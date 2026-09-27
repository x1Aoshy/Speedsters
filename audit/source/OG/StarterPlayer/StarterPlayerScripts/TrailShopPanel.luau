local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")
local SoundService = game:GetService("SoundService")
local MarketplaceService = game:GetService("MarketplaceService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local MenuEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MenuEvents"))

local SHOP_ACTION_SOUND_ID = "rbxassetid://72264591133889"
local oldShopActionSound = SoundService:FindFirstChild("TrailShopBuyEquipSound")
if oldShopActionSound then
    oldShopActionSound:Destroy()
end

local shopActionSound = Instance.new("Sound")
shopActionSound.Name = "TrailShopBuyEquipSound"
shopActionSound.SoundId = SHOP_ACTION_SOUND_ID
shopActionSound.Volume = 0.65
shopActionSound.PlaybackSpeed = 1
shopActionSound.Parent = SoundService

local function playShopActionSound()
    shopActionSound.TimePosition = 0
    shopActionSound:Play()
end

local PURCHASE_SUCCESS_SOUND_ID = "rbxassetid://80736831159506"
local purchaseSuccessSound = Instance.new("Sound")
purchaseSuccessSound.Name = "TrailShopPurchaseSuccessSound"
purchaseSuccessSound.SoundId = PURCHASE_SUCCESS_SOUND_ID
purchaseSuccessSound.Volume = 0.9
purchaseSuccessSound.Parent = SoundService

local function playPurchaseSuccessSound()
    purchaseSuccessSound.TimePosition = 0
    SoundService:PlayLocalSound(purchaseSuccessSound)
end

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

local getOpenEvent = MenuEvents.Get

                                                                      
local openTrailsPanel = getOpenEvent("OpenTrailsPanel")
local openEvolvePanel = getOpenEvent("OpenEvolvePanel")
local openRebirthPanel = getOpenEvent("OpenRebirthPanel")
local openDailyPanel = getOpenEvent("OpenDailyPanel")
local openIndexPanel = getOpenEvent("OpenIndexPanel")
local openAurasPanel = getOpenEvent("OpenAurasPanel")
local openTeleportPanel = getOpenEvent("OpenTeleportPanel")
local openAbilitiesPanel = getOpenEvent("OpenAbilitiesPanel")

local OPEN_POSITION = UDim2.fromScale(0.5, 0.5)
local CLOSED_POSITION = UDim2.fromScale(0.5, 1.25)
local TITLE_ICON_IMAGE = "rbxassetid://98640220351972"
local STUD_TEXTURE_IMAGE = "rbxassetid://6927295847"
local STUD_TILE_SIZE = UDim2.fromOffset(100, 100)
local TRAILS_HEADER_COLOR = Color3.fromRGB(205, 45, 255)

