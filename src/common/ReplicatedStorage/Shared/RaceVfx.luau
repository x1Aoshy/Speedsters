-- ReplicatedStorage/Shared/RaceVfx.luau — Update 4 race VFX (race_fx). Client only.
-- 2026-09-26 (owner): rebuilt around the Sonic Burst feel, with no particles at all (no
-- ParticleEmitter, no Sparkles, no engine particle textures) and no bubble around the racer:
--   * Charge: while the start is held, real electric arcs crackle over the body: chains of
--     Attachments on the Torso, limbs and head joined by untextured Beams (solid tapered bands,
--     LightEmission 1) whose points are re-rolled ArcHz times a second; more of them lit, wider
--     and leaping further off the body the fuller the gauge. Cyan below the zone, gold-white
--     inside it (let go now), red while the gauge vents. The High own racer's torso glows in the zone.
--   * GO (the Sonic Boom): Perfect / Good flash every arc and throw one or two expanding shock
--     rings along the ground plus a burst of after-images; Ok a small ring; Stall a red sputter.
--     The screen side (screen shock ring, CameraPunch FOV + shake by LaunchPunch) belongs to
--     Race/RacePoseClient and Shared/RaceScreenFx.
--   * After-images: pooled silhouettes of the body parts only (no accessories, no scripts,
--     no decals; anchored, no collision / touch / query), stamped every GhostEvery seconds with
--     workspace:BulkMoveTo while the racer runs at SpeedFrom x their own cruise or faster, at
--     super speed and for a moment after GO, a pad or the finish; each fades 0.3 -> 0.7 -> 1
--     over its life. 2026-09-26 (owner): they are the sprint's dark shadow (R15SpeedsterRun's
--     after-images: Color3.fromRGB(28, 17, 38), SmoothPlastic; AfterImage.Color / Material),
--     never the aura's or the race's gold tints. The own racer has its pool; the others share
--     one, for the nearest few.
--   * Rings: expanding shock rings of four curved Beams (Bezier quarters of a circle) from a
--     shared pool: GO and speed pads on the ground, super-speed entry and the finish line as a
--     gate across the track.
--   * The racer's own Trails and Auras are never touched: nothing here hides, covers or
--     re-parents them, and nothing is Glass (Glass hides the particles and trails behind it).
-- Everything is built by Prewarm during the countdown (the CPU is idle then) and afterwards only
-- shown, hidden, moved and restyled: after Prewarm there is no Instance.new, Clone, TweenService
-- or Debris (audit/test_u4_race_vfx checks the source).
-- Budgets come from RaceFeelTier (the local device's tier, Update4Config Feel.Lightning /
-- AfterImage / Rings): the own racer gets the "Own" row, every other racer the "Other" row, and
-- only the nearest few of them get arcs and after-images. Kill switches: SetEnabled (Workspace
-- U4Off_RaceFx / U4Off_RaceGhosts, read by Race/RacePoseClient).
local Vector3, CFrame, Color3, Instance, Enum = Vector3, CFrame, Color3, Instance, Enum
local ColorSequence, NumberSequence = ColorSequence, NumberSequence
if Instance == nil then
	-- Lune: the datatypes come from @lune/roblox (the dynamic require keeps Script Analysis quiet).
	local lateRequire: any = require
	local ok, roblox = pcall(lateRequire, "@lune/roblox")
	if ok and type(roblox) == "table" then
		Vector3, CFrame, Color3, Instance, Enum = roblox.Vector3, roblox.CFrame, roblox.Color3, roblox.Instance, roblox.Enum
		ColorSequence, NumberSequence = roblox.ColorSequence, roblox.NumberSequence
	end
end

local function sibling(name: string): any
	return require((script :: any).Parent:WaitForChild(name, 10))
end
local U4: any = if typeof(script) == "Instance" then sibling("Update4Config") else require("./Update4Config")
local RaceFeelTier: any = if typeof(script) == "Instance" then sibling("RaceFeelTier") else require("./RaceFeelTier")
local RaceChargeMath: any = if typeof(script) == "Instance" then sibling("RaceChargeMath") else require("./RaceChargeMath")

local FEEL = U4.Race.Feel
local SOUNDS = FEEL.Sounds
local COLORS = FEEL.Vfx.Colors
local LIGHTNING = FEEL.Lightning
local GHOST = FEEL.AfterImage
local RINGS = FEEL.Rings
local LAUNCH = FEEL.Launch
local CHARGE = U4.Race.Charge

local RaceVfx = {}

