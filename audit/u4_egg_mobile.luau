-- audit/u4_egg_mobile.luau  (Update 4, 2026-09-26, owner: Eggman in his Egg Mobile)
-- Seats the owner's R6 Eggman (design/npc/LobbyCharacters.rbxm, placed by audit/build_update4's
-- insertLobbyCharacters at his Shared/LobbyNpcConfig spot) in the Egg Mobile that Shared/EggMobile
-- assembles from the owner's Blender kit on that same spot.
-- 2026-09-26 (owner): the part-built ship is gone. The ship exists only when the owner has imported
-- design/npc/eggmobile/EggMobileKit.fbx in Studio and saved design/npc/EggMobileKit.rbxm
-- (design/npc/eggmobile/IMPORTAR_EGGMOBILE.md); without it Eggman stands at his spot as before the ship (the
-- stamped LobbyCharacters folder is replaced on every build, so a part-built ship of an older build goes).
--   * Eggman's parts move up and back onto the bench (EggMobile.SeatCFrame; his joints are kept, the
--     client's "EggmanDriving" pose bends his legs under the cockpit floor);
--   * the ship Model "EggMobile" goes inside the Eggman model, its hull root welded to his
--     HumanoidRootPart (Weld EggMobileMount): Gameplay/LobbyNpcs adopts him as before and his anchored root
--     holds the whole ship (Gameplay/EggMobileClient hovers it by moving that root).
--   LoadKit()                      the kit from design/npc/EggMobileKit.rbxm + the manifest (nil: no file)
--   KitFromFolder(folder, manifest) the kit from any folder of EM_* MeshParts (tests: StandInKit)
--   StandInKit(manifest, yaw)      MeshParts sized from the manifest, pivots turned like Studio's import (tests)
--   Insert(folder, key, notes, kit?) build_update4: the folder's Eggman, standing at key's spot
--   Seat(eggman, floor, kit)       any R6 Eggman standing on `floor` (root 3 studs up); returns the ship
--   Verify(key, dm)                a built place: the ship and the seat with a kit, no ship without one
--   Problems(eggman, floor)        the checks behind Verify, as a list (tests)
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local roblox = require("@lune/roblox")
local EggMobile = require("../src/common/ReplicatedStorage/Shared/EggMobile")
local Npc = require("../src/common/ReplicatedStorage/Shared/LobbyNpcConfig")
local KitImport = require("./kit_import")

local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local M = {}

M.KitFile = "design/npc/EggMobileKit.rbxm"
M.ManifestFile = "design/npc/eggmobile/eggmobile_manifest.json"
M.ENV = {
	Instance = roblox.Instance, Vector3 = roblox.Vector3, CFrame = roblox.CFrame, Color3 = roblox.Color3,
	Enum = roblox.Enum, UDim = roblox.UDim, UDim2 = roblox.UDim2, Vector2 = roblox.Vector2, Font = roblox.Font,
}
M.StandingRootHeight = 3 -- audit/u4_npc_r6: the converted R6 stands with its root 3 studs up

local function v3(list)
	return Vector3.new(list[1], list[2], list[3])
end

function M.ReadManifest()
	assert(fs.isFile(M.ManifestFile), M.ManifestFile .. " is missing (run audit/egg_mobile_bpy.py in Blender)")
	local ok, data = pcall(serde.decode, "json", fs.readFile(M.ManifestFile))
	assert(ok and type(data) == "table" and type(data.pieces) == "table", M.ManifestFile .. " is not a kit manifest: " .. tostring(data))
	return data
end

