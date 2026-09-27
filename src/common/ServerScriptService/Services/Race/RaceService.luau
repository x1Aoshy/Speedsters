-- Services/Race/RaceService.luau — Update 4 (2026-09-25): the server-authoritative race cycle.
--   Idle -> Gathering -> Staging -> Countdown -> Running -> Results -> Cooldown -> Gathering|Idle
-- One race at a time per server, on the arena at Update4Config.Race.Arena.Origin (the same in all
-- three worlds). Every timing is U4.Race.Queue; all clocks are the server clock
-- (Workspace:GetServerTimeNow()). The service never yields: Roblox work (teleports, streaming,
-- remotes, DataStores) goes through the injected `host` (built in Gameplay/RaceServer), so
-- audit/test_u4_race_lifecycle and test_u4_race_validation drive it with a fake clock.
--
-- Authority (PLAN §3.3): each racer has a server model (RaceMath.Step with full forward input,
-- the server's pool, the sprint flag from RaceSprint and the judged grade; Perfect until judged).
-- The racer's sampled distance may not exceed s_env*1.06 + 10 + 0.3*v_env, and no 0.5 s window
-- may cover more than Vs*1.288 over (window + 0.3 s latency slack) three windows in a row.
-- A violation pulls the racer back to the model, and three of them disqualify.
-- 2026-09-25: the latency slack on the rate windows is ours: receive times jitter by up to the
-- ping, so a bare 0.5 s window would flag honest sprinters on a bad connection; the distance
-- envelope still catches any speed-up of more than a few percent.
-- 2026-09-25: two more rules of ours. (1) The same envelope over the last WINDOW_SECONDS: the
-- cumulative 6 % grows with the distance, so late in a race a x1.3 speed-up needed 3-4 s to
-- show; over a 2 s window it shows in about 2 s anywhere on the track. The window measures the
-- racer's progress against the model's top speed over each step, integrated (capS). Its latency allowance is WINDOW_LATENCY_SECONDS (0.2 s):
-- simulated honest clients with 0-300 ms of jitter and 5 % loss needed at most 0.14 s
-- (test_u4_race_validation), and a sample the server saw frozen (a lag spike: the same position
-- twice while the model moved) is never used as the window's start, so a stall followed by a
-- burst cannot look like a speed-up. (2) After a correction, positions the client sent before
-- it saw the pivot still arrive for up to two latencies; for CORRECTION_GRACE they are capped at
-- the envelope instead of counted, so one correction can never snowball into a DQ.
-- 2026-09-25 (owner): the speed follows the Speed stat (RaceMath.CruiseSpeed), so the queue is
-- three queues (Beginner / Rank / Open, U4.Race.Matchmaking) sharing the one arena: each cycle
-- races one heat (RaceService.FormHeat, below), the rest keep their place; a racer's
-- implausibility floor is their own (RaceMath.PlausibleMs), and after the first finish the heat
-- waits for its slowest racer at cruise (RaceMath.ExpectedSeconds) up to MaxRaceSeconds.
-- 2026-09-26 (owner): nobody flies in a race: a racer off the ground (RaceNoFlight.AirStuds over
-- the standing height) for more than RaceNoFlight.MaxAirSeconds of moving samples is a violation
-- (the spike rows of that step count them as on the ground; Validator.Step).
-- 2026-09-26 (owner): a live event closes the races (the "Super Sonic vs Eggman" event: "while the event runs
-- nobody can join a race, and players in a race get pulled out to go to the event"). Close(reason) calls off
-- the cycle at once whatever its phase (_abortAll: no DNF, no idle-DNF strike, no rejoin cooldown, nothing paid
-- for the aborted race; racers in the arena go back to the lobby spawn), writes Workspace.RaceClosedBy = reason
-- (the gate board / HUD show "closed during the event") and refuses every Join ("RaceEventClosed") until
-- Reopen(reason). Gameplay/RaceServer exposes both as _G.SpeedsterRace.Close / .Reopen / .IsClosed.
local Vector3, CFrame = Vector3, CFrame
if Vector3 == nil or CFrame == nil then
	local lateRequire: any = require
	local ok, roblox = pcall(lateRequire, "@lune/roblox")
	if ok and type(roblox) == "table" then
		Vector3, CFrame = roblox.Vector3, roblox.CFrame
	end
end

local function shared(name)
	if typeof(script) == "Instance" then
		return require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild(name, 10))
	end
	return nil
end
local U4 = shared("Update4Config") or require("../../../ReplicatedStorage/Shared/Update4Config")
local RaceTrack = shared("RaceTrack") or require("../../../ReplicatedStorage/Shared/RaceTrack")
local RaceMath = shared("RaceMath") or require("../../../ReplicatedStorage/Shared/RaceMath")
local RaceChargeMath = shared("RaceChargeMath") or require("../../../ReplicatedStorage/Shared/RaceChargeMath")
-- 2026-09-26 (owner): nobody flies in a race (the validator's flight rule, Validator.Step).
local RaceNoFlight = shared("RaceNoFlight") or require("../../../ReplicatedStorage/Shared/RaceNoFlight")

local RACE = U4.Race
local QUEUE = RACE.Queue
local MEGA = RACE.Mega
local VALIDATION = RACE.Validation
local SUPER = RACE.Super
local LENGTH = RACE.Track.Length

local LIVE_INTERVAL = 1 / RACE.Hud.LiveHz
local CAPTURE_INTERVAL = 0.5
local FALSE_START_GRACE = 0.1
local FALSE_START_HOLD = 0.3
local FALL_RECOVER_X = 26
local WINDOW_SECONDS = 2
local WINDOW_MIN_AGE = 1
local WINDOW_LATENCY_SECONDS = 0.2
local STALE_STUDS = 0.01
local CORRECTION_GRACE = 2 * VALIDATION.LatencySeconds + 0.15
-- 2026-09-25: "Npc" is the lobby's Flash NPC (it sends the category the player picked).
local JOIN_SOURCES = { Gate = true, Hud = true, Invite = true, Results = true, Panel = true, Npc = true }
local MATCH = RACE.Matchmaking
local CATEGORIES = {}
for _, name in MATCH.Categories do
	CATEGORIES[name] = true
end
local BRACKET_ORDER = RaceMath.BracketOrder
local PADS = RACE.Pads
local SOLO_WAIT_BUSY = 10 -- s: a lone heat's wait for company while other heats queue behind it
-- 2026-09-25 (final fix): a Join from a client button within REJOIN_COOLDOWN of the player's
-- own Leave is refused (RaceCooldown), so a Join/Leave toggle cannot flip the Workspace race
-- attributes (replicated to everyone) or fire Gathering invites several times a second. The
-- Race Gate pad is exempt (it debounces itself). A rejoin within REJOIN_SAME_SESSION keeps the
-- Engagement_Race session it left, so the toggle does not open funnel sessions either.
local REJOIN_COOLDOWN = 3
local REJOIN_SAME_SESSION = 10
-- Mega Race invites keep a shorter cooldown than the normal 300 s (never none: a cycle is
-- ~1.5 min, and an invite every cycle is the popup spam the plan rules out).
local MEGA_INVITE_COOLDOWN = 120
local STATE_ATTRIBUTES = {
	"RaceSlot", "RaceCruiseSpeed", "RaceSprintSpeed", "RaceSprintSeconds", "RaceRegenFactor", "RaceStatBonus",
	"RaceRewardMultiplier", "RaceChargeLevel", "RaceStartGrade", "RaceFinishMs", "RacePlace", "RaceCategory",
	"RaceHeat",
}

local RaceService = {}
RaceService.__index = RaceService
-- 2026-09-26 (owner): the Workspace attribute a closure writes (its reason; nil while the races are open), the
-- Join refusal's toast key and the Unqueued reason of the players a closure pulled out (Shared/RaceText).
RaceService.ClosedAttribute = "RaceClosedBy"
RaceService.ClosedRefusal = "RaceEventClosed"
RaceService.ClosedUnqueued = "Event"

----------------------------------------------------------------------
-- Validator (pure): one racer's envelope, spikes, finish crossing, super speed.
----------------------------------------------------------------------
local Validator = {}
RaceService.Validator = Validator

-- 2026-09-25 (Astra's map): pads = the race's speed pads (RaceTrack pads; the model is boosted
-- when the samples show a crossing), allowance = the ground profile's slope allowance (the path
-- on a slope is longer than its progress along s; 0 on a flat arena, so nothing changes there).
-- 2026-09-26: lift = RaceTrack.RootLift of the racer's standing height (a tall avatar, the
-- Silver Surfer's board): taken off every sampled y before the spike and pad tests, so a root
-- that stands higher than 3 studs is not a jump over every spike row.
function Validator.New(params, goAt, s0, x0, grade, pads, allowance, lift)
	local s = tonumber(s0) or 0
	local x = tonumber(x0) or 0
	return {
		params = params,
		model = RaceMath.NewState(params, grade or "Perfect", nil, goAt, s),
		pads = pads or {},
		allowance = math.max(0, tonumber(allowance) or 0),
		lift = RaceTrack.RootLift(RaceTrack.RootHeight + (tonumber(lift) or 0)),
		windowBoost = 1, -- the largest pad boost the model had in the current rate window
		sLast = s,
		xLast = x,
		yLast = RaceTrack.Ground(s, x) + RaceTrack.RootHeight,
		tLast = goAt,
		windowT = goAt,
		windowS = s,
		rateStrikes = 0,
		strikes = 0,
		sprint = false,
		super = false,
		speed = 0,
		graceUntil = -math.huge,
		capS = s, -- the model's speed ceiling, integrated
		history = { { t = goAt, s = s, cap = s, lat = 0 } }, -- { t, observed s, capS, latencyV } over WINDOW_SECONDS
		recent = {}, -- { t, model speed } over the last LatencySeconds (latencySpeed)
		latencyV = 0,
		airSeconds = 0, -- 2026-09-26: moving time off the ground in a row (the flight rule, Step)
	}
end

-- 2026-09-26 (owner: Sonic Dash speeds): the fastest the model was over the last LatencySeconds,
-- for the latency allowances. A sample is up to that late, so right after the model slows at
-- once (a spike trip keeps 35 %) the racer seen was still running at the old speed: allowing
-- only the new speed's latency flagged honest racers on a spike row at 300-420 studs/s.
local function latencySpeed(v, now, speedBefore)
	local recent = v.recent
	table.insert(recent, { t = now, v = v.model.v })
	while #recent > 1 and now - recent[1].t > VALIDATION.LatencySeconds do
		table.remove(recent, 1)
	end
	local best = math.max(speedBefore, v.model.v)
	for _, entry in recent do
		best = math.max(best, entry.v)
	end
	v.latencyV = best
end

-- The speed for the window rule's latency allowance (2026-09-26): the model's around both ends
-- of the window (the start sample's latencyV, and now). The model trips on a spike when the
-- server sees the crossing, a latency after the racer did; when that latency differs from the
-- window start's (it wobbles by up to ~0.3 s), the racer's run before or after the trip shows
-- shifted by the difference, up to WINDOW_LATENCY_SECONDS x the fastest it ran. So a window with
-- a trip in it (tripAt, or a latency before its start) takes the model's peak over the window.
-- At 300-420 studs/s the end speeds alone flagged honest racers on the spike rows.
local function windowSpeed(v)
	local first = v.history[1]
	local speed = math.max(v.model.v, v.latencyV or 0, first and first.lat or 0)
	if first and (v.tripAt or -math.huge) >= first.t - VALIDATION.LatencySeconds then
		for _, entry in v.history do
			speed = math.max(speed, entry.lat or 0)
		end
	end
	return speed
end

function Validator.Allowed(v)
	local model = v.model
	local speed = math.max(model.v, v.latencyV or 0)
	return model.s + math.max(0, model.s) * (VALIDATION.Tolerance + v.allowance) + VALIDATION.SlackStuds + VALIDATION.LatencySeconds * speed
end

-- The window rule: progress since the oldest kept sample against the model's speed ceiling since
-- then. Returns the furthest s allowed now (math.huge while the window is too young).
-- 2026-09-26: its latency allowance is at windowSpeed (the ends, or the peak across a trip).
function Validator.WindowAllowed(v, now)
	local first = v.history[1]
	if not first or now - first.t < WINDOW_MIN_AGE then
		return math.huge
	end
	local progress = math.max(0, v.capS - first.cap)
	return first.s + progress * (1 + VALIDATION.Tolerance + v.allowance) + VALIDATION.SlackStuds
		+ WINDOW_LATENCY_SECONDS * windowSpeed(v)
end

-- Frozen samples (no movement while the model moved) are skipped: see the header.
local function remember(v, now, s, stale)
	local history = v.history
	if not stale then
		table.insert(history, { t = now, s = s, cap = v.capS, lat = v.latencyV })
	end
	while #history > 1 and now - history[2].t >= WINDOW_SECONDS do
		table.remove(history, 1)
	end
end

-- One sample at `now` of the racer at (s, x, y). Returns { spike, correction = {s, v}, finishT,
-- superChanged, flying } (any may be nil; flying: 2026-09-26, the correction is the flight rule's).
function Validator.Step(v, now, s, x, y)
	local result = {}
	local dt = now - v.tLast
	if dt <= 0 then
		return result
	end
	y -= v.lift or 0 -- as if standing at RootHeight (2026-09-26, see Validator.New)
	local model = v.model
	local modelBefore, speedBefore = model.s, model.v
	RaceMath.Step(model, { forward = 1, sprint = v.sprint, grounded = true }, dt, v.params, now)
	v.capS += math.max(speedBefore, model.v) * dt
	latencySpeed(v, now, speedBefore)
	local stale = math.abs(s - v.sLast) < STALE_STUDS and math.abs(x - v.xLast) < STALE_STUDS and model.s - modelBefore > 0.5
	local inGrace = now < v.graceUntil
	if inGrace then
		-- Sent before the client saw the last correction: capped, never counted.
		s = math.min(s, Validator.Allowed(v))
	end
	-- 2026-09-26 (owner): nobody flies in a race (Shared/RaceNoFlight; the Flight ability is off
	-- there on the client and the server, this is what an exploited client meets). Airborne: the
	-- root more than AirStuds over its standing height (y is lift-corrected); only moving samples
	-- add up (a lag spike's frozen sample is no flight). Past MaxAirSeconds in a row it is flight:
	-- the spike rows count the racer as on the ground (a hover is no spike immunity) and it is a
	-- violation (pulled back to the model, onto the ground, a strike), so a flight never gains a
	-- stud. An honest jump is off the ground for ~0.5 s, ~1.1 s off a hill at the cap.
	if y - RaceTrack.Ground(s, x) - RaceTrack.RootHeight > RaceNoFlight.AirStuds then
		if not stale then
			v.airSeconds = (v.airSeconds or 0) + dt
		end
	else
		v.airSeconds = 0
	end
	local flying = not inGrace and (v.airSeconds or 0) > RaceNoFlight.MaxAirSeconds
	-- Spikes crossed between the two samples (tile shrunk by 1 stud: the benefit of the doubt).
	local spikeY0, spikeY1 = v.yLast, y
	if flying then
		spikeY0 = RaceTrack.Ground(v.sLast, v.xLast) + RaceTrack.RootHeight
		spikeY1 = RaceTrack.Ground(s, x) + RaceTrack.RootHeight
	end
	local tile = RaceTrack.SweptSpike(v.sLast, v.xLast, s, x, spikeY0, spikeY1, 1)
	if tile and RaceMath.SpikeHit(model, now) then
		result.spike = tile
		v.tripAt = now -- windowSpeed
	end
	-- 2026-09-25: a speed pad the samples cross (footprint grown by ServerMargin: the benefit of
	-- the doubt). The observed path is the client's own a latency late, so the boost starts where
	-- the path enters the pad (t) and the model catches up the kick it missed since then.
	local pad, fraction = RaceTrack.SweptPad(v.pads, v.sLast, v.xLast, v.yLast, s, x, y, PADS.ServerMargin)
	if pad then
		local at = v.tLast + fraction * dt
		local before = model.v
		if RaceMath.PadHit(model, pad.boost, pad.seconds, at) then
			local caught = (model.v - before) * math.max(0, now - at)
			model.s += caught
			v.capS += caught
			result.pad = pad
		end
	end
	v.windowBoost = math.max(v.windowBoost, RaceMath.BoostAt(model, now))
	v.latencyV = math.max(v.latencyV, model.v) -- a pad's kick
	local windowAllowed = Validator.WindowAllowed(v, now)
	local violation = not inGrace and (s > Validator.Allowed(v) or s > windowAllowed or flying)
	if now - v.windowT >= VALIDATION.RateWindow then
		local elapsed = now - v.windowT
		local covered = s - v.windowS
		v.speed = math.max(0, covered / elapsed)
		local rateCap = v.params.Vs * VALIDATION.RateFactor * v.windowBoost * (1 + v.allowance)
		v.windowBoost = RaceMath.BoostAt(model, now)
		if not inGrace and covered > rateCap * (elapsed + VALIDATION.LatencySeconds) then
			v.rateStrikes += 1
		else
			v.rateStrikes = 0
		end
		v.windowT, v.windowS = now, s
		local superOn = v.super
		if v.speed >= SUPER.EnterFraction * v.params.Vs then
			superOn = true
		elseif v.speed < SUPER.ExitFraction * v.params.Vs then
			superOn = false
		end
		if superOn ~= v.super then
			v.super, result.superChanged = superOn, true
		end
	end
	if violation or v.rateStrikes >= VALIDATION.RateStrikeWindows then
		local target = math.min(s, model.s, if windowAllowed < math.huge
			then windowAllowed - VALIDATION.SlackStuds - WINDOW_LATENCY_SECONDS * windowSpeed(v)
			else math.huge)
		-- Never further back than the window's start, never forward of where they are.
		target = math.min(s, math.max(target, v.history[1] and v.history[1].s or target))
		v.strikes += 1
		v.rateStrikes = 0
		v.windowT, v.windowS = now, target
		v.graceUntil = now + CORRECTION_GRACE
		result.correction = { s = target, v = model.v }
		s = target
		v.history = {}
		if flying then
			-- 2026-09-26: the correction puts the racer on the ground (RaceService pivots them
			-- to RaceTrack.GroundCFrame), and the next spike test starts from there.
			result.flying = true
			y = RaceTrack.Ground(s, x) + RaceTrack.RootHeight
		end
		v.airSeconds = 0
	end
	if not inGrace and not result.correction then
		remember(v, now, s, stale)
	elseif result.correction then
		v.history = { { t = now + CORRECTION_GRACE, s = s, cap = v.capS, lat = v.latencyV } }
	end
	if v.sLast < LENGTH and s >= LENGTH then
		local span = s - v.sLast
		result.finishT = v.tLast + (if span > 0 then (LENGTH - v.sLast) / span else 1) * dt
	end
	v.sLast, v.xLast, v.yLast, v.tLast = s, x, y, now
	return result
end

----------------------------------------------------------------------
-- Heats (pure): who races next, from the queue (2026-09-25, owner: three queues)
----------------------------------------------------------------------
-- Heat kinds and who fits them:
--   Beginner  Beginner bracket, queued Beginner or Open;
--   RankLow   Beginner or Mid bracket, queued Rank or Open;   (two adjacent brackets at most)
--   RankHigh  Mid or Pro bracket, queued Rank or Open;
--   Open      queued Open (any bracket);
--   Mega      everyone (an admin's Mega Race is a party for the whole server).
-- A Beginner-queued player who has left the Beginner bracket meanwhile counts as Rank.
RaceService.HeatKinds = { "Beginner", "RankLow", "RankHigh", "Open" }
RaceService.HeatCategory = { Beginner = "Beginner", RankLow = "Rank", RankHigh = "Rank", Open = "Open", Mega = "Open" }

local function effectiveCategory(item)
	local category = if CATEGORIES[item.category] then item.category else MATCH.DefaultCategory
	if category == "Beginner" and item.bracket ~= "Beginner" then
		return "Rank"
	end
	return category
end

function RaceService.Fits(kind, item)
	local category = effectiveCategory(item)
	local order = BRACKET_ORDER[item.bracket] or 2
	if kind == "Mega" then
		return true
	elseif kind == "Open" then
		return category == "Open"
	elseif kind == "Beginner" then
		return order == 1 and (category == "Beginner" or category == "Open")
	elseif kind == "RankLow" then
		return order <= 2 and (category == "Rank" or category == "Open")
	elseif kind == "RankHigh" then
		return order >= 2 and (category == "Rank" or category == "Open")
	end
	return false
end

-- list: the queue in order, items { category, bracket, queuedAt }. Returns { kind, category,
-- members = { indices into list, in queue order } } or nil for an empty queue.
-- The biggest heat wins (ties: the one with the longest-waiting member first); once the head of
-- the queue has waited MATCH.AnchorAfterSeconds, only heats that include the head count, so a
-- player whose heat is small (a lone Beginner) races within about one cycle. The head always
-- fits at least one kind, and each cycle takes the head once it is anchored: nobody is stranded.
function RaceService.FormHeat(list, maxPlayers, now, mega)
	if type(list) ~= "table" or #list == 0 then
		return nil
	end
	local cap = math.max(1, math.floor(tonumber(maxPlayers) or QUEUE.MaxPlayers))
	local function gather(kind)
		local members = {}
		for index, item in list do
			if #members >= cap then
				break
			end
			if RaceService.Fits(kind, item) then
				table.insert(members, index)
			end
		end
		return members
	end
	if mega then
		return { kind = "Mega", category = "Open", members = gather("Mega") }
	end
	local head = list[1]
	local anchored = (tonumber(now) or 0) - (tonumber(head.queuedAt) or math.huge) >= MATCH.AnchorAfterSeconds
	local best = nil
	for _, kind in RaceService.HeatKinds do
		local members = gather(kind)
		local usable = #members > 0 and (not anchored or members[1] == 1)
		if usable then
			local better = best == nil
				or #members > #best.members
				or (#members == #best.members and members[1] < best.members[1])
			if better then
				best = { kind = kind, category = RaceService.HeatCategory[kind], members = members }
			end
		end
	end
	return best
end

----------------------------------------------------------------------
-- Service
----------------------------------------------------------------------
-- host (all required unless marked optional):
--   now(), unix(), isOn(feature), players(), isPlayer(player),
--   sample(player) -> { alive, position: Vector3?, cframe: CFrame?, grounded, stand: number? }
--   (stand: RaceTrack.StandHeight of the humanoid, 2026-09-26; optional),
--   pivot(player, cframe), setVelocity(player, v) (optional), streamAround(player, position, done),
--   rebase(player, progress?), getProgress(player), armGrace(player), teleportToSpawn(player),
--   ping(player) -> seconds, fire(player, payload), live(player, payload),
--   setWorld(name, value), getWorld(name), setGateCollide(on),
--   rawSpeed(player), suitMax(player), dailyFirst(player), raceStats(player) -> {Races}?,
--   prepare(player, outcome) -> plan? (podium only), pay(player, outcome, plan?, done(result), index)
--   (plan nil: pay prepares it in its own thread; index 1.. staggers the payments),
--   submitPb(player, ms, weekId), funnel = {Step, NewSession, Event}, judge (RaceChargeJudge),
--   wake() (optional: start the Roblox loop),
--   bracket(player) (optional, 2026-09-25: "Beginner" | "Mid" | "Pro"),
--   pads() (optional, 2026-09-25: the arena's speed pads, RaceTrack.PadsFromParts, read at staging).
-- The ground profile is RaceTrack's current one (RaceServer sets it from the arena).
function RaceService.new(host)
	local self = setmetatable({}, RaceService)
	self.host = host
	self.phase = "Idle"
	self.endsAt = 0
	self.queue = {}
	self.entries = {}
	self.race = nil
	self.raceCounter = 0
	self.lastInvite = setmetatable({}, { __mode = "k" })
	self.lastLeave = setmetatable({}, { __mode = "k" }) -- player -> { at, session }
	self.nextCaptureAt = 0
	self.nextLiveAt = 0
	self.gatherMode = nil
	self.megaGather = false
	return self
end

local function setAttr(player, name, value)
	pcall(function()
		player:SetAttribute(name, value)
	end)
end

local function getAttr(player, name)
	local ok, value = pcall(function()
		return player:GetAttribute(name)
	end)
	return if ok then value else nil
end

function RaceService:_fire(player, payload)
	pcall(self.host.fire, player, payload)
end

function RaceService:_toast(player, key)
	self:_fire(player, { kind = "Toast", key = key })
end

function RaceService:_step(player, funnel, step, session)
	local f = self.host.funnel
	if f and f.Step then
		pcall(f.Step, player, funnel, step, session)
	end
end

function RaceService:_event(player, name)
	local f = self.host.funnel
	if f and f.Event then
		pcall(f.Event, player, name)
	end
end

function RaceService:_newSession(player, funnel)
	local f = self.host.funnel
	if f and f.NewSession then
		local ok, id = pcall(f.NewSession, player, funnel)
		return if ok then id else nil
	end
	return nil
end

function RaceService:_world(name, value)
	pcall(self.host.setWorld, name, value)
end

function RaceService:_setPhase(phase, endsAt)
	self.phase, self.endsAt = phase, endsAt or 0
	self:_world("RacePhase", phase)
	self:_world("RacePhaseEndsAt", endsAt)
end

function RaceService:MegaActive()
	return (tonumber(self.host.getWorld("RaceEventUntil")) or 0) > self.host.unix()
end

function RaceService:_limits()
	if self:MegaActive() then
		return MEGA.MinPlayers, MEGA.MaxPlayers, MEGA.GatherSeconds
	end
	return QUEUE.MinPlayers, QUEUE.MaxPlayers, QUEUE.GatherSeconds
end

function RaceService:_publishQueue()
	self:_world("RaceQueueCount", #self.queue)
end

function RaceService:_removeFromQueue(player)
	for index, queued in self.queue do
		if queued == player then
			table.remove(self.queue, index)
			self:_publishQueue()
			return true
		end
	end
	return false
end

local function tutorialSeen(player)
	return getAttr(player, "FirstTimeTutorialSeen") == true or (tonumber(getAttr(player, "Rebirths")) or 0) >= 1
end

function RaceService:_clearAttributes(player)
	for _, name in STATE_ATTRIBUTES do
		setAttr(player, name, nil)
	end
	setAttr(player, "RaceState", "")
	setAttr(player, "RaceActive", false)
	setAttr(player, "RaceMovementLocked", false)
	setAttr(player, "RaceSuperSpeed", false)
end

function RaceService:_capture(entry, sample)
	local player = entry.player
	if sample and sample.alive and sample.cframe and sample.grounded ~= false then
		entry.capture = entry.capture or {}
		entry.capture.cframe = sample.cframe
	end
	entry.capture = entry.capture or {}
	local ok, progress = pcall(self.host.getProgress, player)
	if ok and type(progress) == "number" then
		entry.capture.progress = progress
	end
end

-- Server-side arena teleports: always followed by a MovementGuard rebase (the captured lobby
-- progress, never a stage the arena happens to be nearest to) and the arrival grace.
function RaceService:_arenaPivot(entry, cframe)
	local player = entry.player
	pcall(self.host.pivot, player, cframe)
	pcall(self.host.rebase, player, entry.capture and entry.capture.progress or nil)
	pcall(self.host.armGrace, player)
end

----------------------------------------------------------------------
-- Joining and leaving
----------------------------------------------------------------------
-- The player's matchmaking bracket now: host.bracket (Speed + Rebirths, RaceMath.Bracket), else
-- the RaceBracket attribute, else Mid.
function RaceService:_bracketOf(player)
	local bracket = nil
	if self.host.bracket then
		local ok, value = pcall(self.host.bracket, player)
		bracket = if ok then value else nil
	end
	if not BRACKET_ORDER[bracket] then
		bracket = getAttr(player, "RaceBracket")
	end
	return if BRACKET_ORDER[bracket] then bracket else "Mid"
end

-- The queue as FormHeat reads it (brackets refreshed from the attribute RaceServer keeps).
function RaceService:_queueList()
	local list = {}
	for _, player in self.queue do
		local entry = self.entries[player]
		local bracket = getAttr(player, "RaceBracket")
		if entry and BRACKET_ORDER[bracket] then
			entry.bracket = bracket
		end
		table.insert(list, {
			player = player,
			category = entry and entry.category or MATCH.DefaultCategory,
			bracket = entry and entry.bracket or "Mid",
			queuedAt = entry and entry.queuedAt or 0,
		})
	end
	return list
end

-- The heat the queue would make now (nil when empty).
function RaceService:_nextHeat(now, maxPlayers)
	local _, limit = self:_limits()
	return RaceService.FormHeat(self:_queueList(), maxPlayers or limit, now, self:MegaActive())
end

function RaceService:_heatSize(now)
	local heat = self:_nextHeat(now)
	return if heat then #heat.members else 0
end

function RaceService:Join(player, source, category)
	if not JOIN_SOURCES[source] then
		return false, "BadSource"
	end
	-- Only the NPC picks a queue; everything else joins the default one (RACE AGAIN keeps the last).
	if source == "Npc" then
		if not CATEGORIES[category] then
			return false, "BadCategory"
		end
	else
		category = nil
	end
	local host = self.host
	if not host.isPlayer(player) then
		return false, "Gone"
	end
	local refusal = nil
	local bracket = self:_bracketOf(player)
	if not host.isOn("Race") then
		refusal = "RaceOff"
	elseif self.closedBy ~= nil then
		-- 2026-09-26 (owner): closed while a live event runs (Close / Reopen).
		refusal = RaceService.ClosedRefusal
	elseif getAttr(player, "DataLoaded") ~= true then
		refusal = "RaceLoading"
	elseif not tutorialSeen(player) then
		refusal = "RaceLockedTutorial"
	elseif getAttr(player, "AfkModeActive") == true then
		refusal = "RaceAfk"
	elseif getAttr(player, "DataSaveRetrying") == true then
		-- H3: while a save is being retried the profile a race would be paid from is out of
		-- date (a second daily x2) and the payout may wait behind the failed write.
		refusal = "RaceLoading"
	elseif category == "Beginner" and bracket ~= "Beginner" then
		-- 2026-09-25: Beginner races are for new racers (the NPC greys the choice out too).
		refusal = "RaceBracketLocked"
	end
	local now = host.now()
	local left = self.lastLeave[player]
	if not refusal and source ~= "Gate" and left and now - left.at < REJOIN_COOLDOWN and not self.entries[player] then
		refusal = "RaceCooldown"
	end
	local entry = self.entries[player]
	if not refusal and entry then
		local racing = entry.racer and not entry.racer.done and self.race and entry.racer.race == self.race
		if entry.state == "Queued" and category and not racing then
			-- 2026-09-25: queued, then picked a queue at the NPC: same place in line, new queue.
			entry.category, entry.bracket = category, bracket
			setAttr(player, "RaceCategory", category)
			self:_fire(player, { kind = "Queued", source = source, category = category })
			if self.phase == "Gathering" then
				self:_queueChanged(now)
			end
			return true
		end
		if entry.state == "Queued" and source == "Gate" and not entry.inArena and not racing then
			-- 2026-09-25: queued from the HUD, then walked onto the Race Gate: the gate still
			-- takes them to the staging box (same place in the queue, back to spawn afterwards).
			entry.inArena = true
			entry.capture = entry.capture or {}
			entry.capture.fromGate = true
			setAttr(player, "RaceActive", true)
			self:_arenaPivot(entry, RaceTrack.WaitCFrame(#self.queue))
			return true
		end
		-- 2026-09-25 (integrator): a racer who finished (or was DQ'd) but is still in this race,
		-- before _startResults marks them Done and requeues them, is refused too, so a Join in
		-- that window cannot queue them twice. Done (results shown) may join again.
		local inThisRace = entry.racer ~= nil and self.race ~= nil and entry.racer.race == self.race and entry.state ~= "Done"
		if entry.state == "Queued" or racing or inThisRace then
			refusal = "RaceAlreadyQueued"
		end
	end
	local sample = nil
	if not refusal then
		local ok, value = pcall(host.sample, player)
		sample = if ok then value else nil
		if not sample or not sample.alive then
			refusal = "RaceDead"
		end
	end
	if refusal then
		self:_toast(player, refusal)
		return false, refusal
	end

	if not entry then
		entry = { player = player, inArena = false, dnfStreak = 0, autoRequeue = getAttr(player, "RaceAutoRequeue") ~= false }
		self.entries[player] = entry
	end
	entry.racer = nil
	entry.state = "Queued"
	entry.source = source
	-- RACE AGAIN (Results) keeps the queue of the last race; the NPC picks one; the rest join the
	-- default queue.
	entry.category = category or (if source == "Results" then entry.category else nil) or MATCH.DefaultCategory
	entry.bracket = bracket
	entry.queuedAt = now
	if not entry.inArena then
		entry.capture = nil
		self:_capture(entry, sample)
		entry.capture.fromGate = source == "Gate"
	end
	table.insert(self.queue, player)
	self:_publishQueue()
	setAttr(player, "RaceState", "Queued")
	setAttr(player, "RaceCategory", entry.category)
	self:_fire(player, { kind = "Queued", source = source, category = entry.category })
	local rejoin = left ~= nil and now - left.at < REJOIN_SAME_SESSION and left.session ~= nil
	self.lastLeave[player] = nil
	if rejoin then
		entry.session = left.session -- the same visit to the queue: no new funnel session
	else
		entry.session = self:_newSession(player, "Engagement_Race")
		self:_step(player, "Engagement_Race", 1, entry.session)
		self:_event(player, "Race_Join_" .. source .. "_v2")
		local stats = nil
		pcall(function()
			stats = host.raceStats(player)
		end)
		local races = if type(stats) == "table" then tonumber(stats.Races) or 0 else nil
		if races == 0 then
			self:_step(player, "Onboarding_Race", 2)
		elseif races == 1 then
			self:_step(player, "Onboarding_Race", 5)
		end
		if self:MegaActive() then
			self:_event(player, "Race_MegaJoined_v2")
		end
	end
	-- Race Gate joiners wait in the arena's staging box (behind the grid).
	if source == "Gate" and not entry.inArena then
		entry.inArena = true
		setAttr(player, "RaceActive", true)
		self:_arenaPivot(entry, RaceTrack.WaitCFrame(#self.queue))
	end
	if self.phase == "Idle" then
		self:_startGathering(now)
	elseif self.phase == "Gathering" then
		self:_queueChanged(now)
	end
	if host.wake then
		pcall(host.wake)
	end
	return true
end

-- Back to the lobby: where the racer was standing when they queued (+3 studs), with the same
-- MovementGuard progress; Race Gate joiners and bad captures go to the normal spawn.
function RaceService:_returnToLobby(entry)
	local player = entry.player
	local host = self.host
	self:_clearAttributes(player)
	if not entry.inArena then
		return
	end
	entry.inArena = false
	local capture = entry.capture or {}
	local cframe = capture.cframe
	if cframe and not capture.fromGate then
		local target = cframe * CFrame.new(0, 3, 0)
		pcall(host.streamAround, player, target.Position, function()
			local current = self.entries[player]
			if not host.isPlayer(player) or (current and current.inArena) then
				return -- rejoined the arena meanwhile
			end
			pcall(host.pivot, player, target)
			pcall(host.rebase, player, capture.progress)
			pcall(host.armGrace, player)
		end)
	else
		pcall(host.teleportToSpawn, player)
		pcall(host.rebase, player, capture.progress)
	end
end

function RaceService:Leave(player, reason)
	local entry = self.entries[player]
	if not entry then
		return false
	end
	local why = if type(reason) == "string" then string.sub(reason, 1, 24) else "Player"
	if why == "Player" then
		-- Only a queue visit that never raced carries its funnel session over to a quick rejoin.
		local fresh = entry.state == "Queued" and not entry.requeuePending and entry.racer == nil
		self.lastLeave[player] = { at = self.host.now(), session = if fresh then entry.session else nil }
	end
	self:_removeFromQueue(player)
	local racer = entry.racer
	if racer and not racer.done then
		self:_markOut(racer, "Left", true)
	end
	self.entries[player] = nil
	self:_returnToLobby(entry)
	self:_clearAttributes(player)
	pcall(function()
		self.host.judge:Close(player)
	end)
	self:_fire(player, { kind = "Unqueued", reason = why })
	if self.phase == "Gathering" then
		self:_queueChanged(self.host.now())
	end
	return true
end

-- PlayerRemoving: drop everything, pay nothing.
function RaceService:Remove(player)
	local entry = self.entries[player]
	self:_removeFromQueue(player)
	if entry and entry.racer then
		entry.racer.done, entry.racer.gone = true, true
		entry.racer.outcome = entry.racer.outcome or "Gone"
	end
	self.entries[player] = nil
	self.lastInvite[player] = nil
	self.lastLeave[player] = nil
	pcall(function()
		self.host.judge:Forget(player)
	end)
	if self.phase == "Gathering" then
		self:_queueChanged(self.host.now())
	end
end

function RaceService:IsRacing(player)
	local entry = self.entries[player]
	return entry ~= nil and entry.inArena == true
end

-- 2026-09-25: kept from staging on and applied at GO: a sprint held through GO reaches the
-- server before its Running tick about half the time, and a flag refused then would leave the
-- model walking while the racer sprints until their next toggle.
function RaceService:SetSprint(player, on)
	local entry = self.entries[player]
	local racer = entry and entry.racer
	if racer and not racer.done and type(on) == "boolean" and (self.phase == "Countdown" or self.phase == "Running") then
		racer.sprint = on
		if racer.v then
			racer.v.sprint = on
		end
		return true
	end
	return false
end

function RaceService:SetAutoRequeue(player, on)
	if type(on) ~= "boolean" then
		return false
	end
	setAttr(player, "RaceAutoRequeue", on)
	local entry = self.entries[player]
	if entry then
		entry.autoRequeue = on
		if on then
			entry.dnfStreak = 0
			-- RACE AGAIN on an entry the server already requeued: the player's own choice.
			self:_commitRequeue(entry)
		end
	end
	return true
end

-- RaceChargeJudge -> the racer's model (the judge settles at or after GO).
function RaceService:OnJudged(player, grade, heldSeconds)
	local entry = self.entries[player]
	local racer = entry and entry.racer
	if not racer then
		return
	end
	racer.grade, racer.held = grade, tonumber(heldSeconds) or 0
	racer.perfect = grade == "Perfect"
	if racer.v then
		racer.v.model.grade = grade
		racer.v.model.pool = math.clamp(racer.v.model.pool - RaceChargeMath.StaminaCost(racer.held), 0, 1)
		racer.judgedApplied = true
	end
end

----------------------------------------------------------------------
-- Mega Race (admin event)
----------------------------------------------------------------------
function RaceService:StartMegaEvent(durationSeconds, byName)
	local host = self.host
	if not host.isOn("Race") or not host.isOn("MegaRace") then
		return false
	end
	local duration = math.clamp(math.floor(tonumber(durationSeconds) or 600), 30, 6 * 3600)
	self:_world("RaceEventUntil", host.unix() + duration)
	self:_world("RaceEventMultiplier", MEGA.Multiplier)
	self:_world("RaceEventBy", string.sub(tostring(byName or "Admin"), 1, 32))
	-- 2026-09-26 (owner): closed by a live event: the Mega Race's clock runs, its gathering waits for Reopen.
	if self.closedBy == nil and (self.phase == "Idle" or self.phase == "Gathering") then
		self.megaGather = true
		self:_startGathering(host.now(), true)
	end
	if host.wake then
		pcall(host.wake)
	end
	return true
end

function RaceService:StopMegaEvent()
	self:_world("RaceEventUntil", nil)
	self:_world("RaceEventMultiplier", nil)
	self:_world("RaceEventBy", nil)
	return true
end

----------------------------------------------------------------------
-- Gathering
----------------------------------------------------------------------
-- force: the Mega Race start invites everyone eligible once, whatever their cooldown.
function RaceService:_sendInvites(now, force)
	local host = self.host
	if self.closedBy ~= nil then
		return -- 2026-09-26 (owner): no race invites while a live event has the races closed
	end
	local mega = self:MegaActive()
	local unix = host.unix()
	local cooldown = if mega then MEGA_INVITE_COOLDOWN else QUEUE.InviteCooldownSeconds
	local ok, players = pcall(host.players)
	for _, player in (if ok then players else {}) do
		local eligible = not self.entries[player]
			and host.isPlayer(player)
			and getAttr(player, "DataLoaded") == true
			and getAttr(player, "AfkModeActive") ~= true
			and tutorialSeen(player)
			and (tonumber(getAttr(player, "CurrentSafeZoneStage")) or 0) <= 1
			and (force == true or unix - (self.lastInvite[player] or -math.huge) >= cooldown)
		if eligible then
			self.lastInvite[player] = unix
			self:_fire(player, { kind = "Invite", endsAt = self.endsAt, count = #self.queue, mega = mega })
		end
	end
end

-- 2026-09-25: "race" / "full" are about the next heat (RaceService.FormHeat), not the whole
-- queue: three Beginners and a Pro are a heat of 3 and a Pro who waits.
function RaceService:_startGathering(now, forceInvites)
	local minPlayers, maxPlayers, gather = self:_limits()
	local heatSize = self:_heatSize(now)
	-- A Mega Race gathers for its full time even before anyone has queued.
	self.gatherMode = if heatSize >= minPlayers or self.megaGather then "race" else "solo"
	local soloWait = QUEUE.SoloWaitSeconds
	if #self.queue > heatSize then
		-- A lone player whose heat nobody else fits, while others wait for the arena: a short
		-- wait for company, then their Time Trial, then the next heat.
		soloWait = math.min(soloWait, SOLO_WAIT_BUSY)
	end
	local endsAt = now + (if self.gatherMode == "race" then gather else soloWait)
	if heatSize >= maxPlayers then
		endsAt = math.min(endsAt, now + QUEUE.GatherFullSeconds)
	end
	self:_world("RaceMaxPlayers", maxPlayers)
	self:_setPhase("Gathering", endsAt)
	self:_sendInvites(now, forceInvites)
end

function RaceService:_queueChanged(now)
	if self.phase ~= "Gathering" then
		return
	end
	local minPlayers, maxPlayers, gather = self:_limits()
	if #self.queue == 0 and not self.megaGather then
		self:_setPhase("Idle", 0)
		return
	end
	local endsAt = self.endsAt
	local heatSize = self:_heatSize(now)
	if self.gatherMode == "solo" and heatSize >= minPlayers then
		self.gatherMode = "race"
		endsAt = now + gather
	end
	if heatSize >= maxPlayers then
		endsAt = math.min(endsAt, now + QUEUE.GatherFullSeconds)
	end
	if endsAt ~= self.endsAt then
		self:_setPhase("Gathering", endsAt)
	end
end

----------------------------------------------------------------------
-- Staging and countdown
----------------------------------------------------------------------
function RaceService:_startStaging(now)
	local host = self.host
	local _, maxPlayers = self:_limits()
	self.megaGather = false
	self.raceCounter += 1
	local mega = self:MegaActive()
	local race = {
		id = self.raceCounter,
		goAt = now + QUEUE.StagingSeconds + QUEUE.CountdownSeconds,
		stagedAt = now,
		racers = {},
		eventMultiplier = if mega then math.max(1, tonumber(host.getWorld("RaceEventMultiplier")) or MEGA.Multiplier) else 1,
		maxPlayers = maxPlayers,
		gateOpen = false,
		-- 2026-09-25 (Astra's map): the speed pads and the ground profile's slope allowance this
		-- race is judged with (read once at staging; the pads also go to the racers in Staged).
		pads = {},
		allowance = RaceTrack.GetProfile().Allowance,
	}
	if host.pads then
		local okPads, pads = pcall(host.pads)
		race.pads = if okPads and type(pads) == "table" then pads else {}
	end
	-- Set before the racers are staged: a streaming request that fails at once calls back
	-- synchronously, and that callback must already see this race.
	self.race = race
	-- 2026-09-25: the heat (RaceService.FormHeat) leaves the queue; everyone else keeps their
	-- place for the next race.
	local heat = RaceService.FormHeat(self:_queueList(), maxPlayers, now, mega)
	race.heat = heat and heat.kind or "Open"
	race.category = heat and heat.category or "Open"
	local picked, isPicked = {}, {}
	for _, index in (heat and heat.members or {}) do
		local player = self.queue[index]
		if player and not isPicked[player] then
			isPicked[player] = true
			table.insert(picked, player)
		end
	end
	local rest = {}
	for _, player in self.queue do
		if not isPicked[player] then
			table.insert(rest, player)
		end
	end
	self.queue = rest
	for _, player in picked do
		local entry = self.entries[player]
		local ok, sample = pcall(host.sample, player)
		-- H3: not while a save is being retried (see Join); an auto-requeue never passes Join.
		local saving = getAttr(player, "DataSaveRetrying") == true
		if entry and host.isPlayer(player) and ok and sample and sample.alive and not saving then
			self:_commitRequeue(entry)
			local slot = #race.racers + 1
			local regen = if getAttr(player, "StaminaRegen2xOwned") == true then RACE.Stamina.PassRegenFactor else 1
			-- A stat read that fails races on base stats rather than stopping the whole staging.
			local rawOk, rawSpeed = pcall(host.rawSpeed, player)
			local suitOk, suitMax = pcall(host.suitMax, player)
			local params = RaceMath.Params(if rawOk then rawSpeed else 0, if suitOk then suitMax else nil, regen)
			local dailyOk, daily = pcall(host.dailyFirst, player)
			local racer = {
				race = race,
				entry = entry,
				player = player,
				slot = slot,
				params = params,
				done = false,
				rewardMultiplier = race.eventMultiplier * (if dailyOk and daily then RACE.Rewards.DailyFirstMultiplier else 1),
			}
			table.insert(race.racers, racer)
			entry.racer, entry.state = racer, "Staged"
			setAttr(player, "RaceState", "Staged")
			setAttr(player, "RaceActive", true)
			setAttr(player, "RaceMovementLocked", true)
			setAttr(player, "RaceSlot", slot)
			setAttr(player, "RaceCruiseSpeed", params.Vc)
			setAttr(player, "RaceSprintSpeed", params.Vs)
			setAttr(player, "RaceSprintSeconds", params.sprintSeconds)
			setAttr(player, "RaceRegenFactor", params.regenFactor)
			setAttr(player, "RaceStatBonus", params.b)
			setAttr(player, "RaceRewardMultiplier", racer.rewardMultiplier)
			setAttr(player, "RaceSuperSpeed", false)
			setAttr(player, "RaceStartGrade", nil)
			setAttr(player, "RaceFinishMs", nil)
			setAttr(player, "RacePlace", nil)
			setAttr(player, "RaceHeat", race.heat)
			setAttr(player, "IsBoosting", false)
			self:_fire(player, {
				kind = "Staged", slot = slot, raceId = race.id, goAt = race.goAt,
				cruise = params.Vc, sprint = params.Vs, sprintSeconds = params.sprintSeconds, regenFactor = params.regenFactor,
				heat = race.heat,
				pads = RaceTrack.PadsToPayload(race.pads),
			})
			local cframe = RaceTrack.SlotCFrame(slot)
			-- 2026-09-26 (owner: "Couldn't reach the track"): the racer goes to the grid AT ONCE. The track's
			-- floor, walls, pads and spikes are Persistent (on every client from the start), so nothing waits on
			-- streaming; the stream request only loads the decor round the grid. Waiting for it first missed the
			-- 3 s staging on the heavier Green Hill map and dropped the racer at the countdown.
			self:_placeOnSlot(racer)
			pcall(host.streamAround, player, cframe.Position, function()
				if entry.racer == racer and not racer.done and self.race == race and self.phase == "Staging" then
					self:_placeOnSlot(racer) -- seated again once loaded (still before the countdown)
				end
			end)
		elseif entry then
			self.entries[player] = nil
			if entry.inArena then
				self:_returnToLobby(entry)
			end
			self:_clearAttributes(player)
			self:_fire(player, { kind = "Unqueued", reason = if saving then "Saving" else "Unavailable" })
		end
	end
	self:_publishQueue()
	if #race.racers == 0 then
		self:_endCycle(now)
		return
	end
	pcall(host.setGateCollide, true)
	self:_world("RaceId", race.id)
	self:_world("RaceGoAt", race.goAt)
	self:_world("RaceRacerCount", #race.racers)
	self:_world("RaceMaxPlayers", maxPlayers)
	self:_setPhase("Staging", now + QUEUE.StagingSeconds)
end

function RaceService:_activeRacers()
	local list = {}
	if self.race then
		for _, racer in self.race.racers do
			if not racer.done then
				table.insert(list, racer)
			end
		end
	end
	return list
end

function RaceService:_sample(racer)
	local ok, sample = pcall(self.host.sample, racer.player)
	if not ok or not sample or not sample.alive or typeof(sample.position) ~= "Vector3" then
		return nil
	end
	return sample
end

-- 2026-09-26 (owner: "Couldn't reach the track"): moves a racer onto their slot and marks them in the arena
-- once the move is seen to land (the track is Persistent: the floor is there without waiting for streaming).
-- True when they stand on the slot after it.
function RaceService:_placeOnSlot(racer): boolean
	self:_arenaPivot(racer.entry, RaceTrack.SlotCFrame(racer.slot))
	local placed = self:_sample(racer)
	local onSlot = placed ~= nil and (placed.position - RaceTrack.SlotPosition(racer.slot)).Magnitude <= QUEUE.StreamTimeoutStuds
	if onSlot then
		racer.entry.inArena = true
	end
	return onSlot
end

-- A racer not on their slot when the countdown starts (a move that did not land, a slow client) is moved there
-- now instead of dropped; dropped only if that fails too.
function RaceService:_reseat(racer): boolean
	return self:_placeOnSlot(racer)
end

function RaceService:_startCountdown(now)
	local race = self.race
	for _, racer in self:_activeRacers() do
		local sample = self:_sample(racer)
		if not sample then
			self:_markOut(racer, "Dead", false)
		elseif (not racer.entry.inArena or (sample.position - RaceTrack.SlotPosition(racer.slot)).Magnitude > QUEUE.StreamTimeoutStuds)
			and not self:_reseat(racer) then
			-- Never arrived, and moving them to the slot now failed too: back to the lobby, no race.
			racer.done, racer.outcome, racer.dropped = true, "Dropped", true
			local entry = racer.entry
			self.entries[racer.player] = nil
			self:_returnToLobby(entry) -- only teleports when they did reach the arena
			self:_fire(racer.player, { kind = "Unqueued", reason = "StreamTimeout" })
		else
			pcall(function()
				self.host.judge:Open(racer.player, race.id, race.goAt - QUEUE.ChargeOpenLeadSeconds, race.goAt)
			end)
		end
	end
	if #self:_activeRacers() == 0 then
		self:_endCycle(now)
		return
	end
	self:_setPhase("Countdown", race.goAt)
end

function RaceService:_countdownTick(now)
	local race = self.race
	for _, racer in self:_activeRacers() do
		local sample = self:_sample(racer)
		if not sample then
			self:_markOut(racer, "Dead", false)
		else
			local s = RaceTrack.ToLocal(sample.position)
			if s > VALIDATION.FalseStartS and now < race.goAt + FALSE_START_GRACE then
				-- False start: back to the slot, held 0.3 s past GO.
				self:_arenaPivot(racer.entry, RaceTrack.SlotCFrame(racer.slot))
				racer.holdUntil = math.max(now, race.goAt) + FALSE_START_HOLD
				setAttr(racer.player, "RaceMovementLocked", true)
				self:_toast(racer.player, "RaceFalseStart")
			end
		end
	end
	if not race.gateOpen and now >= race.goAt - FALSE_START_GRACE then
		race.gateOpen = true
		pcall(self.host.setGateCollide, false)
	end
	if now >= race.goAt then
		self:_startRunning(now)
	end
end

function RaceService:_startRunning(now)
	local race = self.race
	local active = self:_activeRacers()
	race.n = #active
	race.solo = race.n == 1
	race.endAt = race.goAt + QUEUE.MaxRaceSeconds
	for _, racer in active do
		local sample = self:_sample(racer)
		local slotS, slotX = RaceTrack.SlotLocal(racer.slot)
		local s0, x0 = slotS, slotX
		if sample then
			local s, x = RaceTrack.ToLocal(sample.position)
			if s <= VALIDATION.FalseStartS then
				s0, x0 = s, x
			end
		end
		-- 2026-09-26: the standing height the host reads from the humanoid (sample.stand, optional).
		local lift = RaceTrack.RootLift(sample and sample.stand)
		racer.v = Validator.New(racer.params, race.goAt, s0, x0, "Perfect", race.pads, race.allowance, lift)
		racer.v.sprint = racer.sprint == true
		if racer.grade then
			-- Judged before this step ran (a final packet right at GO).
			racer.v.model.grade = racer.grade
			racer.v.model.pool = math.clamp(1 - RaceChargeMath.StaminaCost(racer.held or 0), 0, 1)
		end
		racer.entry.state = "Racing"
		setAttr(racer.player, "RaceState", "Racing")
		if not (racer.holdUntil and racer.holdUntil > now) then
			setAttr(racer.player, "RaceMovementLocked", false)
		end
		self:_step(racer.player, "Engagement_Race", 2, racer.entry.session)
	end
	self:_world("RaceRacerCount", race.n)
	self:_setPhase("Running", race.endAt)
end

----------------------------------------------------------------------
-- Running
----------------------------------------------------------------------
function RaceService:_markOut(racer, reason, keepEntry)
	if racer.done then
		return
	end
	racer.done = true
	racer.outcome = "DNF"
	racer.reason = reason
	racer.progress = math.clamp((racer.v and racer.v.sLast or 0) / LENGTH, 0, 1)
	if reason == "Dead" or reason == "Left" then
		local player = racer.player
		local entry = self.entries[player]
		if not keepEntry and entry == racer.entry then
			-- Died (normal respawn) or moved out of the arena by something else: no return trip.
			self.entries[player] = nil
			entry.inArena = false
			self:_clearAttributes(player)
		end
		pcall(function()
			self.host.judge:Close(player)
		end)
	end
end

function RaceService:_disqualify(racer, reason)
	if racer.done and racer.outcome ~= "Finished" then
		return
	end
	racer.done, racer.dq, racer.outcome, racer.reason = true, true, "DQ", reason
	racer.finished = false
	racer.progress = math.clamp((racer.v and racer.v.sLast or 0) / LENGTH, 0, 1)
	if racer.entry then
		racer.entry.state = "Finished"
	end
	setAttr(racer.player, "RaceState", "Finished")
	self:_toast(racer.player, "RaceDisqualified")
end

function RaceService:_placeOf(racer)
	local place = 1
	for _, other in self.race.racers do
		if other ~= racer and other.finished and other.finishMs and other.finishMs < racer.finishMs then
			place += 1
		end
	end
	return place
end

function RaceService:_finish(racer, finishT, now)
	local race = self.race
	local ok, ping = pcall(self.host.ping, racer.player)
	local compensation = math.clamp((if ok then tonumber(ping) or 0 else 0) * 500, 0, VALIDATION.PingCompMaxMs)
	local ms = math.floor((finishT - race.goAt) * 1000 - compensation + 0.5)
	-- 2026-09-25: each racer's own floor (their speed), no longer one 30 s for everyone.
	if ms < RaceMath.PlausibleMs(racer.params, race.pads, race.allowance) then
		self:_disqualify(racer, "Implausible")
		return
	end
	racer.done, racer.finished, racer.finishMs, racer.outcome, racer.progress = true, true, ms, "Finished", 1
	racer.entry.state = "Finished"
	local place = self:_placeOf(racer)
	local best = tonumber(getAttr(racer.player, "RaceBestMs")) or 0
	setAttr(racer.player, "RaceFinishMs", ms)
	setAttr(racer.player, "RacePlace", place)
	setAttr(racer.player, "RaceState", "Finished")
	setAttr(racer.player, "RaceSuperSpeed", false)
	self:_fire(racer.player, { kind = "Finished", place = place, timeMs = ms, pb = best == 0 or ms < best })
	self:_step(racer.player, "Engagement_Race", 3, racer.entry.session)
	if (tonumber(getAttr(racer.player, "RaceFinishes")) or 0) == 0 then
		self:_step(racer.player, "Onboarding_Race", 4)
	end
	if not race.firstFinishAt then
		race.firstFinishAt = now
		-- 2026-09-25: speeds differ now (40..148 cruise), so the heat also waits for its slowest
		-- racer still running to finish at cruise (x FinishWaitFactor): an Open or Mega heat never
		-- DNFs a newcomer just for being slower. MaxRaceSeconds still caps it.
		local slowest = 0
		for _, other in self:_activeRacers() do
			slowest = math.max(slowest, RaceMath.ExpectedSeconds(other.params) * QUEUE.FinishWaitFactor)
		end
		race.endAt = math.min(race.endAt, math.max(now + QUEUE.FinishGraceSeconds, race.goAt + slowest))
		self:_setPhase("Running", race.endAt)
	end
end

function RaceService:_runningTick(now)
	local race = self.race
	for _, racer in self:_activeRacers() do
		local player = racer.player
		if racer.holdUntil and now >= racer.holdUntil then
			racer.holdUntil = nil
			setAttr(player, "RaceMovementLocked", false)
		end
		local sample = self:_sample(racer)
		if not sample then
			self:_markOut(racer, "Dead", false)
		else
			local s, x, y = RaceTrack.ToLocal(sample.position)
			local v = racer.v
			-- 2026-09-25: heights over the ground under the racer (a hill is not a fall).
			if RaceTrack.HeightAboveGround(s, x, y) < VALIDATION.FallY then
				-- Fell off: put back on the track where they were, stumbling (not a DNF).
				local backX = math.clamp(x, -FALL_RECOVER_X, FALL_RECOVER_X)
				self:_arenaPivot(racer.entry, RaceTrack.GroundCFrame(v.sLast, backX))
				local speedBefore = v.model.v
				RaceMath.Step(v.model, { forward = 1, sprint = v.sprint, grounded = true }, now - v.tLast, v.params, now)
				-- The window rule's ceiling keeps pace with the model (see Validator.Step).
				v.capS += math.max(speedBefore, v.model.v) * math.max(0, now - v.tLast)
				RaceMath.SpikeHit(v.model, now)
				v.tripAt = now -- 2026-09-26: Validator windowSpeed
				v.xLast, v.yLast, v.tLast = backX, RaceTrack.Ground(v.sLast, backX) + RaceTrack.RootHeight, now
				self:_fire(player, { kind = "Stumble", untilT = v.model.stumbleUntil })
			elseif not RaceTrack.InCorridor(s, x, y) then
				self:_markOut(racer, "Left", false)
			else
				local result = Validator.Step(v, now, s, x, y)
				if result.spike then
					self:_fire(player, { kind = "Stumble", untilT = v.model.stumbleUntil })
				end
				if result.correction then
					local c = result.correction
					self:_arenaPivot(racer.entry, RaceTrack.GroundCFrame(c.s, x))
					if self.host.setVelocity then
						pcall(self.host.setVelocity, player, c.v)
					end
					self:_fire(player, { kind = "Correction", s = c.s, v = c.v })
					self:_event(player, "Race_Correction_v2")
					if v.strikes >= VALIDATION.MaxStrikes then
						self:_disqualify(racer, "Strikes")
					end
				end
				if result.superChanged then
					setAttr(player, "RaceSuperSpeed", v.super)
				end
				if result.finishT and not racer.done then
					self:_finish(racer, result.finishT, now)
				end
			end
		end
	end
	if #self:_activeRacers() == 0 or now >= race.endAt then
		self:_startResults(now)
	end
end

----------------------------------------------------------------------
-- Results, cooldown
----------------------------------------------------------------------
function RaceService:_startResults(now)
	local race = self.race
	local host = self.host
	for _, racer in self:_activeRacers() do
		racer.done, racer.outcome, racer.reason = true, "DNF", "Time"
		racer.progress = math.clamp((racer.v and racer.v.sLast or 0) / LENGTH, 0, 1)
	end
	pcall(function()
		for _, racer in race.racers do
			host.judge:Close(racer.player)
		end
	end)
	-- The start collider closes again, so players waiting in the staging box for the next race
	-- cannot run the empty track meanwhile.
	pcall(host.setGateCollide, true)
	-- Ranking: finishers by time, then the rest by distance (DQ last).
	local order = table.clone(race.racers)
	table.sort(order, function(a, b)
		if a.finished ~= b.finished then
			return a.finished == true
		end
		if a.finished then
			return a.finishMs < b.finishMs
		end
		if (a.dq == true) ~= (b.dq == true) then
			return not a.dq
		end
		return (a.progress or 0) > (b.progress or 0)
	end)
	-- 2026-09-25 (final fix): only the podium (at most 3, whose Wins the Results payload shows)
	-- is prepared here, in this tick; everyone else is prepared inside their own payment thread
	-- (host.pay, staggered by `payIndex`): a profile read deep-copies the whole profile, and 16
	-- of them plus their commits in one frame broke the 1 ms tick budget (PLAN §3.9).
	local plans = {}
	local podium = {}
	for index, racer in order do
		racer.rank = index
		racer.place = if racer.finished then index else 0
		if not racer.gone and not racer.dropped then
			racer.outcome_ = {
				raceId = race.id,
				place = racer.place,
				finished = racer.finished == true,
				dq = racer.dq == true,
				progress = racer.progress or 0,
				solo = race.solo == true,
				n = race.n or #race.racers,
				timeMs = racer.finishMs or 0,
				perfect = racer.perfect == true,
				eventMultiplier = race.eventMultiplier,
			}
			if racer.finished and index <= 3 then
				local ok, plan = pcall(host.prepare, racer.player, racer.outcome_)
				plans[racer] = if ok then plan else nil
			end
			-- Races recorded before this one (0 means the next queue is the player's second,
			-- Onboarding_Race step 5, see _commitRequeue), read before any payment runs.
			local plan = plans[racer]
			if type(plan) == "table" and type(plan.before) == "table" then
				racer.racesBefore = tonumber(plan.before.Races)
			else
				local okStats, stats = pcall(host.raceStats, racer.player)
				racer.racesBefore = if okStats and type(stats) == "table" then tonumber(stats.Races) else nil
			end
		end
		if racer.finished and #podium < 3 then
			local plan = plans[racer]
			table.insert(podium, {
				UserId = racer.player.UserId,
				Name = racer.player.Name,
				Place = racer.place,
				TimeMs = racer.finishMs,
				Wins = if plan and plan.rewards then plan.rewards.wins else 0,
			})
		end
	end
	race.podium = podium
	local payIndex = 0
	for _, racer in order do
		if racer.outcome_ then
			local player = racer.player
			local session = racer.entry and racer.entry.session
			payIndex += 1
			pcall(host.pay, player, racer.outcome_, plans[racer], function(result)
				result = result or {}
				local plan = plans[racer]
				local rewarded = if result.rewarded ~= nil then result.rewarded == true
					else (type(plan) == "table" and type(plan.rewards) == "table" and plan.rewards.rewarded == true)
				if result.ok and rewarded then
					self:_step(player, "Engagement_Race", 4, session)
				end
				if result.ok and racer.finished and (result.pb or result.weeklyPb) then
					pcall(host.submitPb, player, racer.finishMs, result.weekId)
				end
				self:_fire(player, {
					kind = "Results",
					podium = podium,
					you = {
						Place = racer.place,
						Rank = racer.rank,
						Finished = racer.finished == true,
						TimeMs = racer.finishMs,
						Wins = result.wins or 0,
						Speed = result.speed or 0,
						Tickets = result.tickets or 0,
						PB = result.pb == true,
						WeeklyPB = result.weeklyPb == true,
						Outcome = if racer.dq then "DQ" elseif racer.finished then "Finished" else "DNF",
						Reason = racer.reason,
						CapReduced = result.capReduced == true,
						Multiplier = result.multiplier or 1,
						Paid = result.ok == true,
					},
				})
			end, payIndex)
		end
	end
	-- Requeue (auto by default after a race); two idle DNFs in a row switch auto-requeue off.
	for _, racer in order do
		local entry = racer.entry
		if entry and self.entries[racer.player] == entry and not racer.gone and not racer.dropped then
			entry.racesBefore = racer.racesBefore
			if racer.outcome == "DNF" and (racer.progress or 0) < QUEUE.IdleDnfProgress then
				entry.dnfStreak = (entry.dnfStreak or 0) + 1
			else
				entry.dnfStreak = 0
			end
			if entry.dnfStreak >= 2 then
				entry.autoRequeue = false
				setAttr(racer.player, "RaceAutoRequeue", false)
			elseif getAttr(racer.player, "RaceAutoRequeue") == nil then
				setAttr(racer.player, "RaceAutoRequeue", true)
			end
			entry.state = "Done"
			if entry.autoRequeue and entry.inArena and host.isOn("Race") then
				self:_requeue(entry)
			end
		end
	end
	self:_setPhase("Results", now + QUEUE.ResultsSeconds)
end

-- 2026-09-25 (final fix): the automatic requeue keeps the racer's place in the queue at once,
-- but its funnel steps wait for the player's choice (_commitRequeue): RACE AGAIN (RaceAgain or
-- AutoRequeue true), or still being queued when the next race stages. The client's LOBBY timer
-- leaves 8 s later otherwise, and logging at once counted every first finisher as
-- Race_SecondRace and every result screen as a new queue.
function RaceService:_requeue(entry)
	local player = entry.player
	entry.state = "Queued"
	entry.racer = nil
	entry.requeuePending = true
	-- Back of the line, same queue (category) as the race just run.
	entry.queuedAt = self.host.now()
	entry.category = entry.category or MATCH.DefaultCategory
	table.insert(self.queue, player)
	self:_publishQueue()
	setAttr(player, "RaceState", "Queued")
	setAttr(player, "RaceMovementLocked", false)
end

function RaceService:_commitRequeue(entry)
	if not entry.requeuePending then
		return
	end
	entry.requeuePending = nil
	local player = entry.player
	entry.session = self:_newSession(player, "Engagement_Race")
	self:_step(player, "Engagement_Race", 1, entry.session)
	self:_event(player, "Race_Requeued_v2")
	-- 2026-09-25: most second races are auto-requeues, which never pass through Join.
	if entry.racesBefore == 0 then
		self:_step(player, "Onboarding_Race", 5)
	end
	entry.racesBefore = nil
end

-- "Race again" from the results: queue up again without leaving the arena.
function RaceService:RaceAgain(player)
	local entry = self.entries[player]
	if entry and entry.state == "Queued" and entry.inArena then
		self:_commitRequeue(entry) -- already requeued by the server: no "already queued" toast
		return true
	end
	if entry and entry.state == "Done" and entry.inArena then
		entry.autoRequeue = true
		entry.dnfStreak = 0
		setAttr(player, "RaceAutoRequeue", true)
		self:_requeue(entry)
		self:_commitRequeue(entry)
		if self.phase == "Gathering" then
			self:_queueChanged(self.host.now())
		end
		return true
	end
	return self:Join(player, "Results")
end

function RaceService:_endCycle(now)
	local race = self.race
	if race then
		for _, racer in race.racers do
			local entry = racer.entry
			if entry and self.entries[racer.player] == entry and entry.state ~= "Queued" then
				self.entries[racer.player] = nil
				self:_returnToLobby(entry)
			end
		end
	end
	self.race = nil
	self:_world("RaceRacerCount", 0)
	if #self.queue > 0 then
		self:_startGathering(now)
	else
		self:_setPhase("Idle", 0)
	end
end

----------------------------------------------------------------------
-- Live standings (4 Hz, unreliable)
----------------------------------------------------------------------
function RaceService:_standings()
	local list = {}
	for _, racer in self.race.racers do
		if not racer.gone and not racer.dropped and not racer.dq then
			table.insert(list, racer)
		end
	end
	table.sort(list, function(a, b)
		if (a.finished == true) ~= (b.finished == true) then
			return a.finished == true
		end
		if a.finished then
			return a.finishMs < b.finishMs
		end
		return (a.v and a.v.sLast or -math.huge) > (b.v and b.v.sLast or -math.huge)
	end)
	return list
end

function RaceService:_liveTick(now)
	local race = self.race
	if not race then
		return
	end
	local standings = self:_standings()
	local top = {}
	for index = 1, math.min(3, #standings) do
		local racer = standings[index]
		table.insert(top, { u = racer.player.UserId, s = math.floor(racer.v and racer.v.sLast or 0), f = racer.finishMs })
	end
	local endAt = race.endAt or race.goAt
	local base = { id = race.id, t = now, left = math.max(0, endAt - now), n = race.n or #race.racers, top = top }
	local placeOf = {}
	for index, racer in standings do
		placeOf[racer] = index
	end
	for _, racer in race.racers do
		if not racer.gone and not racer.dropped and self.entries[racer.player] == racer.entry then
			local packet = table.clone(base)
			packet.you = {
				place = placeOf[racer],
				s = math.floor(racer.v and racer.v.sLast or 0),
				pool = racer.v and racer.v.model.pool or 1,
				strikes = racer.v and racer.v.strikes or 0,
			}
			pcall(self.host.live, racer.player, packet)
		end
	end
	for _, player in self.queue do
		local entry = self.entries[player]
		if entry and not entry.racer then
			pcall(self.host.live, player, base)
		end
	end
end

----------------------------------------------------------------------
-- Tick
----------------------------------------------------------------------
function RaceService:_captureTick(now)
	for player, entry in self.entries do
		local waiting = entry.state == "Queued" or entry.state == "Done"
		if waiting then
			local ok, sample = pcall(self.host.sample, player)
			if not entry.inArena then
				if entry.state == "Queued" and ok and sample then
					self:_capture(entry, sample)
				end
			elseif not (ok and sample and sample.alive) then
				-- Died while waiting in the arena: the normal respawn takes them to the lobby.
				self.entries[player] = nil
				self:_removeFromQueue(player)
				self:_clearAttributes(player)
				self:_fire(player, { kind = "Unqueued", reason = "Dead" })
			elseif typeof(sample.position) == "Vector3" and not RaceTrack.InCorridor(RaceTrack.ToLocal(sample.position)) then
				-- 2026-09-25: moved out of the arena by something else (a stage trip, an admin
				-- teleport) while waiting: two samples in a row, so a pivot that has not landed
				-- yet never counts. A queued player stays queued from where they are now (the
				-- staging teleport fetches them); one who was done is simply released.
				entry.outside = (entry.outside or 0) + 1
				if entry.outside >= 2 then
					entry.outside = nil
					entry.inArena = false
					if entry.state == "Queued" then
						entry.capture = nil
						self:_capture(entry, sample)
						setAttr(player, "RaceActive", false)
					else
						self.entries[player] = nil
						self:_clearAttributes(player)
						self:_fire(player, { kind = "Unqueued", reason = "Left" })
					end
				end
			else
				entry.outside = nil
			end
		end
	end
end

-- The feature was switched off live (Workspace.U4Off_Race): nobody waits for a race that will
-- not start; a race already running finishes normally.
function RaceService:_dropQueue(reason)
	for _, player in table.clone(self.queue) do
		self:Leave(player, reason)
	end
end

----------------------------------------------------------------------
-- 2026-09-26 (owner): closed while a live event runs
----------------------------------------------------------------------
local function closedReason(reason)
	return if type(reason) == "string" and reason ~= "" then string.sub(reason, 1, 32) else "Event"
end

function RaceService:IsClosed()
	return self.closedBy ~= nil
end

-- Calls the whole cycle off at once, whatever its phase, with no penalty for anyone: a racer still running is
-- marked "Aborted" (never DNF: no Results, no payment for this race, no dnfStreak or auto-requeue change, no
-- funnel step), queued players leave the queue with no rejoin cooldown (lastLeave untouched), the charge judge
-- closes, and everyone in the arena (staging box, grid, track, results screen) goes back to the lobby spawn
-- with the MovementGuard progress they had when they queued (like _returnToLobby's spawn trip). A race whose
-- results were already out keeps its payments (they were sent at _startResults). Returns the players it pulled
-- out and, second, those of them it sent to the spawn.
function RaceService:_abortAll()
	local host = self.host
	local pulled, moved = {}, {}
	local race = self.race
	if race then
		for _, racer in race.racers do
			if not racer.done then
				racer.done, racer.aborted, racer.outcome, racer.reason = true, true, "Aborted", "Closed"
			end
		end
	end
	local players, seen = {}, {}
	for player in self.entries do
		seen[player] = true
		table.insert(players, player)
	end
	for _, player in self.queue do
		if not seen[player] then
			seen[player] = true
			table.insert(players, player)
		end
	end
	for _, player in players do
		local entry = self.entries[player]
		self.entries[player] = nil
		table.insert(pulled, player)
		self:_clearAttributes(player)
		pcall(function()
			host.judge:Close(player)
		end)
		if entry and entry.inArena then
			entry.inArena = false
			table.insert(moved, player)
			pcall(host.teleportToSpawn, player)
			pcall(host.rebase, player, entry.capture and entry.capture.progress or nil)
		end
		self:_fire(player, { kind = "Unqueued", reason = RaceService.ClosedUnqueued })
	end
	self.queue = {}
	self:_publishQueue()
	self.race = nil
	self.megaGather = false
	self.gatherMode = nil
	pcall(host.setGateCollide, true)
	self:_world("RaceRacerCount", 0)
	self:_setPhase("Idle", 0)
	return pulled, moved
end

-- Closes the races for `reason` (a live event's name): the cycle is called off (_abortAll), Workspace.
-- RaceClosedBy = reason, and every Join is refused (RaceEventClosed) until Reopen. Returns _abortAll's lists.
function RaceService:Close(reason)
	local why = closedReason(reason)
	self.closedBy = why
	self:_world(RaceService.ClosedAttribute, why)
	return self:_abortAll()
end

-- Opens the races again (only the closure of `reason` when one is given). A Mega Race still on its clock
-- gathers again at once. Returns whether they were closed.
function RaceService:Reopen(reason)
	if self.closedBy == nil or (reason ~= nil and closedReason(reason) ~= self.closedBy) then
		return false
	end
	self.closedBy = nil
	self:_world(RaceService.ClosedAttribute, nil)
	local host = self.host
	if self.phase == "Idle" and self:MegaActive() and host.isOn("Race") then
		self.megaGather = true
		self:_startGathering(host.now())
		if host.wake then
			pcall(host.wake)
		end
	end
	return true
end

function RaceService:Tick(now)
	local host = self.host
	if (self.phase == "Idle" or self.phase == "Gathering") and #self.queue > 0 and not host.isOn("Race") then
		self:_dropQueue("RaceOff")
	end
	if now >= self.nextCaptureAt then
		self.nextCaptureAt = now + CAPTURE_INTERVAL
		self:_captureTick(now)
	end
	if self.race and host.judge then
		pcall(host.judge.Tick, host.judge, now)
	end
	local phase = self.phase
	if phase == "Idle" then
		if #self.queue > 0 then
			self:_startGathering(now)
		end
	elseif phase == "Gathering" then
		if #self.queue == 0 and not self.megaGather then
			self:_setPhase("Idle", 0)
		elseif now >= self.endsAt then
			if #self.queue > 0 then
				self:_startStaging(now)
			else
				self.megaGather = false
				self:_setPhase("Idle", 0)
			end
		end
	elseif phase == "Staging" then
		if now >= self.endsAt then
			self:_startCountdown(now)
		end
	elseif phase == "Countdown" then
		self:_countdownTick(now)
	elseif phase == "Running" then
		self:_runningTick(now)
	elseif phase == "Results" then
		if now >= self.endsAt then
			self:_setPhase("Cooldown", now + QUEUE.CooldownSeconds)
		end
	elseif phase == "Cooldown" then
		if now >= self.endsAt then
			self:_endCycle(now)
		end
	end
	if self.race and now >= self.nextLiveAt and (self.phase == "Staging" or self.phase == "Countdown" or self.phase == "Running" or self.phase == "Results") then
		self.nextLiveAt = now + LIVE_INTERVAL
		self:_liveTick(now)
	end
	return self.phase
end

return RaceService
