local DailyRewards = {}

DailyRewards.DaySeconds = 24 * 60 * 60
DailyRewards.TotalDays = 30

DailyRewards.SpeedIconImage = "rbxassetid://18209576965"
DailyRewards.WinsIconImage = "rbxassetid://15540211845"

DailyRewards.Rewards = {
	{Day = 1, Type = "Wins", Amount = 1},
	{Day = 2, Type = "Speed", Amount = 1e6},
	{Day = 3, Type = "Wins", Amount = 25000, Featured = true},
	{Day = 4, Type = "Speed", Amount = 1e8},
	{Day = 5, Type = "Wins", Amount = 50000},
	{Day = 6, Type = "Speed", Amount = 2.5e8},
	{Day = 7, Type = "Speed", Amount = 1e9, Featured = true, Milestone = true},
	{Day = 8, Type = "Wins", Amount = 100000},
	{Day = 9, Type = "Speed", Amount = 2.5e9},
	{Day = 10, Type = "Wins", Amount = 150000},
	{Day = 11, Type = "Speed", Amount = 5e9},
	{Day = 12, Type = "Wins", Amount = 250000},
	{Day = 13, Type = "Wins", Amount = 300000},
	{Day = 14, Type = "Speed", Amount = 1e10, Featured = true, Milestone = true},
	{Day = 15, Type = "Wins", Amount = 400000},
	{Day = 16, Type = "Speed", Amount = 2.5e10},
	{Day = 17, Type = "Wins", Amount = 600000},
	{Day = 18, Type = "Speed", Amount = 5e10},
	{Day = 19, Type = "Wins", Amount = 850000},
	{Day = 20, Type = "Speed", Amount = 1e11},
	{Day = 21, Type = "Wins", Amount = 5000000, Featured = true, Milestone = true},
	{Day = 22, Type = "Speed", Amount = 2.5e11},
	{Day = 23, Type = "Wins", Amount = 1200000},
	{Day = 24, Type = "Speed", Amount = 5e11},
	{Day = 25, Type = "Wins", Amount = 1600000},
	{Day = 26, Type = "Speed", Amount = 7.5e11},
	{Day = 27, Type = "Wins", Amount = 2000000},
	{Day = 28, Type = "Speed", Amount = 1e12},
	{Day = 29, Type = "Wins", Amount = 2500000},
	{Day = 30, Type = "Speed", Amount = 5e12, Featured = true, Milestone = true},
}

local SUFFIXES = {
	"", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc", "Ud", "Dd", "Td", "Qad", "Qid", "Sxd", "Spd", "Ocd", "Nod", "Vg"
}

function DailyRewards.FormatNumber(value)
	value = tonumber(value) or 0

	if value < 1000 then
		return tostring(math.floor(value))
	end

	local tier = math.floor(math.log10(math.max(1, value)) / 3) + 1
	if tier <= #SUFFIXES then
		local scaled = value / (1000 ^ (tier - 1))

		if scaled >= 100 then
			return string.format("%.0f%s", scaled, SUFFIXES[tier])
		elseif scaled >= 10 then
			return string.format("%.1f%s", scaled, SUFFIXES[tier]):gsub("%.0", "")
		else
			return string.format("%.2f%s", scaled, SUFFIXES[tier]):gsub("0+$", ""):gsub("%.$", "")
		end
	end

	return string.format("%.2e", value)
end

function DailyRewards.GetReward(day)
	day = tonumber(day) or 1

	for _, reward in ipairs(DailyRewards.Rewards) do
		if reward.Day == day then
			return reward
		end
	end

	return DailyRewards.Rewards[1]
end

function DailyRewards.GetRewardText(reward)
	reward = reward or DailyRewards.Rewards[1]
	return DailyRewards.FormatNumber(reward.Amount) .. " " .. tostring(reward.Type)
end

function DailyRewards.GetRewardIcon(reward)
	reward = reward or DailyRewards.Rewards[1]

	if reward.Type == "Wins" then
		return "🏆"
	end

	return "⚡"
end

function DailyRewards.GetRewardIconImage(reward)
	reward = reward or DailyRewards.Rewards[1]

	if reward.Type == "Wins" then
		return DailyRewards.WinsIconImage
	end

	return DailyRewards.SpeedIconImage
end

function DailyRewards.GetNextDayAfterClaim(lastClaimedDay)
	lastClaimedDay = tonumber(lastClaimedDay) or 0

	if lastClaimedDay >= DailyRewards.TotalDays then
		return 1
	end

	return lastClaimedDay + 1
end

return DailyRewards
