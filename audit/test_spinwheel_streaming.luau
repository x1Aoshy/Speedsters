-- Regression guard for the physical Spin Wheel in the three streamed places.
-- Run from the repository root with: lune run audit/test_spinwheel_streaming.luau

local fs = require("@lune/fs")
local rb = require("@lune/roblox")

local controllerPath = "src/common/StarterPlayer/StarterPlayerScripts/UI/SpinWheelController.client.luau"
local canonicalSource = fs.readFile(controllerPath):gsub("\r\n", "\n")

local function has(source: string, snippet: string, label: string)
	assert(source:find(snippet, 1, true), "SpinWheelController missing " .. label)
end

-- Both races must stay fixed: the GUI's children and the Workspace model can
-- replicate later than their parents when a player first enters a streamed place.
has(canonicalSource, 'PlayerGui:WaitForChild("SpinWheelGui")', "unbounded panel wait")
has(canonicalSource, 'gui:WaitForChild("Frame")', "panel Frame wait")
has(canonicalSource, 'gui:WaitForChild("Button")', "panel Button wait")
has(canonicalSource, 'Workspace:WaitForChild("SpinWheelLobby")', "lobby model wait")
for _, name in { "Face", "Overhead", "PromptAnchor" } do
	has(canonicalSource, 'model:WaitForChild("' .. name .. '")', name .. " wait")
end
has(canonicalSource, 'face:WaitForChild("Wheel")', "wheel surface wait")
has(canonicalSource, 'surface:WaitForChild("Frame")', "wheel art wait")
has(canonicalSource, 'promptAnchor:WaitForChild("ProximityPrompt")', "wheel prompt wait")
assert(not canonicalSource:find('Instance.new("Model")', 1, true),
	"SpinWheelController must not create a second client-side lobby model")

local places = {
	World1 = "World1Update3New.rbxl",
	World2 = "World2Update3new.rbxl",
	World3 = "World3Update3New.rbxl",
}

local function requireChild(parent, name: string, className: string?, context: string)
	local child = parent and parent:FindFirstChild(name)
	assert(child and (className == nil or child:IsA(className)), context .. ": missing " .. name .. " (" .. tostring(className) .. ")")
	return child
end

