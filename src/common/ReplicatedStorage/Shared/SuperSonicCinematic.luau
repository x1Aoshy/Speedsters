--!strict
-- ReplicatedStorage/Shared/SuperSonicCinematic.luau — the camera shots of the "Super Sonic vs Dr. Eggman"
-- live event (2026-09-26, owner: "cinematics that look good, also on phones"). Pure numbers: every shot is
-- a function of its own clock and a context the client fills (where the player, the camera and Eggman
-- are), so audit/test_u4_supersonic_client checks them frame by frame (smooth, never under the floor,
-- starting on the player's camera and ending on it).
--   Intro     Eggman lifts off from his lobby spot: a low shot on him, the camera cranes up and round his
--             side as he rises, then frames him over the lobby from behind the player, and hands the camera back.
--   Emeralds  the 7 Chaos Emeralds round the local player: a full turn round them that closes in for the
--             absorption, and comes back round to the player's own camera.
--   Outro     the defeat (the Egg Mobile crashing down) / the escape: the camera looks up at him from near the
--             player, follows him down to the crash (or off into the sky), and comes back.
--   Entry     (v3: the fight moved to the race map) right after the Teleport beat's fade: from behind the
--             player the camera frames Eggman flying into the arena, then hands the camera back.
-- 2026-09-26 (owner, v3) "better camera movement: smoother, more cinematic paths (eased splines, gentle FOV
-- changes, no jerks, no clipping through walls near Eggman's spot) and a smooth return":
--   * every shot is a set of KEYS (eye, look-at target, field of view at a time), made once when the shot
--     starts from the context (Eggman's path is a pure function of the clock, so where he will be is known),
--     joined by a cubic Hermite spline with Catmull-Rom tangents over the keys' own times and zero speed at
--     both ends (Spline): no corners, no sudden accelerations. The first key IS the player's camera (its eye,
--     a target down its look, its field of view) and the last key IS where the player's camera will be
--     (ReturnCam, the player's own field of view): the shot starts and ends at rest on the player's view;
--   * the look-at target follows Eggman's small wobbles only where the shot is on him (Follow weight), the
--     eye never does (a steady crane, not a shaky one);
--   * the field of view moves on its own spline, never faster than FovRate degrees a second;
--   * clipping: the client passes ctx.clear(from, to) -> the free distance from `from` toward `to` (a raycast;
--     nil = clear). Each eye key is pulled in front of whatever stands between it and its target when the
--     keys are made, and Guard keeps the eye clear every frame (it snaps in front of a wall at once and
--     eases back out, never popping);
--   * a gentler hand-back: BlendOut 1.1 s, eased both ways, from the shot's own last key.
-- The letterbox follows CinematicFit's shares (0.11 on computers, 0.05 on phones).
local Vector3, CFrame = Vector3, CFrame
if Vector3 == nil or CFrame == nil then
	local lateRequire: any = require
	local ok, roblox = pcall(lateRequire, "@lune/roblox")
	if ok and type(roblox) == "table" then
		Vector3, CFrame = roblox.Vector3, roblox.CFrame
	end
end

local Cine = {}

Cine.Version = 3
Cine.BlendIn = 0.8 -- (v2) a shot without keys blended in from the player's camera this long
Cine.BlendOut = 1.1 -- seconds of the hand-back to the player's live camera (eased)
Cine.BarsIn = 0.45 -- the letterbox slides in / out
Cine.BarsOut = 0.4
Cine.Fov = 70
Cine.FovRate = 24 -- degrees a second at most
Cine.MinAboveFloor = 1.6 -- the eye never goes lower than this over ctx.floorY
Cine.MaxSeconds = 12 -- a watchdog: no shot ever holds the camera longer
Cine.LookDistance = 40 -- the first / last keys' target: this far down the player's look
-- Clipping (ctx.clear): the eye stays ClipMargin studs in front of what it would hit, never closer than ClipMin
-- to its target; after a wall it eases back out at ClipGrow studs a second.
Cine.ClipMargin = 1.5
Cine.ClipMin = 4
Cine.ClipGrow = 16

-- 2026-09-26 (owner): the shots' beats, in seconds at their design length (Length); a phase of another
-- length stretches them (Scale). The contract's FreezeWindows use these lengths (Emeralds 6.2, Outro 5.8).
Cine.Shots = {
	Intro = {
		Length = 7.5,
		BlendIn = 1.2, -- his spot is across the lobby: the swoop from the player's camera to him
		LiftShake = 0.5, -- the lift-off (SSE.Boss.LiftHold: he rises from the start): the screen shakes
		Establish = 2.2, -- low on him at his spot, dollying in ("Sonic! ...": SSE.Dialogue at 0.8)
		Rise = { 3.5, 4.9 }, -- the crane up round his side as he climbs ("I'll have my revenge!" at 3.9)
		Frame = 6.15, -- from behind the player: him over the lobby, the fight is on
	},
	Emeralds = {
		Length = 6.2,
		Orbit = { 0, 4.0 }, -- round the player, the gems spinning
		PushIn = { 4.0, 5.2 }, -- they converge: the camera closes in on the chest
		Flash = 5.2, -- SSE.Emeralds.AbsorbAt: the absorption
		Hold = { 5.2, 5.6 },
		Turn = 360, -- degrees round the player (it ends where it began: the player's camera)
	},
	-- The Defeat / Escape: looking up at him from near the player, following him (down to the crash, or off into
	-- the sky), then back. `Follow` = the part spent on him.
	Outro = {
		Length = 5.8,
		Follow = { 0.9, 4.4 },
	},
	-- 2026-09-26 (owner, v3): Eggman flying into the race arena after the Teleport beat (the rest of the beat).
	Entry = {
		Length = 2.9,
		Look = { 0.8, 1.8 },
	},
}

----------------------------------------------------------------------
-- Maths
----------------------------------------------------------------------
local function finite(v: any): boolean
	return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

-- Smootherstep: no speed and no acceleration at either end.
function Cine.Ease(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * x * (x * (x * 6 - 15) + 10)
end

function Cine.EaseOut(x: number): number
	x = math.clamp(x, 0, 1)
	return 1 - (1 - x) ^ 3
end

-- 0 before `a`, 1 after `b`, eased between.
function Cine.Window(t: number, a: number, b: number): number
	if b <= a then
		return if t >= b then 1 else 0
	end
	return Cine.Ease((t - a) / (b - a))
end

local function lerpV(a: Vector3, b: Vector3, k: number): Vector3
	return a + (b - a) * k
end

-- A frame at `eye` looking at `target` (fromMatrix: Lune's lookAt is wrong); `C` the CFrame table.
function Cine.LookAt(eye: Vector3, target: Vector3, C: any?): any
	local CF = C or CFrame
	local d = target - eye
	if d.Magnitude < 1e-4 then
		return CF.new(eye.X, eye.Y, eye.Z)
	end
	local look = d.Unit
	local up = if math.abs(look.Y) > 0.985 then Vector3.new(0, 0, -1) else Vector3.new(0, 1, 0)
	local right = look:Cross(up).Unit
	local up2 = right:Cross(look).Unit
	return CF.fromMatrix(eye, right, up2, -look)
end

-- A horizontal unit vector (fallback when `v` is vertical or tiny).
local function flat(v: Vector3, fallback: Vector3?): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	if f.Magnitude < 1e-3 then
		return fallback or Vector3.new(0, 0, -1)
	end
	return f.Unit
end
Cine.Flat = flat

-- `v` turned `angle` radians about +Y.
local function yaw(v: Vector3, angle: number): Vector3
	local c, s = math.cos(angle), math.sin(angle)
	return Vector3.new(v.X * c + v.Z * s, v.Y, -v.X * s + v.Z * c)
end
Cine.Yaw = yaw

-- 2026-09-26 (owner, v3): a cubic Hermite spline through `keys` ({ { t = seconds, v = a number or a Vector3 },
-- ... } in time order) at `t`: Catmull-Rom tangents over the keys' own spacing, zero at the first and the last
-- key (the motion starts and ends at rest). C1 everywhere; before the first / after the last key: that key.
function Cine.Spline(keys: { any }, t: number): any
	local n = #keys
	if n == 0 then
		return nil
	end
	if n == 1 or t <= keys[1].t then
		return keys[1].v
	end
	if t >= keys[n].t then
		return keys[n].v
	end
	local i = 1
	while i < n - 1 and keys[i + 1].t < t do
		i += 1
	end
	local k0, k1 = keys[i], keys[i + 1]
	local h = k1.t - k0.t
	if h <= 1e-6 then
		return k1.v
	end
	local zero = k0.v * 0
	local function tangent(j: number): any
		if j <= 1 or j >= n then
			return zero
		end
		local dt = keys[j + 1].t - keys[j - 1].t
		if dt <= 1e-6 then
			return zero
		end
		return (keys[j + 1].v - keys[j - 1].v) / dt
	end
	local m0, m1 = tangent(i), tangent(i + 1)
	local u = (t - k0.t) / h
	local u2, u3 = u * u, u * u * u
	local h00 = 2 * u3 - 3 * u2 + 1
	local h10 = u3 - 2 * u2 + u
	local h01 = -2 * u3 + 3 * u2
	local h11 = u3 - u2
	return k0.v * h00 + m0 * (h10 * h) + k1.v * h01 + m1 * (h11 * h)
end

-- A shot's beats at a phase of `length` seconds (the design's seconds times length / Length).
function Cine.Scale(kind: string, length: number?): number
	local shot = (Cine.Shots :: any)[kind]
	local l = tonumber(length)
	if not shot or not l or not finite(l) or l <= 0 then
		return 1
	end
	return math.clamp(l / shot.Length, 0.6, 1.6)
end

function Cine.Length(kind: string, length: number?): number
	local shot = (Cine.Shots :: any)[kind]
	return (shot and shot.Length or 5) * Cine.Scale(kind, length)
end

----------------------------------------------------------------------
-- The context (the client fills it at the shot's start; functions are sampled every frame)
----------------------------------------------------------------------
-- ctx = {
--   startCam: CFrame          the camera when the shot began
--   startFov: number?          its field of view (Cine.Fov)
--   endFov: number?            the player's own field of view to hand back (startFov)
--   root: () -> Vector3        the local character's root now
--   rootAtStart: Vector3
--   boss: (t) -> Vector3        Eggman's ship centre t seconds into the shot
--   spot: Vector3?             Intro: where he stood in the lobby
--   crash: Vector3?            Outro (v3): where the broken Egg Mobile hits the ground (the contract's crash)
--   origin: Vector3            the event's origin (the lobby's spawn)
--   floorY: number             the lobby's floor height
--   length: number?            the phase's length (Scale)
--   clear: ((from, to) -> number?)?   (v3) the free distance from `from` toward `to`, nil when clear
-- }

-- Where the player's own camera will be: the offset it had from the root at the start, the same look.
function Cine.ReturnCam(ctx: any, C: any?): any
	local start = ctx.startCam
	local CF = C or CFrame
	local rootNow = ctx.root()
	local offset = start.Position - ctx.rootAtStart
	local eye = rootNow + offset
	return CF.fromMatrix(eye, start.RightVector, start.UpVector, -start.LookVector)
end

local function keepAbove(eye: Vector3, floorY: number?): Vector3
	local y = tonumber(floorY)
	if y and eye.Y < y + Cine.MinAboveFloor then
		return Vector3.new(eye.X, y + Cine.MinAboveFloor, eye.Z)
	end
	return eye
end

-- An eye pulled in front of what stands between it and its target (ctx.clear), never closer than ClipMin.
local function clearEye(ctx: any, eye: Vector3, target: Vector3): Vector3
	local clear = ctx.clear
	if type(clear) ~= "function" then
		return eye
	end
	local offset = eye - target
	local want = offset.Magnitude
	if want < 1e-3 then
		return eye
	end
	local ok, free = pcall(clear, target, eye)
	if not ok or type(free) ~= "number" or free ~= free or free >= want then
		return eye
	end
	local keep = math.max(Cine.ClipMin, free - Cine.ClipMargin)
	if keep >= want then
		return eye
	end
	return target + offset.Unit * keep
end

-- The player's view at the start and where it will be at the end (the first and the last keys).
local function endKeys(ctx: any): (Vector3, Vector3, Vector3, Vector3)
	local start = ctx.startCam
	local startEye = start.Position
	local startLook = startEye + start.LookVector * Cine.LookDistance
	local endEye = ctx.rootAtStart + (startEye - ctx.rootAtStart)
	local endLook = endEye + start.LookVector * Cine.LookDistance
	return startEye, startLook, endEye, endLook
end

local function fovs(ctx: any): (number, number)
	local a = tonumber(ctx.startFov) or Cine.Fov
	local b = tonumber(ctx.endFov) or a
	return a, b
end

-- The keys of a shot, made once per context (ctx._keys).
local function key(list: { any }, t: number, v: any)
	table.insert(list, { t = t, v = v })
end

-- The Intro: the swoop to him at his spot, the dolly in, the crane up round his side, then behind the player.
local function introKeys(ctx: any): any
	local s = Cine.Scale("Intro", ctx.length)
	local b = Cine.Shots.Intro
	local length = Cine.Length("Intro", ctx.length)
	local spot: Vector3 = ctx.spot or ctx.boss(0)
	local origin: Vector3 = ctx.origin
	local front = flat(origin - spot, Vector3.new(0, 0, -1)) -- he faces the lobby
	local side = Vector3.new(-front.Z, 0, front.X)
	local up = Vector3.new(0, 1, 0)
	local root: Vector3 = ctx.rootAtStart
	local startEye, startLook, endEye, endLook = endKeys(ctx)
	local startFov, endFov = fovs(ctx)
	local tIn, tEst = b.BlendIn * s, b.Establish * s
	local tRise1, tRise2, tFrame = b.Rise[1] * s, b.Rise[2] * s, b.Frame * s
	local cockpit = spot + up * 3.5
	local eyes, looks, fov, follow = {}, {}, {}, {}
	local function add(t: number, eye: Vector3, look: Vector3, f: number, w: number)
		key(eyes, t, keepAbove(clearEye(ctx, eye, look), ctx.floorY))
		key(looks, t, look)
		key(fov, t, f)
		key(follow, t, w)
	end
	key(eyes, 0, startEye)
	key(looks, 0, startLook)
	key(fov, 0, startFov)
	key(follow, 0, 0)
	-- 1. Low in front of him, a little to the side (a three-quarter view), dollying in as he stirs.
	add(tIn, spot + front * 24 + side * 8.5 + up * 3, cockpit, 60, 0)
	add(tEst, spot + front * 19 + side * 6.5 + up * 5, lerpV(cockpit, ctx.boss(tEst), 0.75), 58, 0.6)
	-- 2. The crane: under his side, looking up as he climbs, swinging round him.
	local b1, b2 = ctx.boss(tRise1), ctx.boss(tRise2)
	add(tRise1, b1 + yaw(front, math.rad(-55)) * 30 + up * -8, b1, 62, 1)
	add(tRise2, b2 + yaw(front, math.rad(-95)) * 38 + up * -4, b2, 66, 1)
	-- 3. From behind the player: the ship big over the lobby, the fight is on.
	local b3 = ctx.boss(tFrame)
	local toBoss = flat(b3 - root, front)
	add(tFrame, root - toBoss * 15 + up * 6.5, lerpV(root + up * 3, b3, 0.8), 68, 0.8)
	-- 4. The player's own camera (the hand-back starts from here, at rest).
	key(eyes, length, endEye)
	key(looks, length, endLook)
	key(fov, length, endFov)
	key(follow, length, 0)
	return { eyes = eyes, looks = looks, fov = fov, follow = follow, boss = {
		{ t = 0, v = spot }, { t = tIn, v = ctx.boss(tIn) }, { t = tEst, v = ctx.boss(tEst) }, { t = tRise1, v = b1 },
		{ t = tRise2, v = b2 }, { t = tFrame, v = b3 }, { t = length, v = ctx.boss(length) },
	} }
end

-- The Emeralds: a full turn round the player's chest (polar: angle, radius, height), closing in for the
-- absorption; it starts and ends on the player's own camera.
local function emeraldsKeys(ctx: any): any
	local s = Cine.Scale("Emeralds", ctx.length)
	local b = Cine.Shots.Emeralds
	local length = Cine.Length("Emeralds", ctx.length)
	local startFov, endFov = fovs(ctx)
	local offset = ctx.startCam.Position - ctx.rootAtStart
	local radius0 = math.max(4, Vector3.new(offset.X, 0, offset.Z).Magnitude)
	local height0 = offset.Y - 0.8
	local turn = math.rad(b.Turn)
	local angle, radius, height, fov = {}, {}, {}, {}
	local function add(t: number, a: number, r: number, h: number, f: number)
		key(angle, t, a)
		key(radius, t, r)
		key(height, t, h)
		key(fov, t, f)
	end
	add(0, 0, radius0, height0, startFov)
	add(1.3 * s, turn * 0.2, 12, 3.4, startFov - 3)
	add(b.Orbit[2] * s, turn * 0.55, 9.5, 2.3, startFov - 5)
	add(b.Flash * s, turn * 0.72, 6.8, 1.0, startFov - 9)
	add(b.Hold[2] * s, turn * 0.77, 7.2, 1.2, startFov - 7)
	add(length, turn, radius0, height0, endFov)
	return { angle = angle, radius = radius, height = height, fov = fov }
end

-- The Outro: near the player looking up at him, following him down to the crash (or off into the sky), back.
local function outroKeys(ctx: any): any
	local s = Cine.Scale("Outro", ctx.length)
	local b = Cine.Shots.Outro
	local length = Cine.Length("Outro", ctx.length)
	local root: Vector3 = ctx.rootAtStart
	local up = Vector3.new(0, 1, 0)
	local startEye, startLook, endEye, endLook = endKeys(ctx)
	local startFov, endFov = fovs(ctx)
	local t1, t2 = b.Follow[1] * s, b.Follow[2] * s
	local mid = (t1 + t2) / 2
	local b1, bm, b2 = ctx.boss(t1), ctx.boss(mid), ctx.boss(t2)
	local crash: Vector3? = ctx.crash
	local away = flat(bm - root, Vector3.new(0, 0, -1))
	local side = Vector3.new(-away.Z, 0, away.X)
	local eyes, looks, fov, follow = {}, {}, {}, {}
	local function add(t: number, eye: Vector3, look: Vector3, f: number, w: number)
		key(eyes, t, keepAbove(clearEye(ctx, eye, look), ctx.floorY))
		key(looks, t, look)
		key(fov, t, f)
		key(follow, t, w)
	end
	key(eyes, 0, startEye)
	key(looks, 0, startLook)
	key(fov, 0, startFov)
	key(follow, 0, 0)
	add(t1, root - away * 12 + side * 5 + up * 3, b1, 64, 1)
	add(mid, root - away * 14 + side * 6.5 + up * 4, bm, 60, 1)
	if crash then
		-- The crash: the eye swings a little wider to see the wreck hit the ground.
		add(t2, root - away * 13 + side * 9 + up * 5.5, lerpV(b2, crash, 0.5), 60, 0.6)
	else
		add(t2, root - away * 16 + side * 5 + up * 5, b2, 56, 1)
	end
	key(eyes, length, endEye)
	key(looks, length, endLook)
	key(fov, length, endFov)
	key(follow, length, 0)
	return { eyes = eyes, looks = looks, fov = fov, follow = follow, boss = {
		{ t = 0, v = ctx.boss(0) }, { t = t1, v = b1 }, { t = mid, v = bm }, { t = t2, v = b2 }, { t = length, v = ctx.boss(length) },
	} }
end

-- The Entry (v3): from behind the player, looking up at him flying into the arena, then back.
local function entryKeys(ctx: any): any
	local s = Cine.Scale("Entry", ctx.length)
	local b = Cine.Shots.Entry
	local length = Cine.Length("Entry", ctx.length)
	local root: Vector3 = ctx.rootAtStart
	local up = Vector3.new(0, 1, 0)
	local startEye, startLook, endEye, endLook = endKeys(ctx)
	local startFov, endFov = fovs(ctx)
	local t1, t2 = b.Look[1] * s, b.Look[2] * s
	local b1, b2 = ctx.boss(t1), ctx.boss(t2)
	local toward = flat(b2 - root, flat(ctx.startCam.LookVector, Vector3.new(0, 0, -1)))
	local side = Vector3.new(-toward.Z, 0, toward.X)
	local eyes, looks, fov, follow = {}, {}, {}, {}
	local function add(t: number, eye: Vector3, look: Vector3, f: number, w: number)
		key(eyes, t, keepAbove(clearEye(ctx, eye, look), ctx.floorY))
		key(looks, t, look)
		key(fov, t, f)
		key(follow, t, w)
	end
	key(eyes, 0, startEye)
	key(looks, 0, startLook)
	key(fov, 0, startFov)
	key(follow, 0, 0)
	add(t1, root - toward * 13 + side * 4 + up * 4, lerpV(root + up * 3, b1, 0.85), 64, 0.9)
	add(t2, root - toward * 15 + side * 6 + up * 5, lerpV(root + up * 3, b2, 0.8), 62, 0.9)
	key(eyes, length, endEye)
	key(looks, length, endLook)
	key(fov, length, endFov)
	key(follow, length, 0)
	return { eyes = eyes, looks = looks, fov = fov, follow = follow, boss = {
		{ t = 0, v = ctx.boss(0) }, { t = t1, v = b1 }, { t = t2, v = b2 }, { t = length, v = ctx.boss(length) },
	} }
end

local MAKERS = { Intro = introKeys, Emeralds = emeraldsKeys, Outro = outroKeys, Entry = entryKeys }

local function keysOf(kind: string, ctx: any): any
	ctx._keys = ctx._keys or {}
	local keys = ctx._keys[kind]
	if not keys then
		keys = MAKERS[kind](ctx)
		ctx._keys[kind] = keys
	end
	return keys
end

-- The shot's eye, target and field of view at t.
local function shot(kind: string, t: number, ctx: any): (Vector3, Vector3, number)
	local keys = keysOf(kind, ctx)
	if kind == "Emeralds" then
		local root = ctx.root()
		local chest = root + Vector3.new(0, 0.8, 0)
		local offset = ctx.startCam.Position - ctx.rootAtStart
		local startDir = flat(offset, Vector3.new(0, 0, 1))
		local a = Cine.Spline(keys.angle, t)
		local r = Cine.Spline(keys.radius, t)
		local h = Cine.Spline(keys.height, t)
		local eye = chest + yaw(startDir, a) * r + Vector3.new(0, h, 0)
		-- The look: from the player's own look (at the start) onto the chest, and back onto the player's look.
		local startLook = ctx.startCam.LookVector
		local kLook = Cine.Window(t, 0, 1.2) * (1 - Cine.Window(t, Cine.Length("Emeralds", ctx.length) - 1.2, Cine.Length("Emeralds", ctx.length)))
		local ownLook = eye + startLook * Cine.LookDistance
		return eye, lerpV(ownLook, chest, kLook), Cine.Spline(keys.fov, t)
	end
	local eye = Cine.Spline(keys.eyes, t)
	local look = Cine.Spline(keys.looks, t)
	local w = math.clamp(Cine.Spline(keys.follow, t), 0, 1)
	if w > 0 and ctx.boss then
		-- Eggman's own small moves between the keys (the look only: the eye never shakes with him).
		look += (ctx.boss(t) - Cine.Spline(keys.boss, t)) * w
	end
	return eye, look, Cine.Spline(keys.fov, t)
end

-- The camera at t seconds into `kind`: (CFrame, field of view). It starts on ctx.startCam and ends on the
-- player's live camera (ReturnCam, blended over BlendOut); the eye never goes under ctx.floorY + MinAboveFloor.
function Cine.Frame(kind: string, t: number, ctx: any, C: any?): (any, number)
	local length = Cine.Length(kind, ctx.length)
	local tt = math.clamp(t, 0, length)
	local eye, look, fov = shot(kind, tt, ctx)
	eye = keepAbove(eye, ctx.floorY)
	local cf = Cine.LookAt(eye, look, C)
	local kOut = Cine.Ease((tt - (length - Cine.BlendOut)) / Cine.BlendOut)
	if kOut > 0 then
		cf = cf:Lerp(Cine.ReturnCam(ctx, C), kOut)
	end
	if tt <= 0 then
		cf = ctx.startCam
	end
	return cf, fov
end

-- 2026-09-26 (owner, v3): the eye kept clear of walls every frame. `free` = the free distance from the target
-- toward the eye this frame (nil: clear); `state` = the shot's own table (its deficit: how much the eye is
-- pulled in). It snaps in at once in front of a wall and eases back out at ClipGrow studs a second.
function Cine.Guard(eye: Vector3, target: Vector3, free: number?, state: any, dt: number): Vector3
	local offset = eye - target
	local want = offset.Magnitude
	if want < 1e-3 then
		return eye
	end
	local allowed = want
	if type(free) == "number" and free == free and free < want then
		allowed = math.max(math.min(Cine.ClipMin, want), free - Cine.ClipMargin)
	end
	local need = math.max(0, want - allowed)
	local deficit = tonumber(state.deficit) or 0
	if need >= deficit then
		deficit = need
	else
		deficit = math.max(need, deficit - Cine.ClipGrow * math.max(tonumber(dt) or 0, 0))
	end
	state.deficit = deficit
	if deficit <= 1e-4 then
		return eye
	end
	return target + offset.Unit * math.max(want - deficit, math.min(Cine.ClipMin, want))
end

-- The letterbox bars' share of the height at t (`bars` = CinematicFit.Bars for this screen).
function Cine.Bars(t: number, length: number, bars: number): number
	local k = math.min(Cine.EaseOut(t / Cine.BarsIn), Cine.Ease((length - t) / Cine.BarsOut))
	return bars * math.clamp(k, 0, 1)
end

return Cine
