local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local GlassShatter = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GlassShatter"))

if not Config.InstantMovementControllerEnabled then
	return
end

local player = Players.LocalPlayer

-- Sonic barrier build-up constants (3-second continuous sprint triggers sonic boom glass shatter + 2% boost)
local SONIC_BUILDUP_TIME = tonumber(Config.SprintSonicBuildupSeconds) or 3.0 -- seconds running before breaking into sonic burst
local SONIC_INITIAL_RATIO = 1.00 -- initial sprint speed is 100% of speedometer setting (no reduction)
local SONIC_BURST_RATIO = tonumber(Config.SprintSonicBoostMultiplier) or 1.02 -- speed jumps to 102% once the sonic barrier breaks
local SONIC_COOLDOWN = 1.00 -- cooldown after stopping before the barrier can break again
local SNAIL_WALK_SPEED = 2.5 -- the admin Snail troll's crawl (AdminSnailUntil)
-- In the race arena before Race/RaceInputClient writes RaceLocalSpeed. 2026-09-25: 40 (the
-- base race cruise, U4.Race.Speed.BaseCruise) instead of 25: never a walk in a race.
-- 2026-09-26: 100, the base race cruise of the owner's Sonic Dash formula.
local RACE_FALLBACK_WALK_SPEED = 100

-- 2026-09-25 (owner: never walk in a race): while RaceInputClient says RaceAutoRun the racer
-- runs down the track by itself and the input steers, along Shared.RaceMath.AutoRunDirection
-- (the direction the race model is fed). Required lazily and under pcall: only racers use it,
-- and a race module that failed to load must never stop ordinary movement.
local raceMath = nil
local function autoRunDirection(direction)
	if raceMath == nil then
		-- Never waits (this runs on Heartbeat): a module not there yet is looked for next frame.
		local shared = ReplicatedStorage:FindFirstChild("Shared")
		local module = shared and shared:FindFirstChild("RaceMath")
		if module then
			local ok, api = pcall(require, module)
			raceMath = if ok and type(api) == "table" and type(api.AutoRunDirection) == "function" then api else false
		end
	end
	if raceMath then
		local x, z = raceMath.AutoRunDirection(direction.X, direction.Z)
		return Vector3.new(x, 0, z)
	end
	return if direction.Magnitude > 0.05 then direction else Vector3.new(0, 0, -1)
end

local sonicRunTimer = 0
local sonicBroken = false
local lastSonicBurstAt = 0

local character = nil
local humanoid = nil
local root = nil
local wallRaycastParams = nil
local lastKnownBaseSpeed = nil

                                      
                                                                            
                                                                            
                                                                           
                                                                              
                                                                   
local WALL_BOUNCE_MIN_NORMAL_Y = 0.58
local WALL_BOUNCE_MIN_INTO_DOT = 0.10
local WALL_BOUNCE_BACKSTEP = 0.35
local WALL_BOUNCE_PADDING = 0.75
local WALL_BOUNCE_MIN_CAST = 1.45
local WALL_BOUNCE_MAX_CAST = 5.25
local WALL_BOUNCE_DURATION = 0.24
local WALL_BOUNCE_MIN_SPEED = 18
local WALL_BOUNCE_MAX_SPEED = 26
local WALL_BOUNCE_WALK_SPEED_FACTOR = 0.28
local WALL_BOUNCE_ATTEMPT_LIFETIME = 2.0
local WALL_BOUNCE_LANDING_GRACE = 0.16

                                                                             
                                                                               
                                                                                
                                                                                
                                                                              
local GROUND_WALL_BACKSTEP = 0.24
local GROUND_WALL_PADDING = 0.12
local GROUND_WALL_MIN_CAST = 1.20
local GROUND_WALL_MAX_CAST = 1.55
local GROUND_WALL_MAX_STEP_DISTANCE = 0.22
local GROUND_WALL_MAX_PASSES = 3
local GROUND_WALL_UNIQUE_NORMAL_DOT = 0.94
local GROUND_WALL_CONTACT_GRACE = 0.18

                                                                                
                                                                                 
                                                                                
                                               
-- Air control is full however the jump began (2026-09-18, from Sung's video: a jump from
-- standing still was held to 2-7 studs/s in the air and could not be steered).
-- A character's own feel on the ground: slopes up to 89 degrees walk (micro-steps between
-- floor plates stopped it dead), and its body slides with little friction (bumps took its
-- speed), whatever the surface (its FrictionWeight outweighs the floor's).
local MAX_SLOPE_ANGLE = 89
local BODY_FRICTION = 0.08
local BODY_PHYSICS = PhysicalProperties.new(0.7, BODY_FRICTION, 0, 100, 1)

local lastJumpRequestAt = -math.huge
local jumpAttemptUntil = -math.huge
local bounceUsedThisJump = false
local lastHumanoidState = nil
local activeBounceNormal = nil
local activeBounceStartedAt = -math.huge
local activeBounceUntil = -math.huge
local activeBounceStartSpeed = 0
local lastGroundedAt = -math.huge
local wasGroundedLastFrame = false
local lastGroundedHorizontalSpeed = 0
local lastGroundedInputMagnitude = 0

                         
                                              
                                                   
                                                                                 

local controls = nil
local controlsLoading = false

local keysDown = {
	W = false,
	A = false,
	S = false,
	D = false,
	Up = false,
	Down = false,
	Left = false,
	Right = false,
}

local function setKey(input, isDown)
	if input.KeyCode == Enum.KeyCode.W then
		keysDown.W = isDown
	elseif input.KeyCode == Enum.KeyCode.A then
		keysDown.A = isDown
	elseif input.KeyCode == Enum.KeyCode.S then
		keysDown.S = isDown
	elseif input.KeyCode == Enum.KeyCode.D then
		keysDown.D = isDown
	elseif input.KeyCode == Enum.KeyCode.Up then
		keysDown.Up = isDown
	elseif input.KeyCode == Enum.KeyCode.Down then
		keysDown.Down = isDown
	elseif input.KeyCode == Enum.KeyCode.Left then
		keysDown.Left = isDown
	elseif input.KeyCode == Enum.KeyCode.Right then
		keysDown.Right = isDown
	end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	setKey(input, true)
end)

