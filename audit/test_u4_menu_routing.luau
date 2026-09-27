-- audit/test_u4_menu_routing.luau (2026-09-26, owner): "verify that the Daily Rewards work and show
-- their UI; the Spin the Wheel shows Quests". Every lobby menu entry opens its own panel, the Spin
-- Wheel never ends up as the Quests, and the Daily claim works end to end on a fake clock.
--   1. the places: every panel the HUD / topbar opens is saved in StarterGui (the Spin Wheel's,
--      the Quests', the Daily's pieces their controllers wait for included); every side-menu button
--      (and the runtime Titles one) maps to a menu whose panel exists, none to Quests or SpinWheel;
--      the Spin HUD button's template (Time Gifts) is there;
--   2. Shared/MenuEvents: Spin -> OpenSpinWheelPanel -> SpinWheelGui, Quests -> OpenQuestsPanel ->
--      QuestGui, Daily -> OpenDailyPanel -> DailyReward, no other menu shares those events or GUIs;
--   3. the real MenuEvents with the controllers' real listeners (SpinWheelController,
--      QuestController, DailyRewardController): the Spin HUD button's and the lobby wheel prompt's
--      real click code open the Spin Wheel only; Dr. Eggman's request opens the Quests only; the
--      Daily opens the Daily; a second press closes;
--   4. the reported bug, reproduced and fixed: Dr. Eggman's quests opened TalkSeconds after the
--      talk whatever the player did meanwhile, so a Spin Wheel opened in those seconds was shut and
--      the Quests came up instead. LobbyNpcsClient's real talkToEggman now leaves a menu asked for
--      (or opened) after the talk alone; a plain talk, and a talk over an already open menu, still
--      open the Quests; only this player's press talks to him;
--   5. the Daily server (Social/DailyLoginSystem, the real script) on a fake clock with the real
--      ProfileReducers: day 1 claimable on join, one claim = one grant (a double press pays once),
--      the next window opens at 08:00 UTC after at least 12 h (or 20 h after the claim), Spin
--      tickets / Wins (with the permanent multiplier) / potions paid, a rejoin reads the saved
--      state, DailyCanClaim follows; the client panel shows the server's answer;
--   6. the topbar (UI/TopbarIconsController in a TopbarPlus mock, the real MenuEvents): the Daily
--      icon opens the Daily; its notice follows the claim state even when Remotes.DailyLoginUpdate
--      arrives after the controller started (it used FindFirstChild once) and follows DailyCanClaim.
-- Run: lune run audit/test_u4_menu_routing.luau   (from the project root; never writes a place)
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local PlaceFiles = require("./place_files")
local U4 = require("../src/common/ReplicatedStorage/Shared/Update4Config")
local RetentionMath = require("../src/common/ReplicatedStorage/Shared/RetentionMath")
local DATA = "../src/common/ServerScriptService/Services/Data/"
local ProfileReducers = require(DATA .. "ProfileReducers")
local ProfileCodec = require(DATA .. "ProfileCodec")

local ROOT = "src/common/"
local SHARED = ROOT .. "ReplicatedStorage/Shared/"
local UI = ROOT .. "StarterPlayer/StarterPlayerScripts/UI/"
local SPIN = UI .. "SpinWheelController.client.luau"
local QUEST = UI .. "QuestController.client.luau"
local DAILY = UI .. "DailyRewardController.client.luau"
local TOPBAR = UI .. "TopbarIconsController.client.luau"
local HUD = UI .. "MainHUDController.client.luau"
local NPC = ROOT .. "StarterPlayer/StarterPlayerScripts/Gameplay/LobbyNpcsClient.client.luau"
local DAILY_SERVER = ROOT .. "ServerScriptService/Social/DailyLoginSystem.server.luau"

local passed = 0
local function pass(text)
	passed += 1
	print("PASS " .. text)
end
local function read(path)
	return (fs.readFile(path):gsub("\r\n", "\n"))
end
local function has(source, needle, message)
	assert(string.find(source, needle, 1, true), message .. " (missing: " .. needle .. ")")
