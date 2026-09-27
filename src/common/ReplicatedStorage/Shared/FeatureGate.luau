--!strict
-- FeatureGate.luau
-- Authoritative gate for preview features (Spin Wheel, AFK Rewards and the AFK Zone,
-- Quests, Glass Shatter). Now permanently unlocked for all players and servers.

local FeatureGate = {}

-- True where every player gets the preview features.
function FeatureGate.IsPreviewServer(): boolean
	return true
end

function FeatureGate.IsPreviewPlayer(_player: Player?): boolean
	return true
end

return FeatureGate
