--[[
	MainHUDController – wires the designer-made Mainhud frame.
	Replaces: LeftButtonMenu, RebirthCounterHUD, BottomProgressImage
	Rebirth/trof  →  Rebirths + Wins counters
	LevelProgressBar  →  level, exp progress bar, speed text, buy-speed buttons
	SpeedsterBar  →  stamina bar for shift-to-run boost
	LeftSideBar  →  menu buttons that fire MenuEvents.Request()
	Rightbuttons  →  2xSpeed / 2xVictory permanent multiplier shop prompts
]]

local GuiService = game:GetService("GuiService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local MenuEvents = require(Shared:WaitForChild("MenuEvents"))
local PurchaseButtonSound = require(Shared:WaitForChild("PurchaseButtonSound"))
local ModalJuice = require(Shared:WaitForChild("ModalJuice"))


local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local LevelProgressUpdate = Remotes:WaitForChild("LevelProgressUpdate")

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------
local SUFFIXES = {"", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc", "Ud", "Dd", "Td", "Qad", "Qid", "Sxd", "Spd", "Ocd", "Nod", "Vg"}

local function formatNumber(value)
	value = tonumber(value) or 0
	if value < 1000 then
		return tostring(math.floor(value))
	end
	local tier = math.floor(math.log10(math.max(1, value)) / 3) + 1
	if tier <= #SUFFIXES then
		local scaled = value / (1000 ^ (tier - 1))
		if scaled >= 100 then
			return string.format("%.0f%s", scaled, SUFFIXES[tier])
		elseif scaled >= 10 then
			return string.format("%.1f%s", scaled, SUFFIXES[tier]):gsub("%.0", "")
		else
			return string.format("%.2f%s", scaled, SUFFIXES[tier]):gsub("0+$", ""):gsub("%.$", "")
		end
	end
	return string.format("%.2e", value)
end

local function formatAmount(value)
	local text = tostring(math.max(0, math.floor(tonumber(value) or 0)))
	while true do
		local changed
		text, changed = text:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		if changed == 0 then
			return text
		end
	end
end

local function cleanSpeed(value)
	value = tonumber(value)
	if value == nil or value ~= value or value == math.huge or value == -math.huge then
		return nil
	end
	return math.max(0, value)
end

----------------------------------------------------------------------
-- Wait for Mainhud
----------------------------------------------------------------------
local mainhud = playerGui:WaitForChild("Mainhud", 30)
if not mainhud then
	warn("[MainHUDController] Mainhud not found in PlayerGui")
	return
end

-- legacy Ability screen is replaced by AbilitiesPanel; keep it disabled
local legacyAbility = playerGui:FindFirstChild("Ability")
if legacyAbility then
	legacyAbility.Enabled = false
end
task.spawn(function()
	while player.Parent do
		local legacy = playerGui:FindFirstChild("Ability")
		if legacy and legacy.Enabled then
			legacy.Enabled = false
		end
		task.wait(1)
	end
end)

----------------------------------------------------------------------
-- 1) Rebirth / Wins counters  (Rebith/trof)
----------------------------------------------------------------------
local rebithTrof = mainhud:WaitForChild("Rebith/trof")
local rebirthLabel = nil
for _, c in ipairs(rebithTrof:GetChildren()) do
	if c:IsA("TextLabel") and c.Name == "Rebirth" then
		rebirthLabel = c
		break
	end
end
if not rebirthLabel then
	local candidate = rebithTrof:WaitForChild("Rebirth")
	if candidate:IsA("TextLabel") then
		rebirthLabel = candidate
	else
		for _, c in ipairs(rebithTrof:GetChildren()) do
			if c:IsA("TextLabel") then
				rebirthLabel = c
				break
			end
		end
	end
end
local victoryLabel = rebithTrof:WaitForChild("Victory")

local lastRebirths = nil
local lastWins = nil

local function readStat(name)
	if name == "Rebirths" then
		local attr = player:GetAttribute("Rebirths")
		if typeof(attr) == "number" then
			return attr
		end
	end
	local leaderstats = player:FindFirstChild("leaderstats")
	local value = leaderstats and leaderstats:FindFirstChild(name)
	if value and value:IsA("ValueBase") then
		return tonumber(value.Value) or 0
	end
	return 0
end

local function refreshRebirthWins()
	local rebirths = readStat("Rebirths")
	local wins = readStat("Wins")
	rebirthLabel.Text = formatNumber(rebirths):lower()
	victoryLabel.Text = formatNumber(wins):lower()

	if lastRebirths and rebirths > lastRebirths then
		local pulse = rebithTrof:FindFirstChild("RebirthPulse")
		if pulse and pulse:IsA("UIScale") then
			pulse.Scale = 1.18
			TweenService:Create(pulse, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
		end
	end
	if lastWins and wins > lastWins then
		local pulse = rebithTrof:FindFirstChild("WinsPulse")
		if pulse and pulse:IsA("UIScale") then
			pulse.Scale = 1.18
			TweenService:Create(pulse, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
		end
	end

	lastRebirths = rebirths
	lastWins = wins
end

player:GetAttributeChangedSignal("Rebirths"):Connect(refreshRebirthWins)

local function hookLeaderstats()
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then return end
	for _, name in ipairs({"Rebirths", "Wins"}) do
		local value = leaderstats:FindFirstChild(name)
		if value and value:IsA("ValueBase") then
			value:GetPropertyChangedSignal("Value"):Connect(refreshRebirthWins)
		end
	end
end

player.ChildAdded:Connect(function(child)
	if child.Name == "leaderstats" then
		hookLeaderstats()
		refreshRebirthWins()
	end
end)

task.defer(function()
	hookLeaderstats()
	refreshRebirthWins()
end)

task.spawn(function()
	for _ = 1, 40 do
		task.wait(0.25)
		hookLeaderstats()
	end
end)

----------------------------------------------------------------------
-- 2) Level Progress Bar  (LevelProgressBar.Frame)
----------------------------------------------------------------------
local levelProgressBar = mainhud:WaitForChild("LevelProgressBar")
local levelFrame = levelProgressBar:WaitForChild("Frame")
local levelLabel = levelFrame:WaitForChild("Level")
local expLabel = levelFrame:WaitForChild("Exp")
local speedLabel = levelFrame:WaitForChild("Speed")
local fill = levelFrame:WaitForChild("Fill")

local lastLevel = nil
local speedUpdateSerial = 0
local lastCommittedSpeed = nil
local SPEED_TEXT_FALLBACK_SECONDS = 1.15

local function readSpeedAmount()
	local leaderstats = player:FindFirstChild("leaderstats")
	local speed = leaderstats and leaderstats:FindFirstChild("Speed")
	if speed and speed:IsA("ValueBase") then
		return tonumber(speed.Value) or 1
	end
	local dataFolder = player:FindFirstChild("SpeedsterData")
	local rawSpeed = dataFolder and dataFolder:FindFirstChild("RawSpeed")
	if rawSpeed and rawSpeed:IsA("ValueBase") then
		return tonumber(rawSpeed.Value) or 1
	end
	local attr = player:GetAttribute("RawSpeed")
	if typeof(attr) == "number" then
		return attr
	end
	return 1
end

local speedUpdatePending = false

local function commitSpeedText(explicitSpeed)
	local actualSpeed = cleanSpeed(readSpeedAmount()) or 1
	local displaySpeed = (explicitSpeed ~= nil and cleanSpeed(explicitSpeed)) or actualSpeed
	lastCommittedSpeed = displaySpeed
	speedLabel.Text = "Speed: " .. formatNumber(displaySpeed)
end

local function scheduleSpeedTextUpdate(forceInstant)
	if forceInstant or lastCommittedSpeed == nil then
		commitSpeedText()
		return
	end
	if speedUpdatePending then return end
	speedUpdatePending = true
	task.defer(function()
		speedUpdatePending = false
		commitSpeedText()
	end)
end

local impactEvent = levelFrame:FindFirstChild("World1SpeedGainImpact")
if not impactEvent then
	impactEvent = Instance.new("BindableEvent")
	impactEvent.Name = "World1SpeedGainImpact"
	impactEvent.Parent = levelFrame
end
impactEvent.Event:Connect(function(newSpeed)
	speedUpdateSerial += 1
	if newSpeed and tonumber(newSpeed) then
		commitSpeedText(newSpeed)
	else
		commitSpeedText()
	end
end)

local function hookSpeedSources()
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local speedVal = leaderstats:FindFirstChild("Speed")
		if speedVal and speedVal:IsA("ValueBase") then
			speedVal:GetPropertyChangedSignal("Value"):Connect(function()
				scheduleSpeedTextUpdate(lastCommittedSpeed == nil)
			end)
		end
		leaderstats.ChildAdded:Connect(function(child)
			if child.Name == "Speed" and child:IsA("ValueBase") then
				child:GetPropertyChangedSignal("Value"):Connect(function()
					scheduleSpeedTextUpdate(false)
				end)
			end
		end)
	end
	local dataFolder = player:FindFirstChild("SpeedsterData")
	if dataFolder then
		local rawSpeed = dataFolder:FindFirstChild("RawSpeed")
		if rawSpeed and rawSpeed:IsA("ValueBase") then
			rawSpeed:GetPropertyChangedSignal("Value"):Connect(function()
				scheduleSpeedTextUpdate(false)
			end)
		end
	end
	player:GetAttributeChangedSignal("RawSpeed"):Connect(scheduleSpeedTextUpdate)
end

player.ChildAdded:Connect(function(child)
	if child.Name == "leaderstats" or child.Name == "SpeedsterData" then
		task.defer(hookSpeedSources)
		task.defer(function() scheduleSpeedTextUpdate(true) end)
	end
end)

task.defer(function()
	hookSpeedSources()
	scheduleSpeedTextUpdate(true)
end)

-- Watchdog: the Speed label kept showing the designer default "Speed: 1"
-- because no source signal fired after the value was set. Poll the real
-- speed source and only write when it differs from what's displayed.
task.spawn(function()
	while player.Parent do
		task.wait(0.75)
		local v = cleanSpeed(readSpeedAmount()) or 1
		if v ~= lastCommittedSpeed then
			commitSpeedText(v)
		end
	end
end)

local function applyLevelProgress(data, instant)
	local level = tonumber(data.Level) or player:GetAttribute("Level") or 1
	local progress = tonumber(data.Progress) or player:GetAttribute("LevelProgress") or 0
	local required = tonumber(data.Required) or player:GetAttribute("LevelRequirement") or 10

	required = math.max(1, required)
	progress = math.clamp(progress, 0, required)
	local ratio = math.clamp(progress / required, 0, 1)

	levelLabel.Text = tostring(math.floor(level))
	expLabel.Text = formatNumber(progress) .. "/" .. formatNumber(required)
	scheduleSpeedTextUpdate(instant == true)

	local tweenTime = instant and 0 or 0.18
	TweenService:Create(fill, TweenInfo.new(tweenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromScale(ratio, 1),
	}):Play()

	if lastLevel and level > lastLevel then
		levelLabel.Size = UDim2.fromOffset(94, 54)
		TweenService:Create(levelLabel, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(86, 48),
		}):Play()
	end
	lastLevel = level
end

LevelProgressUpdate.OnClientEvent:Connect(function(data)
	if type(data) == "table" then
		applyLevelProgress(data, false)
	end
end)

local function syncLevelFromAttributes()
	applyLevelProgress({
		Level = player:GetAttribute("Level") or 1,
		Progress = player:GetAttribute("LevelProgress") or 0,
		Required = player:GetAttribute("LevelRequirement") or 10,
	}, false)
end

player:GetAttributeChangedSignal("Level"):Connect(syncLevelFromAttributes)
player:GetAttributeChangedSignal("LevelProgress"):Connect(syncLevelFromAttributes)
player:GetAttributeChangedSignal("LevelRequirement"):Connect(syncLevelFromAttributes)
player:GetAttributeChangedSignal("Rebirths"):Connect(syncLevelFromAttributes)

task.defer(function()
	task.wait(1)
	local needsInitialSync = lastLevel == nil
	applyLevelProgress({
		Level = player:GetAttribute("Level") or 1,
		Progress = player:GetAttribute("LevelProgress") or 0,
		Required = player:GetAttribute("LevelRequirement") or 10,
	}, needsInitialSync)
end)

----------------------------------------------------------------------
-- Hover/touch animation helpers (must be defined before Speedbuy)
----------------------------------------------------------------------
local HOVER_TWEEN_IN = TweenInfo.new(0.20, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local HOVER_TWEEN_OUT = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function setupIconHoverWithRotation(button, scaleIn, scaleOut, rotDeg)
	if not button or not button:IsA("ImageButton") then return end
	scaleIn = scaleIn or 1.18
	scaleOut = scaleOut or 1.0
	rotDeg = rotDeg or 4

	local icon = button:FindFirstChild("Icon") or button:FindFirstChild("ImageLabel") or button:FindFirstChildOfClass("ImageLabel")
	if not icon or not icon:IsA("ImageLabel") then return end

	local hoverScale = icon:FindFirstChild("HoverScale")
	if not hoverScale or not hoverScale:IsA("UIScale") then
		hoverScale = Instance.new("UIScale")
		hoverScale.Name = "HoverScale"
		hoverScale.Scale = scaleOut
		hoverScale.Parent = icon
	end

	local activeTweenS = nil
	local activeTweenR = nil
	local isHovered = false

	local function setZoomRotate(hovered)
		if isHovered == hovered then return end
		isHovered = hovered

		if activeTweenS then activeTweenS:Cancel(); activeTweenS = nil end
		if activeTweenR then activeTweenR:Cancel(); activeTweenR = nil end

		local targetScale = hovered and scaleIn or scaleOut
		local targetRot = hovered and rotDeg or 0
		local tweenInfo = hovered and HOVER_TWEEN_IN or HOVER_TWEEN_OUT

		activeTweenS = TweenService:Create(hoverScale, tweenInfo, { Scale = targetScale })
		activeTweenR = TweenService:Create(icon, tweenInfo, { Rotation = targetRot })
		activeTweenS:Play()
		activeTweenR:Play()
	end

	button.MouseEnter:Connect(function() setZoomRotate(true) end)
	button.MouseLeave:Connect(function() setZoomRotate(false) end)
	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			setZoomRotate(true)
		end
	end)
	button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			setZoomRotate(false)
		end
	end)
	button.SelectionGained:Connect(function() setZoomRotate(true) end)
	button.SelectionLost:Connect(function() setZoomRotate(false) end)
