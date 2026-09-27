                                                              
  
                
                                                                            
                                                                                 
                                                                           
                        
                           
                           
        
                            
                                                                  
                                                                                  
                                                                             
                                                                                  

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local STAGE_COUNT = math.max(2, math.floor(tonumber(Config.StageCount) or 10))
local SAFE_ZONE_SUFFIX = tostring(Config.World2SafeZoneSuffix or ".2")
local VERSION = "V306HVWorld2StageTeleport"

local Service = {}

local markers = {
	safe = {},
	stage = {},
	skip = {},
	win = {},
	x2 = {},
}
local finalReference = nil
local finalSafeZone = nil
local finalWinPad = nil
local finalX2Pad = nil
local defaultSpawn = nil

local function normalizeName(value)
	return tostring(value or ""):lower():gsub("[^%w]", "")
end

local function safeZoneNumberFromName(name)
	local lower = tostring(name or ""):lower()
	local escapedSuffix = SAFE_ZONE_SUFFIX:gsub("(%W)", "%%%1")
	local zoneNumber = tonumber(lower:match("^safezone(%d+)" .. escapedSuffix .. "$"))
	if zoneNumber and zoneNumber >= 1 and zoneNumber <= STAGE_COUNT then
		return zoneNumber
	end
	return nil
end

local function logicalStageFromSafeZoneNumber(zoneNumber)
	if zoneNumber and zoneNumber >= 1 and zoneNumber < STAGE_COUNT then
		return zoneNumber + 1
	end
	return nil
end

local function parseManualMarker(object)
	if not object or not object.Parent or not object:IsA("BasePart") then
		return nil, nil
	end
	local n = normalizeName(object.Name)
	local stage = tonumber(n:match("^stage(%d+)$"))
	if stage then return "stage", stage end
	stage = tonumber(n:match("^skip(%d+)$"))
	if stage then return "skip", stage end
	stage = tonumber(n:match("^win(%d+)$"))
	if stage then return "win", stage end
	stage = tonumber(n:match("^x2(%d+)$"))
	if stage then return "x2", stage end
	return nil, nil
end

local function isStageNumber(stage)
	return stage and stage >= 2 and stage <= STAGE_COUNT
end

local function register(object)
	if not object or not object.Parent then
		return
	end

	if object:IsA("SpawnLocation") and object.Enabled and not defaultSpawn then
		defaultSpawn = object
	end

	local safeZoneNumber = safeZoneNumberFromName(object.Name)
	if safeZoneNumber and (object:IsA("BasePart") or object:IsA("Model")) then
		if safeZoneNumber == STAGE_COUNT then
			if not finalSafeZone or not finalSafeZone.Parent then
				finalSafeZone = object
			end
			return
		end
		local logicalStage = logicalStageFromSafeZoneNumber(safeZoneNumber)
		if logicalStage then
			local old = markers.safe[logicalStage]
			if not old or not old.Parent then
				markers.safe[logicalStage] = object
			end
		end
		return
	end

	local normalized = normalizeName(object.Name)
	if (object:IsA("BasePart") or object:IsA("Model")) and normalized == "winstage2" then
		if not finalReference or not finalReference.Parent then
			finalReference = object
		end
		return
	end
	if object:IsA("BasePart") and normalized == "winstagewin" then
		finalWinPad = finalWinPad and finalWinPad.Parent and finalWinPad or object
		return
	end
	if object:IsA("BasePart") and normalized == "winstagex2" then
		finalX2Pad = finalX2Pad and finalX2Pad.Parent and finalX2Pad or object
		return
	end

	local kind, stage = parseManualMarker(object)
	if kind and isStageNumber(stage) then
		local old = markers[kind][stage]
		if not old or not old.Parent then
			markers[kind][stage] = object
		end
	end
end

local function unregister(object)
	if object == defaultSpawn then defaultSpawn = nil end
	if object == finalReference then finalReference = nil end
	if object == finalWinPad then finalWinPad = nil end
	if object == finalX2Pad then finalX2Pad = nil end

	local safeZoneNumber = safeZoneNumberFromName(object and object.Name)
	if safeZoneNumber == STAGE_COUNT and finalSafeZone == object then
		finalSafeZone = nil
	elseif safeZoneNumber then
		local logicalStage = logicalStageFromSafeZoneNumber(safeZoneNumber)
		if logicalStage and markers.safe[logicalStage] == object then
			markers.safe[logicalStage] = nil
		end
	end
	local kind, stage = parseManualMarker(object)
	if kind and stage and markers[kind][stage] == object then
		markers[kind][stage] = nil
	end
end

for _, object in ipairs(Workspace:GetDescendants()) do
	register(object)
end
Workspace.DescendantAdded:Connect(register)
Workspace.DescendantRemoving:Connect(unregister)

