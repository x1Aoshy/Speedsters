-- test_u4_integration.luau (Update 4, integrator Phase 1, 2026-09-25)
-- The merge of the workstreams (output/Update4/PLAN.md §5.G-§5.J). test_u4_contracts covers the
-- Phase 0 contracts (config, dispatcher, codec, reducers, funnels, menu lists); this covers what
-- Phase 1 wired on top:
--   1. Bootstrap: the race turns the normal sprint off, the 2x Stamina Regen pass (outside races,
--      only while the feature is on), titles drawn from TitleService.Visual with the Dev/Tester
--      fallback, a title redrawn on EquippedTitle, Update4Config loaded without a wait;
--   2. StatsService / PlayerStatsBridge: RetentionSpeedGainMultiplier multiplies Speed gains
--      (1..10 clamp, a bad value is x1), and is x1 while RaceActive;
--   3. Config: M50 / H10 keys, staff by Name or UserId only (a DisplayName is not a staff member);
--   4. Update4Config: the Race Gate points the placement test accepted;
--   5. the build (audit/build_update4.luau `list`, `list p0`) and the runner list every Update 4
--      test and module; fable_build_lib has dryRun / createFolders;
--   6. the workstream fixes the integrator applied (Daily icon art, RaceService Join refusal,
--      arena labels through FontFace).
-- Run: lune run audit/test_u4_integration.luau   (from the project root)
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local BOOTSTRAP = "src/common/ServerScriptService/Bootstrap.server.luau"
local STATS = "src/common/ServerScriptService/Services/Stats/StatsService.luau"
local BRIDGE = "src/common/ServerScriptService/Progression/PlayerStatsBridge.luau"
local CONFIG = "src/common/ReplicatedStorage/Shared/Config.luau"

local passed = 0
local function pass(text)
	passed += 1
	print("PASS " .. text)
end
local function read(path)
	return (fs.readFile(path):gsub("\r\n", "\n"))
end
local function has(source, needle, message)
	assert(string.find(source, needle, 1, true), message .. " (missing: " .. needle .. ")")
