-- audit/build_fable_tutorial_portal.luau  (2026-09-20)
-- Puts the tutorial / portal-flight fixes into the three places:
--   * sources from src/common (rows come from src/manifest.json; new scripts get a row);
--   * the saved Evolve "!" badge in StarterGui, smaller and inside its button.
-- Nothing is written unless every world verified; the places are backed up first, and every
-- script Source that gets replaced is saved beside the backup.
local fs = require("@lune/fs")
local rb = require("@lune/roblox")
local luau = require("@lune/luau")
local serde = require("@lune/serde")

local OUTPUT = "output/FableTutorialPortal"
local COMMON = "src/common/"
local SOURCES = {
	{ path = "ReplicatedStorage/Shared/TutorialGuide.luau" },
	{ path = "ReplicatedStorage/Shared/TutorialGuideLayout.luau" },
	{ path = "ReplicatedStorage/Shared/TutorialFlow.luau", class = "ModuleScript" },
	{ path = "ReplicatedStorage/Shared/WorldPortalShot.luau", class = "ModuleScript" },
	-- In the places since the 2026-09-20 cinematic build, but never given a manifest row.
	{ path = "StarterPlayer/StarterPlayerScripts/UI/WorldPortalCinematic.client.luau", class = "LocalScript" },
	{ path = "StarterPlayer/StarterPlayerScripts/UI/FirstTimeTutorial.client.luau", guarded = true },
	{ path = "StarterPlayer/StarterPlayerScripts/UI/EvolveController.client.luau", guarded = true },
	{ path = "StarterPlayer/StarterPlayerScripts/UI/MainHUDController.client.luau", guarded = true },
	{ path = "ServerScriptService/Social/FirstTimeTutorial.server.luau", guarded = true },
	{ path = "ServerScriptService/Worlds/WorldPortalService.server.luau", guarded = true },
}
local WORLDS = {
	{ "World1", "World1Update3New.rbxl" },
	{ "World2", "World2Update3new.rbxl" },
	{ "World3", "World3Update3New.rbxl" },
}
local BADGE_SIZE = rb.UDim2.new(0.34, 0, 0.34, 0)
local BADGE_POSITION = rb.UDim2.new(0.83, 0, 0.14, 0)

local function lf(text)
	return (text:gsub("\r\n", "\n"))
end

local function segmentsOf(path)
	local segments = {}
	for name in path:gmatch("[^/]+") do
		table.insert(segments, name)
	end
	segments[#segments] = segments[#segments]:gsub("%.client%.luau$", ""):gsub("%.server%.luau$", ""):gsub("%.luau$", "")
	return segments
end

for _, spec in SOURCES do
	local bytecode = luau.compile(fs.readFile(COMMON .. spec.path))
	assert(#bytecode > 0, spec.path)
end
print("compiled " .. #SOURCES .. " sources")

local manifest = serde.decode("json", fs.readFile("src/manifest.json"))
fs.writeDir(OUTPUT)
fs.writeDir(OUTPUT .. "/backup")
local prepared, report = {}, { worlds = {}, sources = {}, studioPlaytest = false }
for _, spec in SOURCES do
	table.insert(report.sources, spec.path)
end

for _, world in WORLDS do
	local key, file = world[1], world[2]
	local raw = fs.readFile(file)
	local dm = rb.deserializePlace(raw)
	local rows = {}
	for _, row in manifest.worlds[key].scripts do
		rows[row.source] = row
	end
	fs.writeDir(OUTPUT .. "/backup/" .. key)
	local notes = {}
	for _, spec in SOURCES do
		local full = COMMON .. spec.path
		local row = rows[full]
		if not row then
			assert(spec.class, key .. ": no manifest row for " .. spec.path)
			local segments = segmentsOf(spec.path)
			row = { added = true, class = spec.class, duplicate = false, source = full, segments = segments,
				path = table.concat(segments, "."), legacyPath = table.concat(segments, "/") }
			table.insert(manifest.worlds[key].scripts, row)
			rows[full] = row
			table.insert(notes, "manifest row added: " .. row.path)
		end
		local node = dm
		for index, name in row.segments do
			local child = node:FindFirstChild(name)
			if not child then
				assert(index == #row.segments and spec.class, key .. ": missing " .. table.concat(row.segments, "."))
				child = rb.Instance.new(spec.class)
				child.Name = name
				child.Parent = node
				table.insert(notes, "script created: " .. row.path)
			end
			node = child
		end
		assert(node.ClassName == row.class, key .. ": " .. row.path .. " is a " .. node.ClassName)
		local wanted = fs.readFile(full)
		if node.Source ~= wanted then
			-- A guarded script must still be what this work started from; otherwise someone
			-- edited it in Studio meanwhile and this build would silently undo that.
			local before = OUTPUT .. "/backup_src/" .. row.segments[#row.segments] .. (spec.path:match("%.client%.luau$") or spec.path:match("%.server%.luau$") or ".luau")
			if spec.guarded and node.Source ~= "" then
				assert(fs.isFile(before), "missing " .. before)
				assert(lf(node.Source) == lf(fs.readFile(before)), key .. ": " .. row.path .. " was edited in the place since src was read; export it first")
			end
			if node.Source ~= "" then
				fs.writeFile(OUTPUT .. "/backup/" .. key .. "/" .. row.path .. ".luau", node.Source)
			end
			node.Source = wanted
		end
	end

	local badge = dm:GetService("StarterGui").Mainhud.LeftSideBar.Evolve:FindFirstChild("!")
	assert(badge and badge:IsA("Frame"), key .. ": the Evolve badge is not where it was")
	badge.Size = BADGE_SIZE
	badge.Position = BADGE_POSITION

	local count = #dm:GetDescendants()
	local result = rb.serializePlace(dm)
	local check = rb.deserializePlace(result)
	assert(#check:GetDescendants() == count, key .. ": instance count changed in the round trip")
	for _, spec in SOURCES do
		local node = check
		for _, name in rows[COMMON .. spec.path].segments do
			node = assert(node:FindFirstChild(name))
		end
		assert(node.Source == fs.readFile(COMMON .. spec.path), key .. ": " .. spec.path .. " did not survive the round trip")
	end
	local savedBadge = check:GetService("StarterGui").Mainhud.LeftSideBar.Evolve["!"]
	assert(math.abs(savedBadge.Size.X.Scale - 0.34) < 1e-4)
	if not fs.isFile(OUTPUT .. "/backup/" .. file) then
		fs.writeFile(OUTPUT .. "/backup/" .. file, raw)
	end
	table.insert(prepared, { file = file, before = raw, after = result })
	report.worlds[key] = { instances = count, sha256 = serde.hash("sha256", result), notes = notes }
	print("verified " .. key .. " (" .. count .. " instances) " .. table.concat(notes, "; "))
end

for _, item in prepared do
	assert(fs.readFile(item.file) == item.before, item.file .. " changed on disk during the build (saved from Studio?)")
end
for _, item in prepared do
	fs.writeFile(item.file, item.after)
	fs.writeFile(OUTPUT .. "/" .. item.file, item.after)
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
fs.writeFile(OUTPUT .. "/validation.json", serde.encode("json", report, true))
print("saved the three places, " .. OUTPUT .. " and the manifest (" .. total .. " common sources)")
