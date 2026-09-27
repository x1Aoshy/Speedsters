--!strict
-- src/ServerScriptService/Services/Data/SessionLease.luau
-- Lote R1-04: Gestión de leases con propiedad de token estricta (A -> B -> nil).

export type LeaseAcquireResult = {
	success: boolean,
	reason: string?,
}

export type LeaseSaveResult = {
	success: boolean,
	reason: string?,
}

local SessionLease = {}

local DEFAULT_LEASE_SECONDS = 120
local DEFAULT_RENEW_MARGIN_SECONDS = 30

-- TryAcquire: Adquiere el lease solo si la key no tiene sesión activa o si la existente ya expiró.
function SessionLease.TryAcquire(
	currentData: any,
	sessionId: string,
	nowUnix: number,
	leaseDurationSeconds: number?
): (boolean, any, string?)
	local duration = leaseDurationSeconds or DEFAULT_LEASE_SECONDS

	if type(currentData) == "table" then
		local activeId = currentData.ActiveSessionId
		local expiresUnix = tonumber(currentData.ActiveSessionExpiresUnix) or 0

		-- Si otra sesión posee el lease y aún no ha expirado, rechazar con LeaseBusy
		if activeId ~= nil and activeId ~= sessionId and expiresUnix > nowUnix then
			return false, currentData, "LeaseBusy"
		end

		currentData.ActiveSessionId = sessionId
		currentData.ActiveSessionStartedUnixMs = math.floor(nowUnix * 1000)
		currentData.ActiveSessionExpiresUnix = nowUnix + duration
		return true, currentData, nil
	end

	-- Si currentData es nil (jugador nuevo), la sesión adquiere el lease
	return true, nil, nil
end

-- TryRenewOrSave: Aplica la regla formal 2.
-- REQUIERE IGUALDAD EXACTA de ActiveSessionId con el sessionId actual.
-- Si ActiveSessionId es nil o de otra sesión, el antiguo propietario queda estricta e irrevocablemente RECHAZADO (SessionLost).
function SessionLease.TryRenewOrSave(
	currentData: any,
	sessionId: string,
	nowUnix: number,
	leaseDurationSeconds: number?,
	release: boolean?
): (boolean, any, string?)
	local duration = leaseDurationSeconds or DEFAULT_LEASE_SECONDS

	if type(currentData) ~= "table" then
		return false, currentData, "SessionLost"
	end

	local activeId = currentData.ActiveSessionId
	-- Vector A -> B -> nil: si activeId es nil, o difiere de sessionId, ownership perdido!
	if activeId ~= sessionId then
		return false, currentData, "SessionLost"
	end

	if release == true then
		currentData.ActiveSessionId = nil
		currentData.ActiveSessionStartedUnixMs = nil
		currentData.ActiveSessionExpiresUnix = nil
	else
		currentData.ActiveSessionExpiresUnix = nowUnix + duration
	end

	return true, currentData, nil
end

-- IsExpired: Determina si un timestamp de lease ya caducó
function SessionLease.IsExpired(expiresUnix: number?, nowUnix: number): boolean
	return (expiresUnix or 0) <= nowUnix
end

-- NeedsRenewal: Determina si el lease está próximo a expirar y necesita renovación preventiva
function SessionLease.NeedsRenewal(expiresUnix: number?, nowUnix: number, marginSeconds: number?): boolean
	local margin = marginSeconds or DEFAULT_RENEW_MARGIN_SECONDS
	return ((expiresUnix or 0) - nowUnix) <= margin
end

return SessionLease
