--!strict
-- src/ServerScriptService/Bootstrap.server.luau
-- Orchestrator del backend modular de +1 Speedster (Reto 1)
-- Inicializa DataService, BuffService, MonetizationService, proyecciones y exportaciones globales.

local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

pcall(function()
	PhysicsService:RegisterCollisionGroup("Players")
end)
pcall(function()
	PhysicsService:RegisterCollisionGroup("VortexSpeedsterCharacters")
end)
pcall(function()
	PhysicsService:CollisionGroupSetCollidable("Players", "Players", false)
	PhysicsService:CollisionGroupSetCollidable("VortexSpeedsterCharacters", "VortexSpeedsterCharacters", false)
	PhysicsService:CollisionGroupSetCollidable("Players", "VortexSpeedsterCharacters", false)
end)

local function setCharacterNoClip(character: Model)
	local function apply(instance: Instance)
		if instance:IsA("BasePart") then
			pcall(function()
				instance.CollisionGroup = "Players"
			end)
		end
	end

	for _, descendant in ipairs(character:GetDescendants()) do
		apply(descendant)
	end
	character.DescendantAdded:Connect(apply)
end

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local SuitCatalog = require(ReplicatedStorage.Shared.SuitCatalog)
local FlightStamina = require(ReplicatedStorage.Shared.FlightStamina)
-- Update 4 (2026-09-25): feature flags / kill switches (Shared/Update4Config, pure data). A
-- build without it (the P0-only one) leaves every Update 4 hook below off.
local U4: any = nil
do
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local module = shared and shared:FindFirstChild("Update4Config")
	if module and module:IsA("ModuleScript") then
		local ok, result = pcall(require, module)
		U4 = if ok and type(result) == "table" then result else nil
	end
end
local function u4IsOn(feature: string): boolean
	if not U4 or type(U4.IsOn) ~= "function" then
		return false
	end
	local ok, on = pcall(U4.IsOn, feature)
	return ok and on == true
end

if Config.UseModularDataService == false then
	warn("[Bootstrap] Config.UseModularDataService is false. Modular backend will NOT activate.")
	return
end

-- Señal global de activación única de backend modular
_G.SpeedsterModularActive = true

local DataService = require(ServerScriptService:WaitForChild("Services"):WaitForChild("Data"):WaitForChild("DataService"))
local DataStoreAdapter = require(ServerScriptService:WaitForChild("Services"):WaitForChild("Data"):WaitForChild("DataStoreAdapter"))
local BuffService = require(ServerScriptService:WaitForChild("Services"):WaitForChild("Buffs"):WaitForChild("BuffService"))
local MonetizationService = require(ServerScriptService:WaitForChild("Services"):WaitForChild("Monetization"):WaitForChild("MonetizationService"))
local StatsService = require(ServerScriptService:WaitForChild("Services"):WaitForChild("Stats"):WaitForChild("StatsService"))
local StatsProjection = require(ServerScriptService:WaitForChild("Services"):WaitForChild("Stats"):WaitForChild("StatsProjection"))
local CharacterStatsAdapter = require(ServerScriptService:WaitForChild("Services"):WaitForChild("Stats"):WaitForChild("CharacterStatsAdapter"))
local PlayerStatsBridge = require(ServerScriptService:WaitForChild("Progression"):WaitForChild("PlayerStatsBridge"))
local PotionServer = require(ServerScriptService:WaitForChild("Services"):WaitForChild("PotionServer"))

-- 1. Inicialización de Remotes
local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not Remotes then
	Remotes = Instance.new("Folder")
	Remotes.Name = "Remotes"
	Remotes.Parent = ReplicatedStorage
end

local function getOrCreateRemote(name: string): RemoteEvent
	local rem = Remotes:FindFirstChild(name)
	if not rem then
		rem = Instance.new("RemoteEvent")
		rem.Name = name
		rem.Parent = Remotes
	end
	return rem :: RemoteEvent
end

local BoostState = getOrCreateRemote("BoostState")
local SpeedGainPopup = getOrCreateRemote("SpeedGainPopup")
local WalkSpeedModeRequest = getOrCreateRemote("WalkSpeedModeRequest")
local SettingsUpdate = getOrCreateRemote("SettingsUpdate")
local UpdateLogClosed = getOrCreateRemote("UpdateLogClosed")
local RemoteGuard = require(ServerScriptService.Services.RemoteGuard)
local LatestStateLimiter = require(ServerScriptService.Services.LatestStateLimiter)
-- The sprint bar goes to its owner only: a Player attribute replicates to every client, and
-- nobody else draws it. Movement/StaminaSyncClient writes the same attribute names locally.
local StaminaSync = Remotes:FindFirstChild("StaminaSync")
if not StaminaSync then
	StaminaSync = Instance.new("UnreliableRemoteEvent")
	StaminaSync.Name = "StaminaSync"
	StaminaSync.Parent = Remotes
