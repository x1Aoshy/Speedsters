       
                                                                          
                                                                             
                                                                 

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local StudUi = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("StudUi"))
local MenuEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MenuEvents"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local requestRemote = remotes:WaitForChild("SkinIndexRequest")
local updateRemote = remotes:WaitForChild("SkinIndexUpdate")

local getOpenEvent = MenuEvents.Get

local openIndexPanel = getOpenEvent("OpenIndexPanel")
local otherOpenEvents = {
	getOpenEvent("OpenAbilitiesPanel"),
	getOpenEvent("OpenEvolvePanel"),
	getOpenEvent("OpenRebirthPanel"),
	getOpenEvent("OpenDailyPanel"),
	getOpenEvent("OpenTrailsPanel"),
	getOpenEvent("OpenAurasPanel"),
	getOpenEvent("OpenTeleportPanel"),
}

local PANEL_SIZE = Vector2.new(840, 545)
local OPEN_POSITION = UDim2.fromScale(0.5, 0.5)
local CLOSED_POSITION = UDim2.fromScale(0.5, 1.26)
local INDEX_COLOR = Color3.fromRGB(20, 212, 255)
local INDEX_DARK = Color3.fromRGB(0, 137, 255)
local EQUIP_COLOR = Color3.fromRGB(205, 45, 255)
local EQUIPPED_COLOR = Color3.fromRGB(80, 255, 30)
local INDEX_ICON = "rbxassetid://72509882071188"
local SKIN_EQUIP_SOUND_ID = "rbxassetid://80736831159506"

local oldGui = playerGui:FindFirstChild("IndexPanel")
if oldGui then
	oldGui:Destroy()
end

local function addCorner(instance, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance
	return corner
end

local function addStroke(instance, thickness, color)
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = color or Color3.fromRGB(0, 0, 0)
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

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "IndexPanel"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 72
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local equipSound = Instance.new("Sound")
equipSound.Name = "IndexSkinEquipSound"
equipSound.SoundId = SKIN_EQUIP_SOUND_ID
equipSound.Volume = 0.9
equipSound.Parent = screenGui

local function playEquipSound()
	equipSound.TimePosition = 0
	equipSound:Play()
end

local dim = Instance.new("TextButton")
dim.Name = "Dim"
dim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
dim.BackgroundTransparency = 1
dim.BorderSizePixel = 0
dim.Size = UDim2.fromScale(1, 1)
dim.Text = ""
dim.Visible = false
dim.AutoButtonColor = false
dim.ZIndex = 1
dim.Parent = screenGui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = CLOSED_POSITION
panel.Size = UDim2.fromOffset(PANEL_SIZE.X, PANEL_SIZE.Y)
panel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
panel.BorderSizePixel = 0
panel.Visible = false
panel.ZIndex = 2
panel.Parent = screenGui
addCorner(panel, 22)
addStroke(panel, 5)

local panelScale = Instance.new("UIScale")
panelScale.Parent = panel

local body = Instance.new("Frame")
body.Name = "WhiteStudBody"
body.Position = UDim2.fromOffset(10, 90)
body.Size = UDim2.new(1, -20, 1, -100)
body.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
body.BorderSizePixel = 0
body.ZIndex = 3
body.Parent = panel
addCorner(body, 16)
StudUi.AddSurface(body, 4, 16)

local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 102)
header.BackgroundColor3 = INDEX_COLOR
header.BorderSizePixel = 0
header.ZIndex = 8
header.Parent = panel
addCorner(header, 20)
addStroke(header, 5)
StudUi.AddSurface(header, 9, 20)

local headerIcon = Instance.new("ImageLabel")
headerIcon.Name = "IndexIcon"
headerIcon.AnchorPoint = Vector2.new(0.5, 0.5)
headerIcon.Position = UDim2.fromOffset(68, 51)
headerIcon.Size = UDim2.fromOffset(78, 78)
headerIcon.BackgroundTransparency = 1
headerIcon.Image = INDEX_ICON
headerIcon.ScaleType = Enum.ScaleType.Fit
headerIcon.ZIndex = 12
headerIcon.Parent = header

local title = Instance.new("TextLabel")
title.Name = "Title"
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(116, 8)
title.Size = UDim2.new(1, -225, 1, -16)
title.Font = Enum.Font.FredokaOne
title.Text = "Index"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextSize = 58
title.TextXAlignment = Enum.TextXAlignment.Left
title.ZIndex = 12
title.Parent = header
addTextStroke(title, 5)

local closeButton = Instance.new("TextButton")
closeButton.Name = "Close"
closeButton.AnchorPoint = Vector2.new(0.5, 0.5)
closeButton.Position = UDim2.new(1, -51, 0.5, 0)
closeButton.Size = UDim2.fromOffset(72, 72)
closeButton.BackgroundColor3 = Color3.fromRGB(255, 42, 48)
closeButton.BorderSizePixel = 0
closeButton.Font = Enum.Font.FredokaOne
closeButton.Text = "X"
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.TextSize = 47
closeButton.ZIndex = 13
closeButton.Parent = header
addCorner(closeButton, 14)
addStroke(closeButton, 4, Color3.fromRGB(90, 0, 5))
StudUi.StyleButton(closeButton, 14)

