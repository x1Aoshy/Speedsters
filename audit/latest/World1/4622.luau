local RateLimiter = {}

local lastAtByPlayer = setmetatable({}, { __mode = "k" })

function RateLimiter.Allow(player, key, interval)
	if not player or not player.Parent then
		return false
	end
	key = tostring(key or "default")
	interval = math.max(0, tonumber(interval) or 0)

	local bucket = lastAtByPlayer[player]
	if not bucket then
		bucket = {}
		lastAtByPlayer[player] = bucket
	end

	local now = os.clock()
	local lastAt = tonumber(bucket[key]) or -math.huge
	if now - lastAt < interval then
		return false
	end
	bucket[key] = now
	return true
end

function RateLimiter.Clear(player)
	lastAtByPlayer[player] = nil
end

return RateLimiter
