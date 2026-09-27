                                                                            
                                             

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local MenuEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MenuEvents"))
local STAGE_COUNT = math.max(1, math.floor(tonumber(Config.StageCount) or 10))

local OPEN_POSITION = UDim2.fromScale(0.5, 0.5)
local CLOSED_POSITION = UDim2.fromScale(0.5, 1.25)
local TELEPORT_ICON_IMAGE = Config.TeleportMenuIconImage or "rbxassetid://72658080659794"
local WINS_ICON_IMAGE = Config.TeleportWinsIconImage or "rbxassetid://15540211845"
local STUD_TEXTURE_IMAGE = "rbxassetid://6927295847"
local STUD_TILE_SIZE = UDim2.fromOffset(100, 100)
local UI_CLICK_SOUND_ID = "rbxassetid://72264591133889"
local REQUIREMENT_FAIL_SOUND_ID = "rbxassetid://132281440773764"
local HEADER_COLOR = Color3.fromRGB(255, 174, 44)
local ROBUX_COLOR = Color3.fromRGB(178, 53, 244)
local WINS_COLOR = Color3.fromRGB(73, 230, 54)

local stageColors = {
    [1] = Color3.fromRGB(55, 239, 48),
    [2] = Color3.fromRGB(50, 231, 43),
    [3] = Color3.fromRGB(64, 221, 36),
    [4] = Color3.fromRGB(112, 214, 27),
    [5] = Color3.fromRGB(170, 211, 23),
    [6] = Color3.fromRGB(210, 198, 20),
    [7] = Color3.fromRGB(235, 168, 20),
    [8] = Color3.fromRGB(239, 119, 24),
    [9] = Color3.fromRGB(232, 67, 35),
    [10] = Color3.fromRGB(195, 55, 122),
    [11] = Color3.fromRGB(145, 65, 190),
}

local getOpenEvent = MenuEvents.Get

local openTeleportPanel = getOpenEvent("OpenTeleportPanel")
local otherPanelEvents = {
    getOpenEvent("OpenAbilitiesPanel"),
    getOpenEvent("OpenEvolvePanel"),
    getOpenEvent("OpenRebirthPanel"),
    getOpenEvent("OpenDailyPanel"),
    getOpenEvent("OpenTrailsPanel"),
    getOpenEvent("OpenAurasPanel"),
    getOpenEvent("OpenIndexPanel"),
}

local oldClickSound = SoundService:FindFirstChild("TeleportMenuClickSound")
if oldClickSound then
    oldClickSound:Destroy()
end

local clickSound = Instance.new("Sound")
clickSound.Name = "TeleportMenuClickSound"
clickSound.SoundId = UI_CLICK_SOUND_ID
clickSound.Volume = 0.65
clickSound.PlaybackSpeed = 1
clickSound.Parent = SoundService

task.spawn(function()
    pcall(function()
        ContentProvider:PreloadAsync({clickSound})
    end)
end)

local function playClick()
    clickSound.TimePosition = 0
    SoundService:PlayLocalSound(clickSound)
end

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

local function addCorner(instance, radius)
    local corner = instance:FindFirstChildOfClass("UICorner")
    if not corner then
        corner = Instance.new("UICorner")
        corner.Parent = instance
    end
    corner.CornerRadius = UDim.new(0, radius)
    return corner
end

local function addStroke(instance, thickness)
    local stroke = instance:FindFirstChildOfClass("UIStroke")
    if not stroke then
        stroke = Instance.new("UIStroke")
        stroke.Parent = instance
    end
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Color = Color3.fromRGB(0, 0, 0)
    stroke.Thickness = thickness
    stroke.LineJoinMode = Enum.LineJoinMode.Round
    return stroke
end

local function addTextStroke(instance, thickness)
    local stroke = Instance.new("UIStroke")
    stroke.Name = "TextOutline"
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
    stroke.Color = Color3.fromRGB(0, 0, 0)
    stroke.Thickness = thickness
    stroke.LineJoinMode = Enum.LineJoinMode.Round
    stroke.Parent = instance
    return stroke
end

