local fs = require("@lune/fs")
local rb = require("@lune/roblox")
local luau = require("@lune/luau")

print("=== Running test_world_lag_and_streaming.luau ===")

local places = {
	World1 = "World1Update3New.rbxl",
	World2 = "World2Update3new.rbxl",
	World3 = "World3Update3New.rbxl",
}

for worldName, fileName in places do
	print("\n--- Verifying " .. worldName .. " (" .. fileName .. ") ---")
	local raw = fs.readFile(fileName)
	local dm = rb.deserializePlace(raw)
	local ws = dm:FindFirstChild("Workspace")
	assert(ws, worldName .. ": Workspace not found!")

	-- 1. Verify Streaming Properties
	assert(ws.StreamingEnabled == true, worldName .. ": StreamingEnabled must be true")
	assert(ws.StreamingMinRadius == 512, worldName .. ": StreamingMinRadius must be 512, got: " .. tostring(ws.StreamingMinRadius))
	assert(ws.StreamingTargetRadius == 1024, worldName .. ": StreamingTargetRadius must be 1024, got: " .. tostring(ws.StreamingTargetRadius))
	assert(ws.StreamingIntegrityMode == rb.Enum.StreamingIntegrityMode.Disabled, worldName .. ": StreamingIntegrityMode must be Disabled, got: " .. tostring(ws.StreamingIntegrityMode))
	assert(ws.StreamOutBehavior == rb.Enum.StreamOutBehavior.LowMemory, worldName .. ": StreamOutBehavior must be LowMemory, got: " .. tostring(ws.StreamOutBehavior))
	assert(ws.ClientAnimatorThrottling == rb.Enum.ClientAnimatorThrottlingMode.Disabled, worldName .. ": ClientAnimatorThrottling must be Disabled, got: " .. tostring(ws.ClientAnimatorThrottling))
	print("PASS " .. worldName .. " streaming & animation throttling configuration is optimal")

	-- 2. Verify 0 Unanchored Parts in Workspace
	local unanchoredCount = 0
	local unanchoredParts = {}
	for _, inst in ws:GetDescendants() do
		if inst:IsA("BasePart") and not inst.Anchored then
			unanchoredCount += 1
			table.insert(unanchoredParts, inst:GetFullName())
		end
	end
	assert(unanchoredCount == 0, worldName .. " has " .. unanchoredCount .. " unanchored parts: " .. table.concat(unanchoredParts, ", "))
	print("PASS " .. worldName .. " has 0 unanchored parts in Workspace (clean physics simulation)")

	-- 3. Verify Specific Hazard & Culling Implementations
	if worldName == "World2" then
		local sp = dm:FindFirstChild("StarterPlayer")
		local sps = sp and sp:FindFirstChild("StarterPlayerScripts")
		local gp = sps and sps:FindFirstChild("Gameplay")
		local treeSlammers = gp and gp:FindFirstChild("World2TreeSlammers")
		assert(treeSlammers and treeSlammers:IsA("LocalScript"), "World2TreeSlammers script missing in World 2")
		assert(string.find(treeSlammers.Source, "nearestTreeDistance%(%) > 500"), "World2TreeSlammers missing distance culling check")
		print("PASS World 2 Tree Slammers has distance culling optimization")
	elseif worldName == "World3" then
		local sp = dm:FindFirstChild("StarterPlayer")
		local sps = sp and sp:FindFirstChild("StarterPlayerScripts")
		local gp = sps and sps:FindFirstChild("Gameplay")
		local hazardsClient = gp and gp:FindFirstChild("World3HazardsClient")
		assert(hazardsClient and hazardsClient:IsA("LocalScript"), "World3HazardsClient script missing in World 3")
		assert(string.find(hazardsClient.Source, "entry%.IsHidden"), "World3HazardsClient missing entry.IsHidden caching")
		assert(string.find(hazardsClient.Source, "serpent%.IsHidden"), "World3HazardsClient missing serpent.IsHidden caching")
		print("PASS World 3 Hazards Client has IsHidden caching for tumbleweeds, roadrunners, carts, serpent, and scorpions")
	end

	-- 4. Verify Script Compilation
	local scriptCount = 0
	for _, inst in dm:GetDescendants() do
		if inst:IsA("LuaSourceContainer") then
			scriptCount += 1
			local ok, err = pcall(luau.compile, inst.Source)
			assert(ok, "Compilation failure in " .. inst:GetFullName() .. ": " .. tostring(err))
		end
	end
	print("PASS " .. worldName .. " all " .. scriptCount .. " Lua scripts compile cleanly")
end

print("\n==================================================")
print("ALL LAG & STREAMING AUDIT CHECKS PASSED (100%)!")
print("==================================================")
