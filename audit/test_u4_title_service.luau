-- test_u4_title_service.luau (Update 4, titles_boards, 2026-09-25)
-- Services/Titles/TitleService with stubbed Players / DataService / FunnelAnalytics (PLAN §7.6):
--   board rank 3 on Speed owns top5 + top10 (not top1); losing the rank drops EquippedTitle back
--   to auto while the preference is kept, and the title returns with the rank; "" shows only
--   staff titles; "none" shows nothing; a locked or malformed Equip is refused; a DisplayName
--   cannot pose as staff (UserId 767108248 is OWNER, not DEV since 2026-09-26); Equip is a volatile write (ApplyVolatile, no
--   Commit); Grant commits "u4title:<id>" for markers only, counts the notice and toasts; the
--   feature switch empties the attributes; Visual and _G.SpeedsterTitles; TitlesUpdate is sent
--   only when something changed.
-- The profile commands run through the real Update4Profile + TitlesSection.
-- Run: lune run audit/test_u4_title_service.luau   (from the project root)
local luau = require("@lune/luau")
local fs = require("@lune/fs")

local SERVICE = "src/common/ServerScriptService/Services/Titles/TitleService.luau"
assert(pcall(luau.compile, fs.readFile(SERVICE)), "TitleService compiles")

local TitleService = require("../src/common/ServerScriptService/Services/Titles/TitleService")
local Catalog = require("../src/common/ReplicatedStorage/Shared/TitleCatalog")
local Update4Profile = require("../src/common/ServerScriptService/Services/Data/Update4Profile")
local U4 = require("../src/common/ReplicatedStorage/Shared/Update4Config")

local passed = 0
local function pass(text)
	passed += 1
	print("PASS " .. text)
end

-- Stubs --------------------------------------------------------------------------------------
local function newPlayer(userId, name, displayName)
	local attributes = {}
	local player = { UserId = userId, Name = name, DisplayName = displayName or name, Parent = "Players" }
	function player:GetAttribute(key)
		return attributes[key]
	end
	function player:SetAttribute(key, value)
		attributes[key] = value
	end
	return player
end

local players = {}
local PlayersStub = {}
function PlayersStub:GetPlayers()
	return players
end

local profiles, commits, volatiles = {}, {}, {}
local DataStub = {}
function DataStub.GetHandle(userId)
	return if profiles[userId] then { userId = userId } else nil
end
local inspects = 0
function DataStub.Inspect(handle)
	inspects += 1
	return { ok = true, value = { profile = profiles[handle.userId] } }
end
local committedIds = {}
function DataStub.Commit(handle, request)
	table.insert(commits, request)
	if committedIds[request.operationId] then
		return { kind = "AlreadyCommitted" }
	end
	for _, command in request.commands do
		local result = Update4Profile.Apply(profiles[handle.userId], command, os.time())
		if not result.ok then
			return { kind = "Rejected", error = result.error }
		end
	end
	committedIds[request.operationId] = true
	return { kind = "Committed" }
end
function DataStub.ApplyVolatile(handle, command)
	table.insert(volatiles, command)
	assert(Update4Profile.IsVolatile(command.kind), "only volatile kinds go through ApplyVolatile")
	return Update4Profile.Apply(profiles[handle.userId], command, os.time())
end

local steps = {}
local Funnels = {
	Step = function(player, funnel, step)
		table.insert(steps, { player.UserId, funnel, step })
		return true
	end,
	NewSession = function(player, funnel)
		table.insert(steps, { player.UserId, funnel, "session" })
		return "s"
	end,
}

local sent, toasts = {}, {}
local UpdateRemote = {}
function UpdateRemote:FireClient(player, payload)
	table.insert(sent, { player = player, payload = payload })
end
local ToastRemote = {}
function ToastRemote:FireClient(player, payload)
	table.insert(toasts, { player = player, payload = payload })
end

local featureOn = true
local U4Stub = setmetatable({
	IsOn = function(feature)
		return featureOn and feature == "Titles"
	end,
}, { __index = U4 })
local Color3Stub = {
	fromRGB = function(r, g, b)
		return { R = r, G = g, B = b }
	end,
}
local ownerUserId = 1
-- Equip's cooldown clock: every read moves 5 s on, unless a check freezes it (clockStep = 0).
local fakeClock, clockStep = 0, 5

