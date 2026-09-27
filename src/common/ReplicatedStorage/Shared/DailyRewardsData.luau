--[[
	DailyRewardsData – 30-day daily login reward definitions.
	Edit this module to change reward types, amounts, featured flags, etc.

	Each entry:
	  Day       – sequential day number (1–30)
	  Type      – "Wins", "Speed", "SpinTicket", "PotionSpeed" or "PotionWins"
	  Amount    – reward quantity (tickets for SpinTicket, minutes for the 2x potions)
	  Featured  – (optional) marks milestone days (3, 7, 14, 21, 30)
	  Milestone – (optional) true for the biggest milestones (7, 14, 21, 30)
]]

local DailyRewardsData = {}

DailyRewardsData.DaySeconds = 24 * 60 * 60
DailyRewardsData.TotalDays = 30

DailyRewardsData.SpeedIconImage = "rbxassetid://18209576965"
DailyRewardsData.WinsIconImage = "rbxassetid://15540211845"

-- M14 (2026-09-25): the Daily turns on a fixed day, 08:00 UTC, like the quests
-- (Shared/QuestPeriod). A claim opens the next one after at least 12 h and at most 20 h:
-- the next 08:00 UTC once 12 h have passed, or 20 h after the claim, whichever is first.
-- (It was a rolling 24 h, so a player who claimed at 21:00 had to come back later every day.)
DailyRewardsData.ResetUtcHour = 8
DailyRewardsData.ClaimFloorSeconds = 43200
DailyRewardsData.ClaimRollingSeconds = 72000

local function dayOf(t: number): number
	return math.floor((t - DailyRewardsData.ResetUtcHour * 3600) / DailyRewardsData.DaySeconds)
end

-- canClaim, secondsRemaining (never negative; 0 when claimable). `last` 0 = never claimed.
function DailyRewardsData.ClaimWindow(last: number?, now: number): (boolean, number)
	local lastClaim = tonumber(last) or 0
	if lastClaim ~= lastClaim then
		lastClaim = 0
	end
	now = tonumber(now) or 0
	if lastClaim <= 0 then
		return true, 0
	end
	local elapsed = now - lastClaim
	if elapsed >= DailyRewardsData.ClaimRollingSeconds
		or (elapsed >= DailyRewardsData.ClaimFloorSeconds and dayOf(now) > dayOf(lastClaim)) then
		return true, 0
	end
	local nextReset = (dayOf(lastClaim) + 1) * DailyRewardsData.DaySeconds + DailyRewardsData.ResetUtcHour * 3600
	local opensAt = math.min(
		lastClaim + DailyRewardsData.ClaimRollingSeconds,
		math.max(nextReset, lastClaim + DailyRewardsData.ClaimFloorSeconds)
	)
	return false, math.max(0, opensAt - now)
end

-- M15 (2026-09-25): one reward scale for the whole month (the old days 16-30 jumped to
-- 1e10-1e12 Speed), with Spin tickets on days 2/12/26 and 2x potions on days 5/19 (minutes).
-- Speed and Wins keep their multipliers when claimed (DailyLoginSystem).
DailyRewardsData.Rewards = {
	{Day = 1,  Type = "Speed",       Amount = 500},
	{Day = 2,  Type = "SpinTicket",  Amount = 1},
	{Day = 3,  Type = "Wins",        Amount = 250,      Featured = true},
	{Day = 4,  Type = "Speed",       Amount = 5000},
	{Day = 5,  Type = "PotionSpeed", Amount = 15},
	{Day = 6,  Type = "Wins",        Amount = 1000},
	{Day = 7,  Type = "Speed",       Amount = 100000,   Featured = true, Milestone = true},
	{Day = 8,  Type = "Wins",        Amount = 5000},
	{Day = 9,  Type = "Speed",       Amount = 250000},
	{Day = 10, Type = "Wins",        Amount = 10000},
	{Day = 11, Type = "Speed",       Amount = 500000},
	{Day = 12, Type = "SpinTicket",  Amount = 2},
	{Day = 13, Type = "Wins",        Amount = 50000},
	{Day = 14, Type = "Speed",       Amount = 2000000,  Featured = true, Milestone = true},
	{Day = 15, Type = "Wins",        Amount = 150000},
	{Day = 16, Type = "Speed",       Amount = 5000000},
	{Day = 17, Type = "Wins",        Amount = 300000},
	{Day = 18, Type = "Speed",       Amount = 10000000},
	{Day = 19, Type = "PotionWins",  Amount = 30},
	{Day = 20, Type = "Speed",       Amount = 25000000},
	{Day = 21, Type = "Wins",        Amount = 2500000,  Featured = true, Milestone = true},
	{Day = 22, Type = "Speed",       Amount = 50000000},
	{Day = 23, Type = "Wins",        Amount = 1200000},
	{Day = 24, Type = "Speed",       Amount = 100000000},
	{Day = 25, Type = "Wins",        Amount = 1600000},
	{Day = 26, Type = "SpinTicket",  Amount = 3},
	{Day = 27, Type = "Wins",        Amount = 2000000},
	{Day = 28, Type = "Speed",       Amount = 500000000},
	{Day = 29, Type = "Wins",        Amount = 2500000},
	{Day = 30, Type = "Speed",       Amount = 2500000000, Featured = true, Milestone = true},
}

return DailyRewardsData
