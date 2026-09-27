-- test_funnel_analytics.luau
-- The Creator Hub funnels (Services.FunnelAnalytics, AnalyticsService:LogFunnelStepEvent):
--   1. a step never throws and never holds up the caller, whatever AnalyticsService does
--      (errors, hangs, or is missing), and bad input is ignored;
--   2. a step counts once per player, funnel session and step; recurring funnels (Revive,
--      Spin Wheel) get a session per run;
--   3. onboarding follows only players who start it, and watches the join, the first
--      treadmill, 100 speed and the first lap itself;
--   4. the client may report only the Starter Pack's click and prompt, rate limited;
--   5. every step of the five funnels is reported somewhere, through the safe loader.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local SOURCE = fs.readFile("src/common/ServerScriptService/Services/FunnelAnalytics.luau")

local function signal()
	local s = { listeners = {} }
	function s:Connect(fn)
		table.insert(self.listeners, fn)
		local connection = { Connected = true }
		function connection.Disconnect()
			connection.Connected = false
			local index = table.find(s.listeners, fn)
			if index then
				table.remove(s.listeners, index)
			end
		end
		return connection
	end
	function s:Fire(...)
		for _, fn in table.clone(self.listeners) do
			fn(...)
		end
	end
	return s
end

local function object(class, name)
	local o = { __mock = true, ClassName = class, Name = name or class, children = {}, attrs = {}, attrSignals = {} }
	function o:IsA(c)
		return self.ClassName == c
	end
	function o:FindFirstChild(n)
		return self.children[n]
	end
	function o:GetAttribute(k)
		return self.attrs[k]
	end
	function o:SetAttribute(k, v)
		self.attrs[k] = v
		if self.attrSignals[k] then
			self.attrSignals[k]:Fire()
		end
	end
	function o:GetAttributeChangedSignal(k)
		self.attrSignals[k] = self.attrSignals[k] or signal()
		return self.attrSignals[k]
	end
	return o
end

-- Loads a fresh FunnelAnalytics. `mode` is what AnalyticsService does: "record", "throw",
-- "hang" (never returns) or "missing" (GetService fails).
local function load(mode)
	local logged, warnings, spawned = {}, {}, {}
	local players = object("Players", "Players")
	players.PlayerAdded = signal()
	players.PlayerRemoving = signal()
	players.list = {}
	function players:GetPlayers()
		return self.list
	end
	local replicated = object("ReplicatedStorage", "ReplicatedStorage")
	local analytics = object("AnalyticsService", "AnalyticsService")
	function analytics:LogFunnelStepEvent(player, funnel, session, step, stepName)
		if mode == "throw" then
			error("AnalyticsService is down")
		elseif mode == "hang" then
			coroutine.yield()
		end
		table.insert(logged, { Player = player, Funnel = funnel, Session = session, Step = step, Name = stepName })
	end
	function analytics:LogCustomEvent(player, eventName)
		if mode == "throw" then error("AnalyticsService is down") end
		if mode == "hang" then coroutine.yield() end
		table.insert(logged, { Player = player, Funnel = eventName, Session = nil, Step = 1,
			Name = ({Progress_Speed100_v2="Speed100Reached",Progress_FirstLap_v2="World1FirstLap",
				Progress_FirstRebirth_v2="FirstRebirthCompleted",Progress_World2_v2="World2Unlocked"})[eventName] or eventName })
	end
	local game = {
		GetService = function(_, name)
			if name == "Players" then
				return players
			elseif name == "ReplicatedStorage" then
				return replicated
			elseif name == "AnalyticsService" then
				if mode == "missing" then
					error("no such service")
				end
				return analytics
			end
			error("unexpected service " .. name)
		end,
	}
	local clock = 0
	local env = {
		game = game,
		typeof = function(v)
			if type(v) == "table" and v.__mock then
				return "Instance"
			end
			return typeof(v)
		end,
		Instance = {
			new = function(class)
				local o = object(class)
				if class == "RemoteEvent" then
					o.OnServerEvent = signal()
				end
				setmetatable(o, {
					__newindex = function(self, k, v)
						rawset(self, k, v)
						if k == "Parent" and v then
							v.children[self.Name] = self
						end
					end,
				})
				return o
			end,
		},
		task = {
			spawn = function(fn, ...)
				local co = coroutine.create(fn)
				table.insert(spawned, co)
				local ok, err = coroutine.resume(co, ...)
				assert(ok, err)
			end,
			defer = function(fn, ...)
				fn(...)
			end,
		},
		os = setmetatable({ clock = function()
			return clock
		end }, { __index = os }),
		warn = function(message)
			table.insert(warnings, message)
		end,
	}
	local module = luau.load(SOURCE, { environment = setmetatable(env, { __index = _G }) })()
	local function newPlayer(userId, rebirths, world2)
		local p = object("Player", "P" .. userId)
		p.UserId = userId
		p.Parent = players
		local leaderstats = object("Folder", "leaderstats")
		local speed = object("NumberValue", "Speed")
		speed.Value = 1
		speed.Changed = signal()
		local rebirthValue = object("NumberValue", "Rebirths")
		rebirthValue.Value = rebirths
		leaderstats.children.Speed = speed
		leaderstats.children.Rebirths = rebirthValue
		p.children.leaderstats = leaderstats
		p.attrs.World2Unlocked = world2 == true
		table.insert(players.list, p)
		players.PlayerAdded:Fire(p)
		return p, speed
	end
	return {
		Module = module,
		Logged = logged,
		Warnings = warnings,
		Spawned = spawned,
		Players = players,
		Replicated = replicated,
		NewPlayer = newPlayer,
		SetClock = function(t)
			clock = t
		end,
	}
