local Players = game:GetService("Players")
local ContentProvider = game:GetService("ContentProvider")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local WalkSpeedModeRequest = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("WalkSpeedModeRequest")

local UI_CLICK_SOUND_ID = "rbxassetid://72264591133889"

local MODE_IMAGES = {
	Green = "rbxassetid://124021406267245",
	Yellow = "rbxassetid://135452730598314",
	Red = "rbxassetid://120853685040395",
}

local function preloadModeImages()
	local preloadObjects = {}
	for _, imageId in pairs(MODE_IMAGES) do
		local image = Instance.new("ImageLabel")
		image.BackgroundTransparency = 1
		image.Image = imageId
		table.insert(preloadObjects, image)
	end
	local ok, err = pcall(function()
		ContentProvider:PreloadAsync(preloadObjects)
	end)
	for _, image in ipairs(preloadObjects) do
		image:Destroy()
	end
	if not ok then
		warn("[WalkSpeedSelector] Image preload failed; selector will still function:", err)
	end
end

preloadModeImages()

local MODE_COLORS = {
	Green = Color3.fromRGB(80, 255, 70),
	Yellow = Color3.fromRGB(255, 220, 35),
	Red = Color3.fromRGB(255, 70, 55),
	Custom = Color3.fromRGB(100, 200, 255),
}

local MODE_PITCHES = {
	Green = 0.95,
	Yellow = 1.05,
	Red = 1.18,
	Custom = 1.10,
}

-- Red -> Yellow -> Green (2026-09-25, M50): one accidental tap from full speed now lands on
-- the middle speed, not the slowest.
local NEXT_MODE = {
	Red = "Yellow",
	Yellow = "Green",
	Green = "Red",
	Custom = "Red",
}

local function getModeMultiplier(mode)
	local multipliers = Config.WalkSpeedSelectorMultipliers or {}
	return tonumber(multipliers[mode]) or 1
end

local function getModeImage(mode, speed)
	if MODE_IMAGES[mode] then
		return MODE_IMAGES[mode]
	end
	if mode == "Custom" and speed then
		if speed <= 80 then
			return MODE_IMAGES.Green
		elseif speed <= 200 then
			return MODE_IMAGES.Yellow
		else
			return MODE_IMAGES.Red
		end
	end
	return MODE_IMAGES.Red
end

local currentMode = Config.WalkSpeedSelectorDefaultMode or "Red"
local initialMode = tostring(player:GetAttribute("WalkSpeedMode") or "")
if MODE_IMAGES[initialMode] or initialMode == "Custom" then
	currentMode = initialMode
end

local gui = playerGui:WaitForChild("WalkSpeedSelectorHUD")
local holder = gui:WaitForChild("SelectorHolder")
local button = holder:WaitForChild("WalkSpeedModeButton") :: ImageButton
local buttonScale = button:WaitForChild("PressScale") :: UIScale
local valueLabel = holder:WaitForChild("RealWalkSpeedValue") :: TextLabel

local textSizeConstraint = valueLabel:WaitForChild("UITextSizeConstraint") :: UITextSizeConstraint
textSizeConstraint.MinTextSize = UserInputService.TouchEnabled and 7 or 16
textSizeConstraint.MaxTextSize = UserInputService.TouchEnabled and 14 or 30

-- Scale component for juicy bounce animation on the number
local textScale = valueLabel:FindFirstChild("TextScale") :: UIScale?
if not textScale then
	textScale = Instance.new("UIScale")
	textScale.Name = "TextScale"
	textScale.Scale = 1
	textScale.Parent = valueLabel
end

-- Allow direct touch on the dial button underneath when not touching the center number
valueLabel.Active = false

local valueLabelStroke = valueLabel:FindFirstChildOfClass("UIStroke")

