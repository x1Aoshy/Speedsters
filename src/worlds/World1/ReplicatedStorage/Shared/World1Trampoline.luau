-- World1Trampoline: the trampoline at the top of Stage 9's climb.
--
-- It used to be a conveyor (pad.Velocity = (0, 277777, 0)): whoever stepped on it left at
-- 277,777 studs a second, which is a teleport far above Stage 10 and over the side barriers,
-- not a bounce. Now it is a trampoline: it throws a runner just high enough to come over the
-- ledge of Stage 10 (Clearance studs over it, well under the top of the barriers), from the
-- height the server measures on the map itself.
--
-- A character's physics belong to its own client, so each client bounces its own character
-- (Gameplay/NewWorld1Trampoline.client); the server only measures and publishes the rise
-- (the Script inside the trampoline model). This module is the maths both share, tested
-- offline by audit/test_fable_trampoline.
local Trampoline = {}

Trampoline.Tag = "NewWorld1Trampoline" -- on the trampoline model
Trampoline.RiseAttribute = "TrampolineRise" -- studs the feet must gain, clearance included
-- While os.clock() is under this character attribute the lift is meant: the run controller
-- does not flatten it against the shaft's wall and the anti-fling does not undo it
-- (Movement/InstantMovementController, Movement/WallImpactAntiFling).
Trampoline.LaunchAttribute = "VortexLaunchUntil"
Trampoline.Clearance = 20 -- studs over the ledge at the top of the bounce
Trampoline.FallbackRise = 440 -- the authored map: 419.4 to the ledge, plus the clearance
Trampoline.Cooldown = 0.35 -- seconds between two bounces of the same character
Trampoline.ContactSlack = 1.5 -- feet this close over the mat count as on it
Trampoline.NearStuds = 60 -- no ray is cast for a character further than this from the mat
Trampoline.HoldSeconds = 0.2 -- the launch is kept against a jump pressed on the same frame
Trampoline.HoldTolerance = 25

-- The height of the top face of a box, however it is turned.
function Trampoline.TopOf(cframe, size)
	return cframe.Position.Y
		+ (math.abs(cframe.RightVector.Y) * size.X + math.abs(cframe.UpVector.Y) * size.Y + math.abs(cframe.LookVector.Y) * size.Z) * 0.5
end

-- How far the feet must rise from the mat to come over the ledge.
function Trampoline.Rise(matTop, ledgeTop)
	if type(matTop) == "number" and type(ledgeTop) == "number" then
		local rise = ledgeTop - matTop + Trampoline.Clearance
		if rise == rise and rise > 30 and rise < 3000 then
			return rise
		end
	end
	return Trampoline.FallbackRise
end

-- What leaves the mat at v comes to rest v^2 / 2g higher.
function Trampoline.LaunchSpeed(gravity, rise)
	return math.sqrt(2 * math.max(1, gravity) * math.max(0, rise))
end

function Trampoline.AscentSeconds(gravity, rise)
	return Trampoline.LaunchSpeed(gravity, rise) / math.max(1, gravity)
end

function Trampoline.Apex(gravity, speed)
	return speed * speed / (2 * math.max(1, gravity))
end

-- From the middle of the root part down to the soles.
function Trampoline.FeetBelowRoot(isR6, hipHeight, rootHeight)
	if isR6 then
		return rootHeight * 0.5 + 2
	end
	return math.max(0, hipHeight) + rootHeight * 0.5
end

function Trampoline.ShouldBounce(now, lastBounceAt, velocityY, launchSpeed)
	-- Not twice in a row, and not something already on its way up from this very mat.
	return now - lastBounceAt >= Trampoline.Cooldown and velocityY < launchSpeed * 0.5
end

-- For the first moments the launch is held: a jump pressed on the same frame would replace
-- it with an ordinary jump. Returns the vertical speed to restore, or nil.
function Trampoline.HeldSpeed(gravity, launchSpeed, sinceLaunch, velocityY)
	if sinceLaunch < 0 or sinceLaunch > Trampoline.HoldSeconds then
		return nil
	end
	local expected = launchSpeed - gravity * sinceLaunch
	if velocityY < expected - Trampoline.HoldTolerance then
		return expected
	end
	return nil
end

return Trampoline
