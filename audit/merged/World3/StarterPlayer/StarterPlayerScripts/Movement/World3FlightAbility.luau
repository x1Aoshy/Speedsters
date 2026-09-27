local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")

local SCRIPT_TAG = "[" .. script.Name .. "]"

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
if Config.AbilityFlightEnabled ~= true then
	return
end

local player = Players.LocalPlayer
local windowFocused = true
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local FlightAbilityState = Remotes:WaitForChild("FlightAbilityState")

local character
local humanoid
local root
local animator
local flightAttachment
local flightVelocity
local flightOrientation
local poweredTrack
local glideTrack
local active = false
local powered = false
local spaceHeld = false
local flightStartedAt = -math.huge
local lastSentActive = nil
local lastSentPowered = nil
local originalAutoRotate = true
local flightLoopSound
local spaceHoldSerial = 0
local rootChildAddedConnection
local runSoundsToSuppress = setmetatable({}, { __mode = "k" })
local canInitiateFlight = false
local lastGroundedAt = 0
local lastBarrierTouch = -math.huge
local characterTouchedConnections = {}

local function isBarrierPart(part)
	if not part or not part:IsA("BasePart") then return false end
	if part:GetAttribute("IsBarrier") == true or part:GetAttribute("World2WallFlightBarrier") == true then
		return true
	end
	local name = part.Name:lower()
	if name == "barrier" or name == "barriers" or name == "wallflightbarrier" then
		return true
	end
	local parent = part.Parent
	if parent and (parent.Name:lower() == "barriers" or parent.Name == "World2WallFlightBarriers_Runtime") then
		return true
	end
	return false
end

local function isCharacterTouchingBarrier()
	if not character or not character.Parent then return false end
	for _, child in ipairs(character:GetDescendants()) do
		if child:IsA("BasePart") then
			local parts = nil
			local ok = pcall(function()
				parts = Workspace:GetPartsInPart(child)
			end)
			if not ok or not parts then
				pcall(function()
					parts = child:GetTouchingParts()
				end)
			end
			if parts then
				for _, part in ipairs(parts) do
					if isBarrierPart(part) then
						return true
					end
				end
			end
		end
	end
	return false
end

local flightVfx = {
	powered = nil,
	glide = nil,
}
local flightVfxEnabledStates = setmetatable({}, { __mode = "k" })
local warnedMissingVfx = {}

local POWERED_VFX_TEMPLATE_NAME = "WindForceUp"
local GLIDE_VFX_TEMPLATE_NAME = "WindForce"

local VFX_FORWARD_Z = 0.02
local POWERED_VFX_HEAD_OFFSET = CFrame.new(0, 0, VFX_FORWARD_Z)
	* CFrame.Angles(math.rad(-90), 0, 0)
local GLIDE_VFX_HEAD_OFFSET = CFrame.new(0, 0, VFX_FORWARD_Z)
	* CFrame.Angles(math.rad(-90), 0, 0)

local RUN_TREADMILL_SOUND_ID = "rbxassetid://96591611478915"

local keysDown = {
	W = false, A = false, S = false, D = false,
	Up = false, Down = false, Left = false, Right = false,
}

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.IgnoreWater = false
raycastParams.RespectCanCollide = true

-- Keep client checks consistent with the server/config.
local FlightStamina = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FlightStamina"))
local StaminaFeedback = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("StaminaFeedback"))
-- Holding Space should feel responsive; override in Config with AbilityFlightHoldSeconds if desired.
local FLIGHT_HOLD_SECONDS = math.max(0.1, tonumber(Config.AbilityFlightHoldSeconds) or 0.85)
-- Jump once, keep holding: flight engages this soon after the feet leave the
-- ground. Holding through the full ground timer was the "you have to jump a
-- dozen times" complaint.
local AIRBORNE_HOLD_SECONDS = math.max(0, tonumber(Config.AbilityFlightAirborneHoldSeconds) or 0.18)
local lastJumpAt = -math.huge

local function setKey(input, down)
	if input.KeyCode == Enum.KeyCode.W then keysDown.W = down
	elseif input.KeyCode == Enum.KeyCode.A then keysDown.A = down
	elseif input.KeyCode == Enum.KeyCode.S then keysDown.S = down
	elseif input.KeyCode == Enum.KeyCode.D then keysDown.D = down
	elseif input.KeyCode == Enum.KeyCode.Up then keysDown.Up = down
	elseif input.KeyCode == Enum.KeyCode.Down then keysDown.Down = down
	elseif input.KeyCode == Enum.KeyCode.Left then keysDown.Left = down
	elseif input.KeyCode == Enum.KeyCode.Right then keysDown.Right = down
	end
end

local function hasTemporaryFlight()
	local expire = tonumber(player:GetAttribute("TemporaryFlightExpireUnix")) or 0
	return expire > os.time()
