local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local LocalPlayer = Players.LocalPlayer
local player = LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local MenuEvents = require(ReplicatedStorage.Shared:WaitForChild("MenuEvents"))
local Config = require(ReplicatedStorage.Shared:WaitForChild("Config"))
local PurchaseButtonSound = require(ReplicatedStorage.Shared:WaitForChild("PurchaseButtonSound"))

local ShopGui = PlayerGui:WaitForChild("Shop")
local ShopFrame = ShopGui:WaitForChild("Shop")
local CloseBtn = ShopFrame:WaitForChild("Close")
local ScrollFrame = ShopFrame:WaitForChild("ScrollingFrame")

local sidebarHolder = ShopGui:WaitForChild("Listbutton")
local Sidebar = sidebarHolder:WaitForChild("Frame")
local GiftFrame = ShopGui:WaitForChild("Gift")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local CodesRequest = Remotes:WaitForChild("CodesRequest")
local CodesUpdate = Remotes:WaitForChild("CodesUpdate")

local isOpen = false
local isClosing = false
local promptBusy = false
local selectedGift = nil

-- Configuración de Animación idéntica a AbilitiesPanel
local POPUP_OPEN_INFO = TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local POPUP_CLOSE_INFO = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local DIM_OPEN_INFO = TweenInfo.new(0.20, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
local DIM_CLOSE_INFO = TweenInfo.new(0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.In)

-- Guardar posiciones abiertas originales de Studio y calcular las cerradas (abajo de pantalla)
local SHOP_OPEN_POS = ShopFrame.Position
local SHOP_CLOSED_POS = UDim2.new(SHOP_OPEN_POS.X.Scale, SHOP_OPEN_POS.X.Offset, 1.28, 0)

local SIDE_OPEN_POS = sidebarHolder.Position
local SIDE_CLOSED_POS = UDim2.new(SIDE_OPEN_POS.X.Scale, SIDE_OPEN_POS.X.Offset, 1.28, 0)

local GIFT_OPEN_POS = GiftFrame.Position
local GIFT_CLOSED_POS = UDim2.new(GIFT_OPEN_POS.X.Scale, GIFT_OPEN_POS.X.Offset, 1.28, 0)

local shopTween, sideTween, giftTween, dimTween

local activeScrollTween: Tween? = nil

local function smoothScrollToCategory(categoryName: string)
	local targetY: number? = nil

	-- Search for Title label in ScrollingFrame matching category name
	for _, c in ipairs(ScrollFrame:GetChildren()) do
		if c:IsA("TextLabel") and string.lower(c.Text) == string.lower(categoryName) then
			targetY = c.Position.Y.Scale * ScrollFrame.AbsoluteCanvasSize.Y + c.Position.Y.Offset
			break
		end
	end

	if not targetY then
		local fallbackMap = {
			Exclusive = "ExclusiveVIP",
			Server = "2XServerSpeed",
			Passes = "Pass",
			Treadmills = "Treadmill Valentine",
			Potions = "PotionLarge2xSpeed",
			Codes = "CodesFrame",
		}
		local frameName = fallbackMap[categoryName]
		local frame = frameName and (ScrollFrame:FindFirstChild(frameName) or (categoryName == "Potions" and ScrollFrame:FindFirstChild("2XSpeedpotion10MinSmall")))
		if frame and frame:IsA("GuiObject") then
			targetY = frame.Position.Y.Scale * ScrollFrame.AbsoluteCanvasSize.Y + frame.Position.Y.Offset - 28
		end
	end

	if not targetY then return end

	local viewSize = ScrollFrame.AbsoluteWindowSize.Y
	local maxY = math.max(0, ScrollFrame.AbsoluteCanvasSize.Y - viewSize)
	local clampedY = math.clamp(math.max(0, targetY - 12), 0, maxY)

	if activeScrollTween then
		activeScrollTween:Cancel()
		activeScrollTween = nil
	end

	local distance = math.abs(ScrollFrame.CanvasPosition.Y - clampedY)
	local duration = math.clamp(distance / 1600, 0.22, 0.40)
	activeScrollTween = TweenService:Create(
		ScrollFrame,
		TweenInfo.new(duration, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out),
		{ CanvasPosition = Vector2.new(0, clampedY) }
	)
	activeScrollTween:Play()
end

local doubleWinsProductId = tonumber(Config.DoubleWinsPadProductId)
local doubleWinsPassId = tonumber(Config.DoubleWinsPadGamePassId) or 0

-- Map pass items to their GamePass or Product IDs
local PASS_MAP = {
	["Starter Pack"] = { type = "GamePass", id = tonumber(Config.StarterPackGamePassId) or 0 },
	["2X Win"] = (doubleWinsProductId and doubleWinsProductId > 0)
		and { type = "Product", id = doubleWinsProductId }
		or { type = "GamePass", id = doubleWinsPassId },
	["2X Speed"] = { type = "GamePass", id = tonumber(Config.TwoXSpeedGamePassId) or 0 },
	["Revive"] = { type = "GamePass", id = tonumber(Config.InfiniteRevivesGamePassId) or 0 },
}

local TREADMILL_MAP = {
	["Treadmill Admin"] = { type = "GamePass", id = 1941342451 },
	["Treadmill Hacker"] = { type = "GamePass", id = 1954325260 },
	["Treadmill Valentine"] = { type = "GamePass", id = tonumber(Config.ValentineTreadmillPassId) or 0 },
}

local function durationText(minutes)
	minutes = math.max(1, math.floor(tonumber(minutes) or 10))
	if minutes >= 60 and minutes % 60 == 0 then
		return tostring(minutes / 60) .. " Hour"
	end
	return tostring(minutes) .. " Minutes"
end

local cardPrices = {}
local DEFAULT_PRICES = {
	["ExclusiveVIP"] = 499,
	["Treadmill Hacker"] = 799,
	["Treadmill Admin"] = 499,
	["Treadmill Valentine"] = 149,
	["2X Speed"] = 249,
	["2X Win"] = 249,
	["Revive"] = 499,
	["Starter Pack"] = 50,
	["2XServerSpeed"] = 550,
	["2XSpeedpotion10MinSmall"] = 9,
	["2XSpeedPotionMedium"] = 27,
	["PotionLarge2xSpeed"] = 42,
	["PotionSmall"] = 49,
	["PotionMedium"] = 139,
	["PotionLarge"] = 219,
}
local refreshGiftRows

local function setExactPrice(card, buyBtn, price)
	if card then
		cardPrices[card.Name] = tonumber(price) or 0
	end
	if not price or price <= 0 then return end
	local priceText = tostring(math.floor(price))
	-- NOTE: We intentionally DO NOT overwrite card:FindFirstChild("Frame"):FindFirstChild("Name")
	-- because that is the strikethrough frame showing the higher original anchor price (e.g. 550, 1200).
	-- We only update the buy button's label to the actual purchase price!
	if buyBtn then
		local foundLabel = false
		for _, label in ipairs(buyBtn:GetDescendants()) do
			if label:IsA("TextLabel") and (label.Name == "Name" or label.Name == "Price" or label.Name == "Robux" or label.Name == "Amount") then
				label.Text = priceText
				foundLabel = true
			end
		end
		if not foundLabel then
			for _, label in ipairs(buyBtn:GetDescendants()) do
				if label:IsA("TextLabel") then
					label.Text = priceText
					break
				end
			end
		end
	end
end

local function promptPurchase(passType, passId)
	if promptBusy or passId <= 0 then return end
	promptBusy = true
	PurchaseButtonSound.Play()
	local ok, err
	if passType == "GamePass" then
		ok, err = pcall(function()
			MarketplaceService:PromptGamePassPurchase(LocalPlayer, passId)
		end)
	else
		ok, err = pcall(function()
			MarketplaceService:PromptProductPurchase(LocalPlayer, passId)
		end)
	end
	if not ok then
		warn("[ShopController] Purchase prompt failed: " .. tostring(err))
	end
	task.delay(0.8, function()
		promptBusy = false
	end)
end

-- Animación de GiftFrame idéntica a AbilitiesPanel
local isGiftClosing = false

local function closeGiftPanel(instant)
	if not GiftFrame.Visible and not isGiftClosing then return end

	if instant then
		isGiftClosing = false
		if giftTween then giftTween:Cancel() end
		GiftFrame.Visible = false
		GiftFrame.Position = GIFT_CLOSED_POS
		ShopFrame.Visible = true
		ShopFrame.Position = SHOP_OPEN_POS
		sidebarHolder.Visible = true
		sidebarHolder.Position = SIDE_OPEN_POS
		return
	end

	if isGiftClosing then return end
	isGiftClosing = true

	if giftTween then giftTween:Cancel() end
	giftTween = TweenService:Create(GiftFrame, POPUP_CLOSE_INFO, { Position = GIFT_CLOSED_POS })
	giftTween:Play()

	task.delay(POPUP_CLOSE_INFO.Time, function()
		if not isGiftClosing then return end
		isGiftClosing = false
		GiftFrame.Visible = false
		GiftFrame.Position = GIFT_CLOSED_POS

		-- Vuelve a entrar el menú principal deslizándose desde abajo
		ShopFrame.Visible = true
		ShopFrame.Position = SHOP_CLOSED_POS
		if shopTween then shopTween:Cancel() end
		shopTween = TweenService:Create(ShopFrame, POPUP_OPEN_INFO, { Position = SHOP_OPEN_POS })
		shopTween:Play()

		sidebarHolder.Visible = true
		sidebarHolder.Position = SIDE_CLOSED_POS
		if sideTween then sideTween:Cancel() end
		sideTween = TweenService:Create(sidebarHolder, POPUP_OPEN_INFO, { Position = SIDE_OPEN_POS })
		sideTween:Play()
	end)
end

local function openGiftPanel(passType, passId, cardName)
	PurchaseButtonSound.Play()
	isGiftClosing = false
	selectedGift = {
		passType = passType,
		id = passId,
		price = cardPrices[cardName] or 0,
	}
	if refreshGiftRows then refreshGiftRows() end

	GiftFrame.ZIndex = 50
	for _, desc in ipairs(GiftFrame:GetDescendants()) do
		if desc:IsA("GuiObject") then
			desc.ZIndex = math.max(desc.ZIndex, 51)
		end
	end

	ShopFrame.Visible = false
	sidebarHolder.Visible = false

	-- Entrada desde abajo con rebote Back.Out
	if giftTween then giftTween:Cancel() end
	GiftFrame.Position = GIFT_CLOSED_POS
	GiftFrame.Visible = true
	giftTween = TweenService:Create(GiftFrame, POPUP_OPEN_INFO, { Position = GIFT_OPEN_POS })
	giftTween:Play()
end

local ownedPasses = {}

local function isPassOwned(cardName, passId)
	if passId and ownedPasses[passId] == true then
		return true
	end
	if cardName == "2X Speed" then
		if player:GetAttribute("TwoXSpeedOwned") == true or (tonumber(player:GetAttribute("PermanentBaseSpeedMultiplier")) or 1) >= 2 then
			if passId then ownedPasses[passId] = true end
			return true
		end
	elseif cardName == "2X Win" then
		if player:GetAttribute("DoubleWinsPadUnlocked") == true or (tonumber(player:GetAttribute("PermanentWinsMultiplier")) or 1) >= 2 then
			if passId then ownedPasses[passId] = true end
			return true
		end
	elseif cardName == "Starter Pack" then
		if player:GetAttribute("StarterPackOwned") == true then
			if passId then ownedPasses[passId] = true end
			return true
		end
	elseif cardName == "Revive" then
		if player:GetAttribute("InfiniteRevivesOwned") == true then
			if passId then ownedPasses[passId] = true end
			return true
		end
	end
	if passId and passId > 0 then
		local ok, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
		end)
		if ok and owns == true then
			ownedPasses[passId] = true
			return true
		end
	end
	return false
