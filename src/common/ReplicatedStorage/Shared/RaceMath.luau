--!strict
-- ReplicatedStorage/Shared/RaceMath.luau — Update 4 race speed, stamina and rewards (pure).
-- The same code runs in the client's prediction, the server's envelope and the Lune tests.
-- 2026-09-25 (owner): the speed reflects progress. Cruise Vc = BaseCruise + LogScale*log10(Speed)
-- clamped to [BaseCruise, MaxCruise] (40 at Speed 1, 76 at 1e6, 112 at 1e12, 148 from 1e18);
-- the world walk multipliers (World 2 x0.5, World 3 x0.25) are still never used, so a race
-- feels the same in every world. Fair heats come from the brackets (Bracket, RaceService).
-- 2026-09-26 (owner: Sonic Dash speeds): Vc = 100 + 18*log10(Speed + 1) capped at 300 (105 at
-- Speed 1, 208 at 1e6, 262 at 1e9, 300 from ~1.3e11: every Pro races at the cap).
-- Step integrates v <- Vt + (v - Vt)*exp(-dt/tau) exactly (s gets the exact integral), so the
-- distance does not depend on the frame rate for a constant target.
local U4: any = if typeof(script) == "Instance"
	then require((script :: any).Parent:WaitForChild("Update4Config", 10))
	else require("./Update4Config")
local RaceChargeMath: any = if typeof(script) == "Instance"
	then require((script :: any).Parent:WaitForChild("RaceChargeMath", 10))
	else require("./RaceChargeMath")

local SPEED = U4.Race.Speed
local STAMINA = U4.Race.Stamina
local SPIKES = U4.Race.Spikes
local REWARDS = U4.Race.Rewards
local CHARGE = U4.Race.Charge
local VALIDATION = U4.Race.Validation
local MATCH = U4.Race.Matchmaking
local PADS = U4.Race.Pads
local LENGTH = U4.Race.Track.Length

local RaceMath = {}
-- The record floor (profiles, boards): under the fastest race the speed cap allows. A racer's
-- own implausibility floor is RaceMath.PlausibleMs(params).
RaceMath.MinPlausibleMs = VALIDATION.MinPlausibleMs
RaceMath.MaxSafeInteger = 9007199254740991

local function number(value: any, default: number): number
	local n = tonumber(value)
	if n == nil or n ~= n or n == math.huge or n == -math.huge then
		return default
	end
	return n
end

----------------------------------------------------------------------
-- Speed and stamina
----------------------------------------------------------------------
-- The race cruise speed of a Speed stat: BaseCruise + LogScale*log10(Speed + 1), Speed >= 0,
-- capped (2026-09-26, the owner's formula: log10(Speed + 1), so Speed 0 races at the base).
function RaceMath.CruiseSpeed(rawSpeed: number?): number
	local raw = math.max(0, number(rawSpeed, 0))
	return math.clamp(SPEED.BaseCruise + SPEED.LogScale * math.log10(raw + 1), SPEED.BaseCruise, SPEED.MaxCruise)
end

-- The part of the cruise that comes from the stat (RaceStatBonus): 0 at Speed 0, 2 at the cap.
function RaceMath.StatBonus(rawSpeed: number?): number
	return RaceMath.CruiseSpeed(rawSpeed) / SPEED.BaseCruise - 1
end

export type Caps = { Vc: number, Vs: number, b: number }
function RaceMath.Caps(rawSpeed: number?): Caps
	local vc = RaceMath.CruiseSpeed(rawSpeed)
	return { Vc = vc, Vs = SPEED.SprintMultiplier * vc, b = vc / SPEED.BaseCruise - 1 }
end

-- The fastest any model of these params can ever go: sprint x the Perfect start's peak (or the
-- Perfect launch itself, were it ever higher).
function RaceMath.PeakSpeed(params: any): number
	local peak = math.max(1, number(CHARGE.Boost.Perfect[1], 1))
	local vc, vs = number(params and params.Vc, 0), number(params and params.Vs, 0)
	return math.max(vs * peak, vc * number(CHARGE.Launch.Perfect, 1))
end

