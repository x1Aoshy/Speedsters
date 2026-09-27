-- QuestService.server.luau
-- Choose Your Destiny quests (Shared.QuestCatalog), on the same persistent profile as the
-- economy: every day three quests to pick from; the chosen one's tasks count from the
-- moment it was picked; finishing them pays every reward, once.
--
-- Progress is counted on the profile: Speed earned (Data/SessionActor), Win pads claimed
-- (RewardPadClaims, any stage) and rebirths (ProfileReducers) as they happen; stages cleared and time
-- played are kept here in memory and saved when a quest is chosen or claimed, when the player
-- leaves, and every SAFETY_FLUSH_SECONDS. (Saving every 10 seconds wrote every profile to the
-- DataStore 6 times a second on a full server and held the data lock the Speed ticks wait on.)
-- The open panel (UI/QuestController) gets the day's quests every 2 seconds, with this server's
-- unsaved stages and seconds already added; the HUD badge attributes of everyone else are
-- refreshed every 10 seconds.
--
-- The client panel creates no remotes of its own, so this service runs everywhere and
-- serves only the players Shared.FeatureGate lets see the preview features.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local FeatureGate = require(RS:WaitForChild("Shared"):WaitForChild("FeatureGate"))
local SSS = game:GetService("ServerScriptService")
local Catalog = require(RS.Shared.QuestCatalog)
-- M33 (2026-09-25): yesterday's finished quest (Shared/QuestPeriod.FindLate) is paid by itself.
-- Without the module nothing is paid late (the rest of the service still runs).
local QuestPeriod = (function()
	local ok, api = pcall(function()
		return require(RS.Shared:WaitForChild("QuestPeriod", 10))
	end)
	if ok and type(api) == "table" and type(api.FindLate) == "function" then
		return api
	end
	return { FindLate = function() return nil end }
end)()
local DataService = require(SSS.Services.Data.DataService)
local RateLimiter = require(SSS.Services.ServerRateLimiter)
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
local Remotes = RS:WaitForChild("Remotes")

local function remote(name)
	local existing = Remotes:FindFirstChild(name)
	if not existing then
		existing = Instance.new("RemoteEvent")
		existing.Name = name
		existing.Parent = Remotes
	end
	return existing
end
local Request, Update = remote("QuestRequest"), remote("QuestUpdate")

local POTION_BUFFS = { PotionSpeed = "SpeedPotion", PotionWins = "WinsPotion" }
-- Unsaved stages and seconds are saved at least this often (and always on choose, claim, leave).
local SAFETY_FLUSH_SECONDS = 300
-- M33: unsaved stages and seconds are saved this close to the quest day's end.
local PRE_ROLLOVER_FLUSH_SECONDS = 10
-- A panel that asked for the quests (Open/State/Choose/Claim) is pushed every 2 seconds for this
-- long; the client sends no "Close", so this is how long an open panel stays live.
local WATCH_SECONDS = 300
local sessions = {}

local function profile(player)
	if player:GetAttribute("DataLoaded") ~= true then
		return nil
	end
	local handle = DataService.GetHandle(player.UserId)
	if not handle then
		return nil
	end
	local result = DataService.Inspect(handle)
	return result.ok and result.value.profile or nil, handle
end

local function levelOf(player)
	return math.max(1, math.floor(tonumber(player:GetAttribute("Level")) or 1))
end

