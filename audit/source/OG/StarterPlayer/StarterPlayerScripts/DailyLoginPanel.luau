                                                                              
                                                                            
          

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local DailyRewards = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DailyRewards"))
local StudUi = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("StudUi"))
local MenuEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MenuEvents"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

        
                                                                                               
                                                  
                                                                                   
local DailyLoginRequest = Remotes:FindFirstChild("DailyLoginRequest")
local DailyLoginUpdate = Remotes:FindFirstChild("DailyLoginUpdate")

local function refreshDailyRemotes()
	DailyLoginRequest = Remotes:FindFirstChild("DailyLoginRequest")
	DailyLoginUpdate = Remotes:FindFirstChild("DailyLoginUpdate")
end

local function safeFireDaily(action)
	refreshDailyRemotes()

	if DailyLoginRequest and DailyLoginRequest:IsA("RemoteEvent") then
		local ok, err = pcall(function()
			DailyLoginRequest:FireServer(action)
		end)

		if not ok then
			warn("[DailyLoginPanel] Daily request failed: " .. tostring(err))
		end
	end
end

local openDailyPanel = MenuEvents.Get("OpenDailyPanel")
local openTrailsPanel = MenuEvents.Get("OpenTrailsPanel")
local openEvolvePanel = MenuEvents.Get("OpenEvolvePanel")
local openRebirthPanel = MenuEvents.Get("OpenRebirthPanel")
local openIndexPanel = MenuEvents.Get("OpenIndexPanel")
local openAurasPanel = MenuEvents.Get("OpenAurasPanel")
local openTeleportPanel = MenuEvents.Get("OpenTeleportPanel")
local openAbilitiesPanel = MenuEvents.Get("OpenAbilitiesPanel")

local PANEL_SIZE = Vector2.new(900, 570)
local OPEN_POSITION = UDim2.fromScale(0.5, 0.5)
local CLOSED_POSITION = UDim2.fromScale(0.5, 1.26)
local DAILY_HEADER_COLOR = Color3.fromRGB(20, 215, 255)
local DAILY_BUTTON_IMAGE = "rbxassetid://100422121663772"
local DAILY_CLAIM_SOUND_ID = "rbxassetid://135478009117226"
local DAILY_CLAIM_SOUND_NAME = "DailyRewardClaimCompleteSound"

local isOpen = false
local activeTween = nil
local dimTween = nil
local currentState = nil
local cardsByDay = {}
local shouldAutoScrollToNextReward = false

local dailyClaimSound = SoundService:FindFirstChild(DAILY_CLAIM_SOUND_NAME)
if not dailyClaimSound or not dailyClaimSound:IsA("Sound") then
	if dailyClaimSound then
		dailyClaimSound:Destroy()
	end
	dailyClaimSound = Instance.new("Sound")
	dailyClaimSound.Name = DAILY_CLAIM_SOUND_NAME
	dailyClaimSound.Parent = SoundService
end
dailyClaimSound.SoundId = DAILY_CLAIM_SOUND_ID
dailyClaimSound.Volume = 1
dailyClaimSound.PlaybackSpeed = 1

task.spawn(function()
	pcall(function()
		ContentProvider:PreloadAsync({ dailyClaimSound })
	end)
end)

local function playDailyClaimSound()
	dailyClaimSound:Stop()
	dailyClaimSound.TimePosition = 0
	SoundService:PlayLocalSound(dailyClaimSound)
end

local dailyContentObjects = {}

local function setDailyContentVisible(visible)
	for _, obj in ipairs(dailyContentObjects) do
		if obj and obj.Parent then
			obj.Visible = visible
		end
	end
end

local old = playerGui:FindFirstChild("DailyLoginPanelGui")
if old then
	old:Destroy()
end

local function addCorner(instance, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 10)
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

local function makeText(parent, name, text, pos, size, textSize, color)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = pos
	label.Size = size
	label.Font = Enum.Font.GothamBlack
	label.Text = text
	label.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	label.TextSize = textSize or 30
	label.TextScaled = false
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.ZIndex = 10
	label.Parent = parent
	addStroke(label, 3)
	return label
end

local function makeButton(parent, name, text, pos, size, color)
	local button = Instance.new("TextButton")
	button.Name = name
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Position = pos
	button.Size = size
	button.BackgroundColor3 = color or Color3.fromRGB(255, 205, 20)
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.Font = Enum.Font.GothamBlack
	button.Text = text
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextSize = 30
	button.ZIndex = 12
	button.Parent = parent
	addCorner(button, 14)
	addStroke(button, 4)
	StudUi.StyleButton(button, 14)
	return button
