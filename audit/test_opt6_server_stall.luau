-- audit/test_opt6_server_stall.luau
-- Worlds 2 and 3 ran "stuck": characters froze and jumped, ping rose (2026-09-21 report). It was
-- not physics. Two shared server scripts searched the whole Workspace over and over, and only
-- where stage zones are missing, which is why World 1 was smooth:
--   * Economy/SpeedProductPurchases: its safe-zone tracker asks for stages 1..11 for every living
--     player about 7 times a second, and a stage with no zone was never remembered as missing:
--     each call paid a recursive FindFirstChild and, in World 2, a whole-Workspace scan. World 2
--     has no SafeZone10.2 / SafeZone11.2, World 3 has no SafeZoneN at all.
--   * Gameplay/StageDecor: gated for new World 1 and World 2 but not for World 3, where it found
--     no zone, built nothing and rescanned the Workspace ten times every 0.25 s, forever.
--
--   lune run audit/test_opt6_server_stall.luau            the sources
--   lune run audit/test_opt6_server_stall.luau places     ...and that the three places carry them
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local rb = require("@lune/roblox")
local PlaceFiles = require("./place_files")

local SPP = "src/common/ServerScriptService/Economy/SpeedProductPurchases.server.luau"
local DECOR = "src/common/ServerScriptService/Gameplay/StageDecor.server.luau"
local function read(path) return (fs.readFile(path):gsub("\r\n", "\n")) end
local function pass(text) print("PASS " .. text) end

----------------------------------------------------------------------
-- 1. The safe-zone lookup: a missing stage is searched once, then remembered
----------------------------------------------------------------------
local function lookup(world)
	local source = read(SPP)
	local a = assert(source:find("local function getObjectBounds(object)", 1, true), "getObjectBounds moved")
	local b = assert(source:find("stageFromSafeZoneName = function(name)", a, true), "stageFromSafeZoneName moved")
	local state = { finds = 0, scans = 0, clock = 0 }
	local function part(name, x)
		local p = { Name = name, Parent = true, CFrame = rb.CFrame.new(x, 0, 0), Size = rb.Vector3.new(40, 10, 40) }
		function p:IsA(class) return class == "BasePart" end
		return p
	end
	local descendants = {}
	for i = 1, 2000 do descendants[i] = part("Filler" .. i, -50000) end
	local references = {}
	if world == 2 then
		for n = 1, 9 do
			references[n] = part("safezone" .. n .. ".2", n * 1000)
			table.insert(descendants, references[n])
		end
	end
	local Workspace = {}
	function Workspace:FindFirstChild() state.finds += 1 return nil end
	function Workspace:GetDescendants() state.scans += 1 return descendants end
	local env = {
		IS_NEW_WORLD1 = false, IS_WORLD2 = world == 2, NEW_WORLD1_MAP_ROOT = nil, Workspace = Workspace, STAGE_COUNT = 11,
		safeZoneReferences = references, safeZoneBoundsCache = {}, safeZoneMissingUntil = {}, SAFE_ZONE_MISSING_RETRY_SECONDS = 60,
		safeZoneName = function(stage) return "SafeZone" .. stage .. (world == 2 and ".2" or "") end,
		isSafeZoneObject = function(object) return object ~= nil end,
		stageFromSafeZoneName = function(name)
			return tonumber(string.match(string.lower(name), world == 2 and "^safezone(%d+)%.2$" or "^safezone(%d+)$"))
		end,
		os = { clock = function() return state.clock end }, math = math, ipairs = ipairs, pcall = pcall, string = string, tonumber = tonumber,
	}
	local find = luau.load(source:sub(a, b - 1) .. "\nreturn findSafeZoneStageAtPosition", { environment = env })()
	return find, state, references, part
end

