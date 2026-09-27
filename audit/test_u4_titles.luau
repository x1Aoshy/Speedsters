-- test_u4_titles.luau (Update 4, titles_boards, 2026-09-25)
-- The titles' data side (output/Update4/PLAN.md §7.6):
--   1. Shared/TitleCatalog: ids unique and ^[a-z0-9_]+$, tabs/styles/templates valid, staff
--      priorities ordered, only Staff and #1 titles animate, rank tiers (rank 3 owns top 5 and
--      top 10), staff by UserId / player.Name only, Resolve ("" auto, "none", owned id), unlock hints;
--   2. Services/Data/U4/TitlesSection: Default / Sanitize / Encode / Apply (Grant idempotent and
--      never failing a reward Commit on a full list, Owned <= 40, SetPref ^[a-z0-9_]*$ <= 32,
--      Revoke), and through the integrator's Update4Profile dispatcher;
--   3. audit/u4_title_templates: Plain (no emitters) / Gold (2 gold emitters) / Owner in
--      ReplicatedStorage.Titles, idempotent, refuses an unstamped template (in memory, on copies
--      of the 3 places; "places" checks the built places on disk instead);
--   4. static: OverheadStats reads TitleStyle and has no literal "Tester" assignment;
--      TitlesController indexes the duplicated row labels by order.
-- Run: lune run audit/test_u4_titles.luau [places]   (from the project root)
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local CATALOG = "src/common/ReplicatedStorage/Shared/TitleCatalog.luau"
local SECTION = "src/common/ServerScriptService/Services/Data/U4/TitlesSection.luau"
local OVERHEAD = "src/common/StarterPlayer/StarterPlayerScripts/UI/OverheadStats.client.luau"
local CONTROLLER = "src/common/StarterPlayer/StarterPlayerScripts/UI/TitlesController.client.luau"
local PLACES = {
	{ key = "World1", file = "World1Update3New.rbxl" },
	{ key = "World2", file = "World2Update3new.rbxl" },
	{ key = "World3", file = "World3Update3New.rbxl" },
}
local PLACES_MODE = process.args[1] == "places"

local passed = 0
local function pass(text)
	passed += 1
	print("PASS " .. text)
end
local function read(path)
	return (fs.readFile(path):gsub("\r\n", "\n"))
end

for _, path in { CATALOG, SECTION, OVERHEAD, CONTROLLER,
	"src/common/ServerScriptService/Services/Titles/TitleService.luau",
	"src/common/ServerScriptService/Social/TitleSystem.server.luau",
	"audit/u4_title_templates.luau", "audit/u4_race_board.luau" } do
	local ok, problem = pcall(luau.compile, fs.readFile(path))
	assert(ok, "SYNTAX " .. path .. ": " .. tostring(problem))
end
pass("every titles source compiles")

local Catalog = require("../src/common/ReplicatedStorage/Shared/TitleCatalog")
local Section = require("../src/common/ServerScriptService/Services/Data/U4/TitlesSection")
local U4 = require("../src/common/ReplicatedStorage/Shared/Update4Config")

