local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local MarketplaceService = game:GetService("MarketplaceService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local MenuEvents = require(Shared:WaitForChild("MenuEvents"))
local StudUi = require(Shared:WaitForChild("StudUi"))
local TreadmillLocked = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("TreadmillLocked")

local MenuPanelLayout = require(Shared:WaitForChild("MenuPanelLayout"))

local PANEL_SIZE = MenuPanelLayout.ModalSizes.Treadmill or Vector2.new(650, 315)
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

local gui = playerGui:WaitForChild("Treadmill")
gui.Enabled = false

local dim = gui:FindFirstChild("Dim")
if not dim or not dim:IsA("GuiObject") then
	if dim then dim:Destroy() end
	local newDim = Instance.new("Frame")
	newDim.Name = "Dim"
	newDim.Parent = gui
	dim = newDim
end
dim.BackgroundColor3 = DARK
dim.BackgroundTransparency = 1
dim.BorderSizePixel = 0
dim.Size = UDim2.fromScale(1, 1)
dim.ZIndex = 40
dim.Active = false
dim.Visible = false

local OPEN_POS = UDim2.new(0.5, 0, 0.48, 0)
local CLOSED_POS = UDim2.new(0.5, 0, 1.28, 0)

local panel = gui:FindFirstChild("TimeGift") or gui:FindFirstChild("Frame") or gui:WaitForChild("TimeGift", 5)
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = CLOSED_POS

-- Remove any UIScale so it matches Shop size exactly
for _, child in ipairs(panel:GetChildren()) do
	if child:IsA("UIScale") then
		child:Destroy()
	end
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

local title = panel.Title
local close = panel.Close
local message = panel:WaitForChild("Name")
message.Text = "Reach 1 Rebirth to unlock this treadmill!"

local okay = panel.Reddem
local isOpen = false
local lastPromptTime = 0
local PROMPT_COOLDOWN = 1.5

local Config = require(Shared:WaitForChild("Config"))

local openTween, dimTween

local function closePanel()
	if not isOpen and not gui.Enabled then
		return
	end
	isOpen = false
	if openTween then openTween:Cancel() end
	if dimTween then dimTween:Cancel() end
	dimTween = TweenService:Create(dim, TweenInfo.new(0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.In), { BackgroundTransparency = 1 })
	dimTween:Play()
	openTween = TweenService:Create(panel, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = CLOSED_POS })
	openTween:Play()
	task.delay(0.18, function()
		if not isOpen then
			gui.Enabled = false
			panel.Visible = false
			dim.Visible = false
		end
	end)
end

local function promptGamePass(gamePassId)
	gamePassId = math.floor(tonumber(gamePassId) or 0)
	if gamePassId <= 0 then
		return
	end
	local now = os.clock()
	if now - lastPromptTime < PROMPT_COOLDOWN then
		return
	end
	lastPromptTime = now

	closePanel()
	local success, err = pcall(function()
		MarketplaceService:PromptGamePassPurchase(player, gamePassId)
	end)

	if not success then
		warn("[TreadmillLockPanel] Could not open Pass purchase prompt: " .. tostring(err))
	end
end

local function openPanel(requiredRebirths, treadmillName)
	if isOpen then
		closePanel()
	end
	MenuEvents.CloseAll:Fire("Treadmill")

	requiredRebirths = math.max(1, math.floor(tonumber(requiredRebirths) or 1))
	local noun = requiredRebirths == 1 and "Rebirth" or "Rebirths"
	message.Text = string.format("Reach %d %s to unlock this treadmill!", requiredRebirths, noun)

	local okayText = okay:FindFirstChild("Name")
	if okayText and okayText:IsA("TextLabel") then
		okayText.Text = "Buy Rebirth"
	end

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

	gui.Enabled = true
	isOpen = true
	panel.Visible = true
	panel.Position = CLOSED_POS
	dim.Visible = true
	dim.BackgroundTransparency = 1
	if dimTween then dimTween:Cancel() end
	dimTween = TweenService:Create(dim, TweenInfo.new(0.20, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { BackgroundTransparency = 0.55 })
	dimTween:Play()

	if openTween then openTween:Cancel() end
	openTween = TweenService:Create(panel, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = OPEN_POS })
	openTween:Play()
end

close.Activated:Connect(closePanel)

local function onOkayClicked()
	closePanel()
	local prodId = tonumber(Config.RebirthProductId)
	local passId = tonumber(Config.RebirthGamePassId)
	if prodId and prodId > 0 then
		pcall(function()
			MarketplaceService:PromptProductPurchase(player, prodId)
		end)
	elseif passId and passId > 0 then
		promptGamePass(passId)
	else
		MenuEvents.Request("Rebirth")
	end
end

okay.Activated:Connect(onOkayClicked)

dim.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		closePanel()
	end
end)

MenuEvents.CloseAll.Event:Connect(function(exceptMenuName)
	if exceptMenuName ~= "Treadmill" then
		closePanel()
	end
end)

local openTreadmillEvent = MenuEvents.Get("OpenTreadmillPanel")
openTreadmillEvent.Event:Connect(function(action)
	if action == "Close" then
		closePanel()
	end
end)

MenuEvents.MarkReady("Treadmill", function()
	return isOpen
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

print("[TreadmillLockPanel] V306ZA loaded. Gold/blue use the stud rebirth panel with Buy Rebirth option; pink and red/Admin treadmills open Roblox's native Pass purchase prompt.")
