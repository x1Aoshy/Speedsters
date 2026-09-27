-- ServerScriptService/Gameplay/SuperSonicEventService.server.luau — the "Super Sonic vs Dr. Eggman" live
-- event on the server (2026-09-26, owner). The rules live in Gameplay/SuperSonicEventCore (a state machine
-- on the server clock) and the shared numbers and protocol in ReplicatedStorage/Shared/SuperSonicEvent; this
-- script connects them to the game:
--   * Start / Stop: the Admin Abuse panel's "Super Sonic vs Eggman" event tile (owners and admins only, Admin/
--     AdminAbusePanelService: runEvent("SuperSonic")) and _G.SpeedsterSuperSonicEvent.Start(byName) /
--     .Stop() / .IsRunning() / .IsAvailable() / .Status(). One event at a time per server. The kill switch
--     (Workspace attribute U4Off_SuperSonicEvent = true) stops a running event at once and refuses new ones.
--   * ReplicatedStorage.Remotes.SuperSonicEvent: every message is ONE array argument ({ "Bomb", ... }). The
--     clients' { "Charge", t } (press), { "Homing", t, charge01? } (release) and { "RingTake", id } go to
--     Core:ClientMessage, rate-limited per player there (SSE.RateLimit, a token bucket). 2026-09-26 (owner): not
--     Services/RemoteGuard: its "one call per interval" would drop a quick tap's release right after its press
--     (and a run through a cluster of rings), and the charge is measured from the receive times.
--   * The bombs' live ragdoll: the character's RagdollEvent (StarterCharacterScripts/R6DeathRagdoll: "Ragdoll",
--     seconds) and the throw's velocity (set here and, since the client owns its character's physics, sent to
--     that client as { "Knock", velocity, seconds }). Never a kill; a player thrown off the sky lobby is put
--     back at the spawn.
--   * Super Sonic's movement: the player attribute SSE_WalkSpeed = 120 (Movement/InstantMovementController
--     runs at least that fast while it is set; the game's sprint stacks on top) and the Humanoid's JumpPower 90
--     (UseJumpPower on); the old jump values and the game's own WalkSpeed come back at the end
--     (_G.SpeedsterApplyWalkSpeed).
--   * 2026-09-26 (owner): Super Sonic's look is the game's real "Super Sonic" skin (SSE.Super.SkinId), put on
--     through _G.SpeedsterSkinOverride (Economy/SkinSystem): never granted, never saved as the equipped skin
--     (EquippedSkin is not touched), auras and trails kept; the player's own skin comes back exactly at the
--     end, on leaving the area, on joining a race, and a death / respawn gives them their own skin anyway.
--     SSE_Skin tells the clients it is on.
--   * 2026-09-26 (owner): no Flight during the event: the player attribute RaceNoFlight.EventAttribute
--     (EventFlightBlocked = "SuperSonicEvent") on every player in the event's area, cleared at the end;
--     Core/Abilities/FlightService lands and refuses them ("Flying is off during the event").
--   * 2026-09-26 (owner): the Cinematic lifts off from the lobby's Eggman (Workspace.LobbyCharacters.Eggman or the
--     model LobbyNpcs prepared, attribute LobbyNpc = "Eggman"): his Egg Mobile's hull centre is SSE_LiftOff.
--   * 2026-09-26 (owner): the defeat's gold rings land on the lobby floor (a raycast per ring); a ring taken
--     pays through the same batched commits as the hits.
--   * Rewards: DataService.Commit GrantExact Wins + Speed (Core batches them per player; each batch its own
--     operation id), plus the before-release save (_G.SpeedsterBeforeRelease.SuperSonicEvent) so a player
--     leaving mid-event keeps every hit.
--   * 2026-09-26 (owner): v3. The fight moves to the race arena: arenaOrigin drops SSE.ArenaOrigin (the track at
--     s = SSE.RaceArena.TrackS) on Workspace.RaceArena's floor (no arena: nil, the fight stays in the lobby);
--     the trips (teleport: the Teleport / Return beats and TeleportToEvent) stream the spot in and move the
--     character (a trip home is the world's own spawn trip first: StageTeleportService.TeleportToNormalSpawn;
--     a trip to the arena arms the arrival grace and rebases MovementGuard at the player's own progress);
--     arenaGates opens the arena's StartGate / StopBar for the event and restores them; the races close and
--     open through _G.SpeedsterRace.Close / .Reopen (Gameplay/RaceServer; without it the Workspace attribute
--     RaceClosedBy alone, which a race server starting later reads). Racing is judged by the race's
--     attributes only (RaceNoFlight.Check with no position): the fight itself stands in the race arena.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local TextChatService = game:GetService("TextChatService")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SSE = require(Shared:WaitForChild("SuperSonicEvent"))
local Config = require(Shared:WaitForChild("Config"))
local Services = ServerScriptService:WaitForChild("Services")
local DataService = require(Services:WaitForChild("Data"):WaitForChild("DataService"))
local Core = require(script.Parent:WaitForChild("SuperSonicEventCore"))

-- The race's own rule (staged, racing, results, the arena volume). Loaded under pcall: an event must not
-- depend on the race module loading.
local RaceNoFlight = nil
do
	local ok, module = pcall(function()
		return require(Shared:WaitForChild("RaceNoFlight", 10))
	end)
	RaceNoFlight = if ok and type(module) == "table" then module else nil
end

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local function remote(name: string): RemoteEvent
	local existing = Remotes:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end
	if existing then
		existing:Destroy()
	end
	local created = Instance.new("RemoteEvent")
	created.Name = name
	created.Parent = Remotes
	return created
end
local Remote = remote(SSE.RemoteName)

local function characterParts(player: Player): (Model?, Humanoid?, BasePart?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not humanoid or not root or not root:IsA("BasePart") then
		return nil, nil, nil
	end
	return character, humanoid, root
end

local function isAlive(player: Player): boolean
	local character, humanoid = characterParts(player)
	return character ~= nil and humanoid ~= nil and humanoid.Health > 0 and character:GetAttribute("Dead") ~= true
end

-- This world's spawn: the enabled SpawnLocation nearest the world's own (SSE.PickSpawn), its top.
local function worldOrigin(): Vector3
	local tops = {}
	for _, descendant in Workspace:GetDescendants() do
		if descendant:IsA("SpawnLocation") and descendant.Enabled then
			table.insert(tops, descendant.Position + Vector3.new(0, descendant.Size.Y / 2, 0))
		end
	end
	return SSE.WorldOrigin(SSE.PickSpawn(tops, Config), Config)
end

-- 2026-09-26 (owner): the lobby's Eggman's Egg Mobile hull centre (the Cinematic's lift-off point), or nil.
local function lobbyEggmanHull(): Vector3?
	local folder = Workspace:FindFirstChild("LobbyCharacters")
	local eggman = folder and folder:FindFirstChild("Eggman")
	if not (eggman and eggman:IsA("Model")) then
		eggman = nil
		for _, descendant in Workspace:GetDescendants() do
			if descendant:IsA("Model") and descendant:GetAttribute("LobbyNpc") == "Eggman" then
				eggman = descendant
				break
			end
		end
	end
	if not eggman then
		return nil
	end
	local ship = eggman:FindFirstChild("EggMobile")
	local hull = ship and ship:FindFirstChild("EggHull", true)
	if hull and hull:IsA("BasePart") then
		return hull.Position
	end
	local root = eggman:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root.Position
	end
	return nil
end

-- 2026-09-26 (owner): the game's Super Sonic skin for the event (Economy/SkinSystem's _G.SpeedsterSkinOverride).
-- When the skin system is busy putting the player's own skin on (a respawn), it is tried again a moment
-- later while the player is still Super. Returns whether it is on now.
local SKIN_RETRIES = 6
local SKIN_RETRY_SECONDS = 0.5
local function putSuperSkin(player: Player, retries: number): boolean
	local skins = (_G :: any).SpeedsterSkinOverride
	if type(skins) ~= "table" or type(skins.Apply) ~= "function" then
		return false
	end
	local ok, applied, why = pcall(skins.Apply, player, SSE.Super.SkinId, SSE.Super.SkinReason)
	if ok and applied == true then
		player:SetAttribute(SSE.PlayerAttributes.Skin, SSE.Super.SkinId)
		return true
	end
	if ok and why == "busy" and retries > 0 then
		task.delay(SKIN_RETRY_SECONDS, function()
			if player.Parent == Players and player:GetAttribute(SSE.PlayerAttributes.Super) == true
				and player:GetAttribute(SSE.PlayerAttributes.Skin) == nil then
				putSuperSkin(player, retries - 1)
			end
		end)
	end
	return false
end

local function characterList(): { Instance }
	local list = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(list, player.Character)
		end
	end
	return list
end

-- The running event's lobby spawn and fight centre (worldOrigin scans the Workspace: once per event, not per
-- rescue).
local eventOrigin: Vector3? = nil
local eventLobby: Vector3? = nil

-- 2026-09-26 (owner): v3. Loaded when first needed (StageTeleportService waits for the world's map when it is
-- required): the world's spawn trip and arrival grace, MovementGuard's progress.
local lazyModules: { [string]: any } = {}
local function service(name: string): any
	local cached = lazyModules[name]
	if cached == nil then
		local ok, api = pcall(function()
			return require(Services:WaitForChild(name, 10))
		end)
		cached = if ok and type(api) == "table" then api else false
		lazyModules[name] = cached
	end
	return cached or nil
end

local function floorParams(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {}
	params.IgnoreWater = true
	params.RespectCanCollide = true
	return params
end

-- The arena's gates as they were before the event (restored at its end).
local savedGates: { [BasePart]: boolean }? = nil

local jobId = if game.JobId ~= "" then game.JobId else "studio-" .. HttpService:GenerateGUID(false)

local core = Core.new({
	SSE = SSE,
	jobId = jobId,
	now = function()
		return Workspace:GetServerTimeNow()
	end,
	players = function()
		return Players:GetPlayers()
	end,
	userId = function(player)
		return player.UserId
	end,
	rootPosition = function(player)
		if not isAlive(player) then
			return nil
		end
		local _, _, root = characterParts(player)
		return root and root.Position
	end,
	-- 2026-09-26 (owner): bombs lead moving players; a ring take allows for the taker's speed.
	velocity = function(player)
		local _, _, root = characterParts(player)
		return root and root.AssemblyLinearVelocity
	end,
	alive = isAlive,
	grounded = function(player)
		local _, humanoid = characterParts(player)
		return humanoid ~= nil and humanoid.FloorMaterial ~= Enum.Material.Air
	end,
	-- (v3: the core passes no position: in a race by the race's attributes, not the arena volume)
	racing = function(player, position)
		if RaceNoFlight and type(RaceNoFlight.Check) == "function" then
			return (RaceNoFlight.Check(player, position))
		end
		return player:GetAttribute("RaceActive") == true
	end,
	afk = function(player)
		return player:GetAttribute("AfkModeActive") == true
	end,
	ground = function(position)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = characterList()
		params.IgnoreWater = true
		local result = Workspace:Raycast(position + Vector3.new(0, 4, 0), Vector3.new(0, -SSE.Bombard.GroundProbe, 0), params)
		return result and result.Position
	end,
	-- 2026-09-26 (owner): a ring's floor: straight down from over the lobby (position, the floor's normal Y).
	ringGround = function(position)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = characterList()
		params.IgnoreWater = true
		params.RespectCanCollide = true -- (v3: the arena's palms and decor do not collide)
		local R = SSE.Rings
		local result = Workspace:Raycast(position, Vector3.new(0, -(R.ProbeUp + R.ProbeDown), 0), params)
		if not result then
			return nil
		end
		return result.Position, result.Normal.Y
	end,
	-- 2026-09-26 (owner): v3. A trip's spot: its floor, straight down from over the centre's height.
	spotGround = function(position)
		local params = floorParams()
		params.FilterDescendantsInstances = characterList()
		local T = SSE.Teleport
		local result = Workspace:Raycast(position, Vector3.new(0, -(T.ProbeUp + T.ProbeDown), 0), params)
		if not result then
			return nil
		end
		return result.Position, result.Normal.Y
	end,
	-- 2026-09-26 (owner): v3. The fight's centre on the race arena's floor, or nil (no arena here).
	arenaOrigin = function()
		if not Workspace:FindFirstChild("RaceArena") then
			eventOrigin = nil
			return nil
		end
		local point = SSE.ArenaOrigin(SSE.WorldKey(Config))
		local R = SSE.RaceArena
		local params = floorParams()
		params.FilterDescendantsInstances = characterList()
		local result = Workspace:Raycast(point + Vector3.new(0, R.ProbeUp, 0), Vector3.new(0, -(R.ProbeUp + R.ProbeDown), 0), params)
		eventOrigin = if result then result.Position else point
		return eventOrigin
	end,
	-- 2026-09-26 (owner): v3. The arena's StartGate / StopBar collide with nobody during the event.
	arenaGates = function(open)
		if open then
			local arena = Workspace:FindFirstChild("RaceArena")
			local structure = arena and arena:FindFirstChild("Structure")
			local saved = {}
			for _, name in { "StartGate", "StopBar" } do
				local part = structure and structure:FindFirstChild(name)
				if part and part:IsA("BasePart") then
					saved[part] = part.CanCollide
					part.CanCollide = false
				end
			end
			savedGates = saved
		else
			for part, canCollide in savedGates or {} do
				if part.Parent then
					part.CanCollide = canCollide
				end
			end
			savedGates = nil
		end
	end,
	-- 2026-09-26 (owner): v3. The races close while the event runs, and open again after it.
	closeRaces = function(reason)
		local race = (_G :: any).SpeedsterRace
		if type(race) == "table" and type(race.Close) == "function" then
			local ok, pulled = pcall(race.Close, reason)
			if ok then
				return if type(pulled) == "table" then pulled else {}
			end
			warn("[SuperSonicEvent] closing the races failed: " .. tostring(pulled))
		end
		Workspace:SetAttribute(SSE.RaceClosed.Attribute, reason)
		return {}
	end,
	openRaces = function(reason)
		local race = (_G :: any).SpeedsterRace
		if type(race) == "table" and type(race.Reopen) == "function" then
			local ok, err = pcall(race.Reopen, reason)
			if not ok then
				warn("[SuperSonicEvent] opening the races failed: " .. tostring(err))
			end
		end
		if Workspace:GetAttribute(SSE.RaceClosed.Attribute) == reason then
			Workspace:SetAttribute(SSE.RaceClosed.Attribute, nil)
		end
	end,
	-- 2026-09-26 (owner): v3. A trip: stream the spot in, then (if it still holds) move the character there,
	-- facing the fight's centre (the lobby spawn for a trip home). home: the world's own spawn trip first
	-- (arrival grace, CurrentSafeZoneStage, MovementGuard), then the few studs to the free spot in the same
	-- frame; to the arena: the arrival grace and a MovementGuard rebase at the player's own progress.
	teleport = function(player, position, stillValid, arrived, home)
		task.spawn(function()
			pcall(function()
				player:RequestStreamAroundAsync(position, SSE.Teleport.StreamSeconds)
			end)
			if player.Parent ~= Players or not stillValid() or not isAlive(player) then
				return
			end
			local stages = service("StageTeleportService")
			if home and stages and type(stages.TeleportToNormalSpawn) == "function" then
				pcall(stages.TeleportToNormalSpawn, player)
			elseif stages and type(stages.ArmArrivalGrace) == "function" then
				pcall(stages.ArmArrivalGrace, player)
			end
			local character, _, root = characterParts(player)
			if not character or not root or not isAlive(player) then
				return
			end
			local centre = (if home then eventLobby else eventOrigin) or position
			local flat = Vector3.new(centre.X, position.Y, centre.Z)
			local cframe = if (flat - position).Magnitude > 1 then CFrame.lookAt(position, flat) else CFrame.new(position) * root.CFrame.Rotation
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
			character:PivotTo(cframe)
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
			if not home then
				local rebase = (_G :: any).VortexMovementGuardRebase
				local guard = service("MovementGuard")
				if type(rebase) == "function" then
					local progress = if guard and type(guard.GetProgress) == "function" then guard.GetProgress(player) else nil
					pcall(rebase, player, progress)
				end
			end
			local event = character:FindFirstChild("RagdollEvent")
			if event and event:IsA("BindableEvent") then
				event:Fire("Unragdoll")
			end
			arrived()
		end)
	end,
	-- 2026-09-26 (owner): v3. The shield's bounce (the attacker's client applies it too: it owns the physics).
	push = function(player, velocity)
		local _, _, root = characterParts(player)
		if root then
			root.AssemblyLinearVelocity = velocity
		end
	end,
	liftOff = lobbyEggmanHull,
	-- 2026-09-26 (owner): no Flight in the event's area (Shared/RaceNoFlight; FlightService re-checks at once).
	setNoFlight = function(player, on)
		if player.Parent ~= Players then
			return
		end
		local name = if RaceNoFlight then RaceNoFlight.EventAttribute else "EventFlightBlocked"
		player:SetAttribute(name, if on then SSE.Super.SkinReason else nil)
		local refresh = (_G :: any).SpeedsterRefreshRaceNoFlight
		if type(refresh) == "function" then
			pcall(refresh, player)
		end
	end,
	setWorld = function(name, value)
		Workspace:SetAttribute(name, value)
	end,
	setPlayer = function(player, name, value)
		if player.Parent == Players then
			player:SetAttribute(name, value)
		end
	end,
	fireAll = function(message)
		Remote:FireAllClients(message)
	end,
	fireOne = function(player, message)
		if player.Parent == Players then
			Remote:FireClient(player, message)
		end
	end,
	-- The game's live ragdoll (never a kill) and the throw. The owner's client applies the throw too
	-- ({ "Knock" }): a velocity set here is overruled by the physics of a client-owned character.
	ragdoll = function(player, seconds, velocity)
		local character, _, root = characterParts(player)
		if not character or not root then
			return
		end
		local event = character:FindFirstChild("RagdollEvent")
		if event and event:IsA("BindableEvent") then
			event:Fire("Ragdoll", seconds)
		else
			character:SetAttribute("RagdollDuration", seconds)
			character:SetAttribute("Ragdolled", true)
		end
		root.AssemblyLinearVelocity = velocity
	end,
	-- Thrown off the floor: back on the fight's centre (v3: the core says where: the arena, or the lobby spawn
	-- before the Teleport beat), standing, still.
	rescue = function(player, position)
		local character, _, root = characterParts(player)
		if not character or not root then
			return
		end
		local target = position or ((eventOrigin or eventLobby or worldOrigin()) + Vector3.new(0, 4, 0))
		character:PivotTo(CFrame.new(target) * root.CFrame.Rotation)
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		local event = character:FindFirstChild("RagdollEvent")
		if event and event:IsA("BindableEvent") then
			event:Fire("Unragdoll")
		end
	end,
	-- Super Sonic: the walk speed floor for the movement controller, a Super jump and (2026-09-26, owner) the
	-- game's Super Sonic skin for the event. What it changed is returned and handed back to restoreSuper.
	applySuper = function(player)
		local _, humanoid = characterParts(player)
		player:SetAttribute(SSE.PlayerAttributes.WalkSpeed, SSE.Super.WalkSpeed)
		player:SetAttribute(SSE.PlayerAttributes.Skin, nil)
		local skinOn = putSuperSkin(player, SKIN_RETRIES)
		local saved: any = { skin = skinOn }
		if not humanoid then
			return saved
		end
		saved.humanoid = humanoid
		saved.UseJumpPower = humanoid.UseJumpPower
		saved.JumpPower = humanoid.JumpPower
		saved.JumpHeight = humanoid.JumpHeight
		humanoid.UseJumpPower = true
		humanoid.JumpPower = SSE.Super.JumpPower
		if humanoid.WalkSpeed < SSE.Super.WalkSpeed then
			humanoid.WalkSpeed = SSE.Super.WalkSpeed
		end
		return saved
	end,
	restoreSuper = function(player, saved)
		if player.Parent == Players then
			player:SetAttribute(SSE.PlayerAttributes.WalkSpeed, nil)
			player:SetAttribute(SSE.PlayerAttributes.Skin, nil)
		end
		-- The player's own skin back (a no-op when it was never put on, or the character is gone: the new one
		-- gets their own skin from the skin system).
		local skins = (_G :: any).SpeedsterSkinOverride
		if type(skins) == "table" and type(skins.Restore) == "function" then
			pcall(skins.Restore, player, SSE.Super.SkinReason)
		end
		if type(saved) == "table" and saved.humanoid and saved.humanoid.Parent then
			local humanoid = saved.humanoid
			humanoid.UseJumpPower = saved.UseJumpPower
			humanoid.JumpPower = saved.JumpPower
			humanoid.JumpHeight = saved.JumpHeight
		end
		-- 2026-09-26 (owner: "the jump doesn't come back after the event"): a body still on the Super jump (no
		-- snapshot for it: a respawn, a second transform) gets the place's own jump back.
		local _, current = characterParts(player)
		if current and current.UseJumpPower and current.JumpPower == SSE.Super.JumpPower then
			local starter = game:GetService("StarterPlayer")
			current.UseJumpPower = starter.CharacterUseJumpPower
			current.JumpPower = starter.CharacterJumpPower
			current.JumpHeight = starter.CharacterJumpHeight
		end
		-- The game's own WalkSpeed again (the stats tick would bring it back anyway).
		local apply = (_G :: any).SpeedsterApplyWalkSpeed
		if type(apply) == "function" and player.Parent == Players then
			pcall(apply, player)
		end
	end,
	grant = function(player, wins, speed, operationId)
		local handle = DataService.GetHandle(player.UserId)
		if not handle then
			return "NoSession"
		end
		local commands = {}
		if wins > 0 then
			table.insert(commands, { kind = "GrantExact", stat = "Wins", amount = wins })
		end
		if speed > 0 then
			table.insert(commands, { kind = "GrantExact", stat = "Speed", amount = speed })
		end
		local result = DataService.Commit(handle, {
			operationId = operationId,
			fingerprint = operationId,
			commands = commands,
		})
		return if type(result) == "table" then result.kind else "Rejected"
	end,
	winsMultiplier = function(player)
		local hook = (_G :: any).SpeedsterGetWinsMultiplier
		return if type(hook) == "function" then hook(player) else 1
	end,
	-- A system line in the chat (the game's way: Economy/SpinWheelService, Admin/ChatBoostCommands).
	chat = function(text)
		local channels = TextChatService:FindFirstChild("TextChannels")
		local general = channels and channels:FindFirstChild("RBXGeneral")
		if general and general:IsA("TextChannel") then
			general:DisplaySystemMessage(string.format("<font color='%s'><b>[SUPER SONIC vs EGGMAN]</b> %s</font>",
				SSE.Announcements.ChatColor, text))
		end
	end,
	-- The world's lobby spawn (v3: SSE_LobbyOrigin; the fight's centre is arenaOrigin's).
	origin = function()
		eventLobby = worldOrigin()
		return eventLobby
	end,
	isOn = SSE.IsOn,
	newSeed = function()
		return math.random(1, 2147483646)
	end,
	spawn = task.spawn,
	wait = task.wait,
	log = function(text)
		print(text)
	end,
})

-- The clients' messages: { "Charge", t } / { "Homing", t, charge01? } / { "RingTake", id } (or the vararg
-- forms), rate-limited per player by the core (SSE.RateLimit). Nothing here yields (the commits are spawned).
Remote.OnServerEvent:Connect(function(player: Player, first: any, second: any, third: any)
	local ok, err = pcall(core.ClientMessage, core, player, first, second, third)
	if not ok then
		warn("[SuperSonicEvent] client message: " .. tostring(err))
	end
end)

