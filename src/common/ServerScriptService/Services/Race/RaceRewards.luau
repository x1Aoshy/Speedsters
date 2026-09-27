-- Services/Race/RaceRewards.luau — Update 4 (2026-09-25): pays one racer for one race.
-- One DataService.Commit per racer per race (operation id race:<JobId>:<raceId>:<userId>, the
-- same id on every retry), carrying the Wins, the Speed, the first-race-of-the-day Spin Ticket,
-- the U4.Race.Record that updates the racer's stats, and any race title just earned. A retry
-- after "Pending" or a second call for the same race answers AlreadyCommitted: never paid twice.
-- The amounts are RaceMath.ComputeRewards (PLAN §3.4): a winner earns 6 % of the world's lap
-- (World 1 scaled by progress toward World 2), about 2 laps an hour at most thanks to the
-- 30-races-an-hour cap.
local U4 = if typeof(script) == "Instance"
	then require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Update4Config", 10))
	else require("../../../ReplicatedStorage/Shared/Update4Config")
local RaceMath = if typeof(script) == "Instance"
	then require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("RaceMath", 10))
	else require("../../../ReplicatedStorage/Shared/RaceMath")
local RaceSection = if typeof(script) == "Instance"
	then require(script.Parent.Parent:WaitForChild("Data"):WaitForChild("U4"):WaitForChild("RaceSection", 10))
	else require("../Data/U4/RaceSection")

local RACE = U4.Race
local COMMIT_RETRIES = 5
-- 2026-09-25 (final fix, H3): a commit still Pending after COMMIT_RETRIES (a save being
-- retried) is not dropped: the same operation id is tried again every LATE_RETRY_SECONDS, up to
-- LATE_RETRIES times, while the player stays. When the race's own write was the one pending, the
-- retry answers AlreadyCommitted once it lands; when an older write blocked it, the retry is
-- what finally applies the race.
local LATE_RETRY_SECONDS = 20
local LATE_RETRIES = 30

local RaceRewards = {}
RaceRewards.__index = RaceRewards

-- deps = {
--   DataService,                       -- GetHandle / Inspect / Commit
--   config = { LapWins, SpeedFloor, SpeedShare, World2UnlockRebirths },
--   world = "World1" | "World2" | "World3",
--   jobId = game.JobId,
--   unix = os.time, wait = task.wait,
--   winsMultiplier = (player) -> number   (_G.SpeedsterGetWinsMultiplier),
--   hasSection = (name) -> boolean        (Update4Profile.HasSection),
--   titlesRefresh = (player) -> ()        (_G.SpeedsterTitles.Refresh),
--   spawn = task.spawn, isPresent = (player) -> boolean   (optional: the late retries of H3),
-- }
function RaceRewards.new(deps)
	local self = setmetatable({}, RaceRewards)
	self.deps = deps
	return self
end

local function number(value, default)
	local n = tonumber(value)
	if n == nil or n ~= n or n == math.huge or n == -math.huge then
		return default
	end
	return n
end

function RaceRewards:_unix()
	return if self.deps.unix then self.deps.unix() else os.time()
end

function RaceRewards:_hasSection(name)
	if self.deps.hasSection then
		local ok, has = pcall(self.deps.hasSection, name)
		return ok and has == true
	end
	return true
end

-- The live profile view of a player: handle, profile, sanitized U4.Race (nil when not loaded).
function RaceRewards:Read(player)
	local DataService = self.deps.DataService
	local handle = DataService and DataService.GetHandle(player)
	if not handle then
		return nil
	end
	local ok, view = pcall(DataService.Inspect, handle)
	if not ok or type(view) ~= "table" or not view.ok or type(view.value) ~= "table" then
		return nil
	end
	local profile = view.value.profile or view.value
	local u4 = type(profile) == "table" and profile.U4
	local raceState = RaceSection.Sanitize(type(u4) == "table" and u4.Race or nil)
	return { handle = handle, profile = profile, race = raceState }
end

-- True when the next rewarded race would be this UTC day's first (x2 + a Spin Ticket).
function RaceRewards:IsDailyFirst(player, read)
	if not self:_hasSection("Race") then
		return false -- without the section nothing would record the day: never double forever
	end
	local data = read or self:Read(player)
	return data ~= nil and data.race.DayId < RaceMath.DayId(self:_unix())
end

