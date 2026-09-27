-- SpinWheelExtras.luau
-- What the Spin Wheel panel adds to the designer's layout: the rarity colours under the
-- prizes, the gold hub cap, the Wins spin (X1 in gold with a Wins icon), and the Robux
-- packs that are not on the designer's row (X10), each button with a caption.
--
-- The build runs this once and saves the finished panel in every place's StarterGui
-- (audit/build_ui_prefabs.luau), so it can be seen and edited in Studio. The panel's
-- controller runs it too: on a saved panel every piece is already there and nothing is
-- made; on a panel without them (an older place) the pieces are made the same way.
-- Positions that depend on the screen (the side buttons) are set by the controller.

local SpinWheelExtras = {}

SpinWheelExtras.WinsGold = { { 0, { 255, 230, 80 } }, { 0.46, { 255, 186, 0 } }, { 1, { 214, 118, 0 } } }
SpinWheelExtras.WinsGoldEdge = { { 0, { 255, 246, 180 } }, { 0.64, { 255, 190, 0 } }, { 1, { 110, 58, 0 } } }
SpinWheelExtras.WinsTag = { { 0, { 255, 244, 140 } }, { 1, { 255, 196, 0 } } }

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

local function namedChild(parent, className, name)
	for _, child in parent:GetChildren() do
		if child:IsA(className) and (name == nil or child.Name == name) then
			return child
		end
	end
	return nil
end
SpinWheelExtras.NamedChild = namedChild

-- A caption under a side button, in the countdown's style.
local function caption(timerLabel, name, text, aspect)
	local label = timerLabel:Clone()
	label.Name = name
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	local shape = label:FindFirstChildOfClass("UIAspectRatioConstraint")
	if shape then
		shape.AspectRatio = aspect
	end
	label.Text = text
	label.Visible = false
	return label
end

-- The slice colours by rarity, between the white art and the prizes.
local function sliceColours(wheel, wheelArt, measure, Layout, Catalog)
	if wheel:FindFirstChild("SliceColours") then
		return
	end
	local layer = Instance.new("Frame")
	layer.Name = "SliceColours"
	layer.BackgroundTransparency = 1
	layer.Size = UDim2.fromScale(1, 1)
	layer.ZIndex = wheelArt.ZIndex + 1
	for _, piece in Layout.SlicePieces(measure) do
		local shape = Instance.new(if piece.Kind == "Studs" then "ImageLabel" else "Frame")
		shape.Name = piece.Kind
		shape.BorderSizePixel = 0
		shape.AnchorPoint = Vector2.new(0.5, 0.5)
		shape.Position = UDim2.fromScale(piece.X, piece.Y)
		shape.Size = UDim2.fromScale(piece.Width, piece.Height)
		shape.Rotation = piece.Rotation
		shape.BackgroundColor3 = rgb(Layout.LineColor)
		if piece.Kind == "Fill" then
			local rarity = Catalog.Segments[piece.Sector].Rarity
			shape.BackgroundColor3 = Color3.new(1, 1, 1)
			local points = {}
			for _, stop in piece.Stops do
				-- Time along the strip (0 = its outer end); shading by distance from the rim.
				table.insert(points, ColorSequenceKeypoint.new(stop.Time, rgb(Catalog.RarityColorAt(rarity, 1 - stop.Share))))
			end
			local gradient = Instance.new("UIGradient")
			gradient.Color = ColorSequence.new(points)
			gradient.Rotation = 90
			gradient.Parent = shape
		elseif piece.Kind == "Studs" then
			shape.BackgroundTransparency = 1
			shape.Image = Layout.StudTexture
			shape.ImageTransparency = Layout.StudTransparency
			shape.ScaleType = Enum.ScaleType.Tile
			shape.TileSize = UDim2.fromScale(piece.TileScale, piece.TileScale)
		elseif piece.Kind == "Ring" then
			shape.BackgroundTransparency = 1
			local stroke = Instance.new("UIStroke")
			stroke.Color = rgb(Layout.LineColor)
			stroke.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
			stroke.BorderStrokePosition = Enum.BorderStrokePosition.Center
			stroke.Thickness = Layout.RingStrokeShare()
			stroke.Parent = shape
		end
		if piece.Kind == "Studs" or piece.Kind == "Dot" or piece.Kind == "Ring" then
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0.5, 0)
			corner.Parent = shape
		end
		shape.Parent = layer
	end
	layer.Parent = wheel
