local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local MarketplaceService = game:GetService("MarketplaceService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local SuitCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SuitCatalog"))
local MenuEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MenuEvents"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local EquipSkin = Remotes:WaitForChild("EquipSkin")
local EvolveSkinUpdate = Remotes:WaitForChild("EvolveSkinUpdate")

local REQUIREMENT_FAIL_SOUND_ID = "rbxassetid://132281440773764"
local requirementFailSound = SoundService:FindFirstChild("SpeedsterRequirementFailSound")
if not requirementFailSound or not requirementFailSound:IsA("Sound") then
    if requirementFailSound then requirementFailSound:Destroy() end
    requirementFailSound = Instance.new("Sound")
    requirementFailSound.Name = "SpeedsterRequirementFailSound"
    requirementFailSound.Parent = SoundService
end
requirementFailSound.SoundId = REQUIREMENT_FAIL_SOUND_ID
requirementFailSound.Volume = 0.9

local function playRequirementFailSound()
    requirementFailSound.TimePosition = 0
    SoundService:PlayLocalSound(requirementFailSound)
end

local EVOLVE_SOUND_ID = "rbxassetid://80736831159506"
local evolveSound = Instance.new("Sound")
evolveSound.Name = "SuitEvolveSound"
evolveSound.SoundId = EVOLVE_SOUND_ID
evolveSound.Volume = 0.9
evolveSound.Parent = SoundService

local EVOLVE_CHAIN = {}
for _, entry in ipairs(SuitCatalog.Ordered) do
    table.insert(EVOLVE_CHAIN, {
        SkinId = entry.Id, DisplayName = entry.DisplayName,
        PreviewAssetId = entry.PreviewAssetId, RequiredLevel = entry.RequiredLevel,
        RequiredRebirths = entry.RequiredRebirths or 0, Stamina = entry.Stamina,
    })
end

local function getSuitSpeedMultiplier(skinId)
    skinId = tostring(skinId or "")
    local defaultMultiplier = tonumber(Config.DefaultSuitSpeedGainMultiplier) or 1
    local multipliers = Config.SuitSpeedGainMultipliers
    if type(multipliers) == "table" and multipliers[skinId] ~= nil then
        return tonumber(multipliers[skinId]) or defaultMultiplier
    end
    return defaultMultiplier
end

local function formatMultiplier(value)
    value = tonumber(value) or 1
    if value >= 1000000 then return string.format("%.2e", value)
    elseif value >= 100 then return string.format("%.0f", value)
    elseif value >= 10 then return string.format("%.1f", value):gsub("0+$", ""):gsub("%.$", "")
    end
    return string.format("%.2f", value):gsub("0+$", ""):gsub("%.$", "")
end

local function getSkinInfo(skinId)
    for _, info in ipairs(EVOLVE_CHAIN) do
        if info.SkinId == skinId then return info end
    end
    return nil
end

local function getNextSkinInfo(ownedSkins)
    for _, info in ipairs(EVOLVE_CHAIN) do
        if ownedSkins[info.SkinId] ~= true then return info end
    end
    return nil
end

local function getHighestOwnedSkinInfo(ownedSkins)
    for index = #EVOLVE_CHAIN, 1, -1 do
        local info = EVOLVE_CHAIN[index]
        if ownedSkins[info.SkinId] == true then return info end
    end
    return nil
end

local function getSuitDisplayName(skinId)
    if skinId == "" then return "Current" end
    local info = getSkinInfo(skinId)
    if info then return info.DisplayName end
    return skinId:gsub("(%l)(%u)", "%1 %2")
end

local function getSkinPreviewImage(skinId, fallback)
    if skinId == "" then return fallback end
    local info = getSkinInfo(skinId)
    if info and info.PreviewAssetId then
        return "rbxthumb://type=Asset&id=" .. tostring(info.PreviewAssetId) .. "&w=420&h=420"
    end
    return fallback
end

local function thumbnailForUserId(userId)
    local ok, content = pcall(function()
        return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.AvatarThumbnail, Enum.ThumbnailSize.Size420x420)
    end)
    return ok and content or ""
end

local cachedThumbnail = ""
task.spawn(function() cachedThumbnail = thumbnailForUserId(player.UserId) end)