-- 2026-09-25 (final fix): the same answer from the projected attributes (RaceDayId, set by
-- Project/Pay) without Inspect's deep copy: staging asks it for up to 16 racers in one tick.
-- nil while nothing has been projected yet (the caller then falls back to IsDailyFirst).
function RaceRewards:IsDailyFirstProjected(player)
	if not self:_hasSection("Race") then
		return false
	end
	local ok, dayId = pcall(function()
		return player:GetAttribute("RaceDayId")
	end)
	if not ok or type(dayId) ~= "number" then
		return nil
	end
	return dayId < RaceMath.DayId(self:_unix())
end

local function publish(player, race, week)
	pcall(function()
		player:SetAttribute("RaceBestMs", race.BestMs)
		player:SetAttribute("RaceWeekBestMs", if race.WeekId == week then race.WeekBestMs else 0)
		player:SetAttribute("RaceWins", race.Wins)
		player:SetAttribute("RaceFinishes", race.Finishes)
		-- 2026-09-25 (final fix): read back by staging (daily x2) and Join (onboarding step)
		-- instead of an Inspect per racer.
		player:SetAttribute("RaceRaces", race.Races)
		player:SetAttribute("RaceDayId", race.DayId)
	end)
end

-- Publishes the race stats on the player (join, and after each paid race).
function RaceRewards:Project(player, read)
	local data = read or self:Read(player)
	if not data then
		return nil
	end
	local race = data.race
	publish(player, race, RaceMath.WeekId(self:_unix()))
	return race
end

-- outcome = { raceId, place (finish place, 0 when not finished), finished, dq, progress (0..1),
--   solo, n (racers at GO), timeMs, perfect, eventMultiplier }
function RaceRewards:Prepare(player, outcome, read)
	local data = read or self:Read(player)
	if not data then
		return nil, "NoSession"
	end
	local config = self.deps.config or {}
	local now = self:_unix()
	local today, week = RaceMath.DayId(now), RaceMath.WeekId(now)
	local race = data.race
	local finished = outcome.finished == true and outcome.dq ~= true
	local place = if finished then math.clamp(math.floor(number(outcome.place, 0)), 0, 24) else 0
	local n = math.clamp(math.floor(number(outcome.n, 1)), 1, 24)
	local winsMultiplier = 1
	if self.deps.winsMultiplier then
		local ok, value = pcall(self.deps.winsMultiplier, player)
		winsMultiplier = if ok then math.max(1, number(value, 1)) else 1
	end
	local rewards = RaceMath.ComputeRewards({
		place = place,
		finished = finished,
		dq = outcome.dq == true,
		progress = number(outcome.progress, 0),
		solo = outcome.solo == true,
		n = n,
		lapWins = number(config.LapWins and config.LapWins[self.deps.world or "World1"], 0),
		world = self.deps.world,
		rebirths = number(data.profile.Rebirths, 0),
		unlockRebirths = number(config.World2UnlockRebirths, 6),
		eventMultiplier = number(outcome.eventMultiplier, 1),
		dailyFirst = self:IsDailyFirst(player, data),
		hourCount = RaceSection.HourCountAt(race, now),
		winsMultiplier = winsMultiplier,
		rawSpeed = number(data.profile.Speed, 0),
		speedFloor = number(config.SpeedFloor, 500),
		speedShare = number(config.SpeedShare, 0.005),
	})
	local timeMs = if finished then math.clamp(math.floor(number(outcome.timeMs, 0)), 0, 6000000) else 0
	local perfect = outcome.perfect == true
	local commands = {}
	if rewards.wins > 0 then
		table.insert(commands, { kind = "GrantExact", stat = "Wins", amount = rewards.wins })
	end
	if rewards.speed > 0 then
		table.insert(commands, { kind = "GrantExact", stat = "Speed", amount = rewards.speed })
	end
	if rewards.tickets > 0 then
		table.insert(commands, { kind = "GrantSpinTickets", amount = rewards.tickets })
	end
	local titles = {}
	local after = table.clone(race)
	if self:_hasSection("Race") then
		local record = {
			kind = "U4.Race.Record",
			finished = finished,
			place = place,
			field = n,
			timeMs = timeMs,
			rewarded = rewards.rewarded,
			dayId = today,
			weekId = week,
			perfect = perfect,
		}
		table.insert(commands, record)
		RaceSection.Apply(after, "Record", record, now)
		-- Race titles reached with this race (U4.Race.Titles), granted in the same Commit.
		if self:_hasSection("Titles") then
			for need, id in RACE.Titles.WinTitles do
				if race.Wins < need and after.Wins >= need then
					table.insert(titles, id)
				end
			end
			local perfectTitle = RACE.Titles.PerfectTitle
			if race.Perfects < perfectTitle.Count and after.Perfects >= perfectTitle.Count then
				table.insert(titles, perfectTitle.Id)
			end
			table.sort(titles)
			for _, id in titles do
				table.insert(commands, { kind = "U4.Titles.Grant", id = id })
			end
		end
	end
	local weekBefore = if race.WeekId == week then race.WeekBestMs else 0
	local valid = finished and timeMs >= RaceMath.MinPlausibleMs
	return {
		userId = player.UserId,
		handle = data.handle,
		rewards = rewards,
		commands = commands,
		titles = titles,
		before = race,
		after = after,
		timeMs = timeMs,
		weekId = week,
		pb = valid and (race.BestMs == 0 or timeMs < race.BestMs),
		weeklyPb = valid and (weekBefore == 0 or timeMs < weekBefore),
		operationId = string.format("race:%s:%s:%d", tostring(self.deps.jobId or "local"), tostring(outcome.raceId), player.UserId),
		fingerprint = "race:" .. tostring(outcome.raceId),
	}
