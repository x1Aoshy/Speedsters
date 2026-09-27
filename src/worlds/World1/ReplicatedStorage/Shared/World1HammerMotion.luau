-- World1HammerMotion: the swing of World 1's hammers as pure maths.
--
-- Until 2026-09-20 the server wrote the CFrame of every hammer part (12 each) 30 times a
-- second. Each part replicates on its own, so on a client the pieces arrived in different
-- packets: the hammer stuttered and looked as if it had come loose. Now the pose is a function
-- of the shared server clock: every client moves the real parts itself, smoothly, and only for
-- the hammers near it (Gameplay/NewWorld1HammerMotion); the server moves nothing and keeps a
-- virtual pose for its kill backstop (Gameplay/NewWorld1ServerMotion).
local Motion = {}

Motion.AngularSpeed = math.pi / (1.2 / 0.819)
Motion.SwingAngle = math.rad(55)
Motion.PhaseOffsets = { -math.pi * 0.5, math.pi * 0.5, 0, math.pi, -math.pi * 0.25 }

Motion.Tag = "NewWorld1ClientHammer"
Motion.Attributes = {
	Pivot = "HammerSwingPivot", -- Vector3, on the hammer
	Axis = "HammerSwingAxis", -- Vector3, on the hammer
	Phase = "HammerSwingPhase", -- number, on the hammer
	Epoch = "HammerSwingEpoch", -- server time the swing counts from, on the hammer
	Moving = "HammerSwingMoving", -- true on each part that swings
	Base = "V306KBH_AuthoredCFrame", -- each part's authored CFrame (NewWorld1ServerMotion writes it)
}

-- A client moves a hammer every frame inside NearRadius, every second frame out to MidRadius,
-- and not at all beyond that (it is then a speck, and its pose is exact again the moment it
-- comes back into range, because the pose only depends on the clock). Near is generous on
-- purpose: a runner at top speed covers about 500 studs a second, and whatever can be reached
-- in the next second must already be moving at the full frame rate. Twelve parts in one
-- BulkMoveTo cost next to nothing; the radii only stop a whole map of obstacles adding up.
Motion.NearRadius = 600
Motion.MidRadius = 1100
Motion.MidFrameSkip = 2

local function verticalSpan(cframe, size)
	return math.abs(cframe.RightVector.Y) * size.X
		+ math.abs(cframe.UpVector.Y) * size.Y
		+ math.abs(cframe.LookVector.Y) * size.Z
end

local function topPoint(cframe, size)
	local half = size * 0.5
	local best = cframe.RightVector * half.X
	for _, candidate in { cframe.UpVector * half.Y, cframe.LookVector * half.Z } do
		if math.abs(candidate.Y) > math.abs(best.Y) then
			best = candidate
		end
	end
	if best.Y < 0 then
		best = -best
	end
	return cframe.Position + best
end

-- parts: array of anything with .CFrame and .Size. The shaft is the tallest part; the pivot is
-- its top; whatever sits wholly above the pivot is the fixed support, the rest swings.
function Motion.Split(parts)
	if #parts <= 1 then
		return {}, {}, nil, parts[1]
	end
	local shaft = parts[1]
	for _, part in parts do
		if verticalSpan(part.CFrame, part.Size) > verticalSpan(shaft.CFrame, shaft.Size) then
			shaft = part
		end
	end
	local pivot = topPoint(shaft.CFrame, shaft.Size)
	local moving, fixed = {}, {}
	for _, part in parts do
		local bottom = part.CFrame.Position.Y - verticalSpan(part.CFrame, part.Size) * 0.5
		if part ~= shaft and bottom >= pivot.Y - 0.8 then
			table.insert(fixed, part)
		else
			table.insert(moving, part)
		end
	end
	if #fixed == 0 then
		return {}, {}, nil, shaft
	end
	return moving, fixed, pivot, shaft
end

