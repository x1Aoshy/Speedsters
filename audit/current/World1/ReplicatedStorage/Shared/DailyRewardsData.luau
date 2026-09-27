--[[
	DailyRewardsData – 30-day daily login reward definitions.
	Edit this module to change reward types, amounts, featured flags, etc.

	Each entry:
	  Day       – sequential day number (1–30)
	  Type      – "Wins" or "Speed"
	  Amount    – reward quantity
	  Featured  – (optional) marks milestone days (3, 7, 14, 21, 30)
	  Milestone – (optional) true for the biggest milestones (7, 14, 21, 30)
]]

local DailyRewardsData = {}

DailyRewardsData.DaySeconds = 24 * 60 * 60
DailyRewardsData.TotalDays = 30

DailyRewardsData.SpeedIconImage = "rbxassetid://18209576965"
DailyRewardsData.WinsIconImage = "rbxassetid://15540211845"

DailyRewardsData.Rewards = {
	{Day = 1,  Type = "Speed", Amount = 1e6},
	{Day = 2,  Type = "Speed", Amount = 1e6},
	{Day = 3,  Type = "Wins",  Amount = 25000,   Featured = true},
	{Day = 4,  Type = "Speed", Amount = 1e8},
	{Day = 5,  Type = "Wins",  Amount = 50000},
	{Day = 6,  Type = "Speed", Amount = 2.5e8},
	{Day = 7,  Type = "Speed", Amount = 1e9,      Featured = true, Milestone = true},
	{Day = 8,  Type = "Wins",  Amount = 100000},
	{Day = 9,  Type = "Speed", Amount = 2.5e9},
	{Day = 10, Type = "Wins",  Amount = 150000},
	{Day = 11, Type = "Speed", Amount = 5e9},
	{Day = 12, Type = "Wins",  Amount = 250000},
	{Day = 13, Type = "Wins",  Amount = 300000},
	{Day = 14, Type = "Speed", Amount = 1e10,     Featured = true, Milestone = true},
	{Day = 15, Type = "Wins",  Amount = 400000},
	{Day = 16, Type = "Speed", Amount = 2.5e10},
	{Day = 17, Type = "Wins",  Amount = 600000},
	{Day = 18, Type = "Speed", Amount = 5e10},
	{Day = 19, Type = "Wins",  Amount = 850000},
	{Day = 20, Type = "Speed", Amount = 1e11},
	{Day = 21, Type = "Wins",  Amount = 5000000,  Featured = true, Milestone = true},
	{Day = 22, Type = "Speed", Amount = 2.5e11},
	{Day = 23, Type = "Wins",  Amount = 1200000},
	{Day = 24, Type = "Speed", Amount = 5e11},
	{Day = 25, Type = "Wins",  Amount = 1600000},
	{Day = 26, Type = "Speed", Amount = 7.5e11},
	{Day = 27, Type = "Wins",  Amount = 2000000},
	{Day = 28, Type = "Speed", Amount = 1e12},
	{Day = 29, Type = "Wins",  Amount = 2500000},
	{Day = 30, Type = "Speed", Amount = 5e12,     Featured = true, Milestone = true},
}

return DailyRewardsData