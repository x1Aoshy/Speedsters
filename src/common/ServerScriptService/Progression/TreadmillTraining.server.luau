local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
-- A treadmill pass can also be a gift saved on the profile (a gift product's receipt, or
-- the admin panel's Treadmills tool): Services/Monetization/GiftedPasses.
local GiftedPasses = require(game:GetService("ServerScriptService"):WaitForChild("Services"):WaitForChild("Monetization"):WaitForChild("GiftedPasses"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local TreadmillLocked = Remotes:WaitForChild("TreadmillLocked")
local IS_WORLD2 = Config.IsWorld2Place == true
local IS_NEW_WORLD1 = Config.IsNewWorld1Map == true
local function getNewWorld1Root()
	return workspace:FindFirstChild(tostring(Config.NewWorld1MapMarkerName or "neworld1"))
end
local NEW_WORLD1_TREADMILL_PROFILES = Config.NewWorld1TreadmillProfiles or {}

local zones = {}
local lastRefreshAt = 0

local TREADMILL_REBIRTH_REQUIREMENTS = {
	Treadmill2_fast = 1,
	Treadmill3_superfast = IS_WORLD2 and 5 or 7,
}

local STRICT_VISIBLE_FOOTPRINT_TREADMILLS = {
	Treadmill2_fast = true,
	Treadmill3_superfast = true,
}

local TREADMILL_GAMEPASS_REQUIREMENTS = {
	Treadmill4_hyperspeed = 1941090466,                  
	Treadmill5_insanespeed = 1941342451,                       
}

for treadmillName, profile in pairs(NEW_WORLD1_TREADMILL_PROFILES) do
	local requiredRebirths = math.max(0, math.floor(tonumber(profile.RequiredRebirths) or 0))
	local gamePassId = math.max(0, math.floor(tonumber(profile.GamePassId) or 0))
	if requiredRebirths > 0 then
		TREADMILL_REBIRTH_REQUIREMENTS[treadmillName] = requiredRebirths
	end
	if gamePassId > 0 then
		TREADMILL_GAMEPASS_REQUIREMENTS[treadmillName] = gamePassId
	end
	STRICT_VISIBLE_FOOTPRINT_TREADMILLS[treadmillName] = true
end

-- World 3 has its own treadmill profiles (Diamond locked behind more Rebirths); they
-- replace the World 1 defaults above for the treadmills World 3 has.
local worldProfiles = if IS_WORLD2 then Config.World2TreadmillProfiles
	elseif Config.IsWorld3Place == true then Config.World3TreadmillProfiles
	else nil
if worldProfiles then
	for treadmillName, profile in pairs(worldProfiles) do
		local requiredRebirths = math.max(0, math.floor(tonumber(profile.RequiredRebirths) or 0))
		local gamePassId = math.max(0, math.floor(tonumber(profile.GamePassId) or 0))
		if requiredRebirths > 0 then
			TREADMILL_REBIRTH_REQUIREMENTS[treadmillName] = requiredRebirths
		end
		if gamePassId > 0 then
			TREADMILL_GAMEPASS_REQUIREMENTS[treadmillName] = gamePassId
		end
		                                                                            
		STRICT_VISIBLE_FOOTPRINT_TREADMILLS[treadmillName] = true
	end
end

local GAMEPASS_FALSE_CACHE_SECONDS = 2.5
local gamePassOwnershipCache = {}
local gamePassLastCheckedAt = {}

local LOCK_EJECT_PADDING = 2.75
local LOCK_NOTICE_COOLDOWN = 1.25
local lastLockNoticeAt = {}

                                                                              
                                                                                   
local LEGACY_REQUIREMENT_BILLBOARD_NAMES = {
	RebirthRequirementBillboard_V306S = true,
	RebirthRequirementBillboard_V306T = true,
	RebirthRequirementBillboard_V306U = true,
}
local LEGACY_REQUIREMENT_TEXT_NAMES = {
	RebirthRequirementText_V306U = true,
}

local function getBoundingBox(object)
	if object:IsA("Model") then
		return object:GetBoundingBox()
	elseif object:IsA("BasePart") then
		return object.CFrame, object.Size
	end

	return nil, nil
end

local function isNewWorld1TreadmillContainer(object)
	local root = getNewWorld1Root()
	return IS_NEW_WORLD1
		and root ~= nil
		and object ~= nil
		and object:IsDescendantOf(root)
		and NEW_WORLD1_TREADMILL_PROFILES[object.Name] ~= nil
end

local function resolvePhysicalTreadmill(container)
	if not container or not (container:IsA("Model") or container:IsA("BasePart")) then
		return nil
	end

	local nestedBelt = container:FindFirstChild("Treadmil", true)
	if nestedBelt and (nestedBelt:IsA("Model") or nestedBelt:IsA("BasePart")) then
		return nestedBelt
	end

	return container
end


                                                                                 
                                                                               
                                                                            
local MAIN_ZONE_HEIGHT = 5.5
local MAIN_ZONE_BELOW_TOP = 0.35
local WALKING_MIN_UP_ALIGNMENT = 0.78
local WALKING_MIN_AREA = 2
local WALKING_HEIGHT_TOLERANCE = 0.48

local function projectedTopY(part)
	local half = part.Size * 0.5
	local cf = part.CFrame
	local verticalRadius = math.abs(cf.RightVector.Y) * half.X
		+ math.abs(cf.UpVector.Y) * half.Y
		+ math.abs(cf.LookVector.Y) * half.Z
	return part.Position.Y + verticalRadius
end

local function flatUnit(vector, fallback)
	local flat = Vector3.new(vector.X, 0, vector.Z)
	if flat.Magnitude <= 0.001 then
		return fallback
	end
	return flat.Unit
end


                                                                               
                                                                           
                                                                               
                                                                               
                                                                                 
local COLLISION_FOLDER_NAME = "VortexTreadmillCollisionFix_V255"
local COLLISION_DECK_WIDTH_OVERBUILD = 0.70                                               
local COLLISION_DECK_LENGTH_OVERBUILD = 0.90                                               

local function getCollisionDeckZone(treadmill, authoredContainer)
	local generatedFolder = workspace:FindFirstChild(COLLISION_FOLDER_NAME)
	if not generatedFolder then
		return nil, nil
	end

	local wantedSource1 = treadmill and treadmill:GetFullName()
	local wantedSource2 = authoredContainer and authoredContainer:GetFullName()
	for _, folder in ipairs(generatedFolder:GetChildren()) do
		local src = folder:GetAttribute("SourceTreadmill")
		local srcCont = folder:GetAttribute("SourceContainer")
		if (wantedSource1 and (src == wantedSource1 or srcCont == wantedSource1))
			or (wantedSource2 and (src == wantedSource2 or srcCont == wantedSource2))
		then
			local deck = folder:FindFirstChild("SmoothDeck")
			if deck and deck:IsA("BasePart") then
				local width = deck.Size.X + 0.5
				local length = deck.Size.Z + 0.5
				local topY = projectedTopY(deck)
				local centerY = topY + MAIN_ZONE_HEIGHT * 0.5 - MAIN_ZONE_BELOW_TOP
				local center = Vector3.new(deck.Position.X, centerY, deck.Position.Z)
				local right = flatUnit(deck.CFrame.RightVector, Vector3.xAxis)
				local look = flatUnit(deck.CFrame.LookVector, Vector3.zAxis)
				return CFrame.fromMatrix(center, right, Vector3.yAxis, -look),
					Vector3.new(width, MAIN_ZONE_HEIGHT, length),
					deck
			end
		end
	end

	return nil, nil
end

local function getExactWalkingZone(treadmill, fallbackCFrame, fallbackSize)
	local candidates = {}
	local function consider(part)
		if not part:IsA("BasePart") then
			return
		end
		local area = part.Size.X * part.Size.Z
		if math.abs(part.CFrame.UpVector.Y) >= WALKING_MIN_UP_ALIGNMENT and area >= WALKING_MIN_AREA then
			table.insert(candidates, {
				Part = part,
				TopY = projectedTopY(part),
				Area = area,
			})
		end
	end

	if treadmill:IsA("BasePart") then
		consider(treadmill)
	end
	for _, descendant in ipairs(treadmill:GetDescendants()) do
		consider(descendant)
	end

	if #candidates == 0 then
		                                                                          
		                                                                           
		local topY = fallbackCFrame.Position.Y + fallbackSize.Y * 0.5
		local centerY = topY + MAIN_ZONE_HEIGHT * 0.5 - MAIN_ZONE_BELOW_TOP
		local flatRight = flatUnit(fallbackCFrame.RightVector, Vector3.xAxis)
		local flatLook = flatUnit(fallbackCFrame.LookVector, Vector3.zAxis)
		local center = Vector3.new(fallbackCFrame.Position.X, centerY, fallbackCFrame.Position.Z)
		return CFrame.fromMatrix(center, flatRight, Vector3.yAxis, -flatLook),
			Vector3.new(fallbackSize.X, MAIN_ZONE_HEIGHT, fallbackSize.Z)
	end

	                                                                            
	local bestCluster = nil
	local bestArea = -math.huge
	for _, seed in ipairs(candidates) do
		local cluster = {}
		local totalArea = 0
		for _, candidate in ipairs(candidates) do
			if math.abs(candidate.TopY - seed.TopY) <= WALKING_HEIGHT_TOLERANCE then
				table.insert(cluster, candidate)
				totalArea += candidate.Area * (candidate.Part.CanCollide and 1 or 0.35)
			end
		end
		if totalArea > bestArea then
			bestArea = totalArea
			bestCluster = cluster
		end
	end

	if not bestCluster or #bestCluster == 0 then
		return fallbackCFrame, Vector3.new(fallbackSize.X, MAIN_ZONE_HEIGHT, fallbackSize.Z)
	end

	local anchor = bestCluster[1]
	for _, candidate in ipairs(bestCluster) do
		if candidate.Area > anchor.Area then
			anchor = candidate
		end
	end

	local right = flatUnit(anchor.Part.CFrame.RightVector, Vector3.xAxis)
	local look = Vector3.new(-right.Z, 0, right.X)
	local origin = anchor.Part.Position
	local minRight, maxRight = math.huge, -math.huge
	local minLook, maxLook = math.huge, -math.huge
	local weightedTop, totalWeight = 0, 0

	for _, candidate in ipairs(bestCluster) do
		local part = candidate.Part
		local halfX = part.Size.X * 0.5
		local halfZ = part.Size.Z * 0.5
		for _, signX in ipairs({-1, 1}) do
			for _, signZ in ipairs({-1, 1}) do
				local corner = part.Position
					+ part.CFrame.RightVector * halfX * signX
					+ part.CFrame.LookVector * halfZ * signZ
				local offset = corner - origin
				local x = offset:Dot(right)
				local z = offset:Dot(look)
				minRight = math.min(minRight, x)
				maxRight = math.max(maxRight, x)
				minLook = math.min(minLook, z)
				maxLook = math.max(maxLook, z)
			end
		end
		local weight = math.max(candidate.Area, 0.1)
		weightedTop += candidate.TopY * weight
		totalWeight += weight
	end

	local width = math.max(0.5, maxRight - minRight)
	local length = math.max(0.5, maxLook - minLook)
	local centerHorizontal = origin
		+ right * ((minRight + maxRight) * 0.5)
		+ look * ((minLook + maxLook) * 0.5)
	local topY = totalWeight > 0 and (weightedTop / totalWeight)
		or (fallbackCFrame.Position.Y + fallbackSize.Y * 0.5)
	local center = Vector3.new(
		centerHorizontal.X,
		topY + MAIN_ZONE_HEIGHT * 0.5 - MAIN_ZONE_BELOW_TOP,
		centerHorizontal.Z
	)

	return CFrame.fromMatrix(center, right, Vector3.yAxis, -look),
		Vector3.new(width, MAIN_ZONE_HEIGHT, length)
end

local function getRequiredRebirths(treadmillName)
	return TREADMILL_REBIRTH_REQUIREMENTS[treadmillName] or 0
end

local function getRequiredGamePassId(treadmillName)
	return TREADMILL_GAMEPASS_REQUIREMENTS[treadmillName] or 0
end

local function getExactAuthoredGamePassId(treadmillName)
	                                                                          
	                                                                            
	                                                                 
	return TREADMILL_GAMEPASS_REQUIREMENTS[treadmillName] or 0
end

local function getPlayerGamePassTables(player)
	local ownership = gamePassOwnershipCache[player]
	if not ownership then
		ownership = {}
		gamePassOwnershipCache[player] = ownership
	end

	local checkedAt = gamePassLastCheckedAt[player]
	if not checkedAt then
		checkedAt = {}
		gamePassLastCheckedAt[player] = checkedAt
	end

	return ownership, checkedAt
end

local function playerOwnsGamePass(player, gamePassId)
	if not gamePassId or gamePassId <= 0 then
		return true
	end

	local ownership, checkedAt = getPlayerGamePassTables(player)
	if ownership[gamePassId] == true then
		return true
	end

	local now = os.clock()
	if ownership[gamePassId] == false
		and now - (checkedAt[gamePassId] or -math.huge) < GAMEPASS_FALSE_CACHE_SECONDS
	then
		return false
	end

	local success, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gamePassId)
	end)

	checkedAt[gamePassId] = now
	if not (success and owns == true) then
		local giftedOk, gifted = pcall(GiftedPasses.Has, player, gamePassId)
		if giftedOk and gifted == true then
			ownership[gamePassId] = true
			return true
		end
	end
	if not success then
		warn(string.format(
			"[TreadmillTraining] Could not verify Pass %d ownership for %s",
			gamePassId,
			player.Name
		))
		ownership[gamePassId] = false
		return false
	end

	ownership[gamePassId] = owns == true
	return ownership[gamePassId]
end

local function getPlayerRebirths(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local rebirths = leaderstats and leaderstats:FindFirstChild("Rebirths")
	if rebirths and (rebirths:IsA("IntValue") or rebirths:IsA("NumberValue")) then
		return math.max(0, math.floor(tonumber(rebirths.Value) or 0))
	end

	local attributeValue = tonumber(player:GetAttribute("Rebirths"))
	if attributeValue then
		return math.max(0, math.floor(attributeValue))
	end

	return 0
end

local function restoreV306UBillboardSize(billboard)
	if billboard:GetAttribute("V306UOriginalSizeSaved") ~= true then
		return
	end

	billboard.Size = UDim2.new(
		billboard:GetAttribute("V306UOriginalSizeXScale") or billboard.Size.X.Scale,
		billboard:GetAttribute("V306UOriginalSizeXOffset") or billboard.Size.X.Offset,
		billboard:GetAttribute("V306UOriginalSizeYScale") or billboard.Size.Y.Scale,
		billboard:GetAttribute("V306UOriginalSizeYOffset") or billboard.Size.Y.Offset
	)

	billboard:SetAttribute("V306UOriginalSizeSaved", nil)
	billboard:SetAttribute("V306UOriginalSizeXScale", nil)
	billboard:SetAttribute("V306UOriginalSizeXOffset", nil)
	billboard:SetAttribute("V306UOriginalSizeYScale", nil)
	billboard:SetAttribute("V306UOriginalSizeYOffset", nil)
end

local function removeOldRebirthPresentation(treadmill)
	for _, descendant in ipairs(treadmill:GetDescendants()) do
		if descendant:IsA("BillboardGui") then
			restoreV306UBillboardSize(descendant)
		end
	end

	for _, descendant in ipairs(treadmill:GetDescendants()) do
		if LEGACY_REQUIREMENT_BILLBOARD_NAMES[descendant.Name]
			or LEGACY_REQUIREMENT_TEXT_NAMES[descendant.Name]
		then
			descendant:Destroy()
		end
	end
end

local function playerMeetsRequirement(player, zone)
	local container = zone.AuthoredContainer or zone.Treadmill
	if container and (container:GetAttribute("AdminSpawned") == true or container:GetAttribute("OwnerAdminSpawned") == true) then
		return true
	end

	local requiredRebirths = zone.RequiredRebirths or 0
	if requiredRebirths > 0 and getPlayerRebirths(player) < requiredRebirths then
		return false
	end

	local requiredGamePassId = zone.RequiredGamePassId or 0
	if requiredGamePassId > 0 and not playerOwnsGamePass(player, requiredGamePassId) then
		return false
	end

	return true
end

local function notifyLockedPlayer(player, zone)
	local now = os.clock()
	local perPlayer = lastLockNoticeAt[player]
	if not perPlayer then
		perPlayer = {}
		lastLockNoticeAt[player] = perPlayer
	end

	local key = zone.TreadmillName
	if now - (perPlayer[key] or -math.huge) < LOCK_NOTICE_COOLDOWN then
		return
	end
	perPlayer[key] = now

	local requiredGamePassId = zone.RequiredGamePassId or 0
	if requiredGamePassId > 0 then
		TreadmillLocked:FireClient(player, {
			LockType = "GamePass",
			TreadmillName = zone.TreadmillName,
			GamePassId = requiredGamePassId,
		})
	else
		TreadmillLocked:FireClient(player, {
			LockType = "Rebirth",
			TreadmillName = zone.TreadmillName,
			RequiredRebirths = zone.RequiredRebirths or 0,
			CurrentRebirths = getPlayerRebirths(player),
		})
	end
end

local function ejectLockedPlayer(player, zone)
	local character = player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root then
		return
	end

	local localPosition = zone.CFrame:PointToObjectSpace(root.Position)
	local halfX = zone.Size.X * 0.5
	local halfZ = zone.Size.Z * 0.5
	local distanceToXEdge = halfX - math.abs(localPosition.X)
	local distanceToZEdge = halfZ - math.abs(localPosition.Z)
	local targetX = localPosition.X
	local targetZ = localPosition.Z

	if distanceToXEdge <= distanceToZEdge then
		local direction = localPosition.X >= 0 and 1 or -1
		targetX = direction * (halfX + LOCK_EJECT_PADDING)
	else
		local direction = localPosition.Z >= 0 and 1 or -1
		targetZ = direction * (halfZ + LOCK_EJECT_PADDING)
	end

	local targetWorldPosition = zone.CFrame:PointToWorldSpace(Vector3.new(targetX, localPosition.Y, targetZ))
	local rotationOnly = root.CFrame - root.Position

	                                                                                 
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	root.CFrame = CFrame.new(targetWorldPosition) * rotationOnly
end

local partToZone = {}
local hookedParts = {}
local lastSpeedGrantAt = {}
local speedGrantInFlight = {}
local addSpeed

-- Touch and occupancy sampling share one successful-grant clock. A failed or
-- not-yet-ready grant must not postpone the next farming tick.
local function tryGrantTreadmillSpeed(player, zone)
	local now = os.clock()
	local cadence = Config.TreadmillTrainingTickSeconds or Config.TrainingTickSeconds or 0.5
	local last = lastSpeedGrantAt[player]
	if speedGrantInFlight[player] or (last and now - last < cadence) then
		return false
	end
	speedGrantInFlight[player] = true
	local ok, granted = pcall(addSpeed, player, zone)
	speedGrantInFlight[player] = nil
	if ok and granted then
		lastSpeedGrantAt[player] = now
		return true
	end
	if not ok then
		warn("[TreadmillTraining] Speed grant failed: " .. tostring(granted))
	end
	return false
end

-- The name TreadmillVfxController themes the runner's effect by (player attribute
-- CurrentTreadmillName): "Taco" for the taco treadmill, else the zone's treadmill name.
local function getVfxTreadmillName(zone)
	if zone.Treadmill and zone.Treadmill:GetAttribute("IsTacoTreadmill") == true then
		return "Taco"
	end
	return tostring(zone.TreadmillName or "")
end

local function onTreadmillPartTouched(part, hit)
	local character = hit and hit.Parent
	if not character then
		return
	end
	local player = Players:GetPlayerFromCharacter(character)
	if not player then
		return
	end
	local zone = partToZone[part]
	if not zone then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root then
		return
	end
	-- Touching a rail from beside the belt is not training on it.
	local position = zone.CFrame:PointToObjectSpace(root.Position)
	local halfSize = zone.Size * 0.5
	if math.abs(position.X) > halfSize.X or math.abs(position.Y) > halfSize.Y
		or math.abs(position.Z) > halfSize.Z then
		return
	end
	if playerMeetsRequirement(player, zone) then
		if tryGrantTreadmillSpeed(player, zone) then
			player:SetAttribute("IsOnTreadmill", true)
			-- Only when not already on one: the sampling loop keeps the first zone it finds.
			local currentName = player:GetAttribute("CurrentTreadmillName")
			if currentName == nil or currentName == "" then
				player:SetAttribute("CurrentTreadmillName", getVfxTreadmillName(zone))
			end
		end
	else
		notifyLockedPlayer(player, zone)
		ejectLockedPlayer(player, zone)
	end
end

local function hookTreadmillPart(part, zone)
	if not part or not part:IsA("BasePart") then
		return
	end
	partToZone[part] = zone
	if not hookedParts[part] then
		hookedParts[part] = true
		part.Touched:Connect(function(hit)
			onTreadmillPartTouched(part, hit)
		end)
	end
end

local function hookZoneTouched(zone)
	if zone.CollisionDeck then
		hookTreadmillPart(zone.CollisionDeck, zone)
	end
	local treadmill = zone.Treadmill
	if treadmill then
		if treadmill:IsA("BasePart") then
			hookTreadmillPart(treadmill, zone)
		end
		for _, part in ipairs(treadmill:GetDescendants()) do
			if part:IsA("BasePart") then
				hookTreadmillPart(part, zone)
			end
		end
	end
	local container = zone.AuthoredContainer
	if container and container ~= treadmill then
		if container:IsA("BasePart") then
			hookTreadmillPart(container, zone)
		end
		for _, part in ipairs(container:GetDescendants()) do
			if part:IsA("BasePart") then
				hookTreadmillPart(part, zone)
			end
		end
	end
end

local function createZone(treadmill, treadmillName, baseGain, authoredContainer)
	authoredContainer = authoredContainer or treadmill
	local cframe, size = getBoundingBox(treadmill)
	if not cframe or not size then
		warn("[TreadmillTraining] Cannot make zone for " .. treadmill:GetFullName())
		return
	end

	                                                                          
	                                                                             
	removeOldRebirthPresentation(treadmill)

	local newWorld1Profile = IS_NEW_WORLD1 and NEW_WORLD1_TREADMILL_PROFILES[treadmillName]
	local color = (newWorld1Profile and newWorld1Profile.PopupColor)
		or Config.TreadmillPopupColors[treadmillName]
		or Color3.fromRGB(255, 0, 0)

	local burstCount = Config.DefaultPopupBurstCount or 3
	if newWorld1Profile and tonumber(newWorld1Profile.PopupBurstCount) then
		burstCount = math.max(1, math.floor(tonumber(newWorld1Profile.PopupBurstCount)))
	elseif Config.TreadmillPopupBurstCounts and Config.TreadmillPopupBurstCounts[treadmillName] then
		burstCount = Config.TreadmillPopupBurstCounts[treadmillName]
	elseif treadmillName == "Treadmill5_insanespeed" or treadmillName == "TreadmillAdmin" then
		burstCount = Config.InsanePopupBurstCount or 18
	end

	local isStageClone = treadmill:GetAttribute("StageClone") == true
		or treadmill:GetAttribute("IsStageClone") == true
	local requiredRebirths = getRequiredRebirths(treadmillName)
	local requiredGamePassId = getRequiredGamePassId(treadmillName)

	local zoneCFrame = cframe
	local zoneSize = size
	local collisionDeck = nil

	if isStageClone then
		local horizontalScale = 0.90
		local verticalPadding = 2.0
		zoneSize = Vector3.new(
			math.max(1.5, size.X * horizontalScale),
			math.max(3.25, size.Y + verticalPadding),
			math.max(1.5, size.Z * horizontalScale)
		)
	else
		zoneCFrame, zoneSize, collisionDeck = getCollisionDeckZone(treadmill, authoredContainer)
		if not zoneCFrame or not zoneSize then
			zoneCFrame, zoneSize = getExactWalkingZone(treadmill, cframe, size)
		end
	end

	local zone = {
		Treadmill = treadmill,
		AuthoredContainer = authoredContainer,
		TreadmillName = treadmillName,
		BaseGain = baseGain,
		PopupColor = color,
		BurstCount = burstCount,
		CFrame = zoneCFrame,
		Size = zoneSize,
		IsStageClone = isStageClone,
		RequiredRebirths = requiredRebirths,
		RequiredGamePassId = requiredGamePassId,
		CollisionDeck = collisionDeck,
	}

	table.insert(zones, zone)
	hookZoneTouched(zone)
	print("[TreadmillTraining] Registered " .. authoredContainer:GetFullName() .. " as +" .. tostring(baseGain) .. " Speed | popups=" .. tostring(burstCount))
	if requiredGamePassId > 0 then
		print(string.format(
			"[TreadmillTraining] PAID LOCK ACTIVE | %s | exactName=%s | Pass=%d",
				authoredContainer:GetFullName(),
				treadmillName,
			requiredGamePassId
		))
	end
end

local function registerIfTreadmill(tracked, treadmill, treadmillName, baseGain, authoredContainer)
	authoredContainer = authoredContainer or treadmill
	if not treadmill or tracked[treadmill] or (authoredContainer and tracked[authoredContainer]) then
		return false
	end

	if treadmill:IsA("Model") or treadmill:IsA("BasePart") then
		tracked[treadmill] = true
		if authoredContainer then
			tracked[authoredContainer] = true
		end
		createZone(treadmill, treadmillName, baseGain, authoredContainer)
		return true
	end

	return false
end

local function registerTreadmills()
	table.clear(zones)
	table.clear(partToZone)
	local tracked = {}
	local foundByName = {}
	local foundNewWorld1ByName = {}
	local descendants = workspace:GetDescendants()

	for _, descendant in ipairs(descendants) do
		if isNewWorld1TreadmillContainer(descendant) then
			local profile = NEW_WORLD1_TREADMILL_PROFILES[descendant.Name]
			local physicalTreadmill = resolvePhysicalTreadmill(descendant)
			if physicalTreadmill and registerIfTreadmill(
				tracked,
				physicalTreadmill,
				descendant.Name,
				math.max(0, tonumber(profile.BaseGain) or 0),
				descendant
			) then
				foundNewWorld1ByName[descendant.Name] = true
			end
		end

		local namedGain = Config.TreadmillBaseGains[descendant.Name]
		if namedGain then
			-- If descendant is a container named "Admin" that contains other treadmill models, do NOT register the container
			local isContainer = false
			if descendant:IsA("Model") and descendant.Name == "Admin" then
				for _, child in ipairs(descendant:GetChildren()) do
					if child:IsA("Model") and (Config.TreadmillBaseGains[child.Name] or child:FindFirstChild("Treadmil", true)) then
						isContainer = true
						break
					end
				end
			end
			if not isContainer then
				local physicalTreadmill = resolvePhysicalTreadmill(descendant)
				if registerIfTreadmill(tracked, physicalTreadmill, descendant.Name, namedGain, descendant) then
					foundByName[descendant.Name] = true
				end
			end
		end

		-- Special check for inner Admin treadmill inside container
		if descendant:IsA("Model") and descendant.Name == "Model" and descendant.Parent and descendant.Parent.Name == "Admin" and descendant:FindFirstChild("Treadmil", true) then
			local adminGain = Config.TreadmillBaseGains["Admin"] or 100
			local physicalTreadmill = resolvePhysicalTreadmill(descendant)
			if registerIfTreadmill(tracked, physicalTreadmill, "Admin", adminGain, descendant) then
				foundByName["Admin"] = true
			end
		end

		local sourceName = descendant:GetAttribute("TreadmillTrainingSourceName")
		local sourceGain = typeof(sourceName) == "string" and Config.TreadmillBaseGains[sourceName]
		if sourceGain then
			local physicalTreadmill = resolvePhysicalTreadmill(descendant)
			registerIfTreadmill(tracked, physicalTreadmill, sourceName, sourceGain, descendant)
		end
	end

	for treadmillName in pairs(Config.TreadmillBaseGains) do
		if not foundByName[treadmillName] then
			local foundSourceClone = false
			for treadmill in pairs(tracked) do
				if treadmill:GetAttribute("TreadmillTrainingSourceName") == treadmillName then
					foundSourceClone = true
					break
				end
			end
			if not foundSourceClone and not IS_NEW_WORLD1 then
				warn("[TreadmillTraining] Missing treadmill model(s): " .. tostring(treadmillName))
			end
		end
	end

	if IS_NEW_WORLD1 then
		for treadmillName, profile in pairs(NEW_WORLD1_TREADMILL_PROFILES) do
			if not foundNewWorld1ByName[treadmillName] and profile.SpawnedAtRuntime ~= true then
				warn("[TreadmillTraining] Missing new World 1 treadmill: " .. treadmillName)
			end
		end
	end

	lastRefreshAt = os.clock()
	print("[TreadmillTraining] Total treadmill zones: " .. tostring(#zones))
end

local refreshQueued = false
local function objectCouldAffectTreadmillRegistry(object)
	if not object then
		return false
	end

	if Config.TreadmillBaseGains[object.Name] ~= nil then
		return true
	end
	if isNewWorld1TreadmillContainer(object) then
		return true
	end

	local sourceName = object:GetAttribute("TreadmillTrainingSourceName")
	if typeof(sourceName) == "string" and Config.TreadmillBaseGains[sourceName] ~= nil then
		return true
	end

	if object.Name == "SmoothDeck"
		or object:GetAttribute("VortexTreadmillCollisionPart") == true
	then
		return true
	end

	local parent = object.Parent
	while parent and parent ~= workspace do
		if isNewWorld1TreadmillContainer(parent) then
			return true
		end
		if Config.TreadmillBaseGains[parent.Name] ~= nil then
			return true
		end
		local parentSource = parent:GetAttribute("TreadmillTrainingSourceName")
		if typeof(parentSource) == "string" and Config.TreadmillBaseGains[parentSource] ~= nil then
			return true
		end
		if parent.Name == COLLISION_FOLDER_NAME
			or parent:GetAttribute("VortexTreadmillCollisionPart") == true
		then
			return true
		end
		parent = parent.Parent
	end

	return false
end

local function queueTreadmillRefresh()
	if refreshQueued then
		return
	end
	refreshQueued = true
	task.delay(0.15, function()
		refreshQueued = false
		registerTreadmills()
	end)
end

local function isRootActuallyOverCollisionDeck(character, root, zone)
	local deck = zone.CollisionDeck
	if not deck or not deck.Parent or not deck:IsA("BasePart") then
		return nil
	end

	local localPosition = deck.CFrame:PointToObjectSpace(root.Position)
	local exactHalfX = deck.Size.X * 0.5 + 0.5
	local exactHalfZ = deck.Size.Z * 0.5 + 0.5
	if math.abs(localPosition.X) > exactHalfX or math.abs(localPosition.Z) > exactHalfZ then
		return false
	end

	local deckTopY = projectedTopY(deck)
	local heightAboveDeck = root.Position.Y - deckTopY
	if heightAboveDeck < -0.5 or heightAboveDeck > MAIN_ZONE_HEIGHT then
		return false
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { deck }
	params.IgnoreWater = true

	local origin = root.Position + Vector3.new(0, 0.25, 0)
	local distance = math.max(1, heightAboveDeck + 0.75)
	local result = workspace:Raycast(origin, Vector3.new(0, -distance, 0), params)
	return result ~= nil and result.Instance == deck
end

local function isRootDirectlySupportedByTreadmill(character, root, zone)
	if zone.IsStageClone then
		return false
	end

	local deck = zone.CollisionDeck
	if not deck or not deck.Parent or not deck:IsA("BasePart") then
		return false
	end

	local deckLocalPosition = deck.CFrame:PointToObjectSpace(root.Position)
	local exactHalfX = deck.Size.X * 0.5 + 0.5
	local exactHalfZ = deck.Size.Z * 0.5 + 0.5
	if math.abs(deckLocalPosition.X) > exactHalfX or math.abs(deckLocalPosition.Z) > exactHalfZ then
		return false
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.IgnoreWater = true
	params.RespectCanCollide = false

	local result = workspace:Raycast(
		root.Position + Vector3.new(0, 0.35, 0),
		Vector3.new(0, -(MAIN_ZONE_HEIGHT + 3.5), 0),
		params
	)
	if not result or not result.Instance then
		return false
	end

	local hit = result.Instance
	local treadmill = zone.Treadmill
	local container = zone.AuthoredContainer
	if treadmill then
		if hit == treadmill then
			return true
		end
		if treadmill:IsA("Model") and hit:IsDescendantOf(treadmill) then
			return true
		end
	end
	if container and container ~= treadmill then
		if hit == container then
			return true
		end
		if container:IsA("Model") and hit:IsDescendantOf(container) then
			return true
		end
	end

	local generatedFolder = workspace:FindFirstChild(COLLISION_FOLDER_NAME)
	if generatedFolder and hit:IsDescendantOf(generatedFolder) then
		local node = hit
		while node and node ~= generatedFolder do
			local src = node:GetAttribute("SourceTreadmill")
			local srcCont = node:GetAttribute("SourceContainer")
			if (treadmill and (src == treadmill:GetFullName() or srcCont == treadmill:GetFullName()))
				or (container and (src == container:GetFullName() or srcCont == container:GetFullName()))
			then
				return true
			end
			node = node.Parent
		end
	end

	return false
end

local function rootInsideTrimmedZone(root, zone)
	local localPosition = zone.CFrame:PointToObjectSpace(root.Position)
	local halfX = zone.Size.X * 0.5
	local halfY = zone.Size.Y * 0.5
	local halfZ = zone.Size.Z * 0.5

	return math.abs(localPosition.X) <= halfX
		and math.abs(localPosition.Y) <= halfY
		and math.abs(localPosition.Z) <= halfZ
end

local function findPlayersInZone(zone)
	local found = {}
	local zonePos = zone.CFrame.Position
	local maxHoriz = math.max(zone.Size.X, zone.Size.Z) * 0.5 + 16
	local maxRadiusSq = maxHoriz * maxHoriz
	local maxVert = zone.Size.Y * 0.5 + 16

	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid and humanoid.Health > 0 and root then
			local rootPos = root.Position
			local dx = rootPos.X - zonePos.X
			local dz = rootPos.Z - zonePos.Z
			if (dx * dx + dz * dz) <= maxRadiusSq and math.abs(rootPos.Y - zonePos.Y) <= maxVert then
				local exactDeckResult = nil
				if not zone.IsStageClone then
					exactDeckResult = isRootActuallyOverCollisionDeck(character, root, zone)
				end

				local directSupportResult = false
				if not zone.IsStageClone then
					directSupportResult = isRootDirectlySupportedByTreadmill(character, root, zone)
				end

				if exactDeckResult == true or directSupportResult == true then
					found[player] = true
				elseif rootInsideTrimmedZone(root, zone) then
					found[player] = true
				end
			end
		end
	end

	return found
end

local function isAdminTreadmill(zone)
	if not zone or not zone.Treadmill then
		return false
	end
	return (tonumber(zone.RequiredGamePassId) or tonumber(zone.GamePassId) or 0) <= 0
		and zone.Treadmill:GetAttribute("AdminSpawned") == true
end

addSpeed = function(player, zone)
	                                                                             
	                                                                                  
	if not playerMeetsRequirement(player, zone) then
		return false
	end

	local addFunction = _G.SpeedsterAddSpeed
	if typeof(addFunction) == "function" then
		local baseGain = zone.BaseGain

		-- An admin treadmill pays its own profile's Speed (Admin3000: the Hacker treadmill's
		-- plus 5%) and, on top, Wins times the admin's multiplier.
		local isTaco = zone.Treadmill:GetAttribute("IsTacoTreadmill") == true
		if isAdminTreadmill(zone) then
			local winMult = tonumber(_G.AdminTreadmillWinMult) or 2
			local winBase = if isTaco then 250 else 200

			local addWins = _G.SpeedsterAddWins
			if typeof(addWins) == "function" then
				addWins(player, winBase * winMult)
			end
		end

		local totalMult = 1
		if type(_G.SpeedsterGetTotalGainMultiplier) == "function" then
			local okMult, mult = pcall(_G.SpeedsterGetTotalGainMultiplier, player)
			if okMult and type(mult) == "number" and mult > 0 then
				totalMult = mult
			end
		end

		local granted = addFunction(player, baseGain, {
			Color = if isTaco then Color3.fromRGB(255, 200, 40) else zone.PopupColor,
			BurstCount = zone.BurstCount,
			TreadmillName = if isTaco then "Taco Treadmill" else zone.TreadmillName,
			ForcePopup = true,
			VisualAmount = math.max(1, math.round(baseGain * totalMult)),
		})
		return granted ~= false
	else
		warn("[TreadmillTraining] Speed add function not ready for " .. player.Name)
	end

	return false
end

task.wait(1)
registerTreadmills()

                                                                                
                                                                              
                                                           
workspace.DescendantAdded:Connect(function(object)
	if objectCouldAffectTreadmillRegistry(object) then
		queueTreadmillRefresh()
	else
		                                                                            
		                                                                      
		task.delay(0.1, function()
			if object.Parent and objectCouldAffectTreadmillRegistry(object) then
				queueTreadmillRefresh()
			end
		end)
	end
end)
workspace.DescendantRemoving:Connect(function(object)
	if objectCouldAffectTreadmillRegistry(object) then
		queueTreadmillRefresh()
	end
end)

local function ensureHeadTaco(player: Player)
	local character = player.Character
	if not character then return end
	local head = character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then return end
	if character:FindFirstChild("TacoHeadAccessory") then return end

	local taco = Instance.new("Part")
	taco.Name = "TacoHeadAccessory"
	taco.Size = Vector3.new(1.2, 1.4, 2.3)
	taco.CanCollide = false
	taco.CanQuery = false
	taco.CanTouch = false
	taco.Massless = true
	taco.CastShadow = false
	taco.Color = Color3.fromRGB(255, 205, 70)
	taco.Material = Enum.Material.SmoothPlastic
	taco.CFrame = head.CFrame * CFrame.new(0, 1.45, 0)

	require(ReplicatedStorage.Shared.TacoVisual).Decorate(taco, 1.1)

	local weld = Instance.new("Weld")
	weld.C0 = CFrame.new(0, 2.1, 0)
	weld.Name = "TacoWeld"
	weld.Part0 = head
	weld.Part1 = taco
	weld.Parent = taco

	taco.Parent = character
end

local function removeHeadTaco(player: Player)
	local character = player.Character
	if not character then return end
	local taco = character:FindFirstChild("TacoHeadAccessory")
	if taco then
		taco:Destroy()
	end
end

task.spawn(function()
	local loopInterval = 0.1 -- High-responsiveness sampling
	while true do
		task.wait(loopInterval)

		local playersOnAnyTreadmill = {}
		local currentTreadmillNameByPlayer = {}
		local playersOnTutorialBrownTreadmill = {}
		local playersOnTacoTreadmill = {}

		for _, zone in ipairs(zones) do
			local playersInZone = findPlayersInZone(zone)

			for player in pairs(playersInZone) do
				playersOnAnyTreadmill[player] = true
				if currentTreadmillNameByPlayer[player] == nil then
					-- The first zone found this tick wins when zones overlap (deterministic).
					currentTreadmillNameByPlayer[player] = getVfxTreadmillName(zone)
				end
				if (zone.TreadmillName == "Treadmill1_basic" or zone.TreadmillName == "Basic")
					and not zone.IsStageClone
					and zone.AuthoredContainer
					and zone.AuthoredContainer:GetAttribute("OwnerAdminSpawned") ~= true
				then
					playersOnTutorialBrownTreadmill[player] = true
				end

				if zone.Treadmill and zone.Treadmill:GetAttribute("IsTacoTreadmill") == true then
					playersOnTacoTreadmill[player] = true
				end

				if playerMeetsRequirement(player, zone) then
					tryGrantTreadmillSpeed(player, zone)
				else
					notifyLockedPlayer(player, zone)
					ejectLockedPlayer(player, zone)
				end
			end
		end

		local isRainingTacos = false
		local rainingUntil = tonumber(workspace:GetAttribute("AdminRainingTacosUntil"))
		if rainingUntil and (rainingUntil > workspace:GetServerTimeNow() or rainingUntil > os.time()) then
			isRainingTacos = true
		end

		for _, player in ipairs(Players:GetPlayers()) do
			local onAny = playersOnAnyTreadmill[player] == true
			if player:GetAttribute("IsOnTreadmill") ~= onAny then
				player:SetAttribute("IsOnTreadmill", onAny)
			end
			local currentName = if onAny then (currentTreadmillNameByPlayer[player] or "") else ""
			if player:GetAttribute("CurrentTreadmillName") ~= currentName then
				player:SetAttribute("CurrentTreadmillName", currentName)
			end
			local onTutorialBrown = playersOnTutorialBrownTreadmill[player] == true
			if player:GetAttribute("OnTutorialBrownTreadmill") ~= onTutorialBrown then
				player:SetAttribute("OnTutorialBrownTreadmill", onTutorialBrown)
			end

			local shouldHaveHeadTaco = isRainingTacos or (playersOnTacoTreadmill[player] == true)
			if shouldHaveHeadTaco then
				ensureHeadTaco(player)
			else
				removeHeadTaco(player)
			end
		end
	end
end)

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, wasPurchased)
	if not player or not gamePassId then
		return
	end

	local ownership, checkedAt = getPlayerGamePassTables(player)
	if wasPurchased then
		ownership[gamePassId] = true
		checkedAt[gamePassId] = os.clock()
	else
		ownership[gamePassId] = nil
		checkedAt[gamePassId] = nil
	end
end)

-- A pass given or taken away on the profile (the admin panel) counts at once, not after
-- the cached answer runs out.
_G.SpeedsterForgetTreadmillPasses = function(player)
	gamePassOwnershipCache[player] = nil
	gamePassLastCheckedAt[player] = nil
end

Players.PlayerRemoving:Connect(function(player)
	lastLockNoticeAt[player] = nil
	lastSpeedGrantAt[player] = nil
	speedGrantInFlight[player] = nil
	gamePassOwnershipCache[player] = nil
	gamePassLastCheckedAt[player] = nil
	removeHeadTaco(player)
end)

print(
	"[TreadmillTraining] V306HC loaded. Existing training is preserved; the main Brown treadmill now exposes one exact event-driven tutorial signal."
)
