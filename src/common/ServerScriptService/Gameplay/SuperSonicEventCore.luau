-- ServerScriptService/Gameplay/SuperSonicEventCore.luau — the "Super Sonic vs Dr. Eggman" event's server
-- state machine (2026-09-26, owner). Gameplay/SuperSonicEventService.server wires it to Roblox; the Lune test
-- (audit/test_u4_supersonic_event) drives it with fake players and a fake clock. Everything is scheduled on
-- the server clock (deps.now = workspace:GetServerTimeNow()) and advanced by Step (every Heartbeat): no
-- task.delay, so the whole event is deterministic for a given seed and the same timeline in the test.
--
-- 2026-09-26 (owner): v2, phase by phase (numbers and the protocol in Shared/SuperSonicEvent):
--   Cinematic Eggman lifts off from his lobby spot (SSE_LiftOff) to the fight (BossCFrame with the plan);
--             a chat announcement. Every participant's Flight is off from here to the end (EventFlightBlocked).
--   Bombard   3 salvos (Aimed, Parallel, Aimed) at the lobby players on the ground, led where they are going.
--             Each bomb leaves the cannon ("Bomb", with its pattern and red-zone radius) and at impact
--             ("BombHit") throws every lobby player within 22 studs in a LIVE ragdoll for 2 s with
--             (pos - bombPos).Unit * 55 + (0, 42, 0). It never kills; a player thrown off the lobby is put back.
--   Emeralds  at the absorption every eligible lobby player turns Super (SSE_Super, the game's Super Sonic skin
--             for the event, WalkSpeed floor 120, JumpPower 90); the client draws the orbit and the burst.
--   Battle    Attack windows (salvos from BattleSalvos: Aimed / Parallel / Rain, more and bigger as the fight
--             goes on; Super players are thrown too) alternate with Reload windows (SSE_BossState mirror).
--             Charged homing attacks ("Charge" press, "Homing" release: the charge measured here) are
--             validated (Super, alive, not racing / stunned, 180 studs, cooldown, one in flight) and count only
--             when they ARRIVE in a Reload window (+-0.15 s; else "Shielded"); at arrival: HP -damage (1..3),
--             "Hit" to all, +600 Wins +30,000 Speed to the hitter (the first 45 hits), SSE_Hits.
--             Runs out after Durations.Battle: the Escape phase.
--   Defeat    HP 0: "Defeat", a chat line, the gold rings rain (RingCount by the participants; landed on the
--             lobby floor by raycasts); after Durations.Defeat the end (the rings stay out LifeSeconds more).
--   Escape    the Battle ran out: "Escape", a chat line; after Durations.Escape the end.
-- Eligible = alive, in the event's area around the spawn (SSE.InArena), not in a race (RaceNoFlight: staged,
-- racing, in the arena) and not in AFK Mode (anchored). Leaving the area, dying, respawning or joining a
-- race ends a player's Super form (their own skin back); a respawn at the spawn during the Battle turns them
-- Super again (SSE.Super.LateTransform) and a new participant raises the boss's HP (HP.GrowWithLateJoiners).
--
-- 2026-09-26 (owner): v3 (Shared/SuperSonicEvent's header has the protocol):
--   Arena     the fight moves to the race arena: the Cinematic in the lobby (SSE_LobbyOrigin = deps.origin()),
--             the Teleport beat moves the lobby's players to the arena (_moveIn, at Beats.Teleport.MoveAt; the
--             fight's centre SSE_Origin = deps.arenaOrigin()), the Return beat moves the arena's players home
--             (_moveOut; Stop does it too when the event is cut short). The event's area is SSE.InEventArea
--             (the arena; the lobby too until the move). The arena's gates stop colliding meanwhile
--             (deps.arenaGates). No deps.arenaOrigin (or nil from it): the whole fight in the lobby, as in v2.
--   Races     Start closes them (deps.closeRaces -> _G.SpeedsterRace.Close: every heat called off without
--             penalties, the arena's players back at the lobby spawn, the queue and the gate closed); Stop, for
--             any reason, opens them again (deps.openRaces).
--   Invites   at Start every player outside the event gets { "Invite", eventId, why } ("race" when they were
--             racing); later a player is owed one when they join the server, respawn (a death in the arena
--             respawns in the lobby) or leave the arena, sent once seen outside the event (_scan; at most one every
--             Invite.MinGapSeconds), until the Defeat / Escape. { "TeleportToEvent" } -> RequestTeleport
--             (SSE.CheckTeleport) -> a clear spot on the floor (_teleportSpot: round the lobby spawn before the
--             Teleport beat, the arena after it) -> deps.teleport; the arrival (TeleportArrived) protects them
--             from bombs for Teleport.SafeSeconds and they take part from the next scan.
--   Freezes   inside SSE.FreezeWindows (the Cinematic, the beats, the Emeralds shot, the crash, the outro) bombs
--             throw nobody, a participant who drops off the floor is put back at the centre, and a death costs
--             no Super form (restoreSuper).
--   Ending    HP 0 always wins: the Escape waits for the attacks flying at the timeout (_lastArrival, at most
--             Homing.MaxFlightSeconds), attacks flying at the defeat still land and pay. The Defeat crashes the
--             ship on the floor (_crashPoint: SSE_CrashPoint; the rings burst out of it, CrashTimes); the Defeat
--             (with its rings) or the Escape, then the Return beat, then the end (SSE_EndStart / SSE_Outcome kept).
--   Homing    the uncharged jump attack (no Charge, or charge01 0) is damage 1; a stale press
--             (Homing.ChargeStaleSeconds) no longer charges; an attack that would arrive while the shield is up
--             flies (HomingGo shielded) and bounces off at its arrival (_shieldBounce: no damage, ShieldKnock).
--
-- deps (functions unless noted):
--   SSE (module)            Shared/SuperSonicEvent
--   now()                   server time
--   players()               the players in the server
--   rootPosition(player)    the living character's HumanoidRootPart position, or nil
--   velocity(player)        (optional) its AssemblyLinearVelocity (bombs lead moving players; ring-take slack)
--   alive(player)           the character is alive (not dead or ragdolled into death)
--   grounded(player)        the character stands on something (Bombard targets)
--   racing(player, pos)     staged / racing / in the race arena (Shared/RaceNoFlight.Check)
--   afk(player)             in AFK Mode (anchored on the AFK spot)
--   ground(pos)             the floor point under pos (a raycast), or nil
--   ringGround(pos)         (optional) the floor under pos for a ring (a longer raycast down from pos):
--                           position, normalY; or nil (falls back to ground)
--   liftOff()               (optional) the Egg Mobile's hull centre at the lobby spot (SSE_LiftOff), or nil
--   setWorld(name, value) / setPlayer(player, name, value)   attributes
--   setNoFlight(player, on) (optional) the event's no-flight flag (RaceNoFlight.EventAttribute) + the refresh
--   fireAll(message) / fireOne(player, message)              the SuperSonicEvent remote (one array argument)
--   ragdoll(player, seconds, velocity)   the game's live ragdoll (R6DeathRagdoll's RagdollEvent) + the throw
--   rescue(player)          put a player who fell off the lobby back at the spawn
--   applySuper(player) -> saved; restoreSuper(player, saved)   the movement override + the Super Sonic skin, and
--                           their undo (the player's own skin back)
--   grant(player, wins, speed, operationId) -> kind   one DataService.Commit ("Committed", "AlreadyCommitted",
--                           "Pending", "Rejected", "NoSession")
--   winsMultiplier(player)  (optional) the player's Wins multiplier (SSE.Rewards.ApplyWinsMultiplier)
--   chat(text)              a system chat line
--   origin()                this world's spawn point (SSE_Origin)
--   isOn()                  the flag + the kill switch (SSE.IsOn)
--   newSeed()               a fresh seed
--   spawn(fn) / wait(s)     task.spawn / task.wait (the commits yield)
--   userId(player)          (optional) player.UserId
--   jobId (string)          game.JobId (operation ids)
--   log(text)               (optional) warn
--   2026-09-26 (owner): v3 (all optional)
--   closeRaces(reason) -> pulled   the race service's Close (the players it pulled out of a queue / race)
--   openRaces(reason)       its Reopen
--   teleport(player, position, stillValid, arrived)   the trip to the event: stream `position` in, then (if
--                           stillValid()) move the root there and call arrived()
--   spotGround(pos)         the floor under a trip's candidate spot (position, normalY), like ringGround
--   push(player, velocity)  set the root's velocity (the shield's bounce; the client applies it too)
--   racing(player, nil)     with no position: in a race by the race's attributes only (not the arena volume;
--                           v3: every racing test passes nil, the fight itself is in the arena)
--   arenaOrigin()           the fight's centre on the race arena's floor, or nil (no arena: the lobby)
--   arenaGates(open)        open (true) the arena's StartGate / StopBar collisions for the event, restore (false)
--   teleport(player, position, stillValid, arrived, home)   (home = true: a trip to the lobby: the world's own
--                           spawn trip first)
--   rescue(player, position?)  (v3: where to put them back: the fight's centre, or the lobby before the move)
local Vector3 = Vector3
if Vector3 == nil then
	-- Lune (the audit test): the constructors come from @lune/roblox; in Roblox the global exists.
	local lateRequire: any = require
	local ok, roblox = pcall(lateRequire, "@lune/roblox")
	if ok and type(roblox) == "table" then
		Vector3 = roblox.Vector3
	end
end

local Core = {}
Core.__index = Core

local INF = math.huge
local TAU = math.pi * 2
local SCAN_SECONDS = 0.25 -- eligibility, the Super forms and the no-flight flags are re-checked 4 times a second
local COMMIT_RETRIES = 5

-- A small seeded generator (xorshift32): the same numbers in Roblox and in Lune for one seed.
local function newRng(seed: number)
	local state = math.floor(math.abs(tonumber(seed) or 1)) % 4294967296
	if state == 0 then
		state = 2463534242
	end
	return function(): number
		state = bit32.bxor(state, bit32.lshift(state, 13))
		state = bit32.bxor(state, bit32.rshift(state, 17))
		state = bit32.bxor(state, bit32.lshift(state, 5))
		return state / 4294967296
	end
end
Core.NewRng = newRng

local function dist(a: Vector3, b: Vector3): number
	local dx, dy, dz = a.X - b.X, a.Y - b.Y, a.Z - b.Z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function newStats()
	return {
		bombs = 0, knocks = 0, hits = 0, damage = 0, refused = {}, rings = 0, ringsTaken = 0, ringRefused = {},
		-- 2026-09-26 (owner): v3
		invites = 0, pulled = 0, teleports = 0, arrivals = 0, teleportRefused = {}, shieldBounces = 0,
		frozenBlasts = 0, frozenFalls = 0, frozenDeaths = 0, movedIn = 0, movedOut = 0, rescues = 0,
	}
end

function Core.new(deps: any)
	local self = setmetatable({}, Core)
	self.deps = deps
	self.SSE = deps.SSE
	self.running = false
	self.phase = ""
	self.phaseStart = 0
	self.counter = 0
	self.eventId = 0
	self.participants = {}
	self.buckets = {}
	self.bombs = {}
	self.launches = {}
	self.rings = nil
	self.hitsByUser = {}
	self.ringsByUser = {}
	self.stats = newStats()
	-- 2026-09-26 (owner): v3
	self.invited = {} -- player -> true: invited at least once this event
	self.recentSpots = {} -- { { pos, at } }: trip spots handed out lately
	self.racesClosed = false
	self.gatesOpen = false
	self.pulled = {}
	self.split = false -- the fight on the race arena (else in the lobby)
	self.moved = false -- the Teleport beat has moved everyone
	self.movedOut = false -- the Return beat (or Stop) has sent everyone home
	return self
end

function Core:_log(text: string)
	if self.deps.log then
		pcall(self.deps.log, "[SuperSonicEvent] " .. text)
	end
end

function Core:_userId(player: any): number
	if self.deps.userId then
		return self.deps.userId(player)
	end
	return player.UserId
end

function Core:_setWorld(name: string, value: any)
	pcall(self.deps.setWorld, name, value)
end

function Core:_setPlayer(player: any, name: string, value: any)
	pcall(self.deps.setPlayer, player, name, value)
end

function Core:_fireAll(message: { any })
	pcall(self.deps.fireAll, message)
end

function Core:_fireOne(player: any, message: { any })
	pcall(self.deps.fireOne, player, message)
end

function Core:_velocity(player: any): Vector3?
	if not self.deps.velocity then
		return nil
	end
	local ok, velocity = pcall(self.deps.velocity, player)
	if ok and velocity ~= nil and velocity.X == velocity.X then
		return velocity
	end
	return nil
end

function Core:IsRunning(): boolean
	return self.running
end

function Core:HasRings(): boolean
	return self.rings ~= nil
end

function Core:Phase(): string
	return self.phase
end

-- The participant record of a player (made on first sight while an event runs or its rings are out).
function Core:_participant(player: any)
	local p = self.participants[player]
	if not p then
		local userId = self:_userId(player)
		p = {
			player = player,
			super = false,
			saved = nil,
			-- The per-event caps follow the account: leaving and rejoining does not reset them.
			hits = self.hitsByUser[userId] or 0,
			rings = self.ringsByUser[userId] or 0,
			lastHomingAt = -INF,
			chargeAt = nil,
			flight = nil,
			knockedAt = -INF,
			stunnedUntil = -INF,
			eligible = false,
			noFlight = false,
			pos = nil,
			pendingWins = 0,
			pendingSpeed = 0,
			batches = 0,
			flushing = false,
			lastFlushAt = -INF,
			flushAt = nil,
			paidWins = 0,
			paidSpeed = 0,
			lostWins = 0,
			-- 2026-09-26 (owner): v3
			areaSeenAt = -INF, -- last seen in the event's area (the frozen-fall rescue)
			safeUntil = -INF, -- no bomb throws until (a trip's arrival)
			lastTeleportAt = nil,
			teleportUntil = nil, -- a trip on its way until
			restoreSuper = nil, -- died inside a freeze window while Super: Super again on respawn
			inEvent = nil, -- in the event's area at the last scan (hysteresis)
			inviteWhy = nil, -- an invite owed (InviteReasons), sent once seen outside the event
			lastInviteAt = -INF,
		}
		self.participants[player] = p
	end
	return p
end

-- Whether a player takes part right now, and where their root is.
function Core:_eligible(player: any, super: boolean): (boolean, Vector3?)
	local deps = self.deps
	local ok, pos = pcall(deps.rootPosition, player)
	if not ok or pos == nil then
		return false, nil
	end
	local okAlive, alive = pcall(deps.alive, player)
	if not okAlive or alive ~= true then
		return false, pos
	end
	-- 2026-09-26 (owner): v3: in a race by the race's attributes (the fight itself is in the race arena).
	local okRace, racing = pcall(deps.racing, player, nil)
	if okRace and racing == true then
		return false, pos
	end
	local okAfk, afk = pcall(deps.afk, player)
	if okAfk and afk == true then
		return false, pos
	end
	if not self:_inEvent(pos, super) then
		return false, pos
	end
	return true, pos
end

-- 2026-09-26 (owner): v3. Whether pos is in the event now (SSE.InEventArea: the arena; the lobby too until the
-- Teleport beat's move; the lobby alone without the arena). keep: the exit test (hysteresis).
function Core:_inEvent(pos: Vector3, keep: boolean?): boolean
	return self.SSE.InEventArea(pos, self.origin, if self.split then self.lobbyOrigin else nil, self.moved, keep)
end

-- Where a trip or a rescue lands round: the arena once everyone was moved there, else the lobby spawn.
function Core:_centre(): Vector3
	return if self.split and self.moved and not self.movedOut then self.origin else self.lobbyOrigin
end

-- 2026-09-26 (owner): v3. Inside the current phase's freeze window (+ grace seconds after it).
function Core:_frozen(now: number, grace: number?): boolean
	return self.running and self.SSE.IsFrozen(self.phase, now - self.phaseStart, grace)
end

----------------------------------------------------------------------
-- Start / Stop
----------------------------------------------------------------------
-- Starts an event. Returns (true) or (false, "running" | "off").
function Core:Start(byName: string?): (boolean, string?)
	local SSE, deps = self.SSE, self.deps
	if self.running then
		return false, "running"
	end
	if not deps.isOn() then
		return false, "off"
	end
	local now = deps.now()
	-- The last event's rings, if still out, go now (their rewards are committed first).
	self:_clearRings()
	for _, p in self.participants do
		self:_flush(p, true)
	end
	self.counter += 1
	self.eventId = self.counter
	self.seed = math.floor(tonumber(deps.newSeed()) or 1)
	self.rng = newRng(self.seed)
	-- 2026-09-26 (owner): v3. The lobby (the Cinematic, the way home) and the fight's centre on the race arena.
	self.lobbyOrigin = deps.origin()
	self.origin = self.lobbyOrigin
	self.split = false
	if deps.arenaOrigin then
		local ok, arena = pcall(deps.arenaOrigin)
		if ok and arena ~= nil and arena.X == arena.X then
			self.origin = arena
			self.split = (arena - self.lobbyOrigin).Magnitude >= 1
		end
	end
	self.moved = false
	self.movedOut = false
	self.liftOff = nil
	if deps.liftOff then
		local ok, lift = pcall(deps.liftOff)
		if ok and lift ~= nil and lift.X == lift.X then
			self.liftOff = lift
		end
	end
	self.plan = SSE.Plan(now, self.seed, self.liftOff, nil, nil, nil, self.lobbyOrigin)
	self.startedBy = byName
	self.participants = {}
	self.hitsByUser = {}
	self.ringsByUser = {}
	self.bombs = {}
	self.launches = {}
	self.nextBombId = 0
	self.salvosFired = 0
	self.nextSalvo = 1
	self.absorbed = false
	self.nextScanAt = -INF
	self.hp = 0
	self.maxHp = 0
	self.peak = 0
	self.bossState = nil
	self.bossStateStart = nil
	self.defeated = false
	self.crashPoint = nil
	self.running = true
	self.stats = newStats()
	self.invited = {}
	self.recentSpots = {}
	self.pulled = {}
	self:_scan(now)
	local count = 0
	for _, p in self.participants do
		if p.eligible then
			count += 1
		end
	end
	self.maxHp = SSE.BossMaxHP(count)
	self.hp = self.maxHp
	local A = SSE.Attributes
	self:_setWorld(A.Origin, self.origin)
	self:_setWorld(A.LobbyOrigin, self.lobbyOrigin)
	self:_setWorld(A.LiftOff, self.liftOff)
	self:_setWorld(A.EventId, self.eventId)
	self:_setWorld(A.Seed, self.seed)
	self:_setWorld(A.EventStart, now)
	self:_setWorld(A.BossMaxHP, self.maxHp)
	self:_setWorld(A.BossHP, self.hp)
	self:_enterPhase(SSE.Phases.Cinematic, now)
	-- 2026-09-26 (owner): v3. The invites (where everyone stands now, before a race trip moves anyone), then the
	-- races close (the heats called off, the arena's players sent to the lobby spawn).
	self:_inviteAtStart()
	self:_closeRaces()
	self:_arenaGates(true)
	pcall(deps.chat, SSE.Announcements.Start)
	self:_log("started (event " .. self.eventId .. ", seed " .. self.seed .. ", by " .. tostring(byName) .. ")")
	return true, nil
end

function Core:_enterPhase(phase: string, at: number)
	local A = self.SSE.Attributes
	self.phase = phase
	self.phaseStart = at
	-- PhaseStart first: a client reacting to SSE_Phase reads the new start with it.
	self:_setWorld(A.PhaseStart, at)
	self:_setWorld(A.Phase, phase)
end

----------------------------------------------------------------------
-- 2026-09-26 (owner): v3. The races, the invites
----------------------------------------------------------------------
function Core:_closeRaces()
	local deps = self.deps
	self.racesClosed = true
	if not deps.closeRaces then
		return
	end
	local ok, pulled = pcall(deps.closeRaces, self.SSE.RaceClosed.Reason)
	if ok and type(pulled) == "table" then
		self.pulled = pulled
		self.stats.pulled = #pulled
	elseif not ok then
		self:_log("closeRaces failed: " .. tostring(pulled))
	end
end

function Core:_openRaces(reason: string?)
	if not self.racesClosed then
		return
	end
	self.racesClosed = false
	if self.deps.openRaces then
		local ok, err = pcall(self.deps.openRaces, self.SSE.RaceClosed.Reason)
		if not ok then
			self:_log("openRaces failed (" .. tostring(reason) .. "): " .. tostring(err))
		end
	end
end

function Core:_afk(player: any): boolean
	local ok, afk = pcall(self.deps.afk, player)
	return ok and afk == true
end

function Core:_invite(player: any, why: string)
	local p = self:_participant(player)
	p.inviteWhy = nil
	p.lastInviteAt = self.deps.now()
	self.invited[player] = true
	self.stats.invites += 1
	self:_fireOne(player, { self.SSE.Messages.Invite, self.eventId, why })
end

-- Everyone outside the event now (the stages, the race arena's racers before their trip home) is invited; a
-- player with no character yet is owed one, sent once seen outside the event (_scan). AFK players are left alone.
function Core:_inviteAtStart()
	local SSE, deps = self.SSE, self.deps
	local okList, list = pcall(deps.players)
	if not okList or type(list) ~= "table" then
		return
	end
	for _, player in list do
		if not self:_afk(player) then
			local okPos, pos = pcall(deps.rootPosition, player)
			if not okPos or pos == nil then
				self:_participant(player).inviteWhy = SSE.InviteReasons.Start
			elseif not self:_inEvent(pos) then
				local okRace, racing = pcall(deps.racing, player, nil)
				self:_invite(player, if okRace and racing == true then SSE.InviteReasons.Race else SSE.InviteReasons.Start)
			end
		end
	end
end

-- 2026-09-26 (owner): v3. The arena's StartGate / StopBar: open (no collisions) for the event, restored after.
function Core:_arenaGates(open: boolean)
	if open == self.gatesOpen or not self.deps.arenaGates then
		return
	end
	if open and not self.split then
		return
	end
	self.gatesOpen = open
	local ok, err = pcall(self.deps.arenaGates, open)
	if not ok then
		self:_log("arenaGates failed: " .. tostring(err))
	end
end

-- 2026-09-26 (owner): v3. The Teleport beat's move: everyone in the lobby area (alive, not AFK, not racing,
-- not already travelling) goes to a free spot round the fight's centre. From now on the event is the arena.
function Core:_moveIn(now: number)
	local SSE, deps = self.SSE, self.deps
	self.moved = true
	self.nextScanAt = -INF
	if not self.split then
		return
	end
	local okList, list = pcall(deps.players)
	if not okList or type(list) ~= "table" then
		return
	end
	table.sort(list, function(a, b)
		return self:_userId(a) < self:_userId(b)
	end)
	for _, player in list do
		local okPos, pos = pcall(deps.rootPosition, player)
		local okAlive, alive = pcall(deps.alive, player)
		local okRace, racing = pcall(deps.racing, player, nil)
		local p = self:_participant(player)
		if okPos and pos and okAlive and alive == true and not (okRace and racing == true) and not self:_afk(player)
			and not (p.teleportUntil and now < p.teleportUntil)
			and SSE.InLobby(pos, self.lobbyOrigin, true) and not SSE.InArena(pos, self.origin, true) then
			self:_trip(p, now, self.origin, false)
			self.stats.movedIn += 1
		end
	end
end

-- 2026-09-26 (owner): v3. The Return beat's move (or Stop's): everyone in the arena goes home, to a free spot
-- round their world's lobby spawn (the world's own spawn trip first).
function Core:_moveOut(now: number)
	local deps = self.deps
	self.movedOut = true
	if not self.split then
		return
	end
	local okList, list = pcall(deps.players)
	if not okList or type(list) ~= "table" then
		return
	end
	table.sort(list, function(a, b)
		return self:_userId(a) < self:_userId(b)
	end)
	for _, player in list do
		local okPos, pos = pcall(deps.rootPosition, player)
		-- 2026-09-26 (owner, critical): anywhere on the race map, not only in the fight's corridor box (players
		-- who ran along the track stayed behind).
		if okPos and pos and (self.SSE.InArena(pos, self.origin, true) or self.SSE.InRaceMap(pos, self.origin)) then
			self:_trip(self:_participant(player), now, self.lobbyOrigin, true)
			self.stats.movedOut += 1
		end
	end
end

function Core:_clearBossState()
	local A = self.SSE.Attributes
	self.bossState, self.bossStateStart = nil, nil
	self:_setWorld(A.BossState, nil)
	self:_setWorld(A.BossStateStart, nil)
	self:_setWorld(A.BossStateEnd, nil)
end

-- Ends the event at once: every Super player restored (their own skin), Flight back, the rewards
-- committed, the attributes cleared. reason: "admin" | "killswitch" | "defeated" | "escaped". v3: the arena's
-- players sent home (if the Return beat has not), the rings gone (they live in the arena), the races open and
-- the arena's gates restored. Returns whether one was running.
function Core:Stop(reason: string?): boolean
	if not self.running then
		return false
	end
	local SSE = self.SSE
	-- 2026-09-26 (owner): v3. Cut short (an admin stop, the kill switch): the arena's players go home now.
	if self.split and self.moved and not self.movedOut then
		self:_moveOut(self.deps.now())
	end
	self.running = false
	for player, p in self.participants do
		if p.super then
			self:_unSuper(p)
		end
		p.flight = nil
		p.chargeAt = nil
		p.restoreSuper = nil
		p.teleportUntil = nil
		if p.noFlight then
			p.noFlight = false
			if self.deps.setNoFlight then
				pcall(self.deps.setNoFlight, player, false)
			end
		end
		self:_setPlayer(player, SSE.PlayerAttributes.Hits, nil)
		self:_flush(p, true)
	end
	self.bombs = {}
	self.launches = {}
	self.recentSpots = {}
	self:_clearRings()
	-- 2026-09-26 (owner): v3. The races open again, whatever ended the event, and the arena's gates close.
	self:_openRaces(reason)
	self:_arenaGates(false)
	self:_clearBossState()
	local A = SSE.Attributes
	self:_setWorld(A.PhaseStart, nil)
	self:_setWorld(A.EventStart, nil)
	self:_setWorld(A.EventId, nil)
	self:_setWorld(A.Seed, nil)
	self:_setWorld(A.BossHP, nil)
	self:_setWorld(A.BossMaxHP, nil)
	self:_setWorld(A.Origin, nil)
	self:_setWorld(A.LiftOff, nil)
	self:_setWorld(A.CrashPoint, nil)
	self:_setWorld(A.LobbyOrigin, nil)
	self:_setWorld(A.EndStart, nil)
	self:_setWorld(A.Outcome, nil)
	self.crashPoint = nil
	self.phase = SSE.Phases.None
	self:_setWorld(A.Phase, SSE.Phases.None)
	self:_log("ended (" .. tostring(reason) .. ")")
	return true
end

----------------------------------------------------------------------
-- The clock
----------------------------------------------------------------------
function Core:Step()
	local deps, SSE = self.deps, self.SSE
	local now = deps.now()
	if self.running then
		if not deps.isOn() then
			self:Stop("killswitch")
			return
		end
		if now >= self.nextScanAt then
			self.nextScanAt = now + SCAN_SECONDS
			self:_scan(now)
		end
		self:_launchBombs(now)
		self:_landBombs(now)
		self:_arrivals(now)
		-- Phase changes; several in one Step when the clock jumped (each at its scheduled time).
		local D, P = SSE.Durations, SSE.Phases
		for _ = 1, 8 do
			if not self.running then
				break
			end
			local phase, start = self.phase, self.phaseStart
			if phase == P.Cinematic and now >= start + D.Cinematic then
				self:_enterPhase(P.Teleport, start + D.Cinematic)
			elseif phase == P.Teleport then
				-- 2026-09-26 (owner): v3. The beat: the lobby moves to the arena at MoveAt, Eggman flies in.
				if not self.moved and now >= start + SSE.Beats.Teleport.MoveAt then
					self:_moveIn(now)
				end
				if now >= start + D.Teleport then
					self:_enterPhase(P.Bombard, start + D.Teleport)
					self.salvosFired = 0
				else
					break
				end
			elseif phase == P.Bombard then
				local B = SSE.Bombard
				while self.salvosFired < B.Salvos and now >= start + B.SalvoTimes[self.salvosFired + 1] do
					self.salvosFired += 1
					self:_queueSalvo(start + B.SalvoTimes[self.salvosFired], B.Patterns[self.salvosFired] or "Aimed", false, 1)
				end
				if now >= start + D.Bombard then
					self:_enterPhase(P.Emeralds, start + D.Bombard)
					self.absorbed = false
				else
					break
				end
			elseif phase == P.Emeralds then
				if not self.absorbed and now >= start + SSE.Emeralds.AbsorbAt then
					self.absorbed = true
					self:_absorb()
				end
				if now >= start + D.Emeralds then
					self:_beginBattle(start + D.Emeralds)
				else
					break
				end
			elseif phase == P.Battle then
				self:_battleSalvos(now)
				if now >= start + D.Battle then
					-- 2026-09-26 (owner): v3. HP 0 always wins: the Escape waits for the attacks still flying at
					-- the timeout (at most Homing.MaxFlightSeconds); one of them may still break him.
					local waitUntil = self:_lastArrival()
					if waitUntil and now < waitUntil and now < start + D.Battle + SSE.Homing.MaxFlightSeconds then
						break
					end
					local at = start + D.Battle
					if waitUntil then
						at = math.max(at, math.min(now, waitUntil))
					end
					self:_escape(at)
				else
					self:_mirrorBossState(now)
					break
				end
			elseif phase == P.Defeat or phase == P.Escape then
				-- 2026-09-26 (owner): v3. Then the Return beat (the rings are gone by then).
				local length = if phase == P.Defeat then D.Defeat else D.Escape
				if now >= start + length then
					self:_clearRings()
					self:_enterPhase(P.Return, start + length)
				else
					break
				end
			elseif phase == P.Return then
				if not self.movedOut and now >= start + SSE.Beats.Return.MoveAt then
					self:_moveOut(now)
				end
				if now >= start + D.Return then
					self:Stop(if self.defeated then "defeated" else "escaped")
				end
				break
			else
				break
			end
		end
		if self.running then
			self:_launchBombs(now)
			self:_landBombs(now)
		end
	end
	if self.rings then
		if not deps.isOn() then
			self:ClearRings()
		else
			self:_ringStep(now)
		end
	end
	self:_flushes(now)
end

-- Who takes part: eligibility, the Super forms kept or ended, late transformations, the no-flight flags,
-- the rescue of a player a bomb threw off the lobby, the HP growing with new participants.
function Core:_scan(now: number)
	local deps, SSE = self.deps, self.SSE
	local okList, list = pcall(deps.players)
	if not okList or type(list) ~= "table" then
		return
	end
	-- 2026-09-26 (owner): v3. Inside a freeze window (+ its grace) a fall off the lobby is put back too.
	local frozen = self:_frozen(now, SSE.Freeze.FallGraceSeconds)
	for _, player in list do
		local p = self:_participant(player)
		local eligible, pos = self:_eligible(player, p.super)
		p.eligible, p.pos = eligible, pos
		if p.super and not eligible then
			self:_unSuper(p)
		elseif not p.super and eligible and self.absorbed and ((SSE.Super.LateTransform
			and (self.phase == SSE.Phases.Emeralds or self.phase == SSE.Phases.Battle)) or p.restoreSuper) then
			-- (v3: restoreSuper, a death inside a freeze window: Super again on respawn, the outro included)
			self:_makeSuper(p)
		end
		if p.super then
			p.restoreSuper = nil
		end
		if pos and self:_inEvent(pos, true) then
			p.areaSeenAt = now
		end
		-- 2026-09-26 (owner): no Flight in the event's area for the whole event (enter at Radius, keep until
		-- ExitRadius; a dead player keeps the flag). v3: the event's area (InEventArea): after the Teleport beat
		-- a player in the lobby has their world back.
		if pos then
			local grounded = self:_inEvent(pos, p.noFlight)
			if grounded ~= p.noFlight then
				p.noFlight = grounded
				if deps.setNoFlight then
					pcall(deps.setNoFlight, player, grounded)
				end
			end
		end
		-- Thrown off the floor (a bomb, the shield) or (v3) dropped off it inside a freeze window: back at the
		-- fight's centre (the lobby spawn before the Teleport beat).
		local centre = if pos then self:_fellFrom(pos) else nil
		if centre then
			local thrown = now - p.knockedAt <= SSE.Bombard.RescueSeconds
			local frozenFall = frozen and now - p.areaSeenAt <= SSE.Bombard.RescueSeconds
			if thrown or frozenFall then
				p.knockedAt = -INF
				self.stats.rescues += 1
				if not thrown then
					self.stats.frozenFalls += 1
				end
				pcall(deps.rescue, player, centre + Vector3.new(0, 4, 0))
			end
		end
		-- 2026-09-26 (owner): v3. The invites: a player not in the event is owed one when they joined the server,
		-- respawned (a death in the arena respawns in the lobby) or left the event's area; it goes out once they
		-- are seen outside it, until the Defeat / Escape, at most one every Invite.MinGapSeconds.
		if pos then
			if self:_inEvent(pos, p.inEvent == true) then
				p.inEvent = true
				p.inviteWhy = nil
			else
				if p.inEvent == true then
					p.inviteWhy = p.inviteWhy or SSE.InviteReasons.Left
				end
				p.inEvent = false
				if p.inviteWhy and SSE.InviteOpen(self.phase) and not self.movedOut
					and not (p.teleportUntil and now < p.teleportUntil)
					and now - p.lastInviteAt >= SSE.Invite.MinGapSeconds and not self:_afk(player) then
					self:_invite(player, p.inviteWhy)
				end
			end
		end
	end
	if self.phase == SSE.Phases.Battle then
		self:_growHp()
	end
