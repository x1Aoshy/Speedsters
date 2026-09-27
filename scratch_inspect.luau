local fs = require("@lune/fs")
local rb = require("@lune/roblox")

local w1 = rb.deserializePlace(fs.readFile("World1Update3New.rbxl"))
print("=== Workspace in World1 ===")
for _, c in ipairs(w1.Workspace:GetChildren()) do
    if c:IsA("Model") or c:IsA("Folder") then
        print(c.ClassName, c.Name)
    end
end
if w1.Workspace:FindFirstChild("Folder") then
    print("=== Workspace.Folder ===")
    for _, c in ipairs(w1.Workspace.Folder:GetChildren()) do
        print(c.ClassName, c.Name)
    end
end
if w1:GetService("ServerStorage") then
    print("=== ServerStorage ===")
    for _, c in ipairs(w1:GetService("ServerStorage"):GetChildren()) do
        print(c.ClassName, c.Name)
    end
end
if w1:GetService("ReplicatedStorage") then
    print("=== ReplicatedStorage ===")
    for _, c in ipairs(w1:GetService("ReplicatedStorage"):GetChildren()) do
        print(c.ClassName, c.Name)
    end
end
