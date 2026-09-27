local fs = require('@lune/fs')
local luau = require('@lune/luau')

local function slice(source, first, last)
	local begin = assert(source:find(first, 1, true), first)
	local finish = assert(source:find(last, begin, true), last)
	return source:sub(begin, finish - 1)
end

for _, world in { 'World1', 'World2' } do
	local base = 'audit/merged/' .. world .. '/ServerScriptService/'
	local source = fs.readFile(base .. 'Bootstrap.luau')
	luau.compile(source)
	local now = 0
	local writes = {}
	local attributes = { DataLoaded = true, EquippedSkin = 'Base', IsBoosting = true }
	local player = { UserId = 17 }
	function player:GetAttribute(name) return attributes[name] end
	function player:SetAttribute(name, value)
		attributes[name] = value
		table.insert(writes, { name = name, value = value, at = now })
	end
	local config = { SuitStaminaMax = { Base = 100, Small = 3 }, BoostDrainPerSecond = 4,
		BoostRegenDelaySeconds = 0, BoostRegenPercentPerTick = 0.5, BoostRegenTickSeconds = 1,
		AbilityFlightEnabled = true,
		-- Flight cost is a share of the bar now; the floor keeps this case's intent
		-- (drain the 3-stamina Small suit inside one 0.4s step).
		AbilityFlightDrainFloorPerSecond = 10, AbilityFlightDrainPercentPerSecond = 0.35,
		AbilityFlightGlideDrainPercentPerSecond = 0.14, AbilityFlightMinimumStaminaPercent = 0.12 }
	local globals = {}
	local heartbeat
	-- Whether the player runs (Bootstrap's isMoving): only a moving sprint drains the bar.
	local moving = true
	local services = { GetHandle = function() return {} end,
		Inspect = function() return { ok = true, value = { profile = { Speed = 17 } } } end,
		Release = function() return { kind = 'Released' } end }
	-- Bootstrap now delegates the flight drain to Shared.FlightStamina; load the
	-- real module so this exercises production math rather than a stand-in.
	local flightStamina = luau.load(fs.readFile('src/common/ReplicatedStorage/Shared/FlightStamina.luau'),
		{ environment = { math = math, tonumber = tonumber } })()
	local env = { Config = config, SuitCatalog = { ById = {} }, _G = globals, FlightStamina = flightStamina,
		os = { clock = function() return now end }, Players = { GetPlayers = function() return { player } end },
		RunService = { Heartbeat = { Connect = function(_, callback) heartbeat = callback end } },
		DataService = services, CharacterStatsAdapter = { Update = function() end },
		StatsProjection = { Detach = function() end }, isMoving = function() return moving end,
		Enum = require('@lune/roblox').Enum }
	local runtime = slice(source, '-- 3. Estado de Stamina', '-- 4. Listeners')
		.. slice(source, 'local function cleanupPlayer', 'Players.PlayerAdded:Connect')
		.. slice(source, 'RunService.Heartbeat:Connect', 'print("[Bootstrap]')
		.. '\nreturn { sync = syncBoostStaminaAttributes, cleanup = cleanupPlayer, refill = refillBoostStamina }'
	local api = luau.load(runtime, { environment = env })()
	api.sync(player)
	assert(#writes == 5, 'all existing aliases initialized')
	table.clear(writes)
	local function step(dt)
		now += dt
		heartbeat(dt)
	end
	step(1 / 60)
	assert(#writes == 0 and globals.SpeedsterGetBoostStamina(player) < 100,
		'authority must drain immediately while UI sample stays unchanged')
	for _ = 2, 600 do step(1 / 60) end
	assert(math.abs(globals.SpeedsterGetBoostStamina(player) - 60) < 1e-8, 'drain integration changed')
	assert(#writes <= 80 and #writes >= 70, 'two changing aliases must publish at most four times per second')
	local priorAt = -math.huge
	for _, write in writes do
		assert(write.name == 'BoostStamina' or write.name == 'TrueBoostStamina', 'unchanged maximum replicated')
		if write.name == 'BoostStamina' then
			assert(write.at - priorAt >= 0.25 - 1e-9, 'periodic publication exceeded 4Hz')
			priorAt = write.at
		end
	end
	assert(attributes.BoostStamina == attributes.TrueBoostStamina, 'aliases diverged')

	-- A maximum change bypasses the 250ms budget and clamps authority in the same frame.
	attributes.EquippedSkin = 'Small'
	step(0.001)
	assert(attributes.TrueBoostStaminaMax == 3 and attributes.BoostStaminaDisplayMax == 3
		and attributes.BoostStaminaMaxInternal == 3 and attributes.BoostStamina < 3, 'maximum change delayed')
	config.BoostDrainPerSecond = 1000
	step(0.01)
	assert(globals.SpeedsterGetBoostStamina(player) == 0 and attributes.TrueBoostStamina == 0
		and attributes.BoostStamina == 0 and attributes.IsBoosting == false, 'exhaustion must publish/stop immediately')
	config.BoostRegenPercentPerTick = 1000
	step(0.001)
	assert(attributes.BoostStamina == 3 and attributes.TrueBoostStamina == 3, 'full boundary delayed')
	table.clear(writes)
	for _ = 1, 600 do step(1 / 60) end
	assert(#writes == 0, 'idle full stamina should perform zero SetAttribute calls')

	-- Load the actual flight remote handler, authorizing against the actual runtime getter.
	local flightSource = fs.readFile(base .. 'Core/Abilities/FlightService.luau')
	luau.compile(flightSource)
	local flight
	player.Character = { FindFirstChildOfClass = function() return { Health = 100 } end }
	luau.load(slice(flightSource, 'FlightAbilityState.OnServerEvent:Connect', 'local function setupPlayer'), {
		environment = { FlightAbilityState = { OnServerEvent = { Connect = function(_, fn) flight = fn end } },
			RateLimiter = { Allow = function() return true end }, Config = config, _G = globals,
			FlightStamina = flightStamina, tonumber = tonumber, math = math,
			syncOwnedAttribute = function() return true end, syncEquippedAttributes = function() return true end }
	})()
	attributes.TrueBoostStamina = 0 -- old visual sample must not reject powered flight.
	flight(player, true, true)
	assert(attributes.FlightAbilityPowered == true, 'flight reads stale UI instead of server stamina')
	attributes.FlightAbilityOwned = true
	step(0.4)
	assert(globals.SpeedsterGetBoostStamina(player) == 0 and attributes.FlightAbilityPowered == false,
		'flight exhausts in heartbeat even between UI samples')
	attributes.TrueBoostStamina = 100 -- stale client-facing sample must not authorize power.
	flight(player, true, true)
	assert(attributes.FlightAbilityPowered == false, 'stale high sample authorized powered flight')

	attributes.DataLoaded = false
	assert(globals.SpeedsterGetBoostStamina(player) == 0, 'unloaded player exposes stamina')
	api.cleanup(player)
	attributes.DataLoaded = true
	attributes.FlightAbilityActive = false
	api.sync(player)
	assert(attributes.TrueBoostStamina == 3, 'cleanup failed to discard runtime sample')
	-- Holding the sprint standing still costs nothing; running with it does (2026-09-18: Shift
	-- pressed in place drained the bar).
	attributes.EquippedSkin = 'Base'
	attributes.FlightAbilityActive = false
	attributes.FlightAbilityPowered = false
	config.BoostDrainPerSecond = 4
	config.BoostRegenDelaySeconds = 1000
	api.refill(player)
	assert(globals.SpeedsterGetBoostStamina(player) == 100 and attributes.BoostStamina == 100, 'a fresh character starts on a full bar, published at once')
	attributes.IsBoosting = true
	moving = false
	for _ = 1, 60 do step(1 / 60) end
	assert(globals.SpeedsterGetBoostStamina(player) == 100 and attributes.IsBoosting == true, 'holding the sprint standing still costs no stamina')
	moving = true
	for _ = 1, 60 do step(1 / 60) end
	assert(math.abs(globals.SpeedsterGetBoostStamina(player) - 96) < 1e-6, 'running with it drains the bar')
	-- A reset mid-run (2026-09-18: the bar did not come back, and the regeneration waited).
	api.refill(player)
	assert(globals.SpeedsterGetBoostStamina(player) == 100 and attributes.BoostStamina == 100 and attributes.IsBoosting == false,
		'a reset refills the bar at once and ends the sprint')
	assert(string.find(source, 'player.CharacterAdded:Connect(function(character)\n\t\trefillBoostStamina(player)', 1, true),
		'every new character (respawn, reset) refills the bar')
	print('PASS ' .. world .. ': actual stamina runtime/Heartbeat at 4Hz; frame-authoritative drain/flight; zero/full/max immediate; aliases and cleanup; only a moving sprint drains; a reset refills at once')
end
