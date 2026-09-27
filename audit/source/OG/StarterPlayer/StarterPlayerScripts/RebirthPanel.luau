local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local REQUIREMENT_FAIL_SOUND_ID = "rbxassetid://132281440773764"
local requirementFailSound = SoundService:FindFirstChild("SpeedsterRequirementFailSound")
if not requirementFailSound or not requirementFailSound:IsA("Sound") then
    if requirementFailSound then
        requirementFailSound:Destroy()
    end
    requirementFailSound = Instance.new("Sound")
    requirementFailSound.Name = "SpeedsterRequirementFailSound"
    requirementFailSound.Parent = SoundService
end
requirementFailSound.SoundId = REQUIREMENT_FAIL_SOUND_ID
requirementFailSound.Volume = 0.9
requirementFailSound.PlaybackSpeed = 1

local function playRequirementFailSound()
    requirementFailSound.TimePosition = 0
    SoundService:PlayLocalSound(requirementFailSound)
end

local StudUi = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("StudUi"))
local MenuEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MenuEvents"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RebirthRequest = Remotes:WaitForChild("RebirthRequest")
local RebirthUpdate = Remotes:WaitForChild("RebirthUpdate")

local openRebirthPanel = MenuEvents.Get("OpenRebirthPanel")
local openEvolvePanel = MenuEvents.Get("OpenEvolvePanel")
local openDailyPanel = MenuEvents.Get("OpenDailyPanel")
local openTrailsPanel = MenuEvents.Get("OpenTrailsPanel")
local openIndexPanel = MenuEvents.Get("OpenIndexPanel")
local openAurasPanel = MenuEvents.Get("OpenAurasPanel")
local openTeleportPanel = MenuEvents.Get("OpenTeleportPanel")
local openAbilitiesPanel = MenuEvents.Get("OpenAbilitiesPanel")

local PANEL_SIZE = Vector2.new(860, 545)
local OPEN_POSITION = UDim2.fromScale(0.5, 0.5)
local CLOSED_POSITION = UDim2.fromScale(0.5, 1.26)

local isOpen = false
local activeTween = nil
local dimTween = nil

local REBIRTH_ICON_IMAGE = "rbxassetid://110921523254175"
local REBIRTH_SOUND_ID = "rbxassetid://127039883737564"
local REBIRTH_HEADER_COLOR = Color3.fromRGB(255, 70, 225)
local SPEED_CARD_COLOR = Color3.fromRGB(20, 205, 255)
local LEVEL_CARD_COLOR = Color3.fromRGB(255, 210, 20)
local LEVEL_FILL_COLOR = Color3.fromRGB(95, 255, 25)
local REBIRTH_BUTTON_COLOR = Color3.fromRGB(225, 45, 255)
local DISABLED_BUTTON_COLOR = Color3.fromRGB(115, 115, 125)

local currentData = {
	Rebirths = player:GetAttribute("Rebirths") or 0,
	CurrentLevel = player:GetAttribute("Level") or 1,
	RequiredLevel = player:GetAttribute("NextRebirthLevelRequired") or 5,
	CurrentMultiplier = player:GetAttribute("RebirthMultiplier") or 1,
	NextMultiplier = 1.5,
	CanRebirth = false,
}

local function addCorner(instance, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 10)
	corner.Parent = instance
	return corner
end

local function addStroke(instance, thickness, color)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Color3.fromRGB(0, 0, 0)
	stroke.Thickness = thickness or 3
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = instance
	return stroke
end

local function makeText(parent, name, text, pos, size, textSize, color)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = pos
	label.Size = size
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	label.TextScaled = false
	label.TextSize = textSize
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.ZIndex = 12
	label.Parent = parent
	addStroke(label, math.max(2, math.floor(textSize / 12)))
	return label
end

local function makeButton(parent, name, text, pos, size, color)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Position = pos
	button.Size = size
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.BackgroundColor3 = color
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBlack
	button.Text = text
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextSize = 34
	button.TextXAlignment = Enum.TextXAlignment.Center
	button.TextYAlignment = Enum.TextYAlignment.Center
	button.ZIndex = 13
	button.Parent = parent
	addCorner(button, 10)
	addStroke(button, 4, Color3.fromRGB(0, 0, 0))
	StudUi.StyleButton(button, 10)
	return button
end

