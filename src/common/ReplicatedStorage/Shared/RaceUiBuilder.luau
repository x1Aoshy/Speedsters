-- ReplicatedStorage/Shared/RaceUiBuilder.luau — Update 4 (2026-09-25): builds the race UI's
-- four ScreenGuis from plain Instances, with the constructors of `env` (RaceUiKit), so the same
-- code runs in the game (UI/RaceHudController, UI/RaceLobbyController) and in plain Lune
-- (audit/test_u4_race_ui). No scripts inside, nothing connected, nothing tweened: the
-- controllers place the HUD pieces from Shared/RaceHudLayout, fill the words from
-- Shared/RaceText and animate.
--   BuildHud(env)       RaceHud       DisplayOrder 60, CoreUISafeInsets: countdown, MPH bar,
--                                     labels, stamina, charge gauge + hint, banner, status,
--                                     podium, "You" pill, ORB readout, feedback, touch action
--                                     button + its segmented ring
--   BuildResults(env)   RaceResults   DisplayOrder 125, Window 640x420 "RACE RESULTS"
--                                     (532x296 on phones, ArrangeResults)
--   BuildLobbyHud(env)  RaceLobbyHud  DisplayOrder 5: the RACE button, the invite, a toast
--   BuildPanel(env)     RacePanelGui  Window 720x460 "RACE": next race, join/leave, rewards,
--                                     FASTEST RACERS (weekly / all-time) (664x296 on phones,
--                                     ArrangePanel)
-- 2026-09-26 (owner): the two windows' ScreenGuis sit under the top bar and inside the notch
-- (CoreUISafeInsets); FitWindow picks the phone or desktop arrangement and places them.
-- The two windows copy GamePanelStyle.BlockyWindow (white frame over the blocky art, the ink
-- outline, the title on the top edge, the round close button, a FitScale UIScale that the
-- controller sizes to the screen); root frame "Window" with the header image "Icon", as
-- ModalJuice and ConsoleUiScale expect.
local RaceUiKit: any = if typeof(script) == "Instance"
	then require((script :: any).Parent:WaitForChild("RaceUiKit", 10))
	else require("./RaceUiKit")
local RaceHudLayout: any = if typeof(script) == "Instance"
	then require((script :: any).Parent:WaitForChild("RaceHudLayout", 10))
	else require("./RaceHudLayout")

local RaceUiBuilder = {}

RaceUiBuilder.HudName = "RaceHud"
RaceUiBuilder.ResultsName = "RaceResults"
RaceUiBuilder.LobbyName = "RaceLobbyHud"
RaceUiBuilder.PanelName = "RacePanelGui"
RaceUiBuilder.ResultsSize = { 640, 420 }
RaceUiBuilder.PanelSize = { 720, 460 }
RaceUiBuilder.BoardRowHeight = 52
RaceUiBuilder.BoardRows = 50
RaceUiBuilder.PodiumMedals = { "Gold", "Silver", "Bronze" }
-- The gauge's stripes: alternating transparency steps (a UIGradient at 45 degrees); a
-- NumberSequence holds at most 20 keypoints, two per step.
RaceUiBuilder.StripeCount = 4

local function kitFor(env: any?): any
	return RaceUiKit.new(env)
end

local function screenGui(kit: any, name: string, displayOrder: number, insets: boolean, enabled: boolean): any
	local Enum = kit.env.Enum
	local gui = kit:make("ScreenGui", {
		Name = name,
		Enabled = enabled,
		DisplayOrder = displayOrder,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		IgnoreGuiInset = not insets,
		AutoLocalize = false,
	}, nil)
	if insets then
		pcall(function()
			gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
		end)
	end
	return gui
end

-- GamePanelStyle.BlockyWindow, without the camera binding (the controller sizes FitScale).
function RaceUiBuilder.BlockyWindow(kit: any, gui: any, options: { Width: number, Height: number, Title: string?, Icon: string? }): (any, any)
	local env = kit.env
	local Enum, UDim2, Vector2 = env.Enum, env.UDim2, env.Vector2
	local width, height = options.Width, options.Height
	local window = kit:make("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(width, height),
		BackgroundColor3 = kit:color("White"),
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		Active = true,
	}, nil)
	window:SetAttribute("DesignWidth", width)
	window:SetAttribute("DesignHeight", height)
	kit:corner(window, 22)
	kit:make("UIStroke", { Color = kit:color("Ink"), Thickness = 5 }, window)
	local art = kit:make("ImageLabel", {
		Name = "Background",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Image = RaceUiKit.Art.BlockyBackground,
		ImageTransparency = 0.15,
		ScaleType = Enum.ScaleType.Stretch,
		ZIndex = 0,
		Active = false,
	}, window)
	kit:corner(art, 22)
	local title = kit:make("TextLabel", {
		Name = "Title",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(math.floor(width * 0.66), 64),
		BackgroundTransparency = 1,
		Text = options.Title or "",
		TextScaled = true,
		Font = Enum.Font.FredokaOne,
		TextColor3 = kit:color("White"),
		ZIndex = 3,
		AutoLocalize = false,
	}, window)
	kit:make("UIStroke", { Color = kit:color("Ink"), Thickness = 4 }, title)
	local icon = kit:make("ImageLabel", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(34, 16),
		Size = UDim2.fromOffset(76, 76),
		BackgroundTransparency = 1,
		Image = options.Icon or RaceUiKit.Art.Lightning,
		Rotation = -10,
		ZIndex = 5,
	}, window)
	kit:make("UIAspectRatioConstraint", { AspectRatio = 1 }, icon)
	local close = kit:make("ImageButton", {
		Name = "Close",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -30, 0, 18),
		Size = UDim2.fromOffset(72, 72),
		BackgroundTransparency = 1,
		Image = RaceUiKit.Art.Close,
		ZIndex = 5,
		Selectable = true,
	}, window)
	kit:make("UIAspectRatioConstraint", { AspectRatio = 1 }, close)
	kit:make("UIScale", { Name = "FitScale" }, window)
	window.Parent = gui
	return window, close
end

