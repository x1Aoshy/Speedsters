-- test_u4_greenhill.luau (Update 4, 2026-09-26): the Green Hill race map as the build puts it in
-- (audit/u4_greenhill_arena.luau from Astra's design/race/Astra_Recta/RaceArena.rbxm), and the
-- runtime pieces around it.
--   1. the gameplay contract survives the conversion: every gameplay part of Astra's map is
--      there with the same path, class, CFrame, Size, collisions and attributes (the StartGate is
--      closed at rest), the contract names (CONTRATO_MAPA_ASTRA §2), Persistent streaming;
--   2. no local content (rbxasset://) is left anywhere, Astra's Visuals and their wind tags are
--      gone, every part is anchored and RaceArenaPart, the decor never collides, touches or
--      queries;
--   3. barriers: invisible walls on x +-38.1 from under the water to >= 60 studs over the highest
--      floor (80, the corridor's height: the default jump is 7.2), end caps behind the staging box and after the run-out,
--      inside the anti-cheat corridor; the fences cover both edges for the full length; the bank
--      lips fill the slot by the walls and never stand above the floor; the verge is 0.3 over it;
--   4. nothing decorative inside |x| < 38.1 stands more than 0.5 over the ground unless its bottom
--      is 13+ over it (the start and finish beams, palm fronds, the ORB);
--   5. the ground profile of the new floor (RaceTrack.BuildProfile over vertical rays, as
--      RaceServer's raycast sees it, with and without the decor) keeps Update4Config.Race.Ground
--      (slope, step, height, flat start and finish), matches Astra's map_data samples, and
--      round-trips through Encode/Decode;
--   6. the speed pads and spike tiles line up with Update4Config (RaceTrack.PadsFromParts,
--      RaceTrack.SpikeTiles), on the ground, with their art on top; 2026-09-26: the tiles are
--      made from Update4Config (GreenHill.SpikesFromConfig: 2-3 rows a field, 90 apart), not
--      kept from Astra's map, so section 1 compares every other gameplay part;
--   7. part budgets (with and without the kit) and water: every number on the voxel grid, the
--      decor stands in it and inside it, nothing of the race under it;
--   8. a stand-in kit without a manifest: Kit_* pieces placed per layout on their box's bottom
--      centre (yaw, scale), never colliding, lowPower tags, small plants without shadows, palm
--      wind attributes, edge fences tiled from Kit_FenceSection, the kit's dirt texture on the
--      floor, a piece inside the track skipped, a missing piece and a floating mesa warned, a kit
--      with local content refused; 8b. the kit artist's real layout.json + kit_manifest.json on
--      MeshParts made from the manifest: all 1,390 placements by the manifest's formula, none in
--      the track or over the void, the verge plants on the verge, pads fitted to the 18 x 16 art,
--      the layout's fences end to end, the budgets (all parts / drawn on phones);
--   9. Gameplay/RaceArenaWater in a fake place (strips, layers, once, kill switch, no Terrain,
--      FillBlock failing), Shared/RaceTropicalLook with fake Lighting/Terrain (blend in and out,
--      only what is still its own, never blendLighting's properties, admin sky events win, Low
--      phones leave the clouds), RacePalmWind and RaceServer (StartGate) statically;
--  10. build_update4 `--greenhill`: insertGreenHill on in-memory places (replaces our stamps,
--      refuses others, keeps RaceGate) and `list --greenhill` (read-only).
-- `places` (read only): the converted arena >= 1500 studs from every other part of each place
-- (and the water region clear of them), the places' jump height under the walls, and when a
-- place already carries the Green Hill arena, GreenHill.Verify on it. `places prebuild` (the
-- checks before a build, 2026-09-26): an arena whose spike tiles only predate Update4Config's
-- layout is noted, not failed (the build's --greenhill makes it again; after it, `places` is strict).
-- Run: lune run audit/test_u4_greenhill.luau [places [prebuild]]   (from the project root)
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local U4 = require("../src/common/ReplicatedStorage/Shared/Update4Config")
local RaceTrack = require("../src/common/ReplicatedStorage/Shared/RaceTrack")
local RaceTropicalLook = require("../src/common/ReplicatedStorage/Shared/RaceTropicalLook")
local GreenHill = require("./u4_greenhill_arena")

local Instance, Vector3, CFrame, Color3, Enum = roblox.Instance, roblox.Vector3, roblox.CFrame, roblox.Color3, roblox.Enum
local ORIGIN = U4.Race.Arena.Origin
local TRACK = U4.Race.Track
local GROUND = U4.Race.Ground
local PADS = U4.Race.Pads
local WATER = U4.Race.Water
local VALIDATION = U4.Race.Validation
local DEFAULT_JUMP = 7.2 -- StarterPlayer.CharacterJumpHeight in the three places (checked in `places`)

local passed = 0
local function pass(text)
	passed += 1
	print("PASS " .. text)
end

local function read(path)
	return (fs.readFile(path):gsub("\r\n", "\n"))
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

-- A path that tells same-named siblings apart (the five SpeedPads): name#k from the root down.
local function relPath(instance)
	local parts = {}
	local current = instance
	while current and current.Parent do
		local k = 0
		for _, sibling in current.Parent:GetChildren() do
			if sibling.Name == current.Name then
				k += 1
			end
			if sibling == current then
				break
			end
		end
		table.insert(parts, 1, current.Name .. "#" .. k)
		current = current.Parent
	end
	return table.concat(parts, "/")
end

local function localS(position)
	return ORIGIN.Z - position.Z
end

-- The top surface of a (pitched) block at track-local (s, x): nil when (s, x) is off its top.
local function topAt(part, s, x)
	local cf, size = part.CFrame, part.Size
	local here = cf:PointToObjectSpace(GreenHill.World(s, x, 0))
	if math.abs(here.X) > size.X * 0.5 + 1e-3 then
		return nil
	end
	-- Walk along the top face to the point over (s, x) (a few steps: the pitch is small).
	local localZ = here.Z
	for _ = 1, 4 do
		local point = cf * Vector3.new(here.X, size.Y * 0.5, localZ)
		localZ += (ORIGIN.Z - s) - point.Z
	end
	if math.abs(localZ) > size.Z * 0.5 + 1e-3 then
		return nil
	end
	return (cf * Vector3.new(here.X, size.Y * 0.5, localZ)).Y - ORIGIN.Y
end

-- The verge's top at (s, x): the highest Verge_* part there.
local function vergeTopAt(root, s, x)
	local best = nil
	for _, part in root:GetDescendants() do
		if part:IsA("BasePart") and string.sub(part.Name, 1, 6) == "Verge_" then
			local top = topAt(part, s, x)
			if top and (best == nil or top > best) then
				best = top
			end
		end
	end
	return best
end

local function inside(instance, ancestorName, arena)
	local current = instance
	while current and current ~= arena do
		if current.Parent == arena then
			return current.Name == ancestorName
		end
		current = current.Parent
	end
	return false
end

----------------------------------------------------------------------
-- Build once (no kit) and keep Astra's original for comparison
----------------------------------------------------------------------
local source = GreenHill.LoadSource()
local original = source:Clone()
local arena, report = GreenHill.Build({ source = source, kit = false })
print("  " .. GreenHill.Describe(report))

----------------------------------------------------------------------
-- 1. The gameplay contract survives
----------------------------------------------------------------------
local sourcePaths = {}
do
	local kept, compared = 0, 0
	local byPath = {}
	for _, d in arena:GetDescendants() do
		byPath[relPath(d)] = d
	end
	for _, d in original:GetDescendants() do
		local top = d
		while top.Parent ~= original do
			top = top.Parent
		end
		-- 2026-09-26: Astra's spike tiles are replaced by Update4Config's (section 6 checks them).
		if table.find(GreenHill.GameplayNames, top.Name) and top.Name ~= "Spikes" and (d:IsA("BasePart") or d:IsA("Attachment")) then
			local path = relPath(d)
			sourcePaths[path] = true
			local copy = byPath[path]
			assert(copy, "kept: " .. path)
			assert(copy.ClassName == d.ClassName, path .. ": class")
			local a, b = { copy.CFrame:GetComponents() }, { d.CFrame:GetComponents() }
			for index = 1, 12 do
				assert(a[index] == b[index], path .. ": CFrame unchanged")
			end
			if d:IsA("BasePart") then
				assert(copy.Size == d.Size, path .. ": Size unchanged")
				assert(copy.CanQuery == d.CanQuery and copy.CanTouch == d.CanTouch and copy.Transparency == d.Transparency
					and copy.Anchored == d.Anchored, path .. ": query/touch/transparency/anchored unchanged")
				if d.Name == "StartGate" then
					assert(copy.CanCollide == true, "StartGate closed at rest (the server opens it at GO)")
				else
					assert(copy.CanCollide == d.CanCollide, path .. ": CanCollide unchanged")
				end
				assert(copy:GetAttribute("RaceArenaPart") == true, path .. ": RaceArenaPart")
				kept += 1
			end
			for key, value in d:GetAttributes() do
				assert(copy:GetAttribute(key) == value, path .. ": attribute " .. key)
			end
			compared += 1
		end
	end
	assert(kept == 344 and report.gameplayParts == kept + #RaceTrack.SpikeTiles() and report.spikeTiles == #RaceTrack.SpikeTiles(),
		"Astra's 344 gameplay parts kept (" .. kept .. ") + Update4Config's " .. #RaceTrack.SpikeTiles() .. " spike tiles")
	-- The contract names.
	local s = arena.Structure
	assert(s:FindFirstChild("StartGate") and s:FindFirstChild("StopBar"), "Structure.StartGate / StopBar")
	for light = 1, 5 do
		assert(s.StartGantry:FindFirstChild("Light" .. light), "StartGantry.Light" .. light)
	end
	for spot = 1, 4 do
		assert(arena.FinishGate:FindFirstChild("ConfettiSpot_" .. spot), "FinishGate.ConfettiSpot_" .. spot)
	end
	assert(arena.RaceOrb:IsA("BasePart") and arena.RaceOrb:FindFirstChild("Shell") and arena.RaceOrb:FindFirstChild("Core"),
		"RaceOrb with the Shell RaceArenaVisuals spins and a Core")
	for _, name in GreenHill.PersistentNames do
		local model = arena:FindFirstChild(name)
		assert(model and model.ClassName == "Model" and model.ModelStreamingMode == Enum.ModelStreamingMode.Persistent, name .. " Persistent")
	end
	for _, name in { "Barriers", "Banks" } do
		assert(arena[name].ModelStreamingMode == Enum.ModelStreamingMode.Persistent, name .. " Persistent")
	end
	for _, chunk in arena.GreenHillDecor:GetChildren() do
		assert(chunk.ClassName == "Model" and chunk.ModelStreamingMode == Enum.ModelStreamingMode.Atomic, chunk.Name .. " Atomic")
	end
	for _, tile in arena.Spikes:GetChildren() do
		assert(tile:GetAttribute("RaceSpikeTile") == true and tile:GetAttribute("RaceArenaPart") == true, tile.Name .. ": RaceSpikeTile")
		assert(not tile.CanCollide and not tile.CanTouch and not tile.CanQuery and tile.Anchored, tile.Name .. ": never collides, touches or is queried")
	end
	assert(#GreenHill.Verify(arena) == 0, "GreenHill.Verify: " .. table.concat(GreenHill.Verify(arena), "; "))
	pass(("gameplay contract: %d parts/attachments of Astra's map kept exactly (StartGate closed at rest), contract names, Persistent/Atomic streaming"):format(compared))
end

----------------------------------------------------------------------
-- 2. No local content; decor never collides
----------------------------------------------------------------------
local added = {}
do
	local xml = roblox.serializeModel({ arena }, true)
	assert(#GreenHill.LocalUris(xml) == 0, "no rbxasset:// left (" .. tostring(GreenHill.LocalUris(xml)[1]) .. ")")
	assert(#GreenHill.LocalUris(roblox.serializeModel({ original }, true)) > 200, "(Astra's map did have them)")
	for uri in string.gmatch(xml, "rbxasset://[^<\"%s]*") do
		assert(string.sub(uri, 1, 17) == "rbxasset://fonts/", "only engine fonts: " .. uri)
	end
	assert(arena:FindFirstChild("Visuals") == nil, "Astra's Visuals folder is gone")
	assert(report.removedParts == 144, "Astra's 144 local-mesh parts removed (" .. report.removedParts .. ")")
	for _, d in arena:GetDescendants() do
		assert(not d:IsA("LuaSourceContainer"), "no scripts in the arena")
		assert(not d:IsA("SpecialMesh") and not d:IsA("MeshPart"), "no meshes in the part-built arena: " .. d:GetFullName())
	end
	for _, part in baseParts(arena) do
		assert(part.Anchored, part:GetFullName() .. " anchored")
		assert(part:GetAttribute("RaceArenaPart") == true, part:GetFullName() .. " RaceArenaPart")
		if not sourcePaths[relPath(part)] then
			table.insert(added, part)
			if part:HasTag("RacePalmWind") then
				assert(typeof(part:GetAttribute("WindBase")) == "Vector3" and typeof(part:GetAttribute("WindCrown")) == "Vector3"
					and part:GetAttribute("WindTree") ~= nil, part:GetFullName() .. ": palm wind attributes")
			end
			if inside(part, "Barriers", arena) then
				assert(part.CanCollide and part.Transparency == 1 and not part.CanTouch and not part.CanQuery, part.Name .. ": invisible wall")
			elseif inside(part, "Banks", arena) then
				assert(part.CanCollide and not part.CanTouch and part.Transparency == 0 and string.sub(part.Name, 1, 8) == "BankLip_",
					part.Name .. ": collidable bank lip")
			else
				assert(not part.CanCollide and not part.CanTouch and not part.CanQuery, part:GetFullName() .. ": decor never collides/touches/queries")
			end
		end
	end
	for _, part in baseParts(original) do
		if part:HasTag("RacePalmWind") then
			assert(not arena:FindFirstChild(part.Name, true) or not arena:FindFirstChild(part.Name, true):HasTag("RacePalmWind"),
				"Astra's palm " .. part.Name .. " left with its tag")
		end
	end
	pass(("no local content (Astra's %d mesh parts and %d meshes out, %d tags with them), %d added parts anchored, decor inert"):format(
		report.removedParts, report.removedObjects, report.removedTags, #added))
end

----------------------------------------------------------------------
-- 3. Barriers, end caps, fences, banks
----------------------------------------------------------------------
local ground = report.ground
do
	local walls = { [-1] = {}, [1] = {} }
	local maxFloor = 0
	for s = GreenHill.S0, GreenHill.S1, 1 do
		maxFloor = math.max(maxFloor, ground(s, -1), ground(s, 1))
	end
	for _, wall in arena.Barriers:GetChildren() do
		local p = wall.CFrame.Position
		local top = p.Y + wall.Size.Y * 0.5 - ORIGIN.Y
		local bottom = p.Y - wall.Size.Y * 0.5 - ORIGIN.Y
		assert(top - maxFloor >= GreenHill.WallClearance - 0.01 and GreenHill.WallClearance >= 60 and GreenHill.WallClearance >= VALIDATION.CorridorYMax,
			wall.Name .. ": >= 60 studs (and the corridor's height) over the highest floor")
		assert(bottom <= WATER.Bottom, wall.Name .. ": down into the water")
		local x = p.X - ORIGIN.X
		assert(math.abs(x) + wall.Size.X * 0.5 <= VALIDATION.CorridorHalfWidth, wall.Name .. ": inside the anti-cheat corridor")
		if string.sub(wall.Name, 1, 4) == "Wall" then
			assert(math.abs(math.abs(x) - GreenHill.WallX) < 1e-3, wall.Name .. ": on the contract's line x +-38.1")
			table.insert(walls[if x < 0 then -1 else 1], { localS(p) - wall.Size.Z * 0.5, localS(p) + wall.Size.Z * 0.5 })
		end
	end
	for side, list in walls do
		table.sort(list, function(a, b)
			return a[1] < b[1]
		end)
		assert(list[1][1] <= GreenHill.S0 - 0.99 and list[#list][2] >= GreenHill.S1 + 0.99, "walls from the back cap to the end cap")
		for index = 2, #list do
			assert(list[index][1] <= list[index - 1][2] + 1e-3, "side " .. side .. ": walls continuous")
		end
	end
	local back, finish = arena.Barriers.BackCap, arena.Barriers.EndCap
	assert(localS(back.CFrame.Position) + back.Size.Z * 0.5 <= GreenHill.S0 + 1e-3 and back.Size.X >= 2 * GreenHill.WallX, "BackCap behind the staging box, across the walls")
	assert(localS(finish.CFrame.Position) - finish.Size.Z * 0.5 >= GreenHill.S1 - 1e-3 and finish.Size.X >= 2 * GreenHill.WallX, "EndCap after the run-out, across the walls")
	assert(-(localS(back.CFrame.Position) - back.Size.Z * 0.5) <= -VALIDATION.CorridorSMin and localS(finish.CFrame.Position) <= VALIDATION.CorridorSMax,
		"end caps inside the corridor's s range")

	-- Fences: posts and both rails along the whole length of both edges, outside x 38.1.
	local rails = { [-1] = { {}, {} }, [1] = { {}, {} } } -- FenceRail1_k (lower) / FenceRail2_k
	local posts = { [-1] = {}, [1] = {} }
	for _, part in added do
		local name = part.Name
		local x = part.CFrame.Position.X - ORIGIN.X
		local side = if x < 0 then -1 else 1
		if string.sub(name, 1, 9) == "FenceRail" then
			local lo, hi = GreenHill.AABB({ part })
			assert(math.min(math.abs(lo.X - ORIGIN.X), math.abs(hi.X - ORIGIN.X)) >= GreenHill.DecorClearX, "rail outside 38.1")
			local level = tonumber(string.sub(name, 10, 10))
			table.insert(rails[side][level], { ORIGIN.Z - hi.Z, ORIGIN.Z - lo.Z })
		elseif name == "FencePost" then
			assert(math.abs(x) - part.Size.X * 0.5 >= GreenHill.DecorClearX, "post outside 38.1")
			table.insert(posts[side], localS(part.CFrame.Position))
		end
	end
	for side = -1, 1, 2 do
		for level = 1, 2 do
			local list = rails[side][level]
			table.sort(list, function(a, b)
				return a[1] < b[1]
			end)
			assert(list[1][1] <= GreenHill.S0 + 0.5 and list[#list][2] >= GreenHill.S1 - 0.5, "rails cover the full length")
			for index = 2, #list do
				assert(list[index][1] <= list[index - 1][2] + 0.05, "rails continuous")
			end
		end
		table.sort(posts[side])
		assert(posts[side][1] <= GreenHill.S0 + 1 and posts[side][#posts[side]] >= GreenHill.S1 - GreenHill.PostEvery, "posts from end to end")
		for index = 2, #posts[side] do
			assert(posts[side][index] - posts[side][index - 1] <= GreenHill.PostEvery + 1e-6, "a post every PostEvery studs at most")
		end
	end

	-- Bank lips (x 36..38.1, collidable): never above the floor, at most 0.65 under it. Verges
	-- (x 38.1..BankOuter, decor): VergeLift (0.3) over the floor, +-0.25, where the kit's plants sit.
	local lips = { [-1] = {}, [1] = {} }
	for _, lip in arena.Banks:GetChildren() do
		local cf, size = lip.CFrame, lip.Size
		local side = if cf.Position.X < ORIGIN.X then -1 else 1
		local innerX = math.abs(cf.Position.X - ORIGIN.X) - size.X * 0.5
		local outerX = math.abs(cf.Position.X - ORIGIN.X) + size.X * 0.5
		assert(math.abs(innerX - GreenHill.FloorHalf) < 1e-3 and math.abs(outerX - GreenHill.WallX) < 1e-3, lip.Name .. ": from the floor's edge to the wall line")
		local s0 = localS((cf * CFrame.new(0, size.Y * 0.5, size.Z * 0.5)).Position)
		local s1 = localS((cf * CFrame.new(0, size.Y * 0.5, -size.Z * 0.5)).Position)
		table.insert(lips[side], { math.min(s0, s1), math.max(s0, s1) })
	end
	local checkedTops = 0
	for side = -1, 1, 2 do
		local list = lips[side]
		table.sort(list, function(a, b)
			return a[1] < b[1]
		end)
		assert(list[1][1] <= GreenHill.S0 and list[#list][2] >= GreenHill.S1, "lips cover the length on side " .. side)
		for index = 2, #list do
			assert(list[index][1] <= list[index - 1][2] + 0.05, "lips continuous on side " .. side)
		end
		for s = GreenHill.S0, GreenHill.S1, 3 do
			local floor = ground(s, side)
			local lipTop = nil
			for _, lip in arena.Banks:GetChildren() do
				local top = topAt(lip, s, side * 37)
				if top then
					lipTop = math.max(lipTop or -math.huge, top)
				end
			end
			assert(lipTop and lipTop <= floor + 1e-3 and lipTop >= floor - 0.65,
				string.format("side %d s %d: the lip (%s) stays at the floor (%.3f), never above it", side, s, tostring(lipTop), floor))
			local verge = vergeTopAt(arena, s, side * 50)
			assert(verge and math.abs(verge - (floor + GreenHill.VergeLift)) <= 0.25,
				string.format("side %d s %d: the verge (%s) is %.1f over the floor (%.3f)", side, s, tostring(verge), GreenHill.VergeLift, floor))
			checkedTops += 1
		end
	end
	pass(("barriers: walls on x +-38.1 from %.1f to %.1f (>= %d over the highest floor %.2f; jump %.1f), end caps, fences (%d posts, 2 rails), bank lips at floor level and verges %.1f over it along the whole length (%d spots)"):format(
		GreenHill.WallBottom, report.wallTop, GreenHill.WallClearance, maxFloor, DEFAULT_JUMP, #posts[-1] + #posts[1], GreenHill.VergeLift, checkedTops))
end

----------------------------------------------------------------------
-- 4. Nothing decorative in the racers' way
----------------------------------------------------------------------
do
	local checked = 0
	for _, part in added do
		if not inside(part, "Barriers", arena) then
			local lo, hi = GreenHill.AABB({ part })
			assert(report.clearOfTrack(lo, hi), part:GetFullName() .. " stands in the track (x " .. (lo.X - ORIGIN.X) .. ".." .. (hi.X - ORIGIN.X)
				.. ", y " .. (lo.Y - ORIGIN.Y) .. ".." .. (hi.Y - ORIGIN.Y) .. ", s " .. localS(hi) .. ".." .. localS(lo) .. ")")
			checked += 1
		end
	end
	-- The rule itself: a box over the track at jump height fails, flat and overhead ones pass.
	local function box(x0, x1, y0, y1, s0, s1)
		return GreenHill.World(s1, x0, y0), GreenHill.World(s0, x1, y1)
	end
	local function clear(...)
		local lo, hi = box(...)
		return report.clearOfTrack(Vector3.new(lo.X, lo.Y, math.min(lo.Z, hi.Z)), Vector3.new(hi.X, hi.Y, math.max(lo.Z, hi.Z)))
	end
	assert(not clear(-2, 2, 0, 3, 500, 504), "a bush on the track fails")
	assert(not clear(30, 40, 5, 9, 500, 504), "a branch at head height over the lane fails")
	assert(clear(-2, 2, 0, 0.4, 500, 504), "a flat marking passes")
	assert(clear(-40, 40, 14, 16, 500, 504), "an overhead beam passes")
	assert(clear(38.2, 45, 0, 20, 500, 504), "outside x 38.1 passes")
	assert(clear(-10, 10, 0, 30, -90, -70), "behind the staging box (outside the playable s range) passes")
	pass(("the track is clear: %d added parts are flat (<= %.1f), overhead (>= %d) or outside |x| 38.1"):format(checked, GreenHill.FlatDecor, GreenHill.Overhead))
end

----------------------------------------------------------------------
-- 5. The ground profile
----------------------------------------------------------------------
do
	local profile = RaceTrack.BuildProfile(GreenHill.ProfileSampler(arena))
	local issues = RaceTrack.CheckProfile(profile)
	assert(#issues == 0, "the floor keeps the contract: " .. table.concat(issues, "; "))
	assert(not profile.Flat, "the hills are there")
	local maxH, maxGrade = 0, 0
	for _, column in profile.Heights do
		for index, h in column do
			maxH = math.max(maxH, math.abs(h))
			if column[index + 1] then
				maxGrade = math.max(maxGrade, math.abs(column[index + 1] - h) / profile.Step)
			end
		end
	end
	assert(maxH <= GROUND.MaxHeight and maxH <= 6.05, "heights within the limits (" .. maxH .. ")")
	assert(math.deg(math.atan(maxGrade)) <= GROUND.MaxSlopeDegrees, "slopes within the limit")
	for column = 2, #profile.Columns do
		for index, h in profile.Heights[column] do
			assert(math.abs(h - profile.Heights[1][index]) < 0.02, "no cross tilt")
		end
	end
	-- What RaceServer's ray sees: every visible collidable part of the arena, not only TrackFloor
	-- (the bank caps, the walls): the same profile.
	local everything = {}
	for _, part in baseParts(arena) do
		if part.CanCollide and part.Transparency < 1 then
			table.insert(everything, part)
		end
	end
	local boxes = GreenHill.BoxesOf(everything)
	local all = RaceTrack.BuildProfile(function(s, x)
		return GreenHill.GroundAt(boxes, math.clamp(s, RaceTrack.ProfileS0 + 1, RaceTrack.ProfileS1 - 1), x, 40)
	end)
	assert(RaceTrack.EncodeProfile(all) == RaceTrack.EncodeProfile(profile), "the decor changes nothing under the rays")
	local encoded = RaceTrack.EncodeProfile(profile)
	local decoded = RaceTrack.DecodeProfile(encoded)
	assert(decoded and RaceTrack.EncodeProfile(decoded) == encoded, "Encode/Decode round trip")
	-- Astra's own heights (map_data.json), node by node.
	local mapData = "design/race/Astra_Recta/map_data.json"
	local matched = 0
	if fs.isFile(mapData) then
		for _, sample in serde.decode("json", fs.readFile(mapData)).samples do
			if sample.s >= -60 and sample.s <= TRACK.Length + TRACK.RunOut - 4 then
				local h = RaceTrack.Ground(sample.s, 0, profile)
				assert(math.abs(h - sample.h) <= 0.06, string.format("s %d: %.3f vs Astra's %.3f", sample.s, h, sample.h))
				matched += 1
			end
		end
	end
	RaceTrack.SetProfile(decoded)
	pass(("ground profile: %d samples x %d columns, max %.2f studs, max slope %.2f deg, flat start/finish, decor-proof, %d of Astra's samples matched"):format(
		profile.Count, #profile.Columns, maxH, math.deg(math.atan(maxGrade)), matched))
end

----------------------------------------------------------------------
-- 6. Speed pads and spike tiles
----------------------------------------------------------------------
do
	local pads = RaceTrack.PadsFromParts(arena.SpeedPads:GetDescendants())
	assert(#pads == 5 and #pads <= PADS.MaxPads, "5 speed pads")
	for _, pad in pads do
		assert(pad.boost <= PADS.MaxBoost and pad.seconds <= PADS.MaxSeconds and pad.boost > 1, "pad boost/seconds within the limits")
		local s, x = (pad.s0 + pad.s1) * 0.5, (pad.x0 + pad.x1) * 0.5
		assert(math.abs(pad.top - RaceTrack.Ground(s, x)) <= 0.5, "pad flat on the ground at s " .. s)
		for _, row in RaceTrack.SpikeRows() do
			assert(math.abs(row.s - s) >= 20, "pad at s " .. s .. " >= 20 studs from the spike row at " .. row.s)
		end
	end
	for _, part in arena.SpeedPads:GetDescendants() do
		if part:IsA("BasePart") then
			assert(not part:HasTag("RaceDecorLowPower") and not part.CanCollide, "pads: not low-power, not colliding")
		end
	end
	local art = 0
	for _, part in added do
		if string.sub(part.Name, 1, 3) == "Pad" then
			local s = localS(part.CFrame.Position)
			local near = false
			for _, pad in pads do
				near = near or (s >= pad.s0 - 1 and s <= pad.s1 + 1)
			end
			assert(near, "pad art on a pad")
			art += 1
		end
	end
	assert(art == 5 * 7, "7 pieces of art per pad")

	local expected = {}
	for _, tile in RaceTrack.SpikeTiles() do
		expected[string.format("SpikeTile_%d_%d_%d", tile.field, tile.row, tile.lane)] = tile
	end
	local tiles = 0
	for _, part in arena.Spikes:GetChildren() do
		local tile = expected[part.Name]
		assert(tile, part.Name .. " is a tile Update4Config knows")
		local s, x = localS(part.CFrame.Position), part.CFrame.Position.X - ORIGIN.X
		assert(math.abs(s - tile.s) < 0.01 and math.abs(x - tile.x) < 0.01, part.Name .. " where RaceTrack puts it")
		assert(math.abs(part.Size.X - TRACK.SpikeTile) < 0.01 and math.abs(part.Size.Z - TRACK.SpikeTile) < 0.01, part.Name .. " 7 x 7")
		local bottom = part.CFrame.Position.Y - part.Size.Y * 0.5 - ORIGIN.Y
		assert(math.abs(bottom - RaceTrack.Ground(s, x)) <= 0.05, part.Name .. " on the ground")
		assert(RaceTrack.SpikeAt(s, x, RaceTrack.Ground(s, x) + RaceTrack.RootHeight) == tile, part.Name .. " hits a racer standing on it")
		tiles += 1
	end
	assert(tiles == #RaceTrack.SpikeTiles() and tiles == 40, "40 tiles (10 rows of 4)")
	local stars = 0
	for _, part in added do
		if part.Name == "TileStar" then
			assert(part.Parent and part.Parent.Parent == arena.Spikes, "a star is its tile's child (Persistent with it)")
			stars += 1
		end
	end
	assert(stars == 2 * tiles, "a two-plate star on every tile")
	pass(("speed pads (5, flat, >= 20 from spike rows, boost <= 1.5, art on each) and %d spike tiles line up with Update4Config / RaceTrack"):format(tiles))
end

----------------------------------------------------------------------
-- 7. Budgets and water
----------------------------------------------------------------------
do
	local total = #baseParts(arena)
	assert(total == report.totalParts and arena:GetAttribute("RaceArenaParts") == total, "part count attribute")
	assert(report.addedParts <= GreenHill.DecorBudget, "added parts within the budget (" .. report.addedParts .. ")")
	assert(total <= 1000 and total <= GreenHill.TotalBudget, "the part-built arena stays under 1000 parts (" .. total .. ")")
	local lowPower = 0
	for _, part in added do
		if part:HasTag("RaceDecorLowPower") then
			lowPower += 1
		end
	end
	for _, key in { "Top", "Bottom", "SeabedBottom", "HalfX", "SMin", "SMax", "StripStuds" } do
		assert(WATER[key] % 4 == 0, "Water." .. key .. " on the 4-stud voxel grid")
	end
	for _, axis in { ORIGIN.X, ORIGIN.Y, ORIGIN.Z } do
		assert(axis % 4 == 0, "Origin on the voxel grid")
	end
	assert(WATER.SeabedBottom < WATER.Bottom and WATER.Bottom < WATER.Top, "seabed, then water")
	assert(WATER.SMin <= GreenHill.DecorS0 + 20 and WATER.SMax >= GreenHill.S1 + 300, "the water runs past both ends")
	-- Nothing of the race under the water: the floor's lowest bottom and the pads/tiles.
	local floorBottom = math.huge
	for _, part in arena.TrackFloor:GetChildren() do
		local lo = GreenHill.AABB({ part })
		floorBottom = math.min(floorBottom, lo.Y - ORIGIN.Y)
	end
	assert(floorBottom >= WATER.Top + 5, "the floor's bottom (" .. floorBottom .. ") is well above the water's top")
	-- The decor stands inside the water region; the ground pieces stand in the water (down to the seabed).
	local grounded, standing = 0, 0
	for _, part in added do
		local lo, hi = GreenHill.AABB({ part })
		local s0, s1 = ORIGIN.Z - hi.Z, ORIGIN.Z - lo.Z
		assert(lo.X - ORIGIN.X >= -WATER.HalfX and hi.X - ORIGIN.X <= WATER.HalfX and s0 >= WATER.SMin and s1 <= WATER.SMax,
			part:GetFullName() .. " inside the water region")
		local name = part.Name
		if name == "Terrace" or name == "Island" or string.sub(name, 1, 9) == "BankCliff" or name == "StartCliff" or name == "EndCliff" then
			assert(lo.Y - ORIGIN.Y <= WATER.Bottom, name .. " stands in the water down to the seabed")
			grounded += 1
		end
		if name == "Island" then
			assert(hi.Y - ORIGIN.Y > WATER.Top, "islands rise over the water")
		end
		if name == "IslandBeach" then
			standing += 1
			assert(hi.Y - ORIGIN.Y > WATER.Top and lo.Y - ORIGIN.Y < WATER.Top, "beaches at the waterline")
		end
	end
	assert(grounded >= 40 and standing >= 8, "terraces, islands, cliffs and bank bodies (" .. grounded .. ")")
	pass(("budget: %d parts = 384 gameplay + %d added (<= %d; %d low-power); water %d..%d, seabed to %d, x +-%d, s %d..%d, all on the voxel grid, %d ground pieces standing in it"):format(
		total, report.addedParts, GreenHill.DecorBudget, lowPower, WATER.Bottom, WATER.Top, WATER.SeabedBottom, WATER.HalfX, WATER.SMin, WATER.SMax, grounded))
end

----------------------------------------------------------------------
-- 8. A stand-in kit
----------------------------------------------------------------------
local function standInKit()
	local folder = Instance.new("Folder")
	folder.Name = "GreenHillKit"
	local function part(parent, name, size, position)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = CFrame.new(position)
		p.CanCollide = true
		p.CastShadow = true
		p.Parent = parent
		return p
	end
	-- A palm (trunk + canopy), anywhere in the file: its bottom centre is (100, 40, 100).
	local palm = Instance.new("Model")
	palm.Name = "Kit_Palm"
	part(palm, "Trunk", Vector3.new(2, 20, 2), Vector3.new(100, 50, 100))
	part(palm, "Canopy", Vector3.new(12, 3, 12), Vector3.new(100, 61, 100))
	palm.Parent = folder
	part(folder, "Kit_Mesa", Vector3.new(40, 30, 40), Vector3.new(-50, 15, 0))
	part(folder, "Kit_Sunflower", Vector3.new(2, 6, 2), Vector3.new(0, 3, 300))
	part(folder, "Kit_Rock", Vector3.new(4, 3, 4), Vector3.new(10, 1.5, 10))
	-- A fence section authored along X (24 long): the edge tiles turn it down the track.
	part(folder, "Kit_FenceSection", Vector3.new(24, 3, 0.6), Vector3.new(0, 1.5, 50))
	return folder
end
local STAND_IN_LAYOUT = {
	placements = {
		{ kit = "Kit_Palm", pos = { -60, -6.4, -300 }, rotY = 30, scale = 1.2, lowPower = false },
		{ kit = "Mesa", pos = { 150, -14, -800 }, rotY = 0, scale = 2, lowPower = false },
		{ kit = "Kit_Mesa", pos = { -300, 2, -1500 }, rotY = 45, scale = 1, lowPower = false }, -- over the water: warned
		{ kit = "Kit_Sunflower", pos = { 44, 0, -500 }, rotY = 90, scale = 1, lowPower = true },
		{ kit = "Kit_Rock", pos = { 0, 0, -1000 }, rotY = 0, scale = 3, lowPower = true }, -- on the track: skipped
		{ kit = "Kit_Loop", pos = { 200, 0, -900 }, rotY = 0, scale = 1 }, -- not in the kit: warned
	},
}
do
	local kit = standInKit()
	local kitArena, kitReport = GreenHill.Build({ kit = kit, layout = STAND_IN_LAYOUT,
		manifest = { textures = { dirt = "rbxassetid://123456789" } } })
	print("  " .. GreenHill.Describe(kitReport))
	assert(kitReport.kit and kitReport.fence == "kit (edge tiles)", "kit mode, fences tiled on the edges from Kit_FenceSection")
	assert(kitReport.kitPlacements == 4, "4 layout pieces placed (" .. kitReport.kitPlacements .. ")")
	assert(#kitReport.skipped == 1 and #kitReport.warnings == 2, "the rock on the track skipped; Kit_Loop and the floating mesa warned")
	assert(string.find(table.concat(kitReport.warnings, " | "), "Kit_Mesa at (-300, 2, -1500) floats", 1, true), "a mesa over the water is reported")
	assert(kitReport.groups.Terraces == nil and kitReport.groups.Palms == nil and kitReport.groups.Islands == nil and kitReport.groups.Plants == nil,
		"no part-built scenery with a kit")
	assert(kitReport.groups.Barriers == 22 and kitReport.groups.Pads == 35 and kitReport.groups.Spikes == 2 * #RaceTrack.SpikeTiles(), "barriers and the race art stay")
	local placed = {}
	for _, d in kitArena.GreenHillDecor:GetDescendants() do
		if string.sub(d.Name, 1, 4) == "Kit_" then
			placed[d.Name] = placed[d.Name] or {}
			table.insert(placed[d.Name], d)
		end
	end
	-- The palm: bottom centre at Origin + pos, yawed 30, scaled 1.2, with wind.
	local palm = placed.Kit_Palm[1]
	local anchor = Vector3.new(ORIGIN.X - 60, ORIGIN.Y - 6.4, ORIGIN.Z - 300)
	local trunk, canopy = palm.Trunk, palm.Canopy
	assert((trunk.CFrame.Position - (anchor + Vector3.new(0, 12, 0))).Magnitude < 1e-3, "trunk centre = anchor + 10 * 1.2 up")
	assert((canopy.CFrame.Position - (anchor + Vector3.new(0, 25.2, 0))).Magnitude < 1e-3, "canopy centre = anchor + 21 * 1.2 up")
	assert((trunk.Size - Vector3.new(2.4, 24, 2.4)).Magnitude < 1e-4, "scaled 1.2")
	local _, yaw = canopy.CFrame:ToOrientation()
	assert(math.abs(math.deg(yaw) - 30) < 1e-3, "yawed 30")
	local lo = GreenHill.AABB({ trunk, canopy })
	assert(math.abs(lo.Y - anchor.Y) < 1e-3, "the palm's bottom sits on pos.y")
	for _, piece in { trunk, canopy } do
		assert(not piece.CanCollide and not piece.CanTouch and not piece.CanQuery and piece.Anchored, "kit pieces never collide")
		assert(piece:HasTag("RacePalmWind") and piece:GetAttribute("WindBase") == anchor, "palm wind base")
		assert(piece:GetAttribute("RaceArenaPart") == true, "RaceArenaPart")
	end
	assert(canopy:GetAttribute("WindKind") == "canopy" and trunk:GetAttribute("WindKind") == "trunk", "canopy / trunk kinds")
	assert(trunk:GetAttribute("WindTree") == canopy:GetAttribute("WindTree"), "one tree")
	local mesa = placed.Kit_Mesa[1]
	assert(math.abs(mesa.Size.Y - 60) < 1e-4 and mesa.CastShadow and not mesa:HasTag("RaceDecorLowPower"), "the mesa: x2, shadows, not low power")
	assert(math.abs(mesa.CFrame.Position.Y - (ORIGIN.Y - 14 + 30)) < 1e-3, "the mesa stands on pos.y")
	local flower = placed.Kit_Sunflower[1]
	assert(flower:HasTag("RaceDecorLowPower") and not flower.CastShadow, "the sunflower: low power, no shadow")
	assert(placed.Kit_Rock == nil, "the rock on the track is not placed")
	-- Edge fences from the kit: along both edges, turned down the track, covering the length.
	local cover = { [-1] = {}, [1] = {} }
	for _, section in placed.Kit_FenceSection do
		local p = section.CFrame.Position
		local x = p.X - ORIGIN.X
		assert(math.abs(math.abs(x) - GreenHill.FenceX) < 1e-3, "fence tile on the fence line")
		assert(section:HasTag("RaceDecorLowPower"), "edge fence tiles are low power (like the layout's)")
		local slo, shi = GreenHill.AABB({ section })
		assert(shi.Z - slo.Z > 23 and shi.X - slo.X < 1, "fence tile turned down the track")
		table.insert(cover[if x < 0 then -1 else 1], { ORIGIN.Z - shi.Z, ORIGIN.Z - slo.Z })
	end
	for side, list in cover do
		table.sort(list, function(a, b)
			return a[1] < b[1]
		end)
		assert(list[1][1] <= GreenHill.S0 + 0.1 and list[#list][2] >= GreenHill.S1 - 0.1, "kit fence covers side " .. side)
		for index = 2, #list do
			assert(list[index][1] <= list[index - 1][2] + 0.1, "kit fence continuous")
		end
	end
	-- The kit's dirt texture on every floor part.
	for _, floor in kitArena.TrackFloor:GetChildren() do
		local dirt = floor:FindFirstChild("KitDirtTexture")
		assert(dirt and dirt.Texture == "rbxassetid://123456789", "kit dirt texture on " .. floor.Name)
	end
	assert(#GreenHill.Verify(kitArena) == 0, "Verify with the kit")
	assert(kitReport.totalParts <= GreenHill.TotalBudget, "kit arena within the budget")
	-- A kit made of local content is refused.
	local bad = standInKit()
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshId = "rbxasset://somewhere/palm.mesh"
	mesh.Parent = bad.Kit_Mesa
	local ok, err = pcall(GreenHill.Build, { kit = bad, layout = STAND_IN_LAYOUT })
	assert(not ok and string.find(tostring(err), "local content", 1, true), "a local-content kit is refused")
	local unsent = standInKit()
	local temp = Instance.new("SpecialMesh")
	temp.MeshId = "rbxtemp://42"
	temp.Parent = unsent.Kit_Rock
	local okTemp, errTemp = pcall(GreenHill.Build, { kit = unsent, layout = STAND_IN_LAYOUT })
	assert(not okTemp and string.find(tostring(errTemp), "rbxtemp://42", 1, true), "an import never uploaded (rbxtemp://) is refused")
	-- The layout forms and the dirt texture sources.
	assert(#GreenHill.Placements(STAND_IN_LAYOUT.placements) == 6 and #GreenHill.Placements({ { kit = "x" } }) == 0, "layout: a bare list too, rows need pos")
	assert(GreenHill.KitDirtTexture(nil, { dirtTexture = "rbxasset://x.png" }) == nil, "a local dirt texture is ignored")
	assert(GreenHill.KitDirtTexture(nil, { DirtTexture = "rbxassetid://42" }) == "rbxassetid://42", "manifest DirtTexture")
	pass(("stand-in kit: %d parts total with the kit (%d kit parts, %d placements), bottom-centre anchors, yaw, scale, wind, low power, shadows, edge fences, dirt texture; skips and refusals"):format(
		kitReport.totalParts, kitReport.kitParts, kitReport.kitPlacements))
end

----------------------------------------------------------------------
-- 8b. The kit artist's real layout.json + kit_manifest.json on a stand-in kit made from the
-- manifest (the owner's GreenHillKit.rbxm is not saved yet): the formula, the heights against
-- the verge and the water, the pads, the fences, the budgets.
----------------------------------------------------------------------
local LAYOUT_FILE, MANIFEST_FILE = GreenHill.LayoutFile, GreenHill.ManifestFile
if fs.isFile(LAYOUT_FILE) and fs.isFile(MANIFEST_FILE) then
	local layout = serde.decode("json", fs.readFile(LAYOUT_FILE))
	local manifest = serde.decode("json", fs.readFile(MANIFEST_FILE))
	local kit = Instance.new("Folder")
	kit.Name = "GreenHillKit"
	for index, entry in manifest.pieces do
		-- As Studio would import it: a MeshPart of the manifest's size, anywhere (pivots untrusted).
		local piece = Instance.new("MeshPart")
		piece.Name = entry.name
		piece.Size = Vector3.new(entry.size[1], entry.size[2], entry.size[3])
		piece.CFrame = CFrame.new(3000 + index * 120, 40, -500)
		piece.CanCollide = true
		piece.Parent = kit
	end
	local t0 = os.clock()
	local kitArena, kitReport = GreenHill.Build({ kit = kit, layout = layout, manifest = manifest })
	print(string.format("  real layout (%.1f s): %s", os.clock() - t0, GreenHill.Describe(kitReport)))
	for _, line in kitReport.warnings do
		print("    warning: " .. line)
	end
	for _, line in kitReport.skipped do
		print("    skipped: " .. line)
	end
	local rows = GreenHill.Placements(layout)
	assert(kitReport.kitPlacements == #rows and #kitReport.skipped == 0, "every placement placed, none inside the track")
	assert(#kitReport.warnings == 0, "no ground piece floats over the water, nothing low stands past it")
	assert(kitReport.fence == "kit (layout)" and kitReport.padsResized == 5, "the layout's fences; 5 SpeedPads fitted to the kit's pad art")
	assert(#GreenHill.Verify(kitArena) == 0, "Verify with the real layout: " .. table.concat(GreenHill.Verify(kitArena), "; "))
	-- The formula, placement by placement (the chunks keep the layout's order per chunk).
	local specs = {}
	for _, entry in manifest.pieces do
		specs[entry.name] = entry
	end
	local byName = {}
	for _, d in kitArena.GreenHillDecor:GetDescendants() do
		if d:IsA("BasePart") and string.sub(d.Name, 1, 4) == "Kit_" then
			byName[d.Name] = byName[d.Name] or {}
			table.insert(byName[d.Name], d)
		end
	end
	local checked, lowPower = 0, 0
	for _, row in rows do
		local name = "Kit_" .. row.kit
		local spec = specs[name]
		local expected = CFrame.new(ORIGIN + Vector3.new(row.pos[1], row.pos[2], row.pos[3])) * CFrame.Angles(0, math.rad(row.rotY), 0)
			* CFrame.new(Vector3.new(spec.bboxCenterOffset[1], spec.bboxCenterOffset[2], spec.bboxCenterOffset[3]) * row.scale)
		local found = nil
		for _, part in byName[name] do
			if (part.CFrame.Position - expected.Position).Magnitude < 1e-2 then
				found = part
				break
			end
		end
		assert(found, name .. " at the formula's CFrame")
		local size = Vector3.new(spec.size[1], spec.size[2], spec.size[3]) * row.scale
		assert((found.Size - size).Magnitude < 1e-3, name .. ": Size = size * scale")
		assert(math.abs(found.CFrame.LookVector:Dot(expected.LookVector) - 1) < 1e-4, name .. ": yaw rotY")
		assert(found:HasTag("RaceDecorLowPower") == (row.lowPower == true), name .. ": RaceDecorLowPower when lowPower")
		assert(not found.CanCollide and not found.CanQuery and not found.CanTouch and found.Anchored, name .. ": inert")
		if spec.castShadow == false then
			assert(not found.CastShadow, name .. ": no shadow (manifest)")
		end
		if string.find(name, "Palm", 1, true) then
			assert(found:HasTag("RacePalmWind") and found:GetAttribute("WindKind") == "trunk"
				and (found:GetAttribute("WindBase") - (ORIGIN + Vector3.new(row.pos[1], row.pos[2], row.pos[3]))).Magnitude < 1e-2,
				name .. ": sways as one trunk about its base")
		end
		if row.lowPower == true then
			lowPower += 1
		end
		checked += 1
	end
	-- The verge plants stand on the verge (VergeLift over the floor), within 0.25.
	local onVerge = 0
	for _, row in rows do
		local s, x = -row.pos[3], row.pos[1]
		if s > GreenHill.S0 + 2 and s < GreenHill.S1 - 2 and math.abs(x) >= 42 and math.abs(x) <= GreenHill.BankOuter - 1 then
			local floor = RaceTrack.Ground(s, 0)
			if math.abs(row.pos[2] - (floor + 0.3)) < 0.05 then
				local verge = vergeTopAt(kitArena, s, x)
				assert(verge and math.abs(verge - row.pos[2]) <= 0.25, string.format("%s at s %.1f x %.1f: base %.2f, verge %s", row.kit, s, x, row.pos[2], tostring(verge)))
				onVerge += 1
			end
		end
	end
	assert(onVerge >= 400, "the verge carries the kit's verge plants (" .. onVerge .. ")")
	-- The pads now boost where the kit's pad art is (18 x 16), still clear of the spike rows.
	local pads = RaceTrack.PadsFromParts(kitArena.SpeedPads:GetDescendants())
	assert(#pads == 5, "5 pads")
	for _, pad in pads do
		assert(math.abs((pad.x1 - pad.x0) - 18) < 0.01 and math.abs((pad.s1 - pad.s0) - 16) < 0.01, "pad footprint 18 x 16")
		for _, row in RaceTrack.SpikeRows() do
			assert(math.abs(row.s - (pad.s0 + pad.s1) * 0.5) >= 20, "pads clear of the spike rows")
		end
	end
	-- The layout's fences on both edges, outside the corridor line, end to end.
	local cover = { [-1] = {}, [1] = {} }
	for _, part in byName.Kit_FenceSection do
		local lo, hi = GreenHill.AABB({ part })
		assert(math.min(math.abs(lo.X - ORIGIN.X), math.abs(hi.X - ORIGIN.X)) >= GreenHill.DecorClearX, "fences outside x 38.1")
		table.insert(cover[if lo.X < ORIGIN.X then -1 else 1], { ORIGIN.Z - hi.Z, ORIGIN.Z - lo.Z })
	end
	for side, list in cover do
		table.sort(list, function(a, b)
			return a[1] < b[1]
		end)
		assert(list[1][1] <= -50 and list[#list][2] >= GreenHill.S1 - 1, "fences from the staging box to the end, side " .. side)
		for index = 2, #list do
			assert(list[index][1] <= list[index - 1][2] + 0.1, "fence continuous, side " .. side)
		end
	end
	local shown = kitReport.totalParts - kitReport.lowPowerParts
	assert(kitReport.totalParts <= GreenHill.KitTotalBudget and shown <= GreenHill.KitShownBudget, "kit budgets")
	pass(("real kit layout: %d placements by the manifest's formula (%d low power), %d verge plants on the verge, pads 18 x 16, fences end to end; %d parts, %d drawn on phones"):format(
		checked, lowPower, onVerge, kitReport.totalParts, shown))
else
	print("  (no " .. LAYOUT_FILE .. " / " .. MANIFEST_FILE .. ": the real-layout check is skipped)")
end

----------------------------------------------------------------------
-- 8c. (2026-09-26) The owner's own GreenHillKit.rbxm, as Studio's Import 3D saved it: the import
-- turned every mesh 180 degrees about Y (its PivotOffsets say so); placed, each piece's own
-- origin (part.CFrame * PivotOffset, the base centre the artist placed) stands on its layout
-- spot and the pad art's chevrons point down the track (-Z) like the manifest says.
----------------------------------------------------------------------
if fs.isFile(GreenHill.KitFile) and fs.isFile(LAYOUT_FILE) then
	local kit, layout, manifest = GreenHill.LoadKit()
	local kitArena, kitReport = GreenHill.Build({ kit = kit, layout = layout, manifest = manifest })
	print(string.format("  owner's kit: import turn %g degrees; %s", kitReport.kitImportYawDegrees or 0, GreenHill.Describe(kitReport)))
	assert(#kitReport.warnings == 0 and #kitReport.skipped == 0, "the owner's kit places cleanly: " .. table.concat(kitReport.warnings, "; "))
	local pivots = {}
	for _, piece in kit:GetChildren() do
		pivots[piece.Name] = piece.PivotOffset.Position
	end
	local rows = GreenHill.Placements(layout)
	local byName = {}
	for _, d in kitArena.GreenHillDecor:GetDescendants() do
		if d:IsA("BasePart") and string.sub(d.Name, 1, 4) == "Kit_" then
			byName[d.Name] = byName[d.Name] or {}
			table.insert(byName[d.Name], d)
		end
	end
	local checked, worst = 0, 0
	local turn = CFrame.Angles(0, math.rad(kitReport.kitImportYawDegrees or 0), 0)
	for _, row in rows do
		local name = "Kit_" .. string.gsub(row.kit, "^Kit_", "")
		local anchor = ORIGIN + Vector3.new(row.pos[1], row.pos[2], row.pos[3])
		local best, found = math.huge, nil
		for _, part in byName[name] do
			local d = ((part.CFrame * (pivots[name] * row.scale)) - anchor).Magnitude
			if d < best then
				best, found = d, part
			end
		end
		assert(found and best < 0.05, name .. " at " .. tostring(anchor) .. ": its own origin stands on the layout spot (off by " .. best .. ")")
		worst = math.max(worst, best)
		-- The authored -Z of the mesh, in world space, is the layout's yaw applied to -Z.
		local forward = (found.CFrame * turn).LookVector
		local want = CFrame.Angles(0, math.rad(row.rotY), 0).LookVector
		assert(forward:Dot(want) > 0.999, name .. ": authored forward turned by rotY only")
		if name == "Kit_SpeedPad" then
			assert(forward:Dot(Vector3.new(0, 0, -1)) > 0.999, "the pad art's chevrons point down the track (-Z)")
		end
		checked += 1
	end
	pass(string.format("the owner's kit (import turn %g degrees undone): %d pieces on their layout spots (worst %.3f studs), pad chevrons toward -Z",
		kitReport.kitImportYawDegrees or 0, checked, worst))
end

----------------------------------------------------------------------
-- 9a. Gameplay/RaceArenaWater in a fake place
----------------------------------------------------------------------
do
	local WATER_SCRIPT = "src/common/ServerScriptService/Gameplay/RaceArenaWater.server.luau"
	local code = read(WATER_SCRIPT)
	local function fakePlace(options)
		local place = { attributes = {}, listeners = {}, calls = {}, warnings = {}, prints = 0 }
		local terrain = {
			ClassName = "Terrain",
			FillBlock = function(_, cf, size, material)
				if options.failFill then
					error("Terrain is locked")
				end
				table.insert(place.calls, { centre = cf.Position, size = size, material = material })
			end,
		}
		local arena = { Name = "RaceArena" }
		local workspace = {
			GetAttribute = function(_, name)
				return place.attributes[name]
			end,
			SetAttribute = function(_, name, value)
				place.attributes[name] = value
			end,
			GetAttributeChangedSignal = function(_, name)
				return { Connect = function(_, fn)
					place.listeners[name] = fn
				end }
			end,
			FindFirstChild = function(_, name)
				return if name == "RaceArena" and not options.noArena then arena else nil
			end,
			FindFirstChildOfClass = function(_, className)
				return if className == "Terrain" and not options.noTerrain then terrain else nil
			end,
			ChildAdded = { Connect = function(_, fn)
				place.childAdded = fn
				return { Disconnect = function() end }
			end },
		}
		local configModule = {}
		local shared = { WaitForChild = function(_, name)
			assert(name == "Update4Config")
			return configModule
		end }
		local replicated = { WaitForChild = function(_, name)
			assert(name == "Shared")
			return shared
		end }
		place.game = { GetService = function(_, name)
			return if name == "Workspace" then workspace elseif name == "ReplicatedStorage" then replicated else error(name)
		end }
		place.run = function()
			local env = {
				game = place.game, Vector3 = Vector3, CFrame = CFrame, Enum = Enum,
				task = { spawn = function(fn, ...) fn(...) end, wait = function() end },
				require = function(module)
					assert(module == configModule)
					return U4
				end,
				warn = function(message)
					table.insert(place.warnings, message)
				end,
				print = function()
					place.prints += 1
				end,
			}
			setmetatable(env, { __index = _G })
			luau.load(code, { debugName = "RaceArenaWater", environment = env })()
		end
		place.workspace = workspace
		return place
	end

	local place = fakePlace({})
	place.run()
	local strips = math.ceil((WATER.SMax - WATER.SMin) / WATER.StripStuds)
	assert(#place.calls == 2 * strips, "water and seabed, strip by strip (" .. #place.calls .. ")")
	local covered = { Water = 0, Sand = 0 }
	for _, call in place.calls do
		local name = tostring(call.material):match("Material%.(%a+)")
		assert(name == "Water" or name == "Sand", "water or sand")
		local y0 = call.centre.Y - call.size.Y * 0.5 - ORIGIN.Y
		local y1 = call.centre.Y + call.size.Y * 0.5 - ORIGIN.Y
		if name == "Water" then
			assert(math.abs(y0 - WATER.Bottom) < 1e-3 and math.abs(y1 - WATER.Top) < 1e-3, "water from Bottom to Top")
		else
			assert(math.abs(y0 - WATER.SeabedBottom) < 1e-3 and math.abs(y1 - WATER.Bottom) < 1e-3, "sand under it")
		end
		assert(math.abs(call.size.X - 2 * WATER.HalfX) < 1e-3 and math.abs(call.centre.X - ORIGIN.X) < 1e-3, "x +-HalfX around the track")
		assert(call.size.Z <= WATER.StripStuds, "strips")
		covered[name] += call.size.Z
	end
	assert(covered.Water == WATER.SMax - WATER.SMin and covered.Sand == WATER.SMax - WATER.SMin, "s from SMin to SMax")
	assert(place.attributes.RaceWaterFilled == true and #place.warnings == 0, "filled once, quietly")
	place.run() -- a second copy of the script
	assert(#place.calls == 2 * strips, "never filled twice")
	place.attributes.U4Off_RaceWater = true
	place.listeners.U4Off_RaceWater()
	assert(#place.calls == 3 * strips and place.attributes.RaceWaterFilled == false, "the kill switch clears it (Air)")
	assert(tostring(place.calls[#place.calls].material):match("Air"), "with Air")
	place.attributes.U4Off_RaceWater = false
	place.listeners.U4Off_RaceWater()
	assert(#place.calls == 5 * strips and place.attributes.RaceWaterFilled == true, "and fills it back")

	local killed = fakePlace({})
	killed.attributes.U4Off_RaceWater = true
	killed.run()
	assert(#killed.calls == 0, "killed before the fill: nothing")
	local noTerrain = fakePlace({ noTerrain = true })
	noTerrain.run()
	assert(#noTerrain.warnings == 1 and noTerrain.attributes.RaceWaterFilled == nil, "no Terrain: one warning, no error")
	local failing = fakePlace({ failFill = true })
	failing.run()
	assert(#failing.warnings == 1 and failing.attributes.RaceWaterFilled == nil, "FillBlock failing: one warning, no error, not marked")
	local late = fakePlace({ noArena = true })
	late.run()
	assert(#late.calls == 0 and late.childAdded, "waits for the arena")
	pass(("RaceArenaWater: %d FillBlock strips (water %d..%d, sand to %d), once per server, kill switch clears and refills, no Terrain / failing FillBlock only warn"):format(
		2 * strips, WATER.Bottom, WATER.Top, WATER.SeabedBottom))
end

----------------------------------------------------------------------
-- 9b. Shared/RaceTropicalLook with fake Lighting / Terrain
----------------------------------------------------------------------
do
	local function object(className, props, children)
		local store = table.clone(props)
		local written = {}
		local o = { ClassName = className, written = written, children = children or {}, destroyed = false }
		function o.FindFirstChildOfClass(self, cls)
			for _, child in self.children do
				if child.ClassName == cls then
					return child
				end
			end
			return nil
		end
		function o.Destroy(self)
			self.destroyed = true
		end
		return setmetatable(o, {
			__index = function(_, key)
				local value = store[key]
				if value == nil then
					error("no property " .. tostring(key))
				end
				return value
			end,
			__newindex = function(_, key, value)
				assert(store[key] ~= nil, "no property " .. tostring(key))
				store[key] = value
				written[key] = (written[key] or 0) + 1
			end,
		})
	end
	local function scene(withClouds)
		local atmosphere = object("Atmosphere", { Density = 0.19, Offset = 0.16, Haze = 0.72, Glare = 0.08,
			Color = Color3.fromRGB(202, 226, 255), Decay = Color3.fromRGB(112, 122, 143) })
		local lighting = object("Lighting", { Brightness = 3, Ambient = Color3.fromRGB(132, 134, 142), OutdoorAmbient = Color3.fromRGB(170, 174, 181),
			ClockTime = 14.15 }, { atmosphere })
		local clouds = object("Clouds", { Cover = 0.7, Density = 0.3, Color = Color3.fromRGB(230, 230, 230) })
		local terrain = object("Terrain", { WaterColor = Color3.fromRGB(12, 84, 92), WaterTransparency = 0.3, WaterWaveSize = 0.15,
			WaterWaveSpeed = 10, WaterReflectance = 1 }, if withClouds then { clouds } else {})
		return atmosphere, lighting, terrain, clouds
	end
	local clock = 1000
	local attributes = {}
	local function make(tier, withClouds)
		local atmosphere, lighting, terrain, clouds = scene(withClouds)
		local grades = {}
		local look = RaceTropicalLook.new({
			lighting = lighting, terrain = terrain,
			now = function()
				return clock
			end,
			attribute = function(name)
				return attributes[name]
			end,
			newGrade = function()
				local grade = object("ColorCorrectionEffect", { Brightness = 0.5, Contrast = 0.5, Saturation = 0.5, TintColor = Color3.new(0, 0, 0) })
				table.insert(grades, grade)
				return grade
			end,
			tier = function()
				return tier
			end,
		})
		return look, atmosphere, lighting, terrain, clouds, grades
	end
	local T = RaceTropicalLook.Targets
	local function near(a, b)
		if typeof(a) == "Color3" then
			return math.abs(a.R - b.R) < 0.01 and math.abs(a.G - b.G) < 0.01 and math.abs(a.B - b.B) < 0.01
		end
		return math.abs(a - b) < 1e-4
	end

	local look, atmosphere, lighting, terrain, clouds, grades = make("High", true)
	assert(look:Step(0.25) == false and next(atmosphere.written) == nil and #grades == 0, "outside: nothing")
	look:SetInside(true)
	assert(look:Step(0.75) == true, "blending in")
	assert(near(atmosphere.Density, (0.19 + T.Atmosphere.Density) / 2), "half way at half the blend")
	assert(#grades == 1 and near(grades[1].Saturation, T.Grade.Saturation / 2), "its own grade, from neutral")
	look:Step(0.75)
	assert(look:Step(0.25) == false, "blend done")
	for property, target in T.Atmosphere do
		assert(near(atmosphere[property], target), "Atmosphere." .. property)
	end
	for property, target in T.Water do
		assert(near(terrain[property], target), "Terrain." .. property)
	end
	for property, target in T.Clouds do
		assert(near(clouds[property], target), "Clouds." .. property)
	end
	assert(next(lighting.written) == nil, "Lighting's own properties (blendLighting's) never written")
	local writes = atmosphere.written.Density
	look:Step(0.25)
	assert(atmosphere.written.Density == writes, "no writes while nothing moves")
	-- Someone else takes Haze; leaving puts the rest back and leaves Haze alone.
	atmosphere.Haze = 2.6
	look:SetInside(false)
	for _ = 1, 8 do
		look:Step(0.25)
	end
	assert(near(atmosphere.Density, 0.19) and near(atmosphere.Glare, 0.08) and near(atmosphere.Color, Color3.fromRGB(202, 226, 255)), "put back")
	assert(near(atmosphere.Haze, 2.6), "a property someone else changed is theirs")
	assert(near(terrain.WaterColor, Color3.fromRGB(12, 84, 92)) and near(clouds.Cover, 0.7), "water and clouds put back")
	assert(grades[1].destroyed, "the grade goes")

	-- Admin sky events win: no look while one runs and for the hold after it; Yield drops it now.
	local look2, atmosphere2 = make("Mid", false)
	look2:SetInside(true)
	for _ = 1, 8 do
		look2:Step(0.25)
	end
	assert(near(atmosphere2.Density, T.Atmosphere.Density), "on")
	attributes.AdminSnowUntil = clock + 60
	look2:Yield()
	assert(near(atmosphere2.Density, 0.19) and near(atmosphere2.Haze, 0.72), "Yield: all back at once")
	for _ = 1, 8 do
		look2:Step(0.25)
	end
	assert(near(atmosphere2.Density, 0.19), "stays off while the snow runs")
	clock += 70
	attributes.AdminSnowUntil = clock - 5
	look2:Step(0.25)
	assert(near(atmosphere2.Density, 0.19), "off during the hold after the event")
	clock += RaceTropicalLook.HoldAfterEventSeconds + 1
	for _ = 1, 8 do
		look2:Step(0.25)
	end
	assert(near(atmosphere2.Density, T.Atmosphere.Density), "back on after the hold")
	attributes.AdminSnowUntil = nil

	-- Low phones: clouds left alone.
	local look3, _, _, _, clouds3 = make("Low", true)
	look3:SetInside(true)
	for _ = 1, 8 do
		look3:Step(0.25)
	end
	assert(next(clouds3.written) == nil, "Low: clouds untouched")
	assert(RaceTropicalLook.AdminSkyActive(function(name)
		return if name == "AdminRainingTacosUntil" then clock + 1 else nil
	end, clock), "raining tacos is an admin sky")

	-- RaceArenaVisuals drives it from its arena-box loop (no per-frame connection).
	local visuals = read("src/common/StarterPlayer/StarterPlayerScripts/Gameplay/RaceArenaVisuals.client.luau")
	assert(string.find(visuals, "look:SetInside(inside)", 1, true) and string.find(visuals, "pcall(look.Step, look, now - last)", 1, true),
		"RaceArenaVisuals steps the look from the arena box")
	assert(string.find(visuals, "look:Yield()", 1, true) and string.find(visuals, "RaceTropicalLook.AdminSkyAttributes", 1, true), "yields to the admin sky events")
	assert(not string.find(visuals, "RunService", 1, true), "no per-frame connection")
	pass("RaceTropicalLook: blends Atmosphere / own grade / water (clouds only if there, not on Low), puts back only what is still its own, never blendLighting's properties, yields to snow/disco/tacos")
end

----------------------------------------------------------------------
-- 9c. RacePalmWind and RaceServer's StartGate (static)
----------------------------------------------------------------------
do
	local wind = read("src/common/StarterPlayer/StarterPlayerScripts/Gameplay/RacePalmWind.client.luau")
	assert(luau.compile(wind), "RacePalmWind compiles")
	for _, needle in {
		"Workspace:BulkMoveTo(moveParts, moveFrames, Enum.BulkMoveMode.FireCFrameChanged)",
		"tree = if tree ~= nil then tree else part,",
		"local MOBILE = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled",
		"local LIMIT = if MOBILE then 6 else 14",
		"connection = RunService.Heartbeat:Connect(step)",
		"connection:Disconnect()",
		'part:GetAttribute("WindKind") == "canopy"',
		"part.Transparency < HIDDEN and part.LocalTransparencyModifier < HIDDEN",
	} do
		assert(string.find(wind, needle, 1, true), "RacePalmWind: " .. needle)
	end
	local _, heartbeats = string.gsub(wind, "Heartbeat:Connect", "")
	assert(heartbeats == 1, "one Heartbeat, connected only while palms are streamed in")
	local server = read("src/common/ServerScriptService/Gameplay/RaceServer.server.luau")
	for _, needle in {
		"local function closeIdleStartGate()",
		'phase ~= "Countdown" and phase ~= "Running"',
		"local function publishProfile()\n\tcloseIdleStartGate()",
		"params.IgnoreWater = true",
		"setGateCollide = function(on)",
	} do
		assert(string.find(server, needle, 1, true), "RaceServer: " .. needle)
	end
	local service = read("src/common/ServerScriptService/Services/Race/RaceService.luau")
	local _, closes = string.gsub(service, "setGateCollide, true", "")
	local _, opens = string.gsub(service, "setGateCollide, false", "")
	assert(closes >= 2 and opens == 1, "RaceService closes the gate at staging and after the results, opens it once before GO")
	pass("RacePalmWind: BulkMoveTo, nil-tree safe, touch-only phones, Heartbeat only while palms exist; RaceServer closes an open StartGate outside the start, raycast ignores water")
end

----------------------------------------------------------------------
-- 10. build_update4 --greenhill
----------------------------------------------------------------------
do
	local fakeProcess = { args = { "module" }, exit = function() end, exec = process.exec, env = process.env }
	local chunk = luau.load(read("audit/build_update4.luau"), {
		debugName = "build_update4",
		environment = setmetatable({
			require = function(path)
				if path == "@lune/process" then
					return fakeProcess
				end
				return require(path)
			end,
		}, { __index = _G }),
	})
	local build = chunk()
	assert(type(build) == "table" and build.insertGreenHill and build.clearArena, "module mode exports insertGreenHill")
	local function place()
		local dm = Instance.new("DataModel")
		return dm, dm:GetService("Workspace")
	end
	-- Empty place: the arena goes in stamped, the gate is built.
	local dm, workspace = place()
	local notes = {}
	build.insertGreenHill(dm, "World1", notes)
	local placed = workspace:FindFirstChild("RaceArena")
	assert(placed and placed:GetAttribute("U4Asset") == GreenHill.Stamp and placed:GetAttribute("RaceArenaStyle") == "GreenHill", "stamped Green Hill arena")
	assert(workspace:FindFirstChild("RaceGate") and workspace.RaceGate:GetAttribute("U4Asset") == "RaceGate", "a missing gate is built")
	assert(#GreenHill.Verify(placed) == 0, "the placed arena verifies")
	-- Our builder's arena and gate: arena replaced, the gate kept as it is.
	local gate = workspace.RaceGate
	local old = Instance.new("Model")
	old.Name = "RaceArena"
	old:SetAttribute("U4Asset", "RaceArena")
	placed.Parent = nil
	old.Parent = workspace
	build.insertGreenHill(dm, "World1", notes)
	assert(old.Parent == nil and workspace.RaceArena:GetAttribute("U4Asset") == GreenHill.Stamp and workspace.RaceGate == gate, "our stamped arena replaced, RaceGate kept")
	-- A Green Hill arena again: replaced.
	local previous = workspace.RaceArena
	build.insertGreenHill(dm, "World1", notes)
	assert(previous.Parent == nil and workspace.RaceArena ~= previous, "a Green Hill arena is ours to replace")
	-- Someone else's arena: refused.
	workspace.RaceArena.Parent = nil
	local theirs = Instance.new("Model")
	theirs.Name = "RaceArena"
	theirs.Parent = workspace
	local ok, err = pcall(build.insertGreenHill, dm, "World1", notes)
	assert(not ok and string.find(tostring(err), "without our U4Asset stamp", 1, true) and theirs.Parent == workspace, "an unstamped arena stops the build")
	-- The build's own text: the flag, the verify, the notes.
	local source = read("audit/build_update4.luau")
	for _, needle in {
		'local GREENHILL = table.find(process.args, "--greenhill") ~= nil',
		"if GREENHILL then\n\t\tinsertGreenHill(dm, key, notes)\n\t\treturn\n\tend",
		'local ARENA_STAMPS = { RaceArena = true, RaceArenaGreenHill = true }',
		'require("./u4_greenhill_arena").Verify(arena)',
		"if ours or greenHillArena then",
		"insertRaceAssets(dm, notes)\n\tinsertRace(dm, key, notes)",
	} do
		assert(string.find(source, needle, 1, true), "build_update4: " .. needle)
	end
	local result = process.exec("lune", { "run", "audit/build_update4.luau", "list", "--greenhill" })
	assert(result.ok, "build_update4 list --greenhill: " .. tostring(result.stderr))
	assert(string.find(result.stdout, "race map (--greenhill): Workspace.RaceArena <- Green Hill", 1, true), "`list --greenhill` reports the map")
	local plain = process.exec("lune", { "run", "audit/build_update4.luau", "list" })
	assert(plain.ok and string.find(plain.stdout, "race map: Workspace.RaceArena kept", 1, true), "`list` without the flag keeps the arena")
	pass("build_update4 --greenhill: stamped Green Hill arena in, our arenas replaced, others refused, RaceGate kept or built; list reports it")
end

----------------------------------------------------------------------
-- Places (read only)
----------------------------------------------------------------------
if process.args[1] == "places" then
	local PLACES = { World1 = "World1Update3New.rbxl", World2 = "World2Update3new.rbxl", World3 = "World3Update3New.rbxl" }
	local function boxDistance(aLo, aHi, bLo, bHi)
		local dx = math.max(bLo.X - aHi.X, aLo.X - bHi.X, 0)
		local dy = math.max(bLo.Y - aHi.Y, aLo.Y - bHi.Y, 0)
		local dz = math.max(bLo.Z - aHi.Z, aLo.Z - bHi.Z, 0)
		return math.sqrt(dx * dx + dy * dy + dz * dz)
	end
	local lo, hi = GreenHill.AABB(baseParts(arena))
	local waterLo = Vector3.new(ORIGIN.X - WATER.HalfX, ORIGIN.Y + WATER.SeabedBottom, ORIGIN.Z - WATER.SMax)
	local waterHi = Vector3.new(ORIGIN.X + WATER.HalfX, ORIGIN.Y + WATER.Top, ORIGIN.Z - WATER.SMin)
	for world, file in PLACES do
		local game = roblox.deserializePlace(fs.readFile(file))
		local workspace = game:GetService("Workspace")
		local starter = game:GetService("StarterPlayer")
		local jump = if starter.CharacterUseJumpPower then (starter.CharacterJumpPower ^ 2) / (2 * workspace.Gravity) else starter.CharacterJumpHeight
		assert(jump < GreenHill.WallClearance, world .. ": the jump (" .. jump .. ") is far under the walls")
		local placedArena = workspace:FindFirstChild("RaceArena")
		local isGreenHill = placedArena and placedArena:GetAttribute("U4Asset") == GreenHill.Stamp
		if isGreenHill then
			local problems = GreenHill.Verify(placedArena)
			if process.args[2] == "prebuild" then
				-- 2026-09-26: before a build, spike tiles that predate Update4Config's layout are
				-- expected (--greenhill makes them again); anything else still fails.
				local rest = {}
				for _, problem in problems do
					if string.find(problem, "spike tiles", 1, true) then
						print("  NOTE " .. world .. ": " .. problem)
					else
						table.insert(rest, problem)
					end
				end
				problems = rest
			end
			assert(#problems == 0, world .. ": " .. table.concat(problems, "; "))
		end
		local nearest, nearestName, nearestWater = math.huge, "", math.huge
		for _, part in workspace:GetDescendants() do
			if part:IsA("BasePart") and part.ClassName ~= "Terrain" and not (placedArena and part:IsDescendantOf(placedArena)) then
				local a, b = GreenHill.AABB({ part })
				local d = boxDistance(lo, hi, a, b)
				if d < nearest then
					nearest, nearestName = d, part:GetFullName()
				end
				nearestWater = math.min(nearestWater, boxDistance(waterLo, waterHi, a, b))
			end
		end
		assert(nearest >= 1500, string.format("%s: the Green Hill arena is >= 1500 studs from every other part (%.0f, %s)", world, nearest, nearestName))
		assert(nearestWater >= 1000, string.format("%s: the water is clear of the place (%.0f)", world, nearestWater))
		print(string.format("  %s: nearest other part %.0f studs from the arena (%s), %.0f from the water; jump %.1f; place arena: %s", world, nearest,
			nearestName, nearestWater, jump, if isGreenHill then "Green Hill (verified)" elseif placedArena then tostring(placedArena:GetAttribute("U4Asset")) else "none"))
	end
	pass("places: the Green Hill arena and its water stand clear of all 3 places, jumps far under the walls")
end

print(string.format("test_u4_greenhill: %d checks passed", passed))