end

local function ownsFlight()
	return player:GetAttribute("FlightAbilityOwned") == true or hasTemporaryFlight()
end

local function flightEquipped()
	return ownsFlight()
		and (player:GetAttribute("FlightAbilityEquipped") == true or player:GetAttribute("EquippedAbility") == "Flight" or hasTemporaryFlight())
end

local function sendState(force)
	if force or active ~= lastSentActive or powered ~= lastSentPowered then
		lastSentActive = active
		lastSentPowered = powered
		FlightAbilityState:FireServer(active, powered)
	end
end

local function setTrack(track, playing)
	if not track then return end
	if playing then
		if not track.IsPlaying then
			track:Play(0.15, 1, 1)
		end
	else
		if track.IsPlaying then
			track:Stop(0.15)
		end
	end
end

local function syncAnimation()
	if not active then
		setTrack(poweredTrack, false)
		setTrack(glideTrack, false)
	elseif powered then
		setTrack(glideTrack, false)
		setTrack(poweredTrack, true)
	else
		setTrack(poweredTrack, false)
		setTrack(glideTrack, true)
	end
end

local function setVfxVisualEnabled(container, enabled)
	if not container then return end
	local function apply(object)
		if object:IsA("ParticleEmitter") or object:IsA("Beam") or object:IsA("Trail") then
			local original = flightVfxEnabledStates[object]
			if original == nil then
				original = object.Enabled
				flightVfxEnabledStates[object] = original
			end
			object.Enabled = enabled and original or false
		end
	end
	apply(container)
	for _, descendant in ipairs(container:GetDescendants()) do
		apply(descendant)
	end
end

local function getVfxBaseParts(container)
	local parts = {}
	if container:IsA("BasePart") then
		table.insert(parts, container)
	end
	for _, descendant in ipairs(container:GetDescendants()) do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end
	return parts
end

local function getVfxTargetCFrame(head, slotName)
	if slotName == "Glide" then
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		if rootPart and rootPart:IsA("BasePart") then
			local forward = Vector3.new(rootPart.CFrame.LookVector.X, 0, rootPart.CFrame.LookVector.Z)
			if forward.Magnitude > 0.001 then
				forward = forward.Unit
				local stableHeadFrame = CFrame.lookAt(
					head.Position,
					head.Position + forward,
					Vector3.yAxis
				)
				return stableHeadFrame * GLIDE_VFX_HEAD_OFFSET, rootPart
			end
		end
		return head.CFrame * GLIDE_VFX_HEAD_OFFSET, head
	end

	return head.CFrame * POWERED_VFX_HEAD_OFFSET, head
end

local function moveVfxToHead(container, target, parts)
	if container:IsA("Model") then
		container:PivotTo(target)
	elseif container:IsA("BasePart") then
		container.CFrame = target
	elseif #parts > 0 then
		local source = parts[1].CFrame
		local delta = target * source:Inverse()
		for _, part in ipairs(parts) do
			part.CFrame = delta * part.CFrame
		end
	end
end

local function createHeadVfx(templateName, slotName)
	if not character or not character.Parent then return nil end
	local head = character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then return nil end

	local template = ReplicatedStorage:FindFirstChild(templateName)
	if not template then
		if not warnedMissingVfx[templateName] then
			warnedMissingVfx[templateName] = true
			warn(SCRIPT_TAG .. " Missing ReplicatedStorage." .. templateName .. "; Flight still works without this VFX.")
		end
		return nil
	end

	local clone = template:Clone()
	clone.Name = "FlightAbility_" .. slotName .. "VFX"
	clone.Parent = character

	local parts = getVfxBaseParts(clone)
	if #parts == 0 then
		clone:Destroy()
		if not warnedMissingVfx[templateName .. "_parts"] then
			warnedMissingVfx[templateName .. "_parts"] = true
			warn(SCRIPT_TAG .. " " .. templateName .. " has no BasePart to attach to the Head.")
		end
		return nil
	end

	local targetCFrame, weldParentPart = getVfxTargetCFrame(head, slotName)
	moveVfxToHead(clone, targetCFrame, parts)
	for _, part in ipairs(parts) do
		part.Anchored = false
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Massless = true
		part.Transparency = 1

		local weld = Instance.new("WeldConstraint")
		weld.Name = "FlightAbilityHeadWeld"
		weld.Part0 = weldParentPart
		weld.Part1 = part
		weld.Parent = part
	end

	setVfxVisualEnabled(clone, false)
	return clone
end

local function destroyFlightVfx()
	for key, instance in pairs(flightVfx) do
		if instance then
			instance:Destroy()
			flightVfx[key] = nil
		end
	end
	flightVfxEnabledStates = setmetatable({}, { __mode = "k" })
