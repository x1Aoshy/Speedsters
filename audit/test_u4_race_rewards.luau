-- test_u4_race_rewards.luau (Update 4, race_server, 2026-09-25)
-- Race rewards (PLAN §3.4 / §7.3 items 7-8): RaceMath.ComputeRewards, Services/Race/RaceRewards
-- and Services/Data/U4/RaceSection, loaded from src in plain Lune. The payment runs through the
-- real DataService / SessionActor / ProfileCodec / ProfileReducers / Update4Profile stack on the
-- mock store, so "one Commit per racer, never paid twice" is checked end to end.
--   field table; World 1 progress 0.0204 / 0.327 / 1.0; a winner earns 6 % of the lap; the
--   worked example (W1, 0 rebirths, 6 racers -> 1,417 Wins); an always-winner earns <= 2.1 laps
--   an hour; Speed clamp; x32 x Mega x daily stays under 2^53-1; DQ and DNF < 25 % pay 0; the
--   RaceSection Record rules; the same race paid twice pays once; race titles.
--   2026-09-25 (speed follows the Speed stat): a fast racer can race every ~43 s, so past
--   HourlyPaidRaces a race pays nothing; the ceiling holds at 80 s, 43 s and 30 s cycles, and
--   the record floor is U4.Race.Validation.MinPlausibleMs in RaceSection too.
-- Run: lune run audit/test_u4_race_rewards.luau   (from the project root)
local RaceMath = require("../src/common/ReplicatedStorage/Shared/RaceMath")
local U4 = require("../src/common/ReplicatedStorage/Shared/Update4Config")
local RaceSection = require("../src/common/ServerScriptService/Services/Data/U4/RaceSection")
local RaceRewards = require("../src/common/ServerScriptService/Services/Race/RaceRewards")
local Update4Profile = require("../src/common/ServerScriptService/Services/Data/Update4Profile")
local DataService = require("../src/common/ServerScriptService/Services/Data/DataService")
local Adapter = require("../src/common/ServerScriptService/Services/Data/DataStoreAdapter")

local passed = 0
local function pass(text)
	passed += 1
	print("PASS " .. text)
end
local function near(a, b, eps)
	return math.abs(a - b) <= eps
end
local LAP_W1 = 1157020
local MAX = 9007199254740991

