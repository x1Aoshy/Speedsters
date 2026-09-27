                                                         
                                                                          
                                                                       
                                                                             
                                                                       

local ContentProvider = game:GetService("ContentProvider")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

if Config.IsWorld2Place == true then
	return
end

local Catalog = require(Shared:WaitForChild("PlaytimeRewards"))
local DailyRewards = require(Shared:WaitForChild("DailyRewards"))
local MenuEvents = require(Shared:WaitForChild("MenuEvents"))
local PurchaseButtonSound = require(Shared:WaitForChild("PurchaseButtonSound"))
local StudUi = require(Shared:WaitForChild("StudUi"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local PlaytimeRequest = Remotes:WaitForChild("PlaytimeRewardsRequest")
local PlaytimeUpdate = Remotes:WaitForChild("PlaytimeRewardsUpdate")
local CodesRequest = Remotes:WaitForChild("CodesRequest")
local CodesUpdate = Remotes:WaitForChild("CodesUpdate")

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 70, 70)),
	ColorSequenceKeypoint.new(0.16, Color3.fromRGB(255, 180, 45)),
	ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 240, 65)),
	ColorSequenceKeypoint.new(0.50, Color3.fromRGB(65, 235, 115)),
	ColorSequenceKeypoint.new(0.66, Color3.fromRGB(70, 210, 255)),
	ColorSequenceKeypoint.new(0.83, Color3.fromRGB(105, 90, 255)),
	ColorSequenceKeypoint.new(1.00, Color3.fromRGB(235, 65, 255)),
})

local GREY = Color3.fromRGB(130, 139, 151)
local CODES_CYAN = Color3.fromRGB(67, 215, 255)
local GREEN = Color3.fromRGB(70, 225, 85)
local CARD_BLUE = Color3.fromRGB(42, 151, 246)
local CARD_BLUE_READY = Color3.fromRGB(34, 177, 255)
local CARD_GREEN = Color3.fromRGB(52, 207, 92)
local CARD_FOOTER_BLUE = Color3.fromRGB(24, 93, 190)
local CARD_FOOTER_GREEN = Color3.fromRGB(27, 154, 65)
local RED = Color3.fromRGB(255, 70, 70)
local NOTIFICATION_IMAGE = "rbxassetid://76373998613283"

local rainbowGradients = {}

local function addCorner(instance, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 12)
	corner.Parent = instance
	return corner
end

local function addStroke(instance, thickness, color)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Color3.fromRGB(0, 0, 0)
	stroke.Thickness = thickness or 3
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = instance
	return stroke
end

local function makeText(parent, name, text, position, size, textSize, color, zIndex)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	label.TextSize = textSize or 28
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.ZIndex = zIndex or 10
	label.Parent = parent
	local stroke = addStroke(label, 3)
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	return label
end

local function addRainbowGradient(instance)
	local gradient = Instance.new("UIGradient")
	gradient.Color = RAINBOW
	gradient.Rotation = 0
	gradient.Parent = instance
	table.insert(rainbowGradients, gradient)
	return gradient
end

local function pressAnimation(target)
	local scale = target:FindFirstChild("PressScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Name = "PressScale"
		scale.Scale = 1
		scale.Parent = target
	end
	TweenService:Create(scale, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Scale = 0.94,
	}):Play()
	task.delay(0.07, function()
		if scale.Parent then
			TweenService:Create(scale, TweenInfo.new(0.11, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Scale = 1,
			}):Play()
		end
	end)
end

for _, oldName in ipairs({"PlaytimeRewardsAndCodesHUD", "PlaytimeRewardsAndCodesPanels"}) do
	local old = playerGui:FindFirstChild(oldName)
	if old then old:Destroy() end
end

local buttonGui = Instance.new("ScreenGui")
buttonGui.Name = "PlaytimeRewardsAndCodesHUD"
buttonGui.ResetOnSpawn = false
buttonGui.IgnoreGuiInset = true
buttonGui.DisplayOrder = 44
buttonGui.Parent = playerGui