RaceVfx.FolderName = "RaceFx"
RaceVfx.ArcName = "RaceArc"
RaceVfx.GhostName = "RaceGhost"
RaceVfx.RingName = "RaceRing"
RaceVfx.BoltColor = Color3.fromRGB(170, 240, 255) -- Sonic Burst's BOLT_COLOR
RaceVfx.White = Color3.fromRGB(255, 255, 255)
-- 2026-09-26 (owner): the after-images' one colour, the sprint's dark shadow (AfterImage.Color,
-- R15SpeedsterRun's AFTERIMAGE_COLOR).
RaceVfx.GhostColor = if type(GHOST.Color) == "table"
	then Color3.fromRGB(GHOST.Color[1] or 28, GHOST.Color[2] or 17, GHOST.Color[3] or 38)
	else Color3.fromRGB(28, 17, 38)
RaceVfx.ChargeFrom = 0.15 -- below this gauge the arcs are sparse and thin
RaceVfx.Levels = 4 -- the gauge is quantised for the arcs' look (a restyle per level, not per frame)
RaceVfx.LodSeconds = 0.25 -- the distance pass (AuraSpecialEffectsClient's 4 Hz)
RaceVfx.BoomDistance = 60
-- The arcs' hosts, in the order a tier's Arcs count takes them (R6 first; R15 names otherwise).
RaceVfx.ArcParts = { "Torso", "Right Arm", "Left Arm", "Right Leg", "Left Leg", "Head" }
RaceVfx.ArcPartsR15 = { "UpperTorso", "RightUpperArm", "LeftUpperArm", "RightUpperLeg", "LeftUpperLeg", "Head" }
RaceVfx.FeetDrop = 2.8 -- a ground ring this far under the root (an R6 root stands 3 over the floor)
RaceVfx.CurveK = 0.5523 -- a Bezier quarter of a circle: handles of radius x this
RaceVfx.LightRange = 10
RaceVfx.LightBrightness = 2.5
RaceVfx.FlashRange = 16
RaceVfx.FlashBrightness = 8
RaceVfx.FlashSeconds = 0.25
RaceVfx.ArcZOffset = 0.3 -- the arcs are drawn a little in front of the body they cover

-- Tests and the client may point this elsewhere; nil = workspace.RaceFx.
RaceVfx.Container = nil :: Instance?
-- The client sets this to its SoundEffects setting.
RaceVfx.SoundsOn = function(): boolean
	return true
end

local entries: { [Model]: any } = {}
local reducedMotion = false
local enabled = { All = true, Ghosts = true }
local nextLodAt = 0
local cameraPosition: Vector3? = nil
local bulkParts: { BasePart } = {}
local bulkFrames: { CFrame } = {}
local ranked: { any } = {}
-- The pools every racer shares: the rings, and the other racers' after-images.
local shared = {
	Folder = nil :: Instance?,
	Tier = nil :: string?,
	Rings = {} :: { any },
	Others = {} :: { any },
	OthersIndex = 1,
}

local function rng(a: number, b: number): number
	return a + math.random() * (b - a)
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function finite(value: any, default: number): number
	local n = tonumber(value)
	if n == nil or n ~= n or n == math.huge or n == -math.huge then
		return default
	end
	return n
end

-- The rings' fade, in 21 steps (a NumberSequence per frame would be garbage).
local FADE = {}
for step = 0, 20 do
	FADE[step] = NumberSequence.new(step / 20)
end
local function fadeSequence(t: number)
	return FADE[math.clamp(math.floor(t * 20 + 0.5), 0, 20)]
end

-- A ring's four points: at 0, 90, 180 and 270 degrees in the holder's XZ plane, each turned so
-- its Axis (X) is the circle's tangent, counter-clockwise (the Beams' CurveSize handles run
-- along it: P1 = A0 + Axis0 * c, P2 = A1 - Axis1 * c).
local RING_DIRS = { Vector3.new(1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(-1, 0, 0), Vector3.new(0, 0, -1) }
local RING_ROT = {}
for index, direction in RING_DIRS do
	local up = Vector3.new(0, 1, 0)
	local tangent = Vector3.new(-direction.Z, 0, direction.X) -- (-sin, 0, cos) at (cos, 0, sin)
	RING_ROT[index] = CFrame.fromMatrix(Vector3.new(0, 0, 0), tangent, up, tangent:Cross(up))
end
local VERTICAL = CFrame.Angles(math.pi / 2, 0, 0) -- the XZ plane turned across the track (-Z)

----------------------------------------------------------------------
-- Pure numbers (the tests and Race/RacePoseClient read them)
----------------------------------------------------------------------
-- An after-image's transparency at `age` seconds of `life`: 0.3 -> 0.7 (half-life) -> 1.
function RaceVfx.GhostTransparency(age: number, life: number): number
	local ramp = GHOST.Transparency
	local span = finite(life, 0)
	if span <= 0 then
		return 1
	end
	local a = finite(age, math.huge) / span
	if a <= 0 then
		return ramp[1]
	elseif a >= 1 then
		return 1
	elseif a < 0.5 then
		return lerp(ramp[1], ramp[2], a / 0.5)
	end
	return lerp(ramp[2], ramp[3], (a - 0.5) / 0.5)
end

-- The local camera's kick at GO: CameraPunch.Fov(Fov) and CameraPunch.Shake(ShakeSeconds,
-- ShakeStrength), the full Sonic Boom on a Perfect, less on Good, small on Ok, none on a Stall.
-- Reduced motion: part of the FOV punch, no shake.
function RaceVfx.LaunchPunch(grade: string?, reduced: boolean?): any
	local share = (grade and LAUNCH.Grade[grade]) or 0
	local fov = LAUNCH.Fov * share * (if reduced then LAUNCH.ReducedFov else 1)
	local strength = if reduced then 0 else LAUNCH.ShakeStrength * share
	return {
		Share = share,
		Fov = fov,
		ShakeSeconds = if strength > 0 then LAUNCH.ShakeSeconds else 0,
		ShakeStrength = strength,
	}
end

-- The super-speed arcs' colours from CosmeticCatalog entries (the equipped aura, else the
-- trail), else the race's gold and bolt colours. The third value: whether it is the aura's.
-- 2026-09-26 (owner): only the arcs take them (SetTint); the after-images are always
-- RaceVfx.GhostColor, the sprint's dark shadow (this was GhostColors).
function RaceVfx.AuraColors(aura: any, trail: any): (Color3, Color3, boolean)
	local function pair(entry: any): (Color3?, Color3?)
		if type(entry) ~= "table" or typeof(entry.ThemeColor) ~= "Color3" then
			return nil, nil
		end
		local dark = if typeof(entry.ThemeDarkColor) == "Color3" then entry.ThemeDarkColor else entry.ThemeColor
		-- Half-way to the dark colour: a black aura's dark half would vanish in Neon.
		return entry.ThemeColor, entry.ThemeColor:Lerp(dark, 0.5)
	end
	local a1, a2 = pair(aura)
	if a1 and a2 then
		return a1, a2, true
	end
	local t1, t2 = pair(trail)
	if t1 and t2 then
		return t1, t2, false
	end
	return COLORS.Burst, RaceVfx.BoltColor, false
end

-- Whether a racer leaves after-images now: fast past their own cruise, at super speed, or in a
-- burst window (GO, a pad, the finish); never standing or jogging.
function RaceVfx.GhostsWanted(speed: number, cruise: number, burst: boolean?, super: boolean?): boolean
	local v = finite(speed, 0)
	if v < GHOST.MinSpeed then
		return false
	end
	return super == true or burst == true or v >= GHOST.SpeedFrom * math.max(1, finite(cruise, 1))
end

-- A ring's radius, band width and fade at `alpha` (0..1) of its life.
function RaceVfx.RingShape(look: any, alpha: number): (number, number, number)
	local a = math.clamp(finite(alpha, 1), 0, 1)
	local e = 1 - (1 - a) ^ 3
	return look.R0 + (look.R1 - look.R0) * e, look.Width * (1 - 0.65 * a), a ^ 1.5
end

----------------------------------------------------------------------
-- Plan: what Prewarm builds for a racer on this tier (pure; the tests count it)
----------------------------------------------------------------------
function RaceVfx.Plan(tier: string?, isLocal: boolean, quality: number?): any
	local budget = RaceFeelTier.Budget(tier, quality)
	local own = isLocal == true
	local row = if own then budget.Own else budget.Other
	local arcs = row.Arcs or 0
	local points = if arcs > 0 then math.max(2, row.ArcPoints or 4) else 0
	local sounds = {}
	if own and type(SOUNDS.Go) == "string" and SOUNDS.Go ~= "" then
		table.insert(sounds, "Go")
	end
	if own and SOUNDS.SuperEnter ~= "" then
		table.insert(sounds, "Enter")
	end
	if SOUNDS.SuperBoom ~= "" then
		table.insert(sounds, "Boom")
	end
	-- A speed pad's whoosh, once the owner uploads an allowed id (own racer).
	if own and type(SOUNDS.PadWhoosh) == "string" and SOUNDS.PadWhoosh ~= "" then
		table.insert(sounds, "Whoosh")
	end
	return {
		Tier = budget.Tier,
		IsLocal = own,
		Arcs = arcs,
		ArcPoints = points,
		ArcBeams = arcs * math.max(0, points - 1),
		ArcAttachments = arcs * points,
		ArcHz = row.ArcHz or 0,
		ArcDistance = if own then math.huge else row.ArcDistance or 0,
		Lights = if own then row.Lights or 0 else 0,
		-- The own racer's after-images; the others share OthersGhostPool.
		GhostPool = if own then row.GhostPool or 0 else 0,
		GhostEvery = row.GhostEvery,
		GhostLife = row.GhostLife,
		GhostDistance = if own then math.huge else row.GhostDistance or 0,
		Distance = if own then math.huge else row.Distance or 0,
		RingDistance = if own then math.huge else budget.RingDistance or 0,
		RingPool = budget.RingPool,
		OthersArcCap = budget.OthersArcCap,
		OthersGhostCap = budget.OthersGhostCap,
		OthersGhostPool = budget.OthersGhostPool,
		Sounds = sounds,
	}
