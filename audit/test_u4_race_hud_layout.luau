-- test_u4_race_hud_layout.luau (Update 4, race_client, 2026-09-25)
-- Shared/RaceHudLayout (PLAN §7.4 item 3): the race HUD on the acceptance screens
--   812x339, 667x339, 2340x1080, 1024x732 (touch), 1366x730, 1920x1022, 3840x2160 (keyboard),
--   1920x1080 (console)
-- with Roblox's top bar at 36 and 58 px: no two of bar, labels, stamina, gauge, hint, number,
-- "STARTING", status, podium, "You" pill, ORB readout, action button, its ring and the jump
-- button closer than 6 px; console inside the 5 % safe area; the action button >= 56 px and
-- >= 30 px from the jump button; every text >= 11 px; the podium's right edge < 35 % of a
-- phone's width; everything on screen. Also the moved Sprint piece, the ring geometry and the
-- lobby button / invite toast.
-- 2026-09-26 (owner's phone playtest): 11 real landscape phones (notch, home bar, 36 / 58 px top
-- bars): the HUD keeps the middle and the thumbstick's corner clear; the race windows' fit
-- (RaceHudLayout.WindowFit): compact, <= 84 % of the room, <= 80 % of the screen, centred under
-- the top bar, scale >= 0.8; 1:1 on desktops.
-- Run: lune run audit/test_u4_race_hud_layout.luau   (from the project root)
local Layout = require("../src/common/ReplicatedStorage/Shared/RaceHudLayout")
local HudErgonomics = require("../src/common/ReplicatedStorage/Shared/HudErgonomics")

local passed = 0
local function pass(text)
	passed += 1
	print("PASS " .. text)
end

local SCREENS = {
	{ 812, 339, "Touch" },
	{ 667, 339, "Touch" },
	{ 2340, 1080, "Touch" },
	{ 1024, 732, "Touch" },
	{ 1366, 730, "Keyboard" },
	{ 1920, 1022, "Keyboard" },
	{ 1920, 1080, "Gamepad" },
	{ 3840, 2160, "Keyboard" },
}
local GAP = 6

local function describe(r)
	return string.format("[%d,%d %dx%d]", r.Left, r.Top, r.Right - r.Left, r.Bottom - r.Top)
end

local function check(W, viewH, input, topBar, layoutText)
	local H = viewH - topBar
	local label = string.format("%dx%d %s top %d", W, viewH, input, topBar)
	local plan = Layout.Plan(W, H, input, topBar, { layout = layoutText })
	local pieces = Layout.Pieces(plan)
	-- Pairs that may never come closer than GAP. The action button and its ring are one piece.
	for i = 1, #pieces do
		for j = i + 1, #pieces do
			local a, b = pieces[i], pieces[j]
			local same = (a.Name == "Action" and b.Name == "Ring") or (a.Name == "Ring" and b.Name == "Action")
			if not same then
				assert(not HudErgonomics.Overlaps(a.Rect, b.Rect, GAP - 0.01),
					label .. ": " .. a.Name .. " " .. describe(a.Rect) .. " touches " .. b.Name .. " " .. describe(b.Rect))
			end
		end
	end
	-- On screen; console inside 5 %.
	for _, piece in pieces do
		local r = piece.Rect
		if piece.Name ~= "Jump" then
			assert(r.Left >= 0 and r.Top >= 0 and r.Right <= W and r.Bottom <= H, label .. ": " .. piece.Name .. " off screen " .. describe(r))
		end
		if input == "Gamepad" then
			assert(r.Left >= W * 0.05 - 0.5 and r.Right <= W * 0.95 + 0.5 and r.Top >= H * 0.05 - 0.5 and r.Bottom <= H * 0.95 + 0.5,
				label .. ": " .. piece.Name .. " outside the console safe area " .. describe(r))
		end
	end
	for _, name in { "Banner", "Feedback" } do
		local r = plan[name]
		assert(r.Left >= 0 and r.Right <= W and r.Top >= 0 and r.Bottom <= H, label .. ": " .. name .. " off screen")
	end
	-- Text sizes.
	for name, size in Layout.TextSizes(plan) do
		assert(size >= 11, label .. ": " .. name .. " text " .. size .. " px")
	end
	-- 2026-09-25 (final fix): LEAVE is on every plan, a real touch target on phones.
	assert(plan.Leave, label .. ": no LEAVE button")
	if input == "Touch" then
		assert(plan.Leave.Bottom - plan.Leave.Top >= 44 and plan.Leave.Right - plan.Leave.Left >= 44, label .. ": LEAVE under 44 px")
	end
	-- Touch: the action button and the jump button.
	if input == "Touch" then
		local action, jump = plan.Action, plan.Jump
		assert(action and jump and plan.Ring, label .. ": touch plan without action/ring/jump")
		assert(action.Size >= 56, label .. ": action button " .. action.Size .. " px")
		assert(jump.Left - action.Right >= 30 or action.Left - jump.Right >= 30 or jump.Top - action.Bottom >= 30 or action.Top - jump.Bottom >= 30,
			label .. ": action button within 30 px of the jump button")
		assert(plan.Gauge == nil, label .. ": touch uses the ring, not the bar gauge")
		-- Phones: the podium stays in the left third.
		if math.min(W, viewH) < 600 then
			assert(plan.Podium.Right < 0.35 * W, label .. ": podium right " .. plan.Podium.Right .. " >= 0.35W")
		end
	else
		assert(plan.Gauge and plan.Action == nil and plan.Jump == nil, label .. ": PC/console use the bar gauge")
		assert(plan.Gauge.Right - plan.Gauge.Left >= 0.6 * (plan.Bar.Right - plan.Bar.Left) - 1, label .. ": gauge width")
	end
	-- The podium cards: 2nd, 1st, 3rd; the 1st is the biggest; all inside the podium.
	local cards = plan.Podium.Cards
	assert(cards[1].Place == 2 and cards[2].Place == 1 and cards[3].Place == 3, label .. ": podium order")
	assert(cards[2].Size > cards[1].Size and cards[1].Size == cards[3].Size, label .. ": podium sizes")
	for _, card in cards do
		assert(card.Left >= 0 and card.Right <= plan.Podium.Right - plan.Podium.Left + 0.01 and card.Bottom <= plan.Podium.Bottom - plan.Podium.Top + 0.01,
			label .. ": card outside the podium")
	end
	-- The bar: at least 120 px, centred.
	assert(plan.Bar.Right - plan.Bar.Left >= 120, label .. ": bar too narrow")
	assert(math.abs((plan.Bar.Left + plan.Bar.Right) / 2 - W / 2) <= 1, label .. ": bar not centred")
	return plan
