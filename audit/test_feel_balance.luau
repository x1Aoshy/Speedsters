-- test_feel_balance.luau
-- The 2026-09-22 game-feel balance pass (audit/build_fable_feel.luau), on the real sources:
--   1. The paid Valentine / Needoh treadmill (pass 1941090466) gives x40 and says "x40 Speed"
--      in every world, above every free treadmill of that world (World 2's Diamond is x30);
--      TreadmillTraining reads the gain from Config.TreadmillBaseGains.
--   2. Every sign that shows it reads x40: World 1's new-map signs and World 3's signs come
--      from Config, World 2's sign reads Config's DisplayText, the admin panel says x40.
--   3. World 3 walks at x0.25 (was 1/9): its own Config number, still under World 2's 0.5,
--      and CharacterStatsAdapter's offline fallback agrees.
--   lune run audit/test_feel_balance.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local rb = require("@lune/roblox")

local CONFIG_PATH = "src/common/ReplicatedStorage/Shared/Config.luau"
local NEEDOH_PASS = 1941090466

local function near(a, b)
	return type(a) == "number" and math.abs(a - b) < 1e-9
end

local function loadConfig(world, source)
	local stub = {
		GetAttribute = function(_, name)
			return name == "PlaceWorldNumber" and world or nil
		end,
		FindFirstChild = function(_, name)
			return name == "neworld1" and world == 1 and {} or nil
		end,
	}
	return luau.load(source or fs.readFile(CONFIG_PATH), {
		environment = {
			game = { PlaceId = 0, GetService = function() return stub end },
			workspace = stub,
			Vector3 = rb.Vector3, Color3 = rb.Color3, CFrame = rb.CFrame, Enum = rb.Enum,
		},
	})()
end

local configs = { loadConfig(1), loadConfig(2), loadConfig(3) }
local profilesOf = {
	function(c) return c.NewWorld1TreadmillProfiles end,
	function(c) return c.World2TreadmillProfiles end,
	function(c) return c.World3TreadmillProfiles end,
}

-- 1. Needoh x40 above every free treadmill ------------------------------------------------------
do
	assert(configs[1].IsNewWorld1Map == true and configs[2].IsWorld2Place == true and configs[3].IsWorld3Place == true, "Each Config knows its world")
	for world, config in configs do
		local profiles = profilesOf[world](config)
		local needoh = assert(profiles.Needoh, "World " .. world .. " has a Needoh treadmill")
		assert(needoh.BaseGain == 40, "World " .. world .. ": Needoh gives x40 (" .. tostring(needoh.BaseGain) .. ")")
		assert(needoh.DisplayText == "x40 Speed", "World " .. world .. ": Needoh reads 'x40 Speed' (" .. tostring(needoh.DisplayText) .. ")")
		assert(needoh.GamePassId == NEEDOH_PASS, "World " .. world .. ": Needoh keeps its game pass")
		assert(config.TreadmillBaseGains.Needoh == 40, "World " .. world .. ": TreadmillTraining's gain table pays x40")
		local freeCount = 0
		for name, profile in profiles do
			if profile.GamePassId == nil and profile.SpawnedAtRuntime ~= true then
				freeCount += 1
				assert(needoh.BaseGain > profile.BaseGain,
					"World " .. world .. ": the paid Needoh (x" .. needoh.BaseGain .. ") beats the free " .. name .. " (x" .. profile.BaseGain .. ")")
			end
		end
		assert(freeCount >= 2, "World " .. world .. " has free treadmills to compare with")
		-- Admin and Hacker stay above it: the price ladder still reads cheap -> expensive.
		assert(profiles.Admin.BaseGain > needoh.BaseGain and profiles.Hacker.BaseGain > profiles.Admin.BaseGain, "World " .. world .. ": Needoh < Admin < Hacker")
	end
	assert(configs[1].ValentineTreadmillPassId == NEEDOH_PASS, "The shop's Valentine card is the same pass")
	print("PASS Needoh: x40 'x40 Speed' in every world, above every free treadmill (World 2 Diamond x30), under Admin and Hacker")
end

-- 2. Every Needoh sign reads x40 -----------------------------------------------------------------
local function sliceBetween(source, startMarker, endMarker, path)
	local a = assert(string.find(source, startMarker, 1, true), path .. ": marker '" .. startMarker .. "' not found")
	local b = assert(string.find(source, endMarker, a + #startMarker, true), path .. ": marker '" .. endMarker .. "' not found")
	return string.sub(source, a, b - 1)
end
do
	-- World 2's own sign script: its PROFILES block, run against Config (and a changed Config).
	local path = "src/worlds/World2/ServerScriptService/Progression/World2TreadmillOverheadLabels.server.luau"
	local source = fs.readFile(path)
	local block = "local REBIRTH_ICON, ROBUX_ICON = 'r', 'b'\n" .. sliceBetween(source, "local PROFILES = {", "\nlocal ANCHOR_OVERRIDES", path) .. "\nreturn PROFILES"
	local function signs(config)
		return luau.load(block, { environment = { Config = config, Color3 = rb.Color3, tostring = tostring } })()
	end
	assert(signs(configs[2]).Needoh.StepsText == "x40 Speed", "World 2's Needoh sign reads x40")
	assert(signs({ World2TreadmillProfiles = { Needoh = { DisplayText = "x77 Speed" } } }).Needoh.StepsText == "x77 Speed", "World 2's Needoh sign follows Config")
	assert(signs({}).Needoh.StepsText == "x40 Speed", "...and falls back to x40 without it")
	assert(signs(configs[2]).Needoh.GamePassId == NEEDOH_PASS, "World 2's sign keeps the pass")
	assert(not string.find(source, "x25", 1, true), path .. " no longer says x25")

	-- World 1's (and World 2's copy of the) sign script: the new map's signs come from Config.
	for _, world in { "World1", "World2" } do
		local labelsPath = "src/worlds/" .. world .. "/ServerScriptService/Progression/TreadmillOverheadLabels.server.luau"
		local labels = fs.readFile(labelsPath)
		local loop = "local PROFILES, IS_NEW_WORLD1 = {}, true\nlocal REBIRTH_ICON, ROBUX_ICON = 'r', 'b'\n"
			.. sliceBetween(labels, "if IS_NEW_WORLD1 then", "\nlocal boundTreadmills", labelsPath) .. "\nreturn PROFILES"
		local built = luau.load(loop, { environment = { NEW_WORLD1_TREADMILL_PROFILES = configs[1].NewWorld1TreadmillProfiles, Color3 = rb.Color3, math = math, tostring = tostring, tonumber = tonumber, pairs = pairs } })()
		assert(built.Needoh and built.Needoh.StepsText == "x40 Speed" and built.Needoh.GamePassId == NEEDOH_PASS, world .. "'s new-map Needoh sign reads x40")
		assert(not string.find(labels, "Needoh x25", 1, true), labelsPath .. ": the ready line no longer says Needoh x25")
		assert(string.find(labels, "(NEW_WORLD1_TREADMILL_PROFILES.Needoh or {}).BaseGain", 1, true), labelsPath .. ": the ready line reads Needoh's gain from Config")
	end

	-- World 3's signs: every title is its Config profile's DisplayText.
	local world3Path = "src/worlds/World3/ServerScriptService/Progression/World3TreadmillOverheadLabels.server.luau"
	local world3 = fs.readFile(world3Path)
	assert(string.find(world3, "Title = tostring(profile.DisplayText", 1, true) and string.find(world3, "Config.World3TreadmillProfiles", 1, true), "World 3's signs read Config.World3TreadmillProfiles")
	assert(configs[3].World3TreadmillProfiles.Needoh.DisplayText == "x40 Speed", "...whose Needoh reads x40")

	local panel = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/Admin/AdminAbusePanelController.client.luau")
	assert(string.find(panel, '{ "Needoh", "Needoh x40" },', 1, true) and not string.find(panel, "Needoh x25", 1, true), "The admin panel's Needoh button says x40")
	print("PASS Needoh signs: World 1 and World 3 from Config, World 2 from Config's DisplayText (x40), admin panel x40")
end

-- 3. World 3 walks at x0.25 ---------------------------------------------------------------------
do
	local configSource = fs.readFile(CONFIG_PATH)
	assert(string.find(configSource, "\nConfig.World3WalkSpeedMultiplier = 0.25\n", 1, true), "World 3's multiplier is an explicit 0.25")
	for _, config in configs do
		assert(near(config.World3WalkSpeedMultiplier, 0.25), "Config.World3WalkSpeedMultiplier is 0.25")
		assert(config.World3WalkSpeedMultiplier < config.World2WalkSpeedMultiplier, "World 3 still walks slower than World 2")
		assert(config.World3WalkSpeedMultiplier > 1 / 9, "...and faster than the old 1/9")
	end
	assert(near(configs[1].WorldWalkSpeedMultiplier, 1) and near(configs[2].WorldWalkSpeedMultiplier, 0.5) and near(configs[3].WorldWalkSpeedMultiplier, 0.25),
		"World 1 x1, World 2 x0.5, World 3 x0.25")

	-- CharacterStatsAdapter: with Config (World 3 place) and without it (its fallback constant).
	local adapterSource = fs.readFile("src/common/ServerScriptService/Services/Stats/CharacterStatsAdapter.luau")
	assert(string.find(adapterSource, "local WORLD3_WALK_SPEED_MULTIPLIER = 0.25\n", 1, true), "The adapter's fallback is 0.25")
	local function adapterFor(config)
		local env = setmetatable({
			typeof = function() return "Instance" end,
			script = { Parent = { StatsService = {} } },
			require = function(target) return target end,
			game = { GetService = function() return { Shared = { Config = config } } end },
		}, { __index = _G })
		return luau.load(adapterSource, { environment = env })()
	end
	local function playerIn(world)
		return { GetAttribute = function(_, name) return if name == "CurrentWorld" then world else nil end }
	end
	assert(near(adapterFor(configs[3]).GetMovementFactors(playerIn(nil)).worldMultiplier, 0.25), "World 3's place walks at x0.25")
	assert(near(adapterFor({}).GetMovementFactors(playerIn(3)).worldMultiplier, 0.25), "Without Config, a World 3 player still walks at x0.25")
	assert(near(adapterFor({}).GetMovementFactors(playerIn(2)).worldMultiplier, 0.5), "...and a World 2 player at x0.5")

	-- The real StatsService: World 3's entry walk (Speed at Level 200) is 2.25 times the old one,
	-- and a rebirth still walks the floor (8), not 8 x 0.25.
	local StatsService = require("../src/common/ServerScriptService/Services/Stats/StatsService")
	local rules = {
		realWalkSpeedMin = configs[3].RealWalkSpeedMin, referenceDisplayedSpeed = configs[3].RealWalkSpeedReferenceDisplayedSpeed,
		walkSpeedAtReference = configs[3].RealWalkSpeedAtReference, curve = configs[3].RealWalkSpeedCurve,
		useSmoothRealSpeedFormula = true, baseWalkSpeed = 8, speedToWalkSpeedMultiplier = 0.08, useWalkSpeedCap = false, maxWalkSpeed = 300,
		startingSpeed = 1, maxStoredSpeed = 1e50,
	}
	local function walk(speed, scale)
		local result = StatsService.CalculateWalkSpeed(speed, rules, { worldMultiplier = scale, selectorMultiplier = 1, boostMultiplier = 1, permanentMultiplier = 1 })
		assert(result.ok, "CalculateWalkSpeed failed")
		return result.value
	end
	local entrySpeed = 1.525e15 -- the Speed Level 200 takes (LevelProgress's requirements, levels 1-199)
	local old, new = walk(entrySpeed, 1 / 9), walk(entrySpeed, 0.25)
	assert(new > 70 and new < 74 and old > 31 and old < 33, ("World 3's entry walk %.1f (was %.1f)"):format(new, old))
	assert(near(new / old, 2.25), "2.25 times the old desert walk")
	assert(new < walk(entrySpeed, 0.5), "...still under World 2's at the same Speed")
	assert(near(walk(1, 0.25), 8), "A rebirth in World 3 walks the floor, 8")
	print(("PASS World 3 walk: x0.25 in Config and the adapter's fallback, under World 2's x0.5; entry walk %.1f studs/s (was %.1f)"):format(new, old))
end

print("ALL FEEL BALANCE CHECKS PASSED")
