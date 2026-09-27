-- FunnelAnalytics.luau
-- The game's funnels in Creator Hub (AnalyticsService:LogFunnelStepEvent), behind one safe
-- door. Every call site uses FunnelAnalytics.Step; it never throws and never waits:
--   * the AnalyticsService call runs in its own thread, inside pcall, so an error or a slow
--     call cannot reach or hold up the gameplay code that reported the step;
--   * a step is logged at most once per player, funnel session and step (per server), so a
--     loop that reports the same moment twice does not count it twice;
--   * unknown funnels, steps or players are ignored.
--
-- Funnels (step numbers as Creator Hub shows them):
--   Onboarding_FTUE          one-time, only for players who start it (no rebirth, World 2
--                            locked when they join): the join, the first treadmill, 100
--                            speed and the first lap are watched here; the first rebirth
--                            (RebirthSystem) and World 2 (WorldPortalService) are reported.
--   Monetization_Revive      one funnel session per death offer (its token):
--                            SpeedProductPurchases.
--   Engagement_SpinWheel     one session each time the panel opens: SpinWheelService, and
--                            the pack receipts in SpeedProductPurchases.
--   Monetization_StarterPack one-time: the icon click and the prompt are reported by the
--                            client (FunnelReport remote, whitelisted and rate limited),
--                            the purchase by SpeedProductPurchases.
--   CoreLoop_Rebirths        one-time: RebirthSystem (threshold, rebirth) and
--                            WorldPortalService (World 3).
--   Engagement_Quests        one session each time the panel opens: QuestService.
--   Engagement_AFK           one session each time the earnings panel opens or AFK
--                            mode is started: AfkRewardsService and AfkZoneService.

local FunnelAnalytics = {}

FunnelAnalytics.Funnels = {
	Onboarding_FTUE = { "PlayerJoined", "FirstTreadmillRun", "Speed_100_Reached", "World1_FirstLap", "FirstRebirth_Completed", "World2_Unlocked" },
	Monetization_Revive = { "RevivePrompt_Shown", "RevivePrompt_Purchased", "RevivePrompt_Dismissed", "RevivePrompt_TimedOut" },
	Engagement_SpinWheel = { "Wheel_Opened", "Wheel_FreeSpinUsed", "Wheel_PaidSpinPrompted", "Wheel_PaidSpinCompleted", "Wheel_WinsSpinCompleted" },
	Monetization_StarterPack = { "StarterPack_IconClicked", "StarterPack_PromptShown", "StarterPack_Purchased" },
	CoreLoop_Rebirths = { "Rebirth_ThresholdReached", "Rebirth_Executed", "World3_Unlocked" },
	Engagement_Quests = { "Quests_Opened", "Destiny_Chosen", "Tasks_Completed", "Rewards_Claimed" },
	Engagement_AFK = { "AFK_Opened", "AFK_Started", "AFK_RewardEarned", "AFK_Exited" },
}
-- Funnels that run again and again, each run with its own funnel session id.
FunnelAnalytics.Recurring = {
	Monetization_Revive = true,
	Engagement_SpinWheel = true,
	Engagement_Quests = true,
	Engagement_AFK = true,
}
-- What only the client sees, and so the client may report.
FunnelAnalytics.ClientSteps = { Monetization_StarterPack = { [1] = true, [2] = true } }
FunnelAnalytics.ClientReportSeconds = 2
FunnelAnalytics.SpeedMilestone = 100

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local analyticsOk, AnalyticsService = pcall(function()
	return game:GetService("AnalyticsService")
end)
if not analyticsOk then
	AnalyticsService = nil
end

local logged = setmetatable({}, { __mode = "k" }) -- player -> { key = true }
local sessions = setmetatable({}, { __mode = "k" }) -- player -> { funnel = id }
local newcomers = setmetatable({}, { __mode = "k" }) -- player -> true while in onboarding
local lastReport = setmetatable({}, { __mode = "k" }) -- player -> { key = os.clock() }
local sessionCounter = 0

local function validPlayer(player): boolean
	return typeof(player) == "Instance" and player:IsA("Player") and player.Parent == Players
end

-- The call itself: its own thread, inside pcall. Returns nothing and never yields.
local function send(player: Player, funnel: string, session: string?, step: number, stepName: string)
	if not AnalyticsService then
		return
	end
	task.spawn(function()
		local ok, err = pcall(function()
			AnalyticsService:LogFunnelStepEvent(player, funnel, session, step, stepName)
		end)
		if not ok then
			warn("[FunnelAnalytics] " .. funnel .. " step " .. tostring(step) .. " was not logged: " .. tostring(err))
		end
	end)
end

-- Starts a new session of a recurring funnel for `player` and returns its id.
function FunnelAnalytics.NewSession(player: Player, funnel: string): string?
	if not FunnelAnalytics.Recurring[funnel] or not validPlayer(player) then
		return nil
	end
	sessionCounter += 1
	local id = string.format("%d-%d-%d", player.UserId, os.time(), sessionCounter)
	sessions[player] = sessions[player] or {}
	sessions[player][funnel] = id
	return id
end

