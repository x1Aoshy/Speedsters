--!strict
-- AfkZoneService.server.luau
-- AFK Mode (Config.AfkZone; Sung's request, 2026-09-18: it replaced the AFK Zone circle in
-- the lobbies). A player turns it on from the Earnings panel ("Go AFK!", opened by the AFK
-- icon on the top bar) and off with "Exit AFK". While it is on:
--   * their character is set down on its slot of the lobby's AFK spot (WorldPlacement;
--     players share it in a ring round it) and STANDS there on its own: 2026-09-26 (owner) it
--     is never anchored, seated or frozen (it used to be anchored at a computed height, which
--     sank half the body into the floor and left it stiff): unseated, feet on the floor (the
--     rig's own standing height over the floor under the slot), velocity cleared, and the
--     Humanoid keeps it standing and animated;
--   * 2026-09-26 (owner): MOVING ENDS IT. Walking or any movement input (Humanoid.MoveDirection),
--     a jump (the root over where it settled), running off (horizontal speed) or leaving a
--     small radius (LeaveRadius studs from where it was set down: a teleport, a push) ends AFK
--     Mode at once: nothing more accrues, and what the stint earned is claimed exactly as Exit
--     AFK claims it (x1; retried every second until it lands). The client
--     (UI/AfkZoneController) asks for the same ExitAfk as soon as it sees movement input;
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
local SLOT_SPACING = math.max(2, tonumber(settings.SlotSpacing) or 2.8)
local RESPAWN_PLACE_DELAY = 0.4
-- 2026-09-26 (owner): moving ends AFK Mode.
-- Found this far (horizontally) from where AFK Mode set it down (a walk, a push, a stage
-- teleport, the treadmill's GO button, an admin), the character has left its spot.
local LEAVE_RADIUS = math.max(2, tonumber(settings.LeaveRadius) or 6)
-- Humanoid.MoveDirection over this is movement input (walking, a thumbstick, click-to-move).
local MOVE_INPUT = 0.1
-- After being set down the character drops the last fraction of a stud onto the floor: for
-- SETTLE_SECONDS only the radius and movement input count; then its height is taken again and
-- a root JUMP_RISE studs over it (a jump), FALL_DROP under it (a fall) or a horizontal speed
-- over WALK_SPEED studs/s counts as moving.
local SETTLE_SECONDS = 2
local JUMP_RISE = 2.5
local FALL_DROP = 10
local WALK_SPEED = 4
-- The root is set this far over its standing height: it settles onto its feet, never into the floor.
local PLACE_MARGIN = 0.25

type Session = {
	since: number,
	rewardSeconds: number,
	ticketSeconds: number,
	speed: number,
	tickets: number,
	slot: number,
	-- Where the root was set down; nil until a new character has been placed.
	stand: Vector3?,
	-- Seconds left before the character counts as settled on its feet (SETTLE_SECONDS).
	settle: number,
	-- 2026-09-26 (owner): the player moved (or asked to exit): nothing more accrues, and the
	-- stint's claim is retried every second until it lands and the session closes.
	ending: boolean,
	pending: { any },
	committing: boolean,
	claimRequest: any?,
	claimSpeed: number?,
	claimTickets: number?,
}
local sessions: { [Player]: Session } = {}

-- Where AFK player number `slot` stands, from the spot: a sunflower disc (each one a golden
-- angle on from the last, SlotSpacing * sqrt(slot) studs out), which keeps any number of
-- them 4.5 studs apart. (It used to stop growing at 12 studs: the 40th player stood 1.6
-- studs from another.)
local function slotOffset(slot: number): Vector3
	local angle = slot * 2.39996
	local radius = math.min(SPOT_RADIUS, SLOT_SPACING * math.sqrt(slot))
	return Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
end

-- The slot's frame over `targetOrigin` (the spot at its floor's height), facing the middle.
local function slotFrame(slot: number, lift: number, targetOrigin: Vector3?): CFrame
	local origin = targetOrigin or center
	local position = origin + slotOffset(slot)
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

-- Raycast params that see only what can be stood on, never a player.
local function floorParams(character: Model): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	local exclude: { Instance } = { character }
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(exclude, p.Character)
		end
	end
	params.FilterDescendantsInstances = exclude
	return params
end

-- How high this rig's root stands over the floor. Measured when the character stands on
-- something now (the ray under its root: skins and scaled bodies included); else from the rig:
-- an R6 rig's 2-stud legs (its HipHeight is 0) or an R15 rig's HipHeight, plus half the root.
local function standingHeight(character: Model, humanoid: Humanoid, root: BasePart): number
	local measured: number? = nil
	pcall(function()
		if humanoid.FloorMaterial ~= Enum.Material.Air then
			local hit = Workspace:Raycast(root.Position, Vector3.new(0, -14, 0), floorParams(character))
			if hit then
				measured = root.Position.Y - hit.Position.Y
			end
		end
	end)
	if measured and measured >= 1.5 and measured <= 12 then
		return measured
	end
	local hip = math.max(0, tonumber(humanoid.HipHeight) or 0)
	if humanoid.RigType == Enum.HumanoidRigType.R6 then
		hip += 2
	elseif hip < 0.5 then
		hip = 2 -- a rig that does not say: standard legs
	end
	return hip + root.Size.Y * 0.5
end

-- 2026-09-26 (owner: "they must not sit"): out of any seat before AFK Mode sets them down.
local function unseat(humanoid: Humanoid)
	pcall(function()
		local seat = humanoid.SeatPart
		if seat then
			local weld = seat:FindFirstChild("SeatWeld")
			if weld then
				weld:Destroy()
			end
		end
		if humanoid.Sit then
			humanoid.Sit = false
		end
	end)
end

-- Sets the character down on its slot, STANDING (2026-09-26, owner): never anchored, never
-- seated, never frozen; its feet on the floor under the slot (standingHeight + PLACE_MARGIN, so
-- it settles onto its feet and never into the floor), its velocity cleared. The Humanoid keeps
-- it standing and animated; moving ends AFK Mode (see moved).
local function placeOnSpot(player: Player, session: Session)
	local character, humanoid, root = living(player)
	if not character or not humanoid or not root then
		return
	end
	unseat(humanoid)
	if root.Anchored then
		root.Anchored = false -- nothing of AFK Mode holds a character any more
	end
	local lift = standingHeight(character, humanoid, root) + PLACE_MARGIN

	-- The floor under the slot, by raycast: only what can be stood on counts.
	local targetFlat = center + slotOffset(session.slot)
	local floorHit = nil
	pcall(function()
		floorHit = Workspace:Raycast(Vector3.new(targetFlat.X, center.Y + 30, targetFlat.Z), Vector3.new(0, -60, 0), floorParams(character))
	end)

	local floorY = if floorHit and floorHit.Position then floorHit.Position.Y else center.Y
	local targetCenter = Vector3.new(center.X, floorY, center.Z)
	local frame = slotFrame(session.slot, lift, targetCenter)

	character:PivotTo(frame)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	session.stand = frame.Position
	session.settle = SETTLE_SECONDS
	-- A sanctioned move: the anti-teleport check starts again from here.
	local rebase = (_G :: any).VortexMovementGuardRebase
	if type(rebase) == "function" then
		pcall(rebase, player, nil)
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
	-- 2026-09-26 (owner): a stint that is ending (the player moved) earns nothing more.
	if session.ending or player:GetAttribute("DataLoaded") ~= true or not living(player) then
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
	if session.committing then return false end
	local speedToClaim = session.claimSpeed or session.speed
	local ticketsToClaim = session.claimTickets or session.tickets
	local commands = {}
	if speedToClaim > 0 then
		table.insert(commands, { kind = "GrantExact", stat = "Speed", amount = speedToClaim })
	end
	if ticketsToClaim > 0 then
		table.insert(commands, { kind = "GrantSpinTickets", amount = ticketsToClaim })
	end
	local request = session.claimRequest or {
		operationId = "afkmode-claim:" .. tostring(player.UserId) .. ":" .. DataService.NewOperationId(),
		fingerprint = "afkmode-claim",
		commands = commands,
	}
	session.claimRequest, session.claimSpeed, session.claimTickets = request, speedToClaim, ticketsToClaim
	session.committing = true
	player:SetAttribute("AfkModeClaimBusy", true)
	local ok, result = pcall(DataService.Commit, handle, request)
	session.committing = false
	if ok and (result.kind == "Committed" or result.kind == "AlreadyCommitted") then
		session.claimRequest, session.claimSpeed, session.claimTickets = nil, nil, nil
		player:SetAttribute("AfkModeClaimBusy", false)
		session.speed = math.max(0, session.speed - speedToClaim)
		session.tickets = math.max(0, session.tickets - ticketsToClaim)
		publish(player, session)
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		local update = remotes and remotes:FindFirstChild("AfkRewardsUpdate")
		if update and update:IsA("RemoteEvent") and player.Parent == Players then
			update:FireClient(player, {
				claimed = true,
				speed = speedToClaim,
				tickets = ticketsToClaim,
				message = "AFK rewards collected!",
			})
		end
		return true
	else
		if ok and result.kind ~= "Pending" then
			session.claimRequest, session.claimSpeed, session.claimTickets = nil, nil, nil
			player:SetAttribute("AfkModeClaimBusy", false)
		end
		warn("[AfkMode] Failed to claim for " .. player.Name .. ": " .. tostring(if ok then result.kind else result))
		return false
	end
end

local function enter(player: Player): boolean
	local current = sessions[player]
	if current then
		-- 2026-09-26: a stint still settling its claim after the player moved is not "on".
		return not current.ending
	end
	if not FeatureGate.IsPreviewPlayer(player) or player:GetAttribute("DataLoaded") ~= true or not living(player) then
		return false
	end
	-- Update 4 (2026-09-25): never AFK from the race arena; a player only waiting in the race
	-- queue (still in the lobby) leaves the queue and goes AFK.
	if player:GetAttribute("RaceActive") == true then
		return false
	end
	if player:GetAttribute("RaceState") == "Queued" then
		local race = (_G :: any).SpeedsterRace
		if type(race) == "table" and type(race.Leave) == "function" then
			pcall(race.Leave, player, "Afk")
		end
	end
	local session: Session = {
		since = Workspace:GetServerTimeNow(),
		rewardSeconds = 0,
		ticketSeconds = 0,
		speed = 0,
		tickets = 0,
		slot = freeSlot(),
		settle = SETTLE_SECONDS,
		ending = false,
		pending = {},
		committing = false,
	}
	sessions[player] = session
	placeOnSpot(player, session)
	publish(player, session)
	FunnelAnalytics.Step(player, "Engagement_AFK", 2, FunnelAnalytics.NewSession(player, "Engagement_AFK"))
	return true
end

local function exit(player: Player)
	local session = sessions[player]
	if not session then
		return
	end
	-- 2026-09-26 (owner): from here on the stint earns nothing more, whatever the claim does
	-- (a claim that does not land yet is retried every second by the loop below).
	session.ending = true
	if session.committing then return end
	if session.speed > 0 or session.tickets > 0 then
		if not claimAfkZone(player) then return end
	end
	sessions[player] = nil
	-- (2026-09-26: nothing to let go of: AFK Mode never anchors the character any more.)
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
		-- A new character (a reset) goes back on the spot. Until it is set down it stands at
		-- the spawn: that is not "moved away".
		local respawned = sessions[player]
		if respawned then
			respawned.stand = nil
		end
		task.delay(RESPAWN_PLACE_DELAY, function()
			local session = sessions[player]
			if session and not session.ending then
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
-- Leaving (or the idle rejoin's teleport): what this stint holds unclaimed is paid at x1 before
-- the data session closes (Bootstrap runs this before Release). It used to be dropped here, so
-- "AFK all night" paid at most one 16-20 minute stint, and nothing if the player just left.
local beforeRelease = (_G :: any).SpeedsterBeforeRelease or {};
(_G :: any).SpeedsterBeforeRelease = beforeRelease
beforeRelease.AfkMode = function(player: Player)
	local session = sessions[player]
	if not session then
		return
	end
	-- A claim or the x5 receipt in flight settles itself; wait for it briefly.
	local deadline = os.clock() + 5
	while session.committing and os.clock() < deadline do
		task.wait(0.1)
	end
	if session.speed > 0 or session.tickets > 0 then
		claimAfkZone(player)
	end
	local handle = DataService.GetHandle(player.UserId)
	if handle then
		for _, request in session.pending do
			pcall(DataService.Commit, handle, request)
		end
	end
	sessions[player] = nil
end
Players.PlayerRemoving:Connect(function(player)
	-- Kept until the before-release save above has run (it may run after this handler); the
	-- loops skip players who have left.
	task.delay(30, function()
		sessions[player] = nil
	end)
end)

_G.SpeedsterAfkModeEnter = enter
_G.SpeedsterAfkModeExit = exit

-- Get x5 (the ClaimX5 developer product; its receipt is planned by Social/AfkRewardsService):
-- hands over what this stint holds unclaimed and takes it out of the session, so Claim and
-- Exit AFK cannot pay it a second time while the receipt is being written. Restore puts it
-- back when the receipt does not land (or pays it x1 if AFK Mode ended meanwhile).
_G.SpeedsterAfkZoneTake = function(player: Player)
	local session = sessions[player]
	if not session or session.committing or session.claimRequest or session.speed <= 0 then
		return nil
	end
	local restored = false
	local speed, tickets = session.speed, session.tickets
	session.speed, session.tickets = 0, 0
	publish(player, session)
	return {
		Speed = speed,
		Tickets = tickets,
		Restore = function()
			if restored then return end
			restored = true
			local current = sessions[player]
			if current then
				current.speed += speed
				current.tickets += tickets
				publish(player, current)
				return
			end
			local handle = DataService.GetHandle(player.UserId)
			if handle then
				local commands: { any } = { { kind = "GrantExact", stat = "Speed", amount = speed } }
				if tickets > 0 then
					table.insert(commands, { kind = "GrantSpinTickets", amount = tickets })
				end
				pcall(DataService.Commit, handle, {
					operationId = "afkmode-restore:" .. tostring(player.UserId) .. ":" .. DataService.NewOperationId(),
					fingerprint = "afkmode-restore",
					commands = commands,
				})
			end
		end,
	}
end

-- 2026-09-26 (owner): whether the player MOVED, which ends AFK Mode (nil = still standing):
--   "left"   the root is over LEAVE_RADIUS studs (horizontally) from where it was set down (a
--            walk, a push, StageTeleportService, the admin / taco treadmill's GO, an admin);
--   "input"  Humanoid.MoveDirection says walking / thumbstick / click-to-move;
-- and once it has settled on its feet (SETTLE_SECONDS after being set down):
--   "jumped" the root JUMP_RISE over where it settled (or Humanoid.Jump), "fell" FALL_DROP under;
--   "ran"    a horizontal speed over WALK_SPEED.
local function moved(player: Player, session: Session): string?
	local _, humanoid, root = living(player)
	local stand = session.stand
	if not humanoid or not root or not stand then
		return nil
	end
	local offset = root.Position - stand
	if Vector3.new(offset.X, 0, offset.Z).Magnitude > LEAVE_RADIUS then
		return "left"
	end
	local ok, direction = pcall(function()
		return (humanoid :: any).MoveDirection
	end)
	if ok and typeof(direction) == "Vector3" and direction.Magnitude > MOVE_INPUT then
		return "input"
	end
	if session.settle > 0 then
		return nil
	end
	if offset.Y > JUMP_RISE or (humanoid :: any).Jump == true then
		return "jumped"
	end
	if offset.Y < -FALL_DROP then
		return "fell"
	end
	local velocity = root.AssemblyLinearVelocity
	if typeof(velocity) == "Vector3" and velocity.X * velocity.X + velocity.Z * velocity.Z > WALK_SPEED * WALK_SPEED then
		return "ran"
	end
	return nil
end

-- The settle countdown: when it runs out, the height the character settled at is where a
-- jump is measured from (it was set down PLACE_MARGIN over its standing height).
local function settleStep(player: Player, session: Session)
	if not session.stand or session.settle <= 0 then
		return
	end
	session.settle -= 1
	if session.settle <= 0 then
		local _, _, root = living(player)
		local stand = session.stand :: Vector3
		if root then
			session.stand = Vector3.new(stand.X, root.Position.Y, stand.Z)
		end
	end
end

task.spawn(function()
	while true do
		task.wait(1)
		for player, session in sessions do
			if player.Parent == Players then
				if session.ending or moved(player, session) ~= nil then
					-- Moving ends AFK Mode: nothing more accrues (ending), and exit() claims what
					-- the stint earned as Exit AFK does; until that claim lands it is tried again
					-- every second. On its own thread: exit() waits for the claim to be saved.
					session.ending = true
					if not session.committing then task.spawn(exit, player) end
				else
					settleStep(player, session)
					tick(player, session)
				end
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
