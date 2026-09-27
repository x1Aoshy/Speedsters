-- StarterPlayer/StarterPlayerScripts/Gameplay/SuperSonicEventClient.client.luau — the "Super Sonic vs
-- Dr. Eggman" live event as every client sees it (2026-09-26, owner). The server
-- (Gameplay/SuperSonicEventService + SuperSonicEventCore) owns every number that matters; this script
-- draws it all from the Workspace attributes SSE_*, the player attributes SSE_Super / SSE_Hits and the
-- SuperSonicEvent remote (Shared/SuperSonicEvent: the protocol and the maths), on the server clock.
-- Tunables and pure helpers: Shared/SuperSonicEventFx; the Super form's look: Shared/SuperSonicLook.
--   * The boss: a local clone of the lobby's Dr. Eggman in his Egg Mobile (Workspace.LobbyCharacters.Eggman,
--     tag LobbyNpcEggman), x2.2, on the contract's path (SSE.BossCFrame with the plan: the lift-off from his
--     lobby spot, the fight, the flight away), his R6 pose Shared/LobbyNpcPose "EggmanDriving" with taunts
--     and gestures, the fan turning, the plasma cone and the exhaust flame pulsing (Beams, no texture).
--     2026-09-26 (owner): no Highlight and no PointLight on it. The lobby NPC is hidden on this client while
--     the event runs. The Cannon mesh (SuperSonicEventAssets.Meshes) under the hull, or a part barrel until
--     it is imported. The HP bar at the top of the screen (en / es / pt). "Hit": a red flash, a flinch and
--     a recoil; "Defeat": chain explosions (BombExplode), CameraPunch, the fanfare, and he flies off smoking
--     ("Escape": laughing), fading into the horizon.
--   * Bombs ("Bomb"): the bomb mesh (or a ball) out of the barrel and along SSE.BombArc to its target over
--     its flight, nose first, over its red warning zone; at the impact (predicted on the server clock, or
--     "BombHit"): BombExplode + EggImpact emitters, a FireTrail patch burning 5 s, CameraPunch scaled by
--     distance. "Knock": the server's ragdoll throw is applied to the local character (the client owns its
--     physics).
--   * Emeralds: the 7 Chaos Emeralds fall from the sky with PointLights in their colours, orbit the
--     player's torso (SSE.EmeraldOrbit), converge into the chest on a Bezier and burst (BurstHatch) with
--     a golden flash and a chime; other players' too, cheaper (Fx.Tiers).
--   * Super Sonic (SSE_Super, any player, all clients): Shared/SuperSonicLook. Auras and trails are never
--     touched.
--   * The homing attack (Battle): a lock-on reticle on the ship within 180 studs; F, Left Click, Space in
--     the air (only without the Flight ability equipped: with it, Space held in the air lifts off, so Space
--     stays the flight's), gamepad X, or the round touch button that shows while locked on
--     (Fx.HomingButtonRect: never on the jump button or the thumbstick), all HELD to charge. The local
--     flight is kinematic: the R6 hidden (LocalTransparencyModifier), the SpinBall mesh (or a gold ball)
--     spinning with wind rings and the speed-trail Beam, the root moved along SSE.HomingPath at 180 studs/s
--     every frame to the intercept (PlatformStand, InstantMovementController stands aside), then "hit!",
--     CameraPunch, the bounce (SSE.HomingBounce) and the body back. Other players' flights come from
--     "HomingGo" (a cheaper ball) and their hits from "Hit".
--   * The chat's start / defeat / escape lines, posted by each client in its player's language
--     (TextChannel:DisplaySystemMessage only works on a client), once per event.
--   * Tiers (Shared/RaceFeelTier), pools for every repeated piece, nothing built per frame; the kill
--     switch (Workspace.U4Off_SuperSonicEvent) takes it all away live; phase "" and a respawn clean up
--     (Eggman still flying away when an escape ends the event finishes his flight alone).
-- 2026-09-26 (owner, v2 after testing v1):
--   * CINEMATICS (Shared/SuperSonicCinematic): the opening (the camera on Eggman lifting off from his lobby
--     spot, the shake, his line, him framed over the lobby, the camera handed back), the Chaos Emeralds'
--     orbit round the local player, the defeat / escape ("I'll be back!"). Letterbox bars (CinematicFit),
--     the interface away (Shared/InterfaceHider), the controls off; the camera's type and subject, the
--     controls and the interface ALWAYS come back (the end, an error, a respawn, the event ending, the kill
--     switch, a watchdog); a player who joins mid-event gets no cinematic.
--   * His DIALOGUE box (Shared/SuperSonicDialogue): his portrait (a ViewportFrame of his head), typewriter
--     text in en / es / pt, his voice clips; bottom centre on computers, a compact box under the boss bar
--     on phones, inside the notch insets.
--   * The CHARGED homing attack: hold, the charge sound and ring, the ball spinning up round the player with
--     wind and speed lines; the release launches it ({ Charge } then { Homing, t, charge01 }); the bigger the
--     charge, the bigger the impact, his recoil and the bounce.
--   * Eggman's gestures (Fx.ApplyGesture: pointing, firing, flinching, panicking at the levers, the defeat),
--     his cannon deploying / retracting / kicking with a white muzzle flash, his shield while he attacks
--     and the "!" while he reloads (vulnerable), the HP bar lit then.
--   * Bombs that leave the barrel, fly with a smoke / fire trail and a whistle, over a red warning zone of
--     the exact blast radius with an alarm; explosions, fire patches and the boss fade out smoothly.
--   * The chaos: the fiery sky (Admin/AdminAbuseEffects' blendLighting layer) and grade, smoke columns and
--     fires round the lobby, embers; the golden vignette while Super; the emeralds' coloured glow and
--     trails; the ring rain at the defeat; the lobby's Eggman fading back in at the end.
-- 2026-09-26 (owner, v3 after the next playtest; the contract is SuperSonicEvent v3):
--   * The "burn" line: a short one-shot now and then near a burning patch (Fx.Burn), never a loop.
--   * The chaos sky toned right down: a subtle warm haze (Fx.Chaos.Strength), a light grade, lighter smoke.
--   * The game's HUD slides away during the event, as when a menu is open (HudHide: MenuEvents.SetHUDVisible);
--     the topbar stays; the event shows only its own small UI: the boss bar (the game's HUD style), the
--     reticle, the touch homing button, the dialogue, the reward / ring popups. No banners, no notices, no
--     hints: a tiny "ATTACK NOW!" under the bar in a Reload window, "(A)" / "(X)" on the reticle on a gamepad.
--   * "hit!" exactly when a homing attack connects as a DAMAGING hit (the server's acceptance, not shielded),
--     never on a bounce or a refusal; FAST like the Sonic games: the contract's quicker dash, a hit-stop, a
--     white flash and a shake, the snappy bounce; off his SHIELD: the zap, his taunt and a real knock-back.
--   * Jump, then press jump again in the air (Space / gamepad A / the touch jump button) while locked on: the
--     instant, uncharged homing attack; F / Left Click / gamepad X / the touch button HELD: the charged one.
--   * The dialogue: plain typewriter text beside a small round portrait (no box, no name tab).
--   * ONE big trail Beam wrapping round the spin ball (Fx.Trail), no swirl of small lines.
--   * The contract's freeze windows (intro, emeralds' shot, outro): the local player stands still inside the
--     event's area (Freeze: the root anchored locally, the controls off, exactly back after).
--   * The invite: an optional small card for a player outside the area ({ "Invite" } -> YES sends
--     { "TeleportToEvent", eventId }), gamepad-selectable, closed when the event moves on or the player arrives.
--   * Smoother cinematics (Shared/SuperSonicCinematic v3: eased spline keys, gentle FOV, kept clear of walls).
--   * The crash at the Defeat (the contract's crash path: smoke and flames, blasts on the way down, the impact's
--     chain and punch, the rings bursting out of the crash point at their time, the wreck fading), no dialogue.
--   * The fight on the race map (SSE_Origin the arena point, SSE_LobbyOrigin the lobby): the race-only pieces
--     hidden locally and back exactly (ArenaHide); the Intro in the lobby; the Teleport / Return beats (Beat: the
--     fade held until the root has arrived, the map streamed in first, Eggman's entry on camera, the lobby
--     Eggman back at his spot); the event's area is SSE.InEventArea (the HUD hold, the music, the dialogue, the
--     invite), the haze zone the arena itself (Fx.ChaosZoneAttribute, read by Admin/AdminAbuseEffects too).
-- 2026-09-26: every top-level section runs as an immediately-called function, not a `do` block. Studio compiles
-- scripts without optimisation, where one function may hold at most 200 locals: the chunk's 185 plus a section's
-- own went past it (line 5402, "Out of local registers") and the whole client failed to load. A function gets
-- its own 200; the chunk's locals become upvalues. Behaviour is unchanged (no section returns or uses `...`).
local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local SSE = require(Shared:WaitForChild("SuperSonicEvent"))
local Fx = require(Shared:WaitForChild("SuperSonicEventFx"))
local Look = require(Shared:WaitForChild("SuperSonicLook"))
local Dialogue = require(Shared:WaitForChild("SuperSonicDialogue"))
local Cine = require(Shared:WaitForChild("SuperSonicCinematic"))
local CinematicFit = require(Shared:WaitForChild("CinematicFit"))
local InterfaceHider = require(Shared:WaitForChild("InterfaceHider"))
local CameraPunch = require(Shared:WaitForChild("CameraPunch"))
local RaceFeelTier = require(Shared:WaitForChild("RaceFeelTier"))
local HudErgonomics = require(Shared:WaitForChild("HudErgonomics"))
local EggMobile = require(Shared:WaitForChild("EggMobile"))
local LobbyNpcConfig = require(Shared:WaitForChild("LobbyNpcConfig"))
local LobbyNpcPose = require(Shared:WaitForChild("LobbyNpcPose"))
local LobbyNpcRig = require(Shared:WaitForChild("LobbyNpcRig"))
local TutorialText = require(Shared:WaitForChild("TutorialText"))
local Config = require(Shared:WaitForChild("Config"))
local MenuEvents = nil
pcall(function()
	MenuEvents = require(Shared:WaitForChild("MenuEvents", 10))
end)
-- 2026-09-26 (owner, v3): whether the event keeps the Flight ability off (EventFlightBlocked): then a jump press
-- in the air is always the homing attack's.
local RaceNoFlight = nil
pcall(function()
	RaceNoFlight = require(Shared:WaitForChild("RaceNoFlight", 10))
end)

local ATTR, PATTR, MSG, PHASE = SSE.Attributes, SSE.PlayerAttributes, SSE.Messages, SSE.Phases
local TAU = math.pi * 2
local lang = TutorialText.ForPlayer(player)
local ENV = {
	Instance = Instance, Vector3 = Vector3, CFrame = CFrame, Color3 = Color3, Enum = Enum,
	NumberRange = NumberRange, NumberSequence = NumberSequence, NumberSequenceKeypoint = NumberSequenceKeypoint,
	ColorSequence = ColorSequence, ColorSequenceKeypoint = ColorSequenceKeypoint, Vector2 = Vector2,
}
local function rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end
local GOLD, RUBY = rgb(Fx.Gold), rgb(Fx.Ruby)
local PLASMA, PLASMA_HOT = rgb(EggMobile.Colors.Plasma), rgb(EggMobile.Colors.PlasmaHot)
local FLASH_RED = rgb(Fx.Boss.FlashColor)
local EMERALD_COLORS = {}
for index, values in SSE.Emeralds.Colors do
	EMERALD_COLORS[index] = rgb(values)
end
-- Movement/InstantMovementController stands aside while the character carries it (the Sonic Burst's
-- throw sets it too): the homing flight drives the root itself.
local DASH_ATTRIBUTE = "SonicBurstDashLocal"
-- Economy/SkinSystem's player attribute: the temporary skin's id while it is on (the contract: the live truth).
local SKIN_OVERRIDE = "SkinOverride"
-- Where idle pooled pieces wait: far over every lobby (never under Workspace.FallenPartsDestroyHeight).
local FAR_AWAY = CFrame.new(0, 60000, 0)

local function serverNow(): number
	return Workspace:GetServerTimeNow()
end
local function killed(): boolean
	return not SSE.IsOn()
end
local function soundsOn(): boolean
	return player:GetAttribute("SoundEffects") ~= false and player:GetAttribute("Muted") ~= true
end

----------------------------------------------------------------------
-- Tier (Shared/RaceFeelTier: phones under 30 FPS are Low)
----------------------------------------------------------------------
local meter = RaceFeelTier.NewMeter()
local tier = RaceFeelTier.Detect(nil)
local budget = Fx.Budget(tier)
local tierClock = 0

----------------------------------------------------------------------
-- State
----------------------------------------------------------------------
local state = {
	active = false,
	phase = "",
	phaseStart = 0,
	eventId = nil :: any,
	origin = Vector3.new(0, 50, 0),
	-- 2026-09-26 (owner, v2): what this client has seen of the event (a player who joins mid-event gets no
	-- cinematic): the first phase it saw and how far into it, the phases it has watched from their start.
	firstPhase = "",
	firstPhaseAge = 0,
	watched = {} :: { [string]: boolean },
	bossState = "" :: string, -- "Attack" / "Reload" in the Battle (SSE.BossState on the server clock)
	bossStateStart = 0, -- server time the window began
	bossWindow = 0, -- how many windows of that state so far (the taunts' rhythm)
	plan = nil :: any, -- the boss path's plan (SSE.PlanFromAttributes), refreshed when the attributes change
	seed = 0,
	chaos = 0, -- the chaos weight (Fx.ChaosStep), the grade's and the ambience's
	-- 2026-09-26 (owner, v3): the fight moved to the race map. SSE_Origin is the arena point on the track,
	-- SSE_LobbyOrigin the world's lobby spawn (nil: a place without the race arena, the lobby is the origin).
	lobbyOrigin = nil :: Vector3?,
	-- The local root in the event (SSE.InEventArea: the lobby until the Teleport beat's move, the arena) and in
	-- the race map's corridor itself (SSE.InArena: the chaos zone), with the contract's hysteresis (the enter
	-- test to come in, the looser exit test to stay); refreshed every frame while an event runs.
	inEvent = false,
	inArena = false,
	returnPos = nil :: Vector3?, -- where the root was when the Return beat began (its freeze window's area)
}

-- 2026-09-26 (owner, v3): the event's area at this moment (the lobby before the Teleport beat's move, then the
-- arena) and the race map's corridor (the lobby itself in a place without the arena).
local function eventArea(pos: Vector3, exitTest: boolean?): boolean
	local moved = SSE.Moved(state.phase, Workspace:GetServerTimeNow() - state.phaseStart)
	return SSE.InEventArea(pos, state.origin, state.lobbyOrigin, moved, exitTest)
end
local function arenaZone(pos: Vector3, exitTest: boolean?): boolean
	local lobby = state.lobbyOrigin
	if lobby == nil or (lobby - state.origin).Magnitude < 1 then
		return SSE.InLobby(pos, state.origin, exitTest)
	end
	return SSE.InArena(pos, state.origin, exitTest)
end
-- A separate race arena (the fight is not in the lobby).
local function arenaMode(): boolean
	local lobby = state.lobbyOrigin
	return lobby ~= nil and (lobby - state.origin).Magnitude >= 1
end

local function refreshArena(): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return state.inEvent
	end
	state.inEvent = eventArea(root.Position, state.inEvent)
	state.inArena = arenaZone(root.Position, state.inArena)
	return state.inEvent
end

-- 2026-09-26 (owner, v2): the ship's path is the contract's plan (the lift-off from his lobby spot, the fight's
-- strafes / dives / reload hover, the flight away after the defeat or the escape): read from the Workspace
-- attributes when they change, never per frame.
local function refreshPlan()
	state.plan = SSE.PlanFromAttributes(function(name: string): any
		return Workspace:GetAttribute(name)
	end)
	state.seed = tonumber(Workspace:GetAttribute(ATTR.Seed)) or 0
end

-- The ship's frame / centre at server time t on the current plan.
local function planFrame(t: number): CFrame
	return SSE.BossCFrame(state.origin, t, state.plan)
end
local function planPosition(t: number): Vector3
	return SSE.BossPosition(state.origin, t, state.plan)
end

local function isEndPhase(phase: string): boolean
	return SSE.EndPhases[phase] == true
end
local runtime: Folder? = nil
local steppedConnection: RBXScriptConnection? = nil
local renderConnection: RBXScriptConnection? = nil
local remote: RemoteEvent? = nil

local function runtimeFolder(): Folder
	if runtime and runtime.Parent then
		return runtime
	end
	local folder = Instance.new("Folder")
	folder.Name = Fx.FolderName
	folder.Parent = Workspace
	runtime = folder
	return folder
end

local function readOrigin(): Vector3
	local value = Workspace:GetAttribute(ATTR.Origin)
	if typeof(value) == "Vector3" then
		return value
	end
	return SSE.WorldOrigin(nil, Config)
end

local function localCharacter(): (Model?, Humanoid?, BasePart?)
	local character = player.Character
	if not character then
		return nil, nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not (humanoid and root and root:IsA("BasePart")) then
		return character, nil, nil
	end
	return character, humanoid, root
end

local function cameraPosition(): Vector3
	local camera = Workspace.CurrentCamera
	return if camera then camera.CFrame.Position else state.origin
end

----------------------------------------------------------------------
-- Parts and emitters
----------------------------------------------------------------------
local function quietPart(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Massless = true
end

local function newPart(name: string, size: Vector3, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
	local part = Instance.new("Part")
	part.Name = name
	if shape then
		part.Shape = shape
	end
	part.Size = size
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	quietPart(part)
	return part
end

-- A Weld holding `part` where it is now relative to `root` (explicit C0: survives any re-parenting).
local function holdTo(root: BasePart, part: BasePart)
	local weld = Instance.new("Weld")
	weld.Name = "SSE_Hold"
	weld.Part0 = root
	weld.Part1 = part
	weld.C0 = root.CFrame:Inverse() * part.CFrame
	weld.C1 = CFrame.new()
	weld.Parent = part
end

-- The one place this script makes a ParticleEmitter: always with one of the owner's textures
-- (Fx.Textures), never Roblox's default sparkles.
local function newEmitter(key: string): ParticleEmitter
	local texture = Fx.Textures[key]
	assert(Fx.AllowedTexture(texture), "SuperSonicEventClient: no texture " .. tostring(key))
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "SSE_" .. key
	emitter.Texture = texture
	local flip = Fx.Flipbooks[key]
	if flip then
		pcall(function()
			emitter.FlipbookLayout = Enum.ParticleFlipbookLayout[flip.Layout]
			emitter.FlipbookMode = Enum.ParticleFlipbookMode[flip.Mode]
			emitter.FlipbookFramerate = NumberRange.new(flip.Fps)
		end)
	end
	emitter.LightInfluence = 0
	emitter.Enabled = false
	return emitter
end

local function sequence(points: { { number } }): NumberSequence
	local keys = {}
	for _, p in points do
		table.insert(keys, NumberSequenceKeypoint.new(p[1], p[2]))
	end
	return NumberSequence.new(keys)
end

----------------------------------------------------------------------
-- Assets (ReplicatedStorage.SuperSonicEventAssets: VFX from the build, Meshes once the owner imports
-- the Blender kit; everything falls back to parts without them)
----------------------------------------------------------------------
local vfxTemplate, meshTemplate, partsOf, fitClone
;(function() -- (a function, not a do-block: see the note at the top)
	local function assetsFolder(kind: string): Instance?
		local assets = ReplicatedStorage:FindFirstChild(SSE.AssetsFolder)
		return assets and assets:FindFirstChild(kind)
	end
	function vfxTemplate(name: string): Instance?
		local folder = assetsFolder("VFX")
		return folder and folder:FindFirstChild(name)
	end
	function meshTemplate(name: string): Instance?
		local folder = assetsFolder("Meshes")
		local template = folder and folder:FindFirstChild(name)
		if template and (template:IsA("Model") or template:IsA("BasePart")) then
			return template
		end
		return nil
	end

	function partsOf(instance: Instance): { BasePart }
		local out = {}
		if instance:IsA("BasePart") then
			table.insert(out, instance)
		end
		for _, d in instance:GetDescendants() do
			if d:IsA("BasePart") then
				table.insert(out, d)
			end
		end
		return out
	end

	-- A clone of a mesh template scaled uniformly so its largest side (fit "Largest") or its height (fit
	-- "Height") is `extent` studs (nil: its own size), every part quiet and held to one anchored root.
	-- Returns (root, the clone, rootOffset: root.CFrame = pivot * rootOffset).
	function fitClone(template: Instance, extent: number?, fit: string?): (BasePart?, Instance?, CFrame)
		local clone = template:Clone()
		for _, d in clone:GetDescendants() do
			if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Sound") or d:IsA("Highlight") then
				d:Destroy()
			end
		end
		local parts = partsOf(clone)
		if #parts == 0 then
			clone:Destroy()
			return nil, nil, CFrame.new()
		end
		local root: BasePart
		if clone:IsA("Model") then
			local primary = clone.PrimaryPart
			root = if primary then primary else parts[1]
			local size = clone:GetExtentsSize()
			local measure = if fit == "Height" then size.Y else math.max(size.X, size.Y, size.Z)
			if extent and measure > 1e-3 then
				pcall(function()
					clone:ScaleTo(clone:GetScale() * extent / measure)
				end)
			end
		else
			root = clone :: BasePart
			local size = root.Size
			local measure = if fit == "Height" then size.Y else math.max(size.X, size.Y, size.Z)
			if extent and measure > 1e-3 then
				root.Size = size * (extent / measure)
			end
		end
		for _, part in parts do
			quietPart(part)
			part.CastShadow = part == root
		end
		for _, part in parts do
			if part ~= root then
				part.Anchored = false
				holdTo(root, part)
			end
		end
		local offset = CFrame.new()
		if clone:IsA("Model") then
			offset = clone:GetPivot():Inverse() * root.CFrame
		end
		return root, clone, offset
	end
end)()

----------------------------------------------------------------------
-- Sounds (2D, attenuated by hand: a few Sounds per kind, reused)
----------------------------------------------------------------------
local prewarmSounds, destroySounds, playSound, distanceFromCamera, stopSound, soundLength
;(function() -- (a function, not a do-block: see the note at the top)
	local soundRings: { [string]: { Sound } } = {}
	local lastSoundAt: { [string]: number } = {}

	-- Every Sound the event plays, made when it starts (playSound only picks one). They live in SoundService:
	-- Audio/SfxAudioController routes them into the SFX group (the Settings toggle and volume slider).
	function prewarmSounds()
		for kind, spec in Fx.Sounds do
			if spec.Rings then
				continue -- (the rings' own: they outlive the event)
			end
			local ring = soundRings[kind]
			if not ring then
				ring = {}
				soundRings[kind] = ring
			end
			while #ring < (Fx.SoundVoices[kind] or 1) do
				local made = Instance.new("Sound")
				made.Name = "SSE_" .. kind
				made.SoundId = spec.Id
				made.Looped = spec.Loop == true
				made.Parent = SoundService
				table.insert(ring, made)
			end
		end
	end

	function destroySounds()
		for _, ring in soundRings do
			for _, sound in ring do
				sound:Destroy()
			end
		end
		table.clear(soundRings)
	end

	-- Plays `kind` (attenuated by `distance` from the camera when given, at `speed` x its own pitch when
	-- given); returns the Sound (nil when silent).
	function playSound(kind: string, distance: number?, speed: number?): Sound?
		if not soundsOn() then
			return nil
		end
		local spec = Fx.Sounds[kind]
		if not spec then
			return nil
		end
		local volume = if distance then Fx.Attenuate(spec.Volume, distance) else spec.Volume
		if volume <= 0.02 then
			return nil
		end
		local now = os.clock()
		if now - (lastSoundAt[kind] or -1) < 0.07 then
			return nil -- a salvo's bombs landing together: one blast is enough
		end
		lastSoundAt[kind] = now
		local ring = soundRings[kind]
		if not ring or #ring == 0 then
			return nil -- (made by prewarmSounds when the event starts)
		end
		local sound: Sound = ring[1]
		for _, candidate in ring do
			if not candidate.IsPlaying then
				sound = candidate
				break
			end
		end
		local s = sound
		s.Volume = volume
		s.PlaybackSpeed = (spec.Speed or 1) * (speed or 1)
		s.TimePosition = 0
		s:Play()
		return s
	end

	function stopSound(kind: string)
		local ring = soundRings[kind]
		for _, sound in ring or {} do
			if sound.IsPlaying then
				sound:Stop()
			end
		end
	end

	-- A sound's length once it has loaded (0 before).
	function soundLength(kind: string): number
		local ring = soundRings[kind]
		local sound = ring and ring[1]
		local ok, length = pcall(function()
			return (sound :: Sound).TimeLength
		end)
		return if ok and type(length) == "number" then length else 0
	end

	function distanceFromCamera(position: Vector3): number
		return (position - cameraPosition()).Magnitude
	end
end)()

----------------------------------------------------------------------
-- VFX rigs: an invisible anchored host with clones of the imported emitters (Fx.EmitterSets), reused.
-- They are built by prewarmRigs, from the message / input / phase handlers; fireRig (which the frame
-- loop may call) only ever takes one that exists.
----------------------------------------------------------------------
local prewarmRigs, fireRig, destroyRigs
;(function() -- (a function, not a do-block: see the note at the top)
	type RigEmitter = { emitter: ParticleEmitter, count: number, delay: number }
	type Rig = { part: BasePart, list: { RigEmitter }, set: string, busyUntil: number }
	-- 2026-09-26 (owner, v2): Muzzle, the cannon's WHITE flash on every shot (tinted white, sized for the
	-- muzzle); the rigs are never moved while their particles live (the imported ones are partly LockedToPart:
	-- a rig reused mid-burst would drag its particles), so the pools are prewarmed for what is in the air.
	local RIG_KINDS = {
		Blast = { vfx = { SSE.VfxNames.BombExplode, SSE.VfxNames.EggImpact }, life = 3.2 },
		Burst = { vfx = { SSE.VfxNames.BurstHatch }, life = 2.8 },
		Hit = { vfx = { SSE.VfxNames.BurstHatch }, life = 1.4 },
		Muzzle = { vfx = { SSE.VfxNames.BurstHatch, SSE.VfxNames.BombExplode }, life = 1.6,
			tint = rgb(Fx.Muzzle.Color), sizeScale = Fx.Muzzle.SizeScale },
	}
	local rigPools: { [string]: { Rig } } = { Blast = {}, Burst = {}, Hit = {}, Muzzle = {} }

	local function rigSet(kind: string): string
		if kind == "Hit" then
			return "Hit"
		elseif kind == "Muzzle" then
			return "Muzzle" .. tostring(budget.Muzzle)
		end
		return budget.BlastSet
	end

	local function scaledSize(size: NumberSequence, k: number): NumberSequence
		local keys = {}
		for _, key in size.Keypoints do
			table.insert(keys, NumberSequenceKeypoint.new(key.Time, key.Value * k, key.Envelope * k))
		end
		return NumberSequence.new(keys)
	end

	local function buildRig(kind: string, set: string): Rig?
		local spec = RIG_KINDS[kind]
		local part = newPart("SSE_" .. kind, Vector3.new(1, 1, 1), GOLD, Enum.Material.SmoothPlastic)
		part.Transparency = 1
		local attachment = Instance.new("Attachment")
		attachment.Name = "SSE_Emit"
		attachment.Parent = part
		local scale = if kind == "Hit" then budget.EmitScale * 0.6 elseif kind == "Muzzle" then 1 else budget.EmitScale
		local list = {}
		for _, vfx in spec.vfx do
			local template = vfxTemplate(vfx)
			if template then
				for _, d in template:GetDescendants() do
					if d:IsA("ParticleEmitter") and Fx.EmitterAllowed(vfx, d.Name, set) then
						local clone = d:Clone()
						clone.Enabled = false
						if spec.tint then
							-- (the muzzle's WHITE flash; the ring's sparkle)
							clone.Color = ColorSequence.new(spec.tint)
							clone.LightEmission = 1
							pcall(function()
								clone.Size = scaledSize(clone.Size, spec.sizeScale or 1)
							end)
						end
						clone.Parent = attachment
						table.insert(list, {
							emitter = clone,
							count = Fx.EmitCount(d:GetAttribute("SabEmit"), d:GetAttribute("EmitCount"), scale),
							delay = math.max(0, tonumber(d:GetAttribute("EmitDelay")) or 0),
						})
					end
				end
			end
		end
		if #list == 0 then
			part:Destroy()
			return nil
		end
		part.CFrame = FAR_AWAY
		part.Parent = runtimeFolder()
		return { part = part, list = list, set = set, busyUntil = 0 }
	end

	local function capOf(kind: string): number
		return if kind == "Blast" then budget.BlastPool else math.max(2, math.floor(budget.BlastPool / 2))
	end

	-- An idle rig of the current set, else the busy one closest to done (it fires again); never builds.
	local function acquireRig(kind: string): Rig?
		local pool = rigPools[kind]
		local set = rigSet(kind)
		local now = os.clock()
		local oldest: Rig? = nil
		for index = #pool, 1, -1 do
			local rig = pool[index]
			if rig.set ~= set and rig.busyUntil <= now then
				-- A tier change: an idle rig of the old set goes.
				rig.part:Destroy()
				table.remove(pool, index)
			elseif rig.set == set then
				if rig.busyUntil <= now then
					return rig
				end
				if not oldest or rig.busyUntil < oldest.busyUntil then
					oldest = rig
				end
			end
		end
		return oldest
	end

	-- At least `count` rigs of `kind` in the current set (within the tier's pool cap).
	function prewarmRigs(kind: string, count: number)
		local pool = rigPools[kind]
		local set = rigSet(kind)
		local have = 0
		for _, rig in pool do
			if rig.set == set then
				have += 1
			end
		end
		local want = math.min(count, capOf(kind))
		while have < want and #pool < capOf(kind) + 2 do
			local rig = buildRig(kind, set)
			if not rig then
				return -- no VFX asset in this place
			end
			table.insert(pool, rig)
			have += 1
		end
	end

	-- `countScale`: more particles for a bigger hit (the charged homing attack).
	function fireRig(kind: string, cframe: CFrame, countScale: number?): boolean
		local rig = acquireRig(kind)
		if not rig then
			return false
		end
		rig.part.CFrame = cframe
		rig.busyUntil = os.clock() + RIG_KINDS[kind].life
		local k = countScale or 1
		for _, entry in rig.list do
			local count = math.max(1, math.floor(entry.count * k + 0.5))
			if entry.delay > 0 then
				local emitter = entry.emitter
				task.delay(entry.delay, function()
					if emitter.Parent then
						emitter:Emit(count)
					end
				end)
			else
				entry.emitter:Emit(count)
			end
		end
		return true
	end

	function destroyRigs()
		for _, pool in rigPools do
			for _, rig in pool do
				rig.part:Destroy()
			end
			table.clear(pool)
		end
	end
end)()

----------------------------------------------------------------------
-- Fire patches (FireTrail) where a bomb landed, burning SSE.Bombard.FirePatchSeconds
----------------------------------------------------------------------
-- 2026-09-26 (owner, v2): a patch FADES out at the end of its 5 s (its flames' rate, transparency and
-- brightness, its warm light) instead of popping; the same pool burns round the lobby while the chaos lasts
-- (ambient patches: until released).
-- 2026-09-26 (owner, v3): "the burn repeats far too much": no loop any more. Now and then (Fx.Burn: a random
-- gap of several seconds after each one) a SHORT burn one-shot plays at the nearest burning patch's distance
-- when one is within Fx.Burn.Range, fading out after Fx.Burn.Seconds; never two at once (updateBurn).
local FIRE_FADE = 0.9 -- seconds of the fade at a patch's end
local newLight
;(function() -- (a function, not a do-block: see the note at the top)
	-- The one place this script makes a PointLight: the emeralds' lights and the fire patches' warm glow.
	function newLight(parent: Instance, range: number, brightness: number, color: Color3): PointLight
		local light = Instance.new("PointLight")
		light.Name = "SSE_Light"
		light.Range = range
		light.Brightness = brightness
		light.Color = color
		light.Shadows = false
		light.Enabled = false
		light.Parent = parent
		return light
	end
end)()

local prewarmFires, burnAt, updateFires, destroyFires, burnAmbient, resetBurn
;(function() -- (a function, not a do-block: see the note at the top)
	type FireEmitter = { emitter: ParticleEmitter, rate: number, levels: { NumberSequence }, brightness: number }
	type Fire = { part: BasePart, emitters: { FireEmitter }, light: PointLight?, offAt: number, busyUntil: number, ambient: boolean, level: number }
	local firePool: { Fire } = {}
	local FIRE_CAP = 20
	local FADE_STEPS = 6
	local FIRE_LIGHT = Color3.fromRGB(255, 130, 40)
	-- 2026-09-26 (owner, v3): the burn one-shot now playing (one at a time), when it began, its volume, and when
	-- the next one may play (os.clock).
	local burn = { sound = nil :: Sound?, start = 0, volume = 0, nextAt = math.huge }

	-- An idle patch (never builds: prewarmFires does, from the handlers).
	local function acquireFire(): Fire?
		local now = os.clock()
		for _, fire in firePool do
			if fire.busyUntil <= now and not fire.ambient then
				return fire
			end
		end
		return nil
	end

	-- The emitter's transparency faded `k` (0..1) toward 1, precomputed (no allocation while it fades).
	local function fadeLevels(base: NumberSequence): { NumberSequence }
		local out = {}
		for step = 0, FADE_STEPS do
			local k = step / FADE_STEPS
			local keys = {}
			for _, key in base.Keypoints do
				table.insert(keys, NumberSequenceKeypoint.new(key.Time, key.Value + (1 - key.Value) * k))
			end
			out[step + 1] = NumberSequence.new(keys)
		end
		return out
	end

	function prewarmFires(count: number)
		local template = vfxTemplate(SSE.VfxNames.FireTrail)
		if not (template and template:IsA("BasePart")) then
			return
		end
		local lights = 0
		for _, fire in firePool do
			if fire.light then
				lights += 1
			end
		end
		while #firePool < math.min(count, FIRE_CAP) do
			local part = template:Clone() :: BasePart
			quietPart(part)
			part.Transparency = 1
			local emitters = {}
			for _, d in part:GetDescendants() do
				if d:IsA("ParticleEmitter") then
					d.Enabled = false
					local okB, brightness = pcall(function()
						return d.Brightness
					end)
					table.insert(emitters, { emitter = d, rate = d.Rate, levels = fadeLevels(d.Transparency), brightness = if okB then brightness else 1 })
				end
			end
			local light = nil
			if lights < budget.FireLights then
				light = newLight(part, 14, 1.6, FIRE_LIGHT)
				lights += 1
			end
			part.CFrame = FAR_AWAY
			part.Parent = runtimeFolder()
			table.insert(firePool, { part = part, emitters = emitters, light = light, offAt = 0, busyUntil = 0, ambient = false, level = 0 })
		end
	end

	local function light(fire: Fire, on: boolean)
		for _, entry in fire.emitters do
			entry.emitter.Rate = entry.rate
			entry.emitter.Transparency = entry.levels[1]
			pcall(function()
				entry.emitter.Brightness = entry.brightness
			end)
			entry.emitter.Enabled = on
		end
		if fire.light then
			fire.light.Brightness = 1.6
			fire.light.Enabled = on
		end
		fire.level = 0
	end

	function burnAt(position: Vector3, count: number)
		local seconds = SSE.Bombard.FirePatchSeconds
		for index = 1, count do
			local fire = acquireFire()
			if not fire then
				return
			end
			local angle = (index - 1) / count * TAU + math.random() * 0.8
			local radius = if count == 1 then 0 else Fx.Bomb.FirePatchRadius * (0.45 + 0.55 * math.random())
			fire.part.CFrame = CFrame.new(position.X + math.cos(angle) * radius, position.Y + 0.05, position.Z + math.sin(angle) * radius)
				* CFrame.Angles(0, angle, 0)
			light(fire, true)
			fire.offAt = os.clock() + seconds
			fire.busyUntil = fire.offAt + 0.6 -- the last flames die out
		end
	end

	-- The ambient patches round the lobby: `points` (world positions) burn until burnAmbient(nil) lets them
	-- fade out. Returns how many burn.
	function burnAmbient(points: { Vector3 }?): number
		local lit = 0
		for _, fire in firePool do
			if fire.ambient then
				if points == nil then
					fire.ambient = false
					fire.offAt = os.clock() + FIRE_FADE
					fire.busyUntil = fire.offAt + 0.6
				else
					lit += 1
				end
			end
		end
		if points == nil then
			return 0
		end
		for index = lit + 1, #points do
			local fire = acquireFire()
			if not fire then
				break
			end
			fire.ambient = true
			fire.part.CFrame = CFrame.new(points[index]) * CFrame.Angles(0, index, 0)
			light(fire, true)
			fire.offAt = math.huge
			fire.busyUntil = math.huge
			lit += 1
		end
		return lit
	end

	-- 2026-09-26 (owner, v3): the next burn waits Fx.Burn.FirstMin..FirstMax from now (a new event; the fires light).
	function resetBurn(clock: number)
		if burn.sound then
			burn.sound:Stop()
			burn.sound = nil
		end
		local b = Fx.Burn
		burn.nextAt = clock + b.FirstMin + (b.FirstMax - b.FirstMin) * math.random()
	end

	-- The short burn: fading out over its end; the next one only after its random gap, never two at once, only
	-- with a burning patch within Fx.Burn.Range of the camera.
	local function updateBurn(clock: number, nearest: number)
		local playing = burn.sound
		if playing then
			local level = Fx.BurnLevel(clock - burn.start)
			if level <= 0 then
				playing:Stop()
				burn.sound = nil
			else
				playing.Volume = burn.volume * level
			end
			return
		end
		if clock < burn.nextAt then
			return
		end
		if nearest > Fx.Burn.Range then
			burn.nextAt = clock + 1 -- (nothing burning close by: look again in a second)
			return
		end
		local sound = playSound("Burn", nearest)
		burn.nextAt = Fx.NextBurnAt(clock, math.random())
		if sound then
			burn.sound = sound
			burn.start = clock
			burn.volume = sound.Volume
		end
	end

	-- Every frame: the patches near their end fade (at most FADE_STEPS writes each); now and then a short burn at
	-- the nearest one.
	function updateFires(clock: number)
		local nearest = math.huge
		local eye = cameraPosition()
		for _, fire in firePool do
			if fire.offAt > 0 then
				if clock >= fire.offAt then
					fire.offAt = 0
					for _, entry in fire.emitters do
						entry.emitter.Enabled = false
					end
					if fire.light then
						fire.light.Enabled = false
					end
				else
					local k = if fire.offAt == math.huge then 0 else math.clamp(1 - (fire.offAt - clock) / FIRE_FADE, 0, 1)
					local level = math.floor(k * FADE_STEPS + 0.5)
					if level ~= fire.level then
						fire.level = level
						for _, entry in fire.emitters do
							entry.emitter.Rate = entry.rate * (1 - k)
							entry.emitter.Transparency = entry.levels[level + 1]
						end
						if fire.light then
							fire.light.Brightness = 1.6 * (1 - k)
						end
					end
					local d = (fire.part.Position - eye).Magnitude / math.max(1 - k, 0.05)
					if d < nearest then
						nearest = d
					end
				end
			end
		end
		updateBurn(clock, nearest)
	end

	function destroyFires()
		for _, fire in firePool do
			fire.part:Destroy()
		end
		table.clear(firePool)
		if burn.sound then
			burn.sound:Stop()
			burn.sound = nil
		end
		burn.nextAt = math.huge
	end
end)()

----------------------------------------------------------------------
-- The boss
----------------------------------------------------------------------
local boss, lobbyEggman, buildBossVfx, destroyBoss, ensureBoss, taunt, bossHit, startFlee, startDefeat, updateBoss
local detachFleeingBoss, runOutro, bossGesture, cannonShot, muzzleFrame
-- (the lobby's Eggman: its block is below; the crash brings him back during the Defeat, v3)
local restoreLobby, hideLobby
;(function() -- (a function, not a do-block: see the note at the top)
	type Joint = { name: string, motor: Motor6D, basis: CFrame, basisInv: CFrame }
	type Glow = { part: BasePart, kind: string, color: Color3 }
	boss = {
		-- 2026-09-26 (owner, v2)
		cannonWelds = {} :: { { weld: Weld, base: CFrame } }, -- the cannon's welds and their C0 at rest
		cannonMount = Vector3.zero, -- hull space (scaled): the cannon turns about its mount
		cannonMuzzle = Vector3.zero, -- hull space (scaled): the muzzle at rest
		cannonOffset = CFrame.new(), -- this frame's deploy / kick offset (hull space, about the mount)
		shotAt = -math.huge, -- the last shot (the kick and the jolt)
		shield = nil :: BasePart?,
		shieldLevel = 0, -- 0..1 shown
		alertAnchor = nil :: Attachment?,
		gesture = nil :: string?, -- a one-shot gesture (Fx.Gestures) and when it began
		gestureStart = 0,
		loop = nil :: string?, -- a looping gesture (Fx.GestureLoops: Reload / Defeat)
		loopStart = 0,
		fade = 0, -- 0..1: the model fading into the horizon
		fadeParts = {} :: { { part: Instance, value: number } },
		recoilStuds = Fx.Boss.RecoilStuds, -- this hit's recoil (SSE.BossRecoil of its charge)
		recoilDegrees = Fx.Boss.RecoilDegrees,
		model = nil :: Model?,
		root = nil :: BasePart?,
		hull = nil :: BasePart?,
		hullToRoot = CFrame.new(),
		scale = 1,
		fallback = false,
		joints = {} :: { Joint },
		fans = {} :: { { motor: Motor6D, side: number } },
		glows = {} :: { Glow },
		shipParts = {} :: { { part: BasePart, color: Color3 } },
		beams = {} :: { Beam },
		exhaust = {} :: { { beam: Beam, tip: Attachment, rest: Vector3 } },
		vfxTier = nil :: string?,
		made = {} :: { Instance },
		reticleAnchor = nil :: Attachment?,
		poseOut = LobbyNpcPose.NewOut(),
		nextPose = 0,
		reaction = nil :: string?,
		reactionStart = 0,
		nextTaunt = 0,
		tauntFlip = false,
		aim = { yaw = 0, pitch = 10 },
		flashStart = -math.huge,
		flashing = false,
		recoilStart = -math.huge,
		recoilDir = Vector3.new(0, 0, 1),
		defeat = nil :: any,
		flee = nil :: any,
		gone = false,
		smoke = nil :: ParticleEmitter?,
		fires = {} :: { ParticleEmitter }, -- (v3) the crash's flames on the hull
		lobbyBack = false, -- (v3) the crash brought the lobby Eggman back (the sweep no longer hides him)
		nextSearch = 0,
		frame = CFrame.new(),
	}

	-- The lobby's Eggman with his ship (the model LobbyNpcs adopted, or the build's LobbyCharacters one).
	function lobbyEggman(): Model?
		for _, model in CollectionService:GetTagged(LobbyNpcConfig.Tags.Eggman) do
			if model:IsA("Model") and model:IsDescendantOf(Workspace) and model:FindFirstChild(EggMobile.ModelName) then
				return model
			end
		end
		local folder = Workspace:FindFirstChild("LobbyCharacters")
		local model = folder and folder:FindFirstChild("Eggman")
		if model and model:IsA("Model") and model:FindFirstChild(EggMobile.ModelName) then
			return model
		end
		return nil
	end

	-- Hull space (ship floor space minus EggMobile.HullCenter, times the scale).
	local function hullOffset(point: { number }): CFrame
		local c = EggMobile.HullCenter
		local s = boss.scale
		return CFrame.new((point[1] - c[1]) * s, (point[2] - c[2]) * s, (point[3] - c[3]) * s)
	end

	local function bossAttachment(name: string, cf: CFrame): Attachment
		local attachment = Instance.new("Attachment")
		attachment.Name = name
		attachment.CFrame = cf
		attachment.Parent = boss.hull
		table.insert(boss.made, attachment)
		return attachment
	end

	local function bossBeam(name: string, a0: Attachment, a1: Attachment, color: Color3, w0: number, w1: number, transparency: NumberSequence): Beam
		local beam = Instance.new("Beam")
		beam.Name = name
		beam.Attachment0 = a0
		beam.Attachment1 = a1
		beam.Color = ColorSequence.new(color)
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.Transparency = transparency
		beam.Width0 = w0
		beam.Width1 = w1
		beam.FaceCamera = true
		beam.Segments = 1
		beam.Texture = "" -- a soft solid ribbon, as the lobby ship (Gameplay/EggMobileClient)
		beam.Parent = a0.Parent
		table.insert(boss.made, beam)
		return beam
	end

	-- The plasma cone and the exhaust flame for the current tier (no lights: 2026-09-26, owner).
	local function clearBossVfx()
		for _, instance in boss.made do
			instance:Destroy()
		end
		table.clear(boss.made)
		table.clear(boss.beams)
		table.clear(boss.exhaust)
		table.clear(boss.fires)
		boss.reticleAnchor = nil
		boss.alertAnchor = nil
		boss.shield = nil
		boss.vfxTier = nil
	end

	function buildBossVfx()
		if boss.vfxTier == tier or not boss.hull then
			return
		end
		clearBossVfx()
		local s = boss.scale
		boss.reticleAnchor = bossAttachment("SSE_Reticle", CFrame.new())
		-- 2026-09-26 (owner, v2): the "!" over him while he reloads, and his shield while he attacks (a
		-- ForceField bubble: a material, no texture), shown by updateBoss.
		boss.alertAnchor = bossAttachment("SSE_Alert", CFrame.new(0, Fx.Boss.AlertHeight * s / 2.2, 0))
		local shield = newPart("SSE_Shield", Vector3.new(1, 1, 1) * Fx.Boss.ShieldRadius * 2 * s / 2.2, rgb(Fx.Boss.ShieldColor), Enum.Material.ForceField, Enum.PartType.Ball)
		shield.Transparency = 1
		shield.CFrame = (boss.hull :: BasePart).CFrame
		shield.Anchored = false
		holdTo(boss.hull :: BasePart, shield)
		shield.Parent = boss.model
		table.insert(boss.made, shield)
		boss.shield = shield
		boss.shieldLevel = 0
		if not boss.fallback then
			local points = EggMobile.Points
			local topPoint = points.PlasmaTop
			local top = bossAttachment("SSE_PlasmaTop", hullOffset(topPoint))
			local bottom = bossAttachment("SSE_PlasmaEnd", hullOffset({ topPoint[1], topPoint[2] - Fx.Boss.PlasmaLength, topPoint[3] }))
			table.insert(boss.beams, bossBeam("SSE_PlasmaCone", top, bottom, PLASMA, 2.8 * s, 5.2 * s, sequence({ { 0, 0.25 }, { 0.55, 0.65 }, { 1, 1 } })))
			if budget.Beams >= 2 then
				table.insert(boss.beams, bossBeam("SSE_PlasmaCore", top, bottom, PLASMA_HOT, 1.3 * s, 2.4 * s, sequence({ { 0, 0.1 }, { 0.7, 0.75 }, { 1, 1 } })))
			end
			if budget.Exhaust then
				for index, point in points.Exhaust do
					local base = bossAttachment("SSE_Exhaust" .. index, hullOffset(point))
					local tipCf = hullOffset({ point[1], point[2], point[3] + Fx.Boss.ExhaustLength })
					local tip = bossAttachment("SSE_ExhaustTip" .. index, tipCf)
					local beam = bossBeam("SSE_ExhaustFlame", base, tip, PLASMA, 1.25 * s, 0.15 * s, sequence({ { 0, 0.1 }, { 0.6, 0.55 }, { 1, 1 } }))
					table.insert(boss.exhaust, { beam = beam, tip = tip, rest = tipCf.Position })
				end
			end
		end
		boss.vfxTier = tier
	end

	-- The Cannon under the bowl's front (the Blender kit: scaled with the ship, its pivot on the mount point, no
	-- rotation; SSE.Boss.Cannon is its spawn point, where the server's bombs start), or a part barrel from the
	-- same mount to the same muzzle until the owner imports the kit.
	-- 2026-09-26 (owner, v2): the cannon's welds are kept (updateBoss slides it out / in and kicks it by their
	-- C0, turning about the mount), with the mount and the muzzle in hull space.
	local function keepCannonWeld(part: BasePart)
		local weld = part:FindFirstChild("SSE_Hold")
		if weld and weld:IsA("Weld") then
			table.insert(boss.cannonWelds, { weld = weld, base = weld.C0 })
		end
	end

	local function mountCannon()
		local hull = boss.hull
		if not hull then
			return
		end
		local s = boss.scale
		table.clear(boss.cannonWelds)
		boss.cannonMount = Vector3.new(table.unpack(Fx.Boss.CannonMount)) * s
		boss.cannonMuzzle = Vector3.new(table.unpack(Fx.Boss.CannonMuzzle)) * s
		local template = meshTemplate(Fx.MeshNames.Cannon)
		if template and template:IsA("Model") then
			local clone = template:Clone() :: Model
			for _, d in clone:GetDescendants() do
				if d:IsA("LuaSourceContainer") or d:IsA("Sound") or d:IsA("Highlight") or d:IsA("Light") then
					d:Destroy()
				end
			end
			pcall(function()
				clone:ScaleTo(s)
			end)
			local mountHull = template:GetAttribute("MountHull")
			local mount = if typeof(mountHull) == "Vector3" then mountHull else Vector3.new(table.unpack(Fx.Boss.CannonMount))
			clone:PivotTo(hull.CFrame * CFrame.new(mount * s))
			local parts = partsOf(clone)
			local primary = clone.PrimaryPart or parts[1]
			if primary then
				for _, part in parts do
					part.Anchored = false
					part.CanCollide = false
					part.CanTouch = false
					part.CanQuery = false
					part.Massless = true
				end
				-- Every piece held to the primary (a kit whose pieces are not jointed moves as one), the primary
				-- to the hull (the one weld that moves).
				for _, part in parts do
					if part ~= primary and not part:FindFirstChildWhichIsA("JointInstance") then
						holdTo(primary, part)
					end
				end
				holdTo(hull, primary)
				keepCannonWeld(primary)
				boss.cannonMount = mount * s
				clone.Name = "SSE_Cannon"
				clone.Parent = boss.model
				return
			end
			clone:Destroy()
		end
		local mount = Vector3.new(table.unpack(Fx.Boss.CannonMount)) * s
		local muzzle = Vector3.new(table.unpack(Fx.Boss.CannonMuzzle)) * s
		local along = muzzle - mount
		local radius = Fx.Boss.CannonRadius * s
		-- A Cylinder's axis is its X: turned a quarter about Y, X runs along the frame's -Z (the barrel).
		local barrelFrame = hull.CFrame * Fx.FrameAlong((mount + muzzle) / 2, along) * CFrame.Angles(0, math.pi / 2, 0)
		local barrel = newPart("SSE_CannonBarrel", Vector3.new(along.Magnitude + radius, radius * 2, radius * 2), Color3.fromRGB(58, 60, 68), Enum.Material.Metal, Enum.PartType.Cylinder)
		barrel.CFrame = barrelFrame
		local ring = newPart("SSE_CannonMuzzle", Vector3.new(0.35 * s, radius * 2.5, radius * 2.5), Color3.fromRGB(255, 200, 30), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		ring.CFrame = hull.CFrame * Fx.FrameAlong(muzzle, along) * CFrame.Angles(0, math.pi / 2, 0)
		for _, part in { barrel, ring } do
			part.Anchored = false
			holdTo(hull, part)
			keepCannonWeld(part)
			part.Parent = boss.model
		end
	end

	-- The muzzle now (the cannon's deploy / kick offset included): a frame whose -Z runs out of the barrel.
	function muzzleFrame(): CFrame
		local hull = boss.frame
		local mount, muzzle = boss.cannonMount, boss.cannonMuzzle
		local moved = CFrame.new(mount) * boss.cannonOffset * CFrame.new(-mount)
		local from = hull * (moved * CFrame.new(mount)).Position
		local to = hull * (moved * CFrame.new(muzzle)).Position
		return Fx.FrameAlong(to, to - from)
	end

	-- A shot: the cannon kicks, the ship jolts, the white muzzle flash, Eggman jerks.
	function cannonShot()
		boss.shotAt = os.clock()
		if boss.model and not boss.gone then
			fireRig("Muzzle", muzzleFrame())
		end
		bossGesture("Fire")
	end

	local function removeTags(instance: Instance)
		for _, tag in CollectionService:GetTags(instance) do
			CollectionService:RemoveTag(instance, tag)
		end
	end

	local STRIP = {}
	for _, className in Fx.StripClasses do
		STRIP[className] = true
	end

	-- A local clone of the lobby's Eggman in his Egg Mobile, cleaned (no scripts, prompts, tags, lights,
	-- colliders, the lobby client's beams), scaled and ready to drive.
	local function buildBossFromLobby(): boolean
		local source = lobbyEggman()
		if not source then
			return false
		end
		local archivable = source.Archivable
		source.Archivable = true
		local ok, made = pcall(function()
			return source:Clone()
		end)
		source.Archivable = archivable
		if not ok or not made then
			return false
		end
		local clone = made :: Model
		removeTags(clone)
		for _, d in clone:GetDescendants() do
			removeTags(d)
		end
		for _, d in clone:GetDescendants() do
			if d.Parent == nil then
				continue
			end
			if STRIP[d.ClassName] or (d:IsA("BasePart") and d:GetAttribute("EggCollider") == true)
				or (d:IsA("Attachment") and string.sub(d.Name, 1, 3) == "Egg") then
				d:Destroy()
			end
		end
		clone:SetAttribute(LobbyNpcConfig.KindAttribute, nil)
		clone.Name = "SSE_EggmanBoss"
		local root = LobbyNpcRig.FindRoot(clone)
		local ship = clone:FindFirstChild(EggMobile.ModelName)
		local hull = ship and ship:FindFirstChild(EggMobile.HullName)
		if not (root and hull and hull:IsA("BasePart")) then
			clone:Destroy()
			return false
		end
		for _, d in clone:GetDescendants() do
			if d:IsA("BasePart") then
				d.CanCollide = false
				d.CanTouch = false
				d.CanQuery = false
				d.Anchored = d == root
				d.LocalTransparencyModifier = 0
			elseif d:IsA("Decal") then
				d.LocalTransparencyModifier = 0
			elseif d:IsA("Humanoid") then
				d.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
				d.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
				pcall(function()
					d.EvaluateStateMachine = false
					d.BreakJointsOnDeath = false
					d.RequiresNeck = false
				end)
			end
		end
		pcall(function()
			clone:ScaleTo(Fx.Boss.Scale)
		end)
		local okScale, scale = pcall(function()
			return clone:GetScale()
		end)
		boss.scale = if okScale and type(scale) == "number" and scale > 0 then scale else 1
		boss.model, boss.root, boss.hull, boss.fallback = clone, root, hull :: BasePart, false
		boss.hullToRoot = (hull :: BasePart).CFrame:Inverse() * root.CFrame
		root.CFrame = planFrame(serverNow()) * boss.hullToRoot
		clone.Parent = runtimeFolder()
		-- A piece the joints do not hold (a ship built before the server unanchors it) is welded on.
		for _, d in clone:GetDescendants() do
			if d:IsA("BasePart") and d ~= root then
				local okGrounded, grounded = pcall(function()
					return d:IsGrounded()
				end)
				if okGrounded and not grounded then
					holdTo(root, d)
				end
			end
		end
		table.clear(boss.joints)
		for _, joint in (LobbyNpcRig.FindJoints(clone)) do
			local basis = joint.motor.C0.Rotation
			table.insert(boss.joints, { name = joint.name, motor = joint.motor, basis = basis, basisInv = basis:Inverse() })
		end
		table.clear(boss.fans)
		table.clear(boss.glows)
		table.clear(boss.shipParts)
		for _, d in (ship :: Instance):GetDescendants() do
			if d:IsA("Motor6D") and d.Name == EggMobile.MotorNames.fan and d.Part1 then
				table.insert(boss.fans, { motor = d, side = tonumber(d.Part1:GetAttribute("EggFan")) or 1 })
			elseif d:IsA("BasePart") and d.Transparency < 1 then
				local kind = d:GetAttribute("EggGlow")
				local color = d.Color
				-- The lobby client may have been mid-pulse: the plasma pieces go back to the kit's colour.
				if kind == "Plasma" or kind == "PlasmaCore" or kind == "Hub" or kind == "Exhaust" then
					color = PLASMA
				end
				d.Color = color
				table.insert(boss.shipParts, { part = d, color = color })
				if type(kind) == "string" then
					table.insert(boss.glows, { part = d, kind = kind, color = color })
				end
			end
		end
		mountCannon()
		return true
	end

	-- No lobby Eggman on this client (streamed out, or a place without him): a simple part ship until he
	-- turns up (looked for again every few seconds).
	local function buildFallbackBoss()
		local s = Fx.Boss.Scale
		local model = Instance.new("Model")
		model.Name = "SSE_EggmanBoss"
		local hull = newPart("SSE_Hull", Vector3.new(7.8, 7.8, 7.8) * s, Color3.fromRGB(236, 238, 242), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		hull.CFrame = planFrame(serverNow())
		hull.Parent = model
		local pieces = {
			{ "SSE_Belly", Vector3.new(7.9, 7.9, 7.9) * s * 0.92, Color3.fromRGB(34, 34, 40), Enum.Material.SmoothPlastic, CFrame.new(0, -1.1 * s, 0) },
			{ "SSE_Dome", Vector3.new(5, 5, 5) * s, Color3.fromRGB(175, 225, 255), Enum.Material.Glass, CFrame.new(0, 3 * s, 0) },
			{ "SSE_Lamp", Vector3.new(1.2, 1.2, 1.2) * s, rgb(EggMobile.Colors.Lamp), Enum.Material.Neon, CFrame.new(0, 0.6 * s, -3.8 * s) },
		}
		for _, spec in pieces do
			local part = newPart(spec[1], spec[2], spec[3], spec[4], Enum.PartType.Ball)
			part.CFrame = hull.CFrame * spec[5]
			if spec[1] == "SSE_Dome" then
				part.Transparency = 0.45
			end
			part.Anchored = false
			holdTo(hull, part)
			part.Parent = model
		end
		model.PrimaryPart = hull
		model.Parent = runtimeFolder()
		boss.model, boss.root, boss.hull, boss.fallback, boss.scale = model, hull, hull, true, s
		boss.hullToRoot = CFrame.new()
		table.clear(boss.joints)
		table.clear(boss.fans)
		table.clear(boss.glows)
		table.clear(boss.shipParts)
		for _, part in partsOf(model) do
			table.insert(boss.shipParts, { part = part, color = part.Color })
		end
		mountCannon()
	end

	function destroyBoss()
		clearBossVfx()
		if boss.model then
			boss.model:Destroy()
		end
		boss.model, boss.root, boss.hull = nil, nil, nil
		boss.smoke = nil
		boss.lobbyBack = false
		boss.defeat, boss.flee, boss.gone = nil, nil, false
		boss.reaction = nil
		boss.flashing = false
		boss.recoilStart = -math.huge
		boss.gesture, boss.loop = nil, nil
		boss.fade = 0
		boss.shotAt = -math.huge
		boss.cannonOffset = CFrame.new()
		table.clear(boss.cannonWelds)
		table.clear(boss.fadeParts)
		table.clear(boss.joints)
		table.clear(boss.fans)
		table.clear(boss.glows)
		table.clear(boss.shipParts)
	end

	function ensureBoss()
		if boss.model and boss.model.Parent and not boss.fallback then
			return
		end
		if os.clock() < boss.nextSearch and boss.model then
			return
		end
		boss.nextSearch = os.clock() + 2
		if boss.model and boss.fallback then
			-- The lobby Eggman streamed in: he replaces the part ship (not while he is breaking or fleeing).
			if lobbyEggman() and not (boss.defeat or boss.flee) then
				destroyBoss()
			else
				return
			end
		end
		if not buildBossFromLobby() then
			buildFallbackBoss()
		end
		buildBossVfx()
	end

	-- A taunt: LobbyNpcPose's EggmanDriving reactions ("Talk" points at the local player, "Laugh").
	function taunt(name: string?)
		local reactions = LobbyNpcPose.Defs[EggMobile.PoseKind] and LobbyNpcPose.Defs[EggMobile.PoseKind].Reactions
		if not reactions then
			return
		end
		local pick = name
		if not pick then
			boss.tauntFlip = not boss.tauntFlip
			pick = if boss.tauntFlip then "Laugh" else (reactions.Talk and "Talk" or "Laugh")
		end
		if not reactions[pick] then
			return
		end
		local _, _, root = localCharacter()
		if root and boss.root then
			local rel = boss.frame:PointToObjectSpace(root.Position)
			local flat = math.sqrt(rel.X * rel.X + rel.Z * rel.Z)
			boss.aim.yaw = math.deg(math.atan2(-rel.X, -rel.Z))
			boss.aim.pitch = math.deg(math.atan2(rel.Y, math.max(flat, 1e-3)))
		end
		boss.reaction = pick
		boss.reactionStart = os.clock()
	end

	-- 2026-09-26 (owner, v2): a gesture (Fx.Gestures one-shots; Fx.GestureLoops: "Reload" / "Defeat" run until
	-- another loop or nil replaces them). He looks at the local player while he does it.
	function bossGesture(name: string?, loop: boolean?)
		if loop then
			if boss.loop ~= name then
				boss.loop = name
				boss.loopStart = os.clock()
			end
			return
		end
		boss.gesture = name
		boss.gestureStart = os.clock()
		local _, _, root = localCharacter()
		if root and boss.root then
			local rel = boss.frame:PointToObjectSpace(root.Position)
			local flat = math.sqrt(rel.X * rel.X + rel.Z * rel.Z)
			boss.aim.yaw = math.deg(math.atan2(-rel.X, -rel.Z))
			boss.aim.pitch = math.deg(math.atan2(rel.Y, math.max(flat, 1e-3)))
		end
	end

	local function applyPose(now: number)
		local reactionName, reactionAge = nil, nil
		if boss.reaction then
			local def = LobbyNpcPose.Defs[EggMobile.PoseKind].Reactions[boss.reaction]
			local age = os.clock() - boss.reactionStart
			if def and age < def.Duration then
				reactionName, reactionAge = boss.reaction, age
			else
				boss.reaction = nil
			end
		end
		local out = LobbyNpcPose.Sample(EggMobile.PoseKind, now, boss.poseOut, reactionName, reactionAge, boss.aim)
		local clock = os.clock()
		if boss.loop then
			local age = clock - boss.loopStart
			Fx.ApplyGesture(out, boss.loop, age, Fx.GestureWeight(boss.loop, age), boss.aim, LobbyNpcPose.AimArm)
		end
		if boss.gesture then
			local age = clock - boss.gestureStart
			local w = Fx.GestureWeight(boss.gesture, age)
			if w > 0 then
				Fx.ApplyGesture(out, boss.gesture, age, w, boss.aim, LobbyNpcPose.AimArm)
			elseif age > 0.1 then
				boss.gesture = nil
			end
		end
		local s = boss.scale
		for _, joint in boss.joints do
			local v = out[joint.name]
			if v and joint.motor.Parent then
				joint.motor.Transform = joint.basisInv
					* (CFrame.new(v[1] * s, v[2] * s, v[3] * s) * CFrame.Angles(math.rad(v[4]), math.rad(v[5]), math.rad(v[6])))
					* joint.basis
			end
		end
	end

	local function pulseBoss(t: number)
		if budget.Pulse then
			local beat = 0.5 + 0.5 * math.sin(TAU * 1.6 * t)
			local flicker = 0.5 + 0.5 * math.sin(TAU * 9.3 * t) * math.sin(TAU * 3.1 * t + 1)
			if not boss.flashing then
				for _, glow in boss.glows do
					local kind = glow.kind
					if kind == "Plasma" or kind == "PlasmaCore" or kind == "Hub" then
						glow.part.Color = glow.color:Lerp(PLASMA_HOT, 0.25 + 0.55 * beat)
					elseif kind == "Exhaust" then
						glow.part.Color = glow.color:Lerp(PLASMA_HOT, 0.2 + 0.7 * flicker)
					end
				end
			end
			local s = boss.scale
			for index, beam in boss.beams do
				local w = (if index == 1 then 2.8 else 1.3) * s
				beam.Width0 = w * (0.9 + 0.2 * beat)
				beam.Width1 = w * (1.75 + 0.3 * beat)
			end
			for index, jet in boss.exhaust do
				local f = 0.5 + 0.5 * math.sin(TAU * 11 * t + index * 2.1) * math.sin(TAU * 4.3 * t + index)
				jet.beam.Width0 = (1.05 + 0.35 * f) * s
				jet.tip.CFrame = CFrame.new(jet.rest + Vector3.new(0, 0, (f - 0.5) * 1.1 * s))
			end
		end
		local fan = (t * 14) % TAU
		for _, entry in boss.fans do
			entry.motor.Transform = CFrame.Angles(0, 0, entry.side * fan)
		end
	end

	-- The red flash of a hit (the ship's pieces toward red and back), his flinch and the recoil away from the
	-- hitter: 2026-09-26 (owner, v2) as strong as the charge (SSE.BossRecoil: studs, degrees).
	function bossHit(fromPosition: Vector3?, charge: number?)
		boss.flashStart = os.clock()
		boss.recoilStart = os.clock()
		local studs, degrees = SSE.BossRecoil(charge or 0)
		boss.recoilStuds, boss.recoilDegrees = studs, degrees
		local centre = boss.frame.Position
		local away = if fromPosition then centre - fromPosition else Vector3.new(math.random() - 0.5, 0.3, math.random() - 0.5)
		boss.recoilDir = if away.Magnitude > 1e-3 then away.Unit else Vector3.new(0, 1, 0)
		bossGesture("Hit")
	end

	local function updateFlash(clock: number)
		local age = clock - boss.flashStart
		local seconds = Fx.Boss.FlashSeconds
		if age < seconds then
			local k = 1 - age / seconds
			for _, entry in boss.shipParts do
				entry.part.Color = entry.color:Lerp(FLASH_RED, k)
			end
			boss.flashing = true
		elseif boss.flashing then
			boss.flashing = false
			for _, entry in boss.shipParts do
				entry.part.Color = entry.color
			end
		end
	end

	-- The ship's frame now: the contract's path (the lift-off in the Cinematic, the fight, the flight away after
	-- the defeat / the escape), plus the client's own shakes: the recoil of a hit, the defeat's shaking, the
	-- jolt of a shot.
	-- 2026-09-26 (owner, v2): the model fading into the horizon (every piece's LocalTransparencyModifier to
	-- `k`: the pieces' own Transparency is never touched), its beams off and its smoke thinning.
	local function collectFade(model: Instance, list: { { part: Instance, value: number } })
		table.clear(list)
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") or d:IsA("Decal") then
				table.insert(list, { part = d, value = (d :: any).LocalTransparencyModifier })
			elseif d:IsA("Beam") then
				table.insert(list, { part = d, value = -1 }) -- (a beam: switched off halfway)
			end
		end
	end

	local function fadeModel(_model: Instance?, list: { { part: Instance, value: number } }, k: number, smoke: ParticleEmitter?, smokeRate: number?)
		for _, entry in list do
			local piece = entry.part :: any
			if piece.Parent then
				if entry.value < 0 then
					if k > 0.55 and piece.Enabled then
						piece.Enabled = false
					end
				else
					piece.LocalTransparencyModifier = entry.value + (1 - entry.value) * k
				end
			end
		end
		if smoke and smoke.Parent and smokeRate then
			smoke.Rate = smokeRate * (1 - k)
		end
	end

	-- How far he has faded (server time `now`): Fx.EndFade from the Defeat / Escape's start; (v3) the crash's
	-- wreck: Fx.CrashFade over SSE.CrashTimes' fadeStart .. fadeEnd.
	local function fleeFade(flee: any, now: number): number
		if flee.times then
			return Fx.CrashFade(now, flee.times)
		end
		return Fx.EndFade(now - flee.endStart, flee.defeated)
	end

	local function bossFrame(now: number, clock: number): CFrame
		local cf = SSE.BossCFrame(state.origin, now, state.plan)
		-- A shot: the whole ship jolts back a little (its -Z is forward).
		local shotAge = clock - boss.shotAt
		if shotAge >= 0 and shotAge < Fx.Cannon.JoltSeconds then
			local k = 1 - shotAge / Fx.Cannon.JoltSeconds
			cf = cf * CFrame.new(0, 0, Fx.Cannon.Jolt * boss.scale / 2.2 * k * k) * CFrame.Angles(math.rad(-2.5 * k * k), 0, 0)
		end
		local defeat = boss.defeat
		if defeat and (not defeat.crash or not defeat.impacted) then
			-- Rattling while it breaks (v3: through the crash's dive; the wreck then lies still).
			local k = if defeat.crash then 0.45 else math.clamp(1 - (clock - defeat.start) / (Fx.Boss.ChainSeconds + 0.4), 0.25, 1)
			cf = cf * CFrame.new(math.sin(clock * 61) * 0.5 * k, math.cos(clock * 53) * 0.4 * k, 0)
				* CFrame.Angles(math.rad(4 * k * math.sin(clock * 47)), 0, math.rad(5 * k * math.cos(clock * 39)))
		end
		local age = clock - boss.recoilStart
		local r = Fx.Boss
		if age < r.RecoilSeconds then
			local k = (1 - age / r.RecoilSeconds) ^ 2
			local shake = math.sin(age * 55)
			local studs, degrees = boss.recoilStuds or r.RecoilStuds, boss.recoilDegrees or r.RecoilDegrees
			cf = (CFrame.new(boss.recoilDir * (studs * k * (0.65 + 0.35 * shake))) * cf)
				* CFrame.Angles(math.rad(degrees) * k * shake, 0, math.rad(degrees) * 0.6 * k * math.cos(age * 47))
		end
		return cf
	end

	-- The end begins (the Defeat or the Escape phase): the path flies him off (the plan's endStart); here the
	-- gestures, the smoke, and the pieces he fades out with.
	function startFlee(defeated: boolean)
		if boss.flee then
			return
		end
		local defeat = boss.defeat
		local endStart = if defeat and defeat.defeatStart then defeat.defeatStart elseif isEndPhase(state.phase) then state.phaseStart else serverNow()
		boss.flee = { start = os.clock(), endStart = endStart, defeated = defeated, origin = state.origin, plan = state.plan,
			times = if defeat and defeat.crash then defeat.times else nil }
		if boss.model then
			collectFade(boss.model, boss.fadeParts)
		end
		if boss.shield then
			boss.shield.Transparency = 1
		end
		if defeated then
			if boss.smoke then
				boss.smoke.Enabled = true
			end
			playSound("Fanfare")
			bossGesture("Defeat", true)
		else
			bossGesture(nil, true)
			taunt("Laugh")
		end
	end

	-- The defeat. 2026-09-26 (owner, v3): THE CRASH ("the Egg Mobile crashes to the ground like a plane out of
	-- control"). { "Defeat", crashPoint, impactTime } / SSE_CrashPoint: the ship dives on the contract's crash path
	-- (BossCFrame with the plan's crashPoint: spiralling, rolling, nose down) trailing thick smoke and the imported
	-- FireTrail flames, small blasts on the way down (Tiers: CrashPops); at the impact the big chain on the ground
	-- (SSE.Crash.Explosions, BombExplode + EggImpact, the tier's CrashBlasts), the defeat's camera punch, burning
	-- patches; the rings burst out of the crash point (the server's Rings); the wreck lies still, then fades out
	-- (CrashTimes' fadeStart .. fadeEnd). No dialogue. The lobby Eggman is back at his spot in the Return beat.
	-- Lighter on Low (fewer blasts and flames, a thinner smoke). A v2 server (no crash point): the old chain over
	-- the hull and the flight away.
	local function crashTrail()
		local attachment = if boss.hull then bossAttachment("SSE_Smoke", CFrame.new(0, 0, 2 * boss.scale)) else nil
		if not attachment then
			return
		end
		local bomb = vfxTemplate(SSE.VfxNames.BombExplode)
		local smoke = bomb and bomb:FindFirstChild("smoke", true)
		if smoke and smoke:IsA("ParticleEmitter") then
			local clone = smoke:Clone()
			clone.Enabled = false
			clone.Rate = budget.CrashSmoke
			clone.LockedToPart = false
			clone.Parent = attachment
			table.insert(boss.made, clone)
			boss.smoke = clone
		end
		local fire = vfxTemplate(SSE.VfxNames.FireTrail)
		if fire then
			for _, d in fire:GetDescendants() do
				if d:IsA("ParticleEmitter") and #boss.fires < budget.CrashFires then
					local clone = d:Clone()
					clone.Enabled = false
					clone.LockedToPart = false
					clone.Parent = attachment
					table.insert(boss.made, clone)
					table.insert(boss.fires, clone)
				end
			end
		end
	end

	function startDefeat(crashPoint: any?, impactTime: any?)
		if boss.defeat or not boss.model then
			return
		end
		refreshPlan()
		local plan = state.plan
		local crash: Vector3? = if typeof(crashPoint) == "Vector3" then crashPoint
			elseif plan and typeof(plan.crashPoint) == "Vector3" then plan.crashPoint
			else nil
		if not crash then
			local count = budget.DefeatBlasts
			local times = {}
			for index = 1, count do
				times[index] = (index - 1) / math.max(count - 1, 1) * Fx.Boss.ChainSeconds
			end
			boss.defeat = { start = os.clock(), times = times, fired = 0 }
			bossGesture("Defeat", true)
			prewarmRigs("Blast", count)
			local template = vfxTemplate(SSE.VfxNames.BombExplode)
			local smoke = template and template:FindFirstChild("smoke", true)
			if boss.hull and smoke and smoke:IsA("ParticleEmitter") and budget.Tier ~= "Low" then
				local clone = smoke:Clone()
				clone.Enabled = false
				clone.Rate = if budget.Tier == "High" then 14 else 7
				clone.LockedToPart = false
				local attachment = bossAttachment("SSE_Smoke", CFrame.new(0, 0, 2 * boss.scale))
				clone.Parent = attachment
				table.insert(boss.made, clone)
				boss.smoke = clone
			end
			local cam = SSE.Camera.Defeat
			CameraPunch.Shake(cam.Shake[1], cam.Shake[2])
			CameraPunch.Fov(cam.Fov)
			startFlee(true)
			return
		end
		local impact = tonumber(impactTime)
		local defeatStart = if plan and plan.crashPoint and plan.endStart then plan.endStart
			elseif impact then impact - SSE.Crash.Seconds
			elseif isEndPhase(state.phase) then state.phaseStart
			else serverNow()
		if plan and not (plan.crashPoint and plan.endStart) then
			-- (the message came before the attributes: the same plan the server flies)
			state.plan = SSE.Plan(plan.start, plan.seed, plan.liftOff, defeatStart, PHASE.Defeat, crash, plan.lobbyOrigin)
		end
		boss.defeat = {
			start = os.clock(), crash = crash, defeatStart = defeatStart, times = SSE.CrashTimes(defeatStart),
			pops = Fx.CrashPops(defeatStart, budget.CrashPops), popped = 0, blasts = 0, impacted = false, calm = false, lobby = false,
		}
		bossGesture("Defeat", true)
		prewarmRigs("Blast", math.max(budget.CrashBlasts, 2))
		prewarmFires(budget.FirePatches + 2)
		crashTrail()
		if boss.smoke then
			boss.smoke.Enabled = true
		end
		for _, flame in boss.fires do
			flame.Enabled = true
		end
		-- The break: a first jolt (the big punch comes with the impact).
		local cam = SSE.Camera.Defeat
		CameraPunch.Shake(cam.Shake[1] * 0.6, cam.Shake[2] * 0.4)
		startFlee(true)
	end

	-- Every frame of the defeat (`now` the server clock): the crash's blasts on the way down, the impact and its
	-- chain, the flames dying down with the fade, the lobby Eggman coming back. (v2: the chain over the hull.)
	local function updateDefeat(clock: number, now: number)
		local defeat = boss.defeat
		if not defeat then
			return
		end
		if not defeat.crash then
			if defeat.fired >= #defeat.times then
				return
			end
			local elapsed = clock - defeat.start
			while defeat.fired < #defeat.times and elapsed >= defeat.times[defeat.fired + 1] do
				defeat.fired += 1
				local hullCf = boss.frame
				local r = 7.5 * boss.scale / 2.2
				local angle = math.random() * TAU
				local y = (math.random() - 0.3) * r
				local point = hullCf * Vector3.new(math.cos(angle) * r, y, math.sin(angle) * r)
				fireRig("Blast", CFrame.new(point))
				playSound("DefeatBoom", distanceFromCamera(point))
				if defeat.fired == #defeat.times then
					local cam = SSE.Camera.Defeat
					CameraPunch.Shake(cam.Shake[1], cam.Shake[2] * 0.6)
				end
			end
			return
		end
		while defeat.popped < #defeat.pops and now >= defeat.pops[defeat.popped + 1] do
			defeat.popped += 1
			local k = boss.scale / 2.2
			local point = boss.frame * Vector3.new((math.random() - 0.5) * 8 * k, (math.random() - 0.3) * 5 * k, (math.random() - 0.5) * 8 * k)
			fireRig("Blast", CFrame.new(point), 0.45)
			playSound("DefeatBoom", distanceFromCamera(point), 1.3)
		end
		local times = defeat.times
		if not defeat.impacted and now >= times.impact then
			defeat.impacted = true
			local cam = SSE.Camera.Defeat
			CameraPunch.Shake(cam.Shake[1], cam.Shake[2])
			CameraPunch.Fov(cam.Fov)
			burnAt(defeat.crash, budget.FirePatches + 1)
		end
		local list = SSE.Crash.Explosions
		local count = math.min(#list, budget.CrashBlasts)
		while defeat.blasts < count and now >= times.impact + list[defeat.blasts + 1][1] do
			defeat.blasts += 1
			local e = list[defeat.blasts]
			local point = defeat.crash + Vector3.new(e[2], e[3], e[4])
			fireRig("Blast", CFrame.new(point), e[5])
			playSound("DefeatBoom", distanceFromCamera(point))
		end
		if not defeat.calm and now >= times.fadeStart then
			defeat.calm = true
			for _, flame in boss.fires do
				flame.Enabled = false
			end
		end
	end

	-- The event ended while he was still flying away (an escape ends it at once): the ship leaves the boss
	-- state (destroyBoss no longer sees it) and finishes its flight alone (runOutro).
	function detachFleeingBoss(): any?
		if not (boss.flee and not boss.gone and boss.model and boss.root) then
			return nil
		end
		local fadeParts = table.clone(boss.fadeParts)
		local out = { model = boss.model, root = boss.root, hullToRoot = boss.hullToRoot, flee = boss.flee, fadeParts = fadeParts,
			smoke = boss.smoke, smokeRate = if boss.smoke then boss.smoke.Rate else nil }
		boss.model, boss.root, boss.hull = nil, nil, nil
		boss.smoke = nil
		table.clear(boss.made) -- its beams and smoke leave with it
		return out
	end

	-- The flight away finished alone (on the plan he had), fading into the horizon; `onDone` once he is gone
	-- (the lobby's Eggman then fades back in).
	function runOutro(out: any, onDone: (() -> ())?)
		out.model.Parent = Workspace
		local connection: RBXScriptConnection? = nil
		local smokeRate = out.smokeRate
		local began = os.clock()
		local flee = out.flee
		connection = RunService.RenderStepped:Connect(function()
			local now = serverNow()
			local fade = math.max(fleeFade(flee, now), math.clamp((os.clock() - began) / Fx.Boss.OutroSeconds, 0, 1))
			if fade >= 1 or killed() or not out.model.Parent or state.active then
				if connection then
					connection:Disconnect()
				end
				out.model:Destroy()
				if onDone then
					onDone()
				end
				return
			end
			out.root.CFrame = SSE.BossCFrame(flee.origin, now, flee.plan) * out.hullToRoot
			fadeModel(out.model, out.fadeParts, fade, out.smoke, smokeRate)
		end)
	end

	-- The cannon: out for an attack (and the whole Bombard), in to reload, kicking on a shot; the shield up while
	-- he attacks in the Battle, dropping (flickering) while he reloads.
	local function updateCannonAndShield(clock: number, now: number)
		local stateName = if state.phase == PHASE.Battle then state.bossState else ""
		local stateAge = now - state.bossStateStart
		local out = Fx.CannonOut(stateName, stateAge)
		local kick = Fx.CannonKick(clock - boss.shotAt)
		if boss.defeat or boss.flee then
			out = 0.4
		end
		local offset = Fx.CannonOffset(out, kick, boss.scale, CFrame)
		boss.cannonOffset = offset
		local mount = boss.cannonMount
		local moved = CFrame.new(mount) * offset * CFrame.new(-mount)
		for _, entry in boss.cannonWelds do
			if entry.weld.Parent then
				entry.weld.C0 = moved * entry.base
			end
		end
		local shield = boss.shield
		if shield then
			local want = if state.phase == PHASE.Battle and state.bossState ~= "Reload" and not boss.defeat and not boss.flee then 1 else 0
			local step = 1 / 60 / Fx.Boss.ShieldFlicker
			boss.shieldLevel = math.clamp(boss.shieldLevel + (if want > boss.shieldLevel then step else -step), 0, 1)
			local level = boss.shieldLevel
			if level <= 0.001 then
				if shield.Transparency ~= 1 then
					shield.Transparency = 1
				end
			else
				-- Flickering while it comes and goes, a slow shimmer while it holds.
				local flicker = if level < 1 then (if math.sin(clock * 70) > 0 then 1 else 0.35) else 0.85 + 0.15 * math.sin(clock * 3)
				shield.Transparency = 1 - (1 - Fx.Boss.ShieldTransparency) * level * flicker
			end
		end
	end

	-- Every frame: the hover, the gestures, the cannon and the shield, the fade into the horizon.

	function updateBoss(now: number, clock: number)
		-- (v3) the defeat's timeline runs on even once the wreck has faded (the lobby Eggman's return)
		if boss.defeat then
			updateDefeat(clock, now)
		end
		if not boss.model or boss.gone then
			return
		end
		if not boss.model.Parent then
			boss.model = nil
			return
		end
		local frame = bossFrame(now, clock)
		boss.frame = frame
		local root = boss.root
		if root and root.Parent then
			root.CFrame = frame * boss.hullToRoot
		end
		local flee = boss.flee
		if flee then
			boss.fade = fleeFade(flee, now)
			if boss.fade >= 1 then
				boss.gone = true
				fadeModel(boss.model, boss.fadeParts, 1, boss.smoke, 0)
				if boss.smoke then
					boss.smoke.Enabled = false
				end
				if root then
					root.CFrame = FAR_AWAY * boss.hullToRoot
				end
				return
			end
			fadeModel(boss.model, boss.fadeParts, boss.fade, boss.smoke, if flee.times then budget.CrashSmoke elseif budget.Tier == "High" then 14 else 7)
		end
		-- Nothing more to animate when the camera is far away.
		if (frame.Position - cameraPosition()).Magnitude > Fx.Boss.FarHide then
			return
		end
		if #boss.joints > 0 and clock >= boss.nextPose then
			boss.nextPose = clock + 1 / budget.PoseHz
			if (state.phase == PHASE.Bombard or state.phase == PHASE.Battle or state.phase == PHASE.Emeralds)
				and not boss.defeat and not boss.loop and clock >= boss.nextTaunt then
				boss.nextTaunt = clock + Fx.Boss.TauntEvery
				taunt(nil)
			end
			applyPose(now)
		end
		updateCannonAndShield(clock, now)
		pulseBoss(now)
		updateFlash(clock)
	end
end)()

----------------------------------------------------------------------
-- The lobby's Eggman, hidden on this client while the event runs (and exactly back after)
----------------------------------------------------------------------
;(function() -- (a function, not a do-block: see the note at the top)
	local lobbyHide = { model = nil :: Model?, transparency = {} :: { [Instance]: number }, enabled = {} :: { [Instance]: boolean } }
	local fadeConnection: RBXScriptConnection? = nil
	local fading: any = nil -- { transparency, enabled } while he fades back in

	local putBack
	-- A fade cut short (a new event, the kill switch): every piece exactly back first.
	local function stopFade()
		if fadeConnection then
			fadeConnection:Disconnect()
			fadeConnection = nil
		end
		if fading then
			local f = fading
			fading = nil
			putBack(f.transparency, f.enabled)
		end
	end

	function putBack(transparency: { [Instance]: number }, enabled: { [Instance]: boolean })
		for piece, value in transparency do
			if piece.Parent then
				(piece :: any).LocalTransparencyModifier = value
			end
		end
		for thing, value in enabled do
			if thing.Parent then
				(thing :: any).Enabled = value
			end
		end
	end

	-- Everything exactly as it was. 2026-09-26 (owner, v2): with `fadeSeconds` he FADES back in at his spot
	-- (each piece from invisible to its own LocalTransparencyModifier: glass stays glass); his beams, prompts
	-- and signs come back once he is half there.
	function restoreLobby(fadeSeconds: number?)
		stopFade()
		local transparency = table.clone(lobbyHide.transparency)
		local enabled = table.clone(lobbyHide.enabled)
		table.clear(lobbyHide.transparency)
		table.clear(lobbyHide.enabled)
		lobbyHide.model = nil
		local seconds = tonumber(fadeSeconds) or 0
		if seconds <= 0 or killed() then
			putBack(transparency, enabled)
			return
		end
		if next(transparency) == nil and next(enabled) == nil then
			return -- (nothing hidden: he is back already)
		end
		local start = os.clock()
		local switched = false
		fading = { transparency = transparency, enabled = enabled }
		fadeConnection = RunService.RenderStepped:Connect(function()
			local k = math.clamp((os.clock() - start) / seconds, 0, 1)
			local e = k * k * (3 - 2 * k)
			for piece, value in transparency do
				if piece.Parent then
					(piece :: any).LocalTransparencyModifier = 1 + (value - 1) * e
				end
			end
			if not switched and k >= 0.5 then
				switched = true
				for thing, value in enabled do
					if thing.Parent then
						(thing :: any).Enabled = value
					end
				end
			end
			if k >= 1 then
				stopFade() -- (every piece exactly back)
			end
		end)
	end

	local function disableLocally(thing: Instance)
		local current = (thing :: any).Enabled
		if lobbyHide.enabled[thing] == nil then
			lobbyHide.enabled[thing] = current
		end
		if current then
			(thing :: any).Enabled = false
		end
	end

	-- Again every sweep: the lobby's own clients rebuild their beams, signs and tags as they please.
	function hideLobby()
		stopFade()
		local model = lobbyEggman()
		if model ~= lobbyHide.model then
			restoreLobby()
			lobbyHide.model = model
		end
		if not model then
			return
		end
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") or d:IsA("Decal") then
				if lobbyHide.transparency[d] == nil then
					lobbyHide.transparency[d] = (d :: any).LocalTransparencyModifier
				end
				(d :: any).LocalTransparencyModifier = 1
			elseif d:IsA("Beam") or d:IsA("ParticleEmitter") or d:IsA("Light") or d:IsA("ProximityPrompt") or d:IsA("BillboardGui") or d:IsA("Trail") then
				disableLocally(d)
			end
		end
		-- The name tag, the "!" and the QUESTS sign live in PlayerGui, adorned to him.
		for _, gui in playerGui:GetChildren() do
			if gui:IsA("BillboardGui") and gui.Adornee and gui.Adornee:IsDescendantOf(model) then
				disableLocally(gui)
			end
		end
	end
end)()

----------------------------------------------------------------------
-- The HUD: the boss bar, the reward popups, the flashes, the touch button, the reticle, the "!"
-- 2026-09-26 (owner, v3): "don't fill the screen with UI and text". No phase banners, no notices, no hints:
-- a small boss bar at the top in the game's HUD style (Fx.Style: the level / stamina bars' white glass, navy ink
-- outline, light rim, round corners, GothamSSm Bold with a navy stroke), a tiny "ATTACK NOW!" under it only in a
-- Reload window, the reward / ring popups, the lock-on reticle ("(A)" / "(X)" on a gamepad), the touch button.
----------------------------------------------------------------------
local hud, buildHud, destroyHud, showReward, goldenFlash, hitFlash, announce, setHp, layoutButton
local lingerHud
-- 2026-09-26 (owner, v2): the charged homing attack (hold / release), filled in by its block below; the touch
-- button and the inputs call it.
local Charge = {} :: any
-- The cinematics (the camera, the letterbox, the interface), filled in below; everything that must stop or
-- wait for one looks here.
local Cinema = { active = nil :: any } :: any
local INK, RIM = rgb(Fx.Style.Ink), rgb(Fx.Style.Rim)
-- The HUD bars' font (GothamSSm Bold), FredokaOne when it cannot be made.
local HUD_FONT: any = nil
pcall(function()
	HUD_FONT = Font.new(Fx.Style.Font, Enum.FontWeight.Bold)
end)
;(function() -- (a function, not a do-block: see the note at the top)
	hud = {
		gui = nil :: ScreenGui?,
		bar = nil :: Frame?,
		barGlow = nil :: UIStroke?, -- the track's light rim: gold and pulsing while he can be hit
		fill = nil :: Frame?,
		trail = nil :: Frame?,
		hpText = nil :: TextLabel?,
		cue = nil :: TextLabel?, -- the tiny "ATTACK NOW!" (Reload windows)
		cueScale = nil :: UIScale?,
		trailShare = 1,
		fillShare = 1,
		popups = {} :: { TextLabel },
		popupIndex = 0,
		flash = nil :: Frame?,
		button = nil :: TextButton?,
		buttonScale = nil :: UIScale?,
		reticle = nil :: BillboardGui?,
		reticleSpin = nil :: Frame?,
		reticleRing = nil :: UIStroke?,
		reticlePrompt = nil :: TextLabel?, -- "(A)" / "(X)" on a gamepad
		alert = nil :: BillboardGui?, -- the small "!" over him while he reloads
		alertMark = nil :: TextLabel?,
		-- A menu of the game is open (the touch button hides): MenuEvents' own requests, not the event's HUD hold.
		menuOpen = false,
	}

	-- The HUD bars' words: GothamSSm Bold, white, a navy stroke (the language's own font where it needs one).
	local function hudText(label: TextLabel, color: Color3, thickness: number)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		if HUD_FONT then
			pcall(function()
				label.FontFace = HUD_FONT
			end)
		end
		label.TextColor3 = color
		label.TextScaled = true
		label.ZIndex = 4
		local stroke = Instance.new("UIStroke")
		stroke.Color = INK
		stroke.Thickness = thickness
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		stroke.LineJoinMode = Enum.LineJoinMode.Round
		stroke.Parent = label
		TutorialText.Style(label, lang)
	end

	-- The designer's words (FredokaOne, white, a dark outline): the popups and the touch button.
	local function styleText(label: TextLabel, color: Color3, strokeColor: Color3, thickness: number)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextColor3 = color
		label.TextScaled = true
		label.ZIndex = 3
		local stroke = Instance.new("UIStroke")
		stroke.Color = strokeColor
		stroke.Thickness = thickness
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		stroke.LineJoinMode = Enum.LineJoinMode.Round
		stroke.Parent = label
		TutorialText.Style(label, lang)
	end

	local function corner(parent: Instance, scale: number, offset: number?)
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(scale, offset or 0)
		round.Parent = parent
	end

	local function outline(parent: Instance, color: Color3, thickness: number, transparency: number)
		local stroke = Instance.new("UIStroke")
		stroke.Color = color
		stroke.Thickness = thickness
		stroke.Transparency = transparency
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.LineJoinMode = Enum.LineJoinMode.Round
		stroke.Parent = parent
		return stroke
	end

	local function goldGradient(parent: Instance)
		local fill = Instance.new("UIGradient")
		fill.Rotation = 90
		fill.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 248, 170)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 205, 40)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(230, 130, 0)),
		})
		fill.Parent = parent
	end

	local function mainHud(): ScreenGui?
		local gui = playerGui:FindFirstChild("Mainhud")
		return if gui and gui:IsA("ScreenGui") then gui else nil
	end

	function buildHud()
		if hud.gui and hud.gui.Parent then
			return
		end
		local gui = Instance.new("ScreenGui")
		gui.Name = Fx.GuiName
		gui.ResetOnSpawn = false
		gui.DisplayOrder = 12
		gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		local main = mainHud()
		-- The same pixels as the Main HUD (HudErgonomics' "Main HUD pixels").
		gui.IgnoreGuiInset = if main then main.IgnoreGuiInset else false
		gui.Enabled = false
		hud.gui = gui

		-- The boss bar (top centre, small): the name over a glass track, the HP inside it, the cue under it.
		local B = Fx.BossBar
		local trackTop = B.NameHeight + B.Gap
		local bar = Instance.new("Frame")
		bar.Name = "BossBar"
		bar.AnchorPoint = Vector2.new(0.5, 0)
		bar.Position = UDim2.new(0.5, 0, 0, B.Top)
		bar.Size = UDim2.new(B.WidthShare, 0, 0, trackTop + B.TrackHeight)
		bar.BackgroundTransparency = 1
		bar.Visible = false
		bar.Parent = gui
		local limits = Instance.new("UISizeConstraint")
		limits.MinSize = Vector2.new(B.MinWidth, 0)
		limits.MaxSize = Vector2.new(B.MaxWidth, math.huge)
		limits.Parent = bar
		local name = Instance.new("TextLabel")
		name.Name = "Title"
		name.Position = UDim2.fromOffset(4, 0)
		name.Size = UDim2.new(0.6, 0, 0, B.NameHeight)
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.Text = Fx.Word(lang, "BossName")
		name.Parent = bar
		hudText(name, Color3.new(1, 1, 1), 1.5)
		-- The light rim round the track (the HUD bars' outer stroke): gold and pulsing while he can be hit.
		local rim = Instance.new("Frame")
		rim.Name = "TrackRim"
		rim.Position = UDim2.fromOffset(-2, trackTop - 2)
		rim.Size = UDim2.new(1, 4, 0, B.TrackHeight + 4)
		rim.BackgroundTransparency = 1
		rim.Parent = bar
		corner(rim, 0, 10)
		local glow = outline(rim, RIM, 2, 0.33)
		local track = Instance.new("Frame")
		track.Name = "Track"
		track.Position = UDim2.fromOffset(0, trackTop)
		track.Size = UDim2.new(1, 0, 0, B.TrackHeight)
		track.BackgroundColor3 = rgb(Fx.Style.Glass)
		track.BackgroundTransparency = Fx.Style.GlassTransparency
		track.BorderSizePixel = 0
		track.ClipsDescendants = true
		track.ZIndex = 2
		track.Parent = bar
		corner(track, 0, 8)
		outline(track, INK, 2, 0.16)
		local trail = Instance.new("Frame")
		trail.Name = "Damage"
		trail.Size = UDim2.fromScale(1, 1)
		trail.BackgroundColor3 = rgb(Fx.Style.HpTrail)
		trail.BorderSizePixel = 0
		trail.ZIndex = 2
		trail.Parent = track
		corner(trail, 0, 8)
		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.Size = UDim2.fromScale(1, 1)
		fill.BackgroundColor3 = rgb(Fx.Style.HpFill)
		fill.BorderSizePixel = 0
		fill.ZIndex = 3
		fill.Parent = track
		corner(fill, 0, 8)
		outline(fill, INK, 1.5, 0.16)
		local hpText = Instance.new("TextLabel")
		hpText.Name = "Hp"
		hpText.AnchorPoint = Vector2.new(0.5, 0)
		hpText.Position = UDim2.new(0.5, 0, 0, trackTop + 2)
		hpText.Size = UDim2.new(1, -12, 0, B.TrackHeight - 4)
		hpText.Text = ""
		hpText.Parent = bar
		hudText(hpText, Color3.new(1, 1, 1), 1.5)
		hpText.ZIndex = 5
		local cue = Instance.new("TextLabel")
		cue.Name = "Cue"
		cue.AnchorPoint = Vector2.new(0.5, 0)
		cue.Position = UDim2.new(0.5, 0, 1, B.Gap)
		cue.Size = UDim2.new(0.62, 0, 0, B.CueHeight)
		cue.Text = Fx.Word(lang, "Vulnerable")
		cue.Visible = false
		cue.Parent = bar
		hudText(cue, Color3.fromRGB(255, 226, 90), 1.5)
		local cueScale = Instance.new("UIScale")
		cueScale.Parent = cue
		hud.bar, hud.fill, hud.trail, hud.hpText, hud.barGlow, hud.cue, hud.cueScale = bar, fill, trail, hpText, glow, cue, cueScale

		-- The reward / ring popups (three, reused in turn): small.
		for index = 1, 3 do
			local popup = Instance.new("TextLabel")
			popup.Name = "Reward" .. index
			popup.AnchorPoint = Vector2.new(0.5, 0.5)
			popup.Position = UDim2.fromScale(0.5, 0.36)
			popup.Size = UDim2.new(0.5, 0, 0, 26)
			popup.Text = ""
			popup.Visible = false
			popup.Parent = gui
			styleText(popup, Color3.new(1, 1, 1), INK, 2)
			goldGradient(popup)
			local limit = Instance.new("UITextSizeConstraint")
			limit.MaxTextSize = 22
			limit.Parent = popup
			table.insert(hud.popups, popup)
		end

		-- The screen flash (the emeralds' golden one; v3: the homing hit's quick white one), over the top bar too.
		local flash = Instance.new("Frame")
		flash.Name = "GoldenFlash"
		flash.Position = UDim2.new(0, 0, 0, -80)
		flash.Size = UDim2.new(1, 0, 1, 160)
		flash.BackgroundColor3 = GOLD
		flash.BackgroundTransparency = 1
		flash.BorderSizePixel = 0
		flash.Visible = false
		flash.ZIndex = 10
		flash.Parent = gui
		hud.flash = flash

		-- The touch HOMING ATTACK button (placed by Fx.HomingButtonRect): the designer's gold button.
		local button = Instance.new("TextButton")
		button.Name = "HomingAttack"
		button.AnchorPoint = Vector2.new(0.5, 0.5)
		button.AutoButtonColor = false
		button.BackgroundColor3 = Color3.new(1, 1, 1)
		button.Text = ""
		button.Visible = false
		button.ZIndex = 4
		button.Parent = gui
		corner(button, 0.5)
		goldGradient(button)
		outline(button, Color3.new(1, 1, 1), 2, 0)
		local label = Instance.new("TextLabel")
		label.Name = "Label"
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Position = UDim2.fromScale(0.5, 0.5)
		label.Size = UDim2.fromScale(0.78, 0.56)
		label.Text = Fx.Word(lang, "Homing")
		label.ZIndex = 5
		label.Parent = button
		styleText(label, Color3.new(1, 1, 1), Color3.fromRGB(90, 30, 0), 2)
		local press = Instance.new("UIScale")
		press.Name = "Press"
		press.Parent = button
		hud.button, hud.buttonScale = button, press
		-- 2026-09-26 (owner, v2): HOLD the button to charge, let go to launch (Charge.Begin / Charge.Release).
		button.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then
				return
			end
			TweenService:Create(press, TweenInfo.new(0.06), { Scale = 0.86 }):Play()
			Charge.Begin("Touch", input)
		end)
		button.InputEnded:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then
				return
			end
			TweenService:Create(press, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
			Charge.Release("Touch")
		end)
		gui.Parent = playerGui

		-- The lock-on reticle: a BillboardGui on the ship (in PlayerGui: a ScreenGui cannot hold one); on a gamepad
		-- the button to press under it: "(A)" in the air, "(X)" on the ground (Fx.ReticlePrompt).
		local reticle = Instance.new("BillboardGui")
		reticle.Name = "SSE_Reticle"
		reticle.AlwaysOnTop = true
		reticle.LightInfluence = 0
		reticle.Size = UDim2.fromOffset(96, 118)
		reticle.MaxDistance = SSE.Homing.Range + 60
		reticle.ResetOnSpawn = false
		reticle.Enabled = false
		local spin = Instance.new("Frame")
		spin.Name = "Spin"
		spin.AnchorPoint = Vector2.new(0.5, 0.5)
		spin.Position = UDim2.new(0.5, 0, 0, 48)
		spin.Size = UDim2.fromOffset(80, 80)
		spin.BackgroundTransparency = 1
		spin.Parent = reticle
		local ring = Instance.new("Frame")
		ring.Name = "Ring"
		ring.Size = UDim2.fromScale(1, 1)
		ring.BackgroundTransparency = 1
		ring.Parent = spin
		corner(ring, 0.5)
		local ringStroke = outline(ring, GOLD, 4, 0)
		for index = 0, 3 do
			local tick = Instance.new("Frame")
			tick.Name = "Tick"
			tick.AnchorPoint = Vector2.new(0.5, 0.5)
			local angle = index * math.pi / 2
			tick.Position = UDim2.fromScale(0.5 + 0.5 * math.sin(angle), 0.5 - 0.5 * math.cos(angle))
			tick.Size = UDim2.fromOffset(if index % 2 == 0 then 6 else 16, if index % 2 == 0 then 16 else 6)
			tick.BackgroundColor3 = Color3.fromRGB(255, 60, 40)
			tick.BorderSizePixel = 0
			tick.Parent = spin
		end
		local prompt = Instance.new("TextLabel")
		prompt.Name = "Prompt"
		prompt.AnchorPoint = Vector2.new(0.5, 1)
		prompt.Position = UDim2.fromScale(0.5, 1)
		prompt.Size = UDim2.fromOffset(44, 22)
		prompt.Text = ""
		prompt.Visible = false
		prompt.Parent = reticle
		hudText(prompt, Color3.new(1, 1, 1), 2)
		reticle.Parent = playerGui
		hud.reticle, hud.reticleSpin, hud.reticleRing, hud.reticlePrompt = reticle, spin, ringStroke, prompt

		-- 2026-09-26 (owner, v2): the flashing "!" over him while he reloads (he can be hit); v3: small, no words.
		local alert = Instance.new("BillboardGui")
		alert.Name = "SSE_Alert"
		alert.AlwaysOnTop = true
		alert.LightInfluence = 0
		alert.Size = UDim2.fromOffset(56, 56)
		alert.MaxDistance = 900
		alert.ResetOnSpawn = false
		alert.Enabled = false
		local mark = Instance.new("TextLabel")
		mark.Name = "Mark"
		mark.AnchorPoint = Vector2.new(0.5, 0.5)
		mark.Position = UDim2.fromScale(0.5, 0.5)
		mark.Size = UDim2.fromScale(1, 1)
		mark.Text = "!"
		mark.Parent = alert
		styleText(mark, Color3.fromRGB(255, 225, 60), INK, 3)
		alert.Parent = playerGui
		hud.alert, hud.alertMark = alert, mark
	end

	local function clearRefs()
		hud.alert, hud.alertMark, hud.barGlow, hud.cue, hud.cueScale = nil, nil, nil, nil, nil
		hud.gui, hud.bar, hud.fill, hud.trail, hud.hpText = nil, nil, nil, nil, nil
		hud.flash, hud.button, hud.buttonScale = nil, nil, nil
		hud.reticle, hud.reticleSpin, hud.reticleRing, hud.reticlePrompt = nil, nil, nil, nil
		table.clear(hud.popups)
		hud.trailShare, hud.fillShare = 1, 1
	end

	function destroyHud()
		if hud.gui then
			hud.gui:Destroy()
		end
		if hud.reticle then
			hud.reticle:Destroy()
		end
		if hud.alert then
			hud.alert:Destroy()
		end
		clearRefs()
	end

	-- The end of the event with the ship still going: the reward / ring popups may finish (the rest goes at
	-- once), then the whole HUD. A new event builds its own.
	function lingerHud(seconds: number)
		local gui = hud.gui
		if not gui then
			return
		end
		if hud.reticle then
			hud.reticle:Destroy()
		end
		if hud.alert then
			hud.alert:Destroy()
		end
		for _, name in { "BossBar", "HomingAttack", "GoldenFlash" } do
			local piece = gui:FindFirstChild(name)
			if piece and piece:IsA("GuiObject") then
				piece.Visible = false
			end
		end
		clearRefs()
		task.delay(seconds, function()
			gui:Destroy()
		end)
	end

	function showReward(wins: any, speed: any, text: string?)
		if #hud.popups == 0 then
			return
		end
		hud.popupIndex = hud.popupIndex % #hud.popups + 1
		local popup = hud.popups[hud.popupIndex]
		popup.Text = text or Fx.RewardText(lang, wins, speed)
		popup.Position = UDim2.fromScale(0.5, 0.4)
		popup.TextTransparency = 0
		popup.Visible = true
		local rise = TweenService:Create(popup, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.fromScale(0.5, 0.33) })
		rise:Play()
		local fade = TweenService:Create(popup, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.8), { TextTransparency = 1 })
		fade:Play()
	end

	local flashToken = 0
	local function flashScreen(color: Color3, from: number, seconds: number)
		local flash = hud.flash
		if not flash then
			return
		end
		flashToken += 1
		local token = flashToken
		flash.BackgroundColor3 = color
		flash.BackgroundTransparency = from
		flash.Visible = true
		local tween = TweenService:Create(flash, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 })
		tween:Play()
		tween.Completed:Once(function()
			if token == flashToken then
				flash.Visible = false
			end
		end)
	end

	function goldenFlash()
		flashScreen(GOLD, 0.3, Fx.Emerald.FlashSeconds)
	end

	-- 2026-09-26 (owner, v3): the homing hit's quick white flash (with the hit-stop and the shake).
	function hitFlash()
		local f = Fx.Homing.HitFlash
		flashScreen(Color3.new(1, 1, 1), f.Transparency, f.Seconds)
	end

	-- 2026-09-26: the event's chat lines. TextChannel:DisplaySystemMessage only works on a client, so each
	-- client posts them itself, in its player's language, once per event (Fx.ChatLine: en / es / pt).
	local announced: { [string]: any } = {}
	function announce(key: string)
		if announced[key] == state.eventId then
			return
		end
		announced[key] = state.eventId
		pcall(function()
			local channels = TextChatService:FindFirstChild("TextChannels")
			local general = channels and channels:FindFirstChild("RBXGeneral")
			if general and general:IsA("TextChannel") then
				general:DisplaySystemMessage(Fx.ChatLine(lang, key))
			end
		end)
	end

	function setHp()
		local text, share = Fx.HpText(Workspace:GetAttribute(ATTR.BossHP), Workspace:GetAttribute(ATTR.BossMaxHP))
		if hud.hpText then
			hud.hpText.Text = text
		end
		if hud.fill then
			hud.fill.Size = UDim2.fromScale(share, 1)
		end
		if share < hud.fillShare and hud.bar then
			-- A hit: the bar jolts.
			hud.bar.Rotation = if math.random() < 0.5 then -2 else 2
		end
		hud.fillShare = share
	end

	-- The touch button's place (HudErgonomics' touch plan, the phone column's pieces).
	function layoutButton()
		local button, gui = hud.button, hud.gui
		if not (button and gui) then
			return
		end
		local size = gui.AbsoluteSize
		if size.X <= 0 or size.Y <= 0 then
			return
		end
		local camera = Workspace.CurrentCamera
		local viewport = if camera then camera.ViewportSize else size
		local topBar = (GuiService:GetGuiInset()).Y
		local neighbours = HudErgonomics.TouchNeighbours(viewport.X, viewport.Y, UserInputService.KeyboardEnabled, topBar)
		local main = mainHud()
		local burst = main and main:FindFirstChild("SonicBurstButton")
		local burstShown = burst ~= nil and burst:IsA("GuiObject") and burst.Visible
		local layout = if UserInputService.TouchEnabled then player:GetAttribute("TouchLayout") else nil
		local plan = HudErgonomics.TouchControls(size.X, size.Y, layout, neighbours, burstShown)
		local avoid = table.clone(neighbours)
		if HudErgonomics.IsCompact(viewport.X, viewport.Y, true, UserInputService.KeyboardEnabled) then
			-- The phone column's Starter Pack and badges (screen pixels -> Main HUD pixels).
			local column = HudErgonomics.PhoneColumn(viewport.X, viewport.Y, true, false, 2, topBar)
			local inset = if gui.IgnoreGuiInset then 0 else topBar
			for _, r in { column.Pack, column.Badges[1], column.Badges[2] } do
				if r then
					table.insert(avoid, { Left = r.Left, Top = r.Top - inset, Right = r.Right, Bottom = r.Bottom - inset })
				end
			end
		end
		local r = Fx.HomingButtonRect(size.X, size.Y, plan, avoid)
		button.Size = UDim2.fromOffset(r.Size, r.Size)
		button.Position = UDim2.fromOffset(math.floor(r.X + 0.5), math.floor(r.Y + 0.5))
	end
end)()

----------------------------------------------------------------------
-- The event's music (2026-09-26, owner, v2): "Eggman's Revenge" loops for the whole event, fading in at the
-- start and out at the end, ducked under his voice lines. Its own SoundGroup (the MUSIC slider and mute, not
-- the SFX group); the lobby playlist (Audio/BackgroundMusic) fades out meanwhile through the attribute
-- Fx.Music.SilenceAttribute on its Sound and comes back after.
----------------------------------------------------------------------
local Music = {} :: any
;(function() -- (a function, not a do-block: see the note at the top)
	local sound: Sound? = nil
	local group: SoundGroup? = nil
	local level = 0
	local duck = 1
	local want = false
	local ducked = false
	local connection: RBXScriptConnection? = nil

	local function lobbyMusic(): Instance?
		return SoundService:FindFirstChild("SpeedsterBackgroundMusic")
	end

	local function volumeNow(): number
		if player:GetAttribute("Muted") == true or Workspace:GetAttribute("AdminMusicActive") == true then
			return 0
		end
		local slider = tonumber(player:GetAttribute("MusicVolume"))
		local k = if slider then math.clamp(math.floor(slider), 0, 100) / 100 else 1
		return Fx.Music.Volume * k
	end

	local function finish()
		if connection then
			connection:Disconnect()
			connection = nil
		end
		if sound then
			sound:Stop()
			sound:Destroy()
			sound = nil
		end
		if group then
			group:Destroy()
			group = nil
		end
		local lobby = lobbyMusic()
		if lobby then
			lobby:SetAttribute(Fx.Music.SilenceAttribute, nil)
		end
		level, duck = 0, 1
	end

	local function step(dt: number)
		local m = Fx.Music
		if want then
			level = math.min(1, level + dt / m.FadeIn)
		else
			level = math.max(0, level - dt / m.FadeOut)
		end
		local goal = if ducked then m.Duck else 1
		local rate = dt / m.DuckSeconds
		duck = if duck < goal then math.min(goal, duck + rate) else math.max(goal, duck - rate)
		if sound then
			sound.Volume = volumeNow() * level * duck
		end
		if not want and level <= 0 then
			finish()
		end
	end

	-- The music starts (fading in); `instant` (a player who joins mid-event) skips nothing but the wait.
	function Music.Start()
		want = true
		if not sound then
			local newGroup = Instance.new("SoundGroup")
			newGroup.Name = Fx.Music.GroupName
			newGroup.Volume = 1
			newGroup.Parent = SoundService
			group = newGroup
			local made = Instance.new("Sound")
			made.Name = Fx.Music.SoundName
			made.SoundId = Fx.Music.Id
			made.Looped = true
			made.Volume = 0
			made.SoundGroup = newGroup -- (set before it is parented: the SFX router leaves it alone)
			made.Parent = SoundService
			sound = made
			made:Play()
		end
		local lobby = lobbyMusic()
		if lobby then
			lobby:SetAttribute(Fx.Music.SilenceAttribute, true)
		end
		if not connection then
			connection = RunService.RenderStepped:Connect(step)
		end
	end

	-- The music fades out and stops (`instant`: now, the kill switch).
	function Music.Stop(instant: boolean?)
		want = false
		ducked = false
		if instant then
			finish()
		end
	end

	function Music.Duck(on: boolean)
		ducked = on
	end

	-- 2026-09-26 (owner, v3): "their world stays normal until they accept": the music plays while the local root
	-- is in the event (fading in / out across its edge), the lobby playlist the rest of the time.
	function Music.Want(on: boolean)
		if on then
			if not want or not sound then
				Music.Start()
			end
		elseif want then
			Music.Stop(false)
		end
	end
end)()

----------------------------------------------------------------------
-- The screen (2026-09-26, owner, v2): one ScreenGui the cinematics keep on screen (Fx.ScreenGuiName: the
-- letterbox bars, Eggman's dialogue, the charge ring) and the golden vignette's (under the HUD).
-- 2026-09-26 (owner, v3) "the dialogue must be SIMPLE and basic": plain typewriter text (white, the game's navy
-- outline) beside a SMALL round portrait of his face (a ViewportFrame of the boss clone's head, or his emblem
-- drawn in frames), his voice clip (the music ducks under it); no box, no name tab, no banner. Laid out by
-- Dialogue.Layout (bottom centre, the phone strip under the boss bar, the letterbox band during a cinematic,
-- inside the notch insets). The charge ring has no words.
----------------------------------------------------------------------
local Screen = {} :: any
;(function() -- (a function, not a do-block: see the note at the top)
	local gui: ScreenGui? = nil
	local barTop: Frame? = nil
	local barBottom: Frame? = nil
	local holder: Frame? = nil -- the fitted strip (its UIScale fits it to the screen)
	local fitScale: UIScale? = nil
	local box: Frame? = nil -- inside it (transparent), popping (its own UIScale)
	local popScale: UIScale? = nil
	local textLabel: TextLabel? = nil
	local portrait: Frame? = nil
	local portraitStroke: UIStroke? = nil
	local viewport: ViewportFrame? = nil
	local viewCamera: Camera? = nil
	local viewModel: Model? = nil
	local viewBase = CFrame.new()
	local emblem: Frame? = nil
	local ring: Frame? = nil
	local ringSegments: { Frame } = {}
	local vignetteGui: ScreenGui? = nil
	local vignetteFrames: { { frame: Frame, layer: number } } = {}
	local fade: Frame? = nil -- (v3) the beats' black
	local fadeLevel = 0
	local talk: any = nil -- { key, text, start, hold, mood, voice, priority, typed, closing }
	local queued: any = nil -- { key, at }: a line waiting for a more important one to end
	local lastKey: { [string]: number } = {} -- when each key last played (cooldowns)
	local lastPick: string? = nil
	local layoutSignature = ""
	local design: string? = nil
	local bars = 0
	local cinematicLayout = false
	local vignetteLevel = 0

	local function make(className: string, props: { [string]: any }, parent: Instance?): any
		local instance = Instance.new(className)
		for key, value in props do
			(instance :: any)[key] = value
		end
		if parent then
			instance.Parent = parent
		end
		return instance
	end

	local function round(parent: Instance, scale: number, offset: number?)
		make("UICorner", { CornerRadius = UDim.new(scale, offset or 0) }, parent)
	end

	local function words(label: TextLabel, color: Color3, stroke: Color3, thickness: number)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextColor3 = color
		make("UIStroke", { Color = stroke, Thickness = thickness, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, LineJoinMode = Enum.LineJoinMode.Round }, label)
		TutorialText.Style(label, lang)
	end

	-- His emblem in frames (no image): a round yellow face, blue goggles, a big brown moustache.
	local function drawEmblem(parent: Instance): Frame
		local face = make("Frame", { Name = "Emblem", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55),
			Size = UDim2.fromScale(0.78, 0.78), BackgroundColor3 = Color3.fromRGB(255, 214, 150), BorderSizePixel = 0 }, parent)
		round(face, 0.5)
		for _, side in { -1, 1 } do
			local goggle = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5 + side * 0.2, 0.36),
				Size = UDim2.fromScale(0.3, 0.3), BackgroundColor3 = Color3.fromRGB(70, 150, 255), BorderSizePixel = 0 }, face)
			round(goggle, 0.5)
			make("UIStroke", { Color = Color3.fromRGB(30, 30, 40), Thickness = 1.5 }, goggle)
			local tash = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5 + side * 0.2, 0.7),
				Size = UDim2.fromScale(0.44, 0.16), Rotation = side * 14, BackgroundColor3 = Color3.fromRGB(150, 70, 20), BorderSizePixel = 0 }, face)
			round(tash, 0.5)
		end
		local nose = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.56),
			Size = UDim2.fromScale(0.2, 0.2), BackgroundColor3 = Color3.fromRGB(255, 170, 130), BorderSizePixel = 0 }, face)
		round(nose, 0.5)
		return face
	end

	function Screen.Build()
		if gui and gui.Parent then
			return
		end
		local screen = make("ScreenGui", { Name = Fx.ScreenGuiName, ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 40,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Enabled = true })
		gui = screen
		barTop = make("Frame", { Name = "BarTop", BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Size = UDim2.fromScale(1, 0), ZIndex = 50 }, screen)
		barBottom = make("Frame", { Name = "BarBottom", BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0), ZIndex = 50 }, screen)
		-- 2026-09-26 (owner, v3): the beats' fade to black (the trips to the race map and back), over everything.
		fade = make("Frame", { Name = "Fade", BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1, Visible = false, ZIndex = 80 }, screen)
		fadeLevel = 0
		-- The dialogue: a transparent strip, the small round portrait and the text.
		local h = make("Frame", { Name = "Dialogue", BackgroundTransparency = 1, Visible = false, ZIndex = 60 }, screen)
		holder = h
		fitScale = make("UIScale", { Name = "Fit" }, h)
		local b = make("Frame", { Name = "Box", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 60 }, h)
		box = b
		popScale = make("UIScale", { Name = "Pop" }, b)
		local p = make("Frame", { Name = "Portrait", BackgroundColor3 = rgb(Fx.Style.Plate), BorderSizePixel = 0, ZIndex = 61, ClipsDescendants = true }, b)
		portrait = p
		round(p, 0.5)
		portraitStroke = make("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, p)
		local v = make("ViewportFrame", { Name = "Head", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 62,
			Ambient = Color3.fromRGB(200, 180, 170), LightColor = Color3.fromRGB(255, 240, 220), LightDirection = Vector3.new(-0.4, -0.6, -1) }, p)
		round(v, 0.5)
		viewport = v
		local cam = make("Camera", { FieldOfView = 30 }, v)
		v.CurrentCamera = cam
		viewCamera = cam
		emblem = drawEmblem(p)
		local tl = make("TextLabel", { Name = "Text", Text = "", TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 61 }, b)
		words(tl, Color3.fromRGB(255, 252, 245), rgb(Fx.Style.Ink), 2)
		textLabel = tl
		-- The charge ring (hidden until a charge; no words).
		local r = make("Frame", { Name = "ChargeRing", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Visible = false, ZIndex = 55 }, screen)
		ring = r
		table.clear(ringSegments)
		for k = 1, Fx.Charge.RingSegments do
			local a = (k - 1) / Fx.Charge.RingSegments * TAU
			local seg = make("Frame", { Name = "Segment", AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5 + 0.5 * math.sin(a), 0.5 - 0.5 * math.cos(a)), Size = UDim2.fromOffset(6, 12),
				Rotation = math.deg(a), BackgroundColor3 = Color3.fromRGB(60, 50, 40), BackgroundTransparency = 0.35, BorderSizePixel = 0, ZIndex = 56 }, r)
			round(seg, 0.5)
			table.insert(ringSegments, seg)
		end
		screen.Parent = playerGui
		-- The golden vignette (its own ScreenGui, under the HUD: the interface stays on top of it).
		local vg = make("ScreenGui", { Name = Fx.VignetteGuiName, ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 5,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Enabled = false })
		vignetteGui = vg
		table.clear(vignetteFrames)
		local gold = rgb(Fx.Vignette.Color)
		for layer = 1, #Fx.Vignette.Layers do
			for side = 1, 4 do
				local frame = make("Frame", { Name = "Edge" .. layer .. "_" .. side, BackgroundColor3 = gold, BorderSizePixel = 0,
					BackgroundTransparency = 1, ZIndex = layer }, vg)
				-- The glow at the screen's edge, fading inward (the frame's BackgroundTransparency sets the level).
				make("UIGradient", { Rotation = ({ 90, -90, 0, 180 })[side], Color = ColorSequence.new(rgb(Fx.Vignette.Hot), gold),
					Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.55, 0.7), NumberSequenceKeypoint.new(1, 1) }) }, frame)
				table.insert(vignetteFrames, { frame = frame, layer = layer, side = side } :: any)
			end
		end
		vg.Parent = playerGui
		layoutSignature = ""
		design = nil
	end

	function Screen.Destroy()
		if talk and talk.voice then
			talk.voice:Stop()
		end
		talk = nil
		queued = nil
		Music.Duck(false)
		if gui then
			gui:Destroy()
		end
		if vignetteGui then
			vignetteGui:Destroy()
		end
		gui, barTop, barBottom, holder, fitScale, box, popScale, textLabel, fade = nil, nil, nil, nil, nil, nil, nil, nil, nil
		fadeLevel = 0
		portrait, portraitStroke, viewport, viewCamera, viewModel, emblem, ring, vignetteGui = nil, nil, nil, nil, nil, nil, nil, nil
		table.clear(ringSegments)
		table.clear(vignetteFrames)
		layoutSignature = ""
		design = nil
		bars = 0
		vignetteLevel = 0
	end

	function Screen.Gui(): ScreenGui?
		return gui
	end

	-- The portrait: a clone of the boss's head (and what sits on it: the hat, the goggles, the moustache) in the
	-- ViewportFrame, looked at from the front; his emblem when there is no head to show.
	function Screen.SetPortrait(model: Model?)
		if viewModel then
			viewModel:Destroy()
			viewModel = nil
		end
		local head = model and model:FindFirstChild("Head")
		if not (viewport and head and head:IsA("BasePart")) then
			if emblem then
				emblem.Visible = true
			end
			return
		end
		local headPart = head :: BasePart
		local copy = Instance.new("Model")
		copy.Name = "PortraitHead"
		local inverse = headPart.CFrame:Inverse()
		local reach = math.max(headPart.Size.X, headPart.Size.Y, headPart.Size.Z) * 1.6
		local ship = (model :: Model):FindFirstChild(EggMobile.ModelName)
		for _, d in (model :: Model):GetDescendants() do
			-- The head, what sits on it and his shoulders (a bust), never the ship's pieces.
			local near = d:IsA("BasePart") and d.Transparency < 1 and (d == headPart
				or ((d.Position - headPart.Position).Magnitude <= reach and not (ship and d:IsDescendantOf(ship))))
			if near then
				local archivable = d.Archivable
				d.Archivable = true
				local ok, piece = pcall(function()
					return d:Clone()
				end)
				d.Archivable = archivable
				if ok and piece then
					for _, child in piece:GetChildren() do
						if not (child:IsA("DataModelMesh") or child:IsA("Decal") or child:IsA("SurfaceAppearance")) then
							child:Destroy()
						end
					end
					piece.Anchored = true
					piece.CFrame = inverse * d.CFrame
					piece.Parent = copy
				end
			end
		end
		copy.Parent = viewport
		viewModel = copy
		local size = headPart.Size.Y
		-- (his face fills the small circle)
		viewBase = Cine.LookAt(Vector3.new(size * 0.35, size * 0.3, -size * 2.5), Vector3.new(0, size * 0.05, 0), CFrame)
		if viewCamera then
			viewCamera.CFrame = viewBase
		end
		if emblem then
			emblem.Visible = false
		end
	end

	-- The layout for this screen and mode (again when the size or the mode changes).
	local function applyLayout(force: boolean?)
		local h, b = holder, box
		if not (gui and h and b) then
			return
		end
		local camera = Workspace.CurrentCamera
		local view = if camera then camera.ViewportSize else Vector2.new(1280, 720)
		local topBar = (GuiService:GetGuiInset()).Y
		local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
		local cinematic = Cinema.active ~= nil
		local signature = ("%d:%d:%d:%s:%s"):format(view.X, view.Y, topBar, tostring(touch), tostring(cinematic))
		if signature == layoutSignature and not force then
			return
		end
		layoutSignature = signature
		local main = playerGui:FindFirstChild("Mainhud")
		local hudInset = not (main and main:IsA("ScreenGui") and main.IgnoreGuiInset)
		local l = Dialogue.Layout(view.X, view.Y, { topBar = topBar, touch = touch, cinematic = cinematic, hudInset = hudInset })
		local d = Dialogue.Designs[l.Design]
		h.Position = UDim2.fromOffset(l.Left, l.Top)
		h.Size = UDim2.fromOffset(d.Width, d.Height)
		if fitScale then
			fitScale.Scale = l.Scale
		end
		if design ~= l.Design then
			design = l.Design
			local pad, size = d.Pad, d.Portrait
			if portrait then
				portrait.Position = UDim2.fromOffset(pad, math.floor((d.Height - size) / 2))
				portrait.Size = UDim2.fromOffset(size, size)
			end
			if textLabel then
				textLabel.Position = UDim2.fromOffset(pad * 3 + size, 0)
				textLabel.Size = UDim2.fromOffset(d.Width - size - pad * 4, d.Height)
				textLabel.TextSize = d.TextSize
			end
		end
		cinematicLayout = cinematic
	end

	-- Says `key` (a Dialogue line or group): the strip pops in, the text types out, his voice plays. A line never
	-- cuts a more important one short (Dialogue.Priority); `cooldown` seconds must pass since that key last
	-- played. Returns whether it plays.
	function Screen.Say(key: string, cooldown: number?): boolean
		-- (v3: a player who is not in the event keeps a normal world: no lines, no voices)
		if killed() or not state.inEvent then
			return false
		end
		local pick = Dialogue.Resolve(key, lastPick, math.floor(os.clock() * 7))
		if not pick then
			return false
		end
		local clock = os.clock()
		if cooldown and clock - (lastKey[key] or -math.huge) < cooldown then
			return false
		end
		local priority = Dialogue.PriorityOf(pick)
		if talk and not talk.closing and clock - talk.start < talk.hold and priority < talk.priority then
			-- It waits for the more important line to end (the latest one only, and not for long).
			queued = { key = key, at = clock }
			return false
		end
		queued = nil
		if not gui then
			Screen.Build()
		end
		local text = Dialogue.Line(lang, pick)
		if text == "" or not (holder and textLabel) then
			return false
		end
		lastKey[key] = clock
		lastPick = pick
		if talk and talk.voice then
			talk.voice:Stop()
		end
		local line = Dialogue.Lines[pick]
		local mood = Dialogue.Mood(pick)
		local voice = if line.Voice then playSound(line.Voice) else nil
		talk = { key = pick, text = text, start = clock, hold = Dialogue.Hold(text), mood = mood, voice = voice, priority = priority, typed = -1, closing = false }
		textLabel.Text = text
		textLabel.MaxVisibleGraphemes = 0
		if portraitStroke then
			-- (his mood, only on the portrait's thin ring)
			portraitStroke.Color = Color3.new(1, 1, 1):Lerp(rgb(mood.Tint), 0.55)
		end
		applyLayout(true)
		holder.Visible = true
		if popScale then
			popScale.Scale = 0.85
			TweenService:Create(popScale, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
		Music.Duck(voice ~= nil)
		return true
	end

	-- 2026-09-26 (owner, v3): the beats' black at `level` (0..1).
	function Screen.SetFade(level: number)
		local l = math.clamp(level, 0, 1)
		if l == fadeLevel then
			return
		end
		fadeLevel = l
		if fade then
			fade.BackgroundTransparency = 1 - l
			fade.Visible = l > 0.001
		end
	end

	function Screen.FadeLevel(): number
		return fadeLevel
	end

	-- The letterbox bars' share of the height (Cinema).
	function Screen.SetBars(share: number)
		if share == bars then
			return
		end
		bars = share
		if barTop and barBottom then
			barTop.Size = UDim2.fromScale(1, share)
			barBottom.Size = UDim2.fromScale(1, share)
		end
	end

	-- The charge ring at `level` (0..1; nil hides it), round the touch button (`around`: its absolute rect in
	-- whole-screen pixels) or under the screen's centre.
	function Screen.ChargeRing(level: number?, around: any?)
		local r = ring
		if not r then
			return
		end
		if level == nil then
			if r.Visible then
				r.Visible = false
			end
			return
		end
		local camera = Workspace.CurrentCamera
		local view = if camera then camera.ViewportSize else Vector2.new(1280, 720)
		if around then
			local d = around.Size + 28
			r.Position = UDim2.fromOffset(around.X, around.Y)
			r.Size = UDim2.fromOffset(d, d)
		else
			local d = Fx.Charge.RingSize
			r.Position = UDim2.fromOffset(view.X / 2, view.Y * 0.62)
			r.Size = UDim2.fromOffset(d, d)
		end
		r.Visible = true
		local lit = Fx.ChargeSegments(level)
		local full = level >= 1
		local hot = if full then Color3.fromRGB(255, 255, 230) else GOLD
		for index, seg in ringSegments do
			local on = index <= lit
			seg.BackgroundColor3 = if on then hot else Color3.fromRGB(60, 50, 40)
			seg.BackgroundTransparency = if on then 0 else 0.35
		end
	end

	-- The golden vignette's level (0..1): while the local player is Super.
	function Screen.Vignette(target: number, clock: number, dt: number)
		local vg = vignetteGui
		if not vg then
			return
		end
		local v = Fx.Vignette
		local step = dt / (if target > vignetteLevel then v.FadeIn else v.FadeOut)
		vignetteLevel = math.clamp(vignetteLevel + (if target > vignetteLevel then step else -step), 0, 1)
		local on = vignetteLevel > 0.001 and budget.Vignette > 0
		if vg.Enabled ~= on then
			vg.Enabled = on
		end
		if not on then
			return
		end
		local camera = Workspace.CurrentCamera
		local view = if camera then camera.ViewportSize else Vector2.new(1280, 720)
		local short = math.min(view.X, view.Y)
		for _, entry in vignetteFrames :: any do
			local frame, layer, side = entry.frame, entry.layer, entry.side
			if layer > budget.Vignette then
				frame.Visible = false
				continue
			end
			frame.Visible = true
			local depth = Fx.Vignette.Layers[layer].Depth * short
			if side == 1 then
				frame.Position, frame.Size = UDim2.fromScale(0, 0), UDim2.new(1, 0, 0, depth)
			elseif side == 2 then
				frame.Position, frame.Size = UDim2.new(0, 0, 1, -depth), UDim2.new(1, 0, 0, depth)
			elseif side == 3 then
				frame.Position, frame.Size = UDim2.fromScale(0, 0), UDim2.new(0, depth, 1, 0)
			else
				frame.Position, frame.Size = UDim2.new(1, -depth, 0, 0), UDim2.new(0, depth, 1, 0)
			end
			frame.BackgroundTransparency = Fx.VignetteEdge(layer, vignetteLevel, clock)
		end
	end

	-- Every frame: the typewriter, the portrait talking, the strip's pop-out, the layout.
	function Screen.Update(clock: number)
		applyLayout(Cinema.active ~= nil ~= cinematicLayout)
		local t = talk
		if not t and queued then
			local waiting = queued
			queued = nil
			if clock - waiting.at < 3 then
				Screen.Say(waiting.key)
			end
			t = talk
		end
		if not (t and holder and textLabel) then
			return
		end
		local age = clock - t.start
		local typed = Dialogue.Typed(t.text, age)
		if typed ~= t.typed then
			t.typed = typed
			textLabel.MaxVisibleGraphemes = typed
		end
		-- The portrait bobbing while he talks (the only motion: no box to shake).
		if portrait then
			local talking = typed < Dialogue.Graphemes(t.text)
			portrait.Rotation = if talking then math.sin(clock * 18) * 4 else 0
		end
		if viewCamera and viewModel then
			viewCamera.CFrame = viewBase * CFrame.Angles(0, math.sin(clock * 3) * 0.06, math.sin(clock * 7) * 0.02 * (if typed < 999 then 1 else 0))
		end
		if t.voice and not t.voice.IsPlaying and age > 0.2 then
			t.voice = nil
			Music.Duck(false)
		end
		if not t.closing and age >= t.hold then
			t.closing = true
			if popScale then
				TweenService:Create(popScale, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.85 }):Play()
			end
		end
		if t.closing and age >= t.hold + 0.18 then
			holder.Visible = false
			if t.voice then
				t.voice = nil
			end
			Music.Duck(false)
			talk = nil
		end
	end

	-- Whether a line is showing (the cinematics wait for their last line).
	function Screen.Talking(): boolean
		return talk ~= nil
	end

	-- 2026-09-26 (owner, v3): silence: the line on screen closes now (its voice stops), nothing waits (the Defeat
	-- has no dialogue).
	function Screen.Hush()
		queued = nil
		local t = talk
		if not t then
			return
		end
		if t.voice then
			t.voice:Stop()
			t.voice = nil
		end
		talk = nil
		Music.Duck(false)
		if holder then
			holder.Visible = false
		end
	end
end)()

