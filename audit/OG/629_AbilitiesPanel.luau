                                                                                   
                                                                                  
                                                                                   

local GuiService = game:GetService("GuiService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local StudUi = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("StudUi"))
local MenuEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MenuEvents"))

                                                                                 
if Config.IsWorld2Place == true or Config.AbilityFlightEnabled ~= true then
	return
end

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local AbilityShopAction = Remotes:WaitForChild("AbilityShopAction")
local AbilityShopUpdate = Remotes:WaitForChild("AbilityShopUpdate")

local openAbilitiesPanel = MenuEvents.Get("OpenAbilitiesPanel")
local otherPanelEvents = {
	MenuEvents.Get("OpenEvolvePanel"), MenuEvents.Get("OpenRebirthPanel"),
	MenuEvents.Get("OpenDailyPanel"), MenuEvents.Get("OpenTrailsPanel"),
	MenuEvents.Get("OpenAurasPanel"), MenuEvents.Get("OpenIndexPanel"),
	MenuEvents.Get("OpenTeleportPanel"),
}

local OPEN_POSITION = UDim2.fromScale(0.5, 0.5)
local CLOSED_POSITION = UDim2.fromScale(0.5, 1.25)
local PANEL_SIZE = Vector2.new(720, 620)
local HEADER_COLOR = Color3.fromRGB(255, 88, 35)
local CARD_COLOR = Color3.fromRGB(255, 143, 37)
local TITLE_ICON_IMAGE = "rbxassetid://106467618023890"
local SHOP_ACTION_SOUND_ID = "rbxassetid://72264591133889"
local PURCHASE_SUCCESS_SOUND_ID = "rbxassetid://80736831159506"
local REQUIREMENT_FAIL_SOUND_ID = "rbxassetid://132281440773764"

local function addCorner(instance, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance
	return corner
end

local function addStroke(instance, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.Thickness = thickness
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = instance
	return stroke
end

local function addTextStroke(instance, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.Thickness = thickness
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = instance
	return stroke
end

local function styleText(label, size, alignment)
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextSize = size
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0
	label.TextXAlignment = alignment or Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
end

local function formatNumber(value)
	local text = tostring(math.floor(tonumber(value) or 0))
	while true do
		local changed
		text, changed = text:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		if changed == 0 then return text end
	end
end

local function makeSound(name, id, volume)
	local old = SoundService:FindFirstChild(name)
	if old then old:Destroy() end
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = id
	sound.Volume = volume
	sound.Parent = SoundService
	return sound
end

local shopSound = makeSound("AbilityShopActionSound", SHOP_ACTION_SOUND_ID, 0.65)
local successSound = makeSound("AbilityShopSuccessSound", PURCHASE_SUCCESS_SOUND_ID, 0.9)
local failSound = makeSound("AbilityShopRequirementFailSound", REQUIREMENT_FAIL_SOUND_ID, 0.9)

local function play(sound)
	sound.TimePosition = 0
	SoundService:PlayLocalSound(sound)
end

local oldGui = playerGui:FindFirstChild("AbilitiesPanelGui")
if oldGui then oldGui:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "AbilitiesPanelGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 82
gui.Enabled = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local dim = Instance.new("TextButton")
dim.Name = "Dim"
dim.Size = UDim2.fromScale(1, 1)
dim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
dim.BackgroundTransparency = 1
dim.BorderSizePixel = 0
dim.Text = ""
dim.AutoButtonColor = false
dim.ZIndex = 9
dim.Parent = gui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = CLOSED_POSITION
panel.Size = UDim2.fromOffset(PANEL_SIZE.X, PANEL_SIZE.Y)
panel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
panel.BorderSizePixel = 0
panel.ZIndex = 10
panel.Parent = gui
addCorner(panel, 18)
addStroke(panel, 5)
StudUi.AddSurface(panel, 10, 18)

local responsiveScale = Instance.new("UIScale")
responsiveScale.Name = "ResponsiveScale"
responsiveScale.Parent = panel

local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 112)
header.BackgroundColor3 = HEADER_COLOR
header.BorderSizePixel = 0
header.ZIndex = 11
header.Parent = panel
addCorner(header, 16)
addStroke(header, 5)
StudUi.AddSurface(header, 12, 16)

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
title.Size = UDim2.fromOffset(390, 72)
title.BackgroundTransparency = 1
title.Text = "Abilities"
title.ZIndex = 13
title.Parent = header
styleText(title, 46, Enum.TextXAlignment.Left)
addTextStroke(title, 4)

local closeButton = Instance.new("TextButton")
closeButton.Name = "Close"
closeButton.AnchorPoint = Vector2.new(1, 0.5)
closeButton.Position = UDim2.new(1, -16, 0.5, 0)
closeButton.Size = UDim2.fromOffset(62, 62)
closeButton.BackgroundColor3 = Color3.fromRGB(255, 85, 85)
closeButton.BorderSizePixel = 0
closeButton.AutoButtonColor = false
closeButton.Text = "X"
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.TextSize = 32
closeButton.ZIndex = 13
closeButton.Parent = header
addCorner(closeButton, 12)
addStroke(closeButton, 4)
StudUi.StyleButton(closeButton, 12)

local card = Instance.new("Frame")
card.Name = "FlightCard"
card.AnchorPoint = Vector2.new(0.5, 0)
card.Position = UDim2.new(0.5, 0, 0, 150)
card.Size = UDim2.new(1, -86, 0, 210)
card.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
card.BackgroundTransparency = 0.18
card.BorderSizePixel = 0
card.ZIndex = 12
card.Parent = panel
addCorner(card, 15)
addStroke(card, 4)

local colored = Instance.new("Frame")
colored.Name = "ColoredRectangle"
colored.Position = UDim2.fromOffset(4, 4)
colored.Size = UDim2.new(1, -8, 1, -8)
colored.BackgroundColor3 = CARD_COLOR
colored.BackgroundTransparency = 0.08
colored.BorderSizePixel = 0
colored.ZIndex = 14
colored.ClipsDescendants = true
colored.Parent = card
addCorner(colored, 12)
addStroke(colored, 5)
StudUi.AddSurface(colored, 15, 12)

local nameLabel = Instance.new("TextLabel")
nameLabel.Name = "AbilityName"
nameLabel.Position = UDim2.fromOffset(20, 16)
nameLabel.Size = UDim2.fromOffset(250, 48)
nameLabel.BackgroundTransparency = 1
nameLabel.Text = "Flight"
nameLabel.ZIndex = 18
nameLabel.Parent = card
styleText(nameLabel, 30, Enum.TextXAlignment.Left)

local instruction = Instance.new("TextLabel")
instruction.Name = "Instruction"
instruction.Position = UDim2.fromOffset(20, 68)
instruction.Size = UDim2.fromOffset(330, 72)
instruction.BackgroundTransparency = 1
instruction.Text = "Hold SPACE to fly up\nRelease to glide"
instruction.TextWrapped = true
instruction.ZIndex = 18
instruction.Parent = card
styleText(instruction, 22, Enum.TextXAlignment.Left)
instruction.TextColor3 = Color3.fromRGB(255, 240, 115)

local stamina = Instance.new("TextLabel")
stamina.Name = "StaminaInfo"
stamina.Position = UDim2.fromOffset(20, 145)
stamina.Size = UDim2.fromOffset(330, 40)
stamina.BackgroundTransparency = 1
stamina.Text = "Uses Stamina"
stamina.ZIndex = 18
stamina.Parent = card
styleText(stamina, 21, Enum.TextXAlignment.Left)

local icon = Instance.new("ImageLabel")
icon.Name = "AbilityIcon"
icon.AnchorPoint = Vector2.new(0.5, 0.5)
icon.Position = UDim2.new(0.56, 0, 0.5, 0)
icon.Size = UDim2.fromOffset(155, 155)
icon.BackgroundTransparency = 1
icon.Image = TITLE_ICON_IMAGE
icon.ImageTransparency = 0.10
icon.ScaleType = Enum.ScaleType.Fit
icon.ZIndex = 18
icon.Parent = card

local winsButton = Instance.new("TextButton")
winsButton.Name = "WinsButton"
winsButton.AnchorPoint = Vector2.new(1, 0)
winsButton.Position = UDim2.new(1, -14, 0, 25)
winsButton.Size = UDim2.fromOffset(170, 64)
winsButton.BackgroundColor3 = Color3.fromRGB(60, 208, 76)
winsButton.BorderSizePixel = 0
winsButton.AutoButtonColor = false
winsButton.TextColor3 = Color3.fromRGB(255, 255, 255)
winsButton.TextSize = 23
winsButton.ZIndex = 17
winsButton.Parent = card
addCorner(winsButton, 10)
addStroke(winsButton, 3)
StudUi.StyleButton(winsButton, 10)

local robuxButton = Instance.new("TextButton")
robuxButton.Name = "RobuxButton"
robuxButton.AnchorPoint = Vector2.new(1, 0)
robuxButton.Position = UDim2.new(1, -14, 0, 119)
robuxButton.Size = UDim2.fromOffset(170, 64)
robuxButton.BackgroundColor3 = Color3.fromRGB(176, 80, 220)
robuxButton.BorderSizePixel = 0
robuxButton.AutoButtonColor = false
robuxButton.TextColor3 = Color3.fromRGB(255, 255, 255)
robuxButton.TextSize = 23
robuxButton.ZIndex = 17
robuxButton.Parent = card
addCorner(robuxButton, 10)
addStroke(robuxButton, 3)
StudUi.StyleButton(robuxButton, 10)

local footer = Instance.new("TextLabel")
footer.Name = "FooterMessage"
footer.AnchorPoint = Vector2.new(0.5, 0)
footer.Position = UDim2.new(0.5, 0, 0, 390)
footer.Size = UDim2.new(1, -70, 0, 54)
footer.BackgroundTransparency = 1
footer.Text = ""
footer.TextWrapped = true
footer.ZIndex = 14
footer.Parent = panel
styleText(footer, 20)
footer.TextColor3 = HEADER_COLOR

local currentState = {
	Owned = player:GetAttribute("FlightAbilityOwned") == true,
	Equipped = player:GetAttribute("FlightAbilityEquipped") == true,
	Wins = 0,
	WinsCost = tonumber(Config.AbilityFlightWinsCost) or 1000000,
	ProductId = tonumber(Config.AbilityFlightProductId) or 3708338152,
	RobuxPrice = tonumber(Config.AbilityFlightPriceRobux) or 79,
	Message = "",
}
local lastOwned = currentState.Owned

local function render()
	local owned = currentState.Owned == true
	local equipped = owned and currentState.Equipped == true
	if owned then
		winsButton.Text = equipped and "UNEQUIP" or "EQUIP"
		winsButton.BackgroundColor3 = equipped and Color3.fromRGB(235, 92, 66) or Color3.fromRGB(60, 208, 76)
		winsButton.Active = true
		winsButton.Selectable = true
		robuxButton.Text = "Owned"
		robuxButton.Active = false
		robuxButton.Selectable = false
	else
		winsButton.Text = formatNumber(currentState.WinsCost) .. " Wins"
		winsButton.BackgroundColor3 = Color3.fromRGB(60, 208, 76)
		winsButton.Active = true
		winsButton.Selectable = true
		robuxButton.Text = "R$ " .. tostring(math.floor(currentState.RobuxPrice))
		robuxButton.Active = true
		robuxButton.Selectable = true
	end
	footer.Text = currentState.Message or ""
	if owned and not lastOwned then play(successSound) end
	lastOwned = owned
end

AbilityShopUpdate.OnClientEvent:Connect(function(state)
	if type(state) ~= "table" then return end
	local flight = type(state.Flight) == "table" and state.Flight or {}
	currentState.Owned = flight.Owned == true
	currentState.Equipped = flight.Equipped == true
	currentState.Wins = tonumber(state.Wins) or currentState.Wins
	currentState.WinsCost = tonumber(flight.WinsCost) or currentState.WinsCost
	currentState.ProductId = tonumber(flight.ProductId) or currentState.ProductId
	currentState.RobuxPrice = tonumber(flight.RobuxPrice) or currentState.RobuxPrice
	currentState.Message = tostring(state.Message or "")
	render()
end)

player:GetAttributeChangedSignal("FlightAbilityOwned"):Connect(function()
	currentState.Owned = player:GetAttribute("FlightAbilityOwned") == true
	render()
end)
player:GetAttributeChangedSignal("FlightAbilityEquipped"):Connect(function()
	currentState.Equipped = player:GetAttribute("FlightAbilityEquipped") == true
	render()
end)

winsButton.Activated:Connect(function()
	play(shopSound)
	if currentState.Owned then
		if currentState.Equipped then
			footer.Text = "Unequipping Flight..."
			AbilityShopAction:FireServer("Unequip", "Flight")
		else
			footer.Text = "Equipping Flight..."
			AbilityShopAction:FireServer("Equip", "Flight")
		end
		return
	end
	if currentState.Wins < currentState.WinsCost then
		footer.Text = "Not Enough Wins (Need " .. formatNumber(currentState.WinsCost) .. " Wins)"
		play(failSound)
		return
	end
	footer.Text = "Buying Flight..."
	AbilityShopAction:FireServer("BuyWins", "Flight")
end)

robuxButton.Activated:Connect(function()
	if currentState.Owned then return end
	play(shopSound)
	footer.Text = "Opening Robux purchase..."
	MarketplaceService:PromptProductPurchase(player, currentState.ProductId)
end)

local isOpen = false
local activeTween
local dimTween

local function stopTweens()
	if activeTween then activeTween:Cancel() activeTween = nil end
	if dimTween then dimTween:Cancel() dimTween = nil end
end

local function closePanel()
	if not isOpen then return end
	isOpen = false
	stopTweens()
	activeTween = TweenService:Create(panel, TweenInfo.new(0.21, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = CLOSED_POSITION})
	dimTween = TweenService:Create(dim, TweenInfo.new(0.16), {BackgroundTransparency = 1})
	activeTween:Play()
	dimTween:Play()
	activeTween.Completed:Once(function()
		if not isOpen then gui.Enabled = false end
	end)
end

local function openPanel()
	stopTweens()
	gui.Enabled = true
	isOpen = true
	panel.Position = CLOSED_POSITION
	dim.BackgroundTransparency = 1
	AbilityShopAction:FireServer("RequestState")
	activeTween = TweenService:Create(panel, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = OPEN_POSITION})
	dimTween = TweenService:Create(dim, TweenInfo.new(0.18), {BackgroundTransparency = 0.35})
	activeTween:Play()
	dimTween:Play()
end

local function togglePanel()
	if gui.Enabled and isOpen then closePanel() else openPanel() end
end

openAbilitiesPanel.Event:Connect(togglePanel)
MenuEvents.CloseAll.Event:Connect(closePanel)
MenuEvents.MarkReady("Abilities", function() return isOpen end)
for _, event in ipairs(otherPanelEvents) do
	event.Event:Connect(function() if isOpen then closePanel() end end)
end
closeButton.Activated:Connect(closePanel)
dim.Activated:Connect(closePanel)

local function updateScale()
	local camera = Workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
	local inset = GuiService:GetGuiInset()
	local availableWidth = math.max(320, viewport.X - 20)
	local availableHeight = math.max(320, viewport.Y - inset.Y - 20)
	local fit = math.min(availableWidth / PANEL_SIZE.X, availableHeight / PANEL_SIZE.Y)
	local minimum = UserInputService.TouchEnabled and 0.44 or 0.60
	local maximum = UserInputService.TouchEnabled and 0.98 or 1.08
	responsiveScale.Scale = math.clamp(fit, minimum, maximum)
end

updateScale()
if Workspace.CurrentCamera then Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale) end
render()
AbilityShopAction:FireServer("RequestState")

print("[AbilitiesPanel] V306KU World 1 Flight card | persistent Equip/Unequip")
