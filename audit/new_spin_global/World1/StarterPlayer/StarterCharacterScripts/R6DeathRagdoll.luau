--[[
	Modern Ragdoll System for Speedster (World 1 & World 2)
	Adapted from Jump Showdown's proven physical ragdoll architecture.
	Features:
	- Pre-built RagdollComponents with smooth RagdollColliders (prevents limb flinging / floor clipping)
	- Stabilizing RagdollWeld (locks Torso to HumanoidRootPart during ragdoll so camera follows naturally)
	- Tuned BallSocketConstraints with calibrated AttachmentCFrames and MaxFrictionTorque damping
	- Full support for both Death Ragdoll and Live Ragdoll (stun / trip / commands)
	- StandUpright recovery with floor raycasting and smooth upright orientation
	- R6 native support with universal R15 fallback
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local character = script.Parent
local humanoid = character:WaitForChild("Humanoid", 10)
local rootPart = character:WaitForChild("HumanoidRootPart", 10)

if not humanoid or not rootPart then
	return
end

humanoid.BreakJointsOnDeath = false
humanoid.RequiresNeck = false

-- Disable internal Roblox Dead & Ragdoll states to eliminate death freeze stutter
humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)

local isR6 = (humanoid.RigType == Enum.HumanoidRigType.R6)
local torso = isR6 and character:WaitForChild("Torso", 10) or character:WaitForChild("UpperTorso", 10)
if not torso then
	return
end

-- Jump Showdown Calibrated R6 Attachment CFrames
local R6_ATTACHMENT_CFRAMES = {
	["Neck"] = {
		CFrame.new(0, 1, 0, 0, -1, 0, 1, 0, -0, 0, 0, 1),
		CFrame.new(0, -0.5, 0, 0, -1, 0, 1, 0, -0, 0, 0, 1),
	},
	["Left Shoulder"] = {
		CFrame.new(-1.3, 0.75, 0, -1, 0, 0, 0, -1, 0, 0, 0, 1),
		CFrame.new(0.2, 0.75, 0, -1, 0, 0, 0, -1, 0, 0, 0, 1),
	},
	["Right Shoulder"] = {
		CFrame.new(1.3, 0.75, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1),
		CFrame.new(-0.2, 0.75, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1),
	},
	["Left Hip"] = {
		CFrame.new(-0.5, -1, 0, 0, 1, -0, -1, 0, 0, 0, 0, 1),
		CFrame.new(0, 1, 0, 0, 1, -0, -1, 0, 0, 0, 0, 1),
	},
	["Right Hip"] = {
		CFrame.new(0.5, -1, 0, 0, 1, -0, -1, 0, 0, 0, 0, 1),
		CFrame.new(0, 1, 0, 0, 1, -0, -1, 0, 0, 0, 0, 1),
	},
}

local WEAPON_MOTORS = {
	KukriMotor = true,
	WhipMotor = true,
	JuliusMotor = true,
	["Kukri Handle og.001"] = true,
	Handle = true,
}

local GET_UP_ANIMATION_ID = "rbxassetid://137493859009439"

local jointsFolder = nil
local smoothingWeld = nil
local activeTimer = nil
local getUpTrack = nil
local isRagdolled = false

-- Preload GetUp animation safely
local function setupGetUpAnimation()
	pcall(function()
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = humanoid
		end
		local anim = Instance.new("Animation")
		anim.AnimationId = GET_UP_ANIMATION_ID
		getUpTrack = animator:LoadAnimation(anim)
		getUpTrack.Priority = Enum.AnimationPriority.Action
	end)
end

setupGetUpAnimation()

-- Builds the RagdollComponents folder with smooth colliders and BallSocketConstraints
local function createJoints()
	if jointsFolder and jointsFolder.Parent then
		jointsFolder:Destroy()
		jointsFolder = nil
	end

	jointsFolder = Instance.new("Folder")
	jointsFolder.Name = "RagdollComponents"
	jointsFolder.Parent = character

	-- Stabilizing WeldConstraint connecting Torso to HumanoidRootPart without identity snap warps
	smoothingWeld = Instance.new("WeldConstraint")
	smoothingWeld.Name = "RagdollWeld"
	smoothingWeld.Part0 = rootPart
	smoothingWeld.Part1 = torso
	smoothingWeld.Enabled = false
	smoothingWeld.Parent = jointsFolder

	local function createCollider(limb: BasePart)
		if not limb or not limb:IsA("BasePart") then
			return nil
		end
		local collider = Instance.new("Part")
		collider.Name = limb.Name .. "_RagdollCollider"
		collider.Size = limb.Size / 1.25
		collider.CanCollide = false
		collider.CanQuery = false
		collider.CanTouch = false
		collider.Massless = true
		collider.CFrame = limb.CFrame
		collider.Transparency = 1
		collider:AddTag("RagdollCollider")
		pcall(function()
			collider.CollisionGroup = "Players"
		end)

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = collider
		weld.Part1 = limb
		weld.Parent = collider

		local noCollision = Instance.new("NoCollisionConstraint")
		noCollision.Part0 = limb
		noCollision.Part1 = collider
		noCollision.Parent = collider

		collider.Parent = jointsFolder
		return collider
	end

	createCollider(torso)

	if isR6 then
		-- R6 Setup with calibrated attachment CFrames
		for _, motor in ipairs(torso:GetChildren()) do
			if motor:IsA("Motor6D") and R6_ATTACHMENT_CFRAMES[motor.Name] then
				local limb = motor.Part1
				if not limb then
					continue
				end

				createCollider(limb)

				local att0 = Instance.new("Attachment")
				att0.Name = "RagdollAttachment0_" .. motor.Name
				att0.CFrame = R6_ATTACHMENT_CFRAMES[motor.Name][1]
				att0.Parent = motor.Part0

				local att1 = Instance.new("Attachment")
				att1.Name = "RagdollAttachment1_" .. motor.Name
				att1.CFrame = R6_ATTACHMENT_CFRAMES[motor.Name][2]
				att1.Parent = limb

				local socket = Instance.new("BallSocketConstraint")
				socket.Name = "RagdollSocket_" .. motor.Name
				socket.Attachment0 = att0
				socket.Attachment1 = att1
				socket.Radius = 0.15
				socket.LimitsEnabled = true
				socket.MaxFrictionTorque = 1.0
				socket.Restitution = 0.2

				if motor.Name == "Neck" then
					socket.TwistLimitsEnabled = true
					socket.UpperAngle = 45
					socket.TwistLowerAngle = -70
					socket.TwistUpperAngle = 70
				else
					socket.TwistLimitsEnabled = false
					socket.UpperAngle = 90
					socket.TwistLowerAngle = -45
					socket.TwistUpperAngle = 45
				end

				socket.Enabled = false
				socket.Parent = jointsFolder
			end
		end
	else
		-- Universal R15 Fallback
		for _, motor in ipairs(character:GetDescendants()) do
			if motor:IsA("Motor6D") and motor.Name ~= "Root" and motor.Name ~= "RootJoint" and not WEAPON_MOTORS[motor.Name] then
				local part0 = motor.Part0
				local part1 = motor.Part1
				if part0 and part1 then
					createCollider(part1)

					local att0 = Instance.new("Attachment")
					att0.Name = "RagdollAtt0_" .. motor.Name
					att0.CFrame = motor.C0
					att0.Parent = part0

					local att1 = Instance.new("Attachment")
					att1.Name = "RagdollAtt1_" .. motor.Name
					att1.CFrame = motor.C1
					att1.Parent = part1

					local socket = Instance.new("BallSocketConstraint")
					socket.Name = "RagdollSocket_" .. motor.Name
					socket.Attachment0 = att0
					socket.Attachment1 = att1
					socket.Radius = 0.15
					socket.LimitsEnabled = true
					socket.MaxFrictionTorque = 1.0
					socket.Restitution = 0.2
					socket.UpperAngle = 60
					socket.TwistLimitsEnabled = true
					socket.TwistLowerAngle = -45
					socket.TwistUpperAngle = 45
					socket.Enabled = false
					socket.Parent = jointsFolder
				end
			end
		end
	end
end

createJoints()

local function clearTimer()
	if activeTimer and coroutine.status(activeTimer) == "suspended" then
		task.cancel(activeTimer)
	end
	activeTimer = nil
end

-- Jump Showdown StandUpright logic: aligns horizontal rotation & repositions root above ground
local function standUpright(downwardDistance: number?)
	local dist = downwardDistance or 5.0
	local origin = rootPart.Position
	local direction = Vector3.new(0, -dist, 0)

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { character }
	rayParams.IgnoreWater = true

	local raycast = workspace:Raycast(origin, direction, rayParams)
	local groundY = raycast and raycast.Position.Y or (origin.Y - 2.5)

	-- Upright horizontal rotation matching current right-cross-down
	local rightVec = rootPart.CFrame.RightVector
	local flatLook = rightVec:Cross(-Vector3.yAxis)
	local uprightRot = CFrame.identity
	if flatLook.Magnitude > 0.001 then
		uprightRot = CFrame.lookAt(Vector3.zero, flatLook.Unit)
	else
		local look = rootPart.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude > 0.001 then
			uprightRot = CFrame.lookAt(Vector3.zero, flat.Unit)
		end
	end

	local targetY = groundY + (humanoid.HipHeight > 0 and (humanoid.HipHeight + 1.5) or 3.0)
	local targetPos = Vector3.new(origin.X, targetY, origin.Z)

	rootPart.CFrame = uprightRot + targetPos
	rootPart.AssemblyLinearVelocity = Vector3.zero
	rootPart.AssemblyAngularVelocity = Vector3.zero
end

-- Forward declaration of stopRagdoll
local stopRagdoll

local function startRagdoll(duration: number?)
	if not character.Parent or not humanoid or not rootPart then
		return
	end

	if isRagdolled then
		if duration and duration > 0 then
			clearTimer()
			activeTimer = task.delay(duration, function()
				stopRagdoll()
			end)
		end
		return
	end

	isRagdolled = true
	clearTimer()

	if not jointsFolder or not jointsFolder.Parent then
		createJoints()
	end

	-- Stop playing animations so they do not fight constraints
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
			if track.Speed == 0 then
				track:AdjustSpeed(1)
			end
			track:Stop(0)
		end
	end

	humanoid.AutoRotate = false
	humanoid.PlatformStand = true
	humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	character:SetAttribute("Ragdolled", true)

	-- Destroy any active flight physics objects so corpse/ragdoll cannot fly
	if rootPart then
		local flightVel = rootPart:FindFirstChild("FlightAbilityVelocity")
		if flightVel then flightVel:Destroy() end
		local flightAtt = rootPart:FindFirstChild("FlightAbilityAttachment")
		if flightAtt then flightAtt:Destroy() end
		local flightOrient = rootPart:FindFirstChild("FlightAbilityOrientation")
		if flightOrient then flightOrient:Destroy() end
	end
	character:SetAttribute("FlightAbilityLocalActive", false)
	local ragdollOwner = Players:GetPlayerFromCharacter(character)
	if ragdollOwner then
		ragdollOwner:SetAttribute("FlightAbilityActive", false)
		ragdollOwner:SetAttribute("FlightAbilityPowered", false)
	end

	-- Disable limb Motor6D joints (keep RootJoint connecting RootPart & Torso)
	if isR6 then
		for _, motor in ipairs(torso:GetChildren()) do
			if motor:IsA("Motor6D") and not motor:HasTag("DontModifyOnRagdoll") and not WEAPON_MOTORS[motor.Name] then
				motor.Enabled = false
			end
		end
	else
		for _, desc in ipairs(character:GetDescendants()) do
			if desc:IsA("Motor6D") and desc.Name ~= "Root" and desc.Name ~= "RootJoint" and not desc:HasTag("DontModifyOnRagdoll") and not WEAPON_MOTORS[desc.Name] then
				desc.Enabled = false
			end
		end
	end

	-- Enable BallSocketConstraints & Colliders
	if jointsFolder then
		for _, item in ipairs(jointsFolder:GetChildren()) do
			if item:IsA("BallSocketConstraint") then
				item.Enabled = true
			elseif item:IsA("BasePart") then
				item.CanCollide = true
			end
		end
	end

	-- Disable visual limb collision to prevent self-collision jitter
	for _, limb in ipairs(character:GetChildren()) do
		if limb:IsA("BasePart") and limb ~= rootPart then
			limb.CanCollide = false
		end
	end

	if smoothingWeld then
		smoothingWeld.Enabled = true
		local rj = rootPart and rootPart:FindFirstChild("RootJoint")
		if rj and rj:IsA("Motor6D") then
			rj.Enabled = false
		end
	end

	-- Check velocity validity
	if rootPart.AssemblyLinearVelocity.X ~= rootPart.AssemblyLinearVelocity.X then
		rootPart.AssemblyLinearVelocity = Vector3.zero
		rootPart.AssemblyAngularVelocity = Vector3.zero
	end

	-- Manage network ownership
	local player = Players:GetPlayerFromCharacter(character)
	if not player then
		pcall(function()
			if rootPart:CanSetNetworkOwnership() then
				rootPart:SetNetworkOwner(nil)
			end
		end)
	end

	if duration and duration > 0 then
		activeTimer = task.delay(duration, function()
			stopRagdoll()
		end)
	end
end

stopRagdoll = function()
	if not character.Parent or not humanoid or not rootPart then
		return
	end

	if not isRagdolled then
		return
	end

	-- If dead, do not stand up (remain as death ragdoll)
	if humanoid.Health <= 0 or humanoid:GetState() == Enum.HumanoidStateType.Dead then
		return
	end

	clearTimer()
	isRagdolled = false
	character:SetAttribute("Ragdolled", false)

	-- Disable BallSocketConstraints & Colliders
	if jointsFolder then
		for _, item in ipairs(jointsFolder:GetChildren()) do
			if item:IsA("BallSocketConstraint") then
				item.Enabled = false
			elseif item:IsA("BasePart") then
				item.CanCollide = false
			end
		end
	end

	if smoothingWeld then
		smoothingWeld.Enabled = false
		local rj = rootPart and rootPart:FindFirstChild("RootJoint")
		if rj and rj:IsA("Motor6D") then
			rj.Enabled = true
		end
	end

	-- Re-enable limb Motor6D joints
	if isR6 then
		for _, motor in ipairs(torso:GetChildren()) do
			if motor:IsA("Motor6D") and not WEAPON_MOTORS[motor.Name] then
				motor.Enabled = true
				motor.Transform = CFrame.identity
			end
		end
	else
		for _, desc in ipairs(character:GetDescendants()) do
			if desc:IsA("Motor6D") and not WEAPON_MOTORS[desc.Name] then
				desc.Enabled = true
				desc.Transform = CFrame.identity
			end
		end
	end

	humanoid.PlatformStand = false
	humanoid.AutoRotate = true
	humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)

	-- StandUpright alignment
	standUpright(6.0)

	local player = Players:GetPlayerFromCharacter(character)
	if player then
		pcall(function()
			if not rootPart.Anchored then
				rootPart:SetNetworkOwner(player)
			end
		end)
	end

	humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)

	-- Play GetUp animation if alive
	if getUpTrack then
		pcall(function()
			getUpTrack:Play(0.1, 1, 1)
		end)
	end
