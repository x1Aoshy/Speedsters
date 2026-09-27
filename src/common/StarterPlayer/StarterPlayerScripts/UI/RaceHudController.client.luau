-- StarterPlayerScripts/UI/RaceHudController.client.luau — Update 4 (2026-09-25): the race HUD and
-- the results window (PLAN §7.4 items 3-4). Both ScreenGuis are built once by
-- Shared/RaceUiBuilder (RaceHud, RaceResults), placed by Shared/RaceHudLayout for the screen and
-- the last input (touch, keyboard, gamepad), worded by Shared/RaceText.
--   RaceHud (from Staged to the end of the race): "STARTING: 3s" + the popping number, "GO!";
--   the MPH bar ("MPH: 84 / 98", Multiplier, MPH/s), the race-stamina bar, the charge gauge
--   (PC/console) or the ring around the CHARGE/BOOST button (touch), the hint, the start
--   banner; the live podium top-left (headshots, medals, purple estimated Wins), "You · 7th/12",
--   the ORB distance and race clock top-right; "OUCH! SPIKES", "FINISHED 2nd!", toasts.
--   The normal HUD is away meanwhile (InterfaceHider "Race", keeping RaceHud, RaceResults and
--   Roblox's TouchGui by name).
--   RaceResults (on the local finish, or the Results of a DNF): place, time, NEW BEST, best,
--   mini podium, reward chips, RACE AGAIN / LOBBY (8). LOBBY (and Close, B, the 8 s timer)
--   sends RaceRequest("Leave"); RACE AGAIN keeps the racer queued (RaceRequest AutoRequeue
--   when the server already requeued them or will at the Results, else Join "Results").
-- One RenderStepped, connected only while the HUD shows: bars and the gauge move only when
-- their value changes, texts refresh at most 10 times a second (fixed TextSize, no scaling),
-- the podium once per RaceLive packet (4 Hz), headshots cached per UserId.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local U4 = require(Shared:WaitForChild("Update4Config"))
local RaceMath = require(Shared:WaitForChild("RaceMath"))
local RaceChargeMath = require(Shared:WaitForChild("RaceChargeMath"))
local RaceTrack = require(Shared:WaitForChild("RaceTrack"))
local RaceHudLayout = require(Shared:WaitForChild("RaceHudLayout"))
local RaceUiBuilder = require(Shared:WaitForChild("RaceUiBuilder"))
local RaceUiKit = require(Shared:WaitForChild("RaceUiKit"))
local RaceText = require(Shared:WaitForChild("RaceText"))
local InterfaceHider = require(Shared:WaitForChild("InterfaceHider"))
local ConsolePanelSupport = require(Shared:WaitForChild("ConsolePanelSupport"))
local NumberFormat = require(Shared:WaitForChild("Math"):WaitForChild("NumberFormat"))
local WinsMath = require(Shared:WaitForChild("WinsMath"))
local Config = require(Shared:WaitForChild("Config"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes", 30)
local RaceRequest = Remotes and Remotes:WaitForChild("RaceRequest", 60)
local RaceEvent = Remotes and Remotes:WaitForChild("RaceEvent", 30)
local RaceLive = Remotes and Remotes:WaitForChild("RaceLive", 30)
if not (RaceRequest and RaceEvent and RaceLive) then
	return
end

local RACE = U4.Race
local QUEUE = RACE.Queue
local HUD = RACE.Hud
local TRACK = RACE.Track
local CHARGE = RACE.Charge
local WORLD = if Config.IsWorld2Place == true then "World2" elseif Config.IsWorld3Place == true then "World3" else "World1"
local HIDER_OWNER = "Race"
local TEXT_INTERVAL = 0.1
local ORB_BEYOND = TRACK.OrbS - TRACK.Length -- the ORB stands this far past the finish
local GAUGE_AFTER_GO = 0.8
local BANNER_SECONDS = 0.9
local GO_SECONDS = 0.7
local BOOST_FILL = { { 0, { 255, 245, 130 } }, { 0.5, { 255, 200, 40 } }, { 1, { 235, 125, 0 } } } -- a pad's boost
-- 2026-09-25 (final fix): LEAVE needs a second tap within this long (an accidental tap on a
-- phone must not end the race); RACE AGAIN ignores presses this soon after the window opened
-- at the finish (a gamepad's A held across the line selects it at once).
local LEAVE_CONFIRM_SECONDS = 3
local AGAIN_GUARD_SECONDS = 0.6
local LEAVE_ACTION = "RaceLeaveHud"

local lang = RaceText.ForPlayer(player)
local kit = RaceUiKit.new()

local function text(key, ...)
	return RaceText.Format(key, lang, ...)
end

local function finite(value)
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function now()
	return Workspace:GetServerTimeNow()
end

-- One of each, kept across respawns (ResetOnSpawn false).
local function ensure(name, build)
	local existing = playerGui:FindFirstChild(name)
	if existing and existing:IsA("ScreenGui") then
		return existing
	end
	local gui = build()
	for _, object in gui:GetDescendants() do
		if object:IsA("TextLabel") or object:IsA("TextButton") then
			RaceText.Style(object, lang)
		end
	end
	gui.Parent = playerGui
	return gui
end

local hud = ensure(RaceUiBuilder.HudName, RaceUiBuilder.BuildHud)
local results = ensure(RaceUiBuilder.ResultsName, RaceUiBuilder.BuildResults)

-- HUD pieces.
local countdown = hud.Countdown
local startingLabel, numberLabel = countdown.Starting, countdown.Number
local numberPop = numberLabel.Pop
local statusLabel = hud.Status
local podium = hud.Podium
local youPill = hud.YouPill
local goal = hud.Goal
local speedBar, staminaBar = hud.SpeedBar, hud.Stamina
local labels = hud.Labels
local gauge = hud.Gauge
local hint = hud.Hint
local banner = hud.Banner
local feedback = hud.Feedback
local action = hud.Action
local leaveButton = hud:FindFirstChild("Leave") -- nil only in a RaceHud built before the fix
local ring = hud.ActionRing
local segments = {}
for k = 1, RaceHudLayout.RingSegments do
	segments[k] = ring:FindFirstChild("Seg" .. k)
end
local pressedScale = action:FindFirstChild("Pressed") or Instance.new("UIScale")
pressedScale.Name = "Pressed"
pressedScale.Parent = action
-- 2026-09-25 (owner: the charge is never passive): while the charge is held the gauge (PC /
-- console) and the ring (touch) throb, faster and harder the fuller the gauge.
local function holdScale(object)
	local scale = object:FindFirstChild("HoldPulse") or Instance.new("UIScale")
	scale.Name = "HoldPulse"
	scale.Parent = object
	return scale
end
local gaugePulse = holdScale(gauge)
local ringPulse = holdScale(ring)

-- 2026-09-26 (owner: console first-class): the controller's buttons on screen while a gamepad is
-- the last input, the same ones Race/RaceInputClient binds (no drift, quick turn or lane change
-- exists, so nothing else is shown):
--   countdown: [A] [R2] HOLD TO CHARGE (both charge);
--   racing:    [R2] BOOST (the sprint; A jumps as Space does, the left stick steers);
--   LEAVE:     a [View] badge on its corner (the Select binding below).
local PAD_GLYPHS = {
	Charge = { Enum.KeyCode.ButtonA, Enum.KeyCode.ButtonR2 },
	Race = { Enum.KeyCode.ButtonR2 },
}
local PAD_LEAVE = Enum.KeyCode.ButtonSelect
local hintGlyphs = { hint.Glyph }
local hintGlyphPhase: string? = nil -- the phase the hint's glyphs show (setHintGlyphs)
do
	local second = hint:FindFirstChild("GlyphAlt")
	if not second then
		second = hint.Glyph:Clone()
		second.Name = "GlyphAlt"
		second.Visible = false
		second.Parent = hint
	end
	table.insert(hintGlyphs, second)
end
local leaveBadge = nil
if leaveButton then
	leaveBadge = leaveButton:FindFirstChild("PadGlyph")
	if not leaveBadge then
		leaveBadge = Instance.new("ImageLabel")
		leaveBadge.Name = "PadGlyph"
		leaveBadge.BackgroundTransparency = 1
		leaveBadge.AnchorPoint = Vector2.new(0.35, 0.35)
		leaveBadge.Position = UDim2.fromOffset(0, 0)
		leaveBadge.ZIndex = 6
		leaveBadge.Visible = false
		leaveBadge.Parent = leaveButton
	end
end

local function padImage(keyCode: Enum.KeyCode): string
	local ok, image = pcall(function()
		return UserInputService:GetImageForKeyCode(keyCode)
	end)
	return if ok and type(image) == "string" then image else ""
end
-- A quick gold flash over the screen on a Perfect start (none with reduced motion).
local flash = hud:FindFirstChild("StartFlash")
if not flash then
	flash = Instance.new("Frame")
	flash.Name = "StartFlash"
	flash.BorderSizePixel = 0
	flash.BackgroundColor3 = Color3.fromRGB(255, 244, 190)
	flash.BackgroundTransparency = 1
	flash.Size = UDim2.fromScale(1, 1)
	flash.ZIndex = 0
	flash.Active = false
	flash.Visible = false
	flash.Parent = hud
end

-- Results pieces.
local window = results.Window
local content = window.Content
local closeButton = window.Close
local raceAgain, lobbyButton = content.Buttons.RaceAgain, content.Buttons.Lobby

-- 2026-09-25 review: the builder's fixed English words, in the player's language.
window.Title.Text = text("ResultsTitle")
for _, holder in { podium, content.Podium } do
	for rank = 1, 3 do
		local card = holder:FindFirstChild("Card" .. rank)
		local chip = card and card:FindFirstChild("You")
		if chip and chip:IsA("TextLabel") then
			chip.Text = text("You")
		end
	end
end

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------
local function place(object, r)
	object.AnchorPoint = Vector2.zero
	object.Position = UDim2.fromOffset(math.floor(r.Left + 0.5), math.floor(r.Top + 0.5))
	object.Size = UDim2.fromOffset(math.floor(r.Right - r.Left + 0.5), math.floor(r.Bottom - r.Top + 0.5))
end

local function placeCentred(object, r)
	object.AnchorPoint = Vector2.new(0.5, 0.5)
	object.Position = UDim2.fromOffset(math.floor((r.Left + r.Right) / 2 + 0.5), math.floor((r.Top + r.Bottom) / 2 + 0.5))
	object.Size = UDim2.fromOffset(math.floor(r.Right - r.Left + 0.5), math.floor(r.Bottom - r.Top + 0.5))
end

local function setText(label, value)
	if label.Text ~= value then
		label.Text = value
	end
end

local function inputKind()
	if GuiService:IsTenFootInterface() then
		return "Gamepad"
	end
	local last = UserInputService:GetLastInputType()
	if last == Enum.UserInputType.Touch then
		return "Touch"
	elseif last.Name:find("Gamepad") then
		return "Gamepad"
	elseif UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "Touch"
	end
	return "Keyboard"
end

local headshots = {}
local function headshot(userId)
	if not finite(userId) or userId <= 0 then
		return ""
	end
	local image = headshots[userId]
	if not image then
		image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", userId)
		headshots[userId] = image
	end
	return image
end

local function displayName(userId, fallback)
	local other = Players:GetPlayerByUserId(userId)
	if other then
		return other.DisplayName
	end
	return if type(fallback) == "string" then fallback else "?"
end

local function eventMultiplier()
	local untilUnix = tonumber(Workspace:GetAttribute("RaceEventUntil")) or 0
	if untilUnix > os.time() then
		return math.max(1, tonumber(Workspace:GetAttribute("RaceEventMultiplier")) or 1)
	end
	return 1
end

-- What `userId` would win for `rank` of `n` right now (RaceMath.ComputeRewards with what the
-- client can see: the lap, their rebirths, their Wins multiplier, the event). The final
-- number comes from the server's Results.
local function estimateWins(userId, rank, n)
	local other = Players:GetPlayerByUserId(userId)
	local winsMultiplier = 1
	if other then
		local ok, value = pcall(WinsMath.GetTotalMultiplier, other)
		winsMultiplier = if ok and finite(value) then value else 1
	end
	local rewards = RaceMath.ComputeRewards({
		place = rank,
		finished = true,
		n = n,
		lapWins = Config.SpinWheel and Config.SpinWheel.LapWins and Config.SpinWheel.LapWins[WORLD] or 0,
		world = WORLD,
		rebirths = other and tonumber(other:GetAttribute("Rebirths")) or 0,
		unlockRebirths = Config.World2UnlockRebirths,
		eventMultiplier = eventMultiplier(),
		winsMultiplier = winsMultiplier,
	})
	return rewards.wins
end

local function compact(value)
	return NumberFormat.FormatCompact(math.max(0, math.floor(tonumber(value) or 0)))
end

----------------------------------------------------------------------
-- Layout
----------------------------------------------------------------------
local plan = nil
local ringRadius = 0

local function layout()
	local size = hud.AbsoluteSize
	if size.X < 100 or size.Y < 100 then
		return
	end
	local kind = inputKind()
	local topBar = GuiService:GetGuiInset().Y
	local layoutText = if kind == "Touch" then player:GetAttribute("TouchLayout") else nil
	plan = RaceHudLayout.Plan(size.X, size.Y, kind, topBar, { layout = layoutText, keyboard = UserInputService.KeyboardEnabled })

	place(speedBar, plan.Bar)
	speedBar.Text.TextSize = plan.Bar.TextSize
	speedBar.Icon.Size = UDim2.fromOffset(plan.Bar.IconSize, plan.Bar.IconSize)
	place(labels, plan.Labels)
	labels.Multiplier.TextSize, labels.Accel.TextSize = plan.Labels.TextSize, plan.Labels.TextSize
	place(staminaBar, plan.Stamina)
	staminaBar.Text.TextSize = plan.Stamina.TextSize
	if plan.Gauge then
		place(gauge, plan.Gauge)
	end
	place(hint, plan.Hint)
	hint.Text.TextSize = plan.Hint.TextSize
	placeCentred(banner, plan.Banner)
	banner.TextSize = plan.Banner.TextSize
	place(statusLabel, plan.Status)
	statusLabel.TextSize = plan.Status.TextSize
	place(podium, plan.Podium)
	for _, card in plan.Podium.Cards do
		local frame = podium:FindFirstChild("Card" .. card.Place)
		if frame then
			local side = card.Size
			frame.Position = UDim2.fromOffset(card.Left, card.Top)
			frame.Size = UDim2.fromOffset(side, card.Bottom - card.Top)
			frame.Headshot.Size = UDim2.fromOffset(side, side)
			local strip = frame.Headshot.NameStrip
			strip.Size = UDim2.new(1, 0, 0, plan.Podium.NameH)
			strip.PlayerName.TextSize = plan.Podium.NameText
			frame.Rank.Size = UDim2.fromOffset(plan.Podium.BadgeSize, plan.Podium.BadgeSize)
			frame.Rank.Number.TextSize = plan.Podium.BadgeText
			frame.Reward.Position = UDim2.fromOffset(0, side + 2)
			frame.Reward.Size = UDim2.fromOffset(side, plan.Podium.RewardH)
			frame.Reward.Amount.TextSize = plan.Podium.RewardText
		end
	end
	place(youPill, plan.You)
	youPill.Text.TextSize = plan.You.TextSize
	place(goal, plan.Goal)
	for index, name in { "Orb", "Distance", "Elapsed" } do
		local line = goal[name]
		line.Position = UDim2.fromOffset(0, (index - 1) * plan.Goal.LineH)
		line.Size = UDim2.new(1, 0, 0, plan.Goal.LineH)
		line.TextSize = plan.Goal.TextSize
	end
	placeCentred(numberLabel, plan.Number) -- TextScaled: its height is its size
	place(startingLabel, plan.Starting)
	startingLabel.TextSize = plan.Starting.TextSize
	placeCentred(feedback, plan.Feedback)
	feedback.TextSize = plan.Feedback.TextSize
	if leaveButton and plan.Leave then
		place(leaveButton, plan.Leave)
		leaveButton.Label.TextSize = plan.Leave.TextSize
	end
	if plan.Action and plan.Ring then
		place(action, plan.Action)
		action.Label.TextSize = plan.Action.TextSize
		local outer = plan.Ring.Right - plan.Ring.Left
		placeCentred(ring, plan.Ring)
		ringRadius = plan.Ring.Radius
		local count = #segments
		local arc = math.rad(RaceHudLayout.RingSweepDegrees) * ringRadius / count
		for k, seg in segments do
			local dx, dy, rotation = RaceHudLayout.RingSegment(k, count, ringRadius)
			seg.Position = UDim2.fromOffset(outer / 2 + dx, outer / 2 + dy)
			seg.Size = UDim2.fromOffset(math.max(2, arc * 0.72), plan.Ring.Thickness)
			seg.Rotation = rotation
		end
	end
	-- The gamepad glyphs for the hint ("[A] [R2] HOLD TO CHARGE", "[R2] BOOST"): set by
	-- setHintGlyphs from render, for the phase; laid out again here (the size changed).
	hintGlyphPhase = nil
	-- 2026-09-26 (owner): the [View] badge on LEAVE's corner on a gamepad.
	if leaveBadge and plan.Leave then
		local image = if kind == "Gamepad" then padImage(PAD_LEAVE) else ""
		local side = math.floor((plan.Leave.Bottom - plan.Leave.Top) * 0.75 + 0.5)
		leaveBadge.Image = image
		leaveBadge.Size = UDim2.fromOffset(side, side)
		leaveBadge.Visible = image ~= ""
	end
end

-- 2026-09-26 (owner): the hint's glyphs for `phase` ("Charge", "Race" or "None"), left of the
-- words; written only when the phase or the layout changed (layout resets hintGlyphPhase).
local function setHintGlyphs(phase: string)
	if phase == hintGlyphPhase then
		return
	end
	hintGlyphPhase = phase
	local keys = PAD_GLYPHS[phase]
	local side = if plan and plan.Hint then plan.Hint.GlyphSize else 0
	local x = 0
	for index, glyph in hintGlyphs do
		local keyCode = keys and keys[index]
		local image = if keyCode and side > 0 then padImage(keyCode) else ""
		glyph.Image = image
		glyph.Visible = image ~= ""
		if glyph.Visible then
			glyph.Size = UDim2.fromOffset(side, side)
			glyph.Position = UDim2.fromOffset(x, 0)
			x += side + 4
		end
	end
	hint.Text.Position = UDim2.fromOffset(x, 0)
	hint.Text.Size = UDim2.new(1, -x, 1, 0)
end

hud:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
UserInputService.LastInputTypeChanged:Connect(function()
	if hud.Enabled then
		layout()
	end
end)
player:GetAttributeChangedSignal("TouchLayout"):Connect(layout)
task.defer(layout)

----------------------------------------------------------------------
-- The race state shown
----------------------------------------------------------------------
local shown = false
local renderConnection = nil
local live = nil -- the last RaceLive packet
local finishedAt = nil -- { place, timeMs } of the local finish
local goShownFor = nil -- the goAt whose GO! was shown
local lastCount = nil
local gaugeBands = nil
local bannerUntil = 0
local feedbackUntil = 0
local lastStumbleShown = -math.huge
local textClock = 0
local shownFill = { Speed = -1, Stamina = -1, Charge = -1 }

local function paintBands(assist)
	if gaugeBands == assist then
		return
	end
	gaugeBands = assist
	local zoneLo, zoneHi, coreLo, coreHi = RaceChargeMath.Bands(nil, assist)
	RaceUiBuilder.PlaceBand({ UDim2 = UDim2 }, gauge.Zone, zoneLo, zoneHi)
	RaceUiBuilder.PlaceBand({ UDim2 = UDim2 }, gauge.Core, coreLo, coreHi)
	RaceUiBuilder.PlaceBand({ UDim2 = UDim2 }, gauge.Overheat, CHARGE.StallAt, 1)
	gauge.Overheat.Visible = not assist
end

-- The ring: charge bands before GO, the race pool after (red under the sprint's minimum).
local ringLit = -1
local ringMode = nil
local function paintRing(value, chargeMode, assist)
	local count = #segments
	local lit = math.floor(math.clamp(value, 0, 1) * count + 0.5)
	local modeKey = (if chargeMode then "c" else "p") .. (if assist then "a" else "") .. (if not chargeMode and value < RACE.Stamina.MinSprintPool then "r" else "")
	if lit == ringLit and modeKey == ringMode then
		return
	end
	ringLit, ringMode = lit, modeKey
	local zoneLo, zoneHi, coreLo, coreHi = RaceChargeMath.Bands(nil, assist)
	for k, seg in segments do
		local at = (k - 0.5) / count
		local color
		if chargeMode then
			if at >= coreLo and at <= coreHi then
				color = RaceUiKit.Colors.Core
			elseif at >= zoneLo and at <= zoneHi then
				color = RaceUiKit.Colors.Zone
			elseif not assist and at >= CHARGE.StallAt then
				color = RaceUiKit.Colors.Overheat
			else
				color = RaceUiKit.Colors.White
			end
		else
			color = if value < RACE.Stamina.MinSprintPool then RaceUiKit.Colors.Red else RaceUiKit.Colors.Cyan
		end
		seg.BackgroundColor3 = kit:rgb(color)
		seg.BackgroundTransparency = if k <= lit then 0 else 0.62
	end
end

local function setFill(bar, key, value, stops)
	local v = math.clamp(value, 0, 1)
	if math.abs(shownFill[key] - v) < 0.002 then
		return
	end
	shownFill[key] = v
	bar.Fill.Size = UDim2.fromScale(v, 1)
	bar.Fill.Visible = v > 0.005
	if stops then
		bar.Fill.Shade.Color = kit:sequence(stops)
	end
end

local function pop(scale, from)
	scale.Scale = from
	TweenService:Create(scale, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

local function showFeedback(message, colorName, seconds)
	feedback.Text = message
	feedback.TextColor3 = kit:color(colorName or "White")
	feedback.TextTransparency = 0
	feedback.Visible = true
	pop(feedback.Pop, 1.3)
	feedbackUntil = os.clock() + (seconds or 1.2)
end

local function startBanner(grade)
	local boost = CHARGE.Boost[grade]
	local key, colour = nil, "Gold"
	if grade == "Perfect" then
		key = "StartPerfect"
	elseif grade == "Good" then
		key, colour = "StartGood", "Zone"
	elseif grade == "Stall" then
		key, colour = "StartStall", "Red"
	end
	if not key then
		banner.Visible = false
		return
	end
	local percent = if boost and grade ~= "Stall" then math.floor((boost[1] - 1) * 100 + 0.5) else 0
	banner.Text = text(key, percent)
	banner.TextColor3 = kit:color(colour)
	banner.Visible = true
	pop(banner.Pop, 1.4)
	bannerUntil = os.clock() + BANNER_SECONDS
	-- 2026-09-25: the launch's flash (the bubble bursting forward is Race/RacePoseClient's).
	local reduced = false
	pcall(function()
		reduced = GuiService.ReducedMotionEnabled == true
	end)
	if grade == "Perfect" and not reduced then
		flash.Visible = true
		flash.BackgroundTransparency = 0.35
		local fade = TweenService:Create(flash, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 })
		fade.Completed:Once(function()
			if flash.BackgroundTransparency >= 0.99 then
				flash.Visible = false
			end
		end)
		fade:Play()
	end
end

-- The start banner, once per start: the server's grade when it has one, else the predicted
-- one (Race/RaceInputClient writes it on the GO frame, after this frame's render); a server
-- grade that differs replaces it while it shows.
local bannerFor = nil
local bannerGrade = nil
local function maybeBanner()
	local goAt = tonumber(Workspace:GetAttribute("RaceGoAt")) or 0
	local t = now()
	if not shown or goAt <= 0 or t < goAt or t > goAt + 1.5 then
		return
	end
	local grade = player:GetAttribute("RaceStartGrade") or player:GetAttribute("RacePredictedGrade")
	if type(grade) ~= "string" then
		return
	end
	if bannerFor ~= goAt or (grade ~= bannerGrade and os.clock() < bannerUntil) then
		bannerFor, bannerGrade = goAt, grade
		startBanner(grade)
	end
end

----------------------------------------------------------------------
-- Podium (per RaceLive packet)
----------------------------------------------------------------------
local function renderPodium()
	local packet = live
	local top = packet and type(packet.top) == "table" and packet.top or {}
	local n = if packet and finite(packet.n) then packet.n else 1
	for rank = 1, 3 do
		local card = podium:FindFirstChild("Card" .. rank)
		local entry = top[rank]
		if card then
			if type(entry) == "table" and finite(entry.u) then
				card.Visible = true
				local face = card.Headshot
				local image = headshot(entry.u)
				if face.Image ~= image then
					face.Image = image
				end
				setText(face.NameStrip.PlayerName, displayName(entry.u))
				local mine = entry.u == player.UserId
				card.You.Visible = mine
				face.Medal.Color = if mine then kit:color("Cyan") else kit:color(RaceUiBuilder.PodiumMedals[rank])
				card.Reward.Icon.Image = HUD.RewardIcon
				setText(card.Reward.Amount, "+" .. compact(estimateWins(entry.u, rank, n)))
			else
				card.Visible = false
			end
		end
	end
	local you = packet and type(packet.you) == "table" and packet.you or nil
	if you and finite(you.place) and you.place > 3 then
		youPill.Visible = true
		setText(youPill.Text, text("YouPlace", RaceText.Ordinal(you.place, lang), n))
	else
		youPill.Visible = false
	end
	podium.Visible = #top > 0
end

----------------------------------------------------------------------
-- Every frame while the HUD shows
----------------------------------------------------------------------
local function render(dt)
	local t = now()
	local goAt = tonumber(Workspace:GetAttribute("RaceGoAt")) or 0
	local phase = Workspace:GetAttribute("RacePhase")
	local state = player:GetAttribute("RaceState")
	local beforeGo = t < goAt and (state == "Staged")
	local sprintMax = tonumber(player:GetAttribute("RaceSprintSpeed")) or (RACE.Speed.BaseCruise * RACE.Speed.SprintMultiplier)
	local speed = tonumber(player:GetAttribute("RaceLocalSpeed")) or 0
	local pool = tonumber(player:GetAttribute("RaceStaminaLocal")) or 1
	local g = tonumber(player:GetAttribute("RaceChargeLocal")) or 0
	local assist = player:GetAttribute("RaceChargeAssist") == true
	local touch = plan ~= nil and plan.Touch == true

	-- Bars (they move only when their value changes).
	-- 2026-09-25: gold while a speed pad's boost lasts (RaceBoostUntil, server clock).
	local boosted = t < (tonumber(player:GetAttribute("RaceBoostUntil")) or -math.huge)
	if boosted ~= (speedBar:GetAttribute("Boosted") == true) then
		speedBar:SetAttribute("Boosted", boosted)
		shownFill.Speed = -1
		setFill(speedBar, "Speed", speed / math.max(1, sprintMax), if boosted then BOOST_FILL else RaceUiKit.SpeedFill)
	else
		setFill(speedBar, "Speed", speed / math.max(1, sprintMax))
	end
	local low = pool < RACE.Stamina.MinSprintPool
	if low ~= (staminaBar:GetAttribute("Low") == true) then
		staminaBar:SetAttribute("Low", low)
		shownFill.Stamina = -1
		setFill(staminaBar, "Stamina", pool, if low then RaceUiKit.LowFill else RaceUiKit.StaminaFill)
	else
		setFill(staminaBar, "Stamina", pool)
	end

	-- The charge: the gauge and hint (Countdown and GAUGE_AFTER_GO after GO), the ring on touch.
	local charging = beforeGo and phase == "Countdown"
	local showGauge = charging or (t >= goAt and t < goAt + GAUGE_AFTER_GO and goAt > 0)
	-- Held: a throb of 3-9 beats a second, up to 6 % (never still while the button is down).
	local pulse = 1
	if charging and player:GetAttribute("RaceChargeHeld") == true then
		local level = math.clamp(g, 0, 1)
		pulse = 1 + (0.02 + 0.04 * level) * (0.5 + 0.5 * math.sin(os.clock() * math.pi * 2 * (3 + 6 * level)))
	end
	if math.abs(gaugePulse.Scale - pulse) > 0.001 then
		gaugePulse.Scale = pulse
		ringPulse.Scale = pulse
	end
	if touch then
		-- (The input switched to touch mid-countdown: the ring takes over from the bar.)
		if gauge.Visible then
			gauge.Visible = false
		end
	else
		gauge.Visible = showGauge
		if showGauge then
			paintBands(assist)
			local v = math.clamp(g, 0, 1)
			if math.abs(shownFill.Charge - v) >= 0.002 then
				shownFill.Charge = v
				gauge.Fill.Size = UDim2.fromScale(v, 1)
				gauge.Needle.Position = UDim2.fromScale(v, 0.5)
			end
		end
	end
	if touch then
		if not action.Visible then
			action.Visible, ring.Visible = true, true
		end
		if beforeGo then
			paintRing(g, true, assist)
		else
			paintRing(pool, false, false)
		end
		setText(action.Label, if beforeGo then text("Charge") else text("Boost"))
		local palette = if not beforeGo and low then "Red" else "Blue"
		if action:GetAttribute("Palette") ~= palette then
			kit:paint(action, palette)
		end
		local squeeze = if player:GetAttribute("RaceChargeHeld") == true then 0.92 else 1
		if pressedScale.Scale ~= squeeze then
			pressedScale.Scale = squeeze
		end
	elseif action.Visible then
		action.Visible, ring.Visible = false, false
	end
	-- 2026-09-26 (owner: console first-class): on a gamepad the hint stays up while racing, with
	-- the sprint's button ("[R2] BOOST"), from when the gauge has gone until the finish.
	local gamepad = plan ~= nil and plan.Input == "Gamepad"
	local padRacing = gamepad and goAt > 0 and t >= goAt + GAUGE_AFTER_GO and (state == "Racing" or state == "Staged")
	hint.Visible = (charging or padRacing) and os.clock() >= bannerUntil
	setHintGlyphs(if not gamepad then "None" elseif padRacing then "Race" else "Charge")
	banner.Visible = os.clock() < bannerUntil

	-- Countdown number (pops on each second), "GO!" (fades after 0.7 s).
	if beforeGo and phase == "Countdown" then
		local count = math.clamp(math.ceil(goAt - t), 1, QUEUE.CountdownSeconds)
		countdown.Visible = true
		if count ~= lastCount then
			lastCount = count
			numberLabel.Text = tostring(count)
			numberLabel.TextColor3 = kit:color("White")
			numberLabel.TextTransparency = 0
			numberLabel.Outline.Transparency = 0
			startingLabel.Visible = true
			pop(numberPop, 1.45)
		end
	elseif goAt > 0 and t >= goAt and t < goAt + GO_SECONDS + 0.3 then
		countdown.Visible = true
		startingLabel.Visible = false
		if goShownFor ~= goAt then
			goShownFor = goAt
			lastCount = nil
			numberLabel.Text = text("Go")
			numberLabel.TextColor3 = kit:color("Go")
			numberLabel.TextTransparency = 0
			numberLabel.Outline.Transparency = 0
			pop(numberPop, 1.6)
			local fade = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, GO_SECONDS)
			TweenService:Create(numberLabel, fade, { TextTransparency = 1 }):Play()
			TweenService:Create(numberLabel.Outline, fade, { Transparency = 1 }):Play()
			maybeBanner()
		end
	else
		countdown.Visible = false
	end

	if feedback.Visible and os.clock() >= feedbackUntil then
		feedback.Visible = false
	end

	-- Texts, at most 10 times a second.
	textClock += dt
	if textClock < TEXT_INTERVAL then
		return
	end
	textClock = 0
	local mph = HUD.MphPerStud
	setText(speedBar.Text, text("Mph", math.floor(speed * mph + 0.5), math.floor(sprintMax * mph + 0.5)))
	setText(staminaBar.Text, text("Stamina", math.floor(pool * 100 + 0.5)))
	local multiplier = tonumber(player:GetAttribute("RaceRewardMultiplier")) or 1
	setText(labels.Multiplier, text("Multiplier", if multiplier == math.floor(multiplier) then tostring(multiplier) else string.format("%.1f", multiplier)))
	local accel = tonumber(player:GetAttribute("RaceAccelLocal")) or 0
	setText(labels.Accel, text("Accel", string.format("%+d", math.floor(accel * mph + 0.5))))
	if beforeGo and phase == "Countdown" then
		startingLabel.Text = text("Starting", math.max(1, math.ceil(goAt - t)))
		local held = player:GetAttribute("RaceChargeHeld") == true
		local key
		if held then
			key = if assist then "EasyZone" else "StayGreen"
		else
			key = if touch then "HoldTouch" elseif plan and plan.Input == "Gamepad" then "HoldPad" else "HoldKey"
		end
		setText(hint.Text, text(key))
	else
		startingLabel.Text = text("GetReady")
		if padRacing then
			setText(hint.Text, text("Boost"))
		end
	end
	-- Status line.
	if state == "Finished" and finishedAt then
		setText(statusLabel, text("FinishedStatus", RaceText.Ordinal(finishedAt.place, lang)))
	elseif beforeGo or goAt <= 0 then
		setText(statusLabel, text("GetReady"))
	else
		local left = tonumber(Workspace:GetAttribute("RacePhaseEndsAt")) or (goAt + QUEUE.MaxRaceSeconds)
		setText(statusLabel, text("InProgress", math.max(0, math.ceil(left - t)) .. "s"))
	end
	statusLabel.Visible = true
	-- The ORB readout.
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local s = 0
	if root then
		s = RaceTrack.ToLocal(root.Position)
	end
	goal.Visible = true
	setText(goal.Orb, text("Orb"))
	setText(goal.Distance, text("Studs", NumberFormat.FormatWithCommas(math.floor(RaceTrack.DistanceLeft(s) + ORB_BEYOND + 0.5))))
	local elapsed = 0
	if finishedAt then
		elapsed = finishedAt.timeMs / 1000
	elseif goAt > 0 and t > goAt then
		elapsed = t - goAt
	end
	setText(goal.Elapsed, RaceText.Elapsed(elapsed))
end

----------------------------------------------------------------------
-- Showing and hiding the HUD
----------------------------------------------------------------------
local function showHud()
	if shown then
		return
	end
	shown = true
	layout()
	lastCount, goShownFor, finishedAt = nil, nil, nil
	gaugeBands, ringLit, ringMode = nil, -1, nil
	shownFill.Speed, shownFill.Stamina, shownFill.Charge = -1, -1, -1
	for _, piece in { speedBar, staminaBar, labels } do
		piece.Visible = true
	end
	gauge.Visible, hint.Visible, banner.Visible, feedback.Visible = false, false, false, false
	podium.Visible, youPill.Visible = false, false
	action.Visible, ring.Visible = plan ~= nil and plan.Touch == true, plan ~= nil and plan.Touch == true
	hud.Enabled = true
	-- 2026-09-26 (owner): "RaceScreenFx" (Shared/RaceScreenFx: speed lines, vignette, shock
	-- rings, shown by Race/RacePoseClient) stays on screen with the HUD.
	InterfaceHider.Hide(HIDER_OWNER, { hud, results, "TouchGui", "RaceScreenFx" })
	if not renderConnection then
		renderConnection = RunService.RenderStepped:Connect(render)
	end
end

local function hideHud()
	if renderConnection then
		renderConnection:Disconnect()
		renderConnection = nil
	end
	if not shown then
		return
	end
	shown = false
	hud.Enabled = false
	live = nil
	InterfaceHider.Show(HIDER_OWNER)
end

----------------------------------------------------------------------
-- LEAVE (Staged and Racing): the only way out of a staged race besides a reset, which kills
-- the character. Two taps; the server takes the racer back to where they queued.
----------------------------------------------------------------------
local leaveArmedUntil = 0
local leaveBound = false

local function setLeaveLabel(armed)
	if not leaveButton then
		return
	end
	local label = leaveButton:FindFirstChild("Label")
	local value = text(if armed then "LeaveConfirm" else "LeaveRace")
	if label then
		setText(label, value)
	end
	leaveButton.Text = value
end

local function pressLeave()
	if os.clock() < leaveArmedUntil then
		leaveArmedUntil = 0
		setLeaveLabel(false)
		pcall(RaceRequest.FireServer, RaceRequest, "Leave")
		return
	end
	leaveArmedUntil = os.clock() + LEAVE_CONFIRM_SECONDS
	setLeaveLabel(true)
	task.delay(LEAVE_CONFIRM_SECONDS, function()
		if os.clock() >= leaveArmedUntil then
			setLeaveLabel(false)
		end
	end)
end

local function refreshLeave()
	if not leaveButton then
		return
	end
	local state = player:GetAttribute("RaceState")
	local show = shown and (state == "Staged" or state == "Racing")
	if leaveButton.Visible ~= show then
		leaveButton.Visible = show
		leaveArmedUntil = 0
		setLeaveLabel(false)
	end
	-- Gamepad: the View (Select) button, bound only while LEAVE shows.
	if show and not leaveBound then
		leaveBound = true
		ContextActionService:BindAction(LEAVE_ACTION, function(_, inputState)
			if inputState == Enum.UserInputState.Begin then
				pressLeave()
				return Enum.ContextActionResult.Sink
			end
			return Enum.ContextActionResult.Pass
		end, false, Enum.KeyCode.ButtonSelect)
	elseif not show and leaveBound then
		leaveBound = false
		ContextActionService:UnbindAction(LEAVE_ACTION)
	end
end

if leaveButton then
	leaveButton.Activated:Connect(pressLeave)
end

local function refreshHud()
	local state = player:GetAttribute("RaceState")
	local active = player:GetAttribute("RaceActive") == true
	if active and (state == "Staged" or state == "Racing" or state == "Finished") then
		showHud()
	else
		hideHud()
	end
	refreshLeave()
end

player:GetAttributeChangedSignal("RaceState"):Connect(refreshHud)
player:GetAttributeChangedSignal("RaceActive"):Connect(refreshHud)
player.CharacterAdded:Connect(function()
	-- A respawn is a new start: nothing of a race's HUD survives a death.
	task.defer(refreshHud)
end)

-- Local spike feel (Race/RaceInputClient): "OUCH! SPIKES", once per stumble.
player:GetAttributeChangedSignal("RaceLocalStumbleAt"):Connect(function()
	local at = player:GetAttribute("RaceLocalStumbleAt")
	if shown and finite(at) and os.clock() - lastStumbleShown > 1 then
		lastStumbleShown = os.clock()
		showFeedback(text("Spikes"), "Red", 1.0)
	end
end)
-- 2026-09-25: a speed pad (Race/RaceInputClient predicts it): "BOOST!" in gold.
player:GetAttributeChangedSignal("RaceBoostAt"):Connect(function()
	if shown and finite(player:GetAttribute("RaceBoostAt")) then
		showFeedback(text("PadBoost"), "Gold", 0.9)
	end
end)
player:GetAttributeChangedSignal("RaceStartGrade"):Connect(maybeBanner)
player:GetAttributeChangedSignal("RacePredictedGrade"):Connect(maybeBanner)

----------------------------------------------------------------------
-- Results window
----------------------------------------------------------------------
local resultsOpen = false
local resultsSerial = 0
local autoLobbyAt = nil
local againGuardUntil = 0
-- 2026-09-25 review: the window opens at the local finish, before the Results (the server
-- pays first). A racer who already chose RACE AGAIN there is not asked again when the Results
-- arrive (the 8 s timer would send the requeued racer to the lobby); one who chose LOBBY sees
-- the rewards (the timer then only closes the window). nil / "again" / "lobby"; reset at the
-- next Staged.
local decided = nil
-- The field of the last race, kept after the HUD hides (RaceLive stops at the requeue, and the
-- Results come after it): "7TH / 12".
local lastN = nil

-- 2026-09-26 (owner, phone playtest: "when I win the race the results UI is very big on the
-- phone"): the window centres in the room under the top bar and inside the notch (RaceResults
-- uses CoreUISafeInsets) and, on a phone, takes the compact arrangement at the Index's share of
-- that room (RaceUiBuilder.FitWindow, RaceHudLayout.WindowFit).
local RESULTS_SIZES = { Wide = RaceUiBuilder.ResultsSize, Compact = RaceUiBuilder.ResultsCompactSize }
local function fitResults()
	local camera = Workspace.CurrentCamera
	local view = camera and camera.ViewportSize or Vector2.new(1280, 720)
	local room = results.AbsoluteSize
	if room.X < 2 or room.Y < 2 then
		room = Vector2.new(view.X, view.Y - GuiService:GetGuiInset().Y)
	end
	local fit = RaceUiBuilder.FitWindow(kit.env, window, RaceUiBuilder.ArrangeResults, RESULTS_SIZES, view.X, view.Y, room.X, room.Y, UserInputService.TouchEnabled)
	window.FitScale.Scale = fit.Scale
end
results:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitResults)
local cameraConnection = nil
local function bindCamera()
	if cameraConnection then
		cameraConnection:Disconnect()
	end
	local camera = Workspace.CurrentCamera
	if camera then
		cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(fitResults)
	end
	fitResults()
end
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)
bindCamera()

local function setLobbyLabel(seconds)
	local label = lobbyButton.Label
	label.Text = if seconds then text("LobbyIn", seconds) else text("Lobby")
	lobbyButton.Text = label.Text
end

local function closeResults()
	if not resultsOpen then
		return
	end
	resultsOpen = false
	resultsSerial += 1
	autoLobbyAt = nil
	results.Enabled = false
	InterfaceHider.Forget(results)
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(results) then
		GuiService.SelectedObject = nil
	end
end

local function goLobby()
	local wasOpen = resultsOpen
	closeResults()
	if wasOpen and decided == nil then
		decided = "lobby"
	end
	if wasOpen and player:GetAttribute("RaceActive") == true then
		pcall(RaceRequest.FireServer, RaceRequest, "Leave")
	end
end

local function goAgain()
	if os.clock() < againGuardUntil then
		return -- a press carried over from the race (see AGAIN_GUARD_SECONDS)
	end
	closeResults()
	decided = "again"
	local state = player:GetAttribute("RaceState")
	if state == "Queued" or (state == "Finished" and player:GetAttribute("RaceActive") == true) then
		-- Already requeued by the server (auto-requeue), or finished while the others still run
		-- (the server requeues at the Results; a Join now would queue this racer twice): stay,
		-- and keep the auto-requeue on.
		pcall(RaceRequest.FireServer, RaceRequest, "AutoRequeue", true)
	else
		pcall(RaceRequest.FireServer, RaceRequest, "Join", "Results")
	end
end

local function fillPodium(podiumList)
	for rank = 1, 3 do
		local card = content.Podium:FindFirstChild("Card" .. rank)
		local entry = type(podiumList) == "table" and podiumList[rank] or nil
		if card then
			if type(entry) == "table" and finite(entry.UserId) then
				card.Visible = true
				card.Headshot.Image = headshot(entry.UserId)
				setText(card.Headshot.NameStrip.PlayerName, displayName(entry.UserId, entry.Name))
				local mine = entry.UserId == player.UserId
				card.You.Visible = mine
				card.Headshot.Medal.Color = if mine then kit:color("Cyan") else kit:color(RaceUiBuilder.PodiumMedals[rank])
				card.Reward.Icon.Image = HUD.RewardIcon
				setText(card.Reward.Amount, "+" .. compact(entry.Wins))
			else
				card.Visible = false
			end
		end
	end
end

local function chip(name, message, icon)
	local tile = content.Rewards[name]
	tile.Visible = message ~= nil
	if message then
		tile.Label.Text = message
		tile.Icon.Image = icon or ""
		tile.Icon.Visible = icon ~= nil
	end
end

local function openResults(info)
	resultsSerial += 1
	local placeValue = if finite(info.place) then info.place else 0
	local banner_ = content.Place
	if info.outcome == "DQ" then
		banner_.Text = text("Dq")
		banner_.TextColor3 = kit:color("Red")
	elseif info.finished and placeValue >= 1 and placeValue <= 3 then
		local ordinal = RaceText.Ordinal(placeValue, lang)
		banner_.Text = text("PlaceTop", if lang == "en" then string.upper(ordinal) else ordinal)
		banner_.TextColor3 = kit:color(RaceUiBuilder.PodiumMedals[placeValue])
	elseif info.finished and placeValue >= 1 then
		local ordinal = RaceText.Ordinal(placeValue, lang)
		banner_.Text = (if lang == "en" then string.upper(ordinal) else ordinal) .. " / " .. tostring(info.n or "?")
		banner_.TextColor3 = kit:color("White")
	else
		banner_.Text = text("Dnf")
		banner_.TextColor3 = kit:color("Muted")
	end
	pop(banner_.Pop, 1.35)
	content.Time.Text = text("Time", if info.finished then RaceText.Seconds(info.timeMs) else "--")
	content.NewBest.Visible = info.pb == true
	content.NewBest.Label.Text = text("NewBest")
	local best = tonumber(player:GetAttribute("RaceBestMs")) or 0
	if info.finished and finite(info.timeMs) and (best <= 0 or info.timeMs < best) then
		best = info.timeMs
	end
	content.Best.Text = text("Best", RaceText.Seconds(best))
	raceAgain.Label.Text = text("RaceAgain")
	raceAgain.Text = raceAgain.Label.Text
	setLobbyLabel(nil)
	if not resultsOpen then
		resultsOpen = true
		fitResults()
		results.Enabled = true
	end
end

local function fillRewards(you, podiumList)
	content.Pending.Visible = false
	local wins = tonumber(you.Wins) or 0
	local speed = tonumber(you.Speed) or 0
	local tickets = tonumber(you.Tickets) or 0
	chip("Wins", if wins > 0 then text("Wins", compact(wins)) else nil, HUD.RewardIcon)
	chip("Speed", if speed > 0 then text("Speed", compact(speed)) else nil, RaceUiKit.Art.Lightning)
	chip("Ticket", if tickets > 0 then text("Ticket", tickets) else nil, nil)
	chip("FirstToday", if tickets > 0 and (tonumber(you.Multiplier) or 1) >= 2 then text("FirstToday") else nil, nil)
	content.CapNote.Visible = you.CapReduced == true
	content.CapNote.Text = text("CapNote")
	fillPodium(podiumList)
	-- LOBBY (8): the player's decision window; the server keeps them queued meanwhile.
	local serial = resultsSerial
	autoLobbyAt = os.clock() + HUD.ResultsAutoLobbySeconds
	task.spawn(function()
		while resultsOpen and serial == resultsSerial and autoLobbyAt do
			local left = math.ceil(autoLobbyAt - os.clock())
			if left <= 0 then
				goLobby()
				return
			end
			setLobbyLabel(left)
			task.wait(0.25)
		end
	end)
end

raceAgain.Activated:Connect(goAgain)
lobbyButton.Activated:Connect(goLobby)
closeButton.Activated:Connect(goLobby)
ConsolePanelSupport.Bind(results, window, raceAgain, lobbyButton, goLobby)
-- 2026-09-26 (owner: console first-class): ButtonB is LOBBY, as this window's Close is, at once.
-- ConsoleUiScale's universal B (MenuEvents.CloseAll) only turned the window off, leaving the 8 s
-- timer to send the racer to the lobby and hiding the rewards a finisher had not seen yet.
local syncResultsBack = ConsolePanelSupport.Back("RaceResultsBack", function()
	return resultsOpen and results.Enabled
end, goLobby)
results:GetPropertyChangedSignal("Enabled"):Connect(syncResultsBack)

-- Out of the race another way (a death, a stage trip): the window just closes.
player:GetAttributeChangedSignal("RaceActive"):Connect(function()
	if player:GetAttribute("RaceActive") ~= true then
		closeResults()
	end
end)

----------------------------------------------------------------------
-- Server events
----------------------------------------------------------------------
RaceLive.OnClientEvent:Connect(function(packet)
	if not shown or type(packet) ~= "table" then
		return
	end
	live = packet
	if finite(packet.n) then
		lastN = packet.n
	end
	renderPodium()
end)

RaceEvent.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" or type(payload.kind) ~= "string" then
		return
	end
	local kind = payload.kind
	if kind == "Staged" then
		decided, lastN = nil, nil
		closeResults()
		refreshHud()
	elseif kind == "Stumble" then
		if shown and os.clock() - lastStumbleShown > 1 then
			lastStumbleShown = os.clock()
			showFeedback(text("Spikes"), "Red", 1.0)
		end
	elseif kind == "Finished" then
		if finite(payload.place) and finite(payload.timeMs) then
			finishedAt = { place = payload.place, timeMs = payload.timeMs }
			local ordinal = RaceText.Ordinal(payload.place, lang)
			showFeedback(text("FinishedBig", if lang == "en" then string.upper(ordinal) else ordinal), "Gold", 2.2)
			if payload.pb == true then
				task.delay(1.2, function()
					if shown then
						showFeedback(text("NewBest"), "Gold", 1.6)
					end
				end)
			end
			local wasOpen = resultsOpen
			openResults({ finished = true, place = payload.place, timeMs = payload.timeMs, pb = payload.pb == true, n = lastN })
			if not wasOpen then
				againGuardUntil = os.clock() + AGAIN_GUARD_SECONDS
			end
			content.Pending.Visible = true
			content.Pending.Text = text("Pending")
			for _, name in { "Wins", "Speed", "Ticket", "FirstToday" } do
				content.Rewards[name].Visible = false
			end
			content.CapNote.Visible = false
			fillPodium(nil)
		end
	elseif kind == "Results" then
		local you = type(payload.you) == "table" and payload.you or nil
		if you and decided ~= "again" then
			openResults({
				finished = you.Finished == true,
				place = you.Place,
				timeMs = you.TimeMs,
				pb = you.PB == true,
				outcome = you.Outcome,
				n = lastN or (type(payload.podium) == "table" and #payload.podium or nil),
			})
			fillRewards(you, payload.podium)
		elseif you then
			-- 2026-09-25 (final fix): RACE AGAIN was chosen before the rewards arrived. The
			-- requeued racer still sees them: a line on the lobby's toast plate
			-- (RaceLobbyController reads these two local attributes).
			local parts = {}
			local wins, speed, tickets = tonumber(you.Wins) or 0, tonumber(you.Speed) or 0, tonumber(you.Tickets) or 0
			if wins > 0 then
				table.insert(parts, text("Wins", compact(wins)))
			end
			if speed > 0 then
				table.insert(parts, text("Speed", compact(speed)))
			end
			if tickets > 0 then
				table.insert(parts, text("Ticket", tickets))
			end
			if you.PB == true then
				table.insert(parts, text("NewBest"))
			end
			if #parts > 0 then
				player:SetAttribute("RaceResultsSummary", table.concat(parts, "  "))
				player:SetAttribute("RaceResultsSummaryAt", os.clock())
			end
		end
	elseif kind == "Toast" then
		if shown and type(payload.key) == "string" and RaceText.Caps[payload.key] then
			showFeedback(text(payload.key), "White", 2.5)
		end
	elseif kind == "Unqueued" then
		refreshHud()
	end
end)

refreshHud()
