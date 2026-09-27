         
                                                                              
                                                                                 

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local MenuEvents = require(Shared:WaitForChild("MenuEvents"))
local PurchaseButtonSound = require(Shared:WaitForChild("PurchaseButtonSound"))
local StudUi = require(Shared:WaitForChild("StudUi"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local WorldPortalAction = Remotes:WaitForChild("WorldPortalAction")
local WorldPortalUpdate = Remotes:WaitForChild("WorldPortalUpdate")

local WORLD_2_PLACE_ID = 116359653478954
local OPEN_POSITION = UDim2.fromScale(0.5, 0.5)
local CLOSED_POSITION = UDim2.fromScale(0.5, 1.28)
local PANEL_WIDTH = 660
local PANEL_HEIGHT = 470
local PORTAL_ICON = "rbxassetid://72658080659794"
local REQUIREMENT_FAIL_SOUND_ID = "rbxassetid://132281440773764"

local HEADER_COLOR = Color3.fromRGB(113, 63, 255)
local WORLD_1_COLOR = Color3.fromRGB(38, 220, 137)
local WORLD_1_DARK = Color3.fromRGB(13, 119, 72)
local WORLD_2_COLOR = Color3.fromRGB(196, 54, 255)
local WORLD_2_DARK = Color3.fromRGB(96, 20, 153)
local CURRENT_COLOR = Color3.fromRGB(98, 110, 125)
local LOCKED_COLOR = Color3.fromRGB(255, 178, 31)
local COMING_SOON_COLOR = Color3.fromRGB(50, 52, 65)

local currentState = {
	CurrentWorld = game.PlaceId == WORLD_2_PLACE_ID and 2 or 1,
	World2ComingSoon = false,
	World2Unlocked = false,
	Level = 1,
	Rebirths = 0,
	RequiredLevel = 100,
	RequiredRebirths = 7,
	MeetsWorld2Requirements = false,
	DataReady = false,
	Busy = false,
	Message = "Touch PortalWorld2 to open this menu",
	Status = "State",
}

local isOpen = false
local activeTween = nil
local dimTween = nil
local openSerial = 0

local oldGui = playerGui:FindFirstChild("WorldPortalGui")
if oldGui then
	oldGui:Destroy()
end

local requirementFailSound = SoundService:FindFirstChild("SpeedsterRequirementFailSound")
if not requirementFailSound or not requirementFailSound:IsA("Sound") then
	if requirementFailSound then
		requirementFailSound:Destroy()
	end
	requirementFailSound = Instance.new("Sound")
	requirementFailSound.Name = "SpeedsterRequirementFailSound"
	requirementFailSound.Parent = SoundService
end
requirementFailSound.SoundId = REQUIREMENT_FAIL_SOUND_ID
requirementFailSound.Volume = 0.9
requirementFailSound.PlaybackSpeed = 1

local function playRequirementFailSound()
	requirementFailSound.TimePosition = 0
	SoundService:PlayLocalSound(requirementFailSound)
end

local function addCorner(instance, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance
	return corner
end

local function addStroke(instance, thickness, color)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Color3.fromRGB(0, 0, 0)
	stroke.Thickness = thickness
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = instance
	return stroke
end

local function styleText(label, textSize, color)
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	label.TextSize = textSize
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	return label
end

local gui = Instance.new("ScreenGui")
gui.Name = "WorldPortalGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 86
gui.Enabled = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local dim = Instance.new("Frame")
dim.Name = "Dim"
dim.Size = UDim2.fromScale(1, 1)
dim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
dim.BackgroundTransparency = 1
dim.BorderSizePixel = 0
dim.ZIndex = 9
dim.Parent = gui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = CLOSED_POSITION
panel.Size = UDim2.fromOffset(PANEL_WIDTH, PANEL_HEIGHT)
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
header.Size = UDim2.new(1, 0, 0, 100)
header.BackgroundColor3 = HEADER_COLOR
header.BorderSizePixel = 0
header.ZIndex = 11
header.Parent = panel
addCorner(header, 16)
addStroke(header, 5)
StudUi.AddSurface(header, 12, 16)

local titleIcon = Instance.new("ImageLabel")
titleIcon.Name = "PortalIcon"
titleIcon.AnchorPoint = Vector2.new(0, 0.5)
titleIcon.Position = UDim2.new(0, 16, 0.5, 0)
titleIcon.Size = UDim2.fromOffset(78, 78)
titleIcon.BackgroundTransparency = 1
titleIcon.Image = PORTAL_ICON
titleIcon.ScaleType = Enum.ScaleType.Fit
titleIcon.ZIndex = 13
titleIcon.Parent = header

local title = Instance.new("TextLabel")
title.Name = "Title"
title.AnchorPoint = Vector2.new(0, 0.5)
title.Position = UDim2.new(0, 104, 0.5, 0)
title.Size = UDim2.fromOffset(350, 68)
title.BackgroundTransparency = 1
title.Text = "WORLDS"
title.TextXAlignment = Enum.TextXAlignment.Left
title.ZIndex = 13
title.Parent = header
styleText(title, 47)
title.TextXAlignment = Enum.TextXAlignment.Left

local closeButton = Instance.new("TextButton")
closeButton.Name = "Close"
closeButton.AnchorPoint = Vector2.new(1, 0.5)
closeButton.Position = UDim2.new(1, -15, 0.5, 0)
closeButton.Size = UDim2.fromOffset(58, 58)
closeButton.BackgroundColor3 = Color3.fromRGB(255, 77, 77)
closeButton.BorderSizePixel = 0
closeButton.AutoButtonColor = false
closeButton.Text = "X"
closeButton.TextScaled = false
closeButton.ZIndex = 13
closeButton.Parent = header
styleText(closeButton, 32)
addCorner(closeButton, 12)
addStroke(closeButton, 4)
StudUi.StyleButton(closeButton, 12)

local cardsHolder = Instance.new("Frame")
cardsHolder.Name = "WorldCards"
cardsHolder.Position = UDim2.fromOffset(24, 119)
cardsHolder.Size = UDim2.new(1, -48, 0, 282)
cardsHolder.BackgroundTransparency = 1
cardsHolder.BorderSizePixel = 0
cardsHolder.ZIndex = 11
cardsHolder.Parent = panel

local cardsLayout = Instance.new("UIListLayout")
cardsLayout.FillDirection = Enum.FillDirection.Horizontal
cardsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
cardsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
cardsLayout.Padding = UDim.new(0, 18)
cardsLayout.SortOrder = Enum.SortOrder.LayoutOrder
cardsLayout.Parent = cardsHolder

local cards = {}
local render

local function buildWorldCard(worldNumber, color, darkColor)
	local card = Instance.new("Frame")
	card.Name = "World" .. tostring(worldNumber)
	card.LayoutOrder = worldNumber
	card.Size = UDim2.fromOffset(294, 278)
	card.BackgroundColor3 = color
	card.BorderSizePixel = 0
	card.ZIndex = 12
	card.Parent = cardsHolder
	addCorner(card, 16)
	addStroke(card, 4)
	StudUi.AddSurface(card, 13, 16)

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "WorldName"
	nameLabel.Position = UDim2.fromOffset(12, 10)
	nameLabel.Size = UDim2.new(1, -24, 0, 43)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = "WORLD " .. tostring(worldNumber)
	nameLabel.ZIndex = 15
	nameLabel.Parent = card
	styleText(nameLabel, 32)

	local portalDisc = Instance.new("Frame")
	portalDisc.Name = "PortalDisc"
	portalDisc.AnchorPoint = Vector2.new(0.5, 0)
	portalDisc.Position = UDim2.new(0.5, 0, 0, 58)
	portalDisc.Size = UDim2.fromOffset(92, 92)
	portalDisc.BackgroundColor3 = darkColor
	portalDisc.BorderSizePixel = 0
	portalDisc.ZIndex = 14
	portalDisc.Parent = card
	addCorner(portalDisc, 46)
	addStroke(portalDisc, 4)

	local portalNumber = Instance.new("TextLabel")
	portalNumber.Name = "Number"
	portalNumber.Size = UDim2.fromScale(1, 1)
	portalNumber.BackgroundTransparency = 1
	portalNumber.Text = tostring(worldNumber)
	portalNumber.ZIndex = 15
	portalNumber.Parent = portalDisc
	styleText(portalNumber, 56)

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.Position = UDim2.fromOffset(13, 146)
	status.Size = UDim2.new(1, -26, 0, 40)
	status.BackgroundTransparency = 1
	status.Text = ""
	status.TextWrapped = true
	status.ZIndex = 15
	status.Parent = card
	styleText(status, 17)

	local requirement = Instance.new("TextLabel")
	requirement.Name = "Requirement"
	requirement.Position = UDim2.fromOffset(12, 184)
	requirement.Size = UDim2.new(1, -24, 0, 31)
	requirement.BackgroundTransparency = 1
	requirement.Text = ""
	requirement.TextWrapped = true
	requirement.ZIndex = 15
	requirement.Parent = card
	styleText(requirement, 16)

	local action = Instance.new("TextButton")
	action.Name = "Action"
	action.AnchorPoint = Vector2.new(0.5, 1)
	action.Position = UDim2.new(0.5, 0, 1, -12)
	action.Size = UDim2.new(1, -28, 0, 51)
	action.BackgroundColor3 = darkColor
	action.BorderSizePixel = 0
	action.AutoButtonColor = false
	action.Text = "TELEPORT"
	action.TextScaled = false
	action.TextWrapped = true
	action.ZIndex = 15
	action.Parent = card
	styleText(action, 22)
	addCorner(action, 11)
	addStroke(action, 4)
	StudUi.StyleButton(action, 11)

	local hoverScale = Instance.new("UIScale")
	hoverScale.Name = "HoverScale"
	hoverScale.Scale = 1
	hoverScale.Parent = action
	action.MouseEnter:Connect(function()
		if action.Active then
			TweenService:Create(hoverScale, TweenInfo.new(0.12), { Scale = 1.035 }):Play()
		end
	end)
	action.MouseLeave:Connect(function()
		TweenService:Create(hoverScale, TweenInfo.new(0.12), { Scale = 1 }):Play()
	end)

	local comingSoonOverlay = nil
	if worldNumber == 2 then
		                                                                           
		                                                                             
		                                          
		comingSoonOverlay = Instance.new("Frame")
		comingSoonOverlay.Name = "ComingSoonOverlay"
		comingSoonOverlay.Size = UDim2.fromScale(1, 1)
		comingSoonOverlay.BackgroundColor3 = Color3.fromRGB(18, 19, 28)
		comingSoonOverlay.BackgroundTransparency = 0.12
		comingSoonOverlay.BorderSizePixel = 0
		comingSoonOverlay.Active = true
		comingSoonOverlay.Selectable = false
		comingSoonOverlay.ClipsDescendants = true
		comingSoonOverlay.ZIndex = 24
		comingSoonOverlay.Parent = card
		addCorner(comingSoonOverlay, 16)
		addStroke(comingSoonOverlay, 4, Color3.fromRGB(15, 15, 20))

		local frostGradient = Instance.new("UIGradient")
		frostGradient.Name = "FrostedGradient"
		frostGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(24, 25, 38)),
			ColorSequenceKeypoint.new(0.48, Color3.fromRGB(58, 48, 76)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 21, 31)),
		})
		frostGradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.08),
			NumberSequenceKeypoint.new(0.5, 0.24),
			NumberSequenceKeypoint.new(1, 0.08),
		})
		frostGradient.Rotation = 22
		frostGradient.Parent = comingSoonOverlay

		local comingSoonText = Instance.new("TextLabel")
		comingSoonText.Name = "ComingSoonText"
		comingSoonText.AnchorPoint = Vector2.new(0.5, 0.5)
		comingSoonText.Position = UDim2.fromScale(0.5, 0.5)
		comingSoonText.Size = UDim2.new(1, -30, 0, 72)
		comingSoonText.BackgroundTransparency = 1
		comingSoonText.BorderSizePixel = 0
		comingSoonText.Text = "COMING SOON"
		comingSoonText.TextWrapped = true
		comingSoonText.ZIndex = 27
		comingSoonText.Parent = comingSoonOverlay
		styleText(comingSoonText, 34, Color3.fromRGB(235, 235, 242))
	end

	cards[worldNumber] = {
		Frame = card,
		Status = status,
		Requirement = requirement,
		Action = action,
		ThemeColor = darkColor,
		ComingSoonOverlay = comingSoonOverlay,
	}

	action.Activated:Connect(function()
		if not action.Active then
			return
		end
		if worldNumber == 2 and currentState.World2ComingSoon ~= false then
			currentState.Message = "World 2 is coming soon"
			currentState.Status = "ComingSoon"
			render()
			return
		end
		PurchaseButtonSound.Play()
		currentState.Busy = true
		currentState.Message = worldNumber == 2 and not currentState.World2Unlocked
			and "Checking World 2 requirements..."
			or "Preparing teleport..."
		render()
		WorldPortalAction:FireServer("Travel", worldNumber)
	end)

	return card
