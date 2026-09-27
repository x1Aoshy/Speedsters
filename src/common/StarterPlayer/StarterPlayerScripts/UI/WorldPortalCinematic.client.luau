-- WorldPortalCinematic.client.luau
-- The camera flight that shows the lobby portal when the next world unlocks.
--
-- When it plays: only when World2Unlocked / World3Unlocked turns on while the player is in
-- the game. Worlds/WorldPortalService saves that flag the moment the requirements are first
-- met and it never turns off, so the flight plays once per world, ever: not on a later
-- join, not after a respawn, a level up or a rebirth. (Shared/WorldPortalShot.Observe.)
--
-- What it shows: a shutter closes, the camera cuts to the FRONT of the lobby portal (the
-- portal slab's own thin axis, on the lobby's side), the shutter opens to letterbox bars,
-- the camera swings round to face the portal while the words pop in, then the shutter
-- closes again and opens on the runner. The lobby is streamed in first, so the shot is
-- never of an empty sky when the runner is far down the track.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Shot = require(Shared:WaitForChild("WorldPortalShot"))
local InterfaceHider = require(Shared:WaitForChild("InterfaceHider"))
local MenuEvents = require(Shared:WaitForChild("MenuEvents"))
local TutorialGuide = require(Shared:WaitForChild("TutorialGuide"))
-- The letterbox on phones (2026-09-22): thin bars, the words and Skip fitted on screen.
local CinematicFit = require(Shared:WaitForChild("CinematicFit"))
local LOW_POWER = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local INK = Color3.fromRGB(11, 27, 61)
local WHITE = Color3.new(1, 1, 1)
local STUDS = "rbxassetid://135496826236732"
local SOUNDS = {
	Reveal = { Id = "rbxassetid://80736831159506", Volume = 0.85 },
	Portal = { Id = "rbxassetid://72264591133889", Volume = 0.75 },
}
-- Each letterbox bar, as a share of the screen height: CinematicFit.Bars (0.11 on a computer,
-- 0.05 on a phone), worked out by wordsLayout below.
local RENDER_NAME = "WorldPortalCinematicCamera"
local INTERFACE_OWNER = "WorldPortalCinematic" -- this script's hold on Shared/InterfaceHider
local WORLD_2_PLACE_ID = Config.World2PlaceId or 116359653478954
local WORLD_3_PLACE_ID = Config.World3PlaceId or 128432111599629

local function getCurrentWorld(): number
	if Config.IsWorld3Place == true
		or ReplicatedStorage:GetAttribute("PlaceWorldNumber") == 3
		or Workspace:GetAttribute("PlaceWorldNumber") == 3
		or game.PlaceId == WORLD_3_PLACE_ID
		or game.PlaceId == 94956471703437
	then
		return 3
	end
	if Config.IsWorld2Place == true
		or ReplicatedStorage:GetAttribute("PlaceWorldNumber") == 2
		or Workspace:GetAttribute("PlaceWorldNumber") == 2
		or game.PlaceId == WORLD_2_PLACE_ID
		or game.PlaceId == 96501592055150
	then
		return 2
	end
	return 1
end

local CURRENT_WORLD = getCurrentWorld()
local TARGET_WORLD = if CURRENT_WORLD == 1 then 2 elseif CURRENT_WORLD == 2 then 3 else 0
if TARGET_WORLD == 0 then
	return -- the last world has no portal to unlock
end
local UNLOCK_ATTRIBUTE = "World" .. TARGET_WORLD .. "Unlocked"

local function make(className, properties, parent)
	local object = Instance.new(className)
	for key, value in properties do
		object[key] = value
	end
	object.Parent = parent
	return object
end

local function playSound(info)
	local sound = make("Sound", { SoundId = info.Id, Volume = info.Volume }, SoundService)
	pcall(function()
		sound:Play()
	end)
	task.delay(6, function()
		sound:Destroy()
	end)
end

----------------------------------------------------------------------
-- The portal
----------------------------------------------------------------------
local function lobbySpawn()
	for _, item in Workspace:GetDescendants() do
		if item:IsA("SpawnLocation") and item.Enabled then
			return item.Position
		end
	end
	return nil
