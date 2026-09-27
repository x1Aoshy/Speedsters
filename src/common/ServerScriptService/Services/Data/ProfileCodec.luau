--!strict
-- src/ServerScriptService/Services/Data/ProfileCodec.luau
-- Lote R1-02 / Revisión 2: Codec puro para codificación, decodificación y normalización V306.
-- Garantiza que ningún dato corrupto, NaN o malformado pase al juego en runtime.
-- Cumple con los hallazgos de auditoría A01, A04, A05, A06, A07 y las correcciones de la segunda revisión.

local ProfileCodec = {}

-- M33 (2026-09-25): the Destiny cleaning moved to Shared/QuestPeriod (p0_data), which adds
-- Complete (the quest was finished before its day ended) and cleans LateDestiny the same way.
-- pcall + FindFirstChild (server modules are in place before scripts run, so never a wait):
-- while that module is missing, the cleaning below (the old inline one plus Complete) is used.
local QuestPeriod: any = nil
do
 local ok, mod = pcall(function(): any
  if typeof(script) == "Instance" then
   local shared = game:GetService("ReplicatedStorage"):FindFirstChild("Shared")
   local module = shared and shared:FindFirstChild("QuestPeriod")
   return if module and module:IsA("ModuleScript") then (require :: any)(module) else nil
  end
  return (require :: any)("../../../ReplicatedStorage/Shared/QuestPeriod")
 end)
 if ok and type(mod) == "table" then QuestPeriod = mod end
end
ProfileCodec.QuestPeriod = QuestPeriod

local function sanitizeDestinyInline(destiny)
 if type(destiny) ~= "table" then return nil end
 local clean = {Period = 0, Choice = 0, Targets = {}, Baseline = {}, Claimed = destiny.Claimed == true, Complete = destiny.Complete == true}
 if type(destiny.Period) == "number" and destiny.Period == destiny.Period then
  clean.Period = math.clamp(math.floor(destiny.Period), 0, 1e10)
 end
 if type(destiny.Choice) == "number" and destiny.Choice == destiny.Choice then
  clean.Choice = math.clamp(math.floor(destiny.Choice), 0, 3)
 end
 for _,metric in {"speed", "stages", "wins", "playtime", "rebirth"} do
  for _,field in {"Targets", "Baseline"} do
   local value = type(destiny[field]) == "table" and destiny[field][metric] or nil
   if type(value) == "number" and value == value then clean[field][metric] = math.clamp(value, 0, 1e50) end
  end
 end
 if type(destiny.ClaimedChoices) == "table" then
  local cleanedChoices = {}
  for k, v in destiny.ClaimedChoices do
   if v == true and (k == "1" or k == "2" or k == "3" or k == 1 or k == 2 or k == 3) then
    cleanedChoices[tostring(k)] = true
   end
  end
  clean.ClaimedChoices = cleanedChoices
 end
 return clean
end

local function sanitizeDestiny(destiny)
 if type(destiny) ~= "table" then return nil end
 if QuestPeriod and type(QuestPeriod.SanitizeDestiny) == "function" then
  local ok, clean = pcall(QuestPeriod.SanitizeDestiny, destiny)
  if ok and (clean == nil or type(clean) == "table") then return clean end
 end
 return sanitizeDestinyInline(destiny)
end

-- Bounded quest state survives reconnects and world transfers.
local function sanitizeQuestState(raw)
 local state = {}
 if type(raw) ~= "table" then return state end
 for _,category in {"Daily", "Weekly"} do
  local bucket = raw[category]
  if type(bucket) == "table" then
   local clean = {Period = 0, Progress = {}, Claimed = {}}
   if type(bucket.Period) == "number" and bucket.Period == bucket.Period then
    clean.Period = math.clamp(math.floor(bucket.Period), 0, 1e10)
   end
   for _,metric in {"speed", "stages", "wins", "playtime", "rebirth"} do
    local value = type(bucket.Progress) == "table" and bucket.Progress[metric] or 0
    if type(value) == "number" and value == value then clean.Progress[metric] = math.clamp(value, 0, 1e50) end
    clean.Claimed[metric] = type(bucket.Claimed) == "table" and bucket.Claimed[metric] == true
   end
   state[category] = clean
  end
 end
 -- Choose Your Destiny (Shared.QuestCatalog): the day, the quest picked (0 = none yet),
 -- each task's target and the day's count when it was picked, and whether it paid.
 -- M33 (2026-09-25): also yesterday's finished, unpaid quest (LateDestiny), paid at the
 -- day change (Shared/QuestPeriod.ClaimLate).
 state.Destiny = sanitizeDestiny(raw.Destiny)
 state.LateDestiny = sanitizeDestiny(raw.LateDestiny)
 return state