UserInputService.InputEnded:Connect(function(input)
	setKey(input, false)
end)

UserInputService.JumpRequest:Connect(function()
	                                                                            
	                                                                              
	                        
	if Config.AbilityFlightEnabled == true and player:GetAttribute("FlightAbilityOwned") == true then
		return
	end

	local now = os.clock()
	lastJumpRequestAt = now
	jumpAttemptUntil = now + WALL_BOUNCE_ATTEMPT_LIFETIME

	                                                                             
	                                                                   
	if character and character.Parent then
		character:SetAttribute("LastVortexWallJumpRequestAt", now)
		character:SetAttribute("VortexGroundWallContactActive", false)
		character:SetAttribute("VortexGroundWallContactNormal", nil)
		character:SetAttribute("VortexGroundWallVisualSpeed", nil)
		character:SetAttribute("LastVortexGroundWallContactAt", nil)
	end

	                                                                           
	                                                                     
	if humanoid and humanoid.Parent then
		local state = humanoid:GetState()
		local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
			and state ~= Enum.HumanoidStateType.Jumping
			and state ~= Enum.HumanoidStateType.Freefall
		if grounded then
			bounceUsedThisJump = false
		end
	end
end)

local function loadPlayerControls()
	if controls then
		return controls
	end

	if controlsLoading then
		return nil
	end

	controlsLoading = true

	local playerScripts = player:FindFirstChild("PlayerScripts")
		or player:WaitForChild("PlayerScripts", 10)

	if not playerScripts then
		controlsLoading = false
		warn("[InstantMovementController] PlayerScripts was not found.")
		return nil
	end

	local playerModuleScript = playerScripts:FindFirstChild("PlayerModule")
		or playerScripts:WaitForChild("PlayerModule", 10)

	if not playerModuleScript then
		controlsLoading = false
		warn("[InstantMovementController] PlayerModule was not found.")
		return nil
	end

	local okModule, playerModule = pcall(require, playerModuleScript)
	if not okModule or type(playerModule) ~= "table" then
		controlsLoading = false
		warn("[InstantMovementController] PlayerModule could not be required: " .. tostring(playerModule))
		return nil
	end

	if type(playerModule.GetControls) ~= "function" then
		controlsLoading = false
		warn("[InstantMovementController] PlayerModule:GetControls() is unavailable.")
		return nil
	end

	local okControls, result = pcall(function()
		return playerModule:GetControls()
	end)

	if not okControls or not result then
		controlsLoading = false
		warn("[InstantMovementController] Controls could not be loaded: " .. tostring(result))
		return nil
	end

	controls = result
	controlsLoading = false
	return controls
end

if UserInputService.TouchEnabled then
	task.spawn(loadPlayerControls)
end

local function enablePlayerControls()
	local activeControls = controls or loadPlayerControls()
	if activeControls and type(activeControls.Enable) == "function" then
		pcall(function()
			activeControls:Enable()
		end)
	end
end

local function disablePlayerControls()
	local activeControls = controls or loadPlayerControls()
	if activeControls and type(activeControls.Disable) == "function" then
		pcall(function()
			activeControls:Disable()
		end)
	end
end

