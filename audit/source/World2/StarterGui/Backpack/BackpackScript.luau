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

MenuEvents.MarkReady("Backpack", function() return isOpen end)



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

		local color = colorKeyOf(entry.DisplayName)

		if not color then

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

		return "GamePass", (ok and info and tonumber(info.PriceInRobux)) or configuredPrice, purchaseId

	end



	if requested == "DeveloperProduct" then

		return "DeveloperProduct", configuredPrice, purchaseId

	end



	-- "Auto": GamePass first, DevProduct second, GamePass as final fallback.

	local passOk, passInfo = pcall(function()

		return MarketplaceService:GetProductInfo(purchaseId, Enum.InfoType.GamePass)

	end)

	if passOk and passInfo and tonumber(passInfo.PriceInRobux) then

		return "GamePass", tonumber(passInfo.PriceInRobux), purchaseId

	end

	local productOk, productInfo = pcall(function()

		return MarketplaceService:GetProductInfo(purchaseId, Enum.InfoType.Product)

	end)

	if productOk and productInfo and tonumber(productInfo.PriceInRobux) then

		return "DeveloperProduct", tonumber(productInfo.PriceInRobux), purchaseId

	end

	return "DeveloperProduct", configuredPrice, purchaseId

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

	local dataFolder = player:FindFirstChild("SpeedsterData")

	if dataFolder then

		local valName = cosmeticType == "Trail" and "EquippedTrail" or "EquippedAura"

		local val = dataFolder:FindFirstChild(valName)

		if val and val:IsA("StringValue") and val.Value ~= "" then

			return val.Value

		end

	end

	local attrName = cosmeticType == "Trail" and "EquippedTrailId" or "EquippedAuraId"

	local attr = player:GetAttribute(attrName)

	if attr and attr ~= "" then

		return attr

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

			item.winsIcon.Visible = true

		end

		if item.winsLabel then

			item.winsLabel.Text = item.winsPriceText

		end

		if item.robuxButton then

			item.robuxButton.Visible = true

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



			local entry = colorMap[colorKeyOf(displayText)]

			if entry then

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



				-- The Aura White card's Robux button kept its default name

				-- ("ImageButton") - match it by its Name label when no proper

				-- RobuxPurchase button was found.

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

				if robuxLabel then

					local _, price = resolveRobux(entry)

					if price and math.floor(price) > 0 then

						robuxLabel.Text = tostring(math.floor(price))

					else

						robuxLabel.Text = "??"

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

				}

				table.insert(widgetLists[cosmeticType], item)

				resolveRobuxAsync(entry, function(purchaseType, livePrice, purchaseId)
					if livePrice and livePrice > 0 then
						local priceStr = tostring(math.floor(livePrice))
						item.robuxPriceText = priceStr
						if item.robuxLabel and item.robuxLabel.Parent and not item.owned then
							item.robuxLabel.Text = priceStr
						end
					end
				end)



				if winsButton then

					winsButton.Activated:Connect(function()

						if isItemOwned(item) then

							toggleEquip(item)

						else

							local action = cosmeticType == "Trail" and TrailShopAction or AuraShopAction

							action:FireServer("Buy", entry.Id)

							refreshNow(cosmeticType)

						end

					end)

				end

				if robuxButton then

					local purchaseType, _, purchaseId = resolveRobux(entry)

					robuxButton.Activated:Connect(function()

						if isItemOwned(item) then

							toggleEquip(item)

							return

						end

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

		end

	end

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



-- Pre-fetch ownership for both tabs so the panel already shows EQUIP the

-- first time it is opened (no visible buy-button flash).

refreshAllLocal("Trail")

refreshAllLocal("Aura")

refreshNow("Trail")

refreshNow("Aura")



print("[BackpackScript] Loaded")

