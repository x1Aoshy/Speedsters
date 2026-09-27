--!strict
-- src/ServerScriptService/Services/Data/SessionActor.luau
-- Lote R1-04: Actor de sesión con FSM formal de 9 estados, ownership estricto y reloj inyectable.

local ProfileCodec
local SessionLease
local ProfileReducers
local SaveCoordinator
local RetryPolicy
local DataStoreAdapter
local StatsService = if typeof(script) == "Instance" then require(script.Parent.Parent.Stats.StatsService) else require("../Stats/StatsService")

if typeof(script) == "Instance" and script.Parent then
	ProfileCodec = require(script.Parent.ProfileCodec)
	SessionLease = require(script.Parent.SessionLease)
	ProfileReducers = require(script.Parent.ProfileReducers)
	SaveCoordinator = require(script.Parent.SaveCoordinator)
	RetryPolicy = require(script.Parent.RetryPolicy)
	DataStoreAdapter = require(script.Parent.DataStoreAdapter)
else
	ProfileCodec = require("./ProfileCodec")
	SessionLease = require("./SessionLease")
	ProfileReducers = require("./ProfileReducers")
	SaveCoordinator = require("./SaveCoordinator")
	RetryPolicy = require("./RetryPolicy")
	DataStoreAdapter = require("./DataStoreAdapter")
end

type ProfileV306 = ProfileCodec.ProfileV306
type EconomyCommand = ProfileReducers.EconomyCommand
type RetryPolicyConfig = RetryPolicy.RetryPolicyConfig
type DataStoreAdapterInterface = DataStoreAdapter.DataStoreAdapterInterface

export type SessionState =
	"Loading"
	| "Ready"
	| "Recovering"
	| "Quiescing"
	| "Released"
	| "Lost"
	| "Failed"
	| "Closed"
	| "Ephemeral"

export type ErrorCode =
	"NotReady"
	| "Closing"
	| "SessionLost"
	| "LeaseBusy"
	| "InvalidInput"
	| "InsufficientFunds"
	| "QueueFull"
	| "DeadlineExceeded"
	| "StoreUnavailable"
	| "PersistenceUncertain"
	| "SchemaUnsupported"
	| "OperationConflict"
	| "InternalError"

export type ServiceError = {
	code: ErrorCode,
	message: string,
	retryable: boolean,
	operationId: string?,
}

export type Result<T> = { ok: true, value: T } | { ok: false, error: ServiceError }

export type SessionHandle = {
	userId: number,
	sessionId: string,
	generation: number,
}

export type AppliedOperation = {
	id: string,
	fingerprint: string,
	appliedRevision: number,
	committedAtUnix: number,
}

export type SessionView = {
	handle: SessionHandle,
	state: SessionState,
	durableRevision: number,
	leaseExpiresUnix: number?,
	profile: ProfileV306?,
}

export type TransactionRequest = {
	operationId: string,
	fingerprint: string,
	expectedRevision: number?,
	commands: { EconomyCommand },
	deadlineMono: number?,
}

export type CommitResult =
	{ kind: "Committed", operationId: string, revision: number }
	| { kind: "AlreadyCommitted", operationId: string, revision: number }
	| { kind: "Rejected", error: ServiceError }
	| { kind: "Pending", operationId: string, retryAfterSeconds: number }

export type SaveResult =
	{ kind: "Saved", durableRevision: number }
	| { kind: "Skipped", reason: "Clean" | "Ephemeral" | "Released" }
	| { kind: "Failed", error: ServiceError }
	| { kind: "Pending", targetRevision: number }

export type ReleaseResult =
	{ kind: "Released", durableRevision: number }
	| { kind: "AlreadyReleased", durableRevision: number }
	| { kind: "Failed", error: ServiceError }

export type Clock = {
	UnixNow: () -> number,
	MonotonicNow: () -> number,
}

export type ActorDependencies = {
	userId: number,
	sessionId: string?,
	storeAdapter: DataStoreAdapterInterface,
	clock: Clock?,
	retryPolicy: RetryPolicyConfig?,
	leaseDurationSeconds: number?,
	keyPrefix: string?,
	isEphemeral: boolean?,
}

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in pairs(value) do
		copy[k] = deepCopy(v)
	end
	return copy
end

local SessionActor = {}
SessionActor.__index = SessionActor

