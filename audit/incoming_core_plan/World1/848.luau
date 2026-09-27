




local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local CosmeticCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CosmeticCatalog"))
local STAGE_COUNT = math.max(11, math.floor(tonumber(Config.StageCount) or 11))
local IS_WORLD2 = Config.IsWorld2Place == true
local IS_NEW_WORLD1 = Config.IsNewWorld1Map == true
local WORLD2_SAFE_ZONE_SUFFIX = tostring(Config.World2SafeZoneSuffix or ".2")
local NEW_WORLD1_MAP_ROOT = IS_NEW_WORLD1
	and (Workspace:FindFirstChild(tostring(Config.NewWorld1MapMarkerName or "neworld1"))
		or Workspace:WaitForChild(tostring(Config.NewWorld1MapMarkerName or "neworld1"), 20))
	or nil
local Services = ServerScriptService:WaitForChild("Services")
local StageTeleportService = require(Services:WaitForChild("StageTeleportService"))
local PotionServer = require(Services:WaitForChild("PotionServer"))
local DataService
pcall(function()
	DataService = require(Services:WaitForChild("Data"):WaitForChild("DataService"))
end)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SpeedGainPopup = Remotes:WaitForChild("SpeedGainPopup")

local ReviveCommerce = Remotes:FindFirstChild("ReviveCommerce")
if not ReviveCommerce then
	ReviveCommerce = Instance.new("RemoteEvent")
	ReviveCommerce.Name = "ReviveCommerce"
	ReviveCommerce.Parent = Remotes
end

local StarterPackClaim = Remotes:FindFirstChild("StarterPackClaim")
if not StarterPackClaim then
	StarterPackClaim = Instance.new("RemoteEvent")
	StarterPackClaim.Name = "StarterPackClaim"
	StarterPackClaim.Parent = Remotes
end

local GiftContextRequest = Remotes:FindFirstChild("GiftContextRequest")
if not GiftContextRequest then
	GiftContextRequest = Instance.new("RemoteEvent")
	GiftContextRequest.Name = "GiftContextRequest"
	GiftContextRequest.Parent = Remotes
end

local pendingGiftContexts = {}
local grantPassPerkToTarget

local STARTER_PACK_REWARD_VERSION = 2
local LEGACY_STARTER_PACK_SPEED_REWARD = 50000
local LEGACY_STARTER_PACK_WINS_REWARD = 30

local ReceiptStore = DataStoreService:GetDataStore("SpeedsterEscape_ProductReceipts_v1")
local RECEIPT_LEASE_SECONDS = 120
local processingPlayerReceipts = {}
local activeReviveOffers = {}
local pendingRevivePurchases = {}
local playerLastGrounded = {}
local starterPackGrantBusy = {}
local starterPackClaimCheckBusy = {}
local monetizationPlayerSetup = {}
local safeZoneReferences = {}
local safeZoneBoundsCache = {}
local stageFromSafeZoneName
local receiptOwnerId = game.JobId ~= ""
	and game.JobId
	or ("studio-" .. HttpService:GenerateGUID(false))

local function safeZoneName(stage)
	if IS_NEW_WORLD1 then
		return tostring(Config.NewWorld1SafeZonePrefix or "stage") .. tostring(stage)
	end
	return "SafeZone" .. tostring(stage) .. (IS_WORLD2 and WORLD2_SAFE_ZONE_SUFFIX or "")
end

local function isSafeZoneObject(object)
	return object and (object:IsA("BasePart") or object:IsA("Model"))
end

local productsById = {}
for _, tier in ipairs(Config.SpeedProductTiers or {}) do
	local productId = tonumber(tier.ProductId)
	if productId then
		productsById[productId] = { Kind = "SpeedAmount", Data = tier }
	end
end

for _, product in ipairs(Config.PermanentSpeedMultiplierProducts or {}) do
	local productId = tonumber(product.ProductId)
	if productId then
		productsById[productId] = { Kind = "PermanentMultiplier", Data = product }
	end
end

for _, product in ipairs(Config.PermanentWinsMultiplierProducts or {}) do
	local productId = tonumber(product.ProductId)
	if productId then
		productsById[productId] = { Kind = "PermanentWinsMultiplier", Data = product }
	end
end

-- Fallback legacy products (3 R$, 7 R$, 19 R$)
local legacyMultipliers = {
	[3650735503] = { Kind = "PermanentMultiplier", Data = { TargetMultiplier = 2 } },
	[3650778372] = { Kind = "PermanentMultiplier", Data = { TargetMultiplier = 4 } },
	[3650798979] = { Kind = "PermanentMultiplier", Data = { TargetMultiplier = 10 } },
	[3674002277] = { Kind = "PermanentWinsMultiplier", Data = { TargetMultiplier = 2 } },
	[3674011914] = { Kind = "PermanentWinsMultiplier", Data = { TargetMultiplier = 4 } },
	[3674018331] = { Kind = "PermanentWinsMultiplier", Data = { TargetMultiplier = 10 } },
}
for pid, info in pairs(legacyMultipliers) do
	if not productsById[pid] then
		productsById[pid] = info
	end
end

local doubleWinsPadProductId = tonumber(Config.DoubleWinsPadProductId)
if doubleWinsPadProductId and doubleWinsPadProductId > 0 then
	if not productsById[doubleWinsPadProductId] then
		productsById[doubleWinsPadProductId] = {
			Kind = "PermanentWinsMultiplier",
			Data = { Stage = 1, TargetMultiplier = 2, ProductId = doubleWinsPadProductId },
		}
	end
end

for _, option in ipairs(Config.TeleportStageOptions or {}) do
	local productId = tonumber(option.ProductId)
	if productId and productId > 0 then
		productsById[productId] = { Kind = "StageTeleport", Data = option }
	end
end

local skipStageProductId = tonumber(Config.SkipStageProductId)
if skipStageProductId and skipStageProductId > 0 then
	productsById[skipStageProductId] = {
		Kind = "SkipStage",
		Data = { ProductId = skipStageProductId },
	}
end

local reviveProductId = tonumber(Config.ReviveProductId)
if reviveProductId and reviveProductId > 0 then
	productsById[reviveProductId] = {
		Kind = "Revive",
		Data = {
			ProductId = reviveProductId,
			PriceRobux = tonumber(Config.RevivePriceRobux) or 7,
		},
	}
end



local flightAbilityProductId = tonumber(Config.AbilityFlightProductId)
if (not IS_WORLD2) and Config.AbilityFlightEnabled == true and flightAbilityProductId and flightAbilityProductId > 0 then
	productsById[flightAbilityProductId] = {
		Kind = "AbilityFlight",
		Data = {
			ProductId = flightAbilityProductId,
			PriceRobux = tonumber(Config.AbilityFlightPriceRobux) or 799,
		},
	}
end

local rebirthProductId = tonumber(Config.RebirthProductId)
if rebirthProductId and rebirthProductId > 0 then
	productsById[rebirthProductId] = {
		Kind = "Rebirth",
		Data = {
			ProductId = rebirthProductId,
			Amount = 1,
			PriceRobux = tonumber(Config.RebirthPriceRobux) or 14,
		},
	}
end





for _, cosmeticType in ipairs({"Trail", "Aura"}) do
	for _, entry in ipairs(CosmeticCatalog.GetList(cosmeticType) or {}) do
		local purchaseId = tonumber(entry.RobuxPurchaseId)
		local purchaseType = tostring(entry.RobuxPurchaseType or "DeveloperProduct")
		if purchaseId and purchaseId > 0 and purchaseType ~= "GamePass" then
			productsById[purchaseId] = {
				Kind = "CosmeticUnlock",
				Data = {
					CosmeticType = cosmeticType,
					CosmeticId = entry.Id,
					DisplayName = entry.DisplayName,
					PriceRobux = tonumber(entry.RobuxPrice),
					ProductId = purchaseId,
				},
			}
		end
	end
end

for _, product in ipairs(Config.PotionWinsProducts or {}) do
	local productId = tonumber(product.ProductId)
	if productId then
		productsById[productId] = { Kind = "PotionWins", Data = product }
	end
end

for _, product in ipairs(Config.PotionSpeedProducts or {}) do
	local productId = tonumber(product.ProductId)
	if productId then
		productsById[productId] = { Kind = "PotionSpeed", Data = product }
	end
end

local serverBoostProductId = tonumber(Config.ServerSpeedBoostProduct and Config.ServerSpeedBoostProduct.ProductId)
if serverBoostProductId and serverBoostProductId > 0 then
	productsById[serverBoostProductId] = {
		Kind = "ServerBoost",
		Data = Config.ServerSpeedBoostProduct,
	}
end

local tierPopupColors = {
	[1] = Color3.fromRGB(48, 190, 255),
	[2] = Color3.fromRGB(56, 215, 110),
	[3] = Color3.fromRGB(255, 184, 45),
	[4] = Color3.fromRGB(255, 76, 78),
}

local DISPLAY_ROUND_DOWN_STEP = math.max(1, tonumber(Config.SpeedProductDisplayRoundDownStep) or 10)
local MAX_SAFE_INTEGER = 9007199254740991

local function receiptKey(purchaseId)
	return "Receipt_" .. tostring(purchaseId)
end

local function isGrantedRecord(record)
	return record == true
		or (type(record) == "table" and record.Status == "Granted")
end

local function acquireReceipt(receiptInfo)
	local purchaseId = tostring(receiptInfo.PurchaseId or "")
	if purchaseId == "" then
		return false, "invalid"
	end
	local claimOwnerId = receiptOwnerId .. ":" .. HttpService:GenerateGUID(false)

	local decision = "error"
	local targetUserId = receiptInfo.TargetUserId or receiptInfo.PlayerId
	local giftContextId = receiptInfo.GiftContextId or ""
	local ok, err = pcall(function()
		ReceiptStore:UpdateAsync(receiptKey(purchaseId), function(current)
			decision = "error"
			targetUserId = type(current)=="table" and current.TargetUserId or receiptInfo.TargetUserId or receiptInfo.PlayerId
			giftContextId = if type(current)=="table" then (current.GiftContextId or "") else (receiptInfo.GiftContextId or "")
			if isGrantedRecord(current) then
				decision = "granted"
				return current
			end

			local now = os.time()
			if type(current) == "table"
				and current.Status == "Processing"
				and current.Owner ~= claimOwnerId
				and (tonumber(current.LeaseExpiresUnix) or 0) > now
			then
				decision = "busy"
				return current
			end

			decision = "acquired"
			return {
				Status = "Processing",
				TargetUserId = targetUserId,
				GiftContextId = giftContextId,
				Owner = claimOwnerId,
				LeaseExpiresUnix = now + RECEIPT_LEASE_SECONDS,
				PlayerId = receiptInfo.PlayerId,
				ProductId = receiptInfo.ProductId,
				UpdatedUnix = now,
			}
		end)
	end)

	if not ok then
		if RunService:IsStudio() then
			print("[SpeedProductPurchases] Studio test mode: allowing receipt without external DataStore")
			return true, "acquired", claimOwnerId, targetUserId, giftContextId
		end
		warn("[SpeedProductPurchases] Receipt claim failed: " .. tostring(err))
		return false, "error"
	end

	return decision == "acquired" or decision == "granted", decision, claimOwnerId, targetUserId, giftContextId
end

local function releaseReceiptLease(receiptInfo, claimOwnerId)
	local purchaseId = tostring(receiptInfo.PurchaseId or "")
	if purchaseId == "" or type(claimOwnerId) ~= "string" then
		return
	end

	local ok, err = pcall(function()
		ReceiptStore:UpdateAsync(receiptKey(purchaseId), function(current)
			if type(current) == "table"
				and current.Status == "Processing"
				and current.Owner == claimOwnerId
			then
				current.LeaseExpiresUnix = 0
				current.UpdatedUnix = os.time()
			end
			return current
		end)
	end)
	if not ok then
		warn("[SpeedProductPurchases] Could not release receipt lease: " .. tostring(err))
	end
end

local function markReceiptGranted(receiptInfo)
	local purchaseId = tostring(receiptInfo.PurchaseId or "")
	if purchaseId == "" then
		return false
	end

	local ok, err = pcall(function()
		ReceiptStore:UpdateAsync(receiptKey(purchaseId), function(current)
			if isGrantedRecord(current) then
				return current
			end
			return {
				Status = "Granted",
				GiftContextId = if type(current)=="table" then (current.GiftContextId or "") else (receiptInfo.GiftContextId or ""),
				TargetUserId = type(current)=="table" and current.TargetUserId or receiptInfo.TargetUserId,
				PlayerId = receiptInfo.PlayerId,
				ProductId = receiptInfo.ProductId,
				GrantedUnix = os.time(),
			}
		end)
	end)

	if not ok then
		if RunService:IsStudio() then
			return true
		end
		warn("[SpeedProductPurchases] Could not finalize receipt marker: " .. tostring(err))
		return false
	end
	return true
end