end

-- The lobby portal's centre, the direction its front faces, and the part (nil when the
-- authored spot had to be used).
local function findPortal()
	local fallback = Shot.Fallback[CURRENT_WORLD]
	local parts = {}
	for _, item in Workspace:GetDescendants() do
		if Shot.PortalNames[item.Name] and item:IsA("BasePart") then
			table.insert(parts, item)
		end
	end
	local spawn = lobbySpawn()
	local part = Shot.Pick(parts, fallback.Position) or (spawn and Shot.Pick(parts, spawn))
	if not part then
		return fallback.Position, fallback.Front, nil
	end
	local reference = if spawn then spawn - part.Position else fallback.Front
	return part.Position, Shot.Front(part.CFrame, part.Size, reference), part
end

-- How far from `focus` the camera can sit along the flight before scenery is in the way.
local function clearReach(focus, front, portalPart)
	local exclude = {}
	if player.Character then
		table.insert(exclude, player.Character)
	end
	if portalPart then
		table.insert(exclude, portalPart.Parent ~= Workspace and portalPart.Parent or portalPart)
	end
	local reach = math.huge
	for step = 0, 4 do
		local eye = Shot.Eye(focus, front, step / 4)
		local offset = eye - focus
		for _ = 1, 5 do
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = exclude
			params.IgnoreWater = true
			local hit = Workspace:Raycast(focus, offset, params)
			if not hit then
				break
			end
			-- See-through and tiny things do not block the view.
			if hit.Instance.Transparency >= 0.6 or hit.Instance.Size.Magnitude < 3 then
				table.insert(exclude, hit.Instance)
			else
				reach = math.min(reach, hit.Distance - 2.5)
				break
			end
		end
	end
	return if reach == math.huge then nil else reach
end

----------------------------------------------------------------------
-- The words and the shutter, in the game's look: Fredoka, navy outlines, stud buttons
----------------------------------------------------------------------
local function words(parent, properties, maxSize, strokeThickness)
	local label = make("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.FredokaOne,
		TextColor3 = WHITE,
		TextScaled = true,
		TextTransparency = 1,
		ZIndex = 56,
	}, parent)
	for key, value in properties do
		label[key] = value
	end
	make("UITextSizeConstraint", { MaxTextSize = maxSize, MinTextSize = 8 }, label)
	make("UIStroke", { Name = "Outline", Color = INK, Thickness = strokeThickness, Transparency = 1 }, label)
	return label
end

local function skipButton(parent)
	local button = make("TextButton", {
		Name = "SkipCinematic",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -18, 1, -10), -- placed by wordsLayout
		Size = UDim2.new(0.14, 0, CinematicFit.DesktopBar, -16),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 70,
	}, parent)
	make("UISizeConstraint", { MinSize = Vector2.new(84, 26), MaxSize = Vector2.new(150, 46) }, button)
	make("UICorner", { CornerRadius = UDim.new(0, 12) }, button)
	make("UIGradient", {
		Name = "Fill",
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 119, 121)),
			ColorSequenceKeypoint.new(0.46, Color3.fromRGB(255, 34, 60)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 14, 50)),
		}),
	}, button)
	local studs = make("ImageLabel", {
		Name = "Studs", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
		Image = STUDS, ImageTransparency = 0.2, Active = false, ZIndex = 70,
	}, button)
	make("UICorner", { CornerRadius = UDim.new(0, 12) }, studs)
	local rim = make("UIStroke", { Name = "Rim", Color = Color3.fromRGB(255, 190, 195), Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, button)
	pcall(function()
		rim.BorderOffset = UDim.new(0, -2)
	end)
	local edge = make("UIStroke", { Name = "Edge", Color = Color3.fromRGB(84, 11, 12), Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, button)
	pcall(function()
		edge.ZIndex = 2
	end)
	local label = make("TextLabel", {
		Name = "Label", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -14, 1, -8),
		Font = Enum.Font.FredokaOne, Text = "SKIP", TextColor3 = WHITE, TextScaled = true,
		Active = false, ZIndex = 71,
	}, button)
	make("UITextSizeConstraint", { MaxTextSize = 24, MinTextSize = 8 }, label)
	make("UIStroke", { Name = "Outline", Color = Color3.fromRGB(84, 11, 12), Thickness = 2 }, label)
	return button
end

----------------------------------------------------------------------
-- Where the words and Skip go on this screen
----------------------------------------------------------------------
-- The top bar's height (Roblox's own buttons), 0 when it cannot be read.
local function topBarInset()
	local ok, inset = pcall(function()
		return GuiService:GetGuiInset()
	end)
	return if ok and typeof(inset) == "Vector2" then inset.Y else 0
