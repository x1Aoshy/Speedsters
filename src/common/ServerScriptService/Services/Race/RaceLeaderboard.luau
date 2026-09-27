-- Services/Race/RaceLeaderboard.luau — Update 4 (2026-09-25): fastest race times.
-- Two ordered stores, ascending (lower ms = better), key U_<userId>:
--   all-time  U4.Race.Leaderboard.AllTimeStore   (also the lobby "FASTEST RACERS" board)
--   weekly    WeeklyPrefix .. RaceMath.WeekId(now) (weeks start Monday 00:00 UTC)
-- Only validated personal bests are written, coalesced per player (the fastest wins), at most
-- MaxWritesPerFlush UpdateAsync calls every FlushSeconds, and each write is min-only: the
-- transform cancels (returns nil) when the stored time is already as fast. Both tops are read
-- every ReadSeconds; the weekly #1 goes on the Race Gate sign (Workspace RaceRecordMs/Name).
-- Stores and clocks are injected so audit/test_u4_race_leaderboard runs it on fakes.
local U4 = if typeof(script) == "Instance"
	then require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Update4Config", 10))
	else require("../../../ReplicatedStorage/Shared/Update4Config")
local RaceMath = if typeof(script) == "Instance"
	then require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("RaceMath", 10))
	else require("../../../ReplicatedStorage/Shared/RaceMath")

local SETTINGS = U4.Race.Leaderboard
local RETRIES = 3
local MAX_MS = 600000

local RaceLeaderboard = {}
RaceLeaderboard.__index = RaceLeaderboard

-- deps = {
--   allTimeStore = OrderedDataStore, weeklyStore = (weekId) -> OrderedDataStore,
--   unix = os.time, clock = os.clock, wait = task.wait, isStudio = boolean,
--   userNames = ({userId}) -> {[userId] = name}, players = () -> {Player},
--   setWorld = (name, value) -> (), fire = (player, payload) -> (),
--   setBoardRanks = (boardId, userIds) -> ()?  (2026-09-26: TitleService.SetBoardRanks)
-- }
function RaceLeaderboard.new(deps)
	local self = setmetatable({}, RaceLeaderboard)
	self.deps = deps
	self.pendingAll = {} -- [userId] = ms
	self.pendingWeek = {} -- [weekId] = { [userId] = ms }
	self.order = {} -- FIFO of pending writes { store = "all" | weekId, userId }
	self.allTime = {}
	self.weekly = {}
	self.weekRead = nil
	self.studioBlocked = false
	self.lastBoard = setmetatable({}, { __mode = "k" })
	return self
end

function RaceLeaderboard.Key(userId)
	return "U_" .. tostring(userId)
end

local function userIdFromKey(key)
	local matched = string.match(tostring(key or ""), "^U_(%d+)$")
	return matched and tonumber(matched) or nil
end

local function cleanMs(value)
	local n = tonumber(value)
	if n == nil or n ~= n or n == math.huge then
		return 0
	end
	n = math.floor(n)
	return if n >= RaceMath.MinPlausibleMs and n <= MAX_MS then n else 0
end

-- Copied from GlobalLeaderboards (Studio without API access): stop asking for the session.
function RaceLeaderboard:_noteRefusal(err)
	if not self.deps.isStudio or self.studioBlocked then
		return
	end
	local message = tostring(err)
	if string.find(message, "Studio access to APIs is not allowed", 1, true)
		or string.find(message, "API access is not enabled", 1, true)
		or string.find(message, "StudioAccessToApisNotAllowed", 1, true)
	then
		self.studioBlocked = true
		self.pendingAll, self.pendingWeek, self.order = {}, {}, {}
		warn("[RaceLeaderboard] Studio has no DataStore access, so race boards are off for this session. "
			.. "Enable it in Game Settings > Security > Enable Studio Access to API Services.")
	end
end

-- Queues a validated personal best. Returns true when queued.
function RaceLeaderboard:Submit(player, ms, weekId)
	if self.studioBlocked then
		return false
	end
	local ok, sessionOnly = pcall(function()
		return player:GetAttribute("SessionDataOnly") == true
	end)
	if not ok or sessionOnly then
		return false -- a session without a real save never reaches the public boards
	end
	local clean = cleanMs(ms)
	local userId = tonumber(player.UserId)
	if clean == 0 or not userId or userId <= 0 then
		return false
	end
	local week = math.floor(tonumber(weekId) or RaceMath.WeekId(self.deps.unix()))
	if not self.pendingAll[userId] then
		table.insert(self.order, { store = "all", userId = userId })
	end
	self.pendingAll[userId] = math.min(self.pendingAll[userId] or math.huge, clean)
	self.pendingWeek[week] = self.pendingWeek[week] or {}
	if not self.pendingWeek[week][userId] then
		table.insert(self.order, { store = week, userId = userId })
	end
	self.pendingWeek[week][userId] = math.min(self.pendingWeek[week][userId] or math.huge, clean)
	return true
end

-- Min-only write; returns true when the call went through (written or cancelled as no PB).
function RaceLeaderboard:_write(store, userId, ms)
	local lastError = nil
	for attempt = 1, RETRIES do
		local ok, err = pcall(function()
			store:UpdateAsync(RaceLeaderboard.Key(userId), function(current)
				local stored = tonumber(current)
				if stored and stored > 0 and stored <= ms then
					return nil -- not a personal best on this board: cancel the write
				end
				return ms
			end)
		end)
		if ok then
			return true
		end
		lastError = err
		self:_noteRefusal(err)
		if self.studioBlocked then
			return false
		end
		if attempt < RETRIES and self.deps.wait then
			self.deps.wait(attempt)
		end
	end
	warn("[RaceLeaderboard] write failed: " .. tostring(lastError))
	return false
end

