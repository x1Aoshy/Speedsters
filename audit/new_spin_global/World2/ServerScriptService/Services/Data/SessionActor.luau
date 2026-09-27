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

local scheduler = if typeof(script) == "Instance" then task else require("@lune/task")

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
	self._openInProgress = false
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
		buffSampleUnix = self.buffClock or self.clock.UnixNow(),
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

	if self._openInProgress then
		while self._openInProgress do
			scheduler.wait(0.05)
			if deadlineMono and self.clock.MonotonicNow() >= deadlineMono then
				return {
					ok = false,
					error = { code = "DeadlineExceeded", message = "Timeout waiting for ongoing session load", retryable = true },
				}
			end
		end
		if self.state == "Ready" then
			return {
				ok = true,
				value = {
					userId = self.userId,
					sessionId = self.sessionId,
					generation = self.generation,
				},
			}
		else
			return {
				ok = false,
				error = { code = "StoreUnavailable", message = "Session load failed in concurrent attempt", retryable = true },
			}
		end
	end

	self._openInProgress = true
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
		self._openInProgress = false
		self.state = "Closed"
		return {
			ok = false,
			error = { code = "Closing", message = "Player left while loading", retryable = false },
		}
	end

	if not updateResult.ok then
		self._openInProgress = false
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
		self._openInProgress = false
		self.state = "Failed"
		return { ok = false, error = validationError }
	end
	if not leaseAcquired then
		self._openInProgress = false
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
		self._openInProgress = false
		self.state = "Failed"
		return {
			ok = false,
			error = decodeResult.error,
		}
	end

	self.profile = decodeResult.value
	self.leaseExpiresUnix = nowUnix + self.leaseDurationSeconds
	self.state = "Ready"
	self._openInProgress = false

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
function SessionActor:AccrueSpeed(handle: SessionHandle, baseAmount: number, multipliers: any?): any
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
	ProfileReducers.AddQuestProgress(self.profile, "speed", speedResult.value.actualAdded or 0, self.clock.UnixNow())
	self.speedCarry = speedResult.value.values.speedCarry

	local rev = self.saveCoordinator:AdvanceCurrent()
	self:_notifySubscribers()
	return {
		ok = true,
		value = rev,
		whole = speedResult.value.wholeRequested,
		actualAdded = speedResult.value.actualAdded,
	}
end

-- Flush: Escribe a DataStore las revisiones acumuladas si la revisión durable está retrasada.
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

-- Update 2: serialized snapshots and retryable, idempotent writes.
local sequence = 0
local function uniqueId()
	if typeof(script) == "Instance" then return game:GetService("HttpService"):GenerateGUID(false) end
	sequence += 1
	return tostring(os.clock()) .. ":" .. tostring(sequence)
end
local originalNew = SessionActor.new
function SessionActor.new(deps)
	deps = table.clone(deps)
	deps.sessionId = deps.sessionId or uniqueId()
	local actor = originalNew(deps)
	actor.closing = false
	return actor
end

function SessionActor:_resolvePending()
	local pending = self.pendingWrite
	if not pending then return true end
	if self.isEphemeral then
		self.profile = pending.profile
	else
		local lost = false
		local result = self.storeAdapter:UpdateAsync(self.key, function(current)
			lost = false
			-- Confirmation of an earlier applied timeout, including final release.
			if type(current) == "table" and current.Update2WriteId == pending.id then return current end
			if type(current) ~= "table" or current.ActiveSessionId ~= self.sessionId
				or current.Update2WriteId ~= pending.previousId then
				lost = true
				return nil
			end
			local encoded = ProfileCodec.Encode(pending.profile)
			encoded.Update2WriteId = pending.id
			encoded.LastSaveUnix = self.clock.UnixNow()
			encoded.ActiveSessionId = if pending.release then nil else self.sessionId
			encoded.ActiveSessionStartedUnixMs = if pending.release then nil else current.ActiveSessionStartedUnixMs
			encoded.ActiveSessionExpiresUnix = if pending.release then nil else self.clock.UnixNow() + self.leaseDurationSeconds
			return encoded
		end)
		if lost then
			self.state = "Lost"
			self:_notifySubscribers()
			return false, "SessionLost"
		end
		if not result.ok or type(result.value) ~= "table" or result.value.Update2WriteId ~= pending.id then
			self.state = "Recovering"
			self:_notifySubscribers()
			return false, "PersistenceUncertain"
		end
		if not pending.release and result.value.ActiveSessionId ~= self.sessionId then
			self.state = "Lost"
			self:_notifySubscribers()
			return false, "SessionLost"
		end
		self.profile = pending.profile
		self.profile.ActiveSessionId = result.value.ActiveSessionId
		self.profile.ActiveSessionExpiresUnix = result.value.ActiveSessionExpiresUnix
	end
	self.profile.Update2WriteId = pending.id
	self.saveCoordinator:ConfirmDurable(pending.revision)
	if pending.resetCarry then self.speedCarry = 0 end
	self.pendingWrite = nil
	self.leaseExpiresUnix = if pending.release then nil else self.profile.ActiveSessionExpiresUnix or self.clock.UnixNow() + self.leaseDurationSeconds
	self.state = if pending.release then "Released" elseif self.closing then "Quiescing" else "Ready"
	self:_notifySubscribers()
	return true