----------------------------------------------------------------------
-- Bombs. 2026-09-26 (owner, v2): the missile visibly leaves the cannon's mouth (Fx.BombPosition: out along the
-- barrel, blended into SSE.BombArc), flies nose first along its velocity with a smoke trail (a Beam) and, on the
-- Full tier, the imported FireTrail flames; the nearest one threatening the player whistles as it falls. Its RED
-- WARNING ZONE is exactly the blast (the message's radius) from the launch to the impact: a bright red ring
-- pulsing faster and faster, a fill closing in quickly, a closing ring, an alarm ticking higher near the impact;
-- it fades out smoothly after the blast. Everything pooled.
----------------------------------------------------------------------
local onBomb, onBombHit, updateBombs, destroyBombs
;(function() -- (a function, not a do-block: see the note at the top)
	type BombVisual = {
		root: BasePart, instance: Instance, offset: CFrame, tail: BasePart, beam: Beam, flames: { ParticleEmitter },
	}
	type Zone = {
		part: BasePart, disc: BasePart, ring: UIStroke, fill: Frame, close: Frame, closeStroke: UIStroke, radius: number,
	}
	type Bomb = {
		id: any, from: Vector3, to: Vector3, launch: number, flight: number, visual: BombVisual?, zone: Zone?, spin: number,
		dir: Vector3?, depth: number, pattern: string?, radius: number,
	}
	local bombs: { [any]: Bomb } = {}
	local exploded: { [any]: number } = {}
	local bombPool: { BombVisual } = {}
	local zonePool: { Zone } = {}
	local fading: { { zone: Zone, start: number } } = {}
	local lastSalvoAt = -math.huge
	local lastMuzzleAt = -math.huge
	local whistle: { id: any, sound: Sound }? = nil
	local alarmNext = 0
	local RED = rgb(Fx.Warning.Color)
	local HOT = rgb(Fx.Warning.Hot)
	local SMOKE = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 170, 60)),
		ColorSequenceKeypoint.new(0.35, Color3.fromRGB(150, 110, 90)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(70, 66, 64)),
	})

	local function makeBombVisual(): BombVisual
		local root, instance, offset = nil, nil, CFrame.new()
		local template = meshTemplate(Fx.MeshNames.Bomb)
		if template then
			local r, clone, o = fitClone(template, Fx.Bomb.Size, "Largest")
			if r and clone then
				clone.Name = "SSE_Bomb"
				root, instance, offset = r, clone, o
			end
		end
		if not (root and instance) then
			local body = newPart("SSE_Bomb", Vector3.new(Fx.Bomb.Size, Fx.Bomb.Size, Fx.Bomb.Size), Color3.fromRGB(40, 42, 50), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
			body.Reflectance = 0.2
			body.CastShadow = true
			local band = newPart("SSE_BombBand", Vector3.new(0.55, Fx.Bomb.Size * 1.04, Fx.Bomb.Size * 1.04), Color3.fromRGB(255, 196, 30), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
			band.CFrame = body.CFrame * CFrame.Angles(0, 0, math.pi / 2)
			band.Anchored = false
			holdTo(body, band)
			band.Parent = body
			root, instance = body, body
		end
		local bombRoot = root :: BasePart
		-- The trail: a Beam from the bomb to a point behind it on its path (the owner's speed-trail texture, in
		-- fire-to-smoke colours).
		local head = Instance.new("Attachment")
		head.Name = "SSE_TrailHead"
		head.Parent = bombRoot
		local tail = newPart("SSE_BombTail", Vector3.new(0.2, 0.2, 0.2), GOLD, Enum.Material.SmoothPlastic)
		tail.Transparency = 1
		local tailAttachment = Instance.new("Attachment")
		tailAttachment.Name = "SSE_TrailTail"
		tailAttachment.Parent = tail
		local beam = Instance.new("Beam")
		beam.Name = "SSE_BombTrail"
		beam.Attachment0 = head
		beam.Attachment1 = tailAttachment
		beam.Texture = Fx.Textures.SpeedTrail
		beam.TextureMode = Enum.TextureMode.Stretch
		beam.Color = SMOKE
		beam.LightEmission = 0.4
		beam.LightInfluence = 0.3
		beam.Transparency = sequence({ { 0, 0.15 }, { 0.6, 0.55 }, { 1, 1 } })
		beam.Width0 = Fx.Bomb.TrailWidth
		beam.Width1 = Fx.Bomb.TrailWidth * 2.2
		beam.FaceCamera = true
		beam.Segments = 6
		beam.Enabled = false
		beam.Parent = tail
		-- The flames (Full tier): the imported FireTrail's emitters on the bomb, leaving their particles behind.
		local flames = {}
		local fire = vfxTemplate(SSE.VfxNames.FireTrail)
		if fire then
			for _, d in fire:GetDescendants() do
				if d:IsA("ParticleEmitter") then
					local clone = d:Clone()
					clone.Enabled = false
					clone.LockedToPart = false
					clone.Parent = head
					table.insert(flames, clone)
				end
			end
		end
		return { root = bombRoot, instance = instance :: Instance, offset = offset, tail = tail, beam = beam, flames = flames }
	end

	-- The red zone: a flat part carrying a SurfaceGui (the ring, the fill, the closing ring: crisp from above and
	-- on phones, no texture) over a Neon disc of the blast's size.
	local function makeZone(): Zone
		local w = Fx.Warning
		local part = newPart("SSE_Warning", Vector3.new(1, 0.1, 1), RED, Enum.Material.SmoothPlastic)
		part.Transparency = 1
		local surface = Instance.new("SurfaceGui")
		surface.Name = "SSE_Zone"
		surface.Face = Enum.NormalId.Top
		surface.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		surface.CanvasSize = Vector2.new(w.Canvas, w.Canvas)
		surface.LightInfluence = 0
		pcall(function()
			surface.Brightness = 2.5
		end)
		surface.Adornee = part
		surface.Parent = part
		local share = 1 / w.Span
		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.AnchorPoint = Vector2.new(0.5, 0.5)
		fill.Position = UDim2.fromScale(0.5, 0.5)
		fill.Size = UDim2.fromScale(0, 0)
		fill.BackgroundColor3 = RED
		fill.BackgroundTransparency = 0.6
		fill.BorderSizePixel = 0
		fill.Parent = surface
		local fillCorner = Instance.new("UICorner")
		fillCorner.CornerRadius = UDim.new(0.5, 0)
		fillCorner.Parent = fill
		local ringFrame = Instance.new("Frame")
		ringFrame.Name = "Ring"
		ringFrame.AnchorPoint = Vector2.new(0.5, 0.5)
		ringFrame.Position = UDim2.fromScale(0.5, 0.5)
		ringFrame.Size = UDim2.fromScale(share, share)
		ringFrame.BackgroundTransparency = 1
		ringFrame.Parent = surface
		local ringCorner = Instance.new("UICorner")
		ringCorner.CornerRadius = UDim.new(0.5, 0)
		ringCorner.Parent = ringFrame
		local ring = Instance.new("UIStroke")
		ring.Color = RED
		ring.Thickness = w.RingThickness
		ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		ring.Parent = ringFrame
		local close = Instance.new("Frame")
		close.Name = "Closing"
		close.AnchorPoint = Vector2.new(0.5, 0.5)
		close.Position = UDim2.fromScale(0.5, 0.5)
		close.Size = UDim2.fromScale(1, 1)
		close.BackgroundTransparency = 1
		close.Parent = surface
		local closeCorner = Instance.new("UICorner")
		closeCorner.CornerRadius = UDim.new(0.5, 0)
		closeCorner.Parent = close
		local closeStroke = Instance.new("UIStroke")
		closeStroke.Color = HOT
		closeStroke.Thickness = math.max(3, w.RingThickness * 0.5)
		closeStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		closeStroke.Parent = close
		local disc = newPart("SSE_WarningDisc", Vector3.new(0.08, 1, 1), RED, Enum.Material.Neon, Enum.PartType.Cylinder)
		disc.Transparency = w.DiscTransparency
		return { part = part, disc = disc, ring = ring, fill = fill, close = close, closeStroke = closeStroke, radius = 0 }
	end

	local function placeZone(zone: Zone, at: Vector3, radius: number)
		local w = Fx.Warning
		local span = radius * 2 * w.Span
		zone.radius = radius
		zone.part.Size = Vector3.new(span, 0.1, span)
		zone.part.CFrame = CFrame.new(at + Vector3.new(0, Fx.Bomb.WarningRise + 0.05, 0))
		zone.disc.Size = Vector3.new(0.08, radius * 2, radius * 2)
		zone.disc.CFrame = CFrame.new(at + Vector3.new(0, Fx.Bomb.WarningRise, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		zone.disc.Transparency = w.DiscTransparency
		zone.ring.Transparency = 0
		zone.ring.Color = RED
		zone.fill.Size = UDim2.fromScale(0, 0)
		zone.fill.BackgroundTransparency = 0.6
		zone.close.Size = UDim2.fromScale(1, 1)
		zone.closeStroke.Transparency = 0.2
		zone.close.Visible = budget.WarningClose
		zone.part.Parent = runtimeFolder()
		zone.disc.Parent = runtimeFolder()
	end

	local function releaseZone(zone: Zone)
		zone.part.Parent = nil
		zone.disc.Parent = nil
		table.insert(zonePool, zone)
	end

	local function releaseBomb(bomb: Bomb)
		if bomb.visual then
			local visual = bomb.visual
			visual.beam.Enabled = false
			for _, flame in visual.flames do
				flame.Enabled = false
			end
			visual.instance.Parent = nil
			visual.tail.Parent = nil
			table.insert(bombPool, visual)
			bomb.visual = nil
		end
		if bomb.zone then
			-- The zone fades out after the blast (updateBombs), then goes back to the pool.
			table.insert(fading, { zone = bomb.zone, start = os.clock() })
			bomb.zone = nil
		end
		if whistle and whistle.id == bomb.id then
			whistle.sound:Stop()
			whistle = nil
		end
	end

	local function explode(bomb: Bomb?, position: Vector3)
		if bomb then
			releaseBomb(bomb)
			bombs[bomb.id] = nil
			exploded[bomb.id] = os.clock()
		end
		fireRig("Blast", CFrame.new(position + Vector3.new(0, 0.6, 0)))
		burnAt(position, budget.FirePatches)
		local d = distanceFromCamera(position)
		playSound("BombBlast", d)
		local _, _, root = localCharacter()
		local shake, strength, fov = Fx.BombPunch(if root then (root.Position - position).Magnitude else d)
		if shake then
			CameraPunch.Shake(shake, strength :: number)
			CameraPunch.Fov(fov :: number)
		end
	end

	-- { "Bomb", id, from, to, launchTime, flightTime, pattern, radius }
	function onBomb(id: any, from: any, to: any, launch: any, flight: any, pattern: any, radius: any)
		if typeof(from) ~= "Vector3" or typeof(to) ~= "Vector3" or id == nil or bombs[id] or exploded[id] then
			return
		end
		local launchTime = tonumber(launch) or serverNow()
		local seconds = math.max(0.1, tonumber(flight) or SSE.BombFlightTime(from, to, state.phase == PHASE.Battle))
		local blast = tonumber(radius) or (SSE.Warning and SSE.Warning.Radius) or SSE.Bombard.BlastRadius
		-- The barrel's direction as it fires (the drawn cannon), so the missile slides out of its mouth.
		local dir, depth = nil, 0
		if boss.model and not boss.gone then
			dir = muzzleFrame().LookVector
			depth = Fx.Bomb.BarrelDepth * boss.scale
		end
		local bomb: Bomb = { id = id, from = from, to = to, launch = launchTime, flight = seconds, visual = nil, zone = nil,
			spin = math.random() * TAU, dir = dir, depth = depth, pattern = if type(pattern) == "string" then pattern else nil, radius = blast }
		local visual = table.remove(bombPool) or makeBombVisual()
		visual.root.CFrame = CFrame.new(Fx.BombPosition(from, to, 0, seconds, dir, depth)) * visual.offset
		visual.tail.CFrame = CFrame.new(from)
		visual.instance.Parent = runtimeFolder()
		visual.tail.Parent = runtimeFolder()
		visual.beam.Enabled = budget.BombTrail ~= "None"
		for _, flame in visual.flames do
			flame.Enabled = budget.BombTrail == "Full"
		end
		bomb.visual = visual
		if budget.Rings then
			local zone = table.remove(zonePool) or makeZone()
			placeZone(zone, to, blast)
			bomb.zone = zone
		end
		bombs[id] = bomb
		-- The blast of every bomb in the air, ready before it lands (the frame loop never builds).
		local inAir = 0
		for _ in bombs do
			inAir += 1
		end
		prewarmRigs("Blast", inAir)
		prewarmFires(inAir * budget.FirePatches)
		local clock = os.clock()
		if clock - lastSalvoAt > 1.2 then
			-- A new salvo: he points at the player and laughs as it goes; a Parallel line is announced.
			bossGesture("Point")
			if bomb.pattern == SSE.BombPatterns.Parallel then
				Screen.Say("EggmanParallel", 4)
			end
		end
		lastSalvoAt = clock
		-- The shot: the cannon kicks, the ship jolts, the white muzzle flash (at most every 0.12 s).
		if clock - lastMuzzleAt > 0.12 then
			lastMuzzleAt = clock
			cannonShot()
		end
		playSound("BombLaunch", distanceFromCamera(from))
		-- The fall's whistle: the one bomb aimed nearest the local player.
		local _, _, root = localCharacter()
		if budget.Whistle and not whistle and root and (Vector3.new(to.X - root.Position.X, 0, to.Z - root.Position.Z)).Magnitude < Fx.Bomb.WhistleNear then
			local sound = playSound("BombWhistle", nil, Fx.WhistlePitch(0))
			if sound then
				whistle = { id = id, sound = sound }
			end
		end
	end

	function onBombHit(id: any, position: any)
		local bomb = bombs[id]
		if bomb then
			explode(bomb, if typeof(position) == "Vector3" then position else bomb.to)
		elseif typeof(position) == "Vector3" and not exploded[id] then
			exploded[id] = os.clock()
			prewarmRigs("Blast", 1)
			prewarmFires(budget.FirePatches)
			explode(nil, position)
		end
	end

	local function updateZone(zone: Zone, t: number, flight: number)
		local pulse, fill, close, heat = Fx.WarningLook(t, flight)
		local share = 1 / Fx.Warning.Span
		zone.ring.Transparency = 0.35 * (1 - pulse)
		zone.ring.Color = RED:Lerp(HOT, heat * pulse)
		zone.fill.Size = UDim2.fromScale(share * fill, share * fill)
		zone.fill.BackgroundTransparency = 0.62 - 0.22 * pulse * (0.4 + 0.6 * heat)
		if budget.WarningClose then
			zone.close.Size = UDim2.fromScale(close, close)
		end
		zone.disc.Transparency = Fx.Warning.DiscTransparency - 0.12 * pulse
	end

	function updateBombs(now: number, clock: number)
		local _, _, root = localCharacter()
		local threat = -1 -- the most advanced bomb aimed at the local player (the alarm)
		for _, bomb in bombs do
			local t = (now - bomb.launch) / bomb.flight
			if t >= 1 then
				explode(bomb, bomb.to) -- on the server clock: "BombHit" arrives a moment later and is ignored
				continue
			end
			local s = math.max(t, 0)
			local visual = bomb.visual
			if visual then
				local pos = Fx.BombPosition(bomb.from, bomb.to, s, bomb.flight, bomb.dir, bomb.depth)
				local ahead = Fx.BombPosition(bomb.from, bomb.to, math.min(s + 0.02, 1), bomb.flight, bomb.dir, bomb.depth)
				local spin = bomb.spin + (now - bomb.launch) * Fx.Bomb.SpinSpeed
				local wobble = math.rad(Fx.Bomb.Wobble) * math.sin((now - bomb.launch) * 13 + bomb.spin)
				-- Nose first (the model's -Y along its velocity), spinning about it and wobbling a little.
				local frame = Fx.FrameAlong(pos, ahead - pos) * CFrame.Angles(math.pi / 2 + wobble, 0, 0) * CFrame.Angles(0, spin, 0)
				visual.root.CFrame = frame * visual.offset
				visual.tail.CFrame = CFrame.new(Fx.BombPosition(bomb.from, bomb.to, math.max(0, s - Fx.Bomb.TrailLag), bomb.flight, bomb.dir, bomb.depth))
			end
			if bomb.zone then
				updateZone(bomb.zone, s, bomb.flight)
			end
			if root then
				local dx, dz = bomb.to.X - root.Position.X, bomb.to.Z - root.Position.Z
				if dx * dx + dz * dz <= (bomb.radius + Fx.Warning.TickNear) ^ 2 and s > threat then
					threat = s
				end
			end
			if whistle and whistle.id == bomb.id then
				whistle.sound.PlaybackSpeed = (Fx.Sounds.BombWhistle.Speed or 1) * Fx.WhistlePitch(s)
			end
		end
		-- The alarm: faster and higher as the nearest threat falls.
		if threat >= 0 then
			local interval, pitch = Fx.AlarmTick(threat)
			if interval and clock >= alarmNext then
				alarmNext = clock + interval
				playSound("AlarmTick", nil, pitch)
			end
		end
		-- The zones of the bombs that landed fade out.
		for index = #fading, 1, -1 do
			local entry = fading[index]
			local k = (clock - entry.start) / Fx.Warning.FadeSeconds
			local zone = entry.zone
			if k >= 1 then
				table.remove(fading, index)
				releaseZone(zone)
			else
				zone.ring.Transparency = k
				zone.closeStroke.Transparency = 0.2 + 0.8 * k
				zone.fill.BackgroundTransparency = 0.45 + 0.55 * k
				zone.disc.Transparency = Fx.Warning.DiscTransparency + (1 - Fx.Warning.DiscTransparency) * k
			end
		end
		for id, at in exploded do
			if clock - at > 15 then
				exploded[id] = nil
			end
		end
	end

	function destroyBombs()
		for _, bomb in bombs do
			releaseBomb(bomb)
		end
		table.clear(bombs)
		table.clear(exploded)
		for _, entry in fading do
			releaseZone(entry.zone)
		end
		table.clear(fading)
		for _, visual in bombPool do
			visual.instance:Destroy()
			visual.tail:Destroy()
		end
		table.clear(bombPool)
		for _, zone in zonePool do
			zone.part:Destroy()
			zone.disc:Destroy()
		end
		table.clear(zonePool)
		if whistle then
			whistle.sound:Stop()
			whistle = nil
		end
	end
end)()

----------------------------------------------------------------------
-- The Chaos Emeralds
----------------------------------------------------------------------
local emeraldSets, lastAbsorbAt, releaseSet, characterRoot, refreshEmeraldSets, updateEmeralds, destroyEmeralds
;(function() -- (a function, not a do-block: see the note at the top)
	type Gem = {
		root: BasePart, instance: Instance, offset: CFrame, parts: { BasePart }, light: PointLight,
		-- 2026-09-26 (owner, v2): its colour's glow and embers (BurstHatch's, tinted) and a short coloured trail.
		glow: { ParticleEmitter }, embers: { ParticleEmitter }, trail: Trail,
	}
	type EmeraldSet = { player: Player, character: Model, gems: { Gem }, own: boolean }
	local gemPool: { Gem } = {}
	emeraldSets = {}
	lastAbsorbAt = -math.huge

	local function makeGem(): Gem
		local e = Fx.Emerald
		local template = meshTemplate(Fx.MeshNames.ChaosEmerald)
		local root, instance, offset = nil, nil, CFrame.new()
		if template then
			-- Scaled uniformly by its height (the kit's gem is 1.6 x 1.5 x 1.6: never squashed).
			root, instance, offset = fitClone(template, e.Size[2], "Height")
		end
		if not (root and instance) then
			local part = newPart("SSE_Emerald", Vector3.new(e.Size[1], e.Size[2], e.Size[3]) * 0.8, GOLD, Enum.Material.Neon)
			root, instance, offset = part, part, CFrame.Angles(0, math.pi / 4, math.pi / 4)
		end
		local gemRoot = root :: BasePart
		-- 2026-09-26 (owner): PointLights, Range 14, Brightness 2.5, in the gem's colour (on only where the
		-- tier allows).
		local light = newLight(gemRoot, e.LightRange, e.LightBrightness, GOLD)
		light.Name = "SSE_EmeraldLight"
		-- 2026-09-26 (owner, v2): a soft glow and embers in the gem's colour (the imported BurstHatch halo and
		-- embers, sized for a gem: no default texture), and a short trail while it orbits and converges.
		local attachment = Instance.new("Attachment")
		attachment.Name = "SSE_GemFx"
		attachment.Parent = gemRoot
		local glow, embers = {}, {}
		local hatch = vfxTemplate(SSE.VfxNames.BurstHatch)
		local g = Fx.GemVfx
		if hatch then
			for _, d in hatch:GetDescendants() do
				if d:IsA("ParticleEmitter") then
					local isGlow = Fx.EmitterAllowed(SSE.VfxNames.BurstHatch, d.Name, "GemGlow")
					local isEmber = Fx.EmitterAllowed(SSE.VfxNames.BurstHatch, d.Name, "GemEmbers")
					if (isGlow and #glow == 0) or (isEmber and #embers == 0) then
						local clone = d:Clone()
						clone.Enabled = false
						local keys = {}
						for _, key in clone.Size.Keypoints do
							table.insert(keys, NumberSequenceKeypoint.new(key.Time, key.Value * (if isGlow then g.GlowSizeScale else g.EmberSizeScale)))
						end
						clone.Size = NumberSequence.new(keys)
						if isGlow then
							clone.Rate = g.GlowRate
							clone.Lifetime = NumberRange.new(g.GlowLife[1], g.GlowLife[2])
							clone.LockedToPart = true
							table.insert(glow, clone)
						else
							clone.Rate = g.EmberRate
							clone.Speed = NumberRange.new(g.EmberSpeed[1], g.EmberSpeed[2])
							clone.LockedToPart = false
							table.insert(embers, clone)
						end
						clone.Parent = attachment
					end
				end
			end
		end
		local a0 = Instance.new("Attachment")
		a0.Name = "SSE_TrailA"
		a0.CFrame = CFrame.new(0, e.Size[2] * 0.3, 0)
		a0.Parent = gemRoot
		local a1 = Instance.new("Attachment")
		a1.Name = "SSE_TrailB"
		a1.CFrame = CFrame.new(0, -e.Size[2] * 0.3, 0)
		a1.Parent = gemRoot
		local trail = Instance.new("Trail")
		trail.Name = "SSE_GemTrail"
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Lifetime = g.TrailLife
		trail.MinLength = 0.05
		trail.LightEmission = 1
		trail.LightInfluence = 0
		trail.FaceCamera = true
		trail.WidthScale = NumberSequence.new(1, 0.1)
		trail.Transparency = NumberSequence.new(g.TrailTransparency[1], g.TrailTransparency[2])
		trail.Enabled = false
		trail.Parent = gemRoot
		return { root = gemRoot, instance = instance :: Instance, offset = offset, parts = partsOf(instance :: Instance), light = light,
			glow = glow, embers = embers, trail = trail }
	end

	-- The gem's colour: the kit's own (its Color<Name> attributes, in its VariantOrder) when it has them,
	-- else SSE.Emeralds.Colors.
	local function emeraldColor(index: number): Color3
		local template = meshTemplate(Fx.MeshNames.ChaosEmerald)
		local order = template and template:GetAttribute("VariantOrder")
		if type(order) == "string" then
			local name = string.split(order, ",")[index]
			local value = name and (template :: Instance):GetAttribute("Color" .. name)
			if typeof(value) == "Color3" then
				return value
			end
		end
		return EMERALD_COLORS[index] or GOLD
	end

	-- `own`: the local player's gems (the glow and embers where the tier allows); others get the trail only.
	local function acquireGem(index: number, withLight: boolean, own: boolean?): Gem
		local gem = table.remove(gemPool) or makeGem()
		local color = emeraldColor(index)
		for _, part in gem.parts do
			part.Color = color
		end
		gem.light.Color = color
		gem.light.Enabled = withLight
		local tint = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.35), color)
		for _, emitter in gem.glow do
			emitter.Color = tint
			emitter.Enabled = own == true and budget.GemGlow
		end
		for _, emitter in gem.embers do
			emitter.Color = tint
			emitter.Enabled = own == true and budget.GemEmbers
		end
		gem.trail.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.5), color)
		gem.trail.Enabled = if own then budget.GemTrail else budget.OtherGemTrail
		gem.root.CFrame = FAR_AWAY
		gem.instance.Parent = runtimeFolder()
		return gem
	end

	local function releaseGem(gem: Gem)
		gem.light.Enabled = false
		for _, emitter in gem.glow do
			emitter.Enabled = false
		end
		for _, emitter in gem.embers do
			emitter.Enabled = false
		end
		gem.trail.Enabled = false
		gem.instance.Parent = nil
		table.insert(gemPool, gem)
	end

	function releaseSet(set: EmeraldSet)
		for _, gem in set.gems do
			releaseGem(gem)
		end
		table.clear(set.gems)
		emeraldSets[set.player] = nil
	end

	function characterRoot(character: Model?): BasePart?
		local root = character and character:FindFirstChild("HumanoidRootPart")
		return if root and root:IsA("BasePart") then root else nil
	end

	local function makeSet(target: Player, own: boolean)
		local character = target.Character
		if not character or emeraldSets[target] then
			return
		end
		local set: EmeraldSet = { player = target, character = character, gems = {}, own = own }
		if own or budget.OtherHitBurst then
			local sets = 1
			for _ in emeraldSets do
				sets += 1
			end
			prewarmRigs("Burst", sets)
		end
		for index = 1, SSE.Emeralds.Count do
			table.insert(set.gems, acquireGem(index, own and index <= budget.OwnLights, own))
		end
		emeraldSets[target] = set
	end

	local function eligible(target: Player): boolean
		local root = characterRoot(target.Character)
		return root ~= nil and eventArea(root.Position, false) and target:GetAttribute("RaceActive") ~= true
	end

	-- The sets for this phase: the local player's (when in the event's area) and the nearest others' (tier).
	function refreshEmeraldSets()
		if state.phase ~= PHASE.Emeralds then
			return
		end
		if Workspace:GetServerTimeNow() - state.phaseStart >= SSE.Emeralds.AbsorbAt then
			return
		end
		if not emeraldSets[player] and eligible(player) then
			makeSet(player, true)
		end
		local eye = cameraPosition()
		local ranked = {}
		for _, other in Players:GetPlayers() do
			if other ~= player then
				local root = characterRoot(other.Character)
				if root and eligible(other) then
					local d = (root.Position - eye).Magnitude
					if d <= budget.OtherEmeraldDistance then
						table.insert(ranked, { other, d })
					end
				end
			end
		end
		table.sort(ranked, function(a, b)
			return a[2] < b[2]
		end)
		local keep = {}
		for index = 1, math.min(#ranked, budget.OtherSets) do
			keep[ranked[index][1]] = true
		end
		for other, set in emeraldSets do
			if not set.own and not keep[other] then
				releaseSet(set)
			end
		end
		for other in keep do
			makeSet(other, false)
		end
	end

	local function absorb(set: EmeraldSet)
		local root = characterRoot(set.character)
		if root then
			local chest = root.Position + Vector3.new(0, Fx.Emerald.ChestY, 0)
			if set.own then
				fireRig("Burst", CFrame.new(chest))
				goldenFlash()
				playSound("Chime")
				lastAbsorbAt = os.clock()
			elseif budget.OtherHitBurst then
				fireRig("Burst", CFrame.new(chest))
			end
		end
		releaseSet(set)
	end

	function updateEmeralds(now: number)
		if next(emeraldSets) == nil then
			return
		end
		local phaseT = now - state.phaseStart
		local spin = now * Fx.Emerald.SpinSpeed
		for _, set in emeraldSets do
			local root = characterRoot(set.character)
			if not root or not set.character.Parent or state.phase ~= PHASE.Emeralds then
				releaseSet(set)
				continue
			end
			if phaseT >= SSE.Emeralds.AbsorbAt then
				absorb(set)
				continue
			end
			local centre = root.Position
			for index, gem in set.gems do
				local offset = Fx.EmeraldOffset(index, phaseT)
				if offset then
					gem.root.CFrame = CFrame.new(centre + offset) * CFrame.Angles(0, spin + index, 0.3) * gem.offset
				end
			end
		end
	end

	function destroyEmeralds()
		for _, set in emeraldSets do
			releaseSet(set)
		end
		table.clear(emeraldSets)
		for _, gem in gemPool do
			gem.instance:Destroy()
		end
		table.clear(gemPool)
	end
end)()

