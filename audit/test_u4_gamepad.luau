-- test_u4_gamepad.luau (2026-09-26, owner: console / gamepad support, first-class)
--   1. Shared/ConsolePanelSupport, the real module on fake services: Cycle wraps; Tabs binds
--      ButtonL1 / ButtonR1 only while its panel is open, above ConsoleUiScale's B and
--      SpeedsterClient's L1 sprint and under the race input, steps -1 / +1 and sinks; Back binds
--      ButtonB while a layer is open and calls it; FirstButton picks the first sensible button
--      (reading order, shown, Active, in its scroll window, never Close or a full-screen dim);
--      Select / ClearSelection never leave the selection on a hidden object; Bind takes a
--      resolver for its first button.
--   2. The Shop, on the real place's StarterGui.Shop: the tab list is the sidebar's real buttons
--      and the canvas' real headers; ShopController's own section code (run from its source)
--      gives each tab's first Buy (the Codes box on Codes), skips PURCHASED and hidden cards (the
--      2X Stamina card while it is off), finds the tab of the selection; the bumpers go round
--      all six tabs; B closes the Gift list first (Back above ConsoleUiScale), then the Shop
--      through MenuEvents.CloseAll; opening selects, closing gives the selection back.
--   3. Titles: bumpers over the designer's real tabs, the first row that can be equipped
--      selected, selection cleared on close; ConsoleUiScale selects a menu's first sensible
--      button and never keeps a hidden selection.
--   4. Races: RaceInputClient binds A / R2 (L2) to charge and R2 (L2) to sprint, nothing to X;
--      the HUD's glyphs are exactly those buttons (countdown [A] [R2], racing [R2] BOOST, run
--      from its source), LEAVE on View with a badge, the results' B is LOBBY; every race
--      window works from a gamepad.
-- Run: lune run audit/test_u4_gamepad.luau   (from the project root)
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local PlaceFiles = require("./place_files")
local ShopCard = require("./u4_shop_card")

local Vector2, UDim2, Enum = roblox.Vector2, roblox.UDim2, roblox.Enum
local ROOT = "src/common/StarterPlayer/StarterPlayerScripts/"
local SHARED = "src/common/ReplicatedStorage/Shared/"

local passed = 0
local function pass(text)
	passed += 1
	print("PASS " .. text)
end
local function has(source, needle, message)
	assert(string.find(source, needle, 1, true), message .. " (" .. needle .. ")")
end