end

local SHOP_BOUNCE_INTERVAL = 6
local SHOP_BOUNCE_SCALE = 1.22
local SHOP_BOUNCE_ROT = 5
local SHOP_BOUNCE_IN = TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local SHOP_BOUNCE_MID = TweenInfo.new(0.10, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local SHOP_BOUNCE_OUT = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

----------------------------------------------------------------------
-- 3) Buy Speed buttons  (Speedbuy.Buy1Speed - Buy4Speed)
----------------------------------------------------------------------
local speedbuyFrame = levelFrame:FindFirstChild("Speedbuy")
	or mainhud:FindFirstChild("Speedbuy", true)
	or mainhud:WaitForChild("Speedbuy", 10)
local speedTiers = Config.SpeedProductTiers or {}
local speedPromptBusy = false

local function displaySpeedGain(tierData, currentSpeed)
	currentSpeed = tonumber(currentSpeed) or 1
	local mult = tonumber(tierData.GainMultiplier) or 0
	local minGain = tonumber(tierData.MinGain)
		or (tierData.Tier == 1 and 500
			or tierData.Tier == 2 and 2500
			or tierData.Tier == 3 and 10000
			or tierData.Tier == 4 and 50000
			or 100)
	local percentGain = mult > 0 and (currentSpeed * mult) or 0
	local raw = math.max(minGain, percentGain)
	local step = math.max(1, tonumber(Config.SpeedProductDisplayRoundDownStep) or 10)
	if raw < 1000 then
		if raw >= step then
			return math.max(step, math.round(raw / step) * step)
		end
		return math.max(1, math.floor(raw + 0.5))
	end
	local tier = math.floor(math.log10(raw) / 3) + 1
	local base = 1000 ^ math.max(0, tier - 1)
	local scaled = raw / base
	local cleanedScaled
	if scaled >= 10 then
		cleanedScaled = math.max(10, math.round(scaled / 10) * 10)
	else
		cleanedScaled = math.max(1, math.floor(scaled))
	end
	return cleanedScaled * base
end