----------------------------------------------------------------------
-- Super Sonic looks (Shared/SuperSonicLook), for every Super player
----------------------------------------------------------------------
local looks, removeLook, refreshLook, rankLooks, refreshAllLooks, removeAllLooks
;(function() -- (a function, not a do-block: see the note at the top)
	type LookEntry = { handle: any, character: Model, level: string }
	looks = {}
	local lookRank: { [Player]: string } = {} -- the level each other player gets (the sweep ranks them)

	local function lookOptions(level: string, skin: boolean): any
		local options = {
			Gold = GOLD,
			Ruby = RUBY,
			Eyes = true,
			Texture = Fx.Textures.Lightning,
			Flipbook = Fx.Flipbooks.Lightning,
			Shells = false,
			AccessoryShells = false,
			SparkLimbs = 0,
			SparkRate = 0,
		}
		if skin then
			-- 2026-09-26 (owner, v2): the server dresses him in the game's real Super Sonic skin (SSE_Skin): none of
			-- the old gold glaze, body colour or eyes, only small lightning on the hands and feet.
			options.BodyGold = false
			options.Eyes = false
			options.SparkScale = 0.55
			options.SparkLimbs = if level == "Own" then budget.OwnSparkLimbs elseif level == "Full" then budget.OtherSparkLimbs else 0
			options.SparkRate = if level == "Own" then budget.OwnSparkRate else budget.OtherSparkRate
			return options
		end
		if level == "Own" then
			options.Shells = budget.OwnShells
			options.AccessoryShells = budget.OwnAccessoryShells
			options.SparkLimbs = budget.OwnSparkLimbs
			options.SparkRate = budget.OwnSparkRate
		elseif level == "Full" then
			options.Shells = budget.OtherShells
			options.AccessoryShells = budget.OtherShells and budget.Tier == "High"
			options.SparkLimbs = budget.OtherSparkLimbs
			options.SparkRate = budget.OtherSparkRate
		end
		return options
	end

	function removeLook(target: Player)
		local entry = looks[target]
		if entry then
			looks[target] = nil
			Look.Remove(entry.handle)
		end
	end

	-- The game's Super Sonic skin is on: the event's SSE_Skin, and the skin system's live SkinOverride still that skin
	-- (it clears at once if the player equips a skin of their own: then the old look is drawn again).
	local function wearsSkin(target: Player): boolean
		local skin = target:GetAttribute(PATTR.Skin)
		return skin ~= nil and target:GetAttribute(SKIN_OVERRIDE) == skin
	end

	function refreshLook(target: Player)
		local wants = target:GetAttribute(PATTR.Super) == true and not killed()
		local character = target.Character
		local skin = wearsSkin(target)
		local level = (if target == player then "Own" else (lookRank[target] or "Lite")) .. (if skin then "+Skin" else "")
		local entry = looks[target]
		if entry and (not wants or entry.character ~= character or entry.level ~= level or not entry.character.Parent) then
			removeLook(target)
			entry = nil
		end
		if wants and not entry and character and character.Parent and character:FindFirstChildOfClass("Humanoid") then
			local base = if target == player then "Own" else (lookRank[target] or "Lite")
			looks[target] = { handle = Look.Apply(ENV, character, lookOptions(base, skin)), character = character, level = level }
		end
	end

	-- Other players ranked by distance: the nearest get the glaze and the sparks (Fx.Tiers OtherFull).
	function rankLooks()
		local eye = cameraPosition()
		local ranked = {}
		for _, other in Players:GetPlayers() do
			if other ~= player and other:GetAttribute(PATTR.Super) == true then
				local root = characterRoot(other.Character)
				if root then
					-- A little hysteresis: one already drawn in full keeps it until clearly further away
					-- (no rebuilding a look every sweep for a player walking on the line).
					local entry = looks[other]
					local slack = if entry and string.sub(entry.level, 1, 4) == "Full" then 25 else 0
					table.insert(ranked, { other, (root.Position - eye).Magnitude - slack })
				end
			end
		end
		table.sort(ranked, function(a, b)
			return a[2] < b[2]
		end)
		table.clear(lookRank)
		for index, pair in ranked do
			lookRank[pair[1]] = if index <= budget.OtherFull and pair[2] <= budget.OtherDistance then "Full" else "Lite"
		end
	end

	function refreshAllLooks()
		rankLooks()
		for _, target in Players:GetPlayers() do
			refreshLook(target)
		end
		for target in looks do
			if target.Parent ~= Players then
				removeLook(target)
			end
		end
	end

	function removeAllLooks()
		for target in looks do
			removeLook(target)
		end
		table.clear(looks)
		table.clear(lookRank)
	end
end)()

