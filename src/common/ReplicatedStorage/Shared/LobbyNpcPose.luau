-- ReplicatedStorage/Shared/LobbyNpcPose.luau — Update 4 (2026-09-25): the lobby NPCs' procedural
-- idles, as R6 joint rotations in each joint's parent part (Motor6D.Transform =
-- C0.Rotation:Inverse() * rotation * C0.Rotation, SurfboardStance.Transform's rule), so the
-- same numbers drive Eggman's part rig and Flash's avatar rig.
--   Eggman  hands on hips, a slow breath, a look to one side, a proud chin-up with a chuckle;
--           reaction "Laugh": leans back, both fists up, shaking ("Ho ho ho!").
--   Flash   a sprinter between races: bouncing on his toes, a leg stretch behind, an overhead
--           side stretch each way, a look at his wristwatch (tapping it), shaking out, then the
--           gate host (2026-09-26): the hero stance and the lightning fist; reaction "Point":
--           points at the player who talked to him.
--   EggmanDriving (2026-09-26, owner: new animations for the Blender Egg Mobile)  Eggman on the
--           ship's bench (Shared/EggMobile): legs under the cockpit floor, fists on the levers,
--           steering and leaning with the hover, a look-around, turbo pushes, "come here" (points at
--           the nearest player and beckons), an evil laugh, a glance, a chuckle; reaction "Talk": turns
--           to the player, points, throws his arms open laughing. Sample's `aim` steers the gestures.
-- Axes (parent space, forward -Z): rx > 0 swings an arm or leg forward and tips a head or the
-- body back; ry > 0 turns left; rz > 0 moves a right limb out (a left limb in).
-- Sample() fills a reused table: no allocation per frame. Pure numbers: Lune tests it.
local LobbyNpcPose = {}

LobbyNpcPose.Joints = { "RootJoint", "Neck", "Left Shoulder", "Right Shoulder", "Left Hip", "Right Hip" }
local JOINTS = LobbyNpcPose.Joints

-- A pose: joint -> { px, py, pz, rx, ry, rz } (studs, degrees); missing joints are zero.
local function pose(values: { [string]: { number } }): { [string]: { number } }
	local out = {}
	for _, joint in JOINTS do
		local v = values[joint] or {}
		out[joint] = { v[1] or 0, v[2] or 0, v[3] or 0, v[4] or 0, v[5] or 0, v[6] or 0 }
	end
	return out
end

----------------------------------------------------------------------
-- Dr. Eggman
----------------------------------------------------------------------
local E_HIPS = pose({
	["Right Shoulder"] = { 0, 0, 0, -10, 0, 22 },
	["Left Shoulder"] = { 0, 0, 0, -10, 0, -22 },
	["Right Hip"] = { 0, 0, 0, 0, 0, 4 },
	["Left Hip"] = { 0, 0, 0, 0, 0, -4 },
})
local E_LOOK = pose({
	Neck = { 0, 0, 0, 0, 24, 0 },
	RootJoint = { 0, 0, 0, 0, 6, 0 },
	["Right Shoulder"] = { 0, 0, 0, -10, 0, 22 },
	["Left Shoulder"] = { 0, 0, 0, -10, 0, -22 },
	["Right Hip"] = { 0, 0, 0, 0, 0, 4 },
	["Left Hip"] = { 0, 0, 0, 0, 0, -4 },
})
local E_PROUD = pose({
	Neck = { 0, 0, 0, 10, -16, 0 },
	RootJoint = { 0, 0, 0, 4, -4, 0 },
	["Right Shoulder"] = { 0, 0, 0, -14, 0, 26 },
	["Left Shoulder"] = { 0, 0, 0, -14, 0, -26 },
	["Right Hip"] = { 0, 0, 0, 0, 0, 5 },
	["Left Hip"] = { 0, 0, 0, 0, 0, -5 },
})
local E_LAUGH = pose({
	RootJoint = { 0, 0, 0, 8, 0, 0 },
	Neck = { 0, 0, 0, 18, 0, 0 },
	["Right Shoulder"] = { 0, 0, 0, 135, 0, 24 },
	["Left Shoulder"] = { 0, 0, 0, 135, 0, -24 },
	["Right Hip"] = { 0, 0, 0, 0, 0, 5 },
	["Left Hip"] = { 0, 0, 0, 0, 0, -5 },
})

