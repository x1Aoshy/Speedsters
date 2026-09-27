-- SupermanFlight.client.luau
-- Superman flies low instead of running (2026-09-18): while a player in the Superman skin
-- (the player's EquippedSkin attribute) moves at a run, their body lies almost flat and
-- floats at the root's height, fist out in front, head up, legs behind, and their cape
-- (RedCape) flutters (Shared.SupermanFlightPose). Every client draws it for every Superman.
--
-- The pose is set on the R6 joints' Transform each frame after the animations have run
-- (Stepped), blended in and out over a moment, so the run cycle's legs never show while it
-- flies; standing still gives the normal idle back. Physics, speed and collisions are
-- untouched. It stands aside while the player uses Flight, climbs, sits, swims, is
-- ragdolled or dead, and lets go of a character once it is gone.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SupermanFlightPose = require(Shared:WaitForChild("SupermanFlightPose"))
local SurfboardStance = require(Shared:WaitForChild("SurfboardStance"))

local SKIN_ID = "SupermanSuit"
local CAPE_NAME = "RedCape"
-- Each posed joint and the part it lives in.
local JOINTS = {
	RootJoint = "HumanoidRootPart",
	Neck = "Torso",
	["Right Shoulder"] = "Torso",
	["Left Shoulder"] = "Torso",
	["Right Hip"] = "Torso",
	["Left Hip"] = "Torso",
}
local AWAY_STATES = {
	[Enum.HumanoidStateType.Climbing] = true,
	[Enum.HumanoidStateType.Seated] = true,
	[Enum.HumanoidStateType.Swimming] = true,
	[Enum.HumanoidStateType.Dead] = true,
	[Enum.HumanoidStateType.Ragdoll] = true,
	[Enum.HumanoidStateType.FallingDown] = true,
	[Enum.HumanoidStateType.PlatformStanding] = true,
}

local flyers = {} -- [character] = its joints, its cape and how far into the pose it is

local function capeWeld(character)
	local cape = character:FindFirstChild(CAPE_NAME)
	local handle = cape and cape:FindFirstChild("Handle")
	local weld = handle and handle:FindFirstChild("AccessoryWeld")
	return if weld and weld:IsA("JointInstance") then weld else nil
end

local function track(character, player)
	local motors = {}
	for name, partName in JOINTS do
		local part = character:FindFirstChild(partName)
		local motor = part and part:FindFirstChild(name)
		if motor and motor:IsA("Motor6D") then
			motors[name] = motor
		end
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") and motors.RootJoint then
		flyers[character] = {
			Motors = motors,
			Root = root,
			Humanoid = character:FindFirstChildOfClass("Humanoid"),
			Player = player,
			Blend = 0,
			Cape = nil,
			CapeC0 = nil,
			-- Supermen side by side do not bob in step.
			Phase = math.random() * 10,
		}
	end
end

local function release(character)
	local flyer = flyers[character]
	if flyer then
		flyers[character] = nil
		if flyer.Cape and flyer.Cape.Parent and flyer.CapeC0 then
			flyer.Cape.C0 = flyer.CapeC0
		end
	end
end

local function refresh(player)
	local character = player.Character
	for tracked, flyer in flyers do
		if flyer.Player == player and tracked ~= character then
			release(tracked)
		end
	end
	if character and character.Parent and player:GetAttribute("EquippedSkin") == SKIN_ID then
		if not flyers[character] then
			track(character, player)
		end
	elseif character then
		release(character)
	end
end

local function onPlayer(player)
	player:GetAttributeChangedSignal("EquippedSkin"):Connect(function()
		refresh(player)
	end)
	player.CharacterAdded:Connect(function(character)
		-- The joints are built a moment after the character arrives.
		character:WaitForChild("HumanoidRootPart", 5)
		task.wait(0.2)
		refresh(player)
	end)
	player.CharacterRemoving:Connect(release)
	refresh(player)
end

Players.PlayerAdded:Connect(onPlayer)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayer, player)
end
Players.PlayerRemoving:Connect(function(player)
	for character, flyer in flyers do
		if flyer.Player == player then
			release(character)
		end
	end
end)

-- Whether the Superman pose should not show: a Flight, a climb, a seat, water, a ragdoll
-- or a death has the body.
local function standsAside(character, flyer)
	local humanoid = flyer.Humanoid
	local player = flyer.Player
	return not humanoid
		or humanoid.Health <= 0
		or not flyer.Root.Parent
		or AWAY_STATES[humanoid:GetState()] == true
		or humanoid.Sit
		or character:GetAttribute("Ragdolled") == true
		or character:GetAttribute("Dead") == true
		or character:GetAttribute("FlightAbilityLocalActive") == true
		or (player ~= nil and (player:GetAttribute("FlightAbilityActive") == true or player:GetAttribute("AdminFlying") == true))
end

RunService.Stepped:Connect(function(now, dt)
	for character, flyer in flyers do
		if not character.Parent then
			release(character)
			continue
		end
		local velocity = flyer.Root.AssemblyLinearVelocity
		local flying = not standsAside(character, flyer)
			and Vector3.new(velocity.X, 0, velocity.Z).Magnitude >= SupermanFlightPose.MinSpeed
		flyer.Blend = SupermanFlightPose.Blend(flyer.Blend, flying, dt)
		local weight = flyer.Blend
		-- The cape: found once it is worn (the skin dresses a moment after the character).
		if not flyer.Cape or not flyer.Cape.Parent then
			flyer.Cape = capeWeld(character)
			flyer.CapeC0 = flyer.Cape and flyer.Cape.C0
		end
		if weight > 0 then
			local t = now + flyer.Phase
			local pose = SupermanFlightPose.Pose(t)
			for name, motor in flyer.Motors do
				local rotation = pose[name]
				if rotation and motor.Parent then
					local target = SurfboardStance.Transform(motor.C0, rotation)
					motor.Transform = if weight >= 1 then target else motor.Transform:Lerp(target, weight)
				end
			end
			if flyer.Cape and flyer.CapeC0 then
				flyer.Cape.C0 = flyer.CapeC0 * CFrame.new():Lerp(SupermanFlightPose.Cape(t), weight)
			end
		elseif flyer.Cape and flyer.CapeC0 and flyer.Cape.C0 ~= flyer.CapeC0 then
			flyer.Cape.C0 = flyer.CapeC0
		end
	end
end)