local function waitForPlayerData(player, timeoutSeconds)
	local deadline = os.clock() + (timeoutSeconds or 10)
	while player.Parent and player:GetAttribute("DataLoaded") ~= true and os.clock() < deadline do
		task.wait(0.1)
	end
	return player.Parent ~= nil and player:GetAttribute("DataLoaded") == true
end

local function getObjectBounds(object)
	if object and object:IsA("BasePart") then
		return object.CFrame, object.Size
	end
	if object and object:IsA("Model") then
		local ok, boundsCFrame, boundsSize = pcall(function()
			return object:GetBoundingBox()
		end)
		if ok then
			return boundsCFrame, boundsSize
		end
	end
	return nil, nil
end

local function getCachedSafeZoneBounds(stage)
	local zone = safeZoneReferences[stage]
	local cached = safeZoneBoundsCache[stage]

	if zone and zone.Parent and cached and cached.Zone == zone then
		return cached.CFrame, cached.Size
	end

	if not zone or not zone.Parent then
		local searchRoot = IS_NEW_WORLD1 and NEW_WORLD1_MAP_ROOT or Workspace
		zone = searchRoot and searchRoot:FindFirstChild(safeZoneName(stage), true)
		if zone and not isSafeZoneObject(zone) then
			zone = nil
		end
		if IS_WORLD2 and not zone and stageFromSafeZoneName then


			for _, descendant in ipairs(Workspace:GetDescendants()) do
				if isSafeZoneObject(descendant)
					and stageFromSafeZoneName(descendant.Name) == stage
				then
					zone = descendant
					break
				end
			end
		end
		safeZoneReferences[stage] = zone
	end

	if not zone then
		safeZoneBoundsCache[stage] = nil
		return nil, nil
	end

	local boundsCFrame, boundsSize = getObjectBounds(zone)
	if boundsCFrame and boundsSize then
		safeZoneBoundsCache[stage] = {
			Zone = zone,
			CFrame = boundsCFrame,
			Size = boundsSize,
		}
		return boundsCFrame, boundsSize
	end

	safeZoneBoundsCache[stage] = nil
	return nil, nil
end

local function findSafeZoneStageAtPosition(position)
	local closestStage = nil
	local closestDistance = math.huge

	for stage = 1, STAGE_COUNT do
		local boundsCFrame, boundsSize = getCachedSafeZoneBounds(stage)
		if boundsCFrame and boundsSize then
			local localPoint = boundsCFrame:PointToObjectSpace(position)
			local half = boundsSize * 0.5
			local inside = math.abs(localPoint.X) <= half.X + 2
				and math.abs(localPoint.Z) <= half.Z + 2
				and localPoint.Y >= -half.Y - 6
				and localPoint.Y <= half.Y + 12
			if inside then
				local distance = (position - boundsCFrame.Position).Magnitude
				if distance < closestDistance then
					closestDistance = distance
					closestStage = stage
				end
			end
		end
	end

	return closestStage
end





stageFromSafeZoneName = function(name)
	local lowerName = string.lower(tostring(name))
	local pattern
	if IS_NEW_WORLD1 then
		pattern = "^" .. string.lower(tostring(Config.NewWorld1SafeZonePrefix or "stage")) .. "(%d+)$"
	else
		pattern = IS_WORLD2 and "^safezone(%d+)%.2$" or "^safezone(%d+)$"
	end
	local stage = tonumber(string.match(lowerName, pattern))
	if stage and stage >= 1 and stage <= STAGE_COUNT then
		return stage
	end
	return nil
end



if IS_WORLD2 or (IS_NEW_WORLD1 and NEW_WORLD1_MAP_ROOT) then
	local searchRoot = IS_NEW_WORLD1 and NEW_WORLD1_MAP_ROOT or Workspace
	for _, descendant in ipairs(searchRoot:GetDescendants()) do
		local stage = stageFromSafeZoneName(descendant.Name)
		if stage and isSafeZoneObject(descendant) and not safeZoneReferences[stage] then
			safeZoneReferences[stage] = descendant
		end
	end
end

Workspace.DescendantAdded:Connect(function(descendant)
	if IS_NEW_WORLD1
		and (not NEW_WORLD1_MAP_ROOT or not descendant:IsDescendantOf(NEW_WORLD1_MAP_ROOT))
	then
		return
	end
	local stage = stageFromSafeZoneName(descendant.Name)
	if not stage or not isSafeZoneObject(descendant) then
		return
	end
	local current = safeZoneReferences[stage]
	if not current or not current.Parent then
		safeZoneReferences[stage] = descendant
		safeZoneBoundsCache[stage] = nil
	end
end)

Workspace.DescendantRemoving:Connect(function(descendant)
	local stage = stageFromSafeZoneName(descendant.Name)
	if stage and safeZoneReferences[stage] == descendant then
		safeZoneReferences[stage] = nil
		safeZoneBoundsCache[stage] = nil
	end
end)

local function cleanStage(value)
	return math.clamp(math.floor(tonumber(value) or 1), 1, STAGE_COUNT)
end

local function waitForLivingCharacter(player, timeoutSeconds)
	local deadline = os.clock() + (timeoutSeconds or 12)
	repeat
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if character
			and character.Parent
			and humanoid
			and humanoid.Health > 0
			and root
			and root:IsA("BasePart")
		then
			return character, humanoid, root
		end
		task.wait(0.1)
	until not player.Parent or os.clock() >= deadline

	return nil, nil, nil
end

local function roundProductGain(value)
	value = tonumber(value) or 0
	if value <= 0 then
		return 0
	end

	if value < 1000 then
		if value >= DISPLAY_ROUND_DOWN_STEP then
			return math.max(DISPLAY_ROUND_DOWN_STEP, math.round(value / DISPLAY_ROUND_DOWN_STEP) * DISPLAY_ROUND_DOWN_STEP)
		end
		return math.max(1, math.floor(value + 0.5))
	end

	local tier = math.floor(math.log10(value) / 3) + 1
	local base = 1000 ^ math.max(0, tier - 1)
	local scaled = value / base
	local cleanedScaled

	if scaled >= 10 then
		cleanedScaled = math.max(10, math.round(scaled / 10) * 10)
	else
		cleanedScaled = math.max(1, math.floor(scaled))
	end

	return cleanedScaled * base
end

local function cleanCurrentSpeed(value)
	value = tonumber(value) or tonumber(Config.StartingSpeed) or 1
	if value ~= value or value == math.huge or value == -math.huge then
		value = tonumber(Config.StartingSpeed) or 1
	end
	return math.clamp(value, tonumber(Config.StartingSpeed) or 1, tonumber(Config.MaxStoredSpeed) or 1e50)
end

local function cleanRobuxSpent(value)
	value = tonumber(value) or 0
	if value ~= value or value == math.huge or value == -math.huge or value < 0 then
		return 0
	end
	return math.clamp(math.floor(value), 0, MAX_SAFE_INTEGER)
end

local function getReceiptRobuxAmount(receiptInfo, productEntry)


	local amount = tonumber(receiptInfo.CurrencySpent)
	if not amount or amount ~= amount or amount == math.huge or amount < 0 then
		amount = tonumber(productEntry.Data and productEntry.Data.PriceRobux) or 0
	end
	return cleanRobuxSpent(amount)
end

