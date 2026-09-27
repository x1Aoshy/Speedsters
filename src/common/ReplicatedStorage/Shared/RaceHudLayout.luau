--!strict
-- ReplicatedStorage/Shared/RaceHudLayout.luau — Update 4 (2026-09-25): where every piece of the
-- race HUD goes on a screen of a given size, in pixels (pure numbers, like HudErgonomics), so
-- audit/test_u4_race_hud_layout can check the rules without a device:
--   * the MPH bar at the bottom centre with its labels row above and the race-stamina bar
--     under it; the charge gauge (PC/console) and its hint above the labels; on touch the
--     gauge is a ring around the CHARGE/BOOST action button, which sits left of Roblox's jump
--     button (HudErgonomics.SprintGap away), where the Sprint button is;
--   * the countdown number in the upper middle ("STARTING: 3s" over it), the status line and
--     the live podium top-left (right edge < 35 % of a phone's width), the ORB readout
--     top-right with the LEAVE button left of it (2026-09-25 final fix: at least 44 px tall on
--     touch; under the readout it took the place players move their Sprint button to), the
--     feedback line ("OUCH! SPIKES") at 30 % of the height;
--   * nothing closer than Gap px to anything else, every text >= MinText px, and on a console
--     everything inside the 5 % safe area.
-- 2026-09-26 (owner): also where the race windows (results, race panel, the Flash's sign-up) go
-- and how big, on phones and desktops (WindowCompact / WindowFit, at the end).
-- W x H is the RaceHud screen (ScreenInsets CoreUISafeInsets: under Roblox's top bar), the
-- same pixels as the Main HUD. Rects are { Left, Top, Right, Bottom } from the top-left corner.
local HudErgonomics: any = if typeof(script) == "Instance"
	then require((script :: any).Parent:WaitForChild("HudErgonomics", 10))
	else require("./HudErgonomics")

local RaceHudLayout = {}

RaceHudLayout.Gap = 6
RaceHudLayout.MinText = 11
-- The touch ring: its centre line runs RingPad px outside the action button, RingThickness wide.
RaceHudLayout.RingPad = 10
RaceHudLayout.RingThickness = 8
RaceHudLayout.RingSegments = 36
-- The ring is a gauge: a 270-degree arc from the lower left, clockwise, to the lower right.
RaceHudLayout.RingStartDegrees = 225
RaceHudLayout.RingSweepDegrees = 270
RaceHudLayout.ActionMin = 60
RaceHudLayout.ActionMax = 84
RaceHudLayout.LeaveTouchMin = 44
-- Podium cards left to right: 2nd, 1st, 3rd.
RaceHudLayout.PodiumOrder = { 2, 1, 3 }
RaceHudLayout.PhonePodiumShare = 0.35
RaceHudLayout.Inputs = { Touch = true, Keyboard = true, Gamepad = true }

export type Rect = { Left: number, Top: number, Right: number, Bottom: number, [string]: any }

local function rect(left: number, top: number, width: number, height: number): Rect
	return { Left = left, Top = top, Right = left + width, Bottom = top + height }
end

local function centred(x: number, y: number, width: number, height: number): Rect
	return rect(x - width / 2, y - height / 2, width, height)
end

local function round(value: number): number
	return math.floor(value + 0.5)
end

RaceHudLayout.Rect = rect
RaceHudLayout.Overlaps = HudErgonomics.Overlaps

-- The screen's margins (console: the 5 % safe area).
function RaceHudLayout.Margins(W: number, H: number, compact: boolean, console: boolean): (number, number)
	if console then
		return math.ceil(W * HudErgonomics.SafeInset), math.ceil(H * HudErgonomics.SafeInset)
	end
	return if compact then 12 else 20, if compact then 6 else 12
end

-- The CHARGE/BOOST button (touch): where the Sprint button is, left of the jump button.
function RaceHudLayout.ActionButton(W: number, H: number): Rect
	local jump = HudErgonomics.JumpButton(W, H)
	local side = math.clamp(round(math.min(W, H) * 0.19), RaceHudLayout.ActionMin, RaceHudLayout.ActionMax)
	local right = jump.Left - HudErgonomics.SprintGap
	local centreY = (jump.Top + jump.Bottom) / 2
	-- Its ring (RingPad + RingThickness outside it) stays on screen too.
	local ringOut = RaceHudLayout.RingPad + RaceHudLayout.RingThickness / 2 + 2
	local top = math.clamp(centreY - side / 2, ringOut, math.max(ringOut, H - side - ringOut))
	local r = rect(right - side, top, side, side)
	r.Size = side
	r.X, r.Y = r.Left + side / 2, r.Top + side / 2
	return r
end

-- The ring around an action button (its outer box).
function RaceHudLayout.RingAround(action: Rect): Rect
	local radius = (action.Right - action.Left) / 2 + RaceHudLayout.RingPad
	local outer = radius + RaceHudLayout.RingThickness / 2
	local r = centred((action.Left + action.Right) / 2, (action.Top + action.Bottom) / 2, outer * 2, outer * 2)
	r.Radius = radius
	r.Thickness = RaceHudLayout.RingThickness
	return r
end

-- Segment k (1..n) of the ring: its centre offset from the ring's centre and its rotation.
function RaceHudLayout.RingSegment(k: number, n: number, radius: number): (number, number, number)
	local fraction = if n > 1 then (k - 1) / (n - 1) else 0
	local degrees = RaceHudLayout.RingStartDegrees - RaceHudLayout.RingSweepDegrees * fraction
	local a = math.rad(degrees)
	-- Screen y grows downwards.
	return math.cos(a) * radius, -math.sin(a) * radius, 90 - degrees
end

export type Options = { layout: any?, keyboard: boolean? }

-- The whole race HUD. `input` is "Touch", "Keyboard" or "Gamepad" (the last input type);
-- `topBar` is Roblox's top bar height (only the compact rule reads it); options.layout is
-- the player's TouchLayout (the Sprint piece "S" moves the action button when that place
-- is clear of everything else).
function RaceHudLayout.Plan(W: number, H: number, input: string?, topBar: number?, options: Options?)
	local opts = options or {}
	local kind = if input and RaceHudLayout.Inputs[input] then input else "Keyboard"
	local touch = kind == "Touch"
	local console = kind == "Gamepad"
	local keyboard = kind == "Keyboard" or opts.keyboard == true
	local compact = HudErgonomics.IsCompact(W, H + (topBar or 0), touch, keyboard)
	local gap = RaceHudLayout.Gap
	local mx, mt = RaceHudLayout.Margins(W, H, compact, console)
	local plan: any = { W = W, H = H, Input = kind, Compact = compact, Console = console, Touch = touch, MarginX = mx, MarginY = mt }

	-- Touch: the action button and its ring first (the bar keeps clear of the ring).
	local action, ring, jump = nil, nil, nil
	if touch then
		jump = HudErgonomics.JumpButton(W, H)
		action = RaceHudLayout.ActionButton(W, H)
		ring = RaceHudLayout.RingAround(action)
	end

	-- The widest centred piece between `top` and `bottom` that keeps Gap px from the ring.
	local function fitWidth(width: number, top: number, bottom: number): number
		if not ring or ring.Top >= bottom + gap or ring.Bottom <= top - gap then
			return width
		end
		if (ring.Left + ring.Right) / 2 >= W / 2 then
			return math.min(width, 2 * (ring.Left - gap - W / 2))
		end
		return math.min(width, 2 * (W / 2 - ring.Right - gap))
	end

	-- The MPH bar, its labels row and the stamina bar, bottom centre.
	local h = math.clamp(round(H * (if compact then 0.088 else 0.06)), 28, 64)
	local w = math.min(11 * h, W * (if compact then 0.50 else 0.42))
	local labelsH = math.max(16, round(0.5 * h))
	local staminaH = math.max(12, round(0.36 * h))
	local centreY = H * (if compact then 0.80 else 0.845)
	local barTop = round(centreY - h / 2)
	-- Never under the bottom margin.
	local over = barTop + h + gap + staminaH - (H - mt)
	if over > 0 then
		barTop -= over
	end
	local fitted = fitWidth(w, barTop - gap - labelsH, barTop + h + gap + staminaH)
	if ring and fitted < 160 then
		-- Nearly square screens: the ring reaches the middle, so the bars go up over it.
		barTop = math.floor(ring.Top - gap - staminaH - gap - h)
		fitted = fitWidth(w, barTop - gap - labelsH, barTop + h + gap + staminaH)
	end
	w = math.max(120, round(fitted))
	local bar = rect(round(W / 2 - w / 2), barTop, w, h)
	bar.TextSize = round(0.62 * h)
	bar.IconSize = round(h * 1.35)
	plan.Bar = bar
	local labels = rect(bar.Left, bar.Top - gap - labelsH, w, labelsH)
	labels.TextSize = math.max(12, labelsH - 4)
	plan.Labels = labels
	local staminaW = round(0.8 * w)
	local stamina = rect(round(W / 2 - staminaW / 2), bar.Bottom + gap, staminaW, staminaH)
	stamina.TextSize = math.max(RaceHudLayout.MinText, staminaH - 1)
	plan.Stamina = stamina

	-- The charge gauge (PC/console) and the hint above it; on touch only the hint.
	local above = labels.Top
	if not touch then
		local gaugeW, gaugeH = round(0.62 * w), math.max(16, round(0.5 * h))
		local gauge = rect(round(W / 2 - gaugeW / 2), above - gap - gaugeH, gaugeW, gaugeH)
		plan.Gauge = gauge
		above = gauge.Top
	end
	local hintH = math.max(18, round(0.55 * h))
	local hintW = round(fitWidth(math.min(W - 2 * mx, math.max(w, 15 * hintH)), above - gap - hintH, above - gap))
	local hint = rect(round(W / 2 - hintW / 2), above - gap - hintH, hintW, hintH)
	hint.TextSize = math.max(12, hintH - 6)
	hint.GlyphSize = hintH
	plan.Hint = hint
	-- The start banner ("PERFECT START! +45%") takes the gauge's and hint's place at GO.
	local bannerBottom = if plan.Gauge then plan.Gauge.Bottom else hint.Bottom
	plan.Banner = rect(hint.Left, hint.Top, hintW, bannerBottom - hint.Top)
	plan.Banner.TextSize = math.max(14, round((bannerBottom - hint.Top) * 0.7))

	-- Top-left: the status line and the live podium.
	local statusH = math.clamp(round(0.055 * H), 16, 40)
	local C = math.clamp(round(0.12 * H), 52, 118)
	local sideC = round(0.82 * C)
	local podiumGap = math.max(4, round(0.08 * C))
	local podiumW = 2 * sideC + C + 2 * podiumGap
	local nameH = math.max(12, round(0.2 * C))
	local rewardH = math.max(14, round(0.26 * C))
	local statusW = math.max(podiumW, math.min(round(statusH * 10), round(W * 0.3)))
	local status = rect(mx, mt, statusW, statusH)
	status.TextSize = math.max(RaceHudLayout.MinText, statusH - 2)
	plan.Status = status
	local podium = rect(mx, status.Bottom + gap, podiumW, C + 2 + rewardH)
	podium.C, podium.Side, podium.NameH, podium.RewardH = C, sideC, nameH, rewardH
	podium.NameText = math.max(RaceHudLayout.MinText, nameH - 2)
	podium.RewardText = math.max(RaceHudLayout.MinText, rewardH - 3)
	podium.BadgeSize = math.max(16, round(0.3 * C))
	podium.BadgeText = math.max(RaceHudLayout.MinText, podium.BadgeSize - 4)
	-- Cards in PodiumOrder (2nd, 1st, 3rd), relative to the podium; the sides sit lower.
	local cards = {}
	local x = 0
	for index, place in RaceHudLayout.PodiumOrder do
		local size = if place == 1 then C else sideC
		local card = rect(x, if place == 1 then 0 else C - size, size, size + 2 + rewardH)
		card.Place, card.Size = place, size
		cards[index] = card
		x += size + podiumGap
	end
	podium.Cards = cards
	plan.Podium = podium
	local youH = math.max(18, round(0.3 * C))
	local you = rect(mx, podium.Bottom + gap, math.clamp(round(1.7 * C), 96, 220), youH)
	you.TextSize = math.max(RaceHudLayout.MinText, youH - 4)
	plan.You = you

	-- Top-right: the ORB readout (label, distance, elapsed time).
	local goalW = math.clamp(round(0.18 * W), 120, 260)
	local lineH = math.clamp(round(0.05 * H), 16, 36)
	local goal = rect(W - mx - goalW, mt, goalW, 3 * lineH)
	goal.LineH = lineH
	goal.TextSize = math.max(RaceHudLayout.MinText, lineH - 2)
	plan.Goal = goal
	-- LEAVE, left of the ORB readout at the top (the middle column narrows to make room).
	local leaveH = math.max(if touch then RaceHudLayout.LeaveTouchMin else 30, lineH + 6)
	local leaveW = math.max(round(leaveH * 2.6), 96)
	local leave = rect(goal.Left - gap - leaveW, mt, leaveW, leaveH)
	leave.TextSize = math.max(12, round(leaveH * 0.4))
	plan.Leave = leave

	-- The middle column: between the podium side and the ORB side, whichever reaches further.
	local sideReach = math.max(math.max(status.Right, podium.Right, you.Right), W - leave.Left)
	local middleW = W - 2 * (sideReach + gap)

	-- The countdown number (upper middle) and "STARTING: 3s" over it, between the top margin
	-- and the hint, inside the middle column.
	local numberH = math.clamp(round(0.30 * H), 96, 300)
	local startingH = math.clamp(round(0.25 * numberH), 18, 48)
	local lowest = hint.Top - gap
	local top = mt
	if middleW < 120 then
		-- A narrow screen: the middle column is too thin, so both go under the corner pieces.
		top = math.max(you.Bottom, goal.Bottom, leave.Bottom) + gap
		middleW = W - 2 * mx
	end
	-- "STARTING: 3s" is about 6.5 of its heights wide: a thin column takes a smaller line.
	startingH = math.max(13, math.min(startingH, math.floor(middleW / 6.5), math.floor((lowest - top) * 0.25)))
	local highest = top + startingH + gap
	numberH = math.max(24, math.min(numberH, lowest - highest, math.floor(middleW / 1.9)))
	local numberW = round(1.9 * numberH)
	local numberTop = math.clamp(round(0.40 * H - numberH / 2), highest, math.max(highest, lowest - numberH))
	local number = rect(round(W / 2 - numberW / 2), numberTop, numberW, numberH)
	number.TextSize = math.min(100, numberH) -- (drawn TextScaled: a TextSize stops at 100)
	plan.Number = number
	local startingW = math.min(W - 2 * mx, startingH * 9, middleW)
	local starting = rect(round(W / 2 - startingW / 2), number.Top - gap - startingH, startingW, startingH)
	starting.TextSize = math.max(RaceHudLayout.MinText, startingH - 2)
	plan.Starting = starting

	-- The feedback line at 30 % of the height, between the podium and the ORB readout.
	local feedbackH = math.clamp(round(0.09 * H), 22, 64)
	local feedbackW = math.max(120, math.min(0.6 * W, W - 2 * sideReach - 2 * gap))
	local feedback = centred(W / 2, 0.30 * H, feedbackW, feedbackH)
	feedback.TextSize = math.max(14, feedbackH - 6)
	plan.Feedback = feedback

	-- Touch: the action button, its ring and the jump button; a moved Sprint piece takes the
	-- action button along when that place is clear of every other piece.
	if touch and action and ring then
		local custom = HudErgonomics.CustomPiece(opts.layout, "S", W, H, action.Size, action.Size, true)
		if custom then
			local customAction = rect(custom.Left, custom.Top, action.Size, action.Size)
			customAction.Size = action.Size
			customAction.X, customAction.Y = custom.X, custom.Y
			local customRing = RaceHudLayout.RingAround(customAction)
			local clear = customRing.Left >= 0 and customRing.Top >= 0 and customRing.Right <= W and customRing.Bottom <= H
				and not HudErgonomics.Overlaps(customAction, jump, 30)
			for _, name in { "Bar", "Labels", "Stamina", "Hint", "Number", "Starting", "Status", "Podium", "You", "Goal", "Leave" } do
				if clear and HudErgonomics.Overlaps(customRing, plan[name], gap) then
					clear = false
				end
			end
			if clear and not HudErgonomics.Overlaps(customRing, jump, gap) then
				action, ring = customAction, customRing
				plan.ActionMoved = true
			end
		end
		action.TextSize = math.max(12, round(action.Size * 0.2))
		plan.Action = action
		plan.Ring = ring
		plan.Jump = jump
	end
	return plan
end

-- The pieces that may never touch (Gap px), for the tests and a debug overlay.
function RaceHudLayout.Pieces(plan: any): { { Name: string, Rect: Rect } }
	local list = {}
	for _, name in { "Bar", "Labels", "Stamina", "Gauge", "Hint", "Number", "Starting", "Status", "Podium", "You", "Goal", "Leave", "Ring", "Action", "Jump" } do
		if plan[name] then
			table.insert(list, { Name = name, Rect = plan[name] })
		end
	end
	return list
end

-- Every text size the plan asks for (name -> px).
function RaceHudLayout.TextSizes(plan: any): { [string]: number }
	local sizes = {}
	for _, name in { "Bar", "Labels", "Stamina", "Hint", "Banner", "Status", "You", "Goal", "Leave", "Number", "Starting", "Feedback", "Action" } do
		local r = plan[name]
		if r and r.TextSize then
			sizes[name] = r.TextSize
		end
	end
	if plan.Podium then
		sizes.PodiumName = plan.Podium.NameText
		sizes.PodiumReward = plan.Podium.RewardText
		sizes.PodiumBadge = plan.Podium.BadgeText
	end
	return sizes
end

----------------------------------------------------------------------
-- Lobby: the RACE button (top-left) and the invite toast under it
----------------------------------------------------------------------
-- `sidebarLeft` is Mainhud.LeftSideBar's left edge (nil: the margin).
function RaceHudLayout.LobbyButton(W: number, H: number, input: string?, sidebarLeft: number?, topBar: number?): Rect
	local touch = input == "Touch"
	local console = input == "Gamepad"
	local compact = HudErgonomics.IsCompact(W, H + (topBar or 0), touch, input == "Keyboard")
	local phone = touch and math.min(W, H + (topBar or 0)) < 600
	local width, height
	if phone then
		width, height = 104, 40
	else
		width = math.clamp(round(0.11 * W), 150, 210)
		height = round(width / 2.6)
	end
	local left = sidebarLeft or (if compact then 12 else 20)
	local top = if console then math.ceil(H * HudErgonomics.SafeInset) elseif compact then 8 else 12
	if console then
		left = math.max(left, math.ceil(W * HudErgonomics.SafeInset))
	end
	local r = rect(math.max(4, left), top, width, height)
	r.TitleText = math.max(12, round(height * 0.42))
	r.StateText = math.max(RaceHudLayout.MinText, round(height * 0.3))
	r.Phone = phone
	return r
end

function RaceHudLayout.InviteToast(W: number, H: number, input: string?, button: Rect, topBar: number?): Rect
	local phone = input == "Touch" and math.min(W, H + (topBar or 0)) < 600
	local width, height = if phone then 250 else 330, if phone then 64 else 86
	width = math.min(width, W - button.Left - 8)
	local r = rect(button.Left, button.Bottom + 8, width, height)
	r.TitleText = math.max(12, round(height * 0.28))
	r.BodyText = math.max(RaceHudLayout.MinText, round(height * 0.19))
	r.Phone = phone
	return r
end

----------------------------------------------------------------------
-- Windows: RaceResults, RacePanelGui and the Flash's RACE SIGN-UP
----------------------------------------------------------------------
-- 2026-09-26 (owner, phone playtest: "when I win the race the results UI is very big on the
-- phone; the race sign-up is too big"): on an 812 x 375 phone the results window came out
-- 462 x 303 px, 81 % of the screen's height (87 % with its title, which started at y = 20,
-- under Roblox's 58 px top bar), its podium words 8 px; the sign-up 455 x 303 px, the race
-- panel 474 x 303 px (their words 7-12 px). Now 447 x 249, 470 x 249 and 558 x 249 px there
-- (66 % of the height), every word 11 px or more. The three windows sit in the room under
-- the top bar and inside the notch (their ScreenGuis use CoreUISafeInsets: W x H here is that
-- room), the window and its header (title, icon, close) together in its middle. On a phone
-- (WindowCompact) they take the share the Index, the Backpack and the Quests take there
-- (MenuPanelLayout.PhoneFit: at most 84 % of the room's height, 94 % of its width, the header
-- whole inside it with 4 px to spare) and never more than 80 % of the screen's height with
-- the header, in their compact arrangement (RaceUiBuilder / LobbyNpcUi Arrange*: the same
-- pieces, denser, texts and buttons sized for that scale); elsewhere the desktop arrangement,
-- never bigger than designed, 24 px from the room's edges.
RaceHudLayout.WindowPhoneHeightShare = 0.84 -- MenuPanelLayout.PhoneHeightShare
RaceHudLayout.WindowPhoneWidthShare = 0.94 -- MenuPanelLayout.PhoneWidthShare
RaceHudLayout.WindowPhoneMargin = 4 -- MenuPanelLayout.PhoneMargin
RaceHudLayout.WindowPhoneViewShare = 0.8 -- window + header, of the whole screen's height
-- The compact arrangements are drawn at most this big: their 14 px words come out ~12.6 px,
-- and a bigger phone (the same points, a bigger screen) shows them no bigger, just more room.
RaceHudLayout.WindowPhoneMaxScale = 0.9
RaceHudLayout.WindowMargin = 24
RaceHudLayout.WindowMinScale = 0.3

-- The compact arrangement: a phone (touch, shorter side under 600 px, LobbyButton's rule) or
-- any room too small for the desktop windows.
function RaceHudLayout.WindowCompact(viewX: number, viewY: number, roomW: number, roomH: number, touch: boolean?): boolean
	return (touch == true and math.min(viewX, viewY) < 600) or roomH < 480 or roomW < 680
end

export type WindowDesign = { Width: number, Height: number, Header: number?, Side: number? }

-- Where a window of `design` (its size, how far its header stands above its top edge and past
-- its sides, all in design px) goes in a `roomW` x `roomH` room: its rect in the room's pixels,
-- Scale (its UIScale), HeaderTop, and OffsetY (its centre below the room's middle: the header
-- counts, so window and header together sit in the middle). `viewY` is the whole screen's
-- height (the phone cap).
function RaceHudLayout.WindowFit(design: WindowDesign, roomW: number, roomH: number, compact: boolean, viewY: number?): Rect
	local w, h = design.Width, design.Height
	local over, side = math.max(0, design.Header or 0), math.max(0, design.Side or 0)
	local scale
	if compact then
		local m = RaceHudLayout.WindowPhoneMargin
		scale = math.min(
			RaceHudLayout.WindowPhoneMaxScale,
			RaceHudLayout.WindowPhoneHeightShare * roomH / h,
			RaceHudLayout.WindowPhoneWidthShare * roomW / (w + 2 * side),
			(roomH - 2 * m) / (h + over),
			(roomW - 2 * m) / (w + 2 * side),
			RaceHudLayout.WindowPhoneViewShare * (viewY or math.huge) / (h + over)
		)
	else
		local m = RaceHudLayout.WindowMargin
		scale = math.min(1, (roomW - 2 * m) / (w + 2 * side), (roomH - 2 * m) / (h + over))
	end
	scale = math.max(RaceHudLayout.WindowMinScale, scale)
	local width, height = w * scale, h * scale
	local centreY = (roomH + over * scale) / 2
	local r = rect(roomW / 2 - width / 2, centreY - height / 2, width, height)
	r.Scale = scale
	r.Compact = compact
	r.HeaderTop = r.Top - over * scale
	r.SideLeft, r.SideRight = r.Left - side * scale, r.Right + side * scale
	r.OffsetY = over * scale / 2
	return r
end

return RaceHudLayout