local panelGui = Instance.new("ScreenGui")
panelGui.Name = "PlaytimeRewardsAndCodesPanels"
panelGui.ResetOnSpawn = false
panelGui.IgnoreGuiInset = true
panelGui.DisplayOrder = 61
panelGui.Enabled = true
panelGui.Parent = playerGui

local dim = Instance.new("Frame")
dim.Name = "Dim"
dim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
dim.BackgroundTransparency = 1
dim.BorderSizePixel = 0
dim.Size = UDim2.fromScale(1, 1)
dim.Visible = false
dim.ZIndex = 1
dim.Parent = panelGui

local function createRightButton(name, color, iconImage, lines, slotIndex, rainbow)
	local holder = Instance.new("Frame")
	holder.Name = name .. "Holder"
	holder.AnchorPoint = Vector2.new(1, 0.5)
	holder.Size = UDim2.fromOffset(330, 88)
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0
	holder:SetAttribute("StackSlot", slotIndex)
	holder.Parent = buttonGui

	local responsiveScale = Instance.new("UIScale")
	responsiveScale.Name = "ResponsiveScale"
	responsiveScale.Scale = 0.82
	responsiveScale.Parent = holder

	local button = Instance.new("ImageButton")
	button.Name = name .. "Button"
	button.Size = UDim2.fromScale(1, 1)
	button.BackgroundColor3 = rainbow and Color3.fromRGB(255, 255, 255) or color
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.ZIndex = 1
	button.Parent = holder
	addCorner(button, 14)
	addStroke(button, 3)

	local studSurface = StudUi.AddSurface(button, 2, 14, 8, 2)
	if rainbow then
		studSurface.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		local studGradient = studSurface:FindFirstChild("StudSurfaceGradient")
		if studGradient then
			studGradient.Color = RAINBOW
			table.insert(rainbowGradients, studGradient)
		end
		addRainbowGradient(button)
	end

	local icon = Instance.new("ImageLabel")
	icon.Name = name .. "BackgroundIcon"
	icon.BackgroundTransparency = 1
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.new(0.5, 0, 0.52, 0)
	icon.Size = UserInputService.TouchEnabled and UDim2.fromOffset(76, 76) or UDim2.fromOffset(108, 108)
	icon.Image = iconImage
	icon.ImageTransparency = 0.06
	icon.ScaleType = Enum.ScaleType.Fit
	icon.ZIndex = 3
	icon.Parent = button

	local titleGroup = Instance.new("Frame")
	titleGroup.Name = "TitleGroup"
	titleGroup.BackgroundTransparency = 1
	titleGroup.AnchorPoint = Vector2.new(0.5, 0.5)
	titleGroup.Position = UDim2.new(0.5, 0, 0.55, 0)
	titleGroup.Size = UDim2.new(0.86, 0, #lines > 1 and 0.72 or 0.84, 0)
	titleGroup.ZIndex = 5
	titleGroup.Parent = button

	for index, text in ipairs(lines) do
		local line = Instance.new("TextLabel")
		line.Name = "Line" .. tostring(index)
		line.BackgroundTransparency = 1
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.Position = UDim2.new(0.5, 0, #lines == 1 and 0.5 or (index == 1 and 0.28 or 0.74), 0)
		line.Size = UDim2.new(1, 0, #lines == 1 and 0.88 or 0.48, 0)
		line.Font = Enum.Font.FredokaOne
		line.Text = text
		line.TextColor3 = Color3.fromRGB(255, 255, 255)
		line.TextScaled = true
		line.TextWrapped = false
		line.ZIndex = 5
		line.Parent = titleGroup
		local constraint = Instance.new("UITextSizeConstraint")
		if #lines == 1 then
			constraint.MinTextSize = UserInputService.TouchEnabled and 16 or 60
			constraint.MaxTextSize = UserInputService.TouchEnabled and 42 or 133
		else
			constraint.MinTextSize = UserInputService.TouchEnabled and 8 or 22
			constraint.MaxTextSize = UserInputService.TouchEnabled and 17 or 38
		end
		constraint.Parent = line
		local stroke = addStroke(line, 4)
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	end

	local function updateLayout()
		local camera = Workspace.CurrentCamera
		local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
		local fit = math.min(viewport.X / 1920, viewport.Y / 1080)
		local isPhone = UserInputService.TouchEnabled and math.min(viewport.X, viewport.Y) < 600
		local xOffset
		local yScale
		if UserInputService.TouchEnabled then
			responsiveScale.Scale = math.clamp(fit * 0.58, 0.22, 0.52)
			xOffset = -8
			yScale = isPhone and 0.50 or 0.55
		else
			responsiveScale.Scale = math.clamp(viewport.X / 1920, 0.58, 0.82)
			xOffset = -24
			yScale = 0.58
		end
		local renderedHeight = holder.Size.Y.Offset * responsiveScale.Scale
		local activeSlot = tonumber(holder:GetAttribute("StackSlot")) or slotIndex
		holder.Position = UDim2.new(1, xOffset, yScale, activeSlot * (renderedHeight + 7))
	end

	return {
		Holder = holder,
		Button = button,
		Icon = icon,
		UpdateLayout = updateLayout,
	}
end

local playtimeButton = createRightButton(
	"PlaytimeRewards",
	Color3.fromRGB(255, 255, 255),
	Catalog.GiftIconImage,
	{"Playtime", "Rewards"},
	2,
	true
)

local codesButton = createRightButton(
	"Codes",
	CODES_CYAN,
	Catalog.CodesIconImage,
	{"Codes"},
	3,
	false
)

local claimTag = makeText(
	playtimeButton.Holder,
	"ClaimTag",
	"Claim!",
	UDim2.fromOffset(6, -15),
	UDim2.fromOffset(145, 54),
	36,
	Color3.fromRGB(255, 245, 50),
	7
)
claimTag.TextXAlignment = Enum.TextXAlignment.Left
claimTag.Rotation = -8
claimTag.Visible = false

local notification = Instance.new("ImageLabel")
notification.Name = "AvailableNotification"
notification.BackgroundTransparency = 1
notification.AnchorPoint = Vector2.new(0.5, 0.5)
notification.Position = UDim2.new(1, -5, 0, 5)
notification.Size = UDim2.fromOffset(77, 77)
notification.Image = NOTIFICATION_IMAGE
notification.ScaleType = Enum.ScaleType.Fit
notification.ZIndex = 9
notification.Visible = false
notification.Parent = playtimeButton.Holder

local notificationScale = Instance.new("UIScale")
notificationScale.Scale = 1
notificationScale.Parent = notification

local pulseTween = TweenService:Create(notificationScale, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
	Scale = 1.08,
})
pulseTween:Play()

local function createPanel(name, panelSize, headerColor, titleText, iconImage, rainbowHeader)
	local state = {
		Open = false,
		ActiveTween = nil,
		DimTween = nil,
	}

	local panel = Instance.new("Frame")
	panel.Name = name
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 1.27)
	panel.Size = UDim2.fromOffset(panelSize.X, panelSize.Y)
	panel.BackgroundColor3 = Color3.fromRGB(250, 250, 250)
	panel.BorderSizePixel = 0
	panel.ClipsDescendants = true
	panel.Visible = false
	panel.ZIndex = 5
	panel.Parent = panelGui
	addCorner(panel, 12)
	addStroke(panel, 5)
	StudUi.AddSurface(panel, 5, 12)

	local responsiveScale = Instance.new("UIScale")
	responsiveScale.Name = "ResponsiveScale"
	responsiveScale.Scale = 1
	responsiveScale.Parent = panel

	local topBar = Instance.new("Frame")
	topBar.Name = "TopBar"
	topBar.BackgroundColor3 = rainbowHeader and Color3.fromRGB(255, 255, 255) or headerColor
	topBar.BorderSizePixel = 0
	topBar.Size = UDim2.new(1, 0, 0, 88)
	topBar.ZIndex = 7
	topBar.Parent = panel
	addCorner(topBar, 12)
	addStroke(topBar, 4)
	local headerStuds = StudUi.AddSurface(topBar, 8, 12)
	if rainbowHeader then
		local studGradient = headerStuds:FindFirstChild("StudSurfaceGradient")
		if studGradient then
			studGradient.Color = RAINBOW
			table.insert(rainbowGradients, studGradient)
		end
		addRainbowGradient(topBar)
	end

	local icon = Instance.new("ImageLabel")
	icon.BackgroundTransparency = 1
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.new(0, 12, 0.5, 0)
	icon.Size = UDim2.fromOffset(76, 76)
	icon.Image = iconImage
	icon.ScaleType = Enum.ScaleType.Fit
	icon.ZIndex = 11
	icon.Parent = topBar

	local title = makeText(topBar, "Title", titleText, UDim2.new(0, 101, 0, 0), UDim2.new(1, -205, 1, 0), 43, Color3.fromRGB(255, 255, 255), 11)
	title.TextXAlignment = Enum.TextXAlignment.Left

	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseX"
	closeButton.AnchorPoint = Vector2.new(0.5, 0.5)
	closeButton.Position = UDim2.new(1, -39, 0.5, 0)
	closeButton.Size = UDim2.fromOffset(58, 58)
	closeButton.BackgroundColor3 = Color3.fromRGB(255, 55, 55)
	closeButton.BorderSizePixel = 0
	closeButton.AutoButtonColor = true
	closeButton.Font = Enum.Font.FredokaOne
	closeButton.Text = "X"
	closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeButton.TextSize = 36
	closeButton.ZIndex = 12
	closeButton.Parent = topBar
	addCorner(closeButton, 13)
	addStroke(closeButton, 4)
	StudUi.StyleButton(closeButton, 13)

	local function updateResponsiveScale()
		local camera = Workspace.CurrentCamera
		local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
		local inset = GuiService:GetGuiInset()
		local horizontalMargin = UserInputService.TouchEnabled and 18 or 40
		local verticalMargin = UserInputService.TouchEnabled and 14 or 34
		local availableWidth = math.max(1, viewport.X - horizontalMargin)
		local availableHeight = math.max(1, viewport.Y - inset.Y - verticalMargin)
		local fit = math.min(availableWidth / panelSize.X, availableHeight / panelSize.Y)
		responsiveScale.Scale = math.clamp(fit, 0.42, UserInputService.TouchEnabled and 0.98 or 1.06)
	end

	local function cancelTweens()
		if state.ActiveTween then state.ActiveTween:Cancel() end
		if state.DimTween then state.DimTween:Cancel() end
		state.ActiveTween = nil
		state.DimTween = nil
	end

	function state.Close()
		if not state.Open and not panel.Visible then return end
		cancelTweens()
		state.Open = false
		state.ActiveTween = TweenService:Create(panel, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.fromScale(0.5, 1.27),
			Rotation = -1,
		})
		state.DimTween = TweenService:Create(dim, TweenInfo.new(0.2), {BackgroundTransparency = 1})
		state.ActiveTween:Play()
		state.DimTween:Play()
		state.ActiveTween.Completed:Connect(function()
			if not state.Open then
				panel.Visible = false
				local anyOpen = false
				for _, candidate in ipairs({panelGui:FindFirstChild("PlaytimeRewardsPanel"), panelGui:FindFirstChild("CodesPanel")}) do
					if candidate and candidate.Visible and candidate ~= panel then
						anyOpen = true
					end
				end
				if not anyOpen then dim.Visible = false end
			end
		end)
	end

	function state.OpenPanel()
		cancelTweens()
		state.Open = true
		panel.Visible = true
		dim.Visible = true
		panel.Position = UDim2.fromScale(0.5, 1.27)
		panel.Rotation = 0
		dim.BackgroundTransparency = 1
		state.ActiveTween = TweenService:Create(panel, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.fromScale(0.5, 0.5),
			Rotation = 0,
		})
		state.DimTween = TweenService:Create(dim, TweenInfo.new(0.18), {BackgroundTransparency = 0.42})
		state.ActiveTween:Play()
		state.DimTween:Play()
	end

	state.Panel = panel
	state.TopBar = topBar
	state.Icon = icon
	state.CloseButton = closeButton
	state.UpdateResponsiveScale = updateResponsiveScale
	updateResponsiveScale()

	closeButton.Activated:Connect(function()
		PurchaseButtonSound.Play()
		pressAnimation(closeButton)
		state.Close()
	end)

	return state
