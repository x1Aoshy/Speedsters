-- test_u4_race_walls.luau (Update 4, 2026-09-26, owner: "racers brushing the invisible side walls
-- at high speed lose momentum and stop"). Every race boundary a racer can touch is frictionless
-- (PhysicalProperties.new(0.7, 0, 0, 100, 100): RaceArenaBuilder.WallPhysics) and the floor keeps
-- its own friction:
--   1. the classifier (RaceArenaBuilder.NameWords / IsWallPart): walls, barriers, caps, lips,
--      curbs, rails, fences, colliders and the StartGate are boundaries; floors, pads, spikes,
--      Trail / Tulip-like names are not;
--   2. the fallback arena (RaceArenaBuilder.Build): side walls, StartGate, back and end walls
--      (and every other boundary) carry WallPhysics and RaceWall; no floor slab does; without
--      PhysicalProperties in env it still builds;
--   3. the Green Hill arena (audit/u4_greenhill_arena, what `--greenhill` puts in the places):
--      Barriers, end caps, bank lips, Astra's 220 short Walls, the StartGate and the kit's fence
--      sections carry WallPhysics, every other collidable part at the track's edges is one of
--      them, TrackFloor / SpeedPads / Spikes keep theirs; the physics survive serialization;
--   4. at runtime (Gameplay/RaceServer's frictionlessWalls, run on the arena the places carry
--      today, which predates this change, or on a stripped copy when no place is here): every
--      wall ends up frictionless, the floor does not; publishProfile runs it on every arena load
--      and builderEnv hands it PhysicalProperties;
--   5. the contact a racer's body makes (Movement/InstantMovementController's BODY_PHYSICS)
--      with a wall now has half the body's own friction; with the floor, the body's.
-- Run: lune run audit/test_u4_race_walls.luau   (from the project root; reads, never writes, the places)
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local U4 = require("../src/common/ReplicatedStorage/Shared/Update4Config")
local RaceArenaBuilder = require("../src/common/ServerScriptService/Services/Race/RaceArenaBuilder")
local GreenHill = require("./u4_greenhill_arena")

local Instance = roblox.Instance
local ORIGIN = U4.Race.Arena.Origin
local ENV = {
	Instance = roblox.Instance, Vector3 = roblox.Vector3, CFrame = roblox.CFrame, Color3 = roblox.Color3,
	Enum = roblox.Enum, UDim2 = roblox.UDim2, NumberRange = roblox.NumberRange, PhysicalProperties = roblox.PhysicalProperties,
	Font = roblox.Font, ColorSequence = roblox.ColorSequence, -- as build_update4 hands it (labels through FontFace)
}

local passed = 0
local function pass(text)
	passed += 1
	print("PASS " .. text)
end

local function near(a, b, eps)
	return math.abs(a - b) <= (eps or 1e-4)
end

local function baseParts(root)
	local list = {}
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(list, d)
		end
	end
	return list
end

-- The top-level child of `arena` holding `part`.
local function topOf(part, arena)
	local node = part
	while node.Parent and node.Parent ~= arena do
		node = node.Parent
	end
	return node
end

