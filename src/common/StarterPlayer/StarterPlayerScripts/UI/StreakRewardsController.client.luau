-- StreakRewardsController.client.luau (Update 4, 2026-09-25)
-- The designer's "Streak Rewards" panel (uineww.rbxm, put in StarterGui by the build), used as
-- it is: root frame "Streak Rewards" with Title, Close, Descri, Speed (two labels both named
-- "Speed": the multiplier and the "+10% each day" note), Info (the 7/14/21 marker frames and
-- labels of the same names), Icon (with the day count in Icon.Time), Bar/Fill, the Choose
-- button (the designer's text says "Return to Offline Reward"; it becomes CLAIM / the
-- countdown) and three reward frames all named "Item1", left to right = days 7 / 14 / 21.
-- Opens through MenuEvents "Streak" (the topbar icon, and once after the Daily closes when a
-- reward waits: UI/DailyRewardController). Social/RetentionService decides everything; CLAIM
-- asks it to pay the oldest pending milestone.
-- Duplicated names are told apart by class and position, never by FindFirstChild.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local MenuEvents = require(Shared:WaitForChild("MenuEvents"))

local gui = playerGui:WaitForChild("Streak Rewards", 8)
local window = gui and gui:WaitForChild("Streak Rewards", 5)
if not gui or not gui:IsA("ScreenGui") or not window or not window:IsA("GuiObject") then
	-- The designer's panel is not in this place yet (the build puts it there).
	warn("[StreakRewardsController] 'Streak Rewards' panel not found; the streak has no window")
	return
end
gui.ResetOnSpawn = false