end

local playtimePanel = createPanel(
	"PlaytimeRewardsPanel",
	Vector2.new(780, 610),
	Color3.fromRGB(255, 255, 255),
	"Playtime Rewards",
	Catalog.GiftIconImage,
	true
)

local playtimeStatus = makeText(
	playtimePanel.Panel,
	"Status",
	"A new reward unlocks every 3 minutes!",
	UDim2.new(0, 24, 0, 94),
	UDim2.new(1, -48, 0, 38),
	25,
	Color3.fromRGB(120, 65, 235),
	10
)

local rewardsGrid = Instance.new("Frame")
rewardsGrid.Name = "RewardsGrid"
rewardsGrid.BackgroundTransparency = 1
rewardsGrid.BorderSizePixel = 0
rewardsGrid.Position = UDim2.new(0, 25, 0, 143)
rewardsGrid.Size = UDim2.new(1, -50, 1, -159)
rewardsGrid.ClipsDescendants = false
rewardsGrid.ZIndex = 9
rewardsGrid.Parent = playtimePanel.Panel

local rewardsLayout = Instance.new("UIGridLayout")
rewardsLayout.CellSize = UDim2.fromOffset(138, 136)
rewardsLayout.CellPadding = UDim2.fromOffset(10, 10)
rewardsLayout.FillDirection = Enum.FillDirection.Horizontal
rewardsLayout.FillDirectionMaxCells = 5
rewardsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
rewardsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
rewardsLayout.SortOrder = Enum.SortOrder.LayoutOrder
rewardsLayout.Parent = rewardsGrid