local function resolveSpawn(player)
	local respawn = player and player.RespawnLocation
	if respawn and respawn:IsA("SpawnLocation") and respawn.Parent then
		return respawn
	end
	if defaultSpawn and defaultSpawn.Parent and defaultSpawn.Enabled then
		return defaultSpawn
	end
	for _, child in ipairs(Workspace:GetDescendants()) do
		if child:IsA("SpawnLocation") and child.Enabled then
			defaultSpawn = child
			return child
		end
	end
	return nil
end

local function getBounds(object)
	if not object or not object.Parent then
		return nil, nil
	end
	if object:IsA("BasePart") then
		return object.CFrame, object.Size
	end
	if object:IsA("Model") then
		local ok, cf, size = pcall(function()
			return object:GetBoundingBox()
		end)
		if ok then
			return cf, size
		end
	end
	return nil, nil
end

local function objectCenter(object)
	local cf = getBounds(object)
	return cf and cf.Position or nil
end

local function stageObject(stage)
	stage = math.floor(tonumber(stage) or 0)
	if stage < 2 or stage > STAGE_COUNT then
		return nil, nil
	end
	                                                                                                    
	                                                                          
	local order = { "safe", "stage", "x2", "win", "skip" }
	for _, kind in ipairs(order) do
		local object = markers[kind][stage]
		if object and object.Parent then
			return object, kind
		end
	end
	return nil, nil
end

local function isManualPad(part)
	if not part or not part:IsA("BasePart") then return false end
	if part:GetAttribute("World2ManualPad") == true then return true end
	local n = normalizeName(part.Name)
	if n == "winstagewin" or n == "winstagex2" then return true end
	if n:match("^skip%d+$") or n:match("^win%d+$") or n:match("^x2%d+$") then
		return true
	end
	return false
end

local function findFloorNear(center, referenceObject, character)
	if typeof(center) ~= "Vector3" then return nil end
	local filter = {}
	if character then table.insert(filter, character) end
	local runtimeFolder = Workspace:FindFirstChild("World2ManualStagePads_Runtime")
	if runtimeFolder then table.insert(filter, runtimeFolder) end
	if referenceObject and referenceObject:IsA("BasePart")
		and (referenceObject.Transparency >= 0.9 or not referenceObject.CanCollide)
	then
		table.insert(filter, referenceObject)
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = filter
	params.IgnoreWater = false

	local offsets = {
		Vector3.zero,
		Vector3.new(6, 0, 0),
		Vector3.new(-6, 0, 0),
		Vector3.new(0, 0, 6),
		Vector3.new(0, 0, -6),
		Vector3.new(10, 0, 10),
		Vector3.new(-10, 0, -10),
	}
	for _, offset in ipairs(offsets) do
		local origin = center + offset + Vector3.new(0, 80, 0)
		local result = Workspace:Raycast(origin, Vector3.new(0, -220, 0), params)
		if result and result.Instance and not isManualPad(result.Instance) then
			return result.Position, result.Instance
		end
	end
	return nil
end

local function horizontalForwardFrom(object)
	local cf = getBounds(object)
	local forward = cf and Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z) or Vector3.new(0, 0, -1)
	if forward.Magnitude < 0.01 then
		return Vector3.new(0, 0, -1)
	end
	return forward.Unit
end

local function zeroVelocity(character)
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.AssemblyLinearVelocity = Vector3.zero
			descendant.AssemblyAngularVelocity = Vector3.zero
		end
	end
end

local function teleportCharacterToPosition(player, position, forward, stageAttribute, markerKind)
	local character = player and player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not humanoid or not root or not root:IsA("BasePart") or humanoid.Health <= 0 then
		return false, "Character is not ready"
	end

	forward = typeof(forward) == "Vector3" and forward or Vector3.new(0, 0, -1)
	forward = Vector3.new(forward.X, 0, forward.Z)
	if forward.Magnitude < 0.01 then forward = Vector3.new(0, 0, -1) else forward = forward.Unit end
	local standHeight = math.max(3.25, (tonumber(humanoid.HipHeight) or 2) + root.Size.Y * 0.5 + 0.55)
	local targetPosition = position + Vector3.new(0, standHeight, 0)
	local targetCFrame = CFrame.lookAt(targetPosition, targetPosition + forward, Vector3.yAxis)

	player:SetAttribute("StageTeleportArrivalGraceUntil", os.clock() + 1.75)
	zeroVelocity(character)
	character:PivotTo(targetCFrame)
	zeroVelocity(character)
	if stageAttribute then
		player:SetAttribute("LastReachedStage", stageAttribute)
		player:SetAttribute("CurrentSafeZoneStage", stageAttribute)
	end
	player:SetAttribute("World2TeleportMarkerKind", markerKind)
	return true
end

function Service.GetStageReferencePosition(stage)
	stage = math.floor(tonumber(stage) or 0)
	if stage == 1 then
		local spawn = resolveSpawn(nil)
		return spawn and spawn.Position or nil
	end
	local target = stageObject(stage)
	return target and objectCenter(target) or nil