local function getSpeedObjects(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local speed = leaderstats and leaderstats:FindFirstChild("Speed")
	local dataFolder = player:FindFirstChild("SpeedsterData")
	local rawSpeed = dataFolder and dataFolder:FindFirstChild("RawSpeed")
	return speed, rawSpeed
end

local function getWinsObject(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local wins = leaderstats and leaderstats:FindFirstChild("Wins")
	return wins
end

local function grantStarterPackOnce(player, reason)
	if starterPackGrantBusy[player] then
		return false
	end
	if not waitForPlayerData(player, 12) then
		warn("[SpeedProductPurchases] Starter Pack grant waited for data but DataLoaded never became true for " .. player.Name)
		return false
	end

	if DataService then
		local handle=DataService.GetHandle(player.UserId)
		if not handle then return false end
		local result=DataService.Commit(handle,{
			operationId="starter-pack:"..STARTER_PACK_REWARD_VERSION,fingerprint="starter-pack:"..STARTER_PACK_REWARD_VERSION,
			commands={{kind="GrantStarterPack",version=STARTER_PACK_REWARD_VERSION,
				speed=math.max(0,tonumber(Config.StarterPackSpeedReward) or 100000),wins=math.max(0,tonumber(Config.StarterPackWinsReward) or 100),
				legacySpeed=LEGACY_STARTER_PACK_SPEED_REWARD,legacyWins=LEGACY_STARTER_PACK_WINS_REWARD,trailId=tostring(Config.StarterPackTrailReward or "Trail02")}},
		})
		return result.kind=="Committed" or result.kind=="AlreadyCommitted"
	end
	local currentRewardVersion = math.max(0, math.floor(tonumber(player:GetAttribute("StarterPackRewardVersion")) or 0))
	if player:GetAttribute("StarterPackGranted") == true and currentRewardVersion >= STARTER_PACK_REWARD_VERSION then
		return true
	end

	starterPackGrantBusy[player] = true
	local ok, result = pcall(function()
		local speed, rawSpeed = getSpeedObjects(player)
		local wins = getWinsObject(player)
		local dataFolder = player:FindFirstChild("SpeedsterData")
		local ownedTrails = dataFolder and dataFolder:FindFirstChild("OwnedTrails")
		local savePlayer = _G.SpeedsterSavePlayer

		if not speed or not rawSpeed or not wins or not ownedTrails then
			warn("[SpeedProductPurchases] Starter Pack grant missing player stat/data objects for " .. player.Name)
			return false
		end
		if type(savePlayer) ~= "function" then
			warn("[SpeedProductPurchases] Starter Pack grant is waiting for PlayerStats save hook for " .. player.Name)
			return false
		end

		local trailId = tostring(Config.StarterPackTrailReward or "Trail02")
		local fullSpeedReward = math.max(0, tonumber(Config.StarterPackSpeedReward) or 100000)
		local fullWinsReward = math.max(0, math.floor(tonumber(Config.StarterPackWinsReward) or 100))
		local alreadyHadLegacyGrant = player:GetAttribute("StarterPackGranted") == true





		local speedReward = fullSpeedReward
		local winsReward = fullWinsReward
		if alreadyHadLegacyGrant and currentRewardVersion < STARTER_PACK_REWARD_VERSION then
			speedReward = math.max(0, fullSpeedReward - LEGACY_STARTER_PACK_SPEED_REWARD)
			winsReward = math.max(0, fullWinsReward - LEGACY_STARTER_PACK_WINS_REWARD)
		end

		local newSpeed = math.min(
			tonumber(Config.MaxStoredSpeed) or 1e50,
			cleanCurrentSpeed(rawSpeed.Value) + speedReward
		)
		rawSpeed.Value = newSpeed
		speed.Value = newSpeed
		wins.Value = math.max(0, math.floor((tonumber(wins.Value) or 0) + winsReward))



		local trailValue = ownedTrails:FindFirstChild(trailId)
		if trailValue and not trailValue:IsA("BoolValue") then
			trailValue:Destroy()
			trailValue = nil
		end
		if not trailValue then
			trailValue = Instance.new("BoolValue")
			trailValue.Name = trailId
			trailValue.Parent = ownedTrails
		end
		trailValue.Value = true

		player:SetAttribute("StarterPackGranted", true)
		player:SetAttribute("StarterPackRewardVersion", STARTER_PACK_REWARD_VERSION)
		player:SetAttribute("StarterPackOwned", true)
		if type(_G.SpeedsterApplyWalkSpeed) == "function" then
			_G.SpeedsterApplyWalkSpeed(player)
		end




		local saved = savePlayer(player, "starter_pack_" .. tostring(reason or "owned"), true) == true
		if not saved then
			warn("[SpeedProductPurchases] Starter Pack was granted in-memory but immediate save failed for " .. player.Name .. "; retrying save.")
			task.spawn(function()
				for attempt = 1, 3 do
					if not player.Parent then
						return
					end
					task.wait(attempt * 2)
					if type(_G.SpeedsterSavePlayer) == "function"
						and _G.SpeedsterSavePlayer(player, "starter_pack_retry_" .. tostring(attempt), true) == true
					then
						return
					end
				end
			end)
		end

		print(
			("[SpeedProductPurchases] Starter Pack granted to %s | +%s Speed | +%d Wins | %s unlocked | version %d")
				:format(player.Name, tostring(speedReward), winsReward, trailId, STARTER_PACK_REWARD_VERSION)
		)
		return true
	end)
	starterPackGrantBusy[player] = nil

	if not ok then
		warn("[SpeedProductPurchases] Starter Pack grant failed: " .. tostring(result))
		return false
	end
	return result == true
end

local function grantSpeedTransaction(player, tier)
	if DataService then
		local handle=DataService.GetHandle(player.UserId)
		if not handle then return nil end
		local result=DataService.Commit(handle,{operationId="speed-pass:"..tostring(tier.ProductId),fingerprint="speed-pass",commands={{kind="PurchaseSpeed",tier=tier}}})
		if result.kind~="Committed" and result.kind~="AlreadyCommitted" then return nil end
		return {Rollback=function() end,Commit=function() end}
	end

	local speed, rawSpeed = getSpeedObjects(player)
	if not speed or not rawSpeed then
		return nil
	end

	local currentSpeed = cleanCurrentSpeed(rawSpeed.Value)
	local gainMultiplier = tonumber(tier.GainMultiplier) or 0
	local minGain = tonumber(tier.MinGain)
		or (tier.Tier == 1 and 500
			or tier.Tier == 2 and 2500
			or tier.Tier == 3 and 10000
			or tier.Tier == 4 and 50000
			or 100)

	local percentGain = gainMultiplier > 0 and roundProductGain(currentSpeed * gainMultiplier) or 0
	local requestedGain = math.max(minGain, percentGain)
	local newSpeed = math.min(tonumber(Config.MaxStoredSpeed) or 1e50, currentSpeed + requestedGain)
	local actualGain = math.max(1, newSpeed - currentSpeed)
	local oldSpeed = speed.Value
	local oldRawSpeed = rawSpeed.Value
	local oldTier = player:GetAttribute("LastSpeedProductTier")
	local oldGain = player:GetAttribute("LastSpeedProductGain")

	rawSpeed.Value = newSpeed
	speed.Value = newSpeed
	player:SetAttribute("RawSpeed", newSpeed)
	player:SetAttribute("LastSpeedProductTier", tonumber(tier.Tier) or 0)
	player:SetAttribute("LastSpeedProductGain", actualGain)

	return {
		Rollback = function()
			if rawSpeed.Parent then
				rawSpeed.Value = oldRawSpeed
			end
			if speed.Parent then
				speed.Value = oldSpeed
			end
			player:SetAttribute("RawSpeed", oldRawSpeed)
			player:SetAttribute("LastSpeedProductTier", oldTier)
			player:SetAttribute("LastSpeedProductGain", oldGain)

			if _G.SpeedsterApplyWalkSpeed then
				_G.SpeedsterApplyWalkSpeed(player)
			end
		end,
		Commit = function()
			if actualGain > 0 and player.Parent then
				SpeedGainPopup:FireClient(player, {
					Amount = actualGain,
					TotalSpeed = cleanCurrentSpeed(newSpeed),
					Color = tierPopupColors[tonumber(tier.Tier)] or Color3.fromRGB(255, 215, 40),
					BurstCount = 8,
					SoundPlaybackSpeed = 1.05,
				})
			end
		end,
	}
end

local function grantPermanentMultiplierTransaction(player, product)
	local current = tonumber(player:GetAttribute("PermanentBaseSpeedMultiplier")) or 1
	if current ~= current or current == math.huge or current == -math.huge then
		current = 1
	end
	current = math.max(1, current)

	local target = math.max(1, tonumber(product.TargetMultiplier) or 1)
	local newMultiplier = math.max(current, target)
	if product.RepeatAddMultiplier and current >= target then
		newMultiplier = math.min(tonumber(Config.MaxPermanentSpeedMultiplier) or 32, current + math.max(1, tonumber(product.RepeatAddMultiplier) or 10))
	end

	local oldLastPurchase = player:GetAttribute("LastPermanentSpeedMultiplierPurchase")
	player:SetAttribute("PermanentBaseSpeedMultiplier", newMultiplier)
	player:SetAttribute("LastPermanentSpeedMultiplierPurchase", newMultiplier)
	if type(_G.SpeedsterSetPermanentBaseSpeedMultiplier) == "function" then
		_G.SpeedsterSetPermanentBaseSpeedMultiplier(player, newMultiplier)
	end
	if type(_G.SpeedsterSavePlayer) == "function" then
		_G.SpeedsterSavePlayer(player, "permanent_speed_multiplier", true)
	end

	return {
		Rollback = function()
			player:SetAttribute("PermanentBaseSpeedMultiplier", current)
			player:SetAttribute("LastPermanentSpeedMultiplierPurchase", oldLastPurchase)
			if type(_G.SpeedsterSetPermanentBaseSpeedMultiplier) == "function" then
				_G.SpeedsterSetPermanentBaseSpeedMultiplier(player, current)
			end
		end,
		Commit = function()
			print(string.format("[SpeedProductPurchases] Permanent speed multiplier updated to x%d for %s", newMultiplier, player.Name))
		end,
	}
end

local function grantPermanentWinsMultiplierTransaction(player, product)
	local current = tonumber(player:GetAttribute("PermanentWinsMultiplier")) or 1
	if current ~= current or current == math.huge or current == -math.huge then
		current = 1
	end
	current = math.max(1, current)

	local stage = tonumber(product.Stage) or 0
	local target = math.max(1, tonumber(product.TargetMultiplier) or 1)
	local newMultiplier = current

	if (stage >= 1 and stage <= 5) or target > 1 then
		newMultiplier = math.max(current, target)
	else
		return nil
	end

	local oldLastPurchase = player:GetAttribute("LastPermanentWinsMultiplierPurchase")
	local oldDoubleWinsUnlocked = player:GetAttribute("DoubleWinsPadUnlocked")

	player:SetAttribute("PermanentWinsMultiplier", newMultiplier)
	player:SetAttribute("LastPermanentWinsMultiplierPurchase", newMultiplier)
	if newMultiplier >= 2 then
		player:SetAttribute("DoubleWinsPadUnlocked", true)
	end

	if type(_G.SpeedsterSetPermanentWinsMultiplier) == "function" then
		_G.SpeedsterSetPermanentWinsMultiplier(player, newMultiplier)
	end
	if type(_G.SpeedsterSavePlayer) == "function" then
		_G.SpeedsterSavePlayer(player, "permanent_wins_multiplier", true)
	end

	return {
		Rollback = function()
			player:SetAttribute("PermanentWinsMultiplier", current)
			player:SetAttribute("LastPermanentWinsMultiplierPurchase", oldLastPurchase)
			player:SetAttribute("DoubleWinsPadUnlocked", oldDoubleWinsUnlocked)
			if type(_G.SpeedsterSetPermanentWinsMultiplier) == "function" then
				_G.SpeedsterSetPermanentWinsMultiplier(player, current)
			end
		end,
		Commit = function()
			print(string.format("[SpeedProductPurchases] Permanent wins multiplier updated to x%d for %s", newMultiplier, player.Name))
		end,
	}
end

local function grantStageTeleportTransaction(player, option)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not root or not root:IsA("BasePart") then
		return nil
	end

	local oldPivot = character:GetPivot()
	local oldLinearVelocity = root.AssemblyLinearVelocity
	local oldAngularVelocity = root.AssemblyAngularVelocity
	local stage = math.floor(tonumber(option.Stage) or 0)
	local teleported, reason = StageTeleportService.TeleportPlayer(player, stage)
	if not teleported then
		warn("[SpeedProductPurchases] Stage teleport could not be granted: " .. tostring(reason))
		return nil
	end

	return {
		Rollback = function()
		end,
		Commit = function()
			local remotes = ReplicatedStorage:FindFirstChild("Remotes")
			local update = remotes and remotes:FindFirstChild("TeleportUpdate")
			if update and update:IsA("RemoteEvent") and player.Parent then
				update:FireClient(player, {
					Message = "Teleported to Stage " .. tostring(stage),
					Success = true,
					Stage = stage,
				})
			end
		end,
	}
end

local function grantRebirthTransaction(player, data)
	local amount = math.max(1, math.floor(tonumber(data and data.Amount) or 1))
	if type(_G.SpeedsterAddRebirths) == "function" then
		_G.SpeedsterAddRebirths(player, amount)
	end
	return {
		Rollback = function()
		end,
		Commit = function()
			local remotes = ReplicatedStorage:FindFirstChild("Remotes")
			local rebirthUpdate = remotes and remotes:FindFirstChild("RebirthUpdate")
			if rebirthUpdate and rebirthUpdate:IsA("RemoteEvent") and player.Parent then
				rebirthUpdate:FireClient(player, {
					Message = "Rebirth purchased!",
					Success = true,
					Rebirths = tonumber(player:GetAttribute("Rebirths")) or 0,
				})
			end
		end,
	}
end

local function grantSkipStageTransaction(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not root or not root:IsA("BasePart") then
		return nil
	end

	local pendingFrom = math.floor(tonumber(player:GetAttribute("PendingSkipStageFrom")) or 0)
	local pendingTarget = math.floor(tonumber(player:GetAttribute("PendingSkipStageTarget")) or 0)
	local pendingSetAt = tonumber(player:GetAttribute("PendingSkipStageSetAt")) or 0
	local pendingFresh = pendingSetAt > 0 and (Workspace:GetServerTimeNow() - pendingSetAt) <= 10 * 60

	local fromStage = pendingFresh and pendingFrom or 0
	local targetStage = pendingFresh and pendingTarget or 0

	if fromStage < 1 or fromStage >= STAGE_COUNT or targetStage ~= fromStage + 1 then
		fromStage = math.floor(tonumber(player:GetAttribute("CurrentSafeZoneStage")) or 0)
		if fromStage < 1 or fromStage >= STAGE_COUNT then
			fromStage = math.floor(tonumber(player:GetAttribute("LastReachedStage")) or 1)
		end
		fromStage = math.clamp(fromStage, 1, math.max(1, STAGE_COUNT - 1))
		targetStage = fromStage + 1
	end

	if targetStage < 2 or targetStage > STAGE_COUNT then
		warn("[SpeedProductPurchases] Skip Stage target was invalid: " .. tostring(targetStage))
		return nil
	end

	local oldPivot = character:GetPivot()
	local oldLinearVelocity = root.AssemblyLinearVelocity
	local oldAngularVelocity = root.AssemblyAngularVelocity
	local oldLastReachedStage = player:GetAttribute("LastReachedStage")
	local oldCurrentSafeZoneStage = player:GetAttribute("CurrentSafeZoneStage")
	local oldPendingFrom = player:GetAttribute("PendingSkipStageFrom")
	local oldPendingTarget = player:GetAttribute("PendingSkipStageTarget")
	local oldPendingSetAt = player:GetAttribute("PendingSkipStageSetAt")
	local oldPendingWorld = player:GetAttribute("PendingSkipStageWorld")

	local teleported, reason = StageTeleportService.TeleportPlayer(player, targetStage)
	if not teleported then
		warn("[SpeedProductPurchases] Skip Stage could not be granted: " .. tostring(reason))
		return nil
	end

	return {
		Rollback = function()
			if player.Character == character and character.Parent and root.Parent then
				character:PivotTo(oldPivot)
				root.AssemblyLinearVelocity = oldLinearVelocity
				root.AssemblyAngularVelocity = oldAngularVelocity
			end
			player:SetAttribute("LastReachedStage", oldLastReachedStage)
			player:SetAttribute("CurrentSafeZoneStage", oldCurrentSafeZoneStage)
			player:SetAttribute("PendingSkipStageFrom", oldPendingFrom)
			player:SetAttribute("PendingSkipStageTarget", oldPendingTarget)
			player:SetAttribute("PendingSkipStageSetAt", oldPendingSetAt)
			player:SetAttribute("PendingSkipStageWorld", oldPendingWorld)
		end,
		Commit = function()
			player:SetAttribute("PendingSkipStageFrom", nil)
			player:SetAttribute("PendingSkipStageTarget", nil)
			player:SetAttribute("PendingSkipStageSetAt", nil)
			player:SetAttribute("PendingSkipStageWorld", nil)

			local remotes = ReplicatedStorage:FindFirstChild("Remotes")
			local update = remotes and remotes:FindFirstChild("TeleportUpdate")
			if update and update:IsA("RemoteEvent") and player.Parent then
				update:FireClient(player, {
					Message = "Skipped to Stage " .. tostring(targetStage),
					Success = true,
					Stage = targetStage,
				})
			end
		end,
	}
end

RunService.Heartbeat:Connect(function()
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if character and root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then
			if humanoid.FloorMaterial ~= Enum.Material.Air and root.Position.Y > -10 then
				local currentStage = cleanStage(player:GetAttribute("LastReachedStage") or 1)
				playerLastGrounded[player] = {
					CFrame = root.CFrame,
					Position = root.Position,
					Stage = currentStage,
					Timestamp = os.clock(),
				}
			end
		end
	end
end)

local function performReliableTeleport(player, character, humanoid, root, targetCFrame, stage)
	print(string.format("[Revive] Teleporting %s to: (%.1f, %.1f, %.1f) | Stage %s",
		player.Name, targetCFrame.Position.X, targetCFrame.Position.Y, targetCFrame.Position.Z, tostring(stage)))

	local standHeight = 3.5
	if humanoid and root:IsA("BasePart") then
		standHeight = math.max(3.25, (tonumber(humanoid.HipHeight) or 2) + root.Size.Y * 0.5 + 0.55)
	end
	if humanoid then
		humanoid.Health = humanoid.MaxHealth
	end

	-- Arm 4.0 seconds of invulnerability shield so hazards do not instantly re-kill the player
	local serial = math.max(0, math.floor(tonumber(player:GetAttribute("StageTeleportProtectionSerial")) or 0)) + 1
	player:SetAttribute("StageTeleportProtectionSerial", serial)
	player:SetAttribute("StageTeleportInvulnerable", true)
	player:SetAttribute("StageTeleportArrivalGraceUntil", os.clock() + 4.0)
	task.delay(4.0, function()
		if player.Parent and tonumber(player:GetAttribute("StageTeleportProtectionSerial")) == serial then
			player:SetAttribute("StageTeleportInvulnerable", false)
		end
	end)

	player:SetAttribute("LastReachedStage", stage)
	player:SetAttribute("CurrentSafeZoneStage", stage)

	-- Anchor briefly to eliminate client spawn physics race condition
	root.Anchored = true
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	character:PivotTo(targetCFrame)
	root.CFrame = targetCFrame

	-- Tell client to sync local root CFrame and camera immediately
	ReviveCommerce:FireClient(player, {
		Type = "ReviveTeleport",
		TargetCFrame = targetCFrame,
		Stage = stage,
	})

	-- Re-assert position over next 2 Heartbeat frames, then unanchor
	task.spawn(function()
		RunService.Heartbeat:Wait()
		if root and root.Parent and character and character.Parent then
			character:PivotTo(targetCFrame)
			root.CFrame = targetCFrame
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
		end
		RunService.Heartbeat:Wait()
		if root and root.Parent and character and character.Parent then
			character:PivotTo(targetCFrame)
			root.CFrame = targetCFrame
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
			root.Anchored = false
		end
	end)

	local vmgRebase = _G.VortexMovementGuardRebase
	if type(vmgRebase) == "function" then
		pcall(vmgRebase, player, stage)
	end
end

local function grantReviveTransaction(player)
	local context = pendingRevivePurchases[player]
	if context and (tonumber(context.ExpiresAt) or 0) < os.clock() then
		pendingRevivePurchases[player] = nil
		context = nil
	end

	local stage = cleanStage(
		context and context.Stage
			or player:GetAttribute("ReviveStageAtDeath")
			or player:GetAttribute("LastReachedStage")
			or 1
	)
	print("[Revive] grantReviveTransaction started for " .. player.Name .. " | stage=" .. tostring(stage))

	local character, humanoid, root = waitForLivingCharacter(player, 12)
	if not character or not root then
		warn("[Revive] waitForLivingCharacter timed out for " .. player.Name)
		return nil
	end

	local oldPivot = character:GetPivot()
	local oldLinearVelocity = root.AssemblyLinearVelocity
	local oldAngularVelocity = root.AssemblyAngularVelocity
	local oldLastReachedStage = player:GetAttribute("LastReachedStage")
	local oldCurrentSafeZoneStage = player:GetAttribute("CurrentSafeZoneStage")

	local deathCFrame = (context and context.DeathCFrame)
		or (activeReviveOffers[player] and activeReviveOffers[player].DeathCFrame)
	local deathPosition = (context and context.DeathPosition)
		or (activeReviveOffers[player] and activeReviveOffers[player].DeathPosition)
		or player:GetAttribute("ReviveDeathPosition")

	if not deathCFrame and typeof(deathPosition) == "Vector3" then
		deathCFrame = CFrame.new(deathPosition)
	end

	local standHeight = 3.5
	if humanoid and root:IsA("BasePart") then
		standHeight = math.max(3.25, (tonumber(humanoid.HipHeight) or 2) + root.Size.Y * 0.5 + 0.55)
	end

	local targetCFrame = nil
	local teleported = false
	local reason = nil

	-- Teleport player to the Safe Zone of the stage where they died
	print(string.format("[Revive] Teleporting %s to Safe Zone of Stage %s", player.Name, tostring(stage)))
	teleported, reason = StageTeleportService.TeleportPlayer(player, stage)

	if not teleported then
		warn("[Revive] Revive could not be granted: " .. tostring(reason))
		return nil
	end

	return {
		Rollback = function()
			if player.Character == character and character.Parent and root.Parent then
				character:PivotTo(oldPivot)
				root.AssemblyLinearVelocity = oldLinearVelocity
				root.AssemblyAngularVelocity = oldAngularVelocity
			end
			player:SetAttribute("LastReachedStage", oldLastReachedStage)
			player:SetAttribute("CurrentSafeZoneStage", oldCurrentSafeZoneStage)
		end,
		Commit = function()
			if pendingRevivePurchases[player] == context then
				pendingRevivePurchases[player] = nil
			end
			if player.Parent then
				ReviveCommerce:FireClient(player, {
					Type = "Granted",
					Stage = stage,
				})
			end
			print("[Revive] Revive commit finished successfully for " .. player.Name)
		end,
	}
end

local function grantFreeInfiniteRevive(player, offer)
	local context = {
		Stage = cleanStage(offer.Stage),
		Token = offer.Token,
		DeathCFrame = offer.DeathCFrame,
		DeathPosition = offer.DeathPosition,
		ExpiresAt = os.clock() + 10 * 60,
	}
	pendingRevivePurchases[player] = context

	task.spawn(function()
		local transaction = grantReviveTransaction(player)
		if not transaction then
			if pendingRevivePurchases[player] == context then
				pendingRevivePurchases[player] = nil
			end
			offer.Claiming = false
			warn("[Revive] Free Infinite Revive transaction failed for " .. player.Name)
			if activeReviveOffers[player] == offer
				and os.clock() <= (tonumber(offer.ExpiresAt) or 0)
			then
				ReviveCommerce:FireClient(player, {
					Type = "Retry",
					Token = offer.Token,
				})
			end
			return
		end

		local committed, commitError = pcall(transaction.Commit)
		if not committed then
			pcall(transaction.Rollback)
			if pendingRevivePurchases[player] == context then
				pendingRevivePurchases[player] = nil
			end
			offer.Claiming = false
			warn("[Revive] Free Infinite Revive commit failed: " .. tostring(commitError))
			if activeReviveOffers[player] == offer
				and os.clock() <= (tonumber(offer.ExpiresAt) or 0)
			then
				ReviveCommerce:FireClient(player, {
					Type = "Retry",
					Token = offer.Token,
				})
			end
			return
		end

		if activeReviveOffers[player] == offer then
			activeReviveOffers[player] = nil
		end
		print("[Revive] Free Infinite Revive successfully granted for " .. player.Name)
	end)
end

local function grantFlightAbilityTransaction(player)
	if IS_WORLD2 or Config.AbilityFlightEnabled ~= true then
		return nil
	end

	local dataFolder = player:FindFirstChild("SpeedsterData")
	if not dataFolder then
		dataFolder = Instance.new("Folder")
		dataFolder.Name = "SpeedsterData"
		dataFolder.Parent = player
	end

	local ownedFolder = dataFolder:FindFirstChild("OwnedUpgrades")
	if not ownedFolder or not ownedFolder:IsA("Folder") then
		if ownedFolder then pcall(function() ownedFolder:Destroy() end) end
		ownedFolder = Instance.new("Folder")
		ownedFolder.Name = "OwnedUpgrades"
		ownedFolder.Parent = dataFolder
	end

	local upgradeName = tostring(Config.AbilityFlightUpgradeName or "Flight")
	local equipMarkerName = "__AbilityEquipped_Flight"
	local equipInitName = "__AbilityEquipStateInitialized"
	local existing = ownedFolder:FindFirstChild(upgradeName)
	if existing and not existing:IsA("BoolValue") then
		pcall(function() existing:Destroy() end)
		existing = nil
	end

	local created = false
	local oldValue = existing and existing.Value or false
	local oldEquipInit = ownedFolder:FindFirstChild(equipInitName)
	local oldEquipMarker = ownedFolder:FindFirstChild(equipMarkerName)
	if oldEquipInit and not oldEquipInit:IsA("BoolValue") then
		pcall(function() oldEquipInit:Destroy() end)
		oldEquipInit = nil
	end
	if oldEquipMarker and not oldEquipMarker:IsA("BoolValue") then
		pcall(function() oldEquipMarker:Destroy() end)
		oldEquipMarker = nil
	end
	local oldEquipInitValue = oldEquipInit and oldEquipInit.Value or false
	local oldEquipMarkerValue = oldEquipMarker and oldEquipMarker.Value or false
	local createdEquipInit = false
	local oldAttribute = player:GetAttribute("FlightAbilityOwned")
	local oldPending = player:GetAttribute("FlightAbilityGrantPending")
	player:SetAttribute("FlightAbilityGrantPending", true)
	local flag = existing
	if not flag then
		flag = Instance.new("BoolValue")
		flag.Name = upgradeName
		flag.Parent = ownedFolder
		created = true
	end
	flag.Value = true

	if oldValue ~= true then
		local init = oldEquipInit
		if not init then
			init = Instance.new("BoolValue")
			init.Name = equipInitName
			init.Parent = ownedFolder
			createdEquipInit = true
		end
		init.Value = true
		local equip = oldEquipMarker
		if not equip then
			equip = Instance.new("BoolValue")
			equip.Name = equipMarkerName
			equip.Parent = ownedFolder
		end
		equip.Value = true
	end

	return {
		Rollback = function()
			if created then
				if flag.Parent then flag:Destroy() end
			elseif flag.Parent then
				flag.Value = oldValue
			end
			if createdEquipInit then
				local init = ownedFolder:FindFirstChild(equipInitName)
				if init then init:Destroy() end
			elseif oldEquipInit and oldEquipInit.Parent then
				oldEquipInit.Value = oldEquipInitValue
			end
			if oldEquipMarker and oldEquipMarker.Parent then
				oldEquipMarker.Value = oldEquipMarkerValue
			end
			player:SetAttribute("FlightAbilityOwned", oldAttribute)
			player:SetAttribute("FlightAbilityGrantPending", oldPending)
		end,
		Commit = function()
			player:SetAttribute("FlightAbilityOwned", true)
			player:SetAttribute("FlightAbilityEquipped", true)
			player:SetAttribute("EquippedAbility", "Flight")
			player:SetAttribute("FlightAbilityGrantPending", nil)
			if type(_G.SpeedsterUnlockUpgrade) == "function" then
				pcall(_G.SpeedsterUnlockUpgrade, player, upgradeName)
			end
			if type(_G.SpeedsterGrantFlight) == "function" then
				pcall(_G.SpeedsterGrantFlight, player, "flight_robux_purchase")
			else
				local savePlayer = _G.SpeedsterSavePlayer
				if type(savePlayer) == "function" then
					pcall(savePlayer, player, "flight_robux_purchase", true)
				end
			end
			local refresh = _G.SpeedsterRefreshAbilityShop
			if type(refresh) == "function" and player.Parent then
				refresh(player, "Flight Purchased & Equipped!")
			end
		end,
	}
end

local function grantCosmeticUnlockTransaction(player, data)
	local cosmeticType = tostring(data and data.CosmeticType or "")
	local cosmeticId = tostring(data and data.CosmeticId or "")
	local displayName = tostring(data and data.DisplayName or cosmeticId)
	local folderName
	local refreshShop
	if cosmeticType == "Trail" then
		folderName = "OwnedTrails"
		refreshShop = function(message)
			local refresh = _G.SpeedsterRefreshTrailShop
			if type(refresh) == "function" then refresh(player, message) end
		end
	elseif cosmeticType == "Aura" then
		folderName = "OwnedAuras"
		refreshShop = function(message)
			local refresh = _G.SpeedsterRefreshAuraShop
			if type(refresh) == "function" then refresh(player, message) end
		end
	else
		return nil
	end

	if cosmeticId == "" or not CosmeticCatalog.IsValid(cosmeticType, cosmeticId) then
		return nil
	end

	local dataFolder = player:FindFirstChild("SpeedsterData")
	if not dataFolder then
		return nil
	end
	local ownedFolder = dataFolder:FindFirstChild(folderName)
	local createdFolder = false
	if not ownedFolder then
		ownedFolder = Instance.new("Folder")
		ownedFolder.Name = folderName
		ownedFolder.Parent = dataFolder
		createdFolder = true
	end

	local flag = ownedFolder:FindFirstChild(cosmeticId)
	if flag and not flag:IsA("BoolValue") then
		return nil
	end
	local createdFlag = false
	local oldValue = false
	if flag then
		oldValue = flag.Value == true
	else
		flag = Instance.new("BoolValue")
		flag.Name = cosmeticId
		flag.Parent = ownedFolder
		createdFlag = true
	end
	flag.Value = true

	if cosmeticType == "Aura" and type(_G.SpeedsterUnlockAura) == "function" then
		_G.SpeedsterUnlockAura(player, cosmeticId)
	elseif cosmeticType == "Trail" and type(_G.SpeedsterUnlockTrail) == "function" then
		_G.SpeedsterUnlockTrail(player, cosmeticId)
	end

	return {
		Rollback = function()
			if createdFlag then
				if flag.Parent then flag:Destroy() end
			elseif flag.Parent then
				flag.Value = oldValue
			end
			if createdFolder and ownedFolder.Parent and #ownedFolder:GetChildren() == 0 then
				ownedFolder:Destroy()
			end
		end,
		Commit = function()
			local entry = CosmeticCatalog.GetEntry(cosmeticType, cosmeticId)
			local multiplier = entry and (tonumber(entry.SpeedMultiplier) or 1) or 1
			pcall(function()
				local CosmeticService = require(ServerScriptService:WaitForChild("Economy"):WaitForChild("Cosmetics"):WaitForChild("CosmeticService"))
				if cosmeticType == "Aura" then
					CosmeticService.EquipAura(player, cosmeticId)
				elseif cosmeticType == "Trail" then
					CosmeticService.EquipTrail(player, cosmeticId)
				end
			end)
			if cosmeticType == "Aura" and type(_G.SpeedsterEquipAura) == "function" then
				_G.SpeedsterEquipAura(player, cosmeticId, multiplier)
			elseif cosmeticType == "Trail" and type(_G.SpeedsterEquipTrail) == "function" then
				_G.SpeedsterEquipTrail(player, cosmeticId, multiplier)
			end
			if dataFolder then
				local eqName = cosmeticType == "Trail" and "EquippedTrail" or "EquippedAura"
				local eqVal = dataFolder:FindFirstChild(eqName)
				if not eqVal then
					eqVal = Instance.new("StringValue")
					eqVal.Name = eqName
					eqVal.Parent = dataFolder
				end
				eqVal.Value = cosmeticId
			end
			if type(_G.SpeedsterSavePlayer) == "function" then
				_G.SpeedsterSavePlayer(player, "cosmetic_robux_unlock_" .. tostring(cosmeticId), true)
			end
			refreshShop("Bought " .. displayName .. " with Robux")
		end,
	}
end

local function grantPotionPurchaseTransaction(player, product, grantFunction)
	if not player or not grantFunction then
		return nil
	end
	local durationMinutes = math.max(1, math.floor(tonumber(product.DurationMinutes) or 10))
	local targetMultiplier = tonumber(product.TargetMultiplier) or 0
	local bottleType = product.ShopFrame or product.Label or "small"
	local granted = targetMultiplier > 0
		and grantFunction(player, durationMinutes, targetMultiplier, bottleType)
		or grantFunction(player, durationMinutes, nil, bottleType)
	if not granted then
		return nil
	end
	return {
		Rollback = function()
			if type(granted.Rollback) == "function" then
				granted.Rollback()
			end
		end,
		Commit = function()
			if type(granted.Notify) == "function" then
				granted.Notify()
			end
		end,
	}
end

local function grantServerBoostTransaction(product, buyer)
	local durationMinutes = math.max(1, math.floor(tonumber(product.DurationMinutes) or 30))
	local targetMultiplier = tonumber(product.TargetMultiplier) or 0
	local buyerName = (buyer and buyer:IsA("Player")) and buyer.Name or nil
	local granted = targetMultiplier > 0
		and PotionServer.GrantServerBoost(durationMinutes, targetMultiplier, buyerName)
		or PotionServer.GrantServerBoost(durationMinutes, nil, buyerName)
	if not granted then
		return nil
	end
	return {
		Rollback = function()
			if type(granted.Rollback) == "function" then
				granted.Rollback()
			end
		end,
		Commit = function()
			if type(granted.Notify) == "function" then
				granted.Notify()
			end
		end,
	}
end

local function grantRebirthTransaction(player, data)
	local amount = math.max(1, math.floor(tonumber(data and data.Amount) or 1))
	local leaderstats = player:FindFirstChild("leaderstats")
	local rebirthsStat = leaderstats and leaderstats:FindFirstChild("Rebirths")
	local oldRebirths = tonumber(player:GetAttribute("Rebirths")) or (rebirthsStat and tonumber(rebirthsStat.Value)) or 0

	return {
		Rollback = function()
			player:SetAttribute("Rebirths", oldRebirths)
			if rebirthsStat then
				rebirthsStat.Value = oldRebirths
			end
		end,
		Commit = function()
			if type(_G.SpeedsterAddRebirths) == "function" then
				_G.SpeedsterAddRebirths(player, amount)
			else
				local newRebirths = oldRebirths + amount
				player:SetAttribute("Rebirths", newRebirths)
				if rebirthsStat then
					rebirthsStat.Value = newRebirths
				end
				local savePlayer = _G.SpeedsterSavePlayer
				if type(savePlayer) == "function" then
					pcall(savePlayer, player, "developer_product_rebirth", true)
				end
			end
			local remotes = ReplicatedStorage:FindFirstChild("Remotes")
			local rebirthUpdate = remotes and remotes:FindFirstChild("RebirthUpdate")
			if rebirthUpdate and rebirthUpdate:IsA("RemoteEvent") and player.Parent then
				rebirthUpdate:FireClient(player, {
					Message = "Rebirth purchased!",
					Success = true,
					Rebirths = tonumber(player:GetAttribute("Rebirths")) or 0,
				})
			end
			print(string.format("[SpeedProductPurchases] Granted %d Rebirth(s) via Developer Product to %s", amount, player.Name))
		end,
	}
end

local function grantProductTransaction(player, productEntry)
	if productEntry.Kind == "SpeedAmount" then
		return grantSpeedTransaction(player, productEntry.Data)
	elseif productEntry.Kind == "PermanentMultiplier" then
		return grantPermanentMultiplierTransaction(player, productEntry.Data)
	elseif productEntry.Kind == "PermanentWinsMultiplier" then
		return grantPermanentWinsMultiplierTransaction(player, productEntry.Data)
	elseif productEntry.Kind == "StageTeleport" then
		return grantStageTeleportTransaction(player, productEntry.Data)
	elseif productEntry.Kind == "SkipStage" then
		return grantSkipStageTransaction(player)
	elseif productEntry.Kind == "Revive" then
		return grantReviveTransaction(player)
	elseif productEntry.Kind == "AbilityFlight" then
		return grantFlightAbilityTransaction(player)
	elseif productEntry.Kind == "CosmeticUnlock" then
		return grantCosmeticUnlockTransaction(player, productEntry.Data)
	elseif productEntry.Kind == "PotionSpeed" then
		return grantPotionPurchaseTransaction(player, productEntry.Data, PotionServer.GrantSpeedPotion)
	elseif productEntry.Kind == "PotionWins" then
		return grantPotionPurchaseTransaction(player, productEntry.Data, PotionServer.GrantWinsPotion)
	elseif productEntry.Kind == "ServerBoost" then
		return grantServerBoostTransaction(productEntry.Data, player)
	elseif productEntry.Kind == "Rebirth" then
		return grantRebirthTransaction(player, productEntry.Data)
	end
	return nil
end

-- Persistent rewards and their receipt marker are committed in the same profile write.
local function persistentReceiptCommands(entry)
	local data = entry.Data or {}
	if entry.Kind == "SpeedAmount" then
		return {{kind="PurchaseSpeed",tier=data}}
	elseif entry.Kind == "PermanentMultiplier" or entry.Kind == "PermanentWinsMultiplier" then
		local speed = entry.Kind == "PermanentMultiplier"
		return {{kind="PurchaseMultiplier",key=if speed then "PermanentBaseSpeedMultiplier" else "PermanentWinsMultiplier",
			target=math.max(1,tonumber(data.TargetMultiplier) or 1),repeatAdd=if speed then tonumber(data.RepeatAddMultiplier) else nil,
			cap=tonumber(Config.MaxPermanentSpeedMultiplier) or 32}}
	elseif entry.Kind == "Rebirth" then
		return {{kind="GrantExact",stat="Rebirths",amount=math.max(1,tonumber(data.Amount) or 1)}}
	elseif entry.Kind == "AbilityFlight" then
		return {{kind="GrantUpgrade",upgradeId="Flight"}}
	elseif entry.Kind == "CosmeticUnlock" then
		if data.CosmeticType == "Trail" then return {{kind="GrantTrail",trailId=data.CosmeticId},{kind="EquipTrail",trailId=data.CosmeticId}} end
		if data.CosmeticType == "Aura" then return {{kind="GrantAura",auraId=data.CosmeticId},{kind="EquipAura",auraId=data.CosmeticId}} end
	elseif entry.Kind == "PotionSpeed" or entry.Kind == "PotionWins" then
		local speed = entry.Kind == "PotionSpeed"
		return {{kind="GrantBuff",grant={kind=if speed then "SpeedPotion" else "WinsPotion",
			addedSeconds=math.max(1,tonumber(data.DurationMinutes) or 15)*60,
			multiplier=tonumber(data.TargetMultiplier) or 2,bottleType=data.BottleType}}}
	end
	return nil
end

local function commitPersistentReceipt(player, recipient, receiptInfo, entry, commands)
	local handle = DataService.GetHandle(recipient.UserId)
	if not handle then return false end
	local purchaseId = tostring(receiptInfo.PurchaseId)
	local robux = getReceiptRobuxAmount(receiptInfo,entry)
	if recipient == player then table.insert(commands,{kind="RecordRobuxSpent",amount=robux}) end
	local result = DataService.Commit(handle,{
		operationId="receipt:"..purchaseId,receiptId=purchaseId,
		fingerprint=tostring(receiptInfo.ProductId),commands=commands,
	})
	if result.kind ~= "Committed" and result.kind ~= "AlreadyCommitted" then return false end
	if recipient ~= player then
		local buyerHandle = DataService.GetHandle(player.UserId)
		if not buyerHandle then return false end
		local buyerResult = DataService.Commit(buyerHandle,{
			operationId="gift-buyer:"..purchaseId,receiptId=purchaseId,
			fingerprint="gift:"..tostring(receiptInfo.ProductId)..":"..recipient.UserId,
			commands={{kind="RecordRobuxSpent",amount=robux}},
		})
		if buyerResult.kind ~= "Committed" and buyerResult.kind ~= "AlreadyCommitted" then return false end
	end
	return true
end


local function processReceipt(receiptInfo)
	local productId = tonumber(receiptInfo.ProductId)
	local productEntry = productsById[productId]
	if not productEntry then
		for _, option in ipairs(Config.TeleportStageOptions or {}) do
			if tonumber(option.ProductId) == productId then
				productEntry = { Kind = "StageTeleport", Data = option }
				productsById[productId] = productEntry
				break
			end
		end
		if not productEntry and tonumber(Config.RebirthProductId) == productId and productId > 0 then
			productEntry = { Kind = "Rebirth", Data = { ProductId = productId, Amount = 1, PriceRobux = tonumber(Config.RebirthPriceRobux) or 14 } }
			productsById[productId] = productEntry
		end
	end
	if not productEntry then
		warn("[SpeedProductPurchases] Unknown Developer Product ID: " .. tostring(productId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local purchaseId = tostring(receiptInfo.PurchaseId or "")
	if purchaseId == "" then
		warn("[SpeedProductPurchases] Roblox supplied an empty PurchaseId")
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local player=Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player or not waitForPlayerData(player,10) then return Enum.ProductPurchaseDecision.NotProcessedYet end
	if DataService then
		local handle=DataService.GetHandle(player.UserId)
		local view=handle and DataService.Inspect(handle)
		if not view or not view.ok then return Enum.ProductPurchaseDecision.NotProcessedYet end
		local contexts=view.value.profile.Update2GiftContexts or {}
		receiptInfo=table.clone(receiptInfo)
		receiptInfo.TargetUserId=contexts[tostring(productId)] or player.UserId
		receiptInfo.GiftContextId=(view.value.profile.Update2GiftContextIds or {})[tostring(productId)] or ""
	end
	local receiptOk, receiptDecision, claimOwnerId, targetUserId, giftContextId = acquireReceipt(receiptInfo)
	if not receiptOk then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if receiptDecision == "granted" then
		if DataService and (targetUserId or player.UserId)~=player.UserId then
			local handle=DataService.GetHandle(player.UserId)
			if handle then
				DataService.Commit(handle,{operationId="gift-clear:"..purchaseId,fingerprint="gift-clear",commands={{kind="ClearGiftContext",productId=tostring(productId),targetUserId=targetUserId,contextId=giftContextId or ""}}})
			end
		end
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local function retryLater()
		releaseReceiptLease(receiptInfo, claimOwnerId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local grantPlayer=Players:GetPlayerByUserId(targetUserId or receiptInfo.TargetUserId or player.UserId)
	if not grantPlayer or not waitForPlayerData(grantPlayer,10) then return retryLater() end

	local hasProcessed = _G.SpeedsterHasProcessedReceipt
	local markProcessed = _G.SpeedsterMarkProcessedReceipt
	local clearProcessed = _G.SpeedsterClearProcessedReceipt
	local savePlayer = _G.SpeedsterSavePlayer
	if type(hasProcessed) ~= "function"
		or type(markProcessed) ~= "function"
		or type(clearProcessed) ~= "function"
		or type(savePlayer) ~= "function"
	then
		return retryLater()
	end

	if hasProcessed(player, purchaseId) then
		if markReceiptGranted(receiptInfo) then
		if DataService and (targetUserId or player.UserId)~=player.UserId then
			local handle=DataService.GetHandle(player.UserId)
			if handle then
				DataService.Commit(handle,{operationId="gift-clear:"..purchaseId,fingerprint="gift-clear",commands={{kind="ClearGiftContext",productId=tostring(productId),targetUserId=targetUserId,contextId=giftContextId or ""}}})
			end
		end
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		return retryLater()
	end

	local commands=DataService and persistentReceiptCommands(productEntry)
	if commands then
		if not commitPersistentReceipt(player,grantPlayer,receiptInfo,productEntry,commands) then return retryLater() end
		if not markReceiptGranted(receiptInfo) then return retryLater() end
		if grantPlayer~=player then
			pendingGiftContexts[player]=nil
			local handle=DataService.GetHandle(player.UserId)
			if handle then DataService.Commit(handle,{operationId="gift-clear:"..purchaseId,fingerprint="gift-clear",commands={{kind="ClearGiftContext",productId=tostring(productId),targetUserId=targetUserId,contextId=giftContextId or ""}}}) end
		end
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local transaction = grantProductTransaction(grantPlayer, productEntry)
	if not transaction then
		return retryLater()
	end

	if DataService then
		if not commitPersistentReceipt(player,grantPlayer,receiptInfo,productEntry,{}) then return retryLater() end
		local ok,message=pcall(transaction.Commit)
		if not ok then warn("[Receipt] Feedback failed: "..tostring(message)) end
		if not markReceiptGranted(receiptInfo) then return retryLater() end
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local previousRobuxSpent = cleanRobuxSpent(player:GetAttribute("RobuxSpent"))
	local receiptRobux = getReceiptRobuxAmount(receiptInfo, productEntry)
	local rewardRollback = transaction.Rollback
	player:SetAttribute(
		"RobuxSpent",
		math.clamp(previousRobuxSpent + receiptRobux, 0, MAX_SAFE_INTEGER)
	)
	transaction.Rollback = function()
		player:SetAttribute("RobuxSpent", previousRobuxSpent)
		rewardRollback()
	end

	local markSuccess, markResult = pcall(markProcessed, player, purchaseId)
	if not markSuccess or markResult == false then
		warn("[SpeedProductPurchases] Failed to mark receipt as processed: " .. tostring(markResult))
		transaction.Rollback()
		return retryLater()
	end

	local savedGrant = savePlayer(grantPlayer, "developer_product_" .. productEntry.Kind, true) == true
	local savedBuyer = true
	if grantPlayer ~= player then
		savedBuyer = savePlayer(player, "developer_product_buyer_" .. productEntry.Kind, true) == true
	end

	if not RunService:IsStudio() and (not savedGrant or not savedBuyer) then
		clearProcessed(player, purchaseId)
		transaction.Rollback()
		return retryLater()
	end

	local committed, commitError = pcall(transaction.Commit)
	if not committed then
		warn("[SpeedProductPurchases] Post-save feedback failed: " .. tostring(commitError))
	end

	if not markReceiptGranted(receiptInfo) then


		return retryLater()
	end

	if grantPlayer ~= player then
		pendingGiftContexts[player] = nil
	end

	print(
		"[SpeedProductPurchases] Granted "
			.. productEntry.Kind
			.. " product "
			.. tostring(productId)
			.. " to "
			.. player.Name
			.. " | RobuxSpent+="
			.. tostring(receiptRobux)
	)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

MarketplaceService.ProcessReceipt = function(receiptInfo)
	local playerId = tonumber(receiptInfo.PlayerId)
	if not playerId then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if processingPlayerReceipts[playerId] then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	processingPlayerReceipts[playerId] = true
	local ok, decision = pcall(processReceipt, receiptInfo)
	processingPlayerReceipts[playerId] = nil

	if not ok then
		warn("[SpeedProductPurchases] Unexpected receipt error: " .. tostring(decision))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return decision
end

local function beginReviveOffer(player, character)
	if player.Character ~= character or not player.Parent then
		return
	end

	local root = character and character:FindFirstChild("HumanoidRootPart")
	local deathPosition = root and root:IsA("BasePart") and root.Position or nil
	local deathCFrame = root and root:IsA("BasePart") and root.CFrame or nil

	-- Si el personaje cayó al vacío, usar la última posición registrada en el suelo
	local grounded = playerLastGrounded[player]
	if (not deathPosition or deathPosition.Y <= -10) and grounded and grounded.Position.Y > -10 then
		deathPosition = grounded.Position
		deathCFrame = grounded.CFrame
		print(string.format("[ReviveCapture] Player fell in void, using last grounded track position for %s: (%.1f, %.1f, %.1f)",
			player.Name, deathPosition.X, deathPosition.Y, deathPosition.Z))
	end

	-- Resolución blindada del Stage más cercano (sin crash de nil)
	local nearestStage, nearestDistance = nil, nil
	if deathPosition then
		pcall(function()
			if StageTeleportService and type(StageTeleportService.GetNearestStage) == "function" then
				nearestStage, nearestDistance = StageTeleportService.GetNearestStage(deathPosition)
			end
		end)
		if not nearestStage then
			nearestStage = findSafeZoneStageAtPosition(deathPosition)
		end
		if not nearestStage then
			local bestDist = math.huge
			for stageNum = 1, STAGE_COUNT do
				local boundsCFrame = getCachedSafeZoneBounds(stageNum)
				if boundsCFrame then
					local dx = deathPosition.X - boundsCFrame.Position.X
					local dz = deathPosition.Z - boundsCFrame.Position.Z
					local dist = math.sqrt(dx * dx + dz * dz)
					if dist < bestDist then
						bestDist = dist
						nearestStage = stageNum
						nearestDistance = dist
					end
				end
			end
		end
	end

	local stage = cleanStage(nearestStage or (grounded and grounded.Stage) or player:GetAttribute("LastReachedStage") or 1)
	local duration = math.max(10, tonumber(Config.ReviveOfferSeconds) or 10)
	local token = HttpService:GenerateGUID(false)
	local isFree = player:GetAttribute("InfiniteRevivesOwned") == true
	local offer = {
		Token = token,
		Stage = stage,
		DeathCFrame = deathCFrame,
		DeathPosition = deathPosition,
		ExpiresAt = os.clock() + duration,
		Free = isFree,
	}
	activeReviveOffers[player] = offer
	player:SetAttribute("ReviveStageAtDeath", stage)
	player:SetAttribute("ReviveNearestStageDistance", nearestDistance)
	if deathPosition then
		player:SetAttribute("ReviveDeathPosition", deathPosition)
	end
	print(
		"[ReviveCapture] "
			.. player.Name
			.. " died nearest Stage "
			.. tostring(stage)
			.. " | distance="
			.. string.format("%.2f", tonumber(nearestDistance) or -1)
			.. " | Free="
			.. tostring(offer.Free)
			.. " | pos="
			.. (deathPosition and string.format("(%.1f, %.1f, %.1f)", deathPosition.X, deathPosition.Y, deathPosition.Z) or "nil")
	)

	ReviveCommerce:FireClient(player, {
		Type = "Offer",
		Token = token,
		Stage = stage,
		Duration = duration,
		ProductId = reviveProductId,
		PriceRobux = tonumber(Config.RevivePriceRobux) or 7,
		Free = offer.Free,
	})

	task.delay(duration, function()
		if activeReviveOffers[player] == offer then
			activeReviveOffers[player] = nil
		end
	end)
end

local function setupReviveCharacter(player, character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid or not humanoid:IsA("Humanoid") then
		return
	end
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if root and root:IsA("BasePart") then
		local stageAtSpawn = findSafeZoneStageAtPosition(root.Position)
		local arrivalGraceUntil = tonumber(player:GetAttribute("StageTeleportArrivalGraceUntil")) or 0
		if stageAtSpawn then
			player:SetAttribute("LastReachedStage", stageAtSpawn)
			player:SetAttribute("CurrentSafeZoneStage", stageAtSpawn)
		elseif os.clock() >= arrivalGraceUntil then


			player:SetAttribute("LastReachedStage", 1)
			player:SetAttribute("CurrentSafeZoneStage", 1)
		end
	end

	humanoid.Died:Connect(function()
		beginReviveOffer(player, character)
	end)
end

local function retryStarterPackGrant(player, reason)
	for attempt = 1, 6 do
		if not player.Parent then
			return
		end
		local version = math.max(0, math.floor(tonumber(player:GetAttribute("StarterPackRewardVersion")) or 0))
		if player:GetAttribute("StarterPackGranted") == true and version >= STARTER_PACK_REWARD_VERSION then
			return
		end
		if grantStarterPackOnce(player, reason) then
			return
		end
		if attempt < 6 then
			task.wait(math.min(5, attempt))
		end
	end
end

local function refreshStarterPackOwnership(player)
	local passId = tonumber(Config.StarterPackGamePassId)
	if not passId or passId <= 0 or not waitForPlayerData(player, 12) then
		return
	end

	local rewardVersion = math.max(0, math.floor(tonumber(player:GetAttribute("StarterPackRewardVersion")) or 0))
	if player:GetAttribute("StarterPackGranted") == true and rewardVersion >= STARTER_PACK_REWARD_VERSION then
		player:SetAttribute("StarterPackOwned", true)
		return
	end

	local ok, ownsPass = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
	end)
	if not ok then
		warn("[SpeedProductPurchases] Could not check Starter Pack ownership for " .. player.Name)
		return
	end

	player:SetAttribute("StarterPackOwned", ownsPass == true)
	if ownsPass then
		retryStarterPackGrant(player, "join_ownership")
	end
end

local function refreshInfiniteRevivesOwnership(player)
	local passId = tonumber(Config.InfiniteRevivesGamePassId)
	if not passId or passId <= 0 then
		player:SetAttribute("InfiniteRevivesOwnershipVerified", true)
		player:SetAttribute("InfiniteRevivesOwnershipChecked", true)
		return
	end

	if player:GetAttribute("InfiniteRevivesOwned") == true then
		player:SetAttribute("InfiniteRevivesOwnershipVerified", true)
		player:SetAttribute("InfiniteRevivesOwnershipChecked", true)
		return
	end

	local ok, ownsPass = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
	end)
	if not player.Parent then
		return
	end

	if ok then

		if player:GetAttribute("InfiniteRevivesOwned") ~= true then
			player:SetAttribute("InfiniteRevivesOwned", ownsPass == true)
		end
		player:SetAttribute("InfiniteRevivesOwnershipVerified", true)
	else
		player:SetAttribute("InfiniteRevivesOwnershipVerified", false)
		warn("[SpeedProductPurchases] Could not check Infinite Revives ownership for " .. player.Name)
	end
	player:SetAttribute("InfiniteRevivesOwnershipChecked", true)
end

local function refreshRebirthPassOwnership(player)
	local passId = tonumber(Config.RebirthGamePassId)
	if not passId or passId <= 0 or not waitForPlayerData(player, 12) then
		return
	end
	if player:GetAttribute("RebirthGamePassGranted") == true then
		return
	end
	local ok, ownsPass = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
	end)
	if ok and ownsPass then
		if player:GetAttribute("RebirthGamePassGranted") ~= true then
			player:SetAttribute("RebirthGamePassGranted", true)
			if type(_G.SpeedsterAddRebirths) == "function" then
				_G.SpeedsterAddRebirths(player, 1)
			end
			print("[SpeedProductPurchases] Rebirth GamePass granted on join for " .. player.Name)
		end
	end
end

local function refreshTwoXSpeedPassOwnership(player)
	if not waitForPlayerData(player, 12) then
		return
	end
	local passId = tonumber(Config.TwoXSpeedGamePassId)
	if passId and passId > 0 then
		local ok, ownsPass = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
		end)
		if ok and ownsPass then
			player:SetAttribute("TwoXSpeedOwned", true)
			local current = tonumber(player:GetAttribute("PermanentBaseSpeedMultiplier")) or 1
			local newMult = math.max(2, current)
			player:SetAttribute("PermanentBaseSpeedMultiplier", newMult)
			if type(_G.SpeedsterSetPermanentBaseSpeedMultiplier) == "function" then
				_G.SpeedsterSetPermanentBaseSpeedMultiplier(player, newMult)
			end
			print("[SpeedProductPurchases] 2x Speed GamePass verified on join for " .. player.Name)
		end
	end

	local tenXPassId = tonumber(Config.TenXSpeedGamePassId)
	if tenXPassId and tenXPassId > 0 then
		local ok10, owns10 = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, tenXPassId)
		end)
		if ok10 and owns10 then
			player:SetAttribute("TenXSpeedOwned", true)
			local current = tonumber(player:GetAttribute("PermanentBaseSpeedMultiplier")) or 1
			local newMult = math.max(10, current)
			player:SetAttribute("PermanentBaseSpeedMultiplier", newMult)
			if type(_G.SpeedsterSetPermanentBaseSpeedMultiplier) == "function" then
				_G.SpeedsterSetPermanentBaseSpeedMultiplier(player, newMult)
			end
			print("[SpeedProductPurchases] 10x Speed GamePass verified on join for " .. player.Name)
		end
	end

	-- Check any PermanentSpeedMultiplierProducts that are GamePasses
	for _, product in ipairs(Config.PermanentSpeedMultiplierProducts or {}) do
		local pid = tonumber(product.ProductId)
		if pid and pid > 0 and (product.IsGamePass == true or pid < 3000000000) then
			local okP, ownsP = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pid)
			end)
			if okP and ownsP then
				local target = tonumber(product.TargetMultiplier) or 1
				local current = tonumber(player:GetAttribute("PermanentBaseSpeedMultiplier")) or 1
				local newMult = math.max(target, current)
				player:SetAttribute("PermanentBaseSpeedMultiplier", newMult)
				if type(_G.SpeedsterSetPermanentBaseSpeedMultiplier) == "function" then
					_G.SpeedsterSetPermanentBaseSpeedMultiplier(player, newMult)
				end
				print(string.format("[SpeedProductPurchases] Permanent speed multiplier GamePass %d (x%d) verified on join for %s", pid, target, player.Name))
			end
		end
	end