----------------------------------------------------------------------
-- Arrangements (2026-09-26, owner's phone playtest: the results and the sign-up were very big)
----------------------------------------------------------------------
-- Each window has two arrangements of the same pieces: Wide, the desktop's (unchanged), and
-- Compact, for phones (RaceHudLayout.WindowCompact), denser, its words 14 px or more and its
-- buttons 54 px tall, drawn at 0.84-0.9 on landscape phones (RaceHudLayout.WindowFit), so on
-- the screen every word is about 11 px or more and every main button a 44 px tap.
-- RaceUiBuilder.FitWindow picks one, arranges the window when that changes and places it
-- (RaceHudLayout.WindowFit). The builders arrange Wide; the controllers call FitWindow.
RaceUiBuilder.ResultsCompactSize = { 532, 296 }
RaceUiBuilder.PanelCompactSize = { 664, 296 }
RaceUiBuilder.Headers = {
	Wide = { TitleShare = 0.66, TitleHeight = 64, IconX = 34, IconY = 16, IconSize = 76, CloseInset = 30, CloseY = 18, CloseSize = 72 },
	Compact = { TitleShare = 0.55, TitleHeight = 48, IconX = 26, IconY = 12, IconSize = 60, CloseInset = 24, CloseY = 14, CloseSize = 56 },
}
-- A designer button's words inside it (x, y padding taken off its size).
RaceUiBuilder.ButtonLabelPad = { Wide = { 16, 10 }, Compact = { 8, 8 } }

local function mode(compact: boolean): string
	return if compact then "Compact" else "Wide"
end

-- How far the header (title, icon, close) stands above the window's top edge and past its
-- sides, in design px.
function RaceUiBuilder.HeaderOverhang(compact: boolean): (number, number)
	local h = RaceUiBuilder.Headers[mode(compact)]
	local above = math.max(h.TitleHeight / 2, h.IconSize / 2 - h.IconY, h.CloseSize / 2 - h.CloseY)
	local beside = math.max(0, h.IconSize / 2 - h.IconX, h.CloseSize / 2 - h.CloseInset)
	return above, beside
end

-- The design box RaceHudLayout.WindowFit takes, for a window of `size` ({ w, h }).
function RaceUiBuilder.WindowDesign(size: { number }, compact: boolean)
	local above, beside = RaceUiBuilder.HeaderOverhang(compact)
	return { Width = size[1], Height = size[2], Header = above, Side = beside }
end

-- The window's size and its header for an arrangement.
function RaceUiBuilder.ArrangeHeader(env: any, window: any, width: number, height: number, compact: boolean)
	local UDim2 = env.UDim2
	local h = RaceUiBuilder.Headers[mode(compact)]
	window.Size = UDim2.fromOffset(width, height)
	window:SetAttribute("DesignWidth", width)
	window:SetAttribute("DesignHeight", height)
	window:SetAttribute("Compact", compact)
	window.Title.Size = UDim2.fromOffset(math.floor(width * h.TitleShare), h.TitleHeight)
	window.Icon.Position = UDim2.fromOffset(h.IconX, h.IconY)
	window.Icon.Size = UDim2.fromOffset(h.IconSize, h.IconSize)
	window.Close.Position = UDim2.new(1, -h.CloseInset, 0, h.CloseY)
	window.Close.Size = UDim2.fromOffset(h.CloseSize, h.CloseSize)
end

-- A designer button's words for an arrangement.
function RaceUiBuilder.ArrangeButtonLabel(env: any, button: any, compact: boolean)
	local label = button:FindFirstChild("Label")
	if label then
		local pad = RaceUiBuilder.ButtonLabelPad[mode(compact)]
		label.Size = env.UDim2.new(1, -pad[1], 1, -pad[2])
	end
end

local function box(env: any, object: any, r: { number })
	object.Position = env.UDim2.fromOffset(r[1], r[2])
	object.Size = env.UDim2.fromOffset(r[3], r[4])
end

-- A TextScaled label's UITextSizeConstraint (made when missing).
local function sizeLimits(env: any, label: any, maxSize: number, minSize: number)
	local limits = label:FindFirstChildOfClass("UITextSizeConstraint")
	if not limits then
		limits = env.Instance.new("UITextSizeConstraint")
		limits.Parent = label
	end
	limits.MaxTextSize = maxSize
	limits.MinTextSize = minSize
end

-- Picks the arrangement for the screen, arranges `window` when it changes (`arrange(env,
-- window, compact)`, the window's Arrange*; `sizes` = { Wide = { w, h }, Compact = { w, h } })
-- and centres it with its header in its ScreenGui. `viewX` x `viewY` is the camera's viewport,
-- `roomW` x `roomH` the ScreenGui's size (under the top bar, inside the notch), `touch` a touch
-- screen. Returns RaceHudLayout.WindowFit's rect: its Scale is the FitScale's, which the caller
-- sets (or tweens).
function RaceUiBuilder.FitWindow(env: any, window: any, arrange: any, sizes: any, viewX: number, viewY: number, roomW: number, roomH: number, touch: boolean?): any
	local compact = RaceHudLayout.WindowCompact(viewX, viewY, roomW, roomH, touch)
	if window:GetAttribute("Compact") ~= compact then
		arrange(env, window, compact)
	end
	local size = if compact then sizes.Compact else sizes.Wide
	local fit = RaceHudLayout.WindowFit(RaceUiBuilder.WindowDesign(size, compact), roomW, roomH, compact, viewY)
	window.AnchorPoint = env.Vector2.new(0.5, 0.5)
	window.Position = env.UDim2.new(0.5, 0, 0.5, math.floor(fit.OffsetY + 0.5))
	return fit
end

----------------------------------------------------------------------
-- Pieces
----------------------------------------------------------------------
-- A podium card: headshot on a navy square with a medal stroke, the name strip over its
-- lower part, the rank badge on its corner, the YOU chip on top, the reward under it.
function RaceUiBuilder.PodiumCard(kit: any, parent: any, place: number): any
	local env = kit.env
	local UDim2, Vector2, Enum = env.UDim2, env.Vector2, env.Enum
	local medal = RaceUiBuilder.PodiumMedals[place] or "Gold"
	local card = kit:make("Frame", { Name = "Card" .. place, BackgroundTransparency = 1, Visible = false }, nil)
	card:SetAttribute("Place", place)
	local face = kit:make("ImageLabel", {
		Name = "Headshot",
		BackgroundColor3 = kit:color("Card"),
		BorderSizePixel = 0,
		Image = "",
		ScaleType = Enum.ScaleType.Crop,
		ZIndex = 2,
	}, card)
	kit:corner(face, 10)
	kit:make("UIStroke", { Name = "Medal", Color = kit:color(medal), Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, face)
	local strip = kit:make("Frame", {
		Name = "NameStrip",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 12),
		BackgroundColor3 = kit:color("Ink"),
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, face)
	kit:corner(strip, 6)
	kit:text(strip, "PlayerName", { Size = UDim2.new(1, -4, 1, 0), Position = UDim2.fromOffset(2, 0), ZIndex = 4, TextTruncate = Enum.TextTruncate.AtEnd }, 11)
	local badge = kit:make("Frame", {
		Name = "Rank",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(2, 2),
		Size = UDim2.fromOffset(18, 18),
		BackgroundColor3 = kit:color(medal),
		BorderSizePixel = 0,
		ZIndex = 5,
	}, card)
	kit:corner(badge, nil, 0.5)
	kit:stroke(badge, "Ink", 2)
	kit:text(badge, "Number", { Size = UDim2.fromScale(1, 1), Text = tostring(place), ZIndex = 6 }, 12)
	local you = kit:make("TextLabel", {
		Name = "You",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(34, 14),
		BackgroundColor3 = kit:color("Cyan"),
		BorderSizePixel = 0,
		Font = Enum.Font.FredokaOne,
		Text = "YOU",
		TextColor3 = kit:color("Ink"),
		TextSize = 11,
		Visible = false,
		ZIndex = 6,
		AutoLocalize = false,
	}, card)
	kit:corner(you, 6)
	local reward = kit:make("Frame", { Name = "Reward", BackgroundTransparency = 1, ZIndex = 2 }, card)
	kit:make("ImageLabel", {
		Name = "Icon",
		BackgroundTransparency = 1,
		Image = "",
		Size = UDim2.fromScale(0.3, 1),
		ZIndex = 3,
	}, reward)
	local amount = kit:text(reward, "Amount", {
		Position = UDim2.fromScale(0.3, 0),
		Size = UDim2.fromScale(0.7, 1),
		TextColor3 = kit:color("Purple"),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
	}, 12)
	amount.Outline.Color = kit:color("PurpleEdge")
	card.Parent = parent
	return card
end

-- The segmented ring around the touch action button: RingSegments short bars on a 270-degree
-- arc (the controller sets their places for the button's size, their colours per band).
function RaceUiBuilder.Ring(kit: any, parent: any): any
	local env = kit.env
	local ring = kit:make("Frame", {
		Name = "ActionRing",
		AnchorPoint = env.Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Visible = false,
		Active = false,
		ZIndex = 4,
	}, nil)
	for k = 1, RaceHudLayout.RingSegments do
		local seg = kit:make("Frame", {
			Name = "Seg" .. k,
			AnchorPoint = env.Vector2.new(0.5, 0.5),
			BackgroundColor3 = kit:color("Muted"),
			BackgroundTransparency = 0.55,
			BorderSizePixel = 0,
			ZIndex = 4,
		}, ring)
		kit:corner(seg, 2)
	end
	ring.Parent = parent
	return ring
end

-- The horizontal charge gauge: a track with the zone (green, striped), the core (gold, glowing),
-- the overheat end (red), the fill up to g and the white needle.
function RaceUiBuilder.Gauge(kit: any, parent: any): any
	local env = kit.env
	local UDim2, Vector2 = env.UDim2, env.Vector2
	local gauge = kit:make("Frame", {
		Name = "Gauge",
		BackgroundColor3 = kit:color("Track"),
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 2,
	}, nil)
	kit:corner(gauge, 8)
	kit:stroke(gauge, "Ink", 3)
	local fill = kit:make("Frame", { Name = "Fill", BackgroundColor3 = kit:color("White"), BackgroundTransparency = 0.55, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1), ZIndex = 3 }, gauge)
	kit:corner(fill, 8)
	local zone = kit:make("Frame", { Name = "Zone", BackgroundColor3 = kit:color("Zone"), BorderSizePixel = 0, ZIndex = 4 }, gauge)
	local points = {}
	for i = 0, RaceUiBuilder.StripeCount * 2 - 1 do
		local t0 = i / (RaceUiBuilder.StripeCount * 2)
		local value = if i % 2 == 0 then 0 else 0.4
		table.insert(points, env.NumberSequenceKeypoint.new(t0, value))
		table.insert(points, env.NumberSequenceKeypoint.new(math.min(1, t0 + 1 / (RaceUiBuilder.StripeCount * 2) - 0.001), value))
	end
	points[#points] = env.NumberSequenceKeypoint.new(1, points[#points].Value)
	kit:make("UIGradient", { Name = "Stripes", Rotation = 45, Transparency = env.NumberSequence.new(points) }, zone)
	local core = kit:make("Frame", { Name = "Core", BackgroundColor3 = kit:color("Core"), BorderSizePixel = 0, ZIndex = 5 }, gauge)
	kit:make("UIStroke", { Name = "Glow", Color = kit:color("Core"), Thickness = 2, Transparency = 0.3 }, core)
	kit:make("Frame", { Name = "Overheat", BackgroundColor3 = kit:color("Overheat"), BorderSizePixel = 0, ZIndex = 4 }, gauge)
	local needle = kit:make("Frame", {
		Name = "Needle",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(0, 4, 1, 10),
		BackgroundColor3 = kit:color("White"),
		BorderSizePixel = 0,
		ZIndex = 7,
	}, gauge)
	kit:stroke(needle, "Ink", 1.5)
	gauge.Parent = parent
	return gauge
end

-- Places a band (Zone/Core/Overheat) of the gauge between two gauge values.
function RaceUiBuilder.PlaceBand(env: any, band: any, lo: number, hi: number)
	band.Position = env.UDim2.fromScale(math.clamp(lo, 0, 1), 0)
	band.Size = env.UDim2.fromScale(math.clamp(hi - lo, 0, 1), 1)
end

----------------------------------------------------------------------
-- RaceHud
----------------------------------------------------------------------
function RaceUiBuilder.BuildHud(env: any?): any
	local kit = kitFor(env)
	local e = kit.env
	local UDim2, Vector2, Enum = e.UDim2, e.Vector2, e.Enum
	local gui = screenGui(kit, RaceUiBuilder.HudName, 60, true, false)

	-- Countdown: "STARTING: 3s" and the big number (popped by a UIScale).
	local countdown = kit:make("Frame", { Name = "Countdown", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false }, gui)
	kit:text(countdown, "Starting", { Rotation = -4, TextColor3 = kit:color("White") }, 24)
	-- TextScaled: a TextSize stops at 100 px and the number is up to 300 px tall (it changes
	-- once a second, so the scaling pass is cheap).
	local number = kit:text(countdown, "Number", { AnchorPoint = Vector2.new(0.5, 0.5), TextColor3 = kit:color("White") })
	local constraint = number:FindFirstChildOfClass("UITextSizeConstraint")
	if constraint then
		constraint:Destroy()
	end
	number.Outline.Thickness = 5
	kit:make("UIScale", { Name = "Pop" }, number)

	-- Status and podium (top-left), the "You" pill under it.
	kit:text(gui, "Status", { TextXAlignment = Enum.TextXAlignment.Left, Visible = false }, 16)
	local podium = kit:make("Frame", { Name = "Podium", BackgroundTransparency = 1, Visible = false }, gui)
	for _, place in RaceHudLayout.PodiumOrder do
		RaceUiBuilder.PodiumCard(kit, podium, place)
	end
	local you = kit:plate(gui, "YouPill", { Visible = false })
	kit:text(you, "Text", { Size = UDim2.fromScale(1, 1), TextColor3 = kit:color("Cyan") }, 14)

	-- ORB readout (top-right).
	local goal = kit:make("Frame", { Name = "Goal", BackgroundTransparency = 1, Visible = false }, gui)
	kit:text(goal, "Orb", { TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = kit:color("Gold"), Text = "▼ ORB" }, 16)
	kit:text(goal, "Distance", { TextXAlignment = Enum.TextXAlignment.Right }, 16)
	kit:text(goal, "Elapsed", { TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = kit:color("Muted") }, 16)
	-- 2026-09-25 (final fix): LEAVE under the ORB readout (two taps; the HUD hides every other
	-- way out of a staged race).
	kit:button(gui, "Leave", "LEAVE", "Red", { Visible = false, ZIndex = 5 }, 14)

	-- The MPH bar with its lightning icon, the labels row, the race-stamina bar.
	local speed = kit:bar(gui, "SpeedBar", RaceUiKit.SpeedFill, 18)
	speed.Visible = false
	local icon = kit:make("ImageLabel", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		BackgroundTransparency = 1,
		Image = RaceUiKit.Art.Lightning,
		Rotation = -10,
		ZIndex = 6,
	}, speed)
	kit:make("UIAspectRatioConstraint", { AspectRatio = 1 }, icon)
	local labels = kit:make("Frame", { Name = "Labels", BackgroundTransparency = 1, Visible = false }, gui)
	kit:text(labels, "Multiplier", { Size = UDim2.fromScale(0.5, 1), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = kit:color("Lime") }, 12)
	kit:text(labels, "Accel", { Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromScale(0.5, 1), TextXAlignment = Enum.TextXAlignment.Right }, 12)
	local stamina = kit:bar(gui, "Stamina", RaceUiKit.StaminaFill, 11)
	stamina.Visible = false

	-- The charge gauge (PC/console), its hint and the start banner.
	RaceUiBuilder.Gauge(kit, gui)
	local hint = kit:make("Frame", { Name = "Hint", BackgroundTransparency = 1, Visible = false }, gui)
	kit:make("ImageLabel", { Name = "Glyph", BackgroundTransparency = 1, Image = "", Visible = false, ZIndex = 2 }, hint)
	kit:text(hint, "Text", { Size = UDim2.fromScale(1, 1), ZIndex = 2 }, 14)
	local banner = kit:text(gui, "Banner", { Visible = false, TextColor3 = kit:color("Gold") }, 24)
	banner.Outline.Thickness = 3
	kit:make("UIScale", { Name = "Pop" }, banner)

	-- Feedback line ("OUCH! SPIKES", "FINISHED 2nd!", toasts).
	local feedback = kit:text(gui, "Feedback", { Visible = false, AnchorPoint = Vector2.new(0.5, 0.5) }, 24)
	feedback.Outline.Thickness = 3
	kit:make("UIScale", { Name = "Pop" }, feedback)

	-- Touch: the CHARGE / BOOST button (round) and its ring.
	local action = kit:button(gui, "Action", "CHARGE", "Blue", { Visible = false, ZIndex = 5 }, 14)
	action:FindFirstChildOfClass("UICorner").CornerRadius = e.UDim.new(0.5, 0)
	action.Studs:FindFirstChildOfClass("UICorner").CornerRadius = e.UDim.new(0.5, 0)
	RaceUiBuilder.Ring(kit, gui)
	return gui
end

----------------------------------------------------------------------
-- RaceResults
----------------------------------------------------------------------
-- The results window's two arrangements (design px; boxes are { x, y, w, h }). Wide is the
-- desktop's 640 x 420; Compact 532 x 296: the place banner narrower (clear of the winner's YOU
-- chip), time / best / NEW BEST on the left, the mini podium on the right, the reward chips two
-- by two across the whole width, the cap note, RACE AGAIN / LOBBY (8) 54 px tall.
RaceUiBuilder.ResultsLayouts = {
	Wide = {
		PlaceY = 44, Place = { 460, 58 },
		Time = { 34, 112, 250, 40 }, Best = { 34, 154, 250, 26 }, NewBest = { 290, 114, 150, 38 },
		Rewards = { 30, 190, 330, 96 }, Cell = { 160, 42 }, CellPad = { 8, 8 }, ChipIcon = { 6, 5, 32 }, ChipLabel = { 40, 4, 46, 8 },
		Pending = { 30, 196, 330, 30 }, CapNote = { 30, 294, 580, 22 },
		Podium = { 378, 112, 240, 170 }, First = 88, Side = 72, Gap = 8, RewardGap = 4, RewardH = 20,
		NameH = 12, NameText = 11, Badge = 18, BadgeText = 12, You = { 34, 14 }, YouX = 0, YouText = 11, AmountText = 12, IconShare = 0.3,
		ButtonsBottom = 22, Again = 220, Lobby = 200, ButtonGap = 20, ButtonH = 62,
	},
	Compact = {
		PlaceY = 26, Place = { 200, 34 },
		Time = { 22, 64, 278, 28 }, Best = { 22, 92, 278, 20 }, NewBest = { 22, 116, 170, 26 },
		Rewards = { 22, 156, 488, 58 }, Cell = { 240, 26 }, CellPad = { 8, 6 }, ChipIcon = { 4, 2, 22 }, ChipLabel = { 30, 2, 34, 4 },
		Pending = { 22, 160, 488, 24 }, CapNote = { 22, 216, 488, 18 },
		Podium = { 314, 64, 196, 86 }, First = 64, Side = 58, Gap = 8, RewardGap = 2, RewardH = 20,
		NameH = 17, NameText = 14, Badge = 20, BadgeText = 14, You = { 38, 18 }, YouX = 6, YouText = 14, AmountText = 14, IconShare = 0.22,
		ButtonsBottom = 6, Again = 236, Lobby = 200, ButtonGap = 20, ButtonH = 54,
	},
}

-- Sizes a results podium card (a PodiumCard) for an arrangement.
local function arrangeResultsCard(env: any, card: any, side: number, L: any, compact: boolean)
	local UDim2 = env.UDim2
	card.Size = UDim2.fromOffset(side, side + L.RewardGap + L.RewardH)
	local face = card.Headshot
	face.Size = UDim2.fromOffset(side, side)
	face.NameStrip.Size = UDim2.new(1, 0, 0, L.NameH)
	face.NameStrip.PlayerName.TextSize = L.NameText
	card.Rank.Size = UDim2.fromOffset(L.Badge, L.Badge)
	card.Rank.Number.TextSize = L.BadgeText
	-- (Compact: a little right of the middle, clear of the rank badge on the card's corner.)
	card.You.Position = UDim2.new(0.5, L.YouX, 0, 0)
	card.You.Size = UDim2.fromOffset(L.You[1], L.You[2])
	card.You.TextSize = L.YouText
	local reward = card.Reward
	reward.Position = UDim2.fromOffset(0, side + L.RewardGap)
	reward.Size = UDim2.fromOffset(side, L.RewardH)
	reward.Icon.Size = UDim2.fromScale(L.IconShare, 1)
	-- (Compact: a narrow slot; the icon keeps its shape inside it.)
	reward.Icon.ScaleType = if compact then env.Enum.ScaleType.Fit else env.Enum.ScaleType.Stretch
	local amount = reward.Amount
	amount.Position = UDim2.fromScale(L.IconShare, 0)
	amount.Size = UDim2.fromScale(1 - L.IconShare, 1)
	-- Compact: "+1.23K" under a 58 px card shrinks to fit rather than spill onto the next card.
	amount.TextScaled = compact
	amount.TextSize = L.AmountText
	if compact then
		sizeLimits(env, amount, L.AmountText, 10)
	end
end

function RaceUiBuilder.ArrangeResults(env: any, window: any, compact: boolean)
	local UDim2 = env.UDim2
	local L = RaceUiBuilder.ResultsLayouts[mode(compact)]
	local size = if compact then RaceUiBuilder.ResultsCompactSize else RaceUiBuilder.ResultsSize
	RaceUiBuilder.ArrangeHeader(env, window, size[1], size[2], compact)
	local content = window.Content
	content.Place.Position = UDim2.new(0.5, 0, 0, L.PlaceY)
	content.Place.Size = UDim2.fromOffset(L.Place[1], L.Place[2])
	box(env, content.Time, L.Time)
	box(env, content.Best, L.Best)
	box(env, content.NewBest, L.NewBest)
	box(env, content.Rewards, L.Rewards)
	local grid = content.Rewards:FindFirstChildOfClass("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(L.Cell[1], L.Cell[2])
	grid.CellPadding = UDim2.fromOffset(L.CellPad[1], L.CellPad[2])
	for _, chip in content.Rewards:GetChildren() do
		if chip:IsA("Frame") then
			chip.Icon.Position = UDim2.fromOffset(L.ChipIcon[1], L.ChipIcon[2])
			chip.Icon.Size = UDim2.fromOffset(L.ChipIcon[3], L.ChipIcon[3])
			chip.Label.Position = UDim2.fromOffset(L.ChipLabel[1], L.ChipLabel[2])
			chip.Label.Size = UDim2.new(1, -L.ChipLabel[3], 1, -L.ChipLabel[4])
		end
	end
	box(env, content.Pending, L.Pending)
	box(env, content.CapNote, L.CapNote)
	-- The mini podium: 2nd, 1st, 3rd; the sides lower, their bottoms level with the winner's.
	box(env, content.Podium, L.Podium)
	local x = 0
	for _, place in RaceHudLayout.PodiumOrder do
		local card = content.Podium:FindFirstChild("Card" .. place)
		local side = if place == 1 then L.First else L.Side
		if card then
			card.Position = UDim2.fromOffset(x, if place == 1 then 0 else L.First - L.Side)
			arrangeResultsCard(env, card, side, L, compact)
		end
		x += side + L.Gap
	end
	local buttons = content.Buttons
	buttons.Position = UDim2.new(0.5, 0, 1, -L.ButtonsBottom)
	buttons.Size = UDim2.fromOffset(L.Again + L.ButtonGap + L.Lobby, L.ButtonH)
	buttons.RaceAgain.Position = UDim2.fromOffset(0, 0)
	buttons.RaceAgain.Size = UDim2.fromOffset(L.Again, L.ButtonH)
	buttons.Lobby.Position = UDim2.fromOffset(L.Again + L.ButtonGap, 0)
	buttons.Lobby.Size = UDim2.fromOffset(L.Lobby, L.ButtonH)
	for _, button in { buttons.RaceAgain, buttons.Lobby } do
		RaceUiBuilder.ArrangeButtonLabel(env, button, compact)
	end
end

function RaceUiBuilder.BuildResults(env: any?): any
	local kit = kitFor(env)
	local e = kit.env
	local UDim2, Vector2, Enum = e.UDim2, e.Vector2, e.Enum
	-- 2026-09-26 (owner): under the top bar and inside the notch (the window centres in that room).
	local gui = screenGui(kit, RaceUiBuilder.ResultsName, 125, true, false)
	local size = RaceUiBuilder.ResultsSize
	local window = RaceUiBuilder.BlockyWindow(kit, gui, { Width = size[1], Height = size[2], Title = "RACE RESULTS" })
	local content = kit:make("Frame", { Name = "Content", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 2 }, window)

	local banner = kit:text(content, "Place", { AnchorPoint = Vector2.new(0.5, 0), TextColor3 = kit:color("Gold"), ZIndex = 3 })
	banner.Outline.Thickness = 4
	kit:make("UIScale", { Name = "Pop" }, banner)

	-- Time, NEW BEST tile, best time, reward chips (their places: ArrangeResults).
	local timeLabel = kit:text(content, "Time", { TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3 })
	timeLabel.Outline.Thickness = 3
	local newBest = kit:tile(content, "NewBest", "Gold", { Visible = false, ZIndex = 3 }, 10)
	kit:text(newBest, "Label", { Size = UDim2.new(1, -10, 1, -6), Position = UDim2.fromOffset(5, 3), Text = "NEW BEST!", ZIndex = 4 })
	kit:text(content, "Best", { TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = kit:color("Navy"), ZIndex = 3 }).Outline.Color = kit:color("White")

	local rewards = kit:make("Frame", { Name = "Rewards", BackgroundTransparency = 1, ZIndex = 3 }, content)
	kit:make("UIGridLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, rewards)
	for order, chip in { { "Wins", "Purple" }, { "Speed", "Blue" }, { "Ticket", "Pink" }, { "FirstToday", "Gold" } } do
		local tile = kit:tile(rewards, chip[1], chip[2], { LayoutOrder = order, Visible = false, ZIndex = 3 }, 10)
		kit:make("ImageLabel", { Name = "Icon", BackgroundTransparency = 1, Image = "", ZIndex = 4 }, tile)
		kit:text(tile, "Label", { TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4 })
	end
	kit:text(content, "Pending", { TextXAlignment = Enum.TextXAlignment.Left, Visible = false, ZIndex = 3 })
	kit:text(content, "CapNote", { TextColor3 = kit:color("Red"), Visible = false, ZIndex = 3 })

	-- The mini podium (88 px for the winner, 72 for the others on a desktop).
	local podium = kit:make("Frame", { Name = "Podium", BackgroundTransparency = 1, ZIndex = 3 }, content)
	for _, place in RaceHudLayout.PodiumOrder do
		RaceUiBuilder.PodiumCard(kit, podium, place)
	end

	-- Buttons: RACE AGAIN (green) and LOBBY (8) (navy).
	local buttons = kit:make("Frame", { Name = "Buttons", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), ZIndex = 3 }, content)
	kit:button(buttons, "RaceAgain", "RACE AGAIN", "Green", { ZIndex = 4 })
	kit:button(buttons, "Lobby", "LOBBY (8)", "Navy", { ZIndex = 4 })
	RaceUiBuilder.ArrangeResults(e, window, false)
	return gui
end

----------------------------------------------------------------------
-- RaceLobbyHud
----------------------------------------------------------------------
function RaceUiBuilder.BuildLobbyHud(env: any?): any
	local kit = kitFor(env)
	local e = kit.env
	local UDim2, Vector2, Enum = e.UDim2, e.Vector2, e.Enum
	local gui = screenGui(kit, RaceUiBuilder.LobbyName, 5, true, true)

	-- The RACE button: lightning icon, "RACE", the state line, the red "!" and the pulse.
	local button = kit:button(gui, "RaceButton", "", "Blue", { Visible = false, Size = UDim2.fromOffset(150, 58) }, 14)
	button.Label.Visible = false
	kit:make("UIScale", { Name = "Pulse" }, button)
	local icon = kit:make("ImageLabel", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 4, 0.5, 0),
		Size = UDim2.fromScale(0.34, 0.9),
		BackgroundTransparency = 1,
		Image = RaceUiKit.Art.Lightning,
		Rotation = -10,
		ZIndex = 4,
	}, button)
	kit:make("UIAspectRatioConstraint", { AspectRatio = 1 }, icon)
	kit:text(button, "Title", { Position = UDim2.fromScale(0.34, 0.06), Size = UDim2.fromScale(0.62, 0.5), Text = "RACE", ZIndex = 4 })
	kit:text(button, "State", { Position = UDim2.fromScale(0.34, 0.54), Size = UDim2.fromScale(0.62, 0.4), ZIndex = 4 })
	local alert = kit:make("Frame", {
		Name = "Alert",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -2, 0, 2),
		Size = UDim2.fromOffset(20, 20),
		BackgroundColor3 = kit:color("Red"),
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 6,
	}, button)
	kit:corner(alert, nil, 0.5)
	kit:stroke(alert, "Ink", 2)
	kit:text(alert, "Mark", { Size = UDim2.fromScale(1, 1), Text = "!", ZIndex = 7 }, 14)

	-- The invite toast: avatars, "RACE IN 0:15!", "5 racers · up to +X Wins", JOIN and x.
	local invite = kit:make("Frame", { Name = "Invite", Visible = false, BackgroundTransparency = 1, Size = UDim2.fromOffset(330, 86) }, gui)
	local card = kit:make("Frame", { Name = "Card", Size = UDim2.fromScale(1, 1) }, invite)
	kit:studPanel(card, 14)
	local avatars = kit:make("Frame", { Name = "Avatars", BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 8), Size = UDim2.new(0.26, 0, 1, -16), ZIndex = 3 }, card)
	for index = 1, 4 do
		local face = kit:make("ImageLabel", {
			Name = "Avatar" .. index,
			BackgroundColor3 = kit:color("Card"),
			BorderSizePixel = 0,
			Position = UDim2.fromScale((index - 1) * 0.22, if index % 2 == 0 then 0.36 else 0.08),
			Size = UDim2.fromScale(0.52, 0.56),
			Image = "",
			Visible = false,
			ZIndex = 3 + index,
		}, avatars)
		kit:make("UIAspectRatioConstraint", { AspectRatio = 1 }, face)
		kit:corner(face, nil, 0.5)
		kit:stroke(face, "White", 2)
	end
	local title = kit:text(card, "Title", { Position = UDim2.fromScale(0.29, 0.08), Size = UDim2.fromScale(0.46, 0.42), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = kit:color("Gold"), ZIndex = 3 })
	title.Outline.Thickness = 2.5
	kit:text(card, "Body", { Position = UDim2.fromScale(0.29, 0.54), Size = UDim2.fromScale(0.46, 0.36), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = kit:color("Navy"), ZIndex = 3 }).Outline.Color = kit:color("White")
	kit:button(card, "Join", "JOIN", "Green", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromScale(0.21, 0.62), ZIndex = 4 })
	local dismiss = kit:make("TextButton", {
		Name = "Dismiss",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -4, 0, 4),
		Size = UDim2.fromOffset(26, 26),
		BackgroundColor3 = kit:color("Ink"),
		BorderSizePixel = 0,
		Font = Enum.Font.FredokaOne,
		Text = "x",
		TextColor3 = kit:color("White"),
		TextSize = 16,
		AutoButtonColor = true,
		Selectable = true,
		ZIndex = 6,
		AutoLocalize = false,
	}, card)
	kit:corner(dismiss, nil, 0.5)

	-- A toast line under the button (join refusals, "You left the race").
	local toast = kit:plate(gui, "Toast", { Visible = false, BackgroundTransparency = 0.15 })
	kit:text(toast, "Text", { Size = UDim2.new(1, -12, 1, 0), Position = UDim2.fromOffset(6, 0) }, 14)
	return gui
