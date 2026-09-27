-- AfkRewardsController.client.luau
-- The designer's "Earnings!" panel (Shared.DesignerUi.EarningsGui), in three modes:
--
--   Offline  Rewards earned while away, frozen at join (Social/AfkRewardsService).
--            Cards show earned Speed and Streak; Claim! and Get x5 collect them.
--   Afk      AFK Mode is on (Social/AfkZoneService, 2026-09-18: it replaced the AFK Zone
--            circle): titled AFK Mode, it shows how long the player has been AFK, the
--            Speed and the Spin Tickets this stint has paid, and the countdowns to the
--            next ones. Claim! reads Exit AFK and turns AFK Mode off; Get x5 offers VIP
--            (AFK Mode pays x5 with it).
--   Idle     Neither: Claim! reads Go AFK! and turns AFK Mode on; the cards say what it
--            pays. The AFK icon on the top bar opens the panel.
--
-- Preserves the designer's exact layout from Uinew (1).rbxm.bak without card fills.
-- A preview feature (Shared.FeatureGate).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local MarketplaceService = game:GetService("MarketplaceService")

local LocalPlayer = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")

local FeatureGate = require(Shared:WaitForChild("FeatureGate"))
if not FeatureGate.IsPreviewPlayer(LocalPlayer) then
	return
end