local fallbackTrails = {
    {
        Id = "Trail05",
        DisplayName = "Orange Trail",
        WinsCost = 10,
        RobuxPurchaseId = 3701439651,
        RobuxPurchaseType = "DeveloperProduct",
        RobuxPrice = 3,
        SpeedMultiplier = 2.5,
        SortOrder = 1,
        IconImage = "rbxassetid://116755979380966",
        ThemeColor = Color3.fromRGB(255, 143, 43),
    },
    {
        Id = "Trail02",
        DisplayName = "Red Trail",
        WinsCost = 1000,
        RobuxPurchaseId = 3701440521,
        RobuxPurchaseType = "DeveloperProduct",
        RobuxPrice = 7,
        SpeedMultiplier = 5,
        SortOrder = 2,
        IconImage = "rbxassetid://78795694520145",
        ThemeColor = Color3.fromRGB(255, 72, 72),
    },
    {
        Id = "Trail01",
        DisplayName = "Purple Trail",
        WinsCost = 10000,
        RobuxPurchaseId = 3701441929,
        RobuxPurchaseType = "DeveloperProduct",
        RobuxPrice = 15,
        SpeedMultiplier = 10,
        SortOrder = 3,
        IconImage = "rbxassetid://98640220351972",
        ThemeColor = Color3.fromRGB(176, 93, 255),
    },
    {
        Id = "Trail07",
        DisplayName = "Blue Trail",
        WinsCost = 100000,
        RobuxPurchaseId = 1940887606,
        RobuxPurchaseType = "Auto",
        SpeedMultiplier = 25,
        SortOrder = 4,
        IconImage = "rbxassetid://115062858785901",
        ThemeColor = Color3.fromRGB(66, 159, 255),
    },
    {
        Id = "Trail06",
        DisplayName = "Yellow Trail",
        WinsCost = 500000,
        RobuxPurchaseId = 3701548211,
        RobuxPurchaseType = "DeveloperProduct",
        RobuxPrice = 59,
        SpeedMultiplier = 50,
        SortOrder = 5,
        IconImage = "rbxassetid://119603954438829",
        ThemeColor = Color3.fromRGB(255, 220, 52),
    },
    {
        Id = "Trail03",
        DisplayName = "White Trail",
        WinsCost = 1000000,
        RobuxPurchaseId = 3701549435,
        RobuxPurchaseType = "DeveloperProduct",
        RobuxPrice = 79,
        SpeedMultiplier = 100,
        SortOrder = 6,
        IconImage = "rbxassetid://104187528469789",
        ThemeColor = Color3.fromRGB(242, 242, 242),
    },
    {
        Id = "Trail04",
        DisplayName = "Secret Trail",
        WinsCost = 10000000,
        RobuxPurchaseId = 3701550223,
        RobuxPurchaseType = "DeveloperProduct",
        RobuxPrice = 179,
        SpeedMultiplier = 1000,
        SortOrder = 7,
        IconImage = "rbxassetid://81036269316578",
        ThemeColor = Color3.fromRGB(20, 20, 20),
    },
}

local currentState = {
    Trails = fallbackTrails,
    Owned = {},
    EquippedTrail = "",
    Wins = 0,
    Message = "",
}

local TrailShopAction = nil
local TrailShopUpdate = nil
local isOpen = false
local activeTween = nil
local dimTween = nil

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

    stroke.Color = Color3.fromRGB(0, 0, 0)
    stroke.Thickness = thickness
    stroke.LineJoinMode = Enum.LineJoinMode.Round
    return stroke
end

local function styleText(instance, textSize, alignment)
    instance.Font = Enum.Font.FredokaOne
    instance.TextColor3 = Color3.fromRGB(255, 255, 255)
    instance.TextSize = textSize
    instance.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    instance.TextStrokeTransparency = 0
    instance.TextXAlignment =
        alignment or Enum.TextXAlignment.Center
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
    local old = button:FindFirstChild("ButtonText")

    if old then
        old:Destroy()
    end

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

    local outline = Instance.new("UIStroke")
    outline.Name = "TextOutline"
    outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
    outline.Color = Color3.fromRGB(0, 0, 0)
    outline.LineJoinMode = Enum.LineJoinMode.Round
    outline.Thickness = math.clamp(
        math.floor((button.TextSize or 16) * 0.11),
        2,
        4
    )
    outline.Parent = label

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
    value = tonumber(value) or 0

    if value >= 1e12 then
        return string.format("%.2fT", value / 1e12)
    elseif value >= 1e9 then
        return string.format("%.2fB", value / 1e9)
    elseif value >= 1e6 then
        return string.format("%.2fM", value / 1e6)
    elseif value >= 1e3 then
        return string.format("%.2fK", value / 1e3)
    end

    return tostring(math.floor(value))
end

local oldGui = playerGui:FindFirstChild("TrailShopGui")

if oldGui then
    oldGui:Destroy()
end

                                                                     
local gui = Instance.new("ScreenGui")
gui.Name = "TrailShopGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 81
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
header.BackgroundColor3 = TRAILS_HEADER_COLOR
header.BackgroundTransparency = 0
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
titleIcon.Image = TITLE_ICON_IMAGE
titleIcon.ScaleType = Enum.ScaleType.Fit
titleIcon.ZIndex = 13
titleIcon.Parent = header