end


export type Settings = {
	Muted: boolean,
	SoundEffects: boolean,
	GlobalMessages: boolean,
	PromptRevivals: boolean,
	HideHud: boolean,
	HidePopups: boolean,
	AcceptGifts: boolean,
	EventEffects: boolean,
	MusicVolume: number,
	SfxVolume: number,
	WalkSpeedMode: string?,
	CustomWalkSpeed: number?,
	TouchLayout: string?,
	-- The HUD guides (Shared/TutorialGuide) are taught once per account (2026-09-21).
	EvolveTutorialSeen: boolean,
	BackpackTutorialSeen: boolean,
	-- The rebirth guide, taught once per account as well (2026-09-22).
	RebirthTutorialSeen: boolean,
}

export type DailyLoginState = {
	ClaimedDays: { number },
	LastClaimAt: number,
	LastClaimedDay: number,
	Cycle: number,
}

export type ProfileV306 = {
	Version: number,
	Speed: number,
	Wins: number,
	Rebirths: number,
	RobuxSpent: number,
	GlobalSpeedGainMultiplier: number,
	TrailSpeedGainMultiplier: number,
	AuraSpeedGainMultiplier: number,
	UpgradeSpeedGainMultiplier: number,
	GamepassSpeedGainMultiplier: number,
	PermanentBaseSpeedMultiplier: number,
	PermanentWinsMultiplier: number,
	StarterPackGranted: boolean,
	StarterPackRewardVersion: number,
	World2Unlocked: boolean,
	World3Unlocked: boolean,
	FirstTimeTutorialSeen: boolean,
	FirstRunEasyLevelsEligible: boolean,
	EquippedSkin: string,
	OwnedSkins: { string },
	EquippedTrail: string,
	OwnedTrails: { string },
	EquippedAura: string,
	OwnedAuras: { string },
	OwnedUpgrades: { string },
	ProcessedReceipts: { [string]: number },
	PotionSpeedRemainingSeconds: number,
	PotionWinsRemainingSeconds: number,
	TemporaryFlightRemainingSeconds: number?,
	Settings: Settings,
	LastSeenUpdateLog: number,
	DailyLoginState: DailyLoginState?,
	LastSaveUnix: number?,
	LastLogoutTimestamp: number?,
	LastAfkClaimTimestamp: number?,
	QuestState: any?,
	SpinTickets: number?,
	SpinWheelFreePeriod: number?,
	SpinWinsWindowStart: number?,
	SpinWinsWindowCount: number?,
	ActiveSessionId: string?,
	ActiveSessionStartedUnixMs: number?,
	ActiveSessionExpiresUnix: number?,
	-- Update 4: { V, Race, Retention, Titles, Community } (Services/Data/Update4Profile).
	U4: any?,
}

export type SkinValidator = (skinId: string) -> boolean

export type ErrorCode =
	"NotReady" | "Closing" | "SessionLost" | "LeaseBusy"
	| "InvalidInput" | "InsufficientFunds" | "UnknownProduct"
	| "QueueFull" | "DeadlineExceeded" | "StoreUnavailable"
	| "PersistenceUncertain" | "SchemaUnsupported" | "OperationConflict"
	| "RecipientUnavailable" | "EphemeralSession" | "InternalError" | "CorruptData"

export type ServiceError = {
	code: ErrorCode,
	message: string,
	retryable: boolean,
	operationId: string?,
}

export type DecodeSuccess = {
	ok: true,
	value: ProfileV306,
	isNew: boolean,
}

export type DecodeFailure = {
	ok: false,
	error: ServiceError,
}

export type DecodeResult = DecodeSuccess | DecodeFailure

local MAX_SAVED_RECEIPTS = 200
local MAX_SAFE_INTEGER = 9007199254740991
local MAX_STORED_SPEED = 1e50
local DEFAULT_SKIN = "FlashSuit"

local function isBadNumber(n: number): boolean
	return n ~= n or n == math.huge or n == -math.huge
end

local function cleanSpeed(v: any): number
	local n = tonumber(v)
	if not n or isBadNumber(n) then
		return 1
	end
	if n < 1 then
		return 1
	end
	if n > MAX_STORED_SPEED then
		return MAX_STORED_SPEED
	end
	return n
end

local function cleanInt(v: any, default: number, min: number?, max: number?): number
	local n = tonumber(v)
	if not n or isBadNumber(n) then
		return default
	end
	n = math.floor(n)
	if min and n < min then
		n = min
	end
	if max and n > max then
		n = max
	end
	return n
