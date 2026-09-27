local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

if _G.SpeedsterModularActive or Config.UseModularDataService then
	warn("[PlayerStats.legacy] Modular DataService is ACTIVE (Config.UseModularDataService = true). Legacy PlayerStats disabled to prevent double-writer collisions.")
	return
end
local SuitCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SuitCatalog"))
local ServerScriptService = game:GetService("ServerScriptService")
local PotionServer = require(ServerScriptService:WaitForChild("Services"):WaitForChild("PotionServer"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local BoostState = Remotes:FindFirstChild("BoostState")
if not BoostState then
	BoostState = Instance.new("RemoteEvent")
	BoostState.Name = "BoostState"
	BoostState.Parent = Remotes
end

local SpeedGainPopup = Remotes:FindFirstChild("SpeedGainPopup")
if not SpeedGainPopup then
	SpeedGainPopup = Instance.new("RemoteEvent")
	SpeedGainPopup.Name = "SpeedGainPopup"
	SpeedGainPopup.Parent = Remotes
end

local WalkSpeedModeRequest = Remotes:FindFirstChild("WalkSpeedModeRequest")
if not WalkSpeedModeRequest then
	WalkSpeedModeRequest = Instance.new("RemoteEvent")
	WalkSpeedModeRequest.Name = "WalkSpeedModeRequest"
	WalkSpeedModeRequest.Parent = Remotes
end

local DataStore = DataStoreService:GetDataStore(Config.DataStoreName)
local serverInstanceId = game.JobId ~= "" and game.JobId or ("studio-" .. HttpService:GenerateGUID(false))

local lastSaveAt = {}
local savingNow = {}
local pendingSaveReasons = {}
local pendingSaveTickets = {}
local nextSaveTicket = {}
local lastSuccessfulSaveTicket = {}
local finalSaveRequested = {}
local sessionIdByPlayer = {}
local processedReceiptsByPlayer = {}
local lastBoostUseAt = {}
local boostMaxByPlayer = {}
local boostStaminaByPlayer = {}

local MAX_SAVED_RECEIPT_IDS = 200

-- Settings toggled in the Settings panel and persisted per-player.
-- All default ON except HideHud (OFF by default so the HUD is visible).
local SETTING_DEFAULTS = {
	Muted = false, -- button shows ON when not muted
	SoundEffects = true,
	GlobalMessages = true,
	PromptRevivals = true,
	HideHud = false,
	HidePopups = false,
	AcceptGifts = true,
	EventEffects = true,
	MusicVolume = 100,
	SfxVolume = 100,
}
local SettingsByPlayer = {}

local function cleanSettings(value)
	local cleaned = {}
	for attr, default in pairs(SETTING_DEFAULTS) do
		if type(value) == "table" and value[attr] ~= nil then
			cleaned[attr] = value[attr] == true
		else
			cleaned[attr] = default
		end
	end
	return cleaned
end

local function applySettingsToPlayer(player, settings)
	local cleaned = cleanSettings(settings)
	for attr, value in pairs(cleaned) do
		player:SetAttribute(attr, value)
	end
end

local function badNumber(value)
	return value ~= value or value == math.huge or value == -math.huge
end

local function cleanSpeed(value)
	value = tonumber(value) or Config.StartingSpeed

	if badNumber(value) then
		value = Config.MaxStoredSpeed
	end

	value = math.max(Config.StartingSpeed, value)
	value = math.min(Config.MaxStoredSpeed, value)

	return value
end

local function cleanInt(value)
	value = tonumber(value) or 0

	if badNumber(value) or value < 0 then
		return 0
	end

	return math.floor(value)
end

local function cleanMultiplier(value)
	value = tonumber(value) or 1

	if badNumber(value) or value < 0 then
		return 1
	end

	return value
end


local function getSuitSpeedGainMultiplierForSkin(skinId)
	skinId = tostring(skinId or "")

	local defaultMultiplier = tonumber(Config.DefaultSuitSpeedGainMultiplier) or 1
	local multipliers = Config.SuitSpeedGainMultipliers

	if type(multipliers) == "table" then
		local value = multipliers[skinId]
		if value ~= nil then
			return cleanMultiplier(value)
		end
	end

	return cleanMultiplier(defaultMultiplier)
end

local function syncSuitSpeedGainMultiplier(player)
	local skinId = player:GetAttribute("EquippedSkin") or ""
	local multiplier = getSuitSpeedGainMultiplierForSkin(skinId)

	player:SetAttribute("SuitSpeedGainMultiplier", multiplier)
	player:SetAttribute("SkinSpeedGainMultiplier", multiplier)
end

local function getKey(player)
	return "Player_" .. player.UserId
end

local function getCharacter(player)
	local character = player.Character
	if not character then
		return nil, nil, nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	return character, humanoid, root
end

local function getLeaderstats(player)
	return player:FindFirstChild("leaderstats")
end

local function getDataFolder(player)
	local folder = player:FindFirstChild("SpeedsterData")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "SpeedsterData"
		folder.Parent = player
	end
	return folder
end

local function getSpeed(player)
	local leaderstats = getLeaderstats(player)
	return leaderstats and leaderstats:FindFirstChild("Speed")
end

local function getRawSpeed(player)
	local folder = getDataFolder(player)
	return folder:FindFirstChild("RawSpeed")
end

local function getWins(player)
	local leaderstats = getLeaderstats(player)
	return leaderstats and leaderstats:FindFirstChild("Wins")
end

local function getRebirths(player)
	local leaderstats = getLeaderstats(player)
	return leaderstats and leaderstats:FindFirstChild("Rebirths")
end

local function ensureNumberValue(parent, name, value)
	local object = parent:FindFirstChild(name)

	if object and not object:IsA("NumberValue") then
		object:Destroy()
		object = nil
	end

	if not object then
		object = Instance.new("NumberValue")
		object.Name = name
		object.Parent = parent
	end

	object.Value = cleanSpeed(value)
	return object
end

local function ensureIntValue(parent, name, value)
	local object = parent:FindFirstChild(name)

	if object and not object:IsA("IntValue") then
		object:Destroy()
		object = nil
	end

	if not object then
		object = Instance.new("IntValue")
		object.Name = name
		object.Parent = parent
	end

	object.Value = cleanInt(value)
	return object
end

local function ensureStringValue(parent, name, value)
	local object = parent:FindFirstChild(name)

	if object and not object:IsA("StringValue") then
		object:Destroy()
		object = nil
	end

	if not object then
		object = Instance.new("StringValue")
		object.Name = name
		object.Parent = parent
	end

	object.Value = tostring(value or "")
	return object
end

local function ensureFolder(parent, name)
	local folder = parent:FindFirstChild(name)

	if folder and not folder:IsA("Folder") then
		folder:Destroy()
		folder = nil
	end

	if not folder then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parent
	end

	return folder
end

local function listToFolder(parent, folderName, list)
	local folder = ensureFolder(parent, folderName)
	folder:ClearAllChildren()

	if type(list) ~= "table" then
		return folder
	end

	for _, item in ipairs(list) do
		if type(item) == "string" and item ~= "" then
			local value = Instance.new("BoolValue")
			value.Name = item
			value.Value = true
			value.Parent = folder
		end
	end

	return folder
end

local function folderToList(folder)
	local list = {}

	if not folder then
		return list
	end

	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("BoolValue") and child.Value == true then
			table.insert(list, child.Name)
		end
	end

	table.sort(list)
	return list
end

local function setDefaultMultiplierAttributes(player)
	if player:GetAttribute("GlobalSpeedGainMultiplier") == nil then
		player:SetAttribute("GlobalSpeedGainMultiplier", Config.DefaultGlobalSpeedGainMultiplier)
	end

	if player:GetAttribute("TrailSpeedGainMultiplier") == nil then
		player:SetAttribute("TrailSpeedGainMultiplier", Config.DefaultTrailSpeedGainMultiplier)
	end

	if player:GetAttribute("AuraSpeedGainMultiplier") == nil then
		player:SetAttribute("AuraSpeedGainMultiplier", Config.DefaultAuraSpeedGainMultiplier or 1)
	end

	if player:GetAttribute("UpgradeSpeedGainMultiplier") == nil then
		player:SetAttribute("UpgradeSpeedGainMultiplier", Config.DefaultUpgradeSpeedGainMultiplier)
	end

	if player:GetAttribute("GamepassSpeedGainMultiplier") == nil then
		player:SetAttribute("GamepassSpeedGainMultiplier", Config.DefaultGamepassSpeedGainMultiplier)
	end

	if player:GetAttribute("VIPSpeedGainMultiplier") == nil then
		player:SetAttribute("VIPSpeedGainMultiplier", 1)
	end

	if player:GetAttribute("VIPWinsMultiplier") == nil then
		player:SetAttribute("VIPWinsMultiplier", 1)
	end

	if player:GetAttribute("PermanentBaseSpeedMultiplier") == nil then
		player:SetAttribute("PermanentBaseSpeedMultiplier", Config.PermanentBaseSpeedMultiplierDefault or 1)
	end

	if player:GetAttribute("RebirthSpeedGainMultiplier") == nil then
		player:SetAttribute("RebirthSpeedGainMultiplier", 1)
	end

	if player:GetAttribute("SuitSpeedGainMultiplier") == nil then
		player:SetAttribute("SuitSpeedGainMultiplier", Config.DefaultSuitSpeedGainMultiplier or 1)
	end

	if player:GetAttribute("SkinSpeedGainMultiplier") == nil then
		player:SetAttribute("SkinSpeedGainMultiplier", Config.DefaultSuitSpeedGainMultiplier or 1)
	end
end

local function getTotalGainMultiplier(player)
	setDefaultMultiplierAttributes(player)

	local global = cleanMultiplier(player:GetAttribute("GlobalSpeedGainMultiplier"))
	local trail = cleanMultiplier(player:GetAttribute("TrailSpeedGainMultiplier"))
	local aura = cleanMultiplier(player:GetAttribute("AuraSpeedGainMultiplier"))
	local upgrade = cleanMultiplier(player:GetAttribute("UpgradeSpeedGainMultiplier"))
	local gamepass = cleanMultiplier(player:GetAttribute("GamepassSpeedGainMultiplier"))
	local suit = cleanMultiplier(player:GetAttribute("SuitSpeedGainMultiplier"))
	local rebirth = cleanMultiplier(player:GetAttribute("RebirthSpeedGainMultiplier"))
	local vip = cleanMultiplier(player:GetAttribute("VIPSpeedGainMultiplier"))

	local total = global * trail * aura * upgrade * gamepass * suit * rebirth * vip
	if badNumber(total) then
		return 1
	end

	return math.max(0, total)
end

local function getPermanentBaseSpeedMultiplier(player)
	setDefaultMultiplierAttributes(player)
	local multiplier = cleanMultiplier(player:GetAttribute("PermanentBaseSpeedMultiplier"))
	return math.max(1, multiplier)
end


local function getNextRebirthLevelRequirement(rebirthCount)
	rebirthCount = cleanInt(rebirthCount)

	local firstRequired = tonumber(Config.RebirthFirstLevelRequired) or 5
	local step = tonumber(Config.RebirthLevelStep) or 15

	if rebirthCount <= 0 then
		return firstRequired
	end

	return firstRequired + (rebirthCount * step)
end

local function getRebirthSpeedGainMultiplier(rebirthCount)
	rebirthCount = cleanInt(rebirthCount)

	local perRebirth = tonumber(Config.RebirthMultiplierPerRebirth) or 1.5
	local multiplier = 1

	for _ = 1, rebirthCount do
		multiplier *= perRebirth

		if badNumber(multiplier) then
			return Config.MaxStoredSpeed or 1e50
		end

		if multiplier > (Config.MaxStoredSpeed or 1e50) then
			return Config.MaxStoredSpeed or 1e50
		end
	end

	return multiplier
end

local function syncRebirthAttributes(player)
	local rebirthsValue = getRebirths(player)
	local rebirthCount = rebirthsValue and cleanInt(rebirthsValue.Value) or 0
	local multiplier = getRebirthSpeedGainMultiplier(rebirthCount)

	player:SetAttribute("Rebirths", rebirthCount)
	player:SetAttribute("RebirthSpeedGainMultiplier", multiplier)
	player:SetAttribute("RebirthMultiplier", multiplier)
	player:SetAttribute("NextRebirthLevelRequired", getNextRebirthLevelRequirement(rebirthCount))
end

local function syncRawFromLeaderboard(player)
	local speed = getSpeed(player)
	local raw = getRawSpeed(player)

	if speed and raw then
		local cleaned = cleanSpeed(speed.Value)
		if raw.Value ~= cleaned then
			raw.Value = cleaned
		end
	end
end

local function syncLeaderboardFromRaw(player)
	local speed = getSpeed(player)
	local raw = getRawSpeed(player)

	if speed and raw then
		local cleaned = cleanSpeed(raw.Value)
		if speed.Value ~= cleaned then
			speed.Value = cleaned
		end
	end
end

local function calculateSmoothWalkSpeed(speedValue)
	local minSpeed = Config.RealWalkSpeedMin or 8
	local referenceDisplayedSpeed = Config.RealWalkSpeedReferenceDisplayedSpeed or 3.37e15
	local walkSpeedAtReference = Config.RealWalkSpeedAtReference or 300
	local curve = Config.RealWalkSpeedCurve or 2

	speedValue = math.max(1, tonumber(speedValue) or 1)
	referenceDisplayedSpeed = math.max(2, tonumber(referenceDisplayedSpeed) or 3.37e15)
	walkSpeedAtReference = math.max(minSpeed + 1, tonumber(walkSpeedAtReference) or 300)

	local progress = math.log10(speedValue) / math.log10(referenceDisplayedSpeed)
	progress = math.max(0, progress)
	progress = progress ^ curve

	local walkSpeed = minSpeed + (progress * (walkSpeedAtReference - minSpeed))
	return math.max(minSpeed, walkSpeed)
end

local function getWalkSpeedSelectorMultiplier(player)
	local defaultMode = Config.WalkSpeedSelectorDefaultMode or "Red"
	local mode = tostring(player:GetAttribute("WalkSpeedMode") or defaultMode)
	if mode == "Custom" then
		return "Custom", 1
	end
	local multipliers = Config.WalkSpeedSelectorMultipliers or {}
	local multiplier = tonumber(multipliers[mode])

	if not multiplier or multiplier <= 0 or badNumber(multiplier) then
		mode = defaultMode
		multiplier = tonumber(multipliers[mode]) or 1
	end

	return mode, multiplier
end

local function calculateMaxWalkSpeed(player)
	local rawSpeed = getRawSpeed(player)
	local speedValue = rawSpeed and cleanSpeed(rawSpeed.Value) or Config.StartingSpeed

	local walkSpeed

	if Config.UseSmoothRealSpeedFormula then
		walkSpeed = calculateSmoothWalkSpeed(speedValue)
	else
		walkSpeed = Config.BaseWalkSpeed + (speedValue * Config.SpeedToWalkSpeedMultiplier)

		if Config.UseWalkSpeedCap then
			walkSpeed = math.min(walkSpeed, Config.MaxWalkSpeed)
		end
	end

	if badNumber(walkSpeed) then
		walkSpeed = Config.RealWalkSpeedMin or Config.BaseWalkSpeed
	end

	if Config.IsWorld2Place == true then
		local worldScale = tonumber(Config.World2WalkSpeedMultiplier) or (1 / 3)
		walkSpeed *= math.clamp(worldScale, 0.01, 1)
	end

	return walkSpeed
end

local function calculateWalkSpeedDetails(player)
	local maxWalkSpeed = calculateMaxWalkSpeed(player)
	local mode, selectorMultiplier = getWalkSpeedSelectorMultiplier(player)
	local selectedWalkSpeed = maxWalkSpeed * selectorMultiplier

	if mode == "Custom" then
		local customSpeed = tonumber(player:GetAttribute("CustomWalkSpeed"))
		if customSpeed and not badNumber(customSpeed) and customSpeed > 0 then
			selectedWalkSpeed = math.clamp(customSpeed, Config.RealWalkSpeedMin or 8, maxWalkSpeed)
			selectorMultiplier = maxWalkSpeed > 0 and (selectedWalkSpeed / maxWalkSpeed) or 1
		end
	end

	if badNumber(selectedWalkSpeed) or selectedWalkSpeed < 0 then
		selectedWalkSpeed = maxWalkSpeed
		mode = Config.WalkSpeedSelectorDefaultMode or "Red"
		selectorMultiplier = 1
	end

	local actualWalkSpeed = selectedWalkSpeed

	if player:GetAttribute("IsBoosting") == true and not Config.InstantMovementControllerEnabled then
		actualWalkSpeed *= (Config.BoostWalkSpeedMultiplier or 1.7)
	end

	return actualWalkSpeed, maxWalkSpeed, selectedWalkSpeed, mode, selectorMultiplier
end

local function setNumberAttributeIfChanged(player, name, value)
	local oldValue = player:GetAttribute(name)
	if type(oldValue) ~= "number" or math.abs(oldValue - value) > 0.000001 then
		player:SetAttribute(name, value)
	end
end

local function applyWalkSpeed(player)
	local actualWalkSpeed, maxWalkSpeed, selectedWalkSpeed, mode, selectorMultiplier = calculateWalkSpeedDetails(player)

	setNumberAttributeIfChanged(player, "RealWalkSpeedMax", maxWalkSpeed)
	setNumberAttributeIfChanged(player, "RealWalkSpeedSelected", selectedWalkSpeed)
	setNumberAttributeIfChanged(player, "WalkSpeedModeScale", selectorMultiplier)
	setNumberAttributeIfChanged(
		player,
		"WorldMovementSpeedScale",
		Config.IsWorld2Place == true
			and math.clamp(tonumber(Config.World2WalkSpeedMultiplier) or (1 / 3), 0.01, 1)
			or 1
	)

	if player:GetAttribute("WalkSpeedMode") ~= mode then
		player:SetAttribute("WalkSpeedMode", mode)
	end

	local _, humanoid = getCharacter(player)
	if humanoid then
		humanoid.WalkSpeed = actualWalkSpeed
	end
end

local function getBaseStaminaMax()
	return Config.BoostStaminaDisplayBase or 17
end

local function getSuitStaminaMax(skinId)
	local configured = Config.SuitStaminaMax
	local value = type(configured) == "table" and tonumber(configured[skinId]) or nil
	if value and value > 0 then
		return value
	end

	local entry = SuitCatalog.Get(skinId)
	value = entry and tonumber(entry.Stamina) or nil
	if value and value > 0 then
		return value
	end

	return getBaseStaminaMax()
end

local function getBoostMaxStamina(player)
	local maxStamina = boostMaxByPlayer[player]

	if type(maxStamina) == "number" and maxStamina > 0 then
		return maxStamina
	end

	maxStamina = getBaseStaminaMax()
	boostMaxByPlayer[player] = maxStamina
	return maxStamina
end

local function syncBoostStaminaAttributes(player)
	local maxStamina = getBoostMaxStamina(player)
	local stamina = boostStaminaByPlayer[player]

	if type(stamina) ~= "number" then
		stamina = maxStamina
		boostStaminaByPlayer[player] = stamina
	end

	if stamina > maxStamina then
		stamina = maxStamina
		boostStaminaByPlayer[player] = stamina
	elseif stamina < 0 then
		stamina = 0
		boostStaminaByPlayer[player] = stamina
	end

	player:SetAttribute("TrueBoostStaminaMax", maxStamina)
	player:SetAttribute("TrueBoostStamina", stamina)

	player:SetAttribute("BoostStaminaMaxInternal", maxStamina)
	player:SetAttribute("BoostStaminaDisplayMax", maxStamina)
	player:SetAttribute("BoostStamina", stamina)
end

local function setBoostStaminaMax(player, maxStamina, refill)
	maxStamina = tonumber(maxStamina) or getBaseStaminaMax()

	if maxStamina <= 0 then
		maxStamina = getBaseStaminaMax()
	end

	boostMaxByPlayer[player] = maxStamina

	local stamina = boostStaminaByPlayer[player]
	if refill == true or type(stamina) ~= "number" then
		stamina = maxStamina
	elseif stamina > maxStamina then
		stamina = maxStamina
	end

	boostStaminaByPlayer[player] = stamina
	syncBoostStaminaAttributes(player)
end

local function setEquippedSuitStamina(player, skinId)
	local suitMax = getSuitStaminaMax(skinId)

	player:SetAttribute("FlashStaminaActive", true)
	player:SetAttribute("FlashStaminaUpgrade", true)
	syncSuitSpeedGainMultiplier(player)

	setBoostStaminaMax(player, suitMax, true)

	for _, delayTime in ipairs({0, 0.1, 0.35, 0.75, 1.5}) do
		task.delay(delayTime, function()
			if player.Parent and player:GetAttribute("EquippedSkin") == skinId then
				setBoostStaminaMax(player, suitMax, true)
			end
		end)
	end

	print(
		"[PlayerStats] V306CV suit stamina | "
			.. tostring(skinId)
			.. "="
			.. tostring(suitMax)
			.. "/"
			.. tostring(suitMax)
			.. " for "
			.. player.Name
	)
end

local setBaseStamina

local function restoreEquippedSkinStamina(player, reason)
	local equippedSkin = tostring(player:GetAttribute("EquippedSkin") or "")

	if SuitCatalog.IsValid(equippedSkin) then
		setEquippedSuitStamina(player, equippedSkin)
		print(
			"[PlayerStats] V306CV restored "
				.. equippedSkin
				.. " stamina after "
				.. tostring(reason)
				.. " for "
				.. player.Name
		)
	else
		setBaseStamina(player)
	end
end

setBaseStamina = function(player)
	local baseMax = getBaseStaminaMax()

	player:SetAttribute("FlashStaminaActive", false)
	player:SetAttribute("FlashStaminaUpgrade", false)
	syncSuitSpeedGainMultiplier(player)

	setBoostStaminaMax(player, baseMax, false)

	print("[PlayerStats] V306CV no-suit stamina max = " .. tostring(baseMax) .. " for " .. player.Name)
end

local function cleanProcessedReceipts(value)
	local entries = {}

	if type(value) == "table" then
		for key, storedValue in pairs(value) do
			local receiptId = nil
			local processedAt = 0

			if type(key) == "string" and key ~= "" then
				receiptId = key
				if type(storedValue) == "number" then
					processedAt = cleanInt(storedValue)
				elseif storedValue ~= true then
					receiptId = nil
				end
			elseif type(key) == "number" and type(storedValue) == "string" and storedValue ~= "" then
				                                                 
				receiptId = storedValue
			end

			if receiptId then
				table.insert(entries, {
					Id = receiptId,
					ProcessedAt = processedAt,
				})
			end
		end
	end

	table.sort(entries, function(left, right)
		if left.ProcessedAt == right.ProcessedAt then
			return left.Id < right.Id
		end
		return left.ProcessedAt > right.ProcessedAt
	end)

	local cleaned = {}
	for index = 1, math.min(#entries, MAX_SAVED_RECEIPT_IDS) do
		local entry = entries[index]
		cleaned[entry.Id] = entry.ProcessedAt
	end

	return cleaned
end

local function copyProcessedReceipts(player)
	return cleanProcessedReceipts(processedReceiptsByPlayer[player])
end

local function cleanDailyLoginState(value)
	if type(value) ~= "table" then
		return nil
	end

	local claimedDays = {}
	local seen = {}
	if type(value.ClaimedDays) == "table" then
		for _, dayValue in ipairs(value.ClaimedDays) do
			local day = math.floor(tonumber(dayValue) or 0)
			if day >= 1 and day <= 30 and not seen[day] then
				seen[day] = true
				table.insert(claimedDays, day)
			end
		end
	end
	table.sort(claimedDays)

	return {
		ClaimedDays = claimedDays,
		LastClaimAt = cleanInt(value.LastClaimAt),
		LastClaimedDay = math.clamp(cleanInt(value.LastClaimedDay), 0, 30),
		Cycle = math.max(1, cleanInt(value.Cycle)),
	}
end

local function dailyDaysToCsv(days)
	local cleaned = cleanDailyLoginState({ ClaimedDays = days })
	local textDays = {}
	for _, day in ipairs(cleaned and cleaned.ClaimedDays or {}) do
		table.insert(textDays, tostring(day))
	end
	return table.concat(textDays, ",")
end

local function dailyDaysFromCsv(csv)
	local days = {}
	for token in string.gmatch(tostring(csv or ""), "[^,]+") do
		table.insert(days, tonumber(token))
	end
	local cleaned = cleanDailyLoginState({ ClaimedDays = days })
	return cleaned and cleaned.ClaimedDays or {}
end

local function makeDefaultSave()
	local defaultSkinId = SuitCatalog.DefaultSkinId or "FlashSuit"
	return {
		Version = 306,
		Speed = Config.StartingSpeed,
		Wins = 0,
		Rebirths = 0,
		RobuxSpent = 0,

		GlobalSpeedGainMultiplier = Config.DefaultGlobalSpeedGainMultiplier,
		TrailSpeedGainMultiplier = Config.DefaultTrailSpeedGainMultiplier,
		UpgradeSpeedGainMultiplier = Config.DefaultUpgradeSpeedGainMultiplier,
		GamepassSpeedGainMultiplier = Config.DefaultGamepassSpeedGainMultiplier,
		PermanentBaseSpeedMultiplier = Config.PermanentBaseSpeedMultiplierDefault or 1,
		PermanentWinsMultiplier = Config.PermanentWinsMultiplierDefault or 1,
		StarterPackGranted = false,
		StarterPackRewardVersion = 0,
		World2Unlocked = false,
		FirstTimeTutorialSeen = false,
		                                                                      
		                                                                           
		FirstRunEasyLevelsEligible = true,

		EquippedSkin = defaultSkinId,
		OwnedSkins = { defaultSkinId },
		EquippedTrail = "",
		OwnedTrails = {},
		EquippedAura = "",
		OwnedAuras = {},
		OwnedUpgrades = {},
		ProcessedReceipts = {},
		PotionSpeedRemainingSeconds = 0,
		PotionWinsRemainingSeconds = 0,
		Settings = cleanSettings(nil),
		LastSeenUpdateLog = 0,
	}
end

local function normalizeOwnedSkins(value, equippedSkin)
	local cleaned = {}
	local seen = {}

	local function include(skinId)
		skinId = tostring(skinId or "")
		if SuitCatalog.IsValid(skinId) and not seen[skinId] then
			seen[skinId] = true
			table.insert(cleaned, skinId)
		end
	end

	if type(value) == "table" then
		for _, skinId in ipairs(value) do
			include(skinId)
		end
	end

	include(SuitCatalog.DefaultSkinId or "FlashSuit")
	include(equippedSkin)
	return cleaned
end

local function cleanLoadedData(data)
	local clean = makeDefaultSave()

	if type(data) == "table" then
		clean.Speed = cleanSpeed(data.Speed)
		clean.Wins = cleanInt(data.Wins)
		clean.Rebirths = cleanInt(data.Rebirths)
		clean.RobuxSpent = cleanInt(data.RobuxSpent)

		clean.GlobalSpeedGainMultiplier = cleanMultiplier(data.GlobalSpeedGainMultiplier)
		clean.TrailSpeedGainMultiplier = cleanMultiplier(data.TrailSpeedGainMultiplier)
		clean.UpgradeSpeedGainMultiplier = cleanMultiplier(data.UpgradeSpeedGainMultiplier)
		clean.GamepassSpeedGainMultiplier = cleanMultiplier(data.GamepassSpeedGainMultiplier)
		clean.PermanentBaseSpeedMultiplier = math.max(1, cleanMultiplier(data.PermanentBaseSpeedMultiplier))
		clean.PermanentWinsMultiplier = math.max(1, cleanMultiplier(data.PermanentWinsMultiplier))
		clean.StarterPackGranted = data.StarterPackGranted == true
		clean.StarterPackRewardVersion = math.max(0, cleanInt(data.StarterPackRewardVersion))
		clean.World2Unlocked = data.World2Unlocked == true
		                                                                         
		                                                                       
		                                                                           
		if data.FirstTimeTutorialSeen == nil then
			clean.FirstTimeTutorialSeen = true
		else
			clean.FirstTimeTutorialSeen = data.FirstTimeTutorialSeen == true
		end

		                                                                        
		                                                                     
		                         
		if data.FirstRunEasyLevelsEligible == nil then
			clean.FirstRunEasyLevelsEligible = false
		else
			clean.FirstRunEasyLevelsEligible = data.FirstRunEasyLevelsEligible == true
		end

		if type(data.EquippedSkin) == "string" then
			clean.EquippedSkin = data.EquippedSkin
		end

		if type(data.OwnedSkins) == "table" then
			clean.OwnedSkins = data.OwnedSkins
		end

		if type(data.EquippedTrail) == "string" then
			clean.EquippedTrail = data.EquippedTrail
		end

		if type(data.OwnedTrails) == "table" then
			clean.OwnedTrails = data.OwnedTrails
		end

		if type(data.EquippedAura) == "string" then
			clean.EquippedAura = data.EquippedAura
		end

		if type(data.OwnedAuras) == "table" then
			clean.OwnedAuras = data.OwnedAuras
		end

		if type(data.OwnedUpgrades) == "table" then
			clean.OwnedUpgrades = data.OwnedUpgrades
		end

		clean.ProcessedReceipts = cleanProcessedReceipts(data.ProcessedReceipts)
		clean.PotionSpeedRemainingSeconds = math.max(0, cleanInt(data.PotionSpeedRemainingSeconds))
		clean.PotionWinsRemainingSeconds = math.max(0, cleanInt(data.PotionWinsRemainingSeconds))
		clean.DailyLoginState = cleanDailyLoginState(data.DailyLoginState)
		clean.Settings = cleanSettings(data.Settings)
		clean.LastSeenUpdateLog = math.max(0, cleanInt(data.LastSeenUpdateLog))
	end

	if not SuitCatalog.IsValid(clean.EquippedSkin) then
		clean.EquippedSkin = SuitCatalog.DefaultSkinId or "FlashSuit"
	end
	clean.OwnedSkins = normalizeOwnedSkins(clean.OwnedSkins, clean.EquippedSkin)

	return clean
end

local function releaseDataSession(player, sessionId)
	if not sessionId then
		return
	end
	local ok, err = pcall(function()
		DataStore:UpdateAsync(getKey(player), function(current)
			if type(current) == "table" and current.ActiveSessionId == sessionId then
				current.ActiveSessionId = nil
				current.ActiveSessionStartedUnixMs = nil
				current.ActiveSessionExpiresUnix = nil
			end
			return current
		end)
	end)
	if not ok then
		warn("[PlayerStats] Could not release abandoned load session for " .. player.Name .. ": " .. tostring(err))
	end
end

local function loadData(player)
	local sessionId = serverInstanceId
		.. ":"
		.. tostring(player.UserId)
		.. ":"
		.. HttpService:GenerateGUID(false)
	local sessionStartedUnixMs = DateTime.now().UnixTimestampMillis
	local lastError = nil

	sessionIdByPlayer[player] = sessionId

	for attempt = 1, (Config.LoadRetryCount or 3) do
		if player.Parent ~= Players then
			releaseDataSession(player, sessionId)
			sessionIdByPlayer[player] = nil
			return nil, "player left while data was loading"
		end

		local blockedByActiveSession = false
		local success, result = pcall(function()
			return DataStore:UpdateAsync(getKey(player), function(current)
				blockedByActiveSession = false
				local currentSessionId = type(current) == "table" and current.ActiveSessionId or nil
				local currentSessionExpires = type(current) == "table"
					and tonumber(current.ActiveSessionExpiresUnix)
					or 0
				if currentSessionId
					and currentSessionId ~= sessionId
					and currentSessionExpires > os.time()
				then
					blockedByActiveSession = true
					return nil
				end

				local claimed = cleanLoadedData(current)
				claimed.ActiveSessionId = sessionId
				claimed.ActiveSessionStartedUnixMs = sessionStartedUnixMs
				claimed.ActiveSessionExpiresUnix = os.time() + (Config.SessionLeaseSeconds or 120)
				return claimed
			end)
		end)

		if success and not blockedByActiveSession and type(result) == "table" then
			if player.Parent ~= Players then
				releaseDataSession(player, sessionId)
				sessionIdByPlayer[player] = nil
				return nil, "player left while data was loading"
			end
			player:SetAttribute("SessionDataOnly", false)
			return cleanLoadedData(result)
		end

		lastError = blockedByActiveSession
			and "the previous server session is still finishing its final save"
			or result
		warn(
			"[PlayerStats] Safe data load attempt "
				.. tostring(attempt)
				.. " failed for "
				.. player.Name
				.. ": "
				.. tostring(lastError)
		)

		if attempt < (Config.LoadRetryCount or 3) then
			task.wait(Config.LoadRetryDelay or 1)
		end
	end

	                                                                            
	                                                                       
	if RunService:IsStudio() then
		if player.Parent ~= Players then
			releaseDataSession(player, sessionId)
			sessionIdByPlayer[player] = nil
			return nil, "player left while data was loading"
		end
		releaseDataSession(player, sessionId)
		sessionIdByPlayer[player] = nil
		player:SetAttribute("SessionDataOnly", true)
		warn("[PlayerStats] Studio data unavailable; using a non-saving test session for " .. player.Name)
		return makeDefaultSave()
	end

	releaseDataSession(player, sessionId)
	sessionIdByPlayer[player] = nil
	return nil, lastError
end

local function createStats(player, data)
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats and not leaderstats:IsA("Folder") then
		leaderstats:Destroy()
		leaderstats = nil
	end

	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	             
	                                                                               
	local speed = ensureNumberValue(leaderstats, "Speed", data.Speed)
	ensureIntValue(leaderstats, "Wins", data.Wins)
	local rebirths = ensureIntValue(leaderstats, "Rebirths", data.Rebirths)

	local dataFolder = getDataFolder(player)
	local rawSpeed = ensureNumberValue(dataFolder, "RawSpeed", data.Speed)
	listToFolder(dataFolder, "OwnedSkins", data.OwnedSkins)
	ensureStringValue(dataFolder, "EquippedTrail", data.EquippedTrail)
	listToFolder(dataFolder, "OwnedTrails", data.OwnedTrails)
	ensureStringValue(dataFolder, "EquippedAura", data.EquippedAura)
	listToFolder(dataFolder, "OwnedAuras", data.OwnedAuras)
	listToFolder(dataFolder, "OwnedUpgrades", data.OwnedUpgrades)
	processedReceiptsByPlayer[player] = cleanProcessedReceipts(data.ProcessedReceipts)

	local dailyState = cleanDailyLoginState(data.DailyLoginState)
	if dailyState then
		player:SetAttribute("DailyClaimedDaysCsv", dailyDaysToCsv(dailyState.ClaimedDays))
		player:SetAttribute("DailyLastClaimAt", dailyState.LastClaimAt)
		player:SetAttribute("DailyLastClaimedDay", dailyState.LastClaimedDay)
		player:SetAttribute("DailyRewardCycle", dailyState.Cycle)
		player:SetAttribute("DailyStateReady", true)
	else
		player:SetAttribute("DailyClaimedDaysCsv", "")
		player:SetAttribute("DailyLastClaimAt", 0)
		player:SetAttribute("DailyLastClaimedDay", 0)
		player:SetAttribute("DailyRewardCycle", 1)
		player:SetAttribute("DailyStateReady", false)
	end

	player:SetAttribute("EquippedSkin", data.EquippedSkin)
	player:SetAttribute("EquippedAuraId", data.EquippedAura)
	player:SetAttribute("EquippedTrailId", data.EquippedTrail)
	player:SetAttribute("GlobalSpeedGainMultiplier", cleanMultiplier(data.GlobalSpeedGainMultiplier))
	player:SetAttribute("TrailSpeedGainMultiplier", cleanMultiplier(data.TrailSpeedGainMultiplier))
	player:SetAttribute("AuraSpeedGainMultiplier", Config.DefaultAuraSpeedGainMultiplier or 1)
	player:SetAttribute("UpgradeSpeedGainMultiplier", cleanMultiplier(data.UpgradeSpeedGainMultiplier))
	player:SetAttribute("GamepassSpeedGainMultiplier", cleanMultiplier(data.GamepassSpeedGainMultiplier))
	player:SetAttribute("PermanentBaseSpeedMultiplier", math.max(1, cleanMultiplier(data.PermanentBaseSpeedMultiplier)))
	player:SetAttribute("PermanentWinsMultiplier", math.max(1, cleanMultiplier(data.PermanentWinsMultiplier)))
	player:SetAttribute("StarterPackGranted", data.StarterPackGranted == true)
	player:SetAttribute("StarterPackRewardVersion", math.max(0, cleanInt(data.StarterPackRewardVersion)))
	player:SetAttribute("World2Unlocked", data.World2Unlocked == true)
	player:SetAttribute("FirstTimeTutorialSeen", data.FirstTimeTutorialSeen == true)
	player:SetAttribute(
		"FirstRunEasyLevelsEligible",
		data.FirstRunEasyLevelsEligible == true and cleanInt(data.Rebirths) == 0
	)
	player:SetAttribute("CrossPlaceTeleporting", false)
	player:SetAttribute("RobuxSpent", cleanInt(data.RobuxSpent))
	local speedPotionRemaining = math.max(0, cleanInt(data.PotionSpeedRemainingSeconds))
	local winsPotionRemaining = math.max(0, cleanInt(data.PotionWinsRemainingSeconds))
	if speedPotionRemaining > 0 then
		player:SetAttribute("PotionSpeedExpireUnix", os.time() + speedPotionRemaining)
		player:SetAttribute("PotionSpeedMultiplier", Config.PotionSpeedMultiplier or 2)
	else
		player:SetAttribute("PotionSpeedExpireUnix", 0)
	end
	if winsPotionRemaining > 0 then
		player:SetAttribute("PotionWinsExpireUnix", os.time() + winsPotionRemaining)
		player:SetAttribute("PotionWinsMultiplier", Config.PotionWinsMultiplier or 2)
	else
		player:SetAttribute("PotionWinsExpireUnix", 0)
	end
	syncSuitSpeedGainMultiplier(player)
	syncRebirthAttributes(player)
	boostMaxByPlayer[player] = getBaseStaminaMax()
	boostStaminaByPlayer[player] = getBaseStaminaMax()
	restoreEquippedSkinStamina(player, "data_load")
	player:SetAttribute("IsBoosting", false)
	lastBoostUseAt[player] = -math.huge
	player:SetAttribute("IsOnTreadmill", false)
	player:SetAttribute("SpeedCarry", 0)
	player:SetAttribute("DataLoaded", true)

	-- Apply persisted settings (defaults are used when none were saved yet).
	SettingsByPlayer[player] = cleanSettings(data.Settings)
	applySettingsToPlayer(player, SettingsByPlayer[player])
	player:SetAttribute("LastSeenUpdateLog", math.max(0, cleanInt(data.LastSeenUpdateLog)))

	task.defer(PotionServer.AnnounceActiveBoosts, player)

	speed.Changed:Connect(function()
		local cleaned = cleanSpeed(speed.Value)
		if speed.Value ~= cleaned then
			speed.Value = cleaned
			return
		end

		syncRawFromLeaderboard(player)
		applyWalkSpeed(player)
	end)

	rawSpeed.Changed:Connect(function()
		local cleaned = cleanSpeed(rawSpeed.Value)
		if rawSpeed.Value ~= cleaned then
			rawSpeed.Value = cleaned
			return
		end

		syncLeaderboardFromRaw(player)
		applyWalkSpeed(player)
	end)

	                                                                      
	rebirths.Changed:Connect(function()
		syncRebirthAttributes(player)
		                                                                            
		                                                                                  
		if cleanInt(rebirths.Value) > 0 and player:GetAttribute("FirstRunEasyLevelsEligible") == true then
			player:SetAttribute("FirstRunEasyLevelsEligible", false)
		end
		applyWalkSpeed(player)
	end)

	                                                                      
	player:GetAttributeChangedSignal("EquippedSkin"):Connect(function()
		syncSuitSpeedGainMultiplier(player)
		restoreEquippedSkinStamina(player, "skin_attribute_changed")
	end)

	syncLeaderboardFromRaw(player)
	applyWalkSpeed(player)

	print("[PlayerStats] V34 created leaderboard for " .. player.Name .. " | Speed=" .. tostring(speed.Value) .. " Wins=" .. tostring(getWins(player).Value) .. " Rebirths=" .. tostring(getRebirths(player).Value))
end

local function buildSaveData(player)
	local rawSpeed = getRawSpeed(player)
	local speed = getSpeed(player)
	local wins = getWins(player)
	local rebirths = getRebirths(player)
	local dataFolder = player:FindFirstChild("SpeedsterData")

	local ownedSkins = dataFolder and dataFolder:FindFirstChild("OwnedSkins")
	local equippedTrail = dataFolder and dataFolder:FindFirstChild("EquippedTrail")
	local ownedTrails = dataFolder and dataFolder:FindFirstChild("OwnedTrails")
	local equippedAura = dataFolder and dataFolder:FindFirstChild("EquippedAura")
	local ownedAuras = dataFolder and dataFolder:FindFirstChild("OwnedAuras")
	local ownedUpgrades = dataFolder and dataFolder:FindFirstChild("OwnedUpgrades")

	local speedToSave = rawSpeed and rawSpeed.Value or (speed and speed.Value) or Config.StartingSpeed

	local data = {
		Version = 306,
		Speed = cleanSpeed(speedToSave),
		Wins = wins and cleanInt(wins.Value) or 0,
		Rebirths = rebirths and cleanInt(rebirths.Value) or 0,
		RobuxSpent = cleanInt(player:GetAttribute("RobuxSpent")),

		GlobalSpeedGainMultiplier = cleanMultiplier(player:GetAttribute("GlobalSpeedGainMultiplier")),
		TrailSpeedGainMultiplier = cleanMultiplier(player:GetAttribute("TrailSpeedGainMultiplier")),
		UpgradeSpeedGainMultiplier = cleanMultiplier(player:GetAttribute("UpgradeSpeedGainMultiplier")),
		GamepassSpeedGainMultiplier = cleanMultiplier(player:GetAttribute("GamepassSpeedGainMultiplier")),
		PermanentBaseSpeedMultiplier = math.max(1, cleanMultiplier(player:GetAttribute("PermanentBaseSpeedMultiplier"))),
		PermanentWinsMultiplier = math.max(1, cleanMultiplier(player:GetAttribute("PermanentWinsMultiplier"))),
		StarterPackGranted = player:GetAttribute("StarterPackGranted") == true,
		StarterPackRewardVersion = math.max(0, cleanInt(player:GetAttribute("StarterPackRewardVersion"))),
		World2Unlocked = player:GetAttribute("World2Unlocked") == true,
		FirstTimeTutorialSeen = player:GetAttribute("FirstTimeTutorialSeen") == true,
		FirstRunEasyLevelsEligible = player:GetAttribute("FirstRunEasyLevelsEligible") == true,

		EquippedSkin = tostring(player:GetAttribute("EquippedSkin") or ""),
		OwnedSkins = folderToList(ownedSkins),
		EquippedTrail = equippedTrail and equippedTrail.Value or "",
		OwnedTrails = folderToList(ownedTrails),
		EquippedAura = equippedAura and equippedAura.Value or "",
		OwnedAuras = folderToList(ownedAuras),
		OwnedUpgrades = folderToList(ownedUpgrades),
		ProcessedReceipts = copyProcessedReceipts(player),
		PotionSpeedRemainingSeconds = math.max(0, cleanInt(player:GetAttribute("PotionSpeedExpireUnix")) - os.time()),
		PotionWinsRemainingSeconds = math.max(0, cleanInt(player:GetAttribute("PotionWinsExpireUnix")) - os.time()),
		Settings = cleanSettings(SettingsByPlayer[player]),
		LastSeenUpdateLog = math.max(0, cleanInt(player:GetAttribute("LastSeenUpdateLog"))),

		LastSaveUnix = os.time(),
	}

	if player:GetAttribute("DailyStateReady") == true then
		data.DailyLoginState = {
			ClaimedDays = dailyDaysFromCsv(player:GetAttribute("DailyClaimedDaysCsv")),
			LastClaimAt = cleanInt(player:GetAttribute("DailyLastClaimAt")),
			LastClaimedDay = math.clamp(cleanInt(player:GetAttribute("DailyLastClaimedDay")), 0, 30),
			Cycle = math.max(1, cleanInt(player:GetAttribute("DailyRewardCycle"))),
		}
	end

	return data
end

local function isFinalSaveReason(reason)
	return reason == "leave" or reason == "shutdown"
end

                                                                               
                                                                              
                                                                              
                                                                                
                    
local function isSessionReleaseReason(reason)
	return isFinalSaveReason(reason) or reason == "teleport"
end

local function queueSaveReason(player, reason)
	reason = tostring(reason or "manual")
	if isFinalSaveReason(reason) then
		finalSaveRequested[player] = true
	end
	if finalSaveRequested[player] then
		reason = "shutdown"
	end
	local queued = pendingSaveReasons[player]
	if queued and isSessionReleaseReason(queued) then
		return
	end
	pendingSaveReasons[player] = reason
end

local function savePlayer(player, reason, waitForCompletion)
	if player:GetAttribute("DataLoaded") ~= true then
		return false
	end

	reason = tostring(reason or "manual")
	if player:GetAttribute("CrossPlaceTeleporting") == true
		and not isSessionReleaseReason(reason)
	then
		-- Critical saves (purchases, receipts, codes) require durable persistence.
		-- Never report success when the write is skipped during teleport.
		if waitForCompletion == true then
			return false
		end
		return true
	end

	                                                                               
	                                                               
	if player:GetAttribute("SessionDataOnly") == true then
		return true
	end

	local requestedTicket = (nextSaveTicket[player] or 0) + 1
	nextSaveTicket[player] = requestedTicket
	pendingSaveTickets[player] = requestedTicket
	queueSaveReason(player, reason)

	if savingNow[player] then
		if waitForCompletion == true then
			local deadline = os.clock() + (Config.SaveFlushTimeoutSeconds or 20)
			while (lastSuccessfulSaveTicket[player] or 0) < requestedTicket
				and os.clock() < deadline
			do
				task.wait(0.05)
			end
			return (lastSuccessfulSaveTicket[player] or 0) >= requestedTicket
		end

		                                                                               
		return true
	end

	savingNow[player] = true

	repeat
		local currentReason = pendingSaveReasons[player] or tostring(reason or "manual")
		local currentTicket = pendingSaveTickets[player] or requestedTicket
		pendingSaveReasons[player] = nil
		pendingSaveTickets[player] = nil

		local data = buildSaveData(player)
		local sessionId = sessionIdByPlayer[player]
		local releaseSession = isSessionReleaseReason(currentReason)
		local ok = false
		local err = nil
		local blockedByNewerSession = false

		if not sessionId then
			err = "missing active session id"
		else
			for attempt = 1, (Config.SaveRetryCount or 3) do
				blockedByNewerSession = false
				ok, err = pcall(function()
					DataStore:UpdateAsync(getKey(player), function(current)
						blockedByNewerSession = false
						local activeSessionId = type(current) == "table" and current.ActiveSessionId or nil
						if activeSessionId and activeSessionId ~= sessionId then
							blockedByNewerSession = true
							return nil
						end

						if releaseSession then
							data.ActiveSessionId = nil
							data.ActiveSessionStartedUnixMs = nil
							data.ActiveSessionExpiresUnix = nil
						else
							data.ActiveSessionId = sessionId
							data.ActiveSessionStartedUnixMs = DateTime.now().UnixTimestampMillis
							data.ActiveSessionExpiresUnix = os.time() + (Config.SessionLeaseSeconds or 120)
						end

						return data
					end)
				end)

				if ok and not blockedByNewerSession then
					break
				end

				if blockedByNewerSession then
					ok = false
					err = "a newer server session owns this player's data"
					break
				end

				if attempt < (Config.SaveRetryCount or 3) then
					task.wait(Config.SaveRetryDelay or 1)
				end
			end
		end

		if ok then
			lastSuccessfulSaveTicket[player] = math.max(
				lastSuccessfulSaveTicket[player] or 0,
				currentTicket
			)
			lastSaveAt[player] = os.clock()
			if currentReason ~= "autosave" then
				print("[PlayerStats] Saved " .. player.Name .. " | reason=" .. tostring(currentReason))
			end
		else
			warn(
				"[PlayerStats] Save failed for "
					.. player.Name
					.. " | reason="
					.. tostring(currentReason)
					.. " | "
					.. tostring(err)
			)
		end
	until pendingSaveReasons[player] == nil and pendingSaveTickets[player] == nil

	savingNow[player] = nil
	return (lastSuccessfulSaveTicket[player] or 0) >= requestedTicket
end

local function addSpeed(player, baseAmount, popupData)
	local speed = getSpeed(player)
	local rawSpeed = getRawSpeed(player)

	if not speed or not rawSpeed then
		warn("[PlayerStats] Cannot add speed. Missing Speed or RawSpeed for " .. player.Name)
		return false
	end

	local originalBaseGain = tonumber(baseAmount) or 0

	                                                                         
	                                                                        
	                                                                          
	                                                              
	                                                               
	local permanentMultiplier = getPermanentBaseSpeedMultiplier(player)
	local permanentlyMultipliedBaseGain = originalBaseGain * permanentMultiplier
	local gain = permanentlyMultipliedBaseGain * getTotalGainMultiplier(player)
	gain = gain * PotionServer.GetSpeedPotionMultiplier(player) * PotionServer.GetServerBoostMultiplier()

	if badNumber(gain) or gain <= 0 then
		return false
	end

	local carry = player:GetAttribute("SpeedCarry") or 0
	carry += gain

	local whole = math.floor(carry)
	local addedWholeSpeed = whole >= 1

	if addedWholeSpeed then
		local newSpeed = cleanSpeed(rawSpeed.Value + whole)
		rawSpeed.Value = newSpeed
		speed.Value = newSpeed
		carry -= whole
	end

	if popupData and (addedWholeSpeed or popupData.ForcePopup == true) then
		local visualAmount = whole

		if visualAmount < 1 then
			visualAmount = tonumber(popupData.VisualAmount) or tonumber(baseAmount) or 1
		end

		SpeedGainPopup:FireClient(player, {
			Amount = visualAmount,
			                                                                      
			                                                                       
			                                              
			TotalSpeed = cleanSpeed(rawSpeed.Value),
			Color = popupData.Color,
			BurstCount = popupData.BurstCount,
			TreadmillName = popupData.TreadmillName,
			SoundPlaybackSpeed = popupData.SoundPlaybackSpeed,
			IsRunningPopup = popupData.IsRunningPopup == true,
			IsBoostingPopup = popupData.IsBoostingPopup == true,
		})
	end

	player:SetAttribute("SpeedCarry", carry)
	applyWalkSpeed(player)
	return true
end

local function getPermanentWinsMultiplier(player)
	local multiplier = cleanMultiplier(player:GetAttribute("PermanentWinsMultiplier"))
	return math.max(1, multiplier)
end

local function VIPWinsMultiplierFor(player)
	local multiplier = cleanMultiplier(player:GetAttribute("VIPWinsMultiplier"))
	return math.max(1, multiplier)
end

local function addWins(player, amount)
	local wins = getWins(player)
	if not wins then
		return false
	end

	local gain = tonumber(amount) or 0
	if gain > 0 then
		gain *= getPermanentWinsMultiplier(player)
		gain *= VIPWinsMultiplierFor(player)
		local confettiExpire = tonumber(player:GetAttribute("ConfettiBoostExpire")) or 0
		if os.time() < confettiExpire then
			gain *= (tonumber(player:GetAttribute("ConfettiWinMult")) or 2)
		end
		gain *= PotionServer.GetWinsPotionMultiplier(player)
	end

	wins.Value = cleanInt(wins.Value + gain)
	return true
end

                                                                            
                                                                        
                                                                       
local function grantExactStat(player, statName, amount)
	if not player or player.Parent ~= Players or player:GetAttribute("DataLoaded") ~= true then
		return false, "Player data is not ready"
	end

	amount = tonumber(amount)
	if not amount or badNumber(amount) or amount <= 0 then
		return false, "Amount must be a positive finite number"
	end

	if statName == "Speed" then
		local speed = getSpeed(player)
		local rawSpeed = getRawSpeed(player)
		if not speed or not rawSpeed then
			return false, "Speed data is missing"
		end

		local before = cleanSpeed(rawSpeed.Value)
		local after = cleanSpeed(before + amount)
		rawSpeed.Value = after
		speed.Value = after
		applyWalkSpeed(player)
		return true, after - before
	elseif statName == "Wins" then
		local wins = getWins(player)
		if not wins then
			return false, "Wins data is missing"
		end

		local before = cleanInt(wins.Value)
		local after = math.min(9007199254740991, cleanInt(before + math.floor(amount)))
		wins.Value = after
		return true, after - before
	end

	return false, "Unsupported stat"
end

local function addRebirths(player, amount)
	local rebirths = getRebirths(player)
	if rebirths then
		rebirths.Value = cleanInt(rebirths.Value + (tonumber(amount) or 0))
		syncRebirthAttributes(player)
	end
end

local function hasProcessedReceipt(player, purchaseId)
	purchaseId = tostring(purchaseId or "")
	if purchaseId == "" then
		return false
	end
	local receipts = processedReceiptsByPlayer[player]
	return type(receipts) == "table" and receipts[purchaseId] ~= nil
end

local function markProcessedReceipt(player, purchaseId)
	purchaseId = tostring(purchaseId or "")
	if purchaseId == "" then
		return false
	end

	local receipts = processedReceiptsByPlayer[player]
	if type(receipts) ~= "table" then
		receipts = {}
	end
	receipts[purchaseId] = os.time()
	processedReceiptsByPlayer[player] = cleanProcessedReceipts(receipts)
	return true
end

local function clearProcessedReceipt(player, purchaseId)
	purchaseId = tostring(purchaseId or "")
	local receipts = processedReceiptsByPlayer[player]
	if type(receipts) == "table" and purchaseId ~= "" then
		receipts[purchaseId] = nil
	end
end

local function unlockTrail(player, trailName)
	if type(trailName) ~= "string" or trailName == "" then
		return
	end

	local dataFolder = getDataFolder(player)
	local folder = ensureFolder(dataFolder, "OwnedTrails")

	local value = folder:FindFirstChild(trailName)
	if not value then
		value = Instance.new("BoolValue")
		value.Name = trailName
		value.Parent = folder
	end

	value.Value = true
end

local function equipTrail(player, trailName, multiplier)
	if type(trailName) ~= "string" then
		trailName = ""
	end

	local dataFolder = getDataFolder(player)
	ensureStringValue(dataFolder, "EquippedTrail", trailName)
	player:SetAttribute("EquippedTrailId", trailName)

	if trailName ~= "" then
		unlockTrail(player, trailName)
	end

	player:SetAttribute("TrailSpeedGainMultiplier", cleanMultiplier(multiplier or 1))
	task.defer(savePlayer, player, "trail_equip")
end

local function unlockSkin(player, skinId)
	if type(skinId) ~= "string" or skinId == "" then
		return
	end

	local dataFolder = getDataFolder(player)
	local folder = ensureFolder(dataFolder, "OwnedSkins")
	local value = folder:FindFirstChild(skinId)

	if not value then
		value = Instance.new("BoolValue")
		value.Name = skinId
		value.Parent = folder
	end

	value.Value = true
end

local function unlockAura(player, auraId)
	if type(auraId) ~= "string" or auraId == "" then
		return
	end

	local dataFolder = getDataFolder(player)
	local folder = ensureFolder(dataFolder, "OwnedAuras")
	local value = folder:FindFirstChild(auraId)

	if not value then
		value = Instance.new("BoolValue")
		value.Name = auraId
		value.Parent = folder
	end

	value.Value = true
end

local function equipAura(player, auraId, multiplier)
	if type(auraId) ~= "string" then
		auraId = ""
	end

	local dataFolder = getDataFolder(player)
	ensureStringValue(dataFolder, "EquippedAura", auraId)
	player:SetAttribute("EquippedAuraId", auraId)
	player:SetAttribute("AuraSpeedGainMultiplier", cleanMultiplier(multiplier or 1))

	if auraId ~= "" then
		unlockAura(player, auraId)
	end

	task.defer(savePlayer, player, "aura_equip")
end

local function unlockUpgrade(player, upgradeName)
	if type(upgradeName) ~= "string" or upgradeName == "" then
		return
	end

	local dataFolder = getDataFolder(player)
	local folder = ensureFolder(dataFolder, "OwnedUpgrades")

	local value = folder:FindFirstChild(upgradeName)
	if not value then
		value = Instance.new("BoolValue")
		value.Name = upgradeName
		value.Parent = folder
	end

	value.Value = true
end

_G.SpeedsterAddSpeed = addSpeed
_G.SpeedsterApplyWalkSpeed = applyWalkSpeed
_G.SpeedsterGetTotalGainMultiplier = getTotalGainMultiplier
_G.SpeedsterGetSuitSpeedGainMultiplierForSkin = getSuitSpeedGainMultiplierForSkin
_G.SpeedsterGetPermanentBaseSpeedMultiplier = getPermanentBaseSpeedMultiplier
_G.SpeedsterGetPermanentWinsMultiplier = getPermanentWinsMultiplier
_G.SpeedsterSyncSuitSpeedGainMultiplier = syncSuitSpeedGainMultiplier
_G.SpeedsterSavePlayer = savePlayer
_G.SpeedsterAddWins = addWins
_G.SpeedsterGrantExactStat = grantExactStat
_G.SpeedsterAddRebirths = addRebirths
_G.SpeedsterHasProcessedReceipt = hasProcessedReceipt
_G.SpeedsterMarkProcessedReceipt = markProcessedReceipt
_G.SpeedsterClearProcessedReceipt = clearProcessedReceipt
_G.SpeedsterGetNextRebirthLevelRequirement = getNextRebirthLevelRequirement
_G.SpeedsterGetRebirthSpeedGainMultiplier = getRebirthSpeedGainMultiplier
_G.SpeedsterSyncRebirthAttributes = syncRebirthAttributes
_G.SpeedsterUnlockTrail = unlockTrail
_G.SpeedsterEquipTrail = equipTrail
_G.SpeedsterUnlockSkin = unlockSkin
_G.SpeedsterUnlockAura = unlockAura
_G.SpeedsterEquipAura = equipAura
_G.SpeedsterUnlockUpgrade = unlockUpgrade


local function getWalkingPopupTier(player)
	local rawSpeed = getRawSpeed(player)
	local speedValue = 0

	if rawSpeed then
		speedValue = tonumber(rawSpeed.Value) or 0
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
		selectedBurstCount = math.min(
			math.floor(selectedBurstCount * (Config.BoostRunningPopupBurstMultiplier or 2)),
			Config.BoostRunningPopupMaxBurst or 36
		)

		selectedSoundPlaybackSpeed = math.min(
			selectedSoundPlaybackSpeed + (Config.BoostRunningPopupSoundExtraSpeed or 0.35),
			Config.BoostRunningPopupSoundMaxPlaybackSpeed or 2.25
		)

		visualAmount *= (Config.BoostRunningVisualAmountMultiplier or Config.BoostRunningGainMultiplier or 3)
	end

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

local function isMoving(player)
	local _, humanoid = getCharacter(player)
	return humanoid and humanoid.Health > 0 and humanoid.MoveDirection.Magnitude > 0.1
end

BoostState.OnServerEvent:Connect(function(player, wantsBoost)
	wantsBoost = wantsBoost == true

	                                                                              
	                                                           
	if Config.AbilityFlightEnabled == true and player:GetAttribute("FlightAbilityActive") == true then
		wantsBoost = false
	end

	syncBoostStaminaAttributes(player)

	local maxStamina = getBoostMaxStamina(player)
	local stamina = boostStaminaByPlayer[player] or maxStamina
	local wasBoosting = player:GetAttribute("IsBoosting") == true

	if wantsBoost and stamina >= (Config.MinimumStaminaToStartBoost or 8) then
		player:SetAttribute("IsBoosting", true)
		lastBoostUseAt[player] = os.clock()
	else
		player:SetAttribute("IsBoosting", false)

		if wasBoosting then
			lastBoostUseAt[player] = os.clock()
		end
	end

	applyWalkSpeed(player)
end)

WalkSpeedModeRequest.OnServerEvent:Connect(function(player, requestedMode)
	local num = tonumber(requestedMode)
	if num ~= nil and num == num and num ~= math.huge and num ~= -math.huge then
		local maxSpeed = tonumber(player:GetAttribute("RealWalkSpeedMax")) or 300
		local minSpeed = Config.RealWalkSpeedMin or 8
		local clamped = math.clamp(math.floor(num + 0.5), minSpeed, maxSpeed)
		player:SetAttribute("WalkSpeedMode", "Custom")
		player:SetAttribute("CustomWalkSpeed", clamped)
		applyWalkSpeed(player)
		return
	end

	requestedMode = tostring(requestedMode or "")
	local multipliers = Config.WalkSpeedSelectorMultipliers or {}

	if tonumber(multipliers[requestedMode]) == nil then
		return
	end

	player:SetAttribute("WalkSpeedMode", requestedMode)
	player:SetAttribute("CustomWalkSpeed", nil)
	applyWalkSpeed(player)
end)

-- Settings toggled from the client Settings panel. The client sets the attribute
-- locally for instant feedback and echoes it here so it is validated, stored
-- server-side, persisted, and re-applied as a replicated attribute.
local SettingsUpdate = Remotes:FindFirstChild("SettingsUpdate")
if not SettingsUpdate then
	SettingsUpdate = Instance.new("RemoteEvent")
	SettingsUpdate.Name = "SettingsUpdate"
	SettingsUpdate.Parent = Remotes
end
SettingsUpdate.OnServerEvent:Connect(function(player, attrName, value)
	if player:GetAttribute("DataLoaded") ~= true then
		return
	end
	if SETTING_DEFAULTS[attrName] == nil then
		return
	end
	if type(SETTING_DEFAULTS[attrName]) == "number" then
		if type(value) ~= "number" or value ~= value then return end
		value = math.clamp(math.floor(value), 0, 100)
	elseif type(SETTING_DEFAULTS[attrName]) == "boolean" then
		if type(value) ~= "boolean" then return end
	else
		return
	end
	SettingsByPlayer[player] = SettingsByPlayer[player] or {}
	SettingsByPlayer[player][attrName] = value
	player:SetAttribute(attrName, value)
	task.defer(savePlayer, player, "setting_change")
end)

-- The client dismisses the update logs panel; remember the version seen so it
-- stays closed until the next publish (game.PlaceVersion bump).
local UpdateLogClosed = Remotes:FindFirstChild("UpdateLogClosed")
if not UpdateLogClosed then
	UpdateLogClosed = Instance.new("RemoteEvent")
	UpdateLogClosed.Name = "UpdateLogClosed"
	UpdateLogClosed.Parent = Remotes
end
UpdateLogClosed.OnServerEvent:Connect(function(player)
	if player:GetAttribute("DataLoaded") ~= true then
		return
	end
	player:SetAttribute("LastSeenUpdateLog", game.PlaceVersion)
	task.defer(savePlayer, player, "update_log_closed")
end)

local function setupPlayer(player)
	                                                                          
	                                           
	player:SetAttribute("WalkSpeedMode", Config.WalkSpeedSelectorDefaultMode or "Red")

	local data, loadError = loadData(player)
	if not data then
		if player.Parent ~= Players then
			return
		end
		player:SetAttribute("DataLoadFailed", true)
		warn("[PlayerStats] Refusing to create saveable defaults for " .. player.Name .. ": " .. tostring(loadError))
		player:Kick("Your data could not be loaded safely. Please rejoin in a moment; your saved progress was not overwritten.")
		return
	end
	player:SetAttribute("DataLoadFailed", false)
	createStats(player, data)


	if player.Character then
		local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end
		applyWalkSpeed(player)
	end

	player.CharacterAdded:Connect(function(character)
		                                                                            
		                                     
		restoreEquippedSkinStamina(player, "character_respawn_immediate")
		for _, delayTime in ipairs({0.05, 0.25, 0.75, 1.5}) do
			task.delay(delayTime, function()
				if player.Parent and player.Character == character then
					restoreEquippedSkinStamina(player, "character_respawn")
				end
			end)
		end

		local humanoid = character:WaitForChild("Humanoid", 5)
		if humanoid then
			humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end

		task.wait(0.15)
		applyWalkSpeed(player)
	end)

	lastSaveAt[player] = os.clock()
end

Players.PlayerAdded:Connect(setupPlayer)

for _, player in ipairs(Players:GetPlayers()) do
	task.defer(setupPlayer, player)
end

local function cleanupPlayerRuntimeState(player)
	lastSaveAt[player] = nil
	pendingSaveReasons[player] = nil
	pendingSaveTickets[player] = nil
	nextSaveTicket[player] = nil
	lastSuccessfulSaveTicket[player] = nil
	finalSaveRequested[player] = nil
	sessionIdByPlayer[player] = nil
	processedReceiptsByPlayer[player] = nil
	lastBoostUseAt[player] = nil
	boostMaxByPlayer[player] = nil
	boostStaminaByPlayer[player] = nil
	SettingsByPlayer[player] = nil
end

Players.PlayerRemoving:Connect(function(player)
	savePlayer(player, "leave", true)

	if savingNow[player] then
		task.spawn(function()
			while savingNow[player] do
				task.wait(0.05)
			end
			cleanupPlayerRuntimeState(player)
		end)
	else
		cleanupPlayerRuntimeState(player)
	end
end)

game:BindToClose(function()
	local players = Players:GetPlayers()
	local completed = 0

	for _, player in ipairs(players) do
		task.spawn(function()
			savePlayer(player, "shutdown", true)
			completed += 1
		end)
	end

	local deadline = os.clock() + (Config.ShutdownSaveTimeoutSeconds or 25)
	while completed < #players and os.clock() < deadline do
		task.wait(0.05)
	end
end)

task.spawn(function()
	while true do
		task.wait(Config.TrainingTickSeconds)

		for _, player in ipairs(Players:GetPlayers()) do
			if player:GetAttribute("IsOnTreadmill") ~= true and Config.RunningSpeedPerTick > 0 and isMoving(player) then
				local runningGain = Config.RunningSpeedPerTick

				if player:GetAttribute("IsBoosting") == true then
					runningGain *= (Config.BoostRunningGainMultiplier or 3)
				end

				if Config.WalkingPopupEnabled then
					addSpeed(player, runningGain, getWalkingPopupTier(player))
				else
					addSpeed(player, runningGain)
				end
			end

			local now = os.clock()
			if not lastSaveAt[player] then
				lastSaveAt[player] = now
			end

			if now - lastSaveAt[player] >= Config.AutoSaveSeconds then
				task.spawn(savePlayer, player, "autosave")
			end
		end
	end
end)

RunService.Heartbeat:Connect(function(dt)
	for _, player in ipairs(Players:GetPlayers()) do
		syncBoostStaminaAttributes(player)

		local maxStamina = getBoostMaxStamina(player)
		local stamina = boostStaminaByPlayer[player] or maxStamina
		local isBoosting = player:GetAttribute("IsBoosting") == true
		local isFlightActive = Config.AbilityFlightEnabled == true
			and player:GetAttribute("FlightAbilityOwned") == true
			and player:GetAttribute("FlightAbilityActive") == true
		local isFlightPowered = isFlightActive
			and player:GetAttribute("FlightAbilityPowered") == true
		local now = os.clock()

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
			end
		else
			local lastUse = lastBoostUseAt[player] or -math.huge
			local delaySeconds = Config.BoostRegenDelaySeconds or 1.7

			if now - lastUse >= delaySeconds then
				local regenPerSecond =
					maxStamina
					* (Config.BoostRegenPercentPerTick or 0.27)
					/ (Config.BoostRegenTickSeconds or 0.7)

				stamina += regenPerSecond * dt
				stamina = math.min(stamina, maxStamina)
			end
		end

		boostStaminaByPlayer[player] = stamina
		syncBoostStaminaAttributes(player)
		applyWalkSpeed(player)
	end
end)

print("[PlayerStats] V306CV loaded. Safe sessions/queued saves active; V34/V197 movement preserved and nine suit stamina caps are authoritative.")
