-- StaminaPassHint.client.luau (Update 4, 2026-09-25)
-- A small, once-a-session offer for the 2x Stamina Regen pass: a "2x Regen" chip at the right
-- end of the stamina bar (Mainhud.SpeedsterBar, only looked at, never changed) for
-- U4.StaminaPass.HintSeconds, shown when a player who does not own the pass has tried to run
-- on an empty bar U4.StaminaPass.HintAfterEmpties times (StaminaFeedback "run") and has played
-- at least HintMinSessionSeconds, never in the tutorial or a race.
-- Tap / click (or D-pad right on a gamepad) opens Roblox's purchase prompt.
-- Funnel Monetization_StaminaPass (FunnelReport): 0 chip shown, 1 tapped, 2 prompt shown;
-- the server logs 3 (StaminaRegenPass). Nothing at all while the pass is off (no id yet).

local ContextActionService = game:GetService("ContextActionService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local U4 = require(Shared:WaitForChild("Update4Config"))

local PASS_ID = math.floor(tonumber(U4.StaminaPass.GamePassId) or 0)
if PASS_ID <= 0 or not U4.IsOn("StaminaPass") then
	return
end

local StaminaFeedback = require(Shared:WaitForChild("StaminaFeedback"))
local playerGui = player:WaitForChild("PlayerGui")

local SETTINGS = U4.StaminaPass
local SESSION_START = os.clock()
local ACTION = "StaminaPassHintBuy"

-- The whole rule, on plain values (audit/test_u4_stamina_pass loads this function alone).
-- HINT_RULE_BEGIN
local function shouldShowHint(state)
	if state.shown or state.owned or state.tutorial or state.racing or not state.passOn then
		return false
	end
	if state.empties < state.afterEmpties then
		return false
	end
	return state.sessionSeconds >= state.minSessionSeconds
end
-- HINT_RULE_END

local empties = 0
local shown = false
local chipGui = nil
local chip = nil
local hideAt = 0

local function reportFunnelStep(step)
	task.spawn(function()
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		local report = remotes and remotes:WaitForChild("FunnelReport", 10)
		if report and report:IsA("RemoteEvent") then
			pcall(report.FireServer, report, "Monetization_StaminaPass", step)
		end
	end)
end

local function staminaBar()
	local mainhud = playerGui:FindFirstChild("Mainhud")
	local bar = mainhud and mainhud:FindFirstChild("SpeedsterBar")
	if mainhud and mainhud:IsA("ScreenGui") and mainhud.Enabled and bar and bar:IsA("GuiObject") and bar.Visible then
		return mainhud, bar
	end
	return nil, nil
end

local function hide()
	hideAt = 0
	ContextActionService:UnbindAction(ACTION)
	if chipGui then
		chipGui.Enabled = false
	end
end

local function buy()
	if not chip or not chipGui or not chipGui.Enabled then
		return
	end
	hide()
	reportFunnelStep(1)
	local ok = pcall(function()
		MarketplaceService:PromptGamePassPurchase(player, PASS_ID)
	end)
	if ok then
		reportFunnelStep(2)
	end
end

local function build(mainhud)
	chipGui = Instance.new("ScreenGui")
	chipGui.Name = "StaminaPassHint"
	chipGui.ResetOnSpawn = false
	chipGui.DisplayOrder = 12
	chipGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	-- The same screen origin as the bar's own ScreenGui, so its absolute place is ours too.
	chipGui.IgnoreGuiInset = mainhud.IgnoreGuiInset
	chipGui.ScreenInsets = mainhud.ScreenInsets
	chipGui.Enabled = false

	chip = Instance.new("TextButton")
	chip.Name = "Chip"
	chip.AnchorPoint = Vector2.new(0, 0.5)
	chip.Size = UDim2.fromOffset(104, 30)
	chip.BackgroundColor3 = Color3.fromRGB(255, 211, 33)
	chip.AutoButtonColor = true
	chip.Font = Enum.Font.FredokaOne
	chip.Text = "⚡ 2x Regen"
	chip.TextColor3 = Color3.fromRGB(255, 255, 255)
	chip.TextScaled = true
	chip.Selectable = true
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = chip
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(11, 27, 61)
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = chip
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingBottom = UDim.new(0, 4)
	padding.Parent = chip
	local textStroke = Instance.new("UIStroke")
	textStroke.Color = Color3.fromRGB(11, 27, 61)
	textStroke.Thickness = 1.5
	textStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	textStroke.Parent = chip
	chip.Activated:Connect(buy)
	chip.Parent = chipGui
	chipGui.Parent = playerGui
end

-- Next to the bar's right end, or above it when the screen ends there (small phones).
local function place(bar)
	local position, size = bar.AbsolutePosition, bar.AbsoluteSize
	local screen = chipGui.AbsoluteSize
	local x = position.X + size.X + 6
	local y = position.Y + size.Y / 2
	if screen.X > 0 and x + chip.AbsoluteSize.X > screen.X - 4 then
		x = position.X + size.X - chip.AbsoluteSize.X
		y = position.Y - 20
	end
	chip.Position = UDim2.fromOffset(math.floor(x), math.floor(y))
end

local function show()
	local mainhud, bar = staminaBar()
	if not mainhud or not bar then
		return false
	end
	if not chipGui then
		build(mainhud)
	end
	shown = true
	chipGui.Enabled = true
	place(bar)
	hideAt = os.clock() + (tonumber(SETTINGS.HintSeconds) or 6)
	ContextActionService:BindActionAtPriority(ACTION, function(_, state)
		if state == Enum.UserInputState.Begin then
			buy()
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.DPadRight)
	if UserInputService.GamepadEnabled then
		chip.Text = "⚡ 2x Regen ▶"
	end
	reportFunnelStep(0)
	-- Follows the bar (the HUD slides it) at 5 Hz, only for these few seconds.
	task.spawn(function()
		while chipGui.Enabled and os.clock() < hideAt do
			local _, current = staminaBar()
			if not current then
				break
			end
			place(current)
			task.wait(0.2)
		end
		hide()
	end)
	return true
end

StaminaFeedback.Attempted:Connect(function(kind)
	if kind ~= "run" or shown then
		return
	end
	empties += 1
	local want = shouldShowHint({
		shown = shown,
		owned = player:GetAttribute("StaminaRegen2xOwned") == true,
		tutorial = player:GetAttribute("FirstTimeTutorialActive") == true,
		racing = player:GetAttribute("RaceActive") == true,
		passOn = U4.IsOn("StaminaPass"),
		empties = empties,
		afterEmpties = tonumber(SETTINGS.HintAfterEmpties) or 3,
		sessionSeconds = os.clock() - SESSION_START,
		minSessionSeconds = tonumber(SETTINGS.HintMinSessionSeconds) or 600,
	})
	if want then
		show()
	end
end)

-- Bought (or given) while the chip is up: it goes at once.
player:GetAttributeChangedSignal("StaminaRegen2xOwned"):Connect(function()
	if player:GetAttribute("StaminaRegen2xOwned") == true then
		hide()
	end
end)
