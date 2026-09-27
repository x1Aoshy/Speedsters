-- test_u4_race_arena.luau (Update 4, race_server, 2026-09-25)
-- Services/Race/RaceArenaBuilder (PLAN §3.5 / §7.3 item 10), built in plain Lune with
-- @lune/roblox (as the build does):
--   part budget (<= 600 with part chevrons, <= 330 with a chevron texture); every part Anchored,
--   CastShadow off, RaceArenaPart; decor never collides, touches or queries; Structure and the
--   ORB Persistent, decor chunks Atomic; floor top at Origin.Y +- 0.02 and continuous; side
--   walls continuous from the back wall to the end wall; the named parts the client animates;
--   spike tiles where RaceTrack says; chevrons tagged RaceDecorLowPower; the three gates.
-- `places` (lune run audit/test_u4_race_arena.luau places): reads the three .rbxl files (never
-- writes them). Workspace.RaceArena must be present (after the build) and >= 1500 studs from
-- every other BasePart. Before the build, `places prebuild` builds the arena in memory in each
-- place instead and checks the same distance against the real maps.
-- 2026-09-25 (race art): ENV carries no RaceAssets, so this is the part-geometry path; the
-- Blender meshes path (same contracts) is audit/test_u4_race_assets.luau.
-- Run: lune run audit/test_u4_race_arena.luau [places [prebuild]]   (from the project root)
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local U4 = require("../src/common/ReplicatedStorage/Shared/Update4Config")
local RaceTrack = require("../src/common/ReplicatedStorage/Shared/RaceTrack")
local RaceArenaBuilder = require("../src/common/ServerScriptService/Services/Race/RaceArenaBuilder")

local ENV = {
	Instance = roblox.Instance, Vector3 = roblox.Vector3, CFrame = roblox.CFrame, Color3 = roblox.Color3,
	Enum = roblox.Enum, UDim2 = roblox.UDim2, NumberRange = roblox.NumberRange,
}
local ORIGIN = U4.Race.Arena.Origin
local TRACK = U4.Race.Track
local PLACES = { World1 = "World1Update3New.rbxl", World2 = "World2Update3new.rbxl", World3 = "World3Update3New.rbxl" }

local passed = 0
local function pass(text)
	passed += 1
	print("PASS " .. text)
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

local function build()
	local folder = roblox.Instance.new("Folder")
	return RaceArenaBuilder.Build(folder, ENV)
end