end

----------------------------------------------------------------------
-- RacePanelGui
----------------------------------------------------------------------
-- The race panel's two arrangements (design px; boxes are { x, y, w, h } in their column).
-- Wide is the desktop's 720 x 460: Left (next race, join, rewards), Right (FASTEST RACERS).
-- Compact 664 x 296: Left holds two columns (the next race and JOIN RACE, then the rewards
-- with the first-race line on two lines), Right the tabs and a list of 38 px rows (its
-- "no times yet" line on two lines too).
RaceUiBuilder.PanelLayouts = {
	Wide = {
		Left = { 24, 50, 300, 392 }, NextRace = { 0, 0, 300, 24 }, Timer = { 0, 24, 300, 50 }, Ready = { 0, 76, 300, 24 },
		Join = { 0, 106, 300, 56 },
		Rewards = { 0, 172, 300, 214 }, RewardsTitle = { 10, 6, 26 }, RowX = 10, RowTop = 36, RowPitch = 36, RowH = 32,
		RowPlace = { 8, 0.4 }, RowIcon = { 6, 24 }, RowAmount = { 34, 0.6 }, FirstToday = { 10, 182, 24 }, FirstTodayWraps = false,
		Right = { 340, 50, 356, 392 }, Fastest = { 0, 0, 356, 28 }, Weekly = { 0, 32, 172, 36 }, AllTime = { 184, 32, 172, 36 },
		YourBest = { 0, 72, 356, 24 }, List = { 0, 100, 356, 288 }, Empty = { 20, 200, 316, 40 }, ListPad = 6,
		Row = { H = 46, RankX = 6, RankW = 40, RankText = 20, FaceX = 50, Face = 38, NameX = 96, NameRight = 196, NameText = 18, TimeRight = 10, TimeW = 92, TimeText = 18 },
	},
	Compact = {
		Left = { 18, 28, 388, 260 }, NextRace = { 0, 0, 176, 20 }, Timer = { 0, 20, 176, 40 }, Ready = { 0, 62, 176, 20 },
		Join = { 0, 88, 176, 56 },
		Rewards = { 188, 0, 200, 212 }, RewardsTitle = { 8, 6, 22 }, RowX = 8, RowTop = 34, RowPitch = 32, RowH = 28,
		RowPlace = { 6, 0.45 }, RowIcon = { 4, 22 }, RowAmount = { 30, 0.55 }, FirstToday = { 8, 164, 40 }, FirstTodayWraps = true,
		Right = { 420, 28, 226, 260 }, Fastest = { 0, 0, 186, 20 }, Weekly = { 0, 24, 109, 42 }, AllTime = { 117, 24, 109, 42 },
		YourBest = { 0, 70, 226, 18 }, List = { 0, 92, 226, 168 }, Empty = { 10, 140, 206, 40 }, ListPad = 4,
		Row = { H = 38, RankX = 4, RankW = 28, RankText = 16, FaceX = 34, Face = 30, NameX = 68, NameRight = 140, NameText = 15, TimeRight = 6, TimeW = 62, TimeText = 15 },
	},
}

