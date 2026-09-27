-- SurfboardPose.client.luau
-- The Silver Surfer rides its board in a surfer's stance (Shared.SurfboardStance): body
-- side-on, feet apart along the board, arms out, leaning into the ride and swaying. Every
-- client draws it for every rider: SkinSystem marks a riding character with the attribute
-- "SurfboardRiding" and welds the board under its feet.
--
-- The stance is set on the R6 joints' Transform each frame after the animations have run
-- (Stepped), so the run cycle's legs never show on the board. Physics, speed and the
-- character's collisions are untouched. It stands aside while the rider flies, is
-- ragdolled or dead, and lets go of a character once it is gone.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SurfboardStance = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SurfboardStance"))

local RIDING = "SurfboardRiding"
-- Each posed joint and the part it lives in.
local JOINTS = {
	RootJoint = "HumanoidRootPart",
	Neck = "Torso",
	["Right Shoulder"] = "Torso",
	["Left Shoulder"] = "Torso",
	["Right Hip"] = "Torso",
	["Left Hip"] = "Torso",
}

local riders = {}
local watched: { [Model]: { RBXScriptConnection } } = setmetatable({}, { __mode = "k" }) :: any

local function rest(rider)
	for _, motor in rider.Motors do
		if motor.Parent then
			motor.Transform = CFrame.identity
		end
	end
end

local function release(character)
	local rider = riders[character]
	if rider then
		riders[character] = nil
		rest(rider)
	end
end

local function track(character)
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
		riders[character] = {
			Motors = motors,
			Root = root,
			Humanoid = character:FindFirstChildOfClass("Humanoid"),
			Player = Players:GetPlayerFromCharacter(character),
			-- Riders side by side do not sway in step.
			Phase = math.random() * 10,
			Resting = false,
		}
	end
end

local function refresh(character)
	if character:GetAttribute(RIDING) == true and character.Parent then
		if not riders[character] then
			track(character)
		end
	else
		release(character)
	end
end

local function watch(character)
	if watched[character] then
		return
	end
	local connections = {}
	watched[character] = connections
	table.insert(connections, character:GetAttributeChangedSignal(RIDING):Connect(function()
		refresh(character)
	end))
	table.insert(connections, character.AncestryChanged:Connect(function()
		if not character:IsDescendantOf(game) then
			release(character)
			for _, connection in connections do
				connection:Disconnect()
			end
			watched[character] = nil
		end
	end))
	refresh(character)
end

local function onPlayer(player)
	if player.Character then
		watch(player.Character)
	end
	player.CharacterAdded:Connect(watch)
end

Players.PlayerAdded:Connect(onPlayer)
for _, player in Players:GetPlayers() do
	onPlayer(player)
end

local function standsAside(character, rider)
	local humanoid = rider.Humanoid
	local player = rider.Player
	return not humanoid
		or humanoid.Health <= 0
		or not rider.Root.Parent
		or character:GetAttribute("Ragdolled") == true
		or character:GetAttribute("Dead") == true
		or character:GetAttribute("FlightAbilityLocalActive") == true
		or (player ~= nil and (player:GetAttribute("FlightAbilityActive") == true or player:GetAttribute("AdminFlying") == true))
end

RunService.Stepped:Connect(function(now)
	for character, rider in riders do
		if standsAside(character, rider) then
			if not rider.Resting then
				rider.Resting = true
				rest(rider)
			end
		else
			rider.Resting = false
			local velocity = rider.Root.AssemblyLinearVelocity
			local pose = SurfboardStance.Pose(now + rider.Phase, Vector3.new(velocity.X, 0, velocity.Z).Magnitude)
			for name, motor in rider.Motors do
				local rotation = pose[name]
				if rotation and motor.Parent then
					motor.Transform = SurfboardStance.Transform(motor.C0, rotation)
				end
			end
		end
	end
end)
