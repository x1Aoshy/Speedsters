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
local MenuPanelLayout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MenuPanelLayout"))
local SkinPreview = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SkinPreview"))
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
        PreviewAssetId = entry.PreviewAssetId, PreviewRig = entry.PreviewRig, RequiredLevel = entry.RequiredLevel,
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

-- A skin's picture (Shared.SkinPreview: its thumbnail, or its rig), or `fallback` (the
-- player's own avatar) for no skin.
local function showSkinPreview(icon, skinId, fallback)
    local info = skinId ~= "" and getSkinInfo(skinId) or nil
    if info and (info.PreviewRig or info.PreviewAssetId) then
        SkinPreview.Apply(icon, info)
    else
        SkinPreview.Apply(icon, nil)
        icon.Image = fallback
    end
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

local oldInfo = frame:FindFirstChild("InfoButton")
if oldInfo then oldInfo:Destroy() end
local oldHelp = gui:FindFirstChild("EvolveHelpCard")
if oldHelp then oldHelp:Destroy() end

local updateProgress = require(ReplicatedStorage.Shared.ProgressBar).Bind(progressFrame)
local currentUnlocked = false
local currentNextSkinId = ""
local maxEvolved = false
local currentOwnedSkins = {}
local Availability = require(ReplicatedStorage.Shared:WaitForChild("EvolveAvailability"))
local function refreshOpportunity()
    local owned = table.clone(currentOwnedSkins)
    local data = player:FindFirstChild("SpeedsterData")
    local folder = data and data:FindFirstChild("OwnedSkins")
    if folder then
        owned = {}
        for _, value in folder:GetChildren() do
            if value:IsA("BoolValue") and value.Value then owned[value.Name] = true end
        end
    end
    owned[SuitCatalog.DefaultSkinId] = true
    local count, nextId = Availability.Count(SuitCatalog.Ordered, owned,
        tonumber(player:GetAttribute("Level")) or 1, tonumber(player:GetAttribute("Rebirths")) or 0)
    if player:GetAttribute("EvolveGuideTarget") ~= nextId then player:SetAttribute("EvolveGuideTarget", nextId) end
    if player:GetAttribute("EvolveAvailableCount") ~= count then player:SetAttribute("EvolveAvailableCount", count) end
    return count
end
-- hasEvolvedBefore: a runner who owns an evolve-chain suit past the starter one has pressed
-- Evolve before and knows the button, so the guide is not for them (2026-09-21). This also
-- covers every save from before EvolveTutorialSeen was kept in the profile. Limited and
-- Exclusive suits (bought or granted) are outside SuitCatalog.Ordered and do not count.
local EVOLVE_CHAIN_IDS = {}
for _, entry in ipairs(SuitCatalog.Ordered) do EVOLVE_CHAIN_IDS[entry.Id] = true end
local function hasEvolvedBefore()
    local data = player:FindFirstChild("SpeedsterData")
    local folder = data and data:FindFirstChild("OwnedSkins")
    if not folder then return false end
    for _, value in folder:GetChildren() do
        if value:IsA("BoolValue") and value.Value and value.Name ~= SuitCatalog.DefaultSkinId
            and EVOLVE_CHAIN_IDS[value.Name] then
            return true
        end
    end
    return false
end
-- end hasEvolvedBefore
local isOpen = false
local pendingEvolveSoundSkinId = nil

-- redraw signature (2026-09-22 polish). Spamming Evolve ran the whole panel redraw on every
-- tap (Availability.Count, two SkinPreview.Apply, labels, colours, attributes). resolveInputs
-- is the cheap part: it reads the inputs the panel is drawn from and makes a signature of
-- them (Level, Rebirths, EquippedSkin, which evolve-chain suits are owned, maxEvolved, the
-- pending evolve, the avatar thumbnail used as fallback picture). drawPanel, the heavy part,
-- runs only when that signature differs from the one last drawn, so every real change (level
-- up, rebirth, evolve answer, EquippedSkin or OwnedSkins change, pending on/off) still redraws
-- once, and taps or repeated identical updates cost only the signature.
local lastDrawnSignature = nil

