local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local GuiService = game:GetService("GuiService")

local LocalPlayer = Players.LocalPlayer
local player = LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local MenuEvents = require(ReplicatedStorage.Shared:WaitForChild("MenuEvents"))
local Config = require(ReplicatedStorage.Shared:WaitForChild("Config"))
local PurchaseButtonSound = require(ReplicatedStorage.Shared:WaitForChild("PurchaseButtonSound"))
local MenuPanelLayout = require(ReplicatedStorage.Shared:WaitForChild("MenuPanelLayout"))
local U4 = require(ReplicatedStorage.Shared:WaitForChild("Update4Config"))
-- 2026-09-26 (owner): the canvas follows the content, and console / gamepad navigation.
local ShopCanvasFlow = require(ReplicatedStorage.Shared:WaitForChild("ShopCanvasFlow"))
local ConsolePanelSupport = require(ReplicatedStorage.Shared:WaitForChild("ConsolePanelSupport"))

local ShopGui = PlayerGui:WaitForChild("Shop")
local ShopFrame = ShopGui:WaitForChild("Shop")
local CloseBtn = ShopFrame:WaitForChild("Close")
local ScrollFrame = ShopFrame:WaitForChild("ScrollingFrame")

local sidebarHolder = ShopGui:WaitForChild("Listbutton")
local Sidebar = sidebarHolder:WaitForChild("Frame")
local GiftFrame = ShopGui:WaitForChild("Gift")

-- 2026-09-26 (owner/QA): the "2X Stamina" card was drawn over the "Treadmills" header and under
-- the Treadmill Valentine card (screenshot). The designer placed every section of the Shop in
-- scale of the canvas and left the Passes list ("Pass", a UIListLayout) room for their own four
-- cards only; the card the build adds there ran past that room. The designer's layout is captured
-- here, once, before anything is changed, and Shared/ShopCanvasFlow replans it (reflowCanvas
-- below) whenever the list's content, a card's visibility or the window's size changes: the
-- sections under the list move down by the added cards, the canvas ends just under the last
-- content (it trailed 2.3 windows of nothing), every piece keeps its pixels.
local PassList = ScrollFrame:WaitForChild("Pass", 10)
local passLayout = PassList and PassList:FindFirstChildOfClass("UIListLayout")

local function captureAuthoredCanvas()
	if not (PassList and passLayout) then
		return nil
	end
	local authored = { CanvasScale = ScrollFrame.CanvasSize.Y.Scale, ListScale = PassList.Position.Y.Scale, Items = {} }
	for _, child in ScrollFrame:GetChildren() do
		if child:IsA("GuiObject") then
			authored.Items[child] = {
				Scale = child.Position.Y.Scale,
				Offset = child.Position.Y.Offset,
				SizeScale = child.Size.Y.Scale,
				Anchor = child.AnchorPoint.Y,
				List = child == PassList,
			}
		end
	end
	return authored
end
local authoredCanvas = captureAuthoredCanvas()

-- The Shop's tabs (the sidebar's buttons and the headers in the canvas), top to bottom, and the
-- one the player is on (the bumpers step from it; the Gamepad section below).
local SHOP_CATEGORIES = { "Exclusive", "Server", "Passes", "Treadmills", "Potions", "Codes" }
local currentCategory = 1

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