end

-- The instances Prewarm makes for a racer's plan (per racer), with `bodyParts` body parts.
function RaceVfx.PlanCounts(plan: any, bodyParts: number?): any
	return {
		Particles = 0, -- none, ever (2026-09-26, owner)
		Attachment = plan.ArcAttachments,
		Beam = plan.ArcBeams,
		PointLight = plan.Lights,
		GhostParts = plan.GhostPool * (bodyParts or 6),
		Sound = #plan.Sounds,
	}
end

-- The shared pools for a tier: the rings, and the other racers' after-images.
function RaceVfx.SharedCounts(plan: any, bodyParts: number?): any
	return {
		RingParts = plan.RingPool,
		RingAttachments = 4 * plan.RingPool,
		RingBeams = 4 * plan.RingPool,
		OtherGhosts = plan.OthersGhostPool,
		OtherGhostParts = plan.OthersGhostPool * (bodyParts or 6),
	}
end

----------------------------------------------------------------------
-- Charge watch: the local racer's grade, predicted from its gauge until the server's arrives
----------------------------------------------------------------------
function RaceVfx.NewChargeWatch(): any
	return { G = 0, ZoneT = 0, CoreT = 0, Venting = false, VentUntil = -math.huge, VentedLate = false, LastAt = nil }
end

-- Feed the gauge every frame of the countdown; goAt: the server clock's GO (now on the same clock).
function RaceVfx.WatchCharge(watch: any, g: number, now: number, goAt: number?)
	local gauge = math.clamp(tonumber(g) or 0, 0, 1)
	if gauge ~= gauge then
		gauge = 0
	end
	local last = watch.LastAt
	watch.LastAt = now
	if gauge >= 0.995 and not watch.Venting then
		watch.Venting, watch.VentUntil = true, now + CHARGE.VentSeconds
	elseif watch.Venting and now >= watch.VentUntil then
		watch.Venting = false
	end
	local go = tonumber(goAt)
	if last and go and now > last then
		local from = math.max(last, go - CHARGE.Window)
		local to = math.min(now, go)
		local inside = math.max(0, to - from)
		if inside > 0 then
			local previous = watch.G
			if previous >= CHARGE.ZoneLo and previous <= CHARGE.ZoneHi then
				watch.ZoneT += inside
			end
			if previous >= CHARGE.CoreLo and previous <= CHARGE.CoreHi then
				watch.CoreT += inside
			end
		end
		if watch.Venting and now >= go - CHARGE.StallWindow and last < go then
			watch.VentedLate = true
		end
	end
	watch.G = gauge
end

function RaceVfx.PredictGrade(watch: any, grace: boolean?): string
	local q = 0.5 * watch.ZoneT / CHARGE.Window + 0.5 * watch.CoreT / CHARGE.Window
	return RaceChargeMath.Outcome({
		G = watch.G,
		Held = false,
		Venting = watch.Venting,
		ZoneT = watch.ZoneT,
		CoreT = watch.CoreT,
		Q = q,
		HeldSeconds = 0,
		OverheatAt = nil,
		VentedLate = watch.VentedLate,
		Assist = false,
	}, CHARGE, grace == true, false)
end

----------------------------------------------------------------------
-- Building (Prewarm only)
----------------------------------------------------------------------
local function container(): Instance?
	if RaceVfx.Container and RaceVfx.Container.Parent ~= nil then
		return RaceVfx.Container
	end
	if typeof(workspace) ~= "Instance" then
		return RaceVfx.Container
	end
	local folder = workspace:FindFirstChild(RaceVfx.FolderName)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = RaceVfx.FolderName
		folder.Parent = workspace
	end
	return folder
end

