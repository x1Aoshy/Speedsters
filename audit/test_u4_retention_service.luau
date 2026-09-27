-- test_u4_retention_service.luau (Update 4, retention workstream, 2026-09-25)
-- The persistence side of Playtime Boost + Streak Rewards (PLAN §7.7):
--   1. Services/Data/U4/RetentionSection: Sanitize (negatives, NaN, wrong types, overlong
--      lists cut to 6/64, pending already claimed dropped), Encode round trip, Apply rules;
--   2. the real src SessionActor + mock store: CheckIn once per day (same operation id ->
--      AlreadyCommitted), day must be today, ClaimStreak only for pending keys, perk 0.2 -> 0.4
--      never beyond, the Playtime counter through ApplyVolatile (no write) and saved on Release;
--   3. Social/RetentionService.server.luau run in a mocked game against that SessionActor:
--      one check-in Commit per day after 60 s, playtime resume within 900 s keeps the seconds
--      and the funnel session id, the claim pays through one Commit, attributes published;
--   4. static: no DataService.Commit inside the timer loop, Playtime saved with ApplyVolatile.
-- Run: lune run audit/test_u4_retention_service.luau   (from the project root)
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local ROOT = "src/common/"
local SERVICE = ROOT .. "ServerScriptService/Social/RetentionService.server.luau"
local Section = require("../src/common/ServerScriptService/Services/Data/U4/RetentionSection")
local RetentionMath = require("../src/common/ReplicatedStorage/Shared/RetentionMath")
local U4 = require("../src/common/ReplicatedStorage/Shared/Update4Config")
local TutorialText = require("../src/common/ReplicatedStorage/Shared/TutorialText")
local Actor = require("../src/common/ServerScriptService/Services/Data/SessionActor")
local Adapter = require("../src/common/ServerScriptService/Services/Data/DataStoreAdapter")
local Codec = require("../src/common/ServerScriptService/Services/Data/ProfileCodec")

local passed = 0
local function pass(text)
	passed += 1
	print("PASS " .. text)
end
local function read(path)
	return (fs.readFile(path):gsub("\r\n", "\n"))
end

local DAY = 20720
local NOW0 = DAY * 86400 + 3600