end

local function cleanMultiplier(v: any, default: number, min: number?): number
	local n = tonumber(v)
	if not n or isBadNumber(n) or n < (min or 0) then
		return default
	end
	return n
end

local function sanitizeBool(v: any, default: boolean): boolean
	if type(v) == "boolean" then
		return v
	end
	return default
end

local function sanitizeString(v: any, default: string): string
	if type(v) == "string" and v ~= "" then
		return v
	end
	return default
end

local function sanitizeNonEmptyString(v: any): string?
	if type(v) == "string" and v ~= "" then
		return v
	end
	return nil
end

local function sanitizeFiniteNonNegative(v: any): number?
	local n = tonumber(v)
	if not n or isBadNumber(n) or n < 0 then
		return nil
	end
	return n
end

local function sanitizeStringList(v: any, requiredEntry: string?, validator: SkinValidator?): { string }
	local result = {}
	local seen = {}
	if requiredEntry then
		seen[requiredEntry] = true
		table.insert(result, requiredEntry)
	end
	if type(v) == "table" then
		for _, item in ipairs(v) do
			if type(item) == "string" and item ~= "" and not seen[item] then
				if not validator or validator(item) then
					seen[item] = true
					table.insert(result, item)
				end
			end
		end
		for key, item in pairs(v) do
			if type(key) == "string" and (item == true or item == 1) and not seen[key] then
				if not validator or validator(key) then
					seen[key] = true
					table.insert(result, key)
				end
			end
		end
	end
	return result
end

local function deepCopyList(list: { string }?): { string }
	local copy = {}
	if type(list) == "table" then
		for i, v in ipairs(list) do
			copy[i] = v
		end
	end
	return copy
end

local function deepCopyMap(map: { [string]: any }?): { [string]: any }
	local copy = {}
	if type(map) == "table" then
		for k, v in pairs(map) do
			copy[k] = v
		end
	end
	return copy
end

-- Genera el estado limpio para un jugador NUEVO (sin partida previa)
-- Según makeDefaultSave (PlayerStats:812), FirstTimeTutorialSeen = false y FirstRunEasyLevelsEligible = true.
function ProfileCodec.CreateDefault(): ProfileV306
	return {
		Version = 306,
		Speed = 1,
		Wins = 0,
		Rebirths = 0,
		RobuxSpent = 0,
		GlobalSpeedGainMultiplier = 1,
		TrailSpeedGainMultiplier = 1,
		AuraSpeedGainMultiplier = 1,
		UpgradeSpeedGainMultiplier = 1,
		GamepassSpeedGainMultiplier = 1,
		PermanentBaseSpeedMultiplier = 1,
		PermanentWinsMultiplier = 1,
		StarterPackGranted = false,
		StarterPackRewardVersion = 0,
		World2Unlocked = false,
		World3Unlocked = false,
		FirstTimeTutorialSeen = false,
		FirstRunEasyLevelsEligible = true,
		EquippedSkin = DEFAULT_SKIN,
		OwnedSkins = { DEFAULT_SKIN },
		EquippedTrail = "",
		OwnedTrails = {},
		EquippedAura = "",
		OwnedAuras = {},
		OwnedUpgrades = {},
		ProcessedReceipts = {},
		PotionSpeedRemainingSeconds = 0,
		PotionWinsRemainingSeconds = 0,
		TemporaryFlightRemainingSeconds = 0,
		Settings = {
			Muted = false,
			SoundEffects = true,
			GlobalMessages = true,
			PromptRevivals = true,
			HideHud = false,
			HidePopups = false,
			AcceptGifts = true,
			EventEffects = true,
			MusicVolume = 100,
			SfxVolume = 100,
			WalkSpeedMode = "Red",
			CustomWalkSpeed = nil,
			TouchLayout = "",
			EvolveTutorialSeen = false,
			BackpackTutorialSeen = false,
			RebirthTutorialSeen = false,
		},
		LastSeenUpdateLog = 0,
		DailyLoginState = {
			ClaimedDays = {},
			LastClaimAt = 0,
			LastClaimedDay = 0,
			Cycle = 1,
		},
		LastSaveUnix = nil,
		LastLogoutTimestamp = nil,
		LastAfkClaimTimestamp = nil,
		QuestState = {},
		SpinTickets = 0,
		SpinWheelFreePeriod = 0,
		SpinWinsWindowStart = 0,
		SpinWinsWindowCount = 0,
		ActiveSessionId = nil,
		ActiveSessionStartedUnixMs = nil,
		ActiveSessionExpiresUnix = nil,
	}
end

