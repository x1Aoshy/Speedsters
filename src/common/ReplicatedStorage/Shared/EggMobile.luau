-- ReplicatedStorage/Shared/EggMobile.luau — Update 4 (2026-09-26, owner): Dr. Eggman's Egg Mobile, the
-- hovering ship the lobby Quests NPC drives.
-- 2026-09-26 (owner): "delete the part-built ship and make it in Blender, IDENTICAL to the reference": the
-- classic Egg Mobile (design/npc/eggmobile/reference/: a white hull over a black sphere bottom, a glass bubble
-- with a thin frame arc, a curved dashboard with a round cyan screen and two red lights, two red levers, a wide
-- low blue bench, yellow lamps in octagonal bezels, vent grilles, hazard bands with arrows, pods on flat
-- ledges, his red emblem, an octagonal exhaust nozzle under a yellow cowl). audit/egg_mobile_bpy.py models it
-- as single-colour pieces (EM_*); the owner imports them in Studio and saves design/npc/EggMobileKit.rbxm.
-- Without that file there is no ship at all (Eggman stands at his spot).
--   Build(env, floor, kit)   the ship from the kit's MeshParts (audit/u4_egg_mobile loads the kit and its
--                            manifest): every piece where the manifest puts it (the turn Studio's import added
--                            undone), its colour / material from the manifest, joined to an invisible hull root
--                            (Welds; Motor6Ds for the rear fan and the two levers), four invisible colliders
--                            loose. audit/u4_egg_mobile welds the hull to Eggman's HumanoidRootPart,
--                            so Gameplay/LobbyNpcs' PrepareOwnerModel makes the ship part of his rig.
--   SeatCFrame(floor)        where Eggman's root sits (the pose "EggmanDriving" of Shared/LobbyNpcPose sits him
--                            on the bench, legs under the cockpit floor, fists on the levers).
--   HoverValues / HoverCFrame  the hover (bob, pitch, yaw, roll) at a time: a pure function of the server clock.
--   StickAngles              the tilt that points a lever at a fist.
--   Client                   Gameplay/EggMobileClient's budget per tier (Shared/RaceFeelTier).
-- Pure data and maths plus the builder; nothing yields, connects or tweens. Lune-safe: the constructors come
-- from `env` (@lune/roblox in the build and tests, the Roblox globals in game).
local EggMobile = {}

EggMobile.ModelName = "EggMobile" -- the ship Model, a child of the Eggman model
EggMobile.Stamp = "EggMobile" -- its U4Asset attribute
-- 2026-09-26 (owner): 2 = the Blender kit (1 was the part-built ship, which a rebuild removes).
EggMobile.Version = 2
EggMobile.KitVersion = 2 -- the eggmobile_manifest.json kitVersion this builder expects
EggMobile.PoseKind = "EggmanDriving" -- Shared/LobbyNpcPose.Defs key Eggman plays in the ship
EggMobile.HullName = "EggHull" -- the invisible root every piece is joined to (and that is welded to Eggman)
EggMobile.MountName = "EggMobileMount" -- the Weld hull <- Eggman's HumanoidRootPart
EggMobile.ColliderName = "EggCollider" -- EggCollider, EggColliderL, EggColliderR, EggColliderBack
EggMobile.ColliderCount = 4
EggMobile.PiecePrefix = "EM_"
EggMobile.PartBudget = 40
EggMobile.MotorNames = { fan = "EggFanMotor", stick = "EggStickMotor" }

