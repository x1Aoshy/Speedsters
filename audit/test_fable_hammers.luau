-- audit/test_fable_hammers.luau  (2026-09-20)
-- World 1's hammers, from the real module against the real place:
--   1. the split (12 swinging parts, 1 fixed support, pivot on top of the shaft);
--   2. every hammer swings ACROSS the path it stands on (Hammer3 used to swing along it);
--   3. the swing is rigid, turns about the pivot, never exceeds 55 degrees, clears the floor;
--   4. server and clients share one formula, and the server writes no hammer part;
--   5. the box test behind the server's kill backstop;
--   6. distance tiers, and the "nobody near" gate for the other obstacles;
--   7. (places) World 1 carries the scripts, and the hammer models stream in whole.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local rb = require("@lune/roblox")
local serde = require("@lune/serde")
local process = require("@lune/process")

local W1 = "src/worlds/World1/"
local MODULE = W1 .. "ReplicatedStorage/Shared/World1HammerMotion.luau"
local SERVER = W1 .. "ServerScriptService/Gameplay/NewWorld1ServerMotion.server.luau"
local CLIENT = W1 .. "StarterPlayer/StarterPlayerScripts/Gameplay/NewWorld1HammerMotion.client.luau"
local PLACE = "World1Update3New.rbxl"
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
local Motion = luau.load(fs.readFile(MODULE), { debugName = "World1HammerMotion", environment = {
	Vector3 = Vector3, CFrame = CFrame, math = math, table = table } })()

local dm = rb.deserializePlace(fs.readFile(PLACE))
local root = assert(dm:GetService("Workspace"):FindFirstChild("neworld1"))

local function worldSpan(part, axis)
	local c, s = part.CFrame, part.Size
	return math.abs(c.RightVector:Dot(axis)) * s.X + math.abs(c.UpVector:Dot(axis)) * s.Y + math.abs(c.LookVector:Dot(axis)) * s.Z
end

-- The platform a hammer hangs over: the big slab under its pivot.
local function platformUnder(pivot)
	local best, bestArea = nil, 0
	for _, item in root:GetDescendants() do
		if item:IsA("BasePart") and not item.Parent.Name:lower():find("hammer", 1, true) then
			local p = item.CFrame.Position
			local spanX, spanZ = worldSpan(item, Vector3.new(1, 0, 0)), worldSpan(item, Vector3.new(0, 0, 1))
			if p.Y < pivot.Y - 30 and p.Y > pivot.Y - 70
				and math.abs(p.X - pivot.X) <= spanX / 2 and math.abs(p.Z - pivot.Z) <= spanZ / 2
				and spanX * spanZ > bestArea and math.max(spanX, spanZ) < 200
			then
				best, bestArea = item, spanX * spanZ
			end
		end
	end
	return best
end