end

local function refreshDoubleWinsPassOwnership(player)
	local passId = tonumber(Config.TwoXVictoryGamePassId) or tonumber(Config.DoubleWinsPadGamePassId) or 1941409601
	if not passId or passId <= 0 or not waitForPlayerData(player, 12) then
		return
	end
	local ok, ownsPass = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
	end)
	if ok and ownsPass then
		player:SetAttribute("DoubleWinsPadUnlocked", true)
		player:SetAttribute("TwoXVictoryOwned", true)
		local current = tonumber(player:GetAttribute("PermanentWinsMultiplier")) or 1
		local newMult = math.max(2, current)
		player:SetAttribute("PermanentWinsMultiplier", newMult)
		if type(_G.SpeedsterSetPermanentWinsMultiplier) == "function" then
			_G.SpeedsterSetPermanentWinsMultiplier(player, newMult)
		end
		print("[SpeedProductPurchases] Double Wins / 2x Victory GamePass verified on join for " .. player.Name)
	end
end

local function refreshFlightPassOwnership(player)
	local passId = tonumber(Config.AbilityFlightGamePassId or Config.AbilityFlightProductId) or 1978623069
	if not passId or passId <= 0 or not waitForPlayerData(player, 12) then
		return
	end
	local ok, ownsPass = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
	end)
	if ok and ownsPass then
		player:SetAttribute("FlightAbilityOwned", true)
		player:SetAttribute("FlightAbilityEquipped", true)
		if type(_G.SpeedsterGrantFlight) == "function" then
			pcall(_G.SpeedsterGrantFlight, player, "flight_gamepass_on_join")
		else
			if type(_G.SpeedsterUnlockUpgrade) == "function" then
				pcall(_G.SpeedsterUnlockUpgrade, player, "Flight")
			end
			local dataFolder = player:FindFirstChild("SpeedsterData")
			local ownedFolder = dataFolder and dataFolder:FindFirstChild("OwnedUpgrades")
			if ownedFolder then
				local flag = ownedFolder:FindFirstChild("Flight")
				if not flag then
					flag = Instance.new("BoolValue")
					flag.Name = "Flight"
					flag.Parent = ownedFolder
				end
				flag.Value = true
			end
		end
		print("[SpeedProductPurchases] Flight GamePass verified on join for " .. player.Name)
	end
