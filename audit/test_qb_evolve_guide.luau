-- test_qb_evolve_guide.luau
-- The Evolve guide is taught once per account (2026-09-21). Before, its "seen" flag was a
-- client attribute only, so the full-screen guide came back on every join, world change and
-- rejoin while an evolution was waiting, and every respawn closed it and brought it back.
--   1. the profile keeps EvolveTutorialSeen / BackpackTutorialSeen: ProfileCodec default,
--      old save, round trip; ProfileReducers.ApplyPreference; Bootstrap's SettingsUpdate
--      allow-list run as it is; StatsProjection projects every Settings key;
--   2. Shared/TutorialGuide run in a mock HUD: MarkSeen fires SettingsUpdate once and never
--      when already seen; a respawn no longer closes the guide; 10 continuous seconds on
--      screen (a cinematic hiding it starts the count over) save the flag; Skip saves it, an
--      immediate close (nothing left to evolve) does not; the aura guide saves its own key;
--   3. UI/EvolveController: hasEvolvedBefore (extracted, real SuitCatalog), the guide loop's
--      gates (DataLoaded, hasEvolvedBefore, a live Humanoid, a pending portal flight), and
--      the panel's Evolve button saving through MarkSeen;
--   4. UI/WorldPortalCinematic: pump() extracted and run: WorldPortalCinematicPending is true
--      while a flight is owed (also while it waits for a guide) and false once it played.
--   lune run audit/test_qb_evolve_guide.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local rb = require("@lune/roblox")

local Codec = require("../src/common/ServerScriptService/Services/Data/ProfileCodec")
local Reducers = require("../src/common/ServerScriptService/Services/Data/ProfileReducers")
local Layout = require("../src/common/ReplicatedStorage/Shared/TutorialGuideLayout")
local SuitCatalog = require("../src/common/ReplicatedStorage/Shared/SuitCatalog")
-- 2026-09-22: the guide's words come from Shared/TutorialText (audit/test_i18n_rebirth_guide).
local TutorialText = require("../src/common/ReplicatedStorage/Shared/TutorialText")

local SHARED = "src/common/ReplicatedStorage/Shared/"
local GUIDE = SHARED .. "TutorialGuide.luau"
local EVOLVE = "src/common/StarterPlayer/StarterPlayerScripts/UI/EvolveController.client.luau"
local PORTAL = "src/common/StarterPlayer/StarterPlayerScripts/UI/WorldPortalCinematic.client.luau"
local AURA = "src/common/StarterPlayer/StarterPlayerScripts/UI/FirstTimeTutorial.client.luau"
local BOOTSTRAP = "src/common/ServerScriptService/Bootstrap.server.luau"
local PROJECTION = "src/common/ServerScriptService/Services/Stats/StatsProjection.luau"
local KEYS = { "EvolveTutorialSeen", "BackpackTutorialSeen" }

local function read(path)
	return (fs.readFile(path):gsub("\r\n", "\n"))
end
local function has(source, needle, message)
	assert(string.find(source, needle, 1, true), message)
