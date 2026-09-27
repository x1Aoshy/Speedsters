--!strict
-- src/ServerScriptService/Services/Buffs/BuffRules.luau
-- Lote R1-08 / Reto 1: Reglas de validación y multiplicadores canónicos para pociones y buffs.

export type BuffKind = "SpeedPotion" | "WinsPotion"

export type BuffGrant = {
	kind: BuffKind,
	addedSeconds: number,
	multiplier: number,
}

local BuffRules = {}

local DEFAULT_MULTIPLIERS: { [BuffKind]: number } = {
	SpeedPotion = 2.0,
	WinsPotion = 2.0,
}

local MAX_POTION_SECONDS = 86400 * 30 -- Máximo 30 días acumulados

function BuffRules.GetDefaultMultiplier(kind: BuffKind): number
	return DEFAULT_MULTIPLIERS[kind] or 1.0
end

function BuffRules.ValidateGrant(grant: BuffGrant): (boolean, string?)
	if grant.kind ~= "SpeedPotion" and grant.kind ~= "WinsPotion" then
		return false, "Invalid buff kind: " .. tostring(grant.kind)
	end

	local seconds = grant.addedSeconds
	if typeof(seconds) ~= "number" or seconds ~= seconds or seconds <= 0 or seconds == math.huge then
		return false, "Invalid added seconds"
	end

	local mult = grant.multiplier
	if typeof(mult) ~= "number" or mult ~= mult or mult <= 0 or mult == math.huge then
		return false, "Invalid multiplier"
	end

	return true, nil
end

function BuffRules.ClampRemaining(seconds: number): number
	return math.clamp(math.floor(seconds), 0, MAX_POTION_SECONDS)
end

return BuffRules
