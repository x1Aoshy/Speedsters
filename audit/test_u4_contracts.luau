-- test_u4_contracts.luau (Update 4, integrator Phase 0, 2026-09-25)
-- The contracts every Update 4 workstream codes against (output/Update4/PLAN.md §2, §5):
--   1. Shared/Update4Config is the §2.1 contract, loads in plain Lune, and IsOn honours the
--      flags, the pass id, the Workspace kill switch and TestingOnly;
--   2. the design assets are the pinned copies (SHA-256) and their roots are what the lists name;
--   3. Services/Data/Update4Profile dispatches U4.<Section>.<Op> to section modules, refuses
--      unknown commands, survives throwing sections, and carries the data of a section that did
--      not load instead of dropping it;
--   4. ProfileCodec: U4 is a known field (never in Update2PreservedFields), an old save gets
--      every section's Default, and U4 round-trips (plain require and through SessionActor);
--   5. ProfileReducers: U4 commands are routed, unknown ones rejected, M33 fallbacks wired;
--   6. FunnelAnalytics: the 7 funnels of §2.6, their routes, strict sequencing, the client
--      whitelist, and FunnelAnalytics.Event (every §2.6 custom event whitelisted);
--   7. MenuEvents / ModalJuice / ConsoleUiScale / MainHUDController know the 6 new panels.
-- Run: lune run audit/test_u4_contracts.luau   (from the project root)
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local DATA = "src/common/ServerScriptService/Services/Data/"
local CONFIG = "src/common/ReplicatedStorage/Shared/Update4Config.luau"
local FUNNELS = "src/common/ServerScriptService/Services/FunnelAnalytics.luau"
local MENU_EVENTS = "src/common/ReplicatedStorage/Shared/MenuEvents.luau"
local MODAL_JUICE = "src/common/ReplicatedStorage/Shared/ModalJuice.luau"
local CONSOLE = "src/common/StarterPlayer/StarterPlayerScripts/UI/ConsoleUiScale.client.luau"
local MAIN_HUD = "src/common/StarterPlayer/StarterPlayerScripts/UI/MainHUDController.client.luau"
local PLAN = "output/Update4/PLAN.md"

local passed = 0
local function pass(text)
	passed += 1
	print("PASS " .. text)
end
local function read(path)
	return (fs.readFile(path):gsub("\r\n", "\n"))
end
local function has(source, needle, message)
	assert(string.find(source, needle, 1, true), message .. " (missing: " .. needle .. ")")
end
local function equal(a, b)
	if type(a) ~= type(b) then
		return false
	end
	if type(a) ~= "table" then
		return a == b
	end
	for k, v in a do
		if not equal(v, b[k]) then
			return false
		end
	end
	for k in b do
		if a[k] == nil then
			return false
		end
	end
	return true
end
local function count(t)
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

for _, path in { CONFIG, DATA .. "Update4Profile.luau", DATA .. "ProfileCodec.luau", DATA .. "ProfileReducers.luau",
	FUNNELS, MENU_EVENTS, MODAL_JUICE, CONSOLE, MAIN_HUD } do
	local ok, problem = pcall(luau.compile, fs.readFile(path))
	assert(ok, "SYNTAX " .. path .. ": " .. tostring(problem))
end
pass("every Phase 0 source compiles")

