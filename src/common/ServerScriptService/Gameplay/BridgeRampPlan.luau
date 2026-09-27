-- BridgeRampPlan.luau
-- A smooth invisible ramp over a plank bridge (Gameplay/SmoothBridges builds it;
-- audit/test_smooth_bridges checks it on the real bridges). 2026-09-18, Sung's video:
-- running over a wooden bridge jerked the character at every plank, because each plank is
-- its own tilted block and their edges step up and down.
--
-- The deck is the bridge's planks: parts thin one way (up) and long another (across the
-- bridge). The ramp follows the middle of their top faces from one end of the deck to the
-- other, in straight pieces a little wider than nothing and a hair over the planks, so a
-- runner meets one smooth surface; the planks themselves then only show. Only numbers.
local Plan = {}

Plan.MaxThickness = 1.6 -- a plank is at most this thick...
Plan.MinLength = 10 -- ...and at least this long across the bridge
Plan.Lift = 0.08 -- the ramp's top over the planks' tops
Plan.Thickness = 1
Plan.Overlap = 0.3 -- each piece reaches this far into the next, so there is no seam
Plan.Inset = 0.4 -- the ramp is this much narrower than the planks are long
Plan.MergeDistance = 0.5 -- plank tops closer than this along the bridge count as one

export type Piece = { CFrame: CFrame, Size: Vector3 }

local function axes(cframe)
	return { cframe.RightVector, cframe.UpVector, cframe.LookVector }
end

-- Whether a part (its CFrame and Size) is a deck plank, and if so its thin axis (pointing
-- up), its long axis and how far it reaches along a direction.
function Plan.Plank(cframe: CFrame, size: Vector3)
	local list = axes(cframe)
	local sizes = { size.X, size.Y, size.Z }
	local thin, long = 1, 1
	for index = 2, 3 do
		if sizes[index] < sizes[thin] then
			thin = index
		end
		if sizes[index] > sizes[long] then
			long = index
		end
	end
	if thin == long or sizes[thin] > Plan.MaxThickness or sizes[long] < Plan.MinLength then
		return nil
	end
	local up = list[thin]
	if math.abs(up.Y) < 0.7 then
		return nil
	end
	if up.Y < 0 then
		up = -up
	end
	local middle = 6 - thin - long
	return {
		Top = cframe.Position + up * (sizes[thin] / 2),
		Up = up,
		Long = list[long],
		LongSize = sizes[long],
		-- A square plank has no long axis of its own.
		Square = sizes[long] < sizes[middle] * 2,
		Reach = function(direction)
			local total = 0
			for index = 1, 3 do
				total += math.abs(list[index]:Dot(direction)) * sizes[index] / 2
			end
			return total
		end,
	}
end

