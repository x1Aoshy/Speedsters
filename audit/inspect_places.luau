local fs = require("@lune/fs")
local r = require("@lune/roblox")

for _, file in {"World1 Speedtercorrect.rbxl", "world2 speedtster.rbxl"} do
    print("=== INSPECTING:", file, "===")
    local place = r.deserializePlace(fs.readFile(file))
    local ws = place:GetService("Workspace")
    local rs = place:GetService("ReplicatedStorage")
    print("PlaceWorldNumber attr on RS:", rs:GetAttribute("PlaceWorldNumber"))
    print("NewWorld1MapActive attr on RS:", rs:GetAttribute("NewWorld1MapActive"))
    print("neworld1 in workspace:", ws:FindFirstChild("neworld1") ~= nil)

    print("Children of workspace:")
    for _, child in ws:GetChildren() do
        if child:IsA("Model") or child:IsA("Folder") then
            print("  WS child:", child.Name, child.ClassName)
        end
    end

    print("Searching treadmills in place:")
    for _, inst in place:GetDescendants() do
        local nameLower = inst.Name:lower()
        if nameLower:find("treadmil") or nameLower:find("needoh") or nameLower:find("hacker") or nameLower:find("admin") or nameLower:find("basic") or nameLower:find("golden") or nameLower:find("diamond") or nameLower:find("candy") then
            if inst:IsA("Model") or inst:IsA("BasePart") or inst:IsA("Folder") then
                print("    Found:", inst:GetFullName(), "(" .. inst.ClassName .. ")")
            end
        end
    end
end