local function styleText(instance, textSize, alignment)
    instance.Font = Enum.Font.FredokaOne
    instance.TextColor3 = Color3.fromRGB(255, 255, 255)
    instance.TextSize = textSize
    instance.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    instance.TextStrokeTransparency = 0
    instance.TextXAlignment = alignment or Enum.TextXAlignment.Center
    instance.TextYAlignment = Enum.TextYAlignment.Center
end

local function addTiledStudSurface(parent, baseZIndex, cornerRadius)
    local old = parent:FindFirstChild("UIStudSurface")
    if old then
        old:Destroy()
    end

    parent.ClipsDescendants = true

    local texture = Instance.new("ImageLabel")
    texture.Name = "UIStudSurface"
    texture.BackgroundColor3 = parent.BackgroundColor3
    texture.BackgroundTransparency = parent.BackgroundTransparency
    texture.BorderSizePixel = 0
    texture.Position = UDim2.fromOffset(0, 0)
    texture.Size = UDim2.fromScale(1, 1)
    texture.Image = STUD_TEXTURE_IMAGE
    texture.ImageColor3 = Color3.fromRGB(255, 255, 255)
    texture.ImageTransparency = 0
    texture.ScaleType = Enum.ScaleType.Tile
    texture.TileSize = STUD_TILE_SIZE
    texture.Active = false
    texture.Selectable = false
    texture.ZIndex = baseZIndex
    texture.Parent = parent
    addCorner(texture, cornerRadius)

    local gradient = Instance.new("UIGradient")
    gradient.Name = "StudSurfaceGradient"
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(0.52, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(248, 248, 248)),
    })
    gradient.Rotation = -90
    gradient.Parent = texture

    return texture
end

local function addButtonTextLayer(button, zIndex)
    local label = Instance.new("TextLabel")
    label.Name = "ButtonText"
    label.BackgroundTransparency = 1
    label.BorderSizePixel = 0
    label.Size = UDim2.fromScale(1, 1)
    label.Font = button.Font
    label.Text = button.Text
    label.TextColor3 = button.TextColor3
    label.TextSize = button.TextSize
    label.TextScaled = button.TextScaled
    label.TextWrapped = button.TextWrapped
    label.TextXAlignment = button.TextXAlignment
    label.TextYAlignment = button.TextYAlignment
    label.Active = false
    label.Selectable = false
    label.ZIndex = zIndex
    label.Parent = button
    addTextStroke(label, math.clamp(math.floor((button.TextSize or 16) * 0.11), 2, 4))

    button.TextTransparency = 1
    button.TextStrokeTransparency = 1

    button:GetPropertyChangedSignal("Text"):Connect(function()
        if label.Parent then
            label.Text = button.Text
        end
    end)

    return label
end

local function formatNumber(value)
    value = math.max(0, math.floor(tonumber(value) or 0))
    local text = tostring(value)
    while true do
        local changed
        text, changed = text:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
        if changed == 0 then
            return text
        end
    end
end

local stageOptions = {}
for _, option in ipairs(Config.TeleportStageOptions or {}) do
    local stage = math.floor(tonumber(option.Stage) or 0)
    if stage >= 1 and stage <= STAGE_COUNT then
        stageOptions[stage] = option
    end
end

local oldGui = playerGui:FindFirstChild("TeleportMenuGui")
if oldGui then
    oldGui:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "TeleportMenuGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 82
gui.Enabled = false
gui.Parent = playerGui

local dim = Instance.new("Frame")
dim.Name = "Dim"
dim.Size = UDim2.fromScale(1, 1)
dim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
dim.BackgroundTransparency = 1
dim.BorderSizePixel = 0
dim.ZIndex = 9
dim.Parent = gui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = CLOSED_POSITION
panel.Size = UDim2.fromOffset(720, 620)
panel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
panel.BackgroundTransparency = 0
panel.BorderSizePixel = 0
panel.ZIndex = 10
panel.Parent = gui
addCorner(panel, 18)
addStroke(panel, 5)
addTiledStudSurface(panel, 10, 18)

local responsiveScale = Instance.new("UIScale")
responsiveScale.Name = "ResponsiveScale"
responsiveScale.Parent = panel

local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 112)
header.BackgroundColor3 = HEADER_COLOR
header.BorderSizePixel = 0
header.ZIndex = 11
header.Parent = panel
addCorner(header, 16)
addStroke(header, 5)
addTiledStudSurface(header, 12, 16)

