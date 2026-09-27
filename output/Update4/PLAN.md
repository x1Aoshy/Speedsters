# Update 4 — Plan de implementación unificado (lead merge, 2026-09-25)

Proyecto: `C:\Users\Aoshy´\Desktop\Update2` (src/common → los 3 places; src/worlds/WorldN → cada place).
Places: `World1Update3New.rbxl`, `World2Update3new.rbxl`, `World3Update3New.rbxl` (live = build 09-22; src lleva además 18 ficheros P0 del 09-24, backup en `output/FableRetentionP0_20260924/backup_src`).
Line numbers = src del 2026-09-25. Nothing in this plan has been applied; the places are **not** rebuilt until the owner says so.

Merged from 6 designs: race-core, race-feel, race-map-ui, retention-features, p0-remainder, build-perf-funnels. Conflicts are resolved in §1; the single contract (config, remotes, attributes, profile, funnels) is §2; workstreams are §4; integrator tasks are §5.

---

## 0. Resumen (qué entra y qué NO entra)

**Entra**
1. **P0 pendientes** (2 workstreams): H3 (lock de SessionActor), H5 (rewind W1), H6 (muertes solo-cliente), M50 (dial de velocidad), M14/M15 (Daily), M33 (misiones), H10 (MovementGuard Observe).
2. **Racing**: una pista recta de 2000 studs, idéntica en los 3 worlds, en `(6000, 12000, 0)` (fuera de streaming del lobby → FPS en móvil). Velocidad normalizada (no depende de World2/3 walk x0.5/x0.25; stats dan como máximo +6%). Mini-juego de carga con stamina (Perfect/Good/Ok/Stall), sprint con pool propio, pinchos que frenan (nunca matan), poses R6 procedurales (Flash crouch / run / super), burbuja Glass del owner (`BubbleModule`) + chispas/rayos estilo Vegeta, HUD propio (referencias 2.webp / 3.png), podio en vivo, resultados, "Race again", leaderboard all-time (tablero en lobby) + semanal (panel), admin event **Mega Race**.
3. **Titles** (equip/unequip; Owner/Developer/Content Creator/Tester, Top 1/5/10 Speed/Wins/Race, títulos de carrera, Member, Streak, VIP) con el panel del diseñador.
4. **Playtime Boost** (+10 % cada 10 min, máx +100 %) y **Streak Rewards** (+10 %/día, máx +100 %, hitos 7/14/21) con los paneles del diseñador.
5. **Community Reward** (Discord, con PolicyService; alternativa grupo Roblox) con el panel del diseñador.
6. **Gamepass 2x Stamina Regen** (oculto mientras no exista el id).
7. **7 funnels + ~15 custom events**, kill-switch por feature (`Workspace.U4Off_<Feature>`), build con guardas.

**Cortado (scope creep)**: Top 500 title y lecturas extra, títulos "Robux supporter", A/B holdout por porcentaje, spectate, carrera por lanes con colisiones, nueva moneda de carrera, puerto del `LightningBolt` de Steal a Hero (es un decompile de terceros), prefabs .rbxm de la UI de carrera (se construye en runtime con un builder Lune-compatible), buff card nueva en MainHUD (se usa icono de topbar), rotación HMAC de códigos Discord (espera a los detalles del owner).

---

## 1. Decisiones que resuelven los conflictos entre diseños

| Tema | Opciones en los diseños | Decisión |
|---|---|---|
| Ubicación de la pista | race-core: por world a altura de lobby (x 2600/1400); map-ui: `(6000,12000,0)` igual en todos; build-perf: ≥400 studs de stages | **`(6000, 12000, 0)` en los 3 worlds**, forward = **-Z**. ≥3700 studs (XZ) de todo mapa, así MovementGuard (distancia XZ a stages, 170) nunca avanza progreso y el lobby se descarga por streaming. y=12000 es float32-seguro (~0.001 stud). |
| Longitud | 2000 (race-core, ~36 s) vs 3000 (map-ui) | **2000 studs** + run-out 120. Carrera 35-40 s, ciclo ~80 s. |
| Geometría | race-core 64 ancho/spike grid; map-ui 72 ancho, 8 lanes, filas que bloquean 4 lanes | **map-ui** (72, 8 lanes, filas alternas siempre con carril libre) con **4 campos** a s0 = 300/750/1200/1650; penalización de race-core (x0.35, 0.7 s stumble). |
| Modelo de velocidad | race-core (cruise 50·(1+b), sprint x1.4, pool propio) vs build-perf (curva comprimida) vs race-feel (stamina normal) | **race-core**: `Vc = 50·(1+b)`, `b ≤ 0.06`, sprint `x1.4`, **pool de stamina de carrera 0..1** igual para todos, independiente de la barra normal y del world. |
| Salida | race-core (charge meter, launch, x1.12) vs race-feel (edges acumulativos, Perfect/Good/Ok/Stall) vs build-perf (Perfect/Good/Weak/FalseStart) | **race-feel** (`RaceChargeMath`, juez por edges con reloj del servidor); el coste sale del **pool de carrera** (0.15/s sostenido); launch `v0 = Vc·Launch[grade]` + `StartMultiplier(grade, τ)`. |
| Sprint en carrera | race-core: remote `RaceSprint` + BoostState ignorado; race-feel: IsBoosting | **race-core**: `RaceSprint` (LatestStateLimiter). `BoostState` fuerza `false` mientras `RaceActive`. |
| Unidad HUD | MPH=studs/s (race-core) vs ×0.6818 | `Update4Config.Race.Hud.MphPerStud = 1` ("MPH: 70 / 70"). |
| Estado del jugador | `RaceQueued/RaceActive` vs `RaceState` vs `InRace` | **`RaceState`** (`""`/`Queued`/`Staged`/`Racing`/`Finished`) + **`RaceActive`** (bool, único guard que leen los demás sistemas) + `RaceMovementLocked`. |
| Remotes | RaceRequest/RaceSprint/RaceCharge/RaceEvent/RaceLive vs RaceStandings/RaceResult vs RaceState | `RaceRequest`, `RaceSprint`, `RaceChargeInput`, `RaceEvent`, `RaceLive` (§2.3). |
| Recompensas | race-core (share de LapWins, field, daily x2, cap horario) vs build-perf (≤0.8 lap rate) | **race-core** (≈2 laps/h máx. para un ganador perpetuo; media ≈1.3). |
| Leaderboard | race-core: stores propios, NO categoría Global (rompe binder) vs map-ui: 4ª categoría con partes Race_* | Stores propios **all-time + semanal (ms)** escritos por `RaceLeaderboard`; tablero de lobby = categoría **"Race" opcional** en GlobalLeaderboards (`Optional=true`: si faltan las partes no rompe los otros 3), `Ascending=true`, `ExternalWrites=true`. |
| Persistencia | `RaceStats`, `RetentionState`, `Settings.TitlePreference` sueltos vs campo `U4` con secciones | **Un campo `U4`** en el perfil con secciones (`Race`, `Retention`, `Titles`, `Community`), dispatcher `Update4Profile` (integrador), una sección por workstream. Comandos `U4.<Sección>.<Op>`. |
| Timers persistentes | `SetRetentionPlaytime` específico vs commit por tier | **`DataService.ApplyVolatile(handle, command)`** genérico (en memoria, sin escritura; lo persiste el autosave de 30 s y el Release) para `U4.Retention.Playtime` y `U4.Titles.SetPref`. Lo implementa p0_data (dueño de SessionActor). |
| Multiplicador retención | aditivo con cap 4.5 vs cap 2.5 | **Aditivo**: `min(3.4, 1 + playtime + streak + perk)`; perk permanente +0.2 (día 7) / +0.4 (día 14) como dice el diseñador ("x1.2 Speed"). Multiplica solo ganancias de correr/treadmill; 1 dentro de carrera. Pregunta al owner. |
| Dónde se ve Playtime/Streak | buff card en MainHUD (Count 4) vs chips | **Iconos TopbarPlus a la izquierda** (Streak "🔥N", Playtime "+30%", Titles, Community) → sin tocar MainHUD ni HudErgonomics.BoostCards. |
| Títulos de staff | Config.IsDeveloper (acepta DisplayName → suplantable) | Títulos por **UserId o Username (Name)**, nunca DisplayName; el integrador además quita DisplayName de `Config.IsDeveloper/IsTester`. |
| Admin event | MegaRace vs RaceRush | **MegaRace** (x2 recompensas, 16 corredores, empieza ya, invita a todos, global por el publish existente). |
| Test runner | run_fable_checks tiene 50 entradas | **`audit/run_update4_checks.luau`** nuevo. |
| Death claim remote (H6) | creado en Bootstrap | Lo crea `LocalDeathArbiter.server.luau` (evita tocar Bootstrap). |
| Burbuja | módulo byte-idéntico vs `return Part` | `src/common/ReplicatedStorage/BubbleModule.luau` **byte-idéntico** al rbxm; el Mesh lo inserta el build; RaceVfx usa pool de clones del Mesh, no llama `CreateBubble` en caliente. |
| Charge gauge | anillo en botón (race-feel) vs barra en HUD (map-ui) | Táctil: **anillo** alrededor del botón de acción (junto al salto); PC/consola: **barra** encima de la barra de MPH. Zonas de `RaceChargeMath`. |

---

## 2. Contrato único

### 2.1 `Shared/Update4Config.luau` (integrador lo crea primero; todos programan contra él)

Pure module: no `require`, no `game` access at require time (Lune-safe). Full content:

```lua
--!strict
-- ReplicatedStorage/Shared/Update4Config.luau — every Update 4 tunable. Pure data + IsOn.
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
	-- Lobby Race Gate pad (race-core probes; test_u4_race_placement must confirm).
	Gate = {
		World1 = { Position = Vector3.new(400, 37467.69, -1845), Face = Vector3.new(400, 37467.69, -1781) },
		World2 = { Position = Vector3.new(-845, 36626.65, -1005), Face = Vector3.new(-784, 36626.65, -1005) },
		World3 = { Position = Vector3.new(145.6, 95.61, 585.5), Face = Vector3.new(265.3, 95.61, 521.6) },
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
	OwnerUserIds = {}, -- owner to confirm (see questions); the game creator (user or group rank 255) is Owner anyway
	OwnerGroupRank = 255,
	DeveloperUserIds = { [767108248] = true, [111827288] = true },
	TesterUsernames = { himothy09871 = true, realwhisper0909 = true, jay_1231600 = true, fabbyy_yt = true,
		dripreeper = true, techssasinbadass = true, supermangolflow = true }, -- player.Name (unique), never DisplayName
	ContentCreatorUserIds = {},
	MaxOwned = 40, NoticeAfterSessionSeconds = 600,
}
U4.Community = { Codes = { "speedfam" }, CodeStoreName = "SpeedsterCommunityCode_v1", CodeStoreKey = "active",
	CodeCacheSeconds = 300, GroupId = 771624731, SpeedPotionMinutes = 30, SpinTickets = 3, TitleId = "member",
	MaxWrongPerMinute = 5 }
U4.StaminaPass = { GamePassId = 0, GiftProductId = 0, PriceRobux = 149, RegenMultiplier = 2, DelayScale = 0.5,
	HintAfterEmpties = 3, HintMinSessionSeconds = 600, HintSeconds = 6 }

return U4
```

### 2.2 Perfil: campo `U4` (codec version sigue 306)

```
U4 = { V = 1,
  Race      = { BestMs, WeekId, WeekBestMs, Races, Finishes, Wins, Podiums, Perfects, DayId, HourStart, HourCount },  -- ints; BestMs 0 = none else 30000..600000
  Retention = { StreakDays, StreakLastDay, StreakBest, StreakGraceDay, StreakPerk (0..0.4),
                StreakPending {≤6 strings "c<cycle>_d<7|14|21>"}, StreakClaimed {≤64 strings},
                PlaytimeSeconds (0..6000), PlaytimeLastSeen (unix), PlaytimeSessionStart (unix) },
  Titles    = { Pref = "" | "none" | "<id>"  (≤32 chars, ^[a-z0-9_]*$), Owned = { ≤40 ids } },
  Community = { Claimed = bool, At = int },
}
```
- Section module contract (`Services/Data/U4/<Name>Section.luau`, pure, dual-require like ProfileReducers:5-7):
  `Default() -> table`, `Sanitize(raw) -> table` (never throws; wrong types/NaN/overlong lists cleaned), `Encode(t) -> table` (plain copy), `Apply(state, op, command, now) -> {ok=true,value=any} | {ok=false,error={code="InvalidInput",message=...,retryable=false}}`.
- Commands (kind strings), dispatched by `Update4Profile.Apply`:
  - `U4.Race.Record {finished, place (0..24), field (1..24), timeMs, rewarded, dayId, weekId, perfect}`
  - `U4.Retention.CheckIn {day}` · `U4.Retention.ClaimStreak {key}` · `U4.Retention.Playtime {seconds, lastSeen, sessionStart}` (**volatile**)
  - `U4.Titles.Grant {id}` · `U4.Titles.Revoke {id}` · `U4.Titles.SetPref {pref}` (**volatile**)
  - `U4.Community.Claim {at}`
- Volatile whitelist (`DataService.ApplyVolatile`): `U4.Retention.Playtime`, `U4.Titles.SetPref` only.
- Operation ids: race `race:<JobId>:<raceId>:<userId>`; streak check-in `u4streak:<utcDay>`; claim `u4streakclaim:<key>`; title `u4title:<id>`; community `u4community:v1`.

### 2.3 Remotes (all in `ReplicatedStorage.Remotes`, created by the owning service with an ensureRemote helper)

| Remote | Type | Dir | Payload | Guard | Owner |
|---|---|---|---|---|---|
| `RaceRequest` | RemoteEvent | C→S | `("Join", source)` source ∈ `"Hud"`,`"Invite"`,`"Results"`,`"Panel"`,`"Gate"`; `("Leave")`; `("AutoRequeue", bool)`; `("Board")` | RemoteGuard 0.25 s | race_server |
| `RaceSprint` | RemoteEvent | C→S | `(on: boolean)` | LatestStateLimiter 0.05 | race_server |
| `RaceChargeInput` | RemoteEvent | C→S | `(raceId: number, edges: {number}, final: boolean)` cumulative server-clock times, odd = press, even = release | LatestStateLimiter 0.08 | race_server |
| `RaceEvent` | RemoteEvent | S→C | `{kind=...}` see below | — | race_server |
| `RaceLive` | UnreliableRemoteEvent | S→racers+queued | 4 Hz `{id, t, left, n, top={{u=userId,s=dist,f=finishMs?}}×≤3, you={place,s,pool,strikes}}` | — | race_server |
| `TitlesRequest` / `TitlesUpdate` | RemoteEvent | C→S / S→C | `("Get")`,`("Equip", pref)`,`("Seen")` / `{Owned, Equipped, Preference, Ranks={Speed,Wins,Race}, Progress, New}` | RemoteGuard 0.3 s | titles_boards |
| `RetentionRequest` / `RetentionUpdate` | RemoteEvent | C→S / S→C | `("Get")`,`("ClaimStreak")` / `{Streak={Days,Best,Perk,CycleDay,Cycle,NextDayUnix,Pending,Claimed}, Playtime={Seconds,Anchor,Pct}, Multiplier, Message?}` | RemoteGuard 0.5 s | retention |
| `CommunityRewardRequest` / `CommunityRewardUpdate` | RemoteEvent | C→S / S→C | `("Get")`,`("Redeem", code)`,`("VerifyGroup")` / `{DiscordAllowed, Claimed, GroupId, Success?, Message?, Rewards}` | RemoteGuard 1 s + 5 wrong/min | community_pass_admin |
| `LocalDeathClaim` | RemoteEvent | C→S | `(hitPart: BasePart?, clientServerTime: number?)` | 0.5 s + 1 decision/character | p0_gameplay |
| `FunnelReport` (existing) | | C→S | new client steps: `Onboarding_Race` 1, `Monetization_StaminaPass` 0-2 | existing | integrator |

`RaceEvent` kinds: `Queued{source}`, `Unqueued{reason}`, `Staged{slot, raceId, goAt, cruise, sprint, sprintSeconds, regenFactor}`, `Start{grade}`, `Stumble{untilT}`, `Correction{s, v}`, `Finished{place, timeMs, pb}`, `Results{podium={{UserId,Name,Place,TimeMs?,Wins}}, you={Place,Finished,TimeMs,Wins,Speed,Tickets,PB,WeeklyPB,Outcome,CapReduced,Multiplier}}`, `Board{weekly={{UserId,Name,Ms}}, allTime=..., you={bestMs,weekBestMs,weeklyRank,allTimeRank}}`, `Toast{key,args}`, `Invite{endsAt,count,mega}`.

### 2.4 Atributos

**Workspace** (race_server): `RacePhase` (`Idle`|`Gathering`|`Staging`|`Countdown`|`Running`|`Results`|`Cooldown`), `RacePhaseEndsAt`, `RaceGoAt`, `RaceId`, `RaceQueueCount`, `RaceRacerCount`, `RaceMaxPlayers`, `RaceEventUntil`, `RaceEventMultiplier`, `RaceEventBy`, `RaceRecordMs`, `RaceRecordName`. Kill switches `U4Off_<Feature>` (admin/Studio).
Derived times: Set pose from `RaceGoAt - 3.5`; charge window opens `RaceGoAt - 3.0`; scoring window last 1.5 s.

**Player (server-set)**
- Race: `RaceState`, `RaceActive`, `RaceMovementLocked`, `RaceSlot`, `RaceAutoRequeue`, `RaceCruiseSpeed`, `RaceSprintSpeed`, `RaceSprintSeconds`, `RaceRegenFactor`, `RaceStatBonus`, `RaceRewardMultiplier`, `RaceChargeLevel` (0..10, ≤4 Hz, Countdown only), `RaceStartGrade` (`Perfect`|`Good`|`Ok`|`Stall`), `RaceSuperSpeed` (bool), `RaceFinishMs`, `RacePlace`, `RaceBestMs`, `RaceWeekBestMs`, `RaceWins`, `RaceFinishes`, `RaceWeeklyRank`, `RaceAllTimeRank`.
- Titles: `EquippedTitle`, `TitlesNewCount`, `TitlePreference`.
- Retention: `PlaytimeBoostPct`, `PlaytimeSessionAnchor` (server time), `StreakDays`, `StreakPerk`, `StreakRewardPending`, `StreakNextDayUnix`, `RetentionSpeedGainMultiplier` (1..3.4).
- Community: `CommunityDiscordAllowed`, `CommunityRewardClaimed`. Pass: `StaminaRegen2xOwned`.
- P0: `DailyCanClaim`, `ArrivedByTeleport`, `DataSaveRetrying`; `DataLoaded` also true in `Recovering`.

**Local-only (client SetAttribute, never replicated)**: player `RaceLocalSpeed` (walk speed the movement controller must use), `RaceChargeLocal` (0..1), `RaceStaminaLocal` (0..1), `RaceLocalSuper` (bool), `RaceFovTarget` (number or nil); character `RacePosed` (bool).

**PlayerTitlePart**: `TitleId`, `TitleStyle` (`typewriter`|`shine`|`static`), `TitleText`.

**Arena parts**: `RaceArenaPart`, `RaceSpikeTile`, tag `RaceDecorLowPower`; named `RaceArena.Structure.StartGate`, `StopBar`, `StartGantry.Light1..5`, `RaceOrb`; model attribute `RaceArenaVersion = 1`.

### 2.5 Globals

- `_G.SpeedsterRace = { Join(player, source), Leave(player, reason), IsRacing(player), StartMegaEvent(durationSeconds, byName), StopMegaEvent() }` (race_server).
- `_G.SpeedsterTitles = { Refresh(player), Grant(player, id, source) -> boolean, Revoke(player, id), Visual(player) -> {Id, Template, Text, Style, Color1, Color2}? }` (titles_boards). Bootstrap reads `Visual`.
- `_G.SpeedsterRedeemCommunityCode(player, code) -> ok, message` (community_pass_admin; CodesSystem routes to it).
- `_G.SpeedsterOverruledRevive(player, stage)`, `_G.SpeedsterHazardPoseAt(part, serverTime)`, `_G.VortexMovementGuardRebase(player, target, source?)` (p0_gameplay).
- `StageTeleportService.ArmArrivalGrace(player)` (new export by race_server).

### 2.6 Funnels (integrator edits `Services/FunnelAnalytics.luau`)

| Logical funnel | Steps | Recurring / session | Route (Creator Hub) | Sequencing | Reported by |
|---|---|---|---|---|---|
| `Engagement_Race` | 1 Race_Queued, 2 Race_Started, 3 Race_Finished, 4 Race_Rewarded | yes; new session per queue join | `Race_Loop_v2` 1-4 (Queued/Started/Finished/Rewarded) | step n needs had(n-1) | race_server |
| `Onboarding_Race` | 1 Race_Discovered, 2 Race_FirstQueued, 3 Race_FirstCharged, 4 Race_FirstFinished, 5 Race_SecondRace | one-time | `Race_FirstRace_v2` 1-5 | had(n-1); step 1 refused if `RaceFinishes > 0` | 1 client (ClientSteps), 2-5 race_server |
| `Retention_Streak` | 1 Streak_CheckedIn, 2 Streak_PanelOpened, 3 Streak_MilestoneClaimed | yes; session `"<uid>-streak-<utcDay>"` | `Streak_Daily_v2` | 2 needs 1, 3 needs 2 | retention |
| `Retention_PlaytimeBoost` | 1 Playtime_10m, 2 Playtime_30m, 3 Playtime_60m, 4 Playtime_Max | yes; session passed explicitly `"<uid>-pt-<PlaytimeSessionStart>"` | `Playtime_Session_v2` | none | retention |
| `Engagement_Titles` | 1 Titles_Opened, 2 Titles_Equipped | yes; per open | `Titles_Equip_v2` | 2 needs 1 | titles_boards |
| `Community_Reward` | 1 Community_Opened, 2 Community_RedeemTried, 3 Community_Claimed | one-time | `Community_Redeem_v2` | 2 needs 1, 3 needs 2 | community_pass_admin |
| `Monetization_StaminaPass` | [0] OfferVisible, [1] Clicked, [2] PromptShown, [3] Purchased | one-time | `StaminaPass_OfferToBuy_v2` 1-4 + `StaminaPass_Ownership_v2` on 3 | like StarterPack | 0-2 client, 3 server |

Custom events via new `FunnelAnalytics.Event(player, name, value?, fields?)` (whitelisted, pcall, own thread): `Race_Join_Gate_v2`, `Race_Join_Hud_v2`, `Race_Join_Invite_v2`, `Race_Join_Results_v2`, `Race_Join_Panel_v2`, `Race_Requeued_v2`, `Race_MegaJoined_v2`, `Race_StartPerfect_v2`, `Race_StartStall_v2`, `Race_Correction_v2`, `Streak_Day7_v2`, `Streak_Day14_v2`, `Streak_Day21_v2`, `Streak_Reset_v2`, `StaminaPass_Ownership_v2`, `LocalDeath_Kill_v2`, `LocalDeath_Revive_v2`, `MG_StrictPass_v2`, `MG_StrictWouldReject_v2`. Server callers load FunnelAnalytics with the exact pcall loader string of QuestService.server.luau:25-33.

---

## 3. Diseño por feature (resumen técnico; el detalle ejecutable está en cada workstream §4)