local function formatNumber(value)
	value = tonumber(value) or 0

	if value >= 1000000000000 then
		return string.format("%.2fT", value / 1000000000000)
	elseif value >= 1000000000 then
		return string.format("%.2fB", value / 1000000000)
	elseif value >= 1000000 then
		return string.format("%.2fM", value / 1000000)
	elseif value >= 1000 then
		return string.format("%.2fK", value / 1000)
	end

	return tostring(math.floor(value))
end

local function formatMultiplier(value)
	value = tonumber(value) or 1

	if value >= 1000000 then
		return string.format("%.2e", value)
	elseif value >= 100 then
		return string.format("%.0f", value)
	elseif value >= 10 then
		return string.format("%.1f", value):gsub("0+$", ""):gsub("%.$", "")
	end

	return string.format("%.2f", value):gsub("0+$", ""):gsub("%.$", "")
end

local oldGui = playerGui:FindFirstChild("RebirthPanelGui")
if oldGui then
	oldGui:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "RebirthPanelGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 79
gui.Enabled = false
gui.Parent = playerGui

local rebirthSound = Instance.new("Sound")
rebirthSound.Name = "RebirthSuccessSound"
rebirthSound.SoundId = REBIRTH_SOUND_ID
rebirthSound.Volume = 0.85
rebirthSound.Parent = gui

local lastKnownRebirthsForSound = tonumber(currentData.Rebirths) or 0
local pendingRebirthSound = false

local function playRebirthSound()
	rebirthSound.TimePosition = 0
	rebirthSound:Play()
end

local dim = Instance.new("Frame")
dim.Name = "Dim"
dim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
dim.BackgroundTransparency = 1
dim.Size = UDim2.fromScale(1, 1)
dim.ZIndex = 9
dim.Parent = gui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = CLOSED_POSITION
panel.Size = UDim2.fromOffset(PANEL_SIZE.X, PANEL_SIZE.Y)
panel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
panel.BackgroundTransparency = 0
panel.BorderSizePixel = 0
panel.Rotation = 0
panel.ZIndex = 10
panel.Parent = gui

                         
                                                                                             
local responsivePanelScale = Instance.new("UIScale")
responsivePanelScale.Name = "MobileResponsiveScale"
responsivePanelScale.Scale = 1
responsivePanelScale.Parent = panel

local function updateResponsivePanelScale()
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
	local inset = GuiService:GetGuiInset()
	local horizontalMargin = UserInputService.TouchEnabled and 18 or 40
	local verticalMargin = UserInputService.TouchEnabled and 14 or 34
	local availableWidth = math.max(1, viewport.X - horizontalMargin)
	local availableHeight = math.max(1, viewport.Y - inset.Y - verticalMargin)
	local fit = math.min(availableWidth / PANEL_SIZE.X, availableHeight / PANEL_SIZE.Y)
	local maximum = UserInputService.TouchEnabled and 0.98 or 1.08

	responsivePanelScale.Scale = math.clamp(fit, 0.42, maximum)
end

updateResponsivePanelScale()

if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsivePanelScale)
end
panel.ClipsDescendants = true
addCorner(panel, 14)
addStroke(panel, 5, Color3.fromRGB(0, 0, 0))
StudUi.AddSurface(panel, 10, 14)

local header = Instance.new("Frame")
header.Name = "Header"
header.BackgroundColor3 = REBIRTH_HEADER_COLOR
header.BackgroundTransparency = 0
header.BorderSizePixel = 0
header.Position = UDim2.fromOffset(0, 0)
header.Size = UDim2.new(1, 0, 0, 84)
header.ZIndex = 10
header.Parent = panel
header.ClipsDescendants = true
addCorner(header, 14)
addStroke(header, 5, Color3.fromRGB(0, 0, 0))
StudUi.AddSurface(header, 11, 14)

local headerIcon = Instance.new("ImageLabel")
headerIcon.Name = "RebirthHeaderIcon"
headerIcon.BackgroundTransparency = 1
headerIcon.Image = REBIRTH_ICON_IMAGE
headerIcon.ScaleType = Enum.ScaleType.Fit
headerIcon.AnchorPoint = Vector2.new(0, 0.5)
headerIcon.Position = UDim2.new(0, 10, 0.5, 0)
headerIcon.Size = UDim2.fromOffset(78, 78)
headerIcon.ZIndex = 35
headerIcon.Parent = header

local title = Instance.new("TextLabel")
title.Name = "Title"
title.BackgroundTransparency = 1
title.BorderSizePixel = 0
title.Text = "Rebirth"
title.Font = Enum.Font.FredokaOne
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
title.TextStrokeTransparency = 0
title.TextScaled = false
title.TextSize = 48
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextYAlignment = Enum.TextYAlignment.Center
title.Position = UDim2.new(0, 102, 0, 0)
title.Size = UDim2.new(1, -210, 1, 0)
title.ZIndex = 35
title.Parent = header

