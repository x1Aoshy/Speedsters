local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local ContextActionService = game:GetService("ContextActionService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local ReviveCommerce = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ReviveCommerce")
local ReviveCloseButton = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ReviveCloseButton"))

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
-- 1) Conexión a RevivePromptHUD en StarterGui / PlayerGui
----------------------------------------------------------------------
local gui = script:FindFirstAncestorWhichIsA("ScreenGui")
if not gui then
	gui = playerGui:WaitForChild("RevivePromptHUD", 5)
end
if not gui then
	gui = playerGui:FindFirstChild("RevivePromptHUD")
end

local createdFallback = false
if not gui then
	gui = Instance.new("ScreenGui")
	gui.Name = "RevivePromptHUD"
	gui.Parent = playerGui
	createdFallback = true
end

gui.ResetOnSpawn = false
gui.DisplayOrder = 90

local function findChild(parent, names, className)
	if not parent then return nil end
	for _, name in ipairs(names) do
		local child = parent:FindFirstChild(name, true)
		if child and (not className or child:IsA(className)) then
			return child
		end
	end
		return nil
end

local holder = findChild(gui, { "ReviveOfferHolder", "Holder", "ReviveFrame", "Frame", "Panel" }, "Frame")
if not holder then
	holder = Instance.new("Frame")
	holder.Name = "ReviveOfferHolder"
	holder.AnchorPoint = Vector2.new(0.5, 1)
	holder.Position = UDim2.new(0.5, 0, 0.88, 0)
	holder.Size = UDim2.fromOffset(370, 134)
	holder.BackgroundTransparency = 1
	holder.Visible = false
	holder.Parent = gui
	createdFallback = true
end

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

local heart = findChild(button, { "HeartIcon", "Heart", "Icon" }, "ImageLabel")
if not heart then
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

local title = findChild(button, { "ReviveText", "Title", "Text", "Name" }, "TextLabel")
if not title then
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

local price = findChild(gui, { "Price", "PriceLabel", "RobuxLabel", "Robux" }, "TextLabel")
if not price then
	price = Instance.new("TextLabel")
	price.Name = "Price"
	price.Font = Enum.Font.FredokaOne
	price.Text = paidPriceText
	price.TextColor3 = Color3.fromRGB(255, 255, 255)
	price.TextScaled = true
	price.BackgroundTransparency = 1
	price.Parent = heart or holder

	local pStroke = Instance.new("UIStroke")
	pStroke.Color = Color3.fromRGB(0, 0, 0)
	pStroke.Thickness = 3
	pStroke.Parent = price
end

----------------------------------------------------------------------
-- 2) Price Centrado Dentro del Heart Icon
----------------------------------------------------------------------
if price and heart then
	price.Parent = heart
	price.AnchorPoint = Vector2.new(0.5, 0.5)
	price.Position = UDim2.new(0.5, 0, 0.5, 0)
	price.Size = UDim2.new(1, -6, 1, -6)
	price.BackgroundTransparency = 1
	price.Rotation = 0
	price.TextXAlignment = Enum.TextXAlignment.Center
	price.TextYAlignment = Enum.TextYAlignment.Center
	price.ZIndex = (heart.ZIndex or 3) + 2
end

local countdown = findChild(holder, { "Countdown", "Timer", "TimeLabel", "Time" }, "TextLabel")
if not countdown then
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

----------------------------------------------------------------------
-- 3) Preservar Escala y Proporción Exacta de Studio
----------------------------------------------------------------------
local OPEN_POS = holder.Position
local OPEN_ANCHOR = holder.AnchorPoint

local holderScale = holder:FindFirstChildOfClass("UIScale")
local initialHolderScale = holderScale and holderScale.Scale or 1.0

local buttonScale = button:FindFirstChildOfClass("UIScale")
local initialButtonScale = buttonScale and buttonScale.Scale or 1.0

if not buttonScale then
	buttonScale = Instance.new("UIScale")
	buttonScale.Name = "ButtonScale"
	buttonScale.Scale = 1.0
	buttonScale.Parent = button
	initialButtonScale = 1.0
end

local CLOSED_POS
if OPEN_ANCHOR.Y >= 0.9 then
	CLOSED_POS = UDim2.new(OPEN_POS.X.Scale, OPEN_POS.X.Offset, 1.25, 60)
else
	CLOSED_POS = UDim2.new(OPEN_POS.X.Scale, OPEN_POS.X.Offset, 1.30, 0)
end

holder.Position = CLOSED_POS
holder.Visible = false
gui.Enabled = false

local function restoreStudioProportions()
	if buttonScale then
		buttonScale.Scale = initialButtonScale
	end
	if holderScale then
		holderScale.Scale = initialHolderScale
	end
end
restoreStudioProportions()