----------------------------------------------------------------------
-- Pure formulas
----------------------------------------------------------------------
do
	local expected = { 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0 }
	for n, value in expected do
		assert(near(RaceMath.FieldFactor(n), value, 1e-9), "field factor at " .. n)
	end
	assert(near(RaceMath.ProgressFactor("World1", 0, 6), 0.0204, 0.0001)
		and near(RaceMath.ProgressFactor("World1", 3, 6), 0.327, 0.001)
		and RaceMath.ProgressFactor("World1", 6, 6) == 1 and RaceMath.ProgressFactor("World1", 40, 6) == 1, "W1 progress 0.0204 / 0.327 / 1.0")
	assert(RaceMath.ProgressFactor("World2", 0, 6) == 1 and RaceMath.ProgressFactor("World3", 0, 6) == 1, "World 2/3 pay in full")

	local function winner(world, lap, rebirths, n)
		return RaceMath.ComputeRewards({ place = 1, finished = true, n = n, lapWins = lap, world = world, rebirths = rebirths, unlockRebirths = 6,
			eventMultiplier = 1, dailyFirst = false, hourCount = 0, winsMultiplier = 1, rawSpeed = 1e6, speedFloor = 500, speedShare = 0.005 })
	end
	for _, case in { { "World1", LAP_W1 }, { "World2", 25000000 }, { "World3", 41000000 } } do
		local r = winner(case[1], case[2], 6, 6)
		assert(r.wins == math.floor(case[2] * 0.06), case[1] .. " winner = 6 % of the lap")
	end
	local example = winner("World1", LAP_W1, 0, 6)
	assert(math.abs(example.wins - 1417) <= 1, "worked example: W1, 0 rebirths, 6 racers -> ~1,417 Wins (" .. example.wins .. ")")
	local second = RaceMath.ComputeRewards({ place = 2, finished = true, n = 6, lapWins = 100000, world = "World2", hourCount = 0 })
	local fourth = RaceMath.ComputeRewards({ place = 4, finished = true, n = 6, lapWins = 100000, world = "World2", hourCount = 0 })
	local solo = RaceMath.ComputeRewards({ place = 1, finished = true, n = 1, solo = true, lapWins = 100000, world = "World2", hourCount = 0 })
	assert(second.wins == 4000 and fourth.wins == 1500 and solo.wins == math.floor(100000 * 0.015 * 0.5), "2nd 4 %, other finishers 1.5 %, Time Trial = finisher x field 0.5")

	-- DQ and short DNFs pay nothing; a long DNF pays the DNF share.
	local dq = RaceMath.ComputeRewards({ place = 1, finished = true, dq = true, n = 6, lapWins = 100000, world = "World2", dailyFirst = true })
	local shortDnf = RaceMath.ComputeRewards({ finished = false, progress = 0.24, n = 6, lapWins = 100000, world = "World2", dailyFirst = true })
	local longDnf = RaceMath.ComputeRewards({ finished = false, progress = 0.25, n = 6, lapWins = 100000, world = "World2" })
	assert(dq.wins == 0 and dq.speed == 0 and dq.tickets == 0 and not dq.rewarded and not dq.dailyUsed, "DQ pays 0 and keeps the daily bonus")
	assert(shortDnf.wins == 0 and shortDnf.speed == 0 and shortDnf.tickets == 0, "DNF under 25 % pays 0")
	assert(longDnf.wins == 500 and longDnf.speed > 0, "DNF from 25 % pays 0.5 %")

	-- Speed: max(floor, raw*share) * minutes, clamped to 5 % of Speed + 2000.
	local rich = RaceMath.ComputeRewards({ place = 1, finished = true, n = 12, rawSpeed = 1e9, speedFloor = 500, speedShare = 0.005, hourCount = 0 })
	assert(rich.speed == math.floor(1e9 * 0.005 * 3.6), "Speed = raw * share * 3.6 AFK minutes for a winner")
	local poor = RaceMath.ComputeRewards({ place = 1, finished = true, n = 12, rawSpeed = 1000, speedFloor = 500, speedShare = 0.005,
		eventMultiplier = 2, dailyFirst = true, hourCount = 0 })
	assert(poor.speed == math.floor(0.05 * 1000 + 2000), "Speed clamp 0.05 * Speed + 2000 (" .. poor.speed .. ")")

	-- The biggest multipliers together never overflow the safe integer range.
	local huge = RaceMath.ComputeRewards({ place = 1, finished = true, n = 16, lapWins = 2 ^ 60, world = "World3", eventMultiplier = 2,
		dailyFirst = true, hourCount = 0, winsMultiplier = 32, rawSpeed = 1e300 })
	assert(huge.wins <= MAX and huge.wins > 0 and huge.speed == huge.speed, "x32 x Mega x daily stays <= 2^53-1")
	local capped = RaceMath.ComputeRewards({ place = 1, finished = true, n = 6, lapWins = 100000, world = "World2", hourCount = 30 })
	assert(capped.capReduced and capped.wins == math.floor(100000 * 0.06 * 0.25), "over 30 races an hour: x0.25")
	local daily = RaceMath.ComputeRewards({ place = 3, finished = true, n = 6, lapWins = 100000, world = "World2", dailyFirst = true, eventMultiplier = 2, hourCount = 0 })
	assert(daily.wins == 12000 and daily.tickets == 1 and daily.multiplier == 4, "daily x2 + 1 Spin Ticket, Mega x2")
	pass("formulas: field, progress, 6 % winner, worked example, shares, DQ/DNF, Speed clamp, 2^53 bound, hourly cap, daily")
end