end
local function between(source, first, last, message)
	local a = string.find(source, first, 1, true)
	assert(a, message .. ": start not found")
	local b = string.find(source, last, a + #first, true)
	assert(b, message .. ": end not found")
	return string.sub(source, a, b - 1)
end

-- Every changed source compiles.
for _, path in { GUIDE, EVOLVE, PORTAL, BOOTSTRAP, PROJECTION,
	"src/common/ServerScriptService/Services/Data/ProfileCodec.luau",
	"src/common/ServerScriptService/Services/Data/ProfileReducers.luau" } do
	local ok, problem = pcall(luau.compile, fs.readFile(path))
	assert(ok, "SYNTAX " .. path .. ": " .. tostring(problem))
end
print("PASS every changed source compiles")

----------------------------------------------------------------------
-- 1. The profile keeps the flags
----------------------------------------------------------------------
do
	local fresh = Codec.CreateDefault()
	for _, key in KEYS do
		assert(fresh.Settings[key] == false, "A new profile: " .. key .. " is false")
	end
	local old = Codec.Decode({ Version = 306, Speed = 1, Wins = 0, Settings = { Muted = true, TouchLayout = "" } })
	assert(old.ok, "An old save decodes")
	for _, key in KEYS do
		assert(old.value.Settings[key] == false, "An old save without " .. key .. " reads false")
	end
	assert(old.value.Settings.Muted == true, "...its other settings kept")
	for _, junk in { "true", 1, { true } } do
		local decoded = Codec.Decode({ Version = 306, Speed = 1, Wins = 0, Settings = { EvolveTutorialSeen = junk } })
		assert(decoded.ok and decoded.value.Settings.EvolveTutorialSeen == false, "A corrupt flag reads false")
	end
	local p = Codec.Decode(nil).value
	for _, key in KEYS do
		local r = Reducers.ApplyPreference(p, key, true)
		assert(r.ok and p.Settings[key] == true, "ApplyPreference keeps " .. key .. " = true")
	end
	local encoded = Codec.Encode(p)
	for _, key in KEYS do
		assert(encoded.Settings[key] == true, key .. " is written to the save")
	end
	local again = Codec.Decode(encoded)
	assert(again.ok, "Round trip decodes")
	for _, key in KEYS do
		assert(again.value.Settings[key] == true, key .. " survives a save and a rejoin")
	end
	-- The reducer refuses anything that is not a boolean, and unknown keys.
	local q = Codec.CreateDefault()
	for _, key in KEYS do
		for _, bad in { "true", 1, {} } do
			assert(not Reducers.ApplyPreference(q, key, bad).ok and q.Settings[key] == false, "ApplyPreference refuses " .. key .. " = " .. typeof(bad))
		end
	end
	assert(not Reducers.ApplyPreference(q, "EvolveTutorialSeenX", true).ok, "An unknown key is refused")
	assert(Reducers.ApplyPreference(q, "EvolveTutorialSeen", false).ok and q.Settings.EvolveTutorialSeen == false, "false is a boolean too")

	-- Bootstrap's SettingsUpdate handler, run as it is (same extraction as test_opt6_touch_layout).
	local bootstrap = read(BOOTSTRAP)
	local header = "RemoteGuard.Connect(SettingsUpdate, 0.05, function(player: Player, attrName: any, value: any)\n"
	local body = between(bootstrap, header, "\nend)\n\nRemoteGuard.Connect(UpdateLogClosed", "SettingsUpdate handler")
	body = string.sub(body, #header + 1)
	has(body, 'EvolveTutorialSeen = "boolean"', "allow-list has EvolveTutorialSeen as a boolean")
	has(body, 'BackpackTutorialSeen = "boolean"', "allow-list has BackpackTutorialSeen as a boolean")
	local profile = Codec.CreateDefault()
	local calls = {}
	local DataService = {
		GetHandle = function() return { userId = 1 } end,
		SetPreference = function(_, key, value)
			table.insert(calls, { key, value })
			return Reducers.ApplyPreference(profile, key, value)
		end,
	}
	local handler = luau.load("return function(player, attrName, value)\n" .. body .. "\nend", {
		environment = { DataService = DataService, type = type, math = math },
	})()
	local loaded = { UserId = 1, GetAttribute = function(_, name) return name == "DataLoaded" end }
	handler(loaded, "EvolveTutorialSeen", "true")
	handler(loaded, "BackpackTutorialSeen", 1)
	assert(#calls == 0, "Not a boolean: never reaches DataService")
	handler({ UserId = 1, GetAttribute = function() return false end }, "EvolveTutorialSeen", true)
	assert(#calls == 0, "Nothing before the profile has loaded")
	handler(loaded, "EvolveTutorialSeen", true)
	handler(loaded, "BackpackTutorialSeen", true)
	assert(#calls == 2 and profile.Settings.EvolveTutorialSeen == true and profile.Settings.BackpackTutorialSeen == true, "Both flags reach the profile")

	-- StatsProjection sends every setting as an attribute of the same name.
	local projection = read(PROJECTION)
	has(projection, "for settingKey, settingVal in pairs(profile.Settings) do\n\t\t\t\tsetAttributeIfChanged(player, settingKey, settingVal)", "Settings are projected to attributes")
	print("PASS profile: both flags default false (old saves too), the reducer and SettingsUpdate take booleans only, they survive a save and a rejoin and are projected as attributes")
end

----------------------------------------------------------------------
-- A small fake of the Roblox instances the guide touches (Lune instances have no
-- AbsoluteSize / AbsolutePosition and no events).
----------------------------------------------------------------------
local function newSignal()
	local signal = { handlers = {} }
	function signal:Connect(fn)
		table.insert(self.handlers, fn)
		return { Disconnect = function()
			local at = table.find(self.handlers, fn)
			if at then table.remove(self.handlers, at) end
		end }
	end
	function signal:Fire(...)
		for _, fn in table.clone(self.handlers) do fn(...) end
	end
	return signal
end

local IS = {
	Frame = { GuiObject = true }, ImageLabel = { GuiObject = true }, TextLabel = { GuiObject = true },
	TextButton = { GuiObject = true, GuiButton = true }, ScrollingFrame = { GuiObject = true },
	ScreenGui = { LayerCollector = true }, BoolValue = { ValueBase = true },
}
local store = {}
local FakeMethods = {}
local FakeMeta = {}
FakeMeta.__index = function(self, key)
	local method = FakeMethods[key]
	if method then return method end
	local props = store[self]
	if props[key] ~= nil then return props[key] end
	return FakeMethods.FindFirstChild(self, key)
end
FakeMeta.__newindex = function(self, key, value)
	local props = store[self]
	if key == "Parent" then
		local oldParent = props.Parent
		if oldParent then
			local list = store[oldParent].Children
			local at = table.find(list, self)
			if at then table.remove(list, at) end
		end
		if value then table.insert(store[value].Children, self) end
	end
	props[key] = value
end
function FakeMethods.IsA(self, class)
	local c = store[self].ClassName
	return c == class or (IS[c] ~= nil and IS[c][class] == true) or class == "Instance"
end
function FakeMethods.FindFirstChild(self, name, recursive)
	for _, child in store[self].Children do
		if store[child].Name == name then return child end
	end
	if recursive then
		for _, child in store[self].Children do
			local found = FakeMethods.FindFirstChild(child, name, true)
			if found then return found end
		end
	end
	return nil
end
function FakeMethods.WaitForChild(self, name) return FakeMethods.FindFirstChild(self, name) end
function FakeMethods.FindFirstChildOfClass(self, class)
	for _, child in store[self].Children do
		if store[child].ClassName == class then return child end
	end
	return nil
end
function FakeMethods.GetChildren(self) return table.clone(store[self].Children) end
function FakeMethods.IsDescendantOf(self, ancestor)
	local node = store[self].Parent
	while node do
		if node == ancestor then return true end
		node = store[node].Parent
	end
	return false
end
function FakeMethods.Destroy(self) self.Parent = nil end
function FakeMethods.GetAttribute(self, name) return store[self].Attributes[name] end
function FakeMethods.SetAttribute(self, name, value) store[self].Attributes[name] = value end

local function fake(class, props, parent)
	local obj = setmetatable({}, FakeMeta)
	store[obj] = {
		ClassName = class, Name = class, Visible = true, Enabled = true, DisplayOrder = 0,
		AbsoluteSize = rb.Vector2.new(844, 390), AbsolutePosition = rb.Vector2.new(0, 0),
		Position = rb.UDim2.new(), Children = {}, Attributes = {}, Activated = newSignal(),
	}
	for key, value in props or {} do obj[key] = value end
	if parent then obj.Parent = parent end
	return obj
end

-- A player with the HUD the guide points at (Mainhud, Backpack, Evolve).
local function newWorld(owned)
	local player = fake("Player", { Name = "Runner", CharacterAdded = newSignal() })
	local pg = fake("PlayerGui", { Name = "PlayerGui" }, player)
	local hud = fake("ScreenGui", { Name = "Mainhud" }, pg)
	local sidebar = fake("Frame", { Name = "LeftSideBar" }, hud)
	local button = { AbsoluteSize = rb.Vector2.new(60, 60), AbsolutePosition = rb.Vector2.new(10, 150) }
	fake("TextButton", { Name = "Evolve", AbsoluteSize = button.AbsoluteSize, AbsolutePosition = button.AbsolutePosition }, sidebar)
	fake("TextButton", { Name = "Backpack", AbsoluteSize = button.AbsoluteSize, AbsolutePosition = rb.Vector2.new(10, 80) }, sidebar)
	local backpack = fake("ScreenGui", { Name = "Backpack" }, pg)
	local main = fake("Frame", { Name = "MainFrame", Visible = false, Position = rb.UDim2.fromScale(0.5, 1.5) }, backpack)
	fake("TextButton", { Name = "Aura" }, main)
	fake("ScrollingFrame", { Name = "Aura", Visible = false }, main)
	local evolveGui = fake("ScreenGui", { Name = "Evolve" }, pg)
	local panel = fake("Frame", { Name = "Evolve", Visible = false, Position = rb.UDim2.fromScale(0.5, 1.5) }, evolveGui)
	fake("TextButton", { Name = "EvolveButton" }, panel)
	local data = fake("Folder", { Name = "SpeedsterData" }, player)
	local skins = fake("Folder", { Name = "OwnedSkins" }, data)
	for _, id in owned or { "FlashSuit" } do
		fake("BoolValue", { Name = id, Value = true }, skins)
	end
	return player, pg
end

----------------------------------------------------------------------
-- 2. Shared/TutorialGuide run in the mock
----------------------------------------------------------------------
local fired = {}
local renderStepped = newSignal()
local SettingsUpdate = { FireServer = function(_, key, value) table.insert(fired, { key, value }) end }
local Remotes = { FindFirstChild = function(_, name) return if name == "SettingsUpdate" then SettingsUpdate else nil end }
local services = {
	RunService = { RenderStepped = renderStepped },
	TweenService = { Create = function() return { Play = function() end, Cancel = function() end } end },
	ReplicatedStorage = { FindFirstChild = function(_, name) return if name == "Remotes" then Remotes else nil end },
}
local Guide = luau.load(fs.readFile(GUIDE), { debugName = "TutorialGuide", environment = {
	script = { Parent = { WaitForChild = function(_, name) return if name == "TutorialText" then TutorialText else Layout end } },
	require = function(module) return module end,
	game = { GetService = function(_, name) return assert(services[name], "no service " .. name) end },
	Instance = { new = function(class) return fake(class) end },
	Vector2 = rb.Vector2, UDim = rb.UDim, UDim2 = rb.UDim2, Color3 = rb.Color3, Enum = rb.Enum,
	ColorSequence = rb.ColorSequence, ColorSequenceKeypoint = rb.ColorSequenceKeypoint, TweenInfo = { new = function() return {} end },
	task = { delay = function(_, fn) fn() end, spawn = function(fn) fn() end },
	math = math, os = os, table = table, string = string, tostring = tostring, tonumber = tonumber,
	pcall = pcall, ipairs = ipairs, pairs = pairs, type = type, typeof = typeof, print = print,
} })()

local function frames(count, dt)
	for _ = 1, count do renderStepped:Fire(dt) end
end
local function seenFires(key)
	local n = 0
	for _, call in fired do
		if call[1] == key then
			assert(call[2] == true, "only true is ever sent")
			n += 1
		end
	end
	return n
end

do
	-- MarkSeen on its own: once, and never when already seen.
	local player = newWorld()
	assert(Guide.MarkSeen(player, "Evolve") == true and #fired == 1 and fired[1][1] == "EvolveTutorialSeen", "MarkSeen fires SettingsUpdate once")
	assert(player:GetAttribute("EvolveTutorialSeen") == true, "...and sets the attribute locally")
	assert(Guide.MarkSeen(player, "Evolve") == false and #fired == 1, "Already seen: nothing is sent")
	local veteran = newWorld()
	veteran:SetAttribute("BackpackTutorialSeen", true) -- projected from the profile
	assert(Guide.MarkSeen(veteran, "Backpack") == false and #fired == 1, "A saved flag: nothing is sent")
	assert(Guide.MarkSeen(veteran, "Nope") == false and #fired == 1, "An unknown guide: nothing is sent")
	table.clear(fired)
	-- A player still in the game gets the flag sent again (the test's task.delay runs at once):
	-- the server's RemoteGuard may have dropped the first one. One who left gets nothing more.
	local inGame = newWorld()
	inGame.Parent = fake("Players", { Name = "Players" })
	assert(Guide.MarkSeen(inGame, "Evolve") == true, "MarkSeen in game")
	assert(seenFires("EvolveTutorialSeen") == 1 + #Guide.SEEN_RESEND_AFTER and #Guide.SEEN_RESEND_AFTER >= 2,
		"The flag is sent again " .. #Guide.SEEN_RESEND_AFTER .. " times")
	assert(Guide.MarkSeen(inGame, "Evolve") == false and seenFires("EvolveTutorialSeen") == 1 + #Guide.SEEN_RESEND_AFTER, "...and never again once seen")
	table.clear(fired)
end

do
	-- The Evolve guide: a respawn keeps it, 10 s on screen save it, Skip then sends nothing more.
	local player, pg = newWorld()
	player:SetAttribute("EvolveGuideTarget", "ReverseSpeedsterSuit")
	player:SetAttribute("EvolveAvailableCount", 1)
	assert(Guide.Start(player, nil, "Evolve") == true, "The Evolve guide starts")
	assert(player:GetAttribute("GuidedTutorialOpen") == true and Guide.IsOpen(), "GuidedTutorialOpen while it is up")
	assert(#player.CharacterAdded.handlers == 0, "The guide no longer listens for a respawn")
	player.CharacterAdded:Fire(fake("Model"))
	frames(1, 0.5)
	assert(Guide.IsOpen() and pg:FindFirstChild("SpeedsterGuidedSpotlight") and pg:FindFirstChild("SpeedsterGuidedDimmer"), "A respawn does not close the guide")
	assert(pg.SpeedsterGuidedSpotlight:FindFirstChild("InstructionCard", true).Visible == true, "The card is on screen")
	frames(9, 0.5) -- 5 s
	-- A cinematic hides the guide (InterfaceHider turns its ScreenGuis off): the count starts over.
	pg.SpeedsterGuidedSpotlight.Enabled = false
	frames(1, 0.5)
	pg.SpeedsterGuidedSpotlight.Enabled = true
	frames(19, 0.5) -- 9.5 s since it came back
	assert(#fired == 0, "Not yet 10 continuous seconds: nothing saved")
	frames(1, 0.5)
	assert(seenFires("EvolveTutorialSeen") == 1 and player:GetAttribute("EvolveTutorialSeen") == true, "10 s on screen: saved once")
	assert(Guide.IsOpen(), "...and the guide stays up")
	frames(40, 0.5)
	assert(#fired == 1, "Saved only once")
	pg.SpeedsterGuidedSpotlight:FindFirstChild("Skip", true).Activated:Fire()
	assert(#fired == 1, "Skip after it was saved sends nothing more")
	assert(not Guide.IsOpen() and player:GetAttribute("GuidedTutorialOpen") == false, "Skip closes it and clears GuidedTutorialOpen")
	assert(pg:FindFirstChild("SpeedsterGuidedSpotlight") == nil and pg:FindFirstChild("SpeedsterGuidedDimmer") == nil, "Nothing is left behind")
	table.clear(fired)
end

do
	-- Skip at once: saved once. An immediate close (nothing left to evolve): not saved.
	local player, pg = newWorld()
	player:SetAttribute("EvolveGuideTarget", "ReverseSpeedsterSuit")
	player:SetAttribute("EvolveAvailableCount", 1)
	assert(Guide.Start(player, nil, "Evolve"))
	frames(2, 0.5)
	pg.SpeedsterGuidedSpotlight:FindFirstChild("Skip", true).Activated:Fire()
	assert(seenFires("EvolveTutorialSeen") == 1 and #fired == 1, "Skip saves the flag once")
	table.clear(fired)

	local other = newWorld()
	other:SetAttribute("EvolveGuideTarget", "ReverseSpeedsterSuit")
	other:SetAttribute("EvolveAvailableCount", 1)
	assert(Guide.Start(other, nil, "Evolve"))
	frames(2, 0.5)
	other:SetAttribute("EvolveAvailableCount", 0) -- a rebirth reset the level
	frames(1, 0.5)
	assert(not Guide.IsOpen() and #fired == 0 and other:GetAttribute("EvolveTutorialSeen") == nil, "Nothing left to evolve: closed, not saved")

	-- The aura guide saves its own key.
	local newbie, newbiePg = newWorld()
	assert(Guide.Start(newbie, nil) == true, "The aura guide starts")
	frames(2, 0.5)
	newbiePg.SpeedsterGuidedSpotlight:FindFirstChild("Skip", true).Activated:Fire()
	assert(seenFires("BackpackTutorialSeen") == 1 and #fired == 1, "Skipping the aura guide saves BackpackTutorialSeen")
	table.clear(fired)
end

do
	-- CloseIfSeen (the portal flight's way past an ignored guide): only a guide already saved gives way.
	local player, pg = newWorld()
	player:SetAttribute("EvolveGuideTarget", "ReverseSpeedsterSuit")
	player:SetAttribute("EvolveAvailableCount", 1)
	assert(Guide.CloseIfSeen(player) == false, "No guide open: nothing to close")
	assert(Guide.Start(player, nil, "Evolve"))
	frames(4, 0.5) -- 2 s: not saved yet
	assert(Guide.CloseIfSeen(player) == false and Guide.IsOpen(), "A guide not yet saved keeps the screen")
	frames(17, 0.5) -- past 10 s on screen: saved
	assert(player:GetAttribute("EvolveTutorialSeen") == true and Guide.IsOpen(), "Saved after 10 s and still up")
	assert(Guide.CloseIfSeen(player) == true, "A saved guide gives way")
	assert(not Guide.IsOpen() and player:GetAttribute("GuidedTutorialOpen") == false, "...closed at once, GuidedTutorialOpen cleared")
	assert(pg:FindFirstChild("SpeedsterGuidedSpotlight") == nil and pg:FindFirstChild("SpeedsterGuidedDimmer") == nil, "...and nothing left behind")
	assert(seenFires("EvolveTutorialSeen") == 1, "The flag was sent once, by the 10 s rule")
	table.clear(fired)
	print("PASS TutorialGuide.CloseIfSeen: a saved guide gives way to the portal flight at once; an unsaved one keeps the screen")
end

do
	local source = read(GUIDE)
	assert(not source:find("CharacterAdded", 1, true), "TutorialGuide must not close on CharacterAdded")
	assert(not source:find("a respawn, another", 1, true), "The stale respawn comment is gone")
	-- The aura loop never starts a second guide over an open one (a respawn now keeps it up).
	local aura = read(AURA)
	has(aura, 'GuideOpen = player:GetAttribute("GuidedTutorialOpen")', "the aura loop checks GuidedTutorialOpen")
	has(aura, "if canShowAuraGuide() then\n\t\t\t\tguide.Start(player, playCompleteSound)", "the aura loop starts the guide only through canShowAuraGuide")
	print("PASS TutorialGuide: MarkSeen sends once and never when seen; a respawn keeps the guide; 10 continuous seconds on screen save it (a hide starts over); Skip saves, an immediate close does not; the aura guide saves its own key; nothing left behind")
end

----------------------------------------------------------------------
-- 3. UI/EvolveController
----------------------------------------------------------------------
do
	local source = read(EVOLVE)
	local chunk = between(source, "local EVOLVE_CHAIN_IDS = {}", "-- end hasEvolvedBefore", "hasEvolvedBefore")
	local function evolvedBefore(owned)
		local player = newWorld(owned)
		return luau.load(chunk .. "\nreturn hasEvolvedBefore", { environment = {
			SuitCatalog = SuitCatalog, player = player, ipairs = ipairs,
		} })()()
	end
	assert(SuitCatalog.DefaultSkinId == "FlashSuit" and SuitCatalog.Ordered[2].Id == "ReverseSpeedsterSuit", "catalog ids as expected")
	local limitedId = SuitCatalog.Limited[1].Id
	assert(limitedId == "DarkZonicSuit", "a Limited suit")
	assert(evolvedBefore({ "FlashSuit" }) == false, "{FlashSuit}: never evolved")
	assert(evolvedBefore({ "FlashSuit", "ReverseSpeedsterSuit" }) == true, "{FlashSuit, ReverseSpeedsterSuit}: evolved before")
	assert(evolvedBefore({ "FlashSuit", limitedId }) == false, "{FlashSuit, DarkZonicSuit}: a Limited suit is not an evolve")
	assert(evolvedBefore({ "FlashSuit", SuitCatalog.Exclusive[1].Id }) == false, "an Exclusive suit is not an evolve")
	assert(evolvedBefore({}) == false, "nothing owned yet")

	local loop = between(source, "task.spawn(function()\n    local offered = false", "\nend)\n", "guide loop")
	for _, needle in {
		'player:GetAttribute("DataLoaded") == true',
		"not hasEvolvedBefore()",
		"humanoid.Health > 0",
		'player:GetAttribute("WorldPortalCinematicPending") ~= true',
		'player:GetAttribute("WorldPortalCinematicActive") ~= true',
		'player:GetAttribute("EvolveTutorialSeen") ~= true',
		'player:GetAttribute("GuidedTutorialOpen") ~= true',
	} do
		has(loop, needle, "the Evolve guide loop checks " .. needle)
	end
	assert(not source:find('pcall(function() player:SetAttribute("EvolveTutorialSeen", true) end)', 1, true), "the session-only SetAttribute is gone")
	local button = between(source, "evolveButton.Activated:Connect(function()", "\nend)\n", "Evolve button")
	has(button, 'require(ReplicatedStorage.Shared.TutorialGuide).MarkSeen(player, "Evolve")', "an evolve from the panel saves the flag")
	-- The "!" badge still reads EvolveAvailableCount, written by refreshOpportunity.
	has(source, 'player:SetAttribute("EvolveAvailableCount", count)', "the badge count is still written")
	print("PASS EvolveController: hasEvolvedBefore counts only evolve-chain suits past FlashSuit; the loop waits for DataLoaded, a live character and no pending portal flight; the panel's Evolve saves through MarkSeen")
end

----------------------------------------------------------------------
-- 4. UI/WorldPortalCinematic: the pending flag, pump() run as it is
----------------------------------------------------------------------
do
	local source = read(PORTAL)
	local chunk = between(source, "local gate = Shot.NewGate()", "player:GetAttributeChangedSignal(UNLOCK_ATTRIBUTE):Connect(observe)", "portal pump")
	local Shot = luau.load(fs.readFile(SHARED .. "WorldPortalShot.luau"), { environment = {
		Vector3 = rb.Vector3, math = math, table = table, ipairs = ipairs, pairs = pairs, type = type,
	} })()
	local attrs = { World2Unlocked = false, GuidedTutorialOpen = true }
	local humanoid = { Health = 100 }
	local root = { Position = rb.Vector3.new(0, 0, 0) } -- far from the W1 portal
	local character = {
		FindFirstChild = function(_, name) return if name == "HumanoidRootPart" then root else nil end,
		FindFirstChildOfClass = function() return humanoid end,
	}
	local player = {
		Character = character,
		GetAttribute = function(_, name) return attrs[name] end,
		SetAttribute = function(_, name, value) attrs[name] = value end,
	}
	local seenWhileWaiting, seenWhilePlaying, played = nil, nil, 0
	local waits = 0
	local run = luau.load(chunk .. "\nreturn observe, function(v) dataReady = v end", { environment = {
		Shot = Shot, player = player, CURRENT_WORLD = 1, TARGET_WORLD = 2, UNLOCK_ATTRIBUTE = "World2Unlocked",
		PlayerGui = { FindFirstChild = function() return nil end },
		InterfaceHider = { IsHidden = function() return false end, Show = function() end },
		-- The guide here is not saved yet, so it keeps the screen until it closes (task.wait below).
		TutorialGuide = { CloseIfSeen = function() return false end },
		playCinematic = function()
			played += 1
			seenWhilePlaying = attrs.WorldPortalCinematicPending
		end,
		task = {
			spawn = function(fn) fn() end,
			wait = function()
				waits += 1
				seenWhileWaiting = attrs.WorldPortalCinematicPending
				attrs.GuidedTutorialOpen = false -- the guide closes: the flight can play
			end,
		},
		os = os, pcall = pcall, warn = warn, tostring = tostring,
	} })
	local observe, setDataReady = run()
	setDataReady(true)
	observe() -- the baseline: still locked
	assert(attrs.WorldPortalCinematicPending == nil, "Nothing pending at the baseline")
	attrs.World2Unlocked = true
	observe() -- the server unlocks World 2 while the runner plays
	assert(waits == 1 and seenWhileWaiting == true, "While the flight waits for an open guide, WorldPortalCinematicPending is true")
	assert(played == 1 and seenWhilePlaying ~= nil, "The flight plays once the guide is gone")
	assert(attrs.WorldPortalCinematicPending == false, "Played: WorldPortalCinematicPending is false again")
	print("PASS WorldPortalCinematic: WorldPortalCinematicPending is true while the flight is owed (also while it waits for a guide) and false once it played")
end
