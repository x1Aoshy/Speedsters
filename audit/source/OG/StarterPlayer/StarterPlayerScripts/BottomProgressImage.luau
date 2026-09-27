local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local LevelProgressUpdate = Remotes:WaitForChild("LevelProgressUpdate")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local StudUi = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("StudUi"))

local SUFFIXES = {
    "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc", "Ud", "Dd", "Td", "Qad", "Qid", "Sxd", "Spd", "Ocd", "Nod", "Vg"
}

local function formatNumber(value)
    value = tonumber(value) or 0
    if value < 1000 then
        return tostring(math.floor(value))
    end

    local tier = math.floor(math.log10(value) / 3) + 1
    if tier <= #SUFFIXES then
        local scaled = value / (1000 ^ (tier - 1))
        if scaled >= 100 then
            return string.format("%.0f%s", scaled, SUFFIXES[tier])
        else
            return string.format("%.2f%s", scaled, SUFFIXES[tier])
        end
    end

    return string.format("%.2e", value)
end

local function addStroke(object, thickness)
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(0, 0, 0)
    stroke.Thickness = thickness or 3
    stroke.LineJoinMode = Enum.LineJoinMode.Round
    stroke.Parent = object
    return stroke
end

local function addCorner(object, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius)
    corner.Parent = object
    return corner
end

local function destroyOldBars()
    for _, gui in ipairs(playerGui:GetChildren()) do
        if gui.Name == "LevelProgressBar" or gui.Name == "BottomProgressImage" then
            gui:Destroy()
        end
    end
end

destroyOldBars()

playerGui.ChildAdded:Connect(function(child)
    if child.Name == "LevelProgressBar" then
        task.defer(function()
            if child and child.Parent then
                child:Destroy()
            end
        end)
    end
end)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BottomProgressImage"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 40
screenGui.Parent = playerGui

                                                                             
                                                                               
                                                                             
local world1SpeedGainImpact = nil
if Config.IsWorld2Place ~= true then
    world1SpeedGainImpact = Instance.new("BindableEvent")
    world1SpeedGainImpact.Name = "World1SpeedGainImpact"
    world1SpeedGainImpact.Parent = screenGui
end

local scale = Instance.new("UIScale")
scale.Parent = screenGui

local holder = Instance.new("Frame")
holder.Name = "ProgressBarHolder"
holder.BackgroundTransparency = 1
holder.AnchorPoint = Vector2.new(0.5, 1)
holder.Position = UDim2.new(0.5, 0, 1, -164)
holder.Size = UDim2.fromOffset(1164, 74)
holder.Parent = screenGui

local mobileHolderScale = Instance.new("UIScale")
mobileHolderScale.Name = "MobileHolderScale"
mobileHolderScale.Scale = 1
mobileHolderScale.Parent = holder

                                                                           
local outer = Instance.new("Frame")
outer.Name = "OuterBar"
outer.BackgroundTransparency = 1
outer.BorderSizePixel = 0
outer.Size = UDim2.fromScale(1, 1)
outer.Parent = holder
addCorner(outer, 10)

local outerStroke = Instance.new("UIStroke")
outerStroke.Color = Color3.fromRGB(0, 0, 0)
outerStroke.Thickness = 2
outerStroke.LineJoinMode = Enum.LineJoinMode.Round
outerStroke.Parent = outer

local inner = Instance.new("Frame")
inner.Name = "InnerBar"
inner.BackgroundColor3 = Color3.fromRGB(8, 8, 8)
inner.BackgroundTransparency = 0.32
inner.BorderSizePixel = 0
inner.Position = UDim2.new(0, 0, 0, 0)
inner.Size = UDim2.new(1, 0, 1, 0)
inner.Parent = outer
addCorner(inner, 10)

local innerGradient = Instance.new("UIGradient")
innerGradient.Rotation = 0
innerGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(22, 22, 22)),
    ColorSequenceKeypoint.new(0.45, Color3.fromRGB(8, 8, 8)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(18, 18, 18)),
})
innerGradient.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0.12),
    NumberSequenceKeypoint.new(0.5, 0.22),
    NumberSequenceKeypoint.new(1, 0.14),
})
innerGradient.Parent = inner
StudUi.AddSurface(inner, 1, 10)