end
local WinPadFeedback = getOrCreateRemote("WinPadFeedback")
local LevelProgressUpdate = getOrCreateRemote("LevelProgressUpdate")
local TemporaryBoostUpdate = getOrCreateRemote("TemporaryBoostUpdate")
local TeleportAction = getOrCreateRemote("TeleportAction")
local TeleportUpdate = getOrCreateRemote("TeleportUpdate")
-- A player's own reset (Esc > Reset Character) and a death only their client saw both ask
-- the server for a real death through this; each character's R6DeathRagdoll answers it.
-- It must exist before any client looks for it.
getOrCreateRemote("PlayerResetRequest")

-- 2. Inicialización de Servicios Modulares
local storeAdapter = DataStoreAdapter.CreateProduction(Config.DataStoreName)
DataService.Start(storeAdapter)
BuffService.Start()
MonetizationService.Init({ dataService = DataService })
MonetizationService.Start()

-- Registrar las 23 exportaciones globales canónicas de compatibilidad
PlayerStatsBridge.RegisterGlobals()

-- 3. Estado de Stamina y Boost en Runtime
local boostStaminaByPlayer: { [Player]: number } = {}
local boostMaxByPlayer: { [Player]: number } = {}
local lastBoostUseAt: { [Player]: number } = {}
local staminaPublicationByPlayer: { [Player]: { at: number, maximum: number, stamina: number, resends: number } } = {}
local STAMINA_PUBLICATION_INTERVAL = 0.25
-- A bar that stops moving repeats its value this many times (at the interval above), then goes quiet.
local STAMINA_SETTLE_RESENDS = 2

local function getBaseStaminaMax(): number
	return Config.BoostStaminaDisplayBase or 17
end

local function getBoostMaxStamina(player: Player): number
	local skinId = player:GetAttribute("EquippedSkin")
	local entry = SuitCatalog.ById and SuitCatalog.ById[skinId]
	local maxStamina = (Config.SuitStaminaMax and Config.SuitStaminaMax[skinId])
		or (entry and entry.Stamina) or getBaseStaminaMax()
	boostMaxByPlayer[player] = maxStamina
	return maxStamina
end

local function getCurrentBoostStamina(player: Player): (number, number)
	local maxStamina = getBoostMaxStamina(player)
	local stamina = math.clamp(boostStaminaByPlayer[player] or maxStamina, 0, maxStamina)
	boostStaminaByPlayer[player] = stamina
	return stamina, maxStamina
end

-- Server consumers must use runtime state, not the periodically replicated UI sample.
_G.SpeedsterGetBoostStamina = function(player: Player): number
	if player:GetAttribute("DataLoaded") ~= true then return 0 end
	local stamina = getCurrentBoostStamina(player)
	return stamina
end

local function syncBoostStaminaAttributes(player: Player, sampledAt: number?)
	local stamina, maxStamina = getCurrentBoostStamina(player)
	local now = sampledAt or os.clock()
	local previous = staminaPublicationByPlayer[player]
	local reachedBoundary = (stamina == 0 or stamina == maxStamina)
		and (previous == nil or previous.stamina ~= stamina)
	if previous and previous.maximum == maxStamina and not reachedBoundary
		and now - previous.at < STAMINA_PUBLICATION_INTERVAL then
		return
	end
	local moved = previous == nil or previous.stamina ~= stamina or previous.maximum ~= maxStamina
	-- The last sample of a run has nothing after it to correct a lost packet or one that came
	-- late (unreliable events are unordered too), and the reliable write below is skipped when
	-- the server's own attribute already holds that end (0 -> half -> 0, full -> half -> full).
	local resends = 0
	if previous and not moved then
		resends = math.min(previous.resends + 1, STAMINA_SETTLE_RESENDS + 1)
	end
	staminaPublicationByPlayer[player] = { at = now, maximum = maxStamina, stamina = stamina, resends = resends }
	local function publish(name: string, value: number)
		if player:GetAttribute(name) ~= value then player:SetAttribute(name, value) end
	end
	-- Keep compatibility aliases used by the authored HUD and flight controllers.
	publish("TrueBoostStaminaMax", maxStamina)
	publish("BoostStaminaMaxInternal", maxStamina)
	publish("BoostStaminaDisplayMax", maxStamina)
	-- Only when it moved or has just come to rest: an idle player at a full bar sends nothing at all.
	if moved or resends <= STAMINA_SETTLE_RESENDS then
		StaminaSync:FireClient(player, stamina, maxStamina)
	end
	-- An unreliable packet can be lost, and the two ends of the bar matter: those go reliably.
	if previous == nil or reachedBoundary then
		publish("TrueBoostStamina", stamina)
		publish("BoostStamina", stamina)
	end