end

local function refreshCosmeticPassOwnership(player)
	if not waitForPlayerData(player, 12) then return end
	local unlockedAny = false
	for _, cosmeticType in ipairs({"Trail", "Aura"}) do
		for _, entry in ipairs(CosmeticCatalog.GetList(cosmeticType) or {}) do
			local passId = tonumber(entry.RobuxPurchaseId)
			if passId and passId > 0 and (passId < 3000000000 or entry.RobuxPurchaseType == "GamePass" or entry.RobuxPurchaseType == "Auto") then
				local ok, owns = pcall(function()
					return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
				end)
				if ok and owns == true then
					local folderName = cosmeticType == "Trail" and "OwnedTrails" or "OwnedAuras"
					local dataFolder = player:FindFirstChild("SpeedsterData")
					if dataFolder then
						local ownedFolder = dataFolder:FindFirstChild(folderName)
						if not ownedFolder then
							ownedFolder = Instance.new("Folder")
							ownedFolder.Name = folderName
							ownedFolder.Parent = dataFolder
						end
						local flag = ownedFolder:FindFirstChild(entry.Id)
						if not flag then
							flag = Instance.new("BoolValue")
							flag.Name = entry.Id
							flag.Parent = ownedFolder
						end
						flag.Value = true
					end
					if cosmeticType == "Aura" and type(_G.SpeedsterUnlockAura) == "function" then
						_G.SpeedsterUnlockAura(player, entry.Id)
					elseif cosmeticType == "Trail" and type(_G.SpeedsterUnlockTrail) == "function" then
						_G.SpeedsterUnlockTrail(player, entry.Id)
					end
					unlockedAny = true
					print(string.format("[SpeedProductPurchases] Cosmetic pass ownership verified on join: %s (%s) for %s", entry.DisplayName, entry.Id, player.Name))
				end
			end
		end
	end
	if unlockedAny then
		if type(_G.SpeedsterRefreshTrailShop) == "function" then
			_G.SpeedsterRefreshTrailShop(player)
		end
		if type(_G.SpeedsterRefreshAuraShop) == "function" then
			_G.SpeedsterRefreshAuraShop(player)
		end
	end
