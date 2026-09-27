--!strict
-- src/ServerScriptService/Bootstrap.server.luau
-- Orchestrator del backend modular de +1 Speedster (Reto 1)
-- Inicializa DataService, BuffService, MonetizationService, proyecciones y exportaciones globales.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local SuitCatalog = require(ReplicatedStorage.Shared.SuitCatalog)

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

local function syncBoostStaminaAttributes(player: Player)
	local maxStamina = getBoostMaxStamina(player)
	local stamina = boostStaminaByPlayer[player] or maxStamina
	if stamina > maxStamina then
		stamina = maxStamina
	elseif stamina < 0 then
		stamina = 0
	end
	boostStaminaByPlayer[player] = stamina

	player:SetAttribute("TrueBoostStaminaMax", maxStamina)
	player:SetAttribute("TrueBoostStamina", stamina)
	player:SetAttribute("BoostStaminaMaxInternal", maxStamina)
	player:SetAttribute("BoostStaminaDisplayMax", maxStamina)
	player:SetAttribute("BoostStamina", stamina)
end

-- 4. Listeners de Remotes
WalkSpeedModeRequest.OnServerEvent:Connect(function(player: Player, requestedMode: any)
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

BoostState.OnServerEvent:Connect(function(player: Player, wantsBoost: any)
	wantsBoost = (wantsBoost == true)
	if Config.AbilityFlightEnabled == true and player:GetAttribute("FlightAbilityActive") == true then
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

	local handle = DataService.GetHandle(player.UserId)
	if handle then
		local insp = DataService.Inspect(handle)
		if insp.ok and insp.value.profile then
			CharacterStatsAdapter.Update(player, insp.value.profile.Speed or 0)
		end
	end
end)

SettingsUpdate.OnServerEvent:Connect(function(player: Player, attrName: any, value: any)
	if player:GetAttribute("DataLoaded") ~= true then return end
	if type(attrName) ~= "string" or (type(value) ~= "boolean" and type(value) ~= "number") then return end
	local allowed = {
		Muted = "boolean", SoundEffects = "boolean", GlobalMessages = "boolean",
		PromptRevivals = "boolean", HideHud = "boolean", HidePopups = "boolean",
		AcceptGifts = "boolean", EventEffects = "boolean",
		MusicVolume = "number", SfxVolume = "number",
	}
	if allowed[attrName] ~= type(value) then return end
	if type(value) == "number" and (value ~= value or math.abs(value) == math.huge) then return end
	local handle = DataService.GetHandle(player.UserId)
	if handle then
		-- SetPreference validates and projects only accepted settings.
		DataService.SetPreference(handle, attrName, value)
	end
end)

UpdateLogClosed.OnServerEvent:Connect(function(player: Player)
	if player:GetAttribute("DataLoaded") ~= true then return end
	player:SetAttribute("LastSeenUpdateLog", game.PlaceVersion)
	local handle = DataService.GetHandle(player.UserId)
	if handle then
		DataService.SetPreference(handle, "LastSeenUpdateLog", game.PlaceVersion)
	end
end)

-- 5. Ciclo de Vida de Jugador
local function isMoving(player: Player): boolean
	local char = player.Character
	if not char then return false end
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return false end
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
	player:SetAttribute("WalkSpeedMode", Config.WalkSpeedSelectorDefaultMode or "Red")
	player:SetAttribute("IsBoosting", false)
	player:SetAttribute("DataLoaded", false)
	syncBoostStaminaAttributes(player)

	local openRes = DataService.Open(player.UserId)
	if not openRes.ok then
		warn(string.format("[Bootstrap] Error abriendo sesion para %d: %s", player.UserId, tostring(openRes.error)))
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
	local function syncSuit()
		boostStaminaByPlayer[player] = getBoostMaxStamina(player)
		syncBoostStaminaAttributes(player)
		_G.SpeedsterSyncSuitSpeedGainMultiplier(player)
	end
	player:GetAttributeChangedSignal("EquippedSkin"):Connect(syncSuit)
	syncSuit()

	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid", 5)
		if humanoid and humanoid:IsA("Humanoid") then
			humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end
		task.wait(0.15)
		local insp = DataService.Inspect(handle)
		if insp.ok and insp.value.profile then
			CharacterStatsAdapter.Update(player, insp.value.profile.Speed or 0)
		end
	end)

	if player.Character then
		local insp = DataService.Inspect(handle)
		if insp.ok and insp.value.profile then
			CharacterStatsAdapter.Update(player, insp.value.profile.Speed or 0)
		end
	end
end

local function cleanupPlayer(player: Player)
	StatsProjection.Detach(player)
	boostStaminaByPlayer[player] = nil
	boostMaxByPlayer[player] = nil
	lastBoostUseAt[player] = nil
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
	local handle = DataService.GetHandle(player.UserId)
	local inspectRes = handle and DataService.Inspect(handle)
	local speedValue = (inspectRes and inspectRes.ok and inspectRes.value.profile and inspectRes.value.profile.Speed)
		or tonumber(player:GetAttribute("RawSpeed"))
		or 0

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
			if player:GetAttribute("DataLoaded") == true and player:GetAttribute("IsOnTreadmill") ~= true and speedPerTick > 0 and isMoving(player) then
				local gain = speedPerTick
				if player:GetAttribute("IsBoosting") == true then
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
			syncBoostStaminaAttributes(player)
			local maxStamina = getBoostMaxStamina(player)
			local stamina = boostStaminaByPlayer[player] or maxStamina
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
				if isFlightPowered then
					stamina -= (Config.AbilityFlightDrainPerSecond or 11.7) * dt
					if stamina <= 0 then
						stamina = 0
						player:SetAttribute("FlightAbilityPowered", false)
						lastBoostUseAt[player] = now
					end
				end
			elseif isBoosting then
				lastBoostUseAt[player] = now
				stamina -= (Config.BoostDrainPerSecond or 34) * dt
				if stamina <= 0 then
					stamina = 0
					player:SetAttribute("IsBoosting", false)
					lastBoostUseAt[player] = now
					local handle = DataService.GetHandle(player.UserId)
					if handle then
						local insp = DataService.Inspect(handle)
						if insp.ok and insp.value.profile then
							CharacterStatsAdapter.Update(player, insp.value.profile.Speed or 0)
						end
					end
				end
			else
				local lastUse = lastBoostUseAt[player] or -math.huge
				local delaySeconds = Config.BoostRegenDelaySeconds or 1.7
				if now - lastUse >= delaySeconds then
					local regenPerSecond = maxStamina
						* (Config.BoostRegenPercentPerTick or 0.27)
						/ (Config.BoostRegenTickSeconds or 0.7)
					stamina += regenPerSecond * dt
					stamina = math.min(stamina, maxStamina)
				end
			end

			boostStaminaByPlayer[player] = stamina
			player:SetAttribute("BoostStamina", stamina)
			player:SetAttribute("TrueBoostStamina", stamina)
		end
	end
end)

print("[Bootstrap] Modular DataService, Buffs, Monetization, and Stats Projection STARTED successfully.")