end

local function formatTime(seconds)
	seconds = math.max(0, math.floor(tonumber(seconds) or 0))

	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	local secs = seconds % 60

	return string.format("%d:%02d:%02d", hours, minutes, secs)
end

local function claimedSetFromState(state)
	local set = {}
	for _, day in ipairs((state and state.ClaimedDays) or {}) do
		set[tonumber(day)] = true
	end
	return set
end

local gui = Instance.new("ScreenGui")
gui.Name = "DailyLoginPanelGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 60
gui.Enabled = false
gui.Parent = playerGui

local dim = Instance.new("Frame")
dim.Name = "Dim"
dim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
dim.BackgroundTransparency = 1
dim.BorderSizePixel = 0
dim.Size = UDim2.fromScale(1, 1)
dim.ZIndex = 1
dim.Parent = gui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = CLOSED_POSITION
panel.Size = UDim2.fromOffset(PANEL_SIZE.X, PANEL_SIZE.Y)
panel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
panel.BackgroundTransparency = 0
panel.BorderSizePixel = 0
panel.ClipsDescendants = true
panel.ZIndex = 5
panel.Parent = gui

                         
                                                                                             
local responsivePanelScale = Instance.new("UIScale")
responsivePanelScale.Name = "MobileResponsiveScale"
responsivePanelScale.Scale = 1
responsivePanelScale.Parent = panel

local function updateResponsivePanelScale()
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
	local inset = GuiService:GetGuiInset()
	local horizontalMargin = UserInputService.TouchEnabled and 18 or 40
	local verticalMargin = UserInputService.TouchEnabled and 14 or 34
	local availableWidth = math.max(1, viewport.X - horizontalMargin)
	local availableHeight = math.max(1, viewport.Y - inset.Y - verticalMargin)
	local fit = math.min(availableWidth / PANEL_SIZE.X, availableHeight / PANEL_SIZE.Y)
	local maximum = UserInputService.TouchEnabled and 0.98 or 1.08

	responsivePanelScale.Scale = math.clamp(fit, 0.42, maximum)
end

updateResponsivePanelScale()

if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsivePanelScale)
end
addCorner(panel, 12)
addStroke(panel, 5)
StudUi.AddSurface(panel, 5, 12)

local topBar = Instance.new("Frame")
topBar.Name = "TopBar"
topBar.BackgroundColor3 = DAILY_HEADER_COLOR
topBar.BorderSizePixel = 0
topBar.Position = UDim2.fromOffset(0, 0)
topBar.Size = UDim2.new(1, 0, 0, 88)
topBar.ZIndex = 6
topBar.Parent = panel
addCorner(topBar, 12)
addStroke(topBar, 4)
StudUi.AddSurface(topBar, 7, 12)

local titleIcon = Instance.new("ImageLabel")
titleIcon.Name = "DailyHeaderIcon"
titleIcon.BackgroundTransparency = 1
titleIcon.BorderSizePixel = 0
titleIcon.AnchorPoint = Vector2.new(0, 0.5)
titleIcon.Position = UDim2.new(0, 12, 0.5, 0)
titleIcon.Size = UDim2.fromOffset(78, 78)
titleIcon.Image = DAILY_BUTTON_IMAGE
titleIcon.ImageRectOffset = Vector2.new(108, 40)
titleIcon.ImageRectSize = Vector2.new(296, 296)
titleIcon.ScaleType = Enum.ScaleType.Fit
titleIcon.ZIndex = 11
titleIcon.Parent = topBar

local title = makeText(topBar, "Title", "Daily Login", UDim2.new(0, 104, 0, 0), UDim2.new(1, -210, 1, 0), 45, Color3.fromRGB(255, 255, 255))
title.ZIndex = 11
title.Font = Enum.Font.FredokaOne
title.TextXAlignment = Enum.TextXAlignment.Left

local closeX = makeButton(topBar, "CloseX", "X", UDim2.new(1, -38, 0.5, 0), UDim2.fromOffset(58, 58), Color3.fromRGB(255, 55, 55))
closeX.TextSize = 36