----------------------------------------------------------------------
-- Pure build
----------------------------------------------------------------------
local arena = build()
do
	local parts = baseParts(arena)
	assert(#parts <= RaceArenaBuilder.BudgetWithParts, "part budget with part chevrons (" .. #parts .. ")")
	assert(arena:GetAttribute("RaceArenaParts") == #parts, "part count attribute")
	local saved = U4.Race.Art.ChevronTexture
	U4.Race.Art.ChevronTexture = "rbxassetid://1"
	local textured = build()
	U4.Race.Art.ChevronTexture = saved
	local texturedParts = baseParts(textured)
	assert(#texturedParts <= RaceArenaBuilder.BudgetWithTexture, "part budget with a chevron texture (" .. #texturedParts .. ")")
	local chevronTextures = 0
	for _, d in textured:GetDescendants() do
		if d:IsA("Texture") and d.Name == "Chevrons" then
			chevronTextures += 1
		end
	end
	assert(chevronTextures > 0, "the chevron texture is used when set")
	pass(string.format("budget: %d parts with part chevrons (<= %d), %d with the texture (<= %d)", #parts, RaceArenaBuilder.BudgetWithParts,
		#texturedParts, RaceArenaBuilder.BudgetWithTexture))
end

do
	local structure = assert(arena:FindFirstChild("Structure"), "Structure")
	local decor = assert(arena:FindFirstChild("Decor"), "Decor")
	local orb = assert(arena:FindFirstChild("RaceOrb"), "RaceOrb")
	assert(arena:GetAttribute("RaceArenaVersion") == 1, "RaceArenaVersion = 1")
	assert(structure.ModelStreamingMode == roblox.Enum.ModelStreamingMode.Persistent, "Structure Persistent")
	assert(orb.ModelStreamingMode == roblox.Enum.ModelStreamingMode.Persistent, "ORB Persistent")
	local chunks = 0
	for _, chunk in decor:GetChildren() do
		assert(chunk:IsA("Model") and string.match(chunk.Name, "^Chunk_%d+$"), "decor holds Chunk_k models")
		assert(chunk.ModelStreamingMode == roblox.Enum.ModelStreamingMode.Atomic, "decor chunks Atomic")
		chunks += 1
	end
	assert(chunks == RaceArenaBuilder.ChunkCount(), "one chunk per 240 studs")
	for _, part in baseParts(arena) do
		assert(part.Anchored == true and part.CastShadow == false, "Anchored, no shadow: " .. part:GetFullName())
		assert(part:GetAttribute("RaceArenaPart") == true, "RaceArenaPart: " .. part:GetFullName())
		if part:IsDescendantOf(decor) or part:IsDescendantOf(orb) then
			assert(not part.CanCollide and not part.CanTouch and not part.CanQuery, "decor: no collide/touch/query " .. part:GetFullName())
		end
		local s, x, y = RaceTrack.ToLocal(part.CFrame.Position)
		assert(math.abs(x) <= 44 and s >= -70 and s <= TRACK.Length + TRACK.RunOut + 5 and y >= -3 and y <= 60, "inside the arena box: " .. part:GetFullName())
	end
	pass("Structure/ORB Persistent, decor chunks Atomic; every part Anchored, no shadow, RaceArenaPart; decor inert")
end

do
	local structure = arena.Structure
	-- Floor: top at Origin.Y, continuous from the staging box to the end wall.
	local floors = {}
	for _, part in structure:GetChildren() do
		if part:IsA("BasePart") and (part.Name == "StagingFloor" or string.match(part.Name, "^Floor_%d+$")) then
			local top = part.CFrame.Position.Y + part.Size.Y * 0.5
			assert(math.abs(top - ORIGIN.Y) <= 0.02, string.format("floor top at Origin.Y (%s %.4f)", part.Name, top - ORIGIN.Y))
			assert(part.CanCollide and math.abs(part.Size.X - TRACK.Width) < 1e-3, "floor collides, 72 wide")
			local s = RaceTrack.ToLocal(part.CFrame.Position)
			table.insert(floors, { s0 = s - part.Size.Z * 0.5, s1 = s + part.Size.Z * 0.5 })
			assert(part:FindFirstChild("Studs") and part.Studs:IsA("Texture"), "stud texture on " .. part.Name)
		end
	end
	table.sort(floors, function(a, b)
		return a.s0 < b.s0
	end)
	assert(math.abs(floors[1].s0 - RaceArenaBuilder.StartS) < 0.01 and math.abs(floors[#floors].s1 - RaceArenaBuilder.EndWallS) < 0.01, "floor from -64 to 2120")
	for i = 2, #floors do
		assert(math.abs(floors[i].s0 - floors[i - 1].s1) < 0.01, "floor continuous at s " .. floors[i].s0)
	end
	-- Walls: both sides continuous, at x +-38.1, 16 tall, invisible, colliding.
	for _, side in { "L", "R" } do
		local walls = {}
		for _, part in structure:GetChildren() do
			if string.match(part.Name, "^Wall" .. side .. "_%d+$") then
				local s, x, y = RaceTrack.ToLocal(part.CFrame.Position)
				assert(math.abs(math.abs(x) - RaceArenaBuilder.WallX) < 0.01 and part.Transparency == 1 and part.CanCollide, "wall " .. part.Name)
				assert(math.abs(y - part.Size.Y * 0.5) < 0.02 and part.Size.Y >= 16, "wall stands on the floor, 16 tall")
				table.insert(walls, { s0 = s - part.Size.Z * 0.5, s1 = s + part.Size.Z * 0.5 })
			end
		end
		table.sort(walls, function(a, b)
			return a.s0 < b.s0
		end)
		assert(#walls > 0 and math.abs(walls[1].s0 - RaceArenaBuilder.StartS) < 0.01 and math.abs(walls[#walls].s1 - RaceArenaBuilder.EndWallS) < 0.01, "wall " .. side .. " spans -64..2120")
		for i = 2, #walls do
			assert(math.abs(walls[i].s0 - walls[i - 1].s1) < 0.01, "wall " .. side .. " continuous")
		end
	end
	-- Named parts the client and the service use.
	local gate = structure:FindFirstChild("StartGate")
	assert(gate and gate.CanCollide and gate.Transparency == 1, "StartGate collider")
	local gs = RaceTrack.ToLocal(gate.CFrame.Position)
	assert(math.abs(gs - 1.5) < 0.01 and gate.Size.X >= TRACK.Width, "StartGate at s 1.5 across the track")
	local stop = structure:FindFirstChild("StopBar")
	assert(stop and not stop.CanCollide and stop:FindFirstChildWhichIsA("SurfaceGui"), "StopBar with its STOP signs")
	for light = 1, 5 do
		assert(structure.StartGantry:FindFirstChild("Light" .. light), "StartGantry.Light" .. light)
	end
	assert(structure:FindFirstChild("BackWall") and structure:FindFirstChild("EndWall"), "back and end walls")
	local core = arena.RaceOrb:FindFirstChild("Core")
	local os_, _, oy = RaceTrack.ToLocal(core.CFrame.Position)
	assert(math.abs(os_ - TRACK.OrbS) < 0.01 and math.abs(oy - TRACK.OrbY) < 0.02, "ORB at s 2060, y 34")
	assert(core:FindFirstChild("OrbMarker") and core:FindFirstChildWhichIsA("PointLight") and core:FindFirstChildWhichIsA("ParticleEmitter"), "ORB light, sparks, marker")
	pass("floor top at Origin.Y and continuous; walls continuous at x +-38.1; StartGate, StopBar, Light1..5, ORB")
end

do
	-- Spike tiles exactly where RaceTrack puts them; chevrons tagged for phones.
	local expected = {}
	for _, tile in RaceTrack.SpikeTiles() do
		expected[string.format("%d:%d", tile.s, tile.lane)] = tile
	end
	local found, chevrons = 0, 0
	for _, part in baseParts(arena.Decor) do
		if part:GetAttribute("RaceSpikeTile") == true then
			local s, x, y = RaceTrack.ToLocal(part.CFrame.Position)
			local tile = expected[string.format("%d:%d", math.floor(s + 0.5), part:GetAttribute("Lane"))]
			assert(tile and math.abs(tile.x - x) < 0.01 and math.abs(y - TRACK.SpikeTileHeight * 0.5) < 0.02, "spike tile where RaceTrack says")
			assert(math.abs(part.Size.X - TRACK.SpikeTile) < 1e-3 and math.abs(part.Size.Y - TRACK.SpikeTileHeight) < 1e-3, "spike tile 7 x 0.4 x 7")
			found += 1
		elseif part.Name == "Chevron" then
			assert(part:HasTag("RaceDecorLowPower"), "part chevrons are tagged RaceDecorLowPower")
			chevrons += 1
		end
	end
	assert(found == #RaceTrack.SpikeTiles(), "every spike tile built (" .. found .. ")")
	assert(chevrons > 0, "part chevrons without a texture")
	-- Distance gantries and the finish.
	local names = {}
	for _, d in arena.Decor:GetDescendants() do
		names[d.Name] = true
	end
	for _, s in TRACK.Gantries do
		assert(names["Gantry_" .. s], "gantry at " .. s)
	end
	assert(names.LastStretch and names.FinishGate and names.FinishLine and names.Checker, "last-stretch gantry and the checkered finish")
	pass(string.format("%d spike tiles where RaceTrack says; %d part chevrons tagged RaceDecorLowPower; gantries and finish", found, chevrons))
end

do
	-- The three Race Gates: a 12 x 12 pad at the configured point, facing Face, with the sign.
	for world in PLACES do
		local folder = roblox.Instance.new("Folder")
		local gate = RaceArenaBuilder.BuildGate(folder, world, ENV)
		local placement = U4.Race.Gate[world]
		local pad = gate:FindFirstChild("RaceGatePad")
		assert(pad and math.abs(pad.Size.X - RaceArenaBuilder.GatePadSize) < 1e-3, world .. " pad")
		local flat = roblox.Vector3.new(pad.CFrame.Position.X - placement.Position.X, 0, pad.CFrame.Position.Z - placement.Position.Z)
		assert(flat.Magnitude < 0.01 and math.abs(pad.CFrame.Position.Y - pad.Size.Y * 0.5 - placement.Position.Y) < 0.02, world .. " pad on the configured point")
		local face = placement.Face - placement.Position
		face = roblox.Vector3.new(face.X, 0, face.Z).Unit
		assert(pad.CFrame.LookVector:Dot(face) > 0.999, world .. " gate faces Face")
		local sign = gate:FindFirstChild("RaceGateSign")
		assert(sign and sign:IsA("BillboardGui") and sign.Adornee and sign:FindFirstChild("Title") and sign:FindFirstChild("Status") and sign:FindFirstChild("Record"), world .. " RaceGateSign")
		for _, part in baseParts(gate) do
			assert(part.Anchored and not part.CastShadow, world .. " gate parts anchored, no shadow")
		end
		assert(not pad.CanCollide, world .. " the pad does not trip anyone")
	end
	-- Source rules: no CFrame.lookAt (wrong in Lune), no Position on attachments.
	local source = fs.readFile("src/common/ServerScriptService/Services/Race/RaceArenaBuilder.luau")
	assert(not string.find(source, "lookAt%s*%("), "no CFrame.lookAt call in the builder")
	pass("three Race Gates: pad on the configured point facing Face, RaceGateSign lines; no CFrame.lookAt")
end

----------------------------------------------------------------------
-- Places (read only)
----------------------------------------------------------------------
local mode = process.args[1]
if mode == "places" then
	local prebuild = process.args[2] == "prebuild"
	local function aabb(part)
		local cf, size = part.CFrame, part.Size
		local lo = { math.huge, math.huge, math.huge }
		local hi = { -math.huge, -math.huge, -math.huge }
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local p = cf * roblox.Vector3.new(sx * size.X / 2, sy * size.Y / 2, sz * size.Z / 2)
					lo[1], lo[2], lo[3] = math.min(lo[1], p.X), math.min(lo[2], p.Y), math.min(lo[3], p.Z)
					hi[1], hi[2], hi[3] = math.max(hi[1], p.X), math.max(hi[2], p.Y), math.max(hi[3], p.Z)
				end
			end
		end
		return lo, hi
	end
	local function boxDistance(aLo, aHi, bLo, bHi)
		local d = 0
		for axis = 1, 3 do
			local gap = math.max(bLo[axis] - aHi[axis], aLo[axis] - bHi[axis], 0)
			d += gap * gap
		end
		return math.sqrt(d)
	end
	for world, file in PLACES do
		local game = roblox.deserializePlace(fs.readFile(file))
		local workspace = game:GetService("Workspace")
		local placed = workspace:FindFirstChild("RaceArena")
		if not placed then
			assert(prebuild, world .. ": Workspace.RaceArena is missing (run the build, or `places prebuild` before it)")
			placed = RaceArenaBuilder.Build(workspace, ENV)
		end
		local lo = { math.huge, math.huge, math.huge }
		local hi = { -math.huge, -math.huge, -math.huge }
		for _, part in baseParts(placed) do
			local a, b = aabb(part)
			for axis = 1, 3 do
				lo[axis], hi[axis] = math.min(lo[axis], a[axis]), math.max(hi[axis], b[axis])
			end
		end
		local nearest, nearestName = math.huge, ""
		for _, part in workspace:GetDescendants() do
			if part:IsA("BasePart") and part.ClassName ~= "Terrain" and not part:IsDescendantOf(placed) then
				local a, b = aabb(part)
				local d = boxDistance(lo, hi, a, b)
				if d < nearest then
					nearest, nearestName = d, part:GetFullName()
				end
			end
		end
		assert(nearest >= 1500, string.format("%s: the arena is >= 1500 studs from every other part (%.0f, %s)", world, nearest, nearestName))
		print(string.format("  %s: arena %s, nearest other part %.0f studs (%s)", world, if prebuild and not workspace:FindFirstChild("RaceGate") then "built in memory" else "in the place", nearest, nearestName))
	end
	pass("places: the arena stands >= 1500 studs from every other part in all 3 places" .. (if prebuild then " (pre-build, in memory)" else ""))
end

print(string.format("test_u4_race_arena: %d checks passed", passed))
