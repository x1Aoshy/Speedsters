-- QuestUi.luau
-- The designer's Choose Your Destiny panel (design/ui/Quests.rbxm, generated as
-- Shared.DesignerUi.QuestGui), finished for the game, and its layout on every screen.
--
-- The build runs Decorate once and saves the finished panel in every place's StarterGui
-- (audit/build_ui_prefabs.luau), so it can be seen and edited in Studio. The panel's
-- controller (UI/QuestController) runs it too: on a saved panel every piece is already
-- there and nothing is made; a place without the panel builds the designer's layout from
-- the data module and gets the same pieces.
--
-- What Decorate adds to the designer's layout (the designer's own sizes stay as made):
--   Dim                    a dark backdrop; tapping it closes the panel
--   Frame.UIScale          the panel's one scale: the open / close pop
--   Frame.Timer            "🕒 Resets in: HH:MM:SS" under the title
--   Frame.Close            the game's round close button
--   Frame.Scroller         phones: the cards side by side in a scroll (Layout / Apply)
--   Frame.Confetti         the claim celebration's pieces
--   Frame.Quest1..3        the designer's cards (Quests2, Quests1, Quests2), left to right
--     .TasksTitle / .RewardsTitle   the designer's two headings
--     .list.Task1..4       the task rows: Icon, Title, and a progress Bar with its Fill
--     .RewardTemplate.Reward1..4   the reward icons, each with its Quantity
--     .Choose.PressScale   the button's press bounce and Claim! pulse
--     .Glow                the chosen quest's gold-to-cyan border (off until chosen)
--     .Shade               dims the quests not chosen
--     .Badge               "COMPLETED" once the rewards are claimed

local QuestUi = {}

QuestUi.CloseImage = "rbxassetid://110882579806743"
-- Below this width, or on a touch screen where the designer's cards would come out
-- narrower than CompactCardWidth, the panel takes the phone layout: a compact window at
-- most PhoneHeightShare x PhoneWidthShare of the screen, its three cards sized to fit its
-- height whole (no vertical scroll), side by side when they fit and in a sideways scroll
-- (each at least MinCardWidth wide) when they do not. Phones found the old full-screen
-- window with 260 px cards far too big (2026-09-19).
QuestUi.CompactBelowWidth = 900
QuestUi.CompactCardWidth = 260
QuestUi.MinCardWidth = 150
QuestUi.MinButtonHeight = 22
QuestUi.PhoneHeightShare = 0.84
QuestUi.PhoneWidthShare = 0.92
QuestUi.CloseSize = 44
-- A task's text: at most this share of its row's height.
QuestUi.RowTextShare = 0.3
QuestUi.MinCloseSize = 32

local NAVY = { 11, 27, 61 }
QuestUi.Colors = {
	Gold = Color3.fromRGB(255, 214, 40),
	Cyan = Color3.fromRGB(40, 210, 255),
	Green = Color3.fromRGB(70, 220, 90),
}

-- The Choose button's colours by state, in the designer's recipe (a 3-stop fill under
-- the stud art, a light rim stroke with its own gradient, a dark edge, a dark text
-- outline). The designer's magenta is kept for Choose.
QuestUi.Palettes = {
	Gold = {
		Fill = { { 0, { 255, 240, 130 } }, { 0.46, { 255, 196, 20 } }, { 1, { 226, 132, 0 } } },
		Rim = { { 0, { 255, 250, 205 } }, { 0.64, { 255, 206, 50 } }, { 1, { 170, 96, 0 } } },
		Edge = { 110, 58, 0 },
		Text = { 96, 46, 0 },
	},
	Green = {
		Fill = { { 0, { 160, 255, 120 } }, { 0.46, { 60, 214, 70 } }, { 1, { 16, 140, 40 } } },
		Rim = { { 0, { 225, 255, 205 } }, { 0.64, { 96, 232, 96 } }, { 1, { 10, 100, 30 } } },
		Edge = { 8, 66, 20 },
		Text = { 8, 60, 18 },
	},
	Blue = {
		Fill = { { 0, { 130, 225, 255 } }, { 0.46, { 30, 160, 255 } }, { 1, { 10, 86, 200 } } },
		Rim = { { 0, { 215, 246, 255 } }, { 0.64, { 86, 192, 255 } }, { 1, { 10, 56, 146 } } },
		Edge = { 5, 34, 90 },
		Text = { 5, 30, 80 },
	},
	Grey = {
		Fill = { { 0, { 205, 210, 220 } }, { 0.46, { 142, 148, 162 } }, { 1, { 94, 99, 114 } } },
		Rim = { { 0, { 238, 240, 246 } }, { 0.64, { 172, 177, 188 } }, { 1, { 78, 83, 94 } } },
		Edge = { 44, 47, 58 },
		Text = { 40, 43, 54 },
	},
}