----------------------------------------------------------------------
-- Spin balls (the local player's charge and flight, and the others')
-- 2026-09-26 (owner, v3): ONE big trail Beam wraps round the ball (Fx.Trail / Fx.TrailWrap), the owner's
-- "Beam113" texture: while charging it hugs the ball, spinning faster as the charge grows; in flight it leaves
-- the ball in a spiral and streams back to a point behind it on the path. No more swirl of small speed lines.
----------------------------------------------------------------------
type BallRig = {
	root: BasePart, instance: Instance, offset: CFrame, holder: BasePart, tail: BasePart, size: number,
	rootOffset: CFrame, -- the ball's centre from the character's root (the kit's RootOffset, negated)
	rings: ParticleEmitter?,
	trail: Beam, -- the one wrap trail
	a0: Attachment, a1: Attachment, -- on the ball (the holder), turned every frame
	tailAttachment: Attachment, -- on the tail part (the path behind the ball)
	flying: boolean, -- the trail's mode: streaming to the tail (true) or hugging the ball (false)
}

local function makeBallRig(full: boolean): BallRig
	local h = Fx.Homing
	local template = meshTemplate(Fx.MeshNames.SpinBall)
	local root, instance, offset = nil, nil, CFrame.new()
	local size, rootOffset = h.BallSize, CFrame.new()
	if template then
		-- The kit's ball at its own size (6.1 across: an R6 fits inside), in Super Sonic's gold.
		root, instance, offset = fitClone(template, nil)
		if root and instance then
			local gold = template:GetAttribute("ColorGold")
			for _, part in partsOf(instance) do
				part.Color = if typeof(gold) == "Color3" then gold else GOLD
			end
			local extent = root.Size
			size = math.max(extent.X, extent.Y, extent.Z)
			local fromRoot = template:GetAttribute("RootOffset")
			if typeof(fromRoot) == "Vector3" then
				rootOffset = CFrame.new(-fromRoot)
			end
		end
	end
	if not (root and instance) then
		local ball = newPart("SSE_SpinBall", Vector3.new(h.BallSize, h.BallSize, h.BallSize), GOLD, Enum.Material.Neon, Enum.PartType.Ball)
		ball.Transparency = 0.12
		root, instance, offset = ball, ball, CFrame.new()
	end
	local holder = newPart("SSE_BallHolder", Vector3.new(1, 1, 1), GOLD, Enum.Material.SmoothPlastic)
	holder.Transparency = 1
	local tail = newPart("SSE_BallTail", Vector3.new(1, 1, 1), GOLD, Enum.Material.SmoothPlastic)
	tail.Transparency = 1
	local head = Instance.new("Attachment")
	head.Name = "SSE_BallHead"
	head.Parent = holder
	local a0 = Instance.new("Attachment")
	a0.Name = "SSE_TrailA"
	a0.Parent = holder
	local a1 = Instance.new("Attachment")
	a1.Name = "SSE_TrailB"
	a1.Parent = holder
	local tailAttachment = Instance.new("Attachment")
	tailAttachment.Name = "SSE_BallTail"
	tailAttachment.Parent = tail
	local windRings: ParticleEmitter? = nil
	if full then
		-- Wind rings round the ball (VelocityPerpendicular): a few while it charges, a stream behind it in flight.
		local rings = newEmitter("WindRings")
		rings.Rate = 16
		rings.Lifetime = NumberRange.new(0.3, 0.4)
		rings.Speed = NumberRange.new(6)
		rings.EmissionDirection = Enum.NormalId.Back
		rings.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		rings.Size = sequence({ { 0, size * 0.6 }, { 1, size * 1.6 } })
		rings.Transparency = sequence({ { 0, 0.15 }, { 1, 1 } })
		rings.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 236, 150))
		rings.LightEmission = 0.6
		rings.LockedToPart = false
		rings.Parent = head
		windRings = rings
	end
	-- The one trail: wide, the owner's texture, gold to white.
	local T = Fx.Trail
	local trail = Instance.new("Beam")
	trail.Name = "SSE_BallTrail"
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Texture = Fx.Textures.SpeedTrail
	trail.TextureMode = Enum.TextureMode.Stretch
	trail.TextureSpeed = T.TextureSpeed
	trail.Width0 = size * T.Width0
	trail.Width1 = size * T.Width1Charge
	trail.FaceCamera = true
	trail.LightEmission = T.LightEmission
	trail.LightInfluence = 0
	trail.Color = ColorSequence.new(rgb(T.Color[1]), rgb(T.Color[2]))
	trail.Transparency = sequence(T.Transparency)
	trail.Segments = budget.TrailSegments
	trail.Enabled = false
	trail.Parent = holder
	return {
		root = root :: BasePart, instance = instance :: Instance, offset = offset, holder = holder, tail = tail,
		size = size, rootOffset = rootOffset, rings = windRings,
		trail = trail, a0 = a0, a1 = a1, tailAttachment = tailAttachment, flying = false,
	}
