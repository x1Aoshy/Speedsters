-- SpinWheelController.client.luau
-- The Spin Wheel panel on the UI designer's layout (Shared.DesignerUi.SpinWheelGui), and
-- the same wheel standing in the lobby. The server decides every spin
-- (Economy/SpinWheelService); this only shows the state and lands the wheel on the
-- segment the server already paid.
--
-- The designer placed each prize by hand inside rotated frames. Shared.SpinWheelLayout
-- reads the angle each prize really sits at, so the wheel stops with the paid prize
-- under the arrow however the designer arranges the slices, and lays out everything this
-- script adds (slice colours, odds, the Wins button) for the screen it is on.
--
-- A preview feature (Shared.FeatureGate).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local MarketplaceService = game:GetService("MarketplaceService")
local Workspace = game:GetService("Workspace")
local GuiService = game:GetService("GuiService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")

local FeatureGate = require(Shared:WaitForChild("FeatureGate"))
if not FeatureGate.IsPreviewPlayer(player) then
	return
end

local Config = require(Shared:WaitForChild("Config"))
local settings = Config.SpinWheel
if type(settings) ~= "table" or settings.Enabled ~= true then
	return
end

local DesignerUiBuilder = require(Shared:WaitForChild("DesignerUiBuilder"))
local SpinWheelGuiSpec = require(Shared:WaitForChild("DesignerUi"):WaitForChild("SpinWheelGui"))
local SpinWheelExtras = require(Shared:WaitForChild("SpinWheelExtras"))
local SpinWheelLayout = require(Shared:WaitForChild("SpinWheelLayout"))
local MenuEvents = require(Shared:WaitForChild("MenuEvents"))
local PurchaseButtonSound = require(Shared:WaitForChild("PurchaseButtonSound"))
local SpinWheelCatalog = require(Shared:WaitForChild("SpinWheelCatalog"))
local UiShake = require(Shared:WaitForChild("UiShake"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Request = Remotes:WaitForChild("SpinWheelRequest")
local Update = Remotes:WaitForChild("SpinWheelUpdate")
local PlayerGui = player:WaitForChild("PlayerGui")

local SPIN_SECONDS = math.max(1.5, tonumber(settings.SpinSeconds) or 4.6)
local SKIP_PASS_ID = tonumber(settings.SkipGamePassId)
local SKIP_SECONDS = math.clamp(tonumber(settings.SkipSpinSeconds) or 0.6, 0.2, 1.5)
local FREE_SPEED = 720 -- degrees per second while the server answers
local MESSAGE_SECONDS = 2.6
local RESULT_COLOR = Color3.fromRGB(255, 214, 64)
local SKIP_ON_FILL = nil -- the designer's Spin button fill, read from the box
local SKIP_OFF = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(236, 238, 244)),
	ColorSequenceKeypoint.new(0.46, Color3.fromRGB(196, 200, 210)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(142, 148, 160)),
})
local SKIP_OFF_EDGE = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
	ColorSequenceKeypoint.new(0.64, Color3.fromRGB(176, 182, 194)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(84, 90, 102)),
})
local LABEL_SWAP_SECONDS = 3
local DIM_COLOR = Color3.fromRGB(150, 150, 150)

----------------------------------------------------------------------
-- The designer's panel
----------------------------------------------------------------------
-- The finished panel is saved in StarterGui (the build puts it there) and arrives in the
-- PlayerGui with the first character. A place without it gets it built from the
-- designer's data, the same way.
local gui = PlayerGui:FindFirstChild("SpinWheelGui") or PlayerGui:WaitForChild("SpinWheelGui", 5)
if not gui then
	gui = DesignerUiBuilder.Build(SpinWheelGuiSpec)
	gui.Name = "SpinWheelGui"
	gui.Parent = PlayerGui
elseif gui.Parent ~= PlayerGui then
	gui.Parent = PlayerGui
end
gui.ResetOnSpawn = false
gui.Enabled = false
-- The pieces the panel adds to the designer's layout; on the saved panel they are there.
SpinWheelExtras.Decorate(gui, settings.Products, SpinWheelLayout, SpinWheelCatalog)

local wheelHolder = gui:FindFirstChild("Frame")
local wheel = wheelHolder:FindFirstChild("Spin Wheel")
local hub = wheel:FindFirstChild("Spin")
local wheelArt = wheel:FindFirstChildOfClass("ImageLabel")
local arrow = wheelHolder:FindFirstChild("Arrow")
local closeButton = wheelHolder:FindFirstChild("Close")
local row = gui:FindFirstChild("Button")
local spinButton = row:FindFirstChild("Claim")
local timerLabel = row:FindFirstChild("TextLabel")

-- The Spin button holds two labels, both named "Name": the word, and the spin count in
-- its top-right corner.
local spinCount
for _, child in spinButton:GetChildren() do
	if child:IsA("TextLabel") and child.Position.X.Scale > 0.7 then
		spinCount = child
	end
end

----------------------------------------------------------------------
-- Geometry: where each prize sits and where the arrow points
----------------------------------------------------------------------
local measure = SpinWheelLayout.Measure(wheelHolder)
local slots = measure.Slots
local POINTER_ANGLE = measure.Pointer
local halfSector = measure.SectorDegrees / 2
local sectorDegrees = measure.SectorDegrees
local separatorLines = {}
for index = 1, #slots do
	table.insert(separatorLines, (measure.SectorOffset + (index - 1) * sectorDegrees - sectorDegrees / 2) % 360)
end
if #slots ~= #SpinWheelCatalog.Segments then
	warn(
		"[SpinWheelController] The wheel art has "
			.. #slots
			.. " slices but the catalog has "
			.. #SpinWheelCatalog.Segments
			.. " segments"
	)
end

-- The slice colours and the hub cap are SpinWheelExtras' (on the saved panel already).

----------------------------------------------------------------------
-- Buttons: Robux packs (X1, X3) and the Wins spin
----------------------------------------------------------------------
local function namedChild(parent, className, name)
	for _, child in parent:GetChildren() do
		if child:IsA(className) and (name == nil or child.Name == name) then
			return child
		end
	end
	return nil
end

-- The packs that are not on the designer's row (X10) stand beside the wheel, on the right
-- (the Wins spin has the left), each with its caption (SpinWheelExtras made them).
local sidePacks = {}
for _, product in settings.Products or {} do
	if product.Button and not row:FindFirstChild(product.Button) then
		local button = wheelHolder:FindFirstChild(product.Button)
		local caption = wheelHolder:FindFirstChild(product.Button .. "Caption")
		if button and caption then
			table.insert(sidePacks, { Button = button, Caption = caption })
		end
	end
end

local packs = {}
for _, product in settings.Products or {} do
	local button = product.Button and (row:FindFirstChild(product.Button) or wheelHolder:FindFirstChild(product.Button))
	if button then
		packs[product.Key] = {
			Button = button,
			Price = namedChild(button, "TextLabel", "Price"),
			Fallback = tonumber(product.PriceRobux),
		}
	end
end

-- The Wins spin: the designer's X1 button in gold with a Wins icon on its price tag
-- (SpinWheelExtras), in the space left of the wheel, and a caption under it with the
-- purchases left this hour. It is placed from the real screen size every time that size
-- changes (SpinWheelLayout).
local compactScale = nil
local compact = false
local winsButton = wheelHolder:FindFirstChild("WinsSpin")
local winsCaption = wheelHolder:FindFirstChild("WinsCaption")
local winsPrice = winsButton and namedChild(winsButton, "TextLabel", "Price")
-- Its price tag's icon is the golden Wins trophy, never the Robux one it was copied from:
-- the saved panel is built offline, where the icon's image is not kept, so it is set here
-- (2026-09-18: the 50M Wins spin showed the Robux icon, as if it cost 50M Robux).
local winsIcon = winsButton and namedChild(winsButton, "ImageLabel")
if winsIcon then
	winsIcon.Image = SpinWheelCatalog.IconImages.Wins
	winsIcon.ScaleType = Enum.ScaleType.Fit
	local tint = winsIcon:FindFirstChildOfClass("UIGradient")
	if tint then
		tint.Enabled = false
	end
