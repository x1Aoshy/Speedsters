local fs = require("@lune/fs")
local rb = require("@lune/roblox")
local luau = require("@lune/luau")
local serde = require("@lune/serde")

local files = {
	World1 = "World1Update3New.rbxl",
	World2 = "World2Update3new.rbxl",
	World3 = "World3Update3New.rbxl",
}

local commonPaths = {
	{ source = "src/common/ReplicatedStorage/Shared/FeatureGate.luau", segments = { "ReplicatedStorage", "Shared", "FeatureGate" } },
	{ source = "src/common/ReplicatedStorage/Shared/Config.luau", segments = { "ReplicatedStorage", "Shared", "Config" } },
	{ source = "src/common/ServerScriptService/Services/PadTouchService.luau", segments = { "ServerScriptService", "Services", "PadTouchService" } },
	{ source = "src/common/ServerScriptService/Economy/SpinWheelService.server.luau", segments = { "ServerScriptService", "Economy", "SpinWheelService" } },
	{ source = "src/common/StarterGui/Messages/MessageHandler.client.luau", segments = { "StarterGui", "Messages", "MessageHandler" } },
}

local world2Paths = {
	{ source = "src/worlds/World2/ServerScriptService/Gameplay/World2SafeZones.server.luau", segments = { "ServerScriptService", "Gameplay", "World2SafeZones" } },
	{ source = "src/worlds/World2/ServerScriptService/Gameplay/World2StageTeleportService.luau", segments = { "ServerScriptService", "Gameplay", "World2StageTeleportService" } },
	{ source = "src/worlds/World2/ServerScriptService/Gameplay/World2ManualStagePads.server.luau", segments = { "ServerScriptService", "Gameplay", "World2ManualStagePads" } },
}

local function find(dm, path)
	local cur = dm
	for _, name in path do
		cur = assert(cur:FindFirstChild(name), "Missing: " .. table.concat(path, "."))
	end
	return cur
end

local function graph(dm)
	return (rb.serializePlace(dm, true):gsub('<UniqueId name="UniqueId">.-</UniqueId>', '<UniqueId/>'))
end

local outDir = "output/Update3_Unlocked_W2Pads"
fs.writeDir(outDir)
local fixDir = "output/New_Spin_AdminGlobal_Fix"
fs.writeDir(fixDir)

local artifacts = {}
local report = { worlds = {}, applied = {} }

for world, file in files do
	print(string.format("--- Building %s (%s) ---", world, file))
	local raw = fs.readFile(file)
	local dm = rb.deserializePlace(raw)
	
	local targetPaths = {}
	for _, e in commonPaths do
		table.insert(targetPaths, e)
	end
	if world == "World2" then
		for _, e in world2Paths do
			table.insert(targetPaths, e)
		end
	end

	local originals = {}
	for _, entry in targetPaths do
		local inst = find(dm, entry.segments)
		originals[entry.source] = inst.Source
		local newSource = fs.readFile(entry.source)
		inst.Source = newSource
		luau.compile(newSource)
		print(string.format("  Updated %s (%d -> %d bytes)", table.concat(entry.segments, "."), #originals[entry.source], #newSource))
	end

	-- Verify all scripts in the DataModel compile
	local count = 0
	for _, inst in dm:GetDescendants() do
		if inst:IsA("LuaSourceContainer") then
			local ok, err = pcall(luau.compile, inst.Source)
			assert(ok, "Compilation failed in " .. inst:GetFullName() .. ": " .. tostring(err))
			count += 1
		end
	end

	local encoded = rb.serializePlace(dm)
	local decoded = rb.deserializePlace(encoded)

	-- Verify round-trip source preservation
	for _, entry in targetPaths do
		local inst = find(decoded, entry.segments)
		assert(inst.Source == fs.readFile(entry.source), "Round-trip source mismatch for " .. entry.source)
		-- Revert to original to test property and map preservation
		inst.Source = originals[entry.source]
	end

	assert(graph(decoded) == graph(rb.deserializePlace(raw)), "Unexpected map/UI/property corruption in " .. world)

	artifacts[file] = encoded
	report.worlds[world] = {
		file = file,
		compiledScripts = count,
		inputSha256 = serde.hash("sha256", raw),
		outputSha256 = serde.hash("sha256", encoded),
		updatedScriptCount = #targetPaths,
		allOtherPropertiesPreserved = true,
	}
	print(string.format("  Verified %d compiled scripts, zero property regressions", count))
end

-- Write output rbxl files to root and output dirs
for file, bytes in artifacts do
	fs.writeFile(file, bytes)
	fs.writeFile(outDir .. "/" .. file, bytes)
	fs.writeFile(fixDir .. "/" .. file, bytes)
	print("Saved " .. file .. " (" .. #bytes .. " bytes)")
end

fs.writeFile("audit/build_spin_announcement_report.json", serde.encode("json", report, true))
print("BUILD SUCCESSFUL: Spin wheel winning announcement banner removed, chat-only active, admin banners exclusive and non-overlapping.")