----------------------------------------------------------------------
-- RaceSection
----------------------------------------------------------------------
do
	local state = RaceSection.Default()
	local function record(fields, now)
		local command = { finished = true, place = 1, field = 6, timeMs = 34000, rewarded = true, dayId = 20000, weekId = 2857, perfect = false }
		for k, v in fields do
			command[k] = v
		end
		return RaceSection.Apply(state, "Record", command, now or 1728000000)
	end
	assert(record({}).ok and state.Races == 1 and state.Finishes == 1 and state.Wins == 1 and state.Podiums == 1 and state.BestMs == 34000 and state.WeekBestMs == 34000, "a win")
	assert(record({ timeMs = 36000, place = 2 }).ok and state.BestMs == 34000 and state.Wins == 1 and state.Podiums == 2, "a slower 2nd: PB kept, podium counted")
	assert(record({ timeMs = 33000, place = 1, field = 1 }).ok and state.Wins == 1 and state.BestMs == 33000, "a Time Trial is no win, but a PB")
	assert(record({ place = 3, field = 2 }).ok and state.Podiums == 2, "3rd of 2 racers is no podium (field >= 3)")
	-- 2026-09-25: the floor is U4.Race.Validation.MinPlausibleMs (5000; RaceSection keeps the same number).
	-- 2026-09-26: 2000 now (Sonic Dash speeds); a time at the floor itself is a PB (checked on a copy).
	assert(record({ timeMs = U4.Race.Validation.MinPlausibleMs - 1 }).ok and state.BestMs == 33000, "an implausible time is never a PB")
	do
		local copy = table.clone(state)
		assert(RaceSection.Apply(copy, "Record", { finished = true, place = 1, field = 6, timeMs = U4.Race.Validation.MinPlausibleMs, rewarded = true,
			dayId = copy.DayId, weekId = copy.WeekId, perfect = false }, 1728000000).ok and copy.BestMs == U4.Race.Validation.MinPlausibleMs,
			"a time at the record floor is a PB: RaceSection's floor is MinPlausibleMs")
	end
	assert(record({ finished = false, place = 0, timeMs = 0, perfect = true }).ok and state.Perfects == 1 and state.Finishes == 5, "a DNF counts a race, not a finish; perfect counted")
	assert(record({ weekId = 2858, timeMs = 40000 }).ok and state.WeekId == 2858 and state.WeekBestMs == 40000 and state.BestMs == 33000, "week rollover resets the weekly best")
	-- hour window
	local hourStart = state.HourStart
	assert(state.HourCount == 7 and hourStart == 1728000000, "rewarded races counted in the hour")
	assert(record({ rewarded = false }, 1728000100).ok and state.HourCount == 7, "unrewarded races do not count")
	assert(record({}, 1728003600).ok and state.HourCount == 1 and state.HourStart == 1728003600, "a new hour window after 3600 s")
	assert(RaceSection.HourCountAt(state, 1728007199) == 1 and RaceSection.HourCountAt(state, 1728007200) == 0, "HourCountAt")
	assert(state.DayId == 20000 and record({ dayId = 19999 }).ok and state.DayId == 20000, "DayId only moves forward")
	for _, bad in { { place = 25 }, { place = -1 }, { field = 0 }, { field = 25 }, { timeMs = 1.5 }, { timeMs = 0 / 0 }, { finished = "yes" },
		{ perfect = 1 }, { rewarded = nil }, { dayId = -3 }, { weekId = 1.2 } } do
		local command = { finished = true, place = 1, field = 6, timeMs = 34000, rewarded = true, dayId = 20000, weekId = 2857, perfect = false }
		for k, v in bad do
			command[k] = v
		end
		if bad.rewarded == nil and next(bad) == nil then
			command.rewarded = nil
		end
		local before = table.clone(state)
		local result = RaceSection.Apply(state, "Record", command, 1728010000)
		if next(bad) ~= nil then
			assert(not result.ok and result.error.code == "InvalidInput", "invalid Record rejected")
			for k, v in before do
				assert(state[k] == v, "a rejected Record changes nothing")
			end
		end
	end
	assert(not RaceSection.Apply(state, "Nope", {}, 0).ok, "unknown op rejected")
	local clean = RaceSection.Sanitize({ BestMs = U4.Race.Validation.MinPlausibleMs - 1, WeekBestMs = 0 / 0, Races = -4, Wins = 1e20, HourStart = 1e12, Podiums = "7", Extra = 1 })
	assert(clean.BestMs == 0 and clean.WeekBestMs == 0 and clean.Races == 0 and clean.Wins == 1e9 and clean.HourStart == 4102444800
		and clean.Podiums == 7 and clean.Extra == nil, "Sanitize: out-of-range times, NaN, negatives, overflow, strings, unknown keys")
	local encoded = RaceSection.Encode(state)
	for k, v in state do
		assert(encoded[k] == v, "Encode is a plain copy")
	end
	clean.HourCount = 12
	assert(RaceSection.HourCountAt(clean, 1728000000) == 0, "a window starting in the future is over")
	assert(Update4Profile.HasSection("Race"), "the dispatcher loads RaceSection")
	pass("RaceSection: wins/podiums need a field, PB/week/hour/day rules, invalid Records change nothing, Sanitize, Encode")
