--!strict
-- SpeedFormula.luau
-- Lógica matemática pura para cálculos de velocidad de caminar y multiplicadores.

local SpeedFormula = {}

local BASE_WALK_SPEED = 16
local MIN_WALK_SPEED = 16
local MAX_WALK_SPEED = 2000

function SpeedFormula.CalculateWalkSpeed(rawSpeed: number, stageMultiplier: number?): number
	local speed = math.max(0, tonumber(rawSpeed) or 0)
	local stageMult = math.max(1, tonumber(stageMultiplier) or 1)

	-- Curva logarítmica/progresiva de velocidad en Roblox
	local computed = BASE_WALK_SPEED + (math.sqrt(speed) * 1.5 * stageMult)
	return math.clamp(computed, MIN_WALK_SPEED, MAX_WALK_SPEED)
end

function SpeedFormula.CalculateGain(baseAmount: number, multipliers: { number }?): number
	local total = math.max(0, tonumber(baseAmount) or 0)
	if multipliers then
		for _, mult in ipairs(multipliers) do
			if mult and mult > 0 then
				total *= mult
			end
		end
	end
	return total
end

return SpeedFormula
