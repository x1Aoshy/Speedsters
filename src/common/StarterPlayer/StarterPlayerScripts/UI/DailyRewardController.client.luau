local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local DailyRewards = require(ReplicatedStorage.Shared:WaitForChild("DailyRewards"))
local MenuEvents = require(ReplicatedStorage.Shared:WaitForChild("MenuEvents"))
local MenuPanelLayout = require(ReplicatedStorage.Shared:WaitForChild("MenuPanelLayout"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
-- The server makes these when it starts (DailyLoginSystem); a client that got here first
-- used to find nothing and never claim (2026-09-18, Sung: "Not being able to claim").
local request = Remotes:WaitForChild("DailyLoginRequest", 30)
local update = Remotes:WaitForChild("DailyLoginUpdate", 30)
local gui = playerGui:WaitForChild("DailyReward")
local daysFrame = gui:WaitForChild("Days31")
local scroll = daysFrame:WaitForChild("ScrollingFrame")
local resultLabel = daysFrame:WaitForChild("RewardResult")
local buttons = {}
for _, child in ipairs(daysFrame:GetChildren()) do if child:IsA("ImageButton") then table.insert(buttons, child) end end
table.sort(buttons, function(a,b) return a.Position.Y.Scale < b.Position.Y.Scale end)
local closeButton = buttons[1]
local claimButton = buttons[#buttons]
local claimLabel = claimButton and claimButton:FindFirstChild("Name")
local cards = {}
for day = 1, DailyRewards.TotalDays do
	local card = scroll:FindFirstChild("Day" .. day)
	if card then
		local dayLabel, amountLabel, statusLabel
		local unclaimed = {}
		for _, label in ipairs(card:GetChildren()) do
			if label:IsA("TextLabel") then
				local text = tostring(label.Text)
				if text:match("^Day") then dayLabel = label
				elseif text == "Today" or text == "Claimed" then statusLabel = label
				elseif text:find("Victory") or text:find("Speed") then amountLabel = label
				else table.insert(unclaimed, label) end
			end
		end
		-- Resolving by placeholder text alone meant a card whose text had been
		-- edited silently lost its labels and never updated. Fall back to layout:
		-- top label is the day, the one under it is the reward, lowest is status.
		if #unclaimed > 0 then
			table.sort(unclaimed, function(a, b) return a.Position.Y.Scale < b.Position.Y.Scale end)
			if not dayLabel then dayLabel = table.remove(unclaimed, 1) end
			if not amountLabel then amountLabel = table.remove(unclaimed, 1) end
			if not statusLabel then statusLabel = unclaimed[#unclaimed] end
		end
		local reward = DailyRewards.GetReward(day)
		-- M15 (2026-09-25): Spin tickets and 2x potions have their own art (DailyRewards.GetRewardIconImage).
		-- A card holds two ImageLabels, both named "ImageLabel": the card-sized background and the
		-- reward icon; the icon is the smaller one (never the Locked overlay's).
		local icon, iconArea = nil, math.huge
		for _, child in ipairs(card:GetChildren()) do
			if child:IsA("ImageLabel") then
				local area = child.Size.X.Scale * child.Size.Y.Scale
				if area < iconArea then
					icon, iconArea = child, area
				end
			end
		end
		if icon and reward and iconArea < 0.5 then
			icon.Image = DailyRewards.GetRewardIconImage(reward)
		end
		if dayLabel then dayLabel.Text = "Day " .. day end
		if amountLabel then amountLabel.Text = DailyRewards.GetRewardText(reward) end
		if statusLabel then statusLabel.Text = "" end
		cards[day] = {Frame = card, Day = dayLabel, Amount = amountLabel, Status = statusLabel, Locked = card:FindFirstChild("Locked"), Reward = reward, Icon = if iconArea < 0.5 then icon else nil}
	end
end
local claimButtonBaseColor = claimButton and claimButton.ImageColor3 or nil

-- 2026-09-26 (owner): "it doesn't show the REAL spin icon like in Quests". A Spin reward's card
-- shows the real spin wheel, as the Quests panel does (UI/QuestController.attachSpinWheelReward):
-- a copy of the Main HUD's Spin button wheel (Mainhud.SpinWheel.Icon.Spinner and its HubCap,
-- made by UI/SpinWheelController) over the card's reward picture, which hides, turning slowly
-- while the panel is open. Until the HUD wheel exists the picture keeps the static art.
local spinWheelIcons = {}
local function attachSpinWheel(picture)
	local existing = picture:FindFirstChild("WheelSpinner")
	if existing then
		return existing
	end
	local mainhud = playerGui:FindFirstChild("Mainhud")
	local hudSpin = mainhud and mainhud:FindFirstChild("SpinWheel")
	local hudIcon = hudSpin and hudSpin:FindFirstChild("Icon")
	local hudSpinner = hudIcon and hudIcon:FindFirstChild("Spinner")
	if not hudSpinner then
		return nil
	end
	local spinner = hudSpinner:Clone()
	spinner.Name = "WheelSpinner"
	spinner.AnchorPoint = Vector2.new(0.5, 0.5)
	spinner.Position = UDim2.fromScale(0.5, 0.5)
	spinner.Size = UDim2.fromScale(1, 1)
	spinner.Rotation = 0
	spinner.ZIndex = picture.ZIndex + 1
	local hudCap = hudIcon:FindFirstChild("HubCap")
	if hudCap then
		local cap = hudCap:Clone()
		cap.AnchorPoint = Vector2.new(0.5, 0.5)
		cap.Position = UDim2.fromScale(0.5, 0.5)
		cap.ZIndex = spinner.ZIndex + 1
		cap.Parent = spinner
	end
	spinner.Parent = picture
	return spinner
end
local function ensureSpinWheelIcons()
	for _, card in pairs(cards) do
		if card.Icon and card.Reward and card.Reward.Type == "SpinTicket" and not spinWheelIcons[card.Icon] then
			local spinner = attachSpinWheel(card.Icon)
			if spinner then
				card.Icon.ImageTransparency = 1
				spinWheelIcons[card.Icon] = spinner
			end
		end
	end
end

-- The claim button used to stay bright and clickable on a day that was already
-- claimed, so players kept pressing it and nothing happened.
local function setClaimEnabled(enabled)
	if not claimButton then return end
	claimButton.Active = enabled
	claimButton.AutoButtonColor = enabled
	if claimButtonBaseColor then
		claimButton.ImageColor3 = if enabled
			then claimButtonBaseColor
			else Color3.new(claimButtonBaseColor.R * 0.45, claimButtonBaseColor.G * 0.45, claimButtonBaseColor.B * 0.45)
	end
	if claimLabel and claimLabel:IsA("TextLabel") then
		claimLabel.TextTransparency = enabled and 0 or 0.35
	end
end

local state
local open = false
local stateReceivedAt = 0
local baseSecondsRemaining = 0

local function formatRemainingTime(seconds)
	seconds = math.max(0, math.floor(tonumber(seconds) or 0))
	local d = math.floor(seconds / 86400)
	local h = math.floor((seconds % 86400) / 3600)
	local m = math.floor((seconds % 3600) / 60)
	local s = math.floor(seconds % 60)
	if d > 0 then
		return string.format("%dd %dh %dm", d, h, m)
	elseif h > 0 then
		return string.format("%dh %dm %ds", h, m, s)
	elseif m > 0 then
		return string.format("%dm %ds", m, s)
	else
		return string.format("%ds", s)
	end
end

local function getRemainingSeconds()
	if not state or state.CanClaim then
		return 0
	end
	local elapsed = os.clock() - stateReceivedAt
	return math.max(0, baseSecondsRemaining - elapsed)
end

local function refresh()
	local claimed = {}
	for _, day in ipairs((state and state.ClaimedDays) or {}) do claimed[tonumber(day)] = true end
	local nextDay = tonumber(state and state.NextDay) or 1
	-- "Today" only while the next reward is ready to claim; until then it just waits.
	local ready = state ~= nil and (state.CanClaim == true or getRemainingSeconds() <= 0)
	for day, card in pairs(cards) do
		-- Every day before the next one in this cycle has been claimed (the server's list
		-- says so too); only the next day can be.
		local isClaimed = claimed[day] == true or day < nextDay
		local isToday = day == nextDay and not isClaimed and ready
		if card.Status then
			card.Status.Text = isClaimed and "Claimed" or (isToday and "Today" or "")
			-- Days 2-30 ship with their status label hidden (only Day 1's was visible), so
			-- "Claimed" never showed on them.
			card.Status.Visible = card.Status.Text ~= ""
		end
		if card.Locked then card.Locked.Visible = day > nextDay and not isClaimed end
		if card.Shade then card.Shade.Visible = isClaimed end
		card.Frame.BackgroundTransparency = isClaimed and 0.5 or 0
	end
	if state then
		local reward = DailyRewards.GetReward(nextDay)
		local rem = getRemainingSeconds()
		if state.CanClaim or rem <= 0 then
			resultLabel.Text = "Day " .. nextDay .. " ready: " .. DailyRewards.GetRewardText(reward)
			if claimLabel then claimLabel.Text = "Claim" end
			setClaimEnabled(true)
		else
			resultLabel.Text = "Next reward in: " .. formatRemainingTime(rem)
			if claimLabel then claimLabel.Text = "Claimed" end
			setClaimEnabled(false)
		end
	end
end

-- Every day card shipped with LayoutOrder = 0, so a SortOrder.LayoutOrder list had
-- nothing to sort by and the days could lay out in any order. Number them.
for day, card in pairs(cards) do
	card.Frame.LayoutOrder = day
end

-- Thirty cards in a scrolling list always opened on Day 1, so the player had to
-- hunt for the day they could actually claim. Put it on screen instead. The list
-- is horizontal today; read the layout rather than assuming an axis.
local function scrollToClaimableDay()
	local nextDay = tonumber(state and state.NextDay) or 1
	local card = cards[nextDay] and cards[nextDay].Frame
	if not card or not scroll then return end

	local layout = scroll:FindFirstChildOfClass("UIListLayout")
	local horizontal = layout == nil or layout.FillDirection == Enum.FillDirection.Horizontal

	local canvas = scroll.AbsoluteCanvasSize
	local window = scroll.AbsoluteSize
	local current = scroll.CanvasPosition
	if horizontal then
		local target = card.AbsolutePosition.X - scroll.AbsolutePosition.X + current.X
		local centred = target - (window.X * 0.5) + (card.AbsoluteSize.X * 0.5)
		scroll.CanvasPosition = Vector2.new(math.clamp(centred, 0, math.max(0, canvas.X - window.X)), current.Y)
	else
		local target = card.AbsolutePosition.Y - scroll.AbsolutePosition.Y + current.Y
		local centred = target - (window.Y * 0.5) + (card.AbsoluteSize.Y * 0.5)
		scroll.CanvasPosition = Vector2.new(current.X, math.clamp(centred, 0, math.max(0, canvas.Y - window.Y)))
	end
end

local dim = gui:WaitForChild("Dim")
dim.ZIndex = 0
dim.Active = false
dim.Visible = false
dim.BackgroundTransparency = 1

daysFrame.ZIndex = 10
for _, desc in ipairs(daysFrame:GetDescendants()) do
	if desc:IsA("GuiObject") and desc.ZIndex < 10 then
		desc.ZIndex = desc.ZIndex + 10
	end
end

-- A claimed day is shaded over its art, its day, reward and "Claimed" on top of the shade.
for _, card in pairs(cards) do
	local frame = card.Frame
	local shade = Instance.new("Frame")
	shade.Name = "ClaimedShade"
	shade.AnchorPoint = Vector2.new(0.5, 0.5)
	shade.Position = UDim2.fromScale(0.5, 0.5)
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundColor3 = Color3.fromRGB(12, 30, 52)
	shade.BackgroundTransparency = 0.45
	shade.BorderSizePixel = 0
	shade.Visible = false
	local corner = frame:FindFirstChildOfClass("UICorner")
	if corner then
		corner:Clone().Parent = shade
	end
	local top = frame.ZIndex
	for _, child in ipairs(frame:GetChildren()) do
		if child:IsA("GuiObject") then
			top = math.max(top, child.ZIndex)
		end
	end
	shade.ZIndex = top + 1
	for _, key in ipairs({ "Day", "Amount", "Status" }) do
		if card[key] then
			card[key].ZIndex = shade.ZIndex + 1
		end
	end
	shade.Parent = frame
	card.Shade = shade
end

local OPEN_POS = UDim2.new(0.5, 0, 0.44, 0)
local CLOSED_POS = UDim2.new(0.5, 0, 1.28, 0)

-- The days: a clear gap between the cards, and room at both ends of the list.
do
	local layout = scroll:FindFirstChildOfClass("UIListLayout")
	if layout then
		layout.Padding = UDim.new(0, 6)
	end
	if not scroll:FindFirstChildOfClass("UIPadding") then
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, 6)
		padding.PaddingRight = UDim.new(0, 6)
		padding.Parent = scroll
	end
end

-- The panel always stays whole on the screen (2026-09-18, Sung: it ran off the right edge
-- and "Claim" could not be reached): measured as it really shows, it is shrunk to at most
-- FIT_SHARE of the screen each way, centred. On most screens it is well under that and
-- keeps the designer's size.
local FIT_SHARE = 0.76
local AUTHORED_SIZE = daysFrame.Size
-- Phones: how much bigger MenuPanelLayout.BindPhoneFit draws it (below), already inside the
-- screen; 1 everywhere else, where only the shrink applies.
local phoneGrow = 1
local function fitOnScreen()
	local screen = gui.AbsoluteSize
	local shown = daysFrame.AbsoluteSize
	local current = daysFrame.Size.X.Scale / math.max(AUTHORED_SIZE.X.Scale, 1e-6)
	if screen.X <= 0 or screen.Y <= 0 or shown.X <= 0 or shown.Y <= 0 or current <= 0 then
		return
	end
	-- Its size at the designer's Size, whatever else scales it.
	local natural = shown / current
	local fit = if phoneGrow > 1 then phoneGrow else math.min(1, FIT_SHARE * screen.X / natural.X, FIT_SHARE * screen.Y / natural.Y)
	if math.abs(fit - current) > 0.005 then
		daysFrame.Size = UDim2.new(AUTHORED_SIZE.X.Scale * fit, AUTHORED_SIZE.X.Offset, AUTHORED_SIZE.Y.Scale * fit, AUTHORED_SIZE.Y.Offset)
	end
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitOnScreen)
daysFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitOnScreen)

-- The Claim button is always on top and pressable.
if claimButton then
	claimButton.Visible = true
	claimButton.ZIndex = math.max(claimButton.ZIndex, 20)
end

-- Phones: at the designer's Size the window is 238 x 186 px on an 812 x 375 phone (Claim
-- 66 x 24 px). MenuPanelLayout draws it bigger on compact touch screens (its shape kept, 84% of
-- the height under the top bar), centred there and slid in from wholly below the screen.
MenuPanelLayout.BindPhoneFit(gui, daysFrame, OPEN_POS, CLOSED_POS, function(fit)
	OPEN_POS, CLOSED_POS = fit.Open, fit.Closed
	phoneGrow = fit.Grow
	fitOnScreen()
end)

daysFrame.AnchorPoint = Vector2.new(0.5, 0.5)
daysFrame.Position = CLOSED_POS

-- Remove any UIScale so it matches Shop size exactly
for _, child in ipairs(daysFrame:GetChildren()) do
	if child:IsA("UIScale") then
		child:Destroy()
	end
end

local openTween, dimTween
local isClosing = false

-- Update 4 (2026-09-25, PLAN §7.7): the only new window that opens by itself. The join chain
-- stays Update Logs -> Daily; when the Daily is closed the first time this session and a
-- streak milestone reward waits (Social/RetentionService sets StreakRewardPending), the Streak
-- panel opens once. Never during the tutorial, never over another open menu.
local streakOfferDone = false
local function openStreakAfterFirstClose()
	if streakOfferDone then return end
	streakOfferDone = true
	if player:GetAttribute("StreakRewardPending") ~= true or player:GetAttribute("FirstTimeTutorialActive") == true then
		return
	end
	if MenuEvents.AnyOpen("Streak") then return end
	MenuEvents.Request("Streak")
end

local function closePanel(instant)
	if not open and not gui.Enabled then return end
	if instant then
		isClosing = false
		open = false
		if openTween then openTween:Cancel() end
		if dimTween then dimTween:Cancel() end
		gui.Enabled = false
		daysFrame.Visible = false
		daysFrame.Position = CLOSED_POS
		if dim then
			dim.Visible = false
			dim.Active = false
			dim.BackgroundTransparency = 1
		end
		return
	end

	if isClosing then return end
	isClosing = true

	if dim then
		if dimTween then dimTween:Cancel() end
		dimTween = TweenService:Create(dim, TweenInfo.new(0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.In), { BackgroundTransparency = 1 })
		dimTween:Play()
	end
	if openTween then openTween:Cancel() end
	openTween = TweenService:Create(daysFrame, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = CLOSED_POS })
	openTween:Play()
	task.delay(0.18, function()
		if not isClosing then return end
		isClosing = false
		open = false
		gui.Enabled = false
		daysFrame.Visible = false
		daysFrame.Position = CLOSED_POS
		if dim then
			dim.Visible = false
			dim.Active = false
		end
		openStreakAfterFirstClose()
	end)