-- Seamless transparent interactive TextBox for direct typing
local textBox = valueLabel:FindFirstChild("WalkSpeedInputBox") :: TextBox?
if not textBox then
	textBox = Instance.new("TextBox")
	textBox.Name = "WalkSpeedInputBox"
	textBox.AnchorPoint = Vector2.new(0.5, 0.5)
	textBox.Position = UDim2.new(0.5, 0, 0.5, 0)
	textBox.Size = UDim2.new(0.55, 0, 0.85, 0)
	textBox.BackgroundTransparency = 1
	textBox.TextTransparency = 1
	textBox.Font = valueLabel.Font
	textBox.TextScaled = valueLabel.TextScaled
	textBox.TextColor3 = valueLabel.TextColor3
	textBox.ClearTextOnFocus = false
	textBox.Active = true
	textBox.Selectable = true
	textBox.ZIndex = 30
	textBox.PlaceholderText = ""
	textBox.Text = ""
	textBox.Parent = valueLabel

	local cloneConstraint = textSizeConstraint:Clone()
	cloneConstraint.Parent = textBox
else
	textBox.AnchorPoint = Vector2.new(0.5, 0.5)
	textBox.Position = UDim2.new(0.5, 0, 0.5, 0)
	textBox.Size = UDim2.new(0.55, 0, 0.85, 0)
	textBox.BackgroundTransparency = 1
	textBox.Active = true
	textBox.Selectable = true
	textBox.ZIndex = 30
	textBox.ClearTextOnFocus = false
end

-- Give textBox its own clean UIStroke so it doesn't leave the old valueLabel outline visible
local textStroke = textBox:FindFirstChildOfClass("UIStroke")
if not textStroke and valueLabelStroke then
	textStroke = valueLabelStroke:Clone()
	textStroke.Name = "UIStroke"
	textStroke.Enabled = false
	textStroke.Parent = textBox
end

-- Phones: the box covers the whole number (a small finger target missed it and hit the
-- dial), can be typed into, and opens empty with the current speed as its placeholder, so
-- the on-screen keyboard starts clean.
local touchTyping = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
textBox.TextEditable = true
textBox.MultiLine = false
if touchTyping then
	textBox.Size = UDim2.new(0.8, 0, 1, 0)
end

-- Ensure button is selectable for console controller navigation
button.Selectable = true

local function formatIntegerWithCommas(value)
	value = math.max(0, math.floor((tonumber(value) or 0) + 0.5))
	local text = tostring(value)
	while true do
		local nextText, count = text:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		text = nextText
		if count == 0 then
			break
		end
	end
	return text
end

local function getDisplayedSelectedSpeed()
	local maxWalkSpeed = tonumber(player:GetAttribute("RealWalkSpeedMax")) or 300
	local selectedWalkSpeed = tonumber(player:GetAttribute("RealWalkSpeedSelected"))
	local serverMode = tostring(player:GetAttribute("WalkSpeedMode") or "")
	local customWalkSpeed = tonumber(player:GetAttribute("CustomWalkSpeed"))

	if currentMode == "Custom" or serverMode == "Custom" then
		return customWalkSpeed or selectedWalkSpeed or maxWalkSpeed
	end

	if maxWalkSpeed then
		-- The server's rule (CharacterStatsAdapter, M50): never under the floor, and full speed
		-- while the full speed is still at most WalkSpeedSelectorFullBelow.
		if maxWalkSpeed <= (tonumber(Config.WalkSpeedSelectorFullBelow) or 24) then
			return maxWalkSpeed
		end
		local floor = math.min(tonumber(Config.WalkSpeedSelectorFloor) or 16, maxWalkSpeed)
		return math.max(floor, maxWalkSpeed * getModeMultiplier(currentMode))
	end

	if selectedWalkSpeed and serverMode == currentMode then
		return selectedWalkSpeed
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		if currentMode == "Red" then
			return humanoid.WalkSpeed
		end
	end

	return nil
end

