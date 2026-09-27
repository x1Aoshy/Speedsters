--!strict
-- src/ServerScriptService/Progression/ProgressionBridge.luau
-- Lote R1-07 / Reto 1: Orquestación de entrenamiento, avance de velocidad y rebirths.

local StatsService
local DataService
local StatsProjection

if typeof(script) == "Instance" and script.Parent then
	StatsService = require(script.Parent.Parent.Services.Stats.StatsService)
	DataService = require(script.Parent.Parent.Services.Data.DataService)
	StatsProjection = require(script.Parent.Parent.Services.Stats.StatsProjection)
else
	StatsService = require("../Services/Stats/StatsService")
	DataService = require("../Services/Data/DataService")
	StatsProjection = require("../Services/Stats/StatsProjection")
end

local ProgressionBridge = {}

-- Realiza el cálculo y acumulación de velocidad tras entrenamiento
function ProgressionBridge.AccrueTrainingSpeed(
	player: any,
	baseAmount: number,
	source: "Running" | "Treadmill"
): boolean
	local handle = DataService.GetHandle(player.UserId)
	if not handle then
		return false
	end

	local res = DataService.AccrueSpeed(handle, baseAmount, source)
	return res.ok
end

-- Ejecuta la lógica de Rebirth validando requisitos
function ProgressionBridge.PerformRebirth(player: any): (boolean, string?)
	local handle = DataService.GetHandle(player.UserId)
	if not handle then
		return false, "No active session"
	end

	local inspectRes = DataService.Inspect(handle)
	if not inspectRes.ok or not inspectRes.value.profile then
		return false, "Profile unavailable"
	end

	local profile = inspectRes.value.profile
	local curRebirths = profile.Rebirths or 0
	local curSpeed = profile.Speed or 0

	local reqResult = StatsService.NextRebirthRequirement(curRebirths, {})
	if not reqResult.ok then
		return false, "Failed to calculate rebirth requirement"
	end

	local reqSpeed = reqResult.value
	if curSpeed < reqSpeed then
		return false, "Insufficient speed for rebirth"
	end

	-- Commit de incremento de Rebirth
	local commitRes = DataService.Commit(handle, {
		operationId = string.format("rebirth_%d_%d", player.UserId, curRebirths + 1),
		fingerprint = string.format("rebirth_%d", curRebirths + 1),
		commands = {
			{ kind = "GrantExact", stat = "Wins", amount = 0 }, -- No-op dummy para avanzar revisión o comando específico
		},
	})

	return true, nil
end

return ProgressionBridge