end

-- A fresh character (a respawn or a reset) starts on a full bar, at once: the old bar and
-- its regeneration delay stayed with the player, so after a reset they had to wait.
local function refillBoostStamina(player: Player)
	boostStaminaByPlayer[player] = getBoostMaxStamina(player)
	lastBoostUseAt[player] = nil
	if player:GetAttribute("IsBoosting") == true then
		player:SetAttribute("IsBoosting", false)
	end
	-- Published now, not at the next 4 Hz sample.
	staminaPublicationByPlayer[player] = nil
	syncBoostStaminaAttributes(player)
end

-- 4. Listeners de Remotes
-- State remotes: never drop the newest state (RemoteGuard would), but a flooding client costs
-- one run per window. Each run used to cost up to two full projections and a profile copy.
LatestStateLimiter.Connect(WalkSpeedModeRequest, 0.25, function(player: Player, requestedMode: any)
	if player:GetAttribute("DataLoaded") ~= true then return end
	if type(requestedMode) ~= "number" and type(requestedMode) ~= "string" then return end
	if type(requestedMode) == "string" and #requestedMode > 16 then return end
	local num = tonumber(requestedMode)
	if num ~= nil and num == num and num ~= math.huge and num ~= -math.huge then
		local maxSpeed = Config.RealWalkSpeedAtReference or 300
		local minSpeed = Config.RealWalkSpeedMin or 8
		local clamped = math.clamp(math.floor(num + 0.5), minSpeed, maxSpeed)

		player:SetAttribute("WalkSpeedMode", "Custom")
		player:SetAttribute("CustomWalkSpeed", clamped)

		local handle = DataService.GetHandle(player.UserId)
		if handle then
			DataService.SetPreference(handle, "WalkSpeedMode", "Custom")
			DataService.SetPreference(handle, "CustomWalkSpeed", clamped)
			local insp = DataService.Inspect(handle)
			if insp.ok and insp.value.profile then
				CharacterStatsAdapter.Update(player, insp.value.profile.Speed or 0)
			else
				CharacterStatsAdapter.Update(player, 0)
			end
		else
			CharacterStatsAdapter.Update(player, 0)
		end
		return
	end

	requestedMode = tostring(requestedMode or "")
	local multipliers = Config.WalkSpeedSelectorMultipliers or {
		Green = 60 / 300,
		Yellow = 170 / 300,
		Red = 1.0,
	}
	if (multipliers :: any)[requestedMode] ~= nil then
		player:SetAttribute("WalkSpeedMode", requestedMode)
		player:SetAttribute("CustomWalkSpeed", nil)
		local handle = DataService.GetHandle(player.UserId)
		if handle then
			DataService.SetPreference(handle, "WalkSpeedMode", requestedMode)
			local insp = DataService.Inspect(handle)
			if insp.ok and insp.value.profile then
				CharacterStatsAdapter.Update(player, insp.value.profile.Speed or 0)
			else
				CharacterStatsAdapter.Update(player, 0)
			end
		else
			CharacterStatsAdapter.Update(player, 0)
		end
	end
end)

