                                                  
  
                  
                                      
  
                
                                                                            
  
                                                  
                                              

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local IS_WORLD2 = game.PlaceId == 116359653478954

local PAD_FOLDER_NAME = "WinPads_TO_PLACE"
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

local function clamp01(value)
    return math.clamp(value, 0, 1)
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
        })
    end
end

local function refreshTracked()
    table.clear(tracked)

    local folder = Workspace:FindFirstChild(PAD_FOLDER_NAME)
    if folder then
        for _, child in ipairs(folder:GetChildren()) do
            if child:IsA("BasePart") and not child.Name:match("_BlackBase$") then
                local billboard = child:FindFirstChild(BILLBOARD_NAME)
                local label = billboard and billboard:FindFirstChild(LABEL_NAME)
                addTrackedEntry(child, billboard, label)
            end
        end
    end

    for _, markerName in ipairs({"WINHERE", "X2HERE"}) do
        local marker = Workspace:FindFirstChild(markerName, true)
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

    billboard.Size = UDim2.fromOffset(
        math.max(1, math.round(CLOSE_WIDTH * scale)),
        math.max(1, math.round(CLOSE_HEIGHT * scale))
    )

    label.TextScaled = false
    label.TextSize = math.max(
        10,
        math.round(CLOSE_TEXT_SIZE * scale)
    )

    return true
end

Workspace.DescendantAdded:Connect(function(descendant)
    if descendant.Name == BILLBOARD_NAME
        or descendant.Name == SKIP_BILLBOARD_NAME
        or descendant.Name == PAD_FOLDER_NAME
        or descendant.Name == STAGE_DECOR_FOLDER_NAME
    then
        task.defer(refreshTracked)
    end
end)

Workspace.DescendantRemoving:Connect(function(descendant)
    if descendant.Name == BILLBOARD_NAME
        or descendant.Name == SKIP_BILLBOARD_NAME
        or descendant.Name == PAD_FOLDER_NAME
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

    if needsRefresh then
        refreshTracked()
    end
end)