end

buildWorldCard(1, WORLD_1_COLOR, WORLD_1_DARK)
buildWorldCard(2, WORLD_2_COLOR, WORLD_2_DARK)

local footerMessage = Instance.new("TextLabel")
footerMessage.Name = "Message"
footerMessage.AnchorPoint = Vector2.new(0.5, 1)
footerMessage.Position = UDim2.new(0.5, 0, 1, -11)
footerMessage.Size = UDim2.new(1, -40, 0, 43)
footerMessage.BackgroundTransparency = 1
footerMessage.Text = ""
footerMessage.TextWrapped = true
footerMessage.ZIndex = 12
footerMessage.Parent = panel
styleText(footerMessage, 18, HEADER_COLOR)
footerMessage.TextColor3 = HEADER_COLOR

local function setButtonState(card, text, enabled, color)
	card.Action.Text = text
	card.Action.Active = enabled
	card.Action.Selectable = enabled
	card.Action.BackgroundColor3 = color
	card.Action.AutoButtonColor = false
	card.Action:SetAttribute("Enabled", enabled)
end

render = function()
	local current = math.floor(tonumber(currentState.CurrentWorld) or 1)
	local level = math.max(1, math.floor(tonumber(currentState.Level) or 1))
	local rebirths = math.max(0, math.floor(tonumber(currentState.Rebirths) or 0))
	local requiredLevel = math.max(1, math.floor(tonumber(currentState.RequiredLevel) or 100))
	local requiredRebirths = math.max(0, math.floor(tonumber(currentState.RequiredRebirths) or 7))
	local unlocked = currentState.World2Unlocked == true
	local comingSoon = currentState.World2ComingSoon ~= false
	local busy = currentState.Busy == true or currentState.Status == "Teleporting"

	local world1 = cards[1]
	world1.Status.Text = current == 1 and "" or "RETURN TO WORLD 1"
	world1.Requirement.Text = "Starter World • Always Available"
	if current == 1 then
		setButtonState(world1, "CURRENT WORLD", false, CURRENT_COLOR)
	else
		setButtonState(world1, busy and "PLEASE WAIT..." or "TELEPORT", not busy, WORLD_1_DARK)
	end

	local world2 = cards[2]
	if world2.ComingSoonOverlay then
		world2.ComingSoonOverlay.Visible = comingSoon
	end
	world2.Action.Visible = not comingSoon
	if comingSoon then
		world2.Status.Text = ""
		world2.Requirement.Text = ""
		setButtonState(world2, "COMING SOON", false, COMING_SOON_COLOR)
	elseif current == 2 then
		world2.Status.Text = ""
		world2.Requirement.Text = "WORLD 2 UNLOCKED"
		setButtonState(world2, "CURRENT WORLD", false, CURRENT_COLOR)
	elseif unlocked then
		world2.Status.Text = "UNLOCKED FOREVER"
		world2.Requirement.Text = "Your World 2 access is saved"
		setButtonState(world2, busy and "PLEASE WAIT..." or "TELEPORT", not busy, WORLD_2_DARK)
	else
		world2.Status.Text = ""
		world2.Requirement.Text = "REQUIRES " .. tostring(requiredRebirths) .. " REBIRTHS + LEVEL " .. tostring(requiredLevel)
		setButtonState(world2, busy and "PLEASE WAIT..." or "UNLOCK WORLD 2", not busy, LOCKED_COLOR)
	end

	footerMessage.Text = tostring(currentState.Message or "")
	if currentState.Status == "Error" or currentState.Status == "Locked" then
		footerMessage.TextColor3 = Color3.fromRGB(255, 74, 74)
	elseif currentState.Status == "ComingSoon" then
		footerMessage.TextColor3 = Color3.fromRGB(190, 184, 210)
	elseif currentState.Status == "Teleporting" then
		footerMessage.TextColor3 = Color3.fromRGB(70, 210, 255)
	elseif currentState.Status == "StudioPreview" then
		footerMessage.TextColor3 = Color3.fromRGB(49, 192, 101)
	else
		footerMessage.TextColor3 = HEADER_COLOR
	end

	                                                                             
	                                                                            
	                                            
	for _, card in pairs(cards) do
		local buttonText = card.Action:FindFirstChild("ButtonText")
		if buttonText and buttonText:IsA("TextLabel") then
			buttonText.Text = card.Action.Text
			buttonText.TextSize = card.Action.TextSize
			buttonText.TextWrapped = card.Action.TextWrapped
		end
	end