----------------------------------------------------------------------
-- 1. The classifier
----------------------------------------------------------------------
do
	local w = RaceArenaBuilder.WallPhysics
	assert(w.Density == 0.7 and w.Friction == 0 and w.Elasticity == 0 and w.FrictionWeight == 100 and w.ElasticityWeight == 100,
		"WallPhysics is the owner's PhysicalProperties.new(0.7, 0, 0, 100, 100)")
	local physics = RaceArenaBuilder.WallPhysicalProperties(ENV)
	assert(physics and near(physics.Density, 0.7) and physics.Friction == 0 and physics.Elasticity == 0
		and physics.FrictionWeight == 100 and physics.ElasticityWeight == 100, "WallPhysicalProperties builds them")
	assert(RaceArenaBuilder.WallPhysicalProperties({}) == nil, "no PhysicalProperties in env (Lune without it): nil, no error")

	local words = RaceArenaBuilder.NameWords("RaceTrackBarrier__Base")
	assert(table.concat(words, ",") == "race,track,barrier,base", "NameWords splits CamelCase and underscores: " .. table.concat(words, ","))
	assert(table.concat(RaceArenaBuilder.NameWords("BankLip_12"), ",") == "bank,lip", "BankLip_12")
	assert(table.concat(RaceArenaBuilder.NameWords("Wall_3_-1"), ",") == "wall", "Wall_3_-1")

	local arena = Instance.new("Model")
	arena.Name = "RaceArena"
	local function folder(name, parent)
		local f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
		return f
	end
	local function part(name, parent)
		local p = Instance.new("Part")
		p.Name = name
		p.Parent = parent
		return p
	end
	local structure = folder("Structure", arena)
	local decor = folder("Decor", arena)
	local floor = folder("TrackFloor", arena)
	local pads = folder("SpeedPads", arena)
	local spikes = folder("Spikes", arena)
	local walls = folder("Walls", arena)
	local barriers = folder("Barriers", arena)
	local banks = folder("Banks", arena)
	local yes = {
		part("WallL_1", structure), part("WallR_9", structure), part("BackWall", structure), part("EndWall", structure),
		part("StartGate", structure), part("BackCap", barriers), part("EndCap", barriers), part("Wall_4_-1", walls),
		part("Anything", barriers), part("BankLip_3", banks), part("Curb", decor), part("CurbGlow", decor),
		part("PadRail", decor), part("FenceRail1_2", decor), part("FencePost", decor), part("Kit_FenceSection", decor),
		part("Collider_Arch", decor), part("RaceTrackBarrier__Accent", decor), part("BarrierPostL", decor), part("GuardRail", decor),
	}
	local marked = part("Rock", decor)
	marked:SetAttribute("RaceWall", true)
	table.insert(yes, marked)
	local no = {
		part("Floor_12", floor), part("StagingFloor", structure), part("Floor_3", structure), part("SpeedPad", pads),
		part("SpikeTile_1_1_1", spikes), part("TileStar", spikes), part("Trail", decor), part("Kit_Tulip", decor),
		part("StopBar", structure), part("Light1", structure), part("Kit_PalmA", decor), part("Verge_3", decor),
		part("BankCliff_2", decor), part("StartLine", decor), part("FinishLine", decor), part("Capsule", decor),
		part("WallFloor", barriers), -- a floor under a wall container is still a floor
	}
	local lip = part("BankLip_9", folder("Deep", banks))
	table.insert(yes, lip)
	for _, p in yes do
		assert(RaceArenaBuilder.IsWallPart(p, arena), p:GetFullName() .. " is a race boundary")
	end
	for _, p in no do
		assert(not RaceArenaBuilder.IsWallPart(p, arena), p:GetFullName() .. " is not a race boundary")
	end
	local count = RaceArenaBuilder.ApplyWallPhysics(arena, ENV)
	assert(count == #yes, string.format("ApplyWallPhysics touched %d parts, want %d", count, #yes))
	for _, p in yes do
		assert(RaceArenaBuilder.HasWallPhysics(p) and p:GetAttribute("RaceWall") == true, p.Name .. ": frictionless and RaceWall")
	end
	for _, p in no do
		assert(p.CustomPhysicalProperties == nil and p:GetAttribute("RaceWall") == nil, p.Name .. ": untouched")
	end
	assert(RaceArenaBuilder.ApplyWallPhysics(arena, ENV) == #yes, "idempotent")
	assert(RaceArenaBuilder.ApplyWallPhysics(arena, {}) == 0, "without PhysicalProperties nothing is touched")
	assert(RaceArenaBuilder.ApplyWallPhysics(nil, ENV) == 0, "no arena: 0")
	pass(string.format("classifier: %d boundaries (walls, caps, lips, curbs, rails, fences, colliders, StartGate, RaceWall) frictionless; %d floors / pads / spikes / decor untouched",
		#yes, #no))
end

----------------------------------------------------------------------
-- 2. The fallback arena (RaceArenaBuilder.Build)
----------------------------------------------------------------------
do
	local arena = RaceArenaBuilder.Build(Instance.new("Folder"), ENV)
	local structure = arena:FindFirstChild("Structure")
	local walls, floors = 0, 0
	for _, p in baseParts(structure) do
		local words = RaceArenaBuilder.NameWords(p.Name)
		if string.match(p.Name, "^Wall[LR]_%d+$") or p.Name == "StartGate" or p.Name == "BackWall" or p.Name == "EndWall" then
			walls += 1
			assert(RaceArenaBuilder.HasWallPhysics(p) and p:GetAttribute("RaceWall") == true, p.Name .. ": frictionless race wall")
			assert(p.CanCollide, p.Name .. " collides")
		elseif table.find(words, "floor") then
			floors += 1
			assert(p.CustomPhysicalProperties == nil and p:GetAttribute("RaceWall") == nil, p.Name .. ": the floor keeps its friction")
		end
	end
	assert(walls >= 2 * #RaceArenaBuilder.WallSegments() + 3, "every side wall segment, the StartGate and the back / end walls")
	assert(floors == #RaceArenaBuilder.FloorSegments(), "every floor slab checked")
	for _, p in baseParts(arena) do
		if p.CanCollide and not table.find(RaceArenaBuilder.NameWords(p.Name), "floor") then
			assert(RaceArenaBuilder.HasWallPhysics(p), "a collidable non-floor part of the fallback arena keeps its friction: " .. p:GetFullName())
		end
		if RaceArenaBuilder.IsWallPart(p, arena) then
			assert(RaceArenaBuilder.HasWallPhysics(p), p:GetFullName() .. ": every boundary")
		end
	end
	for _, p in baseParts(arena:FindFirstChild("SpeedPads")) do
		assert(p.CustomPhysicalProperties == nil, "speed pads keep theirs")
	end
	-- Serialized as the build writes it.
	local back = roblox.deserializeModel(roblox.serializeModel({ arena }))[1]
	local wall = back.Structure:FindFirstChild("WallL_1")
	assert(wall and RaceArenaBuilder.HasWallPhysics(wall), "the physics survive serialization (the places carry them)")
	-- An env without PhysicalProperties (an older caller) still builds, walls marked.
	local plain = table.clone(ENV)
	plain.PhysicalProperties = nil
	local bare = RaceArenaBuilder.Build(Instance.new("Folder"), plain)
	assert(bare.Structure.WallL_1:GetAttribute("RaceWall") == true and bare.Structure.WallL_1.CustomPhysicalProperties == nil,
		"without PhysicalProperties: RaceWall marked, physics left to RaceServer")
	pass(string.format("fallback arena: %d walls / gate / caps frictionless and RaceWall, %d floor slabs untouched, pads untouched, serialized", walls, floors))
end

----------------------------------------------------------------------
-- 3. The Green Hill arena (--greenhill)
----------------------------------------------------------------------
local greenHill, report = GreenHill.Build()
do
	local problems = GreenHill.WallPhysicsProblems(greenHill)
	assert(#problems == 0, "GreenHill.WallPhysicsProblems: " .. table.concat(problems, "; "))
	assert(#GreenHill.Verify(greenHill) == 0, "GreenHill.Verify still passes: " .. table.concat(GreenHill.Verify(greenHill), "; "))
	local byTop = {}
	local fences = 0
	for _, p in baseParts(greenHill) do
		local top = topOf(p, greenHill).Name
		if RaceArenaBuilder.HasWallPhysics(p) then
			byTop[top] = (byTop[top] or 0) + 1
			if table.find(RaceArenaBuilder.NameWords(p.Name), "fence") then
				fences += 1
			end
		end
		if top == "TrackFloor" or top == "SpeedPads" or top == "Spikes" then
			assert(p.CustomPhysicalProperties == nil, top .. "." .. p.Name .. ": keeps its own friction")
		end
	end
	local barriers = #baseParts(greenHill.Barriers)
	assert(byTop.Barriers == barriers and barriers >= 4, "every barrier (side walls, BackCap, EndCap)")
	assert(greenHill.Barriers:FindFirstChild("BackCap") and RaceArenaBuilder.HasWallPhysics(greenHill.Barriers.BackCap)
		and RaceArenaBuilder.HasWallPhysics(greenHill.Barriers.EndCap), "the end caps")
	assert(byTop.Banks == #baseParts(greenHill.Banks), "every bank lip")
	assert(byTop.Walls == #baseParts(greenHill.Walls) and byTop.Walls >= 200, "Astra's short invisible Walls (" .. tostring(byTop.Walls) .. ")")
	assert(RaceArenaBuilder.HasWallPhysics(greenHill.Structure.StartGate), "the StartGate collider")
	assert(fences > 0, "the fences")
	-- Every collidable part of the arena is the floor or a frictionless boundary.
	local collidable = 0
	for _, p in baseParts(greenHill) do
		if p.CanCollide then
			collidable += 1
			local top = topOf(p, greenHill).Name
			assert(top == "TrackFloor" or RaceArenaBuilder.HasWallPhysics(p), "a collidable part keeps its friction: " .. p:GetFullName())
		end
	end
	assert(report.wallParts and report.wallParts > 0, "the build reports its walls")
	local back = roblox.deserializeModel(roblox.serializeModel({ greenHill }))[1]
	assert(#GreenHill.WallPhysicsProblems(back) == 0, "the physics survive serialization (the places carry them)")
	local order = {}
	for name, n in byTop do
		table.insert(order, name .. " " .. n)
	end
	table.sort(order)
	pass(string.format("Green Hill: %d frictionless parts (%s; %d fence pieces); %d collidable parts are the floor or a boundary; floor, pads, spikes keep theirs; serialized",
		report.wallParts, table.concat(order, ", "), fences, collidable))
end

----------------------------------------------------------------------
-- 4. At runtime (Gameplay/RaceServer)
----------------------------------------------------------------------
do
	local server = fs.readFile("src/common/ServerScriptService/Gameplay/RaceServer.server.luau")
	assert(string.find(server, "\tPhysicalProperties = PhysicalProperties,\n}", 1, true), "builderEnv hands the builder PhysicalProperties")
	assert(string.find(server, "local function publishProfile()\n\tcloseIdleStartGate()\n\tfrictionlessWalls()", 1, true),
		"publishProfile (the arena at start and every new Workspace.RaceArena) makes the walls frictionless first")
	local first = assert(string.find(server, "local function frictionlessWalls()", 1, true))
	local last = assert(string.find(server, "\nend\n", first, true))
	local chunk = string.sub(server, first, last + 4) .. "\nreturn frictionlessWalls"

	-- The arena the places carry today (built before this change), else a stripped Green Hill.
	local arena, source = nil, nil
	for _, file in { "World1Update3New.rbxl", "World2Update3new.rbxl", "World3Update3New.rbxl" } do
		if arena == nil and fs.isFile(file) then
			local ok, dm = pcall(roblox.deserializePlace, fs.readFile(file))
			local found = ok and dm:GetService("Workspace"):FindFirstChild("RaceArena")
			if found then
				arena, source = found, file
			end
		end
	end
	if arena == nil then
		arena = GreenHill.Build()
		for _, p in baseParts(arena) do
			p.CustomPhysicalProperties = nil
			p:SetAttribute("RaceWall", nil)
		end
		source = "a stripped Green Hill build"
	end
	local before = 0
	for _, p in baseParts(arena) do
		if RaceArenaBuilder.IsWallPart(p, arena) and not RaceArenaBuilder.HasWallPhysics(p) then
			before += 1
		end
	end
	local floorBefore = {}
	for _, p in baseParts(arena) do
		if topOf(p, arena).Name == "TrackFloor" then
			floorBefore[p] = p.CustomPhysicalProperties
		end
	end

	local printed = {}
	local env = {
		Workspace = { FindFirstChild = function(_, name)
			return if name == "RaceArena" then arena else nil
		end },
		RaceArenaBuilder = RaceArenaBuilder,
		builderEnv = { PhysicalProperties = roblox.PhysicalProperties },
		pcall = pcall,
		tostring = tostring,
		string = string,
		print = function(text)
			table.insert(printed, text)
		end,
		warn = function(text)
			error("frictionlessWalls warned: " .. tostring(text))
		end,
	}
	local frictionlessWalls = luau.load(chunk, { environment = env, debugName = "RaceServer.frictionlessWalls" })()
	frictionlessWalls()
	assert(string.find(printed[1] or "", "race walls frictionless", 1, true), "it logs how many walls it made frictionless")

	local walls, collidable = 0, 0
	for _, p in baseParts(arena) do
		local top = topOf(p, arena).Name
		if RaceArenaBuilder.IsWallPart(p, arena) then
			walls += 1
			assert(RaceArenaBuilder.HasWallPhysics(p), p:GetFullName() .. " is frictionless at runtime")
		end
		if p.CanCollide then
			collidable += 1
			assert(top == "TrackFloor" or RaceArenaBuilder.HasWallPhysics(p), "at runtime a collidable part keeps its friction: " .. p:GetFullName())
		end
		if top == "TrackFloor" then
			assert(p.CustomPhysicalProperties == floorBefore[p], p.Name .. ": the floor's physics are left alone")
		end
	end
	if arena:GetAttribute("RaceArenaStyle") == "GreenHill" then
		assert(#GreenHill.WallPhysicsProblems(arena) == 0, "WallPhysicsProblems after the runtime pass: " .. table.concat(GreenHill.WallPhysicsProblems(arena), "; "))
	end
	-- No arena (a place without one): nothing happens, no error.
	env.Workspace = { FindFirstChild = function()
		return nil
	end }
	luau.load(chunk, { environment = env })()()
	pass(string.format("runtime (RaceServer.frictionlessWalls on %s): %d walls (%d had friction before), all %d collidable parts the floor or frictionless; the floor untouched",
		source, walls, before, collidable))
end

----------------------------------------------------------------------
-- 5. What the racer's body feels (Roblox combines frictions by their weights)
----------------------------------------------------------------------
do
	local controller = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/Movement/InstantMovementController.client.luau")
	local bodyFriction = tonumber(string.match(controller, "local BODY_FRICTION = ([%d%.]+)"))
	local bodyWeight = tonumber(string.match(controller, "PhysicalProperties%.new%(0%.7, BODY_FRICTION, 0, (%d+), %d+%)"))
	assert(bodyFriction and bodyWeight, "InstantMovementController's BODY_PHYSICS")
	local function combined(f1, w1, f2, w2)
		return (f1 * w1 + f2 * w2) / (w1 + w2)
	end
	local w = RaceArenaBuilder.WallPhysics
	local wall = combined(bodyFriction, bodyWeight, w.Friction, w.FrictionWeight)
	local oldWall = combined(bodyFriction, bodyWeight, 0.3, 1) -- a plastic wall's default (friction 0.3, weight 1)
	assert(wall <= bodyFriction * 0.5 + 1e-9 and wall < oldWall, string.format("body vs wall: %.3f (was %.3f)", wall, oldWall))
	pass(string.format("a racer's body against a wall: friction %.3f (was %.3f with the default wall); the floor keeps its own", wall, oldWall))
end

print(string.format("test_u4_race_walls: %d checks passed", passed))