local function refreshVisuals()
	local selected = getDisplayedSelectedSpeed()
	local maxWalkSpeed = tonumber(player:GetAttribute("RealWalkSpeedMax")) or 300

	button.Image = getModeImage(currentMode, selected)

	if not textBox:IsFocused() then
		if valueLabelStroke then
			valueLabelStroke.Enabled = true
		end
		valueLabel.TextTransparency = 0

		if selected then
			local text = formatIntegerWithCommas(selected)
			if currentMode == "Red" or (currentMode ~= "Green" and currentMode ~= "Yellow" and selected >= maxWalkSpeed) then
				text ..= " (Max)"
			end
			valueLabel.Text = text
		else
			valueLabel.Text = currentMode == "Red" and "(Max)" or "..."
		end
	end
end

local uiClickSound = SoundService:FindFirstChild("SpeedsterUiClickSound")
if not uiClickSound then
	uiClickSound = Instance.new("Sound")
	uiClickSound.Name = "SpeedsterUiClickSound"
	uiClickSound.Parent = SoundService
end
uiClickSound.SoundId = UI_CLICK_SOUND_ID
uiClickSound.Volume = 0.65
uiClickSound.PlaybackSpeed = 1

local function playUiClickSound(pitch: number?)
	uiClickSound.TimePosition = 0
	uiClickSound.PlaybackSpeed = pitch or 1
	uiClickSound:Play()
end

-- Juicy 3-phase tactile squash, pop, and tilt animation when touching the dial manually
local currentAnimToken = 0
local function playDialTactileAnimation(mode: string)
	currentAnimToken += 1
	local myToken = currentAnimToken

	local modeColor = MODE_COLORS[mode] or Color3.fromRGB(255, 255, 255)
	local modePitch = MODE_PITCHES[mode] or 1.0

	playUiClickSound(modePitch)

	-- 1. Squash button down & tilt
	TweenService:Create(buttonScale, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Scale = 0.80,
	}):Play()

	TweenService:Create(button, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Rotation = -9,
	}):Play()

	-- 2. Bounce number text scale and pulse mode color
	if textScale then
		textScale.Scale = 1.22
		TweenService:Create(textScale, TweenInfo.new(0.20, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1.0,
		}):Play()
	end

	valueLabel.TextColor3 = modeColor
	TweenService:Create(valueLabel, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		TextColor3 = Color3.fromRGB(255, 255, 255),
	}):Play()

	-- 3. Pop button up with overshoot
	task.delay(0.06, function()
		if currentAnimToken ~= myToken or not buttonScale.Parent then
			return
		end

		TweenService:Create(buttonScale, TweenInfo.new(0.13, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1.18,
		}):Play()

		TweenService:Create(button, TweenInfo.new(0.13, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Rotation = 5,
		}):Play()

		-- 4. Smooth settle back to rest
		task.delay(0.13, function()
			if currentAnimToken ~= myToken or not buttonScale.Parent then
				return
			end

			TweenService:Create(buttonScale, TweenInfo.new(0.11, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Scale = 1.0,
			}):Play()

			TweenService:Create(button, TweenInfo.new(0.11, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Rotation = 0,
			}):Play()
		end)
	end)
end

local function cycleNextMode()
	currentMode = NEXT_MODE[currentMode] or "Red"
	playDialTactileAnimation(currentMode)
	refreshVisuals()
	WalkSpeedModeRequest:FireServer(currentMode)
end

-- Manual touch/click on dial cycles modes (Green -> Yellow -> Red) with juicy tactile animation
button.Activated:Connect(function()
	cycleNextMode()
end)

