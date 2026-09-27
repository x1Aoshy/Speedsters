-- audit/run_fable_checks.luau: compile everything and run every test around the tutorial,
-- the HUD and the portal flight.   lune run audit/run_fable_checks.luau
local process = require("@lune/process")
local TESTS = {
	{ "audit/test_fable_tutorial_portal.luau", "places" },
	{ "audit/test_fable_hammers.luau", "places" },
	{ "audit/test_fable_smooth_obstacles.luau", "places" },
	{ "audit/test_fable_taco_meteor.luau", "places" },
	{ "audit/test_fable_trampoline.luau", "places" },
	{ "audit/test_fable_audit_fixes.luau", "places" },
	{ "audit/test_fable_teleport_price.luau", "places" },
	{ "audit/test_wins_economy.luau" },
	{ "audit/persistence/test_regression.luau", "World1" },
	{ "audit/persistence/test_regression.luau", "World2" },
	{ "audit/test_new_persistence.luau" },
	{ "audit/test_stage_transactions.luau", "World1" },
	{ "audit/test_quests_afk_persistence.luau" },
	{ "audit/test_tacos_tutorial_repair.luau" },
	{ "audit/test_tutorial_polish.luau" },
	{ "audit/test_onboarding_flow.luau" },
	{ "audit/test_ui_ergonomics.luau" },
	{ "audit/test_hud_ergonomics_startup.luau" },
	{ "audit/test_menu_reopen.luau" },
	{ "audit/test_funnel_analytics.luau" },
	-- The 2026-09-21 bug pass (audit/build_fable_opt6.luau).
	{ "audit/test_opt6_server_stall.luau", "places" },
	{ "audit/test_index_scroll_canvas.luau" },
	{ "audit/test_stamina_bar_display.luau" },
	{ "audit/test_stamina_hint.luau" },
	{ "audit/test_opt6_world3_lasers.luau" },
	{ "audit/test_opt6_lag_extras.luau" },
	{ "audit/test_world3_hazards.luau" },
	{ "audit/test_opt6_mobile_panels.luau" },
	{ "audit/test_opt6_touch_layout.luau" },
	-- The 2026-09-21 night QoL pass (audit/build_fable_qb.luau).
	{ "audit/test_qb_multipliers.luau" },
	{ "audit/test_qb_evolve_guide.luau" },
	{ "audit/test_qb_first_tutorial.luau" },
	{ "audit/test_qb_boss_hitboxes.luau" },
	-- The 2026-09-22 live-error / phone-performance / World 2 gate pass (audit/build_fable_perf.luau).
	{ "audit/test_perf_live_errors.luau" },
	{ "audit/test_perf_phone.luau" },
	{ "audit/test_perf_world_gates.luau" },
	-- The 2026-09-22 rebirth guide and tutorial languages pass (audit/build_fable_i18n.luau).
	{ "audit/test_i18n_rebirth_guide.luau" },
	-- The 2026-09-22 themed treadmill VFX / lobby phone LOD pass (audit/build_fable_treadmill_vfx.luau).
	{ "audit/test_treadmill_vfx.luau", "places" },
	-- The 2026-09-22 game-feel pass (audit/build_fable_feel.luau).
	{ "audit/test_feel_balance.luau" },
	{ "audit/test_feel_ground.luau" },
	{ "audit/test_feel_ground.luau", "places" },
	{ "audit/test_feel_letterbox.luau" },
	{ "audit/test_feel_evolve.luau" },
	-- The 2026-09-22 polish pass (audit/build_fable_polish.luau).
	{ "audit/test_polish_rebirth_guide.luau" },
	{ "audit/test_polish_mobile_panels.luau" },
	-- The 2026-09-24 retention P0 pass (output/Auditoria_Retencion_20260923).
	{ "audit/test_retention_p0.luau" },
	-- Not here, broken before this work (2026-09-20): test_backpack_layout and ~18 other audit
	-- scripts still read World{N}Update3.rbxl (the places are now ...New.rbxl); test_saved_uis wants
	-- src/ui/QuestGui.rbxm rebuilt.
}
local failures = 0
for index, test in TESTS do
	local args = { "run", table.unpack(test) }
	local result = process.exec("lune", args)
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
print(("RESULT: %d failures out of %d"):format(failures, #TESTS))
if failures > 0 then
	process.exit(1)
end