local title = Instance.new("TextLabel")
title.Name = "Title"
title.AnchorPoint = Vector2.new(0, 0.5)
title.Position = UDim2.new(0, 132, 0.5, 0)
title.Size = UDim2.fromOffset(330, 66)
title.BackgroundTransparency = 1
title.Text = "Trails"
title.ZIndex = 13
title.Parent = header
styleText(title, 39, Enum.TextXAlignment.Left)
title.TextSize = 46

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
listFrame.ScrollBarImageColor3 =
    TRAILS_HEADER_COLOR
listFrame.ZIndex = 12
listFrame.Parent = panel

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 16)
listLayout.HorizontalAlignment =
    Enum.HorizontalAlignment.Center
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
footerMessage.TextColor3 = TRAILS_HEADER_COLOR

local function makeCardTemplate()
    local card = Instance.new("Frame")
    card.Name = "TrailCardTemplate"
    card.Size = UDim2.new(1, -42, 0, 180)
    card.BackgroundColor3 =
        Color3.fromRGB(24, 24, 28)
    card.BackgroundTransparency = 0.18
    card.BorderSizePixel = 0

    local colored = Instance.new("Frame")
    colored.Name = "ColoredRectangle"
    colored.Position = UDim2.fromOffset(4, 4)
    colored.Size = UDim2.new(1, -8, 1, -8)
    colored.BackgroundColor3 =
        Color3.fromRGB(176, 93, 255)
    colored.BackgroundTransparency = 0.08
    colored.BorderSizePixel = 0
    colored.ClipsDescendants = true
    colored.Parent = card

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "TitleLabel"
    titleLabel.Position = UDim2.fromOffset(18, 16)
    titleLabel.Size = UDim2.fromOffset(188, 44)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Parent = card

    local multiplier = Instance.new("TextLabel")
    multiplier.Name = "MultiplierLabel"
    multiplier.Position = UDim2.fromOffset(18, 122)
    multiplier.Size = UDim2.fromOffset(195, 36)
    multiplier.BackgroundTransparency = 1
    multiplier.Parent = card

    local icon = Instance.new("ImageLabel")
    icon.Name = "TrailIcon"
    icon.AnchorPoint = Vector2.new(0.5, 0.5)
    icon.Position = UDim2.fromScale(0.5, 0.5)
    icon.Size = UDim2.fromOffset(202, 176)
    icon.BackgroundTransparency = 1
    icon.ScaleType = Enum.ScaleType.Fit
    icon.Parent = card

    local action = Instance.new("TextButton")
    action.Name = "ActionButton"
    action.AnchorPoint = Vector2.new(1, 0)
    action.Position = UDim2.new(1, -14, 0, 20)
    action.Size = UDim2.fromOffset(152, 58)
    action.BorderSizePixel = 0
    action.AutoButtonColor = false
    action.Parent = card

    local future = Instance.new("Frame")
    future.Name = "FutureOptions"
    future.AnchorPoint = Vector2.new(1, 0)
    future.Position = UDim2.new(1, -14, 0, 100)
    future.Size = UDim2.fromOffset(152, 58)
    future.BackgroundTransparency = 1
    future.Parent = card

    local robux = Instance.new("TextButton")
    robux.Name = "RobuxButton"
    robux.Position = UDim2.fromOffset(0, 0)
    robux.Size = UDim2.fromOffset(152, 58)
    robux.Parent = future

    return card
end

local cardTemplate = makeCardTemplate()

local function clearCards()
    for _, child in ipairs(listFrame:GetChildren()) do
        if child:IsA("Frame")
            and child:GetAttribute("TrailShopCard") == true
        then
            child:Destroy()
        end
    end
end

local robuxPurchaseCache = {}

