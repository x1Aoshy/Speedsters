-- test_u4_community.luau (Update 4, community_pass_admin, 2026-09-25)
-- The Community reward (output/Update4/PLAN.md §7.8):
--   1. CommunitySection: Default / Sanitize / Encode round trip, Claim once, bad data cleaned;
--      through the real Update4Profile dispatcher too.
--   2. The real Social/CommunityRewardService script, loaded with PolicyService / group /
--      DataStore stubs and the real SessionActor + reducers:
--        a Discord-restricted player: Redeem refused, no payload or message names Discord,
--        the group path pays only when IsInGroupAsync is true;
--        a Discord player: the Config code (after Normalize) and the DataStore list's code pay;
--        a second claim grants nothing (AlreadyCommitted / the section refuses);
--        5 wrong codes a minute, then refused until the minute is over;
--        the funnel steps 1-2-3 in order; the feature switch.
--   3. The panel's group texts never say Discord (en/es/pt).
--   4. CodesSystem hands unknown codes to _G.SpeedsterRedeemCommunityCode.
--   5. 2026-09-26 (owner: "the community reward doesn't come out / work"), reproduced and fixed:
--        Player:IsInGroupAsync answers from the session's cache (TitleSystem fills it at the
--        join), so a player who joined from the panel's prompt kept getting "join our group
--        first": a "no" is re-read from GroupService:GetGroupsAsync, for a few seconds after a
--        "Joined" prompt; requests the RemoteGuard refused are answered; every answer carries a
--        Reason the panel has a text for in en/es/pt.
--   6. 2026-09-26 (owner: "the text overlaps and it's HUGE"): the controller's fitRewardTexts,
--        run on the designer's panel: every reward text beside its picture (never under it),
--        inside its band and the frame, drawn above the picture, big enough on a phone; the
--        status pill above Redeem, not at the window's bottom edge.
-- Run: lune run audit/test_u4_community.luau   (from the project root)
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local SRC = "src/common/"
local Section = require("../src/common/ServerScriptService/Services/Data/U4/CommunitySection")
local Update4Profile = require("../src/common/ServerScriptService/Services/Data/Update4Profile")
local Actor = require("../src/common/ServerScriptService/Services/Data/SessionActor")
local Adapter = require("../src/common/ServerScriptService/Services/Data/DataStoreAdapter")
local CodesCatalog = require("../src/common/ReplicatedStorage/Shared/Catalogs/CodesCatalog")
local U4 = require("../src/common/ReplicatedStorage/Shared/Update4Config")

local passed = 0
local function pass(text)
	passed += 1
	print("PASS " .. text)
end

----------------------------------------------------------------------
-- 1. CommunitySection
----------------------------------------------------------------------
do
	local default = Section.Default()
	assert(default.Claimed == false and default.At == 0, "Default: not claimed")
	for _, bad in { nil, 5, "x", { Claimed = "yes", At = 3 }, { Claimed = true, At = 0 / 0 }, { Claimed = true, At = -4 }, { Claimed = true, At = math.huge } } do
		local clean = Section.Sanitize(bad)
		assert(type(clean.Claimed) == "boolean" and type(clean.At) == "number" and clean.At == clean.At and clean.At >= 0, "Sanitize cleans " .. tostring(bad))
	end
	local saved = Section.Encode({ Claimed = true, At = 1700000000.7 })
	assert(saved.Claimed == true and saved.At == 1700000000, "Encode keeps a claim (whole seconds)")
	local back = Section.Sanitize(saved)
	assert(back.Claimed == true and back.At == 1700000000, "Round trip")
	local state = Section.Default()
	local first = Section.Apply(state, "Claim", { kind = "U4.Community.Claim", at = 1700000100 }, 1700000200)
	assert(first.ok and state.Claimed and state.At == 1700000100, "Claim sets Claimed and At")
	local second = Section.Apply(state, "Claim", { kind = "U4.Community.Claim", at = 1700000300 }, 1700000300)
	assert(not second.ok and second.error.code == "InvalidInput" and string.find(second.error.message, "already claimed", 1, true), "A second Claim is refused")
	assert(not Section.Apply(Section.Default(), "Grant", {}, 1).ok, "Unknown op refused")
	local bogus = Section.Default()
	assert(Section.Apply(bogus, "Claim", { at = "later" }, 1700000999).ok and bogus.At == 1700000999, "A bad at falls back to now")

	assert(Update4Profile.HasSection("Community"), "The dispatcher loads CommunitySection")
	local profile = { U4 = Update4Profile.Sanitize(nil) }
	assert(profile.U4.Community.Claimed == false, "An old save gets the default")
	assert(Update4Profile.Apply(profile, { kind = "U4.Community.Claim", at = 1700000000 }, 1700000000).ok, "U4.Community.Claim routes")
	assert(not Update4Profile.Apply(profile, { kind = "U4.Community.Claim", at = 1700000001 }, 1700000001).ok, "...once")
	local encoded = Update4Profile.Encode(profile.U4)
	assert(encoded.Community.Claimed == true and Update4Profile.Sanitize(encoded).Community.At == 1700000000, "Dispatcher round trip keeps the claim")
	pass("CommunitySection: default, sanitize (bad types, NaN, negative, huge), encode round trip, Claim once, dispatcher routing")
