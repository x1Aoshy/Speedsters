local fs = require("@lune/fs")
local r = require("@lune/roblox")

local place = r.deserializePlace(fs.readFile("World1 Speedtercorrect.rbxl"))
local admin = place:GetService("Workspace"):FindFirstChild("Admin")
if admin then
    print("Found Workspace.Admin! ClassName:", admin.ClassName)
    for _, child in admin:GetChildren() do
        print("  child:", child.Name, child.ClassName)
        if child:IsA("Model") or child:IsA("BasePart") then
            local cf, sz = child:GetBoundingBox()
            print("    bounds size:", sz, "pos:", cf.Position)
        end
    end
    local cf, sz = admin:GetBoundingBox()
    print("TOTAL Workspace.Admin bounds:", sz, "pos:", cf.Position)
else
    print("Workspace.Admin not found!")
end
