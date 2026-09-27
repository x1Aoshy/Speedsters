--!strict
-- ReplicatedStorage/Shared/MeshKitImport.luau — 2026-09-26 (owner): a Blender kit imported with
-- Studio's File > Import 3D (Scale Unit Stud, Merge Meshes off) and saved as an .rbxm, placed piece
-- by piece from its manifest. Shared by RaceArenaBuilder.BuildGate (The Flash's gate,
-- FlashGate.Kit) and any other kit whose pieces keep their authored pivot; audit/u4_greenhill_arena
-- does the same maths for the Green Hill kit (GreenHill.ManifestSpecs).
--
-- What the importer does (checked on the owner's GreenHillKit.rbxm): each FBX object becomes a
-- MeshPart whose CFrame is its mesh's box centre (no rotation) and whose PivotOffset.Position is the
-- object's own origin from there, i.e. the manifest's -bboxCenterOffset; and it TURNED that kit 180
-- degrees about Y (the mesh baked turned, the pivot offset turned with it). So the turn is read
-- from the pivots (ImportTurn) and each mesh is turned back when placed (Placement), whatever turn
-- a future Studio applies. A MeshPart stretches its mesh to Size, so the import unit does not
-- matter; its axes must be the manifest's up to that quarter turn about Y.
--
-- Pure maths on plain Instances: no service, no Workspace scan. Specs are the manifest's numbers:
-- { Size = { x, y, z }, Offset = { x, y, z } } (the box size and the box centre's offset from the
-- kit's pivot, studs, the kit's frame). C / V = the CFrame / Vector3 constructors (Roblox's or
-- @lune/roblox's).
local MeshKitImport = {}

MeshKitImport.ShapeTolerance = 0.03 -- relative, per axis, after the uniform scale
MeshKitImport.ShapeSlack = 0.03 -- studs, per axis
MeshKitImport.MinEvidence = 1 -- studs of pivot offset (XZ) needed to read a turn
MeshKitImport.MaxErrorShare = 0.25 -- the best turn's pivot error, as a share of the evidence

-- Every BasePart under `root` (and root itself) by name; the first of a name wins, in a stable
-- order (an importer may wrap the pieces in extra Models).
function MeshKitImport.Index(root: any): { [string]: any }
	local index = {}
	if root == nil then
		return index
	end
	if root:IsA("BasePart") then
		index[root.Name] = root
	end
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") and index[d.Name] == nil then
			index[d.Name] = d
		end
	end
	return index
end

-- The part named `name`, else one named `name` plus an importer suffix that starts with a
-- non-alphanumeric character (".001", "_Mesh"; "FG_Leg" never matches "FG_LegL").
function MeshKitImport.Find(index: { [string]: any }, name: string): any?
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

-- The spec's size as the imported mesh holds it after `turn` quarter turns about Y (X and Z swap
-- on an odd turn).
function MeshKitImport.TurnedSize(size: { number }, turn: number): { number }
	if turn % 2 == 1 then
		return { size[3], size[2], size[1] }
	end
	return { size[1], size[2], size[3] }
end

-- The uniform scale between a part's Size and the spec size (turned), or nil when the proportions
-- differ (another mesh under that name, or axes the importer swapped some other way).
function MeshKitImport.Scale(have: any, size: { number }, turn: number): number?
	local want = MeshKitImport.TurnedSize(size, turn)
	local got = { have.X, have.Y, have.Z }
	local axis = 1
	for i = 2, 3 do
		if want[i] > want[axis] then
			axis = i
		end
	end
	local k = got[axis] / want[axis]
	if not (k > 0 and k < math.huge) then
		return nil
	end
	for i = 1, 3 do
		local slack = (want[i] * MeshKitImport.ShapeTolerance + MeshKitImport.ShapeSlack) * k
		if math.abs(got[i] - want[i] * k) > slack then
			return nil
		end
	end
	return k
end

export type Turn = { ok: boolean, turn: number, yaw: number, evidence: number, error: number, note: string? }

-- The quarter turn (0..3) the importer applied about Y, from each piece's PivotOffset against its
-- spec (pieces = { { part = MeshPart, spec = { Size, Offset } } }): the turn whose rotated
-- -Offset (scaled like the part) best matches the pivots. ok = false when the pivots show some
-- other change; too little evidence (no pivots, or every piece centred on its pivot, e.g. a
-- stand-in without PivotOffsets) reads as no turn.
function MeshKitImport.ImportTurn(pieces: { any }, C: any, V: any): Turn
	local evidence, errors = 0, { 0, 0, 0, 0 }
	for _, entry in pieces do
		local part, spec = entry.part, entry.spec
		local ok, pivot = pcall(function()
			return part.PivotOffset
		end)
		if ok and pivot and pivot.Position.Magnitude > 1e-4 and type(spec) == "table" and type(spec.Offset) == "table" then
			-- In the manifest's studs, whatever unit the import used (a quarter turn about Y keeps Y).
			local k = math.max(part.Size.Y / math.max(spec.Size[2], 1e-6), 1e-9)
			local want = V.new(-spec.Offset[1], 0, -spec.Offset[3])
			local have = V.new(pivot.Position.X / k, 0, pivot.Position.Z / k)
			evidence += want.Magnitude
			for turn = 0, 3 do
				errors[turn + 1] += ((C.Angles(0, turn * math.pi / 2, 0) * want) - have).Magnitude
			end
		end
	end
	local best = 1
	for turn = 2, 4 do
		if errors[turn] < errors[best] then
			best = turn
		end
	end
	if evidence <= MeshKitImport.MinEvidence then
		return { ok = true, turn = 0, yaw = 0, evidence = evidence, error = 0, note = "no pivot evidence: placed as authored" }
	end
	if errors[best] >= MeshKitImport.MaxErrorShare * evidence then
		return { ok = false, turn = 0, yaw = 0, evidence = evidence, error = errors[best],
			note = string.format("the pivots match no quarter turn (best %d degrees, off by %.2f of %.2f studs)", (best - 1) * 90, errors[best], evidence) }
	end
	return { ok = true, turn = best - 1, yaw = (best - 1) * math.pi / 2, evidence = evidence, error = errors[best], note = nil }
end

-- Where a piece goes: its box centre at frame * Offset, the mesh turned back by the import's turn
-- (so it shows with the manifest's axes), and the Size the turned mesh needs.
function MeshKitImport.Placement(frame: any, spec: any, turn: number, C: any, V: any): (any, any)
	local size = MeshKitImport.TurnedSize(spec.Size, turn)
	local cf = frame * C.new(spec.Offset[1], spec.Offset[2], spec.Offset[3]) * C.Angles(0, -turn * math.pi / 2, 0)
	return cf, V.new(size[1], size[2], size[3])
end

return MeshKitImport