end

-- The hub cap over the centre: a navy rim, a gold studded face, a shine and a shadow.
local function hubCap(wheelHolder, arrow, measure, Layout)
	if wheelHolder:FindFirstChild("HubCap") then
		return
	end
	local cap = Layout.HubCap(measure)
	local holder = Instance.new("Frame")
	holder.Name = "HubCap"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(cap.X, cap.Y)
	holder.Size = UDim2.fromScale(cap.Width, cap.Height)
	holder.ZIndex = arrow.ZIndex - 1
	local square = Instance.new("UIAspectRatioConstraint")
	square.AspectRatio = 1
	square.Parent = holder
	local function circle(name, size, position, color, transparency, zIndex)
		local piece = Instance.new("Frame")
		piece.Name = name
		piece.AnchorPoint = Vector2.new(0.5, 0.5)
		piece.Position = position
		piece.Size = size
		piece.BackgroundColor3 = color
		piece.BackgroundTransparency = transparency
		piece.BorderSizePixel = 0
		piece.ZIndex = zIndex
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = piece
		piece.Parent = holder
		return piece
	end
	circle("Shadow", UDim2.fromScale(1.08, 1.08), UDim2.fromScale(0.5, 0.56), Color3.new(0, 0, 0), 0.6, 1)
	circle("Rim", UDim2.fromScale(1, 1), UDim2.fromScale(0.5, 0.5), rgb(Layout.HubCapRim), 0, 2)
	local face = circle("Face", UDim2.fromScale(0.78, 0.78), UDim2.fromScale(0.5, 0.5), Color3.new(1, 1, 1), 0, 3)
	local gold = Layout.HubCapGold
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, rgb(gold[1])),
		ColorSequenceKeypoint.new(0.46, rgb(gold[2])),
		ColorSequenceKeypoint.new(1, rgb(gold[3])),
	})
	gradient.Parent = face
	local studs = Instance.new("ImageLabel")
	studs.Name = "Studs"
	studs.AnchorPoint = Vector2.new(0.5, 0.5)
	studs.Position = UDim2.fromScale(0.5, 0.5)
	studs.Size = UDim2.fromScale(0.78, 0.78)
	studs.BackgroundTransparency = 1
	studs.Image = Layout.StudTexture
	studs.ImageTransparency = Layout.StudTransparency - 0.1
	studs.ScaleType = Enum.ScaleType.Tile
	studs.TileSize = UDim2.fromScale(0.5, 0.5)
	studs.ZIndex = 4
	local studCorner = Instance.new("UICorner")
	studCorner.CornerRadius = UDim.new(0.5, 0)
	studCorner.Parent = studs
	studs.Parent = holder
	local shine = circle("Shine", UDim2.fromScale(0.34, 0.18), UDim2.fromScale(0.4, 0.3), Color3.new(1, 1, 1), 0.55, 5)
	shine.Rotation = -28
	holder.Parent = wheelHolder
end

