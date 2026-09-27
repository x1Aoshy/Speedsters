-- test_u4_race_placement.luau (Update 4, race_server, 2026-09-25) — `places`
-- The lobby Race Gate (PLAN §7.3 item 10, U4.Race.Gate) against the real maps. Reads the three
-- .rbxl files (never writes them), builds the gate in memory with RaceArenaBuilder.BuildGate at
-- the configured point, and checks:
--   the 12 x 12 pad sits on a collidable floor (within 3 studs under every corner and the middle);
--   the pad is >= 12 studs (XZ, edge to edge) from the spawn, the AFK spot (ring SpotRadius), the
--   disco floor, the admin treadmill, the Spin Wheel, the portal and the treadmills;
--   the arch's colliding parts do not cut into any other colliding part of the lobby.
-- 2026-09-25: the first probe points for World 1 and World 3 were inside the 21-stud block along
-- the lobby's back edge; Update4Config now carries the replacement points (open floor off the
-- walk to Stage 1), so the --proposed override is gone.
-- 2026-09-26 (owner): the gate is The Flash's arch (Shared/FlashGate; the Blender booth is no
-- longer used for it). Also checked now:
--   every visible piece of the arch, medallion and ring pad stays out of the lobby's parts (those
--   that collide or show) above the floor;
--   FlashSpot is LobbyNpcConfig.FlashBeside's point (where the build stands the owner's Flash),
--   on the floor, looking where the gate looks;
--   the holo board (HoloBoardAnchor: the open board's box, and its collapsed header) floats clear
--   of every lobby part that collides or shows, above the floor, and neither it nor any solid
--   piece of the gate stands in the world-portal flight's shot (audit/u4_race_board.PortalView,
--   as audit/test_fable_tutorial_portal films it).
-- The old Race_* board (stamped RaceBoard: the next build removes it) and a gate or arena the
-- build already put in the place are not obstacles. Where the pad's trigger volume reaches a
-- lobby part (someone touching it could join) a NOTE is printed.
-- 2026-09-26 (owner): every check runs twice per place: for the part-built gate and for the Blender
-- kit's mesh gate (FlashGate.Kit; the owner's design/race/flashgate/FlashGateKit.rbxm once saved,
-- else audit/u4_flash_gate_kit's stand-in of Studio's import). The meshes are checked by their
-- boxes, so the arch's box (its opening included) must be clear too.
-- Run: lune run audit/test_u4_race_placement.luau   (from the project root)
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local Vector3, CFrame = roblox.Vector3, roblox.CFrame

local U4 = require("../src/common/ReplicatedStorage/Shared/Update4Config")
local RaceArenaBuilder = require("../src/common/ServerScriptService/Services/Race/RaceArenaBuilder")
local FlashGate = require("../src/common/ReplicatedStorage/Shared/FlashGate")
local LobbyNpcConfig = require("../src/common/ReplicatedStorage/Shared/LobbyNpcConfig")
local Board = require("./u4_race_board")

local ENV = {
	Instance = roblox.Instance, Vector3 = roblox.Vector3, CFrame = roblox.CFrame, Color3 = roblox.Color3,
	Enum = roblox.Enum, UDim2 = roblox.UDim2, NumberRange = roblox.NumberRange, RaceAssets = false,
}
local PLACES = { World1 = "World1Update3New.rbxl", World2 = "World2Update3new.rbxl", World3 = "World3Update3New.rbxl" }
local CLEARANCE = 12
local FLOOR_DROP = 3
local FLOOR_SKIN = 0.35 -- a lobby part whose top is this close to the gate's floor is floor
local BOARD_SLACK = 0.3 -- the board's box grown by this (it floats: nothing may graze it)

----------------------------------------------------------------------
-- Config.luau cannot load in Lune (it reads the place at require time): its lobby spots are
-- read from the source text.
----------------------------------------------------------------------
local configSource = fs.readFile("src/common/ReplicatedStorage/Shared/Config.luau")
local function block(startPattern)
	local start = assert(string.find(configSource, startPattern, 1, true), "Config block " .. startPattern)
	local stop = string.find(configSource, "\n}\n", start, true)
	return string.sub(configSource, start, stop)
end
local function vector(text)
	local x, y, z = string.match(text, "Vector3%.new%(%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*%)")
	return Vector3.new(tonumber(x), tonumber(y), tonumber(z))
