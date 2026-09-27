local task = require("@lune/task")
local Actor = require("./fixed/V2/ServerScriptService/Services/Data/SessionActor")
local Adapter = require("./fixed/V2/ServerScriptService/Services/Data/DataStoreAdapter")
local DataService = require("./fixed/V2/ServerScriptService/Services/Data/DataService")

print("=== Testing Bridge Wiring ===")

-- Mock environment
local mockStore = Adapter.CreateMock({
    Player_100 = {
        Version = 306,
        Speed = 100,
        Wins = 1000,
        PermanentBaseSpeedMultiplier = 1,
        PermanentWinsMultiplier = 1,
        World2Unlocked = false,
        ProcessedReceipts = {},
        OwnedTrails = {},
        OwnedAuras = {},
    }
})

DataService.Init({ storeAdapter = mockStore })
DataService.Start(mockStore)
local handleRes = DataService.Open(100)
assert(handleRes.ok, "Failed to init session: " .. tostring(handleRes.error))
local handle = handleRes.value

-- 1. Test multiplier commit
local multRes = DataService.Commit(handle, {
    operationId = "test_mult_1",
    fingerprint = "speed_mult_4",
    commands = {
        { kind = "SetPersistent", key = "PermanentBaseSpeedMultiplier", value = 4 }
    }
})
assert(multRes.kind == "Committed", "Multiplier commit failed: " .. tostring(multRes.kind))
assert(DataService.Inspect(handle).value.profile.PermanentBaseSpeedMultiplier == 4, "PermanentBaseSpeedMultiplier mismatch")
print("  [PASS] PermanentBaseSpeedMultiplier commits to profile (value: 4)")

-- 2. Test wins multiplier commit
local winsMultRes = DataService.Commit(handle, {
    operationId = "test_wins_mult_1",
    fingerprint = "wins_mult_2",
    commands = {
        { kind = "SetPersistent", key = "PermanentWinsMultiplier", value = 2 }
    }
})
assert(winsMultRes.kind == "Committed", "Wins multiplier commit failed: " .. tostring(winsMultRes.kind))
assert(DataService.Inspect(handle).value.profile.PermanentWinsMultiplier == 2, "PermanentWinsMultiplier mismatch")
print("  [PASS] PermanentWinsMultiplier commits to profile (value: 2)")

-- 3. Test World2Unlocked commit
local w2Res = DataService.Commit(handle, {
    operationId = "test_w2_unlock",
    fingerprint = "unlock_w2",
    commands = {
        { kind = "SetPersistent", key = "World2Unlocked", value = true }
    }
})
assert(w2Res.kind == "Committed", "World2Unlocked commit failed: " .. tostring(w2Res.kind))
assert(DataService.Inspect(handle).value.profile.World2Unlocked == true, "World2Unlocked mismatch")
print("  [PASS] World2Unlocked commits to profile (value: true)")

-- 4. Test Speed purchase commit
local speedRes = DataService.Commit(handle, {
    operationId = "test_speed_buy",
    fingerprint = "speed_500",
    commands = {
        { kind = "GrantExact", stat = "Speed", amount = 500 }
    }
})
assert(speedRes.kind == "Committed", "Speed purchase commit failed: " .. tostring(speedRes.kind))
assert(DataService.Inspect(handle).value.profile.Speed == 600, "Speed mismatch after purchase (expected 600, got " .. tostring(DataService.Inspect(handle).value.profile.Speed) .. ")")
print("  [PASS] Speed purchase commits to profile (value: 600)")

-- 5. Test Release and verify DataStore persistence
local releaseRes = DataService.Release(handle)
assert(releaseRes.kind == "Released", "Release failed: " .. tostring(releaseRes.kind))

local savedData = mockStore:GetData("Player_100")
assert(savedData.PermanentBaseSpeedMultiplier == 4, "DataStore PermanentBaseSpeedMultiplier mismatch")
assert(savedData.PermanentWinsMultiplier == 2, "DataStore PermanentWinsMultiplier mismatch")
assert(savedData.World2Unlocked == true, "DataStore World2Unlocked mismatch")
assert(savedData.Speed == 600, "DataStore Speed mismatch")
print("  [PASS] All changes durably persisted in DataStore upon release!")

print("\nALL BRIDGE WIRING TESTS PASSED PERFECTLY!")