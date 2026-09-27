local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DailyRewardsData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DailyRewardsData"))

local DailyRewards = {}

DailyRewards.DaySeconds = DailyRewardsData.DaySeconds
DailyRewards.TotalDays = DailyRewardsData.TotalDays

DailyRewards.SpeedIconImage = DailyRewardsData.SpeedIconImage
DailyRewards.WinsIconImage = DailyRewardsData.WinsIconImage

DailyRewards.Rewards = DailyRewardsData.Rewards
DailyRewards.ClaimWindow = DailyRewardsData.ClaimWindow

-- M15 (2026-09-25): Spin tickets and 2x potions use the quests' reward art
-- (QuestCatalog.RewardIcons). Found without waiting, on first use (on a client the module may
-- not have replicated yet when this one loads); the Speed art is the fallback until then.
local rewardIcons = nil
local function getRewardIcons()
	if rewardIcons then
		return rewardIcons
	end
	local ok, icons = pcall(function()
		local shared = ReplicatedStorage:FindFirstChild("Shared")
		local module = shared and shared:FindFirstChild("QuestCatalog")
		return module and require(module).RewardIcons
	end)
	if ok and type(icons) == "table" then
		rewardIcons = icons
		return icons
	end
	return {}
end

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
			-- Trim the zeros before the suffix ("2.5B", not "2.50B").
			local digits = string.format("%.2f", scaled):gsub("0+$", ""):gsub("%.$", "")
			return digits .. SUFFIXES[tier]
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
	local amount = math.floor(tonumber(reward.Amount) or 0)
	if reward.Type == "SpinTicket" then
		return if amount == 1 then "1 Spin" else tostring(amount) .. " Spins"
	elseif reward.Type == "PotionSpeed" then
		return "2x Speed " .. tostring(amount) .. "m"
	elseif reward.Type == "PotionWins" then
		return "2x Wins " .. tostring(amount) .. "m"
	end
	return DailyRewards.FormatNumber(reward.Amount) .. " " .. tostring(reward.Type)
end

function DailyRewards.GetRewardIcon(reward)
	reward = reward or DailyRewards.Rewards[1]

	if reward.Type == "Wins" then
		return "🏆"
	elseif reward.Type == "SpinTicket" then
		return "🎟️"
	elseif reward.Type == "PotionSpeed" or reward.Type == "PotionWins" then
		return "🧪"
	end

	return "⚡"
end

function DailyRewards.GetRewardIconImage(reward)
	reward = reward or DailyRewards.Rewards[1]

	if reward.Type == "Wins" then
		return DailyRewards.WinsIconImage
	elseif reward.Type == "SpinTicket" or reward.Type == "PotionSpeed" or reward.Type == "PotionWins" then
		return getRewardIcons()[reward.Type] or DailyRewards.SpeedIconImage
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
