local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local MenuEvents = require(ReplicatedStorage.Shared:WaitForChild("MenuEvents"))

local player = Players.LocalPlayer
local UpdateLogClosed = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("UpdateLogClosed")
local playerGui = player:WaitForChild("PlayerGui")
local gui = playerGui:WaitForChild("Update Logs")
local titleFrame = gui:WaitForChild("Title")
local closeButton = titleFrame:WaitForChild("Close")

local camera = Workspace.CurrentCamera or Workspace:WaitForChild("Camera")

-- Ensure Title background, stroke, and textured background match standard menu styling
titleFrame.BackgroundColor3 = Color3.fromRGB(20, 24, 35)
titleFrame.BackgroundTransparency = 0.15
local stroke = titleFrame:FindFirstChildOfClass("UIStroke")
if not stroke then
	stroke = Instance.new("UIStroke")
	stroke.Parent = titleFrame
end
stroke.Color = Color3.fromRGB(0, 0, 0)
stroke.Thickness = 2
stroke.Transparency = 0
stroke.Enabled = true

local bgImage = titleFrame:FindFirstChild("Background")
if bgImage and bgImage:IsA("ImageLabel") then
	bgImage.ImageTransparency = 0.15
	bgImage.BackgroundTransparency = 1
end

-- Ensure Close button is responsive and visible above all layers
closeButton.Active = true
closeButton.ZIndex = math.max(closeButton.ZIndex, 15)

-- Adjust right-side update banner & codes layout so codes are comfortably inside the modal
local rightFrame = titleFrame:FindFirstChild("Update")
if rightFrame and rightFrame:IsA("Frame") then
	local img = rightFrame:FindFirstChildOfClass("ImageLabel")
	local updateLabel = rightFrame:FindFirstChild("Update")
	local codeLabel = rightFrame:FindFirstChild("Code")
	local tittle = rightFrame:FindFirstChild("Tittle")
	if tittle and tittle:IsA("TextLabel") and tittle.Text == "Ultra" then
		tittle.Visible = false
	end
	if img then
		img.Position = UDim2.new(img.Position.X.Scale, img.Position.X.Offset, 0.300, 0)
	end
	if updateLabel and updateLabel:IsA("TextLabel") then
		updateLabel.Position = UDim2.new(updateLabel.Position.X.Scale, updateLabel.Position.X.Offset, 0.590, 0)
	end
	if codeLabel and codeLabel:IsA("TextLabel") then
		codeLabel.Position = UDim2.new(codeLabel.Position.X.Scale, codeLabel.Position.X.Offset, 0.780, 0)
	end
end

local function configureScrollingFrame()
	local scroll = titleFrame:FindFirstChildWhichIsA("ScrollingFrame")
	if not scroll then
		for _, child in ipairs(gui:GetChildren()) do
			if child:IsA("ScrollingFrame") then
				scroll = child
				break
			end
		end
	end

	if scroll then
		scroll.AnchorPoint = Vector2.new(0.5, 0.5)
		scroll.Position = UDim2.new(0.322037, 0, 0.558447, 0)
		scroll.Size = UDim2.new(0.49, 0, 0.58, 0)
		scroll.Parent = titleFrame

		local scrollAr = scroll:FindFirstChildOfClass("UIAspectRatioConstraint")
		if scrollAr then
			scrollAr:Destroy()
		end

		scroll.Active = true
		scroll.Selectable = true
		scroll.ScrollingEnabled = true
		scroll.ScrollingDirection = Enum.ScrollingDirection.Y
		scroll.ScrollBarThickness = 8
		scroll.ScrollBarImageTransparency = 0
		scroll.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
		scroll.VerticalScrollBarPosition = Enum.VerticalScrollBarPosition.Right
		scroll.ElasticBehavior = Enum.ElasticBehavior.Always
		scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
		scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
		scroll.ZIndex = 5

		local textLabel = scroll:FindFirstChildOfClass("TextLabel")
		if textLabel then
			textLabel.Active = false
			textLabel.Selectable = false
			textLabel.TextScaled = false
			textLabel.TextWrapped = true
			textLabel.TextSize = 14
			textLabel.LineHeight = 1.15
			textLabel.TextXAlignment = Enum.TextXAlignment.Left
			textLabel.TextYAlignment = Enum.TextYAlignment.Top
			textLabel.AnchorPoint = Vector2.new(0, 0)
			textLabel.Position = UDim2.new(0, 4, 0, 4)
			textLabel.Size = UDim2.new(1, -12, 0, 0)
			textLabel.AutomaticSize = Enum.AutomaticSize.Y
			textLabel.ZIndex = 6

			local padding = textLabel:FindFirstChildOfClass("UIPadding")
			if not padding then
				padding = Instance.new("UIPadding")
				padding.Parent = textLabel
			end
			padding.PaddingTop = UDim.new(0, 4)
			padding.PaddingBottom = UDim.new(0, 36)
			padding.PaddingLeft = UDim.new(0, 6)
			padding.PaddingRight = UDim.new(0, 6)
		end
	end
	return scroll