end

----------------------------------------------------------------------
-- 2. The service, loaded for real with stubs.
----------------------------------------------------------------------
local function signal()
	local s = { handlers = {} }
	function s:Connect(fn)
		table.insert(self.handlers, fn)
		return { Disconnect = function() end }
	end
	function s:Fire(...)
		for _, fn in self.handlers do
			fn(...)
		end
	end
	return s
end

local function node(name, children)
	local n = { Name = name, __instance = true, children = children or {} }
	function n:WaitForChild(child)
		return self.children[child]
	end
	function n:FindFirstChild(child)
		return self.children[child]
	end
	function n:IsA(class)
		return self.class == class
	end
	return n
end
local function moduleNode(name, value)
	local n = node(name)
	n.module = value
	return n
end

local function world(options)
	options = options or {}
	local w = { clock = 1000, unix = 1760000000, fired = {}, steps = {}, warnings = {}, storeReads = 0, commits = 0, webGroups = {}, groupListReads = 0 }
	w.policies = options.policies or {}
	w.groups = options.groups or {}
	w.storeValue = options.storeValue
	w.off = {}

	local function remote(name)
		local r = node(name)
		r.class = "RemoteEvent"
		r.OnServerEvent = signal()
		function r:FireClient(player, payload)
			table.insert(w.fired, { remote = name, player = player, payload = payload })
		end
		return r
	end
	local remotes = node("Remotes", {
		CommunityRewardRequest = remote("CommunityRewardRequest"),
		CommunityRewardUpdate = remote("CommunityRewardUpdate"),
		TemporaryBoostUpdate = remote("TemporaryBoostUpdate"),
	})

	-- The real data layer: one SessionActor per player on a mock store.
	local clock = { UnixNow = function() return w.unix end, MonotonicNow = function() return w.clock end }
	local store = Adapter.CreateMock({})
	w.actors, w.handles = {}, {}
	local DataService = {
		GetHandle = function(userId)
			return w.handles[userId]
		end,
		Inspect = function(handle)
			return w.actors[handle]:Inspect(handle)
		end,
		Commit = function(handle, request)
			w.commits += 1
			w.lastCommands = request.commands
			w.lastOperation = request.operationId
			return w.actors[handle]:Commit(handle, request)
		end,
	}
	w.DataService = DataService

	local guards = {}
	w.dropped = {}
	local RemoteGuard = { Connect = function(r, interval, handler, onDropped)
		guards[r.Name] = handler
		w.dropped[r.Name] = onDropped
		w.guardInterval = interval
	end }
	w.guards = guards
	local Funnel = {
		Step = function(player, funnel, step)
			table.insert(w.steps, { player = player, funnel = funnel, step = step })
			return true
		end,
	}
	local U4Test = setmetatable({
		IsOn = function(feature)
			return not w.off[feature] and U4.IsOn(feature)
		end,
	}, { __index = U4 })

	local shared = node("Shared", {
		Update4Config = moduleNode("Update4Config", U4Test),
		Catalogs = node("Catalogs", { CodesCatalog = moduleNode("CodesCatalog", CodesCatalog) }),
	})
	local services = node("Services", {
		Data = node("Data", {
			DataService = moduleNode("DataService", DataService),
			Update4Profile = moduleNode("Update4Profile", Update4Profile),
		}),
		RemoteGuard = moduleNode("RemoteGuard", RemoteGuard),
		FunnelAnalytics = moduleNode("FunnelAnalytics", Funnel),
	})
	local Players = node("Players")
	Players.PlayerAdded = signal()
	Players.PlayerRemoving = signal()
	Players.list = {}
	function Players:GetPlayers()
		return self.list
	end
	w.Players = Players
	local gameServices = {
		Players = Players,
		PolicyService = { GetPolicyInfoForPlayerAsync = function(_, player)
			local policy = w.policies[player.UserId]
			if policy == nil then
				error("policy service unavailable")
			end
			return policy
		end },
		ReplicatedStorage = node("ReplicatedStorage", { Shared = shared, Remotes = remotes }),
		RunService = { IsStudio = function() return false end },
		ServerScriptService = node("ServerScriptService", { Services = services }),
		DataStoreService = { GetDataStore = function(_, name)
			assert(name == U4.Community.CodeStoreName, "the community code store")
			return { GetAsync = function(_, key)
				assert(key == U4.Community.CodeStoreKey, "the community code key")
				w.storeReads += 1
				return w.storeValue
			end }
		end },
		-- The web list (fresh); `w.webGroups[userId]` true (or a function answering it) lists our group.
		GroupService = { GetGroupsAsync = function(_, userId)
			w.groupListReads += 1
			local listed = w.webGroups[userId]
			if type(listed) == "function" then
				listed = listed()
			end
			return if listed then { { Id = 12345, Name = "Other" }, { Id = U4.Community.GroupId, Name = "Speedsters" } } else { { Id = 12345, Name = "Other" } }
		end },
	}
	w.G = {}
	local env = {
		game = { GetService = function(_, name) return assert(gameServices[name], name) end },
		require = function(object)
			assert(type(object) == "table" and object.module ~= nil, "require of an unknown stub")
			return object.module
		end,
		typeof = function(value)
			if type(value) == "table" and value.__instance then
				return "Instance"
			end
			return typeof(value)
		end,
		task = {
			spawn = function(fn, ...) fn(...) end,
			defer = function(fn, ...) fn(...) end,
			delay = function() end,
			wait = function(seconds)
				w.clock += seconds or 0
				return seconds
			end,
		},
		os = { clock = function() return w.clock end, time = function() return w.unix end },
		warn = function(...)
			table.insert(w.warnings, table.concat({ ... }, " "))
		end,
		_G = w.G,
		Instance = { new = function() error("no Instance.new expected: the remotes exist") end },
	}
	local source = fs.readFile(SRC .. "ServerScriptService/Social/CommunityRewardService.server.luau")
	luau.load(source, { environment = setmetatable(env, { __index = _G }) })()

	function w.join(userId, name, inGroup)
		local attributes = { DataLoaded = true }
		local player = { __instance = true, UserId = userId, Name = name, Parent = Players }
		function player:IsA(class)
			return class == "Player"
		end
		function player:GetAttribute(key)
			return attributes[key]
		end
		function player:SetAttribute(key, value)
			attributes[key] = value
		end
		function player:IsInGroupAsync(groupId)
			assert(groupId == U4.Community.GroupId, "our group")
			return w.groups[userId] == true
		end
		player.attributes = attributes
		local actorStore = Actor.new({ userId = userId, sessionId = "s" .. userId, storeAdapter = store, clock = clock })
		local opened = actorStore:Open()
		assert(opened.ok, "profile opens")
		w.actors[opened.value] = actorStore
		w.handles[userId] = opened.value
		if inGroup ~= nil then
			w.groups[userId] = inGroup
		end
		table.insert(Players.list, player)
		Players.PlayerAdded:Fire(player)
		return player
	end
	function w.request(player, ...)
		w.clock += 1.1
		w.guards.CommunityRewardRequest(player, ...)
		return w.fired[#w.fired].payload
	end
	function w.profile(player)
		local handle = w.handles[player.UserId]
		return w.actors[handle]:Inspect(handle).value.profile
	end
	return w
end

-- Any text a player could be shown (the protocol key DiscordAllowed is not shown).
local function mentionsDiscord(value)
	if type(value) == "string" then
		return string.find(string.lower(value), "discord", 1, true) ~= nil
	elseif type(value) == "table" then
		for _, v in value do
			if mentionsDiscord(v) then
				return true
			end
		end
	end
	return false
end

do
	local w = world({ policies = {
		[1] = { AllowedExternalLinkReferences = { "YouTube" } }, -- Discord refused
		[2] = { AllowedExternalLinkReferences = { "Discord", "YouTube" } },
		[3] = { AllowedExternalLinkReferences = { "Discord" } },
		[4] = { AllowedExternalLinkReferences = { "Discord" } },
		[7] = { AllowedExternalLinkReferences = { "Discord" } },
	}, storeValue = nil }) -- no admin list yet: U4.Community.Codes is the fallback
	assert(w.guardInterval == 1, "RemoteGuard 1 s")
	assert(type(w.G.SpeedsterRedeemCommunityCode) == "function", "_G.SpeedsterRedeemCommunityCode is published")

	-- A Discord-restricted player.
	local restricted = w.join(1, "Restricted", false)
	assert(restricted.attributes.CommunityDiscordAllowed == false, "Policy: Discord not allowed")
	local got = w.request(restricted, "Get")
	assert(got.DiscordAllowed == false and got.Claimed == false and got.GroupId == U4.Community.GroupId, "Get answers the group form")
	assert(got.Rewards.SpeedPotionMinutes == 30 and got.Rewards.SpinTickets == 3 and got.Rewards.TitleId == "member", "Rewards in the payload")
	local ok, message = w.G.SpeedsterRedeemCommunityCode(restricted, "speedfam")
	assert(ok == false and message == "Invalid code.", "A code is refused for a restricted player, with the plain message")
	assert(w.commits == 0, "...and nothing is committed")
	local notMember = w.request(restricted, "VerifyGroup")
	assert(notMember.Success == false and w.commits == 0, "Group path: not in the group, nothing paid")
	w.groups[1] = true
	local paid = w.request(restricted, "Redeem")
	assert(paid.Success == true and paid.Claimed == true, "Group path: Redeem pays once IsInGroupAsync is true")
	local profile = w.profile(restricted)
	assert(profile.U4.Community.Claimed == true and profile.U4.Community.At == w.unix, "Saved claim")
	assert(profile.SpinTickets == 3 and profile.PotionSpeedRemainingSeconds == 1800 and profile.PotionSpeedMultiplier == 2, "3 spins and a 30 minute 2x Speed potion")
	assert(w.lastOperation == "u4community:v1", "One operation id per account")
	assert(restricted.attributes.CommunityRewardClaimed == true, "CommunityRewardClaimed")
	local titleAsked = false
	for _, command in w.lastCommands do
		titleAsked = titleAsked or command.kind == "U4.Titles.Grant"
	end
	assert(titleAsked == Update4Profile.HasSection("Titles"), "The Member title is asked for exactly when TitlesSection is built")
	for _, entry in w.fired do
		if entry.player == restricted then
			assert(not mentionsDiscord(entry.payload), "Nothing sent to a restricted player names Discord")
		end
	end
	local order = {}
	for _, step in w.steps do
		if step.player == restricted and step.funnel == "Community_Reward" then
			table.insert(order, step.step)
		end
	end
	assert(order[1] == 1 and table.find(order, 2) and order[#order] == 3 and table.find(order, 2) < #order, "Funnel: opened, tried, claimed (in order)")
	local again = w.request(restricted, "Redeem")
	assert(again.Success == false and again.Claimed == true and w.profile(restricted).SpinTickets == 3, "Second claim: nothing more")
	pass("restricted player: Discord never named, codes refused, the group path pays only for members, once, funnel 1-2-3")

	-- A Discord player: the Config code, normalised.
	local discord = w.join(2, "Discord", false)
	assert(discord.attributes.CommunityDiscordAllowed == true, "Policy: Discord allowed")
	w.request(discord, "Get")
	local wrong = w.request(discord, "Redeem", "notacode")
	assert(wrong.Success == false and w.profile(discord).SpinTickets == 0, "A wrong code pays nothing")
	local right = w.request(discord, "Redeem", "  SpeedFam ")
	assert(right.Success == true and w.profile(discord).U4.Community.Claimed == true, "The Config code, any case and spaces, pays")
	assert(w.request(discord, "VerifyGroup").Success == false, "A Discord player cannot use the group path")
	pass("Discord player: U4.Community.Codes after CodesCatalog.Normalize")

	-- The DataStore list (the admin panel's rotating code), cached.
	w.storeValue = { Codes = { "Rotating-Code_9" }, At = 1 }
	w.G.SpeedsterForgetCommunityCodes() -- what the admin panel's SetCommunityCode does
	local rotating = w.join(3, "Rotating", false)
	local reads = w.storeReads
	local viaStore = w.request(rotating, "Redeem", "rotating-code_9")
	assert(viaStore.Success == true, "The DataStore list's code pays")
	assert(w.storeReads == reads + 1 or w.storeReads == 1, "The list was read")
	local cachedReads = w.storeReads
	w.G.SpeedsterRedeemCommunityCode(rotating, "rotating-code_9")
	assert(w.storeReads == cachedReads, "Cached for CodeCacheSeconds")
	-- 2026-09-25 (final fix): once the panel saved a list, the Config code is retired.
	local leaked = w.join(7, "Leaked", false)
	local oldCode = w.request(leaked, "Redeem", "speedfam")
	assert(oldCode.Success == false and w.profile(leaked).SpinTickets == 0, "The Config code no longer pays once a list is saved")
	assert(w.request(leaked, "Redeem", "Rotating-Code_9").Success == true, "...the saved list's code does")
	pass("Rotating code: DataStore list { Codes, At } read, normalised and cached; it retires the Config code")

	-- 5 wrong codes a minute.
	local guesser = w.join(4, "Guesser", false)
	for index = 1, 5 do
		local answer = w.request(guesser, "Redeem", "guess" .. index)
		assert(answer.Success == false and answer.Message == "Invalid code.", "wrong code " .. index)
	end
	local blocked = w.request(guesser, "Redeem", "rotating-code_9")
	assert(blocked.Success == false and string.find(blocked.Message, "Too many", 1, true), "The 6th try in a minute is refused, even the right code")
	local blockedDirect = select(2, w.G.SpeedsterRedeemCommunityCode(guesser, "rotating-code_9"))
	assert(string.find(blockedDirect, "Too many", 1, true), "...through the Codes window too")
	w.clock += 61
	assert(w.request(guesser, "Redeem", "rotating-code_9").Success == true, "After the minute the code works")
	-- The group path: a "not a member yet" answer counts too (2026-09-25 review), so Redeem
	-- spam cannot become one group web call a second.
	local tapper = w.join(6, "Tapper", false)
	assert(tapper.attributes.CommunityDiscordAllowed == false, "No policy answer: the group path")
	for index = 1, 5 do
		local answer = w.request(tapper, "Redeem")
		assert(answer.Success == false and string.find(answer.Message, "Roblox group", 1, true), "not a member " .. index)
	end
	w.groups[6] = true
	local tooFast = w.request(tapper, "VerifyGroup")
	assert(tooFast.Success == false and string.find(tooFast.Message, "Too many", 1, true), "The 6th group check in a minute is refused")
	assert(w.profile(tapper).SpinTickets == 0, "...and pays nothing")
	w.clock += 61
	assert(w.request(tapper, "VerifyGroup").Success == true, "After the minute the member is paid")
	pass("wrong codes: at most U4.Community.MaxWrongPerMinute a minute per player, on both doors")

	-- A new server (the attribute is gone) still cannot pay twice.
	restricted.attributes.CommunityRewardClaimed = nil
	local handle = w.handles[1]
	local replay = w.actors[handle]:Commit(handle, { operationId = "u4community:v1", fingerprint = "u4community:v1", commands = w.lastCommands })
	assert(replay.kind == "AlreadyCommitted" or replay.kind == "Rejected", "The same operation id is not paid again (" .. replay.kind .. ")")
	local other = w.actors[handle]:Commit(handle, { operationId = "u4community:other", fingerprint = "x", commands = {
		{ kind = "U4.Community.Claim", at = 1 }, { kind = "GrantSpinTickets", amount = 3 } } })
	assert(other.kind == "Rejected" and w.profile(restricted).SpinTickets == 3, "A second Claim under another id refuses the whole transaction")
	local viaService = w.request(restricted, "Redeem")
	assert(viaService.Success == false and viaService.Claimed == true and w.profile(restricted).SpinTickets == 3, "The service sees the saved claim")
	pass("once per account: AlreadyCommitted / the section's refusal grant nothing, even with the attribute lost")

	-- The feature switch.
	w.off.Community = true
	local late = w.join(5, "Late", true)
	local offAnswer = w.request(late, "Redeem")
	assert(offAnswer.Success == false and offAnswer.Enabled == false and w.profile(late).SpinTickets == 0, "Off: nothing paid, the panel is told")
	pass("kill switch: U4.IsOn('Community') false pays nothing")

	-- Policy failure: treated as not allowed (group form).
	local w2 = world({ policies = {} })
	local unknown = w2.join(9, "Unknown", false)
	assert(unknown.attributes.CommunityDiscordAllowed == false and w2.request(unknown, "Get").DiscordAllowed == false, "A failed policy lookup hides Discord")
	pass("policy lookup failure: the group form")
end

----------------------------------------------------------------------
-- 3. The panel: the group form never says Discord; the code box hint fixed.
----------------------------------------------------------------------
do
	local controller = fs.readFile(SRC .. "StarterPlayer/StarterPlayerScripts/UI/CommunityRewardsController.client.luau")
	local a = assert(string.find(controller, "local TEXT = {", 1, true), "TEXT table")
	local b = assert(string.find(controller, "\nlocal lang = ", a, true), "TEXT end")
	local TEXT = luau.load(string.sub(controller, a, b) .. "return TEXT")()
	for _, lang in { "en", "es", "pt" } do
		local text = assert(TEXT[lang], lang)
		assert(#text.GroupSteps == 3 and #text.DiscordSteps == 3, lang .. ": three steps each")
		assert(not mentionsDiscord(text.GroupSteps), lang .. ": the group steps never say Discord")
		for key, value in text do
			if key ~= "DiscordSteps" then
				assert(not mentionsDiscord(value), lang .. "." .. key .. " never says Discord")
			end
		end
		assert(not string.find(string.lower(table.concat(text.DiscordSteps[1], " ")), "http", 1, true), lang .. ": no URL, ever")
	end
	assert(TEXT.en.Placeholder == "Insert Code...", "The hint is a placeholder")
	for _, needle in {
		'codeBox.Text = ""', "codeBox.PlaceholderText = L.Placeholder", "codeBox.ClearTextOnFocus = false",
		'playerGui:WaitForChild("Community rewards", 8)', "MenuPanelLayout.BindPhoneFit(gui, window",
		"ModalJuice.WatchGui(gui)", "ConsolePanelSupport.Bind(gui, window", 'MenuEvents.MarkReady("Community"',
		"GroupService:PromptJoinAsync(groupId)", "codeFrame.Visible = discord and not state.Claimed",
	} do
		assert(string.find(controller, needle, 1, true), "Controller: " .. needle)
	end
	assert(not string.find(controller, "discord.gg", 1, true) and not string.find(controller, "https://", 1, true), "No invite link in the client")
	pass("panel: en/es/pt, the group form and every shared text free of Discord, no link, placeholder fixed, phone fit / juice / console / MarkReady")
end

----------------------------------------------------------------------
-- 4. CodesSystem delegates unknown codes.
----------------------------------------------------------------------
do
	local source = fs.readFile(SRC .. "ServerScriptService/Social/CodesSystem.server.luau")
	local a = assert(string.find(source, "local dynamicCodes", 1, true))
	local b = assert(string.find(source, "\n_G.SpeedsterRedeemCode = performRedeem", a, true))
	local fired = {}
	local delegated = {}
	local G = {
		SpeedsterRedeemCommunityCode = function(player, code)
			table.insert(delegated, code)
			if CodesCatalog.Normalize(code) == "speedfam" then
				return true, "Community reward!"
			end
			return false, "Invalid code."
		end,
	}
	local env = setmetatable({
		CodesCatalog = CodesCatalog,
		fireResult = function(_, success, message)
			table.insert(fired, { success = success, message = message })
		end,
		game = { GetService = function()
			return { GetDataStore = function() return {} end }
		end },
		ServerScriptService = { Services = { DynamicCodeDefinitions = "dyn" } },
		require = function(x)
			assert(x == "dyn")
			return { new = function() return { Get = function() return nil end } end }
		end,
		_G = G,
	}, { __index = _G })
	local performRedeem = luau.load(string.sub(source, a, b) .. "\nreturn performRedeem", { environment = env })()
	local player = { GetAttribute = function() return true end }
	local ok, message = performRedeem(player, " SpeedFam ", false, nil)
	assert(ok == true and message == "Community reward!" and fired[1] and fired[1].success == true, "A community code typed in the Codes window pays through the Community service")
	local bad, badMessage = performRedeem(player, "nope", false, nil)
	assert(bad == false and badMessage == "Invalid code." and #delegated == 2, "An unknown code is still 'Invalid code.'")
	local forced = performRedeem(player, "speedfam", true, "Admin")
	assert(forced == false and #delegated == 2, "Admin force-redeem never goes to the Community reward")
	pass("CodesSystem: unknown codes go to _G.SpeedsterRedeemCommunityCode (not on admin force)")
end

----------------------------------------------------------------------
-- 5. 2026-09-26: the membership cache, answered drops, reasons in three languages.
----------------------------------------------------------------------
do
	local w = world({ policies = {} }) -- no policy answer: everyone on the group path
	assert(type(w.dropped.CommunityRewardRequest) == "function" and w.dropped.CommunityRewardRequest == w.guards.CommunityRewardRequest,
		"A request the RemoteGuard refuses is answered by the same handler once the guard allows (onDropped)")

	-- The owner's bug: IsInGroupAsync keeps the join's "no" (TitleSystem asked GetRankInGroupAsync
	-- then), the player joins from the panel's prompt, the web list has the group: paid.
	local joiner = w.join(20, "Joiner", false)
	local notYet = w.request(joiner, "VerifyGroup")
	assert(notYet.Success == false and notYet.Reason == "NotMember" and string.find(notYet.Message, "Roblox group", 1, true), "Not a member: NotMember")
	w.webGroups[20] = true -- joined from the prompt; the Player cache still says no
	local paid = w.request(joiner, "Redeem")
	assert(paid.Success == true and paid.Reason == "Success" and paid.Claimed == true, "The cached 'no' is re-read from the web list: paid")
	assert(w.profile(joiner).SpinTickets == 3 and w.profile(joiner).U4.Community.Claimed == true, "...the whole reward")
	local again = w.request(joiner, "Redeem")
	assert(again.Success == false and again.Reason == "AlreadyClaimed", "A second Redeem: AlreadyClaimed")

	-- Right after the prompt said Joined, the web list may lag: "Joined" re-reads it.
	local fresh = w.join(21, "Fresh", false)
	local reads = 0
	w.webGroups[21] = function()
		reads += 1
		return reads >= 3
	end
	local clockBefore = w.clock
	local joined = w.request(fresh, "VerifyGroup", "Joined")
	assert(joined.Success == true and joined.Reason == "Success", "A fresh join, listed a few seconds later, is paid on its 'Joined' check")
	assert(w.clock - clockBefore >= 1.5 and w.clock - clockBefore < 10, "...within a few seconds")
	-- Without "Joined" (a plain Redeem), no waiting: one read, then NotMember.
	local slow = w.join(22, "Slow", false)
	local slowReads = 0
	w.webGroups[22] = function()
		slowReads += 1
		return false
	end
	local before = w.clock
	local plain = w.request(slow, "Redeem")
	assert(plain.Reason == "NotMember" and slowReads == 1 and w.clock - before < 1.2, "A plain Redeem reads the list once and answers at once")
	local stillNot = w.request(slow, "VerifyGroup", "Joined")
	assert(stillNot.Reason == "NotMember" and slowReads == 4, "A 'Joined' that never lists: NotMember after its re-reads")
	assert(w.profile(slow).SpinTickets == 0, "...and nothing paid")
	-- A member by the cache is paid without a web read.
	local member = w.join(23, "Member", true)
	local listReads = w.groupListReads
	assert(w.request(member, "Redeem").Reason == "Success" and w.groupListReads == listReads, "IsInGroupAsync's yes is final (no web read)")
	-- Too many tries: TooMany; the kill switch: Off.
	local spam = w.join(24, "Spam", false)
	for _ = 1, 5 do
		w.request(spam, "Redeem")
	end
	assert(w.request(spam, "Redeem").Reason == "TooMany", "The sixth try a minute: TooMany")
	w.off.Community = true
	local off = w.request(w.join(25, "Off", true), "Redeem")
	assert(off.Reason == "Off" and off.Enabled == false, "Switched off: Off")
	w.off.Community = nil
	-- The Discord door's reasons.
	local wd = world({ policies = { [30] = { AllowedExternalLinkReferences = { "Discord" } } } })
	local coder = wd.join(30, "Coder", false)
	assert(wd.request(coder, "Redeem", "nope").Reason == "InvalidCode", "A wrong code: InvalidCode")
	assert(wd.request(coder, "VerifyGroup").Reason == "UseCode", "The group check on the Discord door: UseCode")
	for _ = 1, 4 do
		wd.request(coder, "Redeem", "nope")
	end
	assert(wd.request(coder, "Redeem", "speedfam").Reason == "TooMany", "Too many wrong codes: TooMany on the panel")

	-- Every Reason the server sends has a text in the panel, in en / es / pt.
	local service = fs.readFile(SRC .. "ServerScriptService/Social/CommunityRewardService.server.luau")
	local a = assert(string.find(service, "local MESSAGES = {", 1, true), "MESSAGES")
	local b = assert(string.find(service, "\n}\n", a, true), "MESSAGES end")
	local MESSAGES = luau.load(string.sub(service, a, b + 2) .. "return MESSAGES")()
	local controller = fs.readFile(SRC .. "StarterPlayer/StarterPlayerScripts/UI/CommunityRewardsController.client.luau")
	local ta = assert(string.find(controller, "local TEXT = {", 1, true))
	local tb = assert(string.find(controller, "\nlocal lang = ", ta, true))
	local TEXT = luau.load(string.sub(controller, ta, tb) .. "return TEXT")()
	local reasons = { "Success" }
	for key in MESSAGES do
		table.insert(reasons, if key == "TooManyCodes" then "TooMany" else key)
	end
	for _, lang in { "en", "es", "pt" } do
		for _, reason in reasons do
			assert(type(TEXT[lang].Reasons[reason]) == "string" and TEXT[lang].Reasons[reason] ~= "", lang .. ": a text for Reason " .. reason)
		end
		assert(select(2, string.gsub(TEXT[lang].Reasons.Success, "%%d", "")) == 2, lang .. ": Success shows the minutes and the spins")
		for _, key in { "CheckingGroup", "CheckingCode", "Joined", "JoinPending", "JoinFailed" } do
			assert(type(TEXT[lang][key]) == "string" and not mentionsDiscord(TEXT[lang][key]), lang .. ": " .. key)
		end
	end
	for _, needle in {
		'fire("VerifyGroup", if result == Enum.GroupMembershipStatus.Joined then "Joined" else nil)',
		"result == Enum.GroupMembershipStatus.JoinRequestPending", "say(L.JoinFailed, false)",
		"GroupId = tonumber(U4.Community and U4.Community.GroupId) or 0",
		"queued = table.pack(...)", "say(L.CheckingGroup, false)",
		"MenuPanelLayout.BindPhoneFit(gui, window, OPEN_POS, OPEN_POS, function(fit)", "end, nil, MenuPanelLayout.PhoneBlock)",
	} do
		assert(string.find(controller, needle, 1, true), "Controller: " .. needle)
	end
	pass("2026-09-26: a cached 'not a member' is re-read from the web list (and for a few seconds after 'Joined'), refused requests are answered, every Reason has an en/es/pt text; the panel tells the join prompt's outcome, knows the group at once, queues quick taps")
end

----------------------------------------------------------------------
-- 6. 2026-09-26: the reward texts beside their pictures (the controller's fitRewardTexts,
--    run on the designer's panel), the status pill above Redeem.
----------------------------------------------------------------------
do
	local rb = require("@lune/roblox")
	local model = rb.deserializeModel(fs.readFile("design/ui/uineww.rbxm"))
	local root = model[1]:FindFirstChild("Community rewards") or model[1]
	local window = root:FindFirstChild("Community rewards")
	assert(window, "the designer's Community rewards window")
	local items = window:FindFirstChild("Itemsframe")
	local controller = fs.readFile(SRC .. "StarterPlayer/StarterPlayerScripts/UI/CommunityRewardsController.client.luau")
	local a = assert(string.find(controller, "-- BEGIN fitRewardTexts", 1, true), "fitRewardTexts block")
	local b = assert(string.find(controller, "-- END fitRewardTexts", a, true), "fitRewardTexts end")
	local chunk = string.sub(controller, a, b - 1) .. "\nreturn fitRewardTexts, REWARD_TEXT"
	local fitRewardTexts, REWARD_TEXT = luau.load(chunk, {
		environment = setmetatable({ Instance = rb.Instance, UDim2 = rb.UDim2, Vector2 = rb.Vector2, Enum = rb.Enum }, { __index = _G }),
	})()

	-- Pixel boxes, as Roblox lays them out (FitWithinMaxSize shapes, AnchorPoint on the fitted size).
	local function place(object, parent)
		local w = object.Size.X.Scale * parent.W + object.Size.X.Offset
		local h = object.Size.Y.Scale * parent.H + object.Size.Y.Offset
		local shape = object:FindFirstChildOfClass("UIAspectRatioConstraint")
		if shape and shape.AspectRatio > 0 then
			w = math.min(w, h * shape.AspectRatio)
			h = w / shape.AspectRatio
		end
		local left = parent.L + object.Position.X.Scale * parent.W + object.Position.X.Offset - object.AnchorPoint.X * w
		local top = parent.T + object.Position.Y.Scale * parent.H + object.Position.Y.Offset - object.AnchorPoint.Y * h
		return { L = left, T = top, W = w, H = h, R = left + w, B = top + h }
	end
	local function apart(p, q)
		return math.max(p.L - q.R, q.L - p.R, p.T - q.B, q.T - p.B)
	end
	local function inside(p, q, slack)
		return p.L >= q.L - slack and p.R <= q.R + slack and p.T >= q.T - slack and p.B <= q.B + slack
	end

	-- The window on an 812 x 375 phone under a 58 px top bar, at its PhoneBlock size (217 px).
	local windowHeight = 0.8 * (375 - 58) / (1 + 0.16694)
	local shape = window:FindFirstChildOfClass("UIAspectRatioConstraint")
	local win = { L = 0, T = 0, W = windowHeight * shape.AspectRatio, H = windowHeight }
	local before = place(items, win)
	local beforeTexts = {}
	for _, card in items:GetChildren() do
		if card.Name == "Item1" then
			local c = place(card, before)
			table.insert(beforeTexts, apart(place(card.Title, c), place(card.Icon, c)))
		end
	end
	assert(#beforeTexts == 2 and beforeTexts[1] < 0 and beforeTexts[2] < 0, "(the designer's texts do overlap their pictures)")

	fitRewardTexts(items)
	local frame = place(items, win)
	local unlock = place(items.Unlock, frame)
	local cards = {}
	for _, card in items:GetChildren() do
		if card.Name == "Item1" then
			table.insert(cards, card)
		end
	end
	table.sort(cards, function(x, y)
		return x.Position.Y.Scale < y.Position.Y.Scale
	end)
	local margin = REWARD_TEXT.Margin * frame.W
	for index, card in cards do
		local c = place(card, frame)
		local title, icon = place(card.Title, c), place(card.Icon, c)
		local light = place(card.Light, c)
		local where = ("card %d"):format(index)
		assert(apart(title, icon) >= margin - 0.01, ("%s: its text %.1f px from its picture (margin %.1f)"):format(where, apart(title, icon), margin))
		local band = if index == 1 then { L = frame.L, R = frame.R, T = frame.T, B = unlock.T } else { L = frame.L, R = frame.R, T = unlock.B, B = frame.B }
		assert(inside(title, band, 0.01) and apart(title, unlock) >= margin - 0.01, where .. ": its text inside its band, clear of the Member line")
		assert(inside(icon, band, 0.01), where .. ": its picture inside its band too")
		assert(card.Title.ZIndex > card.Icon.ZIndex and card.Title.ZIndex > card.Light.ZIndex, where .. ": its text drawn above its picture and glow")
		-- (the designer set each glow a little off its picture's centre: that offset, scaled, is kept)
		assert(math.abs((icon.L + icon.R) / 2 - (light.L + light.R) / 2) < 0.04 * frame.W and math.abs((icon.T + icon.B) / 2 - (light.T + light.B) / 2) < 0.04 * frame.W, where .. ": the glow stays around its picture")
		assert(title.W >= 0.4 * frame.W and title.H >= 0.25 * frame.W, ("%s: a text box of %.0f x %.0f px on the phone"):format(where, title.W, title.H))
		local cap = card.Title:FindFirstChildOfClass("UITextSizeConstraint")
		assert(card.Title.TextScaled and cap and cap.MaxTextSize == REWARD_TEXT.MaxTextSize, where .. ": scaled, with a size cap")
	end
	assert(place(cards[1].Icon, place(cards[1], frame)).L < place(cards[1].Title, place(cards[1], frame)).L, "the potion's text right of its picture")
	assert(place(cards[2].Icon, place(cards[2], frame)).L > place(cards[2].Title, place(cards[2], frame)).L, "the spins' text left of its picture")
	local member = place(items.Unlock.Title, unlock)
	assert(inside(member, unlock, 0.01) and member.W >= 0.9 * unlock.W - 0.01, "the Member line spans its band")
	assert(items.Unlock.Title.TextXAlignment == rb.Enum.TextXAlignment.Center, "...centred")
	-- The status pill: above Redeem (not at the window's bottom edge), in the right column.
	for _, needle in { 'status.AnchorPoint = Vector2.new(0.5, 1)', 'status.Position = UDim2.fromScale(0.727, 0.81)', 'status.Size = UDim2.fromScale(0.5, 0.16)' } do
		assert(string.find(controller, needle, 1, true), "Controller: " .. needle)
	end
	local redeem = place(window.Redeem, win)
	local pillBottom = 0.81 * win.H
	local pillTop = pillBottom - 0.16 * win.H
	assert(pillBottom <= redeem.T + 0.5 and pillTop >= place(items, win).T, "the pill ends above Redeem, inside the window")
	assert(0.727 * win.W - 0.25 * win.W >= place(items, win).R - 0.5, "...right of the rewards column")
	pass(("2026-09-26: reward texts beside their pictures (were %.0f and %.0f px into them), in their bands, above them, %.0f px margins; the status pill above Redeem"):format(-beforeTexts[1], -beforeTexts[2], margin))
end

print(("test_u4_community: %d checks passed"):format(passed))
