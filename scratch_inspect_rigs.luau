local fs = require("@lune/fs")
local rb = require("@lune/roblox")

local rbxm = fs.readFile("src/assets/SkinRigs.rbxm")
local folder = rb.deserializeModel(rbxm)[1]

for _, model in ipairs(folder:GetChildren()) do
    print("=== Model:", model.Name)
    for _, c in ipairs(model:GetChildren()) do
        if c:IsA("Accessory") then
            print("  Accessory:", c.Name)
        elseif c:IsA("Shirt") then
            print("  Shirt:", c.ShirtTemplate)
        elseif c:IsA("Pants") then
            print("  Pants:", c.PantsTemplate)
        elseif c:IsA("BodyColors") then
            print("  BodyColors Head:", c.HeadColor3)
        end
    end
end
