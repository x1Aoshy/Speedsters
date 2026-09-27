-- Evolve button under fast taps (2026-09-22, owner: "When I tap Evolve a lot it gets slow and
-- doesn't do the evolve action; then I have to close and reopen the menu").
--
-- Root cause: the server's EquipSkin runs behind RemoteGuard (0.25 s, one call at a time), which
-- silently dropped a request that came while the previous one was still running or inside the
-- interval (e.g. a tap right after the panel's Sync). The client waited for an answer that never
-- came, and ignored every tap until the panel was reopened (its Sync cleared the wait).
--
-- Fix: RemoteGuard.Connect takes an optional onDropped, and EquipSkin uses it to answer a refused
-- request once the guard frees up; every EquipSkin path ends with sendUpdate plus
-- { AnsweredRequest = n } for the client's numbered request. The client keeps one evolve in
-- flight, paces fires 0.3 s apart, shows "..." while waiting and gives up after 4 s.
--
-- This test runs the REAL code on a fake clock and a fake network (0.1 s each way):
--   * the whole UI/EvolveController.client.luau, loaded with a fake game (real SuitCatalog and
--     EvolveAvailability), tapped through evolveButton.Activated;
--   * the REAL EquipSkin handler, extracted from Economy/SkinSystem.server.luau, behind the REAL
--     Services/RemoteGuard.luau; persistSkinSelection / applySkinById are stubs that yield.
-- Checks: every tap ends in an evolve or a visible reset within 4 s, the button is never left dead,
-- no suit is evolved twice, and spam stays limited. The old sources (output/FableFeel_20260922/
-- backup_src) are run through the same harness to show it reproduces the dead button.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local SuitCatalog = require("../src/common/ReplicatedStorage/Shared/SuitCatalog")
local Availability = require("../src/common/ReplicatedStorage/Shared/EvolveAvailability")

local CLIENT = "src/common/StarterPlayer/StarterPlayerScripts/UI/EvolveController.client.luau"
local SERVER = "src/common/ServerScriptService/Economy/SkinSystem.server.luau"
local GUARD = "src/common/ServerScriptService/Services/RemoteGuard.luau"
local BACKUP = "output/FableFeel_20260922/backup_src/"

local function pass(message) print("PASS " .. message) end
local function between(source, first, last, message)
	local a = string.find(source, first, 1, true)
	assert(a, message .. ": start not found")
	local b = string.find(source, last, a + #first, true)
	assert(b, message .. ": end not found")
	return string.sub(source, a, b - 1)
end

for _, path in { CLIENT, SERVER, GUARD } do
	local ok, problem = pcall(luau.compile, fs.readFile(path))
	assert(ok, "SYNTAX " .. path .. ": " .. tostring(problem))
end
pass("the three changed sources compile")

-- The EquipSkin handler with its guard: the new source has the refused-call answer in front.
local function extractHandler(source)
	if string.find(source, "local function answerEquipSkin", 1, true) then
		return between(source, "local function answerEquipSkin(player, requestId)", "\nlocal lastSkinStateAt", "EquipSkin handler")
	end
	return between(source, "RemoteGuard.Connect(EquipSkin, 0.25", "\nlocal lastSkinStateAt", "old EquipSkin handler")
end

----------------------------------------------------------------------
-- Fake clock and scheduler
----------------------------------------------------------------------
local now = 0
local queue = {}
local seq = 0
local function schedule(at, fn)
	seq += 1
	table.insert(queue, { at = at, seq = seq, fn = fn })
end
local function resume(co, ...)
	local ok, err = coroutine.resume(co, ...)
	if not ok then error(debug.traceback(co, tostring(err)), 0) end
end
local fakeTask = {}
function fakeTask.spawn(fn, ...)
	local co = if type(fn) == "thread" then fn else coroutine.create(fn)
	resume(co, ...)
	return co
end
function fakeTask.defer(fn, ...)
	local args = table.pack(...)
	local co = coroutine.create(fn)
	schedule(now, function() resume(co, table.unpack(args, 1, args.n)) end)
	return co
end
function fakeTask.delay(t, fn, ...)
	local args = table.pack(...)
	schedule(now + math.max(0, t or 0), function() resume(coroutine.create(fn), table.unpack(args, 1, args.n)) end)
end
function fakeTask.wait(t)
	local co = coroutine.running()
	local started = now
	schedule(now + math.max(0.03, t or 0), function() resume(co, now - started) end)
	return coroutine.yield()
end
local function runUntil(t)
	while true do
		table.sort(queue, function(a, b)
			if a.at ~= b.at then return a.at < b.at end
			return a.seq < b.seq
		end)
		local item = queue[1]
		if not item or item.at > t then break end
		table.remove(queue, 1)
		now = math.max(now, item.at)
		item.fn()
	end
	now = t
end
local fakeOs = { clock = function() return now end, time = function() return now end }

----------------------------------------------------------------------
-- Fake instances (enough for the controller)
----------------------------------------------------------------------
local function newSignal()
	local signal = { handlers = {} }
	function signal:Connect(fn)
		table.insert(self.handlers, fn)
		return { Disconnect = function() end, Connected = true }
	end
	function signal:Fire(...)
		for _, handler in ipairs(self.handlers) do fakeTask.spawn(handler, ...) end
	end
	return signal
end

local EVENTS = { Activated = true, InputBegan = true, OnClientEvent = true, OnServerEvent = true, Event = true, ChildAdded = true }
local methods = {}
local function newInst(name, className, parent, props)
	local raw = { props = { Name = name, ClassName = className or "Frame", ZIndex = 1, Visible = true, Enabled = true },
		children = {}, order = {}, events = {}, attrs = {}, attrSignals = {}, onSet = nil }
	for k, v in props or {} do raw.props[k] = v end
	local inst = setmetatable({}, {
		__index = function(self, key)
			local r = rawget(self, "__raw")
			if r.props[key] ~= nil then return r.props[key] end
			if methods[key] then return methods[key] end
			if EVENTS[key] then
				r.events[key] = r.events[key] or newSignal()
				return r.events[key]
			end
			if key == "Parent" then return r.parent end
			return r.children[key]
		end,
		__newindex = function(self, key, value)
			local r = rawget(self, "__raw")
			if key == "Parent" then
				r.parent = value
				if value then
					local pr = rawget(value, "__raw")
					if not pr.children[r.props.Name] then table.insert(pr.order, self) end
					pr.children[r.props.Name] = self
				end
				return
			end
			r.props[key] = value
			if r.onSet then r.onSet(key, value) end
		end,
	})
	rawset(inst, "__raw", raw)
	if parent then inst.Parent = parent end
	return inst
end
function methods.FindFirstChild(self, name) return rawget(self, "__raw").children[name] end
function methods.WaitForChild(self, name)
	return rawget(self, "__raw").children[name] or newInst(name, "Frame", self)
end
function methods.GetChildren(self) return table.clone(rawget(self, "__raw").order) end
function methods.FindFirstChildOfClass(self, className)
	for _, child in rawget(self, "__raw").order do
		if child.ClassName == className then return child end
	end
	return nil
end
function methods.IsA(self, className)
	local own = self.ClassName
	if own == className then return true end
	return className == "GuiObject" and own ~= "Sound" and own ~= "BoolValue" and own ~= "Folder"
end
function methods.Destroy(self) end
function methods.GetAttribute(self, name) return rawget(self, "__raw").attrs[name] end
function methods.SetAttribute(self, name, value)
	local r = rawget(self, "__raw")
	if r.attrs[name] == value then return end
	r.attrs[name] = value
	if r.attrSignals[name] then r.attrSignals[name]:Fire() end
end
function methods.GetAttributeChangedSignal(self, name)
	local r = rawget(self, "__raw")
	r.attrSignals[name] = r.attrSignals[name] or newSignal()
	return r.attrSignals[name]
end
function methods.Play(self) self.Plays = (self.Plays or 0) + 1 end

local Enum = setmetatable({}, { __index = function(_, category)
	return setmetatable({}, { __index = function(_, item) return category .. "." .. item end })
end })

----------------------------------------------------------------------
-- A world: one client (the real controller) and the server's real EquipSkin + RemoteGuard
----------------------------------------------------------------------
local LATENCY = 0.1
local ordered = SuitCatalog.Ordered

local function newWorld(options)
	now, queue, seq = 0, {}, 0
	local clientSource = fs.readFile(options.clientPath or (options.old and (BACKUP .. "common/StarterPlayer/StarterPlayerScripts/UI/EvolveController.client.luau")) or CLIENT)
	local serverSource = fs.readFile(options.old and (BACKUP .. "common/ServerScriptService/Economy/SkinSystem.server.luau") or SERVER)
	local guardSource = fs.readFile(options.old and (BACKUP .. "common/ServerScriptService/Services/RemoteGuard.luau") or GUARD)

	local world = {
		persistDelay = options.persistDelay or 0.2, applyDelay = options.applyDelay or 0.3,
		characterReady = options.characterReady ~= false, hang = false,
		stats = { received = {}, handlerRuns = {}, refusedAnswers = 0, sendUpdates = {}, evolves = {}, persists = {},
			indexMessages = {}, log = {}, answers = {}, droppedRuns = {}, answerArrivals = {}, fires = {}, pendingSpans = {}, markSeen = 0, failSounds = 0,
			draws = 0, previewApplies = 0, lastProgress = nil },
	}
	local stats = world.stats

	-- Server-side player and state
	local owned = { [SuitCatalog.DefaultSkinId] = true }
	local level, rebirths = options.level, options.rebirths or 0
	local serverPlayer = newInst("Runner", "Player", nil, {})
	rawget(serverPlayer, "__raw").parent = true -- in the game
	local clientPlayer -- set below

	local function replicateAttr(name, value)
		schedule(now + LATENCY, function() clientPlayer:SetAttribute(name, value) end)
	end
	local serverSetAttribute = methods.SetAttribute
	-- serverPlayer:SetAttribute replicates to the client after LATENCY
	rawget(serverPlayer, "__raw").props.SetAttribute = function(self, name, value)
		serverSetAttribute(self, name, value)
		replicateAttr(name, value)
	end
	serverPlayer:SetAttribute("DataLoaded", true)
	serverPlayer:SetAttribute("Level", level)
	serverPlayer:SetAttribute("Rebirths", rebirths)
	serverPlayer:SetAttribute("EquippedSkin", SuitCatalog.DefaultSkinId)

	local clientEvolveSkinUpdate = newInst("EvolveSkinUpdate", "RemoteEvent")
	local serverEquipSkin = newInst("EquipSkin", "RemoteEvent")
	local ownedFolder -- client replica of SpeedsterData.OwnedSkins

	local function payload()
		local nextEntry
		for _, entry in ordered do
			if not owned[entry.Id] then nextEntry = entry break end
		end
		return {
			Level = level, Rebirths = rebirths, EquippedSkin = serverPlayer:GetAttribute("EquippedSkin") or "",
			OwnedSkins = table.clone(owned), NextSkinId = nextEntry and nextEntry.Id or "",
		}
	end
	local function sendUpdate(player)
		table.insert(stats.sendUpdates, now)
		table.insert(stats.log, "update")
		local data = payload()
		schedule(now + LATENCY, function() clientEvolveSkinUpdate.OnClientEvent:Fire(data) end)
	end
	local function grant(skinId)
		if owned[skinId] then return end
		owned[skinId] = true
		schedule(now + LATENCY, function()
			newInst(skinId, "BoolValue", ownedFolder, { Value = true })
		end)
		-- The real OwnedSkins folder's ChildAdded pushes an update too (SkinSystem ~L2366).
		fakeTask.defer(function() sendUpdate(serverPlayer) end)
	end

	local realGuard = luau.load(guardSource, { debugName = "RemoteGuard", environment = {
		os = fakeOs, task = fakeTask, setmetatable = setmetatable, pcall = pcall, warn = warn, math = math, tostring = tostring,
	} })()
	local guard = { Connect = function(remote, interval, handler, onDropped)
		local wrapped = if onDropped then function(player, ...)
			stats.refusedAnswers += 1
			table.insert(stats.droppedRuns, now)
			return onDropped(player, ...)
		end else nil
		return realGuard.Connect(remote, interval, function(player, ...)
			table.insert(stats.handlerRuns, now)
			return handler(player, ...)
		end, wrapped)
	end }

	local handlerChunk = extractHandler(serverSource)
	local evolveInProgress = {}
	luau.load(handlerChunk, { debugName = "EquipSkinHandler", environment = {
		RemoteGuard = guard, EquipSkin = serverEquipSkin, sendUpdate = sendUpdate,
		EvolveSkinUpdate = { FireClient = function(_, player, data)
			table.insert(stats.log, "answer:" .. tostring(data.AnsweredRequest))
			table.insert(stats.answers, now)
			schedule(now + LATENCY, function()
				if data.AnsweredRequest ~= nil then stats.answerArrivals[data.AnsweredRequest] = now end
				clientEvolveSkinUpdate.OnClientEvent:Fire(data)
			end)
		end },
		sendIndexUpdate = function(player, message)
			table.insert(stats.indexMessages, message or "")
			table.insert(stats.log, "index:" .. tostring(message or ""))
		end,
		evolveInProgress = evolveInProgress,
		getNextEvolutionEntry = function()
			for _, entry in ordered do
				if not owned[entry.Id] then return entry end
			end
			return nil
		end,
		getLevel = function() return level end, getRebirths = function() return rebirths end,
		persistSkinSelection = function(player, skinId, grantIt)
			table.insert(stats.persists, skinId)
			fakeTask.wait(world.persistDelay)
			while world.hang do fakeTask.wait(0.5) end
			if grantIt then grant(skinId) end
			return true
		end,
		applySkinById = function(player, skinId)
			if not world.characterReady then return false end
			player:SetAttribute("EquippedSkin", skinId)
			fakeTask.wait(world.applyDelay)
			sendUpdate(player) -- the real applySkinById ends with sendUpdate as well
			return true
		end,
		unlockSkin = function(player, skinId)
			if not owned[skinId] then grant(skinId) end
			table.insert(stats.evolves, skinId)
		end,
		saveSkinState = function() end, unequipFlashSuit = function() end, forceBaseStamina = function() end,
		refreshCosmeticsAfterSkin = function() end,
		type = type, tostring = tostring, tonumber = tonumber, math = math, pcall = pcall, warn = warn,
	} })()

	-- Client world
	local game = newInst("Game", "DataModel")
	local Players = newInst("Players", "Players", game)
	local ReplicatedStorage = newInst("ReplicatedStorage", "ReplicatedStorage", game)
	local SoundService = newInst("SoundService", "SoundService", game)
	local services = { Players = Players, ReplicatedStorage = ReplicatedStorage, SoundService = SoundService,
		TweenService = newInst("TweenService", "TweenService", game), MarketplaceService = newInst("MarketplaceService", "MarketplaceService", game) }
	rawget(game, "__raw").props.GetService = function(_, name) return services[name] end
	rawget(Players, "__raw").props.GetUserThumbnailAsync = function() return "rbxthumb://avatar" end
	rawget(SoundService, "__raw").props.PlayLocalSound = function() stats.failSounds += 1 end
	rawget(services.TweenService, "__raw").props.Create = function()
		return { Play = function() end, Cancel = function() end }
	end
	rawget(services.MarketplaceService, "__raw").props.PromptProductPurchase = function() end
	rawget(services.MarketplaceService, "__raw").props.PromptGamePassPurchase = function() end

	clientPlayer = newInst("Runner", "Player", Players, { UserId = 1 })
	rawget(Players, "__raw").props.LocalPlayer = clientPlayer
	local playerGui = newInst("PlayerGui", "PlayerGui", clientPlayer)
	local data = newInst("SpeedsterData", "Folder", clientPlayer)
	ownedFolder = newInst("OwnedSkins", "Folder", data)
	newInst(SuitCatalog.DefaultSkinId, "BoolValue", ownedFolder, { Value = true })
	for name, value in rawget(serverPlayer, "__raw").attrs do methods.SetAttribute(clientPlayer, name, value) end

	local gui = newInst("Evolve", "ScreenGui", playerGui)
	local frame = newInst("Evolve", "Frame", gui)
	local button = newInst("EvolveButton", "TextButton", frame)
	local label = newInst("Name", "TextLabel", button, { Text = "Evolve" })
	world.button, world.label = button, label
	local pendingSince = nil
	rawget(label, "__raw").onSet = function(key, value)
		if key ~= "Text" then return end
		if value == "..." and not pendingSince then
			pendingSince = now
		elseif value ~= "..." and pendingSince then
			table.insert(stats.pendingSpans, { from = pendingSince, to = now })
			pendingSince = nil
		end
	end
	function world.pendingSince() return pendingSince end

	local shared = newInst("Shared", "Folder", ReplicatedStorage)
	local remotes = newInst("Remotes", "Folder", ReplicatedStorage)
	local clientEquipSkin = newInst("EquipSkin", "RemoteEvent", remotes)
	clientEvolveSkinUpdate.Parent = remotes
	rawget(clientEquipSkin, "__raw").props.FireServer = function(_, argument, requestId)
		table.insert(stats.fires, { at = now, arg = argument, id = requestId })
		local uplink = if world.uplink then world.uplink(argument) else LATENCY
		schedule(now + uplink, function()
			table.insert(stats.received, now)
			serverEquipSkin.OnServerEvent:Fire(serverPlayer, argument, requestId)
		end)
	end

	local openEvolvePanel = { Event = newSignal() }
	world.openEvolvePanel = openEvolvePanel
	local modules = {
		Config = { DefaultSuitSpeedGainMultiplier = 1, SuitSpeedGainMultipliers = {} },
		SuitCatalog = SuitCatalog,
		MenuEvents = { Get = function() return openEvolvePanel end, CloseAll = { Event = newSignal() },
			MarkReady = function() end, Request = function() end },
		MenuPanelLayout = { BindPhoneFit = function() end },
		-- A full redraw = one ProgressBar update (plus two SkinPreview.Apply), counted here.
		SkinPreview = { Apply = function() stats.previewApplies += 1 end },
		ProgressBar = { Bind = function() return function(ratio, caption)
			stats.draws += 1
			stats.lastProgress = { ratio = ratio, caption = caption }
		end end },
		EvolveAvailability = Availability,
		TutorialGuide = { MarkSeen = function() stats.markSeen += 1 end, Start = function() return false end },
		ConsolePanelSupport = { Bind = function() end },
	}
	for name, module in modules do newInst(name, "ModuleScript", shared, { __module = module }) end

	luau.load(clientSource, { debugName = "EvolveController", environment = {
		game = game, os = fakeOs, task = fakeTask, Enum = Enum,
		require = function(moduleScript) return assert(moduleScript.__module, "unknown module") end,
		Instance = { new = function(className) return newInst(className, className) end },
		Color3 = { fromRGB = function(r, g, b) return { R = r, G = g, B = b } end },
		UDim2 = { new = function(...) return { ... } end, fromScale = function(...) return { ... } end },
		TweenInfo = { new = function(...) return { ... } end },
		print = function() end, warn = warn, math = math, string = string, table = table, ipairs = ipairs, pairs = pairs,
		type = type, tostring = tostring, tonumber = tonumber, pcall = pcall, setmetatable = setmetatable, select = select,
		next = next, error = error, assert = assert,
	} })()
	runUntil(0.5)

	function world.tap() button.Activated:Fire() end
	function world.fireRaw(argument, requestId) clientEquipSkin:FireServer(argument, requestId) end
	function world.evolveSoundPlays()
		local sound = SoundService:FindFirstChild("SuitEvolveSound")
		return sound and sound.Plays or 0
	end
	function world.open() openEvolvePanel.Event:Fire("Open") end
	function world.run(t) runUntil(t) end
	function world.owned() return owned end
	function world.evolveFires()
		local list = {}
		for _, fire in stats.fires do
			if fire.arg ~= "Sync" then table.insert(list, fire) end
		end
		return list
	end
	function world.maxPendingSpan()
		local longest = 0
		for _, span in stats.pendingSpans do longest = math.max(longest, span.to - span.from) end
		if pendingSince then longest = math.max(longest, now - pendingSince) end
		return longest
	end
	function world.setCharacterReady(ready) world.characterReady = ready end
	-- Server-side data changes (replicated to the client after LATENCY)
	function world.setLevel(value) level = value serverPlayer:SetAttribute("Level", value) end
	function world.setRebirths(value) rebirths = value serverPlayer:SetAttribute("Rebirths", value) end
	function world.setEquipped(skinId) serverPlayer:SetAttribute("EquippedSkin", skinId) end
	function world.grant(skinId) grant(skinId) end
	function world.sendUpdate() sendUpdate(serverPlayer) end
	world.frame = frame
	return world
end

local function countOf(list, value)
	local n = 0
	for _, item in list do if item == value then n += 1 end end
	return n
end
local function assertNoDoubleEvolve(world, label, rawSpam)
	local seen = {}
	for _, skinId in world.stats.evolves do
		assert(not seen[skinId], label .. ": " .. skinId .. " evolved twice")
		seen[skinId] = true
	end
	for _, skinId in world.stats.persists do
		assert(countOf(world.stats.persists, skinId) == 1, label .. ": " .. skinId .. " persisted more than once")
	end
	for _, message in if rawSpam then {} else world.stats.indexMessages do
		assert(message ~= "Use Evolve in order, or equip an owned skin from Index", label .. ": a stale evolve reached the server")
	end
end
-- Never two evolve requests in flight: the next one leaves after the previous one's answer
-- reached the client, or after the 4 s timeout gave up on it.
local function assertOneInFlight(world, label)
	local fires = world.evolveFires()
	for index = 2, #fires do
		local previous, current = fires[index - 1], fires[index]
		local answered = world.stats.answerArrivals[previous.id]
		assert((answered and answered <= current.at) or current.at - previous.at >= 4 - 1e-6,
			string.format("%s: request %s left at %.3f while %s (sent %.3f) was unanswered", label, tostring(current.id), current.at, tostring(previous.id), previous.at))
	end
end

-- The button is alive: a tap now (evolution available) reaches the server within 0.3 s.
local function assertAlive(world, label)
	assert(world.label.Text ~= "...", label .. ": button still shows ... at " .. now)
	local before = #world.evolveFires()
	world.tap()
	world.run(now + 0.31)
	assert(#world.evolveFires() == before + 1, label .. ": a tap did not reach the server (button dead)")
end

local REQ1 = ordered[2]
local level1, rebirths1 = REQ1.RequiredLevel or 0, REQ1.RequiredRebirths or 0
local owned0 = { [SuitCatalog.DefaultSkinId] = true }
assert(Availability.Count(ordered, owned0, level1, rebirths1) >= 1, "one evolution available at the first suit's level")
local level3, rebirths3 = ordered[4].RequiredLevel or 0, ordered[4].RequiredRebirths or 0
local available3 = Availability.Count(ordered, owned0, level3, rebirths3)
assert(available3 >= 3, "three evolutions available at the third suit's level")

----------------------------------------------------------------------
-- 0. The harness reproduces the owner's bug on the old sources
----------------------------------------------------------------------
do
	local world = newWorld({ old = true, level = level1, rebirths = rebirths1 })
	world.open()
	world.run(now + 0.21) -- the Sync's answer has just drawn the panel (0.2 s round trip)
	world.tap() -- reaches the server 0.21 s after the Sync: inside its 0.25 s guard
	world.run(now + 10)
	assert(#world.stats.evolves == 0, "old: the request was dropped")
	local fires = #world.evolveFires()
	world.tap()
	world.run(now + 1)
	assert(#world.evolveFires() == fires, "old: the button is dead after a dropped request")
	pass("old sources: a tap right after opening is dropped by RemoteGuard and every later tap is ignored (the owner's dead button)")
end
do
	local world = newWorld({ level = level1, rebirths = rebirths1 })
	world.open()
	world.run(now + 0.21)
	world.tap()
	world.run(now + 3)
	assert(#world.stats.evolves == 1 and world.label.Text == "Evolve", "new: the same tap evolves")
	pass("new sources, same taps: the evolve lands and the button comes back")
end

----------------------------------------------------------------------
-- 1. Taps faster than the guard (one evolution available)
----------------------------------------------------------------------
do
	local world = newWorld({ level = level1, rebirths = rebirths1 })
	world.open()
	world.run(now + 1)
	local start = now
	for i = 1, 40 do
		world.tap()
		world.run(start + i * 0.05)
	end
	world.run(now + 5)
	assert(world.owned()[REQ1.Id] and #world.stats.evolves == 1, "one evolve")
	assertNoDoubleEvolve(world, "fast taps")
	assert(#world.evolveFires() == 1, "one evolve request sent, got " .. #world.evolveFires())
	assert(world.label.Text == "Evolve" and world.maxPendingSpan() < 4, "the button came back")
	assert(world.stats.markSeen == 1 and world.evolveSoundPlays() == 1, "MarkSeen once, one evolve sound")
	pass(string.format("40 taps at 20/s: 1 request, 1 evolve, '...' for %.2f s, then the button is back", world.maxPendingSpan()))
end

----------------------------------------------------------------------
-- 2. Taps during a slow (yielding) evolve
----------------------------------------------------------------------
do
	local world = newWorld({ level = level3, rebirths = rebirths3, persistDelay = 1.5, applyDelay = 1.0 })
	world.open()
	world.run(now + 1)
	local start = now
	world.tap()
	world.run(start + 0.05)
	assert(world.label.Text == "...", "feedback at once: the button shows ...")
	assert(world.button.AutoButtonColor == false, "and is dimmed")
	for i = 1, 20 do
		world.tap()
		world.run(start + 0.05 + i * 0.1)
		if world.label.Text ~= "..." then break end
	end
	assert(#world.evolveFires() == 1, "no second request while the first is in flight")
	world.run(start + 4)
	assert(world.owned()[ordered[2].Id] and #world.stats.evolves == 1, "the slow evolve landed")
	assertNoDoubleEvolve(world, "slow evolve")
	assertOneInFlight(world, "slow evolve")
	assert(world.label.Text == "Evolve", "the button is back after the answer: " .. tostring(world.label.Text))
	assert(world.evolveSoundPlays() == 1, "one evolve sound")
	assert(world.maxPendingSpan() < 4, "answered before the timeout")
	assertAlive(world, "after the slow evolve")
	pass(string.format("slow evolve (2.5 s of server yields): '...' at once, taps ignored, 1 evolve, button back after %.2f s and usable", world.stats.pendingSpans[1].to - world.stats.pendingSpans[1].from))
end

----------------------------------------------------------------------
-- 3. A Sync right before a tap (the owner's case)
----------------------------------------------------------------------
do
	local world = newWorld({ level = level1, rebirths = rebirths1 })
	world.open()
	world.run(now + 0.05)
	world.tap()
	world.run(now + 3)
	local fires = world.stats.fires
	assert(fires[1].arg == "Sync" and fires[2].arg == REQ1.Id, "Sync, then the evolve")
	local gap = fires[2].at - fires[1].at
	assert(gap >= 0.3 - 1e-9, "the evolve waited for the guard: gap " .. gap)
	assert(world.owned()[REQ1.Id] and #world.stats.evolves == 1, "the evolve landed")
	assert(world.stats.refusedAnswers == 0, "nothing refused")
	assert(world.label.Text == "Evolve", "button back")
	-- A request the server refuses (a client without pacing) is answered once, after the guard.
	local world2 = newWorld({ level = level1, rebirths = rebirths1 })
	world2.run(now + 1)
	local refusedStart = now
	local updatesBefore = #world2.stats.sendUpdates
	world2.fireRaw("Sync")
	world2.run(now + 0.05)
	world2.fireRaw("Sync")
	world2.fireRaw("Sync")
	world2.run(now + 1)
	assert(#world2.stats.handlerRuns == 1 and world2.stats.refusedAnswers == 1, "2 refused calls, 1 coalesced answer")
	assert(#world2.stats.sendUpdates == updatesBefore + 2, "the Sync's answer and the coalesced one")
	local answeredAt = world2.stats.sendUpdates[#world2.stats.sendUpdates]
	assert(answeredAt >= refusedStart + LATENCY + 0.25 - 1e-9 and answeredAt < refusedStart + 0.5, "answered when the guard frees up: " .. answeredAt)
	-- Numbered requests refused in a burst: one answer, carrying the last one's number.
	world2.fireRaw("Sync")
	world2.run(now + 0.05)
	world2.fireRaw("NotASuit", 41)
	world2.fireRaw("NotASuit", 42)
	world2.run(now + 1)
	assert(world2.stats.answerArrivals[42] and not world2.stats.answerArrivals[41], "the coalesced answer names the last refused request")
	pass(string.format("tap 0.05 s after opening: the evolve is sent %.2f s after the Sync (outside the 0.25 s guard) and lands; refused calls get one coalesced answer when the guard frees up", gap))
end

----------------------------------------------------------------------
-- 3b. Uneven network delay: the paced evolve reaches the server inside the Sync's guard
----------------------------------------------------------------------
do
	-- Sync takes 0.2 s to arrive, the evolve 0.05 s: 0.3 s apart on the client, 0.15 s at the
	-- server. The guard refuses the evolve; it must still run once the guard frees up.
	local world = newWorld({ level = level1, rebirths = rebirths1 })
	world.uplink = function(argument) return if argument == "Sync" then 0.2 else 0.05 end
	world.open()
	world.run(now + 0.1)
	world.tap()
	world.run(now + 3)
	local fires = world.stats.fires
	assert(fires[1].arg == "Sync" and fires[2].arg == REQ1.Id, "Sync, then the evolve")
	assert(world.stats.refusedAnswers == 1, "the evolve was refused by the guard at the server")
	assert(world.owned()[REQ1.Id] and #world.stats.evolves == 1, "the refused evolve still ran")
	assert(countOf(world.stats.indexMessages, "Unlocked and equipped") == 1, "with its success message")
	assert(world.evolveSoundPlays() == 1, "one evolve sound")
	assert(world.label.Text == "Evolve" and world.maxPendingSpan() < 1.5, "button back: " .. world.maxPendingSpan())
	assertNoDoubleEvolve(world, "uneven delay")
	-- Random uneven delays, 3 evolutions, panel reopened now and then: every evolution lands.
	local world2 = newWorld({ level = level3, rebirths = rebirths3 })
	local state = 99
	local function random()
		state = (state * 1103515245 + 12345) % 2147483648
		return state / 2147483648
	end
	world2.uplink = function() return 0.02 + 0.4 * random() end
	world2.open()
	local stop = now + 10
	while now < stop do
		world2.tap()
		world2.run(now + 0.07)
		if random() < 0.1 then world2.open() end
	end
	world2.run(now + 5)
	assert(world2.stats.refusedAnswers > 0, "the random delays did make the guard refuse calls")
	assert(#world2.stats.evolves == available3, "every available evolution landed: " .. #world2.stats.evolves)
	assertNoDoubleEvolve(world2, "uneven random delay")
	assert(world2.maxPendingSpan() < 4, "every wait answered")
	assert(world2.label.Text ~= "...", "button not dead")
	pass(string.format("uneven delay (Sync 0.2 s, evolve 0.05 s): the guard refuses the evolve at the server, it runs when the guard frees up, button back after %.2f s; random 0.02-0.42 s delays: %d/%d evolutions land, %d refused calls", world.maxPendingSpan(), #world2.stats.evolves, available3, world2.stats.refusedAnswers))
end

----------------------------------------------------------------------
-- 4. 'Character is not ready'
----------------------------------------------------------------------
-- The handler's own answer: an index message directly followed by sendUpdate.
local function answeredAfter(world, message)
	local log = world.stats.log
	for index, entry in log do
		if entry == "index:" .. message then
			return log[index + 1] == "update" and string.sub(log[index + 2] or "", 1, 7) == "answer:"
		end
	end
	return false
end

do
	-- persistSkinSelection grants before applySkinById runs (as the real one commits GrantSkin),
	-- so after this failure the suit is owned and the next tap evolves the following suit.
	local world = newWorld({ level = level3, rebirths = rebirths3, characterReady = false })
	world.open()
	world.run(now + 1)
	local start = now
	world.tap()
	world.run(start + 2)
	assert(#world.stats.evolves == 0 and countOf(world.stats.indexMessages, "Character is not ready") == 1, "failed: not ready")
	assert(answeredAfter(world, "Character is not ready"), "'Character is not ready' is followed by sendUpdate")
	assert(world.label.Text == "Evolve", "the failure is answered: the button is back")
	local span = world.stats.pendingSpans[1].to - world.stats.pendingSpans[1].from
	assert(span < 1, "answered by EvolveSkinUpdate, not the timeout: " .. span)
	world.setCharacterReady(true)
	assertAlive(world, "after 'Character is not ready'")
	world.run(now + 3)
	assert(#world.stats.evolves == 1 and world.owned()[ordered[3].Id], "the next tap evolves")
	assert(answeredAfter(world, "Unlocked and equipped"), "a success is followed by sendUpdate")
	assertNoDoubleEvolve(world, "not ready")
	assertOneInFlight(world, "not ready")
	pass(string.format("'Character is not ready' and a success both end with sendUpdate: button back after %.2f s, the next tap evolves", span))
end

----------------------------------------------------------------------
-- 5. Three evolutions available, tapped quickly
----------------------------------------------------------------------
do
	local world = newWorld({ level = level3, rebirths = rebirths3 })
	world.open()
	world.run(now + 0.1)
	local start = now
	local t = start
	while t < start + 6 do
		world.tap()
		t += 0.12
		world.run(t)
	end
	world.run(now + 5)
	for index = 2, 4 do
		assert(world.owned()[ordered[index].Id], "evolved to " .. ordered[index].Id)
	end
	assert(#world.stats.evolves == available3, "exactly the available evolutions: " .. #world.stats.evolves)
	assertNoDoubleEvolve(world, "three quick evolves")
	assertOneInFlight(world, "three quick evolves")
	assert(world.maxPendingSpan() < 4, "every wait answered")
	local sound = world.evolveSoundPlays()
	assert(sound == available3, "one evolve sound per evolve")
	assert(world.label.Text ~= "...", "the button is back")
	pass(string.format("%d evolutions tapped every 0.12 s: all %d land in order, none twice, longest wait %.2f s, %d evolve sounds", available3, #world.stats.evolves, world.maxPendingSpan(), sound))
end

----------------------------------------------------------------------
-- 6. No answer at all: the 4 s timeout gives the button back and re-syncs
----------------------------------------------------------------------
do
	local world = newWorld({ level = level1, rebirths = rebirths1 })
	world.open()
	world.run(now + 1)
	world.hang = true
	local start = now
	world.tap()
	world.run(start + 3.9)
	assert(world.label.Text == "...", "still waiting at 3.9 s")
	local syncs = 0
	for _, fire in world.stats.fires do if fire.arg == "Sync" then syncs += 1 end end
	world.run(start + 4.01)
	assert(world.label.Text == "Evolve", "reset at 4 s")
	local syncsAfter = 0
	for _, fire in world.stats.fires do if fire.arg == "Sync" then syncsAfter += 1 end end
	assert(syncsAfter == syncs + 1, "and re-synced")
	world.hang = false
	world.run(now + 3)
	assert(#world.stats.evolves == 1, "the late evolve still lands once")
	assertNoDoubleEvolve(world, "timeout")
	pass("a request that is never answered: '...' until 4.0 s, then the button is back and a Sync is sent")
end

----------------------------------------------------------------------
-- 7. Spam is still limited (a client firing EquipSkin directly, 50/s for 4 s)
----------------------------------------------------------------------
do
	local world = newWorld({ level = level3, rebirths = rebirths3 })
	world.run(now + 1)
	local start = now
	for i = 1, 200 do
		world.fireRaw(if i % 3 == 0 then "Sync" else ordered[2].Id)
		world.run(start + i * 0.02)
	end
	world.run(now + 2)
	local worst, worstUpdates = 0, 0
	for second = 0, 4 do
		local a, b = start + second, start + second + 1
		local runs, updates = 0, 0
		for _, t in world.stats.handlerRuns do if t >= a and t < b then runs += 1 end end
		-- a refused call's answer runs under the guard too (and may run the handler)
		for _, t in world.stats.droppedRuns do if t >= a and t < b then runs += 1 end end
		for _, t in world.stats.sendUpdates do if t >= a and t < b then updates += 1 end end
		worst = math.max(worst, runs)
		worstUpdates = math.max(worstUpdates, updates)
	end
	assert(#world.stats.received == 200, "all 200 arrived")
	assert(worst <= 5, "handler runs per second stay limited: " .. worst)
	assert(worstUpdates <= 12, "answers per second stay limited: " .. worstUpdates)
	assertNoDoubleEvolve(world, "spam", true) -- raw spam repeats a stale id on purpose
	pass(string.format("200 raw EquipSkin in 4 s: at most %d handler runs and %d answers per second (%d refused calls answered in bursts: %d)", worst, worstUpdates, 200 - #world.stats.handlerRuns, world.stats.refusedAnswers))
end

----------------------------------------------------------------------
-- 8. RemoteGuard without onDropped behaves exactly like before
----------------------------------------------------------------------
do
	local function trace(source)
		now, queue, seq = 0, {}, 0
		local guard = luau.load(source, { environment = {
			os = fakeOs, task = fakeTask, setmetatable = setmetatable, pcall = pcall, warn = function() end, math = math, tostring = tostring,
		} })()
		local remote = newInst("R", "RemoteEvent")
		local runs = {}
		guard.Connect(remote, 0.25, function(player, n)
			table.insert(runs, string.format("%s:%d@%.3f", player.Name, n, now))
			if n % 4 == 0 then fakeTask.wait(0.4) end
			if n % 7 == 0 then error("boom") end
		end)
		local a, b = newInst("A", "Player"), newInst("B", "Player")
		local state = 7
		local rng = { NextNumber = function(_, lo, hi)
			state = (state * 1103515245 + 12345) % 2147483648
			lo, hi = lo or 0, hi or 1
			return lo + (hi - lo) * state / 2147483648
		end }
		local t = 0
		for n = 1, 300 do
			t += rng:NextNumber(0, 0.2)
			local who = if rng:NextNumber() < 0.5 then a else b
			schedule(t, function() remote.OnServerEvent:Fire(who, n) end)
		end
		runUntil(t + 2)
		return table.concat(runs, ",")
	end
	local old = trace(fs.readFile(BACKUP .. "common/ServerScriptService/Services/RemoteGuard.luau"))
	local new = trace(fs.readFile(GUARD))
	assert(#old > 0 and old == new, "RemoteGuard without onDropped changed behaviour")
	pass("RemoteGuard without onDropped: 300 random calls from 2 players run exactly as with the old guard")
end

----------------------------------------------------------------------
-- 9. Random taps, server delays and character readiness (30 runs)
----------------------------------------------------------------------
do
	local state = 12345
	local function random(lo, hi)
		state = (state * 1103515245 + 12345) % 2147483648
		return lo + (hi - lo) * state / 2147483648
	end
	local longest, taps = 0, 0
	for run = 1, 30 do
		local world = newWorld({ level = level3, rebirths = rebirths3, persistDelay = random(0, 1.5), applyDelay = random(0, 1.5) })
		if run % 2 == 0 then world.open() end
		local stop = now + 12
		while now < stop do
			world.persistDelay, world.applyDelay = random(0, 1.5), random(0, 1.5)
			world.setCharacterReady(random(0, 1) < 0.8)
			world.tap()
			taps += 1
			world.run(now + random(0.01, 0.6))
			if random(0, 1) < 0.05 then world.open() end
		end
		world.setCharacterReady(true)
		world.run(now + 5)
		assertNoDoubleEvolve(world, "random run " .. run)
		assertOneInFlight(world, "random run " .. run)
		assert(world.maxPendingSpan() <= 4 + 1e-6, "random run " .. run .. ": waited " .. world.maxPendingSpan())
		assert(world.label.Text ~= "...", "random run " .. run .. ": button left dead")
		longest = math.max(longest, world.maxPendingSpan())
	end
	pass(string.format("30 random runs (%d taps, server yields 0-1.5 s, 20%% 'not ready'): no double evolve, longest '...' %.2f s, never left dead", taps, longest))
end

----------------------------------------------------------------------
-- 10. Redraw only on a real change (2026-09-22 polish, owner: tapping repeatedly re-ran the
--     whole updateFromData on every tap: Availability.Count, SkinPreview.Apply, attributes)
----------------------------------------------------------------------
do
	local POLISH_BACKUP = "output/FablePolish_20260922/backup_src/common/StarterPlayer/StarterPlayerScripts/UI/EvolveController.client.luau"
	local low = level1 - 1
	assert(low >= 1, "a level below the first evolve")
	local function tapMany(world, n)
		local start = now
		for i = 1, n do
			world.tap()
			world.run(start + i * 0.05)
		end
		world.run(now + 0.5)
	end
	local function text(world, name) return world.frame:FindFirstChild(name).Text end

	-- Before the polish: every tap redrew the panel.
	local oldDraws = nil
	if fs.isFile(POLISH_BACKUP) then
		local old = newWorld({ clientPath = POLISH_BACKUP, level = low, rebirths = 0 })
		old.open()
		old.run(now + 1)
		local before = old.stats.draws
		tapMany(old, 50)
		oldDraws = old.stats.draws - before
		assert(oldDraws >= 50, "the pre-polish controller redraws on every tap: " .. oldDraws)
	end

	local world = newWorld({ level = low, rebirths = 0 })
	local stats = world.stats
	world.open()
	world.run(now + 1)
	assert(stats.draws >= 1 and stats.lastProgress.caption == string.format("Level %d/%d", low, level1), "drawn once opened: " .. tostring(stats.lastProgress and stats.lastProgress.caption))
	-- 50 taps with nothing changing: at most one full redraw, the fail sound on every tap.
	local drawsBefore, appliesBefore, failBefore = stats.draws, stats.previewApplies, stats.failSounds
	tapMany(world, 50)
	local tapDraws = stats.draws - drawsBefore
	assert(tapDraws <= 1, "50 taps without a data change redrew " .. tapDraws .. " times")
	assert(stats.previewApplies - appliesBefore <= 2, "SkinPreview.Apply not re-run per tap")
	assert(stats.failSounds - failBefore == 50, "the requirement-fail sound still plays per tap")
	assert(#world.evolveFires() == 0, "no evolve sent below the level")
	-- Identical server updates (e.g. repeated Syncs) do not redraw either.
	drawsBefore = stats.draws
	for _ = 1, 10 do world.sendUpdate() end
	world.run(now + 0.5)
	assert(stats.draws == drawsBefore, "identical updates redrew " .. (stats.draws - drawsBefore) .. " times")

	local function expectOne(label, change, check)
		local before = stats.draws
		change()
		world.run(now + 0.5)
		assert(stats.draws - before == 1, label .. ": expected exactly one redraw, got " .. (stats.draws - before))
		check()
	end
	local GOLD, GREY = 205, 105
	-- Level up: the evolve becomes available.
	expectOne("level up", function() world.setLevel(level1) end, function()
		assert(stats.lastProgress.caption == string.format("Level %d/%d", level1, level1) and stats.lastProgress.ratio == 1, "level caption")
		assert(world.label.Text == "Evolve" and world.button.BackgroundColor3.G == GOLD and world.button.AutoButtonColor == true, "button gold")
	end)
	-- Rebirth: drawn once (nothing visible depends on it for this suit, but it is an input).
	expectOne("rebirth", function() world.setRebirths(1) end, function()
		assert(stats.lastProgress.caption == string.format("Level %d/%d", level1, level1), "rebirth caption")
	end)
	-- The evolve: pending on, the new suit (owned + equipped), the answer (pending off).
	drawsBefore = stats.draws
	world.tap()
	world.run(now + 0.05)
	assert(stats.draws == drawsBefore + 1 and world.label.Text == "..." and world.button.BackgroundColor3.G ~= GOLD, "pending on: one redraw showing ...")
	world.run(now + 3)
	local evolveDraws = stats.draws - drawsBefore
	assert(#stats.evolves == 1 and world.owned()[REQ1.Id], "the evolve landed")
	assert(evolveDraws >= 2 and evolveDraws <= 4, "the evolve redraws once per changed state (pending on, suit owned, equipped, pending off): " .. evolveDraws)
	local zoom, savitar = ordered[3], ordered[4]
	assert(text(world, "NameBefore") == REQ1.DisplayName and text(world, "NameAfter") == zoom.DisplayName, "evolved names drawn")
	assert(world.label.Text == "Evolve" and world.button.BackgroundColor3.G == GREY, "button back, grey (next suit locked)")
	assert(stats.lastProgress.caption == string.format("Level %d/%d | Rebirths 1/%d", level1, zoom.RequiredLevel, zoom.RequiredRebirths), "next requirement drawn: " .. stats.lastProgress.caption)
	assert(stats.markSeen == 1 and world.evolveSoundPlays() == 1, "MarkSeen and the evolve sound kept")
	-- Taps on a locked suit after the evolve: still no redraw.
	drawsBefore = stats.draws
	tapMany(world, 50)
	assert(stats.draws == drawsBefore, "taps after the evolve redrew " .. (stats.draws - drawsBefore) .. " times")
	-- EquippedSkin change (back to the starter suit from the Index).
	expectOne("EquippedSkin", function() world.setEquipped(SuitCatalog.DefaultSkinId) end, function()
		assert(text(world, "NameBefore") == REQ1.DisplayName, "highest owned suit still shown")
	end)
	-- OwnedSkins change (a suit granted outside the panel).
	expectOne("OwnedSkins", function() world.grant(zoom.Id) end, function()
		assert(text(world, "NameBefore") == zoom.DisplayName and text(world, "NameAfter") == savitar.DisplayName, "granted suit drawn")
		assert(stats.lastProgress.caption == string.format("Level %d/%d | Rebirths 1/%d", level1, savitar.RequiredLevel, savitar.RequiredRebirths), "granted caption")
	end)
	-- Pending on/off through the 4 s safety timeout: one redraw each.
	world.setLevel(savitar.RequiredLevel)
	world.setRebirths(savitar.RequiredRebirths)
	world.run(now + 0.5)
	world.hang = true
	drawsBefore = stats.draws
	local start = now
	world.tap()
	world.run(start + 3.9)
	assert(stats.draws == drawsBefore + 1 and world.label.Text == "...", "pending on: one redraw")
	world.run(start + 4.01)
	assert(stats.draws == drawsBefore + 2 and world.label.Text == "Evolve", "pending off at the timeout: one redraw")
	world.hang = false
	world.run(now + 3)
	assert(world.owned()[savitar.Id] and text(world, "NameBefore") == savitar.DisplayName, "the late evolve is drawn")
	pass(string.format("redraw signature: 50 taps with no data change -> %d redraws (pre-polish %s); level up, rebirth, EquippedSkin, OwnedSkins -> 1 each; an evolve -> %d (pending on .. answer); pending on/off at the timeout -> 1 each",
		tapDraws, if oldDraws then tostring(oldDraws) else "n/a", evolveDraws))
end

print("ALL PASS test_feel_evolve")
