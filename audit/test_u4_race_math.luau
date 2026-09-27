-- test_u4_race_math.luau (Update 4, race_server, 2026-09-25)
-- Shared/RaceMath (speed, stamina, days, rewards helpers) and Shared/RaceTrack (geometry) are
-- pure: this loads the real src files in plain Lune and checks PLAN §7.3 items 1-2:
--   stat bonus monotone and < 6 %; stats alone worth <= 1.5 s (Speed 1e2 vs 1e15); Step gives the
--   same distance at 24 and 240 FPS; sprint seconds 4.0 / 5.0; a spike costs 0.8-1.5 s; a Perfect
--   start is worth 0.8-1.5 s against a Good one; paced sprinting beats holding sprint; nobody can
--   beat 30 s; no world walk multiplier anywhere; RaceTrack slots, spike rows, frames, SpikeAt
--   and SweptSpike.
-- 2026-09-25 (owner): the speed follows the Speed stat (40 + 6 log10(Speed), capped at 148), so
-- "stats worth <= 1.5 s" and "nobody beats 30 s" became the formula table, the brackets, each
-- racer's own plausibility floor and the slowest racer's time; plus the run floor (never a walk)
-- and the auto-run steering.
-- 2026-09-26 (owner: Sonic Dash speeds + spike spacing): 100 + 18 log10(Speed + 1) capped at
-- 300 (every Pro at the cap), the record floor under the fastest race physics allows, the heat
-- wait with a trip per spike row, and the spike rows: >= 60 studs apart (90), 4 free lanes each,
-- no straight lane free through two rows of a field.
-- Run: lune run audit/test_u4_race_math.luau   (from the project root)
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local RaceMath = require("../src/common/ReplicatedStorage/Shared/RaceMath")
local RaceTrack = require("../src/common/ReplicatedStorage/Shared/RaceTrack")
local U4 = require("../src/common/ReplicatedStorage/Shared/Update4Config")

local passed = 0
local function pass(text)
	passed += 1
	print("PASS " .. text)
end
local function near(a, b, eps)
	return math.abs(a - b) <= eps
end

-- One race with a sprint policy; returns the finish time (s).
local function race(params, grade, policy, dt, spikes)
	local state = RaceMath.NewState(params, grade, nil, 0)
	local t = 0
	local hit = {}
	while state.s < RaceTrack.Length and t < 120 do
		local s0 = state.s
		RaceMath.Step(state, { forward = 1, sprint = policy(state, t), grounded = true }, dt, params, t + dt)
		t += dt
		for _, spikeS in spikes or {} do
			if not hit[spikeS] and s0 < spikeS and state.s >= spikeS then
				hit[spikeS] = true
				RaceMath.SpikeHit(state, t)
			end
		end
	end
	return t
end
local function greedy()
	return true
end
-- Sprint from GO until the pool is empty, then only again once it is back to `threshold`.
local function paced(threshold)
	local on = true
	return function(state)
		if on and not state.sprinting and state.pool <= 0.001 then
			on = false
		elseif not on and state.pool >= threshold then
			on = true
		end
		return on
	end
end
local function best(params, grade, dt)
	local fastest = math.huge
	for _, threshold in { 0.3, 0.5, 0.7, 0.8, 0.9, 1.0 } do
		fastest = math.min(fastest, race(params, grade, paced(threshold), dt or 1 / 60))
	end
	return fastest
end

