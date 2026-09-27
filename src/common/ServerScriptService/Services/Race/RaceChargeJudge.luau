-- Services/Race/RaceChargeJudge.luau — Update 4 (2026-09-25): judges each racer's charge start.
-- The client sends its cumulative press/release edges (server-clock times) on RaceChargeInput;
-- the judge stores each new edge once, clamped to what the server could have seen
--   t = clamp(edge, max(openAt, previous + MinPress, received - MaxLag), min(goAt, received + FutureSlack))
-- so a late or replayed list can neither move an accepted edge nor invent one in the future.
-- At `final` (from GO) or GO + JudgeDelay it replays the edges with RaceChargeMath (the same
-- exact integration the client draws) and hands the grade + held seconds to RaceService.
-- Pure apart from the injected deps, so audit/test_u4_race_charge drives it with a fake clock.
local U4 = if typeof(script) == "Instance"
	then require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Update4Config", 10))
	else require("../../../ReplicatedStorage/Shared/Update4Config")
local RaceChargeMath = if typeof(script) == "Instance"
	then require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("RaceChargeMath", 10))
	else require("../../../ReplicatedStorage/Shared/RaceChargeMath")

local CHARGE = U4.Race.Charge
local LEVEL_HZ = 4

local RaceChargeJudge = {}
RaceChargeJudge.__index = RaceChargeJudge

local function finite(value)
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

