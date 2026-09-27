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
local request = Remotes:FindFirstChild("DailyLoginRequest")
local update = Remotes:FindFirstChild("DailyLoginUpdate")
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
		for _, label in ipairs(card:GetChildren()) do
			if label:IsA("TextLabel") then
				local text = tostring(label.Text)
				if text:match("^Day") then dayLabel = label elseif text == "Today" or text == "Claimed" then statusLabel = label elseif text:find("Victory") or text:find("Speed") then amountLabel = label end
			end
		end
		local reward = DailyRewards.GetReward(day)
		if dayLabel then dayLabel.Text = "Day " .. day end
		if amountLabel then amountLabel.Text = DailyRewards.GetRewardText(reward) end
		if statusLabel then statusLabel.Text = "" end
		cards[day] = {Frame = card, Day = dayLabel, Amount = amountLabel, Status = statusLabel, Locked = card:FindFirstChild("Locked"), Reward = reward}
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
	for day, card in pairs(cards) do
		local isClaimed = claimed[day] == true
		local isToday = day == nextDay and not isClaimed
		if card.Status then card.Status.Text = isClaimed and "Claimed" or (isToday and "Today" or "") end
		if card.Locked then card.Locked.Visible = day > nextDay and not isClaimed end
		card.Frame.BackgroundTransparency = isClaimed and 0.5 or 0
	end
	if state then
		local reward = DailyRewards.GetReward(nextDay)
		local rem = getRemainingSeconds()
		if state.CanClaim or rem <= 0 then
			resultLabel.Text = "Day " .. nextDay .. " ready: " .. DailyRewards.GetRewardText(reward)
			if claimLabel then claimLabel.Text = "Claim" end
		else
			resultLabel.Text = "Next reward in: " .. formatRemainingTime(rem)
			if claimLabel then claimLabel.Text = "Claimed" end
		end
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

local OPEN_POS = UDim2.new(0.5, 0, 0.48, 0)
local CLOSED_POS = UDim2.new(0.5, 0, 1.28, 0)

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
	if request then request:FireServer("Refresh") end
	refresh()
	startCountdown()
end

if dim then
	dim.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			closePanel()
		end
	end)
end

if closeButton then
	closeButton.Activated:Connect(function() closePanel() end)
	if closeButton:IsA("GuiButton") then
		closeButton.MouseButton1Click:Connect(function() closePanel() end)
	end
	closeButton.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			closePanel()
		end
	end)
end
if claimButton then claimButton.Activated:Connect(function() if state and state.CanClaim and request then request:FireServer("Claim") end end) end
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
MenuEvents.MarkReady("Daily", function() return open end)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.Escape and open then
		closePanel()
	end
end)
if update then
	update.OnClientEvent:Connect(function(value)
		if type(value) == "table" then
			state = value
			stateReceivedAt = os.clock()
			baseSecondsRemaining = tonumber(state.SecondsRemaining) or 0
			refresh()
		end
	end)
end
if request then request:FireServer("Refresh") end
closePanel(true)