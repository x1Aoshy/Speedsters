          
                                                                        
                                                                        
                                                                         

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
if Config.IsNewWorld1Map == true then
	return
end

local TARGET_LEVEL = 77
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
local MAX_SWEEP_STEP_DISTANCE = 0.50
local MAX_SWEEP_STEPS_PER_HEARTBEAT = 32
local START_DELAY_SECONDS = 0.20
local TAU = math.pi * 2
local LASER_SPEED_MULTIPLIER = 1.17
local VISIBLE_LASER_TRANSPARENCY_CUTOFF = 0.95
local CORE_BODY_PARTS = {
	HumanoidRootPart = true,
	UpperTorso = true,
	LowerTorso = true,
	Torso = true,
	Head = true,
}

local laser = Workspace:WaitForChild("Laser", 30)
local knob = Workspace:WaitForChild("circle1", 30)

if not laser or not knob then
	warn("[RotatingLaser] Workspace.Laser or Workspace.circle1 was not found.")
	return
end

if not (laser:IsA("BasePart") or laser:IsA("Model")) then
	warn("[RotatingLaser] Workspace.Laser must be a BasePart or Model, got " .. laser.ClassName)
	return
end

if not (knob:IsA("BasePart") or knob:IsA("Model")) then
	warn("[RotatingLaser] Workspace.circle1 must be a BasePart or Model, got " .. knob.ClassName)
	return
end

local function badNumber(value)
	return value ~= value or value == math.huge or value == -math.huge
end

local function isVisibleLaserPart(part)
	if not part:IsA("BasePart") then
		return false
	end
	if part.Transparency >= VISIBLE_LASER_TRANSPARENCY_CUTOFF then
		return false
	end
	if part.Size.X <= 0.05 or part.Size.Y <= 0.05 or part.Size.Z <= 0.05 then
		return false
	end
	return true
end

local function getLaserParts()
	local parts = {}
	if laser:IsA("BasePart") then
		if isVisibleLaserPart(laser) then
			table.insert(parts, laser)
		end
	else
		for _, descendant in ipairs(laser:GetDescendants()) do
			if isVisibleLaserPart(descendant) then
				table.insert(parts, descendant)
			end
		end
	end
	return parts
end

local laserParts = getLaserParts()
if #laserParts == 0 then
	warn("[RotatingLaser] Workspace.Laser has no BasePart geometry.")
	return
end

local knobPosition = knob:GetPivot().Position
local initialLaserPivot = laser:GetPivot()
local rotationOrigin = CFrame.new(knobPosition)
local initialRelativePivot = rotationOrigin:ToObjectSpace(initialLaserPivot)

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

                                                                        
local rawSpeedAtTargetLevel = LEVEL_START_RAW_SPEED
for completedLevel = 1, TARGET_LEVEL - 1 do
	rawSpeedAtTargetLevel += levelRequirement(completedLevel)
end

                                                                             
local minimumWalkSpeed = tonumber(Config.RealWalkSpeedMin) or 8
local referenceDisplayedSpeed = math.max(2, tonumber(Config.RealWalkSpeedReferenceDisplayedSpeed) or 3.37e15)
local walkSpeedAtReference = math.max(minimumWalkSpeed + 1, tonumber(Config.RealWalkSpeedAtReference) or 300)
local walkSpeedCurve = tonumber(Config.RealWalkSpeedCurve) or 2
local formulaProgress = math.max(0, math.log10(rawSpeedAtTargetLevel) / math.log10(referenceDisplayedSpeed))
formulaProgress = formulaProgress ^ walkSpeedCurve
local targetTipStudsPerSecond = (minimumWalkSpeed
	+ (formulaProgress * (walkSpeedAtReference - minimumWalkSpeed))) * LASER_SPEED_MULTIPLIER

if badNumber(targetTipStudsPerSecond) or targetTipStudsPerSecond <= 0 then
	warn("[RotatingLaser] The Level 77 target speed calculation was invalid.")
	return
end

local outerRadius = 0
local minimumHorizontalThickness = math.huge
for _, part in ipairs(laserParts) do
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = true
	part.AssemblyLinearVelocity = Vector3.zero
	part.AssemblyAngularVelocity = Vector3.zero

	minimumHorizontalThickness = math.min(minimumHorizontalThickness, part.Size.X, part.Size.Z)
	local halfSize = part.Size * 0.5
	for xSign = -1, 1, 2 do
		for ySign = -1, 1, 2 do
			for zSign = -1, 1, 2 do
				local corner = part.CFrame:PointToWorldSpace(Vector3.new(
				halfSize.X * xSign,
				halfSize.Y * ySign,
				halfSize.Z * zSign
			))
				local horizontalOffset = Vector2.new(corner.X - knobPosition.X, corner.Z - knobPosition.Z)
				outerRadius = math.max(outerRadius, horizontalOffset.Magnitude)
			end
		end
	end