LatestStateLimiter.Connect(BoostState, 0.05, function(player: Player, wantsBoost: any)
	if player:GetAttribute("DataLoaded") ~= true then return end
	wantsBoost = (wantsBoost == true)
	if Config.AbilityFlightEnabled == true and player:GetAttribute("FlightAbilityActive") == true then
		wantsBoost = false
	end
	-- Update 4: a race sprints from its own pool (RaceSprint); the normal sprint stays off there.
	if player:GetAttribute("RaceActive") == true then
		wantsBoost = false
	end

	syncBoostStaminaAttributes(player)
	local maxStamina = getBoostMaxStamina(player)
	local stamina = boostStaminaByPlayer[player] or maxStamina
	local wasBoosting = (player:GetAttribute("IsBoosting") == true)

	if wantsBoost and stamina >= (Config.MinimumStaminaToStartBoost or 8) then
		player:SetAttribute("IsBoosting", true)
		lastBoostUseAt[player] = os.clock()
	else
		player:SetAttribute("IsBoosting", false)
		if wasBoosting then
			lastBoostUseAt[player] = os.clock()
		end
	end

	if DataService.GetHandle(player.UserId) then
		CharacterStatsAdapter.Update(player, DataService.PeekSpeed(player.UserId))
	end
end)

RemoteGuard.Connect(SettingsUpdate, 0.05, function(player: Player, attrName: any, value: any)
	if player:GetAttribute("DataLoaded") ~= true then return end
	if type(attrName) ~= "string" or (type(value) ~= "boolean" and type(value) ~= "number" and type(value) ~= "string") then return end
	local allowed = {
		Muted = "boolean", SoundEffects = "boolean", GlobalMessages = "boolean",
		PromptRevivals = "boolean", HideHud = "boolean", HidePopups = "boolean",
		AcceptGifts = "boolean", EventEffects = "boolean",
		MusicVolume = "number", SfxVolume = "number",
		-- The touch controls' own places (UI/TouchLayoutEditor, sent once on Done):
		-- ProfileReducers keeps only "" or ProfileCodec.SanitizeTouchLayout's exact format.
		TouchLayout = "string",
		-- The HUD guides' "seen" (Shared/TutorialGuide.MarkSeen), saved per account since
		-- 2026-09-21 so the Evolve guide stops coming back on every server.
		EvolveTutorialSeen = "boolean", BackpackTutorialSeen = "boolean",
		-- The rebirth guide's "seen" (2026-09-22), the same way.
		RebirthTutorialSeen = "boolean",
	}
	if allowed[attrName] ~= type(value) then return end
	if type(value) == "number" and (value ~= value or math.abs(value) == math.huge) then return end
	local handle = DataService.GetHandle(player.UserId)
	if handle then
		-- SetPreference validates and projects only accepted settings.
		DataService.SetPreference(handle, attrName, value)
	end
end)

RemoteGuard.Connect(UpdateLogClosed, 0.5, function(player: Player)
	if player:GetAttribute("DataLoaded") ~= true then return end
	local handle = DataService.GetHandle(player.UserId)
	if handle then
		DataService.Commit(handle,{operationId="update-log:"..game.PlaceVersion,fingerprint="update-log:"..game.PlaceVersion,commands={{kind="SetPersistent",key="LastSeenUpdateLog",value=game.PlaceVersion,monotonic=true}}})
	end
end)

-- 5. Ciclo de Vida de Jugador
local setupPlayers: { [Player]: boolean } = {}

local function isMoving(player: Player): boolean
	if player:GetAttribute("AfkModeActive") == true or player:GetAttribute("InAfkZone") == true then
		return false
	end
	local char = player.Character
	if not char then return false end
	if char:GetAttribute("Dead") == true or char:GetAttribute("Ragdolled") == true then
		return false
	end
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 or humanoid.PlatformStand then
		return false
	end
	if humanoid.MoveDirection.Magnitude > 0.05 then return true end
	local root = char:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		local vel = root.AssemblyLinearVelocity
		if (vel.X * vel.X + vel.Z * vel.Z) > 0.8 then
			return true
		end
	end
	return player:GetAttribute("IsMoving") == true
end