end

local isDead = false
local hasRespawned = false

local function triggerRespawn(delaySeconds: number?)
	if hasRespawned then return end
	hasRespawned = true
	isDead = true
	pcall(function()
		character:SetAttribute("Dead", true)
		character:SetAttribute("Ragdolled", true)
	end)

	local player = Players:GetPlayerFromCharacter(character)
	if player and player.Parent then
		local function performRespawn()
			if not player or not player.Parent or player.Character ~= character then
				return
			end
			-- Check if revive purchase is in progress or completed
			if player:GetAttribute("RevivePurchasePending") == true then
				-- Player is actively in the payment prompt or purchase modal: postpone respawn!
				task.delay(5.0, performRespawn)
				return
			end
			if player:GetAttribute("RevivedJustNow") == true then
				-- Player was revived! Cancel respawn entirely!
				return
			end
			if humanoid and humanoid.Health > 0 and character:GetAttribute("Dead") ~= true then
				-- Character was healed/revived!
				return
			end

			-- Enable Dead state right before LoadCharacter so Roblox PlayerModule & camera reset cleanly
			pcall(function()
				if humanoid and humanoid.Parent then
					humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
					humanoid:ChangeState(Enum.HumanoidStateType.Dead)
				end
			end)

			pcall(function()
				player:LoadCharacter()
			end)

			task.delay(0.25, function()
				if character and character.Parent then
					pcall(function()
						character:Destroy()
					end)
				end
			end)
		end

		local defaultDelay = delaySeconds or (Players.RespawnTime or 2.5)
		if type(defaultDelay) ~= "number" or defaultDelay < 1 then
			defaultDelay = math.max(1, Players.RespawnTime or 2.5)
		end

		local respawnTask = task.delay(defaultDelay, performRespawn)

		-- Revives load a fresh character. performRespawn checks character identity
		-- and RevivedJustNow so this old corpse cannot respawn over the replacement.

	else
		-- NPC cleanup
		task.delay(3, function()
			if character and character.Parent then
				pcall(function()
					character:Destroy()
				end)
			end
		end)
	end