end
if not winsCaption then
	winsButton = nil
end

-- True while the compact layout is in use (set by layoutPanel below); it places these itself.
local function compactLayout()
	return compact
end

local function placeWinsButton()
	local screen = gui.AbsoluteSize
	if screen.X <= 0 or screen.Y <= 0 or compactLayout() then
		return
	end
	for _, side in sidePacks do
		local spot = SpinWheelLayout.PackButton(measure, gui, row:FindFirstChild("X3"), timerLabel, screen.X, screen.Y)
		side.Button.Position = UDim2.fromScale(spot.Button.X, spot.Button.Y)
		side.Button.Size = UDim2.fromScale(spot.Button.Width, spot.Button.Height)
		side.Caption.Position = UDim2.fromScale(spot.Caption.X, spot.Caption.Y)
		side.Caption.Size = UDim2.fromScale(spot.Caption.Width, spot.Caption.Height)
	end
	if not winsButton then
		return
	end
	local placement = SpinWheelLayout.WinsButton(measure, gui, row:FindFirstChild("X1"), timerLabel, screen.X, screen.Y)
	winsButton.Position = UDim2.fromScale(placement.Button.X, placement.Button.Y)
	winsButton.Size = UDim2.fromScale(placement.Button.Width, placement.Button.Height)
	winsCaption.Position = UDim2.fromScale(placement.Caption.X, placement.Caption.Y)
	winsCaption.Size = UDim2.fromScale(placement.Caption.Width, placement.Caption.Height)
end

-- Skip: a check under X1 that lands the wheel at once, for owners of the Skip game pass.
-- The box is the designer's Spin button made square, green with a tick when on and grey
-- when off, and "Skip" is written beside it in the countdown's style.
local skipToggle, skipBox, skipTick, skipBoxFill, skipBoxEdges
do
	local x1 = row:FindFirstChild("X1")
	if x1 then
		local layout = SpinWheelLayout.SkipToggle(row, x1, timerLabel)
		skipToggle = Instance.new("TextButton")
		skipToggle.Name = "SkipToggle"
		skipToggle.Text = ""
		skipToggle.BackgroundTransparency = 1
		skipToggle.AutoButtonColor = false
		skipToggle.AnchorPoint = Vector2.new(0.5, 0.5)
		skipToggle.Position = UDim2.fromScale(layout.Toggle.X, layout.Toggle.Y)
		skipToggle.Size = UDim2.fromScale(layout.Toggle.Width, layout.Toggle.Height)
		skipToggle.ZIndex = spinButton.ZIndex + 1

		skipBox = spinButton:Clone()
		skipBox.Name = "Box"
		for _, child in skipBox:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		skipBox.Active = false
		-- The stud texture keeps its proportions in the square instead of squeezing.
		skipBox.ScaleType = Enum.ScaleType.Crop
		skipBox.AutoButtonColor = false
		skipBox.AnchorPoint = Vector2.new(0.5, 0.5)
		skipBox.Position = UDim2.fromScale(layout.Box.X, layout.Box.Y)
		skipBox.Size = UDim2.fromScale(layout.Box.Width, layout.Box.Height)
		skipBox.ZIndex = skipToggle.ZIndex
		local boxShape = skipBox:FindFirstChildOfClass("UIAspectRatioConstraint")
		if boxShape then
			boxShape.AspectRatio = layout.Box.Aspect
		end
		skipBoxFill = namedChild(skipBox, "UIGradient")
		skipBoxEdges = {}
		for _, stroke in skipBox:GetChildren() do
			if stroke:IsA("UIStroke") then
				local edge = stroke:FindFirstChildOfClass("UIGradient")
				table.insert(skipBoxEdges, {
					Stroke = stroke,
					Edge = edge,
					OnColor = stroke.Color,
					OnEdge = edge and edge.Color,
				})
			end
		end

		-- The tick: two white bars on a darker outline, drawn inside the square box.
		skipTick = Instance.new("Frame")
		skipTick.Name = "Tick"
		skipTick.BackgroundTransparency = 1
		skipTick.Size = UDim2.fromScale(1, 1)
		skipTick.ZIndex = skipBox.ZIndex + 1
		for layer, colour in { Color3.fromRGB(14, 60, 10), Color3.new(1, 1, 1) } do
			for _, bar in SpinWheelLayout.SkipTick do
				local outline = if layer == 1 then bar.Thickness * 0.75 else 0
				local piece = Instance.new("Frame")
				piece.Name = if layer == 1 then "Outline" else "Bar"
				piece.BorderSizePixel = 0
				piece.BackgroundColor3 = colour
				piece.AnchorPoint = Vector2.new(0.5, 0.5)
				piece.Position = UDim2.fromScale(bar.X, bar.Y)
				piece.Size = UDim2.fromScale(bar.Length + outline, bar.Thickness + outline)
				piece.Rotation = bar.Rotation
				piece.ZIndex = skipTick.ZIndex + layer - 1
				local corner = Instance.new("UICorner")
				corner.CornerRadius = UDim.new(0.5, 0)
				corner.Parent = piece
				piece.Parent = skipTick
			end
		end
		skipTick.Parent = skipBox
		skipBox.Parent = skipToggle

		local caption = timerLabel:Clone()
		caption.Name = "Caption"
		caption.AnchorPoint = Vector2.new(0.5, 0.5)
		caption.Position = UDim2.fromScale(layout.Caption.X, layout.Caption.Y)
		caption.Size = UDim2.fromScale(layout.Caption.Width, layout.Caption.Height)
		caption.ZIndex = skipToggle.ZIndex
		local captionShape = caption:FindFirstChildOfClass("UIAspectRatioConstraint")
		if captionShape then
			captionShape.AspectRatio = layout.Caption.Aspect
		end
		caption.Text = "Skip"
		caption.Parent = skipToggle

		skipToggle.Parent = row
	end
end

gui.Parent = PlayerGui

----------------------------------------------------------------------
-- State
----------------------------------------------------------------------
local state = nil
local stateReceivedAt = os.clock()
local isOpen = false
local phase = "idle" -- idle | waiting | landing
local wheelAngle = wheel.Rotation
local landing = nil
local messageText, messageUntil = nil, 0
local livePrices = {}
local refreshHudButton -- the Main HUD button, below

local function serverNow()
	if state and state.ServerTime then
		return state.ServerTime + (os.clock() - stateReceivedAt)
	end
	return os.time()
end

local function formatClock(seconds)
	seconds = math.max(0, math.floor(seconds))
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor(seconds % 3600 / 60)
	if hours > 0 then
		return string.format("%d:%02d:%02d", hours, minutes, seconds % 60)
	end
	return string.format("%02d:%02d", minutes, seconds % 60)
end

local function spinsAvailable()
	if not state or state.Loading then
		return 0
	end
	return (tonumber(state.Tickets) or 0) + (if state.FreeAvailable then 1 else 0)
end

local function showMessage(text)
	messageText = text
	messageUntil = os.clock() + MESSAGE_SECONDS
	timerLabel.Text = text
end

-- Paid spins are random rewards and must show their odds before anyone buys one. Each
-- prize's own label shows its amount, then its odds, turning over every few seconds
-- while the wheel rests, so the designer's layout needs nothing extra.
local labelTexts = {}
local labelsShowOdds = false

local function applyLabelTexts()
	for index, slot in slots do
		local texts = labelTexts[index]
		if texts and slot.Label then
			slot.Label.Text = if labelsShowOdds then texts.Odds else texts.Amount
		end
	end
end

local function renderSegments(segments)
	for index, slot in slots do
		local segment = segments[index]
		if segment then
			labelTexts[index] = { Amount = tostring(segment.Label or ""), Odds = tostring(segment.Odds or "") }
			if slot.Icon then
				local image = SpinWheelCatalog.IconImages[segment.Icon]
				if image then
					slot.Icon.Image = image
					slot.Icon.ScaleType = Enum.ScaleType.Fit
				end
			end
		end
	end
	applyLabelTexts()
