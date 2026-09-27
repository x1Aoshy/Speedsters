local PlaytimeRewards = {}

PlaytimeRewards.IntervalSeconds = 3 * 60
PlaytimeRewards.TotalRewards = 15

                                                                            
                                                                             
                                                                             
PlaytimeRewards.GiftIconAssetId = "122099495511140"
PlaytimeRewards.CodesIconAssetId = "18469571139"

local function getAssetThumbnail(assetId)
	return string.format("rbxthumb://type=Asset&id=%s&w=420&h=420", tostring(assetId))
end

PlaytimeRewards.GiftIconImage = getAssetThumbnail(PlaytimeRewards.GiftIconAssetId)
PlaytimeRewards.CodesIconImage = getAssetThumbnail(PlaytimeRewards.CodesIconAssetId)

PlaytimeRewards.Rewards = {
	{ Index = 1, Type = "Speed", Amount = 1000 },
	{ Index = 2, Type = "Wins", Amount = 70 },
	{ Index = 3, Type = "Speed", Amount = 15000 },
	{ Index = 4, Type = "Wins", Amount = 150 },
	{ Index = 5, Type = "Speed", Amount = 70000 },
	{ Index = 6, Type = "Wins", Amount = 200 },
	{ Index = 7, Type = "Speed", Amount = 100000 },
	{ Index = 8, Type = "Wins", Amount = 235 },
	{ Index = 9, Type = "Speed", Amount = 135000 },
	{ Index = 10, Type = "Wins", Amount = 275 },
	{ Index = 11, Type = "Speed", Amount = 150000 },
	{ Index = 12, Type = "Wins", Amount = 317 },
	{ Index = 13, Type = "Speed", Amount = 175000 },
	{ Index = 14, Type = "Wins", Amount = 335 },
	{ Index = 15, Type = "Speed", Amount = 1000000 },
}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi" }

function PlaytimeRewards.GetUnlockSeconds(index)
	return math.max(1, math.floor(tonumber(index) or 1)) * PlaytimeRewards.IntervalSeconds
end

function PlaytimeRewards.GetReward(index)
	index = math.floor(tonumber(index) or 0)
	return PlaytimeRewards.Rewards[index]
end

function PlaytimeRewards.FormatNumber(value)
	value = math.max(0, tonumber(value) or 0)
	if value < 1000 then
		return tostring(math.floor(value))
	end

	local tier = math.clamp(math.floor(math.log10(math.max(1, value)) / 3) + 1, 1, #SUFFIXES)
	local scaled = value / (1000 ^ (tier - 1))
	if scaled >= 100 then
		return string.format("%.0f%s", scaled, SUFFIXES[tier])
	elseif scaled >= 10 then
		return string.format("%.1f%s", scaled, SUFFIXES[tier]):gsub("%.0", "")
	end
	return string.format("%.2f%s", scaled, SUFFIXES[tier]):gsub("0+$", ""):gsub("%.$", "")
end

function PlaytimeRewards.GetRewardText(reward)
	reward = reward or PlaytimeRewards.Rewards[1]
	return PlaytimeRewards.FormatNumber(reward.Amount) .. " " .. tostring(reward.Type)
end

return PlaytimeRewards