local Config = require(Shared:WaitForChild("Config"))
local AfkEarningsLayout = require(Shared:WaitForChild("AfkEarningsLayout"))
local DesignerUiBuilder = require(Shared:WaitForChild("DesignerUiBuilder"))
local EarningsGuiSpec = require(Shared:WaitForChild("DesignerUi"):WaitForChild("EarningsGui"))
local MenuEvents = require(Shared:WaitForChild("MenuEvents"))
local PurchaseButtonSound = require(Shared:WaitForChild("PurchaseButtonSound"))
local SpinWheelCatalog = require(Shared:WaitForChild("SpinWheelCatalog"))
local UiShake = require(Shared:WaitForChild("UiShake"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local AfkRewardsRequest = Remotes:WaitForChild("AfkRewardsRequest")
local AfkRewardsUpdate = Remotes:WaitForChild("AfkRewardsUpdate")
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local zoneSettings = type(Config.AfkZone) == "table" and Config.AfkZone or {}
local REWARD_INTERVAL = math.max(10, math.floor(tonumber(zoneSettings.RewardIntervalSeconds) or 60))
local TICKET_INTERVAL = math.max(REWARD_INTERVAL, math.floor(tonumber(zoneSettings.TicketIntervalSeconds) or 600))

local function rgb(c)
	if typeof(c) == "Color3" then
		return c
	end
	return Color3.fromRGB(c[1], c[2], c[3])
end

-- The designer's labels scale their text to fit (TextScaled) and wrap (TextWrapped) with
-- a very tight LineHeight. With wrapping off, TextScaled sizes text by height alone and
-- it grows past its box; a text that wraps draws its lines on top of each other. So the
-- labels keep every property exactly as designed, and every text goes in with no-break
-- spaces: it can never wrap, and TextScaled shrinks it to fit its box.
local NBSP = utf8.char(160)
local function setText(label, text)
	if label and label:IsA("TextLabel") then
		if label == subtitle or label == speedText or label == timerLabel then
			label.Text = tostring(text)
		else
			label.Text = (string.gsub(tostring(text), " ", NBSP))
		end
	end
end

----------------------------------------------------------------------
-- The designer's panel
----------------------------------------------------------------------
-- Clean any previous ScreenGui to prevent duplicated overlapping panels
local existingGui = PlayerGui:FindFirstChild("AfkRewardsGui")
if existingGui then
	existingGui:Destroy()
end
local existingEarnings = PlayerGui:FindFirstChild("Earnings")
if existingEarnings then
	existingEarnings:Destroy()
end

-- The panel is saved in StarterGui (the build puts it there) and arrives in the PlayerGui
-- with the first character; a place without it gets it built from the designer's data.
local screenGui = PlayerGui:FindFirstChild("AfkRewardsGui") or PlayerGui:WaitForChild("AfkRewardsGui", 8)
if not screenGui then
	screenGui = DesignerUiBuilder.Build(EarningsGuiSpec)
	screenGui.Name = "AfkRewardsGui"
end
screenGui.ResetOnSpawn = false
screenGui.Enabled = false

local panel = screenGui:FindFirstChild("Earnings")
local parts = AfkEarningsLayout.Find(panel)
local closeButton = parts.Close
local claimButton = parts.Claim
local fiveXButton = parts.FiveX
local title = parts.Title
local subtitle = parts.Subtitle
if subtitle and subtitle:IsA("TextLabel") then
	subtitle.LineHeight = 1.0
	local aspect = subtitle:FindFirstChildOfClass("UIAspectRatioConstraint")
	if aspect then
		aspect.AspectRatio = 14.0
	end
	subtitle.Size = UDim2.new(0.88, 0, 0.09, 0)
	subtitle.Position = UDim2.new(0.5, 0, 0.165, 0)
end
local speedCard, winsCard = parts.SpeedCard, parts.WinsCard
local speedText, winsText, winsIcon, bonusBadge = parts.SpeedText, parts.WinsText, parts.WinsIcon, parts.Badge
if speedText and speedText:IsA("TextLabel") then
	speedText.LineHeight = 1.0
	local aspect = speedText:FindFirstChildOfClass("UIAspectRatioConstraint")
	if aspect then
		aspect:Destroy()
	end
	speedText.Size = UDim2.new(0.68, 0, 0.72, 0)
	speedText.Position = UDim2.new(0.64, 0, 0.5, 0)
	speedText.AnchorPoint = Vector2.new(0.5, 0.5)
	speedText.TextWrapped = true
	setText(speedText, "+Speed\nevery 1:00")
end
if winsText and winsText:IsA("TextLabel") then
	winsText.LineHeight = 1.0
	setText(winsText, "+1 Spin\nevery 10:00")
end
if title and title:IsA("TextLabel") then
	setText(title, "AFK Mode")
end
if subtitle and subtitle:IsA("TextLabel") then
	setText(subtitle, "Go AFK to earn Speed and Spins!")
end
local fiveXPrice = fiveXButton and fiveXButton:FindFirstChild("Price")
local fiveXRobux = fiveXButton and fiveXButton:FindFirstChildOfClass("ImageLabel")
local offerOfflineEarnings -- defined with openPanel below
local SUBTITLE_TEXT = subtitle and subtitle.Text or "While Offline You made:"
-- The designer's own words and icon, put back outside AFK Mode.
local TITLE_TEXT = "AFK Mode"
local CLAIM_TEXT = parts.ClaimText and parts.ClaimText.Text or "Claim!"
local FIVEX_TEXT = parts.FiveXText and parts.FiveXText.Text or "Get x5"
local WINS_ICON = (winsIcon and winsIcon.Image ~= "" and winsIcon.Image) or "rbxassetid://135011356419232"
local TICKET_ICON = "rbxassetid://135011356419232" -- the designer's flame ticket icon
local isMovementExitPrompt = false


-- Button gradients and strokes for state switching (Grey when not redeemable, Green/Purple when redeemable)
local claimGradient = parts.ClaimGradient
local fiveXGradient = parts.FiveXGradient
local claimText = parts.ClaimText
local fiveXText = parts.FiveXText

local claimStrokes = {}
if claimButton then
	for _, child in claimButton:GetChildren() do
		if child:IsA("UIStroke") then
			local grad = child:FindFirstChildOfClass("UIGradient")
			table.insert(claimStrokes, {
				Stroke = child,
				Gradient = grad,
				OriginalColor = child.Color,
			})
		end
	end
end

local fiveXStrokes = {}
if fiveXButton then
	for _, child in fiveXButton:GetChildren() do
		if child:IsA("UIStroke") then
			local grad = child:FindFirstChildOfClass("UIGradient")
			table.insert(fiveXStrokes, {
				Stroke = child,
				Gradient = grad,
				OriginalColor = child.Color,
			})
		end
	end
end

-- Small countdown between the cards and the buttons, in the designer's own text style:
-- a copy of the subtitle label, in the gap under the cards.
local timerLabel = panel:FindFirstChild("AfkTimer")
if not timerLabel and subtitle then
	timerLabel = subtitle:Clone()
	timerLabel.Name = "AfkTimer"
	timerLabel.LineHeight = 0.12
	timerLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	timerLabel.Position = UDim2.fromScale(0.5, 0.695)
	timerLabel.Size = UDim2.fromScale(0.6, 0.06)
	local shape = timerLabel:FindFirstChildOfClass("UIAspectRatioConstraint")
	local panelShape = panel:FindFirstChildOfClass("UIAspectRatioConstraint")
	if shape and panelShape then
		-- The box's own proportions, so the constraint keeps exactly the size above.
		shape.AspectRatio = 0.6 * panelShape.AspectRatio / 0.06
	end
	setText(timerLabel, "")
	timerLabel.Parent = panel
end

if winsIcon then
	winsIcon.ScaleType = Enum.ScaleType.Fit
end
if bonusBadge then
	bonusBadge.Visible = false
end
if speedText then
	setText(speedText, "")
end
if winsText then
	setText(winsText, "")
end

screenGui.Parent = PlayerGui

-- The designer drew Earnings bigger than the game's other panels; a UIScale gives it their
-- width on every screen, so its buttons and Close match Shop's and Rebirth's
-- (AfkEarningsLayout.PanelScale). The authored sizes stay untouched.
local panelScale = Instance.new("UIScale")
panelScale.Name = "PanelScale"
panelScale.Parent = panel
local function fitPanel()
	local ok, size = pcall(function()
		return screenGui.AbsoluteSize
	end)
	if ok and typeof(size) == "Vector2" and size.X > 0 and size.Y > 0 then
		panelScale.Scale = AfkEarningsLayout.PanelScale(panel, size.X, size.Y)
	end
end
fitPanel()
pcall(function()
	screenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitPanel)
end)

----------------------------------------------------------------------
-- State
----------------------------------------------------------------------
local isOpen = false
local openedByZone = false
local offline = nil
local busy = false
local vipPrice = tonumber(Config.VipPriceRobux)
-- Get x5 for players without VIP: the ClaimX5 developer product (29 R$) once it has an id,
-- else the VIP pass as before.
local claimX5 = type(zoneSettings.ClaimX5) == "table" and zoneSettings.ClaimX5 or {}
local claimX5ProductId = tonumber(claimX5.ProductId)
local claimX5Price = tonumber(claimX5.PriceRobux)
local function hasClaimX5()
	return claimX5ProductId ~= nil and claimX5ProductId > 0
end
local Workspace = game:GetService("Workspace")

local function afkActive()
	return LocalPlayer:GetAttribute("AfkModeActive") == true
end

local function mode()
	if afkActive() then
		return "Afk"
	elseif offline and offline.eligible == true then
		return "Offline"
	end
	return "Idle"
end

local function clock(seconds)
	seconds = math.max(0, math.floor(seconds))
	if seconds >= 3600 then
		return string.format("%d:%02d:%02d", seconds // 3600, (seconds // 60) % 60, seconds % 60)
	end
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function setButtonClaimable(button, gradient, strokes, label, claimable)
	if not button then
		return
	end
	button.Active = true
	button.AutoButtonColor = claimable
	if gradient then
		gradient.Enabled = claimable
	end
	button.BackgroundColor3 = if claimable then Color3.new(1, 1, 1) else rgb(AfkEarningsLayout.GreyButtonColor)
	for _, entry in strokes do
		if entry.Gradient then
			entry.Gradient.Enabled = claimable
			entry.Stroke.Color = if claimable then entry.OriginalColor else Color3.fromRGB(165, 170, 175)
		else
			entry.Stroke.Color = if claimable then entry.OriginalColor else Color3.fromRGB(75, 80, 85)
		end
	end
	if label and label:IsA("TextLabel") then
		label.TextColor3 = if claimable then rgb(AfkEarningsLayout.WhiteColor) else rgb(AfkEarningsLayout.GreyTextColor)
	end
end

local errorSerial = 0
local defaultSubtitleColor = subtitle and subtitle.TextColor3 or Color3.fromRGB(255, 255, 255)

local function showError(message)
	if not subtitle then
		return
	end
	errorSerial += 1
	local serial = errorSerial
	setText(subtitle, message)
	subtitle.TextColor3 = Color3.fromRGB(240, 60, 60)
	UiShake.Wiggle(subtitle, 6, 0.3, 10)
	task.delay(2.5, function()
		if errorSerial == serial and isOpen then
			errorSerial = 0
			subtitle.TextColor3 = defaultSubtitleColor
			render(false)
		end
	end)
end

function render(instant)
	local current = mode()
	local claimable = false
	local afkLook = current == "Afk" or current == "Idle"
	if title then
		setText(title, if current == "Afk" then "AFK Mode" elseif current == "Idle" then "AFK Mode" else TITLE_TEXT)
	end
	local curSpeed = tonumber(LocalPlayer:GetAttribute("AfkModeSpeed")) or 0
	local curTickets = tonumber(LocalPlayer:GetAttribute("AfkModeTickets")) or 0
	local hasUnclaimed = (curSpeed > 0 or curTickets > 0)

	if parts.ClaimText then
		setText(parts.ClaimText, if current == "Afk" then "Exit AFK" elseif current == "Idle" then "Go AFK!" else CLAIM_TEXT)
	end
	if winsIcon then
		winsIcon.Image = if current == "Afk" or current == "Idle" then TICKET_ICON else WINS_ICON
		winsIcon.Visible = true
	end

	if current == "Offline" then
		if subtitle and errorSerial == 0 then
			setText(subtitle, SUBTITLE_TEXT)
			subtitle.TextColor3 = defaultSubtitleColor
		end
		if speedText then
			setText(speedText, "+" .. SpinWheelCatalog.FormatNumber(tonumber(offline.speed) or 0) .. " Speed!")
		end
		if winsText then
			setText(winsText, tostring(offline.streak or offline.wins or 0))
		end
		if bonusBadge then
			bonusBadge.Visible = offline.hasBonus == true
		end
		if timerLabel then
			timerLabel.Visible = false
		end
		claimable = not busy
	elseif current == "Afk" then
		-- AFK Mode: how long, what it has paid, what comes next.
		local since = tonumber(LocalPlayer:GetAttribute("AfkModeSince")) or Workspace:GetServerTimeNow()
		if subtitle and errorSerial == 0 then
			if isMovementExitPrompt then
				setText(subtitle, "Are you sure you want to exit AFK?")
				subtitle.TextColor3 = Color3.fromRGB(255, 215, 0)
			else
				setText(subtitle, "AFK for " .. clock(Workspace:GetServerTimeNow() - since))
				subtitle.TextColor3 = defaultSubtitleColor
			end
		end
		if speedText then
			setText(speedText, "+" .. SpinWheelCatalog.FormatNumber(tonumber(LocalPlayer:GetAttribute("AfkModeSpeed")) or 0) .. " Speed!")
		end
		if winsText then
			setText(winsText, "+" .. tostring(tonumber(LocalPlayer:GetAttribute("AfkModeTickets")) or 0))
		end
		if bonusBadge then
			bonusBadge.Visible = false
		end
		if timerLabel then
			timerLabel.Visible = true
			local rewardIn = tonumber(LocalPlayer:GetAttribute("AfkModeRewardIn")) or REWARD_INTERVAL
			local ticketIn = tonumber(LocalPlayer:GetAttribute("AfkModeTicketIn")) or TICKET_INTERVAL
			setText(timerLabel, "Speed in " .. clock(rewardIn) .. " | Spin in " .. clock(ticketIn))
			timerLabel.TextColor3 = rgb(AfkEarningsLayout.WhiteColor)
		end
		claimable = not busy
	else
		-- Idle: what AFK Mode pays, and Go AFK! to turn it on.
		if subtitle and errorSerial == 0 then
			setText(subtitle, "Go AFK to earn Speed and Spins!")
			subtitle.TextColor3 = defaultSubtitleColor
		end
		if speedText then
			setText(speedText, "+Speed\nevery " .. clock(REWARD_INTERVAL))
		end
		if winsText then
			setText(winsText, "+1 Spin\nevery " .. clock(TICKET_INTERVAL))
		end
		if bonusBadge then
			bonusBadge.Visible = false
		end
		if timerLabel then
			timerLabel.Visible = true
			setText(timerLabel, "+1 Spin Ticket every " .. clock(TICKET_INTERVAL))
			timerLabel.TextColor3 = rgb(AfkEarningsLayout.WhiteColor)
		end
		claimable = not busy
	end

	setButtonClaimable(claimButton, claimGradient, claimStrokes, claimText, claimable)
	-- Get x5 preserves its normal vibrant authored purple colors
	setButtonClaimable(fiveXButton, fiveXGradient, fiveXStrokes, fiveXText, true)

	-- VIP owners claim 5x for free, so the price tag only shows for everyone else. In AFK
	-- Mode, Get x5 is VIP (AFK Mode pays x5 Speed with it); an owner sees x5 VIP!.
	local isVip = LocalPlayer:GetAttribute("VIPGamepassOwned") == true
	if parts.FiveXText then
		if isMovementExitPrompt and current == "Afk" then
			setText(parts.FiveXText, "Stay in AFK")
		else
			setText(parts.FiveXText, if afkLook and isVip then "x5 VIP!" else FIVEX_TEXT)
		end
	end
	if fiveXPrice then
		fiveXPrice.Visible = not isVip and not (isMovementExitPrompt and current == "Afk")
		local price = if hasClaimX5() and not afkLook then claimX5Price else vipPrice
		if price then
			fiveXPrice.Text = tostring(price)
		end
	end
	if fiveXRobux then
		fiveXRobux.Visible = not isVip and not (isMovementExitPrompt and current == "Afk")
	end
end

-- The Get x5 product's live price, when it is the one for sale.
task.spawn(function()
	if not hasClaimX5() then
		return
	end
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(claimX5ProductId, Enum.InfoType.Product)
	end)
	if ok and type(info) == "table" and tonumber(info.PriceInRobux) then
		claimX5Price = tonumber(info.PriceInRobux)
		render(true)
	end
end)

-- The VIP pass's live price for the tag on Get x5.
task.spawn(function()
	local passId = tonumber(Config.VipGamePassId)
	if not passId or passId <= 0 then
		return
	end
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(passId, Enum.InfoType.GamePass)
	end)
	if ok and type(info) == "table" and tonumber(info.PriceInRobux) then
		vipPrice = tonumber(info.PriceInRobux)
		render(true)
	end
end)

