--!strict
-- src/ServerScriptService/Services/Stats/StatsService.luau
-- Lote R1-03 / Revisión 3: Servicio puro de cálculo matemático de stats (Speed, Wins, WalkSpeed, Rebirths).
-- REGLAS ARQUITECTÓNICAS:
-- 1. Funcionamiento puramente funcional: sin dependencias de DataStore, Players, attributes ni reloj.
-- 2. Sin efectos secundarios (no muta tablas de entrada).
-- 3. Mismas entradas producen exactamente las mismas salidas (determinismo 100%).
-- 4. Cumple con los hallazgos B01, B02, B03 y el contrato de Types.luau.

local StatsService = {}

export type StatValues = {
	speed: number,
	wins: number,
	rebirths: number,
	speedCarry: number,
}

export type GainMultipliers = {
	permanent: number?,
	global: number?,
	trail: number?,
	aura: number?,
	upgrade: number?,
	gamepass: number?,
	suit: number?,
	rebirth: number?,
	vip: number?,
	potion: number?,
	serverBoost: number?,
	-- The admin disco: x2 for everyone during the party, x100 while dancing.
	disco: number?,
}

export type MovementFactors = {
	worldMultiplier: number,
	selectorMultiplier: number,
	boostMultiplier: number,
	permanentMultiplier: number,
	instantMovementControllerEnabled: boolean?,
	isBoosting: boolean?,
}

export type SpeedRules = {
	startingSpeed: number,
	maxStoredSpeed: number,
	useSmoothRealSpeedFormula: boolean,
	realWalkSpeedMin: number,
	referenceDisplayedSpeed: number,
	walkSpeedAtReference: number,
	curve: number,
	baseWalkSpeed: number,
	speedToWalkSpeedMultiplier: number,
	useWalkSpeedCap: boolean,
	maxWalkSpeed: number,
}

export type SpeedGainResult = {
	values: StatValues,
	wholeRequested: number,
	actualAdded: number,
}

export type WinsGainInput = {
	amount: number,
	mode: "Reward" | "Exact",
	permanentMultiplier: number?,
	vipMultiplier: number?,
	potionMultiplier: number?,
	eventMultiplier: number?,
}

export type WalkSpeedDetails = {
	actualWalkSpeed: number,
	maxWalkSpeed: number,
	selectedWalkSpeed: number,
	mode: string,
	selectorMultiplier: number,
}

export type ServiceError = {
	code: string,
	message: string,
	retryable: boolean,
	operationId: string?,
}

export type Result<T> = { ok: true, value: T } | { ok: false, error: ServiceError }

-- Constantes canónicas del juego (Config.luau)
local MIN_WALK_SPEED = 8
local REF_DISPLAYED_SPEED = 3.37e15
local REF_WALK_SPEED = 300
local SPEED_CURVE = 2
-- The live adapter supplies Config explicitly; compatibility callers use it too.
local WORLD2_MULTIPLIER = if typeof(script) == "Instance"
	then tonumber(require(game:GetService("ReplicatedStorage").Shared.Config).World2WalkSpeedMultiplier) or (1 / 3)
	else 1 / 3
local BOOST_MULTIPLIER = 1.7
local MAX_SAFE_INTEGER = 9007199254740991
local MAX_STORED_SPEED = 1e50

-- Config:385 WalkSpeedSelectorMultipliers
local CANONICAL_SELECTOR_MULTIPLIERS = {
	Green = 0.20,
	Yellow = 17 / 30,
	Red = 1.00,
}

local DEFAULT_SPEED_RULES: SpeedRules = {
	startingSpeed = 1,
	maxStoredSpeed = MAX_STORED_SPEED,
	useSmoothRealSpeedFormula = true,
	realWalkSpeedMin = MIN_WALK_SPEED,
	referenceDisplayedSpeed = REF_DISPLAYED_SPEED,
	walkSpeedAtReference = REF_WALK_SPEED,
	curve = SPEED_CURVE,
	baseWalkSpeed = 8,
	speedToWalkSpeedMultiplier = 0.08,
	useWalkSpeedCap = false,
	maxWalkSpeed = 120,
}