local glassHighlight = Instance.new("Frame")
glassHighlight.Name = "GlassHighlight"
glassHighlight.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
glassHighlight.BackgroundTransparency = 0.82
glassHighlight.BorderSizePixel = 0
glassHighlight.Position = UDim2.new(0.015, 0, 0.08, 0)
glassHighlight.Size = UDim2.new(0.97, 0, 0.24, 0)
glassHighlight.ZIndex = 1
glassHighlight.Parent = inner
addCorner(glassHighlight, 8)

local glassGradient = Instance.new("UIGradient")
glassGradient.Rotation = 90
glassGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(215, 245, 250)),
})
glassGradient.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0.28),
    NumberSequenceKeypoint.new(0.55, 0.86),
    NumberSequenceKeypoint.new(1, 1),
})
glassGradient.Parent = glassHighlight

local fillClip = Instance.new("Frame")
fillClip.Name = "BlueFillClip"
fillClip.BackgroundTransparency = 1
fillClip.ClipsDescendants = true
fillClip.Position = UDim2.new(0, 1, 0, 1)
fillClip.Size = UDim2.new(1, -2, 1, -2)
fillClip.ZIndex = 2
fillClip.Parent = inner
addCorner(fillClip, 9)

local fill = Instance.new("Frame")
fill.Name = "BlueFill"
fill.BackgroundColor3 = Color3.fromRGB(0, 175, 255)
fill.BackgroundTransparency = 0
fill.BorderSizePixel = 0
fill.Size = UDim2.fromScale(0, 1)
fill.Parent = fillClip
addCorner(fill, 9)
fill.ZIndex = 2

local fillGradient = Instance.new("UIGradient")
fillGradient.Rotation = 90
fillGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(75, 230, 255)),
    ColorSequenceKeypoint.new(0.48, Color3.fromRGB(0, 175, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 90, 255)),
})
fillGradient.Parent = fill
local fillStudSurface = StudUi.AddSurface(fill, 2, 9)
local fillStudGradient = fillStudSurface:FindFirstChild("StudSurfaceGradient")
if fillStudGradient then
                                                                             
    fillStudGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(0.52, Color3.fromRGB(248, 255, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(232, 248, 255)),
    })
end

local levelWord = Instance.new("TextLabel")
levelWord.Name = "LevelWord"
levelWord.BackgroundTransparency = 1
levelWord.AnchorPoint = Vector2.new(0, 0.5)
levelWord.Position = UDim2.new(0, 26, 0.5, 0)
levelWord.Size = UDim2.fromOffset(142, 43)
levelWord.Font = Enum.Font.GothamBlack
levelWord.Text = "Level"
levelWord.TextColor3 = Color3.fromRGB(255, 255, 255)
levelWord.TextScaled = true
levelWord.TextXAlignment = Enum.TextXAlignment.Left
levelWord.ZIndex = 3
levelWord.Parent = inner
addStroke(levelWord, 2.7)

local levelText = Instance.new("TextLabel")
levelText.Name = "DynamicLevelText"
levelText.BackgroundTransparency = 1
levelText.AnchorPoint = Vector2.new(0, 0.5)
levelText.Position = UDim2.new(0, 170, 0.5, 0)
levelText.Size = UDim2.fromOffset(74, 43)
levelText.Font = Enum.Font.GothamBlack
levelText.Text = "1"
levelText.TextColor3 = Color3.fromRGB(255, 255, 255)
levelText.TextScaled = true
levelText.TextXAlignment = Enum.TextXAlignment.Left
levelText.ZIndex = 3
levelText.Parent = inner
addStroke(levelText, 2.7)

local speedText = Instance.new("TextLabel")
speedText.Name = "SpeedAmountText"
speedText.BackgroundTransparency = 1
speedText.AnchorPoint = Vector2.new(0.5, 1)
                                                        
speedText.Position = UDim2.new(0.5, 0, 0, -10)
speedText.Size = UDim2.fromOffset(468, 55)
speedText.Font = Enum.Font.GothamBlack
speedText.Text = "Speed: 1"
speedText.TextColor3 = Color3.fromRGB(255, 255, 255)
speedText.TextStrokeTransparency = 1
speedText.TextScaled = true
speedText.TextXAlignment = Enum.TextXAlignment.Center
speedText.TextYAlignment = Enum.TextYAlignment.Center
speedText.ZIndex = 5
speedText.Parent = holder

