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
local paidPriceText = tostring(priceRobux)
local uiClickSound = SoundService:FindFirstChild("SpeedsterUiClickSound") or Instance.new("Sound")
uiClickSound.Name = "SpeedsterUiClickSound"
uiClickSound.SoundId = "rbxassetid://72264591133889"
uiClickSound.Volume = 0.65
uiClickSound.Parent = SoundService
local gui = playerGui:FindFirstChild("RevivePromptHUD")

gui.Name = "RevivePromptHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 90
gui.Parent = playerGui


local holder = gui.FindFirstChild()


holder.AnchorPoint = Vector2.new(0.5, 1)
holder.Position = UDim2.new(0.5, 0, 1, 140)
holder.Size = UDim2.fromOffset(370, 126)
holder.BackgroundTransparency = 1
holder.Visible = false
holder.Parent = gui
local responsiveScale = Instance.new("UIScale")
responsiveScale.Scale = 0.92
responsiveScale.Parent = holder

local function updateResponsiveScale()
	local currentCamera = Workspace.CurrentCamera
	local vp = currentCamera and currentCamera.ViewportSize or Vector2.new(1920, 1080)
	local isMobile = UserInputService.TouchEnabled or vp.Y <= 500
	if isMobile then
		responsiveScale.Scale = math.clamp(vp.Y / 720, 0.62, 0.85)
	else
		responsiveScale.Scale = 0.92
	end
end
updateResponsiveScale()
if Workspace.CurrentCamera then
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveScale)
end
local button = Instance.new("ImageButton")
button.Name = "ReviveButton"
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
border.Parent = button
StudUi.AddSurface(button, 3, 14, 9, 2)
local heart = Instance.new("ImageLabel")
heart.Name = "HeartIcon"
heart.BackgroundTransparency = 1
heart.AnchorPoint = Vector2.new(0, 0.5)
heart.Position = UDim2.new(0, 12, 0.5, 0)
heart.Size = UDim2.fromOffset(72, 72)
heart.Image = tostring(Config.ReviveIconImage or "rbxthumb://type=Asset&id=12492678216&w=420&h=420")
heart.ImageColor3 = Color3.fromRGB(255, 255, 255)
heart.ImageTransparency = 0.10
heart.ScaleType = Enum.ScaleType.Fit
heart.ZIndex = 3
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
title.ZIndex = 5
title.Parent = button
local titleStroke = Instance.new("UIStroke")
titleStroke.Thickness = 5
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
local pressScale = Instance.new("UIScale")
pressScale.Scale = 1
pressScale.Parent = button
local function onScreenPosition()
	local mainhud = playerGui:FindFirstChild("Mainhud")
	local lpb = mainhud and mainhud:FindFirstChild("LevelProgressBar")
	local frame = lpb and lpb:FindFirstChild("Frame")
	local speedLabel = frame and frame:FindFirstChild("Speed")

	if speedLabel and speedLabel:IsA("GuiObject") and speedLabel.AbsolutePosition.Y > 0 then
		return UDim2.new(0.5, 0, 0, speedLabel.AbsolutePosition.Y - 12)
	elseif frame and frame:IsA("GuiObject") and frame.AbsolutePosition.Y > 0 then
		return UDim2.new(0.5, 0, 0, frame.AbsolutePosition.Y - 36)
	elseif lpb and lpb:IsA("GuiObject") and lpb.AbsolutePosition.Y > 0 then
		return UDim2.new(0.5, 0, 0, lpb.AbsolutePosition.Y - 36)
	end

	return UDim2.new(0.5, 0, 0.74, -10)
end
local function offScreenPosition() return UDim2.new(0.5, 0, 1, 140) end
local function refreshPriceLabel()
	local free = player:GetAttribute("InfiniteRevivesOwned") == true
	price.Text = (offerToken and (offerIsFree or free)) and "FREE" or paidPriceText
end
local function hideOffer(serial)
	if serial and serial ~= offerSerial then return end
	offerToken = nil
	offerExpiresAt = 0
	offerIsFree = false
	promptBusy = false
	refreshPriceLabel()
	local tween = TweenService:Create(holder, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = offScreenPosition()})
	tween:Play()
	tween.Completed:Connect(function() if not offerToken then holder.Visible = false end end)
