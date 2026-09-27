         
                                                                               
                                                      

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local StudUi = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("StudUi"))
local ReviveCommerce = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ReviveCommerce")

local productId = tonumber(Config.ReviveProductId) or 0
local priceRobux = tonumber(Config.RevivePriceRobux) or 7
local offerToken = nil
local offerExpiresAt = 0
local offerSerial = 0
local promptBusy = false
local offerIsFree = false
local paidPriceText = "R$ " .. tostring(priceRobux)

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

local old = playerGui:FindFirstChild("RevivePromptHUD")
if old then
	old:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "RevivePromptHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 90
gui.Parent = playerGui

local holder = Instance.new("Frame")
holder.Name = "ReviveOfferHolder"
holder.AnchorPoint = Vector2.new(0.5, 1)
holder.Position = UDim2.new(0.5, 0, 1, 140)
holder.Size = UDim2.fromOffset(370, 126)
holder.BackgroundTransparency = 1
holder.Visible = false
holder.Parent = gui

local responsiveScale = Instance.new("UIScale")
responsiveScale.Scale = 0.92
responsiveScale.Parent = holder

local button = Instance.new("ImageButton")
button.Name = "ReviveButton"
button.Position = UDim2.fromOffset(0, 0)
button.Size = UDim2.fromOffset(370, 94)
button.BackgroundColor3 = Color3.fromRGB(102, 255, 38)
button.BorderSizePixel = 0
button.AutoButtonColor = false
button.ZIndex = 2
button.Parent = holder

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 14)
corner.Parent = button

local border = Instance.new("UIStroke")
border.Color = Color3.fromRGB(0, 0, 0)
border.Thickness = 4
border.LineJoinMode = Enum.LineJoinMode.Round
border.Parent = button

StudUi.AddSurface(button, 3, 14, 9, 2)

local heart = Instance.new("ImageLabel")
heart.Name = "HeartIcon"
heart.BackgroundTransparency = 1
heart.AnchorPoint = Vector2.new(0, 0.5)
heart.Position = UDim2.new(0, 13, 0.5, 1)
heart.Size = UDim2.fromOffset(78, 78)
heart.Image = tostring(Config.ReviveIconImage or "rbxthumb://type=Asset&id=12492678216&w=420&h=420")
heart.ScaleType = Enum.ScaleType.Fit
heart.ZIndex = 5
heart.Parent = button

local title = Instance.new("TextLabel")
title.Name = "ReviveText"
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(91, 8)
title.Size = UDim2.fromOffset(261, 78)
title.Font = Enum.Font.FredokaOne
title.Text = "Revive"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextScaled = true
title.TextXAlignment = Enum.TextXAlignment.Center
title.TextYAlignment = Enum.TextYAlignment.Center
title.ZIndex = 5
title.Parent = button

local titleConstraint = Instance.new("UITextSizeConstraint")
titleConstraint.MinTextSize = 34
titleConstraint.MaxTextSize = 68
titleConstraint.Parent = title

local titleStroke = Instance.new("UIStroke")
titleStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
titleStroke.Color = Color3.fromRGB(0, 0, 0)
titleStroke.Thickness = 5
titleStroke.LineJoinMode = Enum.LineJoinMode.Round
titleStroke.Parent = title

local price = Instance.new("TextLabel")
price.Name = "Price"
price.BackgroundTransparency = 1
price.Position = UDim2.fromOffset(-8, -22)
price.Size = UDim2.fromOffset(116, 48)
price.Rotation = -8
price.Font = Enum.Font.FredokaOne
price.Text = paidPriceText
price.TextColor3 = Color3.fromRGB(255, 255, 255)
price.TextScaled = true
price.ZIndex = 7
price.Parent = holder

local priceStroke = Instance.new("UIStroke")
priceStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
priceStroke.Color = Color3.fromRGB(0, 0, 0)
priceStroke.Thickness = 4
priceStroke.Parent = price

local countdown = Instance.new("TextLabel")
countdown.Name = "Countdown"
countdown.BackgroundTransparency = 1
countdown.AnchorPoint = Vector2.new(0.5, 0)
countdown.Position = UDim2.new(0.5, 0, 0, 90)
countdown.Size = UDim2.fromOffset(90, 36)
countdown.Font = Enum.Font.FredokaOne
countdown.Text = "5"
countdown.TextColor3 = Color3.fromRGB(255, 232, 38)
countdown.TextScaled = true
countdown.ZIndex = 6
countdown.Parent = holder

local countdownStroke = Instance.new("UIStroke")
countdownStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
countdownStroke.Color = Color3.fromRGB(0, 0, 0)
countdownStroke.Thickness = 3
countdownStroke.Parent = countdown

