-- A preview feature: only the players Shared.FeatureGate allows get the panel.
if not require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("FeatureGate")).IsPreviewPlayer(
	game:GetService("Players").LocalPlayer
) then
	return
end
-- QuestController.client.luau
-- Choose Your Destiny: the day's three quests (Social/QuestService) on the designer's
-- panel (design/ui/Quests.rbxm), saved in StarterGui as QuestGui and finished by
-- Shared.QuestUi. Each card lists its three tasks and its rewards; its button picks it
-- (a second tap confirms, since a day has one pick), then follows it: In Progress,
-- Claim! (pulsing), Claimed ✓. The chosen card glows gold and cyan and its tasks fill
-- their bars; the others dim and lock. Under the title, the time until the quests reset.
--
-- Every screen: wide screens show the designer's three cards side by side; phones and
-- narrow windows get the cards in a scroll, each at least 260 px wide with buttons at
-- least 44 px tall (QuestUi.Layout), laid out again whenever the screen changes.
--
-- Opens through MenuEvents ("Quests"): since Update 4 (2026-09-25) from the Dr. Eggman lobby NPC,
-- no longer from the topbar. The NPC shows a "!" while rewards are waiting (the
-- QuestRewardReady attribute) or a quest can be chosen (QuestAvailable).

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local DesignerUiBuilder = require(Shared:WaitForChild("DesignerUiBuilder"))
local QuestGuiSpec = require(Shared:WaitForChild("DesignerUi"):WaitForChild("QuestGui"))
local QuestUi = require(Shared:WaitForChild("QuestUi"))
local QuestCatalog = require(Shared:WaitForChild("QuestCatalog"))
local MenuEvents = require(Shared:WaitForChild("MenuEvents"))
local PurchaseButtonSound = require(Shared:WaitForChild("PurchaseButtonSound"))
local SpinWheelLayout = (function()
	local ok, mod = pcall(function()
		return require(Shared:WaitForChild("SpinWheelLayout", 2))
	end)
	return if ok and type(mod) == "table" then mod else nil
end)()

local QuestRequest = Remotes:WaitForChild("QuestRequest")
local QuestUpdate = Remotes:WaitForChild("QuestUpdate")

local CONFIRM_SECONDS = 3
local MESSAGE_SECONDS = 3
-- Asks again this often while the countdown sits at zero and the new day has not come.
local REFRESH_RETRY_SECONDS = 5
-- The designer's labels wrap with a tight line height, so texts join their words with
-- no-break spaces and only break where a line may.
local NBSP = utf8.char(160)
local CONFETTI_COLORS = {
	Color3.fromRGB(255, 214, 40),
	Color3.fromRGB(40, 210, 255),
	Color3.fromRGB(255, 60, 200),
	Color3.fromRGB(80, 230, 90),
	Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(255, 140, 30),
}

local OPEN_INFO = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local CLOSE_INFO = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local PRESS_INFO = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local RELEASE_INFO = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local HOVER_INFO = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local PULSE_INFO = TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local SHINE_INFO = TweenInfo.new(2.5, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1)

local successSound = Instance.new("Sound")
successSound.Name = "QuestSuccessSound"
successSound.SoundId = "rbxassetid://80736831159506"
successSound.Volume = 0.7
successSound.Parent = SoundService

local function glue(text)
	return (string.gsub(tostring(text or ""), " ", NBSP))
end

local activeWheelSpinners: { [Frame]: boolean } = {}
local wheelPrototype, hubCapPrototype, cachedMeasure = nil, nil, nil

local function getWheelPrototypes()
	if wheelPrototype and hubCapPrototype and cachedMeasure then
		return wheelPrototype, hubCapPrototype, cachedMeasure
	end
	local StarterGui = (function()
		local ok, s = pcall(function()
			return game:GetService("StarterGui")
		end)
		return if ok then s else nil
	end)()
	local spinGui = PlayerGui:FindFirstChild("SpinWheelGui") or (StarterGui and StarterGui:FindFirstChild("SpinWheelGui"))
	if not spinGui then
		return nil, nil, nil
	end
	local wheelHolder = spinGui:FindFirstChild("Frame")
	local wheel = wheelHolder and wheelHolder:FindFirstChild("Spin Wheel")
	local hubCap = wheelHolder and wheelHolder:FindFirstChild("HubCap")
	if wheel and hubCap and SpinWheelLayout then
		wheelPrototype = wheel
		hubCapPrototype = hubCap
		cachedMeasure = SpinWheelLayout.Measure(wheelHolder)
		return wheelPrototype, hubCapPrototype, cachedMeasure
	end
	return nil, nil, nil
