local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Catalog = require(ReplicatedStorage.Shared.PlaytimeRewards)
local DailyRewards = require(ReplicatedStorage.Shared.DailyRewards)
local MenuEvents = require(ReplicatedStorage.Shared.MenuEvents)
local MenuPanelLayout = require(ReplicatedStorage.Shared.MenuPanelLayout)

local PlaytimeRewardsRequest = ReplicatedStorage.Remotes:WaitForChild("PlaytimeRewardsRequest")
local PlaytimeRewardsUpdate = ReplicatedStorage.Remotes:WaitForChild("PlaytimeRewardsUpdate")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local ui = playerGui:WaitForChild("TimeGift")
local mainFrame = ui:WaitForChild("TimeGift")
local closeBtn = mainFrame:WaitForChild("Close")
local innerFrame = mainFrame:WaitForChild("Frame")

local isOpen = false
local claimed = {}
local sessionStartedAt = 0
local NUM_DAYS = 15

local function getUnlockSeconds(index)
	return Catalog.GetUnlockSeconds(index)
end

local function formatTime(seconds)
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds % 3600) / 60)
	local s = math.floor(seconds % 60)
	if h > 0 then
		return string.format("%dh %dm %ds", h, m, s)
	elseif m > 0 then
		return string.format("%dm %ds", m, s)
	else
		return string.format("%ds", s)
	end
end

local function updateDayFrame(dayFrame, index, isClaimed, isAvailable, remaining)
	local button = dayFrame:WaitForChild("ImageButton")
	local nameLabel = button:WaitForChild("Name")
	local stroke = dayFrame:FindFirstChildOfClass("UIStroke")

	if isClaimed then
		dayFrame.BackgroundColor3 = Color3.fromRGB(0, 120, 0)
		nameLabel.Text = "Claimed"
		if stroke then stroke.Color = Color3.fromRGB(0, 150, 0) end
	elseif isAvailable then
		dayFrame.BackgroundColor3 = Color3.fromRGB(0, 100, 200)
		nameLabel.Text = "Claim!"
		if stroke then stroke.Color = Color3.fromRGB(0, 150, 255) end
	else
		dayFrame.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
		nameLabel.Text = formatTime(remaining)
		if stroke then stroke.Color = Color3.fromRGB(80, 80, 80) end
	end
end

local function refresh()
	local elapsed = Workspace:GetServerTimeNow() - sessionStartedAt
	for i = 1, NUM_DAYS do
		local dayFrame = innerFrame:FindFirstChild(tostring(i))
		if dayFrame then
			local unlockAt = getUnlockSeconds(i)
			local isClaimed = claimed[i] or false
			local isAvailable = not isClaimed and elapsed >= unlockAt
			local remaining = math.max(0, unlockAt - elapsed)
			updateDayFrame(dayFrame, i, isClaimed, isAvailable, remaining)
		end
	end
end

local function applyState(state)
	if state then
		-- The server sends Claimed as an ARRAY of the claimed indices ({ 2, 3 }); read as a
		-- map it marked the wrong gifts claimed (claimed[1] = 2) and locked gift 1.
		claimed = {}
		for _, index in (if type(state.Claimed) == "table" then state.Claimed else {}) do
			local number = tonumber(index)
			if number then
				claimed[number] = true
			end
		end
		sessionStartedAt = state.SessionStartedAt or 0
	end
	refresh()
end

closeBtn.ZIndex = math.max(closeBtn.ZIndex, 10)
closeBtn.Active = true

for i = 1, NUM_DAYS do
	local dayFrame = innerFrame:FindFirstChild(tostring(i))
	if dayFrame then
		local button = dayFrame:WaitForChild("ImageButton")
		button.ZIndex = math.max(button.ZIndex, 5)
		local function onClaim()
			local elapsed = Workspace:GetServerTimeNow() - sessionStartedAt
			local unlockAt = getUnlockSeconds(i)
			if not claimed[i] and elapsed >= unlockAt then
				PlaytimeRewardsRequest:FireServer("Claim", i)
			end
		end
		button.Activated:Connect(onClaim)
		-- Touch screens: even in the phone-sized window the Claim button is about 41 x 12 px,
		-- so the whole card claims (a see-through button over it, 58 px on an 812 x 375 phone).
		if UserInputService.TouchEnabled then
			local tapArea = Instance.new("TextButton")
			tapArea.Name = "TapArea"
			tapArea.Size = UDim2.fromScale(1, 1)
			tapArea.BackgroundTransparency = 1
			tapArea.Text = ""
			tapArea.AutoButtonColor = false
			tapArea.ZIndex = button.ZIndex + 1
			tapArea.Parent = dayFrame
			tapArea.Activated:Connect(onClaim)
		end
	end