local function isGamePassId(productId, explicitFlag)
	if explicitFlag ~= nil then
		return explicitFlag == true
	end
	local pid = tonumber(productId) or 0
	if pid <= 0 then return false end
	if pid == tonumber(Config.TwoXSpeedGamePassId)
		or pid == tonumber(Config.DoubleWinsPadGamePassId)
		or pid == tonumber(Config.TwoXVictoryGamePassId)
		or pid == tonumber(Config.StarterPackGamePassId)
		or pid == tonumber(Config.InfiniteRevivesGamePassId)
		or pid == tonumber(Config.VipGamePassId)
		or pid == tonumber(Config.ValentineTreadmillPassId)
		or pid == tonumber(Config.AbilityFlightGamePassId)
	then
		return true
	end
	if pid < 3000000000 then
		return true
	end
	return false
end

local productPriceCache = {}
local function fetchAndDisplayProductPrice(priceLbl, productId, fallbackPrice, isGamePass)
	if not priceLbl or not productId or productId <= 0 then return end
	if productPriceCache[productId] then
		priceLbl.Text = tostring(productPriceCache[productId])
		return
	end
	task.spawn(function()
		local asPass = isGamePassId(productId, isGamePass)
		local infoType = asPass and Enum.InfoType.GamePass or Enum.InfoType.Product
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(productId, infoType)
		end)
		if (not ok or not info or not info.PriceInRobux) then
			local altType = asPass and Enum.InfoType.Product or Enum.InfoType.GamePass
			local altOk, altInfo = pcall(function()
				return MarketplaceService:GetProductInfo(productId, altType)
			end)
			if altOk and altInfo and altInfo.PriceInRobux then
				ok, info = altOk, altInfo
			end
		end

		if ok and info and info.PriceInRobux then
			productPriceCache[productId] = info.PriceInRobux
			if priceLbl.Parent then
				priceLbl.Text = tostring(info.PriceInRobux)
			end
		elseif fallbackPrice then
			priceLbl.Text = tostring(fallbackPrice)
		end
	end)
end

local function wireBuySpeedButton(button, tierData)
	if not button or not tierData then return end
	local productId = tonumber(tierData.ProductId)
	local nameLbl = button:FindFirstChild("Name")
	local priceLbl = button:FindFirstChild("Price")
	local isGamePass = tierData.IsGamePass == true

	local function refreshButtonText()
		local current = cleanSpeed(readSpeedAmount()) or 1
		local gain = displaySpeedGain(tierData, current)
		if nameLbl then
			nameLbl.Text = "+" .. formatNumber(gain)
		end
		if priceLbl then
			if productPriceCache[productId] then
				priceLbl.Text = tostring(productPriceCache[productId])
			else
				priceLbl.Text = tostring(tonumber(tierData.PriceRobux) or 0)
				fetchAndDisplayProductPrice(priceLbl, productId, tierData.PriceRobux, isGamePass)
			end
		end
	end
	refreshButtonText()

	button.Activated:Connect(function()
		if speedPromptBusy or not productId or productId <= 0 then return end
		speedPromptBusy = true
		PurchaseButtonSound.Play()
		task.wait(0.08)
		local ok, err = pcall(function()
			if isGamePass then
				MarketplaceService:PromptGamePassPurchase(player, productId)
			else
				MarketplaceService:PromptProductPurchase(player, productId)
			end
		end)
		if not ok then
			warn("[MainHUDController] Speed purchase prompt failed: " .. tostring(err))
		end
		task.delay(0.75, function()
			speedPromptBusy = false
		end)
	end)
end

local buySpeedNames = {"Buy1Speed", "Buy2Speed", "Buy3Speed", "Buy4Speed"}
for i, tierName in ipairs(buySpeedNames) do
	local btn = speedbuyFrame:FindFirstChild(tierName)
	if btn and speedTiers[i] then
		wireBuySpeedButton(btn, speedTiers[i])
	end
	-- Zoom + tiny rotation on hover/touch for Speedbuy icons
	if btn then
		setupIconHoverWithRotation(btn, 1.15, 1.0, 3)
	end
end

task.spawn(function()
	while player.Parent do
		task.wait(Config.SpeedProductDisplayRefreshSeconds or 1)
		local currentSpeed = cleanSpeed(readSpeedAmount()) or 1
		for i, tierName in ipairs(buySpeedNames) do
			local btn = speedbuyFrame:FindFirstChild(tierName)
			local tier = speedTiers[i]
			if btn and tier then
				local gain = displaySpeedGain(tier, currentSpeed)
				local nameLbl = btn:FindFirstChild("Name")
				if nameLbl then
					nameLbl.Text = "+" .. formatNumber(gain)
				end
			end
		end
	end
end)

----------------------------------------------------------------------
-- 4) SpeedsterBar - stamina / shift-to-run bar
----------------------------------------------------------------------
local speedsterBar = mainhud:WaitForChild("SpeedsterBar")
local speedsterFrame = speedsterBar:WaitForChild("Frame")
speedsterFrame.Position = UDim2.new(0.5, 0, 0.4977123, 0)
local staminaFill = speedsterFrame:WaitForChild("Fill")
local staminaValue = speedsterFrame:FindFirstChild("Value")
local shiftLabel = speedsterFrame:FindFirstChild("Shift")

local function refreshStaminaBar()
	local maxStamina = tonumber(player:GetAttribute("BoostStaminaDisplayMax"))
		or tonumber(Config.SuitStaminaMax and Config.SuitStaminaMax["ReverseSpeedsterSuit"])
		or Config.BoostStaminaDisplayBase
		or 17
	local stamina = player:GetAttribute("CurrentStamina")
	if typeof(stamina) ~= "number" then
		stamina = player:GetAttribute("BoostStamina")
	end
	if typeof(stamina) ~= "number" then
		stamina = maxStamina
	end
	stamina = math.clamp(tonumber(stamina) or 0, 0, maxStamina)
	local ratio = maxStamina > 0 and (stamina / maxStamina) or 0
	TweenService:Create(staminaFill, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromScale(ratio, 1),
	}):Play()
	if staminaValue and staminaValue:IsA("TextLabel") then
		staminaValue.Text = tostring(math.floor(stamina)) .. "/" .. tostring(math.floor(maxStamina))
	end
end

player:GetAttributeChangedSignal("CurrentStamina"):Connect(refreshStaminaBar)
player:GetAttributeChangedSignal("BoostStamina"):Connect(refreshStaminaBar)
player:GetAttributeChangedSignal("BoostStaminaDisplayMax"):Connect(refreshStaminaBar)

task.defer(refreshStaminaBar)

task.spawn(function()
	while player.Parent do
		task.wait(0.15)
		refreshStaminaBar()
	end
end)

local function updateSprintHint()
	if not shiftLabel or not shiftLabel:IsA("TextLabel") then
		return
	end

	local lastInputType = UserInputService:GetLastInputType()
	local isGamepad = GuiService:IsTenFootInterface()
		or UserInputService.GamepadEnabled
		or #UserInputService:GetConnectedGamepads() > 0
		or lastInputType == Enum.UserInputType.Gamepad1
		or lastInputType == Enum.UserInputType.Gamepad2
		or lastInputType == Enum.UserInputType.Gamepad3
		or lastInputType == Enum.UserInputType.Gamepad4
		or lastInputType == Enum.UserInputType.Gamepad5
		or lastInputType == Enum.UserInputType.Gamepad6
		or lastInputType == Enum.UserInputType.Gamepad7
		or lastInputType == Enum.UserInputType.Gamepad8

	local isTouch = (lastInputType == Enum.UserInputType.Touch or UserInputService.TouchEnabled) and not UserInputService.KeyboardEnabled

	local isFlightEquipped = player:GetAttribute("FlightAbilityEquipped") == true or player:GetAttribute("EquippedAbility") == "Flight"
	local isFlying = player:GetAttribute("FlightAbilityActive") == true

	if isFlying then
		shiftLabel.Visible = true
		if isGamepad then
			shiftLabel.Text = "Hold A / RB to Fly"
		elseif isTouch then
			shiftLabel.Text = "Hold Jump to Fly"
		else
			shiftLabel.Text = "Hold Space to Fly"
		end
	elseif isFlightEquipped then
		shiftLabel.Visible = true
		if isGamepad then
			shiftLabel.Text = "L2 Sprint | A / RB Fly"
		elseif isTouch then
			shiftLabel.Text = "Hold Jump to Fly"
		else
			shiftLabel.Text = "Shift: Sprint | Space: Fly"
		end
	elseif isGamepad then
		shiftLabel.Visible = true
		shiftLabel.Text = "L2 to Sprint"
	elseif isTouch then
		shiftLabel.Visible = false
	else
		shiftLabel.Visible = true
		shiftLabel.Text = "Shift to Sprint"
	end
