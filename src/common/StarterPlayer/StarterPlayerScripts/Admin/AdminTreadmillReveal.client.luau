-- AdminTreadmillReveal.client.luau
-- The show every player on the server gets when an admin spawns the admin treadmill
-- (Admin/AdminAbusePanelService sends { kind = "TreadmillReveal" } on AdminAbusePanel):
--
--   1. The ground rumbles: the camera trembles harder and harder, black bars close in,
--      the world goes grey, and the words "Something powerful is coming..." then
--      "What is this feeling?" shake on the screen.
--   2. BOOM: a white flash, a shockwave ring and one big hit of the quake.
--   3. The card: "<admin> spawned an ADMIN TREADMILL!" in rainbow over spinning rays, with
--      the admin's avatar, the multiplier, the time left, and a GO! button that sends the
--      player onto the treadmill from wherever they are (AdminTreadmillGo).
--
-- All through the rumble the treadmill climbs out of the ground, shaking, in a cloud of
-- dust, and locks into place on the boom. A player who is not near it is flown there: the
-- screen dips to white, the camera circles the treadmill while it rises, and dips back to
-- the player once it has landed.
--
-- One loop drives every moment of it from the time since it began, so it plays the same
-- on every frame rate. A new reveal replaces the one on screen.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Panel = Remotes:WaitForChild("AdminAbusePanel")
local GoRemote = Remotes:WaitForChild("AdminTreadmillGo")
-- The Taco Treadmill does not climb out of the ground: it comes down from the sky inside a
-- giant taco and leaves a crater (Shared/TacoMeteor).
local Shared = ReplicatedStorage:WaitForChild("Shared")
local TacoMeteor = require(Shared:WaitForChild("TacoMeteor"))
local TacoVisual = require(Shared:WaitForChild("TacoVisual"))
local TacoFire = require(Shared:WaitForChild("TacoFire"))
local InterfaceHider = require(Shared:WaitForChild("InterfaceHider"))
-- The letterbox and the card's fit on phones (2026-09-22): thin bars, the card and GO! kept on screen.
local CinematicFit = require(Shared:WaitForChild("CinematicFit"))
local GuiService = game:GetService("GuiService")
local INTERFACE_OWNER = "AdminTreadmillReveal" -- this script's hold on Shared/InterfaceHider
-- True on the player (client side, like WorldPortalCinematicActive) while this reveal has the
-- camera, for anything else that should wait for the flight to be over.
local CINEMATIC_ATTRIBUTE = "AdminTreadmillCinematicActive"
local UserInputService = game:GetService("UserInputService")
local LOW_POWER = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local INK = Color3.fromRGB(11, 27, 45)
local GOLD = Color3.fromRGB(255, 211, 33)
local GREEN = Color3.fromRGB(70, 210, 85)
local WHITE = Color3.new(1, 1, 1)
local BLOCKY_BACKGROUND = "rbxassetid://106477372921851" -- GamePanelStyle.BlockyBackground
local CLOSE_IMAGE = "rbxassetid://110882579806743" -- GamePanelStyle.CloseImage
local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
	ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 190, 40)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(120, 235, 80)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(60, 200, 255)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(160, 90, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 80, 80)),
})

-- Seconds from the start of the reveal.
local TIMELINE = {
	BarsIn = 0.45,
	WhisperAt = 0.3,
	WhisperOut = 1.45,
	FeelingAt = 1.6,
	FeelingOut = 2.5,
	Boom = 2.7,
	CardRise = 2.4, -- after the card opens, it glides up out of the way
	CardSeconds = 15, -- after it opens, the card closes on its own
	CloseSeconds = 0.3,
}
local WHISPER = "Something powerful is coming..."
local FEELING = "What is this feeling?"

-- The treadmill rising: from how far under its place, starting when.
local RISE = { From = 0.35, Clearance = 1.5 }
-- The flight to the treadmill for a player away from it.
local CINEMA = {
	FarAway = 90, -- further than this from the treadmill, the camera goes there
	CutIn = 0.3,
	CutOut = TIMELINE.Boom + 1.9,
	Dip = 0.25, -- the white dip either side of each cut
	Radius = 46,
	Closer = 8, -- the camera drifts this much closer while it circles
	Height = 16,
	Spin = 0.18, -- radians a second round the treadmill
}

-- The card, in pixels before it is fitted to the screen.
local CARD = { Width = 720, Height = 236, Pad = 24, Avatar = 128, Column = 176 }

-- Swap an id here if a sound is not to your taste.
local SOUNDS = {
	Rumble = { Id = "rbxasset://sounds/collide.wav", Volume = 1.2, Speed = 0.28, Looped = true },
	Boom = { Id = "rbxasset://sounds/collide.wav", Volume = 2.5, Speed = 0.5 },
	Reveal = { Id = "rbxassetid://80736831159506", Volume = 0.8, Speed = 1 },
	Go = { Id = "rbxasset://sounds/swordlunge.wav", Volume = 1, Speed = 1 },
	-- The taco meteor: "Cannon_Explode" under the boom. It is uploaded by Roblox, so it plays in
	-- any experience; another creator's private audio would stay silent. (The fall had a rocket
	-- whoosh; the user found it wrong for a taco and it is gone: the fall has no sound of its own.)
	TacoImpact = { Id = "rbxassetid://3149249837", Volume = 2.4, Speed = 0.8 },
}