function SessionActor.new(deps: ActorDependencies)
	local self = setmetatable({}, SessionActor)

	self.userId = deps.userId
	self.sessionId = deps.sessionId or string.format("session_%d_%d_%d", deps.userId, os.time(), math.random(1000, 9999))
	self.generation = 1
	self.storeAdapter = deps.storeAdapter
	self.clock = deps.clock or {
		UnixNow = function()
			return os.time()
		end,
		MonotonicNow = function()
			return os.clock()
		end,
	}
	self.retryPolicy = deps.retryPolicy or RetryPolicy.CreateDefault()
	self.leaseDurationSeconds = deps.leaseDurationSeconds or 120
	self.keyPrefix = deps.keyPrefix or "Player_"
	self.key = self.keyPrefix .. tostring(self.userId)
	self.isEphemeral = deps.isEphemeral or false

	self.state = (self.isEphemeral and "Ephemeral" or "Loading") :: SessionState
	self.profile = nil :: ProfileV306?
	self.speedCarry = 0
	self.leaseExpiresUnix = nil :: number?
	self.saveCoordinator = SaveCoordinator.new(1)
	self.appliedOperations = {} :: { [string]: AppliedOperation }
	self.subscribers = {} :: { (SessionView) -> () }

	-- Control flags
	self.quiesceRequestedDuringLoading = false
	self.isProcessingQueue = false
	self.queue = {} :: { () -> () }

	return self
end

function SessionActor:_validateHandle(handle: SessionHandle): ServiceError?
	if handle.userId ~= self.userId then
		return { code = "SessionLost", message = "UserId mismatch", retryable = false }
	end
	if handle.sessionId ~= self.sessionId then
		return { code = "SessionLost", message = "SessionId mismatch", retryable = false }
	end
	if handle.generation ~= self.generation then
		return { code = "SessionLost", message = "Stale generation", retryable = false }
	end
	return nil
end

function SessionActor:_notifySubscribers()
	local view = self:_buildView()
	for _, sub in ipairs(self.subscribers) do
		pcall(sub, view)
	end
end

function SessionActor:_buildView(): SessionView
	return {
		handle = {
			userId = self.userId,
			sessionId = self.sessionId,
			generation = self.generation,
		},
		state = self.state,
		durableRevision = self.saveCoordinator:GetDurableRevision(),
		leaseExpiresUnix = self.leaseExpiresUnix,
		profile = self.profile and deepCopy(self.profile) or nil,
	}
end

-- Open: Inicia la adquisición del perfil y el lease.
function SessionActor:Open(deadlineMono: number?): Result<SessionHandle>
	if self.state == "Ready" then
		return {
			ok = true,
			value = {
				userId = self.userId,
				sessionId = self.sessionId,
				generation = self.generation,
			},
		}
	end

	if self.isEphemeral then
		self.state = "Ready"
		self.profile = ProfileCodec.CreateDefault()
		return {
			ok = true,
			value = {
				userId = self.userId,
				sessionId = self.sessionId,
				generation = self.generation,
			},
		}
	end

	self.state = "Loading"
	local nowUnix = self.clock.UnixNow()
	local leaseAcquired = false
	local storeDataToDecode: any = nil
	local acquireError: string? = nil
	local validationError: any = nil

	-- UpdateAsync para adquirir lease atómicamente
	local updateResult = self.storeAdapter:UpdateAsync(self.key, function(current)
		-- Roblox can invoke this callback again after contention. Reset all results.
		leaseAcquired = false
		acquireError = nil
		validationError = nil
		local decoded = ProfileCodec.Decode(current)
		if not decoded.ok then
			validationError = decoded.error
			return nil -- Preserve corrupt/future data verbatim, never replace by defaults.
		end
		local success, modified, errReason = SessionLease.TryAcquire(
			current,
			self.sessionId,
			nowUnix,
			self.leaseDurationSeconds
		)
		if success then
			leaseAcquired = true
			if modified == nil then
				-- Jugador nuevo: creamos default
				local defaultProfile = ProfileCodec.CreateDefault()
				defaultProfile.ActiveSessionId = self.sessionId
				defaultProfile.ActiveSessionStartedUnixMs = math.floor(nowUnix * 1000)
				defaultProfile.ActiveSessionExpiresUnix = nowUnix + self.leaseDurationSeconds
				return defaultProfile
			else
				return modified
			end
		else
			acquireError = errReason
			return nil -- Cancela actualización
		end
	end)

	-- Comprobar si el jugador solicitó salir durante el yield de carga
	if self.quiesceRequestedDuringLoading then
		if leaseAcquired then
			-- Liberamos de inmediato el token recién adquirido
			self.storeAdapter:UpdateAsync(self.key, function(current)
				local ok, released = SessionLease.TryRenewOrSave(
					current,
					self.sessionId,
					nowUnix,
					self.leaseDurationSeconds,
					true
				)
				return ok and released or nil
			end)
		end
		self.state = "Closed"
		return {
			ok = false,
			error = { code = "Closing", message = "Player left while loading", retryable = false },
		}
	end

	if not updateResult.ok then
		self.state = "Failed"
		return {
			ok = false,
			error = {
				code = "StoreUnavailable",
				message = updateResult.error or "Store unavailable during open",
				retryable = true,
			},
		}
	end

	if validationError then
		self.state = "Failed"
		return { ok = false, error = validationError }
	end
	if not leaseAcquired then
		self.state = "Failed"
		local code: ErrorCode = (acquireError == "LeaseBusy") and "LeaseBusy" or "StoreUnavailable"
		return {
			ok = false,
			error = {
				code = code,
				message = acquireError or "Failed to acquire session lease",
				retryable = (code == "LeaseBusy"),
			},
		}
	end

	-- Decodificar y normalizar con ProfileCodec
	storeDataToDecode = updateResult.value
	local decodeResult = ProfileCodec.Decode(storeDataToDecode)
	if not decodeResult.ok then
		-- Error en esquema o corrupción fatal: liberar lease y marcar Failed
		self.storeAdapter:UpdateAsync(self.key, function(current)
			local ok, released = SessionLease.TryRenewOrSave(
				current,
				self.sessionId,
				nowUnix,
				self.leaseDurationSeconds,
				true
			)
			return ok and released or nil
		end)
		self.state = "Failed"
		return {
			ok = false,
			error = decodeResult.error,
		}
	end

	self.profile = decodeResult.value
	self.leaseExpiresUnix = nowUnix + self.leaseDurationSeconds
	self.state = "Ready"

	return {
		ok = true,
		value = {
			userId = self.userId,
			sessionId = self.sessionId,
			generation = self.generation,
		},
	}