do
	-- The constants the slice above is handed must be the script's own.
	local source = read(SPP)
	assert(source:find("local safeZoneMissingUntil = {}", 1, true) and source:find("local SAFE_ZONE_MISSING_RETRY_SECONDS = 60", 1, true),
		"SpeedProductPurchases must remember the stages that have no zone")

	for _, case in { { world = 2, missing = 2 }, { world = 3, missing = 11 } } do
		local find, state, references, part = lookup(case.world)
		-- 60 players for one second (the tracker runs at 6.67 Hz).
		for _ = 1, 400 do find(rb.Vector3.new(123456, 0, 0)) end
		assert(state.finds <= case.missing and state.scans <= case.missing,
			("World %d: 400 lookups made %d recursive finds and %d whole-Workspace scans; a missing stage is searched once (%d are missing)")
				:format(case.world, state.finds, state.scans, case.missing))
		local searched = state.finds
		if case.world == 2 then
			assert(find(rb.Vector3.new(3000, 2, 5)) == 3, "World 2: a player inside safezone3.2 is still placed in it")
			assert(find(rb.Vector3.new(3500, 2, 5)) == nil, "World 2: and outside every zone in none")
		end
		-- A zone that appears later (the script's DescendantAdded sets the reference) counts at once,
		-- inside the retry window.
		references[10] = part("SafeZone10" .. (case.world == 2 and ".2" or ""), 10000)
		assert(find(rb.Vector3.new(10000, 2, 0)) == 10, "a zone registered later must be used at once")
		references[10] = nil
		assert(state.finds == searched, "a registered zone costs no search")
		-- After the retry window a missing stage is looked for again: once.
		state.clock = 61
		state.finds, state.scans = 0, 0
		for _ = 1, 400 do find(rb.Vector3.new(123456, 0, 0)) end
		assert(state.finds <= case.missing and state.scans <= case.missing, "the slow retry is one search per missing stage, not one per call")
		assert(state.finds >= 1, "a missing stage is retried after SAFE_ZONE_MISSING_RETRY_SECONDS")
	end
	pass("safe-zone lookup: 400 lookups cost <= 2 searches in World 2 and <= 11 in World 3 (were 800 + 800 scans, and 4400); zones still resolve; late zones count at once")
end

----------------------------------------------------------------------
-- 2. StageDecor stops in World 3 before it looks for anything
----------------------------------------------------------------------
do
	local source = read(DECOR)
	local gate = assert(source:find("if Config.IsWorld3Place == true then", 1, true), "StageDecor must stop in World 3")
	local firstWork = assert(source:find("local STAGE_COUNT", 1, true))
	assert(gate < firstWork, "the World 3 gate comes before any of the decorator's work")
	local body = source:sub(gate, firstWork)
	assert(body:find("\n\treturn\nend", 1, true), "the World 3 gate returns")
	pass("StageDecor: returns at once in World 3 (it rescanned 36,000 instances 40 times a second, forever)")
end

----------------------------------------------------------------------
-- 3. The maps: which stages have a zone (what made Worlds 2 and 3 different)
----------------------------------------------------------------------
do
	for _, place in PlaceFiles.Places do
		if place.world ~= 1 then
			local dm = rb.deserializePlace(fs.readFile(place.file))
			local found = {}
			for _, inst in dm:GetService("Workspace"):GetDescendants() do
				local stage = tonumber(string.match(string.lower(inst.Name), place.world == 2 and "^safezone(%d+)%.2$" or "^safezone(%d+)$"))
				if stage then found[stage] = true end
			end
			local missing = 0
			for stage = 1, 11 do
				if not found[stage] then missing += 1 end
			end
			assert(missing > 0, place.key .. " has every stage zone now: the negative cache is idle there, fine, but update this test's story")
			print(("     %s: %d of 11 stage zones missing in the map"):format(place.key, missing))
		end
	end
	pass("the World 2 and World 3 maps do miss stage zones, so the lookup above is what their servers run")
end

----------------------------------------------------------------------
-- 4. places: the three places carry these sources
----------------------------------------------------------------------
if process.args[1] == "places" then
	local WANTED = {
		{ SPP, { "ServerScriptService", "Economy", "SpeedProductPurchases" } },
		{ DECOR, { "ServerScriptService", "Gameplay", "StageDecor" } },
	}
	for _, place in PlaceFiles.Places do
		local dm = rb.deserializePlace(fs.readFile(place.file))
		for _, item in WANTED do
			local node = dm
			for _, name in item[2] do
				node = assert(node:FindFirstChild(name), place.key .. ": " .. table.concat(item[2], ".") .. " is missing")
			end
			assert(node.Source == fs.readFile(item[1]), place.key .. ": outdated " .. table.concat(item[2], "."))
		end
	end
	pass("places: SpeedProductPurchases and StageDecor are current in the three places")
end
print("ALL PASSED")