end

local function onDied()
	if isDead then return end
	isDead = true
	clearTimer()
	startRagdoll(nil)
	triggerRespawn()
end

humanoid.Died:Connect(onDied)
humanoid.HealthChanged:Connect(function(health)
	if health <= 0 then
		onDied()
	end
end)

character:GetAttributeChangedSignal("Dead"):Connect(function()
	if character:GetAttribute("Dead") == true and not isDead then
		onDied()
	end
end)

character.Destroying:Connect(function()
	if not hasRespawned then
		triggerRespawn(0.5)
	end
end)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remotes = ReplicatedStorage:FindFirstChild("Remotes")
local resetRemote = remotes and remotes:FindFirstChild("PlayerResetRequest")
if resetRemote and resetRemote:IsA("RemoteEvent") then
	resetRemote.OnServerEvent:Connect(function(sender)
		local myPlayer = Players:GetPlayerFromCharacter(character)
		if sender == myPlayer and humanoid and humanoid.Health > 0 then
			humanoid.Health = 0
		end
	end)
end

-- Attribute trigger: Allows any script or command to set character:SetAttribute("Ragdolled", true/false)
character:GetAttributeChangedSignal("Ragdolled"):Connect(function()
	local val = character:GetAttribute("Ragdolled")
	local dur = character:GetAttribute("RagdollDuration")
	if val == true and not isRagdolled then
		startRagdoll(dur)
	elseif val == false and isRagdolled then
		stopRagdoll()
	end
end)

-- BindableEvent trigger for internal scripts
local bindable = character:FindFirstChild("RagdollEvent")
if not bindable then
	bindable = Instance.new("BindableEvent")
	bindable.Name = "RagdollEvent"
	bindable.Parent = character
end

bindable.Event:Connect(function(action: string, duration: number?)
	if action == "Ragdoll" or action == "Start" then
		startRagdoll(duration)
	elseif action == "Unragdoll" or action == "Stop" then
		stopRagdoll()
	elseif action == "Toggle" then
		if isRagdolled then
			stopRagdoll()
		else
			startRagdoll(duration)
		end
	end
end)

print("[RagdollSystem] JumpShowdown-based ragdoll controller active for " .. character.Name)