end

local function setCardPurchased(card)
	if not card then return end
	card:SetAttribute("Purchased", true)
	local buyBtn = card:FindFirstChild("Buy")
	if buyBtn then
		buyBtn.Active = false
		buyBtn.AutoButtonColor = false
		buyBtn.ImageColor3 = Color3.fromRGB(115, 115, 115)
		for _, child in ipairs(buyBtn:GetChildren()) do
			if child:IsA("ImageLabel") then
				child.Visible = false
			elseif child:IsA("TextLabel") then
				child.Text = "PURCHASED"
				child.TextColor3 = Color3.fromRGB(200, 255, 200)
				child.Size = UDim2.fromScale(1, 1)
				child.Position = UDim2.fromScale(0.5, 0.5)
				child.AnchorPoint = Vector2.new(0.5, 0.5)
				child.TextXAlignment = Enum.TextXAlignment.Center
			end
		end
	end
end

local function wireCardBuy(card, buyBtn, giftBtn, passType, passId)
	if buyBtn and buyBtn:IsA("ImageButton") and passId and passId > 0 then
		buyBtn.Activated:Connect(function()
			if card and card:GetAttribute("Purchased") == true then
				return
			end
			promptPurchase(passType, passId)
		end)
	end
	if giftBtn and giftBtn:IsA("ImageButton") and passId and passId > 0 then
		giftBtn.Activated:Connect(function()
			openGiftPanel(passType, passId, card and card.Name)
		end)
	end