-- Writes up to MaxWritesPerFlush pending bests. Returns the number of UpdateAsync calls made.
function RaceLeaderboard:Flush()
	if self.studioBlocked then
		return 0
	end
	local currentWeek = RaceMath.WeekId(self.deps.unix())
	local calls = 0
	while #self.order > 0 and calls < SETTINGS.MaxWritesPerFlush do
		local item = table.remove(self.order, 1)
		local ms, store
		if item.store == "all" then
			ms = self.pendingAll[item.userId]
			self.pendingAll[item.userId] = nil
			store = self.deps.allTimeStore
		else
			local bucket = self.pendingWeek[item.store]
			ms = bucket and bucket[item.userId]
			if bucket then
				bucket[item.userId] = nil
				if next(bucket) == nil then
					self.pendingWeek[item.store] = nil
				end
			end
			-- A week that ended more than a week ago is closed.
			store = if item.store >= currentWeek - 1 then self.deps.weeklyStore(item.store) else nil
		end
		if ms and store then
			calls += 1
			self:_write(store, item.userId, ms)
			if self.studioBlocked then
				break
			end
		end
	end
	return calls
end

function RaceLeaderboard:_readTop(store)
	local ok, rows = pcall(function()
		local pages = store:GetSortedAsync(true, SETTINGS.TopCount)
		return pages:GetCurrentPage()
	end)
	if not ok then
		self:_noteRefusal(rows)
		return nil
	end
	local list = {}
	for _, row in rows do
		local userId = userIdFromKey(row.key)
		local ms = cleanMs(row.value)
		if userId and ms > 0 and #list < SETTINGS.TopCount then
			table.insert(list, { UserId = userId, Name = "", Ms = ms })
		end
	end
	return list
end

-- Reads both tops, names them, and publishes the record and every in-server player's ranks.
function RaceLeaderboard:Read()
	if self.studioBlocked then
		return false
	end
	local week = RaceMath.WeekId(self.deps.unix())
	local allTime = self:_readTop(self.deps.allTimeStore)
	local weekly = self:_readTop(self.deps.weeklyStore(week))
	if allTime then
		self.allTime = allTime
	end
	if weekly then
		self.weekly, self.weekRead = weekly, week
	end
	local ids, seen = {}, {}
	for _, list in { self.allTime, self.weekly } do
		for _, row in list do
			if not seen[row.UserId] then
				seen[row.UserId] = true
				table.insert(ids, row.UserId)
			end
		end
	end
	if #ids > 0 and self.deps.userNames then
		local ok, names = pcall(self.deps.userNames, ids)
		if ok and type(names) == "table" then
			for _, list in { self.allTime, self.weekly } do
				for _, row in list do
					row.Name = names[row.UserId] or row.Name
				end
			end
		end
	end
	-- 2026-09-26 (owner): the lobby's "FASTEST RACERS" board is gone (the holo board beside The
	-- Flash replaced it), and with it GlobalLeaderboards' Race refresh that fed the race titles
	-- (top 1/5/10): this all-time read feeds them now (TitleService.SetBoardRanks("Race", ids)).
	if allTime and self.deps.setBoardRanks then
		local ordered = {}
		for _, row in self.allTime do
			table.insert(ordered, row.UserId)
		end
		pcall(self.deps.setBoardRanks, "Race", ordered)
	end
	self:Publish()
	return allTime ~= nil and weekly ~= nil
end

function RaceLeaderboard.RankOf(list, userId)
	for index, row in list do
		if row.UserId == userId then
			return index
		end
	end
	return nil
end

function RaceLeaderboard:Publish()
	local top = self.weekly[1]
	if self.deps.setWorld then
		pcall(self.deps.setWorld, "RaceRecordMs", if top then top.Ms else nil)
		pcall(self.deps.setWorld, "RaceRecordName", if top then top.Name else nil)
	end
	for _, player in (self.deps.players and self.deps.players() or {}) do
		self:PublishPlayer(player)
	end
end

function RaceLeaderboard:PublishPlayer(player)
	pcall(function()
		player:SetAttribute("RaceWeeklyRank", RaceLeaderboard.RankOf(self.weekly, player.UserId))
		player:SetAttribute("RaceAllTimeRank", RaceLeaderboard.RankOf(self.allTime, player.UserId))
	end)
end

-- RaceRequest("Board"): at most one answer per BoardRequestSeconds per player.
function RaceLeaderboard:Board(player)
	local now = if self.deps.clock then self.deps.clock() else os.clock()
	if now < (self.lastBoard[player] or -math.huge) + SETTINGS.BoardRequestSeconds then
		return nil
	end
	self.lastBoard[player] = now
	local payload = {
		kind = "Board",
		weekly = self.weekly,
		allTime = self.allTime,
		you = {
			bestMs = tonumber(player:GetAttribute("RaceBestMs")) or 0,
			weekBestMs = tonumber(player:GetAttribute("RaceWeekBestMs")) or 0,
			weeklyRank = RaceLeaderboard.RankOf(self.weekly, player.UserId),
			allTimeRank = RaceLeaderboard.RankOf(self.allTime, player.UserId),
		},
	}
	if self.deps.fire then
		pcall(self.deps.fire, player, payload)
	end
	return payload
end

-- Roblox loops: flush every FlushSeconds, read every ReadSeconds (read once at start).
function RaceLeaderboard:Start(spawn, wait)
	spawn(function()
		self:Read()
		local sinceRead = 0
		while true do
			wait(SETTINGS.FlushSeconds)
			pcall(self.Flush, self)
			sinceRead += SETTINGS.FlushSeconds
			if sinceRead >= SETTINGS.ReadSeconds then
				sinceRead = 0
				pcall(self.Read, self)
			end
		end
	end)
end

return RaceLeaderboard
