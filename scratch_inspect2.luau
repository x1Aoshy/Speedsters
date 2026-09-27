local fs = require("@lune/fs")
local rb = require("@lune/roblox")

local w1 = rb.deserializePlace(fs.readFile("World1Update3New.rbxl"))
local ss = w1:GetService("ServerStorage")
local rs = w1:GetService("ReplicatedStorage")

print("=== ServerStorage.RawCosmeticPack ===")
local rcp = ss:FindFirstChild("RawCosmeticPack")
if rcp then
    for _, c in ipairs(rcp:GetChildren()) do
        print(c.ClassName, c.Name)
    end
end

print("=== ReplicatedStorage.SkinRigs ===")
local sr = rs:FindFirstChild("SkinRigs")
if sr then
    for _, c in ipairs(sr:GetChildren()) do
        print(c.ClassName, c.Name)
    end
end