----------------------------------------------------------------------
-- 1. TitleCatalog
----------------------------------------------------------------------
do
	local seen, tabs = {}, {}
	for _, tab in Catalog.Tabs do
		tabs[tab] = true
	end
	assert(#Catalog.Entries == 21, "21 titles (owner..member), got " .. #Catalog.Entries)
	for _, entry in Catalog.Entries do
		assert(string.match(entry.Id, "^[a-z0-9_]+$") and #entry.Id <= 32, "bad id " .. entry.Id)
		assert(not seen[entry.Id], "duplicate id " .. entry.Id)
		seen[entry.Id] = true
		assert(tabs[entry.Tab], entry.Id .. " tab " .. tostring(entry.Tab))
		assert(Catalog.Styles[entry.Style], entry.Id .. " style " .. tostring(entry.Style))
		assert(Catalog.Templates[entry.Template], entry.Id .. " template " .. tostring(entry.Template))
		assert(type(entry.Text) == "string" and entry.Text ~= "", entry.Id .. " text")
		assert(type(entry.Colors) == "table" and #entry.Colors >= 1 and #entry.Colors[1] == 3, entry.Id .. " colours")
		for _, lang in { "en", "es", "pt" } do
			assert(type(entry.Unlock[lang]) == "string" and entry.Unlock[lang] ~= "", entry.Id .. " unlock " .. lang)
		end
		-- Only Staff and #1 titles animate (phones are render-bound).
		local animated = entry.Style ~= "static"
		assert(animated == (entry.Tab == "Staff" or entry.Top == 1), entry.Id .. " animates = " .. tostring(animated))
		assert(Catalog.ById[entry.Id] == entry, entry.Id .. " ById")
	end
	for _, id in { "owner", "developer", "content_creator", "tester", "speed_top1", "speed_top5", "speed_top10",
		"wins_top1", "wins_top5", "wins_top10", "race_top1", "race_top5", "race_top10", "race_winner",
		"race_champion", "race_legend", "lightning_start", "member", "streak_7", "streak_21", "vip" } do
		assert(seen[id], "missing " .. id)
	end
	-- Every title another workstream grants is a catalog marker.
	for _, id in U4.Race.Titles.WinTitles do
		assert(Catalog.IsMarker(id), id .. " must be grantable by the race server")
	end
	assert(Catalog.IsMarker(U4.Race.Titles.PerfectTitle.Id))
	assert(Catalog.IsMarker(U4.Streak.Milestones.First[7].TitleId) and Catalog.IsMarker(U4.Streak.Milestones.First[21].TitleId))
	assert(Catalog.IsMarker(U4.Community.TitleId))
	assert(Catalog.IsGrantable("content_creator") and Catalog.IsGrantable("member"))
	assert(not Catalog.IsGrantable("race_winner") and not Catalog.IsMarker("speed_top1") and not Catalog.IsMarker("developer"))
	pass("catalog: 21 unique ids, valid tabs/styles/templates, only Staff and #1 animate, granted ids are markers")

	local p = function(id)
		return Catalog.ById[id].Priority
	end
	assert(p("owner") > p("developer") and p("developer") > p("content_creator") and p("content_creator") > p("tester"))
	for _, entry in Catalog.Entries do
		if entry.Tab ~= "Staff" then
			assert(entry.Priority < p("tester"), entry.Id .. " must rank below every staff title")
		end
	end
	pass("staff priorities: owner > developer > content_creator > tester > everything else")

	local function set(list)
		local out = {}
		for _, id in list do
			out[id] = true
		end
		return out
	end
	local r3 = set(Catalog.RankTitles("Speed", 3))
	assert(r3.speed_top5 and r3.speed_top10 and not r3.speed_top1 and not r3.wins_top10, "rank 3 on Speed")
	local r1 = set(Catalog.RankTitles("Race", 1))
	assert(r1.race_top1 and r1.race_top5 and r1.race_top10)
	assert(#Catalog.RankTitles("Wins", 11) == 0 and #Catalog.RankTitles("Wins", nil) == 0 and #Catalog.RankTitles("Wins", 0) == 0)
	assert(Catalog.TierFor(1) == 1 and Catalog.TierFor(3) == 5 and Catalog.TierFor(10) == 10 and Catalog.TierFor(11) == nil
		and Catalog.TierFor(nil) == nil and Catalog.TierFor(0 / 0) == nil)
	pass("rank tiers: rank r owns every tier with top >= r")

	local cfg = U4.Titles
	local gekkoh = Catalog.StaffTitles({ UserId = 767108248, Name = "Gekkoh" }, cfg)
	-- 2026-09-26 (owner): Gekkoh is no longer forced to DEV; he owns OWNER and wears his own choice.
	assert(gekkoh.owner and not gekkoh.developer, "UserId 767108248 is the owner (OwnerUserIds), not DEV")
	local dev = Catalog.StaffTitles({ UserId = 111827288, Name = "pxuto" }, cfg)
	assert(dev.developer and not dev.owner, "UserId 111827288 is DEV only")
	local spoof = Catalog.StaffTitles({ UserId = 42, Name = "randomkid" }, cfg) -- DisplayName "gekkoh" is never read
	assert(next(spoof) == nil, "a DisplayName can not buy a staff title")
	local tester = Catalog.StaffTitles({ UserId = 43, Name = "Himothy09871" }, cfg)
	assert(tester.tester and not tester.developer, "tester by player.Name, any case")
	local creator = Catalog.StaffTitles({ UserId = 44, Name = "x", IsGameOwner = true }, cfg)
	assert(creator.owner, "the game creator is OWNER")
	pass("staff titles: by UserId or player.Name only; the game creator is OWNER")

	local owned = { developer = true, tester = true, speed_top5 = true, speed_top10 = true }
	assert(Catalog.Resolve("", owned) == "developer", "auto = best staff")
	assert(Catalog.Resolve("none", owned) == nil, "none = nothing")
	assert(Catalog.Resolve("speed_top5", owned) == "speed_top5")
	assert(Catalog.Resolve("speed_top1", owned) == "developer", "an id not owned falls back to auto")
	assert(Catalog.Resolve("", { speed_top5 = true }) == nil, "auto shows only staff titles")
	assert(Catalog.Resolve("bogus", {}) == nil)
	local sorted = Catalog.Sorted({ vip = true, member = true }, "member")
	assert(sorted[1].Id == "member" and sorted[2].Id == "vip", "equipped first, then owned")
	assert(#Catalog.Sorted({}, nil, "Staff") == 4 and #Catalog.Sorted({}, nil, "Leaderboards") == 9)
	pass("resolve: \"\" = best staff title, \"none\" = nothing, owned id = it; panel sort and tabs")

	local speed10 = Catalog.ById.speed_top10
	assert(Catalog.UnlockText(speed10, "en", { Have = 57, Need = 10 }) == "Reach Top 10 Speed (you are #57)")
	assert(Catalog.UnlockText(speed10, "es", { Have = 0, Need = 10 }) == "Llega al Top 10 de Velocidad (aún sin puesto)")
	assert(Catalog.UnlockText(Catalog.ById.race_champion, "pt", { Have = 3, Need = 25 }) == "Vença 25 corridas (3/25)")
	assert(Catalog.UnlockText(Catalog.ById.race_champion, "fr", nil) == "Win 25 races", "unknown language = en")
	assert(Catalog.IsValidPreference("") and Catalog.IsValidPreference("none") and not Catalog.IsValidPreference("Bad-Id")
		and not Catalog.IsValidPreference(string.rep("a", 33)) and not Catalog.IsValidPreference(5))
	pass("unlock hints with live numbers (en/es/pt, fallback en); preference validation")
end

----------------------------------------------------------------------
-- 2. TitlesSection (and through Update4Profile)
----------------------------------------------------------------------
do
	local default = Section.Default()
	assert(default.Pref == "" and #default.Owned == 0)
	local messy = { Pref = "Bad Pref!", Owned = { "race_winner", "race_winner", 5, "UPPER", string.rep("a", 33), 0 / 0, "member" } }
	local clean = Section.Sanitize(messy)
	assert(clean.Pref == "" and #clean.Owned == 2 and clean.Owned[1] == "race_winner" and clean.Owned[2] == "member",
		"sanitize drops bad ids, duplicates and a bad pref")
	local many = {}
	for i = 1, 60 do
		table.insert(many, "t" .. i)
	end
	assert(#Section.Sanitize({ Owned = many }).Owned == 40, "Owned is capped at 40")
	for _, raw in { nil, 5, "x", { Owned = "x", Pref = 7 } } do
		local s = Section.Sanitize(raw)
		assert(s.Pref == "" and #s.Owned == 0)
	end
	local encoded = Section.Encode({ Pref = "none", Owned = { "member" } })
	assert(encoded.Pref == "none" and encoded.Owned[1] == "member")
	local round = Section.Sanitize(Section.Encode(clean))
	assert(round.Pref == clean.Pref and #round.Owned == #clean.Owned)
	pass("section Default / Sanitize (types, duplicates, <= 40) / Encode round trip")

	local state = Section.Default()
	local r = Section.Apply(state, "Grant", { id = "race_winner" }, 0)
	assert(r.ok and r.value == true and state.Owned[1] == "race_winner")
	r = Section.Apply(state, "Grant", { id = "race_winner" }, 0)
	assert(r.ok and r.value == false and #state.Owned == 1, "Grant is idempotent")
	r = Section.Apply(state, "Grant", { id = "speed_top1" }, 0)
	assert(not r.ok and r.error.code == "InvalidInput", "a live rank title is never stored")
	r = Section.Apply(state, "Grant", { id = "Bad Id" }, 0)
	assert(not r.ok)
	local full = { Pref = "", Owned = {} }
	for i = 1, 40 do
		full.Owned[i] = "old" .. i
	end
	r = Section.Apply(full, "Grant", { id = "member" }, 0)
	assert(r.ok and r.value == false and #full.Owned == 40, "a full list keeps what it has without failing the Commit")
	r = Section.Apply(state, "Revoke", { id = "race_winner" }, 0)
	assert(r.ok and r.value == true and #state.Owned == 0)
	r = Section.Apply(state, "Revoke", { id = "race_winner" }, 0)
	assert(r.ok and r.value == false)
	r = Section.Apply(state, "SetPref", { pref = "speed_top5" }, 0)
	assert(r.ok and state.Pref == "speed_top5")
	for _, bad in { "Speed", string.rep("a", 33), 7, "a-b" } do
		r = Section.Apply(state, "SetPref", { pref = bad }, 0)
		assert(not r.ok and state.Pref == "speed_top5", "bad pref " .. tostring(bad))
	end
	assert(Section.Apply(state, "SetPref", { pref = "" }, 0).ok and state.Pref == "")
	assert(not Section.Apply(state, "Explode", {}, 0).ok)
	pass("section Apply: Grant idempotent / markers only / full list ok, Revoke, SetPref pattern and length")

	local Profile = require("../src/common/ServerScriptService/Services/Data/Update4Profile")
	assert(Profile.HasSection("Titles"), "the dispatcher loads TitlesSection")
	local profile = { U4 = Profile.Default() }
	assert(profile.U4.Titles.Pref == "" and #profile.U4.Titles.Owned == 0)
	local result = Profile.Apply(profile, { kind = "U4.Titles.Grant", id = "streak_7" }, 0)
	assert(result.ok and profile.U4.Titles.Owned[1] == "streak_7")
	assert(Profile.IsVolatile("U4.Titles.SetPref") and not Profile.IsVolatile("U4.Titles.Grant"))
	local saved = Profile.Sanitize(Profile.Encode(profile.U4))
	assert(saved.Titles.Owned[1] == "streak_7")
	pass("Update4Profile dispatches U4.Titles.* to the section and round-trips it")
end

----------------------------------------------------------------------
-- 3. Title templates (u4_title_templates)
----------------------------------------------------------------------
do
	local Templates = require("./u4_title_templates")
	local function checkFolder(folder, label)
		assert(folder, label .. ": ReplicatedStorage.Titles")
		for _, name in { "Dev", "Tester", "Plain", "Gold", "Owner" } do
			local part = folder:FindFirstChild(name)
			assert(part and part:IsA("BasePart"), label .. ": Titles." .. name)
			assert(Templates._internal.label(part), label .. ": Titles." .. name .. " keeps Title/BillboardGui/Title")
		end
		assert(#Templates._internal.emitters(folder.Plain) == 0, label .. ": Plain has no particles")
		local gold = Templates._internal.emitters(folder.Gold)
		assert(#gold == 2, label .. ": Gold keeps 2 emitters")
		for _, emitter in gold do
			local c = emitter.Color.Keypoints[1].Value
			assert(math.abs(c.R - 1) < 0.01 and math.abs(c.G - 211 / 255) < 0.01 and c.B < 0.2, label .. ": gold emitters")
		end
		for _, name in Templates.Names do
			assert(folder[name]:GetAttribute("U4Asset") == Templates.Stamp, label .. ": " .. name .. " stamped")
		end
	end
	for _, place in PLACES do
		local dm = roblox.deserializePlace(fs.readFile(place.file))
		local folder = dm:GetService("ReplicatedStorage"):FindFirstChild("Titles")
		if PLACES_MODE then
			checkFolder(folder, place.key .. " (built)")
		else
			local notes = {}
			assert(Templates.Insert(dm, notes) == 3 and #notes == 1)
			checkFolder(folder, place.key)
			assert(Templates.Insert(dm, {}) == 3, "idempotent")
			local count = 0
			for _, child in folder:GetChildren() do
				if child.Name == "Plain" or child.Name == "Gold" or child.Name == "Owner" then
					count += 1
				end
			end
			assert(count == 3, place.key .. ": one of each after two inserts")
			folder.Plain:SetAttribute("U4Asset", nil)
			assert(not pcall(Templates.Insert, dm, {}), "an unstamped Plain stops the build")
		end
	end
	pass(if PLACES_MODE then "the 3 built places carry Plain/Gold/Owner" else "templates: Plain/Gold/Owner inserted in all 3 places, idempotent, unstamped refused")
end

----------------------------------------------------------------------
-- 4. Static checks
----------------------------------------------------------------------
do
	local overhead = read(OVERHEAD)
	assert(not string.find(overhead, 'Text%s*=%s*"Tester"'), "OverheadStats must not hard-code the Tester text")
	assert(string.find(overhead, 'GetAttribute("TitleStyle")', 1, true), "OverheadStats reads TitleStyle")
	assert(string.find(overhead, 'GetAttribute("TitleText")', 1, true), "OverheadStats reads TitleText")
	assert(string.find(overhead, 'style == "static"', 1, true), "static titles get no tween/thread")
	local controller = read(CONTROLLER)
	assert(not string.find(controller, 'FindFirstChild%("Title"'), "row labels are indexed by order")
	for _, needle in { 'MenuEvents.MarkReady("Titles"', 'MenuEvents.Listen("Titles"', "MenuPanelLayout.BindPhoneFit(gui, frame",
		"ConsolePanelSupport.Bind(", 'request("Get")', 'request("Seen")', 'request("Equip"', 'TitlesRequest:FireServer(nextRequest[1]', "TutorialText.ForPlayer",
		"MenuPanelLayout.ScaleChain(scroll)", "words.Tabs[", "words.Header" } do
		assert(string.find(controller, needle, 1, true), "TitlesController: " .. needle)
	end
	for _, lang in { "en", "es", "pt" } do
		local words = Catalog.Words[lang]
		assert(type(words.Header) == "string" and words.Header ~= "", lang .. " header")
		for _, tab in Catalog.Tabs do
			assert(type(words.Tabs[tab]) == "string" and words.Tabs[tab] ~= "", lang .. " tab " .. tab)
		end
	end
	pass("static: OverheadStats is driven by TitleStyle/TitleText; TitlesController wiring, header/tabs localised")
end

print(string.format("test_u4_titles: %d checks passed", passed))