-- The touch controls' own places ("Move controls", client UI/TouchLayoutEditor): "" (the
-- automatic layout) or exactly what Shared.HudErgonomics.FormatTouchLayout writes: version
-- "1", then one to four "|<piece>=<x>,<y>" fields, the pieces S, B, H, T once each and in
-- that order, shares of the screen with 4 decimals from 0 to 1. Anything else becomes ""
-- (the pattern of HudErgonomics.ParseTouchLayout; audit/test_opt6_touch_layout checks that
-- the two accept the same strings).
local TOUCH_LAYOUT_MAX_LENGTH = 80
local TOUCH_LAYOUT_ORDER = { S = 1, B = 2, H = 3, T = 4 }
function ProfileCodec.SanitizeTouchLayout(v: any): string
	if type(v) ~= "string" or #v == 0 or #v > TOUCH_LAYOUT_MAX_LENGTH then
		return ""
	end
	local fields = string.split(v, "|")
	if fields[1] ~= "1" or #fields < 2 then
		return ""
	end
	local last = 0
	for index = 2, #fields do
		local piece, x, y = string.match(fields[index], "^([SBHT])=([01]%.%d%d%d%d),([01]%.%d%d%d%d)$")
		local order = piece and TOUCH_LAYOUT_ORDER[piece]
		if not order or order <= last or (tonumber(x) or 2) > 1 or (tonumber(y) or 2) > 1 then
			return ""
		end
		last = order
	end
	return v
end

local function sanitizeSettings(raw: any): Settings
	local s = type(raw) == "table" and raw or {}
	local customSp = nil
	if type(s.CustomWalkSpeed) == "number" and not isBadNumber(s.CustomWalkSpeed) then
		customSp = cleanInt(s.CustomWalkSpeed, 300, 8, 300)
	end
	return {
		Muted = sanitizeBool(s.Muted, false),
		SoundEffects = sanitizeBool(s.SoundEffects, true),
		GlobalMessages = sanitizeBool(s.GlobalMessages, true),
		PromptRevivals = sanitizeBool(s.PromptRevivals, true),
		HideHud = sanitizeBool(s.HideHud, false),
		HidePopups = sanitizeBool(s.HidePopups, false),
		AcceptGifts = sanitizeBool(s.AcceptGifts, true),
		EventEffects = sanitizeBool(s.EventEffects, true),
		MusicVolume = cleanInt(s.MusicVolume, 100, 0, 100),
		SfxVolume = cleanInt(s.SfxVolume, 100, 0, 100),
		WalkSpeedMode = (type(s.WalkSpeedMode) == "string" and s.WalkSpeedMode ~= "") and s.WalkSpeedMode or "Red",
		CustomWalkSpeed = customSp,
		-- A profile saved before the setting existed has none: the automatic layout.
		TouchLayout = ProfileCodec.SanitizeTouchLayout(s.TouchLayout),
		-- 2026-09-21: the HUD guides' "seen" used to live only in a client attribute, so the Evolve
		-- guide came back on every server. A save from before this has none: unseen (the client
		-- still skips the Evolve guide for a runner who already owns a later suit).
		EvolveTutorialSeen = sanitizeBool(s.EvolveTutorialSeen, false),
		BackpackTutorialSeen = sanitizeBool(s.BackpackTutorialSeen, false),
		-- 2026-09-22: a save from before the rebirth guide has none: unseen (the client offers it
		-- only to a runner with no rebirth yet).
		RebirthTutorialSeen = sanitizeBool(s.RebirthTutorialSeen, false),
	}
end

local function sanitizeReceipts(raw: any): { [string]: number }
	local receipts: { [string]: number } = {}
	if type(raw) ~= "table" then
		return receipts
	end

	local byId: { [string]: number } = {}

	for key, storedValue in pairs(raw) do
		local receiptId: string? = nil
		local processedAt: number = 0

		if type(key) == "string" and key ~= "" then
			receiptId = key
			if type(storedValue) == "number" then
				if not isBadNumber(storedValue) and storedValue >= 0 then
					processedAt = math.floor(storedValue)
				else
					receiptId = nil
				end
			elseif storedValue == true then
				processedAt = 0
			else
				receiptId = nil
			end
		elseif type(key) == "number" and type(storedValue) == "string" and storedValue ~= "" then
			receiptId = storedValue
			processedAt = 0
		end

		if receiptId then
			local existing = byId[receiptId]
			if existing == nil or processedAt > existing then
				byId[receiptId] = processedAt
			end
		end
	end

	local entries: { { id: string, time: number } } = {}
	for id, time in pairs(byId) do
		table.insert(entries, { id = id, time = time })
	end

	table.sort(entries, function(left, right)
		if left.time == right.time then
			return left.id < right.id
		end
		return left.time > right.time
	end)

	for i = 1, #entries do
		receipts[entries[i].id] = entries[i].time
	end

	return receipts