end
local function showOffer(payload)
	if player:GetAttribute("PromptRevivals") == false or player:GetAttribute("ReviveDisabled") == true then
		hideOffer()
		return
	end
	offerSerial += 1
	local serial = offerSerial
	offerToken = tostring(payload.Token or "")
	offerIsFree = payload.Free == true or player:GetAttribute("InfiniteRevivesOwned") == true
	local duration = math.max(1, tonumber(payload.Duration) or tonumber(Config.ReviveOfferSeconds) or 5)
	offerExpiresAt = os.clock() + duration
	promptBusy = false
	refreshPriceLabel()
	button.Active = true
	holder.Position = offScreenPosition()
	holder.Visible = offerToken ~= ""
	if not holder.Visible then return end
	print(string.format("[RevivePrompt] showOffer: duration=%d, free=%s, token=%s", duration, tostring(offerIsFree), offerToken))
	TweenService:Create(holder, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = onScreenPosition()}):Play()
	task.spawn(function()
		while serial == offerSerial and holder.Visible and os.clock() < offerExpiresAt do
			countdown.Text = tostring(math.max(1, math.ceil(offerExpiresAt - os.clock())))
			task.wait(0.05)
		end
		if serial == offerSerial and offerToken then hideOffer(serial) end
	end)
end
button.Activated:Connect(function()
	if promptBusy or not offerToken or os.clock() >= offerExpiresAt then return end
	uiClickSound.TimePosition = 0
	uiClickSound:Play()
	print("[RevivePrompt] Revive button clicked by " .. player.Name .. " | Token=" .. tostring(offerToken))
	promptBusy = true
	button.Active = false
	TweenService:Create(pressScale, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 0.94}):Play()
	task.delay(0.07, function() if pressScale.Parent then TweenService:Create(pressScale, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play() end end)
	ReviveCommerce:FireServer("RequestPrompt", offerToken)
end)
ReviveCommerce.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then return end
	print("[RevivePrompt] OnClientEvent received: " .. tostring(payload.Type))
	if payload.Type == "Offer" then showOffer(payload)
	elseif payload.Type == "Prompt" then
		if tostring(payload.Token or "") ~= tostring(offerToken or "") then return end
		local pid = tonumber(payload.ProductId) or productId
		print("[RevivePrompt] Prompting Developer Product purchase: " .. tostring(pid))
		local ok, err = pcall(function() MarketplaceService:PromptProductPurchase(player, pid) end)
		if not ok then warn("[RevivePrompt] Could not open purchase prompt: " .. tostring(err)); promptBusy = false; button.Active = true end
	elseif payload.Type == "Expired" and tostring(payload.Token or "") == tostring(offerToken or "") then
		print("[RevivePrompt] Offer expired")
		hideOffer(offerSerial)
	elseif payload.Type == "Granted" then
		print("[RevivePrompt] Revive granted!")
		hideOffer(offerSerial)
	elseif payload.Type == "ReviveTeleport" then
		print("[RevivePrompt] ReviveTeleport received | Stage=" .. tostring(payload.Stage))
		local targetCFrame = payload.TargetCFrame
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp and typeof(targetCFrame) == "CFrame" then
			hrp.CFrame = targetCFrame
		end
		hideOffer(offerSerial)
	elseif payload.Type == "Retry" then
		print("[RevivePrompt] Revive retry requested")
		promptBusy = false
		button.Active = true
	end
end)
player:GetAttributeChangedSignal("InfiniteRevivesOwned"):Connect(function() if player:GetAttribute("InfiniteRevivesOwned") == true then offerIsFree = true end refreshPriceLabel() end)
player:GetAttributeChangedSignal("PromptRevivals"):Connect(function() if player:GetAttribute("PromptRevivals") == false then hideOffer() end end)
local function updateResponsiveLayout()
	local camera = Workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
	local fit = math.min(viewport.X / 1920, viewport.Y / 1080)
	responsiveScale.Scale = UserInputService.TouchEnabled and math.clamp(fit * 1.25, 0.48, 0.78) or math.clamp(viewport.X / 1920, 0.65, 0.92)
end
updateResponsiveLayout()
if Workspace.CurrentCamera then Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveLayout) end