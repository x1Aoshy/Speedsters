-- SmoothBridges.server.luau
-- Plank bridges run smooth (Config.SmoothBridges; the ramp is Gameplay/BridgeRampPlan's):
-- an invisible ramp follows the middle of the planks' tops from one end of the deck to the
-- other, and the planks themselves stop being solid, so a runner crosses one smooth
-- surface instead of catching on every plank's edge (2026-09-18, Sung's video). The rails
-- and posts stay solid. World 2's Japanese Bridge and World 3's Stage 5 bridges.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local settings = Config.SmoothBridges
if type(settings) ~= "table" or settings.Enabled ~= true then
	return
end
local key = if Config.IsWorld2Place then "World2" elseif Config.IsWorld3Place then "World3" elseif Config.IsNewWorld1Map then "World1" else nil
local names = key and settings[key]
if type(names) ~= "table" or #names == 0 then
	return
end
local Plan = require(script.Parent:WaitForChild("BridgeRampPlan"))

local wanted = {}
for _, name in names do
	wanted[name] = true
end

local smoothed, planksOff = 0, 0
for _, bridge in Workspace:GetDescendants() do
	if bridge:IsA("Model") and wanted[bridge.Name] and not bridge:FindFirstChild("SmoothRamp") then
		local planks, parts = {}, {}
		for _, part in bridge:GetDescendants() do
			if part:IsA("BasePart") and part.CanCollide then
				local plank = Plan.Plank(part.CFrame, part.Size)
				if plank then
					table.insert(planks, plank)
					table.insert(parts, part)
				end
			end
		end
		local pieces, deck = Plan.Ramp(planks)
		if pieces and deck then
			local ramp = Instance.new("Folder")
			ramp.Name = "SmoothRamp"
			for index, piece in pieces do
				local part = Instance.new("Part")
				part.Name = "SmoothRamp" .. index
				part.Anchored = true
				part.CanCollide = true
				part.CanTouch = false
				part.CastShadow = false
				part.Transparency = 1
				part.Material = Enum.Material.SmoothPlastic
				part.TopSurface = Enum.SurfaceType.Smooth
				part.BottomSurface = Enum.SurfaceType.Smooth
				part.Size = piece.Size
				part.CFrame = piece.CFrame
				part.Parent = ramp
			end
			ramp.Parent = bridge
			for index, part in parts do
				if deck[index] then
					part.CanCollide = false
					planksOff += 1
				end
			end
			smoothed += 1
		end
	end
end
print(("[SmoothBridges] %s: %d bridge(s) smoothed, %d planks now only show"):format(key, smoothed, planksOff))