end

-- 1. Never throws, never waits.
do
	local broken = load("throw")
	local p = broken.NewPlayer(1, 5, true)
	local ok, sent = pcall(broken.Module.Step, p, "Monetization_Revive", 1, "offer-1")
	assert(ok and sent == true, "A failing AnalyticsService does not reach the caller")
	assert(#broken.Warnings == 1 and string.find(broken.Warnings[1], "not logged", 1, true), "...its error is caught and warned in its own thread")

	local hanging = load("hang")
	local q = hanging.NewPlayer(2, 5, true)
	local finished = false
	local caller = coroutine.create(function()
		hanging.Module.Step(q, "Engagement_SpinWheel", 1)
		finished = true
	end)
	assert(coroutine.resume(caller))
	assert(finished and coroutine.status(caller) == "dead", "A hanging AnalyticsService never holds up the caller")
	assert(coroutine.status(hanging.Spawned[1]) == "suspended", "(the call hangs in its own thread)")

	local missing = load("missing")
	local r = missing.NewPlayer(3, 5, true)
	local okMissing = pcall(missing.Module.Step, r, "CoreLoop_Rebirths", 2)
	assert(okMissing, "Without AnalyticsService the game still runs")

	local fine = load("record")
	local s = fine.NewPlayer(4, 5, true)
	for _, bad in {
		{ nil, "Monetization_Revive", 1 },
		{ s, "NoSuchFunnel", 1 },
		{ s, "Monetization_Revive", 9 },
		{ s, "Monetization_Revive", "1" },
		{ { Name = "fake" }, "Monetization_Revive", 1 },
	} do
		local okBad, result = pcall(fine.Module.Step, bad[1], bad[2], bad[3])
		assert(okBad and result == false, "Bad input is ignored without an error")
	end
	assert(#fine.Logged == 0, "...and logs nothing")
	print("PASS safe: AnalyticsService errors, hangs or absence never reach or hold up the caller; bad input is ignored")
end

-- 2. Once per player, session and step.
do
	local t = load("record")
	local p = t.NewPlayer(10, 2, true)
	assert(t.Module.Step(p, "CoreLoop_Rebirths", 1) == true, "Eligibility is sent")
	assert(t.Module.Step(p, "CoreLoop_Rebirths", 2) == true, "A step is sent")
	assert(t.Module.Step(p, "CoreLoop_Rebirths", 2) == false, "...once")
	assert(t.Logged[1].Funnel == "Rebirth_EligibleToComplete_v2" and t.Logged[2].Step == 2 and t.Logged[2].Session ~= nil, "Each rebirth has a versioned session")
	assert(t.Module.Step(p, "Monetization_Revive", 1, "offer-A") and t.Module.Step(p, "Monetization_Revive", 1, "offer-B"), "Each death offer is its own Revive session")
	assert(t.Module.Step(p, "Monetization_Revive", 3, "offer-A") and not t.Module.Step(p, "Monetization_Revive", 3, "offer-A"), "...each outcome once per offer")
	assert(t.Module.Step(p, "Monetization_Revive", 4, "offer-B"), "The second offer times out")
	for _, entry in t.Logged do
		assert(entry.Funnel ~= "Revive_Purchase_v2" or entry.Step == 1,
			"Dismissing or timing out never backfills a revive purchase")
	end
	assert(t.Module.Step(p, "Monetization_Revive", 1, "offer-C"))
	assert(t.Module.Step(p, "Monetization_Revive", 2, "offer-C"))
	local purchased = 0
	for _, entry in t.Logged do
		if entry.Funnel == "Revive_Purchase_v2" and entry.Step == 2 then purchased += 1 end
	end
	assert(purchased == 1, "Only a confirmed paid revive reaches purchase step")
	local first = t.Module.NewSession(p, "Engagement_SpinWheel")
	t.Module.Step(p, "Engagement_SpinWheel", 1, first)
	t.Module.Step(p, "Engagement_SpinWheel", 2)
	local second = t.Module.NewSession(p, "Engagement_SpinWheel")
	assert(first ~= second, "Every opening of the wheel is a new session")
	t.Module.Step(p, "Engagement_SpinWheel", 1, second)
	assert(t.Module.Step(p, "Engagement_SpinWheel", 2) == true, "The free spin of the new session counts again")
	for _, entry in t.Logged do
		assert(entry.Funnel ~= "Wheel_Paid_v2" or entry.Step == 1,
			"Free spins do not backfill a paid spin purchase")
	end
	local sessions = {}
	for _, entry in t.Logged do
		if entry.Funnel == "Wheel_Free_v2" then
			table.insert(sessions, entry.Session)
		end
	end
	assert(sessions[1] == first and sessions[2] == first and sessions[3] == second and sessions[4] == second, "Wheel steps carry their opening's session")

	local qSession = t.Module.NewSession(p, "Engagement_Quests")
	assert(t.Module.NewSession(p, "Engagement_Quests") == qSession, "Quest session survives panel reopen during the same UTC day")
	t.Module.Step(p, "Engagement_Quests", 1, qSession)
	assert(t.Module.Step(p, "Engagement_Quests", 2) == true, "Quests step 2 logs")
	assert(t.Module.Step(p, "Engagement_Quests", 2) == false, "...once per session")

	local afkSession = t.Module.NewSession(p, "Engagement_AFK")
	t.Module.Step(p, "Engagement_AFK", 1, afkSession)
	assert(t.Module.Step(p, "Engagement_AFK", 2) == true, "AFK step 2 logs")
	assert(t.Module.Step(p, "Engagement_AFK", 2) == false, "...once per session")

	t.Players.PlayerRemoving:Fire(p)
	print("PASS once: per player, funnel session and step; Revive sessions per offer, Spin Wheel, Quests and AFK sessions")
end

-- 3. Onboarding.
do
	local t = load("record")
	local newcomer, speed = t.NewPlayer(20, 0, false)
	local veteran = t.NewPlayer(21, 4, true)
	newcomer:SetAttribute("DataLoaded", true)
	veteran:SetAttribute("DataLoaded", true)
	local function steps(player)
		local list = {}
		for _, entry in t.Logged do
			-- The newcomer ladder (2026-09-22) is tested in audit/test_perf_world_gates.luau.
			if entry.Player == player and entry.Funnel ~= "Onboarding_Ladder_v2" then
				table.insert(list, entry.Funnel .. ":" .. entry.Name)
			end
		end
		return list
	end
	assert(t.Module.IsNewcomer(newcomer) and not t.Module.IsNewcomer(veteran), "Only players with no rebirth and World 2 locked are in onboarding")
	assert(steps(newcomer)[1] == "Onboarding_Training_v2:PlayerJoined", "PlayerJoined when their data loads")
	newcomer:SetAttribute("IsOnTreadmill", true)
	speed.Value = 99
	speed.Changed:Fire()
	assert(#steps(newcomer) == 2 and steps(newcomer)[2] == "Onboarding_Training_v2:FirstTreadmillRun", "The first treadmill run")
	speed.Value = 100
	speed.Changed:Fire()
	newcomer:SetAttribute("NewWorld1FinalWinStageClaimed", true)
	t.Module.Step(newcomer, "Onboarding_FTUE", 5)
	t.Module.Step(newcomer, "Onboarding_FTUE", 6)
	local expected = { "Onboarding_Training_v2:PlayerJoined", "Onboarding_Training_v2:FirstTreadmillRun", "Progress_Speed100_v2:Speed100Reached", "Progress_FirstLap_v2:World1FirstLap", "Progress_FirstRebirth_v2:FirstRebirthCompleted", "Progress_World2_v2:World2Unlocked" }
	for index, name in expected do
		assert(steps(newcomer)[index] == name, "Onboarding step " .. index .. " is " .. name)
	end
	veteran:SetAttribute("IsOnTreadmill", true)
	assert(t.Module.Step(veteran, "Onboarding_FTUE", 5) == true and steps(veteran)[1] == "Progress_FirstRebirth_v2:FirstRebirthCompleted", "Progress outcomes are tracked across sessions")
	print("PASS onboarding: newcomers only; join, treadmill, 100 speed and first lap watched, rebirth and World 2 reported, in order")
end

-- 4. Client reports.
do
	local t = load("record")
	local p = t.NewPlayer(30, 0, false)
	local report = t.Replicated.children.Remotes.children.FunnelReport
	assert(report and report.ClassName == "RemoteEvent", "The FunnelReport remote exists")
	report.OnServerEvent:Fire(p, "Monetization_Revive", 2)
	report.OnServerEvent:Fire(p, "Monetization_StarterPack", 3)
	report.OnServerEvent:Fire(p, "Monetization_StarterPack", "1")
	report.OnServerEvent:Fire(p, nil, nil)
	assert(#t.Logged == 0, "The client cannot report purchases or other funnels")
	report.OnServerEvent:Fire(p, "Monetization_StarterPack", 0)
	report.OnServerEvent:Fire(p, "Monetization_StarterPack", 1)
	report.OnServerEvent:Fire(p, "Monetization_StarterPack", 2)
	assert(#t.Logged == 3 and t.Logged[1].Name == "OfferVisible" and t.Logged[2].Name == "OfferClicked" and t.Logged[3].Name == "PromptOpened", "Offer exposure, click and prompt come from the client")
	print("PASS client reports: only the Starter Pack's click and prompt, whitelisted, once each")
end

-- 5. Every step is reported somewhere, through the safe loader.
do
	local files = {
		"src/common/ServerScriptService/Services/FunnelAnalytics.luau",
		"src/common/ServerScriptService/Progression/RebirthSystem.server.luau",
		"src/common/ServerScriptService/Worlds/WorldPortalService.server.luau",
		"src/common/ServerScriptService/Economy/SpinWheelService.server.luau",
		"src/common/ServerScriptService/Economy/SpeedProductPurchases.server.luau",
		"src/common/StarterPlayer/StarterPlayerScripts/UI/StarterPackOffer.client.luau",
		"src/common/ServerScriptService/Social/QuestService.server.luau",
		"src/common/ServerScriptService/Social/AfkRewardsService.server.luau",
		"src/common/ServerScriptService/Social/AfkZoneService.server.luau",
	}
	local all = ""
	for _, path in files do
		all ..= fs.readFile(path) .. "\n"
	end
	local reported = {
		Onboarding_FTUE = { 'Step(player, "Onboarding_FTUE", 1)', 'Step(player, "Onboarding_FTUE", 2)', 'Step(player, "Onboarding_FTUE", 3)', 'Step(player, "Onboarding_FTUE", 4)', 'Step(player, "Onboarding_FTUE", 5)', 'Step(player, "Onboarding_FTUE", 6)' },
		Monetization_Revive = { 'Step(player, "Monetization_Revive", 1, token)', 'Step(player, "Monetization_Revive", 2, context.Token)', 'Step(player, "Monetization_Revive", 3, offer.Token)', 'Step(player, "Monetization_Revive", 4, offer.Token)' },
		Engagement_SpinWheel = { 'Step(player, "Engagement_SpinWheel", 1, FunnelAnalytics.NewSession(player, "Engagement_SpinWheel"))', 'Step(player, "Engagement_SpinWheel", 2)', 'Step(player, "Engagement_SpinWheel", 3)', 'Step(grantPlayer, "Engagement_SpinWheel", 4)', 'Step(player, "Engagement_SpinWheel", 5)' },
		Monetization_StarterPack = { "reportFunnelStep(1)", "reportFunnelStep(2)", 'Step(player, "Monetization_StarterPack", 3)' },
		CoreLoop_Rebirths = { 'Step(player, "CoreLoop_Rebirths", 1)', 'Step(player, "CoreLoop_Rebirths", 2)', 'Step(player, "CoreLoop_Rebirths", 3)' },
		Engagement_Quests = {
			'Step(player, "Engagement_Quests", 1, FunnelAnalytics.NewSession(player, "Engagement_Quests"))',
			'Step(player, "Engagement_Quests", 2)',
			'Step(player, "Engagement_Quests", 3)',
			'Step(player, "Engagement_Quests", 4)',
		},
		Engagement_AFK = {
			'Step(player, "Engagement_AFK", 1, FunnelAnalytics.NewSession(player, "Engagement_AFK"))',
			'Step(player, "Engagement_AFK", 2, FunnelAnalytics.NewSession(player, "Engagement_AFK"))',
			'Step(player, "Engagement_AFK", 3)',
			'Step(player, "Engagement_AFK", 4)',
		},
	}
	local Funnels = load("record").Module.Funnels
	local count = 0
	for funnel, calls in reported do
		assert(#calls == #Funnels[funnel], funnel .. ": every step has a call site")
		for _, call in calls do
			assert(string.find(all, call, 1, true), funnel .. " is reported: " .. call)
			count += 1
		end
	end
	assert(count == 29, "29 steps in seven funnels")
	assert(string.find(all, "reportFunnelStep(0)", 1, true), "Starter Pack offer exposure is reported")
	for _, path in { files[2], files[3], files[4], files[5], files[7], files[8], files[9] } do
		local source = fs.readFile(path)
		assert(string.find(source, 'local ok, api = pcall(function()\n\t\treturn require(game:GetService("ServerScriptService"):WaitForChild("Services"):WaitForChild("FunnelAnalytics", 10))', 1, true), path .. " loads FunnelAnalytics inside pcall")
		assert(string.find(source, "return { Step = function() return false end, NewSession = function() return nil end }", 1, true), path .. " ...with a harmless stand-in if it cannot")
	end
	local offer = fs.readFile(files[6])
	assert(string.find(offer, 'pcall(report.FireServer, report, "Monetization_StarterPack", step)', 1, true), "The client's report cannot throw either")
	print("PASS coverage: all 29 steps of the 7 funnels are reported, every server script through the pcall loader")
end

print("ALL FUNNEL ANALYTICS CHECKS PASSED")
