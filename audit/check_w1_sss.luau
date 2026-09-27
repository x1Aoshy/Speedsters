local fs = require("@lune/fs")
local r = require("@lune/roblox")

local place = r.deserializePlace(fs.readFile("World1 Speedtercorrect.rbxl"))
local sss = place:GetService("ServerScriptService")
for _, inst in sss:GetDescendants() do
    if inst:IsA("BaseScript") then
        print("SSS script:", inst:GetFullName(), "Disabled:", inst.Disabled)
    end
end