local closeX = makeButton(header, "TopRightXCloseButton", "X", UDim2.new(1, -38, 0.5, 0), UDim2.fromOffset(58, 58), Color3.fromRGB(255, 75, 75))
closeX.TextSize = 36

local beforeTitle = makeText(panel, "BeforeTitle", "Rebirth 0", UDim2.new(0, 55, 0, 88), UDim2.fromOffset(310, 40), 31, Color3.fromRGB(255, 255, 255))
local afterTitle = makeText(panel, "AfterTitle", "Rebirth 1", UDim2.new(0, 495, 0, 88), UDim2.fromOffset(310, 40), 31, Color3.fromRGB(255, 255, 255))

local function makeStatCard(name, centerXScale, y, color, text)
	local card = Instance.new("Frame")
	card.Name = name
	card.AnchorPoint = Vector2.new(0.5, 0)
	card.Position = UDim2.new(centerXScale, 0, 0, y)
	card.Size = UDim2.fromOffset(315, 76)
	card.BackgroundColor3 = color
	card.BackgroundTransparency = 0
	card.BorderSizePixel = 0
	card.ZIndex = 11
	card.Parent = panel
	addCorner(card, 10)
	addStroke(card, 4, Color3.fromRGB(0, 0, 0))
	StudUi.AddSurface(card, 12, 10)

	local watermark = Instance.new("ImageLabel")
	watermark.Name = "RebirthWatermark"
	watermark.BackgroundTransparency = 1
	watermark.AnchorPoint = Vector2.new(0.5, 0.5)
	watermark.Position = UDim2.fromScale(0.5, 0.5)
	watermark.Size = UDim2.fromOffset(92, 92)
	watermark.Image = REBIRTH_ICON_IMAGE
	watermark.ImageTransparency = 0.48
	watermark.ScaleType = Enum.ScaleType.Fit
	watermark.ZIndex = 14
	watermark.Parent = card

	local label = makeText(card, "Value", text, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 36, Color3.fromRGB(255, 255, 255))
	label.ZIndex = 16

	return card, label
end

local _, beforeMult = makeStatCard("CurrentMultiplierCard", 0.245, 132, SPEED_CARD_COLOR, "x1 Speed")
local _, afterMult = makeStatCard("NextMultiplierCard", 0.755, 132, SPEED_CARD_COLOR, "x1.5 Speed")
local _, currentLevelCardText = makeStatCard("CurrentLevelCard", 0.245, 220, LEVEL_CARD_COLOR, "Level 1")
local _, requiredLevelCardText = makeStatCard("RequiredLevelCard", 0.755, 220, LEVEL_CARD_COLOR, "Level 5")

local function makeComparisonArrow(name, y)
	local shadow = makeText(panel, name .. "Shadow", "➜", UDim2.new(0.5, -42, 0, y + 4), UDim2.fromOffset(84, 68), 58, SPEED_CARD_COLOR)
	shadow.ZIndex = 12

	local arrow = makeText(panel, name, "➜", UDim2.new(0.5, -42, 0, y), UDim2.fromOffset(84, 68), 58, Color3.fromRGB(255, 255, 255))
	arrow.ZIndex = 13
	return arrow
end

makeComparisonArrow("MultiplierArrow", 136)
makeComparisonArrow("LevelArrow", 224)

local resetWarning = makeText(panel, "ResetWarning", "Rebirth resets your level and speed!", UDim2.new(0.5, -380, 0, 301), UDim2.fromOffset(760, 42), 29, Color3.fromRGB(255, 82, 92))
resetWarning.ZIndex = 14

local levelBack = Instance.new("Frame")
levelBack.Name = "RebirthRequirementBar"
levelBack.AnchorPoint = Vector2.new(0.5, 0)
levelBack.Position = UDim2.new(0.5, 0, 0, 348)
levelBack.Size = UDim2.fromOffset(780, 54)
levelBack.BackgroundColor3 = Color3.fromRGB(225, 228, 233)
levelBack.BorderSizePixel = 0
levelBack.ZIndex = 11
levelBack.Parent = panel
addCorner(levelBack, 10)
addStroke(levelBack, 4, Color3.fromRGB(0, 0, 0))
StudUi.AddSurface(levelBack, 11, 10)

