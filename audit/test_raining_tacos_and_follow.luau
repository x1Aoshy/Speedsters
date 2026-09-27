-- audit/test_raining_tacos_and_follow.luau
-- Comprehensive verification of Raining Tacos, Taco Treadmill, and Follow Creator modal.

local fs = require("@lune/fs")
local rb = require("@lune/roblox")
local luau = require("@lune/luau")
local serde = require("@lune/serde")

print("==================================================")
print("TEST: Raining Tacos, Taco Treadmill & Follow Modal")
print("==================================================")

local manifest = serde.decode("json", fs.readFile("src/manifest.json"))

local places = {
	{ key = "World1", file = "World1Update3New.rbxl" },
	{ key = "World2", file = "World2Update3new.rbxl" },
	{ key = "World3", file = "World3Update3New.rbxl" },
}

local checks = {
	{
		name = "AdminBannerConfig (GekkoH 767108248)",
		segments = { "ReplicatedStorage", "AdminBannerConfig" },
		patterns = { "GekkoH", "[767108248]" },
	},
	{
		name = "AdminGlobalEvents (DEFAULT_RAINING_TACOS)",
		segments = { "ReplicatedStorage", "Shared", "AdminGlobalEvents" },
		patterns = { "DEFAULT_RAINING_TACOS", "142376088", "GekkoH" },
	},
	{
		name = "AdminAbusePanelController (Raining Tacos & Taco Treadmill UI)",
		segments = { "StarterPlayer", "StarterPlayerScripts", "Admin", "AdminAbusePanelController" },
		patterns = { "RainingTacos", "Taco Treadmill", "PromptFollow", "767108248" },
	},
	{
		name = "AdminAbusePanelService (Raining Tacos & Taco Treadmill Server)",
		segments = { "ServerScriptService", "Admin", "AdminAbusePanelService" },
		patterns = {
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
			"/tacotreadmill",
			"/follow",
		},
	},
	{
		name = "AdminAbuseEffects (Raining Tacos Visual & Audio Effects)",
		segments = { "StarterPlayer", "StarterPlayerScripts", "Admin", "AdminAbuseEffects" },
		patterns = {
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
		name = "AdminTreadmillReveal (Taco Cinematic & Follow Host Button)",
		segments = { "StarterPlayer", "StarterPlayerScripts", "Admin", "AdminTreadmillReveal" },
		patterns = {
			"isTaco",
			"TACO TREADMILL",
			"FollowHost",
			"PromptFollowCreator",
		},
	},
	{
		name = "AdminCommands (Owner 767108248 Allowed)",
		segments = { "ServerScriptService", "Admin", "AdminCommands" },
		patterns = { "767108248", "ADMIN_IDS" },
	},
	{
		name = "TreadmillTraining (Taco Treadmill Gain Bonus)",
		segments = { "ServerScriptService", "Progression", "TreadmillTraining" },
		patterns = { "IsTacoTreadmill", "Taco Treadmill", "ensureHeadTaco", "TacoHeadAccessory", "FileMesh", "WeldConstraint" },
	},
	{
		name = "CreatorFollowPopup (Follow Modal for @GekkoH)",
		segments = { "StarterPlayer", "StarterPlayerScripts", "UI", "CreatorFollowPopup" },
		patterns = {
			"767108248",
			"GekkoH",
			"ShowFollowCreator",
			"CreatorFollowGui",
			"ProfileLinkBox",
			"COPY PROFILE LINK",
		},
	},
}

local function findNode(root, segments)
	local node = root
	for _, name in ipairs(segments) do
		if not node then return nil end
		node = node:FindFirstChild(name)
	end
	return node
end

local allPassed = true

for _, placeInfo in ipairs(places) do
	print("\n--- Verifying " .. placeInfo.key .. " (" .. placeInfo.file .. ") ---")
	local raw = fs.readFile(placeInfo.file)
	local dm = rb.deserializePlace(raw)
	assert(dm, "Failed to deserialize " .. placeInfo.file)
	local descCount = #dm:GetDescendants()
	print("Total instances in place:", descCount)

	for _, check in ipairs(checks) do
		local node = findNode(dm, check.segments)
		if not node then
			print("❌ MISSING NODE: " .. check.name .. " (" .. table.concat(check.segments, ".") .. ")")
			allPassed = false
		else
			local src = node.Source
			local nodeOk = true
			for _, pat in ipairs(check.patterns) do
				if not string.find(src, pat, 1, true) then
					print("❌ MISSING PATTERN in " .. check.name .. ": '" .. pat .. "'")
					nodeOk = false
					allPassed = false
				end
			end
			if nodeOk then
				local bc = luau.compile(src)
				if #bc == 0 then
					print("❌ BYTECODE COMPILATION FAILED: " .. check.name)
					allPassed = false
				else
					print("✅ PASSED: " .. check.name .. " (" .. #bc .. " bytes bytecode)")
				end
			end
		end
	end
end

assert(allPassed, "Some verification checks failed!")
print("\n==================================================")
print("🎉 ALL TESTS PASSED ACROSS WORLD1, WORLD2 & WORLD3!")
print("==================================================")