----------------------------------------------------------------------
-- 1. Update4Config
----------------------------------------------------------------------
do
	-- The file is the §2.1 block line for line (only the Lune datatype shim is added).
	local plan = read(PLAN)
	local block = string.match(plan, "### 2%.1 [^\n]*\n.-```lua\n(.-)```")
	assert(block, "PLAN §2.1 code block found")
	local fileLines = string.split(read(CONFIG), "\n")
	-- Phase 1 amendments (2026-09-25): the first World 1 / World 3 Race Gate probes sat inside the
	-- lobby's back-edge block; race_server's replacement points (test_u4_race_placement) stand in.
	local AMENDED = {
		-- 2026-09-26: the owner gave their UserId.
		["	OwnerUserIds = {}, -- owner to confirm (see questions); the game creator (user or group rank 255) is Owner anyway"] =
			"	OwnerUserIds = { [767108248] = true }, -- the owner (2026-09-26); the game creator (user or group rank 255) is Owner anyway",
		-- 2026-09-26 (owner): Gekkoh (767108248) is no longer forced to DEV; he owns OWNER.
		["	DeveloperUserIds = { [767108248] = true, [111827288] = true },"] =
			"	DeveloperUserIds = { [111827288] = true },",
		-- 2026-09-26: the owner created the 2x Stamina pass.
		["U4.StaminaPass = { GamePassId = 0, GiftProductId = 0, PriceRobux = 149, RegenMultiplier = 2, DelayScale = 0.5,"] =
			"U4.StaminaPass = { GamePassId = 1998458598, GiftProductId = 0, PriceRobux = 149, RegenMultiplier = 2, DelayScale = 0.5,",
		["\t-- Lobby Race Gate pad (race-core probes; test_u4_race_placement must confirm)."] =
			"\t-- Lobby Race Gate pad. 2026-09-25: the first World 1 / World 3 probes sat inside the lobby's",
		["\t\tWorld1 = { Position = Vector3.new(400, 37467.69, -1845), Face = Vector3.new(400, 37467.69, -1781) },"] =
			"\t\tWorld1 = { Position = Vector3.new(404, 37467.69, -1664), Face = Vector3.new(340, 37467.69, -1664) }, -- open NE corner, off the walk to Stage 1",
		["\t\tWorld3 = { Position = Vector3.new(145.6, 95.61, 585.5), Face = Vector3.new(265.3, 95.61, 521.6) },"] =
			"\t\tWorld3 = { Position = Vector3.new(136, 95.61, 392), Face = Vector3.new(200, 95.61, 392) },",
	}
	local at = 1
	for _, line in string.split(block, "\n") do
		line = AMENDED[line] or line
		if line ~= "" then
			while at <= #fileLines and fileLines[at] ~= line do
				at += 1
			end
			assert(at <= #fileLines, "Update4Config keeps the contract line: " .. line)
			at += 1
		end
	end
	pass("Update4Config holds every line of PLAN §2.1, in order")

	local U4 = require("../src/common/ReplicatedStorage/Shared/Update4Config")
	assert(typeof(U4.Race.Arena.Origin) == "Vector3" and U4.Race.Arena.Origin.Y == 12000, "Origin is a Vector3 in Lune")
	assert(typeof(U4.Race.Feel.Vfx.Colors.Charge1) == "Color3", "Colors are Color3 in Lune")
	assert(U4.Race.Track.Length == 2000 and U4.Race.Track.Lanes == 8 and #U4.Race.Track.SpikeBlocked == 4, "Track contract")
	for field, rows in U4.Race.Track.SpikeBlocked do
		for _, row in rows do
			assert(#row == 4, "Field " .. field .. ": every spike row leaves 4 of 8 lanes free")
		end
	end
	assert(U4.RetentionMultiplierCap == 3.4 and U4.Stamina == nil and U4.Race.Stamina.PassRegenFactor == 1.0, "Owner defaults (§8)")
	assert(U4.IsOn("Race") and U4.IsOn("Titles") and U4.IsOn("Streak") and U4.IsOn("PlaytimeBoost") and U4.IsOn("Community") and U4.IsOn("MegaRace"), "Features ship ON")
	assert(U4.StaminaPass.GamePassId == 1998458598 and U4.IsOn("StaminaPass"), "StaminaPass is on with the owner's pass (2026-09-26)")
	do
		local id = U4.StaminaPass.GamePassId
		U4.StaminaPass.GamePassId = 0
		assert(not U4.IsOn("StaminaPass"), "StaminaPass stays off while its GamePassId is 0")
		U4.StaminaPass.GamePassId = id
	end
	assert(not U4.IsOn("NoSuchFeature"), "Unknown features are off")

	-- In a place: the Workspace kill switch and TestingOnly.
	local attrs = {}
	local workspace = { GetAttribute = function(_, k) return attrs[k] end }
	local game = { PlaceId = 1, GetService = function(_, name) assert(name == "Workspace"); return workspace end }
	local env = {
		game = game,
		Vector3 = roblox.Vector3,
		Color3 = roblox.Color3,
		typeof = function(v) if v == game then return "Instance" end return typeof(v) end,
	}
	local Placed = luau.load(fs.readFile(CONFIG), { environment = env })()
	assert(Placed.IsOn("Race"), "On in a live place")
	attrs.U4Off_Race = true
	assert(not Placed.IsOn("Race") and Placed.IsOn("Titles"), "Workspace.U4Off_Race turns only the race off, live")
	attrs.U4Off_Race = nil
	Placed.Flags.Race.TestingOnly = true
	assert(not Placed.IsOn("Race"), "TestingOnly: off outside the testing places")
	game.PlaceId = 138540610580146
	assert(Placed.IsOn("Race"), "...and on in a testing place")
	Placed.StaminaPass.GamePassId = 123
	assert(Placed.IsOn("StaminaPass"), "The pass switches on with its id")
	workspace.GetAttribute = function() error("boom") end
	assert(Placed.IsOn("Titles"), "A failing attribute read never throws")
	pass("Update4Config loads in plain Lune (Vector3/Color3), IsOn: flags, pass id, kill switch, TestingOnly")
end

----------------------------------------------------------------------
-- 2. Design assets
----------------------------------------------------------------------
do
	local pinned = {
		["design/ui/uineww.rbxm"] = "3cedc6a19ca3db37d3f507b54c1151cd387750ed95aea037fd0d8d085667030f",
		["design/vfx/BubbleModule.rbxm"] = "7c10eae8d43b607568a3243f668ead7d0b17579d744b3b647a2f38f0bcfa78fa",
	}
	for path, sha in pinned do
		assert(serde.hash("sha256", fs.readFile(path)) == sha, path .. " is the pinned copy")
	end
	local ui = roblox.deserializeModel(fs.readFile("design/ui/uineww.rbxm"))
	assert(#ui == 1 and ui[1].ClassName == "Folder" and ui[1].Name == "NewUI", "uineww root is Folder NewUI")
	local guis = {}
	for _, gui in ui[1]:GetChildren() do
		assert(gui.ClassName == "ScreenGui", "NewUI holds ScreenGuis only")
		assert(gui:FindFirstChild(gui.Name) and gui:FindFirstChild(gui.Name).ClassName == "Frame", gui.Name .. ": root frame named like its ScreenGui (ModalJuice)")
		guis[gui.Name] = true
	end
	for _, d in ui[1]:GetDescendants() do
		assert(not d:IsA("LuaSourceContainer"), "The designer UI carries no scripts")
	end
	assert(equal(guis, { ["Playtime Boost"] = true, ["Streak Rewards"] = true, ["Community rewards"] = true, Titles = true }), "The 4 designer panels")
	local bubble = roblox.deserializeModel(fs.readFile("design/vfx/BubbleModule.rbxm"))
	assert(#bubble == 1 and bubble[1].ClassName == "ModuleScript" and bubble[1].Name == "BubbleModule", "BubbleModule root")
	assert(bubble[1]:FindFirstChild("Mesh") and bubble[1].Mesh.ClassName == "MeshPart", "...with its Mesh")
	pass("design assets: pinned SHA-256, NewUI's 4 panels, BubbleModule + Mesh")
end

----------------------------------------------------------------------
-- 3. Update4Profile (stub sections through an injected require)
----------------------------------------------------------------------
local function stubSection(name, calls)
	local S = {}
	function S.Default()
		return { Count = 0, Name = name }
	end
	function S.Sanitize(raw)
		if type(raw) ~= "table" then return S.Default() end
		local n = tonumber(raw.Count)
		return { Count = if n and n == n and n >= 0 then math.floor(n) else 0, Name = name }
	end
	function S.Encode(t)
		return { Count = t.Count, Name = t.Name }
	end
	function S.Apply(state, op, command, now)
		table.insert(calls, { section = name, op = op, now = now })
		if op == "Add" then
			state.Count += 1
			return { ok = true, value = state.Count }
		elseif op == "Boom" then
			error("section bug")
		elseif op == "SetPref" or op == "Playtime" then
			return { ok = true, value = true }
		end
		return { ok = false, error = { code = "InvalidInput", message = "bad op", retryable = false } }
	end
	return S
end

local function loadDispatcher(present, calls)
	local stubs = {}
	for _, name in present do
		stubs["./U4/" .. name .. "Section"] = stubSection(name, calls)
	end
	local env = {
		require = function(path)
			local mod = stubs[path]
			if not mod then error("module not found: " .. path) end
			return mod
		end,
	}
	return luau.load(fs.readFile(DATA .. "Update4Profile.luau"), { environment = env })()
end

do
	local calls = {}
	local P = loadDispatcher({ "Race", "Retention", "Titles", "Community" }, calls)
	for _, name in { "Race", "Retention", "Titles", "Community" } do
		assert(P.HasSection(name), name .. " section loaded")
	end
	local d = P.Default()
	assert(d.V == 1 and d.Race.Count == 0 and d.Community.Name == "Community" and count(d) == 5, "Default: V + 4 sections")
	local old = P.Sanitize(nil)
	assert(equal(old, d), "An old save (no U4) gets every section's Default")
	local clean = P.Sanitize({ V = 1, Race = { Count = 3 }, Titles = { Count = 0 / 0 }, Junk = { 1 } })
	assert(clean.Race.Count == 3 and clean.Titles.Count == 0 and clean.Junk == nil, "Sanitize goes section by section; unknown keys dropped")
	assert(equal(P.Encode(clean), clean), "Encode round trip")
	assert(P.Encode(nil).Retention.Count == 0, "Encode of nothing = defaults")

	local profile = {}
	local r = P.Apply(profile, { kind = "U4.Race.Add" }, 1234)
	assert(r.ok and r.value == 1 and profile.U4.Race.Count == 1 and calls[1].op == "Add" and calls[1].now == 1234, "U4.Race.Add reaches RaceSection.Apply(state, 'Add', command, now)")
	for _, bad in { { kind = "U4.Nope.Add" }, { kind = "U4.Race" }, { kind = "U4..Add" }, { kind = "U4.Race.Add.More" }, { kind = 5 }, "x" } do
		local rej = P.Apply(profile, bad, 1)
		assert(rej.ok == false and rej.error.code == "InvalidInput" and rej.error.retryable == false, "Unknown/malformed U4 command is rejected")
	end
	local boom = P.Apply(profile, { kind = "U4.Race.Boom" }, 1)
	assert(boom.ok == false and boom.error.code == "InvalidInput", "A throwing section is a rejected command, not an error")
	profile.U4.Titles = "corrupt"
	assert(P.Apply(profile, { kind = "U4.Titles.Add" }, 1).ok and profile.U4.Titles.Count == 1, "A corrupt in-memory section restarts from Default")
	assert(P.IsVolatile("U4.Retention.Playtime") and P.IsVolatile("U4.Titles.SetPref"), "Volatile whitelist")
	assert(not P.IsVolatile("U4.Race.Record") and not P.IsVolatile("U4.Retention.ClaimStreak") and not P.IsVolatile(nil), "...exactly two kinds")

	-- A section that did not load: its saved data is carried, untouched, not wiped.
	local partial = loadDispatcher({ "Race" }, {})
	assert(partial.HasSection("Race") and not partial.HasSection("Titles"), "Only Race loaded")
	local saved = { V = 1, Race = { Count = 2 }, Titles = { Pref = "race_winner", Owned = { "race_winner", "member" } } }
	local kept = partial.Encode(partial.Sanitize(saved))
	assert(kept.Race.Count == 2 and equal(kept.Titles, saved.Titles), "Titles data survives a missing TitlesSection")
	assert(kept.Titles ~= saved.Titles, "...as a copy")
	local rejected = partial.Apply({ U4 = kept }, { kind = "U4.Titles.SetPref", pref = "none" }, 1)
	assert(not rejected.ok, "...and its commands are refused")

	-- A section missing a contract function is not loaded.
	local broken = luau.load(fs.readFile(DATA .. "Update4Profile.luau"), { environment = { require = function(path)
		if path == "./U4/RaceSection" then return { Default = function() return {} end } end
		error("missing")
	end } })()
	assert(not broken.HasSection("Race") and equal(broken.Default(), { V = 1 }), "A section without Sanitize/Encode/Apply is ignored")
	pass("Update4Profile: dispatch, unknown commands rejected, throwing sections contained, volatile whitelist, unloaded sections carried")
end

do
	-- The real file from src, as a workstream will see it before its section exists.
	local P = require("../src/common/ServerScriptService/Services/Data/Update4Profile")
	assert(type(P.Default) == "function" and P.Default().V == 1, "Update4Profile loads with plain require")
	pass("Update4Profile requires in plain Lune (sections present: " .. (function()
		local list = {}
		for _, name in P.SectionNames do
			if P.HasSection(name) then table.insert(list, name) end
		end
		return if #list > 0 then table.concat(list, ",") else "none yet"
	end)() .. ")")
end

----------------------------------------------------------------------
-- 4. ProfileCodec
----------------------------------------------------------------------
-- The codec with the stub dispatcher (every section present), QuestPeriod absent.
local function loadCodec(dispatcher)
	local env = {
		require = function(path)
			if path == "./Update4Profile" then return dispatcher end
			error("module not found: " .. path)
		end,
	}
	return luau.load(fs.readFile(DATA .. "ProfileCodec.luau"), { environment = env })()
end

do
	local P = loadDispatcher({ "Race", "Retention", "Titles", "Community" }, {})
	local Codec = loadCodec(P)
	local fresh = Codec.CreateDefault()
	assert(fresh.U4 and fresh.U4.V == 1 and fresh.U4.Race.Count == 0, "A new profile has U4 with every section")
	local new = Codec.Decode(nil)
	assert(new.ok and new.isNew and new.value.U4.Retention.Count == 0, "Decode(nil) too")

	local oldSave = { Version = 306, Speed = 500, Wins = 7, FutureFlag = { a = 1 } }
	local decoded = Codec.Decode(oldSave)
	assert(decoded.ok and equal(decoded.value.U4, P.Default()), "An old save decodes with every section's Default")
	assert(decoded.value.Update2PreservedFields.U4 == nil and decoded.value.Update2PreservedFields.FutureFlag, "U4 is a known field; other extensions are still preserved")
	local encoded = Codec.Encode(decoded.value)
	assert(encoded.U4.V == 1 and encoded.Speed == 500 and encoded.FutureFlag.a == 1, "Encode writes U4 and keeps extensions")

	local withU4 = { Version = 306, Speed = 1, U4 = { V = 1, Race = { Count = 4 }, Titles = { Count = "x" } } }
	local round = Codec.Decode(withU4)
	assert(round.ok and round.value.U4.Race.Count == 4 and round.value.U4.Titles.Count == 0, "Saved U4 is sanitized section by section")
	assert(round.value.Update2PreservedFields.U4 == nil, "...and never lands in Update2PreservedFields")
	local again = Codec.Decode(Codec.Encode(round.value))
	assert(equal(again.value.U4, round.value.U4), "U4 round-trips Encode -> Decode")

	-- Destiny + LateDestiny (inline cleaning while QuestPeriod is absent).
	local quests = Codec.Decode({ Version = 306, QuestState = {
		Destiny = { Period = 20000, Choice = 2, Targets = { speed = 10 }, Baseline = { speed = 0 }, Claimed = false, Complete = true },
		LateDestiny = { Period = 19999, Choice = 9, Claimed = "yes" },
	} })
	local qs = quests.value.QuestState
	assert(qs.Destiny.Complete == true and qs.Destiny.Choice == 2 and qs.Destiny.Targets.speed == 10, "Destiny keeps Complete")
	assert(qs.LateDestiny and qs.LateDestiny.Choice == 3 and qs.LateDestiny.Claimed == false, "LateDestiny is cleaned the same way")
	local qround = Codec.Decode(Codec.Encode(quests.value)).value.QuestState
	assert(equal(qround.Destiny, qs.Destiny) and equal(qround.LateDestiny, qs.LateDestiny), "Destiny/LateDestiny round-trip")
	assert(Codec.Decode({ Version = 306, QuestState = { Destiny = "bad" } }).value.QuestState.Destiny == nil, "A non-table Destiny is dropped")

	-- Without the dispatcher: no wrapper, and U4 travels raw in Update2PreservedFields.
	local bare = luau.load(fs.readFile(DATA .. "ProfileCodec.luau"), { environment = { require = function() error("missing") end } })()
	local kept = bare.Decode(withU4)
	assert(kept.ok and kept.value.U4 == nil and kept.value.Update2PreservedFields.U4, "No dispatcher: U4 is an unknown extension")
	assert(equal(bare.Encode(kept.value).U4, withU4.U4), "...and is written back untouched")
	pass("ProfileCodec: U4 known field, defaults for old saves, round trip, Destiny/LateDestiny, no-dispatcher fallback")
end

do
	-- The real src stack, through SessionActor and the mock store.
	local Actor = require("../src/common/ServerScriptService/Services/Data/SessionActor")
	local Adapter = require("../src/common/ServerScriptService/Services/Data/DataStoreAdapter")
	local Codec = require("../src/common/ServerScriptService/Services/Data/ProfileCodec")
	local now = 1790000000
	local clock = { UnixNow = function() return now end, MonotonicNow = function() return now end }
	local saved = { Version = 306, Speed = 12345, Wins = 67, FutureCompatibleFlag = { nested = { 7, 8 } },
		U4 = { V = 1, Race = { BestMs = 31000, Races = 3 }, Titles = { Pref = "member", Owned = { "member" } } } }
	local store = Adapter.CreateMock({ Player_1 = saved })
	local actor = Actor.new({ userId = 1, sessionId = "A", storeAdapter = store, clock = clock })
	local opened = actor:Open()
	assert(opened.ok, "Open")
	local profile = actor:Inspect(opened.value).value.profile
	assert(profile.U4 and profile.U4.V == 1, "The live profile has U4")
	assert(profile.Update2PreservedFields == nil or profile.Update2PreservedFields.U4 == nil, "...not as a preserved extension")
	assert(actor:Release(opened.value).kind == "Released", "Release")
	local persisted = store:GetData("Player_1")
	assert(persisted.U4 and persisted.U4.V == 1 and persisted.Speed == 12345 and persisted.FutureCompatibleFlag.nested[2] == 8, "Saved back with U4 and everything else")
	for _, name in { "Race", "Titles" } do
		if not Codec.Update4Profile.HasSection(name) then
			assert(equal(persisted.U4[name], saved.U4[name]), name .. ": data of a section not built yet survives the round trip")
		end
	end
	local oldStore = Adapter.CreateMock({ Player_2 = { Version = 306, Speed = 10 } })
	local a2 = Actor.new({ userId = 2, sessionId = "B", storeAdapter = oldStore, clock = clock })
	local h2 = a2:Open()
	assert(h2.ok and a2:Release(h2.value).kind == "Released", "Old save opens and releases")
	assert(equal(oldStore:GetData("Player_2").U4, Codec.Update4Profile.Default()), "An old save is written back with the U4 defaults")
	pass("SessionActor + real src codec: U4 persisted, old saves get defaults, unbuilt sections' data kept")
end

----------------------------------------------------------------------
-- 5. ProfileReducers
----------------------------------------------------------------------
do
	local calls = {}
	local P = loadDispatcher({ "Race", "Retention", "Titles", "Community" }, calls)
	local Codec = loadCodec(P)
	local Reducers = luau.load(fs.readFile(DATA .. "ProfileReducers.luau"), { environment = { require = function(path)
		if path == "./ProfileCodec" then return Codec end
		error("module not found: " .. path)
	end } })()
	local profile = Codec.CreateDefault()
	local r = Reducers.ApplyCommand(profile, { kind = "U4.Retention.Add" }, 99)
	assert(r.ok and profile.U4.Retention.Count == 1 and calls[1].section == "Retention", "U4.* reaches the dispatcher")
	local unknown = Reducers.ApplyCommand(profile, { kind = "U4.Shop.Buy" }, 99)
	assert(not unknown.ok and unknown.error.code == "InvalidInput", "Unknown U4 section rejected")
	local grant = Reducers.ApplyCommand(profile, { kind = "GrantExact", stat = "Wins", amount = 5 }, 99)
	assert(grant.ok and profile.Wins == 5, "Other kinds keep their reducers")
	local late = Reducers.ApplyCommand(profile, { kind = "ClaimLateQuestPath", period = 1 }, 99)
	assert(not late.ok and late.error.code == "InvalidInput", "ClaimLateQuestPath is refused while QuestPeriod is missing")

	-- The real src reducers.
	local Real = require("../src/common/ServerScriptService/Services/Data/ProfileReducers")
	local RealCodec = require("../src/common/ServerScriptService/Services/Data/ProfileCodec")
	local p = RealCodec.CreateDefault()
	local refused = Real.ApplyCommand(p, { kind = "U4.NoSuchSection.Op" }, 1)
	assert(not refused.ok and refused.error.code == "InvalidInput", "Real reducers: unknown U4 command rejected")
	local now = 1790000000 + 3600
	local period = Real.DailyQuestPeriod(now)
	assert(type(period) == "number", "The quest day is exposed")
	if RealCodec.QuestPeriod == nil then
		assert(period == math.floor(now / 86400), "Without QuestPeriod: midnight UTC as before")
	else
		assert(period == RealCodec.QuestPeriod.DailyPeriod(now), "With QuestPeriod: its day")
	end
	local chosen = Real.ApplyCommand(p, { kind = "ChooseQuestPath", period = period, choice = 1, targets = { speed = 10 } }, now)
	assert(chosen.ok, "ChooseQuestPath works on the wired quest day: " .. tostring(chosen.error and chosen.error.message))
	Real.AddQuestProgress(p, "speed", 10, now)
	local claimed = Real.ApplyCommand(p, { kind = "ClaimQuestPath", period = period }, now)
	assert(claimed.ok and p.QuestState.Destiny.Claimed, "ClaimQuestPath works on the wired quest day")
	pass("ProfileReducers: U4 routing, unknown rejected, M33 quest day wired (QuestPeriod " .. (if RealCodec.QuestPeriod then "present" else "absent, fallback") .. ")")
end

----------------------------------------------------------------------
-- 6. FunnelAnalytics
----------------------------------------------------------------------
local function loadFunnels(mode)
	local logged, custom = {}, {}
	local function signal()
		local s = { list = {} }
		function s:Connect(fn) table.insert(self.list, fn); return { Disconnect = function() end } end
		function s:Fire(...) for _, fn in self.list do fn(...) end end
		return s
	end
	local function object(class, name)
		local o = { __mock = true, ClassName = class, Name = name, children = {}, attrs = {} }
		function o:IsA(c) return self.ClassName == c end
		function o:FindFirstChild(n) return self.children[n] end
		function o:GetAttribute(k) return self.attrs[k] end
		function o:GetAttributeChangedSignal() return signal() end
		return o
	end
	local players = object("Players", "Players")
	players.PlayerAdded, players.PlayerRemoving = signal(), signal()
	function players:GetPlayers() return {} end
	local replicated = object("ReplicatedStorage", "ReplicatedStorage")
	local analytics = object("AnalyticsService", "AnalyticsService")
	function analytics:LogFunnelStepEvent(player, funnel, session, step, stepName)
		table.insert(logged, { Funnel = funnel, Session = session, Step = step, Name = stepName })
	end
	function analytics:LogCustomEvent(player, name, value, fields)
		if mode == "throw" then error("down") end
		table.insert(custom, { Name = name, Value = value, Fields = fields })
	end
	local game = { GetService = function(_, name)
		if name == "Players" then return players end
		if name == "ReplicatedStorage" then return replicated end
		if name == "AnalyticsService" then return analytics end
		error("unexpected " .. name)
	end }
	local env = {
		game = game,
		typeof = function(v) if type(v) == "table" and v.__mock then return "Instance" end return typeof(v) end,
		Instance = { new = function(class)
			local o = object(class, class)
			if class == "RemoteEvent" then o.OnServerEvent = signal() end
			return setmetatable(o, { __newindex = function(self, k, v)
				rawset(self, k, v)
				if k == "Parent" and v then v.children[self.Name] = self end
			end })
		end },
		task = { spawn = function(fn, ...) fn(...) end, defer = function(fn, ...) fn(...) end },
		warn = function() end,
	}
	local module = luau.load(fs.readFile(FUNNELS), { environment = env })()
	local nextId = 100
	local function newPlayer()
		nextId += 1
		local p = object("Player", "P" .. nextId)
		p.UserId = nextId
		p.Parent = players
		return p
	end
	return { Module = module, Logged = logged, Custom = custom, NewPlayer = newPlayer, Replicated = replicated }
end

do
	local t = loadFunnels("record")
	local F = t.Module
	local expected = {
		Engagement_Race = 4, Onboarding_Race = 5, Retention_Streak = 3, Retention_PlaytimeBoost = 4,
		Engagement_Titles = 2, Community_Reward = 3,
	}
	for funnel, steps in expected do
		assert(F.Funnels[funnel] and #F.Funnels[funnel] == steps, funnel .. " has " .. steps .. " steps")
	end
	local pass0 = F.Funnels.Monetization_StaminaPass
	assert(pass0[0] == "OfferVisible" and pass0[1] == "Clicked" and pass0[2] == "PromptShown" and pass0[3] == "Purchased", "StaminaPass steps 0-3")
	for _, funnel in { "Engagement_Race", "Retention_Streak", "Retention_PlaytimeBoost", "Engagement_Titles" } do
		assert(F.Recurring[funnel], funnel .. " is recurring")
	end
	for _, funnel in { "Onboarding_Race", "Community_Reward", "Monetization_StaminaPass" } do
		assert(not F.Recurring[funnel], funnel .. " is one-time")
	end
	assert(count(F.ClientSteps) == 3 and count(F.ClientSteps.Onboarding_Race) == 1 and F.ClientSteps.Onboarding_Race[1], "Client: Onboarding_Race step 1 only")
	assert(count(F.ClientSteps.Monetization_StaminaPass) == 3 and not F.ClientSteps.Monetization_StaminaPass[3], "Client: StaminaPass 0-2, never the purchase")

	-- Engagement_Race: a session per queue join, each step after the one before it.
	local p = t.NewPlayer()
	local s1 = F.NewSession(p, "Engagement_Race")
	for step = 1, 4 do
		assert(F.Step(p, "Engagement_Race", step, s1), "Race step " .. step)
	end
	for i, name in { "Queued", "Started", "Finished", "Rewarded" } do
		assert(t.Logged[i].Funnel == "Race_Loop_v2" and t.Logged[i].Step == i and t.Logged[i].Name == name and t.Logged[i].Session == s1, "Race_Loop_v2 step " .. i)
	end
	local s2 = F.NewSession(p, "Engagement_Race")
	assert(s2 ~= s1, "A new session per join")
	assert(not F.Step(p, "Engagement_Race", 3, s2), "Finished without Started is not logged")
	assert(#t.Logged == 4, "...nor sent")
	assert(F.Step(p, "Engagement_Race", 1, s2) and F.Step(p, "Engagement_Race", 2, s2) and F.Step(p, "Engagement_Race", 3, s2), "...and still counts once its turn comes")

	-- Onboarding_Race: never for a runner who already finished a race.
	local veteran = t.NewPlayer()
	veteran.attrs.RaceFinishes = 3
	assert(not F.Step(veteran, "Onboarding_Race", 1) and not F.Step(veteran, "Onboarding_Race", 2), "Veterans are not in the first-race funnel")
	-- 2026-09-25 (final fix): step 1 waits for the data and the projected RaceFinishes.
	local loading = t.NewPlayer()
	assert(not F.Step(loading, "Onboarding_Race", 1), "Step 1 before DataLoaded / RaceFinishes is not logged")
	local rookie = t.NewPlayer()
	rookie.attrs.DataLoaded, rookie.attrs.RaceFinishes = true, 0
	local before = #t.Logged
	assert(F.Step(rookie, "Onboarding_Race", 1) and F.Step(rookie, "Onboarding_Race", 2) and not F.Step(rookie, "Onboarding_Race", 4), "Rookie: 1, 2, and not 4 before 3")
	assert(#t.Logged == before + 2 and t.Logged[before + 2].Funnel == "Race_FirstRace_v2" and t.Logged[before + 2].Name == "FirstQueued", "Race_FirstRace_v2 names")

	-- Retention_Streak: one session per UTC day.
	local streak = F.NewSession(p, "Retention_Streak")
	assert(string.match(streak, "^" .. p.UserId .. "%-streak%-%d+$") and F.NewSession(p, "Retention_Streak") == streak, "Streak session = <uid>-streak-<utcDay>")
	assert(not F.Step(p, "Retention_Streak", 2), "Panel before check-in is not logged")
	assert(F.Step(p, "Retention_Streak", 1) and F.Step(p, "Retention_Streak", 2) and F.Step(p, "Retention_Streak", 3), "Check-in, panel, milestone")

	-- Playtime: explicit session, any order.
	local pt = p.UserId .. "-pt-1790000000"
	assert(F.Step(p, "Retention_PlaytimeBoost", 3, pt) and F.Step(p, "Retention_PlaytimeBoost", 1, pt), "Playtime steps need no order")
	assert(t.Logged[#t.Logged].Session == pt and t.Logged[#t.Logged].Funnel == "Playtime_Session_v2", "...and carry the passed session")

	-- Titles and Community.
	assert(not F.Step(p, "Engagement_Titles", 2, F.NewSession(p, "Engagement_Titles")), "Equip without opening is not logged")
	local titles = F.NewSession(p, "Engagement_Titles")
	assert(F.Step(p, "Engagement_Titles", 1, titles) and F.Step(p, "Engagement_Titles", 2, titles), "Titles opened -> equipped")
	assert(not F.Step(p, "Community_Reward", 3), "Claimed without trying is not logged")
	assert(F.Step(p, "Community_Reward", 1) and F.Step(p, "Community_Reward", 2) and F.Step(p, "Community_Reward", 3), "Community opened -> tried -> claimed")

	-- Stamina pass: like the Starter Pack; ownership is logged whatever the path.
	local buyer = t.NewPlayer()
	local customBefore = #t.Custom
	local stepsBefore = #t.Logged
	assert(F.Step(buyer, "Monetization_StaminaPass", 3), "A purchase without a tracked offer")
	assert(#t.Logged == stepsBefore and t.Custom[customBefore + 1].Name == "StaminaPass_Ownership_v2", "...logs ownership only, never a false OfferToBuy step 4")

	-- Client whitelist through the FunnelReport remote.
	local report = t.Replicated.children.Remotes.children.FunnelReport
	local client = t.NewPlayer()
	client.attrs.DataLoaded, client.attrs.RaceFinishes = true, 0
	local n = #t.Logged
	report.OnServerEvent:Fire(client, "Monetization_StaminaPass", 3)
	report.OnServerEvent:Fire(client, "Onboarding_Race", 2)
	report.OnServerEvent:Fire(client, "Engagement_Race", 1)
	assert(#t.Logged == n, "The client cannot report purchases, race progress or the race loop")
	report.OnServerEvent:Fire(client, "Onboarding_Race", 1)
	report.OnServerEvent:Fire(client, "Monetization_StaminaPass", 0)
	report.OnServerEvent:Fire(client, "Monetization_StaminaPass", 1)
	report.OnServerEvent:Fire(client, "Monetization_StaminaPass", 2)
	assert(#t.Logged == n + 4 and t.Logged[n + 1].Name == "Discovered" and t.Logged[n + 4].Name == "PromptOpened", "Client: discovery and the pass offer/click/prompt")
	pass("FunnelAnalytics: 7 Update 4 funnels, routes, strict sequencing, veterans out of Onboarding_Race, client whitelist")

	-- Event: every §2.6 custom event, and nothing else.
	local plan = read(PLAN)
	local paragraph = string.match(plan, "Custom events via new `FunnelAnalytics%.Event[^\n]*")
	assert(paragraph, "PLAN §2.6 custom event list found")
	local names = {}
	for name in string.gmatch(paragraph, "`([%w_]+_v2)`") do
		table.insert(names, name)
	end
	assert(#names == 19, "19 custom events in §2.6 (found " .. #names .. ")")
	local ev = t.NewPlayer()
	for _, name in names do
		assert(F.Event(ev, name, 2, { [1] = "x" }) == true, name .. " is whitelisted")
	end
	local last = t.Custom[#t.Custom]
	assert(last.Name == names[#names] and last.Value == 2 and last.Fields[1] == "x", "Event passes value and fields")
	assert(F.Event(ev, "Race_Join_Gate_v2") and t.Custom[#t.Custom].Value == 1, "value defaults to 1")
	assert(F.Event(ev, "Race_Join_Gate_v2", 0 / 0) and t.Custom[#t.Custom].Value == 1, "NaN value becomes 1")
	assert(not F.Event(ev, "Totally_Made_Up_v2") and not F.Event(nil, "Race_Join_Gate_v2") and not F.Event({ Name = "fake" }, "Race_Join_Gate_v2") and not F.Event(ev, 5), "Unknown names and players are refused")
	local broken = loadFunnels("throw")
	local okCall, result = pcall(broken.Module.Event, broken.NewPlayer(), "Race_Correction_v2")
	assert(okCall and result == true, "A failing AnalyticsService never reaches the caller")
	pass("FunnelAnalytics.Event: all 19 §2.6 custom events whitelisted, value/fields passed, unknown refused, never throws")
end

----------------------------------------------------------------------
-- 7. Lists
----------------------------------------------------------------------
do
	local menu = read(MENU_EVENTS)
	local names = string.match(menu, "local MENU_EVENT_NAMES = (%b{})")
	local guis = string.match(menu, "local MENU_TO_GUI = (%b{})")
	for key, event in { Titles = "OpenTitlesPanel", Streak = "OpenStreakPanel", PlaytimeBoost = "OpenPlaytimeBoostPanel", Community = "OpenCommunityPanel", Race = "OpenRacePanel" } do
		has(names, key .. ' = "' .. event .. '"', "MENU_EVENT_NAMES." .. key)
	end
	for key, gui in { Titles = "Titles", Streak = "Streak Rewards", PlaytimeBoost = "Playtime Boost", Community = "Community rewards", Race = "RacePanelGui" } do
		has(guis, key .. ' = "' .. gui .. '"', "MENU_TO_GUI." .. key)
	end
	local juice = string.match(read(MODAL_JUICE), "local MODAL_MAIN_FRAMES = (%b{})")
	for _, entry in { '["Playtime Boost"] = { "Playtime Boost" }', '["Streak Rewards"] = { "Streak Rewards" }',
		'["Community rewards"] = { "Community rewards" }', 'Titles = { "Titles" }', 'RacePanelGui = { "Window" }', 'RaceResults = { "Window" }' } do
		has(juice, entry, "ModalJuice")
	end
	local console = string.match(read(CONSOLE), "local MANAGED_MENUS = (%b{})")
	local hud = string.match(read(MAIN_HUD), "local MODAL_SCREEN_GUIS = (%b{})")
	for _, gui in { "Titles", "Streak Rewards", "Playtime Boost", "Community rewards", "RacePanelGui", "RaceResults" } do
		has(console, '["' .. gui .. '"] = true', "ConsoleUiScale MANAGED_MENUS")
		has(hud, '"' .. gui .. '",', "MainHUD MODAL_SCREEN_GUIS")
	end
	pass("MenuEvents / ModalJuice / ConsoleUiScale / MainHUDController list the 6 Update 4 panels")
end

print(string.format("ALL U4 CONTRACT CHECKS PASSED (%d)", passed))