local cards = {}
local currentPlaytimeState = nil
local claimed = {}

local function formatClock(seconds)
	seconds = math.max(0, math.ceil(tonumber(seconds) or 0))
	local minutes = math.floor(seconds / 60)
	local secs = seconds % 60
	return string.format("%02d:%02d", minutes, secs)
end

local function createRewardCard(reward)
	local card = Instance.new("Frame")
	card.Name = "Reward" .. tostring(reward.Index)
	card.LayoutOrder = reward.Index
	card.Size = UDim2.fromOffset(138, 136)
	card.BackgroundColor3 = CARD_BLUE
	card.BorderSizePixel = 0
	card.ZIndex = 10
	card.Parent = rewardsGrid
	addCorner(card, 12)
	addStroke(card, 3)
	StudUi.AddSurface(card, 11, 12, 5, 5)

	local number = makeText(
		card,
		"Number",
		"Reward " .. tostring(reward.Index),
		UDim2.fromOffset(5, 3),
		UDim2.new(1, -10, 0, 27),
		20,
		Color3.fromRGB(255, 255, 255),
		13
	)
	number.TextWrapped = false

	local icon = Instance.new("ImageLabel")
	icon.Name = "RewardIcon"
	icon.BackgroundTransparency = 1
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.Position = UDim2.new(0.5, 0, 0, 29)
	icon.Size = UDim2.fromOffset(52, 45)
	icon.Image = DailyRewards.GetRewardIconImage(reward)
	icon.ScaleType = Enum.ScaleType.Fit
	icon.ZIndex = 13
	icon.Parent = card

	local amount = makeText(
		card,
		"Amount",
		Catalog.GetRewardText(reward),
		UDim2.fromOffset(5, 72),
		UDim2.new(1, -10, 0, 28),
		19,
		Color3.fromRGB(255, 255, 255),
		13
	)
	amount.TextWrapped = false

	local claim = Instance.new("TextButton")
	claim.Name = "Claim"
	claim.AnchorPoint = Vector2.new(0.5, 1)
	claim.Position = UDim2.new(0.5, 0, 1, -6)
	claim.Size = UDim2.new(1, -12, 0, 30)
	claim.BackgroundColor3 = CARD_FOOTER_BLUE
	claim.BorderSizePixel = 0
	claim.AutoButtonColor = false
	claim.Font = Enum.Font.FredokaOne
	claim.Text = "03:00"
	claim.TextColor3 = Color3.fromRGB(255, 255, 255)
	claim.TextSize = 18
	claim.ZIndex = 14
	claim.Parent = card
	addCorner(claim, 8)
	addStroke(claim, 2)
	StudUi.StyleButton(claim, 8)

	claim.Activated:Connect(function()
		if claimed[reward.Index] == true then return end
		local state = currentPlaytimeState
		if not state then return end
		local elapsed = Workspace:GetServerTimeNow() - (tonumber(state.SessionStartedAt) or Workspace:GetServerTimeNow())
		if elapsed < Catalog.GetUnlockSeconds(reward.Index) then return end
		PurchaseButtonSound.Play()
		pressAnimation(claim)
		claim.AutoButtonColor = false
		claim.Text = "Claiming..."
		PlaytimeRequest:FireServer("Claim", reward.Index)
	end)

	cards[reward.Index] = {
		Card = card,
		Number = number,
		Amount = amount,
		Claim = claim,
	}
