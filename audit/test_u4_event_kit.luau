-- test_u4_event_kit.luau (Update 4, 2026-09-26, owner: the "Super Sonic vs Dr. Eggman" event's Blender meshes)
-- audit/event_kit_bpy.py's kit (design/event/supersonic/) and its loader audit/u4_event_kit.luau. Checks:
--   1. the deliverables: the FBX (+ the ASCII public copy), one FBX / OBJ per piece, the previews, the import
--      guide, the generator;
--   2. the manifest: 11 single-colour EV_* pieces in 4 assets (one PrimaryPart each), Roblox's limits and the
--      budgets, the re-import check, the sizes (a 3-stud bomb standing nose-down, a 1.5 x 1.6 emerald with 7
--      colours, a ~6-stud spin ball that holds a standing R6, the cannon), the attachments;
--   3. the cannon on the Egg Mobile (its manifest): the mount on the black bowl at the front, under the lamp and
--      over the floor, the muzzle ahead of the ship pointing forward and down at the stated pitch, the bomb fits
--      the bore and a bomb at the spawn point clears the barrel, ship / hull / local frames agree;
--   4. a stand-in of Studio's import (MeshParts from the manifest, the kit turned 180 degrees with its
--      PivotOffsets) builds Meshes.Bomb / ChaosEmerald / SpinBall / Cannon: every piece where the manifest puts it
--      with the turn undone (an authored point lands on itself), welded to its PrimaryPart, inert, coloured from
--      the manifest, the attachments and attributes, pivots on the asset origin; any quarter turn, a wrapper
--      Model, importer suffixes and a 1/100 unit give the same; it serializes;
--   5. what does not fit: a missing piece, a Part for a mesh, a wrong shape leave that asset out (the others
--      are built); scrambled pivots leave everything out; local content (Upload off) stops with the fix; a script
--      in the kit is found;
--   6. Insert: fills the Meshes folder audit/u4_supersonic_assets makes (or makes one), replaces its own older
--      templates, keeps someone else's; with no kit it returns nil and says so (the event keeps its shapes); the
--      owner's EventKit.rbxm when it is there; u4_supersonic_assets.Build fills SuperSonicEventAssets.Meshes.
--   7. the gold ring, a SEPARATE mini kit (audit/ring_kit_bpy.py, design/event/supersonic/ring/): its deliverables
--      (RingKit.fbx + the public copy, fbx / obj fallbacks, the renders, the owner's reference, IMPORTAR_ANILLO.md),
--      its manifest (a smooth round torus 2.4 across, a quarter-diameter tube, a half-diameter hole, centred pivot,
--      exact normals, polished gold, not Neon), the event kit untouched; a stand-in of Studio's import (180 degrees,
--      and 0 / 90 / 270, a wrapper, a suffix, a 1/100 unit) builds Meshes.Ring with the turn undone; what does not
--      fit; Insert with the ring (after the event kit, the turn hint from it, replaced, someone else's kept) and
--      without it (nothing changes); the owner's RingKit.rbxm when it is there.
-- Run: lune run audit/test_u4_event_kit.luau   (from the project root; reads no place)
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local Vector3, CFrame, Instance = roblox.Vector3, roblox.CFrame, roblox.Instance
local EventKit = require("./u4_event_kit")
local MeshKitImport = require("../src/common/ReplicatedStorage/Shared/MeshKitImport")

local DIR = "design/event/supersonic/"
local passed = 0
local function pass(text)
	passed += 1
	print("PASS " .. text)
end
local function near(a, b, eps)
	return math.abs(a - b) <= (eps or 1e-3)
end
local function v3(list)
	return Vector3.new(list[1], list[2], list[3])
end
local function close(a, b, eps)
	return (a - b).Magnitude <= (eps or 1e-3)
end
local function joined(list)
	return table.concat(list, " | ")
end

local manifest = EventKit.Manifest()
-- Sections 1-6: the event kit alone (an owner's RingKit.rbxm, once saved, must not change them; section 7 is the ring).
EventKit.SetRingOverride(false)
local egg = serde.decode("json", fs.readFile("design/npc/eggmobile/eggmobile_manifest.json"))
local PIECES = {
	Bomb = { "EV_Bomb", "EV_BombStripe", "EV_BombFins", "EV_BombNose" },
	ChaosEmerald = { "EV_ChaosEmerald" },
	SpinBall = { "EV_SpinBall" },
	Cannon = { "EV_Cannon", "EV_CannonMetal", "EV_CannonDark", "EV_CannonStripe", "EV_CannonGlow" },
}
local byName = {}
for _, piece in manifest.pieces do
	byName[piece.name] = piece
end

-- 1. The deliverables.
do
	assert(fs.isFile("audit/event_kit_bpy.py"), "the generator")
	assert(fs.isFile(DIR .. "EventKit.fbx") and fs.isFile("C:/Users/Public/EventKit/EventKit.fbx"), "EventKit.fbx and its public copy")
	assert(fs.readFile(DIR .. "EventKit.fbx") == fs.readFile("C:/Users/Public/EventKit/EventKit.fbx"), "the public copy is the same file")
	for _, piece in manifest.pieces do
		assert(fs.isFile(DIR .. "fbx/" .. piece.name .. ".fbx"), "fbx/" .. piece.name)
		assert(fs.isFile(DIR .. "obj/" .. piece.name .. ".obj") and fs.isFile(DIR .. "obj/" .. piece.name .. ".mtl"), "obj/" .. piece.name)
		assert(fs.isFile(DIR .. "preview/piece_" .. piece.name .. ".png"), "preview of " .. piece.name)
	end
	for _, file in { "emeralds_ring", "bomb_standing", "bomb_flight", "spinball_r6", "cannon_on_eggmobile_front34",
		"cannon_on_eggmobile_side", "cannon_closeup", "kit_overview" } do
		assert(fs.isFile(DIR .. "preview/" .. file .. ".png"), "preview " .. file)
	end
	local guide = fs.readFile(DIR .. "IMPORTAR_EVENTO.md")
	for _, needle in { "Import 3D", "Scale Unit", "Merge Meshes", "Upload to Roblox", "EventKit.rbxm", "11", "C:\\Users\\Public\\EventKit\\EventKit.fbx" } do
		assert(string.find(guide, needle, 1, true), "IMPORTAR_EVENTO.md mentions " .. needle)
	end
	local bomb = byName.EV_Bomb.size
	assert(string.find(guide, ("%.2f"):format(bomb[2]), 1, true), "IMPORTAR_EVENTO.md gives EV_Bomb's size")
	pass("deliverables: EventKit.fbx (+ C:/Users/Public/EventKit copy), fbx/ + obj/ per piece, 20 previews, IMPORTAR_EVENTO.md")
end

-- 2. The manifest.
local tris = 0
do
	assert(manifest.generator == "audit/event_kit_bpy.py" and #manifest.pieces == 11, "11 pieces from the generator")
	local seen = {}
	for asset, names in PIECES do
		local block = manifest.assets[asset]
		assert(block and #block.pieces == #names, asset .. ": its pieces")
		local primaries = 0
		for i, name in names do
			assert(block.pieces[i] == name, asset .. " piece " .. i .. " is " .. name)
			local piece = byName[name]
			assert(piece and piece.asset == asset, name .. " belongs to " .. asset)
			seen[name] = true
			if piece.primary then
				primaries += 1
				assert(block.primary == name, asset .. ": PrimaryPart " .. name)
			end
		end
		assert(primaries == 1, asset .. ": one PrimaryPart")
	end
	local perAsset = {}
	for _, piece in manifest.pieces do
		assert(seen[piece.name] and string.sub(piece.name, 1, 3) == "EV_", piece.name .. " is an EV_ piece of an asset")
		assert(piece.tris <= 20000 and piece.verts <= 10000 and piece.renderVerts <= 10000, piece.name .. " within Roblox's mesh limits")
		assert(#piece.color == 3 and roblox.Enum.Material[piece.material] ~= nil and piece.reflectance >= 0, piece.name .. ": colour, material")
		assert(piece.pivot[1] == 0 and piece.pivot[2] == 0 and piece.pivot[3] == 0, piece.name .. ": pivot on the asset origin")
		perAsset[piece.asset] = (perAsset[piece.asset] or 0) + piece.tris
		tris += piece.tris
	end
	for asset, count in perAsset do
		assert(count <= manifest.budgets[asset], asset .. " within its budget")
	end
	assert(tris == manifest.totalTris, "totalTris")
	assert(manifest.reimportCheck.worstErrorStuds < 0.01 and #manifest.reimportCheck.missing == 0, "the FBX re-imports")
	for file, facts in manifest.fbxFacts do
		assert(near(facts.unitScaleFactor, 1, 1e-6) and facts.asciiOnly and not facts.userFolderInside, file .. ": 1 unit = 1 stud, ASCII")
	end
	local b = manifest.assets.Bomb
	assert(b.noseAxis == "-Y" and near(b.length, 3, 0.02) and near(b.size[2], 3, 0.02) and b.diameter < 1.7, "a 3-stud bomb, nose-down")
	assert(close(v3(b.attachments.Nose.direction), Vector3.new(0, -1, 0)) and b.attachments.Nose.position[2] < -1.4, "the nose at -Y")
	assert(byName.EV_BombNose.bboxCenterOffset[2] < -1 and byName.EV_BombFins.bboxCenterOffset[2] > 0, "nose down, fins up")
	local e = manifest.assets.ChaosEmerald
	assert(near(e.height, 1.5, 0.01) and near(e.diameter, 1.6, 0.01) and byName.EV_ChaosEmerald.shading == "flat", "a 1.5 x 1.6 flat-faceted emerald")
	for _, key in { "Green", "Red", "Blue", "Yellow", "Cyan", "Purple", "White" } do
		assert(e.variants[key] and #e.variants[key] == 3 and table.find(e.variantOrder, key), "emerald colour " .. key)
	end
	local s = manifest.assets.SpinBall
	assert(s.diameter >= 6 and s.diameter <= 6.6 and s.innerRadius < s.outerRadius, "a ~6-stud spin ball shell")
	-- A standing R6 (torso 2x2x1, arms and legs 1x2x1, a 1.25 head) with its root at rootOffset fits the inner shell.
	local root = v3(s.rootOffset)
	for _, corner in { { 2, 1, 0.5 }, { 2, -1, 0.5 }, { 1, -3, 0.5 }, { 0.625, 2.125, 0.625 } } do
		for _, sx in { -1, 1 } do
			assert((root + Vector3.new(corner[1] * sx, corner[2], corner[3])).Magnitude < s.innerRadius, "an R6 fits the spin ball")
		end
	end
	pass(("manifest: 11 EV_ pieces in 4 assets, %d triangles (Bomb %d, Emerald %d, SpinBall %d, Cannon %d), within Roblox's limits, "
		.. "re-imports 1:1; a 3-stud nose-down bomb, a 1.5 x 1.6 emerald in 7 colours, a %.2f-stud spin ball holding an R6")
		:format(tris, perAsset.Bomb, perAsset.ChaosEmerald, perAsset.SpinBall, perAsset.Cannon, s.diameter))
end

-- 3. The cannon on the Egg Mobile.
do
	local c = manifest.assets.Cannon
	local ship = egg.ship
	local function hullR(y)
		local t = math.min(1, (ship.wallFrom - y) / (ship.wallFrom - ship.hullBottom))
		return ship.hullRadius * math.sqrt(math.max(0, 1 - t * t))
	end
	local mount = v3(c.mount.ship)
	local centre = v3(ship.hullCenter)
	assert(mount.X == 0 and mount.Z < 0 and near(math.sqrt(mount.X ^ 2 + mount.Z ^ 2), hullR(mount.Y), 0.005), "the mount is on the bowl, at the front")
	assert(mount.Y < ship.whiteEdge + 0.5, "on the black bowl")
	assert(close(v3(c.mount.hull), mount - centre) and close(v3(c.muzzle.hull), v3(c.muzzle.ship) - centre)
		and close(v3(c.muzzle["local"]), v3(c.muzzle.ship) - mount) and close(v3(c.muzzle.spawnLocal), v3(c.muzzle.spawnShip) - mount),
		"ship / hull / local frames agree")
	local lamp
	for _, piece in egg.pieces do
		if piece.name == "EM_Lamp" then
			lamp = piece
		end
	end
	assert(mount.Y + c.boundsMax[2] < 3.0 and mount.Y + c.boundsMax[2] < lamp.bboxCenterOffset[2] - lamp.size[2] / 2,
		"the cannon stays under the lamp and its bezel")
	assert(mount.Y + c.boundsMin[2] > -0.1, "and over the floor")
	local muzzle, dir = v3(c.muzzle.ship), v3(c.muzzle.direction)
	assert(muzzle.Z < egg.shipBounds.min[3] and dir.Z < -0.8 and dir.Y < 0 and near(dir.Magnitude, 1, 1e-3), "the muzzle ahead, pointing forward and down")
	assert(near(math.deg(math.asin(-dir.Y)), c.pitchDegrees, 0.05), "at the stated pitch")
	assert(manifest.assets.Bomb.diameter < 2 * c.muzzle.boreRadius, "the bomb fits the bore")
	local spawnGap = (v3(c.muzzle.spawnShip) - muzzle)
	assert(spawnGap.Unit:Dot(dir) > 0.999 and spawnGap.Magnitude >= manifest.assets.Bomb.length / 2 + 0.1, "a bomb at the spawn clears the barrel")
	assert(close(v3(c.attachments.Muzzle.position), v3(c.muzzle["local"])) and close(v3(c.attachments.Spawn.position), v3(c.muzzle.spawnLocal)),
		"the attachments are the manifest's points")
	pass(("the cannon: mounted on the bowl at %s (hull %s), under the lamp, over the floor; muzzle %s (hull %s) pointing %.0f degrees down; "
		.. "the bomb fits the %.2f bore and clears it from the spawn"):format(tostring(mount), tostring(v3(c.mount.hull)), tostring(muzzle),
		tostring(v3(c.muzzle.hull)), c.pitchDegrees, c.muzzle.boreRadius * 2))
end

-- 4. A stand-in of Studio's import builds the four templates.
local function assembled(meshes, turn, label)
	local problems = EventKit.Problems(meshes, manifest)
	assert(#problems == 0, label .. ": " .. joined(problems))
	local unturn = CFrame.Angles(0, -turn * math.pi / 2, 0)
	for asset, names in PIECES do
		local template = meshes:FindFirstChild(asset)
		assert(template, label .. ": Meshes." .. asset)
		local isModel = #names > 1
		assert(template.ClassName == (if isModel then "Model" else "MeshPart"), label .. ": " .. asset .. " is a " .. template.ClassName)
		local primary = if isModel then template.PrimaryPart else template
		assert(primary and primary:GetAttribute("EventKitPiece") == manifest.assets[asset].primary and primary.Anchored, label .. ": " .. asset .. "'s PrimaryPart")
		assert(close((primary.CFrame * primary.PivotOffset).Position, Vector3.zero) and close((primary.CFrame * primary.PivotOffset).LookVector,
			Vector3.new(0, 0, -1), 1e-4), label .. ": " .. asset .. " pivots on its origin")
		assert(template:GetAttribute("U4Asset") == EventKit.Stamp and template:GetAttribute("EventKitAsset") == asset
			and template:GetAttribute("EventKitImportTurn") == turn * 90, label .. ": " .. asset .. "'s stamp")
		for _, name in names do
			local spec = byName[name]
			local part = if isModel then template:FindFirstChild(name) else template
			assert(part and part.ClassName == "MeshPart", label .. ": " .. name)
			-- The importer baked the mesh turned (R(turn) about its box centre): an authored point p shows at
			-- part.CFrame * (R(turn) * (p - offset)), which must be p again.
			local offset = v3(spec.bboxCenterOffset)
			for _, p in { offset, offset + Vector3.new(0.5, 0.25, -0.75), offset + Vector3.new(-spec.size[1], spec.size[2], spec.size[3]) / 2 } do
				local shown = part.CFrame * (CFrame.Angles(0, turn * math.pi / 2, 0) * (p - offset))
				assert(close(shown, p, 2e-3), ("%s: %s: an authored point lands at %s, not %s"):format(label, name, tostring(shown), tostring(p)))
			end
			assert(close(part.CFrame.LookVector, unturn.LookVector, 1e-4), label .. ": " .. name .. " turned back")
			local want = MeshKitImport.TurnedSize(spec.size, turn)
			assert(close(part.Size, v3(want), 1e-3), label .. ": " .. name .. " size")
			assert(part.Color == roblox.Color3.fromRGB(spec.color[1], spec.color[2], spec.color[3]) and part.Material == roblox.Enum.Material[spec.material]
				and near(part.Reflectance, spec.reflectance) and near(part.Transparency, spec.transparency) and part.CastShadow == spec.castShadow,
				label .. ": " .. name .. "'s look from the manifest")
			assert(not part.CanCollide and not part.CanTouch and not part.CanQuery, label .. ": " .. name .. " inert")
			assert(#part:GetChildren() == (if part == primary then #(function()
				local list = {}
				for k in manifest.assets[asset].attachments do
					table.insert(list, k)
				end
				return list
			end)() else 1), label .. ": " .. name .. " carries only its weld / attachments")
			if part ~= primary then
				assert(part.Massless and not part.Anchored, label .. ": " .. name .. " massless, held by its weld")
			end
		end
		for attachmentName, a in manifest.assets[asset].attachments do
			local attachment = primary:FindFirstChild(attachmentName)
			assert(attachment and attachment.ClassName == "Attachment", label .. ": " .. asset .. "." .. attachmentName)
			local world = primary.CFrame * attachment.CFrame
			assert(close(world.Position, v3(a.position)) and close(world.LookVector, v3(a.direction).Unit, 1e-4),
				label .. ": " .. asset .. "." .. attachmentName .. " where the manifest says")
		end
	end
	local cannon = meshes.Cannon
	-- (attributes keep a little less than float32: compared within 1e-4)
	assert(close(cannon:GetAttribute("MountShip"), v3(manifest.assets.Cannon.mount.ship), 1e-4)
		and close(cannon:GetAttribute("MuzzleHull"), v3(manifest.assets.Cannon.muzzle.hull), 1e-4)
		and close(cannon:GetAttribute("MuzzleDirection"), v3(manifest.assets.Cannon.muzzle.direction), 1e-4),
		label .. ": the cannon's mount / muzzle attributes")
	assert(meshes.Bomb:GetAttribute("NoseAxis") == "-Y" and close(meshes.SpinBall:GetAttribute("RootOffset"), v3(manifest.assets.SpinBall.rootOffset), 1e-4)
		and meshes.ChaosEmerald:GetAttribute("ColorPurple") ~= nil and meshes.ChaosEmerald:GetAttribute("VariantOrder") ==
		table.concat(manifest.assets.ChaosEmerald.variantOrder, ","), label .. ": the bomb / ball / emerald attributes")
	assert(#roblox.serializeModel({ meshes }) > 0, label .. ": serializes")
end

do
	local meshes, report = EventKit.Build(EventKit.StandIn(manifest), manifest)
	assert(meshes and #report.built == 4 and #report.problems == 0 and report.turn == 2, "the 180-degree import builds 4 assets: " .. joined(report.problems))
	assembled(meshes, 2, "180")
	for turn = 0, 3 do
		local m, r = EventKit.Build(EventKit.StandIn(manifest, { turn = turn, wrap = turn == 1, surfaceAppearance = turn == 3 }), manifest)
		assert(m and r.turn == turn, "turn " .. turn .. ": " .. joined(r.problems))
		assembled(m, turn, "turn " .. turn)
	end
	local suffixed = EventKit.StandIn(manifest, { rename = { EV_Cannon = "EV_Cannon.001", EV_BombFins = "EV_BombFins_Mesh" }, scale = 0.01 })
	local m = EventKit.Build(suffixed, manifest)
	assert(m, "suffixes and a 1/100 unit")
	assembled(m, 2, "suffixes + 1/100")
	pass("a stand-in of Studio's 180-degree import (and 0 / 90 / 270, a wrapper Model, importer suffixes, a 1/100 unit) builds "
		.. "Meshes.Bomb (Model) / ChaosEmerald / SpinBall / Cannon (Model): every piece where the manifest puts it with the turn undone, "
		.. "welded to its PrimaryPart, inert, its look from the manifest, pivots on the asset origin, the attachments and attributes; it serializes")
end

-- 5. What does not fit.
do
	local function build(root)
		local m, r = EventKit.Build(root, manifest)
		return m, r
	end
	local m, r = build(EventKit.StandIn(manifest, { omit = { EV_BombNose = true } }))
	assert(m and not m:FindFirstChild("Bomb") and m:FindFirstChild("Cannon") and m:FindFirstChild("SpinBall") and m:FindFirstChild("ChaosEmerald")
		and table.find(r.skipped, "Bomb") and string.find(joined(r.problems), "EV_BombNose is not in the kit", 1, true), "a missing piece leaves its asset out")
	local asPart = EventKit.StandIn(manifest)
	local glow = asPart:FindFirstChild("EV_CannonGlow", true)
	local block = Instance.new("Part")
	block.Name, block.Size, block.CFrame, block.PivotOffset, block.Parent = "EV_CannonGlow", glow.Size, glow.CFrame, glow.PivotOffset, glow.Parent
	glow.Parent = nil
	m, r = build(asPart)
	assert(m and not m:FindFirstChild("Cannon") and m:FindFirstChild("Bomb") and string.find(joined(r.problems), "EV_CannonGlow is a Part", 1, true),
		"a Part for a mesh leaves its asset out")
	local squashed = EventKit.StandIn(manifest)
	local gem = squashed:FindFirstChild("EV_ChaosEmerald", true)
	gem.Size = Vector3.new(gem.Size.X, gem.Size.Y * 0.5, gem.Size.Z)
	m, r = build(squashed)
	assert(m and not m:FindFirstChild("ChaosEmerald") and string.find(joined(r.problems), "EV_ChaosEmerald has the wrong shape", 1, true),
		"a wrong shape leaves its asset out")
	local scrambled = EventKit.StandIn(manifest)
	for _, part in scrambled:GetDescendants() do
		if part:IsA("MeshPart") then
			part.PivotOffset = CFrame.new(part.PivotOffset.Position.Z + 3, 0, -part.PivotOffset.Position.X)
		end
	end
	m, r = build(scrambled)
	assert(m == nil and #r.skipped == 4 and string.find(joined(r.problems), "match no quarter turn", 1, true), "scrambled pivots: nothing built")
	local notes = {}
	local assets = Instance.new("Folder")
	assets.Name = "SuperSonicEventAssets"
	assert(EventKit.Insert(assets, notes, scrambled) == nil and string.find(notes[1], "event kit not used", 1, true), "Insert says why")
	local uploaded = EventKit.StandIn(manifest)
	uploaded:FindFirstChild("EV_SpinBall", true).MeshId = "rbxasset://EV_SpinBall.mesh"
	local ok, err = pcall(EventKit.Build, uploaded, manifest)
	assert(not ok and string.find(tostring(err), "Upload to Roblox on", 1, true), "local content stops the build with the fix")
	local withScript = EventKit.StandIn(manifest)
	Instance.new("Script").Parent = withScript:FindFirstChild("EV_Bomb", true)
	assert(#EventKit.Scripts(withScript) == 1, "a script in the kit is found")
	pass("what does not fit: a missing piece, a Part for a mesh or a wrong shape leave only that asset out; scrambled pivots leave all out "
		.. "(Insert says why); local content (Upload off) stops with the fix; a script in the kit is found")
end

-- 6. Insert.
do
	local assets = Instance.new("Folder")
	assets.Name = "SuperSonicEventAssets"
	local empty = Instance.new("Folder")
	empty.Name = "Meshes"
	empty.Parent = assets
	local notes = {}
	local meshes = EventKit.Insert(assets, notes, EventKit.StandIn(manifest))
	assert(meshes == empty and #meshes:GetChildren() == 4 and meshes:GetAttribute("EventKitAssets") == "Bomb,ChaosEmerald,SpinBall,Cannon",
		"fills the Meshes folder u4_supersonic_assets made")
	assert(string.find(notes[1], "SuperSonicEventAssets.Meshes: Bomb, ChaosEmerald, SpinBall, Cannon (11 kit pieces, import turn 180 deg)", 1, true),
		"its note: " .. tostring(notes[1]))
	assembled(meshes, 2, "Insert")
	local first = meshes.Bomb
	EventKit.Insert(assets, {}, EventKit.StandIn(manifest))
	assert(#assets.Meshes:GetChildren() == 4 and assets.Meshes.Bomb ~= first and #assets:GetChildren() == 1, "a rebuild replaces its own templates")
	-- Someone else's template of an asset's name stays; ours is not put in.
	assets.Meshes.Cannon.Parent = nil
	local owners = Instance.new("Model")
	owners.Name = "Cannon"
	owners.Parent = assets.Meshes
	notes = {}
	EventKit.Insert(assets, notes, EventKit.StandIn(manifest))
	assert(assets.Meshes.Cannon == owners and #assets.Meshes:GetChildren() == 4 and string.find(joined(notes), "someone else's", 1, true),
		"someone else's Cannon is kept")
	-- No kit: nil, a note, our templates gone (the event draws its shapes), the folder and anything else kept.
	notes = {}
	assert(EventKit.Insert(assets, notes, false) == nil, "no kit: nil")
	assert(#assets.Meshes:GetChildren() == 1 and assets.Meshes.Cannon == owners, "no kit: our templates removed, the rest kept")
	assert(#notes == 1 and string.find(notes[1], "no " .. EventKit.KitFile, 1, true) and string.find(notes[1], "simple shapes", 1, true),
		"no kit: the note says so")
	-- A folder without Meshes gets one.
	local bare = Instance.new("Folder")
	bare.Name = "SuperSonicEventAssets"
	assert(EventKit.Insert(bare, nil, EventKit.StandIn(manifest)) == bare:FindFirstChild("Meshes") and #bare.Meshes:GetChildren() == 4, "Meshes made")
	-- The owner's file (design/event/supersonic/EventKit.rbxm) when it is there; nil and a note when not.
	EventKit.SetOverride(nil)
	local real = Instance.new("Folder")
	real.Name = "SuperSonicEventAssets"
	notes = {}
	local built = EventKit.Insert(real, notes)
	local ownerKit
	if EventKit.KitPath() then
		assert(built and #built:GetChildren() == 4 and #EventKit.Problems(built, manifest) == 0, "the owner's kit builds: " .. joined(notes))
		ownerKit = ("the owner's %s builds all 4 (import turn %d)"):format(EventKit.KitPath(), built:GetAttribute("EventKitImportTurn"))
	else
		assert(built == nil and #real:GetChildren() == 0 and string.find(notes[1], "no " .. EventKit.KitFile, 1, true), "no file: nil and a note")
		ownerKit = "no " .. EventKit.KitFile .. " yet: Insert returns nil with a note"
	end
	-- audit/u4_supersonic_assets (the build's step) fills SuperSonicEventAssets.Meshes through Insert.
	EventKit.SetOverride(EventKit.StandIn(manifest))
	local Assets = require("./u4_supersonic_assets")
	notes = {}
	local folder = Assets.Build(notes)
	assert(folder.Meshes and #folder.Meshes:GetChildren() == 4 and #EventKit.Problems(folder.Meshes, manifest) == 0, "u4_supersonic_assets.Build fills Meshes: " .. joined(notes))
	local dm = Instance.new("DataModel")
	Assets.Insert(dm, {})
	Assets.Verify("memory", dm)
	EventKit.SetOverride(nil)
	pass("Insert: fills the Meshes folder of SuperSonicEventAssets (made when missing), replaces its own templates, keeps someone else's; "
		.. "no kit -> nil and a note, the event keeps its shapes; " .. ownerKit .. "; u4_supersonic_assets.Build / Insert fill it")
end

-- 7. The gold ring: a separate mini kit.
local RDIR = "design/event/supersonic/ring/"
local ringManifest = EventKit.RingManifest()
local ringPiece = ringManifest.pieces[1]
local ringAsset = ringManifest.assets.Ring
local R_MAJOR, R_TUBE = ringAsset.majorRadius, ringAsset.tubeRadius

-- A point of the ring's surface (authored frame: upright, hole along Z).
local function torusPoint(phi, theta)
	local rho = R_MAJOR + R_TUBE * math.cos(theta)
	return Vector3.new(math.cos(phi) * rho, math.sin(phi) * rho, R_TUBE * math.sin(theta))
end
local function onTorus(q, eps)
	local rho = math.sqrt(q.X * q.X + q.Y * q.Y)
	return math.abs(math.sqrt((rho - R_MAJOR) ^ 2 + q.Z * q.Z) - R_TUBE) <= (eps or 2e-3)
end

-- 7a. The deliverables.
do
	assert(fs.isFile("audit/ring_kit_bpy.py"), "the ring generator")
	local public = "C:/Users/Public/RingKit/"
	assert(fs.isFile(RDIR .. "RingKit.fbx") and fs.isFile(public .. "RingKit.fbx"), "RingKit.fbx and its public copy")
	assert(fs.readFile(RDIR .. "RingKit.fbx") == fs.readFile(public .. "RingKit.fbx"), "the public copy is the same file")
	for _, file in { "fbx/EV_Ring.fbx", "obj/EV_Ring.obj", "obj/EV_Ring.mtl" } do
		assert(fs.isFile(RDIR .. file) and fs.readFile(RDIR .. file) == fs.readFile(public .. file), file .. " (+ the public copy)")
	end
	for _, file in { "ring_manifest.json", "IMPORTAR_ANILLO.md" } do
		assert(fs.isFile(public .. file) and fs.readFile(public .. file) == fs.readFile(RDIR .. file), "the public " .. file)
	end
	assert(fs.isFile(RDIR .. "RingKit.blend"), "RingKit.blend")
	for _, file in { "ring_closeup", "rings_on_grass", "ring_profile", "piece_EV_Ring" } do
		local png = fs.isFile(RDIR .. "preview/" .. file .. ".png") and fs.readFile(RDIR .. "preview/" .. file .. ".png")
		assert(png and string.sub(png, 1, 8) == "\137PNG\r\n\26\n" and #png > 50000, "preview " .. file .. ".png")
	end
	local reference = fs.readFile(RDIR .. "reference/ring_reference.webp")
	assert(string.sub(reference, 1, 4) == "RIFF" and string.sub(reference, 9, 12) == "WEBP", "the owner's reference, kept")
	local guide = fs.readFile(RDIR .. "IMPORTAR_ANILLO.md")
	local size = ringPiece.size
	for _, needle in { "Import 3D", "Scale Unit: Stud", "Merge Meshes: DESACTIVADO", "Upload to Roblox: ACTIVADO", "EV_Ring",
		"RingKit.rbxm", "Update2/RingKit.rbxm", "C:\\Users\\Public\\RingKit\\RingKit.fbx", "EventKit.rbxm", "1 MeshPart",
		("(%.2f, %.2f, %.2f)"):format(size[1], size[2], size[3]), ringPiece.material } do
		assert(string.find(guide, needle, 1, true), "IMPORTAR_ANILLO.md mentions " .. needle)
	end
	pass("ring deliverables: RingKit.fbx (+ C:/Users/Public/RingKit copy), fbx/ + obj/ fallbacks, RingKit.blend, 4 previews, "
		.. "the owner's reference, IMPORTAR_ANILLO.md (Import 3D, Stud, Merge Meshes off, Upload on, 1 MeshPart EV_Ring of "
		.. ("(%.2f, %.2f, %.2f)"):format(size[1], size[2], size[3]) .. ", saved as Update2/RingKit.rbxm)")
end

-- 7b. The ring manifest; the event kit is not touched.
do
	local m, p = ringManifest, ringPiece
	assert(m.generator == "audit/ring_kit_bpy.py" and m.kitVersion == EventKit.RingKitVersion and #m.pieces == 1, "one piece from the generator")
	assert(p.name == "EV_Ring" and p.asset == "Ring" and p.primary and ringAsset.primary == "EV_Ring" and ringAsset.pieces[1] == "EV_Ring",
		"EV_Ring is the Ring asset's PrimaryPart")
	assert(p.tris >= 1500 and p.tris <= 4000 and p.tris == m.totalTris and p.tris <= m.budgets.Ring, "a light mesh: " .. p.tris .. " triangles")
	assert(p.verts <= 10000 and p.renderVerts <= 10000, "within Roblox's vertex limit")
	local outer, thick = p.size[1], p.size[3]
	assert(near(outer, 2.4, 0.05) and near(p.size[2], outer, 1e-3), "2.4 studs across, round")
	assert(near(ringAsset.tubeDiameter, outer / 4, 0.03) and near(thick, ringAsset.tubeDiameter, 1e-3), "a tube a quarter of the diameter")
	assert(near(ringAsset.innerDiameter, outer / 2, 0.05) and near((outer - ringAsset.innerDiameter) / 2, thick, 1e-3),
		"the hole half the diameter; a round tube (as wide as it is deep)")
	assert(near(R_MAJOR + R_TUBE, outer / 2, 1e-3), "major + tube radius = the outer radius")
	assert(p.bboxCenterOffset[1] == 0 and p.bboxCenterOffset[2] == 0 and p.bboxCenterOffset[3] == 0 and p.pivot[1] == 0
		and p.pivot[2] == 0 and p.pivot[3] == 0, "its pivot on its centre")
	assert(ringAsset.holeAxis == "Z" and ringAsset.spinAxis == "Y" and thick < p.size[1], "standing upright, its hole facing +-Z")
	assert(p.shading == "smooth" and ringAsset.maxNormalErrorDeg < 0.5 and m.reimportCheck.maxNormalErrorDeg < 0.5, "exact smooth normals")
	assert(m.reimportCheck.worstErrorStuds < 0.01 and #m.reimportCheck.missing == 0 and m.reimportCheck.tris.EV_Ring == p.tris,
		"the FBX re-imports 1:1")
	for file, facts in m.fbxFacts do
		assert(near(facts.unitScaleFactor, 1, 1e-6) and facts.asciiOnly and not facts.userFolderInside, file .. ": 1 unit = 1 stud, ASCII")
	end
	assert(p.color[1] >= 230 and p.color[2] >= 150 and p.color[2] <= 220 and p.color[3] <= 80, "gold")
	assert((p.material == "SmoothPlastic" or p.material == "Metal") and roblox.Enum.Material[p.material] ~= nil
		and p.reflectance >= 0.2 and p.reflectance <= 0.5 and p.transparency == 0, "polished: SmoothPlastic / Metal with Reflectance, not Neon")
	assert(roblox.Enum.RenderFidelity[p.renderFidelity] ~= nil and ringAsset.colors.Gold[1] == p.color[1], "render fidelity, colours")
	-- The owner's imported event kit stays as it was: its manifest has its 11 pieces and no ring.
	assert(#manifest.pieces == 11 and byName.EV_Ring == nil and manifest.assets.Ring == nil and manifest.totalTris == tris,
		"the event kit's manifest is untouched")
	pass(("ring manifest: EV_Ring, %d triangles, %.2f across, a %.2f tube, a %.2f hole, centred pivot, upright (hole +-Z), exact normals "
		.. "(%.3f deg), re-imports 1:1; %s RGB(%d, %d, %d) with Reflectance %.2f; the event kit's manifest untouched (11 pieces)")
		:format(p.tris, outer, ringAsset.tubeDiameter, ringAsset.innerDiameter, m.reimportCheck.maxNormalErrorDeg, p.material,
		p.color[1], p.color[2], p.color[3], p.reflectance))
end

-- A built Meshes.Ring: `standInTurn` is the turn the stand-in's mesh was baked with, `turn` the one it was built with.
local function ringChecked(ring, standInTurn, turn, label)
	assert(ring and ring.ClassName == "MeshPart" and ring.Name == "Ring", label .. ": Meshes.Ring is a MeshPart")
	assert((turn - standInTurn) % 2 == 0, label .. ": the turn's parity")
	local want = MeshKitImport.TurnedSize(ringPiece.size, turn)
	assert(close(ring.Size, v3(want), 1e-3), label .. ": size " .. tostring(ring.Size))
	assert(close(ring.CFrame.Position, Vector3.zero) and close(ring.CFrame.LookVector, CFrame.Angles(0, -turn * math.pi / 2, 0).LookVector, 1e-4),
		label .. ": the import turn undone")
	local pivot = ring.CFrame * ring.PivotOffset
	assert(close(pivot.Position, Vector3.zero) and close(pivot.LookVector, Vector3.new(0, 0, -1), 1e-4) and close(pivot.UpVector, Vector3.new(0, 1, 0), 1e-4),
		label .. ": pivots on its centre, upright")
	-- The mesh the importer baked (turned by standInTurn) shows the authored torus again.
	local baked = CFrame.Angles(0, standInTurn * math.pi / 2, 0)
	for _, phi in { 0.3, 1.9, 4.0, 5.5 } do
		for _, theta in { 0, 1.2, 2.5, 4.4 } do
			local p = torusPoint(phi, theta)
			local shown = ring.CFrame * (baked * p)
			assert(onTorus(shown), ("%s: a point of the ring shows at %s, off the torus"):format(label, tostring(shown)))
			if turn == standInTurn then
				assert(close(shown, p, 2e-3), label .. ": an authored point lands on itself")
			end
		end
	end
	local spec = ringPiece
	assert(ring.Anchored and not ring.CanCollide and not ring.CanTouch and not ring.CanQuery and ring.CastShadow == spec.castShadow,
		label .. ": anchored and inert")
	assert(ring.Color == roblox.Color3.fromRGB(spec.color[1], spec.color[2], spec.color[3]) and ring.Material == roblox.Enum.Material[spec.material]
		and near(ring.Reflectance, spec.reflectance) and near(ring.Transparency, spec.transparency), label .. ": its look from the ring manifest")
	local okFidelity, fidelity = pcall(function()
		return ring.RenderFidelity
	end)
	assert(not okFidelity or fidelity == roblox.Enum.RenderFidelity[spec.renderFidelity], label .. ": RenderFidelity")
	assert(#ring:GetChildren() == 0, label .. ": nothing the importer added")
	assert(ring:GetAttribute("U4Asset") == EventKit.Stamp and ring:GetAttribute("EventKitAsset") == "Ring"
		and ring:GetAttribute("EventKitPiece") == "EV_Ring" and ring:GetAttribute("EventKitSource") == "RingKit"
		and ring:GetAttribute("EventKitImportTurn") == turn * 90 and ring:GetAttribute("EventKitVersion") == ringManifest.kitVersion,
		label .. ": its stamp")
	assert(near(ring:GetAttribute("OuterDiameter"), ringAsset.outerDiameter, 1e-4) and near(ring:GetAttribute("InnerDiameter"), ringAsset.innerDiameter, 1e-4)
		and near(ring:GetAttribute("TubeDiameter"), ringAsset.tubeDiameter, 1e-4) and ring:GetAttribute("HoleAxis") == "Z"
		and ring:GetAttribute("SpinAxis") == "Y" and ring:GetAttribute("ColorGold") == roblox.Color3.fromRGB(table.unpack(ringAsset.colors.Gold)),
		label .. ": its attributes")
	assert(#roblox.serializeModel({ ring }) > 0, label .. ": serializes")
end

-- 7c. A stand-in of Studio's import builds Meshes.Ring.
do
	-- The 180-degree import (Studio's, the ring's PivotOffset centred with the importer's rotation): turn 2 from the size.
	local standIn = EventKit.RingStandIn(ringManifest)
	local part = standIn:FindFirstChild("EV_Ring")
	assert(close(part.PivotOffset.Position, Vector3.zero) and close(part.PivotOffset.LookVector, Vector3.new(0, 1, 0), 1e-4),
		"the stand-in pivots like the real import (centred, the importer's rotation)")
	local ring, report = EventKit.BuildRing(standIn, ringManifest)
	assert(ring and report.turn == 2 and report.source == "size" and #report.problems == 0, "the 180-degree import: " .. joined(report.problems))
	ringChecked(ring, 2, 2, "180")
	local wrap = Instance.new("Folder")
	ring.Parent = wrap
	assert(#EventKit.Problems(wrap, manifest) == 0, "Problems checks the Ring against the ring manifest: " .. joined(EventKit.Problems(wrap, manifest)))
	-- Every quarter turn, with and without the event kit's turn as a hint.
	for turn = 0, 3 do
		local r1, rep1 = EventKit.BuildRing(EventKit.RingStandIn(ringManifest, { turn = turn, wrap = turn == 1, surfaceAppearance = turn == 3 }), ringManifest)
		assert(r1 and rep1.source == "size", "turn " .. turn .. ": " .. joined(rep1.problems))
		ringChecked(r1, turn, rep1.turn, "turn " .. turn)
		local r2, rep2 = EventKit.BuildRing(EventKit.RingStandIn(ringManifest, { turn = turn }), ringManifest, turn)
		assert(r2 and rep2.turn == turn and rep2.source == "event kit", "turn " .. turn .. " with the event kit's turn")
		ringChecked(r2, turn, turn, "turn " .. turn .. " + hint")
		local r3, rep3 = EventKit.BuildRing(EventKit.RingStandIn(ringManifest, { turn = turn }), ringManifest, (turn + 1) % 4)
		assert(r3 and rep3.source == "size" and (rep3.turn - turn) % 2 == 0, "a hint of the other parity is not used")
		ringChecked(r3, turn, rep3.turn, "turn " .. turn .. " + odd hint")
	end
	local r4 = EventKit.BuildRing(EventKit.RingStandIn(ringManifest, { rename = "EV_Ring.001", scale = 0.01, wrap = true }), ringManifest)
	ringChecked(r4, 2, 2, "suffix + 1/100 + wrapper")
	pass("a stand-in of Studio's 180-degree import (a centred PivotOffset: the turn read from the size) builds Meshes.Ring: a MeshPart "
		.. "pivoting on its centre at the origin, the turn undone (the torus shows as authored), anchored, inert, its look and "
		.. "attributes from the ring manifest; 0 / 90 / 270 (the event kit's turn used when it fits), a wrapper, a suffix, a 1/100 unit too")
end

-- 7d. What does not fit.
do
	local r, report = EventKit.BuildRing(EventKit.RingStandIn(ringManifest, { flat = true }), ringManifest)
	assert(r == nil and string.find(joined(report.problems), "EV_Ring has the wrong shape", 1, true), "lying flat: not used")
	r, report = EventKit.BuildRing(EventKit.RingStandIn(ringManifest, { omit = true }), ringManifest)
	assert(r == nil and string.find(joined(report.problems), "EV_Ring is not in the ring kit", 1, true), "no EV_Ring")
	local asPart = EventKit.RingStandIn(ringManifest)
	local mesh = asPart:FindFirstChild("EV_Ring")
	local block = Instance.new("Part")
	block.Name, block.Size, block.CFrame, block.Parent = "EV_Ring", mesh.Size, mesh.CFrame, asPart
	mesh.Parent = nil
	r, report = EventKit.BuildRing(asPart, ringManifest)
	assert(r == nil and string.find(joined(report.problems), "EV_Ring is a Part", 1, true), "a Part for the mesh")
	local uploaded = EventKit.RingStandIn(ringManifest)
	uploaded:FindFirstChild("EV_Ring").MeshId = "rbxasset://EV_Ring.mesh"
	local ok, err = pcall(EventKit.BuildRing, uploaded, ringManifest)
	assert(not ok and string.find(tostring(err), "Upload to Roblox on", 1, true) and string.find(tostring(err), "IMPORTAR_ANILLO.md", 1, true),
		"local content stops the build with the fix")
	local notes = {}
	local assets = Instance.new("Folder")
	assets.Name = "SuperSonicEventAssets"
	assert(EventKit.Insert(assets, notes, false, EventKit.RingStandIn(ringManifest, { flat = true })) == nil
		and string.find(joined(notes), "ring kit not used", 1, true), "Insert says why")
	pass("what does not fit the ring: lying flat, no EV_Ring, a Part for the mesh leave it out (Insert says why); local content "
		.. "(Upload off) stops with the fix")
end

-- 7e. Insert with and without the ring.
do
	local function fresh()
		local assets = Instance.new("Folder")
		assets.Name = "SuperSonicEventAssets"
		local meshes = Instance.new("Folder")
		meshes.Name = "Meshes"
		meshes.Parent = assets
		return assets, meshes
	end
	-- With the event kit: its templates and notes first, then the Ring (its turn from the event kit's).
	local assets, empty = fresh()
	local notes = {}
	local meshes = EventKit.Insert(assets, notes, EventKit.StandIn(manifest), EventKit.RingStandIn(ringManifest))
	assert(meshes == empty and #meshes:GetChildren() == 5 and meshes:FindFirstChild("Ring"), "the 4 event templates and the Ring")
	assert(meshes:GetAttribute("EventKitAssets") == "Bomb,ChaosEmerald,SpinBall,Cannon", "the event kit's attributes unchanged")
	assert(#notes == 2 and string.find(notes[1], "SuperSonicEventAssets.Meshes: Bomb, ChaosEmerald, SpinBall, Cannon (11 kit pieces, import turn 180 deg)", 1, true)
		and string.find(notes[2], "SuperSonicEventAssets.Meshes.Ring: EV_Ring (ring kit v1, import turn 180 deg from the event kit)", 1, true),
		"the notes: " .. joined(notes))
	assert(#EventKit.Problems(meshes, manifest) == 0, "no problems: " .. joined(EventKit.Problems(meshes, manifest)))
	assembled(meshes, 2, "Insert + ring")
	ringChecked(meshes.Ring, 2, 2, "Insert")
	-- An odd import (the event kit turned 90, the ring 270): the ring follows the event kit's turn.
	local oddAssets = fresh()
	notes = {}
	EventKit.Insert(oddAssets, notes, EventKit.StandIn(manifest, { turn = 1 }), EventKit.RingStandIn(ringManifest, { turn = 3 }))
	ringChecked(oddAssets.Meshes.Ring, 3, 1, "odd import")
	assert(string.find(notes[2], "import turn 90 deg from the event kit", 1, true), "odd import note: " .. tostring(notes[2]))
	-- A rebuild replaces our Ring; someone else's Ring is kept.
	local first = meshes.Ring
	EventKit.Insert(assets, {}, EventKit.StandIn(manifest), EventKit.RingStandIn(ringManifest))
	assert(#assets.Meshes:GetChildren() == 5 and assets.Meshes.Ring ~= first and #assets:GetChildren() == 1, "a rebuild replaces the Ring")
	assets.Meshes.Ring.Parent = nil
	local owners = Instance.new("Model")
	owners.Name = "Ring"
	owners.Parent = assets.Meshes
	notes = {}
	EventKit.Insert(assets, notes, EventKit.StandIn(manifest), EventKit.RingStandIn(ringManifest))
	assert(assets.Meshes.Ring == owners and #assets.Meshes:GetChildren() == 5 and string.find(joined(notes), "ring kit: SuperSonicEventAssets.Meshes.Ring is someone else's", 1, true),
		"someone else's Ring is kept")
	-- Without the ring kit nothing changes: the same templates, the same single note, no Ring.
	local plain, plainMeshes = fresh()
	local plainNotes = {}
	assert(EventKit.Insert(plain, plainNotes, EventKit.StandIn(manifest), false) == plainMeshes and #plainMeshes:GetChildren() == 4
		and plainMeshes:FindFirstChild("Ring") == nil and #plainNotes == 1, "no ring kit: the event kit alone, one note")
	-- The ring without the event kit: the Ring alone (the turn from its size).
	local ringOnly = Instance.new("Folder")
	ringOnly.Name = "SuperSonicEventAssets"
	notes = {}
	local only = EventKit.Insert(ringOnly, notes, false, EventKit.RingStandIn(ringManifest))
	assert(only and only.Parent == ringOnly and #only:GetChildren() == 1 and only.Ring and #notes == 2
		and string.find(notes[1], "no " .. EventKit.KitFile, 1, true) and string.find(notes[2], "import turn 180 deg from the size", 1, true),
		"the ring alone: " .. joined(notes))
	ringChecked(only.Ring, 2, 2, "ring alone")
	-- Neither: nil and only the event kit's note.
	notes = {}
	assert(EventKit.Insert(fresh(), notes, false, false) == nil and #notes == 1, "neither kit: nil, one note")
	-- The owner's RingKit.rbxm (Update2/ or design/event/supersonic/ring/) when it is there; nothing when not.
	EventKit.SetRingOverride(nil)
	local real = Instance.new("Folder")
	real.Name = "SuperSonicEventAssets"
	notes = {}
	local built = EventKit.Insert(real, notes, false)
	local ownerRing
	if EventKit.RingKitPath() then
		assert(built and built:FindFirstChild("Ring") and #EventKit.Problems(built, manifest) == 0, "the owner's ring builds: " .. joined(notes))
		ownerRing = ("the owner's %s builds Meshes.Ring (import turn %d, from the %s)"):format(EventKit.RingKitPath(),
			built.Ring:GetAttribute("EventKitImportTurn"), built.Ring:GetAttribute("RingTurnSource"))
	else
		assert(EventKit.LoadRing() == nil and built == nil and #notes == 1 and #real:GetChildren() == 0, "no ring file: nothing, no ring note")
		ownerRing = "no RingKit.rbxm yet: no Ring, no note"
	end
	-- audit/u4_supersonic_assets (the build's step) puts the Ring in with the event templates.
	EventKit.SetOverride(EventKit.StandIn(manifest))
	EventKit.SetRingOverride(EventKit.RingStandIn(ringManifest))
	local Assets = require("./u4_supersonic_assets")
	notes = {}
	local folder = Assets.Build(notes)
	assert(folder.Meshes and #folder.Meshes:GetChildren() == 5 and folder.Meshes:FindFirstChild("Ring")
		and #EventKit.Problems(folder.Meshes, manifest) == 0, "u4_supersonic_assets.Build puts the Ring in: " .. joined(notes))
	local dm = Instance.new("DataModel")
	Assets.Insert(dm, {})
	Assets.Verify("memory", dm)
	EventKit.SetOverride(nil)
	EventKit.SetRingOverride(nil)
	pass("Insert with the ring: after the event kit's templates and notes (the event kit's attributes unchanged), the Ring's turn "
		.. "from the event kit's, a rebuild replaces it, someone else's Ring is kept; the ring alone works; without the ring kit "
		.. "nothing changes (no Ring, no note); " .. ownerRing .. "; u4_supersonic_assets.Build / Insert carry it")
end

print(("test_u4_event_kit: %d checks passed"):format(passed))