end

-- LETTERBOX LAYOUT BEGIN
-- The words: 0.9 x 0.3 of the screen, at most 920 x 250 px, just above the bottom bar.
local WORDS_SHARE = Vector2.new(0.9, 0.3)
local WORDS_MAX = Vector2.new(920, 250)
-- Skip: 0.14 of the width by the bar's height less 16 px, within 84 x 26 and 150 x 46 px, 18 px
-- from the right and 10 px from the bottom (of the safe area).
local SKIP_MIN, SKIP_MAX = Vector2.new(84, 26), Vector2.new(150, 46)
-- 2026-09-22 (owner): the 0.11 bars took 22 % of a phone's screen and cut into the words. On a
-- phone the bars are 0.05; Skip moves inside the safe area (notch, home indicator); the words sit
-- above the bottom bar and above Skip, and get the largest scale <= 1 (a UIScale of their own,
-- under the pop's) at which all of them, at the pop's peak, fit between the bars and the safe
-- area. On a computer this is exactly the old layout: 0.11 bars and scale 1.
local function wordsLayout(view, phoneHint, topBar)
	local isPhone = CinematicFit.IsPhone(view.X, view.Y, phoneHint)
	local bar = CinematicFit.Bars(view.X, view.Y, isPhone)
	local insets = CinematicFit.Insets(view.X, view.Y, isPhone, topBar)
	local band = CinematicFit.Band(view.X, view.Y, bar, insets)
	local margin = CinematicFit.Margin
	-- (Whole pixels, rounded towards the safe side: a UDim's offset is an integer.)
	local skipSize = Vector2.new(
		math.floor(math.clamp(view.X * 0.14, SKIP_MIN.X, SKIP_MAX.X)),
		math.floor(math.clamp(view.Y * bar - 16, SKIP_MIN.Y, SKIP_MAX.Y))
	)
	local skipRight = math.ceil(insets.Right + 18)
	local skipBottom = math.ceil(insets.Bottom + 10)
	local skipTop = view.Y - skipBottom - skipSize.Y
	local words = Vector2.new(
		math.floor(math.min(view.X * WORDS_SHARE.X, WORDS_MAX.X)),
		math.floor(math.min(view.Y * WORDS_SHARE.Y, WORDS_MAX.Y))
	)
	-- The bottom edge of the words: as before (0.025 above the bar), but never over Skip or the band's edge.
	local bottom = math.floor(math.min(view.Y * (1 - bar - 0.025), skipTop - margin, band.Y + band.H - margin))
	local peak = CinematicFit.PopPeak
	local fit = CinematicFit.Fit(words.X * peak, words.Y * peak, band.W, bottom + margin - band.Y)
	return {
		Bar = bar,
		Band = band,
		Insets = insets,
		Words = words,
		Bottom = bottom,
		Fit = fit,
		SkipSize = skipSize,
		SkipRight = skipRight,
		SkipBottom = skipBottom,
	}
end
-- LETTERBOX LAYOUT END

----------------------------------------------------------------------
-- The flight
----------------------------------------------------------------------
local playing = false

local function restoreCamera(camera, saved)
	pcall(function()
		RunService:UnbindFromRenderStep(RENDER_NAME)
	end)
	if not camera then
		return
	end
	camera.CameraType = if saved.CameraType == Enum.CameraType.Scriptable then Enum.CameraType.Custom else saved.CameraType
	camera.FieldOfView = saved.FieldOfView
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end
end

local function playCinematic()
	if playing then
		return
	end
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	playing = true
	player:SetAttribute("WorldPortalCinematicActive", true)
	-- An open menu closes the way it does on a respawn, so its controller knows it is closed and
	-- what comes back after the flight is the HUD, not a panel over the runner.
	MenuEvents.CloseAll:Fire()
	local saved = { CameraType = camera.CameraType, FieldOfView = camera.FieldOfView }
	local timeline = Shot.Timeline

	local gui = make("ScreenGui", {
		Name = "WorldPortalCinematicGui",
		DisplayOrder = 1000100,
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, PlayerGui)
	-- However the flight ends (its end, Skip, an error: pump() destroys this GUI), the interface
	-- comes back with it.
	gui.Destroying:Connect(function()
		InterfaceHider.Show(INTERFACE_OWNER)
	end)
	local barTop = make("Frame", {
		Name = "BarTop", BackgroundColor3 = INK, BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 0), ZIndex = 50,
	}, gui)
	local barBottom = make("Frame", {
		Name = "BarBottom", BackgroundColor3 = INK, BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0), ZIndex = 50,
	}, gui)
	local function shutter(share, seconds, style, direction)
		local info = TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.InOut)
		-- A closed shutter overlaps by a pixel, so no line of the world shows through.
		local size = UDim2.new(1, 0, share, if share >= 0.5 then 1 else 0)
		TweenService:Create(barTop, info, { Size = size }):Play()
		local tween = TweenService:Create(barBottom, info, { Size = size })
		tween:Play()
		return tween
	end

	-- The words sit in a frame of their own whose UIScale fits them to the screen (wordsLayout);
	-- the pop is the words' own UIScale inside it, so the two multiply and the pop is untouched.
	-- Both grow from the bottom middle (their AnchorPoint), as the pop always did.
	local wordsFit = make("Frame", {
		Name = "WordsFit", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.865),
		Size = UDim2.fromOffset(WORDS_MAX.X, WORDS_MAX.Y), BackgroundTransparency = 1, ZIndex = 55,
	}, gui)
	local fitScale = make("UIScale", { Name = "Fit", Scale = 1 }, wordsFit)
	local block = make("Frame", {
		Name = "Words", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 55,
	}, wordsFit)
	local pop = make("UIScale", { Scale = 0.6 }, block)
	local kicker = words(block, {
		Name = "Kicker", Size = UDim2.fromScale(1, 0.2),
		Text = "Something changed, please go check!", TextColor3 = Color3.fromRGB(255, 235, 120),
	}, 30, 2.5)
	local title = words(block, {
		Name = "Title", Position = UDim2.fromScale(0, 0.2), Size = UDim2.fromScale(1, 0.54),
		Text = "WORLD " .. TARGET_WORLD .. " UNLOCKED!",
	}, 72, 4.5)
	local shine = make("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(0.45, Color3.fromRGB(255, 232, 90)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 160, 6)),
		}),
	}, title)
	local sub = words(block, {
		Name = "Sub", Position = UDim2.fromScale(0, 0.76), Size = UDim2.fromScale(1, 0.2),
		Text = "A new portal is open in the lobby!", TextColor3 = Color3.fromRGB(220, 245, 255),
	}, 28, 2.5)
	local skip = skipButton(gui)
	skip.Visible = false

	-- The layout for this screen, again whenever it changes size (a phone turned round, a
	-- resized window). The bars follow at once while they rest as a letterbox; mid-tween the
	-- tween's end puts them right.
	local barShare = CinematicFit.DesktopBar
	local letterboxed = false
	local lastView = nil
	local function applyLayout()
		local current = Workspace.CurrentCamera
		local view = if current then current.ViewportSize else Vector2.new(1280, 720)
		lastView = view
		local layout = wordsLayout(view, LOW_POWER, topBarInset())
		barShare = layout.Bar
		wordsFit.Position = UDim2.new(0.5, 0, 0, layout.Bottom)
		wordsFit.Size = UDim2.fromOffset(layout.Words.X, layout.Words.Y)
		fitScale.Scale = layout.Fit
		skip.Position = UDim2.new(1, -layout.SkipRight, 1, -layout.SkipBottom)
		skip.Size = UDim2.fromOffset(layout.SkipSize.X, layout.SkipSize.Y)
		if letterboxed then
			barTop.Size = UDim2.fromScale(1, barShare)
			barBottom.Size = UDim2.fromScale(1, barShare)
		end
	end
	applyLayout()
	local resized = camera:GetPropertyChangedSignal("ViewportSize"):Connect(applyLayout)
	gui.Destroying:Connect(function()
		resized:Disconnect()
	end)

	local skipped = false
	skip.Activated:Connect(function()
		skipped = true
	end)

	-- 1. The shutter closes; behind it the lobby streams in and the camera cuts to the portal.
	shutter(0.5, 0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.In).Completed:Wait()
	-- Behind the closed shutter the whole interface goes away: HUD, topbar icons, touch controls,
	-- core GUI. Only this GUI stays (Shared/InterfaceHider).
	InterfaceHider.Hide(INTERFACE_OWNER, { gui })
	local fallback = Shot.Fallback[CURRENT_WORLD]
	pcall(function()
		player:RequestStreamAroundAsync(fallback.Position, 2)
	end)
	local focus, front, portalPart = findPortal()
	local reach = clearReach(focus, front, portalPart)
	camera = Workspace.CurrentCamera or camera
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.lookAt(Shot.Eye(focus, front, 0, reach), focus)

	local started = os.clock()
	RunService:BindToRenderStep(RENDER_NAME, Enum.RenderPriority.Camera.Value + 2, function()
		local now = os.clock() - started
		local current = Workspace.CurrentCamera
		if not current then
			return
		end
		current.CameraType = Enum.CameraType.Scriptable
		current.CFrame = CFrame.lookAt(Shot.Eye(focus, front, now / timeline.Hold, reach), focus)
		shine.Offset = Vector2.new(0, math.sin(now * 2.2) * 0.18)
		if current.ViewportSize ~= lastView then
			applyLayout() -- a new camera, or a size change the first camera's signal did not see
		end
	end)

	-- 2. It opens to letterbox bars on the portal and the words pop in.
	playSound(SOUNDS.Reveal)
	playSound(SOUNDS.Portal)
	applyLayout()
	shutter(barShare, timeline.Open, Enum.EasingStyle.Quart, Enum.EasingDirection.Out).Completed:Connect(function(state)
		-- Resting as a letterbox from here: a size change now moves the bars straight away.
		if state == Enum.PlaybackState.Completed and gui.Parent and not skipped and os.clock() - started < timeline.Hold then
			letterboxed = true
			applyLayout()
		end
	end)
	skip.Visible = true
	TweenService:Create(pop, TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	for index, label in { kicker, title, sub } do
		local info = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.18 * index)
		TweenService:Create(label, info, { TextTransparency = 0 }):Play()
		TweenService:Create(label.Outline, info, { Transparency = 0 }):Play()
	end

	while not skipped and os.clock() - started < timeline.Hold and gui.Parent do
		task.wait()
	end

	-- 3. The words leave, the shutter closes, the camera goes home, the shutter opens.
	letterboxed = false
	skip.Visible = false
	TweenService:Create(pop, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.8 }):Play()
	for _, label in { kicker, title, sub } do
		TweenService:Create(label, TweenInfo.new(0.22), { TextTransparency = 1 }):Play()
		TweenService:Create(label.Outline, TweenInfo.new(0.22), { Transparency = 1 }):Play()
	end
	shutter(0.5, timeline.Close, Enum.EasingStyle.Quad, Enum.EasingDirection.In).Completed:Wait()
	restoreCamera(Workspace.CurrentCamera, saved)
	InterfaceHider.Show(INTERFACE_OWNER) -- still behind the closed shutter: it opens on the runner and the HUD
	task.wait(0.12)
	shutter(0, timeline.Reopen, Enum.EasingStyle.Quad, Enum.EasingDirection.Out).Completed:Wait()
	gui:Destroy()
	player:SetAttribute("WorldPortalCinematicActive", false)
	playing = false
