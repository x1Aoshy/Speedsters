-- Services/Race/RaceArenaBuilder.luau — Update 4 (2026-09-25): builds the race arena and the
-- lobby Race Gate from Update4Config (the build authors both into the three places with Lune;
-- Gameplay/RaceServer builds them at runtime only when a place lacks them).
--   Build(parent, env)              -> Model Workspace.RaceArena
--   BuildGate(parent, worldKey, env) -> Model Workspace.RaceGate (pad RaceGatePad, sign RaceGateSign)
-- env = { Instance, Vector3, CFrame, Color3, Enum, UDim2, NumberRange, Font? }: the Roblox globals, or the same
-- constructors from @lune/roblox, so the build never needs a running game. Optional: RaceAssets
-- (the art folder, false = none), ColorSequence (confetti colours), Warn (asset warnings).
--
-- Layout (RaceTrack frame: s = distance past the start line along -Z, x across, y above the
-- floor top; forward is -Z, the default look vector, so no CFrame.lookAt: it is wrong in Lune):
--   RaceArena (attribute RaceArenaVersion = 1)
--     Structure  (Persistent) floor slabs, invisible side walls, StartGate collider, back and end
--                walls, StopBar, StartGantry (Light1..5): everything the race needs to run and
--                that the client animates, so it is always there on every device.
--     Decor      Chunk_k models (Atomic, one per 240 studs): slot plates, start line, curbs,
--                spike tiles, distance gantries, finish; streamed in and out as a whole.
--     RaceOrb    (Persistent) the goal marker past the finish.
--     SpeedPads  (Persistent, 2026-09-25) three flat "SpeedPad" parts with red chevrons (Boost /
--                Seconds attributes), read by the race server at every staging.
-- 2026-09-25: StopBar and StartGantry live in Structure, not in a decor chunk: the client tweens
-- the bar and lights the gantry at GO, and a chunk still streaming in would miss the start.
-- Every part is Anchored with CastShadow off and carries RaceArenaPart; decor never collides,
-- touches or queries. Part budget: <= 330 with a chevron texture, <= 600 with part chevrons
-- (tagged RaceDecorLowPower so LowPowerGraphics can hide them on phones).
--
-- 2026-09-25 (race art): the owner found the blocks "a 2015 prototype". Blender models
-- (audit/generate_race_assets.py -> design/race/fbx, imported once in Studio, saved as
-- design/race/RaceAssets.rbxm, put in ServerStorage.RaceAssets by the build) replace them when
-- present; see design/race/IMPORTAR_EN_STUDIO.md. env.RaceAssets = that folder (false = none);
-- when env has no RaceAssets key and this runs in Roblox, ServerStorage.RaceAssets is used.
-- Each model is checked on its own (every MeshPart named in AssetSpec, the right shape); a model
-- that fails falls back to the part geometry below, the others still use their meshes:
--   RaceStartGantry  -> Structure.StartGantry (its __Light_k spheres renamed Light1..5, the
--                       contract RaceArenaVisuals colours) and, without lights, the 500/1000/1500
--                       and LAST 200! gantries
--   RaceFinishGantry -> Decor FinishGate (ConfettiSpot_1..4 attachments with a Rate-0 Confetti
--                       emitter: :Emit(n) from any script)
--   RaceTrackBarrier -> 39 tiles a side (x +-38.7, its inner face on the invisible wall's face),
--                       instead of the curbs; the invisible walls are unchanged
--   RaceLobbyBooth   -> (retired 2026-09-26: the gate is The Flash's arch now, parts or the
--                       FlashGateKit meshes, see BuildGate; the spec stays for the generator and its tests)
-- Every mesh is cloned, resized to the spec (so the importer's unit choice does not matter),
-- painted from AssetRoles and placed part by part from the spec (never GetPivot/PivotTo: Lune
-- has none). RaceGate.FlashSpot (every gate since 2026-09-26): an invisible 2 x 0.2 x 2 marker
-- whose bottom is the floor under The Flash's feet, LookVector toward the players (the contract
-- LobbyNpcs reads).
local U4 = if typeof(script) == "Instance"
	then require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Update4Config", 10))
	else require("../../../ReplicatedStorage/Shared/Update4Config")
local RaceTrack = if typeof(script) == "Instance"
	then require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("RaceTrack", 10))
	else require("../../../ReplicatedStorage/Shared/RaceTrack")

local RACE = U4.Race
local TRACK = RACE.Track
local ORIGIN = RACE.Arena.Origin

local RaceArenaBuilder = {}
RaceArenaBuilder.Version = 1
RaceArenaBuilder.BudgetWithTexture = 330
RaceArenaBuilder.BudgetWithParts = 600
RaceArenaBuilder.ChunkLength = TRACK.DecorChunk
RaceArenaBuilder.WallX = 38.1
RaceArenaBuilder.WallHeight = 16
RaceArenaBuilder.EndWallS = TRACK.Length + TRACK.RunOut
RaceArenaBuilder.StartS = -TRACK.StagingDepth
RaceArenaBuilder.ChevronEvery = 48
RaceArenaBuilder.GatePadSize = 12
-- 2026-09-25: the fallback arena's speed pads (s of their centres; clear of the spike fields at
-- 300 / 750 / 1200 / 1650 + 40) and their size (the 2 centre lanes, 16 long, 0.2 thick).
RaceArenaBuilder.PadSpots = { 450, 1050, 1500 }
RaceArenaBuilder.PadSize = { 18, 0.2, 16 }

local FLOOR_COLOR = { 0, 186, 240 }
local STAGING_COLOR = { 0, 160, 215 }
local NAVY = { 18, 34, 78 }
local CYAN_NEON = { 0, 230, 255 }
local WHITE = { 255, 255, 255 }
local CURB = { 245, 245, 250 }
local SPIKE_BASE = { 205, 208, 214 }
local SPIKE_STAR = { 25, 25, 30 }
local STOP_RED = { 225, 35, 35 }
local GOLD = { 255, 200, 40 }
local ORB_CORE = { 150, 235, 255 }

----------------------------------------------------------------------
-- Race art assets (2026-09-25)
----------------------------------------------------------------------
RaceArenaBuilder.AssetModels = { "RaceLobbyBooth", "RaceStartGantry", "RaceFinishGantry", "RaceTrackBarrier" }
RaceArenaBuilder.BudgetWithAssets = 600
-- Barrier module centre: its 2.2-wide body's inner face lands on the invisible wall's face (37.6)
-- and its footing reaches back to the floor edge (36).
RaceArenaBuilder.BarrierX = 38.7
RaceArenaBuilder.StartGantryS = -2
-- An imported mesh may be uniformly scaled (the importer's unit choice); anything else (axes
-- swapped, another mesh) is refused. Relative + absolute slack per axis, in spec studs.
RaceArenaBuilder.AssetShapeTolerance = 0.03
RaceArenaBuilder.AssetShapeSlack = 0.03
RaceArenaBuilder.FlashSpotSize = { 2, 0.2, 2 }

