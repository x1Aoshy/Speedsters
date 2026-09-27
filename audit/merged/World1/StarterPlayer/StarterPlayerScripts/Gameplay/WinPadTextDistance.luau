local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WinsMath = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WinsMath"))

local localPlayer = Players.LocalPlayer
local IS_WORLD2 = game.PlaceId == 96501592055150 or game.PlaceId == 116359653478954

local PAD_FOLDER_NAMES = {
    "WinPads_TO_PLACE",
    "NewWorld1ManualPads_Runtime",
    "World2ManualPads_Runtime",
    "World3ManualStagePads_Runtime",
}
local BILLBOARD_NAME = "WinRewardBillboard"
local LABEL_NAME = "RewardText"
local SKIP_BILLBOARD_NAME = "SkipStageBillboard"
local SKIP_LABEL_NAME = "SkipStageText"
local STAGE_DECOR_FOLDER_NAME = "StageDecor_Runtime"

local CLOSE_DISTANCE = 18
local FAR_DISTANCE = 117

local CLOSE_WIDTH = IS_WORLD2 and 170 or 118
local CLOSE_HEIGHT = IS_WORLD2 and 39 or 27
local CLOSE_TEXT_SIZE = IS_WORLD2 and 26 or 19

local FAR_SCALE = 0.52
local UPDATE_INTERVAL = 1 / 30

local tracked = {}
local elapsed = 0
local cachedMarkers = {}
local lastRefreshAt = -math.huge
local REFRESH_COOLDOWN = 0.5

local function clamp01(value)
    return math.clamp(value, 0, 1)
end

local function formatNumber(amount)
    amount = math.floor(amount or 0)
    local formatted = tostring(amount)
    local k
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
        if k == 0 then break end
    end
    return formatted
end

local function addTrackedEntry(pad, billboard, label)
    if not pad or not pad:IsA("BasePart") then
        return
    end

    if billboard
        and billboard:IsA("BillboardGui")
        and label
        and label:IsA("TextLabel")
    then
        table.insert(tracked, {
            Pad = pad,
            Billboard = billboard,
            Label = label,
            ParsedReward = nil,
            HasPersonalized = false,
        })
    end
end

local function refreshTracked()
    lastRefreshAt = os.clock()
    table.clear(tracked)

    for _, folderName in ipairs(PAD_FOLDER_NAMES) do
        local folder = Workspace:FindFirstChild(folderName)
        if folder then
            for _, child in ipairs(folder:GetChildren()) do
                if child:IsA("BasePart") and not child.Name:match("_BlackBase$") and not child.Name:match("_RuntimeBase$") then
                    local billboard = child:FindFirstChild(BILLBOARD_NAME)
                    local label = billboard and billboard:FindFirstChild(LABEL_NAME)
                    addTrackedEntry(child, billboard, label)
                end
            end
        end
    end

    for _, markerName in ipairs({"WINHERE", "X2HERE"}) do
        -- Cached: this is a recursive search of the whole Workspace (8k parts in
        -- World 2), and StreamingEnabled makes pads come and go constantly, so it
        -- used to run over and over while the player ran through a stage.
        local marker = cachedMarkers[markerName]
        if not marker or not marker:IsDescendantOf(Workspace) then
            marker = Workspace:FindFirstChild(markerName, true)
            cachedMarkers[markerName] = marker
        end
        if marker and marker:IsA("BasePart") then
            local billboard = marker:FindFirstChild(BILLBOARD_NAME)
            local label = billboard and billboard:FindFirstChild(LABEL_NAME)
            addTrackedEntry(marker, billboard, label)
        end
    end

    local stageDecor = Workspace:FindFirstChild(STAGE_DECOR_FOLDER_NAME)
    if stageDecor then
        for _, descendant in ipairs(stageDecor:GetDescendants()) do
            if descendant:IsA("BasePart") then
                local billboard = descendant:FindFirstChild(SKIP_BILLBOARD_NAME)
                local label = billboard and billboard:FindFirstChild(SKIP_LABEL_NAME)
                addTrackedEntry(descendant, billboard, label)
            end
        end
    end
end