local function isBadNumber(n: number): boolean
	return n ~= n or n == math.huge or n == -math.huge
end

local function cleanSpeed(v: any, minSpeed: number?, maxSpeed: number?): number
	local minVal = minSpeed or 1
	local maxVal = maxSpeed or MAX_STORED_SPEED
	local n = tonumber(v)
	if not n or isBadNumber(n) then
		return maxVal
	end
	if n < minVal then
		return minVal
	end
	if n > maxVal then
		return maxVal
	end
	return n
end

local function cleanInt(v: any): number
	local n = tonumber(v)
	if not n or isBadNumber(n) or n < 0 then
		return 0
	end
	return math.floor(n)
end

local function validateOptionalMultiplier(v: any, fieldName: string): (boolean, number)
	if v == nil then
		return true, 1
	end
	local n = tonumber(v)
	if not n or isBadNumber(n) or n < 0 then
		return false, 0
	end
	return true, n
end

-- ============================================================================
-- 1. CÁLCULO DE WALKSPEED (VELOCIDAD DE CAMINAR)
-- ============================================================================

function StatsService.CalculateSmoothWalkSpeed(speedValue: number, rules: SpeedRules?): number
	local r = rules or DEFAULT_SPEED_RULES
	local minSpeed = r.realWalkSpeedMin
	local refDisplayed = r.referenceDisplayedSpeed
	local walkSpeedAtRef = r.walkSpeedAtReference
	local curve = r.curve

	local speed = math.max(1, tonumber(speedValue) or 1)
	if isBadNumber(speed) then
		speed = 1
	end

	local progress = math.log10(speed) / math.log10(refDisplayed)
	progress = math.max(0, progress) ^ curve

	local walkSpeed = minSpeed + (progress * (walkSpeedAtRef - minSpeed))
	return math.max(minSpeed, walkSpeed)
end

function StatsService.CalculateMaxWalkSpeed(speedValue: number, isWorld2: boolean?, rules: SpeedRules?): number
	local r = rules or DEFAULT_SPEED_RULES
	local walkSpeed: number

	if r.useSmoothRealSpeedFormula then
		walkSpeed = StatsService.CalculateSmoothWalkSpeed(speedValue, r)
	else
		local speed = math.max(1, tonumber(speedValue) or 1)
		walkSpeed = r.baseWalkSpeed + (speed * r.speedToWalkSpeedMultiplier)
		if r.useWalkSpeedCap then
			walkSpeed = math.min(walkSpeed, r.maxWalkSpeed)
		end
	end

	if isBadNumber(walkSpeed) then
		walkSpeed = r.realWalkSpeedMin or r.baseWalkSpeed
	end

	if isWorld2 == true then
		local worldScale = math.clamp(WORLD2_MULTIPLIER, 0.01, 1)
		walkSpeed *= worldScale
	end

	return walkSpeed
end

