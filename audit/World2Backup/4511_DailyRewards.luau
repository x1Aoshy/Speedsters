local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DailyRewardsData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DailyRewardsData"))

local DailyRewards = {}

DailyRewards.DaySeconds = DailyRewardsData.DaySeconds
DailyRewards.TotalDays = DailyRewardsData.TotalDays

DailyRewards.SpeedIconImage = DailyRewardsData.SpeedIconImage
DailyRewards.WinsIconImage = DailyRewardsData.WinsIconImage

DailyRewards.Rewards = DailyRewardsData.Rewards

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
