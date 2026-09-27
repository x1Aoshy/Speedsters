--[[

	BackpackScript - wires the designer-made Backpack screen (StarterGui.Backpack).

	Replaces the runtime-built BackpackController panel (now deleted).



	- Aura / Trail tab Images swap which scrolling list is shown (Trail first).

	- Each item's WinsPurchase / RobuxPurchase price label is filled from

	  CosmeticCatalog - amounts only, the stat / name labels stay untouched.

	- Wins purchases fire TrailShopAction / AuraShopAction "Buy" (server deducts Wins).

	- Robux purchases prompt the right product: DevProducts use

	  PromptProductPurchase, the Blue Trail GamePass uses PromptGamePassPurchase

	  (TrailShopSystem grants it via PromptGamePassPurchaseFinished).

	- Once an item is owned the same Wins/Robux buttons change their label to

	  EQUIP / EQUIPPED and fire the Equip action (no extra button is added).

]]



local MarketplaceService = game:GetService("MarketplaceService")

local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TweenService = game:GetService("TweenService")



local player = Players.LocalPlayer

local screenGui = script.Parent



local Shared = ReplicatedStorage:WaitForChild("Shared")

local MenuEvents = require(Shared:WaitForChild("MenuEvents"))

local Catalog = require(Shared:WaitForChild("CosmeticCatalog"))



local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local TrailShopAction = Remotes:WaitForChild("TrailShopAction")

local TrailShopUpdate = Remotes:WaitForChild("TrailShopUpdate")

local AuraShopAction = Remotes:WaitForChild("AuraShopAction")

local AuraShopUpdate = Remotes:WaitForChild("AuraShopUpdate")



local mainFrame = screenGui:WaitForChild("MainFrame")

local dimOverlay = screenGui:FindFirstChild("Dim")



----------------------------------------------------------------------

-- Open / close (same ready / close-all contract as every other panel)

----------------------------------------------------------------------

local isOpen = false

local currentType = "Trail"

local widgetLists = { Trail = {}, Aura = {} }

local refreshAllLocal = nil



-- Ensure initial closed state on client load

screenGui.Enabled = false



local function requestState(cosmeticType)

	if cosmeticType == "Trail" then

		TrailShopAction:FireServer("RequestState")

	else

		AuraShopAction:FireServer("RequestState")

	end

end



-- Ownership can settle a beat after a buy / equip / market prompt, so every

-- refresh re-requests state twice shortly after the first call. This keeps

-- the EQUIP labels from lagging behind the server's data.

local function refreshNow(cosmeticType)

	requestState(cosmeticType)

	task.delay(0.35, function()

		if player.Parent then requestState(cosmeticType) end

	end)

	task.delay(1.2, function()

		if player.Parent then requestState(cosmeticType) end

	end)

end



local OPEN_POS = UDim2.new(0.5, 0, 0.48, 0)

local CLOSED_POS = UDim2.new(0.5, 0, 1.28, 0)

local openTween = nil

local dimTween = nil

local isClosing = false



local function hide(instant)

	if not isOpen and not screenGui.Enabled then return end



	if instant then

		isClosing = false

		isOpen = false

		if openTween then openTween:Cancel() end

		if dimTween then dimTween:Cancel() end

		screenGui.Enabled = false

		mainFrame.Visible = false

		mainFrame.Position = CLOSED_POS

		if dimOverlay and dimOverlay:IsA("GuiObject") then

			dimOverlay.Visible = false

			dimOverlay.Active = false

			dimOverlay.BackgroundTransparency = 1

		end

		return

	end



	if isClosing then return end

	isClosing = true



	if dimOverlay and dimOverlay:IsA("GuiObject") then

		if dimTween then dimTween:Cancel() end

		dimTween = TweenService:Create(dimOverlay, TweenInfo.new(0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.In), { BackgroundTransparency = 1 })

		dimTween:Play()

	end



	if openTween then openTween:Cancel() end

	openTween = TweenService:Create(mainFrame, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = CLOSED_POS })

	openTween:Play()



	task.delay(0.18, function()

		if not isClosing then return end

		isClosing = false

		isOpen = false

		screenGui.Enabled = false

		mainFrame.Visible = false

		mainFrame.Position = CLOSED_POS

		if dimOverlay and dimOverlay:IsA("GuiObject") then

			dimOverlay.Visible = false

			dimOverlay.Active = false

		end

	end)

end



local function show()

	if isOpen and screenGui.Enabled and not isClosing then return end

	isClosing = false

	isOpen = true

	screenGui.Enabled = true

	mainFrame.Visible = true

	mainFrame.Position = CLOSED_POS



	if dimOverlay and dimOverlay:IsA("GuiObject") then

		dimOverlay.Visible = true

		dimOverlay.Active = true

		dimOverlay.BackgroundTransparency = 1

		if dimTween then dimTween:Cancel() end

		dimTween = TweenService:Create(dimOverlay, TweenInfo.new(0.20, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { BackgroundTransparency = 0.55 })

		dimTween:Play()

	end



	if openTween then openTween:Cancel() end

	openTween = TweenService:Create(mainFrame, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = OPEN_POS })

	openTween:Play()



	if refreshAllLocal then

		refreshAllLocal(currentType)

	end

	refreshNow(currentType)