end

for _, reward in ipairs(Catalog.Rewards) do
	createRewardCard(reward)
end

local function refreshPlaytimeUi()
	local state = currentPlaytimeState
	if not state then
		playtimeStatus.Text = "Loading playtime rewards..."
		playtimeButton.Holder.Visible = true
		return
	end

	local elapsed = math.max(0, Workspace:GetServerTimeNow() - (tonumber(state.SessionStartedAt) or Workspace:GetServerTimeNow()))
	local availableCount = 0
	for _, reward in ipairs(Catalog.Rewards) do
		local card = cards[reward.Index]
		local isClaimed = claimed[reward.Index] == true
		local remaining = Catalog.GetUnlockSeconds(reward.Index) - elapsed
		local isAvailable = not isClaimed and remaining <= 0

		if isClaimed then
			card.Card.BackgroundColor3 = CARD_GREEN
			card.Claim.Text = "Claimed"
			card.Claim.BackgroundColor3 = CARD_FOOTER_GREEN
			card.Claim.AutoButtonColor = false
		elseif isAvailable then
			availableCount += 1
			card.Card.BackgroundColor3 = CARD_BLUE_READY
			card.Claim.Text = "Claim!"
			card.Claim.BackgroundColor3 = GREEN
			card.Claim.AutoButtonColor = true
		else
			card.Card.BackgroundColor3 = CARD_BLUE
			card.Claim.Text = formatClock(remaining)
			card.Claim.BackgroundColor3 = CARD_FOOTER_BLUE
			card.Claim.AutoButtonColor = false
		end
	end

	local allClaimed = state.Completed == true
	if not allClaimed then
		allClaimed = true
		for index = 1, Catalog.TotalRewards do
			if claimed[index] ~= true then
				allClaimed = false
				break
			end
		end
	end
	playtimeButton.Holder.Visible = not allClaimed
	notification.Visible = availableCount > 0 and not allClaimed
	claimTag.Visible = availableCount > 0 and not allClaimed
	if allClaimed and playtimePanel.Open then
		playtimePanel.Close()
	end

	if availableCount > 0 then
		playtimeStatus.Text = tostring(availableCount) .. (availableCount == 1 and " reward is ready to claim!" or " rewards are ready to claim!")
		playtimeStatus.TextColor3 = Color3.fromRGB(30, 205, 75)
	elseif not allClaimed then
		local nextIndex = nil
		for index = 1, Catalog.TotalRewards do
			if claimed[index] ~= true then
				nextIndex = index
				break
			end
		end
		if nextIndex then
			playtimeStatus.Text = "Next reward in " .. formatClock(Catalog.GetUnlockSeconds(nextIndex) - elapsed)
		else
			playtimeStatus.Text = "All rewards claimed!"
		end
		playtimeStatus.TextColor3 = Color3.fromRGB(120, 65, 235)
	end
