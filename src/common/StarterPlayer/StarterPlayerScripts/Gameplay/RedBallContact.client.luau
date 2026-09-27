                       
  
                                                                            
                                                                             
                                                                          
                                                                           
                                                                               
                                                                              
                                     

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
-- World 3 has no red ball (World 1's WinPads makes its hitbox) and no RedBallContact remote:
-- left running, it waited on that remote forever.
if Config.IsWorld2Place == true or Config.IsNewWorld1Map == true or Config.IsWorld3Place == true then
	return
end
local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local redBallContactRemote = remotesFolder:WaitForChild("RedBallContact")

local DAMAGE_HITBOX_NAME = "VortexRedBallDamageHitbox"
local REPORT_COOLDOWN = 0.08
local MAX_SWEEP_SAMPLE_TIME = 0.12
local MIN_EXPECTED_CHARACTER_TRAVEL = 28
local CHARACTER_TRAVEL_PADDING = 12
local CHARACTER_SPEED_ALLOWANCE = 2.5
local MAX_EXPECTED_BALL_TRAVEL = 20
local CURRENT_CONTACT_EPSILON = 0.08
local SWEPT_CONTACT_PADDING = 0.1

local character = nil
local humanoid = nil
local characterRoot = nil
local characterOverlapParams = nil
local damageHitbox = nil
local previousRootPosition = nil
local previousBodyPositions = {}
local previousHitboxPosition = nil
local previousSampleAt = nil
local previousDamageCycle = nil
local lastReportAt = -math.huge
local initialHitboxScanComplete = false

local function resetSweepHistory()
	previousRootPosition = nil
	previousBodyPositions = {}
	previousHitboxPosition = nil
	previousSampleAt = nil
	previousDamageCycle = nil
end

local function isGeneratedDamageHitbox(instance)
	return instance:IsA("BasePart")
		and instance.Name == DAMAGE_HITBOX_NAME
		and instance:GetAttribute("VortexGeneratedBallDamageHitbox") == true
end

local function setDamageHitbox(instance)
	if damageHitbox == instance then
		return
	end

	damageHitbox = instance
	resetSweepHistory()
end

local function findCurrentDamageHitbox()
	if damageHitbox and damageHitbox:IsDescendantOf(Workspace) then
		return damageHitbox
	end

	if initialHitboxScanComplete then
		return nil
	end
	initialHitboxScanComplete = true

	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if isGeneratedDamageHitbox(descendant) then
			setDamageHitbox(descendant)
			return descendant
		end
	end

	setDamageHitbox(nil)
	return nil
end

Workspace.DescendantAdded:Connect(function(descendant)
	if isGeneratedDamageHitbox(descendant) then
		setDamageHitbox(descendant)
	end
end)

Workspace.DescendantRemoving:Connect(function(descendant)
	if descendant == damageHitbox then
		setDamageHitbox(nil)
	end
end)

local function bindCharacter(newCharacter)
	character = newCharacter
	humanoid = nil
	characterRoot = nil
	characterOverlapParams = nil
	resetSweepHistory()

	local foundHumanoid = newCharacter:WaitForChild("Humanoid", 10)
	local foundRoot = newCharacter:WaitForChild("HumanoidRootPart", 10)

	if localPlayer.Character ~= newCharacter
		or not foundHumanoid or not foundHumanoid:IsA("Humanoid")
		or not foundRoot or not foundRoot:IsA("BasePart")
	then
		return
	end

	humanoid = foundHumanoid
	characterRoot = foundRoot

	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { newCharacter }
	params.MaxParts = 64
	params.RespectCanCollide = false
	characterOverlapParams = params
end

if localPlayer.Character then
	task.spawn(bindCharacter, localPlayer.Character)
end

localPlayer.CharacterAdded:Connect(function(newCharacter)
	task.spawn(bindCharacter, newCharacter)
end)

localPlayer.CharacterRemoving:Connect(function(removingCharacter)
	if character == removingCharacter then
		character = nil
		humanoid = nil
		characterRoot = nil
		characterOverlapParams = nil
		resetSweepHistory()
	end
end)

local function getDirectBodyParts()
	local bodyParts = {}
	if not character then
		return bodyParts
	end

	for _, child in ipairs(character:GetChildren()) do
		                                                                     
		                                                                        
		                                    
		if child:IsA("BasePart") then
			table.insert(bodyParts, child)
		end
	end

	return bodyParts
end

local function getBallRadius(hitbox)
	return math.max(hitbox.Size.X, hitbox.Size.Y, hitbox.Size.Z) * 0.5
end

local function sphereOverlapsBodyPart(hitbox, bodyPart)
	                                                                           
	                                                                          
	                                 
	local localBallCenter = bodyPart.CFrame:PointToObjectSpace(hitbox.Position)
	local halfSize = bodyPart.Size * 0.5
	local closestPoint = Vector3.new(
		math.clamp(localBallCenter.X, -halfSize.X, halfSize.X),
		math.clamp(localBallCenter.Y, -halfSize.Y, halfSize.Y),
		math.clamp(localBallCenter.Z, -halfSize.Z, halfSize.Z)
	)
	local distanceToPart = (localBallCenter - closestPoint).Magnitude

	return distanceToPart <= getBallRadius(hitbox) + CURRENT_CONTACT_EPSILON
end

local function currentBodyOverlapsHitbox(hitbox, bodyParts)
	if not character then
		return false
	end

	local success = false
	local overlappingParts = {}
	if characterOverlapParams then
		success, overlappingParts = pcall(function()
			return Workspace:GetPartsInPart(hitbox, characterOverlapParams)
		end)
	end

	if success then
		for _, part in ipairs(overlappingParts) do
			if part:IsA("BasePart") and part.Parent == character then
				return true
			end
		end
	end

	for _, bodyPart in ipairs(bodyParts) do
		if bodyPart.Parent == character and sphereOverlapsBodyPart(hitbox, bodyPart) then
			return true
		end
	end

	return false
end

local function distanceFromOriginToSegment(segmentStart, segmentEnd)
	local segment = segmentEnd - segmentStart
	local lengthSquared = segment:Dot(segment)

	if lengthSquared <= 1e-6 then
		return segmentStart.Magnitude
	end

	local amount = math.clamp(-segmentStart:Dot(segment) / lengthSquared, 0, 1)
	return (segmentStart + segment * amount).Magnitude
end

local function getBodyPartSweepRadius(bodyPart)
	local size = bodyPart.Size
	return math.max(0.5, math.max(size.X, size.Y, size.Z) * 0.5)
		+ SWEPT_CONTACT_PADDING
end

local function movementSweptThroughHitbox(hitbox, damageCycle, now, bodyParts)
	if previousDamageCycle ~= damageCycle
		or not previousRootPosition
		or not previousHitboxPosition
		or not previousSampleAt
	then
		return false
	end

	local elapsed = now - previousSampleAt
	if elapsed <= 0 or elapsed > MAX_SWEEP_SAMPLE_TIME then
		return false
	end

	local currentCharacterPosition = characterRoot.Position
	local currentHitboxPosition = hitbox.Position
	local characterTravel = (currentCharacterPosition - previousRootPosition).Magnitude
	local hitboxTravel = (currentHitboxPosition - previousHitboxPosition).Magnitude
	local currentCharacterSpeed = characterRoot.AssemblyLinearVelocity.Magnitude
	local expectedCharacterTravel = math.max(
		MIN_EXPECTED_CHARACTER_TRAVEL,
		currentCharacterSpeed * elapsed * CHARACTER_SPEED_ALLOWANCE
			+ CHARACTER_TRAVEL_PADDING
	)

	                                                                            
	                                                                            
	if characterTravel > expectedCharacterTravel
		or hitboxTravel > MAX_EXPECTED_BALL_TRAVEL
	then
		return false
	end

	local ballRadius = getBallRadius(hitbox)

	for _, bodyPart in ipairs(bodyParts) do
		local previousBodyPosition = previousBodyPositions[bodyPart]
		if previousBodyPosition and bodyPart.Parent == character then
			local previousRelativePosition = previousBodyPosition
				- previousHitboxPosition
			local currentRelativePosition = bodyPart.Position
				- currentHitboxPosition
			local closestCenterDistance = distanceFromOriginToSegment(
				previousRelativePosition,
				currentRelativePosition
			)

			if closestCenterDistance <= ballRadius + getBodyPartSweepRadius(bodyPart) then
				return true
			end
		end
	end

	return false
end

local function recordSweepHistory(hitbox, damageCycle, now, bodyParts)
	local currentBodyPositions = {}

	for _, bodyPart in ipairs(bodyParts) do
		if bodyPart.Parent == character then
			currentBodyPositions[bodyPart] = bodyPart.Position
		end
	end

	previousRootPosition = characterRoot.Position
	previousBodyPositions = currentBodyPositions
	previousHitboxPosition = hitbox.Position
	previousSampleAt = now
	previousDamageCycle = damageCycle
end

RunService.Heartbeat:Connect(function()
	local hitbox = findCurrentDamageHitbox()

	if not character or not character.Parent
		or not humanoid or humanoid.Health <= 0
		or not characterRoot or characterRoot.Parent ~= character
		or not hitbox or not hitbox:IsDescendantOf(Workspace)
		or hitbox:GetAttribute("DamageEnabled") ~= true
	then
		resetSweepHistory()
		return
	end

	local damageCycle = hitbox:GetAttribute("DamageCycle")
	if type(damageCycle) ~= "number" then
		resetSweepHistory()
		return
	end

	local now = os.clock()
	local bodyParts = getDirectBodyParts()
	local hasCurrentOverlap = currentBodyOverlapsHitbox(hitbox, bodyParts)
	local crossedBetweenFrames = movementSweptThroughHitbox(
		hitbox,
		damageCycle,
		now,
		bodyParts
	)

	if (hasCurrentOverlap or crossedBetweenFrames)
		and now - lastReportAt >= REPORT_COOLDOWN
	then
		lastReportAt = now
		redBallContactRemote:FireServer(hitbox, damageCycle)
	end

	recordSweepHistory(hitbox, damageCycle, now, bodyParts)
end)

findCurrentDamageHitbox()
