-- test_u4_race_assets.luau (Update 4, race art, 2026-09-25)
-- The Blender race art pipeline (audit/generate_race_assets.py -> design/race -> Studio import ->
-- design/race/RaceAssets.rbxm -> build -> ServerStorage.RaceAssets -> RaceArenaBuilder):
--   1. files: one FBX (binary) and one preview PNG per model, the manifest, the Spanish guide;
--   2. naming: RaceArenaBuilder.AssetSpec (the block the generator writes) matches the manifest
--      object by object, every object name is a node of its FBX and nothing else is, every role
--      has a look in AssetRoles and a row in the guide; triangle budget; markers and colliders;
--   3. the builder with a fake RaceAssets folder (MeshParts at the size a meter-unit import gives,
--      3.57x): every model used, meshes resized to the spec, painted, inert, placed from the
--      spec; the contracts RaceGatePad / RaceGateSign / FlashSpot / StartGantry.Light1..5 /
--      StopBar / StartGate hold; 39 barrier tiles a side with no curbs; ConfettiSpot_1..4;
--      part budget; the result serializes (the build writes it into a place);
--   4. fallbacks: no folder (false, or nil outside Roblox) = today's part geometry (2026-09-26:
--      the gate is The Flash's part arch with or without the folder, FlashSpot always);
--      a model with a missing mesh or a wrong shape (axes swapped) falls back alone, with a
--      warning; importer suffixes (".001") still match, "Light_10" never stands in for "Light_1";
--   5. build_update4: the optional asset step (stamp, order, list note).
-- Run: lune run audit/test_u4_race_assets.luau   (from the project root; reads no place)
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local U4 = require("../src/common/ReplicatedStorage/Shared/Update4Config")
local RaceTrack = require("../src/common/ReplicatedStorage/Shared/RaceTrack")
local RaceArenaBuilder = require("../src/common/ServerScriptService/Services/Race/RaceArenaBuilder")

local Vector3, CFrame, Instance = roblox.Vector3, roblox.CFrame, roblox.Instance
local MODELS = RaceArenaBuilder.AssetModels
local TRACK = U4.Race.Track
local WORLDS = { "World1", "World2", "World3" }
local METER_IMPORT = 1 / 0.28 -- what a meters-to-studs import would give

local warnings = {}
local function makeEnv(assets)
	return {
		Instance = Instance, Vector3 = Vector3, CFrame = CFrame, Color3 = roblox.Color3,
		Enum = roblox.Enum, UDim2 = roblox.UDim2, NumberRange = roblox.NumberRange, Font = roblox.Font,
		ColorSequence = roblox.ColorSequence,
		RaceAssets = assets,
		Warn = function(text)
			table.insert(warnings, text)
		end,
	}
end

local passed = 0
local function pass(text)
	passed += 1
	print("PASS " .. text)
end

local function near(a, b, eps)
	return math.abs(a - b) <= (eps or 1e-3)
end

local function vecNear(v, t, eps)
	return near(v.X, t[1], eps) and near(v.Y, t[2], eps) and near(v.Z, t[3], eps)
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

