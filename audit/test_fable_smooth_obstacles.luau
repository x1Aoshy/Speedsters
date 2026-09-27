-- audit/test_fable_smooth_obstacles.luau  (2026-09-20)
-- World 1's presses, lasers, sliding floor, "fast" block, rising lava and rolling cylinder move on the
-- clients from published tracks (Shared/World1ObstacleMotion). This proves:
--   1. a track says exactly what the old server formulas said (run side by side from the
--      script as it was before, for minutes of game time), so no timing changed;
--   2. tracks survive the trip through an attribute (Encode/Decode);
--   3. the server writes no part of a client-driven obstacle and keeps a virtual pose for kills;
--   4. what smoothness that buys: studs moved per visible step, before and after;
--   5. the client script moves near obstacles every frame and far ones not at all;
--   6. the rolling cylinder rolls on the clients exactly as the server rolled it, and its kill
--      check follows the virtual pose;
--   7. an obstacle the runner has passed is not moved at all (hammers included).
-- Pass "places" to check World 1 carries the scripts.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local rb = require("@lune/roblox")
local serde = require("@lune/serde")
local process = require("@lune/process")

local W1 = "src/worlds/World1/"
local MODULE = W1 .. "ReplicatedStorage/Shared/World1ObstacleMotion.luau"
local SERVER = W1 .. "ServerScriptService/Gameplay/NewWorld1ServerMotion.server.luau"
local CLIENT = W1 .. "StarterPlayer/StarterPlayerScripts/Gameplay/NewWorld1TrackMotion.client.luau"
local OLD_SERVER = "output/FableSmoothObstacles/backup_src/NewWorld1ServerMotion.server.luau"
local Vector3, CFrame = rb.Vector3, rb.CFrame
local passed = 0
local function pass(message)
	passed += 1
	print("PASS " .. message)
end
for _, path in { MODULE, SERVER, CLIENT } do
	local ok, problem = pcall(luau.compile, fs.readFile(path))
	assert(ok, path .. ": " .. tostring(problem))
end
local Motion = luau.load(fs.readFile(MODULE), { debugName = "World1ObstacleMotion", environment = {
	Vector3 = Vector3, CFrame = CFrame, math = math, table = table, string = string, tonumber = tonumber, tostring = tostring, assert = assert } })()
