--!strict
-- AfkZoneService.server.luau
-- AFK Mode (Config.AfkZone; Sung's request, 2026-09-18: it replaced the AFK Zone circle in
-- the lobbies). A player turns it on from the Earnings panel ("Go AFK!", opened by the AFK
-- icon on the top bar) and off with "Exit AFK". While it is on:
--   * their character stands on the lobby's AFK spot (WorldPlacement; players share it in
--     a ring round it), anchored: nothing can push it, drop it or hurt it;
--   * every RewardIntervalSeconds they are paid SpeedShare of their Speed (never under
--     SpeedFloor; x VipSpeedMultiplier with VIP), and a Spin Ticket every
--     TicketIntervalSeconds, straight into their data;
--   * a new character (a reset) is set back on the spot.
-- A player who rejoins with teleport data { AfkModeResume = true } (AfkZoneController's
-- answer to Roblox's 20-minute idle kick when VirtualUser is not allowed) starts in it.
--
-- Published as player attributes for the panel and the HUD:
--   AfkModeActive (bool), AfkModeSince (server time), AfkModeSpeed and AfkModeTickets (what
--   this stint has paid), AfkModeRewardIn and AfkModeTicketIn (seconds), AfkModeNextSpeed.
-- Requests arrive on Remotes.AfkRewardsRequest: { action = "EnterAfk" } and
-- { action = "ExitAfk" }.
--
-- A preview feature (Shared.FeatureGate): only preview players can turn it on.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local settings = Config.AfkZone
if type(settings) ~= "table" or settings.Enabled ~= true then
	return
end

local placementKey = if Config.IsWorld2Place then "World2" elseif Config.IsWorld3Place then "World3" elseif Config.IsNewWorld1Map then "World1" else nil
local center = placementKey and settings.WorldPlacement and settings.WorldPlacement[placementKey]
if typeof(center) ~= "Vector3" then
	return
end

local FeatureGate = require(Shared:WaitForChild("FeatureGate"))
local DataService = require(ServerScriptService:WaitForChild("Services"):WaitForChild("Data"):WaitForChild("DataService"))
-- Creator Hub funnels (Services.FunnelAnalytics: never throws, never waits).
local FunnelAnalytics = (function()
	local ok, api = pcall(function()
		return require(game:GetService("ServerScriptService"):WaitForChild("Services"):WaitForChild("FunnelAnalytics", 10))
	end)
	if ok and type(api) == "table" then
		return api
	end
	return { Step = function() return false end, NewSession = function() return nil end }
end)()

local REWARD_INTERVAL = math.max(10, math.floor(tonumber(settings.RewardIntervalSeconds) or 60))
local TICKET_INTERVAL = math.max(REWARD_INTERVAL, math.floor(tonumber(settings.TicketIntervalSeconds) or 600))
local SPEED_SHARE = math.max(0, tonumber(settings.SpeedShare) or 0.005)
local SPEED_FLOOR = math.max(0, tonumber(settings.SpeedFloor) or 500)
local VIP_MULTIPLIER = math.max(1, tonumber(settings.VipSpeedMultiplier) or 5)
local SPOT_RADIUS = math.max(4, tonumber(settings.SpotRadius) or 12)
local RESPAWN_PLACE_DELAY = 0.4

type Session = {
	since: number,
	rewardSeconds: number,
	ticketSeconds: number,
	speed: number,
	tickets: number,
	slot: number,
	pending: { any },
	committing: boolean,
}
local sessions: { [Player]: Session } = {}

-- Where AFK player number `slot` stands: spread over a disc SpotRadius wide round the spot
-- (the golden angle keeps any number of them apart), all facing its middle.
local function slotFrame(slot: number, lift: number, targetOrigin: Vector3?): CFrame
	local origin = targetOrigin or center
	local angle = slot * 2.39996
	local radius = math.min(SPOT_RADIUS, 3 + 2.2 * math.sqrt(slot))
	local position = origin + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
	local look = Vector3.new(origin.X - position.X, 0, origin.Z - position.Z).Unit
	local right = look:Cross(Vector3.new(0, 1, 0))
	return CFrame.fromMatrix(position + Vector3.new(0, lift, 0), right, Vector3.new(0, 1, 0))
end

local function freeSlot(): number
	local taken = {}
	for _, session in sessions do
		taken[session.slot] = true
	end
	local slot = 1
	while taken[slot] do
		slot += 1
	end
	return slot
end

local function living(player: Player): (Model?, Humanoid?, BasePart?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return nil, nil, nil
	end
	return character, humanoid, root
end

-- Sets the character down on its slot and holds it there.
local function placeOnSpot(player: Player, session: Session)
	local character, humanoid, root = living(player)
	if not character or not humanoid or not root then
		return
	end
	-- The root's height over the floor: legs are at least 2.0 studs tall, root half is 1.0,
	-- plus generous safety clearance so the character is fully standing above the floor and never buried.
	local hip = tonumber(humanoid.HipHeight) or 0
	if hip < 1.8 then
		hip = 2.0 -- Standard Roblox character leg height
	end
	local rootHalfY = if root and root.Size then root.Size.Y * 0.5 else 1.0
	local lift = math.max(3.8, hip + rootHalfY + 0.8)

	-- Probe floor height beneath target spot via raycast so character never clips into the dirt / terrain
	local angle = session.slot * 2.39996
	local radius = math.min(SPOT_RADIUS, 3 + 2.2 * math.sqrt(session.slot))
	local targetFlat = center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)

	local floorHit = nil
	pcall(function()
		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
		local exclude = { character }
		for _, p in Players:GetPlayers() do
			if p.Character then
				table.insert(exclude, p.Character)
			end
		end
		rayParams.FilterDescendantsInstances = exclude
		floorHit = Workspace:Raycast(Vector3.new(targetFlat.X, center.Y + 30, targetFlat.Z), Vector3.new(0, -60, 0), rayParams)
	end)

	local floorY = if floorHit and floorHit.Position then floorHit.Position.Y else center.Y
	local targetCenter = Vector3.new(center.X, floorY, center.Z)
	local frame = slotFrame(session.slot, lift, targetCenter)

	root.Anchored = false
	root.CFrame = frame
	character:PivotTo(frame)
	root.AssemblyLinearVelocity = Vector3.zero
	root.Anchored = true
	-- A sanctioned move: the anti-teleport check starts again from here.
	local rebase = (_G :: any).VortexMovementGuardRebase
	if type(rebase) == "function" then
		pcall(rebase, player, nil)
	end
end

local function release(player: Player)
	local _, _, root = living(player)
	if root then
		root.Anchored = false
	end
end

-- Rewards are queued and committed in order; a failed commit keeps its operation id, so
-- the retry either lands it or finds it already landed.
local function flush(player: Player, session: Session)
	if session.committing or #session.pending == 0 or player:GetAttribute("DataLoaded") ~= true then
		return
	end
	local handle = DataService.GetHandle(player.UserId)
	if not handle then
		return
	end
	session.committing = true
	task.spawn(function()
		while #session.pending > 0 and sessions[player] == session do
			local request = session.pending[1]
			local ok, result = pcall(DataService.Commit, handle, request)
			if ok and (result.kind == "Committed" or result.kind == "AlreadyCommitted") then
				table.remove(session.pending, 1)
			elseif ok and result.kind == "Pending" then
				task.wait(math.max(0.5, tonumber(result.retryAfterSeconds) or 1))
			else
				warn("[AfkMode] Reward dropped for " .. player.Name .. ": " .. tostring(if ok then result.kind else result))
				table.remove(session.pending, 1)
			end
		end
		session.committing = false
	end)
end

-- What the next Speed payment is: a share of the player's Speed, x5 with VIP.
local function speedReward(player: Player): number
	local handle = DataService.GetHandle(player.UserId)
	local speed = 0
	if handle then
		local view = DataService.Inspect(handle)
		if view.ok and view.value.profile then
			speed = tonumber(view.value.profile.Speed) or 0
		end
	end
	local reward = math.max(SPEED_FLOOR, speed * SPEED_SHARE)
	if player:GetAttribute("VIPGamepassOwned") == true then
		reward *= VIP_MULTIPLIER
	end
	return math.floor(reward)
end

local function publish(player: Player, session: Session?)
	if session then
		player:SetAttribute("AfkModeActive", true)
		player:SetAttribute("AfkModeSince", session.since)
		player:SetAttribute("AfkModeSpeed", session.speed)
		player:SetAttribute("AfkModeTickets", session.tickets)
		player:SetAttribute("AfkHasUnclaimed", session.speed > 0 or session.tickets > 0)
		player:SetAttribute("AfkModeRewardIn", math.max(0, REWARD_INTERVAL - session.rewardSeconds))
		player:SetAttribute("AfkModeTicketIn", math.max(0, TICKET_INTERVAL - session.ticketSeconds))
		player:SetAttribute("AfkModeNextSpeed", speedReward(player))
	else
		player:SetAttribute("AfkModeActive", false)
		player:SetAttribute("AfkHasUnclaimed", false)
		for _, name in { "AfkModeSince", "AfkModeRewardIn", "AfkModeTicketIn", "AfkModeNextSpeed", "AfkModeSpeed", "AfkModeTickets" } do
			player:SetAttribute(name, nil)
		end
	end
end

local function tick(player: Player, session: Session)
	if player:GetAttribute("DataLoaded") ~= true or not living(player) then
		return
	end
	session.rewardSeconds += 1
	session.ticketSeconds += 1
	if session.rewardSeconds >= REWARD_INTERVAL then
		session.rewardSeconds = 0
		local reward = speedReward(player)
		session.speed += reward
		FunnelAnalytics.Step(player, "Engagement_AFK", 3)
	end
	if session.ticketSeconds >= TICKET_INTERVAL then
		session.ticketSeconds = 0
		session.tickets += 1
	end
	publish(player, session)
end

local function claimAfkZone(player: Player): boolean
	local session = sessions[player]
	if not session or (session.speed <= 0 and session.tickets <= 0) then
		return false
	end
	if player:GetAttribute("DataLoaded") ~= true then
		return false
	end
	local handle = DataService.GetHandle(player.UserId)
	if not handle then
		return false
	end
	local speedToClaim = session.speed
	local ticketsToClaim = session.tickets
	local commands = {}
	if speedToClaim > 0 then
		table.insert(commands, { kind = "GrantExact", stat = "Speed", amount = speedToClaim })
	end
	if ticketsToClaim > 0 then
		table.insert(commands, { kind = "GrantSpinTickets", amount = ticketsToClaim })
	end
	local request = {
		operationId = "afkmode-claim:" .. tostring(player.UserId) .. ":" .. DataService.NewOperationId(),
		fingerprint = "afkmode-claim",
		commands = commands,
	}
	local ok, result = pcall(DataService.Commit, handle, request)
	if ok and (result.kind == "Committed" or result.kind == "AlreadyCommitted") then
		session.speed = math.max(0, session.speed - speedToClaim)
		session.tickets = math.max(0, session.tickets - ticketsToClaim)
		publish(player, session)
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		local update = remotes and remotes:FindFirstChild("AfkRewardsUpdate")
		if update and update:IsA("RemoteEvent") then
			update:FireClient(player, {
				claimed = true,
				speed = speedToClaim,
				tickets = ticketsToClaim,
				message = "AFK rewards collected!",
			})
		end
		return true
	else
		warn("[AfkMode] Failed to claim for " .. player.Name .. ": " .. tostring(if ok then result.kind else result))
		return false
	end
end

local function enter(player: Player): boolean
	if sessions[player] then
		return true
	end
	if not FeatureGate.IsPreviewPlayer(player) or player:GetAttribute("DataLoaded") ~= true or not living(player) then
		return false
	end
	local session: Session = {
		since = Workspace:GetServerTimeNow(),
		rewardSeconds = 0,
		ticketSeconds = 0,
		speed = 0,
		tickets = 0,
		slot = freeSlot(),
		pending = {},
		committing = false,
	}
	sessions[player] = session
	placeOnSpot(player, session)
	publish(player, session)
	FunnelAnalytics.Step(player, "Engagement_AFK", 2)
	return true
end

local function exit(player: Player)
	local session = sessions[player]
	if not session then
		return
	end
	if session.speed > 0 or session.tickets > 0 then
		claimAfkZone(player)
	end
	sessions[player] = nil
	release(player)
	publish(player, nil)
	FunnelAnalytics.Step(player, "Engagement_AFK", 4)
	-- Anything still waiting to land is committed on its own.
	if #session.pending > 0 then
		local handle = DataService.GetHandle(player.UserId)
		if handle then
			task.spawn(function()
				for _, request in session.pending do
					pcall(DataService.Commit, handle, request)
				end
			end)
		end
	end
end

local function getRateLimiter()
	local ok, rl = pcall(function()
		return require(ServerScriptService:WaitForChild("Services"):WaitForChild("ServerRateLimiter"))
	end)
	return if ok then rl else nil
end

local function onRequest(player: Player, payload: any)
	if type(payload) ~= "table" then
		return
	end
	local rl = getRateLimiter()
	if rl and not rl.Allow(player, "AfkMode", 0.5) then
		return
	end
	if payload.action == "EnterAfk" then
		enter(player)
	elseif payload.action == "ExitAfk" then
		exit(player)
	elseif payload.action == "ClaimAfkZone" or payload.action == "Claim" then
		claimAfkZone(player)
	end
end

local function initRemotes()
	local remotes = ReplicatedStorage:WaitForChild("Remotes", 5)
	if not remotes then
		return
	end
	local request = remotes:FindFirstChild("AfkRewardsRequest")
	if not request then
		local created = Instance.new("RemoteEvent")
		created.Name = "AfkRewardsRequest"
		created.Parent = remotes
		request = created
	end
	(request :: RemoteEvent).OnServerEvent:Connect(onRequest)
end
pcall(initRemotes)

-- A player back from the idle rejoin starts in AFK Mode once their data has loaded.
local function resumeIfAsked(player: Player)
	local ok, data = pcall(function()
		return player:GetJoinData().TeleportData
	end)
	if not ok or type(data) ~= "table" or data.AfkModeResume ~= true then
		return
	end
	task.spawn(function()
		local deadline = os.clock() + 60
		while player.Parent == Players and os.clock() < deadline do
			if player:GetAttribute("DataLoaded") == true and living(player) then
				enter(player)
				return
			end
			task.wait(1)
		end
	end)
end

local function track(player: Player)
	player:SetAttribute("AfkModeActive", false)
	player.CharacterAdded:Connect(function()
		-- A new character (a reset) goes back on the spot.
		task.delay(RESPAWN_PLACE_DELAY, function()
			local session = sessions[player]
			if session then
				placeOnSpot(player, session)
			end
		end)
	end)
	resumeIfAsked(player)
end

Players.PlayerAdded:Connect(track)
for _, player in Players:GetPlayers() do
	track(player)
end
Players.PlayerRemoving:Connect(function(player)
	sessions[player] = nil
end)

_G.SpeedsterAfkModeEnter = enter
_G.SpeedsterAfkModeExit = exit

task.spawn(function()
	while true do
		task.wait(1)
		for player, session in sessions do
			if player.Parent == Players then
				tick(player, session)
			end
		end
	end
end)

print(
	"[AfkMode] ready | "
		.. tostring(placementKey)
		.. " | speed every "
		.. REWARD_INTERVAL
		.. "s | spin every "
		.. TICKET_INTERVAL
		.. "s"
)
