local fs = require("@lune/fs")
local luau = require("@lune/luau")
local rb = require("@lune/roblox")
local function between(source, first, last)
	local a = assert(source:find(first, 1, true), first)
	local b = assert(source:find(last, a + #first, true), last)
	return source:sub(a, b - 1)
end
local function treadmillHarness(source)
	local now, credited, calls, notices = 0, 0, 0, 0
	local ready, allowed, reenter = true, true, nil
	local humanoid = { Health = 100 }
	local root = { Position = rb.Vector3.zero }
	local character = {
		FindFirstChildOfClass = function() return humanoid end,
		FindFirstChild = function() return root end,
	}
	local player = { Character = character, Name = "Runner", attrs = {} }
	function player:SetAttribute(k, v) self.attrs[k] = v end
	function player:GetAttribute(k) return self.attrs[k] end
	local belt = { GetAttribute = function() return nil end }
	local zone = { Treadmill = belt, AuthoredContainer = belt, TreadmillName = "Basic",
		BaseGain = 5, BurstCount = 3, CFrame = rb.CFrame.identity, Size = rb.Vector3.new(8, 6, 12) }
	local poll
	local env = {
		Players = { GetPlayerFromCharacter = function(_, c) return c == character and player or nil end,
			GetPlayers = function() return { player } end },
		Config = { TrainingTickSeconds = 0.5, TreadmillTrainingTickSeconds = 0.5 },
		os = { clock = function() return now end },
		playerMeetsRequirement = function() return allowed end,
		notifyLockedPlayer = function() notices += 1 end,
		ejectLockedPlayer = function() end,
		findPlayersInZone = function() return { [player] = true } end,
		zones = { zone },
		task = { wait = function() coroutine.yield() end,
			spawn = function(fn) poll = coroutine.create(fn); assert(coroutine.resume(poll)) end },
		_G = { SpeedsterAddSpeed = function(_, amount, payload)
			calls += 1
			if reenter then local fn = reenter; reenter = nil; fn() end
			if not ready then return false end
			assert(payload.BurstCount == 3 and payload.TreadmillName == "Basic")
			credited += amount * 2
			return true
		end, SpeedsterGetTotalGainMultiplier = function() return 2 end },
	}
	local grantStart = source:find("\nlocal function addSpeed(", 1, true) and "local function addSpeed(" or "addSpeed = function("
	local chunk = between(source, "local partToZone = {}", "local function hookTreadmillPart")
		.. between(source, "local function isAdminTreadmill", grantStart)
		.. between(source, grantStart, "\ntask.wait(1)")
		.. between(source, "task.spawn(function()\n\tlocal loopInterval", "\nMarketplaceService.PromptGamePassPurchaseFinished")
		.. "\nreturn {touch = onTreadmillPartTouched, zones = partToZone, last = lastSpeedGrantAt}"
	local api = luau.load(chunk, { environment = env })()
	api.zones[belt] = zone
	return {
		touch = function(t) now = t; api.touch(belt, { Parent = character }) end,
		tick = function(t) now = t; local ok, err = coroutine.resume(poll); assert(ok, err) end,
		state = function() return credited, calls, notices, api.last[player] end,
		ready = function(v) ready = v end, allowed = function(v) allowed = v end,
		reenter = function(fn) reenter = fn end,
		root = root, humanoid = humanoid,
	}
end

local old = fs.readFile("audit/treadmill_regression/World1/TreadmillTraining.luau"):gsub("\r\n", "\n")
local broken = treadmillHarness(old)
local ok, err = pcall(broken.touch, 1)
assert(not ok and tostring(err):find("nil value"), "baseline must reproduce out-of-scope addSpeed")
assert(broken.state() == 0, "broken touch unexpectedly credited speed")
local _, _, _, last = broken.state()
assert(last == 1, "baseline must consume cooldown without granting")
print("PASS reproduced saved-place bug: nil addSpeed and consumed cooldown")

local source = fs.readFile("src/common/ServerScriptService/Progression/TreadmillTraining.server.luau"):gsub("\r\n", "\n")
luau.compile(source)
local h = treadmillHarness(source)
h.touch(0)
assert(h.state() == 10, "entry must grant immediately, including early server uptime")
for i = 1, 20 do
	h.touch(i * 0.25)
	h.tick(i * 0.25)
end
assert(h.state() == 110, "touch spam and polling must grant only every 0.5 seconds")
h.tick(5.5)
assert(h.state() == 120, "stationary player must keep farming without touch events")

local failure = treadmillHarness(source)
failure.ready(false)
failure.touch(0)
failure.ready(true)
failure.tick(0.1)
assert(failure.state() == 10, "unloaded profile must not consume cooldown")
failure.reenter(function() failure.touch(0.6) end)
failure.tick(0.6)
assert(failure.state() == 20, "reentrant touch must not double-grant")

local locked = treadmillHarness(source)
locked.allowed(false)
locked.touch(1)
locked.tick(1)
assert(locked.state() == 0, "locked treadmill must not grant speed")
locked.allowed(true)
locked.humanoid.Health = 0
locked.touch(2)
assert(locked.state() == 0, "dead character must not claim by touch")
locked.humanoid.Health = 100
locked.root.Position = rb.Vector3.new(20, 0, 0)
locked.touch(3)
assert(locked.state() == 0, "touch from outside the belt must not grant")
print("PASS immediate entry, stationary farming, 0.5s cadence, failed-profile retry, reentrancy, locks, death, footprint")

local client = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/Movement/SpeedsterClient.client.luau"):gsub("\r\n", "\n")
luau.compile(client)
local requests, mobile = {}, false
local show = luau.load(
	between(client, "local function getWorld1PopupTimingScale", "local function makeOneWorld1BarPopup")
	.. between(client, "local function showSpeedGainBurst", "\nSpeedGainPopup.OnClientEvent")
	.. "\nreturn showSpeedGainBurst",
	{ environment = { Config = {}, Color3 = rb.Color3, POPUP_SPAWN_SOUND_PLAYBACK_SPEED = 1,
		isCompactMobileViewport = function() return mobile end,
		enqueueWorld1Popup = function(request) table.insert(requests, request) end } }
)()
for _, count in { 1, 3, 5, 6, 10, 18, 24, 28 } do
	table.clear(requests)
	show({ Amount = 100, BurstCount = count, TotalSpeed = 1000 })
	assert(#requests == count, "desktop burst lost for tier " .. count)
	assert(requests[1].Amount == 100 and requests[1].TotalSpeed == 1000)
	assert(requests[1].SpawnGap > 0, "bursts must remain staggered")
end
mobile = true
table.clear(requests)
show({ Amount = 100, BurstCount = 18 })
assert(#requests == 8, "mobile must use OG's 8-popup budget")
print("PASS desktop tier bursts 1–28, original mobile budget 8, actual gain payload and staggered timing")