----------------------------------------------------------------------
-- 1. RetentionSection
----------------------------------------------------------------------
do
	local d = Section.Default()
	assert(d.StreakDays == 0 and #d.StreakPending == 0 and d.PlaytimeSeconds == 0, "defaults")
	local junkPending, junkClaimed = {}, {}
	for i = 1, 20 do
		table.insert(junkPending, "c" .. i .. "_d7")
	end
	for i = 1, 100 do
		table.insert(junkClaimed, "c" .. i .. "_d14")
	end
	table.insert(junkPending, "c5_d14") -- also claimed: dropped
	table.insert(junkPending, "bogus")
	local clean = Section.Sanitize({
		StreakDays = -4, StreakLastDay = 0 / 0, StreakBest = "x", StreakGraceDay = math.huge, StreakPerk = 9,
		StreakPending = junkPending, StreakClaimed = junkClaimed,
		PlaytimeSeconds = 1e12, PlaytimeLastSeen = -1, PlaytimeSessionStart = { 1 },
	})
	assert(clean.StreakDays == 0 and clean.StreakLastDay == 0 and clean.StreakBest == 0, "negatives / NaN / wrong types -> 0")
	assert(clean.StreakGraceDay == 0, "infinite -> 0")
	assert(clean.StreakPerk == 0.4, "perk never beyond 0.4")
	assert(#clean.StreakClaimed == 64 and clean.StreakClaimed[64] == "c100_d14" and clean.StreakClaimed[1] == "c37_d14", "claimed cut to the newest 64")
	assert(#clean.StreakPending <= 6, "pending cut to 6")
	for _, key in clean.StreakPending do
		assert(key ~= "bogus" and key ~= "c5_d14", "junk and already-claimed keys are not pending")
	end
	assert(clean.PlaytimeSeconds == 6000 and clean.PlaytimeLastSeen == 0 and clean.PlaytimeSessionStart == 0, "playtime clamped")
	assert(Section.Sanitize(nil).StreakDays == 0 and Section.Sanitize("junk").PlaytimeSeconds == 0, "non-table input -> defaults")
	local nan = Section.Sanitize({ StreakPerk = 0 / 0, PlaytimeSeconds = 0 / 0 })
	assert(nan.StreakPerk == 0 and nan.PlaytimeSeconds == 0, "NaN perk / seconds -> 0")
	local live = { StreakDays = 9, StreakLastDay = DAY, StreakBest = 12, StreakGraceDay = DAY - 3, StreakPerk = 0.2,
		StreakPending = { "c1_d14" }, StreakClaimed = { "c1_d7" }, PlaytimeSeconds = 1234.5, PlaytimeLastSeen = NOW0, PlaytimeSessionStart = NOW0 - 2000 }
	local encoded = Section.Encode(live)
	local back = Section.Sanitize(encoded)
	for key, value in live do
		if type(value) == "table" then
			assert(#back[key] == #value and back[key][1] == value[1], "round trip " .. key)
		else
			assert(back[key] == value, "round trip " .. key)
		end
	end
	assert(encoded ~= live and encoded.StreakPending ~= live.StreakPending, "Encode is a copy")
	-- Apply rules
	local st = Section.Default()
	assert(not Section.Apply(st, "CheckIn", { day = DAY + 1 }, NOW0).ok, "check-in for another day refused")
	assert(not Section.Apply(st, "CheckIn", { day = "x" }, NOW0).ok, "bad day refused")
	assert(Section.Apply(st, "CheckIn", { day = DAY }, NOW0).ok and st.StreakDays == 1, "check-in today")
	assert(not Section.Apply(st, "ClaimStreak", { key = "c1_d7" }, NOW0).ok, "claim of a key that is not pending refused")
	assert(not Section.Apply(st, "Nope", {}, NOW0).ok, "unknown op refused")
	local r = Section.Apply(st, "Playtime", { seconds = 99999, lastSeen = NOW0 + 99999, sessionStart = NOW0 - 50 }, NOW0)
	assert(r.ok and st.PlaytimeSeconds == 6000 and st.PlaytimeLastSeen == NOW0 + 60 and st.PlaytimeSessionStart == NOW0 - 50, "playtime clamped to the max and the server clock")
	assert(not Section.Apply(st, "Playtime", { seconds = 0 / 0, lastSeen = 1, sessionStart = 1 }, NOW0).ok, "NaN playtime refused")
	pass("RetentionSection: Sanitize (negatives, NaN, 6/64 lists), Encode round trip, Apply rules")
end

----------------------------------------------------------------------
-- 2. Through the real SessionActor (mock store)
----------------------------------------------------------------------
local function newActor(userId, saved, clockNow)
	local clock = { UnixNow = function() return clockNow() end, MonotonicNow = function() return clockNow() end }
	local store = Adapter.CreateMock({ ["Player_" .. userId] = saved })
	local actor = Actor.new({ userId = userId, sessionId = "S" .. userId, storeAdapter = store, clock = clock })
	local opened = actor:Open()
	assert(opened.ok, "Open")
	return actor, opened.value, store
end

do
	assert(Codec.Update4Profile and Codec.Update4Profile.HasSection("Retention"), "the dispatcher loads RetentionSection")
	local now = NOW0
	local actor, handle, store = newActor(11, { Version = 306, Speed = 5 }, function() return now end)
	local function retention()
		return actor:Inspect(handle).value.profile.U4.Retention
	end
	local function checkIn(day)
		local op = "u4streak:" .. day
		return actor:Commit(handle, { operationId = op, fingerprint = op, commands = { { kind = "U4.Retention.CheckIn", day = day } } })
	end
	assert(checkIn(DAY).kind == "Committed" and retention().StreakDays == 1, "first check-in")
	assert(checkIn(DAY).kind == "AlreadyCommitted" and retention().StreakDays == 1, "same day again: AlreadyCommitted, nothing changes")
	assert(checkIn(DAY + 1).kind == "Rejected", "a day that is not today is refused")
	-- Walk to day 14 (a check-in per day) and claim both milestones.
	for d = 1, 13 do
		now += 86400
		assert(checkIn(DAY + d).kind == "Committed", "day " .. d + 1)
	end
	local r = retention()
	assert(r.StreakDays == 14 and #r.StreakPending == 2, "two milestones pending on day 14")
	local function claim(key)
		local op = "u4streakclaim:" .. key
		return actor:Commit(handle, { operationId = op, fingerprint = op, commands = {
			{ kind = "U4.Retention.ClaimStreak", key = key }, { kind = "GrantSpinTickets", amount = 0 } } })
	end
	assert(claim("c1_d21").kind == "Rejected", "a key that is not pending is refused")
	assert(claim("c1_d14").kind == "Committed" and math.abs(retention().StreakPerk - 0.4) < 1e-9, "day 14 first: perk 0.4")
	assert(claim("c1_d7").kind == "Committed" and math.abs(retention().StreakPerk - 0.4) < 1e-9, "day 7 afterwards never lowers the perk")
	assert(claim("c1_d7").kind == "AlreadyCommitted", "each key pays once")
	assert(#retention().StreakPending == 0 and #retention().StreakClaimed == 2, "moved to Claimed")
	-- Playtime: in memory only, saved on Release.
	local writesBefore = store.writeCount or 0
	local volatile = { kind = "U4.Retention.Playtime", seconds = 1500, lastSeen = now, sessionStart = now - 1600 }
	local applied
	if type(actor.ApplyVolatile) == "function" then
		applied = actor:ApplyVolatile(handle, volatile)
		assert(applied.ok, "ApplyVolatile accepts the playtime")
		assert(not actor:ApplyVolatile(handle, { kind = "U4.Retention.CheckIn", day = DAY }).ok, "a check-in is not volatile")
	else
		print("NOTE SessionActor:ApplyVolatile is not there yet (p0_data): emulated through ProfileReducers")
		local Reducers = require("../src/common/ServerScriptService/Services/Data/ProfileReducers")
		applied = Reducers.ApplyCommand(actor.profile, volatile, now)
		assert(applied.ok, "reducer accepts the playtime")
	end
	assert(retention().PlaytimeSeconds == 1500, "live profile has the counter")
	if store.writeCount then
		assert(store.writeCount == writesBefore, "no DataStore write for the playtime")
	end
	assert(actor:Release(handle).kind == "Released", "Release")
	local saved = store:GetData("Player_11").U4.Retention
	assert(saved.PlaytimeSeconds == 1500 and saved.PlaytimeSessionStart == now - 1600 and saved.StreakDays == 14, "saved on Release")
	pass("SessionActor: check-in once per day (AlreadyCommitted), today only, claims pending-only and once, perk 0.2 -> 0.4, playtime volatile")
end

----------------------------------------------------------------------
-- 3. RetentionService.server.luau in a mocked game
----------------------------------------------------------------------
local function signal()
	local s = { list = {} }
	function s:Connect(fn)
		local entry = { fn = fn, on = true }
		table.insert(self.list, entry)
		return { Disconnect = function() entry.on = false end }
	end
	function s:Fire(...)
		for _, entry in table.clone(self.list) do
			if entry.on then
				entry.fn(...)
			end
		end
	end
	return s
end

local function object(class, name)
	local o = { __mock = true, ClassName = class, Name = name, children = {}, attrs = {}, attrSignals = {} }
	function o:IsA(c)
		return self.ClassName == c
	end
	function o:FindFirstChild(n)
		return self.children[n]
	end
	function o:WaitForChild(n)
		return self.children[n]
	end
	function o:GetAttribute(k)
		return self.attrs[k]
	end
	function o:GetAttributeChangedSignal(k)
		self.attrSignals[k] = self.attrSignals[k] or signal()
		return self.attrSignals[k]
	end
	function o:SetAttribute(k, v)
		local old = self.attrs[k]
		self.attrs[k] = v
		if old ~= v and self.attrSignals[k] then
			self.attrSignals[k]:Fire()
		end
	end
	function o:Destroy() end
	return o
end
local function child(parent, class, name, payload)
	local o = object(class, name)
	o.payload = payload
	parent.children[name] = o
	o.Parent = parent
	return o
end

local function runService(options)
	local clock = { unix = options.now, mono = 1000 }
	local waiting = {}
	local delayed = {}
	local fired = {} -- RetentionUpdate / toasts per player
	local steps, events, commits, volatiles = {}, {}, {}, {}
	local modules = {}

	local players = object("Players", "Players")
	players.PlayerAdded, players.PlayerRemoving = signal(), signal()
	local playerList = {}
	function players:GetPlayers()
		return playerList
	end
	local replicated = object("ReplicatedStorage", "ReplicatedStorage")
	local shared = child(replicated, "Folder", "Shared")
	for name, module in { Update4Config = U4, RetentionMath = RetentionMath, TutorialText = TutorialText } do
		modules[child(shared, "ModuleScript", name)] = module
	end
	local remotes = child(replicated, "Folder", "Remotes")
	local toastRemote = child(remotes, "RemoteEvent", "TemporaryBoostUpdate")
	function toastRemote:FireClient(player, data)
		table.insert(fired, { player = player, kind = "toast", data = data })
	end
	local sss = object("ServerScriptService", "ServerScriptService")
	local services = child(sss, "Folder", "Services")
	local data = child(services, "Folder", "Data")
	local workspace = object("Workspace", "Workspace")
	function workspace:GetServerTimeNow()
		return clock.unix + 0.25
	end

	-- DataService over real SessionActors (one per user).
	local actors, handles = {}, {}
	local DataService = {
		GetHandle = function(userId)
			return handles[userId]
		end,
		Inspect = function(handle)
			return actors[handle.userId]:Inspect(handle)
		end,
		Commit = function(handle, request)
			table.insert(commits, request.operationId)
			return actors[handle.userId]:Commit(handle, request)
		end,
		ApplyVolatile = function(handle, command)
			table.insert(volatiles, command)
			local actor = actors[handle.userId]
			if type(actor.ApplyVolatile) == "function" then
				return actor:ApplyVolatile(handle, command)
			end
			local Reducers = require("../src/common/ServerScriptService/Services/Data/ProfileReducers")
			return Reducers.ApplyCommand(actor.profile, command, clock.unix)
		end,
	}
	modules[child(data, "ModuleScript", "DataService")] = DataService
	modules[child(data, "ModuleScript", "Update4Profile")] = { HasSection = function(name) return options.titles == true and name == "Titles" end }
	local guardHandler = nil
	modules[child(services, "ModuleScript", "RemoteGuard")] = { Connect = function(_, _, handler)
		guardHandler = handler
	end }
	modules[child(services, "ModuleScript", "FunnelAnalytics")] = {
		Step = function(player, funnel, step, session)
			table.insert(steps, { funnel = funnel, step = step, session = session })
			return true
		end,
		Event = function(player, name, value)
			table.insert(events, name)
			return true
		end,
	}

	local game = { GetService = function(_, name)
		if name == "Players" then return players end
		if name == "ReplicatedStorage" then return replicated end
		if name == "ServerScriptService" then return sss end
		if name == "Workspace" then return workspace end
		error("unexpected service " .. name)
	end }

	local function spawnThread(fn, ...)
		local co = coroutine.create(fn)
		local ok, err = coroutine.resume(co, ...)
		assert(ok, tostring(err))
		if coroutine.status(co) == "suspended" then
			table.insert(waiting, co)
		end
		return co
	end
	local env = {
		game = game,
		typeof = function(v)
			if type(v) == "table" and v.__mock then
				return "Instance"
			end
			return typeof(v)
		end,
		require = function(target)
			local module = modules[target]
			assert(module ~= nil, "unexpected require " .. tostring(target and target.Name))
			return module
		end,
		Instance = { new = function(class)
			local o = object(class, class)
			o.OnServerEvent = signal()
			function o:FireClient(player, payload)
				table.insert(fired, { player = player, kind = self.Name, data = payload })
			end
			return setmetatable(o, { __newindex = function(self, k, v)
				rawset(self, k, v)
				if k == "Parent" and v then
					v.children[self.Name] = self
				end
			end })
		end },
		task = {
			spawn = spawnThread,
			defer = spawnThread,
			delay = function(seconds, fn, ...)
				table.insert(delayed, { at = clock.mono + seconds, fn = fn, args = table.pack(...) })
			end,
			wait = function()
				return coroutine.yield()
			end,
		},
		os = {
			time = function() return math.floor(clock.unix) end,
			clock = function() return clock.mono end,
		},
		_G = {},
		warn = function(...) error("warn: " .. table.concat({ ... }, " ")) end,
		table = table, math = math, string = string, pcall = pcall, type = type, tostring = tostring,
		tonumber = tonumber, ipairs = ipairs, pairs = pairs, setmetatable = setmetatable, select = select,
		error = error, print = print, coroutine = coroutine, next = next,
	}
	luau.load(read(SERVICE), { environment = env, debugName = "RetentionService" })()

	local world = {}
	function world.join(userId, saved)
		local actor = Actor.new({ userId = userId, sessionId = "S" .. userId, storeAdapter = Adapter.CreateMock({ ["Player_" .. userId] = saved }),
			clock = { UnixNow = function() return math.floor(clock.unix) end, MonotonicNow = function() return clock.mono end } })
		local opened = actor:Open()
		assert(opened.ok, "Open " .. userId)
		actors[userId], handles[userId] = actor, opened.value
		local player = object("Player", "P" .. userId)
		player.UserId, player.LocaleId, player.Parent = userId, "en-us", players
		table.insert(playerList, player)
		players.PlayerAdded:Fire(player)
		player:SetAttribute("DataLoaded", true)
		return player, actor, opened.value
	end
	function world.advance(seconds, step)
		local tick = step or 5
		local elapsed = 0
		while elapsed < seconds do
			clock.unix += tick
			clock.mono += tick
			elapsed += tick
			-- task.delay callbacks that are due run as threads of their own.
			local due, later = {}, {}
			for _, entry in delayed do
				table.insert(if entry.at <= clock.mono then due else later, entry)
			end
			delayed = later
			for _, entry in due do
				spawnThread(entry.fn, table.unpack(entry.args, 1, entry.args.n))
			end
			local resume = waiting
			waiting = {}
			for _, co in resume do
				local ok, err = coroutine.resume(co)
				assert(ok, tostring(err))
				if coroutine.status(co) == "suspended" then
					table.insert(waiting, co)
				end
			end
		end
	end
	function world.request(player, ...)
		guardHandler(player, ...)
	end
	function world.release(player)
		env._G.SpeedsterBeforeRelease.Retention(player)
		players.PlayerRemoving:Fire(player)
		local actor = actors[player.UserId]
		assert(actor:Release(handles[player.UserId]).kind == "Released", "Release")
	end
	world.clock, world.fired, world.steps, world.events, world.commits, world.volatiles, world.env =
		clock, fired, steps, events, commits, volatiles, env
	return world
end

local function count(list, predicate)
	local n = 0
	for _, item in list do
		if predicate(item) then
			n += 1
		end
	end
	return n
end

do
	-- A returning player (streak day 6 yesterday) joins: one check-in after 60 s, day 7 pending.
	local world = runService({ now = NOW0, titles = true })
	local saved = { Version = 306, Speed = 5, U4 = { V = 1, Retention = {
		StreakDays = 6, StreakLastDay = DAY - 1, StreakBest = 6, StreakGraceDay = 0, StreakPerk = 0,
		StreakPending = {}, StreakClaimed = {}, PlaytimeSeconds = 0, PlaytimeLastSeen = 0, PlaytimeSessionStart = 0 } } }
	local player, actor, handle = world.join(21, saved)
	assert(player:GetAttribute("StreakDays") == 6, "yesterday's streak still counts before today's check-in")
	assert(player:GetAttribute("PlaytimeBoostPct") == 0 and math.abs(player:GetAttribute("RetentionSpeedGainMultiplier") - 1.6) < 1e-9, "x1.6 at join (6 days)")
	world.advance(55)
	assert(#world.commits == 0, "no check-in before 60 s in game")
	world.advance(30)
	assert(#world.commits == 1 and world.commits[1] == "u4streak:" .. DAY, "one check-in Commit after 60 s")
	world.advance(600)
	assert(#world.commits == 1, "still one Commit after 10 more minutes (the timer never commits)")
	assert(player:GetAttribute("StreakDays") == 7 and player:GetAttribute("StreakRewardPending") == true, "day 7, reward pending")
	assert(count(world.events, function(e) return e == "Streak_Day7_v2" end) == 1, "Streak_Day7_v2 logged")
	assert(count(world.steps, function(s) return s.funnel == "Retention_Streak" and s.step == 1 and s.session == "21-streak-" .. DAY end) == 1, "Retention_Streak step 1 with the day session")
	assert(player:GetAttribute("PlaytimeBoostPct") == 10, "+10 % after 10 minutes")
	assert(count(world.fired, function(f) return f.kind == "toast" and string.find(f.data.Message, "Day 7 streak!", 1, true) ~= nil end) == 1, "day toast")
	assert(count(world.fired, function(f) return f.kind == "toast" and string.find(f.data.Message, "Day 7 streak reward ready", 1, true) ~= nil end) == 1,
		"milestone toast once, after the day's")
	assert(count(world.steps, function(s) return s.funnel == "Retention_PlaytimeBoost" and s.step == 1 end) == 1, "Playtime_10m step")
	assert(#world.volatiles >= 10, "the counter is saved in memory every 60 s")
	local anchor = player:GetAttribute("PlaytimeSessionAnchor")
	assert(type(anchor) == "number", "anchor published")
	-- Race: the multiplier is 1 while racing.
	player:SetAttribute("RaceActive", true)
	assert(player:GetAttribute("RetentionSpeedGainMultiplier") == 1, "1 while racing")
	player:SetAttribute("RaceActive", false)
	assert(math.abs(player:GetAttribute("RetentionSpeedGainMultiplier") - (1 + 0.1 + 0.7)) < 1e-9, "x1.8 again after the race")
	-- The panel opens (step 2) and claims (step 3): one Commit, perk 0.2, title asked for.
	world.request(player, "Get", "Streak")
	assert(count(world.steps, function(s) return s.funnel == "Retention_Streak" and s.step == 2 end) == 1, "panel step 2")
	world.request(player, "Bogus", 5)
	world.request(player, 42)
	world.request(player, "ClaimStreak")
	assert(#world.commits == 2 and world.commits[2] == "u4streakclaim:c1_d7", "claim Commit")
	local retention = actor:Inspect(handle).value.profile.U4.Retention
	assert(math.abs(retention.StreakPerk - 0.2) < 1e-9 and #retention.StreakPending == 0, "perk 0.2, nothing pending")
	assert(player:GetAttribute("StreakRewardPending") == false and math.abs(player:GetAttribute("StreakPerk") - 0.2) < 1e-9, "attributes follow")
	world.request(player, "ClaimStreak")
	assert(#world.commits == 2, "nothing more to claim: no Commit")
	local last = world.fired[#world.fired]
	assert(last.kind == "RetentionUpdate" and last.data.Message == "No streak reward to claim yet.", "answered")
	assert(last.data.Streak.Days == 7 and last.data.Playtime.Pct == 10, "payload shape")
	-- Leaves 5 minutes after the 10-minute mark: the counter goes into the profile.
	world.advance(300)
	world.release(player)
	local stored = actor:Inspect(handle).value.profile
	pass("service: one check-in Commit after 60 s, day 7 pending + event, 10 % at 10 min, race = x1, claim once")

	-- Teleport: back 10 minutes later on another server; seconds and session are kept.
	local seconds = stored.U4.Retention.PlaytimeSeconds
	local session = stored.U4.Retention.PlaytimeSessionStart
	assert(seconds >= 900 and session == NOW0, "counter and session saved at leave")
	local world2 = runService({ now = world.clock.unix + 600 })
	local saved2 = { Version = 306, Speed = 5, U4 = stored.U4 }
	local p2 = world2.join(21, saved2)
	assert(p2:GetAttribute("PlaytimeBoostPct") == 10, "+10 % kept across the teleport")
	assert(count(world2.steps, function(s) return s.funnel == "Retention_PlaytimeBoost" and s.step == 1 and s.session == "21-pt-" .. NOW0 end) == 1,
		"the reached step is replayed under the same session id")
	assert(count(world2.steps, function(s) return s.funnel == "Retention_Streak" and s.step == 1 end) == 1, "today's check-in known on the new server")
	world2.advance(120)
	assert(#world2.commits == 0, "already checked in today: no second Commit on the new server")
	pass("service: teleport within 15 min keeps the seconds and the funnel session, no second check-in")

	-- After 16 minutes away: a new session.
	local world3 = runService({ now = world.clock.unix + 960 })
	local p3 = world3.join(21, { Version = 306, Speed = 5, U4 = stored.U4 })
	assert(p3:GetAttribute("PlaytimeBoostPct") == 0, "16 min away: the boost starts over")
	pass("service: 16 minutes away resets the Playtime Boost")
end

do
	-- Midnight: a player online across the UTC rollover checks in once for the new day.
	local world = runService({ now = (DAY + 1) * 86400 - 120 })
	local player = world.join(31, { Version = 306, Speed = 1 })
	world.advance(90)
	assert(#world.commits == 1 and world.commits[1] == "u4streak:" .. DAY, "first day")
	world.advance(120)
	assert(#world.commits == 2 and world.commits[2] == "u4streak:" .. (DAY + 1), "the next UTC day checks in at the rollover")
	assert(player:GetAttribute("StreakDays") == 2, "day 2")
	pass("service: the UTC rollover checks online players in once")
end

do
	-- A newcomer in the tutorial: checked in at 60 s like anyone, but no toast pops up (PLAN §7.7).
	local world = runService({ now = NOW0 })
	local player = world.join(41, { Version = 306, Speed = 1 })
	player:SetAttribute("FirstTimeTutorialActive", true)
	world.advance(90)
	assert(#world.commits == 1 and player:GetAttribute("StreakDays") == 1, "day 1 checked in during the tutorial")
	assert(count(world.fired, function(f) return f.kind == "toast" end) == 0, "no toast during the tutorial")
	player:SetAttribute("FirstTimeTutorialActive", false)
	world.advance(600)
	assert(count(world.fired, function(f) return f.kind == "toast" end) == 1, "the 10-minute toast after the tutorial")
	pass("service: newcomers see no retention toast during the tutorial")
end

----------------------------------------------------------------------
-- 4. Static: timers never Commit; Playtime goes through ApplyVolatile
----------------------------------------------------------------------
do
	local source = read(SERVICE)
	local loopStart = string.find(source, "local function tickPlayer", 1, true)
	assert(loopStart, "tickPlayer present")
	local loop = string.sub(source, loopStart)
	assert(not string.find(loop, "DataService.Commit", 1, true), "no DataService.Commit in the timer loop")
	assert(string.find(loop, "task.spawn(checkIn", 1, true), "the check-in runs in its own thread")
	-- ApplyVolatile waits for the session lock: never inline in the shared loop.
	assert(string.find(loop, "task.spawn(function()\n\t\t\t\tpcall(saveVolatile, player, state)", 1, true)
		and not string.find(loop, "\n\t\t\tsaveVolatile(player, state)", 1, true), "the volatile save runs in its own thread")
	assert(string.find(source, "DataService.ApplyVolatile", 1, true) and string.find(source, "\"U4.Retention.Playtime\"", 1, true), "Playtime saved with ApplyVolatile")
	local commitsInFile = select(2, string.gsub(source, "pcall%(DataService%.Commit", ""))
	assert(commitsInFile == 2, "exactly two Commits: check-in and claim")
	assert(string.find(source, "\"u4streak:\" .. day", 1, true) and string.find(source, "\"u4streakclaim:\" .. key", 1, true), "operation ids per §2.2")
	assert(string.find(source, "beforeRelease.Retention", 1, true), "saved before Release")
	pass("static: no Commit in the timer loop, Playtime via ApplyVolatile, operation ids")
end

print(string.format("\n%d checks passed", passed))
