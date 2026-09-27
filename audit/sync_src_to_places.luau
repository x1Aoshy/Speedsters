--!strict
-- audit/sync_src_to_places.luau
-- Synchronizes all updated sources from src/ into the root .rbxl place files
-- (World1Update3New.rbxl, World2Update3new.rbxl, World3Update3New.rbxl)
-- matching exact instance paths defined in src/manifest.json.

local fs = require("@lune/fs")
local rb = require("@lune/roblox")
local luau = require("@lune/luau")
local serde = require("@lune/serde")
local PlaceFiles = require("./place_files")

local manifest = serde.decode("json", fs.readFile("src/manifest.json"))
assert(manifest.formatVersion == 1, "Unsupported manifest formatVersion")

local PLACES = {
	World1 = PlaceFiles.World1,
	World2 = PlaceFiles.World2,
	World3 = PlaceFiles.World3,
}

local function segmentsOf(instance)
	local result = {}
	while instance.Parent do
		table.insert(result, 1, instance.Name)
		instance = instance.Parent
	end
	return table.concat(result, "/")
end

for world, file in pairs(PLACES) do
	print(string.format("=== Synchronizing %s (%s) ===", world, file))
	local raw = fs.readFile(file)
	local place = rb.deserializePlace(raw)

	-- Index place scripts by their path
	local scriptsByPath: { [string]: { any } } = {}
	for _, inst in ipairs(place:GetDescendants()) do
		if inst:IsA("LuaSourceContainer") then
			local path = segmentsOf(inst)
			scriptsByPath[path] = scriptsByPath[path] or {}
			table.insert(scriptsByPath[path], inst)
		end
	end

	local updatedCount = 0
	for _, row in ipairs(manifest.worlds[world].scripts) do
		local expectedSource = fs.readFile(row.source)
		luau.compile(expectedSource) -- ensure syntax is 100% valid

		local instances = scriptsByPath[row.legacyPath]
		if not instances or #instances == 0 then
			error(string.format("Missing instance for %s in %s", row.legacyPath, file))
		end

		for _, inst in ipairs(instances) do
			if inst.Source ~= expectedSource then
				inst.Source = expectedSource
				updatedCount += 1
				print(string.format("  [UPDATED] %s (%s)", row.legacyPath, row.source))
			end
		end
	end

	-- Verify that every script in the place compiles
	local totalScripts = 0
	for _, inst in ipairs(place:GetDescendants()) do
		if inst:IsA("LuaSourceContainer") then
			local ok, err = pcall(luau.compile, inst.Source)
			assert(ok, string.format("Compilation failed in %s: %s", inst:GetFullName(), tostring(err)))
			totalScripts += 1
		end
	end

	local serialized = rb.serializePlace(place)
	fs.writeFile(file, serialized)
	print(string.format("OK %s: %d scripts updated, %d total compiled and saved to %s\n", world, updatedCount, totalScripts, file))
end

print("ALL PLACES SYNCHRONIZED SUCCESSFULLY!")
