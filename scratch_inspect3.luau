local fs = require("@lune/fs")
local rb = require("@lune/roblox")

local w1 = rb.deserializePlace(fs.readFile("World1Update3New.rbxl"))
local ss = w1:GetService("ServerStorage")
local rcp = ss:FindFirstChild("RawCosmeticPack")

if rcp then
    for i, c in ipairs(rcp:GetChildren()) do
        if c:IsA("Model") then
            print(string.format("Dummy %d:", i))
            for _, child in ipairs(c:GetChildren()) do
                if child:IsA("Accessory") or child:IsA("Shirt") or child:IsA("Pants") then
                    print("  ", child.ClassName, child.Name)
                end
            end
        end
    end
end