end

local function ensureFlightVfx()
	if not character or not character.Parent then return end
	if not flightVfx.powered or not flightVfx.powered.Parent then
		flightVfx.powered = createHeadVfx(POWERED_VFX_TEMPLATE_NAME, "Powered")
	end
	if not flightVfx.glide or not flightVfx.glide.Parent then
		flightVfx.glide = createHeadVfx(GLIDE_VFX_TEMPLATE_NAME, "Glide")
	end
end

local function syncFlightVfx()
	if active then
		ensureFlightVfx()
	end
	setVfxVisualEnabled(flightVfx.powered, active and powered)
	setVfxVisualEnabled(flightVfx.glide, active and not powered)
end

local function stopFlightLoopSound()
	if flightLoopSound then
		flightLoopSound:Stop()
		flightLoopSound:Destroy()
		flightLoopSound = nil
	end
end

local function ensureFlightLoopSound()
	if not root or not root.Parent then return nil end
	if flightLoopSound and flightLoopSound.Parent == root then
		return flightLoopSound
	end
	stopFlightLoopSound()
	local sound = Instance.new("Sound")
	sound.Name = "FlightAbilityLoopSound"
	sound.SoundId = tostring(Config.AbilityFlightLoopSoundId or "rbxassetid://596046130")
	sound.Volume = math.max(0, tonumber(Config.AbilityFlightLoopSoundVolume) or 1.0)
	sound.Looped = true
	sound.PlaybackSpeed = 1
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 8
	sound.RollOffMaxDistance = 70
	sound.Parent = root
	flightLoopSound = sound
	return sound
end

local function syncFlightLoopSound()
	if not active then
		stopFlightLoopSound()
		return
	end
	local sound = ensureFlightLoopSound()
	if sound and not sound.IsPlaying then
		sound:Play()
	end
end

local function isRunSound(sound)
	if not sound or not sound:IsA("Sound") then return false end
	if sound.SoundId == RUN_TREADMILL_SOUND_ID then return true end
	local name = sound.Name:lower()
	return name == "running" or name:find("speedsterruntreadmillsound", 1, true) ~= nil
end

local function registerRootSound(child)
	if child and child:IsA("Sound") and isRunSound(child) then
		runSoundsToSuppress[child] = true
	end
end

local function bindRunSoundSuppression()
	if rootChildAddedConnection then
		rootChildAddedConnection:Disconnect()
		rootChildAddedConnection = nil
	end
	runSoundsToSuppress = setmetatable({}, { __mode = "k" })
	if not root then return end
	for _, child in ipairs(root:GetChildren()) do
		registerRootSound(child)
	end
	rootChildAddedConnection = root.ChildAdded:Connect(registerRootSound)
end

local function suppressRunningSoundsWhileFlying()
	if not active then return end
	for sound in pairs(runSoundsToSuppress) do
		if sound.Parent == root then
			if sound.IsPlaying then sound:Stop() end
		else
			runSoundsToSuppress[sound] = nil
		end
	end
end

local function destroyConstraints()
	if flightVelocity then flightVelocity:Destroy() flightVelocity = nil end
	if flightOrientation then flightOrientation:Destroy() flightOrientation = nil end
	if flightAttachment then flightAttachment:Destroy() flightAttachment = nil end
end

local function ensureConstraints()
	if not root or not root.Parent then return false end
	if flightAttachment and flightAttachment.Parent == root
		and flightVelocity and flightVelocity.Parent == root
		and flightOrientation and flightOrientation.Parent == root
	then
		return true
	end
	destroyConstraints()

	flightAttachment = Instance.new("Attachment")
	flightAttachment.Name = "FlightAbilityAttachment"
	flightAttachment.Parent = root

	flightVelocity = Instance.new("LinearVelocity")
	flightVelocity.Name = "FlightAbilityVelocity"
	flightVelocity.Attachment0 = flightAttachment
	flightVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	flightVelocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	flightVelocity.ForceLimitsEnabled = false
	flightVelocity.VectorVelocity = Vector3.zero
	flightVelocity.Parent = root

	flightOrientation = Instance.new("AlignOrientation")
	flightOrientation.Name = "FlightAbilityOrientation"
	flightOrientation.Attachment0 = flightAttachment
	flightOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	flightOrientation.RigidityEnabled = false
	flightOrientation.Responsiveness = tonumber(Config.AbilityFlightOrientationResponse) or 34
	flightOrientation.MaxTorque = math.huge
	flightOrientation.CFrame = root.CFrame.Rotation
	flightOrientation.Parent = root
	return true
end