end

local function sanitizeDailyLogin(raw: any): DailyLoginState?
	if type(raw) ~= "table" then
		return nil
	end

	local claimedDays = {}
	if type(raw.ClaimedDays) == "table" then
		for _, day in ipairs(raw.ClaimedDays) do
			local d = tonumber(day)
			if d and d >= 1 and d <= 30 then
				table.insert(claimedDays, math.floor(d))
			end
		end
	end

	return {
		ClaimedDays = claimedDays,
		LastClaimAt = cleanInt(raw.LastClaimAt, 0, 0),
		LastClaimedDay = cleanInt(raw.LastClaimedDay, 0, 0, 30),
		Cycle = cleanInt(raw.Cycle, 1, 1),
	}
end

-- Decodifica un payload desconocido desde DataStore retornando un Result envelope limpio.
-- { ok = true, value = profile, isNew = boolean } o { ok = false, error = ServiceError }.
function ProfileCodec.Decode(raw: any, skinValidator: SkinValidator?): DecodeResult
	-- Caso 1: Jugador nuevo (DataStore devuelve nil)
	if raw == nil then
		return {
			ok = true,
			value = ProfileCodec.CreateDefault(),
			isNew = true,
		}
	end

	-- Caso 2: Dato corrupto / no tabla
	if type(raw) ~= "table" then
		return {
			ok = false,
			error = {
				code = "CorruptData",
				message = "Raw profile payload is not a table (received " .. typeof(raw) .. ")",
				retryable = false,
				operationId = nil,
			},
		}
	end

	-- Caso 3: Versión futura no compatible (A07)
	local rawVersion = tonumber(raw.Version)
	if rawVersion and rawVersion > 306 then
		return {
			ok = false,
			error = {
				code = "SchemaUnsupported",
				message = "Schema version " .. tostring(rawVersion) .. " is newer than supported version 306",
				retryable = false,
				operationId = nil,
			},
		}
	end

	-- Caso 4: Registro existente válido (V306 o legacy con campos ausentes para migrar)
	local rawSkin = sanitizeString(raw.EquippedSkin, DEFAULT_SKIN)
	local equippedSkin = DEFAULT_SKIN
	if skinValidator then
		if skinValidator(rawSkin) then
			equippedSkin = rawSkin
		end
	else
		equippedSkin = rawSkin
	end

	local ownedSkins = sanitizeStringList(raw.OwnedSkins, DEFAULT_SKIN, skinValidator)
	local hasEquipped = false
	for _, s in ipairs(ownedSkins) do
		if s == equippedSkin then
			hasEquipped = true
			break
		end
	end
	if not hasEquipped then
		table.insert(ownedSkins, equippedSkin)
	end

	-- Reglas de migración legacy para registros existentes con campos faltantes:
	-- (PlayerStats.server.luau:876-889)
	local firstTimeTutorialSeen: boolean
	if raw.FirstTimeTutorialSeen == nil then
		firstTimeTutorialSeen = true -- Jugadores existentes no repiten tutorial
	else
		firstTimeTutorialSeen = raw.FirstTimeTutorialSeen == true
	end

	local firstRunEasyLevelsEligible: boolean
	if raw.FirstRunEasyLevelsEligible == nil then
		firstRunEasyLevelsEligible = false -- Jugadores existentes no reciben curva fácil
	else
		firstRunEasyLevelsEligible = raw.FirstRunEasyLevelsEligible == true
	end

	local profile: ProfileV306 = {
		Version = 306,
		Speed = cleanSpeed(raw.Speed),
		Wins = cleanInt(raw.Wins, 0, 0, MAX_SAFE_INTEGER),
		Rebirths = cleanInt(raw.Rebirths, 0, 0, MAX_SAFE_INTEGER),
		RobuxSpent = cleanInt(raw.RobuxSpent, 0, 0, MAX_SAFE_INTEGER),

		-- Los multiplicadores generales permiten 0 (ej. multiplicador de ganancia global apagado)
		GlobalSpeedGainMultiplier = cleanMultiplier(raw.GlobalSpeedGainMultiplier, 1, 0),
		TrailSpeedGainMultiplier = cleanMultiplier(raw.TrailSpeedGainMultiplier, 1, 0),
		AuraSpeedGainMultiplier = cleanMultiplier(raw.AuraSpeedGainMultiplier, 1, 0),
		UpgradeSpeedGainMultiplier = cleanMultiplier(raw.UpgradeSpeedGainMultiplier, 1, 0),
		GamepassSpeedGainMultiplier = cleanMultiplier(raw.GamepassSpeedGainMultiplier, 1, 0),
		-- Los multiplicadores base permanentes tienen un mínimo estricto de 1 (PlayerStats:868-869)
		PermanentBaseSpeedMultiplier = math.max(1, cleanMultiplier(raw.PermanentBaseSpeedMultiplier, 1, 0)),
		PermanentWinsMultiplier = math.max(1, cleanMultiplier(raw.PermanentWinsMultiplier, 1, 0)),

		StarterPackGranted = sanitizeBool(raw.StarterPackGranted, false),
		StarterPackRewardVersion = cleanInt(raw.StarterPackRewardVersion, 0, 0),
		World2Unlocked = sanitizeBool(raw.World2Unlocked, false),
		World3Unlocked = sanitizeBool(raw.World3Unlocked, false),
		FirstTimeTutorialSeen = firstTimeTutorialSeen,
		FirstRunEasyLevelsEligible = firstRunEasyLevelsEligible,

		EquippedSkin = equippedSkin,
		OwnedSkins = ownedSkins,
		EquippedTrail = sanitizeString(raw.EquippedTrail, ""),
		OwnedTrails = sanitizeStringList(raw.OwnedTrails),
		EquippedAura = sanitizeString(raw.EquippedAura, ""),
		OwnedAuras = sanitizeStringList(raw.OwnedAuras),
		OwnedUpgrades = sanitizeStringList(raw.OwnedUpgrades),

		ProcessedReceipts = sanitizeReceipts(raw.ProcessedReceipts),
		PotionSpeedRemainingSeconds = cleanInt(raw.PotionSpeedRemainingSeconds, 0, 0),
		PotionWinsRemainingSeconds = cleanInt(raw.PotionWinsRemainingSeconds, 0, 0),
		TemporaryFlightRemainingSeconds = cleanInt(raw.TemporaryFlightRemainingSeconds, 0, 0),
		Settings = sanitizeSettings(raw.Settings),
		LastSeenUpdateLog = cleanInt(raw.LastSeenUpdateLog, 0, 0),
		DailyLoginState = sanitizeDailyLogin(raw.DailyLoginState),
		LastSaveUnix = sanitizeFiniteNonNegative(raw.LastSaveUnix),
		LastLogoutTimestamp = sanitizeFiniteNonNegative(raw.LastLogoutTimestamp),
		LastAfkClaimTimestamp = sanitizeFiniteNonNegative(raw.LastAfkClaimTimestamp),
		QuestState = sanitizeQuestState(raw.QuestState),
		SpinTickets = math.floor(sanitizeFiniteNonNegative(raw.SpinTickets) or 0),
		SpinWheelFreePeriod = math.floor(sanitizeFiniteNonNegative(raw.SpinWheelFreePeriod) or 0),
		SpinWinsWindowStart = math.floor(sanitizeFiniteNonNegative(raw.SpinWinsWindowStart) or 0),
		SpinWinsWindowCount = math.floor(sanitizeFiniteNonNegative(raw.SpinWinsWindowCount) or 0),

		ActiveSessionId = sanitizeNonEmptyString(raw.ActiveSessionId),
		ActiveSessionStartedUnixMs = sanitizeFiniteNonNegative(raw.ActiveSessionStartedUnixMs),
		ActiveSessionExpiresUnix = sanitizeFiniteNonNegative(raw.ActiveSessionExpiresUnix),
	}

	return {
		ok = true,
		value = profile,
		isNew = false,
	}