end
local afkBlock = block("Config.AfkZone = {")
local spotRadius = tonumber(string.match(afkBlock, "SpotRadius%s*=%s*([%d%.]+)")) or 22
local treadmillBlock = block("Config.AdminTreadmill = {")
local discoBlock = block("Config.AdminDisco = {")
local spots = {}
for world in PLACES do
	local afkLine = string.match(afkBlock, world .. "%s*=%s*(Vector3%.new%b())")
	local treadLine = string.match(treadmillBlock, world .. "%s*=%s*{%s*Position%s*=%s*(Vector3%.new%b())")
	local discoWorld = string.match(discoBlock, world .. "%s*=%s*(%b{})")
	spots[world] = {
		afk = vector(assert(afkLine, world .. " AFK spot")),
		treadmill = vector(assert(treadLine, world .. " admin treadmill")),
		discoFloor = vector(assert(string.match(discoWorld, "Floor%s*=%s*(Vector3%.new%b())"), world .. " disco floor")),
		discoSize = vector(assert(string.match(discoWorld, "Size%s*=%s*(Vector3%.new%b())"), world .. " disco size")),
	}
end

----------------------------------------------------------------------
-- Geometry
----------------------------------------------------------------------
local function aabb(part)
	local cf, size = part.CFrame, part.Size
	local lo = { math.huge, math.huge, math.huge }
	local hi = { -math.huge, -math.huge, -math.huge }
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local p = cf * Vector3.new(sx * size.X / 2, sy * size.Y / 2, sz * size.Z / 2)
				lo[1], lo[2], lo[3] = math.min(lo[1], p.X), math.min(lo[2], p.Y), math.min(lo[3], p.Z)
				hi[1], hi[2], hi[3] = math.max(hi[1], p.X), math.max(hi[2], p.Y), math.max(hi[3], p.Z)
			end
		end
	end
	return { x0 = lo[1], y0 = lo[2], z0 = lo[3], x1 = hi[1], y1 = hi[2], z1 = hi[3] }
end
-- XZ distance between two boxes (0 when they overlap).
local function gapXZ(a, b)
	local dx = math.max(b.x0 - a.x1, a.x0 - b.x1, 0)
	local dz = math.max(b.z0 - a.z1, a.z0 - b.z1, 0)
	return math.sqrt(dx * dx + dz * dz)
end
local function rect(center, halfX, halfZ)
	return { x0 = center.X - halfX, x1 = center.X + halfX, z0 = center.Z - halfZ, z1 = center.Z + halfZ, y0 = -math.huge, y1 = math.huge }
end
local function overlaps(box, other)
	local overlap = math.min(box.x1, other.x1) - math.max(box.x0, other.x0)
	local overlapY = math.min(box.y1, other.y1) - math.max(box.y0, other.y0)
	local overlapZ = math.min(box.z1, other.z1) - math.max(box.z0, other.z0)
	return overlap > 0.1 and overlapY > 0.1 and overlapZ > 0.1
end
local I = Board._internal

local FlashGateKit = require("./u4_flash_gate_kit")
local VARIANTS = { { label = "parts", env = ENV } }
local kitManifest = FlashGateKit.Manifest()
if kitManifest then
	local meshEnv = table.clone(ENV)
	meshEnv.FlashGateKit = FlashGateKit.Load() or FlashGateKit.StandIn(kitManifest)
	table.insert(VARIANTS, { label = "Blender kit", env = meshEnv })
end

