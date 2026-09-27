-- test_u4_race_validation.luau (Update 4, race_server, 2026-09-25)
-- Server authority (PLAN §3.3 / §7.3 item 6): the real Services/Race/RaceService and
-- RaceChargeJudge run on a fake clock against simulated clients. Each client predicts its own
-- race with Shared/RaceMath (the same code as RaceInputClient), charges with a closed-loop
-- press rhythm, sends RaceSprint / RaceChargeInput with 0-300 ms of jitter, and the server
-- samples its position the way replication delivers it (late, jittered, sometimes stale).
--   honest clients with jitter, loss and lag spikes -> 0 corrections, everyone finishes, >= 30 s;
--   a x1.3 speed hack is corrected within 2 s at sprint speed mid-race (3 s from GO, see below);
--   teleporting to the finish -> DQ after 3 strikes (no finish, no PB);
--   ignoring spikes gains <= 0.55 s of sprint per spike (40 studs at the old 74 studs/s) and is
--   corrected (every field: 3 strikes, DQ);
--   a false start is pulled back to the slot and held 0.3 s past GO;
--   a fall off the track is recovered without a DNF; leaving the corridor is a DNF "Left".
-- 2026-09-25 (owner: the speed follows the Speed stat): each simulated racer has its own Speed
-- stat (spec.rawSpeed, default 1e6 = 76 studs/s cruise) and predicts from the Staged payload as
-- the real client does; honest heats mixing Speed 1 (40), 1e9 (94) and 1e18 (148) get no
-- corrections and everyone finishes (the heat waits for its slowest racer); a x1.3 hack at the
-- speed cap is corrected as fast as at 76.
-- 2026-09-26 (owner: Sonic Dash speeds, 100 + 18 log10(Speed + 1) capped at 300; spike rows 90
-- apart, 10 of them): default Speed 1e6 = 208 cruise; mixed heats Speed 1 (105), 1e9 (262),
-- 1e18 (300); races last 5-25 s, so the mid-race hacks start 1.5 s after GO, in lane 3, and the
-- lead per spike is counted per row the lane crosses blocked.
-- Run: lune run audit/test_u4_race_validation.luau   (from the project root)
local roblox = require("@lune/roblox")
local Vector3, CFrame = roblox.Vector3, roblox.CFrame

local U4 = require("../src/common/ReplicatedStorage/Shared/Update4Config")
local RaceTrack = require("../src/common/ReplicatedStorage/Shared/RaceTrack")
local RaceMath = require("../src/common/ReplicatedStorage/Shared/RaceMath")
local RaceChargeMath = require("../src/common/ReplicatedStorage/Shared/RaceChargeMath")
local RaceService = require("../src/common/ServerScriptService/Services/Race/RaceService")
local RaceChargeJudge = require("../src/common/ServerScriptService/Services/Race/RaceChargeJudge")

local P = U4.Race.Charge
local QUEUE = U4.Race.Queue
local passed = 0
local function pass(text)
	passed += 1
	print("PASS " .. text)
end

----------------------------------------------------------------------
-- Deterministic random numbers (the test must not flake)
----------------------------------------------------------------------
-- One generator for the race setups, and one per simulated client (seeded from it): the service
-- visits players in table order, so a shared generator would make the draws order-dependent.
local function generator(seed)
	local state = seed % 2147483648
	return function()
		state = (state * 1103515245 + 12345) % 2147483648
		return state / 2147483648
	end
end
local rand = generator(12345)

----------------------------------------------------------------------
-- Fake players and world
----------------------------------------------------------------------
local LOBBY = Vector3.new(300, 37470.69, -1700)

local function newPlayer(id)
	local p = {
		UserId = id,
		Name = "Racer" .. id,
		present = true,
		attrs = { DataLoaded = true, FirstTimeTutorialSeen = true, Rebirths = 2, RaceFinishes = 10 },
		char = { pos = LOBBY, alive = true },
		progress = 1,
		events = {},
	}
	function p:GetAttribute(name)
		return self.attrs[name]
	end
	function p:SetAttribute(name, value)
		self.attrs[name] = value
	end
	return p
end