local function nearGround()
	if not root or not character then return false end
	if humanoid and humanoid.FloorMaterial ~= Enum.Material.Air then return true end
	raycastParams.FilterDescendantsInstances = {character}
	local distance = math.max(3.2, (humanoid and humanoid.HipHeight or 2) + root.Size.Y * 0.5 + 0.9)
	local result = Workspace:Raycast(root.Position, Vector3.new(0, -distance, 0), raycastParams)
	return result ~= nil and result.Distance <= distance - 0.1
end

local function applyOwnedJumpRule()
	if not humanoid or not humanoid.Parent then return end
	pcall(function()
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
	end)
end

local function stopFlight(landed)
	if not active then return end
	active = false
	powered = false
	spaceHeld = false
	canInitiateFlight = false
	if character and character.Parent then
		character:SetAttribute("FlightAbilityLocalActive", false)
	end
	syncAnimation()
	syncFlightVfx()
	syncFlightLoopSound()
	destroyConstraints()
	if humanoid and humanoid.Parent then
		humanoid.AutoRotate = originalAutoRotate
		if humanoid.Health > 0 then
			humanoid:ChangeState(landed and Enum.HumanoidStateType.Running or Enum.HumanoidStateType.Freefall)
		end
	end
	if root and root.Parent then
		root.AssemblyAngularVelocity = Vector3.zero
		if not landed then
			local vel = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(vel.X * 0.5, math.min(vel.Y, 0), vel.Z * 0.5)
		end
	end
	sendState(true)
end

local function onBarrierHit()
	lastBarrierTouch = os.clock()
	if active then
		stopFlight(false)
		if root and root.Parent then
			local vel = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(0, math.min(vel.Y, 0), 0)
			root.AssemblyAngularVelocity = Vector3.zero
		end
		pcall(function()
			StaminaFeedback.Notify("fly")
		end)
	end
end

-- Lift-off costs a share of this player's own bar. A flat threshold meant the
-- FlashSuit (5 stamina) needed a full bar to fly at all, which read as "flight
-- is broken" rather than "flight is expensive".
local function getMaxStamina()
	local attr = tonumber(player:GetAttribute("TrueBoostStaminaMax"))
	if attr and attr > 0 then
		return attr
	end
	return tonumber(Config.BoostStaminaDisplayBase) or 17
end

local function getStamina()
	local attr = player:GetAttribute("TrueBoostStamina")
	if attr == nil then return 100 end
	return math.max(0, tonumber(attr) or 0)
end

local function canPower()
	return getStamina() >= FlightStamina.MinimumToPower(Config, getMaxStamina())
end

local function setPowered(value)
	value = value == true and active and spaceHeld and canPower()
	if powered == value then return end
	powered = value
	syncAnimation()
	syncFlightVfx()
	sendState(false)
end

local function isDeadOrRagdolled()
	if not character or not humanoid then return true end
	if humanoid.Health <= 0 then return true end
	if character:GetAttribute("Dead") == true or character:GetAttribute("Ragdolled") == true then return true end
	if player:GetAttribute("Ragdolled") == true or player:GetAttribute("Dead") == true then return true end
	if humanoid.PlatformStand == true then return true end
	local st = humanoid:GetState()
	-- IMPORTANT: Physics is the intentional state used while flying.
	-- Treating Physics as ragdoll makes the ability cancel itself immediately.
	if st == Enum.HumanoidStateType.Dead or st == Enum.HumanoidStateType.Ragdoll then
		return true
	end
	return false
end

local function startFlight()
	if isDeadOrRagdolled() then return end
	if active or not flightEquipped() or not humanoid or not root then return end
	if humanoid.Health <= 0 or humanoid.Sit or root.Anchored or player:GetAttribute("AdminFlying") == true then return end
	if not canPower() then return end
	if os.clock() - lastBarrierTouch < 0.5 or isCharacterTouchingBarrier() then return end

	canInitiateFlight = false
	active = true
	powered = true
	flightStartedAt = os.clock()
	originalAutoRotate = humanoid.AutoRotate
	humanoid.AutoRotate = false
	humanoid.Jump = false
	character:SetAttribute("FlightAbilityLocalActive", true)
	if not ensureConstraints() then
		stopFlight(false)
		return
	end
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	root.AssemblyAngularVelocity = Vector3.zero
	syncAnimation()
	syncFlightVfx()
	syncFlightLoopSound()
	sendState(true)
end

local function cameraRelativeKeyboardDirection()
	local x = 0
	local z = 0
	if keysDown.W or keysDown.Up then z += 1 end
	if keysDown.S or keysDown.Down then z -= 1 end
	if keysDown.D or keysDown.Right then x += 1 end
	if keysDown.A or keysDown.Left then x -= 1 end
	local input = Vector2.new(x, z)
	if input.Magnitude <= 0.01 then return nil end
	if input.Magnitude > 1 then input = input.Unit end

	local camera = Workspace.CurrentCamera
	if not camera then return nil end
	local forward = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
	local right = Vector3.new(camera.CFrame.RightVector.X, 0, camera.CFrame.RightVector.Z)
	if forward.Magnitude <= 0.001 or right.Magnitude <= 0.001 then return nil end
	forward = forward.Unit
	right = right.Unit
	local direction = right * input.X + forward * input.Y
	return direction.Magnitude > 0.001 and direction.Unit or nil
