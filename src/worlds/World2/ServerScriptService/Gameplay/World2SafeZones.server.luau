                                                        
  
                                                                        
                                                             
                                                                      
                                                                              
                                                                           

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
if Config.IsWorld2Place ~= true then
	return
end

local STAGE_COUNT = math.max(1, math.floor(tonumber(Config.StageCount) or 10))
local SAFE_ZONE_SUFFIX = tostring(Config.World2SafeZoneSuffix or ".2")
local SAFE_ZONE_ATTRIBUTE = "SafeZoneProtected"
local SAFE_ZONE_FORCE_FIELD = "VortexSafeZoneForceField"
local CHECK_INTERVAL = 0.08
local SIDE_PADDING = 0.75
local BELOW_PADDING = 2
local HEIGHT_ABOVE = 12
local FIRST_SAFE_ZONE_NUMBER = 1
local VERSION = "V306HVWorld2SafeZones"

local safeZones = {}
local boundsCache = {}
local normalizedNames = {}

local function normalizeName(value)
	return tostring(value or ""):lower():gsub("[%s_%-]", "")
end

for zoneNumber = FIRST_SAFE_ZONE_NUMBER, STAGE_COUNT do
	normalizedNames[normalizeName("SafeZone" .. tostring(zoneNumber) .. SAFE_ZONE_SUFFIX)] = zoneNumber
end
normalizedNames[normalizeName("WinStage" .. SAFE_ZONE_SUFFIX)] = STAGE_COUNT
normalizedNames["winstage.2"] = STAGE_COUNT
normalizedNames["winstage2"] = STAGE_COUNT
normalizedNames["winstage"] = STAGE_COUNT

local function logicalStageForZoneNumber(zoneNumber)
	if zoneNumber >= 1 and zoneNumber < STAGE_COUNT then
		return zoneNumber + 1, false
	elseif zoneNumber == STAGE_COUNT then
		return STAGE_COUNT, true
	end
	return nil, false
end

local function isZoneObject(object)
	return object and (object:IsA("BasePart") or object:IsA("Model"))
end