local function bindCharacter(newCharacter)
	character = newCharacter
	humanoid = character:WaitForChild("Humanoid", 10)
	root = character:WaitForChild("HumanoidRootPart", 10)
	wallRaycastParams = nil
	lastJumpRequestAt = -math.huge
	jumpAttemptUntil = -math.huge
	bounceUsedThisJump = false
	lastHumanoidState = nil
	activeBounceNormal = nil
	activeBounceStartedAt = -math.huge
	activeBounceUntil = -math.huge
	activeBounceStartSpeed = 0
	lastGroundedAt = -math.huge
	wasGroundedLastFrame = false
	lastGroundedHorizontalSpeed = 0
	lastGroundedInputMagnitude = 0

	enablePlayerControls()

	-- The body's low friction, on every limb (not the accessories).
	local function smoothBody(part)
		if part:IsA("BasePart") and part.Parent == character then
			part.CustomPhysicalProperties = BODY_PHYSICS
		end
	end
	for _, part in ipairs(character:GetChildren()) do
		smoothBody(part)
	end
	character.ChildAdded:Connect(smoothBody)

	if humanoid then
		humanoid.AutoRotate = true
		humanoid.MaxSlopeAngle = MAX_SLOPE_ANGLE
		lastHumanoidState = humanoid:GetState()

		humanoid.HealthChanged:Connect(function(health)
			if health <= 0 then
				disablePlayerControls()
			end
		end)
	end

	character:GetAttributeChangedSignal("Dead"):Connect(function()
		if character:GetAttribute("Dead") == true then
			disablePlayerControls()
		end
	end)

	character:GetAttributeChangedSignal("Ragdolled"):Connect(function()
		if character:GetAttribute("Ragdolled") == true then
			disablePlayerControls()
		else
			enablePlayerControls()
		end
	end)

	if root then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { character }
		params.IgnoreWater = false
		params.RespectCanCollide = true
		wallRaycastParams = params
	end

	character:SetAttribute("VortexWallBounceActive", false)
	character:SetAttribute("VortexWallBounceVersion", "V248")
	character:SetAttribute("VortexGroundWallContactActive", false)
	character:SetAttribute("VortexGroundWallContactNormal", nil)
	character:SetAttribute("VortexGroundWallVisualSpeed", nil)
	character:SetAttribute("LastVortexGroundWallContactAt", nil)
end

if player.Character then
	task.defer(bindCharacter, player.Character)
end

player.CharacterAdded:Connect(bindCharacter)

-- Client-side Player-to-Player No-Clip: guarantees other players never physically collide with local character
local function disableOtherPlayerCollision(otherChar)
	if not otherChar or otherChar == player.Character then return end
	local function setPartNoCollide(instance)
		if instance:IsA("BasePart") then
			instance.CanCollide = false
		end
	end
	for _, desc in ipairs(otherChar:GetDescendants()) do
		setPartNoCollide(desc)
	end
	otherChar.DescendantAdded:Connect(setPartNoCollide)
end

local function hookOtherPlayer(otherPlayer)
	if otherPlayer == player then return end
	if otherPlayer.Character then
		disableOtherPlayerCollision(otherPlayer.Character)
	end
	otherPlayer.CharacterAdded:Connect(disableOtherPlayerCollision)
end

for _, p in ipairs(Players:GetPlayers()) do
	hookOtherPlayer(p)
end
Players.PlayerAdded:Connect(hookOtherPlayer)

local function isValidCharacter()
	return character
		and character.Parent
		and humanoid
		and humanoid.Parent
		and root
		and root.Parent
		and not root.Anchored
		and humanoid.Health > 0
end

local function shouldSkipMovementControl()
	if not isValidCharacter() then
		return true
	end

	if player:GetAttribute("AdminFlying") == true then
		return true
	end

	-- The Sonic Burst's throw drives the character itself for a moment (SonicBurstClient).
	if character:GetAttribute("SonicBurstDashLocal") == true then
		return true
	end

	if player:GetAttribute("FlightAbilityActive") == true
		or character:GetAttribute("FlightAbilityLocalActive") == true
		or character:GetAttribute("Ragdolled") == true
		or character:GetAttribute("Dead") == true
		or humanoid.PlatformStand == true
		or humanoid.Health <= 0
	then
		return true
	end

	if humanoid.Sit then
		return true
	end

	local state = humanoid:GetState()
	if state == Enum.HumanoidStateType.Dead
		or state == Enum.HumanoidStateType.Ragdoll
		or state == Enum.HumanoidStateType.Physics
		or state == Enum.HumanoidStateType.PlatformStanding
		or state == Enum.HumanoidStateType.Seated
		or state == Enum.HumanoidStateType.Swimming
		or state == Enum.HumanoidStateType.Climbing then
		return true
	end

	return false
end

local function getKeyboardVector()
	local x = 0
	local forward = 0

	if keysDown.W or keysDown.Up then
		forward += 1
	end
	if keysDown.S or keysDown.Down then
		forward -= 1
	end
	if keysDown.D or keysDown.Right then
		x += 1
	end
	if keysDown.A or keysDown.Left then
		x -= 1
	end

	return Vector2.new(x, forward)
end

local function getPlayerModuleVector()
	if not UserInputService.TouchEnabled then
		return Vector2.zero
	end

	local activeControls = controls or loadPlayerControls()
	if not activeControls or type(activeControls.GetMoveVector) ~= "function" then
		return Vector2.zero
	end

	local ok, moveVector = pcall(function()
		return activeControls:GetMoveVector()
	end)

	if not ok or typeof(moveVector) ~= "Vector3" then
		return Vector2.zero
	end

	                                            
	return Vector2.new(moveVector.X, -moveVector.Z)
end

