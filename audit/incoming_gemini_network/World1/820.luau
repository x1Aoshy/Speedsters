          
                                                                            
                                                                               
                                                                           

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local LevelProgressUpdate = Remotes:FindFirstChild("LevelProgressUpdate")
if not LevelProgressUpdate then
	LevelProgressUpdate = Instance.new("RemoteEvent")
	LevelProgressUpdate.Name = "LevelProgressUpdate"
	LevelProgressUpdate.Parent = Remotes
end

local START_LEVEL = 1
local START_PROGRESS = 0
local START_RAW_SPEED = 1

                                                                            
                                                                             
                                                     
local BASE_REQUIREMENT = 37
local EARLY_AND_ENDGAME_GROWTH = 1.166950047752463
local LEVEL_30_TO_60_GROWTH = 1.1477
local LEVEL_60_TO_100_GROWTH = 1.1477
local EARLY_CURVE_END_LEVEL = 30
local MID_CURVE_END_LEVEL = 60
local LATE_CURVE_END_LEVEL = 100
local REQUIREMENT_AT_LEVEL_30 = BASE_REQUIREMENT
	* (EARLY_AND_ENDGAME_GROWTH ^ (EARLY_CURVE_END_LEVEL - 1))
local REQUIREMENT_AT_LEVEL_60 = REQUIREMENT_AT_LEVEL_30
	* (LEVEL_30_TO_60_GROWTH ^ (MID_CURVE_END_LEVEL - EARLY_CURVE_END_LEVEL))
local REQUIREMENT_AT_LEVEL_100 = REQUIREMENT_AT_LEVEL_60
	* (LEVEL_60_TO_100_GROWTH ^ (LATE_CURVE_END_LEVEL - MID_CURVE_END_LEVEL))
local MAX_REQUIREMENT = 1e50
local MAX_LEVEL_SYNC_LOOPS = 2000

                                                                            
                                                                      
local FIRST_RUN_INITIAL_PROGRESS_RATIO = 0.77
local FIRST_RUN_LEVEL_1_FACTOR = 0.50
local FIRST_RUN_LEVEL_17_FACTOR = 0.70
local FIRST_RUN_LEVEL_18_FACTOR = 0.80
local FIRST_RUN_LEVEL_19_FACTOR = 0.90

local tracked = {}

local function badNumber(value)
	return value ~= value or value == math.huge or value == -math.huge
end

local function cleanRawSpeed(value)
	value = tonumber(value) or START_RAW_SPEED
	if badNumber(value) then
		return START_RAW_SPEED
	end
	return math.max(START_RAW_SPEED, value)
end

local function getNormalRequirement(level)
	level = math.max(START_LEVEL, math.floor(tonumber(level) or START_LEVEL))
	local requirement
	if level <= EARLY_CURVE_END_LEVEL then
		requirement = BASE_REQUIREMENT * (EARLY_AND_ENDGAME_GROWTH ^ (level - 1))
	elseif level <= MID_CURVE_END_LEVEL then
		requirement = REQUIREMENT_AT_LEVEL_30
			* (LEVEL_30_TO_60_GROWTH ^ (level - EARLY_CURVE_END_LEVEL))
	elseif level <= LATE_CURVE_END_LEVEL then
		requirement = REQUIREMENT_AT_LEVEL_60
			* (LEVEL_60_TO_100_GROWTH ^ (level - MID_CURVE_END_LEVEL))
	else
		requirement = REQUIREMENT_AT_LEVEL_100
			* (EARLY_AND_ENDGAME_GROWTH ^ (level - LATE_CURVE_END_LEVEL))
	end
	if badNumber(requirement) then
		requirement = MAX_REQUIREMENT
	end
	return math.clamp(requirement, 1, MAX_REQUIREMENT)
end

local function getFirstRunRequirementFactor(level)
	if level <= 17 then
		                                                                  
		local alpha = math.clamp((level - 1) / 16, 0, 1)
		return FIRST_RUN_LEVEL_1_FACTOR
			+ (FIRST_RUN_LEVEL_17_FACTOR - FIRST_RUN_LEVEL_1_FACTOR) * alpha
	elseif level == 18 then
		return FIRST_RUN_LEVEL_18_FACTOR
	elseif level == 19 then
		return FIRST_RUN_LEVEL_19_FACTOR
	end

	                                                                          
	return 1
end

