-- HudErgonomics.luau
-- Where the Main HUD's touch and console pieces go on a screen of a given size, in pixels,
-- so the rules can be checked without a device (audit/test_ui_ergonomics):
--
--   * the touch Sprint button: a 46-54 px circle in the right thumb's reach, left of
--     Roblox's jump button, far enough from it that a jump does not land on it, clear of
--     the thumbstick and of the level and stamina bars;
--   * the Starter Pack offer (top right) and the x2 Speed / x2 Victory badges: on phones
--     the right edge is one column, top to bottom: the Starter Pack, the badges, the
--     speedometer, Roblox's jump button, sized to fit the screen's height, with the boost
--     cards beside the speedometer; the top middle of the screen stays clear, for the
--     track. On bigger screens the badges keep the designer's column under the pack;
--   * the console's safe zone: nothing within 5% of the TV's edges;
--   * the player's own touch layout ("Move controls" in Settings, UI/TouchLayoutEditor):
--     Sprint, the ability buttons and the stamina bar where the player dragged them, kept
--     on screen and off the jump button and the thumbstick (audit/test_opt6_touch_layout);
--   * Superman's Heat Vision button: a thumb's width (HeatClearance) from Sprint, the Burst
--     button, the jump button and the thumbstick, automatic or moved (audit/test_u4_ui_cleanup);
--   * the side menu (Mainhud.LeftSideBar): the designer's two-column grid, one more row for
--     each two buttons added at runtime (SideBarCells).
--
-- Only numbers: the controllers turn them into UDim2s. Rects are { Left, Top, Right,
-- Bottom } in pixels from the screen's top-left corner.

local HudErgonomics = {}

HudErgonomics.SafeInset = 0.05
HudErgonomics.SprintMin = 46
HudErgonomics.SprintMax = 54
-- Between Sprint and Roblox's jump button. At 14 px (2 mm on a phone) the jumping thumb kept
-- landing on Sprint, which is a toggle. 36 px puts Sprint's near edge 71 px from the jump
-- button's centre on a phone, twice the jump button's own half-width.
HudErgonomics.SprintGap = 36
-- ...never less than this, where a screen is too narrow for the whole gap (SprintButton):
-- there Sprint may cover the end of the level bar rather than come nearer the jump.
HudErgonomics.SprintGapMin = 30
-- The designer's centre bars (Mainhud.LevelProgressBar and Mainhud.SpeedsterBar): their
-- centre's height, their scale box and their shape (both keep 13.74:1 inside the box).
-- Sprint keeps this far from their right ends.
HudErgonomics.CentreBars = {
	{ Y = 0.775, Width = 0.4938687, Height = 0.06384879, Aspect = 13.743902 },
	{ Y = 0.857061, Width = 0.4084186, Height = 0.08899189, Aspect = 13.743902 },
}
HudErgonomics.CentreBarGap = 4
-- The designer's badge (Rightbuttons' 2xSpeed / 2xVictory): its shape, its share of the
-- column's height, the list's padding, and how far its price tag hangs below it.
HudErgonomics.BadgeAspect = 3.0151515
HudErgonomics.BadgeHeightShare = 0.188714
HudErgonomics.BadgePaddingShare = 0.12
HudErgonomics.BadgeTagOverhang = 0.36
-- The designer's column (Rightbuttons): centre, size and shape.
HudErgonomics.Column = { X = 0.91146237, Y = 0.53125954, Width = 0.16742837, Height = 0.45140797, Aspect = 0.6590389 }
-- The Starter Pack offer's box, before its responsive scale.
HudErgonomics.StarterPackSize = { 190, 202 }
-- Below Roblox's top bar (its GuiInset, where the TopbarPlus icons sit too) by this much.
HudErgonomics.TopBarGap = 6
-- The phone column: badge heights and the speedometer's scale it may use, and its gaps.
HudErgonomics.ColumnBadgeHeight = { Min = 24, Max = 40 }
HudErgonomics.ColumnSpeedometerScale = { Min = 0.5, Reserve = 0.62, Max = 0.88 }
HudErgonomics.ColumnGap = 8
-- Between the Starter Pack and the badges under it (the brief asks for 12-16 px).
HudErgonomics.ColumnPackGap = 12
-- Between the speedometer and the jump button under it (2026-09-25, M50): a jump tap near
-- the gauge's lower edge changed the speed mode instead.
HudErgonomics.ColumnJumpGap = 24
-- The designer's speedometer (WalkSpeedSelectorHUD.SelectorHolder, in the same screen as the
-- Main HUD): the holder, anchored at its top-right corner, and the gauge button drawn above
-- its top edge, with the speed read-out over the button's lower half.
HudErgonomics.Speedometer = {
	HolderX = 0.97233826,
	HolderWidth = 0.26404363,
	HolderHeight = 0.6152689,
	ButtonX = 0.76666665,
	ButtonY = -0.10280374,
	ButtonWidth = 0.6238095,
	ButtonHeight = 0.38785046,
	ButtonAspect = 1.5783132,
	ValueY = -0.0513671,
	ValueHeight = 0.14018692,
}
-- The boost cards on phones (Mainhud.ActiveBuffsHolder): up to three 44 px cards, 5 px
-- apart, in a 48 px row, at the phone's 0.7 scale.
HudErgonomics.BoostCards = { Count = 3, Side = 44, Padding = 5, Height = 48, Scale = 0.7 }

local function rect(left: number, top: number, width: number, height: number)
	return { Left = left, Top = top, Right = left + width, Bottom = top + height }
end

-- True when two rects share any point, or come closer than `margin` pixels.
function HudErgonomics.Overlaps(a, b, margin: number?): boolean
	local m = margin or 0
	return a.Left < b.Right + m and b.Left < a.Right + m and a.Top < b.Bottom + m and b.Top < a.Bottom + m
