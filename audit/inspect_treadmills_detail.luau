local fs = require("@lune/fs")
local r = require("@lune/roblox")

local place = r.deserializePlace(fs.readFile("World1 Speedtercorrect.rbxl"))
local nw1 = place:GetService("Workspace"):FindFirstChild("neworld1")
local names = {"Basic", "Golden", "Fast", "Candy", "Diamond", "Needoh", "Admin", "Hacker"}
for _, name in names do
    local item = nw1:FindFirstChild(name)
    if item then
        print("Treadmill found:", name, "class:", item.ClassName)
        for _, child in item:GetChildren() do
            print("   child:", child.Name, child.ClassName)
        end
    else
        print("Treadmill NOT in nw1:", name)
    end
end