end

local function fadeLabels(transparency, seconds)
	for _, slot in slots do
		if slot.Label then
			TweenService:Create(slot.Label, TweenInfo.new(seconds), { TextTransparency = transparency }):Play()
			local stroke = slot.Label:FindFirstChildOfClass("UIStroke")
			if stroke then
				TweenService:Create(stroke, TweenInfo.new(seconds), { Transparency = transparency }):Play()
			end
		end
	end
end

-- Until the server answers, the wheel shows this player's amounts from the catalog
-- rather than the designer's placeholder numbers.
do
	local worldKey = if Config.IsWorld2Place then "World2" elseif Config.IsWorld3Place then "World3" else "World1"
	local context = {
		Level = math.max(1, tonumber(player:GetAttribute("Level")) or 1),
		Speed = 0,
		Lap = tonumber(settings.LapWins and settings.LapWins[worldKey]) or 0,
		Shares = { Small = tonumber(settings.SmallLapShare) or 0.15, Large = tonumber(settings.LargeLapShare) or 0.6 },
	}
	local preview = {}
	for index, segment in SpinWheelCatalog.Segments do
		preview[index] = {
			Icon = segment.Icon,
			Label = SpinWheelCatalog.ShortLabel(index, context),
			Odds = SpinWheelCatalog.OddsText(index),
		}
	end
	renderSegments(preview)
end

local function setButtonEnabled(button, enabled)
	button.AutoButtonColor = enabled
	button.ImageColor3 = if enabled then Color3.new(1, 1, 1) else DIM_COLOR
end

local function refreshTimer()
	if messageText and os.clock() < messageUntil then
		return
	end
	messageText = nil
	if not state or state.Loading then
		timerLabel.Text = "Loading..."
	elseif state.FreeAvailable then
		timerLabel.Text = "Free spin ready!"
	else
		timerLabel.Text = "1+ Spin in " .. formatClock((tonumber(state.NextFreeAt) or 0) - serverNow())
	end
	if winsCaption and winsCaption.Visible and state and state.WinsPurchase then
		local purchase = state.WinsPurchase
		local remaining = tonumber(purchase.Remaining) or 0
		-- No-break spaces: one line that TextScaled shrinks to fit the caption.
		local caption = if remaining <= 0
			then "Refill in " .. formatClock((tonumber(purchase.ResetsAt) or 0) - serverNow())
			else tostring(remaining) .. " left this hour"
		winsCaption.Text = (string.gsub(caption, " ", utf8.char(160)))
	end
end

local function fetchLivePrice(key, productId)
	if livePrices[productId] ~= nil then
		return
	end
	livePrices[productId] = false
	task.spawn(function()
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(productId, Enum.InfoType.Product)
		end)
		if ok and type(info) == "table" and tonumber(info.PriceInRobux) then
			livePrices[productId] = tonumber(info.PriceInRobux)
			local pack = packs[key]
			if pack and pack.Price then
				pack.Price.Text = tostring(livePrices[productId])
			end
		end
	end)
end

local function renderState()
	if not state or state.Loading then
		refreshTimer()
		return
	end
	if type(state.Segments) == "table" and phase == "idle" then
		renderSegments(state.Segments)
	end

	local count = spinsAvailable()
	if spinCount then
		spinCount.Text = tostring(count) .. "x"
	end
	setButtonEnabled(spinButton, count > 0 and (phase == "idle" or phase == "celebrating"))

	local allowed = state.PaidSpinsAllowed == true
	for _, side in sidePacks do
		side.Caption.Visible = allowed
	end
	for key, pack in packs do
		pack.Button.Visible = allowed
		local product = nil
		for _, entry in state.Products or {} do
			if entry.Key == key then
				product = entry
			end
		end
		if pack.Price then
			local productId = product and tonumber(product.ProductId)
			if productId and livePrices[productId] then
				pack.Price.Text = tostring(livePrices[productId])
			else
				pack.Price.Text = tostring(pack.Fallback or "")
				if productId then
					fetchLivePrice(key, productId)
				end
			end
		end
	end

	local purchase = state.WinsPurchase
	if winsButton then
		winsButton.Visible = allowed and type(purchase) == "table"
		winsCaption.Visible = winsButton.Visible
		if winsButton.Visible then
			local remaining = tonumber(purchase.Remaining) or 0
			local cost = tonumber(purchase.Cost) or 0
			if winsPrice then
				winsPrice.Text = SpinWheelCatalog.FormatNumber(cost)
			end
			setButtonEnabled(winsButton, remaining > 0 and (tonumber(purchase.Wins) or 0) >= cost)
		end
	end
	refreshTimer()
	refreshHudButton()
end

----------------------------------------------------------------------
-- Spinning
----------------------------------------------------------------------
local IDLE_SPEED = 14
local CONTACT_ANGLE = 7
local MAX_DEFLECTION = 14
local SNAP_VELOCITY = 180
local SPRING_STIFFNESS = 650
local SPRING_DAMPING = 32

local baseArrowRotation = arrow.Rotation
local pointerDeflection = 0
local pointerVelocity = 0
local prevWheelAngle = wheelAngle

local tickSound = Instance.new("Sound")
tickSound.Name = "SpinWheelTick"
tickSound.SoundId = "rbxassetid://72264591133889"
tickSound.Volume = 0.22
tickSound.PlaybackSpeed = 1.4
tickSound.Parent = arrow

local lastTickTime = 0
local function playTick()
	local now = os.clock()
	if now - lastTickTime < 0.045 then
		return
	end
	lastTickTime = now
	tickSound.PlaybackSpeed = 1.35 + (math.random() - 0.5) * 0.15
	tickSound.TimePosition = 0
	tickSound:Play()
end

local function updatePointer(dt)
	if UiShake.IsShaking(arrow, "Rotation") then
		pointerDeflection = 0
		pointerVelocity = 0
		prevWheelAngle = wheelAngle
		return
	end

	local step = (wheelAngle - prevWheelAngle)
	if step < 0 then
		step = step % 360
	end

	local contactPush = nil
	local justCrossed = false

	for _, lineAngle in separatorLines do
		local delta = (lineAngle + wheelAngle - POINTER_ANGLE + 180) % 360 - 180
		local prevDelta = (lineAngle + prevWheelAngle - POINTER_ANGLE + 180) % 360 - 180

		if step > 0 and prevDelta <= 0 and (delta > 0 or delta < prevDelta) then
			justCrossed = true
		elseif step > 0 and delta >= -CONTACT_ANGLE and delta <= 0 then
			local pushRatio = (delta + CONTACT_ANGLE) / CONTACT_ANGLE
			local push = pushRatio * MAX_DEFLECTION
			if not contactPush or push > contactPush then
				contactPush = push
			end
		end
	end

	if justCrossed then
		pointerDeflection = MAX_DEFLECTION
		pointerVelocity = -SNAP_VELOCITY
		playTick()
	elseif contactPush then
		if contactPush > pointerDeflection then
			pointerDeflection = contactPush
			pointerVelocity = 0
		end
	else
		local force = -SPRING_STIFFNESS * pointerDeflection - SPRING_DAMPING * pointerVelocity
		pointerVelocity = pointerVelocity + force * dt
		pointerDeflection = pointerDeflection + pointerVelocity * dt
	end

	arrow.Rotation = baseArrowRotation - pointerDeflection
	prevWheelAngle = wheelAngle
end

local function applyAngle(angle)
	wheelAngle = angle
	wheel.Rotation = angle % 360
end

local LEVEL_UP_SOUND_ID = "rbxassetid://3120909354"
local EPIC_FANFARE_SOUND_ID = "rbxassetid://72264591133889"