for world, path in places do
	local assetPath = "src/assets/SpinWheelLobby_" .. world .. ".rbxm"
	local prefab = assert(rb.deserializeModel(fs.readFile(assetPath))[1], world .. ": wheel prefab missing")
	assert(prefab.ModelStreamingMode == rb.Enum.ModelStreamingMode.Persistent,
		world .. ": saved wheel prefab must remain Persistent")
	local place = rb.deserializePlace(fs.readFile(path))
	local workspace = place:GetService("Workspace")
	assert(workspace.StreamingEnabled == true, world .. ": expected StreamingEnabled place")

	local model = requireChild(workspace, "SpinWheelLobby", "Model", world .. "/Workspace")
	assert(model.ModelStreamingMode == rb.Enum.ModelStreamingMode.Persistent,
		world .. ": SpinWheelLobby must be Persistent, got " .. tostring(model.ModelStreamingMode))
	local face = requireChild(model, "Face", "BasePart", world .. "/SpinWheelLobby")
	local surface = requireChild(face, "Wheel", "SurfaceGui", world .. "/Face")
	local holder = requireChild(surface, "Frame", "Frame", world .. "/Wheel")
	requireChild(holder, "Spin Wheel", "Frame", world .. "/Wheel/Frame")
	local overhead = requireChild(model, "Overhead", "BasePart", world .. "/SpinWheelLobby")
	local billboard = requireChild(overhead, "Billboard", "BillboardGui", world .. "/Overhead")
	requireChild(billboard, "Status", "TextLabel", world .. "/Billboard")
	local anchor = requireChild(model, "PromptAnchor", "BasePart", world .. "/SpinWheelLobby")
	requireChild(anchor, "ProximityPrompt", "ProximityPrompt", world .. "/PromptAnchor")

	local starterGui = place:GetService("StarterGui")
	local gui = requireChild(starterGui, "SpinWheelGui", "ScreenGui", world .. "/StarterGui")
	local panel = requireChild(gui, "Frame", "Frame", world .. "/SpinWheelGui")
	requireChild(panel, "UIAspectRatioConstraint", "UIAspectRatioConstraint", world .. "/SpinWheelGui/Frame")
	local artWheel = requireChild(panel, "Spin Wheel", "Frame", world .. "/SpinWheelGui/Frame")
	requireChild(artWheel, "ImageLabel", "ImageLabel", world .. "/SpinWheelGui/Spin Wheel")
	requireChild(artWheel, "SliceColours", "Frame", world .. "/SpinWheelGui/Spin Wheel")
	requireChild(artWheel, "UIAspectRatioConstraint", "UIAspectRatioConstraint", world .. "/SpinWheelGui/Spin Wheel")
	local hub = requireChild(artWheel, "Spin", "Frame", world .. "/SpinWheelGui/Spin Wheel")
	for index = 1, 6 do
		local slice = requireChild(hub, "Slice" .. index, "Frame", world .. "/Spin")
		requireChild(slice, "Icon", "ImageLabel", world .. "/Slice" .. index)
		requireChild(slice, "TextLabel", "TextLabel", world .. "/Slice" .. index)
		requireChild(slice, "UIAspectRatioConstraint", "UIAspectRatioConstraint", world .. "/Slice" .. index)
	end
	local arrow = requireChild(panel, "Arrow", "Frame", world .. "/SpinWheelGui/Frame")
	requireChild(arrow, "ImageLabel", "ImageLabel", world .. "/Arrow")
	requireChild(panel, "Close", "ImageButton", world .. "/SpinWheelGui/Frame")
	requireChild(panel, "HubCap", "Frame", world .. "/SpinWheelGui/Frame")
	local wins = requireChild(panel, "WinsSpin", "ImageButton", world .. "/SpinWheelGui/Frame")
	requireChild(wins, "Price", "TextLabel", world .. "/WinsSpin")
	requireChild(wins, "ImageLabel", "ImageLabel", world .. "/WinsSpin")
	requireChild(panel, "WinsCaption", "TextLabel", world .. "/SpinWheelGui/Frame")
	local x10 = requireChild(panel, "X10", "ImageButton", world .. "/SpinWheelGui/Frame")
	requireChild(x10, "Price", "TextLabel", world .. "/X10")
	requireChild(panel, "X10Caption", "TextLabel", world .. "/SpinWheelGui/Frame")
	local buttons = requireChild(gui, "Button", "Frame", world .. "/SpinWheelGui")
	requireChild(buttons, "Claim", "ImageButton", world .. "/SpinWheelGui/Button")
	requireChild(buttons, "TextLabel", "TextLabel", world .. "/SpinWheelGui/Button")
	for _, pack in { "X1", "X3" } do
		local button = requireChild(buttons, pack, "ImageButton", world .. "/SpinWheelGui/Button")
		requireChild(button, "Price", "TextLabel", world .. "/" .. pack)
	end

	local starterPlayer = place:GetService("StarterPlayer")
	local playerScripts = requireChild(starterPlayer, "StarterPlayerScripts", nil, world .. "/StarterPlayer")
	local ui = requireChild(playerScripts, "UI", nil, world .. "/StarterPlayerScripts")
	local controller = requireChild(ui, "SpinWheelController", "LocalScript", world .. "/UI")
	assert(controller.Source:gsub("\r\n", "\n") == canonicalSource,
		world .. ": embedded SpinWheelController differs from " .. controllerPath)
	print("PASS " .. world .. ": persistent wheel, prefab, panel, and synchronized controller")
end

print("PASS Spin Wheel streaming regression in all three places")
