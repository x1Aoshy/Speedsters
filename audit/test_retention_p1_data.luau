-- audit/test_retention_p1_data.luau  (Update 4 p0_data, 2026-09-25; PLAN output/Update4/PLAN.md §7.1)
-- The data half of the P0 retention pass, on the real src modules (never audit/merged):
--   H3   a Speed tick never waits for a DataStore write, Recovering keeps its gains, a SetStat
--        written meanwhile drops them; ApplyVolatile changes the profile without a write;
--   M14  the Daily opens on a fixed 08:00 UTC day, 12-20 h after the last claim;
--   M15  one 30-day reward scale with Spin tickets and 2x potions;
--   M33  a quest finished before its day ended is paid exactly once afterwards.
--   lune run audit/test_retention_p1_data.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local task = require("@lune/task")

local ROOT = "src/common/"
local DATA = "../src/common/ServerScriptService/Services/Data/"
local passed = 0
local function pass(text)
	passed += 1
	print("PASS " .. text)
end
local function read(path)
	return (fs.readFile(path):gsub("\r\n", "\n"))
end
local function has(source, needle, message)
	assert(string.find(source, needle, 1, true), message)
end

----------------------------------------------------------------------
-- 0. Every changed source compiles
----------------------------------------------------------------------
local CHANGED = {
	ROOT .. "ServerScriptService/Services/Data/SessionActor.luau",
	ROOT .. "ServerScriptService/Services/Data/DataService.luau",
	ROOT .. "ServerScriptService/Services/Stats/StatsProjection.luau",
	ROOT .. "ReplicatedStorage/Shared/DailyRewardsData.luau",
	ROOT .. "ReplicatedStorage/Shared/DailyRewards.luau",
	ROOT .. "ServerScriptService/Social/DailyLoginSystem.server.luau",
	ROOT .. "StarterPlayer/StarterPlayerScripts/UI/UpdateLogsController.client.luau",
	ROOT .. "ReplicatedStorage/Shared/QuestCatalog.luau",
	ROOT .. "ReplicatedStorage/Shared/QuestPeriod.luau",
	ROOT .. "ServerScriptService/Social/QuestService.server.luau",
}
for _, path in CHANGED do
	local ok, err = pcall(luau.compile, read(path))
	assert(ok, "does not compile: " .. path .. "\n" .. tostring(err))
