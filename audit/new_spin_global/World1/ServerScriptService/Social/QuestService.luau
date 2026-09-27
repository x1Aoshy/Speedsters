-- QuestService.server.luau
-- Choose Your Destiny quests (Shared.QuestCatalog), on the same persistent profile as the
-- economy: every day three quests to pick from; the chosen one's tasks count from the
-- moment it was picked; finishing them pays every reward, once.
--
-- Progress is counted on the profile: Speed earned (Data/SessionActor), runs finished
-- (RewardPadClaims) and rebirths (ProfileReducers) as they happen; stages cleared and time
-- played here, saved every 10 seconds. The panel (UI/QuestController) gets the day's
-- quests every 2 seconds, with this server's unsaved stages and seconds already added.
--
-- The client panel creates no remotes of its own, so this service runs everywhere and
-- serves only the players Shared.FeatureGate lets see the preview features.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local FeatureGate = require(RS:WaitForChild("Shared"):WaitForChild("FeatureGate"))
local SSS = game:GetService("ServerScriptService")
local Catalog = require(RS.Shared.QuestCatalog)
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
		TimeLeft = Catalog.PeriodSeconds - now % Catalog.PeriodSeconds,
		Choice = chosen,
		Claimed = isClaimedActive,
		ClaimedChoices = claimedChoices,
		Paths = paths,
	}
end

local function sync(player, message, success)
	local state = sessions[player]
	local current = profile(player)
	if not state or not current then
		Update:FireClient(player, { message = "Your data is loading. Please try again." })
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
	Update:FireClient(player, payload)
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
	end
	state.busy = false
	return committed
end

local function setup(player)
	if sessions[player] or not FeatureGate.IsPreviewPlayer(player) then
		return
	end
	player:SetAttribute("QuestAvailable", true)
	local state = { sample = os.clock(), stages = 0, ready = false, stage = 1 }
	sessions[player] = state
	local function ready()
		if state.ready or player:GetAttribute("DataLoaded") ~= true then
			return
		end
		state.ready = true
		state.sample = os.clock()
		state.stage = tonumber(player:GetAttribute("LastReachedStage")) or 1
		sync(player)
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
	flush(player)
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
	if not flush(player) then
		state.acting = false
		sync(player, "Saving progress. Please try again.", false)
		return
	end
	local current, handle = profile(player)
	local now = os.time()
	local period = Catalog.PeriodOf(now)
	local destiny = current and current.QuestState and current.QuestState.Destiny
	if not current or not destiny or destiny.Period ~= period or (destiny.Choice or 0) == 0 then
		state.acting = false
		sync(player, "Choose a quest first.", false)
		return
	end
	local path = Catalog.PathsFor(period)[destiny.Choice]
	local level, speed = levelOf(player), tonumber(current.Speed) or 0
	local commands = { { kind = "ClaimQuestPath", period = period } }
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
Players.PlayerRemoving:Connect(function(player)
	local state = sessions[player]
	if state then
		state.loaded:Disconnect()
		state.stageConnection:Disconnect()
		task.spawn(flush, player)
	end
	sessions[player] = nil
end)

task.spawn(function()
	local ticks = 0
	while true do
		task.wait(2)
		ticks += 1
		for player, state in sessions do
			if state.ready then
				if ticks % 5 == 0 then
					task.spawn(flush, player)
				end
				sync(player)
			end
		end
	end
end)