----------------------------------------------------------------------
-- Open / close
----------------------------------------------------------------------
local PANEL_POSITION = panel.Position
local OFFSCREEN = UDim2.fromScale(0, 1.1)
local closeSerial = 0

local function openPanel(byZone)
	if isOpen then
		return
	end
	isOpen = true
	openedByZone = byZone == true
	closeSerial += 1
	MenuEvents.CloseAll:Fire("Afk")
	panel.Position = PANEL_POSITION + OFFSCREEN
	screenGui.Enabled = true
	fitPanel()
	TweenService:Create(panel, TweenInfo.new(0.36, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = PANEL_POSITION }):Play()
	AfkRewardsRequest:FireServer({ action = "Open" })
	render(true)
end

-- Earnings made while away open by themselves, but never on top of another window: on
-- join the Update Log opens first and hands over to the daily reward, so this waits until
-- no menu has been open for a moment. Opening any menu meanwhile restarts the wait.
local OFFER_QUIET_SECONDS = 1.2
local OFFER_GIVE_UP_SECONDS = 180
local offerSerial = 0
offerOfflineEarnings = function()
	offerSerial += 1
	local serial = offerSerial
	task.spawn(function()
		local quietSince = nil
		local giveUpAt = os.clock() + OFFER_GIVE_UP_SECONDS
		while serial == offerSerial and not isOpen and os.clock() < giveUpAt do
			if MenuEvents.AnyOpen("Afk") then
				quietSince = nil
			else
				quietSince = quietSince or os.clock()
				if os.clock() - quietSince >= OFFER_QUIET_SECONDS then
					if offline and offline.eligible == true then
						openPanel(false)
					end
					return
				end
			end
			task.wait(0.25)
		end
	end)