----------------------------------------------------------------------
-- The Flash
----------------------------------------------------------------------
local F_STAND = pose({
	RootJoint = { 0, 0, 0, -3, 0, 0 },
	["Right Shoulder"] = { 0, 0, 0, 0, 0, 6 },
	["Left Shoulder"] = { 0, 0, 0, 0, 0, -6 },
	["Right Hip"] = { 0, 0, 0, 0, 0, 3 },
	["Left Hip"] = { 0, 0, 0, 0, 0, -3 },
})
local F_STRETCH = pose({
	RootJoint = { 0, 0, 0, -10, 0, 0 },
	Neck = { 0, 0, 0, 6, 0, 0 },
	["Right Shoulder"] = { 0, 0, 0, -50, 0, 12 },
	["Left Shoulder"] = { 0, 0, 0, 18, 0, -58 },
	["Right Hip"] = { 0, 0, 0, -68, 0, 2 },
	["Left Hip"] = { 0, 0, 0, 6, 0, -2 },
})
-- 2026-09-25: an overhead side stretch, not a forward lunge: on the race booth's kiosk a lunge
-- put his hands and front foot into the counter (audit/test_u4_npcs, booth check).
local F_SIDE_RIGHT = pose({
	RootJoint = { 0, 0, 0, -2, 0, -10 },
	Neck = { 0, 0, 0, 0, 0, -6 },
	["Left Shoulder"] = { 0, 0, 0, 0, 0, -170 },
	["Right Shoulder"] = { 0, 0, 0, -5, 0, 25 },
	["Right Hip"] = { 0, 0, 0, 0, 0, 7 },
	["Left Hip"] = { 0, 0, 0, 0, 0, -7 },
})
local F_SIDE_LEFT = pose({
	RootJoint = { 0, 0, 0, -2, 0, 10 },
	Neck = { 0, 0, 0, 0, 0, 6 },
	["Right Shoulder"] = { 0, 0, 0, 0, 0, 170 },
	["Left Shoulder"] = { 0, 0, 0, -5, 0, -25 },
	["Right Hip"] = { 0, 0, 0, 0, 0, 7 },
	["Left Hip"] = { 0, 0, 0, 0, 0, -7 },
})
local F_WATCH = pose({
	RootJoint = { 0, 0, 0, -2, 4, 0 },
	Neck = { 0, 0, 0, -22, 22, 0 },
	["Left Shoulder"] = { 0, 0, 0, 85, 0, 28 },
	["Right Shoulder"] = { 0, 0, 0, 50, 0, -30 },
	["Right Hip"] = { 0, 0, 0, 0, 0, 3 },
	["Left Hip"] = { 0, 0, 0, 0, 0, -3 },
})
local F_POINT = pose({
	RootJoint = { 0, 0, 0, -4, 0, 0 },
	Neck = { 0, 0, 0, -4, 0, 0 },
	["Right Shoulder"] = { 0, 0, 0, 92, 0, -6 },
	["Left Shoulder"] = { 0, 0, 0, 0, 0, -10 },
	["Right Hip"] = { 0, 0, 0, 0, 0, 3 },
	["Left Hip"] = { 0, 0, 0, 0, 0, -3 },
})
-- 2026-09-26 (owner: Flash hosts the race gate): the hero stance (fists on his hips, chest out,
-- chin up, feet apart) and the lightning fist (the right fist thrown to the sky, the left on his
-- hip). Gameplay/FlashGateClient bursts his crackles while the fist is up (FlashFist below).
local F_HERO = pose({
	RootJoint = { 0, 0, 0, 3, 0, 0 },
	Neck = { 0, 0, 0, 8, 0, 0 },
	["Right Shoulder"] = { 0, 0, 0, -14, 0, 21 },
	["Left Shoulder"] = { 0, 0, 0, -14, 0, -21 },
	["Right Hip"] = { 0, 0, 0, 0, 0, 5 },
	["Left Hip"] = { 0, 0, 0, 0, 0, -5 },
})
local F_FIST = pose({
	RootJoint = { 0, 0, 0, 4, 0, 0 },
	Neck = { 0, 0, 0, 12, 0, 0 },
	["Right Shoulder"] = { 0, 0, 0, 165, 0, 10 },
	["Left Shoulder"] = { 0, 0, 0, -14, 0, -21 },
	["Right Hip"] = { 0, 0, 0, 0, 0, 5 },
	["Left Hip"] = { 0, 0, 0, 0, 0, -5 },
})
-- The seconds of Flash's loop while the lightning fist is up.
LobbyNpcPose.FlashFist = { 22.2, 23.3 }

