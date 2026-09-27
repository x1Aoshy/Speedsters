-- ReplicatedStorage/Shared/RaceNoFlight.luau
-- 2026-09-26 (owner): nobody flies in the race. Tester report 2026-09-26: "you shouldn't be able
-- to fly in race world - you can as of right now". The server refused a Flight start while
-- RaceActive but never told the client, whose own LinearVelocity kept it in the air, and nothing
-- checked the arena itself. This is the one rule every side reads:
--   Check(player, position)    the server's truth (FlightService, Superman / board looks): the
--                              player is in a race (RaceActive: waiting in the arena's staging
--                              box, staged, racing, on the results; or RaceState Staged/Racing)
--                              or the position is inside the arena's volume (Zone), whoever they
--                              are and however they got there.
--   Blocked(player, position)  the clients' test: Check, or the server's own verdict (the player
--                              attribute RaceFlightBlocked that FlightService keeps).
--   AirStuds / MaxAirSeconds   the race validator's flight rule (Services/Race/RaceService).
--   Message(lang), Notify()    "Flying is off in races" (Movement/RaceNoFlightNotice shows it).
-- 2026-09-26 (owner): no Flight during the "Super Sonic vs Eggman" event either ("it ruins the
-- experience"). A live event's server sets the player attribute EventAttribute (EventFlightBlocked =
-- the event's name) on every player in its area for the whole event and clears it after:
--   FlightCheck(player, position)  FlightService's verdict: Check, or the event attribute ("Event").
--   Blocked(player, position)      the clients' test now honours the event attribute too.
--   Reason(player, position)       "Event" | "Race" | "Arena" | nil: which line the notice shows.
--   Message(lang, reason)          "Flying is off during the event" when reason is "Event".
-- Check stays the race's own rule (the event itself asks it who is racing).
-- Pure: nothing is touched when it is required (the Lune tests require it directly).
local U4 = if typeof(script) == "Instance"
	then require((script :: any).Parent:WaitForChild("Update4Config", 10))
	else require("./Update4Config")

local RaceNoFlight = {}

-- The player attribute FlightService writes (true while FlightCheck holds; replicated to everyone).
RaceNoFlight.Attribute = "RaceFlightBlocked"
-- 2026-09-26 (owner): why (FlightService writes it with Attribute): "Race" | "Arena" | "Event" | nil.
RaceNoFlight.ReasonAttribute = "RaceFlightBlockedReason"
-- 2026-09-26 (owner): set by a live event's server (a non-empty string: the event's name, or true) on the
-- players in its area while it runs; nil otherwise. The Super Sonic vs Eggman event writes "SuperSonicEvent".
RaceNoFlight.EventAttribute = "EventFlightBlocked"
RaceNoFlight.Reasons = { Race = "Race", Arena = "Arena", Event = "Event" }

-- The arena's volume, in track-local studs around U4.Race.Arena.Origin (s = distance down the
-- track toward -Z, x across, y over Origin.Y): the water around the arena (U4.Race.Water, which
-- already holds the whole Green Hill kit: terraces and mesas reach x -484..462, s -493..2763)
-- plus Margin, from under the seabed to well above anything a jump reaches. The arena sits
-- thousands of studs from every lobby and stage of the three places, so the box holds nothing
-- else.
local WATER = U4.Race.Water
local MARGIN = 60
RaceNoFlight.Zone = {
	HalfX = WATER.HalfX + MARGIN,
	SMin = WATER.SMin - MARGIN,
	SMax = WATER.SMax + MARGIN,
	YMin = -300,
	YMax = 1500,
}

-- The race validator's flight rule (RaceService Validator.Step): a racer's root more than
-- AirStuds over its standing height is airborne, and airborne for more than MaxAirSeconds of
-- moving samples (a sample frozen by a lag spike does not count) is flying. An honest jump
-- (JumpHeight 7.2) is over AirStuds for ~0.45 s, and a hill's drop at the speed cap stretches a
-- jump to ~1.1 s at most (U4.Race.Ground.MaxHeight 60): the margin covers 0.3 s of jitter too.
RaceNoFlight.AirStuds = 2.5
RaceNoFlight.MaxAirSeconds = 2

local RACE_STATES = { Staged = true, Racing = true }

-- Read every frame by the Flight client and for every Superman on screen: no closure per call.
local function attribute(player: any, name: string): any
	if player == nil then
		return nil
	end
	local ok, value = pcall(player.GetAttribute, player, name)
	return if ok then value else nil
end