local function slice(source, first, last)
	local a = assert(source:find(first, 1, true), "missing: " .. first)
	local b = assert(source:find(last, a + #first, true), "missing: " .. last)
	return source:sub(a, b - 1)
end

-- The constants, read from the server script itself.
local server = fs.readFile(SERVER)
local function constant(name)
	local text = assert(server:match("\nlocal " .. name .. " = ([^\n]+)"), name)
	text = text:gsub("%s*%-%-.*$", "")
	return assert(luau.load("return " .. text, { environment = { math = math } })(), name)
end
local K = {}
for _, name in { "LASER_ANGULAR_SPEED", "PRESS_DOWN_SPEED", "PRESS_UP_SPEED", "PRESS_TOP_WAIT", "PRESS_BOTTOM_WAIT", "PRESS_SEQUENCE_STAGGER",
	"SLIDE_OUTWARD_DISTANCE", "SLIDE_TRAVEL_TIME", "SLIDE_EDGE_WAIT", "SLIDE_SOLID_UNTIL", "FAST_SPEED", "FAST_START_WAIT", "FAST_END_WAIT", "LAVA_RISE_STUDS", "LAVA_TOP_WAIT", "LAVA_BOTTOM_WAIT", "LAVA_DOWN_SPEED" } do
	K[name] = constant(name)
end
K.LAVA_UP_SPEED = 12.65 * 2.5

-- 1. Side by side with the script as it was.
do
	local old = fs.readFile(OLD_SERVER)
	local captured = {}
	local systems = { Lasers = {}, Presses = {}, Slides = nil, Fast = nil, LavaUp = nil }
	local env = { systems = systems, math = math, ipairs = ipairs, pairs = pairs, CFrame = CFrame, Vector3 = Vector3,
		TAU = math.pi * 2,
		sineEase = function(alpha) return 0.5 - math.cos(math.clamp(alpha, 0, 1) * math.pi) * 0.5 end,
		setRecordPivot = function(record, pivot) captured[record] = pivot * record.OriginPivot:Inverse() end,
		setPartsFromWorldTransform = function(record, transform) captured[record] = transform end }
	for name, value in K do env[name] = value end
	local chunk = slice(old, "local function updateLasers(serverTime)", "local function updateBridge(serverTime)")
		.. "\nreturn { lasers = updateLasers, presses = updatePresses, slides = updateSlides, fast = updateFast, lava = updateLavaUp }"
	local legacy = luau.load(chunk, { environment = env })()

	local function record(origin)
		return { Object = { Parent = true }, OriginPivot = origin }
	end
	-- Three presses of different travel, as the map has them.
	local pressTimes = {}
	for index, travel in { 41.5, 38.2, 44.9 } do
		local top = CFrame.new(100 + index * 40, 37600, -900) * CFrame.Angles(0, 0.3 * index, 0)
		local system = { Record = record(top), Index = index, TopPivot = top, BottomPivot = top + Vector3.new(0, -travel, 0),
			DownTime = math.max(0.16, travel / K.PRESS_DOWN_SPEED), UpTime = math.max(0.45, travel / K.PRESS_UP_SPEED) }
		table.insert(systems.Presses, system)
		table.insert(pressTimes, { Index = index, DownTime = system.DownTime, UpTime = system.UpTime })
	end
	local slideA, slideB = CFrame.new(200, 37500, 600), CFrame.new(260, 37500, 600)
	systems.Slides = { First = record(slideA), Second = record(slideB), FirstOut = slideA - Vector3.new(K.SLIDE_OUTWARD_DISTANCE, 0, 0),
		SecondOut = slideB + Vector3.new(K.SLIDE_OUTWARD_DISTANCE, 0, 0), PartStates = {} }
	local fastStart = CFrame.new(300, 37520, 900) * CFrame.Angles(0, 1.1, 0)
	local fastTravel = math.clamp(612 / K.FAST_SPEED, 0.5, 30)
	systems.Fast = { Record = record(fastStart), StartPivot = fastStart, EndPivot = fastStart + Vector3.new(0, 0, 612), TravelTime = fastTravel }
	local lavaBottom = CFrame.new(250, 37300, 1500)
	systems.LavaUp = { Record = record(lavaBottom), BottomPivot = lavaBottom, TopPivot = lavaBottom + Vector3.new(0, K.LAVA_RISE_STUDS, 0),
		UpTime = K.LAVA_RISE_STUDS / K.LAVA_UP_SPEED, DownTime = K.LAVA_RISE_STUDS / K.LAVA_DOWN_SPEED }
	for index = 1, 3 do
		local origin = CFrame.new(150 + index * 30, 37510, 300)
		table.insert(systems.Lasers, { Record = record(origin), Center = origin.Position, Direction = index % 2 == 0 and -1 or 1, PhaseOffset = (index - 1) * math.rad(37) })
	end

	-- The same obstacles as tracks.
	local pressConstants = { TopWait = K.PRESS_TOP_WAIT, BottomWait = K.PRESS_BOTTOM_WAIT, Stagger = K.PRESS_SEQUENCE_STAGGER }
	local tracks = {}
	for _, system in systems.Presses do
		tracks[system.Record] = { A = system.TopPivot, B = system.BottomPivot, Origin = system.TopPivot,
			Segments = Motion.PressSegments(system.Index, system.DownTime, system.UpTime, pressTimes, pressConstants) }
	end
	local slideSegments = Motion.SlideSegments(K.SLIDE_TRAVEL_TIME, K.SLIDE_EDGE_WAIT)
	tracks[systems.Slides.First] = { A = slideA, B = systems.Slides.FirstOut, Origin = slideA, Segments = slideSegments }
	tracks[systems.Slides.Second] = { A = slideB, B = systems.Slides.SecondOut, Origin = slideB, Segments = slideSegments }
	tracks[systems.Fast.Record] = { A = fastStart, B = systems.Fast.EndPivot, Origin = fastStart, Segments = Motion.FastSegments(K.FAST_START_WAIT, fastTravel, K.FAST_END_WAIT) }
	tracks[systems.LavaUp.Record] = { A = lavaBottom, B = systems.LavaUp.TopPivot, Origin = lavaBottom,
		Segments = Motion.LavaSegments(K.LAVA_BOTTOM_WAIT, systems.LavaUp.UpTime, K.LAVA_TOP_WAIT, systems.LavaUp.DownTime) }
	-- Through the attribute and back, as a client gets them.
	for _, track in tracks do
		local segments, cycle = Motion.Decode(Motion.Encode(track.Segments))
		assert(segments and math.abs(cycle - Motion.Cycle(track.Segments)) < 1e-4, "a track did not survive Encode/Decode")
		track.Segments, track.Cycle = segments, cycle
	end

	local probe = Vector3.new(7, -3, 11)
	local worst, samples = 0, 0
	local state = 4242
	local function random()
		state = (state * 1103515245 + 12345) % 2147483648
		return state / 2147483648
	end
	for step = 0, 5400 do
		local t = if step % 3 == 0 then random() * 900 else step / 60 -- 90 s frame by frame, and random instants up to 15 min
		legacy.lasers(t); legacy.presses(t); legacy.slides(t); legacy.fast(t); legacy.lava(t)
		for rec, track in tracks do
			local mine = Motion.PathTransform(track.A, track.B, track.Origin, Motion.Alpha(track.Segments, track.Cycle, t))
			worst = math.max(worst, ((mine * probe) - (captured[rec] * probe)).Magnitude)
			samples += 1
		end
		for _, laser in systems.Lasers do
			local mine = Motion.SpinTransform(laser.Center, K.LASER_ANGULAR_SPEED, laser.Direction, laser.PhaseOffset, t)
			worst = math.max(worst, ((mine * (laser.Center + probe)) - (captured[laser.Record] * (laser.Center + probe))).Magnitude)
			samples += 1
		end
	end
	-- CFrames are float32; at y 37,500 a stud is only held to about 0.004.
	assert(worst < 0.03, ("a track differs from the old server formula by %.4f studs"):format(worst))
	pass(("timing unchanged: %d poses of 9 obstacles match the old server formulas (worst %.4f studs, float32 at y 37,500)"):format(samples, worst))

	-- 4. What it buys. The old picture moved once per network step (20-30 Hz, with jitter).
	local function worstStep(track, hertz)
		local most, last = 0, nil
		for step = 0, math.floor(track.Cycle * hertz) do
			local at = Motion.PathTransform(track.A, track.B, track.Origin, Motion.Alpha(track.Segments, track.Cycle, step / hertz)).Position
			if last then most = math.max(most, (at - last).Magnitude) end
			last = at
		end
		return most
	end
	local press, fast = tracks[systems.Presses[1].Record], tracks[systems.Fast.Record]
	print(("  press coming down: %.1f studs per visible step at 20 Hz (before) -> %.1f at 60 FPS (now)"):format(worstStep(press, 20), worstStep(press, 60)))
	print(("  fast block:        %.1f studs per visible step at 20 Hz (before) -> %.1f at 60 FPS (now)"):format(worstStep(fast, 20), worstStep(fast, 60)))
	assert(worstStep(press, 60) < worstStep(press, 20) * 0.5)
end

-- 2. Alpha's edges and bad attribute text.
do
	local segments = Motion.FastSegments(1, 2, 1)
	local cycle = Motion.Cycle(segments)
	assert(cycle == 4 and Motion.Alpha(segments, cycle, -3) == 0 and Motion.Alpha(segments, cycle, 0.99) == 0)
	assert(math.abs(Motion.Alpha(segments, cycle, 2) - 0.5) < 1e-9 and Motion.Alpha(segments, cycle, 3.5) == 1)
	assert(Motion.Alpha(segments, cycle, 4.5) == 0, "the cycle must repeat")
	for _, bad in { "", "abc", "1:0:1:nope", "1:0:1", "-1:0:1:sine", "0:0:0:hold" } do
		assert(Motion.Decode(bad) == nil, "accepted a bad track: '" .. bad .. "'")
	end
	assert(Motion.Tier(0) == "near" and Motion.Tier(Motion.NearRadius + 1) == "mid" and Motion.Tier(Motion.MidRadius + 1) == "far")
	assert(Motion.NearRadius >= 500, "near must cover what a runner reaches in the next second (about 500 studs at top speed)")
	pass("tracks: start pose before the epoch, repeat every cycle, reject broken attribute text; near tier covers a second of running")
end

-- 3. The server writes nothing of a client-driven obstacle.
do
	local a = assert(server:find("local function snapshotRecord", 1, true))
	local b = assert(server:find("local function refreshRecordActivity", a, true))
	local gate = luau.load(server:sub(a, b - 1) .. "\nreturn { snapshot = snapshotRecord, write = setPartsFromWorldTransform, pivot = setRecordPivot }",
		{ environment = { math = math, pairs = pairs, ipairs = ipairs, Vector3 = Vector3, CFrame = CFrame } })()
	local writes = 0
	local part = setmetatable({ Parent = true }, { __newindex = function(_, key) if key == "CFrame" then writes += 1 end end })
	local origin = CFrame.new(10, 37500, 20)
	local record = { ClientDriven = true, BoundsCFrame = origin, OriginPivot = origin, OriginCFrames = { [part] = origin },
		PreviousCFrames = {}, Radius = 5, CurrentCenter = origin.Position, PreviousCenter = origin.Position }
	gate.pivot(record, origin + Vector3.new(0, -30, 0))
	assert(writes == 0, "the server wrote a part of a client-driven obstacle")
	assert((record.Transform * origin).Position.Y < 37471 and record.CurrentCenter.Y < 37471, "the virtual pose was not kept")
	gate.snapshot(record)
	gate.pivot(record, origin + Vector3.new(0, -35, 0))
	assert(record.PreviousTransform and math.abs((record.PreviousTransform * origin).Position.Y - 37470) < 0.01 and math.abs(record.PreviousCenter.Y - 37470) < 0.01,
		"the kill sweep needs last tick's virtual pose")
	local contact = slice(server, "local function checkPlayerContact", "for _, object in ipairs(mapRoot:GetDescendants())")
	assert(contact:find("previousPartCFrame(group.Record, part)", 1, true) and contact:find("currentPartCFrame(group.Record, part)", 1, true)
		and not contact:find("part.CFrame", 1, true), "the kill backstop still reads real part positions")
	for _, needed in { 'Kind = "Spin"', "ObstacleMotion.PressSegments", "ObstacleMotion.SlideSegments", "ObstacleMotion.FastSegments", "ObstacleMotion.LavaSegments", "Freezes = true" } do
		assert(server:find(needed, 1, true), "the server does not publish: " .. needed)
	end
	pass("server: zero part writes for client-driven obstacles, virtual pose and last-tick pose kept for the kill sweep")
end

-- 5. The client.
do
	local client = fs.readFile(CLIENT)
	for _, needed in { "Motion.Decode", "Motion.Alpha", "Motion.PathTransform", "Motion.SpinTransform", "Motion.Tier", "BulkMoveTo", "GetServerTimeNow",
		"Enum.RenderPriority.First", "AdminWorldFrozen", "DescendantRemoving", "GetInstanceAddedSignal(Motion.Tag)" } do
		assert(client:find(needed, 1, true), "client lost " .. needed)
	end
	assert(not client:find("FireServer", 1, true) and not client:find("task.wait", 1, true), "the motion loop must not wait or talk to the server")
	pass("client: every rendered frame for near obstacles, one BulkMoveTo each, frozen lava respected")
end

-- 6. The rolling cylinder: the last obstacle the server still moved. Same roll, now on the clients.
do
	local old = fs.readFile(OLD_SERVER)
	local captured, lethal = nil, nil
	local system = { Record = { Object = { Parent = true } } }
	local env = { systems = { Cylinder = system }, math = math, ipairs = ipairs, CFrame = CFrame, Vector3 = Vector3,
		CYLINDER_SPEED = constant("CYLINDER_SPEED"), CYLINDER_STOP_WAIT = constant("CYLINDER_STOP_WAIT"), CYLINDER_START_WAIT = constant("CYLINDER_START_WAIT"),
		setCylinderLethalActive = function(_, active) lethal = active end,
		setRecordPivot = function(_, pivot) captured = pivot end }
	local a = assert(old:find("local function sampleCylinderPath", 1, true))
	local b = assert(old:find("\nend\n", a, true)) -- the function alone: what follows it declares the script's own `systems`
	local legacy = luau.load(old:sub(a, b + 4) .. "\n" .. slice(old, "local function updateCylinder(serverTime)", "local function updateHammers(serverTime)")
		.. "\nreturn updateCylinder", { environment = env })()

	-- The real one rolls 258 studs from z -659 down to the stop at z -905, sampled every 1.5 studs
	-- over flat ground, a slope and a bump.
	local start, radius = Vector3.new(265.3, 37541.9, -659), 23.5
	local points, normals = { start }, { Vector3.new(0, 1, 0) }
	for index = 1, 165 do
		local along = index * 1.5
		local drop = if along < 60 then 0 elseif along < 200 then (along - 60) * 0.42 else 58.8
		local bump = if along > 120 and along < 126 then 1.3 else 0
		table.insert(points, Vector3.new(start.X - along * 0.0016, start.Y - drop + bump, start.Z - along))
		table.insert(normals, Vector3.new(0, 1, 0))
	end
	local cumulative, total = { 0 }, 0
	for index = 2, #points do
		total += (points[index] - points[index - 1]).Magnitude
		cumulative[index] = total
	end
	local startPivot = CFrame.new(start + Vector3.new(0.4, -0.2, 0.1)) * CFrame.Angles(0.2, 1.1, math.pi / 2)
	local rollAxis = Vector3.new(0, 1, 0):Cross((points[#points] - start) * Vector3.new(1, 0, 1)).Unit
	system.Record.OriginPivot = startPivot
	system.StartPivot, system.StartCenter, system.PivotOffset = startPivot, start, startPivot.Position - start
	system.PathPoints, system.PathNormals, system.PathCumulative, system.PathDistance = points, normals, cumulative, total
	system.TravelTime, system.RollAxis, system.Radius = math.max(0.35, total / env.CYLINDER_SPEED), rollAxis, radius

	-- What the server publishes and a client reads back.
	local text = Motion.EncodePoints(points)
	local decoded = assert(Motion.DecodePoints(text), "the path did not survive the attribute")
	assert(#decoded == #points and #text < 8000, ("%d points, %d characters"):format(#decoded, #text))
	local roll = Motion.PrepareRoll({ Points = decoded, Speed = env.CYLINDER_SPEED, StartWait = env.CYLINDER_START_WAIT, StopWait = env.CYLINDER_STOP_WAIT,
		TravelTime = system.TravelTime, Radius = radius, RollAxis = rollAxis, PivotOffset = system.PivotOffset, StartPivot = startPivot })
	assert(math.abs(roll.Distance - total) < 0.05 and math.abs(roll.Cycle - (env.CYLINDER_START_WAIT + system.TravelTime + env.CYLINDER_STOP_WAIT)) < 1e-9)
	for _, bad in { "", "1,2", "1,2,3", "1,2,x;4,5,6", "nope" } do
		assert(Motion.DecodePoints(bad) == nil, "accepted a bad path: '" .. bad .. "'")
	end

	local rim = Vector3.new(0, radius, 6) -- a point on its skin: shows the turning as well as the travel
	local worst, samples, state = 0, 0, 977
	local function random()
		state = (state * 1103515245 + 12345) % 2147483648
		return state / 2147483648
	end
	for step = 0, 3600 do
		local t = if step % 3 == 0 then random() * 900 else step / 60
		legacy(t)
		local mine, rolling = Motion.RollPivot(roll, t)
		worst = math.max(worst, ((mine * rim) - (captured * rim)).Magnitude)
		local phase = t % roll.Cycle
		if math.abs(phase - env.CYLINDER_START_WAIT) > 1e-6 then
			assert(rolling == lethal, ("at %.3f s the cylinder kills on one side only"):format(t))
		end
		samples += 1
	end
	assert(worst < 0.03, ("the roll differs from the old server formula by %.4f studs"):format(worst))
	assert(Motion.RollPivot(roll, -5) == startPivot, "before the epoch it waits at its start")

	-- What it buys: the skin of the cylinder per visible step.
	local function worstStep(hertz)
		local most, last = 0, nil
		for step = 0, math.floor((roll.Cycle - env.CYLINDER_STOP_WAIT) * hertz) do
			local at = Motion.RollPivot(roll, step / hertz) * rim
			if last then most = math.max(most, (at - last).Magnitude) end
			last = at
		end
		return most
	end
	print(("  rolling cylinder:  %.1f studs of skin per visible step at 20 Hz (before) -> %.1f at 60 FPS (now)"):format(worstStep(20), worstStep(60)))
	assert(worstStep(60) < worstStep(20) * 0.5)

	-- The server: publishes it, keeps the virtual pose, judges contact where the pose says.
	for _, needed in { 'Kind = "Roll"', "ObstacleMotion.PrepareRoll", "ObstacleMotion.RollPivot(track.Roll, serverTime)", "ObstacleMotion.EncodePoints(roll.Points)",
		"currentPartCFrame(system.Record, system.HazardPart)", "(cframe or part.CFrame):PointToObjectSpace(point)" } do
		assert(server:find(needed, 1, true), "the server lost: " .. needed)
	end
	local contact = slice(server, "local function characterTouchesExactCylinder", "local function buildCylinderSurfacePath")
	assert(not contact:find("cylinderPart.Position", 1, true), "the cylinder's kill check still reads the real part, which no longer moves on the server")
	local touches = luau.load(slice(server, "local function pointInsideExactCylinder", "local function buildCylinderSurfacePath") .. "\nreturn characterTouchesExactCylinder", { environment = {
		math = math, ipairs = ipairs, cylinderMetrics = function() return "X", 20, radius end } })()
	local function body(position)
		local part = { Position = position, IsA = function() return true end }
		return { GetChildren = function() return { part } end }, part
	end
	local resting = CFrame.new(start)
	local cylinderPart = { Parent = true, CFrame = resting, Position = start, Size = Vector3.new(40, 47, 47) }
	local rolledTo = CFrame.new(start + Vector3.new(0, 0, -150))
	local runner, root = body(rolledTo.Position + Vector3.new(3, 5, 2))
	assert(touches(runner, root, cylinderPart, rolledTo) == true, "a runner under the rolling cylinder must die, though the server's part never left its start")
	assert(touches(runner, root, cylinderPart, nil) == false and touches(body(start), select(2, body(start)), cylinderPart, rolledTo) == false,
		"the kill must follow the virtual pose, not where the part rests")
	local client = fs.readFile(CLIENT)
	for _, needed in { 'kind == "Roll"', "Motion.DecodePoints", "Motion.PrepareRoll", "Motion.RollPivot(state.Roll, elapsed) * state.Origin:Inverse()", "names.Points" } do
		assert(client:find(needed, 1, true), "client lost " .. needed)
	end
	pass(("rolling cylinder: %d poses match the old server roll (worst %.4f studs), %d path points in %d characters, killing window identical, contact follows the virtual pose")
		:format(samples, worst, #decoded, #text))
end

-- 7. Whatever the runner has passed stands still.
do
	local HAMMER_MODULE = W1 .. "ReplicatedStorage/Shared/World1HammerMotion.luau"
	local HAMMER_CLIENT = W1 .. "StarterPlayer/StarterPlayerScripts/Gameplay/NewWorld1HammerMotion.client.luau"
	local Hammer = luau.load(fs.readFile(HAMMER_MODULE), { debugName = "World1HammerMotion", environment = {
		Vector3 = Vector3, CFrame = CFrame, math = math, table = table } })()
	local course = Vector3.new(0.0088, 0, 0.99996).Unit -- stage1 -> stage6 in the real map
	for _, M in { Motion, Hammer } do
		assert(M.CourseAttribute == "NewWorld1CourseDirection" and M.BehindMargin >= 100 and M.BehindMargin <= 250)
		local hammer = Vector3.new(274, 37533, -394)
		assert(M.TierFor(Vector3.new(270, 37400, -600), hammer, course, 60) == "near", "an obstacle ahead must move")
		assert(M.TierFor(hammer, hammer, course, 60) == "near", "an obstacle being crossed must move")
		assert(M.TierFor(hammer + course * (M.BehindMargin + 59), hammer, course, 60) == "near", "just past it, it still moves (a fall or a knock-back)")
		assert(M.TierFor(hammer + course * (M.BehindMargin + 61), hammer, course, 60) == "far", "well past it, it must stand still")
		assert(M.TierFor(Vector3.new(276, 37518, 391), hammer, course, 60) == "far", "at the lasers the hammers must stand still (the user's case)")
		assert(M.TierFor(Vector3.new(276, 37518, 391), hammer, nil, 60) ~= "far", "no course direction published: distance decides, as before")
		assert(M.TierFor(hammer - course * 300, hammer, course, 60) == "near", "turned back or sent to an earlier stage: it moves again")
		-- A huge obstacle (the lava floor) is not passed while the runner is still over it.
		assert(M.TierFor(hammer + course * 400, hammer, course, 450) == "near")
		-- Beside the course, however far sideways, is not "passed".
		assert(M.TierFor(hammer + Vector3.new(500, 0, 0), hammer, course, 60) == "near")
		local parts = { { Size = Vector3.new(10, 40, 10) }, { Size = Vector3.new(30, 30, 30) } }
		local reach = M.Reach(hammer, { CFrame.new(hammer + Vector3.new(0, -50, 0)), CFrame.new(hammer + Vector3.new(0, -70, 0)) }, parts)
		assert(math.abs(reach - (70 + Vector3.new(30, 30, 30).Magnitude * 0.5)) < 0.01 and M.Reach(hammer, {}, {}) == 0)
	end
	for path, needles in {
		[CLIENT] = { "Motion.TierFor(focus, state.Anchor, course, state.Reach)", "Motion.TierFor(focus, state.AnchorB, course, state.Reach)", "Workspace:GetAttribute(Motion.CourseAttribute)", "Motion.Reach(state.Reference" },
		[HAMMER_CLIENT] = { "Motion.TierFor(focus, state.Pivot, course, state.Reach)", "Workspace:GetAttribute(Motion.CourseAttribute)", "Motion.Reach(state.Pivot" },
	} do
		local source = fs.readFile(path)
		assert(select(1, pcall(luau.compile, source)), path)
		for _, needed in needles do
			assert(source:find(needed, 1, true), path .. " lost " .. needed)
		end
		-- The part list (and with it the reach) must be ready before the tier is decided.
		assert(source:find("state.Reach = Motion.Reach", 1, true) < source:find("Motion.TierFor(focus", 1, true), path .. ": reach is measured after the tier check")
	end
	assert(server:find("Workspace:SetAttribute(ObstacleMotion.CourseAttribute, getCourseDirection())", 1, true), "the server does not publish the course direction")
	assert(not server:find("only the cylinder is written here", 1, true))
	pass("passed obstacles stand still: beyond their far edge + margin along the course they are never moved; ahead, beside, on top or after turning back they move")
end

if process.args[1] == "places" then
	local manifest = serde.decode("json", fs.readFile("src/manifest.json"))
	local dm = rb.deserializePlace(fs.readFile("World1Update3New.rbxl"))
	for _, source in { MODULE, SERVER, CLIENT, W1 .. "ReplicatedStorage/Shared/World1HammerMotion.luau", W1 .. "StarterPlayer/StarterPlayerScripts/Gameplay/NewWorld1HammerMotion.client.luau" } do
		local row
		for _, candidate in manifest.worlds.World1.scripts do
			if candidate.source == source then row = candidate end
		end
		assert(row, "no manifest row for " .. source)
		local node = dm
		for _, name in row.segments do
			node = assert(node:FindFirstChild(name), "World1 is missing " .. table.concat(row.segments, "."))
		end
		assert(node.Source == fs.readFile(source), node.Name .. " in the place differs from src")
	end
	pass("World 1 place carries the track module, the client mover and the server script")

	-- The real map, the user's case: standing at the first lasers every hammer is passed, and
	-- from stage 4 on the cylinder is; standing at an obstacle it always moves.
	local workspace = dm:GetService("Workspace")
	local map = assert(workspace:FindFirstChild("neworld1"))
	local function where(object)
		if object:IsA("BasePart") then
			return object.CFrame.Position
		end
		for _, item in object:GetDescendants() do
			if item:IsA("BasePart") then return item.CFrame.Position end
		end
		error(object.Name .. " has no part")
	end
	local function reachOf(object, from)
		local bases, parts = {}, {}
		for _, item in object:GetDescendants() do
			if item:IsA("BasePart") then
				table.insert(bases, item.CFrame)
				table.insert(parts, item)
			end
		end
		return Motion.Reach(from, bases, parts)
	end
	local stage1, stage4, stage6 = where(map:FindFirstChild("stage1", true)), where(map:FindFirstChild("stage4", true)), where(map:FindFirstChild("stage6", true))
	local course = ((stage6 - stage1) * Vector3.new(1, 0, 1)).Unit
	assert(course.Z > 0.99, "the course of World 1 runs along +Z")
	local lasers
	for _, item in map:GetDescendants() do
		if item.Name == "laserplatform" and item:IsA("Model") then
			local at = where(item)
			if not lasers or at.Z < lasers.Z then lasers = at end
		end
	end
	local hammers = 0
	for index = 1, 5 do
		local hammer = map:FindFirstChild("Hammer" .. index, true)
		if hammer then
			hammers += 1
			local at = where(hammer)
			local reach = reachOf(hammer, at)
			assert(reach < 250, "Hammer" .. index .. " reaches " .. reach)
			assert(Motion.TierFor(lasers, at, course, reach) == "far", "Hammer" .. index .. " still moves for a runner at the lasers")
			assert(Motion.TierFor(at, at, course, reach) == "near" and Motion.TierFor(at - course * 250, at, course, reach) == "near")
		end
	end
	assert(hammers >= 4)
	local cylinder, stop = assert(workspace:FindFirstChild("cylinder")), assert(map:FindFirstChild("cylinderstop", true))
	for _, anchor in { where(cylinder), where(stop) } do
		assert(Motion.TierFor(stage4, anchor, course, cylinder.Size.Magnitude * 0.5) == "far", "the cylinder still rolls for a runner at stage 4")
		assert(Motion.TierFor(where(stop), anchor, course, cylinder.Size.Magnitude * 0.5) == "near")
	end
	pass(("real map: %d hammers stand still for a runner at the lasers, the cylinder from stage 4 on; both move for whoever is at them"):format(hammers))
end
print(("ALL PASSED (%d groups)"):format(passed))
