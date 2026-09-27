local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local MarketplaceService = game:GetService("MarketplaceService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local MenuEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MenuEvents"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RebirthRequest = Remotes:WaitForChild("RebirthRequest")
local RebirthUpdate = Remotes:WaitForChild("RebirthUpdate")

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

local REBIRTH_SOUND_ID = "rbxassetid://127039883737564"
local rebirthSound = Instance.new("Sound")
rebirthSound.Name = "RebirthSuccessSound"
rebirthSound.SoundId = REBIRTH_SOUND_ID
rebirthSound.Volume = 0.85
rebirthSound.Parent = SoundService

local gui = playerGui:WaitForChild("Rebirth")
local frame = gui:WaitForChild("Rebirth")
local closeButton = frame:WaitForChild("Close")
local beforeLabel = frame:WaitForChild("Before")
local afterLabel = frame:WaitForChild("After")
local nameLabel = frame:WaitForChild("Name")
local rebirthButton = frame:WaitForChild("Rebirth")
local rebirthBuy = frame:WaitForChild("RebirthBuy")
local progressFrame = frame:WaitForChild("ProgressFrame")
local beforeSpeed = frame:WaitForChild("BeforeSpeed")
local afterSpeed = frame:WaitForChild("AfterSpeed")
local beforeMax = frame:WaitForChild("BeforeMax")
local afterMax = frame:WaitForChild("AfterMax")

-- Keep the Studio-authored label geometry intact.
local function formatMultiplier(value)
    value = tonumber(value) or 1
    if value >= 1000000 then return string.format("%.2e", value)
    elseif value >= 100 then return string.format("%.0f", value)
    elseif value >= 10 then return string.format("%.1f", value):gsub("0+$", ""):gsub("%.$", "")
    end
    return string.format("%.2f", value):gsub("0+$", ""):gsub("%.$", "")
end

local currentData = {
    Rebirths = player:GetAttribute("Rebirths") or 0,
    CurrentLevel = player:GetAttribute("Level") or 1,
    RequiredLevel = player:GetAttribute("NextRebirthLevelRequired") or 5,
    CurrentMultiplier = player:GetAttribute("RebirthMultiplier") or 1,
    NextMultiplier = 1.5,
    CanRebirth = false,
}
local lastKnownRebirthsForSound = tonumber(currentData.Rebirths) or 0
local pendingRebirthSound = false
local isOpen = false

local function getAuthoritativeLevel()
    local attr = tonumber(player:GetAttribute("Level"))
    if attr and attr > 0 then return attr end
    local sf = player:FindFirstChild("SpeedsterData")
    local lv = sf and sf:FindFirstChild("Level")
    if lv and lv:IsA("ValueBase") and tonumber(lv.Value) and tonumber(lv.Value) > 0 then
        return tonumber(lv.Value)
    end
    return tonumber(currentData.CurrentLevel) or 1
end

local function getAuthoritativeRequired()
    local attr = tonumber(player:GetAttribute("NextRebirthLevelRequired"))
        or tonumber(player:GetAttribute("NextRebirthSpeedRequired"))
    if attr and attr > 0 then return attr end
    return tonumber(currentData.RequiredLevel) or 5
end

local function getAuthoritativeRebirths()
    local attr = tonumber(player:GetAttribute("Rebirths"))
    if attr and attr >= 0 then return attr end
    local ls = player:FindFirstChild("leaderstats")
    local rb = ls and ls:FindFirstChild("Rebirths")
    if rb and rb:IsA("ValueBase") and tonumber(rb.Value) and tonumber(rb.Value) >= 0 then
        return tonumber(rb.Value)
    end
    return tonumber(currentData.Rebirths) or 0
end

local updateProgress = require(ReplicatedStorage.Shared.ProgressBar).Bind(progressFrame)

local function applyData(data)
    if type(data) ~= "table" then data = {} end
    for key, value in pairs(data) do currentData[key] = value end

    local rebirths = tonumber(data.Rebirths) or getAuthoritativeRebirths()
    local level = tonumber(data.CurrentLevel) or getAuthoritativeLevel()
    local required = tonumber(data.RequiredLevel) or getAuthoritativeRequired()
    local curMult = tonumber(data.CurrentMultiplier)
        or tonumber(player:GetAttribute("RebirthMultiplier"))
        or tonumber(currentData.CurrentMultiplier)
        or (1.5 ^ rebirths)
    local nextMult = tonumber(data.NextMultiplier)
        or tonumber(currentData.NextMultiplier)
        or (1.5 ^ (rebirths + 1))

    currentData.Rebirths = rebirths
    currentData.CurrentLevel = level
    currentData.RequiredLevel = required
    currentData.CurrentMultiplier = curMult
    currentData.NextMultiplier = nextMult

    required = math.max(1, required)
    local ratio = math.clamp(level / required, 0, 1)

    beforeLabel.Text = "Rebirth " .. tostring(math.floor(rebirths))
    afterLabel.Text = "Rebirth " .. tostring(math.floor(rebirths + 1))
    nameLabel.Text = "x" .. formatMultiplier(curMult) .. " Speed -> x" .. formatMultiplier(nextMult) .. " Speed"

    local bs = beforeSpeed:FindFirstChildOfClass("TextLabel")
    local af = afterSpeed:FindFirstChildOfClass("TextLabel")
    if bs then bs.Text = "x" .. formatMultiplier(curMult) end
    if af then af.Text = "x" .. formatMultiplier(nextMult) end

    local bl = beforeMax:FindFirstChildOfClass("TextLabel")
    local al = afterMax:FindFirstChildOfClass("TextLabel")
    if bl then bl.Text = "Level " .. tostring(math.floor(level)) end
    if al then al.Text = "Level " .. tostring(math.floor(required)) end

    updateProgress(ratio, tostring(math.floor(level)) .. " / " .. tostring(math.floor(required)))

    local canRebirth = data.CanRebirth
    if canRebirth == nil then canRebirth = level >= required end
    currentData.CanRebirth = canRebirth
    if canRebirth then
        rebirthButton.BackgroundColor3 = Color3.fromRGB(225, 45, 255)
        rebirthButton.AutoButtonColor = true
    else
        rebirthButton.BackgroundColor3 = Color3.fromRGB(115, 115, 125)
        rebirthButton.AutoButtonColor = false
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

    applyData()
    RebirthRequest:FireServer("Sync")
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

--------------------------------------------------------------------------------
-- REBIRTH JUICE ANIMATIONS (Boton X, Icono Rebirth & Giro Continuo de RebirthPipe.Icon)
--------------------------------------------------------------------------------

local CLOSE_HOVER_IN = TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local CLOSE_HOVER_OUT = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local CLOSE_PRESS = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function attachCloseAnimation(button: GuiButton)
    if not button or not button:IsA("GuiButton") then return end
    if button:GetAttribute("CloseAnimAttached") == true then return end
    button:SetAttribute("CloseAnimAttached", true)

    local scale = button:FindFirstChild("CloseButtonScale")
    if not scale or not scale:IsA("UIScale") then
        scale = Instance.new("UIScale")
        scale.Name = "CloseButtonScale"
        scale.Scale = 1.0
        scale.Parent = button
    end

    local isHovered = false

    local function onHoverIn()
        isHovered = true
        TweenService:Create(scale, CLOSE_HOVER_IN, { Scale = 1.15 }):Play()
        TweenService:Create(button, CLOSE_HOVER_IN, { Rotation = -8 }):Play()
    end

    local function onHoverOut()
        isHovered = false
        TweenService:Create(scale, CLOSE_HOVER_OUT, { Scale = 1.0 }):Play()
        TweenService:Create(button, CLOSE_HOVER_OUT, { Rotation = 0 }):Play()
    end

    local function onPressDown()
        TweenService:Create(scale, CLOSE_PRESS, { Scale = 0.88 }):Play()
        TweenService:Create(button, CLOSE_PRESS, { Rotation = -4 }):Play()
    end

    local function onPressUp()
        if isHovered then
            onHoverIn()
        else
            onHoverOut()
        end
    end

    button.MouseEnter:Connect(onHoverIn)
    button.MouseLeave:Connect(onHoverOut)
    button.MouseButton1Down:Connect(onPressDown)
    button.MouseButton1Up:Connect(onPressUp)
    button.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            onPressDown()
        end
    end)
    button.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            onHoverOut()
        end
    end)
    button.SelectionGained:Connect(onHoverIn)
    button.SelectionLost:Connect(onHoverOut)