-- UIS refs
local gui = playerGui:WaitForChild("Evolve")
local frame = gui:WaitForChild("Evolve")
local closeButton = frame:WaitForChild("Close")
local beforeLabel = frame:WaitForChild("Before")
local afterLabel = frame:WaitForChild("After")
local evolveButton = frame:WaitForChild("EvolveButton")
local progressFrame = frame:WaitForChild("ProgressFrame")
local iconBefore = frame:WaitForChild("Iconbefore")
local iconAfter = frame:WaitForChild("Iconafter")
local nameBefore = frame:WaitForChild("NameBefore")
local nameAfter = frame:WaitForChild("NameAfter")
local speedBefore = frame:WaitForChild("SpeedBefore")
local speedAfter = frame:WaitForChild("SpeedAfter")

-- Keep the Studio-authored label geometry intact.
-- Defensively ensure Background texture never covers content or paints white
local bgTexture = frame:FindFirstChild("Background")
if bgTexture and bgTexture:IsA("GuiObject") then
    bgTexture.ZIndex = 0
    bgTexture.BackgroundTransparency = 1
end

for _, child in ipairs(frame:GetChildren()) do
    if child:IsA("GuiObject") and child.Name ~= "Background" then
        child.ZIndex = math.max(child.ZIndex, 2)
    end
end
closeButton.ZIndex = math.max(closeButton.ZIndex, 5)
evolveButton.ZIndex = math.max(evolveButton.ZIndex, 4)
iconBefore.BackgroundTransparency = 1
iconAfter.BackgroundTransparency = 1

local updateProgress = require(ReplicatedStorage.Shared.ProgressBar).Bind(progressFrame)
local currentUnlocked = false
local currentNextSkinId = ""
local maxEvolved = false
local currentOwnedSkins = {}
local isOpen = false
local pendingEvolveSoundSkinId = nil

local function updateFromData(data)
    data = type(data) == "table" and data or {}
    local currentLevel = tonumber(data.Level) or player:GetAttribute("Level") or 1
    local currentRebirths = tonumber(data.Rebirths) or tonumber(player:GetAttribute("Rebirths")) or 0
    local currentSkinId = tostring(data.EquippedSkin or player:GetAttribute("EquippedSkin") or "")
    if type(data.OwnedSkins) == "table" then currentOwnedSkins = data.OwnedSkins end
    if SuitCatalog.IsValid(currentSkinId) then currentOwnedSkins[currentSkinId] = true end
    currentOwnedSkins[SuitCatalog.DefaultSkinId or "FlashSuit"] = true

    local nextInfo = getNextSkinInfo(currentOwnedSkins)
    local highestOwnedInfo = getHighestOwnedSkinInfo(currentOwnedSkins)
    local beforeSkinId = highestOwnedInfo and highestOwnedInfo.SkinId or currentSkinId
    local requiredLevel = nextInfo and (tonumber(nextInfo.RequiredLevel) or 0) or 0
    local requiredRebirths = nextInfo and (tonumber(nextInfo.RequiredRebirths) or 0) or 0
    local nextSkinId = nextInfo and nextInfo.SkinId or ""

    currentNextSkinId = nextSkinId
    maxEvolved = nextInfo == nil
    local unlocked = nextInfo ~= nil and currentLevel >= requiredLevel and currentRebirths >= requiredRebirths
    currentUnlocked = unlocked

    nameBefore.Text = getSuitDisplayName(beforeSkinId)
    nameAfter.Text = nextInfo and getSuitDisplayName(nextSkinId) or "Max Evolved"
    speedBefore.Text = formatMultiplier(getSuitSpeedMultiplier(beforeSkinId)) .. " Speed/s"
    speedAfter.Text = nextInfo and (formatMultiplier(getSuitSpeedMultiplier(nextSkinId)) .. " Speed/s") or "MAX"
    iconBefore.Image = getSkinPreviewImage(beforeSkinId, cachedThumbnail)
    iconAfter.Image = nextInfo and getSkinPreviewImage(nextSkinId, iconBefore.Image) or iconBefore.Image

    local ratio = maxEvolved and 1 or math.clamp(currentLevel / math.max(1, requiredLevel), 0, 1)
    local caption = "Max Evolved"
    if nextInfo then
        caption = "Level " .. math.floor(currentLevel) .. "/" .. requiredLevel
        if requiredRebirths > 0 then
            caption ..= " | Rebirths " .. math.floor(currentRebirths) .. "/" .. requiredRebirths
            ratio = math.min(ratio, math.clamp(currentRebirths / requiredRebirths, 0, 1))
        end
    end
    updateProgress(ratio, caption)
    local nameLabel = evolveButton:FindFirstChild("Name")
    if nameLabel then
        nameLabel.Text = maxEvolved and "Max" or "Evolve"
    end
    if maxEvolved or not unlocked then
        evolveButton.BackgroundColor3 = Color3.fromRGB(105, 105, 105)
        evolveButton.AutoButtonColor = false
    else
        evolveButton.BackgroundColor3 = Color3.fromRGB(255, 205, 20)
        evolveButton.AutoButtonColor = true
    end
