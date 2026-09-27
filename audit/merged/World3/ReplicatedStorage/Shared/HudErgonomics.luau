-- HudErgonomics.luau
-- Where the Main HUD's touch and console pieces go on a screen of a given size, in pixels,
-- so the rules can be checked without a device (audit/test_ui_ergonomics):
--
--   * the touch Sprint button: a 60-75 px circle in the right thumb's reach, just left of
--     Roblox's jump button, clear of it and of the thumbstick;
--   * the Starter Pack offer (top right) and the x2 Speed / x2 Victory badges: on phones
--     the right edge is one column, top to bottom: the Starter Pack, the badges, the
--     speedometer, Roblox's jump button, sized to fit the screen's height, with the boost
--     cards beside the speedometer; the top middle of the screen stays clear, for the
--     track. On bigger screens the badges keep the designer's column under the pack;
--   * the console's safe zone: nothing within 5% of the TV's edges.
--
-- Only numbers: the controllers turn them into UDim2s. Rects are { Left, Top, Right,
-- Bottom } in pixels from the screen's top-left corner.

local HudErgonomics = {}

HudErgonomics.SafeInset = 0.05
HudErgonomics.SprintMin = 46
HudErgonomics.SprintMax = 54
HudErgonomics.SprintGap = 14
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

-- The Sprint button: a square (drawn round) of 46-54 px just left of the jump button and
-- level with it, where the right thumb slides to from the jump.
-- Screen here is the Main HUD's (and the touch controls'): below Roblox's top bar.
function HudErgonomics.SprintButton(width: number, height: number)
	local jump = HudErgonomics.JumpButton(width, height)
	local side = math.clamp(math.floor(math.min(width, height) * 0.13 + 0.5), HudErgonomics.SprintMin, HudErgonomics.SprintMax)
	local right = jump.Left - HudErgonomics.SprintGap
	local centreY = (jump.Top + jump.Bottom) / 2
	local top = math.clamp(centreY - side / 2, 8, height - side - 8)
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
	local floor = (if jump then jump.Top + inset else height - 16) - gap
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

----------------------------------------------------------------------
-- The Sonic Burst button (touch screens only: a keyboard charges it with Shift, a gamepad
-- with its sprint trigger)
----------------------------------------------------------------------
HudErgonomics.AbilityButtonSize = { Min = 38, Max = 46 }
HudErgonomics.AbilityGap = 12

-- Where the Sonic Burst button goes on a `width` x `hudHeight` Main HUD screen, in Main
-- HUD pixels: in the right thumb's reach beside the Sprint button (above it, else left of
-- it, else up and left), clear of the jump and Sprint buttons, the thumbstick and `avoid`
-- (the boost cards and the speedometer, which the phone column puts nearby).
function HudErgonomics.AbilityButton(width: number, hudHeight: number, avoid: { any }?)
	local gap = HudErgonomics.AbilityGap
	local limits = HudErgonomics.AbilityButtonSize
	local size = math.clamp(math.floor(math.min(width, hudHeight) * 0.11 + 0.5), limits.Min, limits.Max)
	local sprint = HudErgonomics.SprintButton(width, hudHeight)
	local jump = HudErgonomics.JumpButton(width, hudHeight)
	local stick = HudErgonomics.Thumbstick(width, hudHeight)
	local candidates = {
		rect(sprint.X - size / 2, sprint.Top - gap - size, size, size),
		rect(sprint.Left - gap - size, sprint.Y - size / 2, size, size),
		rect(sprint.Left - gap - size, sprint.Top - gap - size, size, size),
	}
	local chosen = candidates[2]
	for _, candidate in candidates do
		local clear = candidate.Top >= 8
			and candidate.Bottom <= hudHeight - 4
			and candidate.Left >= width / 2
			and not HudErgonomics.Overlaps(candidate, jump, 8)
			and not HudErgonomics.Overlaps(candidate, sprint, 8)
			and not HudErgonomics.Overlaps(candidate, stick, 8)
		for _, other in avoid or {} do
			if HudErgonomics.Overlaps(candidate, other, 6) then
				clear = false
			end
		end
		if clear then
			chosen = candidate
			break
		end
	end
	chosen.Size = size
	chosen.X = (chosen.Left + chosen.Right) / 2
	chosen.Y = (chosen.Top + chosen.Bottom) / 2
	return chosen
end

return HudErgonomics