end

-- A scale position (0..1 across the screen) moved into the console's safe area: 0 becomes
-- 5% and 1 becomes 95%, so everything placed at an edge ends 5% inside the TV.
function HudErgonomics.SafeScale(scale: number, inset: number?): number
	local i = inset or HudErgonomics.SafeInset
	return i + scale * (1 - 2 * i)
end

-- The Main HUD's compact (phone) layout: its own rule for "mobile".
function HudErgonomics.IsCompact(width: number, height: number, touch: boolean, keyboard: boolean): boolean
	return (touch and not keyboard) or height <= 650 or (width <= 950 and touch)
end

----------------------------------------------------------------------
-- Touch controls
----------------------------------------------------------------------
-- Roblox's own jump button (PlayerModule's TouchJump): 70 px on small screens, 120 px
-- otherwise, near the bottom-right corner.
function HudErgonomics.JumpButton(width: number, height: number)
	local small = math.min(width, height) <= 500
	local size = if small then 70 else 120
	local left = width - (size * 1.5 - 10)
	local top = if small then height - size - 20 else height - size * 1.75
	local r = rect(left, top, size, size)
	r.Size = size
	return r
end

-- The dynamic thumbstick's area: the left 40% of the screen's lower two thirds.
function HudErgonomics.Thumbstick(width: number, height: number)
	return rect(0, height / 3, width * 0.4, height * 2 / 3)
end

-- The level and stamina bars at the designer's places on a `width` x `height` Main HUD screen.
function HudErgonomics.CentreBarRects(width: number, height: number)
	local rects = {}
	for index, bar in HudErgonomics.CentreBars do
		local w = math.min(bar.Width * width, bar.Height * height * bar.Aspect)
		local h = w / bar.Aspect
		rects[index] = rect(width / 2 - w / 2, bar.Y * height - h / 2, w, h)
	end
	return rects
end

-- The Sprint button: a square (drawn round) of 46-54 px left of the jump button and level
-- with it, SprintGap px away: near enough for the right thumb, too far to be hit by a jump.
-- Screen here is the Main HUD's (and the touch controls'): below Roblox's top bar.
function HudErgonomics.SprintButton(width: number, height: number)
	local jump = HudErgonomics.JumpButton(width, height)
	local side = math.clamp(math.floor(math.min(width, height) * 0.13 + 0.5), HudErgonomics.SprintMin, HudErgonomics.SprintMax)
	local right = jump.Left - HudErgonomics.SprintGap
	local centreY = (jump.Top + jump.Bottom) / 2
	-- The camera can report a 1 px viewport while the top bar is already measured.
	-- Keep clamp's bounds valid until the real screen size arrives on the next layout.
	local maxTop = math.max(8, height - side - 8)
	local top = math.clamp(centreY - side / 2, 8, maxTop)
	-- 4:3 tablets and the narrowest phones: the whole gap would put Sprint on the right end of
	-- the level or stamina bar. There it gives some of the gap back, never under SprintGapMin.
	for _, bar in HudErgonomics.CentreBarRects(width, height) do
		if bar.Top < top + side and top < bar.Bottom then
			right = math.max(right, bar.Right + HudErgonomics.CentreBarGap + side)
		end
	end
	right = math.min(right, jump.Left - HudErgonomics.SprintGapMin)
	local r = rect(right - side, top, side, side)
	r.Size = side
	r.X = r.Left + side / 2
	r.Y = r.Top + side / 2
	return r
end

----------------------------------------------------------------------
-- The Starter Pack and the x2 badges
----------------------------------------------------------------------
-- The Starter Pack offer's box (StarterPackOffer.client): its right-top corner and scale.
-- `safe` keeps it inside the console's safe zone; `topBar` is the height of Roblox's top bar
-- (GuiService:GetGuiInset().Y), which it stays under, clear of the top bar's icons.
function HudErgonomics.StarterPack(width: number, height: number, touch: boolean, safe: boolean?, topBar: number?)
	local fit = math.min(width / 1920, height / 1080)
	local scale, right, top
	if touch then
		local phone = math.min(width, height) < 600
		scale = math.clamp(fit * 0.94, 0.36, 0.82)
		right, top = width - 8, if phone then 28 else 50
	else
		scale = math.clamp(width / 1920, 0.66, 0.90)
		right, top = width - 28, 64
	end
	if safe then
		right = math.min(right, width * (1 - HudErgonomics.SafeInset))
		top = math.max(top, height * HudErgonomics.SafeInset)
	end
	top = math.max(top, (topBar or 0) + HudErgonomics.TopBarGap)
	local w, h = HudErgonomics.StarterPackSize[1] * scale, HudErgonomics.StarterPackSize[2] * scale
	local r = rect(right - w, top, w, h)
	r.Scale = scale
	r.Phone = touch and math.min(width, height) < 600
	return r
end

