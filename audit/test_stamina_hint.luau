-- test_stamina_hint.luau
-- "No stamina to run / to fly" shows inside the stamina bar, in the place of the bar's own
-- hint ("Shift: Sprint | Space: Fly"), not floating above it where the level bar hid it.
local fs = require("@lune/fs")
local PlaceFiles = require("./place_files")
local roblox = require("@lune/roblox")

local hud = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/UI/MainHUDController.client.luau")

local function has(needle, message)
	assert(string.find(hud, needle, 1, true), message)
end

assert(not string.find(hud, "NoStaminaMessage", 1, true), "The floating no-stamina label must be gone")
has("shiftLabel.Text = string.gsub(StaminaFeedback.Messages[kind]", "The message must be written into the bar's hint label")
has("shiftLabel.Visible = true", "The message must show even where the hint is hidden (touch)")
has("noStaminaShowing = true", "The hint must not overwrite the message while it shows")
has("if not shiftLabel or not shiftLabel:IsA(\"TextLabel\") or noStaminaShowing then", "updateSprintHint must wait for the message")
has("noStaminaShowing = false", "The hint must come back after the message")
assert(not string.find(hud, "shiftLabel.TextWrapped", 1, true) and not string.find(hud, "shiftLabel.Size", 1, true)
	and not string.find(hud, "shiftLabel.Position", 1, true), "The authored hint label keeps its size, position and text settings")

-- The label the message uses sits inside the stamina bar in both places.
for _, place in PlaceFiles.Files("World1", "World2") do
	local game = roblox.deserializePlace(fs.readFile(place))
	local bar = game:GetService("StarterGui"):FindFirstChild("Mainhud")
	bar = bar and bar:FindFirstChild("SpeedsterBar")
	local frame = bar and bar:FindFirstChild("Frame")
	local shift = frame and frame:FindFirstChild("Shift")
	local fill = frame and frame:FindFirstChild("Fill")
	assert(shift and shift:IsA("TextLabel"), place .. ": Mainhud.SpeedsterBar.Frame.Shift missing")
	assert(fill, place .. ": the stamina fill is missing")
	local x, y = shift.Position.X.Scale, shift.Position.Y.Scale
	assert(x > 0 and x < 1 and y > 0 and y < 1, place .. ": the hint label must sit inside the bar")
	assert(shift.ZIndex > fill.ZIndex, place .. ": the hint label must draw over the yellow fill")
	assert(shift.TextScaled and shift.TextWrapped, place .. ": the hint label scales its text to fit")
end

print("PASS no-stamina message shows inside the stamina bar, in the hint label's place")
