--!strict
-- TreeSlamMotion.luau
-- The shape of the World 2 tree slam, as a pure function of time.
--
-- The slam used to be a TweenService tween on the server that rewrote every tree
-- part's CFrame. Anything the server writes replicates at roughly 20 Hz, and the
-- slam lasts 0.16 s - about three packets for the whole strike, which is why it
-- read as a teleport rather than a hit.
--
-- The motion is deterministic, so both sides can compute it instead: the server
-- publishes the constants once, and every client renders it locally at its own
-- frame rate from Workspace:GetServerTimeNow(). Same pose on every machine, no
-- per-frame replication, and the player is hit by exactly what they can see.

local TreeSlamMotion = {}

-- Preserved exactly from the original server tween.
TreeSlamMotion.SlamAngleDegrees = 88
TreeSlamMotion.DownTime = 0.16
TreeSlamMotion.DownHold = 0.70
TreeSlamMotion.UpTime = 1.05
TreeSlamMotion.UprightHold = 0.70
TreeSlamMotion.InitialStagger = 0.29

-- Attribute names, so the server and the client cannot drift apart on spelling.
TreeSlamMotion.StartAttribute = "World2TreeSlamStartTime"
TreeSlamMotion.IndexAttribute = "World2TreeSlamIndex"
TreeSlamMotion.BaseAttribute = "World2TreeSlamBaseCFrame"
TreeSlamMotion.AxisAttribute = "World2TreeSlamAxis"
TreeSlamMotion.RelativeAttribute = "World2TreeSlamRelativeCFrame"

-- TweenService easing, reproduced so the timing feels identical.
local function quintIn(t: number): number
	return t * t * t * t * t
end

local function sineOut(t: number): number
	return math.sin(t * math.pi * 0.5)
end

-- The per-tree jitter the original loop added with its modulo waits.
function TreeSlamMotion.CycleFor(index: number): (number, number, number, number)
	local zeroBased = math.max(0, math.floor(index) - 1)
	local uprightHold = TreeSlamMotion.UprightHold + (zeroBased % 3) * 0.06
	local downHold = TreeSlamMotion.DownHold + (zeroBased % 2) * 0.08
	local period = uprightHold + TreeSlamMotion.DownTime + downHold + TreeSlamMotion.UpTime
	local stagger = zeroBased * TreeSlamMotion.InitialStagger
	return uprightHold, downHold, period, stagger
end

-- Slam angle in radians for this tree at `elapsed` seconds since the shared start.
function TreeSlamMotion.AngleAt(index: number, elapsed: number): number
	local slam = math.rad(TreeSlamMotion.SlamAngleDegrees)
	local uprightHold, downHold, period, stagger = TreeSlamMotion.CycleFor(index)

	local t = (tonumber(elapsed) or 0) - stagger
	if t ~= t or math.abs(t) == math.huge then
		return 0
	end
	if t < 0 then
		return 0
	end
	t %= period

	if t < uprightHold then
		return 0
	end
	t -= uprightHold

	if t < TreeSlamMotion.DownTime then
		return slam * quintIn(t / TreeSlamMotion.DownTime)
	end
	t -= TreeSlamMotion.DownTime

	if t < downHold then
		return slam
	end
	t -= downHold

	return slam * (1 - sineOut(math.min(1, t / TreeSlamMotion.UpTime)))
end

-- Where a part sits for a given angle. `relative` is the part's rest pose in the
-- tree's base space, which is what the server publishes.
function TreeSlamMotion.PoseFor(baseCFrame: CFrame, axis: Vector3, angle: number, relative: CFrame): CFrame
	return baseCFrame * CFrame.fromAxisAngle(axis, angle) * relative
end

return TreeSlamMotion
