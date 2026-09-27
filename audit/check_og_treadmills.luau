local fs = require("@lune/fs")
local r = require("@lune/roblox")

local og = r.deserializePlace(fs.readFile("+1 Speedster Escape OGGG.rbxl"))
local nw1 = og:GetService("Workspace"):FindFirstChild("neworld1")
if nw1 then
    print("neworld1 exists in OGGG!")
else
    print("neworld1 does NOT exist in OGGG!")
    print("Searching treadmills in OGGG:")
    for _, inst in og:GetDescendants() do
        if inst.Name:lower():find("treadmill") then
            print("  OG treadmill:", inst:GetFullName(), inst.ClassName)
        end
    end
end