end
local function between(source, first, last)
	local a = assert(string.find(source, first, 1, true), "missing " .. first)
	local b = assert(string.find(source, last, a + #first, true), "missing " .. last .. " after " .. first)
	return string.sub(source, a, b - 1)
end

----------------------------------------------------------------------
-- 1. Bootstrap
----------------------------------------------------------------------
do
	local source = read(BOOTSTRAP)
	assert(luau.compile(fs.readFile(BOOTSTRAP)), "Bootstrap compiles")
	-- Update4Config is optional (the P0-only build has none) and never waited for.
	local loader = between(source, "local U4: any = nil", "local function u4IsOn")
	has(loader, 'shared:FindFirstChild("Update4Config")', "Update4Config found without a wait")
	has(loader, "pcall(require, module)", "...and required in a pcall")
	assert(not loader:find("WaitForChild"), "no WaitForChild on Update4Config")
	has(source, "local ok, on = pcall(U4.IsOn, feature)", "U4.IsOn is called through a pcall")

	local boost = between(source, "LatestStateLimiter.Connect(BoostState", "syncBoostStaminaAttributes(player)")
	has(boost, 'if player:GetAttribute("RaceActive") == true then\n\t\twantsBoost = false', "BoostState is forced off in a race")

	local regen = between(source, "local delaySeconds = Config.BoostRegenDelaySeconds", "stamina = math.min(stamina, maxStamina)")
	has(regen, 'player:GetAttribute("StaminaRegen2xOwned") == true', "the pass attribute")
	has(regen, 'player:GetAttribute("RaceActive") ~= true', "never in races")
	has(regen, 'u4IsOn("StaminaPass")', "only while the feature is on (and has a pass id)")
	has(regen, "delaySeconds *= if passOwned then (tonumber(U4.StaminaPass.DelayScale) or 1) else 1", "the wait scales")
	has(regen, "regenPerSecond *= if passOwned then (tonumber(U4.StaminaPass.RegenMultiplier) or 1) else 1", "the refill scales")
	assert(string.find(regen, "delaySeconds *=", 1, true) < string.find(regen, "if now - lastUse >= delaySeconds", 1, true),
		"the scaled wait is the one compared")

	local titles = between(source, "local function attachTitleToCharacter", "local function syncSuit")
	has(titles, "(_G :: any).SpeedsterTitles", "titles come from TitleService")
	has(titles, 'targetPlayer:GetAttribute("EquippedTitle") ~= nil', "...only while it publishes EquippedTitle")
	has(titles, "pcall(titlesApi.Visual, targetPlayer)", "Visual is called in a pcall")
	has(titles, "titlesFolder:FindFirstChild(tostring(visual.Template))", "the template TitleService names")
	has(titles, 'elseif Config.IsDeveloper(targetPlayer) then\n\t\t\ttemplate = titlesFolder:FindFirstChild("Dev")', "Dev fallback")
	has(titles, 'elseif Config.IsTester(targetPlayer) then\n\t\t\ttemplate = titlesFolder:FindFirstChild("Tester")', "Tester fallback")
	has(titles, 'targetPlayer:SetAttribute("IsDev", true)', "IsDev is still set")
	has(titles, 'targetPlayer:SetAttribute("IsTester", true)', "IsTester is still set")
	local _, destroys = string.gsub(titles, 'character:FindFirstChild%("PlayerTitlePart"%)\n%s*if shown then\n%s*shown:Destroy%(%)', "")
	assert(destroys == 2, "the shown title goes when no title applies (Visual nil, or no template at all)")
	for _, attribute in { "TitleId", "TitleStyle", "TitleText" } do
		has(titles, 'titlePart:SetAttribute("' .. attribute .. '", visual.', "PlayerTitlePart." .. attribute)
	end
	has(titles, 'titleLabel.Text = tostring(visual.Text or "")', "the label shows the title's text")
	has(titles, '(visual.Template == "Plain" or visual.Template == "Gold")', "only Plain/Gold take catalog colours")

	local hook = between(source, 'player:GetAttributeChangedSignal("EquippedSkin"):Connect(syncSuit)', "syncSuit()")
	has(hook, 'player:GetAttributeChangedSignal("EquippedTitle"):Connect(function()', "EquippedTitle redraws the title")
	has(hook, "attachTitleToCharacter(player, player.Character)", "...on the current character")

	-- Kept for retention (PLAN §7.7): the boost toast remote and the before-release saves.
	has(source, 'getOrCreateRemote("TemporaryBoostUpdate")', "TemporaryBoostUpdate remote")
	has(source, "for name, callback in beforeReleaseCallbacks do", "before-release saves")
	pass("Bootstrap: race sprint off, 2x Stamina Regen outside races, titles from TitleService with the Dev/Tester fallback, EquippedTitle redraw")
end

----------------------------------------------------------------------
-- 2. StatsService / PlayerStatsBridge
----------------------------------------------------------------------
do
	local StatsService = luau.load(fs.readFile(STATS), { environment = setmetatable({}, { __index = _G }) })()
	local before = { speed = 1000, wins = 0, rebirths = 0, speedCarry = 0 }
	local function added(multipliers)
		local result = StatsService.CalculateSpeedGain(before, 10, multipliers)
		assert(result.ok, "gain accepted")
		return result.value.values.speed + result.value.values.speedCarry - before.speed
	end
	local plain = added({})
	assert(plain > 0, "a plain gain")
	assert(math.abs(added({ retention = 2 }) - plain * 2) < 1e-6, "retention x2 doubles the gain")
	assert(math.abs(added({ retention = 3.4 }) - plain * 3.4) < 1e-6, "the x3.4 cap passes through")
	assert(added({ retention = 0.5 }) == plain, "retention never lowers a gain")
	assert(added({ retention = 0 / 0 }) == plain, "NaN retention counts as x1 (the gain is not refused)")
	assert(math.abs(added({ retention = 50 }) - plain * 10) < 1e-6, "clamped at x10")
	assert(math.abs(added({ retention = 2, disco = 2 }) - plain * 4) < 1e-6, "multiplies with the other factors")

	-- The bridge: SpeedsterAddSpeed passes the attribute, x1 in races.
	local captured = nil
	local DataService = {
		GetHandle = function()
			return {}
		end,
		PeekSpeed = function()
			return 0
		end,
		AccrueSpeed = function(_, _, _, multipliers)
			captured = multipliers
			return { ok = true }
		end,
	}
	local stubs = { ["../Services/Data/DataService"] = DataService }
	local fakeG = {}
	local env = setmetatable({
		_G = fakeG,
		require = function(path)
			return stubs[path] or {}
		end,
	}, { __index = _G })
	local Bridge = luau.load(fs.readFile(BRIDGE), { environment = env })()
	Bridge.RegisterGlobals()
	local attributes = {}
	local player = {
		UserId = 1,
		GetAttribute = function(_, key)
			return attributes[key]
		end,
	}
	local function retentionPassed()
		captured = nil
		fakeG.SpeedsterAddSpeed(player, 10)
		assert(captured, "AccrueSpeed called")
		return captured.retention
	end
	assert(retentionPassed() == 1, "no attribute -> x1")
	attributes.RetentionSpeedGainMultiplier = 2.2
	assert(math.abs(retentionPassed() - 2.2) < 1e-9, "the published multiplier")
	attributes.RaceActive = true
	assert(retentionPassed() == 1, "x1 while RaceActive")
	attributes.RaceActive = nil
	attributes.RetentionSpeedGainMultiplier = 0 / 0
	assert(retentionPassed() == 1, "NaN attribute -> x1")
	local bridge = read(BRIDGE)
	has(between(bridge, "g.SpeedsterGetTotalGainMultiplier = function", "return mult"), "* retentionMultiplier(player)",
		"the total multiplier shown to players includes it")
	pass("StatsService x retention (1..10, bad = x1); the bridge passes RetentionSpeedGainMultiplier, x1 in races")
end

----------------------------------------------------------------------
-- 3. Config
----------------------------------------------------------------------
do
	local source = read(CONFIG)
	has(source, "Config.WalkSpeedSelectorFloor = 16\n", "M50 floor")
	has(source, "Config.WalkSpeedSelectorFullBelow = 24\n", "M50 full-speed threshold")
	has(source, 'Config.MovementGuardMode = "Observe"\n', "H10 Observe")
	-- Config reads the place at require time; the staff tables and checks load on their own.
	local chunk = "local Config = {}\n" .. between(source, "Config.Testers = {", "return Config") .. "return Config\n"
	assert(not chunk:find("player.DisplayName", 1, true), "no DisplayName in the staff checks")
	local Config = luau.load(chunk)()
	local function player(name, displayName, userId, attributes)
		return {
			Name = name,
			DisplayName = displayName,
			UserId = userId,
			GetAttribute = function(_, key)
				return (attributes or {})[key]
			end,
		}
	end
	-- 2026-09-26 (owner): Gekkoh (767108248) is no longer forced to DEV; pxuto stays by UserId.
	assert(Config.IsDeveloper(player("someone", "x", 111827288)), "developer by UserId")
	assert(not Config.IsDeveloper(player("GekkoH", "x", 767108248)), "Gekkoh is not forced to DEV")
	assert(not Config.IsDeveloper(player("impostor", "pxuto", 2)), "a DisplayName is not a developer")
	assert(Config.IsTester(player("Fabbyy_YT", "x", 3)), "tester by Name")
	assert(not Config.IsTester(player("impostor", "fabbyy_yt", 4)), "a DisplayName is not a tester")
	assert(Config.IsTester(player("x", "y", 5, { IsTester = true })), "the server-set attribute still counts")
	assert(not Config.IsDeveloper(nil) and not Config.IsTester(nil), "nil player")
	pass("Config: M50 floor 16 / full below 24, MovementGuard Observe, staff by Name or UserId only")
end

----------------------------------------------------------------------
-- 4. Update4Config Race Gate points
----------------------------------------------------------------------
do
	local U4 = require("../src/common/ReplicatedStorage/Shared/Update4Config")
	local gate = U4.Race.Gate
	local function near(v, x, y, z)
		return math.abs(v.X - x) < 1e-3 and math.abs(v.Y - y) < 1e-2 and math.abs(v.Z - z) < 1e-3
	end
	assert(near(gate.World1.Position, 404, 37467.69, -1664) and near(gate.World1.Face, 340, 37467.69, -1664), "World 1 gate")
	assert(near(gate.World2.Position, -845, 36626.65, -1005) and near(gate.World2.Face, -784, 36626.65, -1005), "World 2 gate (unchanged)")
	assert(near(gate.World3.Position, 136, 95.61, 392) and near(gate.World3.Face, 200, 95.61, 392), "World 3 gate")
	assert(not read("audit/test_u4_race_placement.luau"):find("PROPOSED", 1, true), "the placement test has no override left")
	pass("Update4Config: the Race Gate points test_u4_race_placement accepts")
end

----------------------------------------------------------------------
-- 5. Build, runner, library
----------------------------------------------------------------------
do
	local build = read("audit/build_update4.luau")
	has(build, 'local BACKUP = "output/FableRetentionP0_20260924/backup_src/"', "guard baseline: what the places carry")
	for _, needle in {
		'require("./u4_race_board").Remove(dm, notes)', -- 2026-09-26: the old board comes out
		"refreshGate(dm, key, notes, false)", -- 2026-09-26: The Flash's gate (v2)
		'require("./u4_title_templates").Insert(dm, notes)',
		'require("./u4_shop_card").Insert(dm, notes)',
		"RaceArenaBuilder.Build(workspace, ENV)",
		"RaceArenaBuilder.BuildGate(workspace, key, ENV)",
		"NumberRange = roblox.NumberRange",
		"Font = roblox.Font",
		"createFolders = true",
		'dryRun = mode == "check"',
		'"output/Update4/build_p0"',
		'"output/Update4/build_full"',
	} do
		has(build, needle, "build_update4")
	end
	-- `list` / `list p0` read no place and write nothing.
	local function list(...)
		local result = process.exec("lune", { "run", "audit/build_update4.luau", "list", ... })
		assert(result.ok, "build_update4 list failed: " .. tostring(result.stderr))
		return result.stdout
	end
	local full, p0 = list(), list("p0")
	-- 2026-09-25, second build: a file the places already carry (the first Update 4 build,
	-- re-exported to output/Update4/places_now_src before each build by
	-- audit/export_place_sources.luau) is not shipped again, and that is fine.
	local PLACES_NOW = "output/Update4/places_now_src/"
	local function carried(path)
		local now = PLACES_NOW .. path:gsub("^src/", "")
		return fs.isFile(now) and fs.readFile(now):gsub("\r\n", "\n") == fs.readFile(path):gsub("\r\n", "\n")
	end
	local function listed(output, path)
		return output:find("  changed " .. path, 1, true) ~= nil or output:find("  new     " .. path, 1, true) ~= nil
	end
	local function ships(output, path)
		return listed(output, path) or carried(path)
	end
	for _, path in {
		"src/common/ReplicatedStorage/Shared/QuestPeriod.luau",
		"src/common/ServerScriptService/Services/PoseHistory.luau",
		"src/common/ReplicatedStorage/Shared/HazardNames.luau",
		"src/common/ServerScriptService/Services/LocalDeathRules.luau",
		"src/common/ServerScriptService/Gameplay/LocalDeathArbiter.server.luau",
		"src/common/ServerScriptService/Services/Data/SessionActor.luau",
		"src/common/ReplicatedStorage/Shared/Config.luau",
		"src/common/ServerScriptService/Bootstrap.server.luau",
		"src/common/ReplicatedStorage/Shared/Update4Config.luau",
	} do
		assert(ships(p0, path), "p0 ships " .. path)
		assert(ships(full, path), "the full build ships " .. path)
	end
	for _, path in {
		"src/common/ServerScriptService/Services/Race/RaceService.luau",
		"src/common/ServerScriptService/Social/RetentionService.server.luau",
		"src/common/ServerScriptService/Services/Titles/TitleService.luau",
		"src/common/StarterPlayer/StarterPlayerScripts/Race/RacePoseClient.client.luau",
		"src/common/ReplicatedStorage/BubbleModule.luau",
	} do
		assert(not listed(p0, path), "p0 leaves out " .. path)
		assert(ships(full, path), "the full build ships " .. path)
	end
	assert(not p0:find("CHECK  ", 1, true), "every module a P0 file names is shipped or reviewed")

	local runner = read("audit/run_update4_checks.luau")
	for _, name in fs.readDir("audit") do
		if name:match("^test_u4_.+%.luau$") then
			has(runner, '"audit/' .. name .. '"', "run_update4_checks lists it")
		end
	end
	for _, name in { "test_retention_p1_data", "test_retention_p1_gameplay", "test_fable_interface_hider",
		"test_funnel_analytics", "test_retention_p0", "test_new_persistence" } do
		has(runner, '"audit/' .. name .. '.luau"', "run_update4_checks lists it")
	end
	has(runner, '{ "audit/test_u4_race_arena.luau", "places", "prebuild" }', "arena vs the maps before the build")
	for _, name in { "test_u4_race_arena", "test_u4_titles", "test_u4_race_board" } do
		has(runner, '{ "audit/' .. name .. '.luau", "places" }', "after the build")
	end

	local lib = read("audit/fable_build_lib.luau")
	has(lib, "local dryRun = options.dryRun == true", "dryRun")
	has(lib, "if dryRun then\n\t\tprint(\"dry run: \"", "dryRun returns before writing")
	has(lib, "options.createFolders == true and row.added == true", "createFolders, only for added rows")
	pass("build_update4 (list / list p0), run_update4_checks and fable_build_lib agree with PLAN §5.J")
end

----------------------------------------------------------------------
-- 6. Workstream fixes applied by the integrator
----------------------------------------------------------------------
do
	local daily = read("src/common/StarterPlayer/StarterPlayerScripts/UI/DailyRewardController.client.luau")
	has(daily, "icon.Image = DailyRewards.GetRewardIconImage(reward)", "Daily cards show the reward's own art")
	has(daily, "for _, child in ipairs(card:GetChildren()) do\n\t\t\tif child:IsA(\"ImageLabel\") then", "...on the card's own icon, not the Locked overlay")
	local race = read("src/common/ServerScriptService/Services/Race/RaceService.luau")
	has(race, 'entry.racer.race == self.race and entry.state ~= "Done"', "a racer still in this race cannot queue twice")
	local builder = read("src/common/ServerScriptService/Services/Race/RaceArenaBuilder.luau")
	has(builder, "label.FontFace = self.env.Font.fromEnum(Enum.Font.FredokaOne)", "arena labels serialize in Lune")
	pass("Daily icon art, RaceService Join refusal, arena labels through FontFace")
end

print(("test_u4_integration: %d checks passed"):format(passed))