----------------------------------------------------------------------
-- Dr. Eggman at the controls of his Egg Mobile. 2026-09-26 (owner): the Blender ship (Shared/EggMobile)
-- and new animations for it: Eggman sits on the blue bench, legs bent forward under the cockpit floor,
-- fists on the two red levers (the levers follow the fists: Gameplay/EggMobileClient). The client plays
-- this def instead of "Eggman" when his model carries the ship. Everything here is a pure function of the
-- server clock (frame-rate independent, the same moment for everyone); the leans follow the ship's own
-- hover (HoverPeriods / HoverPhases = Shared/EggMobile.Hover, the test keeps them equal).
-- The loop (Loop seconds; DrivingWindows below): driving with steering and leans, a look-around (left then
-- right), a turbo push on the levers, the "come here": his right hand leaves its lever, points at the
-- nearest player (the aim Gameplay/LobbyNpcsClient passes: yaw / pitch in his root's axes) and beckons, an
-- evil laugh (both fists up and shaking, head back, belly bouncing), a glance at the player, a second turbo,
-- a chuckle. Reaction "Talk" (a player used his prompt): he turns to that player, points at them, then
-- throws both arms open with a laugh. His legs never move: every lean of the torso is taken back at the
-- hips (settleLegs), so they stay under the cockpit floor.
----------------------------------------------------------------------
local D_DRIVE = pose({
	RootJoint = { 0, 0, 0, -4, 0, 0 },
	Neck = { 0, 0, 0, 5, 0, 0 },
	["Right Shoulder"] = { 0, 0, 0, 74, 0, 8 },
	["Left Shoulder"] = { 0, 0, 0, 74, 0, -8 },
	["Right Hip"] = { 0, 0, 0, 80, 0, 2 },
	["Left Hip"] = { 0, 0, 0, 80, 0, -2 },
})
local DRIVE_ROOT_RX, DRIVE_HIP_RX = -4, 80

local function bump(t: number, from: number, to: number): number
	-- 0 outside [from, to], rising and falling smoothly inside it.
	if t <= from or t >= to then
		return 0
	end
	return math.sin(math.pi * (t - from) / (to - from))
end

local TAU = math.pi * 2

-- Smootherstep (zero speed and acceleration at both ends).
local function ease(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * x * (x * (x * 6 - 15) + 10)
end

-- 0 outside [w[1], w[2]], eased in over w[3] seconds and out over w[4].
local function window(t: number, w: { number }): number
	local a, b, fin, fout = w[1], w[2], w[3], w[4]
	if t <= a or t >= b then
		return 0
	elseif t < a + fin then
		return ease((t - a) / fin)
	elseif t > b - fout then
		return ease((b - t) / fout)
	end
	return 1
end

local function blendJoint(o: { number }, target: { number }, w: number)
	for i = 1, 6 do
		o[i] += (target[i] - o[i]) * w
	end
end

-- The shoulder angles (degrees: rx forward, rz toward his right) that point an R6 arm along `yaw`
-- (degrees, his left positive) and `pitch` (degrees, up positive): Angles(rx, 0, rz) turns the hanging
-- arm (0, -1, 0) into (sin rz, -cos rz cos rx, -cos rz sin rx).
local function aimArm(pitch: number, yaw: number): (number, number)
	local p, y = math.rad(pitch), math.rad(yaw)
	local dx, dy, dz = -math.sin(y) * math.cos(p), math.sin(p), -math.cos(y) * math.cos(p)
	local rz = math.deg(math.asin(math.clamp(dx, -1, 1)))
	local rx = math.deg(math.atan2(-dz, -dy))
	return rx, rz
end
LobbyNpcPose.AimArm = aimArm

-- His legs stay under the cockpit floor whatever the torso does: the root's pitch is taken back at the
-- hips, and a roll (which lifts one hip) lowers the body by as much. (A yaw only swings the bent legs
-- sideways, level; taking it back at the hips would roll the thighs instead: Angles turns Y before X.)
local function settleLegs(out: any)
	local root = out.RootJoint
	local pitch = root[4] - DRIVE_ROOT_RX
	for _, name in { "Right Hip", "Left Hip" } do
		local hip = out[name]
		hip[4] = DRIVE_HIP_RX - pitch
		hip[5] = 0
	end
	out["Right Hip"][6] = 2
	out["Left Hip"][6] = -2
	root[2] -= math.abs(math.sin(math.rad(root[6]))) * 1.05
	root[1], root[3] = 0, 0
end

-- The driving loop's windows (loop seconds: start, end, ease in, ease out).
local DRIVE = {
	LookLeft = { 5.0, 6.8, 0.55, 0.5 },
	LookRight = { 6.4, 8.3, 0.5, 0.6 },
	Turbo1 = { 8.8, 10.9, 0.5, 0.75 },
	Point = { 11.0, 15.4, 0.55, 0.65 }, -- the right hand off its lever, the whole window
	Beckon = { 12.5, 14.8, 0.35, 0.45 },
	Laugh = { 20.0, 23.8, 0.5, 0.6 }, -- both hands off their levers
	Glance = { 25.0, 26.9, 0.5, 0.55 },
	Turbo2 = { 28.6, 30.7, 0.5, 0.75 },
	Chuckle = { 32.0, 33.9, 0.4, 0.5 },
}
LobbyNpcPose.DrivingWindows = DRIVE
local DEFAULT_AIM = { yaw = -20, pitch = 5 } -- no player near: he points ahead, a little to his right

local function aimOf(aim: any): (number, number)
	local a = aim or DEFAULT_AIM
	return math.clamp(a.yaw or 0, -70, 70), math.clamp(a.pitch or 0, -15, 35)
end

-- The point / beckon of `arm` (his right) at the aim, weight `w`, `beckon` (0..1) swinging it up and down.
local function pointAt(out: any, w: number, beckon: number, t: number, yaw: number, pitch: number)
	local turn = 0.06 * yaw -- the head does the turning: the torso would carry the other hand off its lever
	out.RootJoint[5] += turn * w
	out.Neck[5] += (yaw - turn) * 0.9 * w
	out.Neck[4] += 0.35 * pitch * w
	-- The hand stays high (at least 26 degrees over level): it clears its lever, which lets go.
	local up = math.max(pitch, 0) * 0.5 + 26 + beckon * (14 + 12 * math.sin(TAU * 1.4 * t))
	local rx, rz = aimArm(up, yaw - turn)
	blendJoint(out["Right Shoulder"], { 0, 0, 0, rx, 0, rz }, w)
end

-- Both fists up and shaking, head back, the belly bouncing (the body only ever goes down).
local function evilLaugh(out: any, w: number, t: number)
	local shake = math.sin(TAU * 5 * t)
	out.RootJoint[4] += 3 * w
	out.RootJoint[2] -= 0.05 * w * math.abs(math.sin(TAU * 4.5 * t))
	out.RootJoint[6] += 1.2 * w * shake
	out.Neck[4] += (15 + 3 * math.sin(TAU * 4.5 * t)) * w
	blendJoint(out["Right Shoulder"], { 0, 0, 0, 150 + 6 * shake, 0, 26 + 5 * shake }, w)
	blendJoint(out["Left Shoulder"], { 0, 0, 0, 150 - 6 * shake, 0, -26 + 5 * shake }, w)
end

LobbyNpcPose.Defs = {
	Eggman = {
		Loop = 12,
		Keys = {
			{ 0, E_HIPS }, { 3, E_HIPS }, { 3.6, E_LOOK }, { 5.2, E_LOOK }, { 5.8, E_HIPS }, { 7.8, E_HIPS },
			{ 8.4, E_PROUD }, { 10.2, E_PROUD }, { 10.8, E_HIPS }, { 12, E_HIPS },
		},
		Additive = function(out: any, t: number, loopT: number)
			local breath = math.sin(TAU * 0.33 * t)
			out.RootJoint[2] += 0.045 * breath
			out.RootJoint[4] += 0.8 * breath
			out.Neck[4] -= 0.8 * breath
			out["Right Shoulder"][6] += 1.5 * breath
			out["Left Shoulder"][6] -= 1.5 * breath
			-- The chuckle while he looks proud.
			local chuckle = bump(loopT, 8.6, 10.0)
			if chuckle > 0 then
				local shake = math.abs(math.sin(TAU * 4 * t))
				out.RootJoint[2] += 0.05 * chuckle * shake
				out["Right Shoulder"][6] += 3 * chuckle * shake
				out["Left Shoulder"][6] -= 3 * chuckle * shake
			end
		end,
		Reactions = {
			Laugh = {
				Duration = 1.9, In = 0.2, Out = 0.35, Pose = E_LAUGH,
				Additive = function(out: any, age: number, weight: number)
					local shake = math.sin(TAU * 7 * age)
					out.RootJoint[2] += 0.1 * weight * math.abs(math.sin(TAU * 4.5 * age))
					out.Neck[4] += 4 * weight * math.sin(TAU * 4.5 * age)
					out["Right Shoulder"][6] += 7 * weight * shake
					out["Left Shoulder"][6] -= 7 * weight * shake
				end,
			},
		},
	},
	Flash = {
		Loop = 25,
		Keys = {
			{ 0, F_STAND }, { 2.5, F_STAND }, { 3.2, F_STRETCH }, { 5.6, F_STRETCH }, { 6.3, F_STAND },
			{ 7.0, F_STAND }, { 7.7, F_SIDE_RIGHT }, { 8.8, F_SIDE_RIGHT }, { 9.5, F_SIDE_LEFT }, { 10.6, F_SIDE_LEFT },
			{ 11.2, F_STAND }, { 11.6, F_STAND },
			{ 12.2, F_WATCH }, { 15.0, F_WATCH }, { 15.7, F_STAND }, { 18, F_STAND },
			-- 2026-09-26: the gate host: the hero stance, then the lightning fist.
			{ 18.6, F_HERO }, { 21.6, F_HERO }, { 22.1, F_FIST }, { 23.3, F_FIST }, { 23.9, F_STAND }, { 25, F_STAND },
		},
		Additive = function(out: any, t: number, loopT: number)
			out.RootJoint[2] += 0.02 * math.sin(TAU * 0.4 * t)
			-- On his toes before the stretch and after the watch; reaching a little further in the
			-- side stretch.
			local bounce = bump(loopT, 0, 2.5) + bump(loopT, 15.8, 18)
			if bounce > 0 then
				out.RootJoint[2] += 0.06 * bounce * math.abs(math.sin(TAU * 2 * t))
				out["Right Shoulder"][6] += 5 * bounce * math.sin(TAU * 4 * t)
				out["Left Shoulder"][6] -= 5 * bounce * math.sin(TAU * 4 * t)
			end
			local reach = bump(loopT, 7.8, 10.6)
			if reach > 0 then
				out.RootJoint[6] += 3 * reach * math.sin(TAU * 1.2 * t)
			end
			-- Tapping the watch.
			local tap = bump(loopT, 12.6, 14.6)
			if tap > 0 then
				out["Right Shoulder"][4] += 6 * tap * math.sin(TAU * 3 * t)
			end
			-- 2026-09-26: a proud nod in the hero stance; the fist shakes with the charge.
			local proud = bump(loopT, 18.8, 21.4)
			if proud > 0 then
				out.Neck[4] += 3 * proud * math.sin(TAU * 0.9 * t)
			end
			local fist = bump(loopT, 22.2, 23.3)
			if fist > 0 then
				out["Right Shoulder"][6] += 3 * fist * math.sin(TAU * 6 * t)
			end
		end,
		Reactions = {
			Point = {
				Duration = 1.5, In = 0.18, Out = 0.3, Pose = F_POINT,
				Additive = function(out: any, age: number, weight: number)
					out.Neck[4] += 5 * weight * math.sin(TAU * 2 * age) -- a nod
				end,
			},
		},
	},
	-- 2026-09-26 (owner): Eggman in his Blender Egg Mobile (see D_DRIVE above for the loop).
	EggmanDriving = {
		Loop = 36,
		-- Shared/EggMobile.Hover's periods and phase (the test keeps them equal).
		HoverPeriods = { Bob = 2.6, Roll = 4.1, Pitch = 3.4 },
		HoverPhases = { Pitch = 0.7 },
		Aims = true, -- Gameplay/LobbyNpcsClient passes the nearest player's direction (Sample's `aim`)
		AimRadius = 60,
		TalkReaction = "Talk",
		-- Loop seconds when a hand is off its lever (the whole window, easing included).
		HandsFree = { Right = { DRIVE.Point, DRIVE.Laugh }, Left = { DRIVE.Laugh } },
		Keys = { { 0, D_DRIVE }, { 36, D_DRIVE } },
		Additive = function(out: any, t: number, loopT: number, aim: any?)
			local yaw, pitch = aimOf(aim)
			-- Leaning into the hover: he rides the ship's pitch and bob and sways against its roll, his head
			-- staying level (the ship's own phases: HoverPeriods / HoverPhases).
			local roll = 2.0 * math.sin(TAU * t / 4.1)
			local shipPitch = 1.4 * math.sin(TAU * t / 3.4 + 0.7)
			local bob = math.cos(TAU * t / 2.6)
			out.RootJoint[4] += 0.9 * bob - 0.5 * shipPitch
			out.RootJoint[6] -= 0.6 * roll
			out.Neck[6] += 0.5 * roll
			out.Neck[4] -= 0.8 * math.sin(TAU * 0.33 * t)
			-- The windows.
			local wPoint = window(loopT, DRIVE.Point)
			local wLaugh = window(loopT, DRIVE.Laugh)
			local rightFree = math.max(wPoint, wLaugh)
			-- Steering: small and out of phase on the two levers, a flourish now and then.
			local flourish = 1 + 1.4 * bump(loopT, 16.5, 19.5)
			out["Right Shoulder"][4] += 3.5 * flourish * (1 - rightFree) * math.sin(TAU * 0.8 * t)
			out["Right Shoulder"][6] += 2.5 * (1 - rightFree) * math.sin(TAU * 0.53 * t + 1.1)
			out["Left Shoulder"][4] += 3.5 * flourish * (1 - wLaugh) * math.sin(TAU * 0.8 * t + 2.2)
			out["Left Shoulder"][6] -= 2.5 * (1 - wLaugh) * math.sin(TAU * 0.61 * t + 0.3)
			-- Look around: left, then right (the torso follows a little).
			local look = 38 * window(loopT, DRIVE.LookLeft) - 34 * window(loopT, DRIVE.LookRight)
			out.Neck[5] += 0.94 * look
			out.RootJoint[5] += 0.06 * look
			out.Neck[4] -= 0.08 * math.abs(look)
			-- Turbo: both levers pushed forward, leaning in, chin down.
			local turbo = window(loopT, DRIVE.Turbo1) + window(loopT, DRIVE.Turbo2)
			if turbo > 0 then
				local buzz = math.sin(TAU * 7 * t)
				out.RootJoint[4] -= (4 + 0.6 * buzz) * turbo
				out.Neck[4] -= 3 * turbo
				out["Right Shoulder"][4] += 9 * turbo
				out["Left Shoulder"][4] += 9 * turbo
			end
			-- "Come here!": the right hand points at the player, then beckons.
			if wPoint > 0 then
				pointAt(out, wPoint, window(loopT, DRIVE.Beckon), t, yaw, pitch)
			end
			-- The evil laugh.
			if wLaugh > 0 then
				evilLaugh(out, wLaugh, t)
			end
			-- A glance at the player (or over his right shoulder), and a chuckle with his hands on the levers.
			local glance = window(loopT, DRIVE.Glance)
			if glance > 0 then
				out.Neck[5] += 0.8 * yaw * glance
				out.Neck[4] += 0.3 * pitch * glance
			end
			local chuckle = bump(loopT, DRIVE.Chuckle[1], DRIVE.Chuckle[2])
			if chuckle > 0 then
				out.RootJoint[6] += 0.8 * chuckle * math.sin(TAU * 4 * t)
				out.Neck[4] += 3 * chuckle * math.sin(TAU * 4 * t)
			end
			settleLegs(out)
		end,
		Reactions = {
			-- A player used his prompt: he turns to them, points ("You!"), then throws his arms open laughing.
			Talk = {
				Duration = 2.9, In = 0.3, Out = 0.5, Pose = D_DRIVE, Hands = { Right = { 0, 2.9, 0.3, 0.5 }, Left = { 1.0, 2.9, 0.35, 0.5 } },
				Additive = function(out: any, age: number, weight: number, aim: any?)
					local yaw, pitch = aimOf(aim)
					local pointing = window(age, { 0, 1.35, 0.3, 0.35 })
					local open = window(age, { 1.0, 2.9, 0.35, 0.5 })
					if pointing > 0 then
						pointAt(out, pointing * weight, 0, age, yaw, pitch)
					end
					if open > 0 then
						local w = open * weight
						local shake = math.sin(TAU * 4.5 * age)
						out.RootJoint[5] += 0.12 * yaw * w
						out.Neck[5] += 0.75 * yaw * w
						out.Neck[4] += (10 + 3 * shake) * w
						out.RootJoint[4] += 2 * w
						blendJoint(out["Right Shoulder"], { 0, 0, 0, 122 + 5 * shake, 0, 48 }, w)
						blendJoint(out["Left Shoulder"], { 0, 0, 0, 122 - 5 * shake, 0, -48 }, w)
					end
					-- The left hand leaves its lever as the arms open (and comes back after).
					settleLegs(out)
				end,
			},
			-- The evil laugh on its own (Gameplay/LobbyNpcsClient plays Talk; kept for other callers).
			Laugh = {
				Duration = 2.2, In = 0.3, Out = 0.45, Pose = D_DRIVE, Hands = { Right = { 0, 2.2, 0.3, 0.45 }, Left = { 0, 2.2, 0.3, 0.45 } },
				Additive = function(out: any, age: number, weight: number)
					evilLaugh(out, weight, age)
					settleLegs(out)
				end,
			},
		},
	},
}

local function smooth(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

-- The reaction's weight `age` seconds in (0 before and after it).
function LobbyNpcPose.ReactionWeight(reaction: any, age: number?): number
	if reaction == nil or age == nil or age < 0 or age >= reaction.Duration then
		return 0
	end
	local w = 1
	if age < reaction.In then
		w = smooth(age / reaction.In)
	elseif age > reaction.Duration - reaction.Out then
		w = smooth((reaction.Duration - age) / reaction.Out)
	end
	return w
end

-- A table to Sample into (one per NPC).
function LobbyNpcPose.NewOut(): { [string]: { number } }
	return pose({})
end

-- Fills `out` with `kind`'s pose at time `t` (seconds), blended toward reaction `reactionName`
-- `reactionAge` seconds after it began (nil: none). `aim` (defs with Aims, 2026-09-26): { yaw, pitch } in
-- degrees, the player to look / point at in the NPC root's axes (yaw: his left positive); nil: ahead.
-- Returns `out`.
function LobbyNpcPose.Sample(kind: string, t: number, out: any, reactionName: string?, reactionAge: number?, aim: any?): any
	local def = LobbyNpcPose.Defs[kind]
	local keys = def.Keys
	local loopT = t % def.Loop
	local index = 1
	for i = 1, #keys - 1 do
		if loopT >= keys[i][1] then
			index = i
		end
	end
	local a, b = keys[index], keys[math.min(index + 1, #keys)]
	local span = b[1] - a[1]
	local alpha = if span > 0 then smooth((loopT - a[1]) / span) else 0
	for _, joint in JOINTS do
		local va, vb, o = a[2][joint], b[2][joint], out[joint]
		for i = 1, 6 do
			o[i] = va[i] + (vb[i] - va[i]) * alpha
		end
	end
	def.Additive(out, t, loopT, aim)
	local reaction = reactionName and def.Reactions[reactionName] or nil
	local weight = LobbyNpcPose.ReactionWeight(reaction, reactionAge)
	if weight > 0 then
		local target = reaction.Pose
		for _, joint in JOINTS do
			local vr, o = target[joint], out[joint]
			for i = 1, 6 do
				o[i] += (vr[i] - o[i]) * weight
			end
		end
		reaction.Additive(out, reactionAge :: number, weight, aim)
	end
	return out
end

-- 2026-09-26 (owner): the hands a def's loop or reaction takes off the Egg Mobile's levers at `loopT`
-- (reaction `reactionName` `reactionAge` seconds in): (right free, left free) as 0..1 weights.
function LobbyNpcPose.HandsFree(kind: string, loopT: number, reactionName: string?, reactionAge: number?): (number, number)
	local def = LobbyNpcPose.Defs[kind]
	local right, left = 0, 0
	if def and def.HandsFree then
		for _, w in def.HandsFree.Right do
			right = math.max(right, window(loopT, w))
		end
		for _, w in def.HandsFree.Left do
			left = math.max(left, window(loopT, w))
		end
	end
	local reaction = def and reactionName and def.Reactions[reactionName] or nil
	local weight = LobbyNpcPose.ReactionWeight(reaction, reactionAge)
	if weight > 0 then
		-- The reaction blends the loop out (its gestures with it); Hands: per hand, the reaction-age window
		-- it is off its lever.
		right, left = right * (1 - weight), left * (1 - weight)
		local hands = reaction.Hands or {}
		if hands.Right then
			right = math.max(right, math.min(weight, window(reactionAge :: number, hands.Right)))
		end
		if hands.Left then
			left = math.max(left, math.min(weight, window(reactionAge :: number, hands.Left)))
		end
	end
	return right, left
end

-- One joint's { px, py, pz, rx, ry, rz } as a CFrame (CFrame.Angles order), with `C` the CFrame
-- constructor table.
function LobbyNpcPose.ToCFrame(v: { number }, C: any): any
	return C.new(v[1], v[2], v[3]) * C.Angles(math.rad(v[4]), math.rad(v[5]), math.rad(v[6]))
end

return LobbyNpcPose