-- The manifest's pieces as the builder's specs (in the manifest's order).
function M.Specs(manifest)
	local specs = {}
	for _, entry in manifest.pieces do
		table.insert(specs, {
			name = entry.name,
			role = entry.role,
			size = v3(entry.size),
			offset = v3(entry.bboxCenterOffset),
			color = entry.color,
			material = entry.material,
			reflectance = entry.reflectance,
			transparency = entry.transparency,
			castShadow = entry.castShadow,
			glow = if type(entry.glow) == "string" then entry.glow else nil,
			side = if type(entry.side) == "number" then entry.side else nil,
			rideOn = if type(entry.rideOn) == "string" then entry.rideOn else nil,
			motorPivot = if type(entry.motorPivot) == "table" then entry.motorPivot else nil,
		})
	end
	return specs
end

-- The kit from a folder of the owner's MeshParts: the manifest's specs, each piece's template (no local
-- content allowed: a player online would never load it), the import's quarter turn.
function M.KitFromFolder(folder, manifest)
	KitImport.Flatten(folder, EggMobile.PiecePrefix)
	local specs = M.Specs(manifest)
	local templates, pairs_, warnings = {}, {}, {}
	for _, spec in specs do
		local part = folder:FindFirstChild(spec.name)
		if part and part:IsA("MeshPart") then
			local uri = KitImport.MeshUri(part)
			assert(not KitImport.IsLocalContent(uri), M.KitFile .. ": " .. spec.name .. " shows local content (" .. uri
				.. "): import it again with Upload to Roblox on (design/npc/eggmobile/IMPORTAR_EGGMOBILE.md)")
			templates[spec.name] = part
			table.insert(pairs_, { part = part, offset = spec.offset, size = spec.size })
		elseif part then
			table.insert(warnings, spec.name .. " is a " .. part.ClassName .. ", not a MeshPart")
		else
			table.insert(warnings, spec.name .. " is not in the kit")
		end
	end
	local yaw, evidence = KitImport.DetectYaw(pairs_)
	if yaw == nil then
		table.insert(warnings, "the kit's import pivots match no quarter turn of the manifest; placed as authored")
	end
	return {
		templates = templates,
		specs = specs,
		importYaw = yaw or 0,
		evidence = evidence,
		version = manifest.kitVersion,
		warnings = warnings,
	}
end

-- The owner's kit (design/npc/EggMobileKit.rbxm, saved from Studio after Import 3D) with its manifest; nil
-- when the file is not there.
function M.LoadKit()
	if not fs.isFile(M.KitFile) then
		return nil
	end
	local roots = roblox.deserializeModel(fs.readFile(M.KitFile))
	local folder
	if #roots == 1 and (roots[1].ClassName == "Folder" or roots[1].ClassName == "Model") then
		folder = roots[1]
	else
		folder = roblox.Instance.new("Folder")
		for _, root in roots do
			root.Parent = folder
		end
	end
	for _, d in folder:GetDescendants() do
		assert(not d:IsA("LuaSourceContainer"), M.KitFile .. " holds a script: " .. d:GetFullName())
	end
	local manifest = M.ReadManifest()
	assert(manifest.kitVersion == EggMobile.KitVersion, ("%s is kit v%s but Shared/EggMobile expects v%d: re-export and re-import the kit")
		:format(M.ManifestFile, tostring(manifest.kitVersion), EggMobile.KitVersion))
	return M.KitFromFolder(folder, manifest)
end

-- Tests: what Studio's Import 3D makes of the kit, without Studio. One MeshPart per manifest piece, sized as
-- the manifest says, standing where the import put it (the ship turned by `yaw` about the origin) with the
-- import's PivotOffset (the piece's origin, the ship origin, seen from the part: -bboxCenterOffset turned).
function M.StandInKit(manifest, yaw)
	local folder = roblox.Instance.new("Model")
	folder.Name = "EggMobileKit"
	local turn = CFrame.Angles(0, yaw or 0, 0)
	for _, entry in manifest.pieces do
		local part = roblox.Instance.new("MeshPart")
		part.Name = entry.name
		local size, offset = v3(entry.size), v3(entry.bboxCenterOffset)
		local quarterOdd = math.floor((yaw or 0) / (math.pi / 2) + 0.5) % 2 == 1
		part.Size = if quarterOdd then Vector3.new(size.Z, size.Y, size.X) else size
		part.CFrame = CFrame.new(turn * offset + Vector3.new(0, 30, 0))
		part.PivotOffset = CFrame.new(turn * -offset)
		part.Anchored = true
		part.Parent = folder
	end
	return folder