local function newWorld()
	local W = { now = 1000, clock = 1.8e9, attrs = {}, players = {}, queue = {}, nextTick = 1000, paid = {} }
	local function schedule(at, fn)
		table.insert(W.queue, { at = at, fn = fn, order = #W.queue })
	end
	W.schedule = schedule

	local host = {}
	host.now = function()
		return W.now
	end
	host.unix = function()
		return math.floor(W.clock + (W.now - 1000))
	end
	host.isOn = function()
		return true
	end
	host.players = function()
		return W.players
	end
	host.isPlayer = function(player)
		return player.present == true
	end
	host.sample = function(player)
		local sim = player.sim
		if sim and sim.observe then
			return sim.observe(W.now)
		end
		return { alive = player.char.alive, position = player.char.pos, cframe = CFrame.new(player.char.pos), grounded = true }
	end
	host.pivot = function(player, cframe)
		player.char.pos = cframe.Position
		player.pivots = (player.pivots or 0) + 1
		local sim = player.sim
		if sim and sim.state then
			local s, x = RaceTrack.ToLocal(cframe.Position)
			local lat = sim.latency(W.now)
			schedule(W.now + lat, function()
				sim.state.s, sim.x, sim.y = s, x, RaceTrack.RootHeight
				sim.pivoted = true
			end)
		end
	end
	host.setVelocity = function() end
	host.streamAround = function(_, _, done)
		done()
	end
	host.rebase = function(player)
		player.rebases = (player.rebases or 0) + 1
	end
	host.getProgress = function(player)
		return player.progress
	end
	host.armGrace = function() end
	host.teleportToSpawn = function(player)
		player.char.pos = LOBBY
	end
	host.ping = function(player)
		return player.sim and player.sim.base * 2 or 0
	end
	host.fire = function(player, payload)
		table.insert(player.events, payload)
		local sim = player.sim
		if payload.kind == "Staged" then
			player.staged = payload
		elseif sim and payload.kind == "Start" then
			schedule(W.now + sim.latency(W.now), function()
				if sim.state then
					sim.state.grade = payload.grade
				end
			end)
		elseif sim and payload.kind == "Stumble" and not sim.spec.ignoreSpikes then
			-- The server confirms a stumble (a fall, or a spike the client missed): the client applies
			-- it; a spike the client already hit is still inside its immunity, so nothing doubles.
			schedule(W.now + sim.latency(W.now), function()
				if sim.state then
					RaceMath.SpikeHit(sim.state, W.now)
				end
			end)
		elseif sim and payload.kind == "Correction" then
			player.corrections = (player.corrections or 0) + 1
			player.firstCorrectionAt = player.firstCorrectionAt or W.now
			schedule(W.now + sim.latency(W.now), function()
				if sim.state then
					sim.state.v = payload.v
				end
			end)
		end
	end
	host.live = function() end
	host.setWorld = function(name, value)
		W.attrs[name] = value
	end
	host.getWorld = function(name)
		return W.attrs[name]
	end
	host.setGateCollide = function(on)
		W.gate = on
	end
	host.rawSpeed = function(player)
		return player.sim and player.sim.spec.rawSpeed or 1e6
	end
	host.suitMax = function()
		return 5
	end
	host.dailyFirst = function()
		return false
	end
	host.raceStats = function()
		return { Races = 5 }
	end
	host.prepare = function(_, outcome)
		return { rewards = { wins = if outcome.finished then 10 else 0, rewarded = outcome.finished or false } }
	end
	host.pay = function(player, outcome, _, done)
		W.paid[player] = outcome
		done({ ok = true, wins = 0, speed = 0, tickets = 0, pb = outcome.finished, weekId = 1 })
	end
	host.submitPb = function(player)
		player.pbSubmitted = true
	end
	host.funnel = {}
	W.judge = RaceChargeJudge.new({
		now = host.now,
		fire = host.fire,
		onJudged = function(player, grade, held)
			W.service:OnJudged(player, grade, held)
		end,
	})
	host.judge = W.judge
	W.host = host
	W.service = RaceService.new(host)
	return W
end

local function runDue(W)
	table.sort(W.queue, function(a, b)
		if a.at ~= b.at then
			return a.at < b.at
		end
		return a.order < b.order
	end)
	while W.queue[1] and W.queue[1].at <= W.now + 1e-9 do
		local item = table.remove(W.queue, 1)
		item.fn()
	end
end

----------------------------------------------------------------------
-- Simulated client
----------------------------------------------------------------------
-- A closed-loop charger (as in test_u4_race_charge): press `reaction` after the window opens,
-- release `reaction` after the needle passes the top of the core, press again after it drops.
local function closedLoop(openAt, goAt, reaction)
	local edges = { openAt + reaction }
	local pendingAt = nil
	local t = edges[1]
	while t < goAt do
		t += 1 / 240
		if pendingAt and t >= pendingAt then
			table.insert(edges, pendingAt)
			pendingAt = nil
		end
		local now = RaceChargeMath.Evaluate(edges, openAt, goAt, t, P)
		local held = #edges % 2 == 1
		if not pendingAt and not now.Venting then
			if (held and now.G >= P.CoreHi) or (not held and now.G <= P.CoreLo) then
				pendingAt = t + reaction
			end
		end
	end
	local clean = {}
	for _, e in edges do
		if e < goAt then
			table.insert(clean, e)
		end
	end
	return clean
end

-- spec = { lane, policy(state, t) -> sprint, base latency, jitter, loss, reaction,
--   speedHack = {from, factor}, teleportAt, ignoreSpikes, jumpEvery, fallAt, exitAt }
local function attachClient(W, player, spec)
	local sim = { spec = spec, hist = {}, base = spec.base or 0.1, x = 0, y = RaceTrack.RootHeight }
	local own = generator(math.floor(rand() * 2147483647))
	local phase = own() * 10
	local walk = 0
	function sim.latency(now)
		-- A smooth wobble plus a little random walk, clamped to 0..300 ms.
		walk = math.clamp(walk + (own() - 0.5) * 0.02, -0.08, 0.08)
		return math.clamp(sim.base + (spec.jitter or 0) * math.sin(now * 1.7 + phase) + walk, 0, 0.3)
	end
	local last = nil
	function sim.observe(now)
		if not sim.state then
			last = { alive = player.char.alive, position = player.char.pos, cframe = CFrame.new(player.char.pos), grounded = true }
			return last
		end
		if last and spec.loss and own() < spec.loss then
			return last -- nothing new arrived this step
		end
		if last and spec.lagSpikeEvery and (now % spec.lagSpikeEvery) < 0.8 then
			return last -- a lag spike: the server holds the last position for 0.8 s, then a burst
		end
		local at = now - sim.latency(now)
		local hist = sim.hist
		local a, b = hist[1], hist[#hist]
		if not a or at <= a.t then
			return last or { alive = true, position = player.char.pos, cframe = CFrame.new(player.char.pos), grounded = true }
		end
		for index = #hist, 2, -1 do
			if hist[index - 1].t <= at then
				a, b = hist[index - 1], hist[index]
				break
			end
		end
		local w = if b.t > a.t then math.clamp((at - a.t) / (b.t - a.t), 0, 1) else 1
		local s = a.s + (b.s - a.s) * w
		local x = a.x + (b.x - a.x) * w
		local y = a.y + (b.y - a.y) * w
		local position = RaceTrack.ToWorld(s, x, y)
		last = { alive = true, position = position, cframe = CFrame.new(position), grounded = y <= RaceTrack.RootHeight + 0.01 }
		return last
	end
	player.sim = sim
	return sim
end

local function startClient(W, player)
	local sim, spec, staged = player.sim, player.sim.spec, player.staged
	local goAt = staged.goAt
	local s0, x0 = RaceTrack.ToLocal(player.char.pos)
	sim.x = x0
	if spec.lane then
		sim.x = RaceTrack.LaneX(spec.lane)
	end
	-- As Race/RaceInputClient: the numbers of the Staged payload (the server's RaceMath.Params).
	local params = { Vc = staged.cruise, Vs = staged.sprint, b = 0, sprintSeconds = staged.sprintSeconds, regenFactor = staged.regenFactor }
	sim.params = params
	local result = RaceChargeMath.Evaluate(sim.edges or {}, goAt - QUEUE.ChargeOpenLeadSeconds, goAt, goAt, P)
	local grade = RaceChargeMath.Outcome(result, P, (tonumber(player.attrs.RaceFinishes) or 0) < P.GraceRaces, false)
	sim.predicted = grade
	sim.state = RaceMath.NewState(params, grade, nil, goAt, s0)
	sim.state.pool = math.clamp(1 - RaceChargeMath.StaminaCost(result.HeldSeconds), 0, 1)
	sim.sprintSent = false
	sim.airUntil = nil
	table.insert(sim.hist, { t = goAt, s = s0, x = sim.x, y = sim.y })
end

local function stepClient(W, player, dt)
	local sim = player.sim
	local spec, state, t = sim.spec, sim.state, W.now
	local sprint = if spec.policy then spec.policy(state, t) else false
	if sprint ~= sim.sprintSent then
		sim.sprintSent = sprint
		W.schedule(t + sim.latency(t), function()
			W.service:SetSprint(player, sprint)
		end)
	end
	local jumped = false
	if spec.jumpEvery and (not sim.airUntil or t >= sim.airUntil) and t >= (sim.nextJump or state.goAt + spec.jumpEvery) then
		jumped = true
		sim.jumpAt, sim.airUntil = t, t + 0.5
		sim.nextJump = t + spec.jumpEvery
	end
	local airborne = sim.airUntil ~= nil and t < sim.airUntil
	local s0 = state.s
	RaceMath.Step(state, { forward = 1, sprint = sprint, grounded = not airborne, jumped = jumped }, dt, sim.params, t)
	local hack = spec.speedHack
	if hack and t >= hack.from and (sim.hackStart or not hack.whileSprinting or state.sprinting) then
		sim.hackStart = sim.hackStart or t
		state.s = s0 + (state.s - s0) * hack.factor
	end
	if spec.teleportAt and t >= spec.teleportAt then
		state.s = RaceTrack.Length + 5
	end
	sim.y = if airborne then RaceTrack.RootHeight + 7 * math.sin(math.pi * (t - sim.jumpAt) / 0.5) else RaceTrack.RootHeight
	if spec.fallAt and t >= spec.fallAt and not sim.fell then
		sim.fell = true
		sim.fallUntil = t + 0.6
	end
	if sim.fallUntil and t < sim.fallUntil and not sim.pivoted then
		sim.y = -40
	end
	if spec.exitAt and t >= spec.exitAt then
		sim.x = 70
	end
	if not spec.ignoreSpikes and RaceTrack.SpikeAt(state.s, sim.x, sim.y) then
		if RaceMath.SpikeHit(state, t) then
			sim.spikes = (sim.spikes or 0) + 1
		end
	end
	if not sim.finishT and state.s >= RaceTrack.Length then
		sim.finishT = t
	end
	table.insert(sim.hist, { t = t, s = state.s, x = sim.x, y = sim.y })
	if #sim.hist > 400 then
		table.remove(sim.hist, 1)
	end
end

local DT = 1 / 60
local function advance(W, seconds)
	local stop = W.now + seconds
	while W.now < stop - 1e-9 do
		W.now += DT
		runDue(W)
		for _, player in W.players do
			local sim = player.sim
			-- The client starts its own prediction at GO (RaceGoAt), and stands still while held.
			if sim and player.staged and not sim.state and W.now >= player.staged.goAt and player.attrs.RaceActive == true then
				startClient(W, player)
			end
			if sim and sim.state and player.attrs.RaceMovementLocked ~= true then
				stepClient(W, player, DT)
			end
		end
		if W.now >= W.nextTick then
			W.nextTick += 0.05
			W.service:Tick(W.now)
		end
	end
end

-- Joins every spec'd player, runs gathering/staging, sends the charge edges and returns at GO.
local function setupRace(specs)
	local W = newWorld()
	for index, spec in specs do
		local player = newPlayer(index)
		table.insert(W.players, player)
		attachClient(W, player, spec)
	end
	for _, player in W.players do
		assert(W.service:Join(player, "Hud") == true, "join")
	end
	advance(W, QUEUE.GatherSeconds + 0.2)
	assert(W.service.phase == "Staging", "staging after gathering, got " .. tostring(W.service.phase))
	for _, player in W.players do
		local staged = assert(player.staged, "Staged event")
		local sim = player.sim
		local openAt = staged.goAt - QUEUE.ChargeOpenLeadSeconds
		sim.edges = if sim.spec.reaction then closedLoop(openAt, staged.goAt, sim.spec.reaction) else {}
		for index = 1, #sim.edges do
			local copy = table.move(sim.edges, 1, index, 1, {})
			W.schedule(sim.edges[index] + sim.latency(sim.edges[index]), function()
				W.judge:Input(player, staged.raceId, copy, false)
			end)
		end
		W.schedule(staged.goAt + sim.latency(staged.goAt), function()
			W.judge:Input(player, staged.raceId, table.clone(sim.edges), true)
		end)
	end
	W.goAt = W.players[1].staged.goAt
	W.race = W.service.race
	return W
end

local function racerOf(W, player)
	for _, racer in W.race.racers do
		if racer.player == player then
			return racer
		end
	end
	return nil
end

local function greedy()
	return true
end
local function paced(threshold)
	local on = true
	return function(state)
		if on and not state.sprinting and state.pool <= 0.001 then
			on = false
		elseif not on and state.pool >= threshold then
			on = true
		end
		return on
	end
end
local function never()
	return false
end

----------------------------------------------------------------------
-- Honest clients: jitter, loss, jumps, spikes -> no corrections
----------------------------------------------------------------------
do
	local policies = {
		function() return greedy end,
		function() return paced(0.5) end,
		function() return paced(0.9) end,
		function() return never end,
	}
	local races, maxCorrections, finishers = 0, 0, 0
	for run = 1, 10 do
		local specs = {}
		for k = 1, 2 do
			table.insert(specs, {
				lane = ((run + k) % 8) + 1,
				policy = policies[((run + k) % #policies) + 1](),
				base = 0.03 + 0.12 * rand(),
				jitter = 0.05 + 0.1 * rand(),
				loss = 0.05,
				reaction = if (run + k) % 3 == 0 then nil else 0.10 + 0.25 * rand(),
				jumpEvery = if run % 2 == 0 then 3 + 2 * rand() else nil,
				lagSpikeEvery = if (run + k) % 4 == 1 then 5 + 3 * rand() else nil,
			})
		end
		local W = setupRace(specs)
		advance(W, QUEUE.StagingSeconds + QUEUE.CountdownSeconds + QUEUE.MaxRaceSeconds + 2)
		races += 1
		for _, player in W.players do
			local racer = racerOf(W, player)
			maxCorrections = math.max(maxCorrections, player.corrections or 0)
			assert((player.corrections or 0) == 0, string.format("run %d honest racer %d corrected %d time(s) (lat %.2f)", run, player.UserId, player.corrections or 0, player.sim.base))
			assert(racer.finished and not racer.dq, string.format("run %d racer %d finished (%s %s)", run, player.UserId, tostring(racer.outcome), tostring(racer.reason)))
			assert(racer.finishMs >= RaceMath.PlausibleMs(racer.params), "finish time over the racer's plausibility floor")
			-- The server's time is the client's own within the latency (a lag spike over the line
			-- can only make it later: the server times what it sees).
			local late = racer.finishMs / 1000 - (player.sim.finishT - W.goAt)
			local bound = if player.sim.spec.lagSpikeEvery then 0.35 + 0.8 else 0.35
			assert(late >= -0.35 and late <= bound, string.format("server time %.3f vs client %.3f", racer.finishMs / 1000, player.sim.finishT - W.goAt))
			finishers += 1
		end
	end
	pass(string.format("honest clients (0-300 ms jitter, 5 %% loss, 0.8 s lag spikes, jumps, spikes, 4 sprint styles): %d races, %d finishers, 0 corrections", races, finishers))
end

----------------------------------------------------------------------
-- Honest heats mixing speeds (Open / Mega): nobody corrected, the slowest still finishes
----------------------------------------------------------------------
do
	local finishers, slowestMs, fastestMs = 0, 0, math.huge
	for run = 1, 4 do
		local W = setupRace({
			{ lane = 1, rawSpeed = 1, policy = paced(0.6), base = 0.03 + 0.2 * rand(), jitter = 0.08, loss = 0.05, reaction = 0.12 },
			{ lane = 4, rawSpeed = 1e9, policy = greedy, base = 0.03 + 0.2 * rand(), jitter = 0.08, loss = 0.05, reaction = if run % 2 == 0 then 0.2 else nil },
			{ lane = 7, rawSpeed = 1e18, policy = paced(0.9), base = 0.03 + 0.2 * rand(), jitter = 0.08, loss = 0.05, reaction = 0.15,
				jumpEvery = if run % 2 == 1 then 3 else nil },
		})
		advance(W, QUEUE.StagingSeconds + QUEUE.CountdownSeconds + QUEUE.MaxRaceSeconds + 2)
		for index, player in W.players do
			local racer = racerOf(W, player)
			assert((player.corrections or 0) == 0, string.format("mixed run %d racer %d corrected %d time(s)", run, index, player.corrections or 0))
			assert(racer.finished and not racer.dq, string.format("mixed run %d racer %d (Speed %g) finished (%s %s)", run, index,
				player.sim.spec.rawSpeed, tostring(racer.outcome), tostring(racer.reason)))
			finishers += 1
		end
		local slow, fast = racerOf(W, W.players[1]), racerOf(W, W.players[3])
		assert(fast.place == 1 and slow.place == 3, "the fastest Speed stat wins an honest mixed heat")
		slowestMs, fastestMs = math.max(slowestMs, slow.finishMs), math.min(fastestMs, fast.finishMs)
	end
	pass(string.format("honest mixed heats (Speed 1 / 1e9 / 1e18, jitter, loss): %d finishers, 0 corrections, %.1f s .. %.1f s", finishers, fastestMs / 1000, slowestMs / 1000))
end

----------------------------------------------------------------------
-- x1.3 speed hack
----------------------------------------------------------------------
do
	-- The spec's fixed slack (SlackStuds 10 + LatencySeconds 0.3 x v) sets how soon a x1.3 runner
	-- can show: the gap grows by 0.3 v a second and must beat 0.06 x progress + 10 + 0.3 v, which
	-- takes (10 / v + 0.3) / 0.24 s: 1.85 s at sprint speed (74 studs/s), 2.07 s at cruise, and
	-- ~2.6 s from GO while the runner is still accelerating (faster at higher speeds: the slack is
	-- fixed studs). So mid-race the hack starts at a
	-- sprint and must be caught within 2 s; from GO within 3 s. Honest clients use at most ~13 of
	-- those studs (measured with 0-300 ms jitter); tightening them is an Update4Config decision.
	-- 2026-09-25: also at the speed cap (148 cruise / 207 sprint), where a race lasts ~11 s. The
	-- mid-race hack starts with the first sprint after `from`, between two spike fields (10 s at
	-- 76 cruise, 3 s at 148): a stumble inside the window would blur the measure.
	for _, case in { { from = 0, label = "from GO", bound = 3.0 }, { from = 10, label = "mid-race sprint", bound = 2.0, sprinting = true },
		{ from = 0, label = "from GO at the speed cap", bound = 3.0, rawSpeed = 1e18 },
		{ from = 3, label = "mid-race sprint at the speed cap", bound = 2.0, sprinting = true, rawSpeed = 1e18 } } do
		-- 2026-09-26: a race is 5-9 s at these speeds and a spike row comes every <= 450 studs of a
		-- lane (0.2-1.5 s), so no 2 s window mid-race is free of a trip, and a trip slows the hacker's
		-- gain for ~1 s: the mid-race hacks start at 1.5 s in lane 3 (blocked at 390, 840, 1290,
		-- 1650) and must be caught within 2.5 s. (From GO: 3 s, as before.)
		if case.sprinting then
			case.from, case.bound, case.lane = 1.5, 2.5, 3
		end
		local W = setupRace({
			{ lane = case.lane or 1, rawSpeed = case.rawSpeed, policy = paced(0.6), base = 0.08, jitter = 0.05, speedHack = { from = 0, factor = 1.3 }, reaction = 0.12 },
			{ lane = 5, rawSpeed = case.rawSpeed, policy = paced(0.6), base = 0.08, jitter = 0.05, reaction = 0.12 },
		})
		W.players[1].sim.spec.speedHack.from = W.goAt + case.from
		W.players[1].sim.spec.speedHack.whileSprinting = case.sprinting
		advance(W, QUEUE.StagingSeconds + QUEUE.CountdownSeconds + 20)
		local cheater, honest = W.players[1], W.players[2]
		assert(cheater.firstCorrectionAt, "x1.3 corrected " .. case.label)
		local after = cheater.firstCorrectionAt - cheater.sim.hackStart
		assert(after <= case.bound, string.format("x1.3 %s corrected within %.0f s (%.2f s)", case.label, case.bound, after))
		assert((honest.corrections or 0) == 0, "the honest racer next to them is never corrected")
		print(string.format("  x1.3 %s: first correction after %.2f s", case.label, after))
	end
	pass("x1.3 speed is corrected within 2.5 s mid-race (at a sprint, a spike row in every window) and within 3 s from GO, at 208 and at 300 studs/s cruise")
end

----------------------------------------------------------------------
-- Teleport to the finish
----------------------------------------------------------------------
do
	local W = setupRace({
		{ lane = 2, policy = greedy, base = 0.1, jitter = 0.05, reaction = 0.12 },
		{ lane = 6, policy = paced(0.6), base = 0.1, jitter = 0.05, reaction = 0.12 },
	})
	W.players[1].sim.spec.teleportAt = W.goAt + 6
	advance(W, QUEUE.StagingSeconds + QUEUE.CountdownSeconds + QUEUE.MaxRaceSeconds + 3)
	local racer = racerOf(W, W.players[1])
	assert(racer.dq == true and racer.v.strikes == U4.Race.Validation.MaxStrikes, "teleporter DQ after 3 strikes (" .. tostring(racer.v.strikes) .. ")")
	assert(not racer.finished and W.paid[W.players[1]].dq == true and W.players[1].pbSubmitted ~= true, "no finish, paid as DQ, no PB")
	assert(W.players[1].attrs.RaceFinishMs == nil, "no finish time published")
	local honest = racerOf(W, W.players[2])
	assert(honest.finished and honest.place == 1, "the honest racer wins")
	pass("teleport to the finish: 3 strikes -> DQ, no finish, no PB; the honest racer wins")
end

----------------------------------------------------------------------
-- Ignoring spikes
----------------------------------------------------------------------
do
	-- Lane 2 runs into a spike row in each of the 4 fields (2026-09-26: 6 rows, 300, 750, 930,
	-- 1200, 1380 and 1740; the stumble's immunity can cover the next one).
	local W = setupRace({
		{ lane = 2, policy = paced(0.6), base = 0.08, jitter = 0.04, ignoreSpikes = true, reaction = 0.12 },
		{ lane = 2, policy = paced(0.6), base = 0.08, jitter = 0.04, reaction = 0.12 },
	})
	local cheater, honest = W.players[1], W.players[2]
	-- The cheater's lead over the honest racer in the same lane, as the server sees it, never
	-- exceeds 0.55 s of their sprint speed per spike crossed so far (2026-09-25: in seconds, as the
	-- speed now follows the Speed stat; 40 studs at the old 74 studs/s sprint).
	local worst = 0
	advance(W, W.goAt - W.now)
	local cRacer, hRacer = racerOf(W, cheater), racerOf(W, honest)
	for _ = 1, (QUEUE.MaxRaceSeconds + 2) * 20 do
		advance(W, 0.05)
		if cRacer.v and hRacer.v and not cRacer.done and not hRacer.done then
			local crossed = 0
			for _, row in RaceTrack.SpikeRows() do
				if table.find(row.blocked, 2) and cRacer.v.sLast > row.s then
					crossed += 1
				end
			end
			if crossed > 0 then
				worst = math.max(worst, (cRacer.v.sLast - hRacer.v.sLast) / crossed)
			end
		end
	end
	local laneRows = 0
	for _, row in RaceTrack.SpikeRows() do
		laneRows += if table.find(row.blocked, 2) then 1 else 0
	end
	assert(laneRows == 6 and (honest.sim.spikes or 0) >= 4 and (honest.sim.spikes or 0) <= laneRows,
		"the honest racer in lane 2 hits 4-6 of its 6 blocked rows (" .. tostring(honest.sim.spikes) .. ")")
	assert((cheater.corrections or 0) >= 1, "ignoring spikes is corrected")
	local bound = 0.55 * cRacer.params.Vs
	assert(worst <= bound, string.format("lead <= %.1f studs (0.55 s of sprint) per spike (%.1f)", bound, worst))
	assert(hRacer.finished, "the honest racer finishes")
	-- Ignoring every field is 3 strikes: a DQ, like any other repeated violation.
	assert(cRacer.dq == true and not cRacer.finished, "ignoring spikes in every field ends in a DQ")
	pass(string.format("ignoring spikes: lead <= %.1f studs per spike, corrected %d times -> DQ", worst, cheater.corrections))
end

----------------------------------------------------------------------
-- False start, fall, corridor exit
----------------------------------------------------------------------
do
	local W = setupRace({
		{ lane = 3, policy = greedy, base = 0.05, reaction = 0.12 },
		{ lane = 4, policy = greedy, base = 0.05, reaction = 0.12 },
	})
	local player = W.players[1]
	-- Run to 1 s before GO, then walk through the start line.
	advance(W, W.goAt - 1 - W.now)
	local slot = RaceTrack.SlotPosition(player.attrs.RaceSlot)
	player.char.pos = RaceTrack.ToWorld(5, RaceTrack.LaneX(3), RaceTrack.RootHeight)
	advance(W, 0.1)
	assert((player.char.pos - slot).Magnitude < 0.01, "false start: back on the slot")
	assert(player.attrs.RaceMovementLocked == true, "held")
	local sawToast = false
	for _, event in player.events do
		if event.kind == "Toast" and event.key == "RaceFalseStart" then
			sawToast = true
		end
	end
	assert(sawToast, "false start toast")
	advance(W, 1.15)
	assert(player.attrs.RaceMovementLocked == true, "still held just after GO")
	advance(W, 0.3)
	assert(player.attrs.RaceMovementLocked == false, "released 0.3 s after GO")
	assert(W.players[2].attrs.RaceMovementLocked == false, "the other racer is free at GO")
	pass("false start: pulled back to the slot, held until GO + 0.3 s")
end

do
	local W = setupRace({
		{ lane = 1, policy = paced(0.6), base = 0.08, reaction = 0.12 },
		{ lane = 5, policy = paced(0.6), base = 0.08, reaction = 0.12 },
	})
	-- 2026-09-26: mid-race at 208 studs/s cruise (a race is ~8-10 s now; it was 12 s and 8 s).
	W.players[1].sim.spec.fallAt = W.goAt + 4
	W.players[2].sim.spec.exitAt = W.goAt + 3
	advance(W, QUEUE.StagingSeconds + QUEUE.CountdownSeconds + 20)
	local faller, leaver = racerOf(W, W.players[1]), racerOf(W, W.players[2])
	assert(not faller.done or faller.finished, "a fall is not a DNF")
	local stumbled = false
	for _, event in W.players[1].events do
		if event.kind == "Stumble" then
			stumbled = true
		end
	end
	assert(stumbled and (W.players[1].pivots or 0) >= 2, "the faller is put back on the track, stumbling")
	assert(leaver.done and leaver.outcome == "DNF" and leaver.reason == "Left", "corridor exit -> DNF Left")
	assert(W.players[2].attrs.RaceActive == false and W.players[2].attrs.RaceState == "", "the leaver is released (no return teleport)")
	advance(W, QUEUE.MaxRaceSeconds)
	assert(faller.finished, "the faller still finishes")
	pass("fall recovered without a DNF (stumble); corridor exit -> DNF Left, released without a teleport")
end

print(string.format("test_u4_race_validation: %d checks passed", passed))