end

-- 1. Every acceptance screen, both top-bar heights.
for _, screen in SCREENS do
	for _, topBar in { 36, 58 } do
		check(screen[1], screen[2], screen[3], topBar, nil)
	end
end
pass("8 screens x 2 top bars: no overlaps (6 px), on screen, console in 5 %, text >= 11 px, action/jump rules, phone podium < 0.35W")

-- 2. A range of odd sizes, so the rules are not tuned to the list only.
local count = 0
for W = 640, 2600, 173 do
	for viewH = 330, 1300, 97 do
		if W >= viewH then
			for _, input in { "Touch", "Keyboard", "Gamepad" } do
				check(W, viewH, input, 58, nil)
				count += 1
			end
		end
	end
end
pass(("%d more landscape screens keep the same rules"):format(count))

-- 3. The player's moved Sprint piece moves the action button when that place is clear, never
--    onto the bar or the jump button.
do
	local W, viewH, topBar = 812, 339, 58
	local H = viewH - topBar
	local auto = Layout.Plan(W, H, "Touch", topBar, {})
	-- Right edge, above the jump button (clear of everything): taken.
	local moved = HudErgonomics.FormatTouchLayout({ S = { X = 0.9, Y = 0.45 } })
	local plan = check(W, viewH, "Touch", topBar, moved)
	assert(plan.ActionMoved == true, "a clear moved Sprint place is used")
	assert(math.abs(plan.Action.X - 0.9 * W) < 2, "the action button follows the saved place")
	-- On the MPH bar: refused, the automatic place stays.
	local onBar = HudErgonomics.FormatTouchLayout({ S = { X = 0.5, Y = 0.8 } })
	local refused = check(W, viewH, "Touch", topBar, onBar)
	assert(refused.ActionMoved ~= true and refused.Action.Left == auto.Action.Left, "a moved place on the bar is refused")
	pass("moved Sprint piece: used when clear, refused on the bar")
end

-- 4. The ring: 36 segments on a 270-degree arc, radius = size/2 + 10.
do
	local plan = Layout.Plan(812, 281, "Touch", 58, {})
	local ring, action = plan.Ring, plan.Action
	assert(ring.Radius == action.Size / 2 + Layout.RingPad and ring.Thickness == 8, "ring radius and thickness")
	local x1, y1 = Layout.RingSegment(1, 36, 10)
	local xn, yn = Layout.RingSegment(36, 36, 10)
	local xm, ym = Layout.RingSegment(18.5, 36, 10)
	assert(x1 < 0 and y1 > 0, "the arc starts lower left")
	assert(xn > 0 and yn > 0, "the arc ends lower right")
	assert(math.abs(xm) < 1e-6 and ym < -9.99, "its middle is straight up")
	pass("ring geometry: lower left -> top -> lower right")