end

UserInputService.LastInputTypeChanged:Connect(updateSprintHint)
UserInputService.GamepadConnected:Connect(updateSprintHint)
UserInputService.GamepadDisconnected:Connect(updateSprintHint)
player:GetAttributeChangedSignal("FlightAbilityEquipped"):Connect(updateSprintHint)
player:GetAttributeChangedSignal("EquippedAbility"):Connect(updateSprintHint)
player:GetAttributeChangedSignal("FlightAbilityActive"):Connect(updateSprintHint)
task.defer(updateSprintHint)

----------------------------------------------------------------------
-- 5) LeftSideBar buttons
----------------------------------------------------------------------
local leftBar = mainhud:WaitForChild("LeftSideBar")

local buttonEventMap = {
	Ability = "Abilities",
	Index = "Index",
	Rebirth = "Rebirth",
	-- The sidebar Backpack button opens the unified BackpackController panel
	-- (Trails + Auras tabs) instead of the old Trails-only frame.
	Backpack = "Backpack",
	Evolve = "Evolve",
	Teleport = "Teleport",
	Shop = "Shop",
	Settings = "Settings",
	DailyRewards = "Daily",
	["Time Gifts"] = "Playtime",
}



local function setupSidebarButton(child)
	if not child:IsA("ImageButton") then return end

	child.Activated:Connect(function()
		PurchaseButtonSound.Play()
		local eventName = buttonEventMap[child.Name]
		if eventName and MenuEvents.Request(eventName) then
			return
		end
	end)

	-- Smooth zoom + tiny rotation on the button's Icon (PC hover + Mobile touch + Gamepad)
	local icon = child:FindFirstChild("Rebirth") or child:FindFirstChild("Icon") or child:FindFirstChild("ImageLabel") or child:FindFirstChildOfClass("ImageLabel")
	if icon and icon:IsA("ImageLabel") then
		local hoverScale = icon:FindFirstChild("HoverScale")
		if not hoverScale or not hoverScale:IsA("UIScale") then
			hoverScale = Instance.new("UIScale")
			hoverScale.Name = "HoverScale"
			hoverScale.Scale = 1.0
			hoverScale.Parent = icon
		end

		local activeTweenS = nil
		local activeTweenR = nil
		local isHovered = false

		local function setZoom(hovered)
			if isHovered == hovered then return end
			isHovered = hovered

			if activeTweenS then activeTweenS:Cancel(); activeTweenS = nil end
			if activeTweenR then activeTweenR:Cancel(); activeTweenR = nil end

			local targetScale = hovered and 1.18 or 1.0
			local targetRot = hovered and 3 or 0
			local tweenInfo = hovered and HOVER_TWEEN_IN or HOVER_TWEEN_OUT
			activeTweenS = TweenService:Create(hoverScale, tweenInfo, { Scale = targetScale })
			activeTweenR = TweenService:Create(icon, tweenInfo, { Rotation = targetRot })
			activeTweenS:Play()
			activeTweenR:Play()
		end

		-- PC mouse hover
		child.MouseEnter:Connect(function()
			setZoom(true)
		end)
		child.MouseLeave:Connect(function()
			setZoom(false)
		end)

		-- Mobile touch & mouse click press
		child.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				setZoom(true)
			end
		end)
		child.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				setZoom(false)
			end
		end)

		-- Gamepad navigation
		child.SelectionGained:Connect(function()
			setZoom(true)
		end)
		child.SelectionLost:Connect(function()
			setZoom(false)
		end)
	end
end

for _, child in ipairs(leftBar:GetChildren()) do
	setupSidebarButton(child)
end
leftBar.ChildAdded:Connect(setupSidebarButton)

-- Shop icon periodic attention bounce ("brinquito" to call attention)
task.spawn(function()
	local shopButton = leftBar:FindFirstChild("Shop")
	if not shopButton then return end
	local shopIcon = shopButton:FindFirstChild("Icon") or shopButton:FindFirstChild("ImageLabel") or shopButton:FindFirstChildOfClass("ImageLabel")
	if not shopIcon or not shopIcon:IsA("ImageLabel") then return end

	local shopHoverScale = shopIcon:FindFirstChild("HoverScale")
	if not shopHoverScale or not shopHoverScale:IsA("UIScale") then
		shopHoverScale = Instance.new("UIScale")
		shopHoverScale.Name = "HoverScale"
		shopHoverScale.Scale = 1.0
		shopHoverScale.Parent = shopIcon
	end

	while player.Parent do
		task.wait(SHOP_BOUNCE_INTERVAL)
		-- Only bounce if not currently hovered (scale ~1.0)
		if math.abs(shopHoverScale.Scale - 1.0) < 0.02 then
			-- Wiggle: scale up + rotate right
			local t1 = TweenService:Create(shopHoverScale, SHOP_BOUNCE_IN, { Scale = SHOP_BOUNCE_SCALE })
			local r1 = TweenService:Create(shopIcon, SHOP_BOUNCE_IN, { Rotation = SHOP_BOUNCE_ROT })
			t1:Play(); r1:Play()
			t1.Completed:Wait()

			-- Quick swing to opposite side
			local t2 = TweenService:Create(shopHoverScale, SHOP_BOUNCE_MID, { Scale = SHOP_BOUNCE_SCALE * 0.97 })
			local r2 = TweenService:Create(shopIcon, SHOP_BOUNCE_MID, { Rotation = -SHOP_BOUNCE_ROT })
			t2:Play(); r2:Play()
			r2.Completed:Wait()

			-- Settle back to rest
			local t3 = TweenService:Create(shopHoverScale, SHOP_BOUNCE_OUT, { Scale = 1.0 })
			local r3 = TweenService:Create(shopIcon, SHOP_BOUNCE_OUT, { Rotation = 0 })
			t3:Play(); r3:Play()
			t3.Completed:Wait()
		end
	end
end)

----------------------------------------------------------------------
-- 5b) Sidebar notification badges ("!") - visible + shake while active
----------------------------------------------------------------------
local badgeTweens = {}
local badgeBasePositions = {}
local function setBadgeState(button, active)
	if not button then return end
	local badge = button:FindFirstChild("!")
	if not badge then return end
	if active then
		if badgeTweens[button] then return end
		badgeBasePositions[button] = badgeBasePositions[button] or badge.Position
		local base = badgeBasePositions[button]
		local tween = TweenService:Create(badge,
			TweenInfo.new(0.12, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, true),
			{ Position = base + UDim2.fromOffset(5, 0) })
		tween:Play()
		badgeTweens[button] = tween
		badge.Visible = true
	else
		local tween = badgeTweens[button]
		if tween then
			tween:Cancel()
			badgeTweens[button] = nil
		end
		if badgeBasePositions[button] then
			badge.Position = badgeBasePositions[button]
		end
		badge.Visible = false
	end
end

local function rebirthReady()
	local level = tonumber(player:GetAttribute("Level")) or 0
	local required = tonumber(player:GetAttribute("NextRebirthLevelRequired")) or 5
	return level >= required
end

-- A badge hides once its button is clicked, and comes back when the "new"
-- condition turns off and on again (e.g. next rebirth threshold / next claim).
local dismissedBadges = {}
local function isBadgeDismissed(name)
	return dismissedBadges[name] == true
end
local function dismissBadge(name, button)
	dismissedBadges[name] = true
	setBadgeState(button, false)
end

local rebirthButton = leftBar:FindFirstChild("Rebirth")
local prevRebirthReady = nil
local function refreshRebirthBadge()
	local ready = rebirthReady()
	if ready and prevRebirthReady == false then
		dismissedBadges.Rebirth = nil
	end
	prevRebirthReady = ready
	setBadgeState(rebirthButton, ready and not isBadgeDismissed("Rebirth"))
end
if rebirthButton then
	player:GetAttributeChangedSignal("Level"):Connect(refreshRebirthBadge)
	player:GetAttributeChangedSignal("NextRebirthLevelRequired"):Connect(refreshRebirthBadge)
	rebirthButton.Activated:Connect(function()
		dismissBadge("Rebirth", rebirthButton)
	end)
	refreshRebirthBadge()
end

