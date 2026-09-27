-- test_u4_race_noflight.luau (2026-09-26, owner: nobody flies in the race)
-- Tester report 2026-09-26: "you shouldn't be able to fly in race world - you can as of right
-- now". FlightService refused a start while RaceActive but never told the client (its own
-- LinearVelocity kept it flying), and nothing covered the arena itself. Checked here:
--   1. Shared/RaceNoFlight: the arena volume (every slot, the track, the Green Hill kit's reach,
--      high above; never a lobby or gate of the three worlds), the race states, the server's
--      verdict for the clients, "Flying is off in races" in en/es/pt (+7), the notice throttle;
--   2. the real Core/Abilities/FlightService in a fake Roblox: flight works in the lobby, an
--      active flight is ended when the player is staged (and the client told), a request is
--      refused while staged, racing, on the results in the arena and walked into the arena
--      outside a race (the client told each time), and Flight works again back in the lobby;
--   3. the race validator (Services/Race/RaceService): honest jumps and a lag spike mid-jump
--      are fine, a hover past RaceNoFlight.MaxAirSeconds is pulled back onto the ground with a
--      strike (3 hovers = 3 strikes = a DQ in RaceService), and the spike row it crosses then
--      counts it as on the ground;
--   4. the clients: the three world Flight clients refuse and end flight there (hold-to-fly on
--      Space / A / RB / the touch Jump button), the HUD hint stops offering Fly (run for real:
--      keyboard, touch, gamepad), the Superman low-flight pose stands aside there (run for
--      real), the Silver Surfer's hover drops in a race, the notice shows over the race HUD.
-- Run: lune run audit/test_u4_race_noflight.luau   (from the project root)
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local Vector3 = roblox.Vector3

local U4 = require("../src/common/ReplicatedStorage/Shared/Update4Config")
local RaceTrack = require("../src/common/ReplicatedStorage/Shared/RaceTrack")
local RaceMath = require("../src/common/ReplicatedStorage/Shared/RaceMath")
local RaceNoFlight = require("../src/common/ReplicatedStorage/Shared/RaceNoFlight")
local TutorialText = require("../src/common/ReplicatedStorage/Shared/TutorialText")
local FlightStamina = require("../src/common/ReplicatedStorage/Shared/FlightStamina")
local RaceService = require("../src/common/ServerScriptService/Services/Race/RaceService")

local passed = 0
local function pass(text)
	passed += 1
	print("PASS " .. text)
end

local function read(path)
	return (string.gsub(fs.readFile(path), "\r\n", "\n"))
end

