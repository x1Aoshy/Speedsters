local fs = require("@lune/fs")
local rb = require("@lune/roblox")
local luau = require("@lune/luau")
local serde = require("@lune/serde")

print("================================================================")
print("Building Win Pad Instant Feedback & Treadmill Fluid Spam Fixes")
print("================================================================")

local files = {
	World1 = "World1Update3New.rbxl",
	World2 = "World2Update3new.rbxl",
	World3 = "World3Update3New.rbxl",
}

local commonUpdates = {
	{ source = "src/common/ReplicatedStorage/Shared/Config.luau", segments = { "ReplicatedStorage", "Shared", "Config" } },
	{ source = "src/common/ServerScriptService/Services/RewardPadClaims.luau", segments = { "ServerScriptService", "Services", "RewardPadClaims" } },
	{ source = "src/common/ServerScriptService/Progression/TreadmillTraining.server.luau", segments = { "ServerScriptService", "Progression", "TreadmillTraining" } },
	{ source = "src/common/StarterPlayer/StarterPlayerScripts/Movement/SpeedsterClient.client.luau", segments = { "StarterPlayer", "StarterPlayerScripts", "Movement", "SpeedsterClient" } },
}

local function find(dm, path)
	local cur = dm
	for _, name in path do
		cur = assert(cur:FindFirstChild(name), "Missing: " .. table.concat(path, "."))
	end
	return cur
end

-- Backup folder
local backupDir = "output/Pad_Treadmill_Fixes_Backup"
fs.writeDir(backupDir)

-- 1. Sync audit/merged and audit/new_spin_global folders
for _, world in { "World1", "World2", "World3" } do
	local mergedTreadmill = "audit/merged/" .. world .. "/ServerScriptService/Progression/TreadmillTraining.luau"
	local mergedSpeedster = "audit/merged/" .. world .. "/StarterPlayer/StarterPlayerScripts/Movement/SpeedsterClient.luau"
	local mergedConfig = "audit/merged/" .. world .. "/ReplicatedStorage/Shared/Config.luau"
	local mergedPad = "audit/merged/" .. world .. "/ServerScriptService/Services/RewardPadClaims.luau"

	if fs.isFile(mergedTreadmill) then
		fs.writeFile(mergedTreadmill, fs.readFile("src/common/ServerScriptService/Progression/TreadmillTraining.server.luau"))
	end
	if fs.isFile(mergedSpeedster) then
		fs.writeFile(mergedSpeedster, fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/Movement/SpeedsterClient.client.luau"))
	end
	if fs.isFile(mergedConfig) then
		fs.writeFile(mergedConfig, fs.readFile("src/common/ReplicatedStorage/Shared/Config.luau"))
	end
	if fs.isFile(mergedPad) then
		fs.writeFile(mergedPad, fs.readFile("src/common/ServerScriptService/Services/RewardPadClaims.luau"))
	end

	local newSpinTreadmill = "audit/new_spin_global/" .. world .. "/ServerScriptService/Progression/TreadmillTraining.luau"
	local newSpinSpeedster = "audit/new_spin_global/" .. world .. "/StarterPlayer/StarterPlayerScripts/Movement/SpeedsterClient.luau"
	local newSpinConfig = "audit/new_spin_global/" .. world .. "/ReplicatedStorage/Shared/Config.luau"
	local newSpinPad = "audit/new_spin_global/" .. world .. "/ServerScriptService/Services/RewardPadClaims.luau"

	if fs.isFile(newSpinTreadmill) then
		fs.writeFile(newSpinTreadmill, fs.readFile("src/common/ServerScriptService/Progression/TreadmillTraining.server.luau"))
	end
	if fs.isFile(newSpinSpeedster) then
		fs.writeFile(newSpinSpeedster, fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/Movement/SpeedsterClient.client.luau"))
	end
	if fs.isFile(newSpinConfig) then
		fs.writeFile(newSpinConfig, fs.readFile("src/common/ReplicatedStorage/Shared/Config.luau"))
	end
	if fs.isFile(newSpinPad) then
		fs.writeFile(newSpinPad, fs.readFile("src/common/ServerScriptService/Services/RewardPadClaims.luau"))
	end
end
print("  ✓ Synced audit/merged and audit/new_spin_global mirror files")

-- 2. Inject into all 3 place files
for world, file in files do
	print(string.format("\n--- Processing %s (%s) ---", world, file))
	local raw = fs.readFile(file)
	local dm = rb.deserializePlace(raw)

	for _, update in ipairs(commonUpdates) do
		local inst = find(dm, update.segments)
		local newSource = fs.readFile(update.source)
		-- Validate syntax compilation
		local bytecode = luau.compile(newSource)
		assert(#bytecode > 0, "Compilation failed for " .. update.source)
		inst.Source = newSource
		print(string.format("  + Injected: %s (%d bytes)", table.concat(update.segments, "."), #newSource))
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