local subtitle = Instance.new("TextLabel")
subtitle.Name = "Subtitle"
subtitle.BackgroundTransparency = 1
subtitle.Position = UDim2.fromOffset(32, 114)
subtitle.Size = UDim2.new(1, -64, 0, 42)
subtitle.Font = Enum.Font.FredokaOne
subtitle.Text = "Your Unlocked Skins"
subtitle.TextColor3 = INDEX_DARK
subtitle.TextSize = 31
subtitle.ZIndex = 7
subtitle.Parent = panel
addTextStroke(subtitle, 2)

local status = Instance.new("TextLabel")
status.Name = "Status"
status.BackgroundTransparency = 1
status.Position = UDim2.new(0, 30, 1, -48)
status.Size = UDim2.new(1, -60, 0, 34)
status.Font = Enum.Font.FredokaOne
status.Text = ""
status.TextColor3 = Color3.fromRGB(55, 55, 65)
status.TextSize = 22
status.ZIndex = 8
status.Parent = panel

local scrolling = Instance.new("ScrollingFrame")
scrolling.Name = "SkinCards"
scrolling.Position = UDim2.fromOffset(28, 158)
scrolling.Size = UDim2.new(1, -56, 1, -220)
scrolling.BackgroundTransparency = 1
scrolling.BorderSizePixel = 0
scrolling.CanvasSize = UDim2.fromOffset(0, 0)
scrolling.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrolling.ScrollBarThickness = 8
scrolling.ScrollBarImageColor3 = INDEX_DARK
scrolling.ZIndex = 7
scrolling.Parent = panel

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 8)
padding.PaddingBottom = UDim.new(0, 8)
padding.PaddingLeft = UDim.new(0, 8)
padding.PaddingRight = UDim.new(0, 8)
padding.Parent = scrolling

local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.fromOffset(360, 292)
grid.CellPadding = UDim2.fromOffset(20, 18)
grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
grid.SortOrder = Enum.SortOrder.LayoutOrder
grid.Parent = scrolling

local emptyLabel = Instance.new("TextLabel")
emptyLabel.Name = "Empty"
emptyLabel.BackgroundTransparency = 1
emptyLabel.Position = UDim2.fromOffset(92, 210)
emptyLabel.Size = UDim2.new(1, -184, 0, 190)
emptyLabel.Font = Enum.Font.FredokaOne
emptyLabel.Text = "Evolve a suit to unlock it here."
emptyLabel.TextColor3 = Color3.fromRGB(35, 35, 45)
emptyLabel.TextSize = 31
emptyLabel.TextWrapped = true
emptyLabel.ZIndex = 8
emptyLabel.Visible = false
emptyLabel.Parent = panel
addTextStroke(emptyLabel, 2)

local currentState = {
	Skins = {},
	Owned = {},
	EquippedSkin = "",
}

local renderState

local function makeSkinCard(entry, order)
	local card = Instance.new("Frame")
	card.Name = tostring(entry.Id) .. "Card"
	card.LayoutOrder = order
	card.BackgroundColor3 = order % 2 == 1
		and Color3.fromRGB(25, 210, 255)
		or Color3.fromRGB(255, 76, 218)
	card.BorderSizePixel = 0
	card.ZIndex = 8
	card.Parent = scrolling
	addCorner(card, 16)
	addStroke(card, 4)
	StudUi.AddSurface(card, 9, 16)

	local previewBox = Instance.new("Frame")
	previewBox.Name = "PreviewBox"
	previewBox.Position = UDim2.fromOffset(14, 14)
	previewBox.Size = UDim2.new(1, -28, 0, 168)
	previewBox.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	previewBox.BorderSizePixel = 0
	previewBox.ZIndex = 11
	previewBox.Parent = card
	addCorner(previewBox, 12)
	addStroke(previewBox, 3)
	StudUi.AddSurface(previewBox, 12, 12)

	local preview = Instance.new("ImageLabel")
	preview.Name = "Preview"
	preview.AnchorPoint = Vector2.new(0.5, 0.5)
	preview.Position = UDim2.fromScale(0.5, 0.5)
	preview.Size = UDim2.fromOffset(146, 146)
	preview.BackgroundTransparency = 1
	preview.Image = "rbxthumb://type=Asset&id="
		.. tostring(entry.PreviewAssetId or 0)
		.. "&w=420&h=420"
	preview.ScaleType = Enum.ScaleType.Fit
	preview.ZIndex = 14
	preview.Parent = previewBox

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "SkinName"
	nameLabel.BackgroundTransparency = 1
	nameLabel.Position = UDim2.fromOffset(10, 184)
	nameLabel.Size = UDim2.new(1, -20, 0, 42)
	nameLabel.Font = Enum.Font.FredokaOne
	nameLabel.Text = tostring(entry.DisplayName or entry.Id)
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextScaled = true
	nameLabel.ZIndex = 14
	nameLabel.Parent = card
	local nameConstraint = Instance.new("UITextSizeConstraint")
	nameConstraint.MinTextSize = 18
	nameConstraint.MaxTextSize = 31
	nameConstraint.Parent = nameLabel
	addTextStroke(nameLabel, 3)

	local equipped = currentState.EquippedSkin == entry.Id
	local button = Instance.new("TextButton")
	button.Name = "Equip"
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Position = UDim2.new(0.5, 0, 1, -33)
	button.Size = UDim2.new(1, -44, 0, 50)
	button.BackgroundColor3 = equipped and EQUIPPED_COLOR or EQUIP_COLOR
	button.BorderSizePixel = 0
	button.Font = Enum.Font.FredokaOne
	button.Text = equipped and "Equipped" or "Equip"
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextSize = 27
	button.AutoButtonColor = not equipped
	button.Active = not equipped
	button.ZIndex = 14
	button.Parent = card
	addCorner(button, 11)
	addStroke(button, 3)
	StudUi.StyleButton(button, 11)

	if not equipped then
		button.Activated:Connect(function()
			                                                                    
			                                                                     
			playEquipSound()
			currentState.EquippedSkin = entry.Id
			status.Text = "Equipping..."
			renderState()
			requestRemote:FireServer("Equip", entry.Id)
		end)
	end
end

renderState = function()
	for _, child in ipairs(scrolling:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	local shown = 0
	for index, entry in ipairs(currentState.Skins or {}) do
		if type(entry) == "table" and currentState.Owned[entry.Id] == true then
			shown += 1
			makeSkinCard(entry, index)
		end
	end

	emptyLabel.Visible = shown == 0
end

local isOpen = false
local activeTween
local dimTween

local function stopTweens()
	if activeTween then
		activeTween:Cancel()
		activeTween = nil
	end
	if dimTween then
		dimTween:Cancel()
		dimTween = nil
	end
end

local function closePanel()
	if not isOpen then
		return
	end
	isOpen = false
	stopTweens()
	activeTween = TweenService:Create(
		panel,
		TweenInfo.new(0.21, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{Position = CLOSED_POSITION}
	)
	dimTween = TweenService:Create(dim, TweenInfo.new(0.16), {
		BackgroundTransparency = 1,
	})
	activeTween:Play()
	dimTween:Play()
	activeTween.Completed:Once(function()
		if not isOpen then
			panel.Visible = false
			dim.Visible = false
		end
	end)
end

local function openPanel()
	isOpen = true
	stopTweens()
	panel.Visible = true
	dim.Visible = true
	panel.Position = CLOSED_POSITION
	dim.BackgroundTransparency = 1
	requestRemote:FireServer("RequestState")
	activeTween = TweenService:Create(
		panel,
		TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{Position = OPEN_POSITION}
	)
	dimTween = TweenService:Create(dim, TweenInfo.new(0.18), {
		BackgroundTransparency = 0.42,
	})
	activeTween:Play()
	dimTween:Play()
end

local function updateScale()
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
	local inset = GuiService:GetGuiInset()
	local available = Vector2.new(viewport.X, math.max(1, viewport.Y - inset.Y))
	local mobileExtra = UserInputService.TouchEnabled and 0.92 or 1
	panelScale.Scale = math.clamp(
		math.min(available.X / 930, available.Y / 635) * mobileExtra,
		0.48,
		1.08
	)
end

updateRemote.OnClientEvent:Connect(function(data)
	if type(data) ~= "table" then
		return
	end
	currentState.Skins = type(data.Skins) == "table" and data.Skins or {}
	currentState.Owned = type(data.Owned) == "table" and data.Owned or {}
	currentState.EquippedSkin = tostring(data.EquippedSkin or "")
	status.Text = tostring(data.Message or "")
	renderState()

	                                                                     
	                                                         
end)

openIndexPanel.Event:Connect(openPanel)
MenuEvents.CloseAll.Event:Connect(closePanel)
MenuEvents.MarkReady("Index", function()
	return isOpen
end)
for _, event in ipairs(otherOpenEvents) do
	event.Event:Connect(function()
		if isOpen then
			closePanel()
		end
	end)
end

closeButton.Activated:Connect(closePanel)
dim.Activated:Connect(closePanel)

updateScale()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end

player.CharacterAdded:Connect(function()
	task.defer(function()
		if screenGui.Parent ~= playerGui then
			screenGui.Parent = playerGui
		end
	end)
end)

requestRemote:FireServer("RequestState")

print("[IndexPanel] V305 loaded. Index Equip responds immediately and uses the exact Evolve sound.")
