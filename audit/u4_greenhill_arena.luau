-- audit/u4_greenhill_arena.luau (Update 4, 2026-09-26): Astra's straight Green Hill race map,
-- made ready for the places (used by audit/build_update4.luau `--greenhill`, checked by
-- audit/test_u4_greenhill.luau). Lune only (@lune/roblox); nothing here runs in Roblox.
--
-- Astra's RaceArena.rbxm (design/race/Astra_Recta/RaceArena.rbxm, pinned below) follows our
-- contract (design/race/CONTRATO_MAPA_ASTRA.md), but its look is meshes and textures from
-- rbxasset://raceastra_straight_20260925/..., files on Astra's own disk that no player online
-- will ever load. GreenHill.Build turns it into the arena the places carry:
--   1. KEEP every gameplay part exactly (name, class, CFrame, Size, collisions): TrackFloor,
--      Walls, Structure (StartGate, StopBar, StartGantry.Light1..5), SpeedPads, Spikes,
--      FinishGate (ConfettiSpot_1..4), RaceOrb. Folders the race needs on every device become
--      Persistent Models of the same name (TrackFloor, Structure, SpeedPads), every part
--      carries RaceArenaPart (the character scripts' "arena part" test), the spike tiles
--      RaceSpikeTile, and the StartGate is closed (CanCollide) at rest: the race server opens it
--      at GO. The floor keeps its geometry and gets the dirt look (Ground, warm ochre, the
--      lobby's grain texture, the kit's dirt texture when it has one).
--   2. REMOVE every instance that references rbxasset:// local content (Astra's 144 Visuals
--      meshes with their RacePalmWind / RaceDecorLowPower tags, the spike tiles' meshes) and the
--      parts that only carried such a mesh.
--   3. BARRIERS (Model Barriers, Persistent): invisible walls centred on x +-38.1 (the contract's
--      line), from under the water to WallClearance studs over the highest floor (the default
--      jump is 7.2 studs; 80 = the anti-cheat's CorridorYMax, so clearing one means leaving the
--      race), end caps behind the staging box and after the run-out. Invisible walls have CanQuery
--      off (it only counts while CanCollide is off in Roblox; the server's ground raycast already
--      looks through invisible parts). BANKS in place of Astra's Verge_/Embankment_ meshes (local
--      content), at her heights, which the kit's layout plants sit on: BankLip (Model Banks,
--      Persistent, collidable) from the floor's edge (x 36) to the wall line at floor level, never
--      above it, so the slot between the floor and the walls is ground, not a hole to the water;
--      Verge (grass, VergeLift = 0.3 over the floor) from x 38.1 to BankOuter (66); BankCliff
--      (checkered) under it, down into the water.
--   4. LOOK, online only (rbxassetid:// or plain parts): the kit when
--      design/race/greenhill/GreenHillKit.rbxm exists: Kit_* MeshParts placed per layout.json by
--      the kit artist's formula with kit_manifest.json (CFrame = CFrame.new(Origin + pos) *
--      yaw(rotY) * CFrame.new(bboxCenterOffset * scale), Size = size * scale; Studio's import
--      pivots are not trusted; a piece without a manifest entry sits on its own box's bottom
--      centre), lowPower pieces tagged RaceDecorLowPower, never colliding, touching or queried,
--      small plants without shadows, palms with the RacePalmWind attributes (a single-mesh palm
--      sways as a trunk), the layout's fences, and each SpeedPad under the kit's 18 x 16 pad art
--      takes that footprint (what boosts is what shows). Otherwise a part-built Green Hill:
--      checkered cliffs and terraces with grass tops standing in the water, grass islands with
--      sand rims, palms (RacePalmWind), sunflowers and bushes (RaceDecorLowPower), wooden fences
--      (posts and two rails) and pad art (red plate, yellow chevrons, steel rails). Either way:
--      spike stars, the start line and a beam for the five start lights, a checkered finish with
--      its arch, the ORB.
-- Nothing decorative stands inside |x| < 38.1 higher than FlatDecor over the ground unless its
-- bottom is at least Overhead studs over it (the start and finish beams, palm fronds, the ORB):
-- a jumping racer's head reaches ~12.2 studs.
--
--   GreenHill.Build(options?) -> arena Model (not parented), report
--     options.source: a RaceArena Model (default: the pinned rbxm)
--     options.kit: a GreenHillKit Folder, false = no kit, nil = design/race/greenhill/*
--     options.layout / options.manifest: tables (nil = read with the kit)
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local U4 = require("../src/common/ReplicatedStorage/Shared/Update4Config")
local RaceTrack = require("../src/common/ReplicatedStorage/Shared/RaceTrack")
local KitImport = require("./kit_import")
-- 2026-09-26 (owner): the frictionless race boundaries (RaceArenaBuilder.WallPhysics / IsWallPart).
local RaceArenaBuilder = require("../src/common/ServerScriptService/Services/Race/RaceArenaBuilder")

local Instance, Vector3, CFrame, Color3, Enum = roblox.Instance, roblox.Vector3, roblox.CFrame, roblox.Color3, roblox.Enum
-- 2026-09-26 (owner): racers brushing a wall at race speed must keep their momentum: every
-- boundary a racer can touch (Barriers, end caps, bank lips, fences, Astra's Walls, the
-- StartGate) carries these physics (density 0.7, friction 0, elasticity 0, weights 100); the
-- floor keeps its own. Lune serializes CustomPhysicalProperties, so the places carry them.
local WALL_PHYSICS = RaceArenaBuilder.WallPhysicalProperties(roblox)

local ORIGIN = U4.Race.Arena.Origin
local TRACK = U4.Race.Track
local WATER = U4.Race.Water

local GreenHill = {}
GreenHill.Stamp = "RaceArenaGreenHill"
GreenHill.Version = 1
GreenHill.Source = "design/race/Astra_Recta/RaceArena.rbxm"
GreenHill.SourceSha256 = "945b3cdc800f3c6fd16251eff5ad6ceb66d4bc164ee7a6c34b8909300773f845"
GreenHill.KitFile = "design/race/greenhill/GreenHillKit.rbxm"
GreenHill.LayoutFile = "design/race/greenhill/layout.json"
GreenHill.ManifestFile = "design/race/greenhill/kit_manifest.json"

GreenHill.GameplayNames = { "TrackFloor", "Walls", "Structure", "SpeedPads", "Spikes", "FinishGate", "RaceOrb" }
-- Streamed with the race on every device (the lobby's clients too): the floor, the start the
-- client animates, the pads. Astra's 220 short invisible Walls stay a plain Folder: the Barriers
-- (Persistent) do their job everywhere. 2026-09-26 (owner: race speed): the spike tiles too (40
-- plates and their stars): at 300-900 studs/s a racer must never reach a row streaming has not
-- drawn yet.
GreenHill.PersistentNames = { "TrackFloor", "Structure", "SpeedPads", "Spikes" }
GreenHill.S0 = -TRACK.StagingDepth -- back of the staging box
GreenHill.S1 = TRACK.Length + TRACK.RunOut -- end of the run-out
GreenHill.FloorHalf = TRACK.Width * 0.5 -- 36
GreenHill.WallX = 38.1
GreenHill.WallThickness = 1
-- The walls' top over the highest floor: 60 as the owner asked, raised to the anti-cheat's
-- CorridorYMax (80) so that anything that gets over a wall (an admin jump of 60+ studs; the default
-- jump is 7.2) has left the corridor on the way and is out of the race, never racing outside.
GreenHill.WallClearance = math.max(60, U4.Race.Validation.CorridorYMax)
GreenHill.WallBottom = -14
GreenHill.WallSegment = 240
GreenHill.BankOuter = 66 -- the verge's outer edge (the kit's verge plants stand up to |x| 64)
GreenHill.BankTop = { -0.6, -0.03 } -- the collidable lip's top, under the floor edge's height
GreenHill.VergeLift = 0.3 -- the verge's top over the floor (Astra's Verge_*; the kit's plants sit on it)
GreenHill.BankCapThickness = 1.5
GreenHill.FenceX = 39 -- (the kit's layout: 38.4..39.6)
GreenHill.PostEvery = 72
GreenHill.DecorClearX = 38.1
GreenHill.FlatDecor = 0.5
GreenHill.Overhead = 13
GreenHill.ChunkLength = 240
GreenHill.DecorS0 = -320
-- BaseParts this adds (barriers, banks, fences, art; not Astra's 376 gameplay parts): the
-- part-built fallback and the arena as a whole.
GreenHill.DecorBudget = 640
GreenHill.TotalBudget = 1000 -- the part-built arena
-- With the kit (1,390 layout placements, 1,025 of them RaceDecorLowPower: hidden on phones).
GreenHill.KitTotalBudget = 2300
GreenHill.KitShownBudget = 1100 -- parts phones still draw

-- Texture ids already in World1Update3New.rbxl (so they are online and allowed): the lobby's
-- 2x2 checker (6794250394), grass (190738289, on its green parts) and grain (319943200, a black
-- noise with alpha, on its tan parts).
GreenHill.Textures = {
	Checker = "rbxassetid://6794250394",
	Grass = "rbxassetid://190738289",
	Grain = "rbxassetid://319943200",
}

local COLORS = {
	Dirt = { 205, 148, 84 },
	Grain = { 96, 58, 24 },
	Grass = { 104, 192, 52 },
	GrassDark = { 72, 156, 40 },
	Cliff = { 190, 110, 45 },
	CliffChecker = { 115, 62, 22 },
	Sand = { 236, 214, 158 },
	Wood = { 150, 96, 52 },
	WoodDark = { 112, 70, 36 },
	Trunk = { 164, 116, 66 },
	Frond = { 58, 176, 58 },
	Petal = { 255, 204, 32 },
	Seed = { 112, 62, 22 },
	Stem = { 60, 150, 50 },
	Bush = { 52, 150, 52 },
	PadRed = { 222, 40, 40 },
	PadYellow = { 255, 212, 40 },
	Steel = { 150, 156, 166 },
	Star = { 25, 25, 30 },
	White = { 255, 255, 255 },
	Orb = { 150, 235, 255 },
	Gold = { 255, 200, 40 },
	Navy = { 11, 27, 45 },
}

----------------------------------------------------------------------
-- Frame and small helpers
----------------------------------------------------------------------
-- Track-local (s past the start line, x across, y over Origin.Y) to world.
local function world(s, x, y)
	return Vector3.new(ORIGIN.X + x, ORIGIN.Y + y, ORIGIN.Z - s)
end
GreenHill.World = world

local function rgb(values)
	return Color3.fromRGB(values[1], values[2], values[3])
end

local function sortedKeys(t)
	local keys = {}
	for k in t do
		table.insert(keys, k)
	end
	table.sort(keys)
	return keys
end

-- Deterministic random numbers (the same arena on every build).
local function generator(seed)
	local state = seed % 2147483648
	return function(lo, hi)
		state = (state * 1103515245 + 12345) % 2147483648
		local u = state / 2147483648
		if lo then
			return lo + (hi - lo) * u
		end
		return u
	end
end

----------------------------------------------------------------------
-- Local content (rbxasset://)
----------------------------------------------------------------------
-- Engine content every client ships with (text fonts): not "local" in the sense that matters.
GreenHill.EngineContent = { "rbxasset://fonts/" }

-- Every rbxasset:// uri in an XML model string that is not engine content, and every
-- rbxtemp:// one (Studio's handle for an import that was never uploaded).
function GreenHill.LocalUris(xml)
	local found = {}
	for uri in string.gmatch(xml, "rbxasset://[^<\"%s]*") do
		local engine = false
		for _, prefix in GreenHill.EngineContent do
			if string.sub(uri, 1, #prefix) == prefix then
				engine = true
			end
		end
		if not engine then
			table.insert(found, uri)
		end
	end
	for uri in string.gmatch(xml, "rbxtemp://[^<\"%s]*") do
		table.insert(found, uri)
	end
	return found
end

-- The local content anywhere under root (root included).
function GreenHill.LocalContent(root)
	return GreenHill.LocalUris(roblox.serializeModel({ root }, true))
end

-- Whether an instance's own properties (not its children's) reference local content.
local function ownsLocalContent(instance)
	local copy = instance:Clone()
	copy:ClearAllChildren()
	return #GreenHill.LocalUris(roblox.serializeModel({ copy }, true)) > 0
end

----------------------------------------------------------------------
-- The floor: vertical rays against Astra's TrackFloor boxes (what RaceServer's raycast sees)
----------------------------------------------------------------------
local function floorParts(arena)
	local list = {}
	local floor = arena:FindFirstChild("TrackFloor")
	if floor then
		for _, part in floor:GetDescendants() do
			if part:IsA("BasePart") and part.Transparency < 1 and part.CanCollide and part.CanQuery then
				table.insert(list, part)
			end
		end
	end
	return list
end

-- Boxes for GroundAt: each part's CFrame, half size and world Z range.
function GreenHill.BoxesOf(parts)
	local boxes = {}
	for _, part in parts do
		local cf, size = part.CFrame, part.Size
		local zmin, zmax = math.huge, -math.huge
		for _, dx in { -0.5, 0.5 } do
			for _, dy in { -0.5, 0.5 } do
				for _, dz in { -0.5, 0.5 } do
					local corner = cf * Vector3.new(size.X * dx, size.Y * dy, size.Z * dz)
					zmin, zmax = math.min(zmin, corner.Z), math.max(zmax, corner.Z)
				end
			end
		end
		table.insert(boxes, { cf = cf, half = size * 0.5, zmin = zmin, zmax = zmax })
	end
	return boxes
end

-- The visible collidable TrackFloor parts' boxes.
function GreenHill.FloorBoxes(arena)
	return GreenHill.BoxesOf(floorParts(arena))
end

-- The top of the highest floor box under (s, x): a ray straight down from `fromY` (track-local)
-- that enters a box through a face whose world normal points up (>= 0.5). nil = no floor.
function GreenHill.GroundAt(boxes, s, x, fromY)
	local start = world(s, x, fromY or 40)
	local best = nil
	for _, box in boxes do
		if start.Z >= box.zmin - 1e-6 and start.Z <= box.zmax + 1e-6 then
			local o = box.cf:PointToObjectSpace(start)
			local d = box.cf:VectorToObjectSpace(Vector3.new(0, -1, 0))
			local tEnter, tExit, enterAxis, enterSign = -math.huge, math.huge, nil, 0
			local hit = true
			for axis = 1, 3 do
				local origin = if axis == 1 then o.X elseif axis == 2 then o.Y else o.Z
				local dir = if axis == 1 then d.X elseif axis == 2 then d.Y else d.Z
				local half = if axis == 1 then box.half.X elseif axis == 2 then box.half.Y else box.half.Z
				if math.abs(dir) < 1e-9 then
					if origin < -half or origin > half then
						hit = false
						break
					end
				else
					local t1, t2 = (-half - origin) / dir, (half - origin) / dir
					local sign = -1 -- entering through the -half face
					if t1 > t2 then
						t1, t2 = t2, t1
						sign = 1
					end
					if t1 > tEnter then
						tEnter, enterAxis, enterSign = t1, axis, sign
					end
					tExit = math.min(tExit, t2)
					if tEnter > tExit then
						hit = false
						break
					end
				end
			end
			if hit and enterAxis and tEnter >= 0 then
				local normal = Vector3.new(if enterAxis == 1 then enterSign else 0, if enterAxis == 2 then enterSign else 0,
					if enterAxis == 3 then enterSign else 0)
				if box.cf:VectorToWorldSpace(normal).Y >= 0.5 then
					local y = (fromY or 40) - tEnter
					if best == nil or y > best then
						best = y
					end
				end
			end
		end
	end
	return best
end

-- RaceTrack.BuildProfile's sampler for this floor (one stud inside the end walls, like
-- RaceServer's raycast).
function GreenHill.ProfileSampler(arena)
	local boxes = GreenHill.FloorBoxes(arena)
	return function(s, x)
		local sampleS = math.clamp(s, RaceTrack.ProfileS0 + 1, RaceTrack.ProfileS1 - 1)
		return GreenHill.GroundAt(boxes, sampleS, x, 40)
	end
end

-- h(s) near one edge of the floor (x = side * 33), memoized; 0 past the ends.
local function edgeHeights(boxes, side)
	local cache = {}
	return function(s)
		local key = math.floor(s * 100 + 0.5)
		local value = cache[key]
		if value == nil then
			local sampleS = math.clamp(s, GreenHill.S0 + 0.5, GreenHill.S1 - 0.5)
			value = GreenHill.GroundAt(boxes, sampleS, side * (GreenHill.FloorHalf - 3), 40) or 0
			cache[key] = value
		end
		return value
	end
end

-- Straight pieces over [s0, s1] whose line stays within [h + lo, h + hi] at every `step` studs,
-- each as long as it can be (<= maxLen). Endpoints sit at h + (lo + hi) / 2.
function GreenHill.Chords(h, s0, s1, lo, hi, step, maxLen)
	local mid = (lo + hi) * 0.5
	local pieces = {}
	local a = s0
	while a < s1 - 1e-6 do
		local b = math.min(a + step, s1)
		while true do
			local nextB = math.min(b + step, s1)
			if nextB <= b + 1e-9 or nextB - a > maxLen + 1e-9 then
				break
			end
			local ya, yb = h(a) + mid, h(nextB) + mid
			local ok = true
			local s = a + step
			while s < nextB - 1e-9 do
				local y = ya + (yb - ya) * (s - a) / (nextB - a)
				local g = h(s)
				if y < g + lo - 1e-6 or y > g + hi + 1e-6 then
					ok = false
					break
				end
				s += step
			end
			if not ok then
				break
			end
			b = nextB
		end
		table.insert(pieces, { s0 = a, s1 = b, y0 = h(a) + mid, y1 = h(b) + mid })
		a = b
	end
	return pieces
end

----------------------------------------------------------------------
-- Part factory
----------------------------------------------------------------------
local Factory = {}
Factory.__index = Factory

local function newFactory()
	return setmetatable({ count = 0, groups = {} }, Factory)
end

-- opts: material, shape, transparency, collide (default decor: no collide/touch/query),
-- shadow (default off), lowPower (tag), group (count bucket), query, wall (2026-09-26: a
-- frictionless race boundary, RaceArenaBuilder.MarkWall).
function Factory:part(parent, name, size, cframe, color, opts)
	local o = opts or {}
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CastShadow = o.shadow == true
	part.Size = size
	part.CFrame = cframe
	part.Color = rgb(color)
	part.Material = Enum.Material[o.material or "SmoothPlastic"]
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if o.shape then
		part.Shape = Enum.PartType[o.shape]
	end
	if o.transparency then
		part.Transparency = o.transparency
	end
	if o.collide then
		part.CanCollide = true
		part.CanTouch = false
		part.CanQuery = o.query ~= false
	else
		part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
	end
	part:SetAttribute("RaceArenaPart", true)
	if o.lowPower then
		part:AddTag("RaceDecorLowPower")
	end
	if o.wall then
		RaceArenaBuilder.MarkWall(part, WALL_PHYSICS)
	end
	part.Parent = parent
	self.count += 1
	local group = o.group or "Other"
	self.groups[group] = (self.groups[group] or 0) + 1
	return part
end

function Factory:texture(part, id, face, color, transparency, tile)
	local texture = Instance.new("Texture")
	texture.Name = face .. "Texture"
	texture.Texture = id
	texture.Face = Enum.NormalId[face]
	texture.Color3 = rgb(color)
	texture.Transparency = transparency
	texture.StudsPerTileU = tile
	texture.StudsPerTileV = tile
	texture.Parent = part
	return texture
end

-- A checkered cliff face on the given faces.
function Factory:checker(part, faces, tile)
	for _, face in faces do
		self:texture(part, GreenHill.Textures.Checker, face, COLORS.CliffChecker, 0.35, tile or 16)
	end
end

function Factory:grassTop(part, tile)
	self:texture(part, GreenHill.Textures.Grass, "Top", COLORS.White, 0.35, tile or 8)
end

-- A block hanging `thickness` under the chord (s0, y0) -> (s1, y1) at x, `width` across.
local function chordFrame(piece, x, thickness, overlap)
	local ds, dy = piece.s1 - piece.s0, piece.y1 - piece.y0
	local length = math.sqrt(ds * ds + dy * dy) + (overlap or 0)
	local pitch = math.atan2(dy, ds)
	local cf = CFrame.new(world((piece.s0 + piece.s1) * 0.5, x, (piece.y0 + piece.y1) * 0.5)) * CFrame.Angles(pitch, 0, 0)
		* CFrame.new(0, -thickness * 0.5, 0)
	return cf, length
end

----------------------------------------------------------------------
-- Source and kit files
----------------------------------------------------------------------
function GreenHill.LoadSource()
	assert(fs.isFile(GreenHill.Source), GreenHill.Source .. " is missing (Astra's RaceArena.rbxm)")
	local bytes = fs.readFile(GreenHill.Source)
	assert(serde.hash("sha256", bytes) == GreenHill.SourceSha256,
		GreenHill.Source .. " is not the pinned copy (SHA-256): check the new map against test_u4_greenhill and re-pin it on purpose")
	local roots = roblox.deserializeModel(bytes)
	assert(#roots == 1 and roots[1].Name == "RaceArena", GreenHill.Source .. ": one root named RaceArena")
	return roots[1]
end

local function readJson(path)
	if not fs.isFile(path) then
		return nil
	end
	local ok, data = pcall(serde.decode, "json", fs.readFile(path))
	assert(ok, path .. " is not valid JSON: " .. tostring(data))
	return data
end

-- The owner's kit (GreenHillKit.rbxm, saved from Studio after importing the FBX) with its
-- layout and manifest; nil when there is no kit file. No scripts, no local content.
function GreenHill.LoadKit()
	if not fs.isFile(GreenHill.KitFile) then
		return nil
	end
	local roots = roblox.deserializeModel(fs.readFile(GreenHill.KitFile))
	local folder
	if #roots == 1 and (roots[1].ClassName == "Folder" or roots[1].ClassName == "Model") then
		folder = roots[1]
	else
		folder = Instance.new("Folder")
		for _, root in roots do
			root.Parent = folder
		end
	end
	folder.Name = "GreenHillKit"
	-- Studio's importer can wrap the pieces in an extra Model: lift every outermost Kit_* up to the folder.
	local outer = {}
	for _, d in folder:GetDescendants() do
		if string.sub(d.Name, 1, 4) == "Kit_" and d.Parent ~= folder then
			local inner = false
			local p = d.Parent
			while p and p ~= folder do
				if string.sub(p.Name, 1, 4) == "Kit_" then
					inner = true
					break
				end
				p = p.Parent
			end
			if not inner then
				table.insert(outer, d)
			end
		end
	end
	for _, piece in outer do
		piece.Parent = folder
	end
	local layout = readJson(GreenHill.LayoutFile)
	assert(layout ~= nil, GreenHill.KitFile .. " is there but " .. GreenHill.LayoutFile .. " is not")
	return folder, layout, readJson(GreenHill.ManifestFile)
end

----------------------------------------------------------------------
-- Kit pieces
----------------------------------------------------------------------
local function kitName(name)
	local text = tostring(name or "")
	if string.sub(text, 1, 4) ~= "Kit_" then
		text = "Kit_" .. text
	end
	return text
end

local function partsOf(root)
	local list = {}
	if root:IsA("BasePart") then
		table.insert(list, root)
	end
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(list, d)
		end
	end
	return list
end

-- The world AABB of some parts (from their oriented corners).
local function aabb(parts)
	local lo = Vector3.new(math.huge, math.huge, math.huge)
	local hi = Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, part in parts do
		local cf, size = part.CFrame, part.Size
		for _, dx in { -0.5, 0.5 } do
			for _, dy in { -0.5, 0.5 } do
				for _, dz in { -0.5, 0.5 } do
					local p = cf * Vector3.new(size.X * dx, size.Y * dy, size.Z * dz)
					lo = Vector3.new(math.min(lo.X, p.X), math.min(lo.Y, p.Y), math.min(lo.Z, p.Z))
					hi = Vector3.new(math.max(hi.X, p.X), math.max(hi.Y, p.Y), math.max(hi.Z, p.Z))
				end
			end
		end
	end
	return lo, hi
end
GreenHill.AABB = aabb

-- { [Kit_Name] = { root, base (the bottom centre of its box), size } } for every Kit_* child.
function GreenHill.KitPieces(folder)
	local pieces = {}
	for _, root in folder:GetChildren() do
		if string.sub(root.Name, 1, 4) == "Kit_" then
			local parts = partsOf(root)
			if #parts > 0 then
				local lo, hi = aabb(parts)
				pieces[root.Name] = {
					root = root,
					base = Vector3.new((lo.X + hi.X) * 0.5, lo.Y, (lo.Z + hi.Z) * 0.5),
					size = hi - lo,
				}
			end
		end
	end
	return pieces
end

-- The manifest's placement data per piece ({ size, offset (bboxCenterOffset), castShadow }),
-- checked against the pieces in the rbxm: a MeshPart's mesh stretches to its Size, so the import
-- unit does not matter, but its axes must be the manifest's (same proportions, no rotation).
function GreenHill.ManifestSpecs(manifest, pieces, report)
	local specs = {}
	if type(manifest) ~= "table" or type(manifest.pieces) ~= "table" then
		return specs
	end
	for _, entry in manifest.pieces do
		local name = type(entry) == "table" and entry.name
		local size, offset = type(entry) == "table" and entry.size, type(entry) == "table" and entry.bboxCenterOffset
		if type(name) == "string" and type(size) == "table" and type(offset) == "table" and #size == 3 and #offset == 3 then
			local spec = {
				size = Vector3.new(size[1], size[2], size[3]),
				offset = Vector3.new(offset[1], offset[2], offset[3]),
				castShadow = entry.castShadow,
				-- The piece's true outline seen from above ({x, z} around its pivot), when given.
				hull = if type(entry.footprintHullXZ) == "table" and #entry.footprintHullXZ >= 3 then entry.footprintHullXZ else nil,
			}
			local piece = pieces[name]
			if piece and piece.root:IsA("BasePart") then
				local have = piece.root.Size
				local k = have.Y / spec.size.Y
				local skew = math.max(math.abs(have.X / spec.size.X - k), math.abs(have.Z / spec.size.Z - k)) / math.max(k, 1e-6)
				assert(skew <= 0.03, string.format("%s is %.2f x %.2f x %.2f in the kit but %.2f x %.2f x %.2f in kit_manifest.json: import the FBX again with its default axes (design/race/greenhill/IMPORTAR_KIT.md)",
					name, have.X, have.Y, have.Z, spec.size.X, spec.size.Y, spec.size.Z))
				local _, _, _, r00, _, _, _, r11, _, _, _, r22 = piece.root.CFrame:GetComponents()
				if math.abs(r00 - 1) > 1e-3 or math.abs(r11 - 1) > 1e-3 or math.abs(r22 - 1) > 1e-3 then
					table.insert(report.warnings, name .. " was imported rotated; it is placed with the manifest's axes")
				end
			end
			specs[name] = spec
		end
	end
	-- 2026-09-26: Studio's Import 3D turned the owner's kit 180 degrees about Y (the FBX's axes):
	-- each MeshPart's PivotOffset (where the importer put the piece's own origin, its base
	-- centre) is the manifest's -bboxCenterOffset turned by that yaw. The pieces are placed with
	-- the manifest's axes, so each mesh is turned back by it; without that the pad chevrons
	-- point at the start and a leaning palm's trunk stands twice its offset away (21 studs).
	-- 2026-09-26 (owner): the detection now lives in audit/kit_import (the Egg Mobile kit uses it too).
	local pairs_ = {}
	for name, spec in specs do
		local piece = pieces[name]
		if piece and piece.root:IsA("BasePart") then
			table.insert(pairs_, { part = piece.root, offset = spec.offset, size = spec.size })
		end
	end
	local detected = KitImport.DetectYaw(pairs_)
	local importYaw = detected or 0
	if detected == nil then
		table.insert(report.warnings, "the kit's import pivots match no quarter turn of kit_manifest.json; placed as authored")
	end
	report.kitImportYawDegrees = math.deg(importYaw)
	for _, spec in specs do
		spec.importYaw = importYaw
	end
	return specs
end

-- The kit's dirt texture id, if it carries one: a Texture/Decal named *Dirt* in the kit, a
-- DirtTexture attribute on the folder, or the manifest (dirtTexture / DirtTexture /
-- textures.dirt). Only uploaded ids (rbxassetid://) count.
function GreenHill.KitDirtTexture(folder, manifest)
	local candidates = {}
	if folder then
		table.insert(candidates, folder:GetAttribute("DirtTexture"))
		for _, d in folder:GetDescendants() do
			if (d.ClassName == "Texture" or d.ClassName == "Decal") and string.find(string.lower(d.Name), "dirt", 1, true) then
				local ok, value = pcall(function()
					return d.Texture
				end)
				if ok then
					table.insert(candidates, value)
				end
			end
		end
	end
	if type(manifest) == "table" then
		table.insert(candidates, manifest.dirtTexture)
		table.insert(candidates, manifest.DirtTexture)
		if type(manifest.textures) == "table" then
			table.insert(candidates, manifest.textures.dirt)
			table.insert(candidates, manifest.textures.Dirt)
		end
	end
	for _, value in candidates do
		local text = tostring(value or "")
		if string.match(text, "^rbxassetid://%d+$") then
			return text
		end
	end
	return nil
end

-- A layout.json as a list of placements (a bare list, or { placements = [...] }).
function GreenHill.Placements(layout)
	if type(layout) ~= "table" then
		return {}
	end
	local list = if type(layout.placements) == "table" then layout.placements else layout
	local out = {}
	for _, row in list do
		if type(row) == "table" and type(row.pos) == "table" and #row.pos == 3 then
			table.insert(out, row)
		end
	end
	return out
end

-- Kit pieces that are ground (they should stand in the water, not float over it).
local GROUND_WORDS = { "mesa", "terrace", "cliff", "island", "hill", "plateau", "pillar", "tower", "bank", "embankment" }
local function isGroundPiece(name)
	local lower = string.lower(name)
	for _, word in GROUND_WORDS do
		if string.find(lower, word, 1, true) then
			return true
		end
	end
	return false
end

local PLANT_WORDS = { "flower", "bush", "fern", "grass", "plant", "shrub", "mushroom", "rock", "pebble", "sunflower", "tulip" }
local function isSmallPlant(name, height)
	local lower = string.lower(name)
	for _, word in PLANT_WORDS do
		if string.find(lower, word, 1, true) then
			return true
		end
	end
	return height < 6
end

----------------------------------------------------------------------
-- Build
----------------------------------------------------------------------
local function isGameplay(instance, arena)
	local top = instance
	while top.Parent and top.Parent ~= arena do
		top = top.Parent
	end
	return top.Parent == arena and table.find(GreenHill.GameplayNames, top.Name) ~= nil
end

local function persistentModel(arena, name)
	local container = arena:FindFirstChild(name)
	if not container then
		return nil
	end
	if container.ClassName ~= "Model" then
		local model = Instance.new("Model")
		model.Name = name
		for key, value in container:GetAttributes() do
			model:SetAttribute(key, value)
		end
		for _, tag in container:GetTags() do
			model:AddTag(tag)
		end
		for _, child in container:GetChildren() do
			child.Parent = model
		end
		container.Parent = nil
		model.Parent = arena
		container = model
	end
	container.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	return container
end

-- 2026-09-26 (owner: race speed + spike spacing): the spike tiles come from Update4Config
-- (RaceTrack.SpikeTiles: fields of 2-3 rows, SpikeRowGap apart), not from Astra's map, which
-- carried the first layout (2 rows 40 apart per field). Her tiles go; each config tile is a
-- plate with her tile's look (a SpikeTile x SpikeTileHeight x SpikeTile Metal plate that never
-- collides, touches or is queried) and attributes (S, Field, Row, Lane, RaceSpikeTile), named
-- SpikeTile_<field>_<row>_<lane>, its bottom on the race's ground profile of this floor
-- (RaceTrack.BuildProfile of ProfileSampler: what the server raycasts), so the plate and the
-- hit test agree on the hills. Returns the number of tiles.
function GreenHill.SpikesFromConfig(arena)
	local spikes = arena:FindFirstChild("Spikes")
	assert(spikes, "the race map has no Spikes")
	local template = nil
	for _, child in spikes:GetChildren() do
		if template == nil and child:IsA("BasePart") then
			template = child
		end
	end
	local profile = RaceTrack.BuildProfile(GreenHill.ProfileSampler(arena))
	for _, child in spikes:GetChildren() do
		child.Parent = nil
	end
	for _, tile in RaceTrack.SpikeTiles() do
		local part = Instance.new("Part")
		part.Name = string.format("SpikeTile_%d_%d_%d", tile.field, tile.row, tile.lane)
		part.Anchored = true
		part.Size = Vector3.new(TRACK.SpikeTile, TRACK.SpikeTileHeight, TRACK.SpikeTile)
		part.CFrame = CFrame.new(world(tile.s, tile.x, RaceTrack.Ground(tile.s, tile.x, profile) + TRACK.SpikeTileHeight * 0.5))
		part.Material = if template then template.Material else Enum.Material.Metal
		part.Color = if template then template.Color else Color3.fromRGB(205, 208, 214)
		part.CastShadow = if template then template.CastShadow else false
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
		part:SetAttribute("S", tile.s)
		part:SetAttribute("Field", tile.field)
		part:SetAttribute("Row", tile.row)
		part:SetAttribute("Lane", tile.lane)
		part:SetAttribute("RaceSpikeTile", true)
		part:SetAttribute("RaceArenaPart", true)
		part.Parent = spikes
	end
	return #RaceTrack.SpikeTiles()
end

function GreenHill.Build(options)
	local opts = options or {}
	local arena = opts.source or GreenHill.LoadSource()
	local report = {
		removedParts = 0, removedObjects = 0, removedTags = 0, warnings = {}, skipped = {},
		kit = false, kitPlacements = 0, kitParts = 0, kitLowPowerParts = 0, fence = "parts", replaced = {},
	}
	local f = newFactory()
	local T = GreenHill.Textures

	for _, d in arena:GetDescendants() do
		assert(not d:IsA("LuaSourceContainer"), "the race map carries a script: " .. d:GetFullName())
	end
	for _, name in GreenHill.GameplayNames do
		assert(arena:FindFirstChild(name), "the race map has no " .. name)
	end

	-- 2. Local content out (children first: a mesh carrier with nothing else left goes too).
	local carriers = {}
	for _, d in arena:GetDescendants() do
		if d:IsDescendantOf(arena) and ownsLocalContent(d) then
			if d:IsA("BasePart") then
				assert(not isGameplay(d, arena), "gameplay part " .. d:GetFullName() .. " is itself local content")
				report.removedTags += #d:GetTags()
				for _, x in d:GetDescendants() do
					report.removedTags += #x:GetTags()
				end
				d.Parent = nil
				report.removedParts += 1
			else
				local parent = d.Parent
				d.Parent = nil
				report.removedObjects += 1
				if parent and parent:IsA("BasePart") then
					carriers[parent] = true
				end
			end
		end
	end
	for carrier in carriers do
		if carrier:IsDescendantOf(arena) and not isGameplay(carrier, arena) then
			report.removedTags += #carrier:GetTags()
			carrier.Parent = nil
			report.removedParts += 1
		end
	end
	for _, child in arena:GetChildren() do
		if not table.find(GreenHill.GameplayNames, child.Name) and #partsOf(child) == 0 then
			child.Parent = nil -- the emptied Visuals folder
		end
	end
	assert(#GreenHill.LocalContent(arena) == 0, "local content left after the clean-up")

	-- The spike tiles: Update4Config's layout in place of Astra's (2026-09-26, SpikesFromConfig).
	report.spikeTiles = GreenHill.SpikesFromConfig(arena)

	-- 1. Gameplay kept; the parts every device needs Persistent; the markers the scripts read.
	for _, name in GreenHill.PersistentNames do
		persistentModel(arena, name)
	end
	local gameplayParts = 0
	for _, d in arena:GetDescendants() do
		if d:IsA("BasePart") then
			gameplayParts += 1
			if d:GetAttribute("RaceArenaPart") == nil then
				d:SetAttribute("RaceArenaPart", true)
			end
		end
	end
	for _, tile in arena.Spikes:GetChildren() do
		if tile:IsA("BasePart") then
			tile:SetAttribute("RaceSpikeTile", true)
		end
	end
	local startGate = arena.Structure:FindFirstChild("StartGate")
	assert(startGate and startGate:IsA("BasePart"), "Structure.StartGate")
	startGate.CanCollide = true
	report.gameplayParts = gameplayParts

	-- The kit (or not).
	local kit, layout, manifest = opts.kit, opts.layout, opts.manifest
	if kit == nil then
		kit, layout, manifest = GreenHill.LoadKit()
		if not kit and fs.isFile(GreenHill.LayoutFile) then
			report.kitNote = GreenHill.LayoutFile .. " is there but " .. GreenHill.KitFile
				.. " is not yet (import GreenHillKit.fbx in Studio and save it: design/race/greenhill/IMPORTAR_KIT.md); part-built look meanwhile"
		end
	end
	if kit == false then
		kit = nil
	end
	local pieces = {}
	if kit then
		for _, d in kit:GetDescendants() do
			assert(not d:IsA("LuaSourceContainer"), "the kit carries a script: " .. d:GetFullName())
		end
		local uris = GreenHill.LocalContent(kit)
		assert(#uris == 0, "the kit references local content (" .. tostring(uris[1]) .. "): publish its meshes from Studio first")
		pieces = GreenHill.KitPieces(kit)
		report.kit = true
	end
	local specs = if kit then GreenHill.ManifestSpecs(manifest, pieces, report) else {}
	local placements = if kit then GreenHill.Placements(layout) else {}
	local placedKinds = {}
	for _, row in placements do
		placedKinds[kitName(row.kit)] = true
	end
	local function kitHas(word)
		for name in placedKinds do
			if string.find(string.lower(name), word, 1, true) then
				return true
			end
		end
		return false
	end

	-- The floor: dirt.
	local dirtTexture = if kit then GreenHill.KitDirtTexture(kit, manifest) else nil
	report.dirtTexture = dirtTexture
	for _, part in floorParts(arena) do
		part.Material = Enum.Material.Ground
		part.Color = rgb(COLORS.Dirt)
		f:texture(part, T.Grain, "Top", COLORS.Grain, 0.4, 12)
		if dirtTexture then
			f:texture(part, dirtTexture, "Top", COLORS.White, 0.15, 24).Name = "KitDirtTexture"
		end
	end

	-- Heights along both edges of the floor, and the whole profile (for the barrier height).
	local boxes = GreenHill.FloorBoxes(arena)
	local edge = { [-1] = edgeHeights(boxes, -1), [1] = edgeHeights(boxes, 1) }
	local maxFloor = 0
	for s = GreenHill.S0, GreenHill.S1, 2 do
		maxFloor = math.max(maxFloor, edge[-1](s), edge[1](s))
	end
	report.maxFloor = maxFloor
	local function ground(s, x)
		if s < GreenHill.S0 or s > GreenHill.S1 then
			return 0
		end
		return edge[if x < 0 then -1 else 1](s)
	end
	report.ground = ground

	-- Decor chunks (Atomic, one per ChunkLength of s).
	local decor = Instance.new("Folder")
	decor.Name = "GreenHillDecor"
	local chunks = {}
	local function chunkAt(s)
		local index = math.max(1, math.floor((s - GreenHill.DecorS0) / GreenHill.ChunkLength) + 1)
		local chunk = chunks[index]
		if not chunk then
			chunk = Instance.new("Model")
			chunk.Name = "Chunk_" .. index
			chunk.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
			chunk.Parent = decor
			chunks[index] = chunk
		end
		return chunk
	end

	-- 3. Barriers: tall invisible walls on the contract's line, end caps.
	local barriers = Instance.new("Model")
	barriers.Name = "Barriers"
	barriers.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	local wallTop = maxFloor + GreenHill.WallClearance
	local wallHeight = wallTop - GreenHill.WallBottom
	local wallY = (wallTop + GreenHill.WallBottom) * 0.5
	local barrierOpts = { collide = true, query = false, transparency = 1, group = "Barriers", wall = true }
	do
		local s0, s1 = GreenHill.S0 - 1, GreenHill.S1 + 1
		local index = 0
		local s = s0
		while s < s1 - 1e-6 do
			local e = math.min(s + GreenHill.WallSegment, s1)
			index += 1
			for side = -1, 1, 2 do
				f:part(barriers, (if side < 0 then "WallL_" else "WallR_") .. index,
					Vector3.new(GreenHill.WallThickness, wallHeight, e - s), CFrame.new(world((s + e) * 0.5, side * GreenHill.WallX, wallY)),
					COLORS.White, barrierOpts)
			end
			s = e
		end
		local span = 2 * GreenHill.WallX + GreenHill.WallThickness
		f:part(barriers, "BackCap", Vector3.new(span, wallHeight, 1), CFrame.new(world(GreenHill.S0 - 0.5, 0, wallY)), COLORS.White, barrierOpts)
		f:part(barriers, "EndCap", Vector3.new(span, wallHeight, 1), CFrame.new(world(GreenHill.S1 + 0.5, 0, wallY)), COLORS.White, barrierOpts)
	end
	report.wallTop = wallTop

	-- Banks. Astra's Verge/Embankment meshes were local content; their stand-ins keep her heights,
	-- which the kit's layout plants sit on (verge top = floor + VergeLift from x 38.1 outward):
	--   * BankLip (Persistent, collidable): x 36..38.1, its top at floor level (never above it:
	--     the contract's clear corridor), so the slot between the floor and the walls is ground;
	--   * Verge (decor): grass from the wall line (x 38.1) to BankOuter, VergeLift over the floor;
	--   * BankCliff (decor): checkered, under the verge, down into the water.
	local banks = Instance.new("Model")
	banks.Name = "Banks"
	banks.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	local bankS0, bankS1 = GreenHill.S0 - 12, GreenHill.S1 + 12
	local lipWidth = GreenHill.WallX - GreenHill.FloorHalf
	local vergeWidth = GreenHill.BankOuter - GreenHill.WallX
	local lift = GreenHill.VergeLift
	for side = -1, 1, 2 do
		local h = edge[side]
		local lipTop = GreenHill.BankTop
		for index, piece in GreenHill.Chords(h, bankS0, bankS1, lipTop[1], lipTop[2], 2, GreenHill.ChunkLength) do
			local cf, length = chordFrame(piece, side * (GreenHill.FloorHalf + lipWidth * 0.5), GreenHill.BankCapThickness, 0.3)
			-- 2026-09-26 (owner): the lip's edge is where a racer hugging the wall puts a foot: frictionless too.
			f:part(banks, "BankLip_" .. index, Vector3.new(lipWidth, GreenHill.BankCapThickness, length), cf, COLORS.Grass,
				{ collide = true, material = "Grass", group = "Banks", wall = true })
		end
		for index, piece in GreenHill.Chords(h, bankS0, bankS1, lift - 0.2, lift + 0.2, 2, GreenHill.ChunkLength) do
			local cf, length = chordFrame(piece, side * (GreenHill.WallX + vergeWidth * 0.5), 2, 0.3)
			local verge = f:part(chunkAt((piece.s0 + piece.s1) * 0.5), "Verge_" .. index, Vector3.new(vergeWidth, 2, length), cf, COLORS.Grass,
				{ material = "Grass", group = "Banks" })
			f:grassTop(verge)
		end
		-- The cliff's top stays inside the verge's thickness.
		for index, piece in GreenHill.Chords(h, bankS0, bankS1, lift - 1.6, lift - 0.2, 4, GreenHill.ChunkLength) do
			local midY = (piece.y0 + piece.y1) * 0.5
			local thickness = midY - (GreenHill.WallBottom - 1)
			local cf, length = chordFrame(piece, side * (GreenHill.WallX + 0.3 + (vergeWidth - 0.6) * 0.5), thickness, 0.3)
			local body = f:part(chunkAt((piece.s0 + piece.s1) * 0.5), "BankCliff_" .. index, Vector3.new(vergeWidth - 0.6, thickness, length), cf,
				COLORS.Cliff, { material = "Slate", group = "Banks" })
			f:checker(body, { if side < 0 then "Left" else "Right" }, 12)
		end
	end
	-- The ends: checkered cliffs closing the staging box and the run-out (behind the end caps).
	local function endCliff(name, sNear, sFar, height)
		local sMid, depth = (sNear + sFar) * 0.5, math.abs(sFar - sNear)
		local width = 2 * GreenHill.BankOuter + 24
		local body = f:part(chunkAt(sMid), name, Vector3.new(width, height - GreenHill.WallBottom + 1, depth),
			CFrame.new(world(sMid, 0, (height + GreenHill.WallBottom - 1) * 0.5)), COLORS.Cliff, { material = "Slate", shadow = true, group = "Ends" })
		f:checker(body, { "Front", "Back", "Left", "Right" }, 16)
		local cap = f:part(chunkAt(sMid), name .. "Top", Vector3.new(width + 2, 2, depth + 2), CFrame.new(world(sMid, 0, height + 1)),
			COLORS.Grass, { material = "Grass", group = "Ends" })
		f:grassTop(cap)
	end
	endCliff("StartCliff", GreenHill.S0, GreenHill.S0 - 24, 22)
	endCliff("EndCliff", GreenHill.S1, GreenHill.S1 + 24, 30)

	-- Fences along both edges on the verge: the kit's (its layout's Kit_FenceSection tiles, or
	-- tiles laid here when the layout has none), else wooden posts and two rails.
	local fence = pieces.Kit_FenceSection
	local fenceParts0 = f.count
	local layoutFences = placedKinds.Kit_FenceSection == true
	if fence then
		report.fence = if layoutFences then "kit (layout)" else "kit (edge tiles)"
	else
		for side = -1, 1, 2 do
			local h = edge[side]
			for index, piece in GreenHill.Chords(h, GreenHill.S0, GreenHill.S1, lift + 0.9, lift + 1.9, 2, GreenHill.ChunkLength) do
				for rail, raise in { 0, 1.4 } do
					local lifted = { s0 = piece.s0, s1 = piece.s1, y0 = piece.y0 + raise, y1 = piece.y1 + raise }
					local cf, length = chordFrame(lifted, side * GreenHill.FenceX, 0.6, 0.2)
					f:part(chunkAt((piece.s0 + piece.s1) * 0.5), "FenceRail" .. rail .. "_" .. index, Vector3.new(0.45, 0.6, length), cf,
						COLORS.Wood, { material = "WoodPlanks", group = "Fence", wall = true })
				end
			end
			local s = GreenHill.S0
			while s <= GreenHill.S1 + 1e-6 do
				local g = ground(math.clamp(s, GreenHill.S0, GreenHill.S1), side) + lift
				f:part(chunkAt(s), "FencePost", Vector3.new(0.8, 4, 0.8), CFrame.new(world(s, side * GreenHill.FenceX, g + 1.6)),
					COLORS.WoodDark, { material = "Wood", group = "Fence", wall = true })
				s += GreenHill.PostEvery
			end
		end
	end

	-- Whether a decorative box (world AABB) stays out of the racers' way: over the playable box
	-- (s from S0 to S1, |x| < DecorClearX) it must lie flat on the ground (top <= FlatDecor over
	-- the highest ground under it) or hang overhead (bottom >= Overhead over it).
	local function clearOfTrack(lo, hi)
		local xLo, xHi = lo.X - ORIGIN.X, hi.X - ORIGIN.X
		if xHi <= -GreenHill.DecorClearX or xLo >= GreenHill.DecorClearX then
			return true
		end
		local sA, sB = ORIGIN.Z - hi.Z, ORIGIN.Z - lo.Z
		if sB <= GreenHill.S0 or sA >= GreenHill.S1 then
			return true
		end
		sA, sB = math.max(sA, GreenHill.S0), math.min(sB, GreenHill.S1)
		local gMax = -math.huge
		local s = sA
		while true do
			gMax = math.max(gMax, edge[-1](s), edge[1](s))
			if s >= sB then
				break
			end
			s = math.min(s + 2, sB)
		end
		local top, bottom = hi.Y - ORIGIN.Y, lo.Y - ORIGIN.Y
		return top <= gMax + GreenHill.FlatDecor + 1e-6 or bottom >= gMax + GreenHill.Overhead - 1e-6
	end
	report.clearOfTrack = clearOfTrack

	-- Kit placement. With the piece in kit_manifest.json (the artist's formula; Studio's import
	-- pivots only tell the import's turn, GreenHill.ManifestSpecs): CFrame = CFrame.new(Origin +
	-- pos) * yaw(rotY) * CFrame.new(bboxCenterOffset * scale) * yaw(-importYaw), Size = size * scale. Without it: the piece's own box,
	-- its bottom centre on Origin + pos. Fence tiles laid here are also pitched with the ground.
	-- Never collides; lowPower tagged; small plants cast no shadow; palms sway (RacePalmWind).
	local palmIndex = 0
	local function placeKit(name, row, extraPitch)
		local piece = pieces[name]
		if not piece then
			table.insert(report.warnings, "layout names " .. name .. ", which the kit does not have")
			return nil
		end
		local spec = specs[name]
		local pos = row.pos
		local scale = math.clamp(tonumber(row.scale) or 1, 0.05, 20)
		local yaw = math.rad(tonumber(row.rotY) or 0)
		local anchor = Vector3.new(ORIGIN.X + tonumber(pos[1]), ORIGIN.Y + tonumber(pos[2]), ORIGIN.Z + tonumber(pos[3]))
		local frame = CFrame.new(anchor) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(extraPitch or 0, 0, 0)
		local clone = piece.root:Clone()
		local originals, copies = partsOf(piece.root), partsOf(clone)
		local height = piece.size.Y * scale
		if spec and #copies == 1 then
			copies[1].CFrame = frame * CFrame.new(spec.offset * scale) * CFrame.Angles(0, -(spec.importYaw or 0), 0)
			copies[1].Size = spec.size * scale
			height = spec.size.Y * scale
		else
			local baseFrame = CFrame.new(piece.base)
			for index, original in originals do
				local copy = copies[index]
				local rel = baseFrame:Inverse() * original.CFrame
				local _, _, _, r00, r01, r02, r10, r11, r12, r20, r21, r22 = rel:GetComponents()
				copy.CFrame = frame * CFrame.new(rel.Position * scale) * CFrame.new(0, 0, 0, r00, r01, r02, r10, r11, r12, r20, r21, r22)
				copy.Size = original.Size * scale
			end
		end
		local shadow = (spec == nil or spec.castShadow ~= false) and not isSmallPlant(name, height)
		for _, copy in copies do
			copy.Anchored = true
			copy.CanCollide, copy.CanTouch, copy.CanQuery = false, false, false
			copy:SetAttribute("RaceArenaPart", true)
			if row.lowPower == true then
				copy:AddTag("RaceDecorLowPower")
			end
			if not shadow then
				copy.CastShadow = false
			end
		end
		local lo, hi = aabb(copies)
		-- Across the track, the manifest's outline (a leaning palm's box is much wider than it).
		local clearLo, clearHi = lo, hi
		if spec and spec.hull then
			local xLo, xHi = math.huge, -math.huge
			for _, point in spec.hull do
				local x = (frame * Vector3.new(point[1] * scale, 0, point[2] * scale)).X
				xLo, xHi = math.min(xLo, x), math.max(xHi, x)
			end
			clearLo, clearHi = Vector3.new(xLo, lo.Y, lo.Z), Vector3.new(xHi, hi.Y, hi.Z)
		end
		if not clearOfTrack(clearLo, clearHi) then
			table.insert(report.skipped, string.format("%s at (%g, %g, %g): inside the track corridor", name, pos[1], pos[2], pos[3]))
			return nil
		end
		-- The water (Update4Config.Race.Water): ground pieces should reach into it, and nothing
		-- on the ground should stand past its edge (over the void).
		if isGroundPiece(name) and lo.Y - ORIGIN.Y > WATER.Top then
			table.insert(report.warnings, string.format("%s at (%g, %g, %g) floats: its bottom is %.1f over the water's top (y %d)", name,
				pos[1], pos[2], pos[3], lo.Y - ORIGIN.Y - WATER.Top, WATER.Top))
		end
		if lo.Y - ORIGIN.Y < 40 and (lo.X - ORIGIN.X < -WATER.HalfX or hi.X - ORIGIN.X > WATER.HalfX
			or ORIGIN.Z - hi.Z < WATER.SMin or ORIGIN.Z - lo.Z > WATER.SMax) then
			table.insert(report.warnings, string.format("%s at (%g, %g, %g) reaches past the water (x +-%d, s %d..%d)", name,
				pos[1], pos[2], pos[3], WATER.HalfX, WATER.SMin, WATER.SMax))
		end
		if string.find(string.lower(name), "palm", 1, true) then
			palmIndex += 1
			local crown = frame * Vector3.new(0, height * 0.92, 0)
			for _, copy in copies do
				local lower = string.lower(copy.Name)
				local canopy = string.find(lower, "canopy", 1, true) or string.find(lower, "leaf", 1, true)
					or string.find(lower, "frond", 1, true) or string.find(lower, "crown", 1, true)
				copy:SetAttribute("WindBase", anchor)
				copy:SetAttribute("WindCrown", crown)
				copy:SetAttribute("WindKind", if canopy then "canopy" else "trunk")
				copy:SetAttribute("WindTree", 1000 + palmIndex)
				copy:SetAttribute("WindPhase", (palmIndex * 0.83) % (2 * math.pi))
				copy:AddTag("RacePalmWind")
			end
		end
		clone.Parent = chunkAt(ORIGIN.Z - anchor.Z)
		report.kitParts += #copies
		if row.lowPower == true then
			report.kitLowPowerParts += #copies
		end
		return clone
	end

	if fence and not layoutFences then
		-- Tiles along each edge, each section's long side down the track, pitched with the ground.
		local fenceSize = if specs.Kit_FenceSection then specs.Kit_FenceSection.size else fence.size
		local alongX = fenceSize.X > fenceSize.Z
		local length = math.max(1, if alongX then fenceSize.X else fenceSize.Z)
		for side = -1, 1, 2 do
			local s = GreenHill.S0 + length * 0.5
			while s - length * 0.5 < GreenHill.S1 - 1e-6 do
				local sA, sB = s - length * 0.5, math.min(s + length * 0.5, GreenHill.S1)
				local gA, gB = ground(sA, side), ground(sB, side)
				local pitch = math.atan2(gB - gA, sB - sA)
				local row = { pos = { side * GreenHill.FenceX, (gA + gB) * 0.5 + lift, -s }, rotY = if alongX then 90 else 0, scale = 1, lowPower = true }
				placeKit("Kit_FenceSection", row, if alongX then 0 else pitch)
				s += length
			end
		end
	end
	report.fenceParts = if fence then nil else f.count - fenceParts0

	-- Layout placements.
	local padVisuals = {}
	for _, row in placements do
		local name = kitName(row.kit)
		local placed = placeKit(name, row)
		if placed then
			report.kitPlacements += 1
			if string.find(string.lower(name), "speedpad", 1, true) then
				table.insert(padVisuals, { part = partsOf(placed)[1], rotY = tonumber(row.rotY) or 0 })
			end
		end
	end
	-- The kit's pad art is 18 x 16; Astra's SpeedPad parts are 16 x 20 (invisible). A pad under a
	-- kit pad visual takes the visual's footprint, so what boosts is what shows (the server reads
	-- the parts at every staging; the centre, height and attributes stay).
	report.padsResized = 0
	for _, visual in padVisuals do
		local vPos = visual.part.CFrame.Position
		for _, pad in arena.SpeedPads:GetDescendants() do
			if pad:IsA("BasePart") and pad.Name == "SpeedPad" then
				local p = pad.CFrame.Position
				if math.abs(p.X - vPos.X) < 2 and math.abs(p.Z - vPos.Z) < 2 then
					local quarter = math.abs(((visual.rotY % 180) + 180) % 180 - 90) < 1e-3
					local square = math.abs(visual.rotY % 90) < 1e-3
					if square then
						local size = visual.part.Size
						pad.Size = Vector3.new(if quarter then size.Z else size.X, pad.Size.Y, if quarter then size.X else size.Z)
						report.padsResized += 1
					else
						table.insert(report.warnings, "a kit pad visual is not square to the track; its SpeedPad keeps its footprint")
					end
				end
			end
		end
	end

	-- 4b. The part-built Green Hill (no kit).
	if not kit then
		local rand = generator(20260926)
		local occupied = {}
		local function free(xLo, xHi, sLo, sHi, margin)
			for _, box in occupied do
				if xLo < box[2] + margin and xHi > box[1] - margin and sLo < box[4] + margin and sHi > box[3] - margin then
					return false
				end
			end
			return true
		end
		local function claim(xLo, xHi, sLo, sHi)
			table.insert(occupied, { xLo, xHi, sLo, sHi })
		end
		-- Grass islands with a sand rim just over the water, hugging the banks.
		local islands = {}
		local islandAttempts = 0
		while #islands < 12 and islandAttempts < 400 do
			islandAttempts += 1
			local side = if #islands % 2 == 0 then -1 else 1
			local width = rand(40, 90)
			local depth = rand(60, 170)
			local xMid = side * (GreenHill.BankOuter + width * 0.5 - 4)
			local sMid = rand(-150, 2300)
			if free(xMid - width * 0.5, xMid + width * 0.5, sMid - depth * 0.5, sMid + depth * 0.5, 10) then
				local chunk = chunkAt(sMid)
				local grassTop = WATER.Top + 1.6
				local island = f:part(chunk, "Island", Vector3.new(width, grassTop - GreenHill.WallBottom, depth),
					CFrame.new(world(sMid, xMid, (grassTop + GreenHill.WallBottom) * 0.5)), COLORS.Grass, { material = "Grass", group = "Islands" })
				f:grassTop(island, 10)
				f:part(chunk, "IslandBeach", Vector3.new(width + 8, 1.2, depth + 8), CFrame.new(world(sMid, xMid, WATER.Top + 0.2)), COLORS.Sand,
					{ material = "Sand", group = "Islands" })
				claim(xMid - width * 0.5 - 4, xMid + width * 0.5 + 4, sMid - depth * 0.5 - 4, sMid + depth * 0.5 + 4)
				table.insert(islands, { s = sMid, x = xMid, width = width, depth = depth, top = grassTop })
			end
		end

		-- Terraces: checkered bodies with grass caps standing in the water; some with a second tier.
		local function terrace(sMid, xMid, width, depth, top, tiers)
			local sLo, sHi = sMid - depth * 0.5, sMid + depth * 0.5
			local chunk = chunkAt(sMid)
			local bottom = GreenHill.WallBottom
			local body = f:part(chunk, "Terrace", Vector3.new(width, top - bottom, depth), CFrame.new(world(sMid, xMid, (top + bottom) * 0.5)),
				COLORS.Cliff, { material = "Slate", shadow = true, group = "Terraces" })
			f:checker(body, { "Front", "Back", "Left", "Right" }, 16)
			local cap = f:part(chunk, "TerraceTop", Vector3.new(width + 2, 2.4, depth + 2), CFrame.new(world(sMid, xMid, top + 1)),
				COLORS.Grass, { material = "Grass", shadow = true, group = "Terraces" })
			f:grassTop(cap, 10)
			if tiers == 2 then
				local w2, d2, top2 = width * 0.55, depth * 0.55, top + math.min(40, width * 0.45)
				local body2 = f:part(chunk, "TerraceUpper", Vector3.new(w2, top2 - top, d2), CFrame.new(world(sMid, xMid, (top2 + top) * 0.5 + 1)),
					COLORS.Cliff, { material = "Slate", shadow = true, group = "Terraces" })
				f:checker(body2, { "Front", "Back", "Left", "Right" }, 16)
				local cap2 = f:part(chunk, "TerraceUpperTop", Vector3.new(w2 + 2, 2.4, d2 + 2), CFrame.new(world(sMid, xMid, top2 + 2)),
					COLORS.Grass, { material = "Grass", shadow = true, group = "Terraces" })
				f:grassTop(cap2, 10)
			end
			claim(xMid - width * 0.5, xMid + width * 0.5, sLo, sHi)
		end
		local terraces = 0
		local attempts = 0
		while terraces < 18 and attempts < 600 do
			attempts += 1
			local side = if rand() < 0.5 then -1 else 1
			local far = rand()
			local width = rand(36, 96)
			local depth = rand(36, 110)
			local xMid = side * (70 + width * 0.5 + far * 300)
			local sMid = rand(-200, 2400)
			local top = 8 + far * 55 + rand(0, 18)
			if math.abs(xMid) + width * 0.5 < WATER.HalfX - 40
				and free(xMid - width * 0.5, xMid + width * 0.5, sMid - depth * 0.5, sMid + depth * 0.5, 18) then
				terrace(sMid, xMid, width, depth, top, if far > 0.55 and rand() < 0.6 then 2 else 1)
				terraces += 1
			end
		end
		-- Far towers on the horizon (the reference's tall checkered pillars).
		for index, spot in { { -520, 300 }, { 560, 900 }, { -600, 1500 }, { 540, 2150 } } do
			local width = 50 + index * 6
			terrace(spot[2], spot[1], width, width, 90 + index * 12, 1)
		end

		-- Palms: a two-piece trunk leaning away from the track and five drooping fronds; every piece
		-- carries the RacePalmWind attributes (one tree = one WindTree).
		local palmCount = 0
		local function palm(s, x, groundY, height, lowPower, droopMax)
			palmCount += 1
			local side = if x < 0 then -1 else 1
			local chunk = chunkAt(s)
			local base = world(s, x, groundY)
			local lean = math.rad(rand(4, 10))
			-- Lean away from the track: rotate about Z toward +-X.
			local up1 = CFrame.new(base) * CFrame.Angles(0, 0, -side * lean)
			local l1 = height * 0.55
			local l2 = height - l1
			local seg1 = up1 * CFrame.new(0, l1 * 0.5, 0) * CFrame.Angles(0, 0, math.rad(90))
			local top1 = up1 * CFrame.new(0, l1, 0)
			local up2 = top1 * CFrame.Angles(0, 0, -side * lean * 0.8)
			local seg2 = up2 * CFrame.new(0, l2 * 0.5, 0) * CFrame.Angles(0, 0, math.rad(90))
			local crown = (up2 * CFrame.new(0, l2, 0)).Position
			local opts = { material = "Wood", shadow = true, lowPower = lowPower, group = "Palms" }
			local pieces = {
				f:part(chunk, "PalmTrunk", Vector3.new(l1 + 0.3, 1.9, 1.9), seg1, COLORS.Trunk, table.clone(opts)),
				f:part(chunk, "PalmTrunk", Vector3.new(l2 + 0.3, 1.5, 1.5), seg2, COLORS.Trunk, table.clone(opts)),
			}
			pieces[1]:SetAttribute("WindKind", "trunk")
			pieces[2]:SetAttribute("WindKind", "trunk")
			local frondOpts = { material = "SmoothPlastic", shadow = true, lowPower = lowPower, group = "Palms" }
			local spin = rand(0, 2 * math.pi)
			for frond = 1, 4 do
				local yaw = spin + frond * (2 * math.pi / 4) + rand(-0.25, 0.25)
				local droop = math.rad(rand(15, droopMax or 30))
				local length = rand(8, 9.5)
				local cf = CFrame.new(crown) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(-droop, 0, 0) * CFrame.new(0, 0, -length * 0.5)
				local leaf = f:part(chunk, "PalmFrond", Vector3.new(2.2, 0.3, length), cf, COLORS.Frond, table.clone(frondOpts))
				leaf:SetAttribute("WindKind", "canopy")
				table.insert(pieces, leaf)
			end
			for _, piece in pieces do
				piece:SetAttribute("WindBase", base)
				piece:SetAttribute("WindCrown", crown)
				piece:SetAttribute("WindTree", palmCount)
				piece:SetAttribute("WindPhase", (palmCount * 0.83) % (2 * math.pi))
				piece:AddTag("RacePalmWind")
			end
		end
		-- On the banks just past the fences, leaning out.
		local bankPalms = { { 20, -1 }, { 150, 1 }, { 470, -1 }, { 960, 1 }, { 1110, -1 }, { 1430, 1 }, { 1880, -1 }, { 2040, 1 } }
		for _, spot in bankPalms do
			local s, side = spot[1], spot[2]
			palm(s, side * rand(44, 56), ground(s, side) + GreenHill.VergeLift - 0.1, rand(19, 22), false, 25)
		end
		-- On the islands (the far ones hidden on phones).
		for index, island in islands do
			if index <= 6 then
				palm(island.s + rand(-island.depth * 0.25, island.depth * 0.25), island.x + (if island.x < 0 then -1 else 1) * island.width * 0.2,
					island.top, rand(15, 22), true)
			end
		end

		-- Sunflowers and bushes on the banks (between the fence and the water), hidden on phones.
		local flowerSpots = { { 90, -1 }, { 260, 1 }, { 540, -1 }, { 700, 1 }, { 1010, 1 }, { 1300, -1 }, { 1500, 1 }, { 1760, -1 } }
		for _, spot in flowerSpots do
			local s, side = spot[1], spot[2]
			local x = side * rand(42, 60)
			local g = ground(s, side) + GreenHill.VergeLift
			local chunk = chunkAt(s)
			local stemHeight = rand(4.5, 6)
			local opts = { material = "SmoothPlastic", lowPower = true, group = "Plants" }
			f:part(chunk, "FlowerStem", Vector3.new(stemHeight, 0.45, 0.45), CFrame.new(world(s, x, g + stemHeight * 0.5)) * CFrame.Angles(0, 0, math.rad(90)),
				COLORS.Stem, table.clone(opts))
			-- The head faces the track (a disc's axis is its X).
			local head = CFrame.new(world(s, x, g + stemHeight + 0.4)) * CFrame.Angles(0, 0, -side * math.rad(15))
			f:part(chunk, "FlowerPetals", Vector3.new(0.35, 3.4, 3.4), head, COLORS.Petal, { material = "SmoothPlastic", shape = "Cylinder", lowPower = true, group = "Plants" })
			f:part(chunk, "FlowerSeeds", Vector3.new(0.4, 1.7, 1.7), head * CFrame.new(-side * 0.1, 0, 0), COLORS.Seed,
				{ material = "SmoothPlastic", shape = "Cylinder", lowPower = true, group = "Plants" })
		end
		for index = 1, 10 do
			local side = if index % 2 == 0 then 1 else -1
			local s = -40 + (index - 1) * 220 + rand(-20, 20)
			local size = rand(3.5, 6.5)
			local x = side * rand(42.5, 62)
			local g = ground(math.clamp(s, GreenHill.S0, GreenHill.S1), side) + GreenHill.VergeLift
			f:part(chunkAt(s), "Bush", Vector3.new(size, size, size), CFrame.new(world(s, x, g + size * 0.25)), if index % 3 == 0 then COLORS.GrassDark else COLORS.Bush,
				{ material = "Grass", shape = "Ball", lowPower = true, group = "Plants" })
		end
	end

	-- 4c. The race art every map needs (unless the kit's layout brings its own).
	-- Speed pads: a red plate, two yellow chevrons pointing down the track, steel side rails.
	if kitHas("speedpad") or kitHas("boostpad") then
		table.insert(report.replaced, "speed pad art")
	else
		for _, pad in arena.SpeedPads:GetDescendants() do
			if pad:IsA("BasePart") and pad.Name == "SpeedPad" then
				local size = pad.Size
				local top = size.Y * 0.5
				local chunk = chunkAt(ORIGIN.Z - pad.CFrame.Position.Z)
				f:part(chunk, "PadPlate", Vector3.new(size.X - 0.6, 0.14, size.Z - 0.6), pad.CFrame * CFrame.new(0, top - 0.16, 0), COLORS.PadRed,
					{ material = "SmoothPlastic", group = "Pads" })
				for row = -1, 1, 2 do
					for sideArm = -1, 1, 2 do
						-- Each arm from the plate's edge behind to its centre ahead (a V toward -Z).
						local arm = pad.CFrame * CFrame.new(sideArm * size.X * 0.17, top - 0.04, row * size.Z * 0.2)
							* CFrame.Angles(0, sideArm * math.rad(40), 0)
						f:part(chunk, "PadChevron", Vector3.new(1.5, 0.06, size.X * 0.42), arm, COLORS.PadYellow, { material = "Neon", group = "Pads" })
					end
				end
				for sideRail = -1, 1, 2 do
					f:part(chunk, "PadRail", Vector3.new(0.6, 0.36, size.Z), pad.CFrame * CFrame.new(sideRail * (size.X * 0.5 + 0.3), 0.18 - size.Y * 0.5, 0),
						COLORS.Steel, { material = "Metal", group = "Pads" })
				end
			end
		end
	end

	-- Spike tiles: a black two-plate star on each (Astra's tile meshes were local content).
	-- 2026-09-26: the stars are the tile's own children, Persistent with it (not a decor chunk).
	if kitHas("spike") then
		table.insert(report.replaced, "spike stars")
	else
		for _, tile in arena.Spikes:GetChildren() do
			if tile:IsA("BasePart") then
				local star = tile.CFrame * CFrame.new(0, tile.Size.Y * 0.5 + 0.04, 0)
				f:part(tile, "TileStar", Vector3.new(4.6, 0.08, 4.6), star, COLORS.Star, { group = "Spikes" })
				f:part(tile, "TileStar", Vector3.new(4.6, 0.08, 4.6), star * CFrame.Angles(0, math.rad(45), 0), COLORS.Star, { group = "Spikes" })
			end
		end
	end

	-- The start: a white line, and a checkered beam over the five lights (its bottom Overhead+).
	f:part(chunkAt(0), "StartLine", Vector3.new(TRACK.Width, 0.12, 1), CFrame.new(world(0.5, 0, 0.06)), COLORS.White, { group = "Start" })
	if kitHas("start") then
		table.insert(report.replaced, "start beam")
	else
		local lightsY = 12
		for _, light in arena.Structure.StartGantry:GetChildren() do
			if light:IsA("BasePart") then
				lightsY = math.max(lightsY, light.CFrame.Position.Y - ORIGIN.Y + light.Size.Y * 0.5)
			end
		end
		local beamBottom = math.max(GreenHill.Overhead + 0.2, lightsY + 0.5)
		local beam = f:part(chunkAt(0), "StartBeam", Vector3.new(90, 3, 1.4), CFrame.new(world(0, 0, beamBottom + 1.5)), COLORS.Cliff,
			{ material = "Slate", group = "Start" })
		f:checker(beam, { "Front", "Back" }, 6)
		for side = -1, 1, 2 do
			local post = f:part(chunkAt(0), "StartPost", Vector3.new(2.4, beamBottom + 3 + 1, 2.4), CFrame.new(world(0, side * 43.5, (beamBottom + 3 - 1) * 0.5)),
				COLORS.Cliff, { material = "Slate", group = "Start" })
			f:checker(post, { "Front", "Back", "Left", "Right" }, 4.8)
		end
	end

	-- The finish: a checkered strip at s = Length and an arch with FINISH on both faces.
	local finishChunk = chunkAt(TRACK.Length)
	local strip = f:part(finishChunk, "FinishLine", Vector3.new(TRACK.Width, 0.1, 6), CFrame.new(world(TRACK.Length, 0, 0.05)), COLORS.White, { group = "Finish" })
	f:texture(strip, T.Checker, "Top", COLORS.White, 0, 6)
	if kitHas("finish") then
		table.insert(report.replaced, "finish arch")
	else
		local bottom = GreenHill.Overhead + 1
		local banner = f:part(finishChunk, "FinishBanner", Vector3.new(90, 5, 1.2), CFrame.new(world(TRACK.Length, 0, bottom + 2.5)), COLORS.White,
			{ material = "SmoothPlastic", group = "Finish" })
		for _, face in { "Front", "Back" } do
			local gui = Instance.new("SurfaceGui")
			gui.Name = "Finish" .. face
			gui.Face = Enum.NormalId[face]
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			gui.PixelsPerStud = 20
			gui.LightInfluence = 0
			local label = Instance.new("TextLabel")
			label.Name = "Text"
			label.BackgroundTransparency = 0
			label.BackgroundColor3 = rgb(COLORS.White)
			label.BorderSizePixel = 0
			label.Size = roblox.UDim2.fromScale(1, 1)
			label.FontFace = roblox.Font.fromEnum(Enum.Font.FredokaOne)
			label.Text = "FINISH"
			label.TextScaled = true
			label.TextColor3 = rgb(COLORS.Gold)
			label.TextStrokeColor3 = rgb(COLORS.Navy)
			label.TextStrokeTransparency = 0
			label.Parent = gui
			gui.Parent = banner
		end
		for side = -1, 1, 2 do
			local post = f:part(finishChunk, "FinishPost", Vector3.new(2.4, bottom + 5 + 1, 2.4), CFrame.new(world(TRACK.Length, side * 43.5, (bottom + 5 - 1) * 0.5)),
				COLORS.Cliff, { material = "Slate", group = "Finish" })
			f:checker(post, { "Front", "Back", "Left", "Right" }, 4.8)
		end
	end

	-- The ORB (RaceArenaVisuals spins RaceOrb.Shell; LowPowerGraphics calms RaceOrb.Core.Sparks
	-- when there is one: none here, its only texture would be engine content).
	do
		local orb = arena.RaceOrb
		local center = orb.CFrame
		local core = f:part(orb, "Core", Vector3.new(20, 20, 20), center, COLORS.Orb, { material = "Neon", shape = "Ball", group = "Orb" })
		f:part(orb, "Shell", Vector3.new(28, 28, 28), center, COLORS.Orb, { material = "ForceField", shape = "Ball", group = "Orb" })
		local light = Instance.new("PointLight")
		light.Name = "Glow"
		light.Range = 60
		light.Brightness = 2
		light.Color = rgb(COLORS.Orb)
		light.Shadows = false
		light.Parent = core
		local marker = Instance.new("BillboardGui")
		marker.Name = "OrbMarker"
		marker.Adornee = core
		marker.Size = roblox.UDim2.fromOffset(180, 56)
		marker.StudsOffset = Vector3.new(0, 18, 0)
		marker.AlwaysOnTop = true
		marker.MaxDistance = 2600
		marker.LightInfluence = 0
		local label = Instance.new("TextLabel")
		label.Name = "Text"
		label.BackgroundTransparency = 1
		label.Size = roblox.UDim2.fromScale(1, 1)
		label.FontFace = roblox.Font.fromEnum(Enum.Font.FredokaOne)
		label.Text = "▼ ORB"
		label.TextScaled = true
		label.TextColor3 = rgb(COLORS.Gold)
		label.TextStrokeColor3 = rgb(COLORS.Navy)
		label.TextStrokeTransparency = 0
		label.Parent = marker
		marker.Parent = core
	end

	barriers.Parent = arena
	banks.Parent = arena
	decor.Parent = arena
	-- 2026-09-26 (owner): every other boundary too: Astra's 220 short invisible Walls, the
	-- StartGate collider, the kit's fence sections (RaceArenaBuilder.IsWallPart). Never the floor.
	report.wallParts = RaceArenaBuilder.ApplyWallPhysics(arena, roblox)

	-- Counts and attributes.
	local total = #partsOf(arena) - (if arena:IsA("BasePart") then 1 else 0)
	report.totalParts = total
	local lowPower = 0
	for _, part in partsOf(arena) do
		if part:HasTag("RaceDecorLowPower") then
			lowPower += 1
		end
	end
	report.lowPowerParts = lowPower
	report.addedParts = total - gameplayParts
	report.partParts = f.count
	report.groups = f.groups
	report.chunks = #sortedKeys(chunks)
	arena:SetAttribute("RaceArenaStyle", "GreenHill")
	arena:SetAttribute("RaceArenaGreenHill", GreenHill.Version)
	arena:SetAttribute("RaceArenaParts", total)
	arena:SetAttribute("BasePartCount", total)
	arena:SetAttribute("ResourceMode", if kit then "Online: GreenHillKit meshes + parts" else "Online: parts and lobby textures")
	arena:SetAttribute("RaceArenaKit", report.kit)
	return arena, report
end

-- What an arena in a place (after the build's round trip) breaks of the conversion's promises:
-- the gameplay contract names, no local content, the barriers, the budget. Empty = fine.
function GreenHill.Verify(arena)
	local problems = {}
	local function need(ok, message)
		if not ok then
			table.insert(problems, message)
		end
	end
	for _, name in GreenHill.GameplayNames do
		need(arena:FindFirstChild(name) ~= nil, "no " .. name)
	end
	if #problems > 0 then
		return problems
	end
	local structure = arena.Structure
	for _, name in { "StartGate", "StopBar" } do
		local part = structure:FindFirstChild(name)
		need(part ~= nil and part:IsA("BasePart"), "no Structure." .. name)
	end
	local gantry = structure:FindFirstChild("StartGantry")
	for light = 1, 5 do
		need(gantry ~= nil and gantry:FindFirstChild("Light" .. light) ~= nil, "no Structure.StartGantry.Light" .. light)
	end
	for spot = 1, 4 do
		need(arena.FinishGate:FindFirstChild("ConfettiSpot_" .. spot) ~= nil, "no FinishGate.ConfettiSpot_" .. spot)
	end
	local pads = 0
	for _, pad in arena.SpeedPads:GetDescendants() do
		if pad:IsA("BasePart") and pad.Name == "SpeedPad" then
			pads += 1
		end
	end
	need(pads > 0, "no SpeedPad")
	need(#floorParts(arena) > 0, "no visible collidable TrackFloor part")
	-- 2026-09-26: every tile where Update4Config puts it, not only as many (a layout change
	-- leaves a place's arena stale until the build's --greenhill makes it again).
	local expected = {}
	for _, tile in RaceTrack.SpikeTiles() do
		expected[string.format("SpikeTile_%d_%d_%d", tile.field, tile.row, tile.lane)] = tile
	end
	local tiles, misplaced = 0, 0
	for _, tile in arena.Spikes:GetChildren() do
		if tile:IsA("BasePart") then
			tiles += 1
			local want = expected[tile.Name]
			local p = tile.CFrame.Position
			if not want or math.abs(ORIGIN.Z - p.Z - want.s) > 0.01 or math.abs(p.X - ORIGIN.X - want.x) > 0.01 then
				misplaced += 1
			end
		end
	end
	need(tiles == #RaceTrack.SpikeTiles() and misplaced == 0, string.format("%d spike tiles, %d not where Update4Config says (%d tiles): rebuild the arena with --greenhill",
		tiles, misplaced, #RaceTrack.SpikeTiles()))
	local uris = GreenHill.LocalContent(arena)
	need(#uris == 0, "local content: " .. tostring(uris[1]))
	local barriers = arena:FindFirstChild("Barriers")
	need(barriers ~= nil and barriers:FindFirstChild("BackCap") ~= nil and barriers:FindFirstChild("EndCap") ~= nil, "no Barriers with BackCap and EndCap")
	if barriers then
		for _, wall in barriers:GetChildren() do
			if wall:IsA("BasePart") then
				local top = wall.CFrame.Position.Y + wall.Size.Y * 0.5 - ORIGIN.Y
				need(wall.CanCollide and wall.Transparency >= 1 and top >= GreenHill.WallClearance, "barrier " .. wall.Name .. " is not a tall invisible wall")
			end
		end
	end
	local total = #partsOf(arena)
	if arena:GetAttribute("RaceArenaKit") == true then
		local shown = 0
		for _, part in partsOf(arena) do
			if not part:HasTag("RaceDecorLowPower") then
				shown += 1
			end
		end
		need(total <= GreenHill.KitTotalBudget, string.format("%d parts (budget with the kit %d)", total, GreenHill.KitTotalBudget))
		need(shown <= GreenHill.KitShownBudget, string.format("%d parts phones draw (budget %d)", shown, GreenHill.KitShownBudget))
	else
		need(total <= GreenHill.TotalBudget, string.format("%d parts (budget %d)", total, GreenHill.TotalBudget))
	end
	need(arena:GetAttribute("RaceArenaParts") == total, "RaceArenaParts attribute")
	return problems
end

-- 2026-09-26 (owner): what an arena breaks of the frictionless boundaries: every
-- RaceArenaBuilder.IsWallPart part with exactly WallPhysics, and every other collidable part at
-- the track's edges (|x| >= FloorHalf - 1, not the floor, the pads or the spikes) one of them; the
-- floor keeps its own friction. Empty = fine. Kept out of Verify: an arena built before this
-- change gets the physics from RaceServer at runtime (RaceArenaBuilder.ApplyWallPhysics), so the
-- build's check of a kept arena must not fail on it; --greenhill bakes them in.
function GreenHill.WallPhysicsProblems(arena)
	local problems = {}
	local walls, wrong, missed = 0, {}, {}
	for _, part in partsOf(arena) do
		if part ~= arena then
			local wall = RaceArenaBuilder.IsWallPart(part, arena)
			if wall then
				walls += 1
				if not RaceArenaBuilder.HasWallPhysics(part) then
					table.insert(wrong, part.Name)
				end
			elseif part.CanCollide then
				local floorLike = false
				local node = part.Parent
				while node and node ~= arena do
					floorLike = floorLike or RaceArenaBuilder.FloorContainers[node.Name] == true
					node = node.Parent
				end
				local x = part.CFrame.Position.X - ORIGIN.X
				if not floorLike and math.abs(x) >= GreenHill.FloorHalf - 1 then
					table.insert(missed, part:GetFullName())
				end
			end
		end
	end
	if walls == 0 then
		table.insert(problems, "no race wall at all")
	end
	if #wrong > 0 then
		table.insert(problems, string.format("%d of %d race walls without WallPhysics (e.g. %s)", #wrong, walls, wrong[1]))
	end
	if #missed > 0 then
		table.insert(problems, string.format("%d collidable parts at the track's edges are not race walls (e.g. %s)", #missed, missed[1]))
	end
	for _, part in floorParts(arena) do
		local physics = part.CustomPhysicalProperties
		if physics ~= nil and physics.Friction < 0.2 then
			table.insert(problems, "the floor part " .. part.Name .. " lost its friction")
			break
		end
	end
	return problems
end

-- One line for the build's list / notes.
function GreenHill.Describe(report)
	local groups = {}
	for _, name in sortedKeys(report.groups or {}) do
		table.insert(groups, name .. " " .. report.groups[name])
	end
	return string.format("%d parts (%d gameplay kept + %d added: %s%s; fence %s), %d local-content parts and %d meshes removed%s",
		report.totalParts, report.gameplayParts, report.addedParts, table.concat(groups, ", "),
		if report.kit then string.format(", kit %d pieces / %d parts (%d low-power: %d parts drawn on phones), %d SpeedPads fitted to the kit's pad art",
			report.kitPlacements, report.kitParts, report.kitLowPowerParts, report.totalParts - report.lowPowerParts, report.padsResized or 0)
				.. (if (report.kitImportYawDegrees or 0) ~= 0 then string.format(" (the import's %g-degree turn undone)", report.kitImportYawDegrees) else "")
			else ", no kit (part-built look)",
		report.fence, report.removedParts, report.removedObjects,
		if #report.skipped > 0 then ", " .. #report.skipped .. " layout pieces skipped" else "")
end

return GreenHill
