-- test_u4_supersonic_event.luau (2026-09-26, owner: the "Super Sonic vs Dr. Eggman" live event, server side)
-- 2026-09-26 (owner): v2 after the owner tested v1. Checked here:
--   1. the contract (Shared/SuperSonicEvent): the protocol names, the timeline (Cinematic .. Defeat / Escape),
--      the dialogue cues and sounds, the owner's numbers (HP formula, 600 / 30,000 x 45, rings 50 / 2,500 x 30,
--      warnings, charge 1.6 s), the old names kept (Phases.Intro, legacy BossCFrame);
--   2. its pure functions: the boss schedule (Attack / Reload windows from the seed, BossState, Reload-only
--      hits + 0.15 s grace), the salvos and dives, the boss path (lift-off from the lobby spot, C1-continuous
--      over the whole event incl. every window change and the flight away, low and slow in Reload, facing the
--      spawn), the cannon, bombs (flight = warning >= 1.0 / 1.4 s, lead, Parallel lines), the charge (measured,
--      clamped, capped by the client's own), damage / recoil / bounce, HomingIntercept, CheckHoming (Stunned,
--      Shielded), the rings (count, scatter, take check), the spawn helpers;
--   3. the server state machine (Gameplay/SuperSonicEventCore) with fake players and a fake clock: the phases,
--      Bombard salvos (Aimed / Parallel / Aimed, led, exact throws, no kill), the transformation, the Battle's
--      Attack / Reload mirror, salvos only in Attack windows that throw Super players too, Shielded outside
--      Reload, charged homing (server-measured, damage 1..3, HomingGo / Hit fields), rewards (the cap: later
--      hits land unpaid), the defeat's ring rain (floor raycasts, take validation, rewards, late joiners,
--      expiry, cleared by an admin stop), the escape, the kill switch, leaving / dying / racing / the area,
--      late joiners raising the HP, the no-flight flags, the rate limit, determinism by seed;
--   4. the Roblox glue (Gameplay/SuperSonicEventService, as text and in a small fake Roblox): the remote, the
--      skin override calls, the no-flight attribute, the lift-off point, the ragdoll, the _G API, the
--      before-release save, the kill switch;
--   5. the temporary skin (Economy/SkinSystem's SKIN OVERRIDE, run with fakes): the Super Sonic skin put on
--      without ownership or saving, the player's own skin back exactly, respawns, the player's own choice;
--   6. the admin panel; 7. the build step (audit/u4_supersonic_assets). With `places`: the three places.
-- 2026-09-26 (owner): v3 (the owner's next tests). Also checked: the fight on the race arena (the Cinematic in the
-- lobby, the Teleport beat moving the lobby to the arena, the entrance, the fight's area = the arena corridor,
-- the Return beat sending everyone home, an admin stop sending them home at once, the arena's gates opened and
-- restored), the races closed during the event (the real RaceService: every heat called off without penalties,
-- the arena's players sent to the lobby spawn, the queue / gate closed with RaceClosedBy, reopened after), the
-- invites (start / race / joined / respawn / left) and TeleportToEvent's checks, the freeze windows (no throws,
-- falls put back, deaths forgiven), the fast homing (320 studs/s), the uncharged jump attack, the stale charge,
-- the shield's bounce, the 0.7 s charge, the lower HP (a measured table) and the HP-0 regression (a hit landing
-- at the Battle's last moment or just after it always defeats him: the crash on the floor, the rings from the
-- crash point, never the Escape).
-- The no-flight rule's event reason (Shared/RaceNoFlight, FlightService, the notice) is in test_u4_race_noflight.
-- Run: lune run audit/test_u4_supersonic_event.luau [places]   (from the project root)
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local Vector3 = roblox.Vector3
local CFrame = roblox.CFrame

local SSE = require("../src/common/ReplicatedStorage/Shared/SuperSonicEvent")
local Core = require("../src/common/ServerScriptService/Gameplay/SuperSonicEventCore")
local Assets = require("./u4_supersonic_assets")

local passed = 0
local function pass(text)
	passed += 1
	print("PASS " .. text)
end
local function near(a, b, tolerance, message)
	assert(math.abs(a - b) <= (tolerance or 1e-6), message .. " (" .. tostring(a) .. " vs " .. tostring(b) .. ")")
end
local function nearV(a, b, tolerance, message)
	local d = (a - b).Magnitude
	assert(d <= (tolerance or 1e-3), message .. " (off by " .. d .. ": " .. tostring(a) .. " vs " .. tostring(b) .. ")")
end
local function has(source, needle, message)
	assert(string.find(source, needle, 1, true), message .. " (missing: " .. needle .. ")")