local function winsSpin(wheelHolder, row, timerLabel, Layout, Catalog)
	local source = row:FindFirstChild("X1")
	local existing = wheelHolder:FindFirstChild("WinsSpin")
	if existing then
		local icon = namedChild(existing, "ImageLabel")
		if icon then
			icon.Image = "rbxassetid://15540211845"
			icon.ScaleType = Enum.ScaleType.Fit
			local tint = icon:FindFirstChildOfClass("UIGradient")
			if tint then tint.Enabled = false end
		end
		return
	end
	if not source then
		return
	end
	local button = source:Clone()
	button.Name = "WinsSpin"
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Rotation = 0
	local fill = namedChild(button, "UIGradient")
	if fill then
		fill.Color = sequence(SpinWheelExtras.WinsGold)
	end
	for _, stroke in button:GetChildren() do
		if stroke:IsA("UIStroke") then
			local edge = stroke:FindFirstChildOfClass("UIGradient")
			if edge then
				edge.Color = sequence(SpinWheelExtras.WinsGoldEdge)
			else
				stroke.Color = Color3.fromRGB(92, 48, 0)
			end
		end
	end
	local word = namedChild(button, "TextLabel", "Name")
	if word then
		word.Text = "X1"
		local stroke = word:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = Color3.fromRGB(78, 40, 0)
		end
	end
	local price = namedChild(button, "TextLabel", "Price")
	if price then
		local tag = price:FindFirstChildOfClass("UIGradient")
		if tag then
			tag.Color = sequence(SpinWheelExtras.WinsTag)
		end
	end
	local icon = namedChild(button, "ImageLabel")
	if icon then
		icon.Image = Catalog.IconImages.Wins
		icon.ScaleType = Enum.ScaleType.Fit
		local tint = icon:FindFirstChildOfClass("UIGradient")
		if tint then
			tint.Enabled = false
		end
	end
	button.Visible = false
	button.Parent = wheelHolder
	caption(timerLabel, "WinsCaption", "", Layout.CaptionAspect).Parent = wheelHolder
end

-- A Robux pack whose button is not on the designer's row (X10): a copy of X3.
local function sidePack(wheelHolder, row, timerLabel, product, Layout)
	local source = row:FindFirstChild("X3")
	if not product.Button or row:FindFirstChild(product.Button) or wheelHolder:FindFirstChild(product.Button) or not source then
		return
	end
	local button = source:Clone()
	button.Name = product.Button
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Rotation = 0
	local word = namedChild(button, "TextLabel", "Name")
	if word then
		word.Text = product.Button
	end
	local price = namedChild(button, "TextLabel", "Price")
	if price and product.PriceRobux then
		price.Text = tostring(product.PriceRobux)
	end
	button.Visible = false
	button.Parent = wheelHolder
	caption(timerLabel, product.Button .. "Caption", product.Caption or "", Layout.CaptionAspect).Parent = wheelHolder
end

-- The holder carries the scale the compact (phone) layout grows the panel by
-- (SpinWheelLayout.Compact; 1 = the designer's size). The wheel keeps the designer's own
-- 1:1 UIAspectRatioConstraint, so it stays a circle at any size.
local function shapePieces(wheelHolder, wheel)
	if not wheelHolder:FindFirstChild("CompactScale") then
		local scale = Instance.new("UIScale")
		scale.Name = "CompactScale"
		scale.Scale = 1
		scale.Parent = wheelHolder
	end
end

-- Adds every missing piece to the designer's panel `gui`. `products` are the Robux packs
-- (Config.SpinWheel.Products).
function SpinWheelExtras.Decorate(gui, products, Layout, Catalog)
	local wheelHolder = gui:FindFirstChild("Frame")
	local wheel = wheelHolder:FindFirstChild("Spin Wheel")
	local wheelArt = wheel:FindFirstChildOfClass("ImageLabel")
	local arrow = wheelHolder:FindFirstChild("Arrow")
	local row = gui:FindFirstChild("Button")
	local timerLabel = row:FindFirstChild("TextLabel")
	shapePieces(wheelHolder, wheel)
	local measure = Layout.Measure(wheelHolder)
	sliceColours(wheel, wheelArt, measure, Layout, Catalog)
	hubCap(wheelHolder, arrow, measure, Layout)
	winsSpin(wheelHolder, row, timerLabel, Layout, Catalog)
	for _, product in products or {} do
		sidePack(wheelHolder, row, timerLabel, product, Layout)
	end
end

return SpinWheelExtras