end

local function applyGamePassDescription(card, description, skipTexts)
	if not card or type(description) ~= "string" or description == "" then
		return
	end
	local skip = { [string.lower(tostring(card.Name))] = true }
	if type(skipTexts) == "table" then
		for _, text in ipairs(skipTexts) do
			skip[string.lower(tostring(text))] = true
		end
	end
	for _, child in ipairs(card:GetChildren()) do
		if child:IsA("TextLabel")
			and (child.Name == "Tittle" or child.Name == "Description")
			and not skip[string.lower(tostring(child.Text))]
		then
			child.Text = description
			child.TextWrapped = true
			return
		end
	end
end

local function wirePassCards()
	local Pass = ScrollFrame:FindFirstChild("Pass")
	if not Pass then return end

	for _, item in ipairs(Pass:GetChildren()) do
		if item:IsA("Frame") then
			local buyBtn = item:FindFirstChild("Buy")
			local giftBtn = item:FindFirstChild("Gift")

			local passInfo = PASS_MAP[item.Name]
			if not passInfo then
				wireCardBuy(item, buyBtn, giftBtn, nil, 0)
				continue
			end

			local passId = tonumber(passInfo.id) or 0
			if passId <= 0 then
				wireCardBuy(item, buyBtn, giftBtn, passInfo.type, 0)
				continue
			end

			wireCardBuy(item, buyBtn, giftBtn, passInfo.type, passId)
			local defPassPrice = DEFAULT_PRICES[item.Name]
			if defPassPrice then
				setExactPrice(item, buyBtn, defPassPrice)
			end

			task.spawn(function()
				if isPassOwned(item.Name, passId) then
					setCardPurchased(item)
					return
				end

				local infoType = (passInfo.type == "Product") and Enum.InfoType.Product or Enum.InfoType.GamePass
				local ok, info = pcall(function()
					return MarketplaceService:GetProductInfo(passId, infoType)
				end)
				if ok and type(info) == "table" and info.PriceInRobux then
					local livePrice = tonumber(info.UserBasePriceInRobux or info.BasePriceInRobux or info.OriginalPrice or info.PriceInRobux) or info.PriceInRobux
					setExactPrice(item, buyBtn, livePrice)
					if isPassOwned(item.Name, passId) then
						setCardPurchased(item)
					end
					applyGamePassDescription(item, info.Description)
				else
					warn("[ShopController] Live price for " .. tostring(item.Name) .. " could not be resolved from MarketplaceService.")
				end
			end)
		end
	end