end

local function attachSpinWheelReward(itemFrame)
	local existing = itemFrame:FindFirstChild("WheelSpinner")
	if existing and existing:IsA("Frame") then
		return existing
	end

	local mainhud = PlayerGui:FindFirstChild("Mainhud")
	local hudSpin = mainhud and mainhud:FindFirstChild("SpinWheel")
	local hudIcon = hudSpin and hudSpin:FindFirstChild("Icon")
	local hudSpinner = hudIcon and hudIcon:FindFirstChild("Spinner")
	local hudCap = hudIcon and hudIcon:FindFirstChild("HubCap")
	if hudSpinner then
		local spinner = hudSpinner:Clone()
		spinner.Name = "WheelSpinner"
		spinner.AnchorPoint = Vector2.new(0.5, 0.5)
		spinner.Position = UDim2.fromScale(0.5, 0.5)
		spinner.Size = UDim2.fromScale(1, 1)
		spinner.ZIndex = itemFrame.ZIndex + 1
		if hudCap then
			local cap = hudCap:Clone()
			cap.AnchorPoint = Vector2.new(0.5, 0.5)
			cap.Position = UDim2.fromScale(0.5, 0.5)
			cap.ZIndex = spinner.ZIndex + 1
			cap.Parent = spinner
		end
		spinner.Parent = itemFrame
		return spinner
	end

	local wheel, hubCap, measure = getWheelPrototypes()
	if not wheel or not hubCap or not measure then
		return nil
	end

	local spinner = Instance.new("Frame")
	spinner.Name = "WheelSpinner"
	spinner.BackgroundTransparency = 1
	spinner.AnchorPoint = Vector2.new(0.5, 0.5)
	spinner.Position = UDim2.fromScale(0.5, 0.5)
	spinner.Size = UDim2.fromScale(1, 1)
	spinner.ZIndex = itemFrame.ZIndex + 1

	local mini = wheel:Clone()
	local prizes = mini:FindFirstChild("Spin")
	if prizes then
		prizes:Destroy()
	end
	local ratio = mini:FindFirstChildOfClass("UIAspectRatioConstraint")
	if ratio then
		ratio:Destroy()
	end
	local diameter = 2 * measure.ArtRadius
	mini.AnchorPoint = Vector2.new(0, 0)
	mini.Rotation = 0
	mini.Size = UDim2.fromScale(measure.WheelWidth / diameter, measure.WheelHeight / diameter)
	mini.Position = UDim2.fromScale(0.5 - measure.ArtCenter.x / diameter, 0.5 - measure.ArtCenter.y / diameter)
	mini.ZIndex = spinner.ZIndex
	mini.Parent = spinner

	local cap = hubCap:Clone()
	cap.AnchorPoint = Vector2.new(0.5, 0.5)
	cap.Position = UDim2.fromScale(0.5, 0.5)
	local capShare = if SpinWheelLayout and SpinWheelLayout.HubCapRadiusShare then SpinWheelLayout.HubCapRadiusShare else 0.14
	cap.Size = UDim2.fromScale(2 * capShare, 2 * capShare)
	cap.ZIndex = spinner.ZIndex + 1
	cap.Parent = spinner

	spinner.Parent = itemFrame
	return spinner
end

----------------------------------------------------------------------
-- The panel
----------------------------------------------------------------------
-- The saved panel (StarterGui.QuestGui); a place without it builds the designer's layout.
local gui = PlayerGui:FindFirstChild("QuestGui") or PlayerGui:WaitForChild("QuestGui", 8)
if not gui then
	gui = DesignerUiBuilder.Build(QuestGuiSpec)
	gui.Name = "QuestGui"
end
QuestUi.Decorate(gui)
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = PlayerGui
-- A saved copy arriving after the wait (a late first spawn) would be a second panel of the
-- same name, which MenuEvents could find instead of this one.
PlayerGui.ChildAdded:Connect(function(child)
	if child ~= gui and child.Name == "QuestGui" then
		child:Destroy()
	end
end)