end

local function attachHeaderIconAnimation(icon: ImageLabel)
    if not icon or not icon:IsA("ImageLabel") then return end
    if icon:GetAttribute("HeaderAnimAttached") == true then return end
    icon:SetAttribute("HeaderAnimAttached", true)

    task.spawn(function()
        task.wait(math.random(2, 4))
        while icon.Parent do
            task.wait(math.random(35, 65) / 10)
            if gui and not gui.Enabled then continue end
            if not icon.Visible then continue end

            local curRot = icon.Rotation
            local t1 = TweenService:Create(icon, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Rotation = curRot + 90 })
            t1:Play()
            t1.Completed:Wait()

            task.wait(0.35)

            local t2 = TweenService:Create(icon, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Rotation = curRot + 180 })
            t2:Play()
            t2.Completed:Wait()

            icon.Rotation = (curRot + 180) % 360
        end
    end)
end

-- Giro continuo para el Icon dentro de RebirthPipe (gira siempre, no se para)
local function attachContinuousRotation(icon: GuiObject, speedDegreesPerSec: number?)
    if not icon or not icon:IsA("GuiObject") then return end
    if icon:GetAttribute("ContinuousSpinAttached") == true then return end
    icon:SetAttribute("ContinuousSpinAttached", true)

    local speed = speedDegreesPerSec or 100
    local connection
    connection = RunService.RenderStepped:Connect(function(dt)
        if not icon or not icon.Parent then
            if connection then
                connection:Disconnect()
                connection = nil
            end
            return
        end
        icon.Rotation = (icon.Rotation + speed * dt) % 360
    end)