end

-- 2026-09-26 (owner): v3. The centre a fall is put back at, or nil: pos dropped RescueDrop under the centre it
-- stands over (the arena after the Teleport beat, the lobby before it), inside that area's footprint.
function Core:_fellFrom(pos: Vector3): Vector3?
	local SSE = self.SSE
	if self.movedOut then
		return nil
	end
	local centre = self:_centre()
	if pos.Y >= centre.Y - SSE.Bombard.RescueDrop then
		return nil
	end
	local flat = Vector3.new(pos.X, centre.Y, pos.Z)
	local over = if self.split and centre == self.origin then SSE.InArena(flat, centre, true) else SSE.InLobby(flat, centre, true)
	return if over then centre else nil
end

----------------------------------------------------------------------
-- Bombs (the Bombard and the Battle's Attack windows)
----------------------------------------------------------------------
-- Targets: eligible players (the Bombard: not Super, on the ground; the Battle: everyone eligible), in a
-- stable order (the seed decides, not the table order).
function Core:_targets(battle: boolean): { any }
	local list = {}
	for player, p in self.participants do
		if p.eligible and p.pos then
			if battle then
				table.insert(list, p)
			elseif not p.super then
				local okGround, grounded = pcall(self.deps.grounded, player)
				if not okGround or grounded ~= false then
					table.insert(list, p)
				end
			end
		end
	end
	table.sort(list, function(a, b)
		return self:_userId(a.player) < self:_userId(b.player)
	end)
	return list
end

-- A salvo: its launches (one per bomb; a Parallel line is one launch of Count bombs side by side).
-- untilAt: (the Battle) its Attack window's end: every bomb leaves before it (the stagger shrinks to fit;
-- the cannon is in during Reload).
function Core:_queueSalvo(at: number, pattern: string, battle: boolean, window: number, untilAt: number?)
	local SSE = self.SSE
	local B = SSE.Bombard
	local targets = #self:_targets(battle)
	local room = if untilAt then math.max(0, untilAt - 0.05 - at) else INF
	if pattern == "Parallel" then
		local P = B.Parallel
		local lines = math.max(1, math.min(P.Lines, targets))
		local lineStagger = if lines > 1 then math.min(P.LineStagger, room / (lines - 1)) else 0
		for line = 1, lines do
			table.insert(self.launches, { at = at + (line - 1) * lineStagger, pattern = pattern, battle = battle,
				window = window, count = if battle then P.Count else P.BombardCount })
		end
	else
		local n = if battle then SSE.BattleBombsPerSalvo(targets, window) else SSE.BombsPerSalvo(targets)
		local stagger = if pattern == "Rain" then B.BombStagger / 2 else B.BombStagger
		if n > 1 then
			stagger = math.min(stagger, room / (n - 1))
		end
		for j = 1, n do
			table.insert(self.launches, { at = at + (j - 1) * stagger, pattern = pattern, battle = battle, window = window, count = 1 })
		end
	end