local frame = gui:WaitForChild("Frame")
local panelScale = frame:FindFirstChild("UIScale")
local timer = frame:FindFirstChild("Timer")
local closeButton = frame:FindFirstChild("Close")
local scroller = frame:FindFirstChild("Scroller")
local confetti = frame:FindFirstChild("Confetti")
local dim = gui:FindFirstChild("Dim")
local design = QuestUi.Capture(gui)
timer.Text = glue("Loading quests...")

local shape = frame:FindFirstChildOfClass("UIAspectRatioConstraint")
if not shape then
	shape = Instance.new("UIAspectRatioConstraint")
	shape.Name = "UIAspectRatioConstraint"
	shape.AspectRatio = design.Frame.Aspect
	shape.AspectType = Enum.AspectType.FitWithinMaxSize
	shape.DominantAxis = Enum.DominantAxis.Width
	shape.Parent = frame
end

local cards = {}
for index, card in QuestUi.Cards(gui) do
	local tasks, rewards = {}, {}
	for _, row in QuestUi.Slots(card:FindFirstChild("list"), "Frame", "TemplateQuest", "Task") do
		local bar = row:FindFirstChild("Bar")
		-- The task text follows its row's height (QuestUi.RowTextShare).
		local cap = row:FindFirstChild("Title") and row.Title:FindFirstChild("RowTextSize")
		if cap then
			local function capText()
				local size = row.AbsoluteSize
				local height = if typeof(size) == "Vector2" then size.Y else 0
				if height > 0 then
					cap.MaxTextSize = math.max(cap.MinTextSize + 1, math.floor(height * QuestUi.RowTextShare))
				end
			end
			row:GetPropertyChangedSignal("AbsoluteSize"):Connect(capText)
			capText()
		end
		table.insert(tasks, {
			Row = row,
			Icon = row:FindFirstChild("Icon"),
			Text = row:FindFirstChild("Title"),
			Bar = bar,
			Fill = bar:FindFirstChild("Fill"),
		})
	end
	for _, item in QuestUi.Slots(card:FindFirstChild("RewardTemplate"), "ImageLabel", "Item", "Reward") do
		table.insert(rewards, { Item = item, Quantity = item:FindFirstChild("Quantity") })
	end
	local button = card:FindFirstChild("Choose")
	local glow = card:FindFirstChild("Glow")
	cards[index] = {
		Frame = card,
		Tasks = tasks,
		Rewards = rewards,
		Button = button,
		Parts = QuestUi.ButtonParts(button),
		Glow = glow,
		Shine = glow and glow:FindFirstChild("Shine"),
		Shade = card:FindFirstChild("Shade"),
		Badge = card:FindFirstChild("Badge"),
		Pulsing = false,
	}
end

local function gamepadActive()
	local tenFoot = false
	pcall(function()
		tenFoot = typeof(GuiService.IsTenFootInterface) == "function" and GuiService:IsTenFootInterface() == true
	end)
	if tenFoot then
		return true
	end
	local ok, result = pcall(function()
		return UserInputService.GamepadEnabled and string.find(UserInputService:GetLastInputType().Name, "Gamepad") ~= nil
	end)
	return ok and result == true
end

local function linkGamepad()
	closeButton.Selectable = true
	for index, card in cards do
		card.Button.Selectable = true
		local prevCard = cards[index - 1]
		local nextCard = cards[index + 1]
		if prevCard then
			card.Button.NextSelectionLeft = prevCard.Button
		end
		if nextCard then
			card.Button.NextSelectionRight = nextCard.Button
		end
		card.Button.NextSelectionUp = closeButton
	end
	if cards[1] then
		closeButton.NextSelectionDown = (cards[2] and cards[2].Button) or cards[1].Button
	end
end
linkGamepad()

local isOpen, isClosing = false, false
local motion = 0 -- stale open / close tweens do nothing
local layout = nil
local state = nil -- the last QuestUpdate with quests in it
local deadline = nil -- os.clock() when the day's quests reset
local confirmIndex, confirmUntil = 0, 0
local messageUntil = 0
local lastRefresh = -math.huge

----------------------------------------------------------------------
-- Button feel: press, bounce, hover, the Claim! pulse
----------------------------------------------------------------------
local function scaleTo(card, value, info)
	if card.ScaleTween then
		card.ScaleTween:Cancel()
	end
	local tween = TweenService:Create(card.Parts.Scale, info, { Scale = value })
	card.ScaleTween = tween
	tween:Play()
	return tween