-- A finish faster than this (ms) is implausible for these params: the whole track at the peak
-- speed, with the envelope's tolerance on top (honest races are ~1.7x slower).
-- 2026-09-25: pads (a list of { boost, seconds }, RaceTrack pads) and the ground profile's slope
-- allowance (slopeAllowance) lower it: each pad adds at most (boost - 1) x peak x seconds of
-- distance (its instant kick included), and the envelope's tolerance grows by the allowance.
function RaceMath.PlausibleMs(params: any, pads: { any }?, slopeAllowance: number?): number
	local peak = RaceMath.PeakSpeed(params)
	if not (peak > 0) then
		return RaceMath.MinPlausibleMs
	end
	local gained = 0
	for _, pad in pads or {} do
		local boost = math.clamp(number(pad.boost, 1), 1, PADS.MaxBoost)
		local seconds = math.clamp(number(pad.seconds, 0), 0, PADS.MaxSeconds)
		gained += (boost - 1) * peak * (seconds + SPEED.TauDown)
	end
	local distance = math.max(LENGTH * 0.5, LENGTH - gained)
	local tolerance = 1 + VALIDATION.Tolerance + math.max(0, number(slopeAllowance, 0))
	return math.max(RaceMath.MinPlausibleMs, math.floor(1000 * distance / (peak * tolerance)))
end

