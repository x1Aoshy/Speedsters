         
                                                                             
                                                                        
                                                                      

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local ContentProvider = game:GetService("ContentProvider")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local StarterPackClaim = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("StarterPackClaim")

local passId = tonumber(Config.StarterPackGamePassId) or 0
local visibleSeconds = math.max(1, tonumber(Config.StarterPackVisibleSeconds) or 17 * 60)
local expiresAt = os.clock() + visibleSeconds
local promptBusy = false
local dismissedThisSession = false

local UI_CLICK_SOUND_ID = "rbxassetid://72264591133889"
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

local old = playerGui:FindFirstChild("StarterPackOfferHUD")
if old then
	old:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "StarterPackOfferHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 70
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local holder = Instance.new("Frame")
holder.Name = "StarterPackOfferHolder"
holder.AnchorPoint = Vector2.new(1, 0)
holder.Position = UDim2.new(1, -28, 0, 64)
holder.Size = UDim2.fromOffset(190, 202)
holder.BackgroundTransparency = 1
holder.BorderSizePixel = 0
holder.ClipsDescendants = false
holder.Visible = false
holder.Parent = gui

local responsiveScale = Instance.new("UIScale")
responsiveScale.Name = "ResponsiveScale"
responsiveScale.Scale = 0.90
responsiveScale.Parent = holder

local button = Instance.new("ImageButton")
button.Name = "StarterPackButton"
button.Size = UDim2.fromScale(1, 1)
button.BackgroundTransparency = 1
button.BorderSizePixel = 0
button.AutoButtonColor = false
button.ZIndex = 1
button.Parent = holder

local pressScale = Instance.new("UIScale")
pressScale.Name = "PressScale"
pressScale.Scale = 1
pressScale.Parent = button

local timer = Instance.new("TextLabel")
timer.Name = "Timer"
timer.AnchorPoint = Vector2.new(0.5, 0)
timer.Position = UDim2.new(0.5, 0, 0, 0)
timer.Size = UDim2.fromOffset(118, 43)
timer.BackgroundTransparency = 1
timer.Font = Enum.Font.FredokaOne
timer.Text = "17:00"
timer.TextColor3 = Color3.fromRGB(255, 237, 35)
timer.TextScaled = true
timer.TextXAlignment = Enum.TextXAlignment.Center
timer.ZIndex = 6
timer.Parent = button

local timerConstraint = Instance.new("UITextSizeConstraint")
timerConstraint.MinTextSize = UserInputService.TouchEnabled and 9 or 25
timerConstraint.MaxTextSize = UserInputService.TouchEnabled and 18 or 39
timerConstraint.Parent = timer

local timerStroke = Instance.new("UIStroke")
timerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
timerStroke.Color = Color3.fromRGB(0, 0, 0)
timerStroke.Thickness = 4
timerStroke.LineJoinMode = Enum.LineJoinMode.Round
timerStroke.Parent = timer

local icon = Instance.new("ImageLabel")
icon.Name = "StarterPackIcon"
icon.AnchorPoint = Vector2.new(0.5, 0)
icon.Position = UDim2.new(0.56, 0, 0, 40)
icon.Size = UserInputService.TouchEnabled and UDim2.fromOffset(96, 96) or UDim2.fromOffset(122, 122)
icon.BackgroundTransparency = 1
icon.Image = tostring(Config.StarterPackIconImage or "rbxthumb://type=Asset&id=120522986837915&w=420&h=420")
icon.ScaleType = Enum.ScaleType.Fit
icon.ZIndex = 3
icon.Parent = button

local priceRow = Instance.new("Frame")
priceRow.Name = "RobuxPriceRow"
priceRow.Position = UDim2.fromOffset(0, 59)
priceRow.Size = UDim2.fromOffset(89, 45)
priceRow.BackgroundTransparency = 1
priceRow.ZIndex = 7
priceRow.Parent = button

local robuxIcon = Instance.new("ImageLabel")
robuxIcon.Name = "RobuxIcon"
robuxIcon.AnchorPoint = Vector2.new(0, 0.5)
robuxIcon.Position = UDim2.new(0, 0, 0.5, 0)
robuxIcon.Size = UserInputService.TouchEnabled and UDim2.fromOffset(31, 31) or UDim2.fromOffset(42, 42)
robuxIcon.BackgroundTransparency = 1
robuxIcon.Image = "rbxasset://textures/ui/common/robux.png"
robuxIcon.ImageColor3 = Color3.fromRGB(123, 255, 50)
robuxIcon.ScaleType = Enum.ScaleType.Fit
robuxIcon.ZIndex = 8
robuxIcon.Parent = priceRow

local price = Instance.new("TextLabel")
price.Name = "Price"
price.Position = UDim2.fromOffset(37, 0)
price.Size = UDim2.fromOffset(52, 45)
price.BackgroundTransparency = 1
price.Font = Enum.Font.FredokaOne
price.Text = tostring(tonumber(Config.StarterPackPriceRobux) or 7)
price.TextColor3 = Color3.fromRGB(255, 255, 255)
price.TextScaled = true
price.TextXAlignment = Enum.TextXAlignment.Left
price.ZIndex = 8
price.Parent = priceRow

