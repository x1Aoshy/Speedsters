-- Gameplay/RaceServer.server.luau — Update 4 (2026-09-25): the race server's entry point.
-- Builds the arena and the lobby Race Gate when the place lacks them (the build normally
-- authors both), creates the race remotes, and runs Services/Race/RaceService on a real clock
-- through the `host` table below: every Roblox call the pure service needs (teleports,
-- streaming, remotes, DataStores, MovementGuard, funnels) lives here and nowhere else.
-- Nothing runs while Update4Config.Flags.Race is disabled; with the flag on, the service waits
-- for U4.IsOn("Race") (kill switch Workspace.U4Off_Race, TestingOnly) and checks it again at
-- every join.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local UserService = game:GetService("UserService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local U4 = require(Shared:WaitForChild("Update4Config", 30))
if type(U4) ~= "table" or type(U4.Flags) ~= "table" or type(U4.Flags.Race) ~= "table" or U4.Flags.Race.Enabled ~= true then
	return
end
while not U4.IsOn("Race") do
	task.wait(30)
end

local Config = require(Shared:WaitForChild("Config"))
local RaceMath = require(Shared:WaitForChild("RaceMath"))
local Services = ServerScriptService:WaitForChild("Services")
local RaceFolder = Services:WaitForChild("Race")
local RaceService = require(RaceFolder:WaitForChild("RaceService"))
local RaceChargeJudge = require(RaceFolder:WaitForChild("RaceChargeJudge"))
local RaceRewards = require(RaceFolder:WaitForChild("RaceRewards"))
local RaceLeaderboard = require(RaceFolder:WaitForChild("RaceLeaderboard"))
local RaceArenaBuilder = require(RaceFolder:WaitForChild("RaceArenaBuilder"))
local DataService = require(Services:WaitForChild("Data"):WaitForChild("DataService"))
local RemoteGuard = require(Services:WaitForChild("RemoteGuard"))
local LatestStateLimiter = require(Services:WaitForChild("LatestStateLimiter"))
local PadTouchService = require(Services:WaitForChild("PadTouchService"))

local function optional(name)
	local ok, api = pcall(function()
		return require(Services:WaitForChild(name, 10))
	end)
	return if ok and type(api) == "table" then api else nil
end
local StageTeleportService = optional("StageTeleportService")
local MovementGuard = optional("MovementGuard")
local Update4Profile = (function()
	local ok, api = pcall(function()
		return require(Services:WaitForChild("Data"):WaitForChild("Update4Profile", 10))
	end)
	return if ok and type(api) == "table" then api else nil
end)()
-- Creator Hub funnels (Services.FunnelAnalytics: never throws, never waits).
local FunnelAnalytics = (function()
	local ok, api = pcall(function()
		return require(game:GetService("ServerScriptService"):WaitForChild("Services"):WaitForChild("FunnelAnalytics", 10))
	end)
	if ok and type(api) == "table" then
		return api
	end
	return { Step = function() return false end, NewSession = function() return nil end, Event = function() return false end }
end)()

local RACE = U4.Race
local QUEUE = RACE.Queue
local WORLD_KEY = if Config.IsWorld2Place == true then "World2" elseif Config.IsWorld3Place == true then "World3" else "World1"
local TICK_SECONDS = 0.05
local USERNAME_LOOKUPS_PER_MINUTE = 60

----------------------------------------------------------------------
-- Arena, gate, remotes
----------------------------------------------------------------------
local builderEnv = {
	Instance = Instance, Vector3 = Vector3, CFrame = CFrame, Color3 = Color3, Enum = Enum, UDim2 = UDim2, NumberRange = NumberRange,
	PhysicalProperties = PhysicalProperties,
}
if not Workspace:FindFirstChild("RaceArena") then
	local ok, err = pcall(RaceArenaBuilder.Build, Workspace, builderEnv)
	if not ok then
		warn("[RaceServer] arena build failed: " .. tostring(err))
	end
end
if not Workspace:FindFirstChild("RaceGate") then
	local ok, err = pcall(RaceArenaBuilder.BuildGate, Workspace, WORLD_KEY, builderEnv)
	if not ok then
		warn("[RaceServer] gate build failed: " .. tostring(err))
	end
end

----------------------------------------------------------------------
-- Ground profile and speed pads (2026-09-25, Astra's map: gentle hills, SpeedPads)
----------------------------------------------------------------------
-- The ground under the track, raycast from the arena's collidable floor on a fixed grid
-- (RaceTrack.BuildProfile), published as Workspace.RaceGroundProfile (RaceTrack.EncodeProfile)
-- with RaceGroundVersion, and used here from its decoded copy: the clients decode the same
-- string, so prediction and validation use the same numbers. Done when the arena is there and
-- again whenever Workspace.RaceArena is replaced. The builder's flat arena gives a flat profile.
local RaceTrack = require(Shared:WaitForChild("RaceTrack"))
local GROUND = U4.Race.Ground
local profileVersion = 0

local function groundSampler(arena)
	local exclude = {}
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(exclude, other.Character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	params.IgnoreWater = true
	local last, lastColumn = 0, nil
	return function(s, x)
		if x ~= lastColumn then
			last, lastColumn = 0, x -- each column starts at the flat start
		end
		-- One stud inside the back and end walls.
		local sampleS = math.clamp(s, RaceTrack.ProfileS0 + 1, RaceTrack.ProfileS1 - 1)
		local from = RaceTrack.ToWorld(sampleS, x, last + GROUND.CastAbove)
		local skipped = table.clone(exclude)
		for _ = 1, 6 do
			params.FilterDescendantsInstances = skipped
			local hit = Workspace:Raycast(from, Vector3.new(0, -(GROUND.CastAbove + GROUND.CastDepth), 0), params)
			if not hit then
				return nil
			end
			local part = hit.Instance
			local isTerrain = part:IsA("Terrain")
			local floorLike = hit.Normal.Y >= 0.5
				and (isTerrain or (part:IsDescendantOf(arena) and part.Transparency < 1))
			if floorLike then
				local _, _, y = RaceTrack.ToLocal(hit.Position)
				last = y
				return y
			end
			-- An invisible collider (StartGate, walls), a wall's side or something outside the
			-- arena: look through it.
			table.insert(skipped, part)
		end
		return nil
	end
end

-- 2026-09-26: a hand-made arena may come with its StartGate open (Astra's Green Hill map ships it
-- without collision, for review). It is closed whenever no start is under way, so Race Gate
-- joiners waiting in the staging box cannot run the empty track before the first staging;
-- RaceService closes it at every staging and after the results and opens it just before GO.
local function closeIdleStartGate()
	local arena = Workspace:FindFirstChild("RaceArena")
	local structure = arena and arena:FindFirstChild("Structure")
	local gate = structure and structure:FindFirstChild("StartGate")
	local phase = Workspace:GetAttribute("RacePhase")
	if gate and gate:IsA("BasePart") and not gate.CanCollide and phase ~= "Countdown" and phase ~= "Running" then
		gate.CanCollide = true
	end
end

-- 2026-09-26 (owner): racers brushing the side walls, barriers, curbs or any lateral collider at
-- race speed lost their momentum and stopped. Every boundary of the arena there now (the
-- places' own, an older build's or one made by hand in Studio) is made frictionless
-- (RaceArenaBuilder.ApplyWallPhysics: RaceWall parts, Barriers / Walls / Banks / Fences, wall /
-- barrier / cap / lip / curb / rail / fence / collider names, the StartGate); the floor, the
-- pads and the spike plates keep their own friction.
local function frictionlessWalls()
	local arena = Workspace:FindFirstChild("RaceArena")
	if not arena then
		return
	end
	local ok, count = pcall(RaceArenaBuilder.ApplyWallPhysics, arena, builderEnv)
	if ok then
		print(string.format("[RaceServer] %d race walls frictionless", count))
	else
		warn("[RaceServer] race wall physics failed: " .. tostring(count))
	end
end

local function publishProfile()
	closeIdleStartGate()
	frictionlessWalls()
	local arena = Workspace:FindFirstChild("RaceArena")
	local profile = RaceTrack.FlatProfile()
	if arena then
		local ok, built = pcall(RaceTrack.BuildProfile, groundSampler(arena))
		if ok and built then
			profile = built
		else
			warn("[RaceServer] ground profile failed, racing on a flat one: " .. tostring(built))
		end
	end
	local encoded = RaceTrack.EncodeProfile(profile)
	-- The server judges with the decoded copy, exactly what every client decodes.
	RaceTrack.SetProfile(RaceTrack.DecodeProfile(encoded) or profile)
	profileVersion += 1
	Workspace:SetAttribute("RaceGroundProfile", encoded)
	Workspace:SetAttribute("RaceGroundVersion", profileVersion)
	local issues = RaceTrack.CheckProfile(RaceTrack.GetProfile())
	for index = 1, math.min(5, #issues) do
		warn("[RaceServer] race map (CONTRATO_MAPA_ASTRA §2b): " .. issues[index])
	end
	print(string.format("[RaceServer] ground profile v%d: %s, slope allowance %.4f, %d samples x %d columns",
		profileVersion, if RaceTrack.GetProfile().Flat then "flat" else "hilly", RaceTrack.GetProfile().Allowance,
		RaceTrack.ProfileCount, #RaceTrack.ProfileColumns))
end
publishProfile()
local profilePending = false
local function republishSoon()
	if profilePending then
		return
	end
	profilePending = true
	-- A new arena arrives part by part: measure it once it has settled.
	task.delay(2, function()
		profilePending = false
		publishProfile()
	end)
end
Workspace.ChildAdded:Connect(function(child)
	if child.Name == "RaceArena" then
		republishSoon()
	end
end)
Workspace.ChildRemoved:Connect(function(child)
	if child.Name == "RaceArena" then
		republishSoon()
	end
end)

-- The arena's speed pads (RaceArena.SpeedPads, any depth), read at every staging.
local function readPads()
	local arena = Workspace:FindFirstChild("RaceArena")
	local folder = arena and arena:FindFirstChild("SpeedPads")
	if not folder then
		return {}
	end
	return RaceTrack.PadsFromParts(folder:GetDescendants())
end

local Remotes = ReplicatedStorage:FindFirstChild("Remotes") or ReplicatedStorage:WaitForChild("Remotes", 30)
if not Remotes then
	Remotes = Instance.new("Folder")
	Remotes.Name = "Remotes"
	Remotes.Parent = ReplicatedStorage
end
local function ensureRemote(name, className)
	local existing = Remotes:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing
	end
	local remote = Instance.new(className)
	remote.Name = name
	remote.Parent = Remotes
	return remote
end
local RaceRequest = ensureRemote("RaceRequest", "RemoteEvent")
local RaceSprint = ensureRemote("RaceSprint", "RemoteEvent")
local RaceChargeInput = ensureRemote("RaceChargeInput", "RemoteEvent")
local RaceEvent = ensureRemote("RaceEvent", "RemoteEvent")
local RaceLive = ensureRemote("RaceLive", "UnreliableRemoteEvent")

local function present(player)
	return typeof(player) == "Instance" and player:IsA("Player") and player.Parent == Players
end

local function fire(player, payload)
	if present(player) then
		RaceEvent:FireClient(player, payload)
	end
end

----------------------------------------------------------------------
-- Rewards and leaderboard
----------------------------------------------------------------------
local rewards = RaceRewards.new({
	DataService = DataService,
	config = {
		LapWins = Config.SpinWheel and Config.SpinWheel.LapWins or {},
		SpeedFloor = Config.AfkZone and Config.AfkZone.SpeedFloor,
		SpeedShare = Config.AfkZone and Config.AfkZone.SpeedShare,
		World2UnlockRebirths = Config.World2UnlockRebirths,
	},
	world = WORLD_KEY,
	-- 2026-09-25: Studio has no JobId, and race ids restart at 1 every session: a fixed
	-- "studio" would make every test race after the first answer AlreadyCommitted (shown as
	-- paid, never granted), since the operation ledger is saved with the profile.
	jobId = if game.JobId ~= "" then game.JobId else "studio-" .. game:GetService("HttpService"):GenerateGUID(false),
	unix = os.time,
	wait = task.wait,
	spawn = task.spawn,
	isPresent = function(player)
		return player.Parent == Players
	end,
	winsMultiplier = function(player)
		local hook = (_G :: any).SpeedsterGetWinsMultiplier
		return if type(hook) == "function" then hook(player) else 1
	end,
	hasSection = function(name)
		return Update4Profile ~= nil and type(Update4Profile.HasSection) == "function" and Update4Profile.HasSection(name)
	end,
	titlesRefresh = function(player)
		local titles = (_G :: any).SpeedsterTitles
		if type(titles) == "table" and type(titles.Refresh) == "function" then
			titles.Refresh(player)
		end
	end,
})

local usernameCache = {}
local lookupWindowStart, lookupsUsed = 0, 0
local function userNames(ids)
	local names, missing = {}, {}
	for _, player in Players:GetPlayers() do
		usernameCache[player.UserId] = player.Name
	end
	for _, userId in ids do
		if usernameCache[userId] then
			names[userId] = usernameCache[userId]
		else
			table.insert(missing, userId)
		end
	end
	local now = os.clock()
	if now - lookupWindowStart >= 60 then
		lookupWindowStart, lookupsUsed = now, 0
	end
	local batch = {}
	for index = 1, math.min(#missing, math.max(0, USERNAME_LOOKUPS_PER_MINUTE - lookupsUsed)) do
		table.insert(batch, missing[index])
	end
	if #batch > 0 then
		lookupsUsed += #batch
		local ok, infos = pcall(function()
			return UserService:GetUserInfosByUserIdsAsync(batch)
		end)
		if ok and type(infos) == "table" then
			for _, info in infos do
				local userId = tonumber(info.Id)
				if userId and type(info.Username) == "string" and info.Username ~= "" then
					usernameCache[userId] = info.Username
					names[userId] = info.Username
				end
			end
		end
	end
	return names
end

local leaderboard = nil
do
	local okStore, allTimeStore = pcall(function()
		return DataStoreService:GetOrderedDataStore(RACE.Leaderboard.AllTimeStore)
	end)
	if okStore and allTimeStore then
		local weeklyStores = {}
		leaderboard = RaceLeaderboard.new({
			allTimeStore = allTimeStore,
			weeklyStore = function(weekId)
				if not weeklyStores[weekId] then
					local ok, store = pcall(function()
						return DataStoreService:GetOrderedDataStore(RACE.Leaderboard.WeeklyPrefix .. tostring(weekId))
					end)
					weeklyStores[weekId] = if ok then store else nil
				end
				return weeklyStores[weekId]
			end,
			unix = os.time,
			clock = os.clock,
			wait = task.wait,
			isStudio = RunService:IsStudio(),
			userNames = userNames,
			players = function()
				return Players:GetPlayers()
			end,
			setWorld = function(name, value)
				Workspace:SetAttribute(name, value)
			end,
			fire = fire,
			-- 2026-09-26: the race titles' board ranks (the lobby board that fed them is gone).
			setBoardRanks = function(boardId, userIds)
				local titles = Services:FindFirstChild("Titles")
				local module = titles and titles:FindFirstChild("TitleService")
				if module and module:IsA("ModuleScript") then
					local service = require(module) :: any
					if type(service) == "table" and type(service.SetBoardRanks) == "function" then
						service.SetBoardRanks(boardId, userIds)
					end
				end
			end,
		})
		leaderboard:Start(task.spawn, task.wait)
	else
		warn("[RaceServer] race boards are off: " .. tostring(allTimeStore))
	end
end

----------------------------------------------------------------------
-- Host
----------------------------------------------------------------------
local function characterParts(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then
		return nil
	end
	return character, humanoid, root
end

local function currentProgress(player)
	if MovementGuard and type(MovementGuard.GetProgress) == "function" then
		local ok, progress = pcall(MovementGuard.GetProgress, player)
		if ok and type(progress) == "number" then
			return progress
		end
	end
	return nil
end

local function arenaGate()
	local arena = Workspace:FindFirstChild("RaceArena")
	local structure = arena and arena:FindFirstChild("Structure")
	local gate = structure and structure:FindFirstChild("StartGate")
	return if gate and gate:IsA("BasePart") then gate else nil
end

local service
local judge
local loopRunning = false
local lastTickWarnAt = -math.huge

local function wake()
	if loopRunning then
		return
	end
	loopRunning = true
	task.spawn(function()
		while true do
			local ok, phase = pcall(service.Tick, service, Workspace:GetServerTimeNow())
			if not ok then
				-- At most one warning per 10 s: a persistent error would otherwise print 20 a second.
				if os.clock() - lastTickWarnAt >= 10 then
					lastTickWarnAt = os.clock()
					warn("[RaceServer] tick failed: " .. tostring(phase))
				end
			elseif phase == "Idle" and #service.queue == 0 then
				break -- the loop only runs outside Idle
			end
			task.wait(TICK_SECONDS)
		end
		loopRunning = false
	end)
end

local host = {
	now = function()
		return Workspace:GetServerTimeNow()
	end,
	unix = os.time,
	isOn = U4.IsOn,
	players = function()
		return Players:GetPlayers()
	end,
	isPlayer = present,
	sample = function(player)
		if not present(player) then
			return nil
		end
		local _, humanoid, root = characterParts(player)
		if not humanoid then
			return { alive = false }
		end
		return {
			alive = humanoid.Health > 0 and humanoid:GetState() ~= Enum.HumanoidStateType.Dead,
			position = root.Position,
			cframe = root.CFrame,
			grounded = humanoid.FloorMaterial ~= Enum.Material.Air,
			-- 2026-09-26: how high this rig's root stands (the spike test's lift, RaceService).
			stand = RaceTrack.StandHeight(humanoid.RigType.Name, humanoid.HipHeight, root.Size.Y),
		}
	end,
	pivot = function(player, cframe)
		local character, _, root = characterParts(player)
		if character then
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
			character:PivotTo(cframe)
		end
	end,
	setVelocity = function(player, v)
		local _, _, root = characterParts(player)
		if root then
			root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, -math.max(0, tonumber(v) or 0))
		end
	end,
	streamAround = function(player, position, done)
		task.spawn(function()
			pcall(function()
				player:RequestStreamAroundAsync(position, QUEUE.StreamAroundSeconds)
			end)
			if present(player) then
				done()
			end
			-- 2026-09-26 (owner: Sonic Dash speeds): a racer covers the 2000 studs in 3-20 s, faster
			-- than streaming follows. A trip to the start grid also streams the track ahead
			-- (Queue.StreamAheadS) while the racer stages; nothing waits on it.
			local s, x, y = RaceTrack.ToLocal(position)
			if s <= 0 and s >= -RaceTrack.StagingDepth - 8 and math.abs(x) <= RaceTrack.Width and math.abs(y - RaceTrack.Ground(s, x)) <= 20 then
				for _, aheadS in QUEUE.StreamAheadS or {} do
					if not present(player) then
						break
					end
					local target = RaceTrack.ToWorld(aheadS, 0, RaceTrack.Ground(aheadS, 0) + RaceTrack.RootHeight)
					pcall(function()
						player:RequestStreamAroundAsync(target, QUEUE.StreamAroundSeconds)
					end)
				end
			end
		end)
	end,
	-- Every arena teleport keeps the lobby progress captured at join (the arena is thousands
	-- of studs from any stage, so "nearest stage" would be meaningless there).
	rebase = function(player, progress)
		local hook = (_G :: any).VortexMovementGuardRebase
		if type(hook) == "function" then
			hook(player, if type(progress) == "number" then progress else currentProgress(player))
		end
	end,
	getProgress = currentProgress,
	armGrace = function(player)
		if StageTeleportService and type(StageTeleportService.ArmArrivalGrace) == "function" then
			StageTeleportService.ArmArrivalGrace(player)
		end
	end,
	-- Its own thread: a world's spawn trip may yield, and the race tick never does.
	teleportToSpawn = function(player)
		if StageTeleportService and type(StageTeleportService.TeleportToNormalSpawn) == "function" then
			task.spawn(function()
				local ok, err = pcall(StageTeleportService.TeleportToNormalSpawn, player)
				if not ok then
					warn("[RaceServer] spawn trip failed: " .. tostring(err))
				end
			end)
		end
	end,
	ping = function(player)
		return player:GetNetworkPing()
	end,
	fire = fire,
	live = function(player, payload)
		if present(player) then
			RaceLive:FireClient(player, payload)
		end
	end,
	setWorld = function(name, value)
		Workspace:SetAttribute(name, value)
	end,
	getWorld = function(name)
		return Workspace:GetAttribute(name)
	end,
	setGateCollide = function(on)
		local gate = arenaGate()
		if gate then
			gate.CanCollide = on == true
		end
	end,
	-- PeekSpeed reads the live profile without Inspect's deep copy (16 racers stage at once).
	rawSpeed = function(player)
		if type(DataService.PeekSpeed) == "function" then
			local ok, speed = pcall(DataService.PeekSpeed, player.UserId)
			if ok and type(speed) == "number" then
				return speed
			end
		end
		local data = rewards:Read(player)
		return if data then tonumber(data.profile.Speed) or 0 else 0
	end,
	pads = readPads,
	suitMax = function(player)
		local skin = player:GetAttribute("EquippedSkin")
		return tonumber(Config.SuitStaminaMax and Config.SuitStaminaMax[skin]) or 5
	end,
	-- 2026-09-25 (final fix): both read the attributes RaceRewards projects (RaceDayId,
	-- RaceRaces) instead of Inspect's full profile copy; the profile is read only before the
	-- first projection (a join in the first second after the data loads).
	dailyFirst = function(player)
		local projected = rewards:IsDailyFirstProjected(player)
		if projected ~= nil then
			return projected
		end
		return rewards:IsDailyFirst(player)
	end,
	raceStats = function(player)
		local races = player:GetAttribute("RaceRaces")
		if type(races) == "number" then
			return { Races = races }
		end
		local data = rewards:Read(player)
		return data and data.race
	end,
	prepare = function(player, outcome)
		return rewards:Prepare(player, outcome)
	end,
	-- index (1..16): the payments of one race run 0.1 s apart. task.spawn runs a thread at once
	-- up to its first yield (the DataStore write), so without the stagger every racer's profile
	-- read and commit copies would land in the race tick's frame.
	pay = function(player, outcome, plan, done, index)
		task.spawn(function()
			local delaySeconds = math.clamp(((tonumber(index) or 1) - 1) * 0.1, 0, 3)
			if delaySeconds > 0 then
				task.wait(delaySeconds)
			end
			local ok, result = pcall(rewards.Pay, rewards, player, outcome, plan)
			if not ok then
				warn("[RaceServer] race payment failed: " .. tostring(result))
				result = { ok = false, wins = 0, speed = 0, tickets = 0 }
			end
			if present(player) then
				done(result)
			end
		end)
	end,
	submitPb = function(player, ms, weekId)
		if leaderboard then
			leaderboard:Submit(player, ms, weekId)
		end
	end,
	funnel = FunnelAnalytics,
	wake = wake,
}

-- 2026-09-25 (owner: three queues): the matchmaking bracket from the live Speed (PeekSpeed) and
-- the Rebirths attribute (RaceMath.Bracket, thresholds in U4.Race.Matchmaking).
host.bracket = function(player)
	local ok, speed = pcall(host.rawSpeed, player)
	return RaceMath.Bracket(if ok then speed else 0, player:GetAttribute("Rebirths"))
end

judge = RaceChargeJudge.new({
	now = host.now,
	fire = fire,
	funnel = FunnelAnalytics,
	onJudged = function(player, grade, heldSeconds)
		service:OnJudged(player, grade, heldSeconds)
	end,
})
host.judge = judge
service = RaceService.new(host)

Workspace:SetAttribute("RacePhase", "Idle")
Workspace:SetAttribute("RaceQueueCount", 0)
Workspace:SetAttribute("RaceRacerCount", 0)
Workspace:SetAttribute("RaceMaxPlayers", QUEUE.MaxPlayers)

----------------------------------------------------------------------
-- Remotes
----------------------------------------------------------------------
-- "Gate" is the pad's. 2026-09-25: "Npc" is the lobby's Flash NPC, which sends a table
-- { action = "Join", source = "Npc", category = "Beginner" | "Rank" | "Open" }; the positional
-- form ("Join", source[, category]) is accepted too. RaceService.Join checks the category.
local CLIENT_JOIN_SOURCES = { Hud = true, Invite = true, Results = true, Panel = true, Npc = true }
local CATEGORIES = {}
for _, name in RACE.Matchmaking.Categories do
	CATEGORIES[name] = true
end
local function shortString(value)
	return if type(value) == "string" and #value <= 24 then value else nil
end
RemoteGuard.Connect(RaceRequest, 0.25, function(player, action, argument, extra)
	if type(action) == "table" then
		local payload = action
		action, argument, extra = shortString(rawget(payload, "action")), rawget(payload, "source"), rawget(payload, "category")
	end
	if type(action) ~= "string" then
		return
	end
	if action == "Join" then
		local source = shortString(argument)
		if not source or not CLIENT_JOIN_SOURCES[source] then
			return
		end
		if source == "Results" then
			service:RaceAgain(player)
		elseif source == "Npc" then
			local category = shortString(extra)
			if category and CATEGORIES[category] then
				service:Join(player, "Npc", category)
			end
		else
			service:Join(player, source)
		end
	elseif action == "Leave" then
		service:Leave(player, "Player")
	elseif action == "AutoRequeue" then
		if type(argument) == "boolean" then
			service:SetAutoRequeue(player, argument)
		end
	elseif action == "Board" then
		if leaderboard then
			leaderboard:Board(player)
		end
	end
end)

LatestStateLimiter.Connect(RaceSprint, 0.05, function(player, on)
	if type(on) == "boolean" then
		service:SetSprint(player, on)
	end
end)

LatestStateLimiter.Connect(RaceChargeInput, 0.08, function(player, raceId, edges, final)
	judge:Input(player, raceId, edges, final)
end)

----------------------------------------------------------------------
-- Race Gate pad
----------------------------------------------------------------------
task.spawn(function()
	local gate = Workspace:WaitForChild("RaceGate", 30)
	local pad = gate and gate:WaitForChild("RaceGatePad", 10)
	if not pad or not pad:IsA("BasePart") then
		warn("[RaceServer] no RaceGate.RaceGatePad in this place: the lobby gate is off")
		return
	end
	PadTouchService.Connect(pad, function(root)
		local player = root and Players:GetPlayerFromCharacter(root.Parent)
		if player and not service:IsRacing(player) then
			service:Join(player, "Gate")
		end
	end)
end)

----------------------------------------------------------------------
-- Players
----------------------------------------------------------------------
-- 2026-09-25: RaceBracket ("Beginner" | "Mid" | "Pro") for every loaded player, refreshed every
-- few seconds and written only when it changes (the NPC menu greys Beginner out for veterans;
-- RaceService re-reads it when it forms a heat).
local function publishBracket(player)
	if player.Parent == Players and player:GetAttribute("DataLoaded") == true then
		local ok, bracket = pcall(host.bracket, player)
		if ok and type(bracket) == "string" and player:GetAttribute("RaceBracket") ~= bracket then
			player:SetAttribute("RaceBracket", bracket)
		end
	end
end

local function setupPlayer(player)
	player:SetAttribute("RaceState", "")
	player:SetAttribute("RaceActive", false)
	player:SetAttribute("RaceMovementLocked", false)
	task.spawn(function()
		-- Polled, not :Wait(): a signal wait would hang forever for a player who leaves first.
		local deadline = os.clock() + 120
		while player.Parent == Players and player:GetAttribute("DataLoaded") ~= true and os.clock() < deadline do
			task.wait(1)
		end
		if player.Parent == Players and player:GetAttribute("DataLoaded") == true then
			rewards:Project(player)
			publishBracket(player)
			if leaderboard then
				leaderboard:PublishPlayer(player)
			end
		end
	end)
end

Players.PlayerAdded:Connect(setupPlayer)
for _, player in Players:GetPlayers() do
	task.spawn(setupPlayer, player)
end
task.spawn(function()
	while true do
		task.wait(RACE.Matchmaking.BracketRefreshSeconds)
		for _, player in Players:GetPlayers() do
			publishBracket(player)
		end
	end
end)
Players.PlayerRemoving:Connect(function(player)
	service:Remove(player)
	judge:Forget(player)
end)

----------------------------------------------------------------------
-- Globals (admin panel, AFK Mode, other systems)
----------------------------------------------------------------------
local globals: any = _G
globals.SpeedsterRace = {
	Join = function(player, source, category)
		return service:Join(player, if type(source) == "string" then source else "Panel", category)
	end,
	Leave = function(player, reason)
		return service:Leave(player, reason)
	end,
	IsRacing = function(player)
		return service:IsRacing(player)
	end,
	StartMegaEvent = function(durationSeconds, byName)
		return service:StartMegaEvent(durationSeconds, byName)
	end,
	StopMegaEvent = function()
		return service:StopMegaEvent()
	end,
	-- 2026-09-26 (owner): a live event closes the races while it runs (Gameplay/SuperSonicEventService):
	-- Close(reason) calls off the heat without penalties, sends the arena's players to the lobby spawn and
	-- refuses every Join until Reopen(reason); Workspace.RaceClosedBy = reason meanwhile. Close returns the
	-- players it pulled out (and, second, those it sent to the spawn).
	Close = function(reason)
		return service:Close(reason)
	end,
	Reopen = function(reason)
		return service:Reopen(reason)
	end,
	IsClosed = function()
		return service:IsClosed()
	end,
}
-- 2026-09-26 (owner): an event that closed the races before this server's race loop started (the race was
-- switched off, then on again mid-event) keeps them closed.
do
	local closedBy = Workspace:GetAttribute(RaceService.ClosedAttribute)
	if type(closedBy) == "string" and closedBy ~= "" then
		service:Close(closedBy)
	end
end

print(string.format("[RaceServer] ready in %s | arena at %s | gate %s", WORLD_KEY, tostring(RACE.Arena.Origin),
	if Workspace:FindFirstChild("RaceGate") then "on" else "missing"))