function StatsService.CalculateWalkSpeedDetails(
	speedValue: number,
	isWorld2: boolean?,
	mode: string?,
	isBoosting: boolean?,
	rules: SpeedRules?,
	selectorMultipliers: { [string]: number }?,
	instantMovementControllerEnabled: boolean?
): WalkSpeedDetails
	local maxWalkSpeed = StatsService.CalculateMaxWalkSpeed(speedValue, isWorld2, rules)
	local multipliers = selectorMultipliers or CANONICAL_SELECTOR_MULTIPLIERS
	local defaultMode = "Red"

	local selectedMode = tostring(mode or defaultMode)
	local selectorMultiplier = multipliers[selectedMode]

	if not selectorMultiplier or selectorMultiplier <= 0 or isBadNumber(selectorMultiplier) then
		selectedMode = defaultMode
		selectorMultiplier = multipliers[selectedMode] or 1.0
	end

	local selectedWalkSpeed = maxWalkSpeed * selectorMultiplier
	if isBadNumber(selectedWalkSpeed) or selectedWalkSpeed < 0 then
		selectedWalkSpeed = maxWalkSpeed
		selectedMode = defaultMode
		selectorMultiplier = 1.0
	end

	local actualWalkSpeed = selectedWalkSpeed

	local instantMovement = instantMovementControllerEnabled
	if instantMovement == nil then
		instantMovement = true
	end

	if isBoosting == true and not instantMovement then
		actualWalkSpeed *= BOOST_MULTIPLIER
	end

	return {
		actualWalkSpeed = actualWalkSpeed,
		maxWalkSpeed = maxWalkSpeed,
		selectedWalkSpeed = selectedWalkSpeed,
		mode = selectedMode,
		selectorMultiplier = selectorMultiplier,
	}
end

-- Types.luau: CalculateWalkSpeed(rawSpeed, rules, factors) -> Result<number>
function StatsService.CalculateWalkSpeed(
	rawSpeed: number,
	rules: SpeedRules?,
	factors: MovementFactors?
): Result<number>
	local raw = tonumber(rawSpeed)
	if not raw or isBadNumber(raw) or raw < 0 then
		return {
			ok = false,
			error = {
				code = "InvalidInput",
				message = "rawSpeed must be a finite non-negative number",
				retryable = false,
			},
		}
	end

	local r = rules or DEFAULT_SPEED_RULES
	local f = factors or {
		worldMultiplier = 1,
		selectorMultiplier = 1,
		boostMultiplier = BOOST_MULTIPLIER,
		permanentMultiplier = 1,
	}

	-- Validación de factores
	if isBadNumber(f.boostMultiplier) or isBadNumber(f.worldMultiplier) or isBadNumber(f.selectorMultiplier) then
		return {
			ok = false,
			error = {
				code = "InvalidInput",
				message = "Movement factors must be finite numbers",
				retryable = false,
			},
		}
	end

	local speedValue = cleanSpeed(raw, r.startingSpeed, r.maxStoredSpeed)
	local walkSpeed: number

	if r.useSmoothRealSpeedFormula then
		walkSpeed = StatsService.CalculateSmoothWalkSpeed(speedValue, r)
	else
		walkSpeed = r.baseWalkSpeed + (speedValue * r.speedToWalkSpeedMultiplier)
		if r.useWalkSpeedCap then
			walkSpeed = math.min(walkSpeed, r.maxWalkSpeed)
		end
	end

	local worldScale = math.clamp(f.worldMultiplier or 1, 0.01, 1)
	walkSpeed *= worldScale

	local sel = f.selectorMultiplier
	if not sel or sel <= 0 or isBadNumber(sel) then
		sel = 1.0
	end
	walkSpeed *= sel

	local instantMovement = f.instantMovementControllerEnabled
	if instantMovement == nil then
		instantMovement = true
	end

	if f.isBoosting == true and not instantMovement then
		walkSpeed *= (f.boostMultiplier or BOOST_MULTIPLIER)
	end

	if isBadNumber(walkSpeed) or walkSpeed == math.huge or walkSpeed < 0 then
		return {
			ok = false,
			error = {
				code = "InvalidInput",
				message = "Calculated walk speed is non-finite",
				retryable = false,
			},
		}
	end

	return {
		ok = true,
		value = walkSpeed,
	}
end

-- ============================================================================
-- 2. GANANCIA DE VELOCIDAD ACUMULATIVA (SPEED GAIN & SPEEDCARRY)
-- ============================================================================

