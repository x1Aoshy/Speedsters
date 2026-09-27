--!strict
-- src/ServerScriptService/Services/Data/ProfileReducers.luau
-- Lote R1-04: Reducers puros para mutaciones económicas y de perfil.

local ProfileCodec = if typeof(script) == "Instance" and script.Parent
	then require(script.Parent.ProfileCodec)
	else require("./ProfileCodec")

type ProfileV306 = ProfileCodec.ProfileV306
type Settings = ProfileCodec.Settings

export type ErrorCode =
	"InvalidInput"
	| "InsufficientFunds"
	| "QueueFull"
	| "SessionLost"
	| "OperationConflict"
	| "InternalError"

export type ServiceError = {
	code: ErrorCode,
	message: string,
	retryable: boolean,
}

export type Result<T> = { ok: true, value: T } | { ok: false, error: ServiceError }

export type BuffGrant = {
	kind: "SpeedPotion" | "WinsPotion",
	addedSeconds: number,
	multiplier: number,
}

export type EconomyCommand =
	{ kind: "GrantExact", stat: "Speed" | "Wins" | "Rebirths", amount: number }
	| { kind: "DebitWins", amount: number }
	| { kind: "GrantSkin", skinId: string }
	| { kind: "EquipSkin", skinId: string }
	| { kind: "GrantTrail", trailId: string }
	| { kind: "EquipTrail", trailId: string }
	| { kind: "GrantAura", auraId: string }
	| { kind: "EquipAura", auraId: string }
	| { kind: "GrantUpgrade", upgradeId: string }
	| { kind: "GrantBuff", grant: BuffGrant }
	| { kind: "RecordRobuxSpent", amount: number }
	| { kind: "PerformRebirth", resetSpeedTo: number? }

local MAX_SAFE_INTEGER = 9007199254740991
local SPEED_CAP = 1e50

local ProfileReducers = {}

function ProfileReducers.ApplyCommand(
	profile: ProfileV306,
	command: EconomyCommand,
	nowUnix: number
): Result<boolean>
	if command.kind == "PerformRebirth" then
		profile.Rebirths = math.min(MAX_SAFE_INTEGER, (profile.Rebirths or 0) + 1)
		local resetSpeed = command.resetSpeedTo or 1
		profile.Speed = math.max(1, math.min(SPEED_CAP, resetSpeed))
		profile.FirstRunEasyLevelsEligible = false
		return { ok = true, value = true }
	elseif command.kind == "EquipSkin" then
		if type(command.skinId) ~= "string" or (command.skinId ~= "" and not table.find(profile.OwnedSkins, command.skinId)) then
			return { ok = false, error = { code = "InvalidInput", message = "Skin is not owned", retryable = false } }
		end
		profile.EquippedSkin = command.skinId
		return { ok = true, value = true }
	elseif command.kind == "EquipTrail" then
		if type(command.trailId) ~= "string" or (command.trailId ~= "" and not table.find(profile.OwnedTrails, command.trailId)) then
			return { ok = false, error = { code = "InvalidInput", message = "Trail is not owned", retryable = false } }
		end
		profile.EquippedTrail = command.trailId
		return { ok = true, value = true }
	elseif command.kind == "EquipAura" then
		if type(command.auraId) ~= "string" or (command.auraId ~= "" and not table.find(profile.OwnedAuras, command.auraId)) then
			return { ok = false, error = { code = "InvalidInput", message = "Aura is not owned", retryable = false } }
		end
		profile.EquippedAura = command.auraId
		return { ok = true, value = true }
	elseif command.kind == "GrantExact" then
		local amount = command.amount
		if typeof(amount) ~= "number" or amount ~= amount or amount < 0 or amount == math.huge then
			return {
				ok = false,
				error = { code = "InvalidInput", message = "Invalid grant amount", retryable = false },
			}
		end

		if command.stat == "Speed" then
			local curSpeed = profile.Speed or 0
			profile.Speed = math.min(SPEED_CAP, curSpeed + amount)
			return { ok = true, value = true }
		elseif command.stat == "Wins" then
			local curWins = profile.Wins or 0
			profile.Wins = math.min(MAX_SAFE_INTEGER, curWins + amount)
			return { ok = true, value = true }
		elseif command.stat == "Rebirths" then
			local curRebirths = profile.Rebirths or 0
			profile.Rebirths = math.min(MAX_SAFE_INTEGER, curRebirths + amount)
			return { ok = true, value = true }
		else
			return {
				ok = false,
				error = { code = "InvalidInput", message = "Unknown stat name", retryable = false },
			}
		end

	elseif command.kind == "DebitWins" then
		local amount = command.amount
		if typeof(amount) ~= "number" or amount ~= amount or amount <= 0 or amount == math.huge then
			return {
				ok = false,
				error = { code = "InvalidInput", message = "Invalid debit amount", retryable = false },
			}
		end

		local curWins = profile.Wins or 0
		if curWins < amount then
			return {
				ok = false,
				error = { code = "InsufficientFunds", message = "Insufficient wins balance", retryable = false },
			}
		end

		profile.Wins = curWins - amount
		return { ok = true, value = true }

	elseif command.kind == "GrantSkin" then
		local skinId = command.skinId
		if typeof(skinId) ~= "string" or skinId == "" then
			return {
				ok = false,
				error = { code = "InvalidInput", message = "Invalid skinId", retryable = false },
			}
		end
		if not table.find(profile.OwnedSkins, skinId) then
			table.insert(profile.OwnedSkins, skinId)
		end
		return { ok = true, value = true }

	elseif command.kind == "GrantTrail" then
		local trailId = command.trailId
		if typeof(trailId) ~= "string" or trailId == "" then
			return {
				ok = false,
				error = { code = "InvalidInput", message = "Invalid trailId", retryable = false },
			}
		end
		if not table.find(profile.OwnedTrails, trailId) then
			table.insert(profile.OwnedTrails, trailId)
		end
		return { ok = true, value = true }

	elseif command.kind == "GrantAura" then
		local auraId = command.auraId
		if typeof(auraId) ~= "string" or auraId == "" then
			return {
				ok = false,
				error = { code = "InvalidInput", message = "Invalid auraId", retryable = false },
			}
		end
		if not table.find(profile.OwnedAuras, auraId) then
			table.insert(profile.OwnedAuras, auraId)
		end
		return { ok = true, value = true }

	elseif command.kind == "GrantUpgrade" then
		local upgradeId = command.upgradeId
		if typeof(upgradeId) ~= "string" or upgradeId == "" then
			return {
				ok = false,
				error = { code = "InvalidInput", message = "Invalid upgradeId", retryable = false },
			}
		end
		if not table.find(profile.OwnedUpgrades, upgradeId) then
			table.insert(profile.OwnedUpgrades, upgradeId)
		end
		return { ok = true, value = true }

	elseif command.kind == "GrantBuff" then
		local grant = command.grant
		if typeof(grant) ~= "table" then
			return {
				ok = false,
				error = { code = "InvalidInput", message = "Invalid buff grant", retryable = false },
			}
		end
		local added = grant.addedSeconds or 0
		if added < 0 or added ~= added or added == math.huge then
			return {
				ok = false,
				error = { code = "InvalidInput", message = "Invalid buff duration", retryable = false },
			}
		end

		if grant.kind == "SpeedPotion" then
			profile.PotionSpeedRemainingSeconds = math.min(86400 * 30, (profile.PotionSpeedRemainingSeconds or 0) + added)
		elseif grant.kind == "WinsPotion" then
			profile.PotionWinsRemainingSeconds = math.min(86400 * 30, (profile.PotionWinsRemainingSeconds or 0) + added)
		end
		return { ok = true, value = true }

	elseif command.kind == "RecordRobuxSpent" then
		local amount = command.amount
		if typeof(amount) ~= "number" or amount ~= amount or amount < 0 or amount == math.huge then
			return {
				ok = false,
				error = { code = "InvalidInput", message = "Invalid Robux amount", retryable = false },
			}
		end
		profile.RobuxSpent = math.min(MAX_SAFE_INTEGER, (profile.RobuxSpent or 0) + amount)
		return { ok = true, value = true }
	end

	return {
		ok = false,
		error = { code = "InvalidInput", message = "Unknown command kind", retryable = false },
	}