-- The ramp over `planks` (from Plan.Plank): its pieces, and which planks are the deck
-- (the rest, such as trim boards running along the bridge, stay as they are); nil when
-- there is no deck.
function Plan.Ramp(planks): ({ Piece }?, { [number]: boolean }?)
	if #planks < 3 then
		return nil, nil
	end
	-- Across the bridge: the long axis most of the long planks share, level.
	local across, votes = nil, 0
	for _, plank in planks do
		if not plank.Square then
			local candidate = Vector3.new(plank.Long.X, 0, plank.Long.Z)
			if candidate.Magnitude > 1e-3 then
				candidate = candidate.Unit
				local count = 0
				for _, other in planks do
					if not other.Square then
						local long = Vector3.new(other.Long.X, 0, other.Long.Z)
						if long.Magnitude > 1e-3 and math.abs(long.Unit:Dot(candidate)) > 0.9 then
							count += 1
						end
					end
				end
				if count > votes then
					across, votes = candidate, count
				end
			end
		end
	end
	if not across then
		return nil, nil
	end
	local along = Vector3.new(-across.Z, 0, across.X)

	-- The deck: the square planks and the long ones lying across. Its line: each plank's
	-- top middle, ordered along the bridge.
	local deck = {}
	local points = {}
	local lateral, widths = 0, {}
	for index, plank in planks do
		local long = Vector3.new(plank.Long.X, 0, plank.Long.Z)
		local acrossBridge = plank.Square or (long.Magnitude > 1e-3 and math.abs(long.Unit:Dot(across)) > 0.9)
		if acrossBridge then
			deck[index] = true
			table.insert(points, { S = plank.Top:Dot(along), Y = plank.Top.Y, Reach = plank.Reach(along) })
			lateral += plank.Top:Dot(across)
			if not plank.Square then
				table.insert(widths, plank.LongSize)
			end
		end
	end
	if #points < 3 or #widths == 0 then
		return nil, nil
	end
	lateral /= #points
	table.sort(widths)
	local width = widths[math.max(1, math.ceil(#widths / 2))] - Plan.Inset
	table.sort(points, function(a, b)
		return a.S < b.S
	end)
	local line = {}
	for _, point in points do
		local last = line[#line]
		if last and point.S - last.S < Plan.MergeDistance then
			last.Y = math.max(last.Y, point.Y)
		else
			table.insert(line, { S = point.S, Y = point.Y, Reach = point.Reach })
		end
	end
	-- From the far edge of the first plank to the far edge of the last, carrying on the slope
	-- of the deck's ends (a level step there would be a kink).
	local function carry(from, toward, reach)
		local run = from.S - toward.S
		local slope = if math.abs(run) > 1e-3 then (from.Y - toward.Y) / run else 0
		local s = from.S + (if run >= 0 then reach else -reach)
		return { S = s, Y = from.Y + slope * (s - from.S) }
	end
	if #line >= 2 then
		table.insert(line, 1, carry(line[1], line[2], line[1].Reach))
		table.insert(line, carry(line[#line], line[#line - 1], line[#line].Reach))
	end

	local pieces = {}
	local function at(point)
		return along * point.S + across * lateral + Vector3.new(0, point.Y, 0)
	end
	for index = 1, #line - 1 do
		local a, b = at(line[index]), at(line[index + 1])
		local run = b - a
		if run.Magnitude > 1e-3 then
			local forward = run.Unit
			local up = forward:Cross(across)
			if up.Y < 0 then
				up = -up
			end
			local centre = (a + b) / 2 + up * (Plan.Lift - Plan.Thickness / 2)
			table.insert(pieces, {
				CFrame = CFrame.fromMatrix(centre, across, up),
				Size = Vector3.new(width, Plan.Thickness, run.Magnitude + Plan.Overlap),
			})
		end
	end
	return pieces, deck
end

-- World 3's Stage 10 WoodenBridge is a wide arched deck, unlike the narrow plank
-- bridges above. The two outer rows of boards trace the same height profile. Their
-- trim is half a stud above the broad deck slabs; use their profile to make one
-- continuous walkable surface across the whole width, without a flat shortcut.
function Plan.CurvedArch(parts: { BasePart }): { Piece }?
	local boards = {}
	for _, part in parts do
		local size = part.Size
		if math.abs(size.X - 3.01) < 0.2
			and math.abs(size.Y - 7.26) < 0.2
			and math.abs(size.Z - 1.67) < 0.2
			and part.CFrame.RightVector.Y > 0.9 then
			table.insert(boards, part)
		end
	end
	if #boards < 14 then
		return nil
	end

	local first = boards[1].CFrame
	local span = Vector3.new(first.UpVector.X, 0, first.UpVector.Z).Unit
	local across = Vector3.new(first.LookVector.X, 0, first.LookVector.Z).Unit
	local samples = {}
	local lateralSum, lateralMin, lateralMax = 0, math.huge, -math.huge
	for _, board in boards do
		local top = board.CFrame.Position + board.CFrame.RightVector * (board.Size.X / 2)
		local s = top:Dot(span)
		local lateral = top:Dot(across)
		local reach = board.Size.Y * math.abs(board.CFrame.UpVector:Dot(span)) / 2
			+ board.Size.X * math.abs(board.CFrame.RightVector:Dot(span)) / 2
		table.insert(samples, { S = s, Y = top.Y, Reach = reach })
		lateralSum += lateral
		lateralMin = math.min(lateralMin, lateral)
		lateralMax = math.max(lateralMax, lateral)
	end
	if lateralMax - lateralMin < 25 then
		return nil
	end
	local lateral = lateralSum / #boards
	table.sort(samples, function(a, b)
		return a.S < b.S
	end)
	local profile = {}
	for _, sample in samples do
		local previous = profile[#profile]
		if previous and sample.S - previous.S / previous.Count < 0.65 then
			previous.S += sample.S
			previous.Y += sample.Y
			previous.Reach = math.max(previous.Reach, sample.Reach)
			previous.Count += 1
		else
			table.insert(profile, { S = sample.S, Y = sample.Y, Reach = sample.Reach, Count = 1 })
		end
	end
	for _, point in profile do
		point.S /= point.Count
		point.Y = point.Y / point.Count - 0.5 + Plan.Lift
	end
	if #profile < 7 or profile[#profile].S - profile[1].S < 45 then
		return nil
	end

	local function extend(edge, nextPoint, sign)
		local slope = (nextPoint.Y - edge.Y) / (nextPoint.S - edge.S)
		local s = edge.S + sign * edge.Reach
		return { S = s, Y = edge.Y + slope * (s - edge.S) }
	end
	table.insert(profile, 1, extend(profile[1], profile[2], -1))
	table.insert(profile, extend(profile[#profile], profile[#profile - 1], 1))

	local width = lateralMax - lateralMin - 1.2
	local pieces = {}
	for index = 1, #profile - 1 do
		local a = span * profile[index].S + across * lateral + Vector3.new(0, profile[index].Y, 0)
		local b = span * profile[index + 1].S + across * lateral + Vector3.new(0, profile[index + 1].Y, 0)
		local run = b - a
		if run.Magnitude > 1e-3 then
			local up = run.Unit:Cross(across)
			if up.Y < 0 then up = -up end
			local centre = (a + b) / 2 - up * (Plan.Thickness / 2)
			table.insert(pieces, {
				CFrame = CFrame.fromMatrix(centre, across, up),
				Size = Vector3.new(width, Plan.Thickness, run.Magnitude + Plan.Overlap),
			})
		end
	end
	return pieces
end

return Plan
