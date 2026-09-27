local fs = require("@lune/fs")
local r = require("@lune/roblox")

local place = r.deserializePlace(fs.readFile("World1 Speedtercorrect.rbxl"))
local ws = place:GetService("Workspace")
local nw1 = ws:FindFirstChild("neworld1")

print("Searching stages in neworld1:")
for i = 1, 11 do
    local exactName = "stage" .. tostring(i)
    local found = nw1:FindFirstChild(exactName, true)
    if found then
        print("  Found stage", i, ":", found:GetFullName(), found.ClassName)
    else
        print("  NOT FOUND stage", i)
    end
end
