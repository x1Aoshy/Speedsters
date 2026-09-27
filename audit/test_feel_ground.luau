-- audit/test_feel_ground.luau  (2026-09-22)
-- Treadmills flush on their floors: audit/treadmill_ground_edits.luau run on in-memory copies
-- of the three REAL root places (the source files are never written):
--   1. It finds the treadmills TreadmillTraining registers (the same walk, the place's own
--      Config loaded from src), and the treadmill script still registers them that way.
--   2. Before, measured on the treadmill BODY (the Model holding 'Treadmil', not the crystals
--      and bolts beside it): exactly World 3's Lobby Admin.Model 1.160, Basic 0.151,
--      Diamond.Model 0.969, Needoh.Model 1.332, Hacker.Model 1.565 float; out of scope (the
--      owner: "only happens in World 3") World 1 neworld1.Needoh.Model 0.371 and World 2
--      Admin.Diamond.Model 0.234 are pinned too; everything else is flush or sunk. The
--      decorated containers of World 3's Diamond/Needoh/Hacker read flush through their
--      crystals, which is why the body is what gets measured.
--   3. In World 3 the edit moves exactly those five bodies straight down by their gaps (every
--      part, rotation kept, WorldPivot too); every other BasePart of the place (their crystals
--      and bolts included) keeps its CFrame; afterwards every gap is within 0.05, verify
--      passes, also after a serialize round trip, and World 3's Basic still stands on the
--      treadmill floor as test_world3_polish demands. In World 1 and World 2 it moves nothing,
--      returns false and notes the one body it leaves.
--   4. A second run is a no-op (returns false, nothing moves; no notes in World 3).
--   5. No runtime script lifts the lobby treadmills in World 3.
--   places: the built root places carry the edit (verify passes, edit returns false).
--
--   lune run audit/test_feel_ground.luau           the edit on copies of the places
--   lune run audit/test_feel_ground.luau places    the built places carry it
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local rb = require("@lune/roblox")
local PlaceFiles = require("./place_files")
local Ground = require("./treadmill_ground_edits")

local function pass(text)
	print("PASS " .. text)
end
local function read(path)
	return (string.gsub(fs.readFile(path), "\r\n", "\n"))
end

if process.args[1] == "places" then
	for _, place in PlaceFiles.Places do
		local dm = rb.deserializePlace(fs.readFile(place.file))
		Ground.verify(place.key, dm)
		local notes = {}
		assert(Ground.edit(place.key, dm, notes) == false, place.key .. ": the built place still has a floating treadmill: " .. table.concat(notes, "; "))
		pass(place.key .. " (" .. place.file .. ") carries the treadmill ground edit")
	end
	return
end