----------------------------------------------------------------------
-- The speed formula (2026-09-25, owner: the race speed reflects progress)
----------------------------------------------------------------------
do
	local SPEED = U4.Race.Speed
	assert(SPEED.BaseCruise == 100 and SPEED.LogScale == 18 and SPEED.MaxCruise == 300, "Base 100, 18 per decade, cap 300")
	-- Cruise = 100 + 18*log10(Speed + 1), capped at 300: the owner's formula (2026-09-26).
	local TABLE = { { 0, 100 }, { 1, 100 + 18 * math.log10(2) }, { 9, 118 }, { 999, 154 }, { 1e6 - 1, 208 }, { 1e9 - 1, 262 },
		{ 10 ^ (200 / 18) - 1, 300 }, { 1e12, 300 }, { 1e18, 300 }, { 1e300, 300 } }
	for _, row in TABLE do
		local caps = RaceMath.Caps(row[1])
		assert(near(caps.Vc, row[2], 1e-6), string.format("Speed %g -> cruise %g (got %.4f)", row[1], row[2], caps.Vc))
		assert(near(caps.Vs, 1.4 * caps.Vc, 1e-9), "sprint = 1.4 x cruise at " .. row[1])
		assert(near(caps.b, caps.Vc / 100 - 1, 1e-9) and near(RaceMath.StatBonus(row[1]), caps.b, 1e-9), "RaceStatBonus = the stat's share of the cruise")
	end
	assert(near(RaceMath.CruiseSpeed(1e6), 208, 1e-4) and near(RaceMath.CruiseSpeed(1e9), 262, 1e-6), "Speed 1e6 ~208, 1e9 ~262")
	assert(RaceMath.CruiseSpeed(1e11) < 300 and RaceMath.CruiseSpeed(1.3e11) == 300, "the cap is reached at Speed ~1.3e11")
	assert(RaceMath.CruiseSpeed(U4.Race.Matchmaking.ProMinSpeed) == 300, "the whole Pro bracket (Speed >= 1e12) races at the cap")
	for _, bad in { 0, -5, 0 / 0 } do
		assert(RaceMath.CruiseSpeed(bad) == 100, "Speed 0 / negative / NaN = the base cruise")
	end
	assert(near(RaceMath.CruiseSpeed(0.5), 100 + 18 * math.log10(1.5), 1e-9), "a fractional Speed still counts (log10(Speed + 1))")
	assert(RaceMath.CruiseSpeed(nil) == 100, "no Speed = the base cruise")
	assert(RaceMath.CruiseSpeed(math.huge) == 100 and RaceMath.CruiseSpeed(1e308) == 300, "an infinite (corrupt) Speed is ignored; the largest real one is capped")
	local previous = 0
	for exponent = 0, 40, 0.5 do
		local vc = RaceMath.CruiseSpeed(10 ^ exponent)
		assert(vc >= previous, "cruise never falls as Speed grows")
		previous = vc
	end
	-- The anti-cheat and the track tolerate the top: 609 studs/s at a Perfect start's peak.
	local top = RaceMath.Params(1e30, 70, 1)
	assert(near(RaceMath.PeakSpeed(top), 300 * 1.4 * 1.45, 1e-6) and RaceMath.PeakSpeed(top) <= 610, "peak speed at the cap 609 studs/s")
	assert(near(RaceMath.SprintSeconds(5), 4.0, 1e-9) and near(RaceMath.SprintSeconds(70), 5.0, 1e-9), "sprint seconds 4.0 (Flash) / 5.0 (Silver Surfer)")
	assert(near(RaceMath.SprintSeconds(nil), 4.0, 1e-9) and near(RaceMath.SprintSeconds(500), 5.0, 1e-9), "unknown suit = 4.0, capped at 5.0")
	-- Same caps in every world: the race never reads the world walk multipliers.
	local source = fs.readFile("src/common/ReplicatedStorage/Shared/RaceMath.luau")
	assert(not string.find(source, "WalkSpeedMultiplier", 1, true), "RaceMath ignores World 2/3 walk multipliers")
	pass("speed formula: 100 + 18 log10(Speed + 1) capped at 300 (1 = 105, 1e6 = 208, 1e9 = 262, 1e12+ = 300), monotone, sprint x1.4, peak 609")
end

----------------------------------------------------------------------
-- Brackets (matchmaking)
----------------------------------------------------------------------
do
	local M = U4.Race.Matchmaking
	assert(M.BeginnerMaxSpeed == 1e6 and M.BeginnerMaxRebirths == 2 and M.ProMinSpeed == 1e12 and M.ProMinRebirths == 15, "thresholds in Update4Config.Race.Matchmaking")
	local B = RaceMath.Bracket
	local cases = {
		{ 1, 0, "Beginner" }, { 999999, 2, "Beginner" }, { 0 / 0, nil, "Beginner" },
		{ 1e6, 0, "Mid" }, { 5, 3, "Mid" }, { 1e11, 14, "Mid" }, { 999999999999, 0, "Mid" },
		{ 1e12, 0, "Pro" }, { 1, 15, "Pro" }, { 1e20, 40, "Pro" },
	}
	for _, case in cases do
		assert(B(case[1], case[2]) == case[3], string.format("Speed %g, %s rebirths -> %s (got %s)", case[1], tostring(case[2]), case[3], B(case[1], case[2])))
	end
	assert(RaceMath.BracketOrder.Beginner == 1 and RaceMath.BracketOrder.Mid == 2 and RaceMath.BracketOrder.Pro == 3, "bracket order")
	pass("brackets: Beginner < 1e6 and <= 2 rebirths; Pro >= 1e12 or >= 15 rebirths; Mid between; the higher tier wins")
