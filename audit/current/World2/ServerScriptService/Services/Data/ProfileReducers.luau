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

	elseif command.kind == "RemoveUpgrade" then
		local upgradeId = command.upgradeId
		if typeof(upgradeId) == "string" and upgradeId ~= "" then
			local idx = table.find(profile.OwnedUpgrades, upgradeId)
			if idx then
				table.remove(profile.OwnedUpgrades, idx)
			end
		end
		return { ok = true, value = true }

	elseif command.kind == "RemoveSkin" then
		local skinId = command.skinId
		if typeof(skinId) == "string" and skinId ~= "" then
			local idx = table.find(profile.OwnedSkins, skinId)
			if idx then
				table.remove(profile.OwnedSkins, idx)
			end
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

local originalApplyCommand=ProfileReducers.ApplyCommand
function ProfileReducers.ApplyCommand(profile,command,nowUnix)
	local function invalid(message) return {ok=false,error={code="InvalidInput",message=message,retryable=false}} end
	local function finite(n) return type(n)=="number" and n==n and math.abs(n)~=math.huge end
	if command.kind=="SetPersistent" then
		local key,value=command.key,command.value
		local booleans={World2Unlocked=true,FirstTimeTutorialSeen=true,StarterPackGranted=true}
		local numbers={PermanentBaseSpeedMultiplier=true,PermanentWinsMultiplier=true,GlobalSpeedGainMultiplier=true,TrailSpeedGainMultiplier=true,UpgradeSpeedGainMultiplier=true,GamepassSpeedGainMultiplier=true,LastSeenUpdateLog=true,StarterPackRewardVersion=true}
		if booleans[key] then
			if type(value)~="boolean" then return invalid("Expected boolean") end
			profile[key]=if command.allowFalse then value else (profile[key]==true or value)
		elseif numbers[key] then
			if not finite(value) or value<0 then return invalid("Expected finite nonnegative number") end
			profile[key]=if command.monotonic then math.max(profile[key] or 0,value) else value
		else return invalid("Persistent field is not writable") end
		return {ok=true,value=true}
	elseif command.kind=="PurchaseSpeed" then
		local tier=command.tier
		local multiplier=tonumber(tier.GainMultiplier) or 0
		local minGain=tonumber(tier.MinGain) or ({500,2500,10000,50000})[tier.Tier or 1] or 100
		if not finite(multiplier) or multiplier<0 or not finite(minGain) or minGain<0 then return invalid("Invalid speed purchase") end
		local value=profile.Speed*multiplier
		local rounded=0
		if value>0 then
			if value<1000 then rounded=if value>=10 then math.max(10,math.round(value/10)*10) else math.max(1,math.floor(value+0.5))
			else
				local base=1000^math.floor(math.log10(value)/3)
				local scaled=value/base
				rounded=(if scaled>=10 then math.max(10,math.round(scaled/10)*10) else math.max(1,math.floor(scaled)))*base
			end
		end
		profile.Speed=math.min(1e50,profile.Speed+math.max(minGain,rounded))
		return {ok=true,value=true}
	elseif command.kind=="PurchaseMultiplier" then
		if command.key~="PermanentBaseSpeedMultiplier" and command.key~="PermanentWinsMultiplier" then return invalid("Invalid multiplier") end
		local current=profile[command.key] or 1
		local target=command.target
		if not finite(target) or target<1 then return invalid("Invalid target") end
		local nextValue=math.max(current,target)
		if command.repeatAdd and current>=target then
			if not finite(command.repeatAdd) or command.repeatAdd<0 then return invalid("Invalid increment") end
			nextValue=math.max(current,math.min(command.cap or 1e50,current+command.repeatAdd))
		end
		profile[command.key]=nextValue
		return {ok=true,value=true}
	elseif command.kind=="RecordReceipt" then
		if type(command.receiptId)~="string" or command.receiptId=="" then return invalid("Receipt identity required") end
		profile.ProcessedReceipts[command.receiptId]=nowUnix
		return {ok=true,value=true}
	elseif command.kind=="GrantStarterPack" then
		if (profile.StarterPackRewardVersion or 0)>=command.version then return {ok=true,value=true} end
		local speed,wins=command.speed,command.wins
		if profile.StarterPackGranted then
			speed=math.max(0,speed-(command.legacySpeed or 0));wins=math.max(0,wins-(command.legacyWins or 0))
		end
		profile.Speed=math.min(1e50,profile.Speed+speed)
		profile.Wins=math.min(9007199254740991,profile.Wins+wins)
		if not table.find(profile.OwnedTrails,command.trailId) then table.insert(profile.OwnedTrails,command.trailId) end
		profile.StarterPackGranted=true;profile.StarterPackRewardVersion=command.version
		return {ok=true,value=true}
	end
	if command.kind=="SetDailyState" then
		local state=command.state
		if type(state)~="table" or type(state.ClaimedDays)~="table" or not finite(state.LastClaimAt) or not finite(state.Cycle) then return invalid("Invalid daily state") end
		profile.DailyLoginState={ClaimedDays=table.clone(state.ClaimedDays),LastClaimAt=state.LastClaimAt,LastClaimedDay=state.LastClaimedDay,Cycle=state.Cycle}
		return {ok=true,value=true}
	elseif command.kind=="SetGiftContext" then
		if type(command.productId)~="string" or type(command.targetUserId)~="number" then return invalid("Invalid gift context") end
		profile.Update2GiftContexts=profile.Update2GiftContexts or {}
		profile.Update2GiftContexts[command.productId]=if command.targetUserId>0 then command.targetUserId else nil
		return {ok=true,value=true}
	elseif command.kind=="GrantBuff" then
		local grant=command.grant
		if type(grant)~="table" or not finite(grant.multiplier) or grant.multiplier<1 then return invalid("Invalid potion multiplier") end
		local result=originalApplyCommand(profile,command,nowUnix)
		if result.ok then
			local prefix=if grant.kind=="SpeedPotion" then "PotionSpeed" else "PotionWins"
			profile[prefix.."Multiplier"]=math.max(profile[prefix.."Multiplier"] or 1,grant.multiplier)
			profile[prefix.."BottleType"]=tostring(grant.bottleType or "Small")
		end
		return result
	end
	return originalApplyCommand(profile,command,nowUnix)
end

return ProfileReducers
