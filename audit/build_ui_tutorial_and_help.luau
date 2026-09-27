-- Embed the updated FirstTimeTutorial, EvolveController, and BackpackScript into all 3 places.
local fs = require("@lune/fs")
local rb = require("@lune/roblox")
local luau = require("@lune/luau")
local serde = require("@lune/serde")

local scriptsToInject = {
	{
		sourcePath = "src/common/StarterPlayer/StarterPlayerScripts/UI/FirstTimeTutorial.client.luau",
		expectedPatterns = { "SpeedsterFirstUpgradePrompt", "Skip / Omitir", "rbxassetid://106477372921851", "Aura05" }
	},
	{
		sourcePath = "src/common/StarterPlayer/StarterPlayerScripts/UI/EvolveController.client.luau",
		expectedPatterns = { "InfoButton", "EvolveHelpCard", "HOW EVOLVE WORKS", "¡ENTENDIDO! / GOT IT!" }
	},
	{
		sourcePath = "src/common/StarterGui/Backpack/BackpackScript.client.luau",
		expectedPatterns = { "InfoButton", "BackpackHelpCard", "INVENTORY GUIDE", "¡ENTENDIDO! / GOT IT!" }
	},
}

for _, item in ipairs(scriptsToInject) do
	local src = fs.readFile(item.sourcePath)
	luau.compile(src)
	for _, pat in ipairs(item.expectedPatterns) do
		assert(string.find(src, pat, 1, true), "Pattern missing in " .. item.sourcePath .. ": " .. pat)
	end
	item.source = src
	print("VERIFIED SOURCE:", item.sourcePath)
end

local manifest = serde.decode("json", fs.readFile("src/manifest.json"))
local worlds = {
	{ key = "World1", file = "World1Update3New.rbxl" },
	{ key = "World2", file = "World2Update3new.rbxl" },
	{ key = "World3", file = "World3Update3New.rbxl" },
}

local stamp = os.date("!%Y%m%d_%H%M%S")
local backup = "output/Backup_UiTutorialAndHelp_" .. stamp
local output = "output/UiTutorialAndHelp_" .. stamp
fs.writeDir(backup)
fs.writeDir(output)

local prepared = {}
local report = {
	backup = backup,
	output = output,
	timestamp = stamp,
	worlds = {},
}

local function findNode(root, segments)
	local node = root
	for _, name in ipairs(segments) do
		node = assert(node:FindFirstChild(name), "Missing node: " .. name)
	end
	return node
end

for _, world in ipairs(worlds) do
	local oldPlace = fs.readFile(world.file)
	local dm = rb.deserializePlace(oldPlace)
	local rows = {}
	for _, row in ipairs(manifest.worlds[world.key].scripts) do
		rows[row.source] = row
	end

	for _, item in ipairs(scriptsToInject) do
		local manifestEntry = assert(rows[item.sourcePath], "Script not in manifest for " .. world.key .. ": " .. item.sourcePath)
		local scriptInstance = findNode(dm, manifestEntry.segments)
		scriptInstance.Source = item.source
	end

	local count = #dm:GetDescendants()
	local bytes = rb.serializePlace(dm)
	local check = rb.deserializePlace(bytes)

	for _, item in ipairs(scriptsToInject) do
		local manifestEntry = rows[item.sourcePath]
		local checkInstance = findNode(check, manifestEntry.segments)
		assert(checkInstance.Source == item.source, world.key .. " source not saved for " .. item.sourcePath)
	end
	assert(#check:GetDescendants() == count, world.key .. " instance count changed!")

	fs.writeFile(backup .. "/" .. world.file, oldPlace)
	fs.writeFile(output .. "/" .. world.file, bytes)
	prepared[#prepared + 1] = { world = world, oldPlace = oldPlace, bytes = bytes }
	report.worlds[world.key] = { file = world.file, instances = count, sha256 = serde.hash("sha256", bytes) }
	print("PREPARED", world.key, "instances:", count)
end

for _, item in ipairs(prepared) do
	assert(fs.readFile(item.world.file) == item.oldPlace, item.world.key .. " changed during build")
end

for _, item in ipairs(prepared) do
	fs.writeFile(item.world.file, item.bytes)
	print("SAVED", item.world.file)
end

fs.writeFile(output .. "/validation.json", serde.encode("json", report, true))
print("ALL WORLDS SUCCESSFULLY INJECTED AND SAVED!", output)