end

local function applyPlaytimeState(state)
	if type(state) ~= "table" then return end
	currentPlaytimeState = state
	claimed = {}
	for _, index in ipairs(state.Claimed or {}) do
		claimed[tonumber(index)] = true
	end
	refreshPlaytimeUi()
	if state.ClaimSucceeded == true then
		playtimeStatus.TextColor3 = GREEN
	end
	if tostring(state.Message or "") ~= "" then
		playtimeStatus.Text = tostring(state.Message)
	end
end

local codesPanel = createPanel(
	"CodesPanel",
	Vector2.new(700, 430),
	GREY,
	"Codes",
	Catalog.CodesIconImage,
	false
)

local codesSubtitle = makeText(codesPanel.Panel, "Subtitle", "Enter a code below!", UDim2.new(0, 30, 0, 102), UDim2.new(1, -60, 0, 45), 30, GREY, 10)

local inputSurface = Instance.new("Frame")
inputSurface.Name = "CodeInputSurface"
inputSurface.Position = UDim2.new(0, 48, 0, 161)
inputSurface.Size = UDim2.new(1, -96, 0, 82)
inputSurface.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
inputSurface.BorderSizePixel = 0
inputSurface.ZIndex = 9
inputSurface.Parent = codesPanel.Panel
addCorner(inputSurface, 13)
addStroke(inputSurface, 4)
StudUi.AddSurface(inputSurface, 10, 13, 12, 2)