### 3.1 Carrera — ciclo
`Idle → Gathering (20 s; 5 s si lleno; Mega 30 s) → Staging (3 s: RequestStreamAroundAsync(slot, 5) + PivotTo + Rebase) → Countdown (5 s; Set pose en GoAt-3.5; carga en GoAt-3.0) → Running (≤60 s; +15 s gracia tras el 1º) → Results (7 s) → Cooldown (8 s) → Gathering|Idle`.
1 jugador en cola 25 s → **Time Trial** en solitario (recompensa "finisher" × field 0.5). Joins: pad de Race Gate (lobby), botón HUD, invitación, "Race again", panel. Rechazado si `DataLoaded≠true`, `FirstTimeTutorialSeen≠true and Rebirths<1`, `AfkModeActive`, muerto, ya en cola, feature off.
Salida: `PivotTo` al punto capturado (último suelo firme, 2 Hz mientras está en cola) + `MovementGuard.Rebase(progress capturado)` + `ArmArrivalGrace`; joins por pad → spawn normal.

### 3.2 Carrera — velocidad (RaceMath, pura, cliente+servidor)
- `b = 0.06·(1 − e^(−log10(1+RawSpeed)/6))` → 1.7 % (1e2) … 5.5 % (1e15).
- `Vc = 50·(1+b)`, `Vs = 1.4·Vc`; `v ← Vt + (v−Vt)·e^(−dt/τ)` (τ 1.6 subir / 0.8 bajar); input fuera de 70° del heading → objetivo 0.
- Pool 0..1: sprint seconds `4·(1+0.25·clamp((SuitStaminaMax−5)/65,0,1))` (4.0 Flash … 5.0 Silver Surfer); drenaje `1/sprintSeconds` por s solo si v > 0.5·Vc; regen 0.12/s tras 0.8 s × `PassRegenFactor` (1.0); sprint necesita pool ≥ 0.10; cada salto −0.06.
- Salida: `v0 = Vc·Launch[grade]` (0.8/0.5/0.2/0) y objetivo × `StartMultiplier(grade, τ)` (Perfect 1.45 hasta 1.2 s → 1.0 en 2.5 s; Good 1.22 → 1.0 en 2.0 s; Stall 0 hasta 0.45 s, luego rampa a 1 en 0.8 s).
- Pinchos: `v ← 0.35·v`, stumble 0.7 s (sin sprint, objetivo 0.5·Vc), inmune 0.9 s. Hit si `|dx| ≤ 7/2 − 0.5 + 1` y `|ds| ≤ 4.0` y `y < 0.4 + 3` (se pueden saltar).
- Simulación (race-core sim.py): novato 36.5 s, endgame 35.2 s, salida perfecta ≈ −1 s, pincho +1.2 s → la habilidad pesa 3-6 s, los stats ≤1.35 s. `MinPlausibleMs = 30000`.

### 3.3 Carrera — autoridad y anti-cheat
Servidor muestrea a 20 Hz, integra el mismo `RaceMath.Step` asumiendo input perfecto con **su** pool, **su** sprint (RaceSprint) y **su** grade (asume Perfect hasta juzgar). Envolvente `sAllowed = s_env·1.06 + 10 + 0.3·v_env`; ventana de 0.5 s ≤ `Vs·1.288`. Violación → PivotTo atrás + `_G.VortexMovementGuardRebase(player, nil)` + strike; 3 strikes = DQ (sin premio ni PB). Falsa salida (s > 1.5 antes de GO+0.1) → vuelta al slot + 0.3 s. Caída (y < −25) → recolocar + stumble. Fuera de corredor → DNF "Left". Tiempo final interpolado entre muestras − `clamp(ping·500, 0, 120)` ms.

### 3.4 Carrera — recompensas (una sola `DataService.Commit` por corredor)
```
field    = clamp(0.4 + 0.1·N, 0.5, 1.0)
lap      = Config.SpinWheel.LapWins[world]            -- 1,157,020 / W2 / W3
progress = World1: min(1, ((Rebirths+1)/(Config.World2UnlockRebirths+1))^2) ; else 1
shareW   = place 1/2/3: 0.06/0.04/0.03 ; other finisher 0.015 ; DNF ≥25%: 0.005 ; else/DQ 0 ; solo uses finisher
event    = RaceEventMultiplier (2) while Workspace.RaceEventUntil > os.time() else 1
daily    = 2 on the first rewarded race of the UTC day (+1 Spin Ticket)
cap      = 1 if HourCount < 30 in the rolling hour else 0.25
wins     = floor(floor(lap·progress·shareW·field·event·daily·cap) · _G.SpeedsterGetWinsMultiplier(player))
speed    = floor(max(AfkZone.SpeedFloor, RawSpeed·AfkZone.SpeedShare)·minutes·field·event·daily·cap) ≤ 0.05·RawSpeed + 2000
```
Commands: `GrantExact Wins`, `GrantExact Speed`, `GrantSpinTickets` (daily), `U4.Race.Record`, `U4.Titles.Grant` (títulos de carrera nuevos) — op id `race:<JobId>:<raceId>:<uid>`, reintento Pending ≤5×1 s.

### 3.5 Pista (RaceArenaBuilder, Lune + runtime fallback) y tablero
Estructura Persistent (suelos 120 studs, muros invisibles 16 alto en x ±38.1, StartGate, muro final); decoración Atomic en chunks de 240; spike tiles 7×0.4×7 + estrella de 2 piezas negras; STOP bar roja con SurfaceGui "STOP STOP"; pórtico de salida con 5 luces; pórticos de distancia 500/1000/1500 + "LAST 200!" 1800; meta a cuadros en 2000; ORB (Neon + ForceField) en s 2060, y 34. Texturas: stud 6794250394 + chevron (id del owner o chevrones de partes con tag `RaceDecorLowPower`). ≤330 partes (texture mode), ≤600 (fallback). Todo Anchored, CastShadow=false. Build lo inserta en los 3 places; en runtime se construye si falta.
Tablero "FASTEST RACERS": el build clona las 8 MeshParts de Wins de `leaderboard1` como `Race_*` (W1/W3 tras Wins, W2 tras Robux) — categoría "Race" opcional de GlobalLeaderboards.

### 3.6 HUD y UX de carrera
- RaceHud (DisplayOrder 60): cuenta atrás ("STARTING: 3s" + número grande, "GO!"), barra "MPH: v / Vs" con "Multiplier: xN" y "MPH/s: +a", barra de stamina del pool, charge gauge (barra en PC/consola; anillo en táctil), podio top-left en vivo (headshots, oro/plata/bronce, recompensa morada), "You · 7th/12", ORB distancia + tiempo a la derecha, botón táctil CHARGE/BOOST junto al salto (salto oculto solo en Set), feedback ("PERFECT START! +45%", "OUCH! SPIKES").
- Resultados (BlockyWindow 640×420): puesto, tiempo, NEW BEST, mini-podio, recompensas, **RACE AGAIN** (auto-requeue por defecto) / **LOBBY (8)**.
- Lobby: botón "RACE" top-left con estado (timer / JOIN! / IN QUEUE / LIVE), invitación toast durante Gathering (≤1 cada 300 s, nunca en tutorial, AFK, menús abiertos), panel Race (join + recompensas + top 50 semanal/all-time).
- InterfaceHider oculta el HUD normal durante la carrera y conserva `TouchGui` (joystick/salto).
- Localización: `Shared/RaceText` (10 idiomas vía TutorialText.LanguageFor/Style).

### 3.7 Feel (poses, carga, VFX)
Poses R6 procedurales (`RacePose`: Set crouch Flash, Run, Super) aplicadas en `Stepped` con `SurfboardStance.Transform`; otros corredores vía atributos replicados (sin tráfico por frame). VFX (`RaceVfx`, pools, sin Instance.new tras prewarm): chispas/núcleo en manos (texturas built-in sparkles_main/fire_main como Vegeta), burst en GO, arcos Neon (técnica de SonicBurst), burbuja Glass (High) / ForceField (Mid) / nada (Low) al entrar en super-velocidad. Tiers por `RaceFeelTier` (touch-only <30 FPS = Low). Sonidos solo con ids ya autorizados.

### 3.8 Titles, Playtime, Streak, Community, Pass
Ver workstreams titles_boards, retention, community_pass_admin (§4). Popups: la cadena de entrada sigue UpdateLogs → Daily; única auto-apertura nueva: Streak tras cerrar Daily **solo** si hay un hito pendiente. Todo lo demás son toasts (TemporaryBoostUpdate Type "Retention") y notice dots.

### 3.9 Presupuestos
- Servidor: bucle de carrera solo fuera de Idle; muestreo 20 Hz ≤24 corredores; ≤1 ms/tick. Retención: bucle de 5 s; ranks cada 60 s (refresh existente).
- DataStore: 1 commit por corredor por carrera; 1 check-in por jugador por día; playtime/título-pref en memoria (autosave); PB: ≤20 escrituras por 30 s (min-only UpdateAsync); lecturas de tableros cada 120 s.
- Cliente: ≤2 handlers por frame nuevos por sistema y solo conectados en carrera; LOD de poses/VFX; arena aislada del lobby por streaming; aceptación: render time ≤ +10 % vs lobby con 12 corredores en emulación de móvil.

---

## 4. Workstreams (propiedad de ficheros disjunta)