end

local countdownThread = nil
local function startCountdown()
	if countdownThread then return end
	countdownThread = task.spawn(function()
		while open do
			task.wait(1)
			if not open then break end
			if state and not state.CanClaim then
				local rem = getRemainingSeconds()
				if rem <= 0 then
					if request then request:FireServer("Refresh") end
					break
				else
					resultLabel.Text = "Next reward in: " .. formatRemainingTime(rem)
				end
			end
		end
		countdownThread = nil
	end)
end

local function openPanel()
	if open and gui.Enabled and not isClosing then return end
	isClosing = false
	open = true
	gui.Enabled = true
	daysFrame.Visible = true
	daysFrame.Position = CLOSED_POS
	if dim then
		dim.Visible = true
		dim.Active = true
		dim.BackgroundTransparency = 1
		if dimTween then dimTween:Cancel() end
		dimTween = TweenService:Create(dim, TweenInfo.new(0.20, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { BackgroundTransparency = 0.55 })
		dimTween:Play()
	end
	if openTween then openTween:Cancel() end
	openTween = TweenService:Create(daysFrame, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = OPEN_POS })
	openTween:Play()
	fitOnScreen()
	ensureSpinWheelIcons()
	if request then request:FireServer("Refresh") end
	refresh()
	task.defer(scrollToClaimableDay)
	startCountdown()