end

local function release(card)
	card.Held = false
	local tween = scaleTo(card, if card.Hovered and not card.Pulsing then 1.05 else 1, RELEASE_INFO)
	if card.Pulsing then
		tween.Completed:Connect(function()
			if card.ScaleTween == tween and card.Pulsing and not card.Held then
				scaleTo(card, 1.08, PULSE_INFO)
			end
		end)
	end
end

local function setPulse(card, on)
	if card.Pulsing == on then
		return
	end
	card.Pulsing = on
	if not card.Held then
		scaleTo(card, if on then 1.08 else 1, if on then PULSE_INFO else RELEASE_INFO)
	end
end

local function isPress(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

for _, card in cards do
	local button = card.Button
	button.InputBegan:Connect(function(input)
		if isPress(input) and button:GetAttribute("Enabled") == true then
			card.Held = true
			scaleTo(card, 0.95, PRESS_INFO)
		end
	end)
	button.InputEnded:Connect(function(input)
		if isPress(input) and card.Held then
			release(card)
		end
	end)
	button.MouseEnter:Connect(function()
		card.Hovered = true
		if not card.Held and not card.Pulsing and button:GetAttribute("Enabled") == true then
			scaleTo(card, 1.05, HOVER_INFO)
		end
	end)
	button.MouseLeave:Connect(function()
		card.Hovered = false
		if card.Held then
			release(card)
		elseif not card.Pulsing then
			scaleTo(card, 1, HOVER_INFO)
		end
	end)
end

----------------------------------------------------------------------
-- Drawing the day's quests
----------------------------------------------------------------------
local function clockText(seconds)
	seconds = math.max(0, math.floor(seconds))
	return string.format("%02d:%02d:%02d", seconds // 3600, seconds % 3600 // 60, seconds % 60)
end

local function showMessage(text)
	timer.Text = glue(text)
	messageUntil = os.clock() + MESSAGE_SECONDS
end

local function setButton(card, text, palette, enabled)
	if card.Parts.Label then
		card.Parts.Label.Text = glue(text)
	end
	if not card.Painted or card.Parts.Palette ~= palette then
		QuestUi.Paint(card.Parts, palette)
		card.Painted = true
	end
	card.Button.AutoButtonColor = enabled
	card.Button:SetAttribute("Enabled", enabled)
end

-- "Earn 5K Speed" before the pick; "Earn 5K Speed (1.2K/5K)" or "... (Done!)" after it.
local function taskLine(task, done, chosen)
	local text = glue(task.Text)
	if not chosen then
		return text
	end
	return text .. " " .. glue("(" .. (if done then "Done!" else tostring(task.ProgressText or "")) .. ")")
end

local function setShine(card, on)
	if on and not card.ShineTween and card.Shine then
		card.Shine.Rotation = 0
		card.ShineTween = TweenService:Create(card.Shine, SHINE_INFO, { Rotation = 360 })
		card.ShineTween:Play()
	elseif not on and card.ShineTween then
		card.ShineTween:Cancel()
		card.ShineTween = nil
	end
end

local function render()
	if not state or type(state.Paths) ~= "table" then
		return
	end
	local chosen = tonumber(state.Choice) or 0
	local activeChoice = 0
	for pIdx, p in state.Paths do
		if p.Active then
			activeChoice = pIdx
			break
		end
	end
	if activeChoice == 0 and chosen ~= 0 and state.Claimed ~= true then
		activeChoice = chosen
	end

	local claimedChoices = if type(state.ClaimedChoices) == "table" then state.ClaimedChoices else {}

	for index, card in cards do
		local path = state.Paths[index]
		card.Frame.Visible = path ~= nil
		if path then
			local isThisClaimed = path.Claimed == true
				or claimedChoices[tostring(index)] == true
				or (index == chosen and state.Claimed == true)
			local isThisActive = (index == activeChoice and not isThisClaimed)

			for taskIndex, slot in card.Tasks do
				local task = path.Tasks and path.Tasks[taskIndex]
				slot.Row.Visible = task ~= nil
				if task then
					local target = math.max(1, tonumber(task.Target) or 1)
					local progress = if isThisClaimed
						then target
						else math.clamp(tonumber(task.Progress) or 0, 0, target)
					local done = isThisClaimed or (progress >= target)
					local metric = QuestCatalog.Metrics[task.Metric]
					if slot.Icon then
						slot.Icon.Image = tostring(task.Image or (metric and metric.Image) or "")
					end
					slot.Text.Text = taskLine(task, done, isThisActive or isThisClaimed)
					slot.Bar.Visible = isThisActive or isThisClaimed
					slot.Fill.Size = UDim2.fromScale(if target > 0 then progress / target else 1, 1)
					slot.Fill.BackgroundColor3 = if done then QuestUi.Colors.Green else QuestUi.Colors.Cyan
				end
			end
			for rewardIndex, slot in card.Rewards do
				local reward = path.Rewards and path.Rewards[rewardIndex]
				slot.Item.Visible = reward ~= nil
				if reward then
					slot.Item.Image = tostring(reward.Icon or "")
					if slot.Quantity then
						slot.Quantity.Text = glue(reward.Text)
						slot.Quantity.ZIndex = slot.Item.ZIndex + 4
					end
					if reward.Kind == "SpinTicket" then
						local spinner = attachSpinWheelReward(slot.Item)
						if spinner then
							slot.Item.ImageTransparency = 1
							spinner.Visible = true
							activeWheelSpinners[spinner] = true
						else
							slot.Item.ImageTransparency = 0
						end
					else
						slot.Item.ImageTransparency = 0
						local spinner = slot.Item:FindFirstChild("WheelSpinner")
						if spinner then
							spinner.Visible = false
							activeWheelSpinners[spinner] = nil
						end
					end
				else
					local spinner = slot.Item:FindFirstChild("WheelSpinner")
					if spinner then
						spinner.Visible = false
						activeWheelSpinners[spinner] = nil
					end
				end
			end
			card.Glow.Enabled = isThisActive
			setShine(card, isThisActive)
			card.Badge.Visible = isThisClaimed
			local pulse = false
			if isThisClaimed then
				card.Shade.Visible = false
				setButton(card, "Claimed ✓", "Grey", false)
			elseif isThisActive then
				card.Shade.Visible = false
				if path.Complete == true then
					setButton(card, "Claim!", "Green", true)
					pulse = true
				else
					setButton(card, "In Progress", "Blue", false)
				end
			elseif activeChoice ~= 0 then
				card.Shade.Visible = true
				setButton(card, "Locked", "Grey", false)
			else
				card.Shade.Visible = false
				if confirmIndex == index and os.clock() < confirmUntil then
					setButton(card, "Confirm?", "Gold", true)
				else
					setButton(card, "Choose", nil, true)
				end
			end
			setPulse(card, pulse)
		end
	end
	local hasAvailableChoice = false
	for index, path in state.Paths do
		local isClaimed = path.Claimed == true
			or claimedChoices[tostring(index)] == true
			or (index == chosen and state.Claimed == true)
		if not isClaimed then
			hasAvailableChoice = true
			break
		end
	end
	local isWaitingChoice = (activeChoice == 0 and hasAvailableChoice)
	local isReadyToClaim = (activeChoice ~= 0 and state.Paths[activeChoice] ~= nil and state.Paths[activeChoice].Complete == true)
	LocalPlayer:SetAttribute("QuestRewardReady", isReadyToClaim)
	LocalPlayer:SetAttribute("QuestAvailable", isWaitingChoice or isReadyToClaim)
end

-- The countdown under the title; at zero it asks for the new day's quests.
local function countdown()
	if not deadline then
		return
	end
	local left = deadline - os.clock()
	if os.clock() >= messageUntil then
		timer.Text = glue("🕒 Resets in: " .. clockText(left))
	end
	if confirmIndex ~= 0 and os.clock() >= confirmUntil then
		confirmIndex = 0
		render()
	end
	if left <= 0 and os.clock() - lastRefresh >= REFRESH_RETRY_SECONDS then
		lastRefresh = os.clock()
		QuestRequest:FireServer({ action = "State" })
	end
end

----------------------------------------------------------------------
-- The claim celebration
----------------------------------------------------------------------
local function celebrate(index)
	successSound:Play()
	local card = cards[index]
	local originX, originY = 0.5, 0.8
	if card then
		pcall(function()
			local area, size = confetti.AbsolutePosition, confetti.AbsoluteSize
			local box, boxSize = card.Button.AbsolutePosition, card.Button.AbsoluteSize
			if size.X > 0 and size.Y > 0 then
				originX = (box.X + boxSize.X / 2 - area.X) / size.X
				originY = (box.Y - area.Y) / size.Y
			end
		end)
		card.Held = false
		scaleTo(card, 1.2, PRESS_INFO).Completed:Connect(function()
			scaleTo(card, 1, RELEASE_INFO)
		end)
	end
	for piece = 1, 40 do
		local bit = Instance.new("Frame")
		bit.Name = "Piece"
		bit.BorderSizePixel = 0
		bit.BackgroundColor3 = CONFETTI_COLORS[(piece - 1) % #CONFETTI_COLORS + 1]
		bit.AnchorPoint = Vector2.new(0.5, 0.5)
		bit.SizeConstraint = Enum.SizeConstraint.RelativeYY
		bit.Size = UDim2.fromScale(0.012 + math.random() * 0.01, 0.02 + math.random() * 0.012)
		bit.Position = UDim2.fromScale(originX, originY)
		bit.Rotation = math.random(0, 359)
		bit.ZIndex = 31
		bit.Parent = confetti
		local angle = math.rad(math.random(200, 340))
		local distance = 0.15 + math.random() * 0.25
		local peak = UDim2.fromScale(originX + math.cos(angle) * distance * 0.6, originY + math.sin(angle) * distance)
		local burst = TweenService:Create(bit, TweenInfo.new(0.35 + math.random() * 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = peak,
			Rotation = bit.Rotation + math.random(-180, 180),
		})
		burst.Completed:Connect(function()
			TweenService:Create(bit, TweenInfo.new(1 + math.random() * 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.fromScale(peak.X.Scale + (math.random() - 0.5) * 0.12, 1.08),
				Rotation = bit.Rotation + math.random(-360, 360),
				BackgroundTransparency = 1,
			}):Play()
		end)
		burst:Play()
		task.delay(2.4, function()
			bit:Destroy()
		end)
	end
end

----------------------------------------------------------------------
-- Choosing and claiming
----------------------------------------------------------------------
for index, card in cards do
	card.Button.Activated:Connect(function()
		if not state or card.Button:GetAttribute("Enabled") ~= true then
			return
		end
		PurchaseButtonSound.Play()
		local chosen = tonumber(state.Choice) or 0
		local activeChoice = 0
		if state.Paths then
			for pIdx, p in state.Paths do
				if p.Active then
					activeChoice = pIdx
					break
				end
			end
		end
		if activeChoice == 0 and chosen ~= 0 and state.Claimed ~= true then
			activeChoice = chosen
		end

		if activeChoice == 0 then
			if confirmIndex == index and os.clock() < confirmUntil then
				confirmIndex = 0
				setButton(card, "...", "Grey", false)
				QuestRequest:FireServer({ action = "Choose", choice = index })
			else
				confirmIndex, confirmUntil = index, os.clock() + CONFIRM_SECONDS
				render()
			end
		elseif index == activeChoice then
			setButton(card, "...", "Grey", false)
			setPulse(card, false)
			QuestRequest:FireServer({ action = "Claim" })
		end
	end)
end

QuestUpdate.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then
		return
	end
	local claimedBefore = state ~= nil and state.Claimed == true and state.Period == payload.Period
	if type(payload.Paths) == "table" then
		if state and state.Period ~= payload.Period then
			confirmIndex = 0
		end
		state = payload
		deadline = os.clock() + math.max(0, tonumber(payload.TimeLeft) or 0)
		render()
		countdown()
	end
	if payload.message then
		showMessage(tostring(payload.message))
	end
	if payload.success == true and payload.Claimed == true and not claimedBefore then
		celebrate(tonumber(payload.Choice) or 0)
	end
end)

----------------------------------------------------------------------
-- Every screen
----------------------------------------------------------------------
-- The panel's area: the ScreenGui's size (the viewport less the top bar and notches), or
-- the viewport less the top bar's inset before it has one.
local function screenSize()
	local size = gui.AbsoluteSize
	if typeof(size) == "Vector2" and size.X > 1 and size.Y > 1 then
		return size
	end
	local camera = Workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local inset = GuiService:GetGuiInset()
	return Vector2.new(viewport.X, math.max(1, viewport.Y - inset.Y))
end

local function relayout()
	layout = QuestUi.Layout(screenSize(), UserInputService.TouchEnabled == true, design)
	QuestUi.Apply(gui, design, layout)
	if not isOpen or isClosing then
		panelScale.Scale = layout.Scale
	else
		panelScale.Scale = layout.Scale
	end
end

-- On phones the chosen quest scrolls into view.
local function focusChosen()
	local chosen = state and tonumber(state.Choice) or 0
	local spot = layout and layout.Compact and layout.Cards[chosen]
	if spot then
		local most = math.max(0, layout.CanvasWidth - layout.ViewWidth)
		scroller.CanvasPosition = Vector2.new(math.clamp(spot.X - layout.ViewWidth / 2, 0, most), 0)
	end
end

local watchedCamera = nil
local function watchCamera()
	local camera = Workspace.CurrentCamera
	if camera and camera ~= watchedCamera then
		watchedCamera = camera
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			if camera == Workspace.CurrentCamera then
				relayout()
			end
		end)
	end
end
watchCamera()
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	watchCamera()
	relayout()
end)
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayout)
relayout()

