local fs = require("@lune/fs")
local r = require("@lune/roblox")

local place = r.deserializePlace(fs.readFile("world2 speedtster.rbxl"))
local admin = place:GetService("Workspace"):FindFirstChild("Admin")
for _, child in admin:GetChildren() do
    if child.Name == "Model" and child:FindFirstChild("Treadmil", true) then
        print("Found Admin inner Model! Descendants:")
        for _, d in child:GetDescendants() do
            if d:IsA("BasePart") then
                print("  part:", d.Name, "pos:", d.Position)
            end
        end
    end
end
