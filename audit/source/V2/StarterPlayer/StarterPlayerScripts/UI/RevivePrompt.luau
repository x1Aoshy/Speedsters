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

----------------------------------------------------------------------
-- 1) Bind to designer-made RevivePromptHUD in StarterGui / PlayerGui
----------------------------------------------------------------------
local gui = playerGui:WaitForChild("RevivePromptHUD", 4)
local createdFallback = false

if not gui then
	gui = Instance.new("ScreenGui")
	gui.Name = "RevivePromptHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 90
	gui.Parent = playerGui
	createdFallback = true
end

local function findChild(parent, names, className)
	if not parent then return nil end
	for _, name in ipairs(names) do
		local child = parent:FindFirstChild(name, true)
		if child and (not className or child:IsA(className)) then
			return child
		end
	end
	if className then
		return parent:FindFirstChildWhichIsA(className, true)
	end
	return nil
end

-- Find or construct the offer holder frame
local holder = findChild(gui, { "ReviveOfferHolder", "Holder", "ReviveFrame", "Frame", "Panel" }, "Frame")
if not holder then
	holder = Instance.new("Frame")
	holder.Name = "ReviveOfferHolder"
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.new(0.5, 0, 0.80, 0)
	holder.Size = UDim2.fromOffset(260, 68)
	holder.BackgroundTransparency = 1
	holder.Visible = false
	holder.Parent = gui
	createdFallback = true
end

-- Find or construct ReviveButton
local button = findChild(holder, { "ReviveButton", "Button", "Buy", "Revive" }, "GuiButton")
if not button then
	local btn = Instance.new("ImageButton")
	btn.Name = "ReviveButton"
	btn.Size = UDim2.fromScale(1, 1)
	btn.BackgroundColor3 = Color3.fromRGB(72, 218, 56)
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = true
	btn.ZIndex = 2
	btn.Parent = holder

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = btn

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.Thickness = 3
	stroke.Parent = btn

	button = btn
	createdFallback = true
end

-- Find or construct HeartIcon
local heart = findChild(button, { "HeartIcon", "Heart", "Icon" }, "ImageLabel")
if not heart and createdFallback then
	heart = Instance.new("ImageLabel")
	heart.Name = "HeartIcon"
	heart.AnchorPoint = Vector2.new(0, 0.5)
	heart.Position = UDim2.new(0, 14, 0.5, 0)
	heart.Size = UDim2.fromOffset(40, 40)
	heart.BackgroundTransparency = 1
	heart.Image = tostring(Config.ReviveIconImage or "rbxthumb://type=Asset&id=12492678216&w=420&h=420")
	heart.ImageColor3 = Color3.fromRGB(255, 255, 255)
	heart.ScaleType = Enum.ScaleType.Fit
	heart.ZIndex = 3
	heart.Parent = button
end

-- Find or construct ReviveText title
local title = findChild(button, { "ReviveText", "Title", "Text", "Name" }, "TextLabel")
if not title and createdFallback then
	title = Instance.new("TextLabel")
	title.Name = "ReviveText"
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.Position = UDim2.new(0.55, 0, 0.5, 0)
	title.Size = UDim2.new(0.65, 0, 0.65, 0)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.Text = "Revive"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextScaled = true
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.ZIndex = 4
	title.Parent = button

	local titleStroke = Instance.new("UIStroke")
	titleStroke.Thickness = 3
	titleStroke.Parent = title
end

-- Find or construct Price label
local price = findChild(holder, { "Price", "PriceLabel", "RobuxLabel", "Robux" }, "TextLabel")
if not price and createdFallback then
	price = Instance.new("TextLabel")
	price.Name = "Price"
	price.AnchorPoint = Vector2.new(0, 0.5)
	price.Position = UDim2.new(0, -6, 0, 0)
	price.Size = UDim2.fromOffset(68, 28)
	price.Rotation = -7
	price.BackgroundColor3 = Color3.fromRGB(255, 204, 0)
	price.Font = Enum.Font.FredokaOne
	price.Text = paidPriceText
	price.TextColor3 = Color3.fromRGB(255, 255, 255)
	price.TextScaled = true
	price.ZIndex = 5
	price.Parent = holder

	local pCorner = Instance.new("UICorner")
	pCorner.CornerRadius = UDim.new(0, 8)
	pCorner.Parent = price

	local pStroke = Instance.new("UIStroke")
	pStroke.Color = Color3.fromRGB(0, 0, 0)
	pStroke.Thickness = 2
	pStroke.Parent = price
end