TitleService._Reset()
TitleService.Configure({
	Players = PlayersStub,
	DataService = DataStub,
	FunnelAnalytics = Funnels,
	U4 = U4Stub,
	Catalog = Catalog,
	UpdateRemote = UpdateRemote,
	ToastRemote = ToastRemote,
	IsGameOwner = function(player)
		return player.UserId == ownerUserId
	end,
	Color3 = Color3Stub,
	wait = function() end,
	clock = function()
		fakeClock += clockStep
		return fakeClock
	end,
})
_G.SpeedsterTitles = nil
TitleService.Start()

local function join(userId, name, displayName)
	local player = newPlayer(userId, name, displayName)
	profiles[userId] = { U4 = Update4Profile.Default() }
	table.insert(players, player)
	TitleService.ComputeStaff(player)
	TitleService.Refresh(player)
	return player
end

----------------------------------------------------------------------
do
	assert(type(_G.SpeedsterTitles) == "table" and _G.SpeedsterTitles.Refresh == TitleService.Refresh
		and _G.SpeedsterTitles.Grant == TitleService.Grant and _G.SpeedsterTitles.Revoke == TitleService.Revoke
		and _G.SpeedsterTitles.Visual == TitleService.Visual, "_G.SpeedsterTitles contract")
	pass("Start publishes _G.SpeedsterTitles {Refresh, Grant, Revoke, Visual}")
end

local runner = join(5001, "runner", "runner")
local rival1 = join(5002, "rival1")
local rival2 = join(5003, "rival2")

do
	TitleService.SetBoardRanks("Speed", { rival1.UserId, rival2.UserId, runner.UserId })
	local owned = TitleService.GetOwned(runner)
	assert(owned.speed_top5 and owned.speed_top10 and not owned.speed_top1, "rank 3 owns top5 + top10")
	assert(TitleService.GetOwned(rival1).speed_top1, "rank 1 owns top1")
	assert(runner:GetAttribute("EquippedTitle") == "", "\"\" (auto) shows only staff titles")
	assert(not TitleService.SetBoardRanks("Robux", {}), "unknown boards are refused")
	pass("SetBoardRanks: rank 3 -> speed_top5 + speed_top10, not top1; auto shows no rank title")
end

