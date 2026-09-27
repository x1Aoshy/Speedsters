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
--   Onboarding_Ladder        one-time, only for the same newcomers as Onboarding_FTUE: the
--                            join (here), rebirths 1, 3 and 5 below World 2's gate and the
--                            gate's own rebirth count (Config.World2UnlockRebirths, 6 today)
--                            (RebirthSystem, after the commit) and World 2
--                            (WorldPortalService), each step only after the one before it
--                            on this server.
-- Update 4 (2026-09-25), each step only after the one before it on this server unless noted:
--   Engagement_Race          one session per queue join: queued, started, finished,
--                            rewarded (RaceService).
--   Onboarding_Race          one-time: discovered (client), first queue, first charge, first
--                            finish, second race (RaceService); never for a runner who has
--                            already finished a race (RaceFinishes > 0).
--   Retention_Streak         one session per UTC day: check-in, panel, milestone
--                            (RetentionService).
--   Retention_PlaytimeBoost  one session per play session (passed by RetentionService),
--                            10/30/60 minutes and the full boost, in any order.
--   Engagement_Titles        one session per panel opening: opened, equipped (TitleService).
--   Community_Reward         one-time: opened, code tried, claimed (CommunityRewardService).
--   Monetization_StaminaPass one-time, like the Starter Pack: offer, click and prompt from the
--                            client, the purchase from StaminaRegenPass.
-- FunnelAnalytics.Event logs a whitelisted custom event (same safety: pcall, own thread).

local FunnelAnalytics = {}

FunnelAnalytics.Funnels = {
	Onboarding_FTUE = { "PlayerJoined", "FirstTreadmillRun", "Speed_100_Reached", "World1_FirstLap", "FirstRebirth_Completed", "World2_Unlocked" },
	Monetization_Revive = { "RevivePrompt_Shown", "RevivePrompt_Purchased", "RevivePrompt_Dismissed", "RevivePrompt_TimedOut" },
	Engagement_SpinWheel = { "Wheel_Opened", "Wheel_FreeSpinUsed", "Wheel_PaidSpinPrompted", "Wheel_PaidSpinCompleted", "Wheel_WinsSpinCompleted" },
	Monetization_StarterPack = { [0] = "StarterPack_OfferVisible", [1] = "StarterPack_IconClicked", [2] = "StarterPack_PromptShown", [3] = "StarterPack_Purchased" },
	CoreLoop_Rebirths = { "Rebirth_ThresholdReached", "Rebirth_Executed", "World3_Unlocked" },
	Engagement_Quests = { "Quests_Opened", "Destiny_Chosen", "Tasks_Completed", "Rewards_Claimed" },
	Engagement_AFK = { "AFK_Opened", "AFK_Started", "AFK_RewardEarned", "AFK_Exited" },
	-- Step 5 is renamed after World 2's rebirth gate below ("Rebirth7" while the gate is 7).
	Onboarding_Ladder = { "Joined", "Rebirth1", "Rebirth3", "Rebirth5", "Rebirth7", "World2Unlocked" },
	-- Update 4 (2026-09-25).
	Engagement_Race = { "Race_Queued", "Race_Started", "Race_Finished", "Race_Rewarded" },
	Onboarding_Race = { "Race_Discovered", "Race_FirstQueued", "Race_FirstCharged", "Race_FirstFinished", "Race_SecondRace" },
	Retention_Streak = { "Streak_CheckedIn", "Streak_PanelOpened", "Streak_MilestoneClaimed" },
	Retention_PlaytimeBoost = { "Playtime_10m", "Playtime_30m", "Playtime_60m", "Playtime_Max" },
	Engagement_Titles = { "Titles_Opened", "Titles_Equipped" },
	Community_Reward = { "Community_Opened", "Community_RedeemTried", "Community_Claimed" },
	Monetization_StaminaPass = { [0] = "OfferVisible", [1] = "Clicked", [2] = "PromptShown", [3] = "Purchased" },
}
-- Funnels that run again and again, each run with its own funnel session id.
FunnelAnalytics.Recurring = {
	Monetization_Revive = true,
	Engagement_SpinWheel = true,
	Engagement_Quests = true,
	Engagement_AFK = true,
	CoreLoop_Rebirths = true,
	Engagement_Race = true,
	Retention_Streak = true,
	Retention_PlaytimeBoost = true,
	Engagement_Titles = true,
}
-- What only the client sees, and so the client may report.
FunnelAnalytics.ClientSteps = {
	Monetization_StarterPack = { [0] = true, [1] = true, [2] = true },
	-- Update 4: the race's first sighting (HUD button / gate in view) and the pass offer.
	Onboarding_Race = { [1] = true },
	Monetization_StaminaPass = { [0] = true, [1] = true, [2] = true },
}
FunnelAnalytics.ClientReportSeconds = 2
FunnelAnalytics.SpeedMilestone = 100

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- 2026-09-22: the ladder's last rebirth rung is World 2's rebirth gate, read from Config, so
-- a new gate is still the one-line Config edit: with a fixed "Rebirth 7" rung, a gate of 5 or
-- 6 would never log Rebirth7, and World2Unlocked (which follows it) would read 0%.
-- FindFirstChild + pcall: never waits, and a missing Config keeps today's 6.
local function world2GateRebirths(): number
	local ok, gate = pcall(function()
		local shared = ReplicatedStorage:FindFirstChild("Shared")
		local config = shared and shared:FindFirstChild("Config")
		return config and require(config).World2UnlockRebirths
	end)
	gate = if ok then tonumber(gate) else nil
	return if gate then math.max(0, math.floor(gate)) else 6
