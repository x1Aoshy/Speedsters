local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local MarketplaceService = game:GetService("MarketplaceService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local StudUi = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("StudUi"))
local TreadmillLocked = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("TreadmillLocked")

local PANEL_SIZE = Vector2.new(650, 315)
local GOLD = Color3.fromRGB(255, 196, 20)
local BLUE = Color3.fromRGB(30, 185, 255)
local PINK = Color3.fromRGB(255, 55, 190)
local RED = Color3.fromRGB(255, 75, 75)
local DARK = Color3.fromRGB(0, 0, 0)

local function addCorner(instance, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 12)
	corner.Parent = instance
	return corner
end

local function addStroke(instance, thickness, color)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or DARK
	stroke.Thickness = thickness or 4
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = instance
	return stroke
end

local oldGui = playerGui:FindFirstChild("TreadmillLockPanelGui")
if oldGui then
	oldGui:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "TreadmillLockPanelGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 96
gui.Enabled = false
gui.Parent = playerGui

local dim = Instance.new("Frame")
dim.Name = "Dim"
dim.BackgroundColor3 = DARK
dim.BackgroundTransparency = 1
dim.BorderSizePixel = 0
dim.Size = UDim2.fromScale(1, 1)
dim.ZIndex = 40
dim.Parent = gui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(PANEL_SIZE.X, PANEL_SIZE.Y)
panel.BackgroundColor3 = Color3.fromRGB(250, 250, 250)
panel.BorderSizePixel = 0
panel.ZIndex = 41
panel.Parent = gui
panel.ClipsDescendants = true
addCorner(panel, 14)
addStroke(panel, 5, DARK)
StudUi.AddSurface(panel, panel.ZIndex + 1, 14)

local responsiveScale = Instance.new("UIScale")
responsiveScale.Name = "ResponsiveScale"
responsiveScale.Scale = 1
responsiveScale.Parent = panel

local popupScale = Instance.new("UIScale")
popupScale.Name = "PopupScale"
popupScale.Scale = 0.86
popupScale.Parent = panel

local function updateResponsiveScale()
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
	local inset = GuiService:GetGuiInset()
	local horizontalMargin = UserInputService.TouchEnabled and 24 or 50
	local verticalMargin = UserInputService.TouchEnabled and 20 or 44
	local availableWidth = math.max(1, viewport.X - horizontalMargin)
	local availableHeight = math.max(1, viewport.Y - inset.Y - verticalMargin)
	local fit = math.min(availableWidth / PANEL_SIZE.X, availableHeight / PANEL_SIZE.Y)
	responsiveScale.Scale = math.clamp(fit, 0.48, 1.06)
end

updateResponsiveScale()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveScale)
end

local header = Instance.new("Frame")
header.Name = "Header"
header.BackgroundColor3 = GOLD
header.BorderSizePixel = 0
header.Position = UDim2.fromOffset(0, 0)
header.Size = UDim2.new(1, 0, 0, 90)
header.ZIndex = 42
header.Parent = panel
header.ClipsDescendants = true
addCorner(header, 14)
addStroke(header, 5, DARK)
StudUi.AddSurface(header, header.ZIndex + 1, 14)

local title = Instance.new("TextLabel")
title.Name = "Title"
title.BackgroundTransparency = 1
title.Position = UDim2.new(0, 24, 0, 0)
title.Size = UDim2.new(1, -116, 1, 0)
title.Font = Enum.Font.FredokaOne
title.Text = "Treadmill Locked!"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextStrokeColor3 = DARK
title.TextStrokeTransparency = 0
title.TextSize = 44
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextYAlignment = Enum.TextYAlignment.Center
title.ZIndex = 48
title.Parent = header

local close = Instance.new("TextButton")
close.Name = "Close"
close.AnchorPoint = Vector2.new(0.5, 0.5)
close.Position = UDim2.new(1, -43, 0.5, 0)
close.Size = UDim2.fromOffset(60, 60)
close.BackgroundColor3 = RED
close.BorderSizePixel = 0
close.Font = Enum.Font.GothamBlack
close.Text = "X"
close.TextColor3 = Color3.fromRGB(255, 255, 255)
close.TextSize = 34
close.ZIndex = 49
close.Parent = header
addCorner(close, 10)
addStroke(close, 4, DARK)
StudUi.StyleButton(close, 10)

