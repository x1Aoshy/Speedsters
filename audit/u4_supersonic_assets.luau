-- audit/u4_supersonic_assets.luau (2026-09-26, owner: the "Super Sonic vs Dr. Eggman" live event)
-- Lune helper the Update 4 build calls (audit/build_update4.luau edit / verify): puts
-- ReplicatedStorage.SuperSonicEventAssets into each place, the art the event's clients draw with:
--   VFX     the 4 effects pre-extracted to assets/vfx_imported/, renamed for the contract
--           (Shared/SuperSonicEvent.VfxNames): BombExplodeVFX.rbxm -> "BombExplode",
--           EggImpactDefaultVFX.rbxm -> "EggImpact", FireTrailParticlesPart.rbxm -> "FireTrail",
--           BurstHatchVFX.rbxm -> "BurstHatch". Each file holds one root and no script.
--   Meshes  empty here; the Blender agent's kit (audit/u4_event_kit.luau, when it exists:
--           EventKit.Insert(assetsFolder, notes)) fills it.
-- Nothing in the folder may be a script (checked after the kit too). Idempotent through the `U4Asset`
-- stamp "SuperSonicEventAssets": a stamped folder is replaced by a fresh one; one of the same name
-- without the stamp is someone else's and stops the build.
--   local Assets = require("./u4_supersonic_assets")
--   Assets.Insert(dm, notes) -> folder      Assets.Verify(key, dm)      Assets.Build(notes) -> folder
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local Assets = {}

Assets.Name = "SuperSonicEventAssets"
Assets.Stamp = "SuperSonicEventAssets"
Assets.Dir = "assets/vfx_imported/"
Assets.Vfx = {
	{ file = "BombExplodeVFX.rbxm", name = "BombExplode" },
	{ file = "EggImpactDefaultVFX.rbxm", name = "EggImpact" },
	{ file = "FireTrailParticlesPart.rbxm", name = "FireTrail" },
	{ file = "BurstHatchVFX.rbxm", name = "BurstHatch" },
}
Assets.KitFile = "audit/u4_event_kit.luau" -- the Blender agent's kit (optional)

local SCRIPT_CLASSES = { Script = true, LocalScript = true, ModuleScript = true }

-- Every script under root (root included), as full names.
function Assets.Scripts(root: any): { string }
	local found = {}
	local function check(instance)
		if SCRIPT_CLASSES[instance.ClassName] then
			table.insert(found, instance:GetFullName())
		end
	end
	check(root)
	for _, descendant in root:GetDescendants() do
		check(descendant)
	end
	return found
end

-- One VFX file's root, renamed; errors when the file is missing, holds more than one root or a script.
function Assets.LoadVfx(entry: any): any
	local path = Assets.Dir .. entry.file
	assert(fs.isFile(path), "Super Sonic event VFX missing: " .. path)
	local roots = roblox.deserializeModel(fs.readFile(path))
	assert(#roots == 1, path .. " holds " .. #roots .. " roots (one expected)")
	local root = roots[1]
	local scripts = Assets.Scripts(root)
	assert(#scripts == 0, path .. " carries scripts: " .. table.concat(scripts, ", "))
	root.Name = entry.name
	return root
end

-- The folder, built in memory (not parented).
function Assets.Build(notes: { string }?): any
	local folder = roblox.Instance.new("Folder")
	folder.Name = Assets.Name
	folder:SetAttribute("U4Asset", Assets.Stamp)
	local vfx = roblox.Instance.new("Folder")
	vfx.Name = "VFX"
	vfx.Parent = folder
	for _, entry in Assets.Vfx do
		Assets.LoadVfx(entry).Parent = vfx
	end
	local meshes = roblox.Instance.new("Folder")
	meshes.Name = "Meshes"
	meshes.Parent = folder
	if fs.isFile(Assets.KitFile) then
		local ok, kit = pcall(require, "./u4_event_kit")
		if ok and type(kit) == "table" and type(kit.Insert) == "function" then
			kit.Insert(folder, notes or {})
		elseif notes then
			table.insert(notes, "SuperSonicEventAssets: " .. Assets.KitFile .. " has no Insert (" .. tostring(if ok then "not a kit module" else kit) .. "); Meshes left empty")
		end
	elseif notes then
		table.insert(notes, "SuperSonicEventAssets: no " .. Assets.KitFile .. " yet; Meshes left empty")
	end
	local scripts = Assets.Scripts(folder)
	assert(#scripts == 0, "SuperSonicEventAssets may carry no script: " .. table.concat(scripts, ", "))
	return folder
end

function Assets.Insert(dm: any, notes: { string }?): any
	local replicated = dm:GetService("ReplicatedStorage")
	local existing = replicated:FindFirstChild(Assets.Name)
	if existing then
		assert(existing:GetAttribute("U4Asset") == Assets.Stamp,
			"ReplicatedStorage." .. Assets.Name .. " exists without the U4Asset stamp '" .. Assets.Stamp .. "'; not replacing it")
		existing:Destroy()
	end
	local folder = Assets.Build(notes)
	folder.Parent = replicated
	if notes then
		local meshCount = #folder:FindFirstChild("Meshes"):GetChildren()
		table.insert(notes, ("ReplicatedStorage.%s: VFX %d, Meshes %d"):format(Assets.Name, #folder:FindFirstChild("VFX"):GetChildren(), meshCount))
	end
	return folder
end

-- What is wrong with a place's folder (an empty list: nothing).
function Assets.Problems(dm: any): { string }
	local problems = {}
	local folder = dm:GetService("ReplicatedStorage"):FindFirstChild(Assets.Name)
	if not folder then
		return { "ReplicatedStorage." .. Assets.Name .. " is missing" }
	end
	if folder:GetAttribute("U4Asset") ~= Assets.Stamp then
		table.insert(problems, Assets.Name .. " has no U4Asset stamp")
	end
	local vfx = folder:FindFirstChild("VFX")
	if not vfx then
		table.insert(problems, Assets.Name .. ".VFX is missing")
	else
		for _, entry in Assets.Vfx do
			if not vfx:FindFirstChild(entry.name) then
				table.insert(problems, Assets.Name .. ".VFX." .. entry.name .. " is missing")
			end
		end
	end
	local meshes = folder:FindFirstChild("Meshes")
	if not (meshes and meshes.ClassName == "Folder") then
		table.insert(problems, Assets.Name .. ".Meshes is missing")
	end
	for _, path in Assets.Scripts(folder) do
		table.insert(problems, "script inside: " .. path)
	end
	return problems
end

function Assets.Verify(key: string, dm: any)
	local problems = Assets.Problems(dm)
	assert(#problems == 0, key .. ": " .. table.concat(problems, "; "))
end

return Assets
