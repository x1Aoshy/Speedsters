-- audit/u4_event_kit.luau  (Update 4, 2026-09-26, owner: the "Super Sonic vs Dr. Eggman" live event's meshes)
-- The Blender kit of audit/event_kit_bpy.py (design/event/supersonic/: EventKit.fbx, event_manifest.json) once
-- the owner has imported it with Studio's File > Import 3D and saved it as design/event/supersonic/EventKit.rbxm
-- (IMPORTAR_EVENTO.md). audit/u4_supersonic_assets (the build's SuperSonicEventAssets step) calls Insert; the
-- event's code falls back to simple shapes for any asset that is not there.
--   Insert(assetsFolder, notes, kit?)  fills assetsFolder.Meshes (made when missing) with one ready template per
--                                      asset and returns that folder; nil (and a note) when there is no kit file
--                                      or nothing fits. kit: nil = the file (Load), false = none (tests), or a root.
--   Build(root, manifest)              (meshesFolder | nil, report): the templates from any root of EV_* MeshParts
--   Load()                             the saved kit as one root (nil: no file); no scripts allowed; read once
--   SetOverride(root | false | nil)    the tests' stand-in instead of the file (nil = back to the file)
--   Manifest()                         design/event/supersonic/event_manifest.json
--   StandIn(manifest, options)         what Studio's importer makes of EventKit.fbx, from the manifest (tests)
--   Problems(meshes, manifest)         what is wrong with a built Meshes folder (an empty list: nothing)
-- The templates (every one's pivot on its asset's origin, placed at the world origin):
--   Meshes.Bomb          Model: EV_Bomb (PrimaryPart, anchored) + EV_BombStripe / EV_BombFins / EV_BombNose welded
--                        (unanchored, massless). Stands NOSE-DOWN: nose -Y, tail +Y (attribute NoseAxis "-Y");
--                        Attachments Nose / Fuse (their -Z = LookVector points out of the nose / the fuse).
--   Meshes.ChaosEmerald  MeshPart (1.6 x 1.5 x 1.6, flat facets); attributes Color<Name> for the 7 emeralds,
--                        VariantOrder; Attachment Center.
--   Meshes.SpinBall      MeshPart (6.1 across, an inner shell too); RootOffset (an R6 HumanoidRootPart at
--                        centre * CFrame.new(RootOffset) fits inside), ColorBlue / ColorGold; Attachments Center, Root.
--   Meshes.Cannon        Model: EV_Cannon (the barrel, PrimaryPart) + EV_CannonMetal / EV_CannonDark /
--                        EV_CannonStripe / EV_CannonGlow (Neon) welded. Its pivot is the MOUNT point on the Egg
--                        Mobile's bowl, axes = the ship's: cannon:PivotTo(eggFloor * CFrame.new(MountShip)) (or
--                        EggHull.CFrame * CFrame.new(MountHull)), no rotation (the barrel already points 20 degrees
--                        down); Attachments Mount, Muzzle and Spawn (a bomb's centre there, nose along the
--                        Muzzle's LookVector, clears the barrel). Scale the Model with the ship (Model:ScaleTo).
-- Every part: CanCollide / CanTouch / CanQuery false, colour / material / reflectance / transparency / CastShadow
-- from the manifest, RenderFidelity Precise (or the manifest's renderFidelity), CollisionFidelity Box.
--
-- The gold ring (2026-09-26): a SEPARATE mini kit, audit/ring_kit_bpy.py (design/event/supersonic/ring/:
-- RingKit.fbx, ring_manifest.json, IMPORTAR_ANILLO.md), imported on its own and saved as Update2/RingKit.rbxm (or
-- design/event/supersonic/ring/RingKit.rbxm); EventKit.rbxm and its manifest are never touched. When that file
-- is there, Insert also puts in
--   Meshes.Ring          MeshPart (EV_Ring): a smooth polished gold torus, 2.4 across, a 0.6 tube, a 1.2 hole,
--                        standing upright with its hole facing +-Z, its pivot on its centre (spin it about Y);
--                        anchored, no collision / touch / query, gold SmoothPlastic + Reflectance from the ring
--                        manifest, RenderFidelity Automatic; attributes OuterDiameter, InnerDiameter, TubeDiameter,
--                        HoleAxis "Z", SpinAxis "Y", ColorGold, ColorSparkle, EventKitImportTurn, RingTurnSource.
-- Without it nothing changes (no Ring, no note: the client keeps its fallback ring). The ring is centred on its
-- pivot, so its PivotOffset shows no import turn: RingTurn reads it from the size (X and Z swap on a quarter
-- turn); a half turn leaves the torus unchanged, so an even turn follows the event kit's (the same importer) or
-- RingDefaultTurn.
--   BuildRing(root, manifest, hintTurn?)  (Ring MeshPart | nil, report)      LoadRing() / SetRingOverride(root|false|nil)
--   RingManifest()   RingKitPath()   RingTurn(part, spec, hintTurn?)   RingStandIn(manifest, options) (tests)
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local MeshKitImport = require("../src/common/ReplicatedStorage/Shared/MeshKitImport")
local KitImport = require("./kit_import")

local CFrame, Vector3, Instance, Color3, Enum = roblox.CFrame, roblox.Vector3, roblox.Instance, roblox.Color3, roblox.Enum

local M = {}
M.KitFile = "design/event/supersonic/EventKit.rbxm"
M.KitFileAlternates = { "EventKit.rbxm" } -- also accepted: saved straight into the Update2 folder
M.ManifestFile = "design/event/supersonic/event_manifest.json"
M.KitVersion = 1 -- the manifest kitVersion this loader reads
M.FolderName = "Meshes"
M.Stamp = "SuperSonicEventMeshes" -- each template's U4Asset attribute
M.PiecePrefix = "EV_"
M.AssetNames = { "Bomb", "ChaosEmerald", "SpinBall", "Cannon" }
M.WeldName = "EventKitWeld"
-- The gold ring's mini kit (audit/ring_kit_bpy.py).
M.RingKitFile = "design/event/supersonic/ring/RingKit.rbxm"
M.RingKitFileAlternates = { "RingKit.rbxm" } -- also accepted: saved straight into the Update2 folder (the guide's)
M.RingManifestFile = "design/event/supersonic/ring/ring_manifest.json"
M.RingKitVersion = 1 -- the ring manifest kitVersion this loader reads
M.RingName = "Ring" -- Meshes.Ring
M.RingPiece = "EV_Ring"
M.RingDefaultTurn = 2 -- Studio's Import 3D turned every kit so far 180 degrees about Y

local cache = nil -- nil: not read yet; false: no file
local override = nil
local ringCache = nil
local ringOverride = nil

function M.SetOverride(kit)
	override = kit
	cache = nil
end

-- The tests' stand-in ring kit instead of the file (false = none, nil = back to the file).
function M.SetRingOverride(kit)
	ringOverride = kit
	ringCache = nil
end

-- The saved kit's path (nil: none).
function M.KitPath(): string?
	if fs.isFile(M.KitFile) then
		return M.KitFile
	end
	for _, path in M.KitFileAlternates do
		if fs.isFile(path) then
			return path
		end
	end
	return nil
end

-- Every script under root (root included), as full names.
function M.Scripts(root): { string }
	local found = {}
	local function check(d)
		if d:IsA("LuaSourceContainer") then
			table.insert(found, d:GetFullName())
		end
	end
	check(root)
	for _, d in root:GetDescendants() do
		check(d)
	end
	return found
end

-- A saved kit (.rbxm) as one root named rootName; no scripts allowed.
local function readKit(path: string, rootName: string)
	local roots = roblox.deserializeModel(fs.readFile(path))
	local root
	if #roots == 1 and (roots[1].ClassName == "Folder" or roots[1].ClassName == "Model") then
		root = roots[1]
	else
		root = Instance.new("Folder")
		for _, r in roots do
			r.Parent = root
		end
	end
	root.Name = rootName
	local scripts = M.Scripts(root)
	assert(#scripts == 0, path .. " carries a script (" .. table.concat(scripts, ", ") .. "); remove it and save again")
	return root
end

function M.Load()
	if override ~= nil then
		return override or nil
	end
	if cache == nil then
		cache = false
		local path = M.KitPath()
		if path then
			cache = readKit(path, "EventKit")
		end
	end
	return cache or nil
end

-- The saved ring kit's path (nil: none).
function M.RingKitPath(): string?
	if fs.isFile(M.RingKitFile) then
		return M.RingKitFile
	end
	for _, path in M.RingKitFileAlternates do
		if fs.isFile(path) then
			return path
		end
	end
	return nil
end

-- The saved ring kit as one root (nil: no file); read once.
function M.LoadRing()
	if ringOverride ~= nil then
		return ringOverride or nil
	end
	if ringCache == nil then
		ringCache = false
		local path = M.RingKitPath()
		if path then
			ringCache = readKit(path, "RingKit")
		end
	end
	return ringCache or nil
end

local function readManifest(file: string, version: number, generator: string, what: string)
	assert(fs.isFile(file), file .. " is missing (run " .. generator .. " in Blender)")
	local ok, data = pcall(serde.decode, "json", fs.readFile(file))
	assert(ok and type(data) == "table" and type(data.pieces) == "table" and type(data.assets) == "table",
		file .. " is not the " .. what .. "'s manifest: " .. tostring(data))
	assert(data.kitVersion == version, ("%s is kit v%s but audit/u4_event_kit reads v%d"):format(file,
		tostring(data.kitVersion), version))
	return data
end

function M.Manifest()
	return readManifest(M.ManifestFile, M.KitVersion, "audit/event_kit_bpy.py", "event kit")
end

-- design/event/supersonic/ring/ring_manifest.json (one piece, EV_Ring, and assets.Ring).
function M.RingManifest()
	local data = readManifest(M.RingManifestFile, M.RingKitVersion, "audit/ring_kit_bpy.py", "ring kit")
	assert(data.assets[M.RingName] and #data.pieces == 1 and data.pieces[1].name == M.RingPiece,
		M.RingManifestFile .. ": one piece " .. M.RingPiece .. " of assets." .. M.RingName)
	return data
end

local function v3(list)
	return Vector3.new(list[1], list[2], list[3])
end

-- A CFrame at `position` whose LookVector is `direction` (CFrame.lookAt is wrong in Lune).
local function lookAlong(position, direction)
	local dir = direction.Unit
	local hint = if math.abs(dir.Y) > 0.99 then Vector3.new(0, 0, -1) else Vector3.new(0, 1, 0)
	local right = dir:Cross(hint).Unit
	local up = right:Cross(dir).Unit
	return CFrame.fromMatrix(position, right, up, -dir)
end
M.LookAlong = lookAlong

-- The manifest's pieces as MeshKitImport specs, by name.
function M.Specs(manifest)
	local specs = {}
	for _, piece in manifest.pieces do
		specs[piece.name] = {
			Name = piece.name, Asset = piece.asset, Role = piece.role, Primary = piece.primary == true,
			Size = piece.size, Offset = piece.bboxCenterOffset, Color = piece.color, Material = piece.material,
			Reflectance = piece.reflectance or 0, Transparency = piece.transparency or 0, CastShadow = piece.castShadow == true,
			RenderFidelity = piece.renderFidelity,
		}
	end
	return specs
end

local function setAttributes(target, attributes)
	for key, value in attributes do
		target:SetAttribute(key, value)
	end
end

-- The asset-specific attributes (the manifest's numbers, readable without it).
local function assetAttributes(name, asset)
	local out = {}
	if name == "Bomb" then
		out.NoseAxis = asset.noseAxis
		out.Length = asset.length
		out.Diameter = asset.diameter
	elseif name == "ChaosEmerald" then
		for key, rgb in asset.variants or {} do
			out["Color" .. key] = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
		end
		out.VariantOrder = table.concat(asset.variantOrder or {}, ",")
		out.Height = asset.height
		out.Diameter = asset.diameter
	elseif name == "SpinBall" then
		for key, rgb in asset.colors or {} do
			out["Color" .. key] = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
		end
		out.RootOffset = v3(asset.rootOffset)
		out.OuterRadius = asset.outerRadius
		out.InnerRadius = asset.innerRadius
	elseif name == "Cannon" then
		out.MountShip = v3(asset.mount.ship)
		out.MountHull = v3(asset.mount.hull)
		out.MuzzleLocal = v3(asset.muzzle["local"])
		out.MuzzleHull = v3(asset.muzzle.hull)
		out.MuzzleDirection = v3(asset.muzzle.direction)
		out.SpawnLocal = v3(asset.muzzle.spawnLocal)
		out.SpawnHull = v3(asset.muzzle.spawnHull)
		out.BoreRadius = asset.muzzle.boreRadius
		out.PitchDegrees = asset.pitchDegrees
	elseif name == M.RingName then
		out.OuterDiameter = asset.outerDiameter
		out.InnerDiameter = asset.innerDiameter
		out.TubeDiameter = asset.tubeDiameter
		out.HoleAxis = asset.holeAxis
		out.SpinAxis = asset.spinAxis
		for key, rgb in asset.colors or {} do
			out["Color" .. key] = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
		end
	end
	return out
end

-- One template (MeshPart or Model) from the kit's parts; `origin` is where its pivot goes.
local function buildAsset(name, asset, specs, parts, turn, origin, version)
	local pieces = {}
	local primary
	for _, pieceName in asset.pieces do
		local spec = specs[pieceName]
		local clone = parts[pieceName]:Clone()
		for _, child in clone:GetChildren() do
			child.Parent = nil -- a SurfaceAppearance or anything else the importer added
		end
		local cf, size = MeshKitImport.Placement(origin, spec, turn, CFrame, Vector3)
		clone.Name = pieceName
		clone.Size = size
		clone.CFrame = cf
		clone.PivotOffset = cf:Inverse() * origin -- every piece pivots on its asset's origin, as authored
		clone.Anchored = spec.Primary
		clone.Massless = not spec.Primary
		clone.CanCollide, clone.CanTouch, clone.CanQuery = false, false, false
		clone.CastShadow = spec.CastShadow
		clone.Color = Color3.fromRGB(spec.Color[1], spec.Color[2], spec.Color[3])
		clone.Material = Enum.Material[spec.Material]
		clone.Reflectance = spec.Reflectance
		clone.Transparency = spec.Transparency
		pcall(function()
			clone.TextureID = ""
		end)
		pcall(function()
			clone.RenderFidelity = Enum.RenderFidelity[spec.RenderFidelity or "Precise"]
		end)
		pcall(function()
			clone.CollisionFidelity = Enum.CollisionFidelity.Box
		end)
		clone:SetAttribute("EventKitPiece", pieceName)
		clone:SetAttribute("EventKitRole", spec.Role)
		pieces[pieceName] = clone
		if pieceName == asset.primary then
			primary = clone
		end
	end
	assert(primary, name .. ": its PrimaryPart " .. tostring(asset.primary) .. " is not among its pieces")
	local template
	if #asset.pieces == 1 then
		template = primary
		template.Name = name
	else
		template = Instance.new("Model")
		template.Name = name
		for _, pieceName in asset.pieces do
			local part = pieces[pieceName]
			part.Parent = template
			if part ~= primary then
				local weld = Instance.new("Weld")
				weld.Name = M.WeldName
				weld.Part0 = primary
				weld.Part1 = part
				weld.C0 = primary.CFrame:Inverse() * part.CFrame
				weld.C1 = CFrame.new()
				weld.Parent = part
			end
		end
		template.PrimaryPart = primary
	end
	for attachmentName, a in asset.attachments or {} do
		local attachment = Instance.new("Attachment")
		attachment.Name = attachmentName
		attachment.CFrame = primary.CFrame:Inverse() * (origin * lookAlong(v3(a.position), v3(a.direction)))
		attachment.Parent = primary
	end
	setAttributes(template, assetAttributes(name, asset))
	template:SetAttribute("U4Asset", M.Stamp)
	template:SetAttribute("EventKitAsset", name)
	template:SetAttribute("EventKitVersion", version)
	template:SetAttribute("EventKitImportTurn", turn * 90)
	return template
end

-- The templates from any root holding the kit's EV_* MeshParts (an importer's wrapper Models and name suffixes
-- are fine). One import turn for the whole kit (it was one FBX): read from every piece's pivot. An asset whose
-- pieces are not all there with the manifest's shape is left out (report.skipped / report.problems).
function M.Build(root, manifest)
	local report = { built = {}, skipped = {}, problems = {}, turn = 0, pieces = 0, note = nil }
	local specs = M.Specs(manifest)
	local index = MeshKitImport.Index(root)
	local parts, entries, bad = {}, {}, {}
	for _, piece in manifest.pieces do
		local part = MeshKitImport.Find(index, piece.name)
		if not part then
			table.insert(report.problems, piece.name .. " is not in the kit")
			bad[piece.name] = true
		elseif not part:IsA("MeshPart") then
			table.insert(report.problems, piece.name .. " is a " .. part.ClassName .. ", not a MeshPart")
			bad[piece.name] = true
		else
			local uri = KitImport.MeshUri(part)
			assert(not KitImport.IsLocalContent(uri), M.KitFile .. ": " .. piece.name .. " shows local content (" .. uri
				.. "): import it again with Upload to Roblox on (design/event/supersonic/IMPORTAR_EVENTO.md)")
			parts[piece.name] = part
			table.insert(entries, { part = part, spec = specs[piece.name] })
		end
	end
	local turn = MeshKitImport.ImportTurn(entries, CFrame, Vector3)
	report.turn, report.note = turn.turn, turn.note
	if not turn.ok then
		table.insert(report.problems, turn.note or "the import's turn cannot be read")
		for _, name in M.AssetNames do
			table.insert(report.skipped, name)
		end
		return nil, report
	end
	for _, entry in entries do
		if not MeshKitImport.Scale(entry.part.Size, entry.spec.Size, turn.turn) then
			table.insert(report.problems, ("%s has the wrong shape (%s; the manifest says %s x %s x %s)"):format(entry.spec.Name,
				tostring(entry.part.Size), tostring(entry.spec.Size[1]), tostring(entry.spec.Size[2]), tostring(entry.spec.Size[3])))
			bad[entry.spec.Name] = true
		end
	end
	local meshes = Instance.new("Folder")
	meshes.Name = M.FolderName
	for _, name in M.AssetNames do
		local asset = manifest.assets[name]
		local ok = asset ~= nil
		for _, pieceName in (asset and asset.pieces) or {} do
			ok = ok and not bad[pieceName] and parts[pieceName] ~= nil
		end
		if ok then
			buildAsset(name, asset, specs, parts, turn.turn, CFrame.new(), manifest.kitVersion).Parent = meshes
			table.insert(report.built, name)
			report.pieces += #asset.pieces
		else
			table.insert(report.skipped, name)
		end
	end
	if #report.built == 0 then
		return nil, report
	end
	meshes:SetAttribute("EventKitVersion", manifest.kitVersion)
	meshes:SetAttribute("EventKitImportTurn", turn.turn * 90)
	meshes:SetAttribute("EventKitAssets", table.concat(report.built, ","))
	return meshes, report
end

-- The quarter turn (0..3) Studio's importer gave the ring, and where it was read: "pivot" (its own PivotOffset,
-- only when its box centre is off its origin, which the kit never is), else the size: X and Z swap on a quarter
-- turn ("size"); a half turn leaves the torus as it was, so an even (odd) turn is hintTurn when that has the same
-- parity ("event kit": the same importer turned EventKit.fbx) or RingDefaultTurn (+1). nil, "shape" when the size
-- fits no quarter turn about Y (lying flat, another mesh).
function M.RingTurn(part, spec, hintTurn: number?): (number?, string)
	local own = MeshKitImport.ImportTurn({ { part = part, spec = spec } }, CFrame, Vector3)
	if own.ok and own.note == nil and MeshKitImport.Scale(part.Size, spec.Size, own.turn) then
		return own.turn, "pivot"
	end
	local even = MeshKitImport.Scale(part.Size, spec.Size, 0) ~= nil
	local odd = MeshKitImport.Scale(part.Size, spec.Size, 1) ~= nil
	if not even and not odd then
		return nil, "shape"
	end
	local parity = if even then 0 else 1
	if type(hintTurn) == "number" and hintTurn % 2 == parity then
		return hintTurn % 4, "event kit"
	end
	return (M.RingDefaultTurn + parity) % 4, "size"
end

-- Meshes.Ring from any root holding the ring kit's EV_Ring MeshPart (a wrapper Model, an importer suffix and
-- any unit are fine): the import turn undone, its pivot on its centre at the world origin, the look from the
-- ring manifest. Returns (template | nil, report { turn, source, problems }).
function M.BuildRing(root, manifest, hintTurn: number?)
	local report = { problems = {}, turn = nil, source = nil }
	local specs = M.Specs(manifest)
	local spec = specs[M.RingPiece]
	assert(spec, M.RingManifestFile .. " has no piece " .. M.RingPiece)
	local part = MeshKitImport.Find(MeshKitImport.Index(root), M.RingPiece)
	if not part then
		table.insert(report.problems, M.RingPiece .. " is not in the ring kit")
		return nil, report
	elseif not part:IsA("MeshPart") then
		table.insert(report.problems, M.RingPiece .. " is a " .. part.ClassName .. ", not a MeshPart")
		return nil, report
	end
	local uri = KitImport.MeshUri(part)
	assert(not KitImport.IsLocalContent(uri), M.RingKitFile .. ": " .. M.RingPiece .. " shows local content (" .. uri
		.. "): import it again with Upload to Roblox on (design/event/supersonic/ring/IMPORTAR_ANILLO.md)")
	local turn, source = M.RingTurn(part, spec, hintTurn)
	if not turn then
		table.insert(report.problems, ("%s has the wrong shape (%s; the manifest says %s x %s x %s, X and Z swapped on a "
			.. "quarter turn; lying flat?)"):format(M.RingPiece, tostring(part.Size), tostring(spec.Size[1]),
			tostring(spec.Size[2]), tostring(spec.Size[3])))
		return nil, report
	end
	report.turn, report.source = turn, source
	local template = buildAsset(M.RingName, manifest.assets[M.RingName], specs, { [M.RingPiece] = part }, turn, CFrame.new(),
		manifest.kitVersion)
	template:SetAttribute("EventKitSource", "RingKit")
	template:SetAttribute("RingTurnSource", source)
	return template, report
end

-- The event kit's part of Insert: (anything put in, the kit's import turn when its pivots showed one).
local function insertEventKit(assetsFolder, note, kit, ensureFolder): (boolean, number?)
	if kit == nil then
		kit = M.Load()
	end
	if not kit then
		note("no " .. M.KitFile .. ": " .. assetsFolder.Name .. "." .. M.FolderName
			.. " has no event meshes (the event draws its simple shapes; design/event/supersonic/IMPORTAR_EVENTO.md)")
		return false, nil
	end
	local manifest = M.Manifest()
	local built, report = M.Build(kit, manifest)
	local hint = if report.note == nil then report.turn else nil
	if not built then
		note(("event kit not used (%s): %s"):format(M.KitFile, table.concat(report.problems, "; ")))
		return false, hint
	end
	local folder = ensureFolder()
	local put = {}
	for _, template in built:GetChildren() do
		if folder:FindFirstChild(template.Name) then
			note(("event kit: %s.%s.%s is someone else's (no U4Asset \"%s\"); kept, ours not put in"):format(assetsFolder.Name,
				M.FolderName, template.Name, M.Stamp))
		else
			template.Parent = folder
			table.insert(put, template.Name)
		end
	end
	if #put == 0 then
		return false, hint
	end
	for _, key in { "EventKitVersion", "EventKitImportTurn" } do
		folder:SetAttribute(key, built:GetAttribute(key))
	end
	folder:SetAttribute("EventKitAssets", table.concat(put, ","))
	note(("%s.%s: %s (%d kit pieces, import turn %d deg)"):format(assetsFolder.Name, M.FolderName, table.concat(put, ", "),
		report.pieces, report.turn * 90))
	if #report.skipped > 0 then
		note("event kit: left out " .. table.concat(report.skipped, ", ") .. " (" .. table.concat(report.problems, "; ") .. ")")
	end
	return true, hint
end

-- The ring kit's part of Insert: true when Meshes.Ring was put in. No ring kit: nothing at all (no note).
local function insertRing(assetsFolder, note, ringKit, hintTurn, ensureFolder): boolean
	if ringKit == nil then
		ringKit = M.LoadRing()
	end
	if not ringKit then
		return false
	end
	local manifest = M.RingManifest()
	local template, report = M.BuildRing(ringKit, manifest, hintTurn)
	if not template then
		note(("ring kit not used (%s): %s"):format(M.RingKitPath() or M.RingKitFile, table.concat(report.problems, "; ")))
		return false
	end
	local folder = ensureFolder()
	if folder:FindFirstChild(M.RingName) then
		note(("ring kit: %s.%s.%s is someone else's (no U4Asset \"%s\"); kept, ours not put in"):format(assetsFolder.Name,
			M.FolderName, M.RingName, M.Stamp))
		return false
	end
	template.Parent = folder
	note(("%s.%s.%s: %s (ring kit v%d, import turn %d deg from the %s)"):format(assetsFolder.Name, M.FolderName, M.RingName,
		M.RingPiece, manifest.kitVersion, report.turn * 90, report.source))
	return true
end

-- Puts the templates into assetsFolder.Meshes (audit/u4_supersonic_assets makes it empty; made here when missing).
-- Our older templates there (U4Asset stamp, the Ring too) are replaced; anything else of the same name is kept and
-- that asset skipped. The event kit first (its notes first), then the ring kit (ringKit: nil = the file, false =
-- none, or a root; no ring kit changes nothing). Returns the Meshes folder, or nil when nothing was put in.
function M.Insert(assetsFolder, notes, kit, ringKit)
	local function note(text)
		if notes then
			table.insert(notes, text)
		end
	end
	local folder = assetsFolder:FindFirstChild(M.FolderName)
	if folder then
		for _, child in folder:GetChildren() do
			if child:GetAttribute("U4Asset") == M.Stamp then
				child.Parent = nil
			end
		end
	end
	local function ensureFolder()
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = M.FolderName
			folder.Parent = assetsFolder
		end
		return folder
	end
	local putKit, hintTurn = insertEventKit(assetsFolder, note, kit, ensureFolder)
	local putRing = insertRing(assetsFolder, note, ringKit, hintTurn, ensureFolder)
	if putKit or putRing then
		return folder
	end
	return nil
end

-- A joint holds its parts where they are.
local function holds(joint)
	local a, b = joint.Part0.CFrame * joint.C0, joint.Part1.CFrame * joint.C1
	return (a.Position - b.Position).Magnitude < 1e-3 and (a.LookVector - b.LookVector).Magnitude < 1e-4
		and (a.UpVector - b.UpVector).Magnitude < 1e-4
end

-- What is wrong with a built Meshes folder (an empty list: nothing): each template there has its pieces where
-- the manifest puts them (from its pivot), welded to its PrimaryPart, inert, with its attachments; no scripts.
-- A Ring there is checked against the ring kit's manifest.
function M.Problems(meshes, manifest)
	local problems = {}
	local function check(ok, text)
		if not ok then
			table.insert(problems, text)
		end
	end
	for _, path in M.Scripts(meshes) do
		table.insert(problems, "a script: " .. path)
	end
	local eventSpecs = M.Specs(manifest)
	local ringManifest, ringSpecs = nil, nil
	for _, template in meshes:GetChildren() do
		local name = template.Name
		local asset, specs = manifest.assets[name], eventSpecs
		if asset == nil and name == M.RingName then
			ringManifest = ringManifest or M.RingManifest()
			ringSpecs = ringSpecs or M.Specs(ringManifest)
			asset, specs = ringManifest.assets[M.RingName], ringSpecs
		end
		check(asset ~= nil and template:GetAttribute("U4Asset") == M.Stamp, name .. ": not one of the kit's assets")
		if asset then
			local primary = if template:IsA("Model") then template.PrimaryPart else template
			check(primary ~= nil and primary:IsA("MeshPart") and primary.Anchored, name .. ": its PrimaryPart is an anchored MeshPart")
			if primary then
				local origin = primary.CFrame * primary.PivotOffset
				for _, pieceName in asset.pieces do
					local part = if template:IsA("Model") then template:FindFirstChild(pieceName) else template
					local spec = specs[pieceName]
					check(part ~= nil and part:IsA("MeshPart"), name .. "." .. pieceName .. " is missing")
					if part and spec then
						local turn = (tonumber(template:GetAttribute("EventKitImportTurn")) or 0) / 90
						local want, size = MeshKitImport.Placement(origin, spec, turn, CFrame, Vector3)
						check((part.CFrame.Position - want.Position).Magnitude < 1e-3
							and (part.CFrame.LookVector - want.LookVector).Magnitude < 1e-4
							and (part.Size - size).Magnitude < 1e-3, name .. "." .. pieceName .. " is not where the manifest puts it")
						check(not part.CanCollide and not part.CanTouch and not part.CanQuery, name .. "." .. pieceName .. " is not inert")
						if part ~= primary then
							local weld = part:FindFirstChild(M.WeldName)
							check(weld and weld:IsA("Weld") and weld.Part0 == primary and weld.Part1 == part and holds(weld)
								and not part.Anchored, name .. "." .. pieceName .. " is not welded to " .. primary.Name)
						end
					end
				end
				for attachmentName in asset.attachments or {} do
					check(primary:FindFirstChild(attachmentName) ~= nil, name .. ": no Attachment " .. attachmentName)
				end
			end
		end
	end
	return problems
end

-- Tests: what Studio's Import 3D makes of EventKit.fbx, without Studio. One MeshPart per manifest piece (in a
-- Model "EventKit"), each at its box centre with no rotation, its PivotOffset the piece's origin from there (every
-- piece's origin is the FBX origin: -bboxCenterOffset), the whole kit turned o.turn quarter turns about Y
-- (default 2: what Studio did to the Green Hill kit), scaled by o.scale (1), optionally wrapped in an extra Model
-- (o.wrap), without the pieces in o.omit, renamed by o.rename.
function M.StandIn(manifest, options)
	local o = options or {}
	local turn = if o.turn ~= nil then o.turn else 2
	local scale = o.scale or 1
	local yaw = CFrame.Angles(0, turn * math.pi / 2, 0)
	local origin = Vector3.new(12, 4, -30) -- where the importer dropped the kit
	local model = Instance.new("Model")
	model.Name = "EventKit"
	local holder = model
	if o.wrap then
		holder = Instance.new("Model")
		holder.Name = "EventKit_Import"
		holder.Parent = model
	end
	for _, piece in manifest.pieces do
		if not (o.omit and o.omit[piece.name]) then
			local part = Instance.new("MeshPart")
			part.Name = (o.rename and o.rename[piece.name]) or piece.name
			local size = { piece.size[1] * scale, piece.size[2] * scale, piece.size[3] * scale }
			if turn % 2 == 1 then
				size[1], size[3] = size[3], size[1]
			end
			part.Size = Vector3.new(size[1], size[2], size[3])
			local offset = v3(piece.bboxCenterOffset) * scale
			part.CFrame = CFrame.new(origin + yaw * offset)
			part.PivotOffset = CFrame.new(yaw * (-offset)) * CFrame.Angles(math.pi / 2, 0, 0)
			part.Color = Color3.fromRGB(163, 162, 165)
			part.Anchored = true
			if o.surfaceAppearance then
				Instance.new("SurfaceAppearance").Parent = part
			end
			part.Parent = holder
		end
	end
	return model
end

-- Tests: what Studio's Import 3D makes of RingKit.fbx: one MeshPart EV_Ring (in a Model "RingKit") at its box
-- centre, its PivotOffset the FBX origin from there (the ring's centre: position zero) with the importer's
-- rotation, the ring turned o.turn quarter turns about Y (default 2; X and Z of its size swap on an odd turn),
-- scaled by o.scale, wrapped in an extra Model (o.wrap), renamed (o.rename), lying flat (o.flat: Y and Z of its
-- size swapped), left out (o.omit), with a SurfaceAppearance (o.surfaceAppearance).
function M.RingStandIn(manifest, options)
	local o = options or {}
	local turn = if o.turn ~= nil then o.turn else 2
	local scale = o.scale or 1
	local yaw = CFrame.Angles(0, turn * math.pi / 2, 0)
	local origin = Vector3.new(-6, 3, 14) -- where the importer dropped the ring
	local model = Instance.new("Model")
	model.Name = "RingKit"
	local holder = model
	if o.wrap then
		holder = Instance.new("Model")
		holder.Name = "RingKit_Import"
		holder.Parent = model
	end
	if not o.omit then
		local piece = manifest.pieces[1]
		local part = Instance.new("MeshPart")
		part.Name = o.rename or piece.name
		local size = { piece.size[1] * scale, piece.size[2] * scale, piece.size[3] * scale }
		if turn % 2 == 1 then
			size[1], size[3] = size[3], size[1]
		end
		if o.flat then
			size[2], size[3] = size[3], size[2]
		end
		part.Size = Vector3.new(size[1], size[2], size[3])
		local offset = v3(piece.bboxCenterOffset) * scale
		part.CFrame = CFrame.new(origin + yaw * offset)
		part.PivotOffset = CFrame.new(yaw * (-offset)) * CFrame.Angles(math.pi / 2, 0, 0)
		part.Color = Color3.fromRGB(163, 162, 165)
		part.Anchored = true
		if o.surfaceAppearance then
			Instance.new("SurfaceAppearance").Parent = part
		end
		part.Parent = holder
	end
	return model
end

return M