----------------------------------------------------------------------
-- Pieces
----------------------------------------------------------------------
local function make(className, properties, parent)
	local object = Instance.new(className)
	for key, value in properties do
		object[key] = value
	end
	object.Parent = parent
	return object
end

local function clamp01(value)
	return math.clamp(value, 0, 1)
end

-- 0 before `from`, 1 after `from + length`, eased out in between.
local function easeOut(t, from, length)
	local x = clamp01((t - from) / length)
	return 1 - (1 - x) ^ 3
end

-- Overshoots a little before it settles, like a pop.
local function easeBack(t, from, length)
	local x = clamp01((t - from) / length)
	local c1, c3 = 1.70158, 2.70158
	return 1 + c3 * (x - 1) ^ 3 + c1 * (x - 1) ^ 2
end

-- How hard the ground shakes: building up to the boom, one big hit, then dying away.
local function quakeStrength(t)
	if t < 0 then
		return 0
	elseif t < TIMELINE.Boom then
		local build = t / TIMELINE.Boom
		return 0.12 + 0.88 * build * build
	end
	return 1.8 * math.exp(-(t - TIMELINE.Boom) * 3.5)
end

local function escape(text)
	return (tostring(text):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"):gsub("'", "&apos;"))
end

local function play(sound)
	local object = Instance.new("Sound")
	object.SoundId = sound.Id
	object.Volume = sound.Volume
	object.PlaybackSpeed = sound.Speed
	object.Looped = sound.Looped == true
	object.Parent = SoundService
	pcall(function()
		object:Play()
	end)
	if not object.Looped then
		task.delay(8, function()
			object:Destroy()
		end)
	end
	return object
end

local function shakenText(name, text, parent)
	local label = make("TextLabel", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Font = Enum.Font.FredokaOne,
		TextScaled = true,
		TextColor3 = WHITE,
		TextTransparency = 1,
		Text = text,
		ZIndex = 20,
	}, parent)
	make("UIStroke", { Name = "Outline", Color = INK, Thickness = 4, Transparency = 1 }, label)
	return label
end

-- A bright band slid across a rounded shape: the shine on the card and the GO button.
local function shine(parent, corner)
	local band = make("Frame", {
		Name = "Shine",
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = parent.ZIndex + 1,
	}, parent)
	make("UICorner", { CornerRadius = corner }, band)
	return make("UIGradient", {
		Rotation = 20,
		Offset = Vector2.new(-1, 0),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.42, 1),
			NumberSequenceKeypoint.new(0.5, 0.55),
			NumberSequenceKeypoint.new(0.58, 1),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, band)
end

local function viewport()
	local camera = Workspace.CurrentCamera
	return if camera then camera.ViewportSize else Vector2.new(1280, 720)
end

-- The top bar's height (Roblox's own buttons), 0 when it cannot be read.
local function topBarInset()
	local ok, inset = pcall(function()
		return GuiService:GetGuiInset()
	end)
	return if ok and typeof(inset) == "Vector2" then inset.Y else 0
end

-- LETTERBOX LAYOUT BEGIN
-- The card's footprint: the card, its 6 px rainbow border, and the close button standing 12 px
-- out of its top-right corner.
local CARD_REACH = 12
-- The bars and the card on this screen (2026-09-22, owner: on wide phones the 0.11 bars cropped
-- the card and GO!). On a phone the bars are 0.05 of the height; the card gets the largest scale
-- <= 1 at which all of it fits between the bars and inside the safe area (top bar, notch, home
-- indicator), pops in at 0.45 of the screen moved just enough to stay in that band, and rises
-- towards the top once the bars have gone, still under the top bar. On a computer it is 0.11
-- bars and scale 1, as before. Worked out again every frame, so a rotated or resized screen
-- follows at once.
local function cardLayout(view, phoneHint, topBar)
	local isPhone = CinematicFit.IsPhone(view.X, view.Y, phoneHint)
	local bar = CinematicFit.Bars(view.X, view.Y, isPhone)
	local insets = CinematicFit.Insets(view.X, view.Y, isPhone, topBar)
	local band = CinematicFit.Band(view.X, view.Y, bar, insets)
	local footW, footH = CARD.Width + 2 * CARD_REACH, CARD.Height + 2 * CARD_REACH
	-- The pop overshoots (easeBack peaks at x1.1): the fit leaves room for it.
	local peak = CinematicFit.PopPeak
	local fit = CinematicFit.Fit(footW * peak, footH * peak, band.W, band.H)
	local height = footH * fit
	local popY = CinematicFit.Clamp(view.Y * 0.45, height * peak, band.Y, band.Y + band.H)
	-- Risen, the bars have gone: a phone keeps it inside the safe area; a computer, as before,
	-- only on the screen (its top bar's buttons are in the corners, the card in the middle).
	local safe = CinematicFit.Band(view.X, view.Y, 0, if isPhone then insets else nil)
	local riseY = CinematicFit.Clamp(view.Y * 0.25, height, safe.Y, safe.Y + safe.H)
	return {
		Bar = bar,
		Fit = fit,
		PopY = popY / view.Y,
		RiseY = riseY / view.Y,
		Band = band,
		Safe = safe,
		Footprint = Vector2.new(footW, footH),
	}
end
-- LETTERBOX LAYOUT END

local function adminTreadmill()
	local folder = Workspace:FindFirstChild("AdminSpawnedTreadmills")
	if not folder then return nil end
	return folder:FindFirstChild("TacoTreadmill") or folder:FindFirstChild("AdminTreadmill") or folder:FindFirstChildWhichIsA("Model")
end

-- The treadmill's parts as they stand, and its footprint: the middle of its base and its
-- height.
local function treadmillStage(model)
	local parts = {}
	local low, high = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, { Part = descendant, CFrame = descendant.CFrame, CanCollide = descendant.CanCollide })
		end
		-- The tacos hung on the Taco Treadmill move with it but do not count towards its size
		-- (the crater and the giant taco are sized by the treadmill itself).
		local decor = descendant:GetAttribute("TacoDecor") == true
			or (descendant.Parent and descendant.Parent:GetAttribute("TacoDecor") == true)
		if descendant:IsA("BasePart") and not decor then
			local half = descendant.Size / 2
			for _, x in { -1, 1 } do
				for _, y in { -1, 1 } do
					for _, z in { -1, 1 } do
						local corner = descendant.CFrame:PointToWorldSpace(Vector3.new(half.X * x, half.Y * y, half.Z * z))
						low = Vector3.new(math.min(low.X, corner.X), math.min(low.Y, corner.Y), math.min(low.Z, corner.Z))
						high = Vector3.new(math.max(high.X, corner.X), math.max(high.Y, corner.Y), math.max(high.Z, corner.Z))
					end
				end
			end
		end
	end
	if #parts == 0 then
		return nil
	end
	return {
		Parts = parts,
		Centre = Vector3.new((low.X + high.X) / 2, low.Y, (low.Z + high.Z) / 2),
		Size = high - low,
	}
