-- audit/kit_import.luau (2026-09-26, owner): what the Blender kits have in common once the owner has
-- imported them with Studio's File > Import 3D and saved them as .rbxm (design/race/greenhill/GreenHillKit.rbxm,
-- design/npc/EggMobileKit.rbxm). Lune only.
--   KitImport.DetectYaw(pairs)       the quarter turn about Y that Studio's importer added to a kit
--   KitImport.Flatten(folder, prefix) lift the outermost `prefix`* instances out of wrapper Models
--   KitImport.MeshUri(part)          a MeshPart's mesh content ("" when none), MeshContent or MeshId
--   KitImport.IsLocalContent(uri)    true for anything a player online would never load
local roblox = require("@lune/roblox")

local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local KitImport = {}

-- 2026-09-26: Studio's Import 3D turned the Green Hill kit 180 degrees about Y (the FBX's -Z forward): each
-- MeshPart's PivotOffset (where the importer put the piece's own origin) is the manifest's -bboxCenterOffset
-- turned by that yaw. `pairs` lists { part = the imported MeshPart, offset = bboxCenterOffset (Vector3),
-- size = the manifest's size (Vector3) }; a zero PivotOffset (a stand-in, never an import) is no evidence.
-- Returns the yaw in radians (0, pi/2, pi or 3pi/2; nil when there is evidence but no quarter turn fits),
-- the evidence (studs of offsets compared) and the best turn's error.
function KitImport.DetectYaw(pairs: { any }): (number?, number, number)
	local evidence, errors = 0, { 0, 0, 0, 0 }
	for _, pair in pairs do
		local ok, pivot = pcall(function()
			return pair.part.PivotOffset
		end)
		if ok and pivot and pivot.Position.Magnitude > 1e-4 and pair.size.Y > 1e-6 then
			local k = pair.part.Size.Y / pair.size.Y -- the import's unit (a Stud / Meter mix-up scales it)
			local want = Vector3.new(-pair.offset.X * k, 0, -pair.offset.Z * k)
			local have = Vector3.new(pivot.Position.X, 0, pivot.Position.Z)
			evidence += want.Magnitude
			for turn = 0, 3 do
				errors[turn + 1] += ((CFrame.Angles(0, turn * math.pi / 2, 0) * want) - have).Magnitude
			end
		end
	end
	local best = 1
	for turn = 2, 4 do
		if errors[turn] < errors[best] then
			best = turn
		end
	end
	if evidence <= 1 then
		return 0, evidence, 0
	elseif errors[best] < 0.25 * evidence then
		return (best - 1) * math.pi / 2, evidence, errors[best]
	end
	return nil, evidence, errors[best]
end

-- Studio's importer can wrap the pieces in extra Models: every outermost instance named `prefix`* moves up to
-- `folder` (one inside another piece stays where it is).
function KitImport.Flatten(folder: any, prefix: string)
	local outer = {}
	for _, d in folder:GetDescendants() do
		if string.sub(d.Name, 1, #prefix) == prefix and d.Parent ~= folder then
			local inner = false
			local p = d.Parent
			while p and p ~= folder do
				if string.sub(p.Name, 1, #prefix) == prefix then
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
end

-- The mesh a MeshPart shows: newer Studio saves MeshContent (a Content), older MeshId (a string); Lune cannot
-- read a property that was never set, hence the pcalls.
function KitImport.MeshUri(part: any): string
	local ok, content = pcall(function()
		return part.MeshContent
	end)
	if ok and content ~= nil then
		local uri = string.match(tostring(content), "Uri=([^%)]+)")
		if uri then
			return uri
		end
	end
	local okId, id = pcall(function()
		return part.MeshId
	end)
	if okId and type(id) == "string" then
		return id
	end
	return ""
end

function KitImport.IsLocalContent(uri: string): boolean
	return uri ~= "" and not string.match(uri, "^rbxassetid://%d+$") and not string.match(uri, "^https?://")
end

return KitImport