end

local function getMoveDirection()
	if humanoid then
		local move = Vector3.new(humanoid.MoveDirection.X, 0, humanoid.MoveDirection.Z)
		if move.Magnitude > 0.03 then return move.Unit end
	end
	local keyboard = cameraRelativeKeyboardDirection()
	if keyboard then return keyboard end
	return Vector3.zero
end

local function getFacingDirection(moveDirection)
	if moveDirection.Magnitude > 0.03 then return moveDirection end
	local camera = Workspace.CurrentCamera
	if camera then
		local look = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
		if look.Magnitude > 0.001 then return look.Unit end
	end
	if root then
		local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
		if look.Magnitude > 0.001 then return look.Unit end
	end
	return -Vector3.zAxis
end

local function loadAnimation(animationId, name)
	if not animator or animationId == "" then return nil end
	local animation = Instance.new("Animation")
	animation.Name = name
	animation.AnimationId = animationId
	local ok, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	animation:Destroy()
	if not ok or not track then
		warn(SCRIPT_TAG .. " Could not load " .. name .. ": " .. tostring(track))
		return nil
	end
	track.Name = name
	track.Priority = Enum.AnimationPriority.Action4
	track.Looped = true
	return track
end

local function bindCharacter(newCharacter)
	stopFlight(false)
	destroyFlightVfx()
	character = newCharacter
	humanoid = character:WaitForChild("Humanoid", 10)
	root = character:WaitForChild("HumanoidRootPart", 10)
	animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if humanoid and not animator then
		animator = humanoid:WaitForChild("Animator", 5)
	end
	poweredTrack = loadAnimation(tostring(Config.AbilityFlightPoweredAnimationId or ""), "FlightPoweredAnimation")
	glideTrack = loadAnimation(tostring(Config.AbilityFlightGlideAnimationId or ""), "FlightGlideAnimation")
	bindRunSoundSuppression()
	if character then character:SetAttribute("FlightAbilityLocalActive", false) end
	applyOwnedJumpRule()
	canInitiateFlight = nearGround() and not isDeadOrRagdolled()
	if humanoid then
		local function onDeathOrRagdoll()
			stopFlight(false)
			canInitiateFlight = false
		end
		humanoid.Died:Connect(onDeathOrRagdoll)
		humanoid.HealthChanged:Connect(function(health)
			if health <= 0 then
				onDeathOrRagdoll()
			end
		end)
		humanoid:GetPropertyChangedSignal("PlatformStand"):Connect(function()
			if humanoid.PlatformStand then
				onDeathOrRagdoll()
			end
		end)
		humanoid.StateChanged:Connect(function(_, newState)
			-- Physics is valid while Flight is active.
			if newState == Enum.HumanoidStateType.Dead or newState == Enum.HumanoidStateType.Ragdoll then
				onDeathOrRagdoll()
			end
		end)
	end
	if character then
		character:GetAttributeChangedSignal("Ragdolled"):Connect(function()
			if character:GetAttribute("Ragdolled") == true then
				stopFlight(false)
				canInitiateFlight = false
			end
		end)
		character:GetAttributeChangedSignal("Dead"):Connect(function()
			if character:GetAttribute("Dead") == true then
				stopFlight(false)
				canInitiateFlight = false
			end
		end)

		for _, conn in ipairs(characterTouchedConnections) do
			conn:Disconnect()
		end
		table.clear(characterTouchedConnections)

		local function hookBarrierTouch(part)
			if part:IsA("BasePart") then
				table.insert(characterTouchedConnections, part.Touched:Connect(function(hit)
					if isBarrierPart(hit) then
						onBarrierHit()
					end
				end))
			end
		end

		for _, desc in ipairs(character:GetDescendants()) do
			hookBarrierTouch(desc)
		end
		table.insert(characterTouchedConnections, character.DescendantAdded:Connect(hookBarrierTouch))
	end
end

