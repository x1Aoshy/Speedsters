-- test_u4_race_lifecycle.luau (Update 4, race_server, 2026-09-25)
-- The race cycle (PLAN §3.1 / §7.3 item 5): the real Services/Race/RaceService and
-- RaceChargeJudge on a fake clock with fake players (attributes, a position, alive or not).
-- Racers who run are driven by Shared/RaceMath without latency (validation has its own test).
--   refusals (feature off, loading, tutorial not seen with 0 rebirths, AFK, dead, double join,
--   bad source); Idle -> Gathering (solo wait 25 s, 20 s from the 2nd player, 5 s once full);
--   the Time Trial after 25 s alone; a racer who never reaches the arena is dropped at the
--   countdown (StreamTimeout); the 15 s grace after the first finish; results, requeue (and
--   two idle DNFs switch it off); Leave returns to the captured spot (Gate joiners to spawn);
--   death -> DNF "Dead" without a return trip; PlayerRemoving; Mega Race (16, x2, gathering
--   restarts at once, everyone invited); invites every 300 s and only in the lobby; every
--   arena teleport is followed by a MovementGuard rebase (_G.VortexMovementGuardRebase).
--   2026-09-25 (final fix): a rejoin within 3 s of a Leave is refused (RaceCooldown) and one
--   within 10 s keeps its funnel session; no join or staging while a save is retried (H3);
--   only the podium is prepared in the results tick, payments are staggered; the automatic
--   requeue logs its funnel steps only once the player commits; Mega invites every 120 s.
--   2026-09-25 (owner: three queues): RaceService.FormHeat (biggest heat first, the longest
--   waiter anchors after AnchorAfterSeconds, Rank = two adjacent brackets, Open fills, Mega =
--   everyone, nobody stranded); Npc joins with a category, the Beginner lock, switching queue in
--   place, heats staged by kind; a mixed heat waits for its slowest racer at cruise.
-- Run: lune run audit/test_u4_race_lifecycle.luau   (from the project root)
local roblox = require("@lune/roblox")
local Vector3, CFrame = roblox.Vector3, roblox.CFrame

local U4 = require("../src/common/ReplicatedStorage/Shared/Update4Config")
local RaceTrack = require("../src/common/ReplicatedStorage/Shared/RaceTrack")
local RaceMath = require("../src/common/ReplicatedStorage/Shared/RaceMath")
local RaceService = require("../src/common/ServerScriptService/Services/Race/RaceService")
local RaceChargeJudge = require("../src/common/ServerScriptService/Services/Race/RaceChargeJudge")

local QUEUE = U4.Race.Queue
local MEGA = U4.Race.Mega
local M = U4.Race.Matchmaking
local passed = 0
local function pass(text)
	passed += 1
	print("PASS " .. text)
end

----------------------------------------------------------------------
-- Fakes
----------------------------------------------------------------------
local LOBBY = Vector3.new(300, 37470.69, -1700)
local SPAWN = Vector3.new(280, 37470, -1781)

local function newPlayer(W, id, attrs)
	local p = {
		UserId = id,
		Name = "Player" .. id,
		present = true,
		attrs = { DataLoaded = true, FirstTimeTutorialSeen = true, Rebirths = 0, CurrentSafeZoneStage = 0 },
		char = { pos = LOBBY + Vector3.new(id * 3, 0, 0), alive = true },
		progress = 1 + (id % 3),
		events = {},
		log = {},
		races = 0,
	}
	for k, v in attrs or {} do
		p.attrs[k] = v
	end
	function p:GetAttribute(name)
		return self.attrs[name]
	end
	function p:SetAttribute(name, value)
		self.attrs[name] = value
	end
	table.insert(W.players, p)
	return p
end

local function eventsOf(p, kind)
	local list = {}
	for _, event in p.events do
		if event.kind == kind then
			table.insert(list, event)
		end
	end
	return list
end

