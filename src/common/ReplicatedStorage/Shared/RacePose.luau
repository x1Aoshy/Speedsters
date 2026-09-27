--!strict
-- ReplicatedStorage/Shared/RacePose.luau — Update 4 race poses for R6 (race_fx, 2026-09-25).
-- Three procedural poses, drawn on every client for every racer (Race/RacePoseClient):
--   * Set: Flash's crouch at the line, lower and trembling as the charge overfills;
--   * Run: a sprinter's stride, leaning and swinging harder the closer to sprint speed;
--   * Super: the super-speed dash, body low and forward, arms swept back.
-- Conventions of SurfboardStance / SupermanFlightPose: rotations (and the RootJoint's drop) are
-- in each joint's parent part, about the joint, keyed by the R6 Motor6D names, and become a
-- Motor6D.Transform with SurfboardStance.Transform(motor.C0, rotation). +X on a hip or
-- shoulder swings the limb forward, -X on the RootJoint pitches the torso forward, +X on the
-- Neck tips the head up. The Humanoid keeps the root 3 studs over the floor, so each pose
-- drops the torso by what its lean raises the hips: the feet stay on the floor
-- (audit/test_u4_race_pose checks it with the real R6 C0/C1).
-- Only numbers and CFrames. Every pose writes into an `out` table when given one, so the
-- client makes no tables per frame.
local CFrame = CFrame
if CFrame == nil then
	-- Lune: the datatypes come from @lune/roblox (the dynamic require keeps Script Analysis quiet).
	local lateRequire: any = require
	local ok, roblox = pcall(lateRequire, "@lune/roblox")
	if ok and type(roblox) == "table" then
		CFrame = roblox.CFrame
	end
end

local U4: any = if typeof(script) == "Instance"
	then require((script :: any).Parent:WaitForChild("Update4Config", 10))
	else require("./Update4Config")

local POSE = U4.Race.Feel.Pose
local rad, sin, cos = math.rad, math.sin, math.cos
local TAU = 2 * math.pi

local RacePose = {}

-- Each posed joint and the part it lives in.
RacePose.Joints = {
	RootJoint = "HumanoidRootPart",
	Neck = "Torso",
	["Right Shoulder"] = "Torso",
	["Left Shoulder"] = "Torso",
	["Right Hip"] = "Torso",
	["Left Hip"] = "Torso",
}
RacePose.Names = { "RootJoint", "Neck", "Right Shoulder", "Left Shoulder", "Right Hip", "Left Hip" }

RacePose.NoiseHz = 18 -- the Set pose's tremble
RacePose.PerfectDrive = 40 -- degrees: a Perfect launch drives out through this lean
RacePose.BackOvershoot = 30 -- degrees of extra lean per unit of ease-out-back overshoot

export type Pose = { [string]: CFrame }

-- The midpoint between the hips, in the torso (the Set pose's tremble turns about it).
local HIPS = CFrame.new(0, -1, 0)
local HIPS_BACK = CFrame.new(0, 1, 0)

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------
local function finite(value: any, default: number): number
	local n = tonumber(value)
	if n == nil or n ~= n or n == math.huge or n == -math.huge then
		return default
	end
	return n
end

-- Value noise in [-1, 1], NoiseHz lattice, smoothstep between lattice points.
local function hash(seed: number, i: number): number
	local x = sin(i * 12.9898 + seed * 78.233) * 43758.5453
	return (x - math.floor(x)) * 2 - 1
end
function RacePose.Noise(seed: number?, t: number): number
	local s = finite(seed, 0)
	local u = finite(t, 0) * RacePose.NoiseHz
	local i = math.floor(u)
	local f = u - i
	f = f * f * (3 - 2 * f)
	local a, b = hash(s, i), hash(s, i + 1)
	return a + (b - a) * f
end

-- 0..1 -> 0..1 with a small overshoot past 1 (ease-out-back, c1 = 1.70158).
function RacePose.EaseOutBack(x: number): number
	local c1 = 1.70158
	local c3 = c1 + 1
	local u = math.clamp(finite(x, 0), 0, 1) - 1
	return 1 + c3 * u * u * u + c1 * u * u
end

----------------------------------------------------------------------
-- Poses
----------------------------------------------------------------------
-- The Flash crouch. g: the charge gauge 0..1; t: seconds; seed: the racer's own tremble.
function RacePose.Set(g: number, t: number, seed: number?, out: Pose?): Pose
	local pose = out or {}
	local gauge = math.clamp(finite(g, 0), 0, 1)
	local time = finite(t, 0)
	local p = rad(66 + 4 * gauge)
	local drop = 1.05 + 0.08 * gauge + 0.03 * sin(TAU * 1.4 * time)
	-- Steady inside the zone, trembling once it overfills (0.84 .. 1).
	local j = rad(0.3 + 2.5 * math.max(0, (gauge - 0.84) / 0.16))
	local s = finite(seed, 0)
	local jitter = CFrame.Angles(j * RacePose.Noise(s, time), 0, j * RacePose.Noise(s + 17.31, time))
	-- The tremble turns the torso about the hips and the legs turn back by as much, so the
	-- body shakes over feet that stay planted.
	pose.RootJoint = CFrame.new(0, -drop, 0) * CFrame.Angles(-p, 0, 0) * HIPS * jitter * HIPS_BACK
	local steady = jitter:Inverse()
	pose["Left Hip"] = steady * CFrame.Angles(p + rad(38), 0, -rad(4))
	pose["Right Hip"] = steady * CFrame.Angles(p - rad(42), 0, rad(4))
	pose["Right Shoulder"] = CFrame.Angles(p + rad(4), 0, rad(8))
	pose["Left Shoulder"] = CFrame.Angles(p + rad(4), 0, -rad(8))
	pose.Neck = CFrame.Angles(rad(52), 0, 0)
	return pose
end

local function runPose(phi: number, p: number, s: number, pose: Pose): Pose
	local legs = rad(34 + 10 * s)
	local arms = rad(40 + 15 * s)
	local swing = sin(phi)
	pose.RootJoint = CFrame.new(0, -(1 - cos(p)) - 0.18 * swing * swing, 0) * CFrame.Angles(-p, rad(6) * swing, 0)
	pose["Right Hip"] = CFrame.Angles(p + legs * swing, 0, 0)
	pose["Left Hip"] = CFrame.Angles(p - legs * swing, 0, 0)
	pose["Right Shoulder"] = CFrame.Angles(rad(10) - arms * swing, 0, rad(6))
	pose["Left Shoulder"] = CFrame.Angles(rad(10) + arms * swing, 0, -rad(6))
	pose.Neck = CFrame.Angles(0.7 * p, -rad(3) * swing, 0)
	return pose
end

-- The stride. phi: stride phase (radians); s: speed / RaceSprintSpeed; t: seconds (unused by
-- the stride itself, kept for the common signature).
function RacePose.Run(phi: number, s: number, t: number?, out: Pose?): Pose
	local speed = math.clamp(finite(s, 0), 0, 1)
	return runPose(finite(phi, 0), rad(10 + 10 * speed), speed, out or {})
end

-- The super-speed dash.
function RacePose.Super(phi: number, t: number, out: Pose?): Pose
	local pose = out or {}
	local ph = finite(phi, 0)
	local time = finite(t, 0)
	local swing = sin(ph)
	local p = rad(34 + 2 * sin(2 * ph))
	local legs = rad(38) * swing
	pose.RootJoint = CFrame.new(0, -(1 - cos(p)) - 0.28 * swing * swing, 0) * CFrame.Angles(-p, 0, rad(2) * swing)
	pose["Right Hip"] = CFrame.Angles(p + legs, 0, 0)
	pose["Left Hip"] = CFrame.Angles(p - legs, 0, 0)
	local back = rad(-42 + 4 * sin(9 * time))
	pose["Right Shoulder"] = CFrame.Angles(back, 0, rad(14))
	pose["Left Shoulder"] = CFrame.Angles(back, 0, -rad(14))
	pose.Neck = CFrame.Angles(rad(26), 0, 0)
	return pose
end

-- Strides per second: 1.6 standing .. 3.6 at sprint, capped per tier so a stride always
-- spans >= 9 frames at 24 FPS on Low.
function RacePose.StrideRate(s: number, tier: string?): number
	local cap = POSE.StrideCap[tier or "Low"] or POSE.StrideCap.Low
	return math.clamp(1.6 + 2.0 * math.clamp(finite(s, 0), 0, 1), 1.6, cap)
end

-- Per joint a:Lerp(b, w). Joints missing from one side count as identity.
function RacePose.Blend(a: Pose, b: Pose, w: number, out: Pose?): Pose
	local pose = out or {}
	local weight = math.clamp(finite(w, 0), 0, 1)
	for _, name in RacePose.Names do
		local from = a[name] or CFrame.identity
		local to = b[name] or CFrame.identity
		pose[name] = if weight <= 0 then from elseif weight >= 1 then to else from:Lerp(to, weight)
	end
	return pose
end

-- The pose at weight w over the rest pose (w = 0 is identity everywhere).
function RacePose.Weighted(pose: Pose, w: number, out: Pose?): Pose
	local result = out or {}
	local weight = math.clamp(finite(w, 0), 0, 1)
	for _, name in RacePose.Names do
		local target = pose[name] or CFrame.identity
		result[name] = if weight <= 0 then CFrame.identity elseif weight >= 1 then target else CFrame.identity:Lerp(target, weight)
	end
	return result
end

-- The launch: tau seconds after GO (0 .. Pose.Launch), Set crossfading into Run with an
-- ease-out-back. A Perfect start drives out low: its stride starts at PerfectDrive degrees of
-- lean and straightens as it goes, so the torso passes through 40 degrees.
local launchSet: Pose = {}
local launchRun: Pose = {}
function RacePose.Launch(tau: number, g: number, grade: string?, phi: number, s: number, t: number, seed: number?, out: Pose?): Pose
	local alpha = math.clamp(finite(tau, 0) / POSE.Launch, 0, 1)
	local e = RacePose.EaseOutBack(alpha)
	local speed = math.clamp(finite(s, 0), 0, 1)
	local lean = 10 + 10 * speed
	if grade == "Perfect" then
		lean = RacePose.PerfectDrive + (lean - RacePose.PerfectDrive) * alpha
	end
	lean += math.max(0, e - 1) * RacePose.BackOvershoot
	RacePose.Set(g, t, seed, launchSet)
	runPose(finite(phi, 0), rad(lean), speed, launchRun)
	return RacePose.Blend(launchSet, launchRun, math.min(1, e), out)
end

-- The torso's forward lean (degrees) of a RootJoint rotation: 0 upright, 90 flat.
function RacePose.Lean(rootJoint: CFrame): number
	local up = rootJoint.UpVector
	return math.deg(math.atan2(-up.Z, up.Y))
end

----------------------------------------------------------------------
-- Which pose, and when
----------------------------------------------------------------------
-- Set while staged before GO, Run once racing, or staged past GO on the server clock (the
-- phase and the state arrive a moment after the clock: every racer launches on GO), Done
-- otherwise.
-- 2026-09-25 review: Staged is Set whatever the phase. RaceService stages the racers first and
-- sets RacePhase = "Staging" after them, so a client can see Staged under the old
-- Gathering/Cooldown phase for a frame; Done there dropped the racer for the whole race (no
-- state change re-tracks them before Racing). The client starts the crouch from the phase.
function RacePose.Mode(active: any, state: any, phase: any, now: number, goAt: number?): string
	if active ~= true then
		return "Done"
	end
	if state == "Racing" then
		return "Run"
	end
	if state == "Staged" then
		local go = tonumber(goAt)
		if (phase == "Countdown" or phase == "Running") and go ~= nil and now >= go then
			return "Run"
		end
		return "Set"
	end
	return "Done"
end

-- Whether a Set racer crouches now: from SetLeadSeconds before GO, once the phase is this
-- race's (a stale RaceGoAt from the last race under Gathering never counts).
function RacePose.Crouching(mode: string, phase: any, now: number, goAt: number?, lead: number): boolean
	if mode ~= "Set" or (phase ~= "Staging" and phase ~= "Countdown") then
		return false
	end
	local go = tonumber(goAt)
	return go == nil or now >= go - lead
end

-- Hysteresis for super speed: on after `enter` seconds of raw true, off after `exit` seconds
-- of raw false. latch = { On, Since } (Since = when raw last differed from On).
export type Latch = { On: boolean, Since: number? }
function RacePose.NewLatch(): Latch
	return { On = false, Since = nil }
end
function RacePose.UpdateLatch(latch: Latch, raw: boolean, now: number, enter: number?, exit: number?): boolean
	if raw == latch.On then
		latch.Since = nil
		return latch.On
	end
	if latch.Since == nil then
		latch.Since = now
	end
	local hold = if raw then (enter or 0.35) else (exit or 0.25)
	if now - (latch.Since :: number) >= hold then
		latch.On = raw
		latch.Since = nil
	end
	return latch.On
end

-- How often a racer's pose is recomputed: math.huge = every frame, a number = that many Hz
-- (the last pose is re-applied in between), 0 = not posed (too far to see).
function RacePose.LodRate(tier: string?, distance: number, isLocal: boolean?): number
	if isLocal then
		return math.huge
	end
	local lod = POSE.Lod[tier or "Low"] or POSE.Lod.Low
	local d = finite(distance, math.huge)
	if d <= lod.Full then
		return math.huge
	elseif d <= lod.Reduced then
		return lod.ReducedHz
	end
	return 0
end

return RacePose