end

local OPEN_POS = UDim2.new(0.5, 0, 0.48, 0)
local CLOSED_POS = UDim2.new(0.5, 0, 1.28, 0)
-- Phones: at the designer's Size the window is 238 x 186 px on an 812 x 375 phone, its 15
-- cards 40 px and their Claim buttons 29 x 8 px. MenuPanelLayout draws it bigger on compact
-- touch screens (its shape kept, 84% of the height under the top bar: 58 px cards), centred
-- there and slid in from wholly below the screen: those are the positions used from then on.
-- 2026-09-26 (owner): "too low, move it up a little and make it a bit smaller": PhoneBlock,
-- the window and its header 80% of the room (was about 92%), raised 4% of it (50 px cards on
-- an 812 x 375 phone, 44+ everywhere).
MenuPanelLayout.BindPhoneFit(ui, mainFrame, OPEN_POS, CLOSED_POS, function(fit)
	OPEN_POS, CLOSED_POS = fit.Open, fit.Closed
end, nil, MenuPanelLayout.PhoneBlock)
local openTween = nil
local dimTween = nil
local isClosing = false

local function closePanel(instant)
	if not isOpen and not ui.Enabled then return end

	local dim = ui:FindFirstChild("Dim")

	if instant then
		isClosing = false
		isOpen = false
		if openTween then openTween:Cancel() end
		if dimTween then dimTween:Cancel() end
		ui.Enabled = false
		mainFrame.Visible = false
		mainFrame.Position = CLOSED_POS
		if dim and dim:IsA("GuiObject") then
			dim.Visible = false
			dim.Active = false
			dim.BackgroundTransparency = 1
		end
		return
	end

	if isClosing then return end
	isClosing = true

	if dim and dim:IsA("GuiObject") then
		if dimTween then dimTween:Cancel() end
		dimTween = TweenService:Create(dim, TweenInfo.new(0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.In), { BackgroundTransparency = 1 })
		dimTween:Play()
	end

	if openTween then openTween:Cancel() end
	openTween = TweenService:Create(mainFrame, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = CLOSED_POS })
	openTween:Play()

	task.delay(0.18, function()
		if not isClosing then return end
		isClosing = false
		isOpen = false
		ui.Enabled = false
		mainFrame.Visible = false
		mainFrame.Position = CLOSED_POS
		if dim and dim:IsA("GuiObject") then
			dim.Visible = false
			dim.Active = false
		end
	end)
end

local function openPanel()
	if isOpen and ui.Enabled and not isClosing then return end
	isClosing = false
	isOpen = true
	ui.Enabled = true
	mainFrame.Visible = true
	mainFrame.Position = CLOSED_POS

	local dim = ui:FindFirstChild("Dim")
	if dim and dim:IsA("GuiObject") then
		dim.Visible = true
		dim.Active = true
		dim.BackgroundTransparency = 1
		if dimTween then dimTween:Cancel() end
		dimTween = TweenService:Create(dim, TweenInfo.new(0.20, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { BackgroundTransparency = 0.55 })
		dimTween:Play()
	end

	if openTween then openTween:Cancel() end
	openTween = TweenService:Create(mainFrame, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = OPEN_POS })
	openTween:Play()

	PlaytimeRewardsRequest:FireServer("Refresh")
end

if closeBtn:IsA("GuiButton") then
	closeBtn.Activated:Connect(closePanel)
end

local function hookDim(dim)
	if dim and dim.Name == "Dim" and dim:IsA("GuiObject") then
		dim.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				closePanel()
			end
		end)
	end
end
local existingDim = ui:FindFirstChild("Dim")
if existingDim then hookDim(existingDim) end
ui.ChildAdded:Connect(hookDim)

PlaytimeRewardsUpdate.OnClientEvent:Connect(function(state)
	applyState(state)
end)

local function handleOpenEvent(action)
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
end

MenuEvents.Get("OpenPlaytimeRewardsPanel").Event:Connect(handleOpenEvent)

-- A closing panel counts as closed, so reopening it quickly opens it (MenuEvents).
MenuEvents.MarkReady("Playtime", function() return isOpen and not isClosing end)

MenuEvents.CloseAll.Event:Connect(closePanel)
closePanel()

task.spawn(function()
	while true do
		task.wait(1)
		if isOpen then
			refresh()
		end
	end
end)

PlaytimeRewardsRequest:FireServer("Refresh")