-- The day's quests for this player, as the panel draws them.
local function view(player, state, current, now)
	local period = Catalog.PeriodOf(now)
	local questState = current.QuestState or {}
	local destiny = questState.Destiny
	local isCurrentPeriod = destiny ~= nil and destiny.Period == period
	local chosen = if isCurrentPeriod then destiny.Choice or 0 else 0
	local isClaimedActive = if isCurrentPeriod then destiny.Claimed == true else false
	local claimedChoices = if isCurrentPeriod and type(destiny.ClaimedChoices) == "table" then destiny.ClaimedChoices else {}
	if isClaimedActive and chosen ~= 0 then
		claimedChoices[tostring(chosen)] = true
	end
	local daily = questState.Daily
	local counted = if daily and daily.Period == period then daily.Progress or {} else {}
	-- What this server has not saved yet counts too.
	local unsaved = {
		stages = state.stages,
		playtime = math.max(0, math.floor(os.clock() - state.sample)),
	}
	local level, speed = levelOf(player), tonumber(current.Speed) or 0
	local paths = {}
	for index, path in Catalog.PathsFor(period) do
		local isChosen = isCurrentPeriod and index == chosen
		local isPathClaimed = isCurrentPeriod and (claimedChoices[tostring(index)] == true or (isChosen and isClaimedActive))
		local tasks, complete = {}, true
		for _, task in path.Tasks do
			local target = if isChosen
				then (destiny.Targets[task.Metric] or Catalog.TargetFor(task, speed, level))
				else Catalog.TargetFor(task, speed, level)
			local progress = 0
			if isPathClaimed then
				progress = target
			elseif isChosen then
				local total = (counted[task.Metric] or 0) + (unsaved[task.Metric] or 0)
				progress = math.clamp(total - (destiny.Baseline[task.Metric] or 0), 0, target)
			end
			complete = complete and progress >= target
			table.insert(tasks, {
				Metric = task.Metric,
				Icon = Catalog.Metrics[task.Metric].Icon,
				Image = Catalog.Metrics[task.Metric].Image,
				Text = Catalog.TaskText(task.Metric, target),
				Target = target,
				Progress = progress,
				ProgressText = Catalog.ProgressText(task.Metric, progress, target),
			})
		end
		local rewards = {}
		for _, reward in path.Rewards do
			table.insert(rewards, {
				Kind = reward.Kind,
				Icon = Catalog.RewardIcons[reward.Kind],
				Text = Catalog.RewardText(reward, level, speed),
			})
		end
		table.insert(paths, {
			Id = path.Id,
			Title = path.Title,
			Tasks = tasks,
			Rewards = rewards,
			Complete = isPathClaimed or (isChosen and complete),
			Claimed = isPathClaimed,
			Active = isChosen and not isPathClaimed,
		})
	end
	return {
		Period = period,
		TimeLeft = Catalog.PeriodEnd(now) - now,
		Choice = chosen,
		Claimed = isClaimedActive,
		ClaimedChoices = claimedChoices,
		Paths = paths,
	}
end

-- `badgeOnly`: refresh the HUD badge attributes and the funnel without sending the panel.
local function sync(player, message, success, badgeOnly)
	local state = sessions[player]
	local current = profile(player)
	if not state or not current then
		if not badgeOnly then
			Update:FireClient(player, { message = "Your data is loading. Please try again." })
		end
		return
	end
	local payload = view(player, state, current, os.time())
	payload.message = message
	payload.success = success
	local chosen = tonumber(payload.Choice) or 0
	local isWaitingChoice = false
	local isReadyToClaim = false
	if chosen ~= 0 and payload.Claimed ~= true and payload.Paths[chosen] ~= nil and payload.Paths[chosen].Complete == true then
		isReadyToClaim = true
	end
	if not isReadyToClaim and (chosen == 0 or payload.Claimed == true) then
		for _, p in payload.Paths do
			if not p.Claimed then
				isWaitingChoice = true
				break
			end
		end
	end
	player:SetAttribute("QuestRewardReady", isReadyToClaim)
	player:SetAttribute("QuestAvailable", isWaitingChoice or isReadyToClaim)
	if isReadyToClaim then
		FunnelAnalytics.Step(player, "Engagement_Quests", 3)
	end
	if not badgeOnly then
		Update:FireClient(player, payload)
	end
end

-- Saves the stages cleared and seconds played since the last save.
local function flush(player)
	local state = sessions[player]
	local current, handle = profile(player)
	if not state or not current or state.busy then
		return false
	end
	state.busy = true
	if not state.pending then
		local seconds = math.max(0, math.floor(os.clock() - state.sample))
		state.sample += seconds
		local stages = state.stages
		state.stages = 0
		state.pending = {
			operationId = DataService.NewOperationId(),
			fingerprint = "quest-progress",
			commands = {
				{ kind = "QuestProgress", metric = "playtime", amount = seconds },
				{ kind = "QuestProgress", metric = "stages", amount = stages },
			},
		}
	end
	local ok, result = pcall(DataService.Commit, handle, state.pending)
	local committed = ok and (result.kind == "Committed" or result.kind == "AlreadyCommitted")
	if committed then
		state.pending = nil
		state.lastFlush = os.clock()
	end
	state.busy = false
	return committed
