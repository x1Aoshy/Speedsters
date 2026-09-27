-- LowPowerGraphics.client.luau
-- Phones run this game at 26 FPS on average and are two thirds of the players (analytics,
-- 2026-09-19). Infrastructure/AAA_ReferenceClipLighting turns global shadows on for every
-- world; on a touch-only device they are turned off again, locally. No other device is
-- affected.
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

if not (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled) then
	return
end
local function apply()
	if Lighting.GlobalShadows then
		Lighting.GlobalShadows = false
	end
end
apply()
-- The server script sets its lighting a moment after the place starts, and again if it reruns.
Lighting:GetPropertyChangedSignal("GlobalShadows"):Connect(apply)

-- 2026-09-22: Bloom (0.17), SunRays (0.035) and any Depth of Field are full-screen passes a
-- phone pays every frame for an effect it barely shows. AAA_ReferenceClipLighting destroys
-- and recreates them after the place starts, hence ChildAdded. ColorCorrection (cheap) and
-- Atmosphere (the admin snow and taco events blend it) stay.
local function quietPostEffect(child: Instance)
	if child:IsA("BloomEffect") or child:IsA("SunRaysEffect") or child:IsA("DepthOfFieldEffect") then
		local effect = child :: PostEffect
		if effect.Enabled then
			effect.Enabled = false
		end
		effect:GetPropertyChangedSignal("Enabled"):Connect(function()
			if effect.Enabled then
				effect.Enabled = false
			end
		end)
	end
end
for _, child in Lighting:GetChildren() do
	quietPostEffect(child)
end
Lighting.ChildAdded:Connect(quietPostEffect)

-- 2026-09-22: the lightning bolts on the Admin and Hacker pass treadmills in the lobby carry
-- six always-on Highlights, each another full-screen pass (a device draws at most 31). Only
-- those bolts, found by their exact place in the lobby: gameplay, character and tutorial
-- Highlights are never touched. The lobby streams in and out, so the few lookups below
-- run again every DISPLAY_SWEEP_SECONDS instead of a Workspace-wide DescendantAdded.
local DISPLAY_SWEEP_SECONDS = 2
local LOBBY_DISPLAYS = {
	{ "neworld1", "Admin" }, -- World 1
	{ "neworld1", "Hacker" },
	{ "Admin" }, -- World 2 (the treadmill row itself is called Admin)
	{ "Admin", "Hacker" },
	{ "Lobby", "Admin" }, -- World 3
	{ "Lobby", "Hacker" },
}
local BOLT_NAME = "Lightning Bolt GFX"

local function quietLobbyHighlights()
	for _, path in LOBBY_DISPLAYS do
		local display: Instance? = Workspace
		for _, name in path do
			display = display and display:FindFirstChild(name)
		end
		if display then
			for _, holder in display:GetChildren() do
				if holder.Name == "Model" and holder:IsA("Model") then
					for _, bolt in holder:GetChildren() do
						if bolt.Name == BOLT_NAME then
							for _, highlight in bolt:GetChildren() do
								if highlight:IsA("Highlight") and highlight.Enabled then
									highlight.Enabled = false
								end
							end
						end
					end
				end
			end
		end
	end
end

-- 2026-09-25 (Update 4): the race arena's part chevrons (RaceArenaBuilder tags them
-- RaceDecorLowPower when no chevron texture is uploaded) are ~150 extra parts: hidden here as
-- they stream in. The ORB's sparks drop from 10 to 4 a second (looked up in the same sweep:
-- the ORB is Persistent, so it is there once the arena is).
local LOW_POWER_TAG = "RaceDecorLowPower"
local ORB_SPARKS_RATE = 4

local function hideDecor(instance: Instance)
	if instance:IsA("BasePart") and instance.Transparency < 1 then
		instance.Transparency = 1
	end
end
-- (In pcall: the audit harnesses of this script offer only the services it used before.)
local hasTags, CollectionService = pcall(function()
	return game:GetService("CollectionService")
end)
if hasTags and CollectionService then
	for _, instance in CollectionService:GetTagged(LOW_POWER_TAG) do
		hideDecor(instance)
	end
	CollectionService:GetInstanceAddedSignal(LOW_POWER_TAG):Connect(hideDecor)
end

local function calmOrb()
	local arena = Workspace:FindFirstChild("RaceArena")
	local orb = arena and arena:FindFirstChild("RaceOrb")
	local core = orb and orb:FindFirstChild("Core")
	local sparks = core and core:FindFirstChild("Sparks")
	if sparks and sparks:IsA("ParticleEmitter") and sparks.Rate > ORB_SPARKS_RATE then
		sparks.Rate = ORB_SPARKS_RATE
	end
end

task.spawn(function()
	while true do
		quietLobbyHighlights()
		calmOrb()
		task.wait(DISPLAY_SWEEP_SECONDS)
	end
end)