-- The axis a hammer turns on. The designer points each head along the way it should swing
-- (its two striking faces are the ends of the head), so the axis is the horizontal direction
-- square to the head. Hammer3 stands on the cross platform, where the path runs along X: the
-- old "course direction" axis made it turn on its own length and sweep the path broadside.
function Motion.SwingAxis(moving, shaft, fallback)
	local head, headVolume = nil, 0
	for _, part in moving do
		if part ~= shaft then
			local size = part.Size
			local volume = size.X * size.Y * size.Z
			if volume > headVolume then
				head, headVolume = part, volume
			end
		end
	end
	if head then
		local size, cframe = head.Size, head.CFrame
		local long = cframe.RightVector
		local longest = size.X
		if size.Y > longest then
			long, longest = cframe.UpVector, size.Y
		end
		if size.Z > longest then
			long, longest = cframe.LookVector, size.Z
		end
		local flat = Vector3.new(long.X, 0, long.Z)
		-- A head has to be clearly longer one way, and that way has to be level.
		local others = size.X + size.Y + size.Z - longest
		if flat.Magnitude > 0.7 and longest > others * 0.75 then
			flat = flat.Unit
			-- up x long, with a fixed sign so mirrored heads still agree on the swing.
			local axis = Vector3.new(flat.Z, 0, -flat.X)
			if axis.Z < -0.5 or (math.abs(axis.Z) <= 0.5 and axis.X < 0) then
				axis = -axis
			end
			return axis
		end
	end
	if fallback and Vector3.new(fallback.X, 0, fallback.Z).Magnitude > 0.001 then
		return Vector3.new(fallback.X, 0, fallback.Z).Unit
	end
	return Vector3.new(0, 0, 1)
end

function Motion.PhaseAt(phaseOffset, elapsed)
	return phaseOffset + math.max(0, elapsed) * Motion.AngularSpeed
end

function Motion.AngleAt(phaseOffset, elapsed)
	return math.sin(Motion.PhaseAt(phaseOffset, elapsed)) * Motion.SwingAngle
end

-- The world transform that carries every authored CFrame of the hammer to its pose.
function Motion.Transform(pivot, axis, angle)
	return CFrame.new(pivot) * CFrame.fromAxisAngle(axis, angle) * CFrame.new(-pivot)
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

-- Do two boxes overlap? (separating axis test; `shrink` pulls box A's faces in by that many
-- studs, which is how the server's backstop stays on the safe side of a laggy position.)
function Motion.BoxesOverlap(cframeA, sizeA, cframeB, sizeB, shrink)
	local halfA = sizeA * 0.5 - Vector3.new(shrink or 0, shrink or 0, shrink or 0)
	if halfA.X <= 0 or halfA.Y <= 0 or halfA.Z <= 0 then
		return false
	end
	local halfB = sizeB * 0.5
	local axesA = { cframeA.RightVector, cframeA.UpVector, cframeA.LookVector }
	local axesB = { cframeB.RightVector, cframeB.UpVector, cframeB.LookVector }
	local extentA = { halfA.X, halfA.Y, halfA.Z }
	local extentB = { halfB.X, halfB.Y, halfB.Z }
	local offset = cframeB.Position - cframeA.Position

	local function separated(axis)
		local length = axis.Magnitude
		if length < 1e-5 then
			return false -- parallel edges: this axis decides nothing
		end
		axis = axis / length
		local radiusA, radiusB = 0, 0
		for i = 1, 3 do
			radiusA += extentA[i] * math.abs(axesA[i]:Dot(axis))
			radiusB += extentB[i] * math.abs(axesB[i]:Dot(axis))
		end
		return math.abs(offset:Dot(axis)) > radiusA + radiusB
	end

	for i = 1, 3 do
		if separated(axesA[i]) or separated(axesB[i]) then
			return false
		end
	end
	for i = 1, 3 do
		for j = 1, 3 do
			if separated(axesA[i]:Cross(axesB[j])) then
				return false
			end
		end
	end
	return true
end

return Motion