end

local function showBall(rig: BallRig, on: boolean, rings: boolean, trail: boolean)
	local parent = if on then runtimeFolder() else nil
	rig.instance.Parent = parent
	rig.holder.Parent = parent
	rig.tail.Parent = parent
	if rig.rings then
		rig.rings.Enabled = on and rings
	end
	rig.trail.Enabled = on and trail
end

-- An attachment's frame at `p` whose X axis (the Beam's curve direction) is `axis`.
local function axisFrame(p: Vector3, axis: Vector3): CFrame
	local x = if axis.Magnitude > 1e-4 then axis.Unit else Vector3.new(1, 0, 0)
	local up = if math.abs(x.Z) < 0.95 then Vector3.new(0, 0, 1) else Vector3.new(0, 1, 0)
	local y = up:Cross(x).Unit
	return CFrame.fromMatrix(p, x, y, x:Cross(y))
end

-- The trail's wrap at `angle` (radians round the ball): hugging it (charging) or streaming to the tail (flying).
local function wrapTrail(rig: BallRig, angle: number, flying: boolean, level: number?)
	local T = Fx.Trail
	local p0, axis0, p1, axis1, curve0, curve1 = Fx.TrailWrap(rig.size, angle, flying)
	rig.a0.CFrame = axisFrame(p0, axis0)
	if flying ~= rig.flying then
		rig.flying = flying
		rig.trail.Attachment1 = if flying then rig.tailAttachment else rig.a1
		rig.trail.Width1 = rig.size * (if flying then T.Width1Flight else T.Width1Charge)
	end
	if not flying then
		rig.a1.CFrame = axisFrame(p1, axis1)
	end
	rig.trail.CurveSize0 = curve0
	rig.trail.CurveSize1 = curve1
	local k = math.clamp(tonumber(level) or 1, 0, 1)
	rig.trail.Width0 = rig.size * T.Width0 * (0.75 + 0.25 * k)
end

-- `position`: the character's root (the ball's centre is rig.rootOffset from it), rolling about its X.
local function placeBall(rig: BallRig, position: Vector3, direction: Vector3, spin: number, tailPosition: Vector3)
	local frame = Fx.FrameAlong(position, direction) * rig.rootOffset
	rig.holder.CFrame = frame
	rig.root.CFrame = frame * CFrame.Angles(spin, 0, 0) * rig.offset
	rig.tail.CFrame = Fx.FrameAlong(tailPosition, direction)
end

-- The charge on the ball (2026-09-26, owner, v3): the one trail hugging it, spinning faster as `level` (0..1)
-- grows, the wind rings thickening.
local function chargeBall(rig: BallRig, level: number, clock: number)
	local T = Fx.Trail
	local spin = T.SpinFrom + (T.SpinTo - T.SpinFrom) * level
	wrapTrail(rig, clock * spin, false, level)
	local on = level > 0.02
	if rig.trail.Enabled ~= on then
		rig.trail.Enabled = on
	end
	if rig.rings then
		local c = Fx.Charge
		rig.rings.Rate = c.WindFrom + (c.WindTo - c.WindFrom) * level
	end
end

local function destroyBall(rig: BallRig?)
	if rig then
		rig.instance:Destroy()
		rig.holder:Destroy()
		rig.tail:Destroy()
	end
end

