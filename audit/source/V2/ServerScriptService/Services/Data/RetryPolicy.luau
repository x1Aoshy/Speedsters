--!strict
-- src/ServerScriptService/Services/Data/RetryPolicy.luau
-- Lote R1-04: Política de reintentos con backoff exponencial y full jitter.

export type RetryPolicyConfig = {
	baseDelaySeconds: number,
	maxDelaySeconds: number,
	maxAttempts: number,
	leaseSafetyMarginSeconds: number,
	maxQueueLength: number,
}

local RetryPolicy = {}

local DEFAULT_POLICY: RetryPolicyConfig = {
	baseDelaySeconds = 0.5,
	maxDelaySeconds = 4.0,
	maxAttempts = 5,
	leaseSafetyMarginSeconds = 15,
	maxQueueLength = 50,
}

function RetryPolicy.CreateDefault(): RetryPolicyConfig
	return {
		baseDelaySeconds = DEFAULT_POLICY.baseDelaySeconds,
		maxDelaySeconds = DEFAULT_POLICY.maxDelaySeconds,
		maxAttempts = DEFAULT_POLICY.maxAttempts,
		leaseSafetyMarginSeconds = DEFAULT_POLICY.leaseSafetyMarginSeconds,
		maxQueueLength = DEFAULT_POLICY.maxQueueLength,
	}
end

function RetryPolicy.ComputeDelay(attempt: number, policy: RetryPolicyConfig?): number
	local p = policy or DEFAULT_POLICY
	local exp = math.max(0, attempt - 1)
	local cap = math.min(p.maxDelaySeconds, p.baseDelaySeconds * (2 ^ exp))
	-- Full jitter: distribución uniforme entre 0 y cap
	return math.random() * cap
end

function RetryPolicy.ShouldRetry(attempt: number, policy: RetryPolicyConfig?): boolean
	local p = policy or DEFAULT_POLICY
	return attempt < p.maxAttempts
end

return RetryPolicy
