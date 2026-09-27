-- audit/test_fable_audit_fixes.luau  (2026-09-20)
-- The audit's fixes, each run from the real source:
--   1. sprint bar: owner-only remote at <= 4 Hz, attributes only at the ends, nothing while idle;
--   2. state remotes: a flood costs one run per window and the newest state is never lost;
--   3. speed hot path: no profile copies, one notification per second, saves unaffected;
--   4. animation republish: once per JOIN, not per respawn, never to the observer itself;
--   5. joining: a new player gets no panel; others get the Update Logs only for a new version;
--   6. level bar attribute at most every 2 s; small rate limits; no revive log spam.
-- Pass "places" to check the three places carry these sources and settings.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local rb = require("@lune/roblox")
local serde = require("@lune/serde")
local process = require("@lune/process")

local SSS = "src/common/ServerScriptService/"
local SPS = "src/common/StarterPlayer/StarterPlayerScripts/"
local passed = 0
local function pass(message)
	passed += 1
	print("PASS " .. message)
end
local function read(path)
	return (fs.readFile(path):gsub("\r\n", "\n"))
end
local function slice(source, first, last)
	local a = assert(source:find(first, 1, true), "missing: " .. first)
	local b = assert(source:find(last, a + #first, true), "missing: " .. last)
	return source:sub(a, b - 1)
end

-- 1. The sprint bar -------------------------------------------------------------------------
do
	local source = read(SSS .. "Bootstrap.server.luau")
	local now, writes, remotes = 0, {}, {}
	local attributes = { DataLoaded = true, EquippedSkin = "Base", IsBoosting = true }
	local player = { UserId = 17 }
	function player:GetAttribute(name) return attributes[name] end
	function player:SetAttribute(name, value)
		attributes[name] = value
		table.insert(writes, { name = name, at = now })
	end
	local config = { SuitStaminaMax = { Base = 100 }, BoostDrainPerSecond = 4, BoostRegenDelaySeconds = 0,
		BoostRegenPercentPerTick = 0.5, BoostRegenTickSeconds = 1, AbilityFlightEnabled = false }
	local globals, heartbeat = {}, nil
	local moving = true
	local env = { Config = config, SuitCatalog = { ById = {} }, _G = globals, FlightStamina = {},
		os = { clock = function() return now end }, Players = { GetPlayers = function() return { player } end },
		RunService = { Heartbeat = { Connect = function(_, callback) heartbeat = callback end } },
		DataService = { GetHandle = function() return {} end, PeekSpeed = function() return 17 end,
			Inspect = function() error("Inspect in the stamina path") end },
		CharacterStatsAdapter = { Update = function() end }, isMoving = function() return moving end,
		StaminaSync = { FireClient = function(_, who, stamina, maximum) table.insert(remotes, { at = now, stamina = stamina, maximum = maximum, who = who }) end },
		Enum = rb.Enum, math = math, ipairs = ipairs, pairs = pairs }
	local runtime = slice(source, "-- 3. Estado de Stamina", "-- 4. Listeners")
		.. slice(source, "RunService.Heartbeat:Connect", 'print("[Bootstrap]')
		.. "\nreturn { sync = syncBoostStaminaAttributes }"
	local api = luau.load(runtime, { environment = env })()
	api.sync(player)
	assert(#writes == 5 and #remotes == 1 and remotes[1].who == player, "the first sample must set every alias and reach the owner")
	table.clear(writes); table.clear(remotes)
	local function step(dt) now += dt; heartbeat(dt) end
	for _ = 1, 600 do step(1 / 60) end -- ten seconds of sprinting
	assert(math.abs(globals.SpeedsterGetBoostStamina(player) - 60) < 1e-6, "the drain changed")
	assert(#writes == 0, ("sprinting wrote %d replicated attributes; the bar must go to its owner only"):format(#writes))
	assert(#remotes >= 36 and #remotes <= 41, "the owner must get about four samples a second, got " .. #remotes)
	for index = 2, #remotes do
		assert(remotes[index].at - remotes[index - 1].at >= 0.25 - 1e-9, "faster than 4 Hz")
		assert(remotes[index].stamina < remotes[index - 1].stamina)
	end
	config.BoostDrainPerSecond = 100000
	step(1 / 60)
	assert(attributes.BoostStamina == 0 and attributes.TrueBoostStamina == 0 and attributes.IsBoosting == false,
		"an empty bar must arrive reliably, at once")
	config.BoostRegenPercentPerTick = 100000
	attributes.IsBoosting = false
	step(1 / 60)
	assert(attributes.BoostStamina == 100 and attributes.TrueBoostStamina == 100, "a full bar must arrive reliably, at once")
	table.clear(writes); table.clear(remotes)
	for _ = 1, 60 do step(1 / 60) end
	-- The last packet of a run has nothing after it to correct it: the value at rest is repeated twice.
	assert(#writes == 0 and #remotes == 2 and remotes[1].stamina == 100 and remotes[2].stamina == 100,
		"a bar at rest must repeat its value twice to its owner, and replicate nothing")
	table.clear(remotes)
	for _ = 1, 600 do step(1 / 60) end
	assert(#writes == 0 and #remotes == 0, "an idle player at a full bar must send nothing at all")
	-- The same end twice: the attribute already holds 100, so nothing replicates and the repeats carry it.
	attributes.IsBoosting = true; config.BoostDrainPerSecond = 4; config.BoostRegenPercentPerTick = 0.5
	for _ = 1, 30 do step(1 / 60) end
	attributes.IsBoosting = false; config.BoostRegenPercentPerTick = 100000
	table.clear(writes); table.clear(remotes)
	for _ = 1, 60 do step(1 / 60) end
	assert(#writes == 0 and #remotes == 3 and remotes[3].stamina == 100, "a second full bar in a row must still reach its owner three times")
	local client = read(SPS .. "Movement/StaminaSyncClient.client.luau")
	assert(client:find('player:SetAttribute("BoostStamina", stamina)', 1, true) and client:find('player:SetAttribute("TrueBoostStamina", stamina)', 1, true),
		"the client must keep the attribute names every reader uses")
	pass("sprint bar: 0 replicated writes in 10 s of sprinting (was ~80), owner gets <= 4 Hz, both ends reliable, idle silent")
end

-- 2. State remotes ----------------------------------------------------------------------------
do
	local task = require("@lune/task")
	local handlers = {}
	local remote = { Name = "BoostState", OnServerEvent = { Connect = function(_, fn) table.insert(handlers, fn); return {} end } }
	local Limiter = luau.load(read(SSS .. "Services/LatestStateLimiter.luau"), { environment = {
		task = task, os = os, table = table, math = math, pcall = pcall, warn = function() end, tostring = tostring, setmetatable = setmetatable } })()
	local seen = {}
	local player = { Parent = true }
	Limiter.Connect(remote, 0.1, function(_, value) table.insert(seen, value) end)
	handlers[1](player, true)
	handlers[1](player, false)
	for _ = 1, 500 do handlers[1](player, true) end
	handlers[1](player, false)
	assert(#seen == 1 and seen[1] == true)
	task.wait(0.25)
	assert(#seen == 2 and seen[2] == false, "the newest state was lost")
	local bootstrap = read(SSS .. "Bootstrap.server.luau")
	assert(not bootstrap:find(".OnServerEvent:Connect", 1, true), "Bootstrap still has an unlimited remote")
	assert(bootstrap:find("LatestStateLimiter.Connect(WalkSpeedModeRequest, 0.25", 1, true) and bootstrap:find("LatestStateLimiter.Connect(BoostState, 0.05", 1, true))
	pass("state remotes: 503 calls -> 2 runs, final state kept; Bootstrap has no unlimited remote left")
end

-- 3. The speed hot path ------------------------------------------------------------------------
do
	local actor = read(SSS .. "Services/Data/SessionActor.luau")
	local calls, timers = 0, {}
	local env = { typeof = function(v) return if v == timers then "table" else typeof(v) end, type = type,
		task = timers }
	timers.delay = function(seconds, fn) table.insert(timers, { seconds = seconds, fn = fn }) end
	local chunk = "local SessionActor = {}\nSessionActor.__index = SessionActor\n"
		.. slice(actor, "function SessionActor:PeekNumber", "-- High-rate changes")
		.. slice(actor, "local SPEED_NOTIFY_SECONDS", "function SessionActor:_buildView")
		.. "\nreturn SessionActor"
	local Actor = luau.load(chunk, { environment = env })()
	local self = setmetatable({ profile = { Speed = 41.5, Name = "x" }, state = "Ready",
		_notifySubscribers = function() calls += 1 end }, Actor)
	assert(self:PeekNumber("Speed") == 41.5 and self:PeekNumber("Name") == 0 and self:PeekNumber("Nope") == 0)
	for _ = 1, 10 do self:_notifySubscribersCoalesced() end
	assert(calls == 0 and #timers == 1 and timers[1].seconds >= 1, "ten speed ticks must share one delayed notification")
	timers[1].fn()
	assert(calls == 1)
	self:_notifySubscribersCoalesced()
	assert(#timers == 2, "the next window must schedule again")
	self.state = "Released"
	timers[2].fn()
	assert(calls == 1, "a released session must not be projected")
	-- Without a scheduler (these tests, and the persistence suite) it stays synchronous.
	local plain = luau.load(chunk, { environment = { typeof = typeof, type = type } })()
	local other = setmetatable({ profile = {}, state = "Ready", _notifySubscribers = function() calls += 1 end }, plain)
	other:_notifySubscribersCoalesced()
	assert(calls == 2)
	local accrue = slice(actor, "function SessionActor:AccrueSpeed", "function SessionActor:Subscribe")
	assert(accrue:find("self:_notifySubscribersCoalesced()", 1, true) and not accrue:find("self:_notifySubscribers()", 1, true))
	local commit = slice(actor, "function SessionActor:SetPreference", "function SessionActor:AccrueSpeed")
	assert(commit:find("self:_notifySubscribers()", 1, true), "everything that is not the speed tick must still notify at once")

	local bridge = read(SSS .. "Progression/PlayerStatsBridge.luau")
	local addSpeed = slice(bridge, "g.SpeedsterAddSpeed = function", "-- 2. SpeedsterApplyWalkSpeed")
	assert(not addSpeed:find("DataService.Inspect(", 1, true) and addSpeed:find("DataService.PeekSpeed", 1, true), "SpeedsterAddSpeed still copies the profile")
	local bootstrap = read(SSS .. "Bootstrap.server.luau")
	assert(not slice(bootstrap, "local function getWalkingPopupTier", "local selectedBurstCount"):find("DataService.Inspect(", 1, true))
	assert(read(SSS .. "Services/Data/DataService.luau"):find("function DataService.PeekSpeed", 1, true))
	pass("speed tick: PeekSpeed instead of 3 profile copies, 10 ticks -> 1 projection, other changes still immediate")
end

-- 4. Animation republish -------------------------------------------------------------------------
do
	local source = read(SSS .. "Infrastructure/AnimationReplicationSync.server.luau")
	local now, delayed, fired, onEvent, onRemoving = 100, {}, {}, nil, nil
	local workspaceStub = {}
	local function character()
		local c = {}
		local animator = { Parent = nil, IsA = function(_, class) return class == "Animator" end, GetAttribute = function() return true end }
		local humanoid = { FindFirstChild = function() return { IsA = function() return true end, Value = animator } end }
		animator.Parent = humanoid
		c.IsDescendantOf = function() return true end
		c.FindFirstChildOfClass = function() return humanoid end
		c.WaitForChild = function() return nil end
		return c
	end
	local players = {}
	local Players = { GetPlayers = function() return players end,
		PlayerAdded = { Connect = function() end }, PlayerRemoving = { Connect = function(_, fn) onRemoving = fn end } }
	local function join(name)
		local p = { Name = name, Parent = Players, Character = character(), CharacterAdded = { Connect = function() end } }
		table.insert(players, p)
		return p
	end
	local remote = { OnServerEvent = { Connect = function(_, fn) onEvent = fn end },
		FireClient = function(_, owner, action) table.insert(fired, { owner = owner, action = action }) end }
	local env = { game = { GetService = function(_, name)
			if name == "Players" then return Players end
			return { WaitForChild = function() return { WaitForChild = function() return remote end } end }
		end },
		workspace = workspaceStub, os = { clock = function() return now end },
		task = { spawn = function() end, delay = function(_, fn, ...) table.insert(delayed, { fn = fn, args = { ... } }) end },
		typeof = function(v) return if type(v) == "table" then "Instance" else typeof(v) end,
		setmetatable = setmetatable, ipairs = ipairs, math = math, print = function() end }
	local a, b, c = join("a"), join("b"), join("c")
	luau.load(source, { environment = env })()
	local function flush()
		local pending = delayed
		delayed = {}
		for _, item in pending do item.fn(table.unpack(item.args)) end
	end
	onEvent(a, "ObserverReady", a.Character)
	flush()
	assert(#fired == 4, "a new observer: two republishes to each of the 2 others, got " .. #fired)
	for _, item in fired do
		assert(item.owner ~= a and item.action == "RepublishCurrent", "the observer must not republish to itself")
	end
	-- a dies and respawns, again and again: nobody is asked for anything.
	table.clear(fired)
	for _ = 1, 5 do
		now += 5
		a.Character = character()
		onEvent(a, "ObserverReady", a.Character)
		flush()
	end
	assert(#fired == 0, ("five respawns cost %d remotes; they must cost none"):format(#fired))
	-- Spam inside the window, a stale character and a foreign character are ignored.
	now += 5
	onEvent(b, "ObserverReady", b.Character)
	onEvent(b, "ObserverReady", b.Character)
	onEvent(c, "ObserverReady", a.Character)
	onEvent(c, "Anything", c.Character)
	flush()
	assert(#fired == 4, "only b's first report counts, got " .. #fired)
	onRemoving(a)
	now += 5
	a.Character = character()
	onEvent(a, "ObserverReady", a.Character)
	flush()
	assert(#fired == 8, "a player who rejoins is a new observer again")
	pass("animation: 2*(N-1) remotes per JOIN, 0 per respawn (was 2*N per respawn plus N*(N-1) republished tracks)")
end

-- 5. Joining ---------------------------------------------------------------------------------
do
	local source = read(SPS .. "UI/UpdateLogsController.client.luau")
	local block = slice(source, "task.spawn(function()\n\tlocal deadline = os.clock() + 30", "\nend)") .. "\nend)"
	local function run(attributes, placeVersion, script)
		local now, opened, daily = 0, 0, 0
		local player = { Parent = true, GetAttribute = function(_, name) return attributes[name] end }
		local env = { player = player, isOpen = false, tonumber = tonumber,
			os = { clock = function() return now end }, game = { PlaceVersion = placeVersion },
			openPanel = function() opened += 1 end,
			-- 2026-09-25 (Update 4, M14): the Daily opens only with something to claim; always
			-- here, as before, so the join timing is what this checks.
			dailyWanted = function() return true end,
			MenuEvents = { Get = function() return { Fire = function() daily += 1 end } end },
			task = { spawn = function(fn) fn() end, wait = function(seconds)
				now += seconds
				if script then script(now, attributes) end
				if now > 400 then player.Parent = nil end
			end } }
		luau.load(block, { environment = env })()
		return opened, daily, now
	end
	-- A brand-new player: the tutorial runs for 40 s, then the aura guide until 70 s.
	local opened, daily, at = run({ DataLoaded = true, FirstTimeTutorialActive = true }, 12, function(now, attributes)
		attributes.FirstTimeTutorialActive = now < 40
		attributes.GuidedTutorialOpen = now >= 40 and now < 70
	end)
	assert(opened == 0, "a new player must never be shown the Update Logs")
	assert(daily == 1 and at >= 74 and at < 80, "the daily reward must wait for the tutorial and its guide, opened at " .. at)
	-- A new player who is quick: still no window in the first minute.
	opened, daily, at = run({ DataLoaded = true, FirstTimeTutorialActive = true }, 12, function(now, attributes)
		attributes.FirstTimeTutorialActive = now < 10
	end)
	assert(opened == 0 and daily == 1 and at >= 60, "no window in a new player's first minute, opened at " .. at)
	opened, daily = run({ DataLoaded = true, LastSeenUpdateLog = 11 }, 12)
	assert(opened == 1 and daily == 0, "a returning player with an unseen version gets the Update Logs (which chain to the daily reward)")
	opened, daily = run({ DataLoaded = true, LastSeenUpdateLog = 12 }, 12)
	assert(opened == 0 and daily == 1, "a returning player who has seen this version goes straight to the daily reward")
	assert(source:find('MenuEvents.Get("OpenDailyPanel"):Fire("Open")', 1, true))
	pass("joining: new player gets no panel for a minute and until the guide ends; Update Logs only for an unseen version")
end

-- 6. Small ones ----------------------------------------------------------------------------------
do
	local level = read(SSS .. "Progression/LevelProgress.server.luau")
	local now, writes, remote = 0, {}, 0
	local attributes = {}
	local player = { GetAttribute = function(_, n) return attributes[n] end,
		SetAttribute = function(_, n, v) attributes[n] = v; table.insert(writes, n) end }
	local publish = luau.load(slice(level, "local lastProgressAttributeAt", "local function syncFromRawSpeed") .. "\nreturn publish", { environment = {
		setmetatable = setmetatable, os = { clock = function() return now end }, math = math,
		getRequirement = function(l) return 100 * l end,
		LevelProgressUpdate = { FireClient = function() remote += 1 end } } })()
	publish(player, 3, 10, false)
	table.clear(writes)
	for tick = 1, 20 do -- ten seconds of 2 Hz speed ticks inside one level
		now += 0.5
		publish(player, 3, 10 + tick, false)
	end
	local progressWrites = 0
	for _, name in writes do
		assert(name == "LevelProgress", name .. " was rewritten without changing")
		progressWrites += 1
	end
	assert(progressWrites == 5 and remote == 21, ("LevelProgress attribute %d times in 10 s (want 5), remote %d"):format(progressWrites, remote))
	now += 0.1
	publish(player, 4, 0, false)
	assert(attributes.Level == 4 and attributes.LevelProgress == 0 and attributes.LevelRequirement == 400, "a level up must publish everything at once")

	for path, needle in {
		[SSS .. "Progression/RebirthSystem.server.luau"] = "lastRebirthSyncAt[player] or 0) < 0.5",
		[SSS .. "Social/DailyLoginSystem.server.luau"] = "lastDailyRefreshAt[player] or 0) < 0.5",
		[SSS .. "Economy/SkinSystem.server.luau"] = "lastSkinStateAt[player] or 0) < 0.5",
	} do
		assert(read(path):find(needle, 1, true), path .. " lost its rate limit")
	end
	assert(not read(SSS .. "Economy/SpeedProductPurchases.server.luau"):find("[ReviveCommerce] OnServerEvent from", 1, true), "the revive remote still logs every event")
	local run = read("src/common/StarterPlayer/StarterCharacterScripts/R15SpeedsterRun.client.luau")
	assert(run:find("if afterimagesAlive then", 1, true), "afterimages are still cleared every frame")
	-- Pacing: the free treadmills one rebirth apart, gains untouched, and every free treadmill
	-- before World 2's gate (Config.World2UnlockRebirths since 2026-09-22).
	local config = read("src/common/ReplicatedStorage/Shared/Config.luau")
	local world1 = slice(config, "Config.NewWorld1TreadmillProfiles = {", "Needoh = {")
	local function requirement(name)
		return tonumber(slice(world1, name .. " = {", "}"):match("RequiredRebirths = (%d+)")) or 0
	end
	local function gain(name)
		return tonumber(slice(world1, name .. " = {", "}"):match("BaseGain = (%d+)"))
	end
	assert(requirement("Basic") == 0 and requirement("Golden") == 1 and requirement("Candy") == 2 and requirement("Diamond") == 4, "free treadmill ladder")
	assert(gain("Basic") == 1 and gain("Golden") == 3 and gain("Candy") == 5 and gain("Diamond") == 10, "treadmill gains must not change")
	local world2Gate = tonumber(config:match("\nConfig%.World2UnlockRebirths = (%d+)"))
	assert(world2Gate, "Config sets World 2's rebirth gate (Config.World2UnlockRebirths)")
	assert(requirement("Diamond") < world2Gate, "Diamond must come before World 2's gate (" .. world2Gate .. " rebirths)")
	local low = read(SPS .. "Gameplay/LowPowerGraphics.client.luau")
	assert(low:find("TouchEnabled and not UserInputService.KeyboardEnabled", 1, true) and low:find("Lighting.GlobalShadows = false", 1, true))
	pass("level bar attribute 5 times in 10 s (was 20) with the remote on every tick; three refresh limits; no revive spam; phones drop global shadows")
end

-- 7. The places ----------------------------------------------------------------------------------
if process.args[1] == "places" then
	local manifest = serde.decode("json", fs.readFile("src/manifest.json"))
	local WANTED = {
		SSS .. "Bootstrap.server.luau", SSS .. "Services/LatestStateLimiter.luau", SSS .. "Services/Data/SessionActor.luau",
		SSS .. "Services/Data/DataService.luau", SSS .. "Progression/PlayerStatsBridge.luau", SSS .. "Progression/LevelProgress.server.luau",
		SSS .. "Progression/RebirthSystem.server.luau", SSS .. "Social/DailyLoginSystem.server.luau", SSS .. "Economy/SkinSystem.server.luau",
		SSS .. "Economy/SpeedProductPurchases.server.luau", SSS .. "Infrastructure/AnimationReplicationSync.server.luau",
		"src/common/ReplicatedStorage/Shared/Config.luau",
		SPS .. "UI/UpdateLogsController.client.luau", SPS .. "Movement/StaminaSyncClient.client.luau", SPS .. "Gameplay/LowPowerGraphics.client.luau",
		"src/common/StarterPlayer/StarterCharacterScripts/R15SpeedsterRun.client.luau",
	}
	for _, place in { { "World1", "World1Update3New.rbxl" }, { "World2", "World2Update3new.rbxl" }, { "World3", "World3Update3New.rbxl" } } do
		local dm = rb.deserializePlace(fs.readFile(place[2]))
		local rows = {}
		for _, row in manifest.worlds[place[1]].scripts do rows[row.source] = row end
		for _, source in WANTED do
			local row = assert(rows[source], place[1] .. ": no manifest row for " .. source)
			local node = dm
			for _, name in row.segments do
				node = assert(node:FindFirstChild(name), place[1] .. " is missing " .. table.concat(row.segments, "."))
			end
			assert(node.Source == fs.readFile(source), place[1] .. ": " .. node.Name .. " differs from src")
		end
		assert(tostring(dm:GetService("Workspace").PlayerCharacterDestroyBehavior):find("Enabled"), place[1] .. ": old characters are not destroyed")
	end
	pass("the three places carry all " .. #WANTED .. " sources and destroy old characters")
end
print(("ALL PASSED (%d groups)"):format(passed))
