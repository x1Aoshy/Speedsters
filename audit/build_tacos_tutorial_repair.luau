local fs = require("@lune/fs")
local rb = require("@lune/roblox")
local luau = require("@lune/luau")
local serde = require("@lune/serde")
local output = "output/TacosTutorialRepair"
local manifest = serde.decode("json", fs.readFile("src/manifest.json"))
local changed = {
	"ServerScriptService/Admin/AdminAbusePanelService.server.luau",
	"ServerScriptService/Progression/TreadmillTraining.server.luau",
	"StarterPlayer/StarterPlayerScripts/Admin/AdminAbuseEffects.client.luau",
	"StarterPlayer/StarterPlayerScripts/UI/FirstTimeTutorial.client.luau",
	"StarterPlayer/StarterPlayerScripts/UI/EvolveController.client.luau",
	"StarterGui/Backpack/BackpackScript.client.luau",
}
local modules = {"TacoVisual", "TutorialGuideLayout", "TutorialGuide"}
local allSources = {}
for _, path in changed do table.insert(allSources, "src/common/" .. path) end
for _, name in modules do table.insert(allSources, "src/common/ReplicatedStorage/Shared/" .. name .. ".luau") end
for _, path in allSources do
	local bytecode = luau.compile(fs.readFile(path))
	assert(bytecode:byte(1) ~= 0, path .. " compile error")
	print("COMPILED", path)
end
local original = rb.deserializePlace(fs.readFile("Outdated/V40 SAB by FaypleStudios.rbxl"))
local event = original.ReplicatedStorage.Controllers.EventController.Events["Raining Tacos"]
local assets = rb.Instance.new("Folder")
assets.Name = "TacoEventAssets"
for _, name in {"Taco", "StruckVFX"} do
	local asset = assert(event:FindFirstChild(name), "Original asset missing: " .. name):Clone()
	for _, node in asset:GetDescendants() do
		if node:IsA("LuaSourceContainer") then node:Destroy()
		elseif node:IsA("BasePart") then
			node.CanCollide, node.CanTouch, node.CanQuery = false, false, false
		elseif node:IsA("ParticleEmitter") then node.Enabled = false end
	end
	asset.Parent = assets
	print("ORIGINAL ASSET", name, asset.ClassName, #asset:GetDescendants())
end
assert(assets.Taco:IsA("MeshPart"), "Expected original MeshPart")
fs.writeFile("src/ui/TacoEventAssets.rbxm", rb.serializeModel({assets}))
local report = {sources = allSources, tests = "audit/test_tacos_tutorial_repair.luau", worlds = {},
	assetSource = "Outdated/V40 SAB by FaypleStudios.rbxl", studioPlaytest = false}
local function find(root, segments)
	local node = root
	for _, segment in segments do node = assert(node:FindFirstChild(segment), segment) end
	return node
end
local prepared = {}
for _, spec in {{"World1", "World1Update3New.rbxl"}, {"World2", "World2Update3new.rbxl"}, {"World3", "World3Update3New.rbxl"}} do
	local key, file = spec[1], spec[2]
	local bytes = fs.readFile(file)
	local dm = rb.deserializePlace(bytes)
	local previousPath = output .. "/" .. file
	local previous = if fs.isFile(previousPath) then rb.deserializePlace(fs.readFile(previousPath)) else nil
	local countBefore = #dm:GetDescendants()
	local rows = {}
	for _, row in manifest.worlds[key].scripts do rows[row.source] = row end
	for _, path in changed do
		local sourcePath = "src/common/" .. path
		local row = assert(rows[sourcePath], key .. " missing manifest source " .. sourcePath)
		local node = find(dm, row.segments)
		-- Refuse to overwrite unsynchronized place edits.
		local baseline = fs.readFile(output .. "/backup/" .. sourcePath)
		assert(node.Source == baseline or node.Source == fs.readFile(sourcePath)
			or (previous and node.Source == find(previous, row.segments).Source), key .. " contains different embedded source: " .. sourcePath)
		node.Source = fs.readFile(sourcePath)
	end
	for _, name in modules do
		local sourcePath = "src/common/ReplicatedStorage/Shared/" .. name .. ".luau"
		local node = dm.ReplicatedStorage.Shared:FindFirstChild(name)
		if not node then
			node = rb.Instance.new("ModuleScript")
			node.Name, node.Parent = name, dm.ReplicatedStorage.Shared
		end
		node.Source = fs.readFile(sourcePath)
		if not rows[sourcePath] then
			local row = {added = true, class = "ModuleScript", duplicate = false,
				segments = {"ReplicatedStorage", "Shared", name}, source = sourcePath,
				path = "ReplicatedStorage.Shared." .. name, legacyPath = "ReplicatedStorage/Shared/" .. name}
			table.insert(manifest.worlds[key].scripts, row)
			rows[sourcePath] = row
		end
	end
	local oldAssets = dm.ReplicatedStorage.Shared:FindFirstChild(assets.Name)
	if oldAssets then oldAssets:Destroy() end
	assets:Clone().Parent = dm.ReplicatedStorage.Shared
	local result = rb.serializePlace(dm)
	local check = rb.deserializePlace(result)
	assert(#check:GetDescendants() == #dm:GetDescendants(), "Instance roundtrip mismatch")
	for _, path in allSources do assert(find(check, rows[path].segments).Source == fs.readFile(path), "Source roundtrip mismatch") end
	assert(check.ReplicatedStorage.Shared.TacoEventAssets.Taco.Size == assets.Taco.Size)
	assert(#check.ReplicatedStorage.Shared.TacoEventAssets.StruckVFX:GetDescendants() == #assets.StruckVFX:GetDescendants())
	local backupPath = output .. "/backup/" .. file
	if not fs.isFile(backupPath) then fs.writeFile(backupPath, bytes) end
	fs.writeFile(output .. "/" .. file, result)
	table.insert(prepared, {file = file, before = bytes, after = result})
	report.worlds[key] = {file = file, beforeInstances = countBefore, afterInstances = #check:GetDescendants(), sha256 = serde.hash("sha256", result)}
	print("VERIFIED PLACE", key, #check:GetDescendants())
end
for _, item in prepared do assert(fs.readFile(item.file) == item.before, "Concurrent edit: " .. item.file) end
for _, item in prepared do fs.writeFile(item.file, item.after) end
local uniqueSources = {}
for _, world in manifest.worlds do
	for _, row in world.scripts do
		if row.source:sub(1, 11) == "src/common/" then uniqueSources[row.source] = true end
	end
end
local commonCount = 0
for _ in uniqueSources do commonCount += 1 end
manifest.commonSources = commonCount
fs.writeFile("src/manifest.json", serde.encode("json", manifest, true))
fs.writeFile(output .. "/validation.json", serde.encode("json", report, true))
print("SAVED all 3 worlds, backups and validation in", output)