end

local function setupMonetizationPlayer(player)
	if monetizationPlayerSetup[player] then
		return
	end
	monetizationPlayerSetup[player] = true

	if player:GetAttribute("LastReachedStage") == nil then
		player:SetAttribute("LastReachedStage", 1)
	end
	if player:GetAttribute("CurrentSafeZoneStage") == nil then
		player:SetAttribute("CurrentSafeZoneStage", 1)
	end
	if player:GetAttribute("InfiniteRevivesOwned") == nil then
		player:SetAttribute("InfiniteRevivesOwned", false)
	end
	player:SetAttribute("InfiniteRevivesOwnershipVerified", false)
	player:SetAttribute("InfiniteRevivesOwnershipChecked", false)

	if player.Character then
		task.spawn(setupReviveCharacter, player, player.Character)
	end
	player.CharacterAdded:Connect(function(character)
		task.spawn(setupReviveCharacter, player, character)
	end)
	task.spawn(refreshStarterPackOwnership, player)
	task.spawn(refreshInfiniteRevivesOwnership, player)
	task.spawn(refreshRebirthPassOwnership, player)
	task.spawn(refreshTwoXSpeedPassOwnership, player)
	task.spawn(refreshDoubleWinsPassOwnership, player)
	task.spawn(refreshFlightPassOwnership, player)
	task.spawn(refreshCosmeticPassOwnership, player)