local function scaleEntry(entry, cameraPosition)
    local pad = entry.Pad
    local billboard = entry.Billboard
    local label = entry.Label

    if not pad.Parent or not billboard.Parent or not label.Parent then
        return false
    end

    local distance = (cameraPosition - pad.Position).Magnitude
    local alpha = clamp01(
        (distance - CLOSE_DISTANCE)
            / (FAR_DISTANCE - CLOSE_DISTANCE)
    )

    local scale = 1 - ((1 - FAR_SCALE) * alpha)

    local targetW = math.max(1, math.round(CLOSE_WIDTH * scale))
    local targetH = math.max(1, math.round(CLOSE_HEIGHT * scale))
    local currentSize = billboard.Size
    if currentSize.X.Offset ~= targetW or currentSize.Y.Offset ~= targetH then
        billboard.Size = UDim2.fromOffset(targetW, targetH)
    end

    label.TextScaled = false
    local targetTextSize = math.max(10, math.round(CLOSE_TEXT_SIZE * scale))
    if label.TextSize ~= targetTextSize then
        label.TextSize = targetTextSize
    end

    if label.Name == LABEL_NAME and localPlayer then
        local baseReward = tonumber(pad:GetAttribute("BaseReward"))
        local isDouble = pad:GetAttribute("IsDoublePad") == true
            or pad.Name:match("X2") ~= nil
            or pad.Name:match("x2") ~= nil
            or (label.Text:find("2x") ~= nil and not entry.HasPersonalized)

        if not baseReward then
            if not entry.ParsedReward then
                local numStr = label.Text:match("%+?([%d,]+)%s*Wins") or label.Text:match("([%d,]+)%s*Wins")
                if numStr then
                    local parsed = tonumber((numStr:gsub(",", "")))
                    if isDouble and parsed then
                        entry.ParsedReward = parsed / 2
                    else
                        entry.ParsedReward = parsed
                    end
                end
            end
            baseReward = entry.ParsedReward
        end

        if baseReward and baseReward > 0 then
            -- Shared.WinsMath is the same module the server pays from, so a
            -- billboard can never promise a number the pad does not credit.
            entry.HasPersonalized = true
            local displayAmount = WinsMath.GetAdvertisedPadReward(baseReward, localPlayer, isDouble)
            local targetText = if isDouble
                then "2x Wins\n" .. formatNumber(displayAmount) .. " Wins"
                else "+" .. formatNumber(displayAmount) .. " Wins"
            if label.Text ~= targetText then
                label.Text = targetText
            end
        end
    end

    return true
end

Workspace.DescendantAdded:Connect(function(descendant)
    if descendant.Name == BILLBOARD_NAME
        or descendant.Name == SKIP_BILLBOARD_NAME
        or descendant.Name == "NewWorld1ManualPads_Runtime"
        or descendant.Name == "World2ManualPads_Runtime"
        or descendant.Name == "WinPads_TO_PLACE"
        or descendant.Name == STAGE_DECOR_FOLDER_NAME
    then
        task.defer(refreshTracked)
    end
end)

Workspace.DescendantRemoving:Connect(function(descendant)
    if descendant.Name == BILLBOARD_NAME
        or descendant.Name == SKIP_BILLBOARD_NAME
        or descendant.Name == "NewWorld1ManualPads_Runtime"
        or descendant.Name == "World2ManualPads_Runtime"
        or descendant.Name == "WinPads_TO_PLACE"
        or descendant.Name == STAGE_DECOR_FOLDER_NAME
    then
        task.defer(refreshTracked)
    end
end)

refreshTracked()

RunService.RenderStepped:Connect(function(deltaTime)
    elapsed += deltaTime

    if elapsed < UPDATE_INTERVAL then
        return
    end

    elapsed = 0

    local camera = Workspace.CurrentCamera
    if not camera then
        return
    end

    local cameraPosition = camera.CFrame.Position
    local needsRefresh = false

    for _, entry in ipairs(tracked) do
        if not scaleEntry(entry, cameraPosition) then
            needsRefresh = true
        end
    end

    -- A pad streaming out invalidates an entry, which used to rebuild the whole
    -- tracking table on the very next frame. At speedster pace that is a rebuild
    -- every few frames; twice a second is plenty for billboards.
    if needsRefresh and os.clock() - lastRefreshAt >= REFRESH_COOLDOWN then
        refreshTracked()
    end
end)