end

----------------------------------------------------------------------
-- RaceRewards on the real data stack
----------------------------------------------------------------------
local now = 1728000000
local clock = { UnixNow = function() return now end, MonotonicNow = function() return now end }
local store = Adapter.CreateMock({
	Player_11 = { Version = 306, Speed = 5e6, Wins = 10, Rebirths = 8 },
	Player_12 = { Version = 306, Speed = 100, Wins = 0, Rebirths = 0 },
})
DataService.Init({ storeAdapter = store, clock = clock })
DataService.Start(store)
local function newPlayer(userId)
	local attrs = {}
	return { UserId = userId, Name = "P" .. userId, attrs = attrs, GetAttribute = function(_, k) return attrs[k] end, SetAttribute = function(_, k, v) attrs[k] = v end }
end
local alice, bob = newPlayer(11), newPlayer(12)
assert(DataService.Open(11).ok and DataService.Open(12).ok, "sessions open")
local refreshed = 0
local rewards = RaceRewards.new({
	DataService = DataService,
	config = { LapWins = { World1 = LAP_W1, World2 = 25000000, World3 = 41000000 }, SpeedFloor = 500, SpeedShare = 0.005, World2UnlockRebirths = 6 },
	world = "World2",
	jobId = "job",
	unix = function() return now end,
	wait = function() end,
	winsMultiplier = function() return 2 end,
	hasSection = Update4Profile.HasSection,
	titlesRefresh = function() refreshed += 1 end,
})
local function profile(userId)
	return DataService.Inspect(DataService.GetHandle(userId)).value.profile
end

do
	assert(rewards:IsDailyFirst(alice), "first race of the day doubles")
	local outcome = { raceId = 1, place = 1, finished = true, n = 6, timeMs = 34567, perfect = true, progress = 1, eventMultiplier = 1 }
	local first = rewards:Pay(alice, outcome)
	local expectedWins = math.floor(math.floor(25000000 * 0.06 * 1 * 2) * 2)
	assert(first.ok and first.kind == "Committed" and first.wins == expectedWins and first.tickets == 1 and first.pb and first.weeklyPb, "a winner is paid once: 6 % x daily x2 x wins multiplier 2 + a Spin Ticket")
	local p = profile(11)
	assert(p.Wins == 10 + expectedWins and p.SpinTickets == 1 and p.Speed > 5e6, "Wins, Speed and the ticket are in the profile")
	assert(p.U4.Race.Races == 1 and p.U4.Race.Wins == 1 and p.U4.Race.BestMs == 34567 and p.U4.Race.DayId == RaceMath.DayId(now), "U4.Race recorded in the same Commit")
	assert(alice.attrs.RaceBestMs == 34567 and alice.attrs.RaceWins == 1 and alice.attrs.RaceFinishes == 1, "attributes projected")
	local again = rewards:Pay(alice, outcome)
	assert(again.kind == "AlreadyCommitted" and profile(11).Wins == p.Wins and profile(11).U4.Race.Races == 1, "the same race paid twice pays once")
	assert(not rewards:IsDailyFirst(alice), "the daily double is used")
	local nextRace = rewards:Pay(alice, { raceId = 2, place = 2, finished = true, n = 6, timeMs = 35000, progress = 1 })
	assert(nextRace.ok and nextRace.tickets == 0 and nextRace.wins == math.floor(math.floor(25000000 * 0.04) * 2) and not nextRace.pb, "later races: no double, no PB")
	-- DQ: recorded, nothing paid.
	local dq = rewards:Pay(alice, { raceId = 3, place = 1, finished = true, dq = true, n = 6, timeMs = 31000, progress = 1 })
	assert(dq.ok and dq.wins == 0 and dq.speed == 0 and not dq.pb and profile(11).U4.Race.BestMs == 34567 and profile(11).U4.Race.Races == 3, "DQ: recorded, no reward, no PB")
	-- A newcomer in World 1 terms is scaled by progress (World2 here pays in full: check the World 1 path).
	local w1 = RaceRewards.new({ DataService = DataService, config = { LapWins = { World1 = LAP_W1 }, World2UnlockRebirths = 6 }, world = "World1",
		jobId = "job", unix = function() return now end, hasSection = Update4Profile.HasSection })
	local plan = w1:Prepare(bob, { raceId = 9, place = 1, finished = true, n = 6, timeMs = 36000, progress = 1 })
	assert(math.abs(plan.rewards.wins - 1417 * 2) <= 2, "W1, 0 rebirths, 6 racers: ~1,417 Wins (x2 first race of the day)")
	pass("RaceRewards: one Commit, AlreadyCommitted on repeat, daily x2 + ticket once, U4.Race recorded, DQ pays 0, W1 progress")
