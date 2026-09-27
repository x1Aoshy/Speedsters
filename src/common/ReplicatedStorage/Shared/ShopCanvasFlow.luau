-- ReplicatedStorage/Shared/ShopCanvasFlow.luau
-- 2026-09-26 (owner): the Shop's canvas follows its content.
-- The designer's Shop (StarterGui.Shop.Shop.ScrollingFrame) places every section in scale of the
-- canvas (CanvasSize 0, 9): titles, cards and the Passes list ("Pass", a UIListLayout) all sit at
-- fixed canvas heights. The designer left room in the Passes list for their own four cards, so a
-- card the build adds there ("2X Stamina", audit/u4_shop_card) ran past the list's room and was
-- drawn over the "Treadmills" header and the Treadmill Valentine card (owner's screenshot,
-- 2026-09-26), while 2.3 windows of empty canvas trailed after the Codes box.
-- AutomaticCanvasSize cannot help: the children are placed in scale OF the canvas, so a canvas
-- sized from its children moves them (a loop). Instead the controller measures and this module
-- plans, in the canvas' own terms:
--   * everything placed below the top of the list moves down by the list's extra content (the
--     cards the build added that are showing, each with the list's gap);
--   * the canvas ends EndRoom of the window under the lowest content (never shorter than the
--     window), so nothing is clipped and nothing floats past the end;
--   * every child keeps its size and place in pixels: positions and sizes (Y scale) are
--     rewritten against the new canvas height, X is never touched.
-- Pure numbers in, numbers out (no Roblox types), so audit/test_u4_shop_layout runs it on the
-- real place's Shop at several screen sizes.
local ShopCanvasFlow = {}

-- Share of the scroll window kept under the lowest content: MenuPanelLayout.ListEndRoom, the
-- rule the other lists use.
ShopCanvasFlow.EndRoom = 0.08
-- A plan that moves nothing by more than this (canvas scale) is not written again.
ShopCanvasFlow.Epsilon = 1e-4

local function finite(value)
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

-- The canvas height in pixels NOW, from two children placed in scale of it:
-- samples = { { Scale = Position.Y.Scale, Offset = Position.Y.Offset, Anchor = AnchorPoint.Y,
--   Top = AbsolutePosition.Y, Height = AbsoluteSize.Y }, ... }. The pair farthest apart in scale
-- gives it: (anchor point B - anchor point A) / (scale B - scale A). Measured this way the result
-- is in the same pixels as AbsoluteSize (UIScales and a window mid-slide included).
function ShopCanvasFlow.MeasureCanvas(samples: { any }): number?
	local low, high = nil, nil
	for _, s in samples do
		if finite(s.Scale) and finite(s.Top) and finite(s.Height) then
			if not low or s.Scale < low.Scale then
				low = s
			end
			if not high or s.Scale > high.Scale then
				high = s
			end
		end
	end
	if not low or not high or high.Scale - low.Scale < 0.05 then
		return nil
	end
	local function anchorY(s)
		return s.Top + (s.Anchor or 0) * s.Height - (s.Offset or 0)
	end
	local canvas = (anchorY(high) - anchorY(low)) / (high.Scale - low.Scale)
	return if finite(canvas) and canvas > 0 then canvas else nil
end