local levelFill = Instance.new("Frame")
levelFill.Name = "LevelFill"
levelFill.Size = UDim2.fromScale(0, 1)
levelFill.BackgroundColor3 = LEVEL_FILL_COLOR
levelFill.BorderSizePixel = 0
levelFill.ZIndex = 12
levelFill.Parent = levelBack
addCorner(levelFill, 10)

local levelText = makeText(levelBack, "LevelText", "Level 1/5", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 31, Color3.fromRGB(255, 255, 255))
StudUi.AddSurface(levelFill, 13, 10)
levelText.ZIndex = 15
local statusText = makeText(panel, "StatusText", "Reach Level 5 Required", UDim2.new(0.5, -390, 0, 407), UDim2.fromOffset(780, 38), 25, Color3.fromRGB(255, 82, 92))
local rebirthButton = makeButton(panel, "RebirthButton", "Rebirth", UDim2.new(0.5, 0, 0, 486), UDim2.fromOffset(300, 64), REBIRTH_BUTTON_COLOR)

local rebirthButtonScale = Instance.new("UIScale")
rebirthButtonScale.Name = "HoverScale"
rebirthButtonScale.Scale = 1
rebirthButtonScale.Parent = rebirthButton

local function tweenRebirthButtonScale(target, duration, easingStyle)
	TweenService:Create(rebirthButtonScale, TweenInfo.new(duration, easingStyle, Enum.EasingDirection.Out), {
		Scale = target,
	}):Play()
end

rebirthButton.MouseEnter:Connect(function()
	tweenRebirthButtonScale(1.04, 0.14, Enum.EasingStyle.Back)
end)

rebirthButton.MouseLeave:Connect(function()
	tweenRebirthButtonScale(1, 0.12, Enum.EasingStyle.Quad)
end)

rebirthButton.MouseButton1Down:Connect(function()
	tweenRebirthButtonScale(0.96, 0.07, Enum.EasingStyle.Quad)
end)

rebirthButton.MouseButton1Up:Connect(function()
	local releasedScale = UserInputService.TouchEnabled and 1 or 1.04
	tweenRebirthButtonScale(releasedScale, 0.11, Enum.EasingStyle.Back)
end)

local function applyData(data)
	if type(data) ~= "table" then
		data = {}
	end

	for key, value in pairs(data) do
		currentData[key] = value
	end

	local rebirths = tonumber(currentData.Rebirths) or 0
	local level = tonumber(currentData.CurrentLevel) or player:GetAttribute("Level") or 1
	local required = tonumber(currentData.RequiredLevel) or player:GetAttribute("NextRebirthLevelRequired") or 5
	local currentMultiplier = tonumber(currentData.CurrentMultiplier) or player:GetAttribute("RebirthMultiplier") or 1
	local nextMultiplier = tonumber(currentData.NextMultiplier) or (currentMultiplier * 1.5)

	required = math.max(1, required)
	local ratio = math.clamp(level / required, 0, 1)

	beforeTitle.Text = "Rebirth " .. tostring(math.floor(rebirths))
	beforeMult.Text = "x" .. formatMultiplier(currentMultiplier) .. " Speed"

	afterTitle.Text = "Rebirth " .. tostring(math.floor(rebirths + 1))
	afterMult.Text = "x" .. formatMultiplier(nextMultiplier) .. " Speed"
	currentLevelCardText.Text = "Level " .. tostring(math.floor(level))
	requiredLevelCardText.Text = "Level " .. tostring(math.floor(required))

	levelText.Text = "Level " .. tostring(math.floor(level)) .. "/" .. tostring(math.floor(required))

	TweenService:Create(levelFill, TweenInfo.new(0.34, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Size = UDim2.fromScale(ratio, 1),
	}):Play()

	local canRebirth = data.CanRebirth
	if canRebirth == nil then
		canRebirth = level >= required
	end

	if canRebirth then
		statusText.Text = data.Message or "Rebirth Ready! Gain x" .. formatMultiplier(nextMultiplier) .. " Speed"
		statusText.TextColor3 = Color3.fromRGB(55, 205, 72)
		rebirthButton.BackgroundColor3 = REBIRTH_BUTTON_COLOR
		rebirthButton.AutoButtonColor = true
	else
		statusText.Text = data.Message or ("Reach Level " .. tostring(math.floor(required)) .. " Required")
		statusText.TextColor3 = Color3.fromRGB(255, 82, 92)
		rebirthButton.BackgroundColor3 = DISABLED_BUTTON_COLOR
		rebirthButton.AutoButtonColor = false
	end
end

local function requestSync()
	RebirthRequest:FireServer("Sync")
