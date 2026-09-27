local fs = require("@lune/fs")
local rb = require("@lune/roblox")

local places = {
    World1 = "World1Update3New.rbxl",
    World2 = "World2Update3new.rbxl",
    World3 = "World3Update3New.rbxl",
}

local pathsToCheck = {
    { "ReplicatedStorage", "Shared", "FeatureGate" },
    { "ReplicatedStorage", "Shared", "Config" },
    { "ServerScriptService", "Services", "PadTouchService" },
    { "ServerScriptService", "Economy", "SpinWheelService" },
    { "StarterGui", "Messages", "MessageHandler" },
    { "ServerScriptService", "Admin", "AdminAbusePanelService" },
    { "StarterPlayer", "StarterPlayerScripts", "Admin", "AdminAbusePanelController" },
    { "ServerScriptService", "Progression", "PlayerStatsBridge" },
    { "ServerScriptService", "Admin", "AdminGiveCommands" },
}

for world, file in places do
    print("Checking " .. world .. " (" .. file .. "):")
    local dm = rb.deserializePlace(fs.readFile(file))
    for _, path in pathsToCheck do
        local cur = dm
        local found = true
        for _, name in path do
            cur = cur:FindFirstChild(name)
            if not cur then
                found = false
                break
            end
        end
        print("  " .. table.concat(path, ".") .. ": " .. (if found then "FOUND" else "MISSING"))
    end
end
