local ReplicatedFirst = game:GetService("ReplicatedFirst")
                                                                         
ReplicatedFirst:RemoveDefaultLoadingScreen()

local Players = game:GetService("Players")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")

                                
local SPLASH_IMAGE_ID = "rbxassetid://138327240966588"
local STUD_TEXTURE_IMAGE = "rbxassetid://6927295847"
local STUD_TILE_SIZE = UDim2.fromOffset(100, 100)

local MINIMUM_SHOW_TIME = 3.0
local FULLY_LOADED_EXTRA_WAIT = 0.35

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local gui = Instance.new("ScreenGui")
gui.Name = "SpeedsterLoadingScreen"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 1000000
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local background = Instance.new("Frame")
background.Name = "Background"
background.BackgroundColor3 = Color3.fromRGB(0, 165, 255)
background.Size = UDim2.fromScale(1, 1)
background.BorderSizePixel = 0
background.ZIndex = 1
background.Parent = gui

local gradient = Instance.new("UIGradient")
gradient.Rotation = 90
gradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 70, 255)),
	ColorSequenceKeypoint.new(0.45, Color3.fromRGB(0, 180, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 240, 255)),
})
gradient.Parent = background

                                                                             
local splash = Instance.new("ImageLabel")
splash.Name = "SplashImage_EXACT_ASSET_138327240966588"
splash.BackgroundTransparency = 1
splash.AnchorPoint = Vector2.new(0.5, 0.5)
splash.Position = UDim2.fromScale(0.5, 0.5)
splash.Size = UDim2.fromScale(1, 1)
splash.ScaleType = Enum.ScaleType.Crop
splash.Image = SPLASH_IMAGE_ID
splash.ImageTransparency = 0
splash.ZIndex = 2
splash.Parent = background

local barBack = Instance.new("Frame")
barBack.Name = "LoadingBarBack"
barBack.AnchorPoint = Vector2.new(0.5, 0.5)
barBack.Position = UDim2.fromScale(0.5, 0.78)
barBack.Size = UDim2.fromScale(0.45, 0.055)
barBack.BackgroundColor3 = Color3.fromRGB(13, 16, 28)
barBack.BorderSizePixel = 0
barBack.ZIndex = 5
barBack.Parent = background

local barBackCorner = Instance.new("UICorner")
barBackCorner.CornerRadius = UDim.new(0, 12)
barBackCorner.Parent = barBack

local barStroke = Instance.new("UIStroke")
barStroke.Color = Color3.fromRGB(0, 0, 0)
barStroke.Thickness = 4
barStroke.LineJoinMode = Enum.LineJoinMode.Round
barStroke.Parent = barBack

local barClip = Instance.new("Frame")
barClip.Name = "LoadingBarClip"
barClip.BackgroundTransparency = 1
barClip.ClipsDescendants = true
barClip.Position = UDim2.fromOffset(5, 5)
barClip.Size = UDim2.new(1, -10, 1, -10)
barClip.ZIndex = 6
barClip.Parent = barBack

local barFill = Instance.new("Frame")
barFill.Name = "GoldenFill"
barFill.BackgroundColor3 = Color3.fromRGB(255, 210, 0)
barFill.BorderSizePixel = 0
barFill.Size = UDim2.fromScale(0, 1)
barFill.ZIndex = 7
barFill.Parent = barClip

local barFillCorner = Instance.new("UICorner")
barFillCorner.CornerRadius = UDim.new(0, 9)
barFillCorner.Parent = barFill

local barGradient = Instance.new("UIGradient")
barGradient.Rotation = 90
barGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 248, 70)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 208, 0)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 160, 0)),
})
barGradient.Parent = barFill

barFill.ClipsDescendants = true

local barStudSurface = Instance.new("ImageLabel")
barStudSurface.Name = "UIStudSurface"
barStudSurface.BackgroundColor3 = barFill.BackgroundColor3
barStudSurface.BackgroundTransparency = barFill.BackgroundTransparency
barStudSurface.BorderSizePixel = 0
barStudSurface.Position = UDim2.fromOffset(0, 0)
barStudSurface.Size = UDim2.fromScale(1, 1)
barStudSurface.Image = STUD_TEXTURE_IMAGE
barStudSurface.ImageColor3 = Color3.fromRGB(255, 255, 255)
barStudSurface.ImageTransparency = 0
barStudSurface.ScaleType = Enum.ScaleType.Tile
barStudSurface.TileSize = STUD_TILE_SIZE
barStudSurface.Active = false
barStudSurface.Selectable = false
barStudSurface.ZIndex = 8
barStudSurface.Parent = barFill

