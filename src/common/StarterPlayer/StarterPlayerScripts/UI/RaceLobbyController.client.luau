-- StarterPlayerScripts/UI/RaceLobbyController.client.luau — Update 4 (2026-09-25): how a player
-- in the lobby finds the race (PLAN §7.4 item 5).
--   * The RACE button (RaceLobbyHud, top-left over Mainhud.LeftSideBar): its second line tells
--     the state: "JOIN!" (pulsing, with a red "!", while a race gathers), "IN QUEUE ✓" (green),
--     "LIVE 0:32", "NEXT 0:12", "MEGA RACE!" (gold, during the admin event). A click opens the
--     Race panel (MenuEvents "Race"), the gamepad's D-pad right too; while it says "JOIN!" a
--     click joins at once (RaceRequest "Join", "Hud"). Hidden while the feature is off, and
--     until the tutorial is seen (or a rebirth).
--   * The invite (RaceEvent Invite, while a race gathers): avatars of the queued racers,
--     "RACE IN 0:15!", "5 racers · up to +X Wins", JOIN and x; never while queued, in AFK
--     Mode, in the guided tutorial, under a cinematic or over an open menu; 10 s; after two
--     dismissals only every third invite this session.
--   * The Race panel (RacePanelGui, "RACE"): next race timer, racers ready, JOIN RACE / LEAVE
--     QUEUE, the rewards for 1st/2nd/3rd/finishing (RaceMath.ComputeRewards with the player's
--     own multiplier), FASTEST RACERS weekly / all-time from RaceRequest("Board") (at most
--     one request per 2 s), the player's best and rank.
--   * The Race Gate's sign (Workspace.RaceGate.RaceGateSign): phase, timer, weekly record.
--   * Race toasts outside a race (join refusals, "You left the race").
--   * Creator Hub funnel Onboarding_Race step 1 (FunnelReport), once a session: the first
--     time the RACE button shows, an invite shows or the player walks within 60 studs of the
--     Race Gate. The server refuses it for anyone who has finished a race.
-- No per-frame work: one 0.5 s loop, tweens for the pulse and the invite's slide.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local U4 = require(Shared:WaitForChild("Update4Config"))
local RaceMath = require(Shared:WaitForChild("RaceMath"))
local RaceHudLayout = require(Shared:WaitForChild("RaceHudLayout"))
local RaceUiBuilder = require(Shared:WaitForChild("RaceUiBuilder"))
local RaceUiKit = require(Shared:WaitForChild("RaceUiKit"))
local RaceText = require(Shared:WaitForChild("RaceText"))
local InterfaceHider = require(Shared:WaitForChild("InterfaceHider"))
local MenuEvents = require(Shared:WaitForChild("MenuEvents"))
local ConsolePanelSupport = require(Shared:WaitForChild("ConsolePanelSupport"))
local NumberFormat = require(Shared:WaitForChild("Math"):WaitForChild("NumberFormat"))
local WinsMath = require(Shared:WaitForChild("WinsMath"))
local Config = require(Shared:WaitForChild("Config"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes", 30)
local RaceRequest = Remotes and Remotes:WaitForChild("RaceRequest", 60)
local RaceEvent = Remotes and Remotes:WaitForChild("RaceEvent", 30)
if not (RaceRequest and RaceEvent) then
	return
end

local RACE = U4.Race
local QUEUE = RACE.Queue
local HUD = RACE.Hud
local WORLD = if Config.IsWorld2Place == true then "World2" elseif Config.IsWorld3Place == true then "World3" else "World1"
local LOOP_SECONDS = 0.5
local TOAST_SECONDS = 3
local BOARD_REFRESH_SECONDS = 30
local GATE_ONBOARDING_STUDS = 60
local INVITE_EVERY_AFTER_DISMISSALS = 3

local lang = RaceText.ForPlayer(player)
local kit = RaceUiKit.new()

local function text(key, ...)
	return RaceText.Format(key, lang, ...)
end

local function finite(value)
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function setText(label, value)
	if label.Text ~= value then
		label.Text = value
	end
end

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

local lobbyGui = ensure(RaceUiBuilder.LobbyName, RaceUiBuilder.BuildLobbyHud)
local panelGui = ensure(RaceUiBuilder.PanelName, RaceUiBuilder.BuildPanel)

local raceButton = lobbyGui.RaceButton
local pulse = raceButton.Pulse
local invite = lobbyGui.Invite
local inviteCard = invite.Card
local toast = lobbyGui.Toast
local window = panelGui.Window
local left, right = window.Left, window.Right
local list = right.List

-- 2026-09-25 review: the builder's fixed English words, in the player's language.
window.Title.Text = text("Race")
right.Fastest.Text = text("Fastest")
for _, tabButton in { right.Weekly, right.AllTime } do
	local words = text(tabButton.Name)
	tabButton.Text = words
	tabButton.Label.Text = words
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

----------------------------------------------------------------------
-- Funnel: Onboarding_Race step 1 (once a session)
----------------------------------------------------------------------
local discovered = false
local function reportDiscovered()
	-- 2026-09-25 (final fix): not before the server projected RaceFinishes (about a second after
	-- the data loads): a veteran counted as "discovered" never reaches step 2. The button's
	-- refresh loop asks again once the attribute is there.
	if discovered or player:GetAttribute("RaceFinishes") == nil then
		return
	end
	discovered = true
	task.spawn(function()
		local report = Remotes:WaitForChild("FunnelReport", 10)
		if report and report:IsA("RemoteEvent") then
			pcall(report.FireServer, report, "Onboarding_Race", 1)
		end
	end)
end

----------------------------------------------------------------------
-- Rewards (what the player would win; the server pays its own numbers)
----------------------------------------------------------------------
local function eventMultiplier()
	local untilUnix = tonumber(Workspace:GetAttribute("RaceEventUntil")) or 0
	if untilUnix > os.time() then
		return math.max(1, tonumber(Workspace:GetAttribute("RaceEventMultiplier")) or 1)
	end
	return 1
end

local function megaActive()
	return (tonumber(Workspace:GetAttribute("RaceEventUntil")) or 0) > os.time()
end

local function estimate(rank, finished, n)
	local ok, winsMultiplier = pcall(WinsMath.GetTotalMultiplier, player)
	return RaceMath.ComputeRewards({
		place = rank,
		finished = finished,
		n = n,
		lapWins = Config.SpinWheel and Config.SpinWheel.LapWins and Config.SpinWheel.LapWins[WORLD] or 0,
		world = WORLD,
		rebirths = tonumber(player:GetAttribute("Rebirths")) or 0,
		unlockRebirths = Config.World2UnlockRebirths,
		eventMultiplier = eventMultiplier(),
		winsMultiplier = if ok and finite(winsMultiplier) then winsMultiplier else 1,
	})
end

local function fieldSize()
	local queued = tonumber(Workspace:GetAttribute("RaceQueueCount")) or 0
	local maxPlayers = tonumber(Workspace:GetAttribute("RaceMaxPlayers")) or QUEUE.MaxPlayers
	local mine = if player:GetAttribute("RaceState") == "Queued" then 0 else 1
	return math.clamp(queued + mine, 2, math.max(2, maxPlayers))
end

local function compact(value)
	return NumberFormat.FormatCompact(math.max(0, math.floor(tonumber(value) or 0)))
end

----------------------------------------------------------------------
-- State
----------------------------------------------------------------------
local function serverNow()
	return Workspace:GetServerTimeNow()
end

local function unlocked()
	return player:GetAttribute("FirstTimeTutorialSeen") == true or (tonumber(player:GetAttribute("Rebirths")) or 0) >= 1
end

local function inRace()
	local state = player:GetAttribute("RaceState")
	return state == "Staged" or state == "Racing" or state == "Finished"
end

local function queued()
	return player:GetAttribute("RaceState") == "Queued"
end

-- The clock a queued player waits on: the gathering, or the results + cooldown before the next
-- gathering (a requeued racer, a Race Gate joiner in the staging box). "" otherwise.
local function queueClock(phase, remaining)
	if phase == "Gathering" or phase == "Results" or phase == "Cooldown" then
		return " " .. RaceText.Clock(remaining)
	end
	return ""
end

-- 2026-09-26 (owner): a live event (Super Sonic vs Eggman) closes the races meanwhile: the server writes the
-- Workspace attribute RaceClosedBy (Shared/SuperSonicEvent RaceClosed.Attribute) and refuses every Join with
-- the "RaceEventClosed" toast; the button and the gate's sign say so.
local RACE_CLOSED_ATTRIBUTE = "RaceClosedBy"

-- The button's second line, its palette, and whether it calls for a join.
local function buttonState()
	if Workspace:GetAttribute(RACE_CLOSED_ATTRIBUTE) ~= nil then
		return text("RaceEventClosed"), "Blue", false
	end
	local phase = Workspace:GetAttribute("RacePhase")
	local endsAt = tonumber(Workspace:GetAttribute("RacePhaseEndsAt")) or 0
	local remaining = math.max(0, endsAt - serverNow())
	if queued() then
		-- 2026-09-25 (final fix): with the time left, so a HUD-queued player mid-obby knows when
		-- the staging teleport comes.
		return text("InQueue") .. queueClock(phase, remaining), "Green", false
	elseif inRace() or phase == "Running" then
		return text("Live", RaceText.Clock(remaining)), "Blue", false
	elseif megaActive() then
		return text("Mega"), "Gold", phase == "Gathering"
	elseif phase == "Gathering" then
		return text("Join") .. " " .. RaceText.Clock(remaining), "Blue", true
	elseif phase == "Staging" or phase == "Countdown" then
		return text("StartingSoon"), "Blue", false
	elseif phase == "Results" or phase == "Cooldown" then
		return text("NextIn", RaceText.Clock(remaining)), "Blue", false
	end
	return text("Join"), "Blue", false
end

----------------------------------------------------------------------
-- Layout
----------------------------------------------------------------------
local sidebar = nil
task.spawn(function()
	local mainhud = playerGui:WaitForChild("Mainhud", 30)
	sidebar = mainhud and mainhud:FindFirstChild("LeftSideBar")
end)

-- 2026-09-26 (owner, phone playtest: the race sign-up was too big): the panel centres in the
-- room under the top bar and inside the notch (RacePanelGui uses CoreUISafeInsets) and, on a
-- phone, takes the compact arrangement at the Index's share of that room
-- (RaceUiBuilder.FitWindow, RaceHudLayout.WindowFit).
local PANEL_SIZES = { Wide = RaceUiBuilder.PanelSize, Compact = RaceUiBuilder.PanelCompactSize }
local function fitPanel()
	local camera = Workspace.CurrentCamera
	local view = camera and camera.ViewportSize or Vector2.new(1280, 720)
	local room = panelGui.AbsoluteSize
	if room.X < 2 or room.Y < 2 then
		room = Vector2.new(view.X, view.Y - GuiService:GetGuiInset().Y)
	end
	local fit = RaceUiBuilder.FitWindow(kit.env, window, RaceUiBuilder.ArrangePanel, PANEL_SIZES, view.X, view.Y, room.X, room.Y, UserInputService.TouchEnabled)
	window.FitScale.Scale = fit.Scale
end

local buttonRect = nil
local function layout()
	local size = lobbyGui.AbsoluteSize
	if size.X < 100 or size.Y < 100 then
		return
	end
	local kind = inputKind()
	local topBar = GuiService:GetGuiInset().Y
	local sidebarLeft = if sidebar and sidebar:IsA("GuiObject") and sidebar.AbsoluteSize.X > 0 then sidebar.AbsolutePosition.X else nil
	buttonRect = RaceHudLayout.LobbyButton(size.X, size.Y, kind, sidebarLeft, topBar)
	raceButton.Position = UDim2.fromOffset(buttonRect.Left, buttonRect.Top)
	raceButton.Size = UDim2.fromOffset(buttonRect.Right - buttonRect.Left, buttonRect.Bottom - buttonRect.Top)
	raceButton.Title.TextScaled = false
	raceButton.Title.TextSize = buttonRect.TitleText
	raceButton.State.TextScaled = false
	raceButton.State.TextSize = buttonRect.StateText
	local toastRect = RaceHudLayout.InviteToast(size.X, size.Y, kind, buttonRect, topBar)
	invite.Size = UDim2.fromOffset(toastRect.Right - toastRect.Left, toastRect.Bottom - toastRect.Top)
	invite:SetAttribute("OpenX", toastRect.Left)
	invite:SetAttribute("OpenY", toastRect.Top)
	if not invite.Visible then
		invite.Position = UDim2.fromOffset(-(toastRect.Right - toastRect.Left) - 20, toastRect.Top)
	else
		invite.Position = UDim2.fromOffset(toastRect.Left, toastRect.Top)
	end
	inviteCard.Title.TextScaled = false
	inviteCard.Title.TextSize = toastRect.TitleText
	inviteCard.Body.TextScaled = false
	inviteCard.Body.TextSize = toastRect.BodyText
	toast.Position = UDim2.fromOffset(buttonRect.Left, buttonRect.Bottom + 8)
	toast.Size = UDim2.fromOffset(math.min(size.X - buttonRect.Left - 8, if toastRect.Phone then 250 else 330), if toastRect.Phone then 30 else 36)
	fitPanel()
end
lobbyGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
panelGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitPanel)
UserInputService.LastInputTypeChanged:Connect(function()
	task.defer(layout)
end)
task.delay(1, layout)
task.defer(layout)

----------------------------------------------------------------------
-- The RACE button
----------------------------------------------------------------------
local hudVisible = true
local pulseTween = nil
local function setPulse(on)
	if on and not pulseTween then
		pulse.Scale = 1
		pulseTween = TweenService:Create(pulse, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.08 })
		pulseTween:Play()
	elseif not on and pulseTween then
		pulseTween:Cancel()
		pulseTween = nil
		pulse.Scale = 1
	end