----------------------------------------------------------------------
-- Ship space: origin on the floor spot, forward -Z (where Eggman looks), +X his right, studs. The numbers
-- are audit/egg_mobile_bpy.py's (its manifest's "ship" block; audit/test_u4_egg_mobile checks they agree).
----------------------------------------------------------------------
EggMobile.HullCenter = { 0, 3.0, 0 } -- the hover pivots here
EggMobile.HullRadius = 3.86 -- the hull's wall (the white shell is 0.045 outside it)
EggMobile.FloorTop = 4.9 -- the cockpit floor: Eggman's legs stay under it
EggMobile.RimTop = 5.44
EggMobile.RimInner = 3.56 -- the cockpit wall
-- Eggman's HumanoidRootPart centre, turned as the ship (an R6 torso 2 studs tall: its top is at 6.55, 1.1
-- studs over the rim, so he shows from the chest up over the bench).
EggMobile.SeatRoot = { 0, 5.55, 0.45 }
-- The two red levers: the pivot at the top of each pod (ship space) and the lever's length. Their grips are
-- where the driving pose's fists rest (audit/test_u4_egg_mobile checks it).
EggMobile.Sticks = {
	Right = { Side = 1, Pivot = { 1.7, 5.12, -0.63 }, Length = 1.1, Shoulder = "Right Shoulder", Arm = "Right Arm" },
	Left = { Side = -1, Pivot = { -1.7, 5.12, -0.63 }, Length = 1.1, Shoulder = "Left Shoulder", Arm = "Left Arm" },
}
EggMobile.StickMaxTilt = 28 -- degrees
-- 2026-09-26 (owner): the lower half is the big glossy black sphere (its bottom 0.6 over the floor; the
-- hover keeps it off it), the glass bubble covers the front-left, one yellow lamp (his left).
-- The rear nozzle (axis along +Z) and the fan turning inside it.
EggMobile.Nozzle = { Y = 3.3, Z = 3.25, Depth = 1.35, Radius = 1.22 }
EggMobile.FanPivot = { 0, 3.3, 3.87 }
-- The pods on their ledges (both sides): azimuth (degrees right of forward), the frame's height, and the box
-- they fill from the hull's surface outward (local x along the hull, y up, z out).
EggMobile.Wings = { Azimuth = 120, Y = 3.05, SurfaceRadius = 3.73, Half = 1.25, YMin = -0.65, YMax = 0.66, Out = 1.9 }
-- The footprint the lobby must keep clear (audit/test_u4_egg_mobile): the hull's circle, the wings and the
-- nozzle's box under the cowl (ship space).
EggMobile.Footprint = {
	Radius = 3.95,
	Back = { XMin = -1.3, XMax = 1.3, YMin = 2.05, YMax = 5.35, ZMin = 3.8, ZMax = 4.78 },
	Top = 7.2, -- the frame arc over the glass bubble
}

-- A wing's frame on the hull (ship space): its local -Z (LookVector) points straight out of the hull.
local function wingFrame(side: number, C: any): any
	local w = EggMobile.Wings
	local a = math.rad(side * w.Azimuth)
	return C.new(w.SurfaceRadius * math.sin(a), w.Y, -w.SurfaceRadius * math.cos(a)) * C.Angles(0, -a, 0)
end
EggMobile.WingFrame = wingFrame

-- The footprint's corners beyond the hull's circle ({x, z} pairs, ship space): the wings' outer box corners
-- and the nozzle's box.
function EggMobile.FootprintCorners(C: any): { { number } }
	local w = EggMobile.Wings
	local out = {}
	for _, side in { 1, -1 } do
		local frame = wingFrame(side, C)
		for _, x in { -w.Half, 0, w.Half } do
			for _, z in { 0.5, w.Out } do
				-- The frame's -Z points outward (see wingFrame): "out" is -z locally.
				local p = frame * C.new(x, 0, -z).Position
				table.insert(out, { p.X, p.Z })
			end
		end
	end
	local b = EggMobile.Footprint.Back
	for _, x in { b.XMin, 0, b.XMax } do
		table.insert(out, { x, b.ZMax })
	end
	return out
end

-- VFX anchors (ship space), made by Gameplay/EggMobileClient: on the hull (they move with the hover) or on the
-- static collider (they stay).
EggMobile.Points = {
	PlasmaTop = { 0, 0.58, 0 }, -- hull: the bottom of the plasma emitter
	PlasmaFloor = { 0, 0.05, 0 }, -- collider: on the floor under it
	Exhaust = { { 0, 3.3, 3.62 } }, -- hull: the cyan glow inside the nozzle; the jet runs back (+Z)
	ExhaustLength = 2.9,
	Sign = { 0, 14.6, 0 }, -- collider: the QUESTS sign's centre
	SpotTop = { -3.2, 25, 3.4 }, -- collider: where the yellow spotlight comes from
	SpotTarget = { 0, 5.6, 0.3 }, -- hull: where it lands
}

EggMobile.Colors = {
	White = { 236, 238, 242 },
	Black = { 34, 34, 40 },
	Plasma = { 70, 238, 255 },
	PlasmaHot = { 200, 255, 255 },
	Lamp = { 255, 212, 36 },
	LampHot = { 255, 246, 190 },
	DashRed = { 255, 48, 48 },
	Siren = { 255, 40, 40 },
}