end



local closeButton = mainFrame:WaitForChild("Close")

closeButton.Activated:Connect(hide)

if closeButton:IsA("GuiButton") then

	closeButton.MouseButton1Click:Connect(hide)

end

closeButton.InputBegan:Connect(function(input)

	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then

		hide()

	end

end)



if dimOverlay and dimOverlay:IsA("GuiObject") then

	dimOverlay.Active = true

	dimOverlay.InputBegan:Connect(function(input)

		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then

			hide()

		end

	end)

end



----------------------------------------------------------------------

-- Tab Images: Trail list first, Aura list hidden until its tab is pressed

----------------------------------------------------------------------

local trailFrame, auraFrame, trailTab, auraTab

for _, child in ipairs(mainFrame:GetChildren()) do

	if child.Name == "Trail" and child:IsA("ScrollingFrame") then

		trailFrame = child

	elseif child.Name == "Aura" and child:IsA("ScrollingFrame") then

		auraFrame = child

	elseif child.Name == "Trail" and child:IsA("ImageButton") then

		trailTab = child

	elseif child.Name == "Aura" and child:IsA("ImageButton") then

		auraTab = child

	end

end



assert(trailFrame and auraFrame and trailTab and auraTab, "Backpack UI layout changed")



local function selectTab(showAura)

	local newType = showAura and "Aura" or "Trail"

	trailFrame.Visible = not showAura

	auraFrame.Visible = showAura

	currentType = newType

	if isOpen then

		if refreshAllLocal then

			refreshAllLocal(currentType)

		end

		refreshNow(currentType)

	end

end



selectTab(false) -- trails first by default



trailTab.Activated:Connect(function() selectTab(false) end)

auraTab.Activated:Connect(function() selectTab(true) end)



MenuEvents.Get("OpenBackpackPanel").Event:Connect(function(action, targetTab)

	if targetTab == "Aura" or targetTab == "Auras" then

		selectTab(true)

	elseif targetTab == "Trail" or targetTab == "Trails" then

		selectTab(false)

	end



	if action == "Open" or action == "LeftButtonSwitch" then

		show()

	elseif action == "Close" then

		hide()

	else

		if isOpen then hide() else show() end

	end

end)



MenuEvents.Get("OpenTrailsPanel").Event:Connect(function(action)

	selectTab(false)

	if action == "Open" or action == "LeftButtonSwitch" then

		show()

	elseif action == "Close" then

		hide()

	else

		if isOpen then hide() else show() end

	end

end)



MenuEvents.Get("OpenAurasPanel").Event:Connect(function(action)

	selectTab(true)

	if action == "Open" or action == "LeftButtonSwitch" then

		show()

	elseif action == "Close" then

		hide()

	else

		if isOpen then hide() else show() end

	end

end)



MenuEvents.CloseAll.Event:Connect(hide)

-- A closing panel counts as closed, so reopening it quickly opens it (MenuEvents).
MenuEvents.MarkReady("Backpack", function() return isOpen and not isClosing end)



----------------------------------------------------------------------

-- Price labels + purchase / equip wiring

----------------------------------------------------------------------

local COLOR_KEYS = { "orange", "red", "purple", "blue", "yellow", "white", "black" }



local function colorKeyOf(text)

	text = string.lower(tostring(text or ""))

	for _, color in ipairs(COLOR_KEYS) do

		if string.find(text, color, 1, true) then

			return color

		end

	end

	return nil

end



-- Map a display color to its catalog entry. Entries whose display name has no

-- color word fall back to their ThemeColor; the only such entry today is the

-- Secret Trail, which is the black one.

local function buildColorMap(cosmeticType)

	local map = {}

	for _, entry in ipairs(Catalog.GetList(cosmeticType)) do

		-- World 3's cosmetics ("Cursed Red") and exclusives get cards of their own
		-- (addCatalogCards); only the original colours own the designer's cards.
		local color = if entry.World == nil and entry.Exclusive == nil then colorKeyOf(entry.DisplayName) else nil

		if not color and entry.World == nil and entry.Exclusive == nil then

			local c = entry.ThemeColor

			if c and c.R <= 0.2 and c.G <= 0.2 and c.B <= 0.2 then

				color = "black"

			end

		end

		if color then

			map[color] = entry

		end

	end

	return map

end



local trailByColor = buildColorMap("Trail")

local auraByColor = buildColorMap("Aura")



local SUFFIXES = { "K", "M", "B", "T", "Qa", "Qi" }

local function formatNumber(value)

	value = tonumber(value) or 0

	if value < 1000 then

		return tostring(math.floor(value))

	end

	local tier = math.floor(math.log10(math.max(1, value)) / 3)

	if tier > #SUFFIXES then tier = #SUFFIXES end

	local scaled = value / (1000 ^ tier)

	if scaled >= 100 then

		return string.format("%.0f%s", scaled, SUFFIXES[tier])

	elseif scaled >= 10 then

		return string.format("%.1f%s", scaled, SUFFIXES[tier])

	end

	return string.format("%.2f%s", scaled, SUFFIXES[tier])