local titleIcon = Instance.new("ImageLabel")
titleIcon.Name = "TitleIcon"
titleIcon.AnchorPoint = Vector2.new(0, 0.5)
titleIcon.Position = UDim2.new(0, 8, 0.5, 0)
titleIcon.Size = UDim2.fromOffset(112, 112)
titleIcon.BackgroundTransparency = 1
titleIcon.Image = TELEPORT_ICON_IMAGE
titleIcon.ScaleType = Enum.ScaleType.Fit
titleIcon.ZIndex = 13
titleIcon.Parent = header

local title = Instance.new("TextLabel")
title.Name = "Title"
title.AnchorPoint = Vector2.new(0, 0.5)
title.Position = UDim2.new(0, 132, 0.5, 0)
title.Size = UDim2.fromOffset(380, 66)
title.BackgroundTransparency = 1
title.Text = "Teleport"
title.ZIndex = 13
title.Parent = header
styleText(title, 46, Enum.TextXAlignment.Left)

local closeButton = Instance.new("TextButton")
closeButton.Name = "Close"
closeButton.AnchorPoint = Vector2.new(1, 0.5)
closeButton.Position = UDim2.new(1, -16, 0.5, 0)
closeButton.Size = UDim2.fromOffset(62, 62)
closeButton.BackgroundColor3 = Color3.fromRGB(255, 85, 85)
closeButton.BorderSizePixel = 0
closeButton.AutoButtonColor = false
closeButton.Text = "X"
closeButton.ZIndex = 13
closeButton.Parent = header
styleText(closeButton, 32)
addCorner(closeButton, 12)
addStroke(closeButton, 4)
addTiledStudSurface(closeButton, 14, 12)
addButtonTextLayer(closeButton, 15)

local listFrame = Instance.new("ScrollingFrame")
listFrame.Name = "List"
listFrame.Position = UDim2.new(0, 22, 0, 124)
listFrame.Size = UDim2.new(1, -44, 1, -166)
listFrame.BackgroundTransparency = 1
listFrame.BorderSizePixel = 0
listFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
listFrame.CanvasSize = UDim2.fromOffset(0, 0)
listFrame.ScrollingDirection = Enum.ScrollingDirection.Y
listFrame.ScrollBarThickness = 9
listFrame.ScrollBarImageColor3 = HEADER_COLOR
listFrame.ZIndex = 12
listFrame.Parent = panel

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 14)
listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = listFrame

local footerMessage = Instance.new("TextLabel")
footerMessage.Name = "FooterMessage"
footerMessage.AnchorPoint = Vector2.new(0.5, 1)
footerMessage.Position = UDim2.new(0.5, 0, 1, -8)
footerMessage.Size = UDim2.new(1, -40, 0, 28)
footerMessage.BackgroundTransparency = 1
footerMessage.Text = ""
footerMessage.ZIndex = 12
footerMessage.Parent = panel
styleText(footerMessage, 18)
footerMessage.TextColor3 = HEADER_COLOR

local isOpen = false
local activeTween = nil
local dimTween = nil
local promptBusy = false
local TeleportAction = nil
local TeleportUpdate = nil
local winsButtons = {}

local function readWins()
    local leaderstats = player:FindFirstChild("leaderstats")
    local wins = leaderstats and leaderstats:FindFirstChild("Wins")
    if wins and wins:IsA("ValueBase") then
        return math.max(0, math.floor(tonumber(wins.Value) or 0))
    end
    return 0
end

local function makePressScale(button)
    local scale = Instance.new("UIScale")
    scale.Name = "PressScale"
    scale.Scale = 1
    scale.Parent = button
    return scale
end

