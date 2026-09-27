-- World1ObstacleMotion: the presses, lasers, sliding floor, "fast" block, rising lava and
-- rolling cylinder of World 1 as pure functions of the shared server clock.
--
-- These used to be moved by the server 30 times a second and reach each client over the
-- network at 20-30 Hz with jitter, which in a parkour game reads as stutter exactly where
-- timing matters. Now the server publishes each obstacle's TRACK once (what is below) and
-- every client moves the real parts itself, every rendered frame, for the obstacles near it
-- (Gameplay/NewWorld1TrackMotion). The server evaluates the same track for its kill backstop
-- and writes no part. One formula, so every screen and the server agree.
--
-- A track is either
--   Roll: roll along a path of points (the cylinder);  or
--   Spin: turn about a vertical axis through Center;  or
--   Path: glide between two pivots A and B through a list of segments
--         { Duration, From, To, Ease }, From/To being 0 (at A) or 1 (at B), repeated every Cycle.
local Motion = {}

Motion.Tag = "NewWorld1ClientTrack"
Motion.Attributes = {
	Kind = "TrackKind", -- "Spin" | "Path" | "Roll"
	Points = "TrackPoints", StartWait = "TrackStartWait", StopWait = "TrackStopWait", TravelTime = "TrackTravelTime", -- Roll
	Radius = "TrackRadius", RollAxis = "TrackRollAxis", PivotOffset = "TrackPivotOffset", -- Roll (Origin = its start pivot)
	Epoch = "TrackEpoch", -- server time the track counts from
	Origin = "TrackOriginPivot", -- CFrame: the pivot the authored CFrames belong to (Path)
	A = "TrackPivotA", B = "TrackPivotB", -- CFrame (Path)
	Segments = "TrackSegments", -- string, see Encode (Path)
	Center = "TrackCenter", Speed = "TrackSpeed", Direction = "TrackDirection", Phase = "TrackPhase", -- Spin
	Freezes = "TrackFreezesWithWorld", -- true: holds still while Workspace.AdminWorldFrozen
	Moving = "TrackMoving", -- true on each part that moves
	Base = "V306KBH_AuthoredCFrame", -- each part's authored CFrame (NewWorld1ServerMotion writes it)
}
-- Every frame inside NearRadius, every second frame out to MidRadius, left alone beyond.
-- A runner at top speed covers about 500 studs a second, so "near" is generous on purpose:
-- whatever can be reached in the next second already moves at full rate.
Motion.NearRadius = 600
Motion.MidRadius = 1100
Motion.MidFrameSkip = 2

local EASES = {
	hold = function()
		return 0
	end,
	linear = function(p)
		return p
	end,
	sine = function(p)
		return 0.5 - math.cos(p * math.pi) * 0.5
	end,
	cube = function(p)
		return p * p * p
	end,
	square = function(p)
		return p * p
	end,
}
Motion.Eases = EASES

-- segments: array of { Duration, From, To, Ease }. Returns the text for the attribute.
function Motion.Encode(segments)
	local pieces = {}
	for _, segment in segments do
		assert(EASES[segment.Ease], "unknown ease " .. tostring(segment.Ease))
		table.insert(pieces, string.format("%.9f:%g:%g:%s", segment.Duration, segment.From, segment.To, segment.Ease))
	end
	return table.concat(pieces, ";")
end

function Motion.Decode(text)
	local segments, cycle = {}, 0
	for piece in string.gmatch(text, "[^;]+") do
		local duration, from, to, ease = string.match(piece, "^([^:]+):([^:]+):([^:]+):(%a+)$")
		duration, from, to = tonumber(duration), tonumber(from), tonumber(to)
		if not duration or not from or not to or not EASES[ease] or duration < 0 then
			return nil, 0
		end
		table.insert(segments, { Duration = duration, From = from, To = to, Ease = ease })
		cycle += duration
	end
	if #segments == 0 or cycle <= 0 then
		return nil, 0
	end
	return segments, cycle
