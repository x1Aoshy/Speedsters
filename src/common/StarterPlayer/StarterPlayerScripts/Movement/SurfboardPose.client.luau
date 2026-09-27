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
-- 2026-09-25 (Update 4): it also stands aside in a race (Race/RacePoseClient marks the
-- characters it poses with the local attribute RacePosed), and while the rider's player is in
-- a race (RaceActive) the board and its wake are hidden on this client, then shown again.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SurfboardStance = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SurfboardStance"))

local RIDING = "SurfboardRiding"
local BOARD_FOLDER = "SkinSurfboard" -- SkinSystem welds the board in here
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

-- The board out of sight while its rider races (local only: LocalTransparencyModifier and
-- the wake's Enabled), back as it was afterwards. The board's parts are listed once; the
-- camera may reset the modifier when it zooms, so they are checked again every frame (a few
-- parts, only in a race).
local function showBoard(rider, visible)
	if not visible then
		local folder = rider.Character:FindFirstChild(BOARD_FOLDER)
		local hidden = rider.HiddenBoard
		if not folder then
			return
		end
		if not hidden or hidden.Folder ~= folder then
			hidden = hidden or { Parts = {}, Trails = {} }
			hidden.Folder = folder
			hidden.List = {}
			for _, item in folder:GetDescendants() do
				-- Decals/Textures carry their own modifier (a part's does not reach them).
				if item:IsA("BasePart") or item:IsA("Decal") then
					table.insert(hidden.List, item)
				elseif item:IsA("Trail") and item.Enabled then
					hidden.Trails[item] = true
					item.Enabled = false
				end
			end
			rider.HiddenBoard = hidden
		end
		for _, part in hidden.List do
			if part.LocalTransparencyModifier ~= 1 then
				hidden.Parts[part] = true
				part.LocalTransparencyModifier = 1
			end
		end
	elseif rider.HiddenBoard then
		for part in rider.HiddenBoard.Parts do
			if part.Parent then
				part.LocalTransparencyModifier = 0
			end
		end
		for trail in rider.HiddenBoard.Trails do
			if trail.Parent then
				trail.Enabled = true
			end
		end
		rider.HiddenBoard = nil
	end
end

local function release(character)
	local rider = riders[character]
	if rider then
		riders[character] = nil
		rest(rider)
		showBoard(rider, true)
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
			Character = character,
			HiddenBoard = nil,
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
		or character:GetAttribute("RacePosed") == true
		or character:GetAttribute("FlightAbilityLocalActive") == true
		or (player ~= nil and (player:GetAttribute("FlightAbilityActive") == true or player:GetAttribute("AdminFlying") == true))
end

RunService.Stepped:Connect(function(now)
	for character, rider in riders do
		local racing = rider.Player ~= nil and rider.Player:GetAttribute("RaceActive") == true
		if racing then
			showBoard(rider, false)
		elseif rider.HiddenBoard then
			showBoard(rider, true)
		end
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