local function animatePress(scale)
    TweenService:Create(scale, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 0.94}):Play()
    task.delay(0.07, function()
        if scale.Parent then
            TweenService:Create(scale, TweenInfo.new(0.11, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
        end
    end)
end

local function createPriceButton(parent, name, position, size, color, zIndex)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Position = position
    button.Size = size
    button.BackgroundColor3 = color
    button.BorderSizePixel = 0
    button.AutoButtonColor = false
    button.Text = ""
    button.ZIndex = zIndex
    button.Parent = parent
    addCorner(button, 10)
    addStroke(button, 3)
    addTiledStudSurface(button, zIndex + 1, 10)
    return button
end

local function buildStageRow(stage)
    local option = stageOptions[stage] or {Stage = stage, WinsCost = 0, PriceRobux = 0, ProductId = 0}
    local productId = math.floor(tonumber(option.ProductId) or 0)
    local winsOnly = option.WinsOnly == true or productId <= 0

    local card = Instance.new("Frame")
    card.Name = "Stage" .. tostring(stage) .. "Card"
    card.LayoutOrder = stage
    card.Size = UDim2.new(1, -42, 0, 100)
    card.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
    card.BackgroundTransparency = 0.12
    card.BorderSizePixel = 0
    card.Parent = listFrame
    addCorner(card, 15)
    addStroke(card, 4)

    local colored = Instance.new("Frame")
    colored.Name = "ColoredRectangle"
    colored.Position = UDim2.fromOffset(4, 4)
    colored.Size = UDim2.new(1, -8, 1, -8)
    colored.BackgroundColor3 = stageColors[stage] or Color3.fromRGB(65, 220, 45)
    colored.BackgroundTransparency = 0.04
    colored.BorderSizePixel = 0
    colored.ZIndex = 14
    colored.Parent = card
    addCorner(colored, 12)
    addStroke(colored, 5)
    addTiledStudSurface(colored, 15, 12)

    local portal = Instance.new("ImageLabel")
    portal.Name = "TeleportBackgroundIcon"
    portal.AnchorPoint = Vector2.new(0.5, 0.5)
    portal.Position = UDim2.new(0.38, 0, 0.5, 0)
    portal.Size = UDim2.fromOffset(112, 112)
    portal.BackgroundTransparency = 1
    portal.Image = TELEPORT_ICON_IMAGE
    portal.ImageColor3 = Color3.fromRGB(255, 255, 255)
    portal.ImageTransparency = 0.34
    portal.ScaleType = Enum.ScaleType.Fit
    portal.ZIndex = 17
    portal.Parent = colored

    local stageLabel = Instance.new("TextLabel")
    stageLabel.Name = "StageLabel"
    stageLabel.Position = UDim2.fromOffset(18, 6)
    stageLabel.Size = UDim2.fromOffset(315, 84)
    stageLabel.BackgroundTransparency = 1
    stageLabel.Text = "Stage " .. tostring(stage)
    stageLabel.TextScaled = true
    stageLabel.TextWrapped = false
    stageLabel.ZIndex = 19
    stageLabel.Parent = colored
    styleText(stageLabel, 42, Enum.TextXAlignment.Left)
    local stageConstraint = Instance.new("UITextSizeConstraint")
    stageConstraint.MinTextSize = 28
    stageConstraint.MaxTextSize = 50
    stageConstraint.Parent = stageLabel

    local winsButton = createPriceButton(
        colored,
        "WinsTeleportButton",
        UDim2.new(1, -318, 0.5, -32),
        winsOnly and UDim2.fromOffset(292, 64) or UDim2.fromOffset(176, 64),
        WINS_COLOR,
        19
    )

    local trophy = Instance.new("ImageLabel")
    trophy.Name = "TrophyIcon"
    trophy.AnchorPoint = Vector2.new(0, 0.5)
    trophy.Position = UDim2.new(0, 7, 0.5, 0)
    trophy.Size = UDim2.fromOffset(55, 55)
    trophy.BackgroundTransparency = 1
    trophy.Image = WINS_ICON_IMAGE
    trophy.ScaleType = Enum.ScaleType.Fit
    trophy.ZIndex = 22
    trophy.Parent = winsButton

    local winsText = Instance.new("TextLabel")
    winsText.Name = "WinsPrice"
    winsText.Position = UDim2.new(0, 59, 0, 0)
    winsText.Size = UDim2.new(1, -64, 1, 0)
    winsText.BackgroundTransparency = 1
    winsText.Text = option.Free == true and "FREE" or formatNumber(option.WinsCost or 0)
    winsText.TextScaled = true
    winsText.Font = Enum.Font.FredokaOne
    winsText.TextColor3 = Color3.fromRGB(255, 255, 255)
    winsText.ZIndex = 22
    winsText.Parent = winsButton
    addTextStroke(winsText, 3)
    local winsConstraint = Instance.new("UITextSizeConstraint")
    winsConstraint.MinTextSize = 24
    winsConstraint.MaxTextSize = 40
    winsConstraint.Parent = winsText

    local robuxButton = createPriceButton(
        colored,
        "RobuxTeleportButton",
        UDim2.new(1, -132, 0.5, -32),
        UDim2.fromOffset(116, 64),
        ROBUX_COLOR,
        19
    )

    local robuxIcon = Instance.new("ImageLabel")
    robuxIcon.Name = "RobuxIcon"
    robuxIcon.AnchorPoint = Vector2.new(0, 0.5)
    robuxIcon.Position = UDim2.new(0, 7, 0.5, 0)
    robuxIcon.Size = UDim2.fromOffset(37, 37)
    robuxIcon.BackgroundTransparency = 1
    robuxIcon.Image = "rbxasset://textures/ui/common/robux.png"
    robuxIcon.ImageColor3 = Color3.fromRGB(255, 255, 255)
    robuxIcon.ScaleType = Enum.ScaleType.Fit
    robuxIcon.ZIndex = 22
    robuxIcon.Parent = robuxButton

    local robuxText = Instance.new("TextLabel")
    robuxText.Name = "RobuxPrice"
    robuxText.Position = UDim2.new(0, 39, 0, 0)
    robuxText.Size = UDim2.new(1, -43, 1, 0)
    robuxText.BackgroundTransparency = 1
    robuxText.Text = tostring(math.floor(tonumber(option.PriceRobux) or 0))
    robuxText.TextScaled = true
    robuxText.Font = Enum.Font.FredokaOne
    robuxText.TextColor3 = Color3.fromRGB(255, 255, 255)
    robuxText.ZIndex = 22
    robuxText.Parent = robuxButton
    addTextStroke(robuxText, 3)
    local robuxConstraint = Instance.new("UITextSizeConstraint")
    robuxConstraint.MinTextSize = 22
    robuxConstraint.MaxTextSize = 38
    robuxConstraint.Parent = robuxText

    if winsOnly then
        robuxButton.Visible = false
        robuxButton.Active = false
        robuxButton.Selectable = false
    end

    local winsPress = makePressScale(winsButton)
    local robuxPress = makePressScale(robuxButton)

    winsButtons[stage] = {
        Button = winsButton,
        Cost = math.max(0, math.floor(tonumber(option.WinsCost) or 0)),
    }

    winsButton.Activated:Connect(function()
        if not TeleportAction then
            footerMessage.Text = "Teleport server is still loading"
            return
        end

        playClick()
        animatePress(winsPress)

        local cost = math.max(0, math.floor(tonumber(option.WinsCost) or 0))
        if readWins() < cost then
            footerMessage.Text = "Not Enough Wins (Need " .. formatNumber(cost) .. " Wins)"
            playRequirementFailSound()
            return
        end

        TeleportAction:FireServer("Wins", stage)
    end)

    robuxButton.Activated:Connect(function()
        if promptBusy then
            return
        end
        if winsOnly then
			footerMessage.Text = "This stage uses Wins teleporting"
			return
		end
        if productId <= 0 then
            footerMessage.Text = "Robux teleport is not configured"
            return
        end

        promptBusy = true
        playClick()
        animatePress(robuxPress)
        task.wait(0.08)
        local ok, err = pcall(function()
            MarketplaceService:PromptProductPurchase(player, productId)
        end)
        if not ok then
            warn("[TeleportPanel] Could not open product prompt: " .. tostring(err))
            footerMessage.Text = "Could not open purchase prompt"
        end
        task.delay(0.75, function()
            promptBusy = false
        end)
    end)
end

local firstVisibleStage = Config.IsNewWorld1Map == true and 1 or 2
for stage = firstVisibleStage, STAGE_COUNT do
    buildStageRow(stage)
end

local function refreshAffordability()
    local wins = readWins()
    for _, data in pairs(winsButtons) do
        local affordable = wins >= data.Cost
        data.Button.BackgroundColor3 = affordable and WINS_COLOR or Color3.fromRGB(112, 144, 85)
        local surface = data.Button:FindFirstChild("UIStudSurface")
        if surface then
            surface.BackgroundColor3 = data.Button.BackgroundColor3
        end
    end
end

local function closePanel()
    if not gui.Enabled and not isOpen then
        return
    end
    if activeTween then activeTween:Cancel() end
    if dimTween then dimTween:Cancel() end
    isOpen = false

    activeTween = TweenService:Create(panel, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Position = CLOSED_POSITION,
    })
    activeTween:Play()
    activeTween.Completed:Connect(function()
        if not isOpen then
            gui.Enabled = false
        end
    end)

    dimTween = TweenService:Create(dim, TweenInfo.new(0.18), {BackgroundTransparency = 1})
    dimTween:Play()
end

local function openPanel()
    if activeTween then activeTween:Cancel() end
    if dimTween then dimTween:Cancel() end

    gui.Enabled = true
    isOpen = true
    footerMessage.Text = ""
    refreshAffordability()

    activeTween = TweenService:Create(panel, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = OPEN_POSITION,
    })
    activeTween:Play()

    dimTween = TweenService:Create(dim, TweenInfo.new(0.18), {BackgroundTransparency = 0.35})
    dimTween:Play()
