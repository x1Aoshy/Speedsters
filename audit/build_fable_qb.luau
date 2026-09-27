-- audit/build_fable_qb.luau  (2026-09-21)
-- The QoL bug pass of 2026-09-21 (night): the Evolve guide saved once per account instead of
-- coming back on every server, the first-time tutorial saved as seen only once the first Win
-- pad is claimed (and off in World 3), the Robux Speed/Wins multipliers no longer lowered by
-- the admin 2x Speed toggle or lied about by the HUD, a gifted 2x Speed that is kept, and the
-- bosses (Zoom, Reverse Flash, Sonic.EXE) plus the hammer backstop killing only on what the
-- runner's own screen shows.
--
-- The list of sources is not written by hand: it is every file of src/ that differs from
-- output/FableQB_20260921/backup_src/ (src as the places carried it before this work, taken before
-- the first edit), plus every file that is new since. Each changed source is guarded by its
-- backup copy, so a place edited in Studio meanwhile stops the build instead of being lost.
--
--   lune run audit/build_fable_qb.luau          build
--   lune run audit/build_fable_qb.luau list     only print what it would put in
local fs = require("@lune/fs")
local process = require("@lune/process")
local Lib = require("./fable_build_lib")

-- The second run (the final review's fixes) guards against what the first run put in the places:
-- backup_src_v2, written by scratch/qb_snapshot_v2.luau from the places after that run.
local BACKUP = if fs.isDir("output/FableQB_20260921/backup_src_v2")
	then "output/FableQB_20260921/backup_src_v2/"
	else "output/FableQB_20260921/backup_src/"

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

Lib.run({ output = "output/FableQB_20260921", sources = sources })