-- Types.luau: CalculateSpeedGain(before, baseAmount, multipliers, rules) -> Result<SpeedGainResult>
function StatsService.CalculateSpeedGain(
	before: StatValues,
	baseAmount: number,
	multipliers: GainMultipliers?,
	rules: SpeedRules?
): Result<SpeedGainResult>
	if type(before) ~= "table" then
		return {
			ok = false,
			error = {
				code = "InvalidInput",
				message = "before must be a StatValues table",
				retryable = false,
			},
		}
	end

	local rawBase = tonumber(baseAmount)
	-- B03: Rechazar montos infinitos o NaN
	if not rawBase or isBadNumber(rawBase) then
		return {
			ok = false,
			error = {
				code = "InvalidInput",
				message = "baseAmount must be a finite number",
				retryable = false,
			},
		}
	end

	local r = rules or DEFAULT_SPEED_RULES
	local maxStored = r.maxStoredSpeed or MAX_STORED_SPEED
	local startSpeed = r.startingSpeed or 1

	local curSpeed = cleanSpeed(before.speed, startSpeed, maxStored)
	local curWins = tonumber(before.wins) or 0
	local curRebirths = tonumber(before.rebirths) or 0
	local curCarry = tonumber(before.speedCarry) or 0
	if isBadNumber(curCarry) or curCarry < 0 then
		curCarry = 0
	end

	-- B01: Si baseAmount <= 0, preservar wins y rebirths
	if rawBase <= 0 then
		return {
			ok = true,
			value = {
				values = {
					speed = curSpeed,
					wins = curWins,
					rebirths = curRebirths,
					speedCarry = curCarry,
				},
				wholeRequested = 0,
				actualAdded = 0,
			},
		}
	end

	-- Validar factores de multiplicadores explícitos
	local m = multipliers or {}
	local okM, perm = validateOptionalMultiplier(m.permanent, "permanent")
	if not okM then return { ok = false, error = { code = "InvalidInput", message = "permanent multiplier must be finite non-negative", retryable = false } } end
	perm = math.max(1, perm)

	local okG, glob = validateOptionalMultiplier(m.global, "global")
	if not okG then return { ok = false, error = { code = "InvalidInput", message = "global multiplier must be finite non-negative", retryable = false } } end

	local okT, trail = validateOptionalMultiplier(m.trail, "trail")
	if not okT then return { ok = false, error = { code = "InvalidInput", message = "trail multiplier must be finite non-negative", retryable = false } } end

	local okA, aura = validateOptionalMultiplier(m.aura, "aura")
	if not okA then return { ok = false, error = { code = "InvalidInput", message = "aura multiplier must be finite non-negative", retryable = false } } end

	local okU, upg = validateOptionalMultiplier(m.upgrade, "upgrade")
	if not okU then return { ok = false, error = { code = "InvalidInput", message = "upgrade multiplier must be finite non-negative", retryable = false } } end

	local okP, pass = validateOptionalMultiplier(m.gamepass, "gamepass")
	if not okP then return { ok = false, error = { code = "InvalidInput", message = "gamepass multiplier must be finite non-negative", retryable = false } } end

	local okS, suit = validateOptionalMultiplier(m.suit, "suit")
	if not okS then return { ok = false, error = { code = "InvalidInput", message = "suit multiplier must be finite non-negative", retryable = false } } end

	local okR, reb = validateOptionalMultiplier(m.rebirth, "rebirth")
	if not okR then return { ok = false, error = { code = "InvalidInput", message = "rebirth multiplier must be finite non-negative", retryable = false } } end

	local okV, vip = validateOptionalMultiplier(m.vip, "vip")
	if not okV then return { ok = false, error = { code = "InvalidInput", message = "vip multiplier must be finite non-negative", retryable = false } } end

	local okPot, pot = validateOptionalMultiplier(m.potion, "potion")
	if not okPot then return { ok = false, error = { code = "InvalidInput", message = "potion multiplier must be finite non-negative", retryable = false } } end

	local okB, boost = validateOptionalMultiplier(m.serverBoost, "serverBoost")
	if not okB then return { ok = false, error = { code = "InvalidInput", message = "serverBoost multiplier must be finite non-negative", retryable = false } } end

	local okD, disco = validateOptionalMultiplier(m.disco, "disco")
	if not okD then return { ok = false, error = { code = "InvalidInput", message = "disco multiplier must be finite non-negative", retryable = false } } end
	-- It only ever adds: a pad never slows anyone.
	disco = math.max(1, disco)

	-- B03: Manejar cualquier factor cero antes de calcular el producto
	if glob == 0 or trail == 0 or aura == 0 or upg == 0 or pass == 0 or suit == 0 or reb == 0 or vip == 0 or pot == 0 or boost == 0 then
		return {
			ok = true,
			value = {
				values = {
					speed = curSpeed,
					wins = curWins,
					rebirths = curRebirths,
					speedCarry = curCarry,
				},
				wholeRequested = 0,
				actualAdded = 0,
			},
		}
	end

	local totalGainMult = glob * trail * aura * upg * pass * suit * reb * vip
	local gain = (rawBase * perm) * totalGainMult * pot * boost * disco

	if isBadNumber(gain) or gain <= 0 then
		return {
			ok = true,
			value = {
				values = {
					speed = curSpeed,
					wins = curWins,
					rebirths = curRebirths,
					speedCarry = curCarry,
				},
				wholeRequested = 0,
				actualAdded = 0,
			},
		}
	end

	local carry = curCarry + gain
	local whole = math.floor(carry)
	local hasAddedWhole = whole >= 1

	local newSpeed = curSpeed
	local actualAdded = 0
	if hasAddedWhole then
		local candidate = cleanSpeed(curSpeed + whole, startSpeed, maxStored)
		actualAdded = candidate - curSpeed
		newSpeed = candidate
		carry -= whole
	end

	return {
		ok = true,
		value = {
			values = {
				speed = newSpeed,
				wins = curWins,
				rebirths = curRebirths,
				speedCarry = carry,
			},
			wholeRequested = whole,
			actualAdded = actualAdded,
		},
	}