end

local function togglePanel()
    if gui.Enabled and isOpen then
        closePanel()
    else
        openPanel()
    end
end

closeButton.Activated:Connect(function()
    playClick()
    closePanel()
end)

openTeleportPanel.Event:Connect(togglePanel)
MenuEvents.CloseAll.Event:Connect(closePanel)
MenuEvents.MarkReady("Teleport", function()
    return isOpen
end)
for _, event in ipairs(otherPanelEvents) do
    event.Event:Connect(function()
        if gui.Enabled and isOpen then
            closePanel()
        end
    end)
end

local function updateScale()
    local camera = Workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
    local inset = GuiService:GetGuiInset()
    local availableWidth = math.max(320, viewport.X - 20)
    local availableHeight = math.max(320, viewport.Y - inset.Y - 20)
    local fit = math.min(availableWidth / 720, availableHeight / 620)
    local minimum = UserInputService.TouchEnabled and 0.44 or 0.60
    local maximum = UserInputService.TouchEnabled and 0.98 or 1.08
    responsiveScale.Scale = math.clamp(fit, minimum, maximum)
end

updateScale()
if Workspace.CurrentCamera then
    Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end

local function hookWins()
    local leaderstats = player:FindFirstChild("leaderstats")
    local wins = leaderstats and leaderstats:FindFirstChild("Wins")
    if wins and wins:IsA("ValueBase") then
        wins:GetPropertyChangedSignal("Value"):Connect(refreshAffordability)
    end
    refreshAffordability()
