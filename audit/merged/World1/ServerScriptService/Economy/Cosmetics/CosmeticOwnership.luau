--!strict
-- CosmeticOwnership.luau
-- Shared gamepass-ownership resolution for the trail and aura shops.
--
-- Both shops used to call MarketplaceService:UserOwnsGamePassAsync once per
-- catalog entry every time they rebuilt their state, and they rebuild state on
-- every Wins change. That produced a burst of blocking web calls per player per
-- win, and a throttled call answering "false" was indistinguishable from a real
-- "not owned" - which is how equipped cosmetics ended up silently unequipping.
--
-- This module answers from a per-player cache, only asks Marketplace about ids
-- that really are gamepasses, and reports an unknown result as nil so callers
-- can tell "we could not check" apart from "the player does not own it".

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local CosmeticOwnership = {}

-- Developer-product ids are allocated well above this; gamepass ids are below it.
local GAMEPASS_ID_CEILING = 3000000000

local cache: { [number]: { [number]: boolean } } = {}
local inFlight: { [number]: { [number]: boolean } } = {}

-- True only when this catalog entry's Robux purchase really is a gamepass.
-- "Auto" entries carry whichever id the catalog author had; a developer-product
-- id must never be sent to UserOwnsGamePassAsync.
function CosmeticOwnership.IsGamePassEntry(entry: any): boolean
	if type(entry) ~= "table" then
		return false
	end
	local passId = tonumber(entry.RobuxPurchaseId)
	if not passId or passId <= 0 then
		return false
	end
	local purchaseType = tostring(entry.RobuxPurchaseType or "")
	if purchaseType == "GamePass" then
		return true
	end
	if purchaseType == "Product" or purchaseType == "DeveloperProduct" then
		return false
	end
	return passId < GAMEPASS_ID_CEILING
end

function CosmeticOwnership.GamePassIdFor(entry: any): number?
	if not CosmeticOwnership.IsGamePassEntry(entry) then
		return nil
	end
	return tonumber(entry.RobuxPurchaseId)
end

-- Returns true / false when the answer is known, and nil when Marketplace could
-- not be reached. Callers must treat nil as "leave the current state alone".
function CosmeticOwnership.Owns(player: Player, passId: number?): boolean?
	if not player or not passId or passId <= 0 then
		return false
	end

	local userId = player.UserId
	local byPass = cache[userId]
	if byPass and byPass[passId] ~= nil then
		return byPass[passId]
	end

	-- One outstanding query per player and pass; concurrent callers get "unknown".
	local pending = inFlight[userId]
	if pending and pending[passId] then
		return nil
	end
	pending = pending or {}
	pending[passId] = true
	inFlight[userId] = pending

	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(userId, passId)
	end)

	pending[passId] = nil
	if next(pending) == nil then
		inFlight[userId] = nil
	end

	if not ok then
		-- Throttled or offline: do not cache a false negative.
		return nil
	end

	byPass = cache[userId] or {}
	byPass[passId] = owns == true
	cache[userId] = byPass
	return owns == true
end

-- Record a purchase we just observed, so the next lookup skips the web call.
function CosmeticOwnership.MarkOwned(player: Player, passId: number?)
	if not player or not passId or passId <= 0 then
		return
	end
	local byPass = cache[player.UserId] or {}
	byPass[passId] = true
	cache[player.UserId] = byPass
end

function CosmeticOwnership.Forget(userId: number)
	cache[userId] = nil
	inFlight[userId] = nil
end

Players.PlayerRemoving:Connect(function(player)
	CosmeticOwnership.Forget(player.UserId)
end)

return CosmeticOwnership