end

-- ============================================================================
-- 3. GANANCIA DE VICTORIAS (WINS GAIN)
-- ============================================================================

-- Types.luau: CalculateWinsGain(before: StatValues, input: WinsGainInput) -> Result<StatValues>
function StatsService.CalculateWinsGain(
	before: StatValues,
	input: WinsGainInput
): Result<StatValues>
	if type(before) ~= "table" then
		return {
			ok = false,
			error = {
				code = "InvalidInput",
				message = "before must be a StatValues table",
				retryable = false,
			},
		}
	end
	if type(input) ~= "table" then
		return {
			ok = false,
			error = {
				code = "InvalidInput",
				message = "input must be a WinsGainInput table",
				retryable = false,
			},
		}
	end

	local curWins = tonumber(before.wins) or 0
	if isBadNumber(curWins) or curWins < 0 then
		curWins = 0
	end
	curWins = math.floor(curWins)

	local rawAmount = tonumber(input.amount)
	-- B03: Rechazar no finitos o negativos
	if not rawAmount or isBadNumber(rawAmount) or rawAmount < 0 then
		return {
			ok = false,
			error = {
				code = "InvalidInput",
				message = "amount must be a finite non-negative number",
				retryable = false,
			},
		}
	end

	if rawAmount == 0 then
		return {
			ok = true,
			value = {
				speed = before.speed,
				wins = curWins,
				rebirths = before.rebirths,
				speedCarry = before.speedCarry,
			},
		}
	end

	local gain: number
	if input.mode == "Exact" then
		gain = math.floor(rawAmount)
	else
		-- Validar factores explícitos
		local okPerm, perm = validateOptionalMultiplier(input.permanentMultiplier, "permanentMultiplier")
		if not okPerm then return { ok = false, error = { code = "InvalidInput", message = "permanentMultiplier must be finite non-negative", retryable = false } } end

		local okVip, vip = validateOptionalMultiplier(input.vipMultiplier, "vipMultiplier")
		if not okVip then return { ok = false, error = { code = "InvalidInput", message = "vipMultiplier must be finite non-negative", retryable = false } } end

		local okEvent, event = validateOptionalMultiplier(input.eventMultiplier, "eventMultiplier")
		if not okEvent then return { ok = false, error = { code = "InvalidInput", message = "eventMultiplier must be finite non-negative", retryable = false } } end

		local okPot, pot = validateOptionalMultiplier(input.potionMultiplier, "potionMultiplier")
		if not okPot then return { ok = false, error = { code = "InvalidInput", message = "potionMultiplier must be finite non-negative", retryable = false } } end

		-- B03: Manejar factor cero ANTES de la multiplicación para evitar overflow a NaN
		if perm == 0 or vip == 0 or event == 0 or pot == 0 then
			return {
				ok = true,
				value = {
					speed = before.speed,
					wins = curWins,
					rebirths = before.rebirths,
					speedCarry = before.speedCarry,
				},
			}
		end

		gain = rawAmount * perm * vip * event * pot

		-- B03: Si la multiplicación desborda a infinito o supera MAX_SAFE_INTEGER, saturar en MAX_SAFE_INTEGER
		if isBadNumber(gain) or gain > MAX_SAFE_INTEGER then
			gain = MAX_SAFE_INTEGER
		else
			gain = math.floor(gain)
		end
	end

	local newWins = math.min(MAX_SAFE_INTEGER, curWins + gain)
	if newWins < curWins then
		newWins = curWins
	end

	return {
		ok = true,
		value = {
			speed = before.speed,
			wins = newWins,
			rebirths = before.rebirths,
			speedCarry = before.speedCarry,
		},
	}