end

player.ChildAdded:Connect(function(child)
    if child.Name == "leaderstats" then
        task.defer(hookWins)
    end
end)
task.defer(hookWins)

task.spawn(function()
    local remotes = ReplicatedStorage:WaitForChild("Remotes", 20)
    if not remotes then
        warn("[TeleportPanel] Remotes folder was not found")
        return
    end

    TeleportAction = remotes:WaitForChild("TeleportAction", 20)
    TeleportUpdate = remotes:WaitForChild("TeleportUpdate", 20)

    if TeleportUpdate then
        TeleportUpdate.OnClientEvent:Connect(function(state)
            if type(state) ~= "table" then
                return
            end
            local message = tostring(state.Message or "")
            footerMessage.Text = message
            if string.sub(message, 1, 15) == "Not Enough Wins" then
                playRequirementFailSound()
            end
            refreshAffordability()
            if state.Success == true then
                task.delay(0.08, function()
                    if gui.Enabled and isOpen then
                        closePanel()
                    end
                end)
            end
        end)
    end
end)

print(
    Config.IsNewWorld1Map == true
        and "[TeleportPanel] V306KBU loaded. New World 1 Stage 1-11 exact double-reward Wins teleport menu active."
        or "[TeleportPanel] V306EO loaded. Stage 2-10 studded Wins/Robux teleport menu active."
)
