-- test_u4_shop_layout.luau (2026-09-26, owner/QA: the "2X Stamina" Shop card)
-- The owner's screenshot (2026-09-26): the 2x Stamina card was drawn over the "Treadmills" header
-- and under the Treadmill Valentine card, misaligned, on phone, PC, tablet and console. Checked
-- here against the REAL Shop of the three places (StarterGui.Shop, read with Lune):
--   1. audit/u4_shop_card builds the card from a real sibling ("2X Speed"): inside the Passes list
--      (Pass, its UIListLayout), LayoutOrder right after the designer's last card, Size / aspect /
--      every child's Size, Position and AnchorPoint identical to the sibling's, title,
--      description, bolt icon, price, hidden; idempotent; a foreign card stops it.
--   2. The Shop laid out as Roblox does (a small simulator: scale and offset, AnchorPoint,
--      UIAspectRatioConstraint FitWithinMaxSize, the Pass list's UIListLayout, the canvas in scale
--      of the ScrollingFrame's parent) on PC 1920x1080, laptop 1366x768, tablet 1024x768 (touch),
--      phone 844x390 (touch, MenuPanelLayout's phone fit) and console 1920x1080 (safe insets):
--        * without the fix the card overlaps the Treadmills header (the screenshot);
--        * with Shared/ShopCanvasFlow (what ShopController runs) the card sits after Starter Pack
--          with the list's gap, the Treadmills header comes after it with the designer's own
--          gap, nothing overlaps, nothing is outside the canvas, the canvas ends EndRoom of the
--          window under the last content, a second pass changes nothing, and with the card
--          hidden (kill switch) every section is back at the designer's pixels;
--   3. ShopController wires it: stamped cards after the designer's, the reflow on the list's
--      content, the card's visibility, the kill switch, opening and resizing.
-- Run: lune run audit/test_u4_shop_layout.luau   (from the project root)
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local PlaceFiles = require("./place_files")
local ShopCard = require("./u4_shop_card")
local Flow = require("../src/common/ReplicatedStorage/Shared/ShopCanvasFlow")
local U4 = require("../src/common/ReplicatedStorage/Shared/Update4Config")

local Vector2, UDim2, Enum = roblox.Vector2, roblox.UDim2, roblox.Enum

local passed = 0
local function pass(text)
	passed += 1
	print("PASS " .. text)
end

----------------------------------------------------------------------
-- The real MenuPanelLayout (its phone fit sizes the Shop window on phones)
----------------------------------------------------------------------
local function moduleEnv(extra)
	local services = {
		Workspace = { CurrentCamera = nil },
		UserInputService = { TouchEnabled = false, KeyboardEnabled = true },
		GuiService = { GetGuiInset = function() return Vector2.new(0, 58), Vector2.new(0, 0) end },
		TweenService = {},
	}
	local env = {
		game = { GetService = function(_, name) return assert(services[name], name) end },
		Vector2 = Vector2,
		UDim2 = UDim2,
		Enum = Enum,
	}
	for key, value in extra or {} do
		env[key] = value
	end
	return setmetatable(env, { __index = _G })
end
local HudErgonomics = luau.load(fs.readFile("src/common/ReplicatedStorage/Shared/HudErgonomics.luau"), { environment = moduleEnv() })()
local Layout = luau.load(fs.readFile("src/common/ReplicatedStorage/Shared/MenuPanelLayout.luau"), {
	environment = moduleEnv({
		script = { Parent = { WaitForChild = function(_, name) return { Name = name } end } },
		require = function()
			return HudErgonomics
		end,
	}),
})()

----------------------------------------------------------------------
-- 1. The card, built into each place in memory
----------------------------------------------------------------------
local places = {}
for _, place in PlaceFiles.Places do
	local dm = roblox.deserializePlace(fs.readFile(place.file))
	local list = assert(ShopCard.PassList(dm), place.key .. ": the Passes list")
	local notes = {}
	local card = ShopCard.Insert(dm, notes)
	assert(card.Parent == list and card.Name == ShopCard.Name, place.key .. ": in StarterGui.Shop.Shop.ScrollingFrame.Pass")
	assert(list:FindFirstChildOfClass("UIListLayout"), place.key .. ": the list is a UIListLayout (the card is laid out with its siblings)")
	local source = assert(list:FindFirstChild("2X Speed"), place.key .. ": the 2X Speed sibling")
	local highest = -math.huge
	for _, sibling in ShopCard.Siblings(list) do
		highest = math.max(highest, sibling.LayoutOrder)
	end
	assert(card.LayoutOrder == highest + 1, place.key .. ": LayoutOrder right after the designer's last card (" .. card.LayoutOrder .. ")")
	local problems = ShopCard.LayoutProblems(list, card)
	assert(#problems == 0, place.key .. ": " .. table.concat(problems, "; "))
	assert(card.Visible == false and card:GetAttribute("U4Asset") == ShopCard.Stamp, place.key .. ": hidden and stamped")
	-- The backdrop is centred like 2X Speed / 2X Win (Revive's sits 23 % high).
	local backdrop = card:FindFirstChildOfClass("ImageLabel")
	assert(backdrop.Position == UDim2.fromScale(0.50000006, 0.5) or (math.abs(backdrop.Position.Y.Scale - 0.5) < 1e-4 and math.abs(backdrop.Position.X.Scale - 0.5) < 1e-4),
		place.key .. ": the backdrop is centred (" .. tostring(backdrop.Position) .. ")")
	local titles = ShopCard.Titles(card)
	assert(#titles == 2 and titles[1].Text == ShopCard.Title and titles[2].Text == ShopCard.Description, place.key .. ": header and description")
	local bolts, oldIcon = 0, 0
	for _, child in card:GetChildren() do
		if child:IsA("ImageLabel") then
			local uri = tostring(child.ImageContent.Uri)
			if uri == ShopCard.Icon then
				bolts += 1
			elseif uri == "rbxassetid://97058106405348" then
				oldIcon += 1
			end
		end
	end
	assert(bolts == 5 and oldIcon == 0, place.key .. ": the bolt wherever 2X Speed shows its icon (icon + 4 sparkles): " .. bolts)
	assert(card.Buy:FindFirstChild("Name").Text == tostring(U4.StaminaPass.PriceRobux), place.key .. ": default price")
	assert(card:FindFirstChild("Gift") and card:FindFirstChild("Buy"), place.key .. ": Buy and Gift")
	assert(ShopCard.Titles(source)[1].Text == "2X Speed", place.key .. ": 2X Speed untouched")
	assert(list:FindFirstChild("Revive"):FindFirstChild("Tittle").Text == "Revive infinitely", place.key .. ": Revive untouched")
	ShopCard.Insert(dm, notes)
	local count = 0
	for _, child in list:GetChildren() do
		if child.Name == ShopCard.Name then
			count += 1
		end
	end
	assert(count == 1 and #notes == 2 and string.find(notes[1], "from 2X Speed", 1, true), place.key .. ": idempotent")
	places[place.key] = dm
end
do
	local dm = places.World1
	local list = ShopCard.PassList(dm)
	list:FindFirstChild(ShopCard.Name):SetAttribute("U4Asset", nil)
	local ok, err = pcall(ShopCard.Insert, dm, {})
	assert(not ok and string.find(tostring(err), "without the U4Asset stamp", 1, true), "an unstamped card stops the build")
	list:FindFirstChild(ShopCard.Name):SetAttribute("U4Asset", ShopCard.Stamp)
end
pass("u4_shop_card (3 places): cloned from 2X Speed into the Pass list, LayoutOrder after the designer's cards, geometry identical, centred backdrop, title/description/bolt/price, idempotent")

----------------------------------------------------------------------
-- 2. The Shop, laid out
----------------------------------------------------------------------
-- A GuiObject's box in its parent's box (w x h), as Roblox resolves it: scale and offset, the
-- UIAspectRatioConstraint (FitWithinMaxSize: the largest box of that shape inside Size;
-- ScaleWithParentSize: the dominant axis decides), the AnchorPoint.
local function box(size, position, anchor, shape, pw, ph)
	local w = size.X.Scale * pw + size.X.Offset
	local h = size.Y.Scale * ph + size.Y.Offset
	if shape and shape.AspectRatio > 0 then
		local ar = shape.AspectRatio
		if shape.AspectType == Enum.AspectType.ScaleWithParentSize then
			if shape.DominantAxis == Enum.DominantAxis.Height then
				w = h * ar
			else
				h = w / ar
			end
		elseif w / h > ar then
			w = h * ar
		else
			h = w / ar
		end
	end
	local x = position.X.Scale * pw + position.X.Offset - anchor.X * w
	local y = position.Y.Scale * ph + position.Y.Offset - anchor.Y * h
	return { x = x, y = y, w = w, h = h }
end

local function shapeOf(object)
	return object:FindFirstChildOfClass("UIAspectRatioConstraint")
end

-- The screens. Room is what the Shop's ScreenGui gets (DeviceSafeInsets; consoles are put on
-- CoreUISafeInsets by ConsoleUiScale: under the top bar).
local SCREENS = {
	{ Name = "PC 1920x1080", W = 1920, H = 1080, Touch = false, Keyboard = true },
	{ Name = "laptop 1366x768", W = 1366, H = 768, Touch = false, Keyboard = true },
	{ Name = "tablet 1024x768", W = 1024, H = 768, Touch = true, Keyboard = false },
	{ Name = "phone 844x390", W = 844 - 2 * 47, H = 390 - 21, Touch = true, Keyboard = false },
	{ Name = "console 1920x1080", W = 1920, H = 1080 - 58, Touch = false, Keyboard = false },
}

-- The Shop window's pixel size on a screen: the designer's Size and shape, grown on compact
-- touch screens by MenuPanelLayout's phone fit (the category bar's span as ShopController gives it).
local function shopWindow(shopGui, screen)
	local frame = shopGui.Shop
	local bar = shopGui.Listbutton
	local shape = shapeOf(frame)
	local w, h = Layout.WindowSize(frame.Size, shape, screen.W, screen.H)
	local above, beside = Layout.Overhang(frame)
	local barShape = bar:FindFirstChildOfClass("UIAspectRatioConstraint")
	local function span(safeWidth, safeHeight)
		local barWidth = bar.Size.X.Scale * safeWidth + bar.Size.X.Offset
		if barShape and barShape.AspectRatio > 0 then
			barWidth = math.min(barWidth, (bar.Size.Y.Scale * safeHeight + bar.Size.Y.Offset) * barShape.AspectRatio)
		end
		local fromCentre = (frame.Position.X.Scale - bar.Position.X.Scale) * safeWidth + frame.Position.X.Offset - bar.Position.X.Offset
		return 2 * (math.abs(fromCentre) + barWidth / 2)
	end
	local _, desktopHeight = Layout.WindowSize(frame.Size, shape, Layout.DesktopScreen.X, Layout.DesktopScreen.Y)
	local fit = Layout.PhoneFit({
		Width = screen.W,
		Height = screen.H,
		TopInset = 0,
		Compact = screen.Touch and HudErgonomics.IsCompact(screen.W, screen.H, screen.Touch, screen.Keyboard),
	}, { Width = w, Height = h, Header = above, Span = math.max(w * (1 + 2 * beside), span(screen.W, screen.H)), MaxHeight = desktopHeight })
	return w * fit.Grow, h * fit.Grow, fit.Grow
end

-- The scroll's content on one screen, with `state` (CanvasScale, PosY[child], SizeY[child]
-- overriding the instances, as ShopController writes them). Returns the canvas (w, h), the
-- window height, every child's box (in canvas pixels) and the Pass list's cards in order.
-- The canvas is CanvasSize in scale of the ScrollingFrame's PARENT (Roblox: "calculated using
-- the parent gui's size"); the owner's screenshot agrees (the Treadmill cards' spacing), and so
-- does the designer's own spacing, which the ScrollingFrame's own size would overlap.
local function lay(shopGui, screen, state)
	local frame = shopGui.Shop
	local scroll = frame.ScrollingFrame
	local fw, fh = shopWindow(shopGui, screen)
	local sw = scroll.Size.X.Scale * fw + scroll.Size.X.Offset
	local sh = scroll.Size.Y.Scale * fh + scroll.Size.Y.Offset
	local canvasScale = state.CanvasScale or scroll.CanvasSize.Y.Scale
	local cw = math.max(scroll.CanvasSize.X.Scale * fw + scroll.CanvasSize.X.Offset, sw)
	local ch = math.max(canvasScale * fh + scroll.CanvasSize.Y.Offset, sh)
	local boxes, order = {}, {}
	for _, child in scroll:GetChildren() do
		if child:IsA("GuiObject") then
			local pos = child.Position
			local size = child.Size
			if state.PosY and state.PosY[child] then
				pos = UDim2.new(pos.X.Scale, pos.X.Offset, state.PosY[child], pos.Y.Offset)
			end
			if state.SizeY and state.SizeY[child] then
				size = UDim2.new(size.X.Scale, size.X.Offset, state.SizeY[child], size.Y.Offset)
			end
			boxes[child] = box(size, pos, child.AnchorPoint, shapeOf(child), cw, ch)
			table.insert(order, child)
		end
	end
	-- The Pass list: visible cards by LayoutOrder (ties in child order), centred, Padding apart.
	local list = scroll.Pass
	local listBox = boxes[list]
	local layout = list:FindFirstChildOfClass("UIListLayout")
	local cards = {}
	for index, child in list:GetChildren() do
		local visible = child:IsA("GuiObject") and child.Visible
		if state.CardVisible and state.CardVisible[child] ~= nil then
			visible = state.CardVisible[child]
		end
		if child:IsA("GuiObject") and visible then
			table.insert(cards, { object = child, index = index })
		end
	end
	table.sort(cards, function(a, b)
		if a.object.LayoutOrder ~= b.object.LayoutOrder then
			return a.object.LayoutOrder < b.object.LayoutOrder
		end
		return a.index < b.index
	end)
	local pad = layout.Padding.Scale * listBox.h + layout.Padding.Offset
	local cursor = 0
	local cardBoxes = {}
	for i, entry in cards do
		local b = box(entry.object.Size, UDim2.new(), Vector2.zero, shapeOf(entry.object), listBox.w, listBox.h)
		b.x = listBox.x + (listBox.w - b.w) / 2
		b.y = listBox.y + cursor
		cursor += b.h + (if i < #cards then pad else 0)
		cardBoxes[i] = { object = entry.object, box = b }
	end
	return {
		CanvasW = cw, CanvasH = ch, WindowH = sh, CanvasScale = canvasScale, Boxes = boxes, Order = order,
		Cards = cardBoxes, ListContent = cursor, Pad = pad, List = list, Scroll = scroll,
	}
end

-- What ShopController measures and hands to ShopCanvasFlow (the same numbers, from the boxes).
local function authoredOf(scroll)
	local authored = { CanvasScale = scroll.CanvasSize.Y.Scale, ListScale = scroll.Pass.Position.Y.Scale, Items = {} }
	for _, child in scroll:GetChildren() do
		if child:IsA("GuiObject") then
			authored.Items[child] = {
				Scale = child.Position.Y.Scale, Offset = child.Position.Y.Offset, SizeScale = child.Size.Y.Scale,
				Anchor = child.AnchorPoint.Y, List = child == scroll.Pass,
			}
		end
	end
	return authored
end

local function reflow(shopGui, screen, state, authored)
	local l = lay(shopGui, screen, state)
	local samples, heights, visible = {}, {}, {}
	for _, child in l.Order do
		local b = l.Boxes[child]
		local item = authored.Items[child]
		local scale = if state.PosY and state.PosY[child] then state.PosY[child] else item.Scale
		table.insert(samples, { Scale = scale, Offset = item.Offset, Anchor = item.Anchor, Top = b.y, Height = b.h })
		heights[child] = b.h
		visible[child] = child.Visible
	end
	local cards = {}
	for _, entry in l.Cards do
		table.insert(cards, { Height = entry.box.h, Visible = true, Added = entry.object:GetAttribute("U4Asset") ~= nil })
	end
	local canvasPx = assert(Flow.MeasureCanvas(samples), "the canvas is measured")
	assert(math.abs(canvasPx - l.CanvasH) < 0.01, "MeasureCanvas finds the canvas height (" .. canvasPx .. " vs " .. l.CanvasH .. ")")
	local plan = assert(Flow.Plan(authored, {
		CanvasPx = canvasPx, CanvasScale = l.CanvasScale, WindowPx = l.WindowH,
		ExtraPx = Flow.ListExtra(cards, l.ListContent), ListContentPx = l.ListContent, Heights = heights, Visible = visible,
	}))
	local nextState = { CanvasScale = plan.CanvasScale, PosY = {}, SizeY = {}, CardVisible = state.CardVisible }
	for child, item in plan.Items do
		nextState.PosY[child] = item.Scale
		nextState.SizeY[child] = item.SizeScale
	end
	return nextState, plan
end

local function describe(b)
	return ("(%.1f, %.1f %.1fx%.1f)"):format(b.x, b.y, b.w, b.h)
end
local function overlaps(a, b, tolerance)
	return a.x < b.x + b.w - tolerance and b.x < a.x + a.w - tolerance and a.y < b.y + b.h - tolerance and b.y < a.y + a.h - tolerance
end
local function titleNamed(l, text)
	for _, child in l.Order do
		if child:IsA("TextLabel") and child.Text == text then
			return child, l.Boxes[child]
		end
	end
	error("no title " .. text)
end
-- Every piece of content: the list's cards and every other visible child (the list frame itself
-- is a box around them far taller than the canvas, never drawn).
local function contentBoxes(l)
	local out = {}
	for _, entry in l.Cards do
		table.insert(out, { name = "Pass." .. entry.object.Name, box = entry.box })
	end
	for _, child in l.Order do
		if child ~= l.List and child.Visible then
			table.insert(out, { name = child.Name .. (if child:IsA("TextLabel") then "(" .. child.Text .. ")" else ""), box = l.Boxes[child] })
		end
	end
	return out
end

local screensChecked = 0
for key, dm in places do
	local shopGui = dm:GetService("StarterGui").Shop
	local scroll = shopGui.Shop.ScrollingFrame
	local list = scroll.Pass
	local card = list:FindFirstChild(ShopCard.Name)
	local starter = list:FindFirstChild("Starter Pack")
	local authored = authoredOf(scroll)
	for _, screen in SCREENS do
		local label = key .. " " .. screen.Name
		-- The designer's layout, the card hidden (as the build leaves it).
		local hidden = { CardVisible = { [card] = false } }
		local designer = lay(shopGui, screen, hidden)
		local _, treadmills0 = titleNamed(designer, "Treadmills")
		local lastDesigner = designer.Cards[#designer.Cards]
		assert(lastDesigner.object == starter, label .. ": Starter Pack is the designer's last card")
		local designerGap = treadmills0.y - (lastDesigner.box.y + lastDesigner.box.h)
		assert(designerGap > 0, label .. ": the designer's list ends above the Treadmills header (" .. designerGap .. ")")

		-- The bug: the card shown, the canvas as authored.
		local shown = { CardVisible = { [card] = true } }
		local broken = lay(shopGui, screen, shown)
		local brokenCard = broken.Cards[#broken.Cards]
		local _, brokenTitle = titleNamed(broken, "Treadmills")
		assert(brokenCard.object == card and overlaps(brokenCard.box, brokenTitle, 0.5),
			label .. ": the simulator reproduces the screenshot (the card over the Treadmills header)")

		-- The fix: ShopCanvasFlow, as ShopController runs it.
		local fixedState, plan = reflow(shopGui, screen, shown, authored)
		local fixed = lay(shopGui, screen, fixedState)
		local last = fixed.Cards[#fixed.Cards]
		local before = fixed.Cards[#fixed.Cards - 1]
		assert(last.object == card and before.object == starter, label .. ": the card is the list's last, after Starter Pack")
		assert(math.abs(last.box.y - (before.box.y + before.box.h) - fixed.Pad) < 0.01, label .. ": the list's gap above the card")
		assert(math.abs(last.box.h - before.box.h) < 0.01 and math.abs(last.box.w - before.box.w) < 0.01
			and math.abs(last.box.x - before.box.x) < 0.01, label .. ": the card's size and column are its siblings'")
		local _, treadmills = titleNamed(fixed, "Treadmills")
		local gap = treadmills.y - (last.box.y + last.box.h)
		assert(math.abs(gap - designerGap) < 0.5, label .. (": the Treadmills header after the card with the designer's gap (%.2f vs %.2f)"):format(gap, designerGap))
		-- Nothing overlaps (the designer's own layout has no overlap either).
		local pieces = contentBoxes(fixed)
		for i = 1, #pieces do
			for j = i + 1, #pieces do
				assert(not overlaps(pieces[i].box, pieces[j].box, 0.5),
					label .. ": " .. pieces[i].name .. " " .. describe(pieces[i].box) .. " overlaps " .. pieces[j].name .. " " .. describe(pieces[j].box))
			end
		end
		-- Nothing clipped, nothing floating: the canvas ends EndRoom of the window under the content.
		local lowest = 0
		for _, piece in pieces do
			local b = piece.box
			assert(b.y >= -0.5 and b.y + b.h <= fixed.CanvasH + 0.5 and b.x >= -0.5 and b.x + b.w <= fixed.CanvasW + 0.5,
				label .. ": " .. piece.name .. " " .. describe(b) .. " outside the canvas " .. fixed.CanvasW .. "x" .. fixed.CanvasH)
			lowest = math.max(lowest, b.y + b.h)
		end
		assert(math.abs(fixed.CanvasH - (lowest + Flow.EndRoom * fixed.WindowH)) < 0.5,
			label .. (": the canvas ends %.1f px under the content (want %.1f)"):format(fixed.CanvasH - lowest, Flow.EndRoom * fixed.WindowH))
		-- Everything above the list stays at its pixels; everything below moved by one card + gap.
		for _, child in designer.Order do
			local a, b = designer.Boxes[child], fixed.Boxes[child]
			if child ~= list then
				local moved = b.y - a.y
				local want = if child.Position.Y.Scale > list.Position.Y.Scale then last.box.h + fixed.Pad else 0
				assert(math.abs(moved - want) < 0.05 and math.abs(b.h - a.h) < 0.05 and math.abs(b.x - a.x) < 0.01 and math.abs(b.w - a.w) < 0.01,
					label .. (": %s moved %.2f px (want %.2f), size kept"):format(child.Name, moved, want))
			end
		end
		-- Stable: measured again, the plan is the same.
		local againState = reflow(shopGui, screen, fixedState, authored)
		assert(not Flow.Differs({ CanvasScale = againState.CanvasScale, Items = (function()
			local items = {}
			for child, y in againState.PosY do
				items[child] = { Scale = y, SizeScale = againState.SizeY[child] }
			end
			return items
		end)() }, { CanvasScale = fixedState.CanvasScale, Items = (function()
			local items = {}
			for child, y in fixedState.PosY do
				items[child] = { Scale = y, SizeScale = fixedState.SizeY[child] }
			end
			return items
		end)() }), label .. ": a second pass changes nothing")
		-- The sidebar's category scroll (smoothScrollToCategory: Position.Y.Scale x the canvas)
		-- still lands on each header.
		for _, name in { "Exclusive", "Server", "Passes", "Treadmills", "Potions", "Codes" } do
			local title, b = titleNamed(fixed, name)
			local target = fixedState.PosY[title] * fixed.CanvasH + title.Position.Y.Offset
			assert(math.abs(target - (b.y + title.AnchorPoint.Y * b.h)) < 0.01, label .. ": the " .. name .. " tab scrolls to its header")
		end

		-- The kill switch hides the card: the designer's pixels come back, the canvas trimmed.
		local offState = reflow(shopGui, screen, { CardVisible = { [card] = false }, CanvasScale = fixedState.CanvasScale, PosY = fixedState.PosY, SizeY = fixedState.SizeY }, authored)
		local off = lay(shopGui, screen, offState)
		for _, child in designer.Order do
			if child ~= list then
				assert(math.abs(off.Boxes[child].y - designer.Boxes[child].y) < 0.05, label .. ": hidden card: " .. child.Name .. " back at the designer's place")
			end
		end
		assert(off.CanvasH < designer.CanvasH and plan.CanvasScale < scroll.CanvasSize.Y.Scale,
			label .. (": the designer's canvas (%.0f px) had %.0f px of nothing under the Codes box; now %.0f"):format(designer.CanvasH, designer.CanvasH - lowest, off.CanvasH))
		screensChecked += 1
	end
end
pass(("the real Shop on %d screens (PC, laptop, tablet, phone fit, console): the bug reproduced; with ShopCanvasFlow the card follows Starter Pack, the Treadmills header keeps the designer's gap, no overlap, nothing clipped or floating, stable, kill switch restores the designer's pixels"):format(screensChecked))

----------------------------------------------------------------------
-- 3. ShopController wires it
----------------------------------------------------------------------
do
	local shop = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/UI/ShopController.client.luau")
	local function has(needle, message)
		assert(string.find(shop, needle, 1, true), "ShopController: " .. (message or needle))
	end
	has('local ShopCanvasFlow = require(ReplicatedStorage.Shared:WaitForChild("ShopCanvasFlow"))')
	has("local authoredCanvas = captureAuthoredCanvas()", "the designer's layout is captured once")
	local capture = assert(string.find(shop, "local authoredCanvas = captureAuthoredCanvas()", 1, true))
	local wire = assert(string.find(shop, "\nwirePassCards()\n", 1, true))
	assert(capture < wire, "captured before anything is changed")
	has("ShopCanvasFlow.MeasureCanvas(samples)", "the canvas is measured from the children")
	has("ShopCanvasFlow.ListExtra(cards, passLayout.AbsoluteContentSize.Y", "the list's extra from the added cards")
	has("ShopCanvasFlow.Plan(authoredCanvas, {", "the plan")
	has('passLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(scheduleReflow)', "reflow when the list's content changes")
	has('ScrollFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(scheduleReflow)', "reflow when the window is resized (phone fit)")
	has('card:GetPropertyChangedSignal("Visible"):Connect(scheduleReflow)', "reflow when a card shows or hides (the kill switch)")
	local open = string.sub(shop, assert(string.find(shop, "local function openPanel()", 1, true)), assert(string.find(shop, "closePanel = function(instant)", 1, true)))
	assert(string.find(open, "scheduleReflow()", 1, true), "reflow on open")
	has("local function orderAddedCards()", "stamped cards after the designer's")
	local order = string.sub(shop, assert(string.find(shop, "local function orderAddedCards()", 1, true)), assert(string.find(shop, "local function wirePassCards()", 1, true)))
	assert(string.find(order, 'GetAttribute("U4Asset")', 1, true) and string.find(order, "LayoutOrder = highest + ", 1, true), "LayoutOrder = the designer's highest + n")
	pass("ShopController: authored layout captured first, reflow on content / resize / visibility / open, stamped cards ordered last")
end

print(("test_u4_shop_layout: %d checks passed"):format(passed))