local subtitle = makeText(panel, "Subtitle", "Login everyday for insane rewards!", UDim2.new(0.5, -345, 0, 92), UDim2.fromOffset(690, 40), 29, DAILY_HEADER_COLOR)
local special = makeText(panel, "SpecialText", "Big rewards at day 3, 7, 14, 21 & 30", UDim2.new(0.5, -370, 0, 130), UDim2.fromOffset(740, 40), 30, Color3.fromRGB(255, 220, 42))
addStroke(special, 3, Color3.fromRGB(0, 0, 0))

local scroll = Instance.new("ScrollingFrame")
scroll.Name = "RewardsScroll"
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.Position = UDim2.new(0, 26, 0, 170)
scroll.Size = UDim2.new(1, -52, 0, 260)
scroll.ScrollBarThickness = 8
scroll.ScrollBarImageColor3 = DAILY_HEADER_COLOR
scroll.CanvasSize = UDim2.fromOffset(0, 0)
scroll.ScrollingDirection = Enum.ScrollingDirection.X
scroll.ZIndex = 8
scroll.Parent = panel

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 22)
layout.Parent = scroll

local padding = Instance.new("UIPadding")
padding.PaddingLeft = UDim.new(0, 8)
padding.PaddingRight = UDim.new(0, 8)
padding.PaddingTop = UDim.new(0, 4)
padding.Parent = scroll

local nextRewardText = makeText(panel, "NextRewardText", "Next reward ready!", UDim2.new(0.5, -335, 0, 444), UDim2.fromOffset(670, 38), 32, DAILY_HEADER_COLOR)
local claimButton = makeButton(panel, "ClaimButton", "Claim", UDim2.new(0.5, 0, 0, 518), UDim2.fromOffset(285, 58), Color3.fromRGB(255, 205, 20))

                                         
                                                                                                  
dailyContentObjects = {
	subtitle,
	special,
	scroll,
	nextRewardText,
	claimButton,
}

local function createRewardCard(reward)
	local day = reward.Day

	local card = Instance.new("Frame")
	card.Name = "Day" .. tostring(day)
	card.LayoutOrder = day
	card.Size = UDim2.fromOffset(170, 238)
	card.BackgroundColor3 = Color3.fromRGB(53, 213, 255)
	card.BorderSizePixel = 0
	card.ZIndex = 9
	card.Parent = scroll
	addCorner(card, 12)
	addStroke(card, reward.Featured and 6 or 4)

	local cardGradient = Instance.new("UIGradient")
	cardGradient.Rotation = 90
	cardGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(110, 255, 255)),
		ColorSequenceKeypoint.new(0.52, Color3.fromRGB(35, 190, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(14, 139, 255)),
	})
	cardGradient.Parent = card

	StudUi.AddSurface(card, 10, 12)

	local dayLabel = makeText(card, "DayLabel", "Day " .. tostring(day), UDim2.new(0, 8, 0, 9), UDim2.new(1, -16, 0, 42), 31, Color3.fromRGB(255, 255, 255))
	dayLabel.ZIndex = 14

	local icon = Instance.new("ImageLabel")
	icon.Name = "RewardIcon"
	icon.BackgroundTransparency = 1
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.Position = UDim2.new(0.5, 0, 0, 61)
	icon.Size = UDim2.fromOffset(112, 96)
	icon.Image = DailyRewards.GetRewardIconImage(reward)
	icon.ScaleType = Enum.ScaleType.Fit
	icon.ZIndex = 14
	icon.Parent = card

	local amount = makeText(card, "RewardAmount", DailyRewards.GetRewardText(reward), UDim2.new(0, 8, 1, -58), UDim2.new(1, -16, 0, 48), 26, Color3.fromRGB(255, 255, 255))
	amount.ZIndex = 14

	local claimTag = makeText(card, "ClaimTag", "TODAY", UDim2.new(0.5, -54, 0, 53), UDim2.fromOffset(108, 30), 20, Color3.fromRGB(255, 220, 42))
	claimTag.ZIndex = 15
	claimTag.Visible = false

	local check = makeText(card, "Checkmark", "✓", UDim2.new(0.5, -72, 0.5, -66), UDim2.fromOffset(144, 144), 102, Color3.fromRGB(0, 255, 125))
	check.Rotation = -12
	check.ZIndex = 20
	check.Visible = false
	addStroke(check, 6)

	local lock = Instance.new("Frame")
	lock.Name = "LockedOverlay"
	lock.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	lock.BackgroundTransparency = 0.5
	lock.BorderSizePixel = 0
	lock.Size = UDim2.fromScale(1, 1)
	lock.ZIndex = 18
	lock.Visible = false
	lock.Parent = card
	addCorner(lock, 12)

	local lockText = makeText(lock, "LockText", "LOCKED", UDim2.fromScale(0, 0.40), UDim2.fromScale(1, 0.25), 28, Color3.fromRGB(255, 255, 255))
	lockText.ZIndex = 19

	if reward.Featured then
		local glow = Instance.new("UIStroke")
		glow.Name = "FeaturedGlow"
		glow.Color = reward.Milestone and Color3.fromRGB(255, 220, 42) or Color3.fromRGB(255, 122, 42)
		glow.Thickness = reward.Milestone and 4 or 3
		glow.Transparency = 0.15
		glow.Parent = card
	end

	cardsByDay[day] = {
		Card = card,
		Check = check,
		Lock = lock,
		ClaimTag = claimTag,
		Reward = reward,
	}