end

local function closePanel()
	if not isOpen then
		return
	end
	isOpen = false
	isMovementExitPrompt = false
	openedByZone = false
	closeSerial += 1
	local serial = closeSerial
	local tween = TweenService:Create(panel, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = PANEL_POSITION + OFFSCREEN })
	tween:Play()
	tween.Completed:Connect(function()
		if serial == closeSerial and not isOpen then
			screenGui.Enabled = false
			-- The Main HUD comes back however the panel was closed (X, the dark background, Escape,
			-- another menu), unless another menu is open by now.
			if not MenuEvents.AnyOpen("Afk") then
				MenuEvents.SetHUDVisible(true, nil)
			end
		end
	end)
end

local function setupButtonAnimation(button, hoverScale, clickScale, hoverRotation)
	if not button or not button:IsA("GuiButton") then
		return
	end
	button.AutoButtonColor = false
	local scale = button:FindFirstChild("ButtonScale")
	if not scale or not scale:IsA("UIScale") then
		scale = Instance.new("UIScale")
		scale.Name = "ButtonScale"
		scale.Scale = 1.0
		scale.Parent = button
	end

	local targetHoverScale = hoverScale or 1.05
	local targetClickScale = clickScale or 0.94
	local targetHoverRot = hoverRotation or 0
	local isHovered = false

	local function onHoverIn()
		isHovered = true
		TweenService:Create(scale, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = targetHoverScale }):Play()
		if targetHoverRot ~= 0 then
			TweenService:Create(button, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Rotation = targetHoverRot }):Play()
		end
	end

	local function onHoverOut()
		isHovered = false
		TweenService:Create(scale, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.0 }):Play()
		if targetHoverRot ~= 0 then
			TweenService:Create(button, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Rotation = 0 }):Play()
		end
	end

	local function onPressDown()
		TweenService:Create(scale, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = targetClickScale }):Play()
	end

	local function onPressUp()
		if isHovered then
			onHoverIn()
		else
			onHoverOut()
		end
	end

	if button.MouseEnter then
		button.MouseEnter:Connect(onHoverIn)
	end
	if button.MouseLeave then
		button.MouseLeave:Connect(onHoverOut)
	end
	if button.InputBegan then
		button.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				onPressDown()
			end
		end)
	end
	if button.InputEnded then
		button.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				onPressUp()
			end
		end)
	end
