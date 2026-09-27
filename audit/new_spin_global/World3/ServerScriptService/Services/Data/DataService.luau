--!strict
-- src/ServerScriptService/Services/Data/DataService.luau
-- Lote R1-05: Fachada central y orquestador de sesiones de perfiles de usuario.
-- Implementa estrictamente la interfaz DataServiceAPI de Types.luau.

local SessionActor
local DataStoreAdapter
local RetryPolicy

if typeof(script) == "Instance" and script.Parent then
	SessionActor = require(script.Parent.SessionActor)
	DataStoreAdapter = require(script.Parent.DataStoreAdapter)
	RetryPolicy = require(script.Parent.RetryPolicy)
else
	SessionActor = require("./SessionActor")
	DataStoreAdapter = require("./DataStoreAdapter")
	RetryPolicy = require("./RetryPolicy")
end

type SessionHandle = SessionActor.SessionHandle
type SessionView = SessionActor.SessionView
type TransactionRequest = SessionActor.TransactionRequest
type CommitResult = SessionActor.CommitResult
type SaveResult = SessionActor.SaveResult
type ReleaseResult = SessionActor.ReleaseResult
type ServiceError = SessionActor.ServiceError
type Result<T> = SessionActor.Result<T>
type Clock = SessionActor.Clock
type DataStoreAdapterInterface = DataStoreAdapter.DataStoreAdapterInterface
type RetryPolicyConfig = RetryPolicy.RetryPolicyConfig

export type DataServiceOptions = {
	storeAdapter: DataStoreAdapterInterface?,
	clock: Clock?,
	retryPolicy: RetryPolicyConfig?,
	leaseDurationSeconds: number?,
	keyPrefix: string?,
	isEphemeral: boolean?,
}

local DataService = {}

local storeAdapter: DataStoreAdapterInterface? = nil
local clock: Clock? = nil
local retryPolicy: RetryPolicyConfig? = nil
local leaseDurationSeconds: number = 120
local keyPrefix: string = "Player_"
local isEphemeral: boolean = false
local isStarted: boolean = false

local actorsByUserId: { [number]: any } = {}

-- Init: Configura dependencias (inyección para pruebas o valores por defecto para producción).
function DataService.Init(options: DataServiceOptions?)
	for _, actor in pairs(actorsByUserId) do
		actor:Destroy()
	end
	actorsByUserId = {}

	local opts = options or {}
	storeAdapter = opts.storeAdapter
	clock = opts.clock or {
		UnixNow = function()
			return os.time()
		end,
		MonotonicNow = function()
			return os.clock()
		end,
	}
	retryPolicy = opts.retryPolicy or RetryPolicy.CreateDefault()
	leaseDurationSeconds = opts.leaseDurationSeconds or 120
	keyPrefix = opts.keyPrefix or "Player_"
	isEphemeral = opts.isEphemeral or false
end

local function extractUserId(target: any): number?
	if typeof(target) == "number" then
		return target
	elseif typeof(target) == "Instance" then
		return (target :: any).UserId
	elseif typeof(target) == "table" then
		return target.userId or target.UserId
	end
	return nil
end

-- Start: Inicia el servicio y prepara el contexto del servidor.
function DataService.Start(injectedStoreAdapter: any?)
	if injectedStoreAdapter then
		storeAdapter = injectedStoreAdapter
	elseif not storeAdapter and not isEphemeral then
		storeAdapter = DataStoreAdapter.CreateProduction("SpeedsterEscape_MainSave_v17")
	end
	isStarted = true
end

-- Open: Adquiere una sesión y lease para el jugador con garantías de unicidad e idempotencia.
function DataService.Open(player: any, deadlineMono: number?): Result<SessionHandle>
	local userId = extractUserId(player)
	if typeof(userId) ~= "number" then
		return {
			ok = false,
			error = { code = "InvalidInput", message = "Invalid player UserId", retryable = false },
		}
	end

	local existingActor = actorsByUserId[userId]
	if existingActor then
		if existingActor.state == "Ready" or existingActor.state == "Ephemeral" then
			return {
				ok = true,
				value = {
					userId = existingActor.userId,
					sessionId = existingActor.sessionId,
					generation = existingActor.generation,
				},
			}
		elseif existingActor.state == "Loading" then
			-- Si ya está cargando, retornar handle una vez complete
			return existingActor:Open(deadlineMono)
		elseif existingActor.profile and existingActor.state ~= "Closed" and existingActor.state ~= "Released" and existingActor.state ~= "Lost" then
			return {ok=false,error={code="NotReady",message="Previous session has unconfirmed data",retryable=true}}
		else
			-- Estado terminal previo: limpiar y reabrir
			existingActor:Destroy()
			actorsByUserId[userId] = nil
		end
	end

	local actor = SessionActor.new({
		userId = userId,
		storeAdapter = storeAdapter :: DataStoreAdapterInterface,
		clock = clock,
		retryPolicy = retryPolicy,
		leaseDurationSeconds = leaseDurationSeconds,
		keyPrefix = keyPrefix,
		isEphemeral = isEphemeral,
	})

	actorsByUserId[userId] = actor

	local openResult = actor:Open(deadlineMono)
	if not openResult.ok then
		-- Fallback a sesión de prueba efímera si estamos en Roblox Studio y DataStore no está disponible
		local isStudio = false
		pcall(function()
			local RunService = game:GetService("RunService")
			isStudio = RunService:IsStudio()
		end)

		if isStudio and (openResult.error and openResult.error.code ~= "LeaseBusy") then
			warn(string.format("[DataService] DataStore access is not available in Studio for %d (%s). Using a temporary test session that is not saved.", userId, tostring(openResult.error and openResult.error.message)))
			actor:Destroy()
			local ephemActor = SessionActor.new({
				userId = userId,
				storeAdapter = DataStoreAdapter.CreateMock(),
				clock = clock,
				retryPolicy = retryPolicy,
				leaseDurationSeconds = leaseDurationSeconds,
				keyPrefix = keyPrefix,
				isEphemeral = true,
			})
			actorsByUserId[userId] = ephemActor
			return ephemActor:Open(deadlineMono)
		end

		actorsByUserId[userId] = nil
		actor:Destroy()
		return openResult
	end

	return openResult