----------------------------------------------------------------------
-- 3b) The close "X" (saved in StarterGui by the build; built here only if missing)
----------------------------------------------------------------------
-- Pressing it closes the offer at once and tells the server, which drops the offer and,
-- if the player is still lying dead, respawns them at the spawn straight away. On a
-- gamepad ButtonB does the same, and the offer takes the selection (Revive, with the X to
-- its right) so it can be used without a virtual cursor.
local closeButton = holder:FindFirstChild(ReviveCloseButton.Name)
if not (closeButton and closeButton:IsA("GuiButton")) then
	closeButton = ReviveCloseButton.Build()
	closeButton.Parent = holder
end
local closeArt = closeButton:FindFirstChild("Art")
local closePress = closeArt and closeArt:FindFirstChild("PressScale")
closeButton.Selectable = true
button.Selectable = true
button.NextSelectionRight = closeButton
button.NextSelectionUp = closeButton
closeButton.NextSelectionLeft = button
closeButton.NextSelectionDown = button

local DISMISS_ACTION = "ReviveOfferDismiss_ButtonB"
local PRESS_INFO = TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local gamepadNavigationOwned = false
local bindGamepad

local function gamepadActive()
	return GuiService:IsTenFootInterface()
		or (UserInputService.GamepadEnabled and string.find(UserInputService:GetLastInputType().Name, "Gamepad") ~= nil)
end

----------------------------------------------------------------------
-- 4) Animación de "Brincar" (Bounce) en el Precio Dentro del Corazón
----------------------------------------------------------------------
local priceBounceLoopRunning = false
local priceBasePos = UDim2.new(0.5, 0, 0.5, 0)
local priceBaseRot = 0

local priceScale = price and price:FindFirstChild("PriceScale")
if price and (not priceScale or not priceScale:IsA("UIScale")) then
	priceScale = Instance.new("UIScale")
	priceScale.Name = "PriceScale"
	priceScale.Scale = 1.0
	priceScale.Parent = price
end

local activePriceTweens = {}
local function cancelPriceTweens()
	for _, tw in ipairs(activePriceTweens) do
		tw:Cancel()
	end
	table.clear(activePriceTweens)
end

local function startPriceBounceLoop(serial)
	if not price or not priceScale then return end
	priceBounceLoopRunning = true

	task.spawn(function()
		cancelPriceTweens()
		price.Position = priceBasePos
		price.Rotation = -10
		priceScale.Scale = 0.4

		local pop = TweenService:Create(priceScale, TweenInfo.new(0.30, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.0 })
		local rot = TweenService:Create(price, TweenInfo.new(0.30, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Rotation = 0 })
		table.insert(activePriceTweens, pop)
		table.insert(activePriceTweens, rot)
		pop:Play(); rot:Play()
		pop.Completed:Wait()

		while priceBounceLoopRunning and serial == offerSerial and holder.Visible do
			task.wait(1.2)
			if not priceBounceLoopRunning or serial ~= offerSerial or not holder.Visible then break end

			-- Brinco 1: Salto suave
			local t1 = TweenService:Create(price, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = UDim2.new(0.5, 0, 0.5, -5),
				Rotation = -5,
			})
			local s1 = TweenService:Create(priceScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Scale = 1.15,
			})
			t1:Play(); s1:Play()
			t1.Completed:Wait()

			local d1 = TweenService:Create(price, TweenInfo.new(0.10, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = priceBasePos,
				Rotation = 0,
			})
			local sd1 = TweenService:Create(priceScale, TweenInfo.new(0.10, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Scale = 1.0,
			})
			d1:Play(); sd1:Play()
			d1.Completed:Wait()

			task.wait(0.04)
			if not priceBounceLoopRunning or serial ~= offerSerial or not holder.Visible then break end

			-- Brinco 2: Rebote con Bounce
			local t2 = TweenService:Create(price, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = UDim2.new(0.5, 0, 0.5, -8),
				Rotation = 6,
			})
			local s2 = TweenService:Create(priceScale, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Scale = 1.24,
			})
			t2:Play(); s2:Play()
			t2.Completed:Wait()

			local d2 = TweenService:Create(price, TweenInfo.new(0.20, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), {
				Position = priceBasePos,
				Rotation = 0,
			})
			local sd2 = TweenService:Create(priceScale, TweenInfo.new(0.20, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), {
				Scale = 1.0,
			})
			d2:Play(); sd2:Play()
			d2.Completed:Wait()
		end
	end)
end

local function stopPriceBounceLoop()
	priceBounceLoopRunning = false
	cancelPriceTweens()
	if price then
		price.Position = priceBasePos
		price.Rotation = priceBaseRot
	end
	if priceScale then
		priceScale.Scale = 1.0
	end
end

----------------------------------------------------------------------
-- 5) Consulta de Precio en el Marketplace
----------------------------------------------------------------------
local function refreshPriceLabel()
	if not price then return end
	local free = player:GetAttribute("InfiniteRevivesOwned") == true
	price.Visible = true
	price.TextTransparency = 0
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
-- 6) Animación de Mostrar / Esconder Oferta
----------------------------------------------------------------------
local activeHolderTween = nil