-- Phones: the designer's windows are drawn bigger on compact touch screens, centred under the
-- top bar and slid in from wholly below the screen (MenuPanelLayout.BindPhoneFit). The
-- category bar grows by the Shop window's factor, and so does its distance from the window's
-- centre: it keeps its place and its gap against the window's left edge, and both must fit
-- across the screen. The Gift window, shown on its own, gets its own fit.
local SHOP_AUTHORED_POS = SHOP_OPEN_POS
local SIDE_AUTHORED_POS, SIDE_AUTHORED_SIZE = SIDE_OPEN_POS, sidebarHolder.Size
local sidebarShape = sidebarHolder:FindFirstChildOfClass("UIAspectRatioConstraint")
MenuPanelLayout.BindPhoneFit(ShopGui, ShopFrame, SHOP_OPEN_POS, SHOP_CLOSED_POS, function(fit)
	local grow = fit.Grow
	local staleBar = SIDE_OPEN_POS
	SHOP_OPEN_POS, SHOP_CLOSED_POS = fit.Open, fit.Closed
	sidebarHolder.Size = UDim2.new(SIDE_AUTHORED_SIZE.X.Scale * grow, SIDE_AUTHORED_SIZE.X.Offset * grow, SIDE_AUTHORED_SIZE.Y.Scale * grow, SIDE_AUTHORED_SIZE.Y.Offset * grow)
	if fit.OpenY then
		SIDE_OPEN_POS = UDim2.new(
			fit.Open.X.Scale + (SIDE_AUTHORED_POS.X.Scale - SHOP_AUTHORED_POS.X.Scale) * grow,
			fit.Open.X.Offset + (SIDE_AUTHORED_POS.X.Offset - SHOP_AUTHORED_POS.X.Offset) * grow,
			fit.Open.Y.Scale + (SIDE_AUTHORED_POS.Y.Scale - SHOP_AUTHORED_POS.Y.Scale) * grow,
			fit.Open.Y.Offset + (SIDE_AUTHORED_POS.Y.Offset - SHOP_AUTHORED_POS.Y.Offset) * grow
		)
		SIDE_CLOSED_POS = UDim2.new(SIDE_OPEN_POS.X.Scale, SIDE_OPEN_POS.X.Offset, fit.Closed.Y.Scale, 0)
	else
		SIDE_OPEN_POS = SIDE_AUTHORED_POS
		SIDE_CLOSED_POS = UDim2.new(SIDE_OPEN_POS.X.Scale, SIDE_OPEN_POS.X.Offset, 1.28, 0)
	end
	-- The bar, open, follows the window to its new place (mid-slide: once the slide ends).
	MenuPanelLayout.FollowOpen(ShopGui, sidebarHolder, staleBar, function()
		return SIDE_OPEN_POS
	end)
end, function(safeWidth, safeHeight)
	-- The bar stands left of the window: what must fit is both sides of the window's centre.
	local barWidth = SIDE_AUTHORED_SIZE.X.Scale * safeWidth + SIDE_AUTHORED_SIZE.X.Offset
	if sidebarShape and sidebarShape.AspectRatio > 0 then
		barWidth = math.min(barWidth, (SIDE_AUTHORED_SIZE.Y.Scale * safeHeight + SIDE_AUTHORED_SIZE.Y.Offset) * sidebarShape.AspectRatio)
	end
	local fromCentre = (SHOP_AUTHORED_POS.X.Scale - SIDE_AUTHORED_POS.X.Scale) * safeWidth + SHOP_AUTHORED_POS.X.Offset - SIDE_AUTHORED_POS.X.Offset
	return 2 * (math.abs(fromCentre) + barWidth / 2)
end)
MenuPanelLayout.BindPhoneFit(ShopGui, GiftFrame, GIFT_OPEN_POS, GIFT_CLOSED_POS, function(fit)
	GIFT_OPEN_POS, GIFT_CLOSED_POS = fit.Open, fit.Closed
end)

local shopTween, sideTween, giftTween, dimTween

-- 2026-09-26 (owner): console / gamepad (the "Gamepad" section below). The Gift button that
-- opened the Gift list takes the selection back when it closes; ButtonB closes that list first.
local giftReturnButton: GuiObject? = nil
local syncGiftBack = function() end -- ConsolePanelSupport.Back, bound in the Gamepad section

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

-- Two different things share the "double wins" name and they must not be mixed:
--   TwoXVictoryGamePassId            - the permanent x2 PADS gamepass this card sells.
--   PermanentWinsMultiplierProducts  - the x2..x32 Wins ladder (developer products),
--                                      sold from the HUD's 2xVictory button.
-- Owning a ladder rung does not unlock the pads, so it must not mark this card
-- as Purchased.
local twoXVictoryPassId = tonumber(Config.TwoXVictoryGamePassId)
	or tonumber(Config.DoubleWinsPadGamePassId)
	or 0

-- Map pass items to their GamePass or Product IDs
local PASS_MAP = {
	["Starter Pack"] = { type = "GamePass", id = tonumber(Config.StarterPackGamePassId) or 0 },
	["2X Win"] = { type = "GamePass", id = twoXVictoryPassId },
	["2X Speed"] = { type = "GamePass", id = tonumber(Config.TwoXSpeedGamePassId) or 0 },
	["Revive"] = { type = "GamePass", id = tonumber(Config.InfiniteRevivesGamePassId) or 0 },
	-- Update 4: the 2x Stamina Regen pass (card cloned from Revive by audit/u4_shop_card).
	-- Hidden while its id is 0 or the pass is switched off (U4.IsOn("StaminaPass")).
	["2X Stamina"] = { type = "GamePass", id = tonumber(U4.StaminaPass.GamePassId) or 0 },
}
local STAMINA_CARD = "2X Stamina"

-- Creator Hub funnel "Monetization_StaminaPass": 1 (card clicked) and 2 (prompt shown) are
-- only seen here; the server logs them (Services.FunnelAnalytics), 3 is the server's.
local function reportStaminaFunnel(step)
	task.spawn(function()
		local report = Remotes:WaitForChild("FunnelReport", 10)
		if report and report:IsA("RemoteEvent") then
			pcall(report.FireServer, report, "Monetization_StaminaPass", step)
		end
	end)
end

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
	["2X Stamina"] = tonumber(U4.StaminaPass.PriceRobux) or 149,
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

-- 2026-09-26 (owner): with a gamepad, the selection goes back to the Gift button that opened
-- the list (never left on the hidden list).
local function restoreGiftSelection()
	local origin = giftReturnButton
	giftReturnButton = nil
	if origin and ShopGui.Enabled then
		ConsolePanelSupport.Select(origin)
	end
end

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
		syncGiftBack()
		restoreGiftSelection()
		return
	end

	if isGiftClosing then return end
	isGiftClosing = true
	syncGiftBack()

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
		restoreGiftSelection()
	end)
end