do
	-- An Equip sent without opening the panel logs no funnel step (no orphan step-2 sessions).
	local stepsBefore = #steps
	assert(TitleService.Equip(runner, ""))
	assert(#steps == stepsBefore, "Equip before any Get logs no Titles_Equipped")
	-- "Get" spammed through the 0.3 s guard is one funnel session.
	TitleService.Open(runner)
	TitleService.Open(runner)
	TitleService.Open(runner)
	local sessionsLogged = 0
	for index = stepsBefore + 1, #steps do
		if steps[index][3] == "session" then
			sessionsLogged += 1
		end
	end
	assert(sessionsLogged == 1, "one Titles_Opened session per 10 s, got " .. sessionsLogged)
	volatiles = {}
	pass("funnel: Equip without the panel logs nothing; spammed Get opens one session")
end

do
	local before = #commits
	local ok, message = TitleService.Equip(runner, "speed_top5")
	assert(ok, message)
	assert(runner:GetAttribute("EquippedTitle") == "speed_top5" and runner:GetAttribute("TitlePreference") == "speed_top5")
	assert(#commits == before, "Equip never commits")
	assert(#volatiles == 1 and volatiles[1].kind == "U4.Titles.SetPref" and volatiles[1].pref == "speed_top5")
	assert(profiles[runner.UserId].U4.Titles.Pref == "speed_top5", "the preference is in the profile")
	assert(steps[#steps][2] == "Engagement_Titles" and steps[#steps][3] == 2, "Titles_Equipped funnel step")
	pass("Equip: volatile SetPref (ApplyVolatile, no Commit), EquippedTitle + TitlePreference, funnel step 2")
end

do
	-- The rank is lost: back to auto, the preference stays.
	TitleService.SetBoardRanks("Speed", { rival1.UserId, rival2.UserId })
	assert(runner:GetAttribute("EquippedTitle") == "", "rank lost -> auto (nothing for a non-staff)")
	assert(runner:GetAttribute("TitlePreference") == "speed_top5", "the preference survives")
	-- And comes back with it.
	TitleService.SetBoardRanks("Speed", { runner.UserId, rival1.UserId })
	assert(runner:GetAttribute("EquippedTitle") == "speed_top5", "rank regained -> the preferred title again")
	assert(TitleService.GetOwned(runner).speed_top1)
	pass("losing the rank falls back to auto without losing the preference; regaining it restores it")
end

do
	local refused = {}
	for _, pref in { "wins_top1", "developer", "bogus", "Speed_Top5", string.rep("a", 33), 12 } do
		local ok = TitleService.Equip(runner, pref)
		if not ok then
			table.insert(refused, pref)
		end
	end
	assert(#refused == 6, "every locked / unknown / malformed pref is refused")
	assert(runner:GetAttribute("TitlePreference") == "speed_top5", "a refused Equip changes nothing")
	pass("Equip refuses locked, unknown and malformed titles")
end

do
	local spoof = join(6001, "randomkid", "Gekkoh") -- DisplayName of a developer
	local spoof2 = join(6002, "someone", "himothy09871") -- DisplayName of a tester
	local gekkoh = join(767108248, "Gekkoh", "Gekkoh") -- the owner (OwnerUserIds), no longer a forced DEV
	local dev = join(111827288, "pxuto", "pxuto")
	local tester = join(6003, "Himothy09871", "whoever")
	assert(spoof:GetAttribute("EquippedTitle") == "" and not TitleService.GetOwned(spoof).developer, "DisplayName spoof refused")
	assert(spoof2:GetAttribute("EquippedTitle") == "" and not TitleService.GetOwned(spoof2).tester)
	assert(gekkoh:GetAttribute("EquippedTitle") == "owner" and not TitleService.GetOwned(gekkoh).developer,
		"UserId 767108248 wears OWNER automatically and is not forced to DEV (2026-09-26, owner)")
	assert(dev:GetAttribute("EquippedTitle") == "developer", "UserId 111827288 wears DEV automatically")
	assert(tester:GetAttribute("EquippedTitle") == "tester", "tester by player.Name")
	local owner = join(ownerUserId, "theowner")
	assert(owner:GetAttribute("EquippedTitle") == "owner", "the game creator wears OWNER")
	-- "none" hides even a staff title; "" brings it back.
	assert(TitleService.Equip(dev, "none"))
	assert(dev:GetAttribute("EquippedTitle") == "" and dev:GetAttribute("TitlePreference") == "none")
	assert(TitleService.Visual(dev) == nil, "nothing to draw")
	assert(TitleService.Equip(dev, ""))
	assert(dev:GetAttribute("EquippedTitle") == "developer")
	local visual = TitleService.Visual(dev)
	assert(visual and visual.Id == "developer" and visual.Template == "Dev" and visual.Style == "typewriter"
		and visual.Text == "DEV" and visual.Color1.R == 255, "Visual for Bootstrap")
	pass("staff: DisplayName spoofs refused, 767108248 = OWNER (not DEV), 111827288 = DEV, tester by Name, creator = OWNER; \"none\" hides, \"\" restores")
end

do
	local before = #commits
	assert(not TitleService.Grant(runner, "speed_top1", "test"), "rank titles are never granted")
	assert(not TitleService.Grant(runner, "developer", "test"), "staff titles are never granted")
	assert(#commits == before)
	assert(TitleService.Grant(runner, "race_winner", "race"))
	local last = commits[#commits]
	assert(last.operationId == "u4title:race_winner" and last.commands[1].kind == "U4.Titles.Grant"
		and last.commands[1].id == "race_winner", "one Commit, operation u4title:<id>")
	assert(runner:GetAttribute("TitlesNewCount") == 1, "notice count")
	assert(#toasts == 1 and toasts[1].payload.Type == "Retention"
		and toasts[1].payload.Message == "New title: Race Winner! Equip it in Titles")
	assert(TitleService.GetOwned(runner).race_winner)
	assert(TitleService.Grant(runner, "race_winner", "race"), "granting an owned title is fine")
	assert(runner:GetAttribute("TitlesNewCount") == 1 and #toasts == 1, "no second notice or toast")
	-- Revoke (admin), then grant again: the spent operation id does not block it.
	assert(TitleService.Revoke(runner, "race_winner"))
	assert(not TitleService.GetOwned(runner).race_winner)
	assert(TitleService.Grant(runner, "race_winner", "admin"))
	assert(TitleService.GetOwned(runner).race_winner, "re-granted after a revoke")
	TitleService.Seen(runner)
	assert(runner:GetAttribute("TitlesNewCount") == 0, "Seen clears the notice")
	-- A title another workstream granted in its own Commit is noticed on its Refresh.
	local u4Titles = profiles[runner.UserId].U4.Titles
	table.insert(u4Titles.Owned, "streak_7")
	_G.SpeedsterTitles.Refresh(runner)
	assert(runner:GetAttribute("TitlesNewCount") == 1 and toasts[#toasts].payload.Message == "New title: Loyal Runner! Equip it in Titles")
	TitleService.Seen(runner)
	pass("Grant: markers only, u4title:<id>, notice + toast once, Revoke then Grant again; foreign grants noticed; Seen clears")
end

do
	-- 2026-09-26 (owner): the admin panel gives ANY title (staff / rank too); the choice wins over
	-- auto; the chat prefix is the worn title.
	assert(_G.SpeedsterTitles.AdminGrant == TitleService.AdminGrant, "_G.SpeedsterTitles.AdminGrant")
	assert(_G.SpeedsterTitles.Text("owner") == "OWNER" and _G.SpeedsterTitles.Text("bogus") == nil
		and _G.SpeedsterTitles.Text(12) == nil, "_G.SpeedsterTitles.Text checks ids for the admin panel")
	local kid = join(5101, "kid")
	assert(not TitleService.AdminGrant(kid, "bogus", "admin") and not TitleService.AdminGrant(kid, 12, "admin"), "unknown ids refused")
	assert(not TitleService.Grant(kid, "owner", "x"), "the normal Grant stays markers only")
	local ok, message = TitleService.AdminGrant(kid, "owner", "admin:1")
	assert(ok and message == "granted" and commits[#commits].commands[1].kind == "U4.Titles.AdminGrant", "one AdminGrant Commit")
	assert(table.find(profiles[kid.UserId].U4.Titles.Owned, "owner") and TitleService.GetOwned(kid).owner, "saved on the profile")
	assert(kid:GetAttribute("EquippedTitle") == "owner", "auto wears the granted staff title at once")
	assert(TitleService.AdminGrant(kid, "speed_top1", "admin:1") and TitleService.AdminGrant(kid, "developer", "admin:1"))
	assert(TitleService.Equip(kid, "developer") and kid:GetAttribute("EquippedTitle") == "developer", "the choice wins over auto (owner)")
	assert(TitleService.Equip(kid, "speed_top1") and kid:GetAttribute("EquippedTitle") == "speed_top1")
	local revoked, still = TitleService.Revoke(kid, "speed_top1")
	assert(revoked and not still and kid:GetAttribute("EquippedTitle") == "owner", "revoked -> back to auto")
	-- Gekkoh (the owner) sets and removes his own title: none, OWNER, a given DEV, auto.
	local gekkoh, pxuto = nil, nil
	for _, p in players do
		if p.UserId == 767108248 then
			gekkoh = p
		elseif p.UserId == 111827288 then
			pxuto = p
		end
	end
	assert(TitleService.Equip(gekkoh, "none") and gekkoh:GetAttribute("EquippedTitle") == "", "Gekkoh can wear nothing")
	assert(not TitleService.Equip(gekkoh, "developer"), "DEV is not forced on him (nor owned)")
	assert(TitleService.AdminGrant(gekkoh, "developer", "admin:767108248"))
	for _, pref in { "owner", "developer", "owner" } do
		assert(TitleService.Equip(gekkoh, pref) and gekkoh:GetAttribute("EquippedTitle") == pref, "choice " .. pref)
	end
	assert(TitleService.Equip(gekkoh, "") and gekkoh:GetAttribute("EquippedTitle") == "owner", "auto: the best staff title")
	local _, stillStaff = TitleService.Revoke(pxuto, "developer")
	assert(stillStaff == true, "a staff-list title survives a revoke of its profile copy")
	-- Chat prefix: the worn title, escaped; "none" nothing; auto keeps [VIP].
	assert(Catalog.ChatPrefix("owner", "owner", false) == '<font color="#FFD700"><b>[OWNER]</b></font> ')
	assert(Catalog.ChatPrefix("developer", "developer", true) == '<font color="#FF4500"><b>[DEV]</b></font> ')
	assert(Catalog.ChatPrefix("speed_top5", "", false) == '<font color="#00D2FF"><b>[Top 5 Speed]</b></font> ')
	assert(Catalog.ChatPrefix("", "none", true) == "" and Catalog.ChatPrefix(nil, nil, false) == "")
	assert(Catalog.ChatPrefix("", "", true) == '<font color="#FFD700"><b>[VIP]</b></font> ')
	assert(Catalog.EscapeRichText([[<b>&"']]) == "&lt;b&gt;&amp;&quot;&apos;" and Catalog.ChatTag("bogus") == nil)
	pass("AdminGrant: any catalog id, one Commit, saved, live; Equip choice wins over auto; Revoke any id; chat prefix")
end

do
	-- TitlesUpdate only after the panel asked, and only when something changed.
	local before = #sent
	TitleService.Refresh(rival2)
	assert(#sent == before, "no push before the panel was opened")
	local payload = TitleService.Open(rival2)
	assert(#sent == before + 1 and sent[#sent].payload == payload and payload.Ranks.Speed == 0 and payload.Ranks.Wins == 0)
	assert(type(payload.Progress.speed_top10) == "table" and payload.Progress.speed_top10.Need == 10)
	local session, step = steps[#steps - 1], steps[#steps]
	assert(session[3] == "session" and step[2] == "Engagement_Titles" and step[3] == 1, "Titles_Opened funnel")
	TitleService.Refresh(rival2)
	assert(#sent == before + 1, "unchanged -> nothing sent")
	TitleService.SetBoardRanks("Wins", { rival2.UserId })
	assert(#sent == before + 2 and sent[#sent].payload.Equipped == "" and sent[#sent].payload.Ranks.Wins == 1)
	assert(table.find(sent[#sent].payload.Owned, "wins_top1"))
	pass("TitlesUpdate: sent on open and on change only; Ranks / Progress / Owned in the payload")
end

do
	featureOn = false
	TitleService.Refresh(runner)
	assert(runner:GetAttribute("EquippedTitle") == nil and runner:GetAttribute("TitlePreference") == nil,
		"feature off -> empty attributes (Bootstrap falls back to Dev/Tester)")
	assert(TitleService.Visual(runner) == nil and not TitleService.Equip(runner, "none") and not TitleService.Grant(runner, "member", "x"))
	featureOn = true
	TitleService.Refresh(runner)
	assert(runner:GetAttribute("EquippedTitle") == "speed_top5")
	pass("kill switch: attributes emptied, Equip/Grant/Visual refused; back on restores")
end

do
	-- Inspect deep-copies the whole profile: one per Refresh.
	inspects = 0
	TitleService.Refresh(runner)
	assert(inspects == 1, "Refresh inspects the profile once, got " .. inspects)
	pass("Refresh reads the profile once")
end

do
	-- 2026-09-25 (final fix): one profile read per Equip, and a second Equip within 1 s is refused.
	inspects = 0
	local ok, _, payload = TitleService.Equip(runner, "none")
	assert(ok and inspects == 1, "Equip inspects the profile once, got " .. inspects)
	assert(type(payload) == "table" and payload.Preference == "none", "Equip returns its refreshed payload")
	local sent = TitleService.Push(runner, "Title hidden", true, payload)
	assert(sent == payload and inspects == 1, "Push with Equip's payload reads nothing more")
	clockStep = 0
	local again, message = TitleService.Equip(runner, "speed_top5")
	assert(not again and message == "Wait a moment", "a second Equip within 1 s is refused")
	assert(runner:GetAttribute("TitlePreference") == "none", "the refused Equip changes nothing")
	clockStep = 5
	assert(TitleService.Equip(runner, "speed_top5"), "allowed again after the cooldown")
	pass("Equip: one profile read, payload reused by Push, 1 s cooldown")
end

do
	-- A player who left, or whose data is not loaded, is skipped without errors.
	local gone = newPlayer(7001, "gone")
	gone.Parent = nil
	assert(TitleService.Refresh(gone) == nil and not TitleService.Grant(gone, "member", "x"))
	local loading = newPlayer(7002, "loading")
	table.insert(players, loading)
	local payload = TitleService.Refresh(loading)
	assert(payload and payload.Equipped == "" and payload.Preference == "", "no data yet: auto, nothing owned")
	local ok = TitleService.Equip(loading, "none")
	assert(not ok, "no data -> Equip refused")
	TitleService.PlayerRemoving(loading)
	-- Leaving during the staff check (the group rank call yields): nothing is kept for them.
	local leaver = newPlayer(767108248, "Gekkoh")
	profiles[leaver.UserId] = { U4 = Update4Profile.Default() }
	local realOwner = ownerUserId
	ownerUserId = -1
	TitleService.Configure(setmetatable({
		IsGameOwner = function(player)
			player.Parent = nil
			return false
		end,
	}, { __index = function(_, key)
		return ({ Players = PlayersStub, DataService = DataStub, FunnelAnalytics = Funnels, U4 = U4Stub, Catalog = Catalog,
			UpdateRemote = UpdateRemote, ToastRemote = ToastRemote, Color3 = Color3Stub, wait = function() end })[key]
	end }))
	assert(TitleService.Refresh(leaver) == nil, "left mid staff check -> nothing published")
	assert(leaver:GetAttribute("EquippedTitle") == nil, "no attributes on a player who left")
	ownerUserId = realOwner
	pass("a player who left or has no data yet is skipped safely (also mid staff check)")
end

print(string.format("test_u4_title_service: %d checks passed", passed))