local function getRequirement(level, useFirstRunCurve)
	local requirement = getNormalRequirement(level)
	if useFirstRunCurve == true then
		requirement *= getFirstRunRequirementFactor(level)
	end
	return math.clamp(requirement, 1, MAX_REQUIREMENT)
end

local function ensureNumber(parent, name, value)
	local object = parent:FindFirstChild(name)
	if object and not object:IsA("NumberValue") then
		object:Destroy()
		object = nil
	end
	if not object then
		object = Instance.new("NumberValue")
		object.Name = name
		object.Parent = parent
	end
	object.Value = tonumber(value) or 0
	return object
end

local function calculateFromRawSpeed(rawSpeed, useFirstRunCurve)
	local remaining = math.max(0, cleanRawSpeed(rawSpeed) - START_RAW_SPEED)
	local level = START_LEVEL

	if useFirstRunCurve == true then
		                                                                             
		                                                                            
		                                      
		remaining += getRequirement(START_LEVEL, true) * FIRST_RUN_INITIAL_PROGRESS_RATIO
	end

	for _ = 1, MAX_LEVEL_SYNC_LOOPS do
		local required = getRequirement(level, useFirstRunCurve)
		if remaining < required then
			break
		end
		remaining -= required
		level += 1
	end

	return level, remaining
end

local function publish(player, level, progress, useFirstRunCurve)
	local required = getRequirement(level, useFirstRunCurve)
	player:SetAttribute("Level", level)
	player:SetAttribute("LevelProgress", progress)
	player:SetAttribute("LevelRequirement", required)

	LevelProgressUpdate:FireClient(player, {
		Level = level,
		Progress = progress,
		Required = required,
		Ratio = math.clamp(progress / required, 0, 1),
	})
end

local function syncFromRawSpeed(player)
	local state = tracked[player]
	if not state or not state.rawSpeed.Parent then
		return
	end

	local useFirstRunCurve = player:GetAttribute("FirstRunEasyLevelsEligible") == true
		and (tonumber(player:GetAttribute("Rebirths")) or 0) == 0
	local level, progress = calculateFromRawSpeed(state.rawSpeed.Value, useFirstRunCurve)
	state.levelValue.Value = level
	state.progressValue.Value = progress
	publish(player, level, progress, useFirstRunCurve)
end

local function setupPlayer(player)
	local deadline = os.clock() + 30
	while player.Parent
		and player:GetAttribute("DataLoaded") ~= true
		and player:GetAttribute("DataLoadFailed") ~= true
		and os.clock() < deadline
	do
		task.wait(0.1)
	end

	if not player.Parent or player:GetAttribute("DataLoaded") ~= true then
		if player.Parent and player:GetAttribute("DataLoadFailed") ~= true then
			warn("[LevelProgress] PlayerStats did not finish loading for " .. player.Name)
		end
		return
	end

	local dataFolder = player:FindFirstChild("SpeedsterData")
	local rawSpeed = dataFolder and dataFolder:FindFirstChild("RawSpeed")
	if not dataFolder or not rawSpeed or not rawSpeed:IsA("NumberValue") then
		warn("[LevelProgress] Missing loaded RawSpeed for " .. player.Name)
		return
	end

	local levelValue = ensureNumber(dataFolder, "Level", START_LEVEL)
	local progressValue = ensureNumber(dataFolder, "LevelProgress", START_PROGRESS)
	tracked[player] = {
		rawSpeed = rawSpeed,
		levelValue = levelValue,
		progressValue = progressValue,
	}

	syncFromRawSpeed(player)
	rawSpeed.Changed:Connect(function()
		                                                                         
		                                                         
		syncFromRawSpeed(player)
	end)

	player:GetAttributeChangedSignal("FirstRunEasyLevelsEligible"):Connect(function()
		syncFromRawSpeed(player)
	end)
	player:GetAttributeChangedSignal("Rebirths"):Connect(function()
		syncFromRawSpeed(player)
	end)

	print(
		"[LevelProgress] V306KBC loaded for "
			.. player.Name
			.. " | Level="
			.. tostring(levelValue.Value)
			.. " | Progress="
			.. tostring(progressValue.Value)
	)
end

Players.PlayerAdded:Connect(function(player)
	task.spawn(setupPlayer, player)
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(setupPlayer, player)
end

Players.PlayerRemoving:Connect(function(player)
	tracked[player] = nil
end)

print("[LevelProgress] V306KBC active. Normal curve: original through Level 30, x1.1477 from Level 31 through Level 100, then original endgame growth. First-run Levels 1-19 onboarding preserved.")
