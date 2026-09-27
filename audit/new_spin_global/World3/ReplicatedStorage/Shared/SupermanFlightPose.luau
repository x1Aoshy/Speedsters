-- SupermanFlightPose.luau
-- Superman's run (2026-09-18): while a player in the Superman skin runs, the body flies low
-- instead of running (Movement/SupermanFlight draws it on every client). R6 joints, as
-- rotations in each joint's parent part, about the joint (see SurfboardStance.Transform):
--   * the torso pitched forward to lie almost flat, floating at the root's height (about 3
--     studs over the floor), with a slight bob and roll;
--   * the head lifted to look ahead;
--   * the right arm straight out in front, fist first; the left arm back along the side;
--   * the legs together, stretched out behind.
-- The cape (the RedCape accessory) streams behind and flutters (CapeFlutter).
-- Only numbers and CFrames, so audit/test_new_skins can check the pose.
local SupermanFlightPose = {}

SupermanFlightPose.Pitch = 78 -- degrees the body leans forward, off upright
SupermanFlightPose.HeadLift = 62 -- the head tipped back to look where it flies
SupermanFlightPose.FistReach = 176 -- the right arm swung up past the head, out in front
SupermanFlightPose.Bob = 2 -- degrees of pitch, up and down
SupermanFlightPose.BobRate = 5 -- radians per second
SupermanFlightPose.MinSpeed = 8 -- studs/s: slower than this is standing, not flying
SupermanFlightPose.BlendSeconds = 0.18 -- into and out of the pose
SupermanFlightPose.CapeFlutter = 7 -- degrees
SupermanFlightPose.CapeRate = 14 -- radians per second

-- The rotations for time `t` (seconds), keyed by the R6 Motor6D names.
function SupermanFlightPose.Pose(t: number)
	local rad = math.rad
	local bob = rad(SupermanFlightPose.Bob) * math.sin(t * SupermanFlightPose.BobRate)
	local roll = rad(1.5) * math.sin(t * SupermanFlightPose.BobRate * 0.5)
	return {
		-- About the hip-to-hip axis: the top of the body goes forward and down.
		RootJoint = CFrame.Angles(-rad(SupermanFlightPose.Pitch) + bob, 0, roll),
		Neck = CFrame.Angles(rad(SupermanFlightPose.HeadLift) - bob, 0, 0),
		["Right Shoulder"] = CFrame.Angles(rad(SupermanFlightPose.FistReach), 0, -rad(6)),
		["Left Shoulder"] = CFrame.Angles(-rad(8), 0, -rad(6)),
		["Right Hip"] = CFrame.Angles(-rad(4) + bob, 0, 0),
		["Left Hip"] = CFrame.Angles(rad(3) - bob, 0, 0),
	}
end

-- How much of the pose shows (0 to 1), eased toward whether the body is flying.
function SupermanFlightPose.Blend(current: number, flying: boolean, dt: number): number
	local step = dt / SupermanFlightPose.BlendSeconds
	return math.clamp(current + (if flying then step else -step), 0, 1)
end

-- The cape's turn about where it hangs from, at time `t`.
function SupermanFlightPose.Cape(t: number): CFrame
	return CFrame.Angles(math.rad(SupermanFlightPose.CapeFlutter) * math.sin(t * SupermanFlightPose.CapeRate), 0, 0)
end

return SupermanFlightPose
