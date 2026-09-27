local StatsService = require("../merged/World1/ServerScriptService/Services/Stats/StatsService")
local Actor = require("../merged/World1/ServerScriptService/Services/Data/SessionActor")
local Adapter = require("../merged/World1/ServerScriptService/Services/Data/DataStoreAdapter")

local testCases = {
    { name = "Fresh", speed = 1, rebirths = 0 },
    { name = "Mid", speed = 50000, rebirths = 2 },
    { name = "High", speed = 1e9, rebirths = 8 },
    { name = "Very High", speed = 1e15, rebirths = 15 },
    { name = "Float Gap Limit", speed = 9007199254740992, rebirths = 20 },
    { name = "Extreme", speed = 1e18, rebirths = 25 },
    { name = "Super Extreme", speed = 1e35, rebirths = 50 },
}

print("=== RUNNING STATS GAIN SIMULATION ===")
for _, tc in ipairs(testCases) do
    local store = Adapter.CreateMock({
        ["Player_" .. tc.name] = {
            Version = 306,
            Speed = tc.speed,
            Wins = 1000,
            Rebirths = tc.rebirths,
        }
    })
    local a = Actor.new({ userId = 100, storeAdapter = store, keyPrefix = "Player_" .. tc.name })
    a.key = "Player_" .. tc.name
    local h = a:Open()
    assert(h.ok)
    
    local before = a:Inspect(h.value)
    local res = a:AccrueSpeed(h.value, 1, {
        permanent = 1,
        global = 1,
        trail = 1,
        aura = 1,
        upgrade = 1,
        gamepass = 1,
        suit = 1,
        rebirth = 1.5 ^ tc.rebirths,
        vip = 1,
        potion = 1,
        serverBoost = 1,
    })
    local after = a:Inspect(h.value)
    
    local diff = after.value.profile.Speed - before.value.profile.Speed
    local wholeGain = (typeof(res) == "table" and res.whole and res.whole > 0 and res.whole) or nil
    local amount = (diff > 0 and diff) or wholeGain or 1
    
    print(string.format("[%s] Speed: %e, Rebirths: %d", tc.name, tc.speed, tc.rebirths))
    print(string.format("   res.ok: %s, res.whole: %s, res.actualAdded: %s", tostring(res.ok), tostring(res.whole), tostring(res.actualAdded)))
    print(string.format("   diff: %s, wholeGain: %s, amount: %s", tostring(diff), tostring(wholeGain), tostring(amount)))
end