local hammers = {}
for index = 1, 5 do
	local model = root:FindFirstChild("Hammer" .. index, true)
	if model then
		local parts = {}
		for _, item in model:GetDescendants() do
			if item:IsA("BasePart") then
				table.insert(parts, item)
			end
		end
		local moving, fixed, pivot, shaft = Motion.Split(parts)
		assert(pivot and #moving == 12 and #fixed == 1, ("Hammer%d split: %d moving, %d fixed"):format(index, #moving, #fixed))
		assert(table.find(moving, shaft), "the shaft must swing")
		assert(math.abs(pivot.Y - (shaft.CFrame.Position.Y + worldSpan(shaft, Vector3.new(0, 1, 0)) / 2)) < 0.01, "pivot is not the top of the shaft")
		assert(fixed[1].CFrame.Position.Y > pivot.Y, "the fixed support is not above the pivot")
		hammers[index] = { model = model, moving = moving, fixed = fixed, pivot = pivot, shaft = shaft }
	end
end
assert(hammers[1] and hammers[3] and hammers[4] and hammers[5], "the four authored hammers")
pass("split: 4 hammers, each 12 swinging parts + 1 fixed support, pivot on top of the shaft")

-- 2. Across the path.
for index, hammer in hammers do
	local axis = Motion.SwingAxis(hammer.moving, hammer.shaft, Vector3.new(0, 0, 1))
	assert(math.abs(axis.Magnitude - 1) < 1e-4 and math.abs(axis.Y) < 1e-4, "axis must be a level unit vector")
	local platform = assert(platformUnder(hammer.pivot), "no platform under Hammer" .. index)
	local spanX, spanZ = worldSpan(platform, Vector3.new(1, 0, 0)), worldSpan(platform, Vector3.new(0, 0, 1))
	local pathDirection = if spanX > spanZ then Vector3.new(1, 0, 0) else Vector3.new(0, 0, 1)
	assert(math.abs(axis:Dot(pathDirection)) > 0.99,
		("Hammer%d turns on (%.2f, %.2f) but its platform runs along (%d, %d): it would swing along the path"):format(
			index, axis.X, axis.Z, pathDirection.X, pathDirection.Z))
	-- ...and that is square to the head's own length.
	local head = hammer.moving[1]
	for _, part in hammer.moving do
		if part ~= hammer.shaft and part.Size.X * part.Size.Y * part.Size.Z > head.Size.X * head.Size.Y * head.Size.Z then
			head = part
		end
	end
	if head == hammer.shaft then
		for _, part in hammer.moving do if part ~= hammer.shaft then head = part break end end
	end
	hammer.axis, hammer.platform, hammer.path = axis, platform, pathDirection
end
local old3 = Vector3.new(0, 0, 1) -- the course direction every hammer used before
assert(math.abs(hammers[3].axis:Dot(old3)) < 0.01, "Hammer3 still turns on the course direction")
for _, index in { 1, 4, 5 } do
	assert(hammers[index].axis:Dot(old3) > 0.99, "Hammer" .. index .. " changed its swing; only Hammer3 was wrong")
end
-- An authored override still wins on the server, and a shapeless head falls back.
assert(Motion.SwingAxis({ { Size = Vector3.new(5, 5, 5), CFrame = CFrame.new(0, 0, 0) } }, nil, Vector3.new(1, 0, 0.1)).X > 0.99)
pass("axis: every hammer swings across its own platform; Hammer3 fixed (X, was Z); 1, 4 and 5 unchanged")

-- 3. The swing itself.
for index, hammer in hammers do
	local phase = Motion.PhaseOffsets[index]
	local floorTop = hammer.platform.CFrame.Position.Y + worldSpan(hammer.platform, Vector3.new(0, 1, 0)) / 2
	local widest = 0
	for step = 0, 400 do
		local elapsed = step * 0.0125
		local angle = Motion.AngleAt(phase, elapsed)
		assert(math.abs(angle) <= Motion.SwingAngle + 1e-6, "swing exceeds 55 degrees")
		local transform = Motion.Transform(hammer.pivot, hammer.axis, angle)
		assert((transform * hammer.pivot - hammer.pivot).Magnitude < 0.02, "the pivot moves")
		for _, part in hammer.moving do
			local base = part.CFrame
			local posed = transform * base
			assert(math.abs((posed.Position - hammer.pivot).Magnitude - (base.Position - hammer.pivot).Magnitude) < 0.05, "the hammer stretches")
			local drift = (posed.Position - base.Position):Dot(hammer.axis)
			assert(math.abs(drift) < 0.05, "a part slides along the axis")
			local lowest = posed.Position.Y - (math.abs(posed.RightVector.Y) * part.Size.X + math.abs(posed.UpVector.Y) * part.Size.Y + math.abs(posed.LookVector.Y) * part.Size.Z) / 2
			assert(lowest > floorTop + 1, ("Hammer%d digs into its platform"):format(index))
			local across = hammer.axis:Cross(Vector3.new(0, 1, 0))
			widest = math.max(widest, math.abs((posed.Position - hammer.pivot):Dot(across)))
		end
	end
	assert(widest > 20, "the head barely moves")
	assert(math.abs(Motion.AngleAt(phase, -5) - Motion.AngleAt(phase, 0)) < 1e-9, "time before the epoch must hold the start pose")
end
assert(Motion.Transform(Vector3.new(3, 4, 5), Vector3.new(0, 0, 1), 0).Position.Magnitude < 1e-6, "zero angle must be the identity")
pass("swing: rigid about the pivot, within 55 degrees, across the path, above the floor, 5 s sampled")

-- 4. One formula, no server writes.
do
	local server = fs.readFile(SERVER)
	local a = assert(server:find("local function updateHammers", 1, true))
	local b = assert(server:find("local function updateLasers", a, true))
	local body = server:sub(a, b - 1)
	assert(body:find("HammerMotion.Transform", 1, true) and body:find("HammerMotion.AngleAt", 1, true), "the server must use the shared formula")
	assert(not body:find("setPartsFromWorldTransform", 1, true) and not body:find(".CFrame =", 1, true), "the server still writes hammer parts")
	assert(not body:find(":Play()", 1, true), "the whoosh is the client's now (a server Play replicates to everyone)")
	assert(server:find("CollectionService:AddTag(hammerObject, HammerMotion.Tag)", 1, true))
	assert(server:find("HammerMotion.SwingAxis(movingParts, shaftPart", 1, true), "the server must take the axis from the head")
	local client = fs.readFile(CLIENT)
	for _, needed in { "Motion.Transform", "Motion.AngleAt", "Motion.Tier", "BulkMoveTo", "GetServerTimeNow", "GetInstanceAddedSignal(Motion.Tag)", "DescendantRemoving" } do
		assert(client:find(needed, 1, true), "client lost " .. needed)
	end
	assert(not client:find("FireServer", 1, true), "moving hammers must not talk to the server")
	pass("server keeps a virtual pose with the shared formula and writes no hammer part; client moves them in one BulkMoveTo")
end

-- 5. The box test.
do
	local unit = Vector3.new(4, 4, 4)
	assert(Motion.BoxesOverlap(CFrame.new(0, 0, 0), unit, CFrame.new(3, 0, 0), unit))
	assert(not Motion.BoxesOverlap(CFrame.new(0, 0, 0), unit, CFrame.new(4.1, 0, 0), unit))
	assert(Motion.BoxesOverlap(CFrame.new(0, 0, 0), unit, CFrame.new(3.5, 0, 0), unit))
	assert(not Motion.BoxesOverlap(CFrame.new(0, 0, 0), unit, CFrame.new(3.5, 0, 0), unit, 0.6), "shrink must pull the faces in")
	local turned = CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(45), 0)
	assert(Motion.BoxesOverlap(turned, unit, CFrame.new(4.6, 0, 0), unit), "a turned box reaches further along its diagonal")
	assert(not Motion.BoxesOverlap(turned, unit, CFrame.new(4.6, 0, 4.6), unit), "corner to corner must not count")
	assert(not Motion.BoxesOverlap(CFrame.new(0, 0, 0), Vector3.new(1, 1, 1), CFrame.new(0, 0, 0), unit, 0.6), "a box shrunk to nothing touches nothing")
	-- A runner standing under Hammer1's head at the bottom of the swing is inside it; one 30 studs down the path is not.
	local hammer = hammers[1]
	local head
	for _, part in hammer.moving do
		if part ~= hammer.shaft and (not head or part.Size.Z > head.Size.Z) then head = part end
	end
	local body = Vector3.new(2, 2, 1)
	local hit = CFrame.new(head.CFrame.Position)
	assert(Motion.BoxesOverlap(head.CFrame, head.Size, hit, body, 0.6))
	assert(not Motion.BoxesOverlap(head.CFrame, head.Size, hit + hammer.axis * 30, body, 0.6))
	pass("box test: aligned, turned, shrunk, and a runner inside / beside a real hammer head")
