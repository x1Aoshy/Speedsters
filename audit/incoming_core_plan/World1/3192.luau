local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local MenuEvents = require(ReplicatedStorage.Shared:WaitForChild("MenuEvents"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SettingsRemote = Remotes:FindFirstChild("SettingsUpdate") or Remotes:FindFirstChild("SettingsRequest")
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local SettingsGui = PlayerGui:WaitForChild("Settings")
local SettingsFrame = SettingsGui:WaitForChild("Settings")
local CloseButton = SettingsFrame:WaitForChild("Close")
local ScrollingFrame = SettingsFrame:WaitForChild("ScrollingFrame")
local isOpen = false
local GREEN = Color3.fromRGB(70, 210, 85)
local RED = Color3.fromRGB(230, 70, 70)

local TOGGLES = {
	{row = "Sound", attr = "Muted", invert = true},
	{row = "Sound effects", attr = "SoundEffects"},
	{row = "Global messages", attr = "GlobalMessages"},
	{row = "Prompt Revivals", attr = "PromptRevivals"},
	{row = "Hide HUD", attr = "HideHud", default = false},
	{row = "Hide popups", attr = "HidePopups", default = false},
	{row = "Accept gifts", attr = "AcceptGifts"},
	{row = "Event effects ", attr = "EventEffects"},
}

local TOGGLES_BY_ATTR = {}
for _, toggle in ipairs(TOGGLES) do
	TOGGLES_BY_ATTR[toggle.attr] = toggle
end

local ALWAYS_VISIBLE = {
	Settings = true,
	Topbar = true,
	TopbarPlus = true,
	AdminAbusePanelGui = true,
	DailyReward = true,
}

local function getToggleRow(name)
	return ScrollingFrame:FindFirstChild(name)
end

local function getDisplay(toggle)
	local config = TOGGLES_BY_ATTR[toggle.attr] or toggle
	local value = LocalPlayer:GetAttribute(config.attr)
	if value == nil then
		-- Invert toggles (e.g. Sound/Muted) must read "On" while the raw
		-- attribute is missing, matching the server defaults; only HideHud
		-- defaults to off.
		if config.default ~= nil then
			return config.default
		else
			return true
		end
	end
	if config.invert then
		return not value
	end
	return value
end

local applyVisual

local function setDisplay(toggle, displayValue)
	local attrValue
	if toggle.invert then
		attrValue = not displayValue
	else
		attrValue = displayValue
	end
	LocalPlayer:SetAttribute(toggle.attr, attrValue)
	if SettingsRemote then SettingsRemote:FireServer(toggle.attr, attrValue) end
	applyVisual(getToggleRow(toggle.row), displayValue)
end

function applyVisual(row, on)
	if not row then return end
	local button = row:FindFirstChild("On/Off")
	if button and button:IsA("TextButton") then
		button.Text = on and "On" or "Off"
		button.BackgroundColor3 = on and GREEN or RED
	end
end

-- PlayerGui rows replicate asynchronously; wait (best-effort) for each row so
-- every toggle gets its button + connection even if some rows arrive late.
local function waitForRow(name)
	local row = ScrollingFrame:FindFirstChild(name)
	if row then return row end
	for _ = 1, 100 do
		task.wait(0.05)
		row = ScrollingFrame:FindFirstChild(name)
		if row then return row end
	end
	return nil
end

local soundRow = waitForRow("Sound")
local sourceButton = soundRow and soundRow:FindFirstChild("On/Off")
for _, toggle in ipairs(TOGGLES) do
	local row = waitForRow(toggle.row)
	if row then
		if row ~= soundRow and sourceButton and not row:FindFirstChild("On/Off") then
			local btn = sourceButton:Clone()
			btn.Parent = row
		end
		local btn = row:FindFirstChild("On/Off")
		if btn and btn:IsA("GuiButton") then
			btn.Activated:Connect(function()
				setDisplay(toggle, not getDisplay(toggle))
			end)
		end
		applyVisual(row, getDisplay(toggle))
		-- Self-heal: whenever the attribute changes (local press or server
		-- load), repaint the button so it always matches the real state.
		LocalPlayer:GetAttributeChangedSignal(toggle.attr):Connect(function()
			applyVisual(row, getDisplay(toggle))
		end)
	end
end

----------------------------------------------------------------------
-- Volume Sliders (Music & SFX)
----------------------------------------------------------------------
local SLIDERS = {
	{ row = "Music Volume", attr = "MusicVolume", label = "Music Volume", default = 100 },
	{ row = "SFX Volume", attr = "SfxVolume", label = "SFX Volume", default = 100 },
}

local function setupSlider(config)
	local row = waitForRow(config.row)
	if not row then return end

	local sliderBar = row:WaitForChild("SliderBar", 5)
	if not sliderBar then return end

	local fill = sliderBar:WaitForChild("Fill", 5)
	local knob = sliderBar:WaitForChild("Knob", 5)
	local hitbox = sliderBar:WaitForChild("Hitbox", 5)
	local nameLabel = row:FindFirstChild("Name")

	local function getVolume()
		local val = tonumber(LocalPlayer:GetAttribute(config.attr))
		if val == nil then return config.default end
		return math.clamp(math.floor(val), 0, 100)
	end

	local function updateKnobDimensions()
		if not knob or not sliderBar then return 18 end
		local barH = sliderBar.AbsoluteSize.Y
		local cam = Workspace.CurrentCamera
		local isSmallScreen = cam and cam.ViewportSize.X < 800
		local isTouchDevice = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

		local knobDim
		if isTouchDevice or isSmallScreen then
			-- En móvil/teléfono: tamaño compacto (15-18px) para que no se vea gigante
			knobDim = (barH > 0) and math.clamp(math.round(barH * 1.05), 15, 18) or 17
		else
			-- En PC: tamaño cómodo (20-24px)
			knobDim = (barH > 0) and math.clamp(math.round(barH * 1.25), 20, 24) or 22
		end
		knob.Size = UDim2.new(0, knobDim, 0, knobDim)
		return knobDim
	end

	local function applySliderVisual(volume)
		local frac = volume / 100
		if fill then fill.Size = UDim2.new(frac, 0, 1, 0) end
		if knob then
			local knobWidth = updateKnobDimensions()
			if knobWidth <= 0 then knobWidth = 18 end
			-- Inset the knob so it never protrudes past the left (0%) or right (100%) edges of the bar
			local offset = math.round((0.5 - frac) * knobWidth)
			knob.Position = UDim2.new(frac, offset, 0.5, 0)
		end
		if nameLabel and nameLabel:IsA("TextLabel") then
			nameLabel.Text = config.label .. ": " .. volume .. "%"
		end
	end

	local function setVolume(volume)
		volume = math.clamp(math.floor(volume), 0, 100)
		LocalPlayer:SetAttribute(config.attr, volume)
		if SettingsRemote then
			SettingsRemote:FireServer(config.attr, volume)
		end
		applySliderVisual(volume)
	end

	local isDragging = false

	local function updateFromInput(input)
		local barAbsPos = sliderBar.AbsolutePosition.X
		local barAbsSize = sliderBar.AbsoluteSize.X
		if barAbsSize <= 0 then return end
		local knobWidth = (knob and knob.AbsoluteSize.X > 0 and knob.AbsoluteSize.X) or (knob and knob.Size.X.Offset) or 18
		local usableWidth = math.max(1, barAbsSize - knobWidth)
		local mouseRel = input.Position.X - (barAbsPos + knobWidth / 2)
		local relX = math.clamp(mouseRel / usableWidth, 0, 1)
		setVolume(math.round(relX * 100))
	end

	if hitbox and hitbox:IsA("GuiButton") then
		hitbox.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				isDragging = true
				updateFromInput(input)
			end
		end)
	end

	UserInputService.InputChanged:Connect(function(input)
		if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			updateFromInput(input)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if isDragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			isDragging = false
		end
	end)

	LocalPlayer:GetAttributeChangedSignal(config.attr):Connect(function()
		applySliderVisual(getVolume())
	end)

	sliderBar:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		applySliderVisual(getVolume())
	end)

	if Workspace.CurrentCamera then
		Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			applySliderVisual(getVolume())
		end)
	end

	applySliderVisual(getVolume())
