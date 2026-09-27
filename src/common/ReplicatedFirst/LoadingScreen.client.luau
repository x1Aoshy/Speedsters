--!strict
-- LoadingScreen.client.luau
-- Modern minimalist monochrome loading screen with dual-state vector lightning bolts.
-- Pure black backdrop, clean game icon, smooth crossfade from dimmed white to electric yellow.

local ReplicatedFirst = game:GetService("ReplicatedFirst")
ReplicatedFirst:RemoveDefaultLoadingScreen()

local Players = game:GetService("Players")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")

local GAME_ICON = "rbxassetid://92044769924002"
local BOLT_OFF_ICON = "rbxassetid://106423900726418" -- Dimmed / white uncharged state
local BOLT_ON_ICON = "rbxassetid://123961542220277"  -- Vibrant electric yellow active state
local BOLT_COUNT = 3

local COLOR_BG = Color3.fromRGB(0, 0, 0)
local COLOR_WHITE = Color3.fromRGB(255, 255, 255)
local COLOR_YELLOW = Color3.fromRGB(255, 225, 0)
local COLOR_YELLOW_BRIGHT = Color3.fromRGB(255, 245, 100)
local COLOR_MUTED = Color3.fromRGB(150, 150, 150)

local TIPS = {
	"Train on treadmills to gain Speed faster.",
	"Finish a lap to earn Wins.",
	"Rebirth to grow stronger on your next run.",
	"Complete quests for Spin Tickets.",
	"Use AFK Mode when you need a break.",
}

local MINIMUM_SHOW_TIME = 1.25
local MAX_WAIT_FOR_CHARACTER = 15
local FADE_SECONDS = 0.5

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local previous = playerGui:FindFirstChild("SpeedsterLoadingScreen")
if previous then
	previous:Destroy()
end

local startedAt = os.clock()
local active = true

local gui = Instance.new("ScreenGui")
gui.Name = "SpeedsterLoadingScreen"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 1000000
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

-- Pure solid black background (monochrome OLED black)
local background = Instance.new("Frame")
background.Name = "Background"
background.Size = UDim2.fromScale(1, 1)
background.BackgroundColor3 = COLOR_BG
background.BorderSizePixel = 0
background.Parent = gui

-- Hero container
local hero = Instance.new("Frame")
hero.Name = "Hero"
hero.AnchorPoint = Vector2.new(0.5, 0.5)
hero.Position = UDim2.fromScale(0.5, 0.47)
hero.Size = UDim2.fromOffset(380, 360)
hero.BackgroundTransparency = 1
hero.Parent = background

local heroScale = Instance.new("UIScale")
heroScale.Parent = hero
local function fitHero()
	local size = background.AbsoluteSize
	if size.X > 0 and size.Y > 0 then
		heroScale.Scale = math.clamp(math.min(size.X / 400, size.Y / 540), 0.55, 1.0)
	end
end
background:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitHero)
fitHero()

-- Game Icon (clean presentation without colored borders or tint alterations)
local icon = Instance.new("ImageLabel")
icon.Name = "GameIcon"
icon.AnchorPoint = Vector2.new(0.5, 0)
icon.Position = UDim2.new(0.5, 0, 0, 10)
icon.Size = UDim2.fromOffset(130, 130)
icon.BackgroundTransparency = 1
icon.BorderSizePixel = 0
icon.ScaleType = Enum.ScaleType.Fit
icon.Image = GAME_ICON
icon.Parent = hero

local iconCorner = Instance.new("UICorner")
iconCorner.CornerRadius = UDim.new(0, 24)
iconCorner.Parent = icon

-- Game Title
local title = Instance.new("TextLabel")
title.Name = "GameTitle"
title.AnchorPoint = Vector2.new(0.5, 0)
title.Position = UDim2.new(0.5, 0, 0, 160)
title.Size = UDim2.fromOffset(380, 34)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.Text = "SPEEDSTER ESCAPE"
title.TextColor3 = COLOR_WHITE
title.TextSize = 24
title.TextXAlignment = Enum.TextXAlignment.Center
title.Parent = hero