end

-- Moves every part of `eggman` (standing on `floor`) onto the bench of a new Egg Mobile on that floor and puts
-- the ship inside him. Returns the ship Model and the builder's report.
function M.Seat(eggman, floor, kit)
	assert(kit, "M.Seat needs the kit (M.LoadKit() / M.KitFromFolder)")
	local root = eggman:FindFirstChild("HumanoidRootPart")
	assert(root and root:IsA("BasePart"), eggman:GetFullName() .. ": no HumanoidRootPart to seat")
	assert(not eggman:FindFirstChild(EggMobile.ModelName), eggman:GetFullName() .. " already has an " .. EggMobile.ModelName)
	local standing = floor * CFrame.new(0, M.StandingRootHeight, 0)
	assert((root.CFrame.Position - standing.Position).Magnitude < 0.05, eggman:GetFullName() .. " does not stand on the ship's floor")
	local move = EggMobile.SeatCFrame(floor, CFrame) * standing:Inverse()
	for _, part in eggman:GetDescendants() do
		if part:IsA("BasePart") then
			part.CFrame = move * part.CFrame
		end
	end
	local ship, hull, report = EggMobile.Build(M.ENV, floor, kit)
	local mount = roblox.Instance.new("Weld")
	mount.Name = EggMobile.MountName
	mount.Part0 = root
	mount.Part1 = hull
	mount.C0 = root.CFrame:Inverse() * hull.CFrame
	mount.C1 = CFrame.new()
	mount.Parent = hull
	ship.Parent = eggman
	return ship, report
end

-- build_update4: seats the folder's Eggman in the ship when the kit is there; otherwise he stays standing.
-- `kit`: nil reads the owner's file (M.LoadKit), false means no ship (tests).
function M.Insert(folder, key, notes, kit)
	local eggman = folder:FindFirstChild("Eggman")
	assert(eggman, key .. ": LobbyCharacters has no Eggman to seat in the Egg Mobile")
	if kit == nil then
		kit = M.LoadKit()
	end
	if not kit then
		if notes then
			table.insert(notes, "no " .. M.KitFile .. ": no Egg Mobile, Eggman stands at his spot")
		end
		return nil
	end
	local spot = assert(Npc.Spot(key, "Eggman"), key .. ": no Eggman spot")
	local ship, report = M.Seat(eggman, Npc.SpotCFrame(spot, CFrame), kit)
	if notes then
		local extra = ""
		if #report.missing > 0 then
			extra = "; MISSING " .. table.concat(report.missing, ", ")
		end
		table.insert(notes, ("Egg Mobile (%d kit pieces, import turn %d deg) with Eggman seated%s"):format(report.pieces,
			ship:GetAttribute("EggMobileImportYaw"), extra))
		for _, warning in kit.warnings or {} do
			table.insert(notes, "Egg Mobile kit: " .. warning)
		end
	end
	return ship
end

-- A joint holds its parts where they stand. The place files keep positions as float32: World 1's
-- lobby is 37,468 studs up, where that is ~0.004 studs, so positions get 0.02 of slack.
local function holds(joint)
	local a, b = joint.Part0.CFrame * joint.C0, joint.Part1.CFrame * joint.C1
	return (a.Position - b.Position).Magnitude < 0.02 and (a.LookVector - b.LookVector).Magnitude < 1e-3
		and (a.UpVector - b.UpVector).Magnitude < 1e-3
end