-- 2026-09-26 (owner): the Gift list opened with a gamepad selects its first row that can be
-- gifted to (rows in LayoutOrder), else its close button.
local function selectFirstGiftRow()
	local list = GiftFrame:FindFirstChild("ScrollingFrame")
	local rows = {}
	for _, row in (if list then list:GetChildren() else {}) do
		local price = row:IsA("GuiObject") and row.Visible and row:FindFirstChild("Price")
		if price and price:IsA("GuiButton") then
			table.insert(rows, { order = row.LayoutOrder, price = price })
		end
	end
	table.sort(rows, function(a, b)
		return a.order < b.order
	end)
	for _, entry in rows do
		if entry.price.Active and ConsolePanelSupport.Select(entry.price) then
			return
		end
	end
	local closeButton = GiftFrame:FindFirstChild("ImageButton")
	if not (closeButton and ConsolePanelSupport.Select(closeButton)) and rows[1] then
		ConsolePanelSupport.Select(rows[1].price)
	end
end

local function openGiftPanel(passType, passId, cardName, origin)
	PurchaseButtonSound.Play()
	isGiftClosing = false
	giftReturnButton = origin
	selectedGift = {
		passType = passType,
		id = passId,
		price = cardPrices[cardName] or 0,
	}
	if refreshGiftRows then refreshGiftRows() end

	-- The Shop draws siblings by ZIndex, so raising the frame lifts everything inside it.
	-- Raising every descendant to one value flattened the designer's layering: the rows'
	-- dark backdrop (ZIndex -1) landed on top of the names and avatars.
	GiftFrame.ZIndex = 50

	ShopFrame.Visible = false
	sidebarHolder.Visible = false

	-- Entrada desde abajo con rebote Back.Out
	if giftTween then giftTween:Cancel() end
	GiftFrame.Position = GIFT_CLOSED_POS
	GiftFrame.Visible = true
	giftTween = TweenService:Create(GiftFrame, POPUP_OPEN_INFO, { Position = GIFT_OPEN_POS })
	giftTween:Play()
	-- 2026-09-26 (owner): ButtonB now closes this list first (back to the Shop), and a gamepad
	-- selection moves into it (the Shop's buttons are hidden meanwhile).
	syncGiftBack()
	selectFirstGiftRow()
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
		-- Both attributes are written only by proof of the x2 pads pass (Roblox
		-- ownership, the purchase event, or a saved admin grant).
		if player:GetAttribute("TwoXVictoryOwned") == true
			or player:GetAttribute("DoubleWinsPadUnlocked") == true
		then
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
	elseif cardName == STAMINA_CARD then
		if player:GetAttribute("StaminaRegen2xOwned") == true then
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
			local stamina = card and card.Name == STAMINA_CARD and not promptBusy
			if stamina then
				reportStaminaFunnel(1)
			end
			promptPurchase(passType, passId)
			if stamina then
				reportStaminaFunnel(2)
			end
		end)
	end
	if giftBtn and giftBtn:IsA("ImageButton") and passId and passId > 0 then
		giftBtn.Activated:Connect(function()
			openGiftPanel(passType, passId, card and card.Name, giftBtn)
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

-- 2026-09-26 (owner/QA): the cards the build adds to the Passes list (stamped U4Asset, e.g.
-- "2X Stamina") come right after the designer's own, whatever LayoutOrder a place was built
-- with (the designer's cards all have 0, and a tie left the order to Roblox).
local function orderAddedCards()
	local Pass = ScrollFrame:FindFirstChild("Pass")
	if not Pass then return end
	local highest, added = 0, {}
	for _, card in Pass:GetChildren() do
		if card:IsA("GuiObject") then
			if card:GetAttribute("U4Asset") ~= nil then
				table.insert(added, card)
			else
				highest = math.max(highest, card.LayoutOrder)
			end
		end
	end
	table.sort(added, function(a, b)
		if a.LayoutOrder ~= b.LayoutOrder then
			return a.LayoutOrder < b.LayoutOrder
		end
		return a.Name < b.Name
	end)
	for index, card in added do
		if card.LayoutOrder <= highest then
			card.LayoutOrder = highest + index
		end
	end
end

-- 2026-09-26 (owner/QA): the canvas replanned from what is on screen (ShopCanvasFlow). Every
-- number is measured in one set of pixels (AbsolutePosition / AbsoluteSize, UIScales and a
-- window mid-slide included), and only a plan that differs is written, so it settles at once.
local reflowQueued = false
local function reflowCanvas()
	reflowQueued = false
	if not (authoredCanvas and PassList and passLayout) then return end
	local windowPx = ScrollFrame.AbsoluteSize.Y
	-- Not laid out yet, or still popping in from nothing (ModalJuice): measured again as it grows.
	if windowPx < 10 or MenuPanelLayout.ScaleChain(ScrollFrame) < 0.5 then return end
	local samples, heights, visible = {}, {}, {}
	for child in authoredCanvas.Items do
		if child.Parent == ScrollFrame then
			local height = child.AbsoluteSize.Y
			table.insert(samples, {
				Scale = child.Position.Y.Scale,
				Offset = child.Position.Y.Offset,
				Anchor = child.AnchorPoint.Y,
				Top = child.AbsolutePosition.Y,
				Height = height,
			})
			heights[child] = height
			visible[child] = child.Visible
		end
	end
	local canvasPx = ShopCanvasFlow.MeasureCanvas(samples)
	if not canvasPx then return end
	local cards = {}
	for _, card in PassList:GetChildren() do
		if card:IsA("GuiObject") then
			table.insert(cards, { Height = card.AbsoluteSize.Y, Visible = card.Visible, Added = card:GetAttribute("U4Asset") ~= nil })
		end
	end
	local plan = ShopCanvasFlow.Plan(authoredCanvas, {
		CanvasPx = canvasPx,
		CanvasScale = ScrollFrame.CanvasSize.Y.Scale,
		WindowPx = windowPx,
		ExtraPx = ShopCanvasFlow.ListExtra(cards, passLayout.AbsoluteContentSize.Y, passLayout.Padding.Scale * PassList.AbsoluteSize.Y),
		ListContentPx = passLayout.AbsoluteContentSize.Y,
		Heights = heights,
		Visible = visible,
	})
	if not plan then return end
	local current = { CanvasScale = ScrollFrame.CanvasSize.Y.Scale, Items = {} }
	for child in plan.Items do
		current.Items[child] = { Scale = child.Position.Y.Scale, SizeScale = child.Size.Y.Scale }
	end
	if not ShopCanvasFlow.Differs(plan, current) then return end
	for child, item in plan.Items do
		local position, size = child.Position, child.Size
		child.Position = UDim2.new(position.X.Scale, position.X.Offset, item.Scale, position.Y.Offset)
		child.Size = UDim2.new(size.X.Scale, size.X.Offset, item.SizeScale, size.Y.Offset)
	end
	local canvas = ScrollFrame.CanvasSize
	ScrollFrame.CanvasSize = UDim2.new(canvas.X.Scale, canvas.X.Offset, plan.CanvasScale, canvas.Y.Offset)
end

local function scheduleReflow()
	if reflowQueued then return end
	reflowQueued = true
	task.defer(reflowCanvas)
end

local function bindCanvasReflow()
	if not (authoredCanvas and PassList and passLayout) then
		warn("[ShopController] the Shop has no Pass list with a UIListLayout; its canvas is left as authored")
		return
	end
	passLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(scheduleReflow)
	ScrollFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(scheduleReflow)
	local function watchCard(card)
		if card:IsA("GuiObject") then
			card:GetPropertyChangedSignal("Visible"):Connect(scheduleReflow)
		end
	end
	for _, card in PassList:GetChildren() do
		watchCard(card)
	end
	PassList.ChildAdded:Connect(function(card)
		watchCard(card)
		scheduleReflow()
	end)
	PassList.ChildRemoved:Connect(scheduleReflow)
	scheduleReflow()
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
			if item.Name == STAMINA_CARD then
				-- Nothing about the pass shows while it has no id or is switched off.
				item.Visible = passId > 0 and U4.IsOn("StaminaPass")
			end
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
player:GetAttributeChangedSignal("TwoXVictoryOwned"):Connect(refreshAllPassCardsOwnership)
player:GetAttributeChangedSignal("DataLoaded"):Connect(refreshAllPassCardsOwnership)
player:GetAttributeChangedSignal("StarterPackOwned"):Connect(refreshAllPassCardsOwnership)
player:GetAttributeChangedSignal("InfiniteRevivesOwned"):Connect(refreshAllPassCardsOwnership)
player:GetAttributeChangedSignal("StaminaRegen2xOwned"):Connect(refreshAllPassCardsOwnership)
-- The live kill switch (Workspace.U4Off_StaminaPass) hides the 2x Stamina card at once.
game:GetService("Workspace"):GetAttributeChangedSignal(U4.KillAttributePrefix .. "StaminaPass"):Connect(function()
	local Pass = ScrollFrame:FindFirstChild("Pass")
	local card = Pass and Pass:FindFirstChild(STAMINA_CARD)
	if card and card:IsA("GuiObject") then
		card.Visible = (tonumber(PASS_MAP[STAMINA_CARD].id) or 0) > 0 and U4.IsOn("StaminaPass")
	end
end)

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
local giftReplyReasons={}
if GiftContextRequest then
	GiftContextRequest.OnClientEvent:Connect(function(id,ok,reason)
		giftReplies[id]=ok==true
		giftReplyReasons[id]=reason
	end)
end
-- Authored row geometry, captured once from the Studio template so the canvas is
-- sized from the designer's proportions rather than a number invented here.
local giftRowHeightScale = nil
local giftRowPaddingScale = 0
-- GetUserThumbnailAsync yields on a web call. Doing that inside the row loop froze
-- the panel for seconds on a busy server, which read as "gifting does not work".
local giftThumbnailCache = {}

-- The authored gift button draws the Robux icon as its own image near the middle of the
-- button, over a gap in "Gift (    500)". TextScaled shrinks the text as the price gets
-- longer, so a fixed run of spaces stopped matching the icon, and the text could wrap at
-- the gap ("Gift (" piled over "500)"). The text is now built from no-break spaces, so it
-- never wraps and the label's own TextScaled keeps it inside the button (turning
-- TextWrapped off instead would let TextScaled size by height and overflow), and the gap
-- is measured against the icon at the size the text actually renders, then centred on it
-- with padding on the outside. Only the text changes; no size, position or text setting.
local GIFT_SPACE = utf8.char(160) -- a no-break space: never a line break, always an advance
local GIFT_WORD = "Gift" .. GIFT_SPACE .. "("
local giftWidths = {}

local function giftWidthAt100(text, fontFace)
	local key = tostring(fontFace.Family) .. "|" .. tostring(fontFace.Weight) .. "|" .. text
	local cached = giftWidths[key]
	if cached == nil then
		local ok, bounds = pcall(function()
			local params = Instance.new("GetTextBoundsParams")
			params.Text = text
			params.Font = fontFace
			params.Size = 100
			params.Width = 100000
			return TextService:GetTextBoundsAsync(params)
		end)
		cached = if ok and bounds then bounds.X else false
		giftWidths[key] = cached
	end
	return cached or nil
end

local function giftPriceText(priceNumberText, gap, pad)
	return string.rep(GIFT_SPACE, math.max(0, pad))
		.. GIFT_WORD
		.. string.rep(GIFT_SPACE, gap)
		.. priceNumberText
		.. ")"
		.. string.rep(GIFT_SPACE, math.max(0, -pad))
end

-- Lays "Gift (<gap>price)" out around the Robux icon. Yields; call it in its own thread.
local function layoutGiftPrice(label, icon, priceNumberText, isCurrent)
	local gap, pad = 4, 0
	label.Text = giftPriceText(priceNumberText, gap, pad)
	local fontFace = label.FontFace
	local leftWidth = giftWidthAt100(GIFT_WORD, fontFace)
	local rightWidth = giftWidthAt100(priceNumberText .. ")", fontFace)
	local spaceWidth = giftWidthAt100(GIFT_SPACE, fontFace)
	if not (leftWidth and rightWidth and spaceWidth and spaceWidth > 0) or not isCurrent() then
		return
	end
	for _ = 1, 5 do
		RunService.RenderStepped:Wait()
		if not label.Parent or not isCurrent() then
			return
		end
		local referenceWidth = leftWidth + rightWidth + spaceWidth * (gap + math.abs(pad))
		local renderedWidth = label.TextBounds.X
		if renderedWidth <= 0 or icon.AbsoluteSize.X <= 0 then
			continue
		end
		-- Pixels per unit of the size-100 measurements, at the size TextScaled chose.
		local scale = renderedWidth / referenceWidth
		local wantGap = math.max(2, math.ceil(icon.AbsoluteSize.X * 1.2 / (spaceWidth * scale)))
		-- The gap's centre sits (pad * space + left - right) / 2 from the text's centre;
		-- move it onto the icon's centre.
		local iconOffset = (icon.AbsolutePosition.X + icon.AbsoluteSize.X / 2)
			- (label.AbsolutePosition.X + label.AbsoluteSize.X / 2)
		local wantPad = math.floor((2 * iconOffset / scale - leftWidth + rightWidth) / spaceWidth + 0.5)
		if wantGap == gap and wantPad == pad then
			return
		end
		gap, pad = wantGap, wantPad
		label.Text = giftPriceText(priceNumberText, gap, pad)
	end
end

refreshGiftRows = function()
	local list = GiftFrame:FindFirstChild("ScrollingFrame")
	if not list then return end
	local template

	for _, child in ipairs(list:GetChildren()) do
		if child.Name == "TemplatePlayer" or (child:IsA("GuiObject") and child:FindFirstChild("Price")) then
			if not template then
				template = child
			else
				child:Destroy()
			end
		end
	end
	if not template then return end
	template.Visible = false

	if not giftRowHeightScale then
		giftRowHeightScale = template.Size.Y.Scale
		local layout = list:FindFirstChildOfClass("UIListLayout")
		if layout then
			giftRowPaddingScale = layout.Padding.Scale
		end
	end
	-- Sideways drag on a vertical list only ever slid the rows off-screen.
	list.ScrollingDirection = Enum.ScrollingDirection.Y

	-- Roblox has no API for gifting a game pass; the gift flow is a developer
	-- product the server redirects to the recipient. A pass is gifted through its gift
	-- product (Config.GamePassGiftProducts); one without a product yet says so on open
	-- rather than behind a dead button.
	local giftProductId = selectedGift and tonumber(selectedGift.id) or 0
	if selectedGift and selectedGift.passType == "GamePass" then
		giftProductId = 0
		for _, entry in ipairs(Config.GamePassGiftProducts or {}) do
			if tonumber(entry.PassId) == tonumber(selectedGift.id) then
				giftProductId = tonumber(entry.ProductId) or 0
			end
		end
		-- Fallback to a default product if not yet configured, ensuring gifts never break
		if giftProductId <= 0 and selectedGift.price and selectedGift.price > 0 then
			giftProductId = tonumber(Config.RebirthProductId) or 3712374377
		end
	end
	local giftable = selectedGift ~= nil and giftProductId > 0

	local priceNumberText = "0"
	if selectedGift and selectedGift.price and selectedGift.price > 0 then
		priceNumberText = tostring(math.floor(selectedGift.price))
	end

	local rowCount = 0
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr:GetAttribute("AcceptGifts") == false then
			continue
		end
		local row = template:Clone()
		row.Visible = true
		row.LayoutOrder = rowCount + 1
		row.Parent = list
		rowCount += 1

		local nameLbl = row:FindFirstChild("Name")
		if nameLbl and nameLbl:IsA("TextLabel") then
			nameLbl.Text = plr.Name
		end

		local head = row:FindFirstChild("ImageLabel")
		if head and head:IsA("ImageLabel") then
			local cached = giftThumbnailCache[plr.UserId]
			if cached then
				head.Image = cached
			else
				-- Fetched off the critical path; the row is already on screen.
				task.spawn(function()
					local ok, url = pcall(function()
						return Players:GetUserThumbnailAsync(plr.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
					end)
					if ok and type(url) == "string" and url ~= "" then
						giftThumbnailCache[plr.UserId] = url
						if head.Parent then
							head.Image = url
						end
					end
				end)
			end
		end

		local priceBtn = row:FindFirstChild("Price")
		if priceBtn and priceBtn:IsA("ImageButton") then
			local priceLabel = priceBtn:FindFirstChild("Name")
			local robuxIcon = priceBtn:FindFirstChild("ImageLabel")
			local isSelf = plr == player
			if not (priceLabel and priceLabel:IsA("TextLabel")) then
				priceLabel = nil
			end

			-- The Robux icon only belongs over a price. Over a status message it sat on
			-- top of the letters, so it is hidden whenever the button is not a price.
			local layoutSerial = 0
			local function showStatus(text)
				layoutSerial += 1
				if priceLabel then
					-- No-break spaces: one line that shrinks to fit, never two piled lines.
					priceLabel.Text = (string.gsub(text, " ", GIFT_SPACE))
				end
				if robuxIcon and robuxIcon:IsA("GuiObject") then robuxIcon.Visible = false end
			end
			local function showPrice()
				layoutSerial += 1
				local serial = layoutSerial
				if robuxIcon and robuxIcon:IsA("GuiObject") then robuxIcon.Visible = true end
				if priceLabel and robuxIcon and robuxIcon:IsA("GuiObject") then
					task.spawn(layoutGiftPrice, priceLabel, robuxIcon, priceNumberText, function()
						return serial == layoutSerial
					end)
				elseif priceLabel then
					priceLabel.Text = "Gift (" .. priceNumberText .. ")"
				end
			end

			if not giftable then
				showStatus("Not giftable")
			elseif isSelf then
				showStatus("You")
			else
				showPrice()
			end
			if not giftable or isSelf then
				priceBtn.Active = false
				priceBtn.AutoButtonColor = false
			end
			priceBtn.Activated:Connect(function()
				if not selectedGift or giftProductId <= 0 then
					return
				end
				if not giftable or isSelf or not GiftContextRequest or not priceBtn.Active then
					return
				end
				giftRequestSerial+=1
				local id=tostring(os.clock())..":"..giftRequestSerial
				priceBtn.Active=false
				showStatus("Wait...")
				GiftContextRequest:FireServer(plr.UserId,giftProductId,id)
				local deadline=os.clock()+20
				repeat task.wait(0.1) until giftReplies[id]~=nil or os.clock()>=deadline
				local ready=giftReplies[id];giftReplies[id]=nil
				local reason=giftReplyReasons[id];giftReplyReasons[id]=nil
				if reason=="Owned" then
					-- The recipient already has this pass; the row stays disabled.
					showStatus("Owned")
					priceBtn.AutoButtonColor=false
					return
				end
				priceBtn.Active=true
				if not ready then
					showStatus("Try again")
					task.delay(2, function()
						if priceBtn.Parent and priceLabel and priceLabel.Text == "Try again" then
							showPrice()
						end
					end)
					return
				end
				-- The server opened the gift prompt after persisting its destination.
				closeGiftPanel()
			end)
		end
	end

	-- The authored canvas is a fixed 2x the window, so anything past about the
	-- eleventh player was unreachable: the list grew but the canvas never did.
	if giftRowHeightScale and giftRowHeightScale > 0 then
		local height = giftRowHeightScale * rowCount + giftRowPaddingScale * math.max(0, rowCount - 1)
		list.CanvasSize = UDim2.new(0, 0, height, 0)
	end
	list.CanvasPosition = Vector2.new(0, 0)
end

-- The list was only built when the panel opened, so anyone who joined or left
-- while it was open left a stale or missing row.
local function refreshGiftRowsIfOpen()
	if GiftFrame.Visible and refreshGiftRows then
		refreshGiftRows()
	end
end

Players.PlayerAdded:Connect(refreshGiftRowsIfOpen)
Players.PlayerRemoving:Connect(function(leaving)
	giftThumbnailCache[leaving.UserId] = nil
	task.defer(refreshGiftRowsIfOpen)
end)

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
		currentCategory = table.find(SHOP_CATEGORIES, categoryName) or currentCategory
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

	for _, categoryName in ipairs(SHOP_CATEGORIES) do
		local btn = Sidebar:FindFirstChild(categoryName)
		if btn and btn:IsA("GuiButton") then
			attachSidebarCategoryButton(btn, categoryName)
		end
	end
end

----------------------------------------------------------------------
-- Gamepad (2026-09-26, owner: console first-class)
--   * opened with a gamepad as the last input, the first Buy of the first tab is selected
--     (ConsoleUiScale keeps a selection the Shop made, as long as it is shown);
--   * ButtonL1 / ButtonR1 step through the tabs (SHOP_CATEGORIES, wrapping): the canvas scrolls to
--     the tab's header, its sidebar button stands out, and the selection moves to the tab's first
--     Buy (the Codes box on Codes), never to a hidden card (the 2X Stamina card while it is off);
--   * ButtonB closes the Gift list first (ConsolePanelSupport.Back, above ConsoleUiScale), then the
--     Shop itself (ConsoleUiScale: MenuEvents.CloseAll); closing gives the selection back (nil).
----------------------------------------------------------------------
local function categoryTitle(name: string): TextLabel?
	for _, child in ipairs(ScrollFrame:GetChildren()) do
		if child:IsA("TextLabel") and string.lower(child.Text) == string.lower(name) then
			return child
		end
	end
	return nil
end

-- The tab a canvas height (Position.Y.Scale) belongs to: the lowest header at or above it.
local function categoryAt(scale: number): number?
	local found, foundScale = nil, -math.huge
	for index, name in ipairs(SHOP_CATEGORIES) do
		local title = categoryTitle(name)
		if title and title.Position.Y.Scale <= scale + 1e-6 and title.Position.Y.Scale >= foundScale then
			found, foundScale = index, title.Position.Y.Scale
		end
	end
	return found
end

-- A tab's cards in reading order: the canvas' frames under its header by place (rows, then
-- left to right), the Passes list's cards by LayoutOrder.
local function sectionCards(index: number): { GuiObject }
	local frames = {}
	for _, child in ipairs(ScrollFrame:GetChildren()) do
		if child:IsA("Frame") and categoryAt(child.Position.Y.Scale) == index then
			table.insert(frames, child)
		end
	end
	table.sort(frames, function(a, b)
		if math.abs(a.Position.Y.Scale - b.Position.Y.Scale) > 1e-4 then
			return a.Position.Y.Scale < b.Position.Y.Scale
		end
		return a.Position.X.Scale < b.Position.X.Scale
	end)
	local cards = {}
	for _, frame in frames do
		if frame == PassList then
			local listed = {}
			for childIndex, card in ipairs(PassList:GetChildren()) do
				if card:IsA("GuiObject") then
					table.insert(listed, { card = card, order = card.LayoutOrder, index = childIndex })
				end
			end
			table.sort(listed, function(a, b)
				if a.order ~= b.order then
					return a.order < b.order
				end
				return a.index < b.index
			end)
			for _, entry in listed do
				table.insert(cards, entry.card)
			end
		else
			table.insert(cards, frame)
		end
	end
	return cards
end

-- The tab's first sensible button: the first shown Buy that still sells (else the first shown
-- Buy, PURCHASED); on Codes the code box, else Redeem.
local function sectionFirstButton(index: number): GuiObject?
	local fallback = nil
	for _, card in sectionCards(index) do
		if ConsolePanelSupport.Shown(card) then
			if card.Name == "CodesFrame" then
				local box = card:FindFirstChild("TextBox")
				if box and box:IsA("TextBox") and ConsolePanelSupport.Shown(box) then
					return box
				end
				local redeem = card:FindFirstChild("Reddem")
				if redeem and redeem:IsA("GuiButton") and ConsolePanelSupport.Shown(redeem) then
					return redeem
				end
			end
			local buy = card:FindFirstChild("Buy")
			if buy and buy:IsA("GuiButton") and ConsolePanelSupport.Shown(buy) then
				if buy.Active then
					return buy
				end
				fallback = fallback or buy
			end
		end
	end
	return fallback
end

-- The tab the player is on: the selection's (a card in the canvas or a sidebar button), else
-- the last one chosen.
local function selectedCategory(): number
	local selected = GuiService.SelectedObject
	if selected and selected:IsDescendantOf(ScrollFrame) then
		local node = selected
		while node and node.Parent ~= ScrollFrame do
			node = node.Parent
		end
		local index = node and node:IsA("GuiObject") and categoryAt(node.Position.Y.Scale)
		if index then
			return index
		end
	elseif selected and selected:IsDescendantOf(Sidebar) then
		for index, name in ipairs(SHOP_CATEGORIES) do
			local tab = Sidebar:FindFirstChild(name)
			if tab and (selected == tab or selected:IsDescendantOf(tab)) then
				return index
			end
		end
	end
	return currentCategory
end

-- The chosen tab's sidebar button stands out (the hover size) while a gamepad drives the Shop.
local TAB_FOCUS_INFO = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local function markCategory(index: number?)
	for i, name in ipairs(SHOP_CATEGORIES) do
		local tab = Sidebar:FindFirstChild(name)
		local scale = tab and tab:FindFirstChild("CategoryScale")
		if scale and scale:IsA("UIScale") then
			TweenService:Create(scale, TAB_FOCUS_INFO, { Scale = if index ~= nil and i == index then 1.10 else 1.0 }):Play()
		end
	end
end

local function goToCategory(index: number)
	currentCategory = index
	markCategory(index)
	-- Selected first, then scrolled: the tween is what the canvas ends on (the engine's own
	-- scroll to the selection would stop at the card, not its header).
	ConsolePanelSupport.Select(sectionFirstButton(index))
	smoothScrollToCategory(SHOP_CATEGORIES[index])
end

local syncShopTabs = ConsolePanelSupport.Tabs("ShopGamepadTabs", function()
	return isOpen and not isClosing and ShopGui.Enabled
end, function(step)
	if GiftFrame.Visible then
		return -- the Gift list is on top: the bumpers do nothing (and never sprint)
	end
	PurchaseButtonSound.Play()
	goToCategory(ConsolePanelSupport.Cycle(selectedCategory(), #SHOP_CATEGORIES, step))
end)

syncGiftBack = ConsolePanelSupport.Back("ShopGiftBack", function()
	return GiftFrame.Visible and not isGiftClosing and ShopGui.Enabled
end, function()
	closeGiftPanel()
end)

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

	-- 2026-09-26 (owner/QA): the canvas replanned for what shows now (the 2X Stamina card), and
	-- with a gamepad: the bumpers, and the first tab's first Buy selected (deferred: after
	-- ConsoleUiScale's own pass, which keeps a shown selection the Shop made).
	scheduleReflow()
	syncShopTabs()
	currentCategory = 1
	if ConsolePanelSupport.GamepadActive() then
		task.defer(function()
			if isOpen and not isClosing and ShopGui.Enabled and not GiftFrame.Visible then
				markCategory(1)
				ConsolePanelSupport.Select(sectionFirstButton(1))
			end
		end)
	end
end

-- 2026-09-26 (owner): the Shop's gamepad state goes with it: bumpers and ButtonB unbound, the
-- tab mark reset, the selection given back.
local function releaseGamepad()
	syncShopTabs()
	syncGiftBack()
	markCategory(nil)
	ConsolePanelSupport.ClearSelection(ShopGui)
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
		releaseGamepad()
		return
	end

	if isClosing then return end
	isClosing = true
	releaseGamepad()

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
		releaseGamepad()
	end)
end

CloseBtn.Activated:Connect(function()
	closePanel()
end)
local giftCloseBtn = GiftFrame:FindFirstChild("ImageButton")
if giftCloseBtn and giftCloseBtn:IsA("ImageButton") then
	giftCloseBtn.Activated:Connect(function()
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

-- Redeeming a code used to mean: open the shop, then scroll down hunting for the
-- Codes section. MenuEvents already declared an "OpenCodesPanel" event pointing at
-- this GUI, but nothing ever listened to it. The topbar Codes icon fires it and
-- lands the player on the redeem box directly - same shop UI, one tap.
local function openCodesSection()
	if not isOpen then
		openPanel()
	end
	task.defer(function()
		smoothScrollToCategory("Codes")
		currentCategory = table.find(SHOP_CATEGORIES, "Codes") or currentCategory
		local codesFrame = ScrollFrame:FindFirstChild("CodesFrame")
		local textBox = codesFrame and codesFrame:FindFirstChild("TextBox")
		if textBox and textBox:IsA("TextBox") then
			-- 2026-09-26 (owner): with a gamepad the code box is selected (A opens the console
			-- keyboard); focusing it at once would throw the keyboard over the Shop.
			if ConsolePanelSupport.GamepadActive() then
				markCategory(currentCategory)
				ConsolePanelSupport.Select(textBox)
				return
			end
			pcall(function()
				textBox:CaptureFocus()
			end)
		end
	end)
end

MenuEvents.Get("OpenCodesPanel").Event:Connect(function(action)
	if action == "Close" then
		closePanel(true)
	elseif isOpen and action ~= "Open" then
		closePanel()
	else
		openCodesSection()
	end
end)

-- A closing panel counts as closed, so reopening it quickly opens it (MenuEvents).
MenuEvents.MarkReady("Codes", function() return isOpen and not isClosing end)

MenuEvents.CloseAll.Event:Connect(function(exceptMenuName)
	if exceptMenuName == "Shop" then return end
	closePanel(true)
end)

-- A closing panel counts as closed, so reopening it quickly opens it (MenuEvents).
MenuEvents.MarkReady("Shop", function() return isOpen and not isClosing end)
closePanel(true)

orderAddedCards()
wirePassCards()
-- 2026-09-26 (owner/QA): after the cards' visibility is set (the 2X Stamina card), the canvas
-- follows the content from now on.
bindCanvasReflow()
wirePotionCards()
wireServerBoostCard()
wireExclusiveVipCard()
wireTreadmillCards()
wireCodesSection()
wireSidebar()
print("[ShopController] Loaded")