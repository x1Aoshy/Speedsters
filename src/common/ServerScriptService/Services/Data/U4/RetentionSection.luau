--!strict
-- Services/Data/U4/RetentionSection.luau — profile section U4.Retention (Update 4 Playtime
-- Boost + Streak Rewards, PLAN §2.2 / §7.7), dispatched by Services/Data/Update4Profile.
-- Pure: the rules live in Shared/RetentionMath so the service, the panels and the tests use
-- the same code.
--   CheckIn {day}      one per UTC day (operation id u4streak:<day>); day must be today.
--   ClaimStreak {key}  the key must be pending; moved to Claimed; the perk only ever grows.
--   Playtime {seconds, lastSeen, sessionStart}  volatile (DataService.ApplyVolatile), clamped.
local RetentionMath = if typeof(script) == "Instance"
	then require(game:GetService("ReplicatedStorage"):WaitForChild("Shared", 5):WaitForChild("RetentionMath", 5) :: ModuleScript)
	else require("../../../../ReplicatedStorage/Shared/RetentionMath")
-- The shipped config when it loads; RetentionMath's defaults (the same numbers) otherwise, so
-- a missing Update4Config never takes a player's streak down with it.
local U4 = (function(): any
	local ok, config = pcall(function(): any
		if typeof(script) == "Instance" then
			local shared = game:GetService("ReplicatedStorage"):FindFirstChild("Shared")
			local module = shared and shared:FindFirstChild("Update4Config")
			return if module then (require :: any)(module) else nil
		end
		return (require :: any)("../../../../ReplicatedStorage/Shared/Update4Config")
	end)
	return if ok and type(config) == "table" then config else {}
end)()
local STREAK = U4.Streak or RetentionMath.DefaultStreak
local PLAYTIME = U4.Playtime or RetentionMath.DefaultPlaytime

local RetentionSection = {}

local MAX_DAY = 10000000 -- far past any real UTC day number (20 500 in 2026)
local MAX_UNIX = 4102444800 -- 2100-01-01

local function reject(message: string)
	return { ok = false, error = { code = "InvalidInput", message = message, retryable = false } }
end

local function finite(value: any): number?
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return nil
	end
	return value
end

local function int(value: any, maxValue: number): number
	local n = finite(value)
	if not n then
		return 0
	end
	return math.clamp(math.floor(n), 0, maxValue)
end

-- Unique well-formed keys, newest kept when over `limit`.
local function keyList(raw: any, limit: number): { string }
	local out, seen = {}, {}
	if type(raw) ~= "table" then
		return out
	end
	for _, key in ipairs(raw) do
		if RetentionMath.ParseKey(key) and not seen[key] then
			seen[key] = true
			table.insert(out, key)
		end
		if #out > 4 * limit then
			break -- a list thousands long is junk; the newest few are kept below
		end
	end
	while #out > limit do
		table.remove(out, 1)
	end
	return out
end

function RetentionSection.Default(): { [string]: any }
	return {
		StreakDays = 0, StreakLastDay = 0, StreakBest = 0, StreakGraceDay = 0, StreakPerk = 0,
		StreakPending = {}, StreakClaimed = {},
		PlaytimeSeconds = 0, PlaytimeLastSeen = 0, PlaytimeSessionStart = 0,
	}
end

