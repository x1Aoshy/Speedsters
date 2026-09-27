-- Shared frame and popup layout contract for menus and modal popups.
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local HudErgonomics = require(script.Parent:WaitForChild("HudErgonomics"))

local Layout = {}

Layout.Panels = {
	Abilities = "Panel",
	Shop = "Shop",
	Index = "Index",
	Rebirth = "Rebirth",
	Evolve = "Evolve",
	StageTeleport = "StageTeleport",
	Backpack = "MainFrame",
	TimeGift = "TimeGift",
	DailyReward = "Days31",
	Settings = "Settings",
	Worlds = "Worlds",
	UpdateLogs = "Title",
	Treadmill = "TimeGift",
	RankReward = "Panel",
	Admin = "MainFrame",
}

Layout.ModalSizes = {
	Treadmill = Vector2.new(650, 315),
	RankReward = Vector2.new(690, 430),
	UpdateLogs = Vector2.new(670, 410),
	DailyReward = Vector2.new(680, 450),
	Settings = Vector2.new(660, 440),
	Worlds = Vector2.new(680, 440),
	Admin = Vector2.new(680, 440),
}

function Layout.Calculate(width: number, height: number, touch: boolean, hasSidebar: boolean?)
	local compact = (touch and (width < 1100 or height < 650)) or width < 700 or height < 500
	if not compact then
		return { x = 0.498, y = 0.453, width = 0.32, height = 0.586, scale = 1, compact = false }
	end
	-- Uniformly scale the desktop canvas, retaining readable proportions in either orientation.
	local canvasWidth, canvasHeight = 1920 * 0.32, 1080 * 0.586
	local extraWidth = hasSidebar and canvasWidth * 0.16 or 0
	local scale = math.min(1, math.max(1, width - 24) / (canvasWidth + extraWidth), math.max(1, height - 24) / canvasHeight)
	return {
		x = 0.5 + extraWidth * scale / (2 * math.max(width, 1)),
		y = 0.5,
		width = canvasWidth,
		height = canvasHeight,
		scale = scale,
		compact = true,
	}
end

-- Asegura un único UIScale canónico en el frame, limpiando cualquier UIScale duplicado que cause distorsiones
function Layout.EnsureSingleScale(panel: GuiObject, scaleName: string?): UIScale
	local name = scaleName or "UIScale"
	local chosen: UIScale? = nil
	for _, child in ipairs(panel:GetChildren()) do
		if child:IsA("UIScale") then
			if not chosen then
				chosen = child
				chosen.Name = name
			else
				child:Destroy()
			end
		end
	end
	if not chosen then
		chosen = Instance.new("UIScale")
		chosen.Name = name
		chosen.Scale = 1
		chosen.Parent = panel
	end
	return chosen
end

-- Calcula la escala ideal para un popup o modal centrado en función de la resolución visible
function Layout.GetModalScale(viewport: Vector2, baseSize: Vector2?, isTouch: boolean?, customMargin: Vector2?): number
	local inset = Vector2.zero
	pcall(function()
		inset = GuiService:GetGuiInset()
	end)
	local marginX = if customMargin then customMargin.X else (if isTouch then 32 else 60)
	local marginY = if customMargin then customMargin.Y else (if isTouch then 28 else 60)
	local availX = math.max(1, viewport.X - marginX)
	local availY = math.max(1, viewport.Y - inset.Y - marginY)
	local size = baseSize or Vector2.new(680, 420)
	local fit = math.min(availX / size.X, availY / size.Y)
	return math.clamp(fit, 0.45, 1.05)
end

-- Animación estandarizada y suave de apertura (Back Out elástico)
function Layout.AnimateOpen(panel: GuiObject, dim: GuiObject?, uiScale: UIScale?, targetScale: number?, duration: number?)
	panel.Visible = true
	local scale = targetScale or 1
	local dur = duration or 0.24
	local tweens = {}

	if uiScale then
		uiScale.Scale = scale * 0.88
		local t = TweenService:Create(uiScale, TweenInfo.new(dur, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = scale,
		})
		t:Play()
		table.insert(tweens, t)
	end

	if dim then
		dim.Visible = true
		dim.Active = true
		dim.BackgroundTransparency = 1
		local t = TweenService:Create(dim, TweenInfo.new(math.max(0.12, dur - 0.04), Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 0.48,
		})
		t:Play()
		table.insert(tweens, t)
	end

	return tweens[1]
