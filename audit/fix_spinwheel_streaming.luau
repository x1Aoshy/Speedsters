-- Updates the saved physical wheel and its client controller in every shipped place.
-- Keep the original places and model assets together for a quick Studio rollback.
local fs = require("@lune/fs")
local rb = require("@lune/roblox")
local luau = require("@lune/luau")
local serde = require("@lune/serde")

local manifest = serde.decode("json", fs.readFile("src/manifest.json"))
local controllerPath = "src/common/StarterPlayer/StarterPlayerScripts/UI/SpinWheelController.client.luau"
local source = fs.readFile(controllerPath)
luau.compile(source)

local worlds = {
	{ key = "World1", file = "World1Update3New.rbxl" },
	{ key = "World2", file = "World2Update3new.rbxl" },
	{ key = "World3", file = "World3Update3New.rbxl" },
}
local stamp = os.date("!%Y%m%d_%H%M%S")
local backup = "output/Backup_SpinWheel_" .. stamp
local output = "output/SpinWheel_Fixed_" .. stamp
fs.writeDir(backup)
fs.writeDir(output)
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
	local assetPath = "src/assets/SpinWheelLobby_" .. world.key .. ".rbxm"
	local oldAsset = fs.readFile(assetPath)
	local model = assert(rb.deserializeModel(oldAsset)[1], assetPath)
	assert(model.Name == "SpinWheelLobby", assetPath .. " is not the authored wheel")
	assert(model.ModelStreamingMode == rb.Enum.ModelStreamingMode.Default
		or model.ModelStreamingMode == rb.Enum.ModelStreamingMode.Persistent, assetPath .. " changed unexpectedly")
	model.ModelStreamingMode = rb.Enum.ModelStreamingMode.Persistent
	local newAsset = rb.serializeModel({ model })
	assert(rb.deserializeModel(newAsset)[1].ModelStreamingMode == rb.Enum.ModelStreamingMode.Persistent)

	local oldPlace = fs.readFile(world.file)
	local dm = rb.deserializePlace(oldPlace)
	local workspace = dm:GetService("Workspace")
	local wheel = assert(workspace:FindFirstChild("SpinWheelLobby"), world.key .. " missing wheel")
	local wheelCount = 0
	for _, child in workspace:GetChildren() do
		if child.Name == "SpinWheelLobby" then
			wheelCount += 1
		end
	end
	assert(wheelCount == 1, world.key .. " has duplicate wheels")
	assert(wheel.ModelStreamingMode == rb.Enum.ModelStreamingMode.Default
		or wheel.ModelStreamingMode == rb.Enum.ModelStreamingMode.Persistent, world.key .. " wheel changed unexpectedly")
	wheel.ModelStreamingMode = rb.Enum.ModelStreamingMode.Persistent
	local rows = {}
	for _, row in manifest.worlds[world.key].scripts do
		rows[row.source] = row
	end
	local controller = find(dm, assert(rows[controllerPath], controllerPath).segments)
	assert(string.find(controller.Source, 'PlayerGui:WaitForChild("SpinWheelGui", 5)', 1, true)
		or string.find(controller.Source, 'Workspace:WaitForChild("SpinWheelLobby")', 1, true),
		world.key .. " controller changed unexpectedly")
	controller.Source = source
	local instanceCount = #dm:GetDescendants()
	local newPlace = rb.serializePlace(dm)
	local check = rb.deserializePlace(newPlace)
	assert(find(check, rows[controllerPath].segments).Source == source, world.key .. " controller not saved")
	assert(check:GetService("Workspace"):FindFirstChild("SpinWheelLobby").ModelStreamingMode == rb.Enum.ModelStreamingMode.Persistent,
		world.key .. " Persistent mode not saved")
	assert(#check:GetDescendants() == instanceCount, world.key .. " instance count changed")

	fs.writeFile(backup .. "/" .. world.file, oldPlace)
	fs.writeFile(backup .. "/SpinWheelLobby_" .. world.key .. ".rbxm", oldAsset)
	fs.writeFile(output .. "/" .. world.file, newPlace)
	prepared[#prepared + 1] = { world = world, assetPath = assetPath, oldAsset = oldAsset, newAsset = newAsset, oldPlace = oldPlace, newPlace = newPlace }
	report.worlds[world.key] = {
		file = world.file,
		instances = instanceCount,
		sha256 = serde.hash("sha256", newPlace),
		assetSha256 = serde.hash("sha256", newAsset),
	}
	print("PREPARED", world.key, instanceCount)
end

for _, item in prepared do
	assert(fs.readFile(item.world.file) == item.oldPlace, item.world.key .. " place changed during build")
	assert(fs.readFile(item.assetPath) == item.oldAsset, item.world.key .. " asset changed during build")
end
for _, item in prepared do
	fs.writeFile(item.world.file, item.newPlace)
	fs.writeFile(item.assetPath, item.newAsset)
	print("SAVED", item.world.file, item.assetPath)
end
fs.writeFile(output .. "/validation.json", serde.encode("json", report, true))
print("FIXED", output)