-- 0. Compiles ---------------------------------------------------------------------------------
assert(#luau.compile(fs.readFile("audit/treadmill_ground_edits.luau")) > 0, "treadmill_ground_edits compiles")
pass("audit/treadmill_ground_edits.luau compiles")

-- 1. The registration walk matches TreadmillTraining ------------------------------------------
do
	local source = read("src/common/ServerScriptService/Progression/TreadmillTraining.server.luau")
	for _, marker in {
		'local nestedBelt = container:FindFirstChild("Treadmil", true)',
		"local namedGain = Config.TreadmillBaseGains[descendant.Name]",
		'if descendant:IsA("Model") and descendant.Name == "Admin" then',
		'if descendant:IsA("Model") and descendant.Name == "Model" and descendant.Parent and descendant.Parent.Name == "Admin" and descendant:FindFirstChild("Treadmil", true) then',
		'local sourceName = descendant:GetAttribute("TreadmillTrainingSourceName")',
		"and NEW_WORLD1_TREADMILL_PROFILES[object.Name] ~= nil",
	} do
		assert(string.find(source, marker, 1, true), "TreadmillTraining no longer registers this way: " .. marker)
	end
	pass("TreadmillTraining still registers treadmills the way the edit finds them")
end

local EXPECTED_CONTAINERS = {
	World1 = { "Workspace.neworld1.Admin", "Workspace.neworld1.Basic", "Workspace.neworld1.Candy", "Workspace.neworld1.Diamond",
		"Workspace.neworld1.Golden", "Workspace.neworld1.Hacker", "Workspace.neworld1.Needoh" },
	World2 = { "Workspace.Admin.Candy", "Workspace.Admin.Diamond", "Workspace.Admin.Golden", "Workspace.Admin.Hacker",
		"Workspace.Admin.Model", "Workspace.Admin.Needoh" },
	World3 = { "Workspace.Lobby.Admin.Model", "Workspace.Lobby.Basic", "Workspace.Lobby.Diamond", "Workspace.Lobby.Hacker",
		"Workspace.Lobby.Needoh" },
}
-- The floating bodies, with their measured gaps (studs), and the floor they float over.
local EXPECTED_FLOATING = {
	World1 = { ["Workspace.neworld1.Needoh.Model"] = 0.371 },
	World2 = { ["Workspace.Admin.Diamond.Model"] = 0.234 },
	World3 = {
		["Workspace.Lobby.Admin.Model"] = 1.160,
		["Workspace.Lobby.Basic"] = 0.151,
		["Workspace.Lobby.Diamond.Model"] = 0.969,
		["Workspace.Lobby.Needoh.Model"] = 1.332,
		["Workspace.Lobby.Hacker.Model"] = 1.565,
	},
}
local FLOORS = {
	World1 = "Workspace.neworld1.Treadmillarea.floor for spawn.Part",
	World2 = "Workspace.Baseplate",
	World3 = "Workspace.Lobby.Treadmillarea.floor for spawn.Part",
}
assert(Ground.WORLDS.World3 == true and not Ground.WORLDS.World1 and not Ground.WORLDS.World2,
	"the edit is scoped to World 3 (the owner: only World 3)")

local function cframeEqual(a, b): boolean
	local ax = { a:GetComponents() }
	local bx = { b:GetComponents() }
	for index = 1, 12 do
		if ax[index] ~= bx[index] then
			return false
		end
	end
	return true
end
local function near(a, b, tolerance): boolean
	return math.abs(a - b) <= tolerance
end

-- The edit is measured on the places as they were before this pass: once audit/build_fable_feel.luau
-- has run, the root places carry it already ("places" mode above checks that), and the build keeps
-- the originals in output/FableFeel_20260922/backup.
local PRE_PASS = "output/FableFeel_20260922/backup/"
for _, place in PlaceFiles.Places do
	local key = place.key
	local FLOOR = FLOORS[key]
	local inScope = Ground.WORLDS[key] == true
	local original = if fs.isFile(PRE_PASS .. place.file) then PRE_PASS .. place.file else place.file
	local dm = rb.deserializePlace(fs.readFile(original))
	local workspace = dm:GetService("Workspace")

	-- 1. The containers ------------------------------------------------------------------------
	local names = {}
	for _, container in Ground.containers(dm) do
		table.insert(names, (container:GetFullName()))
	end
	table.sort(names)
	assert(table.concat(names, "|") == table.concat(EXPECTED_CONTAINERS[key], "|"),
		key .. ": registered treadmills are " .. table.concat(names, ", "))

	-- 2. Before --------------------------------------------------------------------------------
	local floating, byName = {}, {}
	for _, entry in Ground.measure(key, dm) do
		byName[entry.name] = entry
		assert(entry.solid > 0, key .. ": " .. entry.name .. " has no visible part")
		assert(entry.floor or entry.sunkInto, key .. ": " .. entry.name .. " has no floor under it")
		if Ground.isFloating(entry) then
			floating[entry.name] = entry
		end
	end
	local wanted = EXPECTED_FLOATING[key]
	for name, gap in wanted do
		local entry = floating[name]
		assert(entry, key .. ": " .. name .. " should float")
		assert(near(entry.gap, gap, 0.01), ("%s: %s floats %.4f, expected %.3f"):format(key, name, entry.gap, gap))
		assert(entry.floorName == FLOOR, key .. ": " .. name .. " floats above " .. entry.floorName)
	end
	for name, entry in floating do
		assert(wanted[name], ("%s: %s floats %.4f and was not expected to"):format(key, name, entry.gap))
	end
	local count = 0
	for _ in wanted do
		count += 1
	end
	pass(("%s before: %d floating (%s)"):format(key, count, (function()
		local list = {}
		for name, entry in floating do
			table.insert(list, ("%s %.3f"):format(name, entry.gap))
		end
		table.sort(list)
		return if #list > 0 then table.concat(list, ", ") else "all flush or sunk"
	end)()))

	-- The body, not the decorated container: in World 3 the containers of Diamond, Needoh and
	-- Hacker reach the floor through their crystals while the treadmill hovers.
	if key == "World3" then
		for _, name in { "Workspace.Lobby.Diamond.Model", "Workspace.Lobby.Needoh.Model", "Workspace.Lobby.Hacker.Model" } do
			local entry = byName[name]
			assert(entry.body ~= entry.container and entry.body:FindFirstChild("Treadmil") and entry.body.Parent == entry.container,
				name .. " is the belt holder inside its container")
			local low = math.huge
			for _, part in entry.container:GetDescendants() do
				if part:IsA("BasePart") and part.Transparency < 1 then
					local half = part.Size / 2
					for _, sx in { -1, 1 } do
						for _, sy in { -1, 1 } do
							for _, sz in { -1, 1 } do
								low = math.min(low, (part.CFrame * rb.CFrame.new(sx * half.X, sy * half.Y, sz * half.Z)).Position.Y)
							end
						end
					end
				end
			end
			assert(low <= entry.floorTop + Ground.FLOAT_TOLERANCE,
				("%s: the whole container (crystals) reaches the floor (%.3f vs %.3f)"):format(name, low, entry.floorTop))
		end
		pass("World 3: Diamond/Needoh/Hacker crystals reach the floor while their treadmill bodies hover, so bodies are measured")
	end

	-- 3. The edit ------------------------------------------------------------------------------
	local parts, before, owner = {}, {}, {}
	for _, descendant in workspace:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
			table.insert(before, descendant.CFrame)
		end
	end
	local pivots = {}
	for name, entry in (if inScope then floating else {}) do
		for _, descendant in entry.body:GetDescendants() do
			if descendant:IsA("BasePart") then
				owner[descendant] = entry
			elseif descendant:IsA("Model") then
				pivots[descendant] = { entry = entry, pivot = descendant.WorldPivotData }
			end
		end
		if entry.body:IsA("BasePart") then
			owner[entry.body] = entry
		else
			pivots[entry.body] = { entry = entry, pivot = entry.body.WorldPivotData }
		end
	end
	local notes = {}
	assert(Ground.edit(key, dm, notes) == (inScope and count > 0), key .. ": edit returns whether it moved something")
	assert(#notes == count, key .. ": one note per floating treadmill (moved, or left out of scope): " .. table.concat(notes, "; "))
	for _, text in notes do
		assert(string.find(text, if inScope then " down " else "only World 3 is edited", 1, true), key .. ": note " .. text)
	end
	local moved, kept = 0, 0
	for index, part in parts do
		local entry = owner[part]
		if entry then
			local expected = before[index] + rb.Vector3.new(0, -entry.gap, 0)
			local now = part.CFrame
			assert((now.Position - expected.Position).Magnitude < 1e-3, key .. ": " .. part:GetFullName() .. " moved wrong")
			assert(now.LookVector:Dot(before[index].LookVector) > 0.99999 and now.UpVector:Dot(before[index].UpVector) > 0.99999,
				key .. ": " .. part:GetFullName() .. " turned")
			moved += 1
		else
			assert(cframeEqual(part.CFrame, before[index]), key .. ": " .. part:GetFullName() .. " moved but is not a floating treadmill")
			kept += 1
		end
	end
	for model, item in pivots do
		if typeof(item.pivot) == "CFrame" then
			local expected = item.pivot.Position - rb.Vector3.new(0, item.entry.gap, 0)
			assert((model.WorldPivotData.Position - expected).Magnitude < 1e-3, key .. ": " .. model:GetFullName() .. " pivot not moved with it")
		end
	end
	for _, entry in Ground.measure(key, dm) do
		if not inScope then
			assert(entry.gap == byName[entry.name].gap, key .. ": " .. entry.name .. " changed outside World 3")
			continue
		end
		assert(not entry.gap or entry.gap <= Ground.FLOAT_TOLERANCE,
			("%s: %s still %.4f above its floor"):format(key, entry.name, entry.gap or 0))
		if wanted[entry.name] then
			assert(math.abs(entry.gap) <= Ground.FLOAT_TOLERANCE, ("%s: %s now %.4f off its floor"):format(key, entry.name, entry.gap))
			assert(entry.floorName == FLOOR, key .. ": " .. entry.name .. " landed on " .. tostring(entry.floorName))
		elseif byName[entry.name].gap then
			assert(entry.gap == byName[entry.name].gap, key .. ": " .. entry.name .. " was flush or sunk and changed")
		end
	end
	Ground.verify(key, dm)
	assert(moved == 0 or inScope, key .. ": moved parts outside World 3")
	pass(("%s after: %d parts moved straight down, %d other BaseParts untouched, %s"):format(
		key, moved, kept, if inScope then ("every gap within %.2f"):format(Ground.FLOAT_TOLERANCE) else "out of scope, nothing moved"))

	if key == "World3" then
		-- test_world3_polish: 'Basic stands on the treadmill floor (bottom, floor)'.
		local lobby = workspace.Lobby
		local floor = lobby.Treadmillarea["floor for spawn"]:FindFirstChildWhichIsA("BasePart")
		local basic = byName["Workspace.Lobby.Basic"]
		local floorTop = -math.huge
		local low = math.huge
		for _, part in { floor } do
			local half = part.Size / 2
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						floorTop = math.max(floorTop, (part.CFrame * rb.CFrame.new(sx * half.X, sy * half.Y, sz * half.Z)).Position.Y)
					end
				end
			end
		end
		for _, part in basic.container:GetDescendants() do
			if part:IsA("BasePart") then
				local half = part.Size / 2
				for _, sx in { -1, 1 } do
					for _, sy in { -1, 1 } do
						for _, sz in { -1, 1 } do
							low = math.min(low, (part.CFrame * rb.CFrame.new(sx * half.X, sy * half.Y, sz * half.Z)).Position.Y)
						end
					end
				end
			end
		end
		assert(math.abs(low - floorTop) < 0.05, ("Basic stands on the treadmill floor (bottom %.3f, floor %.3f)"):format(low, floorTop))
		pass(("World 3's Basic stands on the treadmill floor (bottom %.3f, floor %.3f)"):format(low, floorTop))
	end

	-- 4. Second run ----------------------------------------------------------------------------
	local after = {}
	for index, part in parts do
		after[index] = part.CFrame
	end
	local again = {}
	assert(Ground.edit(key, dm, again) == false and #again == (if inScope then 0 else count), key .. ": a second run changed something: " .. table.concat(again, "; "))
	for index, part in parts do
		assert(cframeEqual(part.CFrame, after[index]), key .. ": the second run moved " .. part:GetFullName())
	end
	-- As the build does: verify on a serialize round trip.
	if inScope and count > 0 then
		local check = rb.deserializePlace(rb.serializePlace(dm))
		Ground.verify(key, check)
		assert(Ground.edit(key, check, {}) == false, key .. ": the round-tripped place floats again")
	end
	pass(key .. ": a second run is a no-op" .. (if inScope and count > 0 then "; verify passes after a serialize round trip" else ""))
end

-- 5. No runtime script lifts World 3's lobby treadmills -------------------------------------
do
	local decor = read("src/common/ServerScriptService/Gameplay/StageDecor.server.luau")
	local stop = assert(string.find(decor, "if Config.IsWorld3Place == true then", 1, true), "StageDecor's World 3 exit moved")
	local firstMove = assert(string.find(decor, "PivotTo", 1, true))
	assert(stop < firstMove and string.find(decor, "if Config.IsWorld3Place == true then\n\tprint(\"[StageDecor] World 1 decorator disabled in World 3; World3ManualStagePads owns the desert stages.\")\n\treturn", 1, true),
		"StageDecor returns in World 3 before it can move any treadmill")
	local fix = read("src/common/ServerScriptService/Progression/TreadmillCollisionFix.server.luau")
	assert(not string.find(fix, "PivotTo", 1, true) and not string.find(fix, "TranslateBy", 1, true),
		"TreadmillCollisionFix never moves a treadmill")
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
	for _, path in walk("src/worlds/World3", {}) do
		local source = read(path)
		if string.find(source, "Lobby", 1, true) and (string.find(source, "Needoh", 1, true) or string.find(source, "Diamond", 1, true)) then
			-- Only the overhead labels name the lobby treadmills; they move nothing but their sign.
			assert(path:match("World3TreadmillOverheadLabels%.server%.luau$"), path .. " names the lobby treadmills")
			assert(not string.find(source, "PivotTo", 1, true) and not string.find(source, "TranslateBy", 1, true), path .. " moves a treadmill")
		end
	end
	pass("no runtime script repositions World 3's lobby treadmills")
end

print("RESULT: treadmill ground edit OK")