local function finite(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

-- Whether a world position is inside the arena's volume.
function RaceNoFlight.InArena(position: any): boolean
	if typeof(position) ~= "Vector3" then
		return false
	end
	local origin = U4.Race.Arena.Origin
	local s, x, y = origin.Z - position.Z, position.X - origin.X, position.Y - origin.Y
	if not (finite(s) and finite(x) and finite(y)) then
		return false
	end
	local zone = RaceNoFlight.Zone
	return math.abs(x) <= zone.HalfX and s >= zone.SMin and s <= zone.SMax and y >= zone.YMin and y <= zone.YMax
end

-- The server's rule. Returns blocked, and why ("Race" | "Arena").
function RaceNoFlight.Check(player: any, position: any): (boolean, string?)
	if attribute(player, "RaceActive") == true or RACE_STATES[attribute(player, "RaceState")] == true then
		return true, "Race"
	end
	if RaceNoFlight.InArena(position) then
		return true, "Arena"
	end
	return false, nil
end

-- 2026-09-26 (owner): whether a live event has the player grounded (EventAttribute set).
function RaceNoFlight.EventBlocked(player: any): boolean
	local value = attribute(player, RaceNoFlight.EventAttribute)
	return value == true or (type(value) == "string" and value ~= "")
end

-- FlightService's verdict: the race rule, or a live event (reason "Event"). Returns blocked, why.
-- 2026-09-26 (owner): the Super Sonic vs Eggman event now fights in the race arena: there the event's reason
-- wins over "Arena" (the event's line, not the race's); a player in a race keeps "Race".
function RaceNoFlight.FlightCheck(player: any, position: any): (boolean, string?)
	local blocked, why = RaceNoFlight.Check(player, position)
	if blocked and why == RaceNoFlight.Reasons.Race then
		return true, why
	end
	if RaceNoFlight.EventBlocked(player) then
		return true, RaceNoFlight.Reasons.Event
	end
	if blocked then
		return true, why
	end
	return false, nil
end

-- The clients' test: the rule itself (no replication delay for the own race state and root),
-- a live event's attribute, or the server's verdict.
function RaceNoFlight.Blocked(player: any, position: any): boolean
	if attribute(player, RaceNoFlight.Attribute) == true then
		return true
	end
	if RaceNoFlight.EventBlocked(player) then
		return true
	end
	return (RaceNoFlight.Check(player, position))
end

-- 2026-09-26 (owner): which line the notice shows: "Event" while a live event grounds the player,
-- else the server's reason, else the race rule's own ("Race" / "Arena"), else nil.
function RaceNoFlight.Reason(player: any, position: any): string?
	if RaceNoFlight.EventBlocked(player) then
		return RaceNoFlight.Reasons.Event
	end
	local blocked, why = RaceNoFlight.Check(player, position)
	if blocked then
		return why
	end
	local told = attribute(player, RaceNoFlight.ReasonAttribute)
	if attribute(player, RaceNoFlight.Attribute) == true and type(told) == "string" and told ~= "" then
		return told
	end
	return nil
end

-- "Flying is off in races" in the 10 languages of Shared/TutorialText (anything else: English).
RaceNoFlight.Messages = {
	en = "Flying is off in races",
	es = "No se puede volar en las carreras",
	pt = "Não dá pra voar nas corridas",
	ru = "В гонках летать нельзя",
	ar = "الطيران ممنوع في السباقات",
	id = "Tidak bisa terbang saat balapan",
	fr = "Pas de vol pendant les courses",
	de = "In Rennen ist Fliegen aus",
	th = "บินไม่ได้ระหว่างการแข่ง",
	tr = "Yarışlarda uçmak kapalı",
}

-- 2026-09-26 (owner): "Flying is off during the event", in the same 10 languages.
RaceNoFlight.EventMessages = {
	en = "Flying is off during the event",
	es = "No se puede volar durante el evento",
	pt = "Não dá pra voar durante o evento",
	ru = "Во время события летать нельзя",
	ar = "الطيران ممنوع أثناء الحدث",
	id = "Tidak bisa terbang selama event",
	fr = "Pas de vol pendant l'événement",
	de = "Während des Events ist Fliegen aus",
	th = "บินไม่ได้ระหว่างอีเวนต์",
	tr = "Etkinlik sırasında uçmak kapalı",
}

-- The line in `lang`; reason "Event" (RaceNoFlight.Reason) gives the event's line.
function RaceNoFlight.Message(lang: string?, reason: string?): string
	local messages = if reason == RaceNoFlight.Reasons.Event then RaceNoFlight.EventMessages else RaceNoFlight.Messages
	local text = messages[lang or "en"]
	return if type(text) == "string" and text ~= "" then text else messages.en
end

-- The notice (client only): a refused flight reports itself here, the notice script shows it.
-- Holding the button, or pressing it again and again, reads as one message.
RaceNoFlight.RepeatSeconds = 2.5
local refused: any = nil
local lastNoticeAt = -math.huge

function RaceNoFlight.Notify(): boolean
	local now = os.clock()
	if now - lastNoticeAt < RaceNoFlight.RepeatSeconds then
		return false
	end
	lastNoticeAt = now
	if refused then
		refused:Fire()
	end
	return true
end

function RaceNoFlight.OnNotice(callback: () -> ()): any
	if not refused then
		refused = Instance.new("BindableEvent")
	end
	return refused.Event:Connect(callback)
end

return RaceNoFlight
