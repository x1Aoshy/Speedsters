-- HeatVisionUi.luau
-- The Heat Vision Trail's HUD button (StarterGui.Mainhud.HeatVisionButton), saved as a real
-- instance in every place (audit/build_ui_prefabs.luau, build_core's ASSETS) so it can be
-- seen and edited in Studio; the client makes it the same way only in a place without it.
-- The designer's Sprint button, copied as it is (colour, outlines, font) and made round,
-- with a pair of eyes shooting red beams drawn on it, the R key's hint in a corner (hidden
-- on phones), a dark cover that drains as the cooldown runs out, and a hint above it for
-- aiming by touch. Hidden until the Superman skin is worn (Movement/HeatVisionClient).
local HeatVisionUi = {}

HeatVisionUi.ButtonName = "HeatVisionButton"
HeatVisionUi.Red = Color3.fromRGB(255, 45, 35)
HeatVisionUi.Ink = Color3.fromRGB(11, 27, 45)

local function make(className, properties, parent)
	local object = Instance.new(className)
	for key, value in properties do
		object[key] = value
	end
	object.Parent = parent
	return object
end

-- Every corner the same radius (UICorner keeps one per corner as well as CornerRadius).
local function round(object, radius)
	local corner = object:FindFirstChildOfClass("UICorner") or make("UICorner", {}, object)
	pcall(function()
		corner.CornerRadius = radius
	end)
	for _, name in { "TopLeftRadius", "TopRightRadius", "BottomLeftRadius", "BottomRightRadius" } do
		pcall(function()
			corner[name] = radius
		end)
	end
	return corner
end
HeatVisionUi.Round = round

local function fredoka(label)
	pcall(function()
		label.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	end)
end

-- An eye: white, with a red iris.
local function eye(parent, x)
	local white = make("Frame", {
		Name = "Eye",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(x, 0.5),
		Size = UDim2.fromScale(0.36, 0.78),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BorderSizePixel = 0,
		ZIndex = 4,
	}, parent)
	round(white, UDim.new(0.5, 0))
	make("UIStroke", { Color = HeatVisionUi.Ink, Thickness = 2 }, white)
	local iris = make("Frame", {
		Name = "Iris",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromScale(0.5, 0.62),
		BackgroundColor3 = HeatVisionUi.Red,
		BorderSizePixel = 0,
		ZIndex = 5,
	}, white)
	round(iris, UDim.new(0.5, 0))
	return white
end

-- A red beam from an eye, down and out.
local function ray(parent, x, rotation)
	local beam = make("Frame", {
		Name = "Ray",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(x, 0.5),
		Size = UDim2.fromScale(0.08, 0.42),
		Rotation = rotation,
		BackgroundColor3 = HeatVisionUi.Red,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, parent)
	round(beam, UDim.new(0.5, 0))
	make("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(255, 220, 120), HeatVisionUi.Red),
		Rotation = 90,
	}, beam)
	return beam
end

-- The designer's Sprint button (Mainhud.MobileSprint, a clone) made into the Heat Vision one.
function HeatVisionUi.DecorateButton(button)
	button.Name = HeatVisionUi.ButtonName
	button.Text = ""
	button.Visible = false
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	round(button, UDim.new(0.5, 0))
	-- Shrinks while pressed (HeatVisionClient).
	if not button:FindFirstChild("PressScale") then
		make("UIScale", { Name = "PressScale", Scale = 1 }, button)
	end

	local icon = make("Frame", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromScale(0.64, 0.64),
		BackgroundTransparency = 1,
		ZIndex = 3,
	}, button)
	make("UIAspectRatioConstraint", { AspectRatio = 1 }, icon)
	local eyes = make("Frame", {
		Name = "Eyes",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.08),
		Size = UDim2.fromScale(0.9, 0.34),
		BackgroundTransparency = 1,
		ZIndex = 3,
	}, icon)
	eye(eyes, 0.25)
	eye(eyes, 0.75)
	ray(icon, 0.3, 18)
	ray(icon, 0.7, -18)

	local word = make("TextLabel", {
		Name = "Word",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.94),
		Size = UDim2.fromScale(0.8, 0.24),
		BackgroundTransparency = 1,
		Text = "HEAT",
		TextScaled = true,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		ZIndex = 4,
	}, button)
	fredoka(word)
	make("UIStroke", { Color = HeatVisionUi.Ink, Thickness = 2 }, word)

	-- The key's hint for keyboards (HeatVisionClient hides it on phones).
	local key = make("TextLabel", {
		Name = "KeyHint",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.86, 0.14),
		Size = UDim2.fromScale(0.34, 0.34),
		BackgroundColor3 = HeatVisionUi.Ink,
		Text = "R",
		TextScaled = true,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		ZIndex = 6,
	}, button)
	fredoka(key)
	round(key, UDim.new(0.5, 0))

	-- The cooldown: a dark cover over the button that drains from the top, and the seconds.
	local cover = make("Frame", {
		Name = "Cooldown",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 7,
	}, button)
	round(cover, UDim.new(0.5, 0))
	local seconds = make("TextLabel", {
		Name = "Seconds",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.62, 0.4),
		BackgroundTransparency = 1,
		Text = "",
		TextScaled = true,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		Visible = false,
		ZIndex = 8,
	}, button)
	fredoka(seconds)
	make("UIStroke", { Color = HeatVisionUi.Ink, Thickness = 2 }, seconds)

	-- Aiming by touch: "Tap where to melt!" over the button while it waits for the tap.
	local hint = make("TextLabel", {
		Name = "AimHint",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 0, 0, -6),
		Size = UDim2.new(3.2, 0, 0.42, 0),
		BackgroundTransparency = 1,
		Text = "Tap where to melt a path!",
		TextScaled = true,
		TextColor3 = Color3.fromRGB(255, 200, 90),
		TextXAlignment = Enum.TextXAlignment.Right,
		Visible = false,
		ZIndex = 8,
	}, button)
	fredoka(hint)
	make("UIStroke", { Color = HeatVisionUi.Ink, Thickness = 2 }, hint)
	return button
end

return HeatVisionUi