local function releaseGamepad()
	ContextActionService:UnbindAction(DISMISS_ACTION)
	local selected = GuiService.SelectedObject
	if selected and selected:IsDescendantOf(holder) then
		GuiService.SelectedObject = nil
	end
	if gamepadNavigationOwned then
		gamepadNavigationOwned = false
		GuiService.GuiNavigationEnabled = false
	end
end

-- `instant`: gone this frame (the X), instead of sliding away.
local function hideOffer(serial, instant)
	if serial and serial ~= offerSerial then return end
	offerToken = nil
	offerExpiresAt = 0
	offerIsFree = false
	promptBusy = false
	refreshPriceLabel()
	stopPriceBounceLoop()
	restoreStudioProportions()
	releaseGamepad()

	if activeHolderTween then activeHolderTween:Cancel() end
	if instant then
		activeHolderTween = nil
		holder.Position = CLOSED_POS
		holder.Visible = false
		gui.Enabled = false
		return
	end
	activeHolderTween = TweenService:Create(holder, TweenInfo.new(0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = CLOSED_POS })
	activeHolderTween:Play()

	activeHolderTween.Completed:Connect(function()
		if not offerToken then
			holder.Visible = false
			gui.Enabled = false
			restoreStudioProportions()
		end
	end)
end

-- The X (or ButtonB): close now, then let the server drop the offer and respawn.
local function dismissOffer()
	local token = offerToken
	if not token or token == "" or promptBusy then return end
	uiClickSound.TimePosition = 0
	uiClickSound:Play()
	hideOffer(offerSerial, true)
	if token ~= "STUDIO_TEST_TOKEN" then
		ReviveCommerce:FireServer("Dismiss", token)
	end
end

bindGamepad = function()
	ContextActionService:BindActionAtPriority(DISMISS_ACTION, function(_, state)
		if state ~= Enum.UserInputState.Begin or GuiService.MenuIsOpen or not offerToken or not holder.Visible then
			return Enum.ContextActionResult.Pass
		end
		dismissOffer()
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value + 10, Enum.KeyCode.ButtonB)
	if gamepadActive() and not GuiService.MenuIsOpen then
		if not GuiService.GuiNavigationEnabled then
			GuiService.GuiNavigationEnabled = true
			gamepadNavigationOwned = true
		end
		GuiService.SelectedObject = button
	end
end

closeButton.Activated:Connect(dismissOffer)
if closePress then
	closeButton.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			TweenService:Create(closePress, PRESS_INFO, { Scale = 0.86 }):Play()
		end
	end)
	closeButton.InputEnded:Connect(function()
		TweenService:Create(closePress, PRESS_INFO, { Scale = 1 }):Play()
	end)
	closeButton.MouseEnter:Connect(function()
		TweenService:Create(closePress, PRESS_INFO, { Scale = 1.1 }):Play()
	end)
	closeButton.MouseLeave:Connect(function()
		TweenService:Create(closePress, PRESS_INFO, { Scale = 1 }):Play()
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
	restoreStudioProportions()

	if activeHolderTween then activeHolderTween:Cancel() end

	if price and heart and price.Parent ~= heart then
		price.Parent = heart
		price.AnchorPoint = Vector2.new(0.5, 0.5)
		price.Position = UDim2.new(0.5, 0, 0.5, 0)
		price.Size = UDim2.new(1, -6, 1, -6)
		price.BackgroundTransparency = 1
	end

	button.Visible = true
	if heart then heart.Visible = true end
	if title then title.Visible = true end
	if countdown then countdown.Visible = true end
	gui.Enabled = true
	holder.Position = CLOSED_POS
	holder.Visible = offerToken ~= ""
	if not holder.Visible then return end

	activeHolderTween = TweenService:Create(holder, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = OPEN_POS })
	activeHolderTween:Play()

	closeButton.Visible = true
	closeButton.Active = true
	bindGamepad()

	startPriceBounceLoop(serial)

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
	closeButton.Active = false

	local downTween = TweenService:Create(buttonScale, TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Scale = initialButtonScale * 0.94,
	})
	downTween:Play()

	task.delay(0.08, function()
		if buttonScale.Parent then
			local upTween = TweenService:Create(buttonScale, TweenInfo.new(0.10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Scale = initialButtonScale,
			})
			upTween:Play()
			upTween.Completed:Once(function()
				buttonScale.Scale = initialButtonScale
			end)
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
			closeButton.Active = true
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
		closeButton.Active = true
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

if RunService:IsStudio() then
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and (input.KeyCode == Enum.KeyCode.K or input.KeyCode == Enum.KeyCode.F4 or input.KeyCode == Enum.KeyCode.F8) then
			showOffer({
				Type = "Offer",
				Token = "STUDIO_TEST_TOKEN",
				Stage = 1,
				Duration = 10,
				ProductId = productId,
				PriceRobux = tonumber(Config.RevivePriceRobux) or 7,
				Free = false,
			})
		end
	end)
end

print("[RevivePrompt] ready | Centered Heart Price + Bounce Anim + Close X (ButtonB) + Studio Proportions Preserved")