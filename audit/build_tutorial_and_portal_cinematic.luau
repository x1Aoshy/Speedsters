-- audit/build_tutorial_and_portal_cinematic.luau
-- Injects updated FirstTimeTutorial (dimmer focus, full window colors, 10s skip) and
-- WorldPortalCinematic (Admin Treadmill style smooth pan, letterbox bars, FredokaOne announcement)
-- into World1Update3New.rbxl, World2Update3new.rbxl, and World3Update3New.rbxl.

local fs = require("@lune/fs")
local rb = require("@lune/roblox")
local luau = require("@lune/luau")
local serde = require("@lune/serde")

print("==================================================")
print("BUILD: Tutorial Overhaul & World Portal Cinematic")
print("==================================================")

local manifest = serde.decode("json", fs.readFile("src/manifest.json"))

local tutorialPath = "src/common/StarterPlayer/StarterPlayerScripts/UI/FirstTimeTutorial.client.luau"
local tutorialSrc = fs.readFile(tutorialPath)
local tutorialBytecode = luau.compile(tutorialSrc)
assert(#tutorialBytecode > 0, "Failed to compile FirstTimeTutorial")

local tutorialPatterns = {
	"SpeedsterGuidedDimmer",
	"SpeedsterGuidedSpotlight",
	"HighlightRing",
	"Ripple",
	"HoleTap",
	"PointerContainer",
	"SkipTutorial",
	"SKIP (10s) ✕",
	"TAP BACKPACK",
	"TAP AURAS",
	"EQUIP AURA (+2.5x)",
	"🎉 EQUIPPED! +2.5x SPEED 🎉",
	"Aura05",
	"Trail05",
	"AuraShopAction",
	"TrailShopAction",
	"finishTutorial",
	"originalMainhudOrder",
	"originalBackpackOrder",
	"DisplayOrder = 15",
	"DisplayOrder = 20",
}

for _, pat in ipairs(tutorialPatterns) do
	assert(string.find(tutorialSrc, pat, 1, true), "Pattern missing in FirstTimeTutorial: " .. pat)
end
print("VERIFIED: FirstTimeTutorial (" .. #tutorialBytecode .. " bytes bytecode)")

local cinematicPath = "src/common/StarterPlayer/StarterPlayerScripts/UI/WorldPortalCinematic.client.luau"
local cinematicSrc = fs.readFile(cinematicPath)
local cinematicBytecode = luau.compile(cinematicSrc)
assert(#cinematicBytecode > 0, "Failed to compile WorldPortalCinematic")

local cinematicPatterns = {
	"WorldPortalCinematicGui",
	"BarTop",
	"BarBottom",
	"DipFrame",
	"Something changed, please go check!",
	"🌟 WORLD PORTAL UNLOCKED! 🌟",
	"Enum.Font.FredokaOne",
	"WorldPortalCinematicCamera",
	"findPortalInstance",
	"meetsRequirementsForNextWorld",
	"WorldPortalCinematicSeen_W",
	"SkipCinematic",
}

for _, pat in ipairs(cinematicPatterns) do
	assert(string.find(cinematicSrc, pat, 1, true), "Pattern missing in WorldPortalCinematic: " .. pat)
end
print("VERIFIED: WorldPortalCinematic (" .. #cinematicBytecode .. " bytes bytecode)")

local worlds = {
	{ key = "World1", file = "World1Update3New.rbxl" },
	{ key = "World2", file = "World2Update3new.rbxl" },
	{ key = "World3", file = "World3Update3New.rbxl" },
}

local stamp = os.date("!%Y%m%d_%H%M%S")
local backup = "output/Backup_TutorialAndCinematic_" .. stamp
local output = "output/TutorialAndCinematic_" .. stamp
fs.writeDir(backup)
fs.writeDir(output)

local function findNode(root, segments)
	local node = root
	for _, name in ipairs(segments) do
		node = assert(node:FindFirstChild(name), "Missing node: " .. name)
	end
	return node
end

local report = {
	timestamp = stamp,
	backup = backup,
	output = output,
	worlds = {},
}

for _, world in ipairs(worlds) do
	print("\n--- Processing " .. world.key .. " (" .. world.file .. ") ---")
	local oldPlace = fs.readFile(world.file)
	local dm = rb.deserializePlace(oldPlace)
	local rows = {}
	for _, row in ipairs(manifest.worlds[world.key].scripts) do
		rows[row.source] = row
	end

	-- 1. Backup original place file
	local backupFile = backup .. "/" .. world.file
	fs.writeFile(backupFile, oldPlace)
	print("Saved backup to " .. backupFile)

	-- 2. Update FirstTimeTutorial
	local manifestEntry = assert(rows[tutorialPath], "Tutorial script not in manifest for " .. world.key)
	local tutorialInstance = findNode(dm, manifestEntry.segments)
	tutorialInstance.Source = tutorialSrc
	print("Updated " .. tutorialPath .. " in " .. world.key)

	-- 3. Ensure WorldPortalCinematic in StarterPlayerScripts.UI
	local sp = assert(dm:FindFirstChild("StarterPlayer"), "StarterPlayer not found in " .. world.key)
	local sps = assert(sp:FindFirstChild("StarterPlayerScripts"), "StarterPlayerScripts not found in " .. world.key)
	local uiFolder = assert(sps:FindFirstChild("UI"), "StarterPlayerScripts.UI not found in " .. world.key)

	local cinematicScript = uiFolder:FindFirstChild("WorldPortalCinematic")
	local isNewScript = false
	if not cinematicScript then
		cinematicScript = rb.Instance.new("LocalScript")
		cinematicScript.Name = "WorldPortalCinematic"
		cinematicScript.Parent = uiFolder
		isNewScript = true
		print("Created new LocalScript WorldPortalCinematic in " .. world.key)
	end
	cinematicScript.Source = cinematicSrc

	-- 4. Serialize & Roundtrip Check
	local count = #dm:GetDescendants()
	local bytes = rb.serializePlace(dm)
	local check = rb.deserializePlace(bytes)

	local checkTutorial = findNode(check, manifestEntry.segments)
	assert(checkTutorial.Source == tutorialSrc, world.key .. " FirstTimeTutorial source mismatch")

	local checkCinematic = check.StarterPlayer.StarterPlayerScripts.UI:FindFirstChild("WorldPortalCinematic")
	assert(checkCinematic and checkCinematic.Source == cinematicSrc, world.key .. " WorldPortalCinematic source mismatch")

	assert(#check:GetDescendants() == count, world.key .. " descendant count mismatch after serialization")

	-- 5. Write updated place file to workspace and output folder
	fs.writeFile(world.file, bytes)
	fs.writeFile(output .. "/" .. world.file, bytes)

	report.worlds[world.key] = {
		file = world.file,
		totalInstances = count,
		isNewScript = isNewScript,
		verified = true,
	}
	print("SUCCESS: Injected and verified " .. world.key .. " (instances: " .. count .. ")")
end

fs.writeFile("audit/build_tutorial_and_portal_cinematic_report.json", serde.encode("json", report))
print("\n==================================================")
print("BUILD COMPLETED SUCCESSFULLY FOR ALL 3 WORLDS!")
print("==================================================")
