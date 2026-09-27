-- Embed the visual First Upgrade modal tutorial into all places.
local fs = require("@lune/fs")
local rb = require("@lune/roblox")
local luau = require("@lune/luau")
local serde = require("@lune/serde")

local sourcePath = "src/common/StarterPlayer/StarterPlayerScripts/UI/FirstTimeTutorial.client.luau"
local source = fs.readFile(sourcePath)
luau.compile(source)

assert(string.find(source, "SpeedsterFirstUpgradePrompt", 1, true), "prompt screen gui missing")
assert(string.find(source, "rbxassetid://82176677996191", 1, true), "Orange Aura icon missing")
assert(string.find(source, "Aura05", 1, true), "Aura05 purchase missing")
assert(string.find(source, "EQUIP NOW", 1, true), "Equip button text missing")

local manifest = serde.decode("json", fs.readFile("src/manifest.json"))
local worlds = {
	{ key = "World1", file = "World1Update3New.rbxl" },
	{ key = "World2", file = "World2Update3new.rbxl" },
	{ key = "World3", file = "World3Update3New.rbxl" },
}
local stamp = os.date("!%Y%m%d_%H%M%S")
local backup = "output/Backup_TutorialUpgradeModal_" .. stamp
local output = "output/TutorialUpgradeModal_" .. stamp
fs.writeDir(backup)
fs.writeDir(output)
local prepared = {}
local report = {
	backup = backup,
	output = output,
	aura = "Aura05",
	worlds = {},
}

local function find(root, segments)
	local node = root
	for _, name in segments do
		node = assert(node:FindFirstChild(name), "Missing " .. name)
	end
	return node
end

for _, world in worlds do
	local oldPlace = fs.readFile(world.file)
	local dm = rb.deserializePlace(oldPlace)
	local rows = {}
	for _, row in manifest.worlds[world.key].scripts do
		rows[row.source] = row
	end
	local tutorialScript = find(dm, assert(rows[sourcePath], sourcePath).segments)
	tutorialScript.Source = source
	local count = #dm:GetDescendants()
	local bytes = rb.serializePlace(dm)
	local check = rb.deserializePlace(bytes)
	assert(find(check, rows[sourcePath].segments).Source == source, world.key .. " tutorial source not saved")
	assert(#check:GetDescendants() == count, world.key .. " instance count changed")
	
	fs.writeFile(backup .. "/" .. world.file, oldPlace)
	fs.writeFile(output .. "/" .. world.file, bytes)
	prepared[#prepared + 1] = { world = world, oldPlace = oldPlace, bytes = bytes }
	report.worlds[world.key] = { file = world.file, instances = count, sha256 = serde.hash("sha256", bytes) }
	print("PREPARED", world.key, count)
end

for _, item in prepared do
	assert(fs.readFile(item.world.file) == item.oldPlace, item.world.key .. " changed during build")
end
for _, item in prepared do
	fs.writeFile(item.world.file, item.bytes)
	print("SAVED", item.world.file)
end
fs.writeFile(output .. "/validation.json", serde.encode("json", report, true))
print("READY", output)