-- A FASTEST RACERS row for an arrangement.
function RaceUiBuilder.ArrangeBoardRow(env: any, row: any, compact: boolean)
	local UDim2 = env.UDim2
	local R = RaceUiBuilder.PanelLayouts[mode(compact)].Row
	row.Size = UDim2.new(1, -8, 0, R.H)
	row.Rank.Position = UDim2.fromOffset(R.RankX, 0)
	row.Rank.Size = UDim2.new(0, R.RankW, 1, 0)
	row.Rank.TextSize = R.RankText
	row.Headshot.Position = UDim2.new(0, R.FaceX, 0.5, 0)
	row.Headshot.Size = UDim2.fromOffset(R.Face, R.Face)
	row.PlayerName.Position = UDim2.fromOffset(R.NameX, 0)
	row.PlayerName.Size = UDim2.new(1, -R.NameRight, 1, 0)
	row.PlayerName.TextSize = R.NameText
	row.Time.Position = UDim2.new(1, -R.TimeRight, 0, 0)
	row.Time.Size = UDim2.new(0, R.TimeW, 1, 0)
	row.Time.TextSize = R.TimeText
end

-- One row of the FASTEST RACERS list: medal/rank, round headshot, name, gold time (arranged
-- like its list: the List's "Compact" attribute).
function RaceUiBuilder.BoardRow(kit: any, parent: any, index: number): any
	local e = kit.env
	local Vector2, Enum = e.Vector2, e.Enum
	local row = kit:make("Frame", {
		Name = string.format("Row%02d", index),
		LayoutOrder = index,
		BackgroundColor3 = kit:color("Plate"),
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		Visible = false,
	}, nil)
	kit:corner(row, 10)
	kit:make("UIStroke", { Name = "Mine", Color = kit:color("Cyan"), Thickness = 3, Enabled = false }, row)
	kit:text(row, "Rank", { ZIndex = 2 }, 20)
	local face = kit:make("ImageLabel", {
		Name = "Headshot",
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = kit:color("Card"),
		BorderSizePixel = 0,
		Image = "",
		ZIndex = 2,
	}, row)
	kit:corner(face, nil, 0.5)
	kit:text(row, "PlayerName", { TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 2 }, 18)
	kit:text(row, "Time", { AnchorPoint = Vector2.new(1, 0), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = kit:color("Gold"), ZIndex = 2 }, 18)
	RaceUiBuilder.ArrangeBoardRow(e, row, parent ~= nil and parent:GetAttribute("Compact") == true)
	row.Parent = parent
	return row
end

function RaceUiBuilder.ArrangePanel(env: any, window: any, compact: boolean)
	local UDim2 = env.UDim2
	local L = RaceUiBuilder.PanelLayouts[mode(compact)]
	local size = if compact then RaceUiBuilder.PanelCompactSize else RaceUiBuilder.PanelSize
	RaceUiBuilder.ArrangeHeader(env, window, size[1], size[2], compact)
	local left, right = window.Left, window.Right
	box(env, left, L.Left)
	box(env, left.NextRace, L.NextRace)
	box(env, left.Timer, L.Timer)
	box(env, left.Ready, L.Ready)
	for _, button in { left.Join, left.Leave } do
		box(env, button, L.Join)
		RaceUiBuilder.ArrangeButtonLabel(env, button, compact)
	end
	local rewards = left.Rewards
	box(env, rewards, L.Rewards)
	rewards.Title.Position = UDim2.fromOffset(L.RewardsTitle[1], L.RewardsTitle[2])
	rewards.Title.Size = UDim2.new(1, -2 * L.RewardsTitle[1], 0, L.RewardsTitle[3])
	for index, key in { "First", "Second", "Third", "Finish" } do
		local row = rewards[key]
		row.Position = UDim2.fromOffset(L.RowX, L.RowTop + (index - 1) * L.RowPitch)
		row.Size = UDim2.new(1, -2 * L.RowX, 0, L.RowH)
		row.Place.Position = UDim2.fromOffset(L.RowPlace[1], 0)
		row.Place.Size = UDim2.new(L.RowPlace[2], -L.RowPlace[1], 1, 0)
		row.Icon.Position = UDim2.new(1, -L.RowIcon[1], 0.5, 0)
		row.Icon.Size = UDim2.fromOffset(L.RowIcon[2], L.RowIcon[2])
		row.Amount.Position = UDim2.new(1, -L.RowAmount[1], 0, 0)
		row.Amount.Size = UDim2.new(L.RowAmount[2], -L.RowAmount[1], 1, 0)
	end
	local firstToday = rewards.FirstToday
	firstToday.Position = UDim2.fromOffset(L.FirstToday[1], L.FirstToday[2])
	firstToday.Size = UDim2.new(1, -2 * L.FirstToday[1], 0, L.FirstToday[3])
	firstToday.TextWrapped = L.FirstTodayWraps
	box(env, right, L.Right)
	box(env, right.Fastest, L.Fastest)
	box(env, right.Weekly, L.Weekly)
	box(env, right.AllTime, L.AllTime)
	for _, button in { right.Weekly, right.AllTime } do
		RaceUiBuilder.ArrangeButtonLabel(env, button, compact)
		-- (Compact: "SEPANJANG MASA" on two lines rather than 9 px.)
		button.Label.TextWrapped = compact
	end
	box(env, right.YourBest, L.YourBest)
	box(env, right.List, L.List)
	box(env, right.Empty, L.Empty)
	right.Empty.TextWrapped = L.FirstTodayWraps
	local list = right.List
	list:SetAttribute("Compact", compact)
	list:FindFirstChildOfClass("UIListLayout").Padding = env.UDim.new(0, L.ListPad)
	local padding = list:FindFirstChildOfClass("UIPadding")
	padding.PaddingTop = env.UDim.new(0, L.ListPad)
	padding.PaddingBottom = env.UDim.new(0, L.ListPad)
	for _, row in list:GetChildren() do
		if row:IsA("Frame") and string.match(row.Name, "^Row%d+$") then
			RaceUiBuilder.ArrangeBoardRow(env, row, compact)
		end
	end
end

function RaceUiBuilder.BuildPanel(env: any?): any
	local kit = kitFor(env)
	local e = kit.env
	local UDim2, Vector2, Enum = e.UDim2, e.Vector2, e.Enum
	-- 2026-09-26 (owner): under the top bar and inside the notch (the window centres in that room).
	local gui = screenGui(kit, RaceUiBuilder.PanelName, 20, true, false)
	local size = RaceUiBuilder.PanelSize
	local window = RaceUiBuilder.BlockyWindow(kit, gui, { Width = size[1], Height = size[2], Title = "RACE" })

	-- Left column: the next race, join / leave, the rewards (their places: ArrangePanel).
	local left = kit:make("Frame", { Name = "Left", BackgroundTransparency = 1, ZIndex = 2 }, window)
	kit:text(left, "NextRace", { TextColor3 = kit:color("Navy"), Text = "NEXT RACE", ZIndex = 3 }).Outline.Color = kit:color("White")
	local timer = kit:text(left, "Timer", { TextColor3 = kit:color("Gold"), ZIndex = 3 })
	timer.Outline.Thickness = 3
	kit:text(left, "Ready", { ZIndex = 3 })
	kit:button(left, "Join", "JOIN RACE", "Green", { ZIndex = 3 })
	kit:button(left, "Leave", "LEAVE QUEUE", "Red", { Visible = false, ZIndex = 3 })
	local rewards = kit:make("Frame", { Name = "Rewards", ZIndex = 2 }, left)
	kit:studPanel(rewards, 14)
	kit:text(rewards, "Title", { Text = "REWARDS", ZIndex = 3 })
	for _, key in { "First", "Second", "Third", "Finish" } do
		local row = kit:plate(rewards, key, { ZIndex = 3 })
		kit:text(row, "Place", { TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4 })
		kit:make("ImageLabel", { Name = "Icon", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Image = "", ZIndex = 4 }, row)
		local amount = kit:text(row, "Amount", { AnchorPoint = Vector2.new(1, 0), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = kit:color("Purple"), ZIndex = 4 })
		amount.Outline.Color = kit:color("PurpleEdge")
	end
	kit:text(rewards, "FirstToday", { TextColor3 = kit:color("Gold"), ZIndex = 3 })

	-- Right column: FASTEST RACERS, the Weekly / All-time tabs, your best, the list.
	local right = kit:make("Frame", { Name = "Right", BackgroundTransparency = 1, ZIndex = 2 }, window)
	local fastest = kit:text(right, "Fastest", { Text = "FASTEST RACERS", TextColor3 = kit:color("Gold"), ZIndex = 3 })
	fastest.Outline.Thickness = 3
	kit:button(right, "Weekly", "WEEKLY", "Blue", { ZIndex = 3 })
	kit:button(right, "AllTime", "ALL-TIME", "Navy", { ZIndex = 3 })
	kit:text(right, "YourBest", { TextColor3 = kit:color("Cyan"), ZIndex = 3 })
	local list = kit:make("ScrollingFrame", {
		Name = "List",
		BackgroundColor3 = kit:color("Navy"),
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.fromOffset(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Selectable = true,
		ZIndex = 3,
	}, right)
	kit:corner(list, 12)
	kit:make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }, list)
	kit:make("UIPadding", {}, list)
	kit:text(right, "Empty", { ZIndex = 5, Visible = false })
	RaceUiBuilder.ArrangePanel(e, window, false)
	return gui
end

return RaceUiBuilder
