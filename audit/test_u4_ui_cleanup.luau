-- test_u4_ui_cleanup.luau (Update 4 polish, 2026-09-25)
-- The owner's UI cleanup:
--   1. the topbar (UI/TopbarIconsController run in a TopbarPlus mock): no Codes, Quests or
--      Titles icons (codes are redeemed in the Shop's Codes section, Quests open from Dr.
--      Eggman in the lobby, Titles from the side menu); every icon on the RIGHT in one group
--      (Streak, Playtime, Community, Daily, AFK, Settings, the admin crown) that ends before
--      the top centre (RetentionMath.TopbarRightLayout), folding on the narrowest phones;
--      Community goes once claimed; the Shop still redeems codes, Quests and Titles still open;
--   2. the side menu's Titles button (MainHUDController 5c run on World 1's real LeftSideBar):
--      the designer's Ability button copied, "Titles" + crown, after the other buttons, the
--      "!" badge for new titles from the tenth minute, hidden while Titles is off, opening the
--      Titles panel; the two-column grid of 9 buttons (HudErgonomics.SideBarCells, checked
--      against the designer's cells) on screen and off the centre bars on every shape;
--   3. Heat Vision (H) never meets Sprint (S): 24 px or more on 640x360 .. 2800x1300 plus the
--      owner's list, Burst shown or not, top bars 0/36/58, automatic and under 6000 saved
--      layouts (random, Swap side, H saved on S / B / the jump button / the thumbstick, S saved
--      on H); also 24 px from the Burst button, the jump button and the thumbstick; a legal
--      saved H is kept where the player put it;
--   2b. 2026-09-26 (owner: "the new Titles button covers the Rebirth icon"; a tester: the open
--      chat covers the side menu on phones): HudErgonomics.SideBarPlan on every shape, input and
--      console: every row SideBarGap above the Rebirth / Wins counters and under the RACE button
--      (RaceHudLayout.LobbyButton), the designer's place kept where it already fits, cells never
--      under SideBarMinScale; HudErgonomics.ChatWindow puts the chat in the top centre strip on
--      compact touch screens, clear of the menu and the right column; MainHUDController 5d wires both;
--   4. the reported bug, reproduced: MainHUDController took the ability buttons' base back
--      from any Position while the HUD showed, so a show slide cut short by the next menu kept
--      its half-way point and Heat Vision came back on top of Sprint. The base is now
--      HeatVisionClient's HudBasePosition attribute (or a laid-out offset place).
-- Run: lune run audit/test_u4_ui_cleanup.luau   (from the project root)
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local rb = require("@lune/roblox")

local PlaceFiles = require("./place_files")
local H = require("../src/common/ReplicatedStorage/Shared/HudErgonomics")
local RaceHudLayout = require("../src/common/ReplicatedStorage/Shared/RaceHudLayout")
local RetentionMath = require("../src/common/ReplicatedStorage/Shared/RetentionMath")
local U4 = require("../src/common/ReplicatedStorage/Shared/Update4Config")

local UI = "src/common/StarterPlayer/StarterPlayerScripts/UI/"
local TOPBAR = UI .. "TopbarIconsController.client.luau"
local HUD = UI .. "MainHUDController.client.luau"
local HEAT = "src/common/StarterPlayer/StarterPlayerScripts/Movement/HeatVisionClient.client.luau"
local EPS = 1e-6

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
local function hasNot(source, needle, message)
	assert(not string.find(source, needle, 1, true), message .. " (found: " .. needle .. ")")
end
local function between(source, first, last, message)
	local a = string.find(source, first, 1, true)
	assert(a, message .. ": start not found")
	local b = string.find(source, last, a + #first, true)
	assert(b, message .. ": end not found")
	return string.sub(source, a, b - 1)
end
-- The gap between two rects (negative: they overlap).
local function gap(a, b)
	return math.max(a.Left - b.Right, b.Left - a.Right, a.Top - b.Bottom, b.Top - a.Bottom)
end

local function newSignal()
	local signal = { handlers = {} }
	function signal:Connect(fn)
		table.insert(self.handlers, fn)
		return {
			Disconnect = function()
				local at = table.find(self.handlers, fn)
				if at then
					table.remove(self.handlers, at)
				end
			end,
		}
	end
	function signal:Fire(...)
		for _, fn in table.clone(self.handlers) do
			fn(...)
		end
	end
	function signal:Wait() end
	return signal
end

-- An object with attributes and their signals (a player, Workspace).
local function attributed(props)
	local o = props or {}
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

-- A folder whose children are found by name (WaitForChild / FindFirstChild / indexing).
local function folder(children)
	return setmetatable({
		WaitForChild = function(_, name)
			return children[name]
		end,
		FindFirstChild = function(_, name)
			return children[name]
		end,
	}, {
		__index = function(_, key)
			return children[key]
		end,
	})
end

----------------------------------------------------------------------
-- 1. The topbar
----------------------------------------------------------------------
do
	local source = read(TOPBAR)
	-- Gone for good, in the source too.
	for _, needle in {
		'request = "Codes"', "Codes = {", "CODES_IMAGE", "CodesTopbarIconImage",
		'request = "Quests"', "Quests = {", "QUESTS_IMAGE", "QuestRewardReady", "QuestAvailable",
		'request = "Titles"', "TITLES_IMAGE", "TitlesNewCount",
		"setLeft", "setMid", "TopbarLeftLayout",
	} do
		hasNot(source, needle, "The topbar no longer carries it")
	end
	has(source, "\t\t:setRight()\n", "Every icon is built right-aligned")
	has(source, "RetentionMath.TopbarRightLayout(width, items)", "One layout for the whole right group")
	has(source, 'local ORDER = { "Streak", "Playtime", "Community", "Daily", "Afk", "Settings", "AdminAbuse" }', "The group's order")

	-- Where each of them lives now.
	local shop = read(UI .. "ShopController.client.luau")
	-- 2026-09-26 (owner): the tab list is ShopController's SHOP_CATEGORIES now (the sidebar and the
	-- gamepad bumpers share it).
	has(shop, 'local SHOP_CATEGORIES = { "Exclusive", "Server", "Passes", "Treadmills", "Potions", "Codes" }', "The Shop keeps its Codes tab")
	has(shop, "for _, categoryName in ipairs(SHOP_CATEGORIES) do", "...and the sidebar wires every tab of it")
	has(shop, 'MenuEvents.Get("OpenCodesPanel")', "...and answers MenuEvents \"Codes\"")
	has(shop, "wireCodesSection()", "...and wires its redeem box")
	local menu = read("src/common/ReplicatedStorage/Shared/MenuEvents.luau")
	has(menu, 'Quests = "OpenQuestsPanel"', "MenuEvents still opens Quests (the NPC's request)")
	has(menu, 'Titles = "OpenTitlesPanel"', "MenuEvents still opens Titles (the side button's request)")
	has(read(UI .. "QuestController.client.luau"), 'MenuEvents.Get("OpenQuestsPanel").Event:Connect(', "The Quests panel still listens")
	has(read(UI .. "TitlesController.client.luau"), 'MenuEvents.Listen("Titles", function(action)', "The Titles panel still listens")
	local place = rb.deserializePlace(fs.readFile(PlaceFiles.World1))
	local shopGui = place:GetService("StarterGui"):FindFirstChild("Shop")
	local codesFrame = shopGui and shopGui:FindFirstChild("Shop") and shopGui.Shop:FindFirstChild("ScrollingFrame") and shopGui.Shop.ScrollingFrame:FindFirstChild("CodesFrame")
	assert(codesFrame and codesFrame:FindFirstChild("TextBox") and codesFrame:FindFirstChild("Reddem"), "World 1's Shop has its Codes section (box + Redeem)")

	-- Run it in a TopbarPlus mock.
	local created = {}
	local IconMock = {}
	IconMock.__index = IconMock
	function IconMock.new()
		local self = setmetatable({
			name = "?", order = 1, size = 44, label = "", enabled = true, totalNotices = 0,
			dropdownIcons = {}, _destroyed = false, selected = newSignal(), deselected = newSignal(),
		}, IconMock)
		table.insert(created, self)
		return self
	end
	for name, field in { setName = "name", setImage = "image", setOrder = "order", setTip = "tip", setLabel = "label", setEnabled = "enabled", setImageYScale = "yScale", setImageRatio = "ratio" } do
		IconMock[name] = function(self, value)
			self[field] = value
			return self
		end
	end
	function IconMock:setSize(x)
		self.size = x
		return self
	end
	function IconMock:setRight()
		self.alignment = "right"
		return self
	end
	function IconMock:setLeft()
		self.alignment = "left"
		return self
	end
	function IconMock:set()
		return self
	end
	function IconMock:select()
		self.selected:Fire()
		return self
	end
	function IconMock:deselect()
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
		self.parent = parent
		table.insert(parent.dropdownIcons, self)
		return self
	end
	function IconMock:leave()
		if self.parent then
			table.remove(self.parent.dropdownIcons, table.find(self.parent.dropdownIcons, self))
			self.parent = nil
		end
		return self
	end
	function IconMock:destroy()
		self:leave()
		self._destroyed = true
	end
	local function iconNamed(name)
		for _, icon in created do
			if icon.name == name and not icon._destroyed then
				return icon
			end
		end
		return nil
	end

	local deferred = {}
	local function flush()
		while #deferred > 0 do
			table.remove(deferred, 1)()
		end
	end
	local requests = {}
	local camera = { ViewportSize = rb.Vector2.new(1920, 1080), _signal = newSignal() }
	function camera:GetPropertyChangedSignal()
		return self._signal
	end
	local workspace = attributed({ CurrentCamera = camera })
	function workspace:GetPropertyChangedSignal()
		return newSignal()
	end
	local playerGui = folder({})
	local player = attributed({ Name = "Player" })
	function player:WaitForChild(name)
		return if name == "PlayerGui" then playerGui else nil
	end
	player:SetAttribute("StreakDays", 3)
	player:SetAttribute("PlaytimeBoostPct", 30)
	local gaps = {}
	local modules = {
		MenuEvents = { Request = function(name)
			table.insert(requests, name)
			return true
		end },
		Update4Config = U4,
		RetentionMath = RetentionMath,
		FeatureGate = { IsPreviewPlayer = function()
			return true
		end },
		IconController = { setGap = function(value, alignment)
			gaps[alignment] = value
		end },
	}
	local tokens = {}
	-- 2026-09-26: over a copy of the names (keys added to `modules` while walking it made the
	-- walk skip some now and then: an "unexpected require" in one run of the suite out of a few).
	local moduleNames = {}
	for name in modules do
		table.insert(moduleNames, name)
	end
	for _, name in moduleNames do
		tokens[name] = folder({})
		modules[tokens[name]] = modules[name]
	end
	local iconToken = folder({ IconController = tokens.IconController })
	modules[iconToken] = IconMock
	local dailyUpdate = { OnClientEvent = newSignal() }
	local shared = folder({ MenuEvents = tokens.MenuEvents, Update4Config = tokens.Update4Config, RetentionMath = tokens.RetentionMath, FeatureGate = tokens.FeatureGate })
	local replicated = folder({ Shared = shared, Icon = iconToken, Remotes = folder({ DailyLoginUpdate = dailyUpdate }) })
	local services = { Players = { LocalPlayer = player }, ReplicatedStorage = replicated, Workspace = workspace }
	local env = setmetatable({
		game = { GetService = function(_, name)
			return assert(services[name], "service " .. name)
		end },
		require = function(token)
			return assert(modules[token], "unexpected require")
		end,
		Instance = { new = function()
			local event = { Event = newSignal() }
			function event:Fire(...)
				self.Event:Fire(...)
			end
			return event
		end },
		task = {
			spawn = function(fn, ...)
				fn(...)
			end,
			defer = function(fn)
				table.insert(deferred, fn)
			end,
			delay = function() end,
		},
		Color3 = rb.Color3,
		warn = function(text)
			error("warned: " .. tostring(text))
		end,
	}, { __index = _G })
	luau.load(read(TOPBAR), { environment = env })()
	flush()

	local names = {}
	for _, icon in created do
		names[icon.name] = true
		assert(icon.alignment == "right", icon.name .. ": right-aligned")
	end
	for _, name in { "Codes", "Quests", "Titles" } do
		assert(not names[name], "No " .. name .. " icon is made")
	end
	local function check(width, height, expectFolded, label)
		camera.ViewportSize = rb.Vector2.new(width, height)
		camera._signal:Fire()
		flush()
		local shown, folded = {}, {}
		for _, key in { "Streak", "Playtime", "Community", "Daily", "Afk", "Settings", "AdminAbuse" } do
			local icon = iconNamed(key)
			if icon then
				assert(icon.enabled, label .. ": " .. key .. " enabled")
				if icon.parent then
					table.insert(folded, key)
				else
					table.insert(shown, icon)
				end
			end
		end
		table.sort(shown, function(a, b)
			return a.order < b.order
		end)
		-- Where TopbarPlus puts them: from the right edge, 48 px in, each icon + the gap.
		local more = iconNamed("TopbarMore")
		local used = RetentionMath.Topbar.RobloxRight
		for _, icon in shown do
			used += icon.size + gaps.right
		end
		if more and more.enabled then
			used += more.size + gaps.right
		end
		assert(width - used >= (1 - RetentionMath.Topbar.Share) * width - EPS, ("%s: the group starts at %.0f, past the top centre"):format(label, width - used))
		assert(table.concat(folded, ",") == expectFolded, label .. ": folded " .. table.concat(folded, ","))
		assert((#folded > 0) == (more ~= nil and more.enabled), label .. ": the more icon only while something is folded")
		for index = 2, #shown do
			assert(shown[index - 1].order < shown[index].order, label .. ": in order")
		end
		return shown
	end
	local wide = check(1920, 1080, "", "1920x1080")
	assert(wide[1].name == "Streak" and wide[2].name == "Playtime" and wide[#wide].name == "Settings", "Desktop: Streak ... Settings, left to right")
	assert(wide[1].label == "3" and wide[2].label == "+30%" and wide[1].size == 44, "Desktop: the counters' labels on 44 px icons")
	check(844, 390, "", "844x390")
	local phone = check(667, 375, "Community,Afk", "667x375")
	assert(phone[1].size == 40 and phone[1].label == "", "Phones: 40 px, no labels")
	-- The admin crown joins the group (and folds first after AFK on a phone).
	player:SetAttribute("AdminAbusePanelAllowed", true)
	flush()
	assert(iconNamed("AdminAbuse") and iconNamed("AdminAbuse").alignment == "right", "The crown is on the right too")
	check(667, 375, "Community,Afk,AdminAbuse", "667x375 admin")
	check(1920, 1080, "", "1920x1080 admin")
	-- Community goes once claimed; the tutorial hides the retention icons only.
	player:SetAttribute("CommunityRewardClaimed", true)
	flush()
	assert(iconNamed("Community") == nil, "Community goes once claimed")
	check(640, 360, "Afk,AdminAbuse", "640x360 claimed")
	player:SetAttribute("FirstTimeTutorialActive", true)
	flush()
	assert(not iconNamed("Streak").enabled and not iconNamed("Playtime").enabled and iconNamed("Daily").enabled and iconNamed("Settings").enabled, "Tutorial: retention icons hidden, the rest kept")
	player:SetAttribute("FirstTimeTutorialActive", false)
	flush()
	-- Clicking opens through MenuEvents.
	iconNamed("Streak"):select()
	iconNamed("Settings"):select()
	assert(requests[1] == "Streak" and requests[2] == "Settings", "Icons open their panels through MenuEvents")

	-- The pure layout on the owner's screens: all reachable, Streak / Playtime / Settings always
	-- on the bar, the group ending before 55 % of the width.
	local items = {
		{ key = "Streak", label = "21" }, { key = "Playtime", label = "+100%" }, { key = "Community", fold = 1 },
		{ key = "Daily", fold = 4 }, { key = "Afk", fold = 2 }, { key = "Settings" }, { key = "AdminAbuse", fold = 3 },
	}
	for _, s in { { 640, 360 }, { 667, 375 }, { 812, 375 }, { 844, 390 }, { 1024, 768 }, { 1280, 720 }, { 1920, 1080 }, { 2388, 1668 }, { 2800, 1300 } } do
		for _, count in { 6, 7 } do
			local list = table.move(items, 1, count, 1, {})
			local layout = RetentionMath.TopbarRightLayout(s[1], list)
			assert(layout.StartX >= 0.55 * s[1] - EPS, ("%dx%d: starts at %.0f"):format(s[1], s[2], layout.StartX))
			assert(#layout.Shown + #layout.Folded == count, "Every icon is reachable")
			for _, key in { "Streak", "Playtime", "Settings" } do
				assert(table.find(layout.Shown, key), key .. " is always on the bar")
			end
			assert(#layout.Folded ~= 1, "Never a dropdown of one")
		end
	end
	pass("topbar: no Codes / Quests / Titles icons (the Shop, Dr. Eggman and the side menu open them), every icon on the right in one group that ends before the top centre on 9 screens, folding on phones; the crown joins it; Community goes once claimed")
end

----------------------------------------------------------------------
-- 2. The side menu's Titles button
----------------------------------------------------------------------
do
	local hud = read(HUD)
	has(hud, '\tTitles = "Titles",\n}', "buttonEventMap sends the Titles button to MenuEvents \"Titles\"")
	has(hud, "local eventName = buttonEventMap[child.Name]\n\t\tif eventName and MenuEvents.Request(eventName) then", "...which setupSidebarButton requests on a tap")
	has(hud, "leftBar.ChildAdded:Connect(setupSidebarButton)", "...for a button added at runtime too")
	local chunk = between(hud, "-- 5c) Titles (Update 4, 2026-09-25): off the topbar, into the side menu", "-- 6) Right buttons", "MainHUDController 5c")

	for _, world in { "World1", "World2", "World3" } do
		local place = rb.deserializePlace(fs.readFile(PlaceFiles[world]))
		local mainhud = place:GetService("StarterGui").Mainhud
		local leftBar = mainhud.LeftSideBar
		-- Heat Vision and Sprint share one ScreenGui: one inset (notch, top bar), one pixel space,
		-- the space HudErgonomics.TouchControls plans both in (section 3).
		local heatButton, sprintButton = mainhud:FindFirstChild("HeatVisionButton"), mainhud:FindFirstChild("MobileSprint")
		assert(heatButton and sprintButton and heatButton.Parent == sprintButton.Parent, world .. ": Heat Vision and Sprint both in Mainhud")
		assert(heatButton.AnchorPoint == rb.Vector2.new(0.5, 0.5), world .. ": Heat Vision placed by its centre, as its plan is")
		local designer = {}
		for _, child in leftBar:GetChildren() do
			if child:IsA("ImageButton") then
				table.insert(designer, child)
			end
		end
		local player = attributed({})
		local workspace = attributed({})
		local killed = {}
		local u4 = setmetatable({ IsOn = function(feature)
			return not killed[feature]
		end }, { __index = U4 })
		local badges, delays = {}, {}
		local clock = 0
		local sharedToken = folder({})
		local shared = folder({ Update4Config = sharedToken })
		luau.load(chunk, {
			environment = setmetatable({
				leftBar = leftBar,
				Shared = shared,
				require = function(token)
					assert(token == sharedToken, "unexpected require")
					return u4
				end,
				player = player,
				Workspace = workspace,
				setBadgeState = function(button, active)
					badges[button] = active
				end,
				os = { clock = function()
					return clock
				end },
				task = { delay = function(seconds, fn)
					table.insert(delays, { seconds, fn })
				end },
				Color3 = rb.Color3,
				ColorSequence = rb.ColorSequence,
				ColorSequenceKeypoint = rb.ColorSequenceKeypoint,
			}, { __index = _G }),
		})()
		local button = leftBar:FindFirstChild("Titles")
		local ability = leftBar:FindFirstChild("Ability")
		assert(button and button:IsA("ImageButton"), world .. ": a Titles button in the side menu")
		local last = 0
		for _, other in designer do
			last = math.max(last, other.LayoutOrder)
		end
		assert(button.LayoutOrder > last, world .. ": sorted after the designer's buttons")
		assert(button.Size == ability.Size and button:FindFirstChildOfClass("UICorner") and button:FindFirstChildOfClass("UIAspectRatioConstraint"), world .. ": the designer's cell, corners and shape")
		local strokes = 0
		for _, child in button:GetChildren() do
			if child:IsA("UIStroke") then
				strokes += 1
			end
		end
		assert(strokes == 2, world .. ": both of the designer's outlines")
		-- (FindFirstChild: `button.Name` is the button's own name.)
		local label = button:FindFirstChild("Name")
		assert(label and label.Text == "Titles" and label:FindFirstChildOfClass("UIStroke"), world .. ": labelled Titles in the designer's lettering")
		assert(button:FindFirstChild("Icon").Image == "rbxassetid://113221127098716", world .. ": the crown")
		local badge = button:FindFirstChild("!")
		assert(badge and badge.Visible == false, world .. ": the designer's \"!\" badge, hidden at first")
		assert(button.BackgroundColor3 ~= ability.BackgroundColor3, world .. ": its own colour")
		-- The badge: new titles, from the tenth minute of the session; hidden while Titles is off.
		assert(badges[button] == false and button.Visible, world .. ": no badge without new titles")
		player:SetAttribute("TitlesNewCount", 2)
		assert(badges[button] == false, world .. ": no badge before the tenth minute")
		clock = U4.Titles.NoticeAfterSessionSeconds + 1
		assert(#delays == 1 and delays[1][1] > U4.Titles.NoticeAfterSessionSeconds, world .. ": a check when the ten minutes are up")
		delays[1][2]()
		assert(badges[button] == true, world .. ": the badge while new titles wait")
		player:SetAttribute("TitlesNewCount", 0)
		assert(badges[button] == false, world .. ": gone once seen")
		killed.Titles = true
		workspace:SetAttribute(U4.KillAttributePrefix .. "Titles", true)
		assert(button.Visible == false, world .. ": hidden while Titles is switched off")
		killed.Titles = nil
		workspace:SetAttribute(U4.KillAttributePrefix .. "Titles", nil)
		assert(button.Visible == true, world .. ": back when it is on")
		-- Running it again (a respawned HUD) keeps one button.
		luau.load(chunk, { environment = setmetatable({ leftBar = leftBar, Shared = shared, require = function()
			return u4
		end, player = player, Workspace = workspace, setBadgeState = function() end, os = os, task = { delay = function() end } }, { __index = _G }) })()
		local count = 0
		for _, child in leftBar:GetChildren() do
			if child.Name == "Titles" then
				count += 1
			end
		end
		assert(count == 1, world .. ": one Titles button")
		assert(#designer == 8, world .. ": the designer's 8 side buttons (" .. #designer .. ")")
	end

	-- The grid model matches the designer's cells (1920 x 1080 under a 58 px top bar).
	local cells = H.SideBarCells(1920, 1022, 8)
	local frame = cells.Frame
	local function share(r)
		return ((r.Left + r.Right) / 2 - frame.Left) / (frame.Right - frame.Left), ((r.Top + r.Bottom) / 2 - frame.Top) / (frame.Bottom - frame.Top)
	end
	local x1, y1 = share(cells.Cells[1])
	local x2 = share(cells.Cells[2])
	local _, y4 = share(cells.Cells[8])
	assert(math.abs(x1 - 0.23711832) < 1e-4 and math.abs(y1 - 0.175) < 1e-4 and math.abs(x2 - 0.76135504) < 1e-4 and math.abs(y4 - 1.315) < 1e-3,
		("SideBarCells matches the designer's grid (%.4f, %.4f, %.4f, %.4f)"):format(x1, y1, x2, y4))
	-- Nine buttons: two columns, five rows, on screen, clear of each other and of the level and
	-- stamina bars, Sprint and the jump button, on every shape.
	local screens = 0
	for _, topBar in { 0, 36, 58 } do
		for width = 640, 2800, 80 do
			for height = 360, 1700, 40 do
				if width >= height then
					screens += 1
					for _, safe in { false, true } do
						local hudHeight = height - topBar
						local grid = H.SideBarCells(width, hudHeight, 9, safe)
						local where = ("%dx%d top %d%s"):format(width, height, topBar, if safe then " (console)" else "")
						assert(grid.Columns == 2, where .. ": two columns")
						local lastCell = grid.Cells[9]
						assert(lastCell.Top >= grid.Cells[7].Bottom and lastCell.Left == grid.Cells[1].Left, where .. ": the ninth starts a fifth row, on the left")
						assert(lastCell.Bottom <= hudHeight * (if safe then 0.95 else 1) - 4, ("%s: the fifth row ends on screen (%.0f of %d)"):format(where, lastCell.Bottom, hudHeight))
						for index, cell in grid.Cells do
							assert(cell.Left >= 0 and cell.Top >= 0, where .. ": on screen")
							for other = index + 1, #grid.Cells do
								assert(not H.Overlaps(cell, grid.Cells[other]), where .. ": cells apart")
							end
							for _, bar in H.CentreBarRects(width, hudHeight) do
								assert(not H.Overlaps(cell, bar, 4), where .. ": clear of the level and stamina bars")
							end
							assert(not H.Overlaps(cell, H.SprintButton(width, hudHeight), 8) and not H.Overlaps(cell, H.JumpButton(width, hudHeight), 8), where .. ": clear of Sprint and the jump button")
						end
					end
				end
			end
		end
	end
	pass(("side menu: a Titles button made from the designer's Ability button in all 3 places (crown, label, outlines, \"!\" for new titles from minute 10, hidden when off), opening Titles; 9 buttons in two columns on screen and clear of the HUD on %d screens and consoles"):format(screens))
end

----------------------------------------------------------------------
-- 2b. 2026-09-26: the side menu above the Rebirth counter, under the RACE button; the chat
----------------------------------------------------------------------
do
	-- The counters' model matches the places (Rebirth icon: centre 2.436, 0.2915 of the frame tall).
	for _, world in { "World1", "World2", "World3" } do
		local place = rb.deserializePlace(fs.readFile(PlaceFiles[world]))
		local counters = place:GetService("StarterGui").Mainhud:FindFirstChild("Rebith/trof")
		local spec = H.Counters
		assert(math.abs(counters.Position.X.Scale - spec.X) < 1e-6 and math.abs(counters.Position.Y.Scale - spec.Y) < 1e-6
			and math.abs(counters.Size.X.Scale - spec.Width) < 1e-6 and math.abs(counters.Size.Y.Scale - spec.Height) < 1e-6, world .. ": HudErgonomics.Counters is the designer's frame")
		local highest = math.huge
		for _, child in counters:GetChildren() do
			if child:IsA("GuiObject") then
				local h = child.Size.Y.Scale
				local shape = child:FindFirstChildOfClass("UIAspectRatioConstraint")
				if shape then
					-- FitWithinMaxSize in a frame 0.726 wide per 1 tall.
					local w = child.Size.X.Scale * spec.Aspect
					h = math.min(h, w / shape.AspectRatio)
				end
				highest = math.min(highest, child.Position.Y.Scale - child.AnchorPoint.Y * h)
			end
		end
		assert(math.abs(highest - spec.Top) < 1e-4, ("%s: the counters' highest piece at %.5f of the frame (model %.5f)"):format(world, highest, spec.Top))
	end
	-- The bug: the designer's ninth cell on the Rebirth counter, on a phone and on a desktop.
	for _, case in { { 844, 390 - 58 }, { 1920, 1080 - 58 } } do
		local cells = H.SideBarCells(case[1], case[2], 9)
		assert(cells.Cells[9].Bottom > H.CountersTop(case[1], case[2]), "(the designer's fifth row reaches into the counters)")
	end
	local screens, moved, shrunk, smallest = 0, 0, 0, math.huge
	for _, topBar in { 0, 36, 58 } do
		for width = 640, 2800, 80 do
			for height = 360, 1700, 40 do
				if width >= height then
					local hudHeight = height - topBar
					for _, kind in { "Touch", "Keyboard", "Gamepad" } do
						local safe = kind == "Gamepad"
						local race = RaceHudLayout.LobbyButton(width, hudHeight, kind, nil, topBar)
						for _, count in { 8, 9 } do
							screens += 1
							local where = ("%dx%d top %d %s, %d buttons"):format(width, height, topBar, kind, count)
							local designer = H.SideBarCells(width, hudHeight, count, safe)
							local plan = H.SideBarPlan(width, hudHeight, count, safe, race.Bottom + H.SideBarGap)
							local counters = H.CountersTop(width, hudHeight, safe)
							assert(plan.Columns == 2 and #plan.Cells == count, where .. ": two columns")
							assert(plan.Scale >= H.SideBarMinScale and plan.Scale <= 1, where .. ": cells at least SideBarMinScale of the designer's")
							assert(math.abs(plan.Frame.Left - designer.Frame.Left) < 1e-6, where .. ": its left edge kept")
							local last = plan.Cells[count]
							assert(last.Bottom <= counters - H.SideBarGap + 1e-6, ("%s: the last row ends %.1f px above the Rebirth counter"):format(where, counters - last.Bottom))
							assert(plan.Cells[1].Top >= race.Bottom + H.SideBarGap - 1e-6, ("%s: the first row under the RACE button (%.1f, button ends %.1f)"):format(where, plan.Cells[1].Top, race.Bottom))
							if designer.Cells[count].Bottom <= counters - H.SideBarGap and designer.Cells[1].Top >= race.Bottom + H.SideBarGap then
								assert(not plan.Moved, where .. ": the designer's place kept when it fits")
							else
								moved += 1
							end
							if plan.Scale < 1 then
								shrunk += 1
							end
							smallest = math.min(smallest, plan.Cell)
							for index, cell in plan.Cells do
								assert(cell.Left >= 0 and cell.Top >= 0 and cell.Bottom <= hudHeight, where .. ": on screen")
								for other = index + 1, #plan.Cells do
									assert(not H.Overlaps(cell, plan.Cells[other]), where .. ": cells apart")
								end
								for _, bar in H.CentreBarRects(width, hudHeight) do
									assert(not H.Overlaps(cell, bar, 4), where .. ": clear of the level and stamina bars")
								end
								assert(not H.Overlaps(cell, H.SprintButton(width, hudHeight), 8) and not H.Overlaps(cell, H.JumpButton(width, hudHeight), 8), where .. ": clear of Sprint and the jump button")
								assert(not H.Overlaps(cell, race, H.SideBarGap - 1e-6), where .. ": clear of the RACE button")
							end
							if safe then
								assert(plan.Cells[1].Top >= hudHeight * H.SafeInset - 1e-6, where .. ": inside the console's safe zone")
							end
						end
					end
				end
			end
		end
	end
	assert(moved > 0, "(the plan does move the menu)")
	-- The chat window: the top centre on compact touch screens, clear of the menu (wherever
	-- SideBarPlan puts it: its right edge stays) and of the right column; the place's own elsewhere.
	local phones = 0
	for _, topBar in { 36, 58 } do
		for _, phone in { { 640, 360 }, { 667, 375 }, { 740, 360 }, { 812, 375 }, { 844, 390 }, { 896, 414 }, { 926, 428 }, { 1024, 768 }, { 2400, 1080 } } do
			local width, height = phone[1], phone[2]
			local designerMenu = H.SideBarCells(width, height - topBar, 9)
			local race = RaceHudLayout.LobbyButton(width, height - topBar, "Touch", designerMenu.Frame.Left, topBar)
			local chat = H.ChatWindow(width, height, true, false, topBar, { race })
			local where = ("chat on %dx%d top %d"):format(width, height, topBar)
			assert(chat and chat.Horizontal == "Center" and chat.Vertical == "Top", where .. ": the top centre")
			local left, right = (width - chat.MaxWidth) / 2, (width + chat.MaxWidth) / 2
			local menu = H.SideBarPlan(width, height - topBar, 9, false, race.Bottom + H.SideBarGap)
			local column = H.PhoneColumn(width, height, true, false, 2, topBar)
			assert(left >= menu.Frame.Right + H.ChatGap - 1e-6, where .. ": clear of the side menu")
			assert(left >= race.Right + H.ChatGap - 1e-6, where .. ": clear of the RACE button")
			assert(right <= math.min(column.Pack.Left, column.Badges[1].Left, column.Speedometer.Rect.Left) - H.ChatGap + 1e-6, where .. ": clear of the Starter Pack, the badges and the speedometer")
			assert(chat.MaxWidth >= 0.4 * width, ("%s: still %.0f px wide at most (%.0f%% of the screen)"):format(where, chat.MaxWidth, 100 * chat.MaxWidth / width))
			assert(math.abs(chat.MaxHeight - H.ChatMaxHeightShare * (height - topBar)) < 1e-6, where .. ": at most ChatMaxHeightShare of the HUD tall")
			phones += 1
		end
	end
	for _, desk in { { 1920, 1080, false, true }, { 1366, 768, false, true }, { 1920, 1080, true, true }, { 2560, 1440, true, true } } do
		assert(H.ChatWindow(desk[1], desk[2], desk[3], desk[4], 58) == nil, "desktops (and touch screens with a keyboard) keep the place's chat")
	end
	local hud = read(HUD)
	local chunk = between(hud, "-- 5d) The side menu's place, and the chat window on phones (2026-09-26, owner and a tester)", "-- WalkSpeedSelectorHUD", "MainHUDController 5d")
	for _, needle in {
		"local plan = HudErgonomics.SideBarPlan(size.X, size.Y, math.max(count, 1), IS_CONSOLE, topRoom)",
		"pcall(raceLayout.LobbyButton, size.X, size.Y, inputKind(), nil, topBar)",
		"leftBarBasePos = UDim2.fromScale(plan.X, plan.Y)",
		"if hudVisible and leftBar.Position ~= leftBarBasePos then",
		"child:GetPropertyChangedSignal(\"Visible\"):Connect(layoutSideBar)",
		"mainhud:GetPropertyChangedSignal(\"AbsoluteSize\"):Connect(layoutSideBar)",
		"HudErgonomics.ChatWindow(view.X, view.Y, UserInputService.TouchEnabled, UserInputService.KeyboardEnabled, topBar, avoid)",
		"pcall(raceLayout.LobbyButton, view.X, view.Y - topBar, inputKind(), leftBar.AbsolutePosition.X - mainhud.AbsolutePosition.X, topBar)",
		"chatWindow.HorizontalAlignment = Enum.HorizontalAlignment.Center",
		"chatWindow.HorizontalAlignment = authored.Horizontal",
	} do
		has(chunk, needle, "MainHUDController 5d")
	end
	luau.compile(hud)
	-- The show slide takes the menu back to the plan's place (the base the 5d block writes).
	has(hud, "local target = visible and leftBarBasePos or UDim2.new(leftBarBasePos.X.Scale, leftBarBasePos.X.Offset, 1.35, 0)", "the show slide uses leftBarBasePos")
	assert(string.find(hud, "-- 5d) The side menu's place", 1, true) > string.find(hud, "local hudVisible = true", 1, true), "5d runs after hudVisible and the bases exist")
	pass(("side menu above the Rebirth counter and under the RACE button on %d screen/input/count cases (moved on %d, shrunk on %d, smallest cell %.1f px); the phone chat in the top centre strip on %d phones, the place's chat on desktops"):format(screens, moved, shrunk, smallest, phones))
end

----------------------------------------------------------------------
-- 3. Heat Vision vs Sprint (and the Burst button, the jump button, the thumbstick)
----------------------------------------------------------------------
do
	local CLEAR = H.HeatClearance
	assert(CLEAR >= 24, "A thumb's width: 24 px or more")
	local checked, worst = 0, { S = math.huge, B = math.huge, J = math.huge, T = math.huge }
	local function verify(width, height, topBar, text, burst, label)
		local hudHeight = height - topBar
		local neighbours = H.TouchNeighbours(width, height, false, topBar)
		local plan = H.TouchControls(width, hudHeight, text, neighbours, burst)
		checked += 1
		local where = ("%s %dx%d top %d burst %s %s"):format(label, width, height, topBar, tostring(burst), text or "")
		local gaps = {
			S = gap(plan.H, plan.S),
			J = gap(plan.H, H.JumpButton(width, hudHeight)),
			T = gap(plan.H, H.Thumbstick(width, hudHeight)),
			B = if burst then gap(plan.H, plan.B) else math.huge,
		}
		for key, value in gaps do
			worst[key] = math.min(worst[key], value)
			assert(value >= CLEAR - EPS, ("%s: Heat Vision %.1f px from %s"):format(where, value, key))
		end
		assert(plan.H.Left >= 0 and plan.H.Top >= 0 and plan.H.Right <= width and plan.H.Bottom <= hudHeight, where .. ": Heat Vision on screen")
		return plan
	end
	-- The owner's list and a sweep of every landscape shape from 640x360 to 2800x1300 and up.
	local LIST = { { 640, 360 }, { 812, 375 }, { 844, 390 }, { 667, 375 }, { 1024, 768 }, { 2388, 1668 }, { 2800, 1300 } }
	for _, topBar in { 0, 36, 58 } do
		for _, s in LIST do
			for _, burst in { false, true } do
				verify(s[1], s[2], topBar, nil, burst, "list")
			end
		end
		for width = 640, 2800, 20 do
			for height = 360, 1700, 20 do
				if width >= height then
					for _, burst in { false, true } do
						verify(width, height, topBar, nil, burst, "sweep")
					end
				end
			end
		end
	end
	local automatic = checked

	-- Saved layouts: random, Swap side, and the hostile ones.
	math.randomseed(20260925)
	local kept, tried = 0, 0
	local screens = table.clone(LIST)
	for _, s in { { 740, 360 }, { 896, 414 }, { 932, 430 }, { 1180, 820 }, { 1366, 1024 }, { 1280, 720 }, { 2000, 900 } } do
		table.insert(screens, s)
	end
	for _, s in screens do
		for _, topBar in { 36, 58 } do
			local width, hudHeight = s[1], s[2] - topBar
			local auto = H.TouchControls(width, hudHeight, "", H.TouchNeighbours(s[1], s[2], false, topBar), true)
			local jump = H.JumpButton(width, hudHeight)
			local stick = H.Thumbstick(width, hudHeight)
			local function share(x, y)
				return { X = math.clamp(x / width, 0, 1), Y = math.clamp(y / hudHeight, 0, 1) }
			end
			local hostile = {
				{ H = share(auto.S.X, auto.S.Y) }, -- Heat Vision saved right on Sprint
				{ H = share(auto.S.X + auto.S.Size, auto.S.Y) }, -- ...just beside it
				{ H = share(auto.B.X, auto.B.Y) }, -- ...on the Burst button
				{ H = share((jump.Left + jump.Right) / 2, (jump.Top + jump.Bottom) / 2) }, -- ...on the jump button
				{ H = share(stick.Right - 10, stick.Top + 10) }, -- ...in the thumbstick
				{ S = share(auto.H.X, auto.H.Y) }, -- Sprint saved where Heat Vision was
				{ S = share(auto.H.X, auto.H.Y), H = share(auto.S.X, auto.S.Y) }, -- the two swapped
				{ S = share(0.5 * width, 0.3 * hudHeight), H = share(0.5 * width + 30, 0.3 * hudHeight) }, -- side by side
				{ B = share(auto.H.X, auto.H.Y) }, -- the Burst button saved where Heat Vision was
			}
			for _, wish in hostile do
				for _, burst in { false, true } do
					verify(s[1], s[2], topBar, H.FormatTouchLayout(wish), burst, "hostile")
				end
			end
			-- Swap side keeps Heat Vision where the preset puts it.
			local preset = H.LeftPreset(width, hudHeight)
			local text = H.FormatTouchLayout(preset)
			for _, burst in { false, true } do
				local plan = verify(s[1], s[2], topBar, text, burst, "swap side")
				local at = H.ParseTouchLayout(text).H
				assert(math.abs(plan.H.X - at.X * width) < 0.5 and math.abs(plan.H.Y - at.Y * hudHeight) < 0.5, "Swap side: Heat Vision stays in the left row")
			end
			for trial = 1, 200 do
				local wish = {}
				for _, key in H.TouchPieces do
					if math.random() < 0.6 then
						wish[key] = { X = math.random(), Y = math.random() }
					end
				end
				local burst = trial % 3 ~= 0
				local textWish = H.FormatTouchLayout(wish)
				local plan = verify(s[1], s[2], topBar, textWish, burst, "random")
				-- A saved Heat Vision that is legal and a thumb's width from the others is kept.
				if wish.H then
					local parsed = H.ParseTouchLayout(textWish).H
					local r = H.PlaceCustom(width, hudHeight, plan.H.Size, plan.H.Size, parsed.X, parsed.Y, true, CLEAR)
					if r and gap(r, plan.S) >= CLEAR + 1 and (not burst or gap(r, plan.B) >= CLEAR + 1) and gap(r, plan.T or H.CentreBarRects(width, hudHeight)[2]) >= 5 then
						tried += 1
						if math.abs(plan.H.X - r.X) < EPS and math.abs(plan.H.Y - r.Y) < EPS then
							kept += 1
						end
					end
				end
			end
		end
	end
	assert(tried > 200 and kept == tried, ("A legal saved Heat Vision is where the player put it (%d of %d)"):format(kept, tried))

	-- The editor refuses a Heat Vision drop within a thumb's width of another button (either
	-- one moving), keeping 2 px for the saved string's rounding, and keeps H's 24 px off the
	-- thumbstick (TouchLayoutEditor.drop).
	local editor = read(UI .. "TouchLayoutEditor.client.luau")
	has(editor, "local HEAT_GAP = HudErgonomics.HeatClearance + 2", "The editor's Heat Vision gap")
	has(editor, 'local heat = (key == "H" or piece.Key == "H") and key ~= "T" and piece.Key ~= "T"', "...for either handle moving")
	has(editor, "other.Gap = if heat then HEAT_GAP else HANDLE_GAP", "...used on the drop")
	has(editor, 'local stickMargin = if key == "H" then HudErgonomics.HeatClearance else nil', "...and off the thumbstick")
	pass(("Heat Vision: >= %d px from Sprint, the Burst button, the jump button and the thumbstick on %d automatic layouts (640x360 .. 2800x1700, the owner's 7 screens, top bars 0/36/58, Burst shown or not) and %d saved ones (random, Swap side, hostile); closest %.0f / %.0f / %.0f / %.0f px; %d legal saved places kept"):format(
		CLEAR, automatic, checked - automatic, worst.S, worst.B, worst.J, worst.T, kept))
end

----------------------------------------------------------------------
-- 4. The reported bug: the show slide's base
----------------------------------------------------------------------
do
	local hud = read(HUD)
	local chunk = between(hud, "local function trackAbilityButton(btn)", "\nif sonicBurstButton then\n", "trackAbilityButton")
	chunk ..= "\nreturn trackAbilityButton, function() return heatVisionBasePos, sonicBurstBasePos end, function(v) hudVisible = v end"
	-- A button: Position and attributes with their signals.
	local function button(name, position)
		local o = attributed({ Name = name })
		local props, signals = { Position = position }, {}
		function o:IsA(class)
			return class == "GuiObject"
		end
		function o:GetPropertyChangedSignal(prop)
			signals[prop] = signals[prop] or newSignal()
			return signals[prop]
		end
		return setmetatable(o, {
			__index = function(_, key)
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
	local authored = rb.UDim2.new(0.6211312, 0, 0.62676924, 0)
	local heat = button("HeatVisionButton", authored)
	local burst = button("SonicBurstButton", authored)
	local track, bases, setVisible = luau.load(chunk, {
		environment = setmetatable({
			hudVisible = true,
			heatVisionBasePos = authored,
			sonicBurstBasePos = authored,
			UDim2 = rb.UDim2,
			typeof = function(value)
				return if type(value) == "userdata" then typeof(value) else type(value)
			end,
		}, { __index = _G }),
	})()
	track(heat)
	track(burst)

	-- A 1024 x 768 tablet under a 58 px top bar, no Burst button: Heat Vision sits right above
	-- Sprint, in its column (on phones the speedometer's boost cards push it beside Sprint).
	local width, hudHeight = 1024, 710
	local plan = H.TouchControls(width, hudHeight, "", H.TouchNeighbours(1024, 768, false, 58), false)
	assert(plan.H.Left < plan.S.Right and plan.S.Left < plan.H.Right and plan.H.Bottom < plan.S.Top, "(the tablet: Heat Vision above Sprint)")
	local laidOut = rb.UDim2.fromOffset(math.floor(plan.H.X + 0.5), math.floor(plan.H.Y + 0.5))
	heat:SetAttribute("HudBasePosition", laidOut) -- HeatVisionClient.layoutButton
	heat.Position = laidOut
	assert(bases() == laidOut, "The base is HeatVisionClient's place")

	-- The show slide's frames, as TweenService writes them (Back easing, from 1.35 below).
	local function slideFrame(target, alpha)
		local c1, c3 = 1.70158, 2.70158
		local f = 1 + c3 * (alpha - 1) ^ 3 + c1 * (alpha - 1) ^ 2
		return rb.UDim2.new(target.X.Scale, target.X.Offset, 1.35 + (target.Y.Scale - 1.35) * f, target.Y.Offset * f)
	end
	local function centreOf(position)
		return position.X.Scale * width + position.X.Offset, position.Y.Scale * hudHeight + position.Y.Offset
	end
	local function onSprint(position)
		local x, y = centreOf(position)
		local half = plan.H.Size / 2
		return H.Overlaps({ Left = x - half, Right = x + half, Top = y - half, Bottom = y + half }, plan.S)
	end
	-- The owner's report, reproduced with the old rule (any Position while shown, Y scale < 1):
	-- a menu closes (the HUD slides in), the next one opens before the 0.32 s slide ends (the
	-- slide is cut: Update Logs -> Daily at join, quick switches), and the next show slides
	-- Heat Vision to where the cut slide stood. Some of those frames lie on Sprint.
	local cutStep = nil
	for step = 1, 31 do
		local frame = slideFrame(laidOut, step / 32)
		if frame.Y.Scale < 1 and onSprint(frame) then
			cutStep = step
			break
		end
	end
	assert(cutStep, "(the bug: a cut slide's frame, which the old rule kept as the base, lies on Sprint)")
	-- Now: the same sequence keeps the laid-out place.
	setVisible(true)
	for step = 1, cutStep do
		heat.Position = slideFrame(laidOut, step / 32)
	end
	setVisible(false)
	heat.Position = rb.UDim2.new(laidOut.X.Scale, laidOut.X.Offset, 1.35, 0)
	assert(bases() == laidOut, "A cut slide never becomes the base")
	setVisible(true)
	for step = 1, 32 do
		heat.Position = slideFrame(laidOut, step / 32)
	end
	assert(bases() == laidOut and not onSprint(bases()), "The next show lands on the laid-out place, off Sprint")

	-- While a menu hides the HUD, a new place (the Burst button shown, a rotation) is taken at
	-- once, and the button waits under it.
	setVisible(false)
	local moved = rb.UDim2.fromOffset(500, 200)
	heat:SetAttribute("HudBasePosition", moved)
	assert(bases() == moved, "Hidden HUD: the base follows the new place")
	assert(heat.Position == rb.UDim2.new(0, 500, 1.35, 0), "...and the button waits under it")
	setVisible(true)

	-- A button without the attribute (the Burst button's script): only laid-out offsets count.
	local burstPlace = rb.UDim2.fromOffset(690, 240)
	burst.Position = burstPlace
	local _, burstBase = bases()
	assert(burstBase == burstPlace, "Burst: a laid-out place is its base")
	for step = 1, 6 do
		burst.Position = slideFrame(burstPlace, step / 32)
	end
	_, burstBase = bases()
	assert(burstBase == burstPlace, "Burst: slide frames never are")

	-- The slide reads the attribute; HeatVisionClient publishes it before drawing; the HUD's
	-- state is on Mainhud for scripts that start while a menu is open.
	has(hud, 'local laidOut = heatVisionButton:GetAttribute("HudBasePosition")', "setHUDVisible slides Heat Vision to the published place")
	has(hud, 'mainhud:SetAttribute("HudVisible", visible)', "Mainhud carries the HUD's state")
	hasNot(hud, "if hudVisible and btn.Position.Y.Scale < 1.0 then", "The old read-back rule is gone")
	local heatClient = read(HEAT)
	has(heatClient, 'button:SetAttribute("HudBasePosition", basePos)\n\tif hudVisible then\n\t\tbutton.Position = basePos', "HeatVisionClient publishes its place, hidden or not")
	has(heatClient, 'local hudVisible = not (mainhud and mainhud:GetAttribute("HudVisible") == false)', "...and starts from the HUD's real state")
	pass("the reported bug: a show slide cut by the next menu left Heat Vision on Sprint (reproduced); the base is now HeatVisionClient's HudBasePosition, slide frames never count, a hidden HUD takes a new place at once")
end

print(string.format("\n%d checks passed", passed))