-- Where the x2 badges go. Compact (phones): stacked under the Starter Pack in the right-edge
-- column (HudErgonomics.PhoneColumn, whose plan is `Column`). Otherwise the designer's column
-- (Rightbuttons at its authored place and size), which on every desktop shape sits under
-- the Starter Pack. Returns the container (Rightbuttons) and each badge's rect, its price
-- tag included; `count` is how many badges are showing (1 or 2). Both stay under Roblox's
-- top bar (`topBar` px tall).
function HudErgonomics.Badges(width: number, height: number, touch: boolean, keyboard: boolean, safe: boolean?, count: number?, topBar: number?)
	local shown = math.max(1, count or 2)
	local pack = HudErgonomics.StarterPack(width, height, touch, safe, topBar)
	local badges = {}
	if HudErgonomics.IsCompact(width, height, touch, keyboard) then
		local plan = HudErgonomics.PhoneColumn(width, height, touch, safe, shown, topBar)
		return {
			Compact = true,
			Pack = pack,
			Badges = plan.Badges,
			BadgeWidth = plan.BadgeWidth,
			BadgeHeight = plan.BadgeHeight,
			Padding = plan.Padding,
			-- Rightbuttons, anchored at its top-right corner (screen pixels).
			Container = plan.Container,
			Column = plan,
		}
	end
	local column = HudErgonomics.Column
	local x, y = column.X, column.Y
	if safe then
		x, y = HudErgonomics.SafeScale(x), HudErgonomics.SafeScale(y)
	end
	-- The column fits inside its scale box, keeping its shape (UIAspectRatioConstraint).
	local columnHeight = math.min(column.Height * height, column.Width * width / column.Aspect)
	local columnWidth = columnHeight * column.Aspect
	local left = x * width - columnWidth / 2
	local top = y * height - columnHeight / 2
	local badgeHeight = columnHeight * HudErgonomics.BadgeHeightShare
	local badgeWidth = badgeHeight * HudErgonomics.BadgeAspect
	local padding = columnHeight * HudErgonomics.BadgePaddingShare
	for index = 1, shown do
		local badgeTop = top + (index - 1) * (badgeHeight + padding)
		local r = rect(left + (columnWidth - badgeWidth) / 2, badgeTop, badgeWidth, badgeHeight * (1 + HudErgonomics.BadgeTagOverhang))
		r.BadgeHeight = badgeHeight
		badges[index] = r
	end
	return {
		Compact = false,
		Pack = pack,
		Badges = badges,
		BadgeWidth = badgeWidth,
		BadgeHeight = badgeHeight,
		Container = { X = x, Y = y },
	}
end

----------------------------------------------------------------------
-- The phone column
----------------------------------------------------------------------
-- The speedometer on a `width` x `hudHeight` Main HUD screen at `scale`, its holder's top at
-- `holderTop`: the rect it draws (the gauge and its read-out). Main HUD pixels.
function HudErgonomics.SpeedometerRect(width: number, hudHeight: number, scale: number, holderTop: number)
	local spec = HudErgonomics.Speedometer
	local holderWidth, holderHeight = spec.HolderWidth * width, spec.HolderHeight * hudHeight
	local buttonWidth = math.min(spec.ButtonWidth * holderWidth, spec.ButtonHeight * holderHeight * spec.ButtonAspect)
	local buttonHeight = buttonWidth / spec.ButtonAspect
	local right = spec.HolderX * width
	local centreX = right - (1 - spec.ButtonX) * holderWidth * scale
	local centreY = holderTop + spec.ButtonY * holderHeight * scale
	local bottom = math.max(centreY + buttonHeight * scale / 2, holderTop + (spec.ValueY + spec.ValueHeight / 2) * holderHeight * scale)
	local r = rect(centreX - buttonWidth * scale / 2, centreY - buttonHeight * scale / 2, buttonWidth * scale, bottom - (centreY - buttonHeight * scale / 2))
	r.ButtonHeight = buttonHeight
	r.HolderHeight = holderHeight
	return r
end