end

local function closePanel()
	if not gui.Enabled then
		return
	end
	openSerial += 1
	isOpen = false
	if activeTween then
		activeTween:Cancel()
	end
	if dimTween then
		dimTween:Cancel()
	end

	activeTween = TweenService:Create(
		panel,
		TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Position = CLOSED_POSITION, Rotation = 0 }
	)
	activeTween:Play()
	dimTween = TweenService:Create(dim, TweenInfo.new(0.18), { BackgroundTransparency = 1 })
	dimTween:Play()

	local serial = openSerial
	task.delay(0.23, function()
		if not isOpen and openSerial == serial then
			gui.Enabled = false
		end
	end)
end

local function openPanel()
	openSerial += 1
	isOpen = true
	gui.Enabled = true
	render()
	WorldPortalAction:FireServer("RequestState")

	if activeTween then
		activeTween:Cancel()
	end
	if dimTween then
		dimTween:Cancel()
	end

	panel.Position = CLOSED_POSITION
	panel.Rotation = -1.4
	activeTween = TweenService:Create(
		panel,
		TweenInfo.new(0.26, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = OPEN_POSITION, Rotation = 0 }
	)
	activeTween:Play()
	dimTween = TweenService:Create(dim, TweenInfo.new(0.18), { BackgroundTransparency = 0.35 })
	dimTween:Play()
