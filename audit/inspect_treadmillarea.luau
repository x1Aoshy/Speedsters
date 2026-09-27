local fs = require("@lune/fs")
local r = require("@lune/roblox")

local place = r.deserializePlace(fs.readFile("World1 Speedtercorrect.rbxl"))
local area = place:GetService("Workspace"):FindFirstChild("neworld1"):FindFirstChild("Treadmillarea")
if area then
    print("Found Treadmillarea! Children:")
    for _, child in area:GetChildren() do
        print("  child:", child.Name, child.ClassName)
        for _, sub in child:GetChildren() do
            print("    sub:", sub.Name, sub.ClassName)
        end
    end
end