end



-- Same resolution as the old shop panels: DevProducts use their configured

-- price, GamePass / "Auto" items fetch the live price first. "Auto" falls

-- back to GamePass (the only "Auto" entry today is the Blue Trail GamePass).

local function resolveRobux(entry)

	local purchaseId = tonumber(entry.RobuxPurchaseId)

	if not purchaseId or purchaseId <= 0 then

		return "None", nil, nil

	end



	local requested = tostring(entry.RobuxPurchaseType or "Auto")

	local configuredPrice = tonumber(entry.RobuxPrice)



	if requested == "GamePass" or purchaseId < 3000000000 then

		local ok, info = pcall(function()

			return MarketplaceService:GetProductInfo(purchaseId, Enum.InfoType.GamePass)

		end)

		local livePrice = ok and info and tonumber(info.UserBasePriceInRobux or info.BasePriceInRobux or info.OriginalPrice or info.PriceInRobux)

		return "GamePass", livePrice or configuredPrice, purchaseId

	end



	if requested == "DeveloperProduct" then

		return "DeveloperProduct", configuredPrice, purchaseId

	end



	-- "Auto": GamePass first, DevProduct second, GamePass as final fallback.

	local passOk, passInfo = pcall(function()

		return MarketplaceService:GetProductInfo(purchaseId, Enum.InfoType.GamePass)

	end)

	local livePassPrice = passOk and passInfo and tonumber(passInfo.UserBasePriceInRobux or passInfo.BasePriceInRobux or passInfo.OriginalPrice or passInfo.PriceInRobux)

	if livePassPrice then

		return "GamePass", livePassPrice, purchaseId

	end

	local productOk, productInfo = pcall(function()

		return MarketplaceService:GetProductInfo(purchaseId, Enum.InfoType.Product)

	end)

	local liveProdPrice = productOk and productInfo and tonumber(productInfo.UserBasePriceInRobux or productInfo.BasePriceInRobux or productInfo.OriginalPrice or productInfo.PriceInRobux)

	if liveProdPrice then

		return "DeveloperProduct", liveProdPrice, purchaseId

	end

	return "DeveloperProduct", configuredPrice, purchaseId

end



local function resolveRobuxAsync(entry, callback)

	task.spawn(function()

		local pType, price, pId = resolveRobux(entry)

		if callback then

			callback(pType, price, pId)

		end

	end)

end



local function isFolderOwned(cosmeticType, id)

	local dataFolder = player:FindFirstChild("SpeedsterData")

	if dataFolder then

		local folderName = cosmeticType == "Trail" and "OwnedTrails" or "OwnedAuras"

		local folder = dataFolder:FindFirstChild(folderName)

		if folder then

			local val = folder:FindFirstChild(id)

			if val and val:IsA("BoolValue") and val.Value == true then

				return true

			end

		end

	end

	return false

end



local function getEquippedId(cosmeticType)
	local attrName = cosmeticType == "Trail" and "EquippedTrailId" or "EquippedAuraId"
	local attr = player:GetAttribute(attrName)
	if attr ~= nil then
		return tostring(attr)
	end

	local dataFolder = player:FindFirstChild("SpeedsterData")
	if dataFolder then
		local valName = cosmeticType == "Trail" and "EquippedTrail" or "EquippedAura"
		local val = dataFolder:FindFirstChild(valName)
		if val and val:IsA("StringValue") then
			return val.Value
		end
	end

	return ""
end



local function isItemOwned(item)

	return item.owned == true or isFolderOwned(item.cosmeticType, item.entry.Id)

end



local function refreshItem(item)

	local owned = isItemOwned(item)

	item.owned = owned



	if owned then

		local actionText = item.equipped and "EQUIPPED" or "EQUIP"

		if item.winsButton then

			item.winsButton.Visible = true

			item.winsButton.Position = UDim2.new(1.3322505, 0, 0.5, 0)

		end

		if item.winsIcon then

			item.winsIcon.Visible = false

		end

		if item.winsLabel then

			item.winsLabel.Text = actionText

		end

		if item.robuxButton then

			item.robuxButton.Visible = false

		end

	else

		if item.winsButton then

			item.winsButton.Visible = true

			if item.winsOriginalPos then

				item.winsButton.Position = item.winsOriginalPos

			end

		end

		if item.winsIcon then

			-- An exclusive's button names where it is won, with no Wins icon.
			item.winsIcon.Visible = item.exclusiveMenu == nil

		end

		if item.winsLabel then

			item.winsLabel.Text = item.winsPriceText

		end

		if item.robuxButton then

			item.robuxButton.Visible = item.robuxShown ~= false

			if item.robuxOriginalPos then

				item.robuxButton.Position = item.robuxOriginalPos

			end

		end

		if item.robuxIcon then

			item.robuxIcon.Visible = true

		end

		if item.robuxLabel then

			item.robuxLabel.Text = item.robuxPriceText

		end

	end

end



