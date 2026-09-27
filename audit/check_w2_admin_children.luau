local fs = require("@lune/fs")
local r = require("@lune/roblox")

local place = r.deserializePlace(fs.readFile("world2 speedtster.rbxl"))
local admin = place:GetService("Workspace"):FindFirstChild("Admin")
if admin then
    print("Children of Workspace.Admin:")
    for _, child in admin:GetChildren() do
        local belt = child:FindFirstChild("Treadmil", true)
        print("  ", child.Name, child.ClassName, "has Treadmil:", belt ~= nil)
        if belt then
            print("     Treadmil path:", belt:GetFullName())
        end
    end
end