local U4 = require(Shared:WaitForChild("Update4Config"))
local RetentionMath = require(Shared:WaitForChild("RetentionMath"))
local QuestCatalog = require(Shared:WaitForChild("QuestCatalog"))
local MenuPanelLayout = require(Shared:WaitForChild("MenuPanelLayout"))
local ModalJuice = require(Shared:WaitForChild("ModalJuice"))
local ConsolePanelSupport = require(Shared:WaitForChild("ConsolePanelSupport"))
local TutorialText = require(Shared:WaitForChild("TutorialText"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Request = Remotes:WaitForChild("RetentionRequest", 30)
local Update = Remotes:WaitForChild("RetentionUpdate", 30)

local STREAK = U4.Streak
local lang = TutorialText.ForPlayer(player)
local READY_COLOR = Color3.fromRGB(85, 255, 127)
local CLAIMED_COLOR = Color3.fromRGB(255, 214, 64)
local LOCKED_COLOR = Color3.fromRGB(200, 200, 210)
local ICONS = QuestCatalog.RewardIcons or {}

local function childrenOf(parent: Instance?, className: string, name: string?): { any }
	local list = {}
	if parent then
		for _, child in parent:GetChildren() do
			if child:IsA(className) and (name == nil or child.Name == name) then
				table.insert(list, child)
			end
		end
	end
	return list
end
local function firstOf(parent: Instance?, className: string, name: string?): any
	return childrenOf(parent, className, name)[1]
end

-- The designer's pieces, found once.
local closeButton = firstOf(window, "GuiButton", "Close")
local chooseButton = firstOf(window, "GuiButton", "Choose")
local chooseLabel = firstOf(chooseButton, "TextLabel", "Name")
local icon = firstOf(window, "ImageLabel", "Icon")
local daysLabel = firstOf(icon, "TextLabel", "Time")
local bar = firstOf(window, "Frame", "Bar")
local fill = firstOf(bar, "GuiObject", "Fill")
local info = firstOf(window, "Frame", "Info")
-- "Speed" frame: the multiplier is the label whose authored text ends in "Speed"
-- ("x1.0 Speed"), else the upper one (the "+10% each Streak Day" note sits below it).
local speedFrame = firstOf(window, "Frame", "Speed")
local multiplierLabel = nil
do
	local labels = childrenOf(speedFrame, "TextLabel", "Speed")
	table.sort(labels, function(a, b)
		return a.Position.Y.Scale < b.Position.Y.Scale
	end)
	for _, label in labels do
		if string.find(label.Text, "Speed%s*$") then
			multiplierLabel = label
			break
		end
	end
	multiplierLabel = multiplierLabel or labels[1]
end

-- Bar: filled by cycle day between the 7 / 14 / 21 marker frames (≈0.286 / 0.594 / 0.894).
local fillPoints = { { 0, 0 } }
for _, day in RetentionMath.MilestoneDays do
	local marker = firstOf(info, "Frame", tostring(day))
	if marker then
		table.insert(fillPoints, { day, marker.Position.X.Scale })
	end
end
if #fillPoints == 1 then
	fillPoints = { { 0, 0 }, { 21, 1 } }
end
if fill then
	-- The designer's fill is centred and shape-locked; it grows from the bar's left edge here.
	fill.AnchorPoint = Vector2.new(0, 0.5)
	fill.Position = UDim2.fromScale(0, 0.5)
	for _, constraint in fill:GetChildren() do
		if constraint:IsA("UIAspectRatioConstraint") or constraint:IsA("UISizeConstraint") then
			constraint:Destroy()
		end
	end
end

-- The three "Item1" frames, left to right = 7 / 14 / 21. Each gets one status label (made
-- once) and a UIScale on its picture for the READY pulse.
local items = childrenOf(window, "Frame", "Item1")
table.sort(items, function(a, b)
	return a.Position.X.Scale < b.Position.X.Scale
end)
local slots = {}
for index, frame in items do
	local day = RetentionMath.MilestoneDays[index]
	if not day then
		break
	end
	local title = firstOf(frame, "TextLabel", "Speed")
	local picture = firstOf(frame, "ImageLabel", "ImageLabel")
	local status = Instance.new("TextLabel")
	status.Name = "U4Status"
	status.AnchorPoint = Vector2.new(0.5, 0.5)
	status.Position = UDim2.fromScale(0.5, 0.9)
	status.Size = UDim2.fromScale(0.9, 0.2)
	status.BackgroundTransparency = 1
	status.TextScaled = true
	status.AutoLocalize = false
	status.ZIndex = (if title then title.ZIndex else frame.ZIndex) + 1
	if title then
		status.FontFace = title.FontFace
		local stroke = title:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke:Clone().Parent = status
		end
	end
	status.Parent = frame
	local pulse = nil
	if picture then
		pulse = picture:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
		pulse.Parent = picture
	end
	if title then
		title.AutoLocalize = false
	end
	slots[index] = { Day = day, Frame = frame, Title = title, Picture = picture, Status = status, Pulse = pulse }
end
for _, label in { multiplierLabel, daysLabel, chooseLabel } do
	if label then
		label.AutoLocalize = false
	end
end

local state = {
	Days = 0, Best = 0, Perk = 0, CycleDay = 0, Cycle = 1, NextDayUnix = 0, Pending = {}, Claimed = {},
	Enabled = true,
}
local isOpen = false
local claiming = false
-- The server's answer to CLAIM ("Nothing to claim yet"...) shows on the button for a moment.
local message, messageUntil = nil, 0

-- Until the server's first answer, the published attribute says whether CLAIM can pay (the
-- panel opened straight after the Daily must not show the countdown for a moment).
local heardServer = false
local function hasPending(): boolean
	return #state.Pending > 0 or (not heardServer and player:GetAttribute("StreakRewardPending") == true)
end

local function streakState()
	return { StreakPending = state.Pending, StreakClaimed = state.Claimed }
end

local function rewardText(reward): string
	if reward.Day == 21 then
		return RetentionMath.Text("Chest", lang)
	end
	if reward.Perk > 0 then
		return RetentionMath.Text("SpeedTimes", lang, RetentionMath.FormatMultiplier(1 + reward.Perk))
	end
	return RetentionMath.Text("Spins", lang, reward.SpinTickets)
end

local function rewardIcon(reward): string?
	-- The designer left placeholders in all three: the chest shows its headline potion.
	if reward.Day == 21 then
		return ICONS.PotionSpeed
	end
	if reward.Perk > 0 then
		return ICONS.Speed
	end
	return ICONS.SpinTicket
end

local function pendingFor(day: number): string?
	for _, key in state.Pending do
		local _, keyDay = RetentionMath.ParseKey(key)
		if keyDay == day then
			return key
		end
	end
	return nil
end

local function setPulse(slot, on: boolean)
	if not slot.Pulse then
		return
	end
	if on and not slot.Tween then
		slot.Pulse.Scale = 1
		slot.Tween = TweenService:Create(slot.Pulse, TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.12 })
		slot.Tween:Play()
	elseif not on and slot.Tween then
		slot.Tween:Cancel()
		slot.Tween = nil
		slot.Pulse.Scale = 1
	end
end

