-- test_u4_retention_math.luau (Update 4, retention workstream, 2026-09-25)
-- Shared/RetentionMath (PLAN §7.7): the streak check-in (same / next / grace / reset), the
-- milestone keys and rewards, Playtime percent and resume, the additive multiplier and its
-- cap, and the bars' piecewise fill at the designer's markers.
-- Run: lune run audit/test_u4_retention_math.luau   (from the project root)
local M = require("../src/common/ReplicatedStorage/Shared/RetentionMath")
local U4 = require("../src/common/ReplicatedStorage/Shared/Update4Config")

local passed = 0
local function pass(text)
	passed += 1
	print("PASS " .. text)
end
local function near(a, b, eps)
	return math.abs(a - b) <= (eps or 1e-6)
end

local S, P = U4.Streak, U4.Playtime
local D = 20000 -- a UTC day number

do
	-- First check-in, then same / next / grace / a second gap within 7 days / gap >= 3.
	local s, event, keys = M.StreakCheckIn(nil, D, S)
	assert(event == "start" and s.StreakDays == 1 and s.StreakLastDay == D and #keys == 0, "first check-in starts at day 1")
	local same, e2 = M.StreakCheckIn(s, D, S)
	assert(e2 == "same" and same.StreakDays == 1, "same day: nothing changes")
	local older, e3 = M.StreakCheckIn(s, D - 3, S)
	assert(e3 == "same" and older.StreakDays == 1 and older.StreakLastDay == D, "a clock that went back changes nothing")
	local nextDay, e4 = M.StreakCheckIn(s, D + 1, S)
	assert(e4 == "next" and nextDay.StreakDays == 2, "next day: +1")
	assert(s.StreakDays == 1, "the input state is untouched")
	local graced, e5 = M.StreakCheckIn(nextDay, D + 3, S)
	assert(e5 == "grace" and graced.StreakDays == 3 and graced.StreakGraceDay == D + 3, "one missed day: the grace saves it")
	local again, e6 = M.StreakCheckIn(graced, D + 5, S)
	assert(e6 == "reset" and again.StreakDays == 1, "a second missed day within 7 days: reset")
	local later, e7 = M.StreakCheckIn(graced, D + 3 + 1 + 8, S)
	assert(e7 == "reset", "gap of 8: reset even with the grace free")
	local afterWeek, e8 = M.StreakCheckIn({ StreakDays = 9, StreakLastDay = D + 10, StreakGraceDay = D + 3, StreakBest = 9 }, D + 12, S)
	assert(e8 == "grace" and afterWeek.StreakDays == 10, "the grace comes back 7 days after it was used")
	local gap3, e9 = M.StreakCheckIn(nextDay, D + 4, S)
	assert(e9 == "reset" and gap3.StreakDays == 1, "gap >= 3: reset")
	assert(gap3.StreakBest == 2 and again.StreakBest == 3, "Best is kept through resets")
	pass("StreakCheckIn: start / same / next / grace / second gap within 7 days / gap >= 3, Best kept")
end

do
	-- Milestone keys at cycle days 7/14/21 of cycle 1 and cycle 2 (days 28/35/42).
	local s = { StreakDays = 0, StreakLastDay = 0 }
	local keysAt = {}
	local day = D
	for n = 1, 42 do
		local event, keys
		s, event, keys = M.StreakCheckIn(s, day, S)
		assert(s.StreakDays == n, "day " .. n)
		for _, key in keys do
			keysAt[n] = key
		end
		day += 1
		if n % 7 == 0 then
			-- claim as it goes so Pending never overflows here
			s.StreakPending = {}
			for _, key in keys do
				table.insert(s.StreakClaimed, key)
			end
		end
	end
	assert(keysAt[7] == "c1_d7" and keysAt[14] == "c1_d14" and keysAt[21] == "c1_d21", "cycle 1 keys")
	assert(keysAt[28] == "c2_d7" and keysAt[35] == "c2_d14" and keysAt[42] == "c2_d21", "cycle 2 keys (days 28/35/42)")
	local count = 0
	for _ in keysAt do
		count += 1
	end
	assert(count == 6, "exactly six milestones in 42 days")
	assert(M.CycleDay(28, S) == 7 and M.Cycle(28, S) == 2 and M.CycleDay(21, S) == 21 and M.Cycle(21, S) == 1, "cycle day / cycle")
	-- Pending survives a reset; a cycle-1 milestone already claimed is filed as a later cycle.
	local p = { StreakDays = 6, StreakLastDay = D, StreakPending = { "c1_d21" }, StreakClaimed = { "c1_d7" } }
	local r = M.StreakCheckIn(p, D + 9, S)
	assert(r.StreakDays == 1 and r.StreakPending[1] == "c1_d21", "pending keys survive a reset")
	local sixth = M.StreakCheckIn(p, D + 1, S)
	assert(sixth.StreakPending[2] == "c2_d7", "day 7 again after a claimed c1_d7 pays the Repeat reward (c2_d7)")
	local full = { StreakDays = 13, StreakLastDay = D, StreakPending = { "c1_d7", "c2_d7", "c3_d7", "c4_d7", "c5_d7", "c6_d7" } }
	local over = M.StreakCheckIn(full, D + 1, S)
	assert(#over.StreakPending == 6 and over.StreakPending[1] == "c2_d7" and over.StreakPending[6] == "c1_d14", "at most 6 pending: the oldest goes")
	pass("milestone keys: cycle days 7/14/21, cycle 2 at 28/35/42, pending survives resets, at most 6")
end

do
	local r7, r14, r21 = M.MilestoneReward("c1_d7", S), M.MilestoneReward("c1_d14", S), M.MilestoneReward("c1_d21", S)
	assert(r7.Perk == 0.2 and r7.TitleId == "streak_7" and r7.SpinTickets == 0, "first day 7: perk 0.2 + title")
	assert(r14.Perk == 0.4 and r14.TitleId == nil, "first day 14: perk 0.4")
	assert(r21.SpinTickets == 5 and r21.SpeedPotionMinutes == 60 and r21.WinsPotionMinutes == 60 and r21.TitleId == "streak_21", "first day 21: the Skull Chest + title")
	local q7, q21 = M.MilestoneReward("c2_d7", S), M.MilestoneReward("c3_d21", S)
	assert(q7.Perk == 0 and q7.SpinTickets == 2 and q7.SpeedPotionMinutes == 30 and q7.TitleId == nil, "repeat day 7: 2 spins + 30 min")
	assert(q21.SpinTickets == 5 and q21.TitleId == nil, "repeat day 21: the chest without the title")
	for _, bad in { "c1_d8", "c0_d7", "x1_d7", "", 7, "c1_d7 ", "c99999999999999_d7" } do
		assert(M.MilestoneReward(bad, S) == nil, "malformed key refused: " .. tostring(bad))
	end
	assert(M.OldestPending({ StreakPending = { "junk", "c2_d14", "c1_d7" } }, S) == "c2_d14", "claims go oldest first, junk skipped")
	pass("MilestoneReward: First / Repeat tables, malformed keys refused, oldest pending first")
end

do
	local expected = { [599] = 0, [600] = 10, [1800] = 30, [3600] = 60, [6000] = 100, [9000] = 100, [0] = 0, [-5] = 0 }
	for seconds, pct in expected do
		assert(M.PlaytimePercent(seconds, P) == pct, "PlaytimePercent(" .. seconds .. ") = " .. pct)
	end
	assert(M.PlaytimePercent(0 / 0, P) == 0, "NaN seconds count as 0")
	assert(M.PlaytimeMaxSeconds(P) == 6000, "max after 100 minutes")
	assert(M.PlaytimeNextStepIn(0, P) == 600 and M.PlaytimeNextStepIn(1790, P) == 10 and M.PlaytimeNextStepIn(6000, P) == nil, "countdown to the next +10 %")
	assert(M.PlaytimeMarkersReached(599, P) == 0 and M.PlaytimeMarkersReached(1800, P) == 2 and M.PlaytimeMarkersReached(6000, P) == 4, "funnel markers")
	-- Resume within 900 s keeps seconds and the session; after that it starts over.
	local now = 1790000000
	local saved = { PlaytimeSeconds = 1500, PlaytimeLastSeen = now - 900, PlaytimeSessionStart = now - 2000 }
	local seconds, start, resumed = M.ResumePlaytime(saved, now, P)
	assert(resumed and seconds == 1500 and start == now - 2000, "back within 15 min: kept")
	seconds, start, resumed = M.ResumePlaytime(saved, now + 61, P)
	assert(not resumed and seconds == 0 and start == now + 61, "back after 16 min: reset")
	seconds = M.ResumePlaytime({ PlaytimeSeconds = 1e9, PlaytimeLastSeen = now, PlaytimeSessionStart = now }, now, P)
	assert(seconds == 6000, "a saved counter past the maximum is clamped")
	assert(select(3, M.ResumePlaytime(nil, now, P)) == false, "nothing saved: a new session")
	pass("Playtime: 599/600/1800/3600/6000/9000 = 0/10/30/60/100/100, countdown, markers, resume 900 s")
end

do
	assert(near(M.StreakBonus(1, S), 0.1) and near(M.StreakBonus(4, S), 0.4) and near(M.StreakBonus(40, S), 1), "streak bonus +10 %/day, max +100 %")
	assert(near(M.Multiplier(0.3, 0.4, 0, U4.RetentionMultiplierCap), 1.7), "additive: 1 + 0.3 + 0.4")
	assert(near(M.Multiplier(1, 1, 0.4, U4.RetentionMultiplierCap), 3.4), "all maxed = 3.4")
	assert(near(M.Multiplier(5, 5, 5, U4.RetentionMultiplierCap), 3.4), "never beyond the cap")
	assert(near(M.Multiplier(0 / 0, -1, 0, 3.4), 1), "NaN / negatives count as nothing")
	assert(M.FormatMultiplier(1.4) == "x1.4" and M.FormatMultiplier(2) == "x2.0", "multiplier text")
	-- LiveStreakDays: a broken streak shows 0 before today's check-in.
	local st = { StreakDays = 5, StreakLastDay = D, StreakGraceDay = 0 }
	assert(M.LiveStreakDays(st, D + 1, S) == 5 and M.LiveStreakDays(st, D + 2, S) == 5 and M.LiveStreakDays(st, D + 3, S) == 0, "live streak")
	pass("multiplier: additive, cap 3.4, streak bonus, live days")
end

do
	-- The designer's marker X scales (uineww.rbxm Playtime Boost.Info): 0.148 / 0.331 / 0.594 / 0.992.
	local pts = { { 0, 0 }, { 600, 0.148 }, { 1800, 0.331 }, { 3600, 0.594 }, { 6000, 0.992 } }
	assert(near(M.PiecewiseFill(600, pts), 0.148) and near(M.PiecewiseFill(6000, pts), 0.992), "600 -> 0.148, 6000 -> 0.992")
	assert(near(M.PiecewiseFill(1200, pts), 0.148 + (0.331 - 0.148) / 2), "halfway between markers")
	assert(near(M.PiecewiseFill(-1, pts), 0) and near(M.PiecewiseFill(9999, pts), 0.992), "clamped at both ends")
	assert(M.PiecewiseFill(5, {}) == 0, "no points: empty")
	assert(M.UtcDay(86400 * 3 + 5) == 3 and M.NextUtcMidnight(86400 * 3 + 5) == 86400 * 4, "UTC days")
	assert(M.FormatClock(65) == "01:05" and M.FormatClock(3725) == "1:02:05", "clock text")
	assert(M.Text("Claim", "es") == "RECLAMAR" and M.Text("Claim", "xx") == "CLAIM" and M.Text("StatusLocked", "pt", 7) == "Dia 7", "en/es/pt words, English fallback")
	pass("PiecewiseFill at the designer markers, UTC days, clock, words")
end

print(string.format("\n%d checks passed", passed))