end

if claimButton then
	setupButtonAnimation(claimButton, 1.05, 0.94)
end
if fiveXButton then
	setupButtonAnimation(fiveXButton, 1.05, 0.94)
end
if closeButton then
	setupButtonAnimation(closeButton, 1.10, 0.92, -8)
end

local function handleDisabledClick(button)
	PurchaseButtonSound.Play()
	UiShake.Wiggle(button, 8, 0.35, 10)
	showError("Nothing to collect yet!")
end

local function isClaimable()
	local current = mode()
	if current == "Offline" then
		return offline ~= nil and offline.eligible == true and not busy
	end
	return current ~= "Offline" and not busy
end

local function claim(claimMode)
	if busy then
		return
	end
	local current = mode()
	if current == "Offline" then
		busy = true
		render(true)
		AfkRewardsRequest:FireServer({ action = "Claim", mode = claimMode })
		task.delay(10, function()
			if busy then
				busy = false
				render(true)
			end
		end)
	elseif current == "Afk" then
		busy = true
		isMovementExitPrompt = false
		AfkRewardsRequest:FireServer({ action = if current == "Afk" then "ExitAfk" else "EnterAfk" })
		task.delay(1.5, function()
			if busy then
				busy = false
				render(true)
			end
		end)
	elseif current == "Idle" then
		busy = true
		isMovementExitPrompt = false
		AfkRewardsRequest:FireServer({ action = if current == "Afk" then "ExitAfk" else "EnterAfk" })
		task.delay(1.5, function()
			if busy then
				busy = false
				render(true)
			end
		end)
	end
