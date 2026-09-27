         
                                                                   
                                                                                    

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local PurchaseButtonSound = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PurchaseButtonSound"))
local StudUi = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("StudUi"))

local SPEED_ICON_IMAGE = Config.SpeedProductBackgroundIconImage or "rbxassetid://18209577000"
local DISPLAY_REFRESH_SECONDS = tonumber(Config.SpeedProductDisplayRefreshSeconds) or 1
local ROUND_DOWN_STEP = math.max(1, tonumber(Config.SpeedProductDisplayRoundDownStep) or 10)

local SUFFIXES = {"", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc", "Ud", "Dd", "Td", "Qad", "Qid", "Sxd", "Spd", "Ocd", "Nod", "Vg"}

local GOLD_BUTTON_COLOR = Color3.fromRGB(255, 187, 38)

local old = playerGui:FindFirstChild("SpeedProductShopHUD")
if old then
    old:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "SpeedProductShopHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 43
gui.Parent = playerGui

local holder = Instance.new("Frame")
holder.Name = "SpeedProductHolder"
holder.AnchorPoint = Vector2.new(0.5, 1)
holder.Position = UDim2.new(0.5, 0, 1, -4)
holder.Size = UDim2.fromOffset(1092, 89)
holder.BackgroundTransparency = 1
holder.BorderSizePixel = 0
holder.Visible = false
holder.Parent = gui

local responsiveScale = Instance.new("UIScale")
responsiveScale.Name = "ResponsiveScale"
responsiveScale.Scale = 1
responsiveScale.Parent = holder

local list = Instance.new("UIListLayout")
list.FillDirection = Enum.FillDirection.Horizontal
list.HorizontalAlignment = Enum.HorizontalAlignment.Center
list.VerticalAlignment = Enum.VerticalAlignment.Center
list.Padding = UDim.new(0, 12)
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = holder

local function addStroke(instance, thickness)
    local stroke = Instance.new("UIStroke")
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
    stroke.Color = Color3.fromRGB(0, 0, 0)
    stroke.Thickness = thickness or 3
    stroke.LineJoinMode = Enum.LineJoinMode.Round
    stroke.Parent = instance
    return stroke
end

local function formatNumber(value)
    value = tonumber(value) or 0
    if value < 1000 then
        return tostring(math.floor(value + 0.5))
    end

    local tier = math.floor(math.log10(value) / 3) + 1
    if tier <= #SUFFIXES then
        local scaled = value / (1000 ^ (tier - 1))
        return string.format("%.0f%s", scaled, SUFFIXES[tier])
    end

    return string.format("%.0e", value)
end

local function normalizeOfferGain(value)
    value = tonumber(value) or 0
    if value <= 0 then
        return 0
    end

    if value < 1000 then
        if value >= ROUND_DOWN_STEP then
            return math.max(ROUND_DOWN_STEP, math.floor(value / ROUND_DOWN_STEP) * ROUND_DOWN_STEP)
        end
        return math.max(1, math.floor(value + 0.5))
    end

    local tier = math.floor(math.log10(value) / 3) + 1
    local suffixIndex = math.clamp(tier, 1, #SUFFIXES)
    local base = 1000 ^ (suffixIndex - 1)
    local scaled = value / base

    local cleanedScaled
    if scaled >= 10 then
        cleanedScaled = math.floor(scaled / 10) * 10
        if cleanedScaled < 10 then
            cleanedScaled = 10
        end
    else
        cleanedScaled = math.max(1, math.floor(scaled))
    end

    return cleanedScaled * base
end

local function readCurrentSpeed()
                                                                             
                                                                             
    local dataFolder = player:FindFirstChild("SpeedsterData")
    local rawSpeed = dataFolder and dataFolder:FindFirstChild("RawSpeed")
    if rawSpeed and rawSpeed:IsA("ValueBase") then
        return tonumber(rawSpeed.Value)
    end

    local attr = player:GetAttribute("RawSpeed")
    if typeof(attr) == "number" then
        return attr
    end

    local leaderstats = player:FindFirstChild("leaderstats")
    local speed = leaderstats and leaderstats:FindFirstChild("Speed")
    if speed and speed:IsA("ValueBase") then
        return tonumber(speed.Value)
    end

    return nil
end

local function cleanCurrentSpeed(value)
    value = tonumber(value) or tonumber(Config.StartingSpeed) or 1
    if value ~= value or value == math.huge or value == -math.huge then
        value = tonumber(Config.StartingSpeed) or 1
    end
    value = math.max(tonumber(Config.StartingSpeed) or 1, value)
    value = math.min(tonumber(Config.MaxStoredSpeed) or 1e50, value)
    return value
end

local function roundDisplayGain(value)
    return normalizeOfferGain(value)
end

local promptBusy = false
local tierWidgets = {}

local function addButton(tierData, index)
    local button = Instance.new("ImageButton")
    button.Name = "SpeedTier" .. tostring(tierData.Tier or index)
    button.LayoutOrder = index
    button.Size = UDim2.fromOffset(254, 77)
    button.BackgroundColor3 = GOLD_BUTTON_COLOR
    button.BackgroundTransparency = 0
    button.BorderSizePixel = 0
    button.AutoButtonColor = false
    button.ScaleType = Enum.ScaleType.Stretch
    button.ZIndex = 1
    button.Parent = holder

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 14)
    corner.Parent = button

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(0, 0, 0)
    stroke.Thickness = 3
    stroke.LineJoinMode = Enum.LineJoinMode.Round
    stroke.Parent = button

    StudUi.AddSurface(button, button.ZIndex + 1, 14, 7, 2)

    local icon = Instance.new("ImageLabel")
    icon.Name = "TierBackgroundIcon"
    icon.BackgroundTransparency = 1
    icon.AnchorPoint = Vector2.new(0.5, 0.5)
    icon.Position = UDim2.new(0.5, 0, 0.52, 0)
    icon.Size = UserInputService.TouchEnabled and UDim2.fromOffset(72, 72) or UDim2.fromOffset(94, 94)
    icon.Image = "rbxthumb://type=Asset&id=18209577000&w=420&h=420"
    icon.ImageColor3 = Color3.fromRGB(255, 255, 255)
    icon.ImageTransparency = 0.10
    icon.Rotation = 0
    icon.ZIndex = 3
    icon.Parent = button

    local amountLabel = Instance.new("TextLabel")
    amountLabel.Name = "AmountLabel"
    amountLabel.BackgroundTransparency = 1
    amountLabel.AnchorPoint = Vector2.new(0.5, 0.5)
    amountLabel.Position = UDim2.new(0.5, 0, 0.56, 0)
    amountLabel.Size = UDim2.new(0.94, 0, 0.88, 0)
    amountLabel.Font = Enum.Font.FredokaOne
    amountLabel.Text = "..."
    amountLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    amountLabel.TextScaled = true
    amountLabel.TextWrapped = false
    amountLabel.TextXAlignment = Enum.TextXAlignment.Center
    amountLabel.TextYAlignment = Enum.TextYAlignment.Center
    amountLabel.ZIndex = 5
    amountLabel.Parent = button
    local amountConstraint = Instance.new("UITextSizeConstraint")
    amountConstraint.MinTextSize = UserInputService.TouchEnabled and 18 or 60
    amountConstraint.MaxTextSize = UserInputService.TouchEnabled and 48 or 133
    amountConstraint.Parent = amountLabel
    addStroke(amountLabel, 4)

    local priceLabel = Instance.new("TextLabel")
    priceLabel.Name = "PriceLabel"
    priceLabel.BackgroundTransparency = 1
    priceLabel.AnchorPoint = Vector2.new(0, 0)
    priceLabel.Position = UDim2.fromOffset(1, -8)
    priceLabel.Size = UDim2.fromOffset(108, 38)
    priceLabel.Rotation = -11
    priceLabel.Font = Enum.Font.FredokaOne
    priceLabel.Text = "R$ " .. tostring(tonumber(tierData.PriceRobux) or 0)
    priceLabel.TextColor3 = Color3.fromRGB(124, 255, 65)
    priceLabel.TextScaled = true
    priceLabel.TextXAlignment = Enum.TextXAlignment.Left
    priceLabel.TextYAlignment = Enum.TextYAlignment.Center
    priceLabel.ZIndex = 6
    priceLabel.Parent = button
    local priceConstraint = Instance.new("UITextSizeConstraint")
    priceConstraint.MinTextSize = UserInputService.TouchEnabled and 6 or 14
    priceConstraint.MaxTextSize = UserInputService.TouchEnabled and 13 or 24
    priceConstraint.Parent = priceLabel
    addStroke(priceLabel, 3)

    local pressScale = Instance.new("UIScale")
    pressScale.Name = "PressScale"
    pressScale.Scale = 1
    pressScale.Parent = button

    local function animatePress()
        TweenService:Create(pressScale, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Scale = 0.94,
        }):Play()
        task.delay(0.07, function()
            if pressScale.Parent then
                TweenService:Create(pressScale, TweenInfo.new(0.11, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                    Scale = 1,
                }):Play()
            end
        end)
    end

    button.Activated:Connect(function()
        if promptBusy then
            return
        end

        local productId = tonumber(tierData.ProductId)
        if not productId or productId <= 0 then
            return
        end

        promptBusy = true
        PurchaseButtonSound.Play()
        animatePress()

                                                                             
                                                                                   
        task.wait(0.08)

        local ok, err = pcall(function()
            MarketplaceService:PromptProductPurchase(player, productId)
        end)

        if not ok then
            warn("[SpeedProductShop] Could not open product prompt: " .. tostring(err))
        end

        task.delay(0.75, function()
            promptBusy = false
        end)
    end)

    table.insert(tierWidgets, {
        TierData = tierData,
        Button = button,
        AmountLabel = amountLabel,
    })