end
pass(#CHANGED .. " changed sources compile")

local Actor = require(DATA .. "SessionActor")
local Adapter = require(DATA .. "DataStoreAdapter")
local ProfileReducers = require(DATA .. "ProfileReducers")
local ProfileCodec = require(DATA .. "ProfileCodec")
local DataService = require(DATA .. "DataService")

-- A mock store whose UpdateAsync can be made slow (a real write parks ~0.3 s).
local function slowStore(initial)
	local inner = Adapter.CreateMock(initial)
	local store = { inner = inner, delay = 0, updates = 0 }
	function store:UpdateAsync(key, fn)
		self.updates += 1
		if self.delay > 0 then
			task.wait(self.delay)
		end
		return inner:UpdateAsync(key, fn)
	end
	function store:GetAsync(key)
		return inner:GetAsync(key)
	end
	return store
end

local now = 1000
local clock = { UnixNow = function() return now end, MonotonicNow = function() return os.clock() end }

local function openActor(store, id)
	local actor = Actor.new({ userId = 1, sessionId = id, storeAdapter = store, clock = clock })
	local opened = actor:Open()
	assert(opened.ok, "session opens")
	return actor, opened.value
end

local function waitFor(predicate, seconds, label)
	local deadline = os.clock() + seconds
	while not predicate() do
		assert(os.clock() < deadline, "timed out waiting: " .. label)
		task.wait(0.02)
	end
end

----------------------------------------------------------------------
-- 1. H3: a speed tick never waits behind a parked write
----------------------------------------------------------------------
do
	local store = slowStore({ Player_1 = { Version = 306, Wins = 0, Speed = 100, Rebirths = 0 } })
	local actor, handle = openActor(store, "H3a")
	store.delay = 0.3
	local commit = nil
	task.spawn(function()
		commit = actor:Commit(handle, { operationId = "wins5", fingerprint = "wins5",
			commands = { { kind = "GrantExact", stat = "Wins", amount = 5 } } })
	end)
	assert(commit == nil and actor.writeInFlight == true, "the Commit is parked inside UpdateAsync")
	local started = os.clock()
	local tick = actor:AccrueSpeed(handle, 10)
	local took = os.clock() - started
	assert(tick.ok == true, "the tick is accepted while the write is in flight")
	assert(took < 0.05, string.format("the tick must not wait for the write (took %.3f s)", took))
	waitFor(function() return commit ~= nil end, 2, "commit")
	assert(commit.kind == "Committed", "the Commit lands: " .. tostring(commit.kind))
	local profile = actor:Inspect(handle).value.profile
	assert(profile.Speed == 110 and profile.Wins == 5, ("the tick survives the snapshot: Speed %s Wins %s"):format(profile.Speed, profile.Wins))
	assert(profile.QuestState.Daily.Progress.speed == 10, "the tick's quest progress is replayed too")
	store.delay = 0
	assert(actor:Flush(handle).kind == "Saved")
	local saved = store.inner:GetData("Player_1")
	assert(saved.Speed == 110 and saved.Wins == 5, "the store holds the replayed tick")
	pass("H3: a tick during a parked 0.3 s write returns in " .. string.format("%.3f", took) .. " s; Speed 110 / Wins 5 kept and saved")

	-- Only the write yields: a tick while a load holds the lock answers NotReady at once.
	actor.mutationOwner = true
	local busy = actor:AccrueSpeed(handle, 10)
	actor.mutationOwner = nil
	assert(busy.ok == false and busy.error.code == "NotReady" and busy.error.retryable == true, "busy session: retryable NotReady, no wait")
	pass("H3: a tick never waits on the lock (NotReady when the holder is not writing)")
end

----------------------------------------------------------------------
-- 2. H3: Recovering keeps its gains; the next Flush stores everything
----------------------------------------------------------------------
do
	local store = slowStore({ Player_1 = { Version = 306, Wins = 0, Speed = 100, Rebirths = 0 } })
	local actor, handle = openActor(store, "H3b")
	store.inner:SetFailureMode("Player_1", "Down")
	local commit = actor:Commit(handle, { operationId = "wins1", fingerprint = "wins1",
		commands = { { kind = "GrantExact", stat = "Wins", amount = 1 } } })
	assert(commit.kind == "Pending" and actor.state == "Recovering", "a failed write leaves the session Recovering")
	assert(DataService.GetHandle ~= nil)
	local a = actor:AccrueSpeed(handle, 10)
	local b = actor:AccrueSpeed(handle, 10)
	assert(a.ok and b.ok, "Recovering accepts Speed ticks")
	assert(actor:Inspect(handle).value.profile.Speed == 120, "ticks land on the live profile")
	assert(#actor.accrualLog == 1 and actor.accrualLog[1].added == 20, "ticks of the same hour share one log entry")
	store.inner:SetFailureMode("Player_1", "None")
	local flushed = actor:Flush(handle)
	assert(flushed.kind == "Saved" and actor.state == "Ready", "the retry lands and the session is Ready again")
	local profile = actor:Inspect(handle).value.profile
	assert(profile.Speed == 120 and profile.Wins == 1, ("snapshot + replay: Speed %s Wins %s"):format(profile.Speed, profile.Wins))
	local saved = store.inner:GetData("Player_1")
	assert(saved.Speed == 120 and saved.Wins == 1, "the store holds the commit and both Recovering ticks")
	pass("H3: Recovering: Commit Pending, 2 ticks accepted, Flush stores Wins 1 + Speed 120")
end

----------------------------------------------------------------------
-- 3. H3: a SetStat written during a tick wins (its replay is dropped)
----------------------------------------------------------------------
do
	local store = slowStore({ Player_1 = { Version = 306, Wins = 0, Speed = 5000, Rebirths = 0 } })
	local actor, handle = openActor(store, "H3c")
	store.delay = 0.3
	local commit = nil
	task.spawn(function()
		commit = actor:Commit(handle, { operationId = "set1", fingerprint = "set1",
			commands = { { kind = "SetStat", stat = "Speed", amount = 1 } } })
	end)
	assert(actor:AccrueSpeed(handle, 10).ok, "the tick runs during the SetStat write")
	waitFor(function() return commit ~= nil end, 2, "SetStat commit")
	assert(commit.kind == "Committed")
	local profile = actor:Inspect(handle).value.profile
	assert(profile.Speed == 1, "SetStat Speed=1 leaves Speed 1, not " .. tostring(profile.Speed))
	assert(actor.speedCarry == 0, "the carry is reset with it")
	pass("H3: SetStat Speed=1 during a tick leaves Speed 1")
end

----------------------------------------------------------------------
-- 4. ApplyVolatile: in memory only, whitelist only
----------------------------------------------------------------------
do
	local store = slowStore({ Player_1 = { Version = 306, Wins = 0, Speed = 100, Rebirths = 0 } })
	local actor, handle = openActor(store, "VOL")
	-- A stub reducer for the whitelisted kinds (the U4 sections are other workstreams').
	local original = ProfileReducers.ApplyCommand
	ProfileReducers.ApplyCommand = function(profile, command, at)
		if command.kind == "U4.Titles.SetPref" or command.kind == "U4.Retention.Playtime" then
			profile.VolatileProbe = (profile.VolatileProbe or 0) + 1
			profile.VolatileLast = command.kind .. ":" .. tostring(command.pref or command.seconds)
			return { ok = true, value = true }
		end
		return original(profile, command, at)
	end
	local ok, err = pcall(function()
		local before = store.updates
		local revBefore = actor.saveCoordinator:GetCurrentRevision()
		local result = actor:ApplyVolatile(handle, { kind = "U4.Titles.SetPref", pref = "race_winner" })
		assert(result.ok == true, "a whitelisted kind is applied")
		local profile = actor:Inspect(handle).value.profile
		assert(profile.VolatileProbe == 1 and profile.VolatileLast == "U4.Titles.SetPref:race_winner", "the profile changed")
		assert(store.updates == before, "no UpdateAsync for a volatile change")
		assert(actor.saveCoordinator:GetCurrentRevision() > revBefore, "the revision advances, so the autosave carries it")
		for _, bad in { { kind = "GrantExact", stat = "Wins", amount = 1 }, { kind = "U4.Race.Record" }, { kind = 5 }, "x" } do
			local refused = actor:ApplyVolatile(handle, bad)
			assert(refused.ok == false and refused.error.code == "InvalidInput", "a non-volatile kind is refused")
		end
		assert(actor:Inspect(handle).value.profile.Wins == 0 and store.updates == before, "nothing was granted or written")
		-- Through the facade.
		DataService.Init({ storeAdapter = store, clock = clock })
		DataService.Start()
		local opened = DataService.Open(7)
		assert(opened.ok)
		local viaService = DataService.ApplyVolatile(opened.value, { kind = "U4.Retention.Playtime", seconds = 600 })
		assert(viaService.ok == true, "DataService.ApplyVolatile reaches the actor")
		assert(DataService.ApplyVolatile({ userId = 99, sessionId = "x", generation = 1 }, { kind = "U4.Titles.SetPref" }).error.code == "SessionLost")
		DataService.Destroy()
		-- Recovering: the volatile change is replayed onto the snapshot when it lands.
		store.inner:SetFailureMode("Player_1", "Down")
		assert(actor:Commit(handle, { operationId = "w", fingerprint = "w", commands = { { kind = "GrantExact", stat = "Wins", amount = 1 } } }).kind == "Pending")
		assert(actor:ApplyVolatile(handle, { kind = "U4.Retention.Playtime", seconds = 900 }).ok, "Recovering accepts volatile changes")
		assert(actor:ApplyVolatile(handle, { kind = "U4.Retention.Playtime", seconds = 1200 }).ok)
		local playtimeEntries = 0
		for _, entry in actor.accrualLog do
			if entry.command and entry.command.kind == "U4.Retention.Playtime" then
				playtimeEntries += 1
			end
		end
		assert(playtimeEntries == 1, "one log entry per volatile kind (the newest), got " .. playtimeEntries)
		store.inner:SetFailureMode("Player_1", "None")
		assert(actor:Flush(handle).kind == "Saved")
		local after = actor:Inspect(handle).value.profile
		assert(after.Wins == 1 and after.VolatileProbe == 2 and after.VolatileLast == "U4.Retention.Playtime:1200", "the volatile change survives the Recovering snapshot")
		-- A SetStat snapshot drops the Speed replay but keeps a volatile change made meanwhile.
		store.inner:SetFailureMode("Player_1", "Down")
		assert(actor:Commit(handle, { operationId = "s", fingerprint = "s", commands = { { kind = "SetStat", stat = "Speed", amount = 7 } } }).kind == "Pending")
		assert(actor:AccrueSpeed(handle, 10).ok and actor:ApplyVolatile(handle, { kind = "U4.Titles.SetPref", pref = "none" }).ok)
		store.inner:SetFailureMode("Player_1", "None")
		assert(actor:Flush(handle).kind == "Saved")
		local reset = actor:Inspect(handle).value.profile
		assert(reset.Speed == 7 and reset.VolatileLast == "U4.Titles.SetPref:none", "SetStat wins over the tick; the title choice is kept")
		assert(store.inner:GetData("Player_1").Speed == 7, "and that is what is stored")
	end)
	ProfileReducers.ApplyCommand = original
	assert(ok, err)
	pass("ApplyVolatile: profile changed with 0 UpdateAsync, non-volatile kinds refused, survives Recovering")
end

----------------------------------------------------------------------
-- 5. M14: ClaimWindow
----------------------------------------------------------------------
local DailyRewardsData = require("../src/common/ReplicatedStorage/Shared/DailyRewardsData")
do
	local W = DailyRewardsData.ClaimWindow
	local midnight = 1790553600 -- 2026-09-28 00:00 UTC
	local H = 3600
	local function wait(lastHour)
		local last = midnight + lastHour * H
		local can, remaining = W(last, last)
		assert(can == false, "just claimed: not claimable")
		return remaining
	end
	assert(wait(7) == 12 * H, "claimed 07:00 UTC -> 12 h (19:00)")
	assert(wait(20) == 12 * H, "claimed 20:00 UTC -> 12 h (08:00 next day)")
	assert(wait(12) == 20 * H, "claimed 12:00 UTC -> 20 h (the rolling cap)")
	assert(wait(8) == 20 * H, "claimed right at the reset -> 20 h")
	local can, remaining = W(0, midnight)
	assert(can == true and remaining == 0, "never claimed -> claimable")
	local seed = 7
	local function random()
		seed = seed * 48271 % 2147483647
		return seed / 2147483647
	end
	for _ = 1, 2000 do
		local last = midnight + math.floor(random() * 30 * 86400)
		local at = last + math.floor(random() * 30 * H)
		local canClaim, left = W(last, at)
		assert(left >= 0, "never negative")
		if canClaim then
			assert(left == 0)
			assert(at - last >= 12 * H, "never claimable before 12 h")
		else
			local opensAt = at + left
			assert(opensAt - last >= 12 * H and opensAt - last <= 20 * H, "the wait is 12-20 h, got " .. (opensAt - last) / H)
			assert(W(last, opensAt) == true, "claimable when the countdown ends")
			assert(W(last, opensAt - 1) == false, "not a second earlier")
		end
	end
	pass("M14: ClaimWindow 07:00 -> 12 h, 20:00 -> 12 h, 12:00 -> 20 h, never -> claimable; 2000 random pairs in [12 h, 20 h]")
end

----------------------------------------------------------------------
-- 6. M15: the 30-day table
----------------------------------------------------------------------
do
	local rewards = DailyRewardsData.Rewards
	assert(#rewards == 30 and DailyRewardsData.TotalDays == 30, "30 entries")
	local TYPES = { Speed = true, Wins = true, SpinTicket = true, PotionSpeed = true, PotionWins = true }
	local last = {}
	for index, reward in rewards do
		assert(reward.Day == index, "days in order")
		assert(TYPES[reward.Type], "known type on day " .. index .. ": " .. tostring(reward.Type))
		assert(type(reward.Amount) == "number" and reward.Amount > 0)
		if reward.Type == "Speed" or reward.Type == "Wins" then
			local previous = last[reward.Type]
			if previous then
				if reward.Type == "Speed" then
					assert(reward.Amount >= previous.Amount, "Speed never goes down (day " .. index .. ")")
				end
				-- "Day over day": the growth per day between two rewards of the same stat.
				local perDay = (reward.Amount / previous.Amount) ^ (1 / (index - previous.Day))
				assert(perDay <= 10, reward.Type .. " grows more than 10x a day before day " .. index)
			end
			last[reward.Type] = reward
		end
	end
	for _, day in { 7, 14, 21, 30 } do
		assert(rewards[day].Milestone == true and rewards[day].Featured == true, "milestone kept on day " .. day)
	end
	assert(rewards[2].Type == "SpinTicket" and rewards[12].Type == "SpinTicket" and rewards[26].Type == "SpinTicket")
	assert(rewards[5].Type == "PotionSpeed" and rewards[5].Amount == 15 and rewards[19].Type == "PotionWins" and rewards[19].Amount == 30)
	assert(rewards[30].Amount == 2.5e9)
	-- Texts and icons (DailyRewards reads its data module through a stub, as the UI tests do).
	-- The quests' reward art is found on first use (QuestCatalog may replicate after this module).
	local QuestCatalogStub = { RewardIcons = { SpinTicket = "rbxassetid://1", PotionSpeed = "rbxassetid://2", PotionWins = "rbxassetid://3" } }
	local catalogReplicated = false
	local catalogModule = { Name = "QuestCatalog" }
	local sharedFolder = {
		WaitForChild = function(self) return self end,
		FindFirstChild = function(_, name) return if name == "QuestCatalog" and catalogReplicated then catalogModule else nil end,
	}
	local DailyRewards = luau.load(read(ROOT .. "ReplicatedStorage/Shared/DailyRewards.luau"), { environment = setmetatable({
		game = { GetService = function() return {
			WaitForChild = function() return sharedFolder end,
			FindFirstChild = function(_, name) return if name == "Shared" then sharedFolder else nil end,
		} end },
		require = function(module) return if module == catalogModule then QuestCatalogStub else DailyRewardsData end,
	}, { __index = _G }) })()
	assert(DailyRewards.GetRewardIconImage(rewards[2]) == DailyRewardsData.SpeedIconImage, "before QuestCatalog is there: the Speed art")
	catalogReplicated = true
	assert(DailyRewards.GetRewardIconImage(rewards[2]) == "rbxassetid://1" and DailyRewards.GetRewardIconImage(rewards[19]) == "rbxassetid://3", "then the quests' art")
	assert(DailyRewards.GetRewardIconImage(rewards[3]) == DailyRewardsData.WinsIconImage)
	assert(DailyRewards.GetRewardText(rewards[2]) == "1 Spin" and DailyRewards.GetRewardText(rewards[12]) == "2 Spins")
	assert(DailyRewards.GetRewardText(rewards[5]) == "2x Speed 15m" and DailyRewards.GetRewardText(rewards[19]) == "2x Wins 30m")
	assert(DailyRewards.GetRewardText(rewards[1]) == "500 Speed" and DailyRewards.GetRewardText(rewards[30]) == "2.5B Speed")
	assert(DailyRewards.ClaimWindow == DailyRewardsData.ClaimWindow)
	pass("M15: 30 days, 5 types, Speed non-decreasing and <= 10x a day, milestones 7/14/21/30, texts '1 Spin' / '2x Speed 15m'")
end

----------------------------------------------------------------------
-- 7. Sources: Daily grants by type, auto-open gate, DataSaveRetrying, late quest claim
----------------------------------------------------------------------
do
	local daily = read(ROOT .. "ServerScriptService/Social/DailyLoginSystem.server.luau")
	has(daily, 'kind="GrantSpinTickets"', "Daily pays Spin tickets")
	has(daily, 'kind="GrantBuff"', "Daily pays potions")
	has(daily, "DailyRewards.ClaimWindow(", "Daily uses the fixed-day window")
	has(daily, '"DailyCanClaim"', "Daily publishes DailyCanClaim")
	has(daily, '"ArrivedByTeleport"', "Daily publishes ArrivedByTeleport")
	has(daily, "td.FromWorld ~= nil or td.AfkModeResume == true", "world change or AFK rejoin")
	local logs = read(ROOT .. "StarterPlayer/StarterPlayerScripts/UI/UpdateLogsController.client.luau")
	has(logs, "DailyCanClaim", "the auto-open reads DailyCanClaim")
	has(logs, "ArrivedByTeleport", "the auto-open reads ArrivedByTeleport")
	local _, gates = string.gsub(logs, "dailyWanted%(%)[^\n]*then\n%s*MenuEvents%.Get%(\"OpenDailyPanel\"%):Fire%(\"Open\"%)", "")
	local _, opens = string.gsub(logs, "MenuEvents%.Get%(\"OpenDailyPanel\"%):Fire%(\"Open\"%)", "")
	assert(gates == 3 and opens == 3, "all three Daily auto-opens are gated, found " .. gates .. " of " .. opens)
	local projection = read(ROOT .. "ServerScriptService/Services/Stats/StatsProjection.luau")
	has(projection, "DataSaveRetrying", "StatsProjection publishes DataSaveRetrying")
	has(projection, 'view.state == "Recovering")', "DataLoaded stays true in Recovering")
	local quests = read(ROOT .. "ServerScriptService/Social/QuestService.server.luau")
	has(quests, 'kind = "ClaimLateQuestPath"', "QuestService pays late quests")
	has(quests, "Yesterday's quest rewards were claimed for you!", "with a message")
	has(quests, "TimeLeft = Catalog.PeriodEnd(now) - now", "the panel counts down to the real day end")
	has(quests, '"quest-claim:" .. player.UserId .. ":" .. late.Period', "the late claim reuses claim()'s operation id")
	has(quests, "state.lateRetryAt and now >= state.lateRetryAt", "a Pending late claim is tried again")
	has(quests, "state.lateRetryAt = os.clock() + 2", "a late claim skipped by a running choose/claim is tried again")
	has(quests, 'Type = "Retention", Message = LATE_MESSAGE', "a late claim is told with a toast when the panel is closed")
	has(quests, 'type(result) == "table" and (result.kind == "Committed" or result.kind == "AlreadyCommitted") then\n\t\tFunnelAnalytics.Step(player, "Engagement_Quests", 4)\n\t\tsync(player, LATE_MESSAGE, true)', "a Pending late claim that landed on retry is still announced")
	pass("sources: Daily GrantSpinTickets/GrantBuff + DailyCanClaim/ArrivedByTeleport, 3 gated auto-opens, DataSaveRetrying, QuestService late claim")
end

----------------------------------------------------------------------
-- 8. M33: QuestPeriod
----------------------------------------------------------------------
local QuestPeriod = require("../src/common/ReplicatedStorage/Shared/QuestPeriod")
local QuestCatalog = require("../src/common/ReplicatedStorage/Shared/QuestCatalog")
local CUT = QuestPeriod.CUTOVER
do
	assert(CUT == 1790582400 and os.date("!%Y-%m-%d %H:%M", CUT) == "2026-09-28 08:00", "cutover is 2026-09-28 08:00 UTC")
	local previous = QuestPeriod.DailyPeriod(CUT - 48 * 3600)
	for t = CUT - 48 * 3600 + 3600, CUT + 48 * 3600, 3600 do
		local p = QuestPeriod.DailyPeriod(t)
		assert(p >= previous and p - previous <= 1, "monotonic, one step at a time at " .. t)
		previous = p
	end
	assert(QuestPeriod.DailyPeriod(CUT) == QuestPeriod.DailyPeriod(CUT - 1) + 1, "one step forward at the cutover")
	assert(QuestPeriod.DailyPeriod(CUT + 86400 - 1) == QuestPeriod.DailyPeriod(CUT), "after it, the day turns at 08:00 UTC")
	assert(QuestPeriod.DailyPeriod(CUT + 86400) == QuestPeriod.DailyPeriod(CUT) + 1)
	for t = CUT - 50 * 3600, CUT + 50 * 3600, 1234 do
		local finish = QuestPeriod.PeriodEnd(t)
		assert(finish > t and QuestPeriod.DailyPeriod(finish) > QuestPeriod.DailyPeriod(t), "PeriodEnd starts a later day")
		assert(QuestPeriod.DailyPeriod(finish - 1) == QuestPeriod.DailyPeriod(t), "PeriodEnd is the first such instant")
	end
	assert(QuestCatalog.PeriodOf == QuestPeriod.DailyPeriod and QuestCatalog.PeriodEnd == QuestPeriod.PeriodEnd, "QuestCatalog uses QuestPeriod")
	assert(ProfileCodec.QuestPeriod == QuestPeriod and ProfileReducers.DailyQuestPeriod == QuestPeriod.DailyPeriod, "the codec and reducers load it")
	-- SanitizeDestiny: the old cleaning plus Complete.
	assert(QuestPeriod.SanitizeDestiny("x") == nil and QuestPeriod.SanitizeDestiny(nil) == nil)
	local clean = QuestPeriod.SanitizeDestiny({ Period = 0 / 0, Choice = 9, Targets = { stages = -5, jumps = 3 }, Baseline = { speed = "x" },
		Claimed = "yes", Complete = true, ClaimedChoices = { ["1"] = true, [2] = true, ["7"] = true } })
	assert(clean.Period == 0 and clean.Choice == 3 and clean.Targets.stages == 0 and clean.Targets.jumps == nil and clean.Baseline.speed == nil)
	assert(clean.Claimed == false and clean.Complete == true and clean.ClaimedChoices["1"] and clean.ClaimedChoices["2"] and not clean.ClaimedChoices["7"])
	pass("M33: DailyPeriod monotonic across the cutover +-48 h, one step at 08:00 UTC; PeriodEnd exact; QuestCatalog/codec/reducers share it")
end

do
	local apply = ProfileReducers.ApplyCommand
	local t1 = CUT + 3 * 3600 -- a day after the cutover
	local P = QuestPeriod.DailyPeriod(t1)
	local tomorrow = QuestPeriod.PeriodEnd(t1) + 60
	assert(QuestPeriod.DailyPeriod(tomorrow) == P + 1)
	local function fresh(choice, targets, progress)
		local profile = ProfileCodec.CreateDefault()
		assert(apply(profile, { kind = "ChooseQuestPath", period = P, choice = choice, targets = targets }, t1).ok, "choose")
		for metric, amount in progress do
			assert(apply(profile, { kind = "QuestProgress", metric = metric, amount = amount }, t1 + 60).ok)
		end
		return profile
	end
	local function claimLate(profile, period, at)
		return apply(profile, { kind = "ClaimLateQuestPath", period = period or P }, at or tomorrow)
	end

	-- Finished yesterday; the day rolls with the next tick (FreezeCompletion), then paid once.
	local done = fresh(1, { stages = 10 }, { stages = 10 })
	assert(claimLate(done, P, t1 + 120).ok == false, "not late while its day is still running")
	ProfileReducers.AddQuestProgress(done, "speed", 5, tomorrow)
	assert(done.QuestState.Destiny.Complete == true, "the roll froze the quest as Complete")
	assert(QuestPeriod.FindLate(done.QuestState, tomorrow) ~= nil, "QuestService would find it")
	assert(claimLate(done).ok == true, "paid")
	assert(done.QuestState.Destiny.Claimed == true and done.QuestState.Destiny.ClaimedChoices["1"] == true)
	assert(claimLate(done).ok == false, "a second late claim is rejected")
	assert(QuestPeriod.FindLate(done.QuestState, tomorrow) == nil)

	-- Not finished: rejected, nothing found.
	local half = fresh(2, { stages = 10 }, { stages = 5 })
	ProfileReducers.AddQuestProgress(half, "speed", 5, tomorrow)
	assert(half.QuestState.Destiny.Complete ~= true and QuestPeriod.FindLate(half.QuestState, tomorrow) == nil)
	assert(claimLate(half).ok == false, "an unfinished quest is rejected")

	-- The bucket has not rolled yet (first thing after rejoining): judged live, paid.
	local offline = fresh(3, { stages = 10, playtime = 600 }, { stages = 12, playtime = 600 })
	assert(offline.QuestState.Daily.Period == P, "nothing rolled the day yet")
	assert(QuestPeriod.FindLate(offline.QuestState, tomorrow) ~= nil, "found live against the old bucket")
	assert(claimLate(offline).ok == true and offline.QuestState.Daily.Period == P + 1, "paid, and the day rolled")

	-- LateDestiny survives a new choice, and is paid once after it.
	local late = fresh(1, { stages = 10 }, { stages = 10 })
	assert(apply(late, { kind = "ChooseQuestPath", period = P + 1, choice = 2, targets = { wins = 2 } }, tomorrow).ok, "tomorrow's choice")
	assert(late.QuestState.LateDestiny and late.QuestState.LateDestiny.Period == P and late.QuestState.LateDestiny.Complete == true, "yesterday's kept as LateDestiny")
	assert(late.QuestState.Destiny.Period == P + 1 and late.QuestState.Destiny.Choice == 2)
	local encoded = ProfileCodec.Encode(late)
	local decoded = ProfileCodec.Decode(encoded)
	assert(decoded.ok and decoded.value.QuestState.LateDestiny.Period == P, "LateDestiny survives a save and a rejoin")
	late = decoded.value
	assert(QuestPeriod.FindLate(late.QuestState, tomorrow).Period == P)
	assert(claimLate(late).ok == true and late.QuestState.LateDestiny == nil, "paid from LateDestiny")
	assert(late.QuestState.Destiny.Claimed == false and late.QuestState.Destiny.Period == P + 1, "today's quest untouched")
	assert(claimLate(late).ok == false, "and never twice")
	-- An unfinished quest is not kept.
	local nope = fresh(1, { stages = 10 }, { stages = 3 })
	assert(apply(nope, { kind = "ChooseQuestPath", period = P + 1, choice = 2, targets = { wins = 2 } }, tomorrow).ok)
	assert(nope.QuestState.LateDestiny == nil, "an unfinished quest is not kept")
	-- Bad input.
	for _, bad in { {}, { period = "x" }, { period = P + 1 }, { period = 0 / 0 }, { period = P + 0.5 } } do
		assert(apply(ProfileCodec.CreateDefault(), { kind = "ClaimLateQuestPath", period = bad.period }, tomorrow).ok == false)
	end
	pass("M33: FreezeCompletion at the roll, ClaimLate pays a finished quest once, rejects unfinished/current/bad, live judge before the roll, LateDestiny survives a new choice and a save")
end

-- Exactly once through a real session: the same operation id as claim() and the reducer's guard.
do
	local t1 = CUT + 3 * 3600
	local P = QuestPeriod.DailyPeriod(t1)
	now = t1
	local store = slowStore({ Player_1 = { Version = 306, Wins = 0, Speed = 100, Rebirths = 0 } })
	local actor, handle = openActor(store, "M33")
	local function commit(id, commands)
		return actor:Commit(handle, { operationId = id, fingerprint = id, commands = commands })
	end
	assert(commit("choose", { { kind = "ChooseQuestPath", period = P, choice = 1, targets = { stages = 4 } } }).kind == "Committed")
	assert(commit("work", { { kind = "QuestProgress", metric = "stages", amount = 4 } }).kind == "Committed")
	now = QuestPeriod.PeriodEnd(t1) + 5
	assert(actor:AccrueSpeed(handle, 3).ok, "the first tick of the new day rolls the bucket")
	local late = QuestPeriod.FindLate(actor:Inspect(handle).value.profile.QuestState, now)
	assert(late and late.Period == P and late.Choice == 1)
	local id = "quest-claim:1:" .. P .. ":1"
	local pay = { { kind = "ClaimLateQuestPath", period = P }, { kind = "GrantExact", stat = "Wins", amount = 100 } }
	assert(commit(id, pay).kind == "Committed", "paid")
	assert(commit(id, pay).kind == "AlreadyCommitted", "the same claim again dedupes")
	assert(commit("other-id", pay).kind == "Rejected", "any other attempt is refused by the reducer")
	assert(actor:Inspect(handle).value.profile.Wins == 100, "paid exactly once")
	pass("M33: a finished quest is paid exactly once through a session after the day rolls")
end

print(string.format("\nALL %d CHECKS PASSED (test_retention_p1_data)", passed))
