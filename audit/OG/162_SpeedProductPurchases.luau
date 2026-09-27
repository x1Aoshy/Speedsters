         
                                                                             
                                                                             
                                                                              

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local CosmeticCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CosmeticCatalog"))
local STAGE_COUNT = math.max(1, math.floor(tonumber(Config.StageCount) or 10))
local IS_WORLD2 = Config.IsWorld2Place == true
local IS_NEW_WORLD1 = Config.IsNewWorld1Map == true
local WORLD2_SAFE_ZONE_SUFFIX = tostring(Config.World2SafeZoneSuffix or ".2")
local NEW_WORLD1_MAP_ROOT = IS_NEW_WORLD1
	and (Workspace:FindFirstChild(tostring(Config.NewWorld1MapMarkerName or "neworld1"))
		or Workspace:WaitForChild(tostring(Config.NewWorld1MapMarkerName or "neworld1"), 20))
	or nil
local StageTeleportService = require(script.Parent:WaitForChild("StageTeleportService"))
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

local STARTER_PACK_REWARD_VERSION = 2
local LEGACY_STARTER_PACK_SPEED_REWARD = 50000
local LEGACY_STARTER_PACK_WINS_REWARD = 30

local ReceiptStore = DataStoreService:GetDataStore("SpeedsterEscape_ProductReceipts_v1")
local RECEIPT_LEASE_SECONDS = 120
local processingPlayerReceipts = {}
local activeReviveOffers = {}
local pendingRevivePurchases = {}
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
			PriceRobux = tonumber(Config.AbilityFlightPriceRobux) or 79,
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
	local ok, err = pcall(function()
		ReceiptStore:UpdateAsync(receiptKey(purchaseId), function(current)
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
				Owner = claimOwnerId,
				LeaseExpiresUnix = now + RECEIPT_LEASE_SECONDS,
				PlayerId = receiptInfo.PlayerId,
				ProductId = receiptInfo.ProductId,
				UpdatedUnix = now,
			}
		end)
	end)

	if not ok then
		warn("[SpeedProductPurchases] Receipt claim failed: " .. tostring(err))
		return false, "error"
	end

	return decision == "acquired" or decision == "granted", decision, claimOwnerId
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
				PlayerId = receiptInfo.PlayerId,
				ProductId = receiptInfo.ProductId,
				GrantedUnix = os.time(),
			}
		end)
	end)

	if not ok then
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
			return math.max(DISPLAY_ROUND_DOWN_STEP, math.floor(value / DISPLAY_ROUND_DOWN_STEP) * DISPLAY_ROUND_DOWN_STEP)
		end
		return math.max(1, math.floor(value + 0.5))
	end

	local tier = math.floor(math.log10(value) / 3) + 1
	local base = 1000 ^ math.max(0, tier - 1)
	local scaled = value / base
	local cleanedScaled

	if scaled >= 10 then
		cleanedScaled = math.max(10, math.floor(scaled / 10) * 10)
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
	local speed, rawSpeed = getSpeedObjects(player)
	if not speed or not rawSpeed then
		return nil
	end

	local currentSpeed = cleanCurrentSpeed(rawSpeed.Value)
	local gainMultiplier = tonumber(tier.GainMultiplier) or 0
	if gainMultiplier <= 0 then
		return nil
	end

	local requestedGain = roundProductGain(currentSpeed * gainMultiplier)
	local newSpeed = math.min(tonumber(Config.MaxStoredSpeed) or 1e50, currentSpeed + requestedGain)
	local actualGain = math.max(0, newSpeed - currentSpeed)
	local oldSpeed = speed.Value
	local oldRawSpeed = rawSpeed.Value
	local oldTier = player:GetAttribute("LastSpeedProductTier")
	local oldGain = player:GetAttribute("LastSpeedProductGain")

	rawSpeed.Value = newSpeed
	player:SetAttribute("LastSpeedProductTier", tonumber(tier.Tier) or 0)
	player:SetAttribute("LastSpeedProductGain", actualGain)
	if _G.SpeedsterApplyWalkSpeed then
		_G.SpeedsterApplyWalkSpeed(player)
	end

	return {
		Rollback = function()
			if rawSpeed.Parent then
				rawSpeed.Value = oldRawSpeed
			end
			if speed.Parent then
				speed.Value = oldSpeed
			end
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

	local stage = tonumber(product.Stage) or 0
	local target = math.max(1, tonumber(product.TargetMultiplier) or 1)
	local newMultiplier = current

	if stage == 1 then
		newMultiplier = math.max(current, target)
	elseif stage == 2 then
		                                                                      
		                                                     
		newMultiplier = math.max(current, target)
	elseif stage == 3 then
		if current < target then
			newMultiplier = target
		else
			newMultiplier = current + math.max(1, tonumber(product.RepeatAddMultiplier) or 10)
		end
	else
		return nil
	end

	local oldLastPurchase = player:GetAttribute("LastPermanentSpeedMultiplierPurchase")
	player:SetAttribute("PermanentBaseSpeedMultiplier", newMultiplier)
	player:SetAttribute("LastPermanentSpeedMultiplierPurchase", newMultiplier)

	return {
		Rollback = function()
			player:SetAttribute("PermanentBaseSpeedMultiplier", current)
			player:SetAttribute("LastPermanentSpeedMultiplierPurchase", oldLastPurchase)
		end,
		Commit = function() end,
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

	if stage == 1 or stage == 2 then
		newMultiplier = math.max(current, target)
	elseif stage == 3 then
		if current < target then
			newMultiplier = target
		else
			newMultiplier = current + math.max(1, tonumber(product.RepeatAddMultiplier) or 10)
		end
	else
		return nil
	end

	local oldLastPurchase = player:GetAttribute("LastPermanentWinsMultiplierPurchase")
	player:SetAttribute("PermanentWinsMultiplier", newMultiplier)
	player:SetAttribute("LastPermanentWinsMultiplierPurchase", newMultiplier)

	return {
		Rollback = function()
			player:SetAttribute("PermanentWinsMultiplier", current)
			player:SetAttribute("LastPermanentWinsMultiplierPurchase", oldLastPurchase)
		end,
		Commit = function() end,
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
			if player.Character == character and character.Parent and root.Parent then
				character:PivotTo(oldPivot)
				root.AssemblyLinearVelocity = oldLinearVelocity
				root.AssemblyAngularVelocity = oldAngularVelocity
			end
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
	local character, _, root = waitForLivingCharacter(player, 12)
	if not character or not root then
		return nil
	end

	local oldPivot = character:GetPivot()
	local oldLinearVelocity = root.AssemblyLinearVelocity
	local oldAngularVelocity = root.AssemblyAngularVelocity
	local oldLastReachedStage = player:GetAttribute("LastReachedStage")
	local oldCurrentSafeZoneStage = player:GetAttribute("CurrentSafeZoneStage")
	local teleported, reason = StageTeleportService.TeleportPlayer(player, stage)
	if not teleported then
		warn("[SpeedProductPurchases] Revive could not be granted: " .. tostring(reason))
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
		end,
	}
end

local function grantFreeInfiniteRevive(player, offer)
	local context = {
		Stage = cleanStage(offer.Stage),
		Token = offer.Token,
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
			warn("[SpeedProductPurchases] Free Infinite Revive failed: " .. tostring(commitError))
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
	end)
end

local function grantFlightAbilityTransaction(player)
	if IS_WORLD2 or Config.AbilityFlightEnabled ~= true then
		return nil
	end

	local dataFolder = player:FindFirstChild("SpeedsterData")
	local ownedFolder = dataFolder and dataFolder:FindFirstChild("OwnedUpgrades")
	if not ownedFolder or not ownedFolder:IsA("Folder") then
		return nil
	end

	local upgradeName = tostring(Config.AbilityFlightUpgradeName or "Flight")
	local equipMarkerName = "__AbilityEquipped_Flight"
	local equipInitName = "__AbilityEquipStateInitialized"
	local existing = ownedFolder:FindFirstChild(upgradeName)
	if existing and not existing:IsA("BoolValue") then
		return nil
	end

	local created = false
	local oldValue = existing and existing.Value or false
	local oldEquipInit = ownedFolder:FindFirstChild(equipInitName)
	local oldEquipMarker = ownedFolder:FindFirstChild(equipMarkerName)
	if (oldEquipInit and not oldEquipInit:IsA("BoolValue"))
		or (oldEquipMarker and not oldEquipMarker:IsA("BoolValue")) then
		return nil
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
		if oldEquipMarker and oldEquipMarker:IsA("BoolValue") then
			oldEquipMarker.Value = false
		end
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
			player:SetAttribute("FlightAbilityGrantPending", nil)
			local refresh = _G.SpeedsterRefreshAbilityShop
			if type(refresh) == "function" and player.Parent then
				refresh(player, "Flight Owned - press Equip")
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
			refreshShop("Bought " .. displayName .. " with Robux")
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
	end
	return nil
end

local function processReceipt(receiptInfo)
	local productId = tonumber(receiptInfo.ProductId)
	local productEntry = productsById[productId]
	if not productEntry then
		warn("[SpeedProductPurchases] Unknown Developer Product ID: " .. tostring(productId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local purchaseId = tostring(receiptInfo.PurchaseId or "")
	if purchaseId == "" then
		warn("[SpeedProductPurchases] Roblox supplied an empty PurchaseId")
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local receiptOk, receiptDecision, claimOwnerId = acquireReceipt(receiptInfo)
	if not receiptOk then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if receiptDecision == "granted" then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local function retryLater()
		releaseReceiptLease(receiptInfo, claimOwnerId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player or not waitForPlayerData(player, 10) then
		return retryLater()
	end

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
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		return retryLater()
	end

	local transaction = grantProductTransaction(player, productEntry)
	if not transaction then
		return retryLater()
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

	if markProcessed(player, purchaseId) ~= true then
		transaction.Rollback()
		return retryLater()
	end
	local saved = savePlayer(player, "developer_product_" .. productEntry.Kind, true) == true
	if not saved then
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
	local nearestStage, nearestDistance = nil, nil
	if deathPosition then
		nearestStage, nearestDistance = StageTeleportService.GetNearestStage(deathPosition)
	end
	local stage = cleanStage(nearestStage or player:GetAttribute("LastReachedStage") or 1)
	local duration = math.max(1, tonumber(Config.ReviveOfferSeconds) or 5)
	local token = HttpService:GenerateGUID(false)
	local offer = {
		Token = token,
		Stage = stage,
		ExpiresAt = os.clock() + duration,
		Free = player:GetAttribute("InfiniteRevivesOwned") == true,
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
end

ReviveCommerce.OnServerEvent:Connect(function(player, action, token)
	if action ~= "RequestPrompt" then
		return
	end

	local offer = activeReviveOffers[player]
	if not offer
		or tostring(token or "") ~= tostring(offer.Token)
		or os.clock() > (tonumber(offer.ExpiresAt) or 0)
	then
		ReviveCommerce:FireClient(player, {
			Type = "Expired",
			Token = token,
		})
		return
	end
	if offer.Claiming or offer.OwnershipChecking then
		return
	end
	if player:GetAttribute("InfiniteRevivesOwned") ~= true
		and player:GetAttribute("InfiniteRevivesOwnershipVerified") ~= true
	then
		offer.OwnershipChecking = true
		refreshInfiniteRevivesOwnership(player)
		offer.OwnershipChecking = false
		if activeReviveOffers[player] ~= offer
			or os.clock() > (tonumber(offer.ExpiresAt) or 0)
		then
			ReviveCommerce:FireClient(player, {
				Type = "Expired",
				Token = token,
			})
			return
		end
	end

	if player:GetAttribute("InfiniteRevivesOwned") == true then
		offer.Claiming = true
		grantFreeInfiniteRevive(player, offer)
		return
	end

	pendingRevivePurchases[player] = {
		Stage = cleanStage(offer.Stage),
		Token = offer.Token,
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
	local starterPackPassId = tonumber(Config.StarterPackGamePassId)
	local infiniteRevivesPassId = tonumber(Config.InfiniteRevivesGamePassId)

	if starterPackPassId and numericPassId == starterPackPassId then
		player:SetAttribute("StarterPackOwned", true)
		task.spawn(retryStarterPackGrant, player, "purchase_finished")
	elseif infiniteRevivesPassId and numericPassId == infiniteRevivesPassId then
		player:SetAttribute("InfiniteRevivesOwned", true)
		player:SetAttribute("InfiniteRevivesOwnershipVerified", true)
		player:SetAttribute("InfiniteRevivesOwnershipChecked", true)
	end
end)

Players.PlayerAdded:Connect(setupMonetizationPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	task.defer(setupMonetizationPlayer, player)
end

Players.PlayerRemoving:Connect(function(player)
	activeReviveOffers[player] = nil
	pendingRevivePurchases[player] = nil
	starterPackGrantBusy[player] = nil
	starterPackClaimCheckBusy[player] = nil
	monetizationPlayerSetup[player] = nil
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
