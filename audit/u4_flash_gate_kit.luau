-- audit/u4_flash_gate_kit.luau  (Update 4, 2026-09-26, owner: The Flash's gate as Blender meshes)
-- The gate kit for the build and the tests:
--   Load()                 design/race/flashgate/FlashGateKit.rbxm (what the owner saves from Studio
--                          after File > Import 3D of FlashGateKit.fbx, IMPORTAR_ARCO.md) as one root,
--                          or nil when the file is not there; no scripts allowed. Read once.
--   SetOverride(kit|false) the tests' stand-in instead of the file (nil = back to the file).
--   Manifest()             design/race/flashgate/flashgate_manifest.json (audit/flash_gate_bpy.py).
--   StandIn(manifest, o)   what Studio's importer makes of the FBX, from the manifest: a Model
--                          "FlashGateKit" of MeshParts, each at its box centre with no rotation, its
--                          PivotOffset the piece's origin (the gate origin) from there, the whole kit
--                          turned o.turn quarter turns about Y (default 2: what Studio did to the
--                          Green Hill kit), scaled by o.scale (1), optionally wrapped in an extra
--                          Model (o.wrap), without the pieces in o.omit, renamed by o.rename.
-- RaceArenaBuilder.BuildGate reads the kit through env.FlashGateKit (audit/build_update4 passes it).
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local CFrame, Vector3, Instance = roblox.CFrame, roblox.Vector3, roblox.Instance

local M = {}
M.KitFile = "design/race/flashgate/FlashGateKit.rbxm"
M.ManifestFile = "design/race/flashgate/flashgate_manifest.json"
M.Stamp = "FlashGateKit"

local cache = nil -- nil: not read yet; false: no file
local override = nil

function M.SetOverride(kit)
	override = kit
end

function M.Load()
	if override ~= nil then
		return override or nil
	end
	if cache == nil then
		cache = false
		if fs.isFile(M.KitFile) then
			local roots = roblox.deserializeModel(fs.readFile(M.KitFile))
			local root
			if #roots == 1 then
				root = roots[1]
			else
				root = Instance.new("Folder")
				for _, r in roots do
					r.Parent = root
				end
			end
			root.Name = M.Stamp
			for _, d in root:GetDescendants() do
				assert(not d:IsA("LuaSourceContainer"), M.KitFile .. " carries a script (" .. d:GetFullName() .. "); remove it and save again")
			end
			cache = root
		end
	end
	return cache or nil
end

function M.Manifest()
	if not fs.isFile(M.ManifestFile) then
		return nil
	end
	local ok, data = pcall(serde.decode, "json", fs.readFile(M.ManifestFile))
	assert(ok, M.ManifestFile .. " is not valid JSON: " .. tostring(data))
	return data
end

-- Studio's import of the FBX, simulated (see the header).
function M.StandIn(manifest, options)
	local o = options or {}
	local turn = if o.turn ~= nil then o.turn else 2
	local scale = o.scale or 1
	local yaw = CFrame.Angles(0, turn * math.pi / 2, 0)
	local origin = Vector3.new(40, 5, -20) -- where the importer dropped the kit
	local model = Instance.new("Model")
	model.Name = M.Stamp
	local holder = model
	if o.wrap then
		holder = Instance.new("Model")
		holder.Name = "FlashGateKit_Import"
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
			local offset = Vector3.new(piece.bboxCenterOffset[1], piece.bboxCenterOffset[2], piece.bboxCenterOffset[3]) * scale
			part.CFrame = CFrame.new(origin + yaw * offset)
			-- The importer's pivot: the piece's origin (the gate origin) from the box centre, turned
			-- with the mesh; Studio also gives it a quarter turn about X (Y-up from the FBX), which
			-- nothing reads.
			part.PivotOffset = CFrame.new(yaw * (-offset)) * CFrame.Angles(math.pi / 2, 0, 0)
			part.Color = roblox.Color3.fromRGB(163, 162, 165)
			part.Anchored = true
			if o.surfaceAppearance then
				local look = Instance.new("SurfaceAppearance")
				look.Parent = part
			end
			part.Parent = holder
		end
	end
	return model
end

return M
