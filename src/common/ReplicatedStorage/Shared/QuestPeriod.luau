--!strict
-- ReplicatedStorage/Shared/QuestPeriod.luau
-- M33 (2026-09-25): the quest day, and a finished quest that outlives it.
--
-- The quest day was midnight UTC while the Daily reward's day turns at 08:00 UTC; from
-- CUTOVER both turn at 08:00 UTC. At the cutover the period steps forward once (that day
-- lasts 8 h), so it never goes back and no saved Period is reused.
--
-- A quest finished before its day ended used to be lost at the day change: its counts were
-- replaced by the new day's before anyone paid it. Now the old day's counts judge it first
-- (FreezeCompletion, from ProfileReducers.QuestBucket), a new choice keeps it as LateDestiny
-- (SaveLate), and QuestService pays it once (ClaimLate, same operation id as a normal claim).
--
-- Pure: no requires, no game access (Lune-safe). ProfileReducers / ProfileCodec / QuestCatalog
-- read it; the integrator wires it into the reducers.

local QuestPeriod = {}

QuestPeriod.DAY = 86400
-- 2026-09-28 08:00 UTC.
QuestPeriod.CUTOVER = 1790582400
-- floor((t + 57600) / 86400): the day that begins at 08:00 UTC (57600 = 86400 - 8 h).
local OFFSET = 57600

local METRICS = { "speed", "stages", "wins", "playtime", "rebirth" }

local function finite(value: any): number?
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return nil
	end
	return value
end

function QuestPeriod.DailyPeriod(now: number): number
	local t = finite(now) or 0
	if t >= QuestPeriod.CUTOVER then
		return math.floor((t + OFFSET) / QuestPeriod.DAY)
	end
	return math.floor(t / QuestPeriod.DAY)
end

-- The first instant with a higher DailyPeriod than `now`'s.
function QuestPeriod.PeriodEnd(now: number): number
	local t = finite(now) or 0
	if t >= QuestPeriod.CUTOVER then
		return (math.floor((t + OFFSET) / QuestPeriod.DAY) + 1) * QuestPeriod.DAY - OFFSET
	end
	return math.min((math.floor(t / QuestPeriod.DAY) + 1) * QuestPeriod.DAY, QuestPeriod.CUTOVER)
end

-- The saved quest of a day, cleaned (was inline in ProfileCodec.sanitizeQuestState, moved as
-- it was) plus Complete: its tasks were all done before its day ended. nil for non-tables.
function QuestPeriod.SanitizeDestiny(destiny: any): any
	if type(destiny) ~= "table" then
		return nil
	end
	local clean: any = {
		Period = 0,
		Choice = 0,
		Targets = {},
		Baseline = {},
		Claimed = destiny.Claimed == true,
		Complete = destiny.Complete == true,
	}
	if type(destiny.Period) == "number" and destiny.Period == destiny.Period then
		clean.Period = math.clamp(math.floor(destiny.Period), 0, 1e10)
	end
	if type(destiny.Choice) == "number" and destiny.Choice == destiny.Choice then
		clean.Choice = math.clamp(math.floor(destiny.Choice), 0, 3)
	end
	for _, metric in METRICS do
		for _, field in { "Targets", "Baseline" } do
			local value = type(destiny[field]) == "table" and destiny[field][metric] or nil
			if type(value) == "number" and value == value then
				clean[field][metric] = math.clamp(value, 0, 1e50)
			end
		end
	end
	if type(destiny.ClaimedChoices) == "table" then
		local cleanedChoices = {}
		for k, v in destiny.ClaimedChoices do
			if v == true and (k == "1" or k == "2" or k == "3" or k == 1 or k == 2 or k == 3) then
				cleanedChoices[tostring(k)] = true
			end
		end
		clean.ClaimedChoices = cleanedChoices
	end
	return clean
end

-- Every task of `destiny` done according to the day bucket `daily`.
local function finishedIn(destiny: any, daily: any): boolean
	if type(destiny.Targets) ~= "table" or type(daily) ~= "table" then
		return false
	end
	local progress = if type(daily.Progress) == "table" then daily.Progress else {}
	local baseline = if type(destiny.Baseline) == "table" then destiny.Baseline else {}
	local count = 0
	for metric, target in destiny.Targets do
		count += 1
		if (tonumber(progress[metric]) or 0) - (tonumber(baseline[metric]) or 0) < (tonumber(target) or math.huge) then
			return false
		end
	end
	return count > 0
