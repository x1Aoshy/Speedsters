-- Regression for HeatVisionClient's first layout pass, when CurrentCamera.ViewportSize
-- can still be 1x1 while GuiService:GetGuiInset() already reports a top bar.
local HudErgonomics = require("../src/common/ReplicatedStorage/Shared/HudErgonomics")

for _, screen in {
	{ 1, 1, 36 },
	{ 1, 36, 36 },
	{ 390, 36, 36 },
	{ 844, 390, 58 },
} do
	local width, height, topBar = screen[1], screen[2], screen[3]
	local plan = HudErgonomics.PhoneColumn(width, height, true, false, 2, topBar)
	assert(plan.Sprint and plan.Speedometer and plan.Speedometer.Rect,
		("PhoneColumn %dx%d with %d px top bar returns a complete plan"):format(width, height, topBar))
	assert(plan.Sprint.Top == plan.Sprint.Top and plan.Speedometer.Scale == plan.Speedometer.Scale,
		"Startup layout values must be finite")
end

print("PASS: phone HUD layout survives an initial viewport smaller than its top bar")
