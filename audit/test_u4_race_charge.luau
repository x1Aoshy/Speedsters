-- test_u4_race_charge.luau (Update 4, race_server, 2026-09-25)
-- Shared/RaceChargeMath (the charge-start gauge) and Services/Race/RaceChargeJudge (the server's
-- replay of the client's edges), loaded from src in plain Lune (PLAN §7.3 items 3-4):
--   Evaluate matches a 1/2000 s numeric integration on 300 random edge lists (with overheats);
--   the outcome table (never / hold from open / late / closed loop at 0.10 and 0.28 s reaction /
--   a single press+release is never Perfect); newcomer grace; the assist; judge clamping (future,
--   stale, reordered, > 40 edges, NaN, wrong raceId, too late), accepted edges immutable, honest
--   edges sent with latency judge to the client's own prediction; StartMultiplier integrals.
-- Run: lune run audit/test_u4_race_charge.luau   (from the project root)
local RaceChargeMath = require("../src/common/ReplicatedStorage/Shared/RaceChargeMath")
local RaceChargeJudge = require("../src/common/ServerScriptService/Services/Race/RaceChargeJudge")
local U4 = require("../src/common/ReplicatedStorage/Shared/Update4Config")

local P = U4.Race.Charge
local OPEN, GO = 100 - P.Window * 2, 100 -- 3.0 s window (ChargeOpenLeadSeconds)
assert(GO - OPEN == U4.Race.Queue.ChargeOpenLeadSeconds, "the window opens ChargeOpenLeadSeconds before GO")

local passed = 0
local function pass(text)
	passed += 1
	print("PASS " .. text)
end
math.randomseed(20260925)
local function uniform(a, b)
	return a + (b - a) * math.random()
end

----------------------------------------------------------------------
-- 1. Exact evaluation vs numeric integration
----------------------------------------------------------------------
-- An independent integrator: fixed 1/2000 s steps, each cut at the edges, the overheat and the
-- end of the vent inside it (so the dynamics are right), with the band times measured by 10
-- midpoint samples per step instead of the exact crossing times.
local function numeric(edges, openAt, goAt, dt, assist)
	local zoneLo, zoneHi, coreLo, coreHi = RaceChargeMath.Bands(P, assist)
	local g, venting, ventUntil = 0, false, -math.huge
	local zoneT, coreT, heldT = 0, 0, 0
	local index, held = 1, false
	while index <= #edges and edges[index] <= openAt do
		held = index % 2 == 1
		index += 1
	end
	local t = openAt
	while t < goAt - 1e-12 do
		local stepEnd = math.min(goAt, t + dt)
		if index <= #edges and edges[index] > t and edges[index] < stepEnd then
			stepEnd = edges[index]
		end
		if venting and ventUntil > t and ventUntil < stepEnd then
			stepEnd = ventUntil
		end
		local rate = if venting then -P.Vent elseif held then P.Fill else -P.Decay
		local overheat = false
		if not venting and held and g + rate * (stepEnd - t) >= 1 then
			stepEnd, overheat = t + (1 - g) / rate, true
		end
		local h = stepEnd - t
		for k = 0, 9 do
			local mid = t + h * (k + 0.5) / 10
			local gMid = math.max(0, g + rate * (mid - t))
			if mid >= goAt - P.Window then
				if gMid >= zoneLo and gMid <= zoneHi then
					zoneT += h / 10
				end
				if gMid >= coreLo and gMid <= coreHi then
					coreT += h / 10
				end
			end
		end
		if held and not venting then
			heldT += h
		end
		g = math.clamp(g + rate * h, 0, 1)
		t = stepEnd
		if overheat then
			g, venting, ventUntil = 1, true, t + P.VentSeconds
		elseif venting and t >= ventUntil - 1e-12 then
			venting = false
		end
		while index <= #edges and edges[index] <= t + 1e-12 do
			held = index % 2 == 1
			index += 1
		end
	end
	return { G = g, ZoneT = zoneT, CoreT = coreT, HeldSeconds = heldT }
end

do
	local worst = { G = 0, ZoneT = 0, CoreT = 0, HeldSeconds = 0 }
	local overheats = 0
	for n = 1, 300 do
		local edges = {}
		local count = math.random(0, 16)
		local t = OPEN - 0.3
		for _ = 1, count do
			-- long holds now and then so overheats happen
			t += if math.random() < 0.25 then uniform(1.2, 2.2) else uniform(0.03, 0.6)
			table.insert(edges, t)
		end
		local exact = RaceChargeMath.Evaluate(edges, OPEN, GO, GO, P, n % 7 == 0)
		local approx = numeric(edges, OPEN, GO, 1 / 2000, n % 7 == 0)
		if exact.OverheatAt then
			overheats += 1
		end
		for key in worst do
			worst[key] = math.max(worst[key], math.abs(exact[key] - approx[key]))
		end
	end
	for key, err in worst do
		assert(err <= 1e-3, string.format("Evaluate %s within tolerance of the 1/2000 s integration (%.5f)", key, err))
	end
	assert(worst.G <= 1e-3, "G within 1e-3")
	assert(overheats >= 20, "the random lists include overheats (" .. overheats .. ")")
	pass(string.format("Evaluate = 1/2000 s integration on 300 lists (%d overheats; max err G %.5f zone %.5f core %.5f held %.5f)",
		overheats, worst.G, worst.ZoneT, worst.CoreT, worst.HeldSeconds))
end

----------------------------------------------------------------------
-- 2. Outcome table
----------------------------------------------------------------------
local function grade(edges, grace, assist)
	return RaceChargeMath.Outcome(RaceChargeMath.Evaluate(edges, OPEN, GO, GO, P, assist), P, grace, assist)
end

-- A closed-loop player: presses `reaction` after the window opens, releases `reaction` after
-- the needle passes the top of the core, presses again `reaction` after it drops under it.
local function closedLoop(reaction, startDelay)
	local edges = { OPEN + reaction + (startDelay or 0) }
	local pendingAt = nil
	local dt = 1 / 240
	local t = edges[1]
	while t < GO do
		t += dt
		if pendingAt and t >= pendingAt then
			table.insert(edges, pendingAt)
			pendingAt = nil
		end
		local now = RaceChargeMath.Evaluate(edges, OPEN, GO, t, P)
		local held = #edges % 2 == 1
		if not pendingAt and not now.Venting then
			if held and now.G >= P.CoreHi then
				pendingAt = t + reaction
			elseif not held and now.G <= P.CoreLo then
				pendingAt = t + reaction
			end
		end
	end
	local clean = {}
	for _, e in edges do
		if e < GO then
			table.insert(clean, e)
		end
	end
	return clean
end

do
	assert(grade({}) == "Ok", "never press -> Ok")
	assert(grade({ OPEN }) == "Stall", "hold from open -> Stall (vents into the last 0.75 s)")
	assert(grade({ OPEN }, true) == "Ok", "...Ok for a newcomer (grace)")
	assert(grade({ GO - 0.3 }) == "Ok", "late press -> Ok")
	assert(grade({ GO - 0.05 }) == "Ok" and grade({ OPEN - 5, OPEN - 4 }) == "Ok", "last-instant tap / pressed before the window -> Ok")

	local perfect, total = 0, 0
	for k = 0, 10 do
		total += 1
		if grade(closedLoop(0.10, k * 0.04)) == "Perfect" then
			perfect += 1
		end
	end
	assert(perfect == total, string.format("closed loop, 0.10 s reaction -> Perfect (%d/%d)", perfect, total))
	for _, reaction in { 0.28, 0.32, 0.36 } do
		local counts = { Perfect = 0, Good = 0, Ok = 0, Stall = 0 }
		for k = 0, 10 do
			local g = grade(closedLoop(reaction, k * 0.04), true)
			counts[g] += 1
		end
		assert(counts.Perfect == 0 and counts.Good >= 6, string.format("closed loop %.2f s -> Good (P%d G%d O%d S%d)", reaction, counts.Perfect, counts.Good, counts.Ok, counts.Stall))
	end

	local bestQ, bestGrade = 0, "Ok"
	for press = OPEN, GO - 0.05, 0.05 do
		for hold = 0.3, 2.0, 0.05 do
			local result = RaceChargeMath.Evaluate({ press, press + hold }, OPEN, GO, GO, P)
			bestQ = math.max(bestQ, result.Q)
			local g = RaceChargeMath.Outcome(result, P)
			assert(g ~= "Perfect", "a single press + release is never Perfect")
			if g == "Good" then
				bestGrade = "Good"
			end
		end
	end
	assert(bestGrade == "Good" and math.abs(bestQ - 0.59) < 0.02, string.format("single press at best Good (Q %.3f ~ 0.59)", bestQ))
	pass(string.format("outcomes: never Ok, hold Stall (grace Ok), late Ok, loop 0.10 Perfect, 0.28-0.36 Good, single press Q %.3f", bestQ))
end

----------------------------------------------------------------------
-- 3. Assist
----------------------------------------------------------------------
do
	local loop = closedLoop(0.10)
	assert(grade(loop, false, true) == "Good", "assist: best result Good")
	assert(grade({ OPEN }, false, true) ~= "Stall", "assist: no stall")
	local lo, hi, clo, chi = RaceChargeMath.Bands(P, true)
	assert(lo == 0.50 and hi == 0.90 and clo == 0.60 and chi == 0.80, "assist bands")

	local fired = {}
	local now = 0
	local judge = RaceChargeJudge.new({ now = function() return now end, fire = function(_, payload) table.insert(fired, payload) end })
	local attrs = { RaceFinishes = 10 }
	local player = { Name = "p", GetAttribute = function(_, k) return attrs[k] end, SetAttribute = function(_, k, v) attrs[k] = v end }
	for race = 1, 3 do
		judge:Open(player, race, OPEN, GO)
		now = GO + 1
		judge:Tick(now)
		assert(judge:Result(player) == "Ok", "never pressing -> Ok")
	end
	assert(judge:IsAssisted(player), "assist after 3 consecutive misses")
	judge:Open(player, 4, OPEN, GO)
	now = OPEN
	judge:Input(player, 4, { OPEN + 0.1 }, false)
	now = GO + 1
	judge:Tick(now)
	assert(judge:Result(player) ~= "Stall" and attrs.RaceStartGrade == judge:Result(player), "assisted judge never stalls")
	assert(fired[#fired].kind == "Start" and fired[#fired].grade == judge:Result(player), "RaceEvent Start{grade}")
	pass("assist: wider bands, no stall, Good at best, on after 3 misses")
end

----------------------------------------------------------------------
-- 4. Judge: clamping, immutability, rejects, honest replay
----------------------------------------------------------------------
local function newPlayer(finishes)
	local attrs = { RaceFinishes = finishes or 5 }
	return { Name = "racer", attrs = attrs, GetAttribute = function(_, k) return attrs[k] end, SetAttribute = function(_, k, v) attrs[k] = v end }
end

do
	local now = OPEN
	local steps, judged = {}, {}
	local judge = RaceChargeJudge.new({
		now = function() return now end,
		funnel = { Step = function(_, funnel, step) table.insert(steps, funnel .. step) end, Event = function() end },
		onJudged = function(_, g, held) table.insert(judged, { g, held }) end,
	})
	local player = newPlayer(0)
	judge:Open(player, 7, OPEN, GO)
	assert(not judge:Input(player, 8, { OPEN + 0.1 }, false), "wrong raceId refused")
	assert(not judge:Input(player, 7, "x", false) and not judge:Input(player, 7, { OPEN }, "yes"), "bad types refused")
	local tooMany = {}
	for i = 1, 41 do
		tooMany[i] = OPEN + i * 0.05
	end
	assert(not judge:Input(player, 7, tooMany, false), "> 40 edges refused")
	now = OPEN + 0.5
	assert(judge:Input(player, 7, { OPEN + 5 }, false), "future edge accepted...")
	local edges = judge:Edges(player)
	assert(math.abs(edges[1] - (OPEN + 0.55)) < 1e-9, "...clamped to received + 0.05")
	assert(steps[1] == "Onboarding_Race3", "first accepted edge of a first race -> Onboarding_Race step 3")
	now = OPEN + 1.5
	judge:Input(player, 7, { OPEN + 0.2, OPEN + 0.3 }, false)
	assert(math.abs(edges[1] - (OPEN + 0.55)) < 1e-9, "accepted edges never change")
	assert(math.abs(edges[2] - (OPEN + 1.1)) < 1e-9, "a stale edge is clamped to received - 0.40")
	now = OPEN + 1.45
	judge:Input(player, 7, { 0, 0, OPEN + 1.11 }, false)
	assert(math.abs(edges[3] - (OPEN + 1.13)) < 1e-9, "a reordered edge is pushed to previous + 0.03")
	judge:Input(player, 7, { 0, 0, 0, 0 / 0 }, false)
	assert(#edges == 3, "NaN edge dropped")
	now = GO + 0.2
	judge:Input(player, 7, { 0, 0, 0, GO + 0.15 }, false)
	assert(math.abs(edges[4] - GO) < 1e-9, "an edge after GO is clamped to GO")
	now = GO + 0.46
	assert(not judge:Input(player, 7, { 0, 0, 0, 0, GO }, true), "after GO + 0.45 the judge takes nothing")
	judge:Tick(now)
	assert(#judged == 1 and judge:Result(player) == judged[1][1], "judged at GO + 0.45 without a final packet")
	local expected = RaceChargeMath.Evaluate(edges, OPEN, GO, GO, P)
	assert(math.abs(judged[1][2] - expected.HeldSeconds) < 1e-9, "held seconds handed to RaceService")
	judge:Tick(now + 1)
	assert(#judged == 1, "judged once")
	pass("judge: raceId/type/count refusals, future/stale/reordered/NaN/after-GO clamping, immutability, late judge, funnel step 3")
end

do
	-- Honest clients: their closed-loop edges arrive 0-150 ms late (with the 0.08 s limiter), and the
	-- server grade equals the client's own prediction.
	local agree, total = 0, 0
	for _, reaction in { 0.10, 0.14, 0.2, 0.28, 0.36 } do
		for k = 0, 5 do
			local clientEdges = closedLoop(reaction, k * 0.05)
			local predicted = grade(clientEdges)
			local now = OPEN
			local judge = RaceChargeJudge.new({ now = function() return now end })
			local player = newPlayer(5)
			judge:Open(player, 1, OPEN, GO)
			local sent = {}
			for _, edge in clientEdges do
				table.insert(sent, edge)
				now = edge + uniform(0, 0.15) + 0.04
				judge:Input(player, 1, table.clone(sent), false)
			end
			now = math.max(now, GO) + 0.1
			judge:Input(player, 1, table.clone(sent), true)
			total += 1
			if judge:Result(player) == predicted then
				agree += 1
			end
		end
	end
	assert(agree == total, string.format("honest edges: judge == client prediction (%d/%d)", agree, total))
	pass("honest edges with 0-150 ms latency: the judge agrees with the client every time")
end

----------------------------------------------------------------------
-- 5. StartMultiplier
----------------------------------------------------------------------
do
	local function integral(g)
		local sum, dt = 0, 1 / 20000
		for k = 0, 4 * 20000 do
			sum += (RaceChargeMath.StartMultiplier(g, k * dt + dt / 2, P) - 1) * dt
		end
		return sum
	end
	local perfect, good, stall = integral("Perfect"), integral("Good"), integral("Stall")
	assert(math.abs(perfect - 0.83) <= 0.01 and math.abs(good - 0.33) <= 0.01 and math.abs(stall + 0.63) <= 0.01,
		string.format("integrals Perfect %.3f Good %.3f Stall %.3f", perfect, good, stall))
	assert(math.abs(RaceChargeMath.BoostDistanceSeconds("Perfect", P) - perfect) < 1e-3 and math.abs(RaceChargeMath.BoostDistanceSeconds("Stall", P) - stall) < 1e-3, "BoostDistanceSeconds = the integrals")
	for _, g in { "Perfect", "Good", "Ok", "Stall" } do
		assert(RaceChargeMath.StartMultiplier(g, 2.5, P) == 1 and RaceChargeMath.StartMultiplier(g, 7, P) == 1, g .. " is exactly 1 from tau 2.5")
	end
	assert(RaceChargeMath.StartMultiplier("Perfect", 0.5, P) == 1.45 and RaceChargeMath.StartMultiplier("Stall", 0.2, P) == 0, "plateaus")
	-- 2026-09-25: launches +0.4 (a real impulse; the run floor is 0.6), same gaps between grades.
	assert(RaceChargeMath.Launch("Perfect", P) == 1.2 and RaceChargeMath.Launch("Good", P) == 0.9 and RaceChargeMath.Launch("Ok", P) == 0.6
		and RaceChargeMath.Launch("Stall", P) == 0 and RaceChargeMath.StaminaCost(2, P) == 0.3, "launch and stamina cost")
	pass(string.format("StartMultiplier: Perfect +%.3f s, Good +%.3f s, Stall %.3f s, exactly 1 after 2.5 s", perfect, good, stall))
end

print(string.format("test_u4_race_charge: %d checks passed", passed))