refreshAllLocal = function(cosmeticType)

	local equippedId = getEquippedId(cosmeticType)

	for _, it in ipairs(widgetLists[cosmeticType] or {}) do

		it.owned = isFolderOwned(cosmeticType, it.entry.Id) or it.owned

		it.equipped = (it.entry.Id == equippedId)

		refreshItem(it)

	end

end



local function toggleEquip(item)

	local action = item.cosmeticType == "Trail" and TrailShopAction or AuraShopAction

	if item.equipped then

		action:FireServer("Unequip", item.entry.Id)

		item.equipped = false

		refreshItem(item)

	else

		action:FireServer("Equip", item.entry.Id)

		for _, other in ipairs(widgetLists[item.cosmeticType] or {}) do

			if other ~= item and other.equipped then

				other.equipped = false

				refreshItem(other)

			end

		end

		item.equipped = true

		refreshItem(item)

	end

	refreshNow(item.cosmeticType)

end



local function formatMultiplier(value)
	value = tonumber(value) or 1
	if value % 1 == 0 then
		return "x" .. tostring(math.floor(value))
	end
	local text = string.format("%.2f", value)
	text = (text:gsub("0+$", ""))
	text = (text:gsub("%.$", ""))
	return "x" .. text
end

-- The card's own UIAspectRatioConstraint is the designer's shape for it. The
-- authored height (0.1517 of the scroll window) is much shorter than that shape
-- needs, so FitWithinMaxSize was solving for height and drawing every card at
-- roughly a third of its width - the squashed menu players reported. Releasing
-- the height lets the constraint solve on width instead, which reproduces the
-- authored card. No size is picked here; the designer's constraint still decides.
local function releaseAuthoredCardHeight(itemFrame)
	local constraint = itemFrame:FindFirstChildOfClass("UIAspectRatioConstraint")
	if not constraint or constraint.AspectType ~= Enum.AspectType.FitWithinMaxSize then
		return
	end
	local size = itemFrame.Size
	if size.Y.Scale >= 1 and size.Y.Offset == 0 then
		return
	end
	itemFrame.Size = UDim2.new(size.X.Scale, size.X.Offset, 1, 0)
end

-- A card shows its name above its speed multiplier. The authored multiplier text
-- has drifted from the catalog (Blue reads "x10 Speed" while the catalog grants
-- x25), so the catalog - the value the server actually applies - fills it in.
local function applyMultiplierLabel(itemFrame, entry)
	local multiplier = tonumber(entry.SpeedMultiplier)
	if not multiplier then
		return
	end
	local lowest = nil
	for _, child in ipairs(itemFrame:GetChildren()) do
		if child:IsA("TextLabel") then
			if not lowest or child.Position.Y.Scale > lowest.Position.Y.Scale then
				lowest = child
			end
		end
	end
	if lowest and string.find(string.lower(lowest.Text), "speed", 1, true) then
		lowest.Text = formatMultiplier(multiplier) .. " Speed"
	end
end