-- Logs `step` of `funnel` for `player`. `session` is the funnel session (recurring funnels
-- only): when it is left out, the player's current session is used, or a new one started.
-- Returns true when the step was sent (the first time), false otherwise. Never throws.
function FunnelAnalytics.Step(player: Player, funnel: string, step: number, session: string?): boolean
	local ok, sent = pcall(function()
		local steps = FunnelAnalytics.Funnels[funnel]
		local stepName = steps and steps[step]
		if not stepName or not validPlayer(player) then
			return false
		end
		if funnel == "Onboarding_FTUE" and not newcomers[player] then
			return false
		end
		local id = nil
		if FunnelAnalytics.Recurring[funnel] then
			id = session or (sessions[player] and sessions[player][funnel]) or FunnelAnalytics.NewSession(player, funnel)
		end
		local key = funnel .. "|" .. tostring(id or "") .. "|" .. tostring(step)
		logged[player] = logged[player] or {}
		if logged[player][key] then
			return false
		end
		logged[player][key] = true
		send(player, funnel, id, step, stepName)
		return true
	end)
	return ok and sent == true
end

-- True while `player` is being followed through onboarding.
function FunnelAnalytics.IsNewcomer(player: Player): boolean
	return newcomers[player] == true
end

----------------------------------------------------------------------
-- Onboarding: who takes part, and the steps watched from here
----------------------------------------------------------------------
local function rebirthsOf(player: Player): number
	local leaderstats = player:FindFirstChild("leaderstats")
	local value = leaderstats and leaderstats:FindFirstChild("Rebirths")
	return tonumber(value and value.Value) or tonumber(player:GetAttribute("Rebirths")) or 0
end

local function speedOf(player: Player): number
	local leaderstats = player:FindFirstChild("leaderstats")
	local value = leaderstats and leaderstats:FindFirstChild("Speed")
	return tonumber(value and value.Value) or 0
end

local function onDataLoaded(player: Player)
	if not validPlayer(player) or newcomers[player] ~= nil then
		return
	end
	-- Only players who have not rebirthed nor opened World 2 are in onboarding.
	newcomers[player] = rebirthsOf(player) <= 0 and player:GetAttribute("World2Unlocked") ~= true
	if not newcomers[player] then
		return
	end
	FunnelAnalytics.Step(player, "Onboarding_FTUE", 1)

	local connections = {}
	local function stopWhenDone()
		local done = logged[player] or {}
		if done["Onboarding_FTUE||2"] and done["Onboarding_FTUE||3"] and done["Onboarding_FTUE||4"] then
			for _, connection in connections do
				connection:Disconnect()
			end
			table.clear(connections)
		end
	end
	local function treadmill()
		if player:GetAttribute("IsOnTreadmill") == true then
			FunnelAnalytics.Step(player, "Onboarding_FTUE", 2)
			stopWhenDone()
		end
	end
	local function speed()
		if speedOf(player) >= FunnelAnalytics.SpeedMilestone then
			FunnelAnalytics.Step(player, "Onboarding_FTUE", 3)
			stopWhenDone()
		end
	end
	-- The first lap: World 1's finish pad (NewWorld1ManualStagePads) marks its claim.
	local function lap()
		if player:GetAttribute("NewWorld1FinalWinStageClaimed") == true then
			FunnelAnalytics.Step(player, "Onboarding_FTUE", 4)
			stopWhenDone()
		end
	end
	table.insert(connections, player:GetAttributeChangedSignal("IsOnTreadmill"):Connect(treadmill))
	table.insert(connections, player:GetAttributeChangedSignal("NewWorld1FinalWinStageClaimed"):Connect(lap))
	local leaderstats = player:FindFirstChild("leaderstats")
	local speedValue = leaderstats and leaderstats:FindFirstChild("Speed")
	if speedValue then
		table.insert(connections, speedValue.Changed:Connect(speed))
	end
	treadmill()
	speed()
end

local function watchPlayer(player: Player)
	if player:GetAttribute("DataLoaded") == true then
		task.defer(onDataLoaded, player)
		return
	end
	local connection
	connection = player:GetAttributeChangedSignal("DataLoaded"):Connect(function()
		if player:GetAttribute("DataLoaded") == true then
			connection:Disconnect()
			-- leaderstats are filled in the same frame; read them after it.
			task.defer(onDataLoaded, player)
		end
	end)
end

----------------------------------------------------------------------
-- Steps reported by the client
----------------------------------------------------------------------
local function onClientReport(player: Player, funnel: any, step: any)
	if type(funnel) ~= "string" or type(step) ~= "number" then
		return
	end
	local allowed = FunnelAnalytics.ClientSteps[funnel]
	if not allowed or not allowed[step] then
		return
	end
	local key = funnel .. "|" .. tostring(step)
	lastReport[player] = lastReport[player] or {}
	local now = os.clock()
	if now - (lastReport[player][key] or -math.huge) < FunnelAnalytics.ClientReportSeconds then
		return
	end
	lastReport[player][key] = now
	FunnelAnalytics.Step(player, funnel, step)
end

local started = false
function FunnelAnalytics.Start()
	if started then
		return
	end
	started = true
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end
	local report = remotes:FindFirstChild("FunnelReport")
	if not (report and report:IsA("RemoteEvent")) then
		report = Instance.new("RemoteEvent")
		report.Name = "FunnelReport"
		report.Parent = remotes
	end
	report.OnServerEvent:Connect(function(player, funnel, step)
		pcall(onClientReport, player, funnel, step)
	end)
	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(watchPlayer, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		logged[player] = nil
		sessions[player] = nil
		newcomers[player] = nil
		lastReport[player] = nil
	end)
end

-- Every script that reports a step requires this module, so the first require starts it.
local startedOk, startError = pcall(FunnelAnalytics.Start)
if not startedOk then
	warn("[FunnelAnalytics] Could not start: " .. tostring(startError))
end

return FunnelAnalytics
