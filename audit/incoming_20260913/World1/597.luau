local character = script.Parent
local humanoid = character:WaitForChild("Humanoid", 10)

if not humanoid then
	return
end

         
                                                                                    
                                                     
if humanoid.RigType ~= Enum.HumanoidRigType.R6 then
	return
end

                                                                           
                                                                           
                                                        
humanoid.BreakJointsOnDeath = false
humanoid.RequiresNeck = false

local ragdolled = false

local BODY_COLLIDERS = {
	["Head"] = true,
	["Torso"] = true,
	["Left Arm"] = true,
	["Right Arm"] = true,
	["Left Leg"] = true,
	["Right Leg"] = true,
}

local SOCKET_LIMITS = {
	["Neck"] = {
		UpperAngle = 35,
		TwistLowerAngle = -35,
		TwistUpperAngle = 35,
	},
	["Left Shoulder"] = {
		UpperAngle = 90,
		TwistLowerAngle = -75,
		TwistUpperAngle = 75,
	},
	["Right Shoulder"] = {
		UpperAngle = 90,
		TwistLowerAngle = -75,
		TwistUpperAngle = 75,
	},
	["Left Hip"] = {
		UpperAngle = 65,
		TwistLowerAngle = -45,
		TwistUpperAngle = 45,
	},
	["Right Hip"] = {
		UpperAngle = 65,
		TwistLowerAngle = -45,
		TwistUpperAngle = 45,
	},
}

local function ragdollMotor(motor)
	                                                                               
	                                                    
	if motor.Name == "RootJoint" then
		return
	end

	local part0 = motor.Part0
	local part1 = motor.Part1
	if not part0 or not part1 then
		return
	end

	local attachment0 = Instance.new("Attachment")
	attachment0.Name = "V306GO_RagdollA0_" .. motor.Name
	attachment0.CFrame = motor.C0
	attachment0.Parent = part0

	local attachment1 = Instance.new("Attachment")
	attachment1.Name = "V306GO_RagdollA1_" .. motor.Name
	attachment1.CFrame = motor.C1
	attachment1.Parent = part1

	local socket = Instance.new("BallSocketConstraint")
	socket.Name = "V306GO_RagdollSocket_" .. motor.Name
	socket.Attachment0 = attachment0
	socket.Attachment1 = attachment1
	socket.Enabled = true
	socket.LimitsEnabled = true
	socket.TwistLimitsEnabled = true

	local limits = SOCKET_LIMITS[motor.Name]
	if limits then
		socket.UpperAngle = limits.UpperAngle
		socket.TwistLowerAngle = limits.TwistLowerAngle
		socket.TwistUpperAngle = limits.TwistUpperAngle
	else
		socket.UpperAngle = 75
		socket.TwistLowerAngle = -55
		socket.TwistUpperAngle = 55
	end

	socket.Parent = part0

	motor.Enabled = false
end

local function ragdoll()
	if ragdolled then
		return
	end
	ragdolled = true

	humanoid.AutoRotate = false
	humanoid.PlatformStand = true

	                                                                                 
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
			track:Stop(0.05)
		end
	end

	                                                                           
	                                                                               
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("BasePart") then
			if child.Name == "HumanoidRootPart" then
				child.CanCollide = false
			elseif BODY_COLLIDERS[child.Name] then
				child.CanCollide = true
			end
		end
	end

	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("Motor6D") then
			ragdollMotor(descendant)
		end
	end
end

humanoid.Died:Connect(ragdoll)

print("[R6DeathRagdoll] V306GO ready. R6 joints remain intact while alive and ragdoll only after death.")
