-- Regression guard for the dual-state vector lightning loading screen in all three places.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local sourcePath = "src/common/ReplicatedFirst/LoadingScreen.client.luau"
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
assert(contains("rbxassetid://92044769924002"), "Use the supplied game icon")
assert(contains("rbxassetid://106423900726418"), "Use dimmed white bolt asset (off state)")
assert(contains("rbxassetid://123961542220277"), "Use electric yellow bolt asset (on state)")
assert(contains("BOLT_COUNT = 3"), "Show exactly three speed bolts")
assert(contains("COLOR_BG = Color3.fromRGB(0, 0, 0)"), "Use pure solid black background")
assert(contains("COLOR_YELLOW"), "Yellow electric charge color must be present")
assert(not contains("⚡"), "Emojis are strictly forbidden")
assert(not contains("makeBoltStroke"), "Procedural AI lightning bolt frames must be removed")
assert(contains("local TIPS = {"), "Loading tips must be available")
assert(contains("tipText.Text = TIPS[tipIndex]"), "Rotate visible gameplay tips")
assert(contains("ReplicatedFirst:RemoveDefaultLoadingScreen()"), "Replace the Roblox default screen")
assert(contains("ContentProvider:PreloadAsync"), "Warm the game icon and bolt assets")
assert(contains("task.spawn"), "Asset preload should run asynchronously")
assert(contains("game:IsLoaded()"), "Wait for Roblox's loaded state")
assert(contains("while not game:IsLoaded() do"), "Wait for the place before revealing the game")
assert(contains("os.clock() < characterDeadline"), "Character wait must have a deadline")
assert(contains("TweenService:Create") and contains("gui:Destroy()"), "Fade and clean up the screen")
assert(not contains("player.CharacterAdded:Wait()"), "A missing character must not hold the screen forever")
print("PASS source: pure black, clean game icon, dual-state vector SVG lightning bolts (crossfade white -> yellow), tips, loaded gate, surge and cleanup")

for world, filename in places do
	local place = roblox.deserializePlace(fs.readFile(filename))
	local node = place
	local entry
	for _, row in manifest.worlds[world].scripts do
		if row.source == sourcePath then
			assert(entry == nil, world .. " has duplicate manifest loading scripts")
			entry = row
		end
	end
	assert(entry, world .. " lacks the loading screen in the manifest")
	for _, segment in entry.segments do
		node = assert(node:FindFirstChild(segment), world .. " missing " .. segment)
	end
	assert(node:IsA("LocalScript"), world .. " loading screen must run on the client")
	assert(node.Source == source, world .. " embeds a stale loading screen")

	local replicatedFirst = assert(place:GetService("ReplicatedFirst"), world .. " missing ReplicatedFirst")
	local count = 0
	for _, descendant in replicatedFirst:GetDescendants() do
		if descendant.Name == "LoadingScreen" and descendant:IsA("LuaSourceContainer") then
			count += 1
		end
	end
	assert(count == 1, world .. " has " .. count .. " loading screen scripts")
	local starterGui = place:GetService("StarterGui")
	assert(not starterGui:FindFirstChild("SpeedsterLoadingScreen", true), world .. " has a static duplicate screen")
	print("PASS " .. world .. ": one current loading script, no static duplicate")
end
print("ALL TESTS PASSED SUCCESSFULLY!")
