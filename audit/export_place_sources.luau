-- audit/export_place_sources.luau  (2026-09-25)
-- Read-only on the places: writes the Source every manifest row carries in the three root places
-- into <out>/<path under src/>, i.e. a backup_src tree of what the places carry NOW. A build
-- script uses such a tree as its guard baseline after a previous build (a guard against the src
-- of before that build would refuse every file it already put in).
-- A common source must be identical in the three places; a difference is printed and the World1
-- copy kept.
--   lune run audit/export_place_sources.luau output/Update4/places_v1_src
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local out = assert(process.args[1], "usage: lune run audit/export_place_sources.luau <out dir>")
out = out:gsub("/$", "")
local PLACES = {
	{ key = "World1", file = "World1Update3New.rbxl" },
	{ key = "World2", file = "World2Update3new.rbxl" },
	{ key = "World3", file = "World3Update3New.rbxl" },
}

local function parentDir(path)
	return path:match("^(.*)/[^/]+$")
end

local manifest = serde.decode("json", fs.readFile("src/manifest.json"))
local written, differences, missing = {}, 0, 0
for _, place in PLACES do
	local dm = roblox.deserializePlace(fs.readFile(place.file))
	for _, row in manifest.worlds[place.key].scripts do
		local source = row.source
		if type(source) == "string" and source:sub(1, 4) == "src/" and row.duplicate ~= true then
			local node = dm
			for _, name in row.segments do
				node = node and node:FindFirstChild(name)
			end
			if node and node:IsA("LuaSourceContainer") then
				local relative = source:sub(5)
				local target = out .. "/" .. relative
				if written[relative] == nil then
					fs.writeDir(parentDir(target))
					fs.writeFile(target, node.Source)
					written[relative] = node.Source
				elseif written[relative] ~= node.Source then
					differences += 1
					print(("DIFFERS %s: %s carries another copy (kept the first)"):format(relative, place.key))
				end
			else
				missing += 1
			end
		end
	end
end
local count = 0
for _ in written do
	count += 1
end
print(("exported %d sources to %s (%d differences between places, %d rows without a script)"):format(count, out, differences, missing))