end

-- The Battle's salvos that are due (BattleSalvos: Attack windows only).
function Core:_battleSalvos(now: number)
	local SSE = self.SSE
	local salvos = SSE.BattleSalvos(self.seed)
	while self.nextSalvo <= #salvos and now >= self.phaseStart + salvos[self.nextSalvo].t do
		local salvo = salvos[self.nextSalvo]
		self.nextSalvo += 1
		local _, _, finish = SSE.BossState(salvo.t, self.seed)
		self:_queueSalvo(self.phaseStart + salvo.t, salvo.pattern, true, salvo.window, self.phaseStart + finish)
	end
end

function Core:_floorUnder(x: number, y: number, z: number, fallbackY: number): Vector3
	local okGround, hit = pcall(self.deps.ground, Vector3.new(x, y, z))
	if okGround and hit ~= nil then
		return hit
	end
	return Vector3.new(x, fallbackY, z)
end

function Core:_fireBomb(from: Vector3, to: Vector3, at: number, flight: number, pattern: string, battle: boolean)
	local SSE = self.SSE
	self.nextBombId += 1
	local bomb = { id = self.nextBombId, from = from, to = to, launch = at, flight = flight, impact = at + flight,
		pattern = pattern, battle = battle }
	table.insert(self.bombs, bomb)
	self.stats.bombs += 1
	self:_fireAll({ SSE.Messages.Bomb, bomb.id, from, to, at, flight, pattern, SSE.Warning.Radius })