local function getUnifiedInputVector()
	local deadzone = Config.InstantMovementStopDeadzone or 0.03

	                                                                 
	local keyboardVector = getKeyboardVector()
	if keyboardVector.Magnitude > deadzone then
		if keyboardVector.Magnitude > 1 then
			keyboardVector = keyboardVector.Unit
		end

		return keyboardVector
	end

	                                                             
	local controlVector = getPlayerModuleVector()
	if controlVector.Magnitude > deadzone then
		                                                                          
		return controlVector.Unit
	end

	                                                
	if not UserInputService.TouchEnabled then
		local fallback = humanoid and humanoid.MoveDirection or Vector3.zero
		fallback = Vector3.new(fallback.X, 0, fallback.Z)

		if fallback.Magnitude > deadzone then
			local camera = workspace.CurrentCamera
			if not camera then
				return Vector2.zero
			end

			local forward = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
			local right = Vector3.new(camera.CFrame.RightVector.X, 0, camera.CFrame.RightVector.Z)

			if forward.Magnitude <= 0.001 or right.Magnitude <= 0.001 then
				return Vector2.zero
			end

			forward = forward.Unit
			right = right.Unit

			local localVector = Vector2.new(fallback:Dot(right), fallback:Dot(forward))
			if localVector.Magnitude > deadzone then
				return localVector.Unit
			end
		end
	end

	return Vector2.zero
end

local function getCameraRelativeDirection()
	local inputVector = getUnifiedInputVector()
	local deadzone = Config.InstantMovementStopDeadzone or 0.03

	if inputVector.Magnitude <= deadzone then
		return Vector3.zero
	end

	local camera = workspace.CurrentCamera
	if not camera then
		return Vector3.zero
	end

	local forward = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
	local right = Vector3.new(camera.CFrame.RightVector.X, 0, camera.CFrame.RightVector.Z)

	if forward.Magnitude <= 0.001 or right.Magnitude <= 0.001 then
		return Vector3.zero
	end

	forward = forward.Unit
	right = right.Unit

	local direction = (right * inputVector.X) + (forward * inputVector.Y)
	if direction.Magnitude <= deadzone then
		return Vector3.zero
	end

	return direction.Unit
end

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

	local targetRootName = normalizeName(Config.NewWorld1MapMarkerName or "neworld1")
	local current = part.Parent
	while current and current ~= Workspace do
		if normalizeName(current.Name) == targetRootName then
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

local function isExcludedBouncePart(part)
	-- Update 4: the race arena's walls and gates never bounce a racer (RaceArenaBuilder marks
	-- every arena part RaceArenaPart).
	if part:GetAttribute("RaceArenaPart") == true then
		return true
	end
	if isNewWorld1SeamWallExempt(part) then
		return true
	end

	local current = part
	while current and current ~= Workspace do
		if current:GetAttribute("VortexTreadmillCollisionPart") == true
			or current:GetAttribute("VortexTreadmillVisualPart") == true
			or current:GetAttribute("VortexGeneratedBallDamageHitbox") == true
			or TREADMILL_MODEL_NAMES[normalizeName(current.Name)]
		then
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

local function horizontalWallNormal(result, travelDirection)
	if not result or not result.Instance or isExcludedBouncePart(result.Instance) then
		return nil
	end
	if math.abs(result.Normal.Y) > WALL_BOUNCE_MIN_NORMAL_Y then
		return nil
	end

	local normal = horizontal(result.Normal)
	if normal.Magnitude <= 0.001 then
		return nil
	end
	normal = normal.Unit
	if travelDirection:Dot(normal) > -WALL_BOUNCE_MIN_INTO_DOT then
		return nil
	end
	return normal
end

local function findJumpWall(direction, deltaTime)
	if not root or not wallRaycastParams then
		return nil
	end

	local flatDirection = horizontal(direction)
	if flatDirection.Magnitude <= 0.001 then
		return nil
	end
	flatDirection = flatDirection.Unit

	local flatSpeed = horizontal(root.AssemblyLinearVelocity).Magnitude
	local step = math.clamp(tonumber(deltaTime) or (1 / 60), 1 / 240, 0.05)
	local rootRadius = math.max(root.Size.X, root.Size.Z) * 0.5
	local castDistance = math.clamp(
		rootRadius + WALL_BOUNCE_PADDING + flatSpeed * step,
		WALL_BOUNCE_MIN_CAST,
		WALL_BOUNCE_MAX_CAST
	)

	local side = flatDirection:Cross(Vector3.yAxis)
	if side.Magnitude <= 0.001 then
		side = Vector3.xAxis
	else
		side = side.Unit
	end

	                                                                         
	                                                                               
	local offsets = {
		Vector3.zero,
		Vector3.yAxis * 1.15,
		-Vector3.yAxis * 0.70,
		side * 0.72,
		-side * 0.72,
		Vector3.yAxis * 0.65 + side * 0.62,
		Vector3.yAxis * 0.65 - side * 0.62,
	}
	local castVector = flatDirection * (castDistance + WALL_BOUNCE_BACKSTEP)
	local closestNormal = nil
	local closestDistance = math.huge

	for _, offset in ipairs(offsets) do
		local origin = root.Position + offset - flatDirection * WALL_BOUNCE_BACKSTEP
		local result = Workspace:Raycast(origin, castVector, wallRaycastParams)
		local normal = horizontalWallNormal(result, flatDirection)
		if normal and result.Distance < closestDistance then
			closestNormal = normal
			closestDistance = result.Distance
		end
	end

	return closestNormal
end

local function filterDirectionAwayFromWall(direction, normal)
	if direction.Magnitude <= 0.001 or not normal then
		return direction
	end

	local intoWall = direction:Dot(normal)
	if intoWall < 0 then
		direction -= normal * intoWall
	end
	if direction.Magnitude > 1 then
		direction = direction.Unit
	end
	return direction
end