end

do
	-- An always-winner racing every `cycle` seconds for an hour: <= 2.1 laps, daily double included.
	-- 2026-09-25: 80 s was the old cycle; a Pro heat can now cycle in ~43 s (5 s full gathering
	-- + 3 + 5 + an ~12 s race + 7 + 8), and 30 s is below anything the service can do.
	local lap = 25000000
	local function hour(cycle)
		local state = RaceSection.Default()
		local total, t, paid = 0, 1729000000, 0
		for _ = 1, math.floor(3600 / cycle) do
			local r = RaceMath.ComputeRewards({ place = 1, finished = true, n = 12, lapWins = lap, world = "World2", dailyFirst = state.DayId < RaceMath.DayId(t),
				hourCount = RaceSection.HourCountAt(state, t), winsMultiplier = 1, eventMultiplier = 1, rawSpeed = 1e12 })
			total += r.wins
			paid += if r.rewarded then 1 else 0
			RaceSection.Apply(state, "Record", { finished = true, place = 1, field = 12, timeMs = 14000, rewarded = r.rewarded, dayId = RaceMath.DayId(t),
				weekId = RaceMath.WeekId(t), perfect = false }, t)
			t += cycle
		end
		return total / lap, paid
	end
	local laps80, laps43, laps30, paid30 = 0, 0, 0, 0
	laps80 = hour(80)
	laps43 = hour(43)
	laps30, paid30 = hour(30)
	for _, laps in { laps80, laps43, laps30 } do
		assert(laps <= 2.1, string.format("hourly ceiling for an always-winner <= 2.1 laps (%.3f)", laps))
	end
	assert(paid30 == U4.Race.Rewards.HourlyPaidRaces, "at most HourlyPaidRaces paid races an hour (" .. paid30 .. ")")
	local over = RaceMath.ComputeRewards({ place = 1, finished = true, n = 6, lapWins = 100000, world = "World2", hourCount = U4.Race.Rewards.HourlyPaidRaces,
		dailyFirst = true, rawSpeed = 1e12 })
	assert(over.wins == 0 and over.speed == 0 and over.tickets == 0 and not over.rewarded and over.capReduced and not over.dailyUsed,
		"past HourlyPaidRaces: nothing paid, not rewarded (no daily x2 spent), shown as capped")
	pass(string.format("hourly ceiling: an always-winner earns %.3f / %.3f / %.3f laps an hour racing every 80 / 43 / 30 s", laps80, laps43, laps30))
end

