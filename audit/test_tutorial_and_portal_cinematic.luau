-- audit/test_tutorial_and_portal_cinematic.luau
-- Full automated regression test for the UI Tutorial overhaul and World Portal Unlock Cinematic.

local fs = require("@lune/fs")
local rb = require("@lune/roblox")
local luau = require("@lune/luau")

print("================================================================")
print("TEST: UI Tutorial Overhaul & World Portal Unlock Cinematic")
print("================================================================")

-- 1. Source verification: FirstTimeTutorial
local tutorialSrc = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/UI/FirstTimeTutorial.client.luau")
local tutorialBytecode = luau.compile(tutorialSrc)
assert(#tutorialBytecode > 0, "Failed to compile FirstTimeTutorial.client.luau")

-- Assert 4-blockers are completely gone (no cutout masks)
assert(not string.find(tutorialSrc, "TopBlocker", 1, true), "TopBlocker cutout still present in tutorial!")
assert(not string.find(tutorialSrc, "BottomBlocker", 1, true), "BottomBlocker cutout still present in tutorial!")
assert(not string.find(tutorialSrc, "LeftBlocker", 1, true), "LeftBlocker cutout still present in tutorial!")
assert(not string.find(tutorialSrc, "RightBlocker", 1, true), "RightBlocker cutout still present in tutorial!")
print("PASS: 4-blocker cutouts successfully removed from FirstTimeTutorial.")

-- Assert dimmer and layer elevation
assert(string.find(tutorialSrc, "SpeedsterGuidedDimmer", 1, true), "Missing SpeedsterGuidedDimmer")
assert(string.find(tutorialSrc, "DisplayOrder = 10", 1, true), "Missing Dimmer DisplayOrder = 10")
assert(string.find(tutorialSrc, "DisplayOrder = 15", 1, true), "Missing Mainhud DisplayOrder = 15 elevation")
assert(string.find(tutorialSrc, "DisplayOrder = 20", 1, true), "Missing Backpack DisplayOrder = 20 elevation")
assert(string.find(tutorialSrc, "originalMainhudOrder", 1, true), "Missing originalMainhudOrder restoration")
assert(string.find(tutorialSrc, "originalBackpackOrder", 1, true), "Missing originalBackpackOrder restoration")
print("PASS: Dimmer and window DisplayOrder elevation verified.")

-- Assert 10s auto-dismiss and prominent skip
assert(string.find(tutorialSrc, "SkipTutorial", 1, true), "Missing SkipTutorial button")
assert(string.find(tutorialSrc, "SKIP (10s) ✕", 1, true), "Missing SKIP (10s) ✕ text")
assert(string.find(tutorialSrc, "secondsLeft <= 0", 1, true), "Missing 10s auto-dismiss timeout check")
assert(string.find(tutorialSrc, "Enum.Font.FredokaOne", 1, true), "Missing Enum.Font.FredokaOne")
assert(string.find(tutorialSrc, "🎉 EQUIPPED! +2.5x SPEED 🎉", 1, true), "Missing celebration banner")
print("PASS: 10s auto-dismiss and prominent skip button verified.")

-- 2. Source verification: WorldPortalCinematic
local cinematicSrc = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/UI/WorldPortalCinematic.client.luau")
local cinematicBytecode = luau.compile(cinematicSrc)
assert(#cinematicBytecode > 0, "Failed to compile WorldPortalCinematic.client.luau")

assert(string.find(cinematicSrc, "WorldPortalCinematicGui", 1, true), "Missing WorldPortalCinematicGui")
assert(string.find(cinematicSrc, "BarTop", 1, true), "Missing BarTop")
assert(string.find(cinematicSrc, "BarBottom", 1, true), "Missing BarBottom")
assert(string.find(cinematicSrc, "DipFrame", 1, true), "Missing DipFrame")
assert(string.find(cinematicSrc, "Something changed, please go check!", 1, true), "Missing user-requested whisper text")
assert(string.find(cinematicSrc, "🌟 WORLD PORTAL UNLOCKED! 🌟", 1, true), "Missing world portal unlocked title")
assert(string.find(cinematicSrc, "Enum.Font.FredokaOne", 1, true), "Missing Enum.Font.FredokaOne in cinematic")
assert(string.find(cinematicSrc, "WorldPortalCinematicCamera", 1, true), "Missing camera render step")
assert(string.find(cinematicSrc, "findPortalInstance", 1, true), "Missing findPortalInstance")
assert(string.find(cinematicSrc, "meetsRequirementsForNextWorld", 1, true), "Missing meetsRequirementsForNextWorld")
assert(string.find(cinematicSrc, "WorldPortalCinematicSeen_W", 1, true), "Missing once-only persistence attribute")
assert(string.find(cinematicSrc, "SkipCinematic", 1, true), "Missing SkipCinematic button")
print("PASS: WorldPortalCinematic source patterns verified.")

-- 3. In-place rbxl verification
local worlds = {
	{ key = "World1", file = "World1Update3New.rbxl" },
	{ key = "World2", file = "World2Update3new.rbxl" },
	{ key = "World3", file = "World3Update3New.rbxl" },
}

for _, w in ipairs(worlds) do
	local bytes = fs.readFile(w.file)
	local dm = rb.deserializePlace(bytes)

	local sp = assert(dm:FindFirstChild("StarterPlayer"), "StarterPlayer missing in " .. w.key)
	local sps = assert(sp:FindFirstChild("StarterPlayerScripts"), "StarterPlayerScripts missing in " .. w.key)
	local ui = assert(sps:FindFirstChild("UI"), "StarterPlayerScripts.UI missing in " .. w.key)

	local tut = assert(ui:FindFirstChild("FirstTimeTutorial"), "FirstTimeTutorial missing in " .. w.key)
	assert(tut:IsA("LocalScript"), "FirstTimeTutorial is not a LocalScript in " .. w.key)
	assert(tut.Source == tutorialSrc, "FirstTimeTutorial source mismatch in " .. w.key)

	local cin = assert(ui:FindFirstChild("WorldPortalCinematic"), "WorldPortalCinematic missing in " .. w.key)
	assert(cin:IsA("LocalScript"), "WorldPortalCinematic is not a LocalScript in " .. w.key)
	assert(cin.Source == cinematicSrc, "WorldPortalCinematic source mismatch in " .. w.key)

	print("PASS: Place file " .. w.file .. " verified with updated tutorial and cinematic scripts.")
end

print("\n================================================================")
print("ALL TESTS PASSED WITH 100% SUCCESS!")
print("================================================================")
