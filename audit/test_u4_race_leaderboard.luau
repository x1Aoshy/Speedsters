-- test_u4_race_leaderboard.luau (Update 4, race_server, 2026-09-25)
-- Services/Race/RaceLeaderboard on fake ordered stores (PLAN §7.3 item 9):
--   WeekId boundaries on Monday 00:00 UTC; min-only UpdateAsync (a slower time cancels the
--   write); personal bests coalesced per player; <= 20 UpdateAsync calls per flush; Studio's
--   refusal turns the boards off quietly; SessionDataOnly / implausible times never written;
--   ranks only for the top 50; the weekly #1 on Workspace; Board answers at most every 2 s.
-- Run: lune run audit/test_u4_race_leaderboard.luau   (from the project root)
local RaceLeaderboard = require("../src/common/ServerScriptService/Services/Race/RaceLeaderboard")
local RaceMath = require("../src/common/ReplicatedStorage/Shared/RaceMath")
local U4 = require("../src/common/ReplicatedStorage/Shared/Update4Config")

local passed = 0
local function pass(text)
	passed += 1
	print("PASS " .. text)
end

-- An ordered store: UpdateAsync runs the transform; GetSortedAsync(ascending, n) pages.
local function newStore(name)
	local store = { name = name, data = {}, calls = 0, fail = nil }
	function store:UpdateAsync(key, transform)
		self.calls += 1
		if self.fail then
			error(self.fail)
		end
		local result = transform(self.data[key])
		if result ~= nil then
			self.data[key] = result
		end
		return result
	end
	function store:GetSortedAsync(ascending, size)
		if self.fail then
			error(self.fail)
		end
		local rows = {}
		for key, value in self.data do
			table.insert(rows, { key = key, value = value })
		end
		table.sort(rows, function(a, b)
			if ascending then
				return a.value < b.value
			end
			return a.value > b.value
		end)
		local page = {}
		for i = 1, math.min(size, #rows) do
			page[i] = rows[i]
		end
		return { GetCurrentPage = function() return page end }
	end
	return store
end

local function newPlayer(userId, attrs)
	attrs = attrs or {}
	return { UserId = userId, Name = "P" .. userId, attrs = attrs, GetAttribute = function(_, k) return attrs[k] end, SetAttribute = function(_, k, v) attrs[k] = v end }
end

local function setup(isStudio)
	local now, clock = 1728259200, 0 -- Monday 2024-10-07 00:00 UTC
	local world, fired = {}, {}
	local allTime = newStore("all")
	local weeks = {}
	local players = {}
	local board = RaceLeaderboard.new({
		allTimeStore = allTime,
		weeklyStore = function(week)
			weeks[week] = weeks[week] or newStore("W" .. week)
			return weeks[week]
		end,
		unix = function() return now end,
		clock = function() return clock end,
		wait = function() end,
		isStudio = isStudio,
		userNames = function(ids)
			local out = {}
			for _, id in ids do
				out[id] = "Name" .. id
			end
			return out
		end,
		players = function() return players end,
		setWorld = function(k, v) world[k] = v end,
		fire = function(player, payload) table.insert(fired, { player, payload }) end,
	})
	return {
		board = board, allTime = allTime, weeks = weeks, world = world, fired = fired, players = players,
		setNow = function(t) now = t end, setClock = function(t) clock = t end, now = function() return now end,
	}
end

do
	local monday = 1728259200
	assert(RaceMath.WeekId(monday) == RaceMath.WeekId(monday + 7 * 86400 - 1), "one week = Monday 00:00 to Sunday 23:59:59 UTC")
	assert(RaceMath.WeekId(monday - 1) == RaceMath.WeekId(monday) - 1, "Sunday 23:59:59 is the week before")
	assert(os.date("!%A %H:%M", monday) == "Monday 00:00", "the boundary is a Monday at 00:00 UTC")
	pass("WeekId boundaries on Monday 00:00 UTC")
end

do
	local env = setup(false)
	local week = RaceMath.WeekId(env.now())
	local p = newPlayer(1)
	assert(env.board:Submit(p, 35000, week) and env.board:Submit(p, 34000, week) and env.board:Submit(p, 36000, week), "PBs queued")
	assert(env.board:Flush() == 2, "coalesced: one write per board per player")
	assert(env.allTime.data.U_1 == 34000 and env.weeks[week].data.U_1 == 34000, "the fastest queued time is written")
	env.board:Submit(p, 34500, week)
	env.board:Flush()
	assert(env.allTime.data.U_1 == 34000 and env.weeks[week].data.U_1 == 34000, "min-only: a slower time cancels the write")
	assert(not env.board:Submit(newPlayer(2, { SessionDataOnly = true }), 31000, week), "SessionDataOnly never reaches the boards")
	-- 2026-09-25: the record floor is U4.Race.Validation.MinPlausibleMs (5000) now that races are 11-55 s.
	assert(not env.board:Submit(p, U4.Race.Validation.MinPlausibleMs - 1, week) and not env.board:Submit(p, 0 / 0, week) and not env.board:Submit(p, 700000, week), "implausible times refused")
	for id = 100, 160 do
		env.board:Submit(newPlayer(id), 30000 + id, week)
	end
	local calls = env.board:Flush()
	assert(calls == U4.Race.Leaderboard.MaxWritesPerFlush, "at most 20 writes per flush (" .. calls .. ")")
	local total = calls
	while true do
		local c = env.board:Flush()
		if c == 0 then
			break
		end
		assert(c <= 20, "every flush <= 20")
		total += c
	end
	assert(total == 61 * 2, "everything is written over several flushes")
	-- An old week is closed.
	env.board:Submit(p, 33000, week - 3)
	local before = env.weeks[week - 3]
	env.board:Flush()
	assert(before == nil and env.weeks[week - 3] == nil and env.allTime.data.U_1 == 33000, "a week that ended long ago is not written, all-time is")
	pass("Submit/Flush: coalesced, min-only, <= 20 writes per flush, SessionDataOnly and implausible refused, closed weeks")
end

do
	local env = setup(false)
	local week = RaceMath.WeekId(env.now())
	for id = 1, 60 do
		env.board:Submit(newPlayer(id), 30000 + id * 10, week)
	end
	while env.board:Flush() > 0 do end
	local inside, outside = newPlayer(3), newPlayer(55)
	table.insert(env.players, inside)
	table.insert(env.players, outside)
	assert(env.board:Read(), "read both boards")
	assert(#env.board.weekly == 50 and #env.board.allTime == 50 and env.board.weekly[1].UserId == 1 and env.board.weekly[1].Name == "Name1", "top 50, ascending, named")
	assert(inside.attrs.RaceWeeklyRank == 3 and inside.attrs.RaceAllTimeRank == 3, "a top-50 player gets ranks")
	assert(outside.attrs.RaceWeeklyRank == nil and outside.attrs.RaceAllTimeRank == nil, "no rank outside the top 50")
	assert(env.world.RaceRecordMs == 30010 and env.world.RaceRecordName == "Name1", "weekly #1 on Workspace for the gate sign")
	inside.attrs.RaceBestMs = 30030
	local payload = env.board:Board(inside)
	assert(payload and payload.kind == "Board" and payload.you.weeklyRank == 3 and payload.you.bestMs == 30030 and #env.fired == 1, "Board answer")
	env.setClock(1.9)
	assert(env.board:Board(inside) == nil and #env.fired == 1, "at most one Board answer per 2 s")
	env.setClock(2.1)
	assert(env.board:Board(inside) ~= nil, "...then again")
	-- New week: the weekly board starts empty.
	env.setNow(env.now() + 7 * 86400)
	env.board:Read()
	assert(#env.board.weekly == 0 and env.world.RaceRecordMs == nil and #env.board.allTime == 50, "a new week starts an empty weekly board")
	pass("Read: top 50 ascending with names, ranks only in the top 50, weekly record on Workspace, Board rate limit, week rollover")
end

do
	local env = setup(true)
	local week = RaceMath.WeekId(env.now())
	env.allTime.fail = "StudioAccessToApisNotAllowed: Studio access to APIs is not allowed"
	env.weeks[week] = newStore("w")
	env.weeks[week].fail = env.allTime.fail
	env.board:Submit(newPlayer(1), 35000, week)
	env.board:Submit(newPlayer(2), 35000, week)
	local calls = env.board:Flush()
	assert(env.board.studioBlocked and calls == 1 and env.allTime.calls == 1, "Studio's refusal stops the boards at the first call")
	assert(not env.board:Submit(newPlayer(3), 35000, week) and env.board:Flush() == 0 and not env.board:Read(), "...quietly, for the session")
	-- A live server keeps retrying (3 attempts) and never blocks.
	local live = setup(false)
	live.allTime.fail = "503"
	live.board:Submit(newPlayer(1), 35000, week)
	live.board:Flush()
	assert(not live.board.studioBlocked and live.allTime.calls == 3, "live errors: 3 retries, never switched off")
	pass("Studio refusal disables the boards quietly; live errors retry 3 times")
end

print(string.format("test_u4_race_leaderboard: %d checks passed", passed))
