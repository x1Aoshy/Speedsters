         
                                                                               
                                                                   
                                             
                                                                
                                                                       

local Players = game:GetService("Players")
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local WalkSpeedModeRequest = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("WalkSpeedModeRequest")

local UI_CLICK_SOUND_ID = "rbxassetid://72264591133889"

                                                  
local MODE_IMAGES = {
	Green = "rbxassetid://124021406267245",
	Yellow = "rbxassetid://135452730598314",
	Red = "rbxassetid://120853685040395",
}

                                                                              
                                                                              
                                                                             
                                                                                
local function preloadModeImages()
	local preloadObjects = {}

	for _, imageId in pairs(MODE_IMAGES) do
		local image = Instance.new("ImageLabel")
		image.BackgroundTransparency = 1
		image.Image = imageId
		table.insert(preloadObjects, image)
	end

	local ok, err = pcall(function()
		ContentProvider:PreloadAsync(preloadObjects)
	end)

	for _, image in ipairs(preloadObjects) do
		image:Destroy()
	end

	if not ok then
		warn("[WalkSpeedSelector] Image preload failed; selector will still function:", err)
	end
end

preloadModeImages()

local MODE_COLORS = {
	Green = Color3.fromRGB(80, 255, 70),
	Yellow = Color3.fromRGB(255, 220, 35),
	Red = Color3.fromRGB(255, 70, 55),
}

local NEXT_MODE = {
	Red = "Green",
	Green = "Yellow",
	Yellow = "Red",
}

local function getModeMultiplier(mode)
	local multipliers = Config.WalkSpeedSelectorMultipliers or {}
	return tonumber(multipliers[mode]) or 1
end

local currentMode = Config.WalkSpeedSelectorDefaultMode or "Red"
if MODE_IMAGES[tostring(player:GetAttribute("WalkSpeedMode") or "")] then
	currentMode = tostring(player:GetAttribute("WalkSpeedMode"))
end

local old = playerGui:FindFirstChild("WalkSpeedSelectorHUD")
if old then
	old:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "WalkSpeedSelectorHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 47
gui.Parent = playerGui

local holder = Instance.new("Frame")
holder.Name = "SelectorHolder"
holder.AnchorPoint = Vector2.new(1, 0)
holder.Position = UDim2.new(1, -22, 0, 247)
holder.Size = UDim2.fromOffset(210, 214)
holder.BackgroundTransparency = 1
holder.Parent = gui

local responsiveScale = Instance.new("UIScale")
responsiveScale.Name = "ResponsiveScale"
responsiveScale.Scale = 1
responsiveScale.Parent = holder

local buttonScale = Instance.new("UIScale")
buttonScale.Name = "PressScale"
buttonScale.Scale = 1

local button = Instance.new("ImageButton")
button.Name = "WalkSpeedModeButton"
button.AnchorPoint = Vector2.new(0.5, 0.5)
button.Position = UDim2.fromOffset(105, 88)
button.Size = UDim2.fromOffset(192, 192)
button.BackgroundTransparency = 1
button.BorderSizePixel = 0
button.AutoButtonColor = false
button.Image = MODE_IMAGES[currentMode]
button.ScaleType = Enum.ScaleType.Fit
button.ZIndex = 2
button.Parent = holder
buttonScale.Parent = button

local valueLabel = Instance.new("TextLabel")
valueLabel.Name = "RealWalkSpeedValue"
valueLabel.AnchorPoint = Vector2.new(0.5, 0.5)
valueLabel.Position = UDim2.fromOffset(105, 122.6)
valueLabel.Size = UDim2.fromOffset(204, 30)
valueLabel.BackgroundTransparency = 1
valueLabel.BorderSizePixel = 0
valueLabel.Font = Enum.Font.FredokaOne
valueLabel.Text = "..."
valueLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
valueLabel.TextScaled = true
valueLabel.TextXAlignment = Enum.TextXAlignment.Center
valueLabel.TextYAlignment = Enum.TextYAlignment.Center
valueLabel.ZIndex = 5
valueLabel.Parent = holder

local textSizeConstraint = Instance.new("UITextSizeConstraint")
textSizeConstraint.MinTextSize = UserInputService.TouchEnabled and 7 or 16
textSizeConstraint.MaxTextSize = UserInputService.TouchEnabled and 14 or 30
textSizeConstraint.Parent = valueLabel

local labelStroke = Instance.new("UIStroke")
labelStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
labelStroke.Color = Color3.fromRGB(0, 0, 0)
labelStroke.Thickness = 4
labelStroke.LineJoinMode = Enum.LineJoinMode.Round
labelStroke.Parent = valueLabel

local function formatIntegerWithCommas(value)
	value = math.max(0, math.floor((tonumber(value) or 0) + 0.5))
	local text = tostring(value)
	while true do
		local nextText, count = text:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		text = nextText
		if count == 0 then
			break
		end
	end
	return text
end

