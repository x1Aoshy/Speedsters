-- audit/build_fable_treadmill_vfx.luau  (2026-09-22)
-- Treadmill VFX cleanup: one themed effect per treadmill (the server publishes the player's
-- CurrentTreadmillName) instead of the V40 template's 10 multi-coloured emitters on every
-- runner, and phone LOD for other players' effects.
--
-- The list of sources is every file of src/ that differs from output/FableTreadmillVfx_20260922/backup_src/
-- (src as the places carried it before this pass), plus every new file; each changed source is
-- guarded by its backup copy, so a place edited in Studio meanwhile stops the build.
--
--   lune run audit/build_fable_treadmill_vfx.luau          build
--   lune run audit/build_fable_treadmill_vfx.luau list     only print what it would put in
local fs = require("@lune/fs")
local process = require("@lune/process")
local Lib = require("./fable_build_lib")

local BACKUP = "output/FableTreadmillVfx_20260922/backup_src/"

local function lf(text)
	return (text:gsub("\r\n", "\n"))
end

local function walk(dir, out)
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			walk(path, out)
		elseif name:match("%.luau$") then
			table.insert(out, path)
		end
	end
	return out
end

local files = walk("src/common", {})
walk("src/worlds", files)
table.sort(files)

local sources, changed, added = {}, {}, {}
for _, path in files do
	local relative = path:gsub("^src/", "")
	local backup = BACKUP .. relative
	local world = path:match("^src/worlds/([^/]+)/")
	local spec = { source = path, worlds = if world then { world } else nil }
	if not fs.isFile(backup) then
		table.insert(sources, spec)
		table.insert(added, path)
	elseif lf(fs.readFile(backup)) ~= lf(fs.readFile(path)) then
		spec.guard = backup
		table.insert(sources, spec)
		table.insert(changed, path)
	end
end
-- Nothing may have been deleted from src by this work.
for _, path in walk(BACKUP:sub(1, -2), {}) do
	local relative = path:sub(#BACKUP + 1)
	if relative:match("^common/") or relative:match("^worlds/") then
		assert(fs.isFile("src/" .. relative), "src/" .. relative .. " was deleted: restore it or retire it as a comment stub")
	end
end

print(("%d changed, %d new source(s)"):format(#changed, #added))
for _, path in changed do
	print("  changed " .. path)
end
for _, path in added do
	print("  new     " .. path)
end
if process.args[1] == "list" then
	return
end

assert(#sources > 0, "nothing to build")
Lib.run({ output = "output/FableTreadmillVfx_20260922", sources = sources })