local function beginFlightHold()
	if isDeadOrRagdolled() then return end
	if spaceHeld then return end
	spaceHeld = true
	spaceHoldSerial += 1
	local mySerial = spaceHoldSerial

	if not flightEquipped() then return end
	if not canPower() then
		-- Only a hold that would have turned into flight says so; an ordinary jump
		-- with a low bar stays quiet.
		task.delay(FLIGHT_HOLD_SECONDS, function()
			if mySerial == spaceHoldSerial and spaceHeld and flightEquipped() and not canPower() and not isDeadOrRagdolled() then
				StaminaFeedback.Notify("fly")
			end
		end)
		return
	end
	if active then
		setPowered(true)
		return
	end

	local delaySeconds = FLIGHT_HOLD_SECONDS
	task.delay(delaySeconds, function()
		if not isDeadOrRagdolled() and windowFocused and not player:GetAttribute("SpeedsterMenuOpen") and not GuiService.MenuIsOpen and not GuiService.SelectedObject and not UserInputService:GetFocusedTextBox() and mySerial == spaceHoldSerial and spaceHeld and flightEquipped() and not active and canPower() and os.clock() - lastBarrierTouch >= 0.5 and not isCharacterTouchingBarrier() then
			startFlight()
		end
	end)
end

local function endFlightHold()
	if not spaceHeld then return end
	spaceHeld = false
	spaceHoldSerial += 1
	if active then setPowered(false) end
end

-- ==============================================================================
-- SISTEMA DE ENTRADA MULTIPLATAFORMA (PC, CONSOLAS Y MÓVIL)
-- ==============================================================================
local heldInputs = {}

local function holdInput(inputIdentifier, down)
	if down then
		if not windowFocused or player:GetAttribute("SpeedsterMenuOpen") or GuiService.MenuIsOpen or GuiService.SelectedObject ~= nil or UserInputService:GetFocusedTextBox() then return end
		heldInputs[inputIdentifier] = true
		beginFlightHold()
	else
		heldInputs[inputIdentifier] = nil
		if next(heldInputs) == nil then
			endFlightHold()
		end
	end
end

local function releaseInputs()
	table.clear(heldInputs)
	for key in pairs(keysDown) do keysDown[key] = false end
	endFlightHold()
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if not gameProcessed then
		setKey(input, true)
	end
	if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA or input.KeyCode == Enum.KeyCode.ButtonR1 then
		if not gameProcessed and not UserInputService:GetFocusedTextBox() and not GuiService.MenuIsOpen and GuiService.SelectedObject == nil then
			holdInput(input.KeyCode, true)
		end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	setKey(input, false)
	if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA or input.KeyCode == Enum.KeyCode.ButtonR1 then
		holdInput(input.KeyCode, false)
	end
end)

ContextActionService:BindActionAtPriority("SpeedsterFlightHold", function(_, state, input)
	if state == Enum.UserInputState.Begin then
		holdInput(input.KeyCode, true)
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		holdInput(input.KeyCode, false)
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Space, Enum.KeyCode.ButtonA, Enum.KeyCode.ButtonR1)

local boundMobileJumpButtons = setmetatable({}, { __mode = "k" })

local function bindMobileJumpButton(instance)
	if not instance:IsA("GuiButton") then return end
	local name = instance.Name:lower()
	if name ~= "jumpbutton" and not name:find("jump") then return end
	if boundMobileJumpButtons[instance] then return end
	boundMobileJumpButtons[instance] = true

	local function onTouchDown()
		holdInput("MobileJumpButton", true)
	end

	local function onTouchUp()
		holdInput("MobileJumpButton", false)
	end

	instance.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			onTouchDown()
		end
	end)

	instance.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			onTouchUp()
		end
	end)

	instance.MouseButton1Down:Connect(onTouchDown)
	instance.MouseButton1Up:Connect(onTouchUp)
end

local playerGui = player:WaitForChild("PlayerGui")
for _, descendant in ipairs(playerGui:GetDescendants()) do
	bindMobileJumpButton(descendant)
end
playerGui.DescendantAdded:Connect(bindMobileJumpButton)

local controls
task.spawn(function()
	local playerScripts = player:WaitForChild("PlayerScripts", 10)
	if not playerScripts then return end
	local playerModule = playerScripts:WaitForChild("PlayerModule", 10)
	if not playerModule then return end
	pcall(function()
		controls = require(playerModule):GetControls()
	end)
end)

local function isPlayerModuleJumping()
	if not controls then return false end
	local ok, jumping = pcall(function()
		local activeCtrl = controls:GetActiveController()
		if activeCtrl then
			if typeof(activeCtrl.GetIsJumping) == "function" and activeCtrl:GetIsJumping() then
				return true
			end
			if activeCtrl.isJumping == true then
				return true
			end
		end
		local touchJump = controls.touchJumpController
		if touchJump then
			if typeof(touchJump.GetIsJumping) == "function" and touchJump:GetIsJumping() then
				return true
			end
			if touchJump.isJumping == true then
				return true
			end
		end
		return false
	end)
	return ok and jumping == true
end