end

ReviveCommerce.OnServerEvent:Connect(function(player, action, token)
	print(string.format("[ReviveCommerce] OnServerEvent from %s | action=%s | token=%s",
		player.Name, tostring(action), tostring(token)))
	if action ~= "RequestPrompt" then
		return
	end

	local offer = activeReviveOffers[player]
	if not offer
		or tostring(token or "") ~= tostring(offer.Token)
		or os.clock() > ((tonumber(offer.ExpiresAt) or 0) + 1.5)
	then
		print("[ReviveCommerce] Offer expired or invalid for " .. player.Name)
		ReviveCommerce:FireClient(player, {
			Type = "Expired",
			Token = token,
		})
		return
	end
	if offer.Claiming or offer.OwnershipChecking then
		print("[ReviveCommerce] Offer already busy claiming/checking for " .. player.Name)
		return
	end
	if player:GetAttribute("InfiniteRevivesOwned") ~= true
		and player:GetAttribute("InfiniteRevivesOwnershipVerified") ~= true
	then
		offer.OwnershipChecking = true
		refreshInfiniteRevivesOwnership(player)
		offer.OwnershipChecking = false
	end

	if player:GetAttribute("InfiniteRevivesOwned") == true then
		print("[ReviveCommerce] Player " .. player.Name .. " owns Infinite Revives -> Granting free revive!")
		offer.Claiming = true
		grantFreeInfiniteRevive(player, offer)
		return
	end

	print(string.format("[ReviveCommerce] Player %s does not own Infinite Revives -> Prompting product %s",
		player.Name, tostring(reviveProductId)))
	pendingRevivePurchases[player] = {
		Stage = cleanStage(offer.Stage),
		Token = offer.Token,
		DeathCFrame = offer.DeathCFrame,
		DeathPosition = offer.DeathPosition,
		ExpiresAt = os.clock() + 10 * 60,
	}
	ReviveCommerce:FireClient(player, {
		Type = "Prompt",
		Token = offer.Token,
		ProductId = reviveProductId,
	})
end)

StarterPackClaim.OnServerEvent:Connect(function(player)
	local passId = tonumber(Config.StarterPackGamePassId)
	if not passId or passId <= 0 or not player.Parent or starterPackClaimCheckBusy[player] then
		return
	end
	starterPackClaimCheckBusy[player] = true




	task.spawn(function()
		for attempt = 1, 6 do
			if not player.Parent then
				starterPackClaimCheckBusy[player] = nil
				return
			end
			local okOwns, ownsPass = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
			end)
			if okOwns and ownsPass == true then
				player:SetAttribute("StarterPackOwned", true)
				retryStarterPackGrant(player, "client_verified_claim")
				starterPackClaimCheckBusy[player] = nil
				return
			end
			if attempt < 6 then
				task.wait(attempt)
			end
		end
		starterPackClaimCheckBusy[player] = nil
		warn("[SpeedProductPurchases] Starter Pack client claim could not verify ownership for " .. player.Name)
	end)
