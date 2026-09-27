local r = require("@lune/roblox")
local fs = require("@lune/fs")
local place = r.deserializePlace(fs.readFile("World1 Speedtercorrect.rbxl"))
local sg = place:GetService("StarterGui")
local mh = sg:FindFirstChild("Mainhud")
if mh then
    print("Mainhud DisplayOrder:", mh.DisplayOrder)
    print("Mainhud ZIndexBehavior:", mh.ZIndexBehavior)
end