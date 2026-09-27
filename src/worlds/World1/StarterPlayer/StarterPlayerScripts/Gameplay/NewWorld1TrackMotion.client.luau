-- NewWorld1TrackMotion.client.luau
-- Moves World 1's presses, lasers, sliding floor, "fast" block, rising lava and rolling cylinder on this client,
-- every rendered frame, from the shared server clock (Shared/World1ObstacleMotion).
--
-- The server used to move them 30 times a second and they arrived here over the network at
-- 20-30 Hz with jitter: stutter exactly where a parkour run needs to read the timing. Now the
-- server publishes each obstacle's track once and writes nothing; what is drawn here is the
-- exact pose for this instant, at the screen's own frame rate, and it is the same pose on every
-- screen and in the server's kill backstop. Contact is still judged by NewWorld1MapMotion on
-- these same parts, so what is seen is what kills.
--
-- Cost: one BulkMoveTo per obstacle per frame, and only for obstacles within
-- Motion.NearRadius of this player (every second frame out to MidRadius, none beyond), and
-- none at all for an obstacle this player has already passed (Motion.TierFor).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
if Config.IsNewWorld1Map ~= true then
	return
end
local Motion = require(Shared:WaitForChild("World1ObstacleMotion"))
local names = Motion.Attributes
local player = Players.LocalPlayer

local TIER_CHECK_SECONDS = 0.25
local tracks = {} -- tagged instance -> state

