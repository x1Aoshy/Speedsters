                                                                                                                    
  
                                                                             
                                                                                
                                                                           
                                                                               
                                                                              
                                                                                 

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer

local MIN_SWEEP_SPEED = 8
local MAX_SIMULATION_STEP = 0.12
local CAST_PADDING = 0.55
local CAST_BACKSTEP = 0.20
local MAX_WALL_NORMAL_Y = 0.58
local MIN_INTO_WALL_DOT = 0.08
local RECENT_TREADMILL_WINDOW = 0.22

                                                                               
                                                                            
                                                           
local MAX_WALL_PROJECTION_PASSES = 3
local UNIQUE_NORMAL_DOT = 0.94
local GROUND_CONTACT_GRACE = 0.18
local CONTROLLER_GROUND_CONTACT_WINDOW = 0.16
local JUMP_REQUEST_GRACE = 0.24
local GROUND_VERTICAL_EPSILON = 0

local BODY_MIN_SIZE = Vector3.new(2.65, 4.35, 2.10)
local BODY_EXTRA_SIZE = Vector3.new(0.55, 2.25, 0.85)

                                                                           
                                                    
local MAX_TANGENT_GAIN_RATIO = 1.06
local MAX_TANGENT_GAIN_PADDING = 5
local ABNORMAL_OUTWARD_RATIO = 0.16
local ABNORMAL_OUTWARD_MINIMUM = 12
local ABNORMAL_UPWARD_IMPULSE = 13
local ABNORMAL_UPWARD_SPEED = 12
local ABNORMAL_ANGULAR_SPEED = 6
local TREADMILL_ABNORMAL_UPWARD_IMPULSE = 8
local TREADMILL_ABNORMAL_UPWARD_SPEED = 8
local TREADMILL_ABNORMAL_ANGULAR_SPEED = 5
local MISSED_IMPACT_SPEED_GAIN_RATIO = 1.40
local MISSED_IMPACT_SPEED_GAIN_PADDING = 20
local MISSED_IMPACT_ANGULAR_SPEED = 12
local MISSED_IMPACT_MIN_ALIGNMENT = 0.25

local character = nil
local humanoid = nil
local root = nil
local raycastParams = nil

local beforeVelocity = Vector3.zero
local beforeState = nil
local beforeJumpRequested = false
local candidateWallNormals = {}
local candidateTreadmill = nil
local groundWallContactThisStep = false
local controllerGroundWallNormal = nil
local recentTreadmillNormal = nil
local recentTreadmillAt = -math.huge
local lastGroundedAt = -math.huge

local function horizontal(vector)
	return Vector3.new(vector.X, 0, vector.Z)
end

local function normalizeName(value)
	return tostring(value or ""):lower():gsub("[^%w]", "")
end

                                                                            
                                                                               
                                                                                
                                         
local NEW_WORLD1_SEAM_WALL_EXEMPT_NAMES = {
	part123 = true,
	part345 = true,
}

local function isNewWorld1SeamWallExempt(part)
	if not part or not NEW_WORLD1_SEAM_WALL_EXEMPT_NAMES[normalizeName(part.Name)] then
		return false
	end

	local current = part.Parent
	while current and current ~= Workspace do
		if normalizeName(current.Name) == "neworld1" then
			return true
		end
		current = current.Parent
	end
	return false
end

local TREADMILL_MODEL_NAMES = {
	treadmill1basic = true,
	treadmill2fast = true,
	treadmill3superfast = true,
	treadmill4hyperspeed = true,
	treadmill5insanespeed = true,
}

local function isTreadmillPart(part)
	local current = part

	while current and current ~= Workspace do
		if current:GetAttribute("VortexTreadmillCollisionPart") == true
			or current:GetAttribute("VortexTreadmillVisualPart") == true
			or TREADMILL_MODEL_NAMES[normalizeName(current.Name)]
		then
			return true
		end
		current = current.Parent
	end

	return false
end