end

for _, reward in ipairs(DailyRewards.Rewards) do
	createRewardCard(reward)
end

local function refreshCanvas()
	scroll.CanvasSize = UDim2.fromOffset(layout.AbsoluteContentSize.X + 32, 0)
end

layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(refreshCanvas)
task.defer(refreshCanvas)

local function updateCards()
	local state = currentState or {}
	local claimed = claimedSetFromState(state)
	local nextDay = tonumber(state.NextDay) or 1

	for day, cardData in pairs(cardsByDay) do
		local isClaimed = claimed[day] == true
		local isToday = day == nextDay and not isClaimed

		cardData.Check.Visible = isClaimed
		cardData.ClaimTag.Visible = isToday and (state.CanClaim == true)
		cardData.Lock.Visible = (day > nextDay) and not isClaimed
		cardData.Card.BackgroundTransparency = isClaimed and 0.14 or 0
	end

	        
	                                                   
	                                                                                      
	                                                                       
	if shouldAutoScrollToNextReward and cardsByDay[nextDay] then
		shouldAutoScrollToNextReward = false

		task.defer(function()
			local card = cardsByDay[nextDay] and cardsByDay[nextDay].Card
			if gui.Enabled and card and card.Parent and scroll.AbsoluteSize.X > 0 then
				scroll.CanvasPosition = Vector2.new(math.max(0, card.AbsolutePosition.X - scroll.AbsolutePosition.X - 32), 0)
			end
		end)
	end
end

local function updateBottomText()
	local state = currentState

	if not state then
		nextRewardText.Text = "Loading daily rewards..."
		claimButton.Text = "Loading"
		claimButton.BackgroundColor3 = Color3.fromRGB(105, 105, 105)
		claimButton.AutoButtonColor = false
		return
	end

	if state.LoadFailed == true then
		nextRewardText.Text = tostring(state.Message or "Daily rewards are temporarily unavailable")
		claimButton.Text = "Unavailable"
		claimButton.BackgroundColor3 = Color3.fromRGB(105, 105, 105)
		claimButton.AutoButtonColor = false
		return
	end

	local message = tostring(state.Message or "")
	local hasClaimError = message ~= ""
		and (message:find("could not", 1, true)
			or message:find("not ready", 1, true))

	local nextDay = tonumber(state.NextDay) or 1
	local reward = DailyRewards.GetReward(nextDay)

	if state.CanClaim then
		nextRewardText.Text = "Day " .. tostring(nextDay) .. " ready: " .. DailyRewards.GetRewardText(reward)
		claimButton.Text = "Claim"
		claimButton.BackgroundColor3 = Color3.fromRGB(255, 205, 20)
		claimButton.AutoButtonColor = true
	else
		nextRewardText.Text = "Next reward in: " .. formatTime(state.SecondsRemaining)
		claimButton.Text = "Claimed"
		claimButton.BackgroundColor3 = Color3.fromRGB(105, 105, 105)
		claimButton.AutoButtonColor = false
	end

	if hasClaimError then
		nextRewardText.Text = message
	end
end

local function applyState(state)
	if type(state) ~= "table" then
		return
	end

	local claimSucceeded = state.ClaimSucceeded == true
	state.ClaimSucceeded = false
	currentState = state
	updateCards()
	updateBottomText()
	if claimSucceeded then
		playDailyClaimSound()
	end