local function rgb(values)
	return Color3.fromRGB(values[1], values[2], values[3])
end

local function sequence(stops)
	local points = {}
	for _, stop in stops do
		table.insert(points, ColorSequenceKeypoint.new(stop[1], rgb(stop[2])))
	end
	return ColorSequence.new(points)
end

-- Rounds every corner: UICorner keeps a radius per corner now.
local function round(object, radius)
	local corner = Instance.new("UICorner")
	pcall(function()
		corner.CornerRadius = radius
	end)
	for _, name in { "TopLeftRadius", "TopRightRadius", "BottomLeftRadius", "BottomRightRadius" } do
		pcall(function()
			corner[name] = radius
		end)
	end
	corner.Parent = object
	return corner
end

local function dropShape(label)
	for _, child in label:GetChildren() do
		if child:IsA("UIAspectRatioConstraint") then
			child:Destroy()
		end
	end
end

-- The designer's cards, left to right (they are named Quests2, Quests1, Quests2 in the
-- file; Decorate names them Quest1..3). On phones they sit in the Scroller.
function QuestUi.Cards(gui)
	local frame = gui:FindFirstChild("Frame")
	if not frame then
		return {}
	end
	local scroller = frame:FindFirstChild("Scroller")
	local cards = {}
	for index = 1, 3 do
		local card = frame:FindFirstChild("Quest" .. index) or (scroller and scroller:FindFirstChild("Quest" .. index))
		if not card then
			cards = nil
			break
		end
		cards[index] = card
	end
	if cards then
		return cards
	end
	local list = {}
	for _, child in frame:GetChildren() do
		if child:IsA("Frame") and child:FindFirstChild("Choose") and child:FindFirstChild("list") then
			table.insert(list, child)
		end
	end
	table.sort(list, function(a, b)
		return a.Position.X.Scale < b.Position.X.Scale
	end)
	return list
end