end

local function wirePotionCards()
	local function wirePotion(card, product)
		if not card then return end
		local buyBtn = card:FindFirstChild("Buy")
		local giftBtn = card:FindFirstChild("Gift")

		local tittles = {}
		for _, child in ipairs(card:GetChildren()) do
			if child:IsA("TextLabel") and child.Name == "Tittle" then
				table.insert(tittles, child)
			end
		end
		for _, label in ipairs(tittles) do
			local text = tostring(label.Text)
			if string.match(text, "^x%d+$") then
				label.Text = tostring(math.floor(tonumber(product.PriceRobux) or 0))
			elseif string.find(string.lower(text), "minute") or string.find(string.lower(text), "hour") then
				label.Text = durationText(product.DurationMinutes)
			else
				label.Text = tostring(product.Label or product.ShopFrame or "Potion")
			end
		end

		local initialPrice = tonumber(product.PriceRobux) or 0
		setExactPrice(card, buyBtn, initialPrice)
		local productId = tonumber(product.ProductId) or 0
		wireCardBuy(card, buyBtn, giftBtn, "Product", productId)

		if productId > 0 then
			task.spawn(function()
				local ok, info = pcall(function()
					return MarketplaceService:GetProductInfo(productId, Enum.InfoType.Product)
				end)
				if ok and type(info) == "table" and info.PriceInRobux then
					local livePrice = tonumber(info.UserBasePriceInRobux or info.BasePriceInRobux or info.OriginalPrice or info.PriceInRobux) or info.PriceInRobux
					setExactPrice(card, buyBtn, livePrice)
				end
			end)
		end
	end

	for _, product in ipairs(Config.PotionWinsProducts or {}) do
		wirePotion(ScrollFrame:FindFirstChild(product.ShopFrame), product)
	end
	for _, product in ipairs(Config.PotionSpeedProducts or {}) do
		wirePotion(ScrollFrame:FindFirstChild(product.ShopFrame), product)
	end
end

local function wireServerBoostCard()
	local card = ScrollFrame:FindFirstChild("2XServerSpeed")
	if not card then return end
	local buyBtn = card:FindFirstChild("Buy")
	local giftBtn = card:FindFirstChild("Gift")
	local boost = Config.ServerSpeedBoostProduct
	local initialPrice = tonumber(boost and boost.PriceRobux) or 0
	setExactPrice(card, buyBtn, initialPrice)
	local boostPid = tonumber(boost and boost.ProductId) or 0
	wireCardBuy(card, buyBtn, giftBtn, "Product", boostPid)

	if boostPid > 0 then
		task.spawn(function()
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(boostPid, Enum.InfoType.Product)
			end)
			if ok and type(info) == "table" and info.PriceInRobux then
				setExactPrice(card, buyBtn, info.PriceInRobux)
			end
		end)
	end
end

local function wireExclusiveVipCard()
	local card = ScrollFrame:FindFirstChild("ExclusiveVIP")
	if not card then return end
	local buyBtn = card:FindFirstChild("Buy")
	local giftBtn = card:FindFirstChild("Gift")

	local passId = tonumber(Config.VipGamePassId) or 0
	if passId <= 0 then
		wireCardBuy(card, buyBtn, giftBtn, "GamePass", 0)
		return
	end

	setExactPrice(card, buyBtn, DEFAULT_PRICES["ExclusiveVIP"] or 499)

	task.spawn(function()
		if isPassOwned("ExclusiveVIP", passId) then
			setCardPurchased(card)
			wireCardBuy(card, buyBtn, giftBtn, "GamePass", passId)
			return
		end

		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(passId, Enum.InfoType.GamePass)
		end)
		if ok and type(info) == "table" and info.PriceInRobux then
			local livePrice = tonumber(info.UserBasePriceInRobux or info.BasePriceInRobux or info.OriginalPrice or info.PriceInRobux) or 499
			setExactPrice(card, buyBtn, livePrice)
			if isPassOwned("ExclusiveVIP", passId) then
				setCardPurchased(card)
			end
			wireCardBuy(card, buyBtn, giftBtn, "GamePass", passId)
			applyGamePassDescription(card, info.Description, { "Digital Vip" })
		else
			warn("[ShopController] ExclusiveVIP gamepass not purchasable; buy disabled.")
			wireCardBuy(card, buyBtn, giftBtn, "GamePass", 0)
		end
	end)