end

for _, sliderConfig in ipairs(SLIDERS) do
	task.spawn(function()
		setupSlider(sliderConfig)
	end)
end

local uiListLayout = ScrollingFrame:WaitForChild("UIListLayout", 5)
local function updateSettingsCanvasSize()
	if not uiListLayout then return end
	local contentY = uiListLayout.AbsoluteContentSize.Y
	if contentY > 0 then
		ScrollingFrame.CanvasSize = UDim2.new(0, 0, 0, contentY + 28)
	end
end
if uiListLayout then
	uiListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateSettingsCanvasSize)
	task.defer(updateSettingsCanvasSize)
end


local hiddenGuis = {}
local function applyHudVisibility(hidden)
	if hidden then
		for _, child in ipairs(PlayerGui:GetChildren()) do
			if child:IsA("ScreenGui") and not ALWAYS_VISIBLE[child.Name] and child.Enabled then
				hiddenGuis[child] = true
				child.Enabled = false
			end
		end
	else
		for gui in pairs(hiddenGuis) do
			if gui and gui.Parent then gui.Enabled = true end
		end
		table.clear(hiddenGuis)
		for _, name in ipairs({ "Mainhud", "WalkSpeedSelectorHUD", "Messages", "ToastMessages" }) do
			local g = PlayerGui:FindFirstChild(name)
			if g and g:IsA("ScreenGui") then
				g.Enabled = true
			end
		end
	end
