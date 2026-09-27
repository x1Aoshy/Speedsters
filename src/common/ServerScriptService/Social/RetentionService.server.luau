-- RetentionService.server.luau (Update 4, 2026-09-25) — Playtime Boost + Streak Rewards
-- (output/Update4/PLAN.md §7.7; the designer's "Playtime Boost" and "Streak Rewards" panels,
-- UI/PlaytimeBoostController and UI/StreakRewardsController; rules in Shared/RetentionMath).
--
-- Playtime Boost: +10 % Speed gain every 10 minutes in game (AFK included: the goal is time
-- in game), at most +100 %. The counter lives in memory and reaches the profile only through
-- DataService.ApplyVolatile (no DataStore write of its own: the 30 s autosave and Release save
-- it), every 60 s and before Release. A player back within 15 minutes (a world teleport, a
-- crash, an AFK rejoin) keeps their seconds and funnel session.
-- Streak: one check-in per UTC day after 60 s in game (and at midnight for players online),
-- one Commit under the operation id u4streak:<day>, so a day is written once per player
-- (a second server asking gets AlreadyCommitted). Milestones 7/14/21 wait in StreakPending
-- (they survive a broken streak) until the panel's CLAIM pays the oldest one, once
-- (u4streakclaim:<key>).
-- Speed gain: RetentionSpeedGainMultiplier = min(3.4, 1 + playtime + streak + perk), 1 while
-- racing; StatsService/PlayerStatsBridge (integrator) multiply running/treadmill gains by it.
-- No Commit ever runs inside a timer loop: the loop only spawns checkIn (a once-a-day Commit).
--
-- Remotes: RetentionRequest ("Get", panel? | "ClaimStreak"), RemoteGuard 0.5 s;
-- RetentionUpdate { Streak = {Days, Best, Perk, CycleDay, Cycle, NextDayUnix, Pending,
-- Claimed}, Playtime = {Seconds, Anchor, Pct}, Multiplier, Message? }.
-- Player attributes: PlaytimeBoostPct, PlaytimeSessionAnchor (server time the counter started;
-- clients count locally), StreakDays, StreakPerk, StreakRewardPending, StreakNextDayUnix,
-- RetentionSpeedGainMultiplier.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local U4 = require(Shared:WaitForChild("Update4Config"))
local RetentionMath = require(Shared:WaitForChild("RetentionMath"))
local TutorialText = require(Shared:WaitForChild("TutorialText"))
local Services = ServerScriptService:WaitForChild("Services")
local DataService = require(Services:WaitForChild("Data"):WaitForChild("DataService"))
local RemoteGuard = require(Services:WaitForChild("RemoteGuard"))
-- The dispatcher tells whether TitlesSection is built: a U4.Titles.Grant it cannot route would
-- refuse the whole claim, so the title is only asked for when its section is there.
local Update4Profile = (function()
	local ok, api = pcall(function()
		return require(Services:WaitForChild("Data"):WaitForChild("Update4Profile", 10))
	end)
	return if ok and type(api) == "table" then api else nil
end)()
-- Creator Hub funnels (Services.FunnelAnalytics: never throws, never waits).
local FunnelAnalytics = (function()
	local ok, api = pcall(function()
		return require(game:GetService("ServerScriptService"):WaitForChild("Services"):WaitForChild("FunnelAnalytics", 10))
	end)
	if ok and type(api) == "table" then
		return api
	end
	return { Step = function() return false end, NewSession = function() return nil end }
end)()

local PLAYTIME = U4.Playtime
local STREAK = U4.Streak
local CAP = tonumber(U4.RetentionMultiplierCap) or 3.4
local MAX_SECONDS = RetentionMath.PlaytimeMaxSeconds(PLAYTIME)
local TICK = math.max(1, tonumber(PLAYTIME.TickSeconds) or 5)
local SAVE_EVERY = math.max(TICK, tonumber(PLAYTIME.VolatileSaveSeconds) or 60)
local DAY_CHECK_EVERY = 30
local PLAYTIME_EVENT = "U4.Retention.Playtime"

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local function ensureRemote(name: string): RemoteEvent
	local remote = Remotes:FindFirstChild(name)
	if remote and not remote:IsA("RemoteEvent") then
		remote:Destroy()
		remote = nil
	end
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = Remotes
	end
	return remote :: RemoteEvent
