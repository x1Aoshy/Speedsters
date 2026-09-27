local GuiService = game:GetService("GuiService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local MenuEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MenuEvents"))

if Config.AbilityFlightEnabled ~= true then
	return
end

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local AbilityShopAction = Remotes:WaitForChild("AbilityShopAction")
local AbilityShopUpdate = Remotes:WaitForChild("AbilityShopUpdate")
local openAbilitiesPanel = MenuEvents.Get("OpenAbilitiesPanel")
local otherPanelEvents = {
	MenuEvents.Get("OpenEvolvePanel"), MenuEvents.Get("OpenRebirthPanel"), MenuEvents.Get("OpenDailyPanel"),
	MenuEvents.Get("OpenTrailsPanel"), MenuEvents.Get("OpenAurasPanel"), MenuEvents.Get("OpenIndexPanel"),
	MenuEvents.Get("OpenTeleportPanel"),
}

local gui
while not gui do
	gui = playerGui:FindFirstChild("Abilities")
	if not gui then
		task.wait(0.25)
	end
end 

local panel = gui:WaitForChild("Panel")

-- Posición original respetada desde Studio
local OPEN_POSITION = panel.Position
local CLOSED_POSITION = UDim2.new(OPEN_POSITION.X.Scale, OPEN_POSITION.X.Offset, 1.28, 0)

local title = panel:WaitForChild("Name")
if title and title:IsA("TextLabel") then
	title.Text = "Abilities"
end

local closeButton = panel:WaitForChild("Close")
local card = panel:WaitForChild("ScrollingFrame"):WaitForChild("Frame")

-- Purchase buttons
local purchaseFrame = card:WaitForChild("Frame")
local winsButton = purchaseFrame:WaitForChild("WinsPurchase")
local robuxButton = purchaseFrame:WaitForChild("RobuxPurchase")

local flightGamePassId = tonumber(Config.AbilityFlightGamePassId or Config.AbilityFlightProductId) or 1978623069

local currentState = {
	Owned = player:GetAttribute("FlightAbilityOwned") == true, 
	Equipped = player:GetAttribute("FlightAbilityEquipped") == true, 
	Wins = 0, 
	WinsCost = tonumber(Config.AbilityFlightWinsCost) or 25000000, 
	ProductId = flightGamePassId, 
	RobuxPrice = tonumber(Config.AbilityFlightPriceRobux) or 79, 
	Message = ""
}

local lastOwned = currentState.Owned

local function formatNumber(value) 
	local n = tonumber(value) or 0
	if n >= 1e9 then
		return string.format("%.2fB", n / 1e9):gsub("%.?0+([B])", "%1")
	elseif n >= 1e6 then
		return string.format("%.2fM", n / 1e6):gsub("%.?0+([M])", "%1")
	elseif n >= 1e3 then
		return string.format("%.1fK", n / 1e3):gsub("%.?0+([K])", "%1")
	end
	return tostring(math.floor(n))
end

local flightDescLabel: TextLabel? = nil
for _, child in ipairs(card:GetChildren()) do
	if child:IsA("TextLabel") and child.Text:lower():find("fly") and child.Text:lower():find("glide") then
		flightDescLabel = child
		break
	end
end

local function updateFlightDescription()
	if not flightDescLabel then return end
	local lastInputType = UserInputService:GetLastInputType()
	local isGamepad = false
	pcall(function()
		isGamepad = GuiService:IsTenFootInterface()
	end)
	isGamepad = isGamepad
		or UserInputService.GamepadEnabled
		or #UserInputService:GetConnectedGamepads() > 0
		or lastInputType == Enum.UserInputType.Gamepad1
		or lastInputType == Enum.UserInputType.Gamepad2
		or lastInputType == Enum.UserInputType.Gamepad3
		or lastInputType == Enum.UserInputType.Gamepad4
		or lastInputType == Enum.UserInputType.Gamepad5
		or lastInputType == Enum.UserInputType.Gamepad6
		or lastInputType == Enum.UserInputType.Gamepad7
		or lastInputType == Enum.UserInputType.Gamepad8

	local isTouch = (lastInputType == Enum.UserInputType.Touch or UserInputService.TouchEnabled) and not UserInputService.KeyboardEnabled

	if isGamepad then
		flightDescLabel.Text = "Hold (A) or RB to fly, release to glide."
	elseif isTouch then
		flightDescLabel.Text = "Hold Jump button to fly, release to glide."
	else
		flightDescLabel.Text = "Hold Space to fly, release to glide."
	end
end

local function playSound(id, name)
	local sound = SoundService:FindFirstChild(name) or Instance.new("Sound")
	sound.Name = name
	sound.SoundId = id
	sound.Volume = 0.8
	sound.Parent = SoundService
	sound.TimePosition = 0
	SoundService:PlayLocalSound(sound)
end

local winsButtonText = winsButton:FindFirstChild("Name")
local winsButtonIcon = winsButton:FindFirstChildOfClass("ImageLabel")
local robuxButtonText = robuxButton:FindFirstChild("Name")
local robuxButtonIcon = robuxButton:FindFirstChildOfClass("ImageLabel")