local function playWinSound(isEpic: boolean)
	local sound = Instance.new("Sound")
	sound.Name = if isEpic then "SpinWheelEpicSound" else "SpinWheelWinSound"
	sound.SoundId = if isEpic then EPIC_FANFARE_SOUND_ID else LEVEL_UP_SOUND_ID
	sound.Volume = if isEpic then 0.9 else 0.75
	sound.PlaybackSpeed = 1.0
	sound.Parent = SoundService
	local played = pcall(function()
		SoundService:PlayLocalSound(sound)
	end)
	if not played then
		pcall(function() sound:Play() end)
	end
	task.delay(5, function()
		sound:Destroy()
	end)
end

local function celebrate(index, title)
	local slot = slots[index]
	UiShake.Wiggle(arrow, 14, 0.55, 11)
	if slot and slot.Icon then
		local scale = slot.Icon:FindFirstChild("WinPop") or Instance.new("UIScale")
		scale.Name = "WinPop"
		scale.Parent = slot.Icon
		scale.Scale = 1
		local grow = TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.45 })
		grow:Play()
		grow.Completed:Connect(function()
			TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end)
	end

	local segment = SpinWheelCatalog.Segments[index]
	local isEpic = segment and (segment.Rare == true or segment.Kind == "Exclusive" or segment.Rarity == "Mythic" or segment.Rarity == "Legendary")
	playWinSound(isEpic == true)

	if title then
		showMessage(title)
		timerLabel.TextColor3 = RESULT_COLOR
		task.delay(MESSAGE_SECONDS, function()
			timerLabel.TextColor3 = Color3.new(1, 1, 1)
		end)
	end
end

local skipOwned, skipOn = false, false
-- Skip Spin GamePass (Config.SpinWheel.SkipGamePassId = 1986854592):
-- Players who own it get Skip enabled. Players who do not own it are prompted to purchase
-- it when clicking the Skip toggle.

local function beginLanding(result)
	local slot = slots[tonumber(result.Index) or 0]
	if not slot then
		phase = "idle"
		renderState()
		return
	end
	-- Land somewhere inside the prize's sector, never on its edge.
	local jitter = (math.random() - 0.5) * halfSector
	local target = (POINTER_ANGLE - slot.Angle + jitter) % 360
	local skipping = skipOwned and skipOn
	-- Skipping still turns the wheel once, quickly, so the prize is seen arriving.
	local minimumTravel = if skipping then 360 else FREE_SPEED * SPIN_SECONDS / 5
	local travel = minimumTravel + (target - (wheelAngle + minimumTravel)) % 360
	-- Quintic ease-out starts at 5 * travel / duration; matching the free spin speed
	-- keeps the hand-off from waiting to landing seamless.
	local duration = if skipping then SKIP_SECONDS else math.clamp(5 * travel / FREE_SPEED, SPIN_SECONDS, SPIN_SECONDS + 2)
	landing = { From = wheelAngle, Travel = travel, Duration = duration, Started = os.clock(), Result = result }
	phase = "landing"
end

RunService.RenderStepped:Connect(function(dt)
	if phase == "waiting" then
		applyAngle(wheelAngle + FREE_SPEED * dt)
	elseif phase == "landing" and landing then
		local t = math.clamp((os.clock() - landing.Started) / landing.Duration, 0, 1)
		local eased = 1 - (1 - t) ^ 5
		applyAngle(landing.From + landing.Travel * eased)
		if t >= 1 then
			local result = landing.Result
			landing = nil
			phase = "celebrating"
			renderState()
			celebrate(tonumber(result.Index) or 0, result.Title)
			task.delay(MESSAGE_SECONDS, function()
				if phase == "celebrating" then
					phase = "idle"
					renderState()
				end
			end)
		end
	elseif phase == "idle" and isOpen then
		applyAngle(wheelAngle + IDLE_SPEED * dt)
	end

	if isOpen then
		updatePointer(dt)
	end
end)

local spinRequestedAt = 0
local function requestSpin()
	if phase ~= "idle" and phase ~= "celebrating" then
		return
	end
	if spinsAvailable() <= 0 then
		showMessage("No spins left!")
		if winsButton and winsButton.Visible then
			UiShake.Wiggle(winsButton, 10, 0.5, 9)
		end
		for _, pack in packs do
			if pack.Button.Visible then
				UiShake.Wiggle(pack.Button, 10, 0.5, 9)
			end
		end
		return
	end
	PurchaseButtonSound.Play()
	phase = "waiting"
	if labelsShowOdds then
		labelsShowOdds = false
		applyLabelTexts()
		fadeLabels(0, 0.1)
	end
	spinRequestedAt = os.clock()
	setButtonEnabled(spinButton, false)
	Request:FireServer({ action = "Spin" })
	task.delay(12, function()
		if phase == "waiting" and os.clock() - spinRequestedAt >= 11.9 then
			phase = "idle"
			showMessage("No answer from the server. Try again.")
			renderState()
		end
	end)
end

spinButton.Activated:Connect(requestSpin)

for key, pack in packs do
	pack.Button.Activated:Connect(function()
		PurchaseButtonSound.Play()
		Request:FireServer({ action = "Buy", key = key })
	end)
end

if winsButton then
	winsButton.Activated:Connect(function()
		local purchase = state and state.WinsPurchase
		if not purchase then
			return
		end
		PurchaseButtonSound.Play()
		if (tonumber(purchase.Remaining) or 0) <= 0 then
			showMessage("Wins spins refill in " .. formatClock((tonumber(purchase.ResetsAt) or 0) - serverNow()))
			UiShake.Wiggle(winsButton, 10, 0.45, 9)
			return
		end
		if (tonumber(purchase.Wins) or 0) < (tonumber(purchase.Cost) or 0) then
			showMessage("You need " .. SpinWheelCatalog.FormatNumber(tonumber(purchase.Cost) or 0) .. " Wins")
			UiShake.Wiggle(winsButton, 10, 0.45, 9)
			return
		end
		Request:FireServer({ action = "BuyWithWins" })
	end)
end

local function renderSkip()
	if not skipToggle then
		return
	end
	local on = skipOwned and skipOn
	skipTick.Visible = on
	if skipBoxFill then
		skipBoxFill.Color = if on then SKIP_ON_FILL else SKIP_OFF
	end
	for _, entry in skipBoxEdges do
		entry.Stroke.Color = if on then entry.OnColor else Color3.fromRGB(58, 62, 72)
		if entry.Edge then
			entry.Edge.Color = if on then entry.OnEdge else SKIP_OFF_EDGE
		end
	end
end

if skipToggle then
	SKIP_ON_FILL = skipBoxFill and skipBoxFill.Color
	renderSkip()
	skipToggle.Activated:Connect(function()
		PurchaseButtonSound.Play()
		if skipOwned then
			skipOn = not skipOn
			renderSkip()
			UiShake.Wiggle(skipBox, 8, 0.35, 9)
		elseif SKIP_PASS_ID then
			MarketplaceService:PromptGamePassPurchase(player, SKIP_PASS_ID)
		else
			showMessage("Skip pass (" .. tostring(settings.SkipPriceRobux or 79) .. " R$) coming soon!")
			UiShake.Wiggle(skipBox, 10, 0.45, 9)
		end
	end)
	if SKIP_PASS_ID then
		task.spawn(function()
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, SKIP_PASS_ID)
			end)
			if ok and owns == true and not skipOwned then
				-- Whoever bought Skip wants it on.
				skipOwned, skipOn = true, true
				renderSkip()
			end
		end)
		MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(buyer, passId, purchased)
			if buyer == player and tonumber(passId) == SKIP_PASS_ID and purchased then
				skipOwned, skipOn = true, true
				renderSkip()
				showMessage("Skip unlocked!")
				UiShake.Wiggle(skipBox, 10, 0.5, 10)
			end
		end)
	end
end

