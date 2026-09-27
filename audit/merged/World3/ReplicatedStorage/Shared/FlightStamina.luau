--!strict
-- FlightStamina.luau
-- The cost of flying, in one place.
--
-- Flight used to read as permanent because only the powered climb drew stamina:
-- a player burned about a second going up and then glided for free, and the suit
-- ladder made it worse - a 60-stamina suit bought several times the airtime of a
-- 17-stamina one for the same input.
--
-- Everything here is a PERCENTAGE of the player's own maximum stamina, with only a
-- tiny absolute floor so the numbers never reach zero.
--
-- The first attempt used `max(flat, percent)` and that was worse than the original
-- bug: a flat 14/s against the FlashSuit's 5-point bar drained it in a third of a
-- second, and a flat "need 5 stamina to take off" meant the FlashSuit needed 100%
-- of its bar to fly at all - which is exactly the "it only works on a full bar"
-- report. Percentages give every suit the same flight, which is what a stamina
-- upgrade should buy: longer sprints, not a different flight mechanic.

local FlightStamina = {}

local function positive(value: any, fallback: number): number
	local number = tonumber(value)
	if number == nil or number ~= number or number == math.huge or number < 0 then
		return fallback
	end
	return number
end

local function drain(flat: number, percent: number, maxStamina: number): number
	return math.max(flat, percent * math.max(0, maxStamina))
end

function FlightStamina.PoweredDrainPerSecond(config: any, maxStamina: number): number
	return drain(
		positive(config.AbilityFlightDrainFloorPerSecond, 0.5),
		positive(config.AbilityFlightDrainPercentPerSecond, 0.35),
		maxStamina
	)
end

function FlightStamina.GlideDrainPerSecond(config: any, maxStamina: number): number
	return drain(
		positive(config.AbilityFlightGlideDrainFloorPerSecond, 0.2),
		positive(config.AbilityFlightGlideDrainPercentPerSecond, 0.14),
		maxStamina
	)
end

-- How much stamina it takes to lift off, and to keep the powered climb going.
-- A share of the player's own bar, never a flat number.
function FlightStamina.MinimumToPower(config: any, maxStamina: number): number
	return drain(
		positive(config.AbilityFlightMinimumStaminaFloor, 0.5),
		positive(config.AbilityFlightMinimumStaminaPercent, 0.12),
		maxStamina
	)
end

-- One simulation step. `powered` is the climb, otherwise the player is gliding.
-- Returns the new stamina and whether the powered climb just ran out.
function FlightStamina.Step(config: any, stamina: number, maxStamina: number, dt: number, powered: boolean): (number, boolean)
	local rate = if powered
		then FlightStamina.PoweredDrainPerSecond(config, maxStamina)
		else FlightStamina.GlideDrainPerSecond(config, maxStamina)
	local next = math.max(0, stamina - rate * math.max(0, dt))
	return next, powered and next <= 0
end

-- Longest possible time in the air from a full bar: climb until the powered
-- minimum, then glide the remainder. Used by the balance test.
function FlightStamina.MaxAirtimeSeconds(config: any, maxStamina: number): number
	local minimumToPower = FlightStamina.MinimumToPower(config, maxStamina)
	local powered = FlightStamina.PoweredDrainPerSecond(config, maxStamina)
	local glide = FlightStamina.GlideDrainPerSecond(config, maxStamina)
	if glide <= 0 then
		return math.huge
	end
	-- Cheapest airtime per stamina point is pure gliding, so the worst case for
	-- balance is the shortest possible climb followed by an all-glide descent.
	return maxStamina / glide + (math.min(minimumToPower, maxStamina) / powered)
end

return FlightStamina
