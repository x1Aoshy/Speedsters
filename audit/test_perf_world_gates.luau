-- test_perf_world_gates.luau
-- The World 2 gate, the per-world walk speed and two analytics fixes (2026-09-22), run on
-- the real sources:
--   1. Config holds World 2's gate (6 Rebirths + Level 50, the owner's 2026-09-22 choice) next to World 3's, and World 3's
--      walk multiplier is its own 0.25 (1/9 until the 2026-09-22 feel pass): a retuned World 2 does not move it.
--   2. WorldPortalService reads the gate from Config (its own declarations, run against a
--      stub Config), and its log line prints it.
--   3. WorldsController reads the same Config, writes the World 2 card's "Requires ..." label
--      from it (a different Config gives a different label), and the server's state wins.
--   4. StatsService (real module): a rebirth in World 2 or 3 (Speed 1) walks at least 8,
--      World 1 does not change, and the Green/Yellow selector still applies on top.
--   5. AfkRewardsService's request handler (the real handler, with the real FunnelAnalytics):
--      RequestStatus and an Open while AFK Mode is on do not start a new AFK funnel session,
--      so the reward after AFKStarted is logged.
--   6. Onboarding_Ladder_v2: only newcomers, in order, rebirths 1/3/5/7 from RebirthSystem's
--      own lines, World 2 from both unlock paths.
--   7. The ladder's gate rung follows Config.World2UnlockRebirths (the real Config, patched to
--      3/5/6/10/0): World2Unlocked is still sent after any gate value.
--   lune run audit/test_perf_world_gates.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local CONFIG_PATH = "src/common/ReplicatedStorage/Shared/Config.luau"
local PORTAL_PATH = "src/common/ServerScriptService/Worlds/WorldPortalService.server.luau"
local WORLDS_PATH = "src/common/StarterPlayer/StarterPlayerScripts/UI/WorldsController.client.luau"
local STATS_PATH = "src/common/ServerScriptService/Services/Stats/StatsService.luau"
local ADAPTER_PATH = "src/common/ServerScriptService/Services/Stats/CharacterStatsAdapter.luau"
local FUNNEL_PATH = "src/common/ServerScriptService/Services/FunnelAnalytics.luau"
local REBIRTH_PATH = "src/common/ServerScriptService/Progression/RebirthSystem.server.luau"
local AFK_PATH = "src/common/ServerScriptService/Social/AfkRewardsService.server.luau"

local function near(a, b, tolerance)
	return type(a) == "number" and math.abs(a - b) <= (tolerance or 1e-9)
end
local function pass(message)
	print("PASS " .. message)