Update.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then
		return
	end
	if payload.Loading then
		if not state then
			state = payload
		end
		if payload.Message then
			showMessage(payload.Message)
		end
		renderState()
		return
	end
	state = payload
	stateReceivedAt = os.clock()
	if payload.Result and phase == "waiting" then
		beginLanding(payload.Result)
	elseif payload.Result == nil and phase == "waiting" and payload.Message then
		-- The spin was refused; nothing was spent.
		phase = "idle"
	end
	if payload.Message then
		showMessage(payload.Message)
	end
	if payload.Bought and spinCount then
		UiShake.Wiggle(spinButton, 8, 0.45, 10)
	end
	renderState()
end)

----------------------------------------------------------------------
-- Open / close
----------------------------------------------------------------------
local HOLDER_POSITION = wheelHolder.Position
local ROW_POSITION = row.Position
local OFFSCREEN = UDim2.fromScale(0, 1.1)
local OPEN_INFO = TweenInfo.new(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local CLOSE_INFO = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local closeSerial = 0

-- Phones and tablets get the compact layout (SpinWheelLayout.Compact): the wheel about 80%
-- of the screen's height in the middle, the buttons in two columns beside it, each at
-- least 44 px tall. Everywhere else the designer's layout, centred top to bottom
-- (SpinWheelLayout.CentreOffset). The designer's values are kept to go back to.
compactScale = wheelHolder:FindFirstChild("CompactScale")
if not (compactScale and compactScale:IsA("UIScale")) then
	compactScale = Instance.new("UIScale")
	compactScale.Name = "CompactScale"
	compactScale.Parent = wheelHolder
end
local rowShape = row:FindFirstChildOfClass("UIAspectRatioConstraint")
local ROW_ASPECT = if rowShape then rowShape.AspectRatio else 7.65
local AUTHORED_INSETS = gui.ScreenInsets
local authoredRow = { AnchorPoint = row.AnchorPoint, Size = row.Size, Shape = ROW_ASPECT }
local authoredPieces = {}
local function remember(object)
	if object and object:IsA("GuiObject") and not authoredPieces[object] then
		authoredPieces[object] = { Position = object.Position, Size = object.Size }
	end
end
for _, name in { "X1", "X3", "Claim", "TextLabel", "SkipToggle" } do
	remember(row:FindFirstChild(name))
end
local holderBase, rowBase = HOLDER_POSITION, ROW_POSITION

local function applyCompact(screen)
	local skip = row:FindFirstChild("SkipToggle")
	local skipAspect = nil
	if skip and authoredPieces[skip] and authoredPieces[skip].Size.Y.Scale > 0 then
		skipAspect = authoredPieces[skip].Size.X.Scale * ROW_ASPECT / authoredPieces[skip].Size.Y.Scale
	end
	local plan = SpinWheelLayout.Compact(measure, gui, row, screen.X, screen.Y, skipAspect)
	compactScale.Scale = plan.Scale
	holderBase = UDim2.fromOffset(math.floor(plan.Holder.X + 0.5), math.floor(plan.Holder.Y + 0.5))
	-- The row stretches over the screen so its buttons can stand in the two columns.
	row.AnchorPoint = Vector2.zero
	row.Size = UDim2.fromOffset(screen.X, screen.Y)
	if rowShape then
		rowShape.AspectRatio = screen.X / screen.Y
	end
	rowBase = UDim2.fromOffset(0, 0)
	for name, rect in plan.Rects do
		local inRow = row:FindFirstChild(name)
		local piece = inRow or wheelHolder:FindFirstChild(name)
		if piece and piece:IsA("GuiObject") then
			local scaled = if inRow then SpinWheelLayout.InRow(plan, rect) else SpinWheelLayout.InHolder(plan, rect)
			piece.Position = UDim2.fromScale(scaled.X, scaled.Y)
			piece.Size = UDim2.fromScale(scaled.Width, scaled.Height)
		end
	end
end

local function applyDesigner()
	compactScale.Scale = 1
	holderBase, rowBase = HOLDER_POSITION, ROW_POSITION
	row.AnchorPoint = authoredRow.AnchorPoint
	row.Size = authoredRow.Size
	if rowShape then
		rowShape.AspectRatio = authoredRow.Shape
	end
	for piece, values in authoredPieces do
		piece.Position = values.Position
		piece.Size = values.Size
	end
	placeWinsButton()
end

local centring = UDim2.new()
local slides = {}
local function slide(object, info, target)
	if slides[object] then
		slides[object]:Cancel()
	end
	local tween = TweenService:Create(object, info, { Position = target })
	slides[object] = tween
	tween:Play()
	return tween
end

local function layoutPanel()
	remember(row:FindFirstChild("SkipToggle"))
	-- Decided on the camera's viewport: the panel's own size changes with the insets below.
	local camera = Workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else gui.AbsoluteSize
	local useCompact = SpinWheelLayout.UseCompact(viewport.X, viewport.Y, UserInputService.TouchEnabled)
	-- Compact uses the whole screen, under Roblox's top bar too (the columns start below it).
	local insets = if useCompact then Enum.ScreenInsets.DeviceSafeInsets else AUTHORED_INSETS
	if gui.ScreenInsets ~= insets then
		gui.ScreenInsets = insets
	end
	local screen = gui.AbsoluteSize
	if screen.X <= 0 or screen.Y <= 0 then
		return
	end
	compact = useCompact
	if compact then
		applyCompact(screen)
		centring = UDim2.new()
	else
		applyDesigner()
		local offset = SpinWheelLayout.CentreOffset(measure, gui, row, HOLDER_POSITION, ROW_POSITION, screen.X, screen.Y)
		centring = UDim2.fromOffset(0, math.floor(offset + 0.5))
	end
	if isOpen then
		for object, tween in slides do
			tween:Cancel()
			slides[object] = nil
		end
		wheelHolder.Position = holderBase + centring
		row.Position = rowBase + centring
	end
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutPanel)

-- Gamepads: the panel's buttons lead to each other (Spin in the middle, the packs to its
-- right, the Wins spin below, the close X above), and Spin takes the selection on open.
local function linkGamepad()
	local packs = {}
	for _, name in { "X1", "X3" } do
		local button = row:FindFirstChild(name)
		if button and button:IsA("GuiButton") then
			table.insert(packs, button)
		end
	end
	local x10 = wheelHolder:FindFirstChild("X10")
	if x10 and x10:IsA("GuiButton") then
		table.insert(packs, x10)
	end
	local wins = wheelHolder:FindFirstChild("WinsSpin")
	for index, button in packs do
		button.Selectable = true
		button.NextSelectionLeft = spinButton
		button.NextSelectionUp = packs[index - 1] or closeButton
		button.NextSelectionDown = packs[index + 1] or button
	end
	spinButton.Selectable = true
	spinButton.NextSelectionRight = packs[1]
	spinButton.NextSelectionUp = closeButton
	if wins and wins:IsA("GuiButton") then
		wins.Selectable = true
		spinButton.NextSelectionDown = wins
		wins.NextSelectionUp = spinButton
		wins.NextSelectionRight = packs[#packs]
	end
	closeButton.Selectable = true
	closeButton.NextSelectionDown = spinButton
end
linkGamepad()

local function gamepadActive()
	return GuiService:IsTenFootInterface()
		or (UserInputService.GamepadEnabled and string.find(UserInputService:GetLastInputType().Name, "Gamepad") ~= nil)
end

local function openPanel()
	if isOpen then
		return
	end
	isOpen = true
	prevWheelAngle = wheelAngle
	pointerDeflection = 0
	pointerVelocity = 0
	closeSerial += 1
	MenuEvents.CloseAll:Fire("SpinWheel")
	if MenuEvents.SetHUDVisible then
		MenuEvents.SetHUDVisible(false, "SpinWheel")
	end
	gui.Enabled = true
	layoutPanel()
	wheelHolder.Position = holderBase + centring + OFFSCREEN
	row.Position = rowBase + centring + OFFSCREEN
	slide(wheelHolder, OPEN_INFO, holderBase + centring)
	slide(row, OPEN_INFO, rowBase + centring)
	-- `opened`: a new run of the Spin Wheel funnel in Creator Hub (SpinWheelService).
	Request:FireServer({ action = "State", opened = true })
	if SKIP_PASS_ID and not skipOwned then
		task.spawn(function()
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, SKIP_PASS_ID)
			end)
			if ok and owns == true and not skipOwned then
				skipOwned, skipOn = true, true
				renderSkip()
			end
		end)
	end
	renderState()
	if gamepadActive() then
		GuiService.GuiNavigationEnabled = true
		GuiService.SelectedObject = spinButton
	end