local function setupPlayer(player: Player)
	if setupPlayers and setupPlayers[player] then
		return
	end
	if setupPlayers then
		setupPlayers[player] = true
	end

	player:SetAttribute("WalkSpeedMode", Config.WalkSpeedSelectorDefaultMode or "Red")
	player:SetAttribute("IsBoosting", false)
	player:SetAttribute("DataLoaded", false)
	syncBoostStaminaAttributes(player)

	local openRes = nil
	for attempt = 1, 6 do
		if player.Parent ~= Players then return end
		openRes = DataService.Open(player.UserId)
		if openRes.ok then break end
		if not openRes.error or openRes.error.retryable == false then break end
		task.wait(1.5)
	end

	if not openRes or not openRes.ok then
		warn(string.format("[Bootstrap] Could not open the session for %d: %s", player.UserId, tostring(openRes and openRes.error)))
		player:SetAttribute("DataLoadFailed", true)
		player:Kick("Your data could not be loaded safely. Please rejoin in a moment; your saved progress has not been reset.")
		return
	end

	local handle = openRes.value
	if player.Parent ~= Players then
		DataService.Release(handle)
		return
	end
	StatsProjection.Attach(player, handle, DataService)

	if Config.IsDeveloper(player) then
		player:SetAttribute("IsDev", true)
	elseif Config.IsTester(player) then
		player:SetAttribute("IsTester", true)
	end

	local function attachTitleToCharacter(targetPlayer: Player, character: Model)
		local titlesFolder = ReplicatedStorage:FindFirstChild("Titles")
		if not titlesFolder then
			return
		end

		local template: Instance? = nil
		if Config.IsDeveloper(targetPlayer) then
			targetPlayer:SetAttribute("IsDev", true)
		elseif Config.IsTester(targetPlayer) then
			targetPlayer:SetAttribute("IsTester", true)
		end
		-- Update 4 (2026-09-25): TitleService picks the title (EquippedTitle is set while Titles is on;
		-- "" = none chosen). Without it (feature off / old server) the Dev/Tester guess below stays.
		local visual = nil
		local titlesApi = (_G :: any).SpeedsterTitles
		if type(titlesApi) == "table" and type(titlesApi.Visual) == "function" and targetPlayer:GetAttribute("EquippedTitle") ~= nil then
			local okVisual, result = pcall(titlesApi.Visual, targetPlayer)
			visual = if okVisual and type(result) == "table" then result else nil
			if visual then
				template = titlesFolder:FindFirstChild(tostring(visual.Template))
					or titlesFolder:FindFirstChild(if visual.Template == "Owner" or visual.Template == "Dev" then "Dev" else "Tester")
			end
			if not template then
				local shown = character:FindFirstChild("PlayerTitlePart")
				if shown then
					shown:Destroy()
				end
				return
			end
		elseif Config.IsDeveloper(targetPlayer) then
			template = titlesFolder:FindFirstChild("Dev")
		elseif Config.IsTester(targetPlayer) then
			template = titlesFolder:FindFirstChild("Tester")
		end

		if not template or not template:IsA("BasePart") then
			-- No title applies any more (e.g. Titles switched off live): drop the one shown.
			local shown = character:FindFirstChild("PlayerTitlePart")
			if shown then
				shown:Destroy()
			end
			return
		end

		local head = character:FindFirstChild("Head") or character:WaitForChild("Head", 5)
		if not head or not head:IsA("BasePart") then
			return
		end

		local existing = character:FindFirstChild("PlayerTitlePart")
		if existing and visual and existing:GetAttribute("TitleId") == visual.Id then
			-- 2026-09-25 (Update 4): the same title is already welded to this head (a skin change,
			-- a refresh): no re-clone, which would replicate a new part to every client.
			local weld = existing:FindFirstChild("TitleWeld")
			if weld and weld:IsA("Weld") and weld.Part0 == head then
				return
			end
		end
		if existing then
			existing:Destroy()
		end

		local titlePart = template:Clone()
		titlePart.Name = "PlayerTitlePart"
		if visual then
			titlePart:SetAttribute("TitleId", visual.Id)
			titlePart:SetAttribute("TitleStyle", visual.Style)
			titlePart:SetAttribute("TitleText", visual.Text)
			local titleAttachment = titlePart:FindFirstChild("Title")
			local titleBoard = titleAttachment and titleAttachment:FindFirstChild("BillboardGui")
			local titleLabel = titleBoard and titleBoard:FindFirstChild("Title")
			if titleLabel and titleLabel:IsA("TextLabel") then
				titleLabel.Text = tostring(visual.Text or "")
				local gradient = titleLabel:FindFirstChildOfClass("UIGradient")
				-- Plain/Gold templates take the catalog colours; Dev/Tester/Owner keep their authored look.
				if gradient and (visual.Template == "Plain" or visual.Template == "Gold") and typeof(visual.Color1) == "Color3" then
					gradient.Color = ColorSequence.new(visual.Color1, if typeof(visual.Color2) == "Color3" then visual.Color2 else visual.Color1)
				end
			end
		end
		titlePart.CanCollide = false
		titlePart.CanTouch = false
		titlePart.CanQuery = false
		titlePart.Massless = true
		titlePart.Transparency = 1
		-- Above the head, where the title shows (its text is placed by OverheadStats), with
		-- its particle emitters on: the template keeps them off in ReplicatedStorage. Update 4: the
		-- template decides the particles (Plain has none, Gold/Owner/Dev/Tester keep theirs).
		titlePart.CFrame = head.CFrame * CFrame.new(0, tonumber(Config.TitleParticleHeight) or 4, 0)
		for _, emitter in titlePart:GetDescendants() do
			if emitter:IsA("ParticleEmitter") then
				emitter.Enabled = true
			end
		end

		local weld = Instance.new("Weld")
		weld.Name = "TitleWeld"
		weld.Part0 = head
		weld.Part1 = titlePart
		weld.C0 = head.CFrame:ToObjectSpace(titlePart.CFrame)
		weld.Parent = titlePart

		titlePart.Parent = character
	end

	local function syncSuit()
		local maxStamina = getBoostMaxStamina(player)
		local current = boostStaminaByPlayer[player]
		boostStaminaByPlayer[player] = if current ~= nil then math.min(current, maxStamina) else maxStamina
		syncBoostStaminaAttributes(player)
		_G.SpeedsterSyncSuitSpeedGainMultiplier(player)
		if player.Character then
			attachTitleToCharacter(player, player.Character)
		end
	end
	player:GetAttributeChangedSignal("EquippedSkin"):Connect(syncSuit)
	-- Update 4: a new title (equip, rank change, grant) is redrawn above the head.
	player:GetAttributeChangedSignal("EquippedTitle"):Connect(function()
		if player.Character then
			attachTitleToCharacter(player, player.Character)
		end
	end)
	syncSuit()

	task.defer(PotionServer.AnnounceActiveBoosts, player)

	player.CharacterAdded:Connect(function(character)
		refillBoostStamina(player)
		setCharacterNoClip(character)
		local humanoid = character:WaitForChild("Humanoid", 5)
		if humanoid and humanoid:IsA("Humanoid") then
			humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end
		attachTitleToCharacter(player, character)
		-- Apply calculated WalkSpeed immediately upon respawn so characters never spawn at default 16
		local insp = DataService.Inspect(handle)
		if insp.ok and insp.value.profile then
			CharacterStatsAdapter.Update(player, insp.value.profile.Speed or 0)
		end
		-- Re-verify after character model fully settles
		task.defer(function()
			if player.Parent and player.Character == character then
				attachTitleToCharacter(player, character)
				local insp2 = DataService.Inspect(handle)
				if insp2.ok and insp2.value.profile then
					CharacterStatsAdapter.Update(player, insp2.value.profile.Speed or 0)
				end
			end
		end)
	end)

	if player.Character then
		setCharacterNoClip(player.Character)
		attachTitleToCharacter(player, player.Character)
		local insp = DataService.Inspect(handle)
		if insp.ok and insp.value.profile then
			CharacterStatsAdapter.Update(player, insp.value.profile.Speed or 0)
		end
	end