----------------------------------------------------------------------
-- Opening and closing
----------------------------------------------------------------------
local function openPanel()
	if isOpen then
		return
	end
	isOpen, isClosing = true, false
	motion += 1
	MenuEvents.CloseAll:Fire("Quests")
	if MenuEvents.SetHUDVisible then
		MenuEvents.SetHUDVisible(false, "Quests")
	end
	relayout()
	panelScale.Scale = layout.Scale * 0.85
	gui.Enabled = true
	TweenService:Create(panelScale, OPEN_INFO, { Scale = layout.Scale }):Play()
	QuestRequest:FireServer({ action = "Open" })
	render()
	focusChosen()
	if gamepadActive() then
		GuiService.GuiNavigationEnabled = true
		local chosen = state and tonumber(state.Choice) or 0
		local focusCard = (chosen > 0 and cards[chosen]) or cards[1]
		if focusCard and focusCard.Button then
			GuiService.SelectedObject = focusCard.Button
		end
	end
end

local function closePanel()
	if not isOpen then
		return
	end
	isOpen, isClosing = false, true
	confirmIndex = 0
	motion += 1
	local token = motion
	local selected = GuiService.SelectedObject
	if selected and selected:IsDescendantOf(gui) then
		GuiService.SelectedObject = nil
	end
	local tween = TweenService:Create(panelScale, CLOSE_INFO, { Scale = (if layout then layout.Scale else 1) * 0.8 })
	tween:Play()
	tween.Completed:Connect(function()
		if motion == token and not isOpen then
			isClosing = false
			gui.Enabled = false
			-- The Main HUD comes back however the panel was closed (X, the dark background, Escape,
			-- another menu), unless another menu is open by now.
			if not MenuEvents.AnyOpen("Quests") then
				MenuEvents.SetHUDVisible(true, nil)
			end
		end
	end)
