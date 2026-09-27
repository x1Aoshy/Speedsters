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
		player:SetAttribute("DataLoaded", view.state == "Ready" or view.state == "Ephemeral")
		player:SetAttribute("DataLoadFailed", false)

		-- Multipliers
		player:SetAttribute("PermanentBaseSpeedMultiplier", profile.PermanentBaseSpeedMultiplier or 1)
		local winsMult = profile.PermanentWinsMultiplier or 1
		player:SetAttribute("PermanentWinsMultiplier", winsMult)
		if winsMult >= 2 then
			player:SetAttribute("DoubleWinsPadUnlocked", true)
		end
		player:SetAttribute("GlobalSpeedGainMultiplier", profile.GlobalSpeedGainMultiplier or 1)
		player:SetAttribute("TrailSpeedGainMultiplier", profile.TrailSpeedGainMultiplier or 1)
		if player:GetAttribute("AuraSpeedGainMultiplier") == nil then
			player:SetAttribute("AuraSpeedGainMultiplier", 1)
		end
		player:SetAttribute("UpgradeSpeedGainMultiplier", profile.UpgradeSpeedGainMultiplier or 1)
		player:SetAttribute("GamepassSpeedGainMultiplier", profile.GamepassSpeedGainMultiplier or 1)

		-- Equipped items
		if profile.EquippedSkin then
			player:SetAttribute("EquippedSkin", profile.EquippedSkin)
		end
		if profile.EquippedTrail then
			player:SetAttribute("EquippedTrailId", profile.EquippedTrail)
		end
		if profile.EquippedAura then
			player:SetAttribute("EquippedAuraId", profile.EquippedAura)
		end

		-- Progression flags
		player:SetAttribute("World2Unlocked", profile.World2Unlocked == true)
		player:SetAttribute("FirstTimeTutorialSeen", profile.FirstTimeTutorialSeen == true)
		player:SetAttribute("FirstRunEasyLevelsEligible", profile.FirstRunEasyLevelsEligible == true)
		player:SetAttribute("StarterPackGranted", profile.StarterPackGranted == true)
		player:SetAttribute("StarterPackRewardVersion", profile.StarterPackRewardVersion or 0)
		player:SetAttribute("LastSeenUpdateLog", profile.LastSeenUpdateLog or 0)
		player:SetAttribute("RobuxSpent", profile.RobuxSpent or 0)

		-- Settings
		if profile.Settings then
			for settingKey, settingVal in pairs(profile.Settings) do
				player:SetAttribute(settingKey, settingVal)
			end
		end

		-- Rebirth
		local rebirthCount = profile.Rebirths or 0
		local nextReqResult = StatsService.NextRebirthRequirement(rebirthCount, {})
		local nextReq = (nextReqResult.ok and nextReqResult.value) or (5 + rebirthCount * 15)
		player:SetAttribute("NextRebirthSpeedRequired", nextReq)
		player:SetAttribute("NextRebirthLevelRequired", nextReq)
		local rebirthMult = 1.5 ^ rebirthCount
		player:SetAttribute("RebirthMultiplier", rebirthMult)
		player:SetAttribute("RebirthSpeedGainMultiplier", rebirthMult)
		player:SetAttribute("Rebirths", rebirthCount)
		player:SetAttribute("RawSpeed", profile.Speed or 0)

		-- Daily login
		local daily = profile.DailyLoginState
		if daily then
			local csv = ""
			if daily.ClaimedDays then
				for i, d in ipairs(daily.ClaimedDays) do
					csv = csv .. (i > 1 and "," or "") .. tostring(d)
				end
			end
			player:SetAttribute("DailyClaimedDaysCsv", csv)
			player:SetAttribute("DailyLastClaimAt", daily.LastClaimAt or 0)
			player:SetAttribute("DailyLastClaimedDay", daily.LastClaimedDay or 0)
			player:SetAttribute("DailyRewardCycle", daily.Cycle or 1)
			player:SetAttribute("DailyStateReady", true)
		else
			player:SetAttribute("DailyClaimedDaysCsv", "")
			player:SetAttribute("DailyStateReady", false)
		end
	end

	-- 4. Actualizar velocidad del personaje
	CharacterStatsAdapter.Update(player, profile.Speed or 0)
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
