-- Embed the September UI, bridge and loading fixes into the three current places.
local fs = require("@lune/fs")
local rb = require("@lune/roblox")
local luau = require("@lune/luau")
local serde = require("@lune/serde")

local manifest = serde.decode("json", fs.readFile("src/manifest.json"))
local commonSources = {
	"src/common/ReplicatedFirst/LoadingScreen.client.luau",
	"src/common/ReplicatedStorage/Shared/Config.luau",
	"src/common/ServerScriptService/Gameplay/BridgeRampPlan.luau",
	"src/common/StarterPlayer/StarterPlayerScripts/UI/TeleportController.client.luau",
	"src/common/StarterGui/Backpack/BackpackScript.client.luau",
	"src/common/StarterGui/Index/IndexScript.client.luau",
}
local world3Sources = {
	"src/worlds/World3/ServerScriptService/Gameplay/World3Hazards.server.luau",
}
local worlds = {
	{ key = "World1", file = "World1Update3New.rbxl" },
	{ key = "World2", file = "World2Update3new.rbxl" },
	{ key = "World3", file = "World3Update3New.rbxl" },
}

local sources = {}
for _, path in commonSources do
	sources[path] = fs.readFile(path)
	luau.compile(sources[path])
end
for _, path in world3Sources do
	sources[path] = fs.readFile(path)
	luau.compile(sources[path])
end

local function find(root, segments)
	local node = root
	for _, name in segments do
		node = assert(node:FindFirstChild(name), "Missing " .. name)
	end
	return node
end

local stamp = os.date("!%Y%m%d_%H%M%S")
local backup = "output/Backup_UI_Bridge_Loading_" .. stamp
local output = "output/UI_Bridge_Loading_Fixed_" .. stamp
fs.writeDir(backup)
fs.writeDir(output)
local prepared = {}
local report = { backup = backup, output = output, worlds = {} }

for _, world in worlds do
	local oldPlace = fs.readFile(world.file)
	local dm = rb.deserializePlace(oldPlace)
	local removedStageRows = 0
	local teleportGui = dm:GetService("StarterGui"):FindFirstChild("StageTeleport")
	local teleportPanel = teleportGui and teleportGui:FindFirstChild("StageTeleport")
	local teleportScroll = teleportPanel and teleportPanel:FindFirstChild("ScrollingFrame")
	assert(teleportScroll, world.key .. " missing teleport menu")
	for _, child in teleportScroll:GetChildren() do
		local stage = child:IsA("GuiObject") and tonumber(string.match(child.Name, "^Stage(%d+)$"))
		if stage and stage > 10 then
			removedStageRows += #child:GetDescendants() + 1
			child:Destroy()
		end
	end
	-- Authored rows use a UIListLayout; size the scroll content to the remaining rows.
	teleportScroll.AutomaticCanvasSize = rb.Enum.AutomaticSize.Y
	teleportScroll.CanvasSize = rb.UDim2.new(0, 0, 0, 0)
	local rows = {}
	for _, row in manifest.worlds[world.key].scripts do
		assert(not rows[row.source], world.key .. " duplicate source " .. row.source)
		rows[row.source] = row
	end
	local changed = {}
	for _, path in commonSources do
		local row = assert(rows[path], world.key .. " missing " .. path)
		local node = find(dm, row.segments)
		assert(node:IsA("LuaSourceContainer"), world.key .. " invalid script " .. path)
		node.Source = sources[path]
		table.insert(changed, path)
	end
	if world.key == "World3" then
		for _, path in world3Sources do
			local row = assert(rows[path], world.key .. " missing " .. path)
			local node = find(dm, row.segments)
			assert(node:IsA("LuaSourceContainer"), world.key .. " invalid script " .. path)
			node.Source = sources[path]
			table.insert(changed, path)
		end
	end

	local count = #dm:GetDescendants()
	local bytes = rb.serializePlace(dm)
	local check = rb.deserializePlace(bytes)
	assert(#check:GetDescendants() == count, world.key .. " instance count changed unexpectedly")
	local savedTeleport = find(check, { "StarterGui", "StageTeleport", "StageTeleport", "ScrollingFrame" })
	assert(not savedTeleport:FindFirstChild("Stage11"), world.key .. " still contains Stage 11 row")
	for _, path in changed do
		assert(find(check, rows[path].segments).Source == sources[path], world.key .. " stale embedded " .. path)
	end
	local cfg = find(check, rows["src/common/ReplicatedStorage/Shared/Config.luau"].segments).Source
	assert(string.find(cfg, "ClaimX5 = { ProductId = 3713742489, PriceRobux = 19 },", 1, true), world.key .. " lost AFK x5 product")
	local wheel = check:GetService("Workspace"):FindFirstChild("SpinWheelLobby")
	assert(wheel and wheel.ModelStreamingMode == rb.Enum.ModelStreamingMode.Persistent, world.key .. " lost persistent wheel")
	if world.key == "World3" then
		local bridge = find(check, { "Workspace", "Stage 10", "Decor", "WoodenBridge" })
		assert(#bridge:GetDescendants() >= 50, "World 3 WoodenBridge geometry missing")
	end

	fs.writeFile(backup .. "/" .. world.file, oldPlace)
	fs.writeFile(output .. "/" .. world.file, bytes)
	prepared[#prepared + 1] = { world = world, oldPlace = oldPlace, bytes = bytes }
	report.worlds[world.key] = {
		file = world.file,
		instances = count,
		sha256 = serde.hash("sha256", bytes),
		changedSources = changed,
		removedStageRowInstances = removedStageRows,
	}
	print("PREPARED", world.key, count)
end

for _, item in prepared do
	assert(fs.readFile(item.world.file) == item.oldPlace, item.world.key .. " changed during build")
end
local saved = {}
local ok, err = pcall(function()
	for _, item in prepared do
		fs.writeFile(item.world.file, item.bytes)
		table.insert(saved, item)
		assert(fs.readFile(item.world.file) == item.bytes, item.world.key .. " root verification failed")
		print("SAVED", item.world.file)
	end
end)
if not ok then
	for _, item in saved do
		fs.writeFile(item.world.file, item.oldPlace)
	end
	error("Place update failed; restored saved roots: " .. tostring(err))
end
fs.writeFile(output .. "/validation.json", serde.encode("json", report, true))
print("READY", output)
