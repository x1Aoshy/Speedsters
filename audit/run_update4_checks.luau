-- audit/run_update4_checks.luau (Update 4, integrator, 2026-09-25; PLAN §5.J): compiles every src
-- file and runs every Update 4 test.
--   lune run audit/run_update4_checks.luau          before the build (the place tests build the
--                                                   arena / gate in memory)
--   lune run audit/run_update4_checks.luau places   after audit/build_update4.luau: also checks
--                                                   what the build wrote into the three places
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local TESTS = {
	-- Integrator: contracts (Phase 0) and the merge (Phase 1).
	{ "audit/test_u4_contracts.luau" },
	{ "audit/test_u4_integration.luau" },
	{ "audit/test_funnel_analytics.luau" },
	{ "audit/test_retention_p0.luau" },
	{ "audit/test_new_persistence.luau" },
	-- p0_data / p0_gameplay
	{ "audit/test_retention_p1_data.luau" },
	{ "audit/test_retention_p1_gameplay.luau" },
	-- race_server
	{ "audit/test_u4_race_math.luau" },
	{ "audit/test_u4_race_charge.luau" },
	{ "audit/test_u4_race_rewards.luau" },
	{ "audit/test_u4_race_leaderboard.luau" },
	{ "audit/test_u4_race_validation.luau" },
	{ "audit/test_u4_race_lifecycle.luau" },
	{ "audit/test_u4_race_terrain.luau" }, -- 2026-09-25: hills (ground profile) and speed pads
	{ "audit/test_u4_race_arena.luau" },
	{ "audit/test_u4_race_placement.luau" },
	-- race_client
	{ "audit/test_u4_race_hud_layout.luau" },
	{ "audit/test_u4_race_ui.luau" },
	{ "audit/test_u4_race_client_static.luau" },
	{ "audit/test_fable_interface_hider.luau" },
	-- race_fx
	{ "audit/test_u4_race_pose.luau" },
	{ "audit/test_u4_race_vfx.luau" },
	-- titles_boards
	{ "audit/test_u4_title_service.luau" },
	{ "audit/test_u4_titles.luau" },
	{ "audit/test_u4_race_board.luau" },
	-- retention
	{ "audit/test_u4_retention_math.luau" },
	{ "audit/test_u4_retention_service.luau" },
	{ "audit/test_u4_topbar.luau" },
	-- community_pass_admin
	{ "audit/test_u4_community.luau" },
	{ "audit/test_u4_stamina_pass.luau" },
	{ "audit/test_u4_admin_events.luau" },
	-- 2026-09-25 polish: topbar/HUD cleanup, lobby NPCs, Blender race art.
	{ "audit/test_u4_ui_cleanup.luau" },
	{ "audit/test_u4_npcs.luau" },
	{ "audit/test_u4_race_assets.luau" },
	{ "audit/test_u4_npc_r6.luau" },
	-- 2026-09-26: the Green Hill map (audit/u4_greenhill_arena, build --greenhill), its water, look and wind.
	{ "audit/test_u4_greenhill.luau" },
	-- 2026-09-26 (owner): frictionless race walls / barriers / caps / lips / fences, the floor keeps its friction.
	{ "audit/test_u4_race_walls.luau" },
	-- 2026-09-26 (owner): AFK Mode stands the character (never anchored / seated) and moving ends it.
	{ "audit/test_afk_zone.luau" },
	-- 2026-09-26 (owner): The Flash's race gate (the arch, the ring pad, his crackles) and the holo board.
	{ "audit/test_u4_flash_gate.luau" },
	-- 2026-09-26 (owner): Dr. Eggman in his Egg Mobile (Shared/EggMobile, audit/u4_egg_mobile).
	{ "audit/test_u4_egg_mobile.luau" },
	-- 2026-09-26 (owner): nobody flies in the race (Shared/RaceNoFlight, FlightService, the validator).
	{ "audit/test_u4_race_noflight.luau" },
	-- 2026-09-26 (owner): the Super Sonic vs Eggman live event, server side (Shared/SuperSonicEvent,
	-- Gameplay/SuperSonicEventCore + Service, the admin tile, audit/u4_supersonic_assets).
	{ "audit/test_u4_supersonic_event.luau" },
	-- 2026-09-26 (owner): the event's Blender meshes (audit/event_kit_bpy.py, audit/u4_event_kit: SuperSonicEventAssets.Meshes).
	{ "audit/test_u4_event_kit.luau" },
	-- 2026-09-26 (owner): the event, client side (Gameplay/SuperSonicEventClient, Shared/SuperSonicEventFx,
	-- Shared/SuperSonicLook): the look on an R6 with an aura, the touch button vs the touch controls, and the
	-- real client in a fake Roblox through a whole event.
	{ "audit/test_u4_supersonic_client.luau" },
	-- 2026-09-26 (owner/QA): the "2X Stamina" Shop card (audit/u4_shop_card from 2X Speed, LayoutOrder) and
	-- the Shop's canvas following its content (Shared/ShopCanvasFlow), on the real Shop at 5 screen sizes.
	{ "audit/test_u4_shop_layout.luau" },
	-- 2026-09-26 (owner): console / gamepad first-class (Shared/ConsolePanelSupport Tabs/Back/FirstButton,
	-- the Shop's and Titles' bumpers and B, ConsoleUiScale's first selection, the race's pad bindings and glyphs).
	{ "audit/test_u4_gamepad.luau" },
	-- 2026-09-26 (owner): "the Spin the Wheel shows Quests" / "verify the Daily Rewards": every lobby menu
	-- entry opens its own panel (the real MenuEvents and listeners), Dr. Eggman's late quests never replace
	-- a menu opened during his line, the Daily claim on a fake clock and the topbar Daily notice.
	{ "audit/test_u4_menu_routing.luau" },
	-- 2026-09-26 (owner): the leaderboard champions show their accessories and dance: one layer
	-- (UI/GlobalLeaderboardDisplay + Shared/LeaderboardChampionRig), the real display in a fake Roblox.
	{ "audit/test_leaderboard_champions.luau" },
	-- Not here, broken before Update 4 (2026-09-25): test_admin_abuse_panel stops at its World 2
	-- dance-floor check (the place geometry, ~line 410), looks for a removed `local function
	-- addSpeed` in TreadmillTraining and exits on the AdminAbuseEffects disco simulation;
	-- test_new_skins still matches `if Config.IsWorld2Place then\n\tConfig.SuitSpeedGainMultipliers`
	-- (Config says `if Config.IsWorld2Place or Config.IsWorld3Place then` since before 09-24).
}
local BEFORE_BUILD = {
	{ "audit/test_u4_race_arena.luau", "places", "prebuild" },
	-- 2026-09-26: prebuild notes a place arena whose spike tiles predate Update4Config (--greenhill remakes them).
	{ "audit/test_u4_greenhill.luau", "places", "prebuild" },
}
local AFTER_BUILD = {
	{ "audit/test_u4_race_arena.luau", "places" },
	{ "audit/test_u4_titles.luau", "places" },
	{ "audit/test_u4_race_board.luau", "places" },
	{ "audit/test_u4_npc_r6.luau", "places" },
	{ "audit/test_u4_greenhill.luau", "places" },
	{ "audit/test_u4_egg_mobile.luau", "places" },
	{ "audit/test_u4_supersonic_event.luau", "places" },
}