local function lastToast(p)
	local toasts = eventsOf(p, "Toast")
	return toasts[#toasts] and toasts[#toasts].key
end

local function newWorld(options)
	local opts = options or {}
	local W = { now = 1000, unixBase = 1.8e9, attrs = {}, players = {}, nextTick = 1000, paid = {}, funnel = {}, flags = { Race = true, MegaRace = true } }
	local host = {}
	host.now = function()
		return W.now
	end
	host.unix = function()
		return math.floor(W.unixBase + (W.now - 1000))
	end
	host.isOn = function(feature)
		return W.flags[feature] == true
	end
	host.players = function()
		return W.players
	end
	host.isPlayer = function(p)
		return p.present == true
	end
	host.sample = function(p)
		if not p.present then
			return nil
		end
		return { alive = p.char.alive, position = p.char.pos, cframe = CFrame.new(p.char.pos), grounded = true }
	end
	host.pivot = function(p, cframe)
		if p.pivotFails then
			return -- (2026-09-26) the move itself fails: this racer never reaches the arena
		end
		p.char.pos = cframe.Position
		table.insert(p.log, "pivot")
		if p.runner then
			p.runner.state.s, p.runner.x = RaceTrack.ToLocal(cframe.Position)
		end
	end
	host.setVelocity = function() end
	host.streamAround = function(p, _, done)
		if p.streamFails then
			return -- the request never finishes in time
		end
		done()
	end
	host.rebase = function(p, progress)
		table.insert(p.log, "rebase")
		p.lastRebase = progress
	end
	host.getProgress = function(p)
		return p.progress
	end
	host.armGrace = function(p)
		table.insert(p.log, "grace")
	end
	host.teleportToSpawn = function(p)
		p.char.pos = SPAWN
		table.insert(p.log, "spawn")
	end
	host.ping = function()
		return 0
	end
	host.fire = function(p, payload)
		table.insert(p.events, payload)
		if payload.kind == "Staged" then
			p.staged = payload
		end
	end
	host.live = function(p)
		p.live = (p.live or 0) + 1
	end
	host.setWorld = function(name, value)
		W.attrs[name] = value
	end
	host.getWorld = function(name)
		return W.attrs[name]
	end
	host.setGateCollide = function(on)
		W.gate = on
	end
	host.rawSpeed = function(p)
		return p.rawSpeed or 1e4
	end
	host.bracket = function(p)
		return p.bracket
	end
	host.pads = function()
		return W.pads or {}
	end
	host.suitMax = function()
		return 5
	end
	host.dailyFirst = function(p)
		return p.dailyFirst == true
	end
	host.raceStats = function(p)
		return { Races = p.races }
	end
	host.prepare = function(p, outcome)
		W.prepared = (W.prepared or 0) + 1
		return { rewards = { wins = 100, rewarded = outcome.finished or outcome.progress >= 0.25 }, before = { Races = p.races } }
	end
	host.pay = function(p, outcome, _, done, index)
		W.paid[p] = W.paid[p] or {}
		W.payIndex = W.payIndex or {}
		W.payIndex[p] = index
		table.insert(W.paid[p], outcome)
		p.races += 1
		done({ ok = true, wins = 100, speed = 10, tickets = 0, pb = false, weekId = 1 })
	end
	host.submitPb = function() end
	host.funnel = {
		Step = function(p, funnel, step, session)
			table.insert(W.funnel, { p = p, funnel = funnel, step = step, session = session })
			return true
		end,
		NewSession = function(p, funnel)
			W.sessions = (W.sessions or 0) + 1
			return funnel .. "#" .. W.sessions
		end,
		Event = function(p, name)
			table.insert(W.funnel, { p = p, event = name })
			return true
		end,
	}
	W.judge = RaceChargeJudge.new({
		now = host.now,
		fire = host.fire,
		funnel = host.funnel,
		onJudged = function(p, grade, held)
			W.service:OnJudged(p, grade, held)
		end,
	})
	host.judge = W.judge
	W.host = host
	W.service = RaceService.new(host)
	return W
end

local function funnelSteps(W, p, funnel)
	local list = {}
	for _, row in W.funnel do
		if row.p == p and row.funnel == funnel then
			table.insert(list, row.step)
		end
	end
	return list
end
local function hadEvent(W, p, name)
	for _, row in W.funnel do
		if row.p == p and row.event == name then
			return true
		end
	end
	return false
end

-- Racers with `p.runs` run the race with a perfect RaceMath model from GO (20 Hz).
local function stepRunners(W, dt)
	for _, p in W.players do
		if p.runs and p.staged and p.char.alive and p.attrs.RaceState == "Racing" and p.attrs.RaceMovementLocked ~= true then
			if not p.runner or p.runner.goAt ~= p.staged.goAt then
				local s0, x0 = RaceTrack.ToLocal(p.char.pos)
				local params = RaceMath.Params(p.rawSpeed or 1e4, 5, 1)
				p.runner = { goAt = p.staged.goAt, params = params, x = x0, state = RaceMath.NewState(params, "Ok", nil, p.staged.goAt, s0) }
			end
			local r = p.runner
			RaceMath.Step(r.state, { forward = p.runs, sprint = false, grounded = true }, dt, r.params, W.now)
			if RaceTrack.SpikeAt(r.state.s, r.x, RaceTrack.RootHeight) then
				RaceMath.SpikeHit(r.state, W.now)
			end
			p.char.pos = RaceTrack.ToWorld(r.state.s, r.x, RaceTrack.RootHeight)
		end
	end
end

local function advance(W, seconds)
	local stop = W.now + seconds
	while W.now < stop - 1e-9 do
		W.now += 0.05
		stepRunners(W, 0.05)
		W.service:Tick(W.now)
	end
end

local function untilPhase(W, phase, limit)
	local stop = W.now + (limit or 200)
	while W.service.phase ~= phase and W.now < stop do
		advance(W, 0.05)
	end
	assert(W.service.phase == phase, "reached phase " .. phase .. " (at " .. tostring(W.service.phase) .. ")")
end

-- Every arena teleport (pivot) is followed by a MovementGuard rebase.
local function rebasedEveryPivot(p)
	for index, entry in p.log do
		if entry == "pivot" and p.log[index + 1] ~= "rebase" then
			return false
		end
	end
	return true
end

local function racerOf(W, p)
	local race = W.service.race or W.lastRace
	for _, racer in (race and race.racers or {}) do
		if racer.player == p then
			return racer
		end
	end
	return nil
end

----------------------------------------------------------------------
-- Refusals
----------------------------------------------------------------------
do
	local W = newWorld()
	local ok = newPlayer(W, 1)
	local afk = newPlayer(W, 2, { AfkModeActive = true })
	local newbie = newPlayer(W, 3, { FirstTimeTutorialSeen = false, Rebirths = 0 })
	local veteran = newPlayer(W, 4, { FirstTimeTutorialSeen = false, Rebirths = 1 })
	local dead = newPlayer(W, 5)
	dead.char.alive = false
	local loading = newPlayer(W, 6, { DataLoaded = false })
	local saving = newPlayer(W, 7, { DataSaveRetrying = true })

	assert(W.service:Join(ok, "Nowhere") == false, "an unknown source is refused")
	assert(W.service:Join(afk, "Hud") == false and lastToast(afk) == "RaceAfk", "AFK refused")
	assert(W.service:Join(newbie, "Hud") == false and lastToast(newbie) == "RaceLockedTutorial", "tutorial not seen and 0 rebirths refused")
	assert(W.service:Join(dead, "Hud") == false and lastToast(dead) == "RaceDead", "dead refused")
	assert(W.service:Join(loading, "Hud") == false and lastToast(loading) == "RaceLoading", "not loaded refused")
	assert(W.service:Join(saving, "Hud") == false and lastToast(saving) == "RaceLoading", "a save being retried (H3) refused")
	W.flags.Race = false
	assert(W.service:Join(ok, "Hud") == false and lastToast(ok) == "RaceOff", "feature off refused")
	W.flags.Race = true
	assert(W.service:Join(veteran, "Panel") == true, "1 rebirth without the tutorial may race")
	assert(W.service:Join(ok, "Hud") == true, "join")
	assert(W.service:Join(ok, "Invite") == false and lastToast(ok) == "RaceAlreadyQueued", "double join refused")
	assert(ok.attrs.RaceState == "Queued" and #eventsOf(ok, "Queued") == 1, "Queued state and event")
	assert(W.attrs.RaceQueueCount == 2, "queue count published")
	-- Funnels: a new Engagement_Race session with step 1, the join event, the first queue.
	local steps = funnelSteps(W, ok, "Engagement_Race")
	assert(#steps == 1 and steps[1] == 1, "Engagement_Race step 1")
	assert(hadEvent(W, ok, "Race_Join_Hud_v2") and hadEvent(W, veteran, "Race_Join_Panel_v2"), "Race_Join_<Source>_v2")
	assert(funnelSteps(W, ok, "Onboarding_Race")[1] == 2, "first queue -> Onboarding_Race step 2")
	-- 2026-09-25 (final fix): Leave then Join at once is refused for 3 s; within 10 s the
	-- rejoin keeps the funnel session it left (no new Engagement_Race step 1 or join event).
	local sessionsBefore = W.sessions
	assert(W.service:Leave(ok, "Player") == true, "leave the queue")
	assert(W.service:Join(ok, "Hud") == false and lastToast(ok) == "RaceCooldown", "a rejoin within 3 s is refused")
	assert(W.service:Join(ok, "Invite") == false, "...from every client button")
	advance(W, 3.1)
	assert(W.service:Join(ok, "Hud") == true, "a rejoin after 3 s is accepted")
	assert(W.sessions == sessionsBefore and #funnelSteps(W, ok, "Engagement_Race") == 1, "...and keeps the session it left")
	W.service:Leave(ok, "Player")
	assert(W.service:Join(ok, "Gate") == true, "the Race Gate is exempt from the rejoin cooldown")
	pass("refusals (source, AFK, tutorial, dead, loading, save retrying, feature off, double join, rejoin cooldown) and join funnels")
end

----------------------------------------------------------------------
-- Gathering timings, full lobby, Time Trial
----------------------------------------------------------------------
do
	local W = newWorld()
	local a = newPlayer(W, 1)
	W.service:Join(a, "Hud")
	assert(W.service.phase == "Gathering" and W.attrs.RacePhase == "Gathering", "one player: gathering (solo wait)")
	assert(math.abs(W.attrs.RacePhaseEndsAt - (W.now + QUEUE.SoloWaitSeconds)) < 1e-6, "alone: 25 s")
	advance(W, 3)
	local b = newPlayer(W, 2)
	W.service:Join(b, "Hud")
	assert(math.abs(W.attrs.RacePhaseEndsAt - (W.now + QUEUE.GatherSeconds)) < 1e-6, "second player: 20 s from now")
	for id = 3, QUEUE.MaxPlayers do
		W.service:Join(newPlayer(W, id), "Hud")
	end
	assert(math.abs(W.attrs.RacePhaseEndsAt - (W.now + QUEUE.GatherFullSeconds)) < 1e-6, "full: 5 s")
	advance(W, QUEUE.GatherFullSeconds + 0.1)
	assert(W.service.phase == "Staging" and #W.service.race.racers == QUEUE.MaxPlayers, "12 staged")
	-- A 13th player waits for the next race.
	local late = newPlayer(W, 13)
	W.service:Join(late, "Hud")
	assert(late.attrs.RaceState == "Queued" and W.service.phase == "Staging", "a late joiner stays queued during staging")
	pass("gathering: 25 s alone, 20 s from the 2nd player, 5 s once full; 12 staged, the 13th waits")

	local W2 = newWorld()
	local solo = newPlayer(W2, 1)
	solo.runs = 1
	W2.service:Join(solo, "Hud")
	advance(W2, QUEUE.SoloWaitSeconds - 0.2)
	assert(W2.service.phase == "Gathering", "still waiting for company")
	untilPhase(W2, "Running", 15)
	assert(W2.service.race.solo == true and W2.service.race.n == 1, "Time Trial after 25 s alone")
	untilPhase(W2, "Results", 70)
	local outcome = W2.paid[solo][1]
	assert(outcome.solo == true and outcome.finished == true and outcome.place == 1 and outcome.n == 1, "the Time Trial is paid as a solo finish")
	pass("Time Trial: alone for 25 s -> a solo race, paid as a solo finish")
end

----------------------------------------------------------------------
-- Staging, stream timeout, false start gate, finish grace, results, requeue
----------------------------------------------------------------------
do
	local W = newWorld()
	local a, b, c, d = newPlayer(W, 1), newPlayer(W, 2), newPlayer(W, 3), newPlayer(W, 4)
	a.runs, b.runs = 1, 0 -- b stands still (DNF at the end)
	-- 2026-09-26 (owner: "Couldn't reach the track"): a slow stream no longer drops a racer (they go to the grid
	-- at once: the track is Persistent); only a move that fails does.
	c.streamFails, c.pivotFails = true, true -- never reaches the arena
	d.runs = 1
	local captured = {}
	for _, p in { a, b, c, d } do
		captured[p] = p.char.pos
		W.service:Join(p, "Hud")
	end
	advance(W, QUEUE.GatherSeconds + 0.1)
	assert(W.service.phase == "Staging", "staging")
	assert(W.gate == true, "start gate closed for staging")
	for _, p in { a, b, d } do
		assert(p.attrs.RaceState == "Staged" and p.attrs.RaceActive == true and p.attrs.RaceMovementLocked == true, "staged attributes")
		assert((p.char.pos - RaceTrack.SlotPosition(p.attrs.RaceSlot)).Magnitude < 1e-3, "on its slot")
		assert(p.attrs.RaceCruiseSpeed and p.attrs.RaceSprintSpeed and p.attrs.RaceSprintSeconds and p.attrs.RaceRegenFactor, "race speeds published")
		assert(p.lastRebase == p.progress, "arena teleport keeps the lobby progress")
	end
	assert(W.attrs.RaceId == W.service.race.id and W.attrs.RaceGoAt == W.service.race.goAt and W.attrs.RaceRacerCount == 4, "race attributes")
	untilPhase(W, "Countdown", 5)
	assert(c.attrs.RaceState == "" and c.attrs.RaceActive == false, "stream timeout: released")
	local unq = eventsOf(c, "Unqueued")
	assert(unq[#unq] and unq[#unq].reason == "StreamTimeout", "Unqueued StreamTimeout")
	-- (2026-09-26: the grid move is tried at once and again at the countdown; it failed both times, so no
	-- move landed and nothing sends them "back" from an arena they never reached.)
	assert(not table.find(c.log, "pivot") and not table.find(c.log, "spawn"), "never reached the arena: no teleport back")
	untilPhase(W, "Running", 6)
	assert(W.gate == false, "start gate opened at GO")
	assert(a.attrs.RaceMovementLocked == false and a.attrs.RaceState == "Racing", "released at GO")
	assert(funnelSteps(W, a, "Engagement_Race")[2] == 2, "Engagement_Race step 2 at GO")
	W.lastRace = W.service.race
	-- First finish, then 15 s of grace for the others.
	local stop = W.now + 60
	while not racerOf(W, a).finished and W.now < stop do
		advance(W, 0.05)
	end
	local ra = racerOf(W, a)
	assert(ra.finished, "a finishes")
	local firstFinishAt = W.now
	assert(a.attrs.RaceState == "Finished" and a.attrs.RaceFinishMs == ra.finishMs and a.attrs.RacePlace >= 1, "finish attributes")
	assert(#eventsOf(a, "Finished") == 1, "Finished event")
	-- 2026-09-26: 15 s after the first finish, or the slowest racer still running's expected time
	-- (the cruise time plus a trip per spike row, x FinishWaitFactor), whichever is later.
	-- (The first finisher may be d, a tick before a: the service's own first finish counts.)
	local goAt = W.service.race.goAt
	firstFinishAt = W.service.race.firstFinishAt
	local slowWait = RaceMath.ExpectedSeconds(RaceMath.Params(1e4, 5, 1)) * QUEUE.FinishWaitFactor
	local endsAt = math.min(goAt + QUEUE.MaxRaceSeconds, math.max(firstFinishAt + QUEUE.FinishGraceSeconds, goAt + slowWait))
	assert(math.abs(W.attrs.RacePhaseEndsAt - endsAt) < 0.06, "race ends 15 s after the first finish or when the slowest should be in")
	untilPhase(W, "Results", endsAt - W.now + 1)
	assert(W.now - endsAt <= 0.1, "results at the end of the wait")
	local rb = racerOf(W, b)
	assert(rb.outcome == "DNF" and rb.reason == "Time", "the slow racer is a DNF (time)")
	assert(W.gate == true, "start gate closed again for the next race")
	local results = eventsOf(a, "Results")
	assert(#results == 1 and results[1].you.Finished == true and #results[1].podium >= 1, "Results event with the podium")
	assert(W.paid[a] and W.paid[b] and not W.paid[c], "everyone who raced is paid once (the dropped one not at all)")
	assert(a.attrs.RaceActive == true, "RaceActive stays on through the results")
	-- 2026-09-25 (final fix): the results tick prepares only the podium; payments are staggered.
	assert(W.prepared <= 3, "only the podium is prepared in the results tick (" .. tostring(W.prepared) .. ")")
	assert(W.payIndex[a] ~= W.payIndex[b] and W.payIndex[a] >= 1 and W.payIndex[b] >= 1, "each payment gets its own stagger index")
	-- Auto-requeue (on by default after a race).
	assert(a.attrs.RaceState == "Queued" and b.attrs.RaceState == "Queued", "requeued automatically")
	assert(not hadEvent(W, a, "Race_Requeued_v2"), "the automatic requeue logs nothing until the player commits")
	untilPhase(W, "Cooldown", QUEUE.ResultsSeconds + 1)
	untilPhase(W, "Gathering", QUEUE.CooldownSeconds + 1)
	pass("staging, stream-timeout drop, gate, GO, 15 s finish grace, results, auto-requeue")

	-- Second race: b idles again -> two idle DNFs in a row switch auto-requeue off.
	untilPhase(W, "Staging", 60)
	assert(hadEvent(W, a, "Race_Requeued_v2"), "Race_Requeued_v2 once the requeued racer is staged")
	untilPhase(W, "Results", 120)
	assert(b.attrs.RaceAutoRequeue == false and b.attrs.RaceState ~= "Queued", "two idle DNFs: no more auto-requeue")
	assert(a.attrs.RaceState == "Queued", "the finisher is requeued again")
	untilPhase(W, "Gathering", QUEUE.ResultsSeconds + QUEUE.CooldownSeconds + 1)
	assert(b.attrs.RaceActive == false and b.attrs.RaceState == "", "b went back to the lobby at the end of the cooldown")
	assert((b.char.pos - (captured[b] + Vector3.new(0, 3, 0))).Magnitude < 1e-3, "returned to where they queued (+3 studs)")
	assert(b.log[#b.log] == "grace" and b.lastRebase == b.progress, "return trip: rebase to the captured progress + arrival grace")
	-- Leave from the queue in the arena.
	assert(W.service:Leave(a, "Player") == true, "leave")
	assert(a.attrs.RaceActive == false and a.attrs.RaceState == "", "leave clears the race attributes")
	assert((a.char.pos - (captured[a] + Vector3.new(0, 3, 0))).Magnitude < 1e-3, "leave returns to the captured spot")
	assert(W.service.phase == "Idle" or #W.service.queue > 0, "an empty queue goes idle")
	for _, p in { a, b, d } do
		assert(rebasedEveryPivot(p), "every arena teleport is followed by a MovementGuard rebase")
	end
	pass("two idle DNFs stop auto-requeue; return trips land +3 studs over the captured spot with rebase + grace")
end

----------------------------------------------------------------------
-- Race Gate joiners, RaceAgain, AutoRequeue off
----------------------------------------------------------------------
do
	local W = newWorld()
	local g = newPlayer(W, 1)
	W.service:Join(g, "Gate")
	assert(g.attrs.RaceActive == true, "a Gate joiner waits in the arena")
	local _, x = RaceTrack.ToLocal(g.char.pos)
	local s = RaceTrack.ToLocal(g.char.pos)
	assert(s > -RaceTrack.StagingDepth and s < 0 and math.abs(x) < 36, "in the staging box")
	assert(g.log[1] == "pivot" and g.log[2] == "rebase", "the wait teleport is rebased")
	W.service:Leave(g, "Player")
	assert(g.log[#g.log] == "rebase" and g.char.pos == SPAWN, "a Gate joiner leaves to the normal spawn")

	local p1, p2 = newPlayer(W, 2), newPlayer(W, 3)
	p1.runs, p2.runs = 1, 1
	W.service:Join(p1, "Hud")
	W.service:Join(p2, "Hud")
	W.service:SetAutoRequeue(p2, false)
	assert(W.service:SetAutoRequeue(p2, "yes") == false, "AutoRequeue needs a boolean")
	untilPhase(W, "Results", 120)
	assert(p1.attrs.RaceState == "Queued" and p2.attrs.RaceState == "Finished", "auto-requeue off: not requeued")
	assert(W.service:RaceAgain(p2) == true and p2.attrs.RaceState == "Queued", "Race again requeues from the results")
	assert(p2.attrs.RaceAutoRequeue == true, "Race again turns auto-requeue back on")
	pass("Gate joiners wait in the staging box and leave to spawn; AutoRequeue off; Race again")
end

----------------------------------------------------------------------
-- 2026-09-25 review: queued then the Gate; moved out of the arena while waiting; the second
-- race's onboarding step on an auto-requeue
----------------------------------------------------------------------
do
	local W = newWorld()
	local q = newPlayer(W, 1)
	assert(W.service:Join(q, "Hud") == true and q.attrs.RaceActive ~= true, "queued from the HUD, still in the lobby")
	assert(W.service:Join(q, "Gate") == true, "the Race Gate takes a queued player to the arena")
	local s = RaceTrack.ToLocal(q.char.pos)
	assert(q.attrs.RaceActive == true and s > -RaceTrack.StagingDepth and s < 0, "waiting in the staging box")
	assert(#W.service.queue == 1 and lastToast(q) == nil, "same queue place, no 'already queued' toast")
	assert(q.log[1] == "pivot" and q.log[2] == "rebase", "the wait teleport is rebased")
	-- A stage trip (something else) moves the waiting player back to the map.
	q.char.pos = LOBBY + Vector3.new(0, 0, 40)
	advance(W, 0.3) -- one 2 Hz capture sample
	assert(q.attrs.RaceActive == true, "one sample outside is not enough (a pivot may not have landed)")
	advance(W, 0.6)
	assert(q.attrs.RaceActive == false and q.attrs.RaceState == "Queued" and #W.service.queue == 1, "still queued, now from the lobby")
	assert(W.service:IsRacing(q) == false, "no longer counted in the arena")
	W.service:Leave(q, "Player")
	assert(q.char.pos == LOBBY + Vector3.new(0, 0, 40), "leaving from the lobby queue teleports nobody")

	-- A finished racer who waits in the arena (auto-requeue off) and is moved out is released.
	local W2 = newWorld()
	local a, b = newPlayer(W2, 1), newPlayer(W2, 2)
	a.runs, b.runs = 1, 1
	W2.service:Join(a, "Hud")
	W2.service:Join(b, "Hud")
	W2.service:SetAutoRequeue(b, false)
	untilPhase(W2, "Results", 120)
	assert(b.attrs.RaceState == "Finished" and b.attrs.RaceActive == true, "b waits through the results")
	-- a's first race: the auto-requeue is its second queue, reported once the player commits
	-- (RACE AGAIN on a racer the server already requeued sends AutoRequeue true).
	local steps = funnelSteps(W2, a, "Onboarding_Race")
	assert(steps[#steps] ~= 5, "no Onboarding_Race step 5 before the player's choice")
	W2.service:SetAutoRequeue(a, true)
	steps = funnelSteps(W2, a, "Onboarding_Race")
	assert(steps[#steps] == 5, "an auto-requeue after the first race reports Onboarding_Race step 5 on RACE AGAIN")
	assert(W2.service:RaceAgain(a) == true, "RaceAgain on an already requeued racer is accepted")
	steps = funnelSteps(W2, a, "Onboarding_Race")
	assert(steps[#steps] == 5 and steps[#steps - 1] ~= 5, "...and reports nothing twice")
	b.char.pos = LOBBY
	advance(W2, 1.2)
	assert(b.attrs.RaceActive == false and b.attrs.RaceState == "" and W2.service.entries[b] == nil, "moved out while done: released")
	local unq = eventsOf(b, "Unqueued")
	assert(unq[#unq] and unq[#unq].reason == "Left", "Unqueued Left")
	local pivots = #b.log
	untilPhase(W2, "Gathering", QUEUE.ResultsSeconds + QUEUE.CooldownSeconds + 1)
	assert(#b.log == pivots, "no return trip for a player who already left the arena")
	pass("queued then Gate -> staging box; moved out while waiting -> lobby queue / released; step 5 on auto-requeue")
end

----------------------------------------------------------------------
-- Death, PlayerRemoving
----------------------------------------------------------------------
do
	local W = newWorld()
	local a, b, c = newPlayer(W, 1), newPlayer(W, 2), newPlayer(W, 3)
	a.runs, b.runs, c.runs = 1, 1, 1
	for _, p in { a, b, c } do
		W.service:Join(p, "Hud")
	end
	untilPhase(W, "Running", 40)
	W.lastRace = W.service.race
	advance(W, 5)
	local pivotsBefore = #b.log
	b.char.alive = false
	advance(W, 0.1)
	local rb = racerOf(W, b)
	assert(rb.done and rb.outcome == "DNF" and rb.reason == "Dead", "death -> DNF Dead")
	assert(b.attrs.RaceActive == false and b.attrs.RaceState == "", "the dead racer is released")
	assert(#b.log == pivotsBefore, "no return teleport after a death (normal respawn)")
	W.service:Remove(c)
	c.present = false
	advance(W, 0.1)
	local rc = racerOf(W, c)
	assert(rc.done and rc.gone, "PlayerRemoving drops the racer")
	untilPhase(W, "Results", 70)
	assert(W.paid[a] and W.paid[b] and not W.paid[c], "the leaver is not paid; the dead racer is paid as a DNF")
	assert(W.paid[b][1].finished == false, "DNF outcome")
	pass("death -> DNF Dead (no teleport, released); PlayerRemoving drops the racer unpaid")
end

----------------------------------------------------------------------
-- Mega Race and invites
----------------------------------------------------------------------
do
	local W = newWorld()
	local lobby1 = newPlayer(W, 1)
	local lobby2 = newPlayer(W, 2)
	local onStage = newPlayer(W, 3, { CurrentSafeZoneStage = 4 })
	local afk = newPlayer(W, 4, { AfkModeActive = true })
	local newbie = newPlayer(W, 5, { FirstTimeTutorialSeen = false })
	local queued = newPlayer(W, 6)
	W.service:Join(queued, "Hud")
	assert(#eventsOf(lobby1, "Invite") == 1 and #eventsOf(lobby2, "Invite") == 1, "gathering invites the lobby")
	assert(#eventsOf(onStage, "Invite") == 0 and #eventsOf(afk, "Invite") == 0 and #eventsOf(newbie, "Invite") == 0
		and #eventsOf(queued, "Invite") == 0, "no invites on the stages, in AFK, before the tutorial or when queued")
	W.service:Leave(queued, "Player")
	advance(W, 3.1) -- past the rejoin cooldown
	W.service:Join(queued, "Hud")
	assert(#eventsOf(lobby1, "Invite") == 1, "at most one invite per 300 s")
	W.service:Leave(queued, "Player")
	advance(W, QUEUE.InviteCooldownSeconds)
	W.service:Join(queued, "Hud")
	assert(#eventsOf(lobby1, "Invite") == 2, "invited again after 300 s")
	W.service:Leave(queued, "Player")
	advance(W, 1)
	assert(W.service.phase == "Idle", "idle when the queue empties")
	pass("invites: lobby only (stage <= 1), not AFK / tutorial / queued, at most one per 300 s")

	-- Mega Race: gathering at once (30 s, 16 slots), everyone eligible invited, x2 rewards.
	W.flags.MegaRace = false
	assert(W.service:StartMegaEvent(600, "Admin") == false, "Mega Race off -> refused")
	W.flags.MegaRace = true
	assert(W.service:StartMegaEvent(600, "Admin") == true, "Mega Race started")
	assert(W.attrs.RaceEventUntil == W.host.unix() + 600 and W.attrs.RaceEventMultiplier == MEGA.Multiplier and W.attrs.RaceEventBy == "Admin", "event attributes")
	assert(W.service.phase == "Gathering" and math.abs(W.attrs.RacePhaseEndsAt - (W.now + MEGA.GatherSeconds)) < 1e-6, "gathering restarts at once for 30 s")
	assert(W.attrs.RaceMaxPlayers == MEGA.MaxPlayers, "16 slots")
	assert(#eventsOf(lobby1, "Invite") == 3 and eventsOf(lobby1, "Invite")[3].mega == true, "everyone eligible is invited again (no cooldown)")
	local racers = {}
	for id = 10, 25 do
		local p = newPlayer(W, id)
		p.runs = 1
		W.service:Join(p, "Hud")
		table.insert(racers, p)
	end
	assert(hadEvent(W, racers[1], "Race_MegaJoined_v2"), "Race_MegaJoined_v2")
	untilPhase(W, "Staging", 10)
	assert(#W.service.race.racers == MEGA.MaxPlayers, "16 racers")
	assert(racers[1].attrs.RaceRewardMultiplier == MEGA.Multiplier, "x2 reward multiplier")
	W.service:StopMegaEvent()
	assert(W.attrs.RaceEventUntil == nil and W.attrs.RaceEventMultiplier == nil, "stop clears the event")
	W.lastRace = W.service.race
	untilPhase(W, "Results", 90)
	assert(W.paid[racers[1]][1].eventMultiplier == MEGA.Multiplier, "a running Mega Race keeps its multiplier after the stop")
	assert(W.prepared <= 3, "16 racers: only the podium is prepared in the results tick (" .. tostring(W.prepared) .. ")")
	pass("Mega Race: 30 s gathering at once, 16 racers, x2 (kept by a running race), everyone invited")

	-- 2026-09-25 (final fix): during a Mega Race the invites keep a 120 s cooldown (the start
	-- invites everyone once), so a Join/Leave toggle cannot spam the server.
	local M = newWorld()
	local watcher = newPlayer(M, 1)
	local toggler = newPlayer(M, 2)
	assert(M.service:StartMegaEvent(3600, "Admin") == true, "Mega Race started")
	assert(#eventsOf(watcher, "Invite") == 1, "the Mega start invites everyone")
	M.service.megaGather = false
	M.service:_setPhase("Idle", 0)
	M.service:Join(toggler, "Hud")
	assert(#eventsOf(watcher, "Invite") == 1, "a second gathering within 120 s invites nobody again")
	M.service:Leave(toggler, "Player")
	advance(M, 121)
	M.service:Join(toggler, "Hud")
	assert(#eventsOf(watcher, "Invite") == 2, "...and invites again after 120 s")
	pass("Mega Race invites: everyone at the start, then at most one per 120 s")
end

----------------------------------------------------------------------
-- Feature switched off live
----------------------------------------------------------------------
do
	local W = newWorld()
	local a = newPlayer(W, 1)
	W.service:Join(a, "Hud")
	W.flags.Race = false
	advance(W, 0.1)
	assert(a.attrs.RaceState == "" and W.service.phase == "Idle", "kill switch: the queue is dropped")
	local unq = eventsOf(a, "Unqueued")
	assert(unq[#unq].reason == "RaceOff", "Unqueued RaceOff")
	pass("kill switch (U4Off_Race): queued players are released at once")
end

----------------------------------------------------------------------
-- Matchmaking: three queues, brackets, heats (2026-09-25, owner)
----------------------------------------------------------------------
do
	local M = U4.Race.Matchmaking
	local function item(category, bracket, queuedAt)
		return { category = category, bracket = bracket, queuedAt = queuedAt or 0 }
	end
	local function same(a, b)
		if #a ~= #b then
			return false
		end
		for index, value in a do
			if b[index] ~= value then
				return false
			end
		end
		return true
	end
	local FormHeat = RaceService.FormHeat
	assert(FormHeat({}, 12, 0) == nil, "an empty queue makes no heat")
	-- The biggest heat races first while nobody has waited long.
	local list = { item("Beginner", "Beginner"), item("Beginner", "Beginner"), item("Beginner", "Beginner"), item("Rank", "Pro") }
	local heat = FormHeat(list, 12, 10)
	assert(heat.kind == "Beginner" and heat.category == "Beginner" and same(heat.members, { 1, 2, 3 }), "3 Beginners race, the Pro waits")
	-- Once the head of the queue has waited AnchorAfterSeconds, the heat must include them.
	list = { item("Rank", "Pro", 0), item("Beginner", "Beginner", 5), item("Beginner", "Beginner", 5), item("Beginner", "Beginner", 5) }
	heat = FormHeat(list, 12, M.AnchorAfterSeconds - 1)
	assert(heat.kind == "Beginner" and same(heat.members, { 2, 3, 4 }), "not anchored yet: the bigger heat")
	heat = FormHeat(list, 12, M.AnchorAfterSeconds)
	assert(heat.kind == "RankHigh" and same(heat.members, { 1 }), "anchored: the longest-waiting player's heat (a Time Trial if alone)")
	-- Rank heats mix two adjacent brackets at most; ties go to the longest-waiting member.
	list = { item("Rank", "Beginner"), item("Rank", "Pro"), item("Rank", "Mid") }
	heat = FormHeat(list, 12, 0)
	assert(heat.kind == "RankLow" and same(heat.members, { 1, 3 }), "Beginner + Mid (never Beginner with Pro)")
	-- Open players fill any heat whose bracket rule they meet; an Open heat mixes everyone.
	list = { item("Rank", "Mid"), item("Open", "Beginner"), item("Open", "Pro"), item("Beginner", "Beginner") }
	heat = FormHeat(list, 12, 0)
	assert(heat.kind == "RankLow" and same(heat.members, { 1, 2 }), "an Open Beginner fills a Rank heat of Beginner + Mid")
	list = { item("Open", "Beginner"), item("Open", "Pro"), item("Open", "Mid") }
	heat = FormHeat(list, 12, 0)
	assert(heat.kind == "Open" and #heat.members == 3, "an Open heat takes every bracket")
	assert(not RaceService.Fits("Beginner", item("Open", "Mid")) and not RaceService.Fits("Beginner", item("Rank", "Beginner"))
		and RaceService.Fits("Beginner", item("Open", "Beginner")), "a Beginner heat: Beginner bracket, queued Beginner or Open")
	assert(not RaceService.Fits("Open", item("Rank", "Mid")) and not RaceService.Fits("Open", item("Beginner", "Beginner")), "Rank / Beginner players never land in an Open heat")
	-- A Beginner-queued player who left the Beginner bracket meanwhile counts as Rank.
	heat = FormHeat({ item("Beginner", "Mid"), item("Rank", "Mid") }, 12, 0)
	assert(heat.kind == "RankLow" and #heat.members == 2, "an outgrown Beginner queues as Rank")
	-- The cap and the Mega Race (everyone, in order).
	list = {}
	for index = 1, 20 do
		list[index] = item(if index % 3 == 0 then "Open" elseif index % 3 == 1 then "Rank" else "Beginner", if index % 2 == 0 then "Beginner" else "Pro")
	end
	heat = FormHeat(list, 12, 0)
	assert(#heat.members <= 12, "at most MaxPlayers")
	heat = FormHeat(list, 16, 0, true)
	assert(heat.kind == "Mega" and #heat.members == 16 and heat.members[1] == 1 and heat.members[16] == 16, "a Mega Race takes the first 16, any queue")
	-- Nobody is stranded: 40 random players, one heat per ~70 s cycle, new joiners every cycle.
	local rng = 7
	local function random()
		rng = (rng * 1103515245 + 12345) % 2147483648
		return rng / 2147483648
	end
	local categories, brackets = M.Categories, M.Brackets
	local queue, now, nextId, waits = {}, 0, 1, {}
	local function joinRandom()
		local bracket = brackets[1 + math.floor(random() * 3)]
		local category = categories[1 + math.floor(random() * 3)]
		if category == "Beginner" and bracket ~= "Beginner" then
			category = "Rank" -- the service refuses Beginner for veterans (see below)
		end
		table.insert(queue, { id = nextId, category = category, bracket = bracket, queuedAt = now })
		nextId += 1
	end
	for _ = 1, 40 do
		joinRandom()
	end
	local worstWait = 0
	for _ = 1, 60 do
		if #queue == 0 then
			break
		end
		local head = queue[1]
		local formed = FormHeat(queue, 12, now)
		assert(formed and #formed.members >= 1, "a queue always makes a heat")
		if now - head.queuedAt >= M.AnchorAfterSeconds then
			assert(formed.members[1] == 1, "an anchored head is always in the heat")
		end
		local taken = {}
		for _, index in formed.members do
			taken[index] = true
			worstWait = math.max(worstWait, now - queue[index].queuedAt)
			local member = queue[index]
			assert(RaceService.Fits(formed.kind, member), "every member fits the heat")
		end
		local rest = {}
		for index, entry in queue do
			if not taken[index] then
				table.insert(rest, entry)
			end
		end
		queue = rest
		now += 70
		if now < 1200 then
			joinRandom()
			joinRandom()
		end
	end
	assert(#queue == 0, "every queued player raced")
	assert(worstWait <= 5 * 70, string.format("the longest wait stays a few cycles (%.0f s)", worstWait))
	pass(string.format("heats: biggest first, the longest waiter anchors after %d s, Rank = 2 adjacent brackets, Open fills, Mega = everyone; nobody stranded (worst wait %d s)", M.AnchorAfterSeconds, worstWait))
end

do
	-- The service: Npc joins with a category, the Beginner lock, queue switches, heats, the wait.
	local W = newWorld()
	local function bracketed(id, bracket, extra)
		local p = newPlayer(W, id, extra)
		p.bracket = bracket
		return p
	end
	local rookie1, rookie2, rookie3 = bracketed(1, "Beginner"), bracketed(2, "Beginner"), bracketed(3, "Beginner")
	local pro = bracketed(4, "Pro", { Rebirths = 20 })
	local mid = bracketed(5, "Mid")
	assert(W.service:Join(pro, "Npc", "Beginner") == false and lastToast(pro) == "RaceBracketLocked", "a veteran is refused the Beginner queue")
	local ok, why = W.service:Join(rookie1, "Npc", "Nope")
	assert(ok == false and why == "BadCategory" and rookie1.attrs.RaceState ~= "Queued", "an unknown category is refused")
	ok, why = W.service:Join(rookie1, "Npc")
	assert(ok == false and why == "BadCategory", "the NPC must name a queue")
	for _, p in { rookie1, rookie2, rookie3 } do
		assert(W.service:Join(p, "Npc", "Beginner") == true and p.attrs.RaceCategory == "Beginner", "Beginner queue")
	end
	local queued = eventsOf(rookie1, "Queued")
	assert(queued[#queued].category == "Beginner" and queued[#queued].source == "Npc", "Queued event carries the category")
	assert(W.service:Join(pro, "Hud") == true and pro.attrs.RaceCategory == M.DefaultCategory, "the HUD joins the default queue (" .. M.DefaultCategory .. ")")
	-- A queued player picks another queue at the NPC: same place in line, new queue.
	assert(W.service:Join(mid, "Npc", "Rank") == true and mid.attrs.RaceCategory == "Rank", "Rank queue")
	local position = table.find(W.service.queue, mid)
	assert(W.service:Join(mid, "Npc", "Open") == true and mid.attrs.RaceCategory == "Open" and table.find(W.service.queue, mid) == position, "switched to Open in place")
	assert(#W.service.queue == 5, "no double entry")
	-- The next heat: the 3 Beginners (the biggest); the Pro and the Open Mid wait.
	untilPhase(W, "Staging", QUEUE.GatherSeconds + 1)
	for _, p in { rookie1, rookie2, rookie3 } do
		assert(p.attrs.RaceState == "Staged" and p.attrs.RaceHeat == "Beginner", "Beginners staged in a Beginner heat")
	end
	assert(pro.attrs.RaceState == "Queued" and mid.attrs.RaceState == "Queued", "the others keep their place")
	assert(#W.service.queue == 2 and W.service.queue[1] == pro, "...in order")
	-- After that race the Pro (waited > AnchorAfterSeconds) anchors the next heat; the Open Mid
	-- fits a Rank heat of Mid + Pro, so both race.
	W.lastRace = W.service.race
	untilPhase(W, "Results", 200)
	untilPhase(W, "Staging", 200)
	assert(pro.attrs.RaceState == "Staged" and mid.attrs.RaceState == "Staged" and pro.attrs.RaceHeat == "RankHigh", "the waiting Pro races next, with the Open Mid")
	pass("service: Npc joins name a queue, veterans refused Beginner, queue switch in place, heats staged by kind, the waiting players race next")
end

do
	-- A lone heat (a Pro nobody else fits) while others wait: 10 s for company, not 25 s.
	local W = newWorld()
	local pro = newPlayer(W, 1, { Rebirths = 20 })
	pro.bracket = "Pro"
	local r1, r2 = newPlayer(W, 2), newPlayer(W, 3)
	r1.bracket, r2.bracket = "Beginner", "Beginner"
	W.service:Join(pro, "Hud")
	advance(W, 1)
	W.service:Join(r1, "Npc", "Beginner")
	W.service:Join(r2, "Npc", "Beginner")
	assert(math.abs(W.attrs.RacePhaseEndsAt - (W.now + QUEUE.GatherSeconds)) < 1e-6, "the Beginner heat of 2 gathers for 20 s")
	untilPhase(W, "Staging", QUEUE.GatherSeconds + 1)
	assert(pro.attrs.RaceState == "Queued" and r1.attrs.RaceState == "Staged", "the bigger heat first")
	untilPhase(W, "Gathering", 200)
	assert(W.service.gatherMode == "solo" and math.abs(W.attrs.RacePhaseEndsAt - (W.now + 10)) < 0.06, "the anchored Pro alone, others behind: a 10 s wait")
	untilPhase(W, "Staging", 11)
	assert(pro.attrs.RaceState == "Staged" and pro.attrs.RaceHeat == "RankHigh" and r1.attrs.RaceState == "Queued", "the Pro's Time Trial, the Beginners next")
	pass("a lone anchored heat waits 10 s for company while other heats queue behind it")
end

do
	-- 2026-09-25 (speed pads): the pads are read at staging, sent in Staged and judged with.
	local W = newWorld()
	W.pads = { { s0 = 442, s1 = 458, x0 = -9, x1 = 9, top = 0.2, boost = 1.25, seconds = 1.5 } }
	local a, b = newPlayer(W, 1), newPlayer(W, 2)
	a.runs, b.runs = 1, 1
	W.service:Join(a, "Hud")
	W.service:Join(b, "Hud")
	untilPhase(W, "Staging", QUEUE.GatherSeconds + 1)
	local staged = a.staged
	assert(type(staged.pads) == "table" and #staged.pads == 1 and staged.pads[1][1] == 442 and staged.pads[1][6] == 1.25, "Staged carries the pads")
	assert(#RaceTrack.PadsFromPayload(staged.pads) == 1, "...in the client's format")
	W.pads = {} -- changed after staging: this race keeps its pads
	untilPhase(W, "Running", 10)
	local racer = racerOf(W, a) or W.service.race.racers[1]
	assert(#racer.v.pads == 1 and racer.v.allowance == 0, "the validator judges with this race's pads, no slope allowance on the flat arena")
	pass("speed pads: read at staging, sent in Staged, judged with; flat arena = no slope allowance")
end

do
	-- A mixed heat (Open): the slowest racer is waited for, not DNF'd 15 s after the fastest.
	local W = newWorld()
	local fast, slow = newPlayer(W, 1), newPlayer(W, 2)
	fast.rawSpeed, slow.rawSpeed = 1e18, 1
	fast.runs, slow.runs = 1, 1
	assert(W.service:Join(fast, "Npc", "Open") and W.service:Join(slow, "Npc", "Open"), "both Open")
	untilPhase(W, "Running", QUEUE.GatherSeconds + 10)
	W.lastRace = W.service.race
	local goAt = W.service.race.goAt
	local stop = W.now + 60
	while not racerOf(W, fast).finished and W.now < stop do
		advance(W, 0.05)
	end
	local firstFinishAt = W.now
	local slowWait = RaceMath.ExpectedSeconds(RaceMath.Params(1, 5, 1)) * QUEUE.FinishWaitFactor
	assert(firstFinishAt - goAt < 20, "the capped racer finishes in under 20 s")
	assert(math.abs(W.attrs.RacePhaseEndsAt - math.min(goAt + QUEUE.MaxRaceSeconds, math.max(firstFinishAt + QUEUE.FinishGraceSeconds, goAt + slowWait))) < 0.06,
		"the heat waits for its slowest racer at cruise")
	untilPhase(W, "Results", QUEUE.MaxRaceSeconds)
	local rs = racerOf(W, slow)
	assert(rs.finished and rs.place == 2, "the Speed-1 racer finishes too (" .. tostring(rs.outcome) .. ")")
	-- 2026-09-26: 300 vs 105 cruise; a trip costs both ~1.1 s, and neither dodges here, so the
	-- gap is x2.4 rather than the cruise's x2.85.
	assert(racerOf(W, fast).finishMs < rs.finishMs / 2, "...far behind the capped one")
	pass(string.format("mixed heat: the fastest finishes in %.1f s, the heat waits %.1f s for Speed 1, who finishes 2nd in %.1f s",
		racerOf(W, fast).finishMs / 1000, slowWait, rs.finishMs / 1000))
end

print(string.format("test_u4_race_lifecycle: %d checks passed", passed))