end

local function wireTreadmillCards()
	for sectionName, treadmillInfo in pairs(TREADMILL_MAP) do
		local section = ScrollFrame:FindFirstChild(sectionName)
		if section then
			local buyBtn = section:FindFirstChild("Buy")
			local giftBtn = section:FindFirstChild("Gift")
			local defTreadPrice = DEFAULT_PRICES[sectionName]
			if defTreadPrice then
				setExactPrice(section, buyBtn, defTreadPrice)
			end

			task.spawn(function()
				if isPassOwned(sectionName, treadmillInfo.id) then
					setCardPurchased(section)
					wireCardBuy(section, buyBtn, giftBtn, treadmillInfo.type, treadmillInfo.id)
					return
				end

				local ok, info = pcall(function()
					return MarketplaceService:GetProductInfo(treadmillInfo.id, Enum.InfoType.GamePass)
				end)
				if ok and type(info) == "table" and info.PriceInRobux then
					local livePrice = tonumber(info.UserBasePriceInRobux or info.BasePriceInRobux or info.OriginalPrice or info.PriceInRobux) or info.PriceInRobux
					setExactPrice(section, buyBtn, livePrice)
					if isPassOwned(sectionName, treadmillInfo.id) then
						setCardPurchased(section)
					end
					wireCardBuy(section, buyBtn, giftBtn, treadmillInfo.type, treadmillInfo.id)
					applyGamePassDescription(section, info.Description)
				else
					warn("[ShopController] " .. tostring(sectionName) .. " not purchasable; buy disabled.")
					wireCardBuy(section, buyBtn, giftBtn, treadmillInfo.type, 0)
				end
			end)
		end
	end
end

local function refreshAllPassCardsOwnership()
	local Pass = ScrollFrame:FindFirstChild("Pass")
	if Pass then
		for _, item in ipairs(Pass:GetChildren()) do
			if item:IsA("Frame") then
				local passInfo = PASS_MAP[item.Name]
				if passInfo and passInfo.id and passInfo.id > 0 then
					if isPassOwned(item.Name, passInfo.id) then
						setCardPurchased(item)
					end
				end
			end
		end
	end
	for sectionName, treadmillInfo in pairs(TREADMILL_MAP) do
		local section = ScrollFrame:FindFirstChild(sectionName)
		if section and isPassOwned(sectionName, treadmillInfo.id) then
			setCardPurchased(section)
		end
	end
	local vipCard = ScrollFrame:FindFirstChild("ExclusiveVIP")
	if vipCard and tonumber(Config.VipGamePassId) and isPassOwned("ExclusiveVIP", tonumber(Config.VipGamePassId)) then
		setCardPurchased(vipCard)
	end
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(buyer, gamePassId, success)
	if success and buyer == player then
		ownedPasses[tonumber(gamePassId)] = true
		refreshAllPassCardsOwnership()
	end
end)

MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, isPurchased)
	if isPurchased and userId == player.UserId then
		refreshAllPassCardsOwnership()
	end
end)

player:GetAttributeChangedSignal("TwoXSpeedOwned"):Connect(refreshAllPassCardsOwnership)
player:GetAttributeChangedSignal("DoubleWinsPadUnlocked"):Connect(refreshAllPassCardsOwnership)
player:GetAttributeChangedSignal("PermanentBaseSpeedMultiplier"):Connect(refreshAllPassCardsOwnership)
player:GetAttributeChangedSignal("PermanentWinsMultiplier"):Connect(refreshAllPassCardsOwnership)
player:GetAttributeChangedSignal("StarterPackOwned"):Connect(refreshAllPassCardsOwnership)
player:GetAttributeChangedSignal("InfiniteRevivesOwned"):Connect(refreshAllPassCardsOwnership)

local codeSuccessSound = Instance.new("Sound")
codeSuccessSound.Name = "CodeRedeemSuccessSound"
codeSuccessSound.SoundId = "rbxassetid://80736831159506"
codeSuccessSound.Volume = 0.95
codeSuccessSound.Parent = SoundService