----------------------------------------------------------------------
-- Checks
----------------------------------------------------------------------
local failures = {}
for world, file in PLACES do
	local game = roblox.deserializePlace(fs.readFile(file))
	local workspace = game:GetService("Workspace")
	for _, variant in VARIANTS do
		local holder = roblox.Instance.new("Folder")
		holder.Parent = workspace
		local gate = RaceArenaBuilder.BuildGate(holder, world, variant.env)
		local base = RaceArenaBuilder.GateCFrame(world, ENV)
		local pad = gate.RaceGatePad
		local padBox = aabb(pad)
		local floorY = U4.Race.Gate[world].Position.Y
		local problems = {}

		-- Zones to keep clear of, and the lobby's parts.
		local zones = {}
		local models = {}
		local colliders = {} -- colliding lobby parts near the gate
		local solids = {} -- colliding or visible lobby parts over the floor near the gate
		-- After a build the place already carries the real gate and arena (build_update4 inserts them):
		-- they are the thing under test, not lobby features to keep clear of. The old Race_* board goes
		-- with the next build.
		local built = {}
		for _, name in { "RaceGate", "RaceArena" } do
			local existing = workspace:FindFirstChild(name)
			if existing and existing ~= holder then
				table.insert(built, existing)
			end
		end
		local function skipped(d)
			for _, root in built do
				if d:IsDescendantOf(root) then
					return true
				end
			end
			if d:GetAttribute("U4Asset") == Board.Stamp then
				return true
			end
			-- The owner's Flash stands at FlashSpot on purpose.
			local cursor = d.Parent
			while cursor and cursor ~= workspace do
				if cursor:IsA("Model") and LobbyNpcConfig.KindForName(cursor.Name) == "Flash" then
					return true
				end
				cursor = cursor.Parent
			end
			return false
		end
		for _, d in workspace:GetDescendants() do
			if d:IsA("BasePart") and d.ClassName ~= "Terrain" and not d:IsDescendantOf(holder) and not skipped(d) then
				local box = aabb(d)
				if box.x1 >= padBox.x0 - 200 and box.x0 <= padBox.x1 + 200 and box.z1 >= padBox.z0 - 200 and box.z0 <= padBox.z1 + 200 then
					if d:IsA("SpawnLocation") then
						table.insert(zones, { name = "spawn " .. d:GetFullName(), box = box })
					end
					local path = string.lower(d:GetFullName())
					for _, key in { "treadmill", "portal", "spinwheel" } do
						if string.find(path, key, 1, true) then
							-- Grouped by the highest ancestor whose name carries the key.
							local owner = d
							local cursor = d
							while cursor and cursor ~= workspace do
								if string.find(string.lower(cursor.Name), key, 1, true) then
									owner = cursor
								end
								cursor = cursor.Parent
							end
							local id = key .. ":" .. owner:GetFullName()
							models[id] = models[id] and {
								x0 = math.min(models[id].x0, box.x0), y0 = math.min(models[id].y0, box.y0), z0 = math.min(models[id].z0, box.z0),
								x1 = math.max(models[id].x1, box.x1), y1 = math.max(models[id].y1, box.y1), z1 = math.max(models[id].z1, box.z1),
							} or box
						end
					end
					if d.CanCollide then
						table.insert(colliders, { part = d, box = box })
					end
					if (d.CanCollide or d.Transparency < 0.95) and box.y1 > floorY + FLOOR_SKIN then
						table.insert(solids, { part = d, box = box })
					end
				end
			end
		end
		for name, box in models do
			table.insert(zones, { name = name, box = box })
		end
		local spot = spots[world]
		table.insert(zones, { name = "AFK spot", box = rect(spot.afk, spotRadius, spotRadius) })
		table.insert(zones, { name = "disco floor", box = rect(spot.discoFloor, spot.discoSize.X / 2, spot.discoSize.Z / 2) })
		-- The admin treadmill is ~38 long (toward its Face, +-Z in every lobby) and ~27 wide.
		table.insert(zones, { name = "admin treadmill", box = rect(spot.treadmill, 13.5, 19) })

		-- 1. On a floor: every corner (1 stud in) and the middle has a colliding top within 3 studs below.
		for _, offset in { { 0, 0 }, { -5, -5 }, { 5, -5 }, { -5, 5 }, { 5, 5 } } do
			local point = pad.CFrame * Vector3.new(offset[1], -pad.Size.Y / 2, offset[2])
			local supported = false
			for _, entry in colliders do
				local part = entry.part
				local rel = part.CFrame:PointToObjectSpace(point)
				if math.abs(rel.X) <= part.Size.X / 2 and math.abs(rel.Z) <= part.Size.Z / 2 then
					local drop = part.Size.Y / 2 - rel.Y -- how far the top is below the point (negative: above)
					local top = point.Y - drop
					if drop >= -0.05 and drop <= FLOOR_DROP and top <= floorY + 0.05 then
						supported = true
						break
					end
				end
			end
			if not supported then
				table.insert(problems, string.format("no floor within %d studs under the pad at (%.1f, %.1f)", FLOOR_DROP, point.X, point.Z))
			end
		end

		-- 2. Clearance from the lobby's features.
		local nearest, nearestName = math.huge, ""
		for _, zone in zones do
			local gap = gapXZ(padBox, zone.box)
			if gap < nearest then
				nearest, nearestName = gap, zone.name
			end
			if gap < CLEARANCE then
				table.insert(problems, string.format("%.1f studs from %s (needs %d)", gap, zone.name, CLEARANCE))
			end
		end

		-- 3. The gate's colliding parts cut into nothing that collides (floors under it may touch);
		-- its visible pieces reach into no lobby part over the floor.
		local gateBox = nil
		for _, part in gate:GetDescendants() do
			if part:IsA("BasePart") then
				local box = aabb(part)
				if part.CanCollide then
					for _, entry in colliders do
						if overlaps(box, entry.box) then
							table.insert(problems, string.format("gate %s cuts into %s", part.Name, entry.part:GetFullName()))
							break
						end
					end
				end
				if part.Transparency < 1 then
					gateBox = if gateBox then { x0 = math.min(gateBox.x0, box.x0), z0 = math.min(gateBox.z0, box.z0),
						x1 = math.max(gateBox.x1, box.x1), z1 = math.max(gateBox.z1, box.z1) } else box
					local exact = I.boxOf(part.CFrame, part.Size)
					for _, entry in solids do
						if overlaps(box, entry.box) and I.overlapDepth(exact, I.boxOf(entry.part.CFrame, entry.part.Size)) > 0.1 then
							table.insert(problems, string.format("gate %s reaches into %s", part.Name, entry.part:GetFullName()))
							break
						end
					end
				end
			end
		end

		-- 4. FlashSpot: LobbyNpcConfig's point beside the arch, on the floor, facing the players.
		local flashSpot = gate:FindFirstChild("FlashSpot")
		local expected = LobbyNpcConfig.FlashBeside(world)
		local feet = flashSpot and flashSpot.CFrame.Position - Vector3.new(0, flashSpot.Size.Y / 2, 0)
		if not feet or not expected or (feet - expected.Position).Magnitude > 0.02 then
			table.insert(problems, "FlashSpot is not LobbyNpcConfig.FlashBeside's point")
		elseif flashSpot.CFrame.LookVector:Dot(base.LookVector) < 0.999 then
			table.insert(problems, "FlashSpot does not look where the gate looks")
		end

		-- 5. The holo board (open, and its header) floats clear of the lobby and the portal's shot.
		local anchor = gate:FindFirstChild("HoloBoardAnchor")
		local view = Board.PortalView(world)
		if not anchor then
			table.insert(problems, "no HoloBoardAnchor")
		else
			local grown = anchor.Size + Vector3.new(BOARD_SLACK * 2, BOARD_SLACK * 2, BOARD_SLACK * 2)
			local boardBox = aabb({ CFrame = anchor.CFrame, Size = grown })
			local exact = I.boxOf(anchor.CFrame, grown)
			if boardBox.y0 < floorY + 1 then
				table.insert(problems, "the holo board reaches the floor")
			end
			for _, entry in solids do
				if overlaps(boardBox, entry.box) and I.overlapDepth(exact, I.boxOf(entry.part.CFrame, entry.part.Size)) > 0 then
					table.insert(problems, "the holo board runs into " .. entry.part:GetFullName())
					break
				end
			end
			for _, segment in view do
				if I.segmentHitsBox(segment[1], segment[2], exact, Board.ViewPad) then
					table.insert(problems, "the holo board blocks the world-portal flight's view")
					break
				end
			end
		end
		for _, part in gate:GetDescendants() do
			if part:IsA("BasePart") and part.Transparency < 0.6 and part.Size.Magnitude >= 3 then
				local exact = I.boxOf(part.CFrame, part.Size)
				for _, segment in view do
					if I.segmentHitsBox(segment[1], segment[2], exact, Board.ViewPad) then
						table.insert(problems, "gate " .. part.Name .. " blocks the world-portal flight's view")
						break
					end
				end
			end
		end

		-- Note only: the pad's trigger (pad + 2 studs a side, 10 tall) reaching a lobby part.
		local trigger = aabb({ CFrame = base * CFrame.new(0, 5.2, 0), Size = Vector3.new(16, 10, 16) })
		for _, entry in colliders do
			if entry.box.y1 > floorY + FLOOR_SKIN and overlaps(trigger, entry.box) then
				print(string.format("  NOTE %s: the gate pad's trigger reaches %s (touching it can join the race)", world, entry.part:GetFullName()))
			end
		end

		local placement = U4.Race.Gate[world]
		if #problems == 0 then
			print(string.format("  %s gate (%s) at %s: on the floor, nearest feature %.1f studs (%s); arch %.1f x %.1f studs; Flash and his board clear",
				world, variant.label, tostring(placement.Position), nearest, nearestName, gateBox.x1 - gateBox.x0, gateBox.z1 - gateBox.z0))
		else
			table.insert(failures, world .. " (" .. variant.label .. ")")
			print(string.format("  %s gate (%s) at %s:", world, variant.label, tostring(placement.Position)))
			for index = 1, math.min(8, #problems) do
				print("    FAIL " .. problems[index])
			end
		end
		holder.Parent = nil
	end
end

if #failures > 0 then
	error(string.format("test_u4_race_placement: the Race Gate is misplaced in %s", table.concat(failures, ", ")))
end
print("PASS The Flash's Race Gate (" .. #VARIANTS .. " builds: parts" .. (if #VARIANTS > 1 then ", the Blender kit" else "")
	.. ") sits on the floor, clear of the lobby; FlashSpot beside it; the holo board clear of the lobby and the portal shot, in all 3 places")
print("test_u4_race_placement: 1 check passed")
