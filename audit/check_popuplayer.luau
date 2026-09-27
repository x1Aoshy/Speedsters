local fs = require("@lune/fs")
local s = fs.readFile("audit/merged/World1/StarterPlayer/StarterPlayerScripts/Movement/SpeedsterClient.luau")
local lines = s:split("\n")
for i, line in ipairs(lines) do
    if line:find("getPopupLayer") or line:find("popupLayer") or line:find("SpeedPopupLayer") then
        print(string.format("%4d: %s", i, line))
    end
end
