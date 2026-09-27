-- Regression guard for the visual First Upgrade modal in all three places.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local sourcePath = "src/common/StarterPlayer/StarterPlayerScripts/UI/FirstTimeTutorial.client.luau"
local source = fs.readFile(sourcePath)
local manifest = serde.decode("json", fs.readFile("src/manifest.json"))
local places = {
	World1 = "World1Update3New.rbxl",
	World2 = "World2Update3new.rbxl",
	World3 = "World3Update3New.rbxl",
}

local function contains(needle)
	return source:find(needle, 1, true) ~= nil
end

luau.compile(source)
assert(contains("SpeedsterFirstUpgradePrompt"), "ScreenGui name must be present")
assert(contains("rbxassetid://82176677996191"), "Orange Aura icon must be present")
assert(contains("rbxassetid://123961542220277"), "Speed lightning icon must be present")
assert(contains("rbxassetid://15540211845"), "Wins trophy icon must be present")
assert(contains("Aura05"), "Aura05 purchase action must be present")
assert(contains("Trail05"), "Trail05 purchase action must be present")
assert(contains("EQUIP NOW"), "Equip button text must be present")
assert(not contains("SendNotification"), "Text-only SendNotification must be replaced")

print("PASS source: visual modal with aura icon, badges, one-tap equip and clean animations")

for world, filename in places do
	local place = roblox.deserializePlace(fs.readFile(filename))
	local node = place
	local entry
	for _, row in manifest.worlds[world].scripts do
		if row.source == sourcePath then
			assert(entry == nil, world .. " has duplicate manifest tutorial scripts")
			entry = row
		end
	end
	assert(entry, world .. " lacks the tutorial script in the manifest")
	for _, segment in entry.segments do
		node = assert(node:FindFirstChild(segment), world .. " missing " .. segment)
	end
	assert(node:IsA("LocalScript"), world .. " tutorial script must be LocalScript")
	assert(node.Source == source, world .. " embeds a stale tutorial script")

	print("PASS " .. world .. ": verified tutorial script embedded")
end
print("ALL TUTORIAL MODAL TESTS PASSED SUCCESSFULLY!")