-- Time Gifts: lights up whenever a daily gift can be claimed (same
-- DailyLoginUpdate state that DailyRewardController uses).
local timeGiftsButton = leftBar:FindFirstChild("Time Gifts")
local DailyLoginUpdate = Remotes:FindFirstChild("DailyLoginUpdate")
local prevTimeGiftsReady = nil
local function refreshTimeGiftsBadge(ready)
	ready = ready == true
	if ready and prevTimeGiftsReady == false then
		dismissedBadges.TimeGifts = nil
	end
	prevTimeGiftsReady = ready
	setBadgeState(timeGiftsButton, ready and not isBadgeDismissed("TimeGifts"))
end
if timeGiftsButton and DailyLoginUpdate then
	DailyLoginUpdate.OnClientEvent:Connect(function(value)
		if type(value) == "table" then
			refreshTimeGiftsBadge(value.CanClaim == true)
		end
	end)
	timeGiftsButton.Activated:Connect(function()
		dismissBadge("TimeGifts", timeGiftsButton)
	end)
end

-- Shop: badge appears when the player has something new in the shop. The
-- "ShopUnread" attribute is the hook for a server-side rule; until one is set
-- the badge stays hidden (and clicking dismisses it regardless).
local shopButton = leftBar:FindFirstChild("Shop")
local prevShopUnread = nil
local function refreshShopBadge()
	local unread = player:GetAttribute("ShopUnread") == true
	if unread and prevShopUnread == false then
		dismissedBadges.Shop = nil
	end
	prevShopUnread = unread
	setBadgeState(shopButton, unread and not isBadgeDismissed("Shop"))
end
if shopButton then
	player:GetAttributeChangedSignal("ShopUnread"):Connect(refreshShopBadge)
	shopButton.Activated:Connect(function()
		dismissBadge("Shop", shopButton)
	end)
	refreshShopBadge()
end

----------------------------------------------------------------------
-- 6) Right buttons  -  2xSpeed & 2xVictory permanent multiplier shops
----------------------------------------------------------------------
local rightButtons = mainhud:WaitForChild("Rightbuttons")
local speedProducts = Config.PermanentSpeedMultiplierProducts or {}
local winsProducts = Config.PermanentWinsMultiplierProducts or {}

local function getCurrentSpeedMultiplier()
	local value = tonumber(player:GetAttribute("PermanentBaseSpeedMultiplier")) or 1
	if value ~= value or value == math.huge or value == -math.huge then value = 1 end
	if player:GetAttribute("TwoXSpeedOwned") == true and value < 2 then
		value = 2
	end
	return math.max(1, value)
end

local function getCurrentWinsMultiplier()
	local value = tonumber(player:GetAttribute("PermanentWinsMultiplier")) or 1
	if value ~= value or value == math.huge or value == -math.huge then return 1 end
	return math.max(1, value)
end

local function chooseSpeedProduct()
	local current = getCurrentSpeedMultiplier()
	for _, product in ipairs(speedProducts) do
		if current < math.max(1, tonumber(product.TargetMultiplier) or 1) then
			return product
		end
	end
	return nil
end

local function chooseWinsProduct()
	local current = getCurrentWinsMultiplier()
	for _, product in ipairs(winsProducts) do
		if current < math.max(1, tonumber(product.TargetMultiplier) or 1) then
			return product
		end
	end
	return nil
end

local speed2xButton = rightButtons:FindFirstChild("2xSpeed")
local wins2xButton = rightButtons:FindFirstChild("2xVictory")
local speed2xPromptBusy = false
local wins2xPromptBusy = false

local function speedProductLabel(sp)
	if not sp then return "" end
	local target = math.max(1, tonumber(sp.TargetMultiplier) or 1)
	return "x" .. tostring(target) .. " Speed"
end

local function winsProductLabel(wp)
	if not wp then return "" end
	local target = math.max(1, tonumber(wp.TargetMultiplier) or 1)
	return "x" .. tostring(target) .. " Victory"
end

local function refresh2xButtons()
	local sp = chooseSpeedProduct()
	if speed2xButton then
		local nameLbl = speed2xButton:FindFirstChild("Name")
		local priceLbl = speed2xButton:FindFirstChild("Price")
		if sp then
			if nameLbl then nameLbl.Text = speedProductLabel(sp) end
			local pid = tonumber(sp.ProductId)
			if priceLbl then
				if pid and productPriceCache[pid] then
					priceLbl.Text = tostring(productPriceCache[pid])
				else
					priceLbl.Text = tostring(tonumber(sp.PriceRobux) or 0)
					if pid then fetchAndDisplayProductPrice(priceLbl, pid, sp.PriceRobux, sp.IsGamePass == true) end
				end
			end
			speed2xButton.Visible = true
		else
			speed2xButton.Visible = false
		end
	end

	local wp = chooseWinsProduct()
	if wins2xButton then
		local nameLbl = wins2xButton:FindFirstChild("Name")
		local priceLbl = wins2xButton:FindFirstChild("Price")
		if wp then
			if nameLbl then nameLbl.Text = winsProductLabel(wp) end
			local pid = tonumber(wp.ProductId)
			if priceLbl then
				if pid and productPriceCache[pid] then
					priceLbl.Text = tostring(productPriceCache[pid])
				else
					priceLbl.Text = tostring(tonumber(wp.PriceRobux) or 0)
					if pid then fetchAndDisplayProductPrice(priceLbl, pid, wp.PriceRobux, wp.IsGamePass == true) end
				end
			end
			wins2xButton.Visible = true
		else
			wins2xButton.Visible = false
		end
	end
end

local function promptMultiplierPurchase(product)
	local productId = product and tonumber(product.ProductId)
	if not productId or productId <= 0 then return end

	local isPass = product.IsGamePass == true
		or (product.IsGamePass ~= false and (productId == tonumber(Config.TwoXSpeedGamePassId) or productId == tonumber(Config.DoubleWinsPadGamePassId)))

	if isPass then
		MarketplaceService:PromptGamePassPurchase(player, productId)
	else
		MarketplaceService:PromptProductPurchase(player, productId)
	end
end

if speed2xButton then
	speed2xButton.Activated:Connect(function()
		if speed2xPromptBusy then return end
		refresh2xButtons()
		local product = chooseSpeedProduct()
		if not product then return end
		speed2xPromptBusy = true
		PurchaseButtonSound.Play()
		task.wait(0.08)
		local ok, err = pcall(function()
			promptMultiplierPurchase(product)
		end)
		if not ok then
			warn("[MainHUDController] 2xSpeed purchase failed: " .. tostring(err))
		end
		task.delay(0.75, function()
			speed2xPromptBusy = false
		end)
	end)
end

if wins2xButton then
	wins2xButton.Activated:Connect(function()
		if wins2xPromptBusy then return end
		refresh2xButtons()
		local product = chooseWinsProduct()
		if not product then return end
		wins2xPromptBusy = true
		PurchaseButtonSound.Play()
		task.wait(0.08)
		local ok, err = pcall(function()
			promptMultiplierPurchase(product)
		end)
		if not ok then
			warn("[MainHUDController] 2xVictory purchase failed: " .. tostring(err))
		end
		task.delay(0.75, function()
			wins2xPromptBusy = false
		end)
	end)
end

player:GetAttributeChangedSignal("PermanentBaseSpeedMultiplier"):Connect(refresh2xButtons)
player:GetAttributeChangedSignal("PermanentWinsMultiplier"):Connect(refresh2xButtons)
player:GetAttributeChangedSignal("TwoXSpeedOwned"):Connect(refresh2xButtons)
player:GetAttributeChangedSignal("DoubleWinsPadUnlocked"):Connect(refresh2xButtons)
player:GetAttributeChangedSignal("DataLoaded"):Connect(refresh2xButtons)

refresh2xButtons()

-- Zoom + girito chiquito on hover/touch for 2xSpeed & 2xVictory icons
setupIconHoverWithRotation(speed2xButton, 1.18, 1.0, 5)
setupIconHoverWithRotation(wins2xButton, 1.18, 1.0, 5)

-- Continuous rotation of Shine light rays behind 2xSpeed and 2xVictory
local speed2xShine = speed2xButton and speed2xButton:FindFirstChild("Shine")
local wins2xShine = wins2xButton and wins2xButton:FindFirstChild("Shine")
RunService.RenderStepped:Connect(function(dt)
	if speed2xShine and speed2xButton and speed2xButton.Visible then
		speed2xShine.Rotation = (speed2xShine.Rotation + dt * 45) % 360
	end
	if wins2xShine and wins2xButton and wins2xButton.Visible then
		wins2xShine.Rotation = (wins2xShine.Rotation + dt * 45) % 360
	end
end)