end

local function buttonVisible()
	return U4.IsOn("Race") and unlocked() and hudVisible and not inRace()
end

local function refreshButton()
	local visible = buttonVisible()
	if raceButton.Visible ~= visible then
		raceButton.Visible = visible
		if visible then
			layout()
		end
	end
	if visible and not discovered then
		reportDiscovered() -- waits for RaceFinishes (see reportDiscovered)
	end
	if not visible then
		setPulse(false)
		return
	end
	local line, palette, calling = buttonState()
	setText(raceButton.Title, text("Race"))
	setText(raceButton.State, line)
	if raceButton:GetAttribute("Palette") ~= palette then
		kit:paint(raceButton, palette)
	end
	raceButton.Alert.Visible = calling
	setPulse(calling)
end

-- While a race gathers the button says "JOIN!" and joins at once (source "Hud"); otherwise it
-- opens the Race panel.
raceButton.Activated:Connect(function()
	local _, _, calling = buttonState()
	if calling and not queued() then
		pcall(RaceRequest.FireServer, RaceRequest, "Join", "Hud")
	else
		MenuEvents.Request("Race")
	end
end)

MenuEvents.HUDVisibilityChanged.Event:Connect(function(visible)
	hudVisible = visible == true
	refreshButton()
end)

-- The gamepad's D-pad right opens the panel when nothing on screen is selected.
ContextActionService:BindActionAtPriority("RaceLobbyOpen", function(_, state)
	if state ~= Enum.UserInputState.Begin or GuiService.SelectedObject ~= nil or GuiService.MenuIsOpen then
		return Enum.ContextActionResult.Pass
	end
	if not raceButton.Visible or not lobbyGui.Enabled then
		return Enum.ContextActionResult.Pass
	end
	MenuEvents.Request("Race")
	return Enum.ContextActionResult.Sink
end, false, Enum.ContextActionPriority.Low.Value, Enum.KeyCode.DPadRight)