-- Never throws: wrong types, NaN, negatives and overlong lists are cleaned.
function RetentionSection.Sanitize(raw: any): { [string]: any }
	local s = if type(raw) == "table" then raw else {}
	local clean = RetentionSection.Default()
	clean.StreakDays = int(s.StreakDays, MAX_DAY)
	clean.StreakLastDay = int(s.StreakLastDay, MAX_DAY)
	clean.StreakBest = math.max(int(s.StreakBest, MAX_DAY), clean.StreakDays)
	clean.StreakGraceDay = int(s.StreakGraceDay, MAX_DAY)
	local perk = finite(s.StreakPerk) or 0
	clean.StreakPerk = math.clamp(perk, 0, RetentionMath.MaxPerk)
	clean.StreakClaimed = keyList(s.StreakClaimed, math.max(1, tonumber(STREAK.MaxClaimedKept) or 64))
	-- A key claimed once is never pending again, even one past the 64 kept.
	local claimed = {}
	for _, key in (if type(s.StreakClaimed) == "table" then s.StreakClaimed else {}) :: any do
		if type(key) == "string" then
			claimed[key] = true
		end
	end
	local pending = {}
	for _, key in keyList(s.StreakPending, math.max(1, tonumber(STREAK.MaxPending) or 6)) do
		if not claimed[key] then
			table.insert(pending, key)
		end
	end
	clean.StreakPending = pending
	clean.PlaytimeSeconds = math.clamp(finite(s.PlaytimeSeconds) or 0, 0, RetentionMath.PlaytimeMaxSeconds(PLAYTIME))
	clean.PlaytimeLastSeen = int(s.PlaytimeLastSeen, MAX_UNIX)
	clean.PlaytimeSessionStart = int(s.PlaytimeSessionStart, MAX_UNIX)
	return clean
end

function RetentionSection.Encode(state: any): { [string]: any }
	-- A plain copy through Sanitize: what reaches the DataStore is always well formed.
	return RetentionSection.Sanitize(state)
end

local function assign(state: any, fields: { [string]: any })
	for key, value in fields do
		state[key] = value
	end
end

function RetentionSection.Apply(state: any, op: string, command: any, now: number)
	if type(state) ~= "table" or type(command) ~= "table" then
		return reject("Invalid retention command")
	end
	local nowUnix = finite(now) or 0
	if op == "CheckIn" then
		local day = finite(command.day)
		if not day or day % 1 ~= 0 or day ~= RetentionMath.UtcDay(nowUnix) then
			return reject("Check-in day is not today")
		end
		local current = RetentionSection.Sanitize(state)
		local nextState, event, crossed = RetentionMath.StreakCheckIn(current, day, STREAK)
		assign(state, nextState)
		return { ok = true, value = { event = event, days = nextState.StreakDays, keys = crossed } }
	elseif op == "ClaimStreak" then
		local key = command.key
		local reward = RetentionMath.MilestoneReward(key, STREAK)
		if not reward then
			return reject("Unknown streak reward")
		end
		local pending = if type(state.StreakPending) == "table" then state.StreakPending else {}
		local index = table.find(pending, key)
		if not index then
			return reject("Streak reward is not pending")
		end
		table.remove(pending, index)
		state.StreakPending = pending
		local claimed = if type(state.StreakClaimed) == "table" then state.StreakClaimed else {}
		if not table.find(claimed, key) then
			table.insert(claimed, key)
		end
		while #claimed > math.max(1, tonumber(STREAK.MaxClaimedKept) or 64) do
			table.remove(claimed, 1)
		end
		state.StreakClaimed = claimed
		local perk = finite(state.StreakPerk) or 0
		state.StreakPerk = math.clamp(math.max(perk, reward.Perk), 0, RetentionMath.MaxPerk)
		return { ok = true, value = reward }
	elseif op == "Playtime" then
		local seconds, lastSeen, sessionStart = finite(command.seconds), finite(command.lastSeen), finite(command.sessionStart)
		if not seconds or not lastSeen or not sessionStart then
			return reject("Invalid playtime")
		end
		-- The server's own clock, never ahead of it by more than a minute.
		local ceiling = math.clamp(nowUnix + 60, 0, MAX_UNIX)
		state.PlaytimeSeconds = math.clamp(seconds, 0, RetentionMath.PlaytimeMaxSeconds(PLAYTIME))
		state.PlaytimeLastSeen = math.clamp(math.floor(lastSeen), 0, ceiling)
		state.PlaytimeSessionStart = math.clamp(math.floor(sessionStart), 0, ceiling)
		return { ok = true, value = state.PlaytimeSeconds }
	end
	return reject("Unknown retention command")
end

return RetentionSection