local function readTrack(object, state)
	state.Ready = false
	local kind = object:GetAttribute(names.Kind)
	local epoch = object:GetAttribute(names.Epoch)
	if type(epoch) ~= "number" then
		return
	end
	state.Kind, state.Epoch = kind, epoch
	state.Freezes = object:GetAttribute(names.Freezes) == true
	if kind == "Spin" then
		local center = object:GetAttribute(names.Center)
		local speed = object:GetAttribute(names.Speed)
		local direction = object:GetAttribute(names.Direction)
		local phase = object:GetAttribute(names.Phase)
		if typeof(center) == "Vector3" and type(speed) == "number" and speed > 0
			and type(direction) == "number" and type(phase) == "number"
		then
			state.Center, state.Speed, state.Direction, state.Phase = center, speed, direction, phase
			state.Anchor, state.AnchorB, state.Reference = center, nil, center
			state.Dirty = true
			state.Ready = true
		end
	elseif kind == "Roll" then
		local origin = object:GetAttribute(names.Origin)
		local text = object:GetAttribute(names.Points)
		local speed, radius = object:GetAttribute(names.Speed), object:GetAttribute(names.Radius)
		local startWait, stopWait, travelTime = object:GetAttribute(names.StartWait), object:GetAttribute(names.StopWait), object:GetAttribute(names.TravelTime)
		local axis, pivotOffset = object:GetAttribute(names.RollAxis), object:GetAttribute(names.PivotOffset)
		local points = type(text) == "string" and Motion.DecodePoints(text) or nil
		if points and typeof(origin) == "CFrame" and typeof(axis) == "Vector3" and typeof(pivotOffset) == "Vector3"
			and type(speed) == "number" and speed > 0 and type(radius) == "number" and radius > 0
			and type(startWait) == "number" and type(stopWait) == "number" and type(travelTime) == "number" and travelTime > 0
		then
			state.Roll = Motion.PrepareRoll({ Points = points, Speed = speed, StartWait = startWait, StopWait = stopWait,
				TravelTime = travelTime, Radius = radius, RollAxis = axis, PivotOffset = pivotOffset, StartPivot = origin })
			state.Origin, state.Reference = origin, origin.Position
			state.Anchor, state.AnchorB = points[1], points[#points]
			state.Dirty = true
			state.Ready = true
		end
	elseif kind == "Path" then
		local origin = object:GetAttribute(names.Origin)
		local a, b = object:GetAttribute(names.A), object:GetAttribute(names.B)
		local text = object:GetAttribute(names.Segments)
		if typeof(origin) == "CFrame" and typeof(a) == "CFrame" and typeof(b) == "CFrame" and type(text) == "string" then
			local segments, cycle = Motion.Decode(text)
			if segments then
				state.Origin, state.A, state.B, state.Segments, state.Cycle = origin, a, b, segments, cycle
				-- Near either end of its travel counts as near.
				state.Anchor, state.AnchorB, state.Reference = a.Position, b.Position, origin.Position
				state.Dirty = true
				state.Ready = true
			end
		end
	end
end

local function track(object)
	if tracks[object] then
		return
	end
	local state = {
		Bases = {}, PartList = {}, BaseList = {}, Targets = {},
		Dirty = true, Tier = "far", NextTierAt = 0, Ready = false, Connections = {},
	}
	tracks[object] = state
	-- Parts stream in and out, and the server may mark them a moment after they arrive.
	local function consider(part)
		if not part:IsA("BasePart") then
			return
		end
		local function refresh()
			if part:GetAttribute(names.Moving) == true and (part == object or part:IsDescendantOf(object)) then
				if not state.Bases[part] then
					local base = part:GetAttribute(names.Base)
					state.Bases[part] = if typeof(base) == "CFrame" then base else part.CFrame
					state.Dirty = true
				end
			elseif state.Bases[part] then
				state.Bases[part] = nil
				state.Dirty = true
			end
		end
		table.insert(state.Connections, part:GetAttributeChangedSignal(names.Moving):Connect(refresh))
		refresh()
	end
	consider(object)
	for _, item in object:GetDescendants() do
		consider(item)
	end
	table.insert(state.Connections, object.DescendantAdded:Connect(consider))
	table.insert(state.Connections, object.DescendantRemoving:Connect(function(item)
		if state.Bases[item] then
			state.Bases[item] = nil
			state.Dirty = true
		end
	end))
	for _, name in { names.Kind, names.Epoch, names.Origin, names.A, names.B, names.Segments, names.Center, names.Speed, names.Direction, names.Phase, names.Freezes,
		names.Points, names.StartWait, names.StopWait, names.TravelTime, names.Radius, names.RollAxis, names.PivotOffset } do
		table.insert(state.Connections, object:GetAttributeChangedSignal(name):Connect(function()
			readTrack(object, state)
		end))
	end
	readTrack(object, state)
end

local function untrack(object)
	local state = tracks[object]
	if not state then
		return
	end
	tracks[object] = nil
	for _, connection in state.Connections do
		connection:Disconnect()
	end
end

for _, object in CollectionService:GetTagged(Motion.Tag) do
	track(object)
end
CollectionService:GetInstanceAddedSignal(Motion.Tag):Connect(track)
CollectionService:GetInstanceRemovedSignal(Motion.Tag):Connect(untrack)

local function focusPosition()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		return root.Position
	end
	local camera = Workspace.CurrentCamera
	return camera and camera.CFrame.Position or Vector3.zero
end

local frame = 0
RunService:BindToRenderStep("NewWorld1TrackMotion", Enum.RenderPriority.First.Value, function()
	frame += 1
	local clock = os.clock()
	local serverNow = Workspace:GetServerTimeNow()
	local frozen = Workspace:GetAttribute("AdminWorldFrozen") == true
	local course = Workspace:GetAttribute(Motion.CourseAttribute)
	course = if typeof(course) == "Vector3" then course else nil
	local focus = nil
	for _, state in tracks do
		if not state.Ready or (frozen and state.Freezes) then
			continue
		end
		if state.Dirty then
			state.Dirty = false
			table.clear(state.PartList)
			table.clear(state.BaseList)
			table.clear(state.Targets)
			for part, base in state.Bases do
				table.insert(state.PartList, part)
				table.insert(state.BaseList, base)
			end
			state.Reach = Motion.Reach(state.Reference, state.BaseList, state.PartList)
		end
		if clock >= state.NextTierAt then
			focus = focus or focusPosition()
			-- Near either end of its travel counts as near; passed only when both ends are behind.
			local tier = Motion.TierFor(focus, state.Anchor, course, state.Reach)
			if state.AnchorB and tier ~= "near" then
				local other = Motion.TierFor(focus, state.AnchorB, course, state.Reach)
				if other == "near" or (other == "mid" and tier == "far") then
					tier = other
				end
			end
			state.Tier = tier
			state.NextTierAt = clock + TIER_CHECK_SECONDS
		end
		if state.Tier == "far" or (state.Tier == "mid" and frame % Motion.MidFrameSkip ~= 0) then
			continue
		end
		if #state.PartList == 0 then
			continue
		end
		local elapsed = serverNow - state.Epoch
		local transform
		if state.Kind == "Spin" then
			transform = Motion.SpinTransform(state.Center, state.Speed, state.Direction, state.Phase, elapsed)
		elseif state.Kind == "Roll" then
			transform = Motion.RollPivot(state.Roll, elapsed) * state.Origin:Inverse()
		else
			transform = Motion.PathTransform(state.A, state.B, state.Origin, Motion.Alpha(state.Segments, state.Cycle, elapsed))
		end
		local targets = state.Targets
		for index, base in state.BaseList do
			targets[index] = transform * base
		end
		Workspace:BulkMoveTo(state.PartList, targets, Enum.BulkMoveMode.FireCFrameChanged)
	end
end)