-- Phones (compact screens): the right edge as one column, top to bottom: the Starter Pack,
-- the x2 badges stacked, the speedometer, then (touch) Roblox's jump button. The badges get
-- 24-40 px of height and the speedometer a 0.5-0.88 scale, whatever the screen's height
-- leaves them; the boost cards stand left of the speedometer. The middle of the screen's top
-- is left clear. Everything is in screen pixels (the Starter Pack's screen, under which
-- Roblox's top bar is `topBar` tall); the Main HUD's pixels are these minus the top bar.
function HudErgonomics.PhoneColumn(width: number, height: number, touch: boolean, safe: boolean?, count: number?, topBar: number?)
	local shown = math.max(1, count or 2)
	local inset = topBar or 0
	local hudHeight = height - inset
	local pack = HudErgonomics.StarterPack(width, height, touch, safe, topBar)
	local gap = HudErgonomics.ColumnGap
	local limits, speedo = HudErgonomics.ColumnBadgeHeight, HudErgonomics.ColumnSpeedometerScale
	local jump = if touch then HudErgonomics.JumpButton(width, hudHeight) else nil
	local sprint = if touch then HudErgonomics.SprintButton(width, hudHeight) else nil
	-- Screen pixels from the top of the badges to the bottom of the speedometer.
	local top = pack.Bottom + HudErgonomics.ColumnPackGap
	local floor = if jump then jump.Top + inset - HudErgonomics.ColumnJumpGap else height - 16 - gap
	local room = floor - top
	-- A column of `shown` badges `h` tall: each price tag hangs 0.36 h under its badge.
	local function columnHeight(h)
		local overhang = h * HudErgonomics.BadgeTagOverhang
		return shown * h + (shown - 1) * (overhang + 4) + overhang
	end
	local reference = HudErgonomics.SpeedometerRect(width, hudHeight, 1, 0)
	local speedoHeight = reference.Bottom - reference.Top
	local badgeHeight = limits.Min
	for h = limits.Max, limits.Min, -1 do
		if columnHeight(h) + gap + speedoHeight * speedo.Reserve <= room then
			badgeHeight = h
			break
		end
	end
	local scale = math.clamp((room - columnHeight(badgeHeight) - gap) / speedoHeight, speedo.Min, speedo.Max)
	local badgeWidth = math.floor(badgeHeight * HudErgonomics.BadgeAspect + 0.5)
	local padding = badgeHeight * HudErgonomics.BadgeTagOverhang + 4
	-- The badges: right-aligned with the Starter Pack, stacked under it.
	local right = pack.Right
	local badges = {}
	for index = 1, shown do
		local badgeTop = top + (index - 1) * (badgeHeight + padding)
		local r = rect(right - badgeWidth, badgeTop, badgeWidth, badgeHeight * (1 + HudErgonomics.BadgeTagOverhang))
		r.BadgeHeight = badgeHeight
		badges[index] = r
	end
	local badgesBottom = badges[shown].Bottom
	-- The speedometer: its gauge's top just under the badges.
	local probe = HudErgonomics.SpeedometerRect(width, hudHeight, scale, 0)
	local holderTop = (badgesBottom + gap - inset) - probe.Top
	local gauge = HudErgonomics.SpeedometerRect(width, hudHeight, scale, holderTop)
	local gaugeOnScreen = rect(gauge.Left, gauge.Top + inset, gauge.Right - gauge.Left, gauge.Bottom - gauge.Top)
	-- The boost cards: a row ending left of the speedometer, level with its middle.
	local buffs = { Right = gauge.Left - 10, Y = (gauge.Top + gauge.Bottom) / 2 }
	local function onScreen(r)
		return r and rect(r.Left, r.Top + inset, r.Right - r.Left, r.Bottom - r.Top) or nil
	end
	return {
		Pack = pack,
		Badges = badges,
		BadgeWidth = badgeWidth,
		BadgeHeight = badgeHeight,
		Padding = padding,
		Container = { Right = right, Top = top, Width = badgeWidth, Height = columnHeight(badgeHeight) },
		Speedometer = { Scale = scale, HolderTop = holderTop, Rect = gaugeOnScreen },
		-- Main HUD pixels (the boost cards' row: its right end and middle).
		Buffs = buffs,
		Jump = onScreen(jump),
		Sprint = onScreen(sprint),
		TopBar = inset,
	}
end

-- What the ability buttons keep clear of on a compact screen: the phone column's speedometer
-- and its boost cards (all three), in Main HUD pixels; nothing on a bigger screen. `width` x
-- `height` is the whole screen (the camera's viewport) and `topBar` Roblox's top bar.
function HudErgonomics.TouchNeighbours(width: number, height: number, keyboard: boolean, topBar: number)
	if not HudErgonomics.IsCompact(width, height, true, keyboard) then
		return {}
	end
	local column = HudErgonomics.PhoneColumn(width, height, true, false, 2, topBar)
	local gauge = column.Speedometer.Rect
	local cards = HudErgonomics.BoostCards
	local cardsWidth = (cards.Count * cards.Side + (cards.Count - 1) * cards.Padding) * cards.Scale
	local cardsHeight = cards.Height * cards.Scale
	return {
		rect(gauge.Left, gauge.Top - topBar, gauge.Right - gauge.Left, gauge.Bottom - gauge.Top),
		rect(column.Buffs.Right - cardsWidth, column.Buffs.Y - cardsHeight / 2, cardsWidth, cardsHeight),
	}
end

----------------------------------------------------------------------
-- The side menu (Mainhud.LeftSideBar)
----------------------------------------------------------------------
-- The designer's frame (centre, scale box, its 0.738 shape) and grid (cells 0.6 x 0.35 of
-- the frame made square, padding 0.05 x 0.03, filled left to right from the top-left). The
-- frame holds the first rows; the rest hang below it, as the designer's fourth row did.
HudErgonomics.SideBar = {
	X = 0.07451798,
	Y = 0.44583333,
	Width = 0.13652945,
	Height = 0.3287037,
	Aspect = 0.7380282,
	CellX = 0.6,
	CellY = 0.35,
	PadX = 0.05,
	PadY = 0.03,
}

-- The cells of `count` buttons on a `width` x `hudHeight` Main HUD screen, in grid order
-- (Main HUD pixels), with the grid's column count; `safe` moves the frame into a console's
-- safe zone as MainHUDController does. `place` (SideBarPlan's, 2026-09-26): the frame's centre
-- X, Y in scale of the screen and its Scale (cells and gaps alike), instead of the designer's.
function HudErgonomics.SideBarCells(width: number, hudHeight: number, count: number, safe: boolean?, place: any?)
	local spec = HudErgonomics.SideBar
	local x, y = spec.X, spec.Y
	if safe then
		x, y = HudErgonomics.SafeScale(x), HudErgonomics.SafeScale(y)
	end
	local scale = 1
	if type(place) == "table" then
		x, y, scale = place.X or x, place.Y or y, place.Scale or 1
	end
	local frameWidth = math.min(spec.Width * width, spec.Height * hudHeight * spec.Aspect) * scale
	local frameHeight = frameWidth / spec.Aspect
	local cell = math.min(spec.CellX * frameWidth, spec.CellY * frameHeight)
	local padX, padY = spec.PadX * frameWidth, spec.PadY * frameHeight
	local columns = math.max(1, math.floor((frameWidth + padX) / (cell + padX) + 1e-6))
	local left, top = x * width - frameWidth / 2, y * hudHeight - frameHeight / 2
	local cells = {}
	for index = 1, count do
		local column, row = (index - 1) % columns, (index - 1) // columns
		cells[index] = rect(left + column * (cell + padX), top + row * (cell + padY), cell, cell)
	end
	return { Cells = cells, Columns = columns, Cell = cell, Frame = rect(left, top, frameWidth, frameHeight) }
end

-- 2026-09-26 (owner: "the new Titles button covers the Rebirth icon"). The designer's Rebirth
-- and Wins counters (Mainhud["Rebith/trof"]) hang far below their frame, at the bottom-left
-- right under the side menu: the frame (centre, scale box, 0.726 shape) and the top of its
-- highest piece (the Rebirth icon, centre 2.436 minus half its 0.2915), as shares of its height.
HudErgonomics.Counters = { X = 0.075299636, Y = 0.22710848, Width = 0.12975508, Height = 0.3175926, Aspect = 0.7259475, Top = 2.2903474 }
-- Kept between the side menu's last row and the counters, and between the RACE button (top-left,
-- RaceHudLayout.LobbyButton) and the menu's first row.
HudErgonomics.SideBarGap = 6
-- The side menu never shrinks below this share of the designer's cells to make room.
HudErgonomics.SideBarMinScale = 0.7

-- The counters' top (the Rebirth icon's), in Main HUD pixels; `safe` as the Main HUD moves them.
function HudErgonomics.CountersTop(width: number, hudHeight: number, safe: boolean?): number
	local spec = HudErgonomics.Counters
	local y = if safe then HudErgonomics.SafeScale(spec.Y) else spec.Y
	local frameWidth = math.min(spec.Width * width, spec.Height * hudHeight * spec.Aspect)
	local frameHeight = frameWidth / spec.Aspect
	return y * hudHeight - frameHeight / 2 + spec.Top * frameHeight
end

-- Where the side menu's frame goes with `count` buttons showing (2026-09-26). A ninth button
-- (Titles) opened a fifth row right on the Rebirth counter, on every screen; on 4:3 tablets the
-- designer's fourth row already touched it. The frame keeps the designer's place while every
-- row ends SideBarGap above the counters and starts below `topRoom` (Main HUD pixels: the RACE
-- button's bottom plus SideBarGap; on a console never above the safe zone); else it moves up
-- (or, on very wide short screens, down) between the two, and when they leave too little room
-- it shrinks (cells and gaps alike, its left edge kept, not under SideBarMinScale) to fit.
-- Returns SideBarCells' table plus X, Y (the frame's centre, in scale of the screen: its
-- Position), Scale (of its Size) and Moved.
function HudErgonomics.SideBarPlan(width: number, hudHeight: number, count: number, safe: boolean?, topRoom: number?)
	local designer = HudErgonomics.SideBarCells(width, hudHeight, count, safe)
	local spec = HudErgonomics.SideBar
	local frame = designer.Frame
	local frameWidth, frameHeight = frame.Right - frame.Left, frame.Bottom - frame.Top
	local rows = math.max(1, math.ceil(math.max(count, 1) / designer.Columns))
	local span = rows * designer.Cell + (rows - 1) * spec.PadY * frameHeight
	local floor = HudErgonomics.CountersTop(width, hudHeight, safe) - HudErgonomics.SideBarGap
	local ceiling = math.max(topRoom or 0, if safe then math.ceil(hudHeight * HudErgonomics.SafeInset) else 0)
	local top, scale = frame.Top, 1
	if top + span > floor then
		top = floor - span
	end
	-- (Very wide, short screens: the designer's first row can meet the RACE button instead.)
	top = math.max(top, ceiling)
	if top + span > floor then
		scale = math.max(HudErgonomics.SideBarMinScale, (floor - top) / span)
	end
	local x = (frame.Left + frameWidth * scale / 2) / width
	local y = (top + frameHeight * scale / 2) / hudHeight
	local plan = HudErgonomics.SideBarCells(width, hudHeight, count, safe, { X = x, Y = y, Scale = scale })
	plan.X, plan.Y, plan.Scale = x, y, scale
	plan.Moved = math.abs(top - frame.Top) > 1e-6 or scale ~= 1
	return plan
end

----------------------------------------------------------------------
-- The chat window on phones (2026-09-26)
----------------------------------------------------------------------
-- A tester's phone: the open chat window (Roblox's, top-left) covered the side menu, Ability,
-- Shop, Index and Rebirth under it. The side menu cannot go lower (the Rebirth and Wins
-- counters, the thumbstick), so on compact touch screens the chat window stands at the top
-- CENTRE (TextChatService.ChatWindowConfiguration's alignment): the one strip of the screen with
-- no buttons, between the side menu and the right column (Starter Pack, x2 badges,
-- speedometer). Its width is kept inside that strip and its height to ChatMaxHeightShare of the
-- Main HUD (above the player's character); nil elsewhere (the place's own top-left chat).
HudErgonomics.ChatMaxHeightShare = 0.55
HudErgonomics.ChatGap = 8

-- `width` x `height`: the whole screen; `topBar` Roblox's top bar; `avoid`: more rects near the
-- top (the RACE button), kept clear across. Returns nil (leave the chat as the place has it) or
-- { Horizontal = "Center", Vertical = "Top", MaxWidth, MaxHeight } in pixels.
function HudErgonomics.ChatWindow(width: number, height: number, touch: boolean, keyboard: boolean, topBar: number?, avoid: { any }?)
	if not touch or not HudErgonomics.IsCompact(width, height, touch, keyboard) then
		return nil
	end
	local inset = topBar or 0
	local hudHeight = height - inset
	local menu = HudErgonomics.SideBarCells(width, hudHeight, 9)
	local column = HudErgonomics.PhoneColumn(width, height, true, false, 2, inset)
	local rightLeft = math.min(column.Pack.Left, column.Badges[1].Left, column.Speedometer.Rect.Left)
	local reach = math.max(menu.Frame.Right, width - rightLeft)
	for _, r in avoid or {} do
		if (r.Left + r.Right) / 2 < width / 2 then
			reach = math.max(reach, r.Right)
		else
			reach = math.max(reach, width - r.Left)
		end
	end
	reach += HudErgonomics.ChatGap
	return {
		Horizontal = "Center",
		Vertical = "Top",
		MaxWidth = math.max(0, width - 2 * reach),
		MaxHeight = HudErgonomics.ChatMaxHeightShare * hudHeight,
	}
end

----------------------------------------------------------------------
-- The Sonic Burst button (touch screens only: a keyboard charges it with Shift, a gamepad
-- with its sprint trigger)
----------------------------------------------------------------------
HudErgonomics.AbilityButtonSize = { Min = 38, Max = 46 }
HudErgonomics.AbilityGap = 12
-- Heat Vision's button keeps this far from Sprint, the Burst button, the jump button and the
-- thumbstick (2026-09-25): 12 px (2 mm on a phone) from Sprint had the thumb that reached for
-- one land on the other, and players reported it on top of Sprint.
HudErgonomics.HeatClearance = 24

-- Where the Sonic Burst button goes on a `width` x `hudHeight` Main HUD screen, in Main
-- HUD pixels: in the right thumb's reach beside the Sprint button (above it, else left of
-- it, else up and left, else further left along the row above it), clear of the jump and
-- Sprint buttons, the thumbstick, the level and stamina bars and `avoid` (the boost cards
-- and the speedometer, which the phone column puts nearby; 6 px, or a rect's own
-- `Clearance`). `clearance` (Heat Vision's HeatClearance) is kept from Sprint and the
-- thumbstick instead of 8 px, and is the gap beside Sprint instead of AbilityGap.
function HudErgonomics.AbilityButton(width: number, hudHeight: number, avoid: { any }?, clearance: number?)
	local gap = math.max(HudErgonomics.AbilityGap, clearance or 0)
	local near = clearance or 8
	local limits = HudErgonomics.AbilityButtonSize
	local size = math.clamp(math.floor(math.min(width, hudHeight) * 0.11 + 0.5), limits.Min, limits.Max)
	local sprint = HudErgonomics.SprintButton(width, hudHeight)
	local jump = HudErgonomics.JumpButton(width, hudHeight)
	local stick = HudErgonomics.Thumbstick(width, hudHeight)
	local bars = HudErgonomics.CentreBarRects(width, hudHeight)
	local candidates = {
		rect(sprint.X - size / 2, sprint.Top - gap - size, size, size),
		rect(sprint.Left - gap - size, sprint.Y - size / 2, size, size),
		rect(sprint.Left - gap - size, sprint.Top - gap - size, size, size),
	}
	-- Narrow phones: the boost cards are above Sprint and the bars' right ends beside it.
	for left = sprint.Left - gap - size - 4, width / 2, -4 do
		table.insert(candidates, rect(left, sprint.Top - gap - size, size, size))
	end
	local function clear(candidate, offTheBars: boolean, anywhere: boolean?): boolean
		if candidate.Top < 8 or candidate.Bottom > hudHeight - 4 or candidate.Left < (if anywhere then 8 else width / 2) then
			return false
		end
		-- As far from the jump button as a piece the player places (CustomJumpMargin): once
		-- Sprint is moved away, a place beside the jump button would be hit by the jumping thumb.
		if HudErgonomics.Overlaps(candidate, jump, HudErgonomics.CustomJumpMargin) then
			return false
		end
		for _, other in { sprint, stick } do
			if HudErgonomics.Overlaps(candidate, other, near) then
				return false
			end
		end
		for _, other in avoid or {} do
			if HudErgonomics.Overlaps(candidate, other, other.Clearance or 6) then
				return false
			end
		end
		for _, bar in if offTheBars then bars else {} do
			if HudErgonomics.Overlaps(candidate, bar, 2) then
				return false
			end
		end
		return true
	end
	-- Off the level and stamina bars if any place is; else as before, over their ends.
	local chosen = nil
	for _, offTheBars in { true, false } do
		for _, candidate in candidates do
			if clear(candidate, offTheBars) then
				chosen = candidate
				break
			end
		end
		if chosen then
			break
		end
	end
	-- The player's own pieces (TouchControls puts them in `avoid`) can close every place
	-- beside Sprint: then the clear place nearest to it in the right half, never on them
	-- (an 8 px grid: a few thousand tries on a phone, once per layout); failing that
	-- (2026-09-25) anywhere on the screen, before the last resort beside Sprint.
	for _, anywhere in { false, true } do
		if chosen then
			break
		end
		local nearest = math.huge
		for top = 8, hudHeight - 4 - size, 8 do
			for left = (if anywhere then 8 else width / 2), width - size, 8 do
				local candidate = rect(left, top, size, size)
				local distance = (left + size / 2 - sprint.X) ^ 2 + (top + size / 2 - sprint.Y) ^ 2
				if distance < nearest and clear(candidate, false, anywhere) then
					chosen, nearest = candidate, distance
				end
			end
		end
	end
	chosen = chosen or candidates[2]
	chosen.Size = size
	chosen.X = (chosen.Left + chosen.Right) / 2
	chosen.Y = (chosen.Top + chosen.Bottom) / 2
	return chosen
end

----------------------------------------------------------------------
-- The player's own touch layout ("Move controls" in Settings, touch screens only)
----------------------------------------------------------------------
-- Saved as one short string, the player's TouchLayout setting and attribute:
--   ""                                    the automatic layout
--   "1|S=0.2124,0.2294|B=0.2901,0.2294"   version 1, then each moved piece and its centre as
--                                         a share of the Main HUD screen, 4 decimals, in the
--                                         order S Sprint, B the Burst button, H the Heat
--                                         Vision button, T the stamina bar.
-- Exactly what FormatTouchLayout writes, nothing else: the server keeps only such strings
-- (ProfileCodec.SanitizeTouchLayout checks the same pattern). A share of the screen, so it
-- survives a rotation or another device; it is only a wish: PlaceCustom moves it on screen
-- and off Roblox's jump button and thumbstick area every time it is applied.
HudErgonomics.TouchLayoutVersion = "1"
HudErgonomics.TouchLayoutMaxLength = 80
HudErgonomics.TouchPieces = { "S", "B", "H", "T" }
HudErgonomics.TouchLayoutField = "^([SBHT])=([01]%.%d%d%d%d),([01]%.%d%d%d%d)$"
HudErgonomics.CustomEdgeMargin = 8
HudErgonomics.CustomJumpMargin = 24
HudErgonomics.CustomStickMargin = 8

-- { S = { X, Y }, ... } from the saved string; nil when it is empty, too long or not exactly
-- the format (one bad field and the whole string is ignored: the automatic layout).
function HudErgonomics.ParseTouchLayout(text: any)
	if type(text) ~= "string" or #text == 0 or #text > HudErgonomics.TouchLayoutMaxLength then
		return nil
	end
	local fields = string.split(text, "|")
	if fields[1] ~= HudErgonomics.TouchLayoutVersion or #fields < 2 then
		return nil
	end
	local pieces, last = {}, 0
	for index = 2, #fields do
		local piece, x, y = string.match(fields[index], HudErgonomics.TouchLayoutField)
		local order = piece and table.find(HudErgonomics.TouchPieces, piece)
		local nx, ny = tonumber(x), tonumber(y)
		-- Each piece once, in order, inside the screen.
		if not order or order <= last or not nx or not ny or nx > 1 or ny > 1 then
			return nil
		end
		last = order
		pieces[piece] = { X = nx, Y = ny }
	end
	return pieces
end

-- The string for { S = { X, Y }, ... }; "" when nothing is moved.
function HudErgonomics.FormatTouchLayout(pieces: any): string
	local fields = { HudErgonomics.TouchLayoutVersion }
	for _, piece in HudErgonomics.TouchPieces do
		local at = type(pieces) == "table" and pieces[piece]
		local x, y = type(at) == "table" and tonumber(at.X), type(at) == "table" and tonumber(at.Y)
		if x and y and x == x and y == y then
			-- (+ 0: a clamped -0 would print as "-0.0000".)
			table.insert(fields, ("%s=%.4f,%.4f"):format(piece, math.clamp(x, 0, 1) + 0, math.clamp(y, 0, 1) + 0))
		end
	end
	return if #fields > 1 then table.concat(fields, "|") else ""
end

-- A piece `pieceWidth` x `pieceHeight` whose centre is wished at `nx`, `ny` of a `width` x
-- `height` Main HUD screen: on screen (8 px in), 24 px or more from Roblox's jump button and,
-- for a button (`solid`), out of the thumbstick's area (`stickMargin` px off it: 8, Heat
-- Vision's 24), moved the shortest way when the wish is not. nil where no such place is
-- near, or the screen is upright or not measured yet: the caller keeps the automatic place.
function HudErgonomics.PlaceCustom(width: number, height: number, pieceWidth: number, pieceHeight: number, nx: number, ny: number, solid: boolean?, stickMargin: number?)
	if width < height or width < 320 or pieceWidth <= 0 or pieceHeight <= 0 or nx ~= nx or ny ~= ny then
		return nil
	end
	local halfW, halfH = pieceWidth / 2, pieceHeight / 2
	local edge = HudErgonomics.CustomEdgeMargin
	local minX, maxX = edge + halfW, width - edge - halfW
	local minY, maxY = edge + halfH, height - edge - halfH
	if minX > maxX or minY > maxY then
		return nil
	end
	local x, y = math.clamp(nx * width, minX, maxX), math.clamp(ny * height, minY, maxY)
	local zones = { { Rect = HudErgonomics.JumpButton(width, height), Margin = HudErgonomics.CustomJumpMargin } }
	if solid then
		table.insert(zones, { Rect = HudErgonomics.Thumbstick(width, height), Margin = stickMargin or HudErgonomics.CustomStickMargin })
	end
	-- Twice: leaving one area can enter the other.
	for _ = 1, 2 do
		for _, zone in zones do
			local left, right = zone.Rect.Left - zone.Margin - halfW, zone.Rect.Right + zone.Margin + halfW
			local top, bottom = zone.Rect.Top - zone.Margin - halfH, zone.Rect.Bottom + zone.Margin + halfH
			if x > left and x < right and y > top and y < bottom then
				-- The nearest way out that is still on the screen.
				local bestX, bestY, bestDistance = nil, nil, math.huge
				for _, exit in { { left, y }, { right, y }, { x, top }, { x, bottom } } do
					local distance = math.abs(exit[1] - x) + math.abs(exit[2] - y)
					if exit[1] >= minX and exit[1] <= maxX and exit[2] >= minY and exit[2] <= maxY and distance < bestDistance then
						bestX, bestY, bestDistance = exit[1], exit[2], distance
					end
				end
				if not bestX then
					return nil
				end
				x, y = bestX, bestY
			end
		end
	end
	local r = rect(x - halfW, y - halfH, pieceWidth, pieceHeight)
	for _, zone in zones do
		if HudErgonomics.Overlaps(r, zone.Rect, zone.Margin - 0.5) then
			return nil
		end
	end
	r.X, r.Y = x, y
	return r
end

-- The saved layout's place for `piece` ("S", "B", "H" or "T"), or nil for the automatic one.
function HudErgonomics.CustomPiece(layoutText: any, piece: string, width: number, height: number, pieceWidth: number, pieceHeight: number, solid: boolean?, stickMargin: number?)
	local pieces = HudErgonomics.ParseTouchLayout(layoutText)
	local at = pieces and pieces[piece]
	if not at then
		return nil
	end
	return HudErgonomics.PlaceCustom(width, height, pieceWidth, pieceHeight, at.X, at.Y, solid, stickMargin)
end

-- `r` tagged with how far the other pieces keep from it (read by AbilityButton and
-- TouchControls); a copy, so the plan's own rects stay plain.
local function keepOff(r, margin: number)
	if not r then
		return nil
	end
	local copy = table.clone(r)
	copy.Clearance = margin
	return copy
end

-- Every touch piece under the player's layout on a `width` x `hudHeight` Main HUD screen, in
-- Main HUD pixels: S Sprint, B the Burst button, H the Heat Vision button (each with its
-- Size), and T the stamina bar (nil while it keeps the designer's place). A moved piece keeps
-- its saved place when PlaceCustom finds it legal here and it is clear of the moved pieces
-- before it (Sprint, the bar, the Burst button: only on another screen can they meet); else
-- its automatic place. The automatic ability buttons make room for every moved piece and
-- keep clear of `neighbours` (TouchNeighbours); Heat Vision of the Burst button too while
-- `burstShown`. Heat Vision, moved or not, keeps HeatClearance (24 px) from Sprint, the
-- Burst button, the jump button and the thumbstick, and the automatic Burst button keeps
-- as far from a moved Heat Vision. The same answer for MainHUDController, SonicBurstClient,
-- HeatVisionClient and the editor, which pass the same `neighbours` and `burstShown`.
function HudErgonomics.TouchControls(width: number, hudHeight: number, layoutText: any, neighbours: { any }?, burstShown: boolean?)
	local sprint = HudErgonomics.SprintButton(width, hudHeight)
	local bar = HudErgonomics.CentreBarRects(width, hudHeight)[2]
	local limits = HudErgonomics.AbilityButtonSize
	local side = math.clamp(math.floor(math.min(width, hudHeight) * 0.11 + 0.5), limits.Min, limits.Max)
	local clearance = HudErgonomics.HeatClearance
	-- The saved place of `piece`, when it is legal here and clear of `before` (4 px, or a
	-- rect's own Clearance).
	local function moved(piece: string, pieceWidth: number, pieceHeight: number, solid: boolean, before: { any }, stickMargin: number?)
		local r = HudErgonomics.CustomPiece(layoutText, piece, width, hudHeight, pieceWidth, pieceHeight, solid, stickMargin)
		for _, other in if r then before else {} do
			if HudErgonomics.Overlaps(r, other, other.Clearance or 4) then
				return nil
			end
		end
		return r
	end
	local plan = {}
	plan.S = moved("S", sprint.Size, sprint.Size, true, {}) or sprint
	plan.S.Size = sprint.Size
	plan.T = moved("T", bar.Right - bar.Left, bar.Bottom - bar.Top, false, { plan.S })
	local placed = { plan.S, plan.T or bar }
	local movedBurst = moved("B", side, side, true, placed)
	-- Heat Vision's saved place: a thumb's width from Sprint and a shown Burst button.
	local heatBefore = { keepOff(plan.S, clearance), plan.T or bar }
	if burstShown and movedBurst then
		table.insert(heatBefore, keepOff(movedBurst, clearance))
	end
	local movedHeat = moved("H", side, side, true, heatBefore, clearance)
	-- The automatic ones make room for what the player placed.
	local obstacles = table.clone(neighbours or {})
	for _, r in { plan.S, plan.T, keepOff(movedHeat, clearance) } do
		table.insert(obstacles, r)
	end
	plan.B = movedBurst or HudErgonomics.AbilityButton(width, hudHeight, obstacles)
	-- (2026-09-25) The automatic Heat Vision: 24 px from Sprint (moved or not) and the shown
	-- Burst button, not the 6-12 px the other pieces keep.
	local heatObstacles = table.clone(neighbours or {})
	for _, r in { keepOff(plan.S, clearance), plan.T, if burstShown then keepOff(plan.B, clearance) else nil } do
		table.insert(heatObstacles, r)
	end
	plan.H = movedHeat or HudErgonomics.AbilityButton(width, hudHeight, heatObstacles, clearance)
	plan.B.Size, plan.H.Size = side, side
	return plan
end

-- "Swap side": Sprint and the ability buttons for the LEFT thumb, in the strip above Roblox's
-- thumbstick area (the left 40% under the screen's top third), right of the menu buttons.
-- Heat Vision keeps its 24 px (+2 for the saved string's rounding) from the Burst button
-- and the thumbstick, so the row sits that high. Shares of the screen, ready for
-- FormatTouchLayout.
HudErgonomics.LeftPresetX = 0.16
function HudErgonomics.LeftPreset(width: number, height: number)
	local sprint = HudErgonomics.SprintButton(width, height)
	local size = HudErgonomics.AbilityButton(width, height).Size
	local gap = HudErgonomics.AbilityGap
	local heatGap = HudErgonomics.HeatClearance + 2
	local stick = HudErgonomics.Thumbstick(width, height)
	local y = math.max(
		HudErgonomics.CustomEdgeMargin + sprint.Size / 2,
		math.min(stick.Top - HudErgonomics.CustomStickMargin - 2 - sprint.Size / 2, stick.Top - heatGap - size / 2)
	)
	local x = width * HudErgonomics.LeftPresetX + gap + sprint.Size / 2
	local burstX = x + sprint.Size / 2 + gap + size / 2
	local heatX = burstX + size + heatGap
	return {
		S = { X = x / width, Y = y / height },
		B = { X = burstX / width, Y = y / height },
		H = { X = heatX / width, Y = y / height },
	}
end

return HudErgonomics