end

local function hookRebirthPipe(pipe: GuiObject)
    if not pipe or not pipe:IsA("GuiObject") then return end
    if pipe:GetAttribute("RebirthPipeJuiceAttached") == true then return end
    pipe:SetAttribute("RebirthPipeJuiceAttached", true)

    -- Interacción elástica del botón RebirthPipe
    if pipe:IsA("GuiButton") then
        local scale = pipe:FindFirstChild("PipeScale")
        if not scale or not scale:IsA("UIScale") then
            scale = Instance.new("UIScale")
            scale.Name = "PipeScale"
            scale.Scale = 1.0
            scale.Parent = pipe
        end

        local hoverIn = TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        local hoverOut = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

        pipe.MouseEnter:Connect(function()
            TweenService:Create(scale, hoverIn, { Scale = 1.08 }):Play()
        end)
        pipe.MouseLeave:Connect(function()
            TweenService:Create(scale, hoverOut, { Scale = 1.0 }):Play()
        end)
        pipe.MouseButton1Down:Connect(function()
            TweenService:Create(scale, hoverOut, { Scale = 0.92 }):Play()
        end)
        pipe.MouseButton1Up:Connect(function()
            TweenService:Create(scale, hoverIn, { Scale = 1.08 }):Play()
        end)
        pipe.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch then
                TweenService:Create(scale, hoverOut, { Scale = 0.92 }):Play()
            end
        end)
        pipe.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch then
                TweenService:Create(scale, hoverOut, { Scale = 1.0 }):Play()
            end
        end)
    end

    -- Conectar el Icon hijo para giro continuo ininterrumpido
    local function checkPipeChild(child: Instance)
        if child:IsA("GuiObject") and (child.Name == "Icon" or child:IsA("ImageLabel")) then
            attachContinuousRotation(child, 100)
        end
    end

    for _, c in ipairs(pipe:GetChildren()) do
        checkPipeChild(c)
    end
    pipe.ChildAdded:Connect(checkPipeChild)