local speedStroke = addStroke(speedText, 2)
speedStroke.Color = Color3.fromRGB(0, 0, 0)

local progressText = Instance.new("TextLabel")
progressText.Name = "DynamicProgressText"
progressText.BackgroundTransparency = 1
progressText.AnchorPoint = Vector2.new(1, 0.5)
progressText.Position = UDim2.new(1, -22, 0.5, 0)
progressText.Size = UDim2.fromOffset(264, 46)
progressText.Font = Enum.Font.GothamBlack
progressText.Text = "0/10"
progressText.TextColor3 = Color3.fromRGB(255, 255, 255)
progressText.TextScaled = true
progressText.TextXAlignment = Enum.TextXAlignment.Right
progressText.ZIndex = 3
progressText.Parent = inner
addStroke(progressText, 2.7)

local function updateScale()
    local camera = workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
    local fit = math.min(viewport.X / 1920, viewport.Y / 1080)

    if UserInputService.TouchEnabled then
                                                                           
                                                                        
        local hudScale = math.clamp(fit * 0.72, 0.25, 0.62)
        scale.Scale = 1
        mobileHolderScale.Scale = hudScale
        local speedRowHeight = 89 * hudScale
        local staminaHeight = 53 * hudScale
        local levelBottomOffset = 3 + speedRowHeight + 3 + staminaHeight + 3
        holder.Position = UDim2.new(0.5, 0, 1, -levelBottomOffset)
    else
        mobileHolderScale.Scale = 1
        scale.Scale = math.clamp(viewport.X / 1920, 0.62, 0.82)
        holder.Position = UDim2.new(0.5, 0, 1, -164)
    end
end

updateScale()
if workspace.CurrentCamera then
    workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end

local function readSpeedAmount()
    local leaderstats = player:FindFirstChild("leaderstats")
    local speed = leaderstats and leaderstats:FindFirstChild("Speed")

    if speed and speed:IsA("ValueBase") then
        return tonumber(speed.Value) or 1
    end

    local dataFolder = player:FindFirstChild("SpeedsterData")
    local rawSpeed = dataFolder and dataFolder:FindFirstChild("RawSpeed")

    if rawSpeed and rawSpeed:IsA("ValueBase") then
        return tonumber(rawSpeed.Value) or 1
    end

    local attr = player:GetAttribute("RawSpeed")
    if typeof(attr) == "number" then
        return attr
    end

    return 1
end

local SPEED_TEXT_FALLBACK_SECONDS = 1.15
local speedUpdateSerial = 0
local lastCommittedSpeed = nil

local function cleanDisplaySpeed(value)
    value = tonumber(value)
    if value == nil or value ~= value or value == math.huge or value == -math.huge then
        return nil
    end
    return math.max(0, value)
end

local function commitSpeedText(explicitSpeed)
    local displaySpeed = cleanDisplaySpeed(explicitSpeed)
        or cleanDisplaySpeed(readSpeedAmount())
        or 1
    lastCommittedSpeed = displaySpeed
    speedText.Text = "Speed: " .. formatNumber(displaySpeed)
end

local function scheduleSpeedTextUpdate(forceInstant)
    local actualSpeed = cleanDisplaySpeed(readSpeedAmount()) or 1

                                                                           
                                                           
    if Config.IsWorld2Place == true
        or forceInstant == true
        or lastCommittedSpeed == nil
        or actualSpeed < lastCommittedSpeed
    then
        speedUpdateSerial += 1
        commitSpeedText(actualSpeed)
        return
    end

                                                                              
                                                                              
    speedUpdateSerial += 1
    local thisSerial = speedUpdateSerial
    task.delay(SPEED_TEXT_FALLBACK_SECONDS, function()
        if thisSerial == speedUpdateSerial then
            commitSpeedText()
        end
    end)
end

