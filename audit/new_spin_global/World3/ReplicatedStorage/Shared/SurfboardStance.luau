-- SurfboardStance.luau
-- The Silver Surfer's stance on its board (Movement/SurfboardPose draws it; SkinSystem welds
-- the board under the feet). R6 joints, as rotations in each joint's parent part, about the
-- joint:
--   * the torso turned side-on to the board (Yaw, regular stance: left foot forward), leaning
--     out over its toe side a little more the faster it goes, with a slow weight-shifting
--     sway (both about the board's own axis, so the hips stay level and both feet on it);
--   * the head turned back toward where the board goes;
--   * arms out for balance, feet apart along the board, the legs upright under the lean.
-- Only numbers and CFrames, so audit/test_new_skins can check where the feet land.
local SurfboardStance = {}

SurfboardStance.Yaw = -90 -- degrees: the torso's front turned to the right of the board
SurfboardStance.HeadTurn = 80 -- the head back toward the nose of the board
SurfboardStance.ArmRaise = 55 -- arms out to the sides
SurfboardStance.LegSpread = 14 -- each leg out from the hip, along the board
SurfboardStance.Lean = 6 -- over the toes, standing still...
SurfboardStance.SpeedLean = 8 -- ...plus this much at full speed
SurfboardStance.FullSpeed = 400 -- studs/s
SurfboardStance.Sway = 3 -- the weight shift, side to side
SurfboardStance.SwayRate = 2.2 -- radians per second

-- The rotations for time `t` (seconds) at `speed` (studs/s, horizontal), keyed by the R6
-- Motor6D names.
function SurfboardStance.Pose(t: number, speed: number?)
	local rad = math.rad
	local ride = math.clamp((tonumber(speed) or 0) / SurfboardStance.FullSpeed, 0, 1)
	local lean = rad(SurfboardStance.Lean + SurfboardStance.SpeedLean * ride)
	local sway = rad(SurfboardStance.Sway) * math.sin(t * SurfboardStance.SwayRate)
	local balance = rad(4) * math.sin(t * SurfboardStance.SwayRate * 2)
	local arms = rad(SurfboardStance.ArmRaise)
	local legs = rad(SurfboardStance.LegSpread)
	local yaw = CFrame.Angles(0, rad(SurfboardStance.Yaw), 0)
	local tilt = CFrame.Angles(0, 0, sway - lean)
	-- The hips undo the torso's lean and sway (seen from the torso), so the legs stay
	-- upright and both feet stay on the board however far the body leans.
	local upright = yaw:Inverse() * tilt:Inverse() * yaw
	return {
		RootJoint = tilt * yaw,
		Neck = CFrame.Angles(0, rad(SurfboardStance.HeadTurn), 0) * CFrame.Angles(-lean * 0.5, 0, 0),
		["Right Shoulder"] = CFrame.Angles(rad(12) + balance, 0, arms + balance),
		["Left Shoulder"] = CFrame.Angles(-rad(12) - balance, 0, -arms + balance),
		["Right Hip"] = upright * CFrame.Angles(0, 0, legs),
		["Left Hip"] = upright * CFrame.Angles(0, 0, -legs),
	}
end

-- The Motor6D.Transform that turns a joint (whose C0 is `c0`) by `rotation`, given in the
-- joint's parent part: Part1 = Part0 * C0 * Transform * C1:Inverse().
function SurfboardStance.Transform(c0: CFrame, rotation: CFrame): CFrame
	local basis = c0.Rotation
	return basis:Inverse() * rotation * basis
end

return SurfboardStance