end

local function closePanel()
	if not isOpen then
		return
	end
	isOpen = false
	pointerDeflection = 0
	pointerVelocity = 0
	arrow.Rotation = baseArrowRotation
	closeSerial += 1
	local serial = closeSerial
	local selected = GuiService.SelectedObject
	if selected and selected:IsDescendantOf(gui) then
		GuiService.SelectedObject = nil
	end
	slide(wheelHolder, CLOSE_INFO, holderBase + centring + OFFSCREEN)
	local tween = slide(row, CLOSE_INFO, rowBase + centring + OFFSCREEN)
	tween.Completed:Connect(function()
		if serial == closeSerial and not isOpen then
			gui.Enabled = false
			-- The Main HUD comes back however the panel was closed (X, the dark background, Escape,
			-- another menu), unless another menu is open by now.
			if not MenuEvents.AnyOpen("SpinWheel") then
				MenuEvents.SetHUDVisible(true, nil)
			end
		end
	end)
end

closeButton.Activated:Connect(function()
	PurchaseButtonSound.Play()
	closePanel()
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if isOpen and (input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB) then
		closePanel()
	end
end)

MenuEvents.Get("OpenSpinWheelPanel").Event:Connect(function(action)
	if action == "Close" then
		closePanel()
	elseif action == "Open" then
		openPanel()
	elseif isOpen then
		closePanel()
	else
		openPanel()
	end
end)
MenuEvents.CloseAll.Event:Connect(function(except)
	if except ~= "SpinWheel" then
		closePanel()
	end
end)
MenuEvents.MarkReady("SpinWheel", function()
	return isOpen
end)

----------------------------------------------------------------------
-- The wheel in the lobby: the designer's wheel on a stand
----------------------------------------------------------------------
local placementKey = if Config.IsWorld2Place then "World2" elseif Config.IsWorld3Place then "World3" else "World1"
local placement = placementKey and settings.WorldPlacement and settings.WorldPlacement[placementKey]
local lobbyWheel, lobbyStatus = nil, nil

-- Find the model placed directly in the map:
local model = Workspace:FindFirstChild("SpinWheelLobby") or Workspace:FindFirstChild("SpinWheel")

-- If not already in the map, build it as fallback:
if not model and placement and typeof(placement.Position) == "Vector3" then
	local RADIUS = 6
	local floorPosition = placement.Position
	local facing = if typeof(placement.Face) == "Vector3"
		then (placement.Face - floorPosition) * Vector3.new(1, 0, 1)
		else Vector3.new(0, 0, 1)
	if facing.Magnitude < 0.1 then
		facing = Vector3.new(0, 0, 1)
	end
	facing = facing.Unit
	local centre = floorPosition + Vector3.new(0, RADIUS * 1.3 + 1.2, 0)
	-- The wheel's local +Z faces the spawn.
	local wheelFrame = CFrame.lookAt(centre, centre - facing)
	local flat = CFrame.lookAt(floorPosition, floorPosition - facing)

	model = Instance.new("Model")
	model.Name = "SpinWheelLobby"
	local function part(name, className, size, cframe, color, collide)
		local instance = Instance.new(className)
		instance.Name = name
		instance.Anchored = true
		instance.CanCollide = collide == true
		instance.CanQuery = collide == true
		instance.CanTouch = false
		instance.Material = Enum.Material.SmoothPlastic
		instance.Size = size
		instance.CFrame = cframe
		instance.Color = color
		instance.Parent = model
		return instance
	end

	-- The stand, in the game's blocky look: a studded navy plinth on a gold trim, two gold
	-- legs leaning in to the axle behind the wheel, and a navy and gold rim around it.
	local NAVY = Color3.fromRGB(38, 44, 74)
	local GOLD = Color3.fromRGB(255, 186, 0)
	local function studs(target, faces)
		for _, face in faces do
			local texture = Instance.new("Texture")
			texture.Texture = SpinWheelLayout.StudTexture
			texture.Face = face
			texture.StudsPerTileU = 2
			texture.StudsPerTileV = 2
			texture.Transparency = 0.7
			texture.Parent = target
		end
	end
	local postHeight = centre.Y - floorPosition.Y
	part("Trim", "Part", Vector3.new(RADIUS * 2.5, 0.4, RADIUS * 1.25), flat * CFrame.new(0, 0.2, -0.6), GOLD, true)
	local plinth = part("Plinth", "Part", Vector3.new(RADIUS * 2.3, 1.4, RADIUS * 1.05), flat * CFrame.new(0, 1.1, -0.6), NAVY, true)
	studs(plinth, { Enum.NormalId.Top, Enum.NormalId.Front, Enum.NormalId.Back })
	for _, side in { -1, 1 } do
		local bottom = Vector3.new(side * RADIUS * 0.95, 1.8, -1.1)
		local top = Vector3.new(side * 0.8, postHeight, -1.1)
		local up = (top - bottom).Unit
		local leg = part(if side < 0 then "LeftLeg" else "RightLeg", "Part", Vector3.new(1.1, (top - bottom).Magnitude + 1, 1.1),
			flat * CFrame.fromMatrix((top + bottom) / 2, up:Cross(Vector3.zAxis).Unit, up), GOLD, true)
		studs(leg, { Enum.NormalId.Front, Enum.NormalId.Back })
	end
	local axle = part("Axle", "Part", Vector3.new(1.6, 2.2, 2.2), wheelFrame * CFrame.new(0, 0, -1.1) * CFrame.Angles(0, math.rad(90), 0), GOLD, false)
	axle.Shape = Enum.PartType.Cylinder
	local outerRim = part("GoldRim", "Part", Vector3.new(0.3, RADIUS * 2.32, RADIUS * 2.32), wheelFrame * CFrame.new(0, 0, -0.55) * CFrame.Angles(0, math.rad(90), 0), GOLD, false)
	outerRim.Shape = Enum.PartType.Cylinder
	outerRim.Material = Enum.Material.Neon
	local innerRim = part("NavyRim", "Part", Vector3.new(0.35, RADIUS * 2.18, RADIUS * 2.18), wheelFrame * CFrame.new(0, 0, -0.35) * CFrame.Angles(0, math.rad(90), 0), NAVY, false)
	innerRim.Shape = Enum.PartType.Cylinder
	local backing = part("Backing", "Part", Vector3.new(0.5, RADIUS * 2.04, RADIUS * 2.04), wheelFrame * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(245, 245, 250), false)
	backing.Shape = Enum.PartType.Cylinder

	local ART_SHARE = 0.84
	local faceStuds = RADIUS * 2 / ART_SHARE
	local face = part("Face", "Part", Vector3.new(faceStuds, faceStuds, 0.05), wheelFrame * CFrame.new(0, 0, 0.3), Color3.new(1, 1, 1), false)
	face.Transparency = 1

	local overhead = part("Overhead", "Part", Vector3.new(1, 1, 1), CFrame.new(centre + Vector3.new(0, RADIUS * 1.6, 0)), Color3.new(1, 1, 1), false)
	overhead.Transparency = 1

	local promptAnchor = part("PromptAnchor", "Part", Vector3.new(1, 1, 1), flat * CFrame.new(0, 3, RADIUS * 0.9), Color3.new(1, 1, 1), false)
	promptAnchor.Transparency = 1

	model.PrimaryPart = plinth
	model.Parent = Workspace
end

