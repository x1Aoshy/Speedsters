-- AdminAbusePanelController.client.luau
-- The game's only admin panel, for admins only. Every button sends one request to
-- Admin/AdminAbusePanelService, which checks permission again.
--
-- Opens from the topbar (TopbarIconsController), with F2, or with /admin or /panel in chat.
--
-- A floating window in the game's own art style, with no dark screen behind it: drag it by
-- its top bar, resize it from its bottom-right corner. Like the Shop and Settings: the
-- blocky stud window (GamePanelStyle.BlockyWindow) with its icon on the top-left corner,
-- light stud panels, the designer's bright stud buttons (a fill lighter on top, a light rim,
-- a dark edge, white words outlined), navy plates behind titles, and the game's own icons
-- on the categories.
--   header:  the This Server / All Servers switch
--   left:    the categories
--   middle:  the category's page, in cards, which scrolls when it runs long
--   right:   who the cards act on: everyone, or one player
--   bottom:  the answer to the last action
-- Everything inside sizes by share of the window, so it reflows as the window resizes.
--
-- The ScreenGui draws sibling by sibling: one made in code draws by global ZIndex unless
-- told otherwise, which once hid every card behind the window's art.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Style = require(Shared:WaitForChild("GamePanelStyle"))
local MenuEvents = require(Shared:WaitForChild("MenuEvents"))
local Panel = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("AdminAbusePanel")
local PlayerGui = player:WaitForChild("PlayerGui")

local WIDTH, HEIGHT = 1040, 660
local MIN_WIDTH, MIN_HEIGHT = 820, 520
local GAP = 12
local HEADER_TOP = 46
local HEADER_HEIGHT = 48
local NAV_WIDTH = 196
local TARGETS_WIDTH = 214
local STATUS_HEIGHT = 34
local BODY_TOP = HEADER_TOP + HEADER_HEIGHT + GAP
local BODY_BOTTOM = GAP + STATUS_HEIGHT + GAP
local CONTENT_LEFT = GAP + NAV_WIDTH + GAP
local CONTENT_RIGHT = GAP + TARGETS_WIDTH + GAP
local NAV_BUTTON_HEIGHT = 50
local SCREEN_MARGIN = 16
local COOLDOWN_SECONDS = 3
local COLORS = {
	Navy = Color3.fromRGB(24, 38, 68),
	Ink = Color3.fromRGB(11, 27, 61),
	Plate = Color3.fromRGB(50, 78, 111),
	Card = Color3.fromRGB(50, 78, 111),
	CardDark = Color3.fromRGB(36, 58, 88),
	Blue = Color3.fromRGB(40, 123, 206),
	Green = Color3.fromRGB(70, 210, 85),
	Red = Color3.fromRGB(225, 70, 70),
	Gold = Color3.fromRGB(255, 211, 33),
	Purple = Color3.fromRGB(150, 80, 230),
	Ice = Color3.fromRGB(90, 190, 255),
	White = Color3.fromRGB(255, 255, 255),
	Muted = Color3.fromRGB(170, 190, 215),
	Help = Color3.fromRGB(44, 62, 96),
}