end

-- Codifica un ProfileV306 limpio para ser persistido en DataStore.
-- Realiza una copia profunda recursiva estricta de todas las estructuras anidadas mutables.
function ProfileCodec.Encode(profile: ProfileV306): { [string]: any }
	local encoded: { [string]: any } = {
		Version = 306,
		Speed = profile.Speed,
		Wins = profile.Wins,
		Rebirths = profile.Rebirths,
		RobuxSpent = profile.RobuxSpent,
		GlobalSpeedGainMultiplier = profile.GlobalSpeedGainMultiplier,
		TrailSpeedGainMultiplier = profile.TrailSpeedGainMultiplier,
		AuraSpeedGainMultiplier = profile.AuraSpeedGainMultiplier,
		UpgradeSpeedGainMultiplier = profile.UpgradeSpeedGainMultiplier,
		GamepassSpeedGainMultiplier = profile.GamepassSpeedGainMultiplier,
		PermanentBaseSpeedMultiplier = profile.PermanentBaseSpeedMultiplier,
		PermanentWinsMultiplier = profile.PermanentWinsMultiplier,
		StarterPackGranted = profile.StarterPackGranted,
		StarterPackRewardVersion = profile.StarterPackRewardVersion,
		World2Unlocked = profile.World2Unlocked,
		World3Unlocked = profile.World3Unlocked,
		FirstTimeTutorialSeen = profile.FirstTimeTutorialSeen,
		FirstRunEasyLevelsEligible = profile.FirstRunEasyLevelsEligible,
		EquippedSkin = profile.EquippedSkin,
		OwnedSkins = deepCopyList(profile.OwnedSkins),
		EquippedTrail = profile.EquippedTrail,
		OwnedTrails = deepCopyList(profile.OwnedTrails),
		EquippedAura = profile.EquippedAura,
		OwnedAuras = deepCopyList(profile.OwnedAuras),
		OwnedUpgrades = deepCopyList(profile.OwnedUpgrades),
		ProcessedReceipts = deepCopyMap(profile.ProcessedReceipts),
		PotionSpeedRemainingSeconds = profile.PotionSpeedRemainingSeconds,
		PotionWinsRemainingSeconds = profile.PotionWinsRemainingSeconds,
		TemporaryFlightRemainingSeconds = profile.TemporaryFlightRemainingSeconds or 0,
		Settings = {
			Muted = profile.Settings.Muted,
			SoundEffects = profile.Settings.SoundEffects,
			GlobalMessages = profile.Settings.GlobalMessages,
			PromptRevivals = profile.Settings.PromptRevivals,
			HideHud = profile.Settings.HideHud,
			HidePopups = profile.Settings.HidePopups,
			AcceptGifts = profile.Settings.AcceptGifts,
			EventEffects = profile.Settings.EventEffects,
			MusicVolume = profile.Settings.MusicVolume,
			SfxVolume = profile.Settings.SfxVolume,
			WalkSpeedMode = profile.Settings.WalkSpeedMode,
			CustomWalkSpeed = profile.Settings.CustomWalkSpeed,
			TouchLayout = profile.Settings.TouchLayout,
			EvolveTutorialSeen = profile.Settings.EvolveTutorialSeen == true,
			BackpackTutorialSeen = profile.Settings.BackpackTutorialSeen == true,
			RebirthTutorialSeen = profile.Settings.RebirthTutorialSeen == true,
		},
		LastSeenUpdateLog = profile.LastSeenUpdateLog,
		LastSaveUnix = profile.LastSaveUnix,
		LastLogoutTimestamp = profile.LastLogoutTimestamp,
		LastAfkClaimTimestamp = profile.LastAfkClaimTimestamp,
		QuestState = sanitizeQuestState(profile.QuestState),
		SpinTickets = profile.SpinTickets or 0,
		SpinWheelFreePeriod = profile.SpinWheelFreePeriod or 0,
		SpinWinsWindowStart = profile.SpinWinsWindowStart or 0,
		SpinWinsWindowCount = profile.SpinWinsWindowCount or 0,
		ActiveSessionId = profile.ActiveSessionId,
		ActiveSessionStartedUnixMs = profile.ActiveSessionStartedUnixMs,
		ActiveSessionExpiresUnix = profile.ActiveSessionExpiresUnix,
	}

	if profile.DailyLoginState then
		local claimedDaysCopy = {}
		if type(profile.DailyLoginState.ClaimedDays) == "table" then
			for i, day in ipairs(profile.DailyLoginState.ClaimedDays) do
				claimedDaysCopy[i] = day
			end
		end
		encoded.DailyLoginState = {
			ClaimedDays = claimedDaysCopy,
			LastClaimAt = profile.DailyLoginState.LastClaimAt,
			LastClaimedDay = profile.DailyLoginState.LastClaimedDay,
			Cycle = profile.DailyLoginState.Cycle,
		}
	end

	return encoded