if model then
	local face = model:FindFirstChild("Face")
	local surface = face and face:FindFirstChild("Wheel")
	if face and not surface then
		surface = Instance.new("SurfaceGui")
		surface.Name = "Wheel"
		surface.Face = Enum.NormalId.Back
		surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		surface.PixelsPerStud = 45
		surface.LightInfluence = 0
		surface.MaxDistance = 220
		surface.ZIndexBehavior = gui.ZIndexBehavior
		surface.Parent = face
	elseif surface then
		surface.ZIndexBehavior = gui.ZIndexBehavior
	end

	if surface then
		local holder = surface:FindFirstChild("Frame") or surface:FindFirstChildOfClass("Frame")
		if not holder then
			holder = wheelHolder:Clone()
			for _, name in { "Close", "WinsSpin", "WinsCaption" } do
				local extra = holder:FindFirstChild(name)
				if extra then
					extra:Destroy()
				end
			end
			local ART_SHARE = 0.84
			local holderHeight = ART_SHARE / (measure.ArtRadius * 2)
			holder.AnchorPoint = Vector2.new(0, 0)
			holder.Size = UDim2.fromScale(holderHeight * measure.Ratio, holderHeight)
			holder.Position = UDim2.fromScale(0.5 - measure.WheelCenter.x * holderHeight, 0.5 - measure.WheelCenter.y * holderHeight)
			holder.Parent = surface
		end
		lobbyWheel = holder:FindFirstChild("Spin Wheel")
	end

	local overhead = model:FindFirstChild("Overhead")
	local billboard = overhead and overhead:FindFirstChild("Billboard")
	if overhead and not billboard then
		billboard = Instance.new("BillboardGui")
		billboard.Name = "Billboard"
		billboard.Size = UDim2.fromScale(14, 4.4)
		billboard.MaxDistance = 160
		billboard.LightInfluence = 0
		billboard.Parent = overhead
		local title = timerLabel:Clone()
		title.Name = "Title"
		title.AnchorPoint = Vector2.new(0.5, 0)
		title.Position = UDim2.fromScale(0.5, 0)
		title.Size = UDim2.fromScale(1, 0.6)
		title.Text = "SPIN WHEEL"
		title.Parent = billboard
		lobbyStatus = timerLabel:Clone()
		lobbyStatus.Name = "Status"
		lobbyStatus.AnchorPoint = Vector2.new(0.5, 0)
		lobbyStatus.Position = UDim2.fromScale(0.5, 0.62)
		lobbyStatus.Size = UDim2.fromScale(1, 0.38)
		lobbyStatus.Text = ""
		lobbyStatus.Parent = billboard
		for _, label in { title, lobbyStatus } do
			local constraint = label:FindFirstChildOfClass("UIAspectRatioConstraint")
			if constraint then
				constraint:Destroy()
			end
		end
	elseif billboard then
		lobbyStatus = billboard:FindFirstChild("Status") or billboard:FindFirstChild("TextLabel", true)
	end

	local prompt = model:FindFirstChildWhichIsA("ProximityPrompt", true)
	if not prompt then
		local promptAnchor = model:FindFirstChild("PromptAnchor") or model.PrimaryPart or model:FindFirstChild("Plinth") or model:FindFirstChild("Trim")
		if promptAnchor then
			prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "Spin"
			prompt.ObjectText = "Spin Wheel"
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = 16
			prompt.RequiresLineOfSight = false
			prompt.Parent = promptAnchor
		end
	end
	if prompt then
		prompt.Triggered:Connect(function()
			Request:FireServer({ action = "State", opened = true })
			MenuEvents.Request("SpinWheel")
		end)
	end

	local idleAngle = 0
	RunService.RenderStepped:Connect(function(dt)
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		local centre = if model.PrimaryPart then model.PrimaryPart.Position else (face and face.Position or Vector3.zero)
		if not rootPart or (rootPart.Position - centre).Magnitude > 200 then
			return
		end
		if lobbyWheel then
			idleAngle = (idleAngle + dt * 14) % 360
			lobbyWheel.Rotation = idleAngle
		end
	end)
end

----------------------------------------------------------------------
-- The Main HUD button: beside x2 Speed, on the right of the screen
----------------------------------------------------------------------
-- The small copy of the wheel (its colours and hub cap, no prizes) turning slowly, with no
-- button behind it, its text under it and the designer's "!" badge: the label and badge
-- come from the Time Gifts button. Its text follows the wheel's state
-- (SpinWheelCatalog.HudButton); a click opens this panel.
--
-- It stands left of x2 Speed, level with it (SpinWheelLayout.HudButtonPlace), following
-- that button every frame, so it slides away with the right buttons when a menu opens and
-- scales with them on phones. It lives in Mainhud itself: inside Rightbuttons their list
-- layout would stack it with them. When x2 Speed is hidden (all bought) it follows x2
-- Victory; with both hidden, the right buttons' frame.
local HUD_BUTTON_NAME = "SpinWheel"
local HUD_WHEEL_DEGREES_PER_SECOND = 45
local HUD_BADGE_SHARE = 0.55
local HUD_BADGE_POSITION = UDim2.fromScale(0.8, 0.13)
local HUD_HOVER_INFO = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local hudButton, hudLabel, hudBadge, hudBadgeLabel, hudSpinner = nil, nil, nil, nil, nil
local hudMainhud, hudRightButtons = nil, nil

-- The Robux price of the smallest spin pack, when spins are for sale to this player.
local function smallestPackPrice()
	if not state or state.PaidSpinsAllowed ~= true then
		return nil
	end
	local price, fewest = nil, math.huge
	for _, product in state.Products or {} do
		local spins = tonumber(product.Spins) or math.huge
		if spins < fewest then
			local productId = tonumber(product.ProductId)
			price = (productId and livePrices[productId]) or tonumber(product.PriceRobux)
			fewest = spins
		end
	end
	return price
end

function refreshHudButton()
	if not hudButton then
		return
	end
	local loading = not state or state.Loading == true
	local text, badge = SpinWheelCatalog.HudButton({
		Loading = loading,
		FreeAvailable = not loading and state.FreeAvailable == true,
		Tickets = if loading then 0 else tonumber(state.Tickets),
		SecondsToFree = if loading then 0 else (tonumber(state.NextFreeAt) or 0) - serverNow(),
		PriceRobux = smallestPackPrice(),
		ShowPrice = math.floor(os.clock() / LABEL_SWAP_SECONDS) % 2 == 1,
	})
	hudLabel.Text = text
	if hudBadge then
		hudBadge.Visible = badge ~= nil
		if hudBadgeLabel and badge then
			hudBadgeLabel.Text = badge
		end
	end
end

