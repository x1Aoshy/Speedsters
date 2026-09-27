local fs = require("@lune/fs")
local r = require("@lune/roblox")

local place = r.deserializePlace(fs.readFile("World1 Speedtercorrect.rbxl"))
local ws = place:GetService("Workspace")
print("=== Treadmills in World1 Speedtercorrect.rbxl ===")
for _, inst in ws:GetDescendants() do
    if inst.Name:match("Treadmill") or inst.Name:match("treadmill") then
        print("  Found:", inst:GetFullName(), "(" .. inst.ClassName .. ")")
    end
end
