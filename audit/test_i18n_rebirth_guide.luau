-- audit/test_i18n_rebirth_guide.luau  (2026-09-22)
-- "There must be a tutorial for rebirths too, and the language must be universal." Runs the REAL
-- modules and sources:
--   1. Shared/TutorialText: every key in all 10 languages, none empty, none left in English,
--      numbers/multipliers and line breaks kept, short enough for the card; LanguageFor on real
--      Roblox locale ids; ForPlayer's fallbacks (LocalizationService on the client, then
--      Player.LocaleId, then English) and its per-session cache; Get never errors; the font for
--      Russian/Arabic/Thai;
--   2. Shared/TutorialGuide mode "Rebirth" in a fake HUD: step 1 rings the sidebar Rebirth button,
--      step 2 the panel's free Rebirth button (not RebirthBuy); a rebirth celebrates and saves
--      RebirthTutorialSeen once; Skip saves; 10 s on screen saves; CloseIfSeen closes a saved one;
--      losing the rebirth closes it unsaved (a short dip does not); no guide for one who cannot
--      rebirth; a Spanish player reads Spanish (AutoLocalize off); Evolve and the aura guide still
--      read their English texts for "en";
--   3. RebirthTutorialSeen persists like EvolveTutorialSeen: ProfileCodec, ProfileReducers,
--      Bootstrap's SettingsUpdate allow-list (run as it is), StatsProjection;
--   4. UI/RebirthController: the gate (extracted with the real getters) and the loop (2 s quiet,
--      offered once, offered again after a teardown, never once seen);
--   5. UI/FirstTimeTutorial: AuraGuidePending (extracted, real TutorialFlow) and the step labels'
--      keys.
--   The priority rules (Step 2, the aura grace) run end to end in audit/test_polish_rebirth_guide.
--   lune run audit/test_i18n_rebirth_guide.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local rb = require("@lune/roblox")

local Codec = require("../src/common/ServerScriptService/Services/Data/ProfileCodec")
local Reducers = require("../src/common/ServerScriptService/Services/Data/ProfileReducers")
local Layout = require("../src/common/ReplicatedStorage/Shared/TutorialGuideLayout")
local TutorialText = require("../src/common/ReplicatedStorage/Shared/TutorialText")
local TutorialFlow = require("../src/common/ReplicatedStorage/Shared/TutorialFlow")

local SHARED = "src/common/ReplicatedStorage/Shared/"
local TEXT = SHARED .. "TutorialText.luau"
local GUIDE = SHARED .. "TutorialGuide.luau"
local REBIRTH = "src/common/StarterPlayer/StarterPlayerScripts/UI/RebirthController.client.luau"
local FIRST = "src/common/StarterPlayer/StarterPlayerScripts/UI/FirstTimeTutorial.client.luau"
local EVOLVE = "src/common/StarterPlayer/StarterPlayerScripts/UI/EvolveController.client.luau"
local BOOTSTRAP = "src/common/ServerScriptService/Bootstrap.server.luau"
local PROJECTION = "src/common/ServerScriptService/Services/Stats/StatsProjection.luau"
local CODEC = "src/common/ServerScriptService/Services/Data/ProfileCodec.luau"
local REDUCERS = "src/common/ServerScriptService/Services/Data/ProfileReducers.luau"

local passed = 0
local function pass(text)
	passed += 1
	print("PASS " .. text)
end
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

for _, path in { TEXT, GUIDE, REBIRTH, FIRST, EVOLVE, BOOTSTRAP, CODEC, REDUCERS } do
	local ok, problem = pcall(luau.compile, fs.readFile(path))
	assert(ok, "SYNTAX " .. path .. ": " .. tostring(problem))
end
pass("every changed source compiles")