local function isMovingLethalHazard(part)
	local current = part

	while current and current ~= Workspace do
		if current:GetAttribute("VortexGeneratedBallDamageHitbox") == true then
			return true
		end

		local normalized = normalizeName(current.Name)
		if normalized == "redball"
			or normalized == "reverseflashboss"
			or normalized:match("^hammer%d+$")
		then
			return true
		end

		current = current.Parent
	end

	return false
end

local function clearSnapshot()
	beforeVelocity = Vector3.zero
	beforeState = nil
	beforeJumpRequested = false
	table.clear(candidateWallNormals)
	candidateTreadmill = nil
	groundWallContactThisStep = false
	controllerGroundWallNormal = nil
end

local function bindCharacter(newCharacter)
	character = newCharacter
	humanoid = nil
	root = nil
	raycastParams = nil
	recentTreadmillNormal = nil
	recentTreadmillAt = -math.huge
	lastGroundedAt = -math.huge
	clearSnapshot()

	local foundHumanoid = newCharacter:WaitForChild("Humanoid", 10)
	local foundRoot = newCharacter:WaitForChild("HumanoidRootPart", 10)

	if localPlayer.Character ~= newCharacter
		or not foundHumanoid or not foundHumanoid:IsA("Humanoid")
		or not foundRoot or not foundRoot:IsA("BasePart")
	then
		return
	end

	humanoid = foundHumanoid
	root = foundRoot

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { newCharacter }
	params.IgnoreWater = false
	params.RespectCanCollide = true
	raycastParams = params

	newCharacter:SetAttribute("VortexWallAntiFling", true)
	newCharacter:SetAttribute("VortexWallAntiFlingVersion", "V248")
	newCharacter:SetAttribute("VortexWallCollisionMode", "V248InputFilteredMultiWallStopAndSingleJumpRebound")
	newCharacter:SetAttribute("VortexGroundWallContactActive", false)
	newCharacter:SetAttribute("VortexGroundWallContactNormal", nil)
	newCharacter:SetAttribute("VortexGroundWallVisualSpeed", nil)
end

if localPlayer.Character then
	task.defer(bindCharacter, localPlayer.Character)
end

localPlayer.CharacterAdded:Connect(bindCharacter)

localPlayer.CharacterRemoving:Connect(function(removingCharacter)
	if character == removingCharacter then
		character = nil
		humanoid = nil
		root = nil
		raycastParams = nil
		recentTreadmillNormal = nil
		recentTreadmillAt = -math.huge
		clearSnapshot()
	end
end)

local function isValidCharacter()
	return character
		and character.Parent
		and humanoid
		and humanoid.Parent == character
		and humanoid.Health > 0
		and root
		and root.Parent == character
		and not root.Anchored
		and raycastParams
end

local function isFlightActive()
	if localPlayer:GetAttribute("AdminFlying") == true then
		return true
	end
	if localPlayer:GetAttribute("FlightAbilityActive") == true then
		return true
	end
	if character and character:GetAttribute("FlightAbilityLocalActive") == true then
		return true
	end
	if root and (root:FindFirstChild("FlightAbilityVelocity") or root:FindFirstChild("FlightAbilityAttachment") or root:FindFirstChild("FlightAbilityOrientation")) then
		return true
	end
	return false
end

local function canControlImpact()
	if not isValidCharacter() or humanoid.Sit then
		return false
	end

	if isFlightActive() then
		return false
	end

	local state = humanoid:GetState()
	return state ~= Enum.HumanoidStateType.Dead
		and state ~= Enum.HumanoidStateType.Seated
		and state ~= Enum.HumanoidStateType.Swimming
		and state ~= Enum.HumanoidStateType.Climbing
end

local function isBlockingWall(result, direction)
	return result
		and result.Instance
		and not isNewWorld1SeamWallExempt(result.Instance)
		and not isMovingLethalHazard(result.Instance)
		and not isTreadmillPart(result.Instance)
		and math.abs(result.Normal.Y) <= MAX_WALL_NORMAL_Y
		and direction:Dot(result.Normal) <= -MIN_INTO_WALL_DOT
