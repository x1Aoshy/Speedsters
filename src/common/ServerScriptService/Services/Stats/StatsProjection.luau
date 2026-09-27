--!strict
-- src/ServerScriptService/Services/Stats/StatsProjection.luau
-- Lote R1-08 / Reto 1: Proyector unidireccional de perfil hacia leaderstats, carpetas y atributos.
-- Invariante: NUNCA escribe de vuelta al perfil de DataService.

local CharacterStatsAdapter
local StatsService

if typeof(script) == "Instance" and script.Parent then
	CharacterStatsAdapter = require(script.Parent.CharacterStatsAdapter)
	StatsService = require(script.Parent.StatsService)
else
	CharacterStatsAdapter = require("./CharacterStatsAdapter")
	StatsService = require("./StatsService")
end

type SessionHandle = {
	userId: number,
	sessionId: string,
	generation: number,
}

type SessionView = {
	handle: SessionHandle,
	state: string,
	durableRevision: number,
	leaseExpiresUnix: number?,
	profile: any?,
}

local StatsProjection = {}
local activeUnsubscribes: { [number]: () -> () } = {}

local function setAttributeIfChanged(instance: any, name: string, value: any)
	if instance:GetAttribute(name) ~= value then
		instance:SetAttribute(name, value)
	end
end

local function ensureValue(parent: any, className: string, name: string, defaultValue: any): any
	if not parent or typeof(parent.FindFirstChild) ~= "function" then
		return nil
	end
	local existing = parent:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing
	end
	if existing then
		pcall(function() existing:Destroy() end)
	end
	local newObj = Instance.new(className)
	newObj.Name = name
	newObj.Value = defaultValue
	newObj.Parent = parent
	return newObj
end

local function syncStringList(folder: any, targetList: { string }?)
	if not folder or typeof(folder.GetChildren) ~= "function" then
		return
	end
	local targets = targetList or {}
	local existingMap = {}
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("BoolValue") or child:IsA("StringValue") then
			existingMap[child.Name] = child
		end
	end

	-- Agregar faltantes
	for _, id in ipairs(targets) do
		if existingMap[id] and not existingMap[id]:IsA("BoolValue") then
			existingMap[id]:Destroy()
			existingMap[id] = nil
		end
		if not existingMap[id] then
			local val = Instance.new("BoolValue")
			val.Name = id
			val.Value = true
			val.Parent = folder
		else
			existingMap[id].Value = true
		end
	end

	for name, child in pairs(existingMap) do
		if not table.find(targets, name) then
			child:Destroy()
		end
	end
end