----------------------------------------------------------------------
-- 1. Files
----------------------------------------------------------------------
local manifest
do
	for _, model in MODELS do
		local fbx = "design/race/fbx/" .. model .. ".fbx"
		local png = "design/race/preview/" .. model .. ".png"
		assert(fs.isFile(fbx), fbx .. " is missing (run audit/generate_race_assets.py in Blender)")
		assert(string.sub(fs.readFile(fbx), 1, 20) == "Kaydara FBX Binary  ", fbx .. " is a binary FBX")
		assert(fs.isFile(png), png .. " is missing")
		local image = fs.readFile(png)
		assert(string.sub(image, 1, 8) == "\137PNG\r\n\26\n" and #image > 20000, png .. " is a real render")
	end
	assert(fs.isFile("design/race/race_assets_manifest.json"), "the manifest")
	assert(fs.isFile("design/race/IMPORTAR_EN_STUDIO.md"), "the owner's guide")
	assert(fs.isFile("audit/generate_race_assets.py"), "the generator")
	manifest = serde.decode("json", fs.readFile("design/race/race_assets_manifest.json"))
	assert(manifest.roundtrip == "ok", "the generator's FBX round trip was clean")
	pass("4 binary FBX files, 4 preview renders, the manifest and the guide")
end

----------------------------------------------------------------------
-- 2. Naming table
----------------------------------------------------------------------
do
	local guide = fs.readFile("design/race/IMPORTAR_EN_STUDIO.md")
	local total = 0
	for role, look in RaceArenaBuilder.AssetRoles do
		local row = manifest.roles[role]
		assert(row, "role " .. role .. " is in the manifest")
		assert(row.material == look.Material and roblox.Enum.Material[look.Material], role .. ": a real Roblox material")
		for i = 1, 3 do
			assert(row.color[i] == look.Color[i], role .. ": colour matches the manifest")
		end
		assert(string.find(guide, "`" .. role .. "`", 1, true), "the guide's table has the role " .. role)
	end
	for role in manifest.roles do
		assert(RaceArenaBuilder.AssetRoles[role], "AssetRoles covers " .. role)
	end
	for _, model in MODELS do
		local spec = RaceArenaBuilder.AssetSpec[model]
		local info = manifest.models[model]
		assert(spec and info, model .. " in both the spec and the manifest")
		assert(#spec.Parts == #info.parts and #spec.Parts > 0, model .. ": same object count")
		assert(spec.Triangles == info.triangles, model .. ": triangle count")
		total += info.triangles
		local names = {}
		for index, part in spec.Parts do
			local row = info.parts[index]
			assert(part.Name == row.name and part.Role == row.role, model .. ": object " .. index .. " name / role")
			for i = 1, 3 do
				assert(near(part.Center[i], row.center[i], 0.0015) and near(part.Size[i], row.size[i], 0.0015), part.Name .. ": box")
			end
			local suffix = string.match(part.Name, "^" .. model .. "__(.+)$")
			assert(suffix, part.Name .. " is <Model>__<Role>")
			assert(suffix == part.Role or (part.Role == "Light" and string.match(suffix, "^Light_%d$")), part.Name .. ": the role is its suffix")
			assert(RaceArenaBuilder.AssetRoles[part.Role], part.Name .. ": the role has a look")
			names[part.Name] = true
		end
		-- The FBX's model nodes are exactly the spec's objects (no empties, no strays).
		local data = fs.readFile("design/race/fbx/" .. model .. ".fbx")
		local found = {}
		for name in string.gmatch(data, "(Race%a+__[%w_]+)\0\1Model") do
			assert(names[name], model .. ".fbx has an object the spec does not know: " .. name)
			found[name] = true
		end
		for name in names do
			assert(found[name], name .. " is a node of " .. model .. ".fbx")
		end
		assert(string.find(guide, model, 1, true), "the guide names " .. model)
	end
	assert(total >= 8000 and total <= 12000 and total == manifest.total_triangles, "8,000-12,000 triangles in all (" .. total .. ")")
	-- Markers and colliders the builder needs.
	local booth = RaceArenaBuilder.AssetSpec.RaceLobbyBooth
	for _, name in { "FlashSpot", "SignAnchor", "PadTrigger" } do
		assert(booth.Markers[name], "booth marker " .. name)
	end
	assert(vecNear(Vector3.new(0, 0.2, 0), booth.Markers.PadTrigger.Center) and booth.Markers.PadTrigger.Size[1] == RaceArenaBuilder.GatePadSize,
		"the booth's pad trigger marker is the RaceGatePad box")
	local cylinders, boxes = 0, 0
	for _, collider in booth.Colliders do
		if collider.Shape == "Cylinder" then
			cylinders += 1
			assert(collider.Radius > 0 and collider.Height > 0, collider.Name)
		else
			boxes += 1
			assert(#collider.Size == 3, collider.Name)
		end
	end
	assert(cylinders >= 4 and boxes >= 3, "booth colliders: podium/kiosk cylinders, pillar/counter boxes")
	for index = 1, 4 do
		assert(RaceArenaBuilder.AssetSpec.RaceFinishGantry.Markers["ConfettiSpot_" .. index], "ConfettiSpot_" .. index)
	end
	local barrier = RaceArenaBuilder.AssetSpec.RaceTrackBarrier
	local span = RaceArenaBuilder.EndWallS - RaceArenaBuilder.StartS
	assert(near(span / barrier.Size[3], math.floor(span / barrier.Size[3] + 0.5)), "barrier tiles fill -64..2120 exactly")
	assert(near(barrier.Size[1] * 0.5, RaceArenaBuilder.BarrierX - 36, 0.01), "the barrier footing reaches the floor edge (x 36)")
	for _, part in barrier.Parts do
		if part.Role == "Base" then
			assert(near(RaceArenaBuilder.BarrierX - part.Size[1] * 0.5, RaceArenaBuilder.WallX - 0.5, 0.01), "the barrier body's face is the invisible wall's face")
		end
	end
	pass(string.format("AssetSpec = manifest (%d objects), FBX nodes = spec names, roles painted and in the guide; %d triangles; markers, colliders, barrier fit",
		#booth.Parts + #RaceArenaBuilder.AssetSpec.RaceStartGantry.Parts + #RaceArenaBuilder.AssetSpec.RaceFinishGantry.Parts + #barrier.Parts, total))
end

----------------------------------------------------------------------
-- 3. The builder with a fake RaceAssets folder
----------------------------------------------------------------------
-- MeshParts as the Studio importer leaves them: one Model per FBX, each mesh at the size of
-- the import's unit (`scale`), somewhere in the world, with a SurfaceAppearance.
local function fakeAssets(options)
	local opts = options or {}
	local scale = opts.scale or METER_IMPORT
	local folder = Instance.new("Folder")
	folder.Name = "RaceAssets"
	for _, model in MODELS do
		local holder = Instance.new("Model")
		holder.Name = model
		holder.Parent = folder
		for _, p in RaceArenaBuilder.AssetSpec[model].Parts do
			if not (opts.omit and opts.omit[p.Name]) then
				local mesh = Instance.new("MeshPart")
				mesh.Name = (opts.rename and opts.rename[p.Name]) or p.Name
				local size = { p.Size[1] * scale, p.Size[2] * scale, p.Size[3] * scale }
				if opts.swap and opts.swap[p.Name] then
					size[2], size[3] = size[3], size[2]
				end
				mesh.Size = Vector3.new(size[1], size[2], size[3])
				mesh.CFrame = CFrame.new(120 + p.Center[1] * scale, 40 + p.Center[2] * scale, -300 + p.Center[3] * scale)
				mesh.Color = roblox.Color3.fromRGB(163, 162, 165)
				local look = Instance.new("SurfaceAppearance")
				look.Parent = mesh
				mesh.Parent = holder
			end
		end
	end
	return folder
end

local function specPart(model, name)
	for _, p in RaceArenaBuilder.AssetSpec[model].Parts do
		if p.Name == name then
			return p
		end
	end
	error("no spec part " .. name)
end

local function checkMesh(part, model)
	assert(part:IsA("MeshPart"), part:GetFullName() .. " is a clone of the imported MeshPart")
	assert(part.Anchored and not part.CastShadow and not part.CanCollide and not part.CanTouch and not part.CanQuery,
		part:GetFullName() .. ": anchored, no shadow, inert")
	assert(part:GetAttribute("RaceArenaPart") == true and part:GetAttribute("RaceAsset") == model, part:GetFullName() .. ": attributes")
	assert(part:FindFirstChildOfClass("SurfaceAppearance") == nil, part:GetFullName() .. ": importer extras stripped")
end

warnings = {}
local assets = fakeAssets()
local arena = RaceArenaBuilder.Build(Instance.new("Folder"), makeEnv(assets))
do
	assert(#warnings == 0, "a complete folder gives no warning: " .. tostring(warnings[1]))
	assert(arena:GetAttribute("RaceArenaAssets") == "RaceStartGantry,RaceFinishGantry,RaceTrackBarrier", "every arena model uses its meshes")
	local parts = baseParts(arena)
	assert(#parts <= RaceArenaBuilder.BudgetWithAssets and arena:GetAttribute("RaceArenaParts") == #parts,
		"part budget with the meshes (" .. #parts .. " <= " .. RaceArenaBuilder.BudgetWithAssets .. ")")
	local structure, decor = arena.Structure, arena.Decor
	for _, part in parts do
		assert(part.Anchored and not part.CastShadow and part:GetAttribute("RaceArenaPart") == true, "anchored, no shadow: " .. part:GetFullName())
		if part:IsDescendantOf(decor) then
			assert(not part.CanCollide and not part.CanTouch and not part.CanQuery, "decor inert: " .. part:GetFullName())
		end
		if part:IsA("MeshPart") then
			checkMesh(part, part:GetAttribute("RaceAsset"))
			local s, x, y = RaceTrack.ToLocal(part.CFrame.Position)
			assert(math.abs(x) <= 44 and s >= -70 and s <= RaceArenaBuilder.EndWallS + 5 and y >= -3 and y <= 60, "inside the arena box: " .. part:GetFullName())
		end
	end

	-- Start gantry: the spheres are Light1..5 (the RaceArenaVisuals contract), resized, painted.
	local gantry = structure.StartGantry
	assert(gantry:FindFirstChild("Beam") == nil and gantry:FindFirstChild("PostL") == nil, "no part gantry left")
	local origin = CFrame.new(RaceTrack.ToWorld(RaceArenaBuilder.StartGantryS, 0, 0))
	for light = 1, 5 do
		local part = gantry:FindFirstChild("Light" .. light)
		assert(part, "StartGantry.Light" .. light)
		checkMesh(part, "RaceStartGantry")
		local spec = specPart("RaceStartGantry", "RaceStartGantry__Light_" .. light)
		assert(vecNear(part.Size, spec.Size), "Light" .. light .. " resized to the spec (not the import's 3.57x)")
		local want = (origin * CFrame.new(spec.Center[1], spec.Center[2], spec.Center[3])).Position
		assert((part.CFrame.Position - want).Magnitude < 0.02, "Light" .. light .. " where the spec puts it")
		assert(part.Material == roblox.Enum.Material.Neon and part.Color == roblox.Color3.fromRGB(60, 18, 18), "Light" .. light .. " starts off (neon, dark red)")
		local s = RaceTrack.ToLocal(part.CFrame.Position)
		assert(s < 0 and s > -8, "the lights face the grid from just behind the start line")
	end
	if gantry:FindFirstChild("Light6") then
		error("only five lights")
	end
	local panel = gantry:FindFirstChild("RaceStartGantry__Panel")
	local gui = panel and panel:FindFirstChild("PanelGui")
	assert(gui and gui.Face == roblox.Enum.NormalId.Back and gui:FindFirstChild("Title") and gui:FindFirstChild("Status"), "the timer panel's Title/Status face the racers")
	assert(structure:FindFirstChild("StopBar") and structure:FindFirstChild("StartGate") and structure:FindFirstChild("BackWall"), "StopBar / StartGate / walls unchanged")
	for _, name in { "WallL_1", "WallR_1" } do
		local wall = structure:FindFirstChild(name)
		local _, wx = RaceTrack.ToLocal(wall.CFrame.Position)
		assert(wall.Transparency == 1 and wall.CanCollide and near(math.abs(wx), RaceArenaBuilder.WallX, 0.01), "invisible side walls unchanged: " .. name)
	end

	-- Barriers: 39 tiles a side, continuous from the back wall to the end wall, no curbs.
	local length = RaceArenaBuilder.AssetSpec.RaceTrackBarrier.Size[3]
	local tiles = { [-1] = {}, [1] = {} }
	local barrierParts, curbs = 0, 0
	for _, part in baseParts(decor) do
		if part:GetAttribute("RaceAsset") == "RaceTrackBarrier" then
			barrierParts += 1
			if part.Name == "RaceTrackBarrier__Base" then
				local s, x = RaceTrack.ToLocal(part.CFrame.Position)
				local spec = specPart("RaceTrackBarrier", "RaceTrackBarrier__Base")
				local side = if x < 0 then -1 else 1
				assert(near(x - side * RaceArenaBuilder.BarrierX, spec.Center[1], 0.01), "barrier at x +-38.7")
				table.insert(tiles[side], s + spec.Center[3])
				-- in the chunk of its middle (streamed with it)
				local chunk = part.Parent
				assert(chunk.Name == "Chunk_" .. RaceArenaBuilder.ChunkIndex(s + spec.Center[3]), "barrier tile in the chunk of its middle")
			end
		elseif part.Name == "Curb" or part.Name == "CurbGlow" then
			curbs += 1
		end
	end
	local perSide = #RaceArenaBuilder.BarrierTiles(length)
	assert(perSide == 39, "39 tiles of 56 studs a side")
	assert(barrierParts == 2 * perSide * #RaceArenaBuilder.AssetSpec.RaceTrackBarrier.Parts and curbs == 0, "barrier tiles replace the curbs")
	for side, list in tiles do
		table.sort(list)
		assert(#list == perSide, "tiles on side " .. side)
		assert(near(list[1] - length * 0.5, RaceArenaBuilder.StartS, 0.01) and near(list[#list] + length * 0.5, RaceArenaBuilder.EndWallS, 0.01), "barrier from -64 to 2120")
		for i = 2, #list do
			assert(near(list[i] - list[i - 1], length, 0.01), "barrier tiles meet end to end")
		end
	end

	-- Distance gantries: the start gantry without lights or rings, text on its panel.
	for _, name in { "Gantry_500", "Gantry_1000", "Gantry_1500", "LastStretch" } do
		local model = decor:FindFirstChild(name, true)
		assert(model and model:IsA("Model"), name)
		assert(model:FindFirstChild("Beam") == nil, name .. ": no part beam")
		for _, part in baseParts(model) do
			assert(part:GetAttribute("RaceAsset") == "RaceStartGantry", name .. ": meshes")
			local role = string.match(part.Name, "__(.+)$")
			assert(role ~= "Gold" and not string.match(role, "^Light"), name .. ": no lights or gold rings")
		end
		local label = model.RaceStartGantry__Panel:FindFirstChild("LabelBack")
		assert(label and label.Face == roblox.Enum.NormalId.Back, name .. ": text faces the racers")
	end

	-- Finish: meshes, FINISH panel, confetti spots.
	local finish = decor:FindFirstChild("FinishGate", true)
	assert(finish and finish:GetAttribute("RaceAsset") == "RaceFinishGantry" and finish:FindFirstChild("Beam") == nil, "FinishGate from the meshes")
	local header = finish.RaceFinishGantry__Base
	local finishOrigin = CFrame.new(RaceTrack.ToWorld(TRACK.Length, 0, 0))
	for index = 1, 4 do
		local spot = header:FindFirstChild("ConfettiSpot_" .. index)
		assert(spot and spot:IsA("Attachment"), "ConfettiSpot_" .. index)
		local marker = RaceArenaBuilder.AssetSpec.RaceFinishGantry.Markers["ConfettiSpot_" .. index]
		local world = (header.CFrame * spot.CFrame).Position
		local want = (finishOrigin * CFrame.new(marker[1], marker[2], marker[3])).Position
		assert((world - want).Magnitude < 0.02, "ConfettiSpot_" .. index .. " where the spec puts it")
		local emitter = spot:FindFirstChild("Confetti")
		assert(emitter and emitter:IsA("ParticleEmitter") and emitter.Rate == 0, "a Rate-0 Confetti emitter (Emit on demand)")
	end
	assert(finish.RaceFinishGantry__Panel:FindFirstChild("LabelBack"), "FINISH on its panel")
	local names = {}
	for _, d in decor:GetDescendants() do
		names[d.Name] = true
	end
	assert(names.FinishLine and names.Checker, "the checkered floor line stays")

	-- It serializes (what the build writes into a place).
	local ok, err = pcall(roblox.serializeModel, { arena })
	assert(ok, "the arena with meshes serializes: " .. tostring(err))
	pass(string.format("arena with meshes: %d parts; Light1..5 resized/painted/placed; %d barrier tiles a side, no curbs; gantries, FINISH, confetti; serializes",
		#parts, perSide))
end

do
	-- 2026-09-26 (owner): the gate is The Flash's part-built arch; a complete RaceAssets folder
	-- (booth included) changes nothing about it (audit/test_u4_flash_gate checks the arch itself).
	for _, world in WORLDS do
		warnings = {}
		local gate = RaceArenaBuilder.BuildGate(Instance.new("Folder"), world, makeEnv(assets))
		assert(#warnings == 0, world .. ": no warning")
		assert(gate:GetAttribute("RaceGateAssets") == false, world .. ": the booth meshes are not used")
		local base = RaceArenaBuilder.GateCFrame(world, makeEnv(nil))
		local pad = gate:FindFirstChild("RaceGatePad")
		assert(pad and vecNear(pad.Size, { 12, 0.4, 12 }) and pad.Transparency == 1 and not pad.CanCollide, world .. ": RaceGatePad, invisible, 12x12")
		assert((pad.CFrame.Position - (base * CFrame.new(0, 0.2, 0)).Position).Magnitude < 0.02, world .. ": RaceGatePad where it always was")
		assert(pad:GetAttribute("PadTriggerHeight") == 10, world .. ": trigger height")
		local sign = gate:FindFirstChild("RaceGateSign")
		assert(sign and sign:IsA("BillboardGui") and sign:FindFirstChild("Title") and sign:FindFirstChild("Status") and sign:FindFirstChild("Record"), world .. ": RaceGateSign lines")
		local flash = gate:FindFirstChild("FlashSpot")
		assert(flash and flash:GetAttribute("FlashSpot") == true and flash.Transparency == 1 and not flash.CanCollide and not flash.CanQuery, world .. ": FlashSpot")
		for _, part in baseParts(gate) do
			assert(part.Anchored and not part.CastShadow and not part:IsA("MeshPart"), world .. ": anchored parts, no shadow, no meshes")
		end
		assert(gate:FindFirstChild("RaceLobbyBooth__Panel") == nil, world .. ": no booth pieces")
		local ok, err = pcall(roblox.serializeModel, { gate })
		assert(ok, world .. ": the gate serializes: " .. tostring(err))
	end
	pass("3 gates with a complete RaceAssets folder: still The Flash's part arch (no booth meshes), RaceGatePad / RaceGateSign / FlashSpot")
end

----------------------------------------------------------------------
-- 4. Fallbacks
----------------------------------------------------------------------
do
	for _, mode in { false, "nil" } do
		warnings = {}
		local env = makeEnv(if mode == "nil" then nil else false)
		local plain = RaceArenaBuilder.Build(Instance.new("Folder"), env)
		assert(plain:GetAttribute("RaceArenaAssets") == "", "no meshes without RaceAssets")
		local gantry = plain.Structure.StartGantry
		assert(gantry:FindFirstChild("Beam") and gantry:FindFirstChild("Light3") and gantry.Light3.ClassName == "Part", "part gantry with Light1..5")
		assert(plain.Decor:FindFirstChild("Curb", true), "curbs without the barrier meshes")
		local finish = plain.Decor:FindFirstChild("FinishGate", true)
		assert(finish.Beam:FindFirstChild("ConfettiSpot_1"), "confetti spots on the part finish too")
		assert(#baseParts(plain) <= RaceArenaBuilder.BudgetWithParts, "fallback budget")
		for _, world in WORLDS do
			local gate = RaceArenaBuilder.BuildGate(Instance.new("Folder"), world, env)
			-- 2026-09-26: The Flash's arch (the 09-25 pillars and lintel are gone), FlashSpot always.
			assert(gate:GetAttribute("RaceGateAssets") == false and gate:FindFirstChild("Arch") and gate:FindFirstChild("Lintel") == nil, world .. ": the part gate")
			assert(gate:FindFirstChild("FlashSpot") ~= nil, world .. ": FlashSpot beside the arch")
			assert(gate.RaceGateSign.Adornee == gate.SignAnchor, world .. ": the sign over the medallion")
		end
		assert(#warnings == 0, "no folder is quiet")
	end

	-- One model broken: only it falls back, with a warning.
	warnings = {}
	local partial = RaceArenaBuilder.Build(Instance.new("Folder"), makeEnv(fakeAssets({ omit = { RaceTrackBarrier__Accent = true } })))
	assert(partial:GetAttribute("RaceArenaAssets") == "RaceStartGantry,RaceFinishGantry", "the barrier alone falls back")
	assert(partial.Decor:FindFirstChild("Curb", true) and partial.Structure.StartGantry:FindFirstChild("RaceStartGantry__Base"), "curbs back, gantry meshes kept")
	assert(#warnings == 1 and string.find(warnings[1], "RaceTrackBarrier__Accent is missing", 1, true), "one warning names the missing mesh")

	warnings = {}
	local swapped = RaceArenaBuilder.Build(Instance.new("Folder"), makeEnv(fakeAssets({ swap = { RaceStartGantry__Base = true } })))
	assert(swapped:GetAttribute("RaceArenaAssets") == "RaceFinishGantry,RaceTrackBarrier", "a wrong-shaped gantry falls back")
	assert(swapped.Structure.StartGantry:FindFirstChild("Beam") and swapped.Decor:FindFirstChild("Gantry_500", true):FindFirstChild("Beam"), "part start and distance gantries")
	assert(#warnings == 1 and string.find(warnings[1], "wrong shape", 1, true), "the warning says wrong shape")

	-- Importer suffixes still match; Light_10 never stands in for Light_1.
	warnings = {}
	local suffixed = RaceArenaBuilder.Build(Instance.new("Folder"), makeEnv(fakeAssets({ rename = { RaceFinishGantry__Base = "RaceFinishGantry__Base.001" } })))
	assert(string.find(suffixed:GetAttribute("RaceArenaAssets"), "RaceFinishGantry", 1, true), "a '.001' suffix still matches")
	assert(suffixed.Decor:FindFirstChild("FinishGate", true):FindFirstChild("RaceFinishGantry__Base"), "renamed back to the spec name")
	warnings = {}
	local tenth = RaceArenaBuilder.Build(Instance.new("Folder"), makeEnv(fakeAssets({ rename = { RaceStartGantry__Light_1 = "RaceStartGantry__Light_10" } })))
	assert(not string.find(tenth:GetAttribute("RaceArenaAssets"), "RaceStartGantry", 1, true), "Light_10 is not Light_1")

	-- A broken booth: the gate never looks at it (2026-09-26), so no warning either.
	warnings = {}
	local gate = RaceArenaBuilder.BuildGate(Instance.new("Folder"), "World1", makeEnv(fakeAssets({ omit = { RaceLobbyBooth__Red = true } })))
	assert(gate:GetAttribute("RaceGateAssets") == false and gate:FindFirstChild("Arch") and #warnings == 0, "a broken booth changes nothing")

	-- AssetScale: uniform scale accepted, anything else refused.
	assert(near(RaceArenaBuilder.AssetScale(Vector3.new(10, 20, 30), { 1, 2, 3 }), 10), "uniform x10")
	assert(near(RaceArenaBuilder.AssetScale(Vector3.new(1, 2, 3), { 1, 2, 3 }), 1), "1:1")
	assert(RaceArenaBuilder.AssetScale(Vector3.new(1, 3, 2), { 1, 2, 3 }) == nil, "axes swapped")
	assert(RaceArenaBuilder.AssetScale(Vector3.new(1.2, 2, 3), { 1, 2, 3 }) == nil, "stretched")
	pass("fallbacks: none (false / nil) = part geometry; a missing or wrong-shaped mesh drops only its model, with one warning; suffix matching")
end

----------------------------------------------------------------------
-- 5. build_update4's optional asset step
----------------------------------------------------------------------
do
	local build = fs.readFile("audit/build_update4.luau")
	for _, needle in {
		'local DESIGN_RACE_ASSETS = "design/race/RaceAssets.rbxm"',
		'clearStamped(serverStorage, "RaceAssets", "RaceAssets")',
		'copy:SetAttribute("U4Asset", "RaceAssets")',
		"insertRaceAssets(dm, notes)\n\tinsertRace(dm, key, notes)",
		'ENV.RaceAssets = dm:GetService("ServerStorage"):FindFirstChild("RaceAssets") or false',
		"RaceArenaBuilder.Build(workspace, ENV)",
		"RaceArenaBuilder.BuildGate(workspace, key, ENV)",
		"LuaSourceContainer",
	} do
		assert(string.find(build, needle, 1, true), "build_update4: " .. needle)
	end
	local result = process.exec("lune", { "run", "audit/build_update4.luau", "list" })
	assert(result.ok, "build_update4 list: " .. tostring(result.stderr))
	assert(string.find(result.stdout, "race art: ", 1, true), "`list` reports the race art step")
	if not fs.isFile("design/race/RaceAssets.rbxm") then
		assert(string.find(result.stdout, "keep their part geometry", 1, true), "no rbxm: the note says the part geometry stays")
	end
	pass("build_update4: optional RaceAssets.rbxm -> ServerStorage.RaceAssets (U4Asset stamp, no scripts) before the arena/gate; `list` note")
end

print(string.format("test_u4_race_assets: %d checks passed", passed))