end

local function bodyCastSize()
	if not root then
		return BODY_MIN_SIZE
	end

	return Vector3.new(
		math.max(BODY_MIN_SIZE.X, root.Size.X + BODY_EXTRA_SIZE.X),
		math.max(BODY_MIN_SIZE.Y, root.Size.Y + BODY_EXTRA_SIZE.Y),
		math.max(BODY_MIN_SIZE.Z, root.Size.Z + BODY_EXTRA_SIZE.Z)
	)
end

local function findRayWall(direction, castDistance)
	local side = direction:Cross(Vector3.yAxis)
	if side.Magnitude <= 0.001 then
		side = Vector3.xAxis
	else
		side = side.Unit
	end

	local offsets = {
		Vector3.zero,
		side * 1.05,
		-side * 1.05,
		Vector3.yAxis * 1.45,
		Vector3.yAxis * 0.65 + side * 0.95,
		Vector3.yAxis * 0.65 - side * 0.95,
		-Vector3.yAxis * 0.75,
	}
	local castVector = direction * (castDistance + CAST_BACKSTEP)
	local treadmillResult = nil

	for _, offset in ipairs(offsets) do
		local origin = root.Position + offset - direction * CAST_BACKSTEP
		local result = Workspace:Raycast(origin, castVector, raycastParams)
		if result and result.Instance and isTreadmillPart(result.Instance) then
			treadmillResult = treadmillResult or result
		elseif isBlockingWall(result, direction) then
			return result, nil
		end
	end

	return nil, treadmillResult
end

local function findWallAhead(direction, castDistance)
	if not root or not raycastParams then
		return nil, nil
	end

	local origin = CFrame.new(root.Position) * root.CFrame.Rotation
	local castVector = direction * math.max(castDistance, 0.05)
	local succeeded, result = pcall(function()
		return Workspace:Blockcast(
			origin,
			bodyCastSize(),
			castVector,
			raycastParams
		)
	end)

	if succeeded and result and result.Instance and isTreadmillPart(result.Instance) then
		return nil, result
	end

	if succeeded and isBlockingWall(result, direction) then
		return result, nil
	end

	                                                                        
	                                                          
	return findRayWall(direction, castDistance)
end

local function wasLegitimateJumpState(state)
	return beforeJumpRequested
		or state == Enum.HumanoidStateType.Jumping
		or state == Enum.HumanoidStateType.Flying
end

local function recoverHumanoidState()
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	if isFlightActive() then
		return
	end

	humanoid.PlatformStand = false
	humanoid.AutoRotate = true

	local state = humanoid:GetState()
	if state == Enum.HumanoidStateType.FallingDown
		or state == Enum.HumanoidStateType.Ragdoll
		or state == Enum.HumanoidStateType.Physics
		or state == Enum.HumanoidStateType.PlatformStanding
	then
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
end

local function wallHorizontalNormal(normal)
	local flat = horizontal(normal)
	return flat.Magnitude > 0.001 and flat.Unit or nil
end

local function removeIntoWall(velocity, normal)
	local flatVelocity = horizontal(velocity)
	local intoWall = flatVelocity:Dot(normal)
	if intoWall < 0 then
		flatVelocity -= normal * intoWall
	end

	return Vector3.new(flatVelocity.X, velocity.Y, flatVelocity.Z)
end

local function addUniqueNormal(normals, normal)
	for _, existing in ipairs(normals) do
		if existing:Dot(normal) >= UNIQUE_NORMAL_DOT then
			return
		end
	end
	table.insert(normals, normal)
end

local function combinedNormal(normals)
	local total = Vector3.zero
	for _, normal in ipairs(normals) do
		total += normal
	end
	local flat = horizontal(total)
	return flat.Magnitude > 0.001 and flat.Unit or normals[1]
end