end

-- 0 far from `at`, 1 at it: a white dip that hides a camera cut.
local function dip(t, at)
	if t < at then
		return clamp01(1 - (at - t) / CINEMA.Dip)
	end
	return clamp01(1 - (t - at) / (CINEMA.Dip * 1.4))
end

----------------------------------------------------------------------
-- The reveal
----------------------------------------------------------------------
local current = nil -- the reveal on screen: { Stop = function }

local function reveal(payload)
	if current then
		current.Stop()
	end
	local byName = string.sub(tostring(payload.byName or "An admin"), 1, 32)
	local byUserId = tonumber(payload.byUserId) or 0
	local multiplier = math.floor(tonumber(payload.multiplier) or 1)
	local speedGain = math.floor(tonumber(payload.speedGain) or 315)
	local expiresAt = tonumber(payload.expiresAt) or 0
	local isTaco = payload.isTaco == true

	local gui = make("ScreenGui", {
		Name = "AdminTreadmillReveal",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 170,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, PlayerGui)

	-- 1. The rumble.
	local tint = make("Frame", {
		Name = "Tint",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
	}, gui)
	local barTop = make("Frame", {
		Name = "BarTop",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.fromScale(1, 0.11),
		ZIndex = 30,
	}, gui)
	local barBottom = make("Frame", {
		Name = "BarBottom",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0.11),
		ZIndex = 30,
	}, gui)
	local whisper = shakenText("Whisper", if isTaco then "Something is falling from the sky..." else WHISPER, gui)
	whisper.Size = UDim2.fromScale(0.72, 0.075)
	whisper.MaxVisibleGraphemes = 0
	local whisperConstraint = make("UITextSizeConstraint", { MaxTextSize = 54 }, whisper)
	local feeling = shakenText("Feeling", if isTaco then "IS THAT... A GIANT TACO?!" else FEELING, gui)
	feeling.Size = UDim2.fromScale(0.86, 0.13)
	local feelingConstraint = make("UITextSizeConstraint", { MaxTextSize = 96 }, feeling)
	local feelingColor = make("UIGradient", {
		Rotation = 90,
		Color = if isTaco then ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 230, 40)),
			ColorSequenceKeypoint.new(0.55, Color3.fromRGB(255, 120, 20)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 30, 10)),
		}) else ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 120, 255)),
			ColorSequenceKeypoint.new(0.55, Color3.fromRGB(150, 70, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 20, 140)),
		}),
	}, feeling)
	local feelingScale = make("UIScale", { Scale = 0.6 }, feeling)
	local grade = make("ColorCorrectionEffect", { Name = "AdminTreadmillQuake" }, Lighting)

	-- 2. The boom.
	local flash = make("Frame", {
		Name = "Flash",
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 40,
	}, gui)
	local shockwave = make("Frame", {
		Name = "Shockwave",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(0, 0),
		Visible = false,
		ZIndex = 35,
	}, gui)
	make("UIAspectRatioConstraint", { AspectRatio = 1, DominantAxis = Enum.DominantAxis.Height }, shockwave)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, shockwave)
	local ring = make("UIStroke", { Color = GOLD, Thickness = 18, Transparency = 0 }, shockwave)

	-- 3. The card, over spinning rays.
	local rays = make("Frame", {
		Name = "Rays",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(1000, 1000),
		Visible = false,
		ZIndex = 8,
	}, gui)
	local rayScale = make("UIScale", { Scale = 1 }, rays)
	local rayBars = {}
	for index = 0, 5 do
		local bar = make("Frame", {
			Name = "Ray",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0, 70, 1, 0),
			Rotation = index * 30,
			BackgroundColor3 = Color3.fromRGB(255, 236, 150),
			BorderSizePixel = 0,
			ZIndex = 8,
		}, rays)
		make("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, 0.25),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}, bar)
		table.insert(rayBars, bar)
	end

	local card = make("Frame", {
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(CARD.Width, CARD.Height),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Active = true,
		Visible = false,
		ZIndex = 10,
	}, gui)
	make("UICorner", { CornerRadius = UDim.new(0, 22) }, card)
	local border = make("UIStroke", { Color = WHITE, Thickness = 6, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, card)
	local borderRainbow = make("UIGradient", { Color = RAINBOW }, border)
	local art = make("ImageLabel", {
		Name = "Background",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Image = BLOCKY_BACKGROUND,
		ImageTransparency = 0.15,
		ScaleType = Enum.ScaleType.Stretch,
		ZIndex = 10,
	}, card)
	make("UICorner", { CornerRadius = UDim.new(0, 22) }, art)
	local cardShine = shine(card, UDim.new(0, 22))
	local cardScale = make("UIScale", { Scale = 0 }, card)

	local avatar = make("Frame", {
		Name = "Avatar",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, CARD.Pad, 0.5, 0),
		Size = UDim2.fromOffset(CARD.Avatar, CARD.Avatar),
		BackgroundColor3 = Color3.fromRGB(40, 60, 100),
		ZIndex = 12,
	}, card)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, avatar)
	make("UIStroke", { Color = GOLD, Thickness = 5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, avatar)
	local headshot = make("ImageLabel", {
		Name = "Headshot",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 13,
	}, avatar)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, headshot)
	if isTaco then
		headshot.Image = "rbxassetid://84855954319870"
		headshot.Size = UDim2.fromScale(0.8, 0.8)
		headshot.Position = UDim2.fromScale(0.1, 0.1)
	elseif byUserId > 0 then
		task.spawn(function()
			local ok, image = pcall(function()
				return Players:GetUserThumbnailAsync(byUserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
			end)
			if ok and headshot.Parent then
				headshot.Image = image
			end
		end)
	end

	local columnWidth = CARD.Width - CARD.Column - 64 -- clear of the close button
	local kicker = make("TextLabel", {
		Name = "Kicker",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(CARD.Column, 26),
		Size = UDim2.fromOffset(columnWidth, 34),
		Font = Enum.Font.FredokaOne,
		TextScaled = true,
		RichText = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = WHITE,
		Text = if isTaco then "LIMITED-TIME EVENT" else '<font color="#FFD84A">' .. escape(byName) .. "</font> spawned an",
		ZIndex = 12,
	}, card)
	make("UIStroke", { Color = INK, Thickness = 3 }, kicker)
	local title = make("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(CARD.Column, 60),
		Size = UDim2.fromOffset(columnWidth, 70),
		Font = Enum.Font.FredokaOne,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = WHITE,
		Text = if isTaco then "🌮 TACO TREADMILL! 🌮" else "ADMIN TREADMILL!",
		ZIndex = 12,
	}, card)
	make("UIStroke", { Color = INK, Thickness = 5 }, title)
	local titleRainbow = make("UIGradient", {
		Color = if isTaco then ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 230, 40)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 130, 20)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 50, 20)),
		}) else RAINBOW,
	}, title)

	local function chip(name, x, width, color, textColor, text)
		local frame = make("Frame", {
			Name = name,
			Position = UDim2.fromOffset(x, 154),
			Size = UDim2.fromOffset(width, 44),
			BackgroundColor3 = color,
			ZIndex = 12,
		}, card)
		make("UICorner", { CornerRadius = UDim.new(0, 12) }, frame)
		make("UIStroke", { Color = INK, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, frame)
		local label = make("TextLabel", {
			Name = "Label",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, -16, 1, -12),
			Font = Enum.Font.FredokaOne,
			TextScaled = true,
			TextColor3 = textColor,
			Text = text,
			ZIndex = 13,
		}, frame)
		return label
	end

	local multWidth = 220
	local timerWidth = 86
	local timerX = CARD.Column + multWidth + 8

	chip("Multiplier", CARD.Column, multWidth, GOLD, INK, (if isTaco then "🌮 x" else "x") .. speedGain .. " SPEED + x" .. multiplier .. " WINS")
	local timer = chip("Timer", timerX, timerWidth, Color3.fromRGB(18, 24, 38), WHITE, "")

	local goX = CARD.Width - CARD.Pad - 124
	local goWidth = 124

	local go = make("TextButton", {
		Name = "Go",
		Position = UDim2.fromOffset(goX, 154),
		Size = UDim2.fromOffset(goWidth, 44),
		BackgroundColor3 = GREEN,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 12,
	}, card)
	make("UICorner", { CornerRadius = UDim.new(0, 12) }, go)
	make("UIStroke", { Color = INK, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, go)
	make("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(WHITE, Color3.fromRGB(190, 190, 190)),
	}, go)
	local goLabel = make("TextLabel", {
		Name = "Label",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -12, 1, -8),
		Font = Enum.Font.FredokaOne,
		TextScaled = true,
		TextColor3 = WHITE,
		Text = "GO!",
		ZIndex = 14,
	}, go)
	make("UIStroke", { Color = INK, Thickness = 3 }, goLabel)
	local goShine = shine(go, UDim.new(0, 12))
	local goScale = make("UIScale", { Scale = 1 }, go)

	local close = make("ImageButton", {
		Name = "Close",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -20, 0, 20),
		Size = UDim2.fromOffset(64, 64),
		BackgroundTransparency = 1,
		Image = CLOSE_IMAGE,
		ZIndex = 15,
	}, card)

	local cut = make("Frame", {
		Name = "Cut",
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 44,
	}, gui)

	local warp = make("Frame", {
		Name = "Warp",
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 45,
	}, gui)

	----------------------------------------------------------------------
	-- Driving it
	----------------------------------------------------------------------
	local started = os.clock()
	-- The taco's fall is longer: until the boom its clock runs TacoMeteor.FallStretch times
	-- slower, after it at the normal rate. Every moment of the reveal reads this clock.
	local function now()
		local elapsed = os.clock() - started
		if not isTaco then
			return elapsed
		end
		local stretch = TacoMeteor.FallStretch
		local boomAt = TIMELINE.Boom * stretch
		if elapsed < boomAt then
			return elapsed / stretch
		end
		return TIMELINE.Boom + (elapsed - boomAt)
	end
	local rumble = play(SOUNDS.Rumble)
	local boomed = false
	local carded = false -- the card (and its GO button) has opened
	local hovering = false
	local closingAt = nil -- when the card started closing
	local warpAt = nil -- when GO was pressed
	local stopped = false
	local stage = nil -- the treadmill rising: its parts, where they belong, its dust
	local cinema = nil -- the flight to it, for a player away from it
	local bindName = "AdminTreadmillReveal"
	local undoName = "AdminTreadmillRevealUndo"
	local seed = math.random() * 100
	-- Last frame's shake: the camera before it and after it. It comes off again before the
	-- camera scripts run, so they never build on it and the view cannot drift.
	local shaken = nil
	local function unshake()
		local camera = Workspace.CurrentCamera
		if camera and shaken then
			-- Exactly as it was, unless something else has moved the camera since.
			camera.CFrame = if camera.CFrame == shaken.After
				then shaken.Before
				else camera.CFrame * shaken.After:ToObjectSpace(shaken.Before)
		end
		shaken = nil
	end

	-- (Above stop(), which calls showInterface: declared below it, the name was a nil global there.)
	-- While the camera is away nothing else is on screen: every other ScreenGui that was showing
	-- and the core GUI are turned off, and afterwards exactly those come back. The ledger is
	-- Shared/InterfaceHider's, shared with the world-portal flight: neither cinematic can bring
	-- the interface back under the other, or leave it off for good.
	local function hideInterface()
		InterfaceHider.Hide(INTERFACE_OWNER, { gui })
	end
	local function showInterface()
		InterfaceHider.Show(INTERFACE_OWNER)
	end

	local function stop()
		if stopped then
			return
		end
		stopped = true
		pcall(function()
			RunService:UnbindFromRenderStep(bindName)
		end)
		pcall(function()
			RunService:UnbindFromRenderStep(undoName)
		end)
		unshake()
		if stage then
			stage.Settle()
		end
		if cinema and cinema.Active then
			cinema.Active = false
			local camera = Workspace.CurrentCamera
			if camera then
				camera.CameraType = cinema.CameraType
				camera.FieldOfView = cinema.FieldOfView or camera.FieldOfView
			end
		end
		if stage and stage.Aura and not stage.AuraGone then
			stage.AuraGone = true
			pcall(stage.Aura.Destroy)
		end
		showInterface()
		player:SetAttribute(CINEMATIC_ATTRIBUTE, false)
		rumble:Destroy()
		grade:Destroy()
		gui:Destroy()
		if current and current.Stop == stop then
			current = nil
		end
	end
	current = { Stop = stop }
	gui.Destroying:Connect(stop)

	local function startClosing()
		if not closingAt then
			closingAt = now()
		end
	end

	go.MouseEnter:Connect(function()
		hovering = true
	end)
	go.MouseLeave:Connect(function()
		hovering = false
	end)
	go.Activated:Connect(function()
		-- Once, after the boom, while the card is open and the treadmill is still there (GONE does nothing).
		if warpAt or closingAt or not carded or not adminTreadmill() then
			return
		end
		warpAt = now()
		play(SOUNDS.Go)
		GoRemote:FireServer()

		-- Instant client-side teleport if stand position is available locally
		local model = adminTreadmill()
		local stand = model and model:GetAttribute("AdminTreadmillStand")
		local face = model and model:GetAttribute("AdminTreadmillFace")
		if typeof(stand) == "Vector3" and typeof(face) == "Vector3" then
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if char and root and hum and hum.Health > 0 then
				hum.Sit = false
				root.AssemblyLinearVelocity = Vector3.zero
				root.AssemblyAngularVelocity = Vector3.zero
				local targetCf = CFrame.lookAt(stand, stand + face)
				root.CFrame = targetCf
				char:PivotTo(targetCf)
			end
		end

		startClosing()
	end)
	close.Activated:Connect(startClosing)


	-- The treadmill: found as soon as it has reached this player, pushed under the ground,
	-- and brought up through the rumble. Its parts only move for this player, and every one
	-- goes back exactly where the server put it.
	local function findStage(t)
		if stage or t >= TIMELINE.Boom then
			return
		end
		local model = adminTreadmill()
		local found = model and treadmillStage(model)
		if not found then
			return
		end
		stage = found
		stage.Depth = found.Size.Y + RISE.Clearance
		stage.Settled = false
		if isTaco then
			stage.Heart = found.Centre + Vector3.new(0, found.Size.Y / 2, 0)
			local tacoAssets = Shared:FindFirstChild("TacoEventAssets")
			stage.Aura = TacoMeteor.BuildAura(stage.Heart, found.Size, LOW_POWER, TacoVisual, Shared:FindFirstChild("TacoMeteorAssets"),
				{ Fire = TacoFire, Struck = tacoAssets and tacoAssets:FindFirstChild("StruckVFX") })
		end
		for _, entry in found.Parts do
			entry.Part.CanCollide = false
		end
		local dust = Instance.new("Part")
		dust.Name = "AdminTreadmillDust"
		dust.Anchored = true
		dust.CanCollide = false
		dust.CanQuery = false
		dust.CanTouch = false
		dust.Transparency = 1
		dust.Size = Vector3.new(math.max(4, found.Size.X), 0.2, math.max(4, found.Size.Z))
		dust.CFrame = CFrame.new(found.Centre + Vector3.new(0, 0.2, 0))
		local cloud = Instance.new("ParticleEmitter")
		cloud.Name = "Dust"
		cloud.Texture = "rbxasset://textures/particles/smoke_main.dds"
		cloud.Color = ColorSequence.new(Color3.fromRGB(205, 190, 165), Color3.fromRGB(150, 140, 128))
		cloud.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 9) })
		cloud.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
		cloud.Lifetime = NumberRange.new(1.4, 2.4)
		cloud.Speed = NumberRange.new(4, 10)
		cloud.SpreadAngle = Vector2.new(50, 50)
		cloud.EmissionDirection = Enum.NormalId.Top
		cloud.Rate = 0
		cloud.Parent = dust
		dust.Parent = Workspace
		stage.Dust = dust
		stage.Cloud = cloud
		function stage.Settle()
			if stage.Settled then
				return
			end
			stage.Settled = true
			for _, entry in stage.Parts do
				if entry.Part.Parent then
					entry.Part.CFrame = entry.CFrame
					entry.Part.CanCollide = entry.CanCollide
				end
			end
			cloud.Rate = 0
			task.delay(3, function()
				dust:Destroy()
			end)
		end

		-- Away from it: fly there. The taco meteor is a show for everyone, near or far.
		local camera = Workspace.CurrentCamera
		if camera and t < CINEMA.CutIn
			and (isTaco or (camera.Focus.Position - found.Centre).Magnitude > CINEMA.FarAway)
		then
			local away = (camera.CFrame.Position - found.Centre) * Vector3.new(1, 0, 1)
			cinema = {
				Active = false,
				Yaw = if away.Magnitude > 1 then math.atan2(away.Z, away.X) else 0,
				CameraType = camera.CameraType,
				FieldOfView = camera.FieldOfView,
			}
		end
	end

	-- Where the flying camera is at time `t`: circling the treadmill, drifting closer.
	local function cinemaShot(t)
		if isTaco and stage.Heart then
			-- From the floor looking up at it, round to the side as it comes in, thrown back by
			-- the hit, then circling the landing.
			local eye, focus, fov = TacoMeteor.Shot(t, TIMELINE.Boom, stage.Heart, stage.Centre.Y, cinema.Yaw)
			local camera = Workspace.CurrentCamera
			if camera then
				camera.FieldOfView = fov
			end
			return CFrame.lookAt(eye, focus)
		end
		local along = clamp01((t - CINEMA.CutIn) / (CINEMA.CutOut - CINEMA.CutIn))
		local yaw = cinema.Yaw + (t - CINEMA.CutIn) * CINEMA.Spin
		local radius = CINEMA.Radius - CINEMA.Closer * along
		local centre = stage.Centre
		local eye = centre + Vector3.new(math.cos(yaw) * radius, CINEMA.Height, math.sin(yaw) * radius)
		return CFrame.lookAt(eye, centre + Vector3.new(0, 5, 0))
	end

	RunService:BindToRenderStep(undoName, Enum.RenderPriority.Camera.Value - 1, unshake)
	RunService:BindToRenderStep(bindName, Enum.RenderPriority.Camera.Value + 1, function()
		local t = now()
		local view = viewport()

		local strength = quakeStrength(t)
		local camera = Workspace.CurrentCamera

		-- The treadmill climbing out of the ground, shaking, until it locks in on the boom.
		findStage(t)
		if stage and not stage.Settled then
			if t >= TIMELINE.Boom then
				stage.Settle()
				pcall(function()
					stage.Cloud:Emit(90)
				end)
				if stage.Aura then
					-- The landing: the giant taco bursts, the explosion, the tacos' own splash at full size.
					pcall(stage.Aura.Burst)
					pcall(TacoMeteor.Impact, stage.Centre, stage.Size, LOW_POWER, Shared:FindFirstChild("TacoEventAssets"),
						Shared:FindFirstChild("TacoMeteorAssets"))
					play(SOUNDS.TacoImpact)
				end
			elseif stage.Aura then
				local pose = TacoMeteor.Pose(t, TIMELINE.Boom, stage.Heart)
				for _, entry in stage.Parts do
					entry.Part.CFrame = pose * entry.CFrame
				end
				stage.Aura.Update(t, pose)
			else
				local x = clamp01((t - RISE.From) / (TIMELINE.Boom - RISE.From))
				local up = x * x * (3 - 2 * x)
				local wobble = 0.35 * strength * (1 - 0.6 * up)
				local offset = Vector3.new(math.noise(t * 22, seed + 41) * wobble, -(1 - up) * stage.Depth, math.noise(t * 22, seed + 43) * wobble)
				for _, entry in stage.Parts do
					entry.Part.CFrame = CFrame.new(offset) * entry.CFrame
				end
				stage.Cloud.Rate = if up > 0 then 80 else 0
			end
		end

		-- Away from it: cut to the treadmill, circle it while it rises, cut back to the player.
		if cinema and camera then
			if not cinema.Active and t >= CINEMA.CutIn and t < CINEMA.CutOut then
				cinema.Active = true
				camera.CameraType = Enum.CameraType.Scriptable
				player:SetAttribute(CINEMATIC_ATTRIBUTE, true)
				if isTaco then
					hideInterface()
				end
			elseif cinema.Active and t >= CINEMA.CutOut then
				cinema.Active = false
				camera.CameraType = cinema.CameraType
				camera.FieldOfView = cinema.FieldOfView or camera.FieldOfView
				showInterface()
				player:SetAttribute(CINEMATIC_ATTRIBUTE, false)
			end
		end
		cut.BackgroundTransparency = if cinema then 1 - math.max(dip(t, CINEMA.CutIn), dip(t, CINEMA.CutOut)) else 1

		-- The quake, on top of wherever the camera scripts (or the flight) put the camera.
		if camera and (strength > 0.003 or (cinema and cinema.Active)) then
			local n = t * 16
			local shake = CFrame.new(math.noise(n, seed) * 0.5 * strength, math.noise(n, seed + 7) * 0.5 * strength, 0)
				* CFrame.Angles(
					math.rad(math.noise(n, seed + 13) * 2.2 * strength),
					math.rad(math.noise(n, seed + 19) * 2.2 * strength),
					math.rad(math.noise(n, seed + 29) * 1.4 * strength)
				)
			local before = camera.CFrame
			local shot = if cinema and cinema.Active then cinemaShot(t) else before
			camera.CFrame = shot * shake
			shaken = { Before = before, After = camera.CFrame }
		end
		local jitter = UDim2.fromOffset(math.noise(t * 30, seed) * 14 * strength, math.noise(t * 30, seed + 3) * 14 * strength)

		-- Before the boom: bars, grey world, the words.
		local isMobile = view.Y < 500 or (view.X < 900 and view.X < view.Y)
		local layout = cardLayout(view, LOW_POWER or isMobile, topBarInset())
		local barFraction = layout.Bar
		barTop.Size = UDim2.fromScale(1, barFraction)
		barBottom.Size = UDim2.fromScale(1, barFraction)

		local closing = easeOut(t, TIMELINE.Boom, 0.35)
		local barsIn = easeOut(t, 0, TIMELINE.BarsIn) * (1 - closing)
		barTop.AnchorPoint = Vector2.new(0, 1 - barsIn)
		barBottom.AnchorPoint = Vector2.new(0, barsIn)
		tint.BackgroundTransparency = 1 - 0.45 * clamp01(t / TIMELINE.Boom) * (1 - easeOut(t, TIMELINE.Boom, 0.25))
		local dread = clamp01(t / TIMELINE.Boom) * (1 - easeOut(t, TIMELINE.Boom, 0.6))
		local pop = math.max(0, 1 - (t - TIMELINE.Boom) / 0.8) * (if t >= TIMELINE.Boom then 1 else 0)
		grade.Saturation = -0.45 * dread
		grade.Contrast = 0.2 * dread
		grade.Brightness = -0.08 * dread + 0.35 * pop
		rumble.Volume = SOUNDS.Rumble.Volume * clamp01(t / 0.6) * (1 - easeOut(t, TIMELINE.Boom, 0.5))

		whisperConstraint.MaxTextSize = if isMobile then 36 else 54
		feelingConstraint.MaxTextSize = if isMobile then 56 else 96
		whisper.Size = UDim2.fromScale(if isMobile then 0.88 else 0.72, if isMobile then 0.08 else 0.075)
		feeling.Size = UDim2.fromScale(if isMobile then 0.92 else 0.86, if isMobile then 0.11 else 0.13)

		local whisperAlpha = easeOut(t, TIMELINE.WhisperAt, 0.25) * (1 - easeOut(t, TIMELINE.WhisperOut, 0.2))
		whisper.MaxVisibleGraphemes = math.floor(clamp01((t - TIMELINE.WhisperAt) / 0.9) * #WHISPER)
		whisper.TextTransparency = 1 - whisperAlpha
		whisper.Outline.Transparency = 1 - whisperAlpha
		whisper.Position = UDim2.fromScale(0.5, 0.45) + jitter
		local feelingAlpha = easeOut(t, TIMELINE.FeelingAt, 0.2) * (1 - easeOut(t, TIMELINE.FeelingOut, 0.2))
		feeling.TextTransparency = 1 - feelingAlpha
		feeling.Outline.Transparency = 1 - feelingAlpha
		feeling.Position = UDim2.fromScale(0.5, 0.47) + jitter
		feeling.Rotation = math.noise(t * 20, seed + 5) * 4 * strength
		feelingScale.Scale = 0.6 + 0.4 * easeBack(t, TIMELINE.FeelingAt, 0.4) + 0.04 * math.sin(t * 18)
		feelingColor.Offset = Vector2.new(0, math.sin(t * 5) * 0.25)

		-- The boom.
		if t >= TIMELINE.Boom and not boomed then
			boomed = true
			play(SOUNDS.Boom)
			shockwave.Visible = true
		end
		local afterBoom = t - TIMELINE.Boom
		-- The card and its GO button never open over the camera's flight (they used to, at the
		-- boom, and covered the last two seconds of the cinematic): they wait until the camera is
		-- the player's again and the white dip has cleared. With no flight (a player beside the
		-- rainbow treadmill, a treadmill that had not arrived by the cut) that is the boom. It is a
		-- moment on this reveal's own clock, so it can never be missed.
		local cardAt = if cinema then CINEMA.CutOut + CINEMA.Dip * 1.4 else TIMELINE.Boom
		if t >= cardAt and not carded then
			carded = true
			play(SOUNDS.Reveal)
			card.Visible = true
			rays.Visible = true
		end
		local afterCard = t - cardAt
		flash.BackgroundTransparency = if afterBoom < 0 then 1 else easeOut(afterBoom, 0, 0.6)
		local wave = clamp01(afterBoom / 0.8)
		shockwave.Size = UDim2.fromScale(0, 0.1 + 2.4 * (1 - (1 - wave) ^ 2))
		ring.Transparency = wave
		ring.Thickness = 18 * (1 - wave) + 2
		shockwave.Visible = boomed and wave < 1

		-- The card: pops in, glides up, closes. Fitted to the band between the bars and the safe
		-- area (cardLayout); the pop multiplies that fit, so it never grows past it for long.
		local fit = layout.Fit
		-- Up near the top once it has been seen, never past the screen's edge or under the top bar.
		local rise = easeOut(afterCard, TIMELINE.CardRise, 0.6)
		local centreY = layout.PopY + (layout.RiseY - layout.PopY) * rise
		if closingAt == nil and afterCard >= TIMELINE.CardSeconds then
			startClosing()
		end
		local shut = if closingAt then clamp01((t - closingAt) / TIMELINE.CloseSeconds) else 0
		cardScale.Scale = fit * easeBack(afterCard, 0.05, 0.45) * (1 - shut)
		card.Position = UDim2.fromScale(0.5, centreY)
		rays.Position = card.Position
		shockwave.Position = UDim2.fromScale(0.5, 0.45)
		rays.Rotation = t * 18
		rayScale.Scale = fit * (0.85 + 0.1 * math.sin(t * 2.2)) * easeOut(afterCard, 0, 0.5) * (1 - shut)
		local rayAlpha = easeOut(afterCard, 0, 0.4) * (0.55 + 0.1 * math.sin(t * 3)) * (1 - shut)
		for _, bar in rayBars do
			bar.BackgroundTransparency = 1 - rayAlpha
		end
		borderRainbow.Rotation = (t * 90) % 360
		titleRainbow.Offset = Vector2.new(math.sin(t * 1.4) * 0.35, 0)
		cardShine.Offset = Vector2.new(-1 + 2 * clamp01(((afterCard - 0.4) % 3) / 1.1), 0)
		goShine.Offset = Vector2.new(-1 + 2 * clamp01(((afterCard - 1) % 1.8) / 0.7), 0)
		goScale.Scale = (if hovering then 1.08 else 1) + 0.05 * math.sin(t * 6)
		local present = adminTreadmill() ~= nil
		go.BackgroundColor3 = if present then GREEN else Color3.fromRGB(96, 104, 120)
		goLabel.Text = if present then "GO!" else "GONE"
		local left = math.max(0, math.floor(expiresAt - Workspace:GetServerTimeNow()))
		timer.Text = string.format("%d:%02d", left // 60, left % 60)

		-- GO: a white rush as the player is sent.
		warp.BackgroundTransparency = if warpAt then 0.15 + 0.85 * clamp01((t - warpAt) / 0.45) else 1

		local warpDone = warpAt == nil or t - warpAt >= 0.45
		local flown = cinema == nil or t >= CINEMA.CutOut + CINEMA.Dip * 1.4
		if closingAt and t - closingAt >= TIMELINE.CloseSeconds and warpDone and flown and strength <= 0.003 then
			stop()
		end
	end)
end

-- A server event can arrive while the portal owns the camera. Keep the newest reveal
-- and play it after the portal hands control back.
local queuedReveal = nil
local function flushReveal()
	if player:GetAttribute("WorldPortalCinematicActive") == true then return end
	local payload = queuedReveal
	queuedReveal = nil
	if payload then reveal(payload) end
end
player:GetAttributeChangedSignal("WorldPortalCinematicActive"):Connect(flushReveal)
Panel.OnClientEvent:Connect(function(payload)
	if type(payload) == "table" and payload.kind == "TreadmillReveal" then
		queuedReveal = payload
		flushReveal()
	end
end)