local codeBox = Instance.new("TextBox")
codeBox.Name = "CodeBox"
codeBox.BackgroundTransparency = 1
codeBox.Position = UDim2.fromOffset(15, 8)
codeBox.Size = UDim2.new(1, -30, 1, -16)
codeBox.ClearTextOnFocus = false
codeBox.Font = Enum.Font.FredokaOne
codeBox.PlaceholderText = "Type code here..."
codeBox.PlaceholderColor3 = Color3.fromRGB(145, 145, 145)
codeBox.Text = ""
codeBox.TextColor3 = Color3.fromRGB(45, 45, 45)
codeBox.TextSize = 28
codeBox.TextXAlignment = Enum.TextXAlignment.Center
codeBox.ZIndex = 12
codeBox.Parent = inputSurface

local redeemButton = Instance.new("TextButton")
redeemButton.Name = "RedeemButton"
redeemButton.AnchorPoint = Vector2.new(0.5, 0)
redeemButton.Position = UDim2.new(0.5, 0, 0, 264)
redeemButton.Size = UDim2.fromOffset(270, 64)
redeemButton.BackgroundColor3 = GREY
redeemButton.BorderSizePixel = 0
redeemButton.AutoButtonColor = true
redeemButton.Font = Enum.Font.FredokaOne
redeemButton.Text = "Redeem"
redeemButton.TextColor3 = Color3.fromRGB(255, 255, 255)
redeemButton.TextSize = 31
redeemButton.ZIndex = 12
redeemButton.Parent = codesPanel.Panel
addCorner(redeemButton, 13)
addStroke(redeemButton, 4)
StudUi.StyleButton(redeemButton, 13)

local codeStatus = makeText(codesPanel.Panel, "CodeStatus", "", UDim2.new(0, 35, 0, 340), UDim2.new(1, -70, 0, 58), 26, RED, 11)

local redeemBusy = false
local function submitCode()
	if redeemBusy then return end
	redeemBusy = true
	PurchaseButtonSound.Play()
	pressAnimation(redeemButton)
	redeemButton.Text = "Checking..."
	redeemButton.AutoButtonColor = false
	CodesRequest:FireServer("Redeem", codeBox.Text)
	task.delay(2.5, function()
		if redeemBusy then
			redeemBusy = false
			redeemButton.Text = "Redeem"
			redeemButton.AutoButtonColor = true
		end
	end)