end

-- Choose and Claim save first; a save already running (the safety flush) is waited for
-- instead of failing the claim with "Saving progress".
local function flushNow(player)
	local state = sessions[player]
	local deadline = os.clock() + 5
	while state and state.busy and os.clock() < deadline do
		task.wait(0.1)
	end
	return flush(player)
end

-- The reward commands of `path` for this player now (level and Speed at claim time).
local function rewardCommands(player, path, current, commands)
	local level, speed = levelOf(player), tonumber(current.Speed) or 0
	for _, reward in path.Rewards do
		local amount = Catalog.RewardAmount(reward, level, speed)
		if reward.Kind == "Wins" then
			table.insert(commands, { kind = "GrantExact", stat = "Wins", amount = amount })
		elseif reward.Kind == "Speed" then
			table.insert(commands, { kind = "GrantExact", stat = "Speed", amount = amount })
		elseif reward.Kind == "SpinTicket" then
			table.insert(commands, { kind = "GrantSpinTickets", amount = amount })
		elseif POTION_BUFFS[reward.Kind] then
			table.insert(commands, {
				kind = "GrantBuff",
				grant = { kind = POTION_BUFFS[reward.Kind], addedSeconds = amount * 60, multiplier = 2, bottleType = "Small" },
			})
		end
	end
	return commands
end

-- M33: a late claim whose save is still being confirmed (Pending) is tried again this often.
local LATE_RETRY_SECONDS = 30
local LATE_MESSAGE = "Yesterday's quest rewards were claimed for you!"

-- M33: pays a quest finished on an earlier day that nobody claimed (it finished just before
-- the day changed, or the player left first). Same operation id as claim() for that day and
-- quest, so it can never pay twice. The caller holds state.acting. Returns true when it paid,
-- and as a second value true when it should be tried again (the save is Pending).
local function payLate(player)
	local current, handle = profile(player)
	local now = os.time()
	local late = current and QuestPeriod.FindLate(current.QuestState, now)
	if not late then
		return false
	end
	local path = Catalog.PathsFor(late.Period)[late.Choice]
	if not path then
		return false
	end
	local commands = rewardCommands(player, path, current, { { kind = "ClaimLateQuestPath", period = late.Period } })
	local operation = "quest-claim:" .. player.UserId .. ":" .. late.Period .. ":" .. tostring(late.Choice)
	local ok, result = pcall(DataService.Commit, handle, { operationId = operation, fingerprint = operation, commands = commands })
	-- AlreadyCommitted: FindLate saw the live profile of a Recovering session, and the earlier
	-- Pending attempt landed inside this Commit. It paid once; the player still hears of it.
	if ok and type(result) == "table" and (result.kind == "Committed" or result.kind == "AlreadyCommitted") then
		FunnelAnalytics.Step(player, "Engagement_Quests", 4)
		sync(player, LATE_MESSAGE, true)
		-- The panel is usually closed at the day change or on joining: say it with a toast too
		-- (BoostNotifier, which honours HidePopups).
		local state = sessions[player]
		local toast = Remotes:FindFirstChild("TemporaryBoostUpdate")
		if toast and toast:IsA("RemoteEvent") and player.Parent and not (state and os.clock() < state.watchUntil) then
			toast:FireClient(player, { Type = "Retention", Message = LATE_MESSAGE, Success = true })
		end
		return true, false
	end
	return false, ok and type(result) == "table" and result.kind == "Pending"
end

-- Remembers a Pending late claim so the 2 s loop tries it again (the day change, a rejoin or
-- a choose would otherwise be the next chance).
local function noteLate(state, ok, retry)
	if state then
		state.lateRetryAt = if ok and retry == true then os.clock() + LATE_RETRY_SECONDS else nil
	end
end

local function claimLate(player)
	local state = sessions[player]
	if not state or not state.ready or not player.Parent then
		return
	end
	if state.acting then
		-- A choose/claim is running (it pays late itself when it can); look again shortly.
		state.lateRetryAt = os.clock() + 2
		return
	end
	state.acting = true
	local ok, err, retry = pcall(payLate, player)
	state.acting = false
	noteLate(state, ok, retry)
	if not ok then
		warn("[QuestService] late quest claim failed for " .. player.Name .. ": " .. tostring(err))
	end
