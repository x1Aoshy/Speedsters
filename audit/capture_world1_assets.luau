-- Capture the art the user added to World1Update3.rbxl in Studio (2026-09-17)
-- into src/assets, so build_core can put it in every world.
--
--   ServerStorage.TungTung  -> src/assets/TungTung.rbxm  (the Tung Tung Sahur skin rig)
--   ServerStorage.67        -> src/assets/Aura67.rbxm    (the Aura 67 effect part)
--
-- The rig came from a free model: it carried two Scripts named PositionsFix, each
-- hidden inside two nested Configuration folders (one under the Humanoid, one under
-- the right wrist attachment). Roblox had already blanked them ("removed for security
-- reasons"). That is the usual free-model backdoor pattern, so every script and its
-- hiding folders are dropped here, and build_core refuses an asset with any script.
--
-- Usage: lune run audit/capture_world1_assets.luau
local fs = require("@lune/fs")
local rb = require("@lune/roblox")

local place = rb.deserializePlace(fs.readFile("World1Update3.rbxl"))
local storage = place:GetService("ServerStorage")

local function capture(name, file)
	local source = storage:FindFirstChild(name) or storage:FindFirstChild("AuthoredAuras") and storage.AuthoredAuras:FindFirstChild(name)
	assert(source, "World1NewestStable has no ServerStorage." .. name)
	local copy = source:Clone()
	local removed = {}
	for _, d in copy:GetDescendants() do
		if d.Parent and d:IsA("LuaSourceContainer") then
			-- Climb out of the Configuration folders that exist only to hide it.
			local top = d
			while top.Parent and top.Parent ~= copy and top.Parent:IsA("Configuration") and #top.Parent:GetChildren() == 1 do
				top = top.Parent
			end
			table.insert(removed, top:GetFullName() .. " (" .. d.Name .. ")")
			top:Destroy()
		end
	end
	for _, d in copy:GetDescendants() do
		assert(not d:IsA("LuaSourceContainer"), "A script survived in " .. name)
	end
	fs.writeDir("src/assets")
	fs.writeFile(file, rb.serializeModel({ copy }))
	print(("captured %s -> %s (%d instances, %d scripts removed)"):format(name, file, #copy:GetDescendants() + 1, #removed))
	for _, path in removed do
		print("  removed " .. path)
	end
end

capture("TungTung", "src/assets/TungTung.rbxm")
capture("67", "src/assets/Aura67.rbxm")
