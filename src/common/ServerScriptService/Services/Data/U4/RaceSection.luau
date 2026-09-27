--!strict
-- Services/Data/U4/RaceSection.luau — the U4.Race profile section (Update 4, 2026-09-25).
-- Pure: Update4Profile (the dispatcher) calls Default/Sanitize/Encode/Apply; commands arrive as
-- "U4.Race.<Op>" inside a race's single Commit (RaceRewards), so a race is recorded exactly when
-- it is paid, under the same operation id.
-- Fields (integers): BestMs / WeekBestMs are 0 for "none", else 2000..600000; WeekId / DayId are
-- RaceMath.WeekId / DayId; HourStart / HourCount are the rolling hour of rewarded races that
-- drives the hourly cap.
local RaceSection = {}

local MAX_COUNT = 1e9
-- 2026-09-25: 5000 (was 30000): races are 11-55 s now that the speed follows the Speed stat;
-- the same floor as U4.Race.Validation.MinPlausibleMs (test_u4_race_rewards checks it).
-- 2026-09-26 (owner: Sonic Dash speeds): 2000: a capped racer's best race is ~3-4.4 s.
local MIN_MS, MAX_MS = 2000, 600000
local FIELDS = { "BestMs", "WeekId", "WeekBestMs", "Races", "Finishes", "Wins", "Podiums", "Perfects", "DayId", "HourStart", "HourCount" }
local HOUR_SECONDS = 3600
local MAX_UNIX = 4102444800 -- 2100-01-01: anything later is corrupt

local function reject(message: string)
	return { ok = false, error = { code = "InvalidInput", message = message, retryable = false } }
end

local function isInteger(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge and value % 1 == 0
end

local function cleanCount(value: any, max: number): number
	local n = tonumber(value)
	if n == nil or n ~= n or n == math.huge or n == -math.huge then
		return 0
	end
	return math.clamp(math.floor(n), 0, max)
end

local function cleanMs(value: any): number
	local n = cleanCount(value, MAX_MS)
	return if n >= MIN_MS then n else 0
end

function RaceSection.Default(): { [string]: number }
	local state = {}
	for _, key in FIELDS do
		state[key] = 0
	end
	return state
end

function RaceSection.Sanitize(raw: any): { [string]: number }
	local state = RaceSection.Default()
	if type(raw) ~= "table" then
		return state
	end
	for _, key in FIELDS do
		if key == "BestMs" or key == "WeekBestMs" then
			state[key] = cleanMs(raw[key])
		elseif key == "HourStart" then
			state[key] = cleanCount(raw[key], MAX_UNIX)
		else
			state[key] = cleanCount(raw[key], MAX_COUNT)
		end
	end
	return state
end

function RaceSection.Encode(state: any): { [string]: number }
	-- A plain copy of the known fields (the dispatcher already passes a sanitized table).
	return RaceSection.Sanitize(state)
end

local function bump(state: any, key: string, by: number)
	state[key] = math.min(MAX_COUNT, cleanCount(state[key], MAX_COUNT) + by)
end

-- Record {finished, place (0..24), field (1..24), timeMs, rewarded, dayId, weekId, perfect}.
local function record(state: any, command: any, now: number)
	local place, field, timeMs = command.place, command.field, command.timeMs
	if not isInteger(place) or place < 0 or place > 24 then
		return reject("Invalid race place")
	end
	if not isInteger(field) or field < 1 or field > 24 then
		return reject("Invalid race field")
	end
	if not isInteger(timeMs) or timeMs < 0 or timeMs > MAX_MS * 10 then
		return reject("Invalid race time")
	end
	for _, key in { "finished", "rewarded", "perfect" } do
		if type(command[key]) ~= "boolean" then
			return reject("Invalid race flag " .. key)
		end
	end
	local dayId, weekId = command.dayId, command.weekId
	if not isInteger(dayId) or dayId < 0 or dayId > MAX_COUNT or not isInteger(weekId) or weekId < 0 or weekId > MAX_COUNT then
		return reject("Invalid race day or week")
	end
	if type(now) ~= "number" or now ~= now then
		return reject("Invalid clock")
	end

	bump(state, "Races", 1)
	if command.finished then
		bump(state, "Finishes", 1)
	end
	-- A win or podium only counts against real opponents (a Time Trial is a finish).
	if command.finished and place == 1 and field >= 2 then
		bump(state, "Wins", 1)
	end
	if command.finished and place >= 1 and place <= 3 and field >= 3 then
		bump(state, "Podiums", 1)
	end
	if command.perfect then
		bump(state, "Perfects", 1)
	end
	local valid = command.finished and timeMs >= MIN_MS and timeMs <= MAX_MS
	if valid then
		local best = cleanMs(state.BestMs)
		state.BestMs = if best == 0 then timeMs else math.min(best, timeMs)
	end
	if cleanCount(state.WeekId, MAX_COUNT) ~= weekId then
		state.WeekId = weekId
		state.WeekBestMs = 0
	end
	if valid then
		local weekBest = cleanMs(state.WeekBestMs)
		state.WeekBestMs = if weekBest == 0 then timeMs else math.min(weekBest, timeMs)
	end
	if command.rewarded then
		local nowSeconds = math.floor(now)
		local start = cleanCount(state.HourStart, MAX_UNIX)
		-- A start in the future (a bad clock or a corrupt save) opens a new window too.
		if nowSeconds - start >= HOUR_SECONDS or start > nowSeconds then
			state.HourStart = math.clamp(nowSeconds, 0, MAX_UNIX)
			state.HourCount = 0
		end
		bump(state, "HourCount", 1)
		state.DayId = math.max(cleanCount(state.DayId, MAX_COUNT), dayId)
	end
	return { ok = true, value = true }
end

function RaceSection.Apply(state: any, op: string, command: any, now: number)
	if type(state) ~= "table" or type(command) ~= "table" then
		return reject("Invalid race command")
	end
	if op == "Record" then
		return record(state, command, now)
	end
	return reject("Unknown race op " .. tostring(op))
end

-- For callers (RaceRewards): the hour count that still applies at `now`.
function RaceSection.HourCountAt(state: any, now: number): number
	if type(state) ~= "table" then
		return 0
	end
	local start = cleanCount(state.HourStart, MAX_UNIX)
	if math.floor(now) - start >= HOUR_SECONDS or start > math.floor(now) then
		return 0
	end
	return cleanCount(state.HourCount, MAX_COUNT)
end

return RaceSection