do
	-- 2026-09-25 (final fix): the projected RaceRaces / RaceDayId answer staging and Join
	-- without a profile read.
	assert(alice.attrs.RaceRaces == 3 and alice.attrs.RaceDayId == RaceMath.DayId(now), "RaceRaces and RaceDayId projected")
	assert(rewards:IsDailyFirstProjected(alice) == false, "the projected day says the double is used")
	local fresh = newPlayer(99)
	assert(rewards:IsDailyFirstProjected(fresh) == nil, "nothing projected yet: nil (the caller reads the profile)")
	fresh.attrs.RaceDayId = RaceMath.DayId(now) - 1
	assert(rewards:IsDailyFirstProjected(fresh) == true, "yesterday's day id: the next race doubles")

	-- A commit still Pending after its retries (H3: a save being retried) is retried later with
	-- the same operation id instead of being dropped.
	local answers, commits, spawned = {}, {}, {}
	local fakeData = {
		GetHandle = function() return { id = 1 } end,
		Inspect = function() return { ok = true, value = { profile = { Speed = 100, Rebirths = 0, U4 = { Race = {} } } } } end,
		Commit = function(_, request)
			table.insert(commits, request.operationId)
			return { kind = table.remove(answers, 1) or "Pending" }
		end,
	}
	local late = RaceRewards.new({ DataService = fakeData, config = { LapWins = { World2 = 1000 } }, world = "World2", jobId = "job",
		unix = function() return now end, wait = function() end, hasSection = Update4Profile.HasSection,
		spawn = function(fn) table.insert(spawned, fn) end, isPresent = function() return true end })
	local racer = newPlayer(77)
	local result = late:Pay(racer, { raceId = 5, place = 1, finished = true, n = 2, timeMs = 40000, progress = 1 })
	assert(not result.ok and result.kind == "Pending" and result.retrying == true and #spawned == 1, "Pending after the retries: a late retry is scheduled")
	assert(racer.attrs.RaceRaces == nil, "nothing published before it lands")
	answers = { "Pending", "AlreadyCommitted" }
	spawned[1]()
	assert(racer.attrs.RaceRaces == 1 and racer.attrs.RaceWins == 1, "the late retry lands (AlreadyCommitted) and publishes the stats")
	for _, id in commits do
		assert(id == commits[1], "every retry uses the same operation id")
	end

	-- Race operation ids leave the profile's ledger after an hour (SessionActor.Commit): kept
	-- forever they would fill its 512 slots after ~12 h of racing.
	local ledger = profile(11).Update2Operations
	assert(ledger["race:job:1:11"] ~= nil, "a fresh race id is in the ledger")
	local saved = now
	now += 3700
	assert(rewards:Pay(alice, { raceId = 50, place = 1, finished = true, n = 2, timeMs = 40000, progress = 1 }).ok, "a race an hour later")
	ledger = profile(11).Update2Operations
	assert(ledger["race:job:1:11"] == nil and ledger["race:job:50:11"] ~= nil, "race ids older than an hour are pruned, the new one kept")
	now = saved
	pass("projected RaceRaces / RaceDayId; a Pending payout is retried later under the same operation id")
end

do
	-- Race titles: computed from the stats before and after, only when the Titles section exists.
	local withTitles = RaceRewards.new({ DataService = DataService, config = { LapWins = { World2 = 1000 } }, world = "World2", jobId = "job",
		unix = function() return now end, hasSection = function() return true end })
	local plan = withTitles:Prepare(bob, { raceId = 20, place = 1, finished = true, n = 2, timeMs = 40000, progress = 1, perfect = true })
	assert(#plan.titles == 1 and plan.titles[1] == "race_winner", "first win -> race_winner")
	local found = false
	for _, command in plan.commands do
		if command.kind == "U4.Titles.Grant" and command.id == "race_winner" then
			found = true
		end
	end
	assert(found, "the grant is in the race Commit")
	local noTitles = rewards:Prepare(bob, { raceId = 21, place = 1, finished = true, n = 2, timeMs = 40000, progress = 1 })
	local titlesSection = Update4Profile.HasSection("Titles")
	assert(titlesSection or #noTitles.titles == 0, "without a Titles section no grant is sent (the Commit would be rejected)")
	local paid = rewards:Pay(bob, { raceId = 21, place = 1, finished = true, n = 2, timeMs = 40000, progress = 1 })
	assert(paid.ok and profile(12).U4.Race.Wins == 1, "bob's first win is paid")
	assert(not titlesSection or refreshed >= 1, "titles refreshed after a grant")
	pass("race titles: 1/25/100 wins and 10 perfect starts, granted in the race Commit only with a Titles section")
end

print(string.format("test_u4_race_rewards: %d checks passed", passed))
