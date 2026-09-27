local fs = require("@lune/fs")
local r = require("@lune/roblox")

for _, file in {"World1 Speedtercorrect.rbxl", "world2 speedtster.rbxl"} do
    print("Checking file:", file)
    local place = r.deserializePlace(fs.readFile(file))
    local ws = place:GetService("Workspace")
    for _, child in ws:GetChildren() do
        if child.Name == "Admin" then
            print("  FOUND Workspace.Admin in", file, "class:", child.ClassName)
            for _, sub in child:GetChildren() do
                print("    sub:", sub.Name, sub.ClassName)
            end
        end
    end
end