local function wireSingleItem(itemFrame, entry, cosmeticType)
	itemFrame.LayoutOrder = tonumber(entry.SortOrder) or 100
	releaseAuthoredCardHeight(itemFrame)
	applyMultiplierLabel(itemFrame, entry)

	local winsButton, robuxButton, winsLabel, robuxLabel

	for _, child in ipairs(itemFrame:GetDescendants()) do
		if child:IsA("ImageButton") or child:IsA("TextButton") then
			if child.Name == "WinsPurchase" or child.Name == "Wins" then
				winsButton = child
				winsLabel = child:FindFirstChild("Name")
			elseif child.Name == "RobuxPurchase" then
				robuxButton = child
				robuxLabel = child:FindFirstChild("Name")
			end
		end
	end

	-- Fallback for Robux button without standard name
	if not robuxButton then
		for _, child in ipairs(itemFrame:GetDescendants()) do
			if child:IsA("ImageButton")
				and child.Name ~= "WinsPurchase" and child.Name ~= "Wins"
				and (child.Name == "ImageButton" or child.Name == "Robux")
				and child:FindFirstChild("Name")
			then
				robuxButton = child
				robuxLabel = child:FindFirstChild("Name")
				break
			end
		end
	end

	if winsLabel then
		winsLabel.Text = formatNumber(tonumber(entry.WinsCost) or 0)
	end

	local function formatRobuxSaleText(currentPrice, originalPrice)
		currentPrice = tonumber(currentPrice) or 0
		originalPrice = tonumber(originalPrice) or 0
		if originalPrice > currentPrice and currentPrice > 0 then
			return string.format('<s><font color="#FF7B7B">%d</font></s> <font color="#55FF77">%d</font>', math.floor(originalPrice), math.floor(currentPrice))
		elseif currentPrice > 0 then
			return tostring(math.floor(currentPrice))
		end
		return ""
	end

	local hasRobux = tonumber(entry.RobuxPurchaseId) and tonumber(entry.RobuxPurchaseId) > 0
	-- A Robux price set before its developer product exists (World 3's, 2026-09-18): the
	-- button shows the price and says "Soon!" when pressed.
	local robuxSoon = not hasRobux and entry.Exclusive == nil and (tonumber(entry.RobuxPrice) or 0) > 0
	if robuxLabel then
		robuxLabel.RichText = true
		local original = tonumber(entry.OriginalRobuxPrice)
		local current = tonumber(entry.RobuxPrice)
		if robuxSoon then
			robuxLabel.Text = formatRobuxSaleText(current, original)
		elseif hasRobux then
			robuxLabel.Text = if current and math.floor(current) > 0
				then formatRobuxSaleText(current, original)
				else "..."
		else
			robuxLabel.Text = ""
		end
	end

	local winsIcon = winsButton and winsButton:FindFirstChildOfClass("ImageLabel")
	local robuxIcon = robuxButton and robuxButton:FindFirstChildOfClass("ImageLabel")

	local item = {
		cosmeticType = cosmeticType,
		entry = entry,
		winsButton = winsButton,
		robuxButton = robuxButton,
		winsLabel = winsLabel,
		robuxLabel = robuxLabel,
		winsIcon = winsIcon,
		robuxIcon = robuxIcon,
		winsOriginalPos = winsButton and winsButton.Position,
		robuxOriginalPos = robuxButton and robuxButton.Position,
		winsPriceText = winsLabel and winsLabel.Text or "",
		robuxPriceText = robuxLabel and robuxLabel.Text or "",
		owned = false,
		equipped = false,
		robuxShown = hasRobux or robuxSoon,
	}

	-- Items without a Robux purchase hide the Robux button and center the Wins button
	if not item.robuxShown then
		if robuxButton then
			robuxButton.Visible = false
		end
		if winsButton then
			winsButton.Position = UDim2.new(1.3322505, 0, 0.5, 0)
			item.winsOriginalPos = winsButton.Position
		end
	end

	table.insert(widgetLists[cosmeticType], item)

	if hasRobux then
		-- Known without a web call, so a click works from the first frame; the async
		-- lookup only refines it.
		local catalogId = tonumber(entry.RobuxPurchaseId)
		local declaredType = tostring(entry.RobuxPurchaseType or "Auto")
		item.robuxPurchaseId = catalogId
		item.robuxPurchaseType = if declaredType == "GamePass" or declaredType == "DeveloperProduct"
			then declaredType
			elseif catalogId < 3000000000 then "GamePass"
			else "DeveloperProduct"

		resolveRobuxAsync(entry, function(purchaseType, livePrice, purchaseId)
			if purchaseType and purchaseId then
				item.robuxPurchaseType = purchaseType
				item.robuxPurchaseId = purchaseId
			end
			if livePrice and livePrice > 0 then
				local priceStr = tostring(math.floor(livePrice))
				item.robuxPriceText = priceStr
				if item.robuxLabel and item.robuxLabel.Parent and not item.owned then
					item.robuxLabel.Text = priceStr
				end
			end
		end)
	end

	if winsButton then
		winsButton.Activated:Connect(function()
			if isItemOwned(item) then
				toggleEquip(item)
			elseif item.exclusiveMenu then
				MenuEvents.Request(item.exclusiveMenu)
			else
				local action = cosmeticType == "Trail" and TrailShopAction or AuraShopAction
				action:FireServer("Buy", entry.Id)
				refreshNow(cosmeticType)
			end
		end)
	end

	if robuxButton and robuxSoon then
		local soonToken = 0
		robuxButton.Activated:Connect(function()
			if isItemOwned(item) then
				toggleEquip(item)
				return
			end
			soonToken += 1
			local token = soonToken
			if item.robuxLabel then
				item.robuxLabel.Text = "Soon!"
			end
			task.delay(1.2, function()
				if token == soonToken and item.robuxLabel and item.robuxLabel.Parent and not item.owned then
					item.robuxLabel.Text = item.robuxPriceText
				end
			end)
		end)
	end

	if robuxButton and hasRobux then
		robuxButton.Activated:Connect(function()
			if isItemOwned(item) then
				toggleEquip(item)
				return
			end
			local purchaseId = tonumber(item.robuxPurchaseId)
			local purchaseType = item.robuxPurchaseType
			if not purchaseId or purchaseId <= 0 then return end
			local isGamePass = purchaseType == "GamePass" or purchaseId < 3000000000
			local ok, err = pcall(function()
				if isGamePass then
					MarketplaceService:PromptGamePassPurchase(player, purchaseId)
				else
					MarketplaceService:PromptProductPurchase(player, purchaseId)
				end
			end)
			if not ok then
				warn("[BackpackScript] Robux prompt failed for " .. tostring(entry.DisplayName) .. ": " .. tostring(err))
			end
		end)
	end

	itemFrame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if isItemOwned(item) then
				toggleEquip(item)
			end
		end
	end)
end