local placesMode = process.args[1] == "places"
for _, test in if placesMode then AFTER_BUILD else BEFORE_BUILD do
	table.insert(TESTS, test)
end

-- Every src file compiles (luau.compile raises on a syntax error).
local compiled, compileErrors = 0, {}
local function walk(dir)
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			walk(path)
		elseif name:match("%.luau$") then
			-- 2026-09-26: at optimisation level 0, as Studio compiles scripts: the default level (1) folds
			-- locals away and passed a MainHUDController Studio refused (over 200 locals in its chunk).
			local ok, err = pcall(luau.compile, fs.readFile(path), { optimizationLevel = 0 })
			if ok then
				compiled += 1
			else
				table.insert(compileErrors, path .. ": " .. tostring(err))
			end
		end
	end
end
walk("src/common")
walk("src/worlds")
if #compileErrors > 0 then
	for _, message in compileErrors do
		print("COMPILE " .. message)
	end
else
	print(("ok   compiled %d src files"):format(compiled))
end

local failures = #compileErrors
for index, test in TESTS do
	local result = process.exec("lune", { "run", table.unpack(test) })
	local label = table.concat(test, " ")
	if result.ok then
		print(("ok   [%d/%d] %s"):format(index, #TESTS, label))
	else
		failures += 1
		print(("FAIL [%d/%d] %s"):format(index, #TESTS, label))
		print((result.stdout or ""):sub(-1500))
		print((result.stderr or ""):sub(-1500))
	end
end
print(("RESULT: %d failures out of %d (%s)"):format(failures, #TESTS + 1, if placesMode then "after the build" else "before the build"))
if failures > 0 then
	process.exit(1)
end