local message = Instance.new("TextLabel")
message.Name = "Message"
message.BackgroundTransparency = 1
message.Position = UDim2.new(0, 38, 0, 116)
message.Size = UDim2.new(1, -76, 0, 92)
message.Font = Enum.Font.FredokaOne
message.Text = "Reach 1 Rebirth to unlock this treadmill!"
message.TextColor3 = Color3.fromRGB(55, 55, 65)
message.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)
message.TextStrokeTransparency = 0.45
message.TextSize = 34
message.TextWrapped = true
message.TextXAlignment = Enum.TextXAlignment.Center
message.TextYAlignment = Enum.TextYAlignment.Center
message.ZIndex = 47
message.Parent = panel

local okay = Instance.new("TextButton")
okay.Name = "Okay"
okay.AnchorPoint = Vector2.new(0.5, 0.5)
okay.Position = UDim2.new(0.5, 0, 1, -55)
okay.Size = UDim2.fromOffset(250, 66)
okay.BackgroundColor3 = GOLD
okay.BorderSizePixel = 0
okay.Font = Enum.Font.GothamBlack
okay.Text = "Okay"
okay.TextColor3 = Color3.fromRGB(255, 255, 255)
okay.TextSize = 32
okay.ZIndex = 48
okay.Parent = panel
addCorner(okay, 10)
addStroke(okay, 4, DARK)
StudUi.StyleButton(okay, 10)

local activeTween = nil
local dimTween = nil
local isOpen = false
local purchasePromptOpen = false
local lastPromptedPassId = nil

local function stopTween(tween)
	if tween then
		tween:Cancel()
	end
end

local function closePanel()
	if not isOpen then
		return
	end
	isOpen = false
	stopTween(activeTween)
	stopTween(dimTween)

	activeTween = TweenService:Create(popupScale, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Scale = 0.86,
	})
	dimTween = TweenService:Create(dim, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		BackgroundTransparency = 1,
	})
	activeTween:Play()
	dimTween:Play()
	activeTween.Completed:Once(function()
		if not isOpen then
			gui.Enabled = false
		end
	end)
end

local function openPanel(requiredRebirths, treadmillName)
	requiredRebirths = math.max(1, math.floor(tonumber(requiredRebirths) or 1))
	local noun = requiredRebirths == 1 and "Rebirth" or "Rebirths"
	message.Text = string.format("Reach %d %s to unlock this treadmill!", requiredRebirths, noun)

	local accent = GOLD
	if treadmillName == "Treadmill3_superfast"
		or treadmillName == "TreadmillDiamond"
		or treadmillName == "Diamond"
	then
		accent = BLUE
	elseif treadmillName == "TreadmillCandy" or treadmillName == "Candy" then
		accent = PINK
	end
	header.BackgroundColor3 = accent
	okay.BackgroundColor3 = accent

	stopTween(activeTween)
	stopTween(dimTween)
	gui.Enabled = true
	isOpen = true
	popupScale.Scale = 0.86
	dim.BackgroundTransparency = 1

	activeTween = TweenService:Create(popupScale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	})
	dimTween = TweenService:Create(dim, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.48,
	})
	activeTween:Play()
	dimTween:Play()
end

close.Activated:Connect(closePanel)
okay.Activated:Connect(closePanel)

local function promptGamePass(gamePassId)
	gamePassId = math.floor(tonumber(gamePassId) or 0)
	if gamePassId <= 0 or purchasePromptOpen then
		return
	end

	closePanel()
	purchasePromptOpen = true
	lastPromptedPassId = gamePassId

	local success, err = pcall(function()
		MarketplaceService:PromptGamePassPurchase(player, gamePassId)
	end)

	if not success then
		warn("[TreadmillLockPanel] Could not open Pass purchase prompt: " .. tostring(err))
		purchasePromptOpen = false
		lastPromptedPassId = nil
		return
	end

	                                                                            
	                                                                         
	task.delay(12, function()
		if purchasePromptOpen and lastPromptedPassId == gamePassId then
			purchasePromptOpen = false
			lastPromptedPassId = nil
		end
	end)
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(finishedPlayer, gamePassId)
	if finishedPlayer ~= player then
		return
	end
	if lastPromptedPassId == gamePassId then
		purchasePromptOpen = false
		lastPromptedPassId = nil
	end
end)

TreadmillLocked.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then
		return
	end

	if payload.LockType == "GamePass" then
		promptGamePass(payload.GamePassId)
		return
	end

	openPanel(payload.RequiredRebirths, payload.TreadmillName)
end)

print("[TreadmillLockPanel] V306Z loaded. Gold/blue use the stud rebirth panel; pink and red/Admin treadmills open Roblox's native Pass purchase page for their assigned Pass IDs.")