local barStudCorner = Instance.new("UICorner")
barStudCorner.CornerRadius = UDim.new(0, 9)
barStudCorner.Parent = barStudSurface

local barStudGradient = Instance.new("UIGradient")
barStudGradient.Name = "StudSurfaceGradient"
barStudGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
	ColorSequenceKeypoint.new(0.52, Color3.fromRGB(255, 255, 245)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 245, 220)),
})
barStudGradient.Rotation = -90
barStudGradient.Parent = barStudSurface

local percentText = Instance.new("TextLabel")
percentText.Name = "PercentText"
percentText.BackgroundTransparency = 1
percentText.Size = UDim2.fromScale(1, 1)
percentText.Font = Enum.Font.GothamBlack
percentText.Text = "0%"
percentText.TextColor3 = Color3.fromRGB(255, 255, 255)
percentText.TextScaled = true
percentText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
percentText.TextStrokeTransparency = 0
percentText.ZIndex = 9
percentText.Parent = barBack

local startedAt = os.clock()
local currentProgress = 0
local imagePreloadFinished = false

local function setProgress(value, tweenTime)
	value = math.clamp(value, 0, 1)
	currentProgress = math.max(currentProgress, value)
	percentText.Text = tostring(math.floor(currentProgress * 100 + 0.5)) .. "%"

	TweenService:Create(barFill, TweenInfo.new(tweenTime or 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromScale(currentProgress, 1),
	}):Play()
end

                                                                             
task.spawn(function()
	local ok, err = pcall(function()
		ContentProvider:PreloadAsync({ splash })
	end)

	imagePreloadFinished = true

	if ok then
		print("[LoadingScreen] Splash image preload finished: " .. SPLASH_IMAGE_ID)
	else
		warn("[LoadingScreen] Splash image preload failed. Check if the image is approved/public. ID: " .. SPLASH_IMAGE_ID .. " Error: " .. tostring(err))
	end
end)

                                                    
task.spawn(function()
	while gui.Parent and not game:IsLoaded() do
		setProgress(math.min(currentProgress + 0.025, 0.88), 0.12)
		task.wait(0.06)
	end
end)

                                      
pcall(function()
	local preloadList = {}
	for _, serviceName in ipairs({
		"ReplicatedStorage",
		"StarterGui",
		"StarterPlayer",
		"SoundService",
		"Workspace",
	}) do
		local service = game:FindService(serviceName)
		if service then
			table.insert(preloadList, service)
		end
	end
	ContentProvider:PreloadAsync(preloadList)
end)

if not game:IsLoaded() then
	game.Loaded:Wait()
end

local character = player.Character or player.CharacterAdded:Wait()
character:WaitForChild("Humanoid", 10)
character:WaitForChild("HumanoidRootPart", 10)

                                                                                            
local imageWaitStarted = os.clock()
while not imagePreloadFinished and os.clock() - imageWaitStarted < 5 do
	task.wait(0.05)
end

local elapsed = os.clock() - startedAt
if elapsed < MINIMUM_SHOW_TIME then
	task.wait(MINIMUM_SHOW_TIME - elapsed)
end

setProgress(1, 0.22)
task.wait(FULLY_LOADED_EXTRA_WAIT)

local fadeInfo = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

for _, obj in ipairs(gui:GetDescendants()) do
	if obj:IsA("Frame") then
		TweenService:Create(obj, fadeInfo, {
			BackgroundTransparency = 1,
		}):Play()
	elseif obj:IsA("ImageLabel") then
		TweenService:Create(obj, fadeInfo, {
			ImageTransparency = 1,
			BackgroundTransparency = 1,
		}):Play()
	elseif obj:IsA("TextLabel") then
		TweenService:Create(obj, fadeInfo, {
			TextTransparency = 1,
			TextStrokeTransparency = 1,
			BackgroundTransparency = 1,
		}):Play()
	elseif obj:IsA("UIStroke") then
		TweenService:Create(obj, fadeInfo, {
			Transparency = 1,
		}):Play()
	end
end

task.wait(0.5)
gui:Destroy()

print("[LoadingScreen] V93 finished. Exact splash image used: " .. SPLASH_IMAGE_ID)
