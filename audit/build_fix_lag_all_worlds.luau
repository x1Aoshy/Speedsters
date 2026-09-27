local fs = require("@lune/fs")
local rb = require("@lune/roblox")
local luau = require("@lune/luau")
local serde = require("@lune/serde")

print("==================================================")
print("Building Lag & Streaming Fix Across All 3 Worlds")
print("==================================================")

local files = {
	World1 = "World1Update3New.rbxl",
	World2 = "World2Update3new.rbxl",
	World3 = "World3Update3New.rbxl",
}

local scriptUpdates = {
	World1 = {},
	World2 = {
		{
			source = "src/worlds/World2/StarterPlayer/StarterPlayerScripts/Gameplay/World2TreeSlammers.client.luau",
			segments = { "StarterPlayer", "StarterPlayerScripts", "Gameplay", "World2TreeSlammers" },
		},
	},
	World3 = {
		{
			source = "src/worlds/World3/StarterPlayer/StarterPlayerScripts/Gameplay/World3HazardsClient.client.luau",
			segments = { "StarterPlayer", "StarterPlayerScripts", "Gameplay", "World3HazardsClient" },
		},
	},
}

local function find(dm, path)
	local cur = dm
	for _, name in path do
		cur = assert(cur:FindFirstChild(name), "Missing: " .. table.concat(path, "."))
	end
	return cur
end

local backupDir = "output/Lag_Fix_All_Worlds"
fs.writeDir(backupDir)

local report = {
	worlds = {},
	timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
}

for world, file in files do
	print(string.format("\n--- Processing %s (%s) ---", world, file))
	local raw = fs.readFile(file)
	local dm = rb.deserializePlace(raw)
	local ws = dm:FindFirstChild("Workspace")
	assert(ws, "Workspace missing in " .. file)

	-- 1. Apply Script Updates for this world
	for _, update in ipairs(scriptUpdates[world] or {}) do
		local inst = find(dm, update.segments)
		local newSource = fs.readFile(update.source)
		luau.compile(newSource)
		inst.Source = newSource
		print(string.format("  + Injected script: %s (%d bytes)", table.concat(update.segments, "."), #newSource))
	end

	-- 2. Streaming properties
	local oldMinRadius = ws.StreamingMinRadius
	local oldIntegrity = tostring(ws.StreamingIntegrityMode)
	local oldStreamOut = tostring(ws.StreamOutBehavior)
	local oldThrottling = tostring(ws.ClientAnimatorThrottling)

	ws.StreamingMinRadius = 512
	ws.StreamingTargetRadius = 1024
	ws.StreamingIntegrityMode = rb.Enum.StreamingIntegrityMode.Disabled
	ws.StreamOutBehavior = rb.Enum.StreamOutBehavior.LowMemory
	ws.ClientAnimatorThrottling = rb.Enum.ClientAnimatorThrottlingMode.Disabled

	print(string.format("  + Streaming settings updated:"))
	print(string.format("      MinRadius: %s -> %s", tostring(oldMinRadius), tostring(ws.StreamingMinRadius)))
	print(string.format("      Integrity: %s -> %s", oldIntegrity, tostring(ws.StreamingIntegrityMode)))
	print(string.format("      StreamOut: %s -> %s", oldStreamOut, tostring(ws.StreamOutBehavior)))
	print(string.format("      AnimThrottling: %s -> %s", oldThrottling, tostring(ws.ClientAnimatorThrottling)))

	-- 3. Anchor unanchored parts
	local unanchoredBefore = 0
	local anchoredList = {}
	for _, inst in ws:GetDescendants() do
		if inst:IsA("BasePart") and not inst.Anchored then
			unanchoredBefore += 1
			table.insert(anchoredList, inst:GetFullName())
			inst.Anchored = true
		end
	end
	print(string.format("  + Unanchored parts in Workspace: %d anchored to 0", unanchoredBefore))

	-- 4. Verify all LuaSourceContainers compile
	local compiledCount = 0
	for _, inst in dm:GetDescendants() do
		if inst:IsA("LuaSourceContainer") then
			local ok, err = pcall(luau.compile, inst.Source)
			assert(ok, "Compilation failed in " .. inst:GetFullName() .. ": " .. tostring(err))
			compiledCount += 1
		end
	end
	print(string.format("  + All %d scripts compiled successfully with zero errors", compiledCount))

	-- 5. Serialize and round-trip verify
	local serialized = rb.serializePlace(dm)
	local decoded = rb.deserializePlace(serialized)
	local decodedWs = decoded:FindFirstChild("Workspace")

	assert(decodedWs.StreamingMinRadius == 512, world .. " StreamingMinRadius mismatch")
	assert(decodedWs.StreamingTargetRadius == 1024, world .. " StreamingTargetRadius mismatch")
	assert(decodedWs.StreamingIntegrityMode == rb.Enum.StreamingIntegrityMode.Disabled, world .. " StreamingIntegrityMode mismatch")
	assert(decodedWs.StreamOutBehavior == rb.Enum.StreamOutBehavior.LowMemory, world .. " StreamOutBehavior mismatch")
	assert(decodedWs.ClientAnimatorThrottling == rb.Enum.ClientAnimatorThrottlingMode.Disabled, world .. " ClientAnimatorThrottling mismatch")

	local unanchoredAfter = 0
	for _, inst in decodedWs:GetDescendants() do
		if inst:IsA("BasePart") and not inst.Anchored then
			unanchoredAfter += 1
		end
	end
	assert(unanchoredAfter == 0, world .. " still has " .. unanchoredAfter .. " unanchored parts after build!")

	-- Verify scripts round-trip
	for _, update in ipairs(scriptUpdates[world] or {}) do
		local inst = find(decoded, update.segments)
		assert(inst.Source == fs.readFile(update.source), world .. " script round-trip source mismatch for " .. update.source)
	end

	-- 6. Write out files
	fs.writeFile(file, serialized)
	fs.writeFile(backupDir .. "/" .. file, serialized)
	print(string.format("  [SUCCESS] Written %s (%d bytes)", file, #serialized))

	report.worlds[world] = {
		file = file,
		bytes = #serialized,
		compiledScripts = compiledCount,
		unanchoredFixed = unanchoredBefore,
		streaming = {
			minRadius = 512,
			targetRadius = 1024,
			integrity = "Disabled",
			streamOut = "LowMemory",
			clientAnimatorThrottling = "Disabled",
		},
	}
end

fs.writeFile("audit/build_fix_lag_report.json", serde.encode("json", report, true))
print("\n==================================================")
print("BUILD COMPLETED WITH 100% SUCCESS!")
print("==================================================")
