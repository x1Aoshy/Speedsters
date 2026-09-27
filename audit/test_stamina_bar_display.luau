-- audit/test_stamina_bar_display.luau
-- The sprint bar read "0/17" over a visible sliver of fill (2026-09-21 report): the label showed
-- math.floor(stamina) while the fill showed the raw ratio, so 0.6 stamina was "0" over 3.5% of
-- the bar for as long as the bar rested there (3 s before it regenerates, longer in the air).
--
-- This runs the real SpeedsterBar block of MainHUDController against mocks and checks that the
-- number and the fill cannot disagree, that one tween runs at a time (cancelled before the
-- next, none while nothing changes) and that a cancelled shrink never hides a refilled bar.
--
--   lune run audit/test_stamina_bar_display.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local rb = require("@lune/roblox")

local PATH = "src/common/StarterPlayer/StarterPlayerScripts/UI/MainHUDController.client.luau"
local source = (string.gsub(fs.readFile(PATH), "\r\n", "\n"))

local a = assert(source:find("local speedsterBar = mainhud:WaitForChild", 1, true), "the SpeedsterBar block moved")
local b = assert(source:find("-- True while the bar's hint label", a, true), "the SpeedsterBar block's end moved")
local block = source:sub(a, b - 1) .. "\nreturn refreshStaminaBar"
-- 2026-09-26: the section now runs inside its own `do` block (Studio's 200-locals limit); the slice opens
-- that block but ends inside it, so drop the opening `do` to keep the slice loadable on its own.
block = string.gsub(block, "\ndo\n", "\n", 1)
assert(not block:find("math.floor(stamina)) ..", 1, true), "the label must be built from the same value as the fill")

local attributes = { BoostStaminaDisplayMax = 17, BoostStamina = 17 }
local tweensCreated, cancels, live = 0, 0, {}
local fill = { Visible = true, Size = "authored" }
local value = { Text = "10/10" }
function value:IsA(class) return class == "TextLabel" end
local frame = {}
function frame:WaitForChild(name) return if name == "Fill" then fill else nil end
function frame:FindFirstChild(name) return if name == "Value" then value else nil end
local bar = {}
function bar:WaitForChild() return frame end
local mainhud = {}
function mainhud:WaitForChild() return bar end
local player = { Parent = nil }
function player:GetAttribute(name) return attributes[name] end
function player:GetAttributeChangedSignal() return { Connect = function() end } end
local TweenService = {}
function TweenService:Create(target, _info, goal)
	tweensCreated += 1
	local tween = { state = "Begin", callbacks = {}, PlaybackState = rb.Enum.PlaybackState.Begin }
	tween.Completed = { Once = function(_, callback) table.insert(tween.callbacks, callback) end }
	function tween:Play() self.state = "Playing"; table.insert(live, self) end
	function tween:Cancel()
		if self.state == "Playing" then
			cancels += 1 -- only a tween that was still running
			self.state = "Cancelled"
			for _, callback in self.callbacks do callback(rb.Enum.PlaybackState.Cancelled) end
		end
	end
	function tween:finish()
		if self.state == "Playing" then
			self.state = "Completed"
			target.Size = goal.Size
			for _, callback in self.callbacks do callback(rb.Enum.PlaybackState.Completed) end
		end
	end
	return tween
end
local env = { mainhud = mainhud, player = player, TweenService = TweenService, Config = { BoostStaminaDisplayBase = 17 },
	TweenInfo = { new = function(...) return { ... } end }, Enum = rb.Enum,
	UDim2 = { new = function(...) return { ... } end, fromScale = function(x, y) return ("%.4f,%d"):format(x, y) end },
	task = { defer = function() end, spawn = function(fn) fn() end, wait = function() end },
	math = math, tonumber = tonumber, tostring = tostring, typeof = typeof }
local refresh = luau.load(block, { environment = env })()

local function settle()
	for _, tween in live do tween:finish() end
	table.clear(live)
end
local function show(stamina, maximum)
	attributes.BoostStaminaDisplayMax = maximum
	attributes.BoostStamina = stamina
	refresh()
	settle()
	return value.Text, fill.Size, fill.Visible
end

-- The base bar (17), a FlashSuit's (5) and the Silver Surfer's (70): the label reads 0 exactly
-- over an empty, hidden fill, and the maximum exactly over a full one.
for _, maximum in { 17, 5, 70 } do
	for _, stamina in { maximum, maximum - 0.005, maximum / 2, 1.4, 1.0, 0.999, 0.6, 0.0001, 0, 0.48, 0.96, 1.45, maximum } do
		local text, size, visible = show(stamina, maximum)
		local shown = tonumber(string.match(text, "^(%d+)/"))
		local shownMax = tonumber(string.match(text, "/(%d+)$"))
		local scale = tonumber(string.match(size, "^([%d%.]+),"))
		assert(shownMax == maximum, "the label's maximum")
		assert((shown == 0) == (scale == 0), ("max %d, stamina %.4f: the label reads 0 exactly when the fill is empty (%s, %.4f)"):format(maximum, stamina, text, scale))
		assert((shown == 0) == (visible == false), ("max %d, stamina %.4f: the empty fill is hidden, any other is shown"):format(maximum, stamina))
		assert((shown == maximum) == (scale == 1), ("max %d, stamina %.4f: the label reads the maximum exactly when the fill is full"):format(maximum, stamina))
		if shown > 0 and shown < maximum then
			assert(math.abs(scale - stamina / maximum) < 1e-4, "between the ends the fill stays the raw, continuous ratio")
		end
	end
end

-- One tween per new target, the old one cancelled first; nothing while nothing changes.
attributes.BoostStaminaDisplayMax = 17
tweensCreated, cancels = 0, 0
attributes.BoostStamina = 9
for _ = 1, 100 do refresh() end -- the 0.15 s poll, 15 s of it
assert(tweensCreated == 1, "an unchanged bar must not build tweens, built " .. tweensCreated)
attributes.BoostStamina = 8
refresh() -- while the tween to 9 still plays
assert(tweensCreated == 2 and cancels == 1, "the running tween is cancelled before the next one")
-- 0 then back up before the shrink ends: the cancelled shrink must not hide the fill afterwards.
attributes.BoostStamina = 0
refresh()
attributes.BoostStamina = 3
refresh()
settle()
assert(fill.Visible == true, "a cancelled shrink must not hide a refilled bar")
print("PASS stamina bar: 0 <=> empty and hidden, max <=> full (bars of 17, 5 and 70); 100 idle polls build 1 tween; cancel-before-next; no stale hide")