end
FunnelAnalytics.World2GateRebirths = world2GateRebirths()
-- Rebirth count -> Onboarding_Ladder step (RebirthSystem reads this after a rebirth commits):
-- rebirths 1, 3 and 5 while they are below the gate, then the gate itself as step 5.
FunnelAnalytics.LadderRebirthSteps = {}
for count, step in { [1] = 2, [3] = 3, [5] = 4 } do
	if count < FunnelAnalytics.World2GateRebirths then
		FunnelAnalytics.LadderRebirthSteps[count] = step
	end
end
if FunnelAnalytics.World2GateRebirths >= 1 then
	FunnelAnalytics.LadderRebirthSteps[FunnelAnalytics.World2GateRebirths] = 5
	FunnelAnalytics.Funnels.Onboarding_Ladder[5] = "Rebirth" .. FunnelAnalytics.World2GateRebirths
end
-- Ladder step -> the step that must come before it: the nearest lower step that can happen
-- with this gate (a gate of 5 has no "Rebirth5" rung, so its gate rung follows Rebirth3).
local ladderPrevious = {}
do
	local reachable = { [1] = true, [6] = true }
	for _, step in FunnelAnalytics.LadderRebirthSteps do
		reachable[step] = true
	end
	local previous = nil
	for step = 1, 6 do
		if reachable[step] then
			ladderPrevious[step] = previous
			previous = step
		end
	end
end

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
local customEvents = {
	Progress_Speed100_v2 = true,
	Progress_FirstLap_v2 = true,
	Progress_FirstRebirth_v2 = true,
	Progress_World2_v2 = true,
	Progress_World3_v2 = true,
	Revive_Dismissed_v2 = true,
	Revive_TimedOut_v2 = true,
	StarterPack_Ownership_v2 = true,
	AFK_PanelOpened_v2 = true,
	AFK_Exited_v2 = true,
	-- Update 4 (2026-09-25): FunnelAnalytics.Event names, and the pass ownership route.
	Race_Join_Gate_v2 = true,
	Race_Join_Hud_v2 = true,
	Race_Join_Invite_v2 = true,
	Race_Join_Results_v2 = true,
	Race_Join_Panel_v2 = true,
	-- 2026-09-25: The Flash's sign-up window in the lobby (Gameplay/LobbyNpcs).
	Race_Join_Npc_v2 = true,
	Race_Requeued_v2 = true,
	Race_MegaJoined_v2 = true,
	Race_StartPerfect_v2 = true,
	Race_StartStall_v2 = true,
	Race_Correction_v2 = true,
	Streak_Day7_v2 = true,
	Streak_Day14_v2 = true,
	Streak_Day21_v2 = true,
	Streak_Reset_v2 = true,
	StaminaPass_Ownership_v2 = true,
	LocalDeath_Kill_v2 = true,
	LocalDeath_Revive_v2 = true,
	MG_StrictPass_v2 = true,
	MG_StrictWouldReject_v2 = true,
}