end

function SessionActor:_writeSnapshot(profile, release, resetCarry)
	assert(not self.pendingWrite, "Pending write must be resolved first")
	local revision = self.saveCoordinator:AdvanceCurrent()
	self.pendingWrite = {
		id = uniqueId(), previousId = self.profile.Update2WriteId,
		profile = deepCopy(profile), release = release == true,
		resetCarry = resetCarry == true, revision = revision,
	}
	return self:_resolvePending()
end

function SessionActor:Commit(handle, request)
	local err = self:_validateHandle(handle)
	if err then return {kind="Rejected", error=err} end
	if self.state == "Lost" then return {kind="Rejected",error={code="SessionLost",message="Session lost",retryable=false}} end
	if self.pendingWrite then
		local ok = self:_resolvePending()
		if not ok then return {kind="Pending",operationId=request.operationId,retryAfterSeconds=1} end
	end
	if self.closing or (self.state ~= "Ready" and self.state ~= "Ephemeral") then return {kind="Rejected",error={code="Closing",message="Session not accepting transactions",retryable=false}} end
	if type(request.operationId) ~= "string" or request.operationId == "" or type(request.fingerprint) ~= "string" then
		return {kind="Rejected",error={code="InvalidInput",message="Operation identity required",retryable=false}}
	end
	local operations = self.profile.Update2Operations or {}
	local existing = operations[request.operationId]
	if request.receiptId and self.profile.ProcessedReceipts[request.receiptId] ~= nil then
		return {kind="AlreadyCommitted",operationId=request.operationId,revision=self.saveCoordinator:GetDurableRevision()}
	end
	if existing then
		if existing.fingerprint ~= request.fingerprint then return {kind="Rejected",error={code="OperationConflict",message="Operation identity conflict",retryable=false}} end
		return {kind="AlreadyCommitted",operationId=request.operationId,revision=self.saveCoordinator:GetDurableRevision()}
	end
	local draft = deepCopy(self.profile)
	local resetCarry = false
	for _,command in ipairs(request.commands) do
		local result = ProfileReducers.ApplyCommand(draft,command,self.clock.UnixNow())
		if not result.ok then return {kind="Rejected",error=result.error} end
		if command.kind == "PerformRebirth" or command.kind == "ResetStats" or command.kind == "WipeProfile" or command.kind == "SetStat" then resetCarry=true end
	end
	draft.Update2Operations = draft.Update2Operations or {}
	draft.Update2Operations[request.operationId] = {fingerprint=request.fingerprint,time=self.clock.UnixNow()}
	-- Normal session operations are bounded. Purchase identities also live in receipts.
	local entries = {}
	for id,entry in pairs(draft.Update2Operations) do table.insert(entries,{id=id,time=entry.time}) end
	table.sort(entries,function(a,b) return a.time > b.time end)
	for i=513,#entries do
		if entries[i].id ~= request.operationId then draft.Update2Operations[entries[i].id]=nil end
	end
	if request.receiptId then draft.ProcessedReceipts[request.receiptId]=self.clock.UnixNow() end
	local ok = self:_writeSnapshot(draft,false,resetCarry)
	if not ok then return {kind="Pending",operationId=request.operationId,retryAfterSeconds=1} end
	return {kind="Committed",operationId=request.operationId,revision=self.saveCoordinator:GetDurableRevision()}
