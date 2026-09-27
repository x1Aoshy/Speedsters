local fs = require("@lune/fs")
local r = require("@lune/roblox")

local og = r.deserializePlace(fs.readFile("+1 Speedster Escape OGGG.rbxl"))
local tt = og:GetService("ServerScriptService"):FindFirstChild("TreadmillTraining")
local tol = og:GetService("ServerScriptService"):FindFirstChild("TreadmillOverheadLabels")
if tt then
    print("=== OGGG TreadmillTraining (first 100 lines) ===")
    local lines = tt.Source:split("\n")
    for i = 1, math.min(100, #lines) do
        print(string.format("%3d: %s", i, lines[i]))
    end
end
if tol then
    print("=== OGGG TreadmillOverheadLabels (first 100 lines) ===")
    local lines = tol.Source:split("\n")
    for i = 1, math.min(100, #lines) do
        print(string.format("%3d: %s", i, lines[i]))
    end
end