-- A later step in a Roblox funnel also counts every earlier step. Version 2 only
-- sequences events that must happen in order; alternative outcomes are one-step
-- funnels. Keep the old names above to validate existing call sites, but do not
-- keep publishing misleading legacy funnel rows.
local routes = {
	Onboarding_FTUE = {
		[1] = { { "Onboarding_Training_v2", 1, "PlayerJoined" } },
		[2] = { { "Onboarding_Training_v2", 2, "FirstTreadmillRun" } },
		[3] = { { "Progress_Speed100_v2", 1, "Speed100Reached" } },
		[4] = { { "Progress_FirstLap_v2", 1, "World1FirstLap" } },
		[5] = { { "Progress_FirstRebirth_v2", 1, "FirstRebirthCompleted" } },
		[6] = { { "Progress_World2_v2", 1, "World2Unlocked" } },
	},
	Monetization_Revive = {
		[1] = { { "Revive_Purchase_v2", 1, "OfferShown" } },
		[2] = { { "Revive_Purchase_v2", 2, "ReviveApplied" } },
		[3] = { { "Revive_Dismissed_v2", 1, "Dismissed" } },
		[4] = { { "Revive_TimedOut_v2", 1, "TimedOut" } },
	},
	Engagement_SpinWheel = {
		[1] = { { "Wheel_Free_v2", 1, "Opened" }, { "Wheel_Paid_v2", 1, "Opened" }, { "Wheel_Wins_v2", 1, "Opened" } },
		[2] = { { "Wheel_Free_v2", 2, "FreeSpinCompleted" } },
		[3] = { { "Wheel_Paid_v2", 2, "PaidPromptOpened" } },
		[4] = { { "Wheel_Paid_v2", 3, "PaidReceiptGranted" } },
		[5] = { { "Wheel_Wins_v2", 2, "WinsSpinCompleted" } },
	},
	Monetization_StarterPack = {
		[0] = { { "StarterPack_OfferToBuy_v2", 1, "OfferVisible" } },
		[1] = { { "StarterPack_OfferToBuy_v2", 2, "OfferClicked" } },
		[2] = { { "StarterPack_OfferToBuy_v2", 3, "PromptOpened" } },
		[3] = { { "StarterPack_OfferToBuy_v2", 4, "OwnershipConfirmed" }, { "StarterPack_Ownership_v2", 1, "OwnershipConfirmed" } },
	},
	CoreLoop_Rebirths = {
		[1] = { { "Rebirth_EligibleToComplete_v2", 1, "ThresholdReached" } },
		[2] = { { "Rebirth_EligibleToComplete_v2", 2, "RebirthCommitted" } },
		[3] = { { "Progress_World3_v2", 1, "World3Unlocked" } },
	},
	Engagement_Quests = {
		[1] = { { "Quest_ChooseToClaim_v2", 1, "PanelOpened" } },
		[2] = { { "Quest_ChooseToClaim_v2", 2, "PathChosen" } },
		[3] = { { "Quest_ChooseToClaim_v2", 3, "TasksCompleted" } },
		[4] = { { "Quest_ChooseToClaim_v2", 4, "RewardsClaimed" } },
	},
	Engagement_AFK = {
		[1] = { { "AFK_PanelOpened_v2", 1, "PanelOpened" } },
		[2] = { { "AFK_ActiveReward_v2", 1, "AFKStarted" } },
		[3] = { { "AFK_ActiveReward_v2", 2, "RewardEarned" } },
		[4] = { { "AFK_Exited_v2", 1, "Exited" } },
	},
	-- 2026-09-22: v2 has no cohort funnel past the first treadmill (the FTUE steps 3-6 are
	-- custom events), so World 2's 2-3% could not be traced back to a rebirth. This ladder
	-- shows where newcomers stop on the way to World 2's gate.
	Onboarding_Ladder = {
		[1] = { { "Onboarding_Ladder_v2", 1, "Joined" } },
		[2] = { { "Onboarding_Ladder_v2", 2, "Rebirth1" } },
		[3] = { { "Onboarding_Ladder_v2", 3, "Rebirth3" } },
		[4] = { { "Onboarding_Ladder_v2", 4, "Rebirth5" } },
		[5] = { { "Onboarding_Ladder_v2", 5, FunnelAnalytics.Funnels.Onboarding_Ladder[5] } },
		[6] = { { "Onboarding_Ladder_v2", 6, "World2Unlocked" } },
	},
	-- Update 4 (2026-09-25).
	Engagement_Race = {
		[1] = { { "Race_Loop_v2", 1, "Queued" } },
		[2] = { { "Race_Loop_v2", 2, "Started" } },
		[3] = { { "Race_Loop_v2", 3, "Finished" } },
		[4] = { { "Race_Loop_v2", 4, "Rewarded" } },
	},
	Onboarding_Race = {
		[1] = { { "Race_FirstRace_v2", 1, "Discovered" } },
		[2] = { { "Race_FirstRace_v2", 2, "FirstQueued" } },
		[3] = { { "Race_FirstRace_v2", 3, "FirstCharged" } },
		[4] = { { "Race_FirstRace_v2", 4, "FirstFinished" } },
		[5] = { { "Race_FirstRace_v2", 5, "SecondRace" } },
	},
	Retention_Streak = {
		[1] = { { "Streak_Daily_v2", 1, "CheckedIn" } },
		[2] = { { "Streak_Daily_v2", 2, "PanelOpened" } },
		[3] = { { "Streak_Daily_v2", 3, "MilestoneClaimed" } },
	},
	Retention_PlaytimeBoost = {
		[1] = { { "Playtime_Session_v2", 1, "Played10m" } },
		[2] = { { "Playtime_Session_v2", 2, "Played30m" } },
		[3] = { { "Playtime_Session_v2", 3, "Played60m" } },
		[4] = { { "Playtime_Session_v2", 4, "BoostMaxed" } },
	},
	Engagement_Titles = {
		[1] = { { "Titles_Equip_v2", 1, "Opened" } },
		[2] = { { "Titles_Equip_v2", 2, "Equipped" } },
	},
	Community_Reward = {
		[1] = { { "Community_Redeem_v2", 1, "Opened" } },
		[2] = { { "Community_Redeem_v2", 2, "RedeemTried" } },
		[3] = { { "Community_Redeem_v2", 3, "Claimed" } },
	},
	Monetization_StaminaPass = {
		[0] = { { "StaminaPass_OfferToBuy_v2", 1, "OfferVisible" } },
		[1] = { { "StaminaPass_OfferToBuy_v2", 2, "OfferClicked" } },
		[2] = { { "StaminaPass_OfferToBuy_v2", 3, "PromptOpened" } },
		[3] = { { "StaminaPass_OfferToBuy_v2", 4, "OwnershipConfirmed" }, { "StaminaPass_Ownership_v2", 1, "OwnershipConfirmed" } },
	},
}
-- Update 4 funnels whose every step needs the one before it in the same session: a step
-- without it is neither sent nor remembered (as the ladder), so Creator Hub never counts an
-- earlier step that did not happen (a rejoin mid-race, a panel opened on another server).
local STRICT_SEQUENCE = {
	Engagement_Race = true,
	Onboarding_Race = true,
	Retention_Streak = true,
	Engagement_Titles = true,
	Community_Reward = true,
}

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
			if customEvents[funnel] then
				AnalyticsService:LogCustomEvent(player, funnel)
			else
				AnalyticsService:LogFunnelStepEvent(player, funnel, session, step, stepName)
			end
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
	local id = if funnel == "Engagement_Quests"
		then string.format("%d-quest-%d", player.UserId, math.floor(os.time() / 86400))
		elseif funnel == "Retention_Streak"
		then string.format("%d-streak-%d", player.UserId, math.floor(os.time() / 86400))
		else string.format("%d-%d-%d", player.UserId, os.time(), sessionCounter)
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
		if funnel == "Onboarding_FTUE" and step <= 3 and not newcomers[player] then
			return false
		end
		-- The ladder is a cohort of newcomers: a veteran's Rebirth 3/5/7 or World 2 unlock
		-- would count as every earlier step in Creator Hub and inflate it (v1 FTUE step 6 did).
		if funnel == "Onboarding_Ladder" and not newcomers[player] then
			return false
		end
		-- Update 4: the first-race funnel follows only runners who have never finished a race.
		-- 2026-09-25 (final fix): not before the data is in and RaceFinishes is projected either
		-- (read as 0 until then, which let veterans in).
		if funnel == "Onboarding_Race" and step == 1 and (player:GetAttribute("DataLoaded") ~= true
			or player:GetAttribute("RaceFinishes") == nil
			or (tonumber(player:GetAttribute("RaceFinishes")) or 0) > 0) then
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
		local function had(previous: number): boolean
			return logged[player][funnel .. "|" .. tostring(id or "") .. "|" .. tostring(previous)] == true
		end
		local sequenced = true
		if funnel == "Onboarding_FTUE" and step == 2 then sequenced = had(1)
		elseif funnel == "Onboarding_FTUE" and step == 3 then sequenced = had(2)
		elseif funnel == "Monetization_Revive" and step == 2 then sequenced = had(1)
		elseif funnel == "Engagement_SpinWheel" and (step == 2 or step == 3 or step == 5) then sequenced = had(1)
		elseif funnel == "Engagement_SpinWheel" and step == 4 then sequenced = had(3)
		elseif funnel == "Monetization_StarterPack" and step == 1 then sequenced = had(0)
		elseif funnel == "Monetization_StarterPack" and step == 2 then sequenced = had(1)
		elseif funnel == "Monetization_StarterPack" and step == 3 then sequenced = had(2)
		elseif funnel == "CoreLoop_Rebirths" and step == 2 then sequenced = had(1)
		-- Quest selection and completion are server-validated and may cross server
		-- sessions. Their stable UTC-day session ID lets Creator Hub join the steps.
		elseif funnel == "Engagement_AFK" and step == 3 then sequenced = had(2)
		elseif funnel == "Onboarding_Ladder" and step > 1 then
			-- A step skipped on this server (rebirths from a code, a rejoin) would otherwise
			-- be counted by Creator Hub as reached; the ladder stops there instead. A rung the
			-- gate leaves out (no ladderPrevious) cannot be logged at all.
			local previous = ladderPrevious[step]
			sequenced = previous ~= nil and had(previous)
			if not sequenced then
				-- Not marked as logged either, or the step after it would pass had().
				logged[player][key] = nil
				return false
			end
		elseif STRICT_SEQUENCE[funnel] and step > 1 then
			if not had(step - 1) then
				logged[player][key] = nil
				return false
			end
		elseif funnel == "Monetization_StaminaPass" and step >= 1 then
			sequenced = had(step - 1)
		end
		for _, route in routes[funnel] and routes[funnel][step] or {} do
			-- A spin pack receipt purchased from the shop is not a wheel-panel
			-- conversion unless this same wheel session opened the paid prompt.
			-- Ownership (Starter Pack, Stamina pass) is logged whatever the offer path was.
			if sequenced or (step == 3 and (route[1] == "StarterPack_Ownership_v2"
				or route[1] == "StaminaPass_Ownership_v2")) then
				send(player, route[1], id, route[2], route[3])
			end
		end
		return true
	end)
	return ok and sent == true
end

-- Logs the whitelisted custom event `name` (Update 4) for `player`, with an optional value
-- and custom fields (Enum.AnalyticsCustomFieldKeys keys). Same safety as a step: its own
-- thread, inside pcall; returns true when sent, false for an unknown name or player.
function FunnelAnalytics.Event(player: Player, name: string, value: number?, fields: { [any]: any }?): boolean
	local ok, sent = pcall(function()
		if type(name) ~= "string" or not customEvents[name] or not validPlayer(player) or not AnalyticsService then
			return false
		end
		local amount = tonumber(value) or 1
		if amount ~= amount or amount == math.huge or amount == -math.huge then
			amount = 1
		end
		local customFields = if type(fields) == "table" then fields else nil
		task.spawn(function()
			local logOk, err = pcall(function()
				AnalyticsService:LogCustomEvent(player, name, amount, customFields)
			end)
			if not logOk then
				warn("[FunnelAnalytics] event " .. name .. " was not logged: " .. tostring(err))
			end
		end)
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
	FunnelAnalytics.Step(player, "Onboarding_Ladder", 1)

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