end
local function hideHudChanged()
	applyHudVisibility(getDisplay(TOGGLES_BY_ATTR["HideHud"]))
end
LocalPlayer:GetAttributeChangedSignal("HideHud"):Connect(hideHudChanged)
LocalPlayer.CharacterAdded:Connect(function()
	task.delay(0.1, function()
		if not getDisplay(TOGGLES_BY_ATTR["HideHud"]) then
			applyHudVisibility(false)
		end
	end)
end)
-- GUIs created while the HUD is hidden are also tracked so they are restored
-- when hiding is turned off (they were previously left disabled forever).
PlayerGui.ChildAdded:Connect(function(child)
	if child:IsA("ScreenGui") and not ALWAYS_VISIBLE[child.Name] then
		if getDisplay(TOGGLES_BY_ATTR["HideHud"]) then
			hiddenGuis[child] = true
			child.Enabled = false
		end
	end
end)
task.defer(hideHudChanged)

local OPEN_POS = UDim2.new(0.5, 0, 0.48, 0)
local CLOSED_POS = UDim2.new(0.5, 0, 1.28, 0)
local openTween = nil
local dimTween = nil
local isClosing = false

local dimOverlay = SettingsGui:FindFirstChild("Dim")
if not dimOverlay then
	local newDim = Instance.new("Frame")
	newDim.Name = "Dim"
	newDim.AnchorPoint = Vector2.new(0.5, 0.5)
	newDim.Position = UDim2.new(0.5, 0, 0.5, 0)
	newDim.Size = UDim2.new(2, 0, 2, 0)
	newDim.BackgroundColor3 = Color3.new(0, 0, 0)
	newDim.BackgroundTransparency = 1
	newDim.BorderSizePixel = 0
	newDim.ZIndex = SettingsFrame.ZIndex - 1
	newDim.Visible = false
	newDim.Active = false
	newDim.Parent = SettingsGui
	dimOverlay = newDim
end

local function closePanel(instant)
	if not isOpen and not SettingsGui.Enabled then return end

	if instant then
		isClosing = false
		isOpen = false
		if openTween then openTween:Cancel() end
		if dimTween then dimTween:Cancel() end
		SettingsGui.Enabled = false
		SettingsFrame.Visible = false
		SettingsFrame.Position = CLOSED_POS
		if dimOverlay then
			dimOverlay.Visible = false
			dimOverlay.Active = false
			dimOverlay.BackgroundTransparency = 1
		end
		return
	end

	if isClosing then return end
	isClosing = true

	if dimOverlay then
		if dimTween then dimTween:Cancel() end
		dimTween = TweenService:Create(dimOverlay, TweenInfo.new(0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.In), { BackgroundTransparency = 1 })
		dimTween:Play()
	end

	if openTween then openTween:Cancel() end
	openTween = TweenService:Create(SettingsFrame, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = CLOSED_POS })
	openTween:Play()

	task.delay(0.18, function()
		if not isClosing then return end
		isClosing = false
		isOpen = false
		SettingsGui.Enabled = false
		SettingsFrame.Visible = false
		SettingsFrame.Position = CLOSED_POS
		if dimOverlay then
			dimOverlay.Visible = false
			dimOverlay.Active = false
		end
	end)
end

local function openPanel()
	if isOpen and SettingsGui.Enabled and not isClosing then return end
	isClosing = false
	isOpen = true
	SettingsGui.Enabled = true
	SettingsFrame.Visible = true
	SettingsFrame.Position = CLOSED_POS

	for _, toggle in ipairs(TOGGLES) do applyVisual(getToggleRow(toggle.row), getDisplay(toggle)) end

	if dimOverlay then
		if dimTween then dimTween:Cancel() end
		dimOverlay.Visible = true
		dimOverlay.Active = true
		dimOverlay.BackgroundTransparency = 1
		dimTween = TweenService:Create(dimOverlay, TweenInfo.new(0.20, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { BackgroundTransparency = 0.55 })
		dimTween:Play()
	end

	if openTween then openTween:Cancel() end
	openTween = TweenService:Create(SettingsFrame, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = OPEN_POS })
	openTween:Play()
end

CloseButton.Activated:Connect(function() closePanel() end)

if dimOverlay then
	dimOverlay.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			closePanel()
		end
	end)
end

local function handleOpenEvent(action)
	if action == "Close" then
		closePanel()
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
MenuEvents.Get("OpenSettingsPanel").Event:Connect(handleOpenEvent)
MenuEvents.CloseAll.Event:Connect(function(exceptMenuName)
	if exceptMenuName ~= "Settings" then
		closePanel(true)
	end
end)
MenuEvents.MarkReady("Settings", function() return isOpen end)
closePanel(true)
UserInputService.InputBegan:Connect(function(input, processed) if not processed and input.KeyCode == Enum.KeyCode.Escape and isOpen then closePanel() end end)