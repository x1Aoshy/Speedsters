--!strict
-- src/ServerScriptService/Services/Data/DataStoreAdapter.luau
-- Lote R1-04: Abstracción de acceso a DataStore y Mock determinista para pruebas offline.

export type StoreResult = {
	ok: boolean,
	value: any?,
	error: string?,
	isUncertain: boolean?,
}

export type StoreFailureMode = "None" | "Timeout" | "Throttled" | "Down"

export type DataStoreAdapterInterface = {
	GetAsync: (self: any, key: string) -> StoreResult,
	UpdateAsync: (self: any, key: string, transform: (current: any?) -> any?) -> StoreResult,
}

local DataStoreAdapter = {}

-- Implementación para producción en Roblox
function DataStoreAdapter.CreateProduction(dataStoreName: string?): DataStoreAdapterInterface
	local name = dataStoreName or "SpeedsterEscape_MainSave_v17"
	local ok, ds = pcall(function()
		local DataStoreService = game:GetService("DataStoreService")
		return DataStoreService:GetDataStore(name)
	end)
	if ok and ds then
		return DataStoreAdapter.CreateRoblox(ds)
	else
		return DataStoreAdapter.CreateMock()
	end
end

-- Implementación para producción en Roblox
function DataStoreAdapter.CreateRoblox(robloxDataStore: any): DataStoreAdapterInterface
	local adapter = {}

	function adapter:GetAsync(key: string): StoreResult
		local success, result = pcall(function()
			return robloxDataStore:GetAsync(key)
		end)
		if success then
			return { ok = true, value = result }
		else
			local errStr = tostring(result)
			local isUncertain = string.find(errStr, "timeout") ~= nil or string.find(errStr, "502") ~= nil
			return { ok = false, error = errStr, isUncertain = isUncertain }
		end
	end

	function adapter:UpdateAsync(key: string, transform: (current: any?) -> any?): StoreResult
		local success, result = pcall(function()
			return robloxDataStore:UpdateAsync(key, transform)
		end)
		if success then
			return { ok = true, value = result }
		else
			local errStr = tostring(result)
			local isUncertain = string.find(errStr, "timeout") ~= nil or string.find(errStr, "502") ~= nil
			return { ok = false, error = errStr, isUncertain = isUncertain }
		end
	end

	return adapter
end

-- Implementación Mock determinista para pruebas unitarias y offline
export type MockDataStoreAdapter = DataStoreAdapterInterface & {
	SetData: (self: any, key: string, value: any) -> (),
	GetData: (self: any, key: string) -> any?,
	SetFailureMode: (self: any, key: string, mode: StoreFailureMode) -> (),
	GetCallCount: (self: any, key: string) -> number,
	GetHistory: (self: any) -> { any },
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

function DataStoreAdapter.CreateMock(initialData: { [string]: any }?): MockDataStoreAdapter
	local storeData: { [string]: any } = {}
	if initialData then
		for k, v in pairs(initialData) do
			storeData[k] = deepCopy(v)
		end
	end

	local failureModes: { [string]: StoreFailureMode } = {}
	local callCounts: { [string]: number } = {}
	local history: { any } = {}

	local mock = {} :: any

	function mock:SetData(key: string, value: any)
		storeData[key] = deepCopy(value)
	end

	function mock:GetData(key: string): any?
		return deepCopy(storeData[key])
	end

	function mock:SetFailureMode(key: string, mode: StoreFailureMode)
		failureModes[key] = mode
	end

	function mock:GetCallCount(key: string): number
		return callCounts[key] or 0
	end

	function mock:GetHistory(): { any }
		return history
	end

	function mock:GetAsync(key: string): StoreResult
		callCounts[key] = (callCounts[key] or 0) + 1
		table.insert(history, { op = "GetAsync", key = key })

		local mode = failureModes[key] or "None"
		if mode == "Down" then
			return { ok = false, error = "DataStore service unavailable", isUncertain = false }
		elseif mode == "Throttled" then
			return { ok = false, error = "502: Request dropped due to throttling", isUncertain = false }
		elseif mode == "Timeout" then
			return { ok = false, error = "DataStore request timed out", isUncertain = true }
		end

		return { ok = true, value = deepCopy(storeData[key]) }
	end

	function mock:UpdateAsync(key: string, transform: (current: any?) -> any?): StoreResult
		callCounts[key] = (callCounts[key] or 0) + 1
		table.insert(history, { op = "UpdateAsync", key = key })

		local mode = failureModes[key] or "None"
		if mode == "Down" then
			return { ok = false, error = "DataStore service unavailable", isUncertain = false }
		elseif mode == "Throttled" then
			return { ok = false, error = "502: Request dropped due to throttling", isUncertain = false }
		elseif mode == "Timeout" then
			-- Simulación crítica: en timeout, la escritura pudo o no aplicarse en el backend.
			-- Ejecutamos la transformación para simular que el backend la procesó, pero el cliente recibió timeout!
			local current = deepCopy(storeData[key])
			local transformed = transform(current)
			if transformed ~= nil then
				storeData[key] = deepCopy(transformed)
			end
			return { ok = false, error = "DataStore update timed out", isUncertain = true }
		end

		local current = deepCopy(storeData[key])
		local transformed = transform(current)
		if transformed ~= nil then
			storeData[key] = deepCopy(transformed)
			return { ok = true, value = deepCopy(transformed) }
		else
			-- Retornar nil en transform cancela la actualización
			return { ok = true, value = deepCopy(current) }
		end
	end

	return mock
end

return DataStoreAdapter