----------------------------------------------------------------------
-- Hover (2026-09-26): a slow bob with a ripple, a small pitch, yaw and roll. Periods in seconds,
-- amplitudes in studs / degrees. The driving pose leans with Bob, Pitch and Roll
-- (LobbyNpcPose.Defs.EggmanDriving.HoverPeriods / HoverPhases; the test keeps them equal).
----------------------------------------------------------------------
EggMobile.Hover = {
	Bob = 0.22, BobPeriod = 2.6,
	Ripple = 0.05, RipplePeriod = 1.1,
	Pitch = 1.4, PitchPeriod = 3.4, PitchPhase = 0.7,
	Yaw = 1.2, YawPeriod = 7.3,
	Roll = 2.0, RollPeriod = 4.1,
}
local TAU = math.pi * 2

-- (bob studs, pitch, yaw, roll degrees) at server time `t`.
function EggMobile.HoverValues(t: number): (number, number, number, number)
	local h = EggMobile.Hover
	local bob = h.Bob * math.sin(TAU * t / h.BobPeriod) + h.Ripple * math.sin(TAU * t / h.RipplePeriod + 0.9)
	local pitch = h.Pitch * math.sin(TAU * t / h.PitchPeriod + h.PitchPhase)
	local yaw = h.Yaw * math.sin(TAU * t / h.YawPeriod + 2.1)
	local roll = h.Roll * math.sin(TAU * t / h.RollPeriod)
	return bob, pitch, yaw, roll
end