end
-- The text from `first` up to (not including) `stop`, found after `first`.
local function slice(source, first, stop)
	local a = string.find(source, first, 1, true)
	assert(a, "marker not found: " .. first)
	local b = string.find(source, stop, a + #first, true)
	assert(b, "end marker not found: " .. stop)
	return string.sub(source, a, b - 1)
end

-- Every changed source compiles.
for _, path in { CONFIG_PATH, PORTAL_PATH, WORLDS_PATH, STATS_PATH, ADAPTER_PATH, FUNNEL_PATH, REBIRTH_PATH, AFK_PATH } do
	local ok, err = pcall(luau.compile, fs.readFile(path))
	assert(ok, path .. " does not compile: " .. tostring(err))
end

-- Config, as a place with PlaceWorldNumber `world` loads it (optionally from a patched source).
local function loadConfig(world, source)
	local stub = { GetAttribute = function(_, name)
		return if name == "PlaceWorldNumber" then world else nil
	end, FindFirstChild = function()
		return nil
	end }
	local env = setmetatable({ workspace = stub, typeof = typeof, print = function() end, warn = function() end }, { __index = _G })
	for _, name in { "CFrame", "Vector3", "Color3", "UDim2", "UDim", "Vector2", "NumberRange", "ColorSequence", "ColorSequenceKeypoint", "NumberSequence", "NumberSequenceKeypoint", "BrickColor", "Enum", "Instance" } do
		env[name] = roblox[name]
	end
	env.game = { PlaceId = 0, GetService = function()
		return stub
	end }
	return luau.load(source or fs.readFile(CONFIG_PATH), { environment = env })()
end
local function replaceOnce(source, pattern, replacement)
	local out, count = string.gsub(source, pattern, replacement)
	assert(count == 1, "expected one match of " .. pattern)
	return out
end

-- 1. Config -------------------------------------------------------------------------------------
local configSource = fs.readFile(CONFIG_PATH)
do
	local world1, world2, world3 = loadConfig(1), loadConfig(2), loadConfig(3)
	for _, config in { world1, world2, world3 } do
		assert(config.World2UnlockRebirths == 6 and config.World2UnlockLevel == 50, "World 2's gate is 6 Rebirths + Level 50 in Config")
		assert(config.World3UnlockRebirths == 15 and config.World3UnlockLevel == 200, "World 3's gate is unchanged")
		assert(near(config.World2WalkSpeedMultiplier, 0.5) and near(config.World3WalkSpeedMultiplier, 0.25), "x0.5 and x0.25")
	end
	assert(near(world1.WorldWalkSpeedMultiplier, 1) and near(world2.WorldWalkSpeedMultiplier, 0.5) and near(world3.WorldWalkSpeedMultiplier, 0.25), "Each place walks at its own world's multiplier")
	assert(string.find(configSource, "\nConfig.World3WalkSpeedMultiplier = 0.25\n", 1, true), "World 3's multiplier is an explicit number")

	local retunedSource = replaceOnce(configSource, "\nConfig%.World2WalkSpeedMultiplier = 0%.5\n", "\nConfig.World2WalkSpeedMultiplier = 0.9\n")
	local retuned2, retuned3 = loadConfig(2, retunedSource), loadConfig(3, retunedSource)
	assert(near(retuned2.WorldWalkSpeedMultiplier, 0.9) and near(retuned3.World2WalkSpeedMultiplier, 0.9), "World 2 follows its own number")
	assert(near(retuned3.World3WalkSpeedMultiplier, 0.25) and near(retuned3.WorldWalkSpeedMultiplier, 0.25), "World 3 stays at x0.25 when World 2 changes")
	pass("Config: World 2 gate 6/50 next to World 3's 15/200; World 3 walks at an explicit x0.25 that a World 2 retune does not move")
end

-- A Config with another World 2 gate, for the readers below.
local gateSource = replaceOnce(replaceOnce(configSource, "\nConfig%.World2UnlockRebirths = 6\n", "\nConfig.World2UnlockRebirths = 7\n"),
	"\nConfig%.World2UnlockLevel = 50\n", "\nConfig.World2UnlockLevel = 100\n")
local currentConfig, changedConfig = loadConfig(1), loadConfig(1, gateSource)
assert(changedConfig.World2UnlockRebirths == 7 and changedConfig.World2UnlockLevel == 100)

-- 2. WorldPortalService ---------------------------------------------------------------------------
do
	local source = fs.readFile(PORTAL_PATH)
	local declarations = slice(source, "local WORLD_2_REBIRTH_REQUIREMENT", "-- World 3 (Desert)")
	local function gate(config)
		local chunk = declarations .. "\nreturn WORLD_2_REBIRTH_REQUIREMENT, WORLD_2_LEVEL_REQUIREMENT"
		return luau.load(chunk, { environment = setmetatable({ Config = config }, { __index = _G }) })()
	end
	local r, l = gate(currentConfig)
	assert(r == 6 and l == 50, "The portal enforces Config's 6 / 50")
	r, l = gate(changedConfig)
	assert(r == 7 and l == 100, "...and follows Config when it changes")
	r, l = gate({})
	assert(r == 6 and l == 50, "...with the current values if Config lacks them")
	assert(not string.find(source, "World 2 at 7 Rebirths", 1, true)
		and string.find(source, '"[WorldPortalService] V306JL+W3 loaded | World 2 at " .. WORLD_2_REBIRTH_REQUIREMENT', 1, true),
		"The loaded log prints the gate it enforces")
	-- The same numbers drive the menu state, the Travel check and the auto-unlock.
	for _, needle in { "RequiredRebirths = WORLD_2_REBIRTH_REQUIREMENT", "rebirths < WORLD_2_REBIRTH_REQUIREMENT or level < WORLD_2_LEVEL_REQUIREMENT",
		'key, needRebirths, needLevel = "World2Unlocked", WORLD_2_REBIRTH_REQUIREMENT, WORLD_2_LEVEL_REQUIREMENT' } do
		assert(string.find(source, needle, 1, true), "WorldPortalService uses the gate: " .. needle)
	end
	pass("WorldPortalService: the gate comes from Config (6/50 now, 7/100 with a changed Config), and so does its log line")
end

-- 3. WorldsController ------------------------------------------------------------------------------
do
	local source = fs.readFile(WORLDS_PATH)
	local declarations = slice(source, "local WORLD_2_REQUIRED_REBIRTHS", "local WORLD_3_REQUIRED_REBIRTHS")
	local card = slice(source, "local function world2RequirementText", "-- World 3's card")
	local onState = slice(source, "\t-- The server's gate wins over this client's Config", "\tif state.CurrentWorld == 1")
	local meets = slice(source, "local function meetsWorld2Requirements", "local function meetsWorld3Requirements")

	local function label(text, name)
		return { Name = name or "Name", Text = text, IsA = function(_, class)
			return class == "TextLabel"
		end }
	end
	local function controller(config)
		local labels = { label("World 2"), label("Requires 7 Rebirths + Level 100"), label("Requires 7 Rebirths + Level 100", "Hint") }
		local frame = { GetChildren = function()
			return labels
		end }
		local buttonsUpdated = 0
		local stats = { rebirths = 0, level = 1 }
		local env = setmetatable({
			Config = config,
			world2Frame = frame,
			updateWorldButtons = function()
				buttonsUpdated += 1
			end,
			isPlayerAdmin = function()
				return false
			end,
			getRebirths = function()
				return stats.rebirths
			end,
			getLevel = function()
				return stats.level
			end,
		}, { __index = _G })
		local chunk = declarations .. card .. meets
			.. "\nreturn { onState = function(state)\n" .. onState .. "\nend, meets = meetsWorld2Requirements, text = world2RequirementText }"
		local api = luau.load(chunk, { environment = env })()
		return api, labels, stats, function()
			return buttonsUpdated
		end
	end

	local api, labels, stats = controller(currentConfig)
	assert(labels[2].Text == "Requires 6 Rebirths + Level 50", "The card reads 'Requires 6 Rebirths + Level 50' from Config")
	assert(labels[1].Text == "World 2" and labels[3].Text == "Requires 7 Rebirths + Level 100", "Only the card's Name label is rewritten")
	stats.rebirths, stats.level = 6, 49
	assert(not api.meets(), "Level 99 is not enough")
	stats.level = 50
	assert(api.meets(), "6 Rebirths + Level 50 opens World 2 on the client")

	local changed, changedLabels, changedStats = controller(changedConfig)
	assert(changedLabels[2].Text == "Requires 7 Rebirths + Level 100", "A changed Config changes the card")
	changedStats.rebirths, changedStats.level = 7, 100
	assert(changed.meets(), "...and the client-side check")

	local served, servedLabels, servedStats, updates = controller(currentConfig)
	served.onState({ RequiredRebirths = 6, RequiredLevel = 50 })
	assert(updates() == 0, "The same gate from the server changes nothing")
	served.onState({ RequiredRebirths = 5, RequiredLevel = 40 })
	assert(servedLabels[2].Text == "Requires 5 Rebirths + Level 40" and updates() == 1, "The server's gate wins: the card follows it")
	servedStats.rebirths, servedStats.level = 5, 40
	assert(served.meets(), "...and so does the client-side check")
	served.onState({ Status = "State" })
	assert(servedLabels[2].Text == "Requires 5 Rebirths + Level 40", "A state without the gate keeps it")

	-- The World 3 clone still finds a "Requires" label to rewrite (the World 2 text runs first).
	local cardAt, cloneAt = string.find(source, "\napplyWorld2CardText()\n", 1, true), string.find(source, "world3Frame = world2Frame:Clone()", 1, true)
	assert(cardAt and cloneAt and cardAt < cloneAt, "The World 2 card is written before World 3's card is cloned from it")
	-- The old copies are gone; the one remaining mention describes the designer's authored label.
	local _, mentions = string.gsub(source, "7 Rebirths %+ Level 100", "")
	assert(mentions == 1 and string.find(source, "-- The designer's World 2 card says \"Requires 7 Rebirths + Level 100\" in the place.", 1, true)
		and not string.find(source, "WORLD_2_REQUIRED_REBIRTHS = 7", 1, true) and not string.find(source, "WORLD_2_REQUIRED_LEVEL = 100", 1, true),
		"WorldsController keeps no copy of the old numbers (only the note on the authored label)")
	pass("WorldsController: the World 2 card and check come from Config ('Requires 6 Rebirths + Level 50', 7/100 with a changed Config) and follow the server's state")
end

-- 4. Walk speed floor (real StatsService and CharacterStatsAdapter) --------------------------------
do
	local StatsService = require("../" .. string.gsub(STATS_PATH, "%.luau$", ""))
	local Adapter = require("../" .. string.gsub(ADAPTER_PATH, "%.luau$", ""))
	local rules = Adapter.GetRules()
	local selectors = { Green = 0.2, Yellow = 17 / 30, Red = 1 }
	local function walk(speed, world, selector)
		local result = StatsService.CalculateWalkSpeed(speed, rules, { worldMultiplier = world, selectorMultiplier = selector or 1, boostMultiplier = 1.7, permanentMultiplier = 1 })
		assert(result.ok, "CalculateWalkSpeed failed")
		return result.value
	end
	-- Before 2026-09-22: 8 x 1/3 = 2.67 and 8 x 1/9 = 0.89.
	assert(walk(1, 1 / 3) >= 8 and walk(1, 1 / 9) >= 8, "A rebirth in World 2 (" .. walk(1, 1 / 3) .. ") or World 3 (" .. walk(1, 1 / 9) .. ") walks at least 8")
	assert(near(walk(1, 1 / 3), 8) and near(walk(1, 1 / 9), 8), "...exactly the minimum, not more")
	-- World 3 walks at 0.25 since the 2026-09-22 feel pass: 8 x 0.25 = 2 would still be under the floor.
	assert(near(walk(1, 0.25), 8), "World 3 at x0.25 after a rebirth walks exactly the minimum")
	for _, speed in { 1, 1e3, 1e5, 3.4e8, 1e12, 3.37e15 } do
		assert(near(walk(speed, 1), StatsService.CalculateSmoothWalkSpeed(speed, rules)), "World 1 is unchanged at Speed " .. speed)
		for _, name in { "Green", "Yellow" } do
			-- The selector applies on top of the floored walk, as it does on World 1's minimum.
			assert(near(walk(speed, 1 / 3, selectors[name]), walk(speed, 1 / 3) * selectors[name]), name .. " applies after the floor")
		end
	end
	assert(near(walk(1, 1 / 3, selectors.Green), walk(1, 1, selectors.Green)), "Green at Speed 1 walks the same in World 2 as in World 1")
	-- Far above the floor the world scale is untouched: World 2 at entry Speed is still a third.
	assert(near(walk(3.4e8, 1 / 3), walk(3.4e8, 1) / 3), "At World 2's entry Speed the walk is still World 1's / 3 (" .. walk(3.4e8, 1 / 3) .. ")")
	assert(StatsService.CalculateMaxWalkSpeed(1, true, rules) >= 8, "CalculateMaxWalkSpeed has the same floor")
	assert(near(StatsService.CalculateMaxWalkSpeed(3.4e8, true, rules), StatsService.CalculateMaxWalkSpeed(3.4e8, false, rules) * 0.5), "...and the same scale above it")
	assert(near(StatsService.CalculateMaxWalkSpeed(1, false, rules), 8), "World 1's max walk at Speed 1 is still 8")

	-- The live path: the adapter's Update writes the Humanoid and the attributes.
	local function playerIn(world, mode)
		local attributes = { CurrentWorld = world, WalkSpeedMode = mode }
		return {
			GetAttribute = function(_, name)
				return attributes[name]
			end,
			SetAttribute = function(_, name, value)
				attributes[name] = value
			end,
		}, attributes
	end
	for _, world in { 2, 3 } do
		local p, attributes = playerIn(world)
		local actual = Adapter.Update(p, 1)
		assert(actual and actual >= 8 and attributes.RealWalkSpeedMax >= 8 and attributes.RealWalkSpeedSelected >= 8, "World " .. world .. " after a rebirth: the live walk is at least 8")
		assert(near(attributes.WorldMovementSpeedScale, if world == 2 then 0.5 else 0.25), "World " .. world .. "'s scale is still reported")
	end
	local green, greenAttributes = playerIn(2, "Green")
	Adapter.Update(green, 1)
	-- 2026-09-25 (Update 4, M50): a full speed of 24 or less is never slowed by the dial (Green
	-- was 20 % of the floored walk, 1.6 studs/s).
	assert(near(greenAttributes.RealWalkSpeedSelected, 8), "Green in World 2 after a rebirth: the floored walk of 8 is never dialled down (M50)")
	pass("walk speed: Speed 1 walks 8 in World 2 and 3 (was 2.67 and 0.89), World 1 unchanged, selectors on top, the world scale intact above the floor")
end

-- The real FunnelAnalytics with stand-ins for the Roblox services (as test_funnel_analytics).
local function signal()
	local s = { listeners = {} }
	function s:Connect(fn)
		table.insert(self.listeners, fn)
		return { Disconnect = function()
			local index = table.find(s.listeners, fn)
			if index then
				table.remove(s.listeners, index)
			end
		end }
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
-- `config` (optional): the table Shared.Config returns, so the module's own Config lookup runs.
local function loadFunnels(config)
	local logged = {}
	local players = object("Players", "Players")
	players.PlayerAdded, players.PlayerRemoving, players.list = signal(), signal(), {}
	function players:GetPlayers()
		return self.list
	end
	local replicated = object("ReplicatedStorage", "ReplicatedStorage")
	local configModule = object("ModuleScript", "Config")
	if config then
		local shared = object("Folder", "Shared")
		shared.children.Config = configModule
		replicated.children.Shared = shared
	end
	local analytics = object("AnalyticsService", "AnalyticsService")
	function analytics:LogFunnelStepEvent(player, funnel, session, step, stepName)
		table.insert(logged, { Player = player, Funnel = funnel, Session = session, Step = step, Name = stepName })
	end
	function analytics:LogCustomEvent(player, eventName)
		table.insert(logged, { Player = player, Funnel = eventName, Step = 1, Name = eventName })
	end
	local env = {
		require = function(module)
			assert(module == configModule, "FunnelAnalytics only requires Shared.Config")
			return config
		end,
		game = { GetService = function(_, name)
			return ({ Players = players, ReplicatedStorage = replicated, AnalyticsService = analytics })[name]
		end },
		typeof = function(v)
			return if type(v) == "table" and v.__mock then "Instance" else typeof(v)
		end,
		Instance = { new = function(class)
			local o = object(class)
			if class == "RemoteEvent" then
				o.OnServerEvent = signal()
			end
			return setmetatable(o, { __newindex = function(self, k, v)
				rawset(self, k, v)
				if k == "Parent" and v then
					v.children[self.Name] = self
				end
			end })
		end },
		task = { spawn = function(fn, ...)
			fn(...)
		end, defer = function(fn, ...)
			fn(...)
		end },
		warn = function() end,
	}
	local module = luau.load(fs.readFile(FUNNEL_PATH), { environment = setmetatable(env, { __index = _G }) })()
	local function newPlayer(userId, rebirths, world2)
		local p = object("Player", "P" .. userId)
		p.UserId, p.Parent = userId, players
		local leaderstats = object("Folder", "leaderstats")
		local speed = object("NumberValue", "Speed")
		speed.Value, speed.Changed = 1, signal()
		local rebirthValue = object("NumberValue", "Rebirths")
		rebirthValue.Value = rebirths
		leaderstats.children.Speed, leaderstats.children.Rebirths = speed, rebirthValue
		p.children.leaderstats = leaderstats
		p.attrs.World2Unlocked = world2 == true
		table.insert(players.list, p)
		players.PlayerAdded:Fire(p)
		p:SetAttribute("DataLoaded", true)
		return p
	end
	local function names(player, funnel)
		local list = {}
		for _, entry in logged do
			if entry.Player == player and entry.Funnel == funnel then
				table.insert(list, entry.Name)
			end
		end
		return list
	end
	return module, newPlayer, names, logged
end

-- 5. AFK funnel session ----------------------------------------------------------------------------
do
	local Funnels, newPlayer, names, logged = loadFunnels()
	local source = fs.readFile(AFK_PATH)
	local handlerSource = slice(source, "Request.OnServerEvent:Connect(function(player,payload)", "\nPlayers.PlayerAdded:Connect(setup)")
	local handler
	local statusSent = 0
	local p = newPlayer(50, 3, true)
	luau.load(handlerSource, { environment = setmetatable({
		Request = { OnServerEvent = { Connect = function(_, fn)
			handler = fn
		end } },
		sessions = { [p] = {} },
		RateLimiter = { Allow = function()
			return true
		end },
		FunnelAnalytics = Funnels,
		sendStatus = function()
			statusSent += 1
		end,
		claim = function() end,
		promptX5 = function() end,
	}, { __index = _G }) })()
	assert(type(handler) == "function", "The real AfkRewardsRequest handler was loaded")
	local function afkEntries(funnel)
		local list = {}
		for _, entry in logged do
			if entry.Funnel == funnel then
				table.insert(list, entry)
			end
		end
		return list
	end

	handler(p, { action = "RequestStatus" })
	assert(statusSent == 1 and #afkEntries("AFK_PanelOpened_v2") == 0, "RequestStatus (join) only sends the status")
	handler(p, { action = "Open" })
	assert(statusSent == 2 and #afkEntries("AFK_PanelOpened_v2") == 1, "A real panel open outside AFK Mode logs PanelOpened")

	-- AFK Mode starts (AfkZoneService: AfkModeActive, then AFKStarted in a new session) and the
	-- client opens the panel by itself, then asks for the status.
	p:SetAttribute("AfkModeActive", true)
	local session = Funnels.NewSession(p, "Engagement_AFK")
	Funnels.Step(p, "Engagement_AFK", 2, session)
	handler(p, { action = "Open" })
	handler(p, { action = "RequestStatus" })
	assert(statusSent == 4 and #afkEntries("AFK_PanelOpened_v2") == 1, "The auto-open while AFK starts no new session")
	Funnels.Step(p, "Engagement_AFK", 3)
	local rewards = afkEntries("AFK_ActiveReward_v2")
	assert(#rewards == 2 and rewards[1].Name == "AFKStarted" and rewards[2].Name == "RewardEarned" and rewards[2].Session == session,
		"The first reward is logged in the session AFKStarted opened")
	p:SetAttribute("AfkModeActive", false)
	handler(p, { action = "Open" })
	assert(#afkEntries("AFK_PanelOpened_v2") == 2, "After AFK Mode a panel open counts again")
	pass("AFK funnel: RequestStatus and the auto-open during AFK Mode keep the AFKStarted session, so RewardEarned is logged")
end

-- 6. Onboarding ladder -----------------------------------------------------------------------------
do
	local Funnels, newPlayer, names = loadFunnels()
	assert(Funnels.World2GateRebirths == 6, "Without Config the ladder keeps today's gate, 6")
	assert(table.concat(Funnels.Funnels.Onboarding_Ladder, ",") == "Joined,Rebirth1,Rebirth3,Rebirth5,Rebirth6,World2Unlocked", "The ladder's steps")

	-- RebirthSystem's own lines after a committed rebirth.
	local rebirthSource = fs.readFile(REBIRTH_PATH)
	local ladderLines = slice(rebirthSource, "\tlocal ladderStep = FunnelAnalytics.LadderRebirthSteps", "\n\n\tsendUpdate(player, \"Rebirth Complete!")
	local afterCommit = luau.load("return function(player, newRebirthCount)\n" .. ladderLines .. "\nend",
		{ environment = setmetatable({ FunnelAnalytics = Funnels }, { __index = _G }) })()
	local commitAt = string.find(rebirthSource, "if not commitRes or (commitRes.kind ~= \"Committed\"", 1, true)
	local ladderAt = string.find(rebirthSource, "local ladderStep = FunnelAnalytics.LadderRebirthSteps", 1, true)
	assert(commitAt and ladderAt and commitAt < ladderAt, "RebirthSystem logs the ladder after the rebirth committed")

	local newcomer = newPlayer(60, 0, false)
	assert(Funnels.IsNewcomer(newcomer))
	assert(table.concat(names(newcomer, "Onboarding_Ladder_v2"), ",") == "Joined", "A newcomer's join is step 1")
	for count = 1, 8 do
		afterCommit(newcomer, count)
	end
	assert(table.concat(names(newcomer, "Onboarding_Ladder_v2"), ",") == "Joined,Rebirth1,Rebirth3,Rebirth5,Rebirth6", "Rebirths 1, 3, 5 and 6, once each")
	Funnels.Step(newcomer, "Onboarding_Ladder", 6)
	Funnels.Step(newcomer, "Onboarding_Ladder", 6)
	assert(table.concat(names(newcomer, "Onboarding_Ladder_v2"), ",") == "Joined,Rebirth1,Rebirth3,Rebirth5,Rebirth6,World2Unlocked", "World 2 last, once")

	local veteran = newPlayer(61, 4, false)
	local unlockedVeteran = newPlayer(62, 0, true)
	for _, p in { veteran, unlockedVeteran } do
		afterCommit(p, 5)
		afterCommit(p, 7)
		Funnels.Step(p, "Onboarding_Ladder", 6)
		assert(#names(p, "Onboarding_Ladder_v2") == 0, "Players who are not newcomers are not in the ladder")
	end

	-- A newcomer who skips rungs (rebirths from a code) stops there: no later step counts.
	local skipper = newPlayer(63, 0, false)
	afterCommit(skipper, 1)
	afterCommit(skipper, 5)
	afterCommit(skipper, 7)
	Funnels.Step(skipper, "Onboarding_Ladder", 6)
	assert(table.concat(names(skipper, "Onboarding_Ladder_v2"), ",") == "Joined,Rebirth1", "A skipped rung stops the ladder")

	-- The FTUE funnel is unchanged beside it.
	assert(table.concat(names(newcomer, "Onboarding_Training_v2"), ",") == "PlayerJoined", "FTUE step 1 is still logged")

	local portal = fs.readFile(PORTAL_PATH)
	local _, calls = string.gsub(portal, 'FunnelAnalytics%.Step%(player, "Onboarding_Ladder", 6%)', "")
	assert(calls == 2, "WorldPortalService logs the ladder's World 2 step from both unlock paths (portal and auto-unlock)")
	assert(string.find(portal, 'FunnelAnalytics.Step(player, "Onboarding_FTUE", 6)\n\t\t\t-- The newcomer ladder', 1, true)
		and string.find(portal, 'if key == "World2Unlocked" then\n\t\t\t\t-- The newcomer ladder', 1, true), "...next to FTUE step 6")
	pass("Onboarding_Ladder_v2: newcomers only, Joined -> Rebirth 1/3/5/6 -> World 2, once each, in order")
end

-- 7. The ladder follows World 2's rebirth gate in Config -------------------------------------------
-- The gate is the pending one-line Config decision: its rebirth rung must move with it, or
-- World2Unlocked (which follows that rung) is never sent.
do
	local rebirthSource = fs.readFile(REBIRTH_PATH)
	local ladderLines = slice(rebirthSource, "\tlocal ladderStep = FunnelAnalytics.LadderRebirthSteps", "\n\n\tsendUpdate(player, \"Rebirth Complete!")
	local function ladderWithGate(gate)
		local config = loadConfig(1, if gate == 6 then nil else replaceOnce(configSource,
			"\nConfig%.World2UnlockRebirths = 6\n", "\nConfig.World2UnlockRebirths = " .. gate .. "\n"))
		assert(config.World2UnlockRebirths == gate)
		local Funnels, newPlayer, names = loadFunnels(config)
		local afterCommit = luau.load("return function(player, newRebirthCount)\n" .. ladderLines .. "\nend",
			{ environment = setmetatable({ FunnelAnalytics = Funnels }, { __index = _G }) })()
		local p = newPlayer(70 + gate, 0, false)
		for count = 1, 12 do
			afterCommit(p, count)
		end
		Funnels.Step(p, "Onboarding_Ladder", 6)
		return table.concat(names(p, "Onboarding_Ladder_v2"), ","), Funnels
	end

	-- The real Config (gate 6) gives the same ladder as the fallback.
	local steps6, funnels6 = ladderWithGate(6)
	assert(funnels6.World2GateRebirths == 6, "The ladder read the gate from the real Config")
	assert(steps6 == "Joined,Rebirth1,Rebirth3,Rebirth5,Rebirth6,World2Unlocked", "Gate 6: " .. steps6)
	assert(ladderWithGate(7) == "Joined,Rebirth1,Rebirth3,Rebirth5,Rebirth7,World2Unlocked", "Gate 7 (the old one)")
	local steps5, funnels5 = ladderWithGate(5)
	assert(steps5 == "Joined,Rebirth1,Rebirth3,Rebirth5,World2Unlocked", "Gate 5: World 2 is still sent, got " .. steps5)
	local numbers = {}
	for count, step in funnels5.LadderRebirthSteps do
		numbers[step] = count
	end
	assert(numbers[2] == 1 and numbers[3] == 3 and numbers[4] == nil and numbers[5] == 5, "Gate 5: rebirth 5 is the gate rung (step 5)")
	assert(ladderWithGate(3) == "Joined,Rebirth1,Rebirth3,World2Unlocked", "Gate 3")
	assert(ladderWithGate(10) == "Joined,Rebirth1,Rebirth3,Rebirth5,Rebirth10,World2Unlocked", "Gate 10")
	assert(ladderWithGate(0) == "Joined,World2Unlocked", "A level-only gate: no rebirth rungs, World 2 follows the join")
	pass("Onboarding_Ladder_v2 follows Config.World2UnlockRebirths: gates 3/5/6/7/10 and 0 all end in World2Unlocked")
end

print("ALL WORLD GATE CHECKS PASSED")