end

-- Commits a prepared plan; retries "Pending" with the same id. Returns kind.
function RaceRewards:Commit(plan, retries)
	local DataService = self.deps.DataService
	if #plan.commands == 0 then
		return "Nothing"
	end
	local kind = "Rejected"
	local maxRetries = if type(retries) == "number" then retries else COMMIT_RETRIES
	for attempt = 1, maxRetries + 1 do
		local ok, result = pcall(DataService.Commit, plan.handle, {
			operationId = plan.operationId,
			fingerprint = plan.fingerprint,
			commands = plan.commands,
		})
		kind = if ok and type(result) == "table" then result.kind else "Rejected"
		if kind ~= "Pending" or attempt > maxRetries then
			if kind == "Rejected" and ok and type(result) == "table" and result.error then
				warn("[RaceRewards] race reward rejected: " .. tostring(result.error.message))
			end
			break
		end
		if self.deps.wait then
			self.deps.wait(1)
		end
	end
	return kind
end

function RaceRewards:_paid(player, plan)
	publish(player, plan.after, plan.weekId)
	if #plan.titles > 0 and self.deps.titlesRefresh then
		pcall(self.deps.titlesRefresh, player)
	end
end

function RaceRewards:_retryLate(player, plan)
	local deps = self.deps
	if type(deps.spawn) ~= "function" or type(deps.wait) ~= "function" then
		return false
	end
	deps.spawn(function()
		for _ = 1, LATE_RETRIES do
			deps.wait(LATE_RETRY_SECONDS)
			if deps.isPresent and not deps.isPresent(player) then
				return
			end
			local kind = self:Commit(plan, 0)
			if kind == "Committed" or kind == "AlreadyCommitted" then
				self:_paid(player, plan)
				return
			elseif kind ~= "Pending" then
				return
			end
		end
		warn("[RaceRewards] race reward still pending after the late retries: " .. plan.operationId)
	end)
	return true
end

-- Prepare + Commit + publish. Returns a result table (always), ok = paid (or already paid).
function RaceRewards:Pay(player, outcome, plan)
	plan = plan or self:Prepare(player, outcome)
	if not plan then
		return { ok = false, kind = "NoSession", wins = 0, speed = 0, tickets = 0, pb = false, weeklyPb = false }
	end
	local kind = self:Commit(plan)
	local ok = kind == "Committed" or kind == "AlreadyCommitted" or kind == "Nothing"
	local rewards = plan.rewards
	local result = {
		ok = ok,
		kind = kind,
		rewarded = rewards.rewarded == true,
		retrying = kind == "Pending" and self:_retryLate(player, plan),
		wins = if ok then rewards.wins else 0,
		speed = if ok then rewards.speed else 0,
		tickets = if ok then rewards.tickets else 0,
		capReduced = rewards.capReduced,
		multiplier = rewards.multiplier,
		pb = ok and plan.pb,
		weeklyPb = ok and plan.weeklyPb,
		timeMs = plan.timeMs,
		weekId = plan.weekId,
		titles = if ok then plan.titles else {},
		stats = if ok then plan.after else plan.before,
	}
	if ok then
		self:_paid(player, plan)
	end
	return result
end

return RaceRewards