-- Project: Aplica de forma idempotente los cambios del SessionView a la instancia Player
function StatsProjection.Project(player: any, view: SessionView)
	local profile = view.profile
	if not profile then
		return
	end

	-- 1. leaderstats
	local leaderstats = if typeof(player.FindFirstChild) == "function"
		then player:FindFirstChild("leaderstats")
		else nil

	if not leaderstats and typeof(Instance) == "table" and Instance.new then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	if leaderstats then
		local speedVal = ensureValue(leaderstats, "NumberValue", "Speed", profile.Speed or 0)
		if speedVal and speedVal.Value ~= profile.Speed then
			speedVal.Value = profile.Speed or 0
		end

		local winsVal = ensureValue(leaderstats, "IntValue", "Wins", profile.Wins or 0)
		if winsVal and winsVal.Value ~= profile.Wins then
			winsVal.Value = profile.Wins or 0
		end

		local rebirthsVal = ensureValue(leaderstats, "IntValue", "Rebirths", profile.Rebirths or 0)
		if rebirthsVal and rebirthsVal.Value ~= profile.Rebirths then
			rebirthsVal.Value = profile.Rebirths or 0
		end
	end

	-- 2. SpeedsterData
	local dataFolder = if typeof(player.FindFirstChild) == "function"
		then player:FindFirstChild("SpeedsterData")
		else nil

	if not dataFolder and typeof(Instance) == "table" and Instance.new then
		dataFolder = Instance.new("Folder")
		dataFolder.Name = "SpeedsterData"
		dataFolder.Parent = player
	end

	if dataFolder then
		local rawSpeed = ensureValue(dataFolder, "NumberValue", "RawSpeed", profile.Speed or 0)
		if rawSpeed and rawSpeed.Value ~= profile.Speed then
			rawSpeed.Value = profile.Speed or 0
		end

		-- Sincronizar cosméticos
		local ownedSkins = dataFolder:FindFirstChild("OwnedSkins") or (typeof(Instance) == "table" and Instance.new and Instance.new("Folder") or nil)
		if ownedSkins then
			ownedSkins.Name = "OwnedSkins"
			ownedSkins.Parent = dataFolder
			syncStringList(ownedSkins, profile.OwnedSkins)
		end

		local ownedTrails = dataFolder:FindFirstChild("OwnedTrails") or (typeof(Instance) == "table" and Instance.new and Instance.new("Folder") or nil)
		if ownedTrails then
			ownedTrails.Name = "OwnedTrails"
			ownedTrails.Parent = dataFolder
			syncStringList(ownedTrails, profile.OwnedTrails)
		end

		local ownedAuras = dataFolder:FindFirstChild("OwnedAuras") or (typeof(Instance) == "table" and Instance.new and Instance.new("Folder") or nil)
		if ownedAuras then
			ownedAuras.Name = "OwnedAuras"
			ownedAuras.Parent = dataFolder
			syncStringList(ownedAuras, profile.OwnedAuras)
		end

		local ownedUpgrades = dataFolder:FindFirstChild("OwnedUpgrades") or (typeof(Instance) == "table" and Instance.new and Instance.new("Folder") or nil)
		if ownedUpgrades then
			ownedUpgrades.Name = "OwnedUpgrades"
			ownedUpgrades.Parent = dataFolder
			syncStringList(ownedUpgrades, profile.OwnedUpgrades)
		end

		local eqTrail = dataFolder:FindFirstChild("EquippedTrail") or (typeof(Instance) == "table" and Instance.new and Instance.new("StringValue") or nil)
		if eqTrail then
			eqTrail.Name = "EquippedTrail"
			eqTrail.Value = profile.EquippedTrail or ""
			eqTrail.Parent = dataFolder
		end

		local eqAura = dataFolder:FindFirstChild("EquippedAura") or (typeof(Instance) == "table" and Instance.new and Instance.new("StringValue") or nil)
		if eqAura then
			eqAura.Name = "EquippedAura"
			eqAura.Value = profile.EquippedAura or ""
			eqAura.Parent = dataFolder
		end
	end

	-- 3. Atributos generales del jugador y estado
	if typeof(player.SetAttribute) == "function" then
		setAttributeIfChanged(player, "DataLoadFailed", false)
		setAttributeIfChanged(player, "LastLogoutTimestamp", profile.LastLogoutTimestamp or 0)
		setAttributeIfChanged(player, "LastAfkClaimTimestamp", profile.LastAfkClaimTimestamp or 0)
		setAttributeIfChanged(player, "SpinTickets", profile.SpinTickets or 0)

		-- Multipliers
		setAttributeIfChanged(player, "PermanentBaseSpeedMultiplier", profile.PermanentBaseSpeedMultiplier or 1)
		local winsMult = profile.PermanentWinsMultiplier or 1
		setAttributeIfChanged(player, "PermanentWinsMultiplier", winsMult)
		-- The Wins ladder does not unlock the x2 pads; the x2 pads gamepass does, and
		-- Roblox records that ownership. The only saved route is an admin grant.
		if table.find(profile.OwnedUpgrades or {}, "TwoXVictory") ~= nil then
			setAttributeIfChanged(player, "DoubleWinsPadUnlocked", true)
			setAttributeIfChanged(player, "TwoXVictoryOwned", true)
		end
		setAttributeIfChanged(player, "GlobalSpeedGainMultiplier", profile.GlobalSpeedGainMultiplier or 1)
		local ReplicatedStorage = game:GetService("ReplicatedStorage")
		local sharedFolder = ReplicatedStorage:FindFirstChild("Shared")
		local catalogModule = sharedFolder and sharedFolder:FindFirstChild("CosmeticCatalog")
		local trailMult = profile.TrailSpeedGainMultiplier or 1
		local auraMult = 1
		if catalogModule then
			local okCat, Catalog = pcall(require, catalogModule)
			if okCat and Catalog and type(Catalog.GetEntry) == "function" then
				local trailEntry = Catalog.GetEntry("Trail", profile.EquippedTrail or "")
				trailMult = trailEntry and (tonumber(trailEntry.SpeedMultiplier) or 1) or 1
				local auraEntry = Catalog.GetEntry("Aura", profile.EquippedAura or "")
				auraMult = auraEntry and (tonumber(auraEntry.SpeedMultiplier) or 1) or 1
			end
		end
		setAttributeIfChanged(player, "TrailSpeedGainMultiplier", trailMult)
		setAttributeIfChanged(player, "AuraSpeedGainMultiplier", auraMult)
		setAttributeIfChanged(player, "UpgradeSpeedGainMultiplier", profile.UpgradeSpeedGainMultiplier or 1)
		setAttributeIfChanged(player, "GamepassSpeedGainMultiplier", profile.GamepassSpeedGainMultiplier or 1)

		-- Equipped items
		setAttributeIfChanged(player, "EquippedSkin", profile.EquippedSkin or "")
		setAttributeIfChanged(player, "EquippedTrailId", profile.EquippedTrail or "")
		setAttributeIfChanged(player, "EquippedTrail", profile.EquippedTrail or "")
		setAttributeIfChanged(player, "EquippedAuraId", profile.EquippedAura or "")
		setAttributeIfChanged(player, "EquippedAura", profile.EquippedAura or "")

		-- Timers pause while offline and use the actor's sample time during a yielding save.
		for _,prefix in {"PotionSpeed","PotionWins"} do
			local remaining=profile[prefix.."RemainingSeconds"] or 0
			setAttributeIfChanged(player, prefix.."ExpireUnix", if remaining>0 then (view.buffSampleUnix or os.time())+remaining else 0)
			setAttributeIfChanged(player, prefix.."Multiplier", profile[prefix.."Multiplier"] or 2)
			setAttributeIfChanged(player, prefix.."Bottle", profile[prefix.."BottleType"] or "Small")
		end
		local upgrades=profile.OwnedUpgrades or {}
		local remaining=profile.TemporaryFlightRemainingSeconds or 0
		local expiry=if remaining>0 then (view.buffSampleUnix or os.time())+remaining else 0
		setAttributeIfChanged(player, "TemporaryFlightExpireUnix", expiry)
		local owned=table.find(upgrades,"Flight")~=nil or expiry>os.time()
		local initialized=table.find(upgrades,"__AbilityEquipStateInitialized")~=nil
		local equipped=owned and (not initialized or table.find(upgrades,"__AbilityEquipped_Flight")~=nil)
		setAttributeIfChanged(player, "FlightAbilityOwned", owned)
		setAttributeIfChanged(player, "FlightAbilityEquipped", equipped)
		setAttributeIfChanged(player, "EquippedAbility", if equipped then "Flight" else "")
		if not equipped then
			setAttributeIfChanged(player, "FlightAbilityActive", false)
			setAttributeIfChanged(player, "FlightAbilityPowered", false)
		end
		-- Progression flags
		setAttributeIfChanged(player, "World2Unlocked", profile.World2Unlocked == true)
		if player:GetAttribute("World3Unlocked") ~= (profile.World3Unlocked == true) then
			player:SetAttribute("World3Unlocked", profile.World3Unlocked == true)
		end
		setAttributeIfChanged(player, "FirstTimeTutorialSeen", profile.FirstTimeTutorialSeen == true)
		setAttributeIfChanged(player, "FirstRunEasyLevelsEligible", profile.FirstRunEasyLevelsEligible == true)
		setAttributeIfChanged(player, "StarterPackGranted", profile.StarterPackGranted == true)
		setAttributeIfChanged(player, "StarterPackRewardVersion", profile.StarterPackRewardVersion or 0)
		setAttributeIfChanged(player, "LastSeenUpdateLog", profile.LastSeenUpdateLog or 0)
		setAttributeIfChanged(player, "RobuxSpent", profile.RobuxSpent or 0)

		-- Settings
		if profile.Settings then
			for settingKey, settingVal in pairs(profile.Settings) do
				setAttributeIfChanged(player, settingKey, settingVal)
			end
		end

		-- Rebirth
		local rebirthCount = profile.Rebirths or 0
		local nextReqResult = StatsService.NextRebirthRequirement(rebirthCount, {})
		local nextReq = (nextReqResult.ok and nextReqResult.value) or (5 + rebirthCount * 15)
		setAttributeIfChanged(player, "NextRebirthSpeedRequired", nextReq)
		setAttributeIfChanged(player, "NextRebirthLevelRequired", nextReq)
		local rebirthMult = 1.5 ^ rebirthCount
		setAttributeIfChanged(player, "RebirthMultiplier", rebirthMult)
		setAttributeIfChanged(player, "RebirthSpeedGainMultiplier", rebirthMult)
		setAttributeIfChanged(player, "Rebirths", rebirthCount)
		setAttributeIfChanged(player, "RawSpeed", profile.Speed or 0)

		-- Daily login
		local daily = profile.DailyLoginState
		if daily then
			local csv = ""
			if daily.ClaimedDays then
				for i, d in ipairs(daily.ClaimedDays) do
					csv = csv .. (i > 1 and "," or "") .. tostring(d)
				end
			end
			setAttributeIfChanged(player, "DailyClaimedDaysCsv", csv)
			setAttributeIfChanged(player, "DailyLastClaimAt", daily.LastClaimAt or 0)
			setAttributeIfChanged(player, "DailyLastClaimedDay", daily.LastClaimedDay or 0)
			setAttributeIfChanged(player, "DailyRewardCycle", daily.Cycle or 1)
			setAttributeIfChanged(player, "DailyStateReady", true)
		else
			setAttributeIfChanged(player, "DailyClaimedDaysCsv", "")
			setAttributeIfChanged(player, "DailyStateReady", false)
		end
	end

	-- 4. Actualizar velocidad del personaje
	CharacterStatsAdapter.Update(player, profile.Speed or 0)

	-- 5. Señalar que todos los datos y atributos están completamente inicializados
	-- H3 (2026-09-25): Recovering (the last write is still unconfirmed and being retried) is
	-- loaded too: the session keeps earning and its value actions get Pending, which callers
	-- handle. DataSaveRetrying tells the UI a save is being retried.
	if typeof(player.SetAttribute) == "function" then
		player:SetAttribute("DataLoaded", view.state == "Ready" or view.state == "Ephemeral" or view.state == "Recovering")
		setAttributeIfChanged(player, "DataSaveRetrying", view.state == "Recovering")
	end
end

-- Attach: Conecta la proyección a un SessionHandle y un jugador
function StatsProjection.Attach(player: any, handle: SessionHandle, dataService: any)
	StatsProjection.Detach(handle)

	local inspectRes = dataService.Inspect(handle)
	if inspectRes.ok then
		StatsProjection.Project(player, inspectRes.value)
	end

	local unsub = dataService.Subscribe(handle, function(view: SessionView)
		StatsProjection.Project(player, view)
	end)

	activeUnsubscribes[handle.userId] = unsub
end

-- Detach: Desconecta la proyección activa del jugador (acepta handle, player o userId)
function StatsProjection.Detach(target: any)
	local uid = if typeof(target) == "table" and target.userId then
		target.userId
	elseif typeof(target) == "Instance" and target.UserId then
		target.UserId
	elseif typeof(target) == "number" then
		target
	else
		nil

	if uid then
		local unsub = activeUnsubscribes[uid]
		if unsub then
			unsub()
			activeUnsubscribes[uid] = nil
		end
	end
end

-- Destroy: Limpieza total
function StatsProjection.Destroy()
	for _, unsub in pairs(activeUnsubscribes) do
		unsub()
	end
	activeUnsubscribes = {}
end

return StatsProjection
