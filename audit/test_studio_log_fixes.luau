--!strict
-- audit/test_studio_log_fixes.luau
-- Guards the fixes for the errors and noise in the Studio play-test output.

local fs = require("@lune/fs")
local PlaceFiles = require("./place_files")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local function read(path: string): string
	return fs.readFile(path)
end

-- 1. Leaderboards stop asking once Studio refuses API access, and only in Studio.
do
	local source = read("src/common/ServerScriptService/Social/GlobalLeaderboards.server.luau")
	local startAt = assert(string.find(source, "local IS_STUDIO = RunService:IsStudio()", 1, true))
	local stopAt = assert(string.find(source, "local playerStates = {}", startAt, true))
	local chunk = string.sub(source, startAt, stopAt - 1)
		.. "\nreturn writeScore, function() return studioApiBlocked end"

	local function run(isStudio: boolean, refusal: string)
		local calls, warnings = 0, 0
		local env = {
			RunService = { IsStudio = function() return isStudio end },
			DATASTORE_RETRIES = 3,
			cleanOrderedInteger = function(value) return value end,
			orderedKey = function(userId) return "U_" .. tostring(userId) end,
			warn = function() warnings += 1 end,
			task = { wait = function() end },
		}
		local writeScore, blocked = luau.load(chunk, { environment = env })()
		local category = {
			Id = "Wins",
			Store = { SetAsync = function() calls += 1; error(refusal) end },
		}
		for _ = 1, 4 do
			writeScore(category, 1, 10)
		end
		return calls, warnings, blocked()
	end

	local refusal = "403: Cannot write to DataStore from studio if API access is not enabled."
	local calls, warnings, blocked = run(true, refusal)
	assert(blocked, "A Studio API refusal must switch the boards off for the session")
	assert(calls == 1, "After Studio refuses once, no further DataStore calls may be made; got " .. calls)
	assert(warnings == 1, "Studio should explain the refusal once, not per player per minute; got " .. warnings)

	local liveCalls, _, liveBlocked = run(false, "502: API Services rejected request with error")
	assert(not liveBlocked, "A live server must never switch its leaderboards off")
	assert(liveCalls == 12, "A live server keeps its normal retries; got " .. liveCalls)
	print("PASS leaderboards: one Studio refusal ends the retries; live servers unaffected")
end

-- 2. Quests and AFK servers serve exactly the players their panels open for.
for _, name in ipairs({ "AfkRewardsService", "QuestService" }) do
	local source = read("src/common/ServerScriptService/Social/" .. name .. ".server.luau")
	assert(not string.find(source, "if true then", 1, true), name .. " must not be hard-disabled")
	assert(string.find(source, "FeatureGate.IsPreviewPlayer(player)", 1, true),
		name .. " must follow Shared.FeatureGate, like its client panel")
	assert(string.find(source, 'local Players', 1, true), name .. " uses Players and must declare it")
end
print("PASS quest and AFK servers answer their preview panels")

-- 3. The announcement bar can fire its remote: MessageHandler ships unsandboxed.
-- (Until 2026-09-19 this also read build_core's copies: "World1 Speedtercorrect.rbxl",
-- "World2Old has to be synced ...rbxl" and output/Update2_core. Builds inject into the root
-- places now, and those copies are gone or stale.)
for _, place in ipairs(PlaceFiles.Files()) do
	local game = roblox.deserializePlace(fs.readFile(place))
	local messages = game:GetService("StarterGui"):FindFirstChild("Messages")
	local handler = messages and messages:FindFirstChild("MessageHandler")
	assert(handler, place .. ": StarterGui.Messages.MessageHandler missing")
	assert(handler.Sandboxed == false,
		place .. ": a sandboxed MessageHandler cannot FireServer on GlobalAnnouncementRequest")
end
print("PASS admin broadcast script is no longer sandboxed in any of the three places")

-- 4. No request for an asset that is not audio.
do
	local shatter = read("src/common/ReplicatedStorage/Shared/GlassShatter.luau")
	assert(not string.find(shatter, "rbxassetid://9114223175", 1, true), "9114223175 is not an audio asset")
	assert(string.find(shatter, "if opts.PlaySound~=false and soundId then", 1, true),
		"The shatter must skip its sound until a real audio id is configured")
end

-- 5. Startup warm-up only asks Marketplace about fields whose type is unknown.
do
	local skins = read("src/common/ServerScriptService/Economy/SkinSystem.server.luau")
	assert(string.find(skins, 'if fieldName == "MaskId" or fieldName == "SuitId" then', 1, true),
		"Shirts, pants and hair are applied with their field named; do not look them up at startup")
	assert(string.find(skins, 'applyAssetToDescription(desc, REVERSE_SHIRT_ID, "Shirt")', 1, true),
		"The Reverse Flash shirt must be applied as a Shirt without a Marketplace lookup")
end

-- 6. Runtime-built treadmills are not reported missing at startup.
do
	local stub = {}
	stub.GetAttribute = function() return nil end
	stub.FindFirstChild = function() return nil end
	stub.WaitForChild = function() return stub end
	local Config = luau.load(read("src/common/ReplicatedStorage/Shared/Config.luau"), {
		environment = {
			game = { GetService = function() return stub end, PlaceId = 85065221510105 },
			workspace = stub, Vector3 = roblox.Vector3, Color3 = roblox.Color3, CFrame = roblox.CFrame,
			Enum = roblox.Enum, UDim2 = roblox.UDim2,
			print = function() end, warn = function() end,
		},
	})()
	local admin3000 = Config.NewWorld1TreadmillProfiles and Config.NewWorld1TreadmillProfiles.Admin3000
	assert(admin3000 and admin3000.SpawnedAtRuntime == true, "Admin3000 is built by the admin panel at runtime")
	local training = read("src/common/ServerScriptService/Progression/TreadmillTraining.server.luau")
	assert(string.find(training, "profile.SpawnedAtRuntime ~= true", 1, true),
		"The startup check must skip treadmills that only exist at runtime")
end

-- 7. No debug prints left in the topbar icon library.
do
	local icon = read("src/common/ReplicatedStorage/Icon/IconController.luau")
	assert(not string.find(icon, 'print("icon = "', 1, true), "IconController debug prints must be gone")
end

print("ALL STUDIO LOG FIX CHECKS PASSED")