end

function ProfileReducers.ApplyPreference(
	profile: ProfileV306,
	key: string,
	value: any
): Result<boolean>
	if key == "MusicVolume" or key == "SfxVolume" then
		if typeof(value) ~= "number" or value ~= value then
			return {
				ok = false,
				error = { code = "InvalidInput", message = "Volume must be a number", retryable = false },
			}
		end
		value = math.clamp(math.floor(value), 0, 100)
	elseif key == "EquippedTrail" or key == "EquippedAura" or key == "EquippedSkin" or key == "WalkSpeedMode" then
		if typeof(value) ~= "string" then
			return {
				ok = false,
				error = { code = "InvalidInput", message = key .. " preference must be a string", retryable = false },
			}
		end
	elseif key == "CustomWalkSpeed" then
		if value ~= nil then
			if typeof(value) ~= "number" or value ~= value then
				return {
					ok = false,
					error = { code = "InvalidInput", message = "CustomWalkSpeed must be a number", retryable = false },
				}
			end
			value = math.clamp(math.floor(value), 8, 300)
		end
	elseif typeof(value) ~= "boolean" then
		return {
			ok = false,
			error = { code = "InvalidInput", message = "Preference value must be boolean", retryable = false },
		}
	end

	local validKeys = {
		Muted = true,
		SoundEffects = true,
		GlobalMessages = true,
		PromptRevivals = true,
		HideHud = true,
		HidePopups = true,
		AcceptGifts = true,
		EventEffects = true,
		MusicVolume = true,
		SfxVolume = true,
		WalkSpeedMode = true,
		CustomWalkSpeed = true,
		EquippedTrail = true,
		EquippedAura = true,
		EquippedSkin = true,
	}

	if not validKeys[key] then
		return {
			ok = false,
			error = { code = "InvalidInput", message = "Unknown setting key: " .. tostring(key), retryable = false },
		}
	end

	if key == "EquippedTrail" then
		profile.EquippedTrail = value
	elseif key == "EquippedAura" then
		profile.EquippedAura = value
	elseif key == "EquippedSkin" then
		profile.EquippedSkin = value
	else
		local settings = profile.Settings :: any
		settings[key] = value
	end
	return { ok = true, value = true }
end

function ProfileReducers.AccrueSpeed(
	profile: ProfileV306,
	wholeAdded: number
): Result<boolean>
	if typeof(wholeAdded) ~= "number" or wholeAdded ~= wholeAdded or wholeAdded <= 0 or wholeAdded == math.huge then
		return {
			ok = false,
			error = { code = "InvalidInput", message = "Invalid speed addition", retryable = false },
		}
	end

	profile.Speed = math.min(SPEED_CAP, (profile.Speed or 0) + wholeAdded)
	return { ok = true, value = true }
end

return ProfileReducers