end

-- GetHandle: Retorna el SessionHandle legítimo activo para un UserId si existe y está Ready
function DataService.GetHandle(target: any): SessionHandle?
	local userId = extractUserId(target)
	if not userId then return nil end
	local actor = actorsByUserId[userId]
	if actor and (actor.state == "Ready" or actor.state == "Ephemeral") then
		return {
			userId = actor.userId,
			sessionId = actor.sessionId,
			generation = actor.generation,
		}
	end
	return nil
end

-- Inspect: Retorna una vista inmutable y profunda del perfil del jugador.
function DataService.Inspect(handle: SessionHandle): Result<SessionView>
	local actor = actorsByUserId[handle.userId]
	if not actor then
		return {
			ok = false,
			error = { code = "SessionLost", message = "No active session for userId", retryable = false },
		}
	end
	return actor:Inspect(handle)
end

-- Commit: Ejecuta una transacción económica con persistencia durable y deduplicación.
function DataService.Commit(handle: SessionHandle, request: TransactionRequest): CommitResult
	local actor = actorsByUserId[handle.userId]
	if not actor then
		return {
			kind = "Rejected",
			error = { code = "SessionLost", message = "No active session for userId", retryable = false },
		}
	end
	return actor:Commit(handle, request)
end

-- SetPreference: Actualiza una preferencia del jugador con coalescencia en memoria.
function DataService.SetPreference(handle: SessionHandle, key: string, value: boolean): Result<number>
	local actor = actorsByUserId[handle.userId]
	if not actor then
		return {
			ok = false,
			error = { code = "SessionLost", message = "No active session for userId", retryable = false },
		}
	end
	return actor:SetPreference(handle, key, value)
end

-- SetDailyLoginState: Actualiza el estado del daily reward en memoria con persistencia durable.
function DataService.SetDailyLoginState(handle: SessionHandle, dailyState: any): Result<number>
	local actor = actorsByUserId[handle.userId]
	if not actor then
		return {
			ok = false,
			error = { code = "SessionLost", message = "No active session for userId", retryable = false },
		}
	end
	return actor:SetDailyLoginState(handle, dailyState)
end

-- AccrueSpeed: Acumula velocidad en memoria con coalescencia.
function DataService.AccrueSpeed(handle: SessionHandle, baseAmount: number, source: string?, multipliers: any?): any
	local actor = actorsByUserId[handle.userId]
	if not actor then
		return {
			ok = false,
			error = { code = "SessionLost", message = "No active session for userId", retryable = false },
		}
	end
	return actor:AccrueSpeed(handle, baseAmount, multipliers)
end

-- Flush: Sincroniza a DataStore las revisiones acumuladas si están pendientes.
function DataService.Flush(handle: SessionHandle, target: number?, deadlineMono: number?): SaveResult
	local actor = actorsByUserId[handle.userId]
	if not actor then
		return {
			kind = "Failed",
			error = { code = "SessionLost", message = "No active session for userId", retryable = false },
		}
	end
	return actor:Flush(handle, target, deadlineMono)
end

-- Quiesce: Cierra la admisión de nuevas operaciones de valor.
function DataService.Quiesce(handle: SessionHandle, reason: string?): Result<number>
	local actor = actorsByUserId[handle.userId]
	if not actor then
		return {
			ok = false,
			error = { code = "SessionLost", message = "No active session for userId", retryable = false },
		}
	end
	return actor:Quiesce(handle, reason)
end

-- Release: Realiza el guardado final y libera el token de sesión en DataStore.
function DataService.Release(handle: any, deadlineMono: number?): ReleaseResult
	local userId = extractUserId(handle)
	if not userId then
		return { kind = "AlreadyReleased", durableRevision = 0 }
	end
	local actor = actorsByUserId[userId]
	if not actor then
		return { kind = "AlreadyReleased", durableRevision = 0 }
	end

	local validHandle = if typeof(handle) == "table" and handle.sessionId then
		handle
	else
		{ userId = actor.userId, sessionId = actor.sessionId, generation = actor.generation }

	local releaseRes = actor:Release(validHandle, deadlineMono)
	actorsByUserId[userId] = nil
	actor:Destroy()
	return releaseRes