local function resolveInputs(data)
    data = type(data) == "table" and data or {}
    local currentLevel = tonumber(data.Level) or player:GetAttribute("Level") or 1
    local currentRebirths = tonumber(data.Rebirths) or tonumber(player:GetAttribute("Rebirths")) or 0
    local currentSkinId = tostring(data.EquippedSkin or player:GetAttribute("EquippedSkin") or "")
    if type(data.OwnedSkins) == "table" then
        currentOwnedSkins = data.OwnedSkins
    else
        local replicated = player:FindFirstChild("SpeedsterData")
        local ownedFolder = replicated and replicated:FindFirstChild("OwnedSkins")
        if ownedFolder then
            currentOwnedSkins = {}
            for _, value in ownedFolder:GetChildren() do
                if value:IsA("BoolValue") and value.Value then currentOwnedSkins[value.Name] = true end
            end
        end
    end
    if SuitCatalog.IsValid(currentSkinId) then currentOwnedSkins[currentSkinId] = true end
    currentOwnedSkins[SuitCatalog.DefaultSkinId or "FlashSuit"] = true

    local ownedChain = table.create(#EVOLVE_CHAIN)
    local isMax = true
    for index, info in ipairs(EVOLVE_CHAIN) do
        local has = currentOwnedSkins[info.SkinId] == true
        ownedChain[index] = if has then "1" else "0"
        if not has then isMax = false end
    end
    local signature = table.concat({
        tostring(currentLevel), tostring(currentRebirths), currentSkinId, table.concat(ownedChain),
        if isMax then "max" else "-", tostring(pendingEvolveSoundSkinId or ""), cachedThumbnail,
    }, "|")
    return {
        Level = currentLevel, Rebirths = currentRebirths, EquippedSkin = currentSkinId,
    }, signature
end

local function drawPanel(inputs, signature)
    lastDrawnSignature = signature
    local currentLevel, currentRebirths, currentSkinId = inputs.Level, inputs.Rebirths, inputs.EquippedSkin
    refreshOpportunity()

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
    showSkinPreview(iconBefore, beforeSkinId, cachedThumbnail)
    showSkinPreview(iconAfter, if nextInfo then nextSkinId else beforeSkinId, cachedThumbnail)

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
    -- An evolve on its way shows "..." on a dimmed button until the server answers (or the 4 s
    -- timeout below gives up).
    if nameLabel then
        nameLabel.Text = if pendingEvolveSoundSkinId then "..." elseif maxEvolved then "Max" else "Evolve"
    end
    if pendingEvolveSoundSkinId then
        evolveButton.BackgroundColor3 = Color3.fromRGB(150, 125, 40)
        evolveButton.AutoButtonColor = false
    elseif maxEvolved or not unlocked then
        evolveButton.BackgroundColor3 = Color3.fromRGB(105, 105, 105)
        evolveButton.AutoButtonColor = false
    else
        evolveButton.BackgroundColor3 = Color3.fromRGB(255, 205, 20)
        evolveButton.AutoButtonColor = true
    end
end

-- Redraws only when the inputs changed since the last draw; returns whether it drew.
local function updateFromData(data)
    local inputs, signature = resolveInputs(data)
    if signature == lastDrawnSignature then return false end
    drawPanel(inputs, signature)
    return true
end
-- end redraw signature

-- evolve request pacing (2026-09-22). SkinSystem answers every EquipSkin, ending with
-- { AnsweredRequest = n } for a numbered request (one its guard refuses gets a coalesced
-- answer), and the button waits for that answer before it takes another tap: one evolve in
-- flight at a time. Updates still on their way for an earlier request do not count as the
-- answer. A fire comes at least EQUIP_FIRE_SPACING after the last one (a tap right after the
-- panel's Sync waits the rest instead of being refused by the server's 0.25 s guard), and an
-- evolve with no answer after EVOLVE_ANSWER_TIMEOUT gives the button back and re-syncs.
-- The timeout stays at 4 s on purpose: the server always answers now (usually within half a
-- second, a slow save can take ~2.5 s), so the timeout is only a safety net for a lost answer.
-- A shorter one would give the button back while a slow evolve is still being saved and let a
-- second request leave with the first one still in flight.
local EQUIP_FIRE_SPACING = 0.3
local EVOLVE_ANSWER_TIMEOUT = 4
local lastEquipFireAt = -math.huge
local evolveRequestSerial = 0
local evolveSoundPlayed = false

local function attributeData()
    return {
        Level = player:GetAttribute("Level") or 1,
        Rebirths = player:GetAttribute("Rebirths") or 0,
        EquippedSkin = player:GetAttribute("EquippedSkin") or "",
    }
end

local function fireEquipSkin(...)
    lastEquipFireAt = os.clock()
    EquipSkin:FireServer(...)
end

local function finishEvolveRequest()
    pendingEvolveSoundSkinId = nil
    evolveRequestSerial += 1
end

-- The evolve sound, once per request, when the suit is on (attribute or panel update).
local function playEvolveSoundFor(equippedSkin)
    if pendingEvolveSoundSkinId and equippedSkin == pendingEvolveSoundSkinId and not evolveSoundPlayed then
        evolveSoundPlayed = true
        evolveSound.TimePosition = 0
        evolveSound:Play()
    end
end

local function sendEvolveRequest(skinId)
    evolveRequestSerial += 1
    local serial = evolveRequestSerial
    pendingEvolveSoundSkinId = skinId
    evolveSoundPlayed = false
    local function fire()
        if serial == evolveRequestSerial then fireEquipSkin(skinId, serial) end
    end
    local waitFor = EQUIP_FIRE_SPACING - (os.clock() - lastEquipFireAt)
    if waitFor > 0 then task.delay(waitFor, fire) else fire() end
    task.delay(EVOLVE_ANSWER_TIMEOUT, function()
        if serial ~= evolveRequestSerial then return end
        finishEvolveRequest()
        fireEquipSkin("Sync")
        updateFromData(attributeData())
    end)
    updateFromData(attributeData())
end
-- end evolve request pacing

local isClosing = false
local OPEN_POS = UDim2.new(0.5, 0, 0.48, 0)
local CLOSED_POS = UDim2.new(0.5, 0, 1.28, 0)
-- Phones: the designer's window is drawn bigger on compact touch screens, centred under the
-- top bar and slid in from wholly below the screen (MenuPanelLayout.BindPhoneFit).
MenuPanelLayout.BindPhoneFit(gui, frame, OPEN_POS, CLOSED_POS, function(fit)
    OPEN_POS, CLOSED_POS = fit.Open, fit.Closed
end)
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

    -- A pending evolve's answer refreshes the panel itself (one request in flight).
    if not pendingEvolveSoundSkinId then fireEquipSkin("Sync") end
    updateFromData({
        Level = player:GetAttribute("Level") or 1,
        Rebirths = player:GetAttribute("Rebirths") or 0,
        EquippedSkin = player:GetAttribute("EquippedSkin") or "",
    })

    -- Help card is available on-demand via the "?" InfoButton in the header.
end

closeButton.Activated:Connect(function() closePanel() end)

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
    -- One evolve in flight: the button shows "..." until its answer or the timeout.
    if pendingEvolveSoundSkinId then return end
    -- Only the cheap signature per tap: the panel is redrawn only when something changed
    -- since it was last drawn (currentUnlocked / currentNextSkinId are then still current).
    local inputs, signature = resolveInputs(attributeData())
    if signature ~= lastDrawnSignature then drawPanel(inputs, signature) end
    if currentUnlocked and currentNextSkinId ~= "" then
        -- Saved in the profile, not just this server (Shared/TutorialGuide.MarkSeen).
        require(ReplicatedStorage.Shared.TutorialGuide).MarkSeen(player, "Evolve")
        sendEvolveRequest(currentNextSkinId)
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
        if data.AnsweredRequest ~= nil then
            -- The end of an EquipSkin request (its state came just before): the button is free.
            if pendingEvolveSoundSkinId and data.AnsweredRequest == evolveRequestSerial then
                finishEvolveRequest()
                updateFromData(attributeData())
            end
            return
        end
        playEvolveSoundFor(tostring(data.EquippedSkin or player:GetAttribute("EquippedSkin") or ""))
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
-- A closing panel counts as closed, so reopening it quickly opens it (MenuEvents).
MenuEvents.MarkReady("Evolve", function() return isOpen and not isClosing end)
closePanel(true)

player:GetAttributeChangedSignal("Level"):Connect(function()
    updateFromData({Level = player:GetAttribute("Level") or 1, Rebirths = player:GetAttribute("Rebirths") or 0, EquippedSkin = player:GetAttribute("EquippedSkin") or ""})
end)
player:GetAttributeChangedSignal("Rebirths"):Connect(function()
    updateFromData({Level = player:GetAttribute("Level") or 1, Rebirths = player:GetAttribute("Rebirths") or 0, EquippedSkin = player:GetAttribute("EquippedSkin") or ""})
end)
player:GetAttributeChangedSignal("EquippedSkin"):Connect(function()
    local equippedSkin = tostring(player:GetAttribute("EquippedSkin") or "")
    playEvolveSoundFor(equippedSkin)
    updateFromData({Level = player:GetAttribute("Level") or 1, Rebirths = player:GetAttribute("Rebirths") or 0, EquippedSkin = equippedSkin})
end)

print("[EvolveController] Loaded")
-- Defer the first evolve guide while onboarding/loading or another guide is visible.
-- The badge continues to show remaining evolutions even after this guide is skipped.
-- 2026-09-21: it is taught once per account. It waits for DataLoaded (so the saved
-- EvolveTutorialSeen and the full OwnedSkins list are in), for a live character (not over
-- the death screen), and for a pending world-portal flight (WorldPortalCinematic waits for an
-- open guide, and the flight is given up after 180 s); a runner who evolved before never gets it.
task.spawn(function()
    local offered = false
    local quietSince = nil
    while player.Parent do
        local count = refreshOpportunity()
        local hud = playerGui:FindFirstChild("Mainhud")
        local sidebar = hud and hud:FindFirstChild("LeftSideBar")
        -- Torn down by another guide (or with nothing left to evolve): it was never seen through,
        -- offer it again.
        if offered and player:GetAttribute("EvolveTutorialSeen") ~= true
            and player:GetAttribute("GuidedTutorialOpen") ~= true then
            offered = false
        end
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if count > 0 and not offered and player:GetAttribute("EvolveTutorialSeen") ~= true
            and player:GetAttribute("DataLoaded") == true and not hasEvolvedBefore()
            and humanoid ~= nil and humanoid.Health > 0
            and player:GetAttribute("FirstTimeTutorialActive") ~= true
            and player:GetAttribute("GuidedTutorialOpen") ~= true
            and player:GetAttribute("WorldPortalCinematicActive") ~= true
            and player:GetAttribute("WorldPortalCinematicPending") ~= true
            and not playerGui:FindFirstChild("SpeedsterLoadingScreen")
            and hud and hud.Enabled and sidebar and sidebar.Visible then
            quietSince = quietSince or os.clock()
            if os.clock() - quietSince >= 1.5 then
                offered = require(ReplicatedStorage.Shared.TutorialGuide).Start(player, nil, "Evolve") == true
            end
        else
            quietSince = nil
        end
        task.wait(0.75)
    end
end)
require(ReplicatedStorage.Shared.ConsolePanelSupport).Bind(gui, frame, evolveButton, closeButton, function() closePanel(true) end)