end

local decodeBase, encodeBase = ProfileCodec.Decode, ProfileCodec.Encode
local function copyOperations(raw)
	local copy = {}
	if type(raw) == "table" then
		for id, entry in pairs(raw) do
			if type(id) == "string" and type(entry) == "table" and type(entry.fingerprint) == "string" then
				copy[id] = { fingerprint = entry.fingerprint, time = tonumber(entry.time) or 0 }
			end
		end
	end
	return copy
end
function ProfileCodec.Decode(raw, validator)
	local result = decodeBase(raw, validator)
	if result.ok then
		result.value.Update2WriteId = type(raw) == "table" and raw.Update2WriteId or nil
		result.value.Update2Operations = copyOperations(type(raw) == "table" and raw.Update2Operations or nil)
	end
	return result
end
function ProfileCodec.Encode(profile)
	local result = encodeBase(profile)
	result.Update2WriteId = profile.Update2WriteId
	result.Update2Operations = copyOperations(profile.Update2Operations)
	return result
end
-- Keep extension fields across old-schema round trips; normalized known fields still win.
local decodeExtended, encodeExtended = ProfileCodec.Decode, ProfileCodec.Encode
local function cloneExtension(value)
	if type(value) ~= "table" then return value end
	local result = {}
	for k,v in pairs(value) do result[k] = cloneExtension(v) end
	return result