UserInputService.WindowFocusReleased:Connect(function() windowFocused = false; releaseInputs() end)
UserInputService.WindowFocused:Connect(function() windowFocused = true end)
UserInputService.TextBoxFocused:Connect(releaseInputs)
player:GetAttributeChangedSignal("SpeedsterMenuOpen"):Connect(function() if player:GetAttribute("SpeedsterMenuOpen") then releaseInputs() end end)
UserInputService.GamepadDisconnected:Connect(releaseInputs)
GuiService.MenuOpened:Connect(releaseInputs)
GuiService:GetPropertyChangedSignal("SelectedObject"):Connect(function()
	if GuiService.SelectedObject then releaseInputs() end
end)

UserInputService.JumpRequest:Connect(function()
	if isDeadOrRagdolled() then return end
	if not windowFocused or player:GetAttribute("SpeedsterMenuOpen") or GuiService.MenuIsOpen or GuiService.SelectedObject or UserInputService:GetFocusedTextBox() then return end
	if not flightEquipped() or not humanoid or humanoid.Health <= 0 then return end
	if active then
		if not canPower() then
			StaminaFeedback.Notify("fly")
			stopFlight(false)
			return
		end
		if spaceHeld then setPowered(true) end
		return
	end
	humanoid.Jump = true
	lastJumpAt = os.clock()
end)

local function syncFlightUsability()
	applyOwnedJumpRule()
	if not flightEquipped() or isDeadOrRagdolled() then
		canInitiateFlight = false
		if active then
			stopFlight(false)
		end
	else
		if not nearGround() then
			canInitiateFlight = false
		end
	end
end

player:GetAttributeChangedSignal("FlightAbilityOwned"):Connect(syncFlightUsability)
player:GetAttributeChangedSignal("FlightAbilityEquipped"):Connect(syncFlightUsability)
player:GetAttributeChangedSignal("EquippedAbility"):Connect(syncFlightUsability)
player:GetAttributeChangedSignal("Ragdolled"):Connect(function()
	if player:GetAttribute("Ragdolled") == true then
		canInitiateFlight = false
		if active then
			stopFlight(false)
		end
	end
end)
player:GetAttributeChangedSignal("Dead"):Connect(function()
	if player:GetAttribute("Dead") == true then
		canInitiateFlight = false
		if active then
			stopFlight(false)
		end
	end
end)

player:GetAttributeChangedSignal("FlightAbilityPowered"):Connect(function()
	if active and player:GetAttribute("FlightAbilityPowered") == false and powered then
		powered = false
		syncAnimation()
		syncFlightVfx()
	end
end)

player:GetAttributeChangedSignal("FlightAbilityActive"):Connect(function()
	if player:GetAttribute("FlightAbilityActive") ~= true and active then
		stopFlight(false)
	end
end)

FlightAbilityState.OnClientEvent:Connect(function(serverActive, serverPowered)
	if serverActive == false and active then
		stopFlight(false)
	end
end)