-- Seamless direct typing: no black box rectangle, completely eliminates ghost outline of old number
textBox.Focused:Connect(function()
	local selected = getDisplayedSelectedSpeed() or 300
	if touchTyping then
		textBox.PlaceholderText = tostring(math.floor(selected))
		textBox.Text = ""
	else
		textBox.Text = tostring(math.floor(selected))
	end
	textBox.BackgroundTransparency = 1
	textBox.TextTransparency = 0
	textBox.TextColor3 = Color3.fromRGB(255, 255, 255)

	-- Completely hide old number and its UIStroke so no shadow/outline remains
	valueLabel.Text = ""
	valueLabel.TextTransparency = 1
	if valueLabelStroke then
		valueLabelStroke.Enabled = false
	end
	if textStroke then
		textStroke.Enabled = true
	end

	-- Console virtual keyboard trigger
	if UserInputService.GamepadEnabled or GuiService:IsTenFootInterface() then
		pcall(function()
			GuiService:ShowVirtualKeyboard()
		end)
	end
end)

-- The typed number: its digits only (a phone keyboard can leave spaces, commas, dots or
-- the old text around them).
local function typedSpeed(text)
	local whole = tostring(text or ""):match("^%s*(%d[%d,%s]*)")
	local digits = (whole or tostring(text or "")):gsub("[^%d]", "")
	if digits == "" or #digits > 9 then
		return nil
	end
	return tonumber(digits)
end

local applying = false
local function applyTypedSpeed()
	if applying then
		return
	end
	applying = true
	textBox.BackgroundTransparency = 1
	textBox.TextTransparency = 1
	if textStroke then
		textStroke.Enabled = false
	end
	if valueLabelStroke then
		valueLabelStroke.Enabled = true
	end
	valueLabel.TextTransparency = 0

	local num = typedSpeed(textBox.Text)
	textBox.Text = ""

	if num ~= nil and num == num and num ~= math.huge and num ~= -math.huge then
		local maxWalkSpeed = tonumber(player:GetAttribute("RealWalkSpeedMax")) or 300
		local minWalkSpeed = Config.RealWalkSpeedMin or 8
		local clamped = math.clamp(math.floor(num + 0.5), minWalkSpeed, maxWalkSpeed)

		currentMode = "Custom"
		player:SetAttribute("WalkSpeedMode", "Custom")
		player:SetAttribute("CustomWalkSpeed", clamped)

		playDialTactileAnimation("Custom")
		refreshVisuals()
		WalkSpeedModeRequest:FireServer(clamped)
	else
		refreshVisuals()
	end
	applying = false
end

-- Enter, Done or a tap elsewhere: the typed speed applies. (Roblox focuses the box itself
-- on a tap; capturing it again from TouchTap made phones drop the focus and the number.)
textBox.FocusLost:Connect(function()
	task.defer(applyTypedSpeed)
end)
pcall(function()
	textBox.ReturnPressedFromOnScreenKeyboard:Connect(function()
		textBox:ReleaseFocus(true)
	end)
end)

-- Gamepad controller support for Console (Xbox / PlayStation)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	-- Button Y (Triangle on PS, Y on Xbox): Standard Roblox action to open keyboard/chat/input
	if input.KeyCode == Enum.KeyCode.ButtonY then
		textBox:CaptureFocus()
		pcall(function()
			GuiService:ShowVirtualKeyboard()
		end)
	-- Button X (Square) or Button R3: Quick cycle dial mode
	elseif input.KeyCode == Enum.KeyCode.ButtonX or input.KeyCode == Enum.KeyCode.ButtonR3 then
		cycleNextMode()
	end
end)

player:GetAttributeChangedSignal("WalkSpeedMode"):Connect(function()
	local mode = tostring(player:GetAttribute("WalkSpeedMode") or "")
	if MODE_IMAGES[mode] or mode == "Custom" then
		currentMode = mode
		refreshVisuals()
	end
end)

player:GetAttributeChangedSignal("CustomWalkSpeed"):Connect(refreshVisuals)
player:GetAttributeChangedSignal("RealWalkSpeedMax"):Connect(refreshVisuals)
player:GetAttributeChangedSignal("RealWalkSpeedSelected"):Connect(refreshVisuals)

refreshVisuals()

print("[WalkSpeedSelector] loaded with mobile touch keyboard, console gamepad, transparent input, and juicy tactile animation.")
