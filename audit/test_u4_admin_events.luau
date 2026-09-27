-- test_u4_admin_events.luau (Update 4, community_pass_admin, 2026-09-25)
-- The admin panel's Update 4 tools (output/Update4/PLAN.md §7.8.5), on the real source:
--   1. EVENTS lists MegaRace; runEvent / stopEvent call _G.SpeedsterRace.StartMegaEvent /
--      StopMegaEvent only when they are functions (and StartMegaEvent only while
--      U4.IsOn("MegaRace")); a global event reaches every server through the "Event" publish.
--   2. GrantTitle / RevokeTitle: ANY catalog title (2026-09-26, owner), through
--      _G.SpeedsterTitles.AdminGrant / Revoke; RevokeTitle never on "All", GrantTitle on "All"
--      only for the Community "member" title.
--   3. SetCommunityCode: owners only, normalised, validated, saved as { Codes = { code }, At }.
--   4. The 2x Stamina pass toggle: a session flag (no commit), also on "All".
--   5. The controller: the Mega Race tile, the 2x Stamina pass, the Title picker, and the
--      Community code card for owners only.
-- Run: lune run audit/test_u4_admin_events.luau   (from the project root)
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local U4 = require("../src/common/ReplicatedStorage/Shared/Update4Config")
local CodesCatalog = require("../src/common/ReplicatedStorage/Shared/Catalogs/CodesCatalog")
local TitleCatalogModule = require("../src/common/ReplicatedStorage/Shared/TitleCatalog")

local service = fs.readFile("src/common/ServerScriptService/Admin/AdminAbusePanelService.server.luau")
local controller = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/Admin/AdminAbusePanelController.client.luau")

local passed = 0
local function pass(text)
	passed += 1
	print("PASS " .. text)
end
local function has(source, needle, message)
	assert(string.find(source, needle, 1, true), message .. " (missing: " .. needle .. ")")
