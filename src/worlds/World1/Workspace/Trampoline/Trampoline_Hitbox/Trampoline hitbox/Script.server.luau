-- The trampoline at the top of Stage 9's climb.
--
-- This script used to make the mat a conveyor: pad.Velocity = (0, 277777, 0). Whoever stepped
-- on it left at 277,777 studs a second: a teleport far above Stage 10 and over the side
-- barriers. Now the mat stands still and each client bounces its own character
-- (Gameplay/NewWorld1Trampoline.client, maths in Shared/World1Trampoline), just high enough
-- to come over the ledge of Stage 10. All this script does is measure that height on the map.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local pad = script.Parent
pad.AssemblyLinearVelocity = Vector3.zero

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Trampoline = require(Shared:WaitForChild("World1Trampoline"))

local model = pad:FindFirstAncestorOfClass("Model") or pad
local map = Workspace:FindFirstChild(tostring(Config.NewWorld1MapMarkerName or "neworld1"))
local ledge = map and map:FindFirstChild("stage10", true)
local ledgeTop = if ledge and ledge:IsA("BasePart") then Trampoline.TopOf(ledge.CFrame, ledge.Size) else nil

model:SetAttribute(Trampoline.RiseAttribute, Trampoline.Rise(Trampoline.TopOf(pad.CFrame, pad.Size), ledgeTop))
CollectionService:AddTag(model, Trampoline.Tag)