end

-- Inspect: Retorna una vista inmutable y profunda de la sesión.
function SessionActor:Inspect(handle: SessionHandle): Result<SessionView>
	local err = self:_validateHandle(handle)
	if err then
		return { ok = false, error = err }
	end
	return { ok = true, value = self:_buildView() }
end

-- Commit: Ejecuta una transacción económica con deduplicación y persistencia atómica.
function SessionActor:Commit(handle: SessionHandle, request: TransactionRequest): CommitResult
	local err = self:_validateHandle(handle)
	if err then
		return { kind = "Rejected", error = err }
	end

	if self.state == "Quiescing" or self.state == "Released" or self.state == "Closed" then
		return {
			kind = "Rejected",
			error = { code = "Closing", message = "Actor is shutting down", retryable = false },
		}
	end

	if self.state == "Lost" then
		return {
			kind = "Rejected",
			error = { code = "SessionLost", message = "Session ownership lost", retryable = false },
		}
	end

	if self.state == "Recovering" then
		return {
			kind = "Pending",
			operationId = request.operationId,
			retryAfterSeconds = 1.0,
		}
	end

	if self.state ~= "Ready" and self.state ~= "Ephemeral" then
		return {
			kind = "Rejected",
			error = { code = "NotReady", message = "Actor state is " .. self.state, retryable = true },
		}
	end

	-- Deduplicación de operación
	local existing = self.appliedOperations[request.operationId]
	if existing then
		if existing.fingerprint == request.fingerprint then
			return {
				kind = "AlreadyCommitted",
				operationId = request.operationId,
				revision = existing.appliedRevision,
			}
		else
			return {
				kind = "Rejected",
				error = {
					code = "OperationConflict",
					message = "Operation ID reused with conflicting fingerprint",
					retryable = false,
					operationId = request.operationId,
				},
			}
		end
	end

	if not self.profile then
		return {
			kind = "Rejected",
			error = { code = "InternalError", message = "Profile not initialized", retryable = false },
		}
	end

	-- Clonar draft para evaluar reducers en memoria
	local draft = deepCopy(self.profile)
	local nowUnix = self.clock.UnixNow()

	for _, cmd in ipairs(request.commands) do
		local cmdResult = ProfileReducers.ApplyCommand(draft, cmd, nowUnix)
		if not cmdResult.ok then
			return {
				kind = "Rejected",
				error = cmdResult.error,
			}
		end
	end

	-- Si es modo efímero (testing sin persistencia), confirmamos en memoria
	if self.isEphemeral then
		self.profile = draft
		for _, command in ipairs(request.commands) do
			if command.kind == "PerformRebirth" then self.speedCarry = 0 end
		end
		local nextRev = self.saveCoordinator:AdvanceCurrent()
		self.saveCoordinator:ConfirmDurable(nextRev)
		self.appliedOperations[request.operationId] = {
			id = request.operationId,
			fingerprint = request.fingerprint,
			appliedRevision = nextRev,
			committedAtUnix = nowUnix,
		}
		self:_notifySubscribers()
		return {
			kind = "Committed",
			operationId = request.operationId,
			revision = nextRev,
		}
	end

	-- Persistencia durable en DataStore
	local nextRev = self.saveCoordinator:AdvanceCurrent()
	local isLost = false

	local storeResult = self.storeAdapter:UpdateAsync(self.key, function(current)
		local ok, saved, leaseErr = SessionLease.TryRenewOrSave(
			current,
			self.sessionId,
			nowUnix,
			self.leaseDurationSeconds,
			false
		)
		if not ok then
			if leaseErr == "SessionLost" then
				isLost = true
			end
			return nil
		end

		-- Codificar draft para persistencia
		local toSave = ProfileCodec.Encode(draft)
		toSave.ActiveSessionId = self.sessionId
		toSave.ActiveSessionStartedUnixMs = current.ActiveSessionStartedUnixMs
		toSave.ActiveSessionExpiresUnix = nowUnix + self.leaseDurationSeconds
		toSave.LastSaveUnix = nowUnix
		return toSave
	end)

	if isLost then
		self.state = "Lost"
		return {
			kind = "Rejected",
			error = { code = "SessionLost", message = "Session ownership lost in store", retryable = false },
		}
	end

	if not storeResult.ok then
		if storeResult.isUncertain then
			-- Timeout / resultado incierto: entramos a Recovering y retornamos Pending
			self.state = "Recovering"
			return {
				kind = "Pending",
				operationId = request.operationId,
				retryAfterSeconds = 1.0,
			}
		else
			return {
				kind = "Rejected",
				error = {
					code = "StoreUnavailable",
					message = storeResult.error or "DataStore write failed",
					retryable = true,
				},
			}
		end
	end

	-- Confirmación exitosa
	self.profile = draft
	for _, command in ipairs(request.commands) do
		if command.kind == "PerformRebirth" then self.speedCarry = 0 end
	end
	self.leaseExpiresUnix = nowUnix + self.leaseDurationSeconds
	self.saveCoordinator:ConfirmDurable(nextRev)
	self.appliedOperations[request.operationId] = {
		id = request.operationId,
		fingerprint = request.fingerprint,
		appliedRevision = nextRev,
		committedAtUnix = nowUnix,
	}

	self:_notifySubscribers()

	return {
		kind = "Committed",
		operationId = request.operationId,
		revision = nextRev,
	}
