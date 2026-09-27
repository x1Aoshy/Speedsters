-- LatestStateLimiter: a rate limit for STATE remotes (BoostState, WalkSpeedModeRequest).
--
-- RemoteGuard DROPS calls inside its window. That is right for requests ("claim", "buy")
-- and wrong for STATE remotes (BoostState, FlightAbilityState, WalkSpeedModeRequest): a quick
-- Shift tap sends true then false 30 ms apart, and dropping the "false" leaves the player
-- sprinting on the server. This limiter never drops the newest state: the first call runs at
-- once, calls inside the window are collapsed, and the LAST one runs when the window closes.
-- A flooding client costs one handler run per `interval`, however fast it fires.
local Limiter = {}

function Limiter.Connect(remote: RemoteEvent, interval: number, handler: (Player, ...any) -> ())
	local state = setmetatable({}, { __mode = "k" }) -- player -> { nextAt, pending, scheduled }

	local function run(player: Player, args: { any })
		local ok, message = pcall(handler, player, table.unpack(args, 1, args.n))
		if not ok then
			warn("[LatestStateLimiter] " .. remote.Name .. ": " .. tostring(message))
		end
	end

	return remote.OnServerEvent:Connect(function(player: Player, ...)
		local now = os.clock()
		local entry = state[player]
		if not entry then
			entry = { nextAt = 0, pending = nil, scheduled = false }
			state[player] = entry
		end
		local args = table.pack(...)
		if now >= entry.nextAt and not entry.scheduled then
			entry.nextAt = now + interval
			run(player, args)
			return
		end
		entry.pending = args -- newest wins
		if entry.scheduled then
			return
		end
		entry.scheduled = true
		task.delay(math.max(0, entry.nextAt - now), function()
			entry.scheduled = false
			local latest = entry.pending
			entry.pending = nil
			if latest and player.Parent then
				entry.nextAt = os.clock() + interval
				run(player, latest)
			end
		end)
	end)
end

return Limiter
