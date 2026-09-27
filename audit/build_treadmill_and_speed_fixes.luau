local fs = require("@lune/fs")
local rb = require("@lune/roblox")
local luau = require("@lune/luau")

print("================================================================")
print("Building Treadmill Speed Farming & Fluid Popups Fixes")
print("================================================================")

local files = {
	World1 = "World1Update3New.rbxl",
	World2 = "World2Update3new.rbxl",
	World3 = "World3Update3New.rbxl",
}

local commonUpdates = {
	{ source = "src/common/ReplicatedStorage/Shared/Config.luau", segments = { "ReplicatedStorage", "Shared", "Config" } },
	{ source = "src/common/ServerScriptService/Progression/TreadmillTraining.server.luau", segments = { "ServerScriptService", "Progression", "TreadmillTraining" } },
	{ source = "src/common/ServerScriptService/Progression/TreadmillCollisionFix.server.luau", segments = { "ServerScriptService", "Progression", "TreadmillCollisionFix" } },
	{ source = "src/common/StarterPlayer/StarterPlayerScripts/Movement/SpeedsterClient.client.luau", segments = { "StarterPlayer", "StarterPlayerScripts", "Movement", "SpeedsterClient" } },
	{ source = "src/common/StarterPlayer/StarterPlayerScripts/Audio/RunningAndTreadmillSound.client.luau", segments = { "StarterPlayer", "StarterPlayerScripts", "Audio", "RunningAndTreadmillSound" } },
}

local function find(dm, path)
	local cur = dm
	for _, name in ipairs(path) do
		cur = assert(cur:FindFirstChild(name), "Missing: " .. table.concat(path, "."))
	end
	return cur
end

-- Backup folder
local backupDir = "output/Treadmill_Speed_Fixes_Backup"
fs.writeDir(backupDir)

-- 1. Sync audit/merged and audit/new_spin_global folders
for _, world in { "World1", "World2", "World3" } do
	local syncPairs = {
		{
			src = "src/common/ReplicatedStorage/Shared/Config.luau",
			merged = "audit/merged/" .. world .. "/ReplicatedStorage/Shared/Config.luau",
			newSpin = "audit/new_spin_global/" .. world .. "/ReplicatedStorage/Shared/Config.luau",
		},
		{
			src = "src/common/ServerScriptService/Progression/TreadmillTraining.server.luau",
			merged = "audit/merged/" .. world .. "/ServerScriptService/Progression/TreadmillTraining.luau",
			newSpin = "audit/new_spin_global/" .. world .. "/ServerScriptService/Progression/TreadmillTraining.luau",
		},
		{
			src = "src/common/ServerScriptService/Progression/TreadmillCollisionFix.server.luau",
			merged = "audit/merged/" .. world .. "/ServerScriptService/Progression/TreadmillCollisionFix.luau",
			newSpin = "audit/new_spin_global/" .. world .. "/ServerScriptService/Progression/TreadmillCollisionFix.luau",
		},
		{
			src = "src/common/StarterPlayer/StarterPlayerScripts/Movement/SpeedsterClient.client.luau",
			merged = "audit/merged/" .. world .. "/StarterPlayer/StarterPlayerScripts/Movement/SpeedsterClient.luau",
			newSpin = "audit/new_spin_global/" .. world .. "/StarterPlayer/StarterPlayerScripts/Movement/SpeedsterClient.luau",
		},
		{
			src = "src/common/StarterPlayer/StarterPlayerScripts/Audio/RunningAndTreadmillSound.client.luau",
			merged = "audit/merged/" .. world .. "/StarterPlayer/StarterPlayerScripts/Audio/RunningAndTreadmillSound.luau",
			newSpin = "audit/new_spin_global/" .. world .. "/StarterPlayer/StarterPlayerScripts/Audio/RunningAndTreadmillSound.luau",
		},
	}

	for _, pair in ipairs(syncPairs) do
		local content = fs.readFile(pair.src)
		if fs.isFile(pair.merged) then
			fs.writeFile(pair.merged, content)
		end
		if fs.isFile(pair.newSpin) then
			fs.writeFile(pair.newSpin, content)
		end
	end
end
print("  ✓ Synced audit/merged and audit/new_spin_global mirror files")

-- 2. Validate all sources compile before injecting
for _, update in ipairs(commonUpdates) do
	local src = fs.readFile(update.source)
	local bytecode = luau.compile(src)
	assert(#bytecode > 0, "Compilation failed for " .. update.source)
	print(string.format("  ✓ Compiled %s (%d bytes bytecode)", update.source, #bytecode))
end

-- 3. Inject into all 3 place files
for world, file in pairs(files) do
	print(string.format("\n--- Processing %s (%s) ---", world, file))
	local raw = fs.readFile(file)
	local dm = rb.deserializePlace(raw)

	for _, update in ipairs(commonUpdates) do
		local inst = find(dm, update.segments)
		local newSource = fs.readFile(update.source)
		inst.Source = newSource
		print(string.format("  + Injected: %s (%d bytes source)", table.concat(update.segments, "."), #newSource))
	end

	-- Save backup
	local backupFile = backupDir .. "/" .. file
	fs.writeFile(backupFile, raw)

	-- Save place
	local outRaw = rb.serializePlace(dm)
	fs.writeFile(file, outRaw)
	print(string.format("  ✓ Successfully serialized and saved %s (%d bytes)", file, #outRaw))
end

print("\n================================================================")
print("BUILD COMPLETED: All 3 places updated cleanly!")
print("================================================================")