end

closeButton.Activated:Connect(function()
	PurchaseButtonSound.Play()
	closePanel()
end)

local openWorldsPanel = MenuEvents.Get("OpenWorldsPanel")
openWorldsPanel.Event:Connect(openPanel)
MenuEvents.CloseAll.Event:Connect(closePanel)
MenuEvents.MarkReady("Worlds", function()
	return isOpen
end)

WorldPortalUpdate.OnClientEvent:Connect(function(state)
	if type(state) ~= "table" then
		return
	end

	local previousStatus = currentState.Status
	currentState = state
	render()

	if (state.Status == "Locked" or state.Status == "Error") and previousStatus ~= state.Status then
		playRequirementFailSound()
	end

	if state.OpenMenu == true and not isOpen then
		MenuEvents.Request("Worlds")
	end
end)

local function updateScale()
	local camera = Workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
	local inset = GuiService:GetGuiInset()
	local availableWidth = math.max(320, viewport.X - 20)
	local availableHeight = math.max(300, viewport.Y - inset.Y - 20)
	local fit = math.min(availableWidth / PANEL_WIDTH, availableHeight / PANEL_HEIGHT)
	local minimum = UserInputService.TouchEnabled and 0.45 or 0.62
	local maximum = UserInputService.TouchEnabled and 0.96 or 1.04
	responsiveScale.Scale = math.clamp(fit, minimum, maximum)
end

local viewportConnection = nil
local function bindCamera(camera)
	if viewportConnection then
		viewportConnection:Disconnect()
		viewportConnection = nil
	end
	if camera then
		viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end
	updateScale()
end

Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	bindCamera(Workspace.CurrentCamera)
end)
bindCamera(Workspace.CurrentCamera)

render()
print("[WorldPortalPanel] V306JL loaded. World 2 is available at 7 Rebirths + Level 100.")