end

----------------------------------------------------------------------
-- When it plays
----------------------------------------------------------------------
local gate = Shot.NewGate()
local dataReady = false
local pending = false
local pumping = false

local function nearPortal(root)
	local position = Shot.Fallback[CURRENT_WORLD].Position
	return (root.Position - position).Magnitude < Shot.NearPortal
end

-- "ready": play now. "drop": it is not needed any more. "wait": try again shortly.
local function readiness()
	if player:GetAttribute(UNLOCK_ATTRIBUTE) ~= true then
		return "drop"
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return "wait"
	end
	if nearPortal(root) then
		return "drop" -- unlocked by walking into the portal: the runner is looking at it
	end
	-- A HUD guide already saved as seen (skipped, done, or 10 s on screen) gives way to the
	-- one-time flight instead of holding it for the whole 180 s (2026-09-21).
	if player:GetAttribute("GuidedTutorialOpen") == true then
		TutorialGuide.CloseIfSeen(player)
	end
	if player:GetAttribute("FirstTimeTutorialActive") == true
		or player:GetAttribute("GuidedTutorialOpen") == true
		or PlayerGui:FindFirstChild("SpeedsterLoadingScreen")
		or player:GetAttribute("AdminTreadmillCinematicActive") == true
		or InterfaceHider.IsHidden(INTERFACE_OWNER) -- the treadmill reveal has the camera: after it
	then
		return "wait"
	end
	return "ready"
