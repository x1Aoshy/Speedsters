local fs = require("@lune/fs")
local luau = require("@lune/luau")

local files = {
    "src/common/ServerScriptService/Admin/AdminAbusePanelService.server.luau",
    "src/common/StarterPlayer/StarterPlayerScripts/Admin/AdminAbusePanelController.client.luau",
    "src/common/StarterGui/Messages/MessageHandler.client.luau",
    "src/common/ServerScriptService/Economy/SpinWheelService.server.luau",
    "src/common/ServerScriptService/Admin/AdminGiveCommands.server.luau",
    "src/common/ServerScriptService/Progression/PlayerStatsBridge.luau",
}

for _, path in files do
    local src = fs.readFile(path)
    local ok, err = pcall(luau.compile, src)
    if ok then
        print("OK: " .. path)
    else
        error("FAIL: " .. path .. " -> " .. tostring(err))
    end
end
print("ALL 6 FILES COMPILED CLEANLY!")