-- Saltarina / bouncy attention animation for 2xSpeed and 2xVictory icons (like Shop)
local function setupButtonBounce(button, interval, offsetSec)
	task.spawn(function()
		task.wait(offsetSec)
		while player.Parent do
			task.wait(interval)
			if not button or not button.Visible then continue end
			local icon = button:FindFirstChild("Icon") or button:FindFirstChild("ImageLabel")
			if not icon or not icon:IsA("ImageLabel") then continue end
			local hoverScale = icon:FindFirstChild("HoverScale")
			if hoverScale and math.abs(hoverScale.Scale - 1.0) < 0.02 then
				local t1 = TweenService:Create(hoverScale, SHOP_BOUNCE_IN, { Scale = SHOP_BOUNCE_SCALE })
				local r1 = TweenService:Create(icon, SHOP_BOUNCE_IN, { Rotation = SHOP_BOUNCE_ROT })
				t1:Play(); r1:Play()
				t1.Completed:Wait()

				local t2 = TweenService:Create(hoverScale, SHOP_BOUNCE_MID, { Scale = SHOP_BOUNCE_SCALE * 0.97 })
				local r2 = TweenService:Create(icon, SHOP_BOUNCE_MID, { Rotation = -SHOP_BOUNCE_ROT })
				t2:Play(); r2:Play()
				r2.Completed:Wait()

				local t3 = TweenService:Create(hoverScale, SHOP_BOUNCE_OUT, { Scale = 1.0 })
				local r3 = TweenService:Create(icon, SHOP_BOUNCE_OUT, { Rotation = 0 })
				t3:Play(); r3:Play()
				t3.Completed:Wait()
			end
		end
	end)
end
setupButtonBounce(speed2xButton, 7, 2)
setupButtonBounce(wins2xButton, 7, 5)

-- Rebirth icons spontaneous 90-degree twist (girito de 90°, paran, girito de 90° - no completo, espontáneo)
local function setupSpontaneous90Spin(getIconFunc, initialDelay)
	task.spawn(function()
		task.wait(initialDelay or math.random(2, 4))
		while player.Parent do
			task.wait(math.random(35, 65) / 10) -- espontáneo: entre 3.5 y 6.5 segundos
			local icon = getIconFunc()
			if icon and icon:IsA("ImageLabel") and icon.Parent then
				local rootGui = icon:FindFirstAncestorOfClass("ScreenGui")
				if rootGui and not rootGui.Enabled then
					continue
				end
				if not icon.Visible then
					continue
				end

				local curRot = icon.Rotation
				-- Girito 1: 90 grados
				local t1 = TweenService:Create(icon, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Rotation = curRot + 90 })
				t1:Play()
				t1.Completed:Wait()

				-- Paran (pausa breve)
				task.wait(0.35)

				-- Girito 2: otros 90 grados (no completo)
				local t2 = TweenService:Create(icon, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Rotation = curRot + 180 })
				t2:Play()
				t2.Completed:Wait()

				icon.Rotation = (curRot + 180) % 360
			end
		end
	end)
end

-- 1) LeftSideBar Rebirth icon
local rebirthBtn = leftBar and leftBar:FindFirstChild("Rebirth")
setupSpontaneous90Spin(function()
	if not rebirthBtn then return nil end
	return rebirthBtn:FindFirstChild("Rebirth")
		or rebirthBtn:FindFirstChild("Icon")
		or rebirthBtn:FindFirstChildWhichIsA("ImageLabel")
end, 2.5)

-- 2) Rebith/trof counter Rebirth icon
setupSpontaneous90Spin(function()
	if not rebithTrof then return nil end
	for _, c in ipairs(rebithTrof:GetChildren()) do
		if c:IsA("ImageLabel") and (c.Name == "Rebirth" or (c.Image and c.Image:find("129578402198506"))) then
			return c
		end
	end
	for _, c in ipairs(rebithTrof:GetChildren()) do
		if c:IsA("ImageLabel") then
			return c
		end
	end
	return nil
end, 3.8)

-- 3) Rebirth modal menu Icon
setupSpontaneous90Spin(function()
	local rGui = playerGui:FindFirstChild("Rebirth")
	if not rGui or not rGui.Enabled then return nil end
	local rFrame = rGui:FindFirstChild("Rebirth")
	if not rFrame then return nil end
	return rFrame:FindFirstChild("Rebirth")
		or rFrame:FindFirstChild("Icon")
		or (function()
			for _, c in ipairs(rFrame:GetChildren()) do
				if c:IsA("ImageLabel") and (c.Name == "Rebirth" or c.Name == "Icon" or (c.Image and c.Image:find("129578402198506"))) then
					return c
				end
			end
			return nil
		end)()
end, 1.8)

task.defer(function()
	for _ = 1, 40 do
		task.wait(0.25)
		refresh2xButtons()
	end
end)

----------------------------------------------------------------------
-- 6) Active Buffs Display (below Speed text / speedmeter)
-- Reusing LeftSideBar container styling (Backpack template)
----------------------------------------------------------------------
local ICON_2X_SPEED = "rbxassetid://71111471194517"
local ICON_2X_WINS = "rbxassetid://89981527304241"
local ICON_2X_SERVER = "rbxassetid://125961309868308"

local buffsHolder = mainhud:FindFirstChild("ActiveBuffsHolder")
	or levelFrame:FindFirstChild("ActiveBuffsHolder")
	or mainhud:WaitForChild("ActiveBuffsHolder", 5)
local speedCard = buffsHolder and buffsHolder:WaitForChild("SpeedBuffCard", 5)
local winsCard = buffsHolder and buffsHolder:WaitForChild("WinsBuffCard", 5)
local serverCard = buffsHolder and buffsHolder:WaitForChild("ServerBuffCard", 5)

local function formatCountdown(seconds)
	seconds = math.max(0, math.floor(seconds))
	local hours = math.floor(seconds / 3600)
	local mins = math.floor((seconds % 3600) / 60)
	local secs = seconds % 60
	if hours > 0 then
		return string.format("%d:%02d:%02d", hours, mins, secs)
	else
		return string.format("%02d:%02d", mins, secs)
	end
end

local function applyCardVisuals(card, iconAsset, countdownText, multiplierText)
	if not card then return end
	local icon = card:FindFirstChild("Icon") or card:FindFirstChild("ImageLabel") or card:FindFirstChildOfClass("ImageLabel")
	if icon and icon:IsA("ImageLabel") then
		icon.Image = iconAsset
		icon.ZIndex = 5
		icon.Visible = true
	end
	local nameLbl = card:FindFirstChild("Name")
	if nameLbl and nameLbl:IsA("TextLabel") then
		nameLbl.Text = countdownText
		nameLbl.ZIndex = 6
		nameLbl.Visible = true
	end
	local badge = card:FindFirstChild("!")
	if badge then
		local badgeLbl = badge:FindFirstChild("Name") or badge:FindFirstChildOfClass("TextLabel")
		if badgeLbl and badgeLbl:IsA("TextLabel") then
			badgeLbl.Text = multiplierText or "2X"
		end
		badge.Visible = true
	end
end

local function refreshBuffDisplay()
	local now = os.time()
	local anyActive = false

	-- 1. 2X Speed (potion countdown only - temporary)
	local speedExpire = tonumber(player:GetAttribute("PotionSpeedExpireUnix")) or 0
	local speedRemaining = math.max(0, speedExpire - now)

	if speedCard then
		if speedRemaining > 0 then
			applyCardVisuals(speedCard, ICON_2X_SPEED, formatCountdown(speedRemaining), "2X")
			speedCard.Visible = true
			anyActive = true
		else
			speedCard.Visible = false
		end
	end

	-- 2. 2X Wins (potion countdown only - temporary)
	local winsExpire = tonumber(player:GetAttribute("PotionWinsExpireUnix")) or 0
	local winsRemaining = math.max(0, winsExpire - now)

	if winsCard then
		if winsRemaining > 0 then
			applyCardVisuals(winsCard, ICON_2X_WINS, formatCountdown(winsRemaining), "2X")
			winsCard.Visible = true
			anyActive = true
		else
			winsCard.Visible = false
		end
	end

	-- 3. 2X Server Speed Boost (30m countdown only - temporary)
	local serverExpire = tonumber(Workspace:GetAttribute("ServerBoostExpiresUnix")) or 0
	local serverRemaining = math.max(0, serverExpire - now)

	if serverCard then
		if serverRemaining > 0 then
			applyCardVisuals(serverCard, ICON_2X_SERVER, formatCountdown(serverRemaining), "2X")
			serverCard.Visible = true
			anyActive = true
		else
			serverCard.Visible = false
		end
	end

	if buffsHolder and buffsHolder:IsA("GuiObject") then
		buffsHolder.Visible = anyActive
	end
