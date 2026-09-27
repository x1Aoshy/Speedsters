--!strict
-- ReplicatedStorage/Shared/Update4Config.luau — every Update 4 tunable. Pure data + IsOn.
-- 2026-09-25: Lune (the audit tests) has no Roblox globals, so there Vector3/Color3 come from
-- @lune/roblox and pure modules and tests can require this file directly. In Roblox the
-- globals exist and the branch never runs (the dynamic require keeps Script Analysis quiet).
local Vector3, Color3 = Vector3, Color3
if Vector3 == nil or Color3 == nil then
	local lateRequire: any = require
	local ok, roblox = pcall(lateRequire, "@lune/roblox")
	if ok and type(roblox) == "table" then
		Vector3, Color3 = roblox.Vector3, roblox.Color3
	end
end

local U4 = {}

U4.Flags = {
	Race = { Enabled = true, TestingOnly = false },
	MegaRace = { Enabled = true },
	Titles = { Enabled = true },
	Streak = { Enabled = true },
	PlaytimeBoost = { Enabled = true },
	Community = { Enabled = true },
	StaminaPass = { Enabled = true }, -- effective only when StaminaPass.GamePassId > 0
}
U4.KillAttributePrefix = "U4Off_" -- Workspace attribute U4Off_<Feature> = true turns a feature off live
U4.TestingPlaceIds = { [138540610580146] = true, [96501592055150] = true, [94956471703437] = true }

-- Checked at every request, not only at startup.
function U4.IsOn(feature: string): boolean
	local flag = U4.Flags[feature]
	if not flag or flag.Enabled ~= true then return false end
	if feature == "StaminaPass" and (tonumber(U4.StaminaPass.GamePassId) or 0) <= 0 then return false end
	if typeof(game) ~= "Instance" then return true end
	local ok, off = pcall(function()
		return game:GetService("Workspace"):GetAttribute(U4.KillAttributePrefix .. feature)
	end)
	if ok and off == true then return false end
	if flag.TestingOnly == true and not U4.TestingPlaceIds[game.PlaceId] then return false end
	return true
end