-- 2026-09-26 (owner): Spin rewards show the real spin wheel, as the Quests panel does
-- (UI/QuestController.attachSpinWheelReward): a copy of the Main HUD's Spin button wheel
-- (Mainhud.SpinWheel.Icon.Spinner and its HubCap, made by UI/SpinWheelController) over the
-- reward picture, which hides, turning while the panel is open. Until the HUD wheel exists the
-- picture keeps the static art; another reward on the slot puts the picture back.
local spinWheels = {}
local function showSpinWheel(picture: ImageLabel, on: boolean)
	local spinner = picture:FindFirstChild("WheelSpinner")
	if on and not spinner then
		local mainhud = playerGui:FindFirstChild("Mainhud")
		local hudSpin = mainhud and mainhud:FindFirstChild("SpinWheel")
		local hudIcon = hudSpin and hudSpin:FindFirstChild("Icon")
		local hudSpinner = hudIcon and hudIcon:FindFirstChild("Spinner")
		if hudSpinner and hudSpinner:IsA("GuiObject") then
			local copy = hudSpinner:Clone() :: GuiObject
			copy.Name = "WheelSpinner"
			copy.AnchorPoint = Vector2.new(0.5, 0.5)
			copy.Position = UDim2.fromScale(0.5, 0.5)
			copy.Size = UDim2.fromScale(1, 1)
			copy.Rotation = 0
			copy.ZIndex = picture.ZIndex + 1
			local hudCap = hudIcon:FindFirstChild("HubCap")
			if hudCap and hudCap:IsA("GuiObject") then
				local cap = hudCap:Clone() :: GuiObject
				cap.AnchorPoint = Vector2.new(0.5, 0.5)
				cap.Position = UDim2.fromScale(0.5, 0.5)
				cap.ZIndex = copy.ZIndex + 1
				cap.Parent = copy
			end
			copy.Parent = picture
			spinner = copy
		end
	end
	if spinner and spinner:IsA("GuiObject") then
		spinner.Visible = on
		spinWheels[spinner] = if on then true else nil
		picture.ImageTransparency = if on then 1 else 0
	end
end

