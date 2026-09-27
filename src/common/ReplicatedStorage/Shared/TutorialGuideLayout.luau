-- Pure pixel layout shared by the guide and its viewport regression tests.
local Layout = {}
local MARGIN, GAP = 10, 30

-- The card is sized from the HUD button it points at (the HUD is scale-sized), so it reads
-- as part of the HUD on a phone and on a 4K screen alike instead of staying 280 px wide.
function Layout.CardSize(vw, vh, buttonHeight)
	local h = math.clamp(math.floor((tonumber(buttonHeight) or 0) * 1.35 + 0.5), 96, 184)
	local w = math.floor(h * 2.5 + 0.5)
	return math.max(60, math.min(w, vw - MARGIN * 2)), math.max(60, math.min(h, vh - MARGIN * 2))
end

-- The size of the sidebar "!" badge on a button in the LEFT column: small enough, and far
-- enough inside the button, that it never reaches the button to its right (it also shakes
-- `shake` px sideways). Returns the badge's scale size and the scale position of its centre.
function Layout.InnerBadge(buttonWidth, gapWidth, shake)
	local size = 0.34
	local centre = 0.86
	if buttonWidth < 8 then
		return size, 0.83, 0.14 -- not laid out yet: the authored-screen answer
	end
	-- right edge of the badge, in button widths, must stay inside button + half the gap
	local limit = 1 + (gapWidth / math.max(1, buttonWidth)) * 0.5 - (shake or 0) / math.max(1, buttonWidth)
	if centre + size / 2 > limit then
		centre = limit - size / 2
	end
	return size, centre, 0.14
end

-- The dark shade around the highlighted button: four rectangles that share their edges.
-- UDim2 offsets are whole pixels and a button's AbsolutePosition/AbsoluteSize almost never
-- are (scale sizes, aspect ratios, UIScale). Cutting each shade's position and size on its
-- own left a bright 1 px line under the hole, along the bottom of the screen and down its
-- right edge. Every edge is rounded once here and shared, so two shades can neither part
-- nor overlap (they are translucent: an overlap would draw a darker line). The hole only
-- grows (floor/ceil outward), and the outer edges run `bleed` px past the canvas, so no
-- screen edge or inset strip stays lit. x, y, w, h: the hole wanted, in the canvas's pixels.
local SHADE_BLEED, SNAP = 1024, 0.001
function Layout.Shades(fullW, fullH, x, y, w, h, bleed)
	bleed = bleed or SHADE_BLEED
	fullW, fullH = math.max(0, math.ceil(fullW - SNAP)), math.max(0, math.ceil(fullH - SNAP))
	local x0 = math.clamp(math.floor(x + SNAP), 0, fullW)
	local y0 = math.clamp(math.floor(y + SNAP), 0, fullH)
	local x1 = math.clamp(math.ceil(x + w - SNAP), x0, fullW)
	local y1 = math.clamp(math.ceil(y + h - SNAP), y0, fullH)
	if not (w > 0 and h > 0) or x1 <= x0 or y1 <= y0 then
		x0, y0, x1, y1 = 0, fullH, 0, fullH -- nothing to show: Top takes the whole screen
	end
	local wide = fullW + bleed * 2
	return {
		Top = {x = -bleed, y = -bleed, w = wide, h = y0 + bleed},
		Bottom = {x = -bleed, y = y1, w = wide, h = fullH - y1 + bleed},
		Left = {x = -bleed, y = y0, w = x0 + bleed, h = y1 - y0},
		Right = {x = x1, y = y0, w = fullW - x1 + bleed, h = y1 - y0},
		Hole = {x = x0, y = y0, w = x1 - x0, h = y1 - y0},
	}
end

function Layout.Place(vw, vh, x, y, w, h, cw, ch)
	local margin, gap = MARGIN, GAP
	cw = math.min(cw or 280, vw - margin * 2)
	ch = ch or 144
	local candidates = {
		{x + w + gap, y + (h - ch) / 2, "right"},
		{x - cw - gap, y + (h - ch) / 2, "left"},
		{x + (w - cw) / 2, y - ch - gap, "top"},
		{x + (w - cw) / 2, y + h + gap, "bottom"},
	}
	local best, bestScore = nil, math.huge
	for _, c in candidates do
		local px = math.clamp(c[1], margin, math.max(margin, vw - cw - margin))
		local py = math.clamp(c[2], margin, math.max(margin, vh - ch - margin))
		local overlap = math.max(0, math.min(px + cw, x + w) - math.max(px, x))
			* math.max(0, math.min(py + ch, y + h) - math.max(py, y))
		local score = overlap * 1000 + math.abs(px - c[1]) + math.abs(py - c[2])
		if score < bestScore then
			best, bestScore = {x = px, y = py, w = cw, h = ch, side = c[3]}, score
		end
	end
	return best
end
return Layout