-- How far the list's content runs past the designer's cards: every added card showing (Added)
-- with one gap each. The gap is measured, not read from Padding: (content - the cards' heights)
-- over the gaps between them. cards = { { Height, Visible, Added } }; contentPx is the
-- UIListLayout's AbsoluteContentSize.Y.
function ShopCanvasFlow.ListExtra(cards: { any }, contentPx: number, paddingPx: number?): number
	local total, count, added = 0, 0, {}
	for _, card in cards do
		if card.Visible and finite(card.Height) then
			total += card.Height
			count += 1
			if card.Added then
				table.insert(added, card.Height)
			end
		end
	end
	local gap = if count > 1 and finite(contentPx) then math.max(0, (contentPx - total) / (count - 1)) else math.max(0, paddingPx or 0)
	local extra = 0
	for _, height in added do
		extra += height + gap
	end
	return extra
end

-- The plan. `authored` is the designer's layout, captured once before anything was changed:
--   { CanvasScale = CanvasSize.Y.Scale, ListScale = the list's Position.Y.Scale,
--     Items = { [key] = { Scale = Position.Y.Scale, Offset = Position.Y.Offset,
--       SizeScale = Size.Y.Scale, Anchor = AnchorPoint.Y, List = true for the list } } }
-- `m` is measured now, in one set of pixels:
--   { CanvasPx = the canvas height now (MeasureCanvas), CanvasScale = CanvasSize.Y.Scale now,
--     WindowPx = the scroll window's height, ExtraPx = ListExtra(...), ListContentPx = the list's
--     content height, Heights = { [key] = AbsoluteSize.Y }, Visible = { [key] = bool } }
-- Returns nil when there is nothing to measure yet, else
--   { CanvasScale = new CanvasSize.Y.Scale, Items = { [key] = { Scale, SizeScale } },
--     Grow = new canvas / designer's canvas, ContentBottomPx, CanvasPx }.
function ShopCanvasFlow.Plan(authored: any, m: any)
	local c0 = authored.CanvasScale
	if not (finite(c0) and c0 > 0 and finite(m.CanvasPx) and m.CanvasPx > 0 and finite(m.CanvasScale) and m.CanvasScale > 0) then
		return nil
	end
	local windowPx = if finite(m.WindowPx) and m.WindowPx > 0 then m.WindowPx else 0
	-- The designer's canvas, in today's pixels (the canvas is its scale times one base).
	local canvas0 = m.CanvasPx * c0 / m.CanvasScale
	local extra = if finite(m.ExtraPx) then m.ExtraPx else 0
	local listTop = authored.ListScale * canvas0
	local bottom = 0
	local shifts = {}
	for key, item in authored.Items do
		local height = m.Heights and m.Heights[key]
		local anchorAt = item.Scale * canvas0 + (item.Offset or 0)
		local below = not item.List and item.Scale > authored.ListScale + 1e-6
		local shift = if below then extra else 0
		shifts[key] = shift
		if (m.Visible == nil or m.Visible[key] ~= false) and finite(height) then
			local itemBottom
			if item.List then
				itemBottom = anchorAt - (item.Anchor or 0) * height + (if finite(m.ListContentPx) then m.ListContentPx else height)
			else
				itemBottom = anchorAt - (item.Anchor or 0) * height + height + shift
			end
			bottom = math.max(bottom, itemBottom)
		end
	end
	if bottom <= 0 then
		return nil
	end
	-- A list with nothing below it still ends inside the canvas.
	bottom = math.max(bottom, listTop)
	local canvas1 = math.max(bottom + ShopCanvasFlow.EndRoom * windowPx, windowPx)
	local grow = canvas1 / canvas0
	local plan = { CanvasScale = c0 * grow, Items = {}, Grow = grow, ContentBottomPx = bottom, CanvasPx = canvas1 }
	for key, item in authored.Items do
		plan.Items[key] = {
			Scale = (item.Scale * canvas0 + shifts[key]) / canvas1,
			SizeScale = item.SizeScale / grow,
		}
	end
	return plan
end

-- Whether `plan` differs from what is on screen (`current` = { CanvasScale, Items = { [key] =
-- { Scale, SizeScale } } }) by more than Epsilon anywhere.
function ShopCanvasFlow.Differs(plan: any, current: any): boolean
	if math.abs(plan.CanvasScale - current.CanvasScale) > ShopCanvasFlow.Epsilon then
		return true
	end
	for key, want in plan.Items do
		local have = current.Items[key]
		if not have or math.abs(want.Scale - have.Scale) > ShopCanvasFlow.Epsilon or math.abs(want.SizeScale - have.SizeScale) > ShopCanvasFlow.Epsilon then
			return true
		end
	end
	return false
end

return ShopCanvasFlow