if world1SpeedGainImpact then
    world1SpeedGainImpact.Event:Connect(function(totalSpeed)
        local impactTotal = cleanDisplaySpeed(totalSpeed)
        if impactTotal == nil then
            return
        end

        local actualSpeed = cleanDisplaySpeed(readSpeedAmount()) or impactTotal
        local tolerance = math.max(0.001, math.abs(actualSpeed) * 1e-12)

                                                                             
                                                                      
        if impactTotal > actualSpeed + tolerance then
            return
        end
        if lastCommittedSpeed ~= nil
            and impactTotal < lastCommittedSpeed - tolerance
            and actualSpeed >= lastCommittedSpeed - tolerance
        then
            return
        end

        speedUpdateSerial += 1
        commitSpeedText(impactTotal)
    end)
end

local function hookSpeedValue(valueObject)
    if valueObject and valueObject:IsA("ValueBase") then
        valueObject:GetPropertyChangedSignal("Value"):Connect(scheduleSpeedTextUpdate)
        scheduleSpeedTextUpdate(lastCommittedSpeed == nil)
    end
end

local function hookSpeedSources()
    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then
        hookSpeedValue(leaderstats:FindFirstChild("Speed"))

        leaderstats.ChildAdded:Connect(function(child)
            if child.Name == "Speed" then
                hookSpeedValue(child)
            end
        end)
    end

    local dataFolder = player:FindFirstChild("SpeedsterData")
    if dataFolder then
        hookSpeedValue(dataFolder:FindFirstChild("RawSpeed"))

        dataFolder.ChildAdded:Connect(function(child)
            if child.Name == "RawSpeed" then
                hookSpeedValue(child)
            end
        end)
    end

    player:GetAttributeChangedSignal("RawSpeed"):Connect(scheduleSpeedTextUpdate)
end

player.ChildAdded:Connect(function(child)
    if child.Name == "leaderstats" or child.Name == "SpeedsterData" then
        task.defer(hookSpeedSources)
        task.defer(scheduleSpeedTextUpdate)
    end
end)

task.defer(function()
    hookSpeedSources()
    scheduleSpeedTextUpdate(true)
end)

local lastLevel = nil

local function applyData(data, instant)
    local level = tonumber(data.Level) or player:GetAttribute("Level") or 1
    local progress = tonumber(data.Progress) or player:GetAttribute("LevelProgress") or 0
    local required = tonumber(data.Required) or player:GetAttribute("LevelRequirement") or 10

    required = math.max(1, required)
    progress = math.clamp(progress, 0, required)

    local ratio = math.clamp(progress / required, 0, 1)

    levelText.Text = tostring(math.floor(level))
    progressText.Text = formatNumber(progress) .. "/" .. formatNumber(required)

                                                                          
                                           
    scheduleSpeedTextUpdate(instant == true)

    local tweenTime = instant and 0 or 0.18
    TweenService:Create(fill, TweenInfo.new(tweenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = UDim2.fromScale(ratio, 1),
    }):Play()

    if lastLevel and level > lastLevel then
        levelText.Size = UDim2.fromOffset(94, 54)
        TweenService:Create(levelText, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.fromOffset(86, 48),
        }):Play()
    end

    lastLevel = level
end

LevelProgressUpdate.OnClientEvent:Connect(function(data)
    if type(data) == "table" then
        applyData(data, false)
    end
end)

task.defer(function()
    task.wait(1)
    local needsInitialSync = lastLevel == nil
    applyData({
        Level = player:GetAttribute("Level") or 1,
        Progress = player:GetAttribute("LevelProgress") or 0,
        Required = player:GetAttribute("LevelRequirement") or 10,
    }, needsInitialSync)
end)

task.spawn(function()
    for _ = 1, 30 do
        task.wait(0.2)
        for _, gui in ipairs(playerGui:GetChildren()) do
            if gui.Name == "LevelProgressBar" then
                gui:Destroy()
            end
        end
    end
end)

if Config.IsWorld2Place then
    print("[BottomProgressImage] V306BF loaded. Level bar is 1.2x V306AX size with V306AX position/scaling preserved.")
else
    print("[BottomProgressImage] V306KAQ loaded. World 1 Speed text commits on exact popup impact with a safe no-popup fallback; Level bar layout is unchanged.")
end