end

----------------------------------------------------------------------
-- Races: speed matters, frame rate, spikes, starts, pacing, plausibility, the slowest racer
----------------------------------------------------------------------
do
	local times = {}
	local previousT = math.huge
	for _, raw in { 1, 1e6, 1e9, 1e12 } do
		local t = best(RaceMath.Params(raw, 5, 1), "Perfect")
		assert(t < previousT, "a faster Speed stat finishes faster (" .. raw .. ")")
		previousT = t
		table.insert(times, string.format("%g: %.2f s", raw, t))
	end
	local newcomer, capped = best(RaceMath.Params(1, 5, 1), "Perfect"), best(RaceMath.Params(1e12, 5, 1), "Perfect")
	-- 2026-09-26: every Pro races at the cap (1e12 and 1e18 alike), Sonic Dash fast but a race.
	assert(best(RaceMath.Params(1e18, 5, 1), "Perfect") == capped, "the cap: Speed 1e12 and 1e18 race alike")
	assert(newcomer / capped >= 3 and capped >= 4 and newcomer <= 20, string.format("the fastest are clearly faster (x%.1f) but not absurd (%.1f s .. %.1f s)", newcomer / capped, capped, newcomer))
	print("  best races (Perfect start, paced sprint, no pads): " .. table.concat(times, ", "))

	local p = RaceMath.Params(1e8, 20, 1)
	local slow, fast = race(p, "Good", paced(0.8), 1 / 24), race(p, "Good", paced(0.8), 1 / 240)
	assert(math.abs(slow - fast) / fast <= 0.005, string.format("24 vs 240 FPS within 0.5 %% (%.3f vs %.3f)", slow, fast))
	local stallSlow, stallFast = race(p, "Stall", paced(0.8), 1 / 24), race(p, "Stall", paced(0.8), 1 / 240)
	assert(math.abs(stallSlow - stallFast) / stallFast <= 0.005, "a Stall's ramped run floor is FPS-independent too")
	-- The same over a fixed time: distance, not only the finish time.
	local function distanceAfter(dt, seconds)
		local st = RaceMath.NewState(p, "Perfect", nil, 0)
		local t = 0
		while t < seconds - 1e-9 do
			local sprint = t > 3 and t < 7 or t > 10 and t < 12
			RaceMath.Step(st, { forward = 1, sprint = sprint, grounded = true }, dt, p, t + dt)
			t += dt
		end
		return st.s
	end
	local d24, d240 = distanceAfter(1 / 24, 15), distanceAfter(1 / 240, 15)
	assert(math.abs(d24 - d240) / d240 <= 0.005, string.format("distance after 15 s within 0.5 %% (%.2f vs %.2f)", d24, d240))

	local clean = race(p, "Good", paced(0.8), 1 / 60)
	local one = race(p, "Good", paced(0.8), 1 / 60, { 750 })
	local four = race(p, "Good", paced(0.8), 1 / 60, { 300, 750, 1200, 1650 })
	assert(one - clean >= 0.8 and one - clean <= 1.5, string.format("one spike costs 0.8-1.5 s (%.2f)", one - clean))
	assert((four - clean) / 4 >= 0.8 and (four - clean) / 4 <= 1.5, string.format("each of 4 spikes 0.8-1.5 s (%.2f)", (four - clean) / 4))

	local perfect, good, ok, stall = best(p, "Perfect"), best(p, "Good"), best(p, "Ok"), best(p, "Stall")
	assert(good - perfect >= 0.8 and good - perfect <= 1.5, string.format("Perfect start worth 0.8-1.5 s over Good (%.2f)", good - perfect))
	assert(perfect < good and good < ok and ok < stall, "Perfect < Good < Ok < Stall")
	print(string.format("  start grades: Perfect %.2f, Good %.2f, Ok %.2f, Stall %.2f", perfect, good, ok, stall))

	-- 2026-09-26: at Sonic Dash speeds a race is over in ~5-8 s past Speed 1e6, one sprint pool
	-- long, so holding the sprint is as good as pacing there; pacing still wins the ~17 s race of
	-- a beginner (Speed 1), and sprinting always beats never sprinting.
	local beginner = RaceMath.Params(1, 5, 1)
	assert(best(beginner, "Good") < race(beginner, "Good", greedy, 1 / 60), "a beginner's paced sprint beats holding sprint")
	assert(best(p, "Good") <= race(p, "Good", greedy, 1 / 60) + 0.1, "paced never loses to holding sprint")
	assert(race(p, "Good", greedy, 1 / 60) < race(p, "Good", function() return false end, 1 / 60), "...and sprinting beats never sprinting")

	-- Plausibility: nobody beats their own floor, and every floor is above the record floor.
	for _, raw in { 1, 1e6, 1e12, 1e300 } do
		local params = RaceMath.Params(raw, 70, 1)
		local absolute = best(params, "Perfect", 1 / 240)
		assert(absolute * 1000 > RaceMath.PlausibleMs(params) * 1.3, string.format("Speed %g: the best race %.2f s is well over its floor %.2f s", raw, absolute, RaceMath.PlausibleMs(params) / 1000))
		assert(RaceMath.PlausibleMs(params) >= RaceMath.MinPlausibleMs, "each racer's floor >= the record floor")
	end
	assert(RaceMath.MinPlausibleMs == U4.Race.Validation.MinPlausibleMs and RaceMath.MinPlausibleMs <= RaceMath.PlausibleMs(RaceMath.Params(1e300, 70, 1)), "the record floor sits under the fastest possible race")

	-- The slowest honest racer (Speed 1, never sprints, Ok start, every spike) finishes before the
	-- heat stops waiting for them (ExpectedSeconds x FinishWaitFactor) and before MaxRaceSeconds.
	-- 2026-09-26: Speed 0, a Stall start and a trip on every spike row (10 rows now).
	local everyRow = {}
	for _, row in RaceTrack.SpikeRows() do
		table.insert(everyRow, row.s)
	end
	local slowest = RaceMath.Params(0, 5, 1)
	local crawl = race(slowest, "Stall", function() return false end, 1 / 60, everyRow)
	local wait = RaceMath.ExpectedSeconds(slowest) * U4.Race.Queue.FinishWaitFactor
	assert(crawl < wait and wait <= U4.Race.Queue.MaxRaceSeconds, string.format("slowest racer %.1f s < heat wait %.1f s <= %d s", crawl, wait, U4.Race.Queue.MaxRaceSeconds))
	-- TripSeconds is what one trip costs at cruise (the model, measured).
	local cruiseOnly = RaceMath.Params(1, 5, 1)
	local plain = race(cruiseOnly, "Ok", function() return false end, 1 / 240)
	local tripped = race(cruiseOnly, "Ok", function() return false end, 1 / 240, { 700 })
	assert(math.abs((tripped - plain) - RaceMath.TripSeconds()) <= 0.03, string.format("a trip costs TripSeconds %.3f s (measured %.3f)", RaceMath.TripSeconds(), tripped - plain))
	assert(near(RaceMath.ExpectedSeconds(slowest), 2000 / 100 + #everyRow * RaceMath.TripSeconds(), 1e-9), "ExpectedSeconds = cruise time + a trip per spike row")
	-- The record floor: under the fastest race physics allows (cap x sprint x Perfect peak x the
	-- largest pad at every instant).
	local bound = 1000 * U4.Race.Track.Length / (300 * 1.4 * U4.Race.Charge.Boost.Perfect[1] * U4.Race.Pads.MaxBoost)
	assert(RaceMath.MinPlausibleMs < bound, string.format("record floor %d ms < the physical bound %.0f ms", RaceMath.MinPlausibleMs, bound))
	pass(string.format("races: speed matters (x%.1f), FPS-independent, spike %.2f s, Perfect +%.2f s, paced > greedy, per-racer floors, slowest %.1f s", newcomer / capped, one - clean, good - perfect, crawl))
end

----------------------------------------------------------------------
-- Never a walk: the run floor and the auto-run steering (2026-09-25, owner)
----------------------------------------------------------------------
do
	local p = RaceMath.Params(1e6, 5, 1)
	local floor = U4.Race.Speed.RunFloor * p.Vc
	-- Moving forward on the ground after GO: never under the run floor, at once.
	local st = RaceMath.NewState(p, "Ok", 0, 0)
	RaceMath.Step(st, { forward = 1, grounded = true }, 1 / 60, p, 1)
	assert(st.v >= floor - 1e-9, "forward on the ground: at least RunFloor x cruise at once")
	assert(RaceMath.RunFloor(st, { forward = 1, grounded = true }, p, 1) == floor, "RunFloor = 0.6 x cruise")
	-- Not without forward input, not in the air, not before GO, not while stumbling.
	st = RaceMath.NewState(p, "Ok", 0, 0)
	RaceMath.Step(st, { forward = 0, grounded = true }, 1 / 60, p, 1)
	assert(st.v == 0, "no forward input: no floor")
	st = RaceMath.NewState(p, "Ok", 0, 0)
	RaceMath.Step(st, { forward = 1, grounded = false }, 1 / 60, p, 1)
	assert(st.v == 0, "airborne: no floor (no acceleration in the air)")
	st = RaceMath.NewState(p, "Ok", 0, 10)
	RaceMath.Step(st, { forward = 1, grounded = true }, 1 / 60, p, 9)
	assert(st.v == 0 and st.s == 0, "before GO: nothing moves")
	st = RaceMath.NewState(p, "Ok", p.Vc, 0)
	RaceMath.SpikeHit(st, 5)
	RaceMath.Step(st, { forward = 1, grounded = true }, 1 / 60, p, 5.05)
	assert(st.v < floor, "a spike's stumble is not floored (the trip is the penalty)")
	-- A Stall holds still for its 0.45 s, then the floor ramps up with the start multiplier.
	st = RaceMath.NewState(p, "Stall", nil, 0)
	RaceMath.Step(st, { forward = 1, grounded = true }, 0.2, p, 0.2)
	assert(st.v == 0, "a Stall's hold stays a stop")
	assert(near(RaceMath.RunFloor(st, { forward = 1, grounded = true }, p, 0.625), floor * 0.5, 1e-9), "halfway up the Stall ramp: half the floor")
	-- Auto-run steering: no input = straight down the track; sideways never slows; back brakes.
	local function dir(x, z)
		local dx, dz = RaceMath.AutoRunDirection(x, z)
		assert(near(dx * dx + dz * dz, 1, 1e-9), "a unit direction")
		return dx, dz
	end
	local x, z = dir(0, 0)
	assert(x == 0 and z == -1, "no input: straight down the track (-Z)")
	x, z = dir(1, 0)
	assert(-z > math.cos(math.rad(U4.Race.Speed.InputConeDegrees)) and x > 0.5, "sideways: steers right and stays inside the forward cone (full speed)")
	assert(RaceMath.ForwardInput(-z) > 0, "...so the model keeps its target")
	x, z = dir(0, -1)
	assert(near(x, 0, 1e-9) and near(z, -1, 1e-9), "forward stays forward")
	x, z = dir(0, 1)
	assert(near(z, 1, 1e-9) and RaceMath.ForwardInput(-z) == 0, "pulling back brakes")
	x, z = dir(-0.3, 0.1) -- 18 degrees behind the side: still a steer, not a brake
	assert(-z > 0, "a slightly backward steer still runs forward")
	pass("never a walk: run floor 0.6 x cruise at once (not in the air, before GO, stumbling or in a Stall's hold); auto-run steers without slowing")
end

----------------------------------------------------------------------
-- Step details: pool, jump, air, stumble, Accel, target before GO
----------------------------------------------------------------------
do
	local p = RaceMath.Params(1e6, 5, 1)
	local st = RaceMath.NewState(p, "Ok", 0, 10)
	RaceMath.Step(st, { forward = 1, sprint = true, grounded = true }, 0.1, p, 9.9)
	assert(st.v == 0 and st.s == 0 and not st.sprinting, "nothing moves before GO")
	st = RaceMath.NewState(p, "Ok", p.Vc, 0)
	st.pool = 0.05
	RaceMath.Step(st, { forward = 1, sprint = true, grounded = true }, 0.1, p, 1)
	assert(not st.sprinting, "sprint needs the minimum pool to start")
	st.pool = 0.5
	RaceMath.Step(st, { forward = 1, sprint = true, grounded = true }, 0.1, p, 1.1)
	assert(st.sprinting and st.pool < 0.5, "sprint drains the pool")
	local drained = st.pool
	RaceMath.Step(st, { forward = 1, sprint = false, grounded = true }, 0.5, p, 1.6)
	assert(st.pool == drained, "no regen inside the 0.8 s delay")
	RaceMath.Step(st, { forward = 1, sprint = false, grounded = true }, 1, p, 2.6)
	assert(near(st.pool, drained + 0.12, 1e-9), "regen 0.12/s after the delay")
	local before = st.pool
	RaceMath.Step(st, { forward = 1, sprint = false, grounded = true, jumped = true }, 0.01, p, 2.61)
	assert(near(st.pool, before - 0.06 + 0.12 * 0.01, 1e-9), "a jump costs 0.06")
	local v = st.v
	st.v = 10
	RaceMath.Step(st, { forward = 1, sprint = false, grounded = false }, 0.5, p, 3.2)
	assert(st.v == 10, "no acceleration in the air")
	st.v = v
	assert(RaceMath.SpikeHit(st, 4) and near(st.v, v * 0.35, 1e-9), "a spike keeps 35 %")
	assert(not RaceMath.SpikeHit(st, 5.5), "immune for 0.7 + 0.9 s")
	assert(RaceMath.SpikeHit(st, 5.61), "...then hit again")
	assert(near(RaceMath.Target(st, { forward = 1, sprint = true }, p, 5.7), 0.5 * p.Vc, 1e-9), "stumbling: half cruise, no sprint")
	assert(RaceMath.Target(st, { forward = 0 }, p, 9) == 0, "no forward input = target 0")
	assert(RaceMath.ForwardInput(1) == 1 and RaceMath.ForwardInput(math.cos(math.rad(75))) == 0 and RaceMath.ForwardInput(-1) == 0, "70 degree input cone")
	st = RaceMath.NewState(p, "Ok", 0, 0)
	RaceMath.Step(st, { forward = 1, sprint = false, grounded = true }, 0.01, p, 0.01)
	assert(RaceMath.Accel(st) > 0, "Accel positive while speeding up")
	assert(near(RaceMath.NewState(p, "Perfect", nil, 0).v, 1.2 * p.Vc, 1e-9) and near(RaceMath.NewState(p, "Ok", nil, 0).v, 0.6 * p.Vc, 1e-9)
		and RaceMath.NewState(p, "Stall", nil, 0).v == 0, "launch v0 = Vc * Launch[grade] (1.2 / 0.6 / 0)")
	assert(RaceMath.WeekId(4 * 86400) == 1 and RaceMath.WeekId(4 * 86400 - 1) == 0, "weeks start Monday 00:00 UTC (1970-01-05)")
	assert(RaceMath.DayId(86399) == 0 and RaceMath.DayId(86400) == 1, "DayId = UTC day")
	pass("Step: locked before GO, sprint start/drain, regen delay, jump cost, air, spikes + immunity, cone, launch, WeekId/DayId")
end

----------------------------------------------------------------------
-- RaceTrack
----------------------------------------------------------------------
do
	local seen = {}
	for i = 1, RaceTrack.SlotCount do
		local cf = RaceTrack.SlotCFrame(i)
		local s, x, y = RaceTrack.ToLocal(cf.Position)
		assert(s < 0 and s > -RaceTrack.StagingDepth and math.abs(x) < RaceTrack.Width / 2 - 2 and near(y, 3, 0.02), "slot " .. i .. " inside the staging box")
		local key = string.format("%.1f:%.1f", s, x)
		assert(not seen[key], "slot " .. i .. " distinct")
		seen[key] = true
		assert(near(cf.LookVector.Z, -1, 1e-6), "slot faces down the track (-Z)")
	end
	assert(RaceTrack.SlotCount == 16 and RaceTrack.LaneX(1) == -31.5 and RaceTrack.LaneX(8) == 31.5, "16 slots, lanes -31.5..31.5")
	-- Every spike row leaves free lanes wide enough to run through.
	local rows = {}
	for _, tile in RaceTrack.SpikeTiles() do
		local key = tile.field .. ":" .. tile.row
		rows[key] = rows[key] or {}
		rows[key][tile.lane] = true
	end
	local rowCount = 0
	for key, blocked in rows do
		rowCount += 1
		local free = 0
		for lane = 1, RaceTrack.Lanes do
			if not blocked[lane] then
				free += 1
			end
		end
		assert(free >= 3 and free <= 5, "row " .. key .. " leaves 3-5 free lanes (" .. free .. ")")
	end
	assert(rowCount == 10 and #RaceTrack.SpikeTiles() == 40 and #RaceTrack.SpikeRows() == rowCount, "4 fields, 2-3 rows each (10), 4 tiles a row")
	-- 2026-09-26 (owner: never an impassable wall, dodging a skill): rows >= 60 studs apart (90),
	-- 4 free lanes each, and two rows in a row of a field never leave the same lane free (the racer
	-- weaves: at most 2 lanes between rows, 18 studs, far under the gap at the 45-degree steer).
	local spikeRows = RaceTrack.SpikeRows()
	for index, row in spikeRows do
		assert(#row.free == 4 and #row.blocked == 4, "row at s " .. row.s .. ": 4 free lanes")
		local nextRow = spikeRows[index + 1]
		if nextRow then
			assert(nextRow.s - row.s >= 60 and nextRow.s - row.s >= U4.Race.Track.SpikeRowGap, "rows >= 60 studs apart (" .. row.s .. " -> " .. nextRow.s .. ")")
			if nextRow.field == row.field then
				local worst = 0
				for _, lane in row.free do
					assert(not table.find(nextRow.free, lane), string.format("lane %d is not free through rows %d and %d", lane, row.s, nextRow.s))
					local nearest = math.huge
					for _, other in nextRow.free do
						nearest = math.min(nearest, math.abs(other - lane))
					end
					worst = math.max(worst, nearest)
				end
				assert(worst <= 2 and worst * RaceTrack.LaneWidth < nextRow.s - row.s - 2 * RaceTrack.SpikeReach(), "the next row's free lane is at most 2 lanes away")
			end
		end
	end
	assert(spikeRows[1].s >= 200 and spikeRows[#spikeRows].s <= U4.Race.Track.LastStretchAt - 40, "spikes clear of the start and the last stretch")
	for _, tile in RaceTrack.SpikeTiles() do
		for lane = 1, RaceTrack.Lanes do
			local blockedHere = false
			for _, other in RaceTrack.SpikeTiles() do
				if other.s == tile.s and other.lane == lane then
					blockedHere = true
				end
			end
			if not blockedHere then
				assert(RaceTrack.SpikeAt(tile.s, RaceTrack.LaneX(lane), 3) == nil, "a free lane's centre is never hit")
			end
		end
	end
	-- Frames.
	for _, sample in { { 0, 0, 0 }, { 1234.5, -20.25, 3 }, { -40, 31.5, 7 } } do
		local world = RaceTrack.ToWorld(sample[1], sample[2], sample[3])
		local s, x, y = RaceTrack.ToLocal(world)
		assert(near(s, sample[1], 0.01) and near(x, sample[2], 0.01) and near(y, sample[3], 0.01), "ToLocal(ToWorld) round trip")
	end
	assert(RaceTrack.DistanceLeft(1500) == 500 and RaceTrack.DistanceLeft(2100) == 0, "DistanceLeft")
	assert(RaceTrack.InCorridor(1000, 44, 80) and not RaceTrack.InCorridor(1000, 44.5, 0) and not RaceTrack.InCorridor(-151, 0, 0)
		and not RaceTrack.InCorridor(2241, 0, 0) and not RaceTrack.InCorridor(10, 0, 81), "corridor |x|<=44, -150<=s<=2240, y<=80")
	-- SpikeAt against the explicit rectangles on a grid.
	local reach = 7 / 2 - 0.5 + 1
	for s = 290, 1750, 1.5 do
		for x = -40, 40, 1.25 do
			local expected = false
			for _, tile in RaceTrack.SpikeTiles() do
				if math.abs(x - tile.x) <= reach and math.abs(s - tile.s) <= reach then
					expected = true
				end
			end
			assert((RaceTrack.SpikeAt(s, x, 3) ~= nil) == expected, string.format("SpikeAt matches the rects at s %.1f x %.2f", s, x))
		end
	end
	local tile = RaceTrack.SpikeTiles()[1]
	assert(RaceTrack.SpikeAt(tile.s, tile.x, 3.39) and not RaceTrack.SpikeAt(tile.s, tile.x, 3.4), "jumping (root 0.4 higher) clears a spike")
	-- SweptSpike: crossing a tile between two samples is caught, jumping over or passing in a free lane is not.
	assert(RaceTrack.SweptSpike(tile.s - 6, tile.x, tile.s + 6, tile.x, 3, 3) == tile, "a 12-stud step through a tile hits it")
	assert(RaceTrack.SweptSpike(tile.s - 6, tile.x, tile.s + 6, tile.x, 5, 5) == nil, "...not when airborne")
	assert(RaceTrack.SweptSpike(tile.s - 6, tile.x + 4.5, tile.s + 6, tile.x + 4.5, 3, 3) == nil, "...not beside it")
	assert(RaceTrack.SweptSpike(tile.s - 6, tile.x + 3.5, tile.s + 6, tile.x + 3.5, 3, 3, 1) == nil, "the server's 1-stud shrink forgives edges")
	math.randomseed(7)
	local function uniform(a, b)
		return a + (b - a) * math.random()
	end
	for _ = 1, 3000 do
		local s0 = uniform(280, 1760)
		local x0 = uniform(-36, 36)
		local s1, x1 = s0 + uniform(-8, 8), x0 + uniform(-3, 3)
		local swept = RaceTrack.SweptSpike(s0, x0, s1, x1, 3, 3)
		local sampled = nil
		for k = 0, 200 do
			local f = k / 200
			sampled = sampled or RaceTrack.SpikeAt(s0 + (s1 - s0) * f, x0 + (x1 - x0) * f, 3)
		end
		assert((swept ~= nil) == (sampled ~= nil), "SweptSpike agrees with dense sampling")
	end
	assert(roblox.Vector3 ~= nil, "lune roblox available")
	-- Standing heights: R15 HipHeight + half the root, R6 legs + half the root + HipHeight; the
	-- lift the spike test takes off is 0..MaxLift (never negative: nobody gets taller spikes).
	assert(RaceTrack.StandHeight("R15", 2, 2) == 3 and RaceTrack.StandHeight("R6", 0, 2) == 3, "a default rig stands at RootHeight")
	assert(near(RaceTrack.StandHeight("R6", 0.85, 2), 3.85, 1e-9) and near(RaceTrack.StandHeight("R15", 2.4, 2), 3.4, 1e-9), "the Surfer's board / a tall avatar")
	assert(RaceTrack.StandHeight("R15", 0 / 0, 2) == 3 and RaceTrack.StandHeight("R15", 50, 2) == 3, "odd numbers: RootHeight")
	assert(RaceTrack.RootLift(3) == 0 and RaceTrack.RootLift(2.5) == 0 and near(RaceTrack.RootLift(3.85), 0.85, 1e-9)
		and RaceTrack.RootLift(9) == U4.Race.Adhesion.MaxLift and RaceTrack.RootLift(nil) == 0, "RootLift 0..MaxLift")
	local lifted = RaceTrack.RootLift(RaceTrack.StandHeight("R6", 0.85, 2))
	assert(RaceTrack.SweptSpike(tile.s - 6, tile.x, tile.s + 6, tile.x, 3.85, 3.85) == nil
		and RaceTrack.SweptSpike(tile.s - 6, tile.x, tile.s + 6, tile.x, 3.85 - lifted, 3.85 - lifted) == tile,
		"a Surfer standing on the board was over every spike; with the lift taken off it is hit")
	for _, inField in { 300, 345, 390, 930, 1740 } do
		assert(RaceTrack.InSpikeField(inField, 0), "s " .. inField .. " inside a spike field")
	end
	assert(not RaceTrack.InSpikeField(500, 8) and not RaceTrack.InSpikeField(1100, 8) and RaceTrack.InSpikeField(295, 8), "InSpikeField")
	pass("RaceTrack: 16 distinct staging slots facing -Z, spike rows (>= 60 apart, 4 free lanes, staggered), frames, corridor, SpikeAt = rects, SweptSpike = sampling, standing lift")
end

print(string.format("test_u4_race_math: %d checks passed", passed))