end

-- SetPreference: Actualiza configuración con coalescencia en memoria sin yield de guardado inmediato.
function SessionActor:SetPreference(handle: SessionHandle, key: string, value: boolean): Result<number>
	local err = self:_validateHandle(handle)
	if err then
		return { ok = false, error = err }
	end

	if self.state ~= "Ready" and self.state ~= "Ephemeral" then
		return {
			ok = false,
			error = { code = "NotReady", message = "Cannot set preference in state " .. self.state, retryable = true },
		}
	end

	if not self.profile then
		return {
			ok = false,
			error = { code = "InternalError", message = "Profile not initialized", retryable = false },
		}
	end

	local prefResult = ProfileReducers.ApplyPreference(self.profile, key, value)
	if not prefResult.ok then
		return { ok = false, error = prefResult.error }
	end

	local rev = self.saveCoordinator:AdvanceCurrent()
	self:_notifySubscribers()
	return { ok = true, value = rev }
end

-- SetDailyLoginState: Actualiza el estado del daily reward en memoria con persistencia durable.
function SessionActor:SetDailyLoginState(handle: SessionHandle, dailyState: any): Result<number>
	local err = self:_validateHandle(handle)
	if err then
		return { ok = false, error = err }
	end

	if self.state ~= "Ready" and self.state ~= "Ephemeral" then
		return {
			ok = false,
			error = { code = "NotReady", message = "Cannot set daily login state in state " .. self.state, retryable = true },
		}
	end

	if not self.profile then
		return {
			ok = false,
			error = { code = "InternalError", message = "Profile not initialized", retryable = false },
		}
	end

	local claimedDaysCopy = {}
	if type(dailyState) == "table" and type(dailyState.ClaimedDays) == "table" then
		for _, day in ipairs(dailyState.ClaimedDays) do
			local d = tonumber(day)
			if d then
				table.insert(claimedDaysCopy, d)
			end
		end
	end

	self.profile.DailyLoginState = {
		ClaimedDays = claimedDaysCopy,
		LastClaimAt = math.max(0, tonumber(dailyState and dailyState.LastClaimAt) or 0),
		LastClaimedDay = math.clamp(math.floor(tonumber(dailyState and dailyState.LastClaimedDay) or 0), 0, 31),
		Cycle = math.max(1, math.floor(tonumber(dailyState and dailyState.Cycle) or 1)),
	}

	local rev = self.saveCoordinator:AdvanceCurrent()
	self:_notifySubscribers()
	return { ok = true, value = rev }