end

local function cancelTweens()
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
	cancelTweens()
	isOpen = false

	                                                                                                   
	setDailyContentVisible(false)

	activeTween = TweenService:Create(panel, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = CLOSED_POSITION,
		Rotation = -1,
	})
	dimTween = TweenService:Create(dim, TweenInfo.new(0.2), {
		BackgroundTransparency = 1,
	})

	activeTween:Play()
	dimTween:Play()

	activeTween.Completed:Connect(function()
		if not isOpen then
			gui.Enabled = false
		end
	end)
end

local function openPanel()
	cancelTweens()

	gui.Enabled = true
	isOpen = true
	shouldAutoScrollToNextReward = true

	                                               
	setDailyContentVisible(true)

	panel.Position = CLOSED_POSITION
	panel.Rotation = 0
	panel.Size = UDim2.fromOffset(PANEL_SIZE.X, PANEL_SIZE.Y)
	dim.BackgroundTransparency = 1

	                                                                                     
	if not currentState then
		currentState = {
			ClaimedDays = {},
			NextDay = 1,
			CanClaim = false,
			SecondsRemaining = 0,
		}
	end

	                                                                   
	activeTween = TweenService:Create(panel, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = OPEN_POSITION,
		Rotation = 0,
	})
	dimTween = TweenService:Create(dim, TweenInfo.new(0.18), {
		BackgroundTransparency = 0.42,
	})

	activeTween:Play()
	dimTween:Play()
	updateCards()
	updateBottomText()

	                                                              
	safeFireDaily("Refresh")
end

local function togglePanel()
	if gui.Enabled and isOpen then
		closePanel()
	else
		openPanel()
	end
end

closeX.Activated:Connect(closePanel)

claimButton.Activated:Connect(function()
	if currentState and currentState.CanClaim then
		safeFireDaily("Claim")

		claimButton.Text = "Claiming..."
		claimButton.AutoButtonColor = false
	end
end)

openDailyPanel.Event:Connect(togglePanel)
MenuEvents.CloseAll.Event:Connect(closePanel)
MenuEvents.MarkReady("Daily", function()
	return isOpen
end)

                                                  
openEvolvePanel.Event:Connect(function()
	if gui.Enabled and isOpen then
		closePanel()
	end
end)

openRebirthPanel.Event:Connect(function()
	if gui.Enabled and isOpen then
		closePanel()
	end
end)

openIndexPanel.Event:Connect(function()
	if gui.Enabled and isOpen then
		closePanel()
	end
end)

local dailyUpdateConnected = false

local function connectDailyUpdateRemote()
	if dailyUpdateConnected then
		return
	end

	refreshDailyRemotes()

	if DailyLoginUpdate and DailyLoginUpdate:IsA("RemoteEvent") then
		dailyUpdateConnected = true
		DailyLoginUpdate.OnClientEvent:Connect(applyState)
	end
end

connectDailyUpdateRemote()

task.spawn(function()
	while not dailyUpdateConnected do
		task.wait(0.25)
		connectDailyUpdateRemote()
	end
end)

task.spawn(function()
	while true do
		task.wait(1)

		if currentState and not currentState.CanClaim then
			currentState.SecondsRemaining = math.max(0, (tonumber(currentState.SecondsRemaining) or 0) - 1)

			if currentState.SecondsRemaining <= 0 then
				currentState.CanClaim = true
			end

			updateBottomText()
			updateCards()
		end
	end
end)

player.CharacterAdded:Connect(function()
	task.defer(function()
		if gui and gui.Parent ~= playerGui then
			gui.Parent = playerGui
		end
	end)
end)

task.defer(function()
	safeFireDaily("Refresh")
end)

print("[DailyLoginPanel] V306HP loaded. Successful saved claims use the exact tutorial-complete sound; safe errors and repeating 30-day cycles remain supported.")


openTrailsPanel.Event:Connect(function()
	if gui.Enabled and isOpen then
		closePanel()
	end
end)

openAurasPanel.Event:Connect(function()
	if gui.Enabled and isOpen then
		closePanel()
	end
end)

openTeleportPanel.Event:Connect(function()
	if gui.Enabled and isOpen then
		closePanel()
	end
end)

openAbilitiesPanel.Event:Connect(function()
	if gui.Enabled and isOpen then
		closePanel()
	end
end)