-- Find or construct Countdown label
local countdown = findChild(holder, { "Countdown", "Timer", "TimeLabel", "Time" }, "TextLabel")
if not countdown and createdFallback then
	countdown = Instance.new("TextLabel")
	countdown.Name = "Countdown"
	countdown.AnchorPoint = Vector2.new(0.5, 0)
	countdown.Position = UDim2.new(0.5, 0, 1, 4)
	countdown.Size = UDim2.fromOffset(60, 22)
	countdown.BackgroundTransparency = 1
	countdown.Font = Enum.Font.FredokaOne
	countdown.Text = "5"
	countdown.TextColor3 = Color3.fromRGB(255, 235, 50)
	countdown.TextScaled = true
	countdown.ZIndex = 4
	countdown.Parent = holder

	local cStroke = Instance.new("UIStroke")
	cStroke.Color = Color3.fromRGB(0, 0, 0)
	cStroke.Thickness = 2
	cStroke.Parent = countdown
end

-- UIScale button click bounce effect
local pressScale = button:FindFirstChild("PressScale") or button:FindFirstChildOfClass("UIScale")
if not pressScale then
	pressScale = Instance.new("UIScale")
	pressScale.Name = "PressScale"
	pressScale.Scale = 1
	pressScale.Parent = button
end

----------------------------------------------------------------------
-- 2) Studio Position Respect:
-- Read the exact position set by the designer in Roblox Studio!
----------------------------------------------------------------------
local OPEN_POS = holder.Position

-- If the designer left it off-screen (Y.Scale >= 1.0), use a centered default
if OPEN_POS.Y.Scale >= 1.0 then
	OPEN_POS = UDim2.new(0.5, 0, 0.80, 0)
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = OPEN_POS
end

local CLOSED_POS = UDim2.new(OPEN_POS.X.Scale, OPEN_POS.X.Offset, 1.30, 0)
holder.Position = CLOSED_POS
holder.Visible = false

----------------------------------------------------------------------
-- 3) Dynamic Price Fetching from Roblox Marketplace
----------------------------------------------------------------------
local function refreshPriceLabel()
	if not price then return end
	local free = player:GetAttribute("InfiniteRevivesOwned") == true
	price.Text = (offerToken and (offerIsFree or free)) and "FREE" or paidPriceText
end

if productId > 0 then
	task.spawn(function()
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(productId, Enum.InfoType.Product)
		end)
		if ok and type(info) == "table" and info.PriceInRobux then
			paidPriceText = tostring(info.PriceInRobux)
			refreshPriceLabel()
		end
	end)
end

----------------------------------------------------------------------
-- 4) Offer Animation & Presentation (respecting Studio OPEN_POS)
----------------------------------------------------------------------
local activeTween = nil

local function hideOffer(serial)
	if serial and serial ~= offerSerial then return end
	offerToken = nil
	offerExpiresAt = 0
	offerIsFree = false
	promptBusy = false
	refreshPriceLabel()

	if activeTween then activeTween:Cancel() end
	activeTween = TweenService:Create(holder, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = CLOSED_POS })
	activeTween:Play()
	activeTween.Completed:Connect(function()
		if not offerToken then
			holder.Visible = false
		end
	end)
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

	if activeTween then activeTween:Cancel() end
	holder.Position = CLOSED_POS
	holder.Visible = offerToken ~= ""
	if not holder.Visible then return end

	activeTween = TweenService:Create(holder, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = OPEN_POS })
	activeTween:Play()

	task.spawn(function()
		while serial == offerSerial and holder.Visible and os.clock() < offerExpiresAt do
			if countdown then
				countdown.Text = tostring(math.max(1, math.ceil(offerExpiresAt - os.clock())))
			end
			task.wait(0.05)
		end
		if serial == offerSerial and offerToken then
			hideOffer(serial)
		end
	end)
end

button.Activated:Connect(function()
	if promptBusy or not offerToken or os.clock() >= offerExpiresAt then return end
	uiClickSound.TimePosition = 0
	uiClickSound:Play()
	promptBusy = true
	button.Active = false

	TweenService:Create(pressScale, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 0.94 }):Play()
	task.delay(0.07, function()
		if pressScale.Parent then
			TweenService:Create(pressScale, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
	end)

	ReviveCommerce:FireServer("RequestPrompt", offerToken)
end)

ReviveCommerce.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then return end
	if payload.Action == "ShowOffer" or payload.Type == "Offer" then
		showOffer(payload)
	elseif payload.Action == "HideOffer" or payload.Type == "Expired" then
		hideOffer(offerSerial)
	elseif payload.Type == "Prompt" then
		if tostring(payload.Token or "") ~= tostring(offerToken or "") then return end
		local pid = tonumber(payload.ProductId) or productId
		local ok, err = pcall(function()
			MarketplaceService:PromptProductPurchase(player, pid)
		end)
		if not ok then
			warn("[RevivePrompt] Could not open purchase prompt: " .. tostring(err))
			promptBusy = false
			button.Active = true
		end
	elseif payload.Type == "Granted" then
		hideOffer(offerSerial)
	elseif payload.Type == "ReviveTeleport" then
		local targetCFrame = payload.TargetCFrame
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp and typeof(targetCFrame) == "CFrame" then
			hrp.CFrame = targetCFrame
		end
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

player:GetAttributeChangedSignal("PromptRevivals"):Connect(function()
	if player:GetAttribute("PromptRevivals") == false then
		hideOffer()
	end
end)