end

local isClosing = false
local OPEN_POS = UDim2.new(0.5, 0, 0.48, 0)
local CLOSED_POS = UDim2.new(0.5, 0, 1.28, 0)
local openTween = nil
local dimTween = nil

local dimOverlay = gui:FindFirstChild("Dim")

local function closePanel(instant)
    if not isOpen and not gui.Enabled then return end

    if instant then
        isClosing = false
        isOpen = false
        if openTween then openTween:Cancel() end
        if dimTween then dimTween:Cancel() end
        gui.Enabled = false
        frame.Visible = false
        frame.Position = CLOSED_POS
        if dimOverlay and dimOverlay:IsA("GuiObject") then
            dimOverlay.Visible = false
            dimOverlay.Active = false
            dimOverlay.BackgroundTransparency = 1
        end
        return
    end

    if isClosing then return end
    isClosing = true

    if dimOverlay and dimOverlay:IsA("GuiObject") then
        if dimTween then dimTween:Cancel() end
        dimTween = TweenService:Create(dimOverlay, TweenInfo.new(0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.In), { BackgroundTransparency = 1 })
        dimTween:Play()
    end

    if openTween then openTween:Cancel() end
    openTween = TweenService:Create(frame, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = CLOSED_POS })
    openTween:Play()

    task.delay(0.18, function()
        if not isClosing then return end
        isClosing = false
        isOpen = false
        gui.Enabled = false
        frame.Visible = false
        frame.Position = CLOSED_POS
        if dimOverlay and dimOverlay:IsA("GuiObject") then
            dimOverlay.Visible = false
            dimOverlay.Active = false
        end
    end)
end

local function openPanel()
    if isOpen and gui.Enabled and not isClosing then return end
    isClosing = false
    isOpen = true
    gui.Enabled = true
    frame.Visible = true
    frame.Position = CLOSED_POS

    if dimOverlay and dimOverlay:IsA("GuiObject") then
        if dimTween then dimTween:Cancel() end
        dimOverlay.Visible = true
        dimOverlay.Active = true
        dimOverlay.BackgroundTransparency = 1
        dimTween = TweenService:Create(dimOverlay, TweenInfo.new(0.20, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { BackgroundTransparency = 0.55 })
        dimTween:Play()
    end

    if openTween then openTween:Cancel() end
    openTween = TweenService:Create(frame, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = OPEN_POS })
    openTween:Play()

    EquipSkin:FireServer("Sync")
    updateFromData({
        Level = player:GetAttribute("Level") or 1,
        Rebirths = player:GetAttribute("Rebirths") or 0,
        EquippedSkin = player:GetAttribute("EquippedSkin") or "",
    })
end

closeButton.Activated:Connect(function() closePanel() end)
if closeButton:IsA("GuiButton") then
    closeButton.MouseButton1Click:Connect(function() closePanel() end)
end
closeButton.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        closePanel()
    end
end)

if dimOverlay and dimOverlay:IsA("GuiObject") then
    dimOverlay.Active = true
    dimOverlay.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            closePanel()
        end
    end)
end