end

local function isOpenQuest(destiny: any): boolean
	return type(destiny) == "table" and (tonumber(destiny.Choice) or 0) ~= 0 and destiny.Claimed ~= true
end

-- Called with the Daily bucket that is about to be replaced: judges that day's chosen quest
-- against that day's counts. Once Complete it stays Complete.
function QuestPeriod.FreezeCompletion(profile: any, oldDailyBucket: any)
	local state = type(profile) == "table" and profile.QuestState
	local destiny = type(state) == "table" and state.Destiny
	if not isOpenQuest(destiny) or type(oldDailyBucket) ~= "table" or destiny.Period ~= oldDailyBucket.Period then
		return
	end
	destiny.Complete = destiny.Complete == true or finishedIn(destiny, oldDailyBucket)
end

-- Before a new choice replaces Destiny: an older, finished, unpaid quest is kept as LateDestiny.
function QuestPeriod.SaveLate(profile: any, now: number)
	local state = type(profile) == "table" and profile.QuestState
	local destiny = type(state) == "table" and state.Destiny
	if not isOpenQuest(destiny) or destiny.Complete ~= true then
		return
	end
	if (tonumber(destiny.Period) or 0) >= QuestPeriod.DailyPeriod(now) then
		return
	end
	state.LateDestiny = QuestPeriod.SanitizeDestiny(destiny)
end

local function reject()
	return { ok = false, error = { code = "InvalidInput", message = "Late quest is not claimable", retryable = false } }
end

-- Pays (marks) the unpaid, finished quest of an earlier day `command.period`: Destiny or
-- LateDestiny. A Destiny whose day bucket has not rolled yet is judged live against it (the
-- roll through questBucketFn then freezes it the same way). Marks it Claimed in both places it
-- may be kept, so a second call is refused; the rewards travel in the same transaction.
function QuestPeriod.ClaimLate(profile: any, command: any, now: number, questBucketFn: any?): any
	local period = type(command) == "table" and finite(command.period) or nil
	if type(profile) ~= "table" or not period or period % 1 ~= 0 or period >= QuestPeriod.DailyPeriod(now) then
		return reject()
	end
	local state = profile.QuestState
	if type(state) ~= "table" then
		return reject()
	end
	-- A day bucket that has not rolled yet judges its quest first; then roll it (the roll
	-- freezes Destiny the same way through ProfileReducers.QuestBucket).
	if type(state.Daily) == "table" and state.Daily.Period == period then
		QuestPeriod.FreezeCompletion(profile, state.Daily)
	end
	if type(questBucketFn) == "function" then
		pcall(questBucketFn, profile, "Daily", now)
	end
	local target = nil
	for _, key in { "LateDestiny", "Destiny" } do
		local candidate = state[key]
		if isOpenQuest(candidate) and candidate.Period == period and candidate.Complete == true then
			target = candidate
			break
		end
	end
	if not target then
		return reject()
	end
	local choice = tostring(target.Choice)
	for _, key in { "LateDestiny", "Destiny" } do
		local kept = state[key]
		if type(kept) == "table" and kept.Period == period then
			kept.Claimed = true
			kept.ClaimedChoices = if type(kept.ClaimedChoices) == "table" then kept.ClaimedChoices else {}
			kept.ClaimedChoices[choice] = true
		end
	end
	if type(state.LateDestiny) == "table" and state.LateDestiny.Period == period then
		state.LateDestiny = nil
	end
	return { ok = true, value = { period = period, choice = target.Choice } }
end

-- The unpaid, finished quest of an earlier day, if any (QuestService: what claimLate pays).
-- `daily` counts are used for a Destiny whose day bucket has not rolled yet.
function QuestPeriod.FindLate(questState: any, now: number): any
	if type(questState) ~= "table" then
		return nil
	end
	local current = QuestPeriod.DailyPeriod(now)
	for _, key in { "LateDestiny", "Destiny" } do
		local candidate = questState[key]
		if isOpenQuest(candidate) and (tonumber(candidate.Period) or current) < current then
			local daily = questState.Daily
			if candidate.Complete == true
				or (type(daily) == "table" and daily.Period == candidate.Period and finishedIn(candidate, daily)) then
				return candidate
			end
		end
	end
	return nil
end

return QuestPeriod