local function buildHudButton(mainhud)
	if mainhud:FindFirstChild(HUD_BUTTON_NAME) then
		return
	end
	local leftBar = mainhud:FindFirstChild("LeftSideBar")
	local template = leftBar and leftBar:FindFirstChild("Time Gifts")
	if not (template and template:IsA("ImageButton")) then
		template = leftBar and leftBar:FindFirstChildWhichIsA("ImageButton")
	end
	if not template then
		return
	end
	local button = template:Clone()
	button.Name = HUD_BUTTON_NAME
	local label = button:FindFirstChild("Name")
	local icon = button:FindFirstChild("Icon")
	if not (label and label:IsA("TextLabel") and icon and icon:IsA("ImageLabel")) then
		button:Destroy()
		return
	end

	-- No button behind the wheel: no image, fill, corners or outline of its own.
	button.ImageTransparency = 1
	button.BackgroundTransparency = 1
	button.AutoButtonColor = false
	for _, child in button:GetChildren() do
		if child:IsA("UIStroke") or child:IsA("UICorner") or child:IsA("UIGradient") then
			child:Destroy()
		end
	end
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Rotation = 0

	-- The template's icon keeps its place and size and holds the turning wheel instead.
	icon.ImageTransparency = 1
	for _, child in icon:GetChildren() do
		if not child:IsA("UIAspectRatioConstraint") then
			child:Destroy()
		end
	end
	local spinner = Instance.new("Frame")
	spinner.Name = "Spinner"
	spinner.BackgroundTransparency = 1
	spinner.AnchorPoint = Vector2.new(0.5, 0.5)
	spinner.Position = UDim2.fromScale(0.5, 0.5)
	spinner.Size = UDim2.fromScale(1, 1)
	spinner.Parent = icon
	-- The panel's wheel, prizes left out, sized so its art fills the icon, with the art's
	-- centre on the spinner's centre so it turns in place.
	local mini = wheel:Clone()
	local prizes = mini:FindFirstChild("Spin")
	if prizes then
		prizes:Destroy()
	end
	local diameter = 2 * measure.ArtRadius
	mini.AnchorPoint = Vector2.new(0, 0)
	mini.Rotation = 0
	mini.Size = UDim2.fromScale(measure.WheelWidth / diameter, measure.WheelHeight / diameter)
	mini.Position = UDim2.fromScale(0.5 - measure.ArtCenter.x / diameter, 0.5 - measure.ArtCenter.y / diameter)
	mini.Parent = spinner
	local panelCap = wheelHolder:FindFirstChild("HubCap")
	if panelCap then
		local cap = panelCap:Clone()
		cap.AnchorPoint = Vector2.new(0.5, 0.5)
		cap.Position = UDim2.fromScale(0.5, 0.5)
		cap.Size = UDim2.fromScale(2 * SpinWheelLayout.HubCapRadiusShare, 2 * SpinWheelLayout.HubCapRadiusShare)
		cap.ZIndex = spinner.ZIndex + 1
		cap.Parent = icon
	end

	-- A little zoom under the mouse, like the other HUD buttons.
	local hoverScale = Instance.new("UIScale")
	hoverScale.Name = "HoverScale"
	hoverScale.Parent = icon
	button.MouseEnter:Connect(function()
		TweenService:Create(hoverScale, HUD_HOVER_INFO, { Scale = 1.15 }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(hoverScale, HUD_HOVER_INFO, { Scale = 1 }):Play()
	end)
	button.Activated:Connect(function()
		PurchaseButtonSound.Play()
		MenuEvents.Request("SpinWheel")
	end)

	label.Text = "Spin"
	hudBadge = button:FindFirstChild("!")
	hudBadgeLabel = hudBadge and hudBadge:FindFirstChildOfClass("TextLabel")
	if hudBadge then
		hudBadge.Visible = false
		hudBadge.ZIndex = icon.ZIndex + 1
		-- A small badge on the wheel's top-right edge: the side bar's full-size one covered
		-- half of the wheel.
		hudBadge.Size = UDim2.fromScale(hudBadge.Size.X.Scale * HUD_BADGE_SHARE, hudBadge.Size.Y.Scale * HUD_BADGE_SHARE)
		hudBadge.Position = HUD_BADGE_POSITION
	end
	hudButton, hudLabel, hudSpinner = button, label, spinner
	hudMainhud, hudRightButtons = mainhud, mainhud:FindFirstChild("Rightbuttons")
	button.Parent = mainhud
	refreshHudButton()
end

-- Beside x2 Speed (or x2 Victory, or the right buttons' frame), in Mainhud's own pixels.
local function placeHudButton()
	local anchor = nil
	if hudRightButtons then
		for _, name in { "2xSpeed", "2xVictory" } do
			local candidate = hudRightButtons:FindFirstChild(name)
			if not anchor and candidate and candidate:IsA("GuiObject") and candidate.Visible then
				anchor = candidate
			end
		end
	end
	local origin = hudMainhud.AbsolutePosition
	local x, y, side
	if anchor then
		x, y, side = SpinWheelLayout.HudButtonPlace(anchor.AbsolutePosition.X - origin.X, anchor.AbsolutePosition.Y - origin.Y, anchor.AbsoluteSize.Y)
	elseif hudRightButtons then
		local frameHeight = hudRightButtons.AbsoluteSize.Y * SpinWheelLayout.HudButtonFallbackRowShare
		x, y, side = SpinWheelLayout.HudButtonPlace(
			hudRightButtons.AbsolutePosition.X + hudRightButtons.AbsoluteSize.X - origin.X,
			hudRightButtons.AbsolutePosition.Y - origin.Y,
			frameHeight
		)
	else
		return
	end
	local position = UDim2.fromOffset(x, y)
	local size = UDim2.fromOffset(side, side)
	if hudButton.Position ~= position then
		hudButton.Position = position
	end
	if hudButton.Size ~= size then
		hudButton.Size = size
	end
end

task.spawn(function()
	local mainhud = player:WaitForChild("PlayerGui"):WaitForChild("Mainhud", 60)
	if mainhud then
		mainhud:WaitForChild("LeftSideBar", 30)
		mainhud:WaitForChild("Rightbuttons", 30)
		local deadline = os.clock() + 30
		while os.clock() < deadline and not hudButton do
			buildHudButton(mainhud)
			if hudButton then
				break
			end
			task.wait(0.5)
		end
	end
end)

RunService.RenderStepped:Connect(function()
	if hudSpinner then
		hudSpinner.Rotation = os.clock() * HUD_WHEEL_DEGREES_PER_SECOND % 360
		placeHudButton()
	end
end)

-- Countdown, the lobby billboard, the lobby wheel's labels and the HUD button, once a
-- second.
local lastStatePoll = 0
task.spawn(function()
	while gui.Parent do
		refreshTimer()
		refreshHudButton()
		if (isOpen or not state or state.Loading) and (os.clock() - lastStatePoll >= 2) then
			lastStatePoll = os.clock()
			Request:FireServer({ action = "State", opened = isOpen })
		end
		if lobbyStatus then
			if not state or state.Loading then
				lobbyStatus.Text = ""
			elseif spinsAvailable() > 0 then
				lobbyStatus.Text = "SPIN NOW!"
				lobbyStatus.TextColor3 = Color3.fromRGB(120, 255, 90)
			else
				lobbyStatus.Text = "Free spin in " .. formatClock((tonumber(state.NextFreeAt) or 0) - serverNow())
				lobbyStatus.TextColor3 = Color3.new(1, 1, 1)
			end
		end
		if lobbyWheel then
			-- The lobby wheel mirrors the panel's prize texts and icons.
			local lobbySpin = lobbyWheel:FindFirstChild("Spin")
			for _, slot in slots do
				local mirror = lobbySpin and lobbySpin:FindFirstChild(slot.Slice.Name)
				if mirror then
					local label = mirror:FindFirstChildOfClass("TextLabel")
					local icon = mirror:FindFirstChildOfClass("ImageLabel")
					if label and slot.Label then
						label.Text = slot.Label.Text
					end
					if icon and slot.Icon then
						icon.Image = slot.Icon.Image
						icon.ScaleType = slot.Icon.ScaleType
					end
				end
			end
		end
		task.wait(1)
	end
end)

-- Amount, then odds, on every prize while the wheel rests.
task.spawn(function()
	while gui.Parent do
		task.wait(LABEL_SWAP_SECONDS)
		if phase == "idle" and next(labelTexts) ~= nil then
			fadeLabels(1, 0.15)
			task.wait(0.16)
			if phase == "idle" then
				labelsShowOdds = not labelsShowOdds
			else
				labelsShowOdds = false
			end
			applyLabelTexts()
			fadeLabels(0, 0.15)
		end
	end
end)

player:GetAttributeChangedSignal("DataLoaded"):Connect(function()
	if player:GetAttribute("DataLoaded") == true and (not state or state.Loading) then
		Request:FireServer({ action = "State" })
	end
end)

-- The lobby billboard needs the state before anyone opens the panel.
task.delay(1, function()
	Request:FireServer({ action = "State" })
end)

print("[SpinWheelController] ready | slices=" .. #slots .. " | pointer=" .. string.format("%.1f", POINTER_ANGLE) .. " | lobby wheel=" .. tostring(placementKey))