-- Appends the new edges of `incoming` (indexes past #accepted) to `accepted`. Returns how many
-- were added. Accepted edges are never changed.
function RaceChargeJudge.AcceptEdges(accepted, incoming, received, openAt, goAt, params)
	local p = params or CHARGE
	if type(incoming) ~= "table" then
		return 0
	end
	local count = #incoming
	if count > p.MaxEdges then
		return 0
	end
	local added = 0
	for index = #accepted + 1, count do
		local edge = incoming[index]
		if not finite(edge) then
			break -- a hole or a bad number ends this packet; the next one can continue
		end
		local previous = accepted[#accepted]
		local low = math.max(openAt, if previous then previous + p.MinPress else -math.huge, received - p.MaxLag)
		local high = math.min(goAt, received + p.FutureSlack)
		if low > high then
			break
		end
		table.insert(accepted, math.clamp(edge, low, high))
		added += 1
	end
	return added
end

-- deps = {
--   now: () -> number (Workspace:GetServerTimeNow()),
--   fire: (player, payload) -> () (RaceEvent),
--   funnel: FunnelAnalytics-like {Step, Event},
--   onJudged: (player, grade, heldSeconds, result) -> (),
-- }
function RaceChargeJudge.new(deps)
	local self = setmetatable({}, RaceChargeJudge)
	self.deps = deps or {}
	self.params = self.deps.params or CHARGE
	self.entries = {} -- [player] = entry
	self.misses = setmetatable({}, { __mode = "k" }) -- consecutive Ok/Stall starts this session
	self.nextLevelAt = 0
	return self
end

function RaceChargeJudge:_now()
	return self.deps.now and self.deps.now() or os.clock()
end

function RaceChargeJudge:Open(player, raceId, openAt, goAt)
	self.entries[player] = {
		raceId = raceId,
		openAt = openAt,
		goAt = goAt,
		edges = {},
		final = false,
		judged = false,
		grade = nil,
		held = 0,
		level = -1,
	}
	pcall(function()
		player:SetAttribute("RaceChargeLevel", 0)
		player:SetAttribute("RaceStartGrade", nil)
	end)
end

function RaceChargeJudge:Close(player)
	self.entries[player] = nil
	pcall(function()
		player:SetAttribute("RaceChargeLevel", nil)
	end)
end

function RaceChargeJudge:Forget(player)
	self.entries[player] = nil
	self.misses[player] = nil
end

function RaceChargeJudge:Edges(player)
	local entry = self.entries[player]
	return entry and entry.edges or nil
end

function RaceChargeJudge:Result(player)
	local entry = self.entries[player]
	return entry and entry.grade or nil
end

function RaceChargeJudge:IsAssisted(player)
	return (self.misses[player] or 0) >= self.params.AssistAfterMisses
end

-- RaceChargeInput(raceId, edges, final). Returns true when the packet was accepted.
function RaceChargeJudge:Input(player, raceId, edges, final)
	local entry = self.entries[player]
	if not entry or entry.judged or entry.final then
		return false
	end
	if type(raceId) ~= "number" or raceId ~= entry.raceId or type(edges) ~= "table" then
		return false
	end
	if final ~= nil and type(final) ~= "boolean" then
		return false
	end
	local now = self:_now()
	if now > entry.goAt + self.params.JudgeDelay then
		return false
	end
	local ok, count = pcall(function()
		return #edges
	end)
	if not ok or count > self.params.MaxEdges then
		return false
	end
	local before = #entry.edges
	RaceChargeJudge.AcceptEdges(entry.edges, edges, now, entry.openAt, entry.goAt, self.params)
	if before == 0 and #entry.edges > 0 then
		local funnel = self.deps.funnel
		if funnel and (tonumber(player:GetAttribute("RaceFinishes")) or 0) == 0 then
			pcall(funnel.Step, player, "Onboarding_Race", 3)
		end
	end
	if final == true then
		entry.final = true
		if now >= entry.goAt then
			self:Judge(player)
		end
	end
	return true
end

-- Replays the edges and settles the grade once. Returns grade, heldSeconds.
function RaceChargeJudge:Judge(player)
	local entry = self.entries[player]
	if not entry then
		return nil, 0
	end
	if entry.judged then
		return entry.grade, entry.held
	end
	local assist = self:IsAssisted(player)
	local grace = (tonumber(player:GetAttribute("RaceFinishes")) or 0) < self.params.GraceRaces
	local result = RaceChargeMath.Evaluate(entry.edges, entry.openAt, entry.goAt, entry.goAt, self.params, assist)
	local grade = RaceChargeMath.Outcome(result, self.params, grace, assist)
	entry.judged, entry.grade, entry.held, entry.result = true, grade, result.HeldSeconds, result
	if grade == "Perfect" or grade == "Good" then
		self.misses[player] = 0
	else
		self.misses[player] = (self.misses[player] or 0) + 1
	end
	pcall(function()
		player:SetAttribute("RaceStartGrade", grade)
		player:SetAttribute("RaceChargeLevel", nil)
	end)
	if self.deps.fire then
		pcall(self.deps.fire, player, { kind = "Start", grade = grade })
	end
	local funnel = self.deps.funnel
	if funnel and funnel.Event then
		if grade == "Perfect" then
			pcall(funnel.Event, player, "Race_StartPerfect_v2")
		elseif grade == "Stall" then
			pcall(funnel.Event, player, "Race_StartStall_v2")
		end
	end
	-- Anti-macro: log only (a perfectly regular press rhythm is suspicious, never punished).
	if #entry.edges >= 8 then
		local first = entry.edges[3] - entry.edges[1]
		local regular = true
		for i = 5, #entry.edges, 2 do
			if math.abs((entry.edges[i] - entry.edges[i - 2]) - first) > 0.002 then
				regular = false
				break
			end
		end
		if regular then
			print(string.format("[RaceChargeJudge] %s: %d edges at a machine-regular rhythm", tostring(player.Name), #entry.edges))
		end
	end
	if self.deps.onJudged then
		pcall(self.deps.onJudged, player, grade, result.HeldSeconds, result)
	end
	return grade, result.HeldSeconds
end

-- Called by RaceService every loop step: judges finished or overdue entries and, at 4 Hz
-- during the countdown, publishes RaceChargeLevel (0..10) when it changes.
function RaceChargeJudge:Tick(now)
	local publish = now >= self.nextLevelAt
	if publish then
		self.nextLevelAt = now + 1 / LEVEL_HZ
	end
	for player, entry in self.entries do
		if not entry.judged then
			if (entry.final and now >= entry.goAt) or now >= entry.goAt + self.params.JudgeDelay then
				self:Judge(player)
			elseif publish and now >= entry.openAt and now < entry.goAt then
				local assist = self:IsAssisted(player)
				local result = RaceChargeMath.Evaluate(entry.edges, entry.openAt, entry.goAt, now - 0.1, self.params, assist)
				local level = math.floor(result.G * 10 + 0.5)
				if level ~= entry.level then
					entry.level = level
					pcall(function()
						player:SetAttribute("RaceChargeLevel", level)
					end)
				end
			end
		end
	end
end

return RaceChargeJudge