local function wireCodesSection()
	local codesFrame = ScrollFrame:FindFirstChild("CodesFrame")
	if not codesFrame then return end

	local textBox = codesFrame:FindFirstChild("TextBox")
	local redeemBtn = codesFrame:FindFirstChild("Reddem")

	if not (redeemBtn and redeemBtn:IsA("ImageButton") and textBox and textBox:IsA("TextBox")) then
		return
	end

	local btnLabel = redeemBtn:FindFirstChild("Name") or redeemBtn:FindFirstChildOfClass("TextLabel")
	local originalBtnText = btnLabel and btnLabel.Text or "Redeem"

	local statusLabel = codesFrame:FindFirstChild("StatusFeedback")
	if not statusLabel then
		statusLabel = Instance.new("TextLabel")
		statusLabel.Name = "StatusFeedback"
		statusLabel.AnchorPoint = Vector2.new(0.5, 0.5)
		statusLabel.Position = UDim2.new(0.65, 0, 0.28, 0)
		statusLabel.Size = UDim2.new(0.60, 0, 0.30, 0)
		statusLabel.BackgroundTransparency = 1
		statusLabel.TextScaled = true
		statusLabel.FontFace = Font.fromName("FredokaOne")
		statusLabel.TextColor3 = Color3.fromRGB(85, 255, 127)
		statusLabel.Text = ""
		statusLabel.Visible = false
		statusLabel.ZIndex = 4

		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Color = Color3.fromRGB(0, 0, 0)
		stroke.Parent = statusLabel

		local constraint = Instance.new("UITextSizeConstraint")
		constraint.MaxTextSize = 22
		constraint.MinTextSize = 10
		constraint.Parent = statusLabel

		statusLabel.Parent = codesFrame
	end

	textBox.PlaceholderText = "Enter code here..."
	textBox.PlaceholderColor3 = Color3.fromRGB(160, 190, 210)

	local feedbackSerial = 0
	local function setFeedback(text, isSuccess, btnStatus)
		feedbackSerial += 1
		local current = feedbackSerial

		statusLabel.Text = text
		statusLabel.TextColor3 = isSuccess and Color3.fromRGB(85, 255, 127) or Color3.fromRGB(255, 85, 85)
		statusLabel.Visible = true

		if btnLabel and btnStatus then
			btnLabel.Text = btnStatus
		end

		if isSuccess then
			codeSuccessSound.TimePosition = 0
			SoundService:PlayLocalSound(codeSuccessSound)
		end

		task.delay(3.5, function()
			if feedbackSerial == current then
				statusLabel.Visible = false
				if btnLabel then
					btnLabel.Text = originalBtnText
				end
				if textBox then
					textBox.PlaceholderText = "Enter code here..."
					textBox.PlaceholderColor3 = Color3.fromRGB(160, 190, 210)
				end
			end
		end)
	end

	local isSubmitting = false
	local function doRedeem()
		if isSubmitting then return end
		local rawCode = textBox.Text
		local codeText = rawCode and rawCode:match("^%s*(.-)%s*$")
		if not codeText or codeText == "" then
			setFeedback("Please enter a code!", false, "EMPTY")
			return
		end

		isSubmitting = true
		if btnLabel then
			btnLabel.Text = "..."
		end
		statusLabel.Text = "Redeeming..."
		statusLabel.TextColor3 = Color3.fromRGB(255, 220, 80)
		statusLabel.Visible = true

		CodesRequest:FireServer("Redeem", codeText)
	end

	redeemBtn.Activated:Connect(function()
		PurchaseButtonSound.Play()
		doRedeem()
	end)

	textBox.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			doRedeem()
		end
	end)

	CodesUpdate.OnClientEvent:Connect(function(data)
		isSubmitting = false
		if type(data) ~= "table" then return end

		local msg = tostring(data.Message or "")
		if data.Success == true then
			textBox.Text = ""
			textBox.PlaceholderText = msg ~= "" and msg or "Code Redeemed!"
			textBox.PlaceholderColor3 = Color3.fromRGB(85, 255, 127)
			setFeedback(msg ~= "" and msg or "Successfully redeemed!", true, "SUCCESS!")
		else
			local btnWord = "INVALID"
			if msg:lower():find("already") then
				btnWord = "CLAIMED"
			end
			setFeedback(msg ~= "" and msg or "Invalid code.", false, btnWord)
		end
	end)
end

local GiftContextRequest = Remotes:WaitForChild("GiftContextRequest", 5) or Remotes:FindFirstChild("GiftContextRequest")
local giftRequestSerial=0
local giftReplies={}
if GiftContextRequest then
	GiftContextRequest.OnClientEvent:Connect(function(id,ok) giftReplies[id]=ok==true end)
end
local templatePriceFormat = nil