----------------------------------------------------------------------
-- Toasts outside the race
----------------------------------------------------------------------
local toastSerial = 0
local toastUntil = 0
local function showToastLine(line)
	if type(line) ~= "string" or line == "" or inRace() then
		return
	end
	toastSerial += 1
	toastUntil = os.clock() + TOAST_SECONDS
	local serial = toastSerial
	setText(toast.Text, line)
	toast.Visible = true
	task.delay(TOAST_SECONDS, function()
		if serial == toastSerial then
			toast.Visible = false
		end
	end)
end

local function showToast(key)
	if RaceText.Caps[key] then
		showToastLine(text(key))
	end
end

-- 2026-09-25 (final fix): the rewards of a race whose results the player skipped with RACE
-- AGAIN (RaceHudController sets these two local attributes).
player:GetAttributeChangedSignal("RaceResultsSummaryAt"):Connect(function()
	showToastLine(player:GetAttribute("RaceResultsSummary"))
end)

-- 2026-09-25 (final fix): a player queued in the arena (Race Gate, RACE AGAIN, auto-requeue)
-- stands in the staging box with the normal HUD: the toast plate says what they wait for, with
-- the clock, whenever no other toast is showing.
local waitingShown = false
local function refreshWaiting()
	local waiting = player:GetAttribute("RaceActive") == true and queued() and raceButton.Visible
	if waiting and os.clock() >= toastUntil then
		local endsAt = tonumber(Workspace:GetAttribute("RacePhaseEndsAt")) or 0
		local remaining = math.max(0, endsAt - serverNow())
		setText(toast.Text, text("Waiting") .. queueClock(Workspace:GetAttribute("RacePhase"), remaining))
		toast.Visible = true
		waitingShown = true
	elseif not waiting and waitingShown then
		waitingShown = false
		if os.clock() >= toastUntil then
			toast.Visible = false
		end
	end