-- The text of `local function name(` up to the first line that is exactly "end" at its indent.
local function functionBody(text, name)
	local start = string.find(text, "local function " .. name .. "%(")
	assert(start, "function " .. name .. " not found")
	local indent = string.match(string.sub(text, 1, start), "\n([\t ]*)$") or ""
	local finish = string.find(text, "\n" .. indent .. "end\n", start, true)
	assert(finish, "end of " .. name .. " not found")
	return string.sub(text, start, finish + #indent + 4)
end

----------------------------------------------------------------------
-- Fake services and a fake GUI
----------------------------------------------------------------------
local world = { binds = {}, unbinds = 0, lastInput = Enum.UserInputType.Gamepad1, tenFoot = false }
local GuiService = { SelectedObject = nil, MenuIsOpen = false }
function GuiService:IsTenFootInterface()
	return world.tenFoot
end
local UserInputService = { GamepadEnabled = true }
function UserInputService:GetLastInputType()
	return world.lastInput
end
local ContextActionService = {}
function ContextActionService:BindActionAtPriority(name, fn, _, priority, ...)
	world.binds[name] = { fn = fn, priority = priority, keys = { ... } }
end
function ContextActionService:UnbindAction(name)
	if world.binds[name] then
		world.unbinds += 1
	end
	world.binds[name] = nil
end
local services = { GuiService = GuiService, UserInputService = UserInputService, ContextActionService = ContextActionService, Workspace = {} }
local ConsolePanelSupport = luau.load(fs.readFile(SHARED .. "ConsolePanelSupport.luau"), {
	environment = setmetatable({
		game = { GetService = function(_, name) return assert(services[name], name) end },
		Enum = Enum,
		Vector2 = Vector2,
	}, { __index = _G }),
})()

local function press(name, keyCode, state)
	local bind = assert(world.binds[name], name .. " is not bound")
	return bind.fn(name, state or Enum.UserInputState.Begin, { KeyCode = keyCode })
end

local CLASSES = {
	ScreenGui = { "ScreenGui", "LayerCollector", "GuiBase2d" },
	Frame = { "Frame", "GuiObject", "GuiBase2d" },
	ScrollingFrame = { "ScrollingFrame", "GuiObject", "GuiBase2d" },
	TextButton = { "TextButton", "GuiButton", "GuiObject", "GuiBase2d" },
	ImageButton = { "ImageButton", "GuiButton", "GuiObject", "GuiBase2d" },
}
local function gui(className, name, parent, x, y, w, h, props)
	local object = { ClassName = className, Name = name, Parent = parent, Children = {}, Visible = true, Active = true, Enabled = true, Selectable = false,
		AbsolutePosition = Vector2.new(x or 0, y or 0), AbsoluteSize = Vector2.new(w or 0, h or 0) }
	object.AbsoluteWindowSize = object.AbsoluteSize
	for key, value in props or {} do
		object[key] = value
	end
	function object:IsA(class)
		return table.find(CLASSES[self.ClassName], class) ~= nil or class == "Instance"
	end
	function object:GetChildren()
		return self.Children
	end
	function object:GetDescendants()
		local out = {}
		local function walk(node)
			for _, child in node.Children do
				table.insert(out, child)
				walk(child)
			end
		end
		walk(self)
		return out
	end
	function object:IsDescendantOf(ancestor)
		local node = self.Parent
		while node do
			if node == ancestor then
				return true
			end
			node = node.Parent
		end
		return false
	end
	function object:FindFirstAncestorWhichIsA(class)
		local node = self.Parent
		while node do
			if node:IsA(class) then
				return node
			end
			node = node.Parent
		end
		return nil
	end
	if parent then
		table.insert(parent.Children, object)
	end
	return object
end

----------------------------------------------------------------------
-- 1. ConsolePanelSupport
----------------------------------------------------------------------
do
	assert(ConsolePanelSupport.Cycle(1, 6, -1) == 6 and ConsolePanelSupport.Cycle(6, 6, 1) == 1 and ConsolePanelSupport.Cycle(3, 6, 1) == 4
		and ConsolePanelSupport.Cycle(2, 4, -1) == 1, "Cycle wraps around both ends")
	local high = Enum.ContextActionPriority.High.Value
	assert(ConsolePanelSupport.Priority > high + 100 and ConsolePanelSupport.Priority < high + 200,
		"above ConsoleUiScale's B (High) and SpeedsterClient's L1 sprint (High + 100), under the race input (High + 200)")
	has(fs.readFile(ROOT .. "Movement/SpeedsterClient.client.luau"), "Enum.ContextActionPriority.High.Value + 100,\n\tEnum.KeyCode.LeftShift", "SpeedsterClient's sprint is at High + 100")
	has(fs.readFile(ROOT .. "Race/RaceInputClient.client.luau"), "local ACTION_PRIORITY = Enum.ContextActionPriority.High.Value + 200", "the race input is at High + 200")

	-- Tabs: bound only while open.
	local open, steps = false, {}
	local sync = ConsolePanelSupport.Tabs("TestTabs", function() return open end, function(step) table.insert(steps, step) end)
	sync()
	assert(world.binds.TestTabs == nil, "closed: the bumpers are not taken")
	open = true
	sync()
	local bind = assert(world.binds.TestTabs, "open: bound")
	assert(table.find(bind.keys, Enum.KeyCode.ButtonL1) and table.find(bind.keys, Enum.KeyCode.ButtonR1) and #bind.keys == 2 and bind.priority == ConsolePanelSupport.Priority, "ButtonL1 / ButtonR1 at Priority")
	assert(press("TestTabs", Enum.KeyCode.ButtonR1) == Enum.ContextActionResult.Sink and press("TestTabs", Enum.KeyCode.ButtonL1) == Enum.ContextActionResult.Sink, "a bumper press is sunk (never sprints)")
	assert(press("TestTabs", Enum.KeyCode.ButtonR1, Enum.UserInputState.End) == Enum.ContextActionResult.Pass, "a release passes")
	GuiService.MenuIsOpen = true
	assert(press("TestTabs", Enum.KeyCode.ButtonR1) == Enum.ContextActionResult.Pass, "Roblox's menu open: passes")
	GuiService.MenuIsOpen = false
	assert(#steps == 2 and steps[1] == 1 and steps[2] == -1, "R1 steps +1, L1 steps -1")
	open = false
	sync()
	assert(world.binds.TestTabs == nil, "closed again: unbound")

	-- Back: B while the layer is open.
	local layer, backs = true, 0
	local syncBack = ConsolePanelSupport.Back("TestBack", function() return layer end, function() backs += 1; layer = false end)
	syncBack()
	local back = assert(world.binds.TestBack, "B bound while the layer is open")
	assert(#back.keys == 1 and back.keys[1] == Enum.KeyCode.ButtonB and back.priority > high, "ButtonB above ConsoleUiScale's universal close (High)")
	assert(press("TestBack", Enum.KeyCode.ButtonB) == Enum.ContextActionResult.Sink and backs == 1, "B closes the layer and is sunk")
	assert(press("TestBack", Enum.KeyCode.ButtonB) == Enum.ContextActionResult.Pass and backs == 1, "the layer gone: B passes on (ConsoleUiScale closes the window)")
	syncBack()
	assert(world.binds.TestBack == nil, "unbound with the layer")

	-- FirstButton / Shown / Select / ClearSelection on a fake window.
	local screen = gui("ScreenGui", "Panel", nil, 0, 0, 1280, 720)
	local dim = gui("TextButton", "Dim", screen, 0, 0, 1280, 720)
	local window = gui("Frame", "Window", screen, 300, 100, 680, 500)
	local close = gui("ImageButton", "Close", window, 950, 80, 40, 40)
	local tabA = gui("ImageButton", "TabA", window, 320, 130, 100, 40)
	local tabB = gui("ImageButton", "TabB", window, 430, 128, 100, 40)
	local hiddenTab = gui("ImageButton", "Early", window, 300, 90, 100, 40, { Visible = false })
	local list = gui("ScrollingFrame", "List", window, 320, 200, 640, 380)
	local above = gui("ImageButton", "Buy", gui("Frame", "Scrolled", list, 320, 60, 600, 100), 700, 90, 100, 40)
	assert(ConsolePanelSupport.FirstButton(screen) == tabA, "reading order: the top row's left button; not the dim, not Close, not a hidden one")
	tabA.Active, tabB.Active = false, false
	local row1 = gui("ImageButton", "Buy", gui("Frame", "Card1", list, 320, 220, 600, 100), 700, 250, 100, 40)
	gui("ImageButton", "Gift", row1.Parent, 820, 252, 40, 40)
	assert(ConsolePanelSupport.FirstButton(screen) == row1, "inside the scroll window before one scrolled out of it (" .. tostring(ConsolePanelSupport.FirstButton(screen) and ConsolePanelSupport.FirstButton(screen).Name) .. ")")
	row1.Parent.Visible = false
	assert(ConsolePanelSupport.FirstButton(screen) == above, "nothing else in view: the scrolled-out one (the engine scrolls to it)")
	assert(not ConsolePanelSupport.Shown(row1) and ConsolePanelSupport.Shown(above), "Shown follows every ancestor")
	assert(ConsolePanelSupport.Select(row1) == false and GuiService.SelectedObject == nil, "never selects a hidden button")
	world.lastInput = Enum.UserInputType.MouseButton1
	assert(ConsolePanelSupport.Select(above) == false and GuiService.SelectedObject == nil, "no gamepad: no selection")
	world.lastInput = Enum.UserInputType.Gamepad1
	assert(ConsolePanelSupport.Select(above) == true and GuiService.SelectedObject == above and above.Selectable == true, "gamepad: selected")
	ConsolePanelSupport.ClearSelection(dim)
	assert(GuiService.SelectedObject == above, "ClearSelection leaves a selection outside the closing root")
	ConsolePanelSupport.ClearSelection(screen)
	assert(GuiService.SelectedObject == nil, "ClearSelection gives it back when inside")
	screen.Enabled = false
	assert(not ConsolePanelSupport.Shown(above) and ConsolePanelSupport.FirstButton(screen) == nil, "a disabled ScreenGui shows nothing")
	close.Active = true
	pass("ConsolePanelSupport: Cycle wraps; Tabs L1/R1 and Back B bound only while open, above ConsoleUiScale and the L1 sprint, sunk; FirstButton reading order / shown / in view / not Close or a dim; Select and ClearSelection never leave a hidden selection")
end

----------------------------------------------------------------------
-- 2. The Shop (the real StarterGui.Shop of World 1)
----------------------------------------------------------------------
local shopSource = fs.readFile(ROOT .. "UI/ShopController.client.luau")
do
	local dm = roblox.deserializePlace(fs.readFile(PlaceFiles.World1))
	ShopCard.Insert(dm, {}) -- the card as the build now makes it (hidden)
	local shopGui = dm:GetService("StarterGui").Shop
	-- Open, as ShopController leaves it (StarterGui keeps it disabled with the window hidden).
	shopGui.Enabled = true
	shopGui.Shop.Visible = true
	local scroll = shopGui.Shop.ScrollingFrame
	local sidebar = shopGui.Listbutton.Frame
	local list = scroll.Pass
	local stamina = list:FindFirstChild(ShopCard.Name)

	-- The tab list is the real one: a sidebar button and a canvas header each.
	local categories = luau.load(string.match(shopSource, "local SHOP_CATEGORIES = (%b{})") and ("return " .. string.match(shopSource, "local SHOP_CATEGORIES = (%b{})")))()
	assert(#categories == 6, "six tabs")
	for _, name in categories do
		assert(sidebar:FindFirstChild(name) and sidebar:FindFirstChild(name):IsA("GuiButton"), "the sidebar has a " .. name .. " button")
		local header = false
		for _, child in scroll:GetChildren() do
			if child:IsA("TextLabel") and string.lower(child.Text) == string.lower(name) then
				header = true
			end
		end
		assert(header, "the canvas has a " .. name .. " header")
	end

	-- ShopController's own section code, run on the real Shop.
	local a = assert(string.find(shopSource, "local function categoryTitle(", 1, true))
	local b = assert(string.find(shopSource, "-- The chosen tab's sidebar button stands out", 1, true))
	local env = setmetatable({
		ScrollFrame = scroll, PassList = list, Sidebar = sidebar, SHOP_CATEGORIES = categories,
		ConsolePanelSupport = ConsolePanelSupport, GuiService = GuiService, currentCategory = 1,
	}, { __index = _G })
	local shop = luau.load(string.sub(shopSource, a, b - 1) .. "\nreturn { sectionFirstButton = sectionFirstButton, selectedCategory = selectedCategory, categoryAt = categoryAt }", { environment = env })()
	local function buyOf(frame)
		return frame:FindFirstChild("Buy")
	end
	local expected = {
		buyOf(scroll.ExclusiveVIP), buyOf(scroll["2XServerSpeed"]), buyOf(list["2X Win"]), buyOf(scroll["Treadmill Valentine"]),
		buyOf(scroll["2XSpeedpotion10MinSmall"]), scroll.CodesFrame.TextBox,
	}
	for index, want in expected do
		local got = shop.sectionFirstButton(index)
		assert(got == want, categories[index] .. ": the first sensible button is " .. want:GetFullName() .. ", got " .. (got and got:GetFullName() or "nil"))
	end
	-- The bumpers go round: R1 six times from Exclusive comes back, L1 from Exclusive is Codes.
	local index = 1
	local seen = {}
	for _ = 1, 6 do
		index = ConsolePanelSupport.Cycle(index, #categories, 1)
		table.insert(seen, categories[index])
	end
	assert(table.concat(seen, ",") == "Server,Passes,Treadmills,Potions,Codes,Exclusive", "R1 visits every tab in order and wraps: " .. table.concat(seen, ","))
	assert(categories[ConsolePanelSupport.Cycle(1, #categories, -1)] == "Codes", "L1 from Exclusive is Codes")
	-- PURCHASED and hidden cards.
	buyOf(list["2X Win"]).Active = false
	assert(shop.sectionFirstButton(3) == buyOf(list["2X Speed"]), "a PURCHASED Buy (inactive) is passed over for the next that sells")
	for _, card in list:GetChildren() do
		if card:IsA("GuiObject") then
			card.Visible = false
		end
	end
	assert(shop.sectionFirstButton(3) == nil, "the 2X Stamina card while it is off: never selected (nor any hidden card)")
	stamina.Visible = true
	assert(shop.sectionFirstButton(3) == buyOf(stamina), "the 2X Stamina card once it shows")
	-- The tab of the selection.
	GuiService.SelectedObject = buyOf(scroll["Treadmill Admin"])
	assert(shop.selectedCategory() == 4, "a treadmill's Buy is on Treadmills")
	GuiService.SelectedObject = buyOf(stamina)
	assert(shop.selectedCategory() == 3, "a pass card (in the list) is on Passes")
	GuiService.SelectedObject = sidebar.Potions
	assert(shop.selectedCategory() == 5, "the Potions tab button")
	GuiService.SelectedObject = nil
	assert(shop.selectedCategory() == 1, "nothing selected: the last tab chosen")

	-- The wiring.
	has(shopSource, 'local syncShopTabs = ConsolePanelSupport.Tabs("ShopGamepadTabs"', "ShopController: bumpers")
	has(shopSource, "goToCategory(ConsolePanelSupport.Cycle(selectedCategory(), #SHOP_CATEGORIES, step))", "ShopController: a bumper steps from the selection's tab")
	local go = functionBody(shopSource, "goToCategory")
	local selectAt = assert(string.find(go, "ConsolePanelSupport.Select(sectionFirstButton(index))", 1, true))
	local scrollAt = assert(string.find(go, "smoothScrollToCategory(SHOP_CATEGORIES[index])", 1, true))
	assert(selectAt < scrollAt and string.find(go, "markCategory(index)", 1, true), "goToCategory: marks the tab, selects its first Buy, then scrolls to its header")
	has(shopSource, 'syncGiftBack = ConsolePanelSupport.Back("ShopGiftBack"', "ShopController: B closes the Gift list first")
	local openGift = functionBody(shopSource, "openGiftPanel")
	assert(string.find(openGift, "syncGiftBack()", 1, true) and string.find(openGift, "selectFirstGiftRow()", 1, true) and string.find(openGift, "giftReturnButton = origin", 1, true),
		"the Gift list: B bound, a row selected, the Gift button remembered")
	local closeGift = functionBody(shopSource, "closeGiftPanel")
	assert(select(2, string.gsub(closeGift, "syncGiftBack%(%)", "")) >= 2 and select(2, string.gsub(closeGift, "restoreGiftSelection%(%)", "")) >= 2,
		"closing the Gift list (both ways): B unbound, the selection back on the Gift button")
	has(shopSource, "openGiftPanel(passType, passId, card and card.Name, giftBtn)", "the Gift button passes itself")
	local open = functionBody(shopSource, "openPanel")
	assert(string.find(open, "syncShopTabs()", 1, true) and string.find(open, "if ConsolePanelSupport.GamepadActive() then", 1, true)
		and string.find(open, "ConsolePanelSupport.Select(sectionFirstButton(1))", 1, true), "opening: bumpers bound, the first tab's first Buy selected on a gamepad")
	local release = functionBody(shopSource, "releaseGamepad")
	assert(string.find(release, "syncShopTabs()", 1, true) and string.find(release, "syncGiftBack()", 1, true)
		and string.find(release, "ConsolePanelSupport.ClearSelection(ShopGui)", 1, true) and string.find(release, "markCategory(nil)", 1, true), "releaseGamepad: unbinds, unmarks, gives the selection back")
	local close = string.sub(shopSource, assert(string.find(shopSource, "closePanel = function(instant)", 1, true)), assert(string.find(shopSource, "CloseBtn.Activated:Connect", 1, true)))
	assert(select(2, string.gsub(close, "releaseGamepad%(%)", "")) == 3, "closePanel releases the gamepad on every path (instant, closing, closed)")
	-- ButtonB on the Shop itself: ConsoleUiScale's universal close, MenuEvents.CloseAll -> closePanel(true).
	has(shopSource, 'MenuEvents.CloseAll.Event:Connect(function(exceptMenuName)\n\tif exceptMenuName == "Shop" then return end\n\tclosePanel(true)', "the Shop closes on MenuEvents.CloseAll")
	pass("Shop (real place): six real tabs; each tab's first Buy (Codes box), PURCHASED and hidden cards skipped, the 2X Stamina card only when shown; bumpers wrap; B closes the Gift list then the Shop (CloseAll); open selects, close gives it back")
end

----------------------------------------------------------------------
-- 3. Titles and ConsoleUiScale
----------------------------------------------------------------------
do
	local titles = fs.readFile(ROOT .. "UI/TitlesController.client.luau")
	has(titles, 'local syncTabs = ConsolePanelSupport.Tabs("TitlesGamepadTabs"', "Titles: bumpers")
	has(titles, "switchTab(TAB_ORDER[ConsolePanelSupport.Cycle(index, #TAB_ORDER, step)])\n\tConsolePanelSupport.Select(firstRowButton())", "Titles: a bumper switches the tab and selects its first row")
	has(titles, "ConsolePanelSupport.Bind(gui, frame, firstRowButton, closeButton", "Titles: the first row that can be equipped is selected on open")
	local close = functionBody(titles, "closePanel")
	assert(select(2, string.gsub(close, "ConsolePanelSupport.ClearSelection%(gui%)", "")) == 2 and select(2, string.gsub(close, "syncTabs%(%)", "")) == 2,
		"Titles: closing unbinds the bumpers and gives the selection back")
	assert(string.find(functionBody(titles, "openPanel"), "syncTabs()", 1, true), "Titles: the bumpers are bound on open")
	local first = functionBody(titles, "firstRowButton")
	assert(string.find(first, "parts.Row.Visible", 1, true) and string.find(first, "entry.button.Active", 1, true), "Titles: never a row the tab hides; an equippable one first")
	has(titles, "MenuEvents.CloseAll.Event:Connect(function(exceptMenuName)\n\tif exceptMenuName == \"Titles\" then\n\t\treturn\n\tend\n\tclosePanel(true)", "Titles: closes on MenuEvents.CloseAll (ButtonB)")
	-- The designer's tabs are in the places.
	local Catalog = require("../src/common/ReplicatedStorage/Shared/TitleCatalog")
	for _, place in PlaceFiles.Places do
		local dm = roblox.deserializePlace(fs.readFile(place.file))
		local panel = dm:GetService("StarterGui"):FindFirstChild("Titles")
		local bar = panel and panel:FindFirstChild("Titles") and panel.Titles:FindFirstChild("Frame")
		assert(bar, place.key .. ": StarterGui.Titles.Titles.Frame (the tab bar)")
		for _, tab in Catalog.Tabs do
			assert(bar:FindFirstChild(tab) and bar[tab]:IsA("GuiButton"), place.key .. ": the Titles tab " .. tab)
		end
	end

	local console = fs.readFile(ROOT .. "UI/ConsoleUiScale.client.luau")
	has(console, "return ConsolePanelSupport.FirstButton(gui) or findCloseOrPrimaryButton(gui)", "ConsoleUiScale: a menu's first sensible button, Close only as a last resort")
	has(console, "if selectionShownIn(gui) then\n\t\t\t\t\tupdateGamepadHints()\n\t\t\t\t\treturn", "ConsoleUiScale: a controller's own selection is kept only while shown")
	has(console, "if not selectionShownIn(gui) then\n\t\t\t\tlocal button = primaryButton(gui) or target", "ConsoleUiScale: a hidden selection moves to the first sensible button")
	has(console, "and ConsolePanelSupport.Shown(selected)", "ConsoleUiScale: shown means every ancestor visible")
	local b = functionBody(console, "onButtonBInput")
	assert(string.find(b, "closeActiveMenu()", 1, true), "ConsoleUiScale: B closes the active menu")
	assert(string.find(functionBody(console, "closeActiveMenu"), "MenuEvents.CloseAll:Fire()", 1, true), "...through MenuEvents.CloseAll")
	has(console, "Enum.ContextActionPriority.High.Value,\n\t\t\tEnum.KeyCode.ButtonB", "ConsoleUiScale's B is at High (the layers' Back sits above it)")
	for _, name in { "Shop", "Titles", "RaceResults", "RacePanelGui" } do
		has(console, '["' .. name .. '"] = true', "ConsoleUiScale manages " .. name)
	end
	has(fs.readFile(SHARED .. "ConsolePanelSupport.luau"), "if type(primaryButton) == \"function\" then", "Bind resolves a function first button")
	pass("Titles: bumpers over the real tabs, first equippable row selected, cleared on close; ConsoleUiScale: first sensible button, no hidden selection, B -> MenuEvents.CloseAll")
end

----------------------------------------------------------------------
-- 4. Races
----------------------------------------------------------------------
do
	local input = fs.readFile(ROOT .. "Race/RaceInputClient.client.luau")
	local hud = fs.readFile(ROOT .. "UI/RaceHudController.client.luau")
	local bind = functionBody(input, "bindInputs")
	local bound = {}
	for key in string.gmatch(bind, "Enum%.KeyCode%.(%w+)") do
		bound[key] = true
	end
	assert(bound.ButtonA and bound.ButtonR2 and bound.ButtonL2, "RaceAction takes A, R2 and L2")
	assert(not bound.ButtonX and not bound.ButtonY and not bound.ButtonB, "no drift, quick turn or lane change exists: nothing invented on X / Y / B")
	local sprint = luau.load("return " .. assert(string.match(input, "local SPRINT_KEYS = (%b{})")))()
	local chargeOnly = luau.load("return " .. assert(string.match(input, "local CHARGE_ONLY_KEYS = (%b{})")))()
	assert(sprint.ButtonR2 and sprint.ButtonL2 and chargeOnly.ButtonA, "R2 / L2 charge and sprint; A charges (and jumps once racing)")
	has(input, "local TRIGGER_PRESS, TRIGGER_RELEASE = 0.35, 0.20", "analog triggers: pressed past 0.35, released under 0.20")
	-- The HUD shows exactly those buttons.
	local glyphs = luau.load("local Enum = ...\nreturn " .. assert(string.match(hud, "local PAD_GLYPHS = (%b{})")))(Enum)
	for _, keyCode in glyphs.Charge do
		assert(bound[keyCode.Name] and (sprint[keyCode.Name] or chargeOnly[keyCode.Name]), "countdown glyph " .. keyCode.Name .. " charges")
	end
	for _, keyCode in glyphs.Race do
		assert(sprint[keyCode.Name], "race glyph " .. keyCode.Name .. " sprints")
	end
	assert(glyphs.Charge[1] == Enum.KeyCode.ButtonA and glyphs.Charge[2] == Enum.KeyCode.ButtonR2 and #glyphs.Race == 1 and glyphs.Race[1] == Enum.KeyCode.ButtonR2, "[A] [R2] charging, [R2] racing")
	has(hud, "local PAD_LEAVE = Enum.KeyCode.ButtonSelect", "LEAVE's badge is View")
	has(functionBody(hud, "refreshLeave"), "end, false, Enum.KeyCode.ButtonSelect)", "...and View is what LEAVE is bound to")
	-- setHintGlyphs, run: the glyphs for the phase, the words after them, nothing on other inputs.
	local body = functionBody(hud, "setHintGlyphs")
	local function glyph()
		return { Image = "", Visible = false, Size = UDim2.new(), Position = UDim2.new() }
	end
	local g1, g2 = glyph(), glyph()
	local hint = { Text = { Position = UDim2.new(), Size = UDim2.new() } }
	local images = { ButtonA = "rbxasset://a.png", ButtonR2 = "rbxasset://r2.png" }
	local set = luau.load("local hintGlyphPhase = nil\n" .. body .. "\nreturn setHintGlyphs", {
		environment = setmetatable({
			PAD_GLYPHS = glyphs, hintGlyphs = { g1, g2 }, hint = hint, plan = { Hint = { GlyphSize = 30 } }, UDim2 = UDim2,
			padImage = function(keyCode) return images[keyCode.Name] or "" end,
		}, { __index = _G }),
	})()
	set("Charge")
	assert(g1.Visible and g1.Image == images.ButtonA and g2.Visible and g2.Image == images.ButtonR2 and g2.Position == UDim2.fromOffset(34, 0)
		and hint.Text.Position == UDim2.fromOffset(68, 0) and hint.Text.Size == UDim2.new(1, -68, 1, 0), "countdown: [A] [R2] then the words")
	set("Race")
	assert(g1.Visible and g1.Image == images.ButtonR2 and not g2.Visible and hint.Text.Position == UDim2.fromOffset(34, 0), "racing: [R2] then BOOST")
	set("None")
	assert(not g1.Visible and not g2.Visible and hint.Text.Position == UDim2.fromOffset(0, 0) and hint.Text.Size == UDim2.new(1, 0, 1, 0), "keyboard / touch: no glyph")
	-- When they show.
	has(hud, 'local padRacing = gamepad and goAt > 0 and t >= goAt + GAUGE_AFTER_GO and (state == "Racing" or state == "Staged")', "the race hint from when the gauge has gone until the finish")
	has(hud, "hint.Visible = (charging or padRacing) and os.clock() >= bannerUntil", "...never over the start banner")
	has(hud, 'setHintGlyphs(if not gamepad then "None" elseif padRacing then "Race" else "Charge")', "the glyphs follow the phase and the input")
	has(hud, 'if padRacing then\n\t\t\tsetText(hint.Text, text("Boost"))', "racing on a gamepad the hint says BOOST")
	-- The results window: B is LOBBY; the race panel and the results are gamepad windows.
	has(hud, 'local syncResultsBack = ConsolePanelSupport.Back("RaceResultsBack", function()\n\treturn resultsOpen and results.Enabled\nend, goLobby)', "the results' B is LOBBY, above ConsoleUiScale")
	has(hud, 'results:GetPropertyChangedSignal("Enabled"):Connect(syncResultsBack)', "...bound while the window shows")
	has(hud, "ConsolePanelSupport.Bind(results, window, raceAgain, lobbyButton, goLobby)", "RACE AGAIN selected on the results")
	local lobby = fs.readFile(ROOT .. "UI/RaceLobbyController.client.luau")
	has(lobby, "ConsolePanelSupport.Bind(panelGui, window, left.Join, window.Close", "the race panel: JOIN selected")
	has(lobby, "Enum.ContextActionPriority.Low.Value, Enum.KeyCode.DPadRight)", "the race panel opens on the D-pad")
	-- No mouse or keyboard needed: the mouse charge is one input among others (the triggers and A
	-- do the same), and the HUD's buttons are LEAVE (View) and the touch-only action button.
	has(input, 'hold("Mouse", true)', "the mouse charges too")
	has(input, "if bound and not gameProcessed and input.UserInputType == Enum.UserInputType.MouseButton1", "...but it is optional (bound and not over a GUI)")
	has(input, "-- The race has no drift, quick turn or lane change, so nothing is bound to ButtonX.", "RaceInputClient documents the mapping")
	pass("races: A / R2 (L2) charge, R2 (L2) sprint, nothing invented on X; HUD glyphs are those buttons ([A] [R2] countdown, [R2] BOOST racing, run), LEAVE on View with a badge, results' B is LOBBY, panel on the D-pad")
end

print(("test_u4_gamepad: %d checks passed"):format(passed))