-- The body of `local function name(` up to the first line that is exactly "end" at its indent.
local function functionBody(text, name)
	local start = string.find(text, "local function " .. name .. "%(")
	assert(start, "function " .. name .. " not found")
	local indent = string.match(string.sub(text, 1, start), "\n([\t ]*)$") or ""
	local finish = string.find(text, "\n" .. indent .. "end\n", start, true)
	assert(finish, "end of " .. name .. " not found")
	return string.sub(text, start, finish + #indent + 4)
end

local function has(text, needle, message)
	assert(string.find(text, needle, 1, true), message .. " (" .. needle .. ")")
end

local ORIGIN = U4.Race.Arena.Origin
local W1_LOBBY = Vector3.new(300, 37470.69, -1700)

----------------------------------------------------------------------
-- 1. Shared/RaceNoFlight
----------------------------------------------------------------------
do
	-- The arena's volume: every slot, the waiting box, the track, the end wall, the Green Hill
	-- kit's reach (x -484..462, s -493..2763), over the water, high above the track.
	for slot = 1, RaceTrack.SlotCount do
		assert(RaceNoFlight.InArena(RaceTrack.SlotPosition(slot)), "slot " .. slot .. " is in the arena")
	end
	assert(RaceNoFlight.InArena(RaceTrack.WaitCFrame(3).Position), "the staging box is in the arena")
	for _, point in {
		{ 0, 0, 3 }, { 1000, 20, 3 }, { 2000, -30, 3 }, { 2100, 0, 3 }, { -493, -484, 10 }, { 2763, 462, 10 },
		{ 1000, 0, 900 }, { 1000, 700, -10 }, { -600, 0, 0 }, { 2900, 0, 0 }, { 1000, 0, -250 },
	} do
		local position = RaceTrack.ToWorld(point[1], point[2], point[3])
		assert(RaceNoFlight.InArena(position), ("s %d x %d y %d is in the arena"):format(point[1], point[2], point[3]))
	end
	-- Never a lobby, a gate or a stage of the three places; nothing just past the zone's edges.
	local zone = RaceNoFlight.Zone
	for _, position in {
		W1_LOBBY, U4.Race.Gate.World1.Position, U4.Race.Gate.World2.Position, U4.Race.Gate.World3.Position,
		Vector3.new(136, 95.61, 392), Vector3.new(0, 0, 0), Vector3.new(6000, 37467, 0), Vector3.new(6000, 100, 0),
		RaceTrack.ToWorld(zone.SMin - 1, 0, 3), RaceTrack.ToWorld(zone.SMax + 1, 0, 3), RaceTrack.ToWorld(1000, zone.HalfX + 1, 3),
		RaceTrack.ToWorld(1000, -zone.HalfX - 1, 3), RaceTrack.ToWorld(1000, 0, zone.YMax + 1), RaceTrack.ToWorld(1000, 0, zone.YMin - 1),
	} do
		assert(not RaceNoFlight.InArena(position), tostring(position) .. " is not the arena")
	end
	assert(not RaceNoFlight.InArena(nil) and not RaceNoFlight.InArena({ X = ORIGIN.X, Y = ORIGIN.Y, Z = ORIGIN.Z }),
		"only a Vector3 is a position")
	assert(zone.HalfX >= U4.Race.Water.HalfX and zone.SMin <= U4.Race.Water.SMin and zone.SMax >= U4.Race.Water.SMax,
		"the zone holds the arena's water (and the whole kit inside it)")
	-- The Race Gates stand far from the zone (a player on the lobby pad is never "in the arena").
	for _, world in { "World1", "World2", "World3" } do
		local s, x, y = RaceTrack.ToLocal(U4.Race.Gate[world].Position)
		assert(math.abs(x) > zone.HalfX + 1000 or s < zone.SMin - 1000 or s > zone.SMax + 1000 or y < zone.YMin - 1000 or y > zone.YMax + 1000,
			world .. "'s gate is far outside the zone")
	end
	pass("RaceNoFlight.InArena: slots, staging box, track, kit, water and sky over it; never a lobby, gate or stage")

	local function fakePlayer(attrs)
		return { GetAttribute = function(_, name) return attrs[name] end }
	end
	local lobby = W1_LOBBY
	local track = RaceTrack.ToWorld(800, 0, 3)
	local function check(attrs, position)
		local blocked, why = RaceNoFlight.Check(fakePlayer(attrs), position)
		return blocked, why
	end
	assert(check({}, lobby) == false, "a player in the lobby may fly")
	assert(check({ RaceState = "Queued" }, lobby) == false, "queued from the HUD, still in the lobby: may fly")
	local blocked, why = check({ RaceActive = true }, lobby)
	assert(blocked and why == "Race", "RaceActive (the Race Gate's joiner before the teleport lands): no flight")
	blocked, why = check({ RaceState = "Staged" }, lobby)
	assert(blocked and why == "Race", "staged: no flight")
	blocked, why = check({ RaceState = "Racing" }, track)
	assert(blocked and why == "Race", "racing: no flight")
	blocked, why = check({}, track)
	assert(blocked and why == "Arena", "walked or teleported into the arena outside a race: no flight")
	assert(check({ RaceState = "Finished" }, lobby) == false, "a finished racer sent back to the lobby may fly")
	assert(RaceNoFlight.Check(nil, nil) == false, "nothing known: not blocked")
	-- The clients' test adds the server's verdict (the attribute replicates to everyone).
	assert(RaceNoFlight.Blocked(fakePlayer({ RaceFlightBlocked = true }), lobby) == true, "the server's RaceFlightBlocked blocks the client")
	assert(RaceNoFlight.Blocked(fakePlayer({}), track) == true and RaceNoFlight.Blocked(fakePlayer({}), lobby) == false,
		"the client's own root decides at once")
	assert(RaceNoFlight.Check(fakePlayer({ RaceFlightBlocked = true }), lobby) == false,
		"the server's rule never reads its own verdict back (it could never clear)")
	pass("RaceNoFlight.Check / Blocked: staged, racing, RaceActive and the arena block; the lobby and a HUD queue do not")

	assert(RaceNoFlight.Message("en") == "Flying is off in races", "English")
	assert(RaceNoFlight.Message("es") == "No se puede volar en las carreras", "Spanish")
	assert(RaceNoFlight.Message("pt") == "Não dá pra voar nas corridas", "Portuguese")
	for _, lang in TutorialText.Languages do
		local text = RaceNoFlight.Message(lang)
		assert(type(text) == "string" and text ~= "" and (utf8.len(text) or 99) <= 36, lang .. ": a short line")
		assert(lang == "en" or text ~= RaceNoFlight.Messages.en, lang .. " is translated")
	end
	assert(RaceNoFlight.Message("xx") == RaceNoFlight.Messages.en and RaceNoFlight.Message(nil) == RaceNoFlight.Messages.en, "fallback: English")
	assert(RaceNoFlight.Notify() == true and RaceNoFlight.Notify() == false, "a held button reads as one notice")
	pass("\"Flying is off in races\" in en / es / pt and the other 7 languages; one notice per " .. RaceNoFlight.RepeatSeconds .. " s")

	-- 2026-09-26 (owner): no Flight during the Super Sonic vs Eggman event, with its own line.
	local E = RaceNoFlight.EventAttribute
	assert(E == "EventFlightBlocked" and RaceNoFlight.ReasonAttribute == "RaceFlightBlockedReason", "the event's attribute names")
	local inEvent = fakePlayer({ [E] = "SuperSonicEvent" })
	blocked, why = RaceNoFlight.FlightCheck(inEvent, lobby)
	assert(blocked == true and why == "Event", "FlightCheck: the event grounds the player (reason Event)")
	assert(RaceNoFlight.FlightCheck(fakePlayer({ [E] = true }), lobby) == true, "true works as the flag too")
	assert(RaceNoFlight.FlightCheck(fakePlayer({ [E] = "" }), lobby) == false and RaceNoFlight.FlightCheck(fakePlayer({}), lobby) == false,
		"no event: may fly")
	blocked, why = RaceNoFlight.FlightCheck(fakePlayer({ [E] = "SuperSonicEvent", RaceActive = true }), lobby)
	assert(blocked and why == "Race", "a race's reason comes first")
	assert(RaceNoFlight.Check(inEvent, lobby) == false, "Check stays the race's own rule (the event asks it who is racing)")
	assert(RaceNoFlight.Blocked(inEvent, lobby) == true, "the clients honour the event at once")
	assert(RaceNoFlight.Reason(inEvent, lobby) == "Event" and RaceNoFlight.Reason(fakePlayer({}), track) == "Arena"
		and RaceNoFlight.Reason(fakePlayer({ RaceActive = true }), lobby) == "Race" and RaceNoFlight.Reason(fakePlayer({}), lobby) == nil,
		"Reason: Event / Arena / Race / nil")
	assert(RaceNoFlight.Reason(fakePlayer({ RaceFlightBlocked = true, RaceFlightBlockedReason = "Event" }), lobby) == "Event",
		"the server's told reason")
	assert(RaceNoFlight.Message("en", "Event") == "Flying is off during the event", "English (event)")
	assert(RaceNoFlight.Message("es", "Event") == "No se puede volar durante el evento", "Spanish (event)")
	assert(RaceNoFlight.Message("pt", "Event") == "Não dá pra voar durante o evento", "Portuguese (event)")
	assert(RaceNoFlight.Message("en", "Race") == RaceNoFlight.Messages.en and RaceNoFlight.Message("xx", "Event") == RaceNoFlight.EventMessages.en,
		"the race line for Race / Arena; English fallback")
	for _, lang in TutorialText.Languages do
		local text = RaceNoFlight.Message(lang, "Event")
		assert(type(text) == "string" and text ~= "" and (utf8.len(text) or 99) <= 40, lang .. ": a short event line")
		assert(lang == "en" or text ~= RaceNoFlight.EventMessages.en, lang .. " is translated (event)")
		assert(text ~= RaceNoFlight.Message(lang), lang .. ": the event's line is its own")
	end
	pass("RaceNoFlight + the event: FlightCheck / Blocked / Reason honour EventFlightBlocked (\"Event\"), Check stays the race's; \"Flying is off during the event\" in the 10 languages")
end

----------------------------------------------------------------------
-- 2. FlightService (the real source) in a fake Roblox
----------------------------------------------------------------------
local function Signal()
	local signal = { entries = {} }
	function signal:Connect(fn)
		local entry = { fn = fn, alive = true }
		table.insert(self.entries, entry)
		return {
			Disconnect = function()
				entry.alive = false
			end,
		}
	end
	function signal:Fire(...)
		for _, entry in table.clone(self.entries) do
			if entry.alive then
				entry.fn(...)
			end
		end
	end
	return signal
end

local function withAttributes(object)
	local attrs, signals = {}, {}
	function object:GetAttribute(name)
		return attrs[name]
	end
	function object:SetAttribute(name, value)
		local old = attrs[name]
		attrs[name] = value
		if old ~= value and signals[name] then
			signals[name]:Fire()
		end
	end
	function object:GetAttributeChangedSignal(name)
		signals[name] = signals[name] or Signal()
		return signals[name]
	end
	return object
end

local function folder(children)
	return {
		FindFirstChild = function(_, name)
			return children[name]
		end,
	}
end

local function boolValue(value)
	return { Value = value, IsA = function(_, class) return class == "BoolValue" end }
end

do
	local PlayersService = { list = {}, PlayerAdded = Signal(), PlayerRemoving = Signal() }
	function PlayersService:GetPlayers()
		return table.clone(self.list)
	end
	local fired = {}
	local function remote(name)
		return {
			Name = name,
			OnServerEvent = Signal(),
			IsA = function(_, class) return class == "RemoteEvent" end,
			FireClient = function(_, player, ...)
				table.insert(fired, { remote = name, player = player, args = table.pack(...) })
			end,
		}
	end
	local remotes = {
		AbilityShopAction = remote("AbilityShopAction"),
		AbilityShopUpdate = remote("AbilityShopUpdate"),
		FlightAbilityState = remote("FlightAbilityState"),
	}
	local remotesFolder = folder(remotes)
	local config = { AbilityFlightEnabled = true, BoostStaminaDisplayBase = 17 }
	local modules = {
		Config = config,
		FlightStamina = FlightStamina,
		WinsMath = { GetProgressionPrice = function(cost) return cost end, GetProgressionPriceFor = function(cost) return cost end },
		RaceNoFlight = RaceNoFlight,
	}
	local shared = {
		WaitForChild = function(_, name)
			return assert(modules[name], "FlightService asked for Shared." .. tostring(name))
		end,
	}
	local ReplicatedStorage = {
		FindFirstChild = function(_, name)
			assert(name == "Remotes", name)
			return remotesFolder
		end,
		WaitForChild = function(_, name)
			assert(name == "Shared", name)
			return shared
		end,
	}
	local Workspace = {
		GetDescendants = function() return {} end,
		DescendantAdded = Signal(),
		GetPartsInPart = function() return {} end,
	}
	local services = {
		Players = PlayersService,
		ReplicatedStorage = ReplicatedStorage,
		RunService = { IsStudio = function() return false end },
		MarketplaceService = { PromptGamePassPurchaseFinished = Signal(), UserOwnsGamePassAsync = function() return false end },
		ServerScriptService = { Services = { Data = { DataService = {} }, ServerRateLimiter = { Allow = function() return true end } } },
		Workspace = Workspace,
	}
	local game = {
		GetService = function(_, name)
			return assert(services[name], "service " .. tostring(name))
		end,
	}
	local spawned = {}
	local waitBudget = 0
	local STOP = { "stop" }
	local warnings = {}
	local fakeG = {
		SpeedsterGetBoostStamina = function()
			return 100
		end,
	}
	local env = {
		game = game,
		workspace = Workspace,
		require = function(module)
			return module
		end,
		_G = fakeG,
		task = {
			spawn = function(fn)
				table.insert(spawned, fn)
			end,
			defer = function(fn, ...)
				fn(...)
			end,
			delay = function() end,
			wait = function()
				if waitBudget <= 0 then
					error(STOP)
				end
				waitBudget -= 1
				return 0
			end,
		},
		print = function() end,
		warn = function(...)
			table.insert(warnings, table.concat({ ... }, " "))
		end,
		Vector3 = Vector3,
	}
	local source = fs.readFile("src/common/ServerScriptService/Core/Abilities/FlightService.luau")
	local FlightService = luau.load(source, { debugName = "FlightService", environment = env })()
	FlightService.Start()
	local loops = table.clone(spawned) -- the no-fly poll and the temporary-flight watchdog
	assert(#loops == 2, "FlightService starts its two loops (" .. #loops .. ")")
	local function pollOnce()
		for _, loop in loops do
			waitBudget = 1
			local ok, err = pcall(loop)
			assert(not ok and err == STOP, "a loop ran one round: " .. tostring(err))
		end
	end

	-- One player who owns and equips Flight, standing in World 1's lobby.
	local root = { Position = W1_LOBBY, IsA = function(_, class) return class == "BasePart" end, FindFirstChild = function() return nil end }
	local humanoid = { Health = 100, PlatformStand = false }
	local character = withAttributes({ Parent = Workspace })
	function character:FindFirstChild(name)
		return if name == "HumanoidRootPart" then root else nil
	end
	function character:FindFirstChildOfClass(class)
		return if class == "Humanoid" then humanoid else nil
	end
	function character:GetDescendants()
		return {}
	end
	local owned = folder({ Flight = boolValue(true), __AbilityEquipped_Flight = boolValue(true), __AbilityEquipStateInitialized = boolValue(true) })
	local data = folder({ OwnedUpgrades = owned })
	local leaderstats = folder({ Wins = { Value = 0, IsA = function(_, class) return class == "IntValue" end } })
	local player = withAttributes({ Name = "Flyer", UserId = 7, Parent = PlayersService, Character = character, CharacterAdded = Signal() })
	function player:FindFirstChild(name)
		return if name == "SpeedsterData" then data elseif name == "leaderstats" then leaderstats else nil
	end
	player:SetAttribute("DataLoaded", true)
	player:SetAttribute("TrueBoostStaminaMax", 100)
	player:SetAttribute("LastBarrierTouchTime", -1e6)
	table.insert(PlayersService.list, player)
	PlayersService.PlayerAdded:Fire(player)

	local FlightAbilityState = remotes.FlightAbilityState
	local function request(active, powered)
		FlightAbilityState.OnServerEvent:Fire(player, active, powered)
	end
	local function raceTold()
		local count = 0
		for _, event in fired do
			if event.remote == "FlightAbilityState" and event.player == player and event.args[1] == false and event.args[2] == false
				and event.args[3] == "Race" then
				count += 1
			end
		end
		return count
	end
	local function flying()
		return player:GetAttribute("FlightAbilityActive") == true
	end

	assert(type(fakeG.SpeedsterRefreshRaceNoFlight) == "function", "_G.SpeedsterRefreshRaceNoFlight")
	assert(player:GetAttribute(RaceNoFlight.Attribute) == false, "in the lobby: RaceFlightBlocked false")
	request(true, true)
	assert(flying() and player:GetAttribute("FlightAbilityPowered") == true and raceTold() == 0, "Flight works in the lobby")
	pass("FlightService: Flight works in the lobby (RaceFlightBlocked false)")

	-- Staging (RaceService sets RaceActive, then RaceState Staged, then the teleport lands).
	player:SetAttribute("RaceActive", true)
	assert(not flying() and player:GetAttribute("FlightAbilityPowered") == false, "staging ends the active flight on the server")
	assert(raceTold() == 1, "and tells the client (it flies on its own constraints)")
	assert(player:GetAttribute(RaceNoFlight.Attribute) == true, "RaceFlightBlocked true while staged")
	player:SetAttribute("RaceState", "Staged")
	root.Position = RaceTrack.SlotPosition(3)
	pass("FlightService: an active flight is turned off the moment the player is staged, and the client is told")

	request(true, true)
	assert(not flying() and raceTold() == 2, "a start while staged is refused and the client told")
	request(true, false)
	assert(not flying() and raceTold() == 3, "a glide while staged is refused too")
	player:SetAttribute("RaceState", "Racing")
	root.Position = RaceTrack.ToWorld(800, 4.5, RaceTrack.RootHeight + 6)
	request(true, true)
	assert(not flying() and raceTold() == 4, "a start while racing is refused")
	local before = raceTold()
	request(false, false)
	assert(raceTold() == before, "a stop is never answered with a refusal")
	pass("FlightService: requests refused while staged and racing (the client is told each time)")

	-- The results: RaceActive / RaceState cleared while still in the arena, then the trip home.
	player:SetAttribute("RaceActive", false)
	player:SetAttribute("RaceState", "")
	pollOnce()
	assert(player:GetAttribute(RaceNoFlight.Attribute) == true, "still in the arena: RaceFlightBlocked stays true")
	request(true, true)
	assert(not flying() and raceTold() == before + 1, "still in the arena after the race: refused")
	root.Position = W1_LOBBY
	pollOnce()
	assert(player:GetAttribute(RaceNoFlight.Attribute) == false, "back in the lobby: RaceFlightBlocked false")
	request(true, true)
	assert(flying() and raceTold() == before + 1, "back in the lobby: Flight works again")
	pass("FlightService: refused in the arena after the race, back in the lobby Flight works as before")

	-- Outside any race: flying (or walking) into the arena's volume lands the player.
	root.Position = RaceTrack.ToWorld(1500, -200, 120)
	pollOnce()
	assert(not flying() and raceTold() == before + 2, "flying into the arena ends the flight (poll)")
	assert(player:GetAttribute(RaceNoFlight.Attribute) == true, "RaceFlightBlocked true in the arena")
	request(true, true)
	assert(not flying() and raceTold() == before + 3, "a start inside the arena is refused")
	root.Position = W1_LOBBY
	assert(fakeG.SpeedsterRefreshRaceNoFlight(player) == false and player:GetAttribute(RaceNoFlight.Attribute) == false,
		"the refresh hook clears it at once")
	request(true, true)
	assert(flying(), "and Flight works again")
	-- A Race Gate joiner: RaceActive before the teleport, still standing in the lobby.
	player:SetAttribute("RaceActive", true)
	assert(not flying() and player:GetAttribute(RaceNoFlight.Attribute) == true, "the Race Gate lands the flyer before the teleport")
	player:SetAttribute("RaceActive", false)
	assert(player:GetAttribute(RaceNoFlight.Attribute) == false, "left the queue in the lobby: RaceFlightBlocked false")
	assert(#warnings == 0, "no warnings: " .. table.concat(warnings, " | "))
	pass("FlightService: the arena's volume is a no-fly zone outside races too (poll 4 Hz), the Gate lands a flyer")

	-- 2026-09-26 (owner): a live event (the Super Sonic event) grounds the players in its area, then lets go.
	request(true, true)
	assert(flying(), "flying in the lobby before the event")
	local toldBefore = raceTold()
	player:SetAttribute(RaceNoFlight.EventAttribute, "SuperSonicEvent")
	assert(not flying() and raceTold() == toldBefore + 1, "the event lands the flyer at once (attribute signal) and tells the client")
	assert(player:GetAttribute(RaceNoFlight.Attribute) == true and player:GetAttribute(RaceNoFlight.ReasonAttribute) == "Event",
		"RaceFlightBlocked true, reason Event (the notice shows the event's line)")
	request(true, true)
	assert(not flying() and raceTold() == toldBefore + 2, "a start during the event is refused and told")
	pollOnce()
	assert(player:GetAttribute(RaceNoFlight.Attribute) == true, "the poll keeps it")
	player:SetAttribute(RaceNoFlight.EventAttribute, nil)
	assert(player:GetAttribute(RaceNoFlight.Attribute) == false and player:GetAttribute(RaceNoFlight.ReasonAttribute) == nil,
		"the event over: RaceFlightBlocked false, no reason")
	request(true, true)
	assert(flying(), "Flight works again after the event")
	player:SetAttribute("RaceActive", true)
	assert(player:GetAttribute(RaceNoFlight.ReasonAttribute) == "Race", "a race's reason")
	player:SetAttribute("RaceActive", false)
	assert(#warnings == 0, "no warnings: " .. table.concat(warnings, " | "))
	pass("FlightService: EventFlightBlocked lands and refuses the flyer at once (reason Event), cleared = Flight back")
end

----------------------------------------------------------------------
-- 3. The race validator's flight rule
----------------------------------------------------------------------
do
	RaceTrack.SetProfile(RaceTrack.FlatProfile())
	local Validator = RaceService.Validator
	local PARAMS = RaceMath.Params(0, nil, 1) -- cruise 100
	local DT = 0.05
	local GROUND = RaceTrack.RootHeight
	local OFF_LANES = 40 -- beside the lanes, inside the corridor: no spike tile reaches it

	local function newRun(s0, x)
		local goAt = 5000
		return {
			v = Validator.New(PARAMS, goAt, s0, x, "Perfect", {}, 0, 0),
			client = RaceMath.NewState(PARAMS, "Perfect", nil, goAt, s0),
			x = x, t = goAt, seen = s0, seenY = GROUND, corrections = 0, flights = 0, spikes = 0,
		}
	end
	-- One 20 Hz sample: the client runs the same model the server keeps (an honest pace); the
	-- server sees it at height y (frozen: a lag spike, the previous position).
	local function sample(run, y, frozen)
		run.t += DT
		RaceMath.Step(run.client, { forward = 1, sprint = false, grounded = true }, DT, PARAMS, run.t)
		if not frozen then
			run.seen, run.seenY = run.client.s, y
		end
		local result = Validator.Step(run.v, run.t, run.seen, run.x, run.seenY)
		if result.spike then
			run.spikes += 1
		end
		if result.correction then
			run.corrections += 1
			if result.flying then
				run.flights += 1
			end
			-- RaceService pivots the racer onto the ground at the corrected s; the client takes s, v.
			run.client.s, run.client.v = result.correction.s, result.correction.v
			run.seen, run.seenY = result.correction.s, GROUND
		end
		return result
	end

	-- Honest jumps (JumpHeight 7.2: ~0.5 s off the ground), one a second for 3 s.
	local run = newRun(400, OFF_LANES)
	for step = 1, 60 do
		local phase = (step * DT) % 1
		local y = if phase >= 0.2 and phase < 0.7 then GROUND + 7 * math.sin(math.pi * (phase - 0.2) / 0.5) else GROUND
		sample(run, y)
		assert(run.v.airSeconds <= 0.6, "an honest jump is short")
	end
	assert(run.corrections == 0 and run.v.strikes == 0, "honest jumps: no correction")
	pass("validator: honest jumps (0.5 s in the air) are never flight")

	-- A lag spike mid-jump: the server sees the racer frozen in the air for 2.5 s.
	run = newRun(400, OFF_LANES)
	for _ = 1, 4 do
		sample(run, GROUND)
	end
	for step = 1, 5 do
		sample(run, GROUND + 7 * math.sin(math.pi * step * DT / 0.5))
	end
	for _ = 1, 50 do
		sample(run, 0, true)
	end
	for _ = 1, 10 do
		sample(run, GROUND)
	end
	assert(run.flights == 0 and run.v.strikes == 0, "a frozen sample in the air is no flight")
	pass("validator: a 2.5 s lag spike in the middle of a jump is not flight (frozen samples do not add up)")

	-- A shorter hover (1.5 s), then down: under the limit, like a long jump.
	run = newRun(400, OFF_LANES)
	for _ = 1, 30 do
		sample(run, GROUND + 6)
	end
	for _ = 1, 10 do
		sample(run, GROUND)
	end
	assert(run.corrections == 0 and run.v.airSeconds == 0, "1.5 s off the ground and back: fine")
	pass("validator: 1.5 s in the air then down is not flight")

	-- A hover (6 studs up, Flight or an exploit): pulled down at MaxAirSeconds with a strike.
	run = newRun(400, OFF_LANES)
	local flaggedAt = nil
	for step = 1, 60 do
		local result = sample(run, GROUND + 6)
		if result.correction and not flaggedAt then
			flaggedAt = step * DT
			assert(result.flying == true, "the correction is the flight rule's")
			assert(result.correction.s <= run.v.model.s + 1e-6, "a flyer never keeps a stud past the model")
		end
		if flaggedAt then
			break
		end
	end
	assert(flaggedAt and flaggedAt >= RaceNoFlight.MaxAirSeconds - 1e-6 and flaggedAt <= RaceNoFlight.MaxAirSeconds + 2 * DT,
		"flagged right after MaxAirSeconds (" .. tostring(flaggedAt) .. " s)")
	assert(run.v.strikes == 1 and run.v.airSeconds == 0, "one strike, air time reset")
	for _ = 1, 30 do
		sample(run, GROUND)
	end
	assert(run.corrections == 1, "back on the ground: no more corrections")
	-- Three flights are three strikes: RaceService disqualifies at VALIDATION.MaxStrikes.
	for _ = 1, 2 do
		for _ = 1, 50 do
			sample(run, GROUND + 6)
		end
		for _ = 1, 20 do
			sample(run, GROUND)
		end
	end
	assert(run.flights == 3 and run.v.strikes >= U4.Race.Validation.MaxStrikes, "three flights: " .. run.v.strikes .. " strikes = DQ")
	pass(("validator: a hover is pulled back onto the ground at %.2f s with a strike; 3 flights = DQ"):format(flaggedAt))

	-- The spike row a flyer crosses when the rule catches it counts it as on the ground (row
	-- s 750 blocks lane 1). The same crossing 0.15 s into a hover (a jump) clears it.
	local LANE1 = RaceTrack.LaneX(1)
	local function crossRow(airBefore)
		local r = newRun(735, LANE1)
		for _ = 1, 20 do
			local ahead = table.clone(r.client)
			RaceMath.Step(ahead, { forward = 1, sprint = false, grounded = true }, DT, PARAMS, r.t + DT)
			if ahead.s >= 747 then
				if airBefore then
					r.v.airSeconds = airBefore
				end
				return sample(r, GROUND + 6), r
			end
			sample(r, GROUND + 6)
		end
		error("never reached the row")
	end
	local caught = crossRow(RaceNoFlight.MaxAirSeconds)
	assert(caught.flying and caught.spike and caught.spike.s == 750 and caught.spike.lane == 1, "the flyer trips on the row")
	local jumped, r2 = crossRow(nil)
	assert(not jumped.flying and not jumped.spike and r2.v.strikes == 0, "a jump over the row clears it")
	pass("validator: the spike row crossed when the flight rule catches a flyer counts them as on the ground")

	-- RaceService lands the flagged racer on the ground (the correction's pivot).
	local service = read("src/common/ServerScriptService/Services/Race/RaceService.luau")
	has(service, "self:_arenaPivot(racer.entry, RaceTrack.GroundCFrame(c.s, x))", "a correction is a pivot onto the ground")
	has(service, "local violation = not inGrace and (s > Validator.Allowed(v) or s > windowAllowed or flying)", "flight is a violation")
	pass("RaceService: a flight correction pivots the racer onto the ground (and strikes count to the DQ)")
end

----------------------------------------------------------------------
-- 4. The clients
----------------------------------------------------------------------
do
	-- The three world Flight clients (identical): refuse and end flight in the race / arena.
	local worlds = {}
	for _, world in { "World1", "World2", "World3" } do
		worlds[world] = read(("src/worlds/%s/StarterPlayer/StarterPlayerScripts/Movement/%sFlightAbility.client.luau"):format(world, world))
	end
	assert(worlds.World1 == worlds.World2 and worlds.World1 == worlds.World3, "the three Flight clients are identical")
	local client = worlds.World1
	has(client, 'local RaceNoFlight = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RaceNoFlight"))', "requires the rule")
	has(functionBody(client, "raceBlocked"), "RaceNoFlight.Blocked(player, if root and root.Parent then root.Position else nil)", "the own root decides")
	has(functionBody(client, "startFlight"), "if raceBlocked() then\n\t\tRaceNoFlight.Notify()\n\t\treturn", "startFlight refuses")
	local hold = functionBody(client, "beginFlightHold")
	local blockedAt = string.find(hold, "if raceBlocked() then", 1, true)
	assert(blockedAt and blockedAt < string.find(hold, "if not canPower() then", 1, true), "the hold stops before anything can lift off")
	has(hold, "and flightEquipped() and raceBlocked() and not isDeadOrRagdolled() then\n\t\t\t\tRaceNoFlight.Notify()", "a held press says why")
	local step = functionBody(client, "stepFlight")
	has(step, "and not raceBlocked()\n\tthen\n\t\tstartFlight()", "the held jump in the air never lifts off")
	has(step, "if raceBlocked() then\n\t\tstopFlight(false)\n\t\tRaceNoFlight.Notify()\n\t\treturn", "a flight under way lands")
	has(client, 'if reason == "Race" then\n\t\tRaceNoFlight.Notify()', "the server's refusal is shown")
	for _, name in { '"RaceActive"', '"RaceState"', "RaceNoFlight.Attribute" } do
		has(client, "player:GetAttributeChangedSignal(" .. name .. "):Connect(onRaceNoFlightChanged)", "lands at once on " .. name)
	end
	pass("World1/2/3 Flight clients: hold-to-fly (Space, A, RB, touch Jump) refused and a flight landed in the race / arena")

	-- The HUD hint, run for real: the Fly line (keyboard, gamepad, and the touch "Hold Jump to Fly")
	-- goes away while RaceNoFlight / RaceActive, and comes back after the race.
	local hud = read("src/common/StarterPlayer/StarterPlayerScripts/UI/MainHUDController.client.luau")
	has(hud, 'player:GetAttributeChangedSignal("RaceFlightBlocked"):Connect(updateSprintHint)', "the hint follows RaceFlightBlocked")
	has(hud, 'player:GetAttributeChangedSignal("RaceActive"):Connect(updateSprintHint)', "the hint follows RaceActive")
	local chunk = functionBody(hud, "updateSprintHint")
	local label = { Visible = true, Text = "", IsA = function(_, class) return class == "TextLabel" end }
	local attrs = {}
	local input = { last = "Keyboard", touch = false, keyboard = true, gamepad = false }
	local env = {
		shiftLabel = label,
		noStaminaShowing = false,
		player = { GetAttribute = function(_, name) return attrs[name] end },
		UserInputService = setmetatable({}, { __index = function(_, key)
			if key == "GetLastInputType" then
				return function() return input.last end
			elseif key == "GetConnectedGamepads" then
				return function() return {} end
			elseif key == "TouchEnabled" then
				return input.touch
			elseif key == "KeyboardEnabled" then
				return input.keyboard
			elseif key == "GamepadEnabled" then
				return input.gamepad
			end
			return nil
		end }),
		GuiService = { IsTenFootInterface = function() return false end },
		Enum = { UserInputType = setmetatable({}, { __index = function(_, key) return key end }) },
	}
	local update = luau.load(chunk .. "\nreturn updateSprintHint", { environment = env })()
	local function hint(attributes, device)
		table.clear(attrs)
		for key, value in attributes do
			attrs[key] = value
		end
		input.last = if device == "touch" then "Touch" elseif device == "gamepad" then "Gamepad1" else "Keyboard"
		input.touch, input.keyboard, input.gamepad = device == "touch", device ~= "touch" and device ~= "gamepad", device == "gamepad"
		label.Visible, label.Text = true, ""
		update()
		return label.Visible, label.Text
	end
	local equipped = { FlightAbilityEquipped = true, EquippedAbility = "Flight" }
	local function with(extra)
		local out = table.clone(equipped)
		for key, value in extra do
			out[key] = value
		end
		return out
	end
	local visible, text = hint(equipped, "keyboard")
	assert(visible and text == "Shift: Sprint | Space: Fly", "lobby keyboard: " .. text)
	visible, text = hint(with({ RaceFlightBlocked = true }), "keyboard")
	assert(visible and text == "Shift to Sprint", "arena keyboard: " .. text)
	visible, text = hint(with({ RaceActive = true, FlightAbilityActive = true }), "keyboard")
	assert(not string.find(text, "Fly", 1, true), "staged: no Fly line (" .. text .. ")")
	visible, text = hint(equipped, "touch")
	assert(visible and text == "Hold Jump to Fly", "lobby touch: " .. text)
	visible = hint(with({ RaceFlightBlocked = true }), "touch")
	assert(visible == false, "arena touch: the Fly hint is hidden")
	visible, text = hint(with({ RaceActive = true }), "gamepad")
	assert(visible and text == "L2 to Sprint", "race gamepad: " .. text)
	visible, text = hint(equipped, "keyboard")
	assert(visible and text == "Shift: Sprint | Space: Fly", "back in the lobby: the Fly hint is back")
	pass("MainHUDController hint (run): no Fly line in the race / arena on keyboard, gamepad and touch; back after the race")

	-- The Superman low-flight pose, run for real: it stands aside in the race and the arena.
	local superman = read("src/common/StarterPlayer/StarterPlayerScripts/Movement/SupermanFlight.client.luau")
	has(superman, 'local RaceNoFlight = require(Shared:WaitForChild("RaceNoFlight"))', "SupermanFlight requires the rule")
	local aside = luau.load(functionBody(superman, "standsAside") .. "\nreturn standsAside",
		{ environment = { AWAY_STATES = {}, RaceNoFlight = RaceNoFlight } })()
	local playerAttrs = {}
	local flyer = {
		Humanoid = { Health = 100, Sit = false, GetState = function() return "Running" end },
		Player = { GetAttribute = function(_, name) return playerAttrs[name] end },
		Root = { Parent = true, Position = W1_LOBBY },
	}
	local characterFake = { GetAttribute = function() return nil end }
	assert(aside(characterFake, flyer) == false, "Superman flies low in the lobby")
	flyer.Root.Position = RaceTrack.ToWorld(600, 10, RaceTrack.RootHeight)
	assert(aside(characterFake, flyer) == true, "not inside the arena")
	flyer.Root.Position = W1_LOBBY
	playerAttrs.RaceActive = true
	assert(aside(characterFake, flyer) == true, "not in a race")
	playerAttrs.RaceActive = nil
	playerAttrs.RaceFlightBlocked = true
	assert(aside(characterFake, flyer) == true, "not when the server says so (another player's replicated verdict)")
	pass("SupermanFlight (run): the low-flight pose stands aside in a race and anywhere in the arena")

	-- The Silver Surfer's board: no hover in a race (the board is hidden there), back afterwards.
	local skins = read("src/common/ServerScriptService/Economy/SkinSystem.server.luau")
	local attach = functionBody(skins, "attachSurfboard")
	has(attach, "if racing() then\n\t\thumanoid.HipHeight = base\n\telse\n\t\thumanoid.HipHeight = base + SURFBOARD_HOVER", "no lift in a race")
	has(attach, "local target = if racing() then base else base + SURFBOARD_HOVER", "the watcher keeps the right height")
	has(attach, 'surfboardRaceWatchers[character] = player:GetAttributeChangedSignal("RaceActive"):Connect(', "follows RaceActive")
	has(skins, "local raceWatcher = surfboardRaceWatchers[character]", "clearSurfboard lets it go")
	pass("SkinSystem: the Silver Surfer's hover drops while RaceActive and comes back after")

	-- The notice: its own ScreenGui, never hidden by the race HUD's InterfaceHider.
	local notice = read("src/common/StarterPlayer/StarterPlayerScripts/Movement/RaceNoFlightNotice.client.luau")
	has(notice, "InterfaceHider.NeverHide[GUI_NAME] = true", "kept over the race HUD")
	has(notice, "RaceNoFlight.OnNotice(", "listens to the Flight clients")
	has(notice, "label.Text = RaceNoFlight.Message(lang, reason())", "in the player's language, the event's line during an event")
	has(notice, "return RaceNoFlight.Reason(player, if root and root:IsA(\"BasePart\") then root.Position else nil)", "the reason (2026-09-26)")
	has(notice, "local lang = TutorialText.ForPlayer(player)", "the player's language")
	assert(luau.compile(notice) ~= nil, "compiles")
	pass("RaceNoFlightNotice: the localized line shows over the race HUD (InterfaceHider.NeverHide)")
end

print(("ALL %d RACE NO-FLIGHT CHECKS PASSED"):format(passed))
