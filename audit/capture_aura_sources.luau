-- Capture the original aura models from AURAS/ into src/assets, so build_core puts them
-- in every world's ServerStorage.AuthoredAuras and CosmeticTemplateBuilder builds the
-- equipped auras from their real structure (limbs, attachments, parts, Forge VFX tags and
-- attributes) instead of NewAurasFactory's flattened copy.
--
--   AURAS/AquaticOpenSource.rbxm   -> src/assets/AquaticOpenSource.rbxm   (Water,  Aura08)
--   AURAS/GalacticOpenSource.rbxm  -> src/assets/GalacticOpenSource.rbxm  (Galaxy, Aura09)
--   AURAS/CursedEnergyAlisor.rbxm  -> src/assets/CursedEnergy.rbxm        (Cursed, Aura10-13)
--
-- Every script goes (the showcase rigs' idle and orbit animations, the READ ME notes: the
-- game animates the orbits itself), so do the rigs' name signs, and so do the Cursed
-- file's four plain dummies.
--
-- Usage: lune run audit/capture_aura_sources.luau
local fs = require("@lune/fs")
local rb = require("@lune/roblox")

-- Scripts, and the showcase rigs' floating name signs (a newer Studio saved their text
-- with properties the places' own labels do not have, and they are no part of an aura).
local function stripScripts(root)
	local removed = 0
	for _, d in root:GetDescendants() do
		if d.Parent and (d:IsA("LuaSourceContainer") or d:IsA("BillboardGui") or d:IsA("SurfaceGui")) then
			d:Destroy()
			removed += 1
		end
	end
	return removed
end

local function save(root, file)
	for _, d in root:GetDescendants() do
		assert(not d:IsA("LuaSourceContainer"), "A script survived in " .. file)
	end
	fs.writeFile(file, rb.serializeModel({ root }))
	print(("captured %s -> %s (%d instances)"):format(root.Name, file, #root:GetDescendants() + 1))
end

do
	local root = rb.deserializeModel(fs.readFile("AURAS/AquaticOpenSource.rbxm"))[1]
	local removed = stripScripts(root)
	save(root, "src/assets/AquaticOpenSource.rbxm")
	print("  removed " .. removed .. " scripts and signs")
end

do
	local root = rb.deserializeModel(fs.readFile("AURAS/GalacticOpenSource.rbxm"))[1]
	local removed = stripScripts(root)
	-- The original folder is spelt "GlacticOpenSource"; the game calls it Galactic.
	root.Name = "GalacticOpenSource"
	save(root, "src/assets/GalacticOpenSource.rbxm")
	print("  removed " .. removed .. " scripts and signs")
end

do
	local folder = rb.Instance.new("Folder")
	folder.Name = "CursedEnergy"
	for _, root in rb.deserializeModel(fs.readFile("AURAS/CursedEnergyAlisor.rbxm")) do
		if root:IsA("BasePart") and string.find(root.Name, "Cursed Energy", 1, true) then
			stripScripts(root)
			root.Parent = folder
		end
	end
	assert(#folder:GetChildren() == 4, "The four Cursed Energy parts")
	save(folder, "src/assets/CursedEnergy.rbxm")
end