end

-- ResumeAfterFailedTeleport: Re-adquiere la sesión con una generación nueva tras un fallo de teletransporte.
function DataService.ResumeAfterFailedTeleport(handle: SessionHandle, deadlineMono: number?): Result<SessionHandle>
	local oldActor = actorsByUserId[handle.userId]
	if oldActor then
		pcall(function()
			oldActor:Release(handle, deadlineMono)
		end)
		oldActor:Destroy()
		actorsByUserId[handle.userId] = nil
	end

	-- Adquisición de nueva sesión bajo generación independiente
	return DataService.Open({ UserId = handle.userId }, deadlineMono)
end

-- Subscribe: Registra un observador de cambios en el estado de la sesión.
function DataService.Subscribe(handle: SessionHandle, listener: (SessionView) -> ()): () -> ()
	local actor = actorsByUserId[handle.userId]
	if not actor then
		return function() end
	end
	return actor:Subscribe(handle, listener)
end

-- Shutdown: Coordina el cierre y liberación ordenada de todos los perfiles activos en paralelo.
function DataService.Shutdown(deadlineMono: number?): { [number]: ReleaseResult }
	local results: { [number]: ReleaseResult } = {}
	local activeList: { { userId: number, actor: any, handle: SessionHandle } } = {}

	for userId, actor in pairs(actorsByUserId) do
		table.insert(activeList, {
			userId = userId,
			actor = actor,
			handle = {
				userId = actor.userId,
				sessionId = actor.sessionId,
				generation = actor.generation,
			},
		})
	end

	for _, item in ipairs(activeList) do
		item.actor:Quiesce(item.handle, "Shutdown")
		local res = item.actor:Release(item.handle, deadlineMono)
		results[item.userId] = res
		item.actor:Destroy()
	end

	actorsByUserId = {}
	return results
end

-- Destroy: Destrucción total e idempotente del servicio.
function DataService.Destroy()
	for _, actor in pairs(actorsByUserId) do
		actor:Destroy()
	end
	actorsByUserId = {}
	isStarted = false
end

-- GetActiveSessionCount: Helper para pruebas unitarias e inspección de fugas.
function DataService.GetActiveSessionCount(): number
	local count = 0
	for _ in pairs(actorsByUserId) do
		count = count + 1
	end
	return count
end

local lifecycleTask=if typeof(script)=="Instance" then task else require("@lune/task")
local function handleFor(actor)
	return {userId=actor.userId,sessionId=actor.sessionId,generation=actor.generation}
end
function DataService.GetHandle(target)
	local actor=actorsByUserId[extractUserId(target)]
	if actor and actor.profile and actor.state~="Lost" and actor.state~="Released" and actor.state~="Closed" then return handleFor(actor) end
	return nil
end
function DataService.Release(target,deadlineMono)
	local uid=extractUserId(target)
	local actor=uid and actorsByUserId[uid]
	if not actor then return {kind="AlreadyReleased",durableRevision=0} end
	local handle=if type(target)=="table" and target.sessionId then target else handleFor(actor)
	local deadline=deadlineMono or os.clock()+25
	local result
	for attempt=1,4 do
		result=actor:Release(handle,deadline)
		if result.kind=="Released" or result.kind=="AlreadyReleased" then
			if actorsByUserId[uid]==actor then actorsByUserId[uid]=nil end
			actor:Destroy()
			return result
		end
		if result.error and result.error.retryable==false then break end
		if os.clock()+attempt>=deadline then break end
		lifecycleTask.wait(attempt)
	end
	-- Keep the snapshot available for a later retry; do not erase unconfirmed data.
	return result
end
function DataService.Shutdown(deadlineMono)
	local deadline=deadlineMono or os.clock()+25
	local results={};local remaining=0
	for uid,actor in pairs(actorsByUserId) do
		remaining+=1
		actor.closing=true
		lifecycleTask.spawn(function()
			local ok,result=pcall(DataService.Release,handleFor(actor),deadline)
			results[uid]=if ok then result else {kind="Failed",error={message=tostring(result)}}
			remaining-=1
		end)
	end
	while remaining>0 and os.clock()<deadline do lifecycleTask.wait(0.05) end
	return results
end
function DataService.ResumeAfterFailedTeleport(handle,deadlineMono)
	local actor=actorsByUserId[handle.userId]
	if actor then
		if actor.state=="Ready" and not actor.closing then return {ok=true,value=handleFor(actor)} end
		local released=DataService.Release(handle,deadlineMono)
		if released.kind~="Released" and released.kind~="AlreadyReleased" then return {ok=false,error=released.error} end
	end
	return DataService.Open(handle.userId,deadlineMono)
end
local operationSequence=0
function DataService.NewOperationId()
	if typeof(script)=="Instance" then return game:GetService("HttpService"):GenerateGUID(false) end
	operationSequence+=1
	return tostring(os.clock())..":"..operationSequence
end
return DataService