local function wireItemList(container, cosmeticType, colorMap)
	for _, itemFrame in ipairs(container:GetChildren()) do
		if itemFrame:IsA("Frame") then
			-- Identify this item's color from its display-name label text.
			local displayText = nil
			for _, label in ipairs(itemFrame:GetChildren()) do
				if label:IsA("TextLabel") and not displayText then
					displayText = label.Text
				end
			end

			local isExperimental = false
			if displayText then
				local lowerText = string.lower(displayText)
				if string.find(lowerText, "demon")
					or string.find(lowerText, "galax")
					or string.find(lowerText, "music")
					or string.find(lowerText, "shadow")
					or string.find(lowerText, "cursed")
					or string.find(lowerText, "aquatic")
					or string.find(lowerText, "shidou")
					or string.find(lowerText, "doodle")
				then
					isExperimental = true
				end
			end

			local entry = not isExperimental and colorMap[colorKeyOf(displayText)] or nil
			if entry then
				wireSingleItem(itemFrame, entry, cosmeticType)
			else
				itemFrame.Visible = false
			end
		end
	end
end



-- The designer drew one card per original colour. Everything else the Backpack sells or
-- holds (World 3's cosmetics, the Spin Wheel's exclusives) gets a copy of the Purple
-- card, painted from the catalog: its colours, its name, its multiplier and, when the
-- catalog has one, its picture.
local EXCLUSIVE_LABELS = { SpinWheel = "SPIN WHEEL" }
local EXCLUSIVE_MENUS = { SpinWheel = "SpinWheel" }

local function cardTemplate(container)
	local fallback = nil
	for _, frame in ipairs(container:GetChildren()) do
		if frame:IsA("Frame") and frame:FindFirstChild("WinsPurchase", true) then
			local text = ""
			for _, label in ipairs(frame:GetChildren()) do
				if label:IsA("TextLabel") then
					text ..= string.lower(label.Text)
				end
			end
			if string.find(text, "purple", 1, true) then
				return frame
			end
			fallback = fallback or frame
		end
	end
	return fallback
end

local function paintCard(card, entry)
	local theme = entry.ThemeColor or Color3.fromRGB(176, 93, 255)
	local titleLabel = nil
	for _, child in ipairs(card:GetChildren()) do
		if child:IsA("TextLabel") and not string.find(string.lower(child.Text), "speed", 1, true) then
			titleLabel = child
		elseif child:IsA("ImageLabel") then
			-- The card's coloured backing and its inner rim.
			child.BackgroundColor3 = theme
			for _, stroke in ipairs(child:GetChildren()) do
				if stroke:IsA("UIStroke") and stroke.Color ~= Color3.new(0, 0, 0) then
					stroke.Color = theme:Lerp(Color3.new(1, 1, 1), 0.45)
				end
			end
		end
	end
	if titleLabel then
		titleLabel.Text = entry.DisplayName
	end
	if entry.CardIcon then
		for _, image in ipairs(card:GetDescendants()) do
			if image:IsA("ImageLabel") and image.Parent and image.Parent:IsA("Frame") and image.Parent ~= card then
				image.Image = entry.CardIcon
				image.ScaleType = Enum.ScaleType.Fit
			end
		end
	end

	local original = tonumber(entry.OriginalRobuxPrice)
	local current = tonumber(entry.RobuxPrice)
	if original and current and original > current then
		local discountPct = math.round((1 - current / original) * 100)
		local saleBadge = card:FindFirstChild("SaleBadge")
		if not saleBadge then
			-- Sized with the card and pinned to its top-left corner, over the picture: a
			-- fixed 70x18 px tag on the top-right covered the Wins button on phones, where
			-- that button is only about 35x11 px.
			saleBadge = Instance.new("TextLabel")
			saleBadge.Name = "SaleBadge"
			saleBadge.AnchorPoint = Vector2.new(0, 0)
			saleBadge.Size = UDim2.new(0.17, 0, 0.24, 0)
			saleBadge.Position = UDim2.new(0.012, 0, 0.06, 0)
			saleBadge.BackgroundColor3 = Color3.fromRGB(220, 35, 60)
			saleBadge.TextColor3 = Color3.fromRGB(255, 255, 255)
			saleBadge.Font = Enum.Font.FredokaOne or Enum.Font.GothamBold
			saleBadge.TextScaled = true
			saleBadge.Active = false
			saleBadge.ZIndex = 25
			local sizeLimit = Instance.new("UITextSizeConstraint")
			sizeLimit.MinTextSize = 6
			sizeLimit.MaxTextSize = 16
			sizeLimit.Parent = saleBadge
			local padding = Instance.new("UIPadding")
			padding.PaddingLeft = UDim.new(0.06, 0)
			padding.PaddingRight = UDim.new(0.06, 0)
			padding.Parent = saleBadge
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 5)
			corner.Parent = saleBadge
			local stroke = Instance.new("UIStroke")
			stroke.Color = Color3.fromRGB(255, 255, 255)
			stroke.Thickness = 1
			stroke.Parent = saleBadge
			saleBadge.Parent = card
		end
		saleBadge.Text = "SALE -" .. discountPct .. "%"
		saleBadge.Visible = true
	end
end