local function quietPart(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Massless = true
	part.Transparency = 1
end

local function newFolder(name: string, parent: Instance): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function newAttachment(name: string, parent: Instance, frame: CFrame?): Attachment
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.CFrame = frame or CFrame.new()
	attachment.Parent = parent
	return attachment
end

-- A solid band of light between two attachments: no texture, no light from the world.
local function newBeam(name: string, a0: Attachment, a1: Attachment, parent: Instance, segments: number): Beam
	local beam = Instance.new("Beam")
	beam.Name = name
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	pcall(function()
		(beam :: any).Texture = "" -- untextured = a solid band
	end)
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.FaceCamera = true
	beam.Segments = segments
	beam.Width0 = 0.2
	beam.Width1 = 0.1
	beam.ZOffset = RaceVfx.ArcZOffset
	beam.Transparency = NumberSequence.new(0.05)
	beam.Color = ColorSequence.new(RaceVfx.BoltColor)
	beam.Enabled = false
	beam.Parent = parent
	return beam
end

-- The body parts: the character's own BaseParts but the root (never an accessory's Handle, a
-- tool or a skin rig's pieces: those are not direct children), by name.
local function bodyParts(character: Model): { BasePart }
	local list = {}
	for _, child in character:GetChildren() do
		if child:IsA("BasePart") and child.Name ~= "HumanoidRootPart" then
			table.insert(list, child)
		end
	end
	table.sort(list, function(a, b)
		return a.Name < b.Name
	end)
	return list
end

-- 2026-09-26 (owner): SmoothPlastic, as the sprint's shadow (a dark "Neon" or "ForceField" if set).
local function ghostMaterial(): any
	if GHOST.Material == "ForceField" then
		return Enum.Material.ForceField
	elseif GHOST.Material == "Neon" then
		return Enum.Material.Neon
	end
	return Enum.Material.SmoothPlastic
end

-- One after-image: a silhouette clone of each body part with nothing inside it but a head's
-- SpecialMesh (untextured), parked invisible where the body is (never far away: float32), in
-- the sprint's dark shadow (RaceVfx.GhostColor).
local function newGhost(sources: { BasePart }, parent: Instance, index: number): any
	local folder = newFolder(RaceVfx.GhostName .. index, parent)
	local ghost = { Folder = folder, Parts = {}, ByName = {}, Alive = false, Born = 0, Life = 0.3, Shown = 1, Hidden = {}, Anchor = nil }
	for _, source in sources do
		local ok, clone = pcall(function()
			return source:Clone()
		end)
		local part: BasePart
		if ok and clone and clone:IsA("BasePart") then
			for _, child in clone:GetChildren() do
				if child:IsA("SpecialMesh") then
					pcall(function()
						(child :: any).TextureId = ""
					end)
				else
					child:Destroy()
				end
			end
			part = clone
		else
			-- Not archivable: a plain block of the same size stands in.
			part = Instance.new("Part")
			part.Size = source.Size
		end
		part.Name = source.Name
		quietPart(part)
		part.Material = ghostMaterial()
		part.Color = RaceVfx.GhostColor
		pcall(function()
			(part :: any).TextureID = ""
		end)
		part.CFrame = source.CFrame
		part.Parent = folder
		table.insert(ghost.Parts, part)
		ghost.ByName[source.Name] = part
	end
	return ghost
end

-- The shared ring pool (built once per tier).
local function buildRings(count: number, parent: Instance, at: CFrame)
	for index = 1, count do
		local holder = Instance.new("Part")
		holder.Name = RaceVfx.RingName
		quietPart(holder)
		holder.Size = Vector3.new(0.2, 0.2, 0.2)
		holder.CFrame = at
		holder.Parent = parent
		local points = {}
		for q = 1, 4 do
			points[q] = newAttachment("RaceRingPoint", holder, CFrame.new(RING_DIRS[q]) * RING_ROT[q])
		end
		local beams = {}
		for q = 1, 4 do
			beams[q] = newBeam("RaceRingArc", points[q], points[q % 4 + 1], holder, 10)
		end
		shared.Rings[index] = { Part = holder, Points = points, Beams = beams, Alive = false, Start = 0, Placed = false }
	end
end

local function destroyShared()
	if shared.Folder then
		shared.Folder:Destroy()
	end
	shared.Folder = nil
	shared.Tier = nil
	shared.Rings = {}
	shared.Others = {}
	shared.OthersIndex = 1
end

-- The shared pools for this tier: rebuilt only when the tier changed (a new race on another
-- device class), never in a hot path. The others' after-images copy the first other racer's body.
local function ensureShared(plan: any, parent: Instance, at: CFrame, sources: { BasePart }?)
	if shared.Folder and (shared.Folder.Parent == nil or shared.Tier ~= plan.Tier) then
		destroyShared()
	end
	if not shared.Folder then
		shared.Folder = newFolder("Shared", parent)
		shared.Tier = plan.Tier
		buildRings(plan.RingPool or 0, shared.Folder :: Instance, at)
	end
	if sources and #shared.Others == 0 and (plan.OthersGhostPool or 0) > 0 and #sources > 0 then
		local folder = newFolder("OtherGhosts", shared.Folder :: Instance)
		for index = 1, plan.OthersGhostPool do
			shared.Others[index] = newGhost(sources, folder, index)
		end
		shared.OthersIndex = 1
	end
end

local function arcHost(character: Model, index: number): BasePart?
	local names = if character:FindFirstChild("Torso") then RaceVfx.ArcParts else RaceVfx.ArcPartsR15
	local part = character:FindFirstChild(names[(index - 1) % #names + 1])
	return if part and part:IsA("BasePart") then part else nil
end

local function newCharge(): any
	return { G = 0, Held = false, LastG = nil, RiseUntil = -math.huge }
end

local resetEntry -- forward (defined with the helpers below)

-- Builds everything for one racer. Idempotent: a second call for the same character (and
-- tier) returns the existing entry, reset for a new race.
function RaceVfx.Prewarm(character: Model?, tier: string?, isLocal: boolean?, quality: number?): any
	if not character or character.Parent == nil then
		return nil
	end
	local plan = RaceVfx.Plan(tier, isLocal == true, quality)
	local existing = entries[character]
	if existing then
		if existing.Plan.Tier == plan.Tier and existing.Plan.IsLocal == plan.IsLocal then
			resetEntry(existing)
			return existing
		end
		RaceVfx.Release(character)
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return nil
	end
	local parent = container()
	if not parent then
		return nil
	end
	local at = CFrame.new(root.CFrame.Position)
	local sources = bodyParts(character)
	-- The pools and the silhouettes first: nothing of ours is on the body yet.
	ensureShared(plan, parent, at, if plan.IsLocal then nil else sources)
	local folder = newFolder(character.Name, parent)
	local torso = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
	local body = {}
	for _, part in sources do
		body[part.Name] = part
	end
	local entry = {
		Character = character,
		Root = root,
		Torso = if torso and torso:IsA("BasePart") then torso else nil,
		Plan = plan,
		Folder = folder,
		Body = body,
		Arcs = {},
		Attachments = {},
		Ghosts = {},
		GhostIndex = 1,
		NextGhostAt = 0,
		GhostBurstUntil = -math.huge,
		Stamps = 0,
		Cruise = U4.Race.Speed.BaseCruise,
		AuraTint = nil,
		Light = nil,
		Sounds = {},
		Charge = newCharge(),
		Stage = "Off",
		Venting = false,
		VentUntil = 0,
		ArcBase = "Off",
		ArcLevel = 0,
		ArcColor = RaceVfx.BoltColor,
		FlashUntil = -math.huge,
		FlashColor = COLORS.Burst,
		FlashP = 1,
		NextRollAt = 0,
		Rolls = 0,
		ArcsShown = false,
		StyleKey = nil,
		Near = plan.IsLocal,
		ArcNear = plan.IsLocal,
		GhostOk = plan.IsLocal and plan.GhostPool > 0,
		RingNear = plan.IsLocal,
		Distance = 0,
		Launched = false,
		Super = false,
		LightStart = nil,
		LightPeak = 0,
		Glow = false,
	}

	for index = 1, plan.GhostPool do
		entry.Ghosts[index] = newGhost(sources, folder, index)
	end

	-- The arcs: a chain of ArcPoints attachments on each host part, joined by ArcPoints - 1 beams.
	for index = 1, plan.Arcs do
		local host = arcHost(character, index)
		if host then
			local arc = { Part = host, Points = {}, Beams = {}, On = false }
			for _ = 1, plan.ArcPoints do
				local point = newAttachment(RaceVfx.ArcName, host)
				table.insert(arc.Points, point)
				table.insert(entry.Attachments, point)
			end
			for k = 1, plan.ArcPoints - 1 do
				arc.Beams[k] = newBeam(RaceVfx.ArcName, arc.Points[k], arc.Points[k + 1], folder, 1)
			end
			table.insert(entry.Arcs, arc)
		end
	end

	if plan.Lights > 0 and entry.Torso then
		local light = Instance.new("PointLight")
		light.Name = "RaceGlow"
		light.Range = RaceVfx.LightRange
		light.Brightness = RaceVfx.LightBrightness
		light.Shadows = false
		light.Color = COLORS.Charge2
		light.Enabled = false
		light.Parent = entry.Torso
		entry.Light = light
	end

	for _, key in plan.Sounds do
		local sound = Instance.new("Sound")
		sound.Name = "RaceFx" .. key
		if key == "Go" then
			sound.SoundId = SOUNDS.Go
			sound.Volume = 0.6
		elseif key == "Enter" then
			sound.SoundId = SOUNDS.SuperEnter
			sound.PlaybackSpeed = 1.25
			sound.Volume = 0.35
		elseif key == "Whoosh" then
			sound.SoundId = SOUNDS.PadWhoosh
			sound.Volume = 0.4
		else
			sound.SoundId = SOUNDS.SuperBoom
			sound.PlaybackSpeed = 0.9
			sound.Volume = if plan.IsLocal then 0.4 else 0.3
		end
		sound.RollOffMaxDistance = RaceVfx.BoomDistance * 2
		sound.Parent = root
		entry.Sounds[key] = sound
	end

	entries[character] = entry
	nextLodAt = 0 -- the next Step places the new racer (distance, arcs, after-images)
	return entry
end

function RaceVfx.Get(character: Model): any
	return entries[character]
end

----------------------------------------------------------------------
-- Tint and cruise
----------------------------------------------------------------------
-- The racer's colours (RaceVfx.AuraColors); isAura: the super-speed arcs take c1.
-- 2026-09-26 (owner): the after-images no longer take any tint: they are always the sprint's
-- dark shadow (RaceVfx.GhostColor), whatever aura or trail is equipped.
function RaceVfx.SetTint(character: Model, c1: Color3?, c2: Color3?, isAura: boolean?)
	local entry = entries[character]
	if not entry then
		return
	end
	local first = if typeof(c1) == "Color3" then c1 else COLORS.Burst
	entry.AuraTint = if isAura == true then first else nil
end

-- The racer's own cruise (studs/s): the after-images' threshold is relative to it.
function RaceVfx.SetCruise(character: Model, cruise: number?)
	local entry = entries[character]
	if entry then
		entry.Cruise = math.max(1, finite(cruise, U4.Race.Speed.BaseCruise))
	end
end

----------------------------------------------------------------------
-- Arcs
----------------------------------------------------------------------
local function setArc(arc: any, on: boolean)
	if arc.On == on then
		return
	end
	arc.On = on
	for _, beam in arc.Beams do
		beam.Enabled = on
	end
end

local function hideArcs(entry: any)
	for _, arc in entry.Arcs do
		setArc(arc, false)
	end
	entry.ArcsShown = false
end

-- The arcs' mode now: a flash (GO, a pad, the finish) over the base (charge, vent, super, off).
local function arcMode(entry: any, clock: number): string
	if clock < entry.FlashUntil then
		return "Flash"
	end
	return entry.ArcBase
end

-- p: the share of arcs lit at each re-roll; hz: re-rolls a second; width: a chain's root width;
-- leap: how far a tip may jump off the body; color.
local function arcLook(entry: any, mode: string): (number, number, number, number, Color3)
	local plan = entry.Plan
	local level = math.floor(math.clamp(entry.ArcLevel, 0, 1) * RaceVfx.Levels + 0.5) / RaceVfx.Levels
	local width = LIGHTNING.Width
	local p, hz, w, leap, color
	if mode == "Flash" then
		p, hz, w, leap, color = entry.FlashP, plan.ArcHz, LIGHTNING.FlashWidth, LIGHTNING.Leap, entry.FlashColor
	elseif mode == "Vent" then
		p, hz, w, leap, color = 0.9, plan.ArcHz, width[2], LIGHTNING.Leap, COLORS.Overheat
	elseif mode == "Super" then
		p, hz, w, leap, color = 0.45, plan.ArcHz * 0.6, lerp(width[1], width[2], 0.45), LIGHTNING.Leap * 0.5, entry.AuraTint or RaceVfx.BoltColor
	else
		p, hz, w, leap, color = 0.3 + 0.65 * level, plan.ArcHz * (0.5 + 0.5 * level), lerp(width[1], width[2], level), LIGHTNING.Leap * level, entry.ArcColor
	end
	if reducedMotion then
		hz *= 0.5
	end
	return p, hz, w, leap, color
end

-- Widths (tapered to Taper at the tip) and colour, only when the look changes.
local function styleArcs(entry: any, mode: string, w: number, color: Color3)
	local key = string.format("%s %.3f %.3f %.3f %.3f", mode, w, color.R, color.G, color.B)
	if entry.StyleKey == key then
		return
	end
	entry.StyleKey = key
	local sequence = ColorSequence.new(color:Lerp(RaceVfx.White, 0.35), color)
	local taper = LIGHTNING.Taper
	for _, arc in entry.Arcs do
		local count = #arc.Beams
		for k, beam in arc.Beams do
			beam.Width0 = w * (1 - (1 - taper) * (k - 1) / count)
			beam.Width1 = w * (1 - (1 - taper) * k / count)
			beam.Color = sequence
		end
	end
end

-- A new path over one side of the host part: along its length, jagged across, a little off
-- the surface; the tip may leap off the body.
local function rollArc(arc: any, leap: number)
	local size = arc.Part.Size
	local hx, hy, hz = size.X * 0.5, size.Y * 0.5, size.Z * 0.5
	local onX = math.random() < 0.5
	local sign = if math.random() < 0.5 then -1 else 1
	local half = if onX then hx else hz
	local across = if onX then hz else hx
	local y0, y1 = rng(-hy, -0.15 * hy), rng(0.15 * hy, hy)
	if math.random() < 0.5 then
		y0, y1 = y1, y0
	end
	local u = rng(-0.6, 0.6) * across
	local count = #arc.Points
	for k, point in arc.Points do
		local t = (k - 1) / math.max(1, count - 1)
		local y = lerp(y0, y1, t) + rng(-0.12, 0.12) * size.Y
		local side = u + rng(-0.55, 0.55) * across
		local lift = rng(0.05, 0.22)
		if k == count and leap > 0 then
			lift += rng(0, leap)
		elseif k > 1 and k < count then
			lift += rng(0, 0.3 * leap)
		end
		local n = sign * (half + lift)
		point.CFrame = if onX then CFrame.new(n, y, side) else CFrame.new(side, y, n)
	end
end

local function stepArcs(entry: any, clock: number)
	if #entry.Arcs == 0 then
		return
	end
	local mode = arcMode(entry, clock)
	if mode == "Off" or not entry.ArcNear or not enabled.All then
		if entry.ArcsShown then
			hideArcs(entry)
		end
		return
	end
	if clock < entry.NextRollAt then
		return
	end
	local p, hz, w, leap, color = arcLook(entry, mode)
	styleArcs(entry, mode, w, color)
	entry.NextRollAt = clock + 1 / math.max(1, hz)
	entry.Rolls += 1
	for _, arc in entry.Arcs do
		local on = math.random() < p
		if on then
			rollArc(arc, leap)
		end
		setArc(arc, on)
	end
	entry.ArcsShown = true
end

local function flash(entry: any, clock: number, seconds: number, color: Color3, p: number?)
	entry.FlashUntil = clock + seconds * (if reducedMotion then 0.6 else 1)
	entry.FlashColor = color
	entry.FlashP = p or 1
	entry.NextRollAt = clock -- the next Step draws it
end

----------------------------------------------------------------------
-- The torso light (High own): a glow in the zone, flashes at GO / pads / the finish
----------------------------------------------------------------------
local function setGlow(entry: any, on: boolean)
	local light = entry.Light
	if not light or entry.LightStart then
		return
	end
	if entry.Glow ~= on then
		entry.Glow = on
		light.Color = COLORS.Charge2
		light.Brightness = RaceVfx.LightBrightness
		light.Range = RaceVfx.LightRange
		light.Enabled = on
	end
end

local function lightFlash(entry: any, clock: number, share: number)
	local light = entry.Light
	if not light or reducedMotion or share <= 0 or not enabled.All then
		return
	end
	entry.LightStart = clock
	entry.LightPeak = RaceVfx.FlashBrightness * share
	light.Range = RaceVfx.FlashRange
	light.Brightness = entry.LightPeak
	light.Color = COLORS.Burst
	light.Enabled = true
end

local function endLight(entry: any)
	entry.LightStart = nil
	entry.Glow = false
	local light = entry.Light
	if light then
		light.Enabled = false
		light.Range = RaceVfx.LightRange
		light.Brightness = RaceVfx.LightBrightness
		light.Color = COLORS.Charge2
	end
end

local function stepLight(entry: any, clock: number)
	if not entry.LightStart then
		return
	end
	local alpha = (clock - entry.LightStart) / RaceVfx.FlashSeconds
	if alpha >= 1 then
		endLight(entry)
	else
		entry.Light.Brightness = entry.LightPeak * (1 - math.max(0, alpha)) ^ 2
	end
end

----------------------------------------------------------------------
-- Charge
----------------------------------------------------------------------
-- g: the gauge 0..1 (local: RaceChargeLocal; others: RaceChargeLevel / 10). held: the local
-- racer's input (RaceChargeHeld); nil for another racer, whose hold is read from the level
-- rising (it arrives at <= 4 Hz). Cheap to call every frame: it only sets the arcs' state;
-- Step re-rolls them.
function RaceVfx.SetCharge(character: Model, g: number, now: number?, held: boolean?)
	local entry = entries[character]
	if not entry or entry.Launched then
		return
	end
	local clock = now or os.clock()
	local gauge = math.clamp(tonumber(g) or 0, 0, 1)
	if gauge ~= gauge then
		gauge = 0
	end
	local charge = entry.Charge
	if held == nil then
		local last = charge.LastG
		if last ~= nil then
			if gauge > last + 0.004 then
				charge.RiseUntil = clock + 0.45 -- their level rose this recently = held
			elseif gauge < last - 0.004 then
				charge.RiseUntil = -math.huge -- falling: let go
			end
		end
		charge.LastG = gauge
		charge.Held = clock < charge.RiseUntil
	else
		charge.Held = held == true
	end
	charge.G = gauge
	if gauge >= 0.995 and not entry.Venting then
		entry.Venting, entry.VentUntil = true, clock + CHARGE.VentSeconds
	elseif entry.Venting and clock >= entry.VentUntil then
		entry.Venting = false
	end
	-- Gold only inside the zone (PLAN §7.5): overfilled past ZoneHi the arcs turn back to cyan,
	-- so the colour says "you left the green" before the vent.
	local stage = if entry.Venting then "Overheat"
		elseif gauge >= CHARGE.ZoneLo and gauge <= CHARGE.ZoneHi then "Charge2"
		elseif gauge >= RaceVfx.ChargeFrom then "Charge1"
		else "Off"
	entry.Stage = stage
	entry.ArcLevel = gauge
	entry.ArcColor = if stage == "Overheat" then COLORS.Overheat elseif stage == "Charge2" then COLORS.Burst else RaceVfx.BoltColor
	local base = if entry.Venting then "Vent" elseif charge.Held then "Charge" else "Off"
	if base ~= entry.ArcBase then
		entry.ArcBase = base
		entry.NextRollAt = math.min(entry.NextRollAt, clock)
	end
	setGlow(entry, stage == "Charge2" and charge.Held and not reducedMotion and enabled.All)
end

----------------------------------------------------------------------
-- Rings
----------------------------------------------------------------------
local function parkRing(ring: any)
	if ring.Alive then
		ring.Alive = false
		for _, beam in ring.Beams do
			beam.Enabled = false
		end
	end
end

-- Count rings of `look` Gap seconds apart at `at` (flat on the ground, or across the track).
local function startRings(look: any, at: CFrame, clock: number, color: Color3)
	if not look or #shared.Rings == 0 or not enabled.All then
		return
	end
	local frame = CFrame.new(at.Position) * (if look.Vertical then VERTICAL else CFrame.new())
	local count = if reducedMotion then 1 else look.Count or 1
	for k = 1, count do
		-- A free ring, else the one that started first.
		local pick = nil
		for _, ring in shared.Rings do
			if not ring.Alive then
				pick = ring
				break
			end
			if not pick or ring.Start < pick.Start then
				pick = ring
			end
		end
		parkRing(pick)
		pick.Alive = true
		pick.Placed = false
		pick.Start = clock + (k - 1) * (look.Gap or 0)
		pick.Look = look
		pick.Frame = frame
		pick.Color = color
		pick.Scale = if reducedMotion then 0.7 else 1
	end
end

local function queueMove(part: BasePart, frame: CFrame)
	table.insert(bulkParts, part)
	table.insert(bulkFrames, frame)
end

local function stepRing(ring: any, clock: number)
	local look = ring.Look
	local alpha = (clock - ring.Start) / look.Life
	if alpha < 0 then
		return
	end
	if alpha >= 1 then
		parkRing(ring)
		return
	end
	if not ring.Placed then
		ring.Placed = true
		queueMove(ring.Part, ring.Frame)
		local sequence = ColorSequence.new(ring.Color)
		for _, beam in ring.Beams do
			beam.Color = sequence
			beam.Enabled = true
		end
	end
	local radius, width, fade = RaceVfx.RingShape(look, alpha)
	radius *= ring.Scale
	local handle = radius * RaceVfx.CurveK
	local sequence = fadeSequence(fade)
	for q, point in ring.Points do
		point.CFrame = CFrame.new(RING_DIRS[q] * radius) * RING_ROT[q]
	end
	for _, beam in ring.Beams do
		beam.CurveSize0 = handle
		beam.CurveSize1 = handle
		beam.Width0 = width
		beam.Width1 = width
		beam.Transparency = sequence
	end
end

local function feetFrame(entry: any): CFrame
	return CFrame.new(entry.Root.CFrame.Position - Vector3.new(0, RaceVfx.FeetDrop, 0))
end

----------------------------------------------------------------------
-- After-images
----------------------------------------------------------------------
local function parkGhost(ghost: any)
	if ghost.Alive then
		ghost.Alive = false
		ghost.Shown = 1
		for _, part in ghost.Parts do
			part.Transparency = 1
		end
	end
end

local function stamp(entry: any, ghost: any, clock: number, life: number)
	parkGhost(ghost)
	-- 2026-09-26 (owner): one colour, the sprint's dark shadow (no aura / gold alternation).
	local color = RaceVfx.GhostColor
	local anchor = (entry.Torso or entry.Root).CFrame.Position
	local start = GHOST.Transparency[1]
	if entry.Plan.IsLocal and cameraPosition and (anchor - cameraPosition).Magnitude < GHOST.CameraClear then
		start = 1 -- stamped at the camera: it shows once the racer has left it behind
	end
	table.clear(ghost.Hidden)
	for name, part in ghost.ByName do
		local source = entry.Body[name]
		if source and source.Parent then
			queueMove(part, source.CFrame)
			if part.Color ~= color then
				part.Color = color
			end
			part.Transparency = start
		else
			ghost.Hidden[part] = true
		end
	end
	ghost.Alive = true
	ghost.Born = clock
	ghost.Life = life
	ghost.Shown = start
	ghost.Anchor = anchor
	ghost.Near = entry.Plan.IsLocal
	entry.Stamps += 1
end

-- 0.3 -> 0.7 -> 1 over its life, in steps of 0.05; not drawn right at the camera (the chase
-- camera passes through the newest ones at race speed).
local function fadeGhost(ghost: any, clock: number, eye: Vector3?)
	if not ghost.Alive then
		return
	end
	local t = RaceVfx.GhostTransparency(clock - ghost.Born, ghost.Life)
	if t >= 0.999 then
		parkGhost(ghost)
		return
	end
	t = math.floor(t * 20 + 0.5) / 20
	if eye and ghost.Near and ghost.Anchor and (ghost.Anchor - eye).Magnitude < GHOST.CameraClear then
		t = 1
	end
	if t ~= ghost.Shown then
		ghost.Shown = t
		for _, part in ghost.Parts do
			if not ghost.Hidden[part] then
				part.Transparency = t
			end
		end
	end
end

local function stepGhosts(entry: any, clock: number)
	if not entry.GhostOk or not enabled.Ghosts or not entry.Plan.GhostEvery then
		return
	end
	local velocity = entry.Root.AssemblyLinearVelocity
	local speed = math.sqrt(velocity.X * velocity.X + velocity.Z * velocity.Z)
	if not RaceVfx.GhostsWanted(speed, entry.Cruise, clock < entry.GhostBurstUntil, entry.Super) then
		return
	end
	if clock + 1e-4 < entry.NextGhostAt then
		return
	end
	-- On the beat (a frame late is not carried into the next stamp), never a catch-up burst.
	local every = entry.Plan.GhostEvery
	entry.NextGhostAt += every
	if entry.NextGhostAt <= clock then
		entry.NextGhostAt = clock + every
	end
	local ghost
	if entry.Plan.IsLocal then
		ghost = entry.Ghosts[entry.GhostIndex]
		entry.GhostIndex = entry.GhostIndex % math.max(1, #entry.Ghosts) + 1
	else
		ghost = shared.Others[shared.OthersIndex]
		shared.OthersIndex = shared.OthersIndex % math.max(1, #shared.Others) + 1
	end
	if ghost then
		stamp(entry, ghost, clock, entry.Plan.GhostLife)
	end
end

local function parkAllGhosts()
	for _, entry in entries do
		for _, ghost in entry.Ghosts do
			parkGhost(ghost)
		end
	end
	for _, ghost in shared.Others do
		parkGhost(ghost)
	end
end

----------------------------------------------------------------------
-- GO, super speed, pads, the finish
----------------------------------------------------------------------
local function play(sound: Sound?, volume: number?)
	if sound and RaceVfx.SoundsOn() then
		if volume then
			sound.Volume = volume
		end
		pcall(function()
			(sound :: any):Play()
		end)
	end
end

-- GO: the Sonic Boom in the world (the screen's is RacePoseClient's).
function RaceVfx.Burst(character: Model, grade: string?, now: number?)
	local entry = entries[character]
	if not entry or entry.Launched then
		return
	end
	local clock = now or os.clock()
	local key = if grade and LAUNCH.Grade[grade] ~= nil then grade else "Ok"
	local share = LAUNCH.Grade[key] or 0
	entry.Launched = true
	entry.Venting = false
	entry.Charge.Held = false
	entry.ArcBase = if entry.Super then "Super" else "Off"
	setGlow(entry, false)
	if key == "Stall" then
		-- A red sputter: half the arcs, nothing thrown.
		flash(entry, clock, LIGHTNING.FlashSeconds * 0.8, COLORS.Overheat, 0.5)
		return
	end
	flash(entry, clock, LIGHTNING.FlashSeconds * (0.5 + 0.5 * share), COLORS.Burst)
	entry.GhostBurstUntil = clock + (GHOST.BurstSeconds[key] or 0)
	entry.NextGhostAt = clock
	if entry.RingNear then
		startRings(RINGS.Go[key], feetFrame(entry), clock, COLORS.Burst)
	end
	if entry.Plan.IsLocal then
		play(entry.Sounds.Go, 0.25 + 0.4 * share)
	elseif entry.Distance <= RaceVfx.BoomDistance and share >= 0.6 then
		play(entry.Sounds.Boom)
	end
	lightFlash(entry, clock, share)
end

function RaceVfx.SetSuper(character: Model, on: boolean, now: number?)
	local entry = entries[character]
	if not entry or entry.Super == (on == true) then
		return
	end
	local clock = now or os.clock()
	entry.Super = on == true
	if entry.Super then
		entry.ArcBase = "Super"
		entry.NextRollAt = math.min(entry.NextRollAt, clock)
		if entry.RingNear then
			local root = entry.Root.CFrame.Position
			startRings(RINGS.Super, CFrame.new(root), clock, entry.AuraTint or RaceVfx.BoltColor)
		end
		if entry.Plan.IsLocal then
			play(entry.Sounds.Enter)
			play(entry.Sounds.Boom)
		elseif entry.Distance <= RaceVfx.BoomDistance then
			play(entry.Sounds.Boom)
		end
	else
		entry.ArcBase = "Off"
	end
end

-- A speed pad: a flash of arcs, a ring on the ground, a burst of after-images, the whoosh.
function RaceVfx.PadBoost(character: Model, now: number?)
	local entry = entries[character]
	if not entry then
		return
	end
	local clock = now or os.clock()
	flash(entry, clock, LIGHTNING.PadFlashSeconds, RaceVfx.BoltColor)
	entry.GhostBurstUntil = math.max(entry.GhostBurstUntil, clock + GHOST.PadSeconds)
	if entry.RingNear then
		startRings(RINGS.Pad, feetFrame(entry), clock, RaceVfx.BoltColor)
	end
	if entry.Plan.IsLocal then
		play(entry.Sounds.Whoosh)
	end
	lightFlash(entry, clock, 0.4)
end

-- The finish line: a gate of rings across the track at `at` (Race/RacePoseClient passes the
-- line under the racer; else where the racer is).
function RaceVfx.Finish(character: Model, at: CFrame?, now: number?)
	local entry = entries[character]
	if not entry then
		return
	end
	local clock = now or os.clock()
	flash(entry, clock, LIGHTNING.FinishFlashSeconds, COLORS.Burst)
	entry.GhostBurstUntil = math.max(entry.GhostBurstUntil, clock + GHOST.FinishSeconds)
	if entry.RingNear then
		startRings(RINGS.Finish, at or entry.Root.CFrame, clock, COLORS.Burst)
	end
	lightFlash(entry, clock, 0.6)
end

-- A kept entry back to its state after Prewarm: no arcs, no after-images, no super.
function resetEntry(entry: any)
	entry.Launched = false
	entry.Super = false
	entry.Venting = false
	entry.Charge = newCharge()
	entry.Stage = "Off"
	entry.ArcBase = "Off"
	entry.ArcLevel = 0
	entry.FlashUntil = -math.huge
	entry.GhostBurstUntil = -math.huge
	entry.NextGhostAt = 0
	entry.StyleKey = nil
	hideArcs(entry)
	for _, ghost in entry.Ghosts do
		parkGhost(ghost)
	end
	endLight(entry)
end

function RaceVfx.SetReducedMotion(on: boolean)
	reducedMotion = on == true
end

-- The kill switches: All (every race VFX: arcs, rings, after-images, the glow) and Ghosts (the
-- after-images alone). Off takes what shows away at once.
function RaceVfx.SetEnabled(flags: any)
	local all = type(flags) ~= "table" or flags.All ~= false
	local ghosts = all and (type(flags) ~= "table" or flags.Ghosts ~= false)
	enabled.All, enabled.Ghosts = all, ghosts
	if not all then
		for _, entry in entries do
			hideArcs(entry)
			endLight(entry)
		end
		for _, ring in shared.Rings do
			parkRing(ring)
		end
	end
	if not ghosts then
		parkAllGhosts()
	end
end

function RaceVfx.IsEnabled(): (boolean, boolean)
	return enabled.All, enabled.Ghosts
end

----------------------------------------------------------------------
-- Step: one RenderStepped for every racer
----------------------------------------------------------------------
-- The 4 Hz distance pass: who is near enough to show, and which other racers get arcs and
-- after-images (the nearest OthersArcCap / OthersGhostCap inside their distances).
local function lodPass(camera: Vector3?)
	table.clear(ranked)
	for _, entry in entries do
		local root = entry.Root
		entry.Distance = if camera and root.Parent then (root.CFrame.Position - camera).Magnitude else 0
		if entry.Plan.IsLocal then
			entry.Near, entry.ArcNear, entry.RingNear = true, true, true
			entry.GhostOk = entry.Plan.GhostPool > 0
		else
			entry.Near = entry.Distance <= entry.Plan.Distance
			entry.RingNear = entry.Distance <= entry.Plan.RingDistance
			table.insert(ranked, entry)
		end
	end
	table.sort(ranked, function(a, b)
		return a.Distance < b.Distance
	end)
	local arcs, ghosts = 0, 0
	for _, entry in ranked do
		local plan = entry.Plan
		local arcOk = #entry.Arcs > 0 and entry.Distance <= plan.ArcDistance and arcs < (plan.OthersArcCap or 0)
		if arcOk then
			arcs += 1
		end
		entry.ArcNear = arcOk
		local ghostOk = #shared.Others > 0 and plan.GhostEvery ~= nil and entry.Distance <= plan.GhostDistance
			and ghosts < (plan.OthersGhostCap or 0)
		if ghostOk then
			ghosts += 1
		end
		entry.GhostOk = ghostOk
	end
end

function RaceVfx.Step(dt: number, camera: Vector3?, now: number?)
	local clock = now or os.clock()
	cameraPosition = camera or cameraPosition
	if clock >= nextLodAt then
		nextLodAt = clock + RaceVfx.LodSeconds
		lodPass(cameraPosition)
	end
	table.clear(bulkParts)
	table.clear(bulkFrames)
	if enabled.All then
		for character, entry in entries do
			if not entry.Root.Parent or character.Parent == nil then
				continue
			end
			stepArcs(entry, clock)
			stepLight(entry, clock)
			for _, ghost in entry.Ghosts do
				fadeGhost(ghost, clock, cameraPosition)
			end
			stepGhosts(entry, clock)
		end
		for _, ghost in shared.Others do
			fadeGhost(ghost, clock, cameraPosition)
		end
		for _, ring in shared.Rings do
			if ring.Alive then
				stepRing(ring, clock)
			end
		end
	end
	if #bulkParts > 0 then
		if typeof(workspace) == "Instance" then
			workspace:BulkMoveTo(bulkParts, bulkFrames, Enum.BulkMoveMode.FireCFrameChanged)
		else
			for index, part in bulkParts do
				part.CFrame = bulkFrames[index]
			end
		end
	end
end

----------------------------------------------------------------------
-- Release
----------------------------------------------------------------------
function RaceVfx.Release(character: Model)
	local entry = entries[character]
	if not entry then
		return
	end
	entries[character] = nil
	for _, sound in entry.Sounds do
		sound:Destroy()
	end
	for _, point in entry.Attachments do
		point:Destroy()
	end
	if entry.Light then
		entry.Light:Destroy()
	end
	entry.Folder:Destroy()
end

-- Everything, the shared pools too.
function RaceVfx.ReleaseAll()
	for character in entries do
		RaceVfx.Release(character)
	end
	destroyShared()
end

function RaceVfx.Count(): number
	local count = 0
	for _ in entries do
		count += 1
	end
	return count
end

-- Racers tracked, or a ring / another racer's after-image still playing out (the client keeps
-- its RenderStepped until nothing is).
function RaceVfx.Active(): boolean
	if next(entries) ~= nil then
		return true
	end
	for _, ring in shared.Rings do
		if ring.Alive then
			return true
		end
	end
	for _, ghost in shared.Others do
		if ghost.Alive then
			return true
		end
	end
	return false
end

-- The shared pools (the tests read them).
function RaceVfx.Shared(): any
	return shared
end

return RaceVfx