end

local tiers = Config.SpeedProductTiers or {}
for index, tierData in ipairs(tiers) do
    addButton(tierData, index)
end

local function refreshTierAmounts()
    local rawCurrentSpeed = readCurrentSpeed()
    if rawCurrentSpeed == nil then
        return false
    end

    local currentSpeed = cleanCurrentSpeed(rawCurrentSpeed)

    for _, widget in ipairs(tierWidgets) do
        local gainMultiplier = tonumber(widget.TierData.GainMultiplier) or 0
        local rawGain = currentSpeed * gainMultiplier
        local roundedGain = roundDisplayGain(rawGain)
        widget.AmountLabel.Text = "+" .. formatNumber(roundedGain)
    end

    return true
end

local function updateResponsiveLayout()
    local camera = Workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
    local fit = math.min(viewport.X / 1920, viewport.Y / 1080)

    if UserInputService.TouchEnabled then
        responsiveScale.Scale = math.clamp(fit * 0.72, 0.25, 0.62)
        holder.Position = UDim2.new(0.5, 0, 1, -3)
    else
        responsiveScale.Scale = math.clamp(viewport.X / 1920, 0.62, 0.82)
        holder.Position = UDim2.new(0.5, 0, 1, -4)
    end
end

updateResponsiveLayout()

if Workspace.CurrentCamera then
    Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveLayout)
end

Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    updateResponsiveLayout()
    if Workspace.CurrentCamera then
        Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveLayout)
    end
end)

task.spawn(function()
                                                                                    
                                                                              
    while player.Parent and player:GetAttribute("DataLoaded") ~= true do
        task.wait(0.05)
    end

    while player.Parent and not refreshTierAmounts() do
        task.wait(0.05)
    end

    if player.Parent then
        holder.Visible = true
    end

    while player.Parent do
        task.wait(DISPLAY_REFRESH_SECONDS)
        refreshTierAmounts()
    end
end)

print("[SpeedProductShop] V306DS loaded. Every bottom +Speed button uses the exact shared Wins purchase-button sound.")