-- 2026-09-26: the seconds one spike trip costs a racer at cruise (Step's exact exponentials):
-- the stumble (StumbleSeconds toward StumbleFactor x cruise from Keep x cruise), then the run
-- floor at once (RunFloor x cruise) and the climb back to cruise (TauUp). ~1.08 s with
-- Update4Config's numbers, whatever the cruise.
function RaceMath.TripSeconds(): number
	local keep, factor, stumble = SPIKES.Keep, SPEED.StumbleFactor, SPIKES.StumbleSeconds
	local tau1 = if keep <= factor then SPEED.TauUp else SPEED.TauDown
	local decay = math.exp(-stumble / tau1)
	local during = (1 - factor) * stumble - (keep - factor) * tau1 * (1 - decay)
	local v1 = math.max(factor + (keep - factor) * decay, SPEED.RunFloor or 0)
	local after = math.max(0, 1 - v1) * SPEED.TauUp
	return math.max(0, during + after)
end

-- The spike rows of the track (Update4Config.Race.Track.SpikeBlocked: a list of rows per field).
local function spikeRowCount(): number
	local rows = 0
	for _, field in U4.Race.Track.SpikeBlocked or {} do
		for _, blocked in field do
			rows += if #blocked > 0 then 1 else 0
		end
	end
	return rows
end

-- Seconds an honest racer of these params needs at cruise alone (no sprint, no boost): how long
-- a heat waits for its slowest racer after the first finish (RaceService). 2026-09-26: plus one
-- trip (TripSeconds) per spike row, so a newcomer who trips on every row still finishes.
function RaceMath.ExpectedSeconds(params: any): number
	local vc = number(params and params.Vc, SPEED.BaseCruise)
	return LENGTH / math.max(1, vc) + spikeRowCount() * RaceMath.TripSeconds()
end

-- The matchmaking bracket of a Speed stat and a rebirth count: the higher of the two tiers.
RaceMath.BracketOrder = { Beginner = 1, Mid = 2, Pro = 3 }
function RaceMath.Bracket(rawSpeed: number?, rebirths: number?): string
	local speed = math.max(0, number(rawSpeed, 0))
	local r = math.max(0, math.floor(number(rebirths, 0)))
	local bySpeed = if speed >= MATCH.ProMinSpeed then 3 elseif speed >= MATCH.BeginnerMaxSpeed then 2 else 1
	local byRebirths = if r >= MATCH.ProMinRebirths then 3 elseif r > MATCH.BeginnerMaxRebirths then 2 else 1
	return MATCH.Brackets[math.max(bySpeed, byRebirths)]
end

-- Seconds of sprint in a full race pool: 4.0 (FlashSuit, stamina 5) ... 5.0 (Silver Surfer, 70).
function RaceMath.SprintSeconds(suitMax: number?): number
	local suit = number(suitMax, 5)
	return STAMINA.SprintBaseSeconds * (1 + STAMINA.SuitSprintBonus * math.clamp((suit - 5) / 65, 0, 1))
end

export type Params = { Vc: number, Vs: number, b: number, sprintSeconds: number, regenFactor: number }
-- Everything a racer's model needs; the server sends Vc/Vs/sprintSeconds/regenFactor in Staged.
function RaceMath.Params(rawSpeed: number?, suitMax: number?, regenFactor: number?): Params
	local caps = RaceMath.Caps(rawSpeed)
	return {
		Vc = caps.Vc,
		Vs = caps.Vs,
		b = caps.b,
		sprintSeconds = RaceMath.SprintSeconds(suitMax),
		regenFactor = math.clamp(number(regenFactor, 1), 0.5, 4),
	}
end

export type State = {
	s: number,
	v: number,
	pool: number,
	sprinting: boolean,
	stumbleUntil: number,
	immuneUntil: number,
	lastSprintAt: number,
	goAt: number,
	grade: string,
	vt: number,
	tau: number,
	boostUntil: number,
	boostMul: number,
}

function RaceMath.NewState(params: Params, grade: string?, v0: number?, goAt: number?, s0: number?): State
	local g = grade or "Ok"
	return {
		s = number(s0, 0),
		v = math.max(0, number(v0, params.Vc * RaceChargeMath.Launch(g, CHARGE))),
		pool = 1,
		sprinting = false,
		stumbleUntil = -math.huge,
		immuneUntil = -math.huge,
		lastSprintAt = -math.huge,
		goAt = number(goAt, 0),
		grade = g,
		vt = 0,
		tau = SPEED.TauUp,
		boostUntil = -math.huge, -- a speed pad's boost (PadHit)
		boostMul = 1,
	}
end

export type Input = { forward: number?, sprint: boolean?, grounded: boolean?, jumped: boolean? }

-- 2026-09-25 (owner: never walk in a race): while racing the racer runs down the track (-Z) by
-- itself. The player's move direction (x, z; world, any length) steers: with no input it is
-- straight ahead, a sideways or forward input is added to "ahead" (so steering never slows the
-- racer), and only a clearly backward input (dot < -AUTO_BRAKE_DOT) is kept as it is (braking).
-- Returns the unit direction (x, z). InstantMovementController moves along it and
-- Race/RaceInputClient feeds the same direction to the model.
local AUTO_BRAKE_DOT = 0.35
function RaceMath.AutoRunDirection(x: number?, z: number?): (number, number)
	local dx, dz = number(x, 0), number(z, 0)
	local length = math.sqrt(dx * dx + dz * dz)
	if length < 0.05 then
		return 0, -1
	end
	dx, dz = dx / length, dz / length
	if -dz >= -AUTO_BRAKE_DOT then
		dz -= 1
		length = math.sqrt(dx * dx + dz * dz)
		dx, dz = dx / length, dz / length
	end
	return dx, dz
end

-- Forward input from a move direction and the track heading: max(0, dot) inside the cone.
function RaceMath.ForwardInput(dot: number): number
	local d = math.clamp(number(dot, 0), -1, 1)
	if d <= math.cos(math.rad(SPEED.InputConeDegrees)) then
		return 0
	end
	return d
end

-- The speed the racer is pulled toward right now (0 before GO and without forward input).
function RaceMath.Target(state: State, input: Input, params: Params, now: number): number
	local forward = number(input.forward, 0)
	local tau = now - state.goAt
	if forward <= 0 or tau < 0 then
		return 0
	end
	if now < state.stumbleUntil then
		return SPEED.StumbleFactor * params.Vc
	end
	local base = if state.sprinting then params.Vs else params.Vc
	return base * RaceChargeMath.StartMultiplier(state.grade, tau, CHARGE) * RaceMath.BoostAt(state, now)
end

-- A speed pad's multiplier on the cap at `now` (1 without one).
function RaceMath.BoostAt(state: any, now: number): number
	if now < (state.boostUntil or -math.huge) then
		return math.max(1, state.boostMul or 1)
	end
	return 1
end

-- 2026-09-25 (speed pads): a pad at `now`. Not boosted: an instant kick (v x boost) and the cap x
-- boost until now + seconds. Already boosted: only the time is refreshed (and the multiplier is
-- the larger of the two), never a second kick: pads never stack. Returns true on a new boost.
function RaceMath.PadHit(state: any, boost: number?, seconds: number?, now: number): boolean
	local b = math.clamp(number(boost, PADS.DefaultBoost), 1, PADS.MaxBoost)
	local d = math.clamp(number(seconds, PADS.DefaultSeconds), 0, PADS.MaxSeconds)
	local active = now < (state.boostUntil or -math.huge)
	if active then
		state.boostMul = math.max(state.boostMul or 1, b)
		state.boostUntil = math.max(state.boostUntil, now + d)
		return false
	end
	state.boostMul = b
	state.boostUntil = now + d
	state.v *= b
	return true
end

-- The least speed a racer moving forward on the ground has (0 before GO, without forward input,
-- in the air or while stumbling).
function RaceMath.RunFloor(state: State, input: Input, params: Params, now: number): number
	local tau = now - state.goAt
	if number(input.forward, 0) <= 0 or tau < 0 or input.grounded == false or now < state.stumbleUntil then
		return 0
	end
	local m = math.clamp(RaceChargeMath.StartMultiplier(state.grade, tau, CHARGE), 0, 1)
	return SPEED.RunFloor * params.Vc * m
end

function RaceMath.Step(state: State, input: Input, dt: number, params: Params, now: number): State
	if not (dt > 0) then
		return state
	end
	local stumbling = now < state.stumbleUntil
	-- Sprint starts only with MinSprintPool, then runs while the pool lasts.
	if input.sprint == true and not stumbling and now >= state.goAt then
		if not state.sprinting and state.pool >= STAMINA.MinSprintPool then
			state.sprinting = true
		elseif state.sprinting and state.pool <= 0 then
			state.sprinting = false
		end
	else
		state.sprinting = false
	end
	if input.jumped == true then
		state.pool = math.max(0, state.pool - STAMINA.JumpCost)
	end

	-- 2026-09-25 (owner: never walk in a race): moving forward on the ground the racer runs at
	-- least RunFloor x cruise at once, scaled by the start multiplier while it is under 1 (a
	-- Stall's hold stays a stop). Not while a spike trips them (the stumble is the penalty).
	local floor = RaceMath.RunFloor(state, input, params, now)
	if state.v < floor then
		state.v = floor
	end

	local target = RaceMath.Target(state, input, params, now)
	if input.grounded == false and target > state.v then
		target = state.v -- no acceleration in the air
	end
	local tau = if target >= state.v then SPEED.TauUp else SPEED.TauDown
	local decay = math.exp(-dt / tau)
	local v0 = state.v
	state.s += target * dt + (v0 - target) * tau * (1 - decay)
	state.v = math.max(0, target + (v0 - target) * decay)
	state.vt, state.tau = target, tau

	if state.sprinting then
		state.lastSprintAt = now
		if state.v > 0.5 * params.Vc then
			state.pool = math.max(0, state.pool - dt / params.sprintSeconds)
		end
		if state.pool <= 0 then
			state.sprinting = false
		end
	elseif now - state.lastSprintAt >= STAMINA.RegenDelay then
		state.pool = math.min(1, state.pool + STAMINA.RegenPerSecond * dt * params.regenFactor)
	end
	state.pool = math.clamp(state.pool, 0, 1)
	return state
end

-- For the HUD "MPH/s": the current pull toward the target.
function RaceMath.Accel(state: State): number
	return (state.vt - state.v) / math.max(1e-3, state.tau)
end

-- A spike: keep 35 % of the speed, stumble 0.7 s (no sprint, half cruise), then 0.9 s immune.
-- Returns false (nothing done) while immune.
function RaceMath.SpikeHit(state: State, now: number): boolean
	if now < state.immuneUntil then
		return false
	end
	state.v *= SPIKES.Keep
	state.sprinting = false
	state.stumbleUntil = now + SPIKES.StumbleSeconds
	state.immuneUntil = now + SPIKES.StumbleSeconds + SPIKES.ImmuneSeconds
	return true
end

----------------------------------------------------------------------
-- Days, weeks
----------------------------------------------------------------------
-- Weeks start on Monday 00:00 UTC (1970-01-01 was a Thursday).
function RaceMath.WeekId(now: number): number
	return math.floor((now + 3 * 86400) / 604800)
end

function RaceMath.DayId(now: number): number
	return math.floor(now / 86400)
end

----------------------------------------------------------------------
-- Rewards
----------------------------------------------------------------------
function RaceMath.FieldFactor(n: number): number
	return math.clamp(REWARDS.FieldBase + REWARDS.FieldPerRacer * number(n, 1), REWARDS.FieldMin, REWARDS.FieldMax)
end

-- World 1 pays by how far the player is toward World 2 (squared), so a new player's win is not
-- worth a veteran's lap; World 2 and 3 pay in full.
function RaceMath.ProgressFactor(world: string?, rebirths: number?, unlockRebirths: number?): number
	if world ~= "World1" then
		return 1
	end
	local r = math.max(0, number(rebirths, 0))
	local unlock = math.max(1, number(unlockRebirths, 6))
	return math.min(1, ((r + 1) / (unlock + 1)) ^ 2)
end

-- Wins share of a lap and AFK-minutes of Speed for one result. progress = fraction of the track.
function RaceMath.Shares(place: number?, finished: boolean, progress: number?, solo: boolean?, dq: boolean?): (number, number)
	if dq then
		return 0, 0
	end
	if finished then
		local p = math.floor(number(place, 0))
		if not solo and p >= 1 and p <= #REWARDS.WinsShare then
			return REWARDS.WinsShare[p], REWARDS.SpeedAfkMinutes[p]
		end
		return REWARDS.FinisherShare, REWARDS.FinisherAfkMinutes
	end
	if number(progress, 0) >= REWARDS.DnfMinProgress then
		return REWARDS.DnfShare, REWARDS.DnfAfkMinutes
	end
	return 0, 0
end

export type RewardContext = {
	place: number?,
	finished: boolean?,
	dq: boolean?,
	progress: number?,
	solo: boolean?,
	n: number?,
	lapWins: number?,
	world: string?,
	rebirths: number?,
	unlockRebirths: number?,
	eventMultiplier: number?,
	dailyFirst: boolean?,
	hourCount: number?,
	winsMultiplier: number?,
	rawSpeed: number?,
	speedFloor: number?,
	speedShare: number?,
}

export type Rewards = {
	wins: number,
	speed: number,
	tickets: number,
	capReduced: boolean,
	multiplier: number,
	rewarded: boolean,
	dailyUsed: boolean,
	field: number,
	shareW: number,
	minutes: number,
}

function RaceMath.ComputeRewards(ctx: RewardContext): Rewards
	local n = math.max(1, math.floor(number(ctx.n, 1)))
	local solo = ctx.solo == true or n <= 1
	local field = RaceMath.FieldFactor(if solo then 1 else n)
	local shareW, minutes = RaceMath.Shares(ctx.place, ctx.finished == true, ctx.progress, solo, ctx.dq == true)
	local hourCount = number(ctx.hourCount, 0)
	-- 2026-09-25: past HourlyPaidRaces rewarded races this hour a race pays nothing and is not
	-- "rewarded" (no hour count, no daily x2 spent): fast racers cycle races much quicker.
	local cap = if hourCount < REWARDS.HourlyFullRaces then 1
		elseif hourCount < (REWARDS.HourlyPaidRaces or math.huge) then REWARDS.OverCapFactor
		else 0
	local earned = shareW > 0 or minutes > 0
	local rewarded = earned and cap > 0
	local event = math.clamp(number(ctx.eventMultiplier, 1), 1, 10)
	local daily = if rewarded and ctx.dailyFirst == true then REWARDS.DailyFirstMultiplier else 1
	local lap = math.max(0, number(ctx.lapWins, 0))
	local progress = RaceMath.ProgressFactor(ctx.world, ctx.rebirths, ctx.unlockRebirths)
	local winsMultiplier = math.max(1, number(ctx.winsMultiplier, 1))
	local base = math.floor(lap * progress * shareW * field * event * daily * cap)
	local wins = math.clamp(math.floor(base * winsMultiplier), 0, RaceMath.MaxSafeInteger)
	local raw = math.max(0, number(ctx.rawSpeed, 0))
	local perMinute = math.max(number(ctx.speedFloor, 500), raw * number(ctx.speedShare, 0.005))
	local speed = math.floor(perMinute * minutes * field * event * daily * cap)
	speed = math.clamp(speed, 0, math.floor(REWARDS.SpeedCapShareOfRaw * raw + REWARDS.SpeedCapFlat))
	return {
		wins = wins,
		speed = speed,
		tickets = if daily > 1 then REWARDS.DailyFirstSpinTickets else 0,
		capReduced = earned and cap < 1,
		multiplier = event * daily,
		rewarded = rewarded,
		dailyUsed = daily > 1,
		field = field,
		shareW = shareW,
		minutes = minutes,
	}
end

return RaceMath