local function anchorObject(object)
	if object:IsA("BasePart") then
		object.Anchored = true
		return
	end
	for _, descendant in ipairs(object:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
		end
	end
end

local function computeBounds(object)
	if not object or not object.Parent then
		return nil
	end
	if object:IsA("BasePart") then
		return { CFrame = object.CFrame, Size = object.Size }
	end
	if object:IsA("Model") then
		local ok, cf, size = pcall(function()
			return object:GetBoundingBox()
		end)
		if ok and cf and size then
			return { CFrame = cf, Size = size }
		end
	end
	return nil
end

local function registerZone(object)
	if not isZoneObject(object) or not object.Parent then
		return false
	end
	local zoneNumber = normalizedNames[normalizeName(object.Name)]
	if not zoneNumber then
		return false
	end
	local old = safeZones[zoneNumber]
	if old and old ~= object and old.Parent then
		return false
	end
	anchorObject(object)
	safeZones[zoneNumber] = object
	boundsCache[zoneNumber] = computeBounds(object)
	local logicalStage, isFinal = logicalStageForZoneNumber(zoneNumber)
	object:SetAttribute("World2SafeZone", true)
	object:SetAttribute("World2SafeZoneNumber", zoneNumber)
	object:SetAttribute("SafeZoneIndex", logicalStage)
	object:SetAttribute("World2FinalSafeZone", isFinal)
	return true
end

local function unregisterZone(object)
	local zoneNumber = normalizedNames[normalizeName(object and object.Name)]
	if zoneNumber and safeZones[zoneNumber] == object then
		safeZones[zoneNumber] = nil
		boundsCache[zoneNumber] = nil
	end
end

local foundAtStartup = 0
for _, object in ipairs(Workspace:GetDescendants()) do
	if registerZone(object) then
		foundAtStartup += 1
	end
end

Workspace.DescendantAdded:Connect(function(object)
	if registerZone(object) then
		return
	end
	                                                                        
	                                                            
	if object:IsA("BasePart") then
		for zoneNumber, zone in pairs(safeZones) do
			if zone and zone:IsA("Model") and object:IsDescendantOf(zone) then
				object.Anchored = true
				boundsCache[zoneNumber] = computeBounds(zone)
				break
			end
		end
	end
end)

Workspace.DescendantRemoving:Connect(function(object)
	unregisterZone(object)
	for zoneNumber, zone in pairs(safeZones) do
		if zone and zone:IsA("Model") and object:IsDescendantOf(zone) then
			task.defer(function()
				if zone.Parent then
					boundsCache[zoneNumber] = computeBounds(zone)
				end
			end)
			break
		end
	end
end)

local function pointInsideBounds(point, bounds)
	if not bounds then
		return false
	end
	local localPoint = bounds.CFrame:PointToObjectSpace(point)
	local half = bounds.Size * 0.5
	return math.abs(localPoint.X) <= half.X + SIDE_PADDING
		and math.abs(localPoint.Z) <= half.Z + SIDE_PADDING
		and localPoint.Y >= -half.Y - BELOW_PADDING
		and localPoint.Y <= half.Y + HEIGHT_ABOVE
end

local function stageAtPosition(position)
	for zoneNumber = FIRST_SAFE_ZONE_NUMBER, STAGE_COUNT do
		if pointInsideBounds(position, boundsCache[zoneNumber]) then
			local logicalStage, isFinal = logicalStageForZoneNumber(zoneNumber)
			return logicalStage, isFinal, zoneNumber
		end
	end
	return nil, false, nil
end

local function setProtection(player, character, protected)
	if not character or not character.Parent then
		return
	end
	if character:GetAttribute(SAFE_ZONE_ATTRIBUTE) ~= protected then
		character:SetAttribute(SAFE_ZONE_ATTRIBUTE, protected)
	end
	if player:GetAttribute(SAFE_ZONE_ATTRIBUTE) ~= protected then
		player:SetAttribute(SAFE_ZONE_ATTRIBUTE, protected)
	end

	local forceField = character:FindFirstChild(SAFE_ZONE_FORCE_FIELD)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if protected then
		if forceField and not forceField:IsA("ForceField") then
			forceField:Destroy()
			forceField = nil
		end
		if not forceField then
			forceField = Instance.new("ForceField")
			forceField.Name = SAFE_ZONE_FORCE_FIELD
			forceField.Visible = false
			forceField.Parent = character
		end
		if humanoid and humanoid.Health > 0 and humanoid.Health < humanoid.MaxHealth then
			humanoid.Health = humanoid.MaxHealth
		end
	elseif forceField then
		forceField:Destroy()
	end
end

local function updatePlayer(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not root or not root:IsA("BasePart") then
		return
	end
	local stage, isFinal, zoneNumber = stageAtPosition(root.Position)
	setProtection(player, character, stage ~= nil)
	local current = stage or 0
	if player:GetAttribute("CurrentSafeZoneStage") ~= current then
		player:SetAttribute("CurrentSafeZoneStage", current)
	end
	if player:GetAttribute("World2AtFinalWinStage") ~= (isFinal == true) then
		player:SetAttribute("World2AtFinalWinStage", isFinal == true)
	end
	-- On change only, like its neighbours (this runs 12.5 times a second for every player).
	if player:GetAttribute("World2CurrentSafeZoneNumber") ~= zoneNumber then
		player:SetAttribute("World2CurrentSafeZoneNumber", zoneNumber)
	end
	if stage then
		local last = math.floor(tonumber(player:GetAttribute("LastReachedStage")) or 0)
		if stage > last then
			player:SetAttribute("LastReachedStage", stage)
		end
		local rebase = _G.VortexMovementGuardRebase
		if type(rebase) == "function" then
			pcall(rebase, player, stage, "SafeZone") -- a body in a zone, not a teleport (MovementGuard H10)
		end
	end
end

for _, player in ipairs(Players:GetPlayers()) do
	if player.Character then
		player.Character:SetAttribute(SAFE_ZONE_ATTRIBUTE, false)
	end
	player:SetAttribute(SAFE_ZONE_ATTRIBUTE, false)
end
Players.PlayerAdded:Connect(function(player)
	player:SetAttribute(SAFE_ZONE_ATTRIBUTE, false)
	player.CharacterAdded:Connect(function(character)
		character:SetAttribute(SAFE_ZONE_ATTRIBUTE, false)
	end)
end)

task.spawn(function()
	while true do
		for _, player in ipairs(Players:GetPlayers()) do
			updatePlayer(player)
		end
		task.wait(CHECK_INTERVAL)
	end
end)

print(
	"[World2SafeZones] "
		.. VERSION
		.. " active | cached SafeZoneN.2 bounds="
		.. tostring(foundAtStartup)
		.. "/"
		.. tostring(STAGE_COUNT)
		.. " | Stage2=SafeZone1.2 .. Stage10=SafeZone9.2 | SafeZone10.2 final | no World 1 dependency"
)