local priceConstraint = Instance.new("UITextSizeConstraint")
priceConstraint.MinTextSize = UserInputService.TouchEnabled and 9 or 26
priceConstraint.MaxTextSize = UserInputService.TouchEnabled and 18 or 41
priceConstraint.Parent = price

local priceStroke = Instance.new("UIStroke")
priceStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
priceStroke.Color = Color3.fromRGB(0, 0, 0)
priceStroke.Thickness = 4
priceStroke.LineJoinMode = Enum.LineJoinMode.Round
priceStroke.Parent = price

local title = Instance.new("TextLabel")
title.Name = "Title"
title.AnchorPoint = Vector2.new(0.5, 0)
title.Position = UDim2.new(0.5, 0, 0, 157)
title.Size = UDim2.fromOffset(190, 43)
title.BackgroundTransparency = 1
title.Font = Enum.Font.FredokaOne
title.Text = "Starter Pack"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextScaled = true
title.TextXAlignment = Enum.TextXAlignment.Center
title.ZIndex = 6
title.Parent = button

local titleConstraint = Instance.new("UITextSizeConstraint")
titleConstraint.MinTextSize = UserInputService.TouchEnabled and 8 or 24
titleConstraint.MaxTextSize = UserInputService.TouchEnabled and 17 or 39
titleConstraint.Parent = title

local titleStroke = Instance.new("UIStroke")
titleStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
titleStroke.Color = Color3.fromRGB(0, 0, 0)
titleStroke.Thickness = 4
titleStroke.LineJoinMode = Enum.LineJoinMode.Round
titleStroke.Parent = title

task.spawn(function()
	pcall(function()
		ContentProvider:PreloadAsync({icon, robuxIcon})
	end)
end)

local function formatTime(seconds)
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

local function isEligible()
	                                                                            
	                                                                             
	return os.clock() < expiresAt and not dismissedThisSession
end

local function refreshVisibility()
	holder.Visible = isEligible()
end

local function updateResponsiveLayout()
	local camera = Workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
	local fit = math.min(viewport.X / 1920, viewport.Y / 1080)
	local isPhone = UserInputService.TouchEnabled and math.min(viewport.X, viewport.Y) < 600
	if UserInputService.TouchEnabled then
		responsiveScale.Scale = math.clamp(fit * 0.94, 0.36, 0.82)
		holder.Position = UDim2.new(1, -8, 0, isPhone and 28 or 50)
		title.Position = UDim2.new(0.5, 0, 0, isPhone and 140 or 157)
	else
		responsiveScale.Scale = math.clamp(viewport.X / 1920, 0.66, 0.90)
		holder.Position = UDim2.new(1, -28, 0, 64)
		title.Position = UDim2.new(0.5, 0, 0, 157)
	end
end

button.Activated:Connect(function()
	if promptBusy or not isEligible() or passId <= 0 then
		return
	end
	playUiClickSound()
	promptBusy = true
	TweenService:Create(pressScale, TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Scale = 0.92,
	}):Play()
	task.delay(0.08, function()
		if pressScale.Parent then
			TweenService:Create(pressScale, TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Scale = 1,
			}):Play()
		end
	end)

	local ok, err = pcall(function()
		MarketplaceService:PromptGamePassPurchase(player, passId)
	end)
	if not ok then
		warn("[StarterPackOffer] Could not open Game Pass prompt: " .. tostring(err))
	end
	task.delay(0.8, function()
		promptBusy = false
	end)
end)

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(purchasedPlayer, purchasedPassId, purchaseSuccess)
	if purchasedPlayer == player
		and tonumber(purchasedPassId) == passId
		and purchaseSuccess == true
	then
		dismissedThisSession = true
		refreshVisibility()

		                                                                    
		                                                                             
		task.spawn(function()
			for attempt = 1, 6 do
				if not gui.Parent then
					return
				end
				StarterPackClaim:FireServer()
				if attempt < 6 then
					task.wait(attempt)
				end
			end
		end)
	end
end)

task.spawn(function()
	if passId <= 0 then
		return
	end
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(passId, Enum.InfoType.GamePass)
	end)
	if ok and type(info) == "table" and tonumber(info.PriceInRobux) then
		price.Text = tostring(math.floor(info.PriceInRobux))
	end
end)

task.spawn(function()
	while gui.Parent and os.clock() < expiresAt do
		timer.Text = formatTime(expiresAt - os.clock())
		refreshVisibility()
		task.wait(0.2)
	end
	holder.Visible = false
end)

updateResponsiveLayout()
if Workspace.CurrentCamera then
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveLayout)
end
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	updateResponsiveLayout()
	if Workspace.CurrentCamera then
		Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveLayout)
	end
end)

print("[StarterPackOffer] V306EJ loaded with verified Starter Pack claim retries.")
