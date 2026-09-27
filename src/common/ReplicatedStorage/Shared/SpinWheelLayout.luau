--!strict
-- SpinWheelLayout.luau
-- What the Spin Wheel panel adds to the designer's layout, as plain geometry: where each
-- prize really sits, the coloured slices under the prizes, and where the Wins button goes
-- on the current screen. The client builds frames from these numbers; the offline tests
-- and layout previews read the very same numbers.
--
-- Units: "holder units" measure the designer's wheel frame with its height as 1 (its
-- width is its aspect ratio). Pieces and odds are returned as scale values inside the
-- "Spin Wheel" frame; the Wins button as scale values inside the holder.

local GuiGeometry = if typeof(script) == "Instance" and script.Parent
	then require(script.Parent:WaitForChild("GuiGeometry"))
	else require("./GuiGeometry")

local SpinWheelLayout = {}

-- Measured on the designer's white wheel, as shares of the art's radius: the slices end at
-- a thin black line at 0.916-0.928, then comes a white rim (0.93-0.985) and a black
-- outline. The colours stop at the middle of that thin line and a ring of the same black
-- redraws it, so the white rim and the outline of the art stay exactly as designed.
SpinWheelLayout.ColourRadiusShare = 0.922
SpinWheelLayout.RingWidthShare = 0.02
-- The black lines between slices (measured about 4 px on a 263 px radius).
SpinWheelLayout.SeparatorWidthShare = 0.0165
-- Where the lines meet, as on the art.
SpinWheelLayout.DotRadiusShare = 0.04
-- Strip width, as a share of the art's radius. Narrow strips keep the rim and the centre
-- clean (see SlicePieces).
SpinWheelLayout.StripWidthShare = 0.025
-- How many colour stops each strip's gradient gets to follow the slice's radial shading.
SpinWheelLayout.GradientStops = 6
-- The studs over the colours: the game's stud texture, tiled about four studs to 0.42 of
-- the art's radius like the studs printed on the designer's white slices and buttons.
SpinWheelLayout.StudTexture = "rbxassetid://6927295847"
SpinWheelLayout.StudTileRadiusShare = 0.42
SpinWheelLayout.StudTransparency = 0.82
-- Width to height of the caption under the Wins button. It is exactly as wide as what the
-- button draws, so its text shrinks to fit rather than running into the wheel.
SpinWheelLayout.CaptionAspect = 6
-- The lines, their meeting point and the ring, as RGB: black like the art's own lines.
SpinWheelLayout.LineColor = { 0, 0, 0 }
-- The cap over the wheel's centre: a gold studded button with a navy rim and a soft
-- shadow, this share of the art's radius. It covers the point where the lines meet.
SpinWheelLayout.HubCapRadiusShare = 0.14
SpinWheelLayout.HubCapGold = { { 255, 230, 80 }, { 255, 186, 0 }, { 214, 118, 0 } }
SpinWheelLayout.HubCapRim = { 11, 27, 61 }
-- The Skip check: its box is this many times the countdown's text height, and the word
-- "Skip" beside it gets this width to height.
SpinWheelLayout.SkipBoxShare = 1.2
SpinWheelLayout.SkipCaptionAspect = 2.6
-- How much taller than the box the Skip check's touch area is, for fingers.
SpinWheelLayout.SkipTouchShare = 1.5
-- The tick drawn in the box: two round-ended bars, as centre, length, thickness and turn,
-- in box units. Each is one thickness longer than its stroke, so the round ends meet.
SpinWheelLayout.SkipTick = {
	{ X = 0.335, Y = 0.625, Length = 0.399, Thickness = 0.13, Rotation = 45 },
	{ X = 0.59, Y = 0.52, Length = 0.696, Thickness = 0.13, Rotation = -47.9 },
}