-- BEGIN GENERATED RaceAssetSpec (audit/generate_race_assets.py 2026-09-25; do not edit by hand)
-- Role -> look of every asset MeshPart (Color RGB 0-255, Material, optional Transparency/Reflectance).
RaceArenaBuilder.AssetRoles = {
	Accent = { Color = { 0, 229, 255 }, Material = "Neon" },
	Base = { Color = { 238, 243, 250 }, Material = "SmoothPlastic" },
	Checker_Black = { Color = { 22, 22, 28 }, Material = "SmoothPlastic" },
	Checker_White = { Color = { 248, 248, 250 }, Material = "SmoothPlastic" },
	Glass = { Color = { 130, 225, 255 }, Material = "Glass", Transparency = 0.45 },
	Gold = { Color = { 255, 193, 37 }, Material = "SmoothPlastic", Reflectance = 0.15 },
	Lamp = { Color = { 255, 246, 214 }, Material = "Neon" },
	Light = { Color = { 60, 18, 18 }, Material = "Neon" },
	Panel = { Color = { 14, 20, 38 }, Material = "SmoothPlastic" },
	Red = { Color = { 220, 34, 44 }, Material = "SmoothPlastic" },
	Trim = { Color = { 24, 38, 86 }, Material = "SmoothPlastic" },
}
-- Per model: every MeshPart (name, role, bounding-box centre and size in the model's frame,
-- studs; x right, y up, -z = the model's front for the booth / the racers' forward for the
-- track pieces), the markers and the invisible colliders.
RaceArenaBuilder.AssetSpec = {
	RaceLobbyBooth = {
		Size = { 35.68, 22.731, 12 }, Triangles = 3610,
		Parts = {
			{ Name = "RaceLobbyBooth__Accent", Role = "Accent", Center = { -2.872, 11.35, -1.738 }, Size = { 35.505, 22.71, 11.525 } },
			{ Name = "RaceLobbyBooth__Base", Role = "Base", Center = { -4.475, 9.212, -1.8 }, Size = { 32.65, 18.475, 12 } },
			{ Name = "RaceLobbyBooth__Glass", Role = "Glass", Center = { -16.6, 3.808, -1.211 }, Size = { 2.2, 1.329, 0.564 } },
			{ Name = "RaceLobbyBooth__Gold", Role = "Gold", Center = { 0.036, 11.358, -1.8 }, Size = { 2.298, 20.617, 4.847 } },
			{ Name = "RaceLobbyBooth__Panel", Role = "Panel", Center = { 0, 14.35, 0.4 }, Size = { 10.4, 3.2, 0.4 } },
			{ Name = "RaceLobbyBooth__Red", Role = "Red", Center = { -2.554, 11.75, 0.022 }, Size = { 34.547, 21.5, 5.335 } },
			{ Name = "RaceLobbyBooth__Trim", Role = "Trim", Center = { -2.918, 8.483, -1.773 }, Size = { 34.436, 15.006, 6.855 } },
		},
		Markers = {
			FlashSpot = { -16.6, 1, 0.9 },
			PadTrigger = { Center = { 0, 0.2, 0 }, Size = { 12, 0.4, 12 } },
			RacePanel = { 0, 14.35, 0.4 },
			SignAnchor = { 0, 26, 0.4 },
		},
		Colliders = {
			{ Name = "PodiumStep", Shape = "Cylinder", Center = { 0, 0.25, -1.8 }, Radius = 6, Height = 0.5 },
			{ Name = "PodiumTop", Shape = "Cylinder", Center = { 0, 0.5, -1.8 }, Radius = 5, Height = 1 },
			{ Name = "PillarL", Shape = "Box", Center = { -10.42, 5, 0.65 }, Size = { 2.95, 10, 4.3 } },
			{ Name = "PillarR", Shape = "Box", Center = { 10.42, 5, 0.65 }, Size = { 2.95, 10, 4.3 } },
			{ Name = "KioskStep", Shape = "Cylinder", Center = { -16.6, 0.25, 0 }, Radius = 4.2, Height = 0.5 },
			{ Name = "KioskTop", Shape = "Cylinder", Center = { -16.6, 0.5, 0 }, Radius = 3.5, Height = 1 },
			{ Name = "Counter", Shape = "Box", Center = { -16.6, 2, -1.3 }, Size = { 6.6, 2, 2.8 } },
		},
	},
	RaceStartGantry = {
		Size = { 94.6, 31.4, 12.2 }, Triangles = 2880,
		Parts = {
			{ Name = "RaceStartGantry__Accent", Role = "Accent", Center = { 0, 13.874, 0 }, Size = { 85.132, 28.332, 10.9 } },
			{ Name = "RaceStartGantry__Base", Role = "Base", Center = { 0, 15.3, 0 }, Size = { 91.014, 31.4, 12.2 } },
			{ Name = "RaceStartGantry__Gold", Role = "Gold", Center = { 0, 16.9, 2.3 }, Size = { 23.524, 3.524, 0.424 } },
			{ Name = "RaceStartGantry__Light_1", Role = "Light", Center = { -10, 16.9, 2.35 }, Size = { 2.283, 2.4, 2.4 } },
			{ Name = "RaceStartGantry__Light_2", Role = "Light", Center = { -5, 16.9, 2.35 }, Size = { 2.283, 2.4, 2.4 } },
			{ Name = "RaceStartGantry__Light_3", Role = "Light", Center = { 0, 16.9, 2.35 }, Size = { 2.283, 2.4, 2.4 } },
			{ Name = "RaceStartGantry__Light_4", Role = "Light", Center = { 5, 16.9, 2.35 }, Size = { 2.283, 2.4, 2.4 } },
			{ Name = "RaceStartGantry__Light_5", Role = "Light", Center = { 10, 16.9, 2.35 }, Size = { 2.283, 2.4, 2.4 } },
			{ Name = "RaceStartGantry__Panel", Role = "Panel", Center = { 0, 21.45, 2.35 }, Size = { 26, 4.4, 0.3 } },
			{ Name = "RaceStartGantry__Trim", Role = "Trim", Center = { 0, 13.9, 0 }, Size = { 94.6, 27.8, 11 } },
		},
		Markers = {
		},
		Colliders = {
		},
	},
	RaceFinishGantry = {
		Size = { 94, 32.319, 7.6 }, Triangles = 3480,
		Parts = {
			{ Name = "RaceFinishGantry__Accent", Role = "Accent", Center = { 0, 11.259, 2.151 }, Size = { 88.4, 22.521, 0.443 } },
			{ Name = "RaceFinishGantry__Base", Role = "Base", Center = { 0, 14.492, -0.1 }, Size = { 93, 29.016, 4.6 } },
			{ Name = "RaceFinishGantry__Checker_Black", Role = "Checker_Black", Center = { 0, 25, 2.375 }, Size = { 86.301, 6.8, 0.35 } },
			{ Name = "RaceFinishGantry__Checker_White", Role = "Checker_White", Center = { -0.362, 25, 2.625 }, Size = { 84.491, 6.04, 0.25 } },
			{ Name = "RaceFinishGantry__Lamp", Role = "Lamp", Center = { 0, 30.296, 1.298 }, Size = { 61.7, 1.588, 0.839 } },
			{ Name = "RaceFinishGantry__Panel", Role = "Panel", Center = { 0, 25, 2.35 }, Size = { 23, 6.4, 0.3 } },
			{ Name = "RaceFinishGantry__Trim", Role = "Trim", Center = { 0, 16.152, 0 }, Size = { 94, 32.303, 7.6 } },
		},
		Markers = {
			ConfettiSpot_1 = { -33, 20.5, 0 },
			ConfettiSpot_2 = { -11, 20.5, 0 },
			ConfettiSpot_3 = { 11, 20.5, 0 },
			ConfettiSpot_4 = { 33, 20.5, 0 },
		},
		Colliders = {
		},
	},
	RaceTrackBarrier = {
		Size = { 5.4, 4.98, 56 }, Triangles = 1412,
		Parts = {
			{ Name = "RaceTrackBarrier__Accent", Role = "Accent", Center = { 0, 2.89, 0 }, Size = { 2.72, 4.18, 54.8 } },
			{ Name = "RaceTrackBarrier__Base", Role = "Base", Center = { 0, 2.25, 0 }, Size = { 2.2, 3.6, 56 } },
			{ Name = "RaceTrackBarrier__Trim", Role = "Trim", Center = { 0, 2.4, 0 }, Size = { 5.4, 4.8, 56 } },
		},
		Markers = {
		},
		Colliders = {
		},
	},
}
-- END GENERATED RaceAssetSpec

