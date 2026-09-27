--!strict
-- src/ServerScriptService/Services/Buffs/BuffService.luau
-- Lote R1-08 / Reto 1: Servicio independiente de administración de buffs y pociones personales.
-- Invariante: NO depende de DataService. Recibe reloj y contratos desacoplados.

local BuffRules
if typeof(script) == "Instance" and script.Parent then
	BuffRules = require(script.Parent.BuffRules)
else
	BuffRules = require("./BuffRules")
end

type BuffKind = BuffRules.BuffKind
type BuffGrant = BuffRules.BuffGrant

type SessionHandle = {
	userId: number,
	sessionId: string,
	generation: number,
}

export type BuffView = {
	kind: BuffKind,
	multiplier: number,
	remainingSeconds: number,
}

export type ServiceError = {
	code: string,
	message: string,
	retryable: boolean,
}

export type Result<T> = { ok: true, value: T } | { ok: false, error: ServiceError }

type ActiveBuffSession = {
	userId: number,
	sessionId: string,
	generation: number,
	attachTimeUnix: number,
	speedRemainingAtAttach: number,
	winsRemainingAtAttach: number,
	speedMultiplier: number,
	winsMultiplier: number,
}

local BuffService = {}
local sessionsByUserId: { [number]: ActiveBuffSession } = {}
local isStarted = false
local clock = {
	UnixNow = function() return os.time() end,
}

function BuffService.SetClock(customClock: { UnixNow: () -> number })
	clock = customClock
end

function BuffService.Start()
	isStarted = true
end

function BuffService.Attach(handle: SessionHandle, snapshot: any)
	local nowUnix = clock.UnixNow()
	local legacy = (snapshot and snapshot.legacy) or snapshot or {}

	local speedSecs = tonumber(legacy.PotionSpeedRemainingSeconds) or 0
	local winsSecs = tonumber(legacy.PotionWinsRemainingSeconds) or 0

	sessionsByUserId[handle.userId] = {
		userId = handle.userId,
		sessionId = handle.sessionId,
		generation = handle.generation,
		attachTimeUnix = nowUnix,
		speedRemainingAtAttach = math.max(0, speedSecs),
		winsRemainingAtAttach = math.max(0, winsSecs),
		speedMultiplier = BuffRules.GetDefaultMultiplier("SpeedPotion"),
		winsMultiplier = BuffRules.GetDefaultMultiplier("WinsPotion"),
	}
end

local function getValidSession(handle: SessionHandle): (ActiveBuffSession?, ServiceError?)
	local session = sessionsByUserId[handle.userId]
	if not session then
		return nil, { code = "NotReady", message = "No active buff session for user", retryable = false }
	end
	if session.sessionId ~= handle.sessionId or session.generation ~= handle.generation then
		return nil, { code = "SessionLost", message = "Stale buff session handle", retryable = false }
	end
	return session, nil
end

function BuffService.Read(handle: SessionHandle, kind: BuffKind): Result<BuffView>
	local session, err = getValidSession(handle)
	if not session then
		return { ok = false, error = err :: ServiceError }
	end

	local nowUnix = clock.UnixNow()
	local elapsed = math.max(0, nowUnix - session.attachTimeUnix)

	local remaining = 0
	local mult = 1.0

	if kind == "SpeedPotion" then
		remaining = math.max(0, session.speedRemainingAtAttach - elapsed)
		mult = (remaining > 0) and session.speedMultiplier or 1.0
	elseif kind == "WinsPotion" then
		remaining = math.max(0, session.winsRemainingAtAttach - elapsed)
		mult = (remaining > 0) and session.winsMultiplier or 1.0
	else
		return {
			ok = false,
			error = { code = "InvalidInput", message = "Unknown buff kind", retryable = false },
		}
	end

	return {
		ok = true,
		value = {
			kind = kind,
			multiplier = mult,
			remainingSeconds = remaining,
		},
	}
end

function BuffService.PrepareGrant(handle: SessionHandle, grant: BuffGrant): Result<any>
	local session, err = getValidSession(handle)
	if not session then
		return { ok = false, error = err :: ServiceError }
	end

	local valid, valErr = BuffRules.ValidateGrant(grant)
	if not valid then
		return {
			ok = false,
			error = { code = "InvalidInput", message = valErr or "Invalid grant", retryable = false },
		}
	end

	return {
		ok = true,
		value = {
			kind = "GrantBuff",
			grant = grant,
		},
	}
end

function BuffService.ExportRemaining(
	handle: SessionHandle,
	nowUnix: number?
): Result<{ speedSeconds: number, winsSeconds: number }>
	local session, err = getValidSession(handle)
	if not session then
		return { ok = false, error = err :: ServiceError }
	end

	local currentNow = nowUnix or clock.UnixNow()
	local elapsed = math.max(0, currentNow - session.attachTimeUnix)

	local sRem = BuffRules.ClampRemaining(session.speedRemainingAtAttach - elapsed)
	local wRem = BuffRules.ClampRemaining(session.winsRemainingAtAttach - elapsed)

	return {
		ok = true,
		value = {
			speedSeconds = sRem,
			winsSeconds = wRem,
		},
	}
end

function BuffService.ApplyCommittedGrant(
	handle: SessionHandle,
	grant: BuffGrant,
	operationId: string,
	committedAtUnix: number
)
	local session = sessionsByUserId[handle.userId]
	if not session then
		return
	end

	local currentNow = clock.UnixNow()
	local elapsed = math.max(0, currentNow - session.attachTimeUnix)

	local currentSpeed = math.max(0, session.speedRemainingAtAttach - elapsed)
	local currentWins = math.max(0, session.winsRemainingAtAttach - elapsed)

	if grant.kind == "SpeedPotion" then
		session.speedRemainingAtAttach = BuffRules.ClampRemaining(currentSpeed + grant.addedSeconds)
		session.winsRemainingAtAttach = currentWins
	elseif grant.kind == "WinsPotion" then
		session.speedRemainingAtAttach = currentSpeed
		session.winsRemainingAtAttach = BuffRules.ClampRemaining(currentWins + grant.addedSeconds)
	end
	session.attachTimeUnix = currentNow
end

function BuffService.Detach(handle: SessionHandle)
	local session = sessionsByUserId[handle.userId]
	if session and session.sessionId == handle.sessionId then
		sessionsByUserId[handle.userId] = nil
	end
end

function BuffService.Destroy()
	sessionsByUserId = {}
	isStarted = false
end

function BuffService.GetActiveSessionCount(): number
	local count = 0
	for _ in pairs(sessionsByUserId) do
		count = count + 1
	end
	return count
end

return BuffService