end

if outerRadius < 0.05 then
	warn("[RotatingLaser] Laser geometry has no usable radius from circle1.")
	return
end

local angularSpeedRadians = targetTipStudsPerSecond / outerRadius
local sweepStepDistance = math.clamp(minimumHorizontalThickness * 0.45, 0.20, MAX_SWEEP_STEP_DISTANCE)
local startServerTime = Workspace:GetServerTimeNow() + START_DELAY_SECONDS

laser:SetAttribute("VortexLaserVersion", "V306KAO")
laser:SetAttribute("VortexLaserEnabled", false)
laser:SetAttribute("VortexLaserKnobPosition", knobPosition)
laser:SetAttribute("VortexLaserInitialPivot", initialLaserPivot)
laser:SetAttribute("VortexLaserStartServerTime", startServerTime)
laser:SetAttribute("VortexLaserAngularSpeed", angularSpeedRadians)
laser:SetAttribute("VortexLaserDegreesPerSecond", math.deg(angularSpeedRadians))
laser:SetAttribute("VortexLaserOuterRadius", outerRadius)
laser:SetAttribute("VortexLaserTargetLevel", TARGET_LEVEL)
laser:SetAttribute("VortexLaserTargetTipSpeed", targetTipStudsPerSecond)
laser:SetAttribute("VortexLaserSafeZoneAware", true)
laser:SetAttribute("VortexLaserEnabled", true)

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

local function getSafeZoneBounds(safeZone)
	if safeZone:IsA("BasePart") then
		return safeZone.CFrame, safeZone.Size
	end

	local ok, boundsCFrame, boundsSize = pcall(function()
		return safeZone:GetBoundingBox()
	end)
	if ok then
		return boundsCFrame, boundsSize
	end
	return nil, nil
end

local function pointInsideSafeZone(point, safeZone)
	local boundsCFrame, boundsSize = getSafeZoneBounds(safeZone)
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

local function damagePlayersOverlappingLaser(alreadyChecked)
	for _, laserPart in ipairs(laserParts) do
		if laserPart.Parent then
			for _, hitPart in ipairs(Workspace:GetPartsInPart(laserPart, overlapParams)) do
				if not CORE_BODY_PARTS[hitPart.Name] then
					continue
				end

				local character = hitPart:FindFirstAncestorOfClass("Model")
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				local player = character and Players:GetPlayerFromCharacter(character)

				if humanoid and player and humanoid.Health > 0 and not alreadyChecked[humanoid] then
					alreadyChecked[humanoid] = true
					if player:GetAttribute("StageTeleportInvulnerable") ~= true
						and not isSafeZoneProtected(player, character)
					then
						                                                            
						                                                              
						                                                                
						            
						humanoid.Health = 0
					end
				end
			end
		end
	end
end

local function pivotAtAngle(angle)
	return rotationOrigin * CFrame.Angles(0, angle % TAU, 0) * initialRelativePivot
end

local previousUnwrappedAngle = 0
local heartbeatConnection
heartbeatConnection = RunService.Heartbeat:Connect(function()
	if not laser.Parent or not knob.Parent then
		heartbeatConnection:Disconnect()
		return
	end

	local elapsed = math.max(0, Workspace:GetServerTimeNow() - startServerTime)
	local currentUnwrappedAngle = elapsed * angularSpeedRadians
	local angleDelta = currentUnwrappedAngle - previousUnwrappedAngle
	local sweptTipDistance = math.abs(angleDelta) * outerRadius
	local sweepSteps = math.clamp(
		math.ceil(sweptTipDistance / sweepStepDistance),
		1,
		MAX_SWEEP_STEPS_PER_HEARTBEAT
	)
	local alreadyChecked = {}

	for step = 1, sweepSteps do
		local alpha = step / sweepSteps
		local sampledAngle = previousUnwrappedAngle + (angleDelta * alpha)
		laser:PivotTo(pivotAtAngle(sampledAngle))
		damagePlayersOverlappingLaser(alreadyChecked)
	end

	previousUnwrappedAngle = currentUnwrappedAngle
end)

print(string.format(
	"[RotatingLaser] V306KAO loaded | visible-geometry core-body laser hitbox | Level %d tip speed %.3f studs/s (17%% faster) | radius %.3f | %.3f deg/s",
	TARGET_LEVEL,
	targetTipStudsPerSecond,
	outerRadius,
	math.deg(angularSpeedRadians)
))