end
function ProfileCodec.Decode(raw, validator)
	local result = decodeExtended(raw, validator)
	if result.ok and type(raw) == "table" then
		local pending=raw.PendingStageTeleport
		if pending~=nil then
			local function finite(value) return type(value)=="number" and value==value and math.abs(value)~=math.huge end
			if type(pending)~="table" or type(pending.id)~="string" or pending.id=="" or #pending.id>128
				or (pending.world~=1 and pending.world~=2) or not finite(pending.stage) or pending.stage%1~=0 or pending.stage<1 or pending.stage>100
				or not finite(pending.cost) or pending.cost%1~=0 or pending.cost<0 or pending.cost>9007199254740991 then
				return {ok=false,error={code="CorruptData",message="Invalid pending travel; preserving stored record",retryable=false}}
			end
		end
		local known = encodeExtended(result.value)
		result.value.Update2PreservedFields = {}
		for k,v in pairs(raw) do
			if known[k] == nil and k ~= "Update2PreservedFields" then result.value.Update2PreservedFields[k] = cloneExtension(v) end
		end
		for _,key in {"PotionSpeedMultiplier","PotionWinsMultiplier","PotionSpeedBottleType","PotionWinsBottleType","Update2GiftContexts","Update2GiftContextIds","PendingStageTeleport"} do
			result.value[key] = cloneExtension(raw[key])
		end
	end
	return result
end
function ProfileCodec.Encode(profile)
	local result = cloneExtension(profile.Update2PreservedFields or {})
	for k,v in pairs(encodeExtended(profile)) do result[k] = v end
	-- Session metadata must never be resurrected from extension fields after release.
	for _,key in {"ActiveSessionId","ActiveSessionStartedUnixMs","ActiveSessionExpiresUnix","Update2WriteId"} do result[key]=profile[key] end
	for _,key in {"PotionSpeedMultiplier","PotionWinsMultiplier","PotionSpeedBottleType","PotionWinsBottleType","Update2GiftContexts","Update2GiftContextIds","PendingStageTeleport"} do result[key]=cloneExtension(profile[key]) end
	return result
end

-- Update 4 (2026-09-25): the U4 field is a known field (not an Update2PreservedField), cleaned
-- and encoded section by section by Update4Profile. pcall: if the dispatcher cannot load, no
-- wrapper is installed and U4 keeps travelling untouched in Update2PreservedFields, as any
-- unknown field does, instead of being dropped.
local u4Ok, Update4Profile = pcall(function(): any
	if typeof(script) == "Instance" and script.Parent then
		local module = script.Parent:FindFirstChild("Update4Profile")
		return if module and module:IsA("ModuleScript") then (require :: any)(module) else nil
	end
	return (require :: any)("./Update4Profile")
end)
if u4Ok and type(Update4Profile) == "table" then
	local decodeU3, encodeU3, defaultU3 = ProfileCodec.Decode, ProfileCodec.Encode, ProfileCodec.CreateDefault
	ProfileCodec.Update4Profile = Update4Profile
	-- Decode(nil) and WipeProfile both build on CreateDefault, so new and wiped profiles get U4 too.
	function ProfileCodec.CreateDefault(): ProfileV306
		local profile = defaultU3()
		profile.U4 = Update4Profile.Default()
		return profile
	end
	function ProfileCodec.Decode(raw, validator)
		local result = decodeU3(raw, validator)
		if result.ok then
			-- A save from before Update 4 has no U4: every section starts from its Default.
			result.value.U4 = Update4Profile.Sanitize(if type(raw) == "table" then raw.U4 else nil)
			if type(result.value.Update2PreservedFields) == "table" then
				result.value.Update2PreservedFields.U4 = nil
			end
		end
		return result
	end
	function ProfileCodec.Encode(profile)
		local encoded = encodeU3(profile)
		encoded.U4 = Update4Profile.Encode(profile.U4)
		return encoded
	end
end

return ProfileCodec