-- The game's own art, as the Shop, Settings and the designer's panels use it.
local ART = {
	Studs = "rbxassetid://135496826236732", -- the stud texture on the designer's buttons
	ColumnStuds = "rbxassetid://117088684729837", -- the stud sheet behind the Shop's tab column
	Crown = "rbxassetid://113221127098716", -- the Shop's Exclusive crown, the panel's icon
}
-- Each category's icon, from the game's own art; the note stands in where there is none.
local TAB_ICONS = {
	Abuse = "rbxassetid://72658080659794", -- the swirling portal
	Events = "rbxassetid://94279344773398", -- the star
	Boosts = "rbxassetid://123961542220277", -- the lightning bolt (the Shop's Server tab)
	Stats = "rbxassetid://76936003828964", -- the treasure chest (the Shop's Passes tab)
	Treadmills = "rbxassetid://140429435591753", -- the treadmill (the Shop's Treadmills tab)
	Announce = "rbxassetid://102193985057745", -- the scroll (Update Logs)
	Moderation = "rbxassetid://75521963910910", -- the players (Rank Rewards)
}

-- The designer's button colours: a fill lighter on top, a lighter rim inside the edge, a dark
-- edge, and the dark outline on the words (as the Shop's Buy and the Earnings buttons).
local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end
local function fade(top, middle, bottom)
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, top),
		ColorSequenceKeypoint.new(0.5, middle),
		ColorSequenceKeypoint.new(1, bottom),
	})
end
local PALETTES = {
	Green = { Fill = fade(rgb(242, 255, 0), rgb(54, 248, 0), rgb(14, 165, 44)), Rim = fade(rgb(225, 255, 180), rgb(54, 248, 0), rgb(10, 110, 30)), Edge = rgb(10, 60, 20) },
	Blue = { Fill = fade(rgb(120, 225, 255), rgb(30, 150, 255), rgb(20, 80, 210)), Rim = fade(rgb(200, 240, 255), rgb(30, 150, 255), rgb(10, 40, 130)), Edge = rgb(5, 25, 80) },
	Red = { Fill = fade(rgb(255, 150, 125), rgb(245, 45, 60), rgb(170, 10, 40)), Rim = fade(rgb(255, 210, 205), rgb(245, 45, 60), rgb(100, 0, 25)), Edge = rgb(80, 0, 15) },
	Gold = { Fill = fade(rgb(255, 245, 130), rgb(255, 200, 40), rgb(235, 125, 0)), Rim = fade(rgb(255, 252, 215), rgb(255, 200, 40), rgb(150, 75, 0)), Edge = rgb(95, 45, 0) },
	Pink = { Fill = fade(rgb(255, 6, 135), rgb(228, 5, 248), rgb(157, 18, 167)), Rim = fade(rgb(255, 156, 250), rgb(228, 5, 248), rgb(84, 10, 89)), Edge = rgb(67, 0, 67) },
	Purple = { Fill = fade(rgb(210, 155, 255), rgb(150, 80, 235), rgb(90, 30, 170)), Rim = fade(rgb(235, 205, 255), rgb(150, 80, 235), rgb(50, 10, 100)), Edge = rgb(40, 0, 80) },
	Navy = { Fill = fade(rgb(100, 130, 180), rgb(50, 78, 111), rgb(30, 45, 75)), Rim = fade(rgb(160, 190, 230), rgb(50, 78, 111), rgb(15, 25, 50)), Edge = rgb(11, 27, 61) },
}
-- Buttons asked for by colour get the palette of that colour.
local PALETTE_OF = {
	{ COLORS.Green, "Green" },
	{ COLORS.Blue, "Blue" },
	{ COLORS.Red, "Red" },
	{ COLORS.Gold, "Gold" },
	{ COLORS.Purple, "Purple" },
	{ COLORS.Ice, "Blue" },
}
local function paletteName(color)
	if type(color) == "string" then
		return if PALETTES[color] then color else "Navy"
	end
	for _, entry in PALETTE_OF do
		if entry[1] == color then
			return entry[2]
		end
	end
	return "Navy"
end
local HOVER_INFO = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local allowed = false
-- F2 pressed before the permission arrived opens the panel when it does, within this long.
local PENDING_OPEN_SECONDS = 5
local pendingOpenUntil = 0
local isOpen = false
local gui = nil
local scope = "Server"
local selectedTarget = "All"
local tracks = {}
local selectedTrack = nil
local refreshPlayers = nil
local refreshTracks = nil
local showToast = nil
local showTabFromOutside = nil

----------------------------------------------------------------------
-- Building blocks, in the game's art style: light stud panels, bright stud buttons with a
-- rim and a dark edge, white words with a dark outline, navy plates behind titles.
----------------------------------------------------------------------
local function make(className, properties, parent)
	local object = Instance.new(className)
	for key, value in properties do
		object[key] = value
	end
	object.Parent = parent
	return object
end

local function maxText(object, size)
	make("UITextSizeConstraint", { MaxTextSize = size, MinTextSize = 8 }, object)
end

local function text(parent, properties)
	local label = make("TextLabel", {
		BackgroundTransparency = 1,
		TextScaled = true,
		Text = "",
	}, parent)
	Style.Text(label)
	maxText(label, 26)
	for key, value in properties do
		label[key] = value
	end
	return label
end

-- A little lift under the mouse.
local function hover(object)
	local lift = make("UIScale", { Name = "HoverScale" }, object)
	object.MouseEnter:Connect(function()
		TweenService:Create(lift, HOVER_INFO, { Scale = 1.04 }):Play()
	end)
	object.MouseLeave:Connect(function()
		TweenService:Create(lift, HOVER_INFO, { Scale = 1 }):Play()
	end)
end

-- The stud texture over a shape, rounded like it.
local function studs(parent, image, transparency, radius)
	local sheet = make("ImageLabel", {
		Name = "Studs",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Image = image,
		ImageTransparency = transparency,
		ScaleType = Enum.ScaleType.Stretch,
		Active = false,
	}, parent)
	make("UICorner", { CornerRadius = radius }, sheet)
	return sheet
end

-- Gives a designer button (or card) the colours of palette `name`.
local function paint(object, name)
	local palette = PALETTES[paletteName(name)]
	object:SetAttribute("Palette", paletteName(name))
	local fill = object:FindFirstChild("Fill")
	if fill then
		fill.Color = palette.Fill
	end
	local rim = object:FindFirstChild("Rim")
	local rimShade = rim and rim:FindFirstChild("RimShade")
	if rimShade then
		rimShade.Color = palette.Rim
	end
	local edge = object:FindFirstChild("Edge")
	if edge then
		edge.Color = palette.Edge
	end
	local label = object:FindFirstChild("Label")
	local outline = label and label:FindFirstChild("Outline")
	if outline then
		outline.Color = palette.Edge
	end
end

-- A bright stud tile in palette `name`, the designer's button look on a plain frame.
local function tile(parent, name, properties)
	local frame = make("Frame", { BackgroundColor3 = COLORS.White, BorderSizePixel = 0 }, parent)
	make("UICorner", { CornerRadius = UDim.new(0, 14) }, frame)
	make("UIGradient", { Name = "Fill", Rotation = 90 }, frame)
	studs(frame, ART.Studs, 0.3, UDim.new(0, 14))
	local rim = make("UIStroke", { Name = "Rim", Color = COLORS.White, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, frame)
	pcall(function()
		rim.BorderOffset = UDim.new(0, -3)
	end)
	make("UIGradient", { Name = "RimShade", Rotation = 90 }, rim)
	local edge = make("UIStroke", { Name = "Edge", Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, frame)
	pcall(function()
		edge.ZIndex = 2
	end)
	paint(frame, name)
	for key, value in properties or {} do
		frame[key] = value
	end
	return frame
end

-- The designer's button: studs over a bright fill, a light rim inside the edge, a dark edge,
-- and the words in white with a dark outline. The button keeps its words in Text too
-- (hidden), so it reads the same to anything looking for it.
local function button(parent, label, color, properties)
	local object = make("TextButton", {
		BackgroundColor3 = COLORS.White,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = label,
		TextTransparency = 1,
		TextScaled = true,
	}, parent)
	make("UICorner", { CornerRadius = UDim.new(0, 12) }, object)
	make("UIGradient", { Name = "Fill", Rotation = 90 }, object)
	studs(object, ART.Studs, 0.2, UDim.new(0, 12))
	local rim = make("UIStroke", {
		Name = "Rim",
		Color = COLORS.White,
		Thickness = 3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, object)
	-- The rim sits just inside the edge (a newer UIStroke setting, set as the designer's
	-- builder sets it, so an older client simply draws it on the edge).
	pcall(function()
		rim.BorderOffset = UDim.new(0, -3)
	end)
	make("UIGradient", { Name = "RimShade", Rotation = 90 }, rim)
	local edge = make("UIStroke", {
		Name = "Edge",
		Thickness = 3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, object)
	pcall(function()
		edge.ZIndex = 2
	end)
	local words = make("TextLabel", {
		Name = "Label",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -16, 1, -10),
		Font = Enum.Font.FredokaOne,
		TextScaled = true,
		TextColor3 = COLORS.White,
		Text = label,
		Active = false,
	}, object)
	make("UIStroke", { Name = "Outline", Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual }, words)
	maxText(words, 24)
	paint(object, color)
	hover(object)
	for key, value in properties or {} do
		if key == "TextXAlignment" then
			words.TextXAlignment = value
		else
			object[key] = value
		end
	end
	return object
end

-- A field to type in: white, with the game's dark outline.
local function input(parent, placeholder, default, properties)
	local box = make("TextBox", {
		BackgroundColor3 = COLORS.White,
		BorderSizePixel = 0,
		PlaceholderText = placeholder,
		PlaceholderColor3 = Color3.fromRGB(125, 135, 160),
		Text = default or "",
		ClearTextOnFocus = false,
		TextScaled = true,
		Font = Enum.Font.FredokaOne,
		TextColor3 = COLORS.Ink,
	}, parent)
	make("UICorner", { CornerRadius = UDim.new(0, 10) }, box)
	make("UIStroke", { Color = COLORS.Ink, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, box)
	make("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }, box)
	maxText(box, 22)
	for key, value in properties or {} do
		box[key] = value
	end
	return box
end

-- A light stud panel, like the Shop's tab column: white, the stud sheet over it, a dark edge.
local function studPanel(object, radius)
	object.BackgroundColor3 = COLORS.White
	object.BackgroundTransparency = 0.08
	object.BorderSizePixel = 0
	make("UICorner", { CornerRadius = UDim.new(0, radius) }, object)
	make("UIStroke", { Color = COLORS.Ink, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, object)
	make("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(214, 226, 244)),
	}, object)
	studs(object, ART.ColumnStuds, 0.52, UDim.new(0, radius))
end

-- A navy plate, as Settings puts behind each row's name.
local function plate(parent, properties)
	local frame = make("Frame", {
		Name = "Plate",
		BackgroundColor3 = COLORS.Plate,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
	}, parent)
	make("UICorner", { CornerRadius = UDim.new(0, 10) }, frame)
	for key, value in properties or {} do
		frame[key] = value
	end
	return frame
end

local function numberFrom(box, default)
	return tonumber(box.Text) or default
end

-- The width of one item in a row of `count` items 10 px apart, taking `share` of the row.
local function width(share, count)
	return UDim2.new(share, -math.ceil(10 * (count - 1) * share), 1, 0)
end

-- A row of items side by side, `height` px tall.
local function row(parent, height, order)
	local frame = make("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, height),
		LayoutOrder = order,
	}, parent)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 10),
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, frame)
	return frame
end

-- A grid of `columns` cells `cellHeight` px tall, growing downwards.
local function grid(parent, columns, cellHeight, order)
	local frame = make("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
	}, parent)
	make("UIGridLayout", {
		CellSize = UDim2.new(1 / columns, -math.ceil(10 * (columns - 1) / columns), 0, cellHeight),
		CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, frame)
	return frame
end

-- A card on a page: a light stud panel with its title on a navy plate and a line of help
-- under it, holding a column of rows. Returns the column.
local function section(page, icon, title, help, order)
	local outer = make("Frame", {
		Name = title,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
	}, page)
	studPanel(outer, 16)
	local frame = make("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, outer)
	make("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 12), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, frame)
	make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, frame)
	local titlePlate = plate(frame, { Size = UDim2.new(1, 0, 0, 36), LayoutOrder = 0 })
	text(titlePlate, {
		Name = "SectionTitle",
		Text = icon .. "  " .. title,
		Size = UDim2.new(1, -20, 1, -6),
		Position = UDim2.fromOffset(10, 3),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	if help and help ~= "" then
		local helpLabel = text(frame, {
			Name = "Help",
			Text = help,
			TextColor3 = COLORS.Help,
			TextStrokeTransparency = 1,
			Size = UDim2.new(1, 0, 0, 20),
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 1,
		})
		maxText(helpLabel, 18)
	end
	return frame
end

local function send(payload)
	payload.scope = scope
	if payload.target == nil then
		payload.target = selectedTarget
	end
	Panel:FireServer(payload)
end

-- The palettes cards take in turn, so a grid of cards is as bright as the Shop's.
local CARD_PALETTES = { "Pink", "Blue", "Green", "Gold", "Purple", "Red" }

-- A card: a bright stud tile with an icon, a title and a cooldown line; clicking it runs
-- `action`. An action that sends nothing (it returns false, like Moderation with no player
-- picked) starts no cooldown.
local function card(parent, icon, title, action, palette)
	local frame = button(parent, "", palette or "Blue", {})
	frame.Label:Destroy()
	text(frame, { Text = icon, Size = UDim2.fromScale(1, 0.42), Position = UDim2.fromScale(0, 0.05) })
	text(frame, { Text = title, Size = UDim2.fromScale(0.9, 0.26), Position = UDim2.fromScale(0.05, 0.48) })
	local status = text(frame, {
		Text = "Ready",
		Size = UDim2.fromScale(0.9, 0.18),
		Position = UDim2.fromScale(0.05, 0.76),
	})
	local readyAt = 0
	frame.Activated:Connect(function()
		if os.clock() < readyAt then
			return
		end
		if action() == false then
			return
		end
		readyAt = os.clock() + COOLDOWN_SECONDS
		task.spawn(function()
			while os.clock() < readyAt and frame.Parent do
				status.Text = string.format("%.1fs", readyAt - os.clock())
				status.TextColor3 = COLORS.Gold
				task.wait(0.1)
			end
			status.Text = "Ready"
			status.TextColor3 = COLORS.White
		end)
	end)
	return frame
end

-- A row of choice buttons; the picked one turns gold. Returns a function giving the pick.
local function choices(parent, entries, selected, columns, order)
	local holder = grid(parent, columns, 42, order)
	local current = selected
	local buttons = {}
	local function refresh()
		for key, choice in buttons do
			paint(choice, if key == current then "Gold" else "Navy")
		end
	end
	for index, entry in entries do
		local choice = button(holder, entry[2], "Navy", { LayoutOrder = index })
		buttons[entry[1]] = choice
		choice.Activated:Connect(function()
			current = entry[1]
			refresh()
		end)
	end
	refresh()
	return function()
		return current
	end
end

local function pickPlayer()
	if selectedTarget == "All" then
		showToast(false, "Pick one player in the list on the right")
		return false
	end
	return true
end

----------------------------------------------------------------------
-- Pages
----------------------------------------------------------------------
local TABS = {}

-- The names on the troll cards, where they differ from the effect's.
local TROLL_TITLES = { NoGravity = "No Gravity", Snail = "Snail Mode", FakeReset = "Fake Reset" }

function TABS.Abuse(page)
	local trolls = section(page, "😈", "Trolls", "Hit the target picked on the right for a few seconds", 1)
	local settings = row(trolls, 44, 2)
	text(settings, { Text = "Duration (seconds)", Size = width(0.4, 2), TextXAlignment = Enum.TextXAlignment.Left })
	local duration = input(settings, "10", "10", { Size = width(0.2, 2) })
	local cards = grid(trolls, 3, 100, 3)
	for index, entry in {
		{ "🚀", "Rocket" },
		{ "💫", "Ragdoll" },
		{ "⛓️", "Jail" },
		{ "🎈", "Balloon" },
		{ "🐜", "Tiny" },
		{ "🔄", "Inverse" },
		{ "🕹️", "Control" },
		{ "👻", "Jumpscare" },
		{ "🪐", "NoGravity" },
		{ "🐌", "Snail" },
		{ "😱", "FakeReset" },
	} do
		local cardButton = card(cards, entry[1], TROLL_TITLES[entry[2]] or entry[2], function()
			send({ action = "Abuse", effect = entry[2], duration = numberFrom(duration, 10) })
		end, CARD_PALETTES[(index - 1) % #CARD_PALETTES + 1])
		cardButton.LayoutOrder = index
	end
end

function TABS.Events(page)
	local events = section(page, "🎉", "Server events", "Set the seconds, then turn an event on or off (the switch at the top picks the servers)", 1)
	local cells = grid(events, 2, 176, 2)
	for index, entry in {
		{ "🪩", "Disco", "Disco Party", "x2 Speed for everyone, x100 while dancing", "Pink" },
		{ "❄️", "Snow", "Snow Storm", "Snow falls, lava freezes, bosses freeze", "Blue" },
		{ "🌪️", "Sandstorm", "Sandstorm", "A desert storm over the map", "Gold" },
		{ "🎉", "Confetti", "Confetti Party", "Confetti rains on everyone", "Purple" },
		{ "🎆", "Fireworks", "Fireworks", "Rockets burst over the lobby, with a little shake", "Red" },
	} do
		local frame = tile(cells, entry[5], { Name = entry[2], LayoutOrder = index })
		text(frame, { Text = entry[1], Size = UDim2.fromScale(0.3, 0.3), Position = UDim2.fromScale(0.04, 0.05) })
		text(frame, { Text = entry[3], Size = UDim2.fromScale(0.62, 0.18), Position = UDim2.fromScale(0.34, 0.07), TextXAlignment = Enum.TextXAlignment.Left })
		text(frame, { Text = entry[4], TextWrapped = true, Size = UDim2.fromScale(0.62, 0.16), Position = UDim2.fromScale(0.34, 0.25), TextXAlignment = Enum.TextXAlignment.Left })
		text(frame, { Text = "Seconds", Size = UDim2.fromScale(0.4, 0.13), Position = UDim2.fromScale(0.06, 0.48) })
		local duration = input(frame, "60", "60", { Size = UDim2.fromScale(0.42, 0.19), Position = UDim2.fromScale(0.52, 0.45) })
		local on = button(frame, "ON", COLORS.Green, { Size = UDim2.fromScale(0.42, 0.22), Position = UDim2.fromScale(0.05, 0.72) })
		local off = button(frame, "OFF", COLORS.Red, { Size = UDim2.fromScale(0.42, 0.22), Position = UDim2.fromScale(0.53, 0.72) })
		on.Activated:Connect(function()
			send({ action = "Event", name = entry[2], duration = numberFrom(duration, 60), enabled = true })
		end)
		off.Activated:Connect(function()
			send({ action = "Event", name = entry[2], enabled = false })
		end)
	end
end

function TABS.Boosts(page)
	local quickSection = section(page, "⚡", "Quick boosts", "For the whole server, 15 minutes", 1)
	local quick = grid(quickSection, 2, 56, 2)
	for index, entry in { { "2x Speed", "Speed", 2 }, { "4x Speed", "Speed", 4 }, { "2x Wins", "Wins", 2 }, { "5x Wins", "Wins", 5 } } do
		local quickButton = button(quick, entry[1], if entry[2] == "Speed" then COLORS.Blue else COLORS.Green, { LayoutOrder = index })
		quickButton.Activated:Connect(function()
			send({ action = "Boost", stat = entry[2], multiplier = entry[3], minutes = 15 })
		end)
	end
	local customSection = section(page, "🎛️", "Custom boost", "Any multiplier, any minutes", 2)
	local fields = row(customSection, 48, 2)
	text(fields, { Text = "Multiplier", Size = width(0.25, 4) })
	local multiplier = input(fields, "Multiplier", "3", { Size = width(0.25, 4) })
	text(fields, { Text = "Minutes", Size = width(0.25, 4) })
	local minutes = input(fields, "Minutes", "15", { Size = width(0.25, 4) })
	local actions = row(customSection, 52, 3)
	for _, stat in { "Speed", "Wins" } do
		button(actions, "Boost " .. stat, if stat == "Speed" then COLORS.Blue else COLORS.Green, { Size = width(0.5, 2) }).Activated:Connect(function()
			send({ action = "Boost", stat = stat, multiplier = numberFrom(multiplier, 2), minutes = numberFrom(minutes, 15) })
		end)
	end
end

function TABS.Stats(page)
	local give = section(page, "💰", "Manage stats", "Give (+), Take (-), or Set (=) stats for target (Everyone = whole server)", 1)
	local amountRow = row(give, 48, 2)
	text(amountRow, { Text = "Amount", Size = width(0.25, 2), TextXAlignment = Enum.TextXAlignment.Left })
	local amount = input(amountRow, "Amount", "1000", { Size = width(0.75, 2) })

	local statItems = {
		{ "Speed", COLORS.Blue },
		{ "Wins", COLORS.Green },
		{ "Rebirths", COLORS.Purple },
		{ "Tickets", COLORS.Gold },
	}

	local giveRow = grid(give, 4, 46, 3)
	for index, entry in ipairs(statItems) do
		button(giveRow, "+ " .. entry[1], entry[2], { LayoutOrder = index }).Activated:Connect(function()
			send({ action = "GiveStat", stat = entry[1], amount = numberFrom(amount, 0) })
		end)
	end

	local removeRow = grid(give, 4, 46, 4)
	for index, entry in ipairs(statItems) do
		button(removeRow, "- " .. entry[1], entry[2], { LayoutOrder = index }).Activated:Connect(function()
			send({ action = "RemoveStat", stat = entry[1], amount = numberFrom(amount, 0) })
		end)
	end

	local setRow = grid(give, 4, 46, 5)
	for index, entry in ipairs(statItems) do
		button(setRow, "= " .. entry[1], entry[2], { LayoutOrder = index }).Activated:Connect(function()
			send({ action = "SetStat", stat = entry[1], amount = numberFrom(amount, 0) })
		end)
	end

	local passes = section(page, "🎟️", "Gamepasses", "Pick one, then give it to or take it from the target", 2)
	local pass = choices(passes, {
		{ "VIP", "VIP" },
		{ "Flight", "Flight" },
		{ "TwoXSpeed", "2x Speed" },
		{ "TwoXVictory", "2x Victory" },
		{ "InfiniteRevives", "Revives" },
		{ "DarkZonic", "Dark Zonic" },
		{ "All", "All" },
	}, "VIP", 4, 2)
	local passActions = row(passes, 50, 3)
	button(passActions, "Give Pass", COLORS.Green, { Size = width(0.5, 2) }).Activated:Connect(function()
		send({ action = "Pass", pass = pass(), enabled = true })
	end)
	button(passActions, "Remove Pass", COLORS.Red, { Size = width(0.5, 2) }).Activated:Connect(function()
		send({ action = "Pass", pass = pass(), enabled = false })
	end)

	local treadmills = section(page, "🏃", "Treadmills", "Pick one, then give the target that pass treadmill (or take it back)", 3)
	local treadmill = choices(treadmills, {
		{ "Needoh", "Needoh x25" },
		{ "Admin", "Admin x100" },
		{ "Hacker", "Hacker x300" },
		{ "All", "All" },
	}, "Hacker", 4, 2)
	local treadmillActions = row(treadmills, 50, 3)
	button(treadmillActions, "Give Treadmill", COLORS.Green, { Size = width(0.5, 2) }).Activated:Connect(function()
		send({ action = "GrantTreadmill", treadmill = treadmill(), enabled = true })
	end)
	button(treadmillActions, "Remove Treadmill", COLORS.Red, { Size = width(0.5, 2) }).Activated:Connect(function()
		send({ action = "GrantTreadmill", treadmill = treadmill(), enabled = false })
	end)

	local resets = section(page, "♻️", "Resets and rebirths", "Reset Stats clears stats to baseline. Wipe All Data completely resets player to fresh profile.", 4)
	local resetRow = grid(resets, 3, 50, 2)
	button(resetRow, "♻️ Reset Stats", COLORS.Red, { LayoutOrder = 1 }).Activated:Connect(function()
		send({ action = "ResetStats" })
	end)
	button(resetRow, "✨ Force Rebirth", COLORS.Purple, { LayoutOrder = 2 }).Activated:Connect(function()
		send({ action = "ForceRebirth" })
	end)
	button(resetRow, "💥 Wipe All Data", COLORS.Red, { LayoutOrder = 3 }).Activated:Connect(function()
		if selectedTarget == "All" or selectedTarget == nil then
			if showToast then
				showToast(false, "Select a single player on the right to wipe. Never global!")
			end
			return
		end
		send({ action = "WipeData", target = selectedTarget })
	end)

	local codes = section(page, "🎁", "Codes", "Redeem a code for the target", 5)
	local codeRow = row(codes, 50, 2)
	local code = input(codeRow, "Code name", "", { Size = width(0.6, 2) })
	button(codeRow, "Redeem Code", COLORS.Green, { Size = width(0.4, 2) }).Activated:Connect(function()
		send({ action = "RedeemCode", code = code.Text })
	end)

	local travel = section(page, "🌍", "Travel", "Free travel for you, to any world", 6)
	local worlds = grid(travel, 3, 50, 2)
	for world = 1, 3 do
		button(worlds, "World " .. world, COLORS.Blue, { LayoutOrder = world }).Activated:Connect(function()
			send({ action = "Travel", world = world, target = "All" })
		end)
	end
end

function TABS.Treadmills(page)
	local treadmill = section(page, "🏃", "Admin treadmill", "A rainbow ADMIN TREADMILL rises out of the lobby floor on its spot, for everyone to run on", 1)
	local fields = row(treadmill, 48, 2)
	text(fields, { Text = "Multiplier", Size = width(0.25, 4) })
	local multiplier = input(fields, "5", "5", { Size = width(0.25, 4) })
	text(fields, { Text = "Minutes", Size = width(0.25, 4) })
	local minutes = input(fields, "10", "10", { Size = width(0.25, 4) })
	local disco = choices(treadmill, { { false, "No disco" }, { true, "🪩 With a Disco Party" } }, false, 2, 3)
	local actions = row(treadmill, 56, 4)
	button(actions, "Spawn Treadmill", COLORS.Green, { Size = width(0.5, 2) }).Activated:Connect(function()
		send({ action = "Treadmill", multiplier = numberFrom(multiplier, 5), minutes = numberFrom(minutes, 10), withDisco = disco() })
	end)
	button(actions, "Remove All", COLORS.Red, { Size = width(0.5, 2) }).Activated:Connect(function()
		send({ action = "ClearTreadmills" })
	end)
end

function TABS.Music(page)
	local music = section(page, "🎵", "Music", "Pick a track, then play it for the server", 1)
	local body = row(music, 320, 2)
	local list = make("ScrollingFrame", {
		BackgroundColor3 = COLORS.White,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		Size = width(0.64, 2),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = COLORS.Ink,
	}, body)
	make("UICorner", { CornerRadius = UDim.new(0, 12) }, list)
	make("UIStroke", { Color = COLORS.Ink, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, list)
	make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, list)
	make("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 12) }, list)
	local side = make("Frame", { BackgroundTransparency = 1, Size = width(0.36, 2) }, body)
	make("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, side)
	local now = text(side, { Text = "No track picked", Size = UDim2.new(1, 0, 0, 70), TextWrapped = true, LayoutOrder = 1 })
	button(side, "▶ Play", COLORS.Green, { Size = UDim2.new(1, 0, 0, 56), LayoutOrder = 2 }).Activated:Connect(function()
		if not selectedTrack then
			showToast(false, "Pick a track first")
			return
		end
		send({ action = "PlayMusic", trackId = selectedTrack.Id })
	end)
	button(side, "■ Stop", COLORS.Red, { Size = UDim2.new(1, 0, 0, 56), LayoutOrder = 3 }).Activated:Connect(function()
		send({ action = "StopMusic" })
	end)
	refreshTracks = function()
		for _, child in list:GetChildren() do
			if child:IsA("GuiButton") then
				child:Destroy()
			end
		end
		for index, track in tracks do
			local entry = button(list, track.Name, if selectedTrack == track then "Blue" else "Navy", {
				Size = UDim2.new(1, 0, 0, 40),
				LayoutOrder = index,
				TextXAlignment = Enum.TextXAlignment.Left,
			})
			entry.Activated:Connect(function()
				selectedTrack = track
				now.Text = track.Name
				refreshTracks()
			end)
		end
	end
	refreshTracks()
end

-- The banner themes (StarterGui.Messages.MessageHandler draws them), with the colours the
-- preview uses.
local ANNOUNCE_THEMES = {
	{ "Gold", "🟡 Gold", Color3.fromRGB(255, 226, 90), Color3.fromRGB(255, 140, 20) },
	{ "Rainbow", "🌈 Rainbow", Color3.fromRGB(255, 90, 170), Color3.fromRGB(60, 200, 255) },
	{ "Alert", "🚨 Alert", Color3.fromRGB(255, 90, 90), Color3.fromRGB(170, 20, 30) },
	{ "Ice", "❄️ Ice", Color3.fromRGB(170, 235, 255), Color3.fromRGB(40, 140, 230) },
	{ "Party", "🎉 Party", Color3.fromRGB(255, 120, 220), Color3.fromRGB(130, 60, 240) },
}

function TABS.Announce(page)
	local compose = section(page, "📢", "Announcements", "A big banner on every player's screen (the switch at the top picks the servers)", 1)
	local message = input(compose, "Message for every player...", "", {
		Size = UDim2.new(1, 0, 0, 110),
		LayoutOrder = 2,
		MultiLine = true,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextScaled = false,
		TextSize = 22,
	})
	local themeEntries = {}
	for _, entry in ANNOUNCE_THEMES do
		table.insert(themeEntries, { entry[1], entry[2] })
	end
	local theme = choices(compose, themeEntries, "Gold", 5, 3)
	local timing = row(compose, 46, 4)
	text(timing, { Text = "Seconds on screen", Size = width(0.5, 2), TextXAlignment = Enum.TextXAlignment.Left })
	local seconds = input(timing, "8", "8", { Size = width(0.5, 2) })

	-- The preview: the banner's colours and the message as it will read.
	local preview = make("Frame", {
		Name = "Preview",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 70),
		LayoutOrder = 5,
	}, compose)
	make("UICorner", { CornerRadius = UDim.new(0, 14) }, preview)
	make("UIStroke", { Color = COLORS.Ink, Thickness = 3 }, preview)
	local previewFill = make("UIGradient", { Rotation = 90 }, preview)
	local previewText = text(preview, {
		Name = "PreviewText",
		Text = "",
		TextWrapped = true,
		Size = UDim2.new(1, -24, 1, -12),
		Position = UDim2.fromOffset(12, 6),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local function refreshPreview()
		for _, entry in ANNOUNCE_THEMES do
			if entry[1] == theme() then
				previewFill.Color = ColorSequence.new(entry[3], entry[4])
			end
		end
		previewText.Text = if message.Text ~= "" then "📢 " .. message.Text else "📢 Your message shows here"
	end
	message:GetPropertyChangedSignal("Text"):Connect(refreshPreview)
	for _, child in compose:GetDescendants() do
		if child:IsA("TextButton") then
			child.Activated:Connect(refreshPreview)
		end
	end
	refreshPreview()

	button(compose, "📢 Send Global Message", COLORS.Green, { Size = UDim2.new(1, 0, 0, 58), LayoutOrder = 6 }).Activated:Connect(function()
		send({ action = "Announce", message = message.Text, theme = theme(), duration = numberFrom(seconds, 8), target = "All" })
	end)
end

function TABS.Moderation(page)
	local moderation = section(page, "🛡️", "Moderation", "Acts on one player: pick them on the right", 1)
	local fields = row(moderation, 48, 2)
	local reason = input(fields, "Reason", "", { Size = width(0.4, 3) })
	local hours = input(fields, "Ban hours (0 = forever)", "", { Size = width(0.32, 3) })
	local minutes = input(fields, "Mute minutes", "10", { Size = width(0.28, 3) })
	local cards = grid(moderation, 3, 96, 3)
	local function pick(action, extra)
		if not pickPlayer() then
			return false
		end
		local payload = { action = action, target = selectedTarget }
		for key, value in extra or {} do
			payload[key] = value
		end
		send(payload)
		return true
	end
	for index, entry in {
		{ "👢", "Kick", function()
			return pick("Kick", { reason = reason.Text })
		end },
		{ "🔨", "Ban", function()
			return pick("Ban", { reason = reason.Text, hours = numberFrom(hours, 0) })
		end },
		{ "🔇", "Mute", function()
			return pick("Mute", { minutes = numberFrom(minutes, 10) })
		end },
		{ "🔊", "Unmute", function()
			return pick("Unmute")
		end },
		{ "📍", "TP to Player", function()
			return pick("GoTo")
		end },
		{ "🧲", "Bring", function()
			return pick("Bring")
		end },
	} do
		card(cards, entry[1], entry[2], entry[3], CARD_PALETTES[(index - 1) % #CARD_PALETTES + 1]).LayoutOrder = index
	end
	local unbanRow = row(moderation, 48, 4)
	local unbanInput = input(unbanRow, "Username or UserId to Unban", "", { Size = width(0.68, 2) })
	button(unbanRow, "🔓 Unban Player", COLORS.Green, { Size = width(0.32, 2) }).Activated:Connect(function()
		local raw = string.match(unbanInput.Text, "^%s*(.-)%s*$") or ""
		if raw == "" and selectedTarget ~= "All" and selectedTarget ~= nil then
			raw = tostring(selectedTarget)
		end
		if raw == "" then
			if showToast then
				showToast(false, "Enter a Username or UserId to unban")
			end
			return
		end
		send({ action = "Unban", target = raw, userId = raw })
	end)
	local speed = section(page, "⚡", "Speed", "Give or take Speed from the target", 2)
	local speedRow = row(speed, 50, 2)
	local amount = input(speedRow, "Speed amount", "", { Size = width(0.34, 3) })
	button(speedRow, "Give Speed", COLORS.Green, { Size = width(0.33, 3) }).Activated:Connect(function()
		send({ action = "GiveSpeed", amount = numberFrom(amount, 0) })
	end)
	button(speedRow, "Remove Speed", COLORS.Red, { Size = width(0.33, 3) }).Activated:Connect(function()
		send({ action = "RemoveSpeed", amount = numberFrom(amount, 0) })
	end)

	local cosmetics = section(page, "✨", "Cosmetics", "Free, on your own account: every aura, trail and skin, then Aura 67, Trail 67 and Tung Tung Sahur go on", 3)
	local unlockRow = row(cosmetics, 50, 2)
	button(unlockRow, "✨ Unlock All Skins, Auras & Trails", COLORS.Gold, { Size = width(1, 1) }).Activated:Connect(function()
		send({ action = "UnlockCosmetics" })
	end)
end

-- The categories, top to bottom: page, icon, name.
local TAB_ORDER = {
	{ "Abuse", "😈", "Abuse/Trolls" },
	{ "Events", "🎉", "Events" },
	{ "Boosts", "⚡", "Boosts & Mults" },
	{ "Stats", "💰", "Stats & Passes" },
	{ "Treadmills", "🏃", "Treadmills" },
	{ "Music", "🎵", "Music" },
	{ "Announce", "📢", "Announcements" },
	{ "Moderation", "🛡️", "Moderation" },
}

----------------------------------------------------------------------
-- The window
----------------------------------------------------------------------
-- Moving and resizing: the window's centre and size in pixels, kept on the screen.
local function viewport()
	local camera = Workspace.CurrentCamera
	return if camera then camera.ViewportSize else Vector2.new(1280, 720)
end

local function build()
	gui = make("ScreenGui", {
		Name = "AdminAbusePanelGui",
		Enabled = false,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 120,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, PlayerGui)

	local panel, close = Style.BlockyWindow(gui, {
		Name = "Panel",
		Width = WIDTH,
		Height = HEIGHT,
		Title = "Admin Abuse Panel",
	})
	local fit = panel:FindFirstChild("FitScale")
	-- The panel's icon on its top-left corner, as the Shop's basket and Settings' cog (the
	-- game's header-icon bounce picks it up by its name).
	make("ImageLabel", {
		Name = "Icon",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(26, 16),
		Size = UDim2.fromOffset(100, 100),
		Image = ART.Crown,
		ZIndex = 7,
	}, panel)

	-- Drag by the top bar; resize from the corner grip.
	local dragBar = make("TextButton", {
		Name = "DragBar",
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -90, 0, HEADER_TOP),
		ZIndex = 2,
	}, panel)
	local grip = make("TextButton", {
		Name = "ResizeGrip",
		Text = "◢",
		TextScaled = true,
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		TextColor3 = COLORS.Ink,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -4, 1, -2),
		Size = UDim2.fromOffset(30, 30),
		ZIndex = 6,
	}, panel)
	local dragging = nil -- { Kind = "Move" | "Resize", Start = Vector2, Position = UDim2, Size = UDim2 }
	local function beginDrag(kind, inputObject)
		if inputObject.UserInputType ~= Enum.UserInputType.MouseButton1 and inputObject.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		dragging = { Kind = kind, Start = Vector2.new(inputObject.Position.X, inputObject.Position.Y), Position = panel.Position, Size = panel.Size }
	end
	dragBar.InputBegan:Connect(function(inputObject)
		beginDrag("Move", inputObject)
	end)
	grip.InputBegan:Connect(function(inputObject)
		beginDrag("Resize", inputObject)
	end)
	UserInputService.InputChanged:Connect(function(inputObject)
		if not dragging or (inputObject.UserInputType ~= Enum.UserInputType.MouseMovement and inputObject.UserInputType ~= Enum.UserInputType.Touch) then
			return
		end
		local delta = Vector2.new(inputObject.Position.X, inputObject.Position.Y) - dragging.Start
		local view = viewport()
		local scale = if fit then fit.Scale else 1
		if dragging.Kind == "Move" then
			-- The top bar stays reachable: the centre never leaves the screen.
			local x = math.clamp(dragging.Position.X.Offset + delta.X, -view.X / 2, view.X / 2)
			local y = math.clamp(dragging.Position.Y.Offset + delta.Y, -view.Y * 0.52 + 40, view.Y * 0.48)
			panel.Position = UDim2.new(dragging.Position.X.Scale, x, dragging.Position.Y.Scale, y)
		else
			local maxWidth = math.max(MIN_WIDTH, (view.X - SCREEN_MARGIN) / scale)
			local maxHeight = math.max(MIN_HEIGHT, (view.Y - SCREEN_MARGIN) / scale)
			local newWidth = math.clamp(dragging.Size.X.Offset + delta.X / scale, MIN_WIDTH, maxWidth)
			local newHeight = math.clamp(dragging.Size.Y.Offset + delta.Y / scale, MIN_HEIGHT, maxHeight)
			panel.Size = UDim2.fromOffset(newWidth, newHeight)
			-- The top-left corner stays put: the centre moves half of the growth.
			panel.Position = UDim2.new(
				dragging.Position.X.Scale,
				dragging.Position.X.Offset + (newWidth - dragging.Size.X.Offset) * scale / 2,
				dragging.Position.Y.Scale,
				dragging.Position.Y.Offset + (newHeight - dragging.Size.Y.Offset) * scale / 2
			)
		end
	end)
	UserInputService.InputEnded:Connect(function(inputObject)
		if inputObject.UserInputType == Enum.UserInputType.MouseButton1 or inputObject.UserInputType == Enum.UserInputType.Touch then
			dragging = nil
		end
	end)

	-- Header: the scope switch, right-aligned, clear of the close button on the corner.
	local header = make("Frame", {
		Name = "Header",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -2 * GAP, 0, HEADER_HEIGHT),
		Position = UDim2.fromOffset(GAP, HEADER_TOP),
		ZIndex = 3,
	}, panel)
	text(header, {
		Text = "Admins only  ·  drag the top bar, resize from the corner",
		Size = UDim2.new(1, -470, 0, 28),
		Position = UDim2.fromOffset(84, 10),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local scopeButtons = {}
	local function setScope(value)
		scope = value
		for key, scopeButton in scopeButtons do
			paint(scopeButton, if key == value then "Gold" else "Navy")
		end
	end
	for index, entry in { { "Server", "This Server" }, { "All", "All Servers" } } do
		local scopeButton = button(header, entry[2], "Navy", {
			Size = UDim2.fromOffset(170, 44),
			Position = UDim2.new(1, -370 + (index - 1) * 180, 0, 2),
		})
		scopeButtons[entry[1]] = scopeButton
		scopeButton.Activated:Connect(function()
			setScope(entry[1])
		end)
	end

	-- Left: the categories.
	-- The column's stud panel, like the Shop's tab column, sits behind the list itself (a
	-- list layout would line the stud sheet up with the buttons).
	local navBack = make("Frame", {
		Name = "NavBack",
		Size = UDim2.new(0, NAV_WIDTH, 1, -(BODY_TOP + BODY_BOTTOM)),
		Position = UDim2.fromOffset(GAP, BODY_TOP),
		ZIndex = 3,
	}, panel)
	studPanel(navBack, 16)
	local nav = make("ScrollingFrame", {
		Name = "Nav",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(0, NAV_WIDTH, 1, -(BODY_TOP + BODY_BOTTOM)),
		Position = UDim2.fromOffset(GAP, BODY_TOP),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = COLORS.Ink,
		ZIndex = 4,
	}, panel)
	make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, nav)
	make("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, nav)

	-- Middle: the pages.
	local content = make("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -(CONTENT_LEFT + CONTENT_RIGHT), 1, -(BODY_TOP + BODY_BOTTOM)),
		Position = UDim2.fromOffset(CONTENT_LEFT, BODY_TOP),
		ZIndex = 3,
	}, panel)

	-- Right: the target.
	local targets = make("Frame", {
		Name = "Targets",
		Size = UDim2.new(0, TARGETS_WIDTH, 1, -(BODY_TOP + BODY_BOTTOM)),
		Position = UDim2.new(1, -(GAP + TARGETS_WIDTH), 0, BODY_TOP),
		ZIndex = 3,
	}, panel)
	studPanel(targets, 16)
	plate(targets, { Size = UDim2.new(1, -16, 0, 28), Position = UDim2.fromOffset(8, 7) })
	local acting = text(targets, {
		Name = "ActingOn",
		Text = "Target: Everyone",
		Size = UDim2.new(1, -24, 0, 24),
		Position = UDim2.fromOffset(12, 9),
	})
	local everyone = button(targets, "👥 Everyone / All", "Gold", {
		Size = UDim2.new(1, -16, 0, 44),
		Position = UDim2.fromOffset(8, 40),
	})
	local list = make("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -8, 1, -100),
		Position = UDim2.fromOffset(4, 94),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = COLORS.Ink,
	}, targets)
	make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, list)
	make("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 10), PaddingBottom = UDim.new(0, 6) }, list)

	refreshPlayers = function()
		paint(everyone, if selectedTarget == "All" then "Gold" else "Navy")
		acting.Text = "Target: Everyone"
		for _, child in list:GetChildren() do
			if child:IsA("GuiButton") then
				child:Destroy()
			end
		end
		for index, other in Players:GetPlayers() do
			local selected = selectedTarget == other.UserId
			if selected then
				acting.Text = "Target: " .. other.DisplayName
			end
			local entry = button(list, other.DisplayName .. (if other == player then " (you)" else ""), if selected then "Blue" else "Navy", {
				Size = UDim2.new(1, 0, 0, 50),
				LayoutOrder = index,
				TextXAlignment = Enum.TextXAlignment.Left,
			})
			entry.Label.AnchorPoint = Vector2.new(0, 0.5)
			entry.Label.Position = UDim2.new(0, 54, 0.5, 0)
			entry.Label.Size = UDim2.new(1, -62, 0, 26)
			local avatar = make("ImageLabel", {
				Name = "Avatar",
				BackgroundColor3 = COLORS.White,
				BackgroundTransparency = 0.2,
				Size = UDim2.fromOffset(40, 40),
				Position = UDim2.fromOffset(6, 5),
				ZIndex = 3,
			}, entry)
			make("UICorner", { CornerRadius = UDim.new(1, 0) }, avatar)
			make("UIStroke", { Color = COLORS.Ink, Thickness = 2 }, avatar)
			task.spawn(function()
				local ok, image = pcall(function()
					return Players:GetUserThumbnailAsync(other.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
				end)
				if ok and avatar.Parent then
					avatar.Image = image
				end
			end)
			entry.Activated:Connect(function()
				selectedTarget = other.UserId
				refreshPlayers()
			end)
		end
	end
	everyone.Activated:Connect(function()
		selectedTarget = "All"
		refreshPlayers()
	end)
	Players.PlayerAdded:Connect(function()
		refreshPlayers()
	end)
	Players.PlayerRemoving:Connect(function(leaving)
		if selectedTarget == leaving.UserId then
			selectedTarget = "All"
		end
		task.defer(refreshPlayers)
	end)

	-- Bottom: the answer to the last action.
	local HINT = "Pick a category on the left and a target on the right"
	local toast = text(panel, {
		Name = "Toast",
		Text = HINT,
		BackgroundColor3 = COLORS.Plate,
		BackgroundTransparency = 0.35,
		Size = UDim2.new(1, -GAP * 2 - 40, 0, STATUS_HEIGHT),
		Position = UDim2.new(0, GAP, 1, -GAP - STATUS_HEIGHT),
		ZIndex = 3,
	})
	make("UICorner", { CornerRadius = UDim.new(0, 10) }, toast)
	local toastSerial = 0
	showToast = function(ok, message)
		toastSerial += 1
		local serial = toastSerial
		toast.Text = (if ok then "✅ " else "⚠️ ") .. message
		toast.TextColor3 = if ok then COLORS.Green else COLORS.Red
		task.delay(5, function()
			if toastSerial == serial then
				toast.Text = HINT
				toast.TextColor3 = COLORS.White
			end
		end)
	end

	-- The pages and their buttons.
	local pages, navButtons = {}, {}
	local function showTab(name)
		for key, page in pages do
			page.Visible = key == name
			paint(navButtons[key], if key == name then "Gold" else "Navy")
		end
	end
	for index, entry in TAB_ORDER do
		local navButton = button(nav, entry[2] .. "  " .. entry[3], "Navy", {
			Name = entry[1],
			Size = UDim2.new(1, 0, 0, NAV_BUTTON_HEIGHT),
			LayoutOrder = index,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		-- The game's icon on the left, the name beside it.
		navButton.Label.Text = entry[3]
		navButton.Label.AnchorPoint = Vector2.new(0, 0.5)
		navButton.Label.Position = UDim2.new(0, 54, 0.5, 0)
		navButton.Label.Size = UDim2.new(1, -62, 0, 26)
		local art = TAB_ICONS[entry[1]]
		if art then
			make("ImageLabel", {
				Name = "TabIcon",
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 6, 0.5, 0),
				Size = UDim2.fromOffset(42, 42),
				Image = art,
				ZIndex = 3,
			}, navButton)
		else
			text(navButton, {
				Name = "TabIcon",
				Text = entry[2],
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 8, 0.5, 0),
				Size = UDim2.fromOffset(38, 38),
				ZIndex = 3,
			})
		end
		navButtons[entry[1]] = navButton
		local page = make("ScrollingFrame", {
			Name = entry[1],
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 6,
			Visible = false,
		}, content)
		make("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }, page)
		make("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 12) }, page)
		pages[entry[1]] = page
		TABS[entry[1]](page)
		navButton.Activated:Connect(function()
			showTab(entry[1])
		end)
	end

	setScope("Server")
	showTab("Abuse")
	showTabFromOutside = showTab
	refreshPlayers()
	close.Activated:Connect(function()
		MenuEvents.Request("AdminAbuse")
	end)
end

----------------------------------------------------------------------
-- Opening, closing, access
----------------------------------------------------------------------
local function open()
	if not allowed or isOpen then
		return
	end
	if not gui then
		build()
	end
	isOpen = true
	MenuEvents.CloseAll:Fire("AdminAbuse")
	refreshPlayers()
	gui.Enabled = true
end

local function close()
	if not isOpen then
		return
	end
	isOpen = false
	if gui then
		gui.Enabled = false
	end
	-- The Main HUD comes back however the panel was closed (the close button, Escape, F2,
	-- another menu), unless another menu is open by now.
	if not MenuEvents.AnyOpen("AdminAbuse") then
		MenuEvents.SetHUDVisible(true, nil)
	end
end

-- Access confirmed, by the server's AdminAbusePanelAllowed attribute (there from the first
-- frame) or its Permission message. The panel is built right away so the topbar icon finds
-- it to follow; F2 pressed a moment early opens it now.
local function grant()
	if allowed then
		return
	end
	allowed = true
	task.spawn(function()
		if not gui then
			build()
		end
	end)
	if pendingOpenUntil > os.clock() then
		pendingOpenUntil = 0
		MenuEvents.Request("AdminAbuse")
	end
end

Panel.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then
		return
	end
	if payload.kind == "Permission" then
		if type(payload.tracks) == "table" then
			tracks = payload.tracks
			if refreshTracks then
				refreshTracks()
			end
		end
		if payload.allowed == true then
			grant()
		else
			allowed = false
			close()
		end
	elseif payload.kind == "Toast" and showToast then
		showToast(payload.ok == true, tostring(payload.message))
	end
end)

MenuEvents.Get("OpenAdminAbusePanel").Event:Connect(function(action)
	if action == "Close" then
		close()
	elseif action == "Open" then
		open()
	elseif isOpen then
		close()
	else
		open()
	end
end)
MenuEvents.CloseAll.Event:Connect(function(except)
	if except ~= "AdminAbuse" then
		close()
	end
end)
MenuEvents.MarkReady("AdminAbuse", function()
	return isOpen
end)

player:GetAttributeChangedSignal("AdminAbusePanelAllowed"):Connect(function()
	if player:GetAttribute("AdminAbusePanelAllowed") == true then
		grant()
	end
end)
if player:GetAttribute("AdminAbusePanelAllowed") == true then
	grant()
end

UserInputService.InputBegan:Connect(function(inputObject, processed)
	if isOpen and (inputObject.KeyCode == Enum.KeyCode.Escape or inputObject.KeyCode == Enum.KeyCode.ButtonB) then
		MenuEvents.Request("AdminAbuse")
		return
	end
	if processed or inputObject.KeyCode ~= Enum.KeyCode.F2 then
		return
	end
	if allowed then
		MenuEvents.Request("AdminAbuse")
	else
		-- Not confirmed yet: ask again, and open the panel as soon as the answer is yes.
		pendingOpenUntil = os.clock() + PENDING_OPEN_SECONDS
		Panel:FireServer({ action = "Hello" })
	end
end)

-- Chat commands open this panel: /admin and /panel (ChatBoostCommands answers them with
-- AdminPanelStatus "OpenUI"), and /g or /announce with no message
-- (GlobalAnnouncementService's "OpenBar"), on Announcements.
local function openFromChat(tab)
	if not allowed then
		return
	end
	if not isOpen then
		MenuEvents.Request("AdminAbuse")
	end
	if tab and showTabFromOutside then
		showTabFromOutside(tab)
	end
end
task.spawn(function()
	local status = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("AdminPanelStatus", 30)
	if status then
		status.OnClientEvent:Connect(function(payload)
			if type(payload) == "table" and (payload.kind == "OpenUI" or payload.kind == "ToggleUI") then
				openFromChat(nil)
			end
		end)
	end
end)
task.spawn(function()
	local announcements = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("GlobalAnnouncementRequest", 30)
	if announcements then
		announcements.OnClientEvent:Connect(function(action)
			if action == "OpenBar" then
				openFromChat("Announce")
			end
		end)
	end
end)

-- Ask straight away; the answer brings the music list (and access, if the attribute is late).
task.defer(function()
	Panel:FireServer({ action = "Hello" })
end)