| key | Título | Crea | Cambia | Depende de |
|---|---|---|---|---|
| p0_data | P0 datos: H3 + ApplyVolatile, M14/M15 Daily, M33 misiones | Shared/QuestPeriod.luau, audit/test_retention_p1_data.luau | SessionActor, DataService, StatsProjection, DailyRewardsData, DailyRewards, DailyLoginSystem, UpdateLogsController, QuestCatalog, QuestService | — |
| p0_gameplay | P0 juego: H5, H6, M50, H10 | PoseHistory, HazardNames, LocalDeathRules, LocalDeathArbiter, audit/test_retention_p1_gameplay.luau | NewWorld1ServerMotion, NewWorld1MapSystems, NewWorld1MapMotion, R15SpeedsterRun, SpeedProductPurchases, HudErgonomics, WalkSpeedSelector, CharacterStatsAdapter, MovementGuard, 3 pads, World2SafeZones | — |
| race_server | Núcleo de carrera | RaceMath, RaceChargeMath, RaceTrack, Services/Race/*, Gameplay/RaceServer.server, U4/RaceSection, tests | SonicBurstService, FlightService, AfkZoneService, StageTeleportService | integrator phase 0 |
| race_client | HUD, input, movimiento, lobby | RaceHudLayout, RaceUiKit, RaceUiBuilder, RaceText, Race/RaceInputClient, UI/RaceHudController, UI/RaceLobbyController, Gameplay/RaceArenaVisuals, tests | InstantMovementController, SpeedsterClient, SonicBurstClient, InterfaceHider, LowPowerGraphics, test_fable_interface_hider | race_server (RaceMath/RaceChargeMath/RaceTrack APIs) |
| race_fx | Poses R6 + VFX + burbuja | ReplicatedStorage/BubbleModule.luau, RacePose, RaceVfx, RaceFeelTier, Race/RacePoseClient, tests | SupermanFlight, SurfboardPose | race_server (RaceTrack/RaceMath read-only) |
| titles_boards | Títulos + tableros | TitleCatalog, Titles/TitleService, Social/TitleSystem.server, UI/TitlesController, U4/TitlesSection, audit/u4_title_templates.luau, audit/u4_race_board.luau, tests | OverheadStats, GlobalLeaderboards, GlobalLeaderboardDisplay | integrator phase 0 |
| retention | Playtime Boost + Streak | RetentionMath, Social/RetentionService.server, UI/PlaytimeBoostController, UI/StreakRewardsController, U4/RetentionSection, tests | TopbarIconsController, DailyRewardController, BoostNotifier | integrator phase 0; p0_data (ApplyVolatile) |
| community_pass_admin | Community + 2x Stamina + Admin (Mega Race, títulos, pase) | Social/CommunityRewardService.server, UI/CommunityRewardsController, U4/CommunitySection, Economy/StaminaRegenPass.server, UI/StaminaPassHint.client, audit/u4_shop_card.luau, tests | CodesSystem, ShopController, AdminAbusePanelService, AdminAbusePanelController, test_admin_abuse_panel | integrator phase 0 |

El integrador (§5) es dueño de: Config.luau, Update4Config.luau (nuevo), Bootstrap.server.luau, ProfileCodec, ProfileReducers, Update4Profile.luau (nuevo), FunnelAnalytics, MainHUDController, MenuEvents, ModalJuice, ConsoleUiScale, StatsService, PlayerStatsBridge, fable_build_lib (dryRun), build_update4.luau, run_update4_checks.luau, test_funnel_analytics, test_u4_integration, design/ui/uineww.rbxm, design/vfx/BubbleModule.rbxm, src/manifest.json.

Las specs completas de cada workstream están en el JSON devuelto por el lead (campo `workstreams[].spec`) y replicadas en §7.

---

## 5. Tareas del integrador (exactas)

**Phase 0 (antes de que empiecen los workstreams)**
1. Crear `src/common/ReplicatedStorage/Shared/Update4Config.luau` con el contenido de §2.1.
2. Copiar `uineww.rbxm` → `design/ui/uineww.rbxm` y `BubbleModule (2).rbxm` → `design/vfx/BubbleModule.rbxm` (los originales no se tocan); anotar sus SHA-256 para el build.
3. Crear `src/common/ServerScriptService/Services/Data/Update4Profile.luau` (dispatcher, §5.A).
4. ProfileCodec + ProfileReducers wiring del campo `U4` (§5.B, §5.C) y el wiring de M33 (§5.D) contra `Shared/QuestPeriod.luau` (lo escribe p0_data; hasta entonces el wiring se guarda con `pcall(require)`).
5. FunnelAnalytics (§5.E), MenuEvents / ModalJuice / ConsoleUiScale / MainHUDController listas (§5.F).

**Phase 1 (tras merge de workstreams)**: Bootstrap (§5.G), StatsService + PlayerStatsBridge (§5.H), Config (§5.I), build + runner (§5.J), manifest.

### 5.A `Services/Data/Update4Profile.luau`
```lua
--!strict
-- Update 4 profile field U4: one dispatcher, one section module per feature (Services/Data/U4/*).
local Update4Profile = {}
local SECTION_NAMES = { "Race", "Retention", "Titles", "Community" }
local VOLATILE = { ["U4.Retention.Playtime"] = true, ["U4.Titles.SetPref"] = true }
local sections = {}
for _, name in SECTION_NAMES do
	local ok, mod = pcall(function()
		if typeof(script) == "Instance" and script.Parent then
			return require(script.Parent:WaitForChild("U4"):WaitForChild(name .. "Section", 5))
		end
		return require("./U4/" .. name .. "Section")
	end)
	if ok and type(mod) == "table" then sections[name] = mod end
end
local function reject(message) return { ok = false, error = { code = "InvalidInput", message = message, retryable = false } } end
function Update4Profile.Default()
	local u4 = { V = 1 }
	for name, mod in sections do u4[name] = mod.Default() end
	return u4
end
function Update4Profile.Sanitize(raw)
	local u4 = { V = 1 }
	for name, mod in sections do
		local ok, clean = pcall(mod.Sanitize, type(raw) == "table" and raw[name] or nil)
		u4[name] = if ok and type(clean) == "table" then clean else mod.Default()
	end
	return u4
end
function Update4Profile.Encode(u4)
	local out = { V = 1 }
	for name, mod in sections do
		out[name] = mod.Encode(type(u4) == "table" and type(u4[name]) == "table" and u4[name] or mod.Default())
	end
	return out
end
function Update4Profile.IsVolatile(kind) return VOLATILE[kind] == true end
function Update4Profile.Apply(profile, command, now)
	local section, op = string.match(command.kind, "^U4%.(%a+)%.(%a+)$")
	local mod = section and sections[section]
	if not mod then return reject("Unknown U4 command") end
	profile.U4 = profile.U4 or Update4Profile.Default()
	profile.U4[section] = profile.U4[section] or mod.Default()
	return mod.Apply(profile.U4[section], op, command, now)
end
return Update4Profile
```

### 5.B ProfileCodec (append before `return ProfileCodec`, after the extension wrapper at :746-782)
```lua
-- Update 4 (2026-09): the U4 field is a known field (not an Update2PreservedField).
local Update4Profile = if typeof(script) == "Instance" and script.Parent
	then require(script.Parent.Update4Profile) else require("./Update4Profile")
local decodeU3, encodeU3, defaultU3 = ProfileCodec.Decode, ProfileCodec.Encode, ProfileCodec.CreateDefault
function ProfileCodec.CreateDefault(...)
	local profile = defaultU3(...)
	profile.U4 = Update4Profile.Default()
	return profile
end
function ProfileCodec.Decode(raw, validator)
	local result = decodeU3(raw, validator)
	if result.ok then
		result.value.U4 = Update4Profile.Sanitize(type(raw) == "table" and raw.U4 or nil)
		if type(result.value.Update2PreservedFields) == "table" then result.value.Update2PreservedFields.U4 = nil end
	end
	return result
end
function ProfileCodec.Encode(profile)
	local encoded = encodeU3(profile)
	encoded.U4 = Update4Profile.Encode(profile.U4)
	return encoded
end
```
Also add `U4: any?` to the `ProfileV306` type (:88-132). Check `CreateDefault`'s real name/signature at :288 and wrap it exactly.

### 5.C ProfileReducers (append before `return ProfileReducers` at :715)
```lua
local Update4Profile = if typeof(script) == "Instance" and script.Parent
	then require(script.Parent.Update4Profile) else require("./Update4Profile")
local applyU3 = ProfileReducers.ApplyCommand
function ProfileReducers.ApplyCommand(profile, command, now)
	if type(command) == "table" and type(command.kind) == "string" and string.sub(command.kind, 1, 3) == "U4." then
		return Update4Profile.Apply(profile, command, now)
	end
	return applyU3(profile, command, now)
end
```

### 5.D M33 wiring (logic in `Shared/QuestPeriod.luau` from p0_data)
- ProfileReducers top: `local QuestPeriod = if typeof(script)=="Instance" then require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("QuestPeriod")) else require("../../../ReplicatedStorage/Shared/QuestPeriod")`.
- `QuestBucket` (:546-555): for `category == "Daily"` use `QuestPeriod.DailyPeriod(now)`; before replacing a Daily bucket call `QuestPeriod.FreezeCompletion(profile, bucket)`.
- `ChooseQuestPath` (:582): period check uses `QuestPeriod.DailyPeriod(now)`; first line of the branch `QuestPeriod.SaveLate(profile, now)`.
- `ClaimQuestPath` (:608): `local period = QuestPeriod.DailyPeriod(now)`.
- New branch in the same wrapper: `elseif command.kind == "ClaimLateQuestPath" then return QuestPeriod.ClaimLate(profile, command, now, ProfileReducers.QuestBucket)`.
- ProfileCodec `sanitizeQuestState` (:10-57): replace the inline Destiny cleaning with `state.Destiny = QuestPeriod.SanitizeDestiny(raw.Destiny)` and add `state.LateDestiny = QuestPeriod.SanitizeDestiny(raw.LateDestiny)` (both return nil for non-tables); QuestPeriod must keep all current fields plus `Complete`.

### 5.E FunnelAnalytics
Add to `Funnels` (:36-46): the 7 funnels of §2.6 (exact step names). `Recurring` (:48-54): `Engagement_Race`, `Retention_Streak`, `Retention_PlaytimeBoost`, `Engagement_Titles`. `ClientSteps` (:56): `Onboarding_Race = {[1]=true}`, `Monetization_StaminaPass = {[0]=true,[1]=true,[2]=true}`. `customEvents` (:118-129): every `_v2` custom of §2.6. `routes` (:135-191) per §2.6 (e.g. `Engagement_Race = {[1]={{"Race_Loop_v2",1,"Queued"}}, [2]={{"Race_Loop_v2",2,"Started"}}, [3]={{"Race_Loop_v2",3,"Finished"}}, [4]={{"Race_Loop_v2",4,"Rewarded"}}}`; `Monetization_StaminaPass[3] = {{"StaminaPass_OfferToBuy_v2",4,"OwnershipConfirmed"},{"StaminaPass_Ownership_v2",1,"OwnershipConfirmed"}}`). `NewSession` (:218-226): `Retention_Streak` → `"%d-streak-%d"` with `floor(os.time()/86400)`. Sequencing (`Step`, :262-285): `Engagement_Race`, `Onboarding_Race`, `Engagement_Titles`, `Community_Reward`, `Retention_Streak` step>first ⇒ `had(step-1)`; `Monetization_StaminaPass` like StarterPack; `Onboarding_Race` step 1 returns false when `player:GetAttribute("RaceFinishes")` > 0. New:
```lua
function FunnelAnalytics.Event(player, name, value, fields)
	if not customEvents[name] or not validPlayer(player) or not AnalyticsService then return false end
	task.spawn(function()
		pcall(function() AnalyticsService:LogCustomEvent(player, name, tonumber(value) or 1, fields) end)
	end)
	return true
end
```
Update `audit/test_funnel_analytics.luau` coverage list (new funnels; client whitelist only Onboarding_Race 1 and StaminaPass 0-2).

### 5.F Lists
- `MenuEvents.luau` MENU_EVENT_NAMES (:8-34): `Titles="OpenTitlesPanel"`, `Streak="OpenStreakPanel"`, `PlaytimeBoost="OpenPlaytimeBoostPanel"`, `Community="OpenCommunityPanel"`, `Race="OpenRacePanel"`. MENU_TO_GUI (:110): `Titles="Titles"`, `Streak="Streak Rewards"`, `PlaytimeBoost="Playtime Boost"`, `Community="Community rewards"`, `Race="RacePanelGui"`.
- `MainHUDController.client.luau` MODAL_SCREEN_GUIS (:2393-2413): `"Titles"`, `"Streak Rewards"`, `"Playtime Boost"`, `"Community rewards"`, `"RacePanelGui"`, `"RaceResults"`.
- `ModalJuice.luau` MODAL_MAIN_FRAMES (:15-30): `["Playtime Boost"]={"Playtime Boost"}`, `["Streak Rewards"]={"Streak Rewards"}`, `["Community rewards"]={"Community rewards"}`, `Titles={"Titles"}`, `RacePanelGui={"Window"}`, `RaceResults={"Window"}`.
- `ConsoleUiScale.client.luau` MANAGED_MENUS (:61-80): the same 6 names.

### 5.G Bootstrap.server.luau
1. Top: `local U4 = require(ReplicatedStorage.Shared.Update4Config)`.
2. BoostState handler (:256-262), after the flight line: `if player:GetAttribute("RaceActive") == true then wantsBoost = false end`.
3. Regen (:692-697): `local passOwned = player:GetAttribute("StaminaRegen2xOwned") == true and U4.IsOn("StaminaPass")`; `delaySeconds *= if passOwned then U4.StaminaPass.DelayScale else 1`; `regenPerSecond *= if passOwned then U4.StaminaPass.RegenMultiplier else 1`.
4. `attachTitleToCharacter` (:386-439): replace the template choice (:391-400) with
   ```lua
   local hook = (_G :: any).SpeedsterTitles
   local visual = if type(hook) == "table" and type(hook.Visual) == "function" then hook.Visual(targetPlayer) else nil
   local template = nil
   if visual then template = titlesFolder:FindFirstChild(visual.Template)
   elseif Config.IsDeveloper(targetPlayer) then template = titlesFolder:FindFirstChild("Dev")
   elseif Config.IsTester(targetPlayer) then template = titlesFolder:FindFirstChild("Tester") end
   if not template or not template:IsA("BasePart") then
   	local old = character:FindFirstChild("PlayerTitlePart"); if old then old:Destroy() end
   	return
   end
   ```
   After cloning: when `visual`, set `titlePart:SetAttribute("TitleId", visual.Id)`, `("TitleStyle", visual.Style)`, `("TitleText", visual.Text)`, set `BillboardGui.Title.Text = visual.Text` and its UIGradient to `ColorSequence.new(visual.Color1, visual.Color2)` when present; enable emitters only when `visual == nil or visual.Style ~= "static"`.
5. Next to the EquippedSkin hook (:450): `player:GetAttributeChangedSignal("EquippedTitle"):Connect(function() if player.Character then attachTitleToCharacter(player, player.Character) end end)`.

### 5.H StatsService + PlayerStatsBridge
- StatsService `GainMultipliers` type (:19-33): `retention: number?`; validation next to disco (:457-460): `local retention = if type(m.retention)=="number" and m.retention==m.retention then math.clamp(m.retention, 1, 10) else 1`; multiply into `gain` at :480.
- PlayerStatsBridge (:108-121): `retention = if player:GetAttribute("RaceActive") == true then 1 else (tonumber(player:GetAttribute("RetentionSpeedGainMultiplier")) or 1)`; same factor in `SpeedsterGetTotalGainMultiplier` (:153).

### 5.I Config.luau
- M50: after :950 `Config.WalkSpeedSelectorFloor = 16`, `Config.WalkSpeedSelectorFullBelow = 24`.
- H10: `Config.MovementGuardMode = "Observe"`.
- `IsTester`/`IsDeveloper` (:1255-1275): remove the DisplayName match (keep Name and UserId).

### 5.J Build, runner, manifest
- `audit/fable_build_lib.luau`: `options.dryRun` → return after the `prepared` loop (:145), skipping disk, manifest and validation writes (:148-163); still serialize + round-trip + verify.
- `audit/build_update4.luau` (pattern `build_fable_polish.luau:26-74`): BACKUP `output/FableRetentionP0_20260924/backup_src/`, OUTPUT `output/Update4_<yyyymmdd>`. Modes: `list`, `check` (dryRun), `p0` (only sources owned by p0_data/p0_gameplay + the 18 pending 09-24 files + Config), default (everything). Guards: `.rbxl.lock` present → refuse unless `--allow-locks`; SHA-256 of both design rbxm pinned; designer root = Folder `NewUI` with the 4 ScreenGuis and no LuaSourceContainer; `U4Asset` stamp: an asset of the same name without the stamp stops the build. `edit(key, dm, notes)`: (1) the 4 ScreenGuis into StarterGui with `Enabled=false`, `ResetOnSpawn=false`, `DisplayOrder=20`, `ZIndexBehavior=Sibling`, attr `U4Asset`; (2) `ReplicatedStorage.BubbleModule.Mesh` from the rbxm (Anchored, CanCollide/CanTouch/CanQuery/CastShadow false, Massless; Highlight kept disabled); (3) `Workspace.RaceArena` via `RaceArenaBuilder.Build(workspace, env)` and `Workspace.RaceGate` via `RaceArenaBuilder.BuildGate(workspace, worldKey, env)` (race_server; `env` = `@lune/roblox` constructors); (4) `require("./u4_race_board").Place(dm, worldKey, notes)` (titles_boards); (5) `require("./u4_title_templates").Insert(dm, notes)` (titles_boards); (6) `require("./u4_shop_card").Insert(dm, notes)` (community_pass_admin). `verify`: all of the above present in all 3 places after the round trip, ImageContent ids unchanged (33/33), arena ≥1500 studs from every other BasePart, part budget.
- `audit/run_update4_checks.luau`: same shape as run_fable_checks; lists every test named in §4 plus `test_u4_integration`, `test_funnel_analytics`, `test_retention_p0`, `test_new_persistence`.
- `audit/test_u4_integration.luau`: dispatcher (Default/Sanitize/Encode round trip, unknown kind rejected, volatile whitelist), codec (U4 not in Update2PreservedFields, old profile decodes), reducers (U4 routing, ClaimLateQuestPath wired), FunnelAnalytics (Event whitelist, new routes/sequencing), MenuEvents/ModalJuice/ConsoleUiScale/MODAL_SCREEN_GUIS lists, Bootstrap static checks (RaceActive BoostState guard, regen pass lines, EquippedTitle hook).
- `src/manifest.json`: rows are added by `Lib.run` for new scripts (check `added:true` rows, compact sorted keys).

Orden: workstreams → merge integrador → `list` → `run_update4_checks` → `run_fable_checks` → `check` → (owner OK) build `p0` y/o completo → `run_update4_checks places` → playtest en los 3 testing places.

---

## 6. Rollout, métricas, riesgos

1. **Publicar P0 solo primero** (propuesta: 3 días antes) para separar su efecto en D1 del de Update 4 (lección 09-20).
2. Update 4 con todo ON salvo StaminaPass (hasta tener id); kill switch `Workspace.U4Off_<Feature>` vía admin/Studio sin republicar. Publicar en hora valle; thumbnail/icon de Race con el publish.
3. Watch list (base DATOS_POST_PUBLISH_20260924): errores/día 101k (alarma >150k o firma U4 en top 25), FPS móvil ~24 (alarma −1), CPU cliente 9.31 ms (+1 ms), D1 12.74 % (<12 %), sesión 10.48 min (<10), `Race_Loop_v2` Queued→Started <85 %, Started→Finished <70 %, Finished→Rewarded <98 %, `Race_FirstRace_v2` Discovered→FirstQueued <25 %, `Race_Correction_v2` > 2 % de carreras, starts Perfect 15-25 % / Stall <8 %.

**Riesgos principales**: (a) predicción cliente ≠ RaceMath → correcciones a jugadores honestos (tolerancias + test con jitter + métrica Race_Correction_v2); (b) Glass solo refracta en calidad alta → en móviles ForceField/nada (expectativa del owner); (c) economía: race Wins ≈2 laps/h máx., retención x3.4 máx. (confirmar); (d) escrituras DataStore: ningún timer hace Commit; (e) Discord/policy: nunca URL ni "Discord" si PolicyService no lo permite; (f) tablero Race opcional para no romper los otros 3; (g) edición paralela de src por otras sesiones/sync del owner → el build usa guardas y backup; (h) H6 LoadCharacter respawn; (i) M15 tabla Daily más baja en días 16-30.

---

## 7. Specs por workstream

(Idénticas a `workstreams[].spec` del JSON del lead; cada una es autocontenida.)


### 7.1 p0_data — P0 data: H3 (+ApplyVolatile), M14/M15 Daily, M33 quests

**Goal.** Speed ticks never wait on a DataStore write and are not lost in `Recovering`. Update 4 timers get a generic in-memory mutation API. The Daily opens on a fixed 08:00 UTC day with a 12-20 h gap and auto-opens only when claimable. Yesterday's finished quest is auto-claimed. Everything is in src only; the places are built later by the integrator's `audit/build_update4.luau` (mode `p0`).

**Owns (change):** `src/common/ServerScriptService/Services/Data/SessionActor.luau` (CRLF: normalise to LF, patch, write CRLF back), `src/common/ServerScriptService/Services/Data/DataService.luau`, `src/common/ServerScriptService/Services/Stats/StatsProjection.luau`, `src/common/ReplicatedStorage/Shared/DailyRewardsData.luau`, `src/common/ReplicatedStorage/Shared/DailyRewards.luau`, `src/common/ServerScriptService/Social/DailyLoginSystem.server.luau`, `src/common/StarterPlayer/StarterPlayerScripts/UI/UpdateLogsController.client.luau`, `src/common/ReplicatedStorage/Shared/QuestCatalog.luau`, `src/common/ServerScriptService/Social/QuestService.server.luau`.
**Owns (create):** `src/common/ReplicatedStorage/Shared/QuestPeriod.luau`, `audit/test_retention_p1_data.luau`.
**Do NOT edit** ProfileReducers or ProfileCodec. The integrator wires QuestPeriod into them using the API below (exact names).

#### H3 — SessionActor holds its lock while writing
Measured on current src: `AccrueSpeed` waits 0.319 s behind a 0.3 s UpdateAsync, and returns `NotReady` in `Recovering` (the gain is lost).
1. `AccrueSpeed` state guard (:532): also accept `self.state == "Recovering"`.
2. After `self.speedCarry = ...` (:555): while `self.pendingWrite` and `self.accrualLog` exist, append `{added = speedResult.value.actualAdded or 0, at = self.clock.UnixNow()}` when added > 0.
3. New `SessionActor:_replayAccruals(pending)` before `_resolvePending` (:609): take and clear `self.accrualLog`; return if it is empty, or on `pending.resetCarry`, `pending.release` or no profile; otherwise for each entry set `profile.Speed = math.min(1e50, Speed + added)` and call `ProfileReducers.AddQuestProgress(profile, "speed", added, at)`; then `self.saveCoordinator:AdvanceCurrent()`.
4. `_resolvePending` (:615-632): set `self.writeInFlight = true` before the UpdateAsync; call `local okCall, result = pcall(self.storeAdapter.UpdateAsync, self.storeAdapter, self.key, fn)`; afterwards `self.writeInFlight = false; if not okCall then result = {ok=false, error=tostring(result)} end`.
5. After `if pending.resetCarry then self.speedCarry = 0 end` (:654): `self:_replayAccruals(pending)`.
6. `_writeSnapshot` (:665-670): `self.accrualLog = {}` right before `return self:_resolvePending()`.
7. Lock wrapper (:761-787): add `"ApplyVolatile"` to the method list. Before `while self.mutationOwner do scheduler.wait() end` insert:
   `if methodName == "AccrueSpeed" and self.mutationOwner then if not self.writeInFlight then return {ok=false,error={code="NotReady",message="Session busy",retryable=true}} end return implementation(self, ...) end`
   (the owner only yields inside UpdateAsync, so a speed tick never waits).
8. **New `SessionActor:ApplyVolatile(handle, command)`**, the same shape as `SetDailyLoginState` (:483-518):
   - validate the handle; the state must be `Ready`, `Ephemeral` or `Recovering`;
   - only `command.kind` `"U4.Retention.Playtime"` or `"U4.Titles.SetPref"`, else `{ok=false, error={code="InvalidInput", message="Not a volatile command", retryable=false}}`;
   - `local r = ProfileReducers.ApplyCommand(self.profile, command, self.clock.UnixNow())`; on ok `local rev = self.saveCoordinator:AdvanceCurrent(); self:_notifySubscribers(); return {ok=true, value=rev}`; else return r.
   - No write happens here; the 30 s autosave and Release persist it.
9. `DataService.ApplyVolatile(handle, command)` wrapper: a copy of `DataService.SetDailyLoginState` (:233-242).
10. `StatsProjection.luau:310`: `DataLoaded` = state is `Ready`, `Ephemeral` or `Recovering`; add `setAttributeIfChanged(player, "DataSaveRetrying", view.state == "Recovering")`.
Risks: every future command that sets Speed absolutely must set `resetCarry`. With DataLoaded true in Recovering, value actions reach Commit and get `Pending` (callers already handle it).

#### M14/M15 — Daily on a fixed day, auto-open only when claimable, one reward scale
1. `DailyRewardsData`: `ResetUtcHour = 8`, `ClaimFloorSeconds = 43200`, `ClaimRollingSeconds = 72000`, and a pure `ClaimWindow(last, now) -> canClaim, secondsRemaining`:
   - `day(t) = floor((t - 8*3600)/86400)`;
   - claimable when `last <= 0`, or `now-last >= 72000`, or (`now-last >= 43200` and `day(now) > day(last)`);
   - remaining = `min(last+72000, max((day(last)+1)*86400 + 28800, last+43200)) - now`, never negative.
2. New 30-day table (Type, Amount): 1 Speed 500 · 2 SpinTicket 1 · 3 Wins 250 · 4 Speed 5K · 5 PotionSpeed 15 (minutes) · 6 Wins 1K · 7 Speed 100K · 8 Wins 5K · 9 Speed 250K · 10 Wins 10K · 11 Speed 500K · 12 SpinTicket 2 · 13 Wins 50K · 14 Speed 2M · 15 Wins 150K · 16 Speed 5M · 17 Wins 300K · 18 Speed 10M · 19 PotionWins 30 · 20 Speed 25M · 21 Wins 2.5M · 22 Speed 50M · 23 Wins 1.2M · 24 Speed 100M · 25 Wins 1.6M · 26 SpinTicket 3 · 27 Wins 2M · 28 Speed 500M · 29 Wins 2.5M · 30 Speed 2.5B. Keep the existing milestone flags on days 7, 14, 21 and 30. Speed/Wins keep today's multiplier behaviour.
3. `DailyRewards.luau` (:47-78): texts `"1 Spin"` / `"N Spins"`, `"2x Speed 15m"`, `"2x Wins 30m"`; icons from `QuestCatalog.RewardIcons` (:42-44).
4. `DailyLoginSystem.server.luau`:
   - `recomputeClaimState` (:112-123) uses `ClaimWindow`;
   - `fireUpdate` (:206) and `loadPlayer` (:282) set the attribute `DailyCanClaim`;
   - `loadPlayer` sets `ArrivedByTeleport = (td.FromWorld ~= nil or td.AfkModeResume == true)` with `td = player:GetJoinData().TeleportData or {}`;
   - `claim` (:378) skips `getRewardObjects` for non-stat types;
   - `claim` (:407) builds the command by type: Wins/Speed `GrantExact` (unchanged); SpinTicket `{kind="GrantSpinTickets", amount=n}`; PotionSpeed/PotionWins `{kind="GrantBuff", grant={kind="SpeedPotion"|"WinsPotion", addedSeconds=minutes*60, multiplier=2, bottleType="Small"}}` (as QuestService:324-327).
5. `UpdateLogsController.client.luau`: `local function dailyWanted() return player:GetAttribute("DailyCanClaim") == true and player:GetAttribute("ArrivedByTeleport") ~= true end` (wait up to 10 s for `DailyCanClaim ~= nil`); gate each auto-open (:250-252, :372-374, :380-382). Manual open unchanged; the HUD badge still shows a locked day.

#### M33 — a finished quest is never lost at the day change
All logic goes in the new pure module `src/common/ReplicatedStorage/Shared/QuestPeriod.luau` (Lune-safe, no requires). Exact API:
- `QuestPeriod.CUTOVER = 1790582400` (2026-09-28 08:00 UTC, verified).
- `QuestPeriod.DailyPeriod(now)`: `now >= CUTOVER and floor((now + 57600)/86400) or floor(now/86400)`. Monotonic: at the cutover it steps forward once (that day lasts 8 h). `QuestPeriod.PeriodEnd(now)`: the first instant with a higher DailyPeriod.
- `QuestPeriod.SanitizeDestiny(d) -> table?`: the Destiny cleaning now inline in ProfileCodec `sanitizeQuestState` (:33-55), moved verbatim, plus `Complete = d.Complete == true`; returns nil for non-tables.
- `QuestPeriod.FreezeCompletion(profile, oldDailyBucket)`: if `profile.QuestState.Destiny.Period == oldDailyBucket.Period`, `Choice ~= 0` and not Claimed, set `Destiny.Complete = every metric has (Progress - Baseline) >= Target`.
- `QuestPeriod.SaveLate(profile, now)`: if Destiny is older than `DailyPeriod(now)`, Complete and not Claimed, copy it to `profile.QuestState.LateDestiny`.
- `QuestPeriod.ClaimLate(profile, command, now, questBucketFn) -> {ok,...}`: pays a Destiny or LateDestiny with `Period == command.period` and `period < DailyPeriod(now)`, not Claimed, and Complete (or judged live against a Daily bucket that has not rolled yet); marks Claimed and ClaimedChoices, clears LateDestiny; otherwise `{ok=false, error={code="InvalidInput", message="Late quest is not claimable", retryable=false}}`.
The integrator wires these into ProfileReducers (QuestBucket, ChooseQuestPath, ClaimQuestPath, new `ClaimLateQuestPath` kind) and ProfileCodec (Destiny + LateDestiny sanitize).
- `QuestCatalog.luau:216-218`: `PeriodOf = QuestPeriod.DailyPeriod`; add `PeriodEnd = QuestPeriod.PeriodEnd`.
- `QuestService.server.luau`:
  - `view` (:138): `TimeLeft = Catalog.PeriodEnd(now) - now`;
  - new `claimLate(player)`: rewards from `Catalog.PathsFor(late.Period)[late.Choice]` at the current level and speed; op id `"quest-claim:"..uid..":"..late.Period..":"..choice` (identical to `claim()`, so it can never pay twice); command `{kind="ClaimLateQuestPath", period=late.Period}` plus the reward commands; message "Yesterday's quest rewards were claimed for you!"; `FunnelAnalytics.Step(player, "Engagement_Quests", 4)`;
  - call `claimLate` deferred in `ready()` (:240), first in `choose()` (:262), and in the 2 s loop (:400-412) when `Catalog.PeriodOf(os.time()) ~= state.period`;
  - pre-rollover flush: in the loop, when `PeriodEnd - now <= 10` and the player has an active unclaimed quest, `task.spawn(flush, player)` once per period.

#### Acceptance
- A speed tick returns in under 0.05 s while a Commit is parked in a 0.3 s UpdateAsync. Recovering accepts gains, and a later Flush stores them. A SetStat during a write drops that write's replay.
- `ApplyVolatile` changes the in-memory profile without any UpdateAsync, and refuses kinds outside the whitelist.
- The ClaimWindow wait is always 12-20 h and never negative. The Daily auto-opens only when `DailyCanClaim` is true, and never after a world teleport or AFK rejoin.
- A quest finished yesterday is paid exactly once after the day rolls, a rejoin, or a new choose.

#### Tests — `audit/test_retention_p1_data.luau` (require src modules by relative path; never audit/merged, it is stale)
- H3: slow mock store (task.wait 0.3 in UpdateAsync) → AccrueSpeed during a parked Commit returns ok in < 0.05 s, then Speed 110 / Wins 5; mock `Down` → Commit Pending, state Recovering, AccrueSpeed ok twice; back to `None` → Flush Saved and the store holds everything (use `DataStoreAdapter.CreateMock` as test_retention_p0 lines 64-75); SetStat Speed=1 during a tick leaves Speed 1.
- ApplyVolatile: a stub reducer command changes the profile, the mock counts zero UpdateAsync calls; a non-whitelisted kind is refused.
- ClaimWindow: last claim 07:00 UTC → 12 h; 20:00 → 12 h; 12:00 → 20 h; last=0 → claimable; 2,000 random pairs: wait in [12 h, 20 h], never negative.
- Table: 30 entries, each Type in {Speed, Wins, SpinTicket, PotionSpeed, PotionWins}, Speed non-decreasing, no day-over-day jump above 10x.
- Source: DailyLoginSystem contains `GrantSpinTickets` and `GrantBuff`; UpdateLogsController contains `DailyCanClaim` and `ArrivedByTeleport`; StatsProjection contains `DataSaveRetrying`.
- QuestPeriod: monotonic across the cutover ±48 h in 3600 s steps; `QuestCatalog.PeriodOf == QuestPeriod.DailyPeriod`; FreezeCompletion / SaveLate / ClaimLate unit cases (complete one paid once, second call rejected, incomplete rejected, LateDestiny survives a new choose).
- Round trips of `Complete`/`LateDestiny` through the codec are covered by the integrator's `test_u4_integration`.

### 7.2 p0_gameplay — P0 gameplay: H5 W1 rewind, H6 client-only deaths, M50 speed dial, H10 MovementGuard Observe

**Goal.** No unfair server backstop kills for laggy W1 runners; a death only the client saw is validated by the server (overruled deaths respawn at the stage start, no penalty); the speed dial no longer sits on the jump button and cannot slow a newcomer to a crawl; MovementGuard measures a strict lane for 48-72 h before any enforcement. src only.

**Owns (change):** `src/worlds/World1/ServerScriptService/Gameplay/NewWorld1ServerMotion.server.luau`, `src/worlds/World1/ServerScriptService/Gameplay/NewWorld1MapSystems.server.luau`, `src/worlds/World1/StarterPlayer/StarterPlayerScripts/Gameplay/NewWorld1MapMotion.client.luau`, `src/common/StarterPlayer/StarterCharacterScripts/R15SpeedsterRun.client.luau`, `src/common/ServerScriptService/Economy/SpeedProductPurchases.server.luau`, `src/common/ReplicatedStorage/Shared/HudErgonomics.luau`, `src/common/StarterPlayer/StarterPlayerScripts/UI/WalkSpeedSelector.client.luau`, `src/common/ServerScriptService/Services/Stats/CharacterStatsAdapter.luau`, `src/common/ServerScriptService/Services/MovementGuard.luau`, `src/worlds/World1/ServerScriptService/Gameplay/NewWorld1ManualStagePads.server.luau`, `src/worlds/World2/ServerScriptService/Gameplay/World2ManualStagePads.server.luau`, `src/worlds/World3/ServerScriptService/Gameplay/World3ManualStagePads.server.luau`, `src/worlds/World2/ServerScriptService/Gameplay/World2SafeZones.server.luau`.
**Owns (create):** `src/common/ServerScriptService/Services/PoseHistory.luau`, `src/common/ReplicatedStorage/Shared/HazardNames.luau`, `src/common/ServerScriptService/Services/LocalDeathRules.luau`, `src/common/ServerScriptService/Gameplay/LocalDeathArbiter.server.luau`, `audit/test_retention_p1_gameplay.luau`.

**Contracts consumed (added by the integrator; read with defaults):** `Config.WalkSpeedSelectorFloor` (16), `Config.WalkSpeedSelectorFullBelow` (24), `Config.MovementGuardMode` ("Observe"). Analytics: `FunnelAnalytics.Event(player, name, value, fields)` with the whitelisted names `LocalDeath_Kill_v2`, `LocalDeath_Revive_v2`, `MG_StrictPass_v2`, `MG_StrictWouldReject_v2`; load FunnelAnalytics with the exact pcall loader of QuestService.server.luau:25-33 and skip silently if `Event` is missing. Race: player attribute `RaceActive` (bool, set by the race server).

#### H5 — the W1 server backstop rewinds lag for every group
- New `PoseHistory` (pure, server): `new(size=12)`, `Push(h, t, cf)` (a push at the same time overwrites the newest), `At(h, t)` (lerp between the two samples around t, clamped to oldest/newest). 12 samples at 30 Hz = 0.4 s > max rewind 0.25 s.
- `NewWorld1ServerMotion.server.luau`:
  1. `local PoseHistory = require(ServerScriptService.Services.PoseHistory)`.
  2. Rename `getHammerRewindSeconds` (:1887-1896) → `getRewindSeconds` (keep the old name as an alias; rule unchanged `clamp(ping*0.5 + 0.05, 0, 0.25)`).
  3. Heartbeat, after `updateBridge(serverTime)` (:2075): for every record with `ClientDriven and Transform`, `record.History = record.History or PoseHistory.new(); PoseHistory.Push(record.History, serverTime, record.Transform)`; then `lastMotionServerTime = serverTime`.
  4. Helper next to `previousPartCFrame` (:1100): `partCFrameAt(record, part, t)` = `PoseHistory.At(record.History, t) * record.OriginCFrames[part]` when both exist, else `currentPartCFrame(record, part)`.
  5. `checkPlayerContact` non-hammer branch (:1963-1995): `seenAt = lastMotionServerTime - getRewindSeconds(player)`; broad phase takes the minimum over current, previous and the rewound centres at `seenAt` and `seenAt - SERVER_MOTION_INTERVAL`; sweep replaces `previousPartCFrame(group.Record, part)` → `partCFrameAt(group.Record, part, seenAt - SERVER_MOTION_INTERVAL)` and `currentPartCFrame(group.Record, part)` → `partCFrameAt(group.Record, part, seenAt)`. Static lava (`Record == nil`) unchanged.
  6. `checkExactCylinderContact` (:1820-1831) uses `partCFrameAt(system.Record, system.HazardPart, seenAt)`; pass `player` from the call site (:1947).
  7. `partToRecord` map filled in `addLethalGroup` (:1073); `_G.SpeedsterHazardPoseAt = function(part, serverTime)` returns `partCFrameAt(record, part, serverTime - motionStartServerTime)` or nil.

#### H6 — client-only deaths go through a server arbiter
- New `Shared/HazardNames.luau`: `IsLethalName(nameLower, parentLower)` and `IsLethalPart(part)`, moved verbatim from R15SpeedsterRun :1122-1131 (keep the `laserplatform` exception and `Kill script`), plus `part:GetAttribute("NewWorld1HazardKey") ~= nil`.
- New `Services/LocalDeathRules.luau` (pure). `Decide(ctx) -> "Kill"|"Revive"|"Ignore", reason`. Rows in order:
  1. server humanoid dead or `Dead` attribute → Ignore;
  2. protected (SafeZoneProtected, StageTeleportInvulnerable, arrival grace, RevivedJustNow, frozen-lava part, **RaceActive**) → Revive "Protected";
  3. part nil and no accepted claim for this character → Revive "NoEvidence";
  4. part nil and a claim was accepted → Kill;
  5. not `HazardNames.IsLethalPart(part)` → Revive "NotLethal";
  6. `TrackMoving` part and no pose provider → Kill (legacy trust);
  7. distance from the server root to the part box (pose provider at `clamp(clientTime, now-1, now)`, else `part.CFrame`) > `6 + v*clamp(ping*0.5 + 0.2, 0.2, 0.6)` with `v = max(root.AssemblyLinearVelocity.Magnitude, RealWalkSpeedSelected*(IsBoosting and 1.7 or 1))` → Revive "TooFar";
  8. otherwise Kill.
- New `Gameplay/LocalDeathArbiter.server.luau`: **creates `ReplicatedStorage.Remotes.LocalDeathClaim` (RemoteEvent) itself** at startup (no Bootstrap change). One claim per 0.5 s per player; one decision per character (weak-keyed `acceptedByCharacter`). Kill → `hum.Health = 0`. Revive → `_G.SpeedsterOverruledRevive(player, ReviveStageAtDeath or LastReachedStage)`. Telemetry at most once per 5 s per player: `FunnelAnalytics.Event(player, "LocalDeath_" .. result .. "_v2", 1, {CustomField01 = reason, CustomField02 = "W" .. world})` (use `Enum.AnalyticsCustomFieldKeys.CustomField01.Name` keys).
- `R15SpeedsterRun.client.luau`: `checkPart` (:1107-1146) uses HazardNames plus a skip when `SafeZoneProtected` is set on the part or the character; right before `humanoid.Health = 0` (:1140) fire `LocalDeathClaim:FireServer(hitPart, Workspace:GetServerTimeNow())`; the `onLocalDeath` watchdog (:1045-1052) fires `LocalDeathClaim:FireServer(nil, nil)` instead of `PlayerResetRequest`. Find the remote with `Remotes:WaitForChild("LocalDeathClaim", 10)`. `PlayerResetRequest` stays for the Esc reset button (InstantMovementController :1113-1131, AdminPanelService :937-944, R6DeathRagdoll :595-603).
- `NewWorld1MapMotion.client.luau` `killLocalForHazard` (:474-492): same SafeZoneProtected skip.
- `NewWorld1MapSystems.server.luau` guard (:73-75): add `player:GetAttribute("SafeZoneProtected") == true or char:GetAttribute("SafeZoneProtected") == true or os.clock() < (tonumber(player:GetAttribute("StageTeleportArrivalGraceUntil")) or 0)`.
- `SpeedProductPurchases.server.luau`, after `grantFreeInfiniteRevive` (:1338):
  ```lua
  _G.SpeedsterOverruledRevive = function(player, stage)
  	pendingRevivePurchases[player] = { Free = true, Stage = cleanStage(stage), Token = "overruled", ExpiresAt = os.clock() + 60 }
  	pcall(player.LoadCharacter, player) -- the server humanoid is alive; the client one is dead for good
  	local tx = grantReviveTransaction(player)
  	if tx then pcall(tx.Commit) end
  end
  ```
  (LoadCharacter first: grantReviveTransaction :1278-1285 only respawns characters the server sees as dead.) The player goes to the start of their stage with no revive offer and no stage loss.

#### M50 — speed dial next to the jump button
- `HudErgonomics.luau`: at :56 add `HudErgonomics.ColumnJumpGap = 24`; at :277 replace `local floor = (if jump then jump.Top + inset else height - 16) - gap` with `local floor = if jump then jump.Top + inset - HudErgonomics.ColumnJumpGap else height - 16 - gap`.
- `WalkSpeedSelector.client.luau` `NEXT_MODE` (:57-62): Red→Yellow, Yellow→Green, Green→Red, Custom→Red.
- `CharacterStatsAdapter.luau` (:61): `local floor = math.min(Config.WalkSpeedSelectorFloor or 16, maximum.value); local selected = math.max(floor, maximum.value * factors.selectorMultiplier); if maximum.value <= (Config.WalkSpeedSelectorFullBelow or 24) then selected = maximum.value end`.
- **Race contract (same file):** skip the `humanoid.WalkSpeed = actual` write (:78-79) while `player:GetAttribute("RaceActive") == true`; the race client sets WalkSpeed then.

#### H10 — MovementGuard: measure a strict lane first
- Two lanes per player: `state` (legacy, unchanged) and `state.strict` (own progress, lastPos, lastAt, steadyUntil, suspiciousUntil). `samplePlayer(player, lane, root, now, allowNearest)`: the nearest-stage shortcut (:157-163) runs only in the legacy lane. `ResetForCharacter` resets both.
- `Rebase(player, target, source)`: source nil, "Teleport", "Respawn" or "Reconnect" → both lanes (all current sanctioned callers and the race server pass nil); "Pad" or "SafeZone" → legacy lane only in Observe. In Enforce, "Pad" is a no-op and "SafeZone" raises `strict.progress` only when `target == strict.progress + 1`, without resetting lastPos/steadyUntil. `_G.VortexMovementGuardRebase` (:339) passes the 3rd argument through.
- `CanClaim` (:235-274): compute legacy (as today) and strict (strict lane, without the :254-260 shortcut). `Config.MovementGuardMode`: "Legacy" → legacy only; "Observe" → returns legacy and records strict; "Enforce" → returns strict.
- Recording (1 per 30 s per player): `FunnelAnalytics.Event(player, "MG_StrictPass_v2" or "MG_StrictWouldReject_v2", 1, {CustomField01 = "W<n>-S<stage>" .. (isFinal and "-F" or ""), CustomField02 = reason .. "-gap" .. bucket})`, bucket "1" / "2-3" / "4+" from `req - strict.progress`; print server counters every 10 min.
- Pads pass the source: NewWorld1ManualStagePads :524 `pcall(rebase, player, stage, "Pad")`, World2ManualStagePads :461 and World3ManualStagePads :379 the same; World2SafeZones :237 `"SafeZone"`.
- Decision rule for the owner after 48-72 h: Enforce only when every stage has WouldReject gap1 / Pass < 1 %.

#### Acceptance
- No behaviour change for players from H10 in Observe. W1 non-hammer hazards judge contact at the player's seen time. Client-only hazard deaths are either confirmed (Kill) or turned into a stage-start respawn. The dial keeps ≥24 px from the jump button on phones with a 36 px top bar and never drops a sub-24 studs/s newcomer below full speed.

#### Tests — `audit/test_retention_p1_gameplay.luau`
- PoseHistory: At() matches an analytic spin within 1e-6, clamps at both ends, same-time overwrite.
- A 132×1×1 beam spinning 52°/s, runner at radius 30: a tick where the current pose covers the runner but the pose 0.2 s ago did not → the rewound sweep does not kill.
- Source: NewWorld1ServerMotion sweep contains `partCFrameAt(group.Record, part, seenAt)`; the lava-freeze line checked by test_admin_abuse_panel.luau:276 is still there.
- HazardNames: `laserplatform` floor not lethal; `Laser` parent lethal; `KillBrick`, `Kill script` child and `Lava` lethal.
- LocalDeathRules.Decide: one case per row, including RaceActive → Revive "Protected".
- Source: R15SpeedsterRun fires LocalDeathClaim and no longer references PlayerResetRequest; InstantMovementController and R6DeathRagdoll still handle PlayerResetRequest; LocalDeathArbiter creates LocalDeathClaim.
- M50: for the PHONES sizes of test_opt6_touch_layout with a 36 px top bar `Jump.Top - Speedometer.Rect.Bottom >= 24 - 1e-6`, every size ≥ 4; CharacterStatsAdapter.Update on a stub player: Speed 1 Green → 8, maximum 300 Green → 60, RaceActive → no WalkSpeed write; NEXT_MODE has `Red = "Yellow"`.
- MovementGuard via `luau.load` with stubs (Players, RunService Heartbeat collected, ReplicatedStorage, Workspace, a StageTeleportService stub with stage n at x = n*1000, `Config.StageCount = 10`): a legit run at 300 studs/s passes in every mode; a 2000-stud hop every 0.1 s + `Rebase(stage, "Pad")` → Legacy and Observe return true and record WouldReject gap4+, Enforce returns false with `MissingCheckpoint`; SafeZone rebase in Enforce raises strict progress by +1 only.
- Keep `audit/test_ui_ergonomics.luau` and `audit/test_opt6_touch_layout.luau` green.

### 7.3 race_server — Racing core (server, shared math, arena builder, rewards, leaderboard)

**Goal.** One race arena per server, identical in all 3 worlds, with a server-authoritative race cycle, a speed model normalised across worlds (stats worth ≤6 %, skill 3-6 s), the charge-start judge, spike stumbles, anti-cheat envelope, balanced rewards in one Commit, all-time + weekly fastest-time stores, and the Mega Race admin hook.

**Owns (create):**
- `src/common/ReplicatedStorage/Shared/RaceTrack.luau`, `Shared/RaceMath.luau`, `Shared/RaceChargeMath.luau` (pure, Lune-safe, used by client, server and tests; other workstreams code against their API below)
- `src/common/ServerScriptService/Services/Race/RaceService.luau`, `Services/Race/RaceChargeJudge.luau`, `Services/Race/RaceRewards.luau`, `Services/Race/RaceLeaderboard.luau`, `Services/Race/RaceArenaBuilder.luau`
- `src/common/ServerScriptService/Gameplay/RaceServer.server.luau` (entry)
- `src/common/ServerScriptService/Services/Data/U4/RaceSection.luau`
- tests: `audit/test_u4_race_math.luau`, `audit/test_u4_race_charge.luau`, `audit/test_u4_race_rewards.luau`, `audit/test_u4_race_validation.luau`, `audit/test_u4_race_lifecycle.luau`, `audit/test_u4_race_leaderboard.luau`, `audit/test_u4_race_arena.luau` (pure + `places`), `audit/test_u4_race_placement.luau` (`places`)
**Owns (change):** `src/common/ServerScriptService/Core/Abilities/SonicBurstService.server.luau`, `src/common/ServerScriptService/Core/Abilities/FlightService.luau`, `src/common/ServerScriptService/Social/AfkZoneService.server.luau`, `src/common/ServerScriptService/Services/StageTeleportService.luau`.

**Consumed contracts.** Every number comes from `ReplicatedStorage/Shared/Update4Config.luau` (`U4.Race.*`, created by the integrator; see PLAN §2.1 — read it, never hard-code). `U4.IsOn("Race")` / `U4.IsOn("MegaRace")` at every request. Profile field `U4.Race` through your `U4/RaceSection.luau` (section contract below); the integrator's dispatcher routes `kind = "U4.Race.<Op>"` to `RaceSection.Apply(state, op, command, now)`. Existing: `Config.SpinWheel.LapWins[world]` (Config.luau:464-475), `Config.AfkZone.SpeedShare/SpeedFloor` (:220-247), `Config.World2UnlockRebirths` (:55), `Config.SuitStaminaMax` (:685-702), `_G.SpeedsterGetWinsMultiplier(player)` (PlayerStatsBridge.luau:197), `_G.VortexMovementGuardRebase(player, nil)` (MovementGuard.luau:339), `MovementGuard.GetProgress(player)` (:226) / `Rebase(player, progress)` (:194), `StageTeleportService.TeleportToNormalSpawn(player)` (:107), `PadTouchService.Connect(pad, cb)` (:92), `PadTouchService.Intersects(cf, size, from, to)` (:12), `DataService.GetHandle/Commit/NewOperationId`, `RemoteGuard.Connect(remote, interval, handler)`, `LatestStateLimiter.Connect(remote, interval, handler)`, `FunnelAnalytics.Step/NewSession/Event` (QuestService.server.luau:25-33 pcall loader). Title grants: include `{kind="U4.Titles.Grant", id=...}` in your race Commit, then call `_G.SpeedsterTitles.Refresh(player)` when it exists (titles workstream).

All modules use the dual-require pattern (`if typeof(script)=="Instance" then require(<instance path>) else require("<relative path>")`) so Lune tests can load them. Never `CFrame.lookAt` (wrong in Lune): the track faces **-Z**, which is the default look vector of `CFrame.new(pos)`.

#### 1. Shared/RaceTrack.luau (geometry; pure)
Frame: `O = U4.Race.Arena.Origin` = (6000, 12000, 0) (centre of the start line on the floor top). `s = O.Z - world.Z` (distance past the start line), `x = world.X - O.X`, `y = world.Y - O.Y`.
- `Length 2000`, `RunOut 120` (end wall at s 2120), `Width 72`, `Lanes 8`, `LaneX(l) = -31.5 + 9(l-1)`, staging s -64..0.
- `SlotCFrame(i)` for i = 1..16: row = ceil(i/8) (s = -10 / -22), lane = ((i-1)%8)+1; `CFrame.new(O.X + LaneX(lane), O.Y + 3, O.Z + 10|22)` (facing -Z).
- `ToLocal(pos) -> s, x, y`, `ToWorld(s, x, y) -> Vector3`, `DistanceLeft(s) = max(0, 2000 - s)`, `InCorridor(s, x, y)` (|x| ≤ 44, -150 ≤ s ≤ 2240, y ≤ 80).
- `SpikeTiles() -> {{s, x, field, row, lane}}`: fields at s0 ∈ {300, 750, 1200, 1650}, rows at s0 and s0+40, blocked lanes from `U4.Race.Track.SpikeBlocked` (always 4 free lanes per row).
- `SpikeAt(s, x, y) -> tile?`: `|x - tile.x| ≤ 7/2 - 0.5 + 1` and `|s - tile.s| ≤ 7/2 - 0.5 + 1` and `y < 0.4 + 3` (jumping clears spikes). `SweptSpike(s0, x0, s1, x1, y0, y1) -> tile?` (segment test against every tile of the ≤2 fields near the segment; both y samples must be under the height).

#### 2. Shared/RaceMath.luau (speed, stamina, rewards; pure; same code on client and server)
- `StatBonus(rawSpeed) = 0.06*(1 - exp(-log10(1 + max(0, rawSpeed))/6))`; `Caps(rawSpeed) -> {Vc = 50*(1+b), Vs = 1.4*Vc, b}`; the world walk multipliers (World2 x0.5, World3 x0.25) are **not** used.
- `SprintSeconds(suitMax) = 4*(1 + 0.25*clamp((suitMax-5)/65, 0, 1))` (4.0 FlashSuit … 5.0 SilverSurferSuit).
- `NewState(params, grade, v0)`; `Step(state, input, dt, params, now)` with state `{s, v, pool, sprinting, stumbleUntil, immuneUntil, lastSprintAt, goAt, grade}` and input `{forward (0..1 = max(0, moveDir·heading) if within 70°, else 0), sprint: boolean, grounded: boolean, jumped: boolean}`:
  - target `Vt = 0` without forward input; else `Vc` (or `Vs` while sprinting with pool > 0 and started at pool ≥ 0.10); × `StartMultiplier(grade, now - goAt)`; stumble → `0.5*Vc`, no sprint;
  - exact integration `v ← Vt + (v - Vt)*exp(-dt/τ)` (τ 1.6 rising, 0.8 falling); no acceleration while airborne; `s += v*dt` (average over the step);
  - pool: drain `dt/sprintSeconds` only while sprinting and `v > 0.5*Vc`; regen `0.12*dt*regenFactor` after 0.8 s without sprint; jump −0.06; clamp 0..1.
  - `Accel(state)` = `(Vt - v)/τ` for the HUD "MPH/s".
- `SpikeHit(state, now)`: `v ← 0.35*v`, `stumbleUntil = now + 0.7`, `immuneUntil = now + 0.7 + 0.9`.
- Rewards (pure, §5): `FieldFactor(n)`, `ProgressFactor(world, rebirths)`, `Shares(place, finished, progress, solo)`, `ComputeRewards(ctx) -> {wins, speed, tickets, capReduced, multiplier}`.
- `WeekId(now) = floor((now + 3*86400)/604800)` (weeks start Monday 00:00 UTC), `DayId(now) = floor(now/86400)`, `MinPlausibleMs = 30000`.

#### 3. Shared/RaceChargeMath.luau (charge-start minigame; pure)
Gauge g ∈ [0,1], piecewise-linear, evaluated exactly between events (frame-rate independent → client display == server replay). Params `U4.Race.Charge`.
- Held (not venting): +Fill 0.55/s; released: −Decay 0.35/s, floor 0; reaching 1 while held = overheat: vent at −1.0/s for 0.6 s ignoring input, then resume with the current held state.
- Zone [0.58, 0.84], Core [0.65, 0.77]; scoring window = last 1.5 s before GO; `zoneT`, `coreT` exact time inside each band; `Q = 0.5*zoneT/1.5 + 0.5*coreT/1.5`; `gGO` = g at GO.
- `Outcome` (first match): `Stall` if overheated in [-0.75, 0] or gGO ≥ 0.97; `Perfect` if gGO in zone and Q ≥ 0.65; `Good` if (gGO in zone and Q ≥ 0.30) or (gGO ≥ 0.45 and Q ≥ 0.55); else `Ok`. Newcomer grace: `RaceFinishes < 3` turns Stall into Ok. Assist: after 3 consecutive Ok/Stall starts in the session, zone [0.50, 0.90], core [0.60, 0.80], no stall, best result Good.
- `StartMultiplier(grade, tau)`: Perfect 1.45 for τ<1.2 then linear to 1.0 at 2.5; Good 1.22 for τ<1.0 then linear to 1.0 at 2.0; Ok 1.0; Stall 0 for τ<0.45 then 0→1 by 0.8.
- API: `Evaluate(edges, openAt, goAt, at, params) -> {G, Held, Venting, ZoneT, CoreT, Q, HeldSeconds, OverheatAt}`, `Outcome(result, params, grace, assist)`, `StartMultiplier(grade, tau, params)`, `BoostDistanceSeconds(grade)`. Edges: sorted server times, odd index = press, even = release. Stamina cost = `0.15 * HeldSeconds` of the race pool (cost only while held and not venting).
- Probe results to reproduce in tests: reaction 0.10 s → Perfect; 0.28-0.36 s → Good; hold from open → Stall; never press → Ok; any single press+release → at best Good (Q≈0.59).

#### 4. Services/Race/RaceChargeJudge.luau
- `Open(player, raceId, openAt, goAt)`, `Result(player) -> grade`, `Close(player)`.
- Remote `RaceChargeInput(raceId, edges, final)` (cumulative), `LatestStateLimiter.Connect(remote, 0.08, …)`. Reject unless edges is a table, `#edges ≤ 40`, raceId matches, `now ≤ goAt + 0.45`. Accepted edges never change: new index i gets `t = clamp(edges[i], max(openAt, prev + 0.03, recv - 0.40), min(goAt, recv + 0.05))`, NaN/inf dropped.
- During Countdown a 4 Hz loop evaluates at `now - 0.1` and writes player attribute `RaceChargeLevel = floor(g*10+0.5)` only when it changes.
- Judge at `final` or `goAt + 0.45`: `Evaluate` → `Outcome` (grace from the `RaceFinishes` attribute, assist from a per-session miss counter) → player attribute `RaceStartGrade`, `RaceEvent{kind="Start", grade}`; returns grade and `HeldSeconds` to RaceService, which subtracts `0.15*HeldSeconds` from the server pool.
- First accepted edge of a player's first race → `FunnelAnalytics.Step(player, "Onboarding_Race", 3)`; Perfect → `Event("Race_StartPerfect_v2")`, Stall → `Event("Race_StartStall_v2")`. Anti-macro: log only.

#### 5. Services/Race/RaceService.luau — lifecycle (state machine, `U4.Race.Queue` timings)
`Idle → Gathering → Staging → Countdown → Running → Results → Cooldown → (Gathering|Idle)`. A `task.wait(0.05)` loop runs only outside Idle; racer sampling on Heartbeat throttled to 20 Hz; all clocks `Workspace:GetServerTimeNow()`. Workspace attributes are written only on transitions: `RacePhase`, `RacePhaseEndsAt`, `RaceGoAt`, `RaceId`, `RaceQueueCount`, `RaceRacerCount`, `RaceMaxPlayers`.
- **Gathering** starts at 2 queued (Mega: 1); 20 s (5 s once full at 12; Mega 30 s / 16). One player alone for 25 s → **Time Trial** (solo; rewards use the finisher share and field 0.5).
- **Join** `Join(player, source)` from: Race Gate pad (`PadTouchService.Connect`; also teleports the player to the staging area s -40 to wait), `RaceRequest("Join", "Hud"|"Invite"|"Results"|"Panel")`. Refused with `RaceEvent{kind="Toast", key=...}` when: feature off; `DataLoaded ~= true`; not (`FirstTimeTutorialSeen == true` or `Rebirths >= 1`) (key `RaceLockedTutorial`); `AfkModeActive`; dead; already queued/racing. On accept: `RaceState = "Queued"`, `RaceEvent{kind="Queued"}`, `FunnelAnalytics.NewSession(player, "Engagement_Race")` + `Step(…, 1)`, `Event("Race_Join_<Source>_v2")` (Gate/Hud/Invite/Results/Panel), first-ever queue (`U4.Race.Races == 0`) → `Step(player, "Onboarding_Race", 2)`, second-ever → step 5. Mega active → `Event("Race_MegaJoined_v2")`.
- While queued, sample the last grounded root CFrame at 2 Hz (`FloorMaterial ~= Air`, alive) + `MovementGuard.GetProgress(player)` for the return trip.
- **Staging (3 s)**: take up to MaxPlayers FIFO; per racer `task.spawn`: `player:RequestStreamAroundAsync(slotPos, 5)` (pcall), `IsBoosting=false`, `character:PivotTo(RaceTrack.SlotCFrame(slot))`, zero velocity, `_G.VortexMovementGuardRebase(player, nil)`. Attributes: `RaceState="Staged"`, `RaceActive=true`, `RaceMovementLocked=true`, `RaceSlot`, `RaceCruiseSpeed`, `RaceSprintSpeed`, `RaceSprintSeconds`, `RaceRegenFactor` (`U4.Race.Stamina.PassRegenFactor` if `StaminaRegen2xOwned`, else 1), `RaceStatBonus`, `RaceRewardMultiplier` (event × daily-first). Server pool = 1.0. `RaceEvent{kind="Staged", slot, raceId, goAt, cruise, sprint, sprintSeconds, regenFactor}`. At Countdown start a racer whose root is > 30 studs from its slot is dropped (`Unqueued`, reason `StreamTimeout`) and returned.
- **Countdown (5 s)**: `RaceGoAt = start + 5`; `RaceChargeJudge.Open(player, raceId, goAt - 3.0, goAt)`. `StartGate.CanCollide = false` at `goAt - 0.1` (task.delay; clients drop their local copy at goAt); `RaceMovementLocked=false` at GO. False start (s > 1.5 before goAt + 0.1) → back to the slot + 0.3 s hold. At GO: `RaceState="Racing"`, `Step(Engagement_Race, 2)`.
- **Running**: per racer at 20 Hz (§6 validation). Finish at s ≥ 2000: time interpolated between samples minus `clamp(ping*500, 0, 120)` ms; `RaceFinishMs`, `RacePlace`, `RaceState="Finished"`, `RaceEvent{kind="Finished", place, timeMs, pb}`, `Step(Engagement_Race, 3)`, first ever → `Step(Onboarding_Race, 4)`. Race ends at `min(goAt + 60, firstFinish + 15)` or when everyone is finished/out. `RaceSuperSpeed` (player attribute) on when the measured 0.5 s speed ≥ 0.93·Vs, off when < 0.85·Vs. `RaceLive` (UnreliableRemoteEvent) at 4 Hz to racers and queued players: `{id, t, left, n, top={{u, s, f}}×≤3, you={place, s, pool, strikes}}`.
- **Results (7 s)**: rank finishers by time, then others by s; pay (§7); `RaceEvent{kind="Results", podium, you}`; `RaceActive` stays true until the player leaves the arena. Racers with `RaceAutoRequeue` (default true after a race; `RaceRequest("AutoRequeue", bool)`) or who pressed Race again are re-queued (`Event("Race_Requeued_v2")`).
- **Leaving** (`RaceRequest("Leave")`, end of Cooldown without requeue, or the Results "Lobby"): `RequestStreamAroundAsync(returnPos, 5)`, `PivotTo(captured CFrame + 3y)`, zero velocity, `MovementGuard.Rebase(player, capturedProgress)`, `StageTeleportService.ArmArrivalGrace(player)`; Gate joiners and invalid captures → `StageTeleportService.TeleportToNormalSpawn(player)`. Clear every Race* state attribute (`RaceState=""`, `RaceActive=false`, `RaceMovementLocked=false`).
- **Edge cases**: `Humanoid.Died` → DNF "Dead" (normal respawn, no return teleport); PlayerRemoving → drop; outside the corridor (another system moved them) → DNF "Left", no teleport; fall (y < -25) → `PivotTo(ToWorld(sLast, clamp(x,-26,26), 3))` + Rebase + stumble (not DNF); two DNFs in a row under 5 % progress → no auto-requeue.
- **Invites**: during Gathering, `RaceEvent{kind="Invite", endsAt, count, mega}` to players with `RaceState==""`, not AFK, tutorial seen, `CurrentSafeZoneStage ≤ 1` (lobby), not invited in the last 300 s (Mega: everyone eligible).
- **Mega Race** (`StartMegaEvent(duration, byName)`): `Workspace.RaceEventUntil = os.time() + duration`, `RaceEventMultiplier = 2`, `RaceEventBy`; while active MaxPlayers 16, Gather 30 s, MinPlayers 1; Idle/Gathering restarts Gathering at once; invites everyone eligible. `StopMegaEvent()` clears the attributes (a running race keeps its multiplier).
- **Gate sign**: Workspace `RaceRecordMs`/`RaceRecordName` (weekly #1) from the leaderboard; the client fills the sign.

#### 6. Server authority and anti-cheat (per racer, 20 Hz)
- Model state stepped with `RaceMath.Step` assuming full forward input, the server pool, the server sprint flag (`RaceSprint`, LatestStateLimiter 0.05; edges ignored unless Racing) and the judged grade (assume Perfect until judged). Spikes: `RaceTrack.SweptSpike` between samples with the tile shrunk by 1 stud → `SpikeHit` on the model and `RaceEvent{kind="Stumble"}`.
- Envelope `sAllowed = s_env*1.06 + 10 + 0.3*v_env`; rate cap over 0.5 s ≤ `Vs*1.288` three windows in a row. Violation → `PivotTo(ToWorld(min(s, s_env), x, 3))`, forward velocity `v_env`, `_G.VortexMovementGuardRebase(player, nil)`, strike, `RaceEvent{kind="Correction", s, v}`, `Event("Race_Correction_v2")`. 3 strikes → DQ (no reward, no PB). Any finish < 30000 ms → DQ.
- MovementGuard needs no change: racers move ≤ ~100 studs/s and the arena is > 3700 studs (XZ) from every stage.

#### 7. Rewards (Services/Race/RaceRewards.luau + RaceMath.ComputeRewards), one Commit per racer
```
N = racers at GO; field = clamp(0.4 + 0.1*N, 0.5, 1.0)
lap = Config.SpinWheel.LapWins[world]
progress = World1: min(1, ((Rebirths+1)/(Config.World2UnlockRebirths+1))^2) else 1
shareW = {0.06, 0.04, 0.03}[place] | other finisher 0.015 | DNF with ≥25% of the track 0.005 | else/DQ 0 ; solo = finisher share
minutes = {3.6, 2.8, 2.4}[place] | finisher 1.8 | DNF ≥25% 0.6
event = RaceEventMultiplier while Workspace.RaceEventUntil > os.time() else 1
daily = 2 on the first rewarded race of the UTC day (U4.Race.DayId < today) + 1 Spin Ticket
cap = 1 if HourCount < 30 in the rolling hour else 0.25
wins = floor(floor(lap*progress*shareW*field*event*daily*cap) * _G.SpeedsterGetWinsMultiplier(player)), clamp 0..2^53-1
speed = floor(max(Config.AfkZone.SpeedFloor, RawSpeed*Config.AfkZone.SpeedShare)*minutes*field*event*daily*cap), ≤ 0.05*RawSpeed + 2000
```
Commit: operationId `race:<game.JobId>:<raceId>:<userId>`, commands `{kind="GrantExact", stat="Wins", amount}`, `{kind="GrantExact", stat="Speed", amount}`, `{kind="GrantSpinTickets", amount=1}` (daily first only), `{kind="U4.Race.Record", finished, place, field, timeMs, rewarded, dayId, weekId, perfect}`, and `{kind="U4.Titles.Grant", id}` for newly reached race titles (`U4.Race.Titles`: wins 1/25/100 → race_winner/race_champion/race_legend; 10 perfect starts → lightning_start). Retry `Pending` with the same id ≤5×1 s. After success: `Step(Engagement_Race, 4)`, update player attributes `RaceBestMs`, `RaceWeekBestMs`, `RaceWins`, `RaceFinishes` (project them on join too from `U4.Race`), queue a PB write, call `_G.SpeedsterTitles.Refresh(player)` if present. Worked examples (×1 multiplier): W1 0 rebirths, 6-racer winner → ~1,417 Wins; W3 winner → 2,460,000 Wins; hourly ceiling for an always-winner ≈ 2 laps.

#### 8. U4/RaceSection.luau (profile `U4.Race`)
Section contract: `Default()`, `Sanitize(raw)`, `Encode(t)`, `Apply(state, op, command, now)`. Fields (ints, clamp 0..1e9; BestMs/WeekBestMs 0 = none else 30000..600000): `BestMs, WeekId, WeekBestMs, Races, Finishes, Wins, Podiums, Perfects, DayId, HourStart, HourCount`. Op `Record`: validate `place 0..24`, `field 1..24`, integer `timeMs`, booleans; `Races += 1`; `Finishes += finished`; `Wins += (place == 1 and field ≥ 2)`; `Podiums += (place ≤ 3 and field ≥ 3)`; `Perfects += perfect`; `BestMs = min` when finished and timeMs ≥ 30000; week rollover (`WeekId ~= weekId` → `WeekBestMs = 0, WeekId = weekId`) then min; when rewarded: `now - HourStart ≥ 3600` → reset HourStart/HourCount, `HourCount += 1`, `DayId = max(DayId, dayId)`. Invalid → `{ok=false, error={code="InvalidInput", ...}}`.

#### 9. Services/Race/RaceLeaderboard.luau
- Stores (ascending, key `U_<userId>`): all-time `U4.Race.Leaderboard.AllTimeStore` ("SpeedsterEscape_RaceBestMs_v1"), weekly `WeeklyPrefix .. WeekId(now)`.
- Write only validated PBs (not `SessionDataOnly`, not DQ): coalesce `pending[userId] = min(ms)`, flush every 30 s, ≤20 writes per flush, `UpdateAsync(key, function(cur) if cur and cur <= ms then return nil end return ms end)`, 3 retries, Studio refusal handling copied from GlobalLeaderboards.server.luau:206-221.
- Read `GetSortedAsync(true, 50)` for both stores every 120 s; usernames through UserService with a cache (GlobalLeaderboards :439 pattern). Outputs: Workspace `RaceRecordMs`/`RaceRecordName` (weekly #1), player `RaceWeeklyRank`/`RaceAllTimeRank` (1..50 else nil), `RaceRequest("Board")` → `RaceEvent{kind="Board", weekly, allTime, you}` (≤ 1 per 2 s per player).
- The lobby board ("FASTEST RACERS") is a GlobalLeaderboards category owned by the titles workstream; it reads the same all-time store.

#### 10. Services/Race/RaceArenaBuilder.luau (Lune build + runtime fallback)
`Build(parent, env) -> Model` where `env = {Instance, Vector3, CFrame, Color3, Enum, UDim2, Font}` (in Roblox pass the globals; in Lune pass `@lune/roblox`). Creates `Workspace.RaceArena` (attribute `RaceArenaVersion = 1`): children `Structure` (`ModelStreamingMode = Persistent`: floor slabs 72×2×120 SmoothPlastic (0,186,240) + staging (0,160,215) with stud Texture 6794250394 (white, Transparency 0.82, 3 studs/tile); invisible walls 1×16×240 at x ±38.1; `StartGate` collider 72×16×1 at s +1.5 y 8, Transparency 1; back wall + collider at s -64; end wall at s 2120), `Decor` with `Chunk_k` models (`Atomic`, one per 240 studs: slot plates, white start line, red `StopBar` 74×1.4×0.5 at s +1 y 3 with 2 SurfaceGuis "STOP  STOP" (FredokaOne, white), barrier posts, start gantry (posts 2×20×2 at x ±40, navy beam 84×4×2, `Light1..5` Neon balls 2.4, cyan neon strip), curbs (245,245,250) + Neon (0,230,255) strips, spike tiles 7×0.4×7 (205,208,214) with two black (25,25,30) 4.6×0.12×4.6 star plates (the second yawed 45°) and attributes `RaceSpikeTile=true`, distance gantries at 500/1000/1500 (SurfaceGui "500 STUDS") + gold "LAST 200!" at 1800, checkered finish at 2000 + finish gate "FINISH"), chevrons (`U4.Race.Art.ChevronTexture` Texture when set; else part chevrons every 48 studs tagged `RaceDecorLowPower` via CollectionService/`AddTag`), `RaceOrb` (`Persistent`: Neon core ball 20 (150,235,255) + ForceField shell 28, PointLight range 60, sparks emitter rate 10, BillboardGui `OrbMarker` "▼ ORB") at s 2060 y 34. Every part Anchored, `CastShadow=false`, decor `CanCollide/CanTouch/CanQuery=false`, arena parts attribute `RaceArenaPart=true`. Budget ≤ 330 parts with the texture, ≤ 600 with part chevrons. Yaw only with `CFrame.Angles(0, θ, 0)`; set `Attachment.CFrame`, never Position.
- `BuildGate(parent, worldKey, env)`: model `Workspace.RaceGate` (arch ~24×12, Neon cyan trim, "RACE" SurfaceGui) + pad part `RaceGatePad` at `U4.Race.Gate[world]`, facing `Face`, BillboardGui anchor `RaceGateSign` (the client fills it), pad wired by RaceService with `PadTouchService.Connect`.

#### 11. Entry `Gameplay/RaceServer.server.luau` and changes elsewhere
- If `U4.IsOn("Race")`: build the arena when `Workspace.RaceArena` is missing and the gate when `Workspace.RaceGate` is missing (runtime fallback; normally the build authors both into the places), create remotes `RaceRequest` (RemoteGuard 0.25), `RaceSprint` (LatestStateLimiter 0.05), `RaceChargeInput` (LatestStateLimiter 0.08), `RaceEvent`, `RaceLive` (UnreliableRemoteEvent), start RaceLeaderboard + RaceService, set `_G.SpeedsterRace = {Join, Leave, IsRacing, StartMegaEvent, StopMegaEvent}`.
- `SonicBurstService.server.luau` `readyCharacter` (:196-213): refuse while `RaceActive`.
- `FlightService.luau` (:395-410): treat `RaceActive` like `AdminFlying` (flight not active).
- `AfkZoneService.server.luau` `enter` (:325-331): refuse while `RaceActive`; if only `RaceState == "Queued"`, call `_G.SpeedsterRace.Leave(player, "Afk")` first.
- `StageTeleportService.luau`: export `StageTeleportService.ArmArrivalGrace = armTeleportInvulnerability` (local at :29).

#### Acceptance
- Honest client model with 0-300 ms jitter finishes with 0 corrections; newcomer vs endgame ≤ 1.5 s apart; perfect start worth 0.8-1.5 s; each spike 0.8-1.5 s; same caps with world walk multipliers 1/0.5/0.25.
- Rewards: W1/W2/W3 winner = 6 % of LapWins at ×1; hourly max ≤ 2.1 laps; DQ/idle pay 0; one Commit per racer, never paid twice.
- Arena: in every place ≥ 1500 studs from every other BasePart; floor top at Origin.Y ± 0.02; walls continuous; budget respected.

#### Tests
- `test_u4_race_math`: stat bonus monotone ≤0.06; 1e2 vs 1e15 ≤1.5 s; Step identical distance at dt 1/24 vs 1/240 within 0.5 %; sprint seconds 4.0/5.0; spike cost 0.8-1.5 s; paced sprint beats greedy; absolute best > 30000 ms; RaceTrack slots distinct in staging, every spike row leaves ≥1 free lane, ToLocal/ToWorld round trip, SpikeAt matches rects.
- `test_u4_race_charge`: Evaluate vs 1/2000 s numeric integration within 1e-3 on 300 random edge lists (incl. overheat); outcome table (never/hold-from-open/late/closed loop 0.10 and 0.28 s/single press never Perfect); grace; assist; judge clamping (future, stale, reordered, >40 edges, NaN, wrong raceId), accepted edges immutable, honest edges → judge == client prediction; StartMultiplier integrals Perfect +0.83 s, Good +0.33 s, Stall −0.63 s (±0.01), exactly 1 after τ 2.5.
- `test_u4_race_rewards`: field table; W1 progress at rebirths 0/3/6 = 0.0204/0.327/1.0; winner = 6 % LapWins; hourly cap ≤ 2.1 laps; Speed clamp; ×32 wins multiplier × Mega × daily never exceeds 2^53-1; DQ and DNF < 25 % pay 0; RaceSection Record rules (PB min, week rollover, hour window, wins only field ≥2, invalid rejected); same operationId twice pays once (fake DataService).
- `test_u4_race_validation`: honest jitter/loss → 0 corrections; ×1.3 speed corrected within 2 s; teleport to the finish → DQ after 3 strikes; ignoring spikes gains ≤ 40 studs per spike and is corrected; false start pulled back; fall recovered without DNF; corridor exit → DNF Left.
- `test_u4_race_lifecycle` (fake clock/players): Idle→Gathering at 2; 5 s when full; solo trial after 25 s; stream timeout drop; 15 s finish grace; requeue; refusals (AFK, tutorial not seen and 0 rebirths, dead, double join); death → DNF; PlayerRemoving; Mega (16, ×2, restart gathering); invite 300 s cooldown and lobby-only; `_G.VortexMovementGuardRebase` called on every arena teleport.
- `test_u4_race_leaderboard`: WeekId boundaries on Monday 00:00 UTC; min-only UpdateAsync cancels non-PB; ≤20 writes/flush; Studio refusal disables quietly; ranks only for top 50.
- `test_u4_race_arena`: builds in Lune with `@lune/roblox` and checks the budget, Anchored/CastShadow, decor CanQuery/CanTouch false, Structure/Orb Persistent, wall continuity; with `places`: `Workspace.RaceArena` present in all 3 places and ≥1500 studs from every other BasePart.
- `test_u4_race_placement` (`places`): each Gate pad sits on a collidable floor within 3 studs and ≥12 studs from spawn, AFK spot, disco floor, admin treadmill, wheel, portal and treadmills.

### 7.4 race_client — Race HUD, input (charge + sprint), movement override, lobby entry, results

**Goal.** Everything the racer touches: the race HUD that looks like the references (2.webp countdown/MPH bar/stamina bar/ORB readout; 3.png "Race in progress" + top-3 podium with purple rewards), the charge-start input and gauge on touch/PC/console, the local speed prediction that drives `WalkSpeed`, the lobby Race button + invite toast + Race panel (join, rewards, fastest racers), the results window, arena client visuals, and hiding the normal HUD during races.

**Owns (create):**
- `src/common/ReplicatedStorage/Shared/RaceHudLayout.luau` (pure numbers), `Shared/RaceUiKit.luau` (style recipe), `Shared/RaceUiBuilder.luau` (pure Instance builders, Lune-compatible, env-injected like SpinWheelExtras), `Shared/RaceText.luau` (10 languages)
- `src/common/StarterPlayer/StarterPlayerScripts/Race/RaceInputClient.client.luau`
- `src/common/StarterPlayer/StarterPlayerScripts/UI/RaceHudController.client.luau`, `UI/RaceLobbyController.client.luau`
- `src/common/StarterPlayer/StarterPlayerScripts/Gameplay/RaceArenaVisuals.client.luau`
- tests `audit/test_u4_race_hud_layout.luau`, `audit/test_u4_race_ui.luau`, `audit/test_u4_race_client_static.luau`
**Owns (change):** `src/common/StarterPlayer/StarterPlayerScripts/Movement/InstantMovementController.client.luau`, `Movement/SpeedsterClient.client.luau`, `Movement/SonicBurstClient.client.luau`, `src/common/ReplicatedStorage/Shared/InterfaceHider.luau`, `StarterPlayerScripts/Gameplay/LowPowerGraphics.client.luau`, `audit/test_fable_interface_hider.luau`.

**Consumed contracts** (do not redefine): `Shared/Update4Config.luau` (`U4.Race.*`, `U4.IsOn`), `Shared/RaceTrack.luau`, `Shared/RaceMath.luau`, `Shared/RaceChargeMath.luau` (race_server; APIs: `RaceTrack.ToLocal/ToWorld/SpikeAt/DistanceLeft/SlotCFrame/LaneX`, `RaceMath.Caps/NewState/Step/SpikeHit/Accel/SprintSeconds`, `RaceChargeMath.Evaluate/Outcome/StartMultiplier`). Remotes (created by the race server in `ReplicatedStorage.Remotes`): `RaceRequest` (`"Join", source` with source `"Hud"|"Invite"|"Results"|"Panel"`; `"Leave"`; `"AutoRequeue", bool`; `"Board"`), `RaceSprint(on)`, `RaceChargeInput(raceId, edges, final)` (cumulative server-clock edges, odd = press, even = release), `RaceEvent` (kinds Queued, Unqueued, Staged, Start, Stumble, Correction, Finished, Results, Board, Toast, Invite), `RaceLive` (4 Hz `{id, t, left, n, top={{u,s,f}}, you={place,s,pool,strikes}}`). Workspace attributes `RacePhase`, `RacePhaseEndsAt`, `RaceGoAt`, `RaceId`, `RaceQueueCount`, `RaceMaxPlayers`, `RaceEventUntil`, `RaceEventMultiplier`, `RaceRecordMs`, `RaceRecordName`. Player attributes `RaceState`, `RaceActive`, `RaceMovementLocked`, `RaceSlot`, `RaceCruiseSpeed`, `RaceSprintSpeed`, `RaceSprintSeconds`, `RaceRegenFactor`, `RaceRewardMultiplier`, `RaceStartGrade`, `RaceFinishes`, `RaceBestMs`, `RaceWeeklyRank`, `RaceAllTimeRank`. MenuEvents names `Race = "OpenRacePanel"` → gui `RacePanelGui` (added by the integrator, also to ModalJuice `{"Window"}`, ConsoleUiScale and MODAL_SCREEN_GUIS together with `RaceResults`). Funnel client step: `Remotes.FunnelReport:FireServer("Onboarding_Race", 1)` in `pcall`.

**Local-only attributes you write** (client `SetAttribute`, never replicated): player `RaceLocalSpeed` (walk speed the movement controller must use), `RaceChargeLocal` (0..1), `RaceStaminaLocal` (0..1), `RaceLocalSuper` (bool: predicted `v ≥ 0.97*Vs`). race_fx reads them for poses/VFX and writes `RaceFovTarget`.

#### 1. RaceInputClient.client.luau — the single owner of race input and prediction
- Phase from Workspace `RacePhase`/`RaceGoAt` and player `RaceState`. Charge window: `goAt - 3.0 .. goAt`; Set (movement locked) from Staging.
- **Inputs**, bound only while `RaceActive` (ContextActionService `BindActionAtPriority("RaceAction", h, false, Enum.ContextActionPriority.High.Value + 200, ...)`):
  - Countdown (charge): PC `Space`, `LeftShift`, `RightShift` + UserInputService MouseButton1 when not gameProcessed; console `ButtonR2`/`ButtonL2` analog (`Position.Z ≥ 0.35` press, `≤ 0.20` release) + `ButtonA`; touch the action button.
  - Running (sprint hold): `LeftShift`/`RightShift`, `ButtonR2`/`ButtonL2`, touch action button (Space stays jump). Send `RaceSprint:FireServer(on)` on edges only.
  - Holding the charge input through GO turns into sprint on the same frame.
- Charge: record edges with `Workspace:GetServerTimeNow()`; send the cumulative list on each edge (≤ every 0.08 s) and once with `final=true` at GO; each RenderStepped draw `RaceChargeMath.Evaluate(localEdges, openAt, goAt, now)` → `RaceChargeLocal`; at GO predict the grade (grace when `RaceFinishes < 3`) and start `RaceMath` with `v0 = Vc*Launch[grade]`; when `RaceEvent Start{grade}` differs, switch to the server grade from the current τ.
- Prediction on Heartbeat (only while `RaceActive`): input `forward = max(0, MoveDirection·(0,0,-1))` if within 70°, `grounded = FloorMaterial ~= Air`, `jumped` on Jumping; `RaceMath.Step` → write `RaceLocalSpeed` (0 while `RaceMovementLocked`), `RaceStaminaLocal`, `RaceLocalSuper`; local spike check `RaceTrack.SpikeAt` on the root position → `RaceMath.SpikeHit` (instant feel; the server confirms with `Stumble`); `Correction{s, v}` → set the model's s/v. Sounds: charge hum (`U4.Race.Feel.Sounds.ChargeHum`, pitch `0.8 + 0.5g`), zone tick, overheat; gamepad haptics `HapticService:SetMotor(gamepad, Small, 0.4*g)`, `Large 0.8` for 0.15 s on Perfect; respect `SoundEffects ~= false` and `GuiService.ReducedMotionEnabled` (pcall).
- Touch: during Countdown save and zero local `Humanoid.JumpHeight`/`JumpPower` (hides TouchJump); restore at GO, death, CharacterRemoving and race exit.
- Onboarding: the first time the Race button becomes visible, an Invite toast shows, or the player is within 60 studs of the Race Gate → `FunnelReport:FireServer("Onboarding_Race", 1)` once per session.

#### 2. Movement and sprint integration (changes)
- `InstantMovementController.client.luau`: in the walk-speed composition (:893-972) while `player:GetAttribute("RaceActive") == true`, `movementWalkSpeed = tonumber(player:GetAttribute("RaceLocalSpeed")) or 0`, ignoring IsBoosting, confetti (:905-908), the sonic ratio (:961) and the world scale; while `RaceMovementLocked`, 0 and no jumps. `isExcludedBouncePart` (:583-606) returns true for parts with `RaceArenaPart`. Other characters are already non-collidable (:338-350).
- `SpeedsterClient.client.luau`: `setBoosting` (:193-216) forces `value = false` while `RaceActive` (so no BoostState, no SprintHeld, no Sonic Burst charge; the UIS listeners and gamepad polling at :949-975 bypass CAS, hence this guard); the FOV loop (:1095-1113) uses `player:GetAttribute("RaceFovTarget")` as the target when it is a number (race_fx writes it); CameraPunch offset still added.
- `SonicBurstClient.client.luau`: the SprintHeld listener (:626-630) ignores input while `RaceActive`.

#### 3. HUD — ScreenGui `RaceHud` (DisplayOrder 60, ScreenInsets CoreUISafeInsets, ResetOnSpawn false, ZIndexBehavior Sibling), built at runtime by `RaceUiBuilder.BuildHud()`
Style (`RaceUiKit`, copied from AdminAbusePanelController PALETTES :97-105, paint :201, tile :225, button :249, studPanel :331, plate :345; the controller itself is not refactored): stud sheet 135496826236732, 3-stop fill, inset white rim, dark edge, FredokaOne white text with ink (11,27,45) outline.
`RaceHudLayout.Plan(W, H, input, topBar)` returns rects `{Left, Top, Right, Bottom}` (H = height under the top bar; `compact = HudErgonomics.IsCompact`; console adds `HudErgonomics.SafeInset` 0.05; margins mx = console 0.05W / compact 12 / 20, mt = console 0.05H / compact 6 / 12):
- **Speed bar**: h = clamp(round(H·(compact 0.088 : 0.06)), 28, 64); w = 11h capped at W·(compact 0.50 : 0.42); touch: w ≤ 2·(action.Left − 12 − W/2); centre (W/2, H·(compact 0.80 : 0.845)); fill gradient (120,225,255)→(30,150,255)→(20,80,210), UICorner h/2, UIStroke ink 3; text "MPH: 84 / 98" (MPH = studs/s × `U4.Race.Hud.MphPerStud`, max = RaceSprintSpeed), TextSize round(0.62h). Lightning icon 123961542220277 at the left end, Rotation −10.
- Labels row above the bar: "Multiplier: x2" (`RaceRewardMultiplier`, colour (215,255,70)) left, "MPH/s: +6" (`RaceMath.Accel`) right.
- **Stamina bar** (race pool `RaceStaminaLocal`) under the bar: w 0.8·bar, h max(12, round(0.36h)), fill (0,235,255), text "STAMINA 80%".
- **Charge gauge** (Countdown and 0.8 s after GO): PC/console horizontal gauge w 0.62·bar, h max(16, round(0.5h)), centred above the labels; touch = ring around the action button (radius size/2 + 10, thickness 8). Bands from `U4.Race.Charge`: zone 0.58-0.84 green (60,230,120) with 45° stripes, core 0.65-0.77 gold (255,210,60) with glow, overheat area ≥0.97 red; needle white. Hint text "HOLD [SHIFT] TO CHARGE" / "HOLD [R2]" (glyph `UserInputService:GetImageForKeyCode(Enum.KeyCode.ButtonR2)`) / "HOLD CHARGE" and "STAY IN THE GREEN!", "EASY ZONE" when assisted. At GO the gauge pops and fades in 0.25 s and a banner shows 0.9 s ("PERFECT START! +45%", "GOOD START! +22%", "STALLED!").
- **Countdown**: number centre (W/2, 0.40H), height clamp(round(0.30H), 96, 300), pop UIScale 1.45→1 (Back Out 0.28 s); "GO!" green, fades after 0.7 s; "STARTING: 3s" label above it (Rotation −4). The top centre is used only during these 5 s.
- **Status + podium (top-left)**: title "Race in progress: 40s" / "Get ready!" / "Finished! 2nd"; podium cards C = clamp(round(0.12H), 52, 118), sides 0.82C, order 2nd-1st-3rd; card = `rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150` on (96,118,150), stroke gold (255,211,33)/silver (200,210,225)/bronze (205,127,50), cyan + "YOU" chip for the local player, name strip, rank badge, reward "+359" purple (190,95,255) with stroke (40,0,80) and the Wins icon `U4.Race.Hud.RewardIcon` (estimated reward for the current place, final value from Results). "You · 7th/12" pill when not top 3. On phones the podium's right edge < 0.35W.
- **Goal readout (right)**: "▼ ORB" gold, "1,234 studs" (`RaceTrack.DistanceLeft` + 60 to the orb) and elapsed "0:27.4".
- **Action button (touch only)**: side clamp(round(min(W,H)·0.19), 60, 84), right edge = jump.Left − `HudErgonomics.SprintGap`, centre y = jump centre (`HudErgonomics.JumpButton`); player-moved Sprint → `HudErgonomics.CustomPiece(layout, "S", W, H, side, side, true)`; label "CHARGE" then "BOOST"; ring shows the pool; red palette under 10 %.
- **Feedback text** centre (W/2, 0.30H): "OUCH! SPIKES", "FINISHED 2nd!", "NEW BEST!".
- Update rates: bars lerp on RenderStepped only while changing; text ≤10 Hz with TextScaled off on changing labels; podium per RaceLive packet; headshots cached per UserId.
- **Hide the normal HUD**: `InterfaceHider.Hide("Race", {raceHud, raceResults, "TouchGui"})` when `RaceState` becomes `Staged`; `Show("Race")` on exit/death/respawn.

#### 4. Results — ScreenGui `RaceResults` (DisplayOrder 125), `GamePanelStyle.BlockyWindow` 640×420, title "RACE RESULTS", root frame named `Window`, image named `Icon`
Place banner ("1ST PLACE!" gold/silver/bronze or "7TH / 12"), time + gold "NEW BEST!" tile, best time, mini podium (88/72 cards), reward chips (Wins, Speed, Spin Ticket, "x2 FIRST RACE TODAY", "reduced after 30 races/hour" note when `CapReduced`), buttons **RACE AGAIN** (Green, 220×62 → `RaceRequest("Join","Results")`, keeps auto-requeue on) and **LOBBY (8)** (Navy, 200×62, 8 s auto → `RaceRequest("Leave")`; Close = Lobby). Opens on the local Finished or DNF. Console: `ConsolePanelSupport.Bind(gui, window, raceAgain, lobby)`; A = race again, B = lobby.

#### 5. Lobby — ScreenGui `RaceLobbyHud` (DisplayOrder 5) + `RacePanelGui` (RaceLobbyController)
- **Race button** top-left: left = `Mainhud.LeftSideBar.AbsolutePosition.X`, top compact 8 : 12 (console 0.05H); phone 104×40, desktop w = clamp(0.11W, 150, 210), h = w/2.6; palette Blue + lightning icon; line 2 state: next-race timer / "JOIN!" (UIScale pulse 1→1.08 every 1.2 s + red "!") / "IN QUEUE ✓" (Green) / "LIVE 0:32" / "MEGA RACE!" (gold, while `RaceEventUntil > now`). Click → `MenuEvents.Request("Race")`. Gamepad DPadRight opens it. Hidden when `U4.IsOn("Race")` is false or `FirstTimeTutorialSeen ~= true and Rebirths < 1`.
- **Invite toast** under the button (desktop 330×86, phone 250×64, slides in 0.3 s Back): avatar stack ≤4, "RACE IN 0:15!", "5 racers · up to +X Wins" (X = `RaceMath.ComputeRewards` for 1st with the player's stats), Green JOIN (→ `"Join","Invite"`) and "x". Shown on `RaceEvent Invite` only when not queued, `AfkModeActive ~= true`, `GuidedTutorialOpen ~= true`, `InterfaceHider.IsHidden()` false and `MenuEvents.AnyOpen()` false; hides after 10 s; after 2 dismissals only every 3rd invite this session.
- **Race panel** `RacePanelGui` (BlockyWindow 720×460, title "RACE", root `Window`): left column NEXT RACE timer, "5 / 12 racers ready", JOIN RACE (Green) / LEAVE QUEUE (Red), rewards panel (1st/2nd/3rd/Finish from `RaceMath.ComputeRewards`, "First race today: x2 + Spin Ticket"); right column "FASTEST RACERS" with Weekly/All-time tabs, "Your best: 31.20s · #123", ScrollingFrame 52 px rows (medal/rank, round headshot, name, gold time; top 3 tinted; own row cyan) from `RaceRequest("Board")` → `RaceEvent Board` (≤1 per 2 s). `MenuEvents.MarkReady("Race", isOpen and not isClosing)`; ModalJuice; phone scale from BlockyWindow.
- **Gate sign**: fill the BillboardGui `Workspace.RaceGate.RaceGateSign` (built by the race server) with "RACE" + phase/timer + "Weekly record 31.20s by Name" from Workspace attributes.

#### 6. RaceArenaVisuals.client.luau
Driven by Workspace `RacePhase`/`RaceGoAt`: gantry lights turn red one per second from `goAt − 5`, all green (70,230,90) at GO; `StopBar` tweens to y −1.2 in 0.25 s (Back In) and the local `StartGate.CanCollide = false` on the same frame; both restored at the next Countdown. Orb shell spins 20°/s. Fog only while the local root is inside the arena box (|x−6000| < 200, −200 < s < 2300): save FogColor/FogStart/FogEnd, set (196,222,240)/450/2600, restore on exit only if the values are still ours; never touch Brightness/Ambient/ClockTime. Phones (touch, no keyboard): `LowPowerGraphics` hides `RaceDecorLowPower`-tagged parts (Transparency 1 as they stream in via CollectionService) and sets the Orb emitter rate to 4.

#### 7. Localisation — `Shared/RaceText.luau`
~35 keys (HUD, gauge, results, lobby, toasts incl. `RaceLockedTutorial`, `StreamTimeout`) in the 10 TutorialText languages via `TutorialText.LanguageFor(player.LocaleId)`, `FontFor`, `Style` (Builder Sans for ru/ar/th); `AutoLocalize = false`; numbers via the game's NumberFormat. Spanish/Portuguese strings must be natural (≈34 % of players).

#### 8. InterfaceHider (keep ScreenGuis by name)
`Hide(owner, keep)` accepts strings in `keep` (ScreenGui names): `kept(gui)` checks `keep[gui] or keep[gui.Name]` (:47-57); the "already hidden" branch (:76-92) also restores covered guis whose Name is kept. Shares the ledger with the portal/admin cinematics.

#### Acceptance
- Countdown → GO → run → results works identically on touch, keyboard and gamepad; the jump button hides only during the countdown and always comes back.
- `RaceLocalSpeed` drives WalkSpeed only while `RaceActive`; outside races nothing changes (BoostState, FOV, Sonic Burst unaffected).
- Screens 812×339, 667×339, 2340×1080, 1024×732 touch, 1366×730, 1920×1022, 1920×1080 console and 3840×2160 have no overlaps (6 px) among bar, stamina, gauge, hint, number, podium, goal, action button and the Roblox jump button; console inside 5 %; action button ≥ 56 px and ≥ 30 px from jump; every text ≥ 11 px.
- Client cost: at most 2 per-frame connections while racing (Heartbeat prediction + RenderStepped UI), both disconnected outside races.

#### Tests
- `test_u4_race_hud_layout`: the screen list above with the rules above; podium right < 0.35W on phones.
- `test_u4_race_ui`: RaceUiBuilder builds RaceHud/RaceResults/RaceLobbyHud/RacePanelGui in Lune; no scripts inside; ResetOnSpawn false; ZIndexBehavior Sibling; root frames named `Window` with `Icon`; RaceText has every key in all 10 languages within each label's length cap.
- `test_u4_race_client_static`: source checks — SpeedsterClient.setBoosting reads `RaceActive`; InstantMovementController reads `RaceLocalSpeed` and `RaceMovementLocked` and excludes `RaceArenaPart` from bounce; SonicBurstClient gates SprintHeld on `RaceActive`; RaceInputClient binds/unbinds only while `RaceActive` and restores JumpHeight on every exit path; no `Workspace:GetDescendants()` in new client files; ≤2 per-frame connections, each disconnected.
- `test_fable_interface_hider` (update): `Hide("Race", {gui, "TouchGui"})` leaves a later-added TouchGui uncovered, Show restores the rest, overlap with the portal owner still works.

### 7.5 race_fx — R6 race poses (Flash crouch / run / super), Vegeta-style charge and lightning VFX, bubble distortion

**Goal.** Make the race look great on every device without costing phones FPS: three procedural R6 poses drawn locally for every racer, charge sparks in the hands (Steal a Hero Vegeta "Charge"/"Burst" parameters), a launch burst, lightning arcs at super speed, and the owner's `BubbleModule` glass bubble when a racer breaks into super speed. Client-only, pooled, tiered.

**Owns (create):**
- `src/common/ReplicatedStorage/BubbleModule.luau` — the ModuleScript `BubbleModule` **byte-identical** to the Source inside `C:\Users\Aoshy´\Desktop\Update2\BubbleModule (2).rbxm` (read it with Lune `roblox.deserializeModel`; LF endings). The build (integrator) parents the rbxm's child MeshPart `Mesh` under it at `ReplicatedStorage.BubbleModule.Mesh` with Anchored=true, CanCollide/CanTouch/CanQuery/CastShadow=false, Massless=true, the child Highlight kept **disabled** (never enable it: each enabled Highlight is a full-screen pass).
- `src/common/ReplicatedStorage/Shared/RacePose.luau`, `Shared/RaceFeelTier.luau`, `Shared/RaceVfx.luau`
- `src/common/StarterPlayer/StarterPlayerScripts/Race/RacePoseClient.client.luau`
- tests `audit/test_u4_race_pose.luau`, `audit/test_u4_race_vfx.luau`
**Owns (change):** `src/common/StarterPlayer/StarterPlayerScripts/Movement/SupermanFlight.client.luau`, `src/common/StarterPlayer/StarterPlayerScripts/Movement/SurfboardPose.client.luau`.

**Consumed contracts:** `Shared/Update4Config.luau` → `U4.Race.Feel` (Pose, Vfx, Camera, Sounds) and `U4.Race.Super`; Workspace `RacePhase`, `RaceGoAt`; player attributes (replicated) `RaceActive`, `RaceState`, `RaceChargeLevel` (0..10, ≤4 Hz), `RaceStartGrade`, `RaceSuperSpeed`, `RaceSprintSpeed`; local-only attributes written by race_client on the local player: `RaceChargeLocal` (0..1), `RaceLocalSpeed`, `RaceLocalSuper`. Existing modules: `SurfboardStance.Transform(c0, rot)` (SurfboardStance.luau:50-53), `CameraPunch.Fov(size)` / `Shake(duration, strength)` (CameraPunch.luau:17-28). **You write** the local player attribute `RaceFovTarget` (read by SpeedsterClient's FOV loop, owned by race_client) and the local character attribute `RacePosed`.

#### 1. RacePose.luau (pure; conventions of SurfboardStance/SupermanFlightPose)
Rotations are in the joint's parent-part space about the joint, keyed by R6 Motor6D names, converted with `SurfboardStance.Transform(motor.C0, rot)`: `+X` on a hip/shoulder swings the limb forward, `−X` on RootJoint pitches the torso forward, `+X` on Neck tips the head up.
- `Set(g, t, seed)` — Flash crouch: `p = 66° + 4°g`, `L = 1.05 + 0.08g + 0.03 sin(2π·1.4t)`; RootJoint `CFrame.new(0, −L, 0)·Angles(−p, 0, 0)·jitter` with `jitter = Angles(j·n1(t), 0, j·n2(t))`, `j = rad(0.3 + 2.5·max(0, (g−0.84)/0.16))` (18 Hz value noise; steady in the zone, trembling when overcharged); Left Hip `Angles(p+38°, 0, −4°)`, Right Hip `Angles(p−42°, 0, +4°)`; shoulders `Angles(p+4°, 0, ±8°)`; Neck `Angles(52°, 0, 0)`.
- `Run(phi, s, t)` — s = clamp(speed / RaceSprintSpeed, 0, 1): lean `p = 10° + 10°s`, leg amp `A = 34° + 10°s`, arm amp `B = 40° + 15°s`; RootJoint `CFrame.new(0, −(1−cos p) − 0.18 sin²φ, 0)·Angles(−p, rad(6) sin φ, 0)`; Right Hip `Angles(p + A sin φ, 0, 0)`, Left Hip `Angles(p − A sin φ, 0, 0)`; Right Shoulder `Angles(10° − B sin φ, 0, 6°)`, Left `Angles(10° + B sin φ, 0, −6°)`; Neck `Angles(0.7p, −rad(3) sin φ, 0)`.
- `Super(phi, t)`: `p = 34° + 2° sin 2φ`; RootJoint `CFrame.new(0, −(1−cos p) − 0.28 sin²φ, 0)·Angles(−p, 0, rad(2) sin φ)`; hips `Angles(p ± 38° sin φ, 0, 0)`; shoulders `Angles(−42° + 4° sin(9t), 0, ±14°)` (arms swept back); Neck `Angles(26°, 0, 0)`.
- `StrideRate(s, tier) = clamp(1.6 + 2.0s, 1.6, U4.Race.Feel.Pose.StrideCap[tier])` Hz (≥ 9 frames per stride at 24 FPS on Low); `Blend(a, b, w)` per joint `CFrame:Lerp`.
- Launch (τ 0 → 0.22 s): Set → Run crossfade with ease-out-back; on Perfect the RootJoint pitch passes through 40°.

#### 2. RacePoseClient.client.luau (one script, every racer on this client)
- Characters of players with `RaceActive == true`. Pose phase: `Set` while Workspace `RacePhase` is `Staging`/`Countdown`; `Run` while Running and `RaceState == "Racing"`; `Super` when (local) `RaceLocalSuper` or (remote) `RaceSuperSpeed` held 0.35 s, exit after 0.25 s below; `Done` when `RaceState` is `Finished`/"" → blend out 0.3 s then one identity reset.
- On `RunService.Stepped` (after the Animator, as SupermanFlight.client.luau:143-166): `motor.Transform = motor.Transform:Lerp(SurfboardStance.Transform(motor.C0, target), w)`; `w` ramps 0→1 in 0.35 s at Set. Set the **local** character attribute `RacePosed = true` while posed. Remote crouch uses `g = RaceChargeLevel/10`; local uses `RaceChargeLocal`. Remote speed = root `AssemblyLinearVelocity` magnitude.
- LOD (camera distance, 4 Hz pass): High full rate ≤150 studs, 20 Hz ≤250, none beyond; Mid/Low full ≤60, 15 Hz ≤150, none beyond; the local racer always full rate.
- Camera (local racer, respect `GuiService.ReducedMotionEnabled` via pcall: no shake, half FOV punches, no flashes): Set → `RaceFovTarget = 70 − 6g`; GO Perfect `CameraPunch.Fov(22)` + `Shake(0.25, 0.35)`, Good `Fov(12)`; Super → `RaceFovTarget = 100` + `Fov(10)`; clear `RaceFovTarget` (nil) at Done.
- Calls into RaceVfx: `Prewarm` at Set, `SetCharge`, `Burst` at GO (grade from `RaceStartGrade`, predicted locally from `RaceChargeLocal` until it arrives), `SetSuper`, `Step(dt)` from one RenderStepped, `Release` at Done + 1 s.

#### 3. RaceFeelTier.luau
Computed once per race at Set (FPS = EMA of 1/dt over ≥ 2 s): **High** = not touch-only (`not (TouchEnabled and not KeyboardEnabled)`, as LowPowerGraphics.client.luau:10) and FPS ≥ 45; **Mid** = touch-only with FPS ≥ 30, or any device at 25-45; **Low** = touch-only under 30, any device under 25, or `UserSettings().GameSettings.SavedQualityLevel` ≤ 3 (pcall). `Budget(tier)` returns the table below.

| per race | High | Mid | Low |
|---|---|---|---|
| Own: Glass bubbles alive (pool) | 2 (3) | 0 Glass / 1 ForceField (2) | 0 |
| Own: arcs × segments, refresh | 3×4 +1 trail, 20 Hz | 2×3, 12 Hz | 1×3, 10 Hz |
| Own: emitters / PointLights | 6 / 2 | 4 / 0 | 2 / 0 |
| Own: particles/s (burst) | 140 (+80) | 60 (+40) | 30 (+20) |
| Other racer | ≤80 studs: 1 arc×4 @10 Hz, core 15/s, 1 Glass bubble on super entry ≤60 studs | ≤50: core 8/s | ≤40: core 6/s |
| All others particles/s cap | 120 | 40 | 24 |
| Glass on screen cap | 5 | 0 | 0 |
| CPU (pose + VFX, 8 racers) | ≤0.6 ms | ≤0.35 ms | ≤0.25 ms |
Glass is allowed on Mid only when SavedQualityLevel ≥ 8 was set by hand.

#### 4. RaceVfx.luau (client-only, pooled; no Instance.new/Clone/TweenService/Debris after Prewarm)
- Folder `workspace.RaceFx` (client-side). `Prewarm(character, tier, isLocal)` creates everything for that racer during Set (CPU idle): attachment `RaceFxPalm` at `CFrame.new(0, −1, 0)` on each R6 arm; emitters; arc segment parts (Neon, width 0.10-0.18, CanCollide/CanQuery/CanTouch false, CastShadow false); bubble slots = clones of `ReplicatedStorage.BubbleModule.Mesh` (Glass on High; `Material = ForceField`, Color (120,200,255) on Mid; none on Low) parked with Transparency 1 **at the racer's position** (never far away: float32 at y 12000).
- **Charge** (Vegeta, HeroClipPlayer.luau:618-700, textures are engine built-ins so nothing to upload): Charge1 (g ≥ 0.15, colour `Colors.Charge1`, k 0.9) core `rbxasset://textures/particles/sparkles_main.dds` Color white→tint, Size 1.1k→0.2k, Transparency 0.1→1, Lifetime 0.12-0.22, Rate 40g, Speed 0-0.5, Spread 180, RotSpeed ±300, LockedToPart, LightEmission 1, LightInfluence 0, ZOffset 0.5; sparks `rbxasset://textures/particles/fire_main.dds` Size 0.35k→0, Lifetime 0.2-0.4, Rate 30g, Speed −2.5…−1.2 (converging). Charge2 (inside the zone): colour `Charge2`, k 1.6, full rates, PointLight on High (Range 11.2, Brightness 2.5, Shadows off). Overheat: tint `Overheat`, sparks Rate 60 at Speed +2…+5, smoke puff `rbxasset://textures/particles/smoke_main.dds` Emit 6 when venting starts. Rates scaled by the tier budget.
- **Burst at GO**: per hand `Emit(40)` Perfect (Speed 9-18, colour `Burst`) / `Emit(20)` Good (Speed 6-12), Spread 60, EmissionDirection Bottom, Drag 4, Lifetime 0.25-0.55, Size 0.7→0; pooled launch ring (flat Neon cylinder, diameter 1→14 in 0.35 s, transparency 0.2→1, colour Charge1).
- **Super arcs** (SonicBurst bolt technique, SonicBurstClient.client.luau:204-216, :283-303): N arcs × K segments re-drawn at the tier refresh rate between random body points (torso → limb, radius 2.5), jagged midpoints ±0.6, each arc visible with p 0.7, colour `Arc`; High adds a trail arc 3-6 studs behind along −v̂.
- **Bubble distortion**: on entering super, one barrier bubble anchored at `root + v̂·2` aligned to travel, size 6³ → 30³ over 0.55 s, transparency 0.15 → 1 (same curve as `CreateBubble(cf, Vector3.new(6,6,6), 0.15, Vector3.new(30,30,30), 0.55)` with Sine Out `e = sin(α·π/2)`); while super, an envelope bubble every 0.45 s (High) / 0.9 s (Mid) following the root, (7,7,9) → (11,11,15) over 0.45 s, transparency 0.45 → 1. One RenderStepped (`Step`) drives all live bubbles; α ≥ 1 parks the part (Transparency 1). Never two Glass bubbles overlapping (transparent objects behind Glass do not render). `CreateBubble` stays available for one-off use; it is not called in the hot path.
- Sounds (only ids already used live; empty id = skipped; respect `SoundEffects ~= false`): super entry `SuperEnter` (pitch 1.25, vol 0.35) + `SuperBoom` (pitch 0.9, 0.4); other racers only the boom within 60 studs at 0.3; `SuperWind` is "" until the owner uploads one.
- 4 Hz distance/LOD pass (AuraSpecialEffectsClient.client.luau:216-222 convention); remote emitter rates scale down to stay under the cap. `Release` destroys everything at Done + 1 s.

#### 5. Stand-aside changes
- `SupermanFlight.client.luau` `standsAside` (:129-141): also true while the character attribute `RacePosed` is true.
- `SurfboardPose.client.luau` `standsAside` (:113-123): same; additionally, while `RaceActive`, hide the Silver Surfer board parts locally (`LocalTransparencyModifier = 1`) and restore them after the race.

#### Acceptance
- Two-client Studio test: the other racer's crouch, launch burst and super arcs are visible; the local player sees their own bubble on PC (Glass) and ForceField/no bubble on phone tiers; FPS delta < 2 ms with 8 bots racing on a phone emulator.
- No per-frame network traffic; no instance creation after Prewarm; no enabled Highlights.

#### Tests
- `test_u4_race_pose` (real R6 C0/C1 constants, no `CFrame.lookAt`): Set feet tips within [−0.15, 0.15] studs of the floor and hands ≤ 0.8 for g = 0 and 1; Run and Super feet ≥ −0.2 over a full cycle at s = 0, 0.5, 1; no NaN; weight 0 = identity; stride rate ≤ tier cap.
- `test_u4_race_vfx`: static source checks — no `Instance.new`, `:Clone(`, `TweenService:Create` or `Debris` inside `RaceVfx.Step`/`SetCharge`/`SetSuper`/`Burst`; every `Feel.Sounds` id is "" or one of 9114277757, 72264591133889, 9114615010, 9119382815; Low budget has no Glass and no PointLights; instance counts per tier match the table; SupermanFlight and SurfboardPose read `RacePosed`; `ReplicatedStorage/BubbleModule.luau` equals the rbxm Source (LF-normalised).

### 7.6 titles_boards — Titles system + leaderboard ranks + "FASTEST RACERS" lobby board

**Goal.** Players equip/unequip a title shown above their head; staff titles are automatic and cannot be spoofed; top 1/5/10 of the Speed, Wins and Race boards get live titles; race/streak/community titles are earned once and kept. The designer's "Titles" panel is used as-is. The all-time race board appears in each lobby next to the existing boards.

**Owns (create):** `src/common/ReplicatedStorage/Shared/TitleCatalog.luau`, `src/common/ServerScriptService/Services/Titles/TitleService.luau`, `src/common/ServerScriptService/Social/TitleSystem.server.luau`, `src/common/StarterPlayer/StarterPlayerScripts/UI/TitlesController.client.luau`, `src/common/ServerScriptService/Services/Data/U4/TitlesSection.luau`, `audit/u4_title_templates.luau` (Lune helper the integrator's build calls), `audit/u4_race_board.luau` (Lune helper the build calls), tests `audit/test_u4_titles.luau`, `audit/test_u4_title_service.luau`, `audit/test_u4_race_board.luau` (`places`).
**Owns (change):** `src/common/StarterPlayer/StarterPlayerScripts/UI/OverheadStats.client.luau`, `src/common/ServerScriptService/Social/GlobalLeaderboards.server.luau`, `src/common/StarterPlayer/StarterPlayerScripts/UI/GlobalLeaderboardDisplay.client.luau`.

**Consumed contracts:** `Shared/Update4Config.luau` → `U4.Titles` (OwnerUserIds, OwnerGroupRank 255, DeveloperUserIds {767108248, 111827288}, TesterUsernames (player.Name, lower-case), ContentCreatorUserIds, MaxOwned 40, NoticeAfterSessionSeconds 600), `U4.Race.Leaderboard.AllTimeStore` ("SpeedsterEscape_RaceBestMs_v1", ascending ms, written by the race server), `U4.Race.Board` (World1 "AfterWins", World2 "AfterRobux", World3 "AfterWins"), `U4.IsOn("Titles")`. Profile section `U4.Titles = {Pref, Owned}` through your `TitlesSection` (dispatcher by the integrator; commands `U4.Titles.Grant {id}`, `U4.Titles.Revoke {id}`, `U4.Titles.SetPref {pref}` — SetPref is **volatile**: call `DataService.ApplyVolatile(handle, {kind="U4.Titles.SetPref", pref=...})`, no DataStore write). Other workstreams grant titles by putting `{kind="U4.Titles.Grant", id=...}` in their own Commit and then calling `_G.SpeedsterTitles.Refresh(player)`. Bootstrap (integrator) calls `_G.SpeedsterTitles.Visual(player)` in `attachTitleToCharacter` and re-attaches when `EquippedTitle` changes. MenuEvents `Titles = "OpenTitlesPanel"` → gui "Titles" (integrator adds it with ModalJuice `{"Titles"}` and ConsoleUiScale). Funnel `Engagement_Titles` (1 Titles_Opened, 2 Titles_Equipped; recurring) via `FunnelAnalytics.Step` (QuestService.server.luau:25-33 loader). The designer ScreenGui "Titles" is put in StarterGui by the build (`Enabled=false`, `ResetOnSpawn=false`): root frame `Titles` with `Tittle`, `Icon`, `ScrollingFrame` (template rows `None` and `Top500`), `Close`, `Frame` (tab buttons All/Staff/Leaderboards/Ranked).

#### 1. TitleCatalog.luau (pure data)
Entry `{Id, Text, Tab ("Staff"|"Leaderboards"|"Ranked"|"All"), Priority, Style ("typewriter"|"shine"|"static"), Template ("Owner"|"Dev"|"Tester"|"Gold"|"Plain"), Colors = {Color3, Color3}, Unlock (hint text, en/es/pt), Source, Grantable?}`:
| Id | Text | Tab | Source | Template/Style |
|---|---|---|---|---|
| owner | OWNER | Staff | `U4.Titles.OwnerUserIds[uid]`, or the game creator (user: `game.CreatorType == Enum.CreatorType.User and uid == game.CreatorId`; group: `GetRankInGroupAsync(game.CreatorId) >= 255`, pcall) | Owner / typewriter, gold |
| developer | DEV | Staff | `U4.Titles.DeveloperUserIds[uid]` | Dev / typewriter (current look) |
| content_creator | Content Creator | Staff | `ContentCreatorUserIds[uid]` or granted marker (Grantable) | Plain / shine, purple-pink |
| tester | Tester | Staff | `TesterUsernames[string.lower(player.Name)]` (never DisplayName) | Tester / shine (current look) |
| speed_top1 / speed_top5 / speed_top10 | #1 SPEEDSTER / Top 5 Speed / Top 10 Speed | Leaderboards | rank on board "Speed" ≤ 1/5/10 | #1 Gold/shine; others Plain/static |
| wins_top1 / wins_top5 / wins_top10 | #1 WINNER / Top 5 Wins / Top 10 Wins | Leaderboards | board "Wins" | same |
| race_top1 / race_top5 / race_top10 | FASTEST RACER / Top 5 Racer / Top 10 Racer | Leaderboards | board "Race" | same |
| race_winner / race_champion / race_legend | Race Winner / Race Champion / Speed Legend | Ranked | marker (race server: 1/25/100 wins) | Plain/static; legend Gold/shine |
| lightning_start | Lightning Start | Ranked | marker (10 perfect starts) | Plain/static |
| member | Member | All | marker (Community reward; Grantable) | Plain/static green |
| streak_7 / streak_21 | Loyal Runner / Streak Legend | All | markers (Streak) | Plain/static; Gold/shine |
| vip | VIP | All | attribute `VIPGamepassOwned` | Plain/static gold |
Staff priority: owner > developer > content_creator > tester. Rank titles: a rank r owns every tier with top ≥ r (rank 3 owns top5 and top10).

#### 2. TitleService.luau (server module)
- `Start()`, `GetOwned(player) -> {[id]=true}` = staff checks (evaluated on join) ∪ current board ranks ∪ `U4.Titles.Owned` markers ∪ vip.
- `Grant(player, id, source) -> boolean`: only catalog marker ids; Commit `{kind="U4.Titles.Grant", id}` with operationId `u4title:<id>`; on success `TitlesNewCount += 1`, toast via `TemporaryBoostUpdate` `{Type="Retention", Message="New title: <Text>! Equip it in Titles"}`, `FunnelAnalytics` nothing, `Refresh`. `Revoke(player, id)` (admin): `U4.Titles.Revoke`.
- `SetBoardRanks(boardId, orderedUserIds)` ("Speed"|"Wins"|"Race"): stores rank per userId; refreshes affected in-server players only when their rank tier changed.
- `Equip(player, pref) -> ok, msg`: `pref` is `""` (auto), `"none"` or an owned catalog id; `DataService.ApplyVolatile(handle, {kind="U4.Titles.SetPref", pref})`; `FunnelAnalytics.Step(player, "Engagement_Titles", 2)`.
- Resolve rule: `""` → highest-priority owned **Staff** title (keeps today's automatic DEV/Tester), else none; `"none"` → none; an id → that id while owned, otherwise auto. The preference survives losing and regaining a rank title.
- Publishes player attributes `EquippedTitle` (id or ""), `TitlePreference`, `TitlesNewCount`; fires `TitlesUpdate` only when something changed.
- `Visual(player) -> {Id, Text, Template, Style, Color1, Color2}?` for Bootstrap.
- `_G.SpeedsterTitles = {Refresh = TitleService.Refresh, Grant = TitleService.Grant, Revoke = TitleService.Revoke, Visual = TitleService.Visual}`.
- New players see the Titles notice dot only after `NoticeAfterSessionSeconds` of playtime (the retention workstream draws the topbar icon; it reads `TitlesNewCount`).

#### 3. TitleSystem.server.luau
Creates `TitlesRequest`/`TitlesUpdate` (RemoteEvents in `ReplicatedStorage.Remotes`) wired with `RemoteGuard.Connect(remote, 0.3, ...)`. Actions: `"Get"` → `TitlesUpdate:FireClient(player, {Owned, Equipped, Preference, Ranks={Speed,Wins,Race}, Progress={[id]={Have,Need}}, New})` + `FunnelAnalytics.NewSession(player, "Engagement_Titles")` + `Step(…, 1)`; `"Equip", pref`; `"Seen"` → `TitlesNewCount = 0`. On `DataLoaded` → `Refresh`. Only when `U4.IsOn("Titles")` (otherwise attributes stay empty and Bootstrap falls back to Dev/Tester).

#### 4. TitlesController.client.luau (designer "Titles" panel, used as-is)
`PlayerGui:WaitForChild("Titles", 8)`; `MenuPanelLayout.BindPhoneFit(gui, gui.Titles, open, closed)` (MenuPanelLayout.luau:394); ModalJuice; `ConsolePanelSupport.Bind`; `MenuEvents.MarkReady("Titles", isOpen and not isClosing)`; listen `MenuEvents.Listen("Titles", open)`. Hide the template rows `ScrollingFrame.None` and `.Top500`; "None" stays as the first row (Equip = `"none"`); one clone of `Top500` per catalog entry: first TextLabel `Title` = Text, the second = unlock hint with live numbers ("Reach Top 10 Speed (you are #57)"), `Frame.UIGradient` = entry colours, button `onoff` reads Equipped / Equip / Locked (Locked greyed and inactive). Index children by order/class, never `FindFirstChild` on duplicated names. Tabs filter by `Tab` (All shows all); sort: equipped, owned by Priority, locked. Opening sends `"Get"`; first open sends `"Seen"`. Local strings en/es/pt (fallback en) via `TutorialText.LanguageFor`.

#### 5. OverheadStats.client.luau
`setupTitleAnimation` (:341-490): drive the look from `titlePart:GetAttribute("TitleStyle")` instead of the Smokes/"DEV" guess (:382) and the hard-coded `titleLabel.Text = "Tester"` (:481): `typewriter` = the existing DEV loop using the `TitleText` attribute (:441-477); `shine` = the existing Tester rotation tween with `TitleText`; `static` = no tweens, no thread. Without attributes keep today's behaviour (old servers). Stacking/AFK tag unchanged (:283-289).

#### 6. Title templates — `audit/u4_title_templates.luau`
`Insert(dm, notes)`: in `ReplicatedStorage.Titles` add `Plain` (a Tester clone with every ParticleEmitter removed), `Gold` (Tester clone keeping 2 emitters recoloured gold (255,211,33)), `Owner` (Dev clone recoloured gold); idempotent (replace existing with attribute `U4Asset`); stamp `U4Asset`. Return the count for notes.

#### 7. GlobalLeaderboards (server + display)
- `GlobalLeaderboards.server.luau`: add category `{Id="Race", Title="FASTEST RACERS", ColumnTitle="TIME", Primary=(0,190,235), Accent=(190,95,255), Dark=(6,22,48), Store=GetOrderedDataStore(U4.Race.Leaderboard.AllTimeStore), Ascending=true, ExternalWrites=true, Optional=true, Decode=cleanOrderedInteger, Format=function(ms) return string.format("%.2fs", ms/1000) end}` (:139-190). `publishPlayer` loop (:299) skips `ExternalWrites` categories. `refreshBoard` (:1027) uses `GetSortedAsync(category.Ascending == true, DISPLAY_COUNT)` and keeps `score > 0`. `hasImportedTargets` (:411-424) ignores categories with `Optional` whose parts are missing (and binds them only when present), so a place without `Race_*` parts keeps the other 3 boards. After `setBoardRows(state, entries, nil)` in `refreshBoard` call `TitleService.SetBoardRanks(category.Id, <userIds in order>)` (require via pcall; skip when missing). The #1 champion avatar comes from the existing route.
- `GlobalLeaderboardDisplay.client.luau`: add the Race category (same colours + RowA (8,40,78), RowB (6,32,64), Background (6,22,48)) to `categories` (:29-57) and the same `Optional` handling in `hasImportedTargets` (:124-137).

#### 8. Race board parts — `audit/u4_race_board.luau`
`Place(dm, worldKey, notes)`: in the place's `leaderboard1` model (W1 `Workspace.Folder.leaderboard1`, W2 `Workspace.leaderboard1`, W3 `Workspace.Lobby.leaderboard1`; find by name recursively) clone the 8 Wins MeshParts (LeaderboardFrame, LeaderboardScreen, LeaderboardScreenBorder, ChampionStandTop, ChampionStandTopOutline, ChampionPillarColumn, ChampionPillarBase, ChampionPillarOutline, prefixed `Wins_`) as `Race_*` into the same model, one row step (39.904 studs along the row) past Wins (W1/W3) or past Robux (W2, `U4.Race.Board`). Expected W1 screen ≈ (419.49, 37479.95, −1696.02); W3 row end z ≈ 415.61; W2 z ≈ −1083.77. Drop-test each part onto a floor; if it fails, place at the other end of the row. Idempotent via `U4Asset` stamps. Uses CFrame arithmetic only (no GetPivot/PivotTo/lookAt in Lune).

#### Acceptance
- A DisplayName of "gekkoh" gets no staff title; UserId 767108248 gets DEV. Staff titles show automatically as today; players can pick "none".
- Rank 3 on Speed owns top5 and top10 but not top1; losing the rank drops back to auto without losing the preference.
- Only Staff and #1 titles animate (phones render-bound).
- All 3 places keep their 3 boards bound with or without Race parts; with them, "FASTEST RACERS" shows times ascending.

#### Tests
- `test_u4_titles`: catalog ids unique and `^[a-z0-9_]+$`; tabs valid; templates exist in `ReplicatedStorage.Titles` of all 3 places after the build (`places`); styles valid; staff priorities ordered; TitlesSection Sanitize/Encode/Apply (Grant idempotent, Owned ≤ 40, SetPref pattern `^[a-z0-9_]*$` ≤ 32 chars, Revoke).
- `test_u4_title_service` (stubbed DataService/Players): SetBoardRanks rank 3 → top5+top10; rank loss → EquippedTitle falls back to auto; "" shows only staff; "none" nothing; Equip of a locked id refused; DisplayName spoof refused; Equip uses ApplyVolatile (no Commit).
- `test_u4_race_board` (`places`): all 3 places have 8 `Race_*` parts in `leaderboard1`, each within 0.5 stud above a floor and not intersecting other lobby parts; GlobalLeaderboards source has Race with `Ascending`, `ExternalWrites`, `Optional`; refreshBoard passes `category.Ascending`; Display has the Race category.
- Static: OverheadStats has no literal `"Tester"` assignment and reads `TitleStyle`.

### 7.7 retention — Playtime Boost + Streak Rewards (designer UIs) + left topbar entry points

**Goal.** Reward longer sessions (CCU) and daily returns (D1/D7) with the designer's "Playtime Boost" and "Streak Rewards" panels: +10 % Speed gain every 10 min (max +100 %) and +10 % per streak day (max +100 %) with milestone rewards on days 7/14/21. No timed DataStore writes. Clear but quiet entry points (topbar icons + toasts; one conditional auto-open).

**Owns (create):** `src/common/ReplicatedStorage/Shared/RetentionMath.luau`, `src/common/ServerScriptService/Social/RetentionService.server.luau`, `src/common/StarterPlayer/StarterPlayerScripts/UI/PlaytimeBoostController.client.luau`, `src/common/StarterPlayer/StarterPlayerScripts/UI/StreakRewardsController.client.luau`, `src/common/ServerScriptService/Services/Data/U4/RetentionSection.luau`, tests `audit/test_u4_retention_math.luau`, `audit/test_u4_retention_service.luau`, `audit/test_u4_topbar.luau`.
**Owns (change):** `src/common/StarterPlayer/StarterPlayerScripts/UI/TopbarIconsController.client.luau`, `src/common/StarterPlayer/StarterPlayerScripts/UI/DailyRewardController.client.luau`, `src/common/StarterPlayer/StarterPlayerScripts/Gameplay/BoostNotifier.client.luau`.

**Consumed contracts:** `Shared/Update4Config.luau` → `U4.Playtime` (StepSeconds 600, StepPercent 10, MaxPercent 100, ResumeGraceSeconds 900, TickSeconds 5, VolatileSaveSeconds 60, Markers {600,1800,3600,6000}), `U4.Streak` (PercentPerDay 10, MaxPercent 100, GraceEveryDays 7, CheckInDelaySeconds 60, CycleDays 21, MaxPending 6, MaxClaimedKept 64, Milestones First/Repeat), `U4.RetentionMultiplierCap` 3.4, `U4.IsOn("PlaytimeBoost"|"Streak"|"Titles"|"Community")`. Profile section `U4.Retention` (your `RetentionSection`; commands `U4.Retention.CheckIn {day}`, `U4.Retention.ClaimStreak {key}`, `U4.Retention.Playtime {seconds, lastSeen, sessionStart}` — the last one is **volatile**: `DataService.ApplyVolatile(handle, command)` (added by p0_data), never Commit). Speed gain: the integrator makes StatsService/PlayerStatsBridge multiply running/treadmill gains by the player attribute `RetentionSpeedGainMultiplier` (1 while `RaceActive`); you only publish the attribute. `_G.SpeedsterBeforeRelease` registry (Bootstrap.server.luau:493-513) for the leave save. Titles: put `{kind="U4.Titles.Grant", id="streak_7"|"streak_21"}` in the claim Commit and call `_G.SpeedsterTitles.Refresh(player)` if present. MenuEvents names (integrator): `Streak = "OpenStreakPanel"` → "Streak Rewards", `PlaytimeBoost = "OpenPlaytimeBoostPanel"` → "Playtime Boost", `Titles`, `Community`. Funnels (integrator): `Retention_Streak` (1 Streak_CheckedIn, 2 Streak_PanelOpened, 3 Streak_MilestoneClaimed; session `"<uid>-streak-<utcDay>"`), `Retention_PlaytimeBoost` (1 Playtime_10m, 2 Playtime_30m, 3 Playtime_60m, 4 Playtime_Max; pass the session id `"<uid>-pt-<PlaytimeSessionStart>"` explicitly), custom `Streak_Day7_v2`, `Streak_Day14_v2`, `Streak_Day21_v2`, `Streak_Reset_v2` via `FunnelAnalytics.Event`. Designer GUIs (put in StarterGui by the build, Enabled=false, ResetOnSpawn=false): "Playtime Boost" (root frame "Playtime Boost": Title, Close, Descri, Speed (label pair both named "Speed"), Info (markers "10M","30M","1H","Max"), Bar/Fill, Time) and "Streak Rewards" (root "Streak Rewards": Title, Close, Descri, Speed, Info ("7","14","21"), Icon (has `Time`), Bar, `Choose` button whose text wrongly says "Return to Offline Reward", three frames all named `Item1`). Index duplicated names by order / `Position.X`, never `FindFirstChild`.

#### 1. RetentionMath.luau (pure)
- `UtcDay(unix) = floor(unix/86400)`, `NextUtcMidnight(unix)`.
- `PlaytimePercent(seconds, cfg) = min(100, 10*floor(seconds/600))` → 10m 10 %, 30m 30 %, 1h 60 %, 100 min 100 %.
- `StreakCheckIn(state, day, cfg) -> newState, event ("same"|"next"|"grace"|"reset"), crossedKeys`: gap = day − LastDay; 0 → same; 1 → Days+1; 2 and `day − GraceDay ≥ 7` → Days+1, GraceDay = day ("grace"); else Days = 1 ("reset"). Best = max. `cycleDay = ((Days−1) % 21) + 1`, `cycle = floor((Days−1)/21) + 1`; crossing cycleDay 7/14/21 appends `"c<cycle>_d<7|14|21>"` to Pending (≤6; pending keys survive a reset).
- `StreakBonus(days) = min(100, 10*days)/100` (day 1 = +10 %: a newcomer immediately sees x1.1).
- `Multiplier(p, s, perk, cap) = min(cap, 1 + p + s + perk)` (additive; max 3.4 with the permanent perk 0.4).
- `MilestoneReward(key, cfg)`: cycle 1 uses `Milestones.First`, later cycles `Repeat` (7: Perk 0.2 + title streak_7; 14: Perk 0.4; 21 "Skull Chest": 5 Spin Tickets + 60 min x2 Speed potion + 60 min x2 Wins potion + title streak_21; repeat 7/14: 2 Spin Tickets + 30 min x2 Speed; repeat 21: chest without title).
- `PiecewiseFill(value, points)` for the bars (points = {{value, xScale}}).

#### 2. RetentionSection.luau (profile `U4.Retention`)
Section contract `Default/Sanitize/Encode/Apply(state, op, command, now)`. Fields: `StreakDays, StreakLastDay, StreakBest, StreakGraceDay` (ints ≥0), `StreakPerk` (0..0.4), `StreakPending` (≤6 strings matching `^c%d+_d%d+$`), `StreakClaimed` (≤64, keep newest), `PlaytimeSeconds` (0..6000), `PlaytimeLastSeen`, `PlaytimeSessionStart`. Ops: `CheckIn {day}` (applies `StreakCheckIn` with `day == UtcDay(now)` required); `ClaimStreak {key}` (key must be pending; move to Claimed; apply `Perk = max(Perk, milestone.Perk)`); `Playtime {seconds, lastSeen, sessionStart}` (clamped, volatile).

#### 3. RetentionService.server.luau
- Playtime (if `U4.IsOn("PlaytimeBoost")`): on DataLoaded read `U4.Retention`; if `now − PlaytimeLastSeen ≤ 900` keep seconds and SessionStart (world teleports, crashes, AFK rejoins), else 0 and `SessionStart = now`. A 5 s loop adds dt (counts every second in game with DataLoaded, AFK included — the goal is CCU). Every 60 s and in `_G.SpeedsterBeforeRelease.Retention` → `DataService.ApplyVolatile(handle, {kind="U4.Retention.Playtime", seconds, lastSeen=os.time(), sessionStart})`. Publish `PlaytimeBoostPct` and `PlaytimeSessionAnchor = Workspace:GetServerTimeNow() − seconds` only on join and on a step change (clients count down locally). On each step reached: `FunnelAnalytics.Step(player, "Retention_PlaytimeBoost", step, "<uid>-pt-<SessionStart>")`; after a teleport replay already-reached steps in order at DataLoaded (same session id). Toasts only at 10m and MAX.
- Streak (if `U4.IsOn("Streak")`): check-in once per UTC day after 60 s in game, and at the UTC rollover for players online (day checked every 30 s): Commit `{kind="U4.Retention.CheckIn", day}` with operationId `u4streak:<day>` (one write per player per day). Toast "🔥 Day 4 streak! x1.4 Speed" / "Streak saved!" / "Streak restarted" (TemporaryBoostUpdate `{Type="Retention", Message}`); `Step(player, "Retention_Streak", 1, "<uid>-streak-<day>")`; `Event("Streak_Day7_v2")` etc. at 7/14/21, `Event("Streak_Reset_v2")` on reset.
- Claim (`RetentionRequest("ClaimStreak")` claims the oldest pending): one Commit, operationId `u4streakclaim:<key>`, commands `{kind="U4.Retention.ClaimStreak", key}` + `{kind="GrantSpinTickets", amount}` + `{kind="GrantBuff", grant={kind="SpeedPotion"|"WinsPotion", addedSeconds=min*60, multiplier=2, bottleType="Small"}}` + `{kind="U4.Titles.Grant", id}` as the milestone says; `Step(…, 3)`.
- Attributes: `StreakDays`, `StreakPerk`, `StreakRewardPending` (bool), `StreakNextDayUnix`, `RetentionSpeedGainMultiplier = Multiplier(PlaytimeBoostPct/100, StreakBonus(Days), Perk, 3.4)` (1 while `RaceActive`; recompute on changes).
- Remotes `RetentionRequest` (`"Get"`, `"ClaimStreak"`; RemoteGuard 0.5 s; "Get" with panel "Streak" → `Step(…, 2)`) / `RetentionUpdate` `{Streak={Days,Best,Perk,CycleDay,Cycle,NextDayUnix,Pending,Claimed}, Playtime={Seconds,Anchor,Pct}, Multiplier, Message?}`. No `DataService.Commit` inside any timer loop.

#### 4. Panels (designer UIs used as-is; `MenuPanelLayout.BindPhoneFit`, ModalJuice, `ConsolePanelSupport.Bind`, `MenuEvents.MarkReady`)
- PlaytimeBoostController: `Speed` value label "+30% Speed"; `Time` = mm:ss to the next +10 % or "MAX"; `Bar.Fill` AnchorPoint (0, 0.5), `Size = UDim2.fromScale(frac, 1)` with `frac = PiecewiseFill(seconds, {{0,0},{600,m10},{1800,m30},{3600,m1h},{6000,mMax}})` where the m* are read at runtime from `Info["10M"/"30M"/"1H"/"Max"].Position.X.Scale` (≈0.148/0.331/0.594/0.992); reached markers tinted.
- StreakRewardsController: `Icon.Time` = Days; `Speed` = "x1.4 Speed" (`(1 + s) + perk` shown as a multiplier); `Bar.Fill` piecewise over `Info["7"/"14"/"21"].Position.X.Scale` by cycleDay; the three `Item1` frames sorted by `Position.X` map to 7/14/21 and show Claimed / Ready (pulse) / Locked, texts updated for later cycles; the 3 placeholder ImageLabels get real icons (Speed potion / Spin ticket / chest from `QuestCatalog.RewardIcons`); `Choose` relabelled "CLAIM" while a reward is pending, else "Next day in hh:mm:ss".
- Strings en/es/pt (fallback en) via `TutorialText.LanguageFor`; designer labels keep AutoLocalize.

#### 5. Entry points and popup budget
- `TopbarIconsController.client.luau`: `buildIcon` (:84-94) accepts `data.left` → `:setLeft()`. Left side, in this order: **Streak** (flame icon, `setLabel(tostring(StreakDays))`, notice while `StreakRewardPending`), **Playtime** (label "+30%" / "MAX"), **Titles** (crown 113221127098716; notice while `TitlesNewCount > 0`, only after 10 min of session), **Community** (icon 75521963910910; notice until claimed; **destroyed** once `CommunityRewardClaimed` is true or `U4.IsOn("Community")` is false). Each opens its panel with `MenuEvents.Request(name)`. Icons hidden while `FirstTimeTutorialActive`. Right side unchanged; top centre stays clear.
- `DailyRewardController.client.luau` `closePanel` (:290-332, non-instant path): after the first close this session, if `StreakRewardPending == true` and no tutorial is running, fire `MenuEvents.Request("Streak")` once. This is the only new auto-open; the join chain stays UpdateLogs → Daily.
- `BoostNotifier.client.luau` (:96-100): accept `payload.Type == "Retention"` (respect `HidePopups`).

#### Acceptance
- W1 → W2 teleport at 25 min keeps +20 % and the countdown continues; reconnect within 15 min keeps it; after 16 min it resets.
- Streak: one durable write per player per day; pending milestone rewards survive a broken streak; each key claimed once.
- Newcomers see nothing retention-related pop up during the tutorial; no extra popups beyond the conditional Streak open.

#### Tests
- `test_u4_retention_math`: StreakCheckIn same/next/grace/second gap within 7 days → reset/gap ≥3 → reset; Best kept; keys at cycleDay 7/14/21 and cycle 2 (days 28/35/42); PlaytimePercent at 599/600/1800/3600/6000/9000 = 0/10/30/60/100/100; Multiplier additivity and cap; PiecewiseFill at the designer markers (600 → 0.148, 6000 → 0.992).
- `test_u4_retention_service` (stubbed DataService, Players, clock): CheckIn idempotent per day (same operationId → AlreadyCommitted); ClaimStreak rejects non-pending keys, perk 0.2 → 0.4 never beyond; RetentionSection Sanitize (negatives, NaN, overlong lists truncated to 6/64) and round trip; playtime resume within 900 s keeps seconds and session id; static grep: no `DataService.Commit` inside the timer loops, Playtime saved with `ApplyVolatile`.
- `test_u4_topbar`: TopbarIconsController source uses `setLeft` for the 4 icons, destroys Community when claimed; on 667×375 and 844×390 phones the left icons end before 0.35W (estimate 44 px per icon + Roblox left buttons 100 px).

### 7.8 community_pass_admin — Community (Discord) reward, 2x Stamina Regen gamepass, admin panel (Mega Race, titles, pass, community code)

**Goal.** A policy-compliant community reward with the designer's "Community rewards" panel; the new 2x Stamina Regen gamepass (ownership, purchase, gift, shop card, a non-intrusive offer); the admin panel gains the Mega Race event, the pass, title grants and the rotating community code.

**Owns (create):** `src/common/ServerScriptService/Social/CommunityRewardService.server.luau`, `src/common/StarterPlayer/StarterPlayerScripts/UI/CommunityRewardsController.client.luau`, `src/common/ServerScriptService/Services/Data/U4/CommunitySection.luau`, `src/common/ServerScriptService/Economy/StaminaRegenPass.server.luau`, `src/common/StarterPlayer/StarterPlayerScripts/UI/StaminaPassHint.client.luau`, `audit/u4_shop_card.luau` (Lune helper for the build), tests `audit/test_u4_community.luau`, `audit/test_u4_stamina_pass.luau`, `audit/test_u4_admin_events.luau`.
**Owns (change):** `src/common/ServerScriptService/Social/CodesSystem.server.luau`, `src/common/StarterPlayer/StarterPlayerScripts/UI/ShopController.client.luau`, `src/common/ServerScriptService/Admin/AdminAbusePanelService.server.luau`, `src/common/StarterPlayer/StarterPlayerScripts/Admin/AdminAbusePanelController.client.luau`, `audit/test_admin_abuse_panel.luau`.

**Consumed contracts:** `Shared/Update4Config.luau` → `U4.Community` (Codes {"speedfam"}, CodeStoreName "SpeedsterCommunityCode_v1", CodeStoreKey "active", CodeCacheSeconds 300, GroupId 771624731, SpeedPotionMinutes 30, SpinTickets 3, TitleId "member", MaxWrongPerMinute 5), `U4.StaminaPass` (GamePassId 0 until created, GiftProductId 0, PriceRobux 149, RegenMultiplier 2, DelayScale 0.5, HintAfterEmpties 3, HintMinSessionSeconds 600, HintSeconds 6), `U4.IsOn("Community"|"StaminaPass"|"MegaRace")` (StaminaPass is off while the id is 0). Profile section `U4.Community = {Claimed, At}` (your `CommunitySection`; command `U4.Community.Claim {at}`). The regen itself is applied by the integrator in Bootstrap's stamina loop from the player attribute `StaminaRegen2xOwned` (you only set the attribute). Race: `_G.SpeedsterRace.StartMegaEvent(durationSeconds, byName)` / `StopMegaEvent()` (race_server; check the type first). Titles: `_G.SpeedsterTitles.Grant(player, id, source)` / `Refresh(player)` and the Commit command `{kind="U4.Titles.Grant", id}`; grantable ids `content_creator`, `member`. MenuEvents `Community = "OpenCommunityPanel"` → "Community rewards" (integrator). Funnels (integrator): `Community_Reward` (1 Community_Opened, 2 Community_RedeemTried, 3 Community_Claimed; one-time) and `Monetization_StaminaPass` ([0] OfferVisible, [1] Clicked, [2] PromptShown client-reported through `Remotes.FunnelReport:FireServer("Monetization_StaminaPass", step)` in pcall; [3] Purchased server). Designer GUI "Community rewards" (in StarterGui via the build, Enabled=false): root frame "Community rewards" with Title, Icon, Close, `Redeem` button, `Frame` (steps 1/2/3 and the `InsertCode` TextBox, whose hint is wrongly in `.Text`), `Itemsframe` (`Unlock` + two frames named `Item1`).

#### 1. Community reward — CommunityRewardService.server.luau
- Policy: `PolicyService:GetPolicyInfoForPlayerAsync(player)` in pcall (pattern SpinWheelService.server.luau:108-123); `CommunityDiscordAllowed = table.find(info.AllowedExternalLinkReferences, "Discord") ~= nil`; **false** until the answer arrives or on failure; true in Studio.
- Discord allowed: steps say "Join our Discord server (link on our game page)", "Get the code with /getcode", "Enter it here". Never show a URL, an invite or anything clickable that leaves Roblox.
- Discord not allowed: the word "Discord" never appears; step 1 = "Join our Roblox group" with a button `GroupService:PromptJoinAsync(U4.Community.GroupId)`; steps 2-3 = "Come back and tap Redeem"; `InsertCode` hidden; the server verifies `player:IsInGroupAsync(GroupId)` (pcall) before paying.
- Remotes `CommunityRewardRequest` (`"Get"` → `Step(1)`; `"Redeem", code` only when allowed → `Step(2)`; `"VerifyGroup"` → `Step(2)`), RemoteGuard 1 s, plus ≤5 wrong codes per minute per player; `CommunityRewardUpdate` `{DiscordAllowed, Claimed, GroupId, Success?, Message?, Rewards={SpeedPotionMinutes, SpinTickets, TitleId}}`.
- Codes: `CodesCatalog.Normalize(code)` (Catalogs/CodesCatalog.luau:61-66) must be in `U4.Community.Codes` or in the DataStore list `GetDataStore(CodeStoreName):GetAsync(CodeStoreKey) = {Codes={...}, At}` cached 300 s (pcall; Studio refusal quiet).
- Reward once per account: one Commit, operationId `u4community:v1`, commands `{kind="U4.Community.Claim", at=os.time()}`, `{kind="U4.Titles.Grant", id="member"}`, `{kind="GrantBuff", grant={kind="SpeedPotion", addedSeconds=30*60, multiplier=2, bottleType="Small"}}`, `{kind="GrantSpinTickets", amount=3}`; then `CommunityRewardClaimed = true`, `Step(3)`, toast, `_G.SpeedsterTitles.Refresh(player)`.
- `_G.SpeedsterRedeemCommunityCode(player, code) -> ok, message` (used by CodesSystem).

#### 2. CommunityRewardsController.client.luau
`WaitForChild("Community rewards", 8)`, `MenuPanelLayout.BindPhoneFit(gui, gui["Community rewards"], open, closed)`, ModalJuice, `ConsolePanelSupport.Bind`, `MenuEvents.MarkReady("Community", …)`. TextBox: `Text = ""`, `PlaceholderText = "Insert Code..."`, `ClearTextOnFocus = false`. Items: `Unlock` = Member title tag; the two `Item1` frames sorted by `Position.Y` = "x2 Speed 30m" / "3 Spins". Step texts per policy (en/es/pt, fallback en). Claimed → "CLAIMED ✓" and Redeem disabled.

#### 3. CodesSystem.server.luau
In `resolveCode` (:160-169): when the normalised code is not a normal code and `_G.SpeedsterRedeemCommunityCode` exists, delegate to it instead of answering "Invalid code" (so a community code typed in the normal Codes modal works too).

#### 4. 2x Stamina Regen pass
- `StaminaRegenPass.server.luau`: on join (after DataLoaded) set `StaminaRegen2xOwned` = `MarketplaceService:UserOwnsGamePassAsync(uid, U4.StaminaPass.GamePassId)` (pcall, retry ×3) or `GiftedPasses.Has(player, passId)` (Services/Monetization/GiftedPasses.luau; same pattern as `refreshSonicBurstPassOwnership`, SpeedProductPurchases.server.luau:2371-2402); a separate `MarketplaceService.PromptGamePassPurchaseFinished` connection sets it on purchase and logs `FunnelAnalytics.Step(player, "Monetization_StaminaPass", 3)`. Everything is skipped while `U4.IsOn("StaminaPass")` is false. Does not touch SpeedProductPurchases.server.luau (owned by p0_gameplay). Gift: once the owner creates the gift product, it is added to `Config.GamePassGiftProducts` by the integrator; `GiftedPasses.Has` then covers it.
- Effect (integrator, Bootstrap): regen ×2 and regen delay ×0.5 outside races (3 s → 1.5 s delay; 5.6 s → 2.8 s from empty). In races the race pool uses `U4.Race.Stamina.PassRegenFactor` (1.0 = no effect; owner question).
- `StaminaPassHint.client.luau`: listen to `StaminaFeedback.Attempted` (Shared/StaminaFeedback.luau:22-23, a BindableEvent signal); on the 3rd empty-bar attempt in a session, for a non-owner with ≥10 min of session and not in the tutorial (`FirstTimeTutorialActive`), show a small "2x Regen" chip (30 px, right end of the stamina bar `SpeedsterBar`, read-only lookup) for 6 s, once per session → `FunnelReport` step 0; tap → step 1 + `MarketplaceService:PromptGamePassPurchase(player, id)` → step 2. Hidden while the pass is off.
- Shop: `audit/u4_shop_card.luau` `Insert(dm, notes)` clones the `Revive` card in `StarterGui.Shop.ScrollingFrame.Pass` to `2X Stamina` (lightning icon 123961542220277, text "2x Stamina Regen", stamped `U4Asset`, idempotent). `ShopController.client.luau`: `PASS_MAP` (:157-162) `["2X Stamina"] = {type="GamePass", id=tonumber(U4.StaminaPass.GamePassId) or 0}`, `DEFAULT_PRICES["2X Stamina"] = U4.StaminaPass.PriceRobux` (:172-188); `wirePassCards` (:424-470) hides the card while the id is 0; card click → funnel steps 1/2 like the hint.

#### 5. Admin panel
- `AdminAbusePanelService.server.luau`: `EVENTS` (:2168) add `MegaRace = true`; `runEvent` (:1212-1238) `elseif name == "MegaRace" then if type(_G.SpeedsterRace) == "table" and U4.IsOn("MegaRace") then _G.SpeedsterRace.StartMegaEvent(duration, by and by.Name or "Admin") end`; `stopEvent` (:1166-1187) → `StopMegaEvent()`. Global scope works through the existing publish (:2204-2211, :2022). `PASSES` (:1825) + `setPass` (:1895): `StaminaRegen` (sets/clears `StaminaRegen2xOwned` for the session, like the other passes). New actions via `targetsFor` like `Pass` (:2507-2520): `GrantTitle {id}` / `RevokeTitle {id}` only for grantable ids (`content_creator`, `member`) → `_G.SpeedsterTitles.Grant/Revoke`; owner-only (`OWNER_IDS`, :66-69) `SetCommunityCode {code}` → `SetAsync(CodeStoreKey, {Codes={normalised}, At=os.time()})`, toast back.
- `AdminAbusePanelController.client.luau`: Events tab tile `{ "🏁", "MegaRace", "Mega Race", "x2 race rewards, 16 racers, starts now", "Blue" }` (:556-563); pass toggle "2x Stamina"; in the player actions a "Title" picker (Content Creator / Member, grant/revoke); owner-only "Community code" text field + Set button.
- `audit/test_admin_abuse_panel.luau`: update the event/tile counts for MegaRace and line :287 to expect `FindFirstChild("LocalDeathClaim")` (H6 by p0_gameplay moves the watchdog to that remote).

#### Acceptance
- A Discord-restricted account never sees "Discord" and can still earn the reward through the group; the reward pays once per account (second attempt = AlreadyCommitted, nothing granted).
- With `GamePassId = 0` nothing about the pass is visible; with an id, ownership/purchase/gift set `StaminaRegen2xOwned` and the offer appears at most once per session.
- Mega Race from the admin panel starts gathering at once on every server (global scope) and doubles race rewards.

#### Tests
- `test_u4_community` (PolicyService/Group/DataStore stubs): not allowed → Redeem refused and payload hides Discord; group path requires IsInGroupAsync true; code accepted from Config or the DataStore list after Normalize; second claim → no second grant; 5 wrong codes/min limit; CommunitySection round trip; CodesSystem delegates unknown codes to `_G.SpeedsterRedeemCommunityCode`.
- `test_u4_stamina_pass`: ownership from UserOwnsGamePassAsync or GiftedPasses; purchase-finished sets the attribute and logs step 3; nothing runs while the id is 0; hint shows only after 3 empties + 10 min, once per session; ShopController hides the card at id 0; `u4_shop_card.Insert` idempotent.
- `test_u4_admin_events`: EVENTS has MegaRace; runEvent/stopEvent call the `_G.SpeedsterRace` hooks guarded by type; GrantTitle refuses non-grantable ids; SetCommunityCode owner-only; the controller lists the MegaRace tile.

---

## 8. Preguntas para el owner (bloquean solo números/ids; el código sale con los valores por defecto indicados)

1. **2x Stamina Regen**: crear el gamepass (precio sugerido 149 R$) y enviar el id + un developer product de regalo al mismo precio. Hasta entonces la tarjeta y la oferta están ocultas. ¿Debe dar ventaja en carreras? Por defecto **no** (`PassRegenFactor = 1.0`); con 1.25 vale ~0.2 s por carrera.
2. **Retención**: Playtime (+100 % máx.) y Streak (+100 % máx.) se **suman** y los hitos 7/14 dan +0.2/+0.4 permanentes → máximo x3.4 sobre ganancias de correr/treadmill (multiplica con los pases). ¿OK o preferís pociones temporales en 7/14 y tope x3?
3. **Título OWNER**: ¿qué UserIds? (el código dice 111827288 = "pxuto / owner"; la memoria dice que 111827288 es pxuto y Gekkoh es 767108248). Por defecto: creador del juego (usuario o rango 255 del grupo) + DEV para 767108248 y 111827288. ¿Lista de Content Creators de lanzamiento (o se dan desde el panel admin)?
4. **Discord**: ¿un código comunitario rotativo que el bot da con /getcode (propuesto; se cambia desde el panel admin) o códigos por usuario (necesita un secreto compartido con el bot)? ¿El enlace de Discord está en los Social Links de la experiencia? Para jugadores sin permiso de Discord se ofrece unirse al grupo de Roblox — ¿OK?
5. **Orden de publicación**: ¿publicar primero solo el build P0 (≈3 días antes) para medir su efecto en D1 por separado?
6. **Daily**: ¿aprobáis la nueva tabla (spins días 2/12/26, pociones días 5/19; días 16-30 dan ~1000x menos Speed) y el día nuevo a las 08:00 UTC (04:00 EE.UU. Este, 05:00 Brasil)?
7. **MovementGuard H10**: ¿48-72 h en modo Observe (sin cambios visibles) antes de decidir Enforce?
8. **Arte de pista**: subir la textura de chevrones (o aceptamos chevrones de partes, ~150 partes más, ocultas en móviles). ¿Hay un sonido de viento de super-velocidad subido/autorizado?
9. **Desbloqueo de carreras**: tras el primer Win pad (tutorial visto) o con ≥1 rebirth (propuesto). ¿OK?
10. **Imágenes del diseñador**: los 14 asset ids de uineww.rbxm deben pertenecer a la cuenta/grupo del juego para cargar; ¿confirmado? (Las 3 imágenes de Streak son placeholders; se ponen iconos de poción/spin/cofre.)