local function addUniqueGroundNormal(normals, normal)
	for _, existing in ipairs(normals) do
		if existing:Dot(normal) >= GROUND_WALL_UNIQUE_NORMAL_DOT then
			return
		end
	end
	table.insert(normals, normal)
end

local function combinedGroundNormal(normals)
	local total = Vector3.zero
	for _, normal in ipairs(normals) do
		total += normal
	end
	local flat = horizontal(total)
	return flat.Magnitude > 0.001 and flat.Unit or normals[1]
end

local function groundWallNormalsAhead(direction, castDistance)
	local flatDirection = horizontal(direction)
	if flatDirection.Magnitude <= 0.001 or not root or not wallRaycastParams then
		return {}
	end
	flatDirection = flatDirection.Unit

	local side = flatDirection:Cross(Vector3.yAxis)
	if side.Magnitude <= 0.001 then
		side = Vector3.xAxis
	else
		side = side.Unit
	end

	                                                                             
	                                                                        
	                                                                     
	local offsets = {
		Vector3.zero,
		Vector3.yAxis * 1.35,
		Vector3.yAxis * 0.65,
		-Vector3.yAxis * 0.78,
		side * 0.82,
		-side * 0.82,
		Vector3.yAxis * 0.72 + side * 0.76,
		Vector3.yAxis * 0.72 - side * 0.76,
	}
	local castVector = flatDirection * (castDistance + GROUND_WALL_BACKSTEP)
	local normals = {}

	for _, offset in ipairs(offsets) do
		local origin = root.Position + offset - flatDirection * GROUND_WALL_BACKSTEP
		local result = Workspace:Raycast(origin, castVector, wallRaycastParams)
		local normal = horizontalWallNormal(result, flatDirection)
		if normal then
			addUniqueGroundNormal(normals, normal)
		end
	end

	return normals
end

local function projectGroundDirection(direction, deltaTime, walkSpeed)
	local corrected = direction
	local allNormals = {}
	local step = math.clamp(tonumber(deltaTime) or (1 / 60), 1 / 240, 0.05)
	local rootRadius = math.max(root.Size.X, root.Size.Z) * 0.5

	for _ = 1, GROUND_WALL_MAX_PASSES do
		if corrected.Magnitude <= 0.001 then
			break
		end

		local castDistance = math.clamp(
			rootRadius
				+ GROUND_WALL_PADDING
				+ math.min(walkSpeed * corrected.Magnitude * step, GROUND_WALL_MAX_STEP_DISTANCE),
			GROUND_WALL_MIN_CAST,
			GROUND_WALL_MAX_CAST
		)
		local passNormals = groundWallNormalsAhead(corrected, castDistance)
		if #passNormals == 0 then
			break
		end

		local before = corrected
		for _, normal in ipairs(passNormals) do
			addUniqueGroundNormal(allNormals, normal)
			corrected = filterDirectionAwayFromWall(corrected, normal)
		end
		if horizontal(corrected - before).Magnitude <= 0.001 then
			break
		end
	end

	return corrected, allNormals
end

local function clearGroundWallVisual()
	if character and character.Parent then
		character:SetAttribute("VortexGroundWallContactActive", false)
		character:SetAttribute("VortexGroundWallContactNormal", nil)
		character:SetAttribute("VortexGroundWallVisualSpeed", nil)
	end
end

local function setGroundWallVisual(normals, visualSpeed, now)
	if not character or not character.Parent or #normals == 0 then
		clearGroundWallVisual()
		return
	end

	character:SetAttribute("VortexGroundWallContactActive", true)
	character:SetAttribute("VortexGroundWallContactNormal", combinedGroundNormal(normals))
	character:SetAttribute("VortexGroundWallVisualSpeed", visualSpeed)
	character:SetAttribute("LastVortexGroundWallContactAt", now)
end

local function clearActiveBounce()
	activeBounceNormal = nil
	activeBounceStartedAt = -math.huge
	activeBounceUntil = -math.huge
	activeBounceStartSpeed = 0
	if character and character.Parent then
		character:SetAttribute("VortexWallBounceActive", false)
		character:SetAttribute("VortexWallBounceUntil", nil)
		character:SetAttribute("VortexWallBounceNormal", nil)
	end
end

local function beginWallBounce(normal, walkSpeed, now)
	activeBounceNormal = normal
	activeBounceStartedAt = now
	activeBounceUntil = now + WALL_BOUNCE_DURATION
	activeBounceStartSpeed = math.clamp(
		walkSpeed * WALL_BOUNCE_WALK_SPEED_FACTOR,
		WALL_BOUNCE_MIN_SPEED,
		WALL_BOUNCE_MAX_SPEED
	)
	bounceUsedThisJump = true

	character:SetAttribute("VortexWallBounceActive", true)
	character:SetAttribute("VortexWallBounceStartedAt", now)
	character:SetAttribute("VortexWallBounceUntil", activeBounceUntil)
	character:SetAttribute("VortexWallBounceNormal", normal)
	character:SetAttribute("LastVortexWallBounceAt", now)
end

local function isGroundedState(state)
	return humanoid.FloorMaterial ~= Enum.Material.Air
		and state ~= Enum.HumanoidStateType.Jumping
		and state ~= Enum.HumanoidStateType.Freefall
		and state ~= Enum.HumanoidStateType.Flying