end

----------------------------------------------------------------------
-- The invite
----------------------------------------------------------------------
local invitesSeen = 0
local dismissals = 0
local megaShownFor = nil -- RaceEventUntil of the Mega Race whose invite was shown
local inviteSerial = 0
local inviteEndsAt = 0
local inviteCount = 0

local function hideInvite()
	if not invite.Visible then
		return
	end
	inviteSerial += 1
	local width = invite.Size.X.Offset
	local y = tonumber(invite:GetAttribute("OpenY")) or invite.Position.Y.Offset
	local tween = TweenService:Create(invite, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.fromOffset(-width - 20, y) })
	local serial = inviteSerial
	tween.Completed:Connect(function()
		if serial == inviteSerial then
			invite.Visible = false
		end
	end)
	tween:Play()
end

local function inviteAllowed()
	return U4.IsOn("Race")
		and unlocked()
		and player:GetAttribute("RaceState") ~= "Queued"
		and not inRace()
		and player:GetAttribute("AfkModeActive") ~= true
		and player:GetAttribute("GuidedTutorialOpen") ~= true
		and not InterfaceHider.IsHidden()
		and not MenuEvents.AnyOpen()
		and lobbyGui.Enabled
end

local function fillAvatars()
	local shown = 0
	for _, other in Players:GetPlayers() do
		if shown >= 4 then
			break
		end
		if other ~= player and other:GetAttribute("RaceState") == "Queued" then
			shown += 1
			local face = inviteCard.Avatars["Avatar" .. shown]
			face.Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", other.UserId)
			face.Visible = true
		end
	end
	for index = shown + 1, 4 do
		inviteCard.Avatars["Avatar" .. index].Visible = false
	end
