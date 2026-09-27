local fs = require("@lune/fs")
local rb = require("@lune/roblox")
local files = {
	OG = "output/+1 Speedster Escape OGGG.rbxl",
	World1 = "World1Update3New.rbxl",
	World2 = "World2Update3new.rbxl",
	World3 = "World3Update3New.rbxl",
}
for world, file in files do
	local dm = rb.deserializePlace(fs.readFile(file))
	local out = "audit/treadmill_regression/" .. world
	fs.writeDir(out)
	for _, inst in dm:GetDescendants() do
		if inst:IsA("LuaSourceContainer") and (inst.Name == "TreadmillTraining" or inst.Name == "SpeedsterClient" or inst.Name == "Config" or inst.Name == "PlayerStatsBridge") then
			fs.writeFile(out .. "/" .. inst.Name .. ".luau", inst.Source)
			print(world, inst:GetFullName(), #inst.Source)
		end
	end
end