export type Slot = { Slice: Instance, Label: Instance?, Icon: Instance?, Angle: number }
export type Measure = {
	Holder: Instance,
	Wheel: Instance,
	Hub: Instance,
	Art: Instance,
	Arrow: Instance,
	Ratio: number,
	WheelWidth: number,
	WheelHeight: number,
	WheelCenter: GuiGeometry.Point,
	Pointer: number,
	ArtCenter: GuiGeometry.Point,
	ArtRadius: number,
	Slots: { Slot },
	SectorDegrees: number,
	SectorOffset: number,
}

local function aspectRatio(object: Instance): number
	local constraint = object:FindFirstChildOfClass("UIAspectRatioConstraint") :: any
	return if constraint and constraint.AspectRatio > 0 then constraint.AspectRatio else 1
end

-- Reads the designer's wheel: sizes, the arrow's angle and every prize's angle, clockwise
-- from the top of the wheel's own (unturned) frame.
function SpinWheelLayout.Measure(holder: Instance): Measure
	local ratio = aspectRatio(holder)
	local wheel = assert(holder:FindFirstChild("Spin Wheel"), "SpinWheelLayout: no 'Spin Wheel' frame")
	local hub = assert(wheel:FindFirstChild("Spin"), "SpinWheelLayout: no 'Spin' frame")
	local art = assert(wheel:FindFirstChildOfClass("ImageLabel"), "SpinWheelLayout: no wheel art")
	local arrow = assert(holder:FindFirstChild("Arrow"), "SpinWheelLayout: no arrow")
	local arrowImage = arrow:FindFirstChildOfClass("ImageLabel") or arrow

	local wheelWidth, wheelHeight = GuiGeometry.SizeIn(holder, wheel, ratio, 1)
	local wheelCenter = GuiGeometry.CenterIn(holder, wheel, ratio, 1)
	local pointer = GuiGeometry.AngleAround(wheelCenter, GuiGeometry.CenterIn(holder, arrowImage, ratio, 1))
	local artWidth = GuiGeometry.SizeIn(wheel, art, wheelWidth, wheelHeight)
	local artCenter = GuiGeometry.CenterIn(wheel, art, wheelWidth, wheelHeight)
	local middle = { x = wheelWidth / 2, y = wheelHeight / 2 }

	local slots: { Slot } = {}
	for _, child in hub:GetChildren() do
		if child:IsA("GuiObject") and string.match(child.Name, "^Slice%d+$") then
			local label = child:FindFirstChildOfClass("TextLabel")
			local icon = child:FindFirstChildOfClass("ImageLabel")
			local marker = label or icon or child
			table.insert(slots, {
				Slice = child,
				Label = label,
				Icon = icon,
				Angle = GuiGeometry.AngleAround(middle, GuiGeometry.CenterIn(wheel, marker, wheelWidth, wheelHeight)),
			})
		end
	end
	local sector = 360 / math.max(1, #slots)
	-- Clockwise from the top, counted from the start of the first sector.
	table.sort(slots, function(a, b)
		return (a.Angle + sector / 2) % 360 < (b.Angle + sector / 2) % 360
	end)
	-- The prizes were placed by hand a degree or two off; the sectors follow their average.
	local offset = 0
	for index, slot in slots do
		offset += GuiGeometry.DeltaDegrees(slot.Angle, (index - 1) * sector)
	end
	offset /= math.max(1, #slots)

	return {
		Holder = holder,
		Wheel = wheel,
		Hub = hub,
		Art = art,
		Arrow = arrow,
		Ratio = ratio,
		WheelWidth = wheelWidth,
		WheelHeight = wheelHeight,
		WheelCenter = wheelCenter,
		Pointer = pointer,
		ArtCenter = artCenter,
		ArtRadius = artWidth / 2,
		Slots = slots,
		SectorDegrees = sector,
		SectorOffset = offset,
	}
end

export type Piece = {
	Kind: string, -- "Fill", "Separator" or "Hub"
	Sector: number?,
	X: number,
	Y: number,
	Width: number,
	Height: number,
	Rotation: number,
}

-- A rectangle lying along the ray at `angle`: it runs from `from` to `to` (distances from
-- the art's centre) and is `offset` to the clockwise side of the ray (negative: the other
-- side). Returned as a centred scale rect inside the wheel frame.
local function strip(measure: Measure, angle: number, from: number, to: number, offset: number, width: number)
	local radians = math.rad(angle)
	local outX, outY = math.sin(radians), -math.cos(radians)
	local sideX, sideY = math.cos(radians), math.sin(radians)
	local along = (from + to) / 2
	local x = measure.ArtCenter.x + outX * along + sideX * offset
	local y = measure.ArtCenter.y + outY * along + sideY * offset
	return x / measure.WheelWidth, y / measure.WheelHeight, width / measure.WheelWidth, (to - from) / measure.WheelHeight
end

export type Stop = { Time: number, Share: number }
export type Piece = {
	Kind: string, -- "Fill", "Studs", "Separator", "Dot" or "Ring"
	Sector: number?,
	X: number,
	Y: number,
	Width: number,
	Height: number,
	Rotation: number,
	-- Fill only: along the strip from its outer end (Time 0) to its inner end (Time 1),
	-- how far out each point is, as a share of the coloured radius (1 = the rim).
	Stops: { Stop }?,
	-- Studs only: the tile size as a scale of the texture.
	TileScale: number?,
}

-- The coloured slices, in drawing order. UI has no pie shapes, and CanvasGroups blur or
-- blank out on low-memory phones, so a slice is covered by straight strips laid flush
-- against its two edges: the half next to each edge is strips parallel to that edge,
-- stacked inwards and started just late enough never to cross the opposite edge. The
-- edges come out exactly straight and strips only meet strips of the same colour. What
-- is left over, a speck where the lines meet and strip ends a hair either side of the rim,
-- sits under the dot and the ring. Each strip carries its own gradient stops, so the
-- shading follows the true distance from the centre across the whole slice.
function SpinWheelLayout.SlicePieces(measure: Measure): { Piece }
	local pieces: { Piece } = {}
	local count = #measure.Slots
	if count < 3 then
		return pieces
	end
	local radius = measure.ArtRadius * SpinWheelLayout.ColourRadiusShare
	local sector = measure.SectorDegrees
	local stripWidth = measure.ArtRadius * SpinWheelLayout.StripWidthShare
	local strips = math.ceil(radius * math.sin(math.rad(sector / 2)) / stripWidth)
	local slope = math.tan(math.rad(sector))
	local stops = math.max(2, SpinWheelLayout.GradientStops)
	for index = 1, count do
		local first = measure.SectorOffset + (index - 1) * sector - sector / 2
		for _, edge in { { Angle = first, Side = 1 }, { Angle = first + sector, Side = -1 } } do
			for step = 0, strips - 1 do
				-- Each strip reaches a little past the next one inwards, so anti-aliased
				-- edges never leave a seam of the white art between them.
				local near = step * stripWidth
				local far = near + stripWidth * 1.3
				local middle = (near + far) / 2
				local from = far / slope
				local to = math.sqrt(math.max(0, radius * radius - middle * middle))
				if to > from then
					local x, y, width, height = strip(measure, edge.Angle, from, to, edge.Side * middle, far - near)
					local shading: { Stop } = {}
					for stop = 0, stops - 1 do
						local time = stop / (stops - 1)
						local along = to - time * (to - from)
						table.insert(shading, { Time = time, Share = math.sqrt(along * along + middle * middle) / radius })
					end
					table.insert(pieces, {
						Kind = "Fill",
						Sector = index,
						X = x,
						Y = y,
						Width = width,
						Height = height,
						Rotation = edge.Angle % 360,
						Stops = shading,
					})
				end
			end
		end
	end

	local centreX, centreY = measure.ArtCenter.x / measure.WheelWidth, measure.ArtCenter.y / measure.WheelHeight
	local diameter = radius * 2
	table.insert(pieces, {
		Kind = "Studs",
		X = centreX,
		Y = centreY,
		Width = diameter / measure.WheelWidth,
		Height = diameter / measure.WheelHeight,
		Rotation = 0,
		TileScale = measure.ArtRadius * SpinWheelLayout.StudTileRadiusShare / diameter,
	})
	local separatorWidth = measure.ArtRadius * SpinWheelLayout.SeparatorWidthShare
	for index = 1, count do
		local angle = measure.SectorOffset + (index - 1) * sector - sector / 2
		local x, y, width, height = strip(measure, angle, 0, radius, 0, separatorWidth)
		table.insert(pieces, { Kind = "Separator", X = x, Y = y, Width = width, Height = height, Rotation = angle % 360 })
	end
	local dot = measure.ArtRadius * SpinWheelLayout.DotRadiusShare * 2
	table.insert(pieces, { Kind = "Dot", X = centreX, Y = centreY, Width = dot / measure.WheelWidth, Height = dot / measure.WheelHeight, Rotation = 0 })
	table.insert(pieces, { Kind = "Ring", X = centreX, Y = centreY, Width = diameter / measure.WheelWidth, Height = diameter / measure.WheelHeight, Rotation = 0 })
	return pieces
end

-- The ring's UIStroke thickness with StrokeSizingMode ScaledSize, which measures against
-- the ring's own diameter.
function SpinWheelLayout.RingStrokeShare(): number
	return SpinWheelLayout.RingWidthShare / (2 * SpinWheelLayout.ColourRadiusShare)
end

-- Where the hub cap goes: a centred, square scale rect inside the holder, over the
-- centre the wheel turns about. It sits in the holder, so it stays still while the wheel
-- spins under it.
function SpinWheelLayout.HubCap(measure: Measure)
	local radius = measure.ArtRadius * SpinWheelLayout.HubCapRadiusShare
	return {
		X = measure.WheelCenter.x / measure.Ratio,
		Y = measure.WheelCenter.y,
		Width = 2 * radius / measure.Ratio,
		Height = 2 * radius,
		Radius = radius,
	}
end

-- The Main HUD's Spin Wheel button stands left of the x2 Speed button, level with it: a
-- square HudButtonHeightShare times that button's height, HudButtonGapShare of its height
-- away. With no right button showing, it follows the right buttons' frame, taking this
-- share of its height as the row. Returns the square's right edge, its centre height and
-- its side, for AnchorPoint (1, 0.5).
SpinWheelLayout.HudButtonHeightShare = 1.4
SpinWheelLayout.HudButtonGapShare = 0.3 -- room for the "!" badge, which overhangs the square's right edge
SpinWheelLayout.HudButtonFallbackRowShare = 0.19
function SpinWheelLayout.HudButtonPlace(anchorLeft: number, anchorTop: number, anchorHeight: number): (number, number, number)
	return anchorLeft - anchorHeight * SpinWheelLayout.HudButtonGapShare,
		anchorTop + anchorHeight / 2,
		anchorHeight * SpinWheelLayout.HudButtonHeightShare
end

-- The rotation that brings the prize at `angle` under the arrow, `jitter` degrees in.
function SpinWheelLayout.LandingRotation(measure: Measure, angle: number, jitter: number): number
	return (measure.Pointer - angle + jitter) % 360
end

-- Where the Wins button and its caption go on a `screenWidth` x `screenHeight` screen.
-- The button is the designer's X1 at the size X1 has on that screen, placed in the space
-- left of the wheel and level with its centre. What gets centred is everything the button
-- draws, its tilted price tag included, so the tag can never touch the wheel. The caption
-- sits under it, as wide as what the button draws. Returns scale rects inside the holder.
-- A button the size of `model` (a designer's button) in the free space beside the wheel,
-- level with its centre: `side` -1 is left of the wheel, 1 right of it.
local function besideWheel(measure: Measure, gui: Instance, model: Instance, screenWidth: number, screenHeight: number, side: number)
	local holderWidth, holderHeight = GuiGeometry.SizeIn(gui, measure.Holder, screenWidth, screenHeight)
	local buttonWidth, buttonHeight = GuiGeometry.SizeIn(gui, model, screenWidth, screenHeight)
	local minX, minY, maxX, maxY = GuiGeometry.BoundsIn(model, buttonWidth, buttonHeight)
	-- The free space, in holder scale: from the holder's edge to the wheel's rim.
	local wheelLeft = (measure.WheelCenter.x - measure.ArtRadius) / measure.Ratio
	local wheelRight = (measure.WheelCenter.x + measure.ArtRadius) / measure.Ratio
	local visualWidth = (maxX - minX) / holderWidth
	-- Left: the middle of the space between the holder's edge and the rim. Right: the same
	-- small gap from the rim, outward (the wheel sits right of centre, so the button may
	-- reach past the holder's edge into the empty screen beside it).
	local gap = math.max(0.01, (wheelLeft - visualWidth) / 2)
	local middle = if side < 0 then wheelLeft / 2 else wheelRight + gap + visualWidth / 2
	local space = if side < 0 then wheelLeft else math.huge
	local visualCentreX = ((minX + maxX) / 2 - buttonWidth / 2) / holderWidth
	local visualCentreY = ((minY + maxY) / 2 - buttonHeight / 2) / holderHeight
	local x = middle - visualCentreX
	local y = measure.WheelCenter.y - visualCentreY
	local visualBottom = y + (maxY - buttonHeight / 2) / holderHeight

	local captionWidth = visualWidth
	local captionHeight = captionWidth * holderWidth / SpinWheelLayout.CaptionAspect / holderHeight
	return {
		Button = { X = x, Y = y, Width = buttonWidth / holderWidth, Height = buttonHeight / holderHeight },
		Caption = {
			X = middle,
			Y = visualBottom + captionHeight * 0.7,
			Width = captionWidth,
			Height = captionHeight,
		},
		-- True when everything the button draws stays clear of the wheel.
		Fits = visualWidth <= space,
		Visual = { Left = middle - visualWidth / 2, Right = middle + visualWidth / 2, WheelLeft = wheelLeft, WheelRight = wheelRight },
	}
end

-- The Wins spin: X1's size, left of the wheel.
function SpinWheelLayout.WinsButton(
	measure: Measure,
	gui: Instance,
	x1: Instance,
	caption: Instance,
	screenWidth: number,
	screenHeight: number
)
	return besideWheel(measure, gui, x1, screenWidth, screenHeight, -1)
end

-- A Robux pack that is not on the designer's row (X10): X3's size, right of the wheel.
function SpinWheelLayout.PackButton(
	measure: Measure,
	gui: Instance,
	x3: Instance,
	caption: Instance,
	screenWidth: number,
	screenHeight: number
)
	return besideWheel(measure, gui, x3, screenWidth, screenHeight, 1)
end

-- The Skip check: a square box in the designer's button style with the word "Skip" beside
-- it, under X1 and level with the countdown, lined up with X1's right edge but never over
-- the countdown's box. All of it lives in the button row, whose shape is fixed, so the
-- numbers hold on every screen. `Toggle` is a centred scale rect inside the row (the touch
-- area); `Box` and `Caption` are centred scale rects inside the toggle, with the
-- width-to-height `Aspect` each one keeps.
function SpinWheelLayout.SkipToggle(row: Instance, x1: Instance, timer: Instance)
	local ratio = aspectRatio(row)
	local x1Width = GuiGeometry.SizeIn(row, x1, ratio, 1)
	local x1Centre = GuiGeometry.CenterIn(row, x1, ratio, 1)
	local timerWidth, timerHeight = GuiGeometry.SizeIn(row, timer, ratio, 1)
	local timerCentre = GuiGeometry.CenterIn(row, timer, ratio, 1)
	local box = timerHeight * SpinWheelLayout.SkipBoxShare
	local gap = box * 0.22
	local captionWidth = timerHeight * SpinWheelLayout.SkipCaptionAspect
	local width = box + gap + captionWidth
	local left = math.max(x1Centre.x + x1Width / 2 - width, timerCentre.x + timerWidth / 2 + gap)
	local height = box * SpinWheelLayout.SkipTouchShare
	return {
		Toggle = { X = (left + width / 2) / ratio, Y = timerCentre.y, Width = width / ratio, Height = height },
		Box = { X = box / 2 / width, Y = 0.5, Width = box / width, Height = box / height, Aspect = 1 },
		Caption = {
			X = (box + gap + captionWidth / 2) / width,
			Y = 0.5,
			Width = captionWidth / width,
			Height = timerHeight / height,
			Aspect = captionWidth / timerHeight,
		},
		-- For checks: the toggle's left edge and the countdown box's right edge, in row units.
		Left = left,
		TimerRight = timerCentre.x + timerWidth / 2,
	}
end

-- How far down (negative: up), in pixels, the wheel's frame and the button row move
-- together so that what the panel draws sits in the middle of a screenWidth x screenHeight
-- screen, from the tip of the arrow to the countdown under the buttons. The wheel counts
-- as the whole circle its art sweeps while it turns. Measured from the authored positions
-- passed in, so it gives the same answer while the panel slides in or out.
function SpinWheelLayout.CentreOffset(
	measure: Measure,
	gui: Instance,
	row: Instance,
	holderPosition: UDim2,
	rowPosition: UDim2,
	screenWidth: number,
	screenHeight: number
): number
	local top, bottom = math.huge, -math.huge
	local function frameTop(frame: any, position: UDim2, height: number): number
		return position.Y.Scale * screenHeight + position.Y.Offset - frame.AnchorPoint.Y * height
	end
	local function includeChildren(frame: Instance, frameTopY: number, width: number, height: number, skip: Instance?)
		for _, child in frame:GetChildren() do
			if child:IsA("GuiObject") and child ~= skip then
				local _, minY, _, maxY = GuiGeometry.DrawnExtentIn(frame, child, width, height)
				if minY and maxY then
					top = math.min(top, frameTopY + minY)
					bottom = math.max(bottom, frameTopY + maxY)
				end
			end
		end
	end

	local holder = measure.Holder
	local holderWidth, holderHeight = GuiGeometry.SizeIn(gui, holder, screenWidth, screenHeight)
	local holderTop = frameTop(holder, holderPosition, holderHeight)
	local drift = math.sqrt((measure.ArtCenter.x - measure.WheelWidth / 2) ^ 2 + (measure.ArtCenter.y - measure.WheelHeight / 2) ^ 2)
	local reach = (measure.ArtRadius + drift) * holderHeight
	local wheelY = holderTop + measure.WheelCenter.y * holderHeight
	top, bottom = wheelY - reach, wheelY + reach
	includeChildren(holder, holderTop, holderWidth, holderHeight, measure.Wheel)

	local rowWidth, rowHeight = GuiGeometry.SizeIn(gui, row, screenWidth, screenHeight)
	includeChildren(row, frameTop(row, rowPosition, rowHeight), rowWidth, rowHeight, nil)

	return screenHeight / 2 - (top + bottom) / 2
end

----------------------------------------------------------------------
-- Compact layout: phones and tablets
----------------------------------------------------------------------
-- On a touch screen (or any screen under 560 px tall) the designer's layout leaves the
-- wheel at about half the screen's height with the buttons in a row under it. Compact
-- instead makes the wheel big and central, about 70% of the screen's height (a 1:1
-- circle), and stands the buttons in two columns beside it, each at least 44 px tall.
-- Nothing goes into the top CompactTopSafe pixels, where Roblox's own top bar is (menu,
-- chat, mic): the wheel is centred in the screen under it. (2026-09-18, Sung: the wheel
-- was 80% of the height and its arrow covered the top bar's icons; it is 12% smaller now.)
--   left:  Spin (the designer's Claim, a size up), its countdown, Skip, the Wins spin
--   right: the Robux packs X1, X3 and X10, "BEST VALUE" under X10
-- Everything is returned in screen pixels (centre X/Y, Width/Height); InHolder and InRow
-- turn a rect into the scale values of the frame it lives in.
SpinWheelLayout.CompactWheelShare = 0.704
SpinWheelLayout.CompactTopSafe = 45
SpinWheelLayout.CompactMinColumn = 150
SpinWheelLayout.CompactButtonShare = 0.15
SpinWheelLayout.CompactMinButton = 44
SpinWheelLayout.CompactMaxButton = 72
SpinWheelLayout.CompactSpinButtonGrow = 1.2

function SpinWheelLayout.UseCompact(screenWidth: number, screenHeight: number, touch: boolean): boolean
	return touch or screenHeight <= 560
end

export type Rect = { X: number, Y: number, Width: number, Height: number }

-- `row` is the designer's button row (X1, X3, Claim and the countdown); the side pieces
-- (WinsSpin, X10 and their captions) are the holder's. `skipAspect` is the Skip toggle's
-- width over height, when there is one.
function SpinWheelLayout.Compact(measure: Measure, gui: Instance, row: Instance, screenWidth: number, screenHeight: number, skipAspect: number?)
	local W, H = screenWidth, screenHeight
	local margin = math.max(8, H * 0.03)
	local gap = math.max(10, H * 0.03)
	local holder = measure.Holder
	local holderWidth, holderHeight = GuiGeometry.SizeIn(gui, holder, W, H)

	-- The wheel: its art `diameter` across, centred with the arrow that pokes out above it
	-- in the screen under the top bar's safe zone.
	local topSafe = SpinWheelLayout.CompactTopSafe
	local drift = math.sqrt((measure.ArtCenter.x - measure.WheelWidth / 2) ^ 2 + (measure.ArtCenter.y - measure.WheelHeight / 2) ^ 2)
	local _, arrowTop = GuiGeometry.DrawnExtentIn(holder, measure.Arrow, holderWidth, holderHeight)
	local artTop = (measure.WheelCenter.y - measure.ArtRadius) * holderHeight
	-- The arrow over the art, per stud of the diameter.
	local overhangShare = math.max(0, artTop - (arrowTop or artTop)) / (2 * measure.ArtRadius * holderHeight)
	local diameter = math.min(
		SpinWheelLayout.CompactWheelShare * H,
		W - 2 * (SpinWheelLayout.CompactMinColumn + margin + gap),
		(H - topSafe - margin) / (1 + overhangShare)
	)
	local scale = diameter / (2 * measure.ArtRadius * holderHeight)
	local overhang = overhangShare * diameter
	local cx = W / 2
	local cy = topSafe + (H - topSafe - (diameter + overhang)) / 2 + overhang + diameter / 2
	local reach = (measure.ArtRadius + drift) * holderHeight * scale
	local holderX = cx - (measure.WheelCenter.x * holderHeight - holderWidth / 2) * scale
	local holderY = cy - (measure.WheelCenter.y * holderHeight - holderHeight / 2) * scale

	-- The columns: from the screen's edge (plus a margin) to the wheel (plus a gap).
	local column = math.max(1, cx - reach - gap - margin)
	local leftX, rightX = margin + column / 2, W - margin - column / 2
	local base = math.clamp(H * SpinWheelLayout.CompactButtonShare, SpinWheelLayout.CompactMinButton, SpinWheelLayout.CompactMaxButton)
	local function fit(aspect: number, height: number): (number, number)
		local width = height * aspect
		if width > column then
			width = column
			height = width / aspect
		end
		return width, height
	end
	local function shapeOf(object: Instance?, fallback: number): number
		return if object then aspectRatio(object) else fallback
	end
	local packAspect = shapeOf(row:FindFirstChild("X1"), 2.8)
	local packWidth, packHeight = fit(packAspect, base)
	local captionHeight = packWidth / SpinWheelLayout.CaptionAspect
	local stackGap = packHeight * 0.3

	local rects: { [string]: Rect } = {}
	local function stack(x: number, pieces: { { Name: string, Width: number, Height: number, After: number } })
		local total = 0
		for index, piece in pieces do
			total += piece.Height + (if index < #pieces then piece.After else 0)
		end
		local y = cy - total / 2
		for _, piece in pieces do
			rects[piece.Name] = { X = x, Y = y + piece.Height / 2, Width = piece.Width, Height = piece.Height }
			y += piece.Height + piece.After
		end
	end

	-- Right: the packs, cheapest first.
	local packs = {}
	for _, name in { "X1", "X3" } do
		if row:FindFirstChild(name) then
			table.insert(packs, { Name = name, Width = packWidth, Height = packHeight, After = stackGap })
		end
	end
	if holder:FindFirstChild("X10") then
		table.insert(packs, { Name = "X10", Width = packWidth, Height = packHeight, After = 4 })
		if holder:FindFirstChild("X10Caption") then
			table.insert(packs, { Name = "X10Caption", Width = packWidth, Height = captionHeight, After = 0 })
		end
	end
	stack(rightX, packs)

	-- Left: Spin, its countdown and Skip; then the Wins spin and its caption.
	local left = {}
	local spinWidth, spinHeight = fit(shapeOf(row:FindFirstChild("Claim"), 2.8), base * SpinWheelLayout.CompactSpinButtonGrow)
	table.insert(left, { Name = "Claim", Width = spinWidth, Height = spinHeight, After = 4 })
	local timer = row:FindFirstChild("TextLabel")
	if timer then
		local timerAspect = shapeOf(timer, 14)
		local timerWidth = math.min(column, spinWidth * 1.25)
		table.insert(left, { Name = "TextLabel", Width = timerWidth, Height = timerWidth / timerAspect, After = 4 })
	end
	if skipAspect and skipAspect > 0 then
		local skipWidth, skipHeight = fit(skipAspect, packHeight * 0.62)
		table.insert(left, { Name = "SkipToggle", Width = skipWidth, Height = skipHeight, After = 4 })
	end
	left[#left].After = stackGap
	if holder:FindFirstChild("WinsSpin") then
		table.insert(left, { Name = "WinsSpin", Width = packWidth, Height = packHeight, After = 4 })
		if holder:FindFirstChild("WinsCaption") then
			table.insert(left, { Name = "WinsCaption", Width = packWidth, Height = captionHeight, After = 0 })
		end
	end
	stack(leftX, left)

	return {
		Scale = scale,
		Holder = { X = holderX, Y = holderY, Width = holderWidth, Height = holderHeight },
		Wheel = { X = cx, Y = cy, Diameter = diameter, Reach = reach, Top = cy - diameter / 2 - overhang },
		Column = column,
		ButtonHeight = packHeight,
		Rects = rects,
		Screen = { Width = W, Height = H },
	}
end

-- A screen rect as scale values inside the (scaled) holder, for its own pieces.
function SpinWheelLayout.InHolder(plan: any, rect: Rect): Rect
	local width, height = plan.Holder.Width * plan.Scale, plan.Holder.Height * plan.Scale
	local left, top = plan.Holder.X - width / 2, plan.Holder.Y - height / 2
	return { X = (rect.X - left) / width, Y = (rect.Y - top) / height, Width = rect.Width / width, Height = rect.Height / height }
end

-- A screen rect as scale values inside the button row, which compact stretches over the
-- whole screen.
function SpinWheelLayout.InRow(plan: any, rect: Rect): Rect
	local W, H = plan.Screen.Width, plan.Screen.Height
	return { X = rect.X / W, Y = rect.Y / H, Width = rect.Width / W, Height = rect.Height / H }
end

return SpinWheelLayout