end

local function refreshInviteText()
	local secondsLeft = math.max(0, inviteEndsAt - serverNow())
	setText(inviteCard.Title, text("InviteTitle", RaceText.Clock(secondsLeft)))
	inviteCard.Title.TextColor3 = kit:color(if megaActive() then "Gold" else "White")
	local count = math.max(inviteCount, tonumber(Workspace:GetAttribute("RaceQueueCount")) or 0)
	setText(inviteCard.Body, text("InviteBody", count, compact(estimate(1, true, math.max(2, count + 1)).wins)))
end

local function showInvite(endsAt, count, mega)
	invitesSeen += 1
	-- A Mega Race's first invite always shows; later ones follow the dismissal rule too
	-- (2026-09-25 final fix: every mega invite showed, one every race cycle).
	local eventId = Workspace:GetAttribute("RaceEventUntil")
	local firstMega = mega and eventId ~= nil and megaShownFor ~= eventId
	if dismissals >= 2 and invitesSeen % INVITE_EVERY_AFTER_DISMISSALS ~= 0 and not firstMega then
		return
	end
	if not inviteAllowed() then
		return
	end
	layout()
	if mega then
		megaShownFor = eventId
	end
	inviteEndsAt, inviteCount = endsAt, count
	fillAvatars()
	setText(inviteCard.Join.Label, text("InviteJoin"))
	refreshInviteText()
	inviteSerial += 1
	local serial = inviteSerial
	local x = tonumber(invite:GetAttribute("OpenX")) or 12
	local y = tonumber(invite:GetAttribute("OpenY")) or 60
	invite.Position = UDim2.fromOffset(-invite.Size.X.Offset - 20, y)
	invite.Visible = true
	TweenService:Create(invite, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.fromOffset(x, y) }):Play()
	reportDiscovered()
	task.delay(HUD.InviteHideSeconds, function()
		if serial == inviteSerial then
			hideInvite()
		end
	end)