end

-- Animación estandarizada de cierre (Quad In)
function Layout.AnimateClose(panel: GuiObject, dim: GuiObject?, uiScale: UIScale?, targetScale: number?, onComplete: (() -> ())?, duration: number?)
	local scale = targetScale or 1
	local dur = duration or 0.18
	local remaining = 0

	local function checkDone()
		remaining -= 1
		if remaining <= 0 then
			panel.Visible = false
			if dim then
				dim.Visible = false
				dim.Active = false
			end
			if onComplete then
				onComplete()
			end
		end
	end

	if uiScale then
		remaining += 1
		local t = TweenService:Create(uiScale, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Scale = scale * 0.88,
		})
		t.Completed:Connect(checkDone)
		t:Play()
	end

	if dim then
		remaining += 1
		local t = TweenService:Create(dim, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			BackgroundTransparency = 1,
		})
		t.Completed:Connect(checkDone)
		t:Play()
	end

	if remaining == 0 then
		panel.Visible = false
		if dim then
			dim.Visible = false
			dim.Active = false
		end
		if onComplete then
			onComplete()
		end
	end
end

----------------------------------------------------------------------
-- Phones
----------------------------------------------------------------------
-- The designer's menus (Time Gift, Shop, Rebirth, Evolve, Worlds...) share one window: 32% of
-- the screen's width by 58.6% of its height, kept near 1.28 to 1, every piece inside it sized
-- in scale. That is 614 x 480 px on a 1080p desktop but 238 x 186 px on an 812 x 375 phone
-- under the top bar, where the Time Gift's Claim buttons come out 29 x 8 px and its texts 6 px.
-- On a compact touch screen (HudErgonomics.IsCompact, the Main HUD's own rule: phones, and
-- tablets without a keyboard) the window is drawn bigger instead, its shape kept: inside
-- PhoneWidthShare x PhoneHeightShare of the room under the top bar (the shares the Backpack,
-- the Index and the Quests take), never bigger than on a 1080p desktop (DesktopScreen), never
-- smaller than the designer's. Nothing changes with a mouse.
Layout.PhoneWidthShare = 0.94
Layout.PhoneHeightShare = 0.84
Layout.DesktopScreen = Vector2.new(1920, 1080)
-- Pixels always left between the window (its header included) and the room's edges.
Layout.PhoneMargin = 4
-- The controllers' slide in lasts 0.24-0.26 s: a window that was still sliding when the screen
-- changed is put in its new place this long after.
Layout.PhoneSlideSeconds = 0.4
-- 2026-09-26 (owner, phone playtest): the designer's Community, Streak and Playtime Boost windows
-- and the Time Gift came out huge and too low on phones. Grown to 84% of the room, their header
-- (icon, title, Close: 9-17% of the window's height above it) came on top of that, so window and
-- header filled the whole room and the window sat on the bottom edge. Those windows hand
-- PhoneBlock to BindPhoneFit instead: the window and its header TOGETHER take Share of the room
-- (the Daily Login's 80%), grown or shrunk to it, and that block stands Lift of the room above
-- the room's middle. Every other window keeps the fit below.
Layout.PhoneBlock = { Share = 0.8, Lift = 0.04 }

-- A window's pixel size for its `size` on a `width` x `height` screen, as its
-- UIAspectRatioConstraint `shape` (if any; or a table with the same fields) leaves it.
function Layout.WindowSize(size: UDim2, shape: any, width: number, height: number): (number, number)
	local w = size.X.Scale * width + size.X.Offset
	local h = size.Y.Scale * height + size.Y.Offset
	if shape and shape.AspectRatio > 0 then
		if shape.AspectType == Enum.AspectType.ScaleWithParentSize then
			if shape.DominantAxis == Enum.DominantAxis.Height then
				w = h * shape.AspectRatio
			else
				h = w / shape.AspectRatio
			end
		else
			w = math.min(w, h * shape.AspectRatio)
			h = w / shape.AspectRatio
		end
	end
	return w, h
end

-- Only numbers, so the rule can be checked without a device (audit/test_opt6_mobile_panels).
-- `screen` is PhoneScreen's. `window` is the window at the designer's Size on that screen:
-- Width x Height pixels; Header, how far its icon, title and Close stand above its top edge,
-- as a share of its height; Span, the width of everything that grows with it about its centre
-- (the pieces past its sides, the Shop's category bar), its own Width when nil; MaxHeight, its
-- height on a 1080p desktop. Returns Grow (1: left alone), the Width and Height it gets and,
-- when it grows, where its centre goes, in scale of the screen's height: OpenY centres the
-- window, header included, in the room under the top bar; ClosedY puts it wholly below the
-- screen.
function Layout.PhoneFit(screen, window)
	local width, height = window.Width, window.Height
	local fit = { Grow = 1, Width = width, Height = height, OpenY = nil :: number?, ClosedY = nil :: number? }
	local top = math.clamp(screen.TopInset or 0, 0, math.max(0, screen.Height - 1))
	local room = screen.Height - top
	if not screen.Compact or width <= 0 or height <= 0 or screen.Width <= 0 or room <= 0 then
		return fit
	end
	local over = math.max(0, window.Header or 0)
	-- 2026-09-26 (owner): a PhoneBlock window (window.Share, window.Lift): window and header
	-- together Share of the room (or less where the width or a 1080p desktop binds), the block
	-- Lift of the room above the room's middle, never closer than PhoneMargin to its edges.
	local share = tonumber(window.Share)
	if share and share > 0 then
		local sized = math.min(
			share * room / (1 + over),
			Layout.PhoneWidthShare * screen.Width * height / math.max(width, window.Span or 0),
			window.MaxHeight or math.huge,
			(room - 2 * Layout.PhoneMargin) / (1 + over)
		)
		if sized <= 0 then
			return fit
		end
		fit.Grow = sized / height
		fit.Width, fit.Height = width * fit.Grow, sized
		local block = sized * (1 + over)
		local lift = math.max(0, tonumber(window.Lift) or 0) * room
		local blockTop = math.clamp((room - block) / 2 - lift, Layout.PhoneMargin, math.max(Layout.PhoneMargin, room - Layout.PhoneMargin - block))
		fit.OpenY = (top + blockTop + over * sized + sized / 2) / screen.Height
		fit.ClosedY = 1 + (sized / 2 + over * sized + Layout.PhoneMargin) / screen.Height
		return fit
	end
	local grown = math.min(
		Layout.PhoneHeightShare * room,
		Layout.PhoneWidthShare * screen.Width * height / math.max(width, window.Span or 0),
		window.MaxHeight or math.huge,
		-- The header counts too: window and header stay whole inside the room.
		(room - 2 * Layout.PhoneMargin) / (1 + over)
	)
	if grown <= height then
		return fit
	end
	fit.Grow = grown / height
	fit.Width, fit.Height = width * fit.Grow, grown
	fit.OpenY = (top + (room + over * grown) / 2) / screen.Height
	fit.ClosedY = 1 + (grown / 2 + over * grown + Layout.PhoneMargin) / screen.Height
	return fit
end

-- A window that keeps its designer's shape on a phone (2026-09-22, owner: "the Backpack and
-- Rebirth windows stretch horizontally on phones"). BindPhoneFit's windows keep theirs through
-- their own UIAspectRatioConstraint (WindowSize above); a window its controller sizes itself
-- (the Backpack) asks here instead of filling PhoneWidthShare x PhoneHeightShare of the room,
-- which drew the Backpack about 2.4 to 1 instead of 1.28 to 1. Returns the largest `aspect`
-- (width / height) rectangle inside that box of a `width` x `height` room, its pieces above it
-- (`over`, a share of its height) and past its sides (`beside`, a share of its width) whole
-- inside the room with PhoneMargin, and CentreY: where its centre goes, in pixels from the
-- room's top, so the window and its header together sit in the middle of the room.
function Layout.AspectBox(width: number, height: number, aspect: number, over: number?, beside: number?): (number, number, number)
	local above = math.max(0, over or 0)
	local side = math.max(0, beside or 0)
	if width <= 0 or height <= 0 or not aspect or aspect <= 0 then
		return 0, 0, height / 2
	end
	local h = math.max(0, math.min(
		Layout.PhoneHeightShare * height,
		Layout.PhoneWidthShare * width / (aspect * (1 + 2 * side)),
		(height - 2 * Layout.PhoneMargin) / (1 + above)
	))
	return h * aspect, h, (height + above * h) / 2
end

-- How far the pieces placed straight in `frame` stand above its top edge and past its sides, as
-- shares of its height and width (the header of the designer's windows: icon, title, Close).
function Layout.Overhang(frame: GuiObject): (number, number)
	local above, beside = 0, 0
	for _, child in ipairs(frame:GetChildren()) do
		if child:IsA("GuiObject") and child.Visible then
			local size, position, anchor = child.Size, child.Position, child.AnchorPoint
			above = math.max(above, anchor.Y * size.Y.Scale - position.Y.Scale)
			beside = math.max(beside, anchor.X * size.X.Scale - position.X.Scale, position.X.Scale + (1 - anchor.X) * size.X.Scale - 1)
		end
	end
	return above, beside
end

-- The product of every UIScale on `inst` and its ancestors (up to its ScreenGui): a layout's
-- AbsoluteContentSize and a frame's AbsoluteSize come out multiplied by it, while CanvasSize and
-- a UIListLayout's Padding are read before it.
function Layout.ScaleChain(inst: Instance?): number
	local product = 1
	local node = inst
	while node and not node:IsA("ScreenGui") do
		for _, child in ipairs(node:GetChildren()) do
			if child:IsA("UIScale") then
				product *= child.Scale
			end
		end
		node = node.Parent
	end
	return product
end

-- Share of a list's height always left under its last card, so it never ends flush with the edge.
Layout.ListEndRoom = 0.08

-- A vertical list's canvas, in the list's own (unscaled) pixels, from what its UIListLayout
-- reports on screen: `content` (AbsoluteContentSize.Y) and `window` (the list's AbsoluteSize.Y)
-- are divided by `scale` (ScaleChain); `gapShare` is the designer's gap between cards as a share
-- of the list's height. Returns the gap (pixels, for the layout's Padding) and the canvas
-- height: the content plus a gap and at least ListEndRoom of the window under the last card.
function Layout.ListCanvas(content: number, window: number, scale: number, gapShare: number): (number, number)
	local s = if scale > 0 then scale else 1
	local own = window / s
	local gap = math.max(0, math.floor(gapShare * own + 0.5))
	return gap, math.ceil(content / s + math.max(gap, Layout.ListEndRoom * own))
end

-- The screen a ScreenGui lays its windows out on: its size in pixels (Width, Height), how much
-- of it lies under Roblox's top bar (TopInset) and whether it is a compact touch screen
-- (Compact). Nil while there is no screen to measure yet.
function Layout.PhoneScreen(gui: ScreenGui)
	local camera = Workspace.CurrentCamera
	local view = if camera then camera.ViewportSize else Vector2.new(0, 0)
	local topBar = 0
	pcall(function()
		topBar = GuiService:GetGuiInset().Y
	end)
	local underTopBar = gui.ScreenInsets == Enum.ScreenInsets.CoreUISafeInsets
	local size = gui.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 then
		-- Not laid out yet: the screen, less the top bar when the ScreenGui starts under it.
		size = Vector2.new(view.X, if underTopBar then view.Y - topBar else view.Y)
	end
	if size.X <= 0 or size.Y <= 0 then
		return nil
	end
	local touch = UserInputService.TouchEnabled
	return {
		Width = size.X,
		Height = size.Y,
		TopInset = if underTopBar then 0 else topBar,
		Compact = touch and HudErgonomics.IsCompact(view.X, view.Y, touch, UserInputService.KeyboardEnabled),
	}
end

-- PhoneFit on `gui`'s screen now, for a window authored at `size` and shaped by `shape` (its
-- UIAspectRatioConstraint, or a table with the same fields); `header` and `beside` are how far
-- its pieces stand above it and past its sides (shares of its height and width), `span` as in
-- BindPhoneFit; `options` is BindPhoneFit's (PhoneBlock). Nil while there is no screen to
-- measure yet.
function Layout.WindowFit(gui: ScreenGui, size: UDim2, shape: any, header: number?, beside: number?, span: ((number, number) -> number)?, options: any?)
	local screen = Layout.PhoneScreen(gui)
	if not screen then
		return nil
	end
	local width, height = Layout.WindowSize(size, shape, screen.Width, screen.Height)
	local _, desktopHeight = Layout.WindowSize(size, shape, Layout.DesktopScreen.X, Layout.DesktopScreen.Y)
	local reach = width * (1 + 2 * (beside or 0))
	if span then
		reach = math.max(reach, span(screen.Width, screen.Height))
	end
	return Layout.PhoneFit(screen, {
		Width = width, Height = height, Header = header, Span = reach, MaxHeight = desktopHeight,
		Share = type(options) == "table" and options.Share or nil,
		Lift = type(options) == "table" and options.Lift or nil,
	})
end

-- The screen changed with `frame` (in `gui`) open, its open place moving from `stale` to
-- `place()`: it goes there at once when it is at rest, else as soon as its slide in has ended
-- (`place` is read then, so a later change wins). A closed or closing window is left where
-- the controller puts it.
function Layout.FollowOpen(gui: ScreenGui, frame: GuiObject, stale: UDim2, place: () -> UDim2)
	if stale == place() or not gui.Enabled or not frame.Visible then
		return
	end
	if frame.Position == stale then
		frame.Position = place()
	else
		task.delay(Layout.PhoneSlideSeconds, function()
			if frame.Position == stale then
				frame.Position = place()
			end
		end)
	end
end

-- Keeps `frame` (one of the designer's windows, in `gui`) at its phone size (PhoneFit): now,
-- and whenever the screen changes. Only its Size is written, in scale and only when its
-- growth changes, so everything inside follows and the UIScales others keep on it
-- (ModalJuice's pop, ConsolePanelSupport's console fit) are left alone. `open` and `closed`
-- are the positions the controller slides it between; after every change `apply(fit)` gets
-- the ones to use from then on (fit.Open, fit.Closed; fit.Grow for pieces that grow with it).
-- `span(width, height)`, when given, is PhoneFit's Span on that screen, for pieces outside
-- the window. `options` (2026-09-26): Layout.PhoneBlock for a window that, header included,
-- takes PhoneBlock.Share of the room, raised by PhoneBlock.Lift. Returns the function that fits
-- it again.
function Layout.BindPhoneFit(gui: ScreenGui, frame: GuiObject, open: UDim2, closed: UDim2, apply: ((any) -> ())?, span: ((number, number) -> number)?, options: any?)
	local authored = frame.Size
	local shape = frame:FindFirstChildOfClass("UIAspectRatioConstraint")
	local shownGrow = 1
	local shownOpen = open
	local cameraConnection = nil

	local function refit()
		-- The window keeps its authored shape: `shape` (its UIAspectRatioConstraint, the
		-- designer's 1.28 to 1 for Rebirth, Evolve, Worlds...) still solves the grown Size.
		local above, beside = Layout.Overhang(frame)
		local fit = Layout.WindowFit(gui, authored, shape, above, beside, span, options)
		if not fit then
			return
		end
		local grow = fit.Grow
		if grow ~= shownGrow then
			shownGrow = grow
			frame.Size = UDim2.new(authored.X.Scale * grow, authored.X.Offset * grow, authored.Y.Scale * grow, authored.Y.Offset * grow)
		end
		fit.Open = if fit.OpenY then UDim2.new(open.X.Scale, open.X.Offset, fit.OpenY, 0) else open
		fit.Closed = if fit.ClosedY then UDim2.new(closed.X.Scale, closed.X.Offset, fit.ClosedY, 0) else closed
		-- The screen changed with the window open: it moves to its new place.
		local stale = shownOpen
		shownOpen = fit.Open
		Layout.FollowOpen(gui, frame, stale, function()
			return shownOpen
		end)
		if apply then
			apply(fit)
		end
	end

	local function bindCamera()
		if cameraConnection then
			cameraConnection:Disconnect()
		end
		local camera = Workspace.CurrentCamera
		if camera then
			cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(refit)
		end
		refit()
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)
	bindCamera()
	return refit
end

return Layout