local function addCatalogCards(container, cosmeticType)
	local template = cardTemplate(container)
	if not template then
		return
	end
	local wired = {}
	for _, item in ipairs(widgetLists[cosmeticType]) do
		wired[item.entry.Id] = true
	end
	local cards = #widgetLists[cosmeticType]
	for _, entry in ipairs(Catalog.GetSortedOwnableEntries(cosmeticType)) do
		if not wired[entry.Id] then
			local card = template:Clone()
			card.Name = entry.Id
			card.Visible = true
			paintCard(card, entry)
			card.Parent = container
			wireSingleItem(card, entry, cosmeticType)
			cards += 1
			local item = widgetLists[cosmeticType][#widgetLists[cosmeticType]]
			if entry.Exclusive and item and item.entry == entry then
				-- Never sold: until it is won, the button says where it comes from.
				item.winsPriceText = EXCLUSIVE_LABELS[entry.Exclusive] or "EXCLUSIVE"
				item.exclusiveMenu = EXCLUSIVE_MENUS[entry.Exclusive]
				if item.winsIcon then
					item.winsIcon.Visible = false
				end
				refreshItem(item)
			end
		end
	end
	-- The designer's canvas and gaps were sized for seven cards; keep the same gap
	-- (in pixels) and grow the canvas with the list.
	local layout = container:FindFirstChildOfClass("UIListLayout")
	if container:IsA("ScrollingFrame") and cards > 7 then
		local canvas = container.CanvasSize.Y.Scale
		local grown = canvas * cards / 7
		container.CanvasSize = UDim2.new(container.CanvasSize.X.Scale, container.CanvasSize.X.Offset, grown, container.CanvasSize.Y.Offset)
		if layout and layout.Padding.Scale > 0 then
			layout.Padding = UDim.new(layout.Padding.Scale * canvas / grown, layout.Padding.Offset)
		end
	end
end

-- Phones (2026-09-18, Sung: "way too big on screen", "better overscaling for evt to fit in"):
-- drawn at PHONE_CARD_SCALE (reduced ~28% from authored size) so 3-4 cards show at once in
-- the list. Since 2026-09-19 the panel itself is bigger on phones (PHONE_PANEL_SIZE): at its
-- authored 32% x 59% of the screen its Wins and Robux buttons came out about 35x11 px.
local PHONE_CARD_SCALE = 0.72
local PHONE_PANEL_SIZE = UDim2.fromScale(0.95, 0.8)
local function isPhone()
	local UserInputService = game:GetService("UserInputService")
	local camera = workspace.CurrentCamera
	local view = camera and camera.ViewportSize or Vector2.new(1280, 720)
	local touch, keyboard = UserInputService.TouchEnabled, UserInputService.KeyboardEnabled
	return (touch and not keyboard) or (touch and (view.Y <= 680 or view.X <= 960)) or (view.Y <= 540)
end

local function fitCardsForPhones(container)
	if not container or not container:IsA("ScrollingFrame") or container:GetAttribute("PhoneCardScale") or not isPhone() then
		return
	end
	container:SetAttribute("PhoneCardScale", PHONE_CARD_SCALE)
	for _, card in ipairs(container:GetChildren()) do
		if card:IsA("Frame") and (card:FindFirstChild("WinsPurchase", true) or card:FindFirstChild("Wins", true)) then
			local size = card.Size
			card.Size = UDim2.new(size.X.Scale * PHONE_CARD_SCALE, size.X.Offset, size.Y.Scale, size.Y.Offset)
		end
	end
	local layout = container:FindFirstChildOfClass("UIListLayout")
	if layout then
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	end
	local canvas = container.CanvasSize
	container.CanvasSize = UDim2.new(canvas.X.Scale, canvas.X.Offset, canvas.Y.Scale * PHONE_CARD_SCALE, canvas.Y.Offset)
end

local function applyState(cosmeticType, payload)

	if type(payload) ~= "table" then return end

	local listKey = cosmeticType == "Trail" and "Trails" or "Auras"

	local ownedMap = payload.Owned or {}

	local equippedId = cosmeticType == "Trail" and (payload.EquippedTrail or "") or (payload.EquippedAura or "")

	if equippedId == "" then

		equippedId = getEquippedId(cosmeticType)

	end

	local byId = {}

	for _, item in ipairs(widgetLists[cosmeticType]) do

		byId[item.entry.Id] = item

	end

	for _, entry in ipairs(payload[listKey] or {}) do

		local item = byId[tostring(entry.Id or "")]

		if item then

			item.owned = (ownedMap[item.entry.Id] == true) or isFolderOwned(cosmeticType, item.entry.Id)

			item.equipped = (item.entry.Id == equippedId)

			refreshItem(item)

		end

	end

	refreshAllLocal(cosmeticType)

end



TrailShopUpdate.OnClientEvent:Connect(function(payload) applyState("Trail", payload) end)

AuraShopUpdate.OnClientEvent:Connect(function(payload) applyState("Aura", payload) end)



local function hookBackpackDataFolder(data)

	if not data then return end

	local function listenFolder(folderName, cosmeticType)

		local folder = data:FindFirstChild(folderName)

		if folder then

			local function onValue(val)

				if val:IsA("BoolValue") then

					val.Changed:Connect(function()

						refreshAllLocal(cosmeticType)

						refreshNow(cosmeticType)

					end)

				end

			end

			folder.ChildAdded:Connect(function(child)

				onValue(child)

				refreshAllLocal(cosmeticType)

				refreshNow(cosmeticType)

			end)

			for _, child in ipairs(folder:GetChildren()) do

				onValue(child)

			end

		end

	end

	listenFolder("OwnedTrails", "Trail")

	listenFolder("OwnedAuras", "Aura")



	local function hookEquippedVal(valName, cosmeticType)

		local val = data:FindFirstChild(valName)

		if val and val:IsA("StringValue") then

			val.Changed:Connect(function()

				refreshAllLocal(cosmeticType)

			end)

		end

	end

	hookEquippedVal("EquippedTrail", "Trail")

	hookEquippedVal("EquippedAura", "Aura")



	data.ChildAdded:Connect(function(child)

		if child.Name == "OwnedTrails" then

			listenFolder("OwnedTrails", "Trail")

			refreshAllLocal("Trail")

			refreshNow("Trail")

		elseif child.Name == "OwnedAuras" then

			listenFolder("OwnedAuras", "Aura")

			refreshAllLocal("Aura")

			refreshNow("Aura")

		elseif child.Name == "EquippedTrail" and child:IsA("StringValue") then

			child.Changed:Connect(function() refreshAllLocal("Trail") end)

			refreshAllLocal("Trail")

		elseif child.Name == "EquippedAura" and child:IsA("StringValue") then

			child.Changed:Connect(function() refreshAllLocal("Aura") end)

			refreshAllLocal("Aura")

		end

	end)

end



local dataFolder = player:FindFirstChild("SpeedsterData")

if dataFolder then

	hookBackpackDataFolder(dataFolder)

else

	player.ChildAdded:Connect(function(child)

		if child.Name == "SpeedsterData" then

			hookBackpackDataFolder(child)

		end

	end)

end



player:GetAttributeChangedSignal("EquippedTrailId"):Connect(function()

	refreshAllLocal("Trail")

end)



player:GetAttributeChangedSignal("EquippedAuraId"):Connect(function()

	refreshAllLocal("Aura")

end)



local function onRobuxPurchased(purchaseId)

	purchaseId = tonumber(purchaseId)

	if not purchaseId then return end



	for _, cosmeticType in ipairs({"Trail", "Aura"}) do

		for _, it in ipairs(widgetLists[cosmeticType] or {}) do

			local pid = tonumber(it.entry.RobuxPurchaseId)

			if pid and pid == purchaseId then

				it.owned = true

				it.equipped = true

				for _, other in ipairs(widgetLists[cosmeticType] or {}) do

					if other ~= it and other.equipped then

						other.equipped = false

						refreshItem(other)

					end

				end

				refreshItem(it)

				local action = cosmeticType == "Trail" and TrailShopAction or AuraShopAction

				action:FireServer("Equip", it.entry.Id)

				break

			end

		end

	end



	task.delay(0.2, function()

		refreshAllLocal("Trail")

		refreshAllLocal("Aura")

		refreshNow("Trail")

		refreshNow("Aura")

	end)

	task.delay(1.0, function()

		refreshAllLocal("Trail")

		refreshAllLocal("Aura")

		refreshNow("Trail")

		refreshNow("Aura")

	end)

end



MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(purchaser, passId, wasPurchased)

	if purchaser == player and wasPurchased then

		onRobuxPurchased(passId)

	end

end)



MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, wasPurchased)

	if userId == player.UserId and wasPurchased then

		onRobuxPurchased(productId)

	end

end)



MarketplaceService.PromptPurchaseFinished:Connect(function(purchaser, assetId, isPurchased)

	if purchaser == player and isPurchased then

		onRobuxPurchased(assetId)

	end

end)



wireItemList(trailFrame, "Trail", trailByColor)

wireItemList(auraFrame, "Aura", auraByColor)

addCatalogCards(trailFrame, "Trail")

addCatalogCards(auraFrame, "Aura")

fitCardsForPhones(trailFrame)

fitCardsForPhones(auraFrame)

-- Phones: the whole panel larger (its UIAspectRatioConstraint keeps the designer's shape),
-- followed as the screen turns or resizes; other screens keep the authored size.
local authoredPanelSize = mainFrame.Size
local function fitPanelForPhones()
	mainFrame.Size = if isPhone() then PHONE_PANEL_SIZE else authoredPanelSize
end
fitPanelForPhones()
local watchedPanelCamera = nil
local function watchPanelCamera()
	local camera = workspace.CurrentCamera
	if camera and camera ~= watchedPanelCamera then
		watchedPanelCamera = camera
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(fitPanelForPhones)
		fitPanelForPhones()
	end
end
watchPanelCamera()
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchPanelCamera)



-- Pre-fetch ownership for both tabs so the panel already shows EQUIP the

-- first time it is opened (no visible buy-button flash).

refreshAllLocal("Trail")

refreshAllLocal("Aura")

refreshNow("Trail")

refreshNow("Aura")



print("[BackpackScript] Loaded")