local function lastJumpRequestTime()
	if not character then
		return -math.huge
	end
	local value = character:GetAttribute("LastVortexWallJumpRequestAt")
	return type(value) == "number" and value or -math.huge
end

local function intentionalBounceNormal(now)
	if not character then
		return nil
	end
	local untilTime = character:GetAttribute("VortexWallBounceUntil")
	local normal = character:GetAttribute("VortexWallBounceNormal")
	if character:GetAttribute("VortexWallBounceActive") == true
		and type(untilTime) == "number"
		and now <= untilTime
		and typeof(normal) == "Vector3"
	then
		return wallHorizontalNormal(normal)
	end
	return nil
end

local function isGroundedState(state)
	return humanoid
		and humanoid.FloorMaterial ~= Enum.Material.Air
		and state ~= Enum.HumanoidStateType.Jumping
		and state ~= Enum.HumanoidStateType.Freefall
		and state ~= Enum.HumanoidStateType.Flying
end

local function realJumpIsActive(now, state)
	return now - lastJumpRequestTime() <= JUMP_REQUEST_GRACE
		or beforeJumpRequested
		or state == Enum.HumanoidStateType.Jumping
		or intentionalBounceNormal(now) ~= nil
end

local function currentControllerGroundWallNormal(now)
	if not character
		or character:GetAttribute("VortexGroundWallContactActive") ~= true
		or character:GetAttribute("VortexWallBounceActive") == true
	then
		return nil
	end

	local contactAt = character:GetAttribute("LastVortexGroundWallContactAt")
	local normal = character:GetAttribute("VortexGroundWallContactNormal")
	if type(contactAt) ~= "number"
		or now - contactAt > CONTROLLER_GROUND_CONTACT_WINDOW
		or typeof(normal) ~= "Vector3"
	then
		return nil
	end

	return wallHorizontalNormal(normal)
end

local function projectAgainstNearbyWalls(velocity, step)
	local corrected = velocity
	local normals = {}
	local treadmillResult = nil
	local rootRadius = math.max(root.Size.X, root.Size.Z) * 0.5

	for pass = 1, MAX_WALL_PROJECTION_PASSES do
		local flatVelocity = horizontal(corrected)
		local speed = flatVelocity.Magnitude
		local minimumSpeed = pass == 1 and MIN_SWEEP_SPEED or 0.5
		if speed < minimumSpeed then
			break
		end

		local direction = flatVelocity.Unit
		local castDistance = speed * step + rootRadius + CAST_PADDING
		local wallResult, foundTreadmill = findWallAhead(direction, castDistance)
		if foundTreadmill then
			                                                                      
			                                                                       
			if #normals == 0 then
				treadmillResult = foundTreadmill
			end
			break
		end
		if not wallResult then
			break
		end

		local normal = wallHorizontalNormal(wallResult.Normal)
		if not normal then
			break
		end
		addUniqueNormal(normals, normal)

		local nextVelocity = removeIntoWall(corrected, normal)
		if horizontal(nextVelocity - corrected).Magnitude <= 0.01 then
			break
		end
		corrected = nextVelocity
	end

	return corrected, normals, treadmillResult
end

