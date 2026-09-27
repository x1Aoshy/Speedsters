local fs = require("@lune/fs")
local rb = require("@lune/roblox")
local luau = require("@lune/luau")
local serde = require("@lune/serde")

print("=== REGRESSION TEST: SPOTLIGHT TUTORIAL AND HELP SYSTEM (ENGLISH & RENDERSTEPPED) ===")

local checks = {
	{
		path = "src/common/StarterPlayer/StarterPlayerScripts/UI/FirstTimeTutorial.client.luau",
		name = "FirstTimeTutorial",
		required = {
			"SpeedsterGuidedSpotlight",
			"SpeedsterGuidedDimmer",
			"DimmerFrame",
			"SKIP (10s) ✕",
			"RenderStepped",
			"HighlightRing",
			"Ripple",
			"PointerContainer",
			"SkipTutorial",
			"TAP BACKPACK",
			"TAP AURAS",
			"EQUIP AURA (+2.5x)",
			"🎉 EQUIPPED! +2.5x SPEED 🎉",
			"Aura05",
			"Trail05",
			"AuraShopAction",
			"TrailShopAction",
			"HoleTap",
			"finishTutorial",
		}
	},
	{
		path = "src/common/StarterPlayer/StarterPlayerScripts/UI/EvolveController.client.luau",
		name = "EvolveController",
		required = {
			"InfoButton",
			"EvolveHelpCard",
			"HOW EVOLVE WORKS",
			"UNLOCK RUNNER SPEED SUITS",
			"GOT IT!",
			"Level & Rebirth Requirements",
			"Massive Speed Boost",
			"Permanent Power",
		}
	},
	{
		path = "src/common/StarterGui/Backpack/BackpackScript.client.luau",
		name = "BackpackScript",
		required = {
			"InfoButton",
			"BackpackHelpCard",
			"INVENTORY GUIDE",
			"AURAS & SPEED TRAILS",
			"GOT IT!",
			"Speed Multipliers",
			"Combine Trail + Aura!",
			"Instant Equip",
		}
	}
}

local sourceContents = {}
for _, c in ipairs(checks) do
	local src = fs.readFile(c.path)
	local bytecode = luau.compile(src)
	assert(#bytecode > 0, "Failed to compile " .. c.name)
	for _, req in ipairs(c.required) do
		assert(string.find(src, req, 1, true), "Missing required snippet in " .. c.name .. ": " .. req)
	end
	sourceContents[c.path] = src
	print("PASS source:", c.name, "(bytecode: " .. #bytecode .. " bytes)")
end

local manifest = serde.decode("json", fs.readFile("src/manifest.json"))
local worlds = {
	{ key = "World1", file = "World1Update3New.rbxl", expectedInstances = 31296 },
	{ key = "World2", file = "World2Update3new.rbxl", expectedInstances = 19477 },
	{ key = "World3", file = "World3Update3New.rbxl", expectedInstances = 45330 },
}

local function findNode(root, segments)
	local node = root
	for _, name in ipairs(segments) do
		node = assert(node:FindFirstChild(name), "Missing node: " .. name)
	end
	return node
end

for _, world in ipairs(worlds) do
	local dm = rb.deserializePlace(fs.readFile(world.file))
	local rows = {}
	for _, row in ipairs(manifest.worlds[world.key].scripts) do
		rows[row.source] = row
	end

	for _, c in ipairs(checks) do
		local manifestEntry = assert(rows[c.path], "Missing in manifest for " .. world.key .. ": " .. c.path)
		local node = findNode(dm, manifestEntry.segments)
		assert(node.Source == sourceContents[c.path], "Source mismatch in " .. world.key .. " for " .. c.name)
	end

	local count = #dm:GetDescendants()
	assert(count == world.expectedInstances, string.format("Instance count mismatch in %s: got %d, expected %d", world.key, count, world.expectedInstances))
	print("PASS " .. world.key .. ": all 3 scripts embedded perfectly with instance parity (" .. count .. " instances)")
end

print("ALL SPOTLIGHT TUTORIAL AND HELP REGRESSION TESTS PASSED SUCCESSFULLY!")