-- Children of `parent` that are `className` and named `designName` or `prefix`..n, in
-- their order (the designer's copies are all alike, so their order is free).
local function slots(parent, className, designName, prefix)
	local found = {}
	for _, child in parent:GetChildren() do
		if child:IsA(className) and (child.Name == designName or string.match(child.Name, "^" .. prefix .. "%d+$")) then
			table.insert(found, child)
		end
	end
	table.sort(found, function(a, b)
		local na, nb = tonumber(string.match(a.Name, "%d+$")), tonumber(string.match(b.Name, "%d+$"))
		if na and nb then
			return na < nb
		end
		return (na ~= nil) and nb == nil
	end)
	return found
end
QuestUi.Slots = slots

local function decorateRow(row, index)
	if row.Name == "TemplateQuest" then
		row.Name = "Task" .. index
		row.LayoutOrder = index
	end
	local icon = row:FindFirstChild("ImageLabel")
	if icon then
		icon.Name = "Icon"
	end
	-- One line, and no taller than RowTextShare of the row (QuestController sets the cap
	-- from the row's pixel height): wrapped, "Clear 17 Stages (16/17)" filled the row in
	-- two big lines (2026-09-19, "el texto se ve muy grande").
	local title = row:FindFirstChild("Title")
	if title and title:IsA("TextLabel") then
		title.TextWrapped = false
		title.TextScaled = true
		title.TextStrokeTransparency = 1
		title.AnchorPoint = Vector2.new(0, 0.5)
		title.Position = UDim2.fromScale(0.23, 0.5)
		title.Size = UDim2.fromScale(0.73, 0.64)
		local aspect = title:FindFirstChildOfClass("UIAspectRatioConstraint")
		if aspect then aspect:Destroy() end
		for _, outline in title:GetChildren() do
			if outline:IsA("UIStroke") then
				outline.StrokeSizingMode = Enum.StrokeSizingMode.FixedSize
				outline.Thickness = 1.2
			end
		end
		if not title:FindFirstChild("RowTextSize") then
			local cap = Instance.new("UITextSizeConstraint")
			cap.Name = "RowTextSize"
			cap.MinTextSize = 6
			cap.MaxTextSize = 22
			cap.Parent = title
		end
	end
	if row:FindFirstChild("Bar") then
		return
	end
	-- The progress capsule behind the icon and the text; the text keeps its dark outline
	-- over the fill.
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.AnchorPoint = Vector2.new(0, 0.5)
	bar.Position = UDim2.fromScale(0.1, 0.53)
	bar.Size = UDim2.fromScale(0.86, 0.74)
	bar.BackgroundColor3 = rgb(NAVY)
	bar.BackgroundTransparency = 0.4
	bar.BorderSizePixel = 0
	bar.ZIndex = 0
	bar.Visible = false
	round(bar, UDim.new(0.5, 0))
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = QuestUi.Colors.Cyan
	fill.BackgroundTransparency = 0.12
	fill.BorderSizePixel = 0
	fill.ZIndex = 0
	round(fill, UDim.new(0.5, 0))
	local shine = Instance.new("UIGradient")
	shine.Name = "Shine"
	shine.Rotation = 90
	shine.Color = sequence({ { 0, { 255, 255, 255 } }, { 1, { 170, 170, 170 } } })
	shine.Parent = fill
	fill.Parent = bar
	bar.Parent = row
end

local function decorateCard(card, index)
	card.Name = "Quest" .. index
	for _, child in card:GetChildren() do
		if child:IsA("TextLabel") and child.Name == "Title" then
			child.Name = if child.Position.Y.Scale < 0.3 then "TasksTitle" else "RewardsTitle"
		end
	end
	local list = card:FindFirstChild("list")
	if list then
		for rowIndex, row in slots(list, "Frame", "TemplateQuest", "Task") do
			decorateRow(row, rowIndex)
		end
	end
	local rewards = card:FindFirstChild("RewardTemplate")
	if rewards then
		for itemIndex, item in slots(rewards, "ImageLabel", "Item", "Reward") do
			if item.Name == "Item" then
				item.Name = "Reward" .. itemIndex
				item.LayoutOrder = itemIndex
			end
			local amount = item:FindFirstChildOfClass("TextLabel")
			if amount then
				amount.Name = "Quantity"
			end
		end
	end
	local button = card:FindFirstChild("Choose")
	if button and not button:FindFirstChild("PressScale") then
		local press = Instance.new("UIScale")
		press.Name = "PressScale"
		press.Scale = 1
		press.Parent = button
	end
	if not card:FindFirstChild("Glow") then
		local glow = Instance.new("UIStroke")
		glow.Name = "Glow"
		glow.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		glow.Color = Color3.new(1, 1, 1)
		glow.Thickness = 5
		pcall(function()
			glow.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
			glow.Thickness = 0.02
		end)
		glow.Enabled = false
		local shine = Instance.new("UIGradient")
		shine.Name = "Shine"
		shine.Color = sequence({ { 0, { 255, 214, 40 } }, { 0.5, { 40, 210, 255 } }, { 1, { 255, 214, 40 } } })
		shine.Parent = glow
		glow.Parent = card
	end
	if not card:FindFirstChild("Shade") then
		local shade = Instance.new("Frame")
		shade.Name = "Shade"
		shade.BackgroundColor3 = Color3.fromRGB(10, 14, 28)
		shade.BackgroundTransparency = 0.45
		shade.BorderSizePixel = 0
		shade.Size = UDim2.fromScale(1, 1)
		shade.ZIndex = 5
		shade.Visible = false
		round(shade, UDim.new(0.05, 0))
		shade.Parent = card
	end
	local heading = card:FindFirstChild("TasksTitle")
	-- The heading straddles the card's top edge, so the Shade (ZIndex 5) dimmed only its
	-- lower half; it draws above the Shade, whole.
	if heading then
		heading.ZIndex = 6
	end
	if heading and not card:FindFirstChild("Badge") then
		local badge = heading:Clone()
		dropShape(badge)
		badge.Name = "Badge"
		badge.Text = "COMPLETED"
		badge.AnchorPoint = Vector2.new(0.5, 0.5)
		badge.Position = UDim2.fromScale(0.5, 0.42)
		badge.Size = UDim2.fromScale(0.9, 0.13)
		badge.Rotation = -12
		badge.TextColor3 = QuestUi.Colors.Gold
		badge.LineHeight = 1
		badge.ZIndex = 7
		badge.Visible = false
		badge.Parent = card
	end
end

-- Adds what the panel needs to the designer's layout. Safe to run again: pieces that
-- are there already are left alone.
function QuestUi.Decorate(gui)
	gui.DisplayOrder = 20
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local frame = gui:FindFirstChild("Frame")
	assert(frame, "The designer's quest panel has its Frame")
	-- Taps between the cards stay on the panel instead of reaching the Dim behind it.
	frame.Active = true
	for index, card in QuestUi.Cards(gui) do
		decorateCard(card, index)
	end

	if not gui:FindFirstChild("Dim") then
		local dim = Instance.new("TextButton")
		dim.Name = "Dim"
		dim.Text = ""
		dim.AutoButtonColor = false
		dim.BackgroundColor3 = Color3.new(0, 0, 0)
		dim.BackgroundTransparency = 0.5
		dim.BorderSizePixel = 0
		-- Past the edges too, so the top bar's strip is dimmed like the rest.
		dim.AnchorPoint = Vector2.new(0.5, 0.5)
		dim.Position = UDim2.fromScale(0.5, 0.5)
		dim.Size = UDim2.fromScale(3, 3)
		dim.ZIndex = 0
		dim.Parent = gui
	end
	if not frame:FindFirstChild("UIScale") then
		local scale = Instance.new("UIScale")
		scale.Name = "UIScale"
		scale.Scale = 1
		scale.Parent = frame
	end
	local title = frame:FindFirstChild("Title")
	if title and not frame:FindFirstChild("Timer") then
		local timer = title:Clone()
		dropShape(timer)
		timer.Name = "Timer"
		timer.Text = "🕒 Resets in: 00:00:00"
		timer.AnchorPoint = Vector2.new(0.5, 0.5)
		timer.Position = UDim2.fromScale(title.Position.X.Scale, 0.072)
		timer.Size = UDim2.fromScale(0.42, 0.046)
		timer.TextColor3 = QuestUi.Colors.Gold
		timer.LineHeight = 1
		timer.Parent = frame
	end
	if not frame:FindFirstChild("Close") then
		local close = Instance.new("ImageButton")
		close.Name = "Close"
		close.Image = QuestUi.CloseImage
		close.BackgroundTransparency = 1
		close.AnchorPoint = Vector2.new(0.5, 0.5)
		close.Position = UDim2.fromScale(0.965, 0.045)
		close.Size = UDim2.fromScale(0.04, 0.072)
		close.ZIndex = 10
		local shape = Instance.new("UIAspectRatioConstraint")
		shape.AspectRatio = 1
		shape.Parent = close
		close.Parent = frame
	end
	if not frame:FindFirstChild("Scroller") then
		local scroller = Instance.new("ScrollingFrame")
		scroller.Name = "Scroller"
		scroller.BackgroundTransparency = 1
		scroller.BorderSizePixel = 0
		scroller.Size = UDim2.fromScale(1, 1)
		scroller.CanvasSize = UDim2.new()
		scroller.ScrollingDirection = Enum.ScrollingDirection.XY
		scroller.ScrollBarThickness = 6
		scroller.ScrollBarImageColor3 = rgb(NAVY)
		scroller.Selectable = false
		scroller.Visible = false
		scroller.Parent = frame
	end
	if not frame:FindFirstChild("Confetti") then
		local confetti = Instance.new("Frame")
		confetti.Name = "Confetti"
		confetti.BackgroundTransparency = 1
		confetti.Size = UDim2.fromScale(1, 1)
		confetti.ZIndex = 30
		confetti.Parent = frame
	end
	return gui
end

----------------------------------------------------------------------
-- Layout
----------------------------------------------------------------------
-- The designer's placement, read once before any layout changes it: what Apply puts back
-- on a wide screen, and the proportions the phone layout keeps.
function QuestUi.Capture(gui)
	local frame = gui:FindFirstChild("Frame")
	local shape = frame:FindFirstChildOfClass("UIAspectRatioConstraint")
	local cards = QuestUi.Cards(gui)
	local first = cards[1]
	local heading = first:FindFirstChild("TasksTitle") or first:FindFirstChild("Title")
	local button = first:FindFirstChild("Choose")
	local buttonShape = button:FindFirstChildOfClass("UIAspectRatioConstraint")
	local design = {
		Frame = { Position = frame.Position, Size = frame.Size, Aspect = if shape then shape.AspectRatio else 1.8 },
		Pieces = {},
		Cards = {},
	}
	for _, name in { "Title", "Timer", "Close" } do
		local piece = frame:FindFirstChild(name)
		if piece then
			design.Pieces[name] = { Position = piece.Position, Size = piece.Size }
		end
	end
	for index, card in cards do
		design.Cards[index] = { Position = card.Position, Size = card.Size }
	end
	design.FrameWidth = frame.Size.X.Scale
	design.FrameHeight = frame.Size.Y.Scale
	design.CardWidth = first.Size.X.Scale
	design.CardHeight = first.Size.Y.Scale
	-- Card width over height, and how far its heading rises above it and its button
	-- hangs below it, in card heights.
	design.CardAspect = design.CardWidth * design.Frame.Aspect / design.CardHeight
	design.Above = math.max(0, -(heading.Position.Y.Scale - heading.Size.Y.Scale / 2))
	design.Below = button.Position.Y.Scale + button.Size.Y.Scale / 2
	design.ButtonWidth = button.Size.X.Scale
	design.ButtonHeight = button.Size.Y.Scale
	design.ButtonAspect = if buttonShape then buttonShape.AspectRatio else 2.8
	return design
end

-- How tall a Choose button comes out on a card `width` x `height` pixels.
function QuestUi.ButtonHeight(design, width, height)
	return math.min(design.ButtonHeight * height, design.ButtonWidth * width / design.ButtonAspect)
end

-- The panel on a screen area of `screen` pixels (the ScreenGui's size: the viewport less
-- the top bar). Wide screens get the designer's layout (the three cards side by side,
-- sized by the screen). Narrow screens, and touch screens where those cards would be
-- too small to read and tap, get the phone layout: a compact window with the title on
-- top and the cards below it, fitted to its height (see CompactBelowWidth).
function QuestUi.Layout(screen, touch, design)
	local width, height = math.max(1, screen.X), math.max(1, screen.Y)
	local frameWidth = math.min(design.FrameWidth * width, design.FrameHeight * height * design.Frame.Aspect)
	local designCard = design.CardWidth * frameWidth
	local compact = width < QuestUi.CompactBelowWidth or (touch == true and designCard < QuestUi.CompactCardWidth)
	if not compact then
		local cardHeight = designCard / design.CardAspect
		return {
			Compact = false,
			Scale = 1,
			CardWidth = designCard,
			CardHeight = cardHeight,
			ButtonHeight = QuestUi.ButtonHeight(design, designCard, cardHeight),
		}
	end
	local gap = 14
	local maxW = math.max(1, math.floor(width * QuestUi.PhoneWidthShare))
	local maxH = math.max(1, math.floor(height * QuestUi.PhoneHeightShare))
	-- At most the designer's shape, inside the share of the screen.
	local panelWidth = math.min(maxW, math.floor(maxH * design.Frame.Aspect))
	local panelHeight = maxH
	local header = math.clamp(math.floor(panelHeight * 0.15 + 0.5), 38, 64)
	local column = design.Above + design.Below
	-- The cards fill the window's height (whole: no vertical scroll), and sit side by side
	-- when three fit across; otherwise they scroll sideways, each MinCardWidth or more.
	local byHeight = (panelHeight - header - 10) / column * design.CardAspect
	local byWidth = (panelWidth - 4 * gap) / 3
	local cardWidth = math.floor(math.max(1, math.min(byHeight, math.max(QuestUi.MinCardWidth, byWidth))))
	local cardHeight = math.floor(cardWidth / design.CardAspect)
	local rowWidth = 3 * cardWidth + 4 * gap
	local columnHeight = math.ceil(column * cardHeight) + 10
	-- The window shrinks round what it holds, so no empty band is left.
	panelWidth = math.max(math.min(panelWidth, rowWidth), math.min(maxW, 240))
	panelHeight = math.min(panelHeight, header + columnHeight)
	local viewWidth, viewHeight = panelWidth, math.max(1, panelHeight - header)
	local canvasWidth, canvasHeight = math.max(viewWidth, rowWidth), math.max(viewHeight, columnHeight)
	local left = math.floor((canvasWidth - rowWidth) / 2) + gap
	local top = math.floor((canvasHeight - columnHeight) / 2) + 5 + design.Above * cardHeight
	local spots = {}
	for index = 1, 3 do
		spots[index] = {
			X = left + cardWidth / 2 + (index - 1) * (cardWidth + gap),
			Y = top + cardHeight / 2,
		}
	end
	return {
		Compact = true,
		Scale = 1,
		FrameWidth = panelWidth,
		FrameHeight = panelHeight,
		HeaderHeight = header,
		ViewWidth = viewWidth,
		ViewHeight = viewHeight,
		CardWidth = cardWidth,
		CardHeight = cardHeight,
		ButtonHeight = QuestUi.ButtonHeight(design, cardWidth, cardHeight),
		CanvasWidth = canvasWidth,
		CanvasHeight = canvasHeight,
		CloseSize = math.clamp(math.floor(header * 0.8 + 0.5), QuestUi.MinCloseSize, QuestUi.CloseSize),
		Cards = spots,
	}
end

-- Puts the panel in `layout` (from Layout), or back in the designer's placement.
function QuestUi.Apply(gui, design, layout)
	local frame = gui:FindFirstChild("Frame")
	local shape = frame:FindFirstChildOfClass("UIAspectRatioConstraint")
	local scroller = frame:FindFirstChild("Scroller")
	local cards = QuestUi.Cards(gui)
	if layout.Compact then
		local header = layout.HeaderHeight
		frame.Position = UDim2.fromScale(0.5, 0.5)
		frame.Size = UDim2.fromOffset(layout.FrameWidth, layout.FrameHeight)
		if shape then
			shape.AspectRatio = layout.FrameWidth / layout.FrameHeight
		end
		local title, timer, close = frame:FindFirstChild("Title"), frame:FindFirstChild("Timer"), frame:FindFirstChild("Close")
		if title then
			title.Position = UDim2.new(0.5, 0, 0, math.floor(header * 0.3))
			title.Size = UDim2.new(0.7, 0, 0, math.floor(header * 0.56))
		end
		if timer then
			timer.Position = UDim2.new(0.5, 0, 0, math.floor(header * 0.78))
			timer.Size = UDim2.new(0.7, 0, 0, math.floor(header * 0.34))
		end
		if close then
			close.Position = UDim2.new(1, -math.floor(layout.CloseSize / 2) - 2, 0, math.floor(header / 2))
			close.Size = UDim2.fromOffset(layout.CloseSize, layout.CloseSize)
		end
		scroller.Position = UDim2.fromOffset(0, header)
		scroller.Size = UDim2.new(1, 0, 1, -header)
		scroller.CanvasSize = UDim2.fromOffset(layout.CanvasWidth, layout.CanvasHeight)
		scroller.ScrollingDirection = if layout.CanvasHeight > layout.ViewHeight then Enum.ScrollingDirection.XY else Enum.ScrollingDirection.X
		scroller.ElasticBehavior = Enum.ElasticBehavior.Always
		scroller.Visible = true
		for index, card in cards do
			local spot = layout.Cards[index]
			card.Parent = scroller
			card.Position = UDim2.fromOffset(spot.X, spot.Y)
			card.Size = UDim2.fromOffset(layout.CardWidth, layout.CardHeight)
		end
	else
		frame.Position = design.Frame.Position
		frame.Size = design.Frame.Size
		if shape then
			shape.AspectRatio = design.Frame.Aspect
		end
		for name, placement in design.Pieces do
			local piece = frame:FindFirstChild(name)
			if piece then
				piece.Position = placement.Position
				piece.Size = placement.Size
			end
		end
		scroller.Visible = false
		for index, card in cards do
			card.Parent = frame
			card.Position = design.Cards[index].Position
			card.Size = design.Cards[index].Size
		end
	end
end

----------------------------------------------------------------------
-- The Choose button's colours
----------------------------------------------------------------------
-- The button's paintable parts, and the designer's colours to go back to.
function QuestUi.ButtonParts(button)
	local parts = { Button = button, Label = button:FindFirstChild("Name"), Scale = button:FindFirstChild("PressScale") }
	parts.Fill = button:FindFirstChildOfClass("UIGradient")
	for _, child in button:GetChildren() do
		if child:IsA("UIStroke") then
			local shine = child:FindFirstChildOfClass("UIGradient")
			if shine and not parts.Rim then
				parts.Rim, parts.RimShine = child, shine
			elseif not parts.Edge then
				parts.Edge = child
			end
		end
	end
	parts.TextStroke = parts.Label and parts.Label:FindFirstChildOfClass("UIStroke")
	parts.Original = {
		Fill = parts.Fill and parts.Fill.Color,
		Rim = parts.RimShine and parts.RimShine.Color,
		Edge = parts.Edge and parts.Edge.Color,
		Text = parts.TextStroke and parts.TextStroke.Color,
	}
	return parts
end

-- Paints the button with a palette name, or nil for the designer's own colours.
function QuestUi.Paint(parts, paletteName)
	local palette = paletteName and QuestUi.Palettes[paletteName]
	local fill = if palette then sequence(palette.Fill) else parts.Original.Fill
	local rim = if palette then sequence(palette.Rim) else parts.Original.Rim
	local edge = if palette then rgb(palette.Edge) else parts.Original.Edge
	local text = if palette then rgb(palette.Text) else parts.Original.Text
	if parts.Fill and fill then
		parts.Fill.Color = fill
	end
	if parts.RimShine and rim then
		parts.RimShine.Color = rim
	end
	if parts.Edge and edge then
		parts.Edge.Color = edge
	end
	if parts.TextStroke and text then
		parts.TextStroke.Color = text
	end
	parts.Palette = paletteName
end

return QuestUi