end

local function scanAndHookJuice(container: Instance)
    if not container then return end

    local function inspect(inst: Instance)
        if inst:IsA("GuiButton") and (inst.Name == "Close" or inst.Name:lower():find("close")) then
            attachCloseAnimation(inst)
        elseif inst.Name == "RebirthPipe" and inst:IsA("GuiObject") then
            hookRebirthPipe(inst)
        elseif inst.Parent and inst.Parent.Name == "RebirthPipe" and inst:IsA("GuiObject") and (inst.Name == "Icon" or inst:IsA("ImageLabel")) then
            attachContinuousRotation(inst, 100)
        elseif inst:IsA("ImageLabel") and (inst.Name == "Icon" or inst.Name == "Rebirth") and inst.Parent and inst.Parent.Name ~= "RebirthPipe" then
            if inst:IsDescendantOf(gui) then
                attachHeaderIconAnimation(inst)
            end
        end
    end

    for _, desc in ipairs(container:GetDescendants()) do
        inspect(desc)
    end
    container.DescendantAdded:Connect(inspect)
end

-- Inicialización de animaciones de UI
attachCloseAnimation(closeButton)
local headerIcon = frame:FindFirstChild("Icon")
if headerIcon and headerIcon:IsA("ImageLabel") then
    attachHeaderIconAnimation(headerIcon)
end

scanAndHookJuice(gui)
scanAndHookJuice(playerGui)

if dimOverlay and dimOverlay:IsA("GuiObject") then
    dimOverlay.Active = true
    dimOverlay.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            closePanel()
        end
    end)
end

local isRebirthProcessing = false

local function onRebirthClicked()
    if isRebirthProcessing then return end
    local level = getAuthoritativeLevel()
    local required = getAuthoritativeRequired()
    if level < required then
        pendingRebirthSound = false
        playRequirementFailSound()
        return
    end
    isRebirthProcessing = true
    pendingRebirthSound = true
    task.delay(1.5, function() isRebirthProcessing = false end)
    task.delay(6, function() pendingRebirthSound = false end)
    RebirthRequest:FireServer("Rebirth")
end

rebirthButton.Activated:Connect(onRebirthClicked)
if rebirthButton:IsA("GuiButton") then
    rebirthButton.MouseButton1Click:Connect(onRebirthClicked)
end

local function onRebirthBuyClicked()
    local prodId = tonumber(Config.RebirthProductId)
    local passId = tonumber(Config.RebirthGamePassId)
    if prodId and prodId > 0 then
        MarketplaceService:PromptProductPurchase(player, prodId)
    elseif passId and passId > 0 then
        MarketplaceService:PromptGamePassPurchase(player, passId)
    else
        warn("[RebirthController] Rebirth GamePass/Product ID is not configured in Config.luau")
        playRequirementFailSound()
    end
end

rebirthBuy.Activated:Connect(onRebirthBuyClicked)
if rebirthBuy:IsA("GuiButton") then
    rebirthBuy.MouseButton1Click:Connect(onRebirthBuyClicked)
end

local priceLabel = rebirthBuy:FindFirstChild("Price")
if not priceLabel then
	for _, child in ipairs(rebirthBuy:GetDescendants()) do
		if child:IsA("TextLabel") and (child.Name == "Price" or child.Name == "Name") then
			priceLabel = child
			break
		end
	end
