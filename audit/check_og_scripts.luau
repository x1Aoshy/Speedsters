local fs = require("@lune/fs")
local r = require("@lune/roblox")

local og = r.deserializePlace(fs.readFile("+1 Speedster Escape OGGG.rbxl"))
for _, inst in og:GetDescendants() do
    if inst:IsA("LuaSourceContainer") and (inst.Name:lower():find("treadmill") or inst.Name:lower():find("speed") or inst.Name:lower():find("train")) then
        print("OG script:", inst:GetFullName(), inst.ClassName)
    end
end
