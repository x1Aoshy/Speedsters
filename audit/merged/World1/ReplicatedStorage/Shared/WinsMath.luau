--!strict
-- WinsMath.luau
-- Single source of truth for how a Wins reward is multiplied.
--
-- Every producer (win pads, _G.SpeedsterAddWins, developer-product grants) and
-- every consumer that shows a number to the player (pad billboards, HUD) must
-- go through here, so the amount a player is promised is the amount the server
-- actually pays. Four different copies of this math used to disagree, which is
-- why the x2 pad advertised one figure and credited another.
--
-- Two independent systems stack multiplicatively:
--   * Permanent / temporary account multipliers (x2..x32 Wins, VIP, potions,
--     confetti and server-wide boosts) apply to EVERY wins reward.
--   * The x2 pads double their own reward for owners of the permanent x2 pads
--     gamepass (Services.DoubleWinsPad), on top of all of the above.

local WinsMath = {}

-- What an x2 pad pays over a normal one for owners of the x2 pads gamepass. Owning
-- a rung of the Wins ladder does not unlock the x2 pads.
WinsMath.PadDoubleMultiplier = 2

local function finite(value: any): number?
	local number = tonumber(value)
	if number == nil or number ~= number or number == math.huge or number == -math.huge then
		return nil
	end
	return number
end

local function multiplier(value: any): number
	local number = finite(value)
	if number == nil or number < 1 then
		return 1
	end
	return number
end

local function unixSeconds(value: any): number
	local number = finite(value)
	if number == nil or number < 0 then
		return 0
	end
	return number
end

local function attribute(holder: any, name: string): any
	if holder == nil or typeof(holder.GetAttribute) ~= "function" then
		return nil
	end
	local ok, value = pcall(holder.GetAttribute, holder, name)
	return ok and value or nil
end

export type Components = {
	permanent: number,
	vip: number,
	potion: number,
	confetti: number,
	serverBoost: number,
	total: number,
}

-- Breakdown of every multiplier that applies to a Wins reward.
-- `worldHolder` defaults to Workspace when running inside Roblox; tests pass a stub.
function WinsMath.GetComponents(player: any, worldHolder: any?): Components
	local world = worldHolder
	if world == nil and typeof(game) == "Instance" then
		world = game:GetService("Workspace")
	end

	local now = os.time()

	local permanent = multiplier(attribute(player, "PermanentWinsMultiplier"))
	local vip = multiplier(attribute(player, "VIPWinsMultiplier"))

	local potion = 1
	if now < unixSeconds(attribute(player, "PotionWinsExpireUnix")) then
		potion = multiplier(attribute(player, "PotionWinsMultiplier"))
		if potion <= 1 then
			potion = 2
		end
	end

	local confetti = 1
	if now < unixSeconds(attribute(player, "ConfettiBoostExpire")) then
		confetti = multiplier(attribute(player, "ConfettiWinMult"))
		if confetti <= 1 then
			confetti = 2
		end
	end

	local serverBoost = 1
	if now < unixSeconds(attribute(world, "ServerWinsBoostExpiresUnix")) then
		serverBoost = multiplier(attribute(world, "ServerWinsBoostMultiplier"))
		if serverBoost <= 1 then
			serverBoost = 2
		end
	end

	local total = permanent * vip * potion * confetti * serverBoost
	if finite(total) == nil or total < 1 then
		total = 1
	end

	return {
		permanent = permanent,
		vip = vip,
		potion = potion,
		confetti = confetti,
		serverBoost = serverBoost,
		total = total,
	}
end

function WinsMath.GetTotalMultiplier(player: any, worldHolder: any?): number
	return WinsMath.GetComponents(player, worldHolder).total
end

-- Reward for touching a pad, before account multipliers.
-- An x2 pad only pays double for an owner of the x2 pads gamepass; without it the
-- pad pays nothing and prompts the pass instead.
function WinsMath.GetPadBaseReward(baseReward: any, isDoublePad: boolean?, doubleEntitled: boolean?): number
	local base = finite(baseReward) or 0
	if base <= 0 then
		return 0
	end
	if isDoublePad == true and doubleEntitled == true then
		base *= WinsMath.PadDoubleMultiplier
	end
	return base
end

-- Final Wins credited for a reward, with every multiplier applied.
function WinsMath.GetFinalReward(baseReward: any, player: any, worldHolder: any?): number
	local base = finite(baseReward) or 0
	if base <= 0 then
		return 0
	end
	local amount = math.floor(base * WinsMath.GetTotalMultiplier(player, worldHolder))
	-- Stay inside the exact-integer range the profile codec can persist.
	return math.clamp(amount, 0, 9007199254740991)
end

-- Progression prices (Flight, World 2 stage teleports) scale with the player's
-- permanent multiplier so the ladder cannot buy its way past the run itself.
--
-- The exponent is what keeps the ladder honest at the top. Measured against the
-- live tables, the fixed unlock pool (7 auras + 7 trails + Flight) is 47,222,220
-- Wins and a full World 1 lap pays 1,157,020:
--
--   exponent 0  (no scaling)   x32 buys every unlock in the game in 1.3 laps
--   exponent 1  (full scaling) x32 pays 32x more, so the ladder buys nothing
--   exponent 0.5                x32 reaches Flight 5.7x faster, still ~3.8 laps
--
-- 0 kills the economy and 1 kills the purchase. The square root is the middle:
-- every rung is meaningfully faster than the one below it, and no rung is free.
-- Cosmetics deliberately do NOT go through here - accelerating those is exactly
-- what the player paid for.
WinsMath.DefaultProgressionPriceExponent = 0.5

-- `exponent` defaults to DefaultProgressionPriceExponent; pass 0 to disable.
function WinsMath.GetProgressionPrice(baseCost: any, totalMultiplier: any, exponent: any?): number
	local base = finite(baseCost)
	if base == nil or base <= 0 then
		return 0
	end

	local scale = multiplier(totalMultiplier)
	local power = finite(exponent)
	if power == nil or power < 0 then
		power = WinsMath.DefaultProgressionPriceExponent
	end

	local priced = base
	if scale > 1 and power > 0 then
		local factor = finite(scale ^ power)
		if factor ~= nil and factor >= 1 then
			priced = base * factor
		end
	end

	local rounded = math.ceil(priced)
	if finite(rounded) == nil or rounded < 0 then
		return math.floor(base)
	end
	return math.clamp(rounded, 0, 9007199254740991)
end

-- Convenience wrapper: prices a progression unlock for `player` directly.
-- Only the PERMANENT multiplier counts. Potions and confetti are timed boosts;
-- pricing against them would make an unlock cost more for ten minutes and then
-- snap back, and a player who banked Wins under a potion would find the price
-- moved underneath them.
function WinsMath.GetProgressionPriceFor(baseCost: any, player: any, exponent: any?): number
	local permanent = multiplier(attribute(player, "PermanentWinsMultiplier"))
	return WinsMath.GetProgressionPrice(baseCost, permanent, exponent)
end

-- What a pad billboard should advertise for this player, entitlement aside:
-- x2 pads always show the doubled figure so the offer is legible before buying.
function WinsMath.GetAdvertisedPadReward(baseReward: any, player: any, isDoublePad: boolean?, worldHolder: any?): number
	return WinsMath.GetFinalReward(
		WinsMath.GetPadBaseReward(baseReward, isDoublePad, true),
		player,
		worldHolder
	)
end

return WinsMath
