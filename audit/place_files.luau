-- audit/place_files.luau
-- The root place files, named once. Tests read them through here, so the next rename is this
-- one edit:   local PlaceFiles = require("./place_files")
-- Paths are relative to the project root, where every audit script is run from.
local PlaceFiles = {
	World1 = "World1Update3New.rbxl",
	World2 = "World2Update3new.rbxl", -- lower-case n, as the file was saved
	World3 = "World3Update3New.rbxl",
}

-- In world order, for loops: { key = "World1", file = "...", world = 1 }, ...
PlaceFiles.Places = {
	{ key = "World1", file = PlaceFiles.World1, world = 1 },
	{ key = "World2", file = PlaceFiles.World2, world = 2 },
	{ key = "World3", file = PlaceFiles.World3, world = 3 },
}

-- Just the file names: PlaceFiles.Files() -> all three, PlaceFiles.Files("World1", "World2") -> those.
function PlaceFiles.Files(...)
	local keys = { ... }
	local files = {}
	if #keys == 0 then
		for _, place in PlaceFiles.Places do
			table.insert(files, place.file)
		end
		return files
	end
	for _, key in keys do
		local file = PlaceFiles[key]
		assert(type(file) == "string", "place_files: no place called " .. tostring(key))
		table.insert(files, file)
	end
	return files
end

return PlaceFiles