end

function Service.GetNearestStage(position)
	if typeof(position) ~= "Vector3" then return nil, nil end
	local nearestStage, nearestDistance = nil, math.huge
	for stage = 1, STAGE_COUNT do
		local p = Service.GetStageReferencePosition(stage)
		if p then
			local delta = position - p
			local distance = Vector3.new(delta.X, 0, delta.Z).Magnitude + math.abs(delta.Y) * 0.001
			if distance < nearestDistance then
				nearestStage, nearestDistance = stage, distance
			end
		end
	end
	return nearestStage, nearestDistance
end

function Service.TeleportPlayer(player, stage)
	stage = math.floor(tonumber(stage) or 0)
	if stage < 1 or stage > STAGE_COUNT then
		return false, "Invalid stage"
	end

	if stage == 1 then
		local spawn = resolveSpawn(player)
		if not spawn then return false, "World 2 spawn is not ready" end
		local character = player and player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not character or not humanoid or not root or humanoid.Health <= 0 then
			return false, "Character is not ready"
		end
		player:SetAttribute("StageTeleportArrivalGraceUntil", os.clock() + 1.75)
		zeroVelocity(character)
		character:PivotTo(spawn.CFrame * CFrame.new(0, 3.5, 0))
		zeroVelocity(character)
		player:SetAttribute("LastReachedStage", 1)
		player:SetAttribute("CurrentSafeZoneStage", 1)
		player:SetAttribute("World2TeleportMarkerKind", "spawn")
		player:SetAttribute("World2AtFinalWinStage", false)
		return true
	end

	player:SetAttribute("World2AtFinalWinStage", false)
	local target, kind = stageObject(stage)
	if not target then
		return false, "World 2 Stage " .. tostring(stage) .. " checkpoint is not ready"
	end
	local center = objectCenter(target)
	if not center then
		return false, "World 2 Stage " .. tostring(stage) .. " checkpoint has no bounds"
	end
	local character = player and player.Character
	local floorPosition = findFloorNear(center, target, character)
	if not floorPosition then
		                                                                         
		                                                                          
		local cf, size = getBounds(target)
		if not cf or not size then return false, "Stage floor is not ready" end
		floorPosition = Vector3.new(cf.Position.X, cf.Position.Y + size.Y * 0.5, cf.Position.Z)
	end
	return teleportCharacterToPosition(player, floorPosition, horizontalForwardFrom(target), stage, kind)
end

local function finalTargetCenter()
	if finalSafeZone and finalSafeZone.Parent then
		return objectCenter(finalSafeZone), finalSafeZone, "SafeZone10.2"
	end
	if finalReference and finalReference.Parent then
		return objectCenter(finalReference), finalReference, "WinStage.2"
	end
	local a = finalWinPad and finalWinPad.Parent and finalWinPad.Position or nil
	local b = finalX2Pad and finalX2Pad.Parent and finalX2Pad.Position or nil
	if a and b then
		return (a + b) * 0.5, nil, "manual final pad midpoint"
	elseif a then
		return a, nil, "WinStageWin"
	elseif b then
		return b, nil, "WinStageX2"
	end
	return nil, nil, nil
end

function Service.TeleportToFinalWinStage(player)
	local center, reference, kind = finalTargetCenter()
	if not center then
		return false, "World 2 final WinStage is not ready"
	end
	local character = player and player.Character
	local floorPosition = findFloorNear(center, reference, character)
	if not floorPosition then
		floorPosition = center
	end
	local forward = reference and horizontalForwardFrom(reference) or Vector3.new(0, 0, -1)
	local ok, reason = teleportCharacterToPosition(player, floorPosition, forward, STAGE_COUNT, "final:" .. tostring(kind))
	if ok then
		player:SetAttribute("World2AtFinalWinStage", true)
	end
	return ok, reason
end

function Service.TeleportSkipPurchase(player, fromStage)
	fromStage = math.floor(tonumber(fromStage) or 0)
	                                                                             
	if fromStage < 2 or fromStage >= STAGE_COUNT then
		return false, "Invalid World 2 Skip Stage source"
	end
	local targetStage = fromStage + 1
	local ok, reason = Service.TeleportPlayer(player, targetStage)
	if not ok then return false, reason end
	return true, {
		IsFinal = false,
		FromStage = fromStage,
		Stage = targetStage,
		Message = "Skipped to Stage " .. tostring(targetStage),
	}
end

function Service.TeleportToStart(player)
	return Service.TeleportPlayer(player, 1)
end

print("[World2StageTeleportService] " .. VERSION .. " loaded | Stage2=SafeZone1.2 .. Stage10=SafeZone9.2 | SafeZone10.2 final area | no Stage10 Skip")
return Service