----------------------------------------------------------------------
-- The local homing attack: charged (2026-09-26, owner, v2: hold, the ring fills over SSE.Homing.ChargeSeconds,
-- release or the charge's end launches), then kinematic (the root moved along SSE.HomingPath every frame to the
-- intercept, SSE.HomingIntercept: where the ship will be when it arrives)
-- 2026-09-26 (owner, v3) "fast and vibrant like the Sonic games":
--   * the instant attack: a mid-air jump press launches at charge 0 ({ Homing, t, 0 }, no Charge before it);
--   * the dash is the contract's (Homing.Speed 320 studs/s, a tighter curve): the flight's stages are "fly" (on
--     the path), then either "stop" (a DAMAGING hit: the hit-stop Fx.Homing.HitStop on the hull, the white flash,
--     the shake, the burst, his recoil; then the snappy SSE.HomingBounce) or "knock" (off his SHIELD: the zap,
--     his taunt and a real knock-back away from the ship, SSE.ShieldKnock, the body flying free and curled in the
--     ball for Fx.Homing.ShieldKnockSeconds);
--   * "hit!" (the owner's "hit!.wav") plays exactly when the attack connects as a damaging hit: at the arrival
--     once the server accepted it as one (HomingGo for this client, not shielded), or when its late acceptance
--     comes within Fx.Homing.HitSoundGrace, or with the server's own "Hit"; never on a bounce or a refusal.
----------------------------------------------------------------------
local flight, ownBall, lastHomingAt, lastLocalImpact, airborne, endFlight, updateBall
;(function() -- (a function, not a do-block: see the note at the top)
	type Flight = {
		from: Vector3, clockStart: number, duration: number, character: Model, humanoid: Humanoid, root: BasePart,
		pieces: { Instance }, saved: { [Instance]: number }, dir: Vector3, to: Vector3, spin: number,
		platformStand: boolean, s: number, charge: number, launch: number,
		shielded: boolean, -- the server said "Shielded" before the arrival
		accepted: boolean, -- (v3) the server's HomingGo for this client came back
		serverShielded: boolean?, -- (v3) its verdict: it will bounce off the shield
		stage: string, -- (v3) "fly" | "stop" (the hit-stop) | "knock" (off the shield)
		stageUntil: number,
		hold: CFrame, -- where the hit-stop holds the root
		bounce: Vector3?, -- the bounce after the hit-stop
		tail: Vector3, -- the trail's tail (the path behind the ball)
	}
	flight = nil
	ownBall = nil
	lastHomingAt = -math.huge -- server time of the last request (SSE.Homing.Cooldown)
	lastLocalImpact = -math.huge
	local flightConnection: RBXScriptConnection? = nil
	local charging: any = nil -- { source, input, pressClock, seconds, character, humanoid, root, pieces, saved, spin, sound }
	-- 2026-09-26 (owner, v3): the "hit!" bookkeeping and this client's own shield bounce.
	local hitSoundAt = -math.huge -- os.clock of the last "hit!" for this client's own attack
	local pendingHit: { untilClock: number }? = nil -- a damaging arrival still waiting for the server's word
	local lastKnockAt = -math.huge -- os.clock of this client's own knock-back off the shield

	function airborne(humanoid: Humanoid): boolean
		if humanoid.FloorMaterial ~= Enum.Material.Air then
			return false
		end
		local s = humanoid:GetState()
		return s == Enum.HumanoidStateType.Freefall or s == Enum.HumanoidStateType.Jumping or s == Enum.HumanoidStateType.Flying
	end

	-- Everything the server checks (SSE.CheckHoming) plus what only the client knows: not flying, not thrown,
	-- no cinematic. `withRange`: the range counts (a charge may begin further away and close in). The client
	-- never refuses "Shielded" itself: the attack flies and bounces off (v3). Returns (ok, reason, root, ship).
	local function canHoming(withRange: boolean): (boolean, string?, BasePart?, Vector3?)
		if not state.active or state.phase ~= PHASE.Battle or boss.defeat or boss.flee or Cinema.active then
			return false, SSE.HomingRefusals.Phase, nil, nil
		end
		local character, humanoid, root = localCharacter()
		if not (character and humanoid and root) or humanoid.Health <= 0 then
			return false, SSE.HomingRefusals.Dead, nil, nil
		end
		if player:GetAttribute("FlightAbilityActive") == true or character:GetAttribute("FlightAbilityLocalActive") == true
			or player:GetAttribute("AdminFlying") == true then
			return false, "flying", nil, nil
		end
		local stunned = character:GetAttribute("Ragdolled") == true or humanoid.Sit
		local now = serverNow()
		local bossPos = planPosition(now)
		local ok, reason = SSE.CheckHoming({
			on = SSE.IsOn(),
			phase = state.phase,
			super = player:GetAttribute(PATTR.Super) == true,
			alive = true,
			racing = player:GetAttribute("RaceActive") == true,
			stunned = stunned,
			inFlight = flight ~= nil,
			hits = tonumber(player:GetAttribute(PATTR.Hits)) or 0,
			lastAt = lastHomingAt,
			now = now,
			distance = if withRange then (root.Position - bossPos).Magnitude else 0,
		})
		if not ok then
			return false, reason, root, bossPos
		end
		return true, nil, root, bossPos
	end

	local function stopFlightConnection()
		if flightConnection then
			flightConnection:Disconnect()
			flightConnection = nil
		end
	end

	-- The flight's end: the body back exactly as it was, the ball away; `bounce` the velocity after it; `fall`: the
	-- fall pose (up in the air after a hit or a bounce, not a stumble).
	function endFlight(bounce: Vector3?, fall: boolean?)
		local f = flight
		if not f then
			return
		end
		flight = nil
		stopFlightConnection()
		Look.Hide(f.pieces, f.saved, false)
		local entry = looks[player]
		if entry then
			Look.SetSparks(entry.handle, true)
		end
		if f.humanoid.Parent then
			f.humanoid.PlatformStand = f.platformStand
		end
		if f.character.Parent then
			f.character:SetAttribute(DASH_ATTRIBUTE, nil)
		end
		if bounce and f.root.Parent then
			f.root.AssemblyLinearVelocity = bounce
			f.root.AssemblyAngularVelocity = Vector3.zero
		end
		if (bounce or fall) and f.root.Parent then
			pcall(function()
				f.humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
			end)
		end
		if ownBall then
			showBall(ownBall, false, false, false)
		end
	end

	-- "hit!": this client's own damaging hit (once per attack).
	local function playHitSound()
		hitSoundAt = os.clock()
		pendingHit = nil
		playSound("HomingHit")
	end

	-- The body taken over by the ball (the flight or the knock-back): hidden, no tumble, the movement controller
	-- standing aside, the ball shown.
	local function takeBody(f: Flight)
		flight = f
		f.humanoid.PlatformStand = true
		f.character:SetAttribute(DASH_ATTRIBUTE, true)
		Look.Hide(f.pieces, f.saved, true)
		local entry = looks[player]
		if entry then
			Look.SetSparks(entry.handle, false)
		end
		if not ownBall then
			ownBall = makeBallRig(true)
		end
		local ball = ownBall :: BallRig
		showBall(ball, true, budget.WindRings, budget.Beam)
		wrapTrail(ball, 0, true)
		placeBall(ball, f.root.Position, f.dir, f.spin, f.tail)
	end

	-- Off his shield (v3): the zap, the shield flaring, his taunt, and the knock-back away from the ship (the
	-- contract's SSE.ShieldKnock: the server sends the same Knock, which this client then leaves alone).
	local function shieldBounce(f: Flight, velocity: Vector3?)
		local knock = velocity or SSE.ShieldKnock(f.root.Position, planPosition(serverNow()))
		f.stage = "knock"
		f.stageUntil = os.clock() + Fx.Homing.ShieldKnockSeconds
		lastKnockAt = os.clock()
		pendingHit = nil
		f.root.AssemblyLinearVelocity = knock
		f.root.AssemblyAngularVelocity = Vector3.zero
		if velocity == nil then
			playSound("ShieldZap")
			fireRig("Hit", CFrame.new(f.to), 0.6)
			boss.shieldLevel = 1
			local shake = Fx.Homing.ShieldShake
			CameraPunch.Shake(shake[1], shake[2])
			bossGesture("Smug")
			Screen.Say(SSE.Taunts.Shielded, 4)
		end
	end

	-- The arrival: a damaging hit (the hit-stop, the flash, the shake, the burst, his recoil: all as big as the
	-- charge; "hit!" once the server agrees), or off his shield (the server's verdict, else the client's own
	-- reading of his windows).
	local function arrive(f: Flight)
		local look = Vector3.new(f.dir.X, 0, f.dir.Z)
		lastLocalImpact = os.clock()
		local shielded = f.shielded
		if not shielded then
			if f.accepted and f.serverShielded ~= nil then
				shielded = f.serverShielded == true
			else
				local battleStart = if state.phase == PHASE.Battle then state.phaseStart else nil
				local vulnerable = battleStart ~= nil and SSE.BossVulnerable(serverNow() - battleStart, state.seed)
				shielded = not vulnerable
			end
		end
		if shielded then
			shieldBounce(f, nil)
			return
		end
		local c = f.charge
		f.stage = "stop"
		f.stageUntil = os.clock() + Fx.Homing.HitStop
		f.hold = Fx.FrameAlong(f.to, f.dir)
		f.bounce = SSE.HomingBounce(look, c)
		f.root.CFrame = f.hold
		f.root.AssemblyLinearVelocity = Vector3.zero
		if f.accepted then
			playHitSound()
		else
			pendingHit = { untilClock = os.clock() + Fx.Homing.HitSoundGrace }
		end
		-- 2026-09-26 (owner): only the owner's "hit!" on a hit (the engine's collide.wav clank under it is gone).
		local cam = SSE.Camera.HomingHit
		CameraPunch.Shake(cam.Shake[1], cam.Shake[2] * Fx.ChargeScale(c, Fx.Charge.Shake) * Fx.Homing.HitShake)
		CameraPunch.Fov(Fx.ChargeScale(c, Fx.Charge.Fov))
		hitFlash()
		fireRig("Hit", CFrame.new(f.to), Fx.ChargeScale(c, Fx.Charge.Impact))
		if c >= 0.6 then
			fireRig("Blast", CFrame.new(f.to))
		end
		bossHit(f.from, c)
	end

	-- Every frame before physics: the root on the curve at the dash's speed (no tumble, no gravity); held on the
	-- hull through the hit-stop; flying free (no spin) while knocked back.
	local function stepFlight()
		local f = flight
		if not f then
			stopFlightConnection()
			return
		end
		if not (f.root.Parent and f.humanoid.Parent) or f.humanoid.Health <= 0 or f.character:GetAttribute("Ragdolled") == true
			or not state.active or killed() or os.clock() - f.clockStart > Fx.Homing.MaxSeconds then
			endFlight(nil)
			return
		end
		local clock = os.clock()
		Look.Hide(f.pieces, f.saved, true)
		if f.stage == "stop" then
			f.root.CFrame = f.hold
			f.root.AssemblyLinearVelocity = Vector3.zero
			f.root.AssemblyAngularVelocity = Vector3.zero
			if clock >= f.stageUntil then
				endFlight(f.bounce, true)
			end
			return
		elseif f.stage == "knock" then
			f.root.AssemblyAngularVelocity = Vector3.zero
			if clock >= f.stageUntil then
				endFlight(nil, true)
			end
			return
		end
		local s = math.clamp((clock - f.clockStart) / f.duration, 0, 1)
		f.s = s
		local to = f.to
		local pos = SSE.HomingPath(f.from, to, s)
		local ahead = SSE.HomingPath(f.from, to, math.min(s + 0.02, 1))
		local dir = ahead - pos
		if dir.Magnitude > 1e-3 then
			f.dir = dir.Unit
		end
		f.root.CFrame = Fx.FrameAlong(pos, f.dir)
		f.root.AssemblyLinearVelocity = f.dir * SSE.Homing.Speed
		f.root.AssemblyAngularVelocity = Vector3.zero
		if s >= 1 then
			arrive(f)
		end
	end

	-- The ball's look, after physics (drawn where the root really is this frame): the one trail streaming back.
	function updateBall(dt: number)
		local f = flight
		if not (f and ownBall) then
			return
		end
		local clock = os.clock()
		if f.stage == "fly" then
			f.spin -= Fx.Homing.BallSpin * dt
			f.tail = SSE.HomingPath(f.from, f.to, math.max(0, f.s - Fx.Homing.TrailLag))
			placeBall(ownBall, f.root.Position, f.dir, f.spin, f.tail)
		elseif f.stage == "stop" then
			placeBall(ownBall, f.root.Position, f.dir, f.spin, f.tail)
		else
			-- Knocked back: spinning the other way, the trail behind its motion.
			f.spin += Fx.Homing.BallSpin * dt
			local v = f.root.AssemblyLinearVelocity
			local dir = if v.Magnitude > 1 then v.Unit else f.dir
			f.tail = f.root.Position - dir * ownBall.size * 2.5
			placeBall(ownBall, f.root.Position, dir, f.spin, f.tail)
		end
		wrapTrail(ownBall, clock * Fx.Trail.FlightSpin, true)
	end

	-- The launch: { Homing, clientTime, charge01 } and the flight to the intercept (charge01 0: the mid-air jump's
	-- instant attack, no Charge before it). A refusal the client can see coming stays silent (no text on screen).
	local function launch(source: string, charge01: number, pieces: { Instance }?, saved: { [Instance]: number }?): boolean
		local ok, _, root, _ = canHoming(true)
		if not ok then
			return false
		end
		local character, humanoid = localCharacter()
		if not (character and humanoid and root) then
			return false
		end
		local now = serverNow()
		lastHomingAt = now
		if remote then
			remote:FireServer({ MSG.Homing, now, charge01 })
		end
		prewarmRigs("Hit", 2) -- the arrival's burst (stepFlight never builds)
		if charge01 >= 0.6 then
			prewarmRigs("Blast", 1)
		end
		local from = root.Position
		local target, duration = SSE.HomingIntercept(from, state.origin, now, state.plan)
		pendingHit = nil
		local f: Flight = {
			from = from,
			clockStart = os.clock(),
			duration = duration,
			character = character,
			humanoid = humanoid,
			root = root,
			pieces = pieces or Look.HidePieces(character),
			saved = saved or {},
			dir = if (target - from).Magnitude > 1e-3 then (target - from).Unit else Vector3.new(0, 1, 0),
			to = Fx.HitPoint(target, from),
			spin = 0,
			platformStand = humanoid.PlatformStand,
			s = 0,
			charge = charge01,
			launch = now,
			shielded = false,
			accepted = false,
			serverShielded = nil,
			stage = "fly",
			stageUntil = 0,
			hold = CFrame.new(),
			bounce = nil,
			tail = from,
		}
		takeBody(f)
		playSound("HomingLaunch")
		stopFlightConnection()
		flightConnection = RunService.Stepped:Connect(function()
			stepFlight()
		end)
		return true
	end

	-- The touch button's centre and size in whole-screen pixels (the charge ring goes round it).
	local function buttonRect(): any?
		local button, gui = hud.button, hud.gui
		if not (button and gui and button.Visible) then
			return nil
		end
		local pos, size = button.AbsolutePosition, button.AbsoluteSize
		if typeof(pos) ~= "Vector2" or typeof(size) ~= "Vector2" then
			return nil
		end
		local inset = if gui.IgnoreGuiInset then 0 else (GuiService:GetGuiInset()).Y
		return { X = pos.X + size.X / 2, Y = pos.Y + size.Y / 2 + inset, Size = size.X }
	end

	local function stopCharging(): any
		local c = charging
		charging = nil
		if c then
			if c.sound then
				c.sound:Stop()
			end
			Screen.ChargeRing(nil)
			if ownBall then
				chargeBall(ownBall, 0, 0)
			end
		end
		return c
	end

	function Charge.Active(): boolean
		return charging ~= nil
	end

	-- 2026-09-26 (owner, v3): the mid-air jump's instant, uncharged attack (Inputs: JumpRequest in the air).
	function Charge.Instant(source: string): boolean
		if charging or flight then
			return false
		end
		return launch(source, 0, nil, nil)
	end

	-- The press: { Charge, clientTime }, the charge sound, the ball round the player (the body hidden), the ring.
	-- 2026-09-26 (owner, v3): the charge fills in the contract's Homing.ChargeSeconds (~0.7 s; the sound may play on).
	function Charge.Begin(source: string, input: any?): boolean
		if charging or flight then
			return false
		end
		local ok, _, root = canHoming(false)
		if not ok then
			return false
		end
		local character, humanoid = localCharacter()
		if not (character and humanoid and root) then
			return false
		end
		local pieces = Look.HidePieces(character)
		local c = {
			source = source, input = input, pressClock = os.clock(),
			seconds = Fx.ChargeSeconds(SSE.Homing.ChargeSeconds, soundLength("ChargeStart")),
			character = character, humanoid = humanoid, root = root, pieces = pieces, saved = {}, spin = 0, level = 0,
			sound = playSound("ChargeStart"),
		}
		charging = c
		if remote then
			remote:FireServer({ MSG.Charge, serverNow() })
		end
		prewarmRigs("Hit", 2)
		Look.Hide(pieces, c.saved, true)
		local entry = looks[player]
		if entry then
			Look.SetSparks(entry.handle, false)
		end
		if not ownBall then
			ownBall = makeBallRig(true)
		end
		showBall(ownBall :: BallRig, true, budget.WindRings, false)
		placeBall(ownBall :: BallRig, root.Position, Vector3.new(0, 0, -1), 0, root.Position)
		return true
	end

	-- A charge given up (the phase ended, a throw, a cinematic, death): the body and the sparks back.
	function Charge.Cancel()
		local c = stopCharging()
		if not c then
			return
		end
		Look.Hide(c.pieces, c.saved, false)
		local entry = looks[player]
		if entry then
			Look.SetSparks(entry.handle, true)
		end
		if ownBall and not flight then
			showBall(ownBall, false, false, false)
		end
	end

	-- The release (of `source`'s input; nil: the charge ran out): the launch at the charge reached.
	function Charge.Release(source: string?, input: any?)
		local c = charging
		if not c or (source ~= nil and c.source ~= source) or (input ~= nil and c.input ~= nil and c.input ~= input) then
			return
		end
		local level = math.max(Fx.Charge.MinCharge, Fx.ChargeLevel(os.clock() - c.pressClock, c.seconds))
		stopCharging()
		if not launch(c.source, level, c.pieces, c.saved) then
			Look.Hide(c.pieces, c.saved, false)
			local entry = looks[player]
			if entry then
				Look.SetSparks(entry.handle, true)
			end
			if ownBall then
				showBall(ownBall, false, false, false)
			end
		end
	end

	-- Every frame while charging: the ball spinning up round the player, the one trail wrapping it, the ring; the
	-- charge's end releases it.
	function Charge.Update(clock: number, dt: number)
		local c = charging
		if not c then
			return
		end
		if state.phase ~= PHASE.Battle or not state.active or killed() or Cinema.active or not (c.root.Parent and c.humanoid.Parent)
			or c.humanoid.Health <= 0 or c.character:GetAttribute("Ragdolled") == true or player:GetAttribute(PATTR.Super) ~= true then
			Charge.Cancel()
			return
		end
		local held = clock - c.pressClock
		local level = Fx.ChargeLevel(held, c.seconds)
		c.level = level
		local ch = Fx.Charge
		c.spin -= (ch.SpinFrom + (ch.SpinTo - ch.SpinFrom) * level) * dt
		Look.Hide(c.pieces, c.saved, true)
		local ball = ownBall
		if ball then
			local toBoss = planPosition(serverNow()) - c.root.Position
			placeBall(ball, c.root.Position, Vector3.new(toBoss.X, 0, toBoss.Z), c.spin, c.root.Position)
			chargeBall(ball, level, clock)
		end
		Screen.ChargeRing(level, if c.source == "Touch" then buttonRect() else nil)
		if held >= c.seconds then
			Charge.Release(nil)
		end
	end

	-- 2026-09-26 (owner, v3): the server's HomingGo for this client: the attack is on (its `shielded` verdict).
	-- A damaging arrival that was waiting for it plays "hit!" now (within HitSoundGrace).
	function Charge.Accepted(shielded: any)
		local f = flight
		if f and f.stage == "fly" then
			f.accepted = true
			f.serverShielded = shielded == true
		end
		local waiting = pendingHit
		pendingHit = nil
		if waiting and shielded ~= true and os.clock() <= waiting.untilClock then
			playHitSound()
		end
	end

	-- The server's "Hit" for this client's own attack: "hit!" if the arrival has not played it yet.
	function Charge.ServerHit()
		pendingHit = nil
		if os.clock() - hitSoundAt > 0.8 then
			playHitSound()
		end
	end

	-- The server refused (HomingNo). "Shielded" (v3: at the arrival): the ball glances off (if it is still
	-- flying) or he just taunts; anything else: the ball goes at once, the player drops from there, and the
	-- cooldown the request started is given back.
	function Charge.Refused(reason: any)
		pendingHit = nil
		if reason == SSE.HomingRefusals.Shielded then
			local f = flight
			if f and f.stage == "fly" then
				f.shielded = true
			else
				bossGesture("Smug")
				Screen.Say(SSE.Taunts.Shielded, 4)
			end
			return
		end
		lastHomingAt = -math.huge
		local f = flight
		if f and f.stage == "fly" then
			endFlight(Vector3.new(0, 30, 0), true)
		end
		Charge.Cancel()
	end

	-- The server's "Knock" for this client: a bomb's throw (the server ragdolls, this client throws the body), or
	-- (v3) the shield's bounce: already done here when this client's own ball bounced off (ShieldKnockDedupe),
	-- else the same knock-back now (curled in the ball, flying free).
	function Charge.Knock(velocity: any, kind: any)
		if typeof(velocity) ~= "Vector3" then
			return
		end
		Charge.Cancel()
		if kind == SSE.KnockKinds.Shield then
			if os.clock() - lastKnockAt < Fx.Homing.ShieldKnockDedupe then
				return
			end
			local f = flight
			if f then
				shieldBounce(f, velocity)
				return
			end
			local character, humanoid, root = localCharacter()
			if not (character and humanoid and root) or humanoid.Health <= 0 then
				return
			end
			local knockFlight: Flight = {
				from = root.Position, clockStart = os.clock(), duration = 1, character = character, humanoid = humanoid, root = root,
				pieces = Look.HidePieces(character), saved = {}, dir = if velocity.Magnitude > 1e-3 then velocity.Unit else Vector3.new(0, 1, 0),
				to = root.Position, spin = 0, platformStand = humanoid.PlatformStand, s = 1, charge = 0, launch = serverNow(),
				shielded = true, accepted = true, serverShielded = true, stage = "knock", stageUntil = 0, hold = CFrame.new(),
				bounce = nil, tail = root.Position,
			}
			takeBody(knockFlight)
			shieldBounce(knockFlight, velocity)
			stopFlightConnection()
			flightConnection = RunService.Stepped:Connect(function()
				stepFlight()
			end)
			return
		end
		endFlight(nil)
		local character = player.Character
		if not character then
			return
		end
		-- The server ragdolls the character; its owner (this client) throws it.
		for _, name in { "HumanoidRootPart", "Torso", "UpperTorso" } do
			local part = character:FindFirstChild(name)
			if part and part:IsA("BasePart") then
				part.AssemblyLinearVelocity = velocity
			end
		end
	end
end)()

----------------------------------------------------------------------
-- Other players' flights ("HomingGo"), hits ("Hit") and bounces off the shield ("ShieldHit")
----------------------------------------------------------------------
local onHomingGo, updateOtherFlights, onHit, onShieldHit, destroyFlights
;(function() -- (a function, not a do-block: see the note at the top)
	type OtherFlight = { target: Player, character: Model, from: Vector3, to: Vector3, launch: number, duration: number, rig: BallRig, pieces: { Instance }, saved: { [Instance]: number }, spin: number }
	local otherFlights: { OtherFlight } = {}
	local otherBallPool: { BallRig } = {}
	local lowHpSaid: any = nil -- the event id he last cried "hull critical" in

	local function finishOther(index: number)
		local other = table.remove(otherFlights, index)
		if not other then
			return
		end
		Look.Hide(other.pieces, other.saved, false)
		local entry = looks[other.target]
		if entry then
			Look.SetSparks(entry.handle, true)
		end
		showBall(other.rig, false, false, false)
		table.insert(otherBallPool, other.rig)
	end

	-- { "HomingGo", userId, from, to (the intercept), launchTime, duration, charge, damage, shielded }
	function onHomingGo(userId: any, from: any, to: any, launch: any, duration: any, shielded: any)
		if userId == player.UserId then
			-- (v3) this client's own attack, accepted: its verdict (the "hit!" waits for it)
			Charge.Accepted(shielded)
			return
		end
		if typeof(from) ~= "Vector3" then
			return
		end
		if #otherFlights >= budget.OtherFlights or distanceFromCamera(from) > Fx.Boss.FarHide / 3 then
			return
		end
		local target = Players:GetPlayerByUserId(tonumber(userId) or 0)
		local character = target and target.Character
		if not (target and character) then
			return
		end
		local rig = table.remove(otherBallPool) or makeBallRig(false)
		showBall(rig, true, false, budget.OtherBeam)
		local seconds = math.max(SSE.Homing.MinDuration, tonumber(duration) or 0.5)
		local intercept = if typeof(to) == "Vector3" then to else planPosition((tonumber(launch) or serverNow()) + seconds)
		local other: OtherFlight = {
			target = target,
			character = character,
			from = from,
			to = Fx.HitPoint(intercept, from),
			launch = tonumber(launch) or serverNow(),
			duration = seconds,
			rig = rig,
			pieces = Look.HidePieces(character),
			saved = {},
			spin = 0,
		}
		Look.Hide(other.pieces, other.saved, true)
		local entry = looks[target]
		if entry then
			Look.SetSparks(entry.handle, false)
		end
		table.insert(otherFlights, other)
	end

	function updateOtherFlights(now: number, dt: number)
		local clock = os.clock()
		for index = #otherFlights, 1, -1 do
			local other = otherFlights[index]
			local s = (now - other.launch) / other.duration
			if s >= 1 or not other.character.Parent then
				finishOther(index)
				continue
			end
			s = math.max(s, 0)
			local pos = SSE.HomingPath(other.from, other.to, s)
			local ahead = SSE.HomingPath(other.from, other.to, math.min(s + 0.02, 1))
			other.spin -= Fx.Homing.BallSpin * dt
			placeBall(other.rig, pos, ahead - pos, other.spin, SSE.HomingPath(other.from, other.to, math.max(0, s - Fx.Homing.TrailLag)))
			wrapTrail(other.rig, clock * Fx.Trail.FlightSpin + index, true)
		end
	end

	-- His reaction to a hit: a line now and then (a big one for a full charge), "hull critical" once.
	local function reactToHit(charge: number)
		local hp, maxHp = tonumber(Workspace:GetAttribute(ATTR.BossHP)), tonumber(Workspace:GetAttribute(ATTR.BossMaxHP))
		if hp and hp <= 0 then
			return -- (the Defeat: no dialogue, v3)
		end
		if lowHpSaid ~= state.eventId and hp and maxHp and maxHp > 0 and hp / maxHp < 0.25 then
			lowHpSaid = state.eventId
			Screen.Say("EggmanLowHp")
			return
		end
		if charge >= 0.9 then
			Screen.Say("EggmanHitBig", 4)
		else
			Screen.Say("EggmanHit", 3.5)
		end
	end

	-- { "Hit", userId, pos, hp, maxHp, damage, charge, recoil }: a DAMAGING hit (the server's own word).
	function onHit(userId: any, position: any, _hp: any, _maxHp: any, damage: any, charge: any, _recoil: any)
		setHp()
		if (tonumber(damage) or 1) <= 0 then
			return
		end
		prewarmRigs("Hit", 2)
		local c = math.clamp(tonumber(charge) or 0, 0, 1)
		reactToHit(c)
		local isLocal = userId == player.UserId
		local target = if isLocal then player else Players:GetPlayerByUserId(tonumber(userId) or 0)
		local hitterRoot = characterRoot(target and target.Character)
		local point = if typeof(position) == "Vector3" then position else boss.frame.Position
		if hitterRoot then
			point = Fx.HitPoint(boss.frame.Position, hitterRoot.Position)
		end
		if isLocal then
			Charge.ServerHit() -- "hit!" unless the arrival already played it
			if os.clock() - lastLocalImpact < 0.8 then
				return -- this client already drew its own hit on arrival
			end
		else
			playSound("HomingHit", distanceFromCamera(point) + 40)
		end
		bossHit(if hitterRoot then hitterRoot.Position else nil, c)
		if isLocal or budget.OtherHitBurst then
			fireRig("Hit", CFrame.new(point), Fx.ChargeScale(c, Fx.Charge.Impact))
		end
	end

	-- (v3) { "ShieldHit", userId, pos }: an attack bounced off the shield (this client drew its own already).
	function onShieldHit(userId: any, position: any)
		if userId == player.UserId and os.clock() - lastLocalImpact < 0.8 then
			return
		end
		local point = if typeof(position) == "Vector3" then position else boss.frame.Position
		boss.shieldLevel = 1
		prewarmRigs("Hit", 1)
		fireRig("Hit", CFrame.new(point), 0.5)
		playSound("ShieldZap", distanceFromCamera(point) + 30)
	end

	function destroyFlights()
		Charge.Cancel()
		endFlight(nil)
		for index = #otherFlights, 1, -1 do
			finishOther(index)
		end
		for _, rig in otherBallPool do
			destroyBall(rig)
		end
		table.clear(otherBallPool)
		destroyBall(ownBall)
		ownBall = nil
	end
end)()

----------------------------------------------------------------------
-- Inputs (2026-09-26, owner, v2: HOLD to charge, release to launch): F / gamepad X (ContextActionService),
-- Left Click, the touch button (its own handlers).
-- 2026-09-26 (owner, v3) "like the original Sonic games, simple": jump, then JUMP AGAIN in the air while
-- Eggman is locked on = the instant homing attack (UserInputService.JumpRequest: Space, gamepad A and the touch
-- jump button alike; a new press = no request for Fx.Inputs.JumpEdgeGap before it).
----------------------------------------------------------------------
local flightEquipped, battleReady, syncInputBinding
;(function() -- (a function, not a do-block: see the note at the top)
	local inputBound = false

	-- The Flight ability equipped (outside the event's area jump presses in the air stay the flight's; inside it
	-- the event switches the flight off: EventFlightBlocked).
	function flightEquipped(): boolean
		return Fx.FlightEquipped({
			FlightAbilityOwned = player:GetAttribute("FlightAbilityOwned"),
			FlightAbilityEquipped = player:GetAttribute("FlightAbilityEquipped"),
			EquippedAbility = player:GetAttribute("EquippedAbility"),
			TemporaryFlightExpireUnix = player:GetAttribute("TemporaryFlightExpireUnix"),
		}, os.time(), Config.AbilityFlightEnabled == true)
	end

	local function eventFlightOff(): boolean
		local ok, blocked = pcall(function()
			return RaceNoFlight ~= nil and RaceNoFlight.EventBlocked(player) == true
		end)
		return ok and blocked == true
	end

	local function onHomingAction(_: string, inputState: Enum.UserInputState, input: InputObject): Enum.ContextActionResult
		if inputState == Enum.UserInputState.Begin then
			if Charge.Begin("Action", input) then
				return Enum.ContextActionResult.Sink
			end
		elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
			if Charge.Active() then
				Charge.Release("Action")
				return Enum.ContextActionResult.Sink
			end
		end
		return Enum.ContextActionResult.Pass
	end

	function battleReady(): boolean
		return state.active and state.phase == PHASE.Battle and player:GetAttribute(PATTR.Super) == true and not killed()
			and Cinema.active == nil
	end

	function syncInputBinding()
		local want = battleReady()
		if want and not inputBound then
			local keys = {}
			for _, name in Fx.Inputs.Keys do
				table.insert(keys, Enum.KeyCode[name])
			end
			for _, name in Fx.Inputs.Gamepad do
				table.insert(keys, Enum.KeyCode[name])
			end
			ContextActionService:BindActionAtPriority(Fx.Inputs.Action, onHomingAction, false, Fx.Inputs.Priority, table.unpack(keys))
			inputBound = true
		elseif not want and inputBound then
			ContextActionService:UnbindAction(Fx.Inputs.Action)
			inputBound = false
			Charge.Cancel()
		end
	end

	local function typing(): boolean
		return UserInputService:GetFocusedTextBox() ~= nil or GuiService.MenuIsOpen
	end

	-- The mid-air jump press: the instant attack while locked on (in range; the server's rules decide the rest).
	local lastJumpRequest = -math.huge
	UserInputService.JumpRequest:Connect(function()
		local clock = os.clock()
		local press = Fx.JumpPress(clock, lastJumpRequest)
		lastJumpRequest = clock
		if not press or not Fx.Inputs.JumpInAir or not battleReady() or typing() then
			return
		end
		if flightEquipped() and not eventFlightOff() then
			return
		end
		local _, humanoid = localCharacter()
		if humanoid and airborne(humanoid) then
			Charge.Instant("Jump")
		end
	end)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not battleReady() then
			return
		end
		if Fx.Inputs.Mouse and input.UserInputType == Enum.UserInputType.MouseButton1 and not gameProcessed then
			Charge.Begin("Mouse", input)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if not Charge.Active() then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			Charge.Release("Mouse")
		elseif input.UserInputType == Enum.UserInputType.Touch then
			-- A finger that slid off the button still lets go of the charge.
			Charge.Release("Touch", input)
		end
	end)
end)()

----------------------------------------------------------------------
-- Reticle, button, boss bar state (10 times a second; the pulses every frame)
----------------------------------------------------------------------
local nextUiCheck, buttonShown, updateHud
;(function() -- (a function, not a do-block: see the note at the top)
	local function inputKind(): string
		local last = UserInputService:GetLastInputType()
		if last == Enum.UserInputType.Touch then
			return "Touch"
		end
		if string.sub(last.Name, 1, 7) == "Gamepad" then
			return "Gamepad"
		end
		if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
			return "Touch"
		end
		return "Keys"
	end

	nextUiCheck = 0
	buttonShown = false

	function updateHud(clock: number, dt: number)
		-- The boss bar: its damage trail catches up with the fill; the jolt settles; lit while he can be hit.
		local bar = hud.bar
		local reloading = state.phase == PHASE.Battle and state.bossState == SSE.BossStates.Reload and not boss.defeat
		if bar then
			local show = (state.phase == PHASE.Battle or isEndPhase(state.phase)) and not boss.gone
				and (state.origin - cameraPosition()).Magnitude < 900 and Cinema.active == nil
			if bar.Visible ~= show then
				bar.Visible = show
			end
			if show then
				hud.trailShare += (hud.fillShare - hud.trailShare) * math.clamp(dt * 3, 0, 1)
				if hud.trail then
					hud.trail.Size = UDim2.fromScale(hud.trailShare, 1)
				end
				if bar.Rotation ~= 0 then
					bar.Rotation = if math.abs(bar.Rotation) < 0.1 then 0 else bar.Rotation * 0.85
				end
				local battle = state.phase == PHASE.Battle and not boss.defeat
				local pulse = 0.5 + 0.5 * math.sin(clock * 9)
				if hud.barGlow then
					hud.barGlow.Color = if reloading then GOLD:Lerp(Color3.new(1, 1, 1), pulse * 0.4) else RIM
					hud.barGlow.Thickness = if reloading then 2 + 1.5 * pulse else 2
					hud.barGlow.Transparency = if reloading then 0 else 0.33
				end
				if hud.fill then
					-- (dimmed behind his shield: no words for it)
					hud.fill.BackgroundTransparency = if battle and not reloading then 0.35 else 0
				end
				local cue = hud.cue
				if cue then
					if cue.Visible ~= reloading then
						cue.Visible = reloading
					end
					if reloading and hud.cueScale then
						hud.cueScale.Scale = 1 + 0.08 * pulse
					end
				end
			end
		end
		-- The small "!" over him while he reloads (flashing).
		local alert = hud.alert
		if alert then
			local on = reloading and boss.alertAnchor ~= nil and not boss.gone and Cinema.active == nil
			if alert.Enabled ~= on then
				alert.Enabled = on
			end
			if on then
				alert.Adornee = boss.alertAnchor
				if hud.alertMark then
					hud.alertMark.TextTransparency = if math.sin(clock * 12) > -0.3 then 0 else 0.7
					hud.alertMark.Rotation = math.sin(clock * 7) * 8
				end
			end
		end
		if hud.reticleSpin and hud.reticle and hud.reticle.Enabled then
			hud.reticleSpin.Rotation = (clock * 90) % 360
		end
		if clock < nextUiCheck then
			return
		end
		nextUiCheck = clock + 1 / Fx.Homing.ButtonCheckHz
		local ready = battleReady() and flight == nil
		local locked, cooling, inAir = false, false, false
		local _, humanoid, root = localCharacter()
		if ready and humanoid and root then
			local bossPos = planPosition(serverNow())
			locked = Fx.InRange(root.Position, bossPos)
			cooling = serverNow() - lastHomingAt < SSE.Homing.Cooldown
			inAir = airborne(humanoid)
		end
		local reticle = hud.reticle
		if reticle then
			local on = locked and boss.reticleAnchor ~= nil and not boss.gone
			reticle.Adornee = boss.reticleAnchor
			reticle.Enabled = on
			if on then
				local fire = not cooling and reloading
				if hud.reticleRing then
					hud.reticleRing.Color = if fire then GOLD else Color3.fromRGB(235, 235, 235)
					hud.reticleRing.Transparency = if fire then 0 else 0.35
				end
				local prompt = hud.reticlePrompt
				if prompt then
					-- 2026-09-26 (owner, v3): "(A)" / "(X)" on a gamepad, nothing otherwise.
					local text = Fx.ReticlePrompt(inputKind(), inAir)
					prompt.Text = text
					prompt.Visible = text ~= ""
				end
			end
		end
		local button = hud.button
		if button then
			local touch = UserInputService.TouchEnabled and inputKind() == "Touch"
			local show = touch and (locked or Charge.Active()) and not hud.menuOpen and Cinema.active == nil
			if show and not buttonShown then
				layoutButton()
			end
			buttonShown = show
			button.Visible = show
			button.BackgroundTransparency = if cooling then 0.45 else 0
		end
	end
end)()

----------------------------------------------------------------------
-- The ring rain (2026-09-26, owner, v2): the broken Egg Mobile spills Sonic's gold rings ({ "Rings", ... }): they
-- burst out of the ship on arcs ("coinnsdrop"), land where the server says at its landTime, spin about their Y and
-- bob there, and fade out smoothly at their expireTime. Touching one takes it: at once here ("coin pickup", a small
-- sparkle in the kit's ColorSparkle, the ring popping up) and { "RingTake", ids } to the server, which validates
-- ("RingGone" everywhere, or "RingNo": "gone" removes it, "cap" leaves it, anything else lets it be taken again).
-- The rings outlive the event (the contract: they stay until their expireTime): their own folder, sounds, sparkle
-- and frame loop, all gone once the last ring is (or at once under the kill switch / "RingsClear"). Pooled; the
-- nearest RingsVisible (the tier) are drawn. The kit's Meshes.Ring when it is there (an upright MeshPart, its hole
-- along Z), else a glossy gold torus of short cylinders like it.
----------------------------------------------------------------------
local Rings = {} :: any
;(function() -- (a function, not a do-block: see the note at the top)
	type RingVisual = { root: BasePart, instance: Instance, offset: CFrame, parts: { BasePart } }
	type Ring = {
		id: number, pos: Vector3, from: Vector3, land: number, launch: number, expire: number, visual: RingVisual?,
		pending: boolean, retryAt: number, spin: number,
	}
	type Sparkle = { part: BasePart, list: { { emitter: ParticleEmitter, count: number } }, busyUntil: number }
	local rings: { [number]: Ring } = {}
	local ringPool: { RingVisual } = {}
	local popping: { { visual: RingVisual, start: number, from: Vector3 } } = {}
	local queue: { number } = {}
	local sparkles: { Sparkle } = {}
	local collectSounds: { Sound } = {}
	local spillSound: Sound? = nil
	local spill: any = nil -- (v3) { at, from }: the "coinnsdrop" waiting for the burst (server time)
	local folder: Folder? = nil
	local connection: RBXScriptConnection? = nil
	local rankSerial = 0
	local capped = false
	local lastSend = -math.huge
	local nextCheck = 0
	local RING_GOLD = rgb(Fx.Rings.Color)
	local SPARKLE = rgb(Fx.Rings.Sparkle)

	local function ringsFolder(): Folder
		if folder and folder.Parent then
			return folder
		end
		local made = Instance.new("Folder")
		made.Name = Fx.RingsFolderName
		made.Parent = Workspace
		folder = made
		return made
	end

	local function makeRingVisual(): RingVisual
		local r = Fx.Rings
		local template = meshTemplate(Fx.MeshNames.Ring)
		if template then
			local root, clone, offset = fitClone(template, r.Size, "Largest")
			if root and clone then
				clone.Name = "SSE_Ring"
				return { root = root, instance = clone, offset = offset, parts = partsOf(clone) }
			end
		end
		-- A glossy gold torus: Segments short cylinders round a circle (the axis along each tangent), standing
		-- upright with its hole along Z, as the kit's ring.
		local holder = newPart("SSE_Ring", Vector3.new(0.2, 0.2, 0.2), RING_GOLD, Enum.Material.SmoothPlastic)
		holder.Transparency = 1
		local parts = {}
		local radius = (r.Size - r.Thickness) / 2
		local length = TAU * radius / r.Segments * 1.12
		for k = 1, r.Segments do
			local a = (k - 0.5) / r.Segments * TAU
			local piece = newPart("SSE_RingPiece", Vector3.new(length, r.Thickness, r.Thickness), RING_GOLD, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
			piece.Reflectance = 0.35
			piece.CFrame = holder.CFrame * CFrame.new(math.cos(a) * radius, math.sin(a) * radius, 0) * CFrame.Angles(0, 0, a + math.pi / 2)
			piece.Anchored = false
			holdTo(holder, piece)
			piece.Parent = holder
			table.insert(parts, piece)
		end
		return { root = holder, instance = holder, offset = CFrame.new(), parts = parts }
	end

	-- Their own sounds (SoundService: the SFX group) and sparkles, made when a rain begins.
	local function prepare()
		local f = ringsFolder()
		while #collectSounds < 3 do
			local sound = Instance.new("Sound")
			sound.Name = "SSE_RingsCollect"
			sound.SoundId = Fx.Sounds.RingCollect.Id
			sound.Parent = SoundService
			table.insert(collectSounds, sound)
		end
		if not spillSound then
			local sound = Instance.new("Sound")
			sound.Name = "SSE_RingsSpill"
			sound.SoundId = Fx.Sounds.RingSpill.Id
			sound.Parent = SoundService
			spillSound = sound
		end
		local hatch = vfxTemplate(SSE.VfxNames.BurstHatch)
		while hatch and #sparkles < 3 do
			local part = newPart("SSE_RingSparkle", Vector3.new(1, 1, 1), SPARKLE, Enum.Material.SmoothPlastic)
			part.Transparency = 1
			local attachment = Instance.new("Attachment")
			attachment.Parent = part
			local list = {}
			for _, d in hatch:GetDescendants() do
				if d:IsA("ParticleEmitter") and Fx.EmitterAllowed(SSE.VfxNames.BurstHatch, d.Name, "Hit") then
					local clone = d:Clone()
					clone.Enabled = false
					clone.Color = ColorSequence.new(SPARKLE)
					clone.LightEmission = 1
					local keys = {}
					for _, key in clone.Size.Keypoints do
						table.insert(keys, NumberSequenceKeypoint.new(key.Time, key.Value * 0.35))
					end
					clone.Size = NumberSequence.new(keys)
					clone.Parent = attachment
					table.insert(list, { emitter = clone, count = Fx.EmitCount(d:GetAttribute("SabEmit"), d:GetAttribute("EmitCount"), 0.5) })
				end
			end
			part.CFrame = FAR_AWAY
			part.Parent = f
			table.insert(sparkles, { part = part, list = list, busyUntil = 0 })
		end
	end

	local function play(sound: Sound?, volume: number, distance: number?)
		if not sound or not soundsOn() then
			return
		end
		local v = if distance then Fx.Attenuate(volume, distance) else volume
		if v <= 0.02 then
			return
		end
		sound.Volume = v
		sound.TimePosition = 0
		sound:Play()
	end

	local function sparkle(position: Vector3)
		local clock = os.clock()
		for _, s in sparkles do
			if s.busyUntil <= clock then
				s.busyUntil = clock + 1
				s.part.CFrame = CFrame.new(position)
				for _, entry in s.list do
					entry.emitter:Emit(entry.count)
				end
				return
			end
		end
	end

	local function hide(ring: Ring)
		if ring.visual then
			ring.visual.instance.Parent = nil
			table.insert(ringPool, ring.visual)
			ring.visual = nil
		end
	end

	local function setAlpha(visual: RingVisual, alpha: number)
		local m = 1 - alpha
		for _, part in visual.parts do
			if part.LocalTransparencyModifier ~= m then
				part.LocalTransparencyModifier = m
			end
		end
	end

	-- A ring taken (by this player: `mine`): it pops up and fades; the collect sound and the sparkle are the taker's.
	local function collect(ring: Ring, mine: boolean)
		if ring.visual then
			local visual = ring.visual
			ring.visual = nil
			table.insert(popping, { visual = visual, start = os.clock(), from = visual.root.Position })
		end
		if mine then
			local free = collectSounds[1]
			for _, sound in collectSounds do
				if not sound.IsPlaying then
					free = sound
					break
				end
			end
			play(free, Fx.Sounds.RingCollect.Volume)
			sparkle(ring.pos)
		end
	end

	-- Everything of the rain away (the rings' pieces, sounds, sparkles, folder, loop).
	function Rings.Destroy()
		spill = nil
		for _, ring in rings do
			hide(ring)
		end
		table.clear(rings)
		table.clear(queue)
		table.clear(popping)
		rankSerial += 1
		if connection then
			connection:Disconnect()
			connection = nil
		end
		for _, visual in ringPool do
			visual.instance:Destroy()
		end
		table.clear(ringPool)
		for _, sound in collectSounds do
			sound:Destroy()
		end
		table.clear(collectSounds)
		if spillSound then
			spillSound:Destroy()
			spillSound = nil
		end
		table.clear(sparkles)
		if folder then
			folder:Destroy()
			folder = nil
		end
		capped = false
	end

	-- { "RingsClear", eventId }: every ring goes now.
	function Rings.Clear()
		Rings.Destroy()
	end

	-- In its own thread (never per frame), once a second while rings are out: the nearest RingsVisible drawn.
	function Rings.Rank()
		if next(rings) == nil then
			return
		end
		local eye = cameraPosition()
		local ranked = {}
		for id, ring in rings do
			if not ring.pending then
				table.insert(ranked, { id, (ring.pos - eye).Magnitude })
			end
		end
		table.sort(ranked, function(a, b)
			return a[2] < b[2]
		end)
		local keep = {}
		for index = 1, math.min(#ranked, budget.RingsVisible) do
			keep[ranked[index][1]] = true
		end
		for id, ring in rings do
			if not keep[id] and ring.visual then
				hide(ring)
			end
		end
		for id in keep do
			local ring = rings[id]
			if ring and not ring.visual then
				local visual = table.remove(ringPool) or makeRingVisual()
				setAlpha(visual, 0)
				visual.root.CFrame = CFrame.new(ring.from)
				visual.instance.Parent = ringsFolder()
				ring.visual = visual
			end
		end
	end

	local function send()
		if #queue == 0 or not remote then
			return
		end
		local clock = os.clock()
		if clock - lastSend < 0.12 then
			return
		end
		lastSend = clock
		local ids = {}
		while #queue > 0 and #ids < SSE.Rings.MaxIdsPerMessage do
			table.insert(ids, table.remove(queue, 1))
		end
		remote:FireServer({ MSG.RingTake, if #ids == 1 then ids[1] else ids })
	end

	-- Every frame while rings are out (their own loop: they outlive the event): the arcs, the spin and bob, the
	-- fades; TakeCheckHz times a second, the touch. The last ring gone (or the kill switch): everything goes.
	function Rings.Update(now: number, clock: number)
		if killed() then
			Rings.Destroy()
			return
		end
		local pendingSpill = spill
		if pendingSpill and now >= pendingSpill.at then
			spill = nil
			play(spillSound, Fx.Sounds.RingSpill.Volume, distanceFromCamera(pendingSpill.from))
		end
		for index = #popping, 1, -1 do
			local pop = popping[index]
			local k = (clock - pop.start) / Fx.Rings.PopSeconds
			if k >= 1 then
				table.remove(popping, index)
				pop.visual.instance.Parent = nil
				table.insert(ringPool, pop.visual)
			else
				pop.visual.root.CFrame = CFrame.new(pop.from + Vector3.new(0, 3 * k, 0)) * CFrame.Angles(0, clock * 18, 0) * pop.visual.offset
				setAlpha(pop.visual, 1 - k)
			end
		end
		if next(rings) == nil then
			send()
			if #popping == 0 and #queue == 0 then
				Rings.Destroy()
			end
			return
		end
		local r = Fx.Rings
		for id, ring in rings do
			if now >= ring.expire then
				rings[id] = nil
				hide(ring)
				continue
			end
			local visual = ring.visual
			if visual then
				if ring.pending then
					setAlpha(visual, 0)
				elseif now < ring.land then
					local t = math.clamp((now - ring.launch) / math.max(ring.land - ring.launch, 0.05), 0, 1)
					visual.root.CFrame = CFrame.new(Fx.RingArc(ring.from, ring.pos, t)) * CFrame.Angles(0, now * r.Spin * 3 + ring.spin, 0) * visual.offset
					setAlpha(visual, if now < ring.launch then 0 else 1)
				else
					-- Resting: spinning about its Y (it stands upright), bobbing, fading at its end.
					local bob = math.sin(now * TAU * r.BobHz + ring.spin) * r.Bob
					visual.root.CFrame = CFrame.new(ring.pos + Vector3.new(0, bob, 0)) * CFrame.Angles(0, now * r.Spin + ring.spin, 0) * visual.offset
					setAlpha(visual, Fx.RingAlpha(now - ring.land, ring.expire - ring.land))
				end
			end
		end
		if clock < nextCheck or capped then
			send()
			return
		end
		nextCheck = clock + 1 / r.TakeCheckHz
		local _, humanoid, root = localCharacter()
		if root and humanoid and humanoid.Health > 0 then
			local p = root.Position
			for _, ring in rings do
				if not ring.pending and now >= ring.land - 0.05 and clock >= ring.retryAt then
					local dx, dy, dz = ring.pos.X - p.X, ring.pos.Y - p.Y, ring.pos.Z - p.Z
					if dx * dx + dz * dz <= r.TakeRadius * r.TakeRadius and math.abs(dy) <= 6 then
						ring.pending = true
						table.insert(queue, ring.id)
						collect(ring, true)
					end
				end
			end
		end
		send()
	end

	-- { "Rings", eventId, positions, landTime, expireTime, fromPos, takenIds } (a late joiner gets it too).
	-- 2026-09-26 (owner, v3): `burstTime` (the crash's impact + Crash.RingsDelay): they burst out of the crash point
	-- then (the "coinnsdrop" with them), not at once.
	function Rings.OnRings(_eventId: any, positions: any, landTime: any, expireTime: any, fromPos: any, takenIds: any, burstTime: any)
		if type(positions) ~= "table" or killed() then
			return
		end
		Rings.Destroy()
		prepare()
		local now = serverNow()
		local land = tonumber(landTime) or now + 1.6
		local expire = tonumber(expireTime) or land + Fx.Rings.Life
		local burst = math.min(tonumber(burstTime) or now, land - 0.3)
		local from = if typeof(fromPos) == "Vector3" then fromPos else planPosition(now)
		local gone = {}
		if type(takenIds) == "table" then
			for _, id in takenIds do
				gone[tonumber(id) or -1] = true
			end
		end
		for index, pos in positions do
			if typeof(pos) == "Vector3" and not gone[index] then
				-- They burst out at burstTime and land at landTime (the far ones leave first: a spray, not a block).
				local flight = math.clamp(Fx.RingFlight(from, pos), 0.4, math.max(0.4, land - math.max(now, burst)))
				rings[index] = { id = index, pos = pos, from = from, land = land, launch = land - flight, expire = expire,
					visual = nil, pending = false, retryAt = 0, spin = math.random() * TAU }
			end
		end
		if land > now then
			if burst <= now then
				play(spillSound, Fx.Sounds.RingSpill.Volume, distanceFromCamera(from))
			else
				spill = { at = burst, from = from }
			end
		end
		Rings.Rank()
		if not connection then
			connection = RunService.RenderStepped:Connect(function()
				Rings.Update(serverNow(), os.clock())
			end)
		end
		rankSerial += 1
		local serial = rankSerial
		task.spawn(function()
			while serial == rankSerial and connection do
				task.wait(1)
				if serial == rankSerial then
					Rings.Rank()
				end
			end
		end)
	end

	-- { "RingGone", id, userId }
	function Rings.Gone(id: any, userId: any)
		local ring = rings[tonumber(id) or -1]
		if not ring then
			return
		end
		rings[ring.id] = nil
		if ring.pending then
			hide(ring)
			return -- (already taken here)
		end
		collect(ring, userId == player.UserId)
	end

	-- { "RingNo", id, reason }
	function Rings.No(id: any, reason: any)
		local ring = rings[tonumber(id) or -1]
		if reason == SSE.RingRefusals.Cap then
			capped = true
		end
		if not ring then
			return
		end
		if reason == SSE.RingRefusals.Gone then
			rings[ring.id] = nil
			hide(ring)
			return
		end
		-- Still there: it shows again (and may be taken again a moment later).
		ring.pending = false
		ring.retryAt = os.clock() + 0.6
	end

	function Rings.Count(): number
		local n = 0
		for _ in rings do
			n += 1
		end
		return n
	end
end)()

----------------------------------------------------------------------
-- The chaos (2026-09-26, owner, v2): while the event lasts the sky turns fiery (Admin/AdminAbuseEffects'
-- blendLighting mixes the Lighting layer from the same Fx.ChaosTarget); here the grade (this client's own
-- ColorCorrectionEffect), smoke columns and burning patches round the lobby (seeded places, the tier's count),
-- embers drifting round the camera. At the end they fade out (the grade with the weight), then go.
----------------------------------------------------------------------
local Chaos = {} :: any
;(function() -- (a function, not a do-block: see the note at the top)
	type Column = { part: BasePart, emitters: { ParticleEmitter }, rates: { number } }
	local grade: ColorCorrectionEffect? = nil
	local weight = 0
	local columns: { Column } = {}
	local embers: { part: BasePart, emitters: { ParticleEmitter }, rates: { number } }? = nil
	local placedFor: any = nil
	local lastRateWeight = -1
	local fadeConnection: RBXScriptConnection? = nil
	local G = Fx.Chaos.Grade

	local function applyGrade()
		local g = grade
		if not g then
			return -- (made by Chaos.Prewarm)
		end
		if weight <= 0.001 or not budget.Grade or killed() then
			if g.Enabled then
				g.Enabled = false
			end
			return
		end
		g.Enabled = true
		g.TintColor = Color3.new(1, 1, 1):Lerp(rgb(G.TintColor), weight)
		g.Saturation = G.Saturation * weight
		g.Contrast = G.Contrast * weight
		g.Brightness = G.Brightness * weight
	end

	-- The floor under a point (a ray down; the origin's height when nothing is found).
	local function floorAt(point: Vector3): Vector3
		local ok, hit = pcall(function()
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			local exclude = { runtimeFolder() }
			for _, other in Players:GetPlayers() do
				if other.Character then
					table.insert(exclude, other.Character)
				end
			end
			params.FilterDescendantsInstances = exclude
			return Workspace:Raycast(point + Vector3.new(0, 40, 0), Vector3.new(0, -120, 0), params)
		end)
		if ok and hit then
			return hit.Position
		end
		return Vector3.new(point.X, state.origin.Y, point.Z)
	end

	local function smokeEmitters(parent: Instance): ({ ParticleEmitter }, { number })
		local list, rates = {}, {}
		local template = vfxTemplate(SSE.VfxNames.BombExplode)
		if not template then
			return list, rates
		end
		local a = Fx.Ambience
		for _, name in { "smoke", "smoke_2" } do
			local source = template:FindFirstChild(name, true)
			if source and source:IsA("ParticleEmitter") then
				local clone = source:Clone()
				clone.Enabled = false
				clone.LockedToPart = false
				clone.EmissionDirection = Enum.NormalId.Top
				clone.SpreadAngle = Vector2.new(10, 10)
				clone.Speed = NumberRange.new(a.SmokeRise * 0.7, a.SmokeRise)
				clone.Lifetime = NumberRange.new(a.SmokeLife[1], a.SmokeLife[2])
				clone.Acceleration = Vector3.new(0, 1.5, 0)
				pcall(function()
					clone.Drag = 0.3
				end)
				local keys = {}
				for _, key in clone.Size.Keypoints do
					table.insert(keys, NumberSequenceKeypoint.new(key.Time, key.Value * a.SmokeSize * (0.6 + 0.8 * key.Time)))
				end
				clone.Size = NumberSequence.new(keys)
				-- 2026-09-26 (owner, v3): a paler, thinner smoke (the lobby stays readable).
				clone.Color = ColorSequence.new(rgb(a.SmokeColor[1]), rgb(a.SmokeColor[2]))
				clone.Parent = parent
				table.insert(list, clone)
				table.insert(rates, if name == "smoke" then a.SmokeRates[1] else a.SmokeRates[2])
			end
		end
		return list, rates
	end

	-- From the handlers and the sweep (never per frame): the grade, the columns and the embers for this event,
	-- placed once.
	function Chaos.Prewarm()
		if not grade or not grade.Parent then
			local made = Instance.new("ColorCorrectionEffect")
			made.Name = Fx.GradeName
			made.Enabled = false
			made.Parent = Lighting
			grade = made
		end
		if placedFor == state.eventId and #columns >= budget.SmokeColumns then
			return
		end
		placedFor = state.eventId
		local points = Fx.AmbiencePoints(state.seed, budget.SmokeColumns)
		while #columns < #points do
			local part = newPart("SSE_SmokeColumn", Vector3.new(4, 1, 4), GOLD, Enum.Material.SmoothPlastic)
			part.Transparency = 1
			local attachment = Instance.new("Attachment")
			attachment.Name = "SSE_Smoke"
			attachment.Parent = part
			local emitters, rates = smokeEmitters(attachment)
			part.Parent = runtimeFolder()
			table.insert(columns, { part = part, emitters = emitters, rates = rates })
		end
		local fires = {}
		for index, offset in points do
			-- (v3: on the race map the smoke and the fires stay inside the corridor, along the track)
			local o = if arenaMode() then Vector3.new(math.clamp(offset.X, -Fx.Ambience.MaxAcross, Fx.Ambience.MaxAcross), 0, offset.Z) else offset
			local at = floorAt(state.origin + o)
			columns[index].part.CFrame = CFrame.new(at + Vector3.new(0, 0.5, 0))
			if index <= budget.AmbientFires then
				table.insert(fires, at)
			end
		end
		prewarmFires(#fires + budget.FirePatches * 4)
		burnAmbient(fires)
		if not embers then
			local hatch = vfxTemplate(SSE.VfxNames.BurstHatch)
			local source = hatch and hatch:FindFirstChild("Embers [20]", true)
			if source and source:IsA("ParticleEmitter") then
				local box = Fx.Ambience.EmberBox
				local part = newPart("SSE_Embers", Vector3.new(box[1], box[2], box[3]), GOLD, Enum.Material.SmoothPlastic)
				part.Transparency = 1
				local clone = source:Clone()
				clone.Enabled = false
				clone.LockedToPart = false
				pcall(function()
					clone.Shape = Enum.ParticleEmitterShape.Box
					clone.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
				end)
				clone.EmissionDirection = Enum.NormalId.Top
				clone.Speed = NumberRange.new(3, 7)
				clone.Lifetime = NumberRange.new(2, 3.5)
				clone.Acceleration = Vector3.new(0, 2.5, 0)
				clone.Color = ColorSequence.new(Color3.fromRGB(255, 200, 80), Color3.fromRGB(255, 70, 20))
				local keys = {}
				for _, key in clone.Size.Keypoints do
					table.insert(keys, NumberSequenceKeypoint.new(key.Time, key.Value * 0.35))
				end
				clone.Size = NumberSequence.new(keys)
				clone.Parent = part
				part.CFrame = FAR_AWAY
				part.Parent = runtimeFolder()
				embers = { part = part, emitters = { clone }, rates = { 1 } }
			end
		end
		lastRateWeight = -1
	end

	local function setRates(k: number)
		for index, column in columns do
			local on = index <= budget.SmokeColumns and k > 0.02
			for j, emitter in column.emitters do
				emitter.Rate = column.rates[j] * k
				if emitter.Enabled ~= on then
					emitter.Enabled = on
				end
			end
		end
		if embers then
			for _, emitter in embers.emitters do
				emitter.Rate = budget.EmberRate * k
				emitter.Enabled = k > 0.02 and budget.EmberRate > 0
			end
		end
	end

	-- Every frame while the event runs: the weight, the grade, the smoke's and embers' rates (when the weight
	-- moved), the embers' box round the camera.
	-- 2026-09-26 (owner, v3): zone-based: only while the local root is in the event's area (state.inArena).
	function Chaos.Update(now: number, dt: number)
		local target = Fx.ChaosTarget(state.phase, now - state.phaseStart, SSE.IsOn(), state.inArena)
		weight = Fx.ChaosStep(weight, target, dt)
		state.chaos = weight
		applyGrade()
		if math.abs(weight - lastRateWeight) > 0.02 or (weight == 0) ~= (lastRateWeight == 0) then
			lastRateWeight = weight
			setRates(weight)
		end
		if embers and weight > 0.02 then
			local eye = cameraPosition()
			embers.part.CFrame = CFrame.new(eye + Vector3.new(0, Fx.Ambience.EmberHeight, 0))
		end
	end

	-- The event is over: the smoke and embers stop (their particles die out), the ambient fires fade, the grade
	-- fades with the weight; then everything goes (`instant`: now, the kill switch).
	function Chaos.Finish(instant: boolean?)
		setRates(0)
		burnAmbient(nil)
		table.clear(columns) -- (their parts leave with the runtime folder)
		embers = nil
		placedFor = nil
		if fadeConnection then
			fadeConnection:Disconnect()
			fadeConnection = nil
		end
		local function done()
			if fadeConnection then
				fadeConnection:Disconnect()
				fadeConnection = nil
			end
			weight = 0
			state.chaos = 0
			if grade then
				grade:Destroy()
				grade = nil
			end
		end
		if instant or weight <= 0 then
			done()
			return
		end
		fadeConnection = RunService.RenderStepped:Connect(function(dt)
			weight = Fx.ChaosStep(weight, 0, dt)
			applyGrade()
			if weight <= 0 then
				done()
			end
		end)
	end
end)()

----------------------------------------------------------------------
-- The cinematics (2026-09-26, owner, v2): Shared/SuperSonicCinematic's shots on a Scriptable camera (bound after
-- the camera scripts; CameraPunch's shake still rides on it), letterbox bars (Screen.SetBars), the interface away
-- (InterfaceHider: our screen stays), the controls off. Whatever ends it (the shot's end, an error, a respawn,
-- the event ending, the kill switch, the watchdog Cine.MaxSeconds), Cinema.Stop puts the camera's type and
-- subject, the controls and the interface back. Only for a player who saw the moment begin (never on joining
-- mid-event), inside the arena, not racing, not under another cinematic.
-- 2026-09-26 (owner, v3): the shots are Shared/SuperSonicCinematic v3's eased spline keys from the player's own
-- camera and field of view back to them; the eye is kept clear of walls (ctx.clear: a raycast from the look-at
-- point toward the eye, the event's pieces and the characters ignored; Cine.Guard every frame).
----------------------------------------------------------------------
;(function() -- (a function, not a do-block: see the note at the top)
	local controls: any = nil

	-- The free distance from `from` toward `to` (nil: nothing in the way): the map only.
	local clearParams: RaycastParams? = nil
	local function clearDistance(from: Vector3, to: Vector3): number?
		local ok, hit = pcall(function()
			local params = clearParams
			if not params then
				params = RaycastParams.new()
				params.FilterType = Enum.RaycastFilterType.Exclude
				params.IgnoreWater = true
				clearParams = params
			end
			local exclude = { runtimeFolder() }
			for _, other in Players:GetPlayers() do
				if other.Character then
					table.insert(exclude, other.Character)
				end
			end
			local lobby = lobbyEggman()
			if lobby then
				table.insert(exclude, lobby)
			end
			-- Invisible pieces (the map's invisible barriers and colliders) never push the eye in: skipped.
			for _ = 1, 4 do
				params.FilterDescendantsInstances = exclude
				local result = Workspace:Raycast(from, to - from, params)
				local part = result and result.Instance
				if not (part and part:IsA("BasePart") and part.Transparency >= 0.95) then
					return result
				end
				table.insert(exclude, part)
			end
			return nil
		end)
		if ok and hit then
			return (hit.Position - from).Magnitude
		end
		return nil
	end

	local function playerControls(): any
		if controls then
			return controls
		end
		local ok, result = pcall(function()
			local scripts = player:FindFirstChild("PlayerScripts")
			local module = scripts and scripts:FindFirstChild("PlayerModule")
			return if module then (require :: any)(module):GetControls() else nil
		end)
		controls = if ok then result else nil
		return controls
	end

	-- 2026-09-26 (owner, v3): the player's controls held off by the cinematic and / or the freeze: off while
	-- anyone holds them, back on when the last lets go.
	local controlHolds: { [string]: boolean } = {}
	function Cinema.HoldControls(owner: string, on: boolean)
		local before = next(controlHolds) ~= nil
		controlHolds[owner] = if on then true else nil
		local after = next(controlHolds) ~= nil
		if before == after then
			return
		end
		local c = playerControls()
		if c then
			pcall(function()
				if after then
					c:Disable()
				else
					c:Enable()
				end
			end)
		end
	end

	-- 2026-09-26 (owner): at the event's end every hold goes, whoever took it (a shot or a freeze cut short).
	function Cinema.ReleaseControls()
		table.clear(controlHolds)
		local c = playerControls()
		if c then
			pcall(function()
				c:Enable()
			end)
		end
	end

	function Cinema.Allowed(): boolean
		if Cinema.active or killed() or not state.active then
			return false
		end
		local _, humanoid, root = localCharacter()
		if not (humanoid and root) or humanoid.Health <= 0 or not Workspace.CurrentCamera then
			return false
		end
		if player:GetAttribute("RaceActive") == true or player:GetAttribute("WorldPortalCinematicActive") == true
			or player:GetAttribute("AdminTreadmillCinematicActive") == true or InterfaceHider.IsHidden(Fx.InterfaceOwner) then
			return false
		end
		return eventArea(root.Position, true)
	end

	-- extra = { boss = (t) -> Vector3, spot = Vector3?, length = number?, cues = { { t, run } }?, onEnd = fn? }
	function Cinema.Play(kind: string, extra: any): boolean
		if not Cinema.Allowed() then
			return false
		end
		local camera = Workspace.CurrentCamera :: Camera
		local _, _, root = localCharacter()
		local rootNow = (root :: BasePart).Position
		local view = camera.ViewportSize
		local phone = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
		local job = {
			kind = kind,
			start = os.clock(),
			length = Cine.Length(kind, extra.length),
			saved = { CameraType = camera.CameraType, CameraSubject = camera.CameraSubject, FieldOfView = camera.FieldOfView },
			guard = { deficit = 0 }, -- (v3) Cine.Guard's state
			ctx = {
				startCam = camera.CFrame,
				startFov = camera.FieldOfView, -- (v3) from the player's own field of view, back to it
				endFov = camera.FieldOfView,
				clear = clearDistance,
				crash = extra.crash,
				root = function(): Vector3
					local _, _, r = localCharacter()
					if r then
						rootNow = r.Position
					end
					return rootNow
				end,
				rootAtStart = rootNow,
				boss = extra.boss,
				spot = extra.spot,
				origin = extra.origin or state.origin,
				floorY = (extra.origin or state.origin).Y - 3,
				length = extra.length,
			},
			cues = extra.cues or {},
			bars = CinematicFit.Bars(view.X, view.Y, phone),
			onEnd = extra.onEnd,
		}
		Cinema.active = job
		player:SetAttribute(Fx.CinematicAttribute, true)
		Screen.Build()
		InterfaceHider.Hide(Fx.InterfaceOwner, { Screen.Gui() })
		Cinema.HoldControls("Cinema", true)
		Charge.Cancel()
		syncInputBinding()
		camera.CameraType = Enum.CameraType.Scriptable
		RunService:BindToRenderStep(Fx.RenderName, Enum.RenderPriority.Camera.Value + 1, Cinema.Step)
		return true
	end

	function Cinema.Step(_dt: number?)
		local job = Cinema.active
		if not job then
			pcall(function()
				RunService:UnbindFromRenderStep(Fx.RenderName)
			end)
			return
		end
		local ok, problem = pcall(function()
			local t = os.clock() - job.start
			if t >= job.length or t > Cine.MaxSeconds or killed() or not state.active then
				Cinema.Stop("done")
				return
			end
			local camera = Workspace.CurrentCamera
			if not camera then
				return
			end
			camera.CameraType = Enum.CameraType.Scriptable
			local cf, fov = Cine.Frame(job.kind, t, job.ctx, CFrame)
			-- (v3) kept clear of walls: snapped in front of one at once, eased back out.
			local lookAt = cf.Position + cf.LookVector * math.min(Cine.LookDistance, 24)
			local eye = Cine.Guard(cf.Position, lookAt, clearDistance(lookAt, cf.Position), job.guard, _dt or 1 / 60)
			if eye ~= cf.Position then
				cf = cf.Rotation + eye
			end
			camera.CFrame = cf
			camera.FieldOfView = fov
			Screen.SetBars(Cine.Bars(t, job.length, job.bars))
			for _, cue in job.cues do
				if not cue.fired and t >= cue.t then
					cue.fired = true
					cue.run()
				end
			end
		end)
		if not ok then
			warn("[SuperSonicEventClient] cinematic: " .. tostring(problem))
			Cinema.Stop("error")
		end
	end

	-- Everything back: the camera's type (a Scriptable one saved means Custom) and subject (the current humanoid),
	-- its field of view, the controls, the interface, the bars, the homing input.
	function Cinema.Stop(reason: string?)
		local job = Cinema.active
		pcall(function()
			RunService:UnbindFromRenderStep(Fx.RenderName)
		end)
		if not job then
			return
		end
		Cinema.active = nil
		local camera = Workspace.CurrentCamera
		if camera then
			pcall(function()
				local saved = job.saved
				camera.CameraType = if saved.CameraType == Enum.CameraType.Scriptable or saved.CameraType == nil then Enum.CameraType.Custom else saved.CameraType
				local _, humanoid = localCharacter()
				camera.CameraSubject = humanoid or saved.CameraSubject
				camera.FieldOfView = saved.FieldOfView or Cine.Fov
			end)
		end
		Cinema.HoldControls("Cinema", false)
		InterfaceHider.Show(Fx.InterfaceOwner)
		Screen.SetBars(0)
		player:SetAttribute(Fx.CinematicAttribute, nil)
		syncInputBinding()
		if job.onEnd then
			pcall(job.onEnd, reason)
		end
	end
end)()

----------------------------------------------------------------------
-- The game's HUD during the event (2026-09-26, owner, v3): "hide the other UIs during the event like when a
-- menu is open, except the topbar buttons". While an event runs and the local root is in its area, the HUD is
-- held away with MenuEvents.SetHUDVisible(false, Fx.HudHide.MenuName) (the Main HUD's pieces, the Starter
-- Pack, the Sonic Burst / Heat Vision buttons, the speedometer slide off, as for a menu); TopbarPlus and
-- Roblox's top bar stay, and the menus they open work. When the HUD asks to come back meanwhile (a menu the
-- player opened closes, a respawn) the hold asks again (deferred: after the HUD's own check). Leaving the area,
-- the end of the event, the kill switch: SetHUDVisible(true) once.
----------------------------------------------------------------------
local HudHide = {} :: any
;(function() -- (a function, not a do-block: see the note at the top)
	local holding = false

	local function setVisible(visible: boolean)
		if MenuEvents and MenuEvents.SetHUDVisible then
			pcall(MenuEvents.SetHUDVisible, visible, if visible then nil else Fx.HudHide.MenuName)
		end
	end

	function HudHide.Update()
		local want = Fx.HudHideWanted(state.active and not killed(), state.phase, state.inEvent, player:GetAttribute("RaceActive") == true)
		if want and not holding then
			holding = true
			setVisible(false)
		elseif not want and holding then
			holding = false
			setVisible(true)
		end
	end

	function HudHide.Release()
		if holding then
			holding = false
			setVisible(true)
		end
	end

	function HudHide.Holding(): boolean
		return holding
	end

	if MenuEvents and MenuEvents.HUDVisibilityChanged then
		MenuEvents.HUDVisibilityChanged.Event:Connect(function(visible, menuName)
			if visible == true then
				hud.menuOpen = false
				if holding then
					task.defer(function()
						if holding then
							setVisible(false)
						end
					end)
				end
			elseif menuName ~= nil and menuName ~= Fx.HudHide.MenuName then
				-- A menu of the game opened (its own request): the touch button makes way.
				hud.menuOpen = true
			end
		end)
	end
end)()

----------------------------------------------------------------------
-- The freeze (2026-09-26, owner, v3): inside the contract's freeze windows (SSE.IsFrozen: the intro, the
-- emeralds' shot, the outro) the local player stands still while its root is in the event's area, so nobody
-- interrupts the animation or falls: the charge and the flight end, the root is anchored LOCALLY (the client owns
-- its character: the server just sees it stand; Movement/InstantMovementController stands aside for an anchored
-- root), its velocity zeroed, the controls held off; everything exactly back after (a respawn inside a window
-- moves the hold to the new body).
----------------------------------------------------------------------
local Freeze = {} :: any
;(function() -- (a function, not a do-block: see the note at the top)
	local held: { root: BasePart, anchored: boolean }? = nil

	function Freeze.Release()
		local h = held
		held = nil
		if not h then
			return
		end
		if h.root.Parent then
			h.root.Anchored = h.anchored
			h.root.AssemblyLinearVelocity = Vector3.zero
			h.root.AssemblyAngularVelocity = Vector3.zero
		end
		Cinema.HoldControls("Freeze", false)
		player:SetAttribute(Fx.FreezeAttribute, nil)
	end

	function Freeze.Update(now: number)
		local _, humanoid, root = localCharacter()
		local pos = if state.phase == PHASE.Return then state.returnPos else (root and root.Position)
		local want = state.active and not killed() and Fx.FreezeWanted(state.phase, now - state.phaseStart, pos, state.origin, state.lobbyOrigin)
		if not (want and humanoid and root and humanoid.Health > 0) then
			if held then
				Freeze.Release()
			end
			return
		end
		if held and held.root ~= root then
			Freeze.Release() -- (a new body: the old one's hold goes, the new one is held)
		end
		if held then
			return
		end
		Charge.Cancel()
		endFlight(nil)
		held = { root = root, anchored = root.Anchored }
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		root.Anchored = true
		Cinema.HoldControls("Freeze", true)
		player:SetAttribute(Fx.FreezeAttribute, true)
	end

	function Freeze.Active(): boolean
		return held ~= nil
	end
end)()

----------------------------------------------------------------------
-- The invite (2026-09-26, owner, v3): { "Invite", eventId, why } for a player outside the event's area (at
-- the start, out of a race, joining mid-event): a small OPTIONAL card in the game's style, "Dr. Eggman is
-- attacking! Join the event?" YES / NO (en / es / pt), gamepad-selectable. YES sends { "TeleportToEvent",
-- eventId } (the server moves the player: TeleportGo / TeleportNo close the card). It closes itself when the
-- invite no longer holds (Fx.InviteShown: SSE.InviteOpen, the same event, the root not in the area), on NO,
-- or after Fx.Invite.Seconds (then, like a NO, it never comes back for that event).
----------------------------------------------------------------------
local Invite = {} :: any
;(function() -- (a function, not a do-block: see the note at the top)
	local gui: ScreenGui? = nil
	local fit: UIScale? = nil
	local yesButton: TextButton? = nil
	local offer: any = nil -- { eventId, at }
	local declined: any = nil -- the event id the player turned down (or let pass)
	local checkConnection: RBXScriptConnection? = nil
	local nextCheck = 0

	local function make(className: string, props: { [string]: any }, parent: Instance?): any
		local instance = Instance.new(className)
		for key, value in props do
			(instance :: any)[key] = value
		end
		if parent then
			instance.Parent = parent
		end
		return instance
	end

	local function words(label: TextLabel, thickness: number)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextScaled = true
		make("UIStroke", { Color = rgb(Fx.Style.Ink), Thickness = thickness, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
			LineJoinMode = Enum.LineJoinMode.Round }, label)
		TutorialText.Style(label, lang)
	end

	-- The designer's button: a 3-stop gradient fill, a light rim, a dark edge, white FredokaOne words.
	local function button(name: string, text: string, stops: { { number } }, parent: Instance): TextButton
		local b = make("TextButton", { Name = name, AutoButtonColor = true, BackgroundColor3 = Color3.new(1, 1, 1), Text = "",
			Selectable = true, ZIndex = 3 }, parent)
		make("UICorner", { CornerRadius = UDim.new(0, 10) }, b)
		make("UIGradient", { Rotation = 90, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, rgb(stops[1])),
			ColorSequenceKeypoint.new(0.5, rgb(stops[2])), ColorSequenceKeypoint.new(1, rgb(stops[3])) }) }, b)
		make("UIStroke", { Color = rgb(Fx.Style.Ink), Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, b)
		local label = make("TextLabel", { Name = "Label", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.8, 0.62), Text = text, ZIndex = 4 }, b)
		words(label, 2)
		return b
	end

	local function stopChecks()
		if checkConnection then
			checkConnection:Disconnect()
			checkConnection = nil
		end
	end

	function Invite.Hide()
		stopChecks()
		offer = nil
		if gui then
			pcall(function()
				local selected = GuiService.SelectedObject
				if selected and selected:IsDescendantOf(gui :: ScreenGui) then
					GuiService.SelectedObject = nil
				end
			end)
			gui:Destroy()
			gui, fit, yesButton = nil, nil, nil
		end
	end

	local function answer(yes: boolean)
		local o = offer
		if not o then
			return
		end
		if yes then
			if remote then
				remote:FireServer({ MSG.TeleportToEvent, o.eventId })
			end
		else
			declined = o.eventId
		end
		Invite.Hide()
	end

	local function build()
		if gui then
			return
		end
		local W, H = Fx.Invite.Width, Fx.Invite.Height
		local screen = make("ScreenGui", { Name = Fx.InviteGuiName, ResetOnSpawn = false, IgnoreGuiInset = false, DisplayOrder = 30,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Enabled = true })
		local card = make("Frame", { Name = "Card", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, Fx.Invite.Top),
			Size = UDim2.fromOffset(W, H), BackgroundColor3 = rgb(Fx.Style.Plate), BackgroundTransparency = 0.06, BorderSizePixel = 0, ZIndex = 2 }, screen)
		make("UICorner", { CornerRadius = UDim.new(0, 14) }, card)
		make("UIStroke", { Color = rgb(Fx.Style.Ink), Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, card)
		fit = make("UIScale", { Name = "Fit" }, card)
		local title = make("TextLabel", { Name = "Title", Position = UDim2.fromOffset(14, 10), Size = UDim2.new(1, -28, 0, 50),
			Text = Fx.Word(lang, "Invite"), TextWrapped = true, ZIndex = 3 }, card)
		words(title, 2)
		make("UITextSizeConstraint", { MaxTextSize = 24 }, title)
		local yes = button("Yes", Fx.Word(lang, "InviteYes"), Fx.Style.Yes, card)
		yes.AnchorPoint = Vector2.new(1, 1)
		yes.Position = UDim2.new(0.5, -8, 1, -12)
		yes.Size = UDim2.fromOffset(120, 44)
		local no = button("No", Fx.Word(lang, "InviteNo"), Fx.Style.No, card)
		no.AnchorPoint = Vector2.new(0, 1)
		no.Position = UDim2.new(0.5, 8, 1, -12)
		no.Size = UDim2.fromOffset(120, 44)
		yes.NextSelectionRight = no
		no.NextSelectionLeft = yes
		yes.Activated:Connect(function()
			answer(true)
		end)
		no.Activated:Connect(function()
			answer(false)
		end)
		screen.Parent = playerGui
		gui, yesButton = screen, yes
	end

	local function fitCard()
		local camera = Workspace.CurrentCamera
		local view = if camera then camera.ViewportSize else Vector2.new(1280, 720)
		if fit then
			fit.Scale = math.clamp(math.min(view.X * 0.9 / Fx.Invite.Width, view.Y * 0.4 / Fx.Invite.Height, 1), Fx.Invite.MinScale, 1)
		end
	end

	local function rootInArea(): boolean
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not (root and root:IsA("BasePart")) then
			return false
		end
		local origin = readOrigin()
		local lobby = Workspace:GetAttribute(ATTR.LobbyOrigin)
		local phase = SSE.NormalizePhase(Workspace:GetAttribute(ATTR.Phase))
		local start = tonumber(Workspace:GetAttribute(ATTR.PhaseStart)) or Workspace:GetServerTimeNow()
		return SSE.InEventArea(root.Position, origin, if typeof(lobby) == "Vector3" then lobby else nil,
			SSE.Moved(phase, Workspace:GetServerTimeNow() - start), true)
	end

	local function stillOpen(): boolean
		local o = offer
		if not o or killed() then
			return false
		end
		if os.clock() - o.at > Fx.Invite.Seconds then
			declined = o.eventId -- (let pass: as a NO, never again this event)
			return false
		end
		return Fx.InviteShown(o.eventId, Workspace:GetAttribute(ATTR.EventId), SSE.NormalizePhase(Workspace:GetAttribute(ATTR.Phase)),
			rootInArea(), declined)
	end

	-- { "Invite", eventId, why }: the card (unless this event was turned down, or it no longer holds).
	function Invite.Offer(eventId: any, _why: any)
		if eventId == nil or eventId == declined then
			return
		end
		offer = { eventId = eventId, at = os.clock() }
		if not stillOpen() then
			offer = nil
			return
		end
		build()
		fitCard()
		-- A gamepad: YES is selected at once (A answers it; B / the other button: NO).
		pcall(function()
			local last = UserInputService:GetLastInputType()
			if string.sub(last.Name, 1, 7) == "Gamepad" and yesButton and GuiService.SelectedObject == nil then
				GuiService.SelectedObject = yesButton
			end
		end)
		stopChecks()
		nextCheck = 0
		checkConnection = RunService.RenderStepped:Connect(function()
			local clock = os.clock()
			if clock < nextCheck then
				return
			end
			nextCheck = clock + 1 / Fx.Invite.CheckHz
			if not stillOpen() then
				Invite.Hide()
			end
		end)
	end

	-- For the tests and the frame loop: whether the card is up.
	function Invite.Shown(): boolean
		return gui ~= nil
	end
end)()

----------------------------------------------------------------------
-- The race map as a plain map (2026-09-26, owner, v3): while an event runs this client hides the race-only
-- pieces of Workspace.RaceArena (Fx.ArenaHide / Fx.ArenaRaceOnly: the start gantry and lights, the start / stop
-- bars, the arches over the track, the orb, the speed pads and their art, the spike tiles, the race signs) and
-- puts every one back exactly after (its LocalTransparencyModifier, CanCollide and Enabled as they were). The
-- arena streams in piece by piece: the first pass takes what is there, DescendantAdded the rest.
----------------------------------------------------------------------
local ArenaHide = {} :: any
;(function() -- (a function, not a do-block: see the note at the top)
	local arena: Instance? = nil
	local added: RBXScriptConnection? = nil
	local transparency: { [Instance]: number } = {}
	local collide: { [Instance]: boolean } = {}
	local enabled: { [Instance]: boolean } = {}
	local chain: { string } = {}

	local function raceOnly(d: Instance): boolean
		local sign = d:IsA("BillboardGui") or d:IsA("SurfaceGui")
		table.clear(chain)
		local node: Instance? = d
		while node and node ~= arena do
			table.insert(chain, node.Name)
			node = node.Parent
		end
		return Fx.ArenaRaceOnly(chain, d:GetAttribute(Fx.ArenaHide.Attribute) == true, sign)
	end

	local function hide(d: Instance)
		if not raceOnly(d) then
			return
		end
		if d:IsA("BasePart") then
			if transparency[d] == nil then
				transparency[d] = d.LocalTransparencyModifier
			end
			d.LocalTransparencyModifier = 1
			if collide[d] == nil then
				collide[d] = d.CanCollide
			end
			if d.CanCollide then
				d.CanCollide = false
			end
		elseif d:IsA("Decal") then
			if transparency[d] == nil then
				transparency[d] = (d :: any).LocalTransparencyModifier
			end
			(d :: any).LocalTransparencyModifier = 1
		elseif d:IsA("Beam") or d:IsA("ParticleEmitter") or d:IsA("Light") or d:IsA("Trail") or d:IsA("BillboardGui") or d:IsA("SurfaceGui") then
			if enabled[d] == nil then
				enabled[d] = (d :: any).Enabled
			end
			(d :: any).Enabled = false
		end
	end

	-- Every piece exactly back (the end of the event, the kill switch, another arena).
	function ArenaHide.Restore()
		if added then
			added:Disconnect()
			added = nil
		end
		for piece, value in transparency do
			if piece.Parent then
				(piece :: any).LocalTransparencyModifier = value
			end
		end
		for piece, value in collide do
			if piece.Parent then
				(piece :: any).CanCollide = value
			end
		end
		for piece, value in enabled do
			if piece.Parent then
				(piece :: any).Enabled = value
			end
		end
		table.clear(transparency)
		table.clear(collide)
		table.clear(enabled)
		arena = nil
	end

	-- From the event's start and the sweep (never per frame): the arena found once, its race pieces hidden.
	function ArenaHide.Apply()
		local found = Workspace:FindFirstChild(Fx.ArenaHide.ArenaName)
		if found == arena then
			return
		end
		ArenaHide.Restore()
		arena = found
		if not found then
			return
		end
		for _, d in found:GetDescendants() do
			hide(d)
		end
		added = found.DescendantAdded:Connect(function(d)
			if state.active and arena == found then
				hide(d)
			end
		end)
	end

	function ArenaHide.Hidden(piece: Instance): boolean
		return transparency[piece] ~= nil or enabled[piece] ~= nil
	end
end)()

----------------------------------------------------------------------
-- The beats (2026-09-26, owner, v3): the fight moved to the race map. The Teleport beat (after the Cinematic in
-- the lobby) and the Return beat (after the Defeat / Escape) fade this client's screen to black (Fx.BeatFade on
-- SSE.Beats) when the trip moves its player (the Teleport: a root in the lobby area; the Return: a root in the
-- arena), keep it black until the root has really arrived (the server moves it at MoveAt; at most
-- Fx.Beat.HoldMax), and fade back in. The map is streamed in round the destination first (Beat.Stream:
-- RequestStreamAroundAsync, from the Cinematic on for the arena, from the Return's start for the lobby). After
-- the Teleport's black, Eggman flies into the arena on camera (the Entry shot), then the controls come back.
-- In the Return beat every client brings the lobby's Eggman back at his spot (Beats.Return.LobbyEggman).
----------------------------------------------------------------------
local Beat = {} :: any
;(function() -- (a function, not a do-block: see the note at the top)
	local job: any = nil -- { phase, start, mine, live, arrivedAt, entry, lobby }

	-- The engine streams the map in round `position` (on its own thread: the call yields).
	function Beat.Stream(position: any)
		if typeof(position) ~= "Vector3" then
			return
		end
		task.spawn(function()
			pcall(function()
				(player :: any):RequestStreamAroundAsync(position, Fx.Beat.StreamTimeout)
			end)
		end)
	end

	-- The trip's destination reached: the Teleport's arena, the Return's lobby.
	local function arrived(phase: string, root: BasePart?): boolean
		if not root then
			return false
		end
		if phase == PHASE.Teleport then
			return arenaZone(root.Position, true)
		end
		return SSE.InLobby(root.Position, state.lobbyOrigin or state.origin, true)
	end

	function Beat.Reset()
		job = nil
		Screen.SetFade(0)
	end

	-- Every frame while an event runs.
	function Beat.Update(now: number)
		local phase = state.phase
		local beat = (SSE.Beats :: any)[phase]
		if not beat then
			if job then
				Beat.Reset()
			end
			return
		end
		local t = now - state.phaseStart
		if not job or job.phase ~= phase or job.start ~= state.phaseStart then
			local _, _, root = localCharacter()
			local mine = false
			if root and arenaMode() then -- (a fight in the lobby itself: the beats move nobody)
				if phase == PHASE.Teleport then
					mine = SSE.InLobby(root.Position, state.lobbyOrigin or state.origin, true)
				else
					mine = arenaZone(root.Position, true)
				end
			end
			-- (a moment this client saw begin: never a black screen or the entry for one who joins mid-beat)
			job = { phase = phase, start = state.phaseStart, mine = mine and t < beat.MoveAt, live = t < 1, arrivedAt = nil,
				entry = false, lobby = false }
		end
		if phase == PHASE.Return and not job.lobby and t >= (tonumber(beat.LobbyEggman) or 0) then
			-- The lobby's Eggman back at his spot for everyone who comes home.
			job.lobby = true
			boss.lobbyBack = true
			restoreLobby(tonumber(beat.LobbyEggmanFade) or Fx.Boss.LobbyFadeSeconds)
		end
		if not job.mine then
			Screen.SetFade(0)
			return
		end
		if not job.arrivedAt and t >= beat.MoveAt then
			local _, _, root = localCharacter()
			if arrived(phase, root) then
				job.arrivedAt = t
			end
		end
		Screen.SetFade(Fx.BeatFade(beat, t, job.arrivedAt))
		if phase == PHASE.Teleport and job.live and job.arrivedAt and not job.entry and t >= job.arrivedAt + 0.05 then
			job.entry = true
			local remaining = (tonumber(SSE.Durations.Teleport) or 4.5) - t - 0.15
			if remaining > 1.5 then
				local serverStart = now
				Cinema.Play("Entry", {
					boss = function(x: number): Vector3
						return planPosition(serverStart + x)
					end,
					length = remaining,
				})
			end
		end
	end
end)()

----------------------------------------------------------------------
-- The remote
----------------------------------------------------------------------
local onPhaseChanged
;(function() -- (a function, not a do-block: see the note at the top)
	local function onMessage(message: any)
		if type(message) ~= "table" or killed() then
			return
		end
		-- The rings outlive the event (they stay until their expireTime; a late joiner gets them too).
		local first = message[1]
		if first == MSG.Rings then
			Rings.OnRings(message[2], message[3], message[4], message[5], message[6], message[7], message[8])
			return
		elseif first == MSG.RingGone then
			Rings.Gone(message[2], message[3])
			return
		elseif first == MSG.RingNo then
			Rings.No(message[2], message[3])
			return
		elseif first == MSG.RingsClear then
			Rings.Clear()
			return
		elseif first == MSG.Invite then
			-- (v3) the optional card (this player is outside the event's area)
			Invite.Offer(message[2], message[3])
			return
		elseif first == MSG.TeleportGo or first == MSG.TeleportNo then
			-- (v3) the trip is on (the server moves the character) or refused: the card goes either way
			Invite.Hide()
			if first == MSG.TeleportGo then
				Beat.Stream(message[3])
			end
			return
		end
		if not state.active then
			onPhaseChanged()
			if not state.active then
				return
			end
		end
		local name = message[1]
		if name == MSG.Bomb then
			onBomb(message[2], message[3], message[4], message[5], message[6], message[7], message[8])
		elseif name == MSG.BombHit then
			onBombHit(message[2], message[3])
		elseif name == MSG.Hit then
			onHit(message[2], message[3], message[4], message[5], message[6], message[7], message[8])
		elseif name == MSG.Reward then
			if message[4] == "ring" then
				showReward(message[2], message[3], Fx.Word(lang, "Ring") .. "  " .. Fx.RewardText(lang, message[2], message[3]))
			else
				showReward(message[2], message[3])
			end
		elseif name == MSG.Defeat then
			-- (v3) { "Defeat", crashPoint, impactTime }: the crash (no banner, no dialogue)
			startDefeat(message[2], message[3])
			announce("ChatDefeat")
		elseif name == MSG.Escape then
			startFlee(false)
			announce("ChatEscape")
		elseif name == MSG.HomingGo then
			onHomingGo(message[2], message[3], message[4], message[5], message[6], message[9])
		elseif name == MSG.HomingNo then
			-- Refused: v3 "Shielded" comes at the arrival (the bounce and his taunt); the rest drop the ball at once.
			Charge.Refused(message[2])
		elseif name == MSG.ShieldHit then
			onShieldHit(message[2], message[3])
		elseif name == MSG.Knock then
			-- (v2) a throw cancels the charge and the flight; (v3) kind "Shield": the bounce off his shield.
			Charge.Knock(message[2], message[4])
		end
	end

	task.spawn(function()
		local remotes = ReplicatedStorage:WaitForChild(SSE.RemotesFolder, 120)
		if not remotes then
			return
		end
		local found = remotes:WaitForChild(SSE.RemoteName, 120)
		while not (found and found:IsA("RemoteEvent")) do
			found = remotes.ChildAdded:Wait()
			if found.Name ~= SSE.RemoteName then
				found = nil
			end
		end
		remote = found :: RemoteEvent
		(found :: RemoteEvent).OnClientEvent:Connect(onMessage)
	end)
end)()

----------------------------------------------------------------------
-- The loops (connected only while an event runs)
----------------------------------------------------------------------
local nextSweep, startSweeps, onStepped, onRender, cueState
;(function() -- (a function, not a do-block: see the note at the top)
	nextSweep = 0
	-- The contract's dialogue cues of the current phase (SSE.DialogueFor), played on the server clock.
	cueState = { list = {} :: { { t: number, key: string } }, index = 1 }

	local function setTier(newTier: string)
		if newTier == tier then
			return
		end
		tier = newTier
		budget = Fx.Budget(tier)
		boss.vfxTier = nil
		buildBossVfx()
		-- The looks are rebuilt at their new level by the next sweep.
		for target in looks do
			-- (The local look waits for the end of a homing flight: the ball hides its pieces.)
			if target ~= player or flight == nil then
				removeLook(target)
			end
		end
		nextSweep = 0
	end

	-- Every Fx.SweepSeconds while an event runs, on its own thread (never in a frame callback): the lobby
	-- NPC hidden again, the boss (re)built if it streamed in, the looks re-ranked, the emerald sets, the inputs,
	-- the lobby's smoke and fires, the rings drawn, the portrait, a cinematic past its watchdog.
	local function sweep()
		if not boss.lobbyBack then
			hideLobby()
		end
		local hadModel = boss.model
		ensureBoss()
		if boss.model ~= hadModel then
			Screen.SetPortrait(boss.model)
		end
		refreshAllLooks()
		refreshEmeraldSets()
		syncInputBinding()
		Chaos.Prewarm()
		ArenaHide.Apply()
		prewarmRigs("Muzzle", 2)
		if Cinema.active and os.clock() - Cinema.active.start > Cine.MaxSeconds then
			Cinema.Stop("watchdog")
		end
	end

	local sweepSerial = 0
	function startSweeps()
		sweepSerial += 1
		local serial = sweepSerial
		task.spawn(function()
			while state.active and serial == sweepSerial do
				nextSweep = os.clock() + Fx.SweepSeconds -- (setTier sets it to 0: the next sweep comes at once)
				local ok, problem = pcall(sweep)
				if not ok then
					warn("[SuperSonicEventClient] sweep: " .. tostring(problem))
				end
				while state.active and serial == sweepSerial and os.clock() < nextSweep do
					task.wait(0.1)
				end
			end
		end)
	end

	-- 2026-09-26 (owner, v2): Eggman's windows in the Battle (SSE.BossState on the server clock): the cannon out
	-- and his attack call for an Attack, the cannon in, the panic and the "!" for a Reload.
	local function updateBossState(now: number)
		if state.phase ~= PHASE.Battle then
			if state.bossState ~= "" then
				state.bossState = ""
				bossGesture(nil, true)
			end
			return
		end
		local name, start = SSE.BossState(now - state.phaseStart, state.seed)
		if name == state.bossState then
			return
		end
		state.bossState = name
		state.bossStateStart = state.phaseStart + math.max(start, 0)
		state.bossWindow += 1
		playSound("CannonMove", distanceFromCamera(boss.frame.Position))
		if name == SSE.BossStates.Reload then
			bossGesture("Reload", true)
			if state.bossWindow <= 4 or state.bossWindow % 3 == 0 then
				Screen.Say(SSE.Taunts.Reload, 6)
			end
		else
			bossGesture(nil, true)
			bossGesture("Point")
			if state.bossWindow > 1 and state.bossWindow % 2 == 1 then
				Screen.Say(SSE.Taunts.Attack, 6)
			end
		end
	end

	local function updateCues(now: number)
		local cue = cueState.list[cueState.index]
		while cue and now - state.phaseStart >= cue.t do
			cueState.index += 1
			-- A cue missed by more than 2 s (a player who joined later) is skipped.
			if now - state.phaseStart - cue.t < 2 then
				Screen.Say(cue.key)
			end
			cue = cueState.list[cueState.index]
		end
	end

	function onStepped(_: number, dt: number)
		RaceFeelTier.Sample(meter, dt)
		tierClock += dt
		if tierClock >= Fx.TierSeconds then
			tierClock = 0
			setTier((RaceFeelTier.Detect(meter)))
		end
		local now = serverNow()
		-- 2026-09-26 (owner, v3): the root in the event's area (the HUD hold, the freeze, the chaos zone), the
		-- freeze windows (before physics: the root anchored / let go).
		refreshArena()
		Freeze.Update(now)
		updateBossState(now)
		updateBoss(now, os.clock())
	end

	function onRender(dt: number)
		local now, clock = serverNow(), os.clock()
		updateCues(now)
		updateBombs(now, clock)
		updateEmeralds(now)
		Charge.Update(clock, dt)
		updateBall(dt)
		updateOtherFlights(now, dt)
		updateFires(clock)
		Chaos.Update(now, dt)
		updateHud(clock, dt)
		Screen.Update(clock)
		Screen.Vignette(if player:GetAttribute(PATTR.Super) == true and state.phase == PHASE.Battle then 1 else 0, clock, dt)
		-- 2026-09-26 (owner, v3): the game's HUD held away in the event's area; the chaos zone for the sky layer.
		HudHide.Update()
		Beat.Update(now)
		Music.Want(state.inEvent)
		local zone = if state.inArena then true else nil
		if player:GetAttribute(Fx.ChaosZoneAttribute) ~= zone then
			player:SetAttribute(Fx.ChaosZoneAttribute, zone)
		end
	end
end)()

----------------------------------------------------------------------
-- The event's life
----------------------------------------------------------------------
;(function() -- (a function, not a do-block: see the note at the top)
	-- 2026-09-26 (owner, v2): the runtime folder of an event that ended is not destroyed at once (its particles
	-- would vanish in a frame): its emitters stop and its pieces fade, and it goes once they have died out.
	local function retire(folder: Folder, instant: boolean)
		if instant then
			folder:Destroy()
			return
		end
		folder.Name = Fx.RetiringName
		local pieces = {}
		for _, d in folder:GetDescendants() do
			if d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") or d:IsA("Light") then
				(d :: any).Enabled = false
			elseif d:IsA("BasePart") and d.Transparency < 1 then
				table.insert(pieces, d)
			end
		end
		local start = os.clock()
		local connection: RBXScriptConnection? = nil
		connection = RunService.RenderStepped:Connect(function()
			local k = (os.clock() - start) / 0.6
			for _, part in pieces do
				if part.Parent then
					part.LocalTransparencyModifier = math.clamp(k, 0, 1)
				end
			end
			if os.clock() - start >= 2.5 or not folder.Parent then
				if connection then
					connection:Disconnect()
				end
				folder:Destroy()
			end
		end)
	end

	local function beginEvent()
		state.active = true
		state.firstPhase = ""
		table.clear(state.watched)
		state.bossState, state.bossWindow = "", 0
		refreshPlan()
		buildHud()
		if hud.gui then
			hud.gui.Enabled = true
		end
		prewarmSounds()
		resetBurn(os.clock())
		refreshArena()
		Screen.Build()
		Music.Want(state.inEvent)
		ArenaHide.Apply()
		ensureBoss()
		Screen.SetPortrait(boss.model)
		hideLobby()
		boss.nextTaunt = os.clock() + 3
		nextSweep = 0
		startSweeps()
		if not steppedConnection then
			steppedConnection = RunService.Stepped:Connect(onStepped)
		end
		if not renderConnection then
			renderConnection = RunService.RenderStepped:Connect(onRender)
		end
	end

	-- Everything away and back as it was: phase "", the kill switch, a new event.
	local function endEvent()
		local instant = killed()
		local lobbyBack = boss.lobbyBack
		state.active = false
		state.phase = ""
		Cinema.Stop("end")
		-- 2026-09-26 (owner, v3): the freeze, the HUD hold, the invite and the chaos zone all let go.
		Freeze.Release()
		-- 2026-09-26 (owner: "the jump doesn't come back after the event"): the controls on, jumping enabled, no
		-- PlatformStand (unless the game's ragdoll holds the body) and a zeroed jump back to the place's values,
		-- whatever path cut a hold short (a shot, a freeze, a homing flight, a bomb's ragdoll, a race pulled out).
		Cinema.ReleaseControls()
		do
			local character, humanoid = localCharacter()
			if humanoid then
				local ragdolled = character ~= nil and character:GetAttribute("Ragdolled") == true
				pcall(function()
					if not ragdolled then
						humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
						humanoid.PlatformStand = false
					end
					local starter = game:GetService("StarterPlayer")
					if humanoid.UseJumpPower and humanoid.JumpPower <= 0 then
						humanoid.JumpPower = starter.CharacterJumpPower
					elseif not humanoid.UseJumpPower and humanoid.JumpHeight <= 0 then
						humanoid.JumpHeight = starter.CharacterJumpHeight
					end
				end)
			end
		end
		HudHide.Release()
		Invite.Hide()
		Beat.Reset()
		ArenaHide.Restore()
		player:SetAttribute(Fx.ChaosZoneAttribute, nil)
		state.inArena, state.inEvent, state.returnPos = false, false, nil
		if steppedConnection then
			steppedConnection:Disconnect()
			steppedConnection = nil
		end
		if renderConnection then
			renderConnection:Disconnect()
			renderConnection = nil
		end
		syncInputBinding()
		-- Eggman still flying away (the event ended before he was gone): he finishes his flight fading into the
		-- horizon, then the lobby's Eggman fades back in. Not under the kill switch: then everything goes now.
		local outro = if instant then nil else detachFleeingBoss()
		destroyFlights()
		destroyBombs()
		destroyEmeralds()
		if instant then
			Rings.Destroy() -- (otherwise the rings stay out until their expireTime: their own loop)
		end
		Chaos.Finish(instant)
		destroyRigs()
		destroyFires()
		removeAllLooks()
		destroyBoss()
		Screen.Destroy()
		Music.Stop(instant)
		if outro then
			-- (the lobby's Eggman stays hidden: he fades back in when the outro ends)
			lingerHud(2.5)
			runOutro(outro, function()
				if not state.active and not lobbyBack then
					restoreLobby(Fx.Boss.LobbyFadeSeconds)
				end
			end)
		else
			-- (v3: the crash brought him back already; the kill switch puts every piece back at once)
			if instant or not lobbyBack then
				restoreLobby(if instant then 0 else Fx.Boss.LobbyFadeSeconds)
			end
			destroyHud()
		end
		destroySounds()
		buttonShown = false
		if runtime then
			retire(runtime, instant)
			runtime = nil
		end
	end

	-- A cinematic's boss path: seconds into the shot -> the ship's centre then.
	local function bossPathFrom(serverStart: number): (number) -> Vector3
		return function(t: number): Vector3
			return planPosition(serverStart + t)
		end
	end

	local function onPhaseEnter(phase: string, previous: string)
		local _, _, root = localCharacter()
		local near = root ~= nil and (root.Position - state.origin).Magnitude < 900
		local now = serverNow()
		local age = now - state.phaseStart
		-- A moment this client saw begin (never a cinematic for a player who joins mid-event).
		local live = age < 1.5 and (previous ~= "" or phase == PHASE.Cinematic)
		if state.firstPhase == "" then
			state.firstPhase = phase
		end
		-- 2026-09-26 (owner, v3): no dialogue in the Defeat (the crash speaks for itself).
		cueState.list = if phase == PHASE.Defeat then {} else SSE.DialogueFor(phase)
		cueState.index = 1
		if phase == PHASE.Cinematic then
			boss.nextTaunt = os.clock() + SSE.Durations.Cinematic
			if previous == "" then
				announce("ChatStart")
			end
			-- (v3) the fight is on the race map: stream it in while the Cinematic plays in the lobby.
			if arenaMode() and state.inEvent then
				Beat.Stream(state.origin)
			end
			if live then
				local lift = Workspace:GetAttribute(ATTR.LiftOff)
				Cinema.Play("Intro", {
					boss = bossPathFrom(now),
					spot = if typeof(lift) == "Vector3" then lift else nil,
					origin = state.lobbyOrigin, -- (v3: the Intro plays in the lobby)
					length = SSE.Durations.Cinematic - age,
					cues = { { t = Cine.Shots.Intro.LiftShake, run = function()
						CameraPunch.Shake(0.8, 2.8)
					end } },
				})
			end
		elseif phase == PHASE.Teleport then
			-- (v3) the trip to the race map (Beat: the fade, the arrival, Eggman's entry on camera)
			if arenaMode() then
				Beat.Stream(state.origin)
			end
		elseif phase == PHASE.Return then
			-- (v3) the trip home: where the root was when it began decides its freeze; the lobby streamed in
			state.returnPos = if root then root.Position else nil
			if arenaMode() then
				Beat.Stream(state.lobbyOrigin)
			end
		elseif phase == PHASE.Bombard then
			taunt("Talk")
			Screen.Say("EggmanBombard")
		elseif phase == PHASE.Emeralds then
			refreshEmeraldSets()
			Screen.Say("EggmanEmeralds")
			if live and emeraldSets[player] then
				Cinema.Play("Emeralds", {})
			end
		elseif phase == PHASE.Battle then
			setHp()
			Screen.Say("EggmanSuper")
		elseif phase == PHASE.Defeat then
			Screen.Hush() -- (v3: no dialogue in the Defeat, not even a line left over from the fight)
			startDefeat(Workspace:GetAttribute(ATTR.CrashPoint), nil)
			announce("ChatDefeat")
		elseif phase == PHASE.Escape then
			startFlee(false)
			announce("ChatEscape")
		end
		if isEndPhase(phase) and live then
			local crash = if phase == PHASE.Defeat and state.plan then state.plan.crashPoint else nil
			-- (v3) the Defeat's shot fits its freeze window (the players are free when the rings can be taken)
			local _, windowEnd = SSE.FreezeWindow(phase)
			local length = if phase == PHASE.Defeat and windowEnd then windowEnd - age else nil
			Cinema.Play("Outro", { boss = bossPathFrom(now), crash = crash, length = length })
		end
		syncInputBinding()
	end

	-- The server writes Origin, EventId, ..., PhaseStart, then Phase when an event starts, and clears them
	-- (Phase last, to "") when it ends: a cleared attribute keeps the value this client had, and only a
	-- DIFFERENT event id restarts everything.
	function onPhaseChanged()
		local phase = SSE.NormalizePhase(Workspace:GetAttribute(ATTR.Phase))
		if not SSE.IsPhase(phase) or killed() then
			phase = ""
		end
		local eventId = Workspace:GetAttribute(ATTR.EventId)
		if eventId ~= nil then
			if state.active and state.eventId ~= nil and eventId ~= state.eventId then
				endEvent() -- a new event: start clean
			end
			state.eventId = eventId
		end
		if phase == "" then
			if state.active then
				endEvent()
			end
			return
		end
		local origin = Workspace:GetAttribute(ATTR.Origin)
		if typeof(origin) == "Vector3" then
			state.origin = origin
		elseif not state.active then
			state.origin = readOrigin()
		end
		-- (v3) the world's lobby spawn (the fight's centre is the race map's point)
		local lobbyOrigin = Workspace:GetAttribute(ATTR.LobbyOrigin)
		if typeof(lobbyOrigin) == "Vector3" then
			state.lobbyOrigin = lobbyOrigin
		elseif not state.active then
			state.lobbyOrigin = nil
		end
		local start = tonumber(Workspace:GetAttribute(ATTR.PhaseStart))
		if start then
			state.phaseStart = start
		elseif not state.active then
			state.phaseStart = serverNow()
		end
		refreshPlan()
		if not state.active then
			beginEvent()
		end
		local previous = state.phase
		state.phase = phase
		if phase ~= previous then
			onPhaseEnter(phase, previous)
		end
	end

	for _, name in { ATTR.Phase, ATTR.PhaseStart, ATTR.EventId, ATTR.Origin, ATTR.EventStart, ATTR.Seed, ATTR.LiftOff, SSE.KillAttribute } do
		Workspace:GetAttributeChangedSignal(name):Connect(onPhaseChanged)
	end
	-- (v3) the lobby spawn, the Defeat's crash point and the ending kept through the Return: the plan follows
	for _, name in { ATTR.LobbyOrigin, ATTR.CrashPoint, ATTR.EndStart, ATTR.Outcome } do
		Workspace:GetAttributeChangedSignal(name):Connect(function()
			if state.active then
				local lobbyOrigin = Workspace:GetAttribute(ATTR.LobbyOrigin)
				if typeof(lobbyOrigin) == "Vector3" then
					state.lobbyOrigin = lobbyOrigin
				end
				refreshPlan()
			end
		end)
	end
	Workspace:GetAttributeChangedSignal(ATTR.BossHP):Connect(function()
		if state.active then
			setHp()
		end
	end)
	Workspace:GetAttributeChangedSignal(ATTR.BossMaxHP):Connect(function()
		if state.active then
			setHp()
		end
	end)
end)()

----------------------------------------------------------------------
-- Players: the Super form comes and goes with SSE_Super (and the skin with SSE_Skin); a respawn cleans up
-- (and hands the camera back: a cinematic never survives a respawn)
----------------------------------------------------------------------
;(function() -- (a function, not a do-block: see the note at the top)
	local playerConnections: { [Player]: { RBXScriptConnection } } = {}

	local function onSuperChanged(target: Player)
		local super = target:GetAttribute(PATTR.Super) == true
		if state.active and super then
			rankLooks()
		end
		refreshLook(target)
		if target == player then
			syncInputBinding()
			if super and state.active then
				playSound("Transform")
				-- A late transformation (no emeralds this time): the burst and the flash on their own (the
				-- emeralds' absorption bursts by itself, whichever of the two comes first).
				if os.clock() - lastAbsorbAt > 1.5 and not emeraldSets[player] then
					local root = characterRoot(player.Character)
					prewarmRigs("Burst", 1)
					if root then
						fireRig("Burst", CFrame.new(root.Position + Vector3.new(0, Fx.Emerald.ChestY, 0)))
					end
					goldenFlash()
				end
			elseif not super then
				Charge.Cancel()
				endFlight(nil)
			end
		end
	end

	local function watchPlayer(target: Player)
		if playerConnections[target] then
			return
		end
		local list = {}
		table.insert(list, target:GetAttributeChangedSignal(PATTR.Super):Connect(function()
			onSuperChanged(target)
		end))
		-- 2026-09-26 (owner, v2): the server's Super Sonic skin on / off: the look is redrawn for it.
		table.insert(list, target:GetAttributeChangedSignal(PATTR.Skin):Connect(function()
			refreshLook(target)
		end))
		table.insert(list, target:GetAttributeChangedSignal(SKIN_OVERRIDE):Connect(function()
			refreshLook(target)
		end))
		table.insert(list, target.CharacterAdded:Connect(function()
			if target == player then
				Cinema.Stop("respawn")
				Charge.Cancel()
				endFlight(nil)
				local set = emeraldSets[player]
				if set then
					releaseSet(set)
				end
				-- The camera follows the new body (the camera scripts do it too; a cinematic stopped by the
				-- respawn may have handed it the old one).
				task.defer(function()
					local camera = Workspace.CurrentCamera
					local body = player.Character
					local newHumanoid = body and body:FindFirstChildOfClass("Humanoid")
					if camera and newHumanoid and camera.CameraType ~= Enum.CameraType.Scriptable then
						local subject = camera.CameraSubject
						if subject == nil or not subject:IsDescendantOf(Workspace) then
							camera.CameraSubject = newHumanoid
						end
					end
				end)
			end
			-- The new body gets the look once it is assembled.
			task.defer(refreshLook, target)
		end))
		table.insert(list, target.CharacterRemoving:Connect(function()
			if target == player then
				Cinema.Stop("respawn")
				Charge.Cancel()
				endFlight(nil)
			end
			removeLook(target)
			local set = emeraldSets[target]
			if set then
				releaseSet(set)
			end
		end))
		playerConnections[target] = list
		refreshLook(target)
	end

	for _, target in Players:GetPlayers() do
		watchPlayer(target)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	Players.PlayerRemoving:Connect(function(target)
		local list = playerConnections[target]
		if list then
			for _, connection in list do
				connection:Disconnect()
			end
			playerConnections[target] = nil
		end
		removeLook(target)
		local set = emeraldSets[target]
		if set then
			releaseSet(set)
		end
	end)

	UserInputService.LastInputTypeChanged:Connect(function()
		nextUiCheck = 0
	end)
	player:GetAttributeChangedSignal("TouchLayout"):Connect(function()
		if buttonShown then
			layoutButton()
		end
	end)
	-- The camera and the interface are never left behind (the script going away: a place shutting down).
	pcall(function()
		(script :: any).Destroying:Connect(function()
			Cinema.Stop("destroyed")
			Freeze.Release()
			HudHide.Release()
			Music.Stop(true)
		end)
	end)

	onPhaseChanged()
end)()
