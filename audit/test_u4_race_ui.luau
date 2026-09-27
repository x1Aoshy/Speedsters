-- test_u4_race_ui.luau (Update 4, race_client, 2026-09-25)
-- Shared/RaceUiBuilder, Shared/RaceUiKit and Shared/RaceText (PLAN §7.4 items 3-5, 7), in plain
-- Lune with @lune/roblox as the env:
--   the four ScreenGuis build (RaceHud, RaceResults, RaceLobbyHud, RacePanelGui); no scripts
--   inside; ResetOnSpawn false; ZIndexBehavior Sibling; display orders 60 / 125 / 5; the HUD
--   under the top bar (CoreUISafeInsets); both windows are "Window" (640x420, 720x460) with the
--   header image "Icon", a Close button and a FitScale; every piece the controllers look up
--   by name is there; words never auto-translated;
--   2026-09-26 (owner's phone playtest): the results, the race panel and the Flash's sign-up in
--   their compact arrangement on 8 phones: inside, no overlaps, words >= 11 px on the screen,
--   taps >= 44 px, CoreUISafeInsets, and back to the desktop arrangement exactly;
--   RaceText: every key in all 10 languages within its cap, Spanish/Portuguese actually
--   translated, French no-break spaces, Format / Ordinal / Seconds / Clock / Elapsed.
-- Run: lune run audit/test_u4_race_ui.luau   (from the project root)
local roblox = require("@lune/roblox")

local RaceUiBuilder = require("../src/common/ReplicatedStorage/Shared/RaceUiBuilder")
local RaceUiKit = require("../src/common/ReplicatedStorage/Shared/RaceUiKit")
local RaceText = require("../src/common/ReplicatedStorage/Shared/RaceText")
local RaceHudLayout = require("../src/common/ReplicatedStorage/Shared/RaceHudLayout")

local ENV = {
	Instance = roblox.Instance, UDim = roblox.UDim, UDim2 = roblox.UDim2, Vector2 = roblox.Vector2,
	Color3 = roblox.Color3, ColorSequence = roblox.ColorSequence, ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
	NumberSequence = roblox.NumberSequence, NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
	Enum = roblox.Enum, Font = roblox.Font,
}

local passed = 0
local function pass(text)
	passed += 1
	print("PASS " .. text)
end

local function find(root, path)
	local node = root
	for name in string.gmatch(path, "[^%.]+") do
		node = node and node:FindFirstChild(name)
	end
	return node
end

local function commonChecks(gui, name, order)
	assert(gui:IsA("ScreenGui") and gui.Name == name, name .. ": a ScreenGui named " .. name)
	assert(gui.ResetOnSpawn == false, name .. ": ResetOnSpawn false")
	assert(gui.ZIndexBehavior == roblox.Enum.ZIndexBehavior.Sibling, name .. ": ZIndexBehavior Sibling")
	assert(gui.DisplayOrder == order, name .. ": DisplayOrder " .. order)
	for _, d in gui:GetDescendants() do
		assert(not d:IsA("LuaSourceContainer"), name .. ": a script inside (" .. d:GetFullName() .. ")")
		if d:IsA("TextLabel") or d:IsA("TextButton") then
			assert(d.AutoLocalize == false, name .. ": " .. d:GetFullName() .. " would be auto-translated on top of RaceText")
		end
		if d:IsA("UIGradient") then
			assert(#d.Transparency.Keypoints <= 20, name .. ": a gradient with more than 20 keypoints")
		end
	end
end

local function window(gui, width, height)
	local w = gui:FindFirstChild("Window")
	assert(w and w:IsA("Frame"), gui.Name .. ": root frame Window")
	assert(w.Size.X.Offset == width and w.Size.Y.Offset == height, gui.Name .. ": window " .. width .. "x" .. height)
	local icon = w:FindFirstChild("Icon")
	assert(icon and icon:IsA("ImageLabel") and icon.Image ~= "", gui.Name .. ": header image Icon")
	assert(w:FindFirstChild("Close") and w.Close:IsA("GuiButton"), gui.Name .. ": Close button")
	assert(w:FindFirstChild("FitScale") and w.FitScale:IsA("UIScale"), gui.Name .. ": FitScale")
	assert(w:FindFirstChild("Background") and w:FindFirstChild("Title"), gui.Name .. ": blocky art and title")
	-- ModalJuice skips a window that already has a UIScale; there must be exactly one.
	local scales = 0
	for _, child in w:GetChildren() do
		if child:IsA("UIScale") then
			scales += 1
		end
	end
	assert(scales == 1, gui.Name .. ": exactly one UIScale on the window")
	return w
end

-- 1. RaceHud.
do
	local hud = RaceUiBuilder.BuildHud(ENV)
	commonChecks(hud, "RaceHud", 60)
	assert(hud.Enabled == false, "RaceHud starts off")
	assert(hud.ScreenInsets == roblox.Enum.ScreenInsets.CoreUISafeInsets and hud.IgnoreGuiInset == false, "RaceHud under the top bar")
	for _, path in {
		"Countdown.Starting", "Countdown.Number", "Countdown.Number.Pop", "Status", "Podium", "YouPill.Text",
		"Goal.Orb", "Goal.Distance", "Goal.Elapsed", "SpeedBar.Fill", "SpeedBar.Text", "SpeedBar.Icon",
		"Labels.Multiplier", "Labels.Accel", "Stamina.Fill", "Stamina.Text", "Gauge.Zone", "Gauge.Zone.Stripes",
		"Gauge.Core", "Gauge.Overheat", "Gauge.Fill", "Gauge.Needle", "Hint.Text", "Hint.Glyph", "Banner", "Banner.Pop",
		"Feedback", "Action.Label", "ActionRing",
	} do
		assert(find(hud, path), "RaceHud." .. path .. " missing")
	end
	for place = 1, 3 do
		for _, part in { "Headshot", "Headshot.NameStrip.PlayerName", "Rank.Number", "You", "Reward.Icon", "Reward.Amount" } do
			assert(find(hud, "Podium.Card" .. place .. "." .. part), "podium card " .. place .. " lacks " .. part)
		end
	end
	local segments = 0
	for _, child in hud.ActionRing:GetChildren() do
		if child.Name:match("^Seg%d+$") then
			segments += 1
		end
	end
	assert(segments == RaceHudLayout.RingSegments, "the ring has " .. RaceHudLayout.RingSegments .. " segments")
	assert(hud.Action:IsA("TextButton") and hud.Action:GetAttribute("Palette") == "Blue", "the action button is a Blue designer button")
	pass("RaceHud: every piece, no scripts, off at start, under the top bar, 36-segment ring")
end

-- 2. RaceResults.
do
	local gui = RaceUiBuilder.BuildResults(ENV)
	commonChecks(gui, "RaceResults", 125)
	local w = window(gui, 640, 420)
	for _, path in { "Content.Place", "Content.Time", "Content.NewBest", "Content.Best", "Content.Rewards.Wins",
		"Content.Rewards.Speed", "Content.Rewards.Ticket", "Content.Rewards.FirstToday", "Content.CapNote", "Content.Pending",
		"Content.Podium.Card1", "Content.Podium.Card2", "Content.Podium.Card3" } do
		assert(find(w, path), "RaceResults.Window." .. path .. " missing")
	end
	local again, lobby = find(w, "Content.Buttons.RaceAgain"), find(w, "Content.Buttons.Lobby")
	assert(again and again.Size.X.Offset == 220 and again.Size.Y.Offset == 62 and again:GetAttribute("Palette") == "Green", "RACE AGAIN green 220x62")
	assert(lobby and lobby.Size.X.Offset == 200 and lobby.Size.Y.Offset == 62 and lobby:GetAttribute("Palette") == "Navy", "LOBBY navy 200x62")
	assert(find(w, "Content.Podium.Card1.Headshot").Size.X.Offset == 88 and find(w, "Content.Podium.Card2.Headshot").Size.X.Offset == 72, "mini podium 88/72")
	pass("RaceResults: Window 640x420 with Icon, RACE AGAIN / LOBBY, mini podium 88/72, reward chips")
end

-- 3. RaceLobbyHud.
do
	local gui = RaceUiBuilder.BuildLobbyHud(ENV)
	commonChecks(gui, "RaceLobbyHud", 5)
	assert(gui.ScreenInsets == roblox.Enum.ScreenInsets.CoreUISafeInsets, "the lobby HUD under the top bar")
	for _, path in { "RaceButton.Icon", "RaceButton.Title", "RaceButton.State", "RaceButton.Alert", "RaceButton.Pulse",
		"Invite.Card.Avatars.Avatar4", "Invite.Card.Title", "Invite.Card.Body", "Invite.Card.Join", "Invite.Card.Dismiss", "Toast.Text" } do
		assert(find(gui, path), "RaceLobbyHud." .. path .. " missing")
	end
	assert(gui.RaceButton.Visible == false and gui.Invite.Visible == false, "button and invite start hidden")
	pass("RaceLobbyHud: RACE button (icon, state, alert, pulse), invite (avatars, JOIN, x), toast")
end

-- 4. RacePanelGui.
do
	local gui = RaceUiBuilder.BuildPanel(ENV)
	commonChecks(gui, "RacePanelGui", 20)
	assert(gui.Enabled == false, "the panel starts closed")
	local w = window(gui, 720, 460)
	for _, path in { "Left.NextRace", "Left.Timer", "Left.Ready", "Left.Join", "Left.Leave", "Left.Rewards.First.Amount",
		"Left.Rewards.Finish.Amount", "Left.Rewards.FirstToday", "Right.Fastest", "Right.Weekly", "Right.AllTime",
		"Right.YourBest", "Right.List", "Right.Empty" } do
		assert(find(w, path), "RacePanelGui.Window." .. path .. " missing")
	end
	local kit = RaceUiKit.new(ENV)
	local row = RaceUiBuilder.BoardRow(kit, w.Right.List, 7)
	assert(row.Name == "Row07" and row.LayoutOrder == 7 and row.Rank and row.Headshot and row:FindFirstChild("PlayerName") and row.Time and row.Mine, "board row pieces")
	assert(row.Size.Y.Offset == RaceUiBuilder.BoardRowHeight - 6, "board rows 52 px apart")
	pass("RacePanelGui: Window 720x460 with Icon, join/leave, rewards, weekly/all-time list rows")
end

-- 5. 2026-09-26 (owner's phone playtest: "the results UI is very big on the phone, the race
--    sign-up too"): the three windows (RaceResults, RacePanelGui, the Flash's RACE SIGN-UP) on
--    real landscape phones, each in its compact arrangement at the scale RaceHudLayout.WindowFit
--    gives there:
--      * their ScreenGuis under the top bar and inside the notch (CoreUISafeInsets);
--      * every piece inside the window (the header within its overhang), no two pieces
--        overlapping (the header's icon off every button and left-aligned text);
--      * every word 11 px or more on the screen in English and 10 px in every language (fixed
--        sizes x scale; TextScaled words estimated from their box and the longest line they
--        show, FredokaOne about 0.62 em per capital), fixed words inside their boxes;
--      * RACE AGAIN, LOBBY, JOIN RACE, the category tiles, WEEKLY RECORDS and Close at least
--        44 x 44 px on the screen, the Weekly / All-time tabs 32 px tall;
--      * back to the desktop arrangement exactly as it was built, 1:1 on a desktop.
do
	local LobbyNpcUi = require("../src/common/ReplicatedStorage/Shared/LobbyNpcUi")
	local LobbyNpcText = require("../src/common/ReplicatedStorage/Shared/LobbyNpcText")
	local PHONES = {
		{ 667, 375, 58, 0, 0 }, { 667, 375, 36, 0, 0 }, { 812, 375, 58, 44, 21 }, { 844, 390, 58, 47, 21 },
		{ 896, 414, 58, 44, 21 }, { 932, 430, 58, 59, 21 }, { 640, 360, 58, 0, 0 }, { 800, 360, 58, 0, 0 },
	}

	-- Rects in design px from the window's top-left corner (UIGridLayout / UIListLayout children
	-- where their layout puts them, every child shown: the worst case).
	local function resolve(window)
		local rects = {}
		local function walk(object, r)
			rects[object] = r
			local children = {}
			for _, child in object:GetChildren() do
				if child:IsA("GuiObject") then
					table.insert(children, child)
				end
			end
			table.sort(children, function(a, b)
				if a.LayoutOrder ~= b.LayoutOrder then
					return a.LayoutOrder < b.LayoutOrder
				end
				return a.Name < b.Name
			end)
			local grid = object:FindFirstChildOfClass("UIGridLayout")
			local list = object:FindFirstChildOfClass("UIListLayout")
			local padding = object:FindFirstChildOfClass("UIPadding")
			local innerW = if object:IsA("ScrollingFrame") then r.W - object.ScrollBarThickness else r.W
			local y = r.Y + (if padding then padding.PaddingTop.Offset else 0)
			for index, child in children do
				local s, p, a = child.Size, child.Position, child.AnchorPoint
				local w, h = s.X.Scale * innerW + s.X.Offset, s.Y.Scale * r.H + s.Y.Offset
				local rect
				if grid then
					local cw, ch = grid.CellSize.X.Offset, grid.CellSize.Y.Offset
					local px, py = grid.CellPadding.X.Offset, grid.CellPadding.Y.Offset
					local columns = math.max(1, math.floor((r.W + px) / (cw + px)))
					local k = index - 1
					rect = { X = r.X + (k % columns) * (cw + px), Y = r.Y + math.floor(k / columns) * (ch + py), W = cw, H = ch }
				elseif list then
					rect = { X = r.X + (innerW - w) / 2, Y = y, W = w, H = h }
					y += h + list.Padding.Offset
				else
					rect = { X = r.X + p.X.Scale * r.W + p.X.Offset - a.X * w, Y = r.Y + p.Y.Scale * r.H + p.Y.Offset - a.Y * h, W = w, H = h }
				end
				walk(child, rect)
			end
		end
		walk(window, { X = 0, Y = 0, W = window.Size.X.Offset, H = window.Size.Y.Offset })
		return rects
	end

	local function overlaps(a, b)
		return a.X < b.X + b.W - 0.01 and b.X < a.X + a.W - 0.01 and a.Y < b.Y + b.H - 0.01 and b.Y < a.Y + a.H - 0.01
	end
	local function describeRect(r)
		return string.format("[%d,%d %dx%d]", r.X, r.Y, r.W, r.H)
	end

	-- A line's width in em (FredokaOne: capitals and digits ~0.62, other Latin ~0.5, spaces 0.28,
	-- . , : ; ! ' and · 0.3, Thai / Arabic marks nothing).
	local function advance(text)
		local total = 0
		for _, code in utf8.codes(text) do
			if code == 32 or code == 0xA0 then
				total += 0.28
			elseif (code >= 0x0E31 and code <= 0x0E3A and code ~= 0x0E32 and code ~= 0x0E33) or (code >= 0x0E47 and code <= 0x0E4E) or (code >= 0x064B and code <= 0x065F) then
				total += 0
			elseif (code >= 65 and code <= 90) or (code >= 48 and code <= 57) then
				total += 0.62
			elseif code == 46 or code == 44 or code == 58 or code == 59 or code == 33 or code == 39 or code == 0xB7 then
				total += 0.3
			elseif code < 128 then
				total += 0.5
			else
				total += 0.6
			end
		end
		return total
	end
	-- The size TextScaled gives `text` in a w x h box (wrapped: greedy word wrap).
	local function scaledSize(text, w, h, wrapped)
		if not wrapped then
			return math.min(h, w / math.max(0.01, advance(text)))
		end
		local size = h
		while size > 1 do
			local lines, line = 1, 0
			for word in string.gmatch(text, "%S+") do
				local width = advance(word) * size
				local spaced = if line > 0 then line + 0.28 * size + width else width
				if spaced <= w then
					line = spaced
				else
					lines += 1
					line = width
				end
			end
			if lines * size <= h then
				return size
			end
			size -= 0.25
		end
		return size
	end

	-- The lines each TextScaled label shows (by the path under the window), per language.
	local function race(key, ...)
		local args = table.pack(...)
		return function(lang)
			return RaceText.Format(key, lang, table.unpack(args, 1, args.n))
		end
	end
	local function npc(key)
		return function(lang)
			return LobbyNpcText.Get(key, lang)
		end
	end
	local function literal(text)
		return function()
			return text
		end
	end
	local function upperOrdinal(n)
		return function(lang)
			local ordinal = RaceText.Ordinal(n, lang)
			return if lang == "en" then string.upper(ordinal) else ordinal
		end
	end
	local RESULTS_LINES = {
		Title = { race("ResultsTitle") },
		["Content.Place"] = { function(lang) return RaceText.Format("PlaceTop", lang, upperOrdinal(1)(lang)) end, race("Dq"), race("Dnf"),
			function(lang) return upperOrdinal(12)(lang) .. " / 12" end },
		["Content.Time"] = { race("Time", "31.20s") },
		["Content.Best"] = { race("Best", "31.20s") },
		["Content.NewBest.Label"] = { race("NewBest") },
		["Content.Rewards.Wins.Label"] = { race("Wins", "1.23M") },
		["Content.Rewards.Speed.Label"] = { race("Speed", "12.3K") },
		["Content.Rewards.Ticket.Label"] = { race("Ticket", 1) },
		["Content.Rewards.FirstToday.Label"] = { race("FirstToday") },
		["Content.Pending"] = { race("Pending") },
		["Content.CapNote"] = { race("CapNote") },
		["Content.Buttons.RaceAgain.Label"] = { race("RaceAgain") },
		["Content.Buttons.Lobby.Label"] = { race("LobbyIn", 8), race("Lobby") },
	}
	for place = 1, 3 do
		RESULTS_LINES["Content.Podium.Card" .. place .. ".Reward.Amount"] = { literal("+1.23K"), literal("+123M") }
	end
	local PANEL_LINES = {
		Title = { race("Race") },
		["Left.NextRace"] = { race("NextRace") },
		["Left.Timer"] = { literal("0:15"), race("StartingSoon"), race("Live", "1:15"), race("Now") },
		["Left.Ready"] = { race("Ready", 12, 12) },
		["Left.Join.Label"] = { race("JoinRace") },
		["Left.Leave.Label"] = { race("LeaveQueue") },
		["Left.Rewards.Title"] = { race("Rewards") },
		["Left.Rewards.FirstToday"] = { race("FirstRaceToday") },
		["Right.Fastest"] = { race("Fastest") },
		["Right.Weekly.Label"] = { race("Weekly") },
		["Right.AllTime.Label"] = { race("AllTime") },
		["Right.YourBest"] = { race("YourBest", "31.20s", 12), race("NoTime") },
		["Right.Empty"] = { race("Empty"), race("Loading") },
	}
	for index, key in { "First", "Second", "Third", "Finish" } do
		PANEL_LINES["Left.Rewards." .. key .. ".Place"] = { if index <= 3 then function(lang) return RaceText.Ordinal(index, lang) end else race("Finish") }
		PANEL_LINES["Left.Rewards." .. key .. ".Amount"] = { literal("+1.23K") }
	end
	local FLASH_LINES = {
		Title = { npc("FlashTitle") },
		["Speech.Line"] = { npc("FlashLine") },
		["Status"] = { function(lang)
			return RaceText.Get("NextRace", lang) .. ": " .. RaceText.Get("StartingSoon", lang) .. "  ·  " .. RaceText.Format("Ready", lang, 12, 12)
		end, function(lang) return LobbyNpcText.Get("Queued", lang) end, race("RaceLockedTutorial") },
		["Records.Label"] = { npc("Records") },
	}
	for category, keys in LobbyNpcText.CategoryKeys do
		FLASH_LINES["Tiles." .. category .. ".Label"] = { npc(keys.Title) }
		FLASH_LINES["Tiles." .. category .. ".Sub"] = { npc(keys.Sub), npc("BeginnerLocked") }
	end
	-- Fixed-size words and the longest line they show.
	local FIXED_LINES = {}
	for place = 1, 3 do
		FIXED_LINES["Content.Podium.Card" .. place .. ".You"] = { race("You") }
		FIXED_LINES["Content.Podium.Card" .. place .. ".Rank.Number"] = { literal(tostring(place)) }
	end
	FIXED_LINES["Speech.Speaker"] = { function(lang) return string.upper(LobbyNpcText.Get("FlashName", lang)) end }

	local function pathOf(object, window)
		local parts = {}
		local node = object
		while node and node ~= window do
			table.insert(parts, 1, node.Name)
			node = node.Parent
		end
		return table.concat(parts, ".")
	end

	local function checkWindow(name, window, arrange, sizes, lines, pieces, buttons, tabs)
		local wideBefore = {}
		local function snapshot(into)
			for _, d in window:GetDescendants() do
				local entry = {}
				if d:IsA("GuiObject") then
					entry = { tostring(d.Position), tostring(d.Size), tostring(d.AnchorPoint) }
					if d:IsA("TextLabel") or d:IsA("TextButton") then
						table.insert(entry, tostring(d.TextSize) .. tostring(d.TextScaled) .. tostring(d.TextWrapped))
					end
					if d:IsA("ImageLabel") then
						table.insert(entry, tostring(d.ScaleType))
					end
				elseif d:IsA("UIGridLayout") then
					entry = { tostring(d.CellSize), tostring(d.CellPadding) }
				elseif d:IsA("UIListLayout") then
					entry = { tostring(d.Padding) }
				elseif d:IsA("UITextSizeConstraint") then
					entry = { tostring(d.MaxTextSize), tostring(d.MinTextSize) }
				end
				into[d:GetFullName() .. "#" .. d.ClassName] = table.concat(entry, "|")
			end
			into["Window"] = tostring(window.Size)
		end
		snapshot(wideBefore)
		local lowest, worst, worstWhere = math.huge, math.huge, ""
		for _, phone in PHONES do
			local roomW, roomH = phone[1] - 2 * phone[4], phone[2] - phone[3] - phone[5]
			local label = string.format("%s on %dx%d top %d", name, phone[1], phone[2], phone[3])
			local fit = RaceUiBuilder.FitWindow(ENV, window, arrange, sizes, phone[1], phone[2], roomW, roomH, true)
			assert(window:GetAttribute("Compact") == true, label .. ": compact arrangement")
			assert(window.Size.X.Offset == sizes.Compact[1] and window.Size.Y.Offset == sizes.Compact[2], label .. ": compact size")
			assert(window.Position == roblox.UDim2.new(0.5, 0, 0.5, math.floor(fit.OffsetY + 0.5)), label .. ": centred with its header")
			local scale = fit.Scale
			lowest = math.min(lowest, scale)
			local W, H = sizes.Compact[1], sizes.Compact[2]
			local above, beside = RaceUiBuilder.HeaderOverhang(true)
			local rects = resolve(window)
			-- Inside the window (the header within its overhang; a list's rows scroll inside it).
			local scroller = window:FindFirstChildWhichIsA("ScrollingFrame", true)
			for object, r in rects do
				if object ~= window and object:IsA("GuiObject") and not (scroller and object:IsDescendantOf(scroller)) then
					local path = pathOf(object, window)
					local header = path == "Title" or path == "Icon" or path == "Close"
					local slack = if header then beside else 0
					assert(r.X >= -slack - 0.01 and r.X + r.W <= W + slack + 0.01 and r.Y >= (if header then -above else 0) - 0.01 and r.Y + r.H <= H + 0.01,
						label .. ": " .. path .. " " .. describeRect(r) .. " outside the " .. W .. "x" .. H .. " window")
				end
			end
			-- No two pieces overlap (a piece and what it holds excepted).
			local list = {}
			for _, path in pieces do
				local object = window
				for part in string.gmatch(path, "[^%.]+") do
					object = object and object:FindFirstChild(part)
				end
				assert(object, label .. ": no " .. path)
				table.insert(list, { Path = path, Object = object, Rect = rects[object] })
			end
			for i = 1, #list do
				for j = i + 1, #list do
					local a, b = list[i], list[j]
					if not a.Object:IsAncestorOf(b.Object) and not b.Object:IsAncestorOf(a.Object) then
						assert(not overlaps(a.Rect, b.Rect), label .. ": " .. a.Path .. " " .. describeRect(a.Rect) .. " overlaps " .. b.Path .. " " .. describeRect(b.Rect))
					end
				end
			end
			-- The header's icon: off every button and every left-aligned word.
			local icon = rects[window.Icon]
			for object, r in rects do
				if object ~= window.Icon and object:IsDescendantOf(window) and ((object:IsA("GuiButton") and object ~= window.Close)
					or (object:IsA("TextLabel") and object.TextXAlignment == roblox.Enum.TextXAlignment.Left)) then
					assert(not overlaps(icon, r), label .. ": the header icon covers " .. pathOf(object, window))
				end
			end
			-- Words.
			for _, d in window:GetDescendants() do
				if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.TextTransparency < 1 then
					local path = pathOf(d, window)
					local r = rects[d]
					if d.TextScaled then
						local limits = d:FindFirstChildOfClass("UITextSizeConstraint")
						local maxSize = if limits then limits.MaxTextSize else 100
						local makers = lines[path]
						if not makers and d.Text ~= "" then
							makers = { literal(d.Text) }
						end
						for _, make in makers or {} do
							for _, lang in RaceText.Languages do
								local text = make(lang)
								local onScreen = math.min(maxSize, scaledSize(text, r.W, r.H, d.TextWrapped)) * scale
								local floor = if lang == "en" then 11 else 10
								assert(onScreen >= floor - 0.01, ("%s: %s \"%s\" (%s) about %.1f px on the screen"):format(label, path, text, lang, onScreen))
								if onScreen < worst then
									worst, worstWhere = onScreen, path .. " (" .. lang .. ")"
								end
							end
						end
					else
						local onScreen = d.TextSize * scale
						assert(onScreen >= 11 - 0.01, ("%s: %s is %d px x %.2f = %.1f px"):format(label, path, d.TextSize, scale, onScreen))
						for _, make in FIXED_LINES[path] or {} do
							for _, lang in RaceText.Languages do
								local text = make(lang)
								assert(advance(text) * d.TextSize <= r.W + 2, ("%s: %s \"%s\" wider than its %d px box"):format(label, path, text, r.W))
							end
						end
						if onScreen < worst then
							worst, worstWhere = onScreen, path
						end
					end
				end
			end
			-- Taps.
			for _, path in buttons do
				local object = window
				for part in string.gmatch(path, "[^%.]+") do
					object = object:FindFirstChild(part)
				end
				local r = rects[object]
				assert(r.W * scale >= 44 - 0.01 and r.H * scale >= 44 - 0.01, ("%s: %s %.0f x %.0f px on the screen"):format(label, path, r.W * scale, r.H * scale))
			end
			for _, path in tabs or {} do
				local r = rects[window.Right[path]]
				assert(r.H * scale >= 32 - 0.01 and r.W * scale >= 44, ("%s: tab %s %.0f px tall"):format(label, path, r.H * scale))
			end
		end
		-- Back to the desktop: exactly as built, 1:1 on a 1080p screen.
		local fit = RaceUiBuilder.FitWindow(ENV, window, arrange, sizes, 1920, 1080, 1920, 1022, false)
		assert(window:GetAttribute("Compact") == false and fit.Scale == 1, name .. ": the desktop arrangement 1:1 on 1920x1080")
		local wideAfter = {}
		snapshot(wideAfter)
		for key, value in wideBefore do
			assert(wideAfter[key] == value, name .. ": " .. key .. " differs after compact -> wide (" .. tostring(wideAfter[key]) .. " vs " .. value .. ")")
		end
		return lowest, worst, worstWhere
	end

	local results = RaceUiBuilder.BuildResults(ENV)
	local panel = RaceUiBuilder.BuildPanel(ENV)
	local flash = LobbyNpcUi.BuildFlashDialog(ENV)
	for _, gui in { results, panel, flash } do
		assert(gui.ScreenInsets == roblox.Enum.ScreenInsets.CoreUISafeInsets and gui.IgnoreGuiInset == false, gui.Name .. ": under the top bar and inside the notch")
	end
	-- Two rows on the board, arranged like their list.
	local kit = RaceUiKit.new(ENV)
	for index = 1, 5 do
		RaceUiBuilder.BoardRow(kit, panel.Window.Right.List, index)
	end
	local summary = {}
	local resultPieces = { "Title", "Close", "Content.Place", "Content.Time", "Content.Best", "Content.NewBest", "Content.Rewards.Wins",
		"Content.Rewards.Speed", "Content.Rewards.Ticket", "Content.Rewards.FirstToday", "Content.CapNote",
		"Content.Buttons.RaceAgain", "Content.Buttons.Lobby" }
	for place = 1, 3 do
		for _, part in { "", ".Rank", ".You" } do
			table.insert(resultPieces, "Content.Podium.Card" .. place .. part)
		end
	end
	local lowest, worst, where = checkWindow("RaceResults", results.Window, RaceUiBuilder.ArrangeResults,
		{ Wide = RaceUiBuilder.ResultsSize, Compact = RaceUiBuilder.ResultsCompactSize }, RESULTS_LINES, resultPieces,
		{ "Content.Buttons.RaceAgain", "Content.Buttons.Lobby", "Close" })
	table.insert(summary, ("results %.2f (smallest word %.1f px: %s)"):format(lowest, worst, where))

	local panelPieces = { "Title", "Close", "Left.NextRace", "Left.Timer", "Left.Ready", "Left.Join", "Left.Rewards", "Right.Fastest",
		"Right.Weekly", "Right.AllTime", "Right.YourBest", "Right.List", "Left.Rewards.Title", "Left.Rewards.FirstToday" }
	for _, key in { "First", "Second", "Third", "Finish" } do
		for _, part in { "", ".Place", ".Icon", ".Amount" } do
			table.insert(panelPieces, "Left.Rewards." .. key .. part)
		end
	end
	for index = 1, 3 do
		for _, part in { "", ".Rank", ".Headshot", ".PlayerName", ".Time" } do
			table.insert(panelPieces, string.format("Right.List.Row%02d%s", index, part))
		end
	end
	lowest, worst, where = checkWindow("RacePanelGui", panel.Window, RaceUiBuilder.ArrangePanel,
		{ Wide = RaceUiBuilder.PanelSize, Compact = RaceUiBuilder.PanelCompactSize }, PANEL_LINES, panelPieces,
		{ "Left.Join", "Left.Leave", "Close" }, { "Weekly", "AllTime" })
	table.insert(summary, ("panel %.2f (%.1f px: %s)"):format(lowest, worst, where))
	-- A row made while the list is compact is compact.
	RaceUiBuilder.ArrangePanel(ENV, panel.Window, true)
	local late = RaceUiBuilder.BoardRow(kit, panel.Window.Right.List, 9)
	assert(late.Size.Y.Offset == RaceUiBuilder.PanelLayouts.Compact.Row.H, "a row made on a phone takes the compact size")
	RaceUiBuilder.ArrangePanel(ENV, panel.Window, false)
	assert(late.Size.Y.Offset == RaceUiBuilder.BoardRowHeight - 6, "and back")

	local flashPieces = { "Title", "Close", "Speech.Speaker", "Speech.Line", "Status", "Records" }
	for _, category in LobbyNpcUi.Categories do
		for _, part in { "", ".Icon", ".Label", ".Sub" } do
			table.insert(flashPieces, "Tiles." .. category .. part)
		end
	end
	local flashButtons = { "Records", "Close" }
	for _, category in LobbyNpcUi.Categories do
		table.insert(flashButtons, "Tiles." .. category)
	end
	lowest, worst, where = checkWindow("LobbyNpcFlashGui", flash.Window, LobbyNpcUi.ArrangeFlashDialog,
		{ Wide = LobbyNpcUi.DialogSize, Compact = LobbyNpcUi.DialogCompactSize }, FLASH_LINES, flashPieces, flashButtons)
	table.insert(summary, ("sign-up %.2f (%.1f px: %s)"):format(lowest, worst, where))
	-- LobbyNpcUi.Fit is FitWindow with the dialog's arrangements; FitScale the same scale (the
	-- notch does not bind on this phone).
	local fit = LobbyNpcUi.Fit(ENV, flash.Window, 812, 375, 724, 296, true)
	assert(flash.Window:GetAttribute("Compact") == true and math.abs(fit.Scale - LobbyNpcUi.FitScale(812, 375, 58 + 21, true)) < 1e-9, "LobbyNpcUi.Fit / FitScale")
	assert(LobbyNpcUi.FitScale(1920, 1080, 58, false) == 1, "the sign-up 1:1 on a desktop")
	pass("windows on " .. #PHONES .. " phones, compact: inside, no overlaps, words >= 11 px (en) / 10 px (all), taps >= 44 px, back to desktop exactly; " .. table.concat(summary, "; "))
end

-- 6. RaceText.
do
	local langs = RaceText.Languages
	assert(#langs == 10, "10 languages")
	local keyCount = 0
	for key in RaceText.Caps do
		keyCount += 1
		for _, lang in langs do
			local text = RaceText.Strings[lang][key]
			assert(type(text) == "string" and text ~= "", lang .. " lacks " .. key)
			local length = RaceText.MeasuredLength(text)
			assert(length <= RaceText.Caps[key], ("%s.%s is %d long (cap %d): %s"):format(lang, key, length, RaceText.Caps[key], text))
			-- The same placeholders as English.
			for index in string.gmatch(RaceText.Strings.en[key], "{(%d)}") do
				assert(string.find(text, "{" .. index .. "}", 1, true), lang .. "." .. key .. " lost {" .. index .. "}")
			end
		end
	end
	for _, lang in langs do
		for key in RaceText.Strings[lang] do
			assert(RaceText.Caps[key], lang .. "." .. key .. " has no cap")
		end
	end
	assert(keyCount >= 35, "about 35 keys or more (" .. keyCount .. ")")
	-- Spanish and Portuguese are real translations (numbers-only lines may match English).
	for _, lang in { "es", "pt" } do
		local same = 0
		for key, text in RaceText.Strings[lang] do
			if text == RaceText.Strings.en[key] then
				same += 1
			end
		end
		assert(same <= 8, lang .. ": " .. same .. " lines identical to English")
	end
	-- French: a no-break space before "!" and ":" (TutorialText's convention).
	for key, text in RaceText.Strings.fr do
		assert(not string.find(text, " !", 1, true) and not string.find(text, " :", 1, true), "fr." .. key .. " breaks before ! or :")
	end
	-- The toast keys RaceService sends all exist.
	for _, key in { "RaceOff", "RaceLoading", "RaceLockedTutorial", "RaceAfk", "RaceAlreadyQueued", "RaceDead",
		"RaceFalseStart", "RaceDisqualified", "StreamTimeout" } do
		assert(RaceText.Caps[key], "toast key " .. key)
	end
	-- Helpers.
	assert(RaceText.Format("Mph", "en", 84, 98) == "MPH: 84 / 98", "Format fills placeholders")
	assert(RaceText.Format("StartPerfect", "en", 45) == "PERFECT START! +45%", "a % in the text survives")
	assert(RaceText.Get("NoSuchKey", "es") == "NoSuchKey" and RaceText.Get("Go", "xx") == "GO!", "fallbacks")
	assert(RaceText.Ordinal(1, "en") == "1st" and RaceText.Ordinal(2, "en") == "2nd" and RaceText.Ordinal(3, "en") == "3rd"
		and RaceText.Ordinal(11, "en") == "11th" and RaceText.Ordinal(22, "en") == "22nd", "English ordinals")
	assert(RaceText.Ordinal(1, "es") == "1.º" and RaceText.Ordinal(2, "pt") == "2º" and RaceText.Ordinal(1, "fr") == "1re"
		and RaceText.Ordinal(3, "de") == "3." and RaceText.Ordinal(4, "th") == "4", "other ordinals")
	assert(RaceText.Seconds(31200) == "31.20s" and RaceText.Seconds(0) == "--", "Seconds")
	assert(RaceText.Clock(15) == "0:15" and RaceText.Clock(75.2) == "1:16", "Clock")
	assert(RaceText.Elapsed(27.43) == "0:27.4" and RaceText.Elapsed(61.05) == "1:01.0", "Elapsed")
	assert(RaceText.LanguageFor("pt-br") == "pt" and RaceText.LanguageFor("zh-cn") == "en", "LanguageFor")
	pass(("RaceText: %d keys x 10 languages within their caps; es/pt translated; fr no-break spaces; helpers"):format(keyCount))
end

print(("ALL PASSED (%d groups)"):format(passed))
