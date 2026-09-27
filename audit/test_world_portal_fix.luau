-- Retired 2026-09-20. This test re-implemented the camera maths instead of running the real
-- code (and looked the front up from the first part named "Sign", which in World 1 faces
-- sideways). The flight is now tested from the real module against the real places by
-- audit/test_fable_tutorial_portal.luau; the old file is in output/FableTutorialPortal/retired.
local process = require("@lune/process")
local result = process.exec("lune", { "run", "audit/test_fable_tutorial_portal.luau", "places" })
print(result.stdout)
if not result.ok then
	print(result.stderr)
	process.exit(1)
end
