-- Regression for the inventory panels that formerly covered the Roblox top bar.
local fs = require("@lune/fs")
local rb = require("@lune/roblox")
local luau = require("@lune/luau")

local files = {
	Backpack = "src/common/StarterGui/Backpack/BackpackScript.client.luau",
	Index = "src/common/StarterGui/Index/IndexScript.client.luau",
}
local place = rb.deserializePlace(fs.readFile("World1Update3New.rbxl"))
for name, path in files do
	local source = fs.readFile(path)
	luau.compile(source)
	assert(source:find("Enum.ScreenInsets.CoreUISafeInsets", 1, true), name .. " omits top-bar safe area")
	assert(source:find("ResponsivePanelScale", 1, true), name .. " omits panel fit")
	if name == "Backpack" then
		assert(not source:find("fitPanelForPhones", 1, true), "legacy Backpack resize handler still overrides the safe-area fit")
		assert(not source:find("PHONE_PANEL_SIZE", 1, true), "legacy Backpack phone size still overrides the safe-area fit")
	end
	local gui = assert(place:GetService("StarterGui"):FindFirstChild(name))
	local frame = assert(gui:FindFirstChild(if name == "Backpack" then "MainFrame" else "Index"))
	local aspect = assert(frame:FindFirstChildOfClass("UIAspectRatioConstraint"))
	local cases = {
		rb.Vector2.new(844, 330), -- landscape phone after top inset
		rb.Vector2.new(390, 740), -- portrait phone
		rb.Vector2.new(1366, 700), -- laptop
		rb.Vector2.new(1920, 1020), -- desktop
		rb.Vector2.new(2587, 1000), -- ultrawide screenshot
	}
	for _, safe in cases do
		local compact = safe.X < 700 or safe.Y < 500
		local size = if compact then rb.Vector2.new(0.94, 0.84) else rb.Vector2.new(frame.Size.X.Scale, frame.Size.Y.Scale)
		local width = size.X * safe.X
		local height = if compact then size.Y * safe.Y else width / aspect.AspectRatio
		local scale = math.min(1, 760 / width, (safe.X - 28) / width, (safe.Y - 28) / height)
		assert(width * scale <= math.min(760, safe.X - 28) + 0.01,
			name .. " overflows width at " .. tostring(safe))
		assert(height * scale <= safe.Y - 28 + 0.01,
			name .. " overflows height at " .. tostring(safe))
		assert(scale > 0 and scale <= 1, name .. " invalid scale at " .. tostring(safe))
	end
	print("PASS", name, "compiled; five safe-area viewport checks")
end