end

-- name -> function(player): shared through _G so a service can register before or after this
-- script runs.
local beforeReleaseCallbacks: { [string]: (Player) -> () } = (_G :: any).SpeedsterBeforeRelease or {};
(_G :: any).SpeedsterBeforeRelease = beforeReleaseCallbacks

local function cleanupPlayer(player: Player)
	if setupPlayers then
		setupPlayers[player] = nil
	end
	StatsProjection.Detach(player)
	boostStaminaByPlayer[player] = nil
	boostMaxByPlayer[player] = nil
	lastBoostUseAt[player] = nil
	staminaPublicationByPlayer[player] = nil
	-- 2026-09-24: services that keep progress in memory (AFK Mode's unclaimed rewards, the
	-- quests' stages and seconds) save it here, before Release closes the session. Their own
	-- PlayerRemoving handlers raced Release (signal order is not guaranteed) and lost it on
	-- every leave and every AFK idle rejoin.
	for name, callback in beforeReleaseCallbacks do
		local ok, err = pcall(callback, player)
		if not ok then
			warn("[Bootstrap] Before-release save '" .. tostring(name) .. "' failed for " .. player.Name .. ": " .. tostring(err))
		end
	end
	-- 2026-09-21: the first-time tutorial is saved as seen at the first Win pad claim, with
	-- retries (Social/FirstTimeTutorial). If none has landed yet the attribute still says true:
	-- put it in the profile here, before Release closes it, rather than racing that script's
	-- own PlayerRemoving handler (signal order is not guaranteed).
	if player:GetAttribute("FirstTimeTutorialSeen") == true then
		local handle = DataService.GetHandle(player.UserId)
		local view = handle and DataService.Inspect(handle)
		if view and view.ok and view.value.profile and view.value.profile.FirstTimeTutorialSeen ~= true then
			pcall(DataService.Commit, handle, {
				operationId = DataService.NewOperationId(),
				fingerprint = "first_time_tutorial_seen_on_leave",
				commands = { { kind = "SetPersistent", key = "FirstTimeTutorialSeen", value = true } },
			})
		end
	end
	local result=DataService.Release(player.UserId)
	if result.kind~="Released" and result.kind~="AlreadyReleased" then
		task.spawn(function()
			for attempt=1,12 do
				if result.error and result.error.retryable==false then return end
				task.wait(5)
				result=DataService.Release(player.UserId)
				if result.kind=="Released" or result.kind=="AlreadyReleased" then return end
			end
			warn("[DataService] Final save still unconfirmed for "..player.UserId)
		end)
	end
end

Players.PlayerAdded:Connect(setupPlayer)
Players.PlayerRemoving:Connect(cleanupPlayer)

for _, player in ipairs(Players:GetPlayers()) do
	task.defer(setupPlayer, player)
end

-- 6. BindToClose
game:BindToClose(function()
	print("[Bootstrap] Game closing. Executing DataService shutdown...")
	DataService.Shutdown()
	print("[Bootstrap] DataService shutdown complete.")
end)

local function getWalkingPopupTier(player: Player)
	local speedValue = DataService.PeekSpeed(player.UserId)
	if speedValue <= 0 then
		speedValue = tonumber(player:GetAttribute("RawSpeed")) or 0
	end

	local selectedBurstCount = Config.WalkingPopupBurstCount or 1
	local selectedSoundPlaybackSpeed = 1
	local selectedName = Config.WalkingPopupName or "Walking"

	local tiers = Config.WalkingPopupTiers
	if type(tiers) == "table" then
		for _, tier in ipairs(tiers) do
			local minimumSpeed = tonumber(tier.MinimumSpeed) or 0
			if speedValue >= minimumSpeed then
				selectedBurstCount = tonumber(tier.BurstCount) or selectedBurstCount
				selectedSoundPlaybackSpeed = tonumber(tier.SoundPlaybackSpeed) or selectedSoundPlaybackSpeed
				selectedName = tier.Name or selectedName
			end
		end
	end

	local isBoosting = player:GetAttribute("IsBoosting") == true
	local visualAmount = Config.WalkingPopupVisualAmount or 1

	if isBoosting then
		selectedSoundPlaybackSpeed = math.min(
			selectedSoundPlaybackSpeed + (Config.BoostRunningPopupSoundExtraSpeed or 0.35),
			Config.BoostRunningPopupSoundMaxPlaybackSpeed or 2.25
		)
		visualAmount *= (Config.BoostRunningVisualAmountMultiplier or Config.BoostRunningGainMultiplier or 3)
	end

	-- Running popups tick continuously 10x/sec; keep burst count to 1 (or 2 when boosting)
	-- to prevent queue explosion on high level players while preserving tier audio and visual scaling.
	selectedBurstCount = isBoosting and 2 or 1

	return {
		Color = Config.WalkingPopupColor or Color3.fromRGB(255, 255, 255),
		BurstCount = selectedBurstCount,
		TreadmillName = selectedName,
		SoundPlaybackSpeed = selectedSoundPlaybackSpeed,
		ForcePopup = Config.WalkingPopupShowEveryTick == true,
		VisualAmount = visualAmount,
		IsRunningPopup = true,
		IsBoostingPopup = isBoosting,
	}
end

-- 7. Loop de Entrenamiento / Correr
task.spawn(function()
	local tickSeconds = Config.TrainingTickSeconds or 0.1
	local speedPerTick = Config.RunningSpeedPerTick or 1
	while true do
		task.wait(tickSeconds)
		for _, player in ipairs(Players:GetPlayers()) do
			-- Dancing at the admin's Disco pays as if running (AdminAbusePanelService sets
			-- DiscoDancing only while the player stands still dancing, and x100 with it).
			local dancing = player:GetAttribute("DiscoDancing") == true
			if player:GetAttribute("DataLoaded") == true and player:GetAttribute("IsOnTreadmill") ~= true and player:GetAttribute("AfkModeActive") ~= true and player:GetAttribute("InAfkZone") ~= true and speedPerTick > 0 and (dancing or isMoving(player)) then
				local gain = speedPerTick
				if not dancing and player:GetAttribute("IsBoosting") == true then
					gain *= (Config.BoostRunningGainMultiplier or 3)
				end
				local handle = DataService.GetHandle(player.UserId)
				if handle then
					local popupTier = Config.WalkingPopupEnabled and getWalkingPopupTier(player) or nil
					_G.SpeedsterAddSpeed(player, gain, popupTier)
				end
			end
		end
	end
end)