-- The hover as a CFrame about the hull centre (in the hull centre's own axes); `C` the CFrame table.
function EggMobile.HoverCFrame(t: number, C: any): any
	local bob, pitch, yaw, roll = EggMobile.HoverValues(t)
	return C.new(0, bob, 0) * C.Angles(math.rad(pitch), math.rad(yaw), math.rad(roll))
end

-- The rotation (CFrame.Angles(rx, 0, rz), radians, in the pivot's axes) that tips an upright
-- stick toward (dx, dy, dz), at most `maxTilt` degrees off upright. Angles(rx, 0, rz) turns +Y
-- into (-sin rz, cos rz cos rx, cos rz sin rx).
function EggMobile.StickAngles(dx: number, dy: number, dz: number, maxTilt: number?): (number, number)
	local length = math.sqrt(dx * dx + dy * dy + dz * dz)
	if length < 1e-6 then
		return 0, 0
	end
	dx, dy, dz = dx / length, dy / length, dz / length
	local rz = math.asin(math.clamp(-dx, -1, 1))
	local rx = math.atan2(dz, dy)
	local tilt = math.acos(math.clamp(dy, -1, 1))
	local limit = math.rad(maxTilt or EggMobile.StickMaxTilt)
	if tilt > limit and tilt > 1e-6 then
		local k = limit / tilt
		rx, rz = rx * k, rz * k
	end
	return rx, rz
end

-- Eggman's HumanoidRootPart frame on the seat of a ship standing on `floor`.
function EggMobile.SeatCFrame(floor: any, C: any): any
	local s = EggMobile.SeatRoot
	return floor * C.new(s[1], s[2], s[3])
end

----------------------------------------------------------------------
-- The client's budget (Gameplay/EggMobileClient), per Shared/RaceFeelTier tier:
--   MotionRadius  the hover, the fan and the levers run within this many studs of the camera, and
--                 only while the ship is on screen (or closer than NearRadius)
--   Hz            nil: every frame; else that many updates a second
--   FanSpeed      radians a second (Low turns slower: at 20 Hz a fast fan would strobe)
--   PlasmaBeams   the plasma cone under the hull (1: the soft glow; 2: and its bright core)
--   Exhaust       the nozzle's plasma jet (a Beam)
--   PlasmaLight / SirenLight  PointLights (the classic ship has no siren: SirenLight finds nothing)
--   Pulse         the Neon glows (plasma, exhaust, lamps, dash lights, screen) pulse
--   Shimmer       the spotlight breathes
----------------------------------------------------------------------
EggMobile.Client = {
	TierSeconds = 5,
	VfxRadius = 230, -- beams and lights exist within this many studs of the camera
	NearRadius = 16,
	Tiers = {
		High = { MotionRadius = 150, Hz = nil, FanSpeed = 14, PlasmaBeams = 2, Exhaust = true, PlasmaLight = true, SirenLight = true, Pulse = true, Shimmer = true },
		Mid = { MotionRadius = 110, Hz = nil, FanSpeed = 12, PlasmaBeams = 1, Exhaust = true, PlasmaLight = true, SirenLight = false, Pulse = true, Shimmer = false },
		Low = { MotionRadius = 70, Hz = 20, FanSpeed = 6, PlasmaBeams = 1, Exhaust = false, PlasmaLight = false, SirenLight = false, Pulse = false, Shimmer = false },
	},
	SirenSpeed = 7, -- radians a second
	-- The QUESTS sign: studs plus pixels (never tiny far away, not huge up close), drawn within
	-- MaxDistance of the camera (the spawns are 73-85 studs away).
	Sign = { MaxDistance = 190, Studs = { 7.2, 4.0 }, Pixels = { 64, 36 } },
}

-- The sign's word, per language (Shared/TutorialText's ten; anything else reads English).
EggMobile.SignWords = {
	en = "QUESTS", es = "MISIONES", pt = "MISSÕES", ru = "ЗАДАНИЯ", ar = "المهام",
	id = "MISI", fr = "QUÊTES", de = "QUESTS", th = "เควส", tr = "GÖREVLER",
}
function EggMobile.SignWord(lang: string?): string
	return EggMobile.SignWords[lang or "en"] or EggMobile.SignWords.en
end

----------------------------------------------------------------------
-- The builder
----------------------------------------------------------------------
local function rgb(env: any, values: { number }): any
	return env.Color3.fromRGB(values[1], values[2], values[3])
end

-- A plain part (the hull root and the colliders): anchored as saved, no touch, no query unless a collider.
local function plainPart(env: any, name: string, size: any, cf: any, shape: string?): any
	local part = env.Instance.new("Part")
	if shape then
		part.Shape = env.Enum.PartType[shape]
	end
	part.Name = name
	part.Size = size
	part.CFrame = cf
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Massless = true
	part.TopSurface = env.Enum.SurfaceType.Smooth
	part.BottomSurface = env.Enum.SurfaceType.Smooth
	return part
end

local function weld(env: any, part0: any, part1: any): any
	local w = env.Instance.new("Weld")
	w.Name = "EggWeld"
	w.Part0 = part0
	w.Part1 = part1
	w.C0 = part0.CFrame:Inverse() * part1.CFrame
	w.C1 = env.CFrame.new()
	w.Parent = part1
	return w
end

-- A Motor6D turning `part1` about `pivot` (ship space) in the ship's axes: C0 / C1 carry the ship's rotation,
-- so a Transform is a rotation in ship axes about the pivot.
local function motor(env: any, floor: any, name: string, part0: any, part1: any, pivot: { number }): any
	local world = floor * env.CFrame.new(pivot[1], pivot[2], pivot[3])
	local m = env.Instance.new("Motor6D")
	m.Name = name
	m.Part0 = part0
	m.Part1 = part1
	m.C0 = part0.CFrame:Inverse() * world
	m.C1 = part1.CFrame:Inverse() * world
	m.Parent = part1
	return m
end

-- The kit (audit/u4_egg_mobile.KitFromFolder):
--   kit.templates  { [name] = MeshPart } as Studio imported them
--   kit.specs      the manifest's pieces in order: { name, role ("static" | "glow" | "fan" | "stick"), size and
--                  offset (Vector3, ship space), color {r, g, b}, material, reflectance, transparency,
--                  castShadow, glow (EggGlow kind or nil), side (1 / -1 for the moving pieces), rideOn }
--   kit.importYaw  the quarter turn (radians) Studio's import added (audit/kit_import.DetectYaw)
-- Builds the ship on `floor`; returns the Model (named EggMobile, PrimaryPart the hull root, stamped;
-- attributes EggMobileVersion, EggMobileParts, EggMobileLook, EggMobileKitVersion, EggMobileImportYaw), the
-- hull root and a report { pieces, missing = { names } }.
function EggMobile.Build(env: any, floor: any, kit: any): (any, any, any)
	assert(type(kit) == "table" and type(kit.specs) == "table" and type(kit.templates) == "table",
		"EggMobile.Build needs the Blender kit (design/npc/EggMobileKit.rbxm + its manifest): there is no part-built ship any more")
	local Vector3, CFrame = env.Vector3, env.CFrame
	local model = env.Instance.new("Model")
	model.Name = EggMobile.ModelName
	local c = EggMobile.HullCenter
	local hull = plainPart(env, EggMobile.HullName, Vector3.new(1, 1, 1), floor * CFrame.new(c[1], c[2], c[3]))
	hull.Parent = model
	model.PrimaryPart = hull
	local yaw = kit.importYaw or 0
	local quarterOdd = math.floor(yaw / (math.pi / 2) + 0.5) % 2 == 1
	local placed, report = {}, { pieces = 0, missing = {} }
	local count = 1
	-- Pass 1: every piece where the manifest puts it.
	for _, spec in kit.specs do
		local template = kit.templates[spec.name]
		if not template then
			table.insert(report.missing, spec.name)
			continue
		end
		local part = template:Clone()
		for _, child in part:GetChildren() do
			child:Destroy() -- a SurfaceAppearance or a Decal from the import would hide the manifest's colour
		end
		part.Name = spec.name
		part.Size = if quarterOdd then Vector3.new(spec.size.Z, spec.size.Y, spec.size.X) else spec.size
		part.CFrame = floor * CFrame.new(spec.offset) * CFrame.Angles(0, -yaw, 0)
		pcall(function()
			part.PivotOffset = part.CFrame:Inverse() * floor -- the pivot: the ship's floor spot
		end)
		part.Color = rgb(env, spec.color)
		part.Material = env.Enum.Material[spec.material] or env.Enum.Material.SmoothPlastic
		part.Reflectance = spec.reflectance or 0
		part.Transparency = spec.transparency or 0
		part.CastShadow = spec.castShadow == true
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Massless = true
		pcall(function()
			part.CollisionFidelity = env.Enum.CollisionFidelity.Box
		end)
		pcall(function()
			part.RenderFidelity = env.Enum.RenderFidelity.Automatic
		end)
		if spec.glow then
			part:SetAttribute("EggGlow", spec.glow)
		end
		part.Parent = model
		placed[spec.name] = part
		count += 1
	end
	-- Pass 2: the joints. Moving pieces turn on the hull's Motor6Ds about the builder's pivots (the manifest's
	-- motorPivot must agree: audit/test_u4_egg_mobile); riders weld to their moving piece; the rest to the hull.
	for _, spec in kit.specs do
		local part = placed[spec.name]
		if not part then
			continue
		end
		local rider = spec.rideOn and placed[spec.rideOn]
		if rider then
			weld(env, rider, part)
		elseif spec.role == "fan" then
			part:SetAttribute("EggFan", spec.side or 1)
			motor(env, floor, EggMobile.MotorNames.fan, hull, part, EggMobile.FanPivot)
		elseif spec.role == "stick" then
			local stick = if (spec.side or 1) > 0 then EggMobile.Sticks.Right else EggMobile.Sticks.Left
			part:SetAttribute("EggStick", stick.Side)
			motor(env, floor, EggMobile.MotorNames.stick, hull, part, stick.Pivot)
		else
			weld(env, hull, part)
		end
		report.pieces += 1
	end
	-- The colliders: invisible, loose (never moved by the hover), the only parts that collide.
	local top = EggMobile.RimTop
	local r = EggMobile.Footprint.Radius
	local colliders = {
		plainPart(env, EggMobile.ColliderName, Vector3.new(top, r * 2, r * 2), floor * CFrame.new(0, top / 2, 0) * CFrame.Angles(0, 0, math.pi / 2), "Cylinder"),
	}
	local w = EggMobile.Wings
	for _, side in { 1, -1 } do
		local frame = wingFrame(side, CFrame)
		local box = plainPart(env, EggMobile.ColliderName .. (if side > 0 then "R" else "L"),
			Vector3.new(w.Half * 2, w.YMax - w.YMin, w.Out), floor * frame * CFrame.new(0, (w.YMin + w.YMax) / 2, -w.Out / 2))
		table.insert(colliders, box)
	end
	local b = EggMobile.Footprint.Back
	table.insert(colliders, plainPart(env, EggMobile.ColliderName .. "Back", Vector3.new(b.XMax - b.XMin, b.YMax - b.YMin, b.ZMax - b.ZMin),
		floor * CFrame.new((b.XMin + b.XMax) / 2, (b.YMin + b.YMax) / 2, (b.ZMin + b.ZMax) / 2)))
	for _, collider in colliders do
		collider.CanCollide = true
		collider.CanQuery = true
		collider.Massless = false
		collider:SetAttribute("EggCollider", true)
		collider.Parent = model
		count += 1
	end
	colliders[1]:SetAttribute("EggAnchor", true) -- the static anchor of the sign, the spotlight and the floor glow

	model:SetAttribute("U4Asset", EggMobile.Stamp)
	model:SetAttribute("EggMobileVersion", EggMobile.Version)
	model:SetAttribute("EggMobileParts", count)
	model:SetAttribute("EggMobileLook", "Kit")
	model:SetAttribute("EggMobileKitVersion", kit.version or 0)
	model:SetAttribute("EggMobileImportYaw", math.floor(math.deg(yaw) + 0.5))
	return model, hull, report
end

return EggMobile