local pressScale = Instance.new("UIScale")
pressScale.Scale = 1
pressScale.Parent = button

local function onScreenPosition()
	                                                                          
	                                            
	return UDim2.new(0.5, 0, 1, -175)
end

local function offScreenPosition()
	return UDim2.new(0.5, 0, 1, 140)
end

local function refreshPriceLabel()
	local hasFreeRevives = player:GetAttribute("InfiniteRevivesOwned") == true
	price.Text = (offerToken and (offerIsFree or hasFreeRevives)) and "FREE" or paidPriceText
end

local function hideOffer(serial)
	if serial and serial ~= offerSerial then
		return
	end
	offerToken = nil
	offerExpiresAt = 0
	offerIsFree = false
	promptBusy = false
	refreshPriceLabel()
	local tween = TweenService:Create(
		holder,
		TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{Position = offScreenPosition()}
	)
	tween:Play()
	tween.Completed:Connect(function()
		if not offerToken then
			holder.Visible = false
		end
	end)
end

local function showOffer(payload)
	offerSerial += 1
	local serial = offerSerial
	offerToken = tostring(payload.Token or "")
	offerIsFree = payload.Free == true or player:GetAttribute("InfiniteRevivesOwned") == true
	local duration = math.max(1, tonumber(payload.Duration) or tonumber(Config.ReviveOfferSeconds) or 5)
	offerExpiresAt = os.clock() + duration
	promptBusy = false
	title.Text = "Revive"
	refreshPriceLabel()
	button.Active = true
	holder.Position = offScreenPosition()
	holder.Visible = offerToken ~= ""
	if not holder.Visible then
		return
	end

	TweenService:Create(
		holder,
		TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{Position = onScreenPosition()}
	):Play()

	task.spawn(function()
		while serial == offerSerial and holder.Visible and os.clock() < offerExpiresAt do
			countdown.Text = tostring(math.max(1, math.ceil(offerExpiresAt - os.clock())))
			task.wait(0.05)
		end
		if serial == offerSerial and offerToken then
			hideOffer(serial)
		end
	end)
end

button.Activated:Connect(function()
	if promptBusy or not offerToken or os.clock() >= offerExpiresAt then
		return
	end
	playUiClickSound()
	promptBusy = true
	button.Active = false
	TweenService:Create(pressScale, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Scale = 0.94,
	}):Play()
	task.delay(0.07, function()
		if pressScale.Parent then
			TweenService:Create(pressScale, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Scale = 1,
			}):Play()
		end
	end)
	ReviveCommerce:FireServer("RequestPrompt", offerToken)
end)

ReviveCommerce.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then
		return
	end

	if payload.Type == "Offer" then
		showOffer(payload)
	elseif payload.Type == "Prompt" then
		if tostring(payload.Token or "") ~= tostring(offerToken or "") then
			return
		end
		local requestedProductId = tonumber(payload.ProductId) or productId
		local ok, err = pcall(function()
			MarketplaceService:PromptProductPurchase(player, requestedProductId)
		end)
		if not ok then
			warn("[RevivePrompt] Could not open purchase prompt: " .. tostring(err))
			promptBusy = false
			button.Active = true
		end
	elseif payload.Type == "Expired" then
		if tostring(payload.Token or "") == tostring(offerToken or "") then
			hideOffer(offerSerial)
		end
	elseif payload.Type == "Granted" then
		hideOffer(offerSerial)
	elseif payload.Type == "Retry" then
		promptBusy = false
		button.Active = true
	end
end)

player:GetAttributeChangedSignal("InfiniteRevivesOwned"):Connect(function()
	if player:GetAttribute("InfiniteRevivesOwned") == true then
		offerIsFree = true
	end
	refreshPriceLabel()
end)

local function updateResponsiveLayout()
	local camera = Workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
	local fit = math.min(viewport.X / 1920, viewport.Y / 1080)
	if UserInputService.TouchEnabled then
		responsiveScale.Scale = math.clamp(fit * 1.25, 0.48, 0.78)
	else
		responsiveScale.Scale = math.clamp(viewport.X / 1920, 0.65, 0.92)
	end
end

task.spawn(function()
	if productId <= 0 then
		return
	end
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(productId, Enum.InfoType.Product)
	end)
	if ok and type(info) == "table" and tonumber(info.PriceInRobux) then
		paidPriceText = "R$ " .. tostring(math.floor(info.PriceInRobux))
		refreshPriceLabel()
	end
end)

updateResponsiveLayout()
if Workspace.CurrentCamera then
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveLayout)
end
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(updateResponsiveLayout)

print("[RevivePrompt] V306DS loaded higher on screen with paid/free Infinite Revives display support.")
