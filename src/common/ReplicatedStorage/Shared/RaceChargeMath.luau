--!strict
-- ReplicatedStorage/Shared/RaceChargeMath.luau — Update 4 race charge-start minigame (pure).
-- The gauge g in [0, 1] is piecewise linear and is integrated exactly between events (press,
-- release, overheat, end of the vent, the floor at 0), so it does not depend on the frame rate:
-- the client's gauge and the server's replay of the same edges give the same numbers.
--   held: +Fill/s; released: -Decay/s (floor 0); reaching 1 while held = overheat: the gauge
--   vents at -Vent/s for VentSeconds ignoring input, then follows the held state again.
-- Scoring looks at the last Window seconds before GO: ZoneT / CoreT are the exact times spent
-- inside each band, Q = 0.5*ZoneT/Window + 0.5*CoreT/Window, and G is the gauge at GO.
-- Edges are server-clock times, odd index = press, even index = release.
local U4: any = if typeof(script) == "Instance"
	then require((script :: any).Parent:WaitForChild("Update4Config", 10))
	else require("./Update4Config")

local CHARGE = U4.Race.Charge

local RaceChargeMath = {}
RaceChargeMath.Grades = { "Perfect", "Good", "Ok", "Stall" }

export type Result = {
	G: number,
	Held: boolean,
	Venting: boolean,
	ZoneT: number,
	CoreT: number,
	Q: number,
	HeldSeconds: number,
	OverheatAt: number?,
	VentedLate: boolean,
	Assist: boolean,
}

-- Zone and core bands; the assist (after repeated misses) widens both.
function RaceChargeMath.Bands(params: any?, assist: boolean?): (number, number, number, number)
	local p = params or CHARGE
	if assist then
		return p.AssistZone[1], p.AssistZone[2], p.AssistCore[1], p.AssistCore[2]
	end
	return p.ZoneLo, p.ZoneHi, p.CoreLo, p.CoreHi
end

-- Time in [a, b] during which the line g(t) = g0 + rate*(t - t0) stays inside [lo, hi].
local function timeInBand(t0: number, g0: number, rate: number, a: number, b: number, lo: number, hi: number): number
	if b <= a then
		return 0
	end
	local ga = g0 + rate * (a - t0)
	if math.abs(rate) < 1e-12 then
		return if ga >= lo and ga <= hi then b - a else 0
	end
	local t1 = a + (lo - ga) / rate
	local t2 = a + (hi - ga) / rate
	if t1 > t2 then
		t1, t2 = t2, t1
	end
	return math.max(0, math.min(b, t2) - math.max(a, t1))
end