local function resolveRobuxPurchase(entry)
    local purchaseId = tonumber(entry.RobuxPurchaseId)
    if not purchaseId or purchaseId <= 0 then
        return nil, nil, nil
    end

    local cached = robuxPurchaseCache[purchaseId]
    if cached then
        return cached.PurchaseType, cached.Price, purchaseId
    end

    local requestedType = tostring(entry.RobuxPurchaseType or "DeveloperProduct")
    local configuredPrice = tonumber(entry.RobuxPrice)
    if requestedType == "DeveloperProduct" then
        robuxPurchaseCache[purchaseId] = {
            PurchaseType = "DeveloperProduct",
            Price = configuredPrice,
        }
        return "DeveloperProduct", configuredPrice, purchaseId
    end

    if requestedType == "GamePass" then
        local ok, info = pcall(function()
            return MarketplaceService:GetProductInfo(purchaseId, Enum.InfoType.GamePass)
        end)
        local price = ok and info and tonumber(info.PriceInRobux) or configuredPrice
        robuxPurchaseCache[purchaseId] = {PurchaseType = "GamePass", Price = price}
        return "GamePass", price, purchaseId
    end

                                                                             
                                                                          
                           
    local passOk, passInfo = pcall(function()
        return MarketplaceService:GetProductInfo(purchaseId, Enum.InfoType.GamePass)
    end)
    if passOk and passInfo then
        local price = tonumber(passInfo.PriceInRobux) or configuredPrice
        robuxPurchaseCache[purchaseId] = {PurchaseType = "GamePass", Price = price}
        return "GamePass", price, purchaseId
    end

    local productOk, productInfo = pcall(function()
        return MarketplaceService:GetProductInfo(purchaseId, Enum.InfoType.Product)
    end)
    if productOk and productInfo then
        local price = tonumber(productInfo.PriceInRobux) or configuredPrice
        robuxPurchaseCache[purchaseId] = {PurchaseType = "DeveloperProduct", Price = price}
        return "DeveloperProduct", price, purchaseId
    end

    return nil, configuredPrice, purchaseId
end

local function promptRobuxPurchase(entry)
    local purchaseType, _, purchaseId = resolveRobuxPurchase(entry)
    if not purchaseId then
        return false, "Robux purchase is not configured"
    end

    if purchaseType == "GamePass" then
        MarketplaceService:PromptGamePassPurchase(player, purchaseId)
        return true
    elseif purchaseType == "DeveloperProduct" then
        MarketplaceService:PromptProductPurchase(player, purchaseId)
        return true
    end

    return false, "Could not identify this Robux product"
end