local function render()
	local owned = currentState.Owned == true
	local equipped = owned and currentState.Equipped == true

	if winsButtonText and winsButtonText:IsA("TextLabel") then
		winsButtonText.Text = owned and (equipped and "UNEQUIP" or "EQUIP") or formatNumber(currentState.WinsCost) .. " Wins"
	end
	if winsButtonIcon then
		winsButtonIcon.Visible = not owned
	end
	winsButton.BackgroundColor3 = owned and (equipped and Color3.fromRGB(235, 92, 66) or Color3.fromRGB(60, 208, 76)) or Color3.fromRGB(60, 208, 76)

	if robuxButtonText and robuxButtonText:IsA("TextLabel") then
		robuxButtonText.Text = owned and "Purchased" or tostring(math.floor(currentState.RobuxPrice))
	end
	if robuxButtonIcon then
		robuxButtonIcon.Visible = not owned
	end
	robuxButton.Active = not owned

	if owned and not lastOwned then 
		playSound("rbxassetid://80736831159506", "AbilityShopSuccessSound") 
	end
	lastOwned = owned
	updateFlightDescription()
end

-- Fetch live GamePass price from Roblox
task.spawn(function()
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(flightGamePassId, Enum.InfoType.GamePass)
	end)
	if ok and info and info.PriceInRobux then
		currentState.RobuxPrice = info.PriceInRobux
		render()
	end
end)

UserInputService.LastInputTypeChanged:Connect(updateFlightDescription)
UserInputService.GamepadConnected:Connect(updateFlightDescription)
UserInputService.GamepadDisconnected:Connect(updateFlightDescription)
task.defer(updateFlightDescription)

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

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(buyer, passId, wasPurchased)
	if buyer == player and tonumber(passId) == flightGamePassId and wasPurchased then
		currentState.Owned = true
		currentState.Equipped = true
		render()
	end
end)

winsButton.Activated:Connect(function()
	if currentState.Owned then
		AbilityShopAction:FireServer(currentState.Equipped and "Unequip" or "Equip", "Flight")
	else
		AbilityShopAction:FireServer("BuyWins", "Flight")
	end
end)

robuxButton.Activated:Connect(function()
	if currentState.Owned then return end
	if RunService:IsStudio() then
		AbilityShopAction:FireServer("StudioBuyRobux", "Flight")
	else
		MarketplaceService:PromptGamePassPurchase(player, flightGamePassId)
	end
end)

local isOpen = false
local isClosing = false
local activeTween

local dimOverlay = gui:FindFirstChild("Dim")
local dimTween = nil

local function closePanel(instant)
	if not isOpen and not gui.Enabled then return end

	if instant then
		isOpen = false
		isClosing = false
		if activeTween then activeTween:Cancel() end
		if dimTween then dimTween:Cancel() end
		gui.Enabled = false
		panel.Position = CLOSED_POSITION
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
		dimTween = TweenService:Create(dimOverlay, TweenInfo.new(0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {BackgroundTransparency = 1})
		dimTween:Play()
	end

	if activeTween then activeTween:Cancel() end
	activeTween = TweenService:Create(panel, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = CLOSED_POSITION})
	activeTween:Play()

	task.delay(0.18, function()
		if not isClosing then return end
		isClosing = false
		isOpen = false
		gui.Enabled = false
		panel.Position = CLOSED_POSITION
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

	if dimOverlay and dimOverlay:IsA("GuiObject") then
		if dimTween then dimTween:Cancel() end
		dimOverlay.Visible = true
		dimOverlay.Active = true
		dimOverlay.BackgroundTransparency = 1
		dimTween = TweenService:Create(dimOverlay, TweenInfo.new(0.20, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {BackgroundTransparency = 0.55})
		dimTween:Play()
	end

	if activeTween then activeTween:Cancel() end
	panel.Position = CLOSED_POSITION
	AbilityShopAction:FireServer("RequestState")

	activeTween = TweenService:Create(panel, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = OPEN_POSITION})
	activeTween:Play()
end

if dimOverlay and dimOverlay:IsA("GuiObject") then
	dimOverlay.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			closePanel()
		end
	end)
end

openAbilitiesPanel.Event:Connect(function(action)
	if action == "Open" or action == "LeftButtonSwitch" then
		openPanel()
	elseif action == "Close" then
		closePanel()
	else
		if isOpen then closePanel() else openPanel() end
	end
end)

MenuEvents.CloseAll.Event:Connect(function() 
	closePanel(true) 
end)

MenuEvents.MarkReady("Abilities", function() 
	return isOpen 
end)

for _, event in ipairs(otherPanelEvents) do 
	event.Event:Connect(function() 
		if isOpen then closePanel(true) end 
	end) 
end

closeButton.Activated:Connect(function()
	closePanel()
end)

if closeButton:IsA("GuiButton") then
	closeButton.MouseButton1Click:Connect(function()
		closePanel()
	end)
end

closeButton.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		closePanel()
	end
end)

closePanel(true)
render()
AbilityShopAction:FireServer("RequestState")