end

if claimButton then
	claimButton.Activated:Connect(function()
		PurchaseButtonSound.Play()
		if isClaimable() then
			claim("Normal")
		else
			handleDisabledClick(claimButton)
		end
	end)
end

if fiveXButton then
	fiveXButton.Activated:Connect(function()
		PurchaseButtonSound.Play()
		local current = mode()
		if isMovementExitPrompt and current == "Afk" then
			isMovementExitPrompt = false
			closePanel()
			return
		end
		if current == "Afk" or current == "Idle" then
			-- AFK Mode's x5 is VIP's.
			if LocalPlayer:GetAttribute("VIPGamepassOwned") == true then
				UiShake.Wiggle(fiveXButton, 6, 0.3, 10)
				return
			end
			local passId = tonumber(Config.VipGamePassId) or 0
			if passId > 0 then
				pcall(function()
					MarketplaceService:PromptGamePassPurchase(LocalPlayer, passId)
				end)
			end
			return
		end
		if not isClaimable() then
			handleDisabledClick(fiveXButton)
			return
		end
		if LocalPlayer:GetAttribute("VIPGamepassOwned") == true then
			claim("VIP")
			return
		end
		-- The server opens the Get x5 product's prompt; its receipt pays the rewards x5.
		if hasClaimX5() then
			AfkRewardsRequest:FireServer({ action = "BuyX5" })
			return
		end
		local passId = tonumber(Config.VipGamePassId) or 0
		if passId > 0 then
			pcall(function()
				MarketplaceService:PromptGamePassPurchase(LocalPlayer, passId)
			end)
		end
	end)