end

-- AccrueSpeed: Acumula velocidad calculada en memoria con coalescencia.
function SessionActor:AccrueSpeed(handle: SessionHandle, baseAmount: number, multipliers: any?): Result<number>
	local err = self:_validateHandle(handle)
	if err then
		return { ok = false, error = err }
	end

	if self.state ~= "Ready" and self.state ~= "Ephemeral" then
		return {
			ok = false,
			error = { code = "NotReady", message = "Cannot accrue speed in state " .. self.state, retryable = true },
		}
	end

	if not self.profile then
		return {
			ok = false,
			error = { code = "InternalError", message = "Profile not initialized", retryable = false },
		}
	end

	local speedResult = StatsService.CalculateSpeedGain({
		speed = self.profile.Speed, wins = self.profile.Wins, rebirths = self.profile.Rebirths,
		speedCarry = self.speedCarry,
	}, baseAmount, multipliers)
	if not speedResult.ok then
		return { ok = false, error = speedResult.error }
	end
	self.profile.Speed = speedResult.value.values.speed
	self.speedCarry = speedResult.value.values.speedCarry

	local rev = self.saveCoordinator:AdvanceCurrent()
	self:_notifySubscribers()
	return { ok = true, value = rev }
end

-- Flush: Escribe a DataStore las revisiones acumuladas si la revisión durable está retrasada.
function SessionActor:Flush(handle: SessionHandle, targetRevision: number?, deadlineMono: number?): SaveResult
	local err = self:_validateHandle(handle)
	if err then
		return { kind = "Failed", error = err }
	end

	local target = targetRevision or self.saveCoordinator:GetCurrentRevision()
	if self.saveCoordinator:GetDurableRevision() >= target
		and (self.isEphemeral or (self.leaseExpiresUnix or 0) - self.clock.UnixNow() > self.leaseDurationSeconds / 2) then
		return { kind = "Saved", durableRevision = self.saveCoordinator:GetDurableRevision() }
	end

	if self.isEphemeral then
		self.saveCoordinator:ConfirmDurable(target)
		return { kind = "Skipped", reason = "Ephemeral" }
	end

	if self.state == "Released" or self.state == "Closed" then
		return { kind = "Skipped", reason = "Released" }
	end

	local nowUnix = self.clock.UnixNow()
	local isLost = false

	local storeResult = self.storeAdapter:UpdateAsync(self.key, function(current)
		local ok, saved, leaseErr = SessionLease.TryRenewOrSave(
			current,
			self.sessionId,
			nowUnix,
			self.leaseDurationSeconds,
			false
		)
		if not ok then
			if leaseErr == "SessionLost" then
				isLost = true
			end
			return nil
		end

		local toSave = ProfileCodec.Encode(self.profile :: ProfileV306)
		toSave.ActiveSessionId = self.sessionId
		toSave.ActiveSessionStartedUnixMs = current.ActiveSessionStartedUnixMs
		toSave.ActiveSessionExpiresUnix = nowUnix + self.leaseDurationSeconds
		toSave.LastSaveUnix = nowUnix
		return toSave
	end)

	if isLost then
		self.state = "Lost"
		return {
			kind = "Failed",
			error = { code = "SessionLost", message = "Session ownership lost during flush", retryable = false },
		}
	end

	if not storeResult.ok then
		if storeResult.isUncertain then
			self.state = "Recovering"
			return { kind = "Pending", targetRevision = target }
		else
			return {
				kind = "Failed",
				error = {
					code = "StoreUnavailable",
					message = storeResult.error or "Flush failed",
					retryable = true,
				},
			}
		end
	end

	self.leaseExpiresUnix = nowUnix + self.leaseDurationSeconds
	self.saveCoordinator:ConfirmDurable(target)
	return { kind = "Saved", durableRevision = self.saveCoordinator:GetDurableRevision() }