end

local function setup(player)
	if sessions[player] or not FeatureGate.IsPreviewPlayer(player) then
		return
	end
	player:SetAttribute("QuestAvailable", true)
	local state = { sample = os.clock(), stages = 0, ready = false, stage = 1, lastFlush = os.clock(), watchUntil = 0 }
	sessions[player] = state
	local function ready()
		if state.ready or player:GetAttribute("DataLoaded") ~= true then
			return
		end
		state.ready = true
		state.sample = os.clock()
		state.stage = tonumber(player:GetAttribute("LastReachedStage")) or 1
		state.period = Catalog.PeriodOf(os.time())
		sync(player)
		-- M33: a quest finished on an earlier day (left before claiming) is paid on arrival.
		task.defer(claimLate, player)
	end
	state.loaded = player:GetAttributeChangedSignal("DataLoaded"):Connect(ready)
	-- A stage counts when the player reaches a higher one by running; teleports (which set
	-- StageTeleportArrivalGraceUntil) and going back to the start do not.
	state.stageConnection = player:GetAttributeChangedSignal("LastReachedStage"):Connect(function()
		local stage = tonumber(player:GetAttribute("LastReachedStage")) or 1
		if state.ready and stage > state.stage and os.clock() >= (tonumber(player:GetAttribute("StageTeleportArrivalGraceUntil")) or 0) then
			state.stages += stage - state.stage
		end
		state.stage = stage
	end)
	ready()
end

