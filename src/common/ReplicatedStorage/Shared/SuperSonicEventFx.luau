--!strict
-- ReplicatedStorage/Shared/SuperSonicEventFx.luau — the client presentation of the "Super Sonic vs
-- Dr. Eggman" live event (2026-09-26, owner): tunables and pure functions for
-- Gameplay/SuperSonicEventClient (the server contract, its phases, messages and maths are
-- Shared/SuperSonicEvent; nothing here duplicates a number that module owns).
--   Tiers                 the budget per Shared/RaceFeelTier tier (63% of the players are on phones)
--   Textures / Flipbooks  the owner's verified ids (lightning, wind rings, speed trail)
--   Sounds                the owner's uploads (2026-09-26 v2) and ids that already play in this game
-- 2026-09-26 (owner, v2 after testing): the charged homing attack (Charge*), the chaos sky and grade
-- (Chaos*: the lighting layer Admin/AdminAbuseEffects' blendLighting mixes in), the golden vignette,
-- Eggman's gestures and his cannon deploying / retracting / kicking, the bombs' exit from the barrel,
-- trail, whistle and red warning zone with its alarm, the muzzle flash, the emeralds' coloured glow,
-- the smoke and fire round the lobby, the ring rain at the defeat.
--   EmitterSets           which emitters of the imported Steal a Hero VFX each tier fires
--   EmitCount             how many particles one :Emit fires (the rbxm's EmitCount / SabEmit)
--   BombPunch             the bomb's camera punch scaled by distance (SSE.Camera.BombHit at the blast)
--   EmeraldOffset         the fall from the sky, the orbit (SSE.EmeraldOrbit) and the Bezier into the chest
--   HitPoint              where a homing attack ends (SSE.Boss.HitRadius short of the ship's centre)
--   HomingButtonRect      the touch HOMING ATTACK button: clear of the jump button, the thumbstick and
--                         the player's own touch pieces (Shared/HudErgonomics)
--   Text / Word / Format  en / es / pt (anything else reads English)
-- 2026-09-26 (owner, v3 after the next playtest):
--   Burn                  the "burn" line is a short one-shot now and then near the fire patches (random gaps
--                         of several seconds, never two at once), no longer a loop
--   Chaos                 toned down: a subtle warm orange haze (Chaos.Strength of the way to the warm target),
--                         a light grade, lighter smoke: the lobby stays readable
--   HudHide               the game's HUD slides away during the event (MenuEvents.SetHUDVisible, as when a menu
--                         is open); the topbar stays; only the event's minimal UI shows
--   Style / BossBar       the game's HUD look (the level / stamina bars: white glass, navy ink outline, GothamSSm
--                         Bold with a navy stroke, round corners) for the small boss bar and the invite card
--   Inputs / ReticlePrompt  a mid-air jump press (Space / gamepad A / the touch jump) is the instant homing
--                         attack; F / Left Click / gamepad X / the touch button HELD is the charged one; the
--                         reticle shows "(A)" / "(X)" on a gamepad
--   Homing                the hit-stop, the white hit flash, the shield's knock-back (SSE.ShieldKnock)
--   Trail / TrailWrap     ONE big speed-trail Beam wrapping round the spin ball (no more swirl of small lines)
--   Freeze                the contract's freeze windows (SSE.IsFrozen) while the root is in the event's area
--   Invite                the optional "teleport to the event?" card (en / es / pt)
-- Pure numbers and tables: nothing yields, connects or touches the DataModel. Lune-safe (the tests
-- require it directly: the Vector3 / CFrame constructors come from @lune/roblox there).
local Vector3, CFrame = Vector3, CFrame
if Vector3 == nil or CFrame == nil then
	local lateRequire: any = require
	local ok, roblox = pcall(lateRequire, "@lune/roblox")
	if ok and type(roblox) == "table" then
		Vector3, CFrame = roblox.Vector3, roblox.CFrame
	end
end
local SSE: any = if typeof(script) == "Instance"
	then require((script :: any).Parent:WaitForChild("SuperSonicEvent", 10))
	else require("./SuperSonicEvent")
local HudErgonomics: any = if typeof(script) == "Instance"
	then require((script :: any).Parent:WaitForChild("HudErgonomics", 10))
	else require("./HudErgonomics")

local Fx = {}

Fx.Version = 3
Fx.FolderName = "SuperSonicEventFx" -- the client's own Workspace folder (local instances only)
Fx.InviteGuiName = "SuperSonicEventInvite" -- 2026-09-26 (owner, v3): the optional teleport card
Fx.RetiringName = "SuperSonicEventFx_Fading" -- the folder at the end of an event while its particles die out
Fx.RingsFolderName = "SuperSonicEventRings" -- the defeat's rings (they outlive the event, until their expireTime)
Fx.GuiName = "SuperSonicEventHud" -- its ScreenGui
Fx.ScreenGuiName = "SuperSonicEventScreen" -- the letterbox, the dialogue box, the charge ring (kept by the cinematics)
Fx.VignetteGuiName = "SuperSonicEventVignette" -- the golden vignette while Super (under the HUD)
Fx.GradeName = "SSE_ChaosGrade" -- the ColorCorrectionEffect under Lighting (the fiery grade)
Fx.InterfaceOwner = "SuperSonicEventCinematic" -- this client's hold on Shared/InterfaceHider
Fx.RenderName = "SuperSonicEventCinematic" -- its BindToRenderStep name
Fx.CinematicAttribute = "SSE_CinematicActive" -- the local player's attribute while a cinematic has the camera
Fx.LookPrefix = "SSE_" -- every instance the client adds to a character starts with this
-- 2026-09-26 (owner): radiant gold body, ruby-red eyes.
Fx.Gold = { 255, 215, 0 }
Fx.Ruby = { 255, 30, 30 }

----------------------------------------------------------------------
-- Textures (2026-09-26, owner: verified ids). The sheets' grids were not part of the check: if a
-- particle shows several small frames (or a cut piece of one), change its Layout here (Studio:
-- the emitter's FlipbookLayout). WindRings is one image.
----------------------------------------------------------------------
-- 2026-09-26 (owner, v2): the "LE Lightning Globe" texture is gone from the event (no use anywhere).
Fx.Textures = {
	Lightning = "rbxassetid://12376549723", -- "Lightning343 2": the Super form's small hand / foot sparks
	WindRings = "rbxassetid://116579220922305", -- "Wind22": rings round the charging ball and behind it
	SpeedTrail = "rbxassetid://110245787189599", -- "Beam113": the spin ball's trail and the charge's speed lines (Beams)
}
Fx.Flipbooks = {
	Lightning = { Layout = "Grid4x4", Mode = "OneShot", Fps = 30 },
	WindRings = { Layout = "None", Mode = "Loop", Fps = 1 },
}
-- Particle textures this client may put on an emitter it creates (never Roblox's default sparkles).
function Fx.AllowedTexture(texture: any): boolean
	if type(texture) ~= "string" or texture == "" then
		return false
	end
	for _, id in Fx.Textures do
		if id == texture then
			return true
		end
	end
	return false
end

----------------------------------------------------------------------
-- Sounds. 2026-09-26 (owner, v2): his uploads (Burn, the voices, "hit!", the charge) and ids that already
-- play somewhere in this game. Every Sound sits in SoundService, where Audio/SfxAudioController routes it
-- into the SFX group (the "Sound effects" toggle and the SFX volume slider); the client also stays silent
-- for SoundEffects == false or Muted. Loop = a looping sound (its volume follows the nearest source).
----------------------------------------------------------------------
-- The contract's own list of the owner's uploads (SSE.Sounds: the music, the rings, the goodbye, the charge) is the
-- source of those ids.
local CONTRACT_SOUNDS: any = SSE.Sounds or {}
Fx.Sounds = {
	-- Admin/AdminAbuseEffects' firework launch: the cannon fires.
	BombLaunch = { Id = "rbxassetid://75964117535029", Volume = 0.45, Speed = 0.85 },
	-- The same firework whistle, low and falling in pitch while a bomb drops toward the player (BombWhistle).
	BombWhistle = { Id = "rbxassetid://75964117535029", Volume = 0.32, Speed = 1.25 },
	-- "Cannon_Explode" (Admin/AdminTreadmillReveal's taco impact): the explosion the owner likes, kept.
	BombBlast = { Id = "rbxassetid://3149249837", Volume = 1.5, Speed = 0.9 },
	-- The red zone's alarm (the race's ZoneTick / the UI tick), rising in pitch near the impact.
	AlarmTick = { Id = "rbxassetid://72264591133889", Volume = 0.5, Speed = 1 },
	-- 2026-09-26 (owner): "hit!", the homing impact on the Egg Mobile.
	HomingHit = { Id = "rbxassetid://134196260572617", Volume = 1.5, Speed = 1 },
	-- The engine's metal clank under it (the hull), softer.
	HomingClank = { Id = "rbxasset://sounds/collide.wav", Volume = 1.1, Speed = 1.35 },
	-- Sonic Boom 5 (Config.AbilitySonicBurstBoomSoundId): the spin ball takes off.
	HomingLaunch = { Id = "rbxassetid://9119382815", Volume = 0.45, Speed = 1.3 },
	-- 2026-09-26 (owner): "sonicballdashstart", Sonic's charge: plays while the homing button is held.
	ChargeStart = { Id = CONTRACT_SOUNDS.Charge or "rbxassetid://93126470207724", Volume = 0.9, Speed = 1 },
	-- 2026-09-26 (owner): "burn" near the fire patches. 2026-09-26 (owner, v3): "it repeats far too much": a
	-- short one-shot now and then (Fx.Burn: random gaps of several seconds, never two at once), not a loop.
	Burn = { Id = "rbxassetid://97328578838913", Volume = 0.4, Speed = 1 },
	-- 2026-09-26 (owner): Eggman's voice. "HAHAHA catch me if you can", "what are you doing I'm right here"
	-- (a homing attack refused by his shield), "Paralel attack!" (the parallel salvo).
	VoiceCatch = { Id = "rbxassetid://85365485919704", Volume = 1.2, Speed = 1 },
	VoiceShielded = { Id = "rbxassetid://107740886981758", Volume = 1.2, Speed = 1 },
	VoiceParallel = { Id = "rbxassetid://82583368227347", Volume = 1.3, Speed = 1 },
	-- Electric Zaps 12 (Config.AbilitySonicBurstChargeSoundId), high: the ball glancing off his shield.
	ShieldZap = { Id = "rbxassetid://9114277757", Volume = 0.55, Speed = 1.6 },
	-- The clank, low: the cannon sliding out of / into the hull.
	CannonMove = { Id = "rbxasset://sounds/collide.wav", Volume = 0.7, Speed = 0.6 },
	-- FirstTimeTutorial's completion chime: the emeralds' golden flash.
	Chime = { Id = "rbxassetid://135478009117226", Volume = 0.8, Speed = 1 },
	-- Electric Zaps 12 (Config.AbilitySonicBurstChargeSoundId): the Super form crackles on.
	Transform = { Id = "rbxassetid://9114277757", Volume = 0.35, Speed = 1.1 },
	-- LevelUpCelebration's fanfare: Eggman defeated.
	Fanfare = { Id = "rbxassetid://3120909354", Volume = 0.9, Speed = 1 },
	-- Admin/AdminAbuseEffects' firework boom: the ship's chain explosions.
	DefeatBoom = { Id = "rbxassetid://126237860088652", Volume = 1.0, Speed = 0.8 },
	-- 2026-09-26 (owner): "coin pickup", every ring collected.
	RingCollect = { Id = CONTRACT_SOUNDS.RingPickup or "rbxassetid://112771432761858", Volume = 0.6, Speed = 1, Rings = true },
	-- 2026-09-26 (owner): "coinnsdrop", the ring rain bursting out of the broken Egg Mobile.
	RingSpill = { Id = CONTRACT_SOUNDS.RingsDrop or "rbxassetid://102136054782395", Volume = 0.9, Speed = 1, Rings = true },
	-- 2026-09-26 (owner): his goodbye, "This is not the end. I will be back... I promise." (EggmanBeBack).
	VoiceBeBack = { Id = CONTRACT_SOUNDS.EggmanBeBack or "rbxassetid://103892608635163", Volume = 1.3, Speed = 1 },
}
-- 2026-09-26 (owner): the event's music, "Eggman's Revenge": looping for the whole event, faded in at the start
-- and out at the end, ducked under his voice lines. It follows the MUSIC slider and mute (its own SoundGroup,
-- not the SFX one); the lobby playlist (Audio/BackgroundMusic) fades out meanwhile (MusicSilenceAttribute on
-- its Sound) and comes back after.
Fx.Music = {
	Id = CONTRACT_SOUNDS.Music or "rbxassetid://133261865867143",
	Volume = 0.4, -- times the player's MusicVolume slider
	FadeIn = 2.5,
	FadeOut = 3,
	Duck = 0.45, -- the level under a voice line
	DuckSeconds = 0.35, -- how fast it ducks / comes back
	GroupName = "SuperSonicEventMusicGroup",
	SoundName = "SuperSonicEventMusic",
	SilenceAttribute = "SuperSonicEventMusic", -- set on SoundService.SpeedsterBackgroundMusic while it plays
}
Fx.SoundRange = 260 -- a world sound fades out over this many studs (played 2D, attenuated by hand)
-- Sounds that may overlap get a few voices (the rest one).
Fx.SoundVoices = { BombBlast = 3, DefeatBoom = 3, HomingHit = 2, HomingClank = 2, BombLaunch = 2, BombWhistle = 2,
	AlarmTick = 2, RingCollect = 3, ShieldZap = 2 }

-- 2026-09-26 (owner, v3): the burn's cadence. A burst plays only when a burning patch is within Range studs of
-- the camera, lasts at most Seconds (fading out over its last FadeSeconds), and the next one waits a random gap
-- of GapMin..GapMax seconds after it ends (the first: FirstMin..FirstMax after the fires light).
Fx.Burn = { GapMin = 7, GapMax = 15, FirstMin = 1.5, FirstMax = 4, Seconds = 2.2, FadeSeconds = 0.5, Range = 120 }

-- When the next burst may play: `clock` + the burst's own length + a gap drawn from rand01 (0..1).
function Fx.NextBurnAt(clock: number, rand01: number?): number
	local b = Fx.Burn
	local r = math.clamp(tonumber(rand01) or 0.5, 0, 1)
	return (tonumber(clock) or 0) + b.Seconds + b.GapMin + (b.GapMax - b.GapMin) * r
end

-- The burst's level `age` seconds after it began: 1, then down to 0 over its last FadeSeconds (0 after Seconds).
function Fx.BurnLevel(age: number): number
	local b = Fx.Burn
	local a = tonumber(age) or math.huge
	if a < 0 or a >= b.Seconds then
		return 0
	end
	return math.clamp((b.Seconds - a) / b.FadeSeconds, 0, 1)
end

-- The sound's volume, or 0 when the player turned sound effects off (the Settings toggle) or is muted.
function Fx.SoundVolume(kind: string, attributes: any, distance: number?): number
	local spec = (Fx.Sounds :: any)[kind]
	if not spec then
		return 0
	end
	if type(attributes) == "table" and (attributes.SoundEffects == false or attributes.Muted == true) then
		return 0
	end
	if distance ~= nil then
		return Fx.Attenuate(spec.Volume, distance)
	end
	return spec.Volume
end

----------------------------------------------------------------------
-- The boss (a local clone of the lobby's Dr. Eggman in his Egg Mobile, Shared/EggMobile)
----------------------------------------------------------------------
Fx.Boss = {
	-- The lobby ship is ~8 studs wide; x2.2 (SSE.Boss.DrawScale) makes its hull (radius 3.86 x 2.2 = 8.5)
	-- meet SSE.Boss.HitRadius (9), where a homing attack ends, and the Cannon's spawn point meet SSE.Boss.Cannon.
	Scale = SSE.Boss.DrawScale or 2.2,
	-- The Blender kit's Cannon (design/event/supersonic/event_manifest.json), hull space at scale 1: its
	-- pivot is the mount point on the bowl, no rotation (the barrel is modelled 20 degrees down). The part
	-- barrel that stands in until the kit is imported runs from the mount to the muzzle.
	CannonMount = { 0, -1.05, -3.114 },
	CannonMuzzle = { 0, -2.0072, -5.8177 },
	CannonRadius = 0.95,
	FarHide = 1400, -- studs from the camera: the boss is not drawn further away
	PlasmaLength = 7, -- the plasma cone under the hull (ship studs, before Scale)
	ExhaustLength = 4.2, -- the exhaust flame behind it (ship studs, before Scale)
	FlashSeconds = 0.22, -- the red flash of a hit
	FlashColor = { 255, 40, 40 },
	RecoilSeconds = 0.45,
	RecoilStuds = 2.4, -- pushed away from the hitter, shaking
	RecoilDegrees = 7,
	TauntEvery = 9, -- seconds between his taunts (Shared/LobbyNpcPose reactions) while he fights
	-- The flight away after the defeat / the escape is the contract's path (SSE.BossCFrame after the plan's
	-- endStart). 2026-09-26 (owner, v2): he fades into the horizon while he goes (Fx.EndFade), never a sudden
	-- disappearance. An event that ends before he is gone (an admin stop) lets him finish alone for at most
	-- OutroSeconds, still fading.
	OutroSeconds = 3.5,
	ChainSeconds = 2.0, -- the chain explosions on the hull while he holds (SSE.Boss.DefeatHold)
	-- The lobby's own Eggman fades back in at his spot once the boss is gone (LocalTransparencyModifier
	-- from 1 back to each piece's own value: glass stays glass).
	LobbyFadeSeconds = 1.4,
	-- The shield while he attacks (a ForceField bubble round the ship; off while he reloads).
	ShieldRadius = 11.5, -- studs (at DrawScale)
	ShieldColor = { 255, 70, 40 },
	ShieldTransparency = 0.55,
	ShieldFlicker = 0.35, -- seconds of flicker when it drops or comes back
	-- The vulnerable "!" over him while he reloads.
	AlertHeight = 13, -- studs over the hull's centre
}
-- 2026-09-26 (owner, v2): how far the ship has faded into the horizon `u` seconds after the Defeat / Escape
-- began (the contract's path: it holds DefeatHold / EscapeHold, then flies away over EscapeFlySeconds): 0 while
-- it holds, then up to 1 while it flies off (fully gone at FadeEnd of the flight).
Fx.EndFadeFrom = 0.1 -- share of the flight away when the fade begins
Fx.EndFadeTo = 0.92 -- ... and ends (invisible)
function Fx.EndFade(u: number, defeated: boolean): number
	local b = SSE.Boss
	local hold = if defeated then (b.DefeatHold or 2.8) else (b.EscapeHold or 2.0)
	local fly = math.max(0, (tonumber(u) or 0) - hold) / (b.EscapeFlySeconds or 3.6)
	local k = math.clamp((fly - Fx.EndFadeFrom) / (Fx.EndFadeTo - Fx.EndFadeFrom), 0, 1)
	return k * k * (3 - 2 * k)
end

-- 2026-09-26 (owner, v3): the crash's wreck fades out between SSE.CrashTimes' fadeStart and fadeEnd (server
-- times; `times` = SSE.CrashTimes(the Defeat's start)): 0 before, 1 after, smooth between.
function Fx.CrashFade(now: number, times: any): number
	local a, b = tonumber(times and times.fadeStart), tonumber(times and times.fadeEnd)
	if not a or not b then
		return 0
	end
	local k = math.clamp(((tonumber(now) or 0) - a) / math.max(b - a, 1e-3), 0, 1)
	return k * k * (3 - 2 * k)
end
-- The small blasts on the way down: `count` server times spread over the dive (never at its ends).
function Fx.CrashPops(defeatStart: number, count: number): { number }
	local out = {}
	local seconds = (SSE.Crash and SSE.Crash.Seconds) or 2.4
	local n = math.max(0, math.floor(tonumber(count) or 0))
	for index = 1, n do
		out[index] = (tonumber(defeatStart) or 0) + seconds * index / (n + 1)
	end
	return out
end

-- Any of these under the clone goes (the owner: no blue highlight / PointLight, only the exhaust
-- flame and the plasma pulse); the clone's colliders and prompts go too.
Fx.StripClasses = {
	"Highlight", "PointLight", "SpotLight", "SurfaceLight", "ParticleEmitter", "Beam", "Trail",
	"BillboardGui", "SurfaceGui", "ProximityPrompt", "ClickDetector", "Sound", "Script", "LocalScript",
	"Animator", "AnimationController", "Fire", "Smoke", "Sparkles", "SelectionBox",
}

----------------------------------------------------------------------
-- Tiers (Shared/RaceFeelTier: High = desktop >= 45 FPS; Mid; Low = phones under 30 FPS)
----------------------------------------------------------------------
-- Boss:     PoseHz (his R6 pose), Beams (plasma cones), Exhaust, Pulse (the Neon glows breathe)
-- Blasts:   BlastSet ("Full" | "Mid" | "Low": EmitterSets), EmitScale, BlastPool, FirePatches (per blast),
--           Rings (the warning disc on the ground)
-- Emeralds: OwnLights (PointLights on the local player's 7), OtherSets (other players' emerald
--           orbits, nearest first), OtherEmeraldDistance
-- Super:    OwnShells / OwnAccessoryShells / OwnSparkLimbs / OwnSparkRate (the local player);
--           OtherFull (other Super players drawn with shells and sparks, nearest first; the rest get
--           the gold body and the eyes only), OtherShells, OtherSparkLimbs, OtherSparkRate, OtherDistance
-- Homing:   WindRings / Beam (the local spin ball's wind rings and speed trail), OtherFlights (other
--           players' balls at once), OtherBeam (their trail), OtherHitBurst; TrailSegments (2026-09-26, owner,
--           v3: the ONE big trail Beam wrapped round the ball, its curve's segments)
-- Defeat:   DefeatBlasts (the chain explosions on the hull), RingsVisible (the ring rain drawn at once);
--           (2026-09-26, owner, v3: the crash) CrashPops (small blasts on the way down), CrashSmoke (the smoke
--           trail's rate), CrashFires (the imported FireTrail flames on the hull), CrashBlasts (the impact chain:
--           the first n of SSE.Crash.Explosions)
-- 2026-09-26 (owner, v2):
-- Chaos:    Grade (the fiery ColorCorrection), SmokeColumns / AmbientFires round the lobby, EmberRate
--           (embers drifting round the camera), Vignette (0 / 1 / 2 layers of the golden vignette while
--           Super), FireLights (a warm PointLight in each fire patch)
-- Bombs:    BombTrail ("Full": fire + smoke Beam, "Beam": the smoke Beam only), WarningClose (the
--           closing ring over the red zone), Whistle, Muzzle (the white flash's emitter set)
-- Gems:     GemGlow / GemEmbers (the tinted BurstHatch glow and embers on the local player's gems),
--           GemTrail (their coloured trail), OtherGemTrail (on other players' gems)
Fx.Tiers = {
	High = {
		PoseHz = 30, Beams = 2, Exhaust = true, Pulse = true,
		BlastSet = "Full", EmitScale = 1, BlastPool = 8, FirePatches = 3, Rings = true,
		OwnLights = 7, OtherSets = 8, OtherEmeraldDistance = 180,
		OwnShells = true, OwnAccessoryShells = true, OwnSparkLimbs = 4, OwnSparkRate = 6,
		OtherFull = 10, OtherSparkLimbs = 2, OtherSparkRate = 2.5, OtherShells = true, OtherDistance = 220,
		WindRings = true, Beam = true, OtherFlights = 8, OtherBeam = true, OtherHitBurst = true, TrailSegments = 20,
		DefeatBlasts = 9, RingsVisible = 40, CrashPops = 4, CrashSmoke = 16, CrashFires = 3, CrashBlasts = 6,
		Grade = true, SmokeColumns = 6, AmbientFires = 6, EmberRate = 18, Vignette = 2, FireLights = 6,
		BombTrail = "Full", WarningClose = true, Whistle = true, Muzzle = "Full",
		GemGlow = true, GemEmbers = true, GemTrail = true, OtherGemTrail = true,
	},
	Mid = {
		PoseHz = 20, Beams = 1, Exhaust = true, Pulse = true,
		BlastSet = "Mid", EmitScale = 0.65, BlastPool = 6, FirePatches = 2, Rings = true,
		OwnLights = 7, OtherSets = 4, OtherEmeraldDistance = 140,
		OwnShells = true, OwnAccessoryShells = true, OwnSparkLimbs = 2, OwnSparkRate = 4,
		OtherFull = 4, OtherSparkLimbs = 1, OtherSparkRate = 1.5, OtherShells = true, OtherDistance = 160,
		WindRings = true, Beam = true, OtherFlights = 4, OtherBeam = false, OtherHitBurst = true, TrailSegments = 14,
		DefeatBlasts = 6, RingsVisible = 24, CrashPops = 3, CrashSmoke = 10, CrashFires = 2, CrashBlasts = 5,
		Grade = true, SmokeColumns = 4, AmbientFires = 4, EmberRate = 10, Vignette = 2, FireLights = 2,
		BombTrail = "Full", WarningClose = true, Whistle = true, Muzzle = "Mid",
		GemGlow = true, GemEmbers = false, GemTrail = true, OtherGemTrail = false,
	},
	Low = {
		PoseHz = 12, Beams = 1, Exhaust = false, Pulse = false,
		BlastSet = "Low", EmitScale = 0.4, BlastPool = 4, FirePatches = 1, Rings = true,
		OwnLights = 0, OtherSets = 0, OtherEmeraldDistance = 0,
		OwnShells = true, OwnAccessoryShells = false, OwnSparkLimbs = 2, OwnSparkRate = 2.5,
		OtherFull = 0, OtherSparkLimbs = 0, OtherSparkRate = 0, OtherShells = false, OtherDistance = 120,
		WindRings = false, Beam = true, OtherFlights = 2, OtherBeam = false, OtherHitBurst = false, TrailSegments = 10,
		DefeatBlasts = 4, RingsVisible = 12, CrashPops = 2, CrashSmoke = 5, CrashFires = 1, CrashBlasts = 3,
		Grade = true, SmokeColumns = 2, AmbientFires = 2, EmberRate = 4, Vignette = 1, FireLights = 0,
		BombTrail = "Beam", WarningClose = false, Whistle = true, Muzzle = "Low",
		GemGlow = false, GemEmbers = false, GemTrail = true, OtherGemTrail = false,
	},
}
Fx.TierSeconds = 5 -- how often the FPS tier is looked at again
Fx.SweepSeconds = 1.5 -- how often the other players' looks and emerald sets are re-ranked by distance

local function copy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for key, item in value do
		out[key] = copy(item)
	end
	return out
end

function Fx.Budget(tier: string?): any
	local name = if tier == "High" or tier == "Mid" or tier == "Low" then tier else "Low"
	local budget = copy(Fx.Tiers[name])
	budget.Tier = name
	return budget
end

----------------------------------------------------------------------
-- The imported VFX (assets/vfx_imported, ReplicatedStorage.SuperSonicEventAssets.VFX)
----------------------------------------------------------------------
-- Which emitters fire per BlastSet. "Full" fires every emitter but the blocked ones. The Low sets
-- are the owner's named pieces (bomb: darkfire, smoke, sw, rock, Sparks).
Fx.EmitterSets = {
	BombExplode = {
		Low = { "darkfire", "smoke", "sw", "rock", "Sparks" },
		Mid = { "darkfire", "smoke", "smoke_2", "sw", "rock", "Sparks", "circle3", "groundwind", "1" },
	},
	EggImpact = {
		Low = { "crack", "smoke", "specs" },
		Mid = { "crack", "gradient", "smoke", "smoke_2", "specs", "square" },
	},
	BurstHatch = {
		Low = { "Hitspark2", "Circle", "FireSpecs" },
		Mid = { "Hitspark2", "Circle", "FireSpecs", "Embers [20]", "shards", "pixel burst 57", "Sharp" },
	},
}
-- Steal a Hero leftovers that must never fire here (Burst_Hatch carries a taco confetti emitter).
Fx.BlockedEmitters = { tacopng = true }
-- The homing hit on the hull (a small burst): BurstHatch's sparks only.
Fx.HitBurstSet = { "Hitspark2", "Circle", "Sharp", "FireSpecs" }
Fx.EmitterSets.BurstHatch.Hit = Fx.HitBurstSet
-- 2026-09-26 (owner, v2): the cannon's WHITE muzzle flash on every shot (a bright flash, a quick ring, a
-- puff), per tier (Tiers' Muzzle), tinted white (Fx.Muzzle); the emeralds' coloured glow and embers.
Fx.EmitterSets.BurstHatch.MuzzleFull = { "Hitspark2", "Circle24", "Sharp" }
Fx.EmitterSets.BurstHatch.MuzzleMid = { "Hitspark2", "Circle24" }
Fx.EmitterSets.BurstHatch.MuzzleLow = { "Hitspark2" }
Fx.EmitterSets.BombExplode.MuzzleFull = { "smoke_2", "circle3" }
Fx.EmitterSets.BombExplode.MuzzleMid = { "smoke_2" }
Fx.EmitterSets.BombExplode.MuzzleLow = {}
Fx.EmitterSets.BurstHatch.GemGlow = { "Circle24" }
Fx.EmitterSets.BurstHatch.GemEmbers = { "Embers [20]" }
Fx.Muzzle = {
	Color = { 255, 255, 255 },
	SizeScale = 0.45, -- the imported pieces are sized for a blast, the muzzle is ~2 studs wide
	LightEmission = 1,
}
-- The emeralds' own glow (a soft halo), embers and trail, tinted with each gem's colour.
Fx.GemVfx = {
	GlowRate = 3.5, GlowSizeScale = 0.3, GlowLife = { 0.45, 0.6 },
	EmberRate = 5, EmberSizeScale = 0.4, EmberSpeed = { 1.5, 4 },
	TrailLife = 0.3, TrailWidth = 0.9, TrailTransparency = { 0.15, 1 },
}
-- Each gem's colour name, in SSE.Emeralds.Colors' order (the kit's VariantOrder may reorder the colours).
Fx.EmeraldNames = { "Green", "Red", "Blue", "Cyan", "Yellow", "White", "Purple" }
-- The owner's Blender kit under SuperSonicEventAssets.Meshes (audit/u4_event_kit: Bomb and Cannon Models,
-- ChaosEmerald and SpinBall MeshParts); until it is imported every one falls back to parts.
--   Bomb          fitted (uniformly) to Fx.Bomb.Size, nose -Y
--   ChaosEmerald  fitted by its height (Fx.Emerald.Size[2]); colours from its Color<Name> attributes in its
--                 VariantOrder when it has them
--   SpinBall      its own size (6.1 across: an R6 fits inside), the root at centre * CFrame.new(RootOffset),
--                 tinted with its ColorGold attribute
--   Cannon        ScaleTo(Fx.Boss.Scale), PivotTo(EggHull.CFrame * CFrame.new(MountHull x scale)); it slides out
--                 of the hull before an attack and back in to reload (Fx.Cannon), kicking on every shot
--   Ring          (2026-09-26, owner: a new kit piece) Sonic's gold ring, fitted to Fx.Rings.Size; a gold
--                 torus of Neon segments until it is imported
Fx.MeshNames = { Bomb = "Bomb", ChaosEmerald = "ChaosEmerald", SpinBall = "SpinBall", Cannon = "Cannon", Ring = "Ring" }

function Fx.EmitterAllowed(vfx: string, emitterName: string, set: string?): boolean
	if Fx.BlockedEmitters[emitterName] then
		return false
	end
	if set == "Full" then
		return true
	end
	local sets = Fx.EmitterSets[vfx]
	local list = sets and sets[set or "Low"]
	if not list then
		return false
	end
	return table.find(list, emitterName) ~= nil
end

-- Particles one burst fires: the rbxm's SabEmit (Burst_Hatch's own count) or EmitCount attribute,
-- times the tier's scale, at least 1.
function Fx.EmitCount(sabEmit: any, emitCount: any, scale: number?): number
	local count = tonumber(sabEmit) or tonumber(emitCount) or 1
	if count ~= count or count <= 0 then
		count = 1
	end
	return math.max(1, math.floor(count * (scale or 1) + 0.5))
end

----------------------------------------------------------------------
-- Bombs
----------------------------------------------------------------------
Fx.Bomb = {
	Size = 2.8, -- the fallback ball's diameter (and the mesh is fitted to this height)
	SpinSpeed = 7, -- radians a second
	-- The Blender bomb stands nose-down (-Y) in its own space: it is turned to fly nose first.
	NoseAxis = "-Y",
	ShakeRange = 140, -- a blast further than this does not punch the camera
	ShakeNear = 12, -- closer than this: the full punch
	WarningRise = 0.08, -- studs over the floor
	FirePatchRadius = 5, -- the burning patches around the crater
	-- 2026-09-26 (owner, v2): the missile visibly leaves the cannon's mouth: it starts BarrelDepth studs
	-- inside the barrel (ship scale 1, times the drawn scale) and slides out along it for ExitSeconds,
	-- blending into SSE.BombArc (no jump: BombPosition).
	BarrelDepth = 2.2,
	ExitSeconds = 0.2,
	-- Its trail: a smoke Beam from the bomb to a point TrailLag of the flight behind it (and, on the Full
	-- tier, the imported FireTrail flames on the bomb itself).
	TrailLag = 0.16,
	TrailWidth = 2.6,
	-- The fall's whistle: the bomb nearest the player (within WhistleNear studs of its target) whistles, its
	-- pitch falling from WhistleFrom to WhistleTo over the flight.
	WhistleNear = 70,
	WhistleFrom = 1.3,
	WhistleTo = 0.72,
	Wobble = 6, -- degrees of wobble about the flight
}

-- 2026-09-26 (owner, v2): the RED WARNING ZONE. It shows exactly the blast radius (SSE.Bombard.BlastRadius)
-- from the launch to the impact (the server's warning / flight time): a bright red ring pulsing faster and
-- faster, a fill that closes in quickly, a closing ring shrinking onto the edge, an alarm tick rising in pitch
-- near the impact; it fades out smoothly after the blast (FadeSeconds). Drawn with a SurfaceGui on a flat
-- part (crisp from above and on phones, no textures) over a Neon disc.
Fx.Warning = {
	Canvas = 256, -- the SurfaceGui's pixels across the part (the part is Span x the blast diameter)
	Span = 1.5, -- the part is this many blast diameters wide: the closing ring starts at the part's edge
	RingThickness = 12, -- canvas px (~1.6 studs at a 22-stud radius)
	PulseMin = 3, -- Hz at the launch
	PulseMax = 13, -- Hz at the impact
	FillBy = 0.8, -- the fill reaches the edge at this share of the flight (it "closes in quickly")
	CloseBy = 0.92, -- the closing ring meets the blast edge here
	DiscTransparency = 0.72, -- the Neon disc under it
	FadeSeconds = 0.4,
	Color = { 255, 30, 30 },
	Hot = { 255, 200, 60 },
	TickNear = 45, -- studs from the target: the local player hears the alarm
	TickFrom = 0.3, -- share of the flight the ticks begin
	TickSlow = 0.3, -- seconds between ticks at TickFrom
	TickFast = 0.06, -- ... at the impact
	TickPitch = { 1, 1.9 },
}

-- The bomb's position at t01 of its flight: out of the barrel for the first ExitSeconds (from `from` minus
-- `barrelDir` x depth, sliding out along the barrel), blended smoothly into SSE.BombArc.
function Fx.BombPosition(from: Vector3, to: Vector3, t01: number, flight: number, barrelDir: Vector3?, depth: number?): Vector3
	local t = math.clamp(tonumber(t01) or 0, 0, 1)
	local arc = SSE.BombArc(from, to, t)
	local dir = barrelDir
	local d = tonumber(depth) or 0
	if not dir or d <= 0 then
		return arc
	end
	local seconds = t * math.max(tonumber(flight) or 1, 0.05)
	local exit = Fx.Bomb.ExitSeconds
	if seconds >= exit then
		return arc
	end
	local k = seconds / exit
	local inside = from - dir * (d * (1 - k))
	local blend = k * k * (3 - 2 * k)
	return inside + (arc - inside) * blend
end

-- The red zone at t01 of a `flight`-second flight: (pulse 0..1, fill share of the blast radius 0..1, closing
-- ring's share of the part's half-width 0..1, heat 0..1: toward the hot colour near the impact).
function Fx.WarningLook(t01: number, flight: number): (number, number, number, number)
	local w = Fx.Warning
	local t = math.clamp(tonumber(t01) or 0, 0, 1)
	-- The pulse speeds up from PulseMin to PulseMax Hz (hz = min + (max - min) t^2); its phase is the
	-- integral of that over the flight's seconds, so the rhythm quickens without ever jumping.
	local f = math.max(tonumber(flight) or 1, 0.05)
	local s = t * f
	local phase = w.PulseMin * s + (w.PulseMax - w.PulseMin) * s * s * s / (3 * f * f)
	local pulse = 0.5 + 0.5 * math.sin(phase * math.pi * 2)
	local fill = 1 - (1 - math.clamp(t / w.FillBy, 0, 1)) ^ 3
	local startShare, endShare = 1, 1 / w.Span
	local c = math.clamp(t / w.CloseBy, 0, 1)
	local close = startShare + (endShare - startShare) * (1 - (1 - c) ^ 2)
	local heat = math.clamp((t - 0.55) / 0.45, 0, 1)
	return pulse, fill, close, heat
end

-- Seconds until the next alarm tick at t01 of the flight (nil before TickFrom), and its pitch.
function Fx.AlarmTick(t01: number): (number?, number)
	local w = Fx.Warning
	local t = math.clamp(tonumber(t01) or 0, 0, 1)
	if t < w.TickFrom then
		return nil, w.TickPitch[1]
	end
	local k = (t - w.TickFrom) / (1 - w.TickFrom)
	return w.TickSlow + (w.TickFast - w.TickSlow) * k ^ 0.8, w.TickPitch[1] + (w.TickPitch[2] - w.TickPitch[1]) * k
end

-- The whistle's pitch at t01 of the fall.
function Fx.WhistlePitch(t01: number): number
	local b = Fx.Bomb
	local t = math.clamp(tonumber(t01) or 0, 0, 1)
	return b.WhistleFrom + (b.WhistleTo - b.WhistleFrom) * t
end

----------------------------------------------------------------------
-- The cannon (2026-09-26, owner, v2): it DEPLOYS (slides out of the hull and levels) before an attack and
-- RETRACTS for the reload; it kicks back along the barrel on every shot and springs back, the ship jolts.
-- Hull space at ship scale 1 (times the drawn scale): Back / Up the retracted offset, Pitch its tilt up.
----------------------------------------------------------------------
Fx.Cannon = {
	DeploySeconds = 0.55,
	RetractSeconds = 0.7,
	Back = 2.4,
	Up = 1.2,
	Pitch = 38,
	KickStuds = 0.9, -- the recoil along the barrel
	KickSeconds = 0.32, -- out and the spring back (a damped spring)
	Jolt = 0.45, -- studs the whole ship jolts back on a shot
	JoltSeconds = 0.25,
}

-- How far out the cannon is (0 = in the hull, 1 = deployed) `age` seconds into `state` ("Attack" deploys,
-- "Reload" retracts, anything else: out, as in the Bombard phase).
function Fx.CannonOut(state: string?, age: number): number
	local c = Fx.Cannon
	local a = math.max(tonumber(age) or 0, 0)
	if state == "Reload" then
		local k = math.clamp(a / c.RetractSeconds, 0, 1)
		return 1 - k * k * (3 - 2 * k)
	elseif state == "Attack" then
		local k = math.clamp(a / c.DeploySeconds, 0, 1)
		-- Out with a small overshoot (a mechanical snap): easeOutBack.
		local s = 1.4
		local x = k - 1
		return math.clamp(1 + (s + 1) * x * x * x + s * x * x, 0, 1.08)
	end
	return 1
end

-- The recoil `age` seconds after a shot: 0..1 (a sharp kick back, then a damped spring home).
function Fx.CannonKick(age: number): number
	local c = Fx.Cannon
	local a = tonumber(age) or math.huge
	if a < 0 or a >= c.KickSeconds then
		return 0
	end
	local k = a / c.KickSeconds
	if k < 0.12 then
		return k / 0.12
	end
	local u = (k - 0.12) / 0.88
	return math.exp(-4.5 * u) * math.cos(u * math.pi * 2.2) * (1 - u)
end

-- The cannon's offset in hull space (studs at scale `scale`) for `out` (0..1) and `kick` (0..1); `C` the
-- CFrame table. The barrel points along its own -Z.
function Fx.CannonOffset(out: number, kick: number, scale: number, C: any?): any
	local CF = C or CFrame
	local c = Fx.Cannon
	local inward = 1 - math.clamp(out, 0, 1.1)
	return CF.new(0, c.Up * inward * scale, (c.Back * inward + c.KickStuds * kick) * scale) * CF.Angles(math.rad(c.Pitch * math.max(inward, 0)), 0, 0)
end

-- The bomb's camera punch at `distance` studs: (duration, strength, fov) or nil (too far).
function Fx.BombPunch(distance: number): (number?, number?, number?)
	local b, cam = Fx.Bomb, SSE.Camera.BombHit
	local d = tonumber(distance) or math.huge
	if d ~= d then
		return nil, nil, nil
	end
	local k = math.clamp(1 - (d - b.ShakeNear) / (b.ShakeRange - b.ShakeNear), 0, 1)
	if k < 0.08 then
		return nil, nil, nil
	end
	return cam.Shake[1], cam.Shake[2] * k, cam.Fov * k
end

-- A 2D sound's volume at `distance` studs (linear fade to Fx.SoundRange).
function Fx.Attenuate(volume: number, distance: number): number
	local d = tonumber(distance) or math.huge
	return volume * math.clamp(1 - d / Fx.SoundRange, 0, 1)
end

----------------------------------------------------------------------
-- The Chaos Emeralds (SSE.Emeralds: the orbit, AbsorbAt, the colours)
----------------------------------------------------------------------
Fx.Emerald = {
	FallSeconds = 1.1, -- they drop from the sky onto the orbit
	FallHeight = 60,
	ChestY = 0.6, -- the chest over the HumanoidRootPart
	Lift = 5, -- the Bezier's middle control point rises this much over the orbit
	Size = { 1.1, 1.5, 1.1 }, -- studs (the mesh is fitted to this height)
	LightRange = 14, -- 2026-09-26 (owner)
	LightBrightness = 2.5,
	SpinSpeed = 3, -- each gem turns on itself
	FlashSeconds = 0.55, -- the golden flash of the local player's absorption
}

local function smoothstep(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

-- Emerald i around the player's root at phaseT (seconds since the Emeralds phase began): the fall
-- from the sky onto the orbit (SSE.EmeraldOrbit: radius 6, y = sin(t * 4) * 1.5), the orbit, then a
-- quadratic Bezier from the orbit, over a lifted middle point, into the chest; nil once absorbed
-- (SSE.Emeralds.AbsorbAt, when the server turns the player Super).
function Fx.EmeraldOffset(i: number, phaseT: number): Vector3?
	local e, f = SSE.Emeralds, Fx.Emerald
	local t = tonumber(phaseT) or 0
	if t >= e.AbsorbAt then
		return nil
	end
	local orbit = SSE.EmeraldOrbit(i, math.max(t, 0))
	local convergeStart = e.AbsorbAt - e.ConvergeSeconds
	if t >= convergeStart then
		local k = smoothstep((t - convergeStart) / e.ConvergeSeconds)
		local u = 1 - k
		-- P0 = the orbit (still turning), P1 = halfway in and lifted, P2 = the chest.
		local p1x, p1y, p1z = orbit.X * 0.45, orbit.Y + f.Lift, orbit.Z * 0.45
		local p2y = f.ChestY
		return Vector3.new(
			u * u * orbit.X + 2 * u * k * p1x,
			u * u * orbit.Y + 2 * u * k * p1y + k * k * p2y,
			u * u * orbit.Z + 2 * u * k * p1z
		)
	end
	if t < f.FallSeconds then
		local drop = 1 - smoothstep(t / f.FallSeconds)
		return Vector3.new(orbit.X, orbit.Y + f.FallHeight * drop * drop, orbit.Z)
	end
	return orbit
end

----------------------------------------------------------------------
-- The homing attack (SSE.Homing: speed, range, cooldown; SSE.HomingPath / HomingDuration)
----------------------------------------------------------------------
Fx.Homing = {
	BallSize = 4.6, -- the spin ball's diameter (an R6 is ~5 studs tall)
	BallSpin = 52, -- radians a second, CFrame.Angles(spin, 0, 0) (v3: faster, the dash is faster)
	TrailLag = 0.18, -- the trail's tail follows the path this share behind the ball
	MaxSeconds = 2.5, -- a flight never lasts longer (a lost message, a stalled clock)
	ButtonCheckHz = 10, -- the reticle / button state
	-- 2026-09-26 (owner, v3) "fast and vibrant like the Sonic games": on a damaging hit the ball freezes on the
	-- hull for HitStop seconds (the hit-stop), the screen flashes white (HitFlash: its starting transparency and
	-- how long it fades) and shakes, then the snappy bounce (SSE.HomingBounce). Off his SHIELD: the zap and a
	-- real knock-back away from the ship (SSE.ShieldKnock, the server's own numbers) during which the body flies
	-- free for ShieldKnockSeconds (nothing steers it), still curled in the ball.
	HitStop = 0.065,
	HitFlash = { Transparency = 0.45, Seconds = 0.16 },
	HitShake = 1.35, -- times the contract's HomingHit shake strength
	ShieldKnockSeconds = 0.5,
	ShieldShake = { 0.22, 1.8 },
	-- The "hit!" plays at the arrival when the server accepted the attack as a damaging one (HomingGo, not
	-- shielded); an acceptance that comes this long after the arrival still plays it (else the server's Hit does).
	HitSoundGrace = 0.35,
	-- A Knock of kind "Shield" this soon after this client's own knock-back is the same bounce (not thrown twice).
	ShieldKnockDedupe = 0.7,
}

----------------------------------------------------------------------
-- The charged homing attack (2026-09-26, owner, v2): HOLD the homing input (F, Left Click, gamepad X, the
-- touch button, Space in the air without the Flight ability) to charge. The charge sound plays, a ring fills
-- over the charge's length (the contract's SSE.Homing.ChargeSeconds, else the sound's length, else Seconds),
-- the ball spins up round the player with growing wind and speed lines; the release (or the charge's end)
-- launches it. The client sends { Charge, clientTime } on the press and { Homing, clientTime, charge01 } on
-- the release; the server measures the charge itself and its "Hit" / "HomingGo" carry the strength.
-- The bigger the charge, the bigger the impact, Eggman's recoil and the bounce (ChargeScale).
----------------------------------------------------------------------
Fx.Charge = {
	Seconds = 1.2,
	SoundMin = 0.5, -- a sound length outside [SoundMin, SoundMax] is not the charge's length
	SoundMax = 2.5,
	SpinFrom = 8, -- the ball's roll (radians a second) at the press ...
	SpinTo = 70, -- ... and at full charge
	GrowFrom = 0.8, -- the ball's scale at the press / at full charge
	GrowTo = 1.15,
	WindFrom = 3, -- the wind rings' rate
	WindTo = 34,
	Impact = { 0.8, 1.9 }, -- the hit burst's size at no charge / full charge
	Recoil = { 1, 2.5 }, -- Eggman's recoil
	Bounce = { 0.9, 1.3 }, -- the bounce off the hull
	Fov = { -4, -12 }, -- the impact's FOV punch
	Shake = { 1, 2.2 }, -- the impact's shake strength factor
	MinCharge = 0.05, -- a tap still launches (at the smallest charge)
	RingSegments = 36,
	RingSize = 120, -- px (the ring round the screen's centre on a computer / console; on touch it rings the button)
}

-- The charge's length: the contract's, else the sound's (when it is a sensible length), else Fx.Charge.Seconds.
function Fx.ChargeSeconds(contractSeconds: any, soundLength: any): number
	local c = tonumber(contractSeconds)
	if c and c == c and c > 0.1 and c < 10 then
		return c
	end
	local s = tonumber(soundLength)
	if s and s == s and s >= Fx.Charge.SoundMin and s <= Fx.Charge.SoundMax then
		return s
	end
	return Fx.Charge.Seconds
end

-- The charge (0..1) after holding `held` seconds of a `seconds`-long charge.
function Fx.ChargeLevel(held: number, seconds: number): number
	local s = math.max(tonumber(seconds) or Fx.Charge.Seconds, 0.05)
	return math.clamp((tonumber(held) or 0) / s, 0, 1)
end

-- `pair` ({ at no charge, at full charge }) at `charge01` (eased: the last bit of the charge counts most).
function Fx.ChargeScale(charge01: any, pair: { number }): number
	local c = math.clamp(tonumber(charge01) or 0, 0, 1)
	local k = c * c * (3 - 2 * c)
	return pair[1] + (pair[2] - pair[1]) * k
end

-- The segments of the charge ring lit at `charge01` (of Fx.Charge.RingSegments).
function Fx.ChargeSegments(charge01: any): number
	local n = Fx.Charge.RingSegments
	return math.clamp(math.floor(math.clamp(tonumber(charge01) or 0, 0, 1) * n + 1e-6), 0, n)
end

----------------------------------------------------------------------
-- The spin ball's trail (2026-09-26, owner, v3): "many small Beams swirl round the ball: use ONE single BIG
-- trail that wraps round it". One Beam (the owner's "Beam113" texture, Textures.SpeedTrail), wide, whose curve
-- (its two Bezier control points: CurveSize0 / CurveSize1 along its attachments' X axes) wraps round the ball:
--   charging  both ends on a ring round the ball (Radius x the ball's size), Wrap degrees apart, the ribbon
--             hugging the ball between them, spinning faster as the charge grows (SpinFrom..SpinTo rad/s);
--   flying    it leaves the ball tangentially (spinning at FlightSpin) and streams back to a point on the path
--             behind the ball (the tail): one big spiralling trail.
-- Positions in the ball's frame (-Z = where it goes / faces, the ring in its XY plane).
----------------------------------------------------------------------
Fx.Trail = {
	Radius = 0.64, -- x the ball's size: just outside its surface (the ball's radius is 0.5)
	Wrap = 200, -- degrees round the ball while charging
	SpinFrom = 7, -- radians a second at the press ...
	SpinTo = 30, -- ... and at full charge
	FlightSpin = 26,
	FlightCurve = 1.5, -- x the ring radius: how far the ribbon swings out as it leaves the ball in flight
	Width0 = 0.95, -- x the ball's size, at the ball
	Width1Charge = 0.6, -- at the far end while charging
	Width1Flight = 0.28, -- at the tail in flight
	TextureSpeed = 2.4,
	Transparency = { { 0, 0.05 }, { 0.65, 0.35 }, { 1, 1 } },
	Color = { { 255, 236, 120 }, { 255, 255, 255 } },
	LightEmission = 1,
}

-- The wrap at `angle` (radians round the ring) for a ball `size` studs across: (p0, axis0, p1, axis1, curve0,
-- curve1) in the ball's frame. flight = false: both ends on the ring (curve = the cubic Bezier that follows a
-- circular arc of Wrap degrees: 4/3 tan(wrap/4) x the radius); flight = true: p1 / axis1 / curve1 unused (the
-- Beam ends at the tail with CurveSize1 0), the ribbon leaving the ball along its tangent turned back.
function Fx.TrailWrap(size: number, angle: number, flight: boolean): (Vector3, Vector3, Vector3, Vector3, number, number)
	local T = Fx.Trail
	local s = math.max(tonumber(size) or 1, 0.1)
	local r = s * T.Radius
	local a = tonumber(angle) or 0
	local c, sn = math.cos(a), math.sin(a)
	local p0 = Vector3.new(c * r, sn * r, if flight then -0.1 * r else -0.15 * r)
	local t0 = Vector3.new(-sn, c, 0)
	if flight then
		local axis = (t0 * 0.85 + Vector3.new(0, 0, 0.55)).Unit
		return p0, axis, p0, axis, r * T.FlightCurve, 0
	end
	local w = math.rad(T.Wrap)
	local b = a + w
	local c1, s1 = math.cos(b), math.sin(b)
	local p1 = Vector3.new(c1 * r, s1 * r, 0.15 * r)
	local t1 = Vector3.new(-s1, c1, 0)
	local k = 4 / 3 * math.tan(w / 4) * r
	return p0, t0, p1, t1, k, k
end

-- The point `u` (0..1) along a Beam from p0 to p1 with its control points (what Roblox draws): for tests and
-- the client's own checks.
function Fx.BeamPoint(p0: Vector3, axis0: Vector3, curve0: number, p1: Vector3, axis1: Vector3, curve1: number, u: number): Vector3
	local c0 = p0 + axis0 * curve0
	local c1 = p1 - axis1 * curve1
	local v = 1 - u
	return p0 * (v * v * v) + c0 * (3 * v * v * u) + c1 * (3 * v * u * u) + p1 * (u * u * u)
end

----------------------------------------------------------------------
-- The chaos (2026-09-26, owner, v2): during the event the sky and the light turn a fiery orange-red. The
-- Lighting properties (Brightness, OutdoorAmbient, Ambient, ClockTime) are Admin/AdminAbuseEffects'
-- blendLighting's: it mixes this layer in last, from the same saved base, with the weight ChaosTarget /
-- ChaosStep give, and puts the base back exactly when every layer is at 0. The grade is this client's own
-- ColorCorrectionEffect (Fx.GradeName) at the same weight.
----------------------------------------------------------------------
-- 2026-09-26 (owner, v3): "the sky gets way too red": a subtle warm orange haze now. The layer only goes
-- Strength of the way from the lobby's own light to the warm target at full weight (v2 went all the way to a
-- sunset at 17:51 with a red-orange ambient: the sky turned red and the sunset haze read as a red fog); the
-- time of day moves an hour at most, the grade is a light warm tint, the smoke round the lobby is lighter.
Fx.Chaos = {
	Lighting = { Brightness = 2.3, OutdoorAmbient = { 255, 176, 112 }, Ambient = { 200, 150, 112 }, ClockTime = 16.8 },
	Strength = 0.34,
	Grade = { TintColor = { 255, 240, 222 }, Saturation = 0.05, Contrast = 0.04, Brightness = 0 },
	InSeconds = 2.2, -- the weight goes 0 -> 1 in this long
	OutSeconds = 2.6, -- and back
	CinematicRise = { 1.0, 5.5 }, -- the opening cinematic: the sky turns while he lifts off
	DefeatFade = { 1.2, 5.0 }, -- the Defeat phase: back to the lobby's own sky
}

-- 2026-09-26 (owner, v3): the chaos is ZONE-BASED: the world looks normal for a player who is not in the event;
-- only while the local root is in the event's area does the light turn (a little darker, a subtle warm tint),
-- blending in / out as the player enters / leaves (or is teleported). The event client publishes it on the
-- LOCAL player as this attribute (true / nil; never replicated: a client's own Player attribute); Admin/
-- AdminAbuseEffects' chaos layer reads it too.
Fx.ChaosZoneAttribute = "SSE_ChaosZone"

-- The chaos weight the event wants now (0..1): `phase` / `phaseTime` (seconds since SSE_PhaseStart); `on` =
-- SSE.IsOn() (the kill switch: 0 at once); `inZone` (v3) = the local root in the event's area (false: 0).
function Fx.ChaosTarget(phase: any, phaseTime: any, on: boolean?, inZone: boolean?): number
	if on == false or inZone == false or type(phase) ~= "string" or phase == "" then
		return 0
	end
	local t = tonumber(phaseTime) or 0
	local phases = SSE.Phases or {}
	if phases.Cinematic ~= nil and phase == phases.Cinematic then
		local r = Fx.Chaos.CinematicRise
		local k = math.clamp((t - r[1]) / (r[2] - r[1]), 0, 1)
		return k * k * (3 - 2 * k)
	elseif phase == phases.Defeat then
		local f = Fx.Chaos.DefeatFade
		local k = math.clamp((t - f[1]) / (f[2] - f[1]), 0, 1)
		return 1 - k * k * (3 - 2 * k)
	elseif phases.Return ~= nil and phase == phases.Return then
		return 0 -- (v3) the trip home: the haze blends out
	end
	return 1
end

-- The weight one frame on (dt seconds), toward `target` at the In / Out speeds.
function Fx.ChaosStep(weight: number, target: number, dt: number): number
	local w = tonumber(weight) or 0
	local goal = math.clamp(tonumber(target) or 0, 0, 1)
	local step = math.max(tonumber(dt) or 0, 0)
	if goal > w then
		return math.min(goal, w + step / Fx.Chaos.InSeconds)
	end
	return math.max(goal, w - step / Fx.Chaos.OutSeconds)
end

-- The layer's Lighting values mixed over `base` at `weight` (what blendLighting writes, given the other layers'
-- result as `base`): { Brightness, OutdoorAmbient, Ambient, ClockTime }. `Color3` the constructor table.
-- 2026-09-26 (owner, v3): at most Chaos.Strength of the way to the warm target (weight 0: the base exactly).
function Fx.ChaosLighting(base: any, weight: number, Color3T: any): any
	local w = math.clamp(tonumber(weight) or 0, 0, 1) * math.clamp(tonumber(Fx.Chaos.Strength) or 1, 0, 1)
	local L = Fx.Chaos.Lighting
	local function rgb(v: { number }): any
		return Color3T.fromRGB(v[1], v[2], v[3])
	end
	local shortest = ((L.ClockTime - base.ClockTime + 12) % 24) - 12
	return {
		Brightness = base.Brightness + (L.Brightness - base.Brightness) * w,
		OutdoorAmbient = base.OutdoorAmbient:Lerp(rgb(L.OutdoorAmbient), w),
		Ambient = base.Ambient:Lerp(rgb(L.Ambient), w),
		ClockTime = (base.ClockTime + shortest * w) % 24,
	}
end

----------------------------------------------------------------------
-- The golden vignette while the local player is Super (2026-09-26, owner, v2): built in code, layered
-- UIGradient frames on the four edges (Tiers' Vignette: how many layers), breathing a little.
----------------------------------------------------------------------
Fx.Vignette = {
	Color = { 255, 200, 40 },
	Hot = { 255, 244, 170 },
	Layers = {
		{ Depth = 0.22, Edge = 0.5 }, -- a soft wide glow (share of the short side, the edge's transparency)
		{ Depth = 0.07, Edge = 0.22 }, -- a bright rim
	},
	FadeIn = 0.5,
	FadeOut = 0.8,
	PulseHz = 1.1,
	Pulse = 0.1, -- how much the edges breathe (transparency)
}

-- The edge transparency of `layer` at `level` (0..1 the vignette's fade) and `clock` (the breathing).
function Fx.VignetteEdge(layer: number, level: number, clock: number): number
	local spec = Fx.Vignette.Layers[layer] or Fx.Vignette.Layers[1]
	local l = math.clamp(tonumber(level) or 0, 0, 1)
	local breathe = Fx.Vignette.Pulse * (0.5 + 0.5 * math.sin((tonumber(clock) or 0) * math.pi * 2 * Fx.Vignette.PulseHz))
	return 1 - (1 - math.clamp(spec.Edge + breathe, 0, 1)) * l
end

----------------------------------------------------------------------
-- Eggman's gestures in the Egg Mobile (2026-09-26, owner, v2: aggressive and chaotic), laid over
-- Shared/LobbyNpcPose's EggmanDriving (its joints: { px, py, pz, rx, ry, rz }, degrees; rx > 0 swings an arm
-- forward and tips the body / head back). One-shots (Duration, eased in and out): Point (the attack call:
-- he points at the player, the other fist shaking), Fire (a jolt as the cannon fires), Hit (a flinch: arms
-- up, head back, shaking), Smug (a refused attack: leaning back, arms spread). Loops (while their state
-- lasts): Reload (panicking at the levers, looking left and right) and Defeat (slumped, flailing).
-- The legs stay under the cockpit floor: any pitch added to the root is taken back at the hips.
----------------------------------------------------------------------
Fx.Gestures = {
	Point = { Duration = 1.4, In = 0.15, Out = 0.35 },
	Fire = { Duration = 0.4, In = 0.03, Out = 0.3 },
	Hit = { Duration = 0.8, In = 0.04, Out = 0.45 },
	Smug = { Duration = 1.8, In = 0.2, Out = 0.45 },
}
Fx.GestureLoops = { Reload = { In = 0.3 }, Defeat = { In = 0.25 } }

local TAU = math.pi * 2

local function windowWeight(age: number, spec: any): number
	if age < 0 or age >= spec.Duration then
		return 0
	end
	local w = 1
	if age < spec.In then
		w = age / spec.In
	elseif age > spec.Duration - spec.Out then
		w = (spec.Duration - age) / spec.Out
	end
	return w * w * (3 - 2 * w)
end

-- The weight of gesture `name` `age` seconds in (loops: eased in, then 1).
function Fx.GestureWeight(name: string, age: number): number
	local a = tonumber(age) or -1
	local one = (Fx.Gestures :: any)[name]
	if one then
		return windowWeight(a, one)
	end
	local loop = (Fx.GestureLoops :: any)[name]
	if loop then
		if a < 0 then
			return 0
		end
		local k = math.clamp(a / loop.In, 0, 1)
		return k * k * (3 - 2 * k)
	end
	return 0
end

local function blendTo(o: { number }, target: { number }, w: number)
	for i = 1, 6 do
		o[i] += ((target[i] or 0) - o[i]) * w
	end
end

-- Lays gesture `name` (`age` seconds in, weight w; `aim` { yaw, pitch } toward the player, degrees; `aimArm`
-- LobbyNpcPose.AimArm) over `out`. Returns out.
function Fx.ApplyGesture(out: any, name: string, age: number, w: number, aim: any?, aimArm: any?): any
	if w <= 0 then
		return out
	end
	local root, neck = out.RootJoint, out.Neck
	local rs, ls = out["Right Shoulder"], out["Left Shoulder"]
	local before = root[4]
	local yaw = math.clamp(aim and aim.yaw or 0, -70, 70)
	local pitch = math.clamp(aim and aim.pitch or 0, -15, 35)
	if name == "Point" then
		local rx, rz = 95, 0
		if aimArm then
			rx, rz = aimArm(math.max(pitch, 0) * 0.5 + 12, yaw * 0.9)
		end
		blendTo(rs, { 0, 0, 0, rx, 0, rz }, w)
		local shake = math.sin(TAU * 11 * age)
		blendTo(ls, { 0, 0, 0, 128 + 14 * shake, 0, -30 + 6 * shake }, w)
		neck[5] += 0.7 * yaw * w
		neck[4] -= 6 * w
		root[4] -= 5 * w -- leaning in
		root[5] += 0.1 * yaw * w
	elseif name == "Fire" then
		local kick = math.exp(-age * 9)
		root[4] += 7 * kick * w -- thrown back
		neck[4] += 10 * kick * w
		rs[4] += 22 * kick * w
		ls[4] += 22 * kick * w
	elseif name == "Hit" then
		local shake = math.sin(TAU * 17 * age)
		root[4] += 13 * w
		root[6] += 5 * shake * w
		neck[4] += 22 * w
		neck[5] += 12 * shake * w
		blendTo(rs, { 0, 0, 0, 150 + 8 * shake, 0, 42 }, w)
		blendTo(ls, { 0, 0, 0, 150 - 8 * shake, 0, -42 }, w)
	elseif name == "Smug" then
		local chuckle = math.abs(math.sin(TAU * 4 * age))
		root[4] += (6 + 2 * chuckle) * w
		neck[4] += 12 * w
		neck[5] += 0.6 * yaw * w
		blendTo(rs, { 0, 0, 0, 100 + 6 * chuckle, 0, 58 }, w)
		blendTo(ls, { 0, 0, 0, 100 + 6 * chuckle, 0, -58 }, w)
	elseif name == "Reload" then
		-- Panic at the levers: both hands pumping them, head snapping left and right, the body jittering.
		local pump = math.sin(TAU * 6.5 * age)
		rs[4] += 16 * pump * w
		ls[4] -= 16 * pump * w
		neck[5] += 34 * math.sin(TAU * 1.9 * age) * w
		neck[4] -= 12 * w
		root[4] -= 4 * w
		root[6] += 2.5 * math.sin(TAU * 9 * age) * w
	elseif name == "Defeat" then
		-- Slumped, head down, arms flailing over his head, the body swaying.
		local flail = math.sin(TAU * 2.6 * age)
		root[4] -= 10 * w
		root[5] += 14 * math.sin(TAU * 1.1 * age) * w
		neck[4] -= 22 * w
		blendTo(rs, { 0, 0, 0, 140 + 35 * flail, 0, 30 + 12 * flail }, w)
		blendTo(ls, { 0, 0, 0, 140 - 35 * flail, 0, -30 + 12 * flail }, w)
	end
	-- The legs stay under the cockpit floor: the added pitch is taken back at the hips.
	local added = root[4] - before
	for _, hipName in { "Right Hip", "Left Hip" } do
		local hip = out[hipName]
		if hip then
			hip[4] -= added
		end
	end
	return out
end

----------------------------------------------------------------------
-- The lobby on fire (2026-09-26, owner, v2): smoke columns and burning patches round the lobby while the
-- chaos lasts (Tiers: SmokeColumns / AmbientFires), embers drifting round the camera (EmberRate). Places
-- are a pure function of the event's seed (every client sees the same ones).
----------------------------------------------------------------------
-- 2026-09-26 (owner, v3): lighter smoke (a thinner, paler haze: the lobby stays readable).
Fx.Ambience = {
	RadiusMin = 60, -- studs from the origin
	RadiusMax = 150,
	SmokeRise = 14, -- studs a second
	SmokeLife = { 4, 5.5 },
	SmokeSize = 2.4, -- times the imported smoke's size
	SmokeRates = { 3, 2 }, -- particles a second of the imported "smoke" / "smoke_2" (v2: 5 / 3)
	SmokeColor = { { 150, 132, 118 }, { 112, 104, 100 } }, -- warm grey, lighter than v2's soot
	MaxAcross = 30, -- (v3) on the race map: the places stay inside the corridor (the walls at +-38)
	EmberBox = { 90, 4, 90 }, -- the emitter's box round the camera (studs)
	EmberHeight = -12, -- under the camera: they rise past it
}

-- `count` places round `origin` from `seed`: { Vector3 offset (Y 0), ... } spread round the circle.
function Fx.AmbiencePoints(seed: any, count: number): { Vector3 }
	local out = {}
	local s = math.floor(math.abs(tonumber(seed) or 1)) % 2147483647 + 1
	local function rand(): number
		s = (s * 48271) % 2147483647
		return s / 2147483647
	end
	local n = math.max(0, math.floor(tonumber(count) or 0))
	local a = Fx.Ambience
	for index = 1, n do
		local angle = (index - 1 + 0.2 + 0.6 * rand()) / math.max(n, 1) * TAU
		local radius = a.RadiusMin + (a.RadiusMax - a.RadiusMin) * rand()
		out[index] = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
	end
	return out
end

----------------------------------------------------------------------
-- The ring rain at the defeat (2026-09-26, owner, v2): the broken ship spills Sonic's gold rings that fly
-- out on arcs, land round the lobby, spin and bob there, and fade out smoothly after a while if nobody takes
-- them. A player takes one by touching it (the client asks the server; the server validates and pays).
----------------------------------------------------------------------
-- The kit's Meshes.Ring (2026-09-26): a MeshPart 2.4 x 2.4 x 0.6 standing upright, its hole facing +-Z,
-- spun about its Y; SmoothPlastic gold (255, 196, 30), Reflectance 0.35; ColorSparkle for the pickup flash.
Fx.Rings = {
	Size = 2.4, -- studs across (the kit's Ring is fitted to this)
	Thickness = 0.6, -- the fallback torus's tube (the kit's TubeDiameter)
	Segments = 12, -- the fallback torus's glossy pieces
	Color = { 255, 196, 30 },
	Sparkle = { 255, 238, 150 }, -- the pickup flash (the kit's ColorSparkle)
	ArcHeight = 18, -- the arc's rise over the straight line
	FlightMin = 0.9,
	FlightPerStud = 1 / 90,
	FlightMax = 1.9,
	Hover = 1.6, -- resting this high over the floor
	Spin = 3.2, -- radians a second
	Bob = 0.3,
	BobHz = 0.9,
	Life = 14, -- seconds on the ground before it fades (the server's own life wins)
	FadeSeconds = 0.8,
	TakeRadius = 4.6, -- studs from the root: touched
	TakeCheckHz = 15,
	PopSeconds = 0.35, -- a taken ring pops up and fades
}

-- A ring's flight time from `from` to `to`.
function Fx.RingFlight(from: Vector3, to: Vector3): number
	local r = Fx.Rings
	local dx, dz = to.X - from.X, to.Z - from.Z
	return math.clamp(r.FlightMin + math.sqrt(dx * dx + dz * dz) * r.FlightPerStud, r.FlightMin, r.FlightMax)
end

-- A ring's place at t01 of its flight (a parabola over the straight line).
function Fx.RingArc(from: Vector3, to: Vector3, t01: number): Vector3
	local t = math.clamp(tonumber(t01) or 0, 0, 1)
	local rise = Fx.Rings.ArcHeight * 4 * t * (1 - t)
	return from + (to - from) * t + Vector3.new(0, rise, 0)
end

-- A resting ring's opacity `age` seconds after it landed, for a ring that lives `life` seconds: 1 until the
-- fade, then down to 0 over FadeSeconds.
function Fx.RingAlpha(age: number, life: number?): number
	local r = Fx.Rings
	local l = tonumber(life) or r.Life
	local a = tonumber(age) or 0
	if a <= l - r.FadeSeconds then
		return 1
	end
	return math.clamp((l - a) / r.FadeSeconds, 0, 1)
end
-- The inputs (2026-09-26, owner): PC F or Left Click, gamepad X (A is the jump / the flight hold, Y is
-- Heat Vision, B closes menus), touch: the round button while airborne. Space in the air too, but only
-- for a player WITHOUT the Flight ability equipped: with it, holding Space in the air lifts off at once
-- (the world FlightAbility scripts: 0.18 s after the jump), so there Space stays the Flight's and the
-- homing attack is F / Left Click (the reticle's hint says which).
-- 2026-09-26 (owner, v2): every one of them is HELD to charge and released to launch (Fx.Charge); the
-- charge works on the ground too (only a Space press needs the air: on the ground Space is the jump).
-- 2026-09-26 (owner, v3) "like the original Sonic games, simple": jump, then press JUMP AGAIN in the air (Space,
-- gamepad A or the touch jump button: UserInputService.JumpRequest, whatever the device) while Eggman is locked
-- on: the instant, uncharged homing attack ({ "Homing", t, 0 }, no "Charge" before it). A press counts when no
-- jump request came for JumpEdgeGap seconds before it (a held jump key keeps requesting: one press), and only
-- while the character is in the air (the jump itself, pressed on the ground, never fires it). F / Left Click
-- / gamepad X / the touch button HELD stay the optional stronger, charged attack. The Flight ability never
-- competes: it is off in the event's area (EventFlightBlocked); with it on elsewhere, jump presses stay its own.
Fx.Inputs = {
	Keys = { "F" },
	Gamepad = { "ButtonX" },
	Mouse = true,
	JumpInAir = true,
	JumpEdgeGap = 0.12,
	Action = "SuperSonicHoming",
	-- Above SpeedsterClient's sprint and the flight hold (ContextActionPriority.High = 2000).
	Priority = 2500,
}

-- 2026-09-26 (owner, v3): the controller prompt on the lock-on reticle, only when the last input is a gamepad:
-- "(A)" in the air (press jump again: the instant attack), "(X)" on the ground (hold X: the charged one).
Fx.PadPrompt = { Jump = "A", Charge = "X" }
function Fx.ReticlePrompt(inputKind: string?, airborne: boolean?): string
	if inputKind ~= "Gamepad" then
		return ""
	end
	return "(" .. (if airborne then Fx.PadPrompt.Jump else Fx.PadPrompt.Charge) .. ")"
end

-- Is this jump request a new press? (the last request came more than JumpEdgeGap before `clock`)
function Fx.JumpPress(clock: number, lastRequest: number?): boolean
	return (tonumber(clock) or 0) - (tonumber(lastRequest) or -math.huge) > Fx.Inputs.JumpEdgeGap
end

----------------------------------------------------------------------
-- The HUD during the event (2026-09-26, owner, v3): "hide the other UIs during the event like when a menu is
-- open, except the topbar buttons; keep only the event's own minimal UI". While an event runs and the local
-- root is in its area (SSE.InArena, exit test), the client holds the game's HUD away with
-- MenuEvents.SetHUDVisible(false, MenuName) (Main HUD, Starter Pack, Sonic Burst / Heat Vision buttons, the
-- speedometer... slide off as for a menu); TopbarPlus and Roblox's top bar stay; when a menu the player opened
-- closes (the HUD asks to come back) the hold asks again; at the end (or leaving the area) SetHUDVisible(true).
----------------------------------------------------------------------
Fx.HudHide = { MenuName = "SuperSonicEvent" }

-- Whether the HUD should be held away: an event running (phase set, not killed), the root in its area, not racing.
function Fx.HudHideWanted(active: boolean?, phase: any, inArena: boolean?, racing: boolean?): boolean
	return active == true and type(phase) == "string" and phase ~= "" and inArena == true and racing ~= true
end

----------------------------------------------------------------------
-- Freeze (2026-09-26, owner, v3): during the contract's freeze windows (SSE.FreezeWindows: the intro in the
-- lobby, the Teleport beat's fades, the emeralds' shot, the crash, the escape's outro, the Return beat) the local
-- player stands still (the root anchored locally, velocity 0, the controls off) when SSE.FreezesHere says so
-- (its root in that window's area; for the Return, where the root was when it began); exactly back after.
----------------------------------------------------------------------
function Fx.FreezeWanted(phase: any, phaseTime: any, pos: Vector3?, origin: Vector3?, lobbyOrigin: Vector3?): boolean
	if pos == nil or origin == nil or type(SSE.FreezesHere) ~= "function" then
		return false
	end
	return SSE.FreezesHere(phase, phaseTime, pos, origin, lobbyOrigin) == true
end

----------------------------------------------------------------------
-- The beats (2026-09-26, owner, v3): the Teleport beat (the lobby to the race map) and the Return beat (back to
-- the lobby) fade the screen to black (SSE.Beats: out by FadeOut, the server moves the players at MoveAt, in by
-- FadeIn) for the players the trip moves. The client keeps it black until its root has really arrived (the move
-- comes over the network), at most HoldMax seconds past MoveAt, then fades in over FadeIn - MoveAt.
----------------------------------------------------------------------
Fx.Beat = { HoldMax = 3.0, StreamTimeout = 4 }

-- The black's level (0..1) `t` seconds into a beat (`beat` = SSE.Beats[phase]); `arrivedAt` = the beat time the
-- root arrived (nil: not yet).
function Fx.BeatFade(beat: any, t: number, arrivedAt: number?): number
	if type(beat) ~= "table" then
		return 0
	end
	local out, moveAt, fadeIn = tonumber(beat.FadeOut) or 0.6, tonumber(beat.MoveAt) or 0.6, tonumber(beat.FadeIn) or 1.4
	local x = tonumber(t) or 0
	if x < 0 then
		return 0
	end
	if x < out then
		local k = x / math.max(out, 1e-3)
		return k * k * (3 - 2 * k)
	end
	local from = math.max(moveAt, math.min(tonumber(arrivedAt) or math.huge, moveAt + Fx.Beat.HoldMax), out)
	if arrivedAt == nil then
		from = math.max(from, moveAt + Fx.Beat.HoldMax)
	end
	if x < from then
		return 1
	end
	local k = math.clamp((x - from) / math.max(fadeIn - moveAt, 0.05), 0, 1)
	return 1 - k * k * (3 - 2 * k)
end

----------------------------------------------------------------------
-- The game's UI look (2026-09-26, owner, v3: "match the game's UI style"): the Main HUD's level and stamina
-- bars (uineww / the places' Mainhud): white glass (0.3 transparent) with a navy ink outline (11, 27, 61) and a
-- faint light rim, a solid fill with the same ink outline, round corners, GothamSSm Bold white words with a
-- navy stroke; the designer's cards: navy plates (50, 78, 111), FredokaOne white words, gradient buttons with a
-- light rim and a dark edge.
----------------------------------------------------------------------
Fx.Style = {
	Ink = { 11, 27, 61 },
	Rim = { 242, 253, 255 },
	Glass = { 255, 255, 255 },
	GlassTransparency = 0.3,
	Plate = { 50, 78, 111 },
	Font = "rbxasset://fonts/families/GothamSSm.json",
	HpFill = { 255, 72, 64 },
	HpTrail = { 255, 232, 150 },
	Yes = { { 120, 235, 95 }, { 60, 190, 60 }, { 30, 130, 40 } },
	No = { { 255, 130, 120 }, { 220, 60, 60 }, { 150, 30, 40 } },
}
-- The boss bar: small and clean at the top centre (HUD pixels, under Roblox's top bar).
Fx.BossBar = {
	WidthShare = 0.3, MinWidth = 200, MaxWidth = 340, -- of the screen's width
	Top = 6,
	NameHeight = 15, -- "DR. EGGMAN" over the bar
	TrackHeight = 18,
	CueHeight = 15, -- the tiny "ATTACK NOW!" under it (Reload windows only)
	Gap = 2,
}
function Fx.BossBarWidth(viewWidth: number): number
	local b = Fx.BossBar
	return math.clamp(math.floor((tonumber(viewWidth) or 800) * b.WidthShare + 0.5), b.MinWidth, b.MaxWidth)
end
-- Its whole height, the cue included (what the dialogue keeps under on phones).
function Fx.BossBarHeight(): number
	local b = Fx.BossBar
	return b.NameHeight + b.Gap + b.TrackHeight + b.Gap + b.CueHeight
end

----------------------------------------------------------------------
-- The invite (2026-09-26, owner, v3): { "Invite", eventId, why } for a player outside the event's area: a small
-- optional card in the game's style ("Dr. Eggman is attacking! Join the event?" YES / NO, en / es / pt,
-- gamepad-selectable). YES -> { "TeleportToEvent", eventId }. It closes itself when the invite no longer holds
-- (SSE.InviteOpen: the Cinematic .. the Battle), the event id changes, the root is in the area, on TeleportGo /
-- TeleportNo, on NO, or after Seconds (then it counts as a NO for this event: never nagging again).
----------------------------------------------------------------------
----------------------------------------------------------------------
-- The race map (2026-09-26, owner, v3): the fight moves to Workspace.RaceArena, "just the plain map". While an
-- event runs every client hides the race-only pieces there LOCALLY and puts each back exactly after: the start
-- gantry and its lights, the StartGate / StopBar, the start / finish arches over the track (the decor's
-- StartBeam / StartLine / StartPost, FinishBanner / FinishLine / FinishPost, the FinishGate), the RaceOrb, the
-- SpeedPads and the kit's pad art (Kit_SpeedPad), the spike tiles (RaceSpikeTile) and any race sign (a
-- BillboardGui / SurfaceGui). Terrain, decor, water, fences, banks, walls and the track stay. A hidden part gets
-- LocalTransparencyModifier 1 and (for this client's own physics) CanCollide false; its lights, beams, emitters
-- and signs are switched off.
----------------------------------------------------------------------
Fx.ArenaHide = {
	ArenaName = "RaceArena",
	Names = {
		Structure = true, StartGate = true, StopBar = true, StartGantry = true, FinishGate = true, RaceOrb = true,
		SpeedPads = true, SpeedPad = true, Spikes = true, StartBeam = true, StartLine = true, StartPost = true,
		FinishBanner = true, FinishLine = true, FinishPost = true,
	},
	Prefixes = { "Kit_SpeedPad", "SpikeTile" },
	Attribute = "RaceSpikeTile",
}

-- Is a piece of the arena race-only? `chain`: its own name, then its ancestors' up to (not including) the arena;
-- `spike`: it carries the RaceSpikeTile attribute; `sign`: a BillboardGui / SurfaceGui.
function Fx.ArenaRaceOnly(chain: { string }, spike: boolean?, sign: boolean?): boolean
	if spike == true or sign == true then
		return true
	end
	local H = Fx.ArenaHide
	for _, name in chain do
		if H.Names[name] then
			return true
		end
		for _, prefix in H.Prefixes do
			if string.sub(name, 1, #prefix) == prefix then
				return true
			end
		end
	end
	return false
end

Fx.Invite = { Seconds = 20, Width = 340, Height = 124, Top = 0.16, MinScale = 0.62, CheckHz = 5 }
-- The local player's own attribute while the freeze holds it (a client-side Player attribute: never replicated).
Fx.FreezeAttribute = "SSE_Frozen"

function Fx.InviteShown(inviteId: any, eventId: any, phase: any, inArena: boolean?, declinedId: any): boolean
	if inviteId == nil or inviteId ~= eventId or inviteId == declinedId or inArena == true then
		return false
	end
	return type(SSE.InviteOpen) == "function" and SSE.InviteOpen(phase) == true
end

-- Does this player have the Flight ability equipped (the world FlightAbility scripts' flightEquipped:
-- owned or on a temporary pass, and equipped)? `attributes`: the player's FlightAbilityOwned,
-- FlightAbilityEquipped, EquippedAbility, TemporaryFlightExpireUnix; `enabled`: Config.AbilityFlightEnabled.
function Fx.FlightEquipped(attributes: any, nowUnix: number, enabled: boolean): boolean
	if not enabled or type(attributes) ~= "table" then
		return false
	end
	local temporary = (tonumber(attributes.TemporaryFlightExpireUnix) or 0) > nowUnix
	local owns = attributes.FlightAbilityOwned == true or temporary
	return owns and (attributes.FlightAbilityEquipped == true or attributes.EquippedAbility == "Flight" or temporary)
end

-- Where a homing attack ends: SSE.Boss.HitRadius short of the ship's centre, on the attacker's side.
function Fx.HitPoint(bossPos: Vector3, from: Vector3): Vector3
	local r = SSE.Boss.HitRadius
	local dx, dy, dz = from.X - bossPos.X, from.Y - bossPos.Y, from.Z - bossPos.Z
	local length = math.sqrt(dx * dx + dy * dy + dz * dz)
	if length < 1e-3 then
		return Vector3.new(bossPos.X, bossPos.Y - r, bossPos.Z)
	end
	if length <= r then
		return from
	end
	return Vector3.new(bossPos.X + dx / length * r, bossPos.Y + dy / length * r, bossPos.Z + dz / length * r)
end

-- Is the ship close enough to lock on (the client gates at SSE.Homing.Range; the server adds slack)?
function Fx.InRange(rootPos: Vector3, bossPos: Vector3): boolean
	local dx, dy, dz = rootPos.X - bossPos.X, rootPos.Y - bossPos.Y, rootPos.Z - bossPos.Z
	local r = SSE.Homing.Range
	return dx * dx + dy * dy + dz * dz <= r * r
end

-- A frame at `pos` whose -Z (LookVector) runs along `dir` (fromMatrix: Lune's lookAt is wrong).
function Fx.FrameAlong(pos: Vector3, dir: Vector3, C: any?): any
	local CF = C or CFrame
	local length = dir.Magnitude
	if length < 1e-4 then
		return CF.new(pos.X, pos.Y, pos.Z)
	end
	local look = dir / length
	local up = if math.abs(look.Y) > 0.98 then Vector3.new(1, 0, 0) else Vector3.new(0, 1, 0)
	local right = look:Cross(up).Unit
	local up2 = right:Cross(look).Unit
	return CF.fromMatrix(pos, right, up2, -look)
end

----------------------------------------------------------------------
-- The touch HOMING ATTACK button (Main HUD pixels, as Shared/HudErgonomics)
----------------------------------------------------------------------
Fx.Button = {
	Share = 0.2, -- of the screen's short side
	Min = 64,
	Max = 108,
	JumpMargin = 24, -- HudErgonomics.CustomJumpMargin: the jumping thumb never lands on it
	StickMargin = 12,
	PieceMargin = 12, -- from Sprint, the Burst and the Heat Vision buttons
	Step = 8, -- the search grid
}

function Fx.HomingButtonSize(width: number, hudHeight: number): number
	local b = Fx.Button
	return math.clamp(math.floor(math.min(width, hudHeight) * b.Share + 0.5), b.Min, b.Max)
end

local function rect(left: number, top: number, width: number, height: number): any
	return { Left = left, Top = top, Right = left + width, Bottom = top + height }
end

-- The button's place on a `width` x `hudHeight` Main HUD screen: the clear place nearest to just above
-- Roblox's jump button (the thumb is there after the jump), in the right half, never on the jump button
-- (JumpMargin), the thumbstick area, the player's touch pieces (`plan`: HudErgonomics.TouchControls'
-- S / B / H) or `avoid` (the phone column's speedometer, boost cards, badges and Starter Pack: a rect's
-- own Clearance or 6 px); off the level and stamina bars when it can be. Returns the rect with Size, X, Y.
function Fx.HomingButtonRect(width: number, hudHeight: number, plan: any?, avoid: { any }?): any
	local b = Fx.Button
	local size = Fx.HomingButtonSize(width, hudHeight)
	local jump = HudErgonomics.JumpButton(width, hudHeight)
	local stick = HudErgonomics.Thumbstick(width, hudHeight)
	local bars = HudErgonomics.CentreBarRects(width, hudHeight)
	local zones = {
		{ Rect = jump, Margin = b.JumpMargin },
		{ Rect = stick, Margin = b.StickMargin },
	}
	for _, key in { "S", "B", "H", "T" } do
		local piece = plan and plan[key]
		if piece then
			table.insert(zones, { Rect = piece, Margin = b.PieceMargin })
		end
	end
	for _, other in avoid or {} do
		table.insert(zones, { Rect = other, Margin = other.Clearance or 6 })
	end
	local function clear(candidate: any, offTheBars: boolean): boolean
		if candidate.Top < 8 or candidate.Bottom > hudHeight - 4 or candidate.Left < 8 or candidate.Right > width - 4 then
			return false
		end
		for _, zone in zones do
			if HudErgonomics.Overlaps(candidate, zone.Rect, zone.Margin) then
				return false
			end
		end
		if offTheBars then
			for _, bar in bars do
				if HudErgonomics.Overlaps(candidate, bar, 2) then
					return false
				end
			end
		end
		return true
	end
	local wantX = (jump.Left + jump.Right) / 2 - size * 0.25
	local wantY = jump.Top - b.JumpMargin - 6 - size / 2
	local chosen, best = nil, math.huge
	-- The right half first (the right thumb), off the bars; then over the bars; then anywhere.
	for _, pass in { { width / 2, true }, { width / 2, false }, { 8, false } } do
		for top = 8, hudHeight - 4 - size, b.Step do
			for left = pass[1] :: number, width - 4 - size, b.Step do
				local candidate = rect(left, top, size, size)
				local d = (left + size / 2 - wantX) ^ 2 + (top + size / 2 - wantY) ^ 2
				if d < best and clear(candidate, pass[2] :: boolean) then
					chosen, best = candidate, d
				end
			end
		end
		if chosen then
			break
		end
	end
	-- Last resort (a screen too small for all of it): above the jump button.
	chosen = chosen or rect(math.clamp(wantX - size / 2, 8, math.max(8, width - size - 4)), math.max(8, jump.Top - b.JumpMargin - size), size, size)
	chosen.Size = size
	chosen.X = (chosen.Left + chosen.Right) / 2
	chosen.Y = (chosen.Top + chosen.Bottom) / 2
	return chosen
end

----------------------------------------------------------------------
-- Words (en / es / pt; anything else reads English)
----------------------------------------------------------------------
Fx.Text = {
	en = {
		Homing = "HOMING\nATTACK",
		BossName = "DR. EGGMAN",
		BossShip = "EGG MOBILE",
		Wins = "Wins",
		Speed = "Speed",
		Jump = "JUMP!",
		HintKeys = "F / CLICK",
		HintKeysSpace = "SPACE / F",
		HintPad = "X",
		HintTouch = "TAP!",
		Cap = "Hit limit reached for this event!",
		Intro = "DR. EGGMAN IS ATTACKING!",
		Cinematic = "DR. EGGMAN IS ATTACKING!",
		Bombard = "DODGE THE BOMBS!",
		Emeralds = "THE CHAOS EMERALDS!",
		Battle = "HOMING ATTACK THE EGG MOBILE!",
		Defeat = "EGGMAN DEFEATED!",
		Escape = "EGGMAN GOT AWAY...",
		-- The chat's system lines (posted by each client: TextChannel:DisplaySystemMessage is client-only).
		ChatStart = "Dr. Eggman is attacking the lobby! Dodge the bombs, grab the Chaos Emeralds and go Super!",
		ChatDefeat = "Dr. Eggman was defeated! Every hit paid +600 Wins and +30,000 Speed. Grab the gold rings!",
		ChatEscape = "Dr. Eggman escaped... he will be back!",
		-- A refused homing attack (the server's HomingNo reasons, SSE.HomingRefusals, and the client's own).
		No_range = "Too far! Get closer",
		No_cooldown = "Wait a moment...",
		No_notSuper = "Only Super Sonic can do that!",
		No_racing = "Not during a race!",
		No_busy = "Already attacking!",
		No_dead = "",
		No_phase = "",
		No_off = "",
		No_ground = "Jump first!",
		No_flying = "Land first: no homing attack while flying!",
		No_stunned = "",
		No_shielded = "SHIELDED! Wait for him to RELOAD!",
		-- 2026-09-26 (owner, v2): the charge, the shield, the rings.
		HintHoldKeys = "HOLD F / CLICK",
		HintHoldKeysSpace = "HOLD SPACE / F",
		HintHoldPad = "HOLD X",
		HintHoldTouch = "HOLD!",
		Charge = "CHARGE",
		ChargeMax = "MAX!",
		Shielded = "SHIELD UP",
		Vulnerable = "ATTACK NOW!",
		Reloading = "RELOADING!",
		Rings = "+%d RINGS",
		Ring = "+1 RING",
		-- 2026-09-26 (owner, v3): the invite card.
		Invite = "Dr. Eggman is attacking! Join the event?",
		InviteYes = "YES",
		InviteNo = "NO",
	},
	es = {
		Homing = "ATAQUE\nTELEDIRIGIDO",
		BossName = "DR. EGGMAN",
		BossShip = "EGG MOBILE",
		Wins = "Victorias",
		Speed = "Velocidad",
		Jump = "¡SALTA!",
		HintKeys = "F / CLIC",
		HintKeysSpace = "ESPACIO / F",
		HintPad = "X",
		HintTouch = "¡TOCA!",
		Cap = "¡Límite de golpes de este evento!",
		Intro = "¡EL DR. EGGMAN ATACA!",
		Cinematic = "¡EL DR. EGGMAN ATACA!",
		Bombard = "¡ESQUIVA LAS BOMBAS!",
		Emeralds = "¡LAS ESMERALDAS DEL CAOS!",
		Battle = "¡ATAQUE TELEDIRIGIDO AL EGG MOBILE!",
		Defeat = "¡EGGMAN DERROTADO!",
		Escape = "EGGMAN ESCAPÓ...",
		ChatStart = "¡El Dr. Eggman ataca el lobby! Esquiva las bombas, toma las Esmeraldas del Caos y vuélvete Super.",
		ChatDefeat = "¡El Dr. Eggman fue derrotado! Cada golpe dio +600 Victorias y +30,000 Velocidad. ¡Toma los anillos de oro!",
		ChatEscape = "El Dr. Eggman escapó... ¡volverá!",
		No_range = "¡Muy lejos! Acércate",
		No_cooldown = "Espera un momento...",
		No_notSuper = "¡Solo Super Sonic puede hacerlo!",
		No_racing = "¡No durante una carrera!",
		No_busy = "¡Ya estás atacando!",
		No_ground = "¡Salta primero!",
		No_flying = "Aterriza: ¡no hay ataque teledirigido volando!",
		No_shielded = "¡ESCUDO! ¡Espera a que RECARGUE!",
		HintHoldKeys = "MANTÉN F / CLIC",
		HintHoldKeysSpace = "MANTÉN ESPACIO / F",
		HintHoldPad = "MANTÉN X",
		HintHoldTouch = "¡MANTÉN!",
		Charge = "CARGA",
		ChargeMax = "¡MÁX!",
		Shielded = "ESCUDO ACTIVO",
		Vulnerable = "¡ATACA AHORA!",
		Reloading = "¡RECARGANDO!",
		Rings = "+%d ANILLOS",
		Ring = "+1 ANILLO",
		Invite = "¡El Dr. Eggman está atacando! ¿Te unes al evento?",
		InviteYes = "SÍ",
		InviteNo = "NO",
	},
	pt = {
		Homing = "ATAQUE\nTELEGUIADO",
		BossName = "DR. EGGMAN",
		BossShip = "EGG MOBILE",
		Wins = "Vitórias",
		Speed = "Velocidade",
		Jump = "PULE!",
		HintKeys = "F / CLIQUE",
		HintKeysSpace = "ESPAÇO / F",
		HintPad = "X",
		HintTouch = "TOQUE!",
		Cap = "Limite de golpes deste evento!",
		Intro = "O DR. EGGMAN ESTÁ ATACANDO!",
		Cinematic = "O DR. EGGMAN ESTÁ ATACANDO!",
		Bombard = "DESVIE DAS BOMBAS!",
		Emeralds = "AS ESMERALDAS DO CAOS!",
		Battle = "ATAQUE TELEGUIADO NO EGG MOBILE!",
		Defeat = "EGGMAN DERROTADO!",
		Escape = "EGGMAN FUGIU...",
		ChatStart = "O Dr. Eggman está atacando o lobby! Desvie das bombas, pegue as Esmeraldas do Caos e vire Super!",
		ChatDefeat = "O Dr. Eggman foi derrotado! Cada golpe deu +600 Vitórias e +30,000 Velocidade. Pegue os anéis de ouro!",
		ChatEscape = "O Dr. Eggman fugiu... ele vai voltar!",
		No_range = "Muito longe! Chegue mais perto",
		No_cooldown = "Espere um momento...",
		No_notSuper = "Só o Super Sonic pode fazer isso!",
		No_racing = "Não durante uma corrida!",
		No_busy = "Você já está atacando!",
		No_ground = "Pule primeiro!",
		No_flying = "Pouse: sem ataque teleguiado voando!",
		No_shielded = "ESCUDO! Espere ele RECARREGAR!",
		HintHoldKeys = "SEGURE F / CLIQUE",
		HintHoldKeysSpace = "SEGURE ESPAÇO / F",
		HintHoldPad = "SEGURE X",
		HintHoldTouch = "SEGURE!",
		Charge = "CARGA",
		ChargeMax = "MÁX!",
		Shielded = "ESCUDO ATIVO",
		Vulnerable = "ATAQUE AGORA!",
		Reloading = "RECARREGANDO!",
		Rings = "+%d ANÉIS",
		Ring = "+1 ANEL",
		Invite = "O Dr. Eggman está atacando! Entrar no evento?",
		InviteYes = "SIM",
		InviteNo = "NÃO",
	},
}

function Fx.Word(lang: string?, key: string): string
	local words = Fx.Text[lang or "en"] or Fx.Text.en
	return words[key] or Fx.Text.en[key] or key
end

-- 1234567 -> "1,234,567"
function Fx.FormatNumber(value: any): string
	local n = math.floor(math.abs(tonumber(value) or 0) + 0.5)
	local text = tostring(n)
	local out = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	return (if (tonumber(value) or 0) < 0 then "-" else "") .. out
end

-- "+1,000 Wins  +50,000 Speed" ("+25 Wins" when there is no Speed: a ring).
function Fx.RewardText(lang: string?, wins: any, speed: any): string
	if (tonumber(speed) or 0) == 0 then
		return ("+%s %s"):format(Fx.FormatNumber(wins), Fx.Word(lang, "Wins"))
	end
	return ("+%s %s  +%s %s"):format(Fx.FormatNumber(wins), Fx.Word(lang, "Wins"), Fx.FormatNumber(speed), Fx.Word(lang, "Speed"))
end

-- "34 / 60" and the fill (0..1).
function Fx.HpText(hp: any, maxHp: any): (string, number)
	local m = math.max(1, math.floor(tonumber(maxHp) or 1))
	local h = math.clamp(math.floor(tonumber(hp) or 0), 0, m)
	return ("%d / %d"):format(h, m), h / m
end

-- The short line for a refused homing attack ("" when nothing needs saying).
function Fx.RefusalWord(lang: string?, reason: any): string
	if type(reason) ~= "string" then
		return ""
	end
	if reason == SSE.HomingRefusals.Cap then
		return Fx.Word(lang, "Cap")
	end
	local key = "No_" .. reason
	if Fx.Text.en[key] == nil then
		return ""
	end
	return Fx.Word(lang, key)
end

-- The chat's system line, wrapped in the event's colour (SSE.Announcements.ChatColor).
function Fx.ChatLine(lang: string?, key: string): string
	local text = Fx.Word(lang, key)
	text = text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
	return ('<font color="%s">%s</font>'):format(SSE.Announcements.ChatColor or "#FFD23C", text)
end

-- The banner word of a phase ("" for none).
function Fx.PhaseWord(lang: string?, phase: string): string
	if phase == "" or phase == nil then
		return ""
	end
	return Fx.Word(lang, phase)
end

return Fx
