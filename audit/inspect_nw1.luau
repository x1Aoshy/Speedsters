local fs = require("@lune/fs")
local r = require("@lune/roblox")

local place = r.deserializePlace(fs.readFile("World1 Speedtercorrect.rbxl"))
local nw1 = place:GetService("Workspace"):FindFirstChild("neworld1")
if nw1 then
    print("neworld1 children:")
    for _, child in nw1:GetChildren() do
        print("  nw1 child:", child.Name, child.ClassName)
    end
end
