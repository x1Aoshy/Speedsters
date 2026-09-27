local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local Vector3, CFrame, Color3 = roblox.Vector3, roblox.CFrame, roblox.Color3

print("=== Starting Treadmill Instant Start & Fluid Burst Tests ===")

-- 1. Test Config Values
local configSource = fs.readFile("src/common/ReplicatedStorage/Shared/Config.luau")
local rsMock = { GetAttribute = function() return 1 end }
local wsMock = { GetAttribute = function() return nil end, FindFirstChild = function() return nil end }
local Config = luau.load(configSource, {
	environment = {
		game = {
			PlaceId = 85065221510105,
			GetService = function(_, n)
				if n == "ReplicatedStorage" then return rsMock end
				if n == "Workspace" then return wsMock end
				return {}
			end
		},
		workspace = wsMock,
		ReplicatedStorage = rsMock,
		Vector3 = Vector3,
		CFrame = CFrame,
		Color3 = Color3,
		Enum = roblox.Enum,
	}
})()

assert(Config.TrainingTickSeconds == 0.1, "Config.TrainingTickSeconds must be 0.1 for responsive 10x/sec cadence")
assert(Config.TreadmillTrainingTickSeconds == 0.5, "Config.TreadmillTrainingTickSeconds must be 0.5")
assert(Config.DefaultPopupBurstCount == 7, "Config.DefaultPopupBurstCount must be 7 (matching OG)")
assert(Config.TreadmillPopupBurstCounts.Treadmill3_superfast == 6, "Treadmill3 burst count must be 6")
assert(Config.TreadmillPopupBurstCounts.Treadmill4_hyperspeed == 10, "Treadmill4 burst count must be 10")
assert(Config.TreadmillPopupBurstCounts.Treadmill5_insanespeed == 18, "Treadmill5 burst count must be 18")
print("  ✓ Config tick rates (0.1s / 0.5s) and burst counts (6, 10, 18) verified")

-- 2. Test Client showSpeedGainBurst logic
local clientSource = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/Movement/SpeedsterClient.client.luau")

-- Verify burstCount is not clamped to 3 in SpeedsterClient source
assert(not clientSource:find("burstCount = math.min%(burstCount, 3%)"), "SpeedsterClient must NOT artificially clamp burstCount to 3")
assert(clientSource:find("MAX_BURST_POPUP_QUEUE_SIZE = 36"), "SpeedsterClient must have MAX_BURST_POPUP_QUEUE_SIZE = 36")
assert(clientSource:find("MAX_RUNNING_POPUP_QUEUE_SIZE = 2"), "SpeedsterClient must have MAX_RUNNING_POPUP_QUEUE_SIZE = 2")
print("  ✓ SpeedsterClient burst queue depth (36) and full burst count preservation verified")

-- 3. Test TreadmillTraining Server Touch & Loop Logic
local ttSource = fs.readFile("src/common/ServerScriptService/Progression/TreadmillTraining.server.luau")

assert(ttSource:find("lastSpeedGrantAt"), "TreadmillTraining must track lastSpeedGrantAt")
assert(ttSource:find("onTreadmillPartTouched"), "TreadmillTraining must define onTreadmillPartTouched")

-- Verify onTreadmillPartTouched awards speed immediately
local touchPattern = "now %- last >= math%.min%(0%.25, cadence%)"
assert(ttSource:find(touchPattern), "TreadmillTraining onTreadmillPartTouched must trigger immediate grant on touch")
print("  ✓ TreadmillTraining instant grant on touch (0ms delay) verified")

-- 4. Test RewardPadClaims immediate feedback
local rpcSource = fs.readFile("src/common/ServerScriptService/Services/RewardPadClaims.luau")
assert(rpcSource:find("winsStat%.Value %+= grantedAmount"), "RewardPadClaims must update leaderstats.Wins immediately")
assert(rpcSource:find("pcall%(onGranted, grantedAmount%)"), "RewardPadClaims must call onGranted immediately")
assert(rpcSource:find("taskSpawn%(settle%)"), "RewardPadClaims must run settle via taskSpawn in background")
print("  ✓ RewardPadClaims 0ms feedback and background commit verified")

print("=== ALL TREADMILL & WIN PAD VERIFICATION TESTS PASSED ===")