local function buildCard(entry, owned, equipped)
    local card = cardTemplate:Clone()
    card.Name = entry.Id
    card.Visible = true
    card.Size = UDim2.new(1, -42, 0, 180)
    card.LayoutOrder = tonumber(entry.SortOrder) or 0
    card:SetAttribute("TrailShopCard", true)
    card.Parent = listFrame
    addCorner(card, 15)
    addStroke(card, 4)

    local colored =
        card:WaitForChild("ColoredRectangle")
    local titleLabel =
        card:WaitForChild("TitleLabel")
    local multiplier =
        card:WaitForChild("MultiplierLabel")
    local icon =
        card:WaitForChild("TrailIcon")
    local action =
        card:WaitForChild("ActionButton")
    local future =
        card:WaitForChild("FutureOptions")
    local robux =
        future:WaitForChild("RobuxButton")

    colored.BackgroundColor3 =
        entry.ThemeColor
        or Color3.fromRGB(176, 93, 255)
    colored.ZIndex = 14
    addCorner(colored, 12)
    local coloredOutline = addStroke(colored, 5)
    coloredOutline.Name = "ColoredRectangleOutline"

                                                                   
    addTiledStudSurface(colored, 15, 12)

    titleLabel.Text = entry.DisplayName or entry.Id
    titleLabel.ZIndex = 18
    styleText(
        titleLabel,
        24,
        Enum.TextXAlignment.Left
    )

    multiplier.Text =
        "x"
        .. tostring(
            tonumber(entry.SpeedMultiplier) or 1
        )
        .. " Speed"
    multiplier.ZIndex = 18
    styleText(
        multiplier,
        22,
        Enum.TextXAlignment.Left
    )
    multiplier.TextColor3 =
        Color3.fromRGB(255, 220, 54)

    icon.Image = entry.IconImage or ""
    icon.Size = UDim2.fromOffset(202, 176)
    icon.Position = UDim2.fromScale(0.5, 0.5)
    icon.ScaleType = Enum.ScaleType.Fit
    icon.ZIndex = 18

    action.ZIndex = 17
    action.BorderSizePixel = 0
    action.AutoButtonColor = false
    action.Active = true
    action.Selectable = true
    styleText(action, 23)
    addCorner(action, 10)
    addStroke(action, 3)

    robux.BackgroundColor3 = Color3.fromRGB(176, 80, 220)
    robux.BorderSizePixel = 0
    robux.AutoButtonColor = false
    robux.ZIndex = 17
    robux.Active = not owned
    robux.Selectable = not owned
    styleText(robux, 23)
    addCorner(robux, 10)
    addStroke(robux, 3)

    local configuredRobuxPrice = tonumber(entry.RobuxPrice)
    if owned then
        robux.Text = "Owned"
    elseif configuredRobuxPrice and configuredRobuxPrice > 0 then
        robux.Text = "R$ " .. tostring(math.floor(configuredRobuxPrice))
    else
        robux.Text = "Robux"
    end

    if owned then
        action.BackgroundColor3 =
            Color3.fromRGB(245, 187, 49)
        action.Text =
            equipped and "Equipped" or "Equip"
    else
        action.BackgroundColor3 =
            Color3.fromRGB(60, 208, 76)
        action.Text =
            formatNumber(entry.WinsCost or 0)
            .. " Wins"
    end

                                                                       
    addTiledStudSurface(action, 18, 10)
    addButtonTextLayer(action, 19)
    addTiledStudSurface(robux, 18, 10)
    addButtonTextLayer(robux, 19)

    if not owned and not configuredRobuxPrice then
        task.spawn(function()
            local _, livePrice = resolveRobuxPurchase(entry)
            if robux.Parent and not owned and livePrice and livePrice > 0 then
                robux.Text = "R$ " .. tostring(math.floor(livePrice))
            end
        end)
    end

    robux.Activated:Connect(function()
        if owned then
            return
        end
        playShopActionSound()
        local ok, err = promptRobuxPurchase(entry)
        if not ok then
            footerMessage.Text = tostring(err or "Robux purchase failed")
            playRequirementFailSound()
        else
            footerMessage.Text = "Opening Robux purchase..."
        end
    end)

    action.Activated:Connect(function()
        if not TrailShopAction then
            footerMessage.Text =
                "Shop server is still loading"
            return
        end

        playShopActionSound()

        if not owned then
            local cost = math.max(0, math.floor(tonumber(entry.WinsCost) or 0))
            local wins = math.max(0, math.floor(tonumber(currentState.Wins) or 0))
            if wins < cost then
                footerMessage.Text = "Not Enough Wins (Need " .. formatNumber(cost) .. " Wins)"
                playRequirementFailSound()
                return
            end
        end

        footerMessage.Text = owned and "Equipping..." or "Buying..."
        TrailShopAction:FireServer(
            owned and "Equip" or "Buy",
            entry.Id
        )
    end)
end

local function render()
    clearCards()
    footerMessage.Text = currentState.Message or ""

    for _, entry in ipairs(
        currentState.Trails or fallbackTrails
    ) do
        buildCard(
            entry,
            currentState.Owned
                and currentState.Owned[entry.Id] == true,
            currentState.EquippedTrail == entry.Id
        )
    end
end

