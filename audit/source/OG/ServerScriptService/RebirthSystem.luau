local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RebirthRequest = Remotes:WaitForChild("RebirthRequest")
local RebirthUpdate = Remotes:WaitForChild("RebirthUpdate")

local function badNumber(value)
	return value ~= value or value == math.huge or value == -math.huge
end

local function cleanInt(value)
	value = tonumber(value) or 0
	if badNumber(value) or value < 0 then
		return 0
	end
	return math.floor(value)
end

local function formatMultiplier(value)
	value = tonumber(value) or 1
	if value >= 1000 then
		return string.format("%.2e", value)
	end

	if value == math.floor(value) then
		return tostring(value)
	end

	return string.format("%.2f", value):gsub("0+$", ""):gsub("%.$", "")
end

local function getNextRequiredLevel(rebirthCount)
	rebirthCount = cleanInt(rebirthCount)

	local firstRequired = tonumber(Config.RebirthFirstLevelRequired) or 5
	local step = tonumber(Config.RebirthLevelStep) or 15

	if rebirthCount <= 0 then
		return firstRequired
	end

	return firstRequired + (rebirthCount * step)
end

local function getRebirthMultiplier(rebirthCount)
	rebirthCount = cleanInt(rebirthCount)

	if _G.SpeedsterGetRebirthSpeedGainMultiplier then
		return _G.SpeedsterGetRebirthSpeedGainMultiplier(rebirthCount)
	end

	local perRebirth = tonumber(Config.RebirthMultiplierPerRebirth) or 1.5
	local multiplier = 1

	for _ = 1, rebirthCount do
		multiplier *= perRebirth
		if badNumber(multiplier) then
			return Config.MaxStoredSpeed or 1e50
		end
	end

	return multiplier
end

local function getStats(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local dataFolder = player:FindFirstChild("SpeedsterData")

	if not leaderstats or not dataFolder then
		return nil
	end

	local speed = leaderstats:FindFirstChild("Speed")
	local rebirths = leaderstats:FindFirstChild("Rebirths")
	local rawSpeed = dataFolder:FindFirstChild("RawSpeed")

	if not speed or not rebirths or not rawSpeed then
		return nil
	end

	return leaderstats, dataFolder, speed, rawSpeed, rebirths
end

local function getCurrentLevel(player, dataFolder)
	local value = tonumber(player:GetAttribute("Level"))

	if value then
		return math.max(1, math.floor(value))
	end

	local levelValue = dataFolder and dataFolder:FindFirstChild("Level")
	value = levelValue and tonumber(levelValue.Value)

	return math.max(1, math.floor(value or 1))
end

local function sendUpdate(player, message, success)
	local stats = {getStats(player)}
	local leaderstats, dataFolder, speed, rawSpeed, rebirths = table.unpack(stats)

	if not leaderstats then
		return
	end

	local rebirthCount = cleanInt(rebirths.Value)
	local currentLevel = getCurrentLevel(player, dataFolder)
	local requiredLevel = getNextRequiredLevel(rebirthCount)
	local currentMultiplier = getRebirthMultiplier(rebirthCount)
	local nextMultiplier = getRebirthMultiplier(rebirthCount + 1)

	RebirthUpdate:FireClient(player, {
		Rebirths = rebirthCount,
		CurrentLevel = currentLevel,
		RequiredLevel = requiredLevel,
		CanRebirth = currentLevel >= requiredLevel,
		CurrentMultiplier = currentMultiplier,
		NextMultiplier = nextMultiplier,
		Message = message,
		Success = success == true,
		StartingSpeed = Config.StartingSpeed or 1,
		MultiplierText = "x" .. formatMultiplier(currentMultiplier),
		NextMultiplierText = "x" .. formatMultiplier(nextMultiplier),
	})
end

local function resetSpeedAndLevel(player, dataFolder, speed, rawSpeed)
	rawSpeed.Value = Config.StartingSpeed or 1
	speed.Value = Config.StartingSpeed or 1
	player:SetAttribute("SpeedCarry", 0)

	local levelValue = dataFolder:FindFirstChild("Level")
	if levelValue then
		levelValue.Value = 1
	end

	local progressValue = dataFolder:FindFirstChild("LevelProgress")
	if progressValue then
		progressValue.Value = 0
	end

	player:SetAttribute("Level", 1)
	player:SetAttribute("LevelProgress", 0)
	player:SetAttribute("LevelRequirement", 37)
end

local function performRebirth(player)
	if player:GetAttribute("DataLoaded") ~= true then
		sendUpdate(player, "Data still loading", false)
		return
	end

	local leaderstats, dataFolder, speed, rawSpeed, rebirths = getStats(player)
	if not leaderstats then
		sendUpdate(player, "Stats not loaded", false)
		return
	end

	local rebirthCount = cleanInt(rebirths.Value)
	local currentLevel = getCurrentLevel(player, dataFolder)
	local requiredLevel = getNextRequiredLevel(rebirthCount)

	if currentLevel < requiredLevel then
		sendUpdate(player, "Reach Level " .. tostring(requiredLevel) .. " Required", false)
		return
	end

	rebirths.Value = rebirthCount + 1
	                                                                            
	player:SetAttribute("FirstRunEasyLevelsEligible", false)

	if _G.SpeedsterSyncRebirthAttributes then
		_G.SpeedsterSyncRebirthAttributes(player)
	end

	resetSpeedAndLevel(player, dataFolder, speed, rawSpeed)

	if _G.SpeedsterApplyWalkSpeed then
		_G.SpeedsterApplyWalkSpeed(player)
	end

	if _G.SpeedsterSavePlayer then
		task.defer(_G.SpeedsterSavePlayer, player, "rebirth")
	end

	task.delay(0.1, function()
		if player.Parent then
			sendUpdate(player, "Rebirth Complete! New multiplier: x" .. formatMultiplier(getRebirthMultiplier(rebirthCount + 1)), true)
		end
	end)
end

RebirthRequest.OnServerEvent:Connect(function(player, action)
	if action == "Sync" then
		sendUpdate(player)
	else
		performRebirth(player)
	end
end)

local function setupPlayer(player)
	player:WaitForChild("leaderstats", 30)
	player:WaitForChild("SpeedsterData", 30)

	task.defer(function()
		task.wait(1)
		if player.Parent then
			if _G.SpeedsterSyncRebirthAttributes then
				_G.SpeedsterSyncRebirthAttributes(player)
			end

			sendUpdate(player)
		end
	end)

	player:GetAttributeChangedSignal("Level"):Connect(function()
		sendUpdate(player)
	end)

	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local rebirths = leaderstats:FindFirstChild("Rebirths")
		if rebirths then
			rebirths.Changed:Connect(function()
				if _G.SpeedsterSyncRebirthAttributes then
					_G.SpeedsterSyncRebirthAttributes(player)
				end

				sendUpdate(player)
			end)
		end
	end
end

Players.PlayerAdded:Connect(function(player)
	task.spawn(setupPlayer, player)
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(setupPlayer, player)
end

print("[RebirthSystem] V152 loaded. First rebirth Level 5, then +15 levels. Multiplier stacks 1.5x.")