end

closeButton.Activated:Connect(function()
	PurchaseButtonSound.Play()
	closePanel()
end)
dim.Activated:Connect(function()
	closePanel()
end)

MenuEvents.Get("OpenQuestsPanel").Event:Connect(function(action)
	if action == "Close" then
		closePanel()
	elseif action == "Open" or action == "Npc" then
		-- Dr. Eggman's dialog always opens the panel (never toggles it shut).
		openPanel()
	elseif isOpen then
		closePanel()
	else
		openPanel()
	end
end)
MenuEvents.CloseAll.Event:Connect(function(except)
	if except ~= "Quests" then
		closePanel()
	end
end)
MenuEvents.MarkReady("Quests", function()
	return isOpen and not isClosing
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not isOpen then
		return
	end
	if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
		closePanel()
	end
end)

-- The countdown, a lapsed confirm, and a new day.
task.spawn(function()
	while gui.Parent do
		task.wait(1)
		countdown()
	end
end)

RunService.RenderStepped:Connect(function()
	if not isOpen or isClosing then
		return
	end
	local rotation = (os.clock() * 45) % 360
	for spinner in activeWheelSpinners do
		if spinner.Parent and spinner.Visible then
			spinner.Rotation = rotation
		else
			activeWheelSpinners[spinner] = nil
		end
	end
end)

task.defer(function()
	QuestRequest:FireServer({ action = "State" })
end)