----------------------------------------------------------------------
-- 1. Shared/TutorialText
----------------------------------------------------------------------
local LANGS = { "en", "es", "pt", "ru", "ar", "id", "fr", "de", "th", "tr" }
do
	assert(#TutorialText.Languages == #LANGS, "10 languages")
	for index, lang in LANGS do
		assert(TutorialText.Languages[index] == lang, "language list: " .. lang)
		assert(type(TutorialText.Strings[lang]) == "table", "no strings for " .. lang)
	end
	local en = TutorialText.Strings.en
	local keys = {}
	for key in en do table.insert(keys, key) end
	table.sort(keys)
	assert(#keys >= 25, "expected every tutorial string, got " .. #keys)
	local longest = {}
	for _, lang in LANGS do
		local strings = TutorialText.Strings[lang]
		for key in strings do
			assert(en[key] ~= nil, lang .. " has a key English lacks: " .. key)
		end
		for _, key in keys do
			local text = strings[key]
			assert(type(text) == "string" and text:match("%S"), lang .. "." .. key .. " is missing or empty")
			if lang ~= "en" then
				assert(text ~= en[key], lang .. "." .. key .. " is still English: " .. text)
			end
			-- Numbers and multipliers stay as they are.
			for _, token in { "x1.5", "2.5x", "10" } do
				if string.find(en[key], token, 1, true) then
					assert(string.find(text, token, 1, true), lang .. "." .. key .. " lost " .. token)
				end
			end
			-- The line breaks the card was laid out for.
			local _, breaks = string.gsub(text, "\n", "")
			local _, enBreaks = string.gsub(en[key], "\n", "")
			assert(breaks == enBreaks, lang .. "." .. key .. " has " .. breaks .. " line breaks, English " .. enBreaks)
			-- Short game-UI lines: a title on one line, a message on the plate.
			local length = utf8.len(text) or #text
			local isTitle = key:find("Title", 1, true) or key == "NiceJob" or key == "Skip" or key:sub(1, 4) == "Step"
			local limit = if isTitle then 24 else 64
			assert(length <= limit, ("%s.%s is %d characters (limit %d): %s"):format(lang, key, length, limit, text))
			if not longest[lang] or length > longest[lang] then longest[lang] = length end
		end
	end
	-- The wording the guides show for English is the wording they showed before this pass.
	for key, text in {
		Skip = "Skip guide", NiceJob = "NICE JOB!", AuraTitle1 = "YOUR FIRST AURA", AuraMsg1 = "Tap the backpack button",
		AuraOpen = "Open your backpack to continue", EvolveTitle1 = "READY TO EVOLVE!", EvolveOpen = "Open Evolve to continue",
		EvolveDone = "New suit unlocked!\nKeep training to get faster!", AuraDone = "Aura equipped!\nEnjoy your 2.5x speed!",
		AuraMsgGet = "Get Orange Aura for 10 Wins", AuraMsgEquip = "Tap Equip for 2.5x speed!",
		StepTrain = "TRAIN HERE!", StepClaimWins = "CLAIM YOUR WINS!",
	} do
		assert(en[key] == text, "English " .. key .. " changed: " .. tostring(en[key]))
	end
	assert(en.RebirthMsg2:find("x1.5", 1, true) and en.RebirthMsg2:lower():find("reset", 1, true), "step 2 says Speed resets for x1.5 forever")
	-- Scripts are what they claim to be.
	assert(TutorialText.Strings.ru.RebirthTitle2:find("[\208\209]"), "Russian is Cyrillic")
	assert(TutorialText.Strings.ar.RebirthTitle2:find("[\216\217]"), "Arabic is Arabic")
	assert(TutorialText.Strings.th.RebirthTitle2:find("\224\184"), "Thai is Thai")
	assert(TutorialText.Strings.es.RebirthTitle1:find("REBIRTH", 1, true), "Spanish keeps the word Rebirth")
	pass(("TutorialText: %d keys x 10 languages, none empty or left in English, tokens and line breaks kept, titles <= 24 and messages <= 64 characters"):format(#keys))

	-- LanguageFor on real Roblox locale ids.
	for locale, want in {
		["en-us"] = "en", ["en-gb"] = "en", ["es-es"] = "es", ["es-mx"] = "es", ["pt-br"] = "pt", ["pt-pt"] = "pt",
		["ru-ru"] = "ru", ["ar-001"] = "ar", ["id-id"] = "id", ["fr-fr"] = "fr", ["fr-ca"] = "fr", ["de-de"] = "de",
		["th-th"] = "th", ["tr-tr"] = "tr", ["ES-MX"] = "es", ["zh-cn"] = "en", ["ja-jp"] = "en", ["ko-kr"] = "en",
		["vi-vn"] = "en", ["it-it"] = "en", ["pl-pl"] = "en", [""] = "en", ["e"] = "en", ["pt"] = "pt",
	} do
		assert(TutorialText.LanguageFor(locale) == want, ("LanguageFor(%q) = %s, want %s"):format(locale, TutorialText.LanguageFor(locale), want))
	end
	for _, junk in { nil, 5, {}, true } do
		assert(TutorialText.LanguageFor(junk) == "en", "LanguageFor(" .. typeof(junk) .. ") must be en")
	end

	-- Get: English when a language lacks a key, the key itself when English does too; never errors.
	assert(TutorialText.Get("RebirthTitle1", "es") == TutorialText.Strings.es.RebirthTitle1)
	assert(TutorialText.Get("RebirthTitle1", "xx") == en.RebirthTitle1, "unknown language: English")
	assert(TutorialText.Get("RebirthTitle1", nil) == en.RebirthTitle1, "no language: English")
	assert(TutorialText.Get("NoSuchKey", "de") == "NoSuchKey", "unknown key: the key")
	assert(TutorialText.Get(nil, "de") == "nil", "nil key: no error")
	local saved = TutorialText.Strings.fr.Skip
	TutorialText.Strings.fr.Skip = nil
	assert(TutorialText.Get("Skip", "fr") == en.Skip, "a key missing in French falls back to English")
	TutorialText.Strings.fr.Skip = saved

	-- ForPlayer (the real module, required here with no `game`): Player.LocaleId, then English.
	TutorialText._ClearCache()
	local brazilian = { LocaleId = "pt-br" }
	assert(TutorialText.ForPlayer(brazilian) == "pt", "Player.LocaleId pt-br -> pt")
	brazilian.LocaleId = "de-de"
	assert(TutorialText.ForPlayer(brazilian) == "pt", "cached for the session")
	local broken = setmetatable({}, { __index = function() error("no LocaleId here") end })
	assert(TutorialText.ForPlayer(broken) == "en", "a LocaleId that errors -> en")
	assert(TutorialText.ForPlayer(nil) == "en", "no player -> en")
	assert(TutorialText.ForPlayer({ LocaleId = 42 }) == "en", "a junk LocaleId -> en")

	-- On the client LocalizationService.RobloxLocaleId (the Roblox language) wins over Player.LocaleId;
	-- on the server (or when the service fails) Player.LocaleId is used.
	local source = fs.readFile(TEXT)
	local function loadText(isClient, robloxLocale, failService)
		local services = {
			RunService = { IsClient = function() return isClient end },
			LocalizationService = { RobloxLocaleId = robloxLocale },
		}
		return luau.load(source, { debugName = "TutorialText", environment = {
			game = { GetService = function(_, name)
				if failService then error("service unavailable") end
				return services[name]
			end },
			Font = rb.Font, Enum = rb.Enum,
			setmetatable = setmetatable, pcall = pcall, type = type, tostring = tostring, string = string,
			table = table, error = error,
		} })()
	end
	assert(loadText(true, "es-mx").ForPlayer({ LocaleId = "en-us" }) == "es", "client: RobloxLocaleId es-mx -> es")
	assert(loadText(true, "ar-001").ForPlayer({ LocaleId = "en-us" }) == "ar", "client: RobloxLocaleId ar-001 -> ar")
	assert(loadText(true, "").ForPlayer({ LocaleId = "tr-tr" }) == "tr", "client: empty RobloxLocaleId -> Player.LocaleId")
	assert(loadText(false, "ru-ru").ForPlayer({ LocaleId = "id-id" }) == "id", "server: Player.LocaleId")
	assert(loadText(true, "ru-ru", true).ForPlayer({ LocaleId = "fr-fr" }) == "fr", "service error -> Player.LocaleId")
	assert(loadText(true, nil, true).ForPlayer({}) == "en", "nothing at all -> en")

	-- The font: Builder Sans ExtraBold for the scripts FredokaOne lacks, FredokaOne kept otherwise.
	local WithFont = loadText(true, "en-us")
	for _, lang in { "ru", "ar", "th" } do
		local face = WithFont.FontFor(lang)
		assert(face and face.Family:find("BuilderSans", 1, true) and face.Weight == rb.Enum.FontWeight.ExtraBold, lang .. " font")
	end
	for _, lang in { "en", "es", "pt", "id", "fr", "de", "tr", "xx" } do
		assert(WithFont.FontFor(lang) == nil, lang .. " keeps FredokaOne")
	end
	local label = rb.Instance.new("TextLabel")
	label.FontFace = rb.Font.fromEnum(rb.Enum.Font.FredokaOne)
	WithFont.Style(label, "es")
	assert(label.AutoLocalize == false and label.FontFace.Family:find("Fredoka", 1, true), "Style(es): AutoLocalize off, FredokaOne kept")
	WithFont.Style(label, "ru")
	assert(label.FontFace.Family:find("BuilderSans", 1, true), "Style(ru): Builder Sans")
	-- Nothing at require time: loadText(.., failService) above required it with every service failing.
	pass("TutorialText: LanguageFor maps real locale ids, ForPlayer falls back RobloxLocaleId -> LocaleId -> en and caches, Get never errors, ru/ar/th get Builder Sans ExtraBold")
end

----------------------------------------------------------------------
-- A small fake of the Roblox instances the guide touches (as audit/test_qb_evolve_guide).
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
	TextButton = { GuiObject = true, GuiButton = true }, ImageButton = { GuiObject = true, GuiButton = true },
	ScrollingFrame = { GuiObject = true }, ScreenGui = { LayerCollector = true }, BoolValue = { ValueBase = true },
	IntValue = { ValueBase = true },
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

local SIDEBAR_REBIRTH = rb.Vector2.new(80, 150)
local PANEL_REBIRTH = rb.Vector2.new(300, 300)
local PANEL_BUY = rb.Vector2.new(450, 300)
local CLOSED = rb.UDim2.new(0.5, 0, 1.28, 0)
local OPEN = rb.UDim2.new(0.5, 0, 0.48, 0)

-- A player with the HUD the guides point at: Mainhud's sidebar, Backpack, Evolve and Rebirth
-- (built as the places have them: Rebirth.Rebirth holds the free "Rebirth" and the Robux "RebirthBuy").
local function newWorld(attributes, locale)
	local player = fake("Player", { Name = "Runner", CharacterAdded = newSignal(), LocaleId = locale })
	for key, value in attributes or {} do player:SetAttribute(key, value) end
	local pg = fake("PlayerGui", { Name = "PlayerGui" }, player)
	local hud = fake("ScreenGui", { Name = "Mainhud" }, pg)
	local sidebar = fake("Frame", { Name = "LeftSideBar" }, hud)
	local size = rb.Vector2.new(60, 60)
	fake("ImageButton", { Name = "Evolve", AbsoluteSize = size, AbsolutePosition = rb.Vector2.new(10, 150) }, sidebar)
	fake("ImageButton", { Name = "Backpack", AbsoluteSize = size, AbsolutePosition = rb.Vector2.new(10, 80) }, sidebar)
	local sidebarRebirth = fake("ImageButton", { Name = "Rebirth", AbsoluteSize = size, AbsolutePosition = SIDEBAR_REBIRTH }, sidebar)
	fake("ImageLabel", { Name = "Rebirth" }, sidebarRebirth) -- its icon, not a button
	local backpack = fake("ScreenGui", { Name = "Backpack" }, pg)
	local main = fake("Frame", { Name = "MainFrame", Visible = false, Position = rb.UDim2.fromScale(0.5, 1.5) }, backpack)
	fake("TextButton", { Name = "Aura" }, main)
	fake("ScrollingFrame", { Name = "Aura", Visible = false }, main)
	local evolveGui = fake("ScreenGui", { Name = "Evolve" }, pg)
	local evolvePanel = fake("Frame", { Name = "Evolve", Visible = false, Position = rb.UDim2.fromScale(0.5, 1.5) }, evolveGui)
	fake("TextButton", { Name = "EvolveButton" }, evolvePanel)
	local rebirthGui = fake("ScreenGui", { Name = "Rebirth", Enabled = false }, pg)
	local panel = fake("Frame", { Name = "Rebirth", Visible = false, Position = CLOSED }, rebirthGui)
	fake("ImageLabel", { Name = "Icon" }, panel)
	fake("ImageButton", { Name = "RebirthBuy", AbsoluteSize = rb.Vector2.new(120, 50), AbsolutePosition = PANEL_BUY }, panel)
	fake("ImageButton", { Name = "Rebirth", AbsoluteSize = rb.Vector2.new(120, 50), AbsolutePosition = PANEL_REBIRTH }, panel)
	local data = fake("Folder", { Name = "SpeedsterData" }, player)
	local skins = fake("Folder", { Name = "OwnedSkins" }, data)
	fake("BoolValue", { Name = "FlashSuit", Value = true }, skins)
	local function openPanel(open)
		-- RebirthController.openPanel/closePanel: the ScreenGui on, the frame shown, slid to 0.48.
		rebirthGui.Enabled = open
		panel.Visible = open
		panel.Position = if open then OPEN else CLOSED
	end
	return player, pg, openPanel
end

----------------------------------------------------------------------
-- 2. Shared/TutorialGuide, mode "Rebirth", in the fake HUD
----------------------------------------------------------------------
local fired = {}
local delayed = {}
local renderStepped = newSignal()
local SettingsUpdate = { FireServer = function(_, key, value) table.insert(fired, { key, value }) end }
local Remotes = { FindFirstChild = function(_, name) return if name == "SettingsUpdate" then SettingsUpdate else nil end }
local services = {
	RunService = { RenderStepped = renderStepped },
	TweenService = { Create = function() return { Play = function() end, Cancel = function() end } end },
	ReplicatedStorage = { FindFirstChild = function(_, name) return if name == "Remotes" then Remotes else nil end },
}
local SIBLINGS = { TutorialGuideLayout = Layout, TutorialText = TutorialText }
local Guide = luau.load(fs.readFile(GUIDE), { debugName = "TutorialGuide", environment = {
	script = { Parent = { WaitForChild = function(_, name) return assert(SIBLINGS[name], "no sibling " .. name) end } },
	require = function(module) return module end,
	game = { GetService = function(_, name) return assert(services[name], "no service " .. name) end },
	Instance = { new = function(class) return fake(class) end },
	Vector2 = rb.Vector2, UDim = rb.UDim, UDim2 = rb.UDim2, Color3 = rb.Color3, Enum = rb.Enum,
	ColorSequence = rb.ColorSequence, ColorSequenceKeypoint = rb.ColorSequenceKeypoint, TweenInfo = { new = function() return {} end },
	task = { delay = function(_, fn) table.insert(delayed, fn) end, spawn = function(fn) fn() end },
	math = math, os = os, table = table, string = string, tostring = tostring, tonumber = tonumber,
	pcall = pcall, ipairs = ipairs, pairs = pairs, type = type, typeof = typeof, print = print,
} })()

local function flush()
	while #delayed > 0 do
		local list = delayed
		delayed = {}
		for _, fn in list do fn() end
	end
end
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
local function card(pg)
	local spot = pg:FindFirstChild("SpeedsterGuidedSpotlight")
	return spot and spot:FindFirstChild("InstructionCard", true)
end
local function ringAt(pg)
	local ring = pg.SpeedsterGuidedSpotlight:FindFirstChild("HighlightRing", true)
	return ring.Visible and ring.Position.X.Offset, ring.Position.Y.Offset
end

local READY = { Level = 5, NextRebirthLevelRequired = 5, Rebirths = 0 }
local EN = TutorialText.Strings.en
local ES = TutorialText.Strings.es

do
	-- The two steps and the celebration.
	local player, pg, openPanel = newWorld(READY)
	local completed = 0
	assert(Guide.Start(player, function() completed += 1 end, "Rebirth") == true, "the Rebirth guide starts")
	assert(player:GetAttribute("GuidedTutorialOpen") == true and Guide.IsOpen(), "GuidedTutorialOpen while it is up")
	frames(1, 0.1)
	local c = card(pg)
	assert(c and c.Visible, "the card is on screen")
	assert(c:FindFirstChild("Icon").Image == "rbxassetid://129578402198506", "the card wears the sidebar Rebirth icon")
	assert(c:FindFirstChild("Step1") and c:FindFirstChild("Step2") and not c:FindFirstChild("Step3"), "two step pills")
	local x, y = ringAt(pg)
	assert(x == SIDEBAR_REBIRTH.X - 6 and y == SIDEBAR_REBIRTH.Y - 6, ("step 1 rings the sidebar Rebirth button, got %s,%s"):format(tostring(x), tostring(y)))
	assert(c:FindFirstChild("Title", true).Text == EN.RebirthTitle1 and c:FindFirstChild("Message", true).Text == EN.RebirthMsg1, "step 1 texts")
	openPanel(true)
	frames(1, 0.1)
	x, y = ringAt(pg)
	assert(x == PANEL_REBIRTH.X - 6 and y == PANEL_REBIRTH.Y - 6, "step 2 rings the panel's free Rebirth button, not RebirthBuy")
	assert(x ~= PANEL_BUY.X - 6)
	assert(c:FindFirstChild("Title", true).Text == EN.RebirthTitle2 and c:FindFirstChild("Message", true).Text == EN.RebirthMsg2, "step 2 texts")
	-- Half-closed (sliding away, below 0.9 of the screen): back to step 1.
	openPanel(false)
	frames(1, 0.1)
	assert(c:FindFirstChild("Message", true).Text == EN.RebirthMsg1, "panel closed: back to step 1")
	openPanel(true)
	frames(1, 0.1)
	-- The rebirth: the server resets Level first (can no longer rebirth), then raises Rebirths.
	player:SetAttribute("Level", 1)
	frames(2, 0.2)
	assert(Guide.IsOpen() and #fired == 0, "a short dip in Level (the rebirth in progress) keeps the guide")
	player:SetAttribute("Rebirths", 1)
	player:SetAttribute("NextRebirthLevelRequired", 20)
	frames(1, 0.1)
	assert(completed == 1, "onComplete ran once")
	assert(c:FindFirstChild("Title", true).Text == EN.NiceJob and c:FindFirstChild("Message", true).Text == EN.RebirthDone, "the celebration texts")
	assert(seenFires("RebirthTutorialSeen") == 1 and #fired == 1 and player:GetAttribute("RebirthTutorialSeen") == true, "a rebirth saves RebirthTutorialSeen once")
	flush()
	assert(not Guide.IsOpen() and player:GetAttribute("GuidedTutorialOpen") == false, "closed after the celebration")
	assert(pg:FindFirstChild("SpeedsterGuidedSpotlight") == nil and pg:FindFirstChild("SpeedsterGuidedDimmer") == nil, "nothing left behind")
	frames(5, 0.5)
	assert(#fired == 1 and completed == 1, "saved and celebrated once")
	table.clear(fired)

	-- leaderstats.Rebirths counts as well (whichever the client sees first).
	local other = newWorld(READY)
	assert(Guide.Start(other, nil, "Rebirth"))
	frames(1, 0.1)
	local stats = fake("Folder", { Name = "leaderstats" }, other)
	fake("IntValue", { Name = "Rebirths", Value = 1 }, stats)
	frames(1, 0.1)
	assert(seenFires("RebirthTutorialSeen") == 1, "a leaderstats rebirth completes the guide")
	flush()
	table.clear(fired)
	pass("Rebirth guide: step 1 rings the sidebar Rebirth, step 2 the panel's Rebirth (not RebirthBuy), a rebirth celebrates and saves RebirthTutorialSeen once")
end

do
	-- Skip saves; 10 s on screen saves; CloseIfSeen closes a saved one; losing the rebirth closes unsaved.
	local player, pg = newWorld(READY)
	assert(Guide.Start(player, nil, "Rebirth"))
	frames(2, 0.5)
	pg.SpeedsterGuidedSpotlight:FindFirstChild("Skip", true).Activated:Fire()
	assert(seenFires("RebirthTutorialSeen") == 1 and #fired == 1, "Skip saves RebirthTutorialSeen once")
	flush()
	assert(not Guide.IsOpen(), "Skip closes it")
	table.clear(fired)

	local idle, idlePg = newWorld(READY)
	assert(Guide.Start(idle, nil, "Rebirth"))
	assert(Guide.CloseIfSeen(idle) == false, "not saved yet: keeps the screen")
	frames(19, 0.5)
	assert(#fired == 0, "9.5 s: not saved")
	frames(1, 0.5)
	assert(seenFires("RebirthTutorialSeen") == 1 and idle:GetAttribute("RebirthTutorialSeen") == true and Guide.IsOpen(), "10 s on screen: saved once, still up")
	assert(Guide.CloseIfSeen(idle) == true and not Guide.IsOpen(), "CloseIfSeen closes a saved Rebirth guide")
	assert(idlePg:FindFirstChild("SpeedsterGuidedSpotlight") == nil, "nothing left behind")
	assert(#fired == 1, "closing a saved guide sends nothing more")
	table.clear(fired)

	local lost, lostPg = newWorld(READY)
	assert(Guide.Start(lost, nil, "Rebirth"))
	frames(1, 0.1)
	lost:SetAttribute("NextRebirthLevelRequired", 50) -- e.g. an admin tool; no rebirth came
	frames(4, 0.2)
	assert(Guide.IsOpen(), "0.8 s: still up")
	frames(2, 0.2)
	assert(not Guide.IsOpen() and #fired == 0 and lost:GetAttribute("RebirthTutorialSeen") == nil, "can no longer rebirth: closed at once, not saved")
	assert(lostPg:FindFirstChild("SpeedsterGuidedSpotlight") == nil and lost:GetAttribute("GuidedTutorialOpen") == false)

	local early = newWorld({ Level = 3, NextRebirthLevelRequired = 5, Rebirths = 0 })
	assert(Guide.Start(early, nil, "Rebirth") == false and not Guide.IsOpen(), "no guide for a runner who cannot rebirth yet")
	local noPanel, noPanelPg = newWorld(READY)
	noPanelPg.Rebirth.Rebirth.Rebirth.Parent = nil
	assert(Guide.Start(noPanel, nil, "Rebirth") == false, "no guide without the panel's Rebirth button")

	-- The sidebar hidden: the card asks to open Rebirth.
	local hidden, hiddenPg = newWorld(READY)
	hiddenPg.Mainhud.LeftSideBar.Visible = false
	assert(Guide.Start(hidden, nil, "Rebirth"))
	frames(1, 0.1)
	assert(card(hiddenPg):FindFirstChild("Message", true).Text == EN.RebirthOpen, "no target on screen: 'Open Rebirth to continue'")
	hiddenPg.SpeedsterGuidedSpotlight:FindFirstChild("Skip", true).Activated:Fire()
	flush()
	table.clear(fired)
	pass("Rebirth guide: Skip and 10 s save once, CloseIfSeen closes it, losing the rebirth closes it unsaved (a short dip does not), none when it cannot rebirth")
end

do
	-- A Spanish player reads Spanish, and Roblox does not translate it again.
	local player, pg, openPanel = newWorld(READY, "es-mx")
	assert(Guide.Start(player, nil, "Rebirth"))
	frames(1, 0.1)
	local c = card(pg)
	local title, message = c:FindFirstChild("Title", true), c:FindFirstChild("Message", true)
	local skipLabel = c:FindFirstChild("Skip"):FindFirstChild("Label")
	assert(title.Text == ES.RebirthTitle1 and message.Text == ES.RebirthMsg1, "Spanish step 1: " .. title.Text .. " / " .. message.Text)
	assert(skipLabel.Text == ES.Skip, "Spanish Skip: " .. skipLabel.Text)
	assert(title.AutoLocalize == false and message.AutoLocalize == false and skipLabel.AutoLocalize == false, "AutoLocalize off on every filled label")
	openPanel(true)
	frames(1, 0.1)
	assert(message.Text == ES.RebirthMsg2 and title.Text == ES.RebirthTitle2, "Spanish step 2")
	player:SetAttribute("Rebirths", 1)
	frames(1, 0.1)
	assert(title.Text == ES.NiceJob and message.Text == ES.RebirthDone, "Spanish celebration")
	flush()
	table.clear(fired)

	-- Evolve and the aura guide still read their English texts for "en" (and Spanish for es).
	local evolver, evolvePg = newWorld()
	evolver:SetAttribute("EvolveGuideTarget", "ReverseSpeedsterSuit")
	evolver:SetAttribute("EvolveAvailableCount", 1)
	assert(Guide.Start(evolver, nil, "Evolve"))
	frames(1, 0.1)
	local ec = card(evolvePg)
	assert(ec:FindFirstChild("Title", true).Text == "READY TO EVOLVE!" and ec:FindFirstChild("Message", true).Text == "Tap Evolve to unlock a faster suit!", "Evolve English")
	assert(ec:FindFirstChild("Skip"):FindFirstChild("Label").Text == "Skip guide", "Skip guide in English")
	assert(ec:FindFirstChild("Icon").Image == "rbxassetid://92164600998462" and ec:FindFirstChild("Step2") and not ec:FindFirstChild("Step3"), "Evolve card unchanged")
	evolvePg.Evolve.Evolve.Visible = true
	evolvePg.Evolve.Evolve.Position = rb.UDim2.fromScale(0.5, 0.48)
	frames(1, 0.1)
	assert(ec:FindFirstChild("Message", true).Text == "Tap Evolve to get your new suit" and ec:FindFirstChild("Title", true).Text == "GET YOUR NEW SUIT", "Evolve step 2 English")
	fake("BoolValue", { Name = "ReverseSpeedsterSuit", Value = true }, evolver.SpeedsterData.OwnedSkins)
	frames(1, 0.1)
	assert(ec:FindFirstChild("Title", true).Text == "NICE JOB!" and ec:FindFirstChild("Message", true).Text == "New suit unlocked!\nKeep training to get faster!", "Evolve celebration English")
	assert(seenFires("EvolveTutorialSeen") == 1, "Evolve still saves its own key")
	flush()
	table.clear(fired)

	local newbie, newbiePg = newWorld()
	assert(Guide.Start(newbie, nil))
	frames(1, 0.1)
	local ac = card(newbiePg)
	assert(ac:FindFirstChild("Title", true).Text == "YOUR FIRST AURA" and ac:FindFirstChild("Message", true).Text == "Tap the backpack button", "aura guide English")
	assert(ac:FindFirstChild("Step3") and ac:FindFirstChild("Icon").Image == "rbxassetid://139874655682754", "aura card unchanged")
	newbie:SetAttribute("EquippedAuraId", "Aura05")
	frames(1, 0.1)
	assert(ac:FindFirstChild("Message", true).Text == "Aura equipped!\nEnjoy your 2.5x speed!" and newbie:GetAttribute("SpeedsterTutorialEquipDone") == true, "aura celebration English")
	assert(seenFires("BackpackTutorialSeen") == 1, "the aura guide still saves its own key")
	flush()
	table.clear(fired)

	local russian, ruPg = newWorld(READY, "ru-ru")
	assert(Guide.Start(russian, nil, "Rebirth"))
	frames(1, 0.1)
	local rtitle = card(ruPg):FindFirstChild("Title", true)
	assert(rtitle.Text == TutorialText.Strings.ru.RebirthTitle1, "Russian title")
	ruPg.SpeedsterGuidedSpotlight:FindFirstChild("Skip", true).Activated:Fire()
	flush()
	table.clear(fired)
	pass("a Spanish player gets Spanish title/message/Skip with AutoLocalize off; Evolve and the aura guide keep their English texts, icons, pills and keys for en")
end

do
	-- MarkSeen and the source.
	local player = newWorld(READY)
	assert(Guide.MarkSeen(player, "Rebirth") == true and fired[1][1] == "RebirthTutorialSeen", "MarkSeen(player, 'Rebirth')")
	assert(Guide.MarkSeen(player, "Rebirth") == false and #fired == 1, "...once")
	table.clear(fired)
	local source = read(GUIDE)
	for _, english in { '"NICE JOB!"', '"Skip guide"', '"Tap the backpack button"', '"Open Evolve to continue"', '"READY TO EVOLVE!"' } do
		assert(not source:find(english, 1, true), "TutorialGuide still hard-codes " .. english)
	end
	has(source, 'require(script.Parent:WaitForChild("TutorialText"))', "TutorialGuide reads TutorialText")
	assert(not source:find('"RebirthBuy"', 1, true), "the guide never points at the Robux button")
	pass("MarkSeen(player, 'Rebirth') sends once; TutorialGuide hard-codes no English")
end

----------------------------------------------------------------------
-- 3. RebirthTutorialSeen persists like EvolveTutorialSeen
----------------------------------------------------------------------
do
	local KEY = "RebirthTutorialSeen"
	assert(Codec.CreateDefault().Settings[KEY] == false, "a new profile: false")
	local old = Codec.Decode({ Version = 306, Speed = 1, Wins = 0, Settings = { Muted = true, EvolveTutorialSeen = true } })
	assert(old.ok and old.value.Settings[KEY] == false and old.value.Settings.EvolveTutorialSeen == true, "an old save reads false, keeps the others")
	for _, junk in { "true", 1, { true } } do
		local decoded = Codec.Decode({ Version = 306, Speed = 1, Wins = 0, Settings = { [KEY] = junk } })
		assert(decoded.ok and decoded.value.Settings[KEY] == false, "a corrupt flag reads false")
	end
	local p = Codec.Decode(nil).value
	assert(Reducers.ApplyPreference(p, KEY, true).ok and p.Settings[KEY] == true, "ApplyPreference keeps it")
	for _, bad in { "true", 1, {} } do
		local q = Codec.CreateDefault()
		assert(not Reducers.ApplyPreference(q, KEY, bad).ok and q.Settings[KEY] == false, "ApplyPreference refuses " .. typeof(bad))
	end
	local encoded = Codec.Encode(p)
	assert(encoded.Settings[KEY] == true, "written to the save")
	local again = Codec.Decode(encoded)
	assert(again.ok and again.value.Settings[KEY] == true, "survives a save and a rejoin")

	local bootstrap = read(BOOTSTRAP)
	local header = "RemoteGuard.Connect(SettingsUpdate, 0.05, function(player: Player, attrName: any, value: any)\n"
	local body = between(bootstrap, header, "\nend)\n\nRemoteGuard.Connect(UpdateLogClosed", "SettingsUpdate handler")
	body = string.sub(body, #header + 1)
	has(body, 'RebirthTutorialSeen = "boolean"', "allow-list has RebirthTutorialSeen as a boolean")
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
	handler(loaded, KEY, "true")
	handler({ UserId = 1, GetAttribute = function() return false end }, KEY, true)
	assert(#calls == 0, "not a boolean, or before the profile loaded: never reaches DataService")
	handler(loaded, KEY, true)
	assert(#calls == 1 and profile.Settings[KEY] == true, "RebirthTutorialSeen reaches the profile")
	has(read(PROJECTION), "for settingKey, settingVal in pairs(profile.Settings) do\n\t\t\t\tsetAttributeIfChanged(player, settingKey, settingVal)", "Settings are projected to attributes")
	pass("RebirthTutorialSeen: default false (old saves too), reducer and SettingsUpdate take booleans only, survives a save and a rejoin, projected as an attribute")
end

----------------------------------------------------------------------
-- 4. UI/RebirthController: the gate and the loop
----------------------------------------------------------------------
do
	local source = read(REBIRTH)
	local getters = between(source, "local function getAuthoritativeLevel()", "local updateProgress", "getters")
	local gate = between(source, "-- rebirthGuideGate\n", "-- end rebirthGuideGate", "gate")
	has(gate, "REBIRTH_GUIDE_QUIET_SECONDS = 2", "a 2 s quiet window")
	local function ready(attributes, opts)
		opts = opts or {}
		local attrs = table.clone(attributes)
		local humanoid = { Health = if opts.dead then 0 else 100 }
		local character = if opts.noCharacter then nil else { FindFirstChildOfClass = function() return humanoid end }
		local sidebar = { Visible = opts.sidebarHidden ~= true }
		local hud = { Enabled = true, FindFirstChild = function(_, name) return if name == "LeftSideBar" then sidebar else nil end }
		local player = {
			Character = character,
			GetAttribute = function(_, name) return attrs[name] end,
			FindFirstChild = function() return nil end,
		}
		local playerGui = { FindFirstChild = function(_, name)
			if name == "Mainhud" then return hud end
			if name == "SpeedsterLoadingScreen" and opts.loading then return {} end
			return nil
		end }
		return luau.load(getters .. "\n" .. gate .. "\nreturn rebirthGuideReady()", { environment = {
			player = player, playerGui = playerGui, tonumber = tonumber,
			os = { clock = function() return 100 end },
			currentData = { Rebirths = 0, CurrentLevel = 1, RequiredLevel = 5 },
		} })()
	end
	local base = { DataLoaded = true, Level = 5, NextRebirthLevelRequired = 5, Rebirths = 0 }
	assert(ready(base) == true, "a new runner who can rebirth: ready")
	local function without(key, value)
		local attrs = table.clone(base)
		attrs[key] = value
		return attrs
	end
	for _, case in {
		{ "Rebirths", 1, "existing players with a rebirth never see it" },
		{ "Level", 4, "cannot rebirth yet" },
		{ "NextRebirthLevelRequired", 6, "cannot rebirth yet (requirement)" },
		{ "RebirthTutorialSeen", true, "already seen" },
		{ "DataLoaded", false, "data not loaded" },
		{ "DataLoaded", nil, "data not loaded (nil)" },
		{ "FirstTimeTutorialActive", true, "first-time tutorial running, no step yet" },
		{ "AuraGuidePending", true, "the aura guide is owed (first look, inside the 15 s grace)" },
		{ "GuidedTutorialOpen", true, "another guide is up" },
		{ "WorldPortalCinematicActive", true, "portal flight playing" },
		{ "WorldPortalCinematicPending", true, "portal flight owed" },
	} do
		assert(ready(without(case[1], case[2])) == false, "gate must hold back: " .. case[3])
	end
	assert(ready(without("AuraGuidePending", false)) == true, "AuraGuidePending false: ready")
	has(gate, "REBIRTH_GUIDE_AURA_GRACE_SECONDS = 15", "a 15 s aura grace")
	local step1 = without("FirstTimeTutorialActive", true)
	step1.FirstTimeTutorialStep = 1
	assert(ready(step1) == false, "gate must hold back: first-time tutorial Step 1")
	step1.FirstTimeTutorialStep = 0
	assert(ready(step1) == false, "gate must hold back: the pause before Step 2")
	step1.FirstTimeTutorialStep = 2
	-- 2026-09-24 (retention P0): Step 2 holds it too; Level 5 comes ~20 s into Step 2 and a
	-- rebirth there reset the runner before the first obby. audit/test_polish_rebirth_guide.
	assert(ready(step1) == false, "gate must hold back: first-time tutorial Step 2 (claim your wins)")
	assert(ready(without("Level", 30)) == true, "past the requirement: ready")
	for _, opt in { "dead", "noCharacter", "sidebarHidden", "loading" } do
		assert(ready(base, { [opt] = true }) == false, "gate must hold back: " .. opt)
	end

	-- The loop, run as it is: quiet window, offered once, offered again after a teardown, never once seen.
	local loop = string.sub(source, (string.find(source, "-- end rebirthGuideGate\n", 1, true)))
	local attrs = { GuidedTutorialOpen = false }
	local clock, isReady, starts, startResult = 0, true, 0, true
	local co
	local modes = {}
	luau.load(loop, { environment = {
		player = { Parent = true, GetAttribute = function(_, name) return attrs[name] end },
		rebirthGuideReady = function() return isReady end,
		REBIRTH_GUIDE_QUIET_SECONDS = 2,
		require = function() return { Start = function(player, onComplete, mode)
			starts += 1
			table.insert(modes, mode)
			if startResult then attrs.GuidedTutorialOpen = true end
			return startResult
		end } end,
		ReplicatedStorage = { Shared = { TutorialGuide = true } },
		os = { clock = function() return clock end },
		task = {
			spawn = function(fn) co = coroutine.create(fn); assert(coroutine.resume(co)) end,
			wait = function() return coroutine.yield() end,
		},
	} })()
	local function tick(seconds)
		local steps = math.max(1, math.floor(seconds / 0.75 + 0.5))
		for _ = 1, steps do
			clock += 0.75
			assert(coroutine.resume(co))
		end
	end
	tick(1.5)
	assert(starts == 0, "not before 2 quiet seconds")
	tick(0.75)
	assert(starts == 1 and modes[1] == "Rebirth", "offered after 2 quiet seconds, mode Rebirth")
	tick(10)
	assert(starts == 1, "offered once while it is up")
	attrs.GuidedTutorialOpen = false -- torn down (e.g. the runner lost the rebirth), never seen through
	tick(0.75)
	assert(starts == 1, "a fresh quiet window after a teardown")
	tick(2.25)
	assert(starts == 2, "offered again after a teardown")
	attrs.RebirthTutorialSeen = true
	attrs.GuidedTutorialOpen = false
	isReady = false
	tick(20)
	assert(starts == 2, "never again once seen")
	has(loop, 'Start(player, nil, "Rebirth") == true', "the loop starts the Rebirth mode")
	pass("RebirthController: the gate holds back for every blocker incl. every first-tutorial step, an owed aura guide (grace) and any rebirth; the loop waits 2 quiet seconds, offers once, again after a teardown, never once seen")
end

----------------------------------------------------------------------
-- 5. UI/FirstTimeTutorial: AuraGuidePending and the step labels
----------------------------------------------------------------------
do
	local source = read(FIRST)
	local chunk = between(source, "local function wantsAuraGuide()", "local function canShowAuraGuide()", "wantsAuraGuide")
	has(chunk, "local function publishAuraGuidePending()", "publishAuraGuidePending sits beside wantsAuraGuide")
	local function publish(attributes, saw)
		local attrs = table.clone(attributes)
		local player = {
			GetAttribute = function(_, name) return attrs[name] end,
			SetAttribute = function(_, name, value) attrs[name] = value end,
		}
		local result = luau.load(chunk .. "\nreturn publishAuraGuidePending()", { environment = {
			TutorialFlow = TutorialFlow, sawTutorial = saw, player = player, TUTORIAL_WIN_STAGE = 1,
			tonumber = tonumber,
		} })()
		return result, attrs.AuraGuidePending
	end
	local r, a = publish({ LastCompletedSafeZone = 1 }, true)
	assert(r == true and a == true, "owed after the first Win pad: AuraGuidePending true")
	r, a = publish({ LastCompletedSafeZone = 1, BackpackTutorialSeen = true }, true)
	assert(r == false and a == false, "dismissed: false")
	r, a = publish({ LastCompletedSafeZone = 1, SpeedsterTutorialEquipDone = true }, true)
	assert(r == false and a == false, "done: false")
	r, a = publish({ LastCompletedSafeZone = 3 }, false)
	assert(r == false and a == false, "a veteran who never saw the tutorial: false")
	r, a = publish({ LastCompletedSafeZone = 0 }, false)
	assert(r == false and a == false, "never saw the tutorial, no pad: false")
	-- Polish pass 2026-09-22: an unclaimed pad no longer counts as "coming" (that hold lasted the
	-- whole first-time tutorial, re-offered every join, plus 180 s, and kept the rebirth guide away).
	r, a = publish({ LastCompletedSafeZone = 0 }, true)
	assert(r == false and a == false, "tutorial running or timed out, pad unclaimed: not owed")
	r, a = publish({ LastCompletedSafeZone = 0, Level = 5 }, true)
	assert(r == false and a == false, "pad unclaimed at Level 5: not owed, the rebirth guide may go")
	for _, gone in { "auraGuideComing", "AURA_PAD_HOLD_SECONDS", "tutorialEndedAt" } do
		assert(not source:find(gone, 1, true), "the old pad hold is back: " .. gone)
	end
	-- The loop keeps it current and done/dismissed clear it at once; the aura guide itself only
	-- starts once it is really owed (pad claimed).
	has(source, "\tpublishAuraGuidePending()\n\tif auraGuideRunning or not wantsAuraGuide() then", "pumpAuraGuide publishes, starts only when owed")
	has(source, "while player.Parent and wantsAuraGuide() do\n\t\t\tpublishAuraGuidePending()", "the aura loop publishes")
	has(source, "auraGuideRunning = false\n\t\tpublishAuraGuidePending()", "the aura loop publishes when it ends")
	has(source, 'player:GetAttributeChangedSignal("BackpackTutorialSeen"):Connect(publishAuraGuidePending)', "dismissed clears it")
	has(source, 'player:GetAttributeChangedSignal("SpeedsterTutorialEquipDone"):Connect(publishAuraGuidePending)', "done clears it")

	-- Step labels are TutorialText keys.
	local labels = between(source, "local STEP_LABEL_TEXT = {", "}", "STEP_LABEL_TEXT")
	local found = 0
	for key in labels:gmatch('= "(%w+)"') do
		found += 1
		assert(TutorialText.Strings.en[key], "step label key " .. key .. " is not in TutorialText")
		for _, lang in LANGS do
			assert(TutorialText.Strings[lang][key], lang .. " lacks " .. key)
		end
	end
	assert(found == 2, "two step labels")
	has(source, "TutorialText.Get(key, stepLanguage)", "labels read TutorialText in the player's language")
	has(source, "TutorialText.Style(labelText, stepLanguage)", "label AutoLocalize off (and font)")
	assert(not source:find('= "TRAIN HERE!"', 1, true) and not source:find('= "CLAIM YOUR WINS!"', 1, true), "no hard-coded English label left")
	pass("FirstTimeTutorial: AuraGuidePending true exactly while the aura guide is owed (pad claimed), never for an unclaimed pad, when done/dismissed or for veterans; step labels are TutorialText keys in every language")
end

----------------------------------------------------------------------
-- 6. TutorialText review rules: button words match the HUD, fr spacing, Skip fits its button
----------------------------------------------------------------------
do
	local S = TutorialText.Strings
	-- The HUD buttons say Evolve and Rebirth: the Latin-script languages name them that way.
	for _, lang in { "es", "pt", "id", "fr", "de", "tr" } do
		for _, key in { "EvolveMsg1", "EvolveMsg2", "EvolveOpen" } do
			assert(S[lang][key]:find("Evolve", 1, true), lang .. "." .. key .. " must name the Evolve button as the HUD does")
		end
		for _, key in { "RebirthMsg1", "RebirthOpen" } do
			assert(S[lang][key]:find("Rebirth", 1, true), lang .. "." .. key .. " must name the Rebirth button as the HUD does")
		end
	end
	-- The currency reads Wins (as on the counter and the price tags) everywhere but Arabic.
	for _, lang in LANGS do
		if lang ~= "ar" then
			assert(S[lang].AuraMsgGet:find("Wins", 1, true), lang .. ".AuraMsgGet must say Wins")
			assert(S[lang].StepClaimWins:upper():find("WINS", 1, true), lang .. ".StepClaimWins must say Wins")
		end
	end
	-- French: a no-break space before ! and :, never an ordinary one that could wrap alone.
	for key, text in S.fr do
		assert(not text:find(" !", 1, true) and not text:find(" :", 1, true), "fr." .. key .. " has a breakable space before ! or :")
	end
	assert(S.fr.NiceJob == "BIEN JOUÉ\u{00A0}!", "fr NiceJob keeps its no-break space")
	-- The Skip button does not wrap: keep it about as short as the English.
	for _, lang in LANGS do
		assert((utf8.len(S[lang].Skip) or 99) <= 12, lang .. ".Skip is too long for its button: " .. S[lang].Skip)
	end
	-- Arabic: no tatweel left dangling before a space.
	for key, text in S.ar do
		assert(not text:find("ـ ", 1, true), "ar." .. key .. " has a dangling tatweel")
	end
	pass("TutorialText: Evolve/Rebirth named as on the HUD in Latin-script languages, Wins kept, fr no-break spaces, Skip fits, no dangling tatweel")
end

print(("ALL PASSED (%d checks)"):format(passed))
