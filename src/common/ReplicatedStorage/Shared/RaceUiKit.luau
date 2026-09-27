-- ReplicatedStorage/Shared/RaceUiKit.luau — Update 4 (2026-09-25): the race UI's style recipe,
-- the game's blocky look as the admin panel draws it (Admin/AdminAbusePanelController PALETTES,
-- paint, tile, button, studPanel, plate; that controller is not refactored, these are copies):
-- a bright 3-stop fill with the stud sheet over it, a light rim inside the edge, a dark edge,
-- white FredokaOne words with the ink (11,27,45) outline.
-- Every constructor comes from `env` ({ Instance, UDim, UDim2, Vector2, Color3, ColorSequence,
-- ColorSequenceKeypoint, NumberSequence, NumberSequenceKeypoint, Enum, Font }): the Roblox
-- globals in the game, @lune/roblox in audit/test_u4_race_ui, so RaceUiBuilder can build the
-- whole race UI without a running game. Nothing here yields, connects or tweens.
local RaceUiKit = {}
RaceUiKit.__index = RaceUiKit

RaceUiKit.Art = {
	Studs = "rbxassetid://135496826236732", -- the stud texture on the designer's buttons
	ColumnStuds = "rbxassetid://117088684729837", -- the stud sheet behind the Shop's tab column
	Lightning = "rbxassetid://123961542220277", -- the lightning bolt (the Shop's Server tab)
	BlockyBackground = "rbxassetid://106477372921851", -- GamePanelStyle.BlockyWindow's art
	Close = "rbxassetid://110882579806743", -- GamePanelStyle.BlockyWindow's close button
	Trophy = "rbxassetid://76936003828964", -- the treasure chest (the Shop's Passes tab)
}

-- { r, g, b } triples, turned into Color3 by the kit (pure data, readable in Lune).
RaceUiKit.Colors = {
	Ink = { 11, 27, 45 },
	InkBlue = { 11, 27, 61 },
	White = { 255, 255, 255 },
	Navy = { 24, 38, 68 },
	Plate = { 50, 78, 111 },
	Card = { 96, 118, 150 },
	Gold = { 255, 211, 33 },
	Silver = { 200, 210, 225 },
	Bronze = { 205, 127, 50 },
	Cyan = { 0, 235, 255 },
	Lime = { 215, 255, 70 },
	Purple = { 190, 95, 255 },
	PurpleEdge = { 40, 0, 80 },
	Zone = { 60, 230, 120 },
	Core = { 255, 210, 60 },
	Overheat = { 235, 60, 50 },
	Go = { 90, 235, 90 },
	Red = { 235, 60, 60 },
	Muted = { 170, 190, 215 },
	Track = { 20, 32, 58 },
}

-- The bar fills: top -> bottom stops.
RaceUiKit.SpeedFill = { { 0, { 120, 225, 255 } }, { 0.5, { 30, 150, 255 } }, { 1, { 20, 80, 210 } } }
RaceUiKit.StaminaFill = { { 0, { 150, 250, 255 } }, { 0.5, { 0, 235, 255 } }, { 1, { 0, 160, 210 } } }
RaceUiKit.LowFill = { { 0, { 255, 150, 125 } }, { 0.5, { 245, 45, 60 } }, { 1, { 170, 10, 40 } } }

-- The designer's palettes (AdminAbusePanelController PALETTES): fill, rim and edge.
RaceUiKit.Palettes = {
	Green = { Fill = { { 242, 255, 0 }, { 54, 248, 0 }, { 14, 165, 44 } }, Rim = { { 225, 255, 180 }, { 54, 248, 0 }, { 10, 110, 30 } }, Edge = { 10, 60, 20 } },
	Blue = { Fill = { { 120, 225, 255 }, { 30, 150, 255 }, { 20, 80, 210 } }, Rim = { { 200, 240, 255 }, { 30, 150, 255 }, { 10, 40, 130 } }, Edge = { 5, 25, 80 } },
	Red = { Fill = { { 255, 150, 125 }, { 245, 45, 60 }, { 170, 10, 40 } }, Rim = { { 255, 210, 205 }, { 245, 45, 60 }, { 100, 0, 25 } }, Edge = { 80, 0, 15 } },
	Gold = { Fill = { { 255, 245, 130 }, { 255, 200, 40 }, { 235, 125, 0 } }, Rim = { { 255, 252, 215 }, { 255, 200, 40 }, { 150, 75, 0 } }, Edge = { 95, 45, 0 } },
	Pink = { Fill = { { 255, 6, 135 }, { 228, 5, 248 }, { 157, 18, 167 } }, Rim = { { 255, 156, 250 }, { 228, 5, 248 }, { 84, 10, 89 } }, Edge = { 67, 0, 67 } },
	Purple = { Fill = { { 210, 155, 255 }, { 150, 80, 235 }, { 90, 30, 170 } }, Rim = { { 235, 205, 255 }, { 150, 80, 235 }, { 50, 10, 100 } }, Edge = { 40, 0, 80 } },
	Navy = { Fill = { { 100, 130, 180 }, { 50, 78, 111 }, { 30, 45, 75 } }, Rim = { { 160, 190, 230 }, { 50, 78, 111 }, { 15, 25, 50 } }, Edge = { 11, 27, 61 } },
}

-- The globals as an env, in the game (nil in plain Lune without @lune/roblox).
function RaceUiKit.GlobalEnv(): any?
	if (Instance :: any) == nil then
		return nil
	end
	return {
		Instance = Instance, UDim = UDim, UDim2 = UDim2, Vector2 = Vector2, Color3 = Color3,
		ColorSequence = ColorSequence, ColorSequenceKeypoint = ColorSequenceKeypoint,
		NumberSequence = NumberSequence, NumberSequenceKeypoint = NumberSequenceKeypoint,
		Enum = Enum, Font = Font,
	}
end

function RaceUiKit.new(env: any?)
	local e = env or RaceUiKit.GlobalEnv()
	assert(e and e.Instance, "RaceUiKit needs an env with Instance (the Roblox globals or @lune/roblox)")
	return setmetatable({ env = e }, RaceUiKit)
end

function RaceUiKit:rgb(values: { number }): any
	return self.env.Color3.fromRGB(values[1], values[2], values[3])
end

function RaceUiKit:color(name: string): any
	return self:rgb(RaceUiKit.Colors[name] or RaceUiKit.Colors.White)
end

-- A ColorSequence from { { time, { r, g, b } }, ... } or three colours (top, middle, bottom).
function RaceUiKit:sequence(stops: any): any
	local env = self.env
	local points = {}
	if type(stops[1]) == "table" and type(stops[1][1]) == "number" and type(stops[1][2]) == "table" then
		for _, stop in stops do
			table.insert(points, env.ColorSequenceKeypoint.new(stop[1], self:rgb(stop[2])))
		end
	else
		for index, values in stops do
			table.insert(points, env.ColorSequenceKeypoint.new((index - 1) / math.max(1, #stops - 1), self:rgb(values)))
		end
	end
	return env.ColorSequence.new(points)
end

function RaceUiKit:make(className: string, properties: { [string]: any }?, parent: any?): any
	local object = self.env.Instance.new(className)
	for key, value in properties or {} do
		object[key] = value
	end
	if parent then
		object.Parent = parent
	end
	return object
end

function RaceUiKit:corner(parent: any, radius: number?, scale: number?): any
	local r = if scale then self.env.UDim.new(scale, 0) else self.env.UDim.new(0, radius or 12)
	return self:make("UICorner", { CornerRadius = r }, parent)
end

function RaceUiKit:stroke(parent: any, colorName: string?, thickness: number?, contextual: boolean?): any
	local Enum = self.env.Enum
	return self:make("UIStroke", {
		Color = self:color(colorName or "Ink"),
		Thickness = thickness or 2,
		ApplyStrokeMode = if contextual then Enum.ApplyStrokeMode.Contextual else Enum.ApplyStrokeMode.Border,
	}, parent)
end

-- White FredokaOne words with the ink outline. `size` sets a fixed TextSize (TextScaled off:
-- labels that change several times a second never pay the scaling pass); nil scales.
function RaceUiKit:text(parent: any, name: string, properties: { [string]: any }?, size: number?): any
	local Enum = self.env.Enum
	local label = self:make("TextLabel", {
		Name = name,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Font = Enum.Font.FredokaOne,
		TextColor3 = self:color("White"),
		Text = "",
		TextScaled = size == nil,
		TextSize = size or 14,
		TextWrapped = false,
		AutoLocalize = false,
		Active = false,
	}, parent)
	self:make("UIStroke", {
		Name = "Outline",
		Color = self:color("Ink"),
		Thickness = 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
	}, label)
	if size == nil then
		self:make("UITextSizeConstraint", { MaxTextSize = 48, MinTextSize = 11 }, label)
	end
	for key, value in properties or {} do
		label[key] = value
	end
	return label
end

-- The stud texture over a shape, rounded like it.
function RaceUiKit:studs(parent: any, image: string?, transparency: number?, radius: number?): any
	local Enum = self.env.Enum
	local sheet = self:make("ImageLabel", {
		Name = "Studs",
		BackgroundTransparency = 1,
		Size = self.env.UDim2.fromScale(1, 1),
		Image = image or RaceUiKit.Art.Studs,
		ImageTransparency = transparency or 0.3,
		ScaleType = Enum.ScaleType.Stretch,
		Active = false,
		ZIndex = 1,
	}, parent)
	self:corner(sheet, radius or 12)
	return sheet
end

-- Gives a tile or button the colours of palette `name`.
function RaceUiKit:paint(object: any, name: string)
	local palette = RaceUiKit.Palettes[name] or RaceUiKit.Palettes.Navy
	object:SetAttribute("Palette", if RaceUiKit.Palettes[name] then name else "Navy")
	local fill = object:FindFirstChild("Fill")
	if fill then
		fill.Color = self:sequence(palette.Fill)
	end
	local rim = object:FindFirstChild("Rim")
	local rimShade = rim and rim:FindFirstChild("RimShade")
	if rimShade then
		rimShade.Color = self:sequence(palette.Rim)
	end
	local edge = object:FindFirstChild("Edge")
	if edge then
		edge.Color = self:rgb(palette.Edge)
	end
	local label = object:FindFirstChild("Label")
	local outline = label and label:FindFirstChild("Outline")
	if outline then
		outline.Color = self:rgb(palette.Edge)
	end
end

local function rimAndEdge(kit: any, object: any, radius: number)
	local Enum = kit.env.Enum
	kit:make("UIGradient", { Name = "Fill", Rotation = 90 }, object)
	kit:studs(object, RaceUiKit.Art.Studs, 0.25, radius)
	local rim = kit:make("UIStroke", { Name = "Rim", Color = kit:color("White"), Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, object)
	pcall(function()
		rim.BorderOffset = kit.env.UDim.new(0, -3)
	end)
	kit:make("UIGradient", { Name = "RimShade", Rotation = 90 }, rim)
	local edge = kit:make("UIStroke", { Name = "Edge", Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, object)
	pcall(function()
		edge.ZIndex = 2
	end)
end

-- A bright stud tile (a frame) in palette `name`.
function RaceUiKit:tile(parent: any, name: string, palette: string, properties: { [string]: any }?, radius: number?): any
	local frame = self:make("Frame", { Name = name, BackgroundColor3 = self:color("White"), BorderSizePixel = 0 }, nil)
	self:corner(frame, radius or 14)
	rimAndEdge(self, frame, radius or 14)
	self:paint(frame, palette)
	for key, value in properties or {} do
		frame[key] = value
	end
	frame.Parent = parent
	return frame
end

-- The designer's button: the tile look with its words in a "Label" child (the button keeps
-- them in Text too, hidden, so anything looking for it reads the same).
function RaceUiKit:button(parent: any, name: string, label: string, palette: string, properties: { [string]: any }?, textSize: number?): any
	local object = self:make("TextButton", {
		Name = name,
		BackgroundColor3 = self:color("White"),
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = label,
		TextTransparency = 1,
		TextScaled = true,
		Selectable = true,
		AutoLocalize = false,
	}, nil)
	self:corner(object, 12)
	rimAndEdge(self, object, 12)
	local words = self:text(object, "Label", {
		AnchorPoint = self.env.Vector2.new(0.5, 0.5),
		Position = self.env.UDim2.fromScale(0.5, 0.5),
		Size = self.env.UDim2.new(1, -16, 1, -10),
		Text = label,
		ZIndex = 3,
	}, textSize)
	words.Outline.Thickness = 2
	self:paint(object, palette)
	for key, value in properties or {} do
		object[key] = value
	end
	object.Parent = parent
	return object
end

-- A light stud panel (the Shop's tab column): white, the stud sheet over it, a dark edge.
function RaceUiKit:studPanel(object: any, radius: number)
	object.BackgroundColor3 = self:color("White")
	object.BackgroundTransparency = 0.08
	object.BorderSizePixel = 0
	self:corner(object, radius)
	self:stroke(object, "Ink", 3)
	self:make("UIGradient", { Rotation = 90, Color = self:sequence({ { 255, 255, 255 }, { 214, 226, 244 } }) }, object)
	self:studs(object, RaceUiKit.Art.ColumnStuds, 0.52, radius)
end

-- A navy plate, as Settings puts behind each row's name.
function RaceUiKit:plate(parent: any, name: string, properties: { [string]: any }?): any
	local frame = self:make("Frame", {
		Name = name,
		BackgroundColor3 = self:color("Plate"),
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
	}, nil)
	self:corner(frame, 10)
	for key, value in properties or {} do
		frame[key] = value
	end
	frame.Parent = parent
	return frame
end

-- A bar: a dark track, a "Fill" frame (Size.X is the value) with a 3-stop gradient, the ink
-- edge, and a centred "Text" label. Rounded h/2.
function RaceUiKit:bar(parent: any, name: string, stops: any, textSize: number?): any
	local UDim2 = self.env.UDim2
	local track = self:make("Frame", {
		Name = name,
		BackgroundColor3 = self:color("Track"),
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
	}, nil)
	self:corner(track, nil, 0.5)
	self:stroke(track, "Ink", 3)
	local fill = self:make("Frame", {
		Name = "Fill",
		BackgroundColor3 = self:color("White"),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
	}, track)
	self:corner(fill, nil, 0.5)
	self:make("UIGradient", { Name = "Shade", Rotation = 90, Color = self:sequence(stops) }, fill)
	self:studs(fill, RaceUiKit.Art.Studs, 0.55, 99).ZIndex = 2
	self:text(track, "Text", { Size = UDim2.fromScale(1, 1), ZIndex = 4 }, textSize)
	track.Parent = parent
	return track
end

return RaceUiKit