end

function SessionActor:Flush(handle, targetRevision, deadlineMono)
	local err=self:_validateHandle(handle)
	if err then return {kind="Failed",error=err} end
	if self.state=="Lost" then return {kind="Failed",error={code="SessionLost",message="Session lost",retryable=false}} end
	if self.pendingWrite and not self:_resolvePending() then return {kind="Pending",targetRevision=self.saveCoordinator:GetCurrentRevision()} end
	if self.state=="Released" or self.state=="Closed" then return {kind="Skipped",reason="Released"} end
	if not self.profile then return {kind="Failed",error={code="NotReady",message="No loaded profile",retryable=true}} end
	if self.saveCoordinator:GetDurableRevision()>=self.saveCoordinator:GetCurrentRevision()
		and (self.leaseExpiresUnix or 0)-self.clock.UnixNow()>self.leaseDurationSeconds/2 then
		return {kind="Saved",durableRevision=self.saveCoordinator:GetDurableRevision()}
	end
	local ok=self:_writeSnapshot(self.profile,false,false)
	if not ok then return {kind="Pending",targetRevision=self.saveCoordinator:GetCurrentRevision()} end
	return {kind="Saved",durableRevision=self.saveCoordinator:GetDurableRevision()}
end

function SessionActor:Quiesce(handle, reason)
	local err=self:_validateHandle(handle)
	if err then return {ok=false,error=err} end
	self.closing=true
	if self.state=="Loading" then self.quiesceRequestedDuringLoading=true
	elseif self.state=="Ready" then self.state="Quiescing" end
	return {ok=true,value=self.saveCoordinator:GetCurrentRevision()}
end

function SessionActor:Release(handle, deadlineMono)
	local err=self:_validateHandle(handle)
	if err then return {kind="Failed",error=err} end
	self.closing=true
	if self.state=="Lost" then return {kind="Failed",error={code="SessionLost",message="Session lost",retryable=false}} end
	if self.pendingWrite and not self:_resolvePending() then return {kind="Failed",error={code="PersistenceUncertain",message="Final save awaiting confirmation",retryable=true}} end
	if self.state=="Released" or self.state=="Closed" then return {kind="AlreadyReleased",durableRevision=self.saveCoordinator:GetDurableRevision()} end
	if not self.profile then return {kind="Failed",error={code="NotReady",message="Load not complete",retryable=true}} end
	self.profile.LastLogoutTimestamp = self.clock.UnixNow()
	self.saveCoordinator:AdvanceCurrent()
	local ok=self:_writeSnapshot(self.profile,true,false)
	if not ok then return {kind="Failed",error={code="PersistenceUncertain",message="Final save awaiting confirmation",retryable=true}} end
	return {kind="Released",durableRevision=self.saveCoordinator:GetDurableRevision()}
end

-- Notifications run after the critical section; subscribers cannot reenter a draft.
local originalNotify=SessionActor._notifySubscribers
function SessionActor:_notifySubscribers()
	if self.mutationOwner then self.notificationPending=true else originalNotify(self) end
end
for _,methodName in ipairs({"Open","Commit","SetPreference","SetDailyLoginState","AccrueSpeed","Flush","Quiesce","Release"}) do
	local implementation=SessionActor[methodName]
	SessionActor[methodName]=function(self,...)
		while self.mutationOwner do scheduler.wait() end
		self.mutationOwner=true
		local now=self.clock.UnixNow()
		if self.profile and not self.pendingWrite then
			local elapsed=math.max(0,now-(self.buffClock or now))
			local changed=false
			for _,key in {"PotionSpeedRemainingSeconds","PotionWinsRemainingSeconds","TemporaryFlightRemainingSeconds"} do
				local current=self.profile[key] or 0
				if current>0 and elapsed>0 then self.profile[key]=math.max(0,current-elapsed);changed=true end
			end
			if changed then self.saveCoordinator:AdvanceCurrent() end
			self.buffClock=now
		end
		local result=table.pack(pcall(implementation,self,...))
		self.buffClock=self.buffClock or self.clock.UnixNow()
		self.mutationOwner=nil
		if self.notificationPending then
			self.notificationPending=false
			originalNotify(self)
		end
		if not result[1] then error(result[2],0) end
		return table.unpack(result,2,result.n)
	end
end

return SessionActor