end
-- The text from `first` up to (not including) `last`, searched from `from` (1 by default).
local function between(source, first, last, message, from)
	local a = string.find(source, first, from or 1, true)
	assert(a, message .. ": start not found")
	local b = string.find(source, last, a + #first, true)
	assert(b, message .. ": end not found")
	return string.sub(source, a, b - 1)
end

----------------------------------------------------------------------
-- A fake scheduler (task.spawn / defer / delay / wait on a fake clock) and signals
----------------------------------------------------------------------
local now = 0
local timers = {}
local function resume(co, ...)
	local ok, problem = coroutine.resume(co, ...)
	if not ok then
		error(debug.traceback(co, tostring(problem)), 0)
	end
end
local Task = {}
function Task.spawn(fn, ...)
	local co = coroutine.create(fn)
	resume(co, ...)
	return co
end
function Task.defer(fn, ...)
	table.insert(timers, { at = now, fn = fn, args = table.pack(...) })
end
function Task.delay(seconds, fn, ...)
	table.insert(timers, { at = now + (seconds or 0), fn = fn, args = table.pack(...) })
end
function Task.wait(seconds)
	table.insert(timers, { at = now + (seconds or 0), co = coroutine.running() })
	return coroutine.yield()
end
local function advance(dt)
	local target = now + dt
	while true do
		local index, at = nil, math.huge
		for i, timer in timers do
			if timer.at <= target and timer.at < at then
				index, at = i, timer.at
			end
		end
		if not index then
			break
		end
		local timer = table.remove(timers, index)
		now = math.max(now, timer.at)
		if timer.co then
			if coroutine.status(timer.co) == "suspended" then
				resume(timer.co)
			end
		else
			Task.spawn(timer.fn, table.unpack(timer.args, 1, timer.args.n))
		end
	end
	now = target
end

local function newSignal()
	local signal = { handlers = {} }
	function signal:Connect(fn)
		local handler = { fn = fn, on = true }
		table.insert(self.handlers, handler)
		return {
			Connected = true,
			Disconnect = function(connection)
				handler.on = false
				connection.Connected = false
			end,
		}
	end
	function signal:Fire(...)
		for _, handler in table.clone(self.handlers) do
			if handler.on then
				handler.fn(...)
			end
		end
	end
	function signal:Count()
		local count = 0
		for _, handler in self.handlers do
			if handler.on then
				count += 1
			end
		end
		return count
	end
	return signal
end

local function bindable(name)
	local event = { Name = name or "BindableEvent", Event = newSignal() }
	function event:Fire(...)
		self.Event:Fire(...)
	end
	function event:IsA(class)
		return class == "BindableEvent" or class == "Instance"
	end
	function event:Destroy() end
	return event
end

-- An object with attributes and their changed signals.
local function attributed(o)
	local attributes, signals = {}, {}
	function o:GetAttribute(name)
		return attributes[name]
	end
	function o:SetAttribute(name, value)
		local old = attributes[name]
		attributes[name] = value
		if old ~= value and signals[name] then
			signals[name]:Fire()
		end
	end
	function o:GetAttributeChangedSignal(name)
		signals[name] = signals[name] or newSignal()
		return signals[name]
	end
	return o
end

-- A container whose children are found by name; WaitForChild waits (on the fake clock) for a child
-- added later with :Add, up to its timeout.
local function container(children)
	local waiting = {}
	local box = { _children = children }
	function box:FindFirstChild(name)
		return children[name]
	end
	function box:WaitForChild(name, timeout)
		if children[name] ~= nil then
			return children[name]
		end
		local co = coroutine.running()
		local entry = { co = co, name = name, done = false }
		table.insert(waiting, entry)
		if timeout then
			Task.delay(timeout, function()
				if not entry.done then
					entry.done = true
					resume(co, nil)
				end
			end)
		end
		return coroutine.yield()
	end
	function box:Add(name, child)
		children[name] = child
		for _, entry in table.clone(waiting) do
			if entry.name == name and not entry.done then
				entry.done = true
				resume(entry.co, child)
			end
		end
	end
	function box:GetChildren()
		local list = {}
		for _, child in children do
			table.insert(list, child)
		end
		return list
	end
	return setmetatable(box, {
		__index = function(_, key)
			return children[key]
		end,
	})
end

-- A ScreenGui: Enabled with its changed signal, ChildAdded, no children.
local function screenGui(name)
	local props = { Name = name, Enabled = false }
	local signals = {}
	local function signalFor(key)
		signals[key] = signals[key] or newSignal()
		return signals[key]
	end
	local methods = {
		IsA = function(_, class)
			return class == "ScreenGui" or class == "LayerCollector" or class == "Instance"
		end,
		GetPropertyChangedSignal = function(_, property)
			return signalFor(property)
		end,
		GetChildren = function()
			return {}
		end,
		FindFirstChild = function()
			return nil
		end,
	}
	return setmetatable({}, {
		__index = function(_, key)
			if methods[key] then
				return methods[key]
			elseif key == "ChildAdded" then
				return signalFor("ChildAdded")
			end
			return props[key]
		end,
		__newindex = function(_, key, value)
			local old = props[key]
			props[key] = value
			if old ~= value and signals[key] then
				signals[key]:Fire()
			end
		end,
	})
end

----------------------------------------------------------------------
-- 1. The places
----------------------------------------------------------------------
local menuSource = read(SHARED .. "MenuEvents.luau")
local EVENT, GUI = luau.load(
	between(menuSource, "local MENU_EVENT_NAMES = {", "local function getSingleBindable", "MENU_EVENT_NAMES")
		.. between(menuSource, "local MENU_TO_GUI = {", "local function getGuiForMenu", "MENU_TO_GUI")
		.. "\nreturn MENU_EVENT_NAMES, MENU_TO_GUI"
)()
local hudSource = read(HUD)
local buttonEventMap = luau.load(between(hudSource, "local buttonEventMap = {", "local function setupSidebarButton", "buttonEventMap") .. "\nreturn buttonEventMap")()
local spinSource = read(SPIN)
local questSource = read(QUEST)
local dailySource = read(DAILY)

-- Panels made at runtime (never saved in StarterGui).
local RUNTIME_GUIS = { AdminAbusePanelGui = true, RacePanelGui = true, ["Codes Modal"] = true, ["Update Logs"] = true, RankRewardGui = true }
-- What each controller waits for with no timeout: a missing piece and the panel (and, for the Spin
-- Wheel, its HUD button) never appears.
local SPIN_PIECES = {
	{ "Frame" }, { "Frame", "Spin Wheel" }, { "Frame", "Spin Wheel", "Spin" }, { "Frame", "Spin Wheel", "ImageLabel" },
	{ "Frame", "Spin Wheel", "SliceColours" }, { "Frame", "Arrow" }, { "Frame", "Arrow", "ImageLabel" }, { "Frame", "Close" },
	{ "Frame", "HubCap" }, { "Frame", "WinsSpin" }, { "Frame", "WinsSpin", "Price" }, { "Frame", "WinsCaption" },
	{ "Frame", "X10" }, { "Frame", "X10", "Price" }, { "Frame", "X10Caption" },
	{ "Button" }, { "Button", "Claim" }, { "Button", "TextLabel" }, { "Button", "X1", "Price" }, { "Button", "X3", "Price" },
}
local QUEST_PIECES = { { "Frame" }, { "Frame", "Close" }, { "Frame", "Timer" }, { "Dim" } }
local DAILY_PIECES = { { "Days31" }, { "Days31", "ScrollingFrame" }, { "Days31", "RewardResult" }, { "Dim" } }
local function find(root, path)
	local node = root
	for _, name in path do
		node = node and node:FindFirstChild(name)
	end
	return node
end
for _, needle in { 'gui:WaitForChild("Frame")', 'wheel:WaitForChild("SliceColours")', 'wheelHolder:WaitForChild("X10Caption")', 'row:WaitForChild("Claim")' } do
	has(spinSource, needle, "SpinWheelController waits for the saved pieces this test checks")
end
has(dailySource, 'gui:WaitForChild("Dim")', "DailyRewardController waits for Dim")

local placeGuis = nil
for _, place in PlaceFiles.Places do
	local game = roblox.deserializePlace(fs.readFile(place.file))
	local starterGui = game:GetService("StarterGui")
	local names = {}
	for _, gui in starterGui:GetChildren() do
		if gui:IsA("ScreenGui") then
			names[gui.Name] = true
		end
	end
	placeGuis = placeGuis or names
	for _, menu in { "SpinWheel", "Quests", "Daily", "Playtime", "Titles", "Streak", "PlaytimeBoost", "Community", "Settings", "Afk", "Shop", "Index", "Backpack", "Rebirth", "Evolve", "Teleport", "Abilities", "Worlds" } do
		assert(names[GUI[menu]], place.key .. ": StarterGui has no " .. tostring(GUI[menu]) .. " (the " .. menu .. " panel)")
	end
	for _, spec in { { "SpinWheelGui", SPIN_PIECES }, { "QuestGui", QUEST_PIECES }, { "DailyReward", DAILY_PIECES } } do
		local gui = starterGui:FindFirstChild(spec[1])
		assert(gui.Enabled == false and gui.ResetOnSpawn == false, place.key .. ": " .. spec[1] .. " is saved off, kept on respawn")
		for _, path in spec[2] do
			assert(find(gui, path), place.key .. ": " .. spec[1] .. "." .. table.concat(path, ".") .. " is missing (its controller would wait forever)")
		end
	end
	for index = 1, 6 do
		assert(find(starterGui.SpinWheelGui, { "Frame", "Spin Wheel", "Spin", "Slice" .. index, "Icon" }), place.key .. ": Spin Wheel slice " .. index)
	end

	local mainhud = starterGui:FindFirstChild("Mainhud")
	local leftBar = mainhud and mainhud:FindFirstChild("LeftSideBar")
	assert(leftBar, place.key .. ": Mainhud.LeftSideBar")
	local buttons = { "Titles" } -- MainHUDController 5c adds it at runtime
	for _, child in leftBar:GetChildren() do
		if child:IsA("ImageButton") then
			table.insert(buttons, child.Name)
		end
	end
	assert(#buttons >= 9, place.key .. ": the side menu has its buttons")
	for _, name in buttons do
		local menu = buttonEventMap[name]
		assert(menu, place.key .. ": side button " .. name .. " opens nothing (buttonEventMap)")
		assert(menu ~= "Quests" and menu ~= "Quest" and menu ~= "SpinWheel", place.key .. ": side button " .. name .. " opens " .. menu)
		assert(EVENT[menu], place.key .. ": side button " .. name .. " -> " .. menu .. " has no MenuEvents event")
		local guiName = GUI[menu] or menu
		assert(names[guiName] or RUNTIME_GUIS[guiName], place.key .. ": side button " .. name .. " -> " .. menu .. " -> " .. guiName .. " is not in StarterGui")
	end
	-- The Spin HUD button is a copy of Time Gifts (its label, icon and "!" badge).
	local template = leftBar:FindFirstChild("Time Gifts")
	assert(template and template:IsA("ImageButton") and template:FindFirstChild("Name") and template:FindFirstChild("Icon") and template:FindFirstChild("!"),
		place.key .. ": LeftSideBar.Time Gifts (the Spin HUD button's template) with Name, Icon and !")
	assert(buttonEventMap["Time Gifts"] == "Playtime", "Time Gifts opens the Time Gifts")
	assert(not leftBar:FindFirstChild("SpinWheel") and not mainhud:FindFirstChild("SpinWheel"), place.key .. ": no saved SpinWheel button to collide with the runtime one")
	for _, prompt in game:GetService("Workspace"):GetDescendants() do
		if prompt:IsA("ProximityPrompt") and string.find(string.lower(prompt.ActionText .. " " .. prompt.ObjectText), "quest", 1, true) then
			error(place.key .. ": a saved prompt talks about quests: " .. prompt:GetFullName())
		end
	end
end
-- The Spin HUD button (a copy of Time Gifts) lives in Mainhud, never in LeftSideBar, where
-- MainHUDController would wire it by name.
local buildHud = between(spinSource, "local function buildHudButton(mainhud)", "-- Beside x2 Speed", "buildHudButton")
has(buildHud, 'button.Name = HUD_BUTTON_NAME', "the copy is renamed")
has(spinSource, 'local HUD_BUTTON_NAME = "SpinWheel"', "the Spin HUD button's name")
has(buildHud, "button.Parent = mainhud", "the Spin HUD button sits in Mainhud")
has(hudSource, "leftBar.ChildAdded:Connect(setupSidebarButton)", "only LeftSideBar buttons are wired by name")
has(hudSource, "local eventName = buttonEventMap[child.Name]\n\t\tif eventName and MenuEvents.Request(eventName) then", "the side buttons open their menu")
pass("places: the Spin Wheel, Quests and Daily panels are saved with every piece their controllers wait for; every side-menu button (and Titles) opens its own panel, none the Quests or the Spin Wheel; the Spin HUD button's template is there")

----------------------------------------------------------------------
-- 2. The MenuEvents tables
----------------------------------------------------------------------
do
	assert(EVENT.SpinWheel == "OpenSpinWheelPanel" and GUI.SpinWheel == "SpinWheelGui", "SpinWheel -> OpenSpinWheelPanel -> SpinWheelGui")
	assert(EVENT.Quests == "OpenQuestsPanel" and EVENT.Quest == "OpenQuestsPanel" and GUI.Quests == "QuestGui" and GUI.Quest == "QuestGui", "Quests -> OpenQuestsPanel -> QuestGui")
	assert(EVENT.Daily == "OpenDailyPanel" and GUI.Daily == "DailyReward", "Daily -> OpenDailyPanel -> DailyReward")
	local families = { SpinWheel = { SpinWheel = true }, Quests = { Quests = true, Quest = true }, Daily = { Daily = true } }
	for owner, members in families do
		for menu, event in EVENT do
			if event == EVENT[owner] then
				assert(members[menu], menu .. " shares " .. owner .. "'s event " .. event)
			end
		end
		for menu, gui in GUI do
			if gui == GUI[owner] then
				assert(members[menu], menu .. " shares " .. owner .. "'s panel " .. gui)
			end
		end
	end
	-- Each controller listens to its own event only.
	has(spinSource, 'MenuEvents.Get("OpenSpinWheelPanel").Event:Connect(', "the Spin Wheel listens")
	has(questSource, 'MenuEvents.Get("OpenQuestsPanel").Event:Connect(', "the Quests listen")
	has(dailySource, 'MenuEvents.Get("OpenDailyPanel").Event:Connect(', "the Daily listens")
	for file, source in { [SPIN] = spinSource, [DAILY] = dailySource } do
		assert(not string.find(source, "OpenQuestsPanel", 1, true) and not string.find(source, 'Request("Quests"', 1, true), file .. " opens the Quests")
	end
	assert(not string.find(questSource, "OpenSpinWheelPanel", 1, true) and not string.find(questSource, 'Request("SpinWheel"', 1, true), "QuestController opens the Spin Wheel")
	-- Nothing but Dr. Eggman opens the Quests.
	local openers = {}
	local function walk(dir)
		for _, name in fs.readDir(dir) do
			local path = dir .. "/" .. name
			if fs.isDir(path) then
				walk(path)
			elseif name:match("%.luau$") then
				local source = fs.readFile(path)
				if string.find(source, 'Request("Quests"', 1, true) or string.find(source, 'Request("Quest"', 1, true)
					or (string.find(source, '"OpenQuestsPanel"', 1, true) and not path:find("MenuEvents.luau", 1, true) and not path:find("QuestController", 1, true)) then
					table.insert(openers, path)
				end
			end
		end
	end
	walk("src/common")
	walk("src/worlds")
	assert(#openers == 1 and openers[1]:find("LobbyNpcsClient", 1, true), "the Quests open from Dr. Eggman only: " .. table.concat(openers, ", "))
	pass("MenuEvents: Spin -> OpenSpinWheelPanel -> SpinWheelGui, Quests -> OpenQuestsPanel -> QuestGui, Daily -> OpenDailyPanel -> DailyReward, no other menu shares them; only Dr. Eggman opens the Quests")
end

----------------------------------------------------------------------
-- 3. The real MenuEvents with the controllers' real listeners
----------------------------------------------------------------------
local guis = {}
for name in placeGuis do
	guis[name] = screenGui(name)
end
for name in RUNTIME_GUIS do
	guis[name] = screenGui(name)
end
local playerGui = container(guis)
local playerScripts = { GetChildren = function()
	return {}
end }
local player = attributed({ Name = "Gekkoh", UserId = 767108248 })
function player:WaitForChild(name)
	return if name == "PlayerScripts" then playerScripts elseif name == "PlayerGui" then playerGui else nil
end
function player:FindFirstChild(name)
	return if name == "PlayerGui" then playerGui else nil
end
local MenuEvents = luau.load(menuSource, {
	environment = setmetatable({
		game = { GetService = function(_, name)
			assert(name == "Players", "MenuEvents asks for " .. tostring(name))
			return { LocalPlayer = player }
		end },
		Instance = { new = function(class)
			assert(class == "BindableEvent", "MenuEvents makes a " .. tostring(class))
			return bindable()
		end },
	}, { __index = _G }),
})()
local hudShown = {}
MenuEvents.HUDVisibilityChanged.Event:Connect(function(visible, menuName)
	table.insert(hudShown, { visible, menuName })
end)

-- A controller's real listener block, run on fake open / close functions. `state` holds the
-- controller's own flags (read by the block through the environment).
local panels = {}
local function runListener(menu, guiName, source, first, last, flags)
	local state = { opens = 0, closes = 0 }
	for key, value in flags do
		state[key] = value
	end
	local gui = guis[guiName]
	local function openPanel()
		if state.isOpen or state.open then
			return
		end
		state.opens += 1
		state.isOpen, state.open, state.isClosing = true, true, false
		-- As the real openPanel: Spin and Quests close the others and hide the HUD themselves.
		if menu ~= "Daily" then
			MenuEvents.CloseAll:Fire(menu)
			MenuEvents.SetHUDVisible(false, menu)
		end
		gui.Enabled = true
	end
	local function closePanel()
		if not (state.isOpen or state.open) then
			return
		end
		state.closes += 1
		state.isOpen, state.open, state.isClosing = false, false, false
		gui.Enabled = false
	end
	-- luau.load resolves a chunk's globals once, at load: the flags are read through `S` instead.
	local code = between(source, first, last, menu .. " listener")
	for key in flags do
		code = string.gsub(code, "%f[%w_]" .. key .. "%f[^%w_]", "S." .. key)
	end
	local env = setmetatable({ MenuEvents = MenuEvents, openPanel = openPanel, closePanel = closePanel, S = state }, { __index = _G })
	luau.load(code, { environment = env })()
	panels[menu] = { state = state, gui = gui }
	return state
end
has(spinSource, 'MenuEvents.CloseAll:Fire("SpinWheel")', "the Spin Wheel's openPanel closes the other menus")
has(questSource, 'MenuEvents.CloseAll:Fire("Quests")', "the Quests' openPanel closes the other menus")
runListener("SpinWheel", "SpinWheelGui", spinSource, 'MenuEvents.Get("OpenSpinWheelPanel").Event:Connect(function(action)', "-- The wheel in the lobby", { isOpen = false })
runListener("Quests", "QuestGui", questSource, 'MenuEvents.Get("OpenQuestsPanel").Event:Connect(function(action)', "UserInputService.InputBegan:Connect(function(input, processed)", { isOpen = false, isClosing = false })
runListener("Daily", "DailyReward", dailySource, 'MenuEvents.Get("OpenDailyPanel").Event:Connect(function(action)', "UserInputService.InputBegan:Connect(function(input, processed)", { open = false, isClosing = false })

local function onlyOpen(expected, message)
	for menu, panel in panels do
		local open = panel.state.isOpen == true or panel.state.open == true
		assert(open == (menu == expected), message .. ": " .. menu .. (if open then " is open" else " is shut"))
		assert(panel.gui.Enabled == open, message .. ": " .. menu .. "'s ScreenGui Enabled = " .. tostring(panel.gui.Enabled))
	end
end
local function closeAll()
	MenuEvents.CloseAll:Fire()
	onlyOpen(nil, "after CloseAll")
end

-- The Spin HUD button's real click code (SpinWheelController buildHudButton).
local hudClick = between(spinSource, "\tbutton.Activated:Connect(function()", '\tlabel.Text = "Spin"', "the Spin HUD button's click", string.find(spinSource, "local function buildHudButton", 1, true))
has(hudClick, 'MenuEvents.Request("SpinWheel")', "the Spin HUD button requests the Spin Wheel")
local hudButton = { Activated = newSignal() }
luau.load(hudClick, { environment = setmetatable({ button = hudButton, MenuEvents = MenuEvents, PurchaseButtonSound = { Play = function() end } }, { __index = _G }) })()
-- The lobby wheel's prompt.
local promptCode = between(spinSource, "prompt.Triggered:Connect(function()", "local idleAngle = 0", "the lobby wheel's prompt")
local lobbyPrompt = { Triggered = newSignal() }
luau.load(promptCode, { environment = setmetatable({ prompt = lobbyPrompt, MenuEvents = MenuEvents, Request = { FireServer = function() end } }, { __index = _G }) })()

hudButton.Activated:Fire()
onlyOpen("SpinWheel", "the Spin HUD button")
assert(hudShown[#hudShown][1] == false, "the HUD steps aside for the Spin Wheel")
hudButton.Activated:Fire()
onlyOpen(nil, "the Spin HUD button again (closes)")
lobbyPrompt.Triggered:Fire(player)
onlyOpen("SpinWheel", "the lobby wheel's prompt")
MenuEvents.Request("Quests", "Npc")
onlyOpen("Quests", "Dr. Eggman's request")
MenuEvents.Request("Quests", "Npc")
onlyOpen("Quests", "Dr. Eggman's request with the Quests open (stays open)")
hudButton.Activated:Fire()
onlyOpen("SpinWheel", "the Spin HUD button over the Quests")
MenuEvents.Request("Daily")
onlyOpen("Daily", "the Daily")
MenuEvents.Request("Daily")
onlyOpen(nil, "the Daily again (closes)")
MenuEvents.Get("OpenDailyPanel"):Fire("Open") -- the join chain (UpdateLogsController)
onlyOpen("Daily", "the Daily from the join chain")
hudButton.Activated:Fire()
onlyOpen("SpinWheel", "the Spin HUD button over the Daily")
closeAll()
assert(panels.Quests.state.opens == 1, "the Quests opened only when Dr. Eggman asked (once: the second request found them open)")
pass("the real MenuEvents + the controllers' listeners: the Spin HUD button and the lobby wheel's prompt open the Spin Wheel only (a second press closes it), Dr. Eggman opens the Quests only, the Daily opens the Daily, each over the others")

----------------------------------------------------------------------
-- 4. Dr. Eggman's talk (the reported bug)
----------------------------------------------------------------------
do
	local npcSource = read(NPC)
	has(npcSource, "prompt.Triggered:Connect(function(who)", "Eggman's prompt reads who pressed it")
	has(npcSource, "(who ~= nil and who ~= player)", "only this player's press talks to him")
	local talkCode = between(npcSource, "local talking = false", "----------------------------------------------------------------------\n-- The Flash: the sign-up window", "talkToEggman")
		.. "\nreturn talkToEggman"
	local CLIENT = { TalkSeconds = 1.9 }
	local talk = luau.load(talkCode, {
		environment = setmetatable({
			MenuEvents = MenuEvents,
			task = Task,
			CLIENT = CLIENT,
			player = player,
			LobbyNpcPose = { Defs = {} },
			react = function() end,
			say = function() end,
			words = function(key)
				return key
			end,
			PurchaseButtonSound = { Play = function() end },
		}, { __index = _G }),
	})()
	local prompt = { Enabled = true, Parent = true }
	local npc = { prompt = prompt, poseKind = "Eggman" }
	local watchers = MenuEvents.CloseAll.Event:Count()

	-- What the owner saw, the old way (the quests' Request TalkSeconds later, unconditional): the
	-- Spin Wheel opened meanwhile is replaced by the Quests.
	Task.delay(CLIENT.TalkSeconds, function()
		MenuEvents.Request("Quests", "Npc")
	end)
	advance(0.6)
	hudButton.Activated:Fire()
	onlyOpen("SpinWheel", "old way: the Spin opens during Eggman's line")
	advance(CLIENT.TalkSeconds)
	onlyOpen("Quests", "old way: ...and the Quests replace it (the report)")
	closeAll()

	-- A plain talk: the quests open after his line; the prompt comes back.
	talk(npc)
	assert(prompt.Enabled == false, "the prompt rests while he talks")
	advance(CLIENT.TalkSeconds - 0.1)
	onlyOpen(nil, "the line first")
	advance(0.2)
	onlyOpen("Quests", "a plain talk opens the Quests")
	advance(1.1)
	assert(prompt.Enabled == true, "the prompt is back")
	closeAll()

	-- The report: the Spin Wheel's button pressed during his line keeps the Spin Wheel.
	talk(npc)
	advance(0.6)
	hudButton.Activated:Fire()
	onlyOpen("SpinWheel", "the Spin opens during Eggman's line")
	advance(CLIENT.TalkSeconds)
	onlyOpen("SpinWheel", "the Spin Wheel stays: the Quests never replace it")
	advance(1.1)
	assert(prompt.Enabled == true, "the prompt is back after a cancelled talk")
	closeAll()
	-- The lobby wheel's prompt, the Daily's icon: the same.
	talk(npc)
	advance(0.3)
	lobbyPrompt.Triggered:Fire(player)
	advance(CLIENT.TalkSeconds + 1.1)
	onlyOpen("SpinWheel", "the lobby wheel's prompt during his line keeps the Spin Wheel")
	closeAll()
	talk(npc)
	advance(0.3)
	MenuEvents.Request("Daily")
	advance(CLIENT.TalkSeconds + 1.1)
	onlyOpen("Daily", "the Daily's icon during his line keeps the Daily")
	closeAll()
	-- A menu that opens by itself meanwhile (the Daily at the end of the join chain) wins too.
	talk(npc)
	advance(0.3)
	MenuEvents.Get("OpenDailyPanel"):Fire("Open")
	advance(CLIENT.TalkSeconds + 1.1)
	onlyOpen("Daily", "the Daily opening by itself during his line stays")
	closeAll()
	-- A respawn (CloseAll with no name) during his line: nothing opens.
	talk(npc)
	advance(0.3)
	MenuEvents.CloseAll:Fire()
	advance(CLIENT.TalkSeconds + 1.1)
	onlyOpen(nil, "a respawn during his line")
	-- Talking to him with the Spin Wheel already open: he is the newer request, the Quests open.
	hudButton.Activated:Fire()
	talk(npc)
	advance(CLIENT.TalkSeconds + 1.1)
	onlyOpen("Quests", "a talk over the open Spin Wheel opens the Quests")
	closeAll()
	assert(MenuEvents.CloseAll.Event:Count() == watchers, "every talk lets go of its CloseAll watch")
	pass("Dr. Eggman (the report, reproduced the old way): a menu asked for during his line (the Spin HUD button, the lobby wheel, the Daily) or opening by itself keeps its place and the Quests stay shut; a plain talk and a talk over an open menu still open the Quests; a respawn cancels; the prompt always comes back")
end

----------------------------------------------------------------------
-- 5. The Daily server on a fake clock
----------------------------------------------------------------------
local DailyRewardsData = luau.load(read(SHARED .. "DailyRewardsData.luau"), { environment = setmetatable({ Color3 = roblox.Color3 }, { __index = _G }) })()
local DailyRewards = luau.load(read(SHARED .. "DailyRewards.luau"), {
	environment = setmetatable({
		game = { GetService = function()
			return { WaitForChild = function(self)
				return self
			end, FindFirstChild = function()
				return nil
			end }
		end },
		require = function()
			return DailyRewardsData
		end,
	}, { __index = _G }),
})()
local DAY0 = 1790380800 -- 2026-09-26 00:00 UTC
local H = 3600
do
	local unix = DAY0 + 7 * H -- 07:00 UTC, before the 08:00 reset
	local mono = 1000
	local sent = {}
	local remotes = container({})
	local function remote(className)
		assert(className == "RemoteEvent", "the Daily makes a " .. tostring(className))
		local r = { OnServerEvent = newSignal() }
		-- Each server handler runs in its own thread, as in Roblox.
		local inner = r.OnServerEvent
		r.OnServerEvent = { Connect = function(_, fn)
			return inner:Connect(function(...)
				Task.spawn(fn, ...)
			end)
		end, Fire = function(_, ...)
			inner:Fire(...)
		end }
		function r:FireClient(_, payload)
			table.insert(sent, payload)
		end
		return setmetatable(r, { __newindex = function(self, key, value)
			if key == "Parent" then
				remotes:Add(rawget(self, "Name"), self)
			end
			rawset(self, key, value)
		end })
	end

	-- The profile and DataService (the real reducers; commits yield like a DataStore write).
	local profile = ProfileCodec.CreateDefault()
	local committed, grants = {}, {}
	local function copy(value)
		if type(value) ~= "table" then
			return value
		end
		local out = {}
		for k, v in value do
			out[k] = copy(v)
		end
		return out
	end
	local playerOne
	local function project() -- Services/Stats/StatsProjection's daily block
		local daily = profile.DailyLoginState
		local days = {}
		for _, day in daily.ClaimedDays do
			table.insert(days, tostring(day))
		end
		playerOne:SetAttribute("DailyClaimedDaysCsv", table.concat(days, ","))
		playerOne:SetAttribute("DailyLastClaimAt", daily.LastClaimAt or 0)
		playerOne:SetAttribute("DailyLastClaimedDay", daily.LastClaimedDay or 0)
		playerOne:SetAttribute("DailyRewardCycle", daily.Cycle or 1)
		playerOne:SetAttribute("DailyStateReady", true)
	end
	local DataService = {
		GetHandle = function(userId)
			return { userId = userId }
		end,
		Commit = function(_, request)
			Task.wait(0.2)
			if committed[request.operationId] then
				return { kind = "AlreadyCommitted" }
			end
			local draft = copy(profile)
			for _, command in request.commands do
				local result = ProfileReducers.ApplyCommand(draft, command, unix)
				if not result.ok then
					return { kind = "Rejected", error = result.error }
				end
			end
			profile = draft
			committed[request.operationId] = true
			for _, command in request.commands do
				if command.kind ~= "SetDailyState" then
					table.insert(grants, command)
				end
			end
			project()
			return { kind = "Committed" }
		end,
		Inspect = function()
			return { ok = true, value = { profile = copy(profile) } }
		end,
	}
	local PotionServer = { GetSpeedPotionMultiplier = function()
		return 1
	end, GetServerBoostMultiplier = function()
		return 1
	end }
	local tokens = { DailyRewards = {}, DataService = {}, PotionServer = {} }
	local modules = { [tokens.DailyRewards] = DailyRewards, [tokens.DataService] = DataService, [tokens.PotionServer] = PotionServer }

	local players = { PlayerAdded = newSignal(), PlayerRemoving = newSignal(), list = {} }
	function players:GetPlayers()
		return table.clone(self.list)
	end
	local function newPlayer()
		local p = attributed({ Name = "Gekkoh", UserId = 767108248, Parent = players })
		local wins = { Value = 0, Parent = true, IsA = function(_, class)
			return class == "IntValue"
		end }
		local speed = { Value = 1, Parent = true, IsA = function(_, class)
			return class == "NumberValue"
		end }
		local raw = { Value = 1, Parent = true, IsA = function(_, class)
			return class == "NumberValue"
		end }
		local children = { leaderstats = container({ Wins = wins, Speed = speed }), SpeedsterData = container({ RawSpeed = raw }) }
		function p:FindFirstChild(name)
			return children[name]
		end
		function p:GetJoinData()
			return { TeleportData = nil }
		end
		return p
	end
	local G = {
		SpeedsterGetPermanentWinsMultiplier = function()
			return 2 -- the x2 Wins pass
		end,
		SpeedsterGetTotalGainMultiplier = function()
			return 1
		end,
		SpeedsterGetSuitSpeedGainMultiplierForSkin = function()
			return 1
		end,
		SpeedsterGetRebirthSpeedGainMultiplier = function()
			return 1
		end,
		SpeedsterSetDailyLoginState = function()
			return true
		end,
		SpeedsterSavePlayer = function()
			return true
		end,
	}
	local services = {
		Players = players,
		ReplicatedStorage = container({ Shared = container({ DailyRewards = tokens.DailyRewards }), Remotes = remotes }),
		DataStoreService = { GetDataStore = function()
			return { GetAsync = function()
				return nil
			end }
		end },
		ServerScriptService = { Services = { Data = { DataService = tokens.DataService }, PotionServer = tokens.PotionServer } },
	}
	local env = setmetatable({
		game = { GetService = function(_, name)
			return assert(services[name], "the Daily asks for " .. tostring(name))
		end },
		require = function(token)
			return assert(modules[token], "the Daily requires something unexpected")
		end,
		Instance = { new = remote },
		task = Task,
		os = { time = function()
			return unix
		end, clock = function()
			return mono
		end },
		_G = G,
		print = function() end,
		warn = function(text)
			error("the Daily warned: " .. tostring(text))
		end,
	}, { __index = _G })
	Task.spawn(luau.load(read(DAILY_SERVER), { environment = env }))
	local request = remotes:FindFirstChild("DailyLoginRequest")
	assert(request and remotes:FindFirstChild("DailyLoginUpdate"), "the Daily makes its two remotes")

	local function join()
		playerOne = newPlayer()
		project()
		playerOne:SetAttribute("DataLoaded", true)
		table.insert(players.list, playerOne)
		players.PlayerAdded:Fire(playerOne)
		advance(0.1)
	end
	local function leave()
		table.remove(players.list, table.find(players.list, playerOne))
		players.PlayerRemoving:Fire(playerOne)
	end
	local function ask(action)
		mono += 1 -- past the Refresh throttle
		request.OnServerEvent:Fire(playerOne, action)
		advance(0.5)
		return sent[#sent]
	end

	join()
	local first = sent[#sent]
	assert(first and first.CanClaim == true and first.NextDay == 1 and first.LoadFailed == false, "a new player can claim Day 1 on join")
	assert(playerOne:GetAttribute("DailyCanClaim") == true, "DailyCanClaim = true (the topbar notice, the join chain)")

	-- Day 1 (500 Speed) at 07:00 UTC, pressed twice at once: paid once.
	local speedBefore = profile.Speed
	request.OnServerEvent:Fire(playerOne, "Claim")
	request.OnServerEvent:Fire(playerOne, "Claim")
	advance(0.5)
	assert(#grants == 1 and grants[1].kind == "GrantExact" and grants[1].stat == "Speed" and grants[1].amount == 500, "Day 1 pays 500 Speed once")
	assert(profile.Speed == speedBefore + 500, "...into the saved profile")
	local after = sent[#sent]
	assert(after.ClaimSucceeded == true and after.CanClaim == false and after.NextDay == 2, "the answer: claimed, Day 2 next")
	assert(after.SecondsRemaining == 12 * H, ("07:00 claim: the next opens 12 h later (floor), got %d s"):format(after.SecondsRemaining))
	assert(profile.DailyLoginState.LastClaimedDay == 1 and profile.DailyLoginState.ClaimedDays[1] == 1, "the saved state")
	assert(playerOne:GetAttribute("DailyCanClaim") == false, "DailyCanClaim = false after the claim")
	local again = ask("Claim")
	assert(#grants == 1 and again.CanClaim == false, "a second claim in the same window pays nothing")

	-- 18:59: still waiting; 19:00: Day 2 (1 Spin ticket).
	unix = DAY0 + 18 * H + 59 * 60
	assert(ask("Refresh").SecondsRemaining == 60, "one minute left at 18:59")
	unix = DAY0 + 19 * H
	local open2 = ask("Refresh")
	assert(open2.CanClaim == true and open2.NextDay == 2, "Day 2 opens at 19:00")
	assert(playerOne:GetAttribute("DailyCanClaim") == true, "DailyCanClaim follows")
	local tickets = profile.SpinTickets or 0
	local claimed2 = ask("Claim")
	assert(grants[2].kind == "GrantSpinTickets" and grants[2].amount == 1 and (profile.SpinTickets or 0) == tickets + 1, "Day 2 pays 1 Spin ticket")
	-- Claimed at 19:00 UTC: the next opens at the 08:00 UTC reset (13 h), not 24 h later.
	assert(claimed2.SecondsRemaining == 13 * H, ("19:00 claim: the next opens at 08:00 UTC, got %d s"):format(claimed2.SecondsRemaining))

	-- A rejoin reads the saved state.
	leave()
	join()
	local rejoin = sent[#sent]
	assert(rejoin.CanClaim == false and rejoin.NextDay == 3 and rejoin.ClaimedDays[1] == 1 and rejoin.ClaimedDays[2] == 2, "a rejoin keeps Days 1-2")

	-- Next day 08:00 UTC: Day 3, 250 Wins x2 (the permanent multiplier).
	unix = DAY0 + 24 * H + 8 * H
	local wins = profile.Wins
	assert(ask("Claim").ClaimSucceeded == true, "Day 3 claimed at 08:00 UTC")
	assert(grants[3].stat == "Wins" and grants[3].amount == 500 and profile.Wins == wins + 500, "Day 3: 250 Wins x2")
	-- Day 4 (Speed) and Day 5 (a 2x Speed potion, 15 min): 20 h after each claim at the latest.
	unix += 20 * H
	ask("Claim")
	unix += 20 * H
	ask("Claim")
	assert(grants[4].stat == "Speed" and grants[5].kind == "GrantBuff" and grants[5].grant.kind == "SpeedPotion" and grants[5].grant.addedSeconds == 900, "Day 5 pays the 15-minute 2x Speed potion")
	assert(#grants == 5, "five claims, five grants")
	leave()

	-- The client panel shows the server's answer (World 1's saved Days31, DailyRewardController's own code).
	local place = roblox.deserializePlace(fs.readFile(PlaceFiles.World1))
	local daysFrame = place:GetService("StarterGui").DailyReward.Days31:Clone()
	local chunk = between(dailySource, "local buttons = {}", "-- Every day card shipped with LayoutOrder", "the Daily's cards")
		.. between(dailySource, "daysFrame.ZIndex = 10", "local OPEN_POS", "the Daily's shading")
		.. "\nreturn cards, refresh, function(value) state = value; stateReceivedAt = os.clock(); baseSecondsRemaining = tonumber(value.SecondsRemaining) or 0 end, claimButton, claimLabel"
	local cards, refresh, setState, claimButton, claimLabel = luau.load(chunk, {
		environment = setmetatable({
			daysFrame = daysFrame, scroll = daysFrame.ScrollingFrame, resultLabel = daysFrame.RewardResult, DailyRewards = DailyRewards,
			Instance = roblox.Instance, Color3 = roblox.Color3, UDim2 = roblox.UDim2, UDim = roblox.UDim, Vector2 = roblox.Vector2, Enum = roblox.Enum,
		}, { __index = _G }),
	})()
	setState(first)
	refresh()
	assert(claimButton.Active == true and claimLabel.Text == "Claim" and daysFrame.RewardResult.Text == "Day 1 ready: 500 Speed", "join: Day 1 ready, Claim live")
	assert(cards[1].Status.Text == "Today", "Day 1 says Today")
	setState(claimed2)
	refresh()
	assert(claimButton.Active == false and claimLabel.Text == "Claimed", "after Day 2: Claim waits")
	-- 13 h, less the real time this test took since the answer.
	local countdown = daysFrame.RewardResult.Text
	assert(string.find(countdown, "Next reward in: 13h 0m 0s", 1, true) or string.find(countdown, "Next reward in: 12h 59m", 1, true),
		"the countdown to the 08:00 UTC reset: " .. countdown)
	assert(cards[1].Status.Text == "Claimed" and cards[2].Status.Text == "Claimed" and cards[2].Shade.Visible, "Days 1-2 claimed and shaded")
	assert(cards[3].Status.Text == "" and not cards[3].Shade.Visible and (not cards[4].Locked or cards[4].Locked.Visible), "Day 3 waits (not Today yet), Day 4 on is locked")
	pass("the Daily server (real DailyLoginSystem, real reducers, fake clock): Day 1 on join, a double press pays once, 07:00 claim -> next in 12 h, 19:00 claim -> next at 08:00 UTC, Spin ticket / Wins x2 / potion paid, a rejoin keeps the days, DailyCanClaim follows; the panel shows the answer")
end

----------------------------------------------------------------------
-- 6. The topbar's Daily icon (TopbarIconsController in a TopbarPlus mock, the real MenuEvents)
----------------------------------------------------------------------
do
	local created = {}
	local IconMock = {}
	IconMock.__index = IconMock
	function IconMock.new()
		local self = setmetatable({ name = "?", totalNotices = 0, dropdownIcons = {}, _destroyed = false, selected = newSignal(), deselected = newSignal() }, IconMock)
		table.insert(created, self)
		return self
	end
	for _, method in { "setName", "setImage", "setOrder", "setTip", "setLabel", "setEnabled", "setImageYScale", "setImageRatio", "setSize", "setRight", "set" } do
		IconMock[method] = function(self, value)
			if method == "setName" then
				self.name = value
			end
			return self
		end
	end
	function IconMock:select()
		self.isSelected = true
		self.selected:Fire()
		return self
	end
	function IconMock:deselect()
		self.isSelected = false
		self.deselected:Fire()
		return self
	end
	function IconMock:notify()
		self.totalNotices += 1
		return self
	end
	function IconMock:clearNotices()
		self.totalNotices = 0
		return self
	end
	function IconMock:join(parent)
		table.insert(parent.dropdownIcons, self)
		return self
	end
	function IconMock:leave()
		return self
	end
	function IconMock:destroy()
		self._destroyed = true
	end

	local camera = { ViewportSize = roblox.Vector2.new(1920, 1080), GetPropertyChangedSignal = function()
		return newSignal()
	end }
	local workspace = attributed({ CurrentCamera = camera })
	function workspace:GetPropertyChangedSignal()
		return newSignal()
	end
	local tokens = { MenuEvents = {}, Update4Config = {}, RetentionMath = {}, FeatureGate = {}, IconController = {} }
	local modules = {
		[tokens.MenuEvents] = MenuEvents,
		[tokens.Update4Config] = U4,
		[tokens.RetentionMath] = RetentionMath,
		[tokens.FeatureGate] = { IsPreviewPlayer = function()
			return true
		end },
		[tokens.IconController] = { setGap = function() end },
	}
	local iconToken = container({ IconController = tokens.IconController })
	modules[iconToken] = IconMock
	local remotes = container({}) -- no DailyLoginUpdate yet: the server has not made it
	local shared = container({ MenuEvents = tokens.MenuEvents, Update4Config = tokens.Update4Config, RetentionMath = tokens.RetentionMath, FeatureGate = tokens.FeatureGate })
	local services = { Players = { LocalPlayer = player }, ReplicatedStorage = container({ Shared = shared, Icon = iconToken, Remotes = remotes }), Workspace = workspace }
	local env = setmetatable({
		game = { GetService = function(_, name)
			return assert(services[name], "the topbar asks for " .. tostring(name))
		end },
		require = function(token)
			return assert(modules[token], "the topbar requires something unexpected")
		end,
		Instance = { new = function()
			return bindable()
		end },
		task = Task,
		Color3 = roblox.Color3,
		warn = function(text)
			error("the topbar warned: " .. tostring(text))
		end,
	}, { __index = _G })
	Task.spawn(luau.load(read(TOPBAR), { environment = env }))
	advance(0)
	local daily = nil
	for _, icon in created do
		if icon.name == "Daily" and not icon._destroyed then
			daily = icon
		end
	end
	assert(daily, "the topbar has the Daily icon")
	has(read(TOPBAR), 'request = "Daily",\n\t\tpanel = "DailyReward",', "the Daily icon's menu and panel")

	-- The icon opens the Daily (and only the Daily), and closes it.
	daily:select()
	onlyOpen("Daily", "the Daily icon")
	daily:deselect()
	onlyOpen(nil, "the Daily icon again")

	-- The remote arrives after the controller started: the notice still follows the server.
	local update = { OnClientEvent = newSignal() }
	advance(2)
	remotes:Add("DailyLoginUpdate", update)
	update.OnClientEvent:Fire({ CanClaim = true })
	assert(daily.totalNotices == 1, "a late DailyLoginUpdate still lights the Daily icon")
	update.OnClientEvent:Fire({ CanClaim = true })
	assert(daily.totalNotices == 1, "one notice, not one per update")
	daily:select()
	assert(daily.totalNotices == 0, "opening the Daily clears the notice")
	onlyOpen("Daily", "the Daily icon with a reward waiting")
	update.OnClientEvent:Fire({ CanClaim = true })
	assert(daily.totalNotices == 1, "still claimable: the next update brings it back")
	update.OnClientEvent:Fire({ CanClaim = false })
	assert(daily.totalNotices == 0, "claimed: the notice goes")
	-- The DailyCanClaim attribute (the server's, on join and every change) drives it too.
	player:SetAttribute("DailyCanClaim", true)
	assert(daily.totalNotices == 1, "DailyCanClaim = true lights it")
	player:SetAttribute("DailyCanClaim", false)
	assert(daily.totalNotices == 0, "DailyCanClaim = false clears it")
	-- The Spin HUD button over the open Daily: the Spin Wheel, the icon follows.
	hudButton.Activated:Fire()
	onlyOpen("SpinWheel", "the Spin HUD button over the Daily (topbar)")
	closeAll()
	pass("topbar: the Daily icon opens the Daily and closes it; its notice follows the server even when DailyLoginUpdate arrives after the controller, clears on open and when claimed, and follows DailyCanClaim")
end

print(("test_u4_menu_routing: %d checks passed"):format(passed))