end

redeemButton.Activated:Connect(submitCode)
codeBox.FocusLost:Connect(function(enterPressed)
	if enterPressed then submitCode() end
end)

CodesUpdate.OnClientEvent:Connect(function(state)
	if type(state) ~= "table" then return end
	redeemBusy = false
	redeemButton.Text = "Redeem"
	redeemButton.AutoButtonColor = true
	codeStatus.Text = tostring(state.Message or "")
	codeStatus.TextColor3 = state.Success == true and GREEN or RED
	if state.Success == true then
		codeBox.Text = ""
	end
end)

local function closeBothPanels()
	playtimePanel.Close()
	codesPanel.Close()
end

MenuEvents.CloseAll.Event:Connect(closeBothPanels)
MenuEvents.Get("OpenPlaytimeRewardsPanel").Event:Connect(function()
	codesPanel.Close()
	playtimePanel.OpenPanel()
	PlaytimeRequest:FireServer("Refresh")
end)
MenuEvents.Get("OpenCodesPanel").Event:Connect(function()
	playtimePanel.Close()
	codesPanel.OpenPanel()
end)
MenuEvents.MarkReady("Playtime", function() return playtimePanel.Open end)
MenuEvents.MarkReady("Codes", function() return codesPanel.Open end)

playtimeButton.Button.Activated:Connect(function()
	if not playtimeButton.Holder.Visible then return end
	PurchaseButtonSound.Play()
	pressAnimation(playtimeButton.Button)
	MenuEvents.Request("Playtime")
end)

codesButton.Button.Activated:Connect(function()
	PurchaseButtonSound.Play()
	pressAnimation(codesButton.Button)
	MenuEvents.Request("Codes")
end)

PlaytimeUpdate.OnClientEvent:Connect(applyPlaytimeState)

local function updateAllResponsiveLayout()
	                                                                             
	                                                                             
	                                                                     
	local infiniteOfferVisible = player:GetAttribute("InfiniteRevivesOwned") ~= true
	local playtimeSlot = infiniteOfferVisible and 2 or 1
	playtimeButton.Holder:SetAttribute("StackSlot", playtimeSlot)
	codesButton.Holder:SetAttribute("StackSlot", playtimeSlot + 1)
	playtimeButton.UpdateLayout()
	codesButton.UpdateLayout()
	playtimePanel.UpdateResponsiveScale()
	codesPanel.UpdateResponsiveScale()
end

updateAllResponsiveLayout()
codesButton.Holder.Visible = true
playtimeButton.Holder.Visible = true

local cameraConnection = nil
local function connectCamera()
	if cameraConnection then cameraConnection:Disconnect() end
	local camera = Workspace.CurrentCamera
	if camera then
		cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateAllResponsiveLayout)
	end
	updateAllResponsiveLayout()
end
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(connectCamera)
connectCamera()
player:GetAttributeChangedSignal("InfiniteRevivesOwned"):Connect(updateAllResponsiveLayout)

task.spawn(function()
	pcall(function()
		ContentProvider:PreloadAsync({
			playtimeButton.Icon,
			codesButton.Icon,
			playtimePanel.Icon,
			codesPanel.Icon,
			notification,
		})
	end)
end)

task.spawn(function()
	while player.Parent do
		task.wait(1)
		refreshPlaytimeUi()
	end
end)

RunService.RenderStepped:Connect(function()
	local rotation = (os.clock() * 20) % 360
	for index = #rainbowGradients, 1, -1 do
		local gradient = rainbowGradients[index]
		if gradient.Parent then
			gradient.Rotation = rotation
		else
			table.remove(rainbowGradients, index)
		end
	end
end)

task.defer(function()
	PlaytimeRequest:FireServer("Refresh")
end)

print("[PlaytimeRewardsAndCodes] V306KAF loaded. Phone right-stack lift and cyan Codes button are active in World 1.")