end

-- ============================================================================
-- 4. REQUISITOS Y MULTIPLICADORES DE REBIRTH
-- ============================================================================

function StatsService.NextRebirthRequirement(
	currentRebirths: number,
	requirements: { number }?
): Result<number>
	local rebirths = cleanInt(currentRebirths)
	local required: number

	if type(requirements) == "table" and #requirements > 0 then
		local index = rebirths + 1
		if requirements[index] then
			required = requirements[index]
		else
			required = requirements[#requirements]
		end
	else
		local firstRequired = 5
		local step = 15
		if rebirths <= 0 then
			required = firstRequired
		else
			required = firstRequired + (rebirths * step)
		end
	end

	return {
		ok = true,
		value = required,
	}
end

function StatsService.RebirthSpeedMultiplier(currentRebirths: number, perRebirth: number?): number
	local rebirths = cleanInt(currentRebirths)
	local factor = tonumber(perRebirth) or 1.5
	local multiplier = 1

	for _ = 1, rebirths do
		multiplier *= factor
		if isBadNumber(multiplier) or multiplier > MAX_STORED_SPEED then
			return MAX_STORED_SPEED
		end
	end

	return multiplier
end

-- ============================================================================
-- 5. ASIGNACIÓN EXACTA (GRANT EXACT STAT)
-- ============================================================================

function StatsService.GrantExactStat(
	currentVal: number,
	amount: number,
	statType: "Speed" | "Wins",
	maxSpeed: number?
): (number, boolean, number)
	local n = tonumber(amount)
	if not n or isBadNumber(n) or n <= 0 then
		return currentVal, false, 0
	end

	local maxLimit = maxSpeed or MAX_STORED_SPEED

	if statType == "Speed" then
		local before = cleanSpeed(currentVal, 1, maxLimit)
		local after = cleanSpeed(before + n, 1, maxLimit)
		local delta = after - before
		return after, (delta > 0), delta
	elseif statType == "Wins" then
		local before = cleanInt(currentVal)
		local after = math.min(MAX_SAFE_INTEGER, cleanInt(before + math.floor(n)))
		local delta = after - before
		return after, (delta > 0), delta
	end

	return currentVal, false, 0
end

return StatsService
