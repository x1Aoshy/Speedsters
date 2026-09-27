-- audit/build_fable_suite_repair.luau  (2026-09-20)
-- Two bugs in Admin/AdminTreadmillReveal that audit/test_admin_treadmill_reveal.luau found once it
-- ran again (its mock had fallen behind the client):
--   * stop() called showInterface() above its declaration, where the name is a nil global: every
--     reveal ended in an error before destroying its rumble, colour grade and ScreenGui, and a
--     reveal replaced mid-flight left the HUD hidden;
--   * the GO handler lost its guard (`if warpAt` only), so GO fired for a treadmill that was gone.
-- Source patch: scratch/fsr09_patch_reveal_client.py. Notes: output/FableSuiteRepair/LEEME.md
local Lib = require("./fable_build_lib")
Lib.run({
	output = "output/FableSuiteRepair",
	sources = {
		{
			source = "src/common/StarterPlayer/StarterPlayerScripts/Admin/AdminTreadmillReveal.client.luau",
			guard = "output/FableSuiteRepair/backup_src/AdminTreadmillReveal.client.luau",
		},
	},
})
