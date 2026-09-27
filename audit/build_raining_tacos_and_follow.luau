-- audit/build_raining_tacos_and_follow.luau
-- Injects Raining Tacos event, Taco Treadmill, and CreatorFollowPopup into World1, World2, and World3.

local fs = require("@lune/fs")
local rb = require("@lune/roblox")
local luau = require("@lune/luau")
local serde = require("@lune/serde")

print("==================================================")
print("BUILD: Raining Tacos, Taco Treadmill & Follow Modal")
print("==================================================")

local manifest = serde.decode("json", fs.readFile("src/manifest.json"))

local scriptsToInject = {
	{
		sourcePath = "src/common/ReplicatedStorage/AdminBannerConfig.luau",
		expectedPatterns = {
			"GekkoH",
			"[767108248]",
		},
	},
	{
		sourcePath = "src/common/ReplicatedStorage/Shared/AdminGlobalEvents.luau",
		expectedPatterns = {
			"DEFAULT_RAINING_TACOS",
			"142376088",
			"GekkoH",
		},
	},
	{
		sourcePath = "src/common/StarterPlayer/StarterPlayerScripts/Admin/AdminAbusePanelController.client.luau",
		expectedPatterns = {
			"RainingTacos",
			"Taco Treadmill",
			"PromptFollow",
			"767108248",
		},
	},
	{
		sourcePath = "src/common/ServerScriptService/Admin/AdminAbusePanelService.server.luau",
		expectedPatterns = {
			"RainingTacos",
			"startRainingTacos",
			"stopRainingTacos",
			"TacoTreadmill",
			"IsTacoTreadmill",
			"ShowFollowCreator",
			"setupAdminChat",
			"OverheadTacoMesh",
			"TacoYellowFlakes",
			"AdminTacoHit",
			"/tacos",
		},
	},
	{
		sourcePath = "src/common/StarterPlayer/StarterPlayerScripts/Admin/AdminAbuseEffects.client.luau",
		expectedPatterns = {
			"RainingTacos",
			"142376088",
			"84855954319870",
			"121725002379738",
			"CrashSoundId",
			"CrunchSoundId",
			"tacoPooledSound",
			"tacoGroundCrash",
			"tacoPlayerHit",
			"updateTacos",
			"AdminTacoHit",
			"AdminTacoCeiling",
			"YellowFlakes",
		},
	},
	{
		sourcePath = "src/common/StarterPlayer/StarterPlayerScripts/Admin/AdminTreadmillReveal.client.luau",
		expectedPatterns = {
			"isTaco",
			"TACO TREADMILL",
			"FollowHost",
			"PromptFollowCreator",
		},
	},
	{
		sourcePath = "src/common/ServerScriptService/Admin/AdminCommands.server.luau",
		expectedPatterns = {
			"767108248",
			"ADMIN_IDS",
		},
	},
	{
		sourcePath = "src/common/ServerScriptService/Progression/TreadmillTraining.server.luau",
		expectedPatterns = {
			"IsTacoTreadmill",
			"Taco Treadmill",
			"ensureHeadTaco",
			"TacoHeadAccessory",
			"FileMesh",
			"WeldConstraint",
		},
	},
}

-- Verify all sources compile and match patterns
for _, item in ipairs(scriptsToInject) do
	local src = fs.readFile(item.sourcePath)
	local bytecode = luau.compile(src)
	assert(#bytecode > 0, "Failed to compile: " .. item.sourcePath)
	for _, pat in ipairs(item.expectedPatterns) do
		assert(string.find(src, pat, 1, true), "Pattern missing in " .. item.sourcePath .. ": " .. pat)
	end
	item.source = src
	print("VERIFIED:", item.sourcePath, "(bytecode: " .. #bytecode .. " bytes)")
end

-- New script to create/ensure in StarterPlayer.StarterPlayerScripts.UI
local followScriptPath = "src/common/StarterPlayer/StarterPlayerScripts/UI/CreatorFollowPopup.client.luau"
local followScriptSource = fs.readFile(followScriptPath)
local followScriptBytecode = luau.compile(followScriptSource)
assert(#followScriptBytecode > 0, "Failed to compile CreatorFollowPopup")
print("VERIFIED: " .. followScriptPath .. " (bytecode: " .. #followScriptBytecode .. " bytes)")

local worlds = {
	{ key = "World1", file = "World1Update3New.rbxl" },
	{ key = "World2", file = "World2Update3new.rbxl" },
	{ key = "World3", file = "World3Update3New.rbxl" },
}

local stamp = os.date("!%Y%m%d_%H%M%S")
local backup = "output/Backup_RainingTacos_" .. stamp
local output = "output/RainingTacos_" .. stamp
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
	print("--- Processing " .. world.key .. " (" .. world.file .. ") ---")
	local oldPlace = fs.readFile(world.file)
	local dm = rb.deserializePlace(oldPlace)
	local rows = {}
	for _, row in ipairs(manifest.worlds[world.key].scripts) do
		rows[row.source] = row
	end

	-- 1. Inject modified existing scripts
	for _, item in ipairs(scriptsToInject) do
		local manifestEntry = assert(rows[item.sourcePath], "Script not in manifest for " .. world.key .. ": " .. item.sourcePath)
		local scriptInstance = findNode(dm, manifestEntry.segments)
		scriptInstance.Source = item.source
	end

	-- 2. Inject or update CreatorFollowPopup in StarterPlayerScripts.UI
	local sp = dm:FindFirstChild("StarterPlayer")
	assert(sp, "StarterPlayer not found in " .. world.key)
	local sps = sp:FindFirstChild("StarterPlayerScripts")
	assert(sps, "StarterPlayerScripts not found in " .. world.key)
	local uiFolder = sps:FindFirstChild("UI")
	assert(uiFolder, "StarterPlayerScripts.UI not found in " .. world.key)

	local followScript = uiFolder:FindFirstChild("CreatorFollowPopup")
	if not followScript then
		followScript = rb.Instance.new("LocalScript")
		followScript.Name = "CreatorFollowPopup"
		followScript.Parent = uiFolder
		print("Created new LocalScript CreatorFollowPopup in " .. world.key)
	end
	followScript.Source = followScriptSource

	local count = #dm:GetDescendants()
	local bytes = rb.serializePlace(dm)
	local check = rb.deserializePlace(bytes)

	-- Verify roundtrip
	for _, item in ipairs(scriptsToInject) do
		local manifestEntry = rows[item.sourcePath]
		local checkInstance = findNode(check, manifestEntry.segments)
		assert(checkInstance.Source == item.source, world.key .. " source not saved for " .. item.sourcePath)
	end

	local checkFollow = check.StarterPlayer.StarterPlayerScripts.UI:FindFirstChild("CreatorFollowPopup")
	assert(checkFollow and checkFollow.Source == followScriptSource, world.key .. " CreatorFollowPopup not saved!")
	assert(#check:GetDescendants() == count, world.key .. " instance count mismatch!")

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
