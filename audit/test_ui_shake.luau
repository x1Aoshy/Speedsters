-- test_ui_shake.luau
-- Shakes must always end at the value the object had before any shake started, even
-- when a new shake begins mid-shake. Tapping Spin with no spins wiggled the pack buttons
-- again and again, and each new wiggle took the tilted angle as its rest, leaving them
-- crooked for good.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local listeners = {}
local RenderStepped = {
	Connect = function(_, fn)
		local entry = { fn = fn, connected = true }
		table.insert(listeners, entry)
		return {
			Disconnect = function()
				entry.connected = false
			end,
		}
	end,
}
local function step(dt)
	for _, entry in table.clone(listeners) do
		if entry.connected then
			entry.fn(dt)
		end
	end
end

local UiShake = luau.load(fs.readFile("src/common/ReplicatedStorage/Shared/UiShake.luau"), {
	environment = setmetatable({
		game = { GetService = function()
			return { RenderStepped = RenderStepped }
		end },
		UDim2 = roblox.UDim2,
	}, { __index = _G }),
})()

-- Wiggle, then tap again at the peak of the wiggle, several times.
local button = { Rotation = 0, Position = roblox.UDim2.fromScale(0.3, 0.5), Parent = true }
UiShake.Wiggle(button, 10, 0.5, 9)
for tap = 1, 6 do
	step(1 / 36) -- a quarter wiggle: the button is tilted
	assert(button.Rotation ~= 0, "the wiggle should be moving")
	UiShake.Wiggle(button, 10, 0.5, 9)
end
for _ = 1, 60 do
	step(1 / 60)
end
assert(button.Rotation == 0, "After overlapping wiggles the button must be straight again, got " .. button.Rotation)

-- An authored tilt is the rest value, and survives overlapping wiggles.
local arrow = { Rotation = 90, Position = roblox.UDim2.fromScale(0.5, 0.1), Parent = true }
UiShake.Wiggle(arrow, 14, 0.55, 11)
step(1 / 40)
UiShake.Wiggle(arrow, 14, 0.55, 11)
for _ = 1, 60 do
	step(1 / 60)
end
assert(arrow.Rotation == 90, "The arrow must return to its authored 90 degrees, got " .. arrow.Rotation)

-- Same for jitter.
UiShake.Jitter(button, 8, 0.4, 18)
step(1 / 50)
UiShake.Jitter(button, 8, 0.4, 18)
for _ = 1, 40 do
	step(1 / 60)
end
assert(button.Position == roblox.UDim2.fromScale(0.3, 0.5), "After overlapping jitters the button must be back in place")

print("PASS UiShake: overlapping wiggles and jitters always come back to the authored rest")