end

local function pump()
	if pumping then
		return
	end
	pumping = true
	task.spawn(function()
		local deadline = os.clock() + 180
		while pending and os.clock() < deadline do
			local state = readiness()
			if state == "ready" then
				pending = false
				local ok, problem = pcall(playCinematic)
				if not ok then
					warn("[WorldPortalCinematic] " .. tostring(problem))
					restoreCamera(Workspace.CurrentCamera, { CameraType = Enum.CameraType.Custom, FieldOfView = 70 })
					local gui = PlayerGui:FindFirstChild("WorldPortalCinematicGui")
					if gui then
						gui:Destroy()
					end
					InterfaceHider.Show(INTERFACE_OWNER)
					player:SetAttribute("WorldPortalCinematicActive", false)
					playing = false
				end
			elseif state == "drop" then
				pending = false
			else
				task.wait(0.5)
			end
		end
		pending = false
		pumping = false
		player:SetAttribute("WorldPortalCinematicPending", false)
	end)
end

local function observe()
	if Shot.Observe(gate, TARGET_WORLD, player:GetAttribute(UNLOCK_ATTRIBUTE) == true, dataReady) then
		pending = true
		-- 2026-09-21: the flight waits for an open HUD guide (readiness), but UI/EvolveController
		-- only saw WorldPortalCinematicActive, set once it plays, so the Evolve guide could take
		-- the screen first and the one-time flight ran out its 180 s. While this is true the
		-- guides wait; pump() clears it once the flight has played, been dropped or given up.
		player:SetAttribute("WorldPortalCinematicPending", true)
		pump()
	end
end

player:GetAttributeChangedSignal(UNLOCK_ATTRIBUTE):Connect(observe)
task.spawn(function()
	while player:GetAttribute("DataLoaded") ~= true do
		player:GetAttributeChangedSignal("DataLoaded"):Wait()
	end
	-- The saved flags arrive with DataLoaded; a moment later they are all in.
	task.wait(1)
	dataReady = true
	observe() -- the baseline: a world that is already unlocked never plays
end)

script.Destroying:Connect(function()
	pcall(function()
		RunService:UnbindFromRenderStep(RENDER_NAME)
	end)
	InterfaceHider.Show(INTERFACE_OWNER)
end)
