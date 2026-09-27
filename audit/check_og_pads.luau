local fs = require("@lune/fs")
local r = require("@lune/roblox")

local og = r.deserializePlace(fs.readFile("+1 Speedster Escape OGGG.rbxl"))
local pad = og:GetService("ServerScriptService"):FindFirstChild("NewWorld1ManualStagePads", true)
if pad then
    print("Found NewWorld1ManualStagePads in OGGG!")
    local lines = pad.Source:split("\n")
    for i = 40, 65 do
        if lines[i] then print(i, lines[i]) end
    end
else
    print("NewWorld1ManualStagePads NOT in OGGG!")
end
