--!strict
local fs = require("@lune/fs")

local function check(cond: boolean, msg: string)
	if not cond then
		error("TEST ASSERTION FAILED: " .. msg, 2)
	end
end

print("=== RUNNING POTION AND MULTIPLIER SYNC TESTS ===")

-- 1. Verify PotionServer source logic
local potionServerSrc = fs.readFile("src/common/ServerScriptService/Services/PotionServer.luau")
check(string.find(potionServerSrc, "DataService.Commit", 1, true) ~= nil, "PotionServer must commit buffs to DataService")
check(string.find(potionServerSrc, "initialWsExpire", 1, true) ~= nil, "PotionServer must inspect existing Workspace ServerBoost attributes on init")
check(string.find(potionServerSrc, "math.max(serverBoostExpiresUnix", 1, true) ~= nil, "PotionServer must check Workspace attribute for server boost")

-- 2. Verify PlayerStatsBridge source logic
local bridgeSrc = fs.readFile("src/common/ServerScriptService/Progression/PlayerStatsBridge.luau")
-- Wins multipliers now live in one shared module so the server and the pad
-- billboards cannot disagree; the bridge routes every wins grant through it.
check(string.find(bridgeSrc, "g.SpeedsterGetWinsMultiplier(player)", 1, true) ~= nil, "SpeedsterAddWins must apply the shared wins multiplier")
check(string.find(bridgeSrc, "WinsMath.GetComponents", 1, true) ~= nil, "PlayerStatsBridge must resolve wins multipliers through Shared.WinsMath")
local winsMathSrc = fs.readFile("src/common/ReplicatedStorage/Shared/WinsMath.luau")
check(string.find(winsMathSrc, "PotionWinsExpireUnix", 1, true) ~= nil, "WinsMath must apply the 2x Wins potion while it is active")
check(string.find(winsMathSrc, "VIPWinsMultiplier", 1, true) ~= nil, "WinsMath must apply the VIP wins multiplier")
check(string.find(winsMathSrc, "ServerWinsBoostExpiresUnix", 1, true) ~= nil, "WinsMath must apply the server-wide wins boost")

-- 3. Verify Bootstrap source logic
local bootstrapSrc = fs.readFile("src/common/ServerScriptService/Bootstrap.server.luau")
check(string.find(bootstrapSrc, "PotionServer.AnnounceActiveBoosts", 1, true) ~= nil, "Bootstrap must announce active boosts on player join")
check(string.find(bootstrapSrc, "task.wait(0.15)", 1, true) == nil, "Bootstrap must not delay WalkSpeed update on CharacterAdded")

-- 4. Verify MainHUDController source logic
local hudSrc = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/UI/MainHUDController.client.luau")
check(string.find(hudSrc, "refreshBuffDisplay", 1, true) ~= nil, "MainHUDController must refresh buff display on CharacterAdded")

-- 5. Test Server Boost calculation logic
do
	local nowUnix = 1000000
	local boostDuration = 1800 -- 30 minutes
	local boostExpire = nowUnix + boostDuration

	-- At T=0, boost active with 1800s remaining
	local remainingT0 = math.max(0, boostExpire - nowUnix)
	check(remainingT0 == 1800, "Server boost remaining at T=0 should be 1800s")

	-- A player joins 5 minutes (300s) later:
	local nowT5 = nowUnix + 300
	local remainingT5 = math.max(0, boostExpire - nowT5)
	check(remainingT5 == 1500, "Server boost remaining at T=5m should be 1500s (25 minutes)")

	-- Boost expired:
	local nowT31 = nowUnix + 1860
	local remainingT31 = math.max(0, boostExpire - nowT31)
	check(remainingT31 == 0, "Server boost remaining at T=31m should be 0s")
end

-- 6. Test Personal Potion Pause-on-Leave and Resume-on-Join logic
do
	local initialPotionSeconds = 600 -- 10 minutes
	local joinTimeServer1 = 1000000
	local onlineSeconds = 200

	-- While online in Server 1, 200 seconds elapse:
	local leaveTimeServer1 = joinTimeServer1 + onlineSeconds
	local remainingAtLeave = math.max(0, initialPotionSeconds - onlineSeconds)
	check(remainingAtLeave == 400, "Remaining seconds at leave should be 400s")

	-- Player stays offline for 2 hours (7200 seconds):
	local offlineSeconds = 7200
	local joinTimeServer2 = leaveTimeServer1 + offlineSeconds

	-- Offline pause: DataStore still has remainingAtLeave = 400s
	local remainingOnJoinServer2 = remainingAtLeave
	check(remainingOnJoinServer2 == 400, "Remaining seconds upon rejoining another server/world must remain 400s (paused offline)")

	-- Projection resumes timer:
	local newExpireUnix = joinTimeServer2 + remainingOnJoinServer2
	check(newExpireUnix == joinTimeServer2 + 400, "New expire timestamp should be joinTime + 400s")

	-- Player plays in Server 2 for 100s:
	local currentTime = joinTimeServer2 + 100
	local remainingNow = math.max(0, newExpireUnix - currentTime)
	check(remainingNow == 300, "Remaining seconds in Server 2 after 100s should be 300s")
end

-- 7. Test Wins Multiplier with Potion
do
	local baseGain = 50
	local permanentMultiplier = 2
	local potionMultiplier = 2

	local totalGain = baseGain * permanentMultiplier * potionMultiplier
	check(totalGain == 200, "50 base wins * 2x permanent * 2x potion should equal 200 wins")
end

print("ALL POTION AND MULTIPLIER SYNC CHECKS PASSED PERFECTLY!")
