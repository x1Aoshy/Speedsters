-- Disabled: Workspace.FadingPart platforms are owned per player by
-- StarterPlayerScripts.Gameplay.FadingPlatformsClient.
--
-- This server copy faded the same part globally, so one player stepping on a
-- platform turned off its collision for everyone else standing on it, and its
-- fifteen stepped Transparency writes replicated to every client on each touch.
-- The client system does the same fade locally, for the player who triggered it.
if true then return end

local part = script.Parent
local originalTransparency = part.Transparency
local originalCanCollide = part.CanCollide
local FADE_TIME = 5
local RESPAWN_TIME = 3
local STEPS = 15

local debounce = false

part.Touched:Connect(function(hit)
	local hum = hit.Parent and hit.Parent:FindFirstChildWhichIsA("Humanoid")
	if not hum then return end
	if debounce then return end
	debounce = true

	-- Fade out
	for i = 1, STEPS do
		part.Transparency = originalTransparency + (1 - originalTransparency) * (i / STEPS)
		task.wait(FADE_TIME / STEPS)
	end

	-- Fully gone
	part.Transparency = 1
	part.CanCollide = false

	-- Wait then respawn
	task.wait(RESPAWN_TIME)

	-- Fade back in
	for i = STEPS, 0, -1 do
		part.Transparency = originalTransparency + (1 - originalTransparency) * (i / STEPS)
		task.wait(FADE_TIME / STEPS)
	end

	part.Transparency = originalTransparency
	part.CanCollide = originalCanCollide
	debounce = false
end)