local function closePanel()
    if activeTween then
        activeTween:Cancel()
    end

    if dimTween then
        dimTween:Cancel()
    end

    isOpen = false

    activeTween = TweenService:Create(
        panel,
        TweenInfo.new(
            0.22,
            Enum.EasingStyle.Quad,
            Enum.EasingDirection.In
        ),
        {
            Position = CLOSED_POSITION,
        }
    )
    activeTween:Play()

    activeTween.Completed:Connect(function()
        if not isOpen then
            gui.Enabled = false
        end
    end)

    dimTween = TweenService:Create(
        dim,
        TweenInfo.new(0.18),
        {
            BackgroundTransparency = 1,
        }
    )
    dimTween:Play()
end

local function openPanel()
    if activeTween then
        activeTween:Cancel()
    end

    if dimTween then
        dimTween:Cancel()
    end

    gui.Enabled = true
    isOpen = true
    render()

    if TrailShopAction then
        TrailShopAction:FireServer("RequestState")
    end

    activeTween = TweenService:Create(
        panel,
        TweenInfo.new(
            0.24,
            Enum.EasingStyle.Back,
            Enum.EasingDirection.Out
        ),
        {
            Position = OPEN_POSITION,
        }
    )
    activeTween:Play()

    dimTween = TweenService:Create(
        dim,
        TweenInfo.new(0.18),
        {
            BackgroundTransparency = 0.35,
        }
    )
    dimTween:Play()
end

local function togglePanel()
    if gui.Enabled and isOpen then
        closePanel()
    else
        openPanel()
    end
end

closeButton.Activated:Connect(closePanel)
openTrailsPanel.Event:Connect(togglePanel)
MenuEvents.CloseAll.Event:Connect(closePanel)
MenuEvents.MarkReady("Trails", function()
    return isOpen
end)

openEvolvePanel.Event:Connect(function()
    if gui.Enabled and isOpen then
        closePanel()
    end
end)

openRebirthPanel.Event:Connect(function()
    if gui.Enabled and isOpen then
        closePanel()
    end
end)

openDailyPanel.Event:Connect(function()
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

local function updateScale()
    local camera = Workspace.CurrentCamera
    local viewport =
        camera and camera.ViewportSize
        or Vector2.new(1920, 1080)

    local inset = GuiService:GetGuiInset()
    local availableWidth =
        math.max(320, viewport.X - 20)
    local availableHeight =
        math.max(320, viewport.Y - inset.Y - 20)

    local fit = math.min(
        availableWidth / 720,
        availableHeight / 620
    )
    local minimum = UserInputService.TouchEnabled and 0.44 or 0.60
    local maximum = UserInputService.TouchEnabled and 0.98 or 1.08

    responsiveScale.Scale = math.clamp(fit, minimum, maximum)
end

updateScale()

if Workspace.CurrentCamera then
    Workspace.CurrentCamera
        :GetPropertyChangedSignal("ViewportSize")
        :Connect(updateScale)
end

                                                               
task.spawn(function()
    local remotes =
        ReplicatedStorage:WaitForChild("Remotes", 20)

    if not remotes then
        warn(
            "[TrailShopPanel] Remotes folder was not found; "
                .. "UI still opens in preview mode."
        )
        return
    end

    TrailShopAction =
        remotes:WaitForChild("TrailShopAction", 20)
    TrailShopUpdate =
        remotes:WaitForChild("TrailShopUpdate", 20)

    if TrailShopUpdate then
        TrailShopUpdate.OnClientEvent:Connect(
            function(state)
                if type(state) == "table" then
                    currentState = state
                    if type(state.Message) == "string" and string.sub(state.Message, 1, 7) == "Bought " then
                        playPurchaseSuccessSound()
                    elseif type(state.Message) == "string" and string.sub(state.Message, 1, 15) == "Not Enough Wins" then
                        playRequirementFailSound()
                    end
                    render()
                end
            end
        )
    end

    if TrailShopAction then
        TrailShopAction:FireServer("RequestState")
    end
end)

render()

print(
    "[TrailShopPanel] V306FJ loaded. "
        .. "Buy/Equip click sound 72264591133889 and successful-buy Evolve sound 80736831159506 active."
)