end

local scrollFrame = configureScrollingFrame()

local OPEN_POS = titleFrame.Position
local CLOSED_POS = UDim2.new(OPEN_POS.X.Scale, OPEN_POS.X.Offset, 1.35, 0)

-- Animation configurations identical to Shop
local OPEN_TWEEN_INFO = TweenInfo.new(
	0.24,
	Enum.EasingStyle.Back,
	Enum.EasingDirection.Out
)

local CLOSE_TWEEN_INFO = TweenInfo.new(
	0.18,
	Enum.EasingStyle.Quad,
	Enum.EasingDirection.In
)

local isOpen = false
local currentTween: Tween? = nil

local function closePanel()
	if not isOpen then
		return
	end
	isOpen = false

	if currentTween then
		currentTween:Cancel()
		currentTween = nil
	end

	-- Smooth slide down animation
	currentTween = TweenService:Create(titleFrame, CLOSE_TWEEN_INFO, { Position = CLOSED_POS })
	currentTween:Play()

	task.spawn(function()
		currentTween.Completed:Wait()
		if not isOpen then
			gui.Enabled = false
			titleFrame.Visible = false
			titleFrame.Position = CLOSED_POS
		end
	end)

	pcall(function()
		UpdateLogClosed:FireServer()
	end)
end

local function openPanel()
	if isOpen then
		return
	end
	isOpen = true

	if currentTween then
		currentTween:Cancel()
		currentTween = nil
	end

	gui.Enabled = true
	titleFrame.Visible = true
	titleFrame.Position = CLOSED_POS

	local scroll = configureScrollingFrame()
	if scroll then
		scroll.CanvasPosition = Vector2.new(0, 0)
	end

	-- Smooth bounce-in animation identical to Shop
	currentTween = TweenService:Create(titleFrame, OPEN_TWEEN_INFO, { Position = OPEN_POS })
	currentTween:Play()
end

-- Multi-touch and click listeners on Close button
closeButton.Activated:Connect(closePanel)
if closeButton:IsA("GuiButton") then
	closeButton.MouseButton1Click:Connect(closePanel)
end
closeButton.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		closePanel()
	end
end)

-- Global menu events
MenuEvents.Get("OpenUpdateLogsPanel").Event:Connect(function(action)
	if action == "Close" then
		closePanel()
	elseif action == "Open" then
		openPanel()
	else
		if isOpen then
			closePanel()
		else
			openPanel()
		end
	end
end)
MenuEvents.CloseAll.Event:Connect(closePanel)
MenuEvents.MarkReady("UpdateLogs", function()
	return isOpen
end)

-- Start with the panel smoothly opening on spawn/join
task.defer(function()
	task.wait(0.25)
	openPanel()
end)