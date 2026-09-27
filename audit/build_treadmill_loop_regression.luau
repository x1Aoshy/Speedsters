local fs = require("@lune/fs")
local rb = require("@lune/roblox")
local luau = require("@lune/luau")
local serde = require("@lune/serde")
local stamp = os.date("!%Y%m%d_%H%M%S")
local backup = "output/Backup_TreadmillLoop_" .. stamp
local output = "output/TreadmillLoop_Fixed_" .. stamp
local files = { World1 = "World1Update3New.rbxl", World2 = "World2Update3new.rbxl", World3 = "World3Update3New.rbxl" }
local updates = {
	{ name = "TreadmillTraining", source = "src/common/ServerScriptService/Progression/TreadmillTraining.server.luau",
		path = { "ServerScriptService", "Progression", "TreadmillTraining" } },
	{ name = "SpeedsterClient", source = "src/common/StarterPlayer/StarterPlayerScripts/Movement/SpeedsterClient.client.luau",
		path = { "StarterPlayer", "StarterPlayerScripts", "Movement", "SpeedsterClient" } },
}
local function find(dm, path)
	local node = dm
	for _, name in path do node = assert(node:FindFirstChild(name), name) end
	return node
end
for _, update in updates do
	update.content = fs.readFile(update.source)
	luau.compile(update.content)
end
fs.writeDir(backup)
fs.writeDir(output)
local report = { backup = backup, output = output, worlds = {} }
-- Prepare and verify all outputs before changing the three root places.
local prepared = {}
for world, file in files do
	local raw = fs.readFile(file)
	local dm = rb.deserializePlace(raw)
	local originalSources = {}
	for _, inst in dm:GetDescendants() do
		if inst:IsA("LuaSourceContainer") then originalSources[inst:GetFullName()] = inst.Source end
	end
	for _, update in updates do
		local inst = find(dm, update.path)
		assert(inst.Source == fs.readFile("audit/treadmill_regression/" .. world .. "/" .. update.name .. ".luau"),
			"Place changed since inspection: " .. world .. "/" .. update.name)
		inst.Source = update.content
	end
	local bytes = rb.serializePlace(dm)
	local verified = rb.deserializePlace(bytes)
	local changed = {}
	for _, inst in verified:GetDescendants() do
		if inst:IsA("LuaSourceContainer") and inst.Source ~= originalSources[inst:GetFullName()] then
			table.insert(changed, inst:GetFullName())
		end
	end
	assert(#changed == 2, "Only the two intended scripts may change")
	for _, update in updates do assert(find(verified, update.path).Source == update.content) end
	assert(#dm:GetDescendants() == #verified:GetDescendants(), "Instance count changed")
	fs.writeFile(backup .. "/" .. file, raw)
	fs.writeFile(output .. "/" .. file, bytes)
	prepared[world] = { raw = raw, bytes = bytes }
	report.worlds[world] = { file = file, scripts = changed, instances = #verified:GetDescendants() }
end
for world, file in files do
	assert(fs.readFile(file) == prepared[world].raw, "Concurrent place edit detected: " .. file)
	fs.writeFile(file, prepared[world].bytes)
	for _, update in updates do
		for _, mirrorRoot in { "audit/merged", "audit/new_spin_global" } do
			local path = mirrorRoot .. "/" .. world .. "/" .. table.concat(update.path, "/") .. ".luau"
			if fs.isFile(path) and fs.readFile(path) == fs.readFile("audit/treadmill_regression/" .. world .. "/" .. update.name .. ".luau") then
				fs.writeFile(path, update.content)
			end
		end
	end
	print("PASS saved and re-read " .. file .. " (only 2 scripts changed)")
end
fs.writeFile("audit/treadmill_loop_fix_report.json", serde.encode("json", report, true))
print("Backup: " .. backup)
print("Fixed copies: " .. output)
