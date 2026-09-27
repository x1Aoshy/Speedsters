--!strict
-- FeatureGate.luau
-- Who sees the preview features (Spin Wheel, AFK Rewards and the AFK Zone, Quests,
-- Glass Shatter): everyone in Studio and on a testing place, and on live servers only
-- the accounts in Config.PreviewFeatures. Services and panels ask the same question,
-- so a panel never opens for someone its service refuses to serve.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local FeatureGate = {}

local function listed(list: any, value: number): boolean
	if type(list) ~= "table" then
		return false
	end
	for _, entry in list do
		if tonumber(entry) == value then
			return true
		end
	end
	return false
end

-- True where every player gets the preview features.
function FeatureGate.IsPreviewServer(): boolean
	if RunService:IsStudio() then
		return true
	end
	local settings = Config.PreviewFeatures
	return type(settings) == "table" and game.PlaceId > 0 and listed(settings.TestingPlaceIds, game.PlaceId)
end

function FeatureGate.IsPreviewPlayer(player: Player?): boolean
	if FeatureGate.IsPreviewServer() then
		return true
	end
	if not player then
		return false
	end
	if Config.IsDeveloper and Config.IsDeveloper(player) then
		return true
	end
	if Config.IsTester and Config.IsTester(player) then
		return true
	end
	local settings = Config.PreviewFeatures
	return type(settings) == "table" and listed(settings.UserIds, player.UserId)
end

return FeatureGate