local function promptRebirthPurchaseOrMenu()
    local prodId = tonumber(Config.RebirthProductId)
    local passId = tonumber(Config.RebirthGamePassId)
    if prodId and prodId > 0 then
        MarketplaceService:PromptProductPurchase(player, prodId)
    elseif passId and passId > 0 then
        MarketplaceService:PromptGamePassPurchase(player, passId)
    else
        MenuEvents.Request("Rebirth")
    end
end

evolveButton.Activated:Connect(function()
    updateFromData({
        Level = player:GetAttribute("Level") or 1,
        Rebirths = player:GetAttribute("Rebirths") or 0,
        EquippedSkin = player:GetAttribute("EquippedSkin") or "",
    })
    if currentUnlocked and not pendingEvolveSoundSkinId and currentNextSkinId ~= "" then
        pendingEvolveSoundSkinId = currentNextSkinId
        EquipSkin:FireServer(currentNextSkinId)
    else
        if not maxEvolved and not currentUnlocked then
            playRequirementFailSound()
            local currentRebirths = tonumber(player:GetAttribute("Rebirths")) or 0
            local nextInfo = getNextSkinInfo(currentOwnedSkins)
            local requiredRebirths = nextInfo and (tonumber(nextInfo.RequiredRebirths) or 0) or 0
            if currentRebirths < requiredRebirths then
                promptRebirthPurchaseOrMenu()
            end
        end
    end
end)

progressFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        local currentRebirths = tonumber(player:GetAttribute("Rebirths")) or 0
        local nextInfo = getNextSkinInfo(currentOwnedSkins)
        local requiredRebirths = nextInfo and (tonumber(nextInfo.RequiredRebirths) or 0) or 0
        if currentRebirths < requiredRebirths then
            promptRebirthPurchaseOrMenu()
        end
    end
end)

EvolveSkinUpdate.OnClientEvent:Connect(function(data)
    if type(data) == "table" then
        local equippedSkin = tostring(data.EquippedSkin or player:GetAttribute("EquippedSkin") or "")
        if pendingEvolveSoundSkinId and equippedSkin == pendingEvolveSoundSkinId then
            evolveSound.TimePosition = 0
            evolveSound:Play()
            pendingEvolveSoundSkinId = nil
        end
        pendingEvolveSoundSkinId = nil
        updateFromData(data)
    end
end)

local openEvolvePanel = MenuEvents.Get("OpenEvolvePanel")
openEvolvePanel.Event:Connect(function(action)
    if action == "Open" or action == "LeftButtonSwitch" then
        openPanel()
    elseif action == "Close" then
        closePanel(true)
    else
        if isOpen then closePanel() else openPanel() end
    end
end)
MenuEvents.CloseAll.Event:Connect(function(exceptMenuName)
    if exceptMenuName == "Evolve" then return end
    closePanel(true)
end)
MenuEvents.MarkReady("Evolve", function() return isOpen end)
closePanel(true)

player:GetAttributeChangedSignal("Level"):Connect(function()
    updateFromData({Level = player:GetAttribute("Level") or 1, Rebirths = player:GetAttribute("Rebirths") or 0, EquippedSkin = player:GetAttribute("EquippedSkin") or ""})
end)
player:GetAttributeChangedSignal("Rebirths"):Connect(function()
    updateFromData({Level = player:GetAttribute("Level") or 1, Rebirths = player:GetAttribute("Rebirths") or 0, EquippedSkin = player:GetAttribute("EquippedSkin") or ""})
end)
player:GetAttributeChangedSignal("EquippedSkin"):Connect(function()
    local equippedSkin = tostring(player:GetAttribute("EquippedSkin") or "")
    if pendingEvolveSoundSkinId and equippedSkin == pendingEvolveSoundSkinId then
        evolveSound.TimePosition = 0
        evolveSound:Play()
        pendingEvolveSoundSkinId = nil
    end
    updateFromData({Level = player:GetAttribute("Level") or 1, Rebirths = player:GetAttribute("Rebirths") or 0, EquippedSkin = equippedSkin})
end)

print("[EvolveController] Loaded")
require(ReplicatedStorage.Shared.ConsolePanelSupport).Bind(gui, frame, evolveButton, closeButton, function() closePanel(true) end)