end

player:GetAttributeChangedSignal("PotionSpeedExpireUnix"):Connect(refreshBuffDisplay)
player:GetAttributeChangedSignal("PotionWinsExpireUnix"):Connect(refreshBuffDisplay)
player:GetAttributeChangedSignal("TwoXSpeedOwned"):Connect(refreshBuffDisplay)
player:GetAttributeChangedSignal("DoubleWinsPadUnlocked"):Connect(refreshBuffDisplay)
player:GetAttributeChangedSignal("PermanentBaseSpeedMultiplier"):Connect(refreshBuffDisplay)
player:GetAttributeChangedSignal("PermanentWinsMultiplier"):Connect(refreshBuffDisplay)
Workspace:GetAttributeChangedSignal("ServerBoostExpiresUnix"):Connect(refreshBuffDisplay)

task.spawn(function()
	local passWins = tonumber(Config.TwoXVictoryGamePassId) or tonumber(Config.DoubleWinsPadGamePassId) or 1941409601
	if passWins and passWins > 0 and (player:GetAttribute("DoubleWinsPadUnlocked") ~= true or (tonumber(player:GetAttribute("PermanentWinsMultiplier")) or 1) < 2) then
		local ok, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passWins)
		end)
		if ok and owns == true then
			player:SetAttribute("DoubleWinsPadUnlocked", true)
			player:SetAttribute("TwoXVictoryOwned", true)
			local cur = tonumber(player:GetAttribute("PermanentWinsMultiplier")) or 1
			player:SetAttribute("PermanentWinsMultiplier", math.max(2, cur))
			refresh2xButtons()
			refreshBuffDisplay()
		end
	end
	local passSpeed = tonumber(Config.TwoXSpeedGamePassId)
	if passSpeed and passSpeed > 0 and player:GetAttribute("TwoXSpeedOwned") ~= true then
		local ok, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passSpeed)
		end)
		if ok and owns == true then
			player:SetAttribute("TwoXSpeedOwned", true)
			local cur = tonumber(player:GetAttribute("PermanentBaseSpeedMultiplier")) or 1
			player:SetAttribute("PermanentBaseSpeedMultiplier", math.max(2, cur))
			refresh2xButtons()
			refreshBuffDisplay()
		end
	end
end)

MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, wasPurchased)
	if wasPurchased and userId == player.UserId then
		productId = tonumber(productId)
		for _, sp in ipairs(speedProducts) do
			if tonumber(sp.ProductId) == productId then
				local target = tonumber(sp.TargetMultiplier) or 2
				local cur = tonumber(player:GetAttribute("PermanentBaseSpeedMultiplier")) or 1
				player:SetAttribute("PermanentBaseSpeedMultiplier", math.max(cur, target))
				if target >= 2 then
					player:SetAttribute("TwoXSpeedOwned", true)
				end
				refresh2xButtons()
				refreshBuffDisplay()
				break
			end
		end
		for _, wp in ipairs(winsProducts) do
			if tonumber(wp.ProductId) == productId then
				local target = tonumber(wp.TargetMultiplier) or 2
				local cur = tonumber(player:GetAttribute("PermanentWinsMultiplier")) or 1
				player:SetAttribute("PermanentWinsMultiplier", math.max(cur, target))
				if target >= 2 then
					player:SetAttribute("DoubleWinsPadUnlocked", true)
					player:SetAttribute("TwoXVictoryOwned", true)
				end
				refresh2xButtons()
				refreshBuffDisplay()
				break
			end
		end
	end
end)

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(buyer, passId, wasPurchased)
	if wasPurchased and buyer == player then
		passId = tonumber(passId)
		local passWins = tonumber(Config.TwoXVictoryGamePassId) or tonumber(Config.DoubleWinsPadGamePassId) or 1941409601
		if passId == passWins then
			player:SetAttribute("DoubleWinsPadUnlocked", true)
			player:SetAttribute("TwoXVictoryOwned", true)
			local cur = tonumber(player:GetAttribute("PermanentWinsMultiplier")) or 1
			player:SetAttribute("PermanentWinsMultiplier", math.max(2, cur))
			refresh2xButtons()
			refreshBuffDisplay()
		elseif passId == tonumber(Config.TwoXSpeedGamePassId) then
			player:SetAttribute("TwoXSpeedOwned", true)
			local cur = tonumber(player:GetAttribute("PermanentBaseSpeedMultiplier")) or 1
			player:SetAttribute("PermanentBaseSpeedMultiplier", math.max(2, cur))
			refresh2xButtons()
			refreshBuffDisplay()
		end
	end
end)

task.spawn(function()
	while player.Parent do
		refreshBuffDisplay()
		task.wait(1)
	end
end)

----------------------------------------------------------------------
-- 8) Dynamic HUD Hide / Show Animation (When Modals Open/Close)
----------------------------------------------------------------------
local leftBarBasePos = leftBar and leftBar.Position
local rightButtonsBasePos = rightButtons and rightButtons.Position
local levelBarBasePos = levelProgressBar and levelProgressBar.Position
local speedsterBarBasePos = speedsterBar and speedsterBar.Position
local rebithTrofBasePos = rebithTrof and rebithTrof.Position
local mobileSprint = mainhud:FindFirstChild("MobileSprint")
local mobileSprintBasePos = mobileSprint and mobileSprint:IsA("GuiObject") and mobileSprint.Position
local buffsHolderBasePos = buffsHolder and buffsHolder:IsA("GuiObject") and buffsHolder.Position

-- WalkSpeedSelectorHUD (el velocímetro que cambia con el tab)
local speedSelectorGui = playerGui:FindFirstChild("WalkSpeedSelectorHUD")
local selectorHolder = speedSelectorGui and speedSelectorGui:FindFirstChild("SelectorHolder")
local selectorHolderBasePos = selectorHolder and selectorHolder:IsA("GuiObject") and selectorHolder.Position

local function setupSelectorHolder(gui)
	if not gui or not gui:IsA("ScreenGui") then return end
	local holder = gui:FindFirstChild("SelectorHolder") or gui:WaitForChild("SelectorHolder", 5)
	if holder and holder:IsA("GuiObject") then
		selectorHolder = holder
		selectorHolderBasePos = holder.Position

		-- Hover + rotation on the speedometer button (velocímetro)
		local modeBtn = holder:FindFirstChild("WalkSpeedModeButton")
		if modeBtn and modeBtn:IsA("ImageButton") then
			local hoverScale = modeBtn:FindFirstChild("HoverScale")
			if not hoverScale or not hoverScale:IsA("UIScale") then
				hoverScale = Instance.new("UIScale")
				hoverScale.Name = "HoverScale"
				hoverScale.Scale = 1.0
				hoverScale.Parent = modeBtn
			end

			local activeTweenS = nil
			local activeTweenR = nil
			local isHovered = false

			local function setSpeedoZoom(hovered)
				if isHovered == hovered then return end
				isHovered = hovered

				if activeTweenS then activeTweenS:Cancel(); activeTweenS = nil end
				if activeTweenR then activeTweenR:Cancel(); activeTweenR = nil end

				local targetScale = hovered and 1.15 or 1.0
				local targetRot = hovered and 4 or 0
				local tweenInfo = hovered and HOVER_TWEEN_IN or HOVER_TWEEN_OUT

				activeTweenS = TweenService:Create(hoverScale, tweenInfo, { Scale = targetScale })
				activeTweenR = TweenService:Create(modeBtn, tweenInfo, { Rotation = targetRot })
				activeTweenS:Play()
				activeTweenR:Play()
			end

			modeBtn.MouseEnter:Connect(function() setSpeedoZoom(true) end)
			modeBtn.MouseLeave:Connect(function() setSpeedoZoom(false) end)
			modeBtn.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
					setSpeedoZoom(true)
				end
			end)
			modeBtn.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
					setSpeedoZoom(false)
				end
			end)
			modeBtn.SelectionGained:Connect(function() setSpeedoZoom(true) end)
			modeBtn.SelectionLost:Connect(function() setSpeedoZoom(false) end)
		end
	end