local function getDisplayedSelectedSpeed()
	local maxWalkSpeed = tonumber(player:GetAttribute("RealWalkSpeedMax"))
	local selectedWalkSpeed = tonumber(player:GetAttribute("RealWalkSpeedSelected"))
	local serverMode = tostring(player:GetAttribute("WalkSpeedMode") or "")

	                                                                              
	                                                                          
	if maxWalkSpeed then
		return maxWalkSpeed * getModeMultiplier(currentMode)
	end

	if selectedWalkSpeed and serverMode == currentMode then
		return selectedWalkSpeed
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		if currentMode == "Red" then
			return humanoid.WalkSpeed
		end
	end

	return nil
end

local function refreshVisuals()
	button.Image = MODE_IMAGES[currentMode] or MODE_IMAGES.Red
	valueLabel.TextColor3 = Color3.fromRGB(255, 255, 255)

	local selected = getDisplayedSelectedSpeed()
	if selected then
		local text = formatIntegerWithCommas(selected)
		if currentMode == "Red" then
			text ..= " (Max)"
		end
		valueLabel.Text = text
	else
		valueLabel.Text = currentMode == "Red" and "(Max)" or "..."
	end
end

local uiClickSound = SoundService:FindFirstChild("SpeedsterUiClickSound")
if not uiClickSound then
	uiClickSound = Instance.new("Sound")
	uiClickSound.Name = "SpeedsterUiClickSound"
	uiClickSound.Parent = SoundService
end
uiClickSound.SoundId = UI_CLICK_SOUND_ID
uiClickSound.Volume = 0.65
uiClickSound.PlaybackSpeed = 1

local function playUiClickSound()
	uiClickSound.TimePosition = 0
	uiClickSound:Play()
end

local function pressAnimation()
	TweenService:Create(buttonScale, TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Scale = 0.92,
	}):Play()

	task.delay(0.08, function()
		if buttonScale.Parent then
			TweenService:Create(buttonScale, TweenInfo.new(0.10, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Scale = 1,
			}):Play()
		end
	end)
end

button.Activated:Connect(function()
	playUiClickSound()
	pressAnimation()

	currentMode = NEXT_MODE[currentMode] or "Red"
	refreshVisuals()
	WalkSpeedModeRequest:FireServer(currentMode)
end)

player:GetAttributeChangedSignal("WalkSpeedMode"):Connect(function()
	local mode = tostring(player:GetAttribute("WalkSpeedMode") or "")
	if MODE_IMAGES[mode] then
		currentMode = mode
		refreshVisuals()
	end
end)

player:GetAttributeChangedSignal("RealWalkSpeedMax"):Connect(refreshVisuals)
player:GetAttributeChangedSignal("RealWalkSpeedSelected"):Connect(refreshVisuals)

local function updateResponsiveScale()
	local camera = Workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
	local fit = math.min(viewport.X / 1280, viewport.Y / 720)
	local isPhone = UserInputService.TouchEnabled and math.min(viewport.X, viewport.Y) < 600

	if UserInputService.TouchEnabled then
		                                                                           
		                                                                            
		local mobileFit = math.min(viewport.X / 1920, viewport.Y / 1080)
		local starterPackScale = math.clamp(mobileFit * 0.94, 0.36, 0.82)
		local renderedStarterPackHeight = 202 * starterPackScale
		                                                                    
		                                                         
		responsiveScale.Scale = math.clamp((190 * starterPackScale / 210) * 1.10, 0.30, 0.62)
		local starterPackTop = isPhone and 28 or 50
		holder.Position = UDim2.new(1, -8, 0, starterPackTop + renderedStarterPackHeight - 10)
	else
		local legacyScale = math.clamp(fit, 0.78, 1.08)
		local rightButtonScale = math.clamp(viewport.X / 1920, 0.58, 0.82)
		local renderedRightButtonHeight = 88 * rightButtonScale
		local speedButtonCenterY = viewport.Y * 0.58 - (renderedRightButtonHeight + 7)
		local speedButtonTopY = speedButtonCenterY - renderedRightButtonHeight * 0.5
		local legacySpeedometerBottomY = 247 + 184 * legacyScale
		local clearance = 8

		if legacySpeedometerBottomY + clearance > speedButtonTopY then
			                                                                         
			                                                                      
			                                                                       
			local starterPackScale = math.clamp(viewport.X / 1920, 0.66, 0.90)
			local starterPackBottomY = 64 + 202 * starterPackScale
			local availableGaugeHeight = math.max(1, speedButtonTopY - starterPackBottomY - clearance * 2)
			local compactScale = math.clamp(availableGaugeHeight / 192, 0.25, legacyScale)
			local gaugeTopY = starterPackBottomY + clearance

			responsiveScale.Scale = compactScale
			holder.Position = UDim2.new(1, -22, 0, gaugeTopY + 8 * compactScale)
		else
			responsiveScale.Scale = legacyScale
			holder.Position = UDim2.new(1, -22, 0, 247)
		end
	end
end

updateResponsiveScale()
refreshVisuals()

if Workspace.CurrentCamera then
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveScale)
end

Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	updateResponsiveScale()
	if Workspace.CurrentCamera then
		Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveScale)
	end
end)

print("[WalkSpeedSelector] V306KAH loaded. Phone lift preserved; compact desktops fit the speedometer between Starter Pack and x2 Speed.")