local function paintItems()
	for _, slot in slots do
		local key = pendingFor(slot.Day)
		-- The reward this milestone pays next: the pending one, else the key it would be filed
		-- under this cycle (a cycle's first rewards come once per account).
		local nextKey = key or RetentionMath.KeyFor(streakState(), state.Cycle, slot.Day)
		local reward = RetentionMath.MilestoneReward(nextKey, STREAK)
		if reward then
			if slot.Title then
				slot.Title.Text = rewardText(reward)
			end
			local image = rewardIcon(reward)
			if slot.Picture and image then
				slot.Picture.Image = image
				showSpinWheel(slot.Picture, image == ICONS.SpinTicket)
			end
		end
		local status, color
		if key then
			status, color = RetentionMath.Text("StatusReady", lang), READY_COLOR
		elseif state.CycleDay >= slot.Day then
			status, color = RetentionMath.Text("StatusClaimed", lang), CLAIMED_COLOR
		else
			status, color = RetentionMath.Text("StatusLocked", lang, slot.Day), LOCKED_COLOR
		end
		slot.Status.Text = status
		slot.Status.TextColor3 = color
		setPulse(slot, isOpen and key ~= nil)
	end
end

local function paintChoose()
	if not chooseButton then
		return
	end
	local ready = state.Enabled and hasPending()
	chooseButton.Active = ready and not claiming
	chooseButton.AutoButtonColor = ready
	if chooseLabel then
		if message and os.clock() < messageUntil then
			chooseLabel.Text = message
		elseif ready then
			chooseLabel.Text = RetentionMath.Text("Claim", lang)
		else
			local left = math.max(0, (tonumber(state.NextDayUnix) or 0) - Workspace:GetServerTimeNow())
			chooseLabel.Text = RetentionMath.Text("NextDay", lang, RetentionMath.FormatClock(left))
		end
	end
end

local function paint()
	local days = if state.Enabled then state.Days else 0
	if daysLabel then
		daysLabel.Text = tostring(days)
	end
	if multiplierLabel then
		local multiplier = 1 + RetentionMath.StreakBonus(days, STREAK) + (if state.Enabled then state.Perk else 0)
		multiplierLabel.Text = RetentionMath.Text("SpeedTimes", lang, RetentionMath.FormatMultiplier(multiplier))
	end
	if fill then
		local frac = math.clamp(RetentionMath.PiecewiseFill(state.CycleDay, fillPoints), 0, 1)
		fill.Size = UDim2.fromScale(frac, 1)
		fill.Visible = frac > 0.002
	end
	paintItems()
	paintChoose()
end

-- Until the server answers, the attributes it publishes are enough to draw the panel.
local function fromAttributes()
	state.Days = math.max(0, math.floor(tonumber(player:GetAttribute("StreakDays")) or 0))
	state.Perk = math.clamp(tonumber(player:GetAttribute("StreakPerk")) or 0, 0, RetentionMath.MaxPerk)
	state.CycleDay = RetentionMath.CycleDay(state.Days, STREAK)
	state.Cycle = RetentionMath.Cycle(state.Days, STREAK)
	state.NextDayUnix = tonumber(player:GetAttribute("StreakNextDayUnix")) or 0
end
fromAttributes()

-- The countdown ticks once a second while open; nothing runs while it is closed.
local ticker = nil
local function startTicker()
	if ticker then
		return
	end
	ticker = task.spawn(function()
		while isOpen do
			paintChoose()
			task.wait(1)
		end
		ticker = nil
	end)
end

local OPEN_POS = window.Position
-- 2026-09-26 (owner): "too low, move it up a little and make it a bit smaller": on phones the
-- window and its header take 80% of the room (was about 96%), raised 4% of it (PhoneBlock).
MenuPanelLayout.BindPhoneFit(gui, window, OPEN_POS, OPEN_POS, function(fit)
	OPEN_POS = fit.Open
	if isOpen then
		window.Position = OPEN_POS
	end
end, nil, MenuPanelLayout.PhoneBlock)
ModalJuice.WatchGui(gui)

local function open()
	if isOpen then
		return
	end
	isOpen = true
	window.Position = OPEN_POS
	window.Visible = true
	gui.Enabled = true
	paint()
	startTicker()
	if Request then
		Request:FireServer("Get", "Streak")
	end
end

local function close()
	if not isOpen then
		return
	end
	isOpen = false
	gui.Enabled = false
	for _, slot in slots do
		setPulse(slot, false)
	end
end

-- The Spin rewards' wheels turn like the Quests panel's while the panel is open (45 degrees a second).
game:GetService("RunService").RenderStepped:Connect(function()
	if not isOpen or next(spinWheels) == nil then
		return
	end
	local rotation = (os.clock() * 45) % 360
	for spinner in spinWheels do
		spinner.Rotation = rotation
	end
end)

local function claim()
	if claiming or not Request or not hasPending() then
		return
	end
	claiming = true
	paintChoose()
	Request:FireServer("ClaimStreak")
	-- The answer (RetentionUpdate) clears this; a lost answer must not lock the button.
	task.delay(3, function()
		if claiming then
			claiming = false
			paintChoose()
		end
	end)
end

if chooseButton then
	chooseButton.Activated:Connect(claim)
end
if closeButton then
	closeButton.Activated:Connect(function()
		if isOpen then
			MenuEvents.Request("Streak")
		end
	end)
end
ConsolePanelSupport.Bind(gui, window, chooseButton, closeButton, function()
	if isOpen then
		MenuEvents.Request("Streak")
	end
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.Escape and isOpen then
		MenuEvents.Request("Streak")
	end
end)

if Update then
	Update.OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" or type(payload.Streak) ~= "table" then
			return
		end
		local s = payload.Streak
		heardServer = true
		state.Days = math.max(0, math.floor(tonumber(s.Days) or 0))
		state.Best = math.max(0, math.floor(tonumber(s.Best) or 0))
		state.Perk = math.clamp(tonumber(s.Perk) or 0, 0, RetentionMath.MaxPerk)
		state.CycleDay = math.clamp(math.floor(tonumber(s.CycleDay) or 0), 0, 21)
		state.Cycle = math.max(1, math.floor(tonumber(s.Cycle) or 1))
		state.NextDayUnix = tonumber(s.NextDayUnix) or 0
		state.Pending = if type(s.Pending) == "table" then s.Pending else {}
		state.Claimed = if type(s.Claimed) == "table" then s.Claimed else {}
		state.Enabled = s.Enabled ~= false
		if type(payload.Message) == "string" and payload.Message ~= "" and claiming then
			message, messageUntil = payload.Message, os.clock() + 2.5
		end
		claiming = false
		paint()
	end)
end
for _, attribute in { "StreakDays", "StreakPerk", "StreakNextDayUnix", "StreakRewardPending" } do
	player:GetAttributeChangedSignal(attribute):Connect(function()
		fromAttributes()
		if isOpen then
			paint()
			if attribute == "StreakRewardPending" and Request then
				Request:FireServer("Get")
			end
		end
	end)
end

MenuEvents.Get("OpenStreakPanel").Event:Connect(function(action)
	if action == "Close" then
		close()
	elseif action == "Open" then
		open()
	elseif isOpen then
		close()
	else
		open()
	end
end)
MenuEvents.CloseAll.Event:Connect(function(except)
	if except ~= "Streak" then
		close()
	end
end)
MenuEvents.MarkReady("Streak", function()
	return isOpen
end)
gui.Enabled = false
paint()