end)

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, purchasedPassId, purchaseSuccess)
	if purchaseSuccess ~= true then
		return
	end
	local numericPassId = tonumber(purchasedPassId)

	local giftContext = pendingGiftContexts[player]
	if giftContext
		and giftContext.ExpiresAt > os.clock()
		and tonumber(giftContext.ProductId) == numericPassId
	then
		local target = Players:GetPlayerByUserId(giftContext.TargetUserId)
		pendingGiftContexts[player] = nil
		if target and target ~= player then
			grantPassPerkToTarget(target, numericPassId)
			print("[SpeedProductPurchases] Gifted gamepass " .. tostring(numericPassId) .. " to " .. target.Name)
			return
		end
	end

	local starterPackPassId = tonumber(Config.StarterPackGamePassId)
	local infiniteRevivesPassId = tonumber(Config.InfiniteRevivesGamePassId)
	local twoXSpeedPassId = tonumber(Config.TwoXSpeedGamePassId)
	local doubleWinsPassId = tonumber(Config.TwoXVictoryGamePassId) or tonumber(Config.DoubleWinsPadGamePassId) or 1941409601
	local rebirthPassId = tonumber(Config.RebirthGamePassId)

	if starterPackPassId and numericPassId == starterPackPassId then
		player:SetAttribute("StarterPackOwned", true)
		task.spawn(retryStarterPackGrant, player, "purchase_finished")
	elseif infiniteRevivesPassId and numericPassId == infiniteRevivesPassId then
		player:SetAttribute("InfiniteRevivesOwned", true)
		player:SetAttribute("InfiniteRevivesOwnershipVerified", true)
		player:SetAttribute("InfiniteRevivesOwnershipChecked", true)
	elseif twoXSpeedPassId and numericPassId == twoXSpeedPassId then
		player:SetAttribute("TwoXSpeedOwned", true)
		local current = tonumber(player:GetAttribute("PermanentBaseSpeedMultiplier")) or 1
		local newMult = math.max(2, current)
		player:SetAttribute("PermanentBaseSpeedMultiplier", newMult)
		if type(_G.SpeedsterSetPermanentBaseSpeedMultiplier) == "function" then
			_G.SpeedsterSetPermanentBaseSpeedMultiplier(player, newMult)
		end
		if type(_G.SpeedsterSavePlayer) == "function" then
			_G.SpeedsterSavePlayer(player, "two_x_speed_pass", true)
		end
		print("[SpeedProductPurchases] 2x Speed GamePass granted to " .. player.Name)
	elseif Config.TenXSpeedGamePassId and numericPassId == tonumber(Config.TenXSpeedGamePassId) then
		player:SetAttribute("TenXSpeedOwned", true)
		local current = tonumber(player:GetAttribute("PermanentBaseSpeedMultiplier")) or 1
		local newMult = math.max(10, current)
		player:SetAttribute("PermanentBaseSpeedMultiplier", newMult)
		if type(_G.SpeedsterSetPermanentBaseSpeedMultiplier) == "function" then
			_G.SpeedsterSetPermanentBaseSpeedMultiplier(player, newMult)
		end
		if type(_G.SpeedsterSavePlayer) == "function" then
			_G.SpeedsterSavePlayer(player, "ten_x_speed_pass", true)
		end
		print("[SpeedProductPurchases] 10x Speed GamePass granted to " .. player.Name)
	elseif doubleWinsPassId and numericPassId == doubleWinsPassId then
		player:SetAttribute("DoubleWinsPadUnlocked", true)
		player:SetAttribute("TwoXVictoryOwned", true)
		local current = tonumber(player:GetAttribute("PermanentWinsMultiplier")) or 1
		local newMult = math.max(2, current)
		player:SetAttribute("PermanentWinsMultiplier", newMult)
		if type(_G.SpeedsterSetPermanentWinsMultiplier) == "function" then
			_G.SpeedsterSetPermanentWinsMultiplier(player, newMult)
		end
		if type(_G.SpeedsterSavePlayer) == "function" then
			_G.SpeedsterSavePlayer(player, "double_wins_pass", true)
		end
		print("[SpeedProductPurchases] Double Wins / 2x Victory GamePass granted to " .. player.Name)
	elseif rebirthPassId and rebirthPassId > 0 and numericPassId == rebirthPassId then
		player:SetAttribute("RebirthGamePassGranted", true)
		if type(_G.SpeedsterAddRebirths) == "function" then
			_G.SpeedsterAddRebirths(player, 1)
		end
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		local rebirthUpdate = remotes and remotes:FindFirstChild("RebirthUpdate")
		if rebirthUpdate and rebirthUpdate:IsA("RemoteEvent") and player.Parent then
			rebirthUpdate:FireClient(player, {
				Message = "Rebirth purchased!",
				Success = true,
				Rebirths = tonumber(player:GetAttribute("Rebirths")) or 0,
			})
		end
		print("[SpeedProductPurchases] Rebirth GamePass granted to " .. player.Name)
	elseif numericPassId == (tonumber(Config.AbilityFlightGamePassId or Config.AbilityFlightProductId) or 1978623069) then
		player:SetAttribute("FlightAbilityOwned", true)
		player:SetAttribute("FlightAbilityEquipped", true)
		if type(_G.SpeedsterGrantFlight) == "function" then
			pcall(_G.SpeedsterGrantFlight, player, "flight_gamepass_purchase")
		else
			if type(_G.SpeedsterUnlockUpgrade) == "function" then
				pcall(_G.SpeedsterUnlockUpgrade, player, "Flight")
			end
			local dataFolder = player:FindFirstChild("SpeedsterData")
			local ownedFolder = dataFolder and dataFolder:FindFirstChild("OwnedUpgrades")
			if ownedFolder then
				local flag = ownedFolder:FindFirstChild("Flight")
				if not flag then
					flag = Instance.new("BoolValue")
					flag.Name = "Flight"
					flag.Parent = ownedFolder
				end
				flag.Value = true
			end
			if type(_G.SpeedsterSavePlayer) == "function" then
				pcall(_G.SpeedsterSavePlayer, player, "flight_gamepass_purchase", true)
			end
		end
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		local abilityShopUpdate = remotes and remotes:FindFirstChild("AbilityShopUpdate")
		if abilityShopUpdate and abilityShopUpdate:IsA("RemoteEvent") and player.Parent then
			abilityShopUpdate:FireClient(player, {
				Flight = {
					Id = "Flight",
					DisplayName = "Flight",
					Owned = true,
					Equipped = true,
					WinsCost = tonumber(Config.AbilityFlightWinsCost) or 25000000,
					ProductId = numericPassId,
					RobuxPrice = tonumber(Config.AbilityFlightPriceRobux) or 799,
				},
				Message = "Flight Purchased & Equipped!",
			})
		end
		print("[SpeedProductPurchases] Flight GamePass granted to " .. player.Name)
	end

	-- Support for SpeedProductTiers as GamePasses
	for _, tier in ipairs(Config.SpeedProductTiers or {}) do
		if tonumber(tier.ProductId) == numericPassId then
			local tx = grantSpeedTransaction(player, tier)
			if tx and tx.Commit then
				tx.Commit()
			end
			print(string.format("[SpeedProductPurchases] Speed tier %d granted via GamePass %d to %s", tier.Tier or 0, numericPassId, player.Name))
			return
		end
	end

	-- Support for PermanentMultiplierProducts as GamePasses
	for _, product in ipairs(Config.PermanentSpeedMultiplierProducts or {}) do
		if tonumber(product.ProductId) == numericPassId then
			local tx = grantPermanentMultiplierTransaction(player, product)
			if tx and tx.Commit then
				tx.Commit()
			end
			print(string.format("[SpeedProductPurchases] Permanent speed multiplier stage %d granted via GamePass %d to %s", product.Stage or 0, numericPassId, player.Name))
			return
		end
	end

	-- Support for PermanentWinsMultiplierProducts as GamePasses
	for _, product in ipairs(Config.PermanentWinsMultiplierProducts or {}) do
		if tonumber(product.ProductId) == numericPassId then
			local tx = grantPermanentWinsMultiplierTransaction(player, product)
			if tx and tx.Commit then
				tx.Commit()
			end
			print(string.format("[SpeedProductPurchases] Permanent wins multiplier stage %d granted via GamePass %d to %s", product.Stage or 0, numericPassId, player.Name))
			return
		end
	end

	-- Support for Cosmetic unlocks as GamePasses (Trails and Auras)
	for _, cosmeticType in ipairs({"Trail", "Aura"}) do
		for _, entry in ipairs(CosmeticCatalog.GetList(cosmeticType) or {}) do
			local passId = tonumber(entry.RobuxPurchaseId)
			if passId and passId == numericPassId then
				local tx = grantCosmeticUnlockTransaction(player, {
					CosmeticType = cosmeticType,
					CosmeticId = entry.Id,
					DisplayName = entry.DisplayName,
					PriceRobux = tonumber(entry.RobuxPrice),
					ProductId = passId,
				})
				if tx and tx.Commit then
					tx.Commit()
				end
				print(string.format("[SpeedProductPurchases] %s %s granted via GamePass %d to %s", cosmeticType, entry.Id, numericPassId, player.Name))
				return
			end
		end
	end
end)

local giftRequestBusy={}
GiftContextRequest.OnServerEvent:Connect(function(player,targetUserId,productId,requestId)
	if giftRequestBusy[player] or pendingGiftContexts[player] or type(requestId)~="string" or #requestId<1 or #requestId>128 or type(productId)~="number" or productId~=productId or productId%1~=0 or type(targetUserId)~="number" or targetUserId~=targetUserId or targetUserId%1~=0 then return end
	local target=Players:GetPlayerByUserId(tonumber(targetUserId) or 0)
	local entry=productsById[tonumber(productId)]
	local handle=DataService and DataService.GetHandle(player.UserId)
	if not target or target==player or target:GetAttribute("AcceptGifts")==false or not entry or not persistentReceiptCommands(entry) or not handle then
		GiftContextRequest:FireClient(player,requestId,false);return
	end
	giftRequestBusy[player]=true
	local ok,result=pcall(function()
		local view=DataService.Inspect(handle)
		local old=view.ok and (view.value.profile.Update2GiftContexts or {})[tostring(productId)]
		local oldId=view.ok and (view.value.profile.Update2GiftContextIds or {})[tostring(productId)]
		if old and (old~=target.UserId or oldId~=requestId) then return false end
		local committed=DataService.Commit(handle,{operationId="gift-context:"..requestId,fingerprint=tostring(productId)..":"..target.UserId,commands={{kind="SetGiftContext",productId=tostring(productId),targetUserId=target.UserId,contextId=requestId}}})
		return committed.kind=="Committed" or committed.kind=="AlreadyCommitted"
	end)
	giftRequestBusy[player]=nil
	if ok and result then
		-- The server owns this prompt and can associate its cancellation with this attempt.
		local context={ProductId=productId,TargetUserId=target.UserId,ContextId=requestId,Handle=handle,ExpiresAt=math.huge}
		pendingGiftContexts[player]=context
		local prompted,promptError=pcall(function() MarketplaceService:PromptProductPurchase(player,productId) end)
		if not prompted then
			-- An exception is not evidence of cancellation; retain the durable route.
			warn("[Gifts] Could not open gift prompt: "..tostring(promptError))
			result=false
		end
	end
	if player.Parent then GiftContextRequest:FireClient(player,requestId,ok and result==true) end
end)
-- Only cancellation is handled here. Successful purchases still use ProcessReceipt.
MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId,productId,isPurchased)
	if isPurchased~=false then return end
	local player=Players:GetPlayerByUserId(userId)
	local context=player and pendingGiftContexts[player]
	if not context or context.ProductId~=productId or not context.ContextId then return end
	if context.Canceling then return end
	context.Canceling=true
	local transaction={operationId="gift-cancel:"..context.ContextId,fingerprint="gift-cancel:"..context.ProductId,
		commands={{kind="ClearGiftContext",productId=tostring(context.ProductId),targetUserId=context.TargetUserId,contextId=context.ContextId}}}
	local function settle()
		local handle=DataService.GetHandle(player.UserId)
		if not handle or handle.sessionId~=context.Handle.sessionId or handle.generation~=context.Handle.generation then return end
		local ok,result=pcall(DataService.Commit,handle,transaction)
		if ok and result and (result.kind=="Committed" or result.kind=="AlreadyCommitted") then
			if pendingGiftContexts[player]==context then pendingGiftContexts[player]=nil end
		elseif not ok or (result and result.kind=="Pending") then task.delay(2,settle)
		else warn("[Gifts] Gift cancellation could not be saved") end
	end
	settle()
end)

grantPassPerkToTarget = function(target, passId)
	local infiniteId = tonumber(Config.InfiniteRevivesGamePassId)
	local starterId = tonumber(Config.StarterPackGamePassId)
	local doubleWinsId = tonumber(Config.DoubleWinsPadGamePassId)
	local twoXSpeedId = tonumber(Config.TwoXSpeedGamePassId)
	local vipId = tonumber(Config.VipGamePassId)
	local rebirthId = tonumber(Config.RebirthGamePassId)
	if passId == infiniteId then
		target:SetAttribute("InfiniteRevivesOwned", true)
		target:SetAttribute("InfiniteRevivesOwnershipVerified", true)
		target:SetAttribute("InfiniteRevivesOwnershipChecked", true)
	elseif passId == starterId then
		target:SetAttribute("StarterPackOwned", true)
		retryStarterPackGrant(target, "gift")
	elseif passId == doubleWinsId then
		target:SetAttribute("DoubleWinsPadUnlocked", true)
		target:SetAttribute("TwoXVictoryOwned", true)
		local current = tonumber(target:GetAttribute("PermanentWinsMultiplier")) or 1
		local newMult = math.max(2, current)
		target:SetAttribute("PermanentWinsMultiplier", newMult)
		if type(_G.SpeedsterSetPermanentWinsMultiplier) == "function" then
			_G.SpeedsterSetPermanentWinsMultiplier(target, newMult)
		end
	elseif passId == twoXSpeedId then
		local current = tonumber(target:GetAttribute("PermanentBaseSpeedMultiplier")) or 1
		target:SetAttribute("PermanentBaseSpeedMultiplier", math.max(2, current))
	elseif passId == vipId then
		target:SetAttribute("VIPGamepassOwned", true)
		target:SetAttribute("VIPSpeedGainMultiplier", tonumber(Config.VipSpeedGainMultiplier) or 2)
		target:SetAttribute("VIPWinsMultiplier", tonumber(Config.VipWinsMultiplier) or 2)
	elseif rebirthId and passId == rebirthId and rebirthId > 0 then
		if type(_G.SpeedsterAddRebirths) == "function" then
			_G.SpeedsterAddRebirths(target, 1)
		end
	end

	for _, cosmeticType in ipairs({"Trail", "Aura"}) do
		for _, entry in ipairs(CosmeticCatalog.GetList(cosmeticType) or {}) do
			if tonumber(entry.RobuxPurchaseId) == passId then
				local tx = grantCosmeticUnlockTransaction(target, {
					CosmeticType = cosmeticType,
					CosmeticId = entry.Id,
					DisplayName = entry.DisplayName,
					PriceRobux = tonumber(entry.RobuxPrice),
					ProductId = passId,
				})
				if tx and tx.Commit then
					tx.Commit()
				end
			end
		end
	end
	print("[SpeedProductPurchases] Pass perk applied to " .. target.Name .. " for pass " .. tostring(passId))
end

Players.PlayerAdded:Connect(setupMonetizationPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	task.defer(setupMonetizationPlayer, player)
end

Players.PlayerRemoving:Connect(function(player)
	activeReviveOffers[player] = nil
	pendingRevivePurchases[player] = nil
	playerLastGrounded[player] = nil
	starterPackGrantBusy[player] = nil
	starterPackClaimCheckBusy[player] = nil
	monetizationPlayerSetup[player] = nil
	pendingGiftContexts[player] = nil
end)

task.spawn(function()
	while true do
		for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
				local stage = findSafeZoneStageAtPosition(root.Position)
				local currentStage = stage or 0
				if player:GetAttribute("CurrentSafeZoneStage") ~= currentStage then
					player:SetAttribute("CurrentSafeZoneStage", currentStage)
				end
				if stage and player:GetAttribute("LastReachedStage") ~= stage then
					player:SetAttribute("LastReachedStage", stage)
				end
			end
		end


		task.wait(0.08)
	end
end)

print("[SpeedProductPurchases] V306EN loaded | secure receipts + Stage 1-10 Skip Stage product.")
