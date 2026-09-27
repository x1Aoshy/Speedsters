          
                                                                            
                                                                              

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
if Config.IsNewWorld1Map == true then
	return
end

local TARGET_LEVEL = 97
local LEVEL_START_RAW_SPEED = 1
local LEVEL_BASE_REQUIREMENT = 37
local LEVEL_EARLY_AND_ENDGAME_GROWTH = 1.166950047752463
local LEVEL_30_TO_60_GROWTH = 1.1491
local LEVEL_60_TO_100_GROWTH = 1.08704
local LEVEL_EARLY_CURVE_END = 30
local LEVEL_MID_CURVE_END = 60
local LEVEL_LATE_CURVE_END = 100
local LEVEL_REQUIREMENT_AT_30 = LEVEL_BASE_REQUIREMENT
	* (LEVEL_EARLY_AND_ENDGAME_GROWTH ^ (LEVEL_EARLY_CURVE_END - 1))
local LEVEL_REQUIREMENT_AT_60 = LEVEL_REQUIREMENT_AT_30
	* (LEVEL_30_TO_60_GROWTH ^ (LEVEL_MID_CURVE_END - LEVEL_EARLY_CURVE_END))
local LEVEL_REQUIREMENT_AT_100 = LEVEL_REQUIREMENT_AT_60
	* (LEVEL_60_TO_100_GROWTH ^ (LEVEL_LATE_CURVE_END - LEVEL_MID_CURVE_END))
local START_DELAY_SECONDS = 0.40
local OPEN_PAUSE = 0.12
local CLOSED_PAUSE = 0.67
local MIN_FACE_GAP = 0.45
local KILL_FACE_DEPTH = 2.2
local FAST_CLOSE_RATIO = 0.23
local PRESS_SPEED_MULTIPLIER = 1.37
local CORE_BODY_PARTS = {
	HumanoidRootPart = true,
	UpperTorso = true,
	LowerTorso = true,
	Torso = true,
	Head = true,
}

local function findWorkspaceObject(name, timeoutSeconds)
	local lowerName = string.lower(name)
	local deadline = os.clock() + (timeoutSeconds or 10)
	repeat
		local exact = Workspace:FindFirstChild(name, true)
		if exact then
			return exact
		end

		for _, descendant in ipairs(Workspace:GetDescendants()) do
			if string.lower(descendant.Name) == lowerName then
				return descendant
			end
		end

		task.wait(0.1)
	until os.clock() >= deadline

	return nil
end

local function getObjectPivot(object)
	if object:IsA("Model") then
		return object:GetPivot()
	elseif object:IsA("BasePart") then
		return object.CFrame
	end

	local firstPart = object:FindFirstChildWhichIsA("BasePart", true)
	if firstPart then
		return firstPart.CFrame
	end

	return nil
end

local function setObjectPivot(object, pivot)
	if object:IsA("Model") then
		object:PivotTo(pivot)
	elseif object:IsA("BasePart") then
		object.CFrame = pivot
	else
		local currentPivot = getObjectPivot(object)
		if not currentPivot then
			return false
		end

		local delta = pivot * currentPivot:Inverse()
		for _, descendant in ipairs(object:GetDescendants()) do
			if descendant:IsA("BasePart") then
				descendant.CFrame = delta * descendant.CFrame
			end
		end
	end

	return true
end

local function getBounds(object)
	if object:IsA("BasePart") then
		return object.CFrame, object.Size
	elseif object:IsA("Model") then
		return object:GetBoundingBox()
	end

	local minPoint = Vector3.new(math.huge, math.huge, math.huge)
	local maxPoint = Vector3.new(-math.huge, -math.huge, -math.huge)
	local foundPart = false

	for _, descendant in ipairs(object:GetDescendants()) do
		if descendant:IsA("BasePart") then
			foundPart = true
			local half = descendant.Size * 0.5
			for x = -1, 1, 2 do
				for y = -1, 1, 2 do
					for z = -1, 1, 2 do
						local corner = descendant.CFrame:PointToWorldSpace(Vector3.new(half.X * x, half.Y * y, half.Z * z))
						minPoint = Vector3.new(math.min(minPoint.X, corner.X), math.min(minPoint.Y, corner.Y), math.min(minPoint.Z, corner.Z))
						maxPoint = Vector3.new(math.max(maxPoint.X, corner.X), math.max(maxPoint.Y, corner.Y), math.max(maxPoint.Z, corner.Z))
					end
				end
			end
		end
	end

	if not foundPart then
		return nil, nil
	end

	local size = maxPoint - minPoint
	local center = (minPoint + maxPoint) * 0.5
	return CFrame.new(center), size
end

local function getAllBaseParts(object)
	local parts = {}
	if object:IsA("BasePart") then
		table.insert(parts, object)
	else
		for _, descendant in ipairs(object:GetDescendants()) do
			if descendant:IsA("BasePart") then
				table.insert(parts, descendant)
			end
		end
	end
	return parts
end

local safeZoneCache = {}