end

-- 2026-09-26 (owner: Sonic Dash race speeds, 100-900 studs/s): ground adhesion while racing.
-- Leaving one of the race map's hill crests a racer kept the climb's upward speed and flew over
-- the spike rows and pads; Shared.RaceTrack.AdhesionVelocity caps it at the ground's own rise
-- (the race's ground profile, U4.Race.Adhesion). Only under RaceAutoRun, never while a jump is
-- on (from the jump until the feet are down again); required lazily and under pcall like
-- RaceMath above, so a race module that failed to load never touches ordinary movement.
local raceTrack = nil
local raceJumping = false
local function raceGroundAdhesion(verticalVelocity, velocity, state, now)
	if player:GetAttribute("RaceAutoRun") ~= true or player:GetAttribute("RaceActive") ~= true then
		raceJumping = false
		return verticalVelocity
	end
	if humanoid.Jump == true or state == Enum.HumanoidStateType.Jumping then
		raceJumping = true
	elseif raceJumping and humanoid.FloorMaterial ~= Enum.Material.Air and now - lastJumpRequestAt > 0.15 then
		raceJumping = false
	end
	if raceJumping then
		return verticalVelocity
	end
	if raceTrack == nil then
		local shared = ReplicatedStorage:FindFirstChild("Shared")
		local module = shared and shared:FindFirstChild("RaceTrack")
		if module then
			local ok, api = pcall(require, module)
			raceTrack = if ok and type(api) == "table" and type(api.AdhesionVelocity) == "function" then api else false
		end
	end
	if not raceTrack then
		return verticalVelocity
	end
	local ok, capped = pcall(function()
		local s, x, y = raceTrack.ToLocal(root.Position)
		local stand = raceTrack.StandHeight(humanoid.RigType.Name, humanoid.HipHeight, root.Size.Y)
		return raceTrack.AdhesionVelocity(s, x, y, -velocity.Z, velocity.X, verticalVelocity, stand)
	end)
	return if ok and type(capped) == "number" and capped == capped then capped else verticalVelocity
end

local function applyMovement(deltaTime)
	if shouldSkipMovementControl() then
		return
	end

	local currentVelocity = root.AssemblyLinearVelocity
	local verticalVelocity = currentVelocity.Y
	local direction = getCameraRelativeDirection()
	local deadzone = Config.InstantMovementStopDeadzone or 0.03
	-- Racing (RaceAutoRun, local): down the track by itself, the input steers (see above).
	if player:GetAttribute("RaceAutoRun") == true and player:GetAttribute("RaceActive") == true then
		direction = autoRunDirection(direction)
	end
	local now = os.clock()
	local state = humanoid:GetState()
	local grounded = isGroundedState(state)

	if grounded then
		lastGroundedAt = now
		lastGroundedHorizontalSpeed = horizontal(currentVelocity).Magnitude
		lastGroundedInputMagnitude = direction.Magnitude
	end
	wasGroundedLastFrame = grounded

	                                                                         
	                                                                   
	if state == Enum.HumanoidStateType.Jumping
		and lastHumanoidState ~= Enum.HumanoidStateType.Jumping
		and now - lastJumpRequestAt > 0.08
	then
		lastJumpRequestAt = now
		jumpAttemptUntil = now + WALL_BOUNCE_ATTEMPT_LIFETIME
		bounceUsedThisJump = false
	end
	lastHumanoidState = state
	-- 2026-09-26: racing and not jumping, never more upward speed than the ground rises (above).
	verticalVelocity = raceGroundAdhesion(verticalVelocity, currentVelocity, state, now)

	local recentlyRequestedJump = now - lastJumpRequestAt <= WALL_BOUNCE_LANDING_GRACE
	if isGroundedState(state) and not recentlyRequestedJump then
		bounceUsedThisJump = false
		jumpAttemptUntil = -math.huge
		if activeBounceNormal then
			clearActiveBounce()
		end
	end

	-- Update 4 (2026-09-25): in a race the walk speed is the race's own prediction
	-- (Race/RaceInputClient writes RaceLocalSpeed; the server checks it against the same
	-- RaceMath model): no sprint boost, confetti, sonic build-up or world scale on top, and
	-- nothing moves while the racer is held on the grid (RaceMovementLocked).
	local raceActive = player:GetAttribute("RaceActive") == true
	local raceLocked = raceActive and player:GetAttribute("RaceMovementLocked") == true

	local selectedAttr = tonumber(player:GetAttribute("RealWalkSpeedSelected"))
	if selectedAttr and selectedAttr > 0 then
		lastKnownBaseSpeed = selectedAttr
	elseif not lastKnownBaseSpeed or lastKnownBaseSpeed <= 0 then
		lastKnownBaseSpeed = humanoid.WalkSpeed
	end
	local baseSpeed = lastKnownBaseSpeed or 16
	-- 2026-09-26 (owner): Super Sonic (the Super Sonic vs Eggman event, Gameplay/SuperSonicEventService)
	-- runs at least SSE_WalkSpeed (120) while the server keeps it set, never in a race; a player already
	-- faster keeps their own speed, and the sprint, confetti and sonic build-up stack on top as usual.
	local superWalkSpeed = tonumber(player:GetAttribute("SSE_WalkSpeed"))
	if superWalkSpeed and superWalkSpeed > baseSpeed and not raceActive then
		baseSpeed = superWalkSpeed
	end

	local walkSpeed = baseSpeed
	if player:GetAttribute("IsBoosting") == true then
		walkSpeed *= (Config.BoostWalkSpeedMultiplier or Config.BoostSpeedMultiplier or 1.7)
	end
	local confettiExpire = tonumber(player:GetAttribute("ConfettiBoostExpire")) or 0
	if os.time() < confettiExpire then
		walkSpeed *= (tonumber(player:GetAttribute("ConfettiSpeedMult")) or 2)
	end

	local movementWalkSpeed = walkSpeed

	-- Sonic barrier build-up:
	-- Players initially run at 80% of their selected speedometer speed.
	-- After ~0.65s of continuous sprinting they break the sonic barrier: the camera's FOV
	-- widens (SpeedsterClient, SonicBurstActive) and the speed goes to 100%. No glass on the
	-- screen: that was too much on phones every few seconds; the glass now breaks at stage
	-- barriers and the finish (Movement/StageBarrierShatter).
	local isMovingInput = direction.Magnitude > deadzone

	local stepTime = math.clamp(tonumber(deltaTime) or (1 / 60), 1 / 240, 0.1)

	local sprinting = player:GetAttribute("IsBoosting") == true and not raceActive
	local canShatter = isMovingInput and sprinting and grounded and root.AssemblyLinearVelocity.Magnitude > 2
	if canShatter then
		sonicRunTimer += stepTime
		if sonicRunTimer >= SONIC_BUILDUP_TIME then
			if not sonicBroken and now - lastSonicBurstAt >= SONIC_COOLDOWN then
				sonicBroken = true
				lastSonicBurstAt = now
				player:SetAttribute("SonicBurstActive", true)
				task.defer(function()
					GlassShatter.Play({
						Distance = 3.2,
						Depth = 3,
						Intensity = 1.6,
						Thickness = 0.05,
						Transparency = 0.45,
						CameraPunch = true,
						Shockwave = true,
					})
				end)
				-- 2026-09-22: the extra deferred camera "Punch(6)" call is gone: the CameraPunch
				-- module has no Punch, so it only errored on every sonic break (70k live errors) and no
				-- player ever saw a kick. GlassShatter already shakes the camera (CameraPunch = true).
				local moveVel = root.AssemblyLinearVelocity
				local flatMove = Vector3.new(moveVel.X, 0, moveVel.Z)
				if flatMove.Magnitude > 0.1 then
					root.AssemblyLinearVelocity += flatMove.Unit * math.max(15, movementWalkSpeed * 0.15)
				end
			end
		end
	else
		sonicRunTimer = 0
		sonicBroken = false
		if player:GetAttribute("SonicBurstActive") == true then
			player:SetAttribute("SonicBurstActive", false)
		end
	end

	local sonicRatio = if (sprinting and sonicBroken) then SONIC_BURST_RATIO else SONIC_INITIAL_RATIO
	movementWalkSpeed *= sonicRatio

	if raceActive then
		-- (A jog when the prediction has not written yet, never a frozen racer.)
		local raceSpeed = tonumber(player:GetAttribute("RaceLocalSpeed"))
		movementWalkSpeed = if raceLocked then 0 elseif raceSpeed and raceSpeed == raceSpeed then math.max(0, raceSpeed) else RACE_FALLBACK_WALK_SPEED
		walkSpeed = movementWalkSpeed
	end

	-- The admin Snail troll (Admin/AdminAbusePanelService): a crawl until its time is up;
	-- the player's own speed is back the moment it is.
	local snailUntil = tonumber(player:GetAttribute("AdminSnailUntil"))
	if snailUntil and Workspace:GetServerTimeNow() < snailUntil then
		walkSpeed = math.min(walkSpeed, SNAIL_WALK_SPEED)
		movementWalkSpeed = math.min(movementWalkSpeed, SNAIL_WALK_SPEED)
	end

	if humanoid and math.abs(humanoid.WalkSpeed - movementWalkSpeed) > 0.1 then
		humanoid.WalkSpeed = movementWalkSpeed
	end

	if raceLocked then
		-- On the grid (staging, the countdown, a false start's hold): standing, no jumps.
		humanoid.Jump = false
		clearGroundWallVisual()
		if activeBounceNormal then
			clearActiveBounce()
		end
		root.AssemblyLinearVelocity = Vector3.new(0, math.min(verticalVelocity, 0), 0)
		if Config.InstantMovementKeepHumanoidMove then
			humanoid:Move(Vector3.zero, false)
		end
		return
	end

	local jumpAttemptActive = now <= jumpAttemptUntil
		and (recentlyRequestedJump
			or humanoid.Jump == true
			or state == Enum.HumanoidStateType.Jumping
			or state == Enum.HumanoidStateType.Freefall)

	if not activeBounceNormal
		and not bounceUsedThisJump
		and jumpAttemptActive
		and direction.Magnitude > deadzone
	then
		local wallNormal = findJumpWall(direction, deltaTime)
		if wallNormal then
			beginWallBounce(wallNormal, movementWalkSpeed, now)
		end
	end

	if activeBounceNormal then
		clearGroundWallVisual()
		                                                                           
		                                                                     
		local filteredDirection = filterDirectionAwayFromWall(direction, activeBounceNormal)
		local targetHorizontalVelocity = filteredDirection * movementWalkSpeed
		local targetNormalSpeed = targetHorizontalVelocity:Dot(activeBounceNormal)
		local targetTangent = targetHorizontalVelocity
			- activeBounceNormal * targetNormalSpeed

		local outwardSpeed = math.max(0, targetNormalSpeed)
		if now < activeBounceUntil then
			local progress = math.clamp(
				(now - activeBounceStartedAt) / WALL_BOUNCE_DURATION,
				0,
				1
			)
			                                                                          
			                                                                 
			local rebound = activeBounceStartSpeed * (1 - progress * progress)
			outwardSpeed = math.max(outwardSpeed, rebound)
		end

		local bouncedHorizontal = targetTangent + activeBounceNormal * outwardSpeed
		root.AssemblyLinearVelocity = Vector3.new(
			bouncedHorizontal.X,
			Config.InstantMovementPreserveVerticalVelocity and verticalVelocity or 0,
			bouncedHorizontal.Z
		)

		if Config.InstantMovementKeepHumanoidMove then
			humanoid:Move(filteredDirection.Magnitude > deadzone and filteredDirection or Vector3.zero, false)
		end
		return
	end

	local groundedOrContactGrace = isGroundedState(state)
		or now - lastGroundedAt <= GROUND_WALL_CONTACT_GRACE
	if not jumpAttemptActive and direction.Magnitude > deadzone then
		local filteredDirection, groundNormals = projectGroundDirection(
			direction,
			deltaTime,
			movementWalkSpeed
		)
		if #groundNormals > 0 then
			                                                                        
			                                                                           
			                                                                           
			-- A launch pad's lift is meant (the World 1 trampoline sets VortexLaunchUntil while its
			-- runner rises): flattening it here left the runner hanging against the shaft's wall.
			local launchUntil = character and character:GetAttribute("VortexLaunchUntil")
			local launched = type(launchUntil) == "number" and now <= launchUntil
			local stopSolverLift = not launched and (groundedOrContactGrace or verticalVelocity > 0)
			if stopSolverLift then
				setGroundWallVisual(groundNormals, movementWalkSpeed, now)
			else
				clearGroundWallVisual()
			end

			                                                                    
			                                                                       
			                                                                      
			                                                  
			local targetHorizontalVelocity = filteredDirection * movementWalkSpeed
			local correctedVertical = verticalVelocity
			if stopSolverLift then
				correctedVertical = math.min(correctedVertical, 0)
			end
			root.AssemblyLinearVelocity = Vector3.new(
				targetHorizontalVelocity.X,
				Config.InstantMovementPreserveVerticalVelocity
					and correctedVertical or 0,
				targetHorizontalVelocity.Z
			)
			if root.AssemblyAngularVelocity.Magnitude > 0.05 then
				root.AssemblyAngularVelocity = Vector3.zero
			end

			if Config.InstantMovementKeepHumanoidMove then
				humanoid:Move(
					filteredDirection.Magnitude > deadzone
						and filteredDirection or Vector3.zero,
					false
				)
			end
			return
		end
	end

	clearGroundWallVisual()

	if direction.Magnitude <= deadzone then
		                                            
		root.AssemblyLinearVelocity = Vector3.new(
			currentVelocity.X * (Config.InstantMovementHorizontalStopMultiplier or 0),
			Config.InstantMovementPreserveVerticalVelocity and verticalVelocity or 0,
			currentVelocity.Z * (Config.InstantMovementHorizontalStopMultiplier or 0)
		)

		if Config.InstantMovementKeepHumanoidMove then
			humanoid:Move(Vector3.zero, false)
		end

		return
	end

	local targetHorizontalVelocity = direction * movementWalkSpeed

	root.AssemblyLinearVelocity = Vector3.new(
		targetHorizontalVelocity.X,
		Config.InstantMovementPreserveVerticalVelocity and verticalVelocity or 0,
		targetHorizontalVelocity.Z
	)

	if Config.InstantMovementKeepHumanoidMove then
		humanoid:Move(direction, false)
	end
end

RunService.Heartbeat:Connect(applyMovement)

-- Roblox Esc -> Reset Character hook
task.spawn(function()
	local StarterGui = game:GetService("StarterGui")
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local resetRemote = remotes and remotes:FindFirstChild("PlayerResetRequest")
	local resetBindable = Instance.new("BindableEvent")
	resetBindable.Name = "SpeedsterResetBindable"

	resetBindable.Event:Connect(function()
		if resetRemote and resetRemote:IsA("RemoteEvent") then
			resetRemote:FireServer()
		end
		local char = player.Character
		if char then
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 then
				hum.Health = 0
			end
		end
	end)

	for _ = 1, 15 do
		local ok = pcall(function()
			StarterGui:SetCore("ResetButtonCallback", resetBindable)
		end)
		if ok then break end
		task.wait(0.5)
	end
end)

print("[InstantMovementController] V306KBK loaded. V197/V302 movement is preserved; new World 1 Part123/Part345 are ignored only by wall classification so their authored collision stays unchanged without the brief seam barrier.")