end
local function between(source, first, last)
	local a = assert(string.find(source, first, 1, true), "chunk start " .. first)
	local b = assert(string.find(source, last, a + #first, true), "chunk end " .. last)
	return string.sub(source, a, b - 1)
end
local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

-- World 1's spawn: the sky lobby (float32 positions hold ~0.004 studs up there).
local ORIGIN = Vector3.new(280.28, 37467.06, -1781.14)
-- World 1's lobby Eggman's hull centre (his spot at (219, 37468.04, -1820), 3 studs up).
local LIFT = Vector3.new(219, 37471.04, -1820)
local SEED = 12345
local D = SSE.Durations
-- 2026-09-26 (owner): v3: the fight's centre on the race arena (the track at s = TrackS, on the floor top).
local ARENA = SSE.ArenaOrigin("World1")

----------------------------------------------------------------------
-- 1. The contract
----------------------------------------------------------------------
do
	assert(SSE.Version == 3, "contract v3")
	assert(SSE.KillAttribute == "U4Off_SuperSonicEvent", "kill switch name")
	assert(SSE.RemoteName == "SuperSonicEvent" and SSE.RemotesFolder == "Remotes", "remote")
	local A = SSE.Attributes
	assert(A.Phase == "SSE_Phase" and A.PhaseStart == "SSE_PhaseStart" and A.EventId == "SSE_EventId" and A.Seed == "SSE_Seed"
		and A.BossHP == "SSE_BossHP" and A.BossMaxHP == "SSE_BossMaxHP" and A.Origin == "SSE_Origin", "world attributes (v1)")
	assert(A.EventStart == "SSE_EventStart" and A.LiftOff == "SSE_LiftOff" and A.BossState == "SSE_BossState"
		and A.BossStateStart == "SSE_BossStateStart" and A.BossStateEnd == "SSE_BossStateEnd", "world attributes (v2)")
	local PA = SSE.PlayerAttributes
	assert(PA.Super == "SSE_Super" and PA.Hits == "SSE_Hits" and PA.WalkSpeed == "SSE_WalkSpeed" and PA.Skin == "SSE_Skin" and PA.Rings == "SSE_Rings", "player attributes")
	local P = SSE.Phases
	assert(P.None == "" and P.Cinematic == "Cinematic" and P.Bombard == "Bombard" and P.Emeralds == "Emeralds" and P.Battle == "Battle"
		and P.Defeat == "Defeat" and P.Escape == "Escape" and P.Teleport == "Teleport" and P.Return == "Return", "phases (+ v3's beats)")
	assert(P.Intro == "Cinematic" and D.Intro == D.Cinematic and SSE.NormalizePhase("Intro") == "Cinematic", "v1's Intro kept as the Cinematic's alias")
	assert(table.concat(SSE.PhaseOrder, ",") == "Cinematic,Teleport,Bombard,Emeralds,Battle,Defeat,Return", "phase order")
	assert(SSE.NextPhase("Cinematic") == "Teleport" and SSE.NextPhase("Teleport") == "Bombard" and SSE.NextPhase("Battle") == "Defeat"
		and SSE.NextPhase("Defeat") == "Return" and SSE.NextPhase("Escape") == "Return" and SSE.NextPhase("Return") == ""
		and SSE.NextPhase("Intro") == "Teleport", "NextPhase (v3: the beats)")
	assert(SSE.IsPhase("") and SSE.IsPhase("Escape") and SSE.IsPhase("Cinematic") and SSE.IsPhase("Return") and SSE.IsPhase("Teleport")
		and not SSE.IsPhase("Boss"), "IsPhase")
	local M = SSE.Messages
	for _, name in { "Bomb", "BombHit", "Hit", "Reward", "Defeat", "Homing", "HomingGo", "HomingNo", "Escape", "Knock",
		"Charge", "Rings", "RingGone", "RingNo", "RingsClear", "RingTake", "ShieldHit", "Invite", "TeleportGo", "TeleportNo", "TeleportToEvent" } do
		assert(M[name] == name, "message " .. name)
	end
	assert(SSE.HomingRefusals.Shielded == "Shielded" and SSE.HomingRefusals.Stunned == "stunned", "the v2 refusals")
	-- The timeline: 7.5 s Cinematic, a short Bombard, the Battle, 6-7 s cinematics at the end.
	assert(D.Cinematic >= 7 and D.Cinematic <= 8, "Cinematic 7-8 s")
	assert(D.Bombard < 17 and D.Bombard >= 8, "the Bombard is shorter than v1's 17 s (the Battle has attacks now)")
	assert(D.Escape >= 6 and D.Escape <= 7.5, "the Escape long enough for the flight away")
	assert(D.Teleport == 4.5 and D.Return == 2.5 and D.Defeat == 20, "v3: the beats, the Defeat holds the ring collection")
	local crash0 = SSE.CrashTimes(0)
	assert(crash0.ringsLand + SSE.Rings.LifeSeconds < D.Defeat and crash0.fadeEnd < D.Defeat, "the rings expire and the wreck fades before the Return")
	assert(SSE.PhaseOffset("Cinematic") == 0 and SSE.PhaseOffset("Teleport") == D.Cinematic and SSE.PhaseOffset("Bombard") == D.Cinematic + D.Teleport
		and SSE.PhaseOffset("Battle") == D.Cinematic + D.Teleport + D.Bombard + D.Emeralds and SSE.PhaseOffset("Defeat") == nil, "PhaseOffset")
	local B = SSE.Beats
	assert(B.Teleport.FadeOut <= B.Teleport.MoveAt and B.Teleport.MoveAt < B.Teleport.FadeIn and B.Teleport.FadeIn < D.Teleport
		and B.Return.MoveAt < B.Return.FadeIn and B.Return.FadeIn < D.Return, "the beats: fade out, move, fade in, inside their phases")
	-- The dialogue cues: keys only, inside their phases; the owner's lines are there.
	local keys = {}
	for _, cue in SSE.Dialogue do
		assert(SSE.IsPhase(cue[1]) and cue[1] ~= "", "cue phase " .. tostring(cue[1]))
		assert(type(cue[2]) == "number" and cue[2] >= 0 and cue[2] < SSE.PhaseDuration(cue[1]), "cue inside its phase: " .. cue[3])
		assert(type(cue[3]) == "string", "cue key")
		keys[cue[1] .. ":" .. cue[3]] = true
	end
	assert(keys["Cinematic:EggmanSonic"] and keys["Cinematic:EggmanRevenge"] and keys["Escape:EggmanBeBack"],
		"Sonic! / revenge in the Cinematic, I'll be back in the Escape")
	assert(#SSE.DialogueFor("Defeat") == 0, "v3: no dialogue in the Defeat (the crash)")
	local cues = SSE.DialogueFor("Intro")
	assert(#cues == 2 and cues[1].key == "EggmanSonic" and cues[1].t < cues[2].t, "DialogueFor sorts (and takes the old name)")
	local S = SSE.Sounds
	assert(S.Music == "rbxassetid://133261865867143" and S.RingPickup == "rbxassetid://112771432761858" and S.RingsDrop == "rbxassetid://102136054782395"
		and S.EggmanBeBack == "rbxassetid://103892608635163" and S.Charge == "rbxassetid://93126470207724", "the owner's audio")
	assert(SSE.DialogueSounds.EggmanBeBack == "EggmanBeBack" and SSE.Homing.ChargeSound == S.Charge, "the goodbye's recording, the charge sound")
	-- The owner's numbers.
	assert(SSE.Bombard.BlastRadius == 22 and SSE.Bombard.KnockOut == 55 and SSE.Bombard.KnockUp == 42 and SSE.Bombard.RagdollSeconds == 2, "blast 22, 55 / 42, 2 s")
	assert(SSE.Warning.Radius == SSE.Bombard.BlastRadius, "the red zone is the blast")
	assert(SSE.Warning.MinSeconds >= 0.9 and SSE.Warning.MinSeconds <= 1.1 and SSE.Bombard.BattleFlightMin == SSE.Warning.MinSeconds, "Battle warning 0.9-1.1 s")
	assert(SSE.Bombard.FlightMin == SSE.Warning.BombardMinSeconds and SSE.Bombard.BattleFlightMax < SSE.Bombard.FlightMax, "faster bombs in the Battle")
	assert(SSE.Emeralds.OrbitRadius == 6 and SSE.Emeralds.BobSpeed == 4 and SSE.Emeralds.BobHeight == 1.5 and SSE.Emeralds.Count == 7, "emeralds")
	assert(SSE.Super.WalkSpeed == 120 and SSE.Super.JumpPower == 90 and SSE.Super.SkinId == "SuperSonicSuit", "Super Sonic 120 / 90, the real skin")
	assert(SSE.Homing.Range == 180 and SSE.Homing.Speed == 320 and SSE.Homing.ChargeSeconds == 0.7, "v3: homing range 180, 320 studs/s, full charge in 0.7 s")
	assert(SSE.Shield.KnockOut == 70 and SSE.Shield.KnockUp == 30 and SSE.Shield.RagdollSeconds == 0, "v3: the shield throws 70 out + 30 up, no ragdoll")
	assert(SSE.Rewards.HitWins == 600 and SSE.Rewards.HitSpeed == 30000 and SSE.Rewards.MaxRewardedHits == 45, "+600 Wins +30,000 Speed a hit, 45 paid")
	local v1Total, v2Total = 1000 * 25, SSE.Rewards.HitWins * SSE.Rewards.MaxRewardedHits
	assert(v2Total >= v1Total and v2Total <= v1Total * 1.2, "the most a player earns stays about v1's (" .. v2Total .. ")")
	local R = SSE.Rings
	assert(R.RewardWins == 50 and R.RewardSpeed == 2500 and R.MaxPerPlayer == 30, "a ring: +50 Wins +2,500 Speed, 30 a player")
	near(R.RewardWins / SSE.Rewards.HitWins, 1 / 12, 1e-9, "a ring = 1/12 of a hit's Wins")
	near(R.RewardSpeed / SSE.Rewards.HitSpeed, 1 / 12, 1e-9, "a ring = 1/12 of a hit's Speed")
	assert(R.LifeSeconds >= 12 and R.LifeSeconds <= 20 and R.TakeRadius == 8, "v3: rings ~16 s (before the Return beat), 8 studs")
	assert(SSE.HP.Base == 34 and SSE.BossMaxHP(0) == 34 and SSE.BossMaxHP(1) == 34 and SSE.BossMaxHP(1000) == SSE.HP.Max, "v3: HP from 34")
	for _, n in { 2, 4, 8, 16 } do
		assert(SSE.BossMaxHP(n) == math.round(34 * n ^ 0.95), "HP = round(34 x n^0.95) for " .. n)
	end
	for n = 1, 40 do -- (the Max clamp starts at ~57)
		assert(SSE.BossMaxHP(n + 1) > SSE.BossMaxHP(n), "HP grows with every participant")
	end
	local C = SSE.Camera
	assert(C.BombHit.Shake[1] == 0.35 and C.BombHit.Fov == 12 and C.HomingHit.Fov == -6 and C.Defeat.Fov == 18, "camera punches")
	-- The Bombard fits its salvos: the last bomb of the biggest salvo lands before the phase ends.
	local last = SSE.Bombard.SalvoTimes[3] + (SSE.Bombard.BombsMax - 1) * SSE.Bombard.BombStagger + SSE.Bombard.FlightMax
	assert(last < D.Bombard, "every Bombard bomb lands inside the Bombard (" .. last .. ")")
	assert(#SSE.Bombard.SalvoTimes == SSE.Bombard.Salvos and table.concat(SSE.Bombard.Patterns, ",") == "Aimed,Parallel,Aimed", "Bombard: Aimed, Parallel, Aimed")
	assert(SSE.Boss.LiftHold < SSE.Boss.LeaveAt and SSE.Boss.LeaveAt + SSE.Boss.LeaveSeconds <= D.Cinematic + SSE.Beats.Teleport.MoveAt + 1e-9,
		"v3: he lifts off, then leaves the lobby before the Teleport beat's move")
	assert(SSE.Emeralds.AbsorbAt < D.Emeralds, "the absorption inside the Emeralds phase")
	assert(SSE.Boss.DefeatHold < D.Defeat and SSE.Boss.EscapeHold < D.Escape, "he flies away before the end")
	pass("contract: names (v1 kept + v2 + v3), timeline 7.5 / 4.5 / 9.5 / 7 / 150 / 20 | 7 / 2.5, dialogue keys (none in the Defeat) + the owner's sounds, HP 34 x n^0.95, homing 320 / charge 0.7 s, shield 70 / 30, 600 / 30,000 x 45, rings 50 / 2,500 x 30, red zone = blast 22, warning 1.0 / 1.4 s")
end

----------------------------------------------------------------------
-- 2. The pure functions
----------------------------------------------------------------------
-- 2a. The boss schedule.
do
	local B = SSE.Battle
	for _, seed in { SEED, 777, 1, 2147483646 } do
		local windows = SSE.BossWindows(seed)
		assert(windows[1].state == "Attack" and windows[1].start == 0 and windows[1].finish == B.FirstAttack, "the Battle opens with a 5 s Attack")
		local reloads = 0
		for i, w in windows do
			assert(w.finish > w.start, "a window has a length")
			if i > 1 then
				assert(w.start == windows[i - 1].finish, "windows are contiguous")
				assert(w.state ~= windows[i - 1].state, "Attack and Reload alternate")
			end
			local length = w.finish - w.start
			if w.state == "Reload" then
				reloads += 1
				assert(length >= B.MinTail - 1e-9 and length <= B.ReloadMax + B.MinTail + 1e-9, "Reload length " .. length)
			elseif i > 1 then
				assert(length >= B.MinTail - 1e-9 and length <= B.AttackMax + B.MinTail + 1e-9, "Attack length " .. length)
			end
		end
		assert(windows[#windows].finish == D.Battle, "the windows cover the whole Battle")
		assert(reloads >= 9 and reloads <= 12, "9-12 Reload windows (" .. reloads .. ")")
		-- BossState agrees with the windows; before / after the Battle: Attack.
		for _, w in windows do
			local mid = (w.start + w.finish) / 2
			local state, s, f = SSE.BossState(mid, seed)
			assert(state == w.state and s == w.start and f == w.finish, "BossState at a window's middle")
			assert(SSE.BossVulnerable(mid, seed) == (w.state == "Reload"), "vulnerable only in Reload")
			if w.state == "Reload" then
				assert(SSE.BossVulnerable(w.start - 0.14, seed) and SSE.BossVulnerable(w.finish + 0.14, seed), "+-0.15 s grace")
				if w.start > 0.5 then
					assert(not SSE.BossVulnerable(w.start - 0.16, seed), "not before the grace")
				end
				if w.finish < D.Battle - 0.5 then
					assert(not SSE.BossVulnerable(w.finish + 0.16, seed), "not after the grace")
				end
			end
		end
		assert(SSE.BossState(-1, seed) == "Attack" and SSE.BossState(D.Battle + 1, seed) == "Attack", "outside the Battle: Attack")
		assert(not SSE.BossVulnerable(-1, seed) and not SSE.BossVulnerable(D.Battle + 5, seed), "never vulnerable outside it")
		-- Salvos: only in Attack windows, not in their last SalvoTail, gaps shrinking, the 2nd a Parallel line.
		local salvos = SSE.BattleSalvos(seed)
		local perWindow = {}
		for _, salvo in salvos do
			local state, s, f = SSE.BossState(salvo.t, seed)
			assert(state == "Attack" and salvo.t >= s + B.SalvoLead - 1e-9 and salvo.t <= f - B.SalvoTail + 1e-9, "a salvo inside an Attack window")
			assert(SSE.BombPatterns[salvo.pattern] == salvo.pattern, "a known pattern")
			if salvo.index == B.ParallelAt then
				assert(salvo.pattern == "Parallel", "the 2nd salvo of a window is a Parallel line")
			end
			perWindow[salvo.window] = (perWindow[salvo.window] or 0) + 1
		end
		local firstFull, lastFull = nil, nil
		for _, w in windows do
			if w.state == "Attack" and w.index >= 2 and w.finish - w.start >= B.AttackMin - 1e-9 then
				firstFull = firstFull or perWindow[w.index]
				lastFull = perWindow[w.index]
			end
		end
		assert(firstFull and lastFull and lastFull > firstFull, "more salvos as the fight goes on (" .. tostring(firstFull) .. " -> " .. tostring(lastFull) .. ")")
		-- Dives: inside Attack windows (from the 2nd), clear of the window's ends.
		local dives = SSE.BossDives(seed)
		assert(#dives >= 5, "dives through the fight")
		for _, dive in dives do
			local state, s, f = SSE.BossState(dive.start + 0.01, seed)
			assert(state == "Attack" and dive.start >= s + SSE.Boss.DiveLead - 1e-9 and dive.finish <= f - SSE.Boss.DiveTail + 1e-9, "a dive inside its Attack window")
		end
	end
	-- Seeded and repeatable.
	local a, b, c = SSE.BossWindows(SEED), SSE.BossWindows(SEED), SSE.BossWindows(SEED + 1)
	assert(a == b, "cached per seed")
	local differs = false
	for i = 2, math.min(#a, #c) do
		if math.abs(a[i].finish - c[i].finish) > 1e-6 then
			differs = true
		end
	end
	assert(differs, "another seed, another rhythm")
	near(SSE.Hash01(SEED, 3, 4), SSE.Hash01(SEED, 3, 4), 0, "Hash01 repeatable")
	pass("schedule: Attack 5 s then Reload 5.5-6.5 / Attack 7-9 (seeded) over 150 s; BossState / BossVulnerable (+-0.15 s); salvos only in Attack windows, more later, 2nd = Parallel; dives inside Attack windows")
end

-- 2b. The boss path. 2026-09-26 (owner): v3: the lobby (the lift-off, the lines, the departure) until the Teleport
-- beat's move, then the arena (the entrance, the fight over the corridor), the crash or the flight away.
do
	local plan = SSE.Plan(1000, SEED, LIFT, nil, nil, nil, ORIGIN)
	local b = SSE.Boss
	local entry0 = 1000 + SSE.PhaseOffset("Teleport") + SSE.Beats.Teleport.EntryStart
	local bombard0 = 1000 + SSE.PhaseOffset("Bombard")
	-- The lift-off: exactly the lobby Eggman's hull, facing the lobby spawn as he stands there, then straight up.
	nearV(SSE.BossPosition(ARENA, 1000, plan), LIFT, 0.02, "the Cinematic starts at the lobby spot")
	local lookAtLift = SSE.BossCFrame(ARENA, 1000, plan).LookVector
	assert(flat(lookAtLift).Unit:Dot(flat(ORIGIN - LIFT).Unit) > 0.999, "he faces the lobby spawn, as at his spot")
	local up = SSE.BossPosition(ARENA, 1000 + b.LiftHold, plan)
	nearV(up, LIFT + Vector3.new(0, b.LiftRise, 0), 0.05, "straight up LiftRise first")
	-- He leaves the lobby: up and away before the move.
	local gone = SSE.BossPosition(ARENA, entry0 - 0.02, plan)
	assert(gone.Y > LIFT.Y + 100 and flat(gone - LIFT).Magnitude > 150, "gone up and away by the Teleport beat's move")
	-- C1 in the lobby (the lift-off, the hover, the departure) and in the arena (the entrance to the end of the Battle).
	local dt = 1 / 60
	local function scanC1(t0, t1)
		local prev, prevV = nil, nil
		local maxSpeed, maxAccel = 0, 0
		for k = 0, math.floor((t1 - t0) / dt) do
			local t = t0 + k * dt
			local x, y, z = SSE.BossOffset(ARENA, t, plan)
			if prev then
				local v = Vector3.new((x - prev.X) / dt, (y - prev.Y) / dt, (z - prev.Z) / dt)
				maxSpeed = math.max(maxSpeed, v.Magnitude)
				if prevV then
					maxAccel = math.max(maxAccel, (v - prevV).Magnitude / dt)
				end
				prevV = v
			end
			prev = Vector3.new(x, y, z)
		end
		return maxSpeed, maxAccel
	end
	local lobbySpeed, lobbyAccel = scanC1(1000, entry0 - 0.02)
	assert(lobbyAccel < 600, "the lobby part is C1 (max accel " .. lobbyAccel .. ")")
	local total = SSE.PhaseOffset("Battle") + D.Battle
	local maxSpeed, maxAccel = scanC1(entry0 + 0.001, 1000 + total)
	assert(maxSpeed < 130, "the ship never faster than 130 studs/s in the arena (" .. maxSpeed .. ")")
	assert(maxAccel < 600, "no velocity jumps in the arena: C1 (max accel " .. maxAccel .. " studs/s^2)")
	local minRadius, maxAcross = math.huge, 0
	for k = 0, math.floor((total - SSE.PhaseOffset("Bombard")) / 0.05) do
		local t = bombard0 + k * 0.05
		local x, _, z = SSE.BossOffset(ARENA, t, plan)
		minRadius = math.min(minRadius, math.sqrt(x * x + z * z))
		maxAcross = math.max(maxAcross, math.abs(x))
	end
	assert(minRadius >= b.DiveRadius * b.OrbitScaleX - 0.01, "never over the centre's axis (" .. minRadius .. ")")
	assert(maxAcross <= (b.OrbitRadius + b.OrbitWobble) * b.OrbitScaleX + 0.01 and maxAcross <= 36, "over the 72-stud corridor (|x| " .. maxAcross .. ")")
	-- The entrance: from EntryFrom (high, down the track) into the orbit by the Bombard.
	nearV(SSE.BossPosition(ARENA, entry0 + 1e-4, plan), ARENA + Vector3.new(table.unpack(b.EntryFrom)), 0.05, "he enters the arena from EntryFrom")
	-- Exactly at every window boundary: the velocity on both sides agrees.
	local battle0 = 1000 + SSE.PhaseOffset("Battle")
	for _, w in SSE.BossWindows(SEED) do
		local t = battle0 + w.start
		local before = SSE.BossVelocity(ARENA, t - 0.002, plan, 0.001)
		local after = SSE.BossVelocity(ARENA, t + 0.002, plan, 0.001)
		assert((after - before).Magnitude < 3, "C1 at a window change (" .. (after - before).Magnitude .. ")")
	end
	-- Attack high and quick, Reload low and slow; facing the fight's centre.
	local W = SSE.BossWindows(SEED)
	local reloadW, attackW = W[4], W[5]
	assert(reloadW.state == "Reload" and attackW.state == "Attack", "seed 12345's 4th / 5th windows")
	local function sample(w)
		local ys, speeds = {}, {}
		for k = 1, 9 do
			local t = battle0 + w.start + b.Ramp + (w.finish - w.start - b.Ramp - 0.2) * k / 10
			local pos = SSE.BossPosition(ARENA, t, plan)
			table.insert(ys, pos.Y - ARENA.Y)
			table.insert(speeds, SSE.BossVelocity(ARENA, t, plan).Magnitude)
			local cf = SSE.BossCFrame(ARENA, t, plan)
			assert(flat(cf.LookVector).Unit:Dot(flat(ARENA - pos).Unit) > 0.999, "faces the fight's centre")
		end
		return ys, speeds
	end
	local ry, rs = sample(reloadW)
	for i = 1, #ry do
		assert(math.abs(ry[i] - b.ReloadHeight) <= b.ReloadBob + 0.05, "Reload: low (" .. ry[i] .. ")")
		assert(rs[i] < 12, "Reload: slow (" .. rs[i] .. " studs/s)")
	end
	local ay, as = sample(attackW)
	local fastest = 0
	for i = 1, #ay do
		assert(ay[i] > b.ReloadHeight + 8 or ay[i] < b.DiveHeight + 20, "Attack: high (or diving)")
		fastest = math.max(fastest, as[i])
	end
	assert(fastest > 20, "Attack: strafing fast (" .. fastest .. ")")
	-- A dive gets close to the players.
	local dive = SSE.BossDives(SEED)[1]
	local bottom = SSE.BossPosition(ARENA, battle0 + (dive.start + dive.finish) / 2, plan)
	near(bottom.Y - ARENA.Y, b.DiveHeight, 0.05, "the dive's bottom")
	local reach = flat(bottom - ARENA).Magnitude
	assert(reach <= b.DiveRadius + 0.05 and reach >= b.DiveRadius * b.OrbitScaleX - 0.05, "close to the centre (" .. reach .. ")")
	-- v2's flight away (a plan without a crash point): C1 at endStart, then gone.
	local endStart = battle0 + 61.3
	local defeatPlan = SSE.Plan(1000, SEED, LIFT, endStart, "Defeat", nil, ORIGIN)
	nearV(SSE.BossPosition(ARENA, endStart, defeatPlan), SSE.BossPosition(ARENA, endStart, plan), 0.02, "the defeat starts where the ship was")
	local vBefore = SSE.BossVelocity(ARENA, endStart - 0.002, plan, 0.001)
	local vAfter = SSE.BossVelocity(ARENA, endStart + 0.002, defeatPlan, 0.001)
	assert((vAfter - vBefore).Magnitude < 1.5, "C1 into the flight away (" .. (vAfter - vBefore).Magnitude .. ")")
	local away = SSE.BossPosition(ARENA, endStart + 7, defeatPlan)
	assert((away - ARENA).Magnitude > 250 and away.Y > ARENA.Y + 150, "v2 (no crash point): he flies up and away")
	local escapePlan = SSE.Plan(1000, SEED, LIFT, battle0 + D.Battle, "Escape", nil, ORIGIN)
	assert((SSE.BossPosition(ARENA, battle0 + D.Battle + D.Escape, escapePlan) - ARENA).Magnitude > 250, "the escape flies away")
	-- v3: the crash. C1 into the dive, a spiralling fall onto the crash point, the wreck lies there.
	local crash = ARENA + Vector3.new(12, 0, -20)
	local crashPlan = SSE.Plan(1000, SEED, LIFT, endStart, "Defeat", crash, ORIGIN)
	local cvAfter = SSE.BossVelocity(ARENA, endStart + 0.002, crashPlan, 0.001)
	assert((cvAfter - vBefore).Magnitude < 1.5, "C1 into the crash (" .. (cvAfter - vBefore).Magnitude .. ")")
	local C = SSE.Crash
	local lowest, prevP, maxDiveAccel, prevDV = math.huge, nil, 0, nil
	for k = 0, math.floor(C.Seconds * 60) - 1 do
		local pos = SSE.BossPosition(ARENA, endStart + k / 60, crashPlan)
		lowest = math.min(lowest, pos.Y - crash.Y)
		if prevP then
			local v = (pos - prevP) * 60
			if prevDV then
				maxDiveAccel = math.max(maxDiveAccel, (v - prevDV).Magnitude * 60)
			end
			prevDV = v
		end
		prevP = pos
	end
	assert(lowest >= C.WreckLift - 0.01, "the dive never goes under the floor (" .. lowest .. ")")
	assert(maxDiveAccel < 400, "the dive is smooth (" .. maxDiveAccel .. ")")
	nearV(SSE.BossPosition(ARENA, endStart + C.Seconds, crashPlan), crash + Vector3.new(0, C.WreckLift, 0), 0.01, "the impact on the crash point")
	nearV(SSE.BossPosition(ARENA, endStart + D.Defeat, crashPlan), crash + Vector3.new(0, C.WreckLift, 0), 0.01, "the wreck lies there")
	for s = 0.1, 0.9, 0.2 do
		nearV(SSE.CrashPath(SSE.BossPosition(ARENA, endStart, plan), crash, s, vBefore), SSE.BossPosition(ARENA, endStart + s * C.Seconds, crashPlan), 0.05,
			"CrashPath = BossCFrame's position during the dive")
	end
	local nose = SSE.BossCFrame(ARENA, endStart + C.Seconds - 0.05, crashPlan).LookVector
	assert(nose.Y < -0.5, "nose down at the impact (" .. nose.Y .. ")")
	local times = SSE.CrashTimes(endStart)
	assert(times.impact == endStart + C.Seconds and times.ringsBurst > times.impact and times.ringsLand > times.ringsBurst
		and times.fadeEnd > times.fadeStart, "CrashTimes")
	for k = 1, C.Candidates do
		local cand = SSE.CrashCandidate(ARENA, SSE.BossPosition(ARENA, endStart, plan), k, C.MaxAcross)
		assert(math.abs(cand.X - ARENA.X) <= C.MaxAcross + 0.01 and flat(cand - ARENA).Magnitude <= C.Radius + 0.01, "a crash candidate on the corridor")
	end
	-- PlanFromAttributes: what the clients read (v3: the lobby spawn, the crash point, the Return's kept ending).
	local attrs = { SSE_EventStart = 1000, SSE_Seed = SEED, SSE_LiftOff = LIFT, SSE_Phase = "Defeat", SSE_PhaseStart = endStart,
		SSE_CrashPoint = crash, SSE_LobbyOrigin = ORIGIN }
	local function readPlan()
		return SSE.PlanFromAttributes(function(name)
			return attrs[name]
		end)
	end
	local read = readPlan()
	assert(read and read.start == 1000 and read.seed == SEED and read.liftOff == LIFT and read.endStart == endStart and read.outcome == "Defeat"
		and read.crashPoint == crash and read.lobbyOrigin == ORIGIN, "PlanFromAttributes")
	nearV(SSE.BossPosition(ARENA, endStart + 2, read), SSE.BossPosition(ARENA, endStart + 2, crashPlan), 1e-4, "the same path from the attributes")
	attrs.SSE_Phase, attrs.SSE_PhaseStart, attrs.SSE_EndStart, attrs.SSE_Outcome = "Return", endStart + D.Defeat, endStart, "Defeat"
	read = readPlan()
	assert(read.endStart == endStart and read.outcome == "Defeat" and read.crashPoint == crash, "the Return keeps the ending (SSE_EndStart / SSE_Outcome)")
	attrs.SSE_Phase = "Battle"
	assert(readPlan().endStart == nil and readPlan().crashPoint == nil, "no endStart during the fight")
	assert(SSE.PlanFromAttributes(function() return nil end) == nil, "no event: nil")
	-- No lift-off point: the default, over the lobby spawn.
	nearV(SSE.BossPosition(ARENA, 1000, SSE.Plan(1000, SEED, nil, nil, nil, nil, ORIGIN)), ORIGIN + Vector3.new(table.unpack(b.DefaultLiftOff)), 0.02, "DefaultLiftOff")
	-- The legacy forms (v1 clients) still work.
	local v1 = SSE.BossCFrame(ORIGIN, 5000)
	near(v1.Position.Y - ORIGIN.Y, b.Height + b.BobHeight * math.sin(2 * math.pi * 5000 / b.BobPeriod), 0.05, "legacy hover")
	nearV(SSE.BossPosition(ORIGIN, 7000 + b.FlyInSeconds, 7000), SSE.BossPosition(ORIGIN, 7000 + b.FlyInSeconds), 0.02, "legacy fly-in meets the hover")
	-- The cannon hangs under the hull.
	local t = battle0 + 20
	local cannon, ship = SSE.CannonPosition(ARENA, t, plan), SSE.BossPosition(ARENA, t, plan)
	assert(cannon.Y < ship.Y - 3 and (cannon - ship).Magnitude < 20, "the cannon is under the ship")
	pass("path: lifts off from the lobby Eggman facing the lobby spawn, leaves before the move, enters the arena from EntryFrom, C1 in each place (max " .. math.floor(maxSpeed) .. " studs/s), over the corridor (|x| <= " .. math.floor(maxAcross) .. "), Reload low + slow, Attack high + strafing, dives; the crash (C1, spiralling, never under the floor, the wreck lies), v2's flight away; PlanFromAttributes (+ the Return); legacy forms kept")
end

-- 2c. Bombs, emeralds, the homing attack, the charge, the rings, the checks.
do
	local a, b = Vector3.new(0, 185, 0), Vector3.new(30, 100, 40)
	nearV(SSE.BombArc(a, b, 0), a, 1e-4, "arc starts at the cannon")
	nearV(SSE.BombArc(a, b, 1), b, 1e-4, "arc ends on the target")
	nearV(SSE.BombArc(a, b, 0.5), (a + b) / 2 + Vector3.new(0, SSE.Bombard.ArcHeight, 0), 1e-3, "ArcHeight at the middle")
	near(SSE.BombFlightTime(a, a), SSE.Bombard.FlightMin, 1e-9, "Bombard: the minimum warning 1.4 s")
	near(SSE.BombFlightTime(a, a, true), SSE.Warning.MinSeconds, 1e-9, "Battle: the minimum warning 1.0 s")
	near(SSE.BombFlightTime(a, a + Vector3.new(5000, 0, 0), true), SSE.Bombard.BattleFlightMax, 1e-9, "Battle: the maximum")
	assert(SSE.BombFlightTime(a, b, true) < SSE.BombFlightTime(a, b), "Battle bombs are faster")
	local bomb = Vector3.new(10, 37467, 10)
	assert(SSE.InBlast(bomb + Vector3.new(21.9, 0, 0), bomb) and not SSE.InBlast(bomb + Vector3.new(22.1, 0, 0), bomb), "blast radius 22")
	for _, offset in { Vector3.new(10, 3, 0), Vector3.new(-5, 3, 12), Vector3.new(0, 1, -21) } do
		nearV(SSE.Knockback(bomb + offset, bomb), offset.Unit * 55 + Vector3.new(0, 42, 0), 1e-3, "knockback")
	end
	-- Lead and Parallel lines.
	local pos = Vector3.new(0, 10, 0)
	nearV(SSE.LeadPoint(pos, Vector3.new(10, 50, 0), 1.0), Vector3.new(6, 10, 0), 1e-6, "lead: horizontal velocity x flight x 0.6")
	nearV(SSE.LeadPoint(pos, Vector3.new(0, 0, 200), 1.5), Vector3.new(0, 10, SSE.Bombard.LeadMaxStuds), 1e-6, "lead: at most 24 studs")
	nearV(SSE.LeadPoint(pos, nil, 1), pos, 0, "no velocity: no lead")
	local offsets = SSE.ParallelOffsets(10, 0, 3)
	assert(#offsets == 3, "3 side by side")
	for j, o in offsets do
		near(o[1], 0, 1e-9, "across the ship -> target line")
		near(o[2], (j - 2) * SSE.Bombard.Parallel.Spacing, 1e-9, "Spacing apart, centred")
	end
	local two = SSE.ParallelOffsets(3, 4, 2)
	near(math.sqrt((two[1][1] - two[2][1]) ^ 2 + (two[1][2] - two[2][2]) ^ 2), SSE.Bombard.Parallel.Spacing, 1e-9, "2 in a line")
	near((two[1][1] + two[2][1]) * 3 + (two[1][2] + two[2][2]) * 4, 0, 1e-9, "centred")
	near((two[1][1] - two[2][1]) * 3 + (two[1][2] - two[2][2]) * 4, 0, 1e-9, "perpendicular")
	assert(SSE.BombsPerSalvo(0) == 3 and SSE.BombsPerSalvo(100) == SSE.Bombard.BombsMax, "Bombard bombs per salvo")
	assert(SSE.BattleBombsPerSalvo(3, 1) == 6 and SSE.BattleBombsPerSalvo(3, 9) == 10 and SSE.BattleBombsPerSalvo(100, 1) == SSE.Bombard.BattleBombsMax,
		"Battle: more with more players and later windows")

	-- The emeralds (v1).
	for i = 1, 7 do
		local o = SSE.EmeraldOrbit(i, 1.3)
		near(math.sqrt(o.X ^ 2 + o.Z ^ 2), 6, 1e-4, "orbit radius 6")
	end
	assert(SSE.EmeraldOffset(3, SSE.Emeralds.AbsorbAt) == nil and SSE.EmeraldOffset(3, SSE.Emeralds.AbsorbAt - 0.01).Magnitude < 0.05, "absorbed")

	-- The charge: measured from the server's receive times, clamped, never above the client's own.
	local CS = SSE.Homing.ChargeSeconds -- v3: 0.7 s
	near(SSE.MeasureCharge(10, 10), 0, 1e-9, "a tap: 0")
	near(SSE.MeasureCharge(10, 10 + CS / 2), 0.5, 1e-9, "half the charge time: half")
	near(SSE.MeasureCharge(10, 10 + CS), 1, 1e-9, "0.7 s: full")
	near(SSE.MeasureCharge(10, 30), 1, 1e-9, "held long: clamped to 1")
	near(SSE.MeasureCharge(10, 9), 0, 1e-9, "released before the press arrived: 0")
	near(SSE.MeasureCharge(10, 11.6, 0.3), 0.3, 1e-9, "the client's own charge caps it")
	near(SSE.MeasureCharge(10, 10 + CS / 4, 1), 0.25, 1e-9, "a client claiming more gets the server's")
	near(SSE.MeasureCharge(10, 10 + CS, 0), 0, 1e-9, "v3: charge01 0 = the uncharged jump attack")
	near(SSE.MeasureCharge(nil, 11), 0, 1e-9, "no press: 0 (the uncharged jump attack)")
	near(SSE.MeasureCharge(10, 10 + CS * 0.625, 0 / 0), 0.625, 1e-9, "junk charge01: ignored")
	assert(SSE.HomingDamage(0) == 1 and SSE.HomingDamage(0.24) == 1 and SSE.HomingDamage(0.25) == 2 and SSE.HomingDamage(0.74) == 2
		and SSE.HomingDamage(0.75) == 3 and SSE.HomingDamage(1) == 3 and SSE.HomingDamage(5) == 3 and SSE.HomingDamage("x") == 1, "damage = 1 + round(2 x charge)")
	local r0, d0 = SSE.BossRecoil(0)
	local r1, d1 = SSE.BossRecoil(1)
	assert(r1 > r0 and d1 > d0 and r0 > 0, "more charge, more recoil")
	local look = Vector3.new(0.6, -0.3, 0.8)
	local lookFlat = Vector3.new(0.6, 0, 0.8).Unit
	nearV(SSE.HomingBounce(look), Vector3.new(0, 55, 0) - lookFlat * 25, 1e-4, "bounce: v1 at no charge")
	nearV(SSE.HomingBounce(look, 1), Vector3.new(0, 55 + SSE.Homing.BounceUpCharged, 0) - lookFlat * (25 + SSE.Homing.BounceBackCharged), 1e-4, "a charged bounce is stronger")
	-- HomingIntercept: to where the ship will be at the arrival.
	local plan = SSE.Plan(1000, SEED, LIFT)
	local from = ORIGIN + Vector3.new(10, 3, -5)
	local launch = 1000 + SSE.PhaseOffset("Battle") + 30
	local to, duration = SSE.HomingIntercept(from, ORIGIN, launch, plan)
	nearV(to, SSE.BossPosition(ORIGIN, launch + duration, plan), 0.02, "the attack meets the ship")
	near(duration, SSE.HomingDuration(from, to), 0.01, "its duration is the curve's")
	near(SSE.RewindTime(90, 100), 100 - SSE.Homing.MaxLag, 1e-9, "rewind at most MaxLag back")

	-- CheckHoming, every refusal, in order.
	local base = { on = true, phase = "Battle", super = true, alive = true, racing = false, stunned = false, inFlight = false, hits = 0,
		lastAt = nil, now = 100, distance = 100, vulnerable = true }
	local function with(overrides)
		local input = table.clone(base)
		for k, v in overrides do
			input[k] = v
		end
		return input
	end
	assert(SSE.CheckHoming(base) == true, "a valid request")
	local R = SSE.HomingRefusals
	for _, case in {
		{ { on = false }, R.Off }, { { phase = "Bombard" }, R.Phase }, { { super = false }, R.NotSuper },
		{ { alive = false }, R.Dead }, { { racing = true }, R.Racing }, { { stunned = true }, R.Stunned }, { { inFlight = true }, R.Busy },
		{ { lastAt = 99.5 }, R.Cooldown }, { { distance = 186.01 }, R.Range }, { { distance = 0 / 0 }, R.Range },
		{ { vulnerable = false }, R.Shielded }, { { vulnerable = false, distance = 500 }, R.Range },
	} do
		local ok, reason = SSE.CheckHoming(with(case[1]))
		assert(ok == false and reason == case[2], "refused: " .. case[2] .. " (got " .. tostring(reason) .. ")")
	end
	assert(SSE.CheckHoming(with({ hits = 999 })) == true, "v2: the cap no longer refuses (hits past it land unpaid)")
	assert(SSE.CheckHoming(with({ vulnerable = nil })) == true, "an old caller without `vulnerable`")

	-- The rings.
	local RI = SSE.Rings
	assert(SSE.RingCount(0) == 20 and SSE.RingCount(4) == 44 and SSE.RingCount(12) == 92 and SSE.RingCount(50) == RI.Max, "20 + 6 per participant, at most 120")
	local seen = {}
	for i = 1, 60 do
		local p = SSE.RingScatter(ORIGIN, SEED, i, 60)
		local r = flat(p - ORIGIN).Magnitude
		assert(r >= RI.MinRadius - 1e-3 and r <= RI.MaxRadius + 1e-3 and p.Y == ORIGIN.Y, "a candidate between the radii")
		nearV(p, SSE.RingScatter(ORIGIN, SEED, i, 60), 0, "repeatable")
		local key = string.format("%.2f,%.2f", p.X, p.Z)
		assert(not seen[key], "distinct spots")
		seen[key] = true
	end
	assert(flat(SSE.RingScatter(ORIGIN, SEED, 61, 60) - SSE.RingScatter(ORIGIN, SEED, 1, 60)).Magnitude > 1, "a retry is another spot")
	local RR = SSE.RingRefusals
	local ring = { exists = true, taken = false, now = 50, landAt = 40, expireAt = 70, alive = true, dx = 3, dy = 0.5, dz = 2, speed = 0, count = 0 }
	local function ringWith(overrides)
		local input = table.clone(ring)
		for k, v in overrides do
			input[k] = v
		end
		return input
	end
	assert(SSE.RingTakeCheck(ring) == true, "a valid take")
	for _, case in {
		{ { exists = false }, RR.Gone }, { { taken = true }, RR.Gone }, { { now = 70.01 }, RR.Gone }, { { now = 39.9 }, RR.Early },
		{ { alive = false }, RR.Dead }, { { dx = 9 }, RR.Far }, { { dy = 11 }, RR.Far }, { { dx = 0 / 0 }, RR.Far }, { { count = 30 }, RR.Cap },
	} do
		local ok, reason = SSE.RingTakeCheck(ringWith(case[1]))
		assert(ok == false and reason == case[2], "ring refused: " .. case[2] .. " (got " .. tostring(reason) .. ")")
	end
	assert(SSE.RingTakeCheck(ringWith({ now = 39.97 })) == true, "EarlyGrace")
	assert(SSE.RingTakeCheck(ringWith({ dx = 12, speed = 60 })) == true and SSE.RingTakeCheck(ringWith({ dx = 30, speed = 1000 })) == false,
		"a fast taker gets latency slack, capped")

	-- Where the event happens (v1).
	local w1 = { IsNewWorld1Map = true }
	assert(SSE.PickSpawn({ Vector3.new(6000, 12000, 0), ORIGIN }, w1) == ORIGIN and SSE.PickSpawn({ Vector3.new(6000, 12000, 0) }, w1) == nil, "PickSpawn")
	nearV(SSE.WorldOrigin(nil, w1), ORIGIN, 0.01, "WorldOrigin: World 1's fallback")
	assert(SSE.InLobby(ORIGIN + Vector3.new(290, 3, 0), ORIGIN) and not SSE.InLobby(ORIGIN + Vector3.new(310, 3, 0), ORIGIN)
		and SSE.InLobby(ORIGIN + Vector3.new(310, 3, 0), ORIGIN, true), "InLobby (v2's area, + exit hysteresis)")
	-- v3: the fight's area is the race arena's corridor round SSE_Origin.
	local AR = SSE.Arena
	assert(SSE.InArena(ARENA + Vector3.new(AR.HalfX - 1, 3, AR.HalfZ - 1), ARENA) and not SSE.InArena(ARENA + Vector3.new(AR.HalfX + 1, 3, 0), ARENA)
		and SSE.InArena(ARENA + Vector3.new(AR.HalfX + 1, 3, 0), ARENA, true) and not SSE.InArena(ARENA + Vector3.new(0, 3, AR.ExitHalfZ + 1), ARENA, true)
		and not SSE.InArena(ARENA + Vector3.new(0, -AR.BelowOrigin - 1, 0), ARENA), "InArena: the corridor box (+ exit hysteresis)")
	assert(SSE.InEventArea(ORIGIN + Vector3.new(5, 3, 0), ARENA, ORIGIN, false) and not SSE.InEventArea(ORIGIN + Vector3.new(5, 3, 0), ARENA, ORIGIN, true)
		and SSE.InEventArea(ARENA + Vector3.new(5, 3, 0), ARENA, ORIGIN, true) and SSE.InEventArea(ARENA + Vector3.new(5, 3, 0), ARENA, ORIGIN, false)
		and SSE.InEventArea(ORIGIN + Vector3.new(5, 3, 0), ORIGIN, nil, true), "InEventArea: lobby + arena until the move, the arena after; no arena: the lobby")
	assert(not SSE.Moved("Cinematic", 3) and not SSE.Moved("Teleport", SSE.Beats.Teleport.MoveAt - 0.01) and SSE.Moved("Teleport", SSE.Beats.Teleport.MoveAt)
		and SSE.Moved("Battle", 0) and SSE.Moved("Return", 1) and not SSE.Moved("", 0), "Moved")
	assert(SSE.IsOn() == true, "IsOn outside Roblox")
	pass("pure: bombs (warning 1.0 / 1.4 s, faster in the Battle, lead <= 24, Parallel lines), charge (server-measured, clamped, client-capped), damage 1/2/3, recoil, charged bounce, HomingIntercept, CheckHoming (Stunned, Shielded, no cap refusal), rings (count, scatter, take check), spawn helpers")
end

----------------------------------------------------------------------
-- 3. The state machine
----------------------------------------------------------------------
-- The fake lobby floor: flat within 50 studs of the spawn, a steep slope to 58, void past it.
-- 2026-09-26 (owner): v3: the fake race arena: its corridor's floor (|x| <= ARENA_FLOOR_X round ARENA, the track
-- along z) at ARENA.Y; water past the banks. newWorld({ arena = true }) gives the core the arena (deps.arenaOrigin).
local LOBBY_FLOOR = 50
local ARENA_FLOOR_X = 36
local function nearArena(position)
	return math.abs(position.Y - ARENA.Y) < 2000
end
local function newWorld(options)
	options = options or {}
	local world = {
		T = options.T or 1000,
		on = true,
		players = {},
		log = {},
		all = {},
		one = {},
		ragdolls = {},
		rescues = {},
		applied = {},
		restored = {},
		grants = {},
		chat = {},
		worldAttrs = {},
		noFlight = {},
		grantKinds = {}, -- queue of kinds grant answers (default "Committed")
		seed = options.seed or SEED,
		gates = {}, -- v3: arenaGates calls
		trips = {}, -- v3: deps.teleport calls
		heldTrips = {},
		pushes = {}, -- v3: the shield's bounces
	}
	function world.add(userId, offset, extra)
		local player = { UserId = userId, Name = "P" .. userId, pos = ORIGIN + offset, alive = true, grounded = true,
			racing = false, afk = false, attrs = {}, velocity = Vector3.zero }
		for k, v in extra or {} do
			player[k] = v
		end
		table.insert(world.players, player)
		return player
	end
	function world.remove(player)
		local index = table.find(world.players, player)
		if index then
			table.remove(world.players, index)
		end
	end
	world.deps = {
		SSE = SSE,
		jobId = "job-test",
		now = function()
			return world.T
		end,
		players = function()
			return table.clone(world.players)
		end,
		userId = function(player)
			return player.UserId
		end,
		rootPosition = function(player)
			return if player.alive then player.pos else nil
		end,
		velocity = function(player)
			return player.velocity
		end,
		alive = function(player)
			return player.alive
		end,
		grounded = function(player)
			return player.grounded
		end,
		racing = function(player)
			return player.racing
		end,
		afk = function(player)
			return player.afk
		end,
		ground = function(position)
			return Vector3.new(position.X, if nearArena(position) then ARENA.Y else ORIGIN.Y, position.Z)
		end,
		ringGround = function(position)
			if nearArena(position) then
				if math.abs(position.X - ARENA.X) <= ARENA_FLOOR_X and math.abs(position.Z - ARENA.Z) <= 900 then
					return Vector3.new(position.X, ARENA.Y, position.Z), 1
				end
				return nil -- the water past the banks
			end
			local r = flat(position - ORIGIN).Magnitude
			if r <= LOBBY_FLOOR then
				return Vector3.new(position.X, ORIGIN.Y, position.Z), 1
			elseif r <= LOBBY_FLOOR + 8 then
				return Vector3.new(position.X, ORIGIN.Y + 2, position.Z), 0.3 -- a steep slope
			end
			return nil
		end,
		liftOff = function()
			return if options.noLift then nil else LIFT
		end,
		setWorld = function(name, value)
			world.worldAttrs[name] = value
		end,
		setPlayer = function(player, name, value)
			player.attrs[name] = value
		end,
		setNoFlight = function(player, on)
			world.noFlight[player] = on
			table.insert(world.log, { kind = "noFlight", player = player, on = on, T = world.T })
		end,
		fireAll = function(message)
			table.insert(world.all, message)
			table.insert(world.log, { kind = "all", message = message, T = world.T })
		end,
		fireOne = function(player, message)
			table.insert(world.one, { player = player, message = message })
			table.insert(world.log, { kind = "one", player = player, message = message, T = world.T })
		end,
		ragdoll = function(player, seconds, velocity)
			table.insert(world.ragdolls, { player = player, seconds = seconds, velocity = velocity, pos = player.pos, T = world.T, super = player.attrs.SSE_Super == true })
			table.insert(world.log, { kind = "ragdoll", player = player, seconds = seconds, velocity = velocity, pos = player.pos })
		end,
		rescue = function(player, position)
			table.insert(world.rescues, player)
			player.pos = position or ORIGIN + Vector3.new(0, 4, 0)
		end,
		-- 2026-09-26 (owner): v3
		arenaOrigin = if options.arena then function()
			return ARENA
		end else nil,
		arenaGates = function(open)
			table.insert(world.gates, open)
		end,
		closeRaces = function(reason)
			world.racesClosed = reason
			return if world.onCloseRaces then world.onCloseRaces() else {}
		end,
		openRaces = function(reason)
			world.racesOpened = reason
		end,
		teleport = function(player, position, stillValid, arrived, home)
			table.insert(world.trips, { player = player, pos = position, home = home, T = world.T })
			if world.holdTrips then
				table.insert(world.heldTrips, { player = player, pos = position, stillValid = stillValid, arrived = arrived })
				return
			end
			if stillValid() and player.alive then
				player.pos = position
				arrived()
			end
		end,
		push = function(player, velocity)
			table.insert(world.pushes, { player = player, velocity = velocity })
		end,
		applySuper = function(player)
			table.insert(world.applied, player)
			player.walkFloor = SSE.Super.WalkSpeed
			player.jumpPower = SSE.Super.JumpPower
			return { token = player.UserId }
		end,
		restoreSuper = function(player, saved)
			table.insert(world.restored, { player = player, saved = saved })
			player.walkFloor = nil
			player.jumpPower = nil
		end,
		grant = function(player, wins, speed, operationId)
			local kind = table.remove(world.grantKinds, 1) or "Committed"
			table.insert(world.grants, { player = player, wins = wins, speed = speed, operationId = operationId, kind = kind })
			return kind
		end,
		chat = function(text)
			table.insert(world.chat, text)
		end,
		origin = function()
			return ORIGIN
		end,
		isOn = function()
			return world.on
		end,
		newSeed = function()
			return world.seed
		end,
		spawn = function(fn)
			fn()
		end,
		wait = function() end,
	}
	world.core = Core.new(world.deps)
	function world.run(untilT, dt)
		dt = dt or 0.05
		while world.T < untilT - 1e-9 do
			world.T = math.min(untilT, world.T + dt)
			world.core:Step()
		end
	end
	function world.messages(name)
		local list = {}
		for _, message in world.all do
			if message[1] == name then
				table.insert(list, message)
			end
		end
		return list
	end
	function world.toOne(player, name)
		local list = {}
		for _, entry in world.one do
			if entry.player == player and entry.message[1] == name then
				table.insert(list, entry.message)
			end
		end
		return list
	end
	function world.paid(player)
		local wins, speed, ops = 0, 0, {}
		for _, grant in world.grants do
			if grant.player == player and (grant.kind == "Committed" or grant.kind == "AlreadyCommitted") and not ops[grant.operationId] then
				ops[grant.operationId] = true
				wins += grant.wins
				speed += grant.speed
			end
		end
		return wins, speed
	end
	-- Suppress the Battle's salvos (homing details without bombs in the way).
	function world.quiet()
		world.core.nextSalvo = math.huge
		world.core.launches = {}
		world.core.bombs = {}
	end
	return world
end

local T0 = 1000
local TELEPORT = T0 + D.Cinematic -- v3: the Teleport beat
local BOMBARD = TELEPORT + D.Teleport
local EMERALDS = BOMBARD + D.Bombard
local ABSORB = EMERALDS + SSE.Emeralds.AbsorbAt
local BATTLE = EMERALDS + D.Emeralds
local WINDOWS = SSE.BossWindows(SEED)
local RELOAD1 = WINDOWS[2]
assert(RELOAD1.state == "Reload", "seed 12345's 2nd window is a Reload")

-- A player right under the ship's orbit (the homing attacks are short).
local UNDER = Vector3.new(0, 3, 0)

-- 3a. A full event: phases, bombs, blasts, the transformation, the Battle, the defeat, the rings, the cleanup.
do
	local world = newWorld()
	local a = world.add(1, Vector3.new(0, 3, 0))
	local b = world.add(2, Vector3.new(8, 3, 5), { velocity = Vector3.new(40, 0, 0) }) -- running: bombs lead it
	local c = world.add(3, Vector3.new(-6, 3, -4))
	local racer = world.add(4, Vector3.new(4, 3, -3), { racing = true })
	local afk = world.add(5, Vector3.new(-3, 3, 6), { afk = true })
	local away = world.add(6, Vector3.new(1000, 3, 0)) -- out on the stages
	local core = world.core

	assert(core:Start("Tester") == true, "Start")
	local ok, reason = core:Start("Again")
	assert(ok == false and reason == "running", "one event at a time")
	local A = SSE.Attributes
	local W = world.worldAttrs
	assert(W[A.Phase] == "Cinematic" and W[A.PhaseStart] == T0 and W[A.EventStart] == T0 and W[A.EventId] == 1
		and W[A.Seed] == SEED and W[A.Origin] == ORIGIN and W[A.LiftOff] == LIFT, "Start: the world attributes (EventStart, LiftOff)")
	assert(W[A.BossMaxHP] == SSE.BossMaxHP(3) and W[A.BossHP] == SSE.BossMaxHP(3), "an HP estimate from the 3 eligible players")
	assert(world.chat[1] == SSE.Announcements.Start, "the start is announced in the chat")
	-- No Flight in the event's area from the first moment (the racer stands in the lobby here too; the away
	-- player on the stages keeps Flight).
	for _, player in { a, b, c, racer, afk } do
		assert(world.noFlight[player] == true, "no Flight in the area: " .. player.Name)
	end
	assert(world.noFlight[away] == nil, "the stages keep Flight")
	local plan = SSE.Plan(T0, SEED, LIFT)

	world.run(TELEPORT - 0.01)
	assert(W[A.Phase] == "Cinematic" and #world.messages("Bomb") == 0, "no bomb in the Cinematic")
	world.run(BOMBARD - 0.01)
	assert(W[A.Phase] == "Teleport" and W[A.PhaseStart] == TELEPORT and #world.messages("Bomb") == 0, "v3: the Teleport beat at 7.5 s (no race arena here: nobody moves)")
	assert(#world.trips == 0 and a.pos == ORIGIN + Vector3.new(0, 3, 0), "without the arena the lobby stays put")
	world.run(BOMBARD + 0.01)
	assert(W[A.Phase] == "Bombard" and W[A.PhaseStart] == BOMBARD, "Bombard at 12 s")
	world.run(EMERALDS - 0.01)
	local bombs, hits = world.messages("Bomb"), world.messages("BombHit")
	local perSalvo = SSE.BombsPerSalvo(3)
	local lines = math.min(SSE.Bombard.Parallel.Lines, 3)
	assert(#bombs == 2 * perSalvo + lines * SSE.Bombard.Parallel.BombardCount, "Aimed " .. perSalvo .. " + Parallel " .. lines .. "x2 + Aimed (" .. #bombs .. ")")
	assert(#hits == #bombs, "every bomb landed inside the Bombard")
	local byId, parallels, ledB = {}, {}, 0
	local function leadOf(target, from)
		return SSE.LeadPoint(target.pos, target.velocity, SSE.BombFlightTime(from, target.pos, false))
	end
	for index, message in bombs do
		local id, from, to, launch, flight, pattern, radius = message[2], message[3], message[4], message[5], message[6], message[7], message[8]
		assert(id == index, "bomb ids in order")
		byId[id] = message
		nearV(from, SSE.CannonPosition(ORIGIN, launch, plan), 0.02, "bomb " .. id .. " leaves the cannon (the v2 path)")
		assert(radius == SSE.Warning.Radius, "the red zone's radius in the message")
		assert(flight >= SSE.Warning.BombardMinSeconds - 1e-9 and flight <= SSE.Bombard.FlightMax + 1e-9, "Bombard warning 1.4-2.0 s")
		near(to.Y, ORIGIN.Y, 0.01, "lands on the floor")
		local salvo = if launch < BOMBARD + 3 then 1 elseif launch < BOMBARD + 5.5 then 2 else 3
		assert(pattern == SSE.Bombard.Patterns[salvo], "salvo " .. salvo .. " is " .. SSE.Bombard.Patterns[salvo])
		if pattern == "Aimed" then
			near(flight, SSE.BombFlightTime(from, to, false), 1e-6, "flight time")
			local best = math.huge
			for _, target in { a, b, c } do
				best = math.min(best, flat(to - leadOf(target, from)).Magnitude)
			end
			assert(best <= SSE.Bombard.TargetScatter + 0.01, "bomb " .. id .. " aimed near a lobby player's lead point")
			if flat(to - leadOf(b, from)).Magnitude <= SSE.Bombard.TargetScatter + 0.01 and flat(to - b.pos).Magnitude > SSE.Bombard.TargetScatter + 1 then
				ledB += 1
			end
		else
			parallels[launch] = parallels[launch] or {}
			table.insert(parallels[launch], message)
		end
	end
	assert(ledB > 0, "the running player's bombs land ahead of it (led)")
	local lineCount = 0
	for launch, line in parallels do
		lineCount += 1
		assert(#line == SSE.Bombard.Parallel.BombardCount, "a Bombard line has 2 bombs, launched together")
		local p1, p2 = line[1][4], line[2][4]
		near(flat(p2 - p1).Magnitude, SSE.Bombard.Parallel.Spacing, 0.05, "side by side, Spacing apart")
		local centre = (p1 + p2) / 2
		near(flat(p2 - p1).Unit:Dot(flat(centre - line[1][3]).Unit), 0, 0.02, "across the ship -> target line")
		assert(line[1][6] == line[2][6], "one flight for the line")
	end
	assert(lineCount == lines, "one line per target (at most 2)")
	-- The throws: each one exact, for the bomb that landed right after, within 22 studs; never a kill.
	local pending, knocks = {}, 0
	for _, entry in world.log do
		if entry.kind == "ragdoll" then
			table.insert(pending, entry)
		elseif entry.kind == "all" and entry.message[1] == "BombHit" then
			for _, knock in pending do
				assert(knock.player ~= racer and knock.player ~= afk and knock.player ~= away, "never the racer / AFK / away player")
				assert(SSE.InBlast(knock.pos, entry.message[3]), "thrown only within 22 studs")
				nearV(knock.velocity, SSE.Knockback(knock.pos, entry.message[3]), 1e-3, "the exact throw")
				assert(knock.seconds == 2, "2 s live ragdoll")
				knocks += 1
			end
			pending = {}
		end
	end
	assert(knocks > 0 and #pending == 0, "bombs threw players (" .. knocks .. ")")
	for _, player in { a, b, c } do
		assert(player.alive, "never a kill")
	end

	-- Emeralds: Super at the absorption, not before; only eligible players.
	world.run(ABSORB - 0.02)
	assert(W[A.Phase] == "Emeralds" and a.attrs.SSE_Super == nil and #world.applied == 0, "not Super before the absorption")
	world.run(ABSORB + 0.01)
	for _, player in { a, b, c } do
		assert(player.attrs.SSE_Super == true and player.walkFloor == 120 and player.jumpPower == 90, "Super at the absorption: " .. player.Name)
	end
	for _, player in { racer, afk, away } do
		assert(player.attrs.SSE_Super == nil, "not Super: " .. player.Name)
	end

	-- The Battle: the HP from the participants, the Attack / Reload mirror.
	world.run(BATTLE + 0.01)
	assert(W[A.Phase] == "Battle" and W[A.PhaseStart] == BATTLE, "Battle at 24 s")
	local maxHp = SSE.BossMaxHP(3)
	assert(W[A.BossMaxHP] == maxHp and W[A.BossHP] == maxHp, "HP = HP(3 participants) = " .. maxHp)
	assert(W[A.BossState] == "Attack" and W[A.BossStateStart] == BATTLE and W[A.BossStateEnd] == BATTLE + WINDOWS[1].finish, "SSE_BossState Attack (the first 5 s)")
	local okA, whyA = core:RequestHoming(a, world.T)
	assert(okA == true and whyA == "Shielded", "v3: an attack arriving in the Attack window flies, shielded")
	world.run(BATTLE + RELOAD1.start + 0.02)
	assert(W[A.BossState] == "Reload" and W[A.BossStateStart] == BATTLE + RELOAD1.start and W[A.BossStateEnd] == BATTLE + RELOAD1.finish, "then Reload")
	-- Salvos in the first Attack window, only there; Super players are thrown too (shorter).
	local battleBombs = 0
	for _, message in world.messages("Bomb") do
		if message[5] >= BATTLE then
			battleBombs += 1
			local state = SSE.BossState(message[5] - BATTLE, SEED)
			assert(state == "Attack", "a Battle bomb leaves in an Attack window only")
			assert(message[6] >= SSE.Warning.MinSeconds - 1e-9 and message[6] <= SSE.Bombard.BattleFlightMax + 1e-9, "Battle warning 1.0-1.5 s")
		end
	end
	assert(battleBombs > 0, "the Battle has attacks")
	local superThrown = 0
	for _, r in world.ragdolls do
		if r.super then
			superThrown += 1
			assert(r.seconds == SSE.Battle.SuperRagdollSeconds, "a Super player is ragdolled 1.2 s")
		end
	end
	assert(superThrown > 0, "the Battle's bombs throw Super players")

	-- A short fight: the ship down to 12 HP, everyone attacks every step; hits only land in Reload windows.
	core.hp = 12
	local attackers = { a, b, c }
	for _, player in attackers do
		player.pos = ORIGIN + UNDER + Vector3.new(player.UserId * 2, 0, 0)
	end
	local guard = 0
	while W[A.Phase] == "Battle" do
		guard += 1
		assert(guard < 40000, "the battle ends")
		for _, player in attackers do
			core:RequestHoming(player, world.T)
		end
		world.T += 0.05
		core:Step()
	end
	assert(W[A.Phase] == "Defeat" and W[A.BossHP] == 0, "HP 0 -> Defeat")
	local defeatAt = W[A.PhaseStart]
	assert(#world.messages("Defeat") == 1 and world.chat[#world.chat] == SSE.Announcements.Defeat, "Defeat to all + the chat line")
	local shieldedGo = 0
	for _, go in world.messages("HomingGo") do
		if go[9] then
			shieldedGo += 1
			assert(go[8] == 0, "a shielded attack does no damage")
		else
			assert(SSE.BossVulnerable(go[5] + go[6] - BATTLE, SEED), "every unshielded attack arrives in a Reload window")
		end
	end
	assert(shieldedGo > 0, "attacks timed for an Attack window flew shielded")
	local shielded = 0
	for _, player in attackers do
		for _, no in world.toOne(player, "HomingNo") do
			if no[2] == "Shielded" then
				shielded += 1
			end
		end
	end
	assert(shielded > 0, "attacks timed for an Attack window were Shielded")
	assert(W[A.BossState] == nil, "no boss state after the fight")
	assert(core.plan.endStart == defeatAt and core.plan.outcome == "Defeat", "the path flies away from the defeat")
	-- The rings rain at the defeat.
	local rings = world.messages("Rings")
	assert(#rings == 1, "the Rings message")
	local ringMessage = rings[1]
	local crashTimes = SSE.CrashTimes(defeatAt)
	assert(ringMessage[2] == 1 and ringMessage[4] == crashTimes.ringsLand and ringMessage[5] == ringMessage[4] + SSE.Rings.LifeSeconds
		and ringMessage[8] == crashTimes.ringsBurst, "event id, land / expire / burst times (after the crash)")
	local crashPoint = W[A.CrashPoint]
	assert(crashPoint and core.crashPoint == crashPoint and core.plan.crashPoint == crashPoint, "v3: SSE_CrashPoint")
	near(crashPoint.Y, ORIGIN.Y, 1e-3, "the crash point on the floor")
	assert(flat(crashPoint - ORIGIN).Magnitude <= SSE.Crash.Radius + 0.01 and flat(crashPoint - ORIGIN).Magnitude >= SSE.Crash.MinRadius - 0.01, "near the centre")
	local defeatMessage = world.messages("Defeat")[1]
	assert(defeatMessage[2] == crashPoint and defeatMessage[3] == crashTimes.impact, "{ Defeat, crashPoint, impactTime }")
	nearV(ringMessage[6], crashPoint + Vector3.new(0, SSE.Crash.RingsUp, 0), 1e-3, "they burst out of the crash point")
	assert(#ringMessage[3] > 0 and #ringMessage[3] <= SSE.RingCount(3) and #ringMessage[7] == 0, "up to RingCount(3) = " .. SSE.RingCount(3) .. " rings (" .. #ringMessage[3] .. ")")
	-- Still Super through the Defeat; the Return beat; restored (and Flight back) at the end; the rings gone.
	assert(a.attrs.SSE_Super == true, "Super through the Defeat")
	world.run(defeatAt + D.Defeat + 0.05)
	assert(W[A.Phase] == "Return" and W[A.EndStart] == defeatAt and W[A.Outcome] == "Defeat", "v3: the Return beat keeps the ending")
	assert(not core:HasRings(), "the rings are gone by the Return (expired before it)")
	world.run(defeatAt + D.Defeat + D.Return + 0.05)
	assert(W[A.Phase] == "" and W[A.PhaseStart] == nil and W[A.BossHP] == nil and W[A.Origin] == nil and W[A.Seed] == nil
		and W[A.EventId] == nil and W[A.EventStart] == nil and W[A.LiftOff] == nil, "cleanup: attributes cleared")
	for _, player in attackers do
		assert(player.attrs.SSE_Super == nil and player.attrs.SSE_Hits == nil and player.walkFloor == nil, "restored: " .. player.Name)
		assert(world.noFlight[player] == false, "Flight back: " .. player.Name)
		local wins, speed = world.paid(player)
		local rewarded = #world.toOne(player, "Reward")
		assert(wins == rewarded * 600 and speed == rewarded * 30000, player.Name .. ": 600 / 30,000 a hit, paid once each (" .. wins .. ")")
	end
	assert(#world.restored == 3, "every Super player restored once")
	assert(core:IsRunning() == false and core:HasRings() == false, "stopped; the rings went with the event")
	assert(W[A.CrashPoint] == nil and W[A.EndStart] == nil and W[A.Outcome] == nil and W[A.LobbyOrigin] == nil, "v3's attributes cleared")
	assert(world.racesClosed == "SuperSonicEvent" and world.racesOpened == "SuperSonicEvent", "the races closed for the event, open again")
	local okR, why = core:RequestHoming(a, world.T)
	assert(okR == false and why == "phase", "no event: refused")
	-- Batching: fewer commits than hits, each a new operation id.
	local ids = {}
	for _, grant in world.grants do
		assert(not ids[grant.operationId], "one operation id per commit")
		ids[grant.operationId] = true
	end
	pass("state machine (no race arena: all in the lobby): Cinematic (no Flight in the area) -> Teleport (nobody moves) -> Bombard (Aimed / Parallel / Aimed, led, exact throws, no kill) -> Emeralds -> Battle (HP from participants, Attack / Reload mirror, salvos only in Attack, Super players thrown 1.2 s, shielded outside Reload) -> Defeat (the crash, the rings from it) -> Return -> cleanup (Flight back, rings gone, races open)")
end

-- 3b. The homing attack in detail (no bombs in the way). 2026-09-26 (owner): v3: fast (320 studs/s), the uncharged
-- jump attack (no Charge), the 0.7 s charge, a stale press forgotten, the shield's bounce.
do
	local world = newWorld()
	local a = world.add(1, UNDER)
	local b = world.add(2, UNDER + Vector3.new(3, 0, 0))
	local core = world.core
	core:Start()
	world.run(BATTLE + 0.5)
	world.quiet()
	local maxHp = core.maxHp
	-- During the Attack window: the attack flies, shielded, and bounces off at its arrival.
	local ok, why = core:RequestHoming(a, world.T)
	assert(ok == true and why == "Shielded", "Attack window: the attack flies, shielded")
	local sgo = world.messages("HomingGo")[1]
	assert(sgo and sgo[2] == 1 and sgo[8] == 0 and sgo[9] == true, "HomingGo { ..., damage 0, shielded = true }")
	assert(sgo[6] <= 0.6, "fast: a ~60-stud dash takes well under a second (" .. sgo[6] .. " s)")
	near(sgo[6], SSE.HomingDuration(sgo[3], sgo[4]), 1e-6, "its duration at Homing.Speed along HomingPath")
	assert(core.participants[a].lastHomingAt == world.T, "a shielded attack spends the cooldown")
	local ragBefore = #world.ragdolls
	world.run(sgo[5] + sgo[6] + 0.05, 0.01)
	local no = world.toOne(a, "HomingNo")
	assert(#no == 1 and no[1][2] == "Shielded", "at the arrival: { HomingNo, Shielded }")
	local knock = {}
	for _, message in world.toOne(a, "Knock") do
		if message[4] == "Shield" then
			table.insert(knock, message)
		end
	end
	assert(#knock == 1 and knock[1][3] == 0, "{ Knock, velocity, 0, Shield }: no ragdoll")
	local shipAt = SSE.BossPosition(ORIGIN, sgo[5] + sgo[6], core.plan)
	nearV(knock[1][2], SSE.ShieldKnock(sgo[3], shipAt), 1e-3, "ShieldKnock: 70 out (back the way it came) + 30 up")
	near(Vector3.new(knock[1][2].X, 0, knock[1][2].Z).Magnitude, SSE.Shield.KnockOut, 1e-3, "70 studs/s out")
	near(knock[1][2].Y, SSE.Shield.KnockUp, 1e-6, "30 up")
	assert(flat(knock[1][2]).Unit:Dot(flat(sgo[3] - shipAt).Unit) > 0.999, "away from the ship")
	assert(#world.pushes == 1 and world.pushes[1].player == a, "the server sets the velocity too")
	local shieldHit = world.messages("ShieldHit")
	assert(#shieldHit == 1 and shieldHit[1][2] == 1, "{ ShieldHit, userId, pos } to everyone")
	assert(core.hp == maxHp and #world.messages("Hit") == 0 and #world.ragdolls == ragBefore and a.alive, "no damage to anyone, no ragdoll, no kill")
	local okSt, whySt = core:RequestHoming(a, world.T)
	assert(okSt == false and (whySt == "stunned" or whySt == "cooldown"), "stunned / cooling down after the bounce (" .. tostring(whySt) .. ")")
	-- A charge pressed before the Reload, released 0.35 s later: 0.5 -> damage 2, arriving in the Reload.
	world.run(BATTLE + RELOAD1.start - 0.3)
	assert(core:ClientMessage(a, { "Charge", world.T }) == "Charge", "{ Charge, t }")
	world.run(world.T + SSE.Homing.ChargeSeconds / 2, 0.01)
	local releaseAt = world.T
	assert(core:ClientMessage(a, { "Homing", releaseAt }) == "Homing", "{ Homing, t }")
	local go = world.messages("HomingGo")[2]
	assert(go and go[2] == 1 and go[9] == false, "accepted: HomingGo, not shielded")
	near(go[7], 0.5, 1e-6, "the charge measured by the server (half of 0.7 s)")
	assert(go[8] == 2, "damage 2")
	nearV(go[4], SSE.BossPosition(ORIGIN, go[5] + go[6], core.plan), 0.02, "flies to where the ship will be")
	assert(SSE.BossVulnerable(go[5] + go[6] - BATTLE, SEED), "it arrives in the Reload")
	world.run(go[5] + go[6] + 0.05, 0.01)
	local hit = world.messages("Hit")[1]
	assert(hit and hit[2] == 1 and hit[4] == maxHp - 2 and hit[5] == maxHp and hit[6] == 2, "Hit { userId, pos, hp, maxHp, damage 2 }")
	near(hit[7], go[7], 1e-9, "Hit carries the charge")
	near(hit[8], (SSE.BossRecoil(go[7])), 1e-9, "and the recoil")
	local reward = world.toOne(a, "Reward")[1]
	assert(reward[2] == 600 and reward[3] == 30000 and reward[4] == "hit", "Reward { 600, 30000, hit }")
	assert(#world.grants == 1 and world.grants[1].wins == 600 and world.grants[1].speed == 30000, "the first reward committed at once")
	-- Held past the full charge but the client says 0.3: 0.3 -> damage 2; a full charge (0.7 s) -> 3.
	world.run(world.T + 0.1, 0.02)
	core:ClientMessage(a, "Charge", world.T)
	world.run(world.T + 1.2, 0.05)
	assert(core:ClientMessage(a, "Homing", world.T, 0.3) == "Homing", "the vararg form")
	local go2 = world.messages("HomingGo")[3]
	near(go2[7], 0.3, 1e-9, "the client's own charge caps the server's")
	assert(go2[8] == 2, "0.3 -> damage 2")
	world.run(go2[5] + go2[6] + 0.05, 0.01)
	world.run(world.T + SSE.Homing.Cooldown, 0.05)
	core:ClientMessage(a, { "Charge", world.T })
	world.run(world.T + SSE.Homing.ChargeSeconds + 0.05, 0.05)
	core:ClientMessage(a, { "Homing", world.T })
	local go3 = world.messages("HomingGo")[4]
	assert(go3 and go3[7] == 1 and go3[8] == 3 and go3[9] == false, "a full charge in 0.7 s: damage 3 (" .. tostring(go3 and go3[7]) .. ")")
	world.run(go3[5] + go3[6] + 0.05, 0.01)
	-- v3: the mid-air jump attack: { Homing, t } with no Charge before it = uncharged, damage 1.
	core:ClientMessage(b, { "Homing", world.T })
	local go4 = world.messages("HomingGo")[5]
	assert(go4 and go4[2] == 2 and go4[7] == 0 and go4[8] == 1 and go4[9] == false, "the jump attack (no Charge): charge 0, damage 1, accepted")
	world.run(go4[5] + go4[6] + 0.05, 0.01)
	assert(core.hp == maxHp - 2 - 2 - 3 - 1, "HP -damage each (" .. core.hp .. ")")
	assert(a.attrs.SSE_Hits == 3 and b.attrs.SSE_Hits == 1, "SSE_Hits counts hits (not the bounce)")
	-- v3: a press whose release never came (stale) does not charge a later jump attack; charge01 0 is uncharged too.
	core:ClientMessage(b, { "Charge", world.T })
	world.run(world.T + SSE.Homing.ChargeStaleSeconds + 0.5, 0.25)
	world.quiet()
	local function reloadNow()
		local state, _, f = SSE.BossState(world.T - BATTLE, SEED)
		return state == "Reload" and world.T - BATTLE + 0.4 < f
	end
	local guard = 0
	while not reloadNow() do
		guard += 1
		assert(guard < 4000, "a Reload window")
		world.run(world.T + 0.05)
	end
	core:ClientMessage(b, { "Homing", world.T })
	local go5 = world.messages("HomingGo")[#world.messages("HomingGo")]
	assert(go5[2] == 2 and go5[7] == 0 and go5[8] == 1, "a stale press (" .. SSE.Homing.ChargeStaleSeconds .. " s) no longer counts: damage 1")
	world.run(go5[5] + go5[6] + 0.05, 0.01)
	world.run(world.T + SSE.Homing.Cooldown + 0.05)
	core:ClientMessage(a, { "Charge", world.T })
	world.run(world.T + SSE.Homing.ChargeSeconds, 0.05)
	while not reloadNow() do
		guard += 1
		assert(guard < 8000, "a Reload window (2)")
		world.run(world.T + 0.05)
	end
	core:ClientMessage(a, { "Homing", world.T, 0 })
	local go6 = world.messages("HomingGo")[#world.messages("HomingGo")]
	assert(go6[2] == 1 and go6[7] == 0 and go6[8] == 1, "charge01 0: uncharged whatever was pressed")
	world.run(go6[5] + go6[6] + 0.05, 0.01)
	-- Busy / cooldown / range (in a Reload window).
	local function attackWhenOpen(player)
		local g = 0
		while not (reloadNow() and core:RequestHoming(player, world.T)) do
			g += 1
			assert(g < 4000, "an attack for " .. player.Name)
			world.run(world.T + 0.05)
		end
	end
	world.run(world.T + 1.1)
	attackWhenOpen(a)
	local okB, whyB = core:RequestHoming(a, world.T)
	assert(okB == false and whyB == "busy", "one in flight at a time")
	world.run(world.T + 0.5, 0.01)
	local okC, whyC = core:RequestHoming(a, world.T)
	assert(okC == false and whyC == "cooldown", "cooldown")
	b.pos = ORIGIN + Vector3.new(280, 3, 0)
	world.run(world.T + 1.1)
	local okR, whyR = core:RequestHoming(b, world.T) -- (range is checked before the shield)
	assert(okR == false and whyR == "range", "out of range")
	b.pos = ORIGIN + UNDER
	-- A bomb throws a Super player: stunned 1.2 s, the charge and a flight in the air cancelled.
	world.run(world.T + 1.1)
	attackWhenOpen(a) -- a's attack in flight
	core:Charge(b, world.T)
	core:_blast({ id = 900, to = b.pos + Vector3.new(0, -3, 0), battle = true }, world.T)
	core:_blast({ id = 901, to = a.pos + Vector3.new(0, -3, 0), battle = true }, world.T)
	assert(core.participants[a].flight == nil and core.participants[b].chargeAt == nil, "the throw cancels the flight and the charge")
	local okS, whyS = core:RequestHoming(b, world.T)
	assert(okS == false and whyS == "stunned", "stunned right after the throw")
	assert(world.toOne(b, "Knock")[1][4] == "Bomb", "{ Knock, velocity, seconds, Bomb }")
	world.run(world.T + SSE.Battle.SuperRagdollSeconds + 0.1)
	assert(core:RequestHoming(b, world.T) ~= nil and core.participants[b].stunnedUntil < world.T, "the stun wears off")
	-- The cap: past MaxRewardedHits hits still land and damage, but pay nothing.
	world.run(world.T + 1.2, 0.01)
	core.participants[a].hits = SSE.Rewards.MaxRewardedHits
	local rewardsBefore, hpBefore = #world.toOne(a, "Reward"), core.hp
	local tries = 0
	while core.hp == hpBefore and tries < 4000 do
		tries += 1
		world.run(world.T + 0.05)
		if reloadNow() then
			core:RequestHoming(a, world.T)
		end
	end
	assert(core.hp < hpBefore, "a hit past the cap still damages the ship")
	assert(#world.toOne(a, "Reward") == rewardsBefore, "but pays nothing")
	core:Stop("admin")
	pass("homing: 320 studs/s; the shield: the attack flies and bounces off (HomingNo Shielded + Knock 70 out / 30 up, no ragdoll, ShieldHit, no damage, cooldown spent, stunned); Charge -> Homing measured by the server (0.35 s of 0.7 = 0.5 -> 2 dmg; client 0.3 caps; full in 0.7 s -> 3); the jump attack with no Charge -> 1; a stale press and charge01 0 -> 1; busy / cooldown / range; a throw stuns 1.2 s and cancels; past the cap hits land unpaid")
end

-- 3c. The blast in detail (a bomb at a known point).
do
	local world = newWorld()
	local core = world.core
	local inside = world.add(1, Vector3.new(10, 3, 0))
	local edge = world.add(2, Vector3.new(21.5, 3, 0))
	local outside = world.add(3, Vector3.new(22.5, 3, 0))
	local racer = world.add(4, Vector3.new(0, 3, 5), { racing = true })
	local afk = world.add(5, Vector3.new(0, 3, -5), { afk = true })
	local dead = world.add(6, Vector3.new(3, 3, 3), { alive = false })
	core:Start()
	-- (v3: outside the freeze windows: the Bombard, its own salvos held back)
	world.run(BOMBARD + 0.05)
	core.launches, core.bombs, core.salvosFired = {}, {}, 99
	local bombAt = ORIGIN
	core:_blast({ id = 99, to = bombAt }, world.T)
	local victims = {}
	for _, r in world.ragdolls do
		victims[r.player] = r
	end
	assert(victims[inside] and victims[edge] and not victims[outside], "22 studs")
	assert(not victims[racer] and not victims[afk] and not victims[dead], "racing / AFK / dead players are never thrown")
	nearV(victims[inside].velocity, (inside.pos - bombAt).Unit * 55 + Vector3.new(0, 42, 0), 1e-3, "exact throw")
	core:_blast({ id = 100, to = bombAt }, world.T)
	assert(#world.ragdolls == 2, "no double throw inside KnockGrace")
	world.T += SSE.Bombard.KnockGrace + 0.01
	core:_blast({ id = 101, to = bombAt }, world.T)
	assert(#world.ragdolls == 4, "thrown again after KnockGrace")
	inside.pos = ORIGIN + Vector3.new(60, -(SSE.Bombard.RescueDrop + 5), 0)
	world.T += 0.3
	core:_scan(world.T)
	assert(#world.rescues == 1 and world.rescues[1] == inside, "rescued off the sky lobby")
	edge.pos = ORIGIN + Vector3.new(0, -(SSE.Bombard.RescueDrop + 5), 0)
	world.T += SSE.Bombard.RescueSeconds + 1
	core:_scan(world.T)
	assert(#world.rescues == 1, "only within RescueSeconds of a throw")
	-- In the Bombard a Super player (a late one) is left alone; a Battle bomb throws them.
	core.participants[outside].super = true
	outside.pos = ORIGIN + Vector3.new(5, 3, 0)
	world.T += 1
	core:_blast({ id = 102, to = bombAt }, world.T)
	for _, r in world.ragdolls do
		assert(r.player ~= outside, "a Bombard bomb leaves Super players alone")
	end
	core:_blast({ id = 103, to = bombAt, battle = true }, world.T)
	local thrownSuper = false
	for _, r in world.ragdolls do
		if r.player == outside then
			thrownSuper = r.seconds == SSE.Battle.SuperRagdollSeconds
		end
	end
	assert(thrownSuper, "a Battle bomb throws a Super player for 1.2 s")
	core.participants[outside].super = false
	core:Stop("admin")
	pass("blast: within 22 studs only, exact throw, not racing / AFK / dead, KnockGrace, rescue within RescueSeconds; Super players only by Battle bombs (1.2 s)")
end

-- 3d. Timeout (escape), kill switch, leaving, dying, late participants (+HP), racing, the area, no-flight flags.
do
	-- Escape: nobody hits the ship; the Escape phase plays out, then the end (no rings, nothing paid).
	local world = newWorld()
	local a = world.add(1, UNDER)
	world.core:Start()
	world.run(BATTLE + D.Battle - 0.05, 0.1)
	assert(world.worldAttrs.SSE_Phase == "Battle", "still in the Battle")
	world.run(BATTLE + D.Battle + 0.1, 0.05)
	assert(world.worldAttrs.SSE_Phase == "Escape" and world.worldAttrs.SSE_PhaseStart == BATTLE + D.Battle, "the Escape phase")
	assert(#world.messages("Escape") == 1 and world.chat[#world.chat] == SSE.Announcements.Escape, "Escape + chat")
	assert(world.core.plan.endStart == BATTLE + D.Battle and world.core.plan.outcome == "Escape", "the path flies away")
	assert(a.attrs.SSE_Super == true, "Super through the escape's cinematic")
	world.run(BATTLE + D.Battle + D.Escape + 0.1, 0.05)
	assert(world.worldAttrs.SSE_Phase == "Return" and world.worldAttrs.SSE_Outcome == "Escape", "v3: then the Return beat")
	world.run(BATTLE + D.Battle + D.Escape + D.Return + 0.1, 0.05)
	assert(world.worldAttrs.SSE_Phase == "" and a.attrs.SSE_Super == nil and a.walkFloor == nil and world.noFlight[a] == false, "escape: cleaned up, Flight back")
	assert(#world.messages("Defeat") == 0 and #world.messages("Rings") == 0 and #world.grants == 0 and not world.core:HasRings(), "no defeat, no rings, nothing paid")

	-- Kill switch mid-Bombard: stops at once; refuses a new start.
	world = newWorld()
	a = world.add(1, UNDER)
	world.core:Start()
	world.run(BOMBARD + 3)
	world.on = false
	world.run(BOMBARD + 3.2)
	assert(world.core:IsRunning() == false and world.worldAttrs.SSE_Phase == "" and world.noFlight[a] == false, "kill switch: stopped, Flight back")
	local okS, why = world.core:Start()
	assert(okS == false and why == "off", "kill switch: no new event")
	local okH, whyH = world.core:RequestHoming(a, world.T)
	assert(okH == false and whyH == "off", "kill switch: homing refused")
	world.on = true
	world.core:Start()
	world.run(world.T + D.Cinematic + D.Teleport + D.Bombard + D.Emeralds + 0.5)
	assert(a.attrs.SSE_Super == true, "Super in the second event")
	world.on = false
	world.run(world.T + 0.1)
	assert(a.attrs.SSE_Super == nil and a.walkFloor == nil and world.worldAttrs.SSE_Phase == "" and world.worldAttrs.SSE_EventId == nil,
		"kill switch in the Battle: restored and cleared")

	-- Leaving mid-event; dying; late participants raising the HP; racing; leaving the area.
	world = newWorld()
	a = world.add(1, UNDER)
	local b = world.add(2, UNDER + Vector3.new(2, 0, 0))
	local late = world.add(3, Vector3.new(0, 3, 0), { alive = false }) -- dead at the absorption
	local extra = world.add(7, UNDER + Vector3.new(-2, 0, 0), { alive = false }) -- dead too
	local core = world.core
	core:Start()
	world.run(BATTLE + 0.1)
	world.quiet()
	assert(a.attrs.SSE_Super == true and b.attrs.SSE_Super == true and late.attrs.SSE_Super == nil, "Super (not while dead)")
	local hp2 = SSE.BossMaxHP(2)
	assert(core.maxHp == hp2 and core.peak == 2, "HP for 2 participants")
	-- (v3: attacks in the Attack windows fly and bounce off: attack only in a Reload window)
	local function reloadNow()
		local state, _, f = SSE.BossState(world.T - BATTLE, SEED)
		return state == "Reload" and world.T - BATTLE + 0.4 < f
	end
	local function hitOnce(player)
		-- the next moment the attack arrives in a Reload window
		local guard = 0
		while not (reloadNow() and core:RequestHoming(player, world.T)) do
			guard += 1
			assert(guard < 3000, "an attack for " .. player.Name)
			world.run(world.T + 0.05)
		end
		world.run(world.T + SSE.Homing.Cooldown + 0.05, 0.05)
	end
	hitOnce(a)
	hitOnce(a)
	assert(#world.grants == 1, "the second hit waits for its batch")
	local guard = 0
	while not (reloadNow() and core:RequestHoming(a, world.T)) do
		guard += 1
		assert(guard < 3000, "a third attack")
		world.run(world.T + 0.05)
	end
	world.remove(a)
	core:PlayerRemoving(a)
	assert(world.paid(a) == 1200, "leaving: every landed hit paid (" .. world.paid(a) .. ")")
	world.run(world.T + 2)
	assert(world.paid(a) == 1200 and a.attrs.SSE_Hits == 2, "the attack in flight when a left never lands")
	local rejoined = world.add(1, UNDER)
	world.run(world.T + 0.5)
	assert(core.participants[rejoined] and core.participants[rejoined].hits == 2, "the count follows the account across a rejoin")
	world.remove(rejoined)
	core:PlayerRemoving(rejoined)
	-- b dies: the Super form ends (the service puts the own skin back); a respawn at the spawn: Super again.
	b.alive = false
	core:CharacterReset(b)
	assert(b.attrs.SSE_Super == nil and b.walkFloor == nil, "died: restored")
	local okD, whyD = core:RequestHoming(b, world.T)
	assert(okD == false and (whyD == "notSuper" or whyD == "dead"), "dead: refused (" .. tostring(whyD) .. ")")
	local hpBefore, maxBefore = core.hp, core.maxHp
	b.alive = true
	late.alive = true
	world.run(world.T + 0.5)
	assert(b.attrs.SSE_Super == true and late.attrs.SSE_Super == true, "late transformation (respawn / arrival during the Battle)")
	assert(core.maxHp == maxBefore and core.hp == hpBefore, "2 participants again (a left, late came): no more HP")
	extra.alive = true
	world.run(world.T + 0.5)
	assert(extra.attrs.SSE_Super == true, "a 3rd participant")
	local hp3 = SSE.BossMaxHP(3)
	assert(core.peak == 3 and core.maxHp == hp3 and core.hp == hpBefore + (hp3 - maxBefore), "a 3rd participant raises the HP by HP(3) - HP(2)")
	assert(world.worldAttrs.SSE_BossMaxHP == hp3 and world.worldAttrs.SSE_BossHP == core.hp, "the attributes follow")
	b.racing = true
	world.run(world.T + 0.5)
	assert(b.attrs.SSE_Super == nil, "racing: restored")
	assert(core.maxHp == hp3, "the HP never shrinks")
	b.racing = false
	-- Leaving the area (past the exit radius): restored, Flight back; back: Super again, no Flight.
	late.pos = ORIGIN + Vector3.new(SSE.Lobby.ExitRadius + 10, 3, 0)
	world.run(world.T + 0.5)
	assert(late.attrs.SSE_Super == nil and world.noFlight[late] == false, "left the area: restored, Flight back")
	late.pos = ORIGIN + Vector3.new(SSE.Lobby.Radius + 20, 3, 0)
	world.run(world.T + 0.5)
	assert(late.attrs.SSE_Super == nil and world.noFlight[late] == false, "hysteresis: not back until inside Radius")
	late.pos = ORIGIN + UNDER
	world.run(world.T + 0.5)
	assert(late.attrs.SSE_Super == true and world.noFlight[late] == true, "back in the area: Super, no Flight")
	core:Stop("admin")
	assert(world.noFlight[late] == false and world.noFlight[b] == false, "the end: Flight back for everyone")
	pass("escape phase (7 s, the flight away, no rings, then the Return); kill switch; leaving pays every landed hit; death / racing / leaving the area end the Super form; late participants raise the HP (never lowered); no-flight flags follow the area")

	-- Commits: Pending retried with the same id, then counted once.
	world = newWorld()
	a = world.add(1, UNDER)
	world.grantKinds = { "Pending", "Pending", "Committed" }
	world.core:Start()
	world.run(BATTLE + 0.1)
	world.quiet()
	guard = 0
	while not (SSE.BossState(world.T - BATTLE, SEED) == "Reload" and world.core:RequestHoming(a, world.T)) do
		guard += 1
		world.run(world.T + 0.05)
	end
	world.run(world.T + 1.2)
	assert(#world.grants == 3 and world.grants[1].operationId == world.grants[3].operationId, "Pending retried with the same operation id")
	assert(world.paid(a) == 600, "paid once")
	world.core:Stop("admin")
	pass("commits: Pending retried with the same operation id, paid once")
end

-- 3e. The defeat's gold rings.
do
	local world = newWorld()
	local players = {}
	for i = 1, 4 do
		players[i] = world.add(i, UNDER + Vector3.new(i * 2, 0, 0))
	end
	local core = world.core
	core:Start()
	world.run(BATTLE + 0.1)
	world.quiet()
	core.hp = 1
	local guard = 0
	while world.worldAttrs.SSE_Phase == "Battle" do
		guard += 1
		assert(guard < 4000, "defeated")
		core:RequestHoming(players[1], world.T)
		world.run(world.T + 0.05)
	end
	local defeatAt = world.worldAttrs.SSE_PhaseStart
	local message = world.messages("Rings")[1]
	local positions, landAt, expireAt = message[3], message[4], message[5]
	local count = SSE.RingCount(4)
	assert(#positions <= count and #positions >= count * 0.9, "RingCount(4) = " .. count .. " rings landed, retries closer in (" .. #positions .. ")")
	for _, pos in positions do
		assert(flat(pos - ORIGIN).Magnitude <= LOBBY_FLOOR + 1e-3, "on the walkable floor (not the slope, not the void)")
		near(pos.Y, ORIGIN.Y + SSE.Rings.Height, 1e-3, "RingHeight over the floor")
	end
	-- The same seed, the same rain.
	local again = newWorld()
	for i = 1, 4 do
		again.add(i, UNDER + Vector3.new(i * 2, 0, 0))
	end
	again.core:Start()
	again.T = BATTLE + 0.1
	again.core:Step()
	again.core.peak = 4
	again.core:_dropRings(defeatAt)
	local other = again.messages("Rings")[1][3]
	assert(#other == #positions, "same count")
	for i, pos in positions do
		nearV(other[i], pos, 1e-4, "same spots")
	end
	again.core:Stop("admin")

	local taker, rival = players[2], players[3]
	local function stand(player, id)
		player.pos = positions[id] + Vector3.new(1, 0.5, 1)
	end
	stand(taker, 1)
	local okE, whyE = core:_takeRing(taker, 1)
	assert(not okE and whyE == "early" and world.toOne(taker, "RingNo")[1][3] == "early", "before they land: early")
	world.run(landAt + 0.01)
	taker.pos = positions[1] + Vector3.new(30, 0, 0)
	local okF, whyF = core:_takeRing(taker, 1)
	assert(not okF and whyF == "far", "far")
	stand(taker, 1)
	assert(core:ClientMessage(taker, { "RingTake", 1 }) == "RingTake", "{ RingTake, id }")
	local gone = world.messages("RingGone")
	assert(#gone == 1 and gone[1][2] == 1 and gone[1][3] == taker.UserId, "RingGone { id, userId } to everyone")
	local reward = world.toOne(taker, "Reward")
	assert(reward[#reward][2] == 50 and reward[#reward][3] == 2500 and reward[#reward][4] == "ring", "Reward { 50, 2500, ring }")
	assert(taker.attrs.SSE_Rings == 1, "SSE_Rings")
	stand(rival, 1)
	local okG, whyG = core:_takeRing(rival, 1)
	assert(not okG and whyG == "gone", "taken: gone for everyone else")
	for _, junk in { 0, 1.5, "x", 9999 } do
		local okJ, whyJ = core:_takeRing(rival, junk)
		assert(not okJ and whyJ == "gone", "junk id: gone (" .. tostring(junk) .. ")")
	end
	-- A batch: the one within reach is taken, the far one refused.
	stand(taker, 2)
	assert(core:RingTake(taker, { 2, 3 }) == 1, "an array of ids: 1 taken, 1 far")
	-- The per-player cap: the ring stays for the others.
	core.participants[rival].rings = SSE.Rings.MaxPerPlayer
	stand(rival, 4)
	local okC, whyC = core:_takeRing(rival, 4)
	assert(not okC and whyC == "cap" and core.rings.list[4].taken == nil, "30 a player; the ring stays")
	-- Dead takers.
	players[4].alive = false
	local okD, whyD = core:_takeRing(players[4], 4)
	assert(not okD and whyD == "dead", "dead")
	players[4].alive = true
	-- v3: the rings live through the Defeat (gone before the Return beat); a late joiner gets them meanwhile.
	assert(expireAt < defeatAt + D.Defeat, "they expire before the Return")
	world.run(defeatAt + SSE.FreezeWindows.Defeat.End + 1)
	assert(core:IsRunning() and core:HasRings(), "the Defeat goes on, the rings are out")
	stand(players[4], 4)
	assert(core:_takeRing(players[4], 4) == true, "taken during the Defeat")
	local newcomer = world.add(9, Vector3.new(0, 3, 0))
	core:PlayerJoined(newcomer)
	local snapshot = world.toOne(newcomer, "Rings")[1]
	assert(snapshot and #snapshot[3] == #positions and table.find(snapshot[7], 1) and table.find(snapshot[7], 2) and table.find(snapshot[7], 4)
		and not table.find(snapshot[7], 3), "a late joiner gets the rain with the taken ids")
	-- Expiry: gone, every ring reward committed.
	world.run(expireAt + 0.2)
	assert(not core:HasRings(), "expired")
	assert(taker.attrs.SSE_Rings == nil, "SSE_Rings cleared")
	local wins, speed = world.paid(taker)
	local rewards = world.toOne(taker, "Reward")
	local expectWins, expectSpeed = 0, 0
	for _, r in rewards do
		expectWins += r[2]
		expectSpeed += r[3]
	end
	assert(wins == expectWins and speed == expectSpeed and expectWins >= 100, "every ring (and hit) paid, once (" .. wins .. ")")
	local okX, whyX = core:_takeRing(rival, 5)
	assert(not okX and whyX == "gone", "after the expiry: gone")
	world.run(defeatAt + D.Defeat + D.Return + 0.1)
	assert(not core:IsRunning(), "then the Return and the end")
	-- An admin stop (or a new event) clears the rings at once.
	local w2 = newWorld()
	local p1 = w2.add(1, UNDER)
	w2.core:Start()
	w2.run(w2.T + D.Cinematic + D.Teleport + D.Bombard + D.Emeralds + 0.1)
	w2.quiet()
	w2.core.hp = 1
	guard = 0
	while w2.worldAttrs.SSE_Phase == "Battle" do
		guard += 1
		assert(guard < 4000, "defeated (2)")
		w2.core:RequestHoming(p1, w2.T)
		w2.run(w2.T + 0.05)
	end
	assert(w2.core:HasRings(), "rings out")
	w2.core:Stop("admin")
	assert(not w2.core:HasRings() and #w2.messages("RingsClear") == 1 and w2.messages("RingsClear")[1][2] == 1, "an admin stop clears them: RingsClear")
	-- The kill switch in the Defeat, with the rings out: they go, and what they paid is committed.
	local w3 = newWorld()
	local q = w3.add(1, UNDER)
	w3.core:Start()
	w3.run(w3.T + D.Cinematic + D.Teleport + D.Bombard + D.Emeralds + 0.1)
	w3.quiet()
	w3.core.hp = 1
	guard = 0
	while w3.worldAttrs.SSE_Phase == "Battle" do
		guard += 1
		assert(guard < 4000, "defeated (3)")
		w3.core:RequestHoming(q, w3.T)
		w3.run(w3.T + 0.05)
	end
	assert(w3.core:IsRunning() and w3.core:HasRings(), "the Defeat, the rings out")
	local rain = w3.messages("Rings")[1]
	w3.run(rain[4] + 0.01)
	q.pos = rain[3][1] + Vector3.new(0, 0.5, 0)
	assert(w3.core:_takeRing(q, 1) == true, "a ring taken")
	w3.on = false
	w3.run(w3.T + 0.05)
	assert(not w3.core:HasRings() and #w3.messages("RingsClear") == 1, "the kill switch clears the rings")
	local expected = 0
	for _, r in w3.toOne(q, "Reward") do
		expected += r[2]
	end
	assert(w3.paid(q) == expected, "and commits what they paid (" .. w3.paid(q) .. ")")
	pass("rings: RingCount by participants on the walkable floor (seeded), early / far / gone / cap / dead refusals, RingGone + Reward { 50, 2500, ring }, batches, through the Defeat (gone before the Return), late joiners, expiry commits, RingsClear on an admin stop / the kill switch")
end

-- 3f. Determinism, an empty lobby, the rate limit.
do
	local function bombsFor(seed)
		local world = newWorld({ seed = seed })
		world.add(1, Vector3.new(0, 3, 0))
		world.add(2, Vector3.new(15, 3, -10))
		world.add(3, Vector3.new(-20, 3, 12))
		world.core:Start()
		world.run(BATTLE + 40)
		local list = {}
		for _, message in world.messages("Bomb") do
			table.insert(list, string.format("%.3f,%.3f,%s", message[4].X, message[4].Z, message[7]))
		end
		world.core:Stop("admin")
		return table.concat(list, ";")
	end
	assert(bombsFor(777) == bombsFor(777), "same seed, same bombs")
	assert(bombsFor(777) ~= bombsFor(778), "another seed, other bombs")
	local r1, r2 = Core.NewRng(42), Core.NewRng(42)
	for _ = 1, 50 do
		local x = r1()
		assert(x == r2() and x >= 0 and x < 1, "rng in [0, 1), repeatable")
	end
	-- Nobody in the lobby: bombs still fall near the spawn; the cinematic's default lift-off.
	local world = newWorld({ noLift = true })
	world.core:Start()
	assert(world.worldAttrs.SSE_LiftOff == nil, "no lobby Eggman: no SSE_LiftOff")
	world.run(EMERALDS)
	local bombs = world.messages("Bomb")
	assert(#bombs == 2 * SSE.BombsPerSalvo(0) + 1 * SSE.Bombard.Parallel.BombardCount, "an empty lobby still gets its salvos (" .. #bombs .. ")")
	for _, message in bombs do
		assert(flat(message[4] - ORIGIN).Magnitude <= SSE.Bombard.FallbackRadius + SSE.Bombard.Parallel.Spacing + 0.01, "near the spawn")
	end
	world.core:Stop("admin")
	-- The rate limit: a burst of Burst messages, then dropped; refilled over time. Unknown names cost nothing.
	world = newWorld()
	local p = world.add(1, UNDER)
	world.core:Start()
	for _ = 1, 5 do
		assert(world.core:ClientMessage(p, { "Bomb", 1 }) == nil and world.core:ClientMessage(p, "junk") == nil, "unknown: ignored")
	end
	for i = 1, SSE.RateLimit.Burst do
		assert(world.core:ClientMessage(p, { "Charge", world.T }) == "Charge", "burst " .. i)
	end
	assert(world.core:ClientMessage(p, { "Charge", world.T }) == "limited", "over the burst: dropped")
	world.T += 1 / SSE.RateLimit.PerSecond + 1e-6
	assert(world.core:ClientMessage(p, { "Homing", world.T }) == "Homing", "refilled")
	world.core:Stop("admin")
	pass("determinism: the seed decides the bombs; an empty lobby still gets bombs near the spawn (default lift-off); rate limit: 12 burst, 15/s")
end

----------------------------------------------------------------------
-- 3g. 2026-09-26 (owner): v3's pure parts: the trips, the freeze windows, the shield, the race closure's names
----------------------------------------------------------------------
do
	-- CheckTeleport, every refusal, in order.
	local base = { on = true, phase = "Battle", sameEvent = true, alive = true, racing = false, afk = false, busy = false, lastAt = nil,
		now = 100, inArena = false }
	local function with(overrides)
		local input = table.clone(base)
		for k, v in overrides do
			input[k] = v
		end
		return input
	end
	assert(SSE.CheckTeleport(base) == true, "a valid trip")
	local R = SSE.TeleportRefusals
	for _, case in {
		{ { on = false }, R.Off }, { { phase = "Defeat" }, R.Phase }, { { phase = "Escape" }, R.Phase }, { { phase = "Return" }, R.Phase },
		{ { phase = "" }, R.Phase }, { { sameEvent = false }, R.Phase }, { { alive = false }, R.Dead }, { { racing = true }, R.Racing },
		{ { afk = true }, R.Afk }, { { busy = true }, R.Busy }, { { lastAt = 97 }, R.Cooldown }, { { inArena = true }, R.Here },
	} do
		local ok, reason = SSE.CheckTeleport(with(case[1]))
		assert(ok == false and reason == case[2], "trip refused: " .. case[2] .. " (got " .. tostring(reason) .. ")")
	end
	for _, phase in { "Cinematic", "Teleport", "Bombard", "Emeralds", "Battle" } do
		assert(SSE.InviteOpen(phase) and SSE.CheckTeleport(with({ phase = phase })) == true, "invites and trips open in " .. phase)
	end
	assert(SSE.CheckTeleport(with({ lastAt = 100 - SSE.Teleport.Cooldown })) == true, "the cooldown wears off")
	-- The spots: the ellipse round the centre, distinct, clear of players and bombs.
	local T = SSE.Teleport
	local seen = {}
	for k = 1, T.Candidates do
		local c = SSE.TeleportCandidate(ARENA, k)
		local dx, dz = c.X - ARENA.X, c.Z - ARENA.Z
		assert(math.abs(dx) <= T.Across + 0.01 and math.abs(dz) <= T.Along + 0.01 and math.sqrt(dx * dx + dz * dz) >= T.MinRadius - 0.01,
			"a spot inside the ellipse, out of the centre")
		assert(math.abs(dx) <= 36, "inside the arena's corridor")
		local key = string.format("%.1f,%.1f", dx, dz)
		assert(not seen[key], "distinct spots")
		seen[key] = true
	end
	assert(T.Candidates >= 60, "enough spots for a full server (60)")
	local spot = ARENA + Vector3.new(10, 0, 0)
	assert(SSE.SpotClear(spot, { ARENA + Vector3.new(10 + T.Clearance + 0.1, 3, 0) }, {}), "clear of a player Clearance away")
	assert(not SSE.SpotClear(spot, { ARENA + Vector3.new(10 + T.Clearance - 0.1, 3, 0) }, {}), "not on a player")
	assert(not SSE.SpotClear(spot, {}, { spot + Vector3.new(SSE.Bombard.BlastRadius + T.BombMargin - 1, 0, 0) }), "never under a falling bomb")
	assert(SSE.SpotClear(spot, {}, { spot + Vector3.new(SSE.Bombard.BlastRadius + T.BombMargin + 1, 0, 0) }), "clear of the bomb's blast + margin")
	-- The freeze windows (per phase, with their area).
	local F = SSE.FreezeWindows
	assert(F.Cinematic.End == D.Cinematic and F.Cinematic.Area == "Lobby", "the whole Cinematic, in the lobby")
	assert(F.Teleport.End >= SSE.Beats.Teleport.FadeIn and F.Teleport.End < D.Teleport and F.Teleport.Area == "Both", "the Teleport beat's fades")
	assert(F.Emeralds.End > SSE.Emeralds.AbsorbAt and F.Emeralds.End < D.Emeralds and F.Emeralds.Area == "Arena", "the Emeralds shot")
	assert(F.Defeat.End > SSE.CrashTimes(0).ringsLand and F.Defeat.End < SSE.CrashTimes(0).ringsLand + 1, "the crash, until the rings have landed")
	assert(F.Escape.End < D.Escape and F.Return.End == D.Return, "the Escape's outro, the Return beat")
	assert(F.Bombard == nil and F.Battle == nil, "never in the Bombard or the Battle (bombs to dodge, attacks to make)")
	local start, finish, area = SSE.FreezeWindow("Intro")
	assert(start == 0 and finish == D.Cinematic and area == "Lobby", "FreezeWindow (old name too)")
	assert(SSE.IsFrozen("Cinematic", 0) and SSE.IsFrozen("Cinematic", 7.5) and not SSE.IsFrozen("Cinematic", 7.6), "IsFrozen: the window")
	assert(SSE.IsFrozen("Emeralds", 6.5, SSE.Freeze.FallGraceSeconds) and not SSE.IsFrozen("Emeralds", 6.5), "the server's grace after the End")
	assert(not SSE.IsFrozen("Battle", 3) and not SSE.IsFrozen("", 0) and not SSE.IsFrozen("Cinematic", 0 / 0), "never elsewhere")
	local inLobby, inArena, away = ORIGIN + Vector3.new(4, 3, 0), ARENA + Vector3.new(4, 3, 0), ORIGIN + Vector3.new(900, 3, 0)
	assert(SSE.FreezesHere("Cinematic", 2, inLobby, ARENA, ORIGIN) and not SSE.FreezesHere("Cinematic", 2, away, ARENA, ORIGIN)
		and not SSE.FreezesHere("Cinematic", 2, inArena, ARENA, ORIGIN), "the Cinematic freezes the lobby only")
	assert(SSE.FreezesHere("Emeralds", 2, inArena, ARENA, ORIGIN) and not SSE.FreezesHere("Emeralds", 2, inLobby, ARENA, ORIGIN),
		"the Emeralds shot freezes the arena only (the lobby's world is normal)")
	assert(SSE.FreezesHere("Teleport", 0.5, inLobby, ARENA, ORIGIN) and SSE.FreezesHere("Teleport", 1, inArena, ARENA, ORIGIN), "the beat: both")
	assert(not SSE.FreezesHere("Battle", 2, inArena, ARENA, ORIGIN) and not SSE.FreezesHere("Emeralds", 6.5, inArena, ARENA, ORIGIN), "not outside a window")
	assert(SSE.FreezesHere("Emeralds", 2, inLobby, ORIGIN, nil), "no race arena: the lobby is the arena")
	-- The shield's bounce.
	local ship = Vector3.new(0, 40, 0)
	nearV(SSE.ShieldKnock(Vector3.new(30, 3, 40), ship), Vector3.new(0.6 * 70, 30, 0.8 * 70), 1e-4, "70 out along the way the attack came, 30 up")
	nearV(SSE.ShieldKnock(Vector3.new(0, 3, 0), ship), Vector3.new(0, 30, 70), 1e-4, "straight under the ship: toward +Z")
	-- The race closure's names match the race service and the texts.
	local RaceService = require("../src/common/ServerScriptService/Services/Race/RaceService")
	local RaceText = require("../src/common/ReplicatedStorage/Shared/RaceText")
	assert(SSE.RaceClosed.Attribute == RaceService.ClosedAttribute and SSE.RaceClosed.Refusal == RaceService.ClosedRefusal
		and SSE.RaceClosed.Unqueued == RaceService.ClosedUnqueued and SSE.RaceClosed.Reason == "SuperSonicEvent", "RaceClosed = the race service's names")
	assert(RaceText.Caps.RaceEventClosed and RaceText.UnqueuedToast.Event == "RaceEventClosed", "the toast and the Unqueued reason have their texts")
	for _, lang in RaceText.Languages do
		assert(type(RaceText.Strings[lang].RaceEventClosed) == "string", lang .. ": RaceEventClosed")
	end
	-- The arena point: the race arena's track at TrackS (the three worlds share it), on flat ground.
	local U4 = require("../src/common/ReplicatedStorage/Shared/Update4Config")
	local o = U4.Race.Arena.Origin
	assert(SSE.RaceArena.Origin[1] == o.X and SSE.RaceArena.Origin[2] == o.Y and SSE.RaceArena.Origin[3] == o.Z, "RaceArena.Origin = Update4Config.Race.Arena.Origin")
	for _, key in { "World1", "World2", "World3" } do
		nearV(SSE.ArenaOrigin(key), Vector3.new(o.X, o.Y, o.Z - SSE.RaceArena.TrackS), 1e-6, "ArenaOrigin(" .. key .. ")")
	end
	assert(SSE.RaceArena.TrackS > 0 and SSE.RaceArena.TrackS < U4.Race.Track.Length, "on the track")
	pass("v3 pure: CheckTeleport (off / phase / dead / racing / afk / busy / cooldown / here), the spots (ellipse on the corridor, 64, clear of players and bombs), the freeze windows per phase and area, ShieldKnock, RaceClosed names = the race service's + the texts in 10 languages, ArenaOrigin")
end

----------------------------------------------------------------------
-- 3h. 2026-09-26 (owner): v3. The fight on the race arena: lobby -> Teleport beat -> arena -> Return beat
----------------------------------------------------------------------
do
	local world = newWorld({ arena = true })
	local core = world.core
	local W, A = world.worldAttrs, SSE.Attributes
	local a = world.add(1, Vector3.new(0, 3, 0))
	local b = world.add(2, Vector3.new(6, 3, 4))
	local stages = world.add(3, Vector3.new(1000, 3, 0)) -- out on the obstacle stages
	local far = world.add(6, Vector3.new(-900, 3, 200)) -- far away too
	local racer = world.add(4, Vector3.new(0, 3, 0), { racing = true })
	racer.pos = ARENA + Vector3.new(0, 3, 380) -- racing on the track
	local afk = world.add(5, Vector3.new(-4, 3, 2), { afk = true })
	-- The race service calls the heat off and sends the racer to the lobby spawn (Close's trip).
	world.onCloseRaces = function()
		racer.racing = false
		racer.pos = ORIGIN + Vector3.new(-8, 3, -6)
		return { racer }
	end
	local function invitesOf(player)
		return world.toOne(player, "Invite")
	end
	assert(core:Start("Tester") == true, "Start")
	nearV(W[A.Origin], ARENA, 1e-6, "SSE_Origin = the arena point")
	nearV(W[A.LobbyOrigin], ORIGIN, 1e-6, "SSE_LobbyOrigin = the lobby spawn")
	assert(world.racesClosed == "SuperSonicEvent" and core.stats.pulled == 1 and core:Status().racesClosed == true, "the races close at the start")
	assert(#world.gates == 1 and world.gates[1] == true, "the arena's gates open")
	assert(#invitesOf(stages) == 1 and invitesOf(stages)[1][2] == 1 and invitesOf(stages)[1][3] == "start", "{ Invite, eventId, start } to the stages")
	assert(#invitesOf(far) == 1, "and to anyone far away")
	assert(#invitesOf(racer) == 1 and invitesOf(racer)[1][3] == "race", "the racer: { Invite, eventId, race }")
	assert(#invitesOf(a) == 0 and #invitesOf(b) == 0 and #invitesOf(afk) == 0, "the lobby is not invited (the beat moves it); AFK left alone")
	assert(world.noFlight[a] == true and world.noFlight[b] == true and world.noFlight[stages] == nil, "no Flight for the lobby's audience; the stages keep it")
	-- The Cinematic in the lobby: the stages player accepts: a trip to the LOBBY (the beat takes them on).
	world.run(T0 + 2)
	local okEarly, earlySpot = core:RequestTeleport(stages, 1)
	assert(okEarly == true and SSE.InLobby(earlySpot, ORIGIN) and not SSE.InArena(earlySpot, ARENA), "before the move: a trip to the lobby")
	local goEarly = world.toOne(stages, "TeleportGo")[1]
	assert(goEarly and goEarly[2] == 1 and goEarly[3] == earlySpot, "{ TeleportGo, eventId, position }")
	assert(world.trips[#world.trips].home == true and stages.pos == earlySpot, "the world's own spawn trip (home)")
	near(earlySpot.Y, ORIGIN.Y + SSE.Teleport.Height, 1e-3, "on the lobby floor")
	world.run(TELEPORT + 0.01)
	assert(W[A.Phase] == "Teleport" and SSE.InLobby(a.pos, ORIGIN), "the Teleport beat; still in the lobby before its move")
	world.run(TELEPORT + SSE.Beats.Teleport.MoveAt + 0.01)
	local moved = { a, b, racer, stages }
	for i, p in moved do
		assert(SSE.InArena(p.pos, ARENA), p.Name .. " moved to the arena")
		near(p.pos.Y, ARENA.Y + SSE.Teleport.Height, 1e-3, p.Name .. " on the arena floor")
		assert(math.abs(p.pos.X - ARENA.X) <= SSE.Teleport.Across + 0.01, p.Name .. " inside the corridor")
		for j = i + 1, #moved do
			assert(flat(p.pos - moved[j].pos).Magnitude >= SSE.Teleport.Clearance - 1e-3, "free spots, apart")
		end
	end
	assert(core.stats.movedIn == 4 and SSE.InLobby(afk.pos, ORIGIN) and flat(far.pos - ORIGIN).Magnitude > 800, "the AFK player and the far one stay")
	for _, trip in world.trips do
		if trip.T >= TELEPORT then
			assert(trip.home == false, "trips to the arena are not spawn trips")
		end
	end
	world.run(TELEPORT + 1)
	assert(world.noFlight[afk] == false, "after the move the lobby has its world back (Flight)")
	assert(world.noFlight[a] == true and world.noFlight[stages] == true, "no Flight in the arena")
	-- Bombs fall in the arena; the far player accepts in the Bombard: straight to the arena.
	world.run(BOMBARD + 3)
	for _, message in world.messages("Bomb") do
		assert(SSE.InArena(message[4], ARENA, true), "a bomb lands in the arena")
	end
	local okFar, farSpot = core:RequestTeleport(far, 1)
	assert(okFar == true and SSE.InArena(farSpot, ARENA) and far.pos == farSpot and world.trips[#world.trips].home == false, "after the move: a trip to the arena")
	local okAgain, whyAgain = core:RequestTeleport(far, 1)
	assert(okAgain == false and whyAgain == "cooldown" and world.toOne(far, "TeleportNo")[1][2] == "cooldown", "{ TeleportNo, cooldown }")
	local okHere, whyHere = core:RequestTeleport(a, 1)
	assert(okHere == false and whyHere == "here", "already in the event: here")
	local okStale, whyStale = core:RequestTeleport(afk, 99)
	assert(okStale == false and whyStale == "phase", "another event's id: phase")
	local okAfk, whyAfk = core:RequestTeleport(afk, nil)
	assert(okAfk == false and whyAfk == "afk", "AFK: refused")
	-- The absorption in the arena: every participant turns Super, the lobby's AFK player does not.
	world.run(ABSORB + 0.01)
	for _, p in { a, b, racer, stages, far } do
		assert(p.attrs.SSE_Super == true, p.Name .. " Super in the arena")
	end
	assert(afk.attrs.SSE_Super == nil, "not the lobby's AFK player")
	world.run(BATTLE + 0.01)
	world.quiet()
	assert(core.maxHp == SSE.BossMaxHP(5), "HP for the 5 in the arena")
	-- A player who joins mid-Battle spawns in the lobby: invited ("joined"); accepts: the arena, Super at once.
	local late = world.add(9, Vector3.new(2, 3, -3))
	core:PlayerJoined(late)
	world.run(world.T + 0.3)
	assert(#invitesOf(late) == 1 and invitesOf(late)[1][3] == "joined", "a joiner: { Invite, eventId, joined }")
	assert(late.attrs.SSE_Super == nil and world.noFlight[late] == nil, "their world stays normal until they accept")
	assert(core:RequestTeleport(late, 1) == true, "accepted")
	world.run(world.T + 0.3)
	assert(SSE.InArena(late.pos, ARENA) and late.attrs.SSE_Super == true and world.noFlight[late] == true, "in the arena: Super at once (the Battle is on), no Flight")
	assert(core.maxHp == SSE.BossMaxHP(6) and core.peak == 6, "a 6th participant raises the HP")
	-- Bombs spare a player who just arrived (Teleport.SafeSeconds).
	local ragBefore = #world.ragdolls
	core:_blast({ id = 700, to = late.pos + Vector3.new(0, -3, 0), battle = true }, world.T)
	for index = ragBefore + 1, #world.ragdolls do
		assert(world.ragdolls[index].player ~= late, "a new arrival is not thrown")
	end
	-- A death in the arena respawns in the lobby: invited ("respawn"), their world normal meanwhile.
	b.alive = false
	core:CharacterReset(b)
	world.run(world.T + 0.3)
	b.alive = true
	b.pos = ORIGIN + Vector3.new(3, 3, 3)
	core:CharacterReset(b) -- the new character
	world.run(world.T + 0.3)
	local bInvites = invitesOf(b)
	assert(#bInvites == 1 and bInvites[1][3] == "respawn", "respawned in the lobby: { Invite, eventId, respawn }")
	assert(b.attrs.SSE_Super == nil and world.noFlight[b] == false, "in the lobby: no Super, Flight back until they accept")
	-- Leaving the arena: invited ("left"), at most one every Invite.MinGapSeconds.
	racer.pos = ARENA + Vector3.new(0, 3, -(SSE.Arena.ExitHalfZ + 20))
	world.run(world.T + 0.3)
	local rInvites = invitesOf(racer)
	assert(rInvites[#rInvites][3] == "left" and racer.attrs.SSE_Super == nil, "left the arena: { Invite, eventId, left }, not Super")
	local count = #rInvites
	racer.pos = ARENA + Vector3.new(0, 3, 10)
	world.run(world.T + 0.3)
	assert(racer.attrs.SSE_Super == true, "back in: Super again")
	racer.pos = ARENA + Vector3.new(0, 3, -(SSE.Arena.ExitHalfZ + 20))
	world.run(world.T + 0.3)
	assert(#invitesOf(racer) == count, "no second invite inside Invite.MinGapSeconds")
	world.run(world.T + SSE.Invite.MinGapSeconds)
	assert(#invitesOf(racer) == count + 1, "the owed one after the gap")
	racer.pos = ARENA + Vector3.new(0, 3, 10)
	-- The defeat on the arena: the crash on the corridor's floor, the rings on the track floor.
	core.hp = 1
	local function reloadNow()
		local state, _, f = SSE.BossState(world.T - BATTLE, SEED)
		return state == "Reload" and world.T - BATTLE + 0.4 < f
	end
	local guard = 0
	while W[A.Phase] == "Battle" do
		guard += 1
		assert(guard < 6000, "defeated")
		if reloadNow() then
			core:RequestHoming(a, world.T)
		end
		world.run(world.T + 0.05)
	end
	assert(W[A.Phase] == "Defeat", "HP 0: the Defeat")
	local defeatAt = W[A.PhaseStart]
	local crash = W[A.CrashPoint]
	assert(crash and math.abs(crash.X - ARENA.X) <= SSE.Crash.MaxAcross + 0.01 and math.abs(crash.Y - ARENA.Y) < 1e-3, "the crash on the corridor's floor")
	local rain = world.messages("Rings")[1]
	assert(#rain[3] >= SSE.RingCount(6) * 0.8, "the rings (" .. #rain[3] .. " of " .. SSE.RingCount(6) .. ")")
	for _, pos in rain[3] do
		assert(math.abs(pos.X - ARENA.X) <= ARENA_FLOOR_X and math.abs(pos.Y - (ARENA.Y + SSE.Rings.Height)) < 1e-3, "a ring on the track floor, inside the walls")
	end
	nearV(rain[6], crash + Vector3.new(0, SSE.Crash.RingsUp, 0), 1e-3, "they burst out of the crash point")
	-- No invites after the fight, and no trips.
	local latecomer = world.add(10, Vector3.new(-2, 3, 5))
	core:PlayerJoined(latecomer)
	world.run(world.T + 0.5)
	assert(#invitesOf(latecomer) == 0, "no invite after the defeat")
	local okLate, whyLate = core:RequestTeleport(latecomer, 1)
	assert(okLate == false and whyLate == "phase", "no trip after the defeat")
	-- The Return beat: everyone still in the arena goes home (the world's spawn trip), the gates back, the races open.
	local inArena = {}
	for _, p in { a, racer, stages, far, late } do
		if SSE.InArena(p.pos, ARENA, true) then
			table.insert(inArena, p)
		end
	end
	assert(#inArena == 5, "five in the arena")
	world.run(defeatAt + D.Defeat + 0.05)
	assert(W[A.Phase] == "Return" and SSE.InArena(a.pos, ARENA), "the Return beat; the move comes at MoveAt")
	world.run(defeatAt + D.Defeat + SSE.Beats.Return.MoveAt + 0.05)
	for _, p in inArena do
		assert(SSE.InLobby(p.pos, ORIGIN) and not SSE.InArena(p.pos, ARENA, true), p.Name .. " back in the lobby")
		near(p.pos.Y, ORIGIN.Y + SSE.Teleport.Height, 1e-3, p.Name .. " on the lobby floor")
	end
	assert(core.stats.movedOut == 5 and world.trips[#world.trips].home == true, "the trips home are spawn trips")
	world.run(defeatAt + D.Defeat + D.Return + 0.05)
	assert(not core:IsRunning() and W[A.Phase] == "", "the end")
	assert(world.gates[#world.gates] == false and world.racesOpened == "SuperSonicEvent", "the gates restored, the races open")
	for _, p in inArena do
		assert(p.attrs.SSE_Super == nil and world.noFlight[p] == false, p.Name .. ": restored")
	end
	-- Cut short (an admin stop in the Battle): the arena's players go home at once.
	local w2 = newWorld({ arena = true })
	local q = w2.add(1, Vector3.new(0, 3, 0))
	w2.core:Start()
	w2.run(BATTLE + 3)
	assert(SSE.InArena(q.pos, ARENA), "in the arena")
	w2.core:Stop("admin")
	assert(SSE.InLobby(q.pos, ORIGIN) and w2.trips[#w2.trips].home == true, "an admin stop sends the arena home")
	assert(w2.gates[#w2.gates] == false and w2.racesOpened == "SuperSonicEvent", "and restores the gates, opens the races")
	-- Stopped before the move (the kill switch in the Cinematic): nobody travels.
	local w3 = newWorld({ arena = true })
	local r = w3.add(1, Vector3.new(0, 3, 0))
	w3.core:Start()
	w3.run(T0 + 3)
	w3.on = false
	w3.run(T0 + 3.1)
	assert(not w3.core:IsRunning() and #w3.trips == 0 and SSE.InLobby(r.pos, ORIGIN), "stopped in the Cinematic: nobody travels")
	pass("arena: SSE_Origin = the arena point + SSE_LobbyOrigin, races closed, gates open; invites (start / race; joined; respawn; left, one per " .. SSE.Invite.MinGapSeconds .. " s; none after the defeat); a trip before the move goes to the lobby, after it to the arena (free spots on the floor, apart); the Teleport beat moves the lobby (not AFK, not the far); Flight back in the lobby; bombs in the arena, new arrivals spared; late joiners Super at once; the crash and the rings on the corridor; the Return beat sends the arena home (spawn trips); an admin stop does it at once")
end

----------------------------------------------------------------------
-- 3i. 2026-09-26 (owner): v3. Races vs the event: the real RaceService (Services/Race) with a fake host
----------------------------------------------------------------------
do
	local U4 = require("../src/common/ReplicatedStorage/Shared/Update4Config")
	local RaceTrack = require("../src/common/ReplicatedStorage/Shared/RaceTrack")
	local RaceService = require("../src/common/ServerScriptService/Services/Race/RaceService")
	local RaceChargeJudge = require("../src/common/ServerScriptService/Services/Race/RaceChargeJudge")
	local QUEUE = U4.Race.Queue
	local SPAWN = Vector3.new(280, 37470, -1781)
	local RW = { now = 1000, attrs = {}, players = {}, paid = {}, flags = { Race = true, MegaRace = true } }
	local function racePlayer(id, attrs)
		local p = { UserId = id, Name = "R" .. id, present = true, events = {}, log = {}, races = 0,
			attrs = { DataLoaded = true, FirstTimeTutorialSeen = true, Rebirths = 0, CurrentSafeZoneStage = 0 },
			char = { pos = ORIGIN + Vector3.new(id * 3, 3, 0), alive = true } }
		for k, v in attrs or {} do
			p.attrs[k] = v
		end
		function p:GetAttribute(name)
			return self.attrs[name]
		end
		function p:SetAttribute(name, value)
			self.attrs[name] = value
		end
		table.insert(RW.players, p)
		return p
	end
	local host = {}
	host.now = function() return RW.now end
	host.unix = function() return math.floor(1.8e9 + RW.now) end
	host.isOn = function(feature) return RW.flags[feature] == true end
	host.players = function() return RW.players end
	host.isPlayer = function(p) return p.present == true end
	host.sample = function(p)
		return { alive = p.char.alive, position = p.char.pos, cframe = CFrame.new(p.char.pos), grounded = true }
	end
	host.pivot = function(p, cframe)
		p.char.pos = cframe.Position
		table.insert(p.log, "pivot")
	end
	host.setVelocity = function() end
	host.streamAround = function(_, _, done) done() end
	host.rebase = function(p, progress)
		table.insert(p.log, "rebase")
		p.lastRebase = progress
	end
	host.getProgress = function() return 4 end
	host.armGrace = function(p) table.insert(p.log, "grace") end
	host.teleportToSpawn = function(p)
		p.char.pos = SPAWN
		table.insert(p.log, "spawn")
	end
	host.ping = function() return 0 end
	host.fire = function(p, payload) table.insert(p.events, payload) end
	host.live = function() end
	host.setWorld = function(name, value) RW.attrs[name] = value end
	host.getWorld = function(name) return RW.attrs[name] end
	host.setGateCollide = function(on) RW.gate = on end
	host.rawSpeed = function() return 1e4 end
	host.bracket = function() return "Mid" end
	host.pads = function() return {} end
	host.suitMax = function() return 5 end
	host.dailyFirst = function() return false end
	host.raceStats = function(p) return { Races = p.races } end
	host.prepare = function() return { rewards = { wins = 100, rewarded = true }, before = { Races = 0 } } end
	host.pay = function(p, outcome, _, done)
		RW.paid[p] = RW.paid[p] or {}
		table.insert(RW.paid[p], outcome)
		done({ ok = true, wins = 100, speed = 10, tickets = 0 })
	end
	host.submitPb = function() end
	host.funnel = { Step = function() return true end, NewSession = function() return "s" end, Event = function() return true end }
	local judge = RaceChargeJudge.new({ now = host.now, fire = host.fire, funnel = host.funnel, onJudged = function() end })
	host.judge = judge
	local service = RaceService.new(host)
	local function advance(seconds)
		local stop = RW.now + seconds
		while RW.now < stop - 1e-9 do
			RW.now += 0.05
			service:Tick(RW.now)
		end
	end
	local function untilPhase(phase)
		local stop = RW.now + 200
		while service.phase ~= phase and RW.now < stop do
			advance(0.05)
		end
		assert(service.phase == phase, "race phase " .. phase .. " (at " .. tostring(service.phase) .. ")")
	end
	local function events(p, kind)
		local list = {}
		for _, e in p.events do
			if e.kind == kind then
				table.insert(list, e)
			end
		end
		return list
	end
	-- A heat running (two racers) with a Gate joiner waiting in the arena and a HUD joiner queued on a stage.
	local r1, r2 = racePlayer(1), racePlayer(2)
	assert(service:Join(r1, "Hud") and service:Join(r2, "Hud"), "two join")
	untilPhase("Running")
	local race = service.race
	local waiter = racePlayer(3)
	assert(service:Join(waiter, "Gate"), "a Gate joiner waits in the arena for the next heat")
	local staged = racePlayer(4)
	staged.char.pos = ORIGIN + Vector3.new(900, 3, 0) -- queued from the HUD while on a stage
	assert(service:Join(staged, "Hud"), "a HUD joiner queued on a stage")
	assert(service:IsRacing(r1) and service:IsRacing(waiter) and not service:IsRacing(staged), "in the arena: the racers and the waiter")
	local streakBefore = service.entries[r1].dnfStreak
	-- The event starts: Close.
	local pulled, movedHome = service:Close("SuperSonicEvent")
	assert(#pulled == 4 and #movedHome == 3, "pulled all four, the three in the arena sent home (" .. #pulled .. ", " .. #movedHome .. ")")
	assert(RW.attrs.RaceClosedBy == "SuperSonicEvent" and service:IsClosed(), "RaceClosedBy = SuperSonicEvent")
	assert(service.phase == "Idle" and RW.attrs.RacePhase == "Idle" and service.race == nil and #service.queue == 0 and RW.attrs.RaceQueueCount == 0,
		"the cycle called off: Idle, no race, no queue")
	assert(next(service.entries) == nil, "nobody left in the race service")
	for _, racer in race.racers do
		assert(racer.done and racer.aborted and racer.outcome == "Aborted" and racer.outcome ~= "DNF", "a racer: Aborted, never a DNF")
	end
	for _, p in { r1, r2, waiter } do
		assert(p.char.pos == SPAWN and table.find(p.log, "spawn"), p.Name .. ": sent to the lobby spawn")
	end
	assert(staged.char.pos == ORIGIN + Vector3.new(900, 3, 0), "the one queued on a stage stays where they are")
	for _, p in { r1, r2, waiter, staged } do
		local unq = events(p, "Unqueued")
		assert(#unq >= 1 and unq[#unq].reason == "Event", p.Name .. ": { Unqueued, Event }")
		assert(p.attrs.RaceActive == false and p.attrs.RaceState == "" and p.attrs.RaceMovementLocked == false, p.Name .. ": race attributes cleared")
		assert(#events(p, "Results") == 0 and RW.paid[p] == nil, p.Name .. ": no results, nothing paid for the aborted race")
		assert(service.lastLeave[p] == nil, p.Name .. ": no rejoin cooldown")
		assert(p.attrs.RaceAutoRequeue ~= false, p.Name .. ": auto-requeue untouched (no idle-DNF strike)")
	end
	assert(streakBefore == 0, "(no streak before)")
	assert(RW.gate == true, "the start collider closed (at rest)")
	-- Closed: every Join refused with the event's toast; a Mega Race does not gather; no race invites.
	local okJ, whyJ = service:Join(r1, "Hud")
	assert(okJ == false and whyJ == "RaceEventClosed" and events(r1, "Toast")[#events(r1, "Toast")].key == "RaceEventClosed", "Join: { Toast, RaceEventClosed }")
	assert(service:Join(waiter, "Gate") == false and service:Join(staged, "Npc", "Open") == false and service:RaceAgain(r2) == false, "the Gate, the NPC, RACE AGAIN too")
	service:StartMegaEvent(600, "Admin")
	advance(1)
	assert(service.phase == "Idle" and #events(staged, "Invite") == 0, "a Mega Race waits: no gathering, no invites while closed")
	-- Reopened by the event's end: Join works at once.
	assert(service:Reopen("SomethingElse") == false and service:IsClosed(), "another closure's reopen does nothing")
	assert(service:Reopen("SuperSonicEvent") == true and RW.attrs.RaceClosedBy == nil and not service:IsClosed(), "Reopen")
	assert(service.phase == "Gathering", "the Mega Race still on its clock gathers again")
	assert(service:Join(r1, "Hud") == true, "joining works again at once (no cooldown)")
	service:StopMegaEvent()
	-- Closed while the results are out: their payments stand (sent at the results), nothing twice.
	local rs = RaceService.new(host)
	service = rs
	RW.paid = {}
	local s1, s2 = racePlayer(21), racePlayer(22)
	s1.char.pos, s2.char.pos = ORIGIN, ORIGIN
	assert(rs:Join(s1, "Hud") and rs:Join(s2, "Hud"), "a new heat")
	untilPhase("Running")
	-- (the heat times out: everyone DNF, results out, payments sent)
	untilPhase("Results")
	local paidBefore = #(RW.paid[s1] or {})
	assert(paidBefore == 1, "paid at the results")
	rs:Close("SuperSonicEvent")
	assert(#(RW.paid[s1] or {}) == paidBefore and rs.phase == "Idle", "a closure in the results keeps their payment, no second one")
	rs:Reopen()
	assert(not rs:IsClosed(), "Reopen() with no reason opens any closure")
	-- The Roblox glue: RaceServer exposes Close / Reopen / IsClosed, and a race loop starting mid-event reads the attribute.
	local raceServer = fs.readFile("src/common/ServerScriptService/Gameplay/RaceServer.server.luau")
	has(raceServer, "Close = function(reason)\n\t\treturn service:Close(reason)", "_G.SpeedsterRace.Close")
	has(raceServer, "Reopen = function(reason)\n\t\treturn service:Reopen(reason)", "_G.SpeedsterRace.Reopen")
	has(raceServer, "local closedBy = Workspace:GetAttribute(RaceService.ClosedAttribute)", "a race server starting mid-event stays closed")
	local raceSource = fs.readFile("src/common/ServerScriptService/Services/Race/RaceService.luau")
	has(raceSource, "refusal = RaceService.ClosedRefusal", "Join refuses while closed")
	has(raceSource, "if self.closedBy ~= nil then\n\t\treturn -- 2026-09-26 (owner): no race invites", "no race invites while closed")
	pass("races vs the event: RaceService.Close calls off a running heat (Aborted, never DNF: no results, no payment, no streak, no cooldown), sends the arena's racers and waiters to the lobby spawn (not the stage-queued one), Unqueued { Event }, RaceClosedBy; Join / Gate / NPC / RACE AGAIN refused (RaceEventClosed), a Mega Race waits; Reopen (only its own closure) clears it, Join works at once, the Mega gathers; a closure in the results keeps their payments; RaceServer's _G.SpeedsterRace.Close / Reopen")
end

----------------------------------------------------------------------
-- 3j. 2026-09-26 (owner): v3. The freeze windows on the server: no throws, falls put back, deaths forgiven
----------------------------------------------------------------------
do
	local world = newWorld()
	local core = world.core
	local a = world.add(1, Vector3.new(0, 3, 0))
	local b = world.add(2, Vector3.new(5, 3, 0))
	core:Start()
	world.run(T0 + 2)
	-- The Cinematic: a bomb (had one landed) throws nobody.
	core:_blast({ id = 1, to = a.pos + Vector3.new(0, -3, 0), battle = false }, world.T)
	assert(#world.ragdolls == 0 and core.stats.frozenBlasts == 1, "frozen: a blast throws nobody")
	-- A participant who drops off the lobby while frozen is put back (no throw needed).
	b.pos = ORIGIN + Vector3.new(40, -(SSE.Bombard.RescueDrop + 5), 0)
	world.run(world.T + 0.3)
	assert(#world.rescues == 1 and world.rescues[1] == b and core.stats.frozenFalls == 1, "frozen: a fall is put back")
	nearV(b.pos, ORIGIN + Vector3.new(0, 4, 0), 1e-3, "at the centre")
	-- Outside a window (the Bombard) a plain fall is the player's own (no throw: not put back).
	world.run(BOMBARD + SSE.Freeze.FallGraceSeconds + 2)
	world.core.launches, world.core.bombs, world.core.salvosFired = {}, {}, 99
	core.participants[a].knockedAt = -math.huge -- (not thrown by the Bombard's bombs)
	local rescuesBefore = #world.rescues
	a.pos = ORIGIN + Vector3.new(30, -(SSE.Bombard.RescueDrop + 5), 0)
	world.run(world.T + 0.3)
	assert(#world.rescues == rescuesBefore, "not frozen, not thrown: not put back")
	a.pos = ORIGIN + Vector3.new(0, 3, 0)
	-- The Defeat's crash: a bomb still falling when he broke lands and throws nobody.
	world.run(BATTLE + 0.1)
	world.quiet()
	core.hp = 1
	local guard = 0
	while world.worldAttrs.SSE_Phase == "Battle" do
		guard += 1
		assert(guard < 6000, "defeated")
		if SSE.BossState(world.T - BATTLE, SEED) == "Reload" then
			core:RequestHoming(a, world.T)
		end
		world.run(world.T + 0.05)
	end
	local defeatAt = world.worldAttrs.SSE_PhaseStart
	local ragBefore = #world.ragdolls
	table.insert(core.bombs, { id = 777, from = ORIGIN + Vector3.new(0, 60, 0), to = a.pos + Vector3.new(0, -3, 0), launch = defeatAt - 0.5,
		flight = 1.5, impact = defeatAt + 1, pattern = "Aimed", battle = true })
	world.run(defeatAt + 1.2)
	assert(#world.ragdolls == ragBefore and #world.messages("BombHit") > 0, "the crash's freeze: the bomb bursts, nobody is thrown")
	-- A death inside the crash's freeze costs no Super form: Super again on respawn (the Defeat has no late transform).
	assert(a.attrs.SSE_Super == true, "Super in the Defeat")
	a.alive = false
	core:CharacterReset(a)
	assert(a.attrs.SSE_Super == nil and core.stats.frozenDeaths == 1, "died while frozen")
	world.run(world.T + 0.3)
	a.alive = true
	a.pos = ORIGIN + Vector3.new(2, 3, 0)
	core:CharacterReset(a)
	world.run(world.T + 0.3)
	assert(a.attrs.SSE_Super == true, "respawned in the event: Super again")
	-- After the window (+ grace) a death is the player's: no Super again in the Defeat.
	world.run(defeatAt + SSE.FreezeWindows.Defeat.End + SSE.Freeze.FallGraceSeconds + 1)
	b.alive = false
	core:CharacterReset(b)
	world.run(world.T + 0.3)
	b.alive = true
	b.pos = ORIGIN + Vector3.new(4, 3, 0)
	core:CharacterReset(b)
	world.run(world.T + 0.3)
	assert(b.attrs.SSE_Super == nil and core.stats.frozenDeaths == 1, "a death after the window: not forgiven")
	core:Stop("admin")
	pass("freeze on the server: frozen blasts throw nobody (the Cinematic, a bomb landing in the crash), a frozen fall is put back at the centre (a plain one is not), a death while frozen costs no Super form (after the window it does)")
end

----------------------------------------------------------------------
-- 3k. 2026-09-26 (owner): v3. HP 0 always defeats him (the owner's playtest: "he always escapes when low on HP")
----------------------------------------------------------------------
do
	local battleEnd = BATTLE + D.Battle
	-- An attack still flying at the timeout lands after it: the Escape waits, the hit breaks him: the Defeat.
	local world = newWorld()
	local core = world.core
	local a = world.add(1, UNDER)
	core:Start()
	world.run(battleEnd - 0.3)
	world.quiet()
	assert(world.worldAttrs.SSE_Phase == "Battle", "the Battle's last moments")
	core.hp = 1
	local p = core.participants[a]
	p.flight = { arriveAt = battleEnd + 0.4, from = a.pos, to = SSE.BossPosition(ORIGIN, battleEnd + 0.4, core.plan), charge = 0, damage = 1, shielded = false }
	world.run(battleEnd + 0.2)
	assert(world.worldAttrs.SSE_Phase == "Battle", "the timeout waits for the attack in flight")
	world.run(battleEnd + 1)
	assert(world.worldAttrs.SSE_Phase == "Defeat" and #world.messages("Escape") == 0, "the hit broke him: Defeat, never the Escape")
	assert(#world.messages("Rings") == 1 and world.worldAttrs.SSE_CrashPoint ~= nil, "the rings and the crash")
	assert(world.worldAttrs.SSE_PhaseStart == battleEnd + 0.4, "the Defeat at the hit's arrival")
	core:Stop("admin")
	-- A hit arriving in the very step the timeout is due: the hit lands first.
	world = newWorld()
	core = world.core
	a = world.add(1, UNDER)
	core:Start()
	world.run(battleEnd - 0.05)
	world.quiet()
	core.hp = 2
	core.participants[a].flight = { arriveAt = battleEnd - 0.01, from = a.pos, to = SSE.BossPosition(ORIGIN, battleEnd, core.plan), charge = 0.5,
		damage = 2, shielded = false }
	world.T = battleEnd + 0.25 -- the clock jumps past both
	core:Step()
	assert(world.worldAttrs.SSE_Phase == "Defeat" and #world.messages("Escape") == 0, "same step: the Defeat wins")
	core:Stop("admin")
	-- The Escape waits at most Homing.MaxFlightSeconds.
	world = newWorld()
	core = world.core
	a = world.add(1, UNDER)
	core:Start()
	world.run(battleEnd - 0.1)
	world.quiet()
	core.hp = 5
	core.participants[a].flight = { arriveAt = battleEnd + 10, from = a.pos, to = a.pos, charge = 0, damage = 1, shielded = false }
	world.run(battleEnd + SSE.Homing.MaxFlightSeconds + 0.1)
	assert(world.worldAttrs.SSE_Phase == "Escape", "the Escape after MaxFlightSeconds at most")
	near(world.worldAttrs.SSE_PhaseStart, battleEnd + SSE.Homing.MaxFlightSeconds, 0.06, "at the cap")
	core:Stop("admin")
	-- Attacks flying when the ship breaks still land and pay (a hit on the wreck: the bar stays at 0).
	world = newWorld()
	core = world.core
	a = world.add(1, UNDER)
	local b = world.add(2, UNDER + Vector3.new(2, 0, 0))
	core:Start()
	world.run(BATTLE + 0.1)
	world.quiet()
	local function reloadNow()
		local state, _, f = SSE.BossState(world.T - BATTLE, SEED)
		return state == "Reload" and world.T - BATTLE + 0.4 < f
	end
	while not reloadNow() do
		world.run(world.T + 0.05)
	end
	core.hp = 1
	assert(core:RequestHoming(a, world.T) == true, "a's attack")
	world.run(world.T + 0.02, 0.01)
	local okB = core:RequestHoming(b, world.T)
	assert(okB == true, "b's attack right after")
	world.run(world.T + 1, 0.01)
	assert(world.worldAttrs.SSE_Phase == "Defeat" and core.hp == 0, "a's hit broke him")
	local rewardsB = world.toOne(b, "Reward")
	assert(#rewardsB == 1 and b.attrs.SSE_Hits == 1, "b's attack, flying at the defeat, still landed and paid")
	core:Stop("admin")
	-- The measured table (seed 12345, the Battle's bombs on; attacks only when the arrival falls in a Reload window).
	local function fight(n, charged)
		local w = newWorld()
		local list = {}
		for i = 1, n do
			table.insert(list, w.add(i, UNDER + Vector3.new(i * 2, 0, 0)))
		end
		local c = w.core
		c:Start()
		local pressed = {}
		while c.running and c.phase ~= "Defeat" and c.phase ~= "Escape" do
			w.T += 0.05
			c:Step()
			if c.phase == "Battle" then
				local state, _, f = SSE.BossState(w.T + 0.25 - BATTLE, SEED)
				local reload = state == "Reload" and w.T + 0.25 - BATTLE < f
				for _, pl in list do
					if charged then
						if not pressed[pl] then
							c:Charge(pl, w.T)
							pressed[pl] = w.T
						elseif w.T - pressed[pl] >= SSE.Homing.ChargeSeconds and reload then
							c:RequestHoming(pl, w.T)
							pressed[pl] = nil
						end
					elseif reload then
						c:RequestHoming(pl, w.T) -- the jump attack: no charge
					end
				end
			end
		end
		local phase, seconds = c.phase, w.T - BATTLE
		c:Stop("admin")
		return phase, seconds, c.maxHp
	end
	local rows = {}
	for _, n in { 1, 4, 8 } do
		local phase, seconds, maxHp = fight(n, false)
		assert(phase == "Defeat" and seconds < 125, n .. " player(s) jumping at him without charging break him (" .. phase .. ", " .. string.format("%.1f", seconds) .. " s)")
		table.insert(rows, string.format("%d: HP %d, uncharged %.0f s", n, maxHp, seconds))
	end
	local phase, seconds = fight(1, true)
	assert(phase == "Defeat" and seconds < 70, "charged play breaks him much sooner (" .. string.format("%.1f", seconds) .. " s)")
	table.insert(rows, string.format("1 charged: %.0f s", seconds))
	pass("HP 0 always wins: an attack flying at the timeout lands after it and defeats him (never the Escape), a hit due in the timeout's step wins, the Escape waits at most " .. SSE.Homing.MaxFlightSeconds .. " s, attacks flying at the defeat still land and pay; measured (bombs on): " .. table.concat(rows, "; "))
end

----------------------------------------------------------------------
-- 4. The Roblox glue
----------------------------------------------------------------------
do
	local service = fs.readFile("src/common/ServerScriptService/Gameplay/SuperSonicEventService.server.luau")
	has(service, 'local Remotes = ReplicatedStorage:WaitForChild("Remotes")', "the remote lives in ReplicatedStorage.Remotes")
	has(service, "local Remote = remote(SSE.RemoteName)", "the SuperSonicEvent remote")
	has(service, "Remote.OnServerEvent:Connect(function(player: Player, first: any, second: any, third: any)", "one handler for Charge / Homing / RingTake")
	has(service, "pcall(core.ClientMessage, core, player, first, second, third)", "rate-limited by the core")
	has(service, "if core.running or core:HasRings() then", "the clock runs while the rings are out")
	has(service, "core:PlayerJoined(player)", "late joiners get the rings")
	has(service, 'event:Fire("Ragdoll", seconds)', "the game's live ragdoll (R6DeathRagdoll's RagdollEvent)")
	has(service, "root.AssemblyLinearVelocity = velocity", "the throw")
	has(service, "G[SSE.ApiName] = {", "_G.SpeedsterSuperSonicEvent")
	has(service, "beforeRelease.SuperSonicEvent = function(player: Player)", "the before-release save")
	has(service, "Workspace:GetAttributeChangedSignal(SSE.KillAttribute)", "the kill switch stops it live")
	has(service, "RaceNoFlight.Check(player, position)", "racing = the race's own rule")
	has(service, 'player:GetAttribute("AfkModeActive") == true', "AFK Mode players are left alone")
	has(service, "humanoid.JumpPower = SSE.Super.JumpPower", "JumpPower 90")
	has(service, "player:SetAttribute(SSE.PlayerAttributes.WalkSpeed, SSE.Super.WalkSpeed)", "the walk speed floor")
	has(service, "pcall(skins.Apply, player, SSE.Super.SkinId, SSE.Super.SkinReason)", "the real Super Sonic skin")
	has(service, "pcall(skins.Restore, player, SSE.Super.SkinReason)", "the player's own skin back")
	has(service, "player:SetAttribute(name, if on then SSE.Super.SkinReason else nil)", "EventFlightBlocked")
	has(service, "local function lobbyEggmanHull(): Vector3?", "the lift-off point")
	has(service, "local function putSuperSkin(player: Player, retries: number): boolean", "the skin retried while the skin system is busy")
	has(service, 'if ok and why == "busy" and retries > 0 then', "only when busy")
	has(service, "core:ClearRings() -- 2026-09-26 (owner): the defeat's rings too", "the kill switch clears the rings")
	has(service, 'kind = "GrantExact", stat = "Wins"', "Wins through DataService.Commit")
	has(service, 'kind = "GrantExact", stat = "Speed"', "Speed through DataService.Commit")
	has(service, "general:DisplaySystemMessage(", "a system chat line")
	-- 2026-09-26 (owner): v3
	has(service, "arenaOrigin = function()", "the fight's centre on the race arena")
	has(service, "local point = SSE.ArenaOrigin(SSE.WorldKey(Config))", "ArenaOrigin, dropped on the floor")
	has(service, "arenaGates = function(open)", "the arena's gates")
	has(service, 'for _, name in { "StartGate", "StopBar" } do', "StartGate / StopBar")
	has(service, "local ok, pulled = pcall(race.Close, reason)", "_G.SpeedsterRace.Close")
	has(service, "pcall(race.Reopen, reason)", "_G.SpeedsterRace.Reopen")
	has(service, "Workspace:SetAttribute(SSE.RaceClosed.Attribute, reason)", "no race server: the attribute alone")
	has(service, "player:RequestStreamAroundAsync(position, SSE.Teleport.StreamSeconds)", "a trip streams the spot in first")
	has(service, "pcall(stages.TeleportToNormalSpawn, player)", "a trip home is the world's own spawn trip")
	has(service, "pcall(stages.ArmArrivalGrace, player)", "a trip to the arena arms the arrival grace")
	has(service, "pcall(rebase, player, progress)", "and rebases MovementGuard at the player's own progress")
	has(service, "push = function(player, velocity)", "the shield's bounce")
	has(service, "params.RespectCanCollide = true", "floor raycasts skip non-colliding decor")
	for _, forbidden in { "Health = 0", ":TakeDamage(", ":BreakJoints(", "Humanoid.Health -", 'SetAttribute("EquippedSkin"' } do
		assert(not string.find(service, forbidden, 1, true), "never (" .. forbidden .. ")")
	end
	assert(luau.compile(service), "the service compiles")
	local movement = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/Movement/InstantMovementController.client.luau")
	has(movement, 'local superWalkSpeed = tonumber(player:GetAttribute("SSE_WalkSpeed"))', "the movement controller reads SSE_WalkSpeed")
	pass("glue: one rate-limited handler (Charge / Homing / RingTake), the clock while rings are out, RagdollEvent throw, _G API, before-release save, kill switch, skin override Apply / Restore, EventFlightBlocked, lift-off, grants, chat, no kill, no EquippedSkin write")
end

-- 4b. The real service script in a small fake Roblox.
do
	local T = 3000
	local function signal()
		local s = { handlers = {} }
		function s:Connect(fn)
			table.insert(self.handlers, fn)
			return { Disconnect = function() end }
		end
		function s:Fire(...)
			for _, handler in table.clone(self.handlers) do
				handler(...)
			end
		end
		return s
	end
	local function node(className, name, props)
		local o = { ClassName = className, Name = name, children = {}, attrs = {}, attrSignals = {} }
		for k, v in props or {} do
			o[k] = v
		end
		function o:FindFirstChild(n)
			for _, child in self.children do
				if child.Name == n then
					return child
				end
			end
			return nil
		end
		function o:WaitForChild(n)
			return (assert(self:FindFirstChild(n), "fake WaitForChild: " .. tostring(n)))
		end
		function o:IsA(c)
			return self.ClassName == c or (c == "BasePart" and (self.ClassName == "Part" or self.ClassName == "SpawnLocation"))
		end
		function o:FindFirstChildOfClass(c)
			for _, child in self.children do
				if child.ClassName == c then
					return child
				end
			end
			return nil
		end
		function o:GetAttribute(n)
			return self.attrs[n]
		end
		function o:SetAttribute(n, v)
			self.attrs[n] = v
			if self.attrSignals[n] then
				self.attrSignals[n]:Fire()
			end
		end
		function o:GetAttributeChangedSignal(n)
			self.attrSignals[n] = self.attrSignals[n] or signal()
			return self.attrSignals[n]
		end
		function o:GetDescendants()
			local out = {}
			local function walk(x)
				for _, child in x.children do
					table.insert(out, child)
					walk(child)
				end
			end
			walk(self)
			return out
		end
		function o:add(child)
			table.insert(self.children, child)
			child.Parent = self
			return child
		end
		return o
	end
	local marker = function(name)
		return node("ModuleScript", name)
	end

	local workspace = node("Workspace", "Workspace")
	local spawnTop = ORIGIN
	workspace:add(node("SpawnLocation", "SpawnLocation", { Enabled = true, Position = spawnTop - Vector3.new(0, 0.5, 0), Size = Vector3.new(12, 1, 12) }))
	-- The lobby's Eggman in his Egg Mobile (the build's LobbyCharacters folder).
	local lobbyChars = workspace:add(node("Folder", "LobbyCharacters"))
	local eggman = lobbyChars:add(node("Model", "Eggman"))
	local ship = eggman:add(node("Model", "EggMobile"))
	ship:add(node("Part", "EggHull", { Position = LIFT }))
	function workspace:GetServerTimeNow()
		return T
	end
	function workspace:Raycast(origin, _direction, _params)
		return { Position = Vector3.new(origin.X, ORIGIN.Y, origin.Z), Normal = Vector3.new(0, 1, 0) }
	end
	local players = node("Players", "Players", { PlayerAdded = signal(), PlayerRemoving = signal() })
	local playerList = {}
	function players:GetPlayers()
		return table.clone(playerList)
	end
	local replicated = node("ReplicatedStorage", "ReplicatedStorage")
	local shared = replicated:add(node("Folder", "Shared"))
	local sseModule = shared:add(marker("SuperSonicEvent"))
	local configModule = shared:add(marker("Config"))
	local raceModule = shared:add(marker("RaceNoFlight"))
	local remotes = replicated:add(node("Folder", "Remotes"))
	local sent = { all = {}, one = {} }
	local remoteEvent = remotes:add(node("RemoteEvent", "SuperSonicEvent", { OnServerEvent = signal() }))
	function remoteEvent:FireAllClients(message)
		table.insert(sent.all, message)
	end
	function remoteEvent:FireClient(player, message)
		table.insert(sent.one, { player = player, message = message })
	end
	local sss = node("ServerScriptService", "ServerScriptService")
	local services = sss:add(node("Folder", "Services"))
	local dataFolder = services:add(node("Folder", "Data"))
	local dataModule = dataFolder:add(marker("DataService"))
	local gameplay = sss:add(node("Folder", "Gameplay"))
	local coreModule = gameplay:add(marker("SuperSonicEventCore"))
	local chatLines = {}
	local textChat = node("TextChatService", "TextChatService")
	local channels = textChat:add(node("Folder", "TextChannels"))
	local general = channels:add(node("TextChannel", "RBXGeneral"))
	function general:DisplaySystemMessage(text)
		table.insert(chatLines, text)
	end
	local heartbeat = signal()
	local serviceByName = {
		Players = players, ReplicatedStorage = replicated, RunService = { Heartbeat = heartbeat },
		ServerScriptService = sss, TextChatService = textChat, HttpService = { GenerateGUID = function() return "guid" end },
		Workspace = workspace,
	}
	local game = { JobId = "job-harness" }
	function game:GetService(name)
		return (assert(serviceByName[name], "fake service " .. name))
	end

	local commits = {}
	local DataServiceFake = {
		GetHandle = function(userId)
			return { userId = userId }
		end,
		Commit = function(handle, request)
			table.insert(commits, { userId = handle.userId, request = request })
			return { kind = "Committed" }
		end,
	}
	local RaceNoFlight = require("../src/common/ReplicatedStorage/Shared/RaceNoFlight")
	local modules = {
		[sseModule] = SSE, [configModule] = { IsNewWorld1Map = true }, [raceModule] = RaceNoFlight,
		[dataModule] = DataServiceFake, [coreModule] = Core,
	}

	local function newPlayer(userId, offset)
		local player = node("Player", "P" .. userId, { UserId = userId, DisplayName = "P" .. userId, CharacterAdded = signal() })
		player.Parent = players
		local character = node("Model", "P" .. userId)
		local humanoid = character:add(node("Humanoid", "Humanoid", { Health = 100, FloorMaterial = "Plastic", UseJumpPower = false,
			JumpPower = 50, JumpHeight = 7.2, WalkSpeed = 40, Died = signal() }))
		local position = spawnTop + offset
		local root = character:add(node("Part", "HumanoidRootPart", { Position = position, CFrame = CFrame.new(position),
			AssemblyLinearVelocity = Vector3.zero, AssemblyAngularVelocity = Vector3.zero }))
		local ragdolls = {}
		local ragdollEvent = character:add(node("BindableEvent", "RagdollEvent"))
		function ragdollEvent:Fire(action, seconds)
			table.insert(ragdolls, { action = action, seconds = seconds })
		end
		function character:PivotTo(cf)
			root.CFrame = cf
			root.Position = cf.Position
		end
		player.Character = character
		table.insert(playerList, player)
		return player, humanoid, root, ragdolls
	end
	local a, aHumanoid, aRoot, aRagdolls = newPlayer(11, Vector3.new(0, 3, 0))
	local b, _, _, bRagdolls = newPlayer(12, Vector3.new(3, 3, 2))

	-- The skin system's and FlightService's hooks.
	local skinCalls = {}
	local refreshed = {}
	local G = {
		SpeedsterSkinOverride = {
			Apply = function(player, skinId, reason)
				table.insert(skinCalls, { "Apply", player, skinId, reason })
				return true
			end,
			Restore = function(player, reason)
				table.insert(skinCalls, { "Restore", player, reason })
				return true, "restored"
			end,
		},
		SpeedsterRefreshRaceNoFlight = function(player)
			refreshed[player] = (refreshed[player] or 0) + 1
		end,
	}
	local env = setmetatable({
		game = game,
		script = { Parent = gameplay },
		require = function(module)
			return (assert(modules[module], "fake require: " .. tostring(module and module.Name)))
		end,
		Instance = { new = function(className)
			return node(className, className)
		end },
		Enum = { Material = { Air = "Air" }, RaycastFilterType = { Exclude = "Exclude" } },
		RaycastParams = { new = function()
			return {}
		end },
		Vector3 = Vector3,
		CFrame = CFrame,
		task = { spawn = function(fn, ...)
			fn(...)
		end, wait = function() end, delay = function() end },
		print = function() end,
		warn = function() end,
		_G = G,
	}, { __index = _G })
	local serviceSource = fs.readFile("src/common/ServerScriptService/Gameplay/SuperSonicEventService.server.luau")
	luau.load(serviceSource, { environment = env })()

	local api = G.SpeedsterSuperSonicEvent
	assert(type(api) == "table" and type(api.Start) == "function" and type(api.Stop) == "function", "_G.SpeedsterSuperSonicEvent")
	assert(type(G.SpeedsterBeforeRelease) == "table" and type(G.SpeedsterBeforeRelease.SuperSonicEvent) == "function", "before-release hook")
	assert(workspace.attrs.SSE_Phase == "", "a clean slate at start")
	assert(api.IsRunning() == false and api.IsAvailable() == true, "idle and available")

	assert(api.Start("Harness") == true and workspace.attrs.SSE_Phase == "Cinematic", "started through the _G API")
	nearV(workspace.attrs.SSE_Origin, spawnTop, 0.01, "SSE_Origin = the lobby spawn's top")
	assert(workspace.attrs.SSE_LiftOff == LIFT, "SSE_LiftOff = the lobby Eggman's Egg Mobile hull")
	nearV(workspace.attrs.SSE_LobbyOrigin, spawnTop, 0.01, "v3: SSE_LobbyOrigin (no RaceArena here: the fight stays in the lobby)")
	assert(workspace.attrs.RaceClosedBy == "SuperSonicEvent", "v3: no race server: the races closed by the attribute alone")
	assert(a.attrs.EventFlightBlocked == "SuperSonicEvent" and b.attrs.EventFlightBlocked == "SuperSonicEvent", "no Flight during the event")
	assert(refreshed[a] and refreshed[a] >= 1, "FlightService re-checks at once (_G.SpeedsterRefreshRaceNoFlight)")
	assert(string.find(chatLines[1] or "", SSE.Announcements.Start, 1, true), "the start in the chat")
	local function stepTo(untilT)
		while T < untilT do
			T = math.min(untilT, T + 0.05)
			heartbeat:Fire(0.05)
		end
	end
	local battle = 3000 + D.Cinematic + D.Teleport + D.Bombard + D.Emeralds
	stepTo(battle - D.Emeralds - 0.1)
	assert(#aRagdolls + #bRagdolls > 0, "bombs threw the players through their RagdollEvent")
	for _, entry in aRagdolls do
		assert(entry.action == "Ragdoll" and entry.seconds == 2, "RagdollEvent:Fire(\"Ragdoll\", 2)")
	end
	assert(aHumanoid.Health == 100, "never a kill")
	stepTo(battle + 0.1)
	assert(workspace.attrs.SSE_Phase == "Battle", "Battle")
	assert(a.attrs.SSE_Super == true and a.attrs.SSE_WalkSpeed == 120 and a.attrs.SSE_Skin == "SuperSonicSuit", "Super: SSE_Super, the walk speed floor, SSE_Skin")
	assert(aHumanoid.UseJumpPower == true and aHumanoid.JumpPower == 90 and aHumanoid.WalkSpeed == 120, "JumpPower 90 on the Humanoid")
	local applied = 0
	for _, call in skinCalls do
		if call[1] == "Apply" then
			applied += 1
			assert(call[3] == "SuperSonicSuit" and call[4] == "SuperSonicEvent", "Apply(player, SuperSonicSuit, SuperSonicEvent)")
		end
	end
	assert(applied == 2, "the skin put on both players")
	assert(a.attrs.EquippedSkin == nil, "EquippedSkin never written")

	-- A charged homing attack through the remote in the first Reload window (past any bomb's stun).
	stepTo(battle + 6.5)
	aRoot.Position = ORIGIN + UNDER
	remoteEvent.OnServerEvent:Fire(a, { "Charge", T })
	stepTo(T + SSE.Homing.ChargeSeconds / 2)
	remoteEvent.OnServerEvent:Fire(a, { "Homing", T })
	local go = nil
	for _, message in sent.all do
		if message[1] == "HomingGo" then
			go = message
		end
	end
	assert(go and go[2] == 11 and go[8] == 2, "HomingGo for the attacker, a half charge = damage 2")
	stepTo(T + go[6] + 0.1)
	local hit = nil
	for _, message in sent.all do
		if message[1] == "Hit" then
			hit = message
		end
	end
	assert(hit and hit[2] == 11 and hit[6] == 2, "the hit landed (2 damage)")
	assert(#commits == 1 and commits[1].userId == 11, "committed")
	local commands = commits[1].request.commands
	assert(commands[1].kind == "GrantExact" and commands[1].stat == "Wins" and commands[1].amount == 600
		and commands[2].kind == "GrantExact" and commands[2].stat == "Speed" and commands[2].amount == 30000, "GrantExact Wins 600 + Speed 30000")
	assert(string.find(commits[1].request.operationId, "^sse:job%-harness:1:11:1$"), "operation id")
	stepTo(T + SSE.Homing.Cooldown + 0.1)
	local before = 0
	for _, message in sent.all do
		if message[1] == "HomingGo" then
			before += 1
		end
	end
	remoteEvent.OnServerEvent:Fire(a, "Homing", T)
	local after = 0
	for _, message in sent.all do
		if message[1] == "HomingGo" then
			after += 1
		end
	end
	assert(after == before + 1, "the vararg form is accepted too")
	remoteEvent.OnServerEvent:Fire(b, { "Bomb", 1 })
	remoteEvent.OnServerEvent:Fire(b, "junk")
	remoteEvent.OnServerEvent:Fire(b, { "RingTake", 1 })
	-- The kill switch attribute stops it at once and restores everything.
	local isOn = SSE.IsOn
	SSE.IsOn = function()
		return workspace.attrs[SSE.KillAttribute] ~= true
	end
	workspace:SetAttribute(SSE.KillAttribute, true)
	SSE.IsOn = isOn
	assert(api.IsRunning() == false and workspace.attrs.SSE_Phase == "", "kill switch: stopped")
	assert(a.attrs.SSE_Super == nil and a.attrs.SSE_WalkSpeed == nil and a.attrs.SSE_Skin == nil, "attributes cleared")
	assert(aHumanoid.UseJumpPower == false and aHumanoid.JumpPower == 50 and aHumanoid.JumpHeight == 7.2, "the jump restored")
	local restores = 0
	for _, call in skinCalls do
		if call[1] == "Restore" then
			restores += 1
			assert(call[3] == "SuperSonicEvent", "Restore(player, SuperSonicEvent)")
		end
	end
	assert(restores == 2, "the own skin back for both")
	assert(a.attrs.EventFlightBlocked == nil and b.attrs.EventFlightBlocked == nil, "Flight back")
	assert(workspace.attrs.RaceClosedBy == nil and workspace.attrs.SSE_LobbyOrigin == nil, "v3: the races open, the attributes cleared")
	pass("service in a fake Roblox: _G Start, SSE_LiftOff from LobbyCharacters.Eggman, EventFlightBlocked + the refresh, RagdollEvent throws, Super (JumpPower 90, SSE_WalkSpeed 120, the real skin via SpeedsterSkinOverride, SSE_Skin), Charge + Homing through the remote (2 dmg), GrantExact 600 / 30,000, kill switch restores all")
end

-- 4c. 2026-09-26 (owner): v3. The real service script with a race arena in the fake Roblox: the arena point on its
-- floor, the gates opened / restored, the races closed / reopened through _G.SpeedsterRace, the Teleport beat's
-- trips (streamed, the arrival grace, MovementGuard at the player's own progress), the trip home (the world's own
-- spawn trip) on an admin stop.
do
	local T = 5000
	local function signal()
		local s = { handlers = {} }
		function s:Connect(fn)
			table.insert(self.handlers, fn)
			return { Disconnect = function() end }
		end
		function s:Fire(...)
			for _, handler in table.clone(self.handlers) do
				handler(...)
			end
		end
		return s
	end
	local function node(className, name, props)
		local o = { ClassName = className, Name = name, children = {}, attrs = {}, attrSignals = {} }
		for k, v in props or {} do
			o[k] = v
		end
		function o:FindFirstChild(n)
			for _, child in self.children do
				if child.Name == n then
					return child
				end
			end
			return nil
		end
		function o:WaitForChild(n)
			return (assert(self:FindFirstChild(n), "fake WaitForChild: " .. tostring(n)))
		end
		function o:IsA(c)
			return self.ClassName == c or (c == "BasePart" and (self.ClassName == "Part" or self.ClassName == "SpawnLocation"))
		end
		function o:FindFirstChildOfClass(c)
			for _, child in self.children do
				if child.ClassName == c then
					return child
				end
			end
			return nil
		end
		function o:GetAttribute(n)
			return self.attrs[n]
		end
		function o:SetAttribute(n, v)
			self.attrs[n] = v
			if self.attrSignals[n] then
				self.attrSignals[n]:Fire()
			end
		end
		function o:GetAttributeChangedSignal(n)
			self.attrSignals[n] = self.attrSignals[n] or signal()
			return self.attrSignals[n]
		end
		function o:GetDescendants()
			local out = {}
			local function walk(x)
				for _, child in x.children do
					table.insert(out, child)
					walk(child)
				end
			end
			walk(self)
			return out
		end
		function o:add(child)
			table.insert(self.children, child)
			child.Parent = self
			return child
		end
		return o
	end
	local marker = function(name)
		return node("ModuleScript", name)
	end
	local workspace = node("Workspace", "Workspace")
	local spawnTop = ORIGIN
	workspace:add(node("SpawnLocation", "SpawnLocation", { Enabled = true, Position = spawnTop - Vector3.new(0, 0.5, 0), Size = Vector3.new(12, 1, 12) }))
	local arena = workspace:add(node("Model", "RaceArena"))
	local structure = arena:add(node("Model", "Structure"))
	local startGate = structure:add(node("Part", "StartGate", { CanCollide = true }))
	local stopBar = structure:add(node("Part", "StopBar", { CanCollide = false }))
	function workspace:GetServerTimeNow()
		return T
	end
	local rays = {}
	function workspace:Raycast(origin, _direction, params)
		table.insert(rays, params)
		local y = if math.abs(origin.Y - ARENA.Y) < 2000 then ARENA.Y else ORIGIN.Y
		return { Position = Vector3.new(origin.X, y, origin.Z), Normal = Vector3.new(0, 1, 0) }
	end
	local players = node("Players", "Players", { PlayerAdded = signal(), PlayerRemoving = signal() })
	local playerList = {}
	function players:GetPlayers()
		return table.clone(playerList)
	end
	local replicated = node("ReplicatedStorage", "ReplicatedStorage")
	local shared = replicated:add(node("Folder", "Shared"))
	local sseModule = shared:add(marker("SuperSonicEvent"))
	local configModule = shared:add(marker("Config"))
	local raceModule = shared:add(marker("RaceNoFlight"))
	local remotes = replicated:add(node("Folder", "Remotes"))
	local sent = { all = {}, one = {} }
	local remoteEvent = remotes:add(node("RemoteEvent", "SuperSonicEvent", { OnServerEvent = signal() }))
	function remoteEvent:FireAllClients(message)
		table.insert(sent.all, message)
	end
	function remoteEvent:FireClient(player, message)
		table.insert(sent.one, { player = player, message = message })
	end
	local sss = node("ServerScriptService", "ServerScriptService")
	local services = sss:add(node("Folder", "Services"))
	local dataModule = services:add(node("Folder", "Data")):add(marker("DataService"))
	local stagesModule = services:add(marker("StageTeleportService"))
	local guardModule = services:add(marker("MovementGuard"))
	local gameplay = sss:add(node("Folder", "Gameplay"))
	local coreModule = gameplay:add(marker("SuperSonicEventCore"))
	local textChat = node("TextChatService", "TextChatService")
	local general = textChat:add(node("Folder", "TextChannels")):add(node("TextChannel", "RBXGeneral"))
	function general:DisplaySystemMessage() end
	local heartbeat = signal()
	local serviceByName = {
		Players = players, ReplicatedStorage = replicated, RunService = { Heartbeat = heartbeat },
		ServerScriptService = sss, TextChatService = textChat, HttpService = { GenerateGUID = function() return "guid" end },
		Workspace = workspace,
	}
	local game = { JobId = "job-arena" }
	function game:GetService(name)
		return (assert(serviceByName[name], "fake service " .. name))
	end
	-- The world's spawn trip and arrival grace, MovementGuard's progress.
	local spawnTrips, graces, rebases, streamed = {}, {}, {}, {}
	local StagesFake = {
		TeleportToNormalSpawn = function(player)
			table.insert(spawnTrips, player)
			player.Character:PivotTo(CFrame.new(spawnTop + Vector3.new(0, 3.5, 0)))
			return true
		end,
		ArmArrivalGrace = function(player)
			table.insert(graces, player)
		end,
	}
	local GuardFake = { GetProgress = function() return 7 end }
	local RaceNoFlight = require("../src/common/ReplicatedStorage/Shared/RaceNoFlight")
	local modules = {
		[sseModule] = SSE, [configModule] = { IsNewWorld1Map = true }, [raceModule] = RaceNoFlight,
		[dataModule] = { GetHandle = function() return nil end, Commit = function() return { kind = "NoSession" } end },
		[coreModule] = Core, [stagesModule] = StagesFake, [guardModule] = GuardFake,
	}
	local function newPlayer(userId, position)
		local player = node("Player", "P" .. userId, { UserId = userId, DisplayName = "P" .. userId, CharacterAdded = signal() })
		player.Parent = players
		local character = node("Model", "P" .. userId)
		character:add(node("Humanoid", "Humanoid", { Health = 100, FloorMaterial = "Plastic", UseJumpPower = false,
			JumpPower = 50, JumpHeight = 7.2, WalkSpeed = 40, Died = signal() }))
		local root = character:add(node("Part", "HumanoidRootPart", { Position = position, CFrame = CFrame.new(position),
			AssemblyLinearVelocity = Vector3.zero, AssemblyAngularVelocity = Vector3.zero }))
		function character:PivotTo(cf)
			root.CFrame = cf
			root.Position = cf.Position
		end
		function player:RequestStreamAroundAsync(pos)
			table.insert(streamed, { player = self, pos = pos })
		end
		player.Character = character
		table.insert(playerList, player)
		return player, root
	end
	local a, aRoot = newPlayer(31, spawnTop + Vector3.new(0, 3, 0))
	local b, bRoot = newPlayer(32, spawnTop + Vector3.new(4, 3, 2))
	local closes, reopens = {}, {}
	local G = {
		SpeedsterRace = {
			Close = function(reason)
				table.insert(closes, reason)
				return {}, {}
			end,
			Reopen = function(reason)
				table.insert(reopens, reason)
				return true
			end,
		},
		VortexMovementGuardRebase = function(player, progress)
			table.insert(rebases, { player = player, progress = progress })
		end,
	}
	local env = setmetatable({
		game = game,
		script = { Parent = gameplay },
		require = function(module)
			return (assert(modules[module], "fake require: " .. tostring(module and module.Name)))
		end,
		Instance = { new = function(className)
			return node(className, className)
		end },
		Enum = { Material = { Air = "Air" }, RaycastFilterType = { Exclude = "Exclude" } },
		RaycastParams = { new = function()
			return {}
		end },
		Vector3 = Vector3,
		CFrame = CFrame,
		task = { spawn = function(fn, ...)
			fn(...)
		end, wait = function() end, delay = function() end },
		print = function() end,
		warn = function() end,
		_G = G,
	}, { __index = _G })
	luau.load(fs.readFile("src/common/ServerScriptService/Gameplay/SuperSonicEventService.server.luau"), { environment = env })()
	local api = G.SpeedsterSuperSonicEvent
	local function stepTo(untilT)
		while T < untilT do
			T = math.min(untilT, T + 0.05)
			heartbeat:Fire(0.05)
		end
	end
	assert(api.Start("Harness") == true, "started")
	nearV(workspace.attrs.SSE_Origin, ARENA, 1e-3, "SSE_Origin: the arena point dropped on the RaceArena's floor")
	nearV(workspace.attrs.SSE_LobbyOrigin, spawnTop, 1e-3, "SSE_LobbyOrigin: the lobby spawn")
	assert(rays[1] and rays[1].RespectCanCollide == true, "the floor raycasts skip non-colliding decor")
	assert(closes[1] == "SuperSonicEvent", "_G.SpeedsterRace.Close(\"SuperSonicEvent\")")
	assert(startGate.CanCollide == false and stopBar.CanCollide == false, "the arena's StartGate / StopBar collide with nobody")
	assert(a.attrs.EventFlightBlocked == "SuperSonicEvent", "no Flight in the lobby's audience")
	stepTo(5000 + D.Cinematic + SSE.Beats.Teleport.MoveAt + 0.06)
	for _, entry in { { a, aRoot }, { b, bRoot } } do
		local root = entry[2]
		assert(SSE.InArena(root.Position, ARENA), entry[1].Name .. " moved into the arena")
		near(root.Position.Y, ARENA.Y + SSE.Teleport.Height, 1e-3, entry[1].Name .. " on the arena floor")
		-- (Lune's CFrame.lookAt differs from Roblox's: compare with the same call, toward the centre at the root's height)
		local expected = CFrame.lookAt(root.Position, Vector3.new(ARENA.X, root.Position.Y, ARENA.Z))
		nearV(root.CFrame.LookVector, expected.LookVector, 1e-3, entry[1].Name .. " facing the fight's centre (lookAt)")
	end
	assert(#streamed >= 2 and #graces >= 2 and #spawnTrips == 0, "streamed in first, the arrival grace armed, no spawn trip into the arena")
	assert(rebases[1] and rebases[1].progress == 7, "MovementGuard rebased at the player's own progress")
	stepTo(T + 0.3)
	assert(a.attrs.EventFlightBlocked == "SuperSonicEvent", "no Flight in the arena either")
	-- An admin stop mid-fight: the arena goes home (the world's own spawn trip, then the free spot), all restored.
	stepTo(5000 + SSE.PhaseOffset("Battle") + 2)
	assert(api.Stop() == true, "stopped")
	assert(#spawnTrips == 2, "the trip home is the world's spawn trip")
	for _, root in { aRoot, bRoot } do
		assert(SSE.InLobby(root.Position, spawnTop) and not SSE.InArena(root.Position, ARENA, true), "back in the lobby")
		near(root.Position.Y, spawnTop.Y + SSE.Teleport.Height, 1e-3, "on the lobby floor")
	end
	assert(startGate.CanCollide == true and stopBar.CanCollide == false, "the gates restored as they were")
	assert(reopens[1] == "SuperSonicEvent" and workspace.attrs.RaceClosedBy == nil, "_G.SpeedsterRace.Reopen")
	assert(a.attrs.EventFlightBlocked == nil and workspace.attrs.SSE_Phase == "", "Flight back, cleared")
	pass("service with the race arena (fake Roblox): SSE_Origin on the RaceArena floor (RespectCanCollide), SSE_LobbyOrigin, _G.SpeedsterRace.Close / Reopen, StartGate / StopBar opened and restored, the Teleport beat's trips (streamed, arrival grace, MovementGuard at the own progress, facing the centre), an admin stop's trips home (the world's spawn trip, then the free spot)")
end

----------------------------------------------------------------------
-- 5. The temporary skin (Economy/SkinSystem's SKIN OVERRIDE)
----------------------------------------------------------------------
do
	local skins = fs.readFile("src/common/ServerScriptService/Economy/SkinSystem.server.luau")
	local block = between(skins, "-- SKIN OVERRIDE BEGIN", "-- SKIN OVERRIDE END")
	local newSkinOverride = luau.load(block .. "\nreturn newSkinOverride", { debugName = "SkinOverride" })()
	-- A fake skin system: the player's own skin, the look actually worn, and everything that would be saved.
	local function setup()
		local state = { equipped = "SonicSuit", look = "SonicSuit-look", calls = {}, attrs = {}, saved = 0, owned = { SonicSuit = true } }
		local player = { Name = "P", attrs = state.attrs }
		local character = { humanoid = { Health = 100 } }
		player.Character = character
		local deps = {
			equipped = function()
				return state.equipped
			end,
			parts = function(p)
				local ch = p.Character
				if not ch or ch.humanoid.Health <= 0 then
					return nil, nil
				end
				return ch, ch.humanoid
			end,
			snapshot = function()
				return { look = state.look }
			end,
			valid = function(skinId)
				return skinId == "SuperSonicSuit" or skinId == "SonicSuit"
			end,
			isSkin = function(skinId)
				return skinId ~= ""
			end,
			wear = function(_, ch, _, skinId, isCurrent)
				table.insert(state.calls, { "wear", skinId, ch })
				state.look = skinId .. "-look"
				state.isCurrent = isCurrent
				return true
			end,
			applySkin = function(_, skinId)
				table.insert(state.calls, { "applySkin", skinId })
				state.look = skinId .. "-look"
				return true
			end,
			applyDescription = function(_, _, _, description)
				table.insert(state.calls, { "applyDescription", description })
				state.look = description.look
				return true
			end,
			refresh = function()
				table.insert(state.calls, { "refresh" })
			end,
			setAttribute = function(_, name, value)
				assert(name == "SkinOverride", "the override writes no other attribute (" .. tostring(name) .. ")")
				state.attrs[name] = value
			end,
			busy = function()
				return state.busy == true
			end,
		}
		return newSkinOverride(deps), player, character, state
	end
	-- Put on and taken off: the own skin back through the skin system's own apply; nothing owned or saved.
	local override, player, character, state = setup()
	assert(override.Apply(player, "SuperSonicSuit", "SuperSonicEvent") == true, "Apply")
	assert(state.look == "SuperSonicSuit-look" and state.attrs.SkinOverride == "SuperSonicSuit", "worn; SkinOverride attribute")
	assert(state.equipped == "SonicSuit" and state.owned.SuperSonicSuit == nil, "EquippedSkin untouched, nothing granted")
	assert(state.isCurrent() == true, "its fallbacks run while it is on")
	assert(override.Active(player) == "SuperSonicSuit", "Active")
	assert(override.Apply(player, "SuperSonicSuit", "SuperSonicEvent") == true and #state.calls == 2, "a second Apply is a no-op")
	local okOther, whyOther = override.Restore(player, "SomethingElse")
	assert(okOther == false and whyOther == "other" and state.look == "SuperSonicSuit-look", "another reason's Restore leaves it on")
	local ok, why = override.Restore(player, "SuperSonicEvent")
	assert(ok == true and why == "restored", "Restore")
	assert(state.look == "SonicSuit-look" and state.calls[#state.calls - 1][1] == "applySkin" and state.calls[#state.calls - 1][2] == "SonicSuit",
		"the player's own skin back exactly (the skin system's own apply of EquippedSkin)")
	assert(state.calls[#state.calls][1] == "refresh", "auras / trails back on")
	assert(state.attrs.SkinOverride == nil and state.isCurrent() == false, "off: the attribute cleared, its fallbacks stop")
	assert(override.Restore(player) == false, "nothing on: nothing to do")
	-- No skin of their own: the look before (the snapshot) exactly.
	override, player, character, state = setup()
	state.equipped = ""
	state.look = "own-avatar"
	override.Apply(player, "SuperSonicSuit", "SuperSonicEvent")
	override.Restore(player, "SuperSonicEvent")
	assert(state.look == "own-avatar" and state.calls[#state.calls - 1][1] == "applyDescription", "the snapshot back when no skin is equipped")
	-- A death / respawn: nothing put back on the dead or the new character (the skin system dresses the new one).
	override, player, character, state = setup()
	override.Apply(player, "SuperSonicSuit", "SuperSonicEvent")
	character.humanoid.Health = 0
	local calls = #state.calls
	ok, why = override.Restore(player, "SuperSonicEvent")
	assert(ok == false and why == "gone" and #state.calls == calls, "dead: nothing re-applied")
	override.Apply(player, "SuperSonicSuit", "SuperSonicEvent") -- the dead one: refused
	assert(override.Active(player) == nil, "no skin on a dead character")
	player.Character = { humanoid = { Health = 100 } }
	assert(override.Apply(player, "SuperSonicSuit", "SuperSonicEvent") == true, "the respawned character (a late transformation)")
	local respawned = player.Character
	-- applySavedSkin on that same character (the appearance loaded under it): dressed again, kept.
	assert(override.Rewear(player, respawned) == true and state.look == "SuperSonicSuit-look" and override.Active(player) == "SuperSonicSuit", "Rewear keeps it on")
	-- applySavedSkin on another character: forgotten.
	player.Character = { humanoid = { Health = 100 } }
	assert(override.Rewear(player, player.Character) == false and override.Active(player) == nil and state.attrs.SkinOverride == nil, "an old character's override is forgotten")
	-- The player's own choice (Evolve / the Index) replaces it: Drop, nothing put back later.
	override, player, character, state = setup()
	override.Apply(player, "SuperSonicSuit", "SuperSonicEvent")
	override.Drop(player)
	calls = #state.calls
	ok, why = override.Restore(player, "SuperSonicEvent")
	assert(ok == false and why == "none" and #state.calls == calls, "dropped: the event's Restore does nothing")
	assert(override.Apply(player, "RigThing", "SuperSonicEvent") == false, "only catalog suits")
	-- The skin system busy putting the player's own skin on (a respawn): "busy", nothing worn (the event retries).
	override, player, character, state = setup()
	state.busy = true
	local okBusy, whyBusy = override.Apply(player, "SuperSonicSuit", "SuperSonicEvent")
	assert(okBusy == false and whyBusy == "busy" and #state.calls == 0 and state.attrs.SkinOverride == nil, "busy: try later")
	state.busy = false
	assert(override.Apply(player, "SuperSonicSuit", "SuperSonicEvent") == true, "then it goes on")
	-- A second temporary skin on the same character keeps the first snapshot.
	override, player, character, state = setup()
	state.equipped = ""
	state.look = "own-avatar"
	override.Apply(player, "SuperSonicSuit", "SuperSonicEvent")
	override.Apply(player, "SonicSuit", "SuperSonicEvent")
	override.Restore(player)
	assert(state.look == "own-avatar", "the look before ANY temporary skin")
	-- The wiring in SkinSystem: never EquippedSkin, never granted, never saved.
	local wear = between(skins, "local function wearTemporarySkin(", "\nskinOverride = newSkinOverride({")
	local wiring = between(skins, "-- SKIN OVERRIDE BEGIN", "-- EquipSkin always gets an answer (2026-09-22)")
	for _, forbidden in { "forceSuitState", 'SetAttribute("EquippedSkin"', "persistSkinSelection", "unlockSkin(", "saveSkinState", "GrantSkin", "EquipSkin\"" } do
		assert(not string.find(wiring, forbidden, 1, true), "the temporary skin never " .. forbidden)
	end
	has(wear, "applyCatalogSuitDescription(humanoid, entry)", "the catalog suit's own look")
	has(wear, "clearRigOutfit(character)", "the previous skin's rig outfit off")
	has(wiring, 'return tostring(player:GetAttribute("EquippedSkin") or "")', "the own skin is read, never written")
	has(wiring, "local ok, applied = pcall(applySkinById, player, skinId)", "the own skin back through the skin system's apply")
	has(wiring, "refresh = refreshCosmeticsAfterSkin,", "auras / trails refreshed")
	has(wiring, "_G.SpeedsterSkinOverride = {", "the API for the event")
	local applyById = between(skins, "local function applySkinById(player, skinId)", "\tlocal applied\n")
	has(applyById, "skinOverride.Drop(player)", "a real equip drops the temporary skin")
	has(between(skins, "local function unequipFlashSuit(player)", "\tlocal character = player.Character\n"), "skinOverride.Drop(player)", "unequip too")
	local saved = between(skins, "local function applySavedSkin(player)", "\tapplyingSavedSkin[player] = true\n")
	has(saved, "if skinOverride and skinOverride.Rewear(player, character) then", "a respawn's apply keeps an override on its own character")
	has(skins, "skinOverride.Forget(player) -- 2026-09-26 (owner)", "forgotten on leaving")
	has(wiring, "return applyingSavedSkin[player] == true or evolveInProgress[player] == true", "busy while the skin system applies a skin")
	has(skins, "or (skinOverride ~= nil and skinOverride.Active(player) ~= nil) -- 2026-09-26 (owner): an event's skin is on",
		"the own skin's late fallbacks stand aside while the event's skin is on")
	assert(luau.compile(skins), "SkinSystem compiles")
	local catalog = fs.readFile("src/common/ReplicatedStorage/Shared/SuitCatalog.luau")
	local entry = between(catalog, 'Id = "SuperSonicSuit",', "\t},")
	assert(not string.find(entry, "SpecialApplyMode", 1, true) and string.find(entry, "MaskId", 1, true) and string.find(entry, "ShirtId", 1, true),
		"SuperSonicSuit is a catalog suit (mask, shirt, pants)")
	pass("skin override: the game's Super Sonic skin on without EquippedSkin / ownership / saving, the own skin back exactly (skin system apply, or the snapshot), death / respawn / Rewear / Drop / other reasons, first snapshot kept; SkinSystem wiring")
end

----------------------------------------------------------------------
-- 6. The admin panel
----------------------------------------------------------------------
do
	local service = fs.readFile("src/common/ServerScriptService/Admin/AdminAbusePanelService.server.luau")
	local controller = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/Admin/AdminAbusePanelController.client.luau")
	local function chunkBetween(first, last)
		return between(service, first, last)
	end
	local EVENTS = luau.load(chunkBetween("local EVENTS = {", "\n-- 2026-09-26 (owner): an admin may give") .. "\nreturn EVENTS")()
	assert(EVENTS.SuperSonic == true and EVENTS.MegaRace == true, "EVENTS lists SuperSonic")
	local G = {}
	local calls = {}
	local env = setmetatable({
		_G = G,
		U4 = { IsOn = function() return true end },
		stopDisco = function() end, stopSnow = function() end, stopSandstorm = function() end, stopRainingTacos = function() end,
		startDisco = function() end, startSnow = function() end, startSandstorm = function() end, startRainingTacos = function() end,
		discoFloor = function() return nil, nil end,
		eventTokens = {},
		Lighting = { FindFirstChild = function() return nil end },
		Panel = { FireAllClients = function(_, payload) table.insert(calls, payload) end },
		PotionServer = {}, Players = { GetPlayers = function() return {} end },
	}, { __index = _G })
	local runEvent, stopEvent, lastStart = luau.load(chunkBetween("local function stopEvent(name: string)", "\nlocal TREADMILL_FOLDER")
		.. "\nreturn runEvent, stopEvent, function() return superSonicStart end", { environment = env })()
	runEvent("SuperSonic", 60, true, { UserId = 1, Name = "Boss" })
	assert(lastStart().ok == false and lastStart().reason == "missing", "no service: not available")
	local started, stopped = {}, 0
	local answer = { true, nil }
	G.SpeedsterSuperSonicEvent = {
		Start = function(byName)
			table.insert(started, byName)
			return answer[1], answer[2]
		end,
		Stop = function()
			stopped += 1
			return true
		end,
	}
	runEvent("SuperSonic", 60, true, { UserId = 1, Name = "Boss" })
	assert(started[1] == "Boss" and lastStart().ok == true, "runEvent -> Start(byName)")
	answer = { false, "running" }
	runEvent("SuperSonic", 60, true, nil)
	assert(started[2] == "Admin" and lastStart().ok == false and lastStart().reason == "running", "a refusal is kept for the toast")
	runEvent("SuperSonic", 0, false, nil)
	assert(stopped == 1, "off -> Stop")
	G.SpeedsterSuperSonicEvent.Start = function()
		error("service failure")
	end
	runEvent("SuperSonic", 60, true, nil)
	assert(lastStart().ok == false, "a failing Start is a refusal")
	for _, payload in calls do
		assert(payload.effect ~= "SuperSonic", "the panel draws nothing itself for it")
	end
	has(service, 'toast(admin, false, "Super Sonic vs Eggman: "', "the admin is told when it did not start")
	has(controller, '{ "🦔", "SuperSonic", "Super Sonic vs Eggman", "Eggman attacks the lobby: go Super, +600 Wins a hit", "Gold" },', "the event tile (+600 a hit)")
	pass("admin: EVENTS.SuperSonic, runEvent -> _G.SpeedsterSuperSonicEvent.Start(byName) (guarded, pcall, refusal kept), stopEvent -> Stop, the tile (+600 Wins a hit)")
end

----------------------------------------------------------------------
-- 7. The build step
----------------------------------------------------------------------
do
	local notes = {}
	local folder = Assets.Build(notes)
	assert(folder.Name == "SuperSonicEventAssets" and folder:GetAttribute("U4Asset") == Assets.Stamp, "stamped folder")
	local vfx = folder:FindFirstChild("VFX")
	assert(vfx and #vfx:GetChildren() == 4, "4 VFX")
	for _, name in { "BombExplode", "EggImpact", "FireTrail", "BurstHatch" } do
		local effect = vfx:FindFirstChild(name)
		assert(effect, "VFX." .. name)
		local emitters = 0
		for _, d in effect:GetDescendants() do
			if d.ClassName == "ParticleEmitter" then
				emitters += 1
			end
		end
		assert(emitters > 0, name .. " has its particle emitters")
		assert(SSE.VfxNames[name] == name, "the contract names " .. name)
	end
	local meshes = folder:FindFirstChild("Meshes")
	assert(meshes and meshes.ClassName == "Folder", "Meshes folder")
	if not fs.isFile(Assets.KitFile) then
		assert(#meshes:GetChildren() == 0, "Meshes empty without the Blender kit")
	end
	assert(#Assets.Scripts(folder) == 0, "no scripts")
	local dm = roblox.Instance.new("DataModel")
	local replicated = dm:GetService("ReplicatedStorage")
	Assets.Insert(dm, notes)
	local first = replicated:FindFirstChild(Assets.Name)
	Assets.Insert(dm, notes)
	local count = 0
	for _, child in replicated:GetChildren() do
		if child.Name == Assets.Name then
			count += 1
		end
	end
	assert(count == 1 and replicated:FindFirstChild(Assets.Name) ~= first, "a rebuild replaces the stamped folder")
	Assets.Verify("memory", dm)
	local sneaky = roblox.Instance.new("Script")
	sneaky.Parent = replicated:FindFirstChild(Assets.Name).VFX.BombExplode
	assert(#Assets.Problems(dm) == 1, "a script inside is a problem")
	replicated:FindFirstChild(Assets.Name):Destroy()
	local foreign = roblox.Instance.new("Folder")
	foreign.Name = Assets.Name
	foreign.Parent = replicated
	assert(not pcall(Assets.Insert, dm, notes), "an unstamped folder is not replaced")
	local build = fs.readFile("audit/build_update4.luau")
	has(build, 'require("./u4_supersonic_assets").Insert(dm, notes)', "build_update4 edit inserts the folder")
	has(build, 'require("./u4_supersonic_assets").Verify(key, dm)', "build_update4 verify checks it")
	pass("build: ReplicatedStorage.SuperSonicEventAssets { VFX, Meshes }, stamped, no scripts, replaced on a rebuild, an unstamped one refused, hooked into build_update4")
end

-- `places`: what the build wrote into the three places.
if table.find(process.args, "places") then
	for _, file in { "World1Update3New.rbxl", "World2Update3new.rbxl", "World3Update3New.rbxl" } do
		local dm = roblox.deserializePlace(fs.readFile(file))
		Assets.Verify(file, dm)
	end
	pass("places: SuperSonicEventAssets in the three places (stamped, 4 VFX, Meshes, no scripts)")
end

print("test_u4_supersonic_event: " .. passed .. " checks passed")