local function finite(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

function RaceChargeMath.Evaluate(edges: { number }?, openAt: number, goAt: number, at: number, params: any?, assist: boolean?): Result
	local p = params or CHARGE
	local zoneLo, zoneHi, coreLo, coreHi = RaceChargeMath.Bands(p, assist)
	local windowStart = goAt - p.Window
	local stallStart = goAt - p.StallWindow
	local stop = math.min(at, goAt)
	local list = if type(edges) == "table" then edges else {}

	local g, held, venting, ventUntil = 0, false, false, -math.huge
	local zoneT, coreT, heldSeconds = 0, 0, 0
	local overheatAt: number? = nil
	local ventedLate = false
	local t = openAt
	local index = 1

	-- Edges at or before the opening only set the held state.
	while index <= #list and finite(list[index]) and list[index] <= t do
		held = index % 2 == 1
		index += 1
	end

	local guard = 0
	while t < stop do
		guard += 1
		if guard > 10000 then
			break -- malformed input can never hang a server
		end
		local nextEdge = if index <= #list and finite(list[index]) then math.max(t, list[index]) else math.huge
		local segmentEnd = math.min(stop, nextEdge)
		if venting then
			segmentEnd = math.min(segmentEnd, ventUntil)
		end
		local rate = if venting then -p.Vent elseif held then p.Fill else -p.Decay
		local overheats = false
		if not venting and held then
			local full = t + (1 - g) / p.Fill
			if full <= segmentEnd then
				segmentEnd, overheats = full, true
			end
		end
		-- One linear piece, split where a falling gauge reaches the floor.
		local pieceEnd = segmentEnd
		if rate < 0 and g + rate * (segmentEnd - t) < 0 then
			pieceEnd = t - g / rate
		end
		zoneT += timeInBand(t, g, rate, math.max(t, windowStart), math.min(pieceEnd, goAt), zoneLo, zoneHi)
		coreT += timeInBand(t, g, rate, math.max(t, windowStart), math.min(pieceEnd, goAt), coreLo, coreHi)
		if pieceEnd < segmentEnd then
			zoneT += timeInBand(pieceEnd, 0, 0, math.max(pieceEnd, windowStart), math.min(segmentEnd, goAt), zoneLo, zoneHi)
			coreT += timeInBand(pieceEnd, 0, 0, math.max(pieceEnd, windowStart), math.min(segmentEnd, goAt), coreLo, coreHi)
		end
		if held and not venting then
			heldSeconds += segmentEnd - t
		end
		if venting and segmentEnd > stallStart and t < goAt then
			ventedLate = true
		end
		g = math.clamp(g + rate * (segmentEnd - t), 0, 1)
		t = segmentEnd
		if overheats then
			g, venting, ventUntil, overheatAt = 1, true, t + p.VentSeconds, t
			if t >= stallStart and t <= goAt then
				ventedLate = true
			end
		elseif venting and t >= ventUntil then
			venting = false
		end
		while index <= #list and finite(list[index]) and list[index] <= t do
			held = index % 2 == 1
			index += 1
		end
		while index <= #list and not finite(list[index]) do
			index += 1 -- a NaN/inf edge is skipped (the judge never stores one)
		end
	end

	local q = 0.5 * zoneT / p.Window + 0.5 * coreT / p.Window
	return {
		G = g,
		Held = held,
		Venting = venting,
		ZoneT = zoneT,
		CoreT = coreT,
		Q = q,
		HeldSeconds = heldSeconds,
		OverheatAt = overheatAt,
		VentedLate = ventedLate,
		Assist = assist == true,
	}
end

-- First match: Stall, Perfect, Good, Ok. grace (newcomers) turns Stall into Ok; assist never
-- stalls and tops out at Good.
function RaceChargeMath.Outcome(result: Result, params: any?, grace: boolean?, assist: boolean?): string
	local p = params or CHARGE
	local assisted = assist == true or result.Assist == true
	local zoneLo, zoneHi = RaceChargeMath.Bands(p, assisted)
	local g, q = result.G, result.Q
	local inZone = g >= zoneLo and g <= zoneHi
	if not assisted and (result.VentedLate or g >= p.StallAt) then
		return if grace then "Ok" else "Stall"
	end
	if not assisted and inZone and q >= p.PerfectQ then
		return "Perfect"
	end
	if (inZone and q >= p.GoodQ) or (g >= p.AltGoodG and q >= p.AltGoodQ) then
		return "Good"
	end
	return "Ok"
end

-- The launch target multiplier tau seconds after GO.
--   Perfect 1.45 until 1.2 s, then linear to 1.0 at 2.5 s; Good 1.22 until 1.0 s, 1.0 at 2.0 s;
--   Stall 0 until 0.45 s, then 0 -> 1 by 0.8 s; Ok (and anything else) 1.
function RaceChargeMath.StartMultiplier(grade: string?, tau: number, params: any?): number
	local p = params or CHARGE
	local boost = grade and p.Boost[grade]
	if not boost then
		return 1
	end
	if grade == "Stall" then
		local hold, finish = boost[1], boost[2]
		if tau < hold then
			return 0
		elseif tau < finish then
			return (tau - hold) / (finish - hold)
		end
		return 1
	end
	local peak, hold, finish = boost[1], boost[2], boost[3]
	if tau < hold then
		return peak
	elseif tau < finish then
		return peak + (1 - peak) * (tau - hold) / (finish - hold)
	end
	return 1
end

-- Integral of (StartMultiplier - 1) over tau >= 0: the start's worth in seconds of cruise.
function RaceChargeMath.BoostDistanceSeconds(grade: string?, params: any?): number
	local p = params or CHARGE
	local boost = grade and p.Boost[grade]
	if not boost then
		return 0
	end
	if grade == "Stall" then
		return -boost[1] - (boost[2] - boost[1]) * 0.5
	end
	return (boost[1] - 1) * boost[2] + (boost[1] - 1) * (boost[3] - boost[2]) * 0.5
end

function RaceChargeMath.Launch(grade: string?, params: any?): number
	local p = params or CHARGE
	return tonumber(grade and p.Launch[grade]) or 0
end

function RaceChargeMath.StaminaCost(heldSeconds: number, params: any?): number
	local p = params or CHARGE
	return math.max(0, tonumber(heldSeconds) or 0) * p.CostPerHeldSecond
end

return RaceChargeMath