-- What is wrong with the Egg Mobile of `eggman` on `floor` (an empty list: nothing).
function M.Problems(eggman, floor)
	local problems = {}
	local function check(ok, text)
		if not ok then
			table.insert(problems, text)
		end
	end
	local ship = eggman:FindFirstChild(EggMobile.ModelName)
	if not ship then
		return { "no " .. EggMobile.ModelName .. " in " .. eggman:GetFullName() }
	end
	check(ship:GetAttribute("U4Asset") == EggMobile.Stamp and ship:GetAttribute("EggMobileVersion") == EggMobile.Version
		and ship:GetAttribute("EggMobileLook") == "Kit", "the ship's stamp / version / look")
	local hull = ship:FindFirstChild(EggMobile.HullName)
	local root = eggman:FindFirstChild("HumanoidRootPart")
	check(hull and root, "no hull or no root")
	if not (hull and root) then
		return problems
	end
	local seat = EggMobile.SeatCFrame(floor, CFrame)
	check((root.CFrame.Position - seat.Position).Magnitude < 0.05 and (root.CFrame.LookVector - seat.LookVector).Magnitude < 1e-3,
		("Eggman's root is not on the seat (%s)"):format(tostring(root.CFrame.Position)))
	local c = EggMobile.HullCenter
	check((hull.CFrame.Position - (floor * Vector3.new(c[1], c[2], c[3]))).Magnitude < 0.05, "the hull is not on the spot")
	local mount = hull:FindFirstChild(EggMobile.MountName)
	check(mount and mount:IsA("Weld") and mount.Part0 == root and mount.Part1 == hull and holds(mount), "the hull is not welded to Eggman's root where it stands")
	local parts, colliders, meshes = 0, 0, 0
	for _, d in ship:GetDescendants() do
		check(not d:IsA("LuaSourceContainer"), "a script in the ship: " .. d:GetFullName())
		if d:IsA("BasePart") then
			parts += 1
			check(d.CanTouch == false, d.Name .. " can touch")
			if d:GetAttribute("EggCollider") then
				colliders += 1
				check(d.Anchored and d.CanCollide and d.Transparency == 1, d.Name .. ": a collider is anchored, colliding and invisible")
			else
				check(not d.CanCollide and not d.CanQuery, d.Name .. " collides or blocks rays")
			end
			if d:IsA("MeshPart") then
				meshes += 1
				check(not KitImport.IsLocalContent(KitImport.MeshUri(d)), d.Name .. " shows local content")
			end
		elseif d:IsA("JointInstance") and d.Part0 and d.Part1 then
			check(holds(d), d:GetFullName() .. " does not hold its parts where they are")
		end
	end
	check(colliders == EggMobile.ColliderCount, colliders .. " colliders")
	check(meshes > 0, "no kit pieces in the ship")
	check(parts == ship:GetAttribute("EggMobileParts") and parts <= EggMobile.PartBudget, ("%d parts (budget %d)"):format(parts, EggMobile.PartBudget))
	return problems
end

-- A built place: with the owner's kit, Eggman sits in the ship at his spot; without it, no ship anywhere in
-- the LobbyCharacters folder (a part-built ship from an older build is gone) and he stands at his spot.
function M.Verify(key, dm)
	local folder = dm:GetService("Workspace"):FindFirstChild("LobbyCharacters")
	local eggman = folder and folder:FindFirstChild("Eggman")
	assert(eggman, key .. ": Workspace.LobbyCharacters.Eggman")
	local spot = assert(Npc.Spot(key, "Eggman"), key .. ": no Eggman spot")
	local floor = Npc.SpotCFrame(spot, CFrame)
	if fs.isFile(M.KitFile) then
		local problems = M.Problems(eggman, floor)
		assert(#problems == 0, key .. ": Egg Mobile: " .. table.concat(problems, "; "))
	else
		assert(not folder:FindFirstChild(EggMobile.ModelName, true), key .. ": an Egg Mobile is in the place but there is no " .. M.KitFile)
		local root = eggman:FindFirstChild("HumanoidRootPart")
		local standing = floor * CFrame.new(0, M.StandingRootHeight, 0)
		assert(root and (root.CFrame.Position - standing.Position).Magnitude < 0.05, key .. ": Eggman does not stand at his spot")
	end
end

return M
