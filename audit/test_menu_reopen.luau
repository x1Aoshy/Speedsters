-- test_menu_reopen.luau
-- Reopening a menu right after closing it (2026-09-18 report: "open the Index, pick a
-- character, open it again: the HUD hides and comes back, and the menu never opens").
--
-- The Index refused to open while its 0.2 s close was still animating, and told MenuEvents
-- it was still open all that time, so MenuEvents "closed" it again instead of opening it
-- and the HUD flashed away and back. Now a closing panel counts as closed, opening it cancels
-- the close, and a finished tween from an older open or close does nothing. The other menus
-- (which already cancel their close when opened) no longer count as open while closing.
--
-- Runs the Index's real open/close code and the real MenuEvents.Request.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function has(source, needle, message)
	assert(string.find(source, needle, 1, true), message)
end
local function between(source, first, last)
	local a = assert(string.find(source, first, 1, true), "chunk " .. first)
	local b = assert(string.find(source, last, a, true), "chunk end " .. last)
	return string.sub(source, a, b - 1)
end

-- Tweens that finish only when the test says so.
local tweens = {}
local function signal()
	local s = { listeners = {} }
	function s:Connect(fn)
		table.insert(self.listeners, fn)
		return { Disconnect = function() end }
	end
	function s:Fire(...)
		for _, fn in table.clone(self.listeners) do
			fn(...)
		end
	end
	return s
end
local TweenService = {
	Create = function(_, target, _, goal)
		local tween = { Target = target, Goal = goal, Completed = signal(), State = "Created" }
		function tween:Play()
			self.State = "Playing"
		end
		function tween:Cancel()
			if self.State == "Playing" then
				self.State = "Cancelled"
				self.Completed:Fire("Cancelled")
			end
		end
		function tween:Finish()
			if self.State == "Playing" then
				self.State = "Completed"
				for key, value in self.Goal do
					self.Target[key] = value
				end
				self.Completed:Fire("Completed")
			end
		end
		table.insert(tweens, tween)
		return tween
	end,
}
local function finishAll()
	for _, tween in table.clone(tweens) do
		tween:Finish()
	end
end

----------------------------------------------------------------------
-- The Index's open and close
----------------------------------------------------------------------
local index = fs.readFile("src/common/StarterGui/Index/IndexScript.client.luau")
local chunk = between(index, "-- Open / Close handling", "if closeButton then")
	.. "\nreturn { show = showPanel, hide = hidePanel, isOpen = function() return isOpen end }"
local screenGui = { Enabled = false, Name = "Index", IsA = function(_, class) return class == "ScreenGui" end }
local OPEN = { X = { Scale = 0.5, Offset = 0 } }
local CLOSED = { X = { Scale = 0.5, Offset = 0 }, Closed = true }
local mainFrame = { Position = OPEN, Visible = false }
local dim = { Visible = false, Active = false, BackgroundTransparency = 1, IsA = function(_, class) return class == "GuiObject" end }
local builds = 0
local failBuild = false
local panel = luau.load(chunk, {
	environment = setmetatable({
		mainFrame = mainFrame,
		screenGui = screenGui,
		dim = dim,
		isOpen = false,
		TweenService = TweenService,
		TweenInfo = { new = function() return {} end },
		Enum = { EasingStyle = {}, EasingDirection = {} },
		UDim2 = { new = function() return CLOSED end },
		SkinIndexRequest = { FireServer = function() end },
		rebuildGrid = function()
			builds += 1
			if failBuild then
				error("a card could not be drawn")
			end
		end,
		warn = function() end,
	}, { __index = _G }),
})()

panel.hide(true)
assert(not panel.isOpen() and screenGui.Enabled == false, "Starts closed")
panel.show()
assert(panel.isOpen() and screenGui.Enabled and mainFrame.Visible and builds == 1, "Opens")
finishAll()
assert(mainFrame.Position == OPEN, "...all the way")
panel.hide(false)
assert(not panel.isOpen() and screenGui.Enabled, "Closing: it counts as closed at once, while it slides away")
local closeTweens = #tweens
panel.show()
assert(panel.isOpen() and screenGui.Enabled and mainFrame.Visible, "Opened again mid-close: it opens (it used to refuse)")
-- The cut-short close's tween is cancelled; even if an old one finished now, nothing closes.
for index = 1, closeTweens do
	tweens[index].Completed:Fire("Completed")
end
assert(panel.isOpen() and screenGui.Enabled and mainFrame.Visible, "A tween from the old close never shuts the reopened panel")
finishAll()
panel.hide(false)
finishAll()
assert(not panel.isOpen() and screenGui.Enabled == false and mainFrame.Visible == false, "Closed and finished: hidden")
failBuild = true
panel.show()
assert(panel.isOpen() and screenGui.Enabled, "A card that cannot be drawn never leaves it half-open")
failBuild = false
panel.hide(true)
assert(not panel.isOpen() and screenGui.Enabled == false, "Closed at once (another menu)")
print("PASS Index: a closing panel counts as closed, reopening cancels the close, old tweens do nothing, a bad card never jams it")

----------------------------------------------------------------------
-- Through MenuEvents: open, close, open again at once
----------------------------------------------------------------------
do
	local function bindable(name)
		local event = { Name = name, Event = signal() }
		function event:Fire(...)
			self.Event:Fire(...)
		end
		function event:IsA(class)
			return class == "BindableEvent"
		end
		function event:Destroy() end
		return event
	end
	local playerScripts = { GetChildren = function() return {} end }
	local playerGui = {
		FindFirstChild = function(_, name)
			return if name == "Index" then screenGui else nil
		end,
	}
	local player = {
		WaitForChild = function() return playerScripts end,
		FindFirstChild = function(_, name) return if name == "PlayerGui" then playerGui else nil end,
	}
	local MenuEvents = luau.load(fs.readFile("src/common/ReplicatedStorage/Shared/MenuEvents.luau"), {
		environment = setmetatable({
			game = { GetService = function() return { LocalPlayer = player } end },
			Instance = { new = function() return bindable("") end },
		}, { __index = _G }),
	})()
	local hud = {}
	MenuEvents.HUDVisibilityChanged.Event:Connect(function(visible)
		table.insert(hud, visible)
	end)
	-- Wired exactly as IndexScript wires itself.
	has(index, 'if action == "Close" then\n\t\thidePanel(false)\n\telseif action == "Open" then\n\t\tshowPanel()', "(the Index's own wiring)")
	MenuEvents.Get("OpenIndexPanel").Event:Connect(function(action)
		if action == "Close" then
			panel.hide(false)
		elseif action == "Open" then
			panel.show()
		end
	end)
	MenuEvents.MarkReady("Index", function()
		return panel.isOpen()
	end)

	MenuEvents.Request("Index")
	finishAll()
	assert(panel.isOpen() and screenGui.Enabled, "The Index button opens it")
	MenuEvents.Request("Index")
	assert(not panel.isOpen(), "Pressed again: it closes")
	MenuEvents.Request("Index")
	assert(panel.isOpen() and screenGui.Enabled and hud[#hud] == false, "Pressed once more, mid-close: it opens (the HUD no longer just flashes)")
	finishAll()
	assert(panel.isOpen() and screenGui.Enabled, "...and stays open")
	print("PASS MenuEvents: open, close and open again at once opens the menu, with the HUD out of the way")
end

----------------------------------------------------------------------
-- The other menus: closing counts as closed
----------------------------------------------------------------------
do
	local UI = "src/common/StarterPlayer/StarterPlayerScripts/UI/"
	for file, name in {
		["src/common/StarterGui/Backpack/BackpackScript.client.luau"] = 'MenuEvents.MarkReady("Backpack", function() return isOpen and not isClosing end)',
		[UI .. "AbilitiesPanel.client.luau"] = 'MenuEvents.MarkReady("Abilities", function() return isOpen and not isClosing end)',
		[UI .. "EvolveController.client.luau"] = 'MenuEvents.MarkReady("Evolve", function() return isOpen and not isClosing end)',
		[UI .. "RebirthController.client.luau"] = 'MenuEvents.MarkReady("Rebirth", function() return isOpen and not isClosing end)',
		[UI .. "SettingsController.client.luau"] = 'MenuEvents.MarkReady("Settings", function() return isOpen and not isClosing end)',
		[UI .. "TeleportController.client.luau"] = 'MenuEvents.MarkReady("Teleport", function() return isOpen and not isClosing end)',
		[UI .. "TimeGiftController.client.luau"] = 'MenuEvents.MarkReady("Playtime", function() return isOpen and not isClosing end)',
		[UI .. "DailyRewardController.client.luau"] = 'MenuEvents.MarkReady("Daily", function() return open and not isClosing end)',
	} do
		local source = fs.readFile(file)
		has(source, name, file .. ": a closing panel counts as closed")
		assert(string.find(source, "and not isClosing then return end", 1, true), file .. ": ...and opening it cancels the close")
	end
	local shop = fs.readFile(UI .. "ShopController.client.luau")
	has(shop, 'MenuEvents.MarkReady("Shop", function() return isOpen and not isClosing end)', "The Shop too")
	has(shop, 'MenuEvents.MarkReady("Codes", function() return isOpen and not isClosing end)', "...and its Codes tab")
	print("PASS menus: every panel that animates its close counts as closed while closing, and opening it cancels the close")
end

print("ALL MENU REOPEN CHECKS PASSED")