local function findSafeZoneNow(zoneIndex)
	local exactName = "SafeZone" .. tostring(zoneIndex)
	local exact = Workspace:FindFirstChild(exactName, true)
	if exact and (exact:IsA("BasePart") or exact:IsA("Model")) then
		return exact
	end

	local wantedLower = string.lower(exactName)
	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if string.lower(descendant.Name) == wantedLower
			and (descendant:IsA("BasePart") or descendant:IsA("Model"))
		then
			return descendant
		end
	end

	return nil
end

local function pointInsideSafeZone(point, safeZone)
	local boundsCFrame, boundsSize = getBounds(safeZone)
	if not boundsCFrame or not boundsSize then
		return false
	end

	local localPoint = boundsCFrame:PointToObjectSpace(point)
	local halfSize = boundsSize * 0.5
	return math.abs(localPoint.X) <= halfSize.X + 0.75
		and math.abs(localPoint.Z) <= halfSize.Z + 0.75
		and localPoint.Y >= -halfSize.Y - 2
		and localPoint.Y <= halfSize.Y + 12
end

local function isSafeZoneProtected(player, character)
	if player:GetAttribute("SafeZoneProtected") == true
		or character:GetAttribute("SafeZoneProtected") == true
	then
		return true
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end

	for zoneIndex = 1, 10 do
		local safeZone = safeZoneCache[zoneIndex]
		if not safeZone or not safeZone.Parent then
			safeZone = findSafeZoneNow(zoneIndex)
			safeZoneCache[zoneIndex] = safeZone
		end
		if safeZone and pointInsideSafeZone(root.Position, safeZone) then
			return true
		end
	end

	return false
end

local function levelRequirement(level)
	if level <= LEVEL_EARLY_CURVE_END then
		return LEVEL_BASE_REQUIREMENT
			* (LEVEL_EARLY_AND_ENDGAME_GROWTH ^ (level - 1))
	elseif level <= LEVEL_MID_CURVE_END then
		return LEVEL_REQUIREMENT_AT_30
			* (LEVEL_30_TO_60_GROWTH ^ (level - LEVEL_EARLY_CURVE_END))
	elseif level <= LEVEL_LATE_CURVE_END then
		return LEVEL_REQUIREMENT_AT_60
			* (LEVEL_60_TO_100_GROWTH ^ (level - LEVEL_MID_CURVE_END))
	end
	return LEVEL_REQUIREMENT_AT_100
		* (LEVEL_EARLY_AND_ENDGAME_GROWTH ^ (level - LEVEL_LATE_CURVE_END))
end

local function walkSpeedAtLevel(level)
	local rawSpeed = LEVEL_START_RAW_SPEED
	for completedLevel = 1, level - 1 do
		rawSpeed += levelRequirement(completedLevel)
	end

	local minimumWalkSpeed = tonumber(Config.RealWalkSpeedMin) or 8
	local referenceDisplayedSpeed = math.max(2, tonumber(Config.RealWalkSpeedReferenceDisplayedSpeed) or 3.37e15)
	local walkSpeedAtReference = math.max(minimumWalkSpeed + 1, tonumber(Config.RealWalkSpeedAtReference) or 300)
	local walkSpeedCurve = tonumber(Config.RealWalkSpeedCurve) or 2
	local formulaProgress = math.max(0, math.log10(rawSpeed) / math.log10(referenceDisplayedSpeed))
	formulaProgress = formulaProgress ^ walkSpeedCurve
	return minimumWalkSpeed + (formulaProgress * (walkSpeedAtReference - minimumWalkSpeed))
end

local press1 = findWorkspaceObject("Press1", 15)
local press2 = findWorkspaceObject("Press2", 15)
if not press1 or not press2 then
	warn("[Press1Press2Controller] Press1 or Press2 was not found in Workspace.")
	return
end

local press1Pivot = getObjectPivot(press1)
local press2Pivot = getObjectPivot(press2)
local _, press1Size = getBounds(press1)
local _, press2Size = getBounds(press2)
if not press1Pivot or not press2Pivot or not press1Size or not press2Size then
	warn("[Press1Press2Controller] Press1/Press2 must contain BaseParts.")
	return
end

for _, part in ipairs(getAllBaseParts(press1)) do
	part.Anchored = true
	part.CanQuery = true
	part.AssemblyLinearVelocity = Vector3.zero
	part.AssemblyAngularVelocity = Vector3.zero
end
for _, part in ipairs(getAllBaseParts(press2)) do
	part.Anchored = true
	part.CanQuery = true
	part.AssemblyLinearVelocity = Vector3.zero
	part.AssemblyAngularVelocity = Vector3.zero
end