refreshGiftRows = function()
	local list = GiftFrame:FindFirstChild("ScrollingFrame")
	if not list then return end
	local template

	for _, child in ipairs(list:GetChildren()) do
		if child.Name == "TemplatePlayer" or (child:IsA("GuiObject") and child:FindFirstChild("Price")) then
			if not template then
				template = child
				-- Extraer el formato con espacios de Studio para que el Robux no tape "("
				if not templatePriceFormat then
					local pBtn = template:FindFirstChild("Price")
					local pLbl = pBtn and pBtn:FindFirstChild("Name")
					if pLbl and pLbl:IsA("TextLabel") and pLbl.Text ~= "" and string.find(pLbl.Text, "%d+") then
						templatePriceFormat = pLbl.Text
					end
				end
			else
				child:Destroy()
			end
		end
	end
	if not template then return end
	template.Visible = false

	local priceNumberText = "0"
	if selectedGift and selectedGift.price and selectedGift.price > 0 then
		priceNumberText = tostring(math.floor(selectedGift.price))
	end

	local finalPriceText
	if templatePriceFormat then
		finalPriceText = string.gsub(templatePriceFormat, "%d+", priceNumberText)
	else
		finalPriceText = "Gift (   " .. priceNumberText .. ")"
	end

	for _, plr in ipairs(Players:GetPlayers()) do
		if plr:GetAttribute("AcceptGifts") == false then
			continue
		end
		local row = template:Clone()
		row.Visible = true
		row.Parent = list

		local nameLbl = row:FindFirstChild("Name")
		if nameLbl and nameLbl:IsA("TextLabel") then
			nameLbl.Text = plr.Name
		end

		local head = row:FindFirstChild("ImageLabel")
		if head and head:IsA("ImageLabel") then
			local ok, url = pcall(function()
				return Players:GetUserThumbnailAsync(plr.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
			end)
			if ok and type(url) == "string" and url ~= "" then
				head.Image = url
			end
		end

		local priceBtn = row:FindFirstChild("Price")
		if priceBtn and priceBtn:IsA("ImageButton") then
			local priceLabel = priceBtn:FindFirstChild("Name")
			if priceLabel and priceLabel:IsA("TextLabel") then
				priceLabel.Text = finalPriceText
			end
			priceBtn.Activated:Connect(function()
				if not selectedGift or not selectedGift.id or selectedGift.id <= 0 then
					return
				end
				if not GiftContextRequest or selectedGift.passType=="GamePass" or plr==player then
					if priceLabel then priceLabel.Text="Gift unavailable" end
					return
				end
				local gift=table.clone(selectedGift)
				giftRequestSerial+=1
				local id=tostring(os.clock())..":"..giftRequestSerial
				priceBtn.Active=false
				if priceLabel then priceLabel.Text="Preparing gift..." end
				GiftContextRequest:FireServer(plr.UserId,gift.id,id)
				local deadline=os.clock()+20
				repeat task.wait(0.1) until giftReplies[id]~=nil or os.clock()>=deadline
				local ready=giftReplies[id];giftReplies[id]=nil
				priceBtn.Active=true
				if not ready then
					if priceLabel then priceLabel.Text="Could not prepare gift. Retry." end
					return
				end
				promptPurchase(gift.passType,gift.id)
				closeGiftPanel()
			end)
		end
	end
end

local SIDEBAR_HOVER_IN = TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local SIDEBAR_HOVER_OUT = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local SIDEBAR_PRESS = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function attachSidebarCategoryButton(btn: GuiButton, categoryName: string)
	if not btn or not btn:IsA("GuiButton") then return end

	local scale = btn:FindFirstChild("CategoryScale")
	if not scale or not scale:IsA("UIScale") then
		scale = Instance.new("UIScale")
		scale.Name = "CategoryScale"
		scale.Scale = 1.0
		scale.Parent = btn
	end

	local isHovered = false

	local function onEnter()
		isHovered = true
		TweenService:Create(scale, SIDEBAR_HOVER_IN, { Scale = 1.10 }):Play()
	end

	local function onLeave()
		isHovered = false
		TweenService:Create(scale, SIDEBAR_HOVER_OUT, { Scale = 1.0 }):Play()
	end

	local function onDown()
		TweenService:Create(scale, SIDEBAR_PRESS, { Scale = 0.92 }):Play()
	end

	local function onUp()
		if isHovered then
			onEnter()
		else
			onLeave()
		end
	end

	btn.MouseEnter:Connect(onEnter)
	btn.MouseLeave:Connect(onLeave)
	btn.MouseButton1Down:Connect(onDown)
	btn.MouseButton1Up:Connect(onUp)
	btn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			onDown()
		end
	end)
	btn.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			onLeave()
		end
	end)
	btn.Activated:Connect(function()
		PurchaseButtonSound.Play()
		smoothScrollToCategory(categoryName)
	end)
end

local function wireSidebar()
	local decorativeImage = sidebarHolder:FindFirstChildOfClass("ImageLabel")
	if decorativeImage then
		decorativeImage.Rotation = 0
		local rogueScale = decorativeImage:FindFirstChild("HeaderIconScale")
		if rogueScale then
			rogueScale:Destroy()
		end
	end

	local categories = { "Exclusive", "Server", "Passes", "Treadmills", "Potions", "Codes" }
	for _, categoryName in ipairs(categories) do
		local btn = Sidebar:FindFirstChild(categoryName)
		if btn and btn:IsA("GuiButton") then
			attachSidebarCategoryButton(btn, categoryName)
		end
	end
