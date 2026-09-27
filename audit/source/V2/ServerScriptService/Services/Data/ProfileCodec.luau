--!strict
-- src/ServerScriptService/Services/Data/ProfileCodec.luau
-- Lote R1-02 / Revisión 2: Codec puro para codificación, decodificación y normalización V306.
-- Garantiza que ningún dato corrupto, NaN o malformado pase al juego en runtime.
-- Cumple con los hallazgos de auditoría A01, A04, A05, A06, A07 y las correcciones de la segunda revisión.

local ProfileCodec = {}

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
	UpgradeSpeedGainMultiplier: number,
	GamepassSpeedGainMultiplier: number,
	PermanentBaseSpeedMultiplier: number,
	PermanentWinsMultiplier: number,
	StarterPackGranted: boolean,
	StarterPackRewardVersion: number,
	World2Unlocked: boolean,
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
	Settings: Settings,
	LastSeenUpdateLog: number,
	DailyLoginState: DailyLoginState?,
	LastSaveUnix: number?,
	ActiveSessionId: string?,
	ActiveSessionStartedUnixMs: number?,
	ActiveSessionExpiresUnix: number?,
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
		UpgradeSpeedGainMultiplier = 1,
		GamepassSpeedGainMultiplier = 1,
		PermanentBaseSpeedMultiplier = 1,
		PermanentWinsMultiplier = 1,
		StarterPackGranted = false,
		StarterPackRewardVersion = 0,
		World2Unlocked = false,
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
		},
		LastSeenUpdateLog = 0,
		DailyLoginState = {
			ClaimedDays = {},
			LastClaimAt = 0,
			LastClaimedDay = 0,
			Cycle = 1,
		},
		LastSaveUnix = nil,
		ActiveSessionId = nil,
		ActiveSessionStartedUnixMs = nil,
		ActiveSessionExpiresUnix = nil,
	}
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

	for i = 1, math.min(#entries, MAX_SAVED_RECEIPTS) do
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
		UpgradeSpeedGainMultiplier = cleanMultiplier(raw.UpgradeSpeedGainMultiplier, 1, 0),
		GamepassSpeedGainMultiplier = cleanMultiplier(raw.GamepassSpeedGainMultiplier, 1, 0),
		-- Los multiplicadores base permanentes tienen un mínimo estricto de 1 (PlayerStats:868-869)
		PermanentBaseSpeedMultiplier = math.max(1, cleanMultiplier(raw.PermanentBaseSpeedMultiplier, 1, 0)),
		PermanentWinsMultiplier = math.max(1, cleanMultiplier(raw.PermanentWinsMultiplier, 1, 0)),

		StarterPackGranted = sanitizeBool(raw.StarterPackGranted, false),
		StarterPackRewardVersion = cleanInt(raw.StarterPackRewardVersion, 0, 0),
		World2Unlocked = sanitizeBool(raw.World2Unlocked, false),
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
		Settings = sanitizeSettings(raw.Settings),
		LastSeenUpdateLog = cleanInt(raw.LastSeenUpdateLog, 0, 0),
		DailyLoginState = sanitizeDailyLogin(raw.DailyLoginState),
		LastSaveUnix = sanitizeFiniteNonNegative(raw.LastSaveUnix),

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
		UpgradeSpeedGainMultiplier = profile.UpgradeSpeedGainMultiplier,
		GamepassSpeedGainMultiplier = profile.GamepassSpeedGainMultiplier,
		PermanentBaseSpeedMultiplier = profile.PermanentBaseSpeedMultiplier,
		PermanentWinsMultiplier = profile.PermanentWinsMultiplier,
		StarterPackGranted = profile.StarterPackGranted,
		StarterPackRewardVersion = profile.StarterPackRewardVersion,
		World2Unlocked = profile.World2Unlocked,
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
		},
		LastSeenUpdateLog = profile.LastSeenUpdateLog,
		LastSaveUnix = profile.LastSaveUnix,
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

return ProfileCodec
