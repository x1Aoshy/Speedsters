-- audit/fable_build_lib.luau
-- Shared by the audit/build_fable_*.luau scripts: puts sources from src/ into the root places by
-- their manifest rows (adding the row and the script when new), lets the caller edit authored
-- instances, verifies a serialize round trip, and only then writes. Places are backed up once
-- per output folder; every replaced Source is saved beside the backup.
local fs = require("@lune/fs")
local rb = require("@lune/roblox")
local luau = require("@lune/luau")
local serde = require("@lune/serde")

local Lib = {}
Lib.Places = {
	{ key = "World1", file = "World1Update3New.rbxl" },
	{ key = "World2", file = "World2Update3new.rbxl" },
	{ key = "World3", file = "World3Update3New.rbxl" },
}

local function lf(text)
	return (text:gsub("\r\n", "\n"))
end

local function segmentsOf(source)
	local relative = source:gsub("^src/common/", ""):gsub("^src/worlds/[^/]+/", "")
	local segments = {}
	for name in relative:gmatch("[^/]+") do
		table.insert(segments, name)
	end
	segments[#segments] = segments[#segments]:gsub("%.client%.luau$", ""):gsub("%.server%.luau$", ""):gsub("%.luau$", "")
	return segments
end

local function classOf(source)
	if source:match("%.client%.luau$") then
		return "LocalScript"
	elseif source:match("%.server%.luau$") then
		return "Script"
	end
	return "ModuleScript"
end

local function wants(spec, key)
	if not spec.worlds then
		return true
	end
	return table.find(spec.worlds, key) ~= nil
end

-- options: output (folder), sources = { { source, worlds?, guard? } }, edit(key, dm, notes)? (returns true
-- when it changed the place), verify(key, dm)?, dryRun? (2026-09-25, Update 4: everything up to and
-- including the round trip and verify runs, then it returns before any write: no place, backup,
-- output folder, manifest or validation file is touched), createFolders? (2026-09-25, Update 4: a new
-- script whose folders do not exist yet, e.g. StarterPlayerScripts.Race or Services.Data.U4, gets
-- them as Folders; only for rows this build adds, never for authored ones). A place with nothing
-- to change is not rewritten.
-- guard: a file holding the Source the place is expected to still carry (the src before this
-- work); anything else means it was edited in Studio meanwhile and the build stops.
function Lib.run(options)
	local output = options.output
	local dryRun = options.dryRun == true
	if not dryRun then
		fs.writeDir(output)
		fs.writeDir(output .. "/backup")
	end
	for _, spec in options.sources do
		local bytecode = luau.compile(fs.readFile(spec.source))
		assert(#bytecode > 0, spec.source)
	end
	print("compiled " .. #options.sources .. " sources")

	local manifest = serde.decode("json", fs.readFile("src/manifest.json"))
	local prepared, report = {}, { worlds = {}, studioPlaytest = false }
	for _, place in Lib.Places do
		local key, file = place.key, place.file
		local raw = fs.readFile(file)
		local dm = rb.deserializePlace(raw)
		local rows, notes = {}, {}
		for _, row in manifest.worlds[key].scripts do
			rows[row.source] = row
		end
		if not dryRun then
			fs.writeDir(output .. "/backup/" .. key)
		end
		local touched = {}
		for _, spec in options.sources do
			if not wants(spec, key) then
				continue
			end
			local row = rows[spec.source]
			if not row then
				local segments = segmentsOf(spec.source)
				row = { added = true, class = classOf(spec.source), duplicate = false, source = spec.source,
					segments = segments, path = table.concat(segments, "."), legacyPath = table.concat(segments, "/") }
				table.insert(manifest.worlds[key].scripts, row)
				rows[spec.source] = row
				table.insert(notes, "row+ " .. row.path)
			end
			-- Twins share one path and the walk below follows only the first of them.
			assert(row.duplicate ~= true, key .. ": " .. row.path .. " is one of several same-named scripts; change them in the edit callback")
			local node = dm
			for index, name in row.segments do
				local child = node:FindFirstChild(name)
				if not child and index > 1 and index < #row.segments and options.createFolders == true and row.added == true then
					child = rb.Instance.new("Folder")
					child.Name = name
					child.Parent = node
					table.insert(notes, "folder " .. table.concat(row.segments, ".", 1, index))
				end
				if not child then
					assert(index == #row.segments, key .. ": missing container " .. table.concat(row.segments, "."))
					-- An authored row that ends here sits under a same-named twin of this parent
					-- (World 1's water scripts): creating it here would put a second script in the wrong part.
					assert(row.added == true, key .. ": " .. row.path .. " is authored, but not under the first " .. table.concat(row.segments, ".", 1, index - 1))
					child = rb.Instance.new(row.class)
					child.Name = name
					child.Parent = node
					table.insert(notes, "new " .. row.path)
				end
				node = child
			end
			assert(node.ClassName == row.class, key .. ": " .. row.path .. " is a " .. node.ClassName)
			local wanted = fs.readFile(spec.source)
			if node.Source ~= wanted then
				if spec.guard and node.Source ~= "" then
					assert(fs.isFile(spec.guard), "missing guard " .. spec.guard)
					assert(lf(node.Source) == lf(fs.readFile(spec.guard)),
						key .. ": " .. row.path .. " differs from what this work started from (edited in Studio?); export it first")
				end
				if node.Source ~= "" and not dryRun then
					fs.writeFile(output .. "/backup/" .. key .. "/" .. row.path .. ".luau", node.Source)
				end
				node.Source = wanted
			end
			table.insert(touched, { row = row, source = spec.source })
		end
		local changed = #touched > 0
		if options.edit then
			changed = options.edit(key, dm, notes) == true or changed
		end
		if not changed then
			print("skipped " .. key .. " (nothing of this build belongs to it)")
			continue
		end

		local count = #dm:GetDescendants()
		local result = rb.serializePlace(dm)
		local check = rb.deserializePlace(result)
		assert(#check:GetDescendants() == count, key .. ": instance count changed in the round trip")
		for _, item in touched do
			local node = check
			for _, name in item.row.segments do
				node = assert(node:FindFirstChild(name))
			end
			assert(node.Source == fs.readFile(item.source), key .. ": " .. item.source .. " did not survive the round trip")
		end
		if options.verify then
			options.verify(key, check)
		end
		if not dryRun and not fs.isFile(output .. "/backup/" .. file) then
			fs.writeFile(output .. "/backup/" .. file, raw)
		end
		table.insert(prepared, { file = file, before = raw, after = result })
		report.worlds[key] = { instances = count, sha256 = serde.hash("sha256", result), notes = notes }
		print("verified " .. key .. " (" .. count .. " instances) " .. table.concat(notes, "; "))
	end

	for _, item in prepared do
		assert(fs.readFile(item.file) == item.before, item.file .. " changed on disk during the build (saved from Studio?)")
	end
	if dryRun then
		print("dry run: " .. #prepared .. " place(s) verified, nothing written")
		return report
	end
	for _, item in prepared do
		fs.writeFile(item.file, item.after)
		fs.writeFile(output .. "/" .. item.file, item.after)
	end
	local unique, total = {}, 0
	for _, world in manifest.worlds do
		for _, row in world.scripts do
			if row.source:sub(1, 11) == "src/common/" and not unique[row.source] then
				unique[row.source] = true
				total += 1
			end
		end
	end
	manifest.commonSources = total
	fs.writeFile("src/manifest.json", serde.encode("json", manifest, true))
	fs.writeFile(output .. "/validation.json", serde.encode("json", report, true))
	print("saved the three places, " .. output .. " and the manifest")
end

return Lib
