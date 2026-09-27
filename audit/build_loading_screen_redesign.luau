-- Embed the shared icon-and-speed-bolts loading screen in all three shipped places.
local fs = require("@lune/fs")
local rb = require("@lune/roblox")
local luau = require("@lune/luau")
local serde = require("@lune/serde")

local sourcePath = "src/common/ReplicatedFirst/LoadingScreen.client.luau"
local source = fs.readFile(sourcePath)
luau.compile(source)
assert(string.find(source, "rbxassetid://92044769924002", 1, true), "game icon missing")
assert(not string.find(source, "rbxassetid://138327240966588", 1, true), "old splash is still present")
local manifest = serde.decode("json", fs.readFile("src/manifest.json"))
local worlds = {
	{ key = "World1", file = "World1Update3New.rbxl" },
	{ key = "World2", file = "World2Update3new.rbxl" },
	{ key = "World3", file = "World3Update3New.rbxl" },
}
local stamp = os.date("!%Y%m%d_%H%M%S")
local backup = "output/Backup_LoadingScreen_" .. stamp
local output = "output/LoadingScreen_Redesign_" .. stamp
fs.writeDir(backup)
fs.writeDir(output)
local prepared = {}
local report = { backup = backup, output = output, icon = "rbxassetid://92044769924002", worlds = {} }

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
	local loading = find(dm, assert(rows[sourcePath], sourcePath).segments)
	assert(string.find(loading.Source, "rbxassetid://138327240966588", 1, true),
		world.key .. " loading screen changed unexpectedly")
	loading.Source = source
	local count = #dm:GetDescendants()
	local bytes = rb.serializePlace(dm)
	local check = rb.deserializePlace(bytes)
	assert(find(check, rows[sourcePath].segments).Source == source, world.key .. " loading source not saved")
	assert(#check:GetDescendants() == count, world.key .. " instance count changed")
	local cfg = find(check, assert(rows["src/common/ReplicatedStorage/Shared/Config.luau"]).segments).Source
	assert(string.find(cfg, "ClaimX5 = { ProductId = 3713742489, PriceRobux = 19 },", 1, true),
		world.key .. " lost AFK x5 product")
	assert(check:GetService("Workspace"):FindFirstChild("SpinWheelLobby").ModelStreamingMode == rb.Enum.ModelStreamingMode.Persistent,
		world.key .. " lost persistent wheel")
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