end
local Request = ensureRemote("RetentionRequest")
local Update = ensureRemote("RetentionUpdate")

-- player -> { ready, left, joinedAt, inGame, seconds, sessionStart, pct, markers, lastSave,
-- streak (a copy of U4.Retention's streak fields), checkInBusy, claimBusy, failedDay }
local sessions = {}

local function setIfChanged(player: Player, name: string, value: any)
	if player:GetAttribute(name) ~= value then
		player:SetAttribute(name, value)
	end
end

local function langOf(player: Player): string
	local ok, lang = pcall(TutorialText.LanguageFor, player.LocaleId)
	return if ok and type(lang) == "string" then lang else "en"
end

-- Toasts go through BoostNotifier (TemporaryBoostUpdate, Type "Retention"); it respects
-- HidePopups. Bootstrap creates the remote; without it there is simply no toast.
local function toast(player: Player, message: string, success: boolean?)
	-- 2026-09-25 review: a newcomer's "Day 1 streak!" landed 60 s in, in the middle of the
	-- tutorial (PLAN §7.7: nothing retention-related pops up during it). The attributes still
	-- change; only the toast is dropped.
	if player:GetAttribute("FirstTimeTutorialActive") == true then
		return
	end
	local remote = Remotes:FindFirstChild("TemporaryBoostUpdate")
	if remote and remote:IsA("RemoteEvent") and player.Parent then
		remote:FireClient(player, { Type = "Retention", Message = message, Success = success ~= false })
	end
end

local function retentionOf(player: Player): (any, any)
	if player:GetAttribute("DataLoaded") ~= true then
		return nil, nil
	end
	local handle = DataService.GetHandle(player.UserId)
	if not handle then
		return nil, nil
	end
	local ok, result = pcall(DataService.Inspect, handle)
	if not ok or type(result) ~= "table" or not result.ok or not result.value.profile then
		return nil, handle
	end
	local u4 = result.value.profile.U4
	return if type(u4) == "table" and type(u4.Retention) == "table" then u4.Retention else {}, handle
end

local function today(): number
	return RetentionMath.UtcDay(os.time())
end

local function streakSession(player: Player, day: number): string
	return string.format("%d-streak-%d", player.UserId, day)
end

local function liveDays(state): number
	return if U4.IsOn("Streak") then RetentionMath.LiveStreakDays(state.streak, today(), STREAK) else 0
end

-- Publishes the attributes; the anchor only when asked (join and step changes), so clients
-- count the seconds locally and nothing replicates every tick.
local function publish(player: Player, state, withAnchor: boolean?)
	local playtimeOn = U4.IsOn("PlaytimeBoost")
	local streakOn = U4.IsOn("Streak")
	local pct = if playtimeOn then state.pct else 0
	local days = liveDays(state)
	local perk = if streakOn then state.streak.StreakPerk else 0
	setIfChanged(player, "PlaytimeBoostPct", pct)
	if withAnchor then
		setIfChanged(player, "PlaytimeSessionAnchor", if playtimeOn then Workspace:GetServerTimeNow() - state.seconds else 0)
	end
	setIfChanged(player, "StreakDays", days)
	setIfChanged(player, "StreakPerk", perk)
	setIfChanged(player, "StreakRewardPending", streakOn and RetentionMath.OldestPending(state.streak, STREAK) ~= nil)
	setIfChanged(player, "StreakNextDayUnix", RetentionMath.NextUtcMidnight(os.time()))
	local multiplier = RetentionMath.Multiplier(pct / 100, RetentionMath.StreakBonus(days, STREAK), perk, CAP)
	if player:GetAttribute("RaceActive") == true then
		multiplier = 1 -- races pay by their own rules (PLAN §1)
	end
	setIfChanged(player, "RetentionSpeedGainMultiplier", math.floor(multiplier * 1000 + 0.5) / 1000)
end

local function payload(player: Player, state, message: string?)
	local days = liveDays(state)
	local perk = if U4.IsOn("Streak") then state.streak.StreakPerk else 0
	local pct = if U4.IsOn("PlaytimeBoost") then state.pct else 0
	return {
		Streak = {
			Days = days,
			Best = state.streak.StreakBest,
			Perk = perk,
			CycleDay = RetentionMath.CycleDay(days, STREAK),
			Cycle = RetentionMath.Cycle(days, STREAK),
			NextDayUnix = RetentionMath.NextUtcMidnight(os.time()),
			Pending = table.clone(state.streak.StreakPending),
			Claimed = table.clone(state.streak.StreakClaimed),
			Enabled = U4.IsOn("Streak"),
		},
		Playtime = {
			Seconds = state.seconds,
			Anchor = Workspace:GetServerTimeNow() - state.seconds,
			Pct = pct,
			Enabled = U4.IsOn("PlaytimeBoost"),
		},
		Multiplier = player:GetAttribute("RetentionSpeedGainMultiplier") or 1,
		Message = message,
	}
end

local function send(player: Player, state, message: string?)
	if player.Parent then
		Update:FireClient(player, payload(player, state, message))
	end
end

-- The counter into the profile, in memory only (the autosave and Release write it).
local function saveVolatile(player: Player, state)
	if not state.ready then
		return
	end
	local handle = DataService.GetHandle(player.UserId)
	if not handle or type(DataService.ApplyVolatile) ~= "function" then
		return
	end
	state.lastSave = os.clock()
	local ok, result = pcall(DataService.ApplyVolatile, handle, {
		kind = PLAYTIME_EVENT,
		seconds = math.floor(state.seconds),
		lastSeen = os.time(),
		sessionStart = state.sessionStart,
	})
	if not ok or type(result) ~= "table" or result.ok ~= true then
		state.saveFailures = (state.saveFailures or 0) + 1
	end
end

local function playtimeSession(player: Player, state): string
	return string.format("%d-pt-%d", player.UserId, state.sessionStart)
end

-- Funnel markers 10m/30m/60m/Max, each once per play session (a teleport replays the ones
-- already reached, in order, under the same session id; FunnelAnalytics dedupes per server).
local function logMarkers(player: Player, state)
	local reached = RetentionMath.PlaytimeMarkersReached(state.seconds, PLAYTIME)
	for step = state.markers + 1, reached do
		FunnelAnalytics.Step(player, "Retention_PlaytimeBoost", step, playtimeSession(player, state))
	end
	state.markers = math.max(state.markers, reached)
end

local function refreshStreak(player: Player, state)
	local saved = retentionOf(player)
	if saved then
		state.streak = RetentionMath.CopyStreak(saved)
	end
end

local function milestoneEvent(player: Player, days: number)
	local cycleDay = RetentionMath.CycleDay(days, STREAK)
	if cycleDay == 7 or cycleDay == 14 or cycleDay == 21 then
		if type(FunnelAnalytics.Event) == "function" then
			FunnelAnalytics.Event(player, "Streak_Day" .. cycleDay .. "_v2", days)
		end
	end
end

-- Today's check-in: one Commit per player per UTC day (u4streak:<day>).
local function checkIn(player: Player, day: number)
	local state = sessions[player]
	if not state or not state.ready or state.left or state.checkInBusy or not U4.IsOn("Streak") then
		return
	end
	state.checkInBusy = true
	local _, handle = retentionOf(player)
	local before = state.streak
	local predicted, event = RetentionMath.StreakCheckIn(before, day, STREAK)
	local operation = "u4streak:" .. day
	local ok, result = false, nil
	if handle then
		ok, result = pcall(DataService.Commit, handle, {
			operationId = operation,
			fingerprint = operation,
			commands = { { kind = "U4.Retention.CheckIn", day = day } },
		})
	end
	state.checkInBusy = false
	if sessions[player] ~= state or state.left then
		return
	end
	local kind = if ok and type(result) == "table" then result.kind else nil
	if kind == "Committed" then
		refreshStreak(player, state)
		if state.streak.StreakLastDay ~= day then
			state.streak = predicted -- the profile read failed; the Commit did land
		end
		local lang = langOf(player)
		local days = state.streak.StreakDays
		local shown = RetentionMath.FormatMultiplier(1 + RetentionMath.StreakBonus(days, STREAK) + state.streak.StreakPerk)
		if event == "grace" then
			toast(player, RetentionMath.Text("StreakSaved", lang, days, shown))
		elseif event == "reset" then
			toast(player, RetentionMath.Text("StreakRestarted", lang, shown), false)
			if type(FunnelAnalytics.Event) == "function" then
				FunnelAnalytics.Event(player, "Streak_Reset_v2", before.StreakDays)
			end
		elseif event ~= "same" then
			toast(player, RetentionMath.Text("StreakDay", lang, days, shown))
		end
		-- 2026-09-25 review: the check-in lands 60 s in, after the join Daily has usually been
		-- closed, so the one Streak auto-open never sees a milestone reached today. A quiet
		-- toast (after the day's, which stays 4 s on screen) points at the flame's notice.
		local fresh = nil
		for _, key in state.streak.StreakPending do
			if not table.find(before.StreakPending, key) then
				fresh = key
			end
		end
		local _, freshDay = RetentionMath.ParseKey(fresh)
		if freshDay then
			task.delay(4.5, function()
				if sessions[player] == state and not state.left then
					toast(player, RetentionMath.Text("StreakMilestone", langOf(player), freshDay))
				end
			end)
		end
		if event == "next" or event == "grace" then
			milestoneEvent(player, days)
		end
		FunnelAnalytics.Step(player, "Retention_Streak", 1, streakSession(player, day))
	elseif kind == "AlreadyCommitted" then
		-- Another server (the world the player came from) checked today in already.
		refreshStreak(player, state)
		FunnelAnalytics.Step(player, "Retention_Streak", 1, streakSession(player, day))
	elseif kind == "Rejected" and type(result.error) == "table"
		and (result.error.code == "InvalidInput" or result.error.code == "OperationConflict") then
		-- The section refused it (a clock a day off): not asked again today.
		state.failedDay = day
	else
		-- Pending, or a session not taking commits right now (Recovering, closing): the loop
		-- asks again in 30 s, and the operation id keeps it to one write.
		return
	end
	publish(player, state)
	send(player, state)
end

-- CLAIM: pays the oldest pending milestone, once (u4streakclaim:<key>).
local function claim(player: Player)
	local state = sessions[player]
	if not state or not state.ready or state.claimBusy then
		return
	end
	local lang = langOf(player)
	if not U4.IsOn("Streak") then
		send(player, state, RetentionMath.Text("ClaimFailed", lang))
		return
	end
	state.claimBusy = true
	refreshStreak(player, state)
	local key = RetentionMath.OldestPending(state.streak, STREAK)
	local reward = key and RetentionMath.MilestoneReward(key, STREAK)
	local _, handle = retentionOf(player)
	if not key or not reward or not handle then
		state.claimBusy = false
		send(player, state, RetentionMath.Text(if key then "ClaimFailed" else "NothingToClaim", lang))
		return
	end
	local commands = { { kind = "U4.Retention.ClaimStreak", key = key } }
	if reward.SpinTickets > 0 then
		table.insert(commands, { kind = "GrantSpinTickets", amount = reward.SpinTickets })
	end
	if reward.SpeedPotionMinutes > 0 then
		table.insert(commands, { kind = "GrantBuff", grant = { kind = "SpeedPotion",
			addedSeconds = reward.SpeedPotionMinutes * 60, multiplier = 2, bottleType = "Small" } })
	end
	if reward.WinsPotionMinutes > 0 then
		table.insert(commands, { kind = "GrantBuff", grant = { kind = "WinsPotion",
			addedSeconds = reward.WinsPotionMinutes * 60, multiplier = 2, bottleType = "Small" } })
	end
	local titled = reward.TitleId ~= nil and U4.IsOn("Titles") and Update4Profile ~= nil
		and type(Update4Profile.HasSection) == "function" and Update4Profile.HasSection("Titles")
	if titled then
		table.insert(commands, { kind = "U4.Titles.Grant", id = reward.TitleId })
	end
	local operation = "u4streakclaim:" .. key
	local ok, result = pcall(DataService.Commit, handle, { operationId = operation, fingerprint = operation, commands = commands })
	state.claimBusy = false
	if sessions[player] ~= state or state.left then
		return
	end
	local kind = if ok and type(result) == "table" then result.kind else nil
	refreshStreak(player, state)
	local message
	if kind == "Committed" then
		message = RetentionMath.Text("Claimed", lang)
		FunnelAnalytics.Step(player, "Retention_Streak", 3, streakSession(player, today()))
		local titles = (_G :: any).SpeedsterTitles
		if titled and type(titles) == "table" and type(titles.Refresh) == "function" then
			task.spawn(pcall, titles.Refresh, player)
		end
		toast(player, message)
	elseif kind == "AlreadyCommitted" then
		message = RetentionMath.Text("Claimed", lang)
	else
		message = RetentionMath.Text("ClaimFailed", lang)
	end
	publish(player, state)
	send(player, state, message)
end

local function onLoaded(player: Player)
	local state = sessions[player]
	if not state or state.ready or state.left then
		return
	end
	local saved = retentionOf(player)
	if not saved then
		return
	end
	local seconds, sessionStart, resumed = RetentionMath.ResumePlaytime(saved, os.time(), PLAYTIME)
	state.seconds = seconds
	state.sessionStart = sessionStart
	state.resumed = resumed
	state.pct = RetentionMath.PlaytimePercent(seconds, PLAYTIME)
	state.streak = RetentionMath.CopyStreak(saved)
	state.lastSave = os.clock()
	state.lastTick = os.clock()
	state.ready = true
	state.playtimeWasOn = U4.IsOn("PlaytimeBoost")
	if U4.IsOn("PlaytimeBoost") then
		logMarkers(player, state)
	else
		state.markers = RetentionMath.PlaytimeMarkersReached(seconds, PLAYTIME)
	end
	-- Checked in already today on another server: this server's funnel knows step 1 too, so
	-- the panel's step 2 is not dropped by the strict sequence.
	if U4.IsOn("Streak") and state.streak.StreakLastDay == today() then
		FunnelAnalytics.Step(player, "Retention_Streak", 1, streakSession(player, today()))
	end
	publish(player, state, true)
end

local function setup(player: Player)
	if sessions[player] then
		return
	end
	local state = {
		ready = false, left = false, joinedAt = os.clock(), inGame = 0,
		seconds = 0, sessionStart = os.time(), pct = 0, markers = 0, lastSave = os.clock(), lastTick = os.clock(),
		streak = RetentionMath.CopyStreak(nil), connections = {},
	}
	sessions[player] = state
	table.insert(state.connections, player:GetAttributeChangedSignal("DataLoaded"):Connect(function()
		if player:GetAttribute("DataLoaded") == true then
			onLoaded(player)
		end
	end))
	table.insert(state.connections, player:GetAttributeChangedSignal("RaceActive"):Connect(function()
		if state.ready then
			publish(player, state)
		end
	end))
	if player:GetAttribute("DataLoaded") == true then
		onLoaded(player)
	end
end

RemoteGuard.Connect(Request, 0.5, function(player: Player, action: any, panel: any)
	local state = sessions[player]
	if not state or not state.ready or type(action) ~= "string" then
		return
	end
	if action == "Get" then
		if panel == "Streak" and U4.IsOn("Streak") then
			FunnelAnalytics.Step(player, "Retention_Streak", 2, streakSession(player, today()))
		end
		send(player, state)
	elseif action == "ClaimStreak" then
		claim(player)
	end
end)

Players.PlayerAdded:Connect(setup)
for _, player in Players:GetPlayers() do
	task.spawn(setup, player)
end

-- Leaving: the counter goes into the profile before Release writes it (Bootstrap runs this
-- before Release; our own PlayerRemoving could land on a closed session).
local beforeRelease = (_G :: any).SpeedsterBeforeRelease or {};
(_G :: any).SpeedsterBeforeRelease = beforeRelease
beforeRelease.Retention = function(player: Player)
	local state = sessions[player]
	if state and state.ready and U4.IsOn("PlaytimeBoost") then
		saveVolatile(player, state)
	end
end
Players.PlayerRemoving:Connect(function(player: Player)
	local state = sessions[player]
	if not state then
		return
	end
	state.left = true
	for _, connection in state.connections do
		connection:Disconnect()
	end
	-- Kept until the before-release save above has run (it may run after this handler).
	task.delay(30, function()
		if sessions[player] == state then
			sessions[player] = nil
		end
	end)
end)

-- One loop for everyone, every TickSeconds: adds the time, publishes on a step change, saves
-- the counter in memory every VolatileSaveSeconds, and every 30 s spawns the day's check-in.
-- Timers never Commit (PLAN §3.9): checkIn is its own thread and writes once a day.
local function tickPlayer(player: Player, state, now: number, checkDay: boolean)
	local dt = math.clamp(now - state.lastTick, 0, TICK * 3)
	state.lastTick = now
	state.inGame += dt
	if U4.IsOn("PlaytimeBoost") then
		if state.seconds < MAX_SECONDS then
			state.seconds = math.min(MAX_SECONDS, state.seconds + dt)
		end
		local pct = RetentionMath.PlaytimePercent(state.seconds, PLAYTIME)
		if pct ~= state.pct then
			local lang = langOf(player)
			if pct >= (tonumber(PLAYTIME.MaxPercent) or 100) then
				toast(player, RetentionMath.Text("PlaytimeMax", lang))
			elseif state.pct < (tonumber(PLAYTIME.StepPercent) or 10) then
				toast(player, RetentionMath.Text("Playtime10", lang))
			end
			state.pct = pct
			publish(player, state, true)
		end
		logMarkers(player, state)
		if now - state.lastSave >= SAVE_EVERY and not state.saving then
			-- 2026-09-25 review: ApplyVolatile waits for the session lock (a save in flight
			-- holds it for seconds); run inline it held up the one loop, and everyone's
			-- playtime with it (dt is capped at 3 ticks), so each save gets its own thread.
			state.lastSave = now
			state.saving = true
			task.spawn(function()
				pcall(saveVolatile, player, state)
				state.saving = false
			end)
		end
	end
	if checkDay then
		-- Kill switches and midnight change the attributes without any event of their own. The
		-- anchor goes out again when the Playtime switch flips (it was published as 0 while off).
		local playtimeOn = U4.IsOn("PlaytimeBoost")
		publish(player, state, playtimeOn ~= state.playtimeWasOn)
		state.playtimeWasOn = playtimeOn
		local day = today()
		if U4.IsOn("Streak") and state.inGame >= (tonumber(STREAK.CheckInDelaySeconds) or 60)
			and state.streak.StreakLastDay ~= day and state.failedDay ~= day and not state.checkInBusy then
			task.spawn(checkIn, player, day)
		end
	end
end

task.spawn(function()
	local ticks = 0
	while true do
		task.wait(TICK)
		ticks += 1
		local now = os.clock()
		local checkDay = ticks % math.max(1, math.floor(DAY_CHECK_EVERY / TICK)) == 0
		for player, state in sessions do
			if state.ready and not state.left then
				local ok, err = pcall(tickPlayer, player, state, now, checkDay)
				if not ok then
					warn("[RetentionService] tick failed for " .. player.Name .. ": " .. tostring(err))
				end
			elseif not state.ready and not state.left and player:GetAttribute("DataLoaded") == true then
				-- 2026-09-25 review: DataLoaded fires once; a profile read that failed then
				-- (Inspect mid-recovery) left the player without the boost all session.
				pcall(onLoaded, player)
			end
		end
	end
end)
