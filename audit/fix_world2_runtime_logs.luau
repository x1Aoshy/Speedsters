-- Saves the World 2 log fixes without disturbing the AFK product or wheel changes.
local fs = require("@lune/fs")
local rb = require("@lune/roblox")
local luau = require("@lune/luau")
local serde = require("@lune/serde")

local manifest = serde.decode("json", fs.readFile("src/manifest.json"))
local common = {
	"src/common/ReplicatedStorage/Shared/HudErgonomics.luau",
	"src/common/ServerScriptService/Economy/SkinSystem.server.luau",
}
local world2Only = {
	"src/worlds/World2/StarterPlayer/StarterPlayerScripts/Gameplay/World2TreeSlammers.client.luau",
	"src/worlds/World2/ServerScriptService/Progression/World2TreadmillOverheadLabels.server.luau",
}
local worlds = {
	{ key = "World1", file = "World1Update3New.rbxl" },
	{ key = "World2", file = "World2Update3new.rbxl" },
	{ key = "World3", file = "World3Update3New.rbxl" },
}
local stamp = os.date("!%Y%m%d_%H%M%S")
local backup = "output/Backup_World2_RuntimeLogs_" .. stamp
local output = "output/World2_RuntimeLogs_Fixed_" .. stamp
fs.writeDir(backup)
fs.writeDir(output)

local sources = {}
for _, path in common do
	sources[path] = fs.readFile(path)
	luau.compile(sources[path])
end
for _, path in world2Only do
	sources[path] = fs.readFile(path)
	luau.compile(sources[path])
end

local prepared = {}
local report = { backup = backup, output = output, worlds = {} }
local function find(root, segments)
	local object = root
	for _, name in segments do
		object = assert(object:FindFirstChild(name), "Missing " .. name)
	end
	return object
end

for _, world in worlds do
	local oldPlace = fs.readFile(world.file)
	local dm = rb.deserializePlace(oldPlace)
	local rows = {}
	for _, row in manifest.worlds[world.key].scripts do
		rows[row.source] = row
	end
	local changes = table.clone(common)
	if world.key == "World2" then
		for _, path in world2Only do
			table.insert(changes, path)
		end
	end
	local previousHud = find(dm, assert(rows[common[1]], common[1]).segments).Source
	assert(string.find(previousHud, "math.clamp(centreY - side / 2, 8, height - side - 8)", 1, true),
		world.key .. " HUD source changed unexpectedly")
	local previousSkin = find(dm, assert(rows[common[2]], common[2]).segments).Source
	assert(string.find(previousSkin, 'return false, "DarkZonic dummy missing"', 1, true),
		world.key .. " skin source changed unexpectedly")
	if world.key == "World2" then
		local previousTree = find(dm, assert(rows[world2Only[1]], world2Only[1]).segments).Source
		assert(string.find(previousTree, "local function nearestTreeDistance()", 1, true),
			"World 2 tree source changed unexpectedly")
		local previousLabel = find(dm, assert(rows[world2Only[2]], world2Only[2]).segments).Source
		assert(string.find(previousLabel, 'StepsText = "Starter\\nx3 Speed"', 1, true),
			"World 2 Golden sign changed unexpectedly")
	end
	for _, path in changes do
		find(dm, assert(rows[path], path).segments).Source = sources[path]
	end
	local beforeCount = #dm:GetDescendants()
	local newPlace = rb.serializePlace(dm)
	local check = rb.deserializePlace(newPlace)
	for _, path in changes do
		assert(find(check, rows[path].segments).Source == sources[path], world.key .. " did not save " .. path)
	end
	assert(#check:GetDescendants() == beforeCount, world.key .. " instance count changed")
	local cfg = find(check, assert(rows["src/common/ReplicatedStorage/Shared/Config.luau"]).segments).Source
	assert(string.find(cfg, "ClaimX5 = { ProductId = 3713742489, PriceRobux = 19 },", 1, true),
		world.key .. " lost the AFK x5 product")
	local wheel = assert(check:GetService("Workspace"):FindFirstChild("SpinWheelLobby"))
	assert(wheel.ModelStreamingMode == rb.Enum.ModelStreamingMode.Persistent, world.key .. " lost wheel streaming fix")
	fs.writeFile(backup .. "/" .. world.file, oldPlace)
	fs.writeFile(output .. "/" .. world.file, newPlace)
	prepared[#prepared + 1] = { world = world, oldPlace = oldPlace, newPlace = newPlace }
	report.worlds[world.key] = { file = world.file, instances = beforeCount, sha256 = serde.hash("sha256", newPlace) }
	print("PREPARED", world.key, beforeCount)
end

for _, item in prepared do
	assert(fs.readFile(item.world.file) == item.oldPlace, item.world.key .. " changed during build")
end
for _, item in prepared do
	fs.writeFile(item.world.file, item.newPlace)
	print("SAVED", item.world.file)
end
fs.writeFile(output .. "/validation.json", serde.encode("json", report, true))
print("READY", output)