-- Status label
local status = Instance.new("TextLabel")
status.Name = "LoadingStatus"
status.AnchorPoint = Vector2.new(0.5, 0)
status.Position = UDim2.new(0.5, 0, 0, 202)
status.Size = UDim2.fromOffset(380, 20)
status.BackgroundTransparency = 1
status.Font = Enum.Font.GothamMedium
status.Text = "PREPARING YOUR RUN"
status.TextColor3 = COLOR_MUTED
status.TextSize = 12
status.TextXAlignment = Enum.TextXAlignment.Center
status.Parent = hero

-- Lightning Bolts Row (Dual-layer smooth crossfade: Off Dimmed White <-> On Electric Yellow)
local boltRow = Instance.new("Frame")
boltRow.Name = "BoltRow"
boltRow.AnchorPoint = Vector2.new(0.5, 0)
boltRow.Position = UDim2.new(0.5, 0, 0, 238)
boltRow.Size = UDim2.fromOffset(190, 52)
boltRow.BackgroundTransparency = 1
boltRow.Parent = hero

type BoltHandle = {
	container: Frame,
	offImg: ImageLabel,
	onImg: ImageLabel,
	scale: UIScale,
}

local bolts: { BoltHandle } = {}
local boltSpacing = 64

for index = 1, BOLT_COUNT do
	local container = Instance.new("Frame")
	container.Name = "Bolt" .. index
	container.AnchorPoint = Vector2.new(0.5, 0.5)
	container.Position = UDim2.new(0, (index - 1) * boltSpacing + 32, 0.5, 0)
	container.Size = UDim2.fromOffset(48, 48)
	container.BackgroundTransparency = 1
	container.Parent = boltRow

	local scale = Instance.new("UIScale")
	scale.Scale = 1.0
	scale.Parent = container

	-- Layer 1: Off state (dimmed / white uncharged bolt)
	local offImg = Instance.new("ImageLabel")
	offImg.Name = "OffIcon"
	offImg.AnchorPoint = Vector2.new(0.5, 0.5)
	offImg.Position = UDim2.fromScale(0.5, 0.5)
	offImg.Size = UDim2.fromOffset(44, 44)
	offImg.BackgroundTransparency = 1
	offImg.ScaleType = Enum.ScaleType.Fit
	offImg.Image = BOLT_OFF_ICON
	offImg.ImageColor3 = COLOR_WHITE
	offImg.ImageTransparency = 0.35
	offImg.Parent = container

	-- Layer 2: On state (active vibrant electric yellow bolt)
	local onImg = Instance.new("ImageLabel")
	onImg.Name = "OnIcon"
	onImg.AnchorPoint = Vector2.new(0.5, 0.5)
	onImg.Position = UDim2.fromScale(0.5, 0.5)
	onImg.Size = UDim2.fromOffset(44, 44)
	onImg.BackgroundTransparency = 1
	onImg.ScaleType = Enum.ScaleType.Fit
	onImg.Image = BOLT_ON_ICON
	onImg.ImageColor3 = COLOR_YELLOW
	onImg.ImageTransparency = 1.0 -- Starts hidden; crossfades in smoothly
	onImg.Parent = container

	bolts[index] = {
		container = container,
		offImg = offImg,
		onImg = onImg,
		scale = scale,
	}
end

-- Smooth crossfade function between dimmed white and electric yellow
local function animateBoltTransition(bolt: BoltHandle, charged: boolean, duration: number)
	local targetScale = if charged then 1.2 else 1.0
	local onTrans = if charged then 0.0 else 1.0
	local offTrans = if charged then 1.0 else 0.35

	local info = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(bolt.scale, info, { Scale = targetScale }):Play()
	TweenService:Create(bolt.onImg, info, { ImageTransparency = onTrans }):Play()
	TweenService:Create(bolt.offImg, info, { ImageTransparency = offTrans }):Play()
end

-- Frameless, Minimalist Tip
local tipText = Instance.new("TextLabel")
tipText.Name = "TipText"
tipText.AnchorPoint = Vector2.new(0.5, 1)
tipText.Position = UDim2.new(0.5, 0, 1, -40)
tipText.Size = UDim2.new(0.85, 0, 0, 36)
tipText.BackgroundTransparency = 1
tipText.Font = Enum.Font.GothamMedium
tipText.Text = TIPS[1]
tipText.TextColor3 = COLOR_MUTED
tipText.TextSize = 13
tipText.TextWrapped = true
tipText.TextXAlignment = Enum.TextXAlignment.Center
tipText.TextYAlignment = Enum.TextYAlignment.Center
tipText.Parent = background