end

function Motion.Cycle(segments)
	local cycle = 0
	for _, segment in segments do
		cycle += segment.Duration
	end
	return cycle
end

-- Where between A (0) and B (1) the obstacle is, `elapsed` seconds after the epoch.
function Motion.Alpha(segments, cycle, elapsed)
	local phase = math.max(0, elapsed) % cycle
	for _, segment in segments do
		if phase < segment.Duration then
			if segment.From == segment.To or segment.Duration <= 0 then
				return segment.To
			end
			local eased = EASES[segment.Ease](math.clamp(phase / segment.Duration, 0, 1))
			return segment.From + (segment.To - segment.From) * eased
		end
		phase -= segment.Duration
	end
	return segments[#segments].To
end

-- The world transform that carries every authored CFrame of a Path obstacle to its pose.
function Motion.PathTransform(a, b, origin, alpha)
	return a:Lerp(b, alpha) * origin:Inverse()
end

function Motion.SpinAngle(speed, direction, phase, elapsed)
	local period = 2 * math.pi / speed
	return ((math.max(0, elapsed) % period) * speed) * direction + phase
end

function Motion.SpinTransform(center, speed, direction, phase, elapsed)
	return CFrame.new(center) * CFrame.Angles(0, Motion.SpinAngle(speed, direction, phase, elapsed), 0) * CFrame.new(-center)
end

function Motion.Tier(distance)
	if distance <= Motion.NearRadius then
		return "near"
	elseif distance <= Motion.MidRadius then
		return "mid"
	end
	return "far"
end

-- An obstacle the runner has already passed does not move at all: once this player is more
-- than BehindMargin studs beyond the far edge of it along the course (the server publishes the
-- direction as Workspace.NewWorld1CourseDirection; `reach` is how far the obstacle extends
-- from its anchor), it is "far" whatever the distance. Turn back, fall or teleport to an
-- earlier stage and it moves again within a quarter of a second, exactly on time, because
-- its pose only depends on the clock.
Motion.CourseAttribute = "NewWorld1CourseDirection"
Motion.BehindMargin = 160

function Motion.TierFor(focus, anchor, courseDirection, reach)
	local offset = focus - anchor
	if courseDirection and offset:Dot(courseDirection) > Motion.BehindMargin + (reach or 0) then
		return "far"
	end
	return Motion.Tier(offset.Magnitude)
end

-- How far a set of authored parts extends from `reference` (their corners included).
function Motion.Reach(reference, bases, parts)
	local reach = 0
	for index, base in bases do
		reach = math.max(reach, (base.Position - reference).Magnitude + parts[index].Size.Magnitude * 0.5)
	end
	return reach
end

----------------------------------------------------------------------
-- Roll: the rolling cylinder. It waits, rolls along a path of points at a constant speed,
-- turning by distance / radius, waits at the end, and starts again.
----------------------------------------------------------------------
function Motion.EncodePoints(points)
	local pieces = {}
	for _, point in points do
		table.insert(pieces, string.format("%.3f,%.3f,%.3f", point.X, point.Y, point.Z))
	end
	return table.concat(pieces, ";")
end

function Motion.DecodePoints(text)
	local points = {}
	for piece in string.gmatch(text, "[^;]+") do
		local x, y, z = string.match(piece, "^([^,]+),([^,]+),([^,]+)$")
		x, y, z = tonumber(x), tonumber(y), tonumber(z)
		if not x or not y or not z then
			return nil
		end
		table.insert(points, Vector3.new(x, y, z))
	end
	return if #points >= 2 then points else nil
end

-- roll: { Points, Speed, StartWait, StopWait, TravelTime, Radius, RollAxis, PivotOffset, StartPivot }
-- Fills in what is derived (the running length of the path) and returns it.
function Motion.PrepareRoll(roll)
	assert(#roll.Points >= 2, "a roll needs a path")
	local cumulative, total = { 0 }, 0
	for index = 2, #roll.Points do
		total += (roll.Points[index] - roll.Points[index - 1]).Magnitude
		cumulative[index] = total
	end
	roll.Cumulative, roll.Distance = cumulative, total
	roll.Cycle = roll.StartWait + roll.TravelTime + roll.StopWait
	roll.Rotation = roll.StartPivot - roll.StartPivot.Position
	return roll
end

-- The cylinder's pivot, and whether it is rolling (it only kills while it rolls).
function Motion.RollPivot(roll, elapsed)
	local phase = math.max(0, elapsed) % roll.Cycle
	if phase <= roll.StartWait then
		return roll.StartPivot, false
	end
	local travelled = math.min(roll.Distance, math.min(roll.TravelTime, phase - roll.StartWait) * roll.Speed)
	local points, cumulative = roll.Points, roll.Cumulative
	local low, high = 2, #points
	while low < high do
		local middle = math.floor((low + high) * 0.5)
		if cumulative[middle] < travelled then
			low = middle + 1
		else
			high = middle
		end
	end
	local before = cumulative[low - 1]
	local alpha = math.clamp((travelled - before) / math.max(0.0001, cumulative[low] - before), 0, 1)
	local centre = points[low - 1]:Lerp(points[low], alpha)
	return CFrame.new(centre + roll.PivotOffset) * CFrame.fromAxisAngle(roll.RollAxis, travelled / roll.Radius) * roll.Rotation, true
end

-- The tracks themselves, built from the same numbers the server script always used.
function Motion.PressSegments(index, downTime, upTime, presses, constants)
	-- presses: array of { Index, DownTime, UpTime } for every press, because they share a cycle.
	local latestDownFinish = constants.TopWait
	for _, press in presses do
		latestDownFinish = math.max(latestDownFinish, constants.TopWait + (press.Index - 1) * constants.Stagger + press.DownTime)
	end
	local upBase = latestDownFinish + constants.BottomWait
	local cycle = upBase
	for _, press in presses do
		cycle = math.max(cycle, upBase + (press.Index - 1) * constants.Stagger + press.UpTime)
	end
	local downStart = constants.TopWait + (index - 1) * constants.Stagger
	local downEnd = downStart + downTime
	local upStart = upBase + (index - 1) * constants.Stagger
	local upEnd = upStart + upTime
	return {
		{ Duration = downStart, From = 0, To = 0, Ease = "hold" },
		{ Duration = downTime, From = 0, To = 1, Ease = "cube" },
		{ Duration = upStart - downEnd, From = 1, To = 1, Ease = "hold" },
		{ Duration = upTime, From = 1, To = 0, Ease = "sine" },
		{ Duration = math.max(0, cycle - upEnd), From = 0, To = 0, Ease = "hold" },
	}
end

function Motion.SlideSegments(travelTime, edgeWait)
	return {
		{ Duration = travelTime, From = 0, To = 1, Ease = "sine" },
		{ Duration = edgeWait, From = 1, To = 1, Ease = "hold" },
		{ Duration = travelTime, From = 1, To = 0, Ease = "sine" },
		{ Duration = edgeWait, From = 0, To = 0, Ease = "hold" },
	}
end

function Motion.FastSegments(startWait, travelTime, endWait)
	return {
		{ Duration = startWait, From = 0, To = 0, Ease = "hold" },
		{ Duration = travelTime, From = 0, To = 1, Ease = "linear" },
		{ Duration = endWait, From = 1, To = 1, Ease = "hold" },
	}
end

function Motion.LavaSegments(bottomWait, upTime, topWait, downTime)
	return {
		{ Duration = bottomWait, From = 0, To = 0, Ease = "hold" },
		{ Duration = upTime, From = 0, To = 1, Ease = "sine" },
		{ Duration = topWait, From = 1, To = 1, Ease = "hold" },
		{ Duration = downTime, From = 1, To = 0, Ease = "square" },
	}
end

return Motion