end

-- 5. Lobby button and invite toast.
do
	local phone = Layout.LobbyButton(812, 281, "Touch", 20, 58)
	assert(phone.Right - phone.Left == 104 and phone.Bottom - phone.Top == 40 and phone.Left == 20 and phone.Top == 8, "phone button 104x40 at the sidebar's left, 8 px down")
	local desktop = Layout.LobbyButton(1920, 1022, "Keyboard", nil, 58)
	local w = desktop.Right - desktop.Left
	assert(w == 210 and math.abs((desktop.Bottom - desktop.Top) - w / 2.6) < 1 and desktop.Top == 12, "desktop button 0.11W capped at 210, w/2.6 tall")
	local console = Layout.LobbyButton(1920, 1080, "Gamepad", 10, 0)
	assert(console.Left >= 96 and console.Top >= 54, "console button inside the safe area")
	local toast = Layout.InviteToast(812, 281, "Touch", phone, 58)
	assert(toast.Right - toast.Left == 250 and toast.Bottom - toast.Top == 64 and toast.Top == phone.Bottom + 8, "phone toast 250x64 under the button")
	local big = Layout.InviteToast(1920, 1022, "Keyboard", desktop, 58)
	assert(big.Right - big.Left == 330 and big.Bottom - big.Top == 86, "desktop toast 330x86")
	for _, r in { phone, desktop, console } do
		assert(r.TitleText >= 11 and r.StateText >= 11, "lobby button text >= 11 px")
	end
	assert(toast.TitleText >= 11 and toast.BodyText >= 11, "toast text >= 11 px")
	pass("lobby button (phone 104x40, desktop 0.11W, console safe area) and invite toast sizes")
end

-- 2026-09-26 (owner's phone playtest): real landscape phones. W x H is the whole screen, `top`
-- Roblox's top bar, `side` the notch on each side and `bottom` the home bar (the HUD and the
-- windows use CoreUISafeInsets: their screen is what is left).
local PHONES = {
	{ 667, 375, 58, 0, 0, "iPhone 8" },
	{ 667, 375, 36, 0, 0, "iPhone 8, old top bar" },
	{ 812, 375, 58, 44, 21, "iPhone X / 11 Pro" },
	{ 812, 375, 36, 44, 21, "iPhone X, old top bar" },
	{ 844, 390, 58, 47, 21, "iPhone 12-14" },
	{ 896, 414, 58, 44, 21, "iPhone 11 / XR" },
	{ 932, 430, 58, 59, 21, "iPhone Pro Max" },
	{ 640, 360, 58, 0, 0, "small Android" },
	{ 740, 360, 58, 0, 0, "Android 18.5:9" },
	{ 800, 360, 58, 0, 0, "Android 20:9" },
	{ 915, 412, 58, 0, 0, "Android 20:9 big" },
}
local function room(phone)
	return phone[1] - 2 * phone[4], phone[2] - phone[3] - phone[5]
end