end

-- Quiesce: Cierra la admisión de nuevas mutaciones de valor y prepara el cierre.
function SessionActor:Quiesce(handle: SessionHandle, reason: string?): Result<number>
	local err = self:_validateHandle(handle)
	if err then
		return { ok = false, error = err }
	end

	if self.state == "Loading" then
		self.quiesceRequestedDuringLoading = true
		return { ok = true, value = self.saveCoordinator:GetCurrentRevision() }
	end

	self.state = "Quiescing"
	return { ok = true, value = self.saveCoordinator:GetCurrentRevision() }
end

-- Release: Realiza el último guardado y libera el lease atómicamente en una sola llamada.
function SessionActor:Release(handle: SessionHandle, deadlineMono: number?): ReleaseResult
	local err = self:_validateHandle(handle)
	if err then
		return { kind = "Failed", error = err }
	end

	if self.state == "Released" or self.state == "Closed" then
		return { kind = "AlreadyReleased", durableRevision = self.saveCoordinator:GetDurableRevision() }
	end

	if self.isEphemeral then
		self.state = "Released"
		return { kind = "Released", durableRevision = self.saveCoordinator:GetDurableRevision() }
	end

	local nowUnix = self.clock.UnixNow()
	local isLost = false

	local storeResult = self.storeAdapter:UpdateAsync(self.key, function(current)
		local ok, saved, leaseErr = SessionLease.TryRenewOrSave(
			current,
			self.sessionId,
			nowUnix,
			self.leaseDurationSeconds,
			true -- release = true!
		)
		if not ok then
			if leaseErr == "SessionLost" then
				isLost = true
			end
			return nil
		end

		if self.profile then
			local toSave = ProfileCodec.Encode(self.profile)
			toSave.ActiveSessionId = nil
			toSave.ActiveSessionStartedUnixMs = nil
			toSave.ActiveSessionExpiresUnix = nil
			toSave.LastSaveUnix = nowUnix
			return toSave
		end

		return saved
	end)

	if isLost then
		self.state = "Lost"
		return {
			kind = "Failed",
			error = { code = "SessionLost", message = "Session lost during release", retryable = false },
		}
	end

	if not storeResult.ok then
		return {
			kind = "Failed",
			error = {
				code = "StoreUnavailable",
				message = storeResult.error or "Failed to release lease",
				retryable = true,
			},
		}
	end

	self.state = "Released"
	self.leaseExpiresUnix = nil
	self.saveCoordinator:ConfirmDurable(self.saveCoordinator:GetCurrentRevision())

	return { kind = "Released", durableRevision = self.saveCoordinator:GetDurableRevision() }
end

-- Subscribe: Registra un observador de cambios en el estado del SessionView.
function SessionActor:Subscribe(handle: SessionHandle, listener: (SessionView) -> ()): () -> ()
	local err = self:_validateHandle(handle)
	if err then
		return function() end
	end

	table.insert(self.subscribers, listener)

	-- Retorna función de desconexión
	return function()
		local idx = table.find(self.subscribers, listener)
		if idx then
			table.remove(self.subscribers, idx)
		end
	end
end

-- Destroy: Destrucción idempotente de recursos locales.
function SessionActor:Destroy()
	self.state = "Closed"
	self.subscribers = {}
	self.appliedOperations = {}
	self.profile = nil
end

-- DataStore yields must not let another mutation install a competing snapshot.
local scheduler = if typeof(script) == "Instance" then task else require("@lune/task")
for _, methodName in ipairs({ "Commit", "SetPreference", "AccrueSpeed", "Flush", "Quiesce", "Release" }) do
	local implementation = SessionActor[methodName]
	SessionActor[methodName] = function(self, ...)
		local thread = coroutine.running()
		while self.mutationOwner and self.mutationOwner ~= thread do scheduler.wait() end
		local ownsLock = self.mutationOwner == nil
		if ownsLock then self.mutationOwner = thread end
		local result = table.pack(pcall(implementation, self, ...))
		if ownsLock then self.mutationOwner = nil end
		if not result[1] then error(result[2], 0) end
		return table.unpack(result, 2, result.n)
	end
end

return SessionActor