local function stepFlight(dt)
	if isDeadOrRagdolled() then
		canInitiateFlight = false
		if active then
			stopFlight(false)
		end
		return
	end

	if active and isCharacterTouchingBarrier() then
		onBarrierHit()
		return
	end

	local isTextBoxFocused = UserInputService:GetFocusedTextBox() ~= nil
	local isHoldingJumpUniversal = not isTextBoxFocused and (
		UserInputService:IsKeyDown(Enum.KeyCode.Space)
		or isPlayerModuleJumping()
		or UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonA)
		or UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad2, Enum.KeyCode.ButtonA)
		or UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonR1)
		or UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad2, Enum.KeyCode.ButtonR1)
	)

	if isHoldingJumpUniversal then
		if not heldInputs["PolledJumpState"] then
			holdInput("PolledJumpState", true)
		end
	else
		if heldInputs["PolledJumpState"] then
			holdInput("PolledJumpState", false)
		end
	end

	local isGrounded = nearGround()
	if isGrounded and not isDeadOrRagdolled() then
		lastGroundedAt = os.clock()
		if not active then
			canInitiateFlight = true
		end
	end

	-- Jump once, then keep the button held. As soon as the player is off the
	-- ground from that jump, flight engages. The ground hold timer stays as the
	-- no-jump fallback, but nobody has to tap their way into the air any more.
	if not active
		and spaceHeld
		and not isGrounded
		and os.clock() - lastJumpAt >= AIRBORNE_HOLD_SECONDS
		and os.clock() - lastJumpAt <= 6
		and flightEquipped()
		and canPower()
		and not isDeadOrRagdolled()
		and os.clock() - lastBarrierTouch >= 0.5
		and not isCharacterTouchingBarrier()
	then
		startFlight()
	end

	if not active then return end
	if not character or not character.Parent or not humanoid or humanoid.Health <= 0 or not root or not root.Parent then
		stopFlight(false)
		return
	end
	if isCharacterTouchingBarrier() then
		onBarrierHit()
		return
	end
	if not flightEquipped() or humanoid.Sit or player:GetAttribute("AdminFlying") == true then
		stopFlight(false)
		return
	end
	if not flightVelocity or not flightVelocity.Parent or not flightOrientation or not flightOrientation.Parent then
		if not ensureConstraints() then
			stopFlight(false)
			return
		end
	end

	syncFlightLoopSound()

	-- Gliding draws stamina as well, so flight ends when the bar empties instead
	-- of coasting across the stage. Set AbilityFlightGlideDrainPercentPerSecond
	-- to 0 to restore unlimited gliding.
	if FlightStamina.GlideDrainPerSecond(Config, getMaxStamina()) > 0 and getStamina() <= 0 then
		StaminaFeedback.Notify("fly")
		stopFlight(false)
		return
	end

	if powered and (not spaceHeld or not canPower()) then
		if spaceHeld then
			-- Still holding to climb, but the bar cannot pay for it.
			StaminaFeedback.Notify("fly")
		end
		setPowered(false)
	elseif not powered and spaceHeld and canPower() then
		setPowered(true)
	end

	local normalRunSpeed = math.max(0, tonumber(player:GetAttribute("RealWalkSpeedSelected")) or (humanoid and humanoid.WalkSpeed) or 0)
	local moveDirection = getMoveDirection()
	local facing = getFacingDirection(moveDirection)
	local targetVelocity

	if powered then
		local horizontalSpeed = math.max(35, normalRunSpeed * (tonumber(Config.AbilityFlightPoweredSpeedMultiplier) or 0.3151))
		local upSpeed = math.max(
			tonumber(Config.AbilityFlightMinimumUpSpeed) or 24.66,
			normalRunSpeed * (tonumber(Config.AbilityFlightVerticalSpeedMultiplier) or 0.3151)
		)
		targetVelocity = moveDirection * horizontalSpeed + Vector3.new(0, upSpeed, 0)
	else
		local glideDirection = moveDirection.Magnitude > 0.03 and moveDirection or facing
		local forwardSpeed = math.max(45, normalRunSpeed * (tonumber(Config.AbilityFlightGlideForwardMultiplier) or 1.2519))
		local downSpeed = math.max(
			tonumber(Config.AbilityFlightGlideMinimumDownSpeed) or 8.0,
			math.min(18.0, normalRunSpeed * (tonumber(Config.AbilityFlightGlideDownRunMultiplier) or 0.08))
		)
		local camera = Workspace.CurrentCamera
		if camera then
			local pitch = camera.CFrame.LookVector.Y
			local pitchFactor = math.clamp(1 + pitch * -0.5, 0.6, 1.4)
			downSpeed = downSpeed * pitchFactor
			if pitch < -0.15 then
				forwardSpeed = forwardSpeed * (1 + math.abs(pitch) * 0.35)
			end
		end
		targetVelocity = glideDirection * forwardSpeed + Vector3.new(0, -downSpeed, 0)
	end

	local currentTarget = flightVelocity.VectorVelocity
	local steeringResponse = tonumber(Config.AbilityFlightSteeringResponse) or 28
	local alpha = 1 - math.exp(-steeringResponse * math.clamp(dt, 0, 0.05))
	flightVelocity.VectorVelocity = currentTarget:Lerp(targetVelocity, alpha)
	root.AssemblyAngularVelocity = Vector3.zero

	local flatFacing = Vector3.new(facing.X, 0, facing.Z)
	if flatFacing.Magnitude > 0.001 then
		flightOrientation.CFrame = CFrame.lookAt(Vector3.zero, flatFacing.Unit, Vector3.yAxis).Rotation
	end

	if not powered and os.clock() - flightStartedAt > 0.28 and nearGround() then
		stopFlight(true)
	end
end

RunService.Heartbeat:Connect(stepFlight)
RunService.RenderStepped:Connect(suppressRunningSoundsWhileFlying)

if player.Character then task.defer(bindCharacter, player.Character) end
player.CharacterAdded:Connect(bindCharacter)
player.CharacterRemoving:Connect(function(removing)
	if removing == character then
		releaseInputs()
		stopFlight(false)
		character = nil
		humanoid = nil
		root = nil
		animator = nil
		poweredTrack = nil
		glideTrack = nil
		if rootChildAddedConnection then
			rootChildAddedConnection:Disconnect()
			rootChildAddedConnection = nil
		end
		runSoundsToSuppress = setmetatable({}, { __mode = "k" })
		stopFlightLoopSound()
		destroyFlightVfx()
	end
end)

print(SCRIPT_TAG .. " Client active | Cross-platform ready")