end
local function chunkBetween(first, last)
	local a = assert(string.find(service, first, 1, true), "chunk start " .. first)
	local b = assert(string.find(service, last, a + #first, true), "chunk end " .. last)
	return string.sub(service, a, b - 1)
end

-- The constants the request handler uses, read from the source.
-- 2026-09-26 (owner): no title list here any more: any catalog title, checked by TitleService
-- (_G.SpeedsterTitles.Text), so a p0-only build needs no catalog next to this file.
local constants = luau.load(chunkBetween("local EVENTS = {", "\nPanel.OnServerEvent:Connect") .. "\nreturn EVENTS, COMMUNITY_CODE_PATTERN")
local EVENTS, COMMUNITY_CODE_PATTERN = constants()
local TitleCatalog = TitleCatalogModule

----------------------------------------------------------------------
-- 1. Mega Race
----------------------------------------------------------------------
do
	assert(EVENTS.MegaRace == true, "EVENTS has MegaRace")
	for _, name in { "Disco", "Snow", "Sandstorm", "Confetti", "Fireworks", "RainingTacos" } do
		assert(EVENTS[name] == true, "EVENTS still has " .. name)
	end
	local chunk = chunkBetween("local function stopEvent(name: string)", "\nlocal TREADMILL_FOLDER")
	local calls = {}
	local G = {}
	local megaOn = true
	local function stub(name)
		return function(...)
			table.insert(calls, { name = name, args = { ... } })
		end
	end
	local env = setmetatable({
		_G = G,
		U4 = setmetatable({ IsOn = function(feature)
			return feature ~= "MegaRace" or megaOn
		end }, { __index = U4 }),
		stopDisco = stub("stopDisco"), stopSnow = stub("stopSnow"), stopSandstorm = stub("stopSandstorm"),
		stopRainingTacos = stub("stopRainingTacos"), startDisco = stub("startDisco"), startSnow = stub("startSnow"),
		startSandstorm = stub("startSandstorm"), startRainingTacos = stub("startRainingTacos"),
		discoFloor = function() return nil, nil end,
		eventTokens = {},
		Lighting = { FindFirstChild = function() return nil end },
		Panel = { FireAllClients = stub("FireAllClients") },
		PotionServer = {}, Players = { GetPlayers = function() return {} end },
	}, { __index = _G })
	local runEvent, stopEvent = luau.load(chunk .. "\nreturn runEvent, stopEvent", { environment = env })()

	-- No race server yet: nothing happens, nothing throws.
	runEvent("MegaRace", 600, true, { UserId = 1, Name = "Boss" })
	runEvent("MegaRace", 600, false, nil)
	G.SpeedsterRace = { StartMegaEvent = "not a function", StopMegaEvent = 5 }
	runEvent("MegaRace", 600, true, { UserId = 1, Name = "Boss" })
	runEvent("MegaRace", 0, false, nil)
	assert(#calls == 0, "No hooks: nothing called, no generic effect broadcast for MegaRace")

	local started, stopped = {}, 0
	G.SpeedsterRace = {
		StartMegaEvent = function(duration, byName)
			table.insert(started, { duration = duration, byName = byName })
		end,
		StopMegaEvent = function()
			stopped += 1
		end,
	}
	runEvent("MegaRace", 600, true, { UserId = 1, Name = "Boss" })
	assert(#started == 1 and started[1].duration == 600 and started[1].byName == "Boss", "StartMegaEvent(duration, byName)")
	runEvent("MegaRace", 300, true, nil)
	assert(started[2].byName == "Admin", "Without an admin name: 'Admin'")
	runEvent("MegaRace", 0, false, nil)
	assert(stopped == 1, "Off -> StopMegaEvent")
	megaOn = false
	runEvent("MegaRace", 600, true, { UserId = 1, Name = "Boss" })
	assert(#started == 2, "U4Off_MegaRace / flag off: not started")
	G.SpeedsterRace.StartMegaEvent = function()
		error("race server failure")
	end
	megaOn = true
	runEvent("MegaRace", 600, true, { UserId = 1, Name = "Boss" }) -- pcall: no throw
	for _, call in calls do
		assert(call.name ~= "FireAllClients", "MegaRace draws nothing itself")
	end

	-- Global scope: the existing "Event" path (handler + publish + runShared) carries it.
	has(service, 'elseif action == "Event" and EVENTS[payload.name] then', "Events are gated by EVENTS")
	has(service, 'publish("Event", { name = payload.name, duration = duration, enabled = enabled, byId = admin.UserId, byName = byName }, admin)', "All Servers publishes the event")
	has(service, 'runEvent(tostring(data.name), number(data.duration, 60, 5, 900), data.enabled == true, {', "Other servers run it")
	pass("Mega Race: EVENTS, runEvent/stopEvent call _G.SpeedsterRace hooks only when they are functions and the flag is on, never throw, global via the Event publish")
end

----------------------------------------------------------------------
-- 2 + 3. GrantTitle / RevokeTitle / SetCommunityCode, the handler's own branches.
----------------------------------------------------------------------
do
	local branch = chunkBetween('	elseif action == "GrantTitle" or action == "RevokeTitle" then', '	elseif action == "Travel" then')
	local toasts, granted, revoked, saved = {}, {}, {}, {}
	local G = {}
	local forgot = 0
	local OWNER_IDS = { [767108248] = true }
	local players = { { Name = "Target", UserId = 50 }, { Name = "Other", UserId = 51 } }
	local storeFails = false
	local env = setmetatable({
		_G = G,
		U4 = U4,
		CodesCatalog = CodesCatalog,
		OWNER_IDS = OWNER_IDS,
		COMMUNITY_CODE_PATTERN = COMMUNITY_CODE_PATTERN,
		toast = function(_, ok, message)
			table.insert(toasts, { ok = ok, message = message })
		end,
		targetsFor = function(admin, target)
			if target == "All" then
				return players
			end
			for _, p in players do
				if p.UserId == target then
					return { p }
				end
			end
			return { admin }
		end,
		game = { GetService = function(_, name)
			assert(name == "DataStoreService")
			return { GetDataStore = function(_, storeName)
				return { SetAsync = function(_, key, value)
					if storeFails then
						error("DataStore down")
					end
					table.insert(saved, { store = storeName, key = key, value = value })
				end }
			end }
		end },
	}, { __index = _G })
	local handle = luau.load("return function(admin, payload, action, target)\n\tif false then\n" .. branch .. "\tend\nend", { environment = env })()
	local admin = { Name = "Mod", UserId = 999 }
	local owner = { Name = "Owner", UserId = 767108248 }

	-- Titles.
	handle(admin, { id = "member" }, "GrantTitle", 50)
	assert(toasts[#toasts].ok == false and string.find(toasts[#toasts].message, "loading", 1, true), "Titles not loaded yet: said so")
	G.SpeedsterTitles = {
		Grant = function()
			error("the admin panel uses AdminGrant, never the markers-only Grant")
		end,
		AdminGrant = function(player, id, source)
			table.insert(granted, { player = player, id = id, source = source })
			return true, "granted"
		end,
		Revoke = function(player, id)
			table.insert(revoked, { player = player, id = id })
			return true, id == "developer"
		end,
		Text = function(id) -- TitleService.Text
			local entry = type(id) == "string" and TitleCatalog.ById[id] or nil
			return entry and entry.Text
		end,
	}
	for _, bad in { "top1_speed", "", "MEMBER", 42, "bogus", string.rep("a", 40) } do
		handle(admin, { id = bad }, "GrantTitle", 50)
		assert(toasts[#toasts].ok == false and #granted == 0, "GrantTitle refuses " .. tostring(bad))
		handle(admin, { id = bad }, "RevokeTitle", 50)
		assert(#revoked == 0, "RevokeTitle refuses " .. tostring(bad))
	end
	-- 2026-09-26 (owner): any catalog title, staff and rank ones included.
	for _, id in { "owner", "developer", "speed_top1", "content_creator", "streak_21" } do
		handle(admin, { id = id }, "GrantTitle", 50)
		assert(granted[#granted].id == id and granted[#granted].player.UserId == 50 and granted[#granted].source == "admin:999"
			and toasts[#toasts].ok == true, "GrantTitle gives " .. id .. " through _G.SpeedsterTitles.AdminGrant")
	end
	handle(admin, { id = "member" }, "RevokeTitle", 50)
	assert(#revoked == 1 and revoked[1].id == "member" and toasts[#toasts].ok == true, "Member taken through Revoke")
	handle(admin, { id = "developer" }, "RevokeTitle", 50)
	assert(#revoked == 2 and string.find(toasts[#toasts].message, "still has it", 1, true), "a staff-list title still owned is reported")
	G.SpeedsterTitles.AdminGrant = function()
		error("titles broke")
	end
	handle(admin, { id = "member" }, "GrantTitle", 50) -- pcall: no throw
	assert(toasts[#toasts].ok == false, "A failing grant is reported, not thrown")
	local handler = chunkBetween("Panel.OnServerEvent:Connect(function(admin: Player, payload: any)", '	if action == "Hello" then')
	has(handler, 'or action == "RevokeTitle"', "RevokeTitle is a removal")
	has(handler, 'if takesAway and (target == "All" or target == "all") then', "...and removals never run on All")
	has(handler, 'or (action == "GrantTitle" and payload.id ~= "member")', "A given title goes to one named player, never All (but the Community member one)")
	has(service, 'toast(admin, false, "Mega Race is not available on this server")', "A Mega Race this server cannot run is reported, not a green 'on'")
	for _, entry in TitleCatalog.Entries do
		assert(TitleCatalog.IsAdminGrantable(entry.Id), "admin grantable: " .. entry.Id)
	end
	pass("titles: any catalog title, through _G.SpeedsterTitles AdminGrant/Revoke (guarded, pcall), RevokeTitle never on All")

	-- Community code.
	local before = #saved
	handle(admin, { code = "newcode" }, "SetCommunityCode", "All")
	assert(#saved == before and toasts[#toasts].ok == false and string.find(toasts[#toasts].message, "owners", 1, true), "Not an owner: refused, nothing saved")
	for _, bad in { "", "abc", "has space?", string.rep("x", 33), "speed!", 12 } do
		handle(owner, { code = bad }, "SetCommunityCode", "All")
		assert(#saved == before, "Refused code " .. tostring(bad))
	end
	local normal = CodesCatalog.Active[1]
	if normal then
		handle(owner, { code = normal }, "SetCommunityCode", "All")
		assert(#saved == before, "A normal code cannot become the Community code")
	end
	G.SpeedsterForgetCommunityCodes = function()
		forgot += 1
	end
	handle(owner, { code = "  Discord-Week_42 " }, "SetCommunityCode", "All")
	local entry = saved[#saved]
	assert(entry and entry.store == U4.Community.CodeStoreName and entry.key == U4.Community.CodeStoreKey, "Saved to the community code store")
	assert(#entry.value.Codes == 1 and entry.value.Codes[1] == "discord-week_42" and type(entry.value.At) == "number", "{ Codes = { normalised }, At }")
	assert(forgot == 1 and toasts[#toasts].ok == true, "This server forgets its cache; the owner is told")
	storeFails = true
	handle(owner, { code = "another1" }, "SetCommunityCode", "All")
	assert(toasts[#toasts].ok == false and forgot == 1, "A failed save is reported")
	pass("community code: owners only, normalised, 4-32 [a-z0-9_-], not a normal code, saved as { Codes, At }, cache dropped")
end

----------------------------------------------------------------------
-- 4. The 2x Stamina pass toggle.
----------------------------------------------------------------------
do
	local passChunk = chunkBetween("local PASSES = {", "\n-- Unlock All Cosmetics")
	local commits = {}
	local env = setmetatable({
		commit = function(_, commands)
			table.insert(commits, commands)
			return true
		end,
		refreshStats = function() end,
		Config = { VipSpeedGainMultiplier = 2, VipWinsMultiplier = 2 },
		DataService = { GetHandle = function() return nil end },
		GiftedPasses = { Has = function() return false end },
		_G = {},
	}, { __index = _G })
	local PASSES, setPass = luau.load(passChunk .. "\nreturn PASSES, setPass", { environment = env })()
	assert(PASSES.StaminaRegen == true, "PASSES has StaminaRegen")
	local attributes = { DataLoaded = true }
	local victim = {
		GetAttribute = function(_, key) return attributes[key] end,
		SetAttribute = function(_, key, value) attributes[key] = value end,
	}
	assert(setPass(victim, "StaminaRegen", true) == true and attributes.StaminaRegen2xOwned == true and #commits == 0, "Give: the session flag, nothing saved")
	assert(setPass(victim, "StaminaRegen", false) == true and attributes.StaminaRegen2xOwned == false and #commits == 0, "Remove: the flag goes")
	attributes.DataLoaded = false
	assert(setPass(victim, "StaminaRegen", true) == false, "Not before the data has loaded")
	attributes.DataLoaded = true
	setPass(victim, "All", true)
	assert(attributes.StaminaRegen2xOwned == true and #commits == 1, "All includes it")
	for _, command in commits[1] do
		assert(command.upgradeId ~= "StaminaRegen", "...never saved as an upgrade")
	end
	pass("2x Stamina pass toggle: StaminaRegen2xOwned for the session, no commit, part of All")
end

----------------------------------------------------------------------
-- 5. The controller.
----------------------------------------------------------------------
do
	has(controller, '{ "🏁", "MegaRace", "Mega Race", "x2 race rewards, 16 racers, starts now", "Blue" },', "The Mega Race tile")
	local tiles = string.match(controller, "function TABS%.Events%(page%)(.-)\nend\n")
	assert(tiles, "Events tab")
	local names = {}
	for name in string.gmatch(tiles, '{ "[^"]+", "(%w+)", "[^"]+", "[^"]+", "%w+" }') do
		table.insert(names, name)
	end
	-- 2026-09-26 (owner): the Super Sonic vs Eggman tile follows Mega Race (audit/test_u4_supersonic_event).
	assert(#names == 8 and names[7] == "MegaRace" and names[8] == "SuperSonic", "Eight event tiles, Mega Race then Super Sonic last (" .. #names .. ")")
	for _, name in names do
		assert(EVENTS[name] == true, "Tile " .. name .. " has a server event")
	end
	has(controller, '{ "StaminaRegen", "2x Stamina" },', "The 2x Stamina pass toggle")
	has(controller, 'local TitleCatalog = require(Shared:WaitForChild("TitleCatalog"))', "Title picker: the catalog")
	has(controller, "for index, entry in TitleCatalog.Entries do", "Title picker: every catalog title")
	has(controller, 'send({ action = "GrantTitle", id = pickedTitle, target = selectedTarget })', "Give Title on the picked player")
	has(controller, 'send({ action = "RevokeTitle", id = pickedTitle, target = selectedTarget })', "Remove Title on the picked player")
	has(controller, 'send({ action = "SetCommunityCode", code = communityCode.Text, target = "All" })', "Community code: Set")
	has(controller, "communityCard.Visible = isOwner", "Community code card only for owners")
	has(controller, 'isOwner = player:GetAttribute("AdminAbusePanelOwner") == true', "...as the server marks them")
	has(service, 'player:SetAttribute("AdminAbusePanelOwner", OWNER_IDS[player.UserId] == true)', "The server marks owners")
	pass("controller: Mega Race + Super Sonic tiles (8 tiles, all with server events), 2x Stamina toggle, Title picker, owner-only Community code")
end

print(("test_u4_admin_events: %d checks passed"):format(passed))