end

closeButton.Activated:Connect(function()
	PurchaseButtonSound.Play()
	closePanel()
end)

AfkRewardsUpdate.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then
		return
	end
	busy = false
	if payload.claimed == true then
		offline = nil
		LocalPlayer:SetAttribute("OfflineEarningsReady", false)
		if subtitle then
			setText(subtitle, if payload.bonus then "Collected! " .. tostring(payload.bonus) else "Collected!")
		end
		setButtonClaimable(claimButton, claimGradient, claimStrokes, claimText, false)
		setButtonClaimable(fiveXButton, fiveXGradient, fiveXStrokes, fiveXText, true)
		if speedCard then
			UiShake.Wiggle(speedCard, 6, 0.5, 10)
		end
		if winsCard then
			UiShake.Wiggle(winsCard, 8, 0.5, 10)
		end
		task.delay(1.6, function()
			if afkActive() then
				render(true)
			else
				closePanel()
			end
		end)
		return
	end
	offline = payload
	render(true)
	if payload.eligible == true then
		offerOfflineEarnings()
	end
end)

-- AFK Mode: turning on shows the panel as its overlay; turning off (Exit AFK) closes it.
local wasAfk = afkActive()
local function onAfkChanged()
	local now = afkActive()
	busy = false
	if now and not wasAfk then
		if isOpen then
			render(true)
		else
			openPanel(true)
		end
	elseif not now and wasAfk then
		if isOpen and mode() ~= "Offline" then
			closePanel()
		elseif isOpen then
			render(true)
		end
	end
	wasAfk = now
end
LocalPlayer:GetAttributeChangedSignal("AfkModeActive"):Connect(onAfkChanged)
for _, attribute in { "AfkModeSpeed", "AfkModeTickets", "AfkModeRewardIn", "AfkModeTicketIn" } do
	LocalPlayer:GetAttributeChangedSignal(attribute):Connect(function()
		if isOpen and mode() == "Afk" then
			render(false)
		end
	end)
end

MenuEvents.Get("OpenAfkPanel").Event:Connect(function(action)
	if action == "Close" then
		closePanel()
		return
	end
	if action == "MovementPrompt" then
		if mode() == "Afk" then
			isMovementExitPrompt = true
			if not isOpen then
				openPanel(false)
			else
				render(true)
			end
			if subtitle then
				UiShake.Wiggle(subtitle, 6, 0.35, 10)
			end
			PurchaseButtonSound.Play()
		end
		return
	end
	isMovementExitPrompt = false
	if action == "Open" or not isOpen then
		AfkRewardsRequest:FireServer({ action = "RequestStatus" })
		openPanel(false)
	else
		closePanel()
	end
end)
MenuEvents.CloseAll.Event:Connect(function(except)
	if except ~= "Afk" then
		closePanel()
	end
end)
MenuEvents.MarkReady("Afk", function()
	return isOpen
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if isOpen and (input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB) then
		closePanel()
		return
	end
	if mode() == "Afk" and not isMovementExitPrompt then
		local code = input.KeyCode
		if code == Enum.KeyCode.W or code == Enum.KeyCode.A or code == Enum.KeyCode.S or code == Enum.KeyCode.D
			or code == Enum.KeyCode.Up or code == Enum.KeyCode.Down or code == Enum.KeyCode.Left or code == Enum.KeyCode.Right
			or code == Enum.KeyCode.Space
		then
			MenuEvents.Get("OpenAfkPanel"):Fire("MovementPrompt")
		end
	end
end)

LocalPlayer:GetAttributeChangedSignal("VIPGamepassOwned"):Connect(function()
	AfkRewardsRequest:FireServer({ action = "RequestStatus" })
end)

task.delay(2.5, function()
	AfkRewardsRequest:FireServer({ action = "RequestStatus" })
end)

if wasAfk then
	task.defer(openPanel, true)
end

print("[AfkRewardsController] ready on the designer's Earnings panel")