end

local closePanel

local function openPanel()
	if isOpen and ShopGui.Enabled and not isClosing then return end
	isClosing = false
	isOpen = true
	ShopGui.Enabled = true
	ScrollFrame.CanvasPosition = Vector2.new(0, 0)
	refreshAllPassCardsOwnership()
	closeGiftPanel(true)

	local dim = ShopGui:FindFirstChild("Dim")
	if dim and dim:IsA("GuiObject") then
		if dimTween then dimTween:Cancel() end
		dim.Visible = true
		dim.Active = true
		dim.BackgroundTransparency = 1
		dimTween = TweenService:Create(dim, DIM_OPEN_INFO, { BackgroundTransparency = 0.55 })
		dimTween:Play()
	end

	-- Animación idéntica a AbilitiesPanel (entra desde abajo con Back.Out)
	if shopTween then shopTween:Cancel() end
	ShopFrame.Visible = true
	ShopFrame.Position = SHOP_CLOSED_POS
	shopTween = TweenService:Create(ShopFrame, POPUP_OPEN_INFO, { Position = SHOP_OPEN_POS })
	shopTween:Play()

	if sideTween then sideTween:Cancel() end
	sidebarHolder.Visible = true
	sidebarHolder.Position = SIDE_CLOSED_POS
	sideTween = TweenService:Create(sidebarHolder, POPUP_OPEN_INFO, { Position = SIDE_OPEN_POS })
	sideTween:Play()
end

closePanel = function(instant)
	if not isOpen and not ShopGui.Enabled then return end
	local dim = ShopGui:FindFirstChild("Dim")

	if instant then
		isClosing = false
		isOpen = false
		ShopGui.Enabled = false
		if shopTween then shopTween:Cancel() end
		if sideTween then sideTween:Cancel() end
		if dimTween then dimTween:Cancel() end
		ShopFrame.Position = SHOP_CLOSED_POS
		sidebarHolder.Position = SIDE_CLOSED_POS
		closeGiftPanel(true)
		if dim and dim:IsA("GuiObject") then
			dim.Visible = false
			dim.Active = false
			dim.BackgroundTransparency = 1
		end
		return
	end

	if isClosing then return end
	isClosing = true

	if dim and dim:IsA("GuiObject") then
		if dimTween then dimTween:Cancel() end
		dimTween = TweenService:Create(dim, DIM_CLOSE_INFO, { BackgroundTransparency = 1 })
		dimTween:Play()
	end

	-- Se desliza hacia abajo al cerrarse
	if shopTween then shopTween:Cancel() end
	shopTween = TweenService:Create(ShopFrame, POPUP_CLOSE_INFO, { Position = SHOP_CLOSED_POS })
	shopTween:Play()

	if sideTween then sideTween:Cancel() end
	sideTween = TweenService:Create(sidebarHolder, POPUP_CLOSE_INFO, { Position = SIDE_CLOSED_POS })
	sideTween:Play()

	task.delay(POPUP_CLOSE_INFO.Time, function()
		if not isClosing then return end
		isClosing = false
		ShopGui.Enabled = false
		isOpen = false
		closeGiftPanel(true)
		if dim and dim:IsA("GuiObject") then
			dim.Visible = false
			dim.Active = false
			dim.BackgroundTransparency = 1
		end
		ShopFrame.Position = SHOP_CLOSED_POS
		sidebarHolder.Position = SIDE_CLOSED_POS
	end)
end

CloseBtn.Activated:Connect(function()
	closePanel()
end)
if CloseBtn:IsA("GuiButton") then
	CloseBtn.MouseButton1Click:Connect(function()
		closePanel()
	end)
end
CloseBtn.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		closePanel()
	end
end)

local giftCloseBtn = GiftFrame:FindFirstChild("ImageButton")
if giftCloseBtn and giftCloseBtn:IsA("ImageButton") then
	giftCloseBtn.Activated:Connect(function()
		closeGiftPanel()
	end)
	giftCloseBtn.MouseButton1Click:Connect(function()
		closeGiftPanel()
	end)
end

local function handleOpenEvent(action)
	if action == "Close" then
		closePanel(true)
	elseif action == "Open" then
		openPanel()
	else
		if isOpen then
			closePanel()
		else
			openPanel()
		end
	end
end

MenuEvents.Get("OpenShopPanel").Event:Connect(handleOpenEvent)

MenuEvents.CloseAll.Event:Connect(function(exceptMenuName)
	if exceptMenuName == "Shop" then return end
	closePanel(true)
end)

MenuEvents.MarkReady("Shop", function()
	return isOpen
end)
closePanel(true)

wirePassCards()
wirePotionCards()
wireServerBoostCard()
wireExclusiveVipCard()
wireTreadmillCards()
wireCodesSection()
wireSidebar()
print("[ShopController] Loaded")