-- Safe asset preloading
task.spawn(function()
	local ok, err = pcall(function()
		ContentProvider:PreloadAsync({ icon, bolts[1].offImg, bolts[1].onImg })
	end)
	if not ok then
		warn("[LoadingScreen] Preload notice: " .. tostring(err))
	end
end)

-- Smooth wave charging animation: seamless crossfade across the 3 bolts
task.spawn(function()
	local step = 1
	while active and gui.Parent do
		for index, b in ipairs(bolts) do
			local isCurrent = (index == step)
			animateBoltTransition(b, isCurrent, 0.32)
		end
		step = (step % BOLT_COUNT) + 1
		task.wait(0.40)
	end
end)

-- Smooth tip rotation with clean fade
task.spawn(function()
	local tipIndex = 1
	while active and gui.Parent do
		task.wait(4.0)
		if not active or not gui.Parent then break end
		local fadeOut = TweenService:Create(tipText, TweenInfo.new(0.25), { TextTransparency = 1 })
		fadeOut:Play()
		fadeOut.Completed:Wait()
		if not active or not gui.Parent then break end
		tipIndex = (tipIndex % #TIPS) + 1
		tipText.Text = TIPS[tipIndex]
		local fadeIn = TweenService:Create(tipText, TweenInfo.new(0.25), { TextTransparency = 0 })
		fadeIn:Play()
	end
end)

task.delay(12, function()
	if active and status.Parent then
		status.Text = "FINALIZING CONNECTION"
	end
end)

-- Wait for Roblox loaded state
while not game:IsLoaded() do
	task.wait(0.1)
end
local characterDeadline = os.clock() + MAX_WAIT_FOR_CHARACTER
while not (player.Character and player.Character:FindFirstChild("HumanoidRootPart")) and os.clock() < characterDeadline do
	task.wait(0.1)
end

local remaining = MINIMUM_SHOW_TIME - (os.clock() - startedAt)
if remaining > 0 then
	task.wait(remaining)
end
active = false

-- POWERFUL FINALE:
-- All 3 bolts ignite into electric yellow in rapid succession, followed by a synchronized surge
status.Text = "READY TO RUN"
status.TextColor3 = COLOR_YELLOW

-- Sequential crossfade lock: 1 -> 2 -> 3 turn full electric yellow smoothly
for _, b in ipairs(bolts) do
	local snapInfo = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(b.scale, snapInfo, { Scale = 1.28 }):Play()
	TweenService:Create(b.onImg, snapInfo, {
		ImageTransparency = 0,
		ImageColor3 = COLOR_YELLOW_BRIGHT,
	}):Play()
	TweenService:Create(b.offImg, snapInfo, { ImageTransparency = 1.0 }):Play()
	task.wait(0.11)
end

-- Synchronized surge shockwave
local surgeInfo = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
for _, b in ipairs(bolts) do
	TweenService:Create(b.scale, surgeInfo, { Scale = 1.40 }):Play()
	TweenService:Create(b.onImg, surgeInfo, { ImageColor3 = COLOR_YELLOW }):Play()
end
task.wait(0.18)

local settleInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
for _, b in ipairs(bolts) do
	TweenService:Create(b.scale, settleInfo, { Scale = 1.15 }):Play()
end
task.wait(0.18)

-- Clean exit fade out to reveal the game
local fadeInfo = TweenInfo.new(FADE_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
for _, object in ipairs(gui:GetDescendants()) do
	local properties = {}
	if object:IsA("Frame") then
		properties.BackgroundTransparency = 1
	elseif object:IsA("ImageLabel") then
		properties.ImageTransparency = 1
	elseif object:IsA("TextLabel") then
		properties.TextTransparency = 1
	end
	if object:IsA("UIStroke") then
		properties.Transparency = 1
	end
	if next(properties) then
		TweenService:Create(object, fadeInfo, properties):Play()
	end
end
task.wait(FADE_SECONDS + 0.05)
gui:Destroy()
print("[LoadingScreen] Smooth dual-state vector bolts charged; game ready")