end

if speedSelectorGui then
	setupSelectorHolder(speedSelectorGui)
else
	task.spawn(function()
		local g = playerGui:WaitForChild("WalkSpeedSelectorHUD", 10)
		if g then setupSelectorHolder(g) end
	end)
end

playerGui.ChildAdded:Connect(function(child)
	if child.Name == "WalkSpeedSelectorHUD" then
		setupSelectorHolder(child)
	end
end)

local MODAL_SCREEN_GUIS = {
	"Shop",
	"Index",
	"Backpack",
	"Evolve",
	"Rebirth",
	"Abilities",
	"StageTeleport",
	"Worlds",
	"Settings",
	"DailyReward",
	"TimeGift",
	"Treadmill",
	"Update Logs",
	"RankRewardGui",
}

local function isAnyModalOpen()
	for _, guiName in ipairs(MODAL_SCREEN_GUIS) do
		local gui = playerGui:FindFirstChild(guiName)
		if gui and gui:IsA("ScreenGui") and gui.Enabled == true then
			return true
		end
	end
	return false
end

local hudVisible = true
local hudTweens = {}

local function cancelHudTweens()
	for _, tw in ipairs(hudTweens) do
		tw:Cancel()
	end
	table.clear(hudTweens)
end

local HUD_HIDE_INFO = TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local HUD_SHOW_INFO = TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local function setHUDVisible(visible, force)
	if not force and hudVisible == visible then return end
	hudVisible = visible

	cancelHudTweens()

	local info = visible and HUD_SHOW_INFO or HUD_HIDE_INFO

	-- 1) LeftSideBar (menu buttons) -> slides DOWN
	if leftBar and leftBarBasePos then
		local target = visible and leftBarBasePos or UDim2.new(leftBarBasePos.X.Scale, leftBarBasePos.X.Offset, 1.35, 0)
		local tw = TweenService:Create(leftBar, info, { Position = target })
		table.insert(hudTweens, tw)
		tw:Play()
	end

	-- 2) Rightbuttons (2xSpeed & 2xVictory) -> slides DOWN
	if rightButtons and rightButtonsBasePos then
		local target = visible and rightButtonsBasePos or UDim2.new(rightButtonsBasePos.X.Scale, rightButtonsBasePos.X.Offset, 1.35, 0)
		local tw = TweenService:Create(rightButtons, info, { Position = target })
		table.insert(hudTweens, tw)
		tw:Play()
	end

	-- 3) LevelProgressBar & Speedbuy -> slides DOWN
	if levelProgressBar and levelBarBasePos then
		local target = visible and levelBarBasePos or UDim2.new(levelBarBasePos.X.Scale, levelBarBasePos.X.Offset, 1.35, 0)
		local tw = TweenService:Create(levelProgressBar, info, { Position = target })
		table.insert(hudTweens, tw)
		tw:Play()
	end

	-- 4) SpeedsterBar (Run / stamina bar) -> slides DOWN
	if speedsterBar and speedsterBarBasePos then
		local target = visible and speedsterBarBasePos or UDim2.new(speedsterBarBasePos.X.Scale, speedsterBarBasePos.X.Offset, 1.40, 0)
		local tw = TweenService:Create(speedsterBar, info, { Position = target })
		table.insert(hudTweens, tw)
		tw:Play()
	end

	-- 5) Rebith/trof (Rebirths & Wins) -> slides DOWN parejo!
	if rebithTrof and rebithTrofBasePos then
		local target = visible and rebithTrofBasePos or UDim2.new(rebithTrofBasePos.X.Scale, rebithTrofBasePos.X.Offset, 1.35, 0)
		local tw = TweenService:Create(rebithTrof, info, { Position = target })
		table.insert(hudTweens, tw)
		tw:Play()
	end

	-- 6) SelectorHolder (el velocímetro que cambia con el tab) -> slides DOWN parejo!
	if not selectorHolder and speedSelectorGui then
		selectorHolder = speedSelectorGui:FindFirstChild("SelectorHolder")
		if selectorHolder and selectorHolder.Position.Y.Scale < 1.0 then
			selectorHolderBasePos = selectorHolder.Position
		end
	end
	if selectorHolder and selectorHolderBasePos then
		local target = visible and selectorHolderBasePos or UDim2.new(selectorHolderBasePos.X.Scale, selectorHolderBasePos.X.Offset, 1.35, 0)
		local tw = TweenService:Create(selectorHolder, info, { Position = target })
		table.insert(hudTweens, tw)
		tw:Play()
	end

	-- 7) MobileSprint (botón táctil de sprint en móvil) -> slides DOWN parejo!
	if mobileSprint and mobileSprintBasePos then
		local target = visible and mobileSprintBasePos or UDim2.new(mobileSprintBasePos.X.Scale, mobileSprintBasePos.X.Offset, 1.35, 0)
		local tw = TweenService:Create(mobileSprint, info, { Position = target })
		table.insert(hudTweens, tw)
		tw:Play()
	end

	-- 8) ActiveBuffsHolder (tarjetas de pociones / boost temporales) -> slides DOWN parejo!
	if buffsHolder and buffsHolderBasePos then
		local target = visible and buffsHolderBasePos or UDim2.new(buffsHolderBasePos.X.Scale, buffsHolderBasePos.X.Offset, 1.35, 0)
		local tw = TweenService:Create(buffsHolder, info, { Position = target })
		table.insert(hudTweens, tw)
		tw:Play()
	end
end

-- Debounced check to prevent race conditions during modal switches
local pendingCheckThread = nil
local function scheduleVisibilityCheck()
	if pendingCheckThread then
		task.cancel(pendingCheckThread)
		pendingCheckThread = nil
	end
	pendingCheckThread = task.delay(0.06, function()
		pendingCheckThread = nil
		local anyOpen = isAnyModalOpen()
		setHUDVisible(not anyOpen)
	end)
end

-- 1. Listen to MenuEvents HUD visibility signals
MenuEvents.HUDVisibilityChanged.Event:Connect(function(visible, menuName)
	if visible == false then
		if pendingCheckThread then
			task.cancel(pendingCheckThread)
			pendingCheckThread = nil
		end
		setHUDVisible(false)
	else
		scheduleVisibilityCheck()
	end
end)

-- 2. Listen to ScreenGui.Enabled changes on all modal ScreenGuis
local function bindModalGui(gui)
	if not gui or not gui:IsA("ScreenGui") then return end
	gui:GetPropertyChangedSignal("Enabled"):Connect(function()
		if gui.Enabled then
			if pendingCheckThread then
				task.cancel(pendingCheckThread)
				pendingCheckThread = nil
			end
			setHUDVisible(false)
		else
			scheduleVisibilityCheck()
		end
	end)
end

for _, name in ipairs(MODAL_SCREEN_GUIS) do
	local g = playerGui:FindFirstChild(name)
	if g then
		bindModalGui(g)
	end
end

playerGui.ChildAdded:Connect(function(child)
	if table.find(MODAL_SCREEN_GUIS, child.Name) then
		bindModalGui(child)
	end
end)

-- 3. Listen to Character lifecycle to safely close modals on death and restore HUD on respawn
local function handleCharacter(char)
	local hum = char:WaitForChild("Humanoid", 10)
	if hum and hum:IsA("Humanoid") then
		hum.Died:Connect(function()
			MenuEvents.CloseAll:Fire()
		end)
	end
end

if player.Character then
	task.spawn(handleCharacter, player.Character)
end
player.CharacterAdded:Connect(function(char)
	task.spawn(handleCharacter, char)
	MenuEvents.CloseAll:Fire()
	task.delay(0.12, function()
		if not isAnyModalOpen() then
			setHUDVisible(true, true)
		end
	end)
end)

-- Initialize automatic zoom juice on all modal popups
ModalJuice.InitAutoJuice(playerGui)

-- Initial sync
task.defer(function()
	if isAnyModalOpen() then
		setHUDVisible(false)
	else
		setHUDVisible(true, true)
	end
end)

----------------------------------------------------------------------
-- Done
----------------------------------------------------------------------
print("[MainHUDController] V1 loaded. LeftSideBar, LevelProgressBar, SpeedsterBar, Rebith/trof, BuySpeed, 2xSpeed/2xVictory, Dynamic HUD Transitions & ModalJuice active.")