                                                                

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local OWNER_USER_ID = 5113549114
if player.UserId ~= OWNER_USER_ID then
	return
end

local StudUi = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("StudUi"))
local adminRemote = ReplicatedStorage
	:WaitForChild("Remotes")
	:WaitForChild("OwnerAdminPanel")
local playerGui = player:WaitForChild("PlayerGui")

local oldGui = playerGui:FindFirstChild("OwnerAdminPanelV306GY")
if oldGui then
	oldGui:Destroy()
end

local COLORS = {
	Purple = Color3.fromRGB(176, 48, 255),
	PurpleDark = Color3.fromRGB(82, 17, 128),
	White = Color3.fromRGB(250, 250, 255),
	Ink = Color3.fromRGB(18, 18, 28),
	Green = Color3.fromRGB(80, 238, 65),
	Blue = Color3.fromRGB(30, 190, 255),
	Gold = Color3.fromRGB(255, 198, 25),
	Red = Color3.fromRGB(255, 70, 70),
	Gray = Color3.fromRGB(61, 64, 78),
}

local TREADMILLS = {
	{ Name = "Treadmill1_basic", Label = "BROWN\nBASIC", Color = Color3.fromRGB(153, 88, 38) },
	{ Name = "Treadmill2_fast", Label = "GOLD\nFAST", Color = Color3.fromRGB(255, 188, 22) },
	{ Name = "Treadmill3_superfast", Label = "BLUE\nSUPER", Color = Color3.fromRGB(24, 166, 255) },
	{ Name = "Treadmill4_hyperspeed", Label = "PINK\nHYPER", Color = Color3.fromRGB(255, 58, 192) },
	{ Name = "Treadmill5_insanespeed", Label = "RED\nADMIN", Color = Color3.fromRGB(255, 47, 47) },
}

local clickSound = SoundService:FindFirstChild("SpeedsterUiClickSound")
if not clickSound then
	clickSound = Instance.new("Sound")
	clickSound.Name = "SpeedsterUiClickSound"
	clickSound.SoundId = "rbxassetid://72264591133889"
	clickSound.Volume = 0.65
	clickSound.Parent = SoundService
end

local function playClick()
	clickSound.TimePosition = 0
	clickSound:Play()
end

local function addCorner(object, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = object
	return corner
end

local function addStroke(object, color, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Color3.new(0, 0, 0)
	stroke.Thickness = thickness or 3
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = object
	return stroke
end

local function makeLabel(parent, name, text, position, size, textSize, color, zIndex)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextColor3 = color or COLORS.Ink
	label.TextSize = textSize or 22
	label.TextScaled = false
	label.TextWrapped = true
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 0
	label.ZIndex = zIndex or 5
	label.Parent = parent
	return label
end

local function makeButton(parent, name, text, color, position, size, zIndex)
	local button = Instance.new("TextButton")
	button.Name = name
	button.AutoButtonColor = false
	button.BackgroundColor3 = color
	button.BorderSizePixel = 0
	button.Position = position
	button.Size = size
	button.Font = Enum.Font.FredokaOne
	button.Text = text
	button.TextColor3 = Color3.new(1, 1, 1)
	button.TextSize = 20
	button.TextScaled = false
	button.TextWrapped = true
	button.ZIndex = zIndex or 5
	button.Parent = parent
	addCorner(button, 11)
	addStroke(button, Color3.new(0, 0, 0), 3)
	StudUi.StyleButton(button, 11)

	button.MouseEnter:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.11), {
			Rotation = 2,
			BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), 0.12),
		}):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.11), {
			Rotation = 0,
			BackgroundColor3 = color,
		}):Play()
	end)
	button.Activated:Connect(playClick)
	return button
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "OwnerAdminPanelV306GY"
screenGui.DisplayOrder = 120
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local dim = Instance.new("TextButton")
dim.Name = "Dim"
dim.AutoButtonColor = false
dim.BackgroundColor3 = Color3.new(0, 0, 0)
dim.BackgroundTransparency = 0.42
dim.BorderSizePixel = 0
dim.Size = UDim2.fromScale(1, 1)
dim.Text = ""
dim.Visible = false
dim.ZIndex = 1
dim.Parent = screenGui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.BackgroundColor3 = COLORS.White
panel.BorderSizePixel = 0
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(760, 610)
panel.Visible = false
panel.ZIndex = 2
panel.Parent = screenGui
addCorner(panel, 18)
addStroke(panel, Color3.new(0, 0, 0), 5)
StudUi.AddSurface(panel, 3, 18, 12, 10)

local panelScale = Instance.new("UIScale")
panelScale.Name = "ResponsiveScale"
panelScale.Parent = panel

local header = Instance.new("Frame")
header.Name = "Header"
header.BackgroundColor3 = COLORS.Purple
header.BorderSizePixel = 0
header.Size = UDim2.new(1, 0, 0, 94)
header.ZIndex = 4
header.Parent = panel
addCorner(header, 17)
StudUi.AddSurface(header, 5, 17, 12, 2)

local headerCover = Instance.new("Frame")
headerCover.BackgroundColor3 = COLORS.Purple
headerCover.BorderSizePixel = 0
headerCover.Position = UDim2.new(0, 0, 1, -18)
headerCover.Size = UDim2.new(1, 0, 0, 18)
headerCover.ZIndex = 4
headerCover.Parent = header

makeLabel(
	header,
	"Title",
	"OWNER PANEL",
	UDim2.fromOffset(26, 10),
	UDim2.new(1, -124, 1, -20),
	42,
	Color3.new(1, 1, 1),
	7
).TextXAlignment = Enum.TextXAlignment.Left

local closeButton = makeButton(
	header,
	"Close",
	"X",
	COLORS.Red,
	UDim2.new(1, -77, 0, 16),
	UDim2.fromOffset(58, 58),
	7
)
closeButton.TextSize = 33

local content = Instance.new("Frame")
content.Name = "Content"
content.BackgroundTransparency = 1
content.Position = UDim2.fromOffset(20, 105)
content.Size = UDim2.new(1, -40, 1, -122)
content.ZIndex = 4
content.Parent = panel

local treadmillCard = Instance.new("Frame")
treadmillCard.Name = "TreadmillCard"
treadmillCard.BackgroundColor3 = Color3.fromRGB(239, 225, 255)
treadmillCard.BorderSizePixel = 0
treadmillCard.Position = UDim2.fromOffset(0, 0)
treadmillCard.Size = UDim2.new(1, 0, 0, 172)
treadmillCard.ZIndex = 4
treadmillCard.Parent = content
addCorner(treadmillCard, 14)
addStroke(treadmillCard, Color3.new(0, 0, 0), 3)

local treadmillTitle = makeLabel(
	treadmillCard,
	"Title",
	"SPAWN TREADMILL UNDER ME",
	UDim2.fromOffset(15, 7),
	UDim2.new(1, -30, 0, 32),
	25,
	COLORS.PurpleDark,
	6
)
treadmillTitle.TextStrokeTransparency = 1
treadmillTitle.TextXAlignment = Enum.TextXAlignment.Left

local treadmillButtonsFrame = Instance.new("Frame")
treadmillButtonsFrame.Name = "Buttons"
treadmillButtonsFrame.BackgroundTransparency = 1
treadmillButtonsFrame.Position = UDim2.fromOffset(10, 55)
treadmillButtonsFrame.Size = UDim2.new(1, -20, 0, 105)
treadmillButtonsFrame.ZIndex = 5
treadmillButtonsFrame.Parent = treadmillCard

local treadmillGrid = Instance.new("UIGridLayout")
treadmillGrid.CellSize = UDim2.fromOffset(128, 105)
treadmillGrid.CellPadding = UDim2.fromOffset(11, 0)
treadmillGrid.FillDirectionMaxCells = 5
treadmillGrid.HorizontalAlignment = Enum.HorizontalAlignment.Center
treadmillGrid.VerticalAlignment = Enum.VerticalAlignment.Bottom
treadmillGrid.SortOrder = Enum.SortOrder.LayoutOrder
treadmillGrid.Parent = treadmillButtonsFrame

for index, entry in ipairs(TREADMILLS) do
	local button = makeButton(
		treadmillButtonsFrame,
		entry.Name,
		entry.Label,
		entry.Color,
		UDim2.fromOffset(0, 0),
		UDim2.fromOffset(128, 105),
		6
	)
	button.LayoutOrder = index
	button.TextSize = 18
	button.Activated:Connect(function()
		adminRemote:FireServer({
			Action = "SpawnTreadmill",
			Treadmill = entry.Name,
		})
	end)
end

local grantsCard = Instance.new("Frame")
grantsCard.Name = "GrantsCard"
grantsCard.BackgroundColor3 = Color3.fromRGB(222, 247, 255)
grantsCard.BorderSizePixel = 0
grantsCard.Position = UDim2.fromOffset(0, 186)
grantsCard.Size = UDim2.new(1, 0, 0, 221)
grantsCard.ZIndex = 4
grantsCard.Parent = content
addCorner(grantsCard, 14)
addStroke(grantsCard, Color3.new(0, 0, 0), 3)

local grantsTitle = makeLabel(
	grantsCard,
	"Title",
	"EXACT GRANT  •  GLOBAL = EVERY PLAYER ONLINE",
	UDim2.fromOffset(15, 6),
	UDim2.new(1, -30, 0, 30),
	22,
	Color3.fromRGB(0, 92, 135),
	6
)
grantsTitle.TextStrokeTransparency = 1
grantsTitle.TextXAlignment = Enum.TextXAlignment.Left

local amountBox = Instance.new("TextBox")
amountBox.Name = "Amount"
amountBox.BackgroundColor3 = Color3.new(1, 1, 1)
amountBox.BorderSizePixel = 0
amountBox.ClearTextOnFocus = false
amountBox.Font = Enum.Font.FredokaOne
amountBox.PlaceholderText = "AMOUNT  (EXAMPLE: 50000, 2M, 1e15)"
amountBox.PlaceholderColor3 = Color3.fromRGB(105, 105, 118)
amountBox.Position = UDim2.fromOffset(14, 41)
amountBox.Size = UDim2.new(1, -28, 0, 48)
amountBox.Text = ""
amountBox.TextColor3 = COLORS.Ink
amountBox.TextSize = 20
amountBox.TextXAlignment = Enum.TextXAlignment.Left
amountBox.ZIndex = 6
amountBox.Parent = grantsCard
addCorner(amountBox, 10)
addStroke(amountBox, Color3.new(0, 0, 0), 3)

local amountPadding = Instance.new("UIPadding")
amountPadding.PaddingLeft = UDim.new(0, 14)
amountPadding.PaddingRight = UDim.new(0, 14)
amountPadding.Parent = amountBox

local grantButtons = {
	{ Name = "ServerSpeed", Text = "SERVER\nSPEED", Color = COLORS.Blue, Scope = "Server", Stat = "Speed" },
	{ Name = "ServerWins", Text = "SERVER\nWINS", Color = COLORS.Gold, Scope = "Server", Stat = "Wins" },
	{ Name = "GlobalSpeed", Text = "GLOBAL ONLINE\nSPEED", Color = COLORS.Purple, Scope = "Global", Stat = "Speed" },
	{ Name = "GlobalWins", Text = "GLOBAL ONLINE\nWINS", Color = Color3.fromRGB(255, 128, 25), Scope = "Global", Stat = "Wins" },
}

for index, entry in ipairs(grantButtons) do
	local column = (index - 1) % 2
	local row = math.floor((index - 1) / 2)
	local button = makeButton(
		grantsCard,
		entry.Name,
		entry.Text,
		entry.Color,
		UDim2.new(column * 0.5, 14 + column * 6, 0, 101 + row * 57),
		UDim2.new(0.5, -20, 0, 48),
		6
	)
	button.TextSize = 18
	button.Activated:Connect(function()
		adminRemote:FireServer({
			Action = "Grant",
			Scope = entry.Scope,
			Stat = entry.Stat,
			Amount = amountBox.Text,
		})
	end)
end

local flyButton = makeButton(
	content,
	"Fly",
	"FLY: OFF",
	COLORS.Gray,
	UDim2.fromOffset(0, 421),
	UDim2.new(0, 220, 0, 57),
	6
)
flyButton.TextSize = 24

local status = makeLabel(
	content,
	"Status",
	"Type /panel or ?panel to reopen",
	UDim2.fromOffset(237, 421),
	UDim2.new(1, -237, 0, 57),
	19,
	COLORS.Ink,
	6
)
status.BackgroundColor3 = Color3.fromRGB(245, 245, 250)
status.BackgroundTransparency = 0
status.TextStrokeTransparency = 1
addCorner(status, 11)
addStroke(status, Color3.new(0, 0, 0), 3)

local isOpen = false
local flying = false

local function updateFlyButton()
	flyButton.Text = flying and "FLY: ON" or "FLY: OFF"
	flyButton.BackgroundColor3 = flying and COLORS.Green or COLORS.Gray
end

local function resizePanel()
	local camera = Workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
	local fit = math.min((viewport.X - 24) / 760, (viewport.Y - 24) / 610, 1)
	panelScale.Scale = math.max(0.32, fit)
end

local cameraConnection
local function bindCamera()
	if cameraConnection then
		cameraConnection:Disconnect()
	end
	local camera = Workspace.CurrentCamera
	if camera then
		cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(resizePanel)
	end
	resizePanel()
end
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)
bindCamera()

local function setPanelOpen(open)
	isOpen = open == true
	if not isOpen then
		panel.Visible = false
		dim.Visible = false
		return
	end

	dim.Visible = true
	panel.Visible = true
	panelScale.Scale *= 0.90
	local targetScale = math.max(0.32, math.min(
		((Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize.X or 1280) - 24) / 760,
		((Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize.Y or 720) - 24) / 610,
		1
	))
	TweenService:Create(
		panelScale,
		TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = targetScale }
	):Play()
	adminRemote:FireServer({ Action = "GetState" })
end

closeButton.Activated:Connect(function()
	setPanelOpen(false)
end)
dim.Activated:Connect(function()
	setPanelOpen(false)
end)
flyButton.Activated:Connect(function()
	adminRemote:FireServer({
		Action = "SetFly",
		Enabled = not flying,
	})
end)

                                                                          
                                                                  
local FLIGHT_BIND = "SpeedsterOwnerFlightV306GY"
local FLIGHT_SPEED = 92
local FLIGHT_FAST_SPEED = 165
local verticalInput = 0
local flightAttachment
local flightVelocity
local flightOrientation
local flightHumanoid
local flightRoot

local function clearFlightObjects()
	RunService:UnbindFromRenderStep(FLIGHT_BIND)
	if flightVelocity then
		flightVelocity:Destroy()
	end
	if flightOrientation then
		flightOrientation:Destroy()
	end
	if flightAttachment then
		flightAttachment:Destroy()
	end
	if flightHumanoid and flightHumanoid.Parent then
		flightHumanoid.AutoRotate = true
	end
	if flightRoot and flightRoot.Parent then
		flightRoot.AssemblyLinearVelocity = Vector3.zero
		flightRoot.AssemblyAngularVelocity = Vector3.zero
	end
	flightAttachment = nil
	flightVelocity = nil
	flightOrientation = nil
	flightHumanoid = nil
	flightRoot = nil
end

local function beginFlightForCharacter(character)
	clearFlightObjects()
	if player:GetAttribute("AdminFlying") ~= true or player.UserId ~= OWNER_USER_ID then
		return
	end

	local humanoid = character:WaitForChild("Humanoid", 10)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not humanoid or not root or humanoid.Health <= 0 then
		return
	end

	flightHumanoid = humanoid
	flightRoot = root
	humanoid.AutoRotate = false

	flightAttachment = Instance.new("Attachment")
	flightAttachment.Name = "OwnerFlightAttachmentV306GY"
	flightAttachment.Parent = root

	flightVelocity = Instance.new("LinearVelocity")
	flightVelocity.Name = "OwnerFlightVelocityV306GY"
	flightVelocity.Attachment0 = flightAttachment
	flightVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	flightVelocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	flightVelocity.ForceLimitsEnabled = false
	flightVelocity.VectorVelocity = Vector3.zero
	flightVelocity.Parent = root

	flightOrientation = Instance.new("AlignOrientation")
	flightOrientation.Name = "OwnerFlightOrientationV306GY"
	flightOrientation.Attachment0 = flightAttachment
	flightOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	flightOrientation.RigidityEnabled = false
	flightOrientation.Responsiveness = 35
	flightOrientation.MaxTorque = math.huge
	flightOrientation.MaxAngularVelocity = math.huge
	flightOrientation.Parent = root

	RunService:BindToRenderStep(FLIGHT_BIND, Enum.RenderPriority.Character.Value + 20, function()
		if player:GetAttribute("AdminFlying") ~= true
			or player.Character ~= character
			or humanoid.Health <= 0
			or not root.Parent
		then
			clearFlightObjects()
			return
		end

		local camera = Workspace.CurrentCamera
		local movement = humanoid.MoveDirection
		local vertical = verticalInput
		local speed = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
			and FLIGHT_FAST_SPEED or FLIGHT_SPEED
		local direction = movement + Vector3.new(0, vertical, 0)
		if direction.Magnitude > 1 then
			direction = direction.Unit
		end
		flightVelocity.VectorVelocity = direction * speed

		local look = camera and camera.CFrame.LookVector or root.CFrame.LookVector
		local flatLook = Vector3.new(look.X, 0, look.Z)
		if flatLook.Magnitude <= 0.001 then
			flatLook = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
		end
		if flatLook.Magnitude > 0.001 then
			flightOrientation.CFrame = CFrame.lookAt(Vector3.zero, flatLook.Unit)
		end
		root.AssemblyAngularVelocity = Vector3.zero
	end)
end

local function refreshFlight()
	flying = player:GetAttribute("AdminFlying") == true
	updateFlyButton()
	if flying and player.Character then
		task.defer(beginFlightForCharacter, player.Character)
	else
		clearFlightObjects()
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.Space then
		verticalInput = 1
	elseif input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.C then
		verticalInput = -1
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.Space and verticalInput > 0 then
		verticalInput = 0
	elseif (input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.C)
		and verticalInput < 0
	then
		verticalInput = 0
	end
end)

player:GetAttributeChangedSignal("AdminFlying"):Connect(refreshFlight)
player.CharacterAdded:Connect(function(character)
	if player:GetAttribute("AdminFlying") == true then
		task.defer(beginFlightForCharacter, character)
	end
end)
player.CharacterRemoving:Connect(clearFlightObjects)

adminRemote.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then
		return
	end
	if payload.Type == "Open" then
		flying = payload.Flying == true
		updateFlyButton()
		setPanelOpen(true)
	elseif payload.Type == "State" or payload.Type == "FlyState" then
		flying = payload.Flying == true
		updateFlyButton()
	elseif payload.Type == "Result" then
		status.Text = tostring(payload.Message or "")
		status.TextColor3 = payload.Ok == true and Color3.fromRGB(20, 145, 28) or COLORS.Red
	end
end)

refreshFlight()
adminRemote:FireServer({ Action = "GetState" })

print("[OwnerAdminPanel] V306GY client ready for UserId 5113549114. Use /panel or ?panel; flight W/A/S/D + Space/Ctrl, Shift fast.")
