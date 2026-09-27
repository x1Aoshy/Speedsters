--!strict
-- ReplicatedStorage/Shared/SuperSonicEvent.luau — the "Super Sonic vs Dr. Eggman" live event: the one
-- contract the server (Gameplay/SuperSonicEventService + SuperSonicEventCore), the clients (the event's
-- presentation) and the Lune tests share. Pure data + pure functions: nothing yields, connects, tweens or
-- touches the DataModel when it is required (IsOn reads one Workspace attribute when it is called in game).
-- 2026-09-26 (owner): the event. An admin starts it from the Admin Abuse panel ("Super Sonic vs Eggman").
-- 2026-09-26 (owner): v2 after the owner tested v1 — a boss fight with Attack / Reload windows, charged
-- homing attacks, the game's real Super Sonic skin, no Flight during the event, the opening and closing
-- cinematics with dialogue cues, aggressive missiles (Aimed / Parallel / Rain), much more boss HP scaling
-- with the participants, lower rewards per hit with a higher cap, and a rain of gold rings at the defeat.
-- 2026-09-26 (owner): v3 after the owner's next tests (v2's names are kept where they still mean something;
-- what changed is marked "v3"):
--   * THE FIGHT MOVES TO THE RACE MAP (the lobbies, World 2's above all, are too small). The Cinematic still
--     plays in the LOBBY (Eggman lifts off from his lobby spot, his lines, then leaves), a Teleport beat moves
--     everyone in the lobby area (and anyone who accepted the invite) to the Green Hill race arena
--     (Workspace.RaceArena, the same in the three worlds; "just the plain map": the clients hide the race-only
--     pieces), Eggman flies into the arena, the fight, the Defeat (a crash on the track, the rings on the track
--     floor) or the Escape, then a Return beat moves everyone still in the arena back to their world's lobby
--     spawn, where the lobby Eggman is back at his spot. SSE_Origin = the arena point (ArenaOrigin: the track
--     at s = RaceArena.TrackS, a flat stretch; the server drops it on the floor), SSE_LobbyOrigin = the world's
--     lobby spawn. The event's area is the arena corridor (InArena: a box round SSE_Origin) and, until the
--     Teleport beat has moved everyone, the lobby too (InLobby); InEventArea says which applies. While the
--     event runs the arena's StartGate / StopBar collide with nobody (restored after), no race runs (so no
--     race spikes, pads or validation), and Flight stays off there. A place without Workspace.RaceArena keeps
--     the whole fight in the lobby (SSE_Origin = SSE_LobbyOrigin; the beats move nobody).
--   * RACES CLOSE DURING THE EVENT. At the start the server calls off every race heat (gathering / staging /
--     countdown / running / results) through the race service, with no penalty (no DNF, no idle-DNF strike, no
--     rejoin cooldown; only the aborted race pays nothing), sends the race arena's players to their lobby spawn
--     (the Teleport beat then takes them to the fight) and closes the race queue and the Race Gate until the
--     event ends or stops. Workspace attribute RaceClosed.Attribute ("RaceClosedBy") = RaceClosed.Reason
--     ("SuperSonicEvent") meanwhile (nil = open): the gate's holo board / the race HUD show "closed during the
--     event" while it is set. A Join is refused with the toast RaceClosed.Refusal ("RaceEventClosed"); the
--     players pulled out of a queue get RaceEvent { kind = "Unqueued", reason = "Event" }.
--   * INVITE + TELEPORT. Until the Defeat / Escape, every player who is not in the event gets { "Invite",
--     eventId, why }: at the start (outside the lobby area: the stages, far away), when they join the server,
--     when they respawn outside the arena (a death in the arena respawns in the lobby) and when they leave the
--     arena (at most one every Invite.MinGapSeconds). Their world stays normal until they accept. The client
--     shows an optional prompt while InviteOpen(SSE_Phase) holds (it closes it when the phase moves on, when
--     SSE_EventId changes, or when its own root is InEventArea). YES sends { "TeleportToEvent", eventId }:
--     CheckTeleport (running and before the Defeat, the kill switch, alive, not racing, not AFK, not already
--     travelling, Teleport.Cooldown, not already in the event) -> { "TeleportGo", eventId, position } (the
--     server streams the spot in and moves the character there within Teleport.StreamSeconds: a free spot on
--     the floor near the fight - the lobby spawn before the Teleport beat, the arena after -, clear of other
--     players and of every falling bomb) or { "TeleportNo", reason } (TeleportRefusals). They take part like
--     anyone there: Super at the absorption, or at once when it is past (LateTransform), no Flight.
--   * FREEZE WINDOWS. FreezeWindows[phase] = { Start, End, Area } (seconds into that phase): the Cinematic, the
--     Teleport beat's fade, the Emeralds shot, the Defeat's crash, the Escape's outro and the Return beat. The
--     clients freeze their own player there (velocity 0, no movement) while FreezesHere says so (its root in
--     that window's Area); nobody elsewhere is frozen. The server throws nobody then (a bomb still lands and
--     bursts), puts a participant who drops off the floor back at the fight's centre, and a death inside a
--     window (+ Freeze.FallGraceSeconds) costs no Super form: Super again on respawn (once back in the event).
--   * HOMING like the Sonic games. A simple mid-air jump press fires an uncharged attack: { "Homing", t } with no
--     "Charge" before it (or { "Homing", t, 0 }) = charge 0, damage 1; the charged path (F held) stays, with the
--     full charge in Homing.ChargeSeconds = 0.7 s (the charge sound may play on). A "Charge" press older than
--     Homing.ChargeStaleSeconds at the release no longer counts. The attack is FAST (Homing.Speed 320 studs/s)
--     along a tighter curve (Lift / Swing): a snappy dash. An attack that would reach the ship while its SHIELD
--     is up (arrival outside every Reload window) flies (HomingGo with shielded = true) and at its arrival
--     bounces off: no damage, the attacker gets { "HomingNo", "Shielded" } and { "Knock", velocity, 0, "Shield" }
--     (ShieldKnock: Shield.KnockOut studs/s away from the ship + Shield.KnockUp up; no ragdoll, never a kill),
--     everyone gets { "ShieldHit", userId, pos }, the attack's cooldown is spent, the attacker "stunned" for
--     Shield.StunSeconds. Space-in-air Flight stays off in the event (EventFlightBlocked, below).
--   * THE DEFEAT ALWAYS HAPPENS AT 0 HP, AND IT IS A CRASH. The owner saw him escape every time with little HP
--     left: v2's HP (66 for one player) was more than a player attacking without charging could deal in the
--     Battle's ~64 s of Reload windows with the bombs throwing them about, and an attack still flying at the
--     timeout was dropped. v3: HP from a lower base (HP below), the Escape waits for the attacks in flight
--     (Homing.MaxFlightSeconds), a hit that empties the bar always defeats him, and attacks flying at the defeat
--     still land (and pay). The Defeat is a crash onto the track (Crash; CrashPath through BossCFrame with the
--     plan's crashPoint, CrashTimes, SSE_CrashPoint), the rings burst out of the crash point, no dialogue.
--
-- Timeline (seconds; Durations below). Every phase start is exact: EventStart + the durations before it,
-- except Defeat / Escape (Defeat when the HP reaches 0; Escape when the Battle runs out) and what follows.
--   Cinematic  7.5  IN THE LOBBY: Eggman lifts off from his lobby spot (Workspace.LobbyCharacters.Eggman:
--                   SSE_LiftOff) while taunting (Dialogue "EggmanSonic" at 0.8, "EggmanRevenge" at 3.9), then
--                   flies up and away (Boss.LeaveAt).
--   Teleport   4.5  (v3) the beat (Beats.Teleport): the screens fade out by 0.6, the server moves the lobby's
--                   players to the arena at 0.6 (spread on free floor round SSE_Origin), the screens fade back
--                   in by 1.4 while Eggman flies into the arena (Boss.EntryFrom -> his orbit by the phase's end).
--   Bombard    9.5  3 salvos (Aimed, Parallel, Aimed) at the players on the ground, before they transform.
--   Emeralds   7    the 7 Chaos Emeralds orbit and are absorbed at 5.2: participants turn Super Sonic.
--   Battle   150    Eggman alternates ATTACK windows (salvos, strafes, dives; he is shielded) and RELOAD
--                   windows (low, slow hover, cannon in: the ONLY time homing attacks damage). Schedule below.
--   Defeat    20    HP 0: (v3) the ship CRASHES onto the track (SSE_CrashPoint; Crash: a spiralling dive of
--                   2.4 s), explodes, the gold rings burst out of the crash point and land on the track floor,
--                   the wreck fades out; then the rings can be taken until the phase ends. No dialogue.
--                   HP 0 always wins over the timeout (above).
--   Escape     7    the Battle ran out: he laughs ("EggmanEscape" at 0.4), the goodbye at 1.2, holds 2.0 s and
--                   flies away. Nothing is paid for the escape itself.
--   Return     2.5  (v3) the beat (Beats.Return): the screens fade out by 0.6, the server moves everyone still in
--                   the arena to their world's lobby spawn at 0.6 (the rings left go), the lobby Eggman fades in
--                   at his spot from 0.6, the screens fade back in by 1.4. Then the event ends.
--   Old name kept: Phases.Intro == "Cinematic" (and Durations.Intro); NormalizePhase("Intro") = "Cinematic".
--
-- Protocol
--   Workspace attributes (server writes, clients read):
--     SSE_Phase       "" | "Cinematic" | "Teleport" | "Bombard" | "Emeralds" | "Battle" | "Defeat" | "Escape"
--                     | "Return"   ("" = none)
--     SSE_PhaseStart  workspace:GetServerTimeNow() when the phase began
--     SSE_EventStart  (v2) the Cinematic's start: the boss path's clock (Plan.start)
--     SSE_EventId     a number, new for every event (clients reset their state when it changes)
--     SSE_Seed        the event's seed (the Battle schedule, the path's variety, the rings)
--     SSE_Origin      Vector3: the fight's centre: (v3) the arena point on the track floor (the lobby spawn in a
--                     place without the race arena)
--     SSE_LobbyOrigin (v3) Vector3: this world's lobby spawn (the Cinematic's lobby, where everyone goes back)
--     SSE_LiftOff     (v2) Vector3: the Egg Mobile's hull centre at its lobby spot, where the Cinematic starts
--                     (absent: Boss.DefaultLiftOff over the lobby spawn)
--     SSE_BossHP / SSE_BossMaxHP   the Egg Mobile's hit points (set for real when the Battle begins; the max
--                     grows when more participants turn Super during the Battle, HP.GrowWithLateJoiners)
--     SSE_BossState   (v2, Battle only, else nil) "Attack" | "Reload": a mirror of BossState for simple clients
--     SSE_BossStateStart / SSE_BossStateEnd   (v2) server times of that window ("Hurt" flashes are client-only)
--     SSE_CrashPoint  (v3, from the Defeat) Vector3: where the Egg Mobile crashes (set before SSE_Phase =
--                     "Defeat"; PlanFromAttributes reads it: BossCFrame then follows the crash)
--     SSE_EndStart / SSE_Outcome   (v3, from the Defeat / Escape) its start and "Defeat" | "Escape" (the Return
--                     phase's plan still needs them)
--   Player attributes (server writes):
--     SSE_Super       true while the player is Super Sonic (the emerald absorption turns it on)
--     SSE_Skin        (v2) "SuperSonicSuit" while the game's real Super Sonic skin is worn for the event (the
--                     client then stops drawing the old gold glaze); nil if the skin could not be put on.
--                     The live truth is SkinOverride (Economy/SkinSystem): it clears at once if the player
--                     equips a skin of their own meanwhile. EquippedSkin never changes (nothing is saved).
--     SSE_Hits        the player's homing hits on the ship this event
--     SSE_Rings       (v2) gold rings this player collected this event
--     SSE_WalkSpeed   the Super Sonic walk speed floor while Super (Movement/InstantMovementController)
--     EventFlightBlocked (Shared/RaceNoFlight.EventAttribute) "SuperSonicEvent" while the player is in the
--                     event (InEventArea): the Flight ability is off ("Flying is off during the event")
--   ReplicatedStorage.Remotes.SuperSonicEvent (RemoteEvent). Every message is ONE array argument.
--     server -> clients
--       { "Bomb", id, fromPos, toPos, launchTime, flightTime, pattern, radius }   a bomb leaves the cannon.
--             (v2) pattern "Aimed" | "Parallel" | "Rain"; radius = the blast / red-zone radius. The RED ZONE is
--             the circle of `radius` around toPos, shown from launchTime to launchTime + flightTime (= its fall;
--             never less than Warning.MinSeconds in the Battle, Warning.BombardMinSeconds in the Bombard).
--       { "BombHit", id, pos }                                  it lands: blast + fire patch
--       { "Hit", userId, pos, hp, maxHp, damage, charge, recoil }   a homing attack hit the ship; pos =
--             BossPosition at the arrival; (v2) damage 1..3, charge 0..1, recoil = BossRecoil(charge) studs
--       { "Reward", wins, speed, kind }                          what it paid (the earner only); (v2) kind
--             "hit" | "ring". Hits past Rewards.MaxRewardedHits still land and damage, but pay nothing.
--       { "Defeat", crashPoint, impactTime }                     the ship breaks (the Defeat phase begins); (v3)
--             it crashes at crashPoint (= SSE_CrashPoint) at impactTime (CrashTimes(defeatStart).impact)
--       { "HomingGo", userId, fromPos, toPos, launchTime, duration, charge, damage, shielded }   an accepted
--             homing attack: toPos = where the ship WILL be at launchTime + duration (HomingIntercept); (v2)
--             charge, damage; (v3) shielded = true: it will bounce off the shield at its arrival (damage 0)
--       { "HomingNo", reason }                                   the requester's attack was refused
--             (reason: one of HomingRefusals; the client plays Eggman's taunt on "Shielded", Taunts.Shielded).
--             v3: "Shielded" comes AT THE ARRIVAL of a shielded attack (with the "Knock" below).
--       { "ShieldHit", userId, pos }                            (v3) an attack bounced off the shield at pos (the
--             ship's position at the arrival): every client may flash the shield there
--       { "Escape" }                                             the Battle timed out (the Escape phase begins)
--       { "Knock", velocity, seconds, kind }                     the victim's own client: a bomb threw it (set
--             HumanoidRootPart.AssemblyLinearVelocity = velocity; the server ragdolls it). (v2) Super players are
--             thrown too in the Battle (Battle.SuperRagdollSeconds); a throw cancels their charge and flight.
--             (v3) kind "Bomb" | "Shield"; seconds 0 = no ragdoll (the shield's bounce: just the velocity)
--       { "Invite", eventId, why }                               (v3) the event invites this player: an optional
--             prompt; why = InviteReasons ("start" | "race" | "joined" | "respawn" | "left")
--       { "TeleportGo", eventId, position }                      (v3) the trip is on: the root lands at position
--       { "TeleportNo", reason }                                 (v3) the trip was refused (TeleportRefusals)
--       { "Rings", eventId, positions, landTime, expireTime, fromPos, takenIds, burstTime }   (v2) the defeat's
--             ring rain: ring id = its index in positions (landed centres); they fall from fromPos, land at
--             landTime, can be taken from then until expireTime (then they fade). takenIds: ids already gone (a
--             late joiner gets this message too). (v3) fromPos = the crash point + Crash.RingsUp; they burst out
--             of it at burstTime (the impact + Crash.RingsDelay) and fly Crash.RingsFly to land at landTime;
--             they expire before the Return beat.
--       { "RingGone", id, userId }                               (v2) a ring was taken: remove it everywhere
--       { "RingNo", id, reason }                                 (v2) the requester's take was refused
--             (reason: RingRefusals; "gone" = remove it, "cap" = this player may take no more, it stays)
--       { "RingsClear", eventId }                                (v2) every ring goes now (admin stop, kill switch,
--             the Return beat)
--     client -> server
--       { "Charge", clientTime }            (v2) F / the button PRESSED: the server stamps its own receive time
--       { "Homing", clientTime, charge01? } RELEASED: request a homing attack. The server measures the charge
--             itself (MeasureCharge: receive times, clamped 0..1 over Homing.ChargeSeconds, at most charge01
--             when the client sends it). No "Charge" first = charge 0. clientTime = the client's
--             workspace:GetServerTimeNow() at the release. (v3) The mid-air jump press sends it with no
--             "Charge" before it (or charge01 = 0): an uncharged attack, damage 1.
--       { "RingTake", id }                  (v2) take ring `id` (or an array of up to Rings.MaxIdsPerMessage ids)
--       { "TeleportToEvent", eventId? }     (v3) YES on the Invite prompt: take me to the event
--     Rate limit: RateLimit (a token bucket per player); messages over it are dropped.
--
-- The Battle schedule (Battle below; deterministic from the Battle's start + SSE_Seed):
--   BossWindows(seed) -> { {state, start, finish, index} }, phase times (seconds since the Battle began):
--   Attack 5 s first, then Reload 5.5..6.5 s / Attack 7..9 s alternating (seeded lengths) until 150 s.
--   BossState(phaseTime, seed) -> "Attack" | "Reload", start, finish.
--   A homing hit counts only when its ARRIVAL is inside a Reload window, +- Battle.HitGrace (0.15 s):
--   BossVulnerable(phaseTime, seed). Salvos: BattleSalvos(seed) (only in Attack windows; the gap shrinks
--   2.6 s -> 1.5 s as the fight goes on, the 2nd salvo of each window is a Parallel line). Dives:
--   BossDives(seed) (one per Attack window from the 2nd on).
--
-- The boss path: BossCFrame(origin, t, plan) with plan = Plan(eventStart, seed, liftOff?, endStart?, outcome?,
-- crashPoint?, lobbyOrigin?) (or PlanFromAttributes(getter)): a pure function of the server time, C1 within
-- each place: in the lobby (the lift-off from his spot, the taunts, the departure) until the Teleport beat's
-- move, then in the arena (the entrance, strafes and dives in Attack, a low slow hover in Reload, over the
-- track: the orbit is squeezed across it by Boss.OrbitScaleX; the crash or the flight away after endStart). The
-- old forms BossCFrame(origin, t) / BossCFrame(origin, t, introStartNumber) still give the v1 hover (legacy).
--
-- Boss HP (HP below): v3 round(34 x participants^0.95), 34..3000 (v2: 66 x ...). Participants = Super players when
-- the Battle begins (more later: the max grows). See HP for what a lobby deals.
--
-- Pure helpers (both sides)
--   NormalizePhase / IsPhase / NextPhase / PhaseDuration / PhaseOffset
--   Plan / PlanFromAttributes / BossOffset / BossCFrame / BossPosition / BossVelocity / CannonPosition
--   BossWindows / BossState / BossVulnerable / BattleSalvos / BossDives / BossMaxHP
--   BombsPerSalvo(players) (Bombard) / BattleBombsPerSalvo(players, window) / BombFlightTime(from, to, battle?)
--   BombArc / InBlast / Knockback / LeadPoint / ParallelOffsets
--   EmeraldOrbit / EmeraldOffset
--   HomingPath / HomingLength / HomingDuration / HomingIntercept / HomingBounce(look, charge?)
--   MeasureCharge / HomingDamage / BossRecoil / RewindTime / CheckHoming / ShieldKnock (v3)
--   RingCount / RingScatter / RingTakeCheck
--   CrashPath / CrashTimes / CrashCandidate (v3)
--   DialogueFor(phase)
--   FreezeWindow / IsFrozen / FreezesHere (v3)
--   InviteOpen / Moved / CheckTeleport / TeleportCandidate / SpotClear (v3)
--   ArenaOrigin / InArena / InLobby / InEventArea (v3)
--   WorldKey / PickSpawn / WorldOrigin / IsOn
local Vector3, CFrame = Vector3, CFrame
if Vector3 == nil or CFrame == nil then
	local lateRequire: any = require
	local ok, roblox = pcall(lateRequire, "@lune/roblox")
	if ok and type(roblox) == "table" then
		Vector3, CFrame = roblox.Vector3, roblox.CFrame
	end
end

local SSE = {}

SSE.Version = 3 -- 2026-09-26 (owner): v3 (the fight in the race arena, races closed, invites + trips, freeze windows, fast homing, shield bounce, the crash)
SSE.Feature = "SuperSonicEvent"
SSE.Enabled = true -- the code flag; the live switch is the Workspace attribute below
SSE.KillAttribute = "U4Off_SuperSonicEvent" -- Workspace attribute: true stops a running event and refuses new ones
SSE.RemoteName = "SuperSonicEvent"
SSE.RemotesFolder = "Remotes" -- ReplicatedStorage.Remotes, where the game's other remotes live
SSE.AssetsFolder = "SuperSonicEventAssets" -- ReplicatedStorage.SuperSonicEventAssets { VFX, Meshes } (the build)
SSE.VfxNames = { BombExplode = "BombExplode", EggImpact = "EggImpact", FireTrail = "FireTrail", BurstHatch = "BurstHatch" }
SSE.AdminEventKey = "SuperSonic" -- the Admin Abuse panel's event button / command
SSE.ApiName = "SpeedsterSuperSonicEvent" -- _G.SpeedsterSuperSonicEvent.Start(byName?) / .Stop() / .IsRunning() / .IsAvailable() / .Status()

----------------------------------------------------------------------
-- Protocol names
----------------------------------------------------------------------
-- 2026-09-26 (owner): "Cinematic" replaced v1's "Intro" (Phases.Intro stays as an alias of the new name).
SSE.Phases = {
	None = "",
	Cinematic = "Cinematic",
	Intro = "Cinematic", -- v1 name, kept: the opening is the Cinematic now
	Bombard = "Bombard",
	Emeralds = "Emeralds",
	Battle = "Battle",
	Defeat = "Defeat",
	Escape = "Escape",
	Teleport = "Teleport", -- v3: the beat that moves the lobby to the race arena
	Return = "Return", -- v3: the beat that moves the arena back to the lobby (then the event ends)
}
-- v3: Escape replaces Defeat on a timeout; Return follows either.
SSE.PhaseOrder = { "Cinematic", "Teleport", "Bombard", "Emeralds", "Battle", "Defeat", "Return" }
SSE.EndPhases = { Defeat = true, Escape = true }

SSE.Attributes = {
	Phase = "SSE_Phase",
	PhaseStart = "SSE_PhaseStart",
	EventStart = "SSE_EventStart", -- v2
	EventId = "SSE_EventId",
	Seed = "SSE_Seed",
	BossHP = "SSE_BossHP",
	BossMaxHP = "SSE_BossMaxHP",
	Origin = "SSE_Origin",
	LiftOff = "SSE_LiftOff", -- v2
	BossState = "SSE_BossState", -- v2
	BossStateStart = "SSE_BossStateStart", -- v2
	BossStateEnd = "SSE_BossStateEnd", -- v2
	CrashPoint = "SSE_CrashPoint", -- v3: the Defeat's crash point on the track floor (Vector3; from the Defeat)
	LobbyOrigin = "SSE_LobbyOrigin", -- v3: the world's lobby spawn (SSE_Origin is the arena point)
	EndStart = "SSE_EndStart", -- v3: the Defeat / Escape's start (kept through the Return)
	Outcome = "SSE_Outcome", -- v3: "Defeat" | "Escape" (kept through the Return)
}
SSE.PlayerAttributes = {
	Super = "SSE_Super",
	Hits = "SSE_Hits",
	WalkSpeed = "SSE_WalkSpeed",
	Skin = "SSE_Skin", -- v2
	Rings = "SSE_Rings", -- v2
}

SSE.Messages = {
	-- server -> client
	Bomb = "Bomb",
	BombHit = "BombHit",
	Hit = "Hit",
	Reward = "Reward",
	Defeat = "Defeat",
	HomingGo = "HomingGo",
	HomingNo = "HomingNo",
	Escape = "Escape",
	Knock = "Knock",
	Rings = "Rings", -- v2
	RingGone = "RingGone", -- v2
	RingNo = "RingNo", -- v2
	RingsClear = "RingsClear", -- v2
	ShieldHit = "ShieldHit", -- v3
	Invite = "Invite", -- v3
	TeleportGo = "TeleportGo", -- v3
	TeleportNo = "TeleportNo", -- v3
	-- client -> server
	Charge = "Charge", -- v2
	Homing = "Homing",
	RingTake = "RingTake", -- v2
	TeleportToEvent = "TeleportToEvent", -- v3
}
-- Why a homing request was refused (the HomingNo message's reason).
SSE.HomingRefusals = {
	Phase = "phase", -- not in the Battle
	NotSuper = "notSuper",
	Dead = "dead",
	Racing = "racing",
	Stunned = "stunned", -- v2: a bomb just threw the player (Battle.SuperRagdollSeconds)
	Busy = "busy", -- the previous homing attack is still flying
	Cooldown = "cooldown",
	Cap = "cap", -- v1 only: v2 lets hits past the cap land (unpaid), so the server no longer sends it
	Range = "range",
	Shielded = "Shielded", -- v2: the arrival is outside every Reload window (Eggman's shield is up); v3: sent at
	-- the arrival of the shielded attack (it bounced off), with the shield's Knock
	Off = "off", -- the kill switch
}
SSE.RingRefusals = { Gone = "gone", Early = "early", Dead = "dead", Far = "far", Cap = "cap" }
SSE.BombPatterns = { Aimed = "Aimed", Parallel = "Parallel", Rain = "Rain" }
SSE.BossStates = { Attack = "Attack", Reload = "Reload" }
-- 2026-09-26 (owner): v3. The Knock message's kind (4th field).
SSE.KnockKinds = { Bomb = "Bomb", Shield = "Shield" }
-- Why an Invite was sent (its 3rd field).
SSE.InviteReasons = { Start = "start", Race = "race", Joined = "joined", Respawn = "respawn", Left = "left" }
-- At most one Invite a player every MinGapSeconds (a player on the arena's edge, a quick death loop).
SSE.Invite = { MinGapSeconds = 3 }
-- Why a TeleportToEvent was refused (the TeleportNo message's reason), in CheckTeleport's order.
SSE.TeleportRefusals = {
	Off = "off", -- the kill switch
	Phase = "phase", -- no event, the Defeat / Escape already, or another event's id
	Dead = "dead",
	Racing = "racing",
	Afk = "afk",
	Busy = "busy", -- a trip is already on its way
	Cooldown = "cooldown",
	Here = "here", -- already in the event's area (the client just closes its prompt)
}

-- 2026-09-26 (owner): v3. The races close while the event runs (Services/Race/RaceService Close / Reopen through
-- _G.SpeedsterRace). Attribute: the Workspace attribute the race writes (Reason while closed, nil when open);
-- Unqueued: the RaceEvent Unqueued reason of the players it pulled out; Refusal: the Join toast key.
SSE.RaceClosed = { Attribute = "RaceClosedBy", Reason = "SuperSonicEvent", Unqueued = "Event", Refusal = "RaceEventClosed" }

----------------------------------------------------------------------
-- Config (seconds, studs, studs/s)
----------------------------------------------------------------------
-- Phase lengths. Battle is the longest it may last: the ship escapes when it runs out (boss HP left).
-- 2026-09-26 (owner): v3: the Teleport and Return beats; the Defeat holds the ring collection on the track.
SSE.Durations = { Cinematic = 7.5, Intro = 7.5, Teleport = 4.5, Bombard = 9.5, Emeralds = 7, Battle = 150, Defeat = 20,
	Escape = 7, Return = 2.5 }

-- 2026-09-26 (owner): v3. The beats (seconds into their phase). The clients fade their screen out from 0 to
-- FadeOut and back in from MoveAt to FadeIn; the server moves the players at MoveAt: Teleport, everyone in the
-- lobby area to the arena (Moved from then on); Return, everyone in the arena to their world's lobby spawn.
-- Teleport.EntryStart: Eggman's entrance into the arena starts (from Boss.EntryFrom; in his orbit at the
-- phase's end). Return.LobbyEggman: the lobby Eggman fades back in at his spot over LobbyEggmanFade.
SSE.Beats = {
	Teleport = { FadeOut = 0.6, MoveAt = 0.6, FadeIn = 1.4, EntryStart = 0.6 },
	Return = { FadeOut = 0.6, MoveAt = 0.6, FadeIn = 1.4, LobbyEggman = 0.6, LobbyEggmanFade = 1.0 },
}

-- 2026-09-26 (owner): the cinematics' lines, as keys only (the client owns the texts and the audio). Each
-- entry: { phase, seconds into that phase, key }. "EggmanSonic" = "Sonic! ...", "EggmanRevenge" = "I'll have my
-- revenge!", "EggmanBeBack" = "This is not the end. I will be back... I promise." (the owner's recording:
-- Sounds.EggmanBeBack); "EggmanDefeat" / "EggmanEscape" are optional short cries (the client may skip a key it
-- has no line for).
-- 2026-09-26 (owner): v3: NO dialogue in the Defeat (the crash speaks for itself); the Escape keeps his goodbye.
SSE.Dialogue = {
	{ "Cinematic", 0.8, "EggmanSonic" },
	{ "Cinematic", 3.9, "EggmanRevenge" },
	{ "Escape", 0.4, "EggmanEscape" },
	{ "Escape", 1.2, "EggmanBeBack" },
}
-- 2026-09-26 (owner): the event's audio, uploaded by the owner (the client plays them).
SSE.Sounds = {
	Music = "rbxassetid://133261865867143", -- "Eggman's Revenge": loops for the whole event
	RingPickup = "rbxassetid://112771432761858", -- a ring taken (the taker's client; RingGone)
	RingsDrop = "rbxassetid://102136054782395", -- the rings raining down (the "Rings" message)
	EggmanBeBack = "rbxassetid://103892608635163", -- "This is not the end. I will be back... I promise." (Defeat / Escape)
	Charge = "rbxassetid://93126470207724", -- the homing charge (Homing.ChargeSeconds)
}
-- Dialogue keys that have a recording (the rest are the client's own text / audio).
SSE.DialogueSounds = { EggmanBeBack = "EggmanBeBack" } -- key -> SSE.Sounds entry
-- Keys the client may play on its own triggers: a "Shielded" refusal, SSE_BossState turning Reload / Attack.
SSE.Taunts = { Shielded = "EggmanShielded", Reload = "EggmanReload", Attack = "EggmanAttack" }

SSE.Boss = {
	-- v2 path (Plan / BossCFrame with a plan). Heights over the origin, radii from it (horizontal).
	Height = 72, -- the Attack windows' cruise height (and the Bombard's)
	ReloadHeight = 34, -- Reload: lower, reachable
	DiveHeight = 24, -- the bottom of a dive toward the players
	OrbitRadius = 46, -- Attack: the orbit around the spawn, +- OrbitWobble
	OrbitWobble = 10,
	OrbitWobblePeriod = 7.3,
	ReloadRadius = 24, -- Reload: a small slow circle, +- ReloadWobble
	ReloadWobble = 3,
	ReloadWobblePeriod = 9.1,
	DiveRadius = 14,
	DiveSeconds = 3.2, -- one dive (a sin^2 bump) per Attack window from the 2nd on
	DiveLead = 1.2, -- a dive starts at least this long into its window
	DiveTail = 0.8, -- ...and ends at least this long before the window closes
	DiveMinWindow = 6.5,
	OrbitPeriod = 34, -- one lap of the base orbit (the ship's slow drift around the spawn)
	StrafeAngle = 0.55, -- Attack: sideways sweeps of +- this many radians around the orbit
	StrafePeriod = 5.6,
	EmeraldsStrafe = 0.35, -- the strafe's strength while the players transform
	Ramp = 1.0, -- every change of motion (Attack <-> Reload, the phases) eases over this long (C1)
	BobHeight = 2.2,
	BobPeriod = 4.6,
	ReloadBob = 1.2,
	ReloadBobPeriod = 6.2,
	NosePitch = -6, -- degrees: nose a little down, toward the players
	ReloadPitch = -2,
	DivePitch = -16, -- more nose-down at the bottom of a dive
	PitchWobble = 2.5,
	RollWobble = 4,
	Bank = 14, -- degrees of roll at the fastest strafe
	-- The Cinematic: up LiftRise from the lift-off point (LiftHold s), then into the hover (LiftBlend s).
	LiftRise = 18,
	LiftHold = 2.2,
	LiftBlend = 4.8,
	DefaultLiftOff = { 0, 60, 140 }, -- no lobby Eggman: he comes from here (offset from the lobby spawn)
	-- 2026-09-26 (owner): v3. In the lobby he lifts off (LiftRise over LiftHold, facing the lobby spawn), hovers
	-- with his lines, and from LeaveAt (Cinematic time) flies up and away for LeaveSeconds (LeaveRise up,
	-- LeaveOut away from the spawn, turning round): gone by the Teleport beat's fade. In the arena he enters from
	-- EntryFrom (offset from SSE_Origin: high, down the track) at Beats.Teleport.EntryStart and eases into his
	-- orbit by the Bombard. OrbitScaleX squeezes every x offset of the arena path (the orbit, the Reload circle,
	-- the dives: an ellipse along the track) so he stays over the 72-stud corridor.
	LeaveAt = 5.6,
	LeaveSeconds = 2.5,
	LeaveRise = 160,
	LeaveOut = 260,
	EntryFrom = { 0, 110, -380 },
	OrbitScaleX = 0.6,
	-- Defeat / Escape (plan.endStart): drift on (EscapeDrag), hold (DefeatHold / EscapeHold), fly away.
	EscapeDrag = 1.6,
	DefeatHold = 2.8,
	EscapeHold = 2.0,
	DefeatSink = 8,
	DefeatSpins = 1,
	DefeatWobble = 16, -- degrees of roll while smoking
	EscapeFlySeconds = 3.6,
	EscapeRise = 180,
	EscapeOut = 320,
	EscapePitch = 18, -- degrees nose up while flying away
	-- v1 (legacy BossCFrame(origin, t [, introStart])): the ellipse hover and the fly-in.
	PathRadiusX = 38,
	PathRadiusZ = 26,
	PathPeriod = 28,
	FlyInSeconds = 5,
	FlyInFrom = { 0, 140, 340 },
	HitRadius = 9, -- the client ends a homing attack this far short of the ship's centre (its hull)
	-- 2026-09-26 (owner): the clients draw the lobby's Egg Mobile at DrawScale (its hull, radius 3.86 x 2.2 = 8.5,
	-- meets HitRadius) with the Blender kit's Cannon under its bowl (design/event/supersonic/event_manifest.json:
	-- the barrel points 20 degrees down; a bomb spawned at its "spawn" point clears the barrel). Cannon = that
	-- spawn point (hull space (0, -2.5886, -7.4152) at scale 1) times DrawScale, in the ship's space from its
	-- centre (forward -Z): the server's bombs leave the drawn muzzle.
	DrawScale = 2.2,
	Cannon = { 0, -2.5886 * 2.2, -7.4152 * 2.2 },
}

-- 2026-09-26 (owner): v3. The defeat: "the Egg Mobile CRASHES to the ground like a plane out of control (a
-- spiralling, smoking dive from his position to a crash point on the lobby floor near the spawn), explodes on
-- impact (the chain of explosions), the RINGS burst out from the CRASH POINT, then he fades away smoothly - NO
-- dialogue in the Defeat - and the lobby Eggman returns to his spot (fade in)" (v3: the floor is the arena's
-- track; the lobby Eggman is back at his spot for the Return beat: Beats.Return). Times are seconds after the
-- Defeat's start (SSE_PhaseStart = plan.endStart); CrashTimes(defeatStart) gives them as server times.
--   the dive     0 .. Seconds: CrashPath (BossCFrame's position) from the ship at the defeat (velocity-continuous)
--                to the crash point (SSE_CrashPoint: the floor Radius studs from the fight's centre toward the
--                ship, at most MaxAcross across the track: CrashCandidate + the server's raycast), spiralling
--                (SpiralRadius, SpiralTurns) and rolling (SpinTurns), nose down at the impact; the hull centre
--                lands WreckLift over the floor.
--   the impact   at Seconds: the explosions (Explosions: { seconds after the impact, x, y, z offset from the
--                crash point, size x }), a camera punch (Camera.Defeat).
--   the rings    burst from the crash point RingsDelay after the impact (the Rings message's fromPos = the crash
--                point + RingsUp, its burstTime), land RingsFly later (its landTime).
--   the wreck    lies still (tilted WreckPitch / WreckRoll) until WreckHold after the impact, then fades out over
--                FadeSeconds.
-- Without SSE_CrashPoint (a v2 server) the old drift / hold / fly-away stays.
SSE.Crash = {
	Seconds = 2.4,
	Radius = 30,
	MinRadius = 12,
	MaxAcross = 24, -- the crash point's x offset (across the track) is clamped to this
	Candidates = 15, -- CrashCandidate: 3 radii x 5 directions
	MaxCarry = 40, -- the dive keeps at most this much of the fight's horizontal speed (studs/s)
	SpiralRadius = 9,
	SpiralTurns = 1.25,
	SpinTurns = 2, -- whole barrel rolls: upright again at the impact
	FaceIn = 0.25, -- share of the dive over which the ship turns from its fight facing to nose-first
	WreckLift = 3,
	WreckPitch = -24, -- degrees (nose into the ground)
	WreckRoll = 18,
	RingsDelay = 0.1,
	RingsFly = 1.2,
	RingsUp = 3,
	WreckHold = 1.0,
	FadeSeconds = 1.4,
	Explosions = {
		{ 0.00, 0, 2, 0, 1.6 },
		{ 0.18, 5, 3, -3, 1.0 },
		{ 0.34, -4, 4, 4, 1.1 },
		{ 0.52, 2, 6, 5, 0.9 },
		{ 0.70, -6, 2, -4, 1.2 },
		{ 0.95, 0, 5, 0, 1.4 },
	},
}

-- 2026-09-26 (owner): the boss fight's rhythm. Phase times are seconds since the Battle began.
SSE.Battle = {
	FirstAttack = 5, -- the first window (the players have just transformed)
	AttackMin = 7, -- later Attack windows: AttackMin..AttackMax (seeded)
	AttackMax = 9,
	ReloadMin = 5.5, -- Reload windows: ReloadMin..ReloadMax (seeded)
	ReloadMax = 6.5,
	MinTail = 2.0, -- a last window shorter than this is merged into the one before
	HitGrace = 0.15, -- a homing arrival this close outside a Reload window still counts
	SalvoLead = 0.8, -- the first salvo this long into an Attack window
	SalvoGapStart = 2.6, -- then every gap: SalvoGapStart - SalvoGapStep x (window - 1), at least SalvoGapMin
	SalvoGapStep = 0.12,
	SalvoGapMin = 1.5,
	SalvoTail = 0.4, -- no salvo leaves in the last SalvoTail seconds of a window
	ParallelAt = 2, -- the 2nd salvo of every Attack window is a Parallel line
	PatternWeights = { Aimed = 0.5, Parallel = 0.2, Rain = 0.3 }, -- the others (seeded)
	SuperRagdollSeconds = 1.2, -- a Super player thrown by a bomb: ragdolled (and refused "stunned") this long
}

-- The ship's hit points: round(Base x participants^Exponent), within Min..Max (participants = the Super players
-- when the Battle begins; a new participant later raises it: the max and the HP left grow by the difference).
-- 2026-09-26 (owner): v3: Base 34 (v2: 66: a solo player attacking without charging, thrown about by the bombs,
-- dealt ~53 of 66 in the 150 s: "he always escapes"). Measured with the server itself (audit/test_u4_supersonic_event
-- 3k: seed 12345, the Battle's bombs on, players attacking only when the arrival falls in a Reload window):
--     players   HP    uncharged jump attacks (1 dmg)   charged (0.7 s, 3 dmg)
--        1      34            ~96 s                          ~49 s
--        4     127            ~93 s
--        8     245            ~94 s
-- A lobby attacking at random (shield up or not) bounces off half the time and may still see him escape.
SSE.HP = { Base = 34, Exponent = 0.95, Min = 34, Max = 3000, GrowWithLateJoiners = true }

SSE.Bombard = {
	-- The Bombard phase (the players are not Super yet: a longer warning).
	Salvos = 3,
	SalvoTimes = { 0.8, 3.3, 5.8 }, -- seconds into the Bombard phase
	Patterns = { "Aimed", "Parallel", "Aimed" },
	BombsBase = 3, -- bombs per salvo: Base + PerPlayer x eligible players, at most Max
	BombsPerPlayer = 1,
	BombsMax = 12,
	FlightMin = 1.4, -- a bomb's flight (= its warning): FlightMin + horizontal distance x FlightPerStud, at most FlightMax
	FlightPerStud = 1 / 160,
	FlightMax = 2.0,
	-- The Battle's salvos (Super players: faster bombs, shorter warning, more bombs as the fight goes on).
	BattleBombsBase = 3, -- Base + PerPlayer x targets + floor(Escalation x (window - 1)), at most Max
	BattleBombsPerPlayer = 1,
	BattleEscalation = 0.5,
	BattleBombsMax = 16,
	BattleFlightMin = 1.0,
	BattleFlightPerStud = 1 / 220,
	BattleFlightMax = 1.5,
	BombStagger = 0.1, -- seconds between the bombs of an Aimed salvo (Rain: half of it)
	ArcHeight = 16, -- the arc's rise over the straight line at its middle
	TargetScatter = 7, -- an Aimed bomb lands up to this far from its (led) target
	RainScatter = 30, -- a Rain bomb: up to this far
	LeadFactor = 0.6, -- lead a moving target by its horizontal velocity x flight x LeadFactor...
	LeadMaxStuds = 24, -- ...at most this far
	Parallel = { Count = 3, BombardCount = 2, Spacing = 26, Lines = 2, LineStagger = 0.25 }, -- bombs side by side
	-- across the target (perpendicular to the ship -> target line), Spacing apart; Lines lines (one per target)
	BlastRadius = 22,
	KnockOut = 55, -- (pos - bombPos).Unit * KnockOut + (0, KnockUp, 0)
	KnockUp = 42,
	RagdollSeconds = 2, -- the live ragdoll; the blast NEVER kills
	FirePatchSeconds = 5, -- the burning patch where a bomb landed (cosmetic)
	GroundProbe = 60, -- studs the server looks down for the floor under a target
	KnockGrace = 0.4, -- a player just thrown is not thrown again by another bomb for this long
	RescueDrop = 60, -- a thrown player this far under the origin (off the sky lobby) is put back at the spawn
	RescueSeconds = 5, -- ...while this long after the throw
	FallbackRadius = 40, -- no player to aim at: the bomb lands this close to the spawn
}
-- 2026-09-26 (owner): the red zone the client draws for every bomb = exactly the blast: a circle of Radius
-- around the bomb's toPos from its launch until its impact (its flightTime, never under MinSeconds).
SSE.Warning = { Radius = 22, MinSeconds = 1.0, BombardMinSeconds = 1.4 }

-- The 7 Chaos Emeralds (RGB 0-255, cosmetic).
SSE.Emeralds = {
	Count = 7,
	OrbitRadius = 6,
	SpinSpeed = 2.4, -- radians a second around the player
	BobSpeed = 4, -- y = sin(t * BobSpeed) * BobHeight
	BobHeight = 1.5,
	OrbitSeconds = 4.0, -- phase time: orbit until OrbitSeconds,
	ConvergeSeconds = 1.2, -- then close in on the player's root,
	AbsorbAt = 5.2, -- absorbed here: the server sets SSE_Super (the client bursts),
	BurstSeconds = 0.8,
	Colors = {
		{ 40, 220, 90 }, { 235, 40, 50 }, { 40, 90, 245 }, { 90, 230, 255 },
		{ 255, 220, 40 }, { 235, 235, 245 }, { 175, 70, 240 },
	},
}

-- WalkSpeed is a floor (a player already faster keeps their own speed; the game's sprint stacks on top).
-- LateTransform: players who reach the event during the Battle (or respawn there) turn Super too.
-- 2026-09-26 (owner): SkinId = the game's real Super Sonic skin (Shared/SuitCatalog), worn for the event
-- through _G.SpeedsterSkinOverride (Economy/SkinSystem): never owned, never saved, the player's own skin back.
SSE.Super = { WalkSpeed = 120, JumpPower = 90, LateTransform = true, SkinId = "SuperSonicSuit", SkinReason = "SuperSonicEvent" }

SSE.Homing = {
	Range = 180, -- studs from the ship's server-computed position
	RangeSlack = 6, -- latency slack on the server's range check (the client gates at Range)
	-- 2026-09-26 (owner): v3 "fast like the Sonic games": 320 studs/s (v2: 180) along a tighter curve (v2: Lift
	-- 0.28 / 6..40, Swing 0.14 / 18, MinDuration 0.15): a snappy dash, ~0.2 s to a ship 60 studs away.
	Speed = 320, -- studs a second along HomingPath
	MinDuration = 0.1,
	Cooldown = 1.0, -- per player, between accepted homing attacks (a shielded one too, v3)
	MaxLag = 0.6, -- a request's clientTime is trusted this far back (lag-compensated ship position)
	Lift = 0.12, -- the curve's rise: Lift x distance, within LiftMin..LiftMax studs
	LiftMin = 2,
	LiftMax = 12,
	Swing = 0.05, -- its sideways swing: Swing x distance, at most SwingMax studs
	SwingMax = 5,
	-- 2026-09-26 (owner): v3. A "Charge" press older than this at the release is forgotten (charge 0): a press
	-- whose release never came cannot charge a later mid-air jump attack.
	ChargeStaleSeconds = 8,
	-- 2026-09-26 (owner): v3. At the Battle's timeout the Escape waits for the attacks still flying (they may
	-- still break him), at most this long.
	MaxFlightSeconds = 1.5,
	Samples = 24, -- segments HomingLength sums
	BounceUp = 55, -- HomingBounce: Vector3.new(0, BounceUp + BounceUpCharged x c, 0) - look * (BounceBack + BounceBackCharged x c)
	BounceBack = 25,
	-- 2026-09-26 (owner): the charged homing attack ("Sonic charges the ball with F for as long as the charge
	-- sound lasts, or release earlier; the more charge, the more knockback"). The charge sound is
	-- rbxassetid://93126470207724. 2026-09-26 (owner): v3: the full charge in 0.7 s (v2: 1.6 s, "too long and
	-- frustrating"); the sound may play on past it.
	ChargeSeconds = 0.7,
	ChargeSound = "rbxassetid://93126470207724",
	DamageBase = 1, -- damage = DamageBase + round(DamageCharged x charge): 1 (< 0.25), 2 (< 0.75), 3
	DamageCharged = 2,
	BounceUpCharged = 30,
	BounceBackCharged = 25,
	RecoilStuds = 2.5, -- BossRecoil: the ship is knocked RecoilStuds + RecoilChargedStuds x charge (client visual)
	RecoilChargedStuds = 7.5,
	RecoilDegrees = 6,
	RecoilChargedDegrees = 14,
}

-- 2026-09-26 (owner): v3. An attack that reaches the ship while its shield is up (an Attack window) bounces off:
-- no damage to anyone, the attacker thrown KnockOut studs/s away from the ship (horizontally, back the way the
-- attack came: ShieldKnock) + KnockUp up, with no ragdoll (RagdollSeconds 0: never a kill), then "stunned"
-- (HomingRefusals.Stunned) for StunSeconds. A player thrown off the floor is put back at the fight's centre
-- (Bombard.RescueDrop / RescueSeconds, like a bomb's throw).
SSE.Shield = { KnockOut = 70, KnockUp = 30, RagdollSeconds = 0, StunSeconds = 0.4 }

SSE.Rewards = {
	-- 2026-09-26 (owner): the fight is longer, so a hit pays less and the cap is higher (v1: 1,000 / 50,000 x 25).
	HitWins = 600,
	HitSpeed = 30000,
	MaxRewardedHits = 45, -- per account per event (a rejoin does not reset it): at most 27,000 Wins + 1,350,000 Speed.
	-- Hits past it still land and damage the ship, they just pay nothing.
	-- The data commits: the first reward is committed at once, later ones are batched per player at most
	-- every FlushSeconds (every commit is a DataStore write), and everything left at the end, on leaving.
	FlushSeconds = 5,
	ApplyWinsMultiplier = false, -- true: HitWins x the player's Wins multiplier (_G.SpeedsterGetWinsMultiplier)
}

-- 2026-09-26 (owner): the defeat's rain of gold rings (the server picks the landing spots on the lobby floor).
-- A ring pays BOTH Wins and Speed, 1/12 of a hit (600 / 30,000): +50 Wins +2,500 Speed, at most 30 rings a
-- player an event (1,500 Wins + 75,000 Speed). Shared evenly: 4 players -> 44 rings, ~11 each (~550 Wins +
-- ~27,500 Speed); 12 players -> 92 rings, ~8 each (~400 Wins + ~20,000 Speed); a quick player takes more.
SSE.Rings = {
	Base = 20, -- count = Base + PerParticipant x participants, at most Max
	PerParticipant = 6,
	Max = 120,
	MinRadius = 8, -- RingScatter: from the spawn, spread evenly by area
	MaxRadius = 70,
	Tries = 3, -- candidates per ring when a spot has no floor (then it is dropped)
	RetryShrink = 0.7, -- each retry's spot is this much closer to the spawn
	ProbeUp = 12, -- the server's raycast starts this far over the origin's height...
	ProbeDown = 40, -- ...and looks this far down; the floor must be within MaxRise over / MaxDrop under the origin
	MaxRise = 12,
	MaxDrop = 20,
	MinNormalY = 0.7, -- walkable: a floor, not a wall
	Height = 2.5, -- a ring's centre over the floor
	LandDelay = 1.6, -- (v2, no crash point) they rain from the breaking ship and land this long after the defeat
	-- 2026-09-26 (owner): v3: they land after the crash (CrashTimes: 3.7 s into the Defeat) and may be taken for
	-- LifeSeconds (the clients fade them out), gone before the Return beat (Durations.Defeat 20). ScaleX squeezes
	-- the scatter's x offsets (across the track) on the arena: an ellipse inside the 72-stud corridor.
	LifeSeconds = 16,
	ScaleX = 0.45,
	TakeRadius = 8, -- the taker's root within this (horizontal) of the ring...
	TakeHeight = 10, -- ...and this vertically,
	TakeSlackSeconds = 0.15, -- + speed x TakeSlackSeconds (latency), at most TakeSlackMax
	TakeSlackMax = 18,
	EarlyGrace = 0.05,
	RewardWins = 50,
	RewardSpeed = 2500,
	MaxPerPlayer = 30,
	MaxIdsPerMessage = 8,
}

-- Client messages per player: a token bucket (Burst tokens, refilled PerSecond); the rest are dropped.
SSE.RateLimit = { Burst = 12, PerSecond = 15 }

-- The event's area (targets, transformation, no Flight); a player leaves it past the Exit sizes (hysteresis).
-- 2026-09-26 (owner): v3: the fight's area is the race arena's corridor round SSE_Origin: InArena = a box HalfX
-- across the track (the walls stand at +-38.1), HalfZ along it, BelowOrigin .. AboveOrigin in height. (Radius /
-- ExitRadius: v2's circle round the lobby spawn, now SSE.Lobby's.)
SSE.Arena = { HalfX = 60, ExitHalfX = 72, HalfZ = 300, ExitHalfZ = 330, BelowOrigin = 60, AboveOrigin = 260,
	Radius = 300, ExitRadius = 340 }
-- v3: the lobby area (v2's event area): within Radius (horizontal) of the lobby spawn and within the height
-- band; the Cinematic's audience, moved to the arena by the Teleport beat.
SSE.Lobby = { Radius = 300, ExitRadius = 340, BelowOrigin = 80, AboveOrigin = 260 }
-- v3: the race arena (Update4Config.Race.Arena.Origin: the start line's centre on the floor top, the track toward
-- -Z, s = Origin.Z - Z; the same in the three worlds). The fight's centre is the track at s = TrackS (a flat
-- stretch of Green Hill's ground: s 440..580 lies at the floor's height; hills of 4.5 studs round it), x 0; the
-- server drops it on the floor (a raycast from ProbeUp over it down ProbeDown). Origins[worldKey] may move a world's.
SSE.RaceArena = { Origin = { 6000, 12000, 0 }, TrackS = 510, ProbeUp = 40, ProbeDown = 120, Origins = {} }

-- 2026-09-26 (owner): v3. The freeze windows (seconds into each phase): the Cinematic (the whole 7.5 s, in the
-- lobby), the Teleport beat (its fades), the Emeralds shot (Shared/SuperSonicCinematic's Emeralds shot, 6.2 s),
-- the Defeat's crash (the crash, the impact and the ring burst until the rings have landed, + 0.3 s; its outro
-- shot fits inside it, so the players are free when the rings can be taken), the Escape's outro (its Outro shot,
-- 5.8 s) and the Return beat. The clients freeze their own player (velocity 0, no movement) inside a window when
-- FreezesHere says so: its root in the window's Area ("Lobby": InLobby; "Arena": InArena; "Both": either; for
-- the Return, where the root was when the phase began: the trip moves it). The server throws nobody, rescues
-- falls and forgives deaths inside them (+ FallGraceSeconds after the End: a player let go in the air lands).
-- A phase not listed never freezes.
SSE.FreezeWindows = {
	Cinematic = { Start = 0, End = 7.5, Area = "Lobby" },
	Teleport = { Start = 0, End = 1.8, Area = "Both" },
	Emeralds = { Start = 0, End = 6.2, Area = "Arena" },
	Defeat = { Start = 0, End = 4.0, Area = "Arena" },
	Escape = { Start = 0, End = 5.8, Area = "Arena" },
	Return = { Start = 0, End = 2.5, Area = "Arena" },
}
SSE.Freeze = { FallGraceSeconds = 1.5 }

-- 2026-09-26 (owner): v3. The trips (TeleportToEvent, the Teleport and Return beats). The spot: the first of
-- Candidates spots (TeleportCandidate: an ellipse round the centre, Across studs across the track (x) and Along
-- along it (z), none closer than MinRadius) with walkable floor near the centre's height (a raycast from ProbeUp
-- over it down ProbeUp + ProbeDown; within MaxRise over / MaxDrop under it, normal Y >= MinNormalY) that is
-- Clearance studs (horizontal) from every other player and every spot handed out in the last SpotMemory s, and
-- outside every falling bomb's blast + BombMargin (SpotClear). None: the centre itself. The centre: SSE_Origin
-- (the arena) once the Teleport beat has moved everyone, the lobby spawn before it and for the Return. The root
-- lands Height over the floor. The server streams the spot in for the player first (at most StreamSeconds),
-- then moves them (arrival grace, MovementGuard; a trip to the lobby is the world's own spawn trip first).
-- Bombs throw nobody for SafeSeconds after an arrival.
SSE.Teleport = {
	Cooldown = 5,
	MinRadius = 6,
	Across = 26,
	Along = 40,
	Candidates = 64, -- a full server (MaxPlayers 60) moved at once
	Clearance = 4,
	SpotMemory = 3,
	BombMargin = 6,
	ProbeUp = 12,
	ProbeDown = 40,
	MaxRise = 8,
	MaxDrop = 12,
	MinNormalY = 0.7,
	Height = 3.5,
	StreamSeconds = 4,
	SafeSeconds = 2,
}

-- Camera punches (Shared/CameraPunch: Shake(duration, strength) + Fov(size)).
SSE.Camera = {
	BombHit = { Shake = { 0.35, 2.2 }, Fov = 12 },
	HomingHit = { Shake = { 0.18, 1.4 }, Fov = -6 },
	Defeat = { Shake = { 0.60, 3.5 }, Fov = 18 },
}

-- The server's system chat lines (TextChatService system message).
SSE.Announcements = {
	Start = "Dr. Eggman is attacking the lobby! Dodge the bombs, grab the Chaos Emeralds and go Super!",
	Defeat = "Dr. Eggman is DEFEATED! Every hit paid +600 Wins and +30,000 Speed. Grab the gold rings!",
	Escape = "Dr. Eggman got away... he'll be back!",
	ChatColor = "#FFD23C",
}

----------------------------------------------------------------------
-- Maths
----------------------------------------------------------------------
local TAU = math.pi * 2
local INF = math.huge

local function finite(n: any): boolean
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

local function num(value: any, default: number): number
	local n = tonumber(value)
	if n == nil or not finite(n) then
		return default
	end
	return n
end

local function smoothstep(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

-- A seeded number in [0, 1) for (seed, a, b): xorshift rounds only (bit32: exact, the same in Roblox and Lune).
local function hash01(seed: any, a: number, b: number): number
	local s = math.floor(math.abs(num(seed, 1))) % 4294967296
	local x = bit32.bxor(s, (math.floor(a) * 40503 + math.floor(b) * 9973 + 12345) % 4294967296)
	if x == 0 then
		x = 2463534242
	end
	for _ = 1, 4 do
		x = bit32.bxor(x, bit32.lshift(x, 13))
		x = bit32.bxor(x, bit32.rshift(x, 17))
		x = bit32.bxor(x, bit32.lshift(x, 5))
	end
	return x / 4294967296
end
SSE.Hash01 = hash01

-- "Intro" (v1) -> "Cinematic"; anything else as it is.
function SSE.NormalizePhase(name: any): string
	if name == "Intro" then
		return SSE.Phases.Cinematic
	end
	return if type(name) == "string" then name else ""
end

function SSE.IsPhase(name: any): boolean
	if name == "" or name == SSE.Phases.Escape then
		return true
	end
	for _, phase in SSE.PhaseOrder do
		if phase == name then
			return true
		end
	end
	return false
end

-- The phase after `phase` ("" after the Return or for anything unknown; v3: Defeat / Escape -> Return).
function SSE.NextPhase(phase: string): string
	phase = SSE.NormalizePhase(phase)
	if phase == SSE.Phases.Escape then
		return SSE.Phases.Return
	end
	for i, name in SSE.PhaseOrder do
		if name == phase then
			return SSE.PhaseOrder[i + 1] or ""
		end
	end
	return ""
end

function SSE.PhaseDuration(phase: string): number
	return num((SSE.Durations :: any)[SSE.NormalizePhase(phase)], 0)
end

-- Seconds from the event's start (SSE_EventStart) to a phase's start (nil for Defeat / Escape / Return: not
-- fixed). v3: the Teleport beat between the Cinematic and the Bombard.
function SSE.PhaseOffset(phase: string): number?
	phase = SSE.NormalizePhase(phase)
	local D = SSE.Durations
	if phase == "Cinematic" then
		return 0
	elseif phase == "Teleport" then
		return D.Cinematic
	elseif phase == "Bombard" then
		return D.Cinematic + D.Teleport
	elseif phase == "Emeralds" then
		return D.Cinematic + D.Teleport + D.Bombard
	elseif phase == "Battle" then
		return D.Cinematic + D.Teleport + D.Bombard + D.Emeralds
	end
	return nil
end

-- The dialogue cues of a phase, sorted: { { t = seconds into the phase, key = ... }, ... }.
function SSE.DialogueFor(phase: string): { { t: number, key: string } }
	phase = SSE.NormalizePhase(phase)
	local list = {}
	for _, cue in SSE.Dialogue do
		if cue[1] == phase then
			table.insert(list, { t = cue[2], key = cue[3] })
		end
	end
	table.sort(list, function(a, b)
		return a.t < b.t
	end)
	return list
end

-- 2026-09-26 (owner): v3. A phase's freeze window: (Start, End) in seconds into the phase and its Area, or nil
-- (never frozen).
function SSE.FreezeWindow(phase: any): (number?, number?, string?)
	local w = SSE.FreezeWindows[SSE.NormalizePhase(phase)]
	if type(w) ~= "table" then
		return nil, nil, nil
	end
	return w.Start, w.End, w.Area
end

-- Whether phaseTime (seconds since SSE_PhaseStart) is inside the phase's freeze window (+ grace seconds after its
-- End; the clients pass none, the server Freeze.FallGraceSeconds for falls and deaths).
function SSE.IsFrozen(phase: any, phaseTime: any, grace: number?): boolean
	local start, finish = SSE.FreezeWindow(phase)
	local t = tonumber(phaseTime)
	if start == nil or finish == nil or t == nil or not finite(t) then
		return false
	end
	return (t :: number) >= start and (t :: number) <= finish + math.max(0, num(grace, 0))
end

-- 2026-09-26 (owner): v3. Whether a client freezes its own player: inside the phase's window (IsFrozen) with its
-- root (pos) in the window's Area: "Lobby" InLobby(lobbyOrigin), "Arena" InArena(origin), "Both" either (exit
-- tests). For the Return pass where the root was when the phase began (the trip moves it). lobbyOrigin nil:
-- the lobby is the origin.
function SSE.FreezesHere(phase: any, phaseTime: any, pos: Vector3?, origin: Vector3?, lobbyOrigin: Vector3?): boolean
	if pos == nil or origin == nil or not SSE.IsFrozen(phase, phaseTime) then
		return false
	end
	local _, _, area = SSE.FreezeWindow(phase)
	local lobby: Vector3 = lobbyOrigin or origin
	local inLobby = SSE.InLobby(pos, lobby, true)
	local inArena = SSE.InArena(pos, origin, true) or (lobby - origin).Magnitude < 1 and inLobby
	if area == "Lobby" then
		return inLobby
	elseif area == "Arena" then
		return inArena
	end
	return inLobby or inArena
end

-- 2026-09-26 (owner): v3. Whether the event still invites (and takes) players: the Cinematic .. the Battle.
function SSE.InviteOpen(phase: any): boolean
	phase = SSE.NormalizePhase(phase)
	return phase == SSE.Phases.Cinematic or phase == SSE.Phases.Teleport or phase == SSE.Phases.Bombard
		or phase == SSE.Phases.Emeralds or phase == SSE.Phases.Battle
end

-- 2026-09-26 (owner): much more HP, scaling with the participants (see the table in the header).
function SSE.BossMaxHP(playerCount: number?): number
	local n = math.max(1, math.floor(num(playerCount, 0)))
	local hp = SSE.HP
	return math.clamp(math.round(hp.Base * n ^ hp.Exponent), hp.Min, hp.Max)
end

-- Bombs of a Bombard salvo (Aimed / Rain).
function SSE.BombsPerSalvo(playerCount: number?): number
	local n = math.max(0, math.floor(num(playerCount, 0)))
	local b = SSE.Bombard
	return math.clamp(b.BombsBase + b.BombsPerPlayer * n, 1, b.BombsMax)
end

-- Bombs of a Battle salvo (Aimed / Rain) in Attack window `window` (1, 2, ...): more players, later windows, more.
function SSE.BattleBombsPerSalvo(playerCount: number?, window: number?): number
	local n = math.max(0, math.floor(num(playerCount, 0)))
	local k = math.max(1, math.floor(num(window, 1)))
	local b = SSE.Bombard
	return math.clamp(b.BattleBombsBase + b.BattleBombsPerPlayer * n + math.floor(b.BattleEscalation * (k - 1)), 1, b.BattleBombsMax)
end

----------------------------------------------------------------------
-- The Battle schedule (pure, seeded; phase times)
----------------------------------------------------------------------
export type BossWindow = { state: string, start: number, finish: number, index: number }

local caches: { [string]: { [number]: any } } = { windows = {}, salvos = {}, dives = {}, path = {} }
local cacheSizes: { [string]: number } = { windows = 0, salvos = 0, dives = 0, path = 0 }

local function seedKey(seed: any): number
	return math.floor(math.abs(num(seed, 0))) % 4294967296
end

local function cached(kind: string, key: number, build: () -> any): any
	local store = caches[kind]
	local value = store[key]
	if value == nil then
		if cacheSizes[kind] >= 32 then
			table.clear(store)
			cacheSizes[kind] = 0
		end
		value = build()
		store[key] = value
		cacheSizes[kind] += 1
	end
	return value
end

-- The Battle's Attack / Reload windows, covering [0, Durations.Battle] (phase times).
function SSE.BossWindows(seed: any): { BossWindow }
	local key = seedKey(seed)
	return cached("windows", key, function()
		local B, total = SSE.Battle, SSE.Durations.Battle
		local list = {}
		local first = math.min(B.FirstAttack, total)
		table.insert(list, { state = "Attack", start = 0, finish = first, index = 1 })
		local t = first
		local attacks, reloads = 1, 0
		while t < total - 1e-9 do
			reloads += 1
			local length = B.ReloadMin + (B.ReloadMax - B.ReloadMin) * hash01(key, reloads, 2)
			local finish = math.min(total, t + length)
			table.insert(list, { state = "Reload", start = t, finish = finish, index = reloads })
			t = finish
			if t >= total - 1e-9 then
				break
			end
			attacks += 1
			length = B.AttackMin + (B.AttackMax - B.AttackMin) * hash01(key, attacks, 1)
			finish = math.min(total, t + length)
			table.insert(list, { state = "Attack", start = t, finish = finish, index = attacks })
			t = finish
		end
		-- A last sliver shorter than MinTail joins the window before it.
		local last = list[#list]
		if #list > 1 and last.finish - last.start < B.MinTail then
			table.remove(list)
			list[#list].finish = total
		end
		return list
	end)
end

-- The boss's state at phaseTime (seconds since the Battle began): "Attack" | "Reload", its window's start and
-- end (phase times). Before the Battle: "Attack" until 0; after it: "Attack" from Durations.Battle on.
function SSE.BossState(phaseTime: number, seed: any): (string, number, number)
	local t = num(phaseTime, 0)
	if t < 0 then
		return "Attack", -INF, 0
	end
	local list = SSE.BossWindows(seed)
	for _, w in list do
		if t < w.finish then
			return w.state, w.start, w.finish
		end
	end
	return "Attack", SSE.Durations.Battle, INF
end

-- Whether a homing arrival at phaseTime counts: inside a Reload window, +- grace (default Battle.HitGrace).
function SSE.BossVulnerable(phaseTime: number, seed: any, grace: number?): boolean
	local t = num(phaseTime, -INF)
	local g = num(grace, SSE.Battle.HitGrace)
	for _, w in SSE.BossWindows(seed) do
		if w.state == "Reload" and t >= w.start - g and t <= w.finish + g then
			return true
		end
	end
	return false
end

-- The Battle's salvos: { { t = phase time, pattern, window = Attack window index, index = salvo in it } }.
function SSE.BattleSalvos(seed: any): { { t: number, pattern: string, window: number, index: number } }
	local key = seedKey(seed)
	return cached("salvos", key, function()
		local B = SSE.Battle
		local weights = B.PatternWeights
		local total = weights.Aimed + weights.Parallel + weights.Rain
		local list = {}
		for _, w in SSE.BossWindows(key) do
			if w.state == "Attack" then
				local k = w.index
				local gap = math.max(B.SalvoGapMin, B.SalvoGapStart - B.SalvoGapStep * (k - 1))
				local t = w.start + B.SalvoLead
				local j = 0
				while t <= w.finish - B.SalvoTail + 1e-9 do
					j += 1
					local pattern
					if j == B.ParallelAt then
						pattern = "Parallel"
					else
						local roll = hash01(key, k * 16 + j, 4) * total
						pattern = if roll < weights.Aimed then "Aimed" elseif roll < weights.Aimed + weights.Parallel then "Parallel" else "Rain"
					end
					table.insert(list, { t = t, pattern = pattern, window = k, index = j })
					t += gap
				end
			end
		end
		return list
	end)
end

-- The Battle's dives: { { start, finish } } phase times (one per Attack window from the 2nd on, when long enough).
function SSE.BossDives(seed: any): { { start: number, finish: number } }
	local key = seedKey(seed)
	return cached("dives", key, function()
		local b = SSE.Boss
		local list = {}
		for _, w in SSE.BossWindows(key) do
			local length = w.finish - w.start
			if w.state == "Attack" and w.index >= 2 and length >= b.DiveMinWindow then
				local room = length - b.DiveLead - b.DiveSeconds - b.DiveTail
				local start = w.start + b.DiveLead + math.max(0, room) * hash01(key, w.index, 3)
				table.insert(list, { start = start, finish = start + b.DiveSeconds })
			end
		end
		return list
	end)
end

----------------------------------------------------------------------
-- The boss path
----------------------------------------------------------------------
export type Plan = { start: number, seed: number, liftOff: Vector3?, endStart: number?, outcome: string?, crashPoint: Vector3?,
	lobbyOrigin: Vector3? }

-- The plan every side computes the ship with: start = SSE_EventStart (the Cinematic's start), seed = SSE_Seed,
-- liftOff = SSE_LiftOff (nil: DefaultLiftOff over the lobby spawn), endStart = the Defeat / Escape phase's start
-- (nil while the fight is on), outcome = "Defeat" | "Escape", (v3) crashPoint = SSE_CrashPoint (the Defeat's
-- crash; nil: the v2 fly-away), (v3) lobbyOrigin = SSE_LobbyOrigin (nil: the lobby is the origin itself).
function SSE.Plan(start: number, seed: any, liftOff: Vector3?, endStart: number?, outcome: string?, crashPoint: Vector3?,
	lobbyOrigin: Vector3?): Plan
	return { start = num(start, 0), seed = seedKey(seed), liftOff = liftOff, endStart = endStart, outcome = outcome,
		crashPoint = crashPoint, lobbyOrigin = lobbyOrigin }
end

-- The plan from the Workspace attributes: get(name) -> the attribute (e.g. function(n) return
-- workspace:GetAttribute(n) end). nil when no event runs (no SSE_EventStart).
function SSE.PlanFromAttributes(get: (string) -> any): Plan?
	local A = SSE.Attributes
	local start = tonumber(get(A.EventStart))
	if start == nil or not finite(start) then
		return nil
	end
	local phase = SSE.NormalizePhase(get(A.Phase))
	local endStart, outcome, crash = nil, nil, nil
	if SSE.EndPhases[phase] then
		endStart = tonumber(get(A.PhaseStart))
		outcome = phase
	elseif phase == SSE.Phases.Return then
		-- v3: the Return beat keeps the ending's plan (SSE_EndStart / SSE_Outcome).
		local kept = get(A.Outcome)
		if type(kept) == "string" and SSE.EndPhases[kept] then
			endStart = tonumber(get(A.EndStart))
			outcome = kept
		end
	end
	if outcome == SSE.Phases.Defeat then
		crash = get(A.CrashPoint)
		if typeof(crash) ~= "Vector3" then
			crash = nil
		end
	end
	local lift = get(A.LiftOff)
	if typeof(lift) ~= "Vector3" then
		lift = nil
	end
	local lobby = get(A.LobbyOrigin)
	if typeof(lobby) ~= "Vector3" then
		lobby = nil
	end
	return SSE.Plan(start :: number, get(A.Seed), lift, endStart, outcome, crash, lobby)
end

-- Motion levels over event time: { { at, level } } with the first at -INF; each change eases over Boss.Ramp.
local function segLevel(segs: { any }, x: number, ramp: number): number
	local lo, hi = 1, #segs
	while lo < hi do
		local mid = (lo + hi + 1) // 2
		if segs[mid].at <= x then
			lo = mid
		else
			hi = mid - 1
		end
	end
	if lo == 1 then
		return segs[1].level
	end
	local prev = segs[lo - 1].level
	local seg = segs[lo]
	return prev + (seg.level - prev) * smoothstep((x - seg.at) / ramp)
end

-- The path's schedule in event time (seconds since the Cinematic began), per seed.
local function pathSchedule(key: number): any
	return cached("path", key, function()
		local b = SSE.Boss
		-- v3: the Teleport beat before the Bombard; the arena path starts with Eggman's entrance (entry0).
		local bombard0 = SSE.PhaseOffset("Bombard") :: number
		local battle0 = SSE.PhaseOffset("Battle") :: number
		local entry0 = (SSE.PhaseOffset("Teleport") :: number) + SSE.Beats.Teleport.EntryStart
		local strafe = { { at = -INF, level = 0 }, { at = bombard0, level = 1 },
			{ at = SSE.PhaseOffset("Emeralds") :: number, level = b.EmeraldsStrafe } }
		local reload = { { at = -INF, level = 0 } }
		for _, w in SSE.BossWindows(key) do
			local isReload = w.state == "Reload"
			table.insert(strafe, { at = battle0 + w.start, level = if isReload then 0 else 1 })
			table.insert(reload, { at = battle0 + w.start, level = if isReload then 1 else 0 })
		end
		local dives = {}
		for _, dive in SSE.BossDives(key) do
			table.insert(dives, { start = battle0 + dive.start, finish = battle0 + dive.finish })
		end
		return {
			strafe = strafe,
			reload = reload,
			dives = dives,
			strafePhase = hash01(key, 7, 5) * TAU,
			wobblePhase = hash01(key, 7, 6) * TAU,
			bombard0 = bombard0,
			entry0 = entry0,
			entryLen = math.max(0.5, bombard0 - entry0),
		}
	end)
end

local function diveLevel(dives: { any }, x: number, seconds: number): number
	for _, dive in dives do
		if x >= dive.start and x <= dive.finish then
			local s = math.sin(math.pi * (x - dive.start) / seconds)
			return s * s
		end
	end
	return 0
end

-- 2026-09-26 (owner): v3. The lobby part (the Cinematic, until the Teleport beat's move): world positions and
-- yaw / pitch / roll at event time tau. (lx, ly, lz) = the lift-off point, (ox, oz) = the lobby spawn. He rises
-- LiftRise over LiftHold facing the spawn (as at his spot), bobs, and from LeaveAt flies up and away (turning
-- round, nose up).
local function lobbyValues(tau: number, lx: number, ly: number, lz: number, ox: number, oz: number): (number, number, number, number, number, number)
	local b = SSE.Boss
	local dx, dz = lx - ox, lz - oz
	local hl = math.sqrt(dx * dx + dz * dz)
	local ux, uz = 0, 1
	if hl > 1e-3 then
		ux, uz = dx / hl, dz / hl
	end
	local lift = smoothstep(tau / b.LiftHold)
	local settle = smoothstep((tau - b.LiftHold) / 1.2)
	local f = math.max(0, tau - b.LeaveAt) / b.LeaveSeconds
	local f3 = f * f * f
	local x = lx + ux * b.LeaveOut * f3
	local y = ly + b.LiftRise * lift + b.BobHeight * math.sin(TAU * (tau - b.LiftHold) / b.BobPeriod) * settle + b.LeaveRise * f3
	local z = lz + uz * b.LeaveOut * f3
	local yaw = math.atan2(ux, uz) + math.pi * smoothstep(math.min(1, f * 2))
	local pitch = math.rad(b.NosePitch) * lift + (math.rad(b.EscapePitch) - math.rad(b.NosePitch) * lift) * smoothstep(f)
	local roll = math.rad(b.RollWobble) * math.sin(TAU * tau / 5.3) * lift * (1 - smoothstep(f))
	return x, y, z, yaw, pitch, roll
end

-- The fight's path in the arena (before any endStart): offsets from the origin (numbers) and yaw / pitch / roll
-- (radians) at event time tau. (ex, ey, ez): the entrance's start (Boss.EntryFrom). v3: his orbit, Reload circle
-- and dives are squeezed across the track (OrbitScaleX) and he always faces the fight's centre.
local function fightValues(tau: number, key: number, ex: number, ey: number, ez: number): (number, number, number, number, number, number)
	local b = SSE.Boss
	local sched = pathSchedule(key)
	local S = segLevel(sched.strafe, tau, b.Ramp)
	local R = segLevel(sched.reload, tau, b.Ramp)
	local dive = diveLevel(sched.dives, tau, b.DiveSeconds)
	local thetaL = math.atan2(ez, ex)
	local strafeArg = TAU * tau / b.StrafePeriod + sched.strafePhase
	local theta = thetaL + TAU / b.OrbitPeriod * (tau - sched.bombard0) + S * b.StrafeAngle * math.sin(strafeArg)
	local rA = b.OrbitRadius + b.OrbitWobble * math.sin(TAU * tau / b.OrbitWobblePeriod + sched.wobblePhase)
	local rR = b.ReloadRadius + b.ReloadWobble * math.sin(TAU * tau / b.ReloadWobblePeriod)
	local r = rA + (rR - rA) * R
	r += (b.DiveRadius - r) * dive
	local yA = b.Height + b.BobHeight * math.sin(TAU * tau / b.BobPeriod)
	local yR = b.ReloadHeight + b.ReloadBob * math.sin(TAU * tau / b.ReloadBobPeriod)
	local y = yA + (yR - yA) * R
	y += (b.DiveHeight - y) * dive
	local hx, hz = r * math.cos(theta) * b.OrbitScaleX, r * math.sin(theta)
	-- The entrance: from the entry point into the orbit (the Teleport beat).
	local w = smoothstep((tau - sched.entry0) / sched.entryLen)
	local x = ex + (hx - ex) * w
	local yy = ey + (y - ey) * w
	local z = ez + (hz - ez) * w
	-- Facing the fight's centre (forward -Z).
	local yaw = math.atan2(x, z)
	local pitchDeg = b.NosePitch + (b.ReloadPitch - b.NosePitch) * R + b.DivePitch * dive + b.PitchWobble * math.sin(TAU * tau / 3.7 + 0.6)
	local rollDeg = -b.Bank * S * math.cos(strafeArg) + b.RollWobble * math.sin(TAU * tau / 5.3)
	return x, yy, z, yaw, math.rad(pitchDeg * w), math.rad(rollDeg * w)
end

-- v1's hover (legacy): the ellipse over the spawn, facing it.
local function legacyHover(t: number): (number, number, number, number, number, number)
	local b = SSE.Boss
	local a = TAU * t / b.PathPeriod
	local x = b.PathRadiusX * math.cos(a)
	local z = b.PathRadiusZ * math.sin(a)
	local y = b.Height + b.BobHeight * math.sin(TAU * t / b.BobPeriod)
	local yaw = math.atan2(x, z)
	local pitch = math.rad(b.NosePitch + b.PitchWobble * math.sin(TAU * t / 3.7 + 0.6))
	local roll = math.rad(b.RollWobble * math.sin(TAU * t / 5.3))
	return x, y, z, yaw, pitch, roll
end

local function legacyOffset(t: number, introStart: number?): (number, number, number, number, number, number)
	local x, y, z, yaw, pitch, roll = legacyHover(t)
	if introStart ~= nil and finite(introStart) then
		local fly = SSE.Boss.FlyInSeconds
		local s = (t - (introStart :: number)) / fly
		if s < 1 then
			local ex, ey, ez = legacyHover((introStart :: number) + fly)
			local from = SSE.Boss.FlyInFrom
			local k = smoothstep(s)
			x = (ex + from[1]) + (x - (ex + from[1])) * k
			y = (ey + from[2]) + (y - (ey + from[2])) * k
			z = (ez + from[3]) + (z - (ez + from[3])) * k
		end
	end
	return x, y, z, yaw, pitch, roll
end

-- 2026-09-26 (owner): v3. The crash's point at s = 0..1 of the dive, in any frame (world or origin offsets):
-- from (f) = the ship at the defeat, v = its velocity then (studs/s), to (t) = the hull centre at the impact.
-- Horizontal: a cubic Hermite from (f, v x Seconds) to (t, t - f): it leaves with the fight's own velocity (C1;
-- at most MaxCarry studs/s of it). Vertical: an accelerating fall (1/2 s^2 + 1/2 s^3) plus v's climb / sink
-- fading out (s (1 - s)^2; a sink clamped so the ship never dips under the impact height). A corkscrew of
-- radius SpiralRadius x sin^2(pi s) turning SpiralTurns times (none at either end).
local function crashXYZ(s: number, fx: number, fy: number, fz: number, vx: number, vy: number, vz: number,
	tx: number, ty: number, tz: number): (number, number, number)
	local C = SSE.Crash
	local T = C.Seconds
	s = math.clamp(s, 0, 1)
	local hv = math.sqrt(vx * vx + vz * vz)
	if not finite(hv) then
		vx, vz, hv = 0, 0, 0
	end
	if hv > C.MaxCarry then
		vx, vz = vx / hv * C.MaxCarry, vz / hv * C.MaxCarry
	end
	if not finite(vy) then
		vy = 0
	end
	vy = math.max(vy, -3 * math.max(fy - ty, 1) / T)
	local s2, s3 = s * s, s * s * s
	local h00, h10, h01, h11 = 2 * s3 - 3 * s2 + 1, s3 - 2 * s2 + s, -2 * s3 + 3 * s2, s3 - s2
	local x = h00 * fx + h10 * vx * T + h01 * tx + h11 * (tx - fx)
	local z = h00 * fz + h10 * vz * T + h01 * tz + h11 * (tz - fz)
	local y = fy + (ty - fy) * (0.5 * s2 + 0.5 * s3) + vy * T * s * (1 - s) * (1 - s)
	local sn = math.sin(math.pi * s)
	local r = C.SpiralRadius * sn * sn
	local a = C.SpiralTurns * TAU * s
	return x + r * math.cos(a), y, z + r * math.sin(a)
end

-- The crash as numbers: u = seconds since the defeat; (x0..roll0) the ship's pose then, (vx, vy, vz) its
-- velocity, (tx, ty, tz) the hull centre at the impact. The dive turns nose-first over FaceIn of it and rolls
-- SpinTurns times; after the impact the wreck settles (0.3 s) nose down WreckPitch, rolled WreckRoll, and lies.
local function crashValues(u: number, x0: number, y0: number, z0: number, yaw0: number, pitch0: number, roll0: number,
	vx: number, vy: number, vz: number, tx: number, ty: number, tz: number): (number, number, number, number, number, number)
	local C = SSE.Crash
	local s = math.clamp(u / C.Seconds, 0, 1)
	local x, y, z = crashXYZ(s, x0, y0, z0, vx, vy, vz, tx, ty, tz)
	local e = 1e-3
	local xa, ya, za = crashXYZ(math.max(0, s - e), x0, y0, z0, vx, vy, vz, tx, ty, tz)
	local xb, yb, zb = crashXYZ(math.min(1, s + e), x0, y0, z0, vx, vy, vz, tx, ty, tz)
	local dx, dy, dz = xb - xa, yb - ya, zb - za
	local hl = math.sqrt(dx * dx + dz * dz)
	local yawV = if hl > 1e-9 then math.atan2(-dx, -dz) else yaw0
	local pitchV = math.atan2(dy, math.max(hl, 1e-9))
	local w = smoothstep(s / C.FaceIn)
	local dyaw = ((yawV - yaw0 + math.pi) % TAU) - math.pi
	local yaw = yaw0 + dyaw * w
	local pitch = pitch0 + (pitchV - pitch0) * w
	local roll = roll0 * (1 - w) + TAU * C.SpinTurns * smoothstep(s)
	if u > C.Seconds then
		local k = smoothstep((u - C.Seconds) / 0.3)
		pitch += (math.rad(C.WreckPitch) - pitch) * k
		roll += (math.rad(C.WreckRoll) - roll) * k
	end
	return x, y, z, yaw, pitch, roll
end

-- 2026-09-26 (owner): v3. The crash's hull centre at t01 = 0..1 of the dive (world): from = the ship at the
-- defeat, crashPoint = SSE_CrashPoint (the floor), v0 = the ship's velocity then (BossVelocity; nil = still).
-- BossCFrame with a Defeat plan that has a crashPoint gives the same point (and the ship's rotation).
function SSE.CrashPath(from: Vector3, crashPoint: Vector3, t01: number, v0: Vector3?): Vector3
	local v = v0 or Vector3.new(0, 0, 0)
	local x, y, z = crashXYZ(num(t01, 0), from.X, from.Y, from.Z, v.X, v.Y, v.Z,
		crashPoint.X, crashPoint.Y + SSE.Crash.WreckLift, crashPoint.Z)
	return Vector3.new(x, y, z)
end

-- The crash's server times from the Defeat's start (SSE_PhaseStart): impact, ringsBurst, ringsLand, fadeStart,
-- fadeEnd (the wreck gone). (The lobby Eggman comes back in the Return beat: Beats.Return.)
function SSE.CrashTimes(defeatStart: number): { [string]: number }
	local C = SSE.Crash
	local impact = num(defeatStart, 0) + C.Seconds
	local burst = impact + C.RingsDelay
	local fadeStart = impact + C.WreckHold
	return {
		impact = impact,
		ringsBurst = burst,
		ringsLand = burst + C.RingsFly,
		fadeStart = fadeStart,
		fadeEnd = fadeStart + C.FadeSeconds,
	}
end

-- Candidate k (1..Crash.Candidates) of the crash point, at the origin's height: Radius (then halfway to
-- MinRadius, then MinRadius) from the fight's centre, toward the ship (shipPos, horizontally), then 0.45 / 0.9
-- rad to either side; v3: its x offset (across the track) within maxAcross (the arena: Crash.MaxAcross; nil =
-- none). The server drops each on the floor (like a ring) and takes the first that has floor.
function SSE.CrashCandidate(origin: Vector3, shipPos: Vector3, k: number, maxAcross: number?): Vector3
	local C = SSE.Crash
	local i = math.max(0, math.floor(num(k, 1)) - 1)
	local angles = { 0, 0.45, -0.45, 0.9, -0.9 }
	local radii = { C.Radius, (C.Radius + C.MinRadius) / 2, C.MinRadius }
	local r = radii[math.min(#radii, i // #angles + 1)]
	local dx, dz = shipPos.X - origin.X, shipPos.Z - origin.Z
	local base = if dx * dx + dz * dz > 1e-6 then math.atan2(dz, dx) else math.pi / 2
	local a = base + angles[i % #angles + 1]
	local x = r * math.cos(a)
	if maxAcross then
		x = math.clamp(x, -maxAcross, maxAcross)
	end
	return Vector3.new(origin.X + x, origin.Y, origin.Z + r * math.sin(a))
end

-- The ship at server time t as numbers: offsets from the origin and yaw / pitch / roll (radians).
-- plan: a Plan (v2); a number (v1 introStart) or nil: the legacy v1 hover.
function SSE.BossOffset(origin: Vector3, t: number, plan: any): (number, number, number, number, number, number)
	if type(plan) ~= "table" then
		return legacyOffset(t, if type(plan) == "number" then plan else nil)
	end
	local key = seedKey(plan.seed)
	local e = SSE.Boss.EntryFrom
	local lx, ly, lz = e[1], e[2], e[3] -- v3: the arena path's entry point (offset from the origin)
	local start = num(plan.start, 0)
	local tau = t - start
	local endStart = tonumber(plan.endStart)
	if endStart == nil or not finite(endStart) or t <= (endStart :: number) then
		-- v3: in the lobby until the Teleport beat's move (world positions there).
		if tau < pathSchedule(key).entry0 then
			local lobby: Vector3 = if typeof(plan.lobbyOrigin) == "Vector3" then plan.lobbyOrigin else origin
			local lift = plan.liftOff
			local ax, ay, az
			if typeof(lift) == "Vector3" then
				ax, ay, az = lift.X, lift.Y, lift.Z
			else
				local d = SSE.Boss.DefaultLiftOff
				ax, ay, az = lobby.X + d[1], lobby.Y + d[2], lobby.Z + d[3]
			end
			local x, y, z, yaw, pitch, roll = lobbyValues(tau, ax, ay, az, lobby.X, lobby.Z)
			return x - origin.X, y - origin.Y, z - origin.Z, yaw, pitch, roll
		end
		return fightValues(tau, key, lx, ly, lz)
	end
	-- After the defeat / the escape: drift on with the velocity it had, hold, then fly away (C1 at endStart).
	local b = SSE.Boss
	local te = (endStart :: number) - start
	local x0, y0, z0, yaw0, pitch0, roll0 = fightValues(te, key, lx, ly, lz)
	local h = 1e-3
	local xa, ya, za = fightValues(te - h, key, lx, ly, lz)
	local xb, yb, zb = fightValues(te + h, key, lx, ly, lz)
	local vx, vy, vz = (xb - xa) / (2 * h), (yb - ya) / (2 * h), (zb - za) / (2 * h)
	local u = tau - te
	-- 2026-09-26 (owner): v3. The Defeat with a crash point: the crash (dive, impact, wreck).
	local crash = plan.crashPoint
	if plan.outcome == SSE.Phases.Defeat and typeof(crash) == "Vector3" then
		return crashValues(u, x0, y0, z0, yaw0, pitch0, roll0, vx, vy, vz,
			crash.X - origin.X, crash.Y - origin.Y + SSE.Crash.WreckLift, crash.Z - origin.Z)
	end
	local decay = (1 - math.exp(-b.EscapeDrag * u)) / b.EscapeDrag
	local defeat = plan.outcome ~= SSE.Phases.Escape
	local hold = if defeat then b.DefeatHold else b.EscapeHold
	local sink = if defeat then -b.DefeatSink * smoothstep(u / hold) else 0
	local fly = math.max(0, u - hold) / b.EscapeFlySeconds
	local f = fly * fly * fly
	local hl = math.sqrt(x0 * x0 + z0 * z0)
	local ox, oz = 0, 1
	if hl > 1e-3 then
		ox, oz = x0 / hl, z0 / hl
	end
	local x = x0 + vx * decay + ox * b.EscapeOut * f
	local y = y0 + vy * decay + sink + b.EscapeRise * f
	local z = z0 + vz * decay + oz * b.EscapeOut * f
	local spin = if defeat then TAU * b.DefeatSpins * smoothstep(u / hold) else 0
	local turn = math.pi * smoothstep(math.min(1, fly * 2)) -- turns to fly away nose first
	local yaw = yaw0 + spin + turn
	local pitch = pitch0 + (math.rad(b.EscapePitch) - pitch0) * smoothstep(fly)
	local wobble = if defeat then math.rad(b.DefeatWobble) * math.sin(TAU * u / 0.9) * smoothstep(u / 0.3) * (1 - smoothstep(fly)) else 0
	local roll = roll0 * (1 - smoothstep(u / 0.6)) + wobble
	return x, y, z, yaw, pitch, roll
end

-- The Egg Mobile's CFrame at server time t (forward -Z, facing the spawn). plan: see BossOffset.
function SSE.BossCFrame(origin: Vector3, t: number, plan: any): CFrame
	local x, y, z, yaw, pitch, roll = SSE.BossOffset(origin, t, plan)
	return CFrame.new(origin.X + x, origin.Y + y, origin.Z + z) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, roll)
end

-- The ship's centre (Vector3) at server time t.
function SSE.BossPosition(origin: Vector3, t: number, plan: any): Vector3
	local x, y, z = SSE.BossOffset(origin, t, plan)
	return Vector3.new(origin.X + x, origin.Y + y, origin.Z + z)
end

-- The ship's velocity (studs/s) at t (central difference over h seconds, default 1/60).
function SSE.BossVelocity(origin: Vector3, t: number, plan: any, h: number?): Vector3
	local dt = num(h, 1 / 60)
	local xa, ya, za = SSE.BossOffset(origin, t - dt, plan)
	local xb, yb, zb = SSE.BossOffset(origin, t + dt, plan)
	return Vector3.new((xb - xa) / (2 * dt), (yb - ya) / (2 * dt), (zb - za) / (2 * dt))
end

-- Where bombs leave the ship (the cannon's muzzle) at server time t.
function SSE.CannonPosition(origin: Vector3, t: number, plan: any): Vector3
	local c = SSE.Boss.Cannon
	return (SSE.BossCFrame(origin, t, plan) * CFrame.new(c[1], c[2], c[3])).Position
end

----------------------------------------------------------------------
-- Bombs
----------------------------------------------------------------------
-- A bomb's flight time (= its warning): battle = true for the Battle's faster bombs.
function SSE.BombFlightTime(from: Vector3, to: Vector3, battle: boolean?): number
	local b = SSE.Bombard
	local minimum = if battle then b.BattleFlightMin else b.FlightMin
	local perStud = if battle then b.BattleFlightPerStud else b.FlightPerStud
	local maximum = if battle then b.BattleFlightMax else b.FlightMax
	local dx, dz = to.X - from.X, to.Z - from.Z
	return math.clamp(minimum + math.sqrt(dx * dx + dz * dz) * perStud, minimum, maximum)
end

-- A bomb's position at t01 (0 = the cannon, 1 = the target): the straight line plus a parabolic rise
-- ArcHeight at the middle (the bomb pops up out of the cannon, then drops onto the target).
function SSE.BombArc(from: Vector3, to: Vector3, t01: number): Vector3
	local t = math.clamp(num(t01, 0), 0, 1)
	local rise = SSE.Bombard.ArcHeight * 4 * t * (1 - t)
	return Vector3.new(
		from.X + (to.X - from.X) * t,
		from.Y + (to.Y - from.Y) * t + rise,
		from.Z + (to.Z - from.Z) * t
	)
end

function SSE.InBlast(pos: Vector3, bombPos: Vector3): boolean
	local dx, dy, dz = pos.X - bombPos.X, pos.Y - bombPos.Y, pos.Z - bombPos.Z
	local r = SSE.Bombard.BlastRadius
	return dx * dx + dy * dy + dz * dz <= r * r
end

-- The blast's velocity for a character at pos: (pos - bombPos).Unit * 55 + (0, 42, 0). Straight on
-- top of the bomb (no direction) it throws toward -Z.
function SSE.Knockback(pos: Vector3, bombPos: Vector3): Vector3
	local b = SSE.Bombard
	local dx, dy, dz = pos.X - bombPos.X, pos.Y - bombPos.Y, pos.Z - bombPos.Z
	local length = math.sqrt(dx * dx + dy * dy + dz * dz)
	if length < 1e-3 then
		dx, dy, dz, length = 0, 0, -1, 1
	end
	return Vector3.new(dx / length * b.KnockOut, dy / length * b.KnockOut + b.KnockUp, dz / length * b.KnockOut)
end

-- Where to aim at a moving player: pos + horizontal velocity x flight x LeadFactor, at most LeadMaxStuds.
function SSE.LeadPoint(pos: Vector3, velocity: Vector3?, flight: number): Vector3
	if velocity == nil then
		return pos
	end
	local b = SSE.Bombard
	local lx, lz = velocity.X * flight * b.LeadFactor, velocity.Z * flight * b.LeadFactor
	local length = math.sqrt(lx * lx + lz * lz)
	if not finite(length) then
		return pos
	end
	if length > b.LeadMaxStuds then
		lx, lz = lx / length * b.LeadMaxStuds, lz / length * b.LeadMaxStuds
	end
	return Vector3.new(pos.X + lx, pos.Y, pos.Z + lz)
end

-- A Parallel line's horizontal offsets: `count` bombs Spacing apart, centred, across the direction (dx, dz)
-- (the ship -> target line). Returns { { x, z } }.
function SSE.ParallelOffsets(dx: number, dz: number, count: number, spacing: number?): { { number } }
	local s = num(spacing, SSE.Bombard.Parallel.Spacing)
	local l = math.sqrt(dx * dx + dz * dz)
	local px, pz = 1, 0
	if l > 1e-3 then
		px, pz = -dz / l, dx / l
	end
	local list = {}
	local n = math.max(1, math.floor(count))
	for j = 1, n do
		local k = (j - (n + 1) / 2) * s
		table.insert(list, { px * k, pz * k })
	end
	return list
end

----------------------------------------------------------------------
-- Emeralds
----------------------------------------------------------------------
-- Emerald i (1..Count) around the player's root, at time t (seconds): the orbit of radius 6,
-- y = sin(t * 4) * 1.5.
function SSE.EmeraldOrbit(i: number, t: number): Vector3
	local e = SSE.Emeralds
	local angle = t * e.SpinSpeed + (i - 1) * TAU / e.Count
	return Vector3.new(math.cos(angle) * e.OrbitRadius, math.sin(t * e.BobSpeed) * e.BobHeight, math.sin(angle) * e.OrbitRadius)
end

-- Emerald i during the Emeralds phase (phaseT = seconds since SSE_PhaseStart): the orbit, then the
-- convergence onto the root (radius and bob shrink to 0 by AbsorbAt); nil once absorbed.
function SSE.EmeraldOffset(i: number, phaseT: number): Vector3?
	local e = SSE.Emeralds
	if phaseT >= e.AbsorbAt then
		return nil
	end
	local orbit = SSE.EmeraldOrbit(i, phaseT)
	local convergeStart = e.AbsorbAt - e.ConvergeSeconds
	if phaseT <= convergeStart then
		return orbit
	end
	local k = 1 - smoothstep((phaseT - convergeStart) / e.ConvergeSeconds)
	return Vector3.new(orbit.X * k, orbit.Y * k, orbit.Z * k)
end

----------------------------------------------------------------------
-- The homing attack
----------------------------------------------------------------------
-- The homing attack's curve: a cubic Bezier from `from` (the player's root) to `to` (the ship) that
-- rises and swings to one side on the way. t01 = 0..1; exactly `from` at 0 and `to` at 1.
local function homingControls(from: Vector3, to: Vector3): (number, number, number, number, number, number)
	local h = SSE.Homing
	local dx, dy, dz = to.X - from.X, to.Y - from.Y, to.Z - from.Z
	local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
	local lift = math.clamp(dist * h.Lift, h.LiftMin, h.LiftMax)
	local swing = math.min(dist * h.Swing, h.SwingMax)
	-- The side: horizontal, perpendicular to the flight (none when the flight is straight up).
	local hl = math.sqrt(dx * dx + dz * dz)
	local sx, sz = 0, 0
	if hl > 1e-3 then
		sx, sz = -dz / hl * swing, dx / hl * swing
	end
	local p1x, p1y, p1z = from.X + dx * 0.2 + sx, from.Y + dy * 0.2 + lift, from.Z + dz * 0.2 + sz
	local p2x, p2y, p2z = from.X + dx * 0.75 + sx * 0.4, from.Y + dy * 0.75 + lift * 0.6, from.Z + dz * 0.75 + sz * 0.4
	return p1x, p1y, p1z, p2x, p2y, p2z
end

local function bezier(a: number, b: number, c: number, d: number, t: number): number
	local u = 1 - t
	return u * u * u * a + 3 * u * u * t * b + 3 * u * t * t * c + t * t * t * d
end

function SSE.HomingPath(from: Vector3, to: Vector3, t01: number): Vector3
	local t = math.clamp(num(t01, 0), 0, 1)
	local p1x, p1y, p1z, p2x, p2y, p2z = homingControls(from, to)
	return Vector3.new(bezier(from.X, p1x, p2x, to.X, t), bezier(from.Y, p1y, p2y, to.Y, t), bezier(from.Z, p1z, p2z, to.Z, t))
end

-- The curve's length (Samples straight segments; computed in numbers, so it is the same everywhere).
function SSE.HomingLength(from: Vector3, to: Vector3): number
	local p1x, p1y, p1z, p2x, p2y, p2z = homingControls(from, to)
	local n = SSE.Homing.Samples
	local length = 0
	local px, py, pz = from.X, from.Y, from.Z
	for k = 1, n do
		local t = k / n
		local x, y, z = bezier(from.X, p1x, p2x, to.X, t), bezier(from.Y, p1y, p2y, to.Y, t), bezier(from.Z, p1z, p2z, to.Z, t)
		length += math.sqrt((x - px) ^ 2 + (y - py) ^ 2 + (z - pz) ^ 2)
		px, py, pz = x, y, z
	end
	return length
end

-- How long the homing attack flies (s): its length / Speed (180 studs/s), at least MinDuration.
function SSE.HomingDuration(from: Vector3, to: Vector3): number
	return math.max(SSE.Homing.MinDuration, SSE.HomingLength(from, to) / SSE.Homing.Speed)
end

-- 2026-09-26 (owner): the ship moves more now, so the attack flies to where the ship WILL be when it arrives:
-- (to, duration) with to = BossPosition(launch + duration) exactly, and duration = HomingDuration(from, to)
-- to within a few milliseconds (fixed-point steps; the ship is far slower than the attack). HomingGo carries
-- exactly these, so the attack drawn along HomingPath(from, to) over `duration` ends on the ship.
function SSE.HomingIntercept(from: Vector3, origin: Vector3, launch: number, plan: any): (Vector3, number)
	local to = SSE.BossPosition(origin, launch, plan)
	local duration = SSE.HomingDuration(from, to)
	for _ = 1, 4 do
		to = SSE.BossPosition(origin, launch + duration, plan)
		duration = SSE.HomingDuration(from, to)
	end
	return SSE.BossPosition(origin, launch + duration, plan), duration
end

-- The charge (0..1) of a release at releaseAt after a press at pressAt (the server's own receive times),
-- over Homing.ChargeSeconds; never more than the client's own charge01 when it sends one. No press: 0.
function SSE.MeasureCharge(pressAt: any, releaseAt: any, clientCharge: any): number
	local p, r = tonumber(pressAt), tonumber(releaseAt)
	if p == nil or r == nil or not finite(p) or not finite(r) then
		return 0
	end
	local server = math.clamp(((r :: number) - (p :: number)) / SSE.Homing.ChargeSeconds, 0, 1)
	local c = tonumber(clientCharge)
	if c ~= nil and finite(c) then
		return math.min(server, math.clamp(c :: number, 0, 1))
	end
	return server
end

-- Damage of a homing hit: 1 + round(2 x charge) (1, 2 or 3).
function SSE.HomingDamage(charge: any): number
	local h = SSE.Homing
	return h.DamageBase + math.round(h.DamageCharged * math.clamp(num(charge, 0), 0, 1))
end

-- The ship's recoil on a hit (client visual): studs, degrees.
function SSE.BossRecoil(charge: any): (number, number)
	local h = SSE.Homing
	local c = math.clamp(num(charge, 0), 0, 1)
	return h.RecoilStuds + h.RecoilChargedStuds * c, h.RecoilDegrees + h.RecoilChargedDegrees * c
end

-- The bounce off the ship after a hit: (0, BounceUp + 30c, 0) - look * (BounceBack + 25c) (look flattened).
function SSE.HomingBounce(look: Vector3?, charge: any): Vector3
	local h = SSE.Homing
	local c = math.clamp(num(charge, 0), 0, 1)
	local lx, lz = 0, 0
	if look ~= nil then
		local l = math.sqrt(look.X * look.X + look.Z * look.Z)
		if l > 1e-4 then
			lx, lz = look.X / l, look.Z / l
		end
	end
	local back = h.BounceBack + h.BounceBackCharged * c
	return Vector3.new(-lx * back, h.BounceUp + h.BounceUpCharged * c, -lz * back)
end

-- 2026-09-26 (owner): v3. The shield's bounce: Shield.KnockOut studs/s horizontally from the ship toward where
-- the attack came from (fromPos - shipPos, flattened; straight under / over the ship: toward +Z) + KnockUp up.
function SSE.ShieldKnock(fromPos: Vector3, shipPos: Vector3): Vector3
	local s = SSE.Shield
	local dx, dz = fromPos.X - shipPos.X, fromPos.Z - shipPos.Z
	local l = math.sqrt(dx * dx + dz * dz)
	if not finite(l) or l < 1e-3 then
		dx, dz, l = 0, 1, 1
	end
	return Vector3.new(dx / l * s.KnockOut, s.KnockUp, dz / l * s.KnockOut)
end

-- The ship's position the server checks a homing request against: at the request's clientTime,
-- trusted at most MaxLag seconds back and never in the future.
function SSE.RewindTime(clientTime: any, now: number): number
	local t = tonumber(clientTime)
	if t == nil or not finite(t) then
		return now
	end
	return math.clamp(t :: number, now - SSE.Homing.MaxLag, now)
end

export type HomingInput = {
	phase: string?,
	on: boolean?, -- IsOn() (the kill switch)
	super: boolean?,
	alive: boolean?,
	racing: boolean?,
	stunned: boolean?, -- v2: thrown by a bomb moments ago
	inFlight: boolean?,
	hits: number?, -- v1 (the cap no longer refuses)
	lastAt: number?, -- the player's last accepted homing (server time)
	now: number,
	distance: number?, -- root -> ship (lag-compensated; the smaller of now / rewound)
	vulnerable: boolean?, -- v2: the arrival falls in a Reload window (BossVulnerable); false -> "Shielded"
}

-- The server's homing validation, in order: (true) or (false, reason from HomingRefusals).
function SSE.CheckHoming(input: HomingInput): (boolean, string?)
	local r = SSE.HomingRefusals
	if input.on == false then
		return false, r.Off
	end
	if input.phase ~= SSE.Phases.Battle then
		return false, r.Phase
	end
	if input.super ~= true then
		return false, r.NotSuper
	end
	if input.alive ~= true then
		return false, r.Dead
	end
	if input.racing == true then
		return false, r.Racing
	end
	if input.stunned == true then
		return false, r.Stunned
	end
	if input.inFlight == true then
		return false, r.Busy
	end
	local lastAt = tonumber(input.lastAt)
	if lastAt ~= nil and finite(lastAt) and input.now - (lastAt :: number) < SSE.Homing.Cooldown then
		return false, r.Cooldown
	end
	local distance = tonumber(input.distance)
	if distance == nil or not finite(distance) or (distance :: number) > SSE.Homing.Range + SSE.Homing.RangeSlack then
		return false, r.Range
	end
	if input.vulnerable == false then
		return false, r.Shielded
	end
	return true, nil
end

----------------------------------------------------------------------
-- Rings
----------------------------------------------------------------------
function SSE.RingCount(participants: number?): number
	local R = SSE.Rings
	local n = math.max(0, math.floor(num(participants, 0)))
	return math.clamp(R.Base + R.PerParticipant * n, R.Base, R.Max)
end

-- Candidate i (1, 2, ...; a retry uses i + count, i + 2 x count) of `count` rings: a point at the origin's
-- height, spread evenly by area between MinRadius and MaxRadius from the spawn (golden angle + seeded jitter);
-- each retry round comes RetryShrink closer to the spawn (a spot over the lobby's edge finds floor nearer in).
-- The server drops each one on the floor under it (a raycast) and sends the landed positions.
-- v3: scaleX (the arena: Rings.ScaleX) squeezes the x offsets (across the track); nil = 1.
function SSE.RingScatter(origin: Vector3, seed: any, i: number, count: number, scaleX: number?): Vector3
	local R = SSE.Rings
	local key = seedKey(seed)
	local n = math.max(1, math.floor(num(count, 1)))
	local k = math.max(0, math.floor(num(i, 1)) - 1)
	local round = k // n
	local frac = ((k % n) + hash01(key, k + 1, 12)) / n
	local r = R.MinRadius + (R.MaxRadius - R.MinRadius) * math.sqrt(frac) * R.RetryShrink ^ round
	local golden = math.pi * (3 - math.sqrt(5))
	local a = k * golden + hash01(key, 0, 13) * TAU + (hash01(key, k + 1, 11) - 0.5) * 0.6
	return Vector3.new(origin.X + r * math.cos(a) * num(scaleX, 1), origin.Y, origin.Z + r * math.sin(a))
end

export type RingInput = {
	exists: boolean?,
	taken: boolean?,
	now: number,
	landAt: number,
	expireAt: number,
	alive: boolean?,
	dx: number?, -- root - ring
	dy: number?,
	dz: number?,
	speed: number?, -- the taker's speed (latency slack)
	count: number?, -- rings this player took this event
}

-- The server's ring-take validation: (true) or (false, reason from RingRefusals).
function SSE.RingTakeCheck(input: RingInput): (boolean, string?)
	local R, why = SSE.Rings, SSE.RingRefusals
	if input.exists ~= true or input.taken == true or input.now > input.expireAt then
		return false, why.Gone
	end
	if input.now < input.landAt - R.EarlyGrace then
		return false, why.Early
	end
	if input.alive ~= true then
		return false, why.Dead
	end
	local dx, dy, dz = num(input.dx, INF), num(input.dy, INF), num(input.dz, INF)
	local slack = math.min(R.TakeSlackMax, math.max(0, num(input.speed, 0)) * R.TakeSlackSeconds)
	if math.sqrt(dx * dx + dz * dz) > R.TakeRadius + slack or math.abs(dy) > R.TakeHeight then
		return false, why.Far
	end
	if num(input.count, 0) >= R.MaxPerPlayer then
		return false, why.Cap
	end
	return true, nil
end

----------------------------------------------------------------------
-- The area
----------------------------------------------------------------------
-- Inside the fight's area (enter test; exitTest = the looser size a player keeps it until). v3: the race arena's
-- corridor round the origin (SSE_Origin): |dx| <= HalfX, |dz| <= HalfZ, the height band (v2: a circle).
-- 2026-09-26 (owner, critical: players stayed in the boss arena): the WHOLE race map around the fight's centre
-- (Shared/RaceNoFlight's zone: the water's area + 60 studs, from the staging box to past the end wall). The
-- fight's corridor box (Arena: 660 studs of the 2,120-stud track) is for the fight; the Return beat sweeps home
-- everyone on the race map, wherever they ran to.
SSE.RaceMap = { HalfX = 760, SMin = -660, SMax = 2960, YMin = -300, YMax = 1500 }
function SSE.InRaceMap(pos: Vector3, origin: Vector3): boolean
	local m = SSE.RaceMap
	local s = (origin.Z + SSE.RaceArena.TrackS) - pos.Z
	local dy = pos.Y - origin.Y
	return math.abs(pos.X - origin.X) <= m.HalfX and s >= m.SMin and s <= m.SMax and dy >= m.YMin and dy <= m.YMax
end

function SSE.InArena(pos: Vector3, origin: Vector3, exitTest: boolean?): boolean
	local a = SSE.Arena
	local dy = pos.Y - origin.Y
	if dy < -a.BelowOrigin or dy > a.AboveOrigin then
		return false
	end
	local hx = if exitTest then a.ExitHalfX else a.HalfX
	local hz = if exitTest then a.ExitHalfZ else a.HalfZ
	return math.abs(pos.X - origin.X) <= hx and math.abs(pos.Z - origin.Z) <= hz
end

-- 2026-09-26 (owner): v3. Inside the lobby area round the lobby spawn (v2's event area: a circle and a height band).
function SSE.InLobby(pos: Vector3, lobbyOrigin: Vector3, exitTest: boolean?): boolean
	local a = SSE.Lobby
	local dy = pos.Y - lobbyOrigin.Y
	if dy < -a.BelowOrigin or dy > a.AboveOrigin then
		return false
	end
	local dx, dz = pos.X - lobbyOrigin.X, pos.Z - lobbyOrigin.Z
	local r = if exitTest then a.ExitRadius else a.Radius
	return dx * dx + dz * dz <= r * r
end

-- 2026-09-26 (owner): v3. Whether the Teleport beat has moved everyone to the arena by (phase, phaseTime): from
-- Beats.Teleport.MoveAt on, through the Return beat (whose own move sends them home).
function SSE.Moved(phase: any, phaseTime: any): boolean
	phase = SSE.NormalizePhase(phase)
	if phase == "" or phase == SSE.Phases.Cinematic then
		return false
	elseif phase == SSE.Phases.Teleport then
		return num(phaseTime, 0) >= SSE.Beats.Teleport.MoveAt
	end
	return SSE.IsPhase(phase)
end

-- 2026-09-26 (owner): v3. Whether pos takes part in the event (targets, the Super form, no Flight, no invite):
-- in the arena round origin (SSE_Origin); before the Teleport beat's move (Moved false) the lobby round
-- lobbyOrigin (SSE_LobbyOrigin) too. Without a separate arena (lobbyOrigin nil, or origin == lobbyOrigin: a place
-- without the race arena) the lobby area alone.
function SSE.InEventArea(pos: Vector3, origin: Vector3, lobbyOrigin: Vector3?, moved: boolean?, exitTest: boolean?): boolean
	if lobbyOrigin == nil or (lobbyOrigin - origin).Magnitude < 1 then
		return SSE.InLobby(pos, origin, exitTest)
	end
	if SSE.InArena(pos, origin, exitTest) then
		return true
	end
	return moved ~= true and SSE.InLobby(pos, lobbyOrigin, exitTest)
end

-- 2026-09-26 (owner): v3. The fight's centre on the race arena (before the server drops it on the floor): the
-- track at s = RaceArena.TrackS, x 0. worldKey ("World1" | "World2" | "World3", SSE.WorldKey) picks
-- RaceArena.Origins[worldKey] when a world has its own; else the one arena of the three worlds.
function SSE.ArenaOrigin(worldKey: string?): Vector3
	local R = SSE.RaceArena
	local o = (worldKey and R.Origins[worldKey]) or R.Origin
	return Vector3.new(o[1], o[2], o[3] - R.TrackS)
end

----------------------------------------------------------------------
-- 2026-09-26 (owner): v3. The trip to the event (Invite -> TeleportToEvent)
----------------------------------------------------------------------
export type TeleportInput = {
	on: boolean?, -- IsOn() (the kill switch)
	phase: string?, -- the running event's phase ("" = none)
	sameEvent: boolean?, -- false: the request names another event's id
	alive: boolean?,
	racing: boolean?,
	afk: boolean?,
	busy: boolean?, -- a trip already on its way
	lastAt: number?, -- the player's last accepted trip (server time)
	now: number,
	inArena: boolean?, -- the root is already in the event's area
}

-- The server's trip validation, in order: (true) or (false, reason from TeleportRefusals).
function SSE.CheckTeleport(input: TeleportInput): (boolean, string?)
	local r = SSE.TeleportRefusals
	if input.on == false then
		return false, r.Off
	end
	if not SSE.InviteOpen(input.phase) or input.sameEvent == false then
		return false, r.Phase
	end
	if input.alive ~= true then
		return false, r.Dead
	end
	if input.racing == true then
		return false, r.Racing
	end
	if input.afk == true then
		return false, r.Afk
	end
	if input.busy == true then
		return false, r.Busy
	end
	local lastAt = tonumber(input.lastAt)
	if lastAt ~= nil and finite(lastAt) and input.now - (lastAt :: number) < SSE.Teleport.Cooldown then
		return false, r.Cooldown
	end
	if input.inArena == true then
		return false, r.Here
	end
	return true, nil
end

-- Candidate k (1..Teleport.Candidates) of a trip's landing spot, at the centre's height: spread by area over an
-- ellipse Across (x) by Along (z) round a golden-angle spiral, none closer than MinRadius (fixed: the same in
-- every event; the server drops each one on the floor and takes the first that is clear).
function SSE.TeleportCandidate(origin: Vector3, k: number): Vector3
	local T = SSE.Teleport
	local n = math.max(1, T.Candidates)
	local i = math.max(0, math.floor(num(k, 1)) - 1)
	local frac = ((i % n) + 0.5) / n
	local inner = math.clamp(T.MinRadius / T.Along, 0, 0.9)
	local r = inner + (1 - inner) * math.sqrt(frac)
	local a = i * math.pi * (3 - math.sqrt(5))
	local x, z = r * T.Across * math.cos(a), r * T.Along * math.sin(a)
	local d = math.sqrt(x * x + z * z)
	if d < T.MinRadius and d > 1e-6 then
		x, z = x / d * T.MinRadius, z / d * T.MinRadius
	end
	return Vector3.new(origin.X + x, origin.Y, origin.Z + z)
end

-- Whether a landing spot is clear: Teleport.Clearance studs (horizontal) from every position in `others`
-- (players, spots just handed out) and outside every blast in `bombs` (their landing points) + BombMargin.
function SSE.SpotClear(spot: Vector3, others: { Vector3 }?, bombs: { Vector3 }?): boolean
	local T = SSE.Teleport
	for _, pos in others or {} do
		local dx, dz = pos.X - spot.X, pos.Z - spot.Z
		if dx * dx + dz * dz < T.Clearance * T.Clearance then
			return false
		end
	end
	local reach = SSE.Bombard.BlastRadius + T.BombMargin
	for _, pos in bombs or {} do
		local dx, dz = pos.X - spot.X, pos.Z - spot.Z
		if dx * dx + dz * dz < reach * reach then
			return false
		end
	end
	return true
end

----------------------------------------------------------------------
-- Where the event happens
----------------------------------------------------------------------
-- The world's key from Shared/Config's place flags ("World1" / "World2" / "World3", nil elsewhere).
function SSE.WorldKey(config: any): string?
	if type(config) ~= "table" then
		return nil
	end
	if config.IsWorld3Place == true then
		return "World3"
	elseif config.IsWorld2Place == true then
		return "World2"
	elseif config.IsNewWorld1Map == true then
		return "World1"
	end
	return nil
end

-- The top of each world's lobby SpawnLocation (read from the three places, 2026-09-26: World 1
-- Workspace.neworld1.SpawnLocation, World 2 Workspace.Spawn, World 3 Workspace.Lobby.SpawnLocation).
-- PickSpawn takes the live spawn nearest to these; they stand in when a place has none.
SSE.FallbackOrigins = {
	World1 = { 280.28, 37467.06, -1781.14 },
	World2 = { -783.83, 36627.15, -993.76 },
	World3 = { 265.30, 94.98, 521.64 },
}
SSE.SpawnSearchRadius = 400 -- a spawn farther than this from the world's own is not the lobby's

-- The event's origin: the spawn point (the top of the world's SpawnLocation, which the server
-- finds), else this world's fallback, else (0, 50, 0).
function SSE.WorldOrigin(spawnPosition: Vector3?, config: any): Vector3
	if spawnPosition ~= nil and finite(spawnPosition.X) and finite(spawnPosition.Y) and finite(spawnPosition.Z) then
		return spawnPosition
	end
	local key = SSE.WorldKey(config)
	local fallback = key and SSE.FallbackOrigins[key]
	if fallback then
		return Vector3.new(fallback[1], fallback[2], fallback[3])
	end
	return Vector3.new(0, 50, 0)
end

-- The lobby spawn among the enabled SpawnLocations' tops (a list of Vector3): the one nearest this world's
-- FallbackOrigins entry, within SpawnSearchRadius; nil when none is (WorldOrigin then uses the fallback).
-- Outside the three worlds (no key): the first one.
function SSE.PickSpawn(tops: { Vector3 }, config: any): Vector3?
	local key = SSE.WorldKey(config)
	local fallback = key and SSE.FallbackOrigins[key]
	if not fallback then
		return tops[1]
	end
	local best, bestDistance = nil, SSE.SpawnSearchRadius
	for _, top in tops do
		local d = math.sqrt((top.X - fallback[1]) ^ 2 + (top.Y - fallback[2]) ^ 2 + (top.Z - fallback[3]) ^ 2)
		if d <= bestDistance then
			best, bestDistance = top, d
		end
	end
	return best
end

-- The feature flag + the live kill switch (Workspace attribute U4Off_SuperSonicEvent = true).
function SSE.IsOn(): boolean
	if SSE.Enabled ~= true then
		return false
	end
	if typeof(game) ~= "Instance" then
		return true
	end
	local ok, off = pcall(function()
		return game:GetService("Workspace"):GetAttribute(SSE.KillAttribute)
	end)
	return not (ok and off == true)
end

return SSE