end

if priceLabel and priceLabel:IsA("TextLabel") and Config.RebirthPriceRobux then
	priceLabel.Text = tostring(Config.RebirthPriceRobux)
end

task.spawn(function()
	local prodId = tonumber(Config.RebirthProductId)
	local passId = tonumber(Config.RebirthGamePassId)
	local targetId = (prodId and prodId > 0) and prodId or passId
	local infoType = (prodId and prodId > 0) and Enum.InfoType.Product or Enum.InfoType.GamePass

	if targetId and targetId > 0 then
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(targetId, infoType)
		end)
		if ok and type(info) == "table" and info.PriceInRobux then
			if priceLabel and priceLabel:IsA("TextLabel") then
				priceLabel.Text = tostring(info.PriceInRobux)
			end
			for _, label in ipairs(rebirthBuy:GetDescendants()) do
				if label:IsA("TextLabel") and (label.Name == "Price" or label.Name == "Name") then
					label.Text = tostring(info.PriceInRobux)
				end
			end
		end
	end
end)

RebirthUpdate.OnClientEvent:Connect(function(data)
    if type(data) == "table" then
        local oldRebirths = tonumber(currentData.Rebirths) or lastKnownRebirthsForSound or 0
        local newRebirths = tonumber(data.Rebirths) or oldRebirths
        if pendingRebirthSound and newRebirths > oldRebirths then
            rebirthSound.TimePosition = 0
            rebirthSound:Play()
            pendingRebirthSound = false
        end
        lastKnownRebirthsForSound = newRebirths
    end
    applyData(data)
end)

local openRebirthPanel = MenuEvents.Get("OpenRebirthPanel")
openRebirthPanel.Event:Connect(function(action)
    if action == "Open" or action == "LeftButtonSwitch" then
        openPanel()
    elseif action == "Close" then
        closePanel(true)
    else
        if isOpen then closePanel() else openPanel() end
    end
end)
MenuEvents.CloseAll.Event:Connect(function(exceptMenuName)
    if exceptMenuName == "Rebirth" then return end
    closePanel(true)
end)
MenuEvents.MarkReady("Rebirth", function() return isOpen end)
closePanel(true)

local function onStatChanged()
    applyData()
    if isOpen then
        RebirthRequest:FireServer("Sync")
    end
end

player:GetAttributeChangedSignal("Level"):Connect(onStatChanged)
player:GetAttributeChangedSignal("Rebirths"):Connect(onStatChanged)
player:GetAttributeChangedSignal("NextRebirthLevelRequired"):Connect(onStatChanged)
player:GetAttributeChangedSignal("NextRebirthSpeedRequired"):Connect(onStatChanged)
player:GetAttributeChangedSignal("RebirthMultiplier"):Connect(onStatChanged)

local function hookPlayerInstances()
    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then
        local rb = leaderstats:FindFirstChild("Rebirths")
        if rb and rb:IsA("ValueBase") then
            rb:GetPropertyChangedSignal("Value"):Connect(onStatChanged)
        end
    end
    local dataFolder = player:FindFirstChild("SpeedsterData")
    if dataFolder then
        local lv = dataFolder:FindFirstChild("Level")
        if lv and lv:IsA("ValueBase") then
            lv:GetPropertyChangedSignal("Value"):Connect(onStatChanged)
        end
    end
end

player.ChildAdded:Connect(function(child)
    if child.Name == "leaderstats" or child.Name == "SpeedsterData" then
        task.defer(hookPlayerInstances)
        task.defer(onStatChanged)
    end
end)
task.defer(hookPlayerInstances)

task.defer(function()
    task.wait(1)
    applyData()
    RebirthRequest:FireServer("Sync")
end)

print("[RebirthController] Loaded")
require(ReplicatedStorage.Shared.ConsolePanelSupport).Bind(gui, frame, rebirthButton, closeButton, function() closePanel(true) end)