local press1Inward = -press1Pivot.LookVector.Unit                       
local press2Inward = press2Pivot.LookVector.Unit                         
local press1FaceCenter = (press1Pivot * CFrame.new(0, 0, press1Size.Z * 0.5)).Position
local press2FaceCenter = (press2Pivot * CFrame.new(0, 0, -press2Size.Z * 0.5)).Position
local initialGap = math.max(0, (press2FaceCenter - press1FaceCenter):Dot(press1Inward))
local travelDistanceEach = math.max(0, (initialGap - MIN_FACE_GAP) * 0.5)
local closeSpeedTotal = walkSpeedAtLevel(TARGET_LEVEL)
local baseSinglePresserSpeed = math.max(1, closeSpeedTotal * 0.5 * PRESS_SPEED_MULTIPLIER)
local baseOneWayDuration = travelDistanceEach > 0 and (travelDistanceEach / baseSinglePresserSpeed) or 0.001
local totalMoveDuration = baseOneWayDuration * 2
local closeDuration = math.max(0.001, totalMoveDuration * FAST_CLOSE_RATIO)
local openDuration = math.max(0.001, totalMoveDuration - closeDuration)
local closeInwardSpeed = travelDistanceEach / closeDuration
local openBackSpeed = travelDistanceEach / openDuration

local press1OpenPivot = press1Pivot
local press2OpenPivot = press2Pivot
local press1ClosedPivot = press1OpenPivot + (press1Inward * travelDistanceEach)
local press2ClosedPivot = press2OpenPivot + (press2Inward * travelDistanceEach)

local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Include
overlapParams.MaxParts = 0
overlapParams.RespectCanCollide = false

local function refreshCharacterFilter()
	local characters = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			table.insert(characters, player.Character)
		end
	end
	overlapParams.FilterDescendantsInstances = characters
end

local function watchPlayer(player)
	player.CharacterAdded:Connect(function()
		task.defer(refreshCharacterFilter)
	end)
	player.CharacterRemoving:Connect(function()
		task.defer(refreshCharacterFilter)
	end)
	refreshCharacterFilter()
end

for _, player in ipairs(Players:GetPlayers()) do
	watchPlayer(player)
end
Players.PlayerAdded:Connect(watchPlayer)
Players.PlayerRemoving:Connect(function()
	task.defer(refreshCharacterFilter)
end)
refreshCharacterFilter()

local function killFromCharacterPart(hitPart)
	if not CORE_BODY_PARTS[hitPart.Name] then
		return
	end

	local character = hitPart:FindFirstAncestorOfClass("Model")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local player = character and Players:GetPlayerFromCharacter(character)
	if humanoid
		and player
		and humanoid.Health > 0
		and player:GetAttribute("StageTeleportInvulnerable") ~= true
		and not isSafeZoneProtected(player, character)
	then
		humanoid.Health = 0
	end
end

local function scanFaceSlab(pivot, objectSize, localZCenter)
	local slabCFrame = pivot * CFrame.new(0, 0, localZCenter)
	local slabSize = Vector3.new(objectSize.X, objectSize.Y, KILL_FACE_DEPTH)
	for _, hitPart in ipairs(Workspace:GetPartBoundsInBox(slabCFrame, slabSize, overlapParams)) do
		killFromCharacterPart(hitPart)
	end
end

local function applyPivots(pivot1, pivot2)
	setObjectPivot(press1, pivot1)
	setObjectPivot(press2, pivot2)
	scanFaceSlab(pivot1, press1Size, (press1Size.Z * 0.5) + (KILL_FACE_DEPTH * 0.5))
	scanFaceSlab(pivot2, press2Size, -(press2Size.Z * 0.5) - (KILL_FACE_DEPTH * 0.5))
end

local cycleLength = OPEN_PAUSE + closeDuration + CLOSED_PAUSE + openDuration
local startTime = Workspace:GetServerTimeNow() + START_DELAY_SECONDS
local heartbeatConnection
heartbeatConnection = RunService.Heartbeat:Connect(function()
	if not press1.Parent or not press2.Parent then
		heartbeatConnection:Disconnect()
		return
	end

	local elapsed = math.max(0, Workspace:GetServerTimeNow() - startTime)
	local cycleTime = cycleLength > 0 and (elapsed % cycleLength) or 0
	local pivot1
	local pivot2

	if cycleTime < OPEN_PAUSE then
		pivot1 = press1OpenPivot
		pivot2 = press2OpenPivot
	elseif cycleTime < OPEN_PAUSE + closeDuration then
		local alpha = (cycleTime - OPEN_PAUSE) / closeDuration
		pivot1 = press1OpenPivot:Lerp(press1ClosedPivot, alpha)
		pivot2 = press2OpenPivot:Lerp(press2ClosedPivot, alpha)
	elseif cycleTime < OPEN_PAUSE + closeDuration + CLOSED_PAUSE then
		pivot1 = press1ClosedPivot
		pivot2 = press2ClosedPivot
	else
		local alpha = (cycleTime - OPEN_PAUSE - closeDuration - CLOSED_PAUSE) / openDuration
		pivot1 = press1ClosedPivot:Lerp(press1OpenPivot, alpha)
		pivot2 = press2ClosedPivot:Lerp(press2OpenPivot, alpha)
	end

	applyPivots(pivot1, pivot2)
end)

print(string.format(
	"[Press1Press2Controller] V306KAO active | Press1.Back + Press2.Front lethal | Level %d total speed %.3f | fast close %.3f | slow open %.3f | travel each = %.3f",
	TARGET_LEVEL,
	closeSpeedTotal,
	closeInwardSpeed,
	openBackSpeed,
	travelDistanceEach
))