RunService.PreSimulation:Connect(function(deltaTimeSim)
	clearSnapshot()

	if not canControlImpact() then
		return
	end

	beforeVelocity = root.AssemblyLinearVelocity
	beforeState = humanoid:GetState()
	beforeJumpRequested = humanoid.Jump

	local now = os.clock()
	if isGroundedState(beforeState) then
		lastGroundedAt = now
	end
	controllerGroundWallNormal = currentControllerGroundWallNormal(now)

	local step = math.clamp(
		tonumber(deltaTimeSim) or (1 / 60),
		1 / 240,
		MAX_SIMULATION_STEP
	)
	local corrected, normals, foundTreadmill = projectAgainstNearbyWalls(beforeVelocity, step)
	candidateTreadmill = foundTreadmill
	for _, normal in ipairs(normals) do
		table.insert(candidateWallNormals, normal)
	end

	if candidateTreadmill then
		recentTreadmillAt = now
		local normal = wallHorizontalNormal(candidateTreadmill.Normal)
		if normal then
			recentTreadmillNormal = normal
		end
		return
	end

	                                                                          
	                                                                           
	                                                                             
	local groundedOrGrace = isGroundedState(beforeState)
		or now - lastGroundedAt <= GROUND_CONTACT_GRACE
	groundWallContactThisStep = not realJumpIsActive(now, beforeState)
		and (controllerGroundWallNormal ~= nil
			or (#candidateWallNormals > 0 and groundedOrGrace))

	if groundWallContactThisStep then
		corrected = Vector3.new(
			corrected.X,
			math.min(corrected.Y, GROUND_VERTICAL_EPSILON),
			corrected.Z
		)
	end

	if corrected ~= beforeVelocity then
		root.AssemblyLinearVelocity = corrected
		beforeVelocity = corrected
		character:SetAttribute("LastVortexWallProjectionAt", now)
	end

	if groundWallContactThisStep
		or root.AssemblyAngularVelocity.Magnitude > ABNORMAL_ANGULAR_SPEED
	then
		root.AssemblyAngularVelocity = Vector3.zero
	end
	recoverHumanoidState()
end)

RunService.PostSimulation:Connect(function()
	if not canControlImpact() then
		return
	end

	local now = os.clock()
	local bounceNormal = intentionalBounceNormal(now)
	local treadmillNormal = nil
	if candidateTreadmill then
		treadmillNormal = wallHorizontalNormal(candidateTreadmill.Normal)
	elseif recentTreadmillNormal and now - recentTreadmillAt <= RECENT_TREADMILL_WINDOW then
		treadmillNormal = recentTreadmillNormal
	end
	local treadmillContact = candidateTreadmill ~= nil
		or now - recentTreadmillAt <= RECENT_TREADMILL_WINDOW

	local afterVelocity = root.AssemblyLinearVelocity
	local beforeFlat = horizontal(beforeVelocity)
	local afterFlat = horizontal(afterVelocity)
	local beforeSpeed = beforeFlat.Magnitude
	local afterSpeed = afterFlat.Magnitude
	local angularSpeed = root.AssemblyAngularVelocity.Magnitude
	local afterState = humanoid:GetState()

	local legitimateJump = wasLegitimateJumpState(beforeState)
		or afterState == Enum.HumanoidStateType.Jumping
		or now - lastJumpRequestTime() <= JUMP_REQUEST_GRACE
	local upwardImpulse = afterVelocity.Y - beforeVelocity.Y
	local upwardImpulseThreshold = treadmillContact
		and TREADMILL_ABNORMAL_UPWARD_IMPULSE or ABNORMAL_UPWARD_IMPULSE
	local upwardSpeedThreshold = treadmillContact
		and TREADMILL_ABNORMAL_UPWARD_SPEED or ABNORMAL_UPWARD_SPEED
	local abnormalUpward = not legitimateJump
		and upwardImpulse >= upwardImpulseThreshold
		and afterVelocity.Y >= upwardSpeedThreshold
	local abnormalState = afterState == Enum.HumanoidStateType.FallingDown
		or afterState == Enum.HumanoidStateType.Ragdoll
		or afterState == Enum.HumanoidStateType.Physics
		or afterState == Enum.HumanoidStateType.PlatformStanding

	local correctedFlat = afterFlat
	local shouldCorrect = false
	local activeNormals = candidateWallNormals

	                                                                        
	                                                                            
	                                                                             
	if #activeNormals == 0 and bounceNormal then
		activeNormals = { bounceNormal }
	end

	for _, wallNormal in ipairs(activeNormals) do
		local normalSpeed = correctedFlat:Dot(wallNormal)
		local sameIntentionalWall = bounceNormal
			and wallNormal:Dot(bounceNormal) >= 0.92
		local abnormalOutward = normalSpeed
			>= math.max(
				ABNORMAL_OUTWARD_MINIMUM,
				beforeSpeed * ABNORMAL_OUTWARD_RATIO
			)

		if groundWallContactThisStep then
			                                                                        
			                                                                     
			if normalSpeed < -0.05 then
				correctedFlat -= wallNormal * normalSpeed
				shouldCorrect = true
			end
		elseif normalSpeed < -0.25 or (abnormalOutward and not sameIntentionalWall) then
			correctedFlat -= wallNormal * normalSpeed
			shouldCorrect = true
		end
	end

	if #activeNormals > 0 and not bounceNormal then
		local maximumTangentSpeed = beforeSpeed * MAX_TANGENT_GAIN_RATIO
			+ MAX_TANGENT_GAIN_PADDING
		if correctedFlat.Magnitude > maximumTangentSpeed then
			correctedFlat = correctedFlat.Unit * maximumTangentSpeed
			shouldCorrect = true
		end
	end

	if treadmillNormal and #activeNormals == 0 then
		local outwardSpeed = correctedFlat:Dot(treadmillNormal)
		local abnormalOutward = outwardSpeed
			>= math.max(
				ABNORMAL_OUTWARD_MINIMUM,
				beforeSpeed * ABNORMAL_OUTWARD_RATIO
			)
		if abnormalOutward then
			correctedFlat -= treadmillNormal * outwardSpeed
			shouldCorrect = true
		end
	end

	local missedImpactGain = afterSpeed
		>= beforeSpeed * MISSED_IMPACT_SPEED_GAIN_RATIO
			+ MISSED_IMPACT_SPEED_GAIN_PADDING
	local missedImpactDeflection = #activeNormals == 0
		and not treadmillContact
		and beforeSpeed >= MIN_SWEEP_SPEED
		and afterSpeed >= math.max(12, beforeSpeed * 0.25)
		and afterFlat.Unit:Dot(beforeFlat.Unit) < MISSED_IMPACT_MIN_ALIGNMENT
	if #activeNormals == 0 and missedImpactGain and beforeSpeed >= MIN_SWEEP_SPEED then
		local maximumSpeed = beforeSpeed * MAX_TANGENT_GAIN_RATIO
			+ MAX_TANGENT_GAIN_PADDING
		if correctedFlat.Magnitude > maximumSpeed then
			correctedFlat = correctedFlat.Unit * maximumSpeed
		end
		shouldCorrect = true
	end
	if missedImpactDeflection then
		correctedFlat = Vector3.zero
		shouldCorrect = true
	end

	local correctedY = afterVelocity.Y
	if groundWallContactThisStep and not legitimateJump and correctedY > GROUND_VERTICAL_EPSILON then
		correctedY = GROUND_VERTICAL_EPSILON
		shouldCorrect = true
	elseif abnormalUpward then
		correctedY = math.min(afterVelocity.Y, math.max(beforeVelocity.Y, 0))
		shouldCorrect = true
	end
	if abnormalState then
		shouldCorrect = true
	end

	local angularThreshold = treadmillContact
		and TREADMILL_ABNORMAL_ANGULAR_SPEED
		or (#activeNormals > 0 and ABNORMAL_ANGULAR_SPEED or MISSED_IMPACT_ANGULAR_SPEED)
	if angularSpeed >= angularThreshold then
		shouldCorrect = true
	end

	if not shouldCorrect then
		return
	end

	root.AssemblyLinearVelocity = Vector3.new(
		correctedFlat.X,
		correctedY,
		correctedFlat.Z
	)
	root.AssemblyAngularVelocity = Vector3.zero
	recoverHumanoidState()
	character:SetAttribute("LastVortexWallCorrectionAt", now)
end)

print("[WallImpactAntiFling] V306KBK loaded. V248 anti-fling behavior is preserved; new World 1 Part123/Part345 stay physically collidable but are excluded from wall classification to remove the brief seam barrier.")