end

-- Where a bomb aims at a target: its root led by its velocity (LeadPoint), on the floor.
function Core:_aim(p: any, from: Vector3, battle: boolean): Vector3
	local guess = self.SSE.BombFlightTime(from, p.pos, battle)
	return self.SSE.LeadPoint(p.pos, self:_velocity(p.player), guess)
end

function Core:_launch(entry: any, targets: { any })
	local SSE, B = self.SSE, self.SSE.Bombard
	local at = entry.at
	local from = SSE.CannonPosition(self.origin, at, self.plan)
	local angle = self.rng() * TAU
	if entry.pattern == "Parallel" then
		local center, baseY
		if #targets > 0 then
			local p = targets[math.floor(self.rng() * #targets) + 1]
			center, baseY = self:_aim(p, from, entry.battle), p.pos.Y
		else
			local r = B.FallbackRadius * math.sqrt(self.rng())
			center = Vector3.new(self.origin.X + math.cos(angle) * r, self.origin.Y + 3, self.origin.Z + math.sin(angle) * r)
			baseY = self.origin.Y + 3
		end
		local middle = self:_floorUnder(center.X, baseY, center.Z, baseY - 3)
		local flight = SSE.BombFlightTime(from, middle, entry.battle)
		for _, offset in SSE.ParallelOffsets(center.X - from.X, center.Z - from.Z, entry.count) do
			local to = self:_floorUnder(center.X + offset[1], baseY, center.Z + offset[2], baseY - 3)
			self:_fireBomb(from, to, at, flight, entry.pattern, entry.battle)
		end
		return
	end
	local to
	if #targets > 0 then
		local p = targets[math.floor(self.rng() * #targets) + 1]
		local scatter = if entry.pattern == "Rain" then B.RainScatter else B.TargetScatter
		local r = scatter * math.sqrt(self.rng())
		local aim = self:_aim(p, from, entry.battle)
		to = self:_floorUnder(aim.X + math.cos(angle) * r, p.pos.Y, aim.Z + math.sin(angle) * r, p.pos.Y - 3)
	else
		local r = B.FallbackRadius * math.sqrt(self.rng())
		local x, z = self.origin.X + math.cos(angle) * r, self.origin.Z + math.sin(angle) * r
		to = self:_floorUnder(x, self.origin.Y + 3, z, self.origin.Y)
	end
	self:_fireBomb(from, to, at, SSE.BombFlightTime(from, to, entry.battle), entry.pattern, entry.battle)
end

function Core:_launchBombs(now: number)
	if #self.launches == 0 then
		return
	end
	local due, remaining = {}, {}
	for _, entry in self.launches do
		if now >= entry.at then
			table.insert(due, entry)
		else
			table.insert(remaining, entry)
		end
	end
	self.launches = remaining
	if #due == 0 then
		return
	end
	table.sort(due, function(a, b)
		return a.at < b.at
	end)
	local targetsFor = {}
	for _, entry in due do
		local key = if entry.battle then "battle" else "bombard"
		targetsFor[key] = targetsFor[key] or self:_targets(entry.battle)
		self:_launch(entry, targetsFor[key])
	end
end

function Core:_landBombs(now: number)
	if #self.bombs == 0 then
		return
	end
	local remaining = {}
	for _, bomb in self.bombs do
		if now >= bomb.impact then
			self:_blast(bomb, now)
		else
			table.insert(remaining, bomb)
		end
	end
	self.bombs = remaining
end

-- The blast: every eligible player within BlastRadius is thrown (a live ragdoll, never a kill). In the
-- Bombard Super players are left alone; in the Battle they are thrown too (shorter), and the throw ends
-- their charge and their homing attack in flight.
function Core:_blast(bomb: any, now: number)
	local SSE, deps, B = self.SSE, self.deps, self.SSE.Bombard
	-- 2026-09-26 (owner): v3. Inside a freeze window (the cinematics) a bomb still bursts but throws nobody, and
	-- a player who just arrived by the event's trip is spared for Teleport.SafeSeconds.
	local frozen = self:_frozen(now)
	if frozen then
		self.stats.frozenBlasts += 1
	end
	for player, p in self.participants do
		if not frozen and now >= p.safeUntil and (bomb.battle or not p.super) and now - p.knockedAt >= B.KnockGrace then
			local eligible, pos = self:_eligible(player, p.super)
			if eligible and pos and SSE.InBlast(pos, bomb.to) then
				local velocity = SSE.Knockback(pos, bomb.to)
				local seconds = if p.super then SSE.Battle.SuperRagdollSeconds else B.RagdollSeconds
				p.knockedAt = now
				p.stunnedUntil = now + seconds
				p.flight = nil
				p.chargeAt = nil
				self.stats.knocks += 1
				pcall(deps.ragdoll, player, seconds, velocity)
				self:_fireOne(player, { SSE.Messages.Knock, velocity, seconds, SSE.KnockKinds.Bomb })
			end
		end
	end
	self:_fireAll({ SSE.Messages.BombHit, bomb.id, bomb.to })
end

----------------------------------------------------------------------
-- Emeralds and the Super form
----------------------------------------------------------------------
function Core:_makeSuper(p: any)
	if p.super then
		return
	end
	local ok, saved = pcall(self.deps.applySuper, p.player)
	if not ok then
		self:_log("applySuper failed: " .. tostring(saved))
		return
	end
	p.super = true
	p.saved = saved
	self:_setPlayer(p.player, self.SSE.PlayerAttributes.Super, true)
end

function Core:_unSuper(p: any)
	if not p.super then
		return
	end
	p.super = false
	p.flight = nil
	p.chargeAt = nil
	local saved = p.saved
	p.saved = nil
	local ok, err = pcall(self.deps.restoreSuper, p.player, saved)
	if not ok then
		self:_log("restoreSuper failed: " .. tostring(err))
	end
	self:_setPlayer(p.player, self.SSE.PlayerAttributes.Super, nil)
end

-- The absorption: every eligible lobby player turns Super at once.
function Core:_absorb()
	local now = self.deps.now()
	self:_scan(now)
	self.nextScanAt = now + SCAN_SECONDS
	for _, p in self.participants do
		if p.eligible and not p.super then
			self:_makeSuper(p)
		end
	end
end

function Core:_supers(): number
	local count = 0
	for _, p in self.participants do
		if p.super then
			count += 1
		end
	end
	return count
end

function Core:_beginBattle(at: number)
	local SSE, A = self.SSE, self.SSE.Attributes
	local count = self:_supers()
	self.peak = count
	self.maxHp = SSE.BossMaxHP(count)
	self.hp = self.maxHp
	self.nextSalvo = 1
	self:_setWorld(A.BossMaxHP, self.maxHp)
	self:_setWorld(A.BossHP, self.hp)
	self:_enterPhase(SSE.Phases.Battle, at)
	self:_mirrorBossState(at)
end

-- 2026-09-26 (owner): a new participant (more Super players than ever this Battle) raises the ship's HP by
-- the difference of the formula (never lowered when players leave).
function Core:_growHp()
	local SSE = self.SSE
	if not SSE.HP.GrowWithLateJoiners or self.defeated then
		return
	end
	local count = self:_supers()
	if count <= self.peak then
		return
	end
	local newMax = SSE.BossMaxHP(count)
	local add = newMax - self.maxHp
	self.peak = count
	if add > 0 then
		self.maxHp = newMax
		self.hp += add
		self:_setWorld(SSE.Attributes.BossMaxHP, self.maxHp)
		self:_setWorld(SSE.Attributes.BossHP, self.hp)
	end
end

-- SSE_BossState / Start / End: the Battle's current window (Start first, like the phases).
function Core:_mirrorBossState(now: number)
	local SSE, A = self.SSE, self.SSE.Attributes
	local state, s, f = SSE.BossState(now - self.phaseStart, self.seed)
	if state == self.bossState and s == self.bossStateStart then
		return
	end
	self.bossState, self.bossStateStart = state, s
	self:_setWorld(A.BossStateStart, self.phaseStart + s)
	self:_setWorld(A.BossStateEnd, self.phaseStart + math.min(f, SSE.Durations.Battle))
	self:_setWorld(A.BossState, state)
end

----------------------------------------------------------------------
-- Client messages (rate-limited per player)
----------------------------------------------------------------------
function Core:_allow(player: any): boolean
	local now = self.deps.now()
	local limit = self.SSE.RateLimit
	local bucket = self.buckets[player]
	if not bucket then
		bucket = { tokens = limit.Burst, at = now }
		self.buckets[player] = bucket
	end
	bucket.tokens = math.min(limit.Burst, bucket.tokens + math.max(0, now - bucket.at) * limit.PerSecond)
	bucket.at = now
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

-- One client message: { "Charge", t } | { "Homing", t, charge01? } | { "RingTake", id | {ids} } |
-- (v3) { "TeleportToEvent", eventId? } (the vararg forms too). Returns the message's name when handled,
-- "limited" when dropped, nil when unknown.
function Core:ClientMessage(player: any, first: any, second: any, third: any): string?
	local name, a, b = first, second, third
	if type(first) == "table" then
		name, a, b = first[1], first[2], first[3]
	end
	local M = self.SSE.Messages
	if name ~= M.Charge and name ~= M.Homing and name ~= M.RingTake and name ~= M.TeleportToEvent then
		return nil
	end
	if not self:_allow(player) then
		return "limited"
	end
	if name == M.Charge then
		self:Charge(player, if type(a) == "number" then a else nil)
	elseif name == M.Homing then
		self:RequestHoming(player, if type(a) == "number" then a else nil, if type(b) == "number" then b else nil)
	elseif name == M.TeleportToEvent then
		self:RequestTeleport(player, a)
	else
		self:RingTake(player, a)
	end
	return name
end

----------------------------------------------------------------------
-- Battle
----------------------------------------------------------------------
-- 2026-09-26 (owner): F / the button pressed: the charge starts at the server's own receive time.
function Core:Charge(player: any, _clientTime: number?): boolean
	if not self.running then
		return false
	end
	local p = self:_participant(player)
	p.chargeAt = self.deps.now()
	return true
end

-- A homing attack request (the release, or v3's mid-air jump press with no Charge before it: uncharged).
-- Returns (true) or (false, reason) and tells the player when refused. v3: an attack that would arrive while
-- the shield is up flies anyway and bounces off at its arrival: (true, "Shielded").
function Core:RequestHoming(player: any, clientTime: any, clientCharge: any): (boolean, string?)
	local SSE, deps = self.SSE, self.deps
	local now = deps.now()
	local p = if self.running then self:_participant(player) else nil
	-- The charge: measured from this server's receive times (press -> release), used up by this release.
	-- 2026-09-26 (owner): v3. A press older than Homing.ChargeStaleSeconds is forgotten (its release never came).
	local charge = 0
	if p then
		local pressAt = p.chargeAt
		if pressAt and now - pressAt > SSE.Homing.ChargeStaleSeconds then
			pressAt = nil
		end
		charge = SSE.MeasureCharge(pressAt, now, clientCharge)
		p.chargeAt = nil
	end
	local okPos, pos = pcall(deps.rootPosition, player)
	if not okPos then
		pos = nil
	end
	local okAlive, alive = pcall(deps.alive, player)
	local okRace, racing = false, false
	if pos then
		okRace, racing = pcall(deps.racing, player, nil) -- (v3: by the race's attributes: the fight is in the arena)
	end
	local rewind = SSE.RewindTime(clientTime, now)
	local distance, to, duration, arrive = nil, nil, nil, nil
	if pos and self.running then
		distance = math.min(dist(pos, SSE.BossPosition(self.origin, now, self.plan)), dist(pos, SSE.BossPosition(self.origin, rewind, self.plan)))
		to, duration = SSE.HomingIntercept(pos, self.origin, rewind, self.plan)
		arrive = rewind + duration
	end
	local vulnerable = nil
	if self.running and self.phase == SSE.Phases.Battle and arrive then
		vulnerable = SSE.BossVulnerable(arrive - self.phaseStart, self.seed)
	end
	local ok, reason = SSE.CheckHoming({
		on = deps.isOn(),
		phase = if self.running then self.phase else SSE.Phases.None,
		super = p ~= nil and p.super,
		alive = pos ~= nil and okAlive and alive == true,
		racing = okRace and racing == true,
		stunned = p ~= nil and now < p.stunnedUntil,
		inFlight = p ~= nil and p.flight ~= nil,
		hits = if p then p.hits else 0,
		lastAt = if p then p.lastHomingAt else nil,
		now = now,
		distance = distance,
		vulnerable = vulnerable,
	})
	-- 2026-09-26 (owner): v3. The shield is up at the arrival: the attack flies and bounces off (_shieldBounce).
	local shielded = false
	if not ok and reason == SSE.HomingRefusals.Shielded then
		ok, shielded = true, true
	end
	if not ok then
		self.stats.refused[reason] = (self.stats.refused[reason] or 0) + 1
		self:_fireOne(player, { SSE.Messages.HomingNo, reason })
		return false, reason
	end
	local damage = if shielded then 0 else SSE.HomingDamage(charge)
	p.lastHomingAt = now
	p.flight = { arriveAt = math.max(now, arrive), from = pos, to = to, charge = charge, damage = damage, shielded = shielded }
	self:_fireAll({ SSE.Messages.HomingGo, self:_userId(player), pos, to, rewind, duration, charge, damage, shielded })
	return true, if shielded then SSE.HomingRefusals.Shielded else nil
end

-- Lands the attacks that have arrived. 2026-09-26 (owner): v3. An attack that was flying when the ship broke
-- still lands and pays (a hit on the wreck: the bar stays at 0), and a shielded one bounces off.
function Core:_arrivals(now: number)
	local P = self.SSE.Phases
	for _, p in self.participants do
		local flight = p.flight
		if flight and now >= flight.arriveAt then
			p.flight = nil
			if self.running and p.super then
				if self.phase == P.Battle then
					if flight.shielded then
						self:_shieldBounce(p, flight.arriveAt, flight)
					else
						self:_hit(p, flight.arriveAt, flight)
					end
				elseif self.phase == P.Defeat and not flight.shielded then
					self:_hit(p, flight.arriveAt, flight)
				end
			end
		end
	end
end

-- 2026-09-26 (owner): v3. The latest arrival of the (unshielded) attacks still flying, or nil.
function Core:_lastArrival(): number?
	local last = nil
	for _, p in self.participants do
		local flight = p.flight
		if flight and not flight.shielded and p.super then
			last = math.max(last or -INF, flight.arriveAt)
		end
	end
	return last
end

-- 2026-09-26 (owner): v3. An attack reached the ship while its shield was up: no damage; the attacker is
-- thrown away from the ship (ShieldKnock: back the way the attack came, no ragdoll, never a kill), "stunned"
-- for Shield.StunSeconds, told { HomingNo, Shielded } + { Knock, velocity, 0, "Shield" }; everyone sees the
-- shield flash ({ ShieldHit, userId, pos }). A throw off the sky lobby is put back at the spawn (_scan).
function Core:_shieldBounce(p: any, at: number, flight: any)
	local SSE, deps = self.SSE, self.deps
	local player = p.player
	local now = deps.now()
	local shipPos = SSE.BossPosition(self.origin, at, self.plan)
	local velocity = SSE.ShieldKnock(flight.from or shipPos, shipPos)
	p.knockedAt = now
	p.stunnedUntil = math.max(p.stunnedUntil, now + SSE.Shield.StunSeconds)
	p.chargeAt = nil
	self.stats.shieldBounces += 1
	if deps.push then
		pcall(deps.push, player, velocity)
	end
	self:_fireOne(player, { SSE.Messages.HomingNo, SSE.HomingRefusals.Shielded })
	self:_fireOne(player, { SSE.Messages.Knock, velocity, SSE.Shield.RagdollSeconds, SSE.KnockKinds.Shield })
	self:_fireAll({ SSE.Messages.ShieldHit, self:_userId(player), shipPos })
end

-- A reward for the earner: pending until its batch is committed (the first at once).
function Core:_pay(p: any, wins: number, speed: number, kind: string)
	local R = self.SSE.Rewards
	p.pendingWins += wins
	p.pendingSpeed += speed
	self:_fireOne(p.player, { self.SSE.Messages.Reward, wins, speed, kind })
	local now = self.deps.now()
	if now - p.lastFlushAt >= R.FlushSeconds then
		self:_flush(p, false)
	elseif p.flushAt == nil then
		p.flushAt = p.lastFlushAt + R.FlushSeconds
	end
end

function Core:_hit(p: any, at: number, flight: any)
	local SSE, R = self.SSE, self.SSE.Rewards
	local player = p.player
	local damage = math.max(1, math.floor(tonumber(flight and flight.damage) or 1))
	local charge = tonumber(flight and flight.charge) or 0
	self.hp = math.max(0, self.hp - damage)
	p.hits += 1
	self.hitsByUser[self:_userId(player)] = p.hits
	self.stats.hits += 1
	self.stats.damage += damage
	self:_setPlayer(player, SSE.PlayerAttributes.Hits, p.hits)
	self:_setWorld(SSE.Attributes.BossHP, self.hp)
	local recoil = SSE.BossRecoil(charge)
	self:_fireAll({ SSE.Messages.Hit, self:_userId(player), SSE.BossPosition(self.origin, at, self.plan), self.hp, self.maxHp,
		damage, charge, recoil })
	-- 2026-09-26 (owner): the first MaxRewardedHits hits pay; later ones still count for the fight.
	if p.hits <= R.MaxRewardedHits then
		local wins = R.HitWins
		if R.ApplyWinsMultiplier and self.deps.winsMultiplier then
			local ok, multiplier = pcall(self.deps.winsMultiplier, player)
			multiplier = if ok then tonumber(multiplier) else nil
			if multiplier and multiplier == multiplier and multiplier >= 1 and multiplier < INF then
				wins = math.floor(wins * multiplier)
			end
		end
		self:_pay(p, wins, R.HitSpeed, "hit")
	end
	if self.hp <= 0 and not self.defeated then
		self:_defeat(at)
	end
end

function Core:_endFight(at: number, outcome: string)
	self.plan.endStart = at
	self.plan.outcome = outcome
	self.launches = {}
	self:_clearBossState()
	-- 2026-09-26 (owner): v3. Kept for the Return beat's plan (SSE_Phase moves on).
	self:_setWorld(self.SSE.Attributes.EndStart, at)
	self:_setWorld(self.SSE.Attributes.Outcome, outcome)
	for _, p in self.participants do
		p.inviteWhy = nil -- no invites after the fight
		-- 2026-09-26 (owner): v3. At the Defeat the attacks already flying still land (and pay: _arrivals); a
		-- shielded one, and every one at the Escape, is gone.
		if p.flight and (outcome ~= self.SSE.Phases.Defeat or p.flight.shielded) then
			p.flight = nil
		end
		p.chargeAt = nil
	end
end

-- 2026-09-26 (owner): v3. The crash point: the first CrashCandidate (toward the ship, near the spawn) with lobby
-- floor under it (the rings' raycast rules), else the spawn itself.
function Core:_crashPoint(at: number): Vector3
	local SSE = self.SSE
	local ship = SSE.BossPosition(self.origin, at, self.plan)
	for k = 1, SSE.Crash.Candidates do
		local floor = self:_ringFloor(SSE.CrashCandidate(self.origin, ship, k, if self.split then SSE.Crash.MaxAcross else nil))
		if floor then
			return floor
		end
	end
	return Vector3.new(self.origin.X, self.origin.Y, self.origin.Z)
end

-- HP 0: the Defeat. 2026-09-26 (owner): v3: the ship crashes at SSE_CrashPoint (set before the phase, so a
-- client reading SSE_Phase = "Defeat" builds the crash plan at once), the rings burst out of the crash point.
function Core:_defeat(at: number)
	local SSE = self.SSE
	self.defeated = true
	local crash = self:_crashPoint(at)
	self:_endFight(at, SSE.Phases.Defeat)
	self.plan.crashPoint = crash
	self.crashPoint = crash
	self:_setWorld(SSE.Attributes.CrashPoint, crash)
	self:_enterPhase(SSE.Phases.Defeat, at)
	self:_fireAll({ SSE.Messages.Defeat, crash, SSE.CrashTimes(at).impact })
	pcall(self.deps.chat, SSE.Announcements.Defeat)
	for _, p in self.participants do
		self:_flush(p, false)
	end
	self:_dropRings(at)
end

function Core:_escape(at: number)
	local SSE = self.SSE
	self:_endFight(at, SSE.Phases.Escape)
	self:_enterPhase(SSE.Phases.Escape, at)
	self:_fireAll({ SSE.Messages.Escape })
	pcall(self.deps.chat, SSE.Announcements.Escape)
end

----------------------------------------------------------------------
-- The defeat's gold rings
----------------------------------------------------------------------
-- The floor under a candidate spot (walkable, near the origin's height), or nil.
function Core:_ringFloor(candidate: Vector3): Vector3?
	local SSE, deps = self.SSE, self.deps
	local R = SSE.Rings
	local probe = Vector3.new(candidate.X, self.origin.Y + R.ProbeUp, candidate.Z)
	local ok, hit, normalY
	if deps.ringGround then
		ok, hit, normalY = pcall(deps.ringGround, probe)
	else
		ok, hit = pcall(deps.ground, probe)
	end
	if not ok or hit == nil then
		return nil
	end
	if type(normalY) == "number" and normalY < R.MinNormalY then
		return nil
	end
	if hit.Y > self.origin.Y + R.MaxRise or hit.Y < self.origin.Y - R.MaxDrop then
		return nil
	end
	return hit
end

function Core:_dropRings(at: number)
	local SSE = self.SSE
	local R = SSE.Rings
	local n = SSE.RingCount(math.max(self.peak or 0, self:_supers()))
	local list, positions = {}, {}
	for i = 1, n do
		for k = 0, R.Tries - 1 do
			local floor = self:_ringFloor(SSE.RingScatter(self.origin, self.seed, i + k * n, n, if self.split then R.ScaleX else nil))
			if floor then
				local pos = Vector3.new(floor.X, floor.Y + R.Height, floor.Z)
				table.insert(list, { pos = pos, taken = nil })
				table.insert(positions, pos)
				break
			end
		end
	end
	-- 2026-09-26 (owner): v3. They burst out of the crash point after the impact (CrashTimes); without one (v2)
	-- they fall from the ship LandDelay after the defeat.
	local landAt, burstAt, from = at + R.LandDelay, at, SSE.BossPosition(self.origin, at, self.plan)
	if self.crashPoint then
		local times = SSE.CrashTimes(at)
		landAt, burstAt = times.ringsLand, times.ringsBurst
		from = self.crashPoint + Vector3.new(0, SSE.Crash.RingsUp, 0)
	end
	self.rings = {
		eventId = self.eventId,
		list = list,
		positions = positions,
		landAt = landAt,
		burstAt = burstAt,
		expireAt = landAt + R.LifeSeconds,
		from = from,
		taken = 0,
	}
	self.stats.rings = #list
	self:_fireAll(self:_ringsMessage())
end

function Core:_ringsMessage(): { any }
	local rings = self.rings
	local takenIds = {}
	for id, ring in rings.list do
		if ring.taken ~= nil then
			table.insert(takenIds, id)
		end
	end
	return { self.SSE.Messages.Rings, rings.eventId, rings.positions, rings.landAt, rings.expireAt, rings.from, takenIds,
		rings.burstAt }
end

-- A player joined while rings are out: they get the rain too (without the rings already taken).
-- 2026-09-26 (owner): v3. A player who joins before the Defeat is invited once seen outside the area (_scan).
function Core:PlayerJoined(player: any)
	if self.rings then
		self:_fireOne(player, self:_ringsMessage())
	end
	if self.running and self.SSE.InviteOpen(self.phase) then
		self:_participant(player).inviteWhy = self.SSE.InviteReasons.Joined
	end
end

-- { "RingTake", id } (or an array of ids). Returns how many were taken.
function Core:RingTake(player: any, ids: any): number
	local R = self.SSE.Rings
	local list = if type(ids) == "table" then ids else { ids }
	local taken = 0
	for index = 1, math.min(#list, R.MaxIdsPerMessage) do
		if self:_takeRing(player, list[index]) then
			taken += 1
		end
	end
	return taken
end

function Core:_takeRing(player: any, id: any): (boolean, string?)
	local SSE, deps = self.SSE, self.deps
	local R = SSE.Rings
	local rings = self.rings
	local now = deps.now()
	local ring = nil
	if rings and type(id) == "number" and id == math.floor(id) then
		ring = rings.list[id]
	end
	local okPos, pos = pcall(deps.rootPosition, player)
	if not okPos then
		pos = nil
	end
	local okAlive, alive = pcall(deps.alive, player)
	local velocity = self:_velocity(player)
	local p = if rings then self:_participant(player) else nil
	local dx, dy, dz = nil, nil, nil
	if ring and pos then
		dx, dy, dz = pos.X - ring.pos.X, pos.Y - ring.pos.Y, pos.Z - ring.pos.Z
	end
	local ok, why = SSE.RingTakeCheck({
		exists = ring ~= nil,
		taken = ring ~= nil and ring.taken ~= nil,
		now = now,
		landAt = if rings then rings.landAt else INF,
		expireAt = if rings then rings.expireAt else -INF,
		alive = pos ~= nil and okAlive and alive == true,
		dx = dx,
		dy = dy,
		dz = dz,
		speed = if velocity then velocity.Magnitude else 0,
		count = if p then p.rings else 0,
	})
	if not ok then
		self.stats.ringRefused[why] = (self.stats.ringRefused[why] or 0) + 1
		self:_fireOne(player, { SSE.Messages.RingNo, id, why })
		return false, why
	end
	local userId = self:_userId(player)
	ring.taken = userId
	rings.taken += 1
	p.rings += 1
	self.ringsByUser[userId] = p.rings
	self.stats.ringsTaken += 1
	self:_setPlayer(player, SSE.PlayerAttributes.Rings, p.rings)
	self:_fireAll({ SSE.Messages.RingGone, id, userId })
	self:_pay(p, R.RewardWins, R.RewardSpeed, "ring")
	return true, nil
end

-- The rings' end: expired (everything left of their rewards is committed).
function Core:_ringStep(now: number)
	local rings = self.rings
	if rings and now > rings.expireAt then
		self.rings = nil
		for player, p in self.participants do
			self:_setPlayer(player, self.SSE.PlayerAttributes.Rings, nil)
			self:_flush(p, true)
		end
	end
end

-- The kill switch while only the rings are out: they go, and their rewards are committed.
function Core:ClearRings()
	if not self.rings then
		return
	end
	self:_clearRings()
	for _, p in self.participants do
		self:_flush(p, true)
	end
end

-- Every ring goes now (admin stop, kill switch, a new event).
function Core:_clearRings()
	local rings = self.rings
	if not rings then
		return
	end
	self.rings = nil
	self:_fireAll({ self.SSE.Messages.RingsClear, rings.eventId })
	for player in self.participants do
		self:_setPlayer(player, self.SSE.PlayerAttributes.Rings, nil)
	end
end

----------------------------------------------------------------------
-- 2026-09-26 (owner): v3. The trip to the event (Invite -> TeleportToEvent)
----------------------------------------------------------------------
-- The floor under a trip's candidate spot (walkable, near the centre's height; SSE.Teleport's bounds), or nil.
function Core:_spotFloor(candidate: Vector3, centre: Vector3): Vector3?
	local SSE, deps = self.SSE, self.deps
	local T = SSE.Teleport
	local probe = Vector3.new(candidate.X, centre.Y + T.ProbeUp, candidate.Z)
	local ok, hit, normalY
	if deps.spotGround then
		ok, hit, normalY = pcall(deps.spotGround, probe)
	elseif deps.ringGround then
		ok, hit, normalY = pcall(deps.ringGround, probe)
	else
		ok, hit = pcall(deps.ground, probe)
	end
	if not ok or hit == nil then
		return nil
	end
	if type(normalY) == "number" and normalY < T.MinNormalY then
		return nil
	end
	if hit.Y > centre.Y + T.MaxRise or hit.Y < centre.Y - T.MaxDrop then
		return nil
	end
	return hit
end

-- Where a trip lands (the root's position): the first TeleportCandidate round `centre` with floor that is clear
-- of the other players, of the spots handed out lately and of every falling bomb (SSE.SpotClear); else over the
-- centre.
function Core:_teleportSpot(player: any, now: number, centre: Vector3): Vector3
	local SSE = self.SSE
	local T = SSE.Teleport
	local others = {}
	for other, q in self.participants do
		if other ~= player and q.pos then
			table.insert(others, q.pos)
		end
	end
	local kept = {}
	for _, spot in self.recentSpots do
		if now - spot.at <= T.SpotMemory then
			table.insert(kept, spot)
			table.insert(others, spot.pos)
		end
	end
	self.recentSpots = kept
	local dangers = {}
	for _, bomb in self.bombs do
		table.insert(dangers, bomb.to)
	end
	for k = 1, T.Candidates do
		local floor = self:_spotFloor(SSE.TeleportCandidate(centre, k), centre)
		if floor and SSE.SpotClear(floor, others, dangers) then
			return Vector3.new(floor.X, floor.Y + T.Height, floor.Z)
		end
	end
	return Vector3.new(centre.X, centre.Y + T.Height, centre.Z)
end

-- A trip (TeleportToEvent, a beat's move): a spot round `centre`, then deps.teleport (it streams the spot in and
-- moves the character; `home` = a trip to the lobby: the world's own spawn trip first). Returns the spot.
function Core:_trip(p: any, now: number, centre: Vector3, home: boolean): Vector3
	local spot = self:_teleportSpot(p.player, now, centre)
	self:_tripTo(p, now, spot, home)
	return spot
end

-- { "TeleportToEvent", eventId? }: validated (SSE.CheckTeleport), then the trip (deps.teleport streams the spot
-- in and moves the character; TeleportArrived when it lands). Returns (true, position) or (false, reason) and
-- tells the player either way ({ TeleportGo, eventId, position } / { TeleportNo, reason }).
function Core:RequestTeleport(player: any, eventId: any): (boolean, any)
	local SSE, deps = self.SSE, self.deps
	local now = deps.now()
	local p = if self.running then self:_participant(player) else nil
	local okPos, pos = pcall(deps.rootPosition, player)
	if not okPos then
		pos = nil
	end
	local okAlive, alive = pcall(deps.alive, player)
	-- In a race by the race's own attributes (no position: standing in the empty race arena after the races
	-- were called off is no race).
	local okRace, racing = pcall(deps.racing, player, nil)
	local ok, reason = SSE.CheckTeleport({
		on = deps.isOn(),
		phase = if self.running then self.phase else SSE.Phases.None,
		sameEvent = eventId == nil or eventId == self.eventId,
		alive = pos ~= nil and okAlive and alive == true,
		racing = okRace and racing == true,
		afk = self:_afk(player),
		busy = p ~= nil and p.teleportUntil ~= nil and now < p.teleportUntil,
		lastAt = if p then p.lastTeleportAt else nil,
		now = now,
		inArena = pos ~= nil and self.running and self:_inEvent(pos),
	})
	if not ok then
		self.stats.teleportRefused[reason] = (self.stats.teleportRefused[reason] or 0) + 1
		self:_fireOne(player, { SSE.Messages.TeleportNo, reason })
		return false, reason
	end
	-- The spot: round the arena once everyone was moved there; before the Teleport beat, round the lobby spawn
	-- (the Cinematic plays there, and the beat takes them on with everyone).
	local centre = self:_centre()
	local spot = self:_teleportSpot(player, now, centre)
	p.lastTeleportAt = now
	p.inviteWhy = nil
	self.stats.teleports += 1
	self:_fireOne(player, { SSE.Messages.TeleportGo, self.eventId, spot })
	self:_tripTo(p, now, spot, centre == self.lobbyOrigin)
	return true, spot
end

-- A trip to a spot already chosen.
function Core:_tripTo(p: any, now: number, spot: Vector3, home: boolean)
	local SSE, deps = self.SSE, self.deps
	local player = p.player
	p.teleportUntil = now + SSE.Teleport.StreamSeconds + 1
	table.insert(self.recentSpots, { pos = spot, at = now })
	if deps.teleport then
		local id = self.eventId
		local function stillValid(): boolean
			return home or (self.running and self.eventId == id and SSE.InviteOpen(self.phase))
		end
		local function arrived()
			if self.running and self.eventId == id then
				self:TeleportArrived(player)
			end
		end
		local ok, err = pcall(deps.teleport, player, spot, stillValid, arrived, home)
		if not ok then
			self:_log("teleport failed: " .. tostring(err))
		end
	end
end

-- The trip landed: bombs spare the player for Teleport.SafeSeconds, and they take part from the next Step.
function Core:TeleportArrived(player: any)
	local p = self.participants[player]
	if not p then
		return
	end
	local now = self.deps.now()
	p.teleportUntil = nil
	p.safeUntil = now + self.SSE.Teleport.SafeSeconds
	p.knockedAt = -INF
	self.nextScanAt = -INF
	self.stats.arrivals += 1
end

----------------------------------------------------------------------
-- Rewards: batched DataService commits (the first at once, then at most every FlushSeconds)
----------------------------------------------------------------------
function Core:_flushes(now: number)
	for _, p in self.participants do
		if p.flushAt and now >= p.flushAt and not p.flushing then
			p.flushAt = nil
			self:_flush(p, false)
		end
	end
end

-- Commits what the player has earned and not yet committed, in one operation of its own
-- (sse:<jobId>:<eventId>:<userId>:<batch>, retried with the same id while Pending: never paid twice).
-- sync: commit in this thread (the before-release save); else in a new one.
function Core:_flush(p: any, _final: boolean, sync: boolean?)
	if p.flushing then
		p.flushAgain = true
		return
	end
	local wins, speed = p.pendingWins, p.pendingSpeed
	if wins <= 0 and speed <= 0 then
		return
	end
	local deps = self.deps
	p.pendingWins, p.pendingSpeed = 0, 0
	p.batches += 1
	p.flushAt = nil
	p.flushing = true
	p.lastFlushAt = deps.now()
	local operationId = string.format("sse:%s:%d:%d:%d", tostring(deps.jobId or "local"), self.eventId, self:_userId(p.player), p.batches)
	local function commit()
		local kind = "Rejected"
		for attempt = 1, COMMIT_RETRIES + 1 do
			local ok, result = pcall(deps.grant, p.player, wins, speed, operationId)
			kind = if ok then tostring(result) else "Rejected"
			if kind ~= "Pending" or attempt > COMMIT_RETRIES then
				break
			end
			if deps.wait then
				deps.wait(1)
			end
		end
		p.flushing = false
		if kind == "Committed" or kind == "AlreadyCommitted" then
			p.paidWins += wins
			p.paidSpeed += speed
		else
			p.lostWins += wins
			self:_log(("reward %s not committed (%s): %d Wins, %d Speed"):format(operationId, kind, wins, speed))
		end
		if p.flushAgain then
			p.flushAgain = false
			if self.running or self.rings then
				p.flushAt = p.lastFlushAt + self.SSE.Rewards.FlushSeconds
			else
				self:_flush(p, true)
			end
		end
	end
	if sync or not deps.spawn then
		commit()
	else
		deps.spawn(commit)
	end
end

----------------------------------------------------------------------
-- Players
----------------------------------------------------------------------
-- Died or respawned: the Super form (their own skin back), the charge and a homing attack in flight end
-- with that character.
function Core:CharacterReset(player: any)
	local p = self.participants[player]
	if not p then
		return
	end
	-- 2026-09-26 (owner): v3. A death inside a freeze window (+ its grace) is not the player's: Super again on
	-- respawn (_scan), the outro included.
	if self.running and p.super and self:_frozen(self.deps.now(), self.SSE.Freeze.FallGraceSeconds) then
		p.restoreSuper = true
		self.stats.frozenDeaths += 1
	end
	-- 2026-09-26 (owner): v3. A new character outside the event (a death in the arena respawns in the lobby) is
	-- invited again (_scan).
	if self.running and self.SSE.InviteOpen(self.phase) then
		p.inviteWhy = p.inviteWhy or self.SSE.InviteReasons.Respawn
	end
	p.teleportUntil = nil
	p.flight = nil
	p.chargeAt = nil
	if p.super then
		self:_unSuper(p)
	end
	p.eligible = false
end

-- The before-release save (Bootstrap's SpeedsterBeforeRelease): commits what is left, in this thread.
function Core:FlushSync(player: any)
	local p = self.participants[player]
	if p then
		self:_flush(p, true, true)
	end
end

-- Left the server: what is left is committed, and the player is forgotten.
function Core:PlayerRemoving(player: any)
	self.buckets[player] = nil
	self.invited[player] = nil
	local p = self.participants[player]
	if not p then
		return
	end
	p.flight = nil
	p.chargeAt = nil
	p.super = false
	p.saved = nil
	self:_flush(p, true, true)
	self.participants[player] = nil
end

function Core:Status(): any
	local supers, eligible = 0, 0
	for _, p in self.participants do
		if p.super then
			supers += 1
		end
		if p.eligible then
			eligible += 1
		end
	end
	return {
		running = self.running,
		phase = self.phase,
		phaseStart = self.phaseStart,
		eventId = self.eventId,
		seed = self.seed,
		hp = self.hp,
		maxHp = self.maxHp,
		peak = self.peak,
		bossState = self.bossState,
		supers = supers,
		eligible = eligible,
		bombs = self.stats.bombs,
		knocks = self.stats.knocks,
		hits = self.stats.hits,
		damage = self.stats.damage,
		rings = if self.rings then #self.rings.list else 0,
		ringsTaken = self.stats.ringsTaken,
		-- 2026-09-26 (owner): v3
		racesClosed = self.racesClosed,
		arena = self.split,
		moved = self.moved,
		movedOut = self.movedOut,
		pulled = self.stats.pulled,
		invites = self.stats.invites,
		teleports = self.stats.teleports,
		shieldBounces = self.stats.shieldBounces,
		crashPoint = self.crashPoint,
	}
end

return Core