end

-- The Spin cards' wheels turn like the Quests panel's while the panel is open (45 degrees a second).
game:GetService("RunService").RenderStepped:Connect(function()
	if not open or next(spinWheelIcons) == nil then
		return
	end
	local rotation = (os.clock() * 45) % 360
	for _, spinner in pairs(spinWheelIcons) do
		spinner.Rotation = rotation
	end
end)

if dim then
	dim.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			closePanel()
		end
	end)
end

if closeButton then
	closeButton.Activated:Connect(function() closePanel() end)
end
-- Claim asks whenever the button says Claim (the day ready, or its countdown run out
-- here before the server's next word); the server decides. It used to ask only when the
-- last state said so, and a countdown that ran out left "Claim" doing nothing.
local function claimReady()
	return state == nil or state.CanClaim == true or getRemainingSeconds() <= 0
end
if claimButton then
	claimButton.Activated:Connect(function()
		if request and claimReady() then
			request:FireServer("Claim")
		end
	end)
end
MenuEvents.Get("OpenDailyPanel").Event:Connect(function(action)
	if action == "Open" or action == "LeftButtonSwitch" then
		openPanel()
	elseif action == "Close" then
		closePanel()
	else
		if open then closePanel() else openPanel() end
	end
end)
MenuEvents.CloseAll.Event:Connect(function(exceptMenuName)
	if exceptMenuName ~= "Daily" then
		closePanel(true)
	end
end)
-- A closing panel counts as closed, so reopening it quickly opens it (MenuEvents).
MenuEvents.MarkReady("Daily", function() return open and not isClosing end)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.Escape and open then
		closePanel()
	end
end)
if update then
	update.OnClientEvent:Connect(function(value)
		if type(value) == "table" then
			local hadState = state ~= nil
			state = value
			stateReceivedAt = os.clock()
			baseSecondsRemaining = tonumber(state.SecondsRemaining) or 0
			refresh()
			if open and not hadState then
				task.defer(scrollToClaimableDay)
			end
		end
	end)
end
if request then request:FireServer("Refresh") end
closePanel(true)
