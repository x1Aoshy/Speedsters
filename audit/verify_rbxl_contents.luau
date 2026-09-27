--!strict
-- audit/verify_rbxl_contents.luau
-- Opens the shipped .rbxl files and proves that what is inside them is exactly
-- what is in src/ - every tracked script, plus the modules added this pass.

local fs = require("@lune/fs")
local PlaceFiles = require("./place_files")
local serde = require("@lune/serde")
local roblox = require("@lune/roblox")

local manifest = serde.decode("json", fs.readFile("src/manifest.json"))

-- The root places only (audit/place_files.luau). build_core's copies ("World1 Speedtercorrect.rbxl",
-- "World2Old has to be synced ...rbxl", output/Update2_core) are gone or stale since builds
-- started injecting into the root places (2026-09-19).
local PLACES = {
	World1 = { PlaceFiles.World1 },
	World2 = { PlaceFiles.World2 },
	World3 = { PlaceFiles.World3 },
}

local ADDED_THIS_PASS = {
	"ReplicatedStorage/Shared/WinsMath",
	"ServerScriptService/Services/DoubleWinsPad",
	"ServerScriptService/Economy/Cosmetics/CosmeticOwnership",
}

local function segmentsOf(instance)
	local result = {}
	while instance.Parent do
		table.insert(result, 1, instance.Name)
		instance = instance.Parent
	end
	return table.concat(result, "/")
end

local function findByPath(place, legacyPath)
	local current: any = place
	for segment in string.gmatch(legacyPath, "[^/]+") do
		if not current then return nil end
		current = current:FindFirstChild(segment)
	end
	return current
end

-- Several authored paths have same-named siblings (two MeshParts under one Water
-- model, several Conveyor Scripts). build_core matches those by referent, so the
-- check here compares the multiset of sources found at each path instead of
-- walking by name, which would pick an arbitrary twin.
local function sourcesByPath(place)
	local byPath: any = {}
	for _, instance in ipairs(place:GetDescendants()) do
		if instance:IsA("LuaSourceContainer") then
			local path = segmentsOf(instance)
			byPath[path] = byPath[path] or {}
			table.insert(byPath[path], instance.Source)
		end
	end
	return byPath
end

local failures = 0
for world, files in pairs(PLACES) do
	for _, file in ipairs(files) do
		local place = roblox.deserializePlace(fs.readFile(file))
		local present = sourcesByPath(place)
		local expected: any = {}
		for _, row in ipairs(manifest.worlds[world].scripts) do
			expected[row.legacyPath] = expected[row.legacyPath] or {}
			table.insert(expected[row.legacyPath], fs.readFile(row.source))
		end

		local checked, problems = 0, 0
		for path, wanted in pairs(expected) do
			local found = present[path] or {}
			if #found ~= #wanted then
				problems += 1
				print(string.format("  COUNT    %s :: %s (place has %d, manifest has %d)", file, path, #found, #wanted))
			else
				local remaining = table.clone(found)
				for _, source in ipairs(wanted) do
					local index = table.find(remaining, source)
					if index then
						table.remove(remaining, index)
						checked += 1
					end
				end
				if #remaining > 0 then
					problems += 1
					print(string.format("  STALE    %s :: %s (%d source(s) do not match src)", file, path, #remaining))
				end
			end
		end

		for _, legacyPath in ipairs(ADDED_THIS_PASS) do
			local instance = findByPath(place, legacyPath)
			if not instance or not instance:IsA("ModuleScript") then
				problems += 1
				print(string.format("  MISSING  %s :: %s (module added this pass)", file, legacyPath))
			end
		end

		if problems > 0 then
			failures += 1
			print(string.format("FAIL %s: %d matched, %d problem(s)", file, checked, problems))
		else
			print(string.format("ok   %s: %d tracked scripts match src, all 3 new modules present", file, checked))
		end
	end
end

-- The Wins SKU change and the flight stamina change must be live inside the place,
-- not just in src.
for world, files in pairs(PLACES) do
	local place = roblox.deserializePlace(fs.readFile(files[1]))
	local config = findByPath(place, "ReplicatedStorage/Shared/Config")
	assert(config, world .. ": Config missing from the place")
	assert(string.find(config.Source, "RetiredPermanentWinsMultiplierProducts", 1, true),
		world .. ": the retired Wins products are not in the shipped Config")
	assert(string.find(config.Source, "AbilityFlightGlideDrainPercentPerSecond", 1, true),
		world .. ": the glide stamina drain is not in the shipped Config")
	assert(string.find(config.Source, "AbilityFlightMinimumStaminaPercent", 1, true),
		world .. ": the proportional lift-off threshold is not in the shipped Config")
	print("ok   " .. world .. ": shipped Config carries the Wins SKU and flight stamina changes")
end

if failures > 0 then
	error(string.format("%d place file(s) do not match src", failures))
end
print("ALL PLACE FILES MATCH src")