end

-- 6. Tiers and the dormancy gate.
do
	assert(Motion.Tier(0) == "near" and Motion.Tier(Motion.NearRadius) == "near")
	assert(Motion.Tier(Motion.NearRadius + 1) == "mid" and Motion.Tier(Motion.MidRadius + 1) == "far")
	assert(Motion.MidFrameSkip >= 2 and Motion.NearRadius >= 200, "near must cover what a runner can reach in a few seconds")
	local server = fs.readFile(SERVER)
	local a = assert(server:find("local ACTIVE_RADIUS", 1, true))
	local b = assert(server:find("local function objectDepth", a, true))
	local roots = {}
	local env = { math = math, table = table, ipairs = ipairs, pairs = pairs, Vector3 = Vector3,
		Players = { GetPlayers = function()
			local list = {}
			for _, position in roots do
				table.insert(list, { Character = { FindFirstChild = function() return { Position = position, IsA = function() return true end } end } })
			end
			return list
		end } }
	local gate = luau.load(server:sub(a, b - 1) .. "\nreturn { write = setPartsFromWorldTransform, refresh = refreshRecordActivity, radius = ACTIVE_RADIUS }", { environment = env })()
	local writes = 0
	local part = setmetatable({ Parent = true }, { __newindex = function(_, key) if key == "CFrame" then writes += 1 end end })
	local record = { BoundsCFrame = CFrame.new(0, 0, 0), OriginCFrames = { [part] = CFrame.new(0, 0, 0) }, Radius = 10, CurrentCenter = Vector3.new(0, 0, 0) }
	-- An obstacle that travels 0..600 along X, runner far away: learns its range, writes nothing once dormant.
	roots = { Vector3.new(0, 0, 5000) }
	gate.write(record, CFrame.new(0, 0, 0))
	gate.refresh({ record })
	assert(record.Dormant == true, "nobody near: dormant")
	local before = writes
	for x = 0, 600, 50 do gate.write(record, CFrame.new(x, 0, 0)) end
	assert(writes == before, "a dormant obstacle wrote its parts")
	assert(record.CurrentCenter.X == 600 and record.TravelMax.X == 600 and record.TravelMin.X == 0, "the pose must keep being tracked while dormant")
	-- A runner beside where it USED to be (its parts are frozen there) wakes it.
	roots = { Vector3.new(0, 0, 100) }
	gate.refresh({ record })
	assert(record.Dormant == false, "a runner beside the frozen parts must wake it")
	gate.write(record, CFrame.new(600, 0, 0))
	assert(writes == before + 1, "an active obstacle must write")
	-- Just out of reach of the whole travel box: dormant again.
	roots = { Vector3.new(600 + record.Radius + gate.radius + 5, 0, 0) }
	gate.refresh({ record })
	assert(record.Dormant == true)
	roots = { Vector3.new(600 + record.Radius + gate.radius - 5, 0, 0) }
	gate.refresh({ record })
	assert(record.Dormant == false)
	roots = {}
	gate.refresh({ record })
	assert(record.Dormant == true, "an empty server moves nothing")
	pass("tiers near/mid/far; other obstacles: no writes while nobody is near their whole travel range, wake on approach")
end

-- 7. The place.
if process.args[1] == "places" then
	local manifest = serde.decode("json", fs.readFile("src/manifest.json"))
	for _, source in { MODULE, SERVER, CLIENT } do
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
	for index, hammer in hammers do
		assert(tostring(hammer.model.ModelStreamingMode):find("Atomic"), "Hammer" .. index .. " does not stream in whole")
	end
	for _, other in { "World2Update3new.rbxl", "World3Update3New.rbxl" } do
		local place = rb.deserializePlace(fs.readFile(other))
		assert(not place:GetService("ReplicatedStorage").Shared:FindFirstChild("World1HammerMotion"), other .. " must not carry World 1's module")
	end
	pass("World 1 place carries the three scripts and Atomic hammers; Worlds 2 and 3 untouched")
end

print(("ALL PASSED (%d groups)"):format(passed))