----------------------------------------------------------------------
-- Wall physics
----------------------------------------------------------------------
-- 2026-09-26 (owner): a racer brushing a side wall, a barrier, a curb or any lateral collider at
-- race speed lost its momentum and stopped (the wall's friction dragged the body). Every race
-- boundary a racer can touch (the invisible side walls, the barriers, the end caps / back and end
-- walls, the StartGate collider, the bank lips, fences, curbs, rails and colliders) gets these
-- frictionless physics; the floor keeps its own (normal) friction. Roblox averages the two
-- frictions of a contact by their FrictionWeights: at 100 (the maximum) the wall's zero weighs as
-- much as the racer body's own 0.08 (weight 100, Movement/InstantMovementController), so a body
-- on a wall slides at 0.04 (it was ~0.082 against a default wall). The builders stamp them
-- (Lune serializes CustomPhysicalProperties) and mark each such part with the RaceWall
-- attribute; Gameplay/RaceServer applies them again
-- whenever Workspace.RaceArena arrives (ApplyWallPhysics), so an arena built before this change or
-- made by hand in Studio is covered too.
RaceArenaBuilder.WallPhysics = { Density = 0.7, Friction = 0, Elasticity = 0, FrictionWeight = 100, ElasticityWeight = 100 }
RaceArenaBuilder.WallAttribute = "RaceWall"
-- Containers (any depth under the arena) whose parts are all boundaries: the Green Hill
-- builder's Barriers (walls and end caps) and Banks (the collidable lips), Astra's short
-- invisible Walls, and any Fences folder.
RaceArenaBuilder.WallContainers = { Barriers = true, Walls = true, Banks = true, Fences = true }
-- Containers whose parts are never boundaries: the floor, the pads and the spike plates.
RaceArenaBuilder.FloorContainers = { TrackFloor = true, SpeedPads = true, Spikes = true, RaceOrb = true }
-- Words of a part's name (CamelCase / snake_case, see NameWords) that make it a boundary
-- wherever it is: WallL_1, BackWall, BackCap, EndCap, BankLip_3, CurbGlow, PadRail,
-- Kit_FenceSection, Collider_Pad, RaceTrackBarrier__Base... A whole word, so Trail or Tulip
-- never are. A name with the word "floor" (StagingFloor, Floor_12) never is.
RaceArenaBuilder.WallWords = {
	wall = true, walls = true, barrier = true, barriers = true, fence = true, fences = true, curb = true, curbs = true,
	rail = true, rails = true, guardrail = true, guard = true, lip = true, collider = true, colliders = true,
	bumper = true, border = true, cap = true,
}
-- Whole names (lower case) that are boundaries: the start's collider.
RaceArenaBuilder.WallNames = { startgate = true }

-- A name's words, lower case: "BankLip_3" -> { "bank", "lip" }, "RaceTrackBarrier__Base" ->
-- { "race", "track", "barrier", "base" }.
function RaceArenaBuilder.NameWords(name: string): { string }
	local spaced = string.gsub(name, "(%l)(%u)", "%1 %2")
	spaced = string.gsub(spaced, "(%u)(%u%l)", "%1 %2")
	local words = {}
	for word in string.gmatch(spaced, "%a+") do
		table.insert(words, string.lower(word))
	end
	return words
end

-- The PhysicalProperties constructor: env's (Lune: @lune/roblox), else Roblox's global.
local function physicalPropertiesOf(env: any): any
	if type(env) == "table" and env.PhysicalProperties ~= nil then
		return env.PhysicalProperties
	end
	if typeof(script) == "Instance" then
		return PhysicalProperties
	end
	return nil
end

-- The frictionless wall physics (nil when env has no PhysicalProperties).
function RaceArenaBuilder.WallPhysicalProperties(env: any): any?
	local constructor = physicalPropertiesOf(env)
	if constructor == nil then
		return nil
	end
	local w = RaceArenaBuilder.WallPhysics
	return constructor.new(w.Density, w.Friction, w.Elasticity, w.FrictionWeight, w.ElasticityWeight)
end

-- Whether `part` (a BasePart under `arena`) is a race boundary: the RaceWall attribute, a wall
-- container, or a boundary name; never under TrackFloor / SpeedPads / Spikes / RaceOrb, never a
-- name with the word "floor".
function RaceArenaBuilder.IsWallPart(part: any, arena: any): boolean
	if part == nil or not part:IsA("BasePart") then
		return false
	end
	local words = RaceArenaBuilder.NameWords(part.Name)
	if table.find(words, "floor") then
		return false
	end
	local inWallContainer = false
	local node = part.Parent
	while node ~= nil and node ~= arena do
		if RaceArenaBuilder.FloorContainers[node.Name] then
			return false
		end
		if RaceArenaBuilder.WallContainers[node.Name] then
			inWallContainer = true
		end
		node = node.Parent
	end
	if part:GetAttribute(RaceArenaBuilder.WallAttribute) == true or inWallContainer then
		return true
	end
	if RaceArenaBuilder.WallNames[string.lower(part.Name)] then
		return true
	end
	for _, word in words do
		if RaceArenaBuilder.WallWords[word] then
			return true
		end
	end
	return false
end

-- Whether a part carries exactly WallPhysics (PhysicalProperties are float32: 0.7 reads back as
-- 0.69999998, so within 1e-4).
function RaceArenaBuilder.HasWallPhysics(part: any): boolean
	local physics = part.CustomPhysicalProperties
	if physics == nil then
		return false
	end
	local w = RaceArenaBuilder.WallPhysics
	local function near(a: number, b: number): boolean
		return math.abs(a - b) < 1e-4
	end
	return near(physics.Density, w.Density) and near(physics.Friction, w.Friction) and near(physics.Elasticity, w.Elasticity)
		and near(physics.FrictionWeight, w.FrictionWeight) and near(physics.ElasticityWeight, w.ElasticityWeight)
end

-- Stamps one part as a race wall: RaceWall and the frictionless physics (when there are any).
function RaceArenaBuilder.MarkWall(part: any, physics: any?)
	part:SetAttribute(RaceArenaBuilder.WallAttribute, true)
	if physics ~= nil then
		part.CustomPhysicalProperties = physics
	end
end

-- Every boundary part under `arena` made frictionless (IsWallPart). Returns how many; 0 when
-- env has no PhysicalProperties. Idempotent; the floor is never touched.
function RaceArenaBuilder.ApplyWallPhysics(arena: any, env: any): number
	local physics = RaceArenaBuilder.WallPhysicalProperties(env)
	if arena == nil or physics == nil then
		return 0
	end
	local count = 0
	for _, part in arena:GetDescendants() do
		if RaceArenaBuilder.IsWallPart(part, arena) then
			RaceArenaBuilder.MarkWall(part, physics)
			count += 1
		end
	end
	return count
end

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------
local Builder = {}
Builder.__index = Builder

local function newBuilder(env)
	local self = setmetatable({}, Builder)
	self.env = env
	self.parts = 0
	-- 2026-09-26 (owner): the frictionless physics of every race boundary (WallPhysics).
	self.wallPhysics = RaceArenaBuilder.WallPhysicalProperties(env)
	return self
end

function Builder:rgb(values)
	return self.env.Color3.fromRGB(values[1], values[2], values[3])
end

-- The arena frame: s past the start line, x across, y above the floor top.
function Builder:at(s, x, y)
	return self.env.CFrame.new(ORIGIN.X + x, ORIGIN.Y + y, ORIGIN.Z - s)
end

function Builder:make(className, name, parent)
	local object = self.env.Instance.new(className)
	object.Name = name
	if parent then
		object.Parent = parent
	end
	return object
end

function Builder:model(name, parent, mode)
	local model = self:make("Model", name, nil)
	if mode then
		pcall(function()
			model.ModelStreamingMode = self.env.Enum.ModelStreamingMode[mode]
		end)
	end
	model.Parent = parent
	return model
end

-- A part; decor = true turns off collisions, touches and queries; wall = true makes it a
-- frictionless race boundary (RaceWall, WallPhysics; 2026-09-26).
function Builder:part(parent, name, size, cframe, color, options)
	local Enum = self.env.Enum
	local opts = options or {}
	local part = self:make("Part", name, nil)
	part.Anchored = true
	part.CastShadow = false
	part.Size = size
	part.CFrame = cframe
	part.Color = self:rgb(color)
	part.Material = Enum.Material[opts.material or "SmoothPlastic"]
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if opts.shape then
		part.Shape = Enum.PartType[opts.shape]
	end
	if opts.transparency then
		part.Transparency = opts.transparency
	end
	if opts.decor then
		part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
	else
		part.CanCollide = opts.collide ~= false
		part.CanTouch = false
		part.CanQuery = opts.query ~= false
	end
	part:SetAttribute("RaceArenaPart", true)
	if opts.wall then
		RaceArenaBuilder.MarkWall(part, self.wallPhysics)
	end
	part.Parent = parent
	self.parts += 1
	return part
end

function Builder:label(surfaceGui, text, color, strokeColor)
	local Enum = self.env.Enum
	local label = self:make("TextLabel", "Text", nil)
	label.BackgroundTransparency = 1
	label.Size = self.env.UDim2.fromScale(1, 1)
	-- 2026-09-25 (integrator): through FontFace when env carries Font. Lune stores `.Font =` as an
	-- EnumItem in FontFace, and the build then cannot serialize the place.
	if self.env.Font then
		label.FontFace = self.env.Font.fromEnum(Enum.Font.FredokaOne)
	else
		label.Font = Enum.Font.FredokaOne
	end
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = self:rgb(color or WHITE)
	label.TextStrokeColor3 = self:rgb(strokeColor or { 11, 27, 45 })
	label.TextStrokeTransparency = 0
	label.Parent = surfaceGui
	return label
end

-- A SurfaceGui with one line of text on `face` of `part`.
function Builder:surfaceText(part, name, face, text, color)
	local Enum = self.env.Enum
	local gui = self:make("SurfaceGui", name, nil)
	gui.Face = Enum.NormalId[face]
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.LightInfluence = 0
	gui.Parent = part
	self:label(gui, text, color)
	return gui
end

-- Racers look along -Z, so the face they see coming toward a part is its Back face (+Z).
function Builder:gantry(parent, name, s, beamColor, text, textColor)
	local model = self:model(name, parent, nil)
	for side = -1, 1, 2 do
		self:part(model, if side < 0 then "PostL" else "PostR", self.env.Vector3.new(2, 20, 2), self:at(s, side * 40, 10), NAVY, { decor = true })
	end
	local beam = self:part(model, "Beam", self.env.Vector3.new(84, 4, 2), self:at(s, 0, 22), beamColor, { decor = true })
	self:surfaceText(beam, "LabelBack", "Back", text, textColor)
	self:surfaceText(beam, "LabelFront", "Front", text, textColor)
	return model
end

----------------------------------------------------------------------
-- Race art assets: lookup, checks, placement (2026-09-25)
----------------------------------------------------------------------
-- The RaceAssets folder: env.RaceAssets (false = none); in Roblox, ServerStorage.RaceAssets.
local function assetFolder(env)
	if env.RaceAssets ~= nil then
		return if env.RaceAssets then env.RaceAssets else nil
	end
	if typeof(game) == "Instance" then
		local ok, folder = pcall(function()
			return game:GetService("ServerStorage"):FindFirstChild("RaceAssets")
		end)
		if ok and folder then
			return folder
		end
	end
	return nil
end

-- A mesh the owner imported: the exact name, else the name followed by a non-alphanumeric
-- character (an importer suffix such as ".001" or "_Mesh"; "Light_1" never matches "Light_10").
local function findAssetPart(index, name)
	local exact = index[name]
	if exact then
		return exact
	end
	local best, bestName = nil, nil
	for otherName, part in index do
		if #otherName > #name and string.sub(otherName, 1, #name) == name
			and string.match(string.sub(otherName, #name + 1, #name + 1), "[%w]") == nil
			and (bestName == nil or otherName < bestName)
		then
			best, bestName = part, otherName
		end
	end
	return best
end

-- The uniform scale between an imported mesh and its spec size, or nil when the shape differs
-- (axes swapped by a wrong import, or another mesh under that name).
function RaceArenaBuilder.AssetScale(size: any, spec: { number }): number?
	local got = { size.X, size.Y, size.Z }
	local axis = 1
	for i = 2, 3 do
		if spec[i] > spec[axis] then
			axis = i
		end
	end
	local k = got[axis] / spec[axis]
	if not (k > 0 and k < math.huge) then
		return nil
	end
	for i = 1, 3 do
		local slack = (spec[i] * RaceArenaBuilder.AssetShapeTolerance + RaceArenaBuilder.AssetShapeSlack) * k
		if math.abs(got[i] - spec[i] * k) > slack then
			return nil
		end
	end
	return k
end

-- Per model: ok (every spec part found with the right shape), parts (name -> source part),
-- scale, problems. A folder of nil gives an empty report (every model falls back).
function RaceArenaBuilder.ResolveAssets(folder: any): { [string]: any }
	local report = {}
	if folder == nil then
		return report
	end
	local index = {}
	for _, d in folder:GetDescendants() do
		if d:IsA("BasePart") and index[d.Name] == nil then
			index[d.Name] = d
		end
	end
	for _, model in RaceArenaBuilder.AssetModels do
		local spec = RaceArenaBuilder.AssetSpec[model]
		local entry = { ok = false, parts = {}, problems = {}, scale = nil }
		if type(spec) ~= "table" or type(spec.Parts) ~= "table" or #spec.Parts == 0 then
			table.insert(entry.problems, "no AssetSpec for it (run audit/generate_race_assets.py)")
		else
			for _, p in spec.Parts do
				local part = findAssetPart(index, p.Name)
				if not part then
					table.insert(entry.problems, p.Name .. " is missing")
				else
					local k = RaceArenaBuilder.AssetScale(part.Size, p.Size)
					if not k then
						table.insert(entry.problems, string.format("%s has the wrong shape (%s; the spec says %s x %s x %s)",
							p.Name, tostring(part.Size), tostring(p.Size[1]), tostring(p.Size[2]), tostring(p.Size[3])))
					else
						entry.parts[p.Name] = part
						entry.scale = entry.scale or k
					end
				end
			end
			entry.ok = #entry.problems == 0
		end
		report[model] = entry
	end
	return report
end

-- Resolves the assets for this build and warns (once per model this build uses) about a folder
-- that is there but does not fit; no folder at all is the normal fallback and stays quiet.
function Builder:resolveAssets(env, models)
	local folder = assetFolder(env)
	self.assets = RaceArenaBuilder.ResolveAssets(folder)
	if folder == nil then
		return
	end
	local log = if type(env.Warn) == "function" then env.Warn elseif typeof(warn) == "function" then warn else print
	for _, model in models do
		local entry = self.assets[model]
		if entry and not entry.ok then
			local shown = {}
			for index = 1, math.min(3, #entry.problems) do
				shown[index] = entry.problems[index]
			end
			log(string.format("[RaceArenaBuilder] RaceAssets.%s not used (%d problem(s)): %s", model, #entry.problems, table.concat(shown, "; ")))
		end
	end
end

function Builder:asset(model)
	local entry = self.assets and self.assets[model]
	return entry ~= nil and entry.ok == true
end

-- Clones every spec part of `model` (but the roles in `skip`) into `parent`, each at
-- base * Center with the spec Size and its role's look. Returns { [spec name] = clone }.
function Builder:placeAsset(model, parent, base, skip, rename)
	local env = self.env
	local entry = self.assets[model]
	local placed = {}
	for _, p in RaceArenaBuilder.AssetSpec[model].Parts do
		if not (skip and skip[p.Role]) then
			local clone = entry.parts[p.Name]:Clone()
			for _, child in clone:GetChildren() do
				child.Parent = nil -- a SurfaceAppearance or anything else the importer added
			end
			local look = RaceArenaBuilder.AssetRoles[p.Role] or RaceArenaBuilder.AssetRoles.Base
			clone.Name = (rename and rename[p.Name]) or p.Name
			clone.Anchored = true
			clone.CanCollide, clone.CanTouch, clone.CanQuery = false, false, false
			clone.CastShadow = false
			clone.Color = self:rgb(look.Color)
			clone.Material = env.Enum.Material[look.Material]
			clone.Transparency = look.Transparency or 0
			clone.Reflectance = look.Reflectance or 0
			pcall(function()
				clone.TextureID = ""
			end)
			clone.Size = env.Vector3.new(p.Size[1], p.Size[2], p.Size[3])
			clone.CFrame = base * env.CFrame.new(p.Center[1], p.Center[2], p.Center[3])
			clone:SetAttribute("RaceArenaPart", true)
			clone:SetAttribute("RaceAsset", model)
			clone.Parent = parent
			self.parts += 1
			placed[p.Name] = clone
		end
	end
	return placed
end

-- An invisible collider from the spec (the meshes never collide; these boxes/cylinders do).
function Builder:collider(parent, base, spec)
	local env = self.env
	local center = base * env.CFrame.new(spec.Center[1], spec.Center[2], spec.Center[3])
	local part
	if spec.Shape == "Cylinder" then
		-- A Roblox cylinder runs along its X axis: turned upright.
		part = self:part(parent, "Collider_" .. spec.Name, env.Vector3.new(spec.Height, spec.Radius * 2, spec.Radius * 2),
			center * env.CFrame.Angles(0, 0, math.pi / 2), WHITE, { transparency = 1, shape = "Cylinder" })
	else
		part = self:part(parent, "Collider_" .. spec.Name, env.Vector3.new(spec.Size[1], spec.Size[2], spec.Size[3]),
			center, WHITE, { transparency = 1 })
	end
	part:SetAttribute("RaceGateCollider", true)
	return part
end

-- A two-line panel face (Title over Status) other code can rewrite.
function Builder:panelGui(part, face, title, status, titleColor)
	local Enum = self.env.Enum
	local gui = self:make("SurfaceGui", "PanelGui", nil)
	gui.Face = Enum.NormalId[face]
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.LightInfluence = 0
	gui.Parent = part
	local top = self:label(gui, title, titleColor)
	top.Name = "Title"
	top.Size = self.env.UDim2.fromScale(1, 0.58)
	local bottom = self:label(gui, status, WHITE)
	bottom.Name = "Status"
	bottom.Size = self.env.UDim2.fromScale(1, 0.42)
	bottom.Position = self.env.UDim2.fromScale(0, 0.58)
	return gui
end

-- Confetti spots under the finish header: attachments on `host` with a Rate-0 emitter.
local CONFETTI_COLORS = { GOLD, CYAN_NEON, STOP_RED, WHITE }
function Builder:confetti(host, base)
	local env = self.env
	local markers = RaceArenaBuilder.AssetSpec.RaceFinishGantry and RaceArenaBuilder.AssetSpec.RaceFinishGantry.Markers or nil
	local inverse = host.CFrame:Inverse()
	local sequence = env.ColorSequence or (if typeof(script) == "Instance" then (ColorSequence :: any) else nil)
	for index, fallbackX in { -33, -11, 11, 33 } do
		local name = "ConfettiSpot_" .. index
		local point = markers and markers[name] or { fallbackX, 20.5, 0 }
		local attachment = self:make("Attachment", name, nil)
		attachment.CFrame = inverse * (base * env.CFrame.new(point[1], point[2], point[3]))
		attachment.Parent = host
		local emitter = self:make("ParticleEmitter", "Confetti", nil)
		emitter.Rate = 0
		emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		emitter.LightEmission = 0.4
		emitter.LightInfluence = 0
		emitter.Acceleration = env.Vector3.new(0, -24, 0)
		emitter.Drag = 1.5
		if env.NumberRange then
			emitter.Lifetime = env.NumberRange.new(2, 3.5)
			emitter.Speed = env.NumberRange.new(16, 28)
		end
		if sequence then
			emitter.Color = sequence.new(self:rgb(CONFETTI_COLORS[index]))
		end
		emitter.Parent = attachment
	end
end

-- Barrier tiles from StartS to EndWallS (the last one ends on the end wall).
function RaceArenaBuilder.BarrierTiles(length: number): { { s0: number, s1: number, mid: number } }
	local span = RaceArenaBuilder.EndWallS - RaceArenaBuilder.StartS
	local count = math.max(1, math.ceil(span / length - 1e-6))
	local list = {}
	for index = 0, count - 1 do
		local mid = math.min(RaceArenaBuilder.StartS + length * (index + 0.5), RaceArenaBuilder.EndWallS - length * 0.5)
		table.insert(list, { s0 = mid - length * 0.5, s1 = mid + length * 0.5, mid = mid })
	end
	return list
end

----------------------------------------------------------------------
-- Arena
----------------------------------------------------------------------
-- The chunk (1-based) that holds decor at distance s.
function RaceArenaBuilder.ChunkIndex(s: number): number
	return math.max(1, math.floor((s - RaceArenaBuilder.StartS) / RaceArenaBuilder.ChunkLength) + 1)
end

function RaceArenaBuilder.ChunkCount(): number
	return RaceArenaBuilder.ChunkIndex(RaceArenaBuilder.EndWallS + 2)
end

-- Floor slabs: the staging box (s -64..0), then 120-stud slabs to the end wall.
function RaceArenaBuilder.FloorSegments(): { { s0: number, s1: number, staging: boolean } }
	local list = { { s0 = RaceArenaBuilder.StartS, s1 = 0, staging = true } }
	local s = 0
	while s < RaceArenaBuilder.EndWallS - 1e-6 do
		local s1 = math.min(s + 120, RaceArenaBuilder.EndWallS)
		table.insert(list, { s0 = s, s1 = s1, staging = false })
		s = s1
	end
	return list
end

-- Side wall segments (<= 240 studs each) covering StartS..EndWallS without gaps.
function RaceArenaBuilder.WallSegments(): { { s0: number, s1: number } }
	local list = {}
	local s = RaceArenaBuilder.StartS
	while s < RaceArenaBuilder.EndWallS - 1e-6 do
		local s1 = math.min(s + RaceArenaBuilder.ChunkLength, RaceArenaBuilder.EndWallS)
		table.insert(list, { s0 = s, s1 = s1 })
		s = s1
	end
	return list
end

function RaceArenaBuilder.Build(parent: any, env: any): any
	local b = newBuilder(env)
	local Vector3, CFrame = env.Vector3, env.CFrame
	local art = RACE.Art
	local chevronTexture = type(art.ChevronTexture) == "string" and art.ChevronTexture ~= ""
	b:resolveAssets(env, { "RaceStartGantry", "RaceFinishGantry", "RaceTrackBarrier" })

	local arena = b:model("RaceArena", nil, nil)
	arena:SetAttribute("RaceArenaVersion", RaceArenaBuilder.Version)
	local structure = b:model("Structure", arena, "Persistent")
	local decor = b:model("Decor", arena, nil)
	local chunks = {}
	for k = 1, RaceArenaBuilder.ChunkCount() do
		chunks[k] = b:model("Chunk_" .. k, decor, "Atomic")
	end
	local function chunkAt(s)
		return chunks[math.clamp(RaceArenaBuilder.ChunkIndex(s), 1, #chunks)]
	end

	-- Floor (top exactly at Origin.Y) with the stud texture, and the chevron texture when set.
	for index, segment in RaceArenaBuilder.FloorSegments() do
		local length = segment.s1 - segment.s0
		local slab = b:part(structure, if segment.staging then "StagingFloor" else "Floor_" .. (index - 1),
			Vector3.new(TRACK.Width, 2, length), b:at((segment.s0 + segment.s1) * 0.5, 0, -1),
			if segment.staging then STAGING_COLOR else FLOOR_COLOR)
		local studs = b:make("Texture", "Studs", nil)
		studs.Texture = art.StudTexture
		studs.Face = env.Enum.NormalId.Top
		studs.StudsPerTileU, studs.StudsPerTileV = 3, 3
		studs.Color3 = b:rgb(WHITE)
		studs.Transparency = 0.82
		studs.Parent = slab
		if chevronTexture and not segment.staging then
			local chevrons = b:make("Texture", "Chevrons", nil)
			chevrons.Texture = art.ChevronTexture
			chevrons.Face = env.Enum.NormalId.Top
			chevrons.StudsPerTileU, chevrons.StudsPerTileV = TRACK.Width, RaceArenaBuilder.ChevronEvery
			chevrons.Color3 = b:rgb(WHITE)
			chevrons.Transparency = 0.4
			chevrons.Parent = slab
		end
	end

	-- Invisible side walls (continuous), the start collider, back and end walls.
	for index, segment in RaceArenaBuilder.WallSegments() do
		local length = segment.s1 - segment.s0
		for side = -1, 1, 2 do
			b:part(structure, (if side < 0 then "WallL_" else "WallR_") .. index,
				Vector3.new(1, RaceArenaBuilder.WallHeight, length),
				b:at((segment.s0 + segment.s1) * 0.5, side * RaceArenaBuilder.WallX, RaceArenaBuilder.WallHeight * 0.5),
				WHITE, { transparency = 1, query = false, wall = true })
		end
	end
	-- 2026-09-26 (owner): every collider a racer can brush is frictionless (wall = true).
	b:part(structure, "StartGate", Vector3.new(TRACK.Width, 16, 1), b:at(1.5, 0, 8), WHITE, { transparency = 1, query = false, wall = true })
	local wallSpan = 2 * RaceArenaBuilder.WallX + 1
	b:part(structure, "BackWall", Vector3.new(wallSpan, RaceArenaBuilder.WallHeight, 1),
		b:at(RaceArenaBuilder.StartS - 0.5, 0, RaceArenaBuilder.WallHeight * 0.5), NAVY, { wall = true })
	b:part(structure, "EndWall", Vector3.new(wallSpan, RaceArenaBuilder.WallHeight, 2),
		b:at(RaceArenaBuilder.EndWallS + 1, 0, RaceArenaBuilder.WallHeight * 0.5), NAVY, { wall = true })

	-- STOP bar over the start line (drops at GO on the client) and the start gantry.
	local stopBar = b:part(structure, "StopBar", Vector3.new(74, 1.4, 0.5), b:at(1, 0, 3), STOP_RED, { decor = true })
	b:surfaceText(stopBar, "StopBack", "Back", "STOP  STOP")
	b:surfaceText(stopBar, "StopFront", "Front", "STOP  STOP")
	local gantry = b:model("StartGantry", structure, nil)
	if b:asset("RaceStartGantry") then
		-- 2026-09-25: the Blender gantry; its sphere lights become Light1..5 (RaceArenaVisuals).
		local rename = {}
		for light = 1, 5 do
			rename["RaceStartGantry__Light_" .. light] = "Light" .. light
		end
		local placed = b:placeAsset("RaceStartGantry", gantry, b:at(RaceArenaBuilder.StartGantryS, 0, 0), nil, rename)
		local panel = placed["RaceStartGantry__Panel"]
		if panel then
			b:panelGui(panel, "Back", "RACE", "", WHITE)
		end
		gantry:SetAttribute("RaceAsset", "RaceStartGantry")
	else
		for side = -1, 1, 2 do
			b:part(gantry, if side < 0 then "PostL" else "PostR", Vector3.new(2, 20, 2), b:at(-2, side * 40, 10), NAVY, { decor = true })
		end
		b:part(gantry, "Beam", Vector3.new(84, 4, 2), b:at(-2, 0, 22), NAVY, { decor = true })
		b:part(gantry, "Strip", Vector3.new(84, 0.4, 0.3), b:at(-3.1, 0, 20.3), CYAN_NEON, { decor = true, material = "Neon" })
		for light = 1, 5 do
			b:part(gantry, "Light" .. light, Vector3.new(2.4, 2.4, 2.4), b:at(-3.4, (light - 3) * 6, 22), { 60, 18, 18 },
				{ decor = true, material = "Neon", shape = "Ball" })
		end
	end

	-- Grid: slot plates and the start line; barrier posts at the ends of the STOP bar.
	for slot = 1, RaceTrack.SlotCount do
		local s, x = RaceTrack.SlotLocal(slot)
		b:part(chunkAt(s), "Slot_" .. slot, Vector3.new(6, 0.1, 6), b:at(s, x, 0.05), WHITE, { decor = true, transparency = 0.35 })
	end
	b:part(chunkAt(0), "StartLine", Vector3.new(TRACK.Width, 0.12, 1), b:at(0.5, 0, 0.06), WHITE, { decor = true })
	for side = -1, 1, 2 do
		b:part(chunkAt(1), if side < 0 then "BarrierPostL" else "BarrierPostR", Vector3.new(1.2, 4, 1.2), b:at(1, side * 37.4, 2), STOP_RED, { decor = true })
	end

	if b:asset("RaceTrackBarrier") then
		-- 2026-09-25: guard-rail tiles along both edges instead of the curbs. The module's cross
		-- section is symmetric, so both sides use it unrotated and its chevrons point down the track.
		local length = RaceArenaBuilder.AssetSpec.RaceTrackBarrier.Size[3]
		for _, tile in RaceArenaBuilder.BarrierTiles(length) do
			for side = -1, 1, 2 do
				b:placeAsset("RaceTrackBarrier", chunkAt(tile.mid), b:at(tile.mid, side * RaceArenaBuilder.BarrierX, 0))
			end
		end
	else
		-- Curbs and neon strips along both edges, one piece per chunk.
		for k, chunk in chunks do
			local s0 = math.max(RaceArenaBuilder.StartS, RaceArenaBuilder.StartS + (k - 1) * RaceArenaBuilder.ChunkLength)
			local s1 = math.min(RaceArenaBuilder.EndWallS, RaceArenaBuilder.StartS + k * RaceArenaBuilder.ChunkLength)
			if s1 > s0 then
				local mid, length = (s0 + s1) * 0.5, s1 - s0
				for side = -1, 1, 2 do
					b:part(chunk, "Curb", Vector3.new(1.4, 0.5, length), b:at(mid, side * 35.3, 0.25), CURB, { decor = true })
					b:part(chunk, "CurbGlow", Vector3.new(0.4, 0.2, length), b:at(mid, side * 34.3, 0.1), CYAN_NEON, { decor = true, material = "Neon" })
				end
			end
		end
	end

	-- Spike tiles: a grey plate with a black two-piece star (the second plate yawed 45 degrees).
	for _, tile in RaceTrack.SpikeTiles() do
		local chunk = chunkAt(tile.s)
		local base = b:part(chunk, "SpikeTile", Vector3.new(TRACK.SpikeTile, TRACK.SpikeTileHeight, TRACK.SpikeTile),
			b:at(tile.s, tile.x, TRACK.SpikeTileHeight * 0.5), SPIKE_BASE, { decor = true, material = "DiamondPlate" })
		base:SetAttribute("RaceSpikeTile", true)
		base:SetAttribute("Field", tile.field)
		base:SetAttribute("Row", tile.row)
		base:SetAttribute("Lane", tile.lane)
		local starY = TRACK.SpikeTileHeight + 0.06
		b:part(chunk, "SpikeStar", Vector3.new(4.6, 0.12, 4.6), b:at(tile.s, tile.x, starY), SPIKE_STAR, { decor = true })
		b:part(chunk, "SpikeStar", Vector3.new(4.6, 0.12, 4.6), b:at(tile.s, tile.x, starY) * CFrame.Angles(0, math.rad(45), 0), SPIKE_STAR, { decor = true })
	end

	-- Distance gantries and the last-stretch gantry (the start gantry's mesh without its lights
	-- when the assets are there).
	local function distanceGantry(name, s, beamColor, text, textColor, assetTextColor)
		if b:asset("RaceStartGantry") then
			local model = b:model(name, chunkAt(s), nil)
			local placed = b:placeAsset("RaceStartGantry", model, b:at(s, 0, 0), { Light = true, Gold = true })
			local panel = placed["RaceStartGantry__Panel"]
			if panel then
				b:surfaceText(panel, "LabelBack", "Back", text, assetTextColor)
			end
			return model
		end
		return b:gantry(chunkAt(s), name, s, beamColor, text, textColor)
	end
	for _, s in TRACK.Gantries do
		distanceGantry("Gantry_" .. s, s, NAVY, string.format("%d STUDS", s), WHITE, WHITE)
	end
	distanceGantry("LastStretch", TRACK.LastStretchAt, GOLD, "LAST 200!", WHITE, GOLD)

	-- Checkered finish line and the FINISH gate.
	local finishChunk = chunkAt(TRACK.Length)
	b:part(finishChunk, "FinishLine", Vector3.new(TRACK.Width, 0.1, 6), b:at(TRACK.Length, 0, 0.05), WHITE, { decor = true })
	local columns, squareW = 12, TRACK.Width / 12
	for column = 1, columns do
		for row = 1, 2 do
			if (column + row) % 2 == 0 then
				b:part(finishChunk, "Checker", Vector3.new(squareW, 0.12, 3),
					b:at(TRACK.Length - 1.5 + (row - 1) * 3, -TRACK.Width * 0.5 + (column - 0.5) * squareW, 0.06), SPIKE_STAR, { decor = true })
			end
		end
	end
	local finishBase = b:at(TRACK.Length, 0, 0)
	if b:asset("RaceFinishGantry") then
		local finishGate = b:model("FinishGate", finishChunk, nil)
		local placed = b:placeAsset("RaceFinishGantry", finishGate, finishBase)
		local panel = placed["RaceFinishGantry__Panel"]
		if panel then
			b:surfaceText(panel, "LabelBack", "Back", "FINISH", GOLD)
		end
		b:confetti(placed["RaceFinishGantry__Base"], finishBase)
		finishGate:SetAttribute("RaceAsset", "RaceFinishGantry")
	else
		local finishGate = b:gantry(finishChunk, "FinishGate", TRACK.Length, NAVY, "FINISH", GOLD)
		b:confetti(finishGate:FindFirstChild("Beam"), finishBase)
	end

	-- Part chevrons (no texture uploaded): a V every 48 studs pointing down the track, hidden on
	-- phones by LowPowerGraphics through the RaceDecorLowPower tag.
	if not chevronTexture then
		local s = RaceArenaBuilder.ChevronEvery
		while s < TRACK.Length do
			-- 2026-09-26: off every spike field (2 or 3 rows, SpikeRowGap apart).
			local inSpikes = RaceTrack.InSpikeField(s, 8)
			if not inSpikes then
				for side = -1, 1, 2 do
					-- Each arm runs from the lane edge (behind) to the centre line (ahead).
					local arm = b:part(chunkAt(s), "Chevron", Vector3.new(1, 0.08, 8),
						b:at(s, side * 2.6, 0.04) * CFrame.Angles(0, side * math.rad(40), 0), WHITE, { decor = true, transparency = 0.35 })
					pcall(function()
						arm:AddTag("RaceDecorLowPower")
					end)
				end
			end
			s += RaceArenaBuilder.ChevronEvery
		end
	end

	-- 2026-09-25 (speed pads, CONTRATO_MAPA_ASTRA §2b): RaceArena.SpeedPads (Persistent, so every
	-- device has them; tagged RaceSpeedPad, never RaceDecorLowPower, so phones keep them). Each pad
	-- is a flat yellow "SpeedPad" on the floor across the centre lanes with a red chevron pointing
	-- down the track (-Z); Boost / Seconds are the defaults (U4.Race.Pads). Inert: the server
	-- reads their footprint at staging (RaceTrack.PadsFromParts), nothing touches them.
	local padFolder = b:model("SpeedPads", arena, "Persistent")
	local padSize = RaceArenaBuilder.PadSize
	for index, s in RaceArenaBuilder.PadSpots do
		local pad = b:part(padFolder, "SpeedPad", Vector3.new(padSize[1], padSize[2], padSize[3]),
			b:at(s, 0, padSize[2] * 0.5), GOLD, { decor = true })
		pad:SetAttribute("Boost", RACE.Pads.DefaultBoost)
		pad:SetAttribute("Seconds", RACE.Pads.DefaultSeconds)
		pad:SetAttribute("PadIndex", index)
		pcall(function()
			pad:AddTag("RaceSpeedPad")
		end)
		for row = -1, 1, 2 do
			for side = -1, 1, 2 do
				-- Two V's (each arm from the pad's edge behind to its centre ahead).
				local arm = b:part(padFolder, "SpeedPadArrow", Vector3.new(1.2, 0.06, 7),
					b:at(s + row * 3.5, side * 3.2, padSize[2] + 0.03) * CFrame.Angles(0, side * math.rad(40), 0), STOP_RED, { decor = true })
				pcall(function()
					arm:AddTag("RaceSpeedPad")
				end)
			end
		end
	end

	-- The ORB: Neon core, ForceField shell, light, a few sparks and a marker.
	local orbModel = b:model("RaceOrb", arena, "Persistent")
	local orbCFrame = b:at(TRACK.OrbS, 0, TRACK.OrbY)
	local core = b:part(orbModel, "Core", Vector3.new(20, 20, 20), orbCFrame, ORB_CORE, { decor = true, material = "Neon", shape = "Ball" })
	b:part(orbModel, "Shell", Vector3.new(28, 28, 28), orbCFrame, ORB_CORE, { decor = true, material = "ForceField", shape = "Ball" })
	orbModel.PrimaryPart = core
	local light = b:make("PointLight", "Glow", nil)
	light.Range = 60
	light.Brightness = 2
	light.Color = b:rgb(ORB_CORE)
	light.Shadows = false
	light.Parent = core
	local sparks = b:make("ParticleEmitter", "Sparks", nil)
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Rate = 10
	sparks.Lifetime = env.NumberRange and env.NumberRange.new(0.6, 1.2) or sparks.Lifetime
	sparks.LightEmission = 1
	sparks.LightInfluence = 0
	sparks.Parent = core
	local marker = b:make("BillboardGui", "OrbMarker", nil)
	marker.Adornee = core
	marker.Size = env.UDim2.fromOffset(180, 56)
	marker.StudsOffset = Vector3.new(0, 18, 0)
	marker.AlwaysOnTop = true
	marker.MaxDistance = 2600
	marker.LightInfluence = 0
	marker.Parent = core
	b:label(marker, "▼ ORB", GOLD)

	local used = {}
	for _, model in { "RaceStartGantry", "RaceFinishGantry", "RaceTrackBarrier" } do
		if b:asset(model) then
			table.insert(used, model)
		end
	end
	arena:SetAttribute("RaceArenaAssets", table.concat(used, ","))
	arena:SetAttribute("RaceArenaParts", b.parts)
	-- 2026-09-26 (owner): the barrier tiles, curbs and posts too (IsWallPart), not only the colliders.
	RaceArenaBuilder.ApplyWallPhysics(arena, env)
	arena.Parent = parent
	return arena
end

----------------------------------------------------------------------
-- Race Gate (lobby)
----------------------------------------------------------------------
-- The gate's frame: at the configured floor point, local -Z toward Face (the side players see).
function RaceArenaBuilder.GateCFrame(worldKey: string, env: any): any?
	local placement = RACE.Gate[worldKey]
	if type(placement) ~= "table" then
		return nil
	end
	local position, face = placement.Position, placement.Face
	local dx, dz = face.X - position.X, face.Z - position.Z
	local yaw = if dx * dx + dz * dz > 1e-6 then math.atan2(-dx, -dz) else 0
	return env.CFrame.new(position.X, position.Y, position.Z) * env.CFrame.Angles(0, yaw, 0)
end

-- 2026-09-26 (owner): The Flash's gate, after the owner's reference (Shared/FlashGate has every
-- number): a big red arch (a smooth half circle of 24 box segments on two short legs) with a gold
-- band inlaid on both faces, a round gold medallion with the lightning bolt at its top (a
-- MedallionGlow ring the client breathes), and the sign-up ring pad under it (a dark disc with
-- cyan / gold / cyan Neon rings; the turning dashes and the rising scan ring are the client's,
-- Gameplay/FlashGateClient). The Flash stands beside it (FlashSpot) and his holo board floats past
-- him (HoloBoardAnchor: the client builds the panel there). Parts only: no meshes, textures,
-- scripts or particles. The Blender booth (RaceLobbyBooth) is no longer used for the gate (its
-- spec stays for the generator); RaceGateAssets is always false.
-- Contract: RaceGatePad (12 x 0.4 x 12 at the floor point, invisible: the trigger PadTouchService
-- reads), RaceGateSign (BillboardGui, Title / Status / Record: RaceLobbyController fills it; over
-- the medallion, for players far away: the client hides it near the gate, where the board says
-- the same), FlashSpot (its bottom is the floor under Flash's feet, LookVector toward the players,
-- at LobbyNpcConfig.FlashBesideGate's point, where the build stands the owner's Flash too),
-- HoloBoardAnchor (invisible, non-colliding: its CFrame is the open board's centre, its Size the
-- open board; the owner may move it). RaceGate attribute RaceGateVersion = FlashGate.Version:
-- audit/build_update4 rebuilds an older gate of ours (U4Asset "RaceGate"), never another's.
--
-- 2026-09-26 (owner): the part look was rejected, so the gate's art is the Blender kit now
-- (audit/flash_gate_bpy.py; the owner imports design/race/flashgate/FlashGateKit.fbx once and saves
-- FlashGateKit.rbxm). env.FlashGateKit = that kit (false = none; with no such key, in Roblox,
-- ServerStorage.FlashGateKit). When every FlashGate.Kit piece is in it with the right shape, the
-- arch, medallion and ring pad are its MeshParts instead of the parts: each cloned, children
-- stripped, placed from FlashGate.Kit (Size, the box centre's Offset from the gate origin) with the
-- import's quarter turn undone (Shared/MeshKitImport reads it from the pivots), painted from it
-- (Color, Material, Reflectance, CastShadow), the legs (FG_LegL / FG_LegR) colliding and everything
-- else inert; MedallionGlow stays a Neon Part (FlashGate.Kit.Glow) the client breathes. Same
-- footprint and the same contract parts; RaceGateVersion = FlashGate.MeshVersion, RaceGateKit = true.
-- A kit that is there but does not fit is reported (env.Warn / warn) and the parts are built.
local FlashGate = if typeof(script) == "Instance"
	then require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("FlashGate", 10))
	else require("../../../ReplicatedStorage/Shared/FlashGate")
local LobbyNpcConfig = if typeof(script) == "Instance"
	then require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("LobbyNpcConfig", 10))
	else require("../../../ReplicatedStorage/Shared/LobbyNpcConfig")
local MeshKitImport = if typeof(script) == "Instance"
	then require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("MeshKitImport", 10))
	else require("../../../ReplicatedStorage/Shared/MeshKitImport")

-- The part-built gate's version; GateVersionFor(kit) is the one BuildGate makes with that kit.
RaceArenaBuilder.GateVersion = FlashGate.Version
RaceArenaBuilder.GateMeshVersion = FlashGate.MeshVersion
RaceArenaBuilder.GatePartBudget = 80

-- The gate kit: env.FlashGateKit (false = none); in Roblox without that key, ServerStorage.FlashGateKit.
local function gateKitFolder(env)
	if env.FlashGateKit ~= nil then
		return if env.FlashGateKit then env.FlashGateKit else nil
	end
	if typeof(game) == "Instance" then
		local ok, folder = pcall(function()
			return game:GetService("ServerStorage"):FindFirstChild(FlashGate.KitName)
		end)
		if ok and folder then
			return folder
		end
	end
	return nil
end

-- { ok, parts = { [piece name] = source MeshPart }, turn (quarter turns the import applied),
-- problems }. No folder: not ok, no problems (the normal part-built gate).
function RaceArenaBuilder.ResolveGateKit(folder: any): { [string]: any }
	local report = { ok = false, parts = {}, turn = 0, problems = {}, note = nil }
	if folder == nil then
		return report
	end
	local kit = FlashGate.Kit
	if type(kit) ~= "table" or type(kit.Pieces) ~= "table" or #kit.Pieces == 0 or type(kit.Glow) ~= "table" then
		table.insert(report.problems, "FlashGate.Kit is empty (run audit/flash_gate_bpy.py)")
		return report
	end
	local index = MeshKitImport.Index(folder)
	local pieces = {}
	for _, spec in kit.Pieces do
		local part = MeshKitImport.Find(index, spec.Name)
		if not part then
			table.insert(report.problems, spec.Name .. " is missing")
		elseif not part:IsA("MeshPart") then
			table.insert(report.problems, spec.Name .. " is a " .. part.ClassName .. ", not a MeshPart")
		else
			report.parts[spec.Name] = part
			table.insert(pieces, { part = part, spec = spec })
		end
	end
	if #report.problems > 0 then
		return report
	end
	local CF, V3 = if typeof(CFrame) == "table" then CFrame else nil, if typeof(Vector3) == "table" then Vector3 else nil
	if CF == nil or V3 == nil then
		local lateRequire: any = require
		local ok, roblox = pcall(lateRequire, "@lune/roblox")
		if ok then
			CF, V3 = roblox.CFrame, roblox.Vector3
		end
	end
	local turn = MeshKitImport.ImportTurn(pieces, CF, V3)
	report.turn, report.note = turn.turn, turn.note
	if not turn.ok then
		table.insert(report.problems, turn.note or "the import's turn cannot be read")
		return report
	end
	for _, entry in pieces do
		if not MeshKitImport.Scale(entry.part.Size, entry.spec.Size, turn.turn) then
			table.insert(report.problems, string.format("%s has the wrong shape (%s; FlashGate.Kit says %s x %s x %s)", entry.spec.Name,
				tostring(entry.part.Size), tostring(entry.spec.Size[1]), tostring(entry.spec.Size[2]), tostring(entry.spec.Size[3])))
		end
	end
	report.ok = #report.problems == 0
	return report
end

-- The RaceGateVersion BuildGate stamps with this kit (nil = none): MeshVersion when it fits.
function RaceArenaBuilder.GateVersionFor(folder: any): number
	return if RaceArenaBuilder.ResolveGateKit(folder).ok then FlashGate.MeshVersion else FlashGate.Version
end

-- The kit's MeshParts into the gate's Arch / Medallion / RingPad models (see above).
function Builder:gateMeshes(gate, base, kit)
	local env = self.env
	local Enum, Vector3, CFrame = env.Enum, env.Vector3, env.CFrame
	local NAMES = FlashGate.Names
	local groups = {}
	for _, name in { NAMES.Arch, NAMES.Medallion, NAMES.RingPad } do
		groups[name] = self:model(name, gate, nil)
	end
	for _, spec in FlashGate.Kit.Pieces do
		local clone = kit.parts[spec.Name]:Clone()
		for _, child in clone:GetChildren() do
			child.Parent = nil -- a SurfaceAppearance or anything else the importer added
		end
		local cf, size = MeshKitImport.Placement(base, spec, kit.turn, CFrame, Vector3)
		clone.Name = spec.Name
		clone.Anchored = true
		clone.Size = size
		clone.CFrame = cf
		pcall(function()
			clone.PivotOffset = cf:Inverse() * base -- every piece pivots on the gate's floor point, as authored
		end)
		local solid = spec.CanCollide == true
		clone.CanCollide, clone.CanTouch, clone.CanQuery = solid, false, solid
		clone.CastShadow = spec.CastShadow == true
		clone.Color = self:rgb(spec.Color)
		clone.Material = Enum.Material[spec.Material]
		clone.Reflectance = spec.Reflectance or 0
		clone.Transparency = 0
		pcall(function()
			clone.TextureID = ""
		end)
		-- Studio-only properties (a running server cannot write them; the owner sets them on the kit
		-- too, IMPORTAR_ARCO.md): full detail at any distance, simple collision.
		pcall(function()
			clone.RenderFidelity = Enum.RenderFidelity.Precise
		end)
		pcall(function()
			clone.CollisionFidelity = if solid then Enum.CollisionFidelity.Hull else Enum.CollisionFidelity.Box
		end)
		clone:SetAttribute("RaceArenaPart", true)
		clone:SetAttribute("RaceAsset", FlashGate.KitStamp)
		clone.Parent = groups[spec.Group] or gate
		self.parts += 1
	end
	local glow = FlashGate.Kit.Glow
	self:part(groups[NAMES.Medallion], NAMES.MedallionGlow, Vector3.new(glow.Depth, glow.Radius * 2, glow.Radius * 2),
		base * CFrame.new(glow.Centre[1], glow.Centre[2], glow.Centre[3]) * CFrame.Angles(0, math.pi / 2, 0), FlashGate.Colors.GoldGlow,
		{ decor = true, material = "Neon", shape = "Cylinder", transparency = 0.35 })
end

function RaceArenaBuilder.BuildGate(parent: any, worldKey: string, env: any): any?
	local base = RaceArenaBuilder.GateCFrame(worldKey, env)
	if not base then
		return nil
	end
	local b = newBuilder(env)
	local Vector3, CFrame = env.Vector3, env.CFrame
	local ARCH, PAD, COLORS, NAMES = FlashGate.Arch, FlashGate.Pad, FlashGate.Colors, FlashGate.Names
	-- 2026-09-26 (owner): the Blender kit when it fits, else the parts.
	local kitFolder = gateKitFolder(env)
	local kit = RaceArenaBuilder.ResolveGateKit(kitFolder)
	if kitFolder ~= nil and not kit.ok then
		local log = if type(env.Warn) == "function" then env.Warn elseif typeof(warn) == "function" then warn else print
		local shown = {}
		for index = 1, math.min(3, #kit.problems) do
			shown[index] = kit.problems[index]
		end
		log(string.format("[RaceArenaBuilder] %s not used (%d problem(s)): %s; the gate is built from parts", FlashGate.KitName,
			#kit.problems, table.concat(shown, "; ")))
	end
	local gate = b:model("RaceGate", nil, "Atomic")
	gate:SetAttribute("RaceGateWorld", worldKey)
	gate:SetAttribute("RaceArenaVersion", RaceArenaBuilder.Version)
	gate:SetAttribute("RaceGateAssets", false)
	gate:SetAttribute(FlashGate.VersionAttribute, if kit.ok then FlashGate.MeshVersion else FlashGate.Version)
	gate:SetAttribute(FlashGate.KitAttribute, kit.ok)
	if kit.ok then
		gate:SetAttribute("RaceAsset", FlashGate.KitStamp)
		gate:SetAttribute("RaceGateKitTurn", kit.turn * 90)
	end

	-- The trigger stays where it always was (PadTouchService reads it); the ring pad shows it.
	local padSize = RaceArenaBuilder.GatePadSize
	local pad = b:part(gate, NAMES.Pad, Vector3.new(padSize, 0.4, padSize), base * CFrame.new(0, 0.2, 0), FLOOR_COLOR,
		{ collide = false, query = false, transparency = 1 })
	pad:SetAttribute("PadTriggerHeight", 10)

	if kit.ok then
		b:gateMeshes(gate, base, kit)
	else
		-- The arch: box segments around a half circle centred Leg studs up (each one's X radial, Y
		-- along the circle, Z through the arch; long enough to close the outer edge), on straight legs.
		local arch = b:model(NAMES.Arch, gate, nil)
		local function band(prefix, inner, outer, depth, color, gapDegrees, reflectance)
			local step = math.pi / ARCH.Segments
			local mid = (inner + outer) / 2
			local length = 2 * outer * math.tan(step / 2) + 0.02
			local pieces = {}
			for k = 1, ARCH.Segments do
				local angle = (k - 0.5) * step
				if math.abs(math.deg(angle) - 90) >= gapDegrees then
					table.insert(pieces, b:part(arch, prefix .. k, Vector3.new(outer - inner, length, depth),
						base * CFrame.new(math.cos(angle) * mid, ARCH.Leg + math.sin(angle) * mid, 0) * CFrame.Angles(0, 0, angle), color))
				end
			end
			for side = -1, 1, 2 do
				table.insert(pieces, b:part(arch, prefix .. (if side < 0 then "LegL" else "LegR"), Vector3.new(outer - inner, ARCH.Leg, depth),
					base * CFrame.new(side * mid, ARCH.Leg / 2, 0), color))
			end
			for _, piece in pieces do
				piece.Reflectance = reflectance
			end
		end
		band("Red", ARCH.Inner, ARCH.Outer, ARCH.Depth, COLORS.Red, 0, 0)
		band("Gold", ARCH.BandInner, ARCH.BandOuter, ARCH.BandDepth, COLORS.Gold, ARCH.BandGapDegrees, 0.15)

		-- The medallion at the top of the band: gold rim, cream face, the Neon bolt through both faces,
		-- and the glow ring just outside the rim (the client breathes it).
		local medallion = b:model(NAMES.Medallion, gate, nil)
		local centreY = ARCH.Leg + (ARCH.BandInner + ARCH.BandOuter) / 2
		local facing = base * CFrame.new(0, centreY, 0) * CFrame.Angles(0, math.pi / 2, 0) -- a cylinder's X axis along the gate's Z
		b:part(medallion, NAMES.MedallionGlow, Vector3.new(ARCH.GlowDepth, ARCH.Glow * 2, ARCH.Glow * 2), facing, COLORS.GoldGlow,
			{ decor = true, material = "Neon", shape = "Cylinder", transparency = 0.35 })
		local rim = b:part(medallion, "MedallionRim", Vector3.new(ARCH.RimDepth, ARCH.Rim * 2, ARCH.Rim * 2), facing, COLORS.Gold, { shape = "Cylinder" })
		rim.Reflectance = 0.15
		b:part(medallion, "MedallionFace", Vector3.new(ARCH.FaceDepth, ARCH.Face * 2, ARCH.Face * 2), facing, COLORS.Cream, { decor = true, shape = "Cylinder" })
		for index, stroke in FlashGate.Bolt do
			-- Viewer's right (u) is the gate's -x: the players look along the gate's +Z.
			local x1, y1, x2, y2 = -stroke[1][1], stroke[1][2], -stroke[2][1], stroke[2][2]
			local dx, dy = x2 - x1, y2 - y1
			b:part(medallion, "MedallionBolt" .. index, Vector3.new(math.sqrt(dx * dx + dy * dy) + stroke[3] * 0.35, stroke[3], ARCH.BoltDepth),
				base * CFrame.new((x1 + x2) / 2, centreY + (y1 + y2) / 2, 0) * CFrame.Angles(0, 0, math.atan2(dy, dx)), COLORS.Bolt,
				{ decor = true, material = "Neon" })
		end

		-- The ring pad: flat upright cylinders, each Step higher than the last (no two faces share a
		-- height), glow rings under dark covers; nothing collides (nobody trips on it).
		local ringPad = b:model(NAMES.RingPad, gate, nil)
		local upright = CFrame.Angles(0, 0, math.pi / 2)
		local layer = 0
		local function disc(name, radius, color, material)
			local top = PAD.Base + layer * PAD.Step
			layer += 1
			return b:part(ringPad, name, Vector3.new(top, radius * 2, radius * 2), base * CFrame.new(0, top / 2, 0) * upright, color,
				{ decor = true, material = material, shape = "Cylinder" })
		end
		disc("PadBase", PAD.Radius, COLORS.PadDark, "SmoothPlastic")
		for index, ring in PAD.Rings do
			disc("RingGlow" .. index, ring[2], COLORS[ring[1]], "Neon")
			disc("RingCover" .. index, ring[3], COLORS.PadDark, "SmoothPlastic")
		end
	end

	-- The sign for players far away, over the medallion.
	local signAnchor = b:part(gate, NAMES.SignAnchor, Vector3.new(1, 1, 1), base * CFrame.new(0, ARCH.SignHeight, 0), WHITE,
		{ decor = true, transparency = 1 })
	local sign = b:make("BillboardGui", NAMES.Sign, nil)
	sign.Adornee = signAnchor
	sign.Size = env.UDim2.fromScale(14, 6)
	sign.MaxDistance = 250
	sign.LightInfluence = 0
	sign.Parent = gate
	for index, name in { "Title", "Status", "Record" } do
		local line = b:label(sign, if name == "Title" then "RACE" else "", if name == "Record" then GOLD else WHITE)
		line.Name = name
		line.Size = env.UDim2.fromScale(1, if index == 1 then 0.44 else 0.28)
		line.Position = env.UDim2.fromScale(0, if index == 1 then 0 elseif index == 2 then 0.44 else 0.72)
	end

	-- Where The Flash stands (LobbyNpcs; the marker's bottom is the floor under his feet, its
	-- LookVector toward the players) and where his holo board opens.
	local beside = LobbyNpcConfig.FlashBesideGate[worldKey]
	local flashX, flashZ = FlashGate.FlashLocal(beside)
	local size = RaceArenaBuilder.FlashSpotSize
	local spot = b:part(gate, NAMES.FlashSpot, Vector3.new(size[1], size[2], size[3]), base * CFrame.new(flashX, size[2] * 0.5, flashZ), WHITE,
		{ decor = true, transparency = 1 })
	spot:SetAttribute("FlashSpot", true)
	b:part(gate, NAMES.Anchor, Vector3.new(FlashGate.Board.Width, FlashGate.Board.Height, 0.2),
		base * FlashGate.BoardLocal(beside, CFrame), WHITE, { decor = true, transparency = 1 })

	gate:SetAttribute("RaceArenaParts", b.parts)
	gate.Parent = parent
	return gate
end

return RaceArenaBuilder