end

local function cancelTweens()
	if activeTween then
		activeTween:Cancel()
		activeTween = nil
	end

	if dimTween then
		dimTween:Cancel()
		dimTween = nil
	end
end

local function openPanel()
	cancelTweens()
	requestSync()

	gui.Enabled = true
	isOpen = true

	panel.Position = CLOSED_POSITION
	panel.Rotation = 0
	panel.Size = UDim2.fromOffset(PANEL_SIZE.X, PANEL_SIZE.Y)
	dim.BackgroundTransparency = 1

	                                                        
	activeTween = TweenService:Create(panel, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = OPEN_POSITION,
		Rotation = 0,
	})

	dimTween = TweenService:Create(dim, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.45,
	})

	activeTween:Play()
	dimTween:Play()
end

local function closePanel()
	if not gui.Enabled then
		return
	end

	cancelTweens()
	isOpen = false

	panel.Position = OPEN_POSITION
	panel.Rotation = 0

	activeTween = TweenService:Create(panel, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = CLOSED_POSITION,
		Rotation = 0,
	})

	dimTween = TweenService:Create(dim, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		BackgroundTransparency = 1,
	})

	activeTween:Play()
	dimTween:Play()

	activeTween.Completed:Connect(function()
		if not isOpen then
			gui.Enabled = false
		end
	end)
end

local function togglePanel()
	if gui.Enabled and isOpen then
		closePanel()
	else
		openPanel()
	end
end

closeX.Activated:Connect(closePanel)

rebirthButton.Activated:Connect(function()
	local level = tonumber(currentData.CurrentLevel) or player:GetAttribute("Level") or 1
	local required = tonumber(currentData.RequiredLevel) or player:GetAttribute("NextRebirthLevelRequired") or 5
	if level < required then
		pendingRebirthSound = false
		playRequirementFailSound()
		return
	end

	        
	                                                                                  
	                                             
	pendingRebirthSound = true

	task.delay(6, function()
		pendingRebirthSound = false
	end)

	RebirthRequest:FireServer("Rebirth")
end)

openRebirthPanel.Event:Connect(togglePanel)
MenuEvents.CloseAll.Event:Connect(closePanel)
MenuEvents.MarkReady("Rebirth", function()
	return isOpen
end)

                                                                 
openEvolvePanel.Event:Connect(function()
	if gui.Enabled and isOpen then
		closePanel()
	end
end)

                                                                
openDailyPanel.Event:Connect(function()
	if gui.Enabled and isOpen then
		closePanel()
	end
end)

openTrailsPanel.Event:Connect(function()
	if gui.Enabled and isOpen then
		closePanel()
	end
end)

openIndexPanel.Event:Connect(function()
	if gui.Enabled and isOpen then
		closePanel()
	end
end)

openAurasPanel.Event:Connect(function()
	if gui.Enabled and isOpen then
		closePanel()
	end
end)

openTeleportPanel.Event:Connect(function()
	if gui.Enabled and isOpen then
		closePanel()
	end
end)

openAbilitiesPanel.Event:Connect(function()
	if gui.Enabled and isOpen then
		closePanel()
	end
end)

RebirthUpdate.OnClientEvent:Connect(function(data)
	if type(data) == "table" then
		local oldRebirths = tonumber(currentData.Rebirths) or lastKnownRebirthsForSound or 0
		local newRebirths = tonumber(data.Rebirths) or oldRebirths

		        
		                                                                                           
		                                                                                  
		if pendingRebirthSound and newRebirths > oldRebirths then
			playRebirthSound()
			pendingRebirthSound = false
		end

		lastKnownRebirthsForSound = newRebirths
	end

	applyData(data)
end)

player:GetAttributeChangedSignal("Level"):Connect(requestSync)
player:GetAttributeChangedSignal("Rebirths"):Connect(requestSync)
player:GetAttributeChangedSignal("NextRebirthLevelRequired"):Connect(requestSync)

task.defer(function()
	task.wait(1)
	applyData(currentData)
	requestSync()
end)


                                      
                                                                               
local function ensureRebirthGuiAlive()
	if gui and gui.Parent ~= playerGui then
		gui.Parent = playerGui
	end
end

player.CharacterAdded:Connect(function()
	isOpen = false
	task.defer(ensureRebirthGuiAlive)
	task.delay(0.5, ensureRebirthGuiAlive)
	task.delay(1, requestSync)
end)

print("[RebirthPanel] V220 reference-style UI loaded; rebirth behavior is unchanged.")
