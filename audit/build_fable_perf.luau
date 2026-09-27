-- audit/build_fable_perf.luau  (2026-09-22)
-- The live-error, phone-performance and retention pass of 2026-09-22: the Raining Tacos and
-- ragdoll assets this experience may not load (about 2.8M live errors), the AsmrEffects /
-- InstantMovement / SpinWheel / ZoomArenaAmbience script errors, phone quality tiers (other
-- players' auras, Bloom/SunRays, lobby Highlights, admin snow and rainbow treadmills), the
-- World 2 gate (6 Rebirths + Level 50, from Config) and walk speed (x0.5, never under 8 after
-- a rebirth), Sonic.EXE's chase relative to its runner, analytics fixes, and place content
-- (audit/perf_place_edits.luau: Stage 10's emitters, hidden Bottom-face Textures, the
-- unauthorized place Sounds).
--
-- The list of sources is not written by hand: it is every file of src/ that differs from
-- output/FablePerf_20260922/backup_src/ (src as the places carried it before this pass), plus
-- every file that is new since. Each changed source is guarded by its backup copy, so a place
-- edited in Studio meanwhile stops the build instead of being lost.
--
--   lune run audit/build_fable_perf.luau          build
--   lune run audit/build_fable_perf.luau list     only print what it would put in
local fs = require("@lune/fs")
local process = require("@lune/process")
local Lib = require("./fable_build_lib")
local Edits = require("./perf_place_edits")

-- Later runs guard against what the first run put in the places: backup_src_v2, written by
-- scratch/perf_snapshot_v2.luau from the places after that run.
local BACKUP = if fs.isDir("output/FablePerf_20260922/backup_src_v2")
	then "output/FablePerf_20260922/backup_src_v2/"
	else "output/FablePerf_20260922/backup_src/"

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

Lib.run({ output = "output/FablePerf_20260922", sources = sources, edit = Edits.edit, verify = Edits.verify })