U4.Race = {
	Arena = { Origin = Vector3.new(6000, 12000, 0) }, -- centre of the start line, floor top; forward = -Z
	Track = {
		Length = 2000, RunOut = 120, Width = 72, Lanes = 8, LaneWidth = 9, StagingDepth = 64,
		SlotRows = { -10, -22 }, -- s of grid row A / B (8 lanes each => 16 slots)
		SpikeFields = { 300, 750, 1200, 1650 }, SpikeRowGap = 40, SpikeTile = 7, SpikeTileHeight = 0.4,
		-- per field: { blocked lanes row 1, blocked lanes row 2 } (always 4 free lanes per row)
		SpikeBlocked = {
			{ { 2, 4, 6, 8 }, { 1, 3, 5, 7 } },
			{ { 1, 2, 7, 8 }, { 3, 4, 5, 6 } },
			{ { 1, 3, 5, 7 }, { 2, 4, 6, 8 } },
			{ { 3, 4, 5, 6 }, { 1, 2, 7, 8 } },
		},
		Gantries = { 500, 1000, 1500 }, LastStretchAt = 1800, OrbS = 2060, OrbY = 34,
		DecorChunk = 240,
	},
	-- Lobby Race Gate pad. 2026-09-25: the first World 1 / World 3 probes sat inside the lobby's
	-- 21-stud back-edge block; these points pass test_u4_race_placement against the three places.
	Gate = {
		World1 = { Position = Vector3.new(404, 37467.69, -1664), Face = Vector3.new(340, 37467.69, -1664) }, -- open NE corner, off the walk to Stage 1
		World2 = { Position = Vector3.new(-845, 36626.65, -1005), Face = Vector3.new(-784, 36626.65, -1005) },
		World3 = { Position = Vector3.new(136, 95.61, 392), Face = Vector3.new(200, 95.61, 392) },
	},
	Board = { World1 = "AfterWins", World2 = "AfterRobux", World3 = "AfterWins" },
	Queue = {
		MinPlayers = 2, MaxPlayers = 12, GatherSeconds = 20, GatherFullSeconds = 5, SoloWaitSeconds = 25,
		StagingSeconds = 3, CountdownSeconds = 5, SetLeadSeconds = 3.5, ChargeOpenLeadSeconds = 3.0,
		MaxRaceSeconds = 60, FinishGraceSeconds = 15, ResultsSeconds = 7, CooldownSeconds = 8,
		InviteCooldownSeconds = 300, StreamTimeoutStuds = 30, StreamAroundSeconds = 5,
		IdleDnfProgress = 0.05, -- two DNFs in a row under 5% => removed from auto-requeue
	},
	Mega = { MaxPlayers = 16, GatherSeconds = 30, MinPlayers = 1, Multiplier = 2 },
	Speed = { BaseCruise = 50, MaxStatBonus = 0.06, StatScale = 6, SprintMultiplier = 1.4,
		TauUp = 1.6, TauDown = 0.8, InputConeDegrees = 70, StumbleFactor = 0.5 },
	-- 2026-09-25 (owner): three queues so the speed gap stays fair. RaceBracket (player attribute,
	-- server) is the higher of the Speed tier and the Rebirths tier: Beginner = Speed < 1e6 and
	-- Rebirths <= 2; Pro = Speed >= 1e12 or Rebirths >= 15 (World 3's gate); Mid otherwise.
	-- Categories: "Beginner" (Beginner bracket only), "Rank" (a heat mixes two adjacent brackets
	-- at most), "Open" (anyone; fills any heat whose bracket rule it meets). The HUD button, the
	-- invite, the panel and the gate join DefaultCategory; the Flash NPC sends its own.
	-- Heats (RaceService.FormHeat): one arena, one heat per cycle: the biggest heat the queue can
	-- make, unless the player who has waited longest has waited AnchorAfterSeconds: then the heat
	-- is theirs (so nobody waits more than about one race); a Mega Race takes everyone.
	Matchmaking = {
		Categories = { "Beginner", "Rank", "Open" }, DefaultCategory = "Rank",
		Brackets = { "Beginner", "Mid", "Pro" },
		BeginnerMaxSpeed = 1e6, BeginnerMaxRebirths = 2, ProMinSpeed = 1e12, ProMinRebirths = 15,
		BracketRefreshSeconds = 5, AnchorAfterSeconds = 40,
	},
	Stamina = { SprintBaseSeconds = 4, SuitSprintBonus = 0.25, RegenPerSecond = 0.12, RegenDelay = 0.8,
		MinSprintPool = 0.10, JumpCost = 0.06, PassRegenFactor = 1.0 }, -- 1.0 = the 2x pass does nothing in races
	Charge = {
		Fill = 0.55, Decay = 0.35, ZoneLo = 0.58, ZoneHi = 0.84, CoreLo = 0.65, CoreHi = 0.77,
		Vent = 1.0, VentSeconds = 0.6, Window = 1.5, StallWindow = 0.75, StallAt = 0.97,
		PerfectQ = 0.65, GoodQ = 0.30, AltGoodG = 0.45, AltGoodQ = 0.55,
		CostPerHeldSecond = 0.15, MinPress = 0.03, MaxEdges = 40, MaxLag = 0.40, FutureSlack = 0.05,
		JudgeDelay = 0.45, GraceRaces = 3, AssistAfterMisses = 3,
		AssistZone = { 0.50, 0.90 }, AssistCore = { 0.60, 0.80 },
		Launch = { Perfect = 0.8, Good = 0.5, Ok = 0.2, Stall = 0 }, -- v0 = Vc * Launch
		Boost = { Perfect = { 1.45, 1.2, 2.5 }, Good = { 1.22, 1.0, 2.0 }, Stall = { 0.45, 0.8 } },
	},
	Spikes = { Keep = 0.35, StumbleSeconds = 0.7, ImmuneSeconds = 0.9, HitInset = 0.5,
		CharacterHalfWidth = 1, MaxHeightAbove = 3 },
	Validation = { Tolerance = 0.06, SlackStuds = 10, LatencySeconds = 0.3, SampleHz = 20,
		RateWindow = 0.5, RateFactor = 1.288, RateStrikeWindows = 3, MaxStrikes = 3, MinPlausibleMs = 30000,
		PingCompMaxMs = 120, FalseStartS = 1.5, CorridorHalfWidth = 44, CorridorSMin = -150,
		CorridorSMax = 2240, CorridorYMax = 80, FallY = -25 },
	Super = { EnterFraction = 0.93, ExitFraction = 0.85, LocalEnterFraction = 0.97 },
	Rewards = {
		WinsShare = { 0.06, 0.04, 0.03 }, FinisherShare = 0.015, DnfShare = 0.005, DnfMinProgress = 0.25,
		SpeedAfkMinutes = { 3.6, 2.8, 2.4 }, FinisherAfkMinutes = 1.8, DnfAfkMinutes = 0.6,
		FieldBase = 0.4, FieldPerRacer = 0.1, FieldMin = 0.5, FieldMax = 1.0,
		DailyFirstMultiplier = 2, DailyFirstSpinTickets = 1,
		HourlyFullRaces = 30, OverCapFactor = 0.25,
		SpeedCapShareOfRaw = 0.05, SpeedCapFlat = 2000,
	},
	Leaderboard = { AllTimeStore = "SpeedsterEscape_RaceBestMs_v1", WeeklyPrefix = "SpeedsterEscape_RaceBestMs_W",
		FlushSeconds = 30, MaxWritesPerFlush = 20, ReadSeconds = 120, TopCount = 50, BoardRequestSeconds = 2 },
	Titles = { WinTitles = { [1] = "race_winner", [25] = "race_champion", [100] = "race_legend" },
		PerfectTitle = { Count = 10, Id = "lightning_start" } },
	Hud = { MphPerStud = 1, ResultsAutoLobbySeconds = 8, InviteHideSeconds = 10,
		RewardIcon = "rbxassetid://107664846509614", LiveHz = 4 },
	Art = { ChevronTexture = "", StudTexture = "rbxassetid://6794250394" },
	Feel = {
		Pose = { StrideCap = { High = 3.6, Mid = 3.0, Low = 2.6 }, BlendIn = 0.35, BlendOut = 0.3,
			Launch = 0.22, SuperBlend = 0.2,
			Lod = { High = { Full = 150, Reduced = 250, ReducedHz = 20 }, Mid = { Full = 60, Reduced = 150, ReducedHz = 15 },
				Low = { Full = 60, Reduced = 150, ReducedHz = 15 } } },
		Vfx = {
			Colors = { Charge1 = Color3.fromRGB(255, 226, 90), Charge2 = Color3.fromRGB(255, 250, 200),
				Burst = Color3.fromRGB(255, 240, 140), Overheat = Color3.fromRGB(255, 90, 40), Arc = Color3.fromRGB(255, 240, 160) },
			BubbleEnvelopeEvery = { High = 0.45, Mid = 0.9 },
			Barrier = { StartSize = 6, EndSize = 30, StartTransparency = 0.15, Life = 0.55 },
			Envelope = { StartSize = Vector3.new(7, 7, 9), EndSize = Vector3.new(11, 11, 15), StartTransparency = 0.45, Life = 0.45 },
			GlassOnScreenCap = { High = 5, Mid = 0, Low = 0 },
			RemoteParticleCap = { High = 120, Mid = 40, Low = 24 },
		},
		Camera = { SetFovDrop = 6, PerfectPunch = 22, GoodPunch = 12, SuperFov = 100, SuperPunch = 10 },
		Sounds = { ChargeHum = "rbxassetid://9114277757", ZoneTick = "rbxassetid://72264591133889",
			Overheat = "rbxassetid://9114615010", Go = "rbxassetid://9119382815",
			SuperEnter = "rbxassetid://9114615010", SuperBoom = "rbxassetid://9119382815", SuperWind = "" },
	},
}

-- 2026-09-25 (owner, race polish). Amendments to the PLAN §2.1 race contract above, which stays
-- line for line (audit/test_u4_contracts); these values are the ones the game uses.
do
	local race = U4.Race
	-- The race speed reflects progress: cruise = BaseCruise + LogScale * log10(Speed stat),
	-- clamped to [BaseCruise, MaxCruise]: Speed 1 = 40, 1e6 = 76, 1e12 = 112, 1e18+ = 148
	-- studs/s (RaceMath.CruiseSpeed); sprint x1.4 (207 at the cap) and a Perfect start peaks at
	-- x1.45 of that (~300). The world walk multipliers are still never used. RunFloor: a racer
	-- moving forward on the ground never goes under RunFloor x cruise (no walking in a race),
	-- except while a spike trips them and in a Stall's hold. (MaxStatBonus / StatScale are gone.)
	race.Speed = { BaseCruise = 40, LogScale = 6, MaxCruise = 148, SprintMultiplier = 1.4, RunFloor = 0.6,
		TauUp = 1.6, TauDown = 0.8, InputConeDegrees = 70, StumbleFactor = 0.5 }
	-- v0 = Vc * Launch: +0.4 for every grade but Stall (the same gaps between them), so the launch
	-- is a real impulse and no start is a walk.
	race.Charge.Launch = { Perfect = 1.2, Good = 0.9, Ok = 0.6, Stall = 0 }
	-- A Speed-1 racer needs ~45-55 s now: 70 s at most, and after the first finish the heat still
	-- waits for its slowest racer's cruise time x FinishWaitFactor (RaceMath.ExpectedSeconds).
	race.Queue.MaxRaceSeconds = 70
	race.Queue.FinishWaitFactor = 1.15
	-- The record floor (profiles, boards), under the fastest race the speed cap allows (~6.3 s);
	-- each racer's own implausibility floor is RaceMath.PlausibleMs(params) (was 30000 for all).
	race.Validation.MinPlausibleMs = 5000
	-- A capped racer finishes in ~11 s and could race ~80 times an hour: past HourlyPaidRaces
	-- rewarded races in the hour a race pays nothing (an always-winner stays <= 2.01 laps/hour).
	race.Rewards.HourlyPaidRaces = 40
	-- 2026-09-25 (owner: Astra's final map, design/race/CONTRATO_MAPA_ASTRA.md §2b): a straight
	-- track with gentle hills. Heights are measured from the ground under the racer, h(s, x): a
	-- profile sampled every Step studs of s (from the staging box to the end wall) in the
	-- Columns (x) across the track, interpolated (RaceTrack.Ground). The server raycasts it from
	-- the arena's collidable floor when the arena loads and publishes it (Workspace attribute
	-- RaceGroundProfile), so prediction and validation use the same numbers; the builder's flat
	-- arena gives a flat profile. MaxSlopeDegrees / MaxStepStuds are the map's contract; the
	-- envelope allows the path length of the steepest slope on top of its tolerance.
	race.Ground = { Step = 4, Columns = { -31.5, 0, 31.5 }, MaxSlopeDegrees = 10, MaxStepStuds = 1,
		CastAbove = 25, CastDepth = 120, MaxHeight = 60 }
	-- Speed pads: Parts named SpeedPad in RaceArena.SpeedPads (arrow toward -Z). Attributes Boost
	-- (x the speed cap, default 1.25, clamped to MaxBoost) and Seconds (default 1.5, <= MaxSeconds).
	-- Feet over the pad: s and x inside its footprint and the feet within FeetBelow..FeetAbove
	-- studs of its top. The client is strict, the server grants within ServerMargin studs of the
	-- footprint (an honest crossing is never missed). A pad starts the boost with an instant kick
	-- (v x Boost); another pad while boosted only refreshes the time (never stacks).
	race.Pads = { DefaultBoost = 1.25, DefaultSeconds = 1.5, MaxBoost = 1.5, MaxSeconds = 3,
		FeetBelow = 1, FeetAbove = 3, ServerMargin = 1, MaxPads = 24 }
	-- A whoosh for the pads (owner's sound, 2026-09-26; "" = no sound).
	race.Feel.Sounds.PadWhoosh = "rbxassetid://90156573887604"
	-- 2026-09-26 (owner: the Green Hill map stands on a thin layer of water, not in a void):
	-- Gameplay/RaceArenaWater fills Terrain once per server around the arena, in track-local
	-- studs (y over Origin.Y, x across, s along the track; every number a multiple of 4, the
	-- voxel grid, so the layers are exact): water from Bottom to Top (8 studs under the floor,
	-- which is at 0..6), a sand seabed from SeabedBottom to Bottom, |x| <= HalfX, s from SMin to
	-- SMax (the Green Hill kit's terraces and mesas reach x -484..462, s -493..2763), filled in
	-- strips of StripStuds of s. Kill switch: Workspace.U4Off_RaceWater (clears it).
	race.Water = { Top = -8, Bottom = -12, SeabedBottom = -16, HalfX = 700, SMin = -600, SMax = 2900,
		Material = "Water", SeabedMaterial = "Sand", StripStuds = 400 }
end

-- 2026-09-26 (owner): race speed + spike spacing. Amends the blocks above (the PLAN §2.1 lines
-- stay line for line); these are the values the game uses.
do
	local race = U4.Race
	-- Sonic Dash speeds, the owner's formula: cruise = BaseCruise + LogScale * log10(Speed + 1) =
	-- 100 + 18 log10(Speed stat + 1), capped at MaxCruise 300 (reached at Speed ~1.3e11, so the
	-- whole Pro bracket, Speed >= 1e12, races at the cap: fair). Speed 0 = 100, 1 = 105,
	-- 1e6 = 208, 1e9 = 262, 1e12+ = 300 studs/s; sprint x1.4 (420 at the cap), a Perfect start
	-- peaks at x1.45 of that (609) and a pad adds x1.25 (Astra's pads; x1.5 at most). Best races
	-- (Perfect start, paced sprint, Astra's 5 pads): Speed 1 ~12.5 s, 1e6 ~5.3 s, 1e9 ~4.0 s,
	-- the cap ~3.5 s; a Speed-1 racer at cruise alone needs ~19 s. The rest (RunFloor, TauUp,
	-- TauDown, the input cone, the stumble) is unchanged, and relative to the cruise.
	race.Speed.BaseCruise = 100
	race.Speed.LogScale = 18
	race.Speed.MaxCruise = 300
	-- The slowest honest racer (Speed 0, Stall start, never sprints, trips on every spike row)
	-- needs ~30 s; after the first finish a heat waits for its slowest racer's ExpectedSeconds
	-- (the cruise time plus RaceMath.TripSeconds, ~1.08 s, per spike row: ~35 s at Speed 0 with
	-- the FinishWaitFactor 1.15), so 45 s at most.
	race.Queue.MaxRaceSeconds = 45
	-- The record floor (profiles, boards): under the fastest race physics allows at all, the cap
	-- x sprint x the Perfect peak x the largest pad at every instant (300 x 1.4 x 1.45 x 1.5 =
	-- 913 studs/s: 2.19 s for 2000 studs; the best real one is ~2.9 s with x1.5 pads, ~3.5 s on
	-- Astra's map). Each racer's own floor stays RaceMath.PlausibleMs(params, pads, allowance).
	race.Validation.MinPlausibleMs = 2000
	-- HourlyPaidRaces (40) needs no change: it counts races, not seconds. A heat still takes at
	-- least ~30 s (5 s full gathering + 3 + 5 + the race + 7 + 8), so an always-winner stays
	-- under ~2.01 laps an hour however fast the races are.
	-- Streaming: the arena streams (only the floor, pads, barriers and now the spikes are
	-- Persistent), and a racer covers 2000 studs in 3-20 s. While staging, the server also asks
	-- to stream each racer the track at these s (RaceServer, after the slot; StreamingMinRadius
	-- 512 overlaps them), so the whole track is on the client before GO.
	race.Queue.StreamAheadS = { 500, 1000, 1500, 2000 }
	-- Ground adhesion (Movement/InstantMovementController, RaceTrack.AdhesionVelocity): at these
	-- speeds a racer leaving a hill crest keeps the climb's upward speed and flies over the
	-- spikes and pads. While racing and not jumping, the root's upward speed is capped at the
	-- ground's own rise along the motion (the profile's grade over LookSeconds of travel, at
	-- least 1 stud and at most MaxLook studs ahead) minus Pull x the height it floats over its
	-- standing height (past DeadBand). Never above SnapStuds (a real fall or another racer's
	-- head is left to physics) and never while jumping: jumps stay as they were.
	-- MaxLift: the standing root over RaceTrack.RootHeight (3) that a tall avatar or the Silver
	-- Surfer's board adds (RaceTrack.StandHeight); spike and pad height tests take it off, so
	-- a hover is no spike immunity (a root 0.4 studs over 3 used to clear every row).
	race.Adhesion = { SnapStuds = 2.5, DeadBand = 0.1, Pull = 12, LookSeconds = 1 / 30, MaxLook = 16, MaxLift = 1.5 }
	-- Spikes (owner: never an impassable wall, a reflex / skill test): rows SpikeRowGap = 90
	-- studs apart (0.2 s at the cap's sprint; the owner's minimum is 60), every row blocks 4 of
	-- the 8 lanes (4 free) and consecutive rows of a field are complementary, so no straight
	-- lane is free through two rows: the racer weaves (at most 2 lanes, 18 studs, between rows).
	-- Fields 2 and 3 get a third row. Rows (s): 300, 390 | 750, 840, 930 | 1200, 1290, 1380 |
	-- 1650, 1740; Astra's pads (60, 480, 990, 1450, 1850) stay >= 60 studs from every row.
	race.Track.SpikeRowGap = 90
	race.Track.SpikeBlocked = {
		{ { 2, 4, 6, 8 }, { 1, 3, 5, 7 } }, -- s 300, 390: checker
		{ { 1, 2, 7, 8 }, { 3, 4, 5, 6 }, { 1, 2, 7, 8 } }, -- s 750, 840, 930: edges, centre, edges
		{ { 1, 2, 5, 6 }, { 3, 4, 7, 8 }, { 1, 2, 5, 6 } }, -- s 1200, 1290, 1380: pairs
		{ { 3, 4, 5, 6 }, { 1, 2, 7, 8 } }, -- s 1650, 1740: centre, edges
	}
end

-- 2026-09-26 (owner): race VFX. The race's look is rebuilt around the Sonic Burst feel with no
-- particles at all (Shared/RaceVfx, Shared/RaceScreenFx, Race/RacePoseClient): electric arcs of
-- segmented Beams over the body while the start is held, a Sonic Boom at GO (shock rings on the
-- ground and on the screen, an FOV punch and a shake scaled by the grade), after-images of the
-- body at speed (2026-09-26, owner: the sprint's dark shadow, see AfterImage), ring shockwaves
-- at speed pads and the finish line, speed lines and a vignette on the screen that follow the
-- racer's speed over their own cruise. The
-- BubbleModule bubble is gone from races: Feel.Vfx's bubble / envelope / Glass / particle-cap
-- values above are no longer read (Feel.Vfx.Colors still are). Kill switches (Workspace
-- attributes, live): U4Off_RaceFx (all of it), U4Off_RaceGhosts (the after-images),
-- U4Off_RaceScreen (the lines, the vignette and the screen ring).
do
	local feel = U4.Race.Feel
	U4.Flags.RaceFx = { Enabled = true }
	U4.Flags.RaceGhosts = { Enabled = true }
	U4.Flags.RaceScreen = { Enabled = true }
	-- GO: CameraPunch.Fov(Fov) and CameraPunch.Shake(ShakeSeconds, ShakeStrength), the strength
	-- and the punch times the grade's share (Stall: nothing). Reduced motion: ReducedFov of the
	-- punch and no shake. (Replaces Camera.PerfectPunch / GoodPunch.)
	feel.Launch = { Fov = 18, ShakeSeconds = 0.3, ShakeStrength = 1.5, ReducedFov = 0.5,
		Grade = { Perfect = 1, Good = 0.6, Ok = 0.3, Stall = 0 } }
	-- The arcs, per tier: chains on the own racer (Points attachments each, on the Torso, limbs and
	-- head), re-rolled Hz times a second at full charge; the others' chains (OtherArcs) only on the
	-- nearest OthersNearest inside OtherDistance. Width: a chain's root width at g 0 / g 1 (studs),
	-- tapered to Taper of it at the tip; Leap: how far a tip may jump off the body at full charge.
	feel.Lightning = {
		Arcs = { High = 6, Mid = 4, Low = 2 }, Points = { High = 5, Mid = 4, Low = 4 }, Hz = { High = 20, Mid = 12, Low = 8 },
		OtherArcs = { High = 2, Mid = 1, Low = 0 }, OtherHz = { High = 10, Mid = 8, Low = 0 },
		OthersNearest = { High = 6, Mid = 3, Low = 0 }, OtherDistance = { High = 90, Mid = 60, Low = 0 },
		Width = { 0.08, 0.26 }, FlashWidth = 0.34, Taper = 0.3, Leap = 1.2,
		FlashSeconds = 0.3, PadFlashSeconds = 0.2, FinishFlashSeconds = 0.35,
	}
	-- After-images: a silhouette stamped every Every seconds and living Life seconds (Transparency
	-- 0.3 -> 0.7 -> 1 over it) while the racer runs at SpeedFrom x their own cruise or faster (and
	-- over MinSpeed), at super speed, BurstSeconds after GO, PadSeconds after a pad, FinishSeconds
	-- at the line. Others: only the nearest OthersNearest inside OtherDistance, every OtherEvery.
	-- CameraClear: one this close to the camera is not drawn (the chase camera passes the newest).
	-- 2026-09-26 (owner): the race's after-images are the sprint's dark shadow (StarterCharacterScripts/
	-- R15SpeedsterRun's AFTERIMAGE_COLOR, SmoothPlastic), never the aura's or the race's gold tints:
	-- Color (RGB) and Material ("SmoothPlastic"; "Neon" is a dark Neon, "ForceField" also works).
	feel.AfterImage = {
		Every = { High = 0.05, Mid = 0.08, Low = 0.12 }, Life = { High = 0.3, Mid = 0.28, Low = 0.24 },
		Transparency = { 0.3, 0.7, 1 }, SpeedFrom = 1.12, MinSpeed = 12, Material = "SmoothPlastic", Color = { 28, 17, 38 },
		BurstSeconds = { Perfect = 0.8, Good = 0.55, Ok = 0.3, Stall = 0 }, PadSeconds = 0.45, FinishSeconds = 0.5,
		OthersNearest = { High = 3, Mid = 1, Low = 0 }, OtherEvery = { High = 0.1, Mid = 0.14, Low = 0 },
		OtherDistance = { High = 90, Mid = 60, Low = 0 }, CameraClear = 5,
	}
	-- Ring shockwaves (four curved Beams each) from a pool per tier; another racer's only inside
	-- OtherDistance. Per kind: Count rings Gap seconds apart, radius R0 -> R1 studs over Life
	-- seconds, a band Width studs wide, flat on the ground or Vertical (a gate across the track).
	feel.Rings = {
		Pool = { High = 8, Mid = 5, Low = 3 }, OtherDistance = { High = 120, Mid = 80, Low = 0 },
		Go = {
			Perfect = { Count = 2, Gap = 0.09, R0 = 1.5, R1 = 26, Life = 0.5, Width = 1.6 },
			Good = { Count = 1, Gap = 0, R0 = 1.5, R1 = 18, Life = 0.42, Width = 1.2 },
			Ok = { Count = 1, Gap = 0, R0 = 1.2, R1 = 9, Life = 0.3, Width = 0.7 },
		},
		Pad = { Count = 1, Gap = 0, R0 = 1.5, R1 = 16, Life = 0.35, Width = 1 },
		Super = { Count = 1, Gap = 0, R0 = 3, R1 = 22, Life = 0.45, Width = 1.3, Vertical = true },
		Finish = { Count = 2, Gap = 0.12, R0 = 4, R1 = 40, Life = 0.7, Width = 2.2, Vertical = true },
	}
	-- The own racer's screen: speed lines from LinesFrom to LinesFull x the own cruise (Lines per
	-- tier, redrawn up to Hz times a second); the vignette's edge alpha up to VignetteAlpha with the
	-- speed and the FOV (BaseFov -> FovFull); a shock ring out of the middle of the screen at GO
	-- (the grade's share), a pad (PadShock) or the finish (FinishShock), ShockSeconds long.
	feel.Screen = {
		Lines = { High = 28, Mid = 16, Low = 8 }, Hz = { High = 60, Mid = 30, Low = 20 },
		LinesFrom = 1.05, LinesFull = 1.4, VignetteAlpha = 0.55, BaseFov = 70, FovFull = 100,
		ShockSeconds = 0.4, ShockRings = { High = 2, Mid = 1, Low = 1 }, PadShock = 0.45, FinishShock = 0.6, SuperShock = 0.35,
	}
	-- The charge's sonic turbine (Feel.Sounds.ChargeHum, Race/RaceInputClient): pitch and volume
	-- climb from the first to the second number as the gauge fills while held.
	feel.Turbine = { Pitch = { 0.7, 1.75 }, Volume = { 0.12, 0.55 } }
	-- The run's FOV (RaceFovTarget): Camera.SuperFov reached at the super-speed ratio of the own
	-- cruise (Super.EnterFraction x Speed.SprintMultiplier), 70 at the cruise, in RunFovStep
	-- degrees; PadPunch: a speed pad's CameraPunch.Fov.
	feel.Camera.RunFovStep = 1
	feel.Camera.PadPunch = 8
end

U4.Playtime = { StepSeconds = 600, StepPercent = 10, MaxPercent = 100, ResumeGraceSeconds = 900,
	TickSeconds = 5, VolatileSaveSeconds = 60, Markers = { 600, 1800, 3600, 6000 } }
U4.Streak = {
	PercentPerDay = 10, MaxPercent = 100, GraceEveryDays = 7, CheckInDelaySeconds = 60, CycleDays = 21,
	MaxPending = 6, MaxClaimedKept = 64,
	Milestones = {
		First = { [7] = { Perk = 0.2, TitleId = "streak_7" }, [14] = { Perk = 0.4 },
			[21] = { SpinTickets = 5, SpeedPotionMinutes = 60, WinsPotionMinutes = 60, TitleId = "streak_21" } },
		Repeat = { [7] = { SpinTickets = 2, SpeedPotionMinutes = 30 }, [14] = { SpinTickets = 2, SpeedPotionMinutes = 30 },
			[21] = { SpinTickets = 5, SpeedPotionMinutes = 60, WinsPotionMinutes = 60 } },
	},
}
U4.RetentionMultiplierCap = 3.4
U4.Titles = {
	OwnerUserIds = { [767108248] = true }, -- the owner (2026-09-26); the game creator (user or group rank 255) is Owner anyway
	OwnerGroupRank = 255,
	-- 2026-09-26 (owner): Gekkoh (767108248) is no longer forced to DEV: he owns OWNER (above)
	-- and wears whatever he picks in the Titles panel (or none), overhead and in chat.
	DeveloperUserIds = { [111827288] = true },
	TesterUsernames = { himothy09871 = true, realwhisper0909 = true, jay_1231600 = true, fabbyy_yt = true,
		dripreeper = true, techssasinbadass = true, supermangolflow = true }, -- player.Name (unique), never DisplayName
	ContentCreatorUserIds = {},
	MaxOwned = 40, NoticeAfterSessionSeconds = 600,
}
U4.Community = { Codes = { "speedfam" }, CodeStoreName = "SpeedsterCommunityCode_v1", CodeStoreKey = "active",
	CodeCacheSeconds = 300, GroupId = 771624731, SpeedPotionMinutes = 30, SpinTickets = 3, TitleId = "member",
	MaxWrongPerMinute = 5 }
U4.StaminaPass = { GamePassId = 1998458598, GiftProductId = 0, PriceRobux = 149, RegenMultiplier = 2, DelayScale = 0.5,
	HintAfterEmpties = 3, HintMinSessionSeconds = 600, HintSeconds = 6 }

return U4