-- 8. Loop de Drenaje / Regeneración de Stamina (Heartbeat)
task.spawn(function()
	while true do
		task.wait(math.min(Config.AutoSaveSeconds or 30, 30))
		for _, player in ipairs(Players:GetPlayers()) do
			local handle = DataService.GetHandle(player.UserId)
			if handle then
				task.spawn(function()
					local result = DataService.Flush(handle)
					if result.kind == "Failed" then warn("[Autosave] " .. result.error.message) end
				end)
			end
		end
	end
end)

RunService.Heartbeat:Connect(function(dt: number)
	local now = os.clock()
	for _, player in ipairs(Players:GetPlayers()) do
		if player:GetAttribute("DataLoaded") == true then
			local stamina, maxStamina = getCurrentBoostStamina(player)
			local isBoosting = player:GetAttribute("IsBoosting") == true
			local isFlightActive = (Config.AbilityFlightEnabled == true)
				and (player:GetAttribute("FlightAbilityOwned") == true)
				and (player:GetAttribute("FlightAbilityActive") == true)
			local isFlightPowered = isFlightActive and (player:GetAttribute("FlightAbilityPowered") == true)

			if isFlightActive then
				if isBoosting then
					player:SetAttribute("IsBoosting", false)
				end
				lastBoostUseAt[player] = now
				-- Both the climb and the glide draw from the same bar; Shared.FlightStamina
				-- scales each by the player's maximum so late suits cannot fly forever.
				local exhausted
				stamina, exhausted = FlightStamina.Step(Config, stamina, maxStamina, dt, isFlightPowered)
				if exhausted then
					player:SetAttribute("FlightAbilityPowered", false)
					lastBoostUseAt[player] = now
				end
			elseif isBoosting and isMoving(player) then
				-- Only a sprint that moves costs stamina: holding Shift standing still used to
				-- drain the bar all the same.
				lastBoostUseAt[player] = now
				stamina -= (Config.BoostDrainPerSecond or 34) * dt
				if stamina <= 0 then
					stamina = 0
					player:SetAttribute("IsBoosting", false)
					lastBoostUseAt[player] = now
					if DataService.GetHandle(player.UserId) then
						CharacterStatsAdapter.Update(player, DataService.PeekSpeed(player.UserId))
					end
				end
			else
				local char = player.Character
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				local isAirborne = hum ~= nil and hum.FloorMaterial == Enum.Material.Air and player:GetAttribute("IsOnTreadmill") ~= true
				if isAirborne then
					lastBoostUseAt[player] = now
				else
					local lastUse = lastBoostUseAt[player] or -math.huge
					local delaySeconds = Config.BoostRegenDelaySeconds or 1.7
					-- Update 4: the 2x Stamina Regen pass (Economy/StaminaRegenPass sets the attribute,
					-- gifts included) halves the wait and doubles the refill. Races have their own pool.
					local passOwned = player:GetAttribute("StaminaRegen2xOwned") == true
						and player:GetAttribute("RaceActive") ~= true
						and u4IsOn("StaminaPass")
					delaySeconds *= if passOwned then (tonumber(U4.StaminaPass.DelayScale) or 1) else 1
					if now - lastUse >= delaySeconds then
						local regenPerSecond = maxStamina
							* (Config.BoostRegenPercentPerTick or 0.27)
							/ (Config.BoostRegenTickSeconds or 0.7)
						regenPerSecond *= if passOwned then (tonumber(U4.StaminaPass.RegenMultiplier) or 1) else 1
						stamina += regenPerSecond * dt
						stamina = math.min(stamina, maxStamina)
					end
				end
			end

			boostStaminaByPlayer[player] = stamina
			syncBoostStaminaAttributes(player, now)
		end
	end
end)

print("[Bootstrap] Modular DataService, Buffs, Monetization, and Stats Projection STARTED successfully.")