end

inviteCard.Join.Activated:Connect(function()
	hideInvite()
	pcall(RaceRequest.FireServer, RaceRequest, "Join", "Invite")
end)
inviteCard.Dismiss.Activated:Connect(function()
	dismissals += 1
	hideInvite()
end)

----------------------------------------------------------------------
-- The Race panel
----------------------------------------------------------------------
local isOpen = false
local tab = "Weekly"
local board = nil
local lastBoardAskAt = -math.huge
local rows = {}

-- At most one ask per BoardRequestSeconds (the server answers at most that often too).
local function askBoard()
	if os.clock() - lastBoardAskAt < RACE.Leaderboard.BoardRequestSeconds then
		return
	end
	lastBoardAskAt = os.clock()
	pcall(RaceRequest.FireServer, RaceRequest, "Board")
end

local MEDALS = { "🥇", "🥈", "🥉" }
local ROW_TINTS = { RaceUiKit.Colors.Gold, RaceUiKit.Colors.Silver, RaceUiKit.Colors.Bronze }

local function renderBoard()
	local entries = if board then (if tab == "Weekly" then board.weekly else board.allTime) else nil
	local count = if type(entries) == "table" then math.min(#entries, RaceUiBuilder.BoardRows) else 0
	for index = 1, count do
		local entry = entries[index]
		if type(entry) ~= "table" then
			entry = {}
		end
		local row = rows[index]
		if not row then
			row = RaceUiBuilder.BoardRow(kit, list, index)
			for _, object in row:GetDescendants() do
				if object:IsA("TextLabel") then
					RaceText.Style(object, lang)
				end
			end
			rows[index] = row
		end
		local userId = tonumber(entry.UserId) or 0
		row.Visible = true
		setText(row.Rank, MEDALS[index] or ("#" .. index))
		row.Headshot.Image = if userId > 0 then string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", userId) else ""
		setText(row.PlayerName, if type(entry.Name) == "string" and entry.Name ~= "" then entry.Name else "?")
		setText(row.Time, RaceText.Seconds(entry.Ms))
		row.BackgroundColor3 = if ROW_TINTS[index] then kit:rgb(ROW_TINTS[index]) else kit:color("Plate")
		row.BackgroundTransparency = if ROW_TINTS[index] then 0.45 else 0.3
		row.Mine.Enabled = userId == player.UserId
	end
	for index = count + 1, #rows do
		rows[index].Visible = false
	end
	right.Empty.Visible = count == 0
	setText(right.Empty, if board then text("Empty") else text("Loading"))
	-- The player's best and rank on this tab.
	local you = board and type(board.you) == "table" and board.you or {}
	local bestMs = if tab == "Weekly" then tonumber(you.weekBestMs) else tonumber(you.bestMs)
	bestMs = bestMs or tonumber(player:GetAttribute(if tab == "Weekly" then "RaceWeekBestMs" else "RaceBestMs")) or 0
	local rank = if tab == "Weekly" then tonumber(you.weeklyRank) else tonumber(you.allTimeRank)
	if bestMs <= 0 then
		setText(right.YourBest, text("NoTime"))
	elseif rank then
		setText(right.YourBest, text("YourBest", RaceText.Seconds(bestMs), rank))
	else
		setText(right.YourBest, text("YourBestNoRank", RaceText.Seconds(bestMs)))
	end
	kit:paint(right.Weekly, if tab == "Weekly" then "Blue" else "Navy")
	kit:paint(right.AllTime, if tab == "AllTime" then "Blue" else "Navy")
end

local function renderPanel()
	local phase = Workspace:GetAttribute("RacePhase")
	local endsAt = tonumber(Workspace:GetAttribute("RacePhaseEndsAt")) or 0
	local secondsLeft = math.max(0, endsAt - serverNow())
	setText(left.NextRace, text("NextRace"))
	local timer
	if phase == "Gathering" or phase == "Results" or phase == "Cooldown" then
		timer = RaceText.Clock(secondsLeft)
	elseif phase == "Staging" or phase == "Countdown" then
		timer = text("StartingSoon")
	elseif phase == "Running" then
		timer = text("Live", RaceText.Clock(secondsLeft))
	else
		timer = text("Now")
	end
	setText(left.Timer, timer)
	local maxPlayers = tonumber(Workspace:GetAttribute("RaceMaxPlayers")) or QUEUE.MaxPlayers
	setText(left.Ready, text("Ready", tonumber(Workspace:GetAttribute("RaceQueueCount")) or 0, maxPlayers))
	local isQueued = queued()
	left.Join.Visible = not isQueued and not inRace()
	left.Leave.Visible = isQueued
	setText(left.Join.Label, text("JoinRace"))
	setText(left.Leave.Label, text("LeaveQueue"))
	local rewards = left.Rewards
	setText(rewards.Title, text("Rewards"))
	local n = fieldSize()
	for index, key in { "First", "Second", "Third", "Finish" } do
		local row = rewards[key]
		setText(row.Place, if index <= 3 then RaceText.Ordinal(index, lang) else text("Finish"))
		row.Icon.Image = HUD.RewardIcon
		-- Past the podium every finisher gets the same share (place 4 stands for all of them).
		setText(row.Amount, "+" .. compact(estimate(index, true, n).wins))
	end
	setText(rewards.FirstToday, text("FirstRaceToday"))
	renderBoard()
end

local function open()
	if isOpen then
		return
	end
	isOpen = true
	layout()
	fitPanel()
	panelGui.Enabled = true
	renderPanel()
	askBoard()
	task.spawn(function()
		local sinceBoard = 0
		while isOpen do
			task.wait(LOOP_SECONDS)
			if not isOpen then
				break
			end
			renderPanel()
			sinceBoard += LOOP_SECONDS
			if sinceBoard >= BOARD_REFRESH_SECONDS then
				sinceBoard = 0
				askBoard()
			end
		end
	end)
end

local function close()
	if not isOpen then
		return
	end
	isOpen = false
	panelGui.Enabled = false
	-- Closed while a race had the interface hidden: it must not come back after the race.
	InterfaceHider.Forget(panelGui)
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(panelGui) then
		GuiService.SelectedObject = nil
	end
end

left.Join.Activated:Connect(function()
	pcall(RaceRequest.FireServer, RaceRequest, "Join", "Panel")
	if isOpen then
		MenuEvents.Request("Race")
	end
end)
left.Leave.Activated:Connect(function()
	pcall(RaceRequest.FireServer, RaceRequest, "Leave")
end)
right.Weekly.Activated:Connect(function()
	tab = "Weekly"
	renderBoard()
end)
right.AllTime.Activated:Connect(function()
	tab = "AllTime"
	renderBoard()
end)
window.Close.Activated:Connect(function()
	if isOpen then
		MenuEvents.Request("Race")
	end
end)
ConsolePanelSupport.Bind(panelGui, window, left.Join, window.Close, function()
	if isOpen then
		MenuEvents.Request("Race")
	end
end)

MenuEvents.Listen("Race", function(action, detail)
	-- The Flash's WEEKLY RECORDS (2026-09-25): always opens, on the Weekly board.
	-- MenuEvents.Request("Race", "Weekly") fires ("Open", "Weekly") (2026-09-26 fix).
	if action == "Weekly" or detail == "Weekly" then
		tab = "Weekly"
		if isOpen then
			renderPanel()
		else
			open()
		end
		return
	end
	local shouldOpen = action == "Open" or (action ~= "Close" and not isOpen)
	if shouldOpen then
		open()
	else
		close()
	end
end)
MenuEvents.CloseAll.Event:Connect(function(except)
	if except ~= "Race" then
		close()
	end
end)
-- A panel that other code closed (MenuEvents turns its ScreenGui off) is closed here too.
panelGui:GetPropertyChangedSignal("Enabled"):Connect(function()
	if not panelGui.Enabled and isOpen then
		isOpen = false
	end
end)
MenuEvents.MarkReady("Race", function()
	return isOpen and panelGui.Enabled
end)

----------------------------------------------------------------------
-- The Race Gate's sign
----------------------------------------------------------------------
local gatePosition = RACE.Gate[WORLD] and RACE.Gate[WORLD].Position or nil

local function refreshGate()
	local gate = Workspace:FindFirstChild("RaceGate")
	local sign = gate and gate:FindFirstChild("RaceGateSign")
	if sign then
		local title, status, record = sign:FindFirstChild("Title"), sign:FindFirstChild("Status"), sign:FindFirstChild("Record")
		if title and title:IsA("TextLabel") then
			setText(title, text("Race"))
		end
		if status and status:IsA("TextLabel") then
			local line = buttonState()
			setText(status, if U4.IsOn("Race") then line else "")
		end
		if record and record:IsA("TextLabel") then
			local ms = tonumber(Workspace:GetAttribute("RaceRecordMs"))
			local name = Workspace:GetAttribute("RaceRecordName")
			if ms and ms > 0 and type(name) == "string" and name ~= "" then
				setText(record, text("GateRecord", RaceText.Seconds(ms), name))
			else
				setText(record, text("GateStep"))
			end
		end
	end
	-- Onboarding: near the gate (the pad when it has streamed in, else its configured place).
	if not discovered and unlocked() then
		local pad = gate and gate:FindFirstChild("RaceGatePad")
		local at = if pad and pad:IsA("BasePart") then pad.Position else gatePosition
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if at and root and (root.Position - at).Magnitude <= GATE_ONBOARDING_STUDS then
			reportDiscovered()
		end
	end
end

----------------------------------------------------------------------
-- Events and the loop
----------------------------------------------------------------------
RaceEvent.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" or type(payload.kind) ~= "string" then
		return
	end
	local kind = payload.kind
	if kind == "Invite" then
		if finite(payload.endsAt) then
			showInvite(payload.endsAt, if finite(payload.count) then payload.count else 0, payload.mega == true)
		end
	elseif kind == "Queued" then
		hideInvite()
		refreshButton()
	elseif kind == "Board" then
		if type(payload.weekly) == "table" and type(payload.allTime) == "table" then
			board = payload
			if isOpen then
				renderBoard()
			end
		end
	elseif kind == "Toast" then
		if type(payload.key) == "string" then
			showToast(payload.key)
		end
	elseif kind == "Unqueued" then
		local key = type(payload.reason) == "string" and RaceText.UnqueuedToast[payload.reason] or nil
		if key then
			showToast(key)
		end
		refreshButton()
	end
end)

for _, name in { "RaceState", "FirstTimeTutorialSeen", "Rebirths" } do
	player:GetAttributeChangedSignal(name):Connect(refreshButton)
end
-- Staged for a race: the panel and the invite go (the race HUD takes the screen).
player:GetAttributeChangedSignal("RaceState"):Connect(function()
	if inRace() then
		hideInvite()
		if isOpen then
			MenuEvents.Request("Race")
			close()
		end
	end
end)

task.spawn(function()
	local gateClock = 0
	while true do
		refreshButton()
		refreshWaiting()
		if invite.Visible then
			if inviteAllowed() and inviteEndsAt > serverNow() then
				refreshInviteText()
			else
				hideInvite()
			end
		end
		gateClock += LOOP_SECONDS
		if gateClock >= 1 then
			gateClock = 0
			refreshGate()
		end
		task.wait(LOOP_SECONDS)
	end
end)