-- The clock: while an event runs, and while the defeat's rings are still out after it.
RunService.Heartbeat:Connect(function()
	if core.running or core:HasRings() then
		core:Step()
	end
end)

Workspace:GetAttributeChangedSignal(SSE.KillAttribute):Connect(function()
	if core.running and not SSE.IsOn() then
		core:Stop("killswitch")
	elseif core:HasRings() and not SSE.IsOn() then
		core:ClearRings() -- 2026-09-26 (owner): the defeat's rings too
	end
end)

-- Death or respawn ends a player's Super form (and a homing attack in flight).
local function watchCharacter(player: Player, character: Model)
	core:CharacterReset(player)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid and humanoid:IsA("Humanoid") then
		humanoid.Died:Connect(function()
			core:CharacterReset(player)
		end)
	end
end
local function watchPlayer(player: Player)
	core:PlayerJoined(player) -- 2026-09-26 (owner): the defeat's rings, if they are still out
	player.CharacterAdded:Connect(function(character)
		watchCharacter(player, character)
	end)
	if player.Character then
		task.spawn(watchCharacter, player, player.Character)
	end
end
Players.PlayerAdded:Connect(watchPlayer)
for _, player in Players:GetPlayers() do
	task.spawn(watchPlayer, player)
end
Players.PlayerRemoving:Connect(function(player)
	core:PlayerRemoving(player)
end)

-- Before Bootstrap releases a leaving player's session: the hits not yet committed are.
local G: any = _G
local beforeRelease = G.SpeedsterBeforeRelease or {}
G.SpeedsterBeforeRelease = beforeRelease
beforeRelease.SuperSonicEvent = function(player: Player)
	core:FlushSync(player)
end

G[SSE.ApiName] = {
	Start = function(byName: string?): (boolean, string?)
		return core:Start(byName)
	end,
	Stop = function(): boolean
		return core:Stop("admin")
	end,
	IsRunning = function(): boolean
		return core.running
	end,
	IsAvailable = function(): boolean
		return SSE.IsOn()
	end,
	Status = function()
		return core:Status()
	end,
}

-- A clean slate on start (a Studio "Run" after a stopped test, a server that crashed mid-event keeps nothing).
Workspace:SetAttribute(SSE.Attributes.Phase, SSE.Phases.None)