-- 6. The race HUD on those phones: the same rules as above, and nothing that stays on screen
--    for the whole race (bars, podium, ORB readout, LEAVE, the action button) in the middle of
--    the screen where the runner is drawn; nothing that takes taps (the action button, LEAVE)
--    in the thumbstick's corner.
do
	local LASTING = { "Bar", "Labels", "Stamina", "Status", "Podium", "You", "Goal", "Leave", "Action", "Ring" }
	for _, phone in PHONES do
		local W, H = room(phone)
		local label = string.format("%s %dx%d top %d", phone[6], phone[1], phone[2], phone[3])
		-- check() takes the screen under the top bar as viewH - topBar.
		local plan = check(W, H + phone[3], "Touch", phone[3], nil)
		assert(plan.Compact, label .. ": the compact HUD")
		local centre = Layout.Rect(0.3 * W, 0.2 * H, 0.4 * W, 0.42 * H)
		for _, name in LASTING do
			assert(not HudErgonomics.Overlaps(plan[name], centre), label .. ": " .. name .. " " .. describe(plan[name]) .. " covers the middle " .. describe(centre))
		end
		local stick = HudErgonomics.Thumbstick(W, H)
		for _, name in { "Action", "Leave" } do
			assert(not HudErgonomics.Overlaps(plan[name], stick), label .. ": " .. name .. " in the thumbstick's corner")
		end
		-- The countdown number stays above the MPH stack, the podium in the left third.
		assert(plan.Number.Bottom <= plan.Hint.Top - 6, label .. ": the countdown reaches the hint")
		assert(plan.Podium.Right < 0.35 * W and plan.You.Bottom < H / 2, label .. ": the podium outside the left third / below the middle")
	end
	pass(("race HUD on %d real phones (notch, home bar, both top bars): the middle and the thumbstick corner stay clear"):format(#PHONES))
end

-- 7. The windows (RaceResults, RacePanelGui, the Flash's RACE SIGN-UP): on a phone the compact
--    arrangement, at most 84 % of the room's height and 80 % of the screen's height with its
--    header, inside the room (4 px), centred under the top bar, never under 0.8 (the compact
--    arrangements' words are 14 px: 11 px on screen); desktops keep 1:1.
do
	local RaceUiBuilder = require("../src/common/ReplicatedStorage/Shared/RaceUiBuilder")
	local LobbyNpcUi = require("../src/common/ReplicatedStorage/Shared/LobbyNpcUi")
	local WINDOWS = {
		{ "RaceResults", RaceUiBuilder.ResultsSize, RaceUiBuilder.ResultsCompactSize },
		{ "RacePanelGui", RaceUiBuilder.PanelSize, RaceUiBuilder.PanelCompactSize },
		{ "LobbyNpcFlashGui", LobbyNpcUi.DialogSize, LobbyNpcUi.DialogCompactSize },
	}
	local lowest = math.huge
	for _, entry in WINDOWS do
		for _, phone in PHONES do
			local roomW, roomH = room(phone)
			local label = string.format("%s on %s %dx%d top %d", entry[1], phone[6], phone[1], phone[2], phone[3])
			assert(Layout.WindowCompact(phone[1], phone[2], roomW, roomH, true), label .. ": compact")
			local design = RaceUiBuilder.WindowDesign(entry[3], true)
			local fit = Layout.WindowFit(design, roomW, roomH, true, phone[2])
			lowest = math.min(lowest, fit.Scale)
			assert(fit.Scale >= 0.8 and fit.Scale <= 1, label .. ": scale " .. fit.Scale)
			local height = fit.Bottom - fit.Top
			assert(height <= 0.84 * roomH + 0.01, label .. ": taller than 84 % of the room")
			assert(fit.Bottom - fit.HeaderTop <= 0.8 * phone[2] + 0.01, label .. ": window + header over 80 % of the screen")
			assert(fit.HeaderTop >= 4 - 0.01 and fit.Bottom <= roomH - 4 + 0.01 and fit.SideLeft >= 4 - 0.01 and fit.SideRight <= roomW - 4 + 0.01,
				label .. ": outside the room " .. describe(fit))
			-- Centred with its header: as much room above the header as under the window.
			assert(math.abs(fit.HeaderTop - (roomH - fit.Bottom)) < 0.01, label .. ": not centred under the top bar")
			assert(math.abs(fit.OffsetY - design.Header * fit.Scale / 2) < 1e-6, label .. ": OffsetY")
		end
		-- A desktop, a laptop, a tablet (touch, no notch) and a console keep the desktop windows 1:1.
		for _, screen in { { 1920, 1080, 58, false }, { 1366, 768, 58, false }, { 1280, 720, 36, false }, { 1024, 768, 58, true }, { 1920, 1080, 0, false } } do
			local roomW, roomH = screen[1], screen[2] - screen[3]
			assert(not Layout.WindowCompact(screen[1], screen[2], roomW, roomH, screen[4]), entry[1] .. ": wide on " .. screen[1] .. "x" .. screen[2])
			local fit = Layout.WindowFit(RaceUiBuilder.WindowDesign(entry[2], false), roomW, roomH, false, screen[2])
			assert(fit.Scale == 1, entry[1] .. ": 1:1 on " .. screen[1] .. "x" .. screen[2] .. " (" .. fit.Scale .. ")")
			assert(fit.HeaderTop >= 24 and fit.Bottom <= roomH - 24, entry[1] .. ": 24 px margins on " .. screen[1] .. "x" .. screen[2])
		end
		-- A small desktop window takes the compact arrangement too.
		assert(Layout.WindowCompact(900, 500, 900, 442, false), "a 900 x 500 window is compact")
	end
	-- Before 2026-09-26 (the old rule, over the whole screen with the top bar): the results window
	-- on an 812 x 375 phone was 0.72 of 640 x 420, centred at 52 % of the height, its title from
	-- 21 px (under a 58 px top bar).
	local old = math.min(1, math.max(0.3, (812 - 24) / 640), math.max(0.3, (375 - 72) / 420))
	assert(0.52 * 375 - old * (420 / 2 + 32) < 58, "the old results title sat under the top bar")
	pass(("windows: compact on %d phones x 3 windows (scale >= %.2f, <= 84 %% of the room, <= 80 %% of the screen, centred under the top bar), 1:1 on desktops"):format(#PHONES, lowest))
end

print(("ALL PASSED (%d groups)"):format(passed))