-- Picks today's quest `index` (1-3). Unsaved progress is saved first, so it belongs to no
-- quest: the chosen quest counts from now.
local function choose(player, index)
	local state = sessions[player]
	if not state or state.acting or type(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > Catalog.PathsPerDay then
		return
	end
	state.acting = true
	-- M33: yesterday's finished quest is paid before today's choice replaces it (a Pending one
	-- is kept as LateDestiny by the choice and tried again).
	local okLate, _, retryLate = pcall(payLate, player)
	noteLate(state, okLate, retryLate)
	flushNow(player)
	local current, handle = profile(player)
	if not current then
		state.acting = false
		sync(player, "Your data is loading. Please try again.", false)
		return
	end
	local now = os.time()
	local period = Catalog.PeriodOf(now)
	local path = Catalog.PathsFor(period)[index]
	local targets = {}
	for _, task in path.Tasks do
		targets[task.Metric] = Catalog.TargetFor(task, tonumber(current.Speed) or 0, levelOf(player))
	end
	local operation = "quest-choose:" .. player.UserId .. ":" .. period .. ":" .. index
	local ok, result = pcall(DataService.Commit, handle, {
		operationId = operation,
		fingerprint = operation,
		commands = { { kind = "ChooseQuestPath", period = period, choice = index, targets = targets } },
	})
	state.acting = false
	local success = ok and (result.kind == "Committed" or result.kind == "AlreadyCommitted")
	if success then
		FunnelAnalytics.Step(player, "Engagement_Quests", 2)
	end
	sync(player, if success then path.Title .. " chosen. Good luck!" else "You cannot choose this quest right now.", success)
end

-- Pays today's chosen quest once all its tasks are done.
local function claim(player)
	local state = sessions[player]
	if not state or state.acting then
		return
	end
	state.acting = true
	if not flushNow(player) then
		state.acting = false
		sync(player, "Saving progress. Please try again.", false)
		return
	end
	local current, handle = profile(player)
	local now = os.time()
	local period = Catalog.PeriodOf(now)
	local destiny = current and current.QuestState and current.QuestState.Destiny
	if not current or not destiny or destiny.Period ~= period or (destiny.Choice or 0) == 0 then
		-- M33: pressed just after the day changed: yesterday's finished quest still pays.
		local paidLate = false
		if current and destiny and destiny.Period ~= period then
			local okLate, paid, retry = pcall(payLate, player)
			paidLate = okLate and paid == true
			noteLate(state, okLate, retry)
		end
		state.acting = false
		if not paidLate then
			sync(player, "Choose a quest first.", false)
		end
		return
	end
	local path = Catalog.PathsFor(period)[destiny.Choice]
	local commands = rewardCommands(player, path, current, { { kind = "ClaimQuestPath", period = period } })
	local operation = "quest-claim:" .. player.UserId .. ":" .. period .. ":" .. tostring(destiny.Choice)
	local ok, result = pcall(DataService.Commit, handle, { operationId = operation, fingerprint = operation, commands = commands })
	state.acting = false
	local success = ok and result.kind == "Committed"
	local repeated = ok and result.kind == "AlreadyCommitted"
	if success then
		FunnelAnalytics.Step(player, "Engagement_Quests", 4)
	end
	sync(
		player,
		if success then "Rewards claimed!" elseif repeated then "Rewards already claimed." else "Finish every task first.",
		success
	)
end

Request.OnServerEvent:Connect(function(player, payload)
	if type(payload) ~= "table" or not sessions[player] or not RateLimiter.Allow(player, "QuestRequest", 0.3) then
		return
	end
	sessions[player].watchUntil = os.clock() + WATCH_SECONDS
	-- The panel asks with "State" (the countdown reached zero, or it opened); "RequestState"
	-- is the older name. A pick names its quest as `choice` (older panels: `index`).
	if payload.action == "Open" then
		FunnelAnalytics.Step(player, "Engagement_Quests", 1, FunnelAnalytics.NewSession(player, "Engagement_Quests"))
		sync(player)
	elseif payload.action == "State" or payload.action == "RequestState" then
		sync(player)
	elseif payload.action == "Choose" then
		choose(player, if payload.choice ~= nil then payload.choice else payload.index)
	elseif payload.action == "Claim" then
		claim(player)
	end
end)

Players.PlayerAdded:Connect(setup)
for _, player in Players:GetPlayers() do
	setup(player)
end
-- Leaving: the unsaved stages and seconds are saved before the data session closes (Bootstrap
-- runs this before Release; a PlayerRemoving flush of our own raced Release and could land on a
-- closed session).
local beforeRelease = _G.SpeedsterBeforeRelease or {}
_G.SpeedsterBeforeRelease = beforeRelease
beforeRelease.Quests = function(player)
	if sessions[player] then
		flushNow(player)
	end
	sessions[player] = nil
end
Players.PlayerRemoving:Connect(function(player)
	local state = sessions[player]
	if state then
		state.loaded:Disconnect()
		state.stageConnection:Disconnect()
		state.ready = false
		-- Kept until the before-release save above has run (it may run after this handler).
		task.delay(30, function()
			if sessions[player] == state then
				sessions[player] = nil
			end
		end)
	end
end)

task.spawn(function()
	local ticks = 0
	while true do
		task.wait(2)
		ticks += 1
		local now = os.clock()
		for player, state in sessions do
			if state.ready then
				-- M33: the quest day changed while playing: pay yesterday's finished quest.
				local unix = os.time()
				local period = Catalog.PeriodOf(unix)
				if state.period ~= period then
					state.period = period
					task.spawn(claimLate, player)
				elseif state.lateRetryAt and now >= state.lateRetryAt and not state.acting then
					state.lateRetryAt = nil
					task.spawn(claimLate, player)
				end
				-- The last seconds of the day: save the unsaved stages and seconds so they still
				-- count for the day's quest (once per day, only with a quest in progress).
				if Catalog.PeriodEnd(unix) - unix <= PRE_ROLLOVER_FLUSH_SECONDS and state.preflushPeriod ~= period and not state.busy then
					state.preflushPeriod = period
					local current = profile(player)
					local destiny = current and current.QuestState and current.QuestState.Destiny
					if destiny and destiny.Period == period and (destiny.Choice or 0) ~= 0 and destiny.Claimed ~= true then
						state.lastFlush = now
						task.spawn(flush, player)
					end
				end
				if now - state.lastFlush >= SAFETY_FLUSH_SECONDS and not state.busy then
					-- Paced by each player's own last save, so the saves spread out.
					state.lastFlush = now
					task.spawn(flush, player)
				end
				if now < state.watchUntil then
					sync(player)
				elseif ticks % 5 == 0 then
					sync(player, nil, nil, true)
				end
			end
		end
	end
end)
