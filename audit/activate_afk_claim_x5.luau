-- Saves the configured Get x5 developer product into all three shipped places.
local fs = require("@lune/fs")
local rb = require("@lune/roblox")
local luau = require("@lune/luau")
local serde = require("@lune/serde")

local manifest = serde.decode("json", fs.readFile("src/manifest.json"))
local configPath = "src/common/ReplicatedStorage/Shared/Config.luau"
local changes = {
	configPath,
	"src/common/ServerScriptService/Social/AfkRewardsService.server.luau",
	"src/common/StarterPlayer/StarterPlayerScripts/UI/AfkRewardsController.client.luau",
}
local files = {
	{ key = "World1", file = "World1Update3New.rbxl" },
	{ key = "World2", file = "World2Update3new.rbxl" },
	{ key = "World3", file = "World3Update3New.rbxl" },
}
local stamp = os.date("!%Y%m%d_%H%M%S")
local backup = "output/Backup_AFK_GetX5_" .. stamp
local output = "output/AFK_GetX5_" .. stamp
fs.writeDir(backup)
fs.writeDir(output)

local sources = {}
for _, path in changes do
	sources[path] = fs.readFile(path)
	luau.compile(sources[path])
end
assert(string.find(sources[configPath], "ClaimX5 = { ProductId = 3713742489, PriceRobux = 19 },", 1, true),
	"Get x5 product ID and price are not configured")
local prepared = {}
local report = { backup = backup, output = output, productId = 3713742489, fallbackPriceRobux = 19, worlds = {} }

local function find(root, segments)
	local object = root
	for _, name in segments do
		object = assert(object:FindFirstChild(name), "Missing " .. name)
	end
	return object
end

for _, world in files do
	local oldPlace = fs.readFile(world.file)
	local dm = rb.deserializePlace(oldPlace)
	local wheel = assert(dm:GetService("Workspace"):FindFirstChild("SpinWheelLobby"), world.key .. " missing wheel")
	assert(wheel.ModelStreamingMode == rb.Enum.ModelStreamingMode.Persistent, world.key .. " lost the wheel streaming fix")
	local rows = {}
	for _, row in manifest.worlds[world.key].scripts do
		rows[row.source] = row
	end
	local oldConfig = find(dm, assert(rows[configPath], configPath).segments).Source
	assert(string.find(oldConfig, "ClaimX5 = { ProductId = nil, PriceRobux = 29 },", 1, true),
		world.key .. " AFK config changed unexpectedly")
	for _, path in changes do
		find(dm, assert(rows[path], path).segments).Source = sources[path]
	end
	local count = #dm:GetDescendants()
	local newPlace = rb.serializePlace(dm)
	local check = rb.deserializePlace(newPlace)
	for _, path in changes do
		assert(find(check, rows[path].segments).Source == sources[path], world.key .. " did not save " .. path)
	end
	assert(#check:GetDescendants() == count, world.key .. " instance count changed")
	assert(check:GetService("Workspace"):FindFirstChild("SpinWheelLobby").ModelStreamingMode == rb.Enum.ModelStreamingMode.Persistent,
		world.key .. " wheel mode changed")
	fs.writeFile(backup .. "/" .. world.file, oldPlace)
	fs.writeFile(output .. "/" .. world.file, newPlace)
	prepared[#prepared + 1] = { world = world, oldPlace = oldPlace, newPlace = newPlace }
	report.worlds[world.key] = { file = world.file, instances = count, sha256 = serde.hash("sha256", newPlace) }
	print("PREPARED", world.key, count)
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
