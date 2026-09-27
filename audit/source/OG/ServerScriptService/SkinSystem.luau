local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local InsertService = game:GetService("InsertService")
local ServerStorage = game:GetService("ServerStorage")
local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local SuitCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SuitCatalog"))

local EquipSkin = Remotes:FindFirstChild("EquipSkin")
if not EquipSkin then
	EquipSkin = Instance.new("RemoteEvent")
	EquipSkin.Name = "EquipSkin"
	EquipSkin.Parent = Remotes
end

local EvolveSkinUpdate = Remotes:FindFirstChild("EvolveSkinUpdate")
if not EvolveSkinUpdate then
	EvolveSkinUpdate = Instance.new("RemoteEvent")
	EvolveSkinUpdate.Name = "EvolveSkinUpdate"
	EvolveSkinUpdate.Parent = Remotes
end

local SkinIndexRequest = Remotes:FindFirstChild("SkinIndexRequest")
if not SkinIndexRequest then
	SkinIndexRequest = Instance.new("RemoteEvent")
	SkinIndexRequest.Name = "SkinIndexRequest"
	SkinIndexRequest.Parent = Remotes
end

local SkinIndexUpdate = Remotes:FindFirstChild("SkinIndexUpdate")
if not SkinIndexUpdate then
	SkinIndexUpdate = Instance.new("RemoteEvent")
	SkinIndexUpdate.Name = "SkinIndexUpdate"
	SkinIndexUpdate.Parent = Remotes
end

local FLASH_ENTRY = assert(SuitCatalog.Get("FlashSuit"), "SuitCatalog is missing FlashSuit")
local REVERSE_ENTRY = assert(SuitCatalog.Get("ReverseSpeedsterSuit"), "SuitCatalog is missing ReverseSpeedsterSuit")
local FLASH_LEVEL_REQUIRED = tonumber(FLASH_ENTRY.RequiredLevel) or 0

local FLASH_HELMET_ID = FLASH_ENTRY.MaskId
local FLASH_SHIRT_ID = assert(FLASH_ENTRY.ShirtId, "FlashSuit is missing ShirtId")
local FLASH_PANTS_ID = assert(FLASH_ENTRY.PantsId, "FlashSuit is missing PantsId")

local REVERSE_MASK_ID = REVERSE_ENTRY.MaskId
local REVERSE_PANTS_ID = REVERSE_ENTRY.PantsId
local REVERSE_SHIRT_ID = REVERSE_ENTRY.ShirtId

local originalDescriptions = {}
local lastAppliedCharacter = {}
local lastAppliedSkin = {}
local applyingSavedSkin = {}
local evolveInProgress = {}

local INDEX_SKINS = {}
for _, entry in ipairs(SuitCatalog.Ordered) do
	table.insert(INDEX_SKINS, {
		Id = entry.Id,
		DisplayName = entry.DisplayName,
		PreviewAssetId = entry.PreviewAssetId,
		RequiredLevel = entry.RequiredLevel,
		RequiredRebirths = entry.RequiredRebirths or 0,
		Stamina = entry.Stamina,
	})
end

local INDEX_DISPLAY_SKINS = {}
for _, entry in ipairs(INDEX_SKINS) do
	table.insert(INDEX_DISPLAY_SKINS, entry)
end
for _, entry in ipairs(SuitCatalog.Limited or {}) do
	table.insert(INDEX_DISPLAY_SKINS, {
		Id = entry.Id,
		DisplayName = entry.DisplayName,
		PreviewAssetId = entry.PreviewAssetId,
		RequiredLevel = entry.RequiredLevel or 0,
		RequiredRebirths = entry.RequiredRebirths or 0,
		Stamina = entry.Stamina,
	})
end

local VALID_INDEX_SKINS = {}
for _, entry in ipairs(INDEX_DISPLAY_SKINS) do
	VALID_INDEX_SKINS[entry.Id] = true
end

local ACCESSORY_FIELDS = {
	HatAccessory = true,
	HairAccessory = true,
	FaceAccessory = true,
	NeckAccessory = true,
	ShoulderAccessory = true,
	FrontAccessory = true,
	BackAccessory = true,
	WaistAccessory = true,

	ShirtAccessory = true,
	TShirtAccessory = true,
	PantsAccessory = true,
	JacketAccessory = true,
	SweaterAccessory = true,
	ShortsAccessory = true,
	LeftShoeAccessory = true,
	RightShoeAccessory = true,
	DressSkirtAccessory = true,
}


local function safeGetDescriptionField(desc, field)
	local ok, value = pcall(function()
		return desc[field]
	end)

	if ok then
		return value
	end

	return nil
end

local function safeSetDescriptionField(desc, field, value)
	local ok = pcall(function()
		desc[field] = value
	end)

	return ok
end

local function safeClearDescriptionField(desc, field)
	return safeSetDescriptionField(desc, field, "")
end

local ASSET_FIELD_BY_TYPE_ID = {}
local assetFieldCache = {}
local assetInfoCache = {}

local function mapAssetType(enumName, descriptionField)
	local ok, enumItem = pcall(function()
		return Enum.AssetType[enumName]
	end)

	if ok and enumItem then
		ASSET_FIELD_BY_TYPE_ID[enumItem.Value] = descriptionField
	end
end

mapAssetType("Hat", "HatAccessory")
mapAssetType("HairAccessory", "HairAccessory")
mapAssetType("FaceAccessory", "FaceAccessory")
mapAssetType("NeckAccessory", "NeckAccessory")
mapAssetType("ShoulderAccessory", "ShoulderAccessory")
mapAssetType("FrontAccessory", "FrontAccessory")
mapAssetType("BackAccessory", "BackAccessory")
mapAssetType("WaistAccessory", "WaistAccessory")
mapAssetType("Shirt", "Shirt")
mapAssetType("Pants", "Pants")
mapAssetType("TShirt", "GraphicTShirt")
mapAssetType("ShirtAccessory", "ShirtAccessory")
mapAssetType("TShirtAccessory", "TShirtAccessory")
mapAssetType("PantsAccessory", "PantsAccessory")
mapAssetType("JacketAccessory", "JacketAccessory")
mapAssetType("SweaterAccessory", "SweaterAccessory")
mapAssetType("ShortsAccessory", "ShortsAccessory")
mapAssetType("LeftShoeAccessory", "LeftShoeAccessory")
mapAssetType("RightShoeAccessory", "RightShoeAccessory")
mapAssetType("DressSkirtAccessory", "DressSkirtAccessory")

local function getLevel(player)
	return tonumber(player:GetAttribute("Level")) or 1
end

local function getRebirths(player)
	local attributeValue = tonumber(player:GetAttribute("Rebirths"))
	if attributeValue ~= nil then
		return math.max(0, math.floor(attributeValue))
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	local rebirths = leaderstats and leaderstats:FindFirstChild("Rebirths")
	return math.max(0, math.floor(tonumber(rebirths and rebirths.Value) or 0))
end

local function appendAccessory(desc, field, assetId)
	local assetString = tostring(assetId)
	local current = tostring(safeGetDescriptionField(desc, field) or "")

	if current == "" then
		safeSetDescriptionField(desc, field, assetString)
		return
	end

	for _, id in ipairs(string.split(current, ",")) do
		if id == assetString then
			return
		end
	end

	safeSetDescriptionField(desc, field, current .. "," .. assetString)
end

local function removeAccessoryFromField(desc, field, assetId)
	local current = tostring(safeGetDescriptionField(desc, field) or "")
	if current == "" then
		return
	end

	local target = tostring(assetId)
	local kept = {}

	for _, id in ipairs(string.split(current, ",")) do
		if id ~= "" and id ~= target then
			table.insert(kept, id)
		end
	end

	safeSetDescriptionField(desc, field, table.concat(kept, ","))
end


local KNOWN_SPEEDSTER_ASSET_IDS = {}
for _, collection in ipairs({ SuitCatalog.Ordered, SuitCatalog.Limited or {} }) do
	for _, entry in ipairs(collection) do
		for _, fieldName in ipairs({ "MaskId", "HairId", "SuitId", "ShirtId", "PantsId" }) do
			local assetId = tonumber(entry[fieldName])
			if assetId then
				KNOWN_SPEEDSTER_ASSET_IDS[assetId] = true
			end
		end
	end
end

local function removeKnownSpeedsterAssets(desc)
	for assetId in pairs(KNOWN_SPEEDSTER_ASSET_IDS) do
		for field in pairs(ACCESSORY_FIELDS) do
			removeAccessoryFromField(desc, field, assetId)
		end

		if tostring(safeGetDescriptionField(desc, "Shirt") or "") == tostring(assetId) then
			safeSetDescriptionField(desc, "Shirt", 0)
		end
		if tostring(safeGetDescriptionField(desc, "Pants") or "") == tostring(assetId) then
			safeSetDescriptionField(desc, "Pants", 0)
		end
		if tostring(safeGetDescriptionField(desc, "GraphicTShirt") or "") == tostring(assetId) then
			safeSetDescriptionField(desc, "GraphicTShirt", 0)
		end
	end
end

local function forceSuitState(player, skinId)
	player:SetAttribute("EquippedSkin", skinId)
	player:SetAttribute("FlashStaminaActive", true)
	player:SetAttribute("FlashStaminaUpgrade", true)
end

local function forceReverseStamina(player)
	forceSuitState(player, "ReverseSpeedsterSuit")
end

local function getAssetField(assetId)
	local cachedField = assetFieldCache[assetId]
	if cachedField ~= nil then
		return cachedField, assetInfoCache[assetId]
	end

	local info
	local ok, err = pcall(function()
		info = MarketplaceService:GetProductInfo(assetId, Enum.InfoType.Asset)
	end)

	if not ok or not info then
		warn("[SkinSystem] Could not get ProductInfo for " .. tostring(assetId) .. ": " .. tostring(err))
		return nil
	end

	local field = ASSET_FIELD_BY_TYPE_ID[info.AssetTypeId]
	if not field then
		warn("[SkinSystem] Unsupported AssetTypeId for " .. tostring(assetId) .. ": " .. tostring(info.AssetTypeId) .. " / " .. tostring(info.Name))
		return nil, info
	end

	assetFieldCache[assetId] = field
	assetInfoCache[assetId] = info
	return field, info
end

local function applyAssetToDescription(desc, assetId, forcedField)
	local field = forcedField or getAssetField(assetId)
	if not field then
		return false
	end

	local ok = pcall(function()
		if field == "Shirt" or field == "Pants" or field == "GraphicTShirt" then
			safeSetDescriptionField(desc, field, tonumber(assetId))
		elseif ACCESSORY_FIELDS[field] then
			appendAccessory(desc, field, assetId)
		end
	end)

	return ok
end

local skinAssetCacheFolder = ServerStorage:FindFirstChild("SkinAssetRuntimeCache")
if skinAssetCacheFolder and not skinAssetCacheFolder:IsA("Folder") then
	skinAssetCacheFolder:Destroy()
	skinAssetCacheFolder = nil
end
if not skinAssetCacheFolder then
	skinAssetCacheFolder = Instance.new("Folder")
	skinAssetCacheFolder.Name = "SkinAssetRuntimeCache"
	skinAssetCacheFolder.Parent = ServerStorage
end

local cachedLoadedAssets = {}

local function getCachedLoadedAsset(assetId)
	local cached = cachedLoadedAssets[assetId]
	if cached and cached.Parent then
		return cached
	end

	local cacheName = "Asset_" .. tostring(assetId)
	local existing = skinAssetCacheFolder:FindFirstChild(cacheName)
	if existing then
		cachedLoadedAssets[assetId] = existing
		return existing
	end

	local loaded
	local ok, err = pcall(function()
		loaded = InsertService:LoadAsset(assetId)
	end)

	if not ok or not loaded then
		warn("[SkinSystem] InsertService cache load failed for " .. tostring(assetId) .. ": " .. tostring(err))
		return nil
	end

	loaded.Name = cacheName
	loaded.Parent = skinAssetCacheFolder
	cachedLoadedAssets[assetId] = loaded
	return loaded
end

local function cloneCachedLoadedAsset(assetId)
	local cached = getCachedLoadedAsset(assetId)
	return cached and cached:Clone() or nil
end

local function removeFlashFallbackObjects(character)
	for _, child in ipairs(character:GetChildren()) do
		if child:GetAttribute("FlashSuitAccessory") == true then
			child:Destroy()
		end
	end
end

local function forceLoadAccessory(character, humanoid, assetId)
	local loaded = cloneCachedLoadedAsset(assetId)
	if not loaded then
		return false
	end

	local added = false

	for _, child in ipairs(loaded:GetChildren()) do
		if child:IsA("Accessory") then
			child:SetAttribute("FlashSuitAccessory", true)
			child:SetAttribute("SpeedsterCatalogAssetId", assetId)
			child.Parent = character

			local addOk, addErr = pcall(function()
				humanoid:AddAccessory(child)
			end)

			if not addOk then
				warn("[SkinSystem] AddAccessory failed for " .. tostring(assetId) .. ": " .. tostring(addErr))
			else
				added = true
			end
		end
	end

	loaded:Destroy()
	return added
end

local function forceClassicClothing(character, assetId, field)
	if field == "Shirt" then
		local shirt = character:FindFirstChildOfClass("Shirt")
		if not shirt then
			shirt = Instance.new("Shirt")
			shirt.Parent = character
		end
		shirt:SetAttribute("FlashSuitClothing", true)
		shirt.ShirtTemplate = "rbxassetid://" .. tostring(assetId)
		return true
	elseif field == "Pants" then
		local pants = character:FindFirstChildOfClass("Pants")
		if not pants then
			pants = Instance.new("Pants")
			pants.Parent = character
		end
		pants:SetAttribute("FlashSuitClothing", true)
		pants.PantsTemplate = "rbxassetid://" .. tostring(assetId)
		return true
	end

	return false
end

local function removeFlashDirectClothing(character)
	for _, child in ipairs(character:GetChildren()) do
		if child:GetAttribute("FlashSuitClothing") == true then
			child:Destroy()
		end
	end
end

local function getOwnedSkinsFolder(player)
	local dataFolder = player:FindFirstChild("SpeedsterData")
	if not dataFolder then
		return nil
	end

	local folder = dataFolder:FindFirstChild("OwnedSkins")
	if folder and not folder:IsA("Folder") then
		folder:Destroy()
		folder = nil
	end

	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "OwnedSkins"
		folder.Parent = dataFolder
	end

	return folder
end

local function ownsSkin(player, skinId)
	local folder = getOwnedSkinsFolder(player)
	local value = folder and folder:FindFirstChild(skinId)
	return value ~= nil and value:IsA("BoolValue") and value.Value == true
end

local function unlockSkin(player, skinId)
	if not SuitCatalog.IsValid(skinId) then
		return false
	end

	if type(_G.SpeedsterUnlockSkin) == "function" then
		_G.SpeedsterUnlockSkin(player, skinId)
	else
		local folder = getOwnedSkinsFolder(player)
		if not folder then
			return false
		end

		local value = folder:FindFirstChild(skinId)
		if not value then
			value = Instance.new("BoolValue")
			value.Name = skinId
			value.Parent = folder
		end
		value.Value = true
	end

	return true
end

local function getNextEvolutionEntry(player)
	for _, entry in ipairs(INDEX_SKINS) do
		if not ownsSkin(player, entry.Id) then
			return entry
		end
	end
	return nil
end

local function saveSkinState(player, reason)
	task.defer(function()
		local savePlayer = _G.SpeedsterSavePlayer
		if type(savePlayer) == "function" and player.Parent then
			savePlayer(player, reason or "skin_change")
		end
	end)
end

local function collectOwnedSkins(player)
	local owned = {}
	for _, entry in ipairs(INDEX_DISPLAY_SKINS) do
		owned[entry.Id] = ownsSkin(player, entry.Id)
	end
	return owned
end

local function sendUpdate(player)
	local nextEntry = getNextEvolutionEntry(player)
	EvolveSkinUpdate:FireClient(player, {
		Level = getLevel(player),
		Rebirths = getRebirths(player),
		FlashRequiredLevel = FLASH_LEVEL_REQUIRED,
		FlashUnlocked = getLevel(player) >= FLASH_LEVEL_REQUIRED,
		EquippedSkin = player:GetAttribute("EquippedSkin") or "",
		OwnedSkins = collectOwnedSkins(player),
		Skins = INDEX_SKINS,
		NextSkinId = nextEntry and nextEntry.Id or "",
		NextRequiredLevel = nextEntry and nextEntry.RequiredLevel or 0,
		NextRequiredRebirths = nextEntry and (nextEntry.RequiredRebirths or 0) or 0,
	})
end

local function sendIndexUpdate(player, message, playEquipSound, equippedOverride)
	local equippedSkin = equippedOverride
	if equippedSkin == nil then
		equippedSkin = player:GetAttribute("EquippedSkin") or ""
	end

	SkinIndexUpdate:FireClient(player, {
		Skins = INDEX_DISPLAY_SKINS,
		Owned = collectOwnedSkins(player),
		EquippedSkin = equippedSkin,
		Message = message,
		                                                                     
		                                                                        
		PlayEquipSound = false,
	})
end

local function forceFlashStamina(player)
	forceSuitState(player, "FlashSuit")
end

local function forceBaseStamina(player, explicitUnequip)
	if explicitUnequip == true then
		player:SetAttribute("FlashStaminaActive", false)
		player:SetAttribute("FlashStaminaUpgrade", false)
	end
end

local function applyFlashSuit(player)
	local character = player.Character
	if not character then
		return false, "No character"
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return false, "No humanoid"
	end

	if not originalDescriptions[player] then
		local ok, desc = pcall(function()
			return humanoid:GetAppliedDescription():Clone()
		end)

		if ok and desc then
			originalDescriptions[player] = desc
		end
	end

	forceFlashStamina(player)
	removeFlashFallbackObjects(character)
	removeFlashDirectClothing(character)

	local desc = humanoid:GetAppliedDescription()
	removeKnownSpeedsterAssets(desc)

	                                                                        
	                                                             
	applyAssetToDescription(desc, FLASH_HELMET_ID, "HatAccessory")
	applyAssetToDescription(desc, FLASH_SHIRT_ID, "Shirt")
	applyAssetToDescription(desc, FLASH_PANTS_ID, "Pants")

	local ok, err = pcall(function()
		humanoid:ApplyDescription(desc)
	end)

	if not ok then
		warn("[SkinSystem] ApplyDescription failed: " .. tostring(err))
	end

	task.defer(function()
		task.wait(0.35)

		if not player.Character or player.Character ~= character then
			return
		end

		if humanoid.Parent ~= character then
			return
		end

		if player:GetAttribute("EquippedSkin") ~= "FlashSuit" then
			return
		end

		                                            
		forceLoadAccessory(character, humanoid, FLASH_HELMET_ID)

		                                                                           
		                                                                               
		forceClassicClothing(character, FLASH_SHIRT_ID, "Shirt")
		forceClassicClothing(character, FLASH_PANTS_ID, "Pants")
	end)

	forceFlashStamina(player)
	sendUpdate(player)
	return true
end



local function clearReverseAvatarItems(character)
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Accessory")
			or child:IsA("Accoutrement")
			or child:IsA("Shirt")
			or child:IsA("Pants")
			or child:IsA("ShirtGraphic")
			or child:IsA("CharacterMesh") then
			child:Destroy()
		end
	end
end

local function clearReverseDescription(desc)
	        
	                                                                                                 
	                                                                                     
	                               
	for field in pairs(ACCESSORY_FIELDS) do
		safeClearDescriptionField(desc, field)
	end

	for _, field in ipairs({
		"HatAccessory",
		"HairAccessory",
		"FaceAccessory",
		"NeckAccessory",
		"ShoulderAccessory",
		"FrontAccessory",
		"BackAccessory",
		"WaistAccessory",
		"ShirtAccessory",
		"TShirtAccessory",
		"PantsAccessory",
		"JacketAccessory",
		"SweaterAccessory",
		"ShortsAccessory",
		"LeftShoeAccessory",
		"RightShoeAccessory",
		"DressSkirtAccessory",
	}) do
		safeClearDescriptionField(desc, field)
	end

	safeSetDescriptionField(desc, "Shirt", 0)
	safeSetDescriptionField(desc, "Pants", 0)
	safeSetDescriptionField(desc, "GraphicTShirt", 0)
end



local function setClassicClothingTemplate(character, assetId, field)
	local url = "http://www.roblox.com/asset/?id=" .. tostring(assetId)

	if field == "Shirt" then
		local old = character:FindFirstChildOfClass("Shirt")
		if old then
			old:Destroy()
		end

		local shirt = Instance.new("Shirt")
		shirt.Name = "ReverseSpeedsterShirt"
		shirt:SetAttribute("FlashSuitClothing", true)
		shirt.ShirtTemplate = url
		shirt.Parent = character
		return true
	elseif field == "Pants" then
		local old = character:FindFirstChildOfClass("Pants")
		if old then
			old:Destroy()
		end

		local pants = Instance.new("Pants")
		pants.Name = "ReverseSpeedsterPants"
		pants:SetAttribute("FlashSuitClothing", true)
		pants.PantsTemplate = url
		pants.Parent = character
		return true
	end

	return false
end

local function applyReverseDescription(humanoid)
	local desc = humanoid:GetAppliedDescription()
	clearReverseDescription(desc)

	                                           
	                                                                           
	applyAssetToDescription(desc, REVERSE_MASK_ID)

	                                                                        
	safeSetDescriptionField(desc, "Shirt", REVERSE_SHIRT_ID)
	safeSetDescriptionField(desc, "Pants", REVERSE_PANTS_ID)

	local ok, err = pcall(function()
		humanoid:ApplyDescriptionReset(desc)
	end)

	if not ok then
		ok, err = pcall(function()
			humanoid:ApplyDescription(desc)
		end)
	end

	if not ok then
		warn("[SkinSystem] ReverseSpeedsterSuit ApplyDescription/Reset failed: " .. tostring(err))
	end

	return ok
end

local function loadReverseAssetOntoCharacter(character, humanoid, assetId)
	local loaded = cloneCachedLoadedAsset(assetId)
	if not loaded then
		return false
	end

	local applied = false

	for _, inst in ipairs(loaded:GetDescendants()) do
		if inst:IsA("Accessory") then
			local clone = inst:Clone()
			clone:SetAttribute("FlashSuitAccessory", true)
			clone:SetAttribute("SpeedsterCatalogAssetId", assetId)
			clone.Parent = character

			local addOk, addErr = pcall(function()
				humanoid:AddAccessory(clone)
			end)

			if not addOk then
				warn("[SkinSystem] Reverse AddAccessory failed for " .. tostring(assetId) .. ": " .. tostring(addErr))
			else
				applied = true
			end
		elseif inst:IsA("Shirt") then
			local old = character:FindFirstChildOfClass("Shirt")
			if old then
				old:Destroy()
			end

			local clone = inst:Clone()
			clone:SetAttribute("FlashSuitClothing", true)
			clone.Parent = character
			applied = true
		elseif inst:IsA("Pants") then
			local old = character:FindFirstChildOfClass("Pants")
			if old then
				old:Destroy()
			end

			local clone = inst:Clone()
			clone:SetAttribute("FlashSuitClothing", true)
			clone.Parent = character
			applied = true
		elseif inst:IsA("ShirtGraphic") then
			local old = character:FindFirstChildOfClass("ShirtGraphic")
			if old then
				old:Destroy()
			end

			local clone = inst:Clone()
			clone:SetAttribute("FlashSuitClothing", true)
			clone.Parent = character
			applied = true
		end
	end

	loaded:Destroy()
	return applied
end

                                                                           
                                                                           
task.spawn(function()
	for _, entry in ipairs(SuitCatalog.Ordered) do
		for _, fieldName in ipairs({ "MaskId", "HairId", "SuitId", "ShirtId", "PantsId" }) do
			local assetId = tonumber(entry[fieldName])
			if assetId then
				getAssetField(assetId)
				                                                                  
				                                                                 
				                                                      
				if entry.Order <= 2 then
					getCachedLoadedAsset(assetId)
				end
				task.wait()
			end
		end
	end
end)

local function applyReverseDirectClassicClothes(character, humanoid)
	                                                    
	                                                         
	setClassicClothingTemplate(character, REVERSE_SHIRT_ID, "Shirt")
	setClassicClothingTemplate(character, REVERSE_PANTS_ID, "Pants")

	                                                                               
	local maskApplied = loadReverseAssetOntoCharacter(character, humanoid, REVERSE_MASK_ID)
	local shirtApplied = loadReverseAssetOntoCharacter(character, humanoid, REVERSE_SHIRT_ID)
	local pantsApplied = loadReverseAssetOntoCharacter(character, humanoid, REVERSE_PANTS_ID)

	print("[SkinSystem] Reverse direct apply | mask=" .. tostring(maskApplied) .. " shirtAsset=" .. tostring(shirtApplied) .. " pantsAsset=" .. tostring(pantsApplied))
end



local function tryApplyReverseDescription(humanoid, desc)
	local ok, err = pcall(function()
		humanoid:ApplyDescriptionReset(desc)
	end)

	if ok then
		return true
	end

	                                                                             
	local verificationNames = {"Default", "Always", "ClientOnly"}
	for _, enumName in ipairs(verificationNames) do
		local enumValue
		local enumOk = pcall(function()
			enumValue = Enum.AssetTypeVerification[enumName]
		end)

		if enumOk and enumValue then
			ok, err = pcall(function()
				humanoid:ApplyDescriptionReset(desc, enumValue)
			end)

			if ok then
				return true
			end
		end
	end

	ok, err = pcall(function()
		humanoid:ApplyDescription(desc)
	end)

	if ok then
		return true
	end

	for _, enumName in ipairs(verificationNames) do
		local enumValue
		local enumOk = pcall(function()
			enumValue = Enum.AssetTypeVerification[enumName]
		end)

		if enumOk and enumValue then
			ok, err = pcall(function()
				humanoid:ApplyDescription(desc, enumValue)
			end)

			if ok then
				return true
			end
		end
	end

	warn("[SkinSystem] Reverse description apply failed after all methods: " .. tostring(err))
	return false
end

local function applyReverseCatalogDescription(humanoid)
	local desc = humanoid:GetAppliedDescription()
	clearReverseDescription(desc)

	        
	                                                                             
	                                                                                                              
	local maskOk = applyAssetToDescription(desc, REVERSE_MASK_ID)
	local shirtOk = applyAssetToDescription(desc, REVERSE_SHIRT_ID)
	local pantsOk = applyAssetToDescription(desc, REVERSE_PANTS_ID)

	                                                     
	                                          
	if not shirtOk then
		safeSetDescriptionField(desc, "Shirt", REVERSE_SHIRT_ID)
	end

	if not pantsOk then
		safeSetDescriptionField(desc, "Pants", REVERSE_PANTS_ID)
	end

	local applied = tryApplyReverseDescription(humanoid, desc)

	print("[SkinSystem] Reverse auto asset apply | maskOk=" .. tostring(maskOk) .. " shirtOk=" .. tostring(shirtOk) .. " pantsOk=" .. tostring(pantsOk) .. " applied=" .. tostring(applied))

	return applied
end

local function forceReverseClassicClothingObjects(character)
	                                                                                         
	if not character:FindFirstChildOfClass("Shirt") then
		local shirt = Instance.new("Shirt")
		shirt.Name = "ReverseSpeedsterShirtFallback"
		shirt:SetAttribute("FlashSuitClothing", true)
		shirt.ShirtTemplate = "http://www.roblox.com/asset/?id=" .. tostring(REVERSE_SHIRT_ID)
		shirt.Parent = character
	end

	if not character:FindFirstChildOfClass("Pants") then
		local pants = Instance.new("Pants")
		pants.Name = "ReverseSpeedsterPantsFallback"
		pants:SetAttribute("FlashSuitClothing", true)
		pants.PantsTemplate = "http://www.roblox.com/asset/?id=" .. tostring(REVERSE_PANTS_ID)
		pants.Parent = character
	end
end

local function forceCatalogClassicClothingObjects(character, entry)
	if entry.ShirtId and not character:FindFirstChildOfClass("Shirt") then
		local shirt = Instance.new("Shirt")
		shirt.Name = entry.Id .. "ShirtFallback"
		shirt:SetAttribute("FlashSuitClothing", true)
		shirt.ShirtTemplate = "http://www.roblox.com/asset/?id=" .. tostring(entry.ShirtId)
		shirt.Parent = character
	end

	if entry.PantsId and not character:FindFirstChildOfClass("Pants") then
		local pants = Instance.new("Pants")
		pants.Name = entry.Id .. "PantsFallback"
		pants:SetAttribute("FlashSuitClothing", true)
		pants.PantsTemplate = "http://www.roblox.com/asset/?id=" .. tostring(entry.PantsId)
		pants.Parent = character
	end
end

local function hasCatalogAccessory(character, assetId)
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Accessory") then
			if tonumber(child:GetAttribute("SpeedsterCatalogAssetId")) == tonumber(assetId) then
				return true
			end

			local ok, sourceAssetId = pcall(function()
				return child.SourceAssetId
			end)
			if ok and tonumber(sourceAssetId) == tonumber(assetId) then
				return true
			end
		end
	end
	return false
end

local function applyCatalogSuitDescription(humanoid, entry)
	local desc = humanoid:GetAppliedDescription()
	clearReverseDescription(desc)

	local maskOk = entry.MaskId and applyAssetToDescription(desc, entry.MaskId) or true
	local hairOk = entry.HairId and applyAssetToDescription(desc, entry.HairId, "HairAccessory") or true
	local shirtOk = entry.ShirtId and applyAssetToDescription(desc, entry.ShirtId, "Shirt") or true
	local pantsOk = entry.PantsId and applyAssetToDescription(desc, entry.PantsId, "Pants") or true

	if entry.ShirtId and not shirtOk then
		safeSetDescriptionField(desc, "Shirt", entry.ShirtId)
	end
	if entry.PantsId and not pantsOk then
		safeSetDescriptionField(desc, "Pants", entry.PantsId)
	end

	local applied = tryApplyReverseDescription(humanoid, desc)
	print(
		"[SkinSystem] V306CZ catalog apply | skin="
			.. entry.Id
			.. " mask="
			.. tostring(maskOk)
			.. " hair="
			.. tostring(hairOk)
			.. " shirt="
			.. tostring(shirtOk)
			.. " pants="
			.. tostring(pantsOk)
			.. " applied="
			.. tostring(applied)
	)
	return applied
end

local function applyCatalogSuit(player, entry)
	local character = player.Character
	if not character then
		return false, "No character"
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return false, "No humanoid"
	end

	if not originalDescriptions[player] then
		local ok, original = pcall(function()
			return humanoid:GetAppliedDescription():Clone()
		end)
		if ok and original then
			originalDescriptions[player] = original
		end
	end

	forceSuitState(player, entry.Id)
	clearReverseAvatarItems(character)
	removeFlashFallbackObjects(character)
	removeFlashDirectClothing(character)

	local applied = applyCatalogSuitDescription(humanoid, entry)

	local function finishFallback()
		if player.Character ~= character
			or humanoid.Parent ~= character
			or player:GetAttribute("EquippedSkin") ~= entry.Id
		then
			return false
		end
		forceCatalogClassicClothingObjects(character, entry)
		if entry.MaskId and not hasCatalogAccessory(character, entry.MaskId) then
			loadReverseAssetOntoCharacter(character, humanoid, entry.MaskId)
		end
		if entry.HairId and not hasCatalogAccessory(character, entry.HairId) then
			loadReverseAssetOntoCharacter(character, humanoid, entry.HairId)
		end
		return true
	end

	task.defer(function()
		task.wait(0.15)
		finishFallback()
	end)

	task.defer(function()
		for _, delayTime in ipairs({ 0.35, 1.0 }) do
			task.wait(delayTime)
			if not finishFallback() then
				return
			end
			applyCatalogSuitDescription(humanoid, entry)
			task.wait(0.15)
			finishFallback()
		end
	end)

	sendUpdate(player)
	return true
end

local function applyReverseSpeedsterSuit(player)
	local character = player.Character
	if not character then
		return false, "No character"
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return false, "No humanoid"
	end

	if not originalDescriptions[player] then
		local ok, original = pcall(function()
			return humanoid:GetAppliedDescription():Clone()
		end)

		if ok and original then
			originalDescriptions[player] = original
		end
	end

	forceReverseStamina(player)

	                                              
	                                                                                       
	clearReverseAvatarItems(character)
	removeFlashFallbackObjects(character)
	removeFlashDirectClothing(character)

	local applied = applyReverseCatalogDescription(humanoid)

	task.defer(function()
		task.wait(0.15)
		if player.Character == character and humanoid.Parent == character and player:GetAttribute("EquippedSkin") == "ReverseSpeedsterSuit" then
			forceReverseClassicClothingObjects(character)
		end
	end)

	task.defer(function()
		for _, delayTime in ipairs({0.35, 1.0, 2.0}) do
			task.wait(delayTime)

			if not player.Character or player.Character ~= character then
				return
			end

			if humanoid.Parent ~= character then
				return
			end

			if player:GetAttribute("EquippedSkin") ~= "ReverseSpeedsterSuit" then
				return
			end

			                                      
			                                                                 
			applyReverseCatalogDescription(humanoid)

			task.wait(0.15)
			if player.Character == character and humanoid.Parent == character and player:GetAttribute("EquippedSkin") == "ReverseSpeedsterSuit" then
				forceReverseClassicClothingObjects(character)
			end
		end
	end)

	print("[SkinSystem] ReverseSpeedster apply requested | catalogDescription=" .. tostring(applied))
	sendUpdate(player)
	return true
end

local function unequipFlashSuit(player)
	local character = player.Character
	if not character then
		player:SetAttribute("EquippedSkin", "")
		forceBaseStamina(player, true)
		sendUpdate(player)
		return true
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		player:SetAttribute("EquippedSkin", "")
		forceBaseStamina(player, true)
		sendUpdate(player)
		return true
	end

	removeFlashFallbackObjects(character)
	removeFlashDirectClothing(character)

	local desc = originalDescriptions[player]

	if not desc then
		local ok, userDesc = pcall(function()
			return Players:GetHumanoidDescriptionFromUserId(player.UserId)
		end)

		if ok and userDesc then
			desc = userDesc
		end
	end

	if desc then
		local applyOk, applyErr = pcall(function()
			humanoid:ApplyDescription(desc)
		end)

		if not applyOk then
			warn("[SkinSystem] Unequip ApplyDescription failed: " .. tostring(applyErr))
		end
	else
		local current = humanoid:GetAppliedDescription()
		removeAccessoryFromField(current, "HatAccessory", FLASH_HELMET_ID)

		                                                              
		if tostring(safeGetDescriptionField(current, "Shirt") or "") == tostring(FLASH_SHIRT_ID) then
			safeSetDescriptionField(current, "Shirt", 0)
		end
		if tostring(safeGetDescriptionField(current, "Pants") or "") == tostring(FLASH_PANTS_ID) then
			safeSetDescriptionField(current, "Pants", 0)
		end

		pcall(function()
			humanoid:ApplyDescription(current)
		end)
	end

	player:SetAttribute("EquippedSkin", "")
	forceBaseStamina(player, true)
	sendUpdate(player)
	return true
end

local function refreshCosmeticsAfterSkin(player)
	for _, delayTime in ipairs({0, 0.12, 0.45, 1.0}) do
		task.delay(delayTime, function()
			if not player.Parent then
				return
			end
			local cosmetics = _G.SpeedsterCosmetics
			if type(cosmetics) == "table" and type(cosmetics.RefreshPlayer) == "function" then
				cosmetics.RefreshPlayer(player)
			end
		end)
	end
end

local darkZonicDummyCache = nil

local function getDarkZonicDummy(entry)
	if darkZonicDummyCache and darkZonicDummyCache.Parent then
		return darkZonicDummyCache
	end

	local targetName = tostring(entry.SourceModelName or "DarkZonic")
	local found = Workspace:FindFirstChild(targetName, true)
	if found and found:IsA("Model") and found:FindFirstChildOfClass("Humanoid") then
		darkZonicDummyCache = found
		return found
	end

	return nil
end

local function cloneDummyAppearanceOntoCharacter(character, humanoid, source)
	clearReverseAvatarItems(character)
	removeFlashFallbackObjects(character)
	removeFlashDirectClothing(character)

	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Shirt") or child:IsA("Pants") or child:IsA("ShirtGraphic") then
			child:Destroy()
		end
	end

	local oldBodyColors = character:FindFirstChildOfClass("BodyColors")
	if oldBodyColors then
		oldBodyColors:Destroy()
	end
	local sourceBodyColors = source:FindFirstChildOfClass("BodyColors")
	if sourceBodyColors then
		sourceBodyColors:Clone().Parent = character
	end

	for _, partName in ipairs({ "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }) do
		local sourcePart = source:FindFirstChild(partName)
		local targetPart = character:FindFirstChild(partName)
		if sourcePart and sourcePart:IsA("BasePart") and targetPart and targetPart:IsA("BasePart") then
			targetPart.Color = sourcePart.Color
			targetPart.Material = sourcePart.Material
			targetPart.Reflectance = sourcePart.Reflectance
			targetPart.Transparency = sourcePart.Transparency
			for _, old in ipairs(targetPart:GetChildren()) do
				if old:IsA("Decal") or old:IsA("Texture") then
					old:Destroy()
				end
			end
			for _, visual in ipairs(sourcePart:GetChildren()) do
				if visual:IsA("Decal") or visual:IsA("Texture") then
					visual:Clone().Parent = targetPart
				end
			end
		end
	end
end

local function setDarkZonicNeckSpacing(model, enabled)
	if not model then
		return
	end
	local torso = model:FindFirstChild("Torso")
	local neck = torso and torso:FindFirstChild("Neck")
	if not neck or not neck:IsA("Motor6D") then
		return
	end
	local base = neck:GetAttribute("DarkZonicBaseC0")
	if typeof(base) ~= "CFrame" then
		base = neck.C0
		neck:SetAttribute("DarkZonicBaseC0", base)
	end
	neck.C0 = enabled and (base * CFrame.new(0, 0.22, 0)) or base
end

local function applyDarkZonicCatalogLook(model, entry)
	if not model or not model.Parent then
		return false
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return false
	end

	for _, child in ipairs(model:GetChildren()) do
		if child:IsA("Shirt") or child:IsA("Pants") or child:IsA("ShirtGraphic") then
			child:Destroy()
		elseif child:IsA("Accessory") or child:IsA("Accoutrement") then
			local sourceAssetId = 0
			pcall(function()
				sourceAssetId = tonumber(child.SourceAssetId) or 0
			end)
			if sourceAssetId == tonumber(entry.MaskId) then
				child:Destroy()
			end
		end
	end

	local ok, desc = pcall(function()
		return humanoid:GetAppliedDescription():Clone()
	end)
	if not ok or not desc then
		return false
	end
	if tonumber(entry.ShirtId) then
		safeSetDescriptionField(desc, "Shirt", tonumber(entry.ShirtId))
	end
	if tonumber(entry.PantsId) then
		safeSetDescriptionField(desc, "Pants", tonumber(entry.PantsId))
	end
	if tonumber(entry.MaskId) then
		for field in pairs(ACCESSORY_FIELDS) do
			removeAccessoryFromField(desc, field, tonumber(entry.MaskId))
		end
		applyAssetToDescription(desc, tonumber(entry.MaskId))
	end
	local applied = pcall(function()
		humanoid:ApplyDescription(desc)
	end)
	desc:Destroy()
	if applied then
		setDarkZonicNeckSpacing(model, true)
	end
	return applied
end

local function applyWorkspaceDummySuit(player, entry)
	local character = player.Character
	if not character then
		return false, "No character"
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return false, "No humanoid"
	end

	local source = getDarkZonicDummy(entry)
	if not source then
		return false, "DarkZonic dummy missing"
	end

	if not originalDescriptions[player] then
		local ok, original = pcall(function()
			return humanoid:GetAppliedDescription():Clone()
		end)
		if ok and original then
			originalDescriptions[player] = original
		end
	end

	forceSuitState(player, entry.Id)

	setDarkZonicNeckSpacing(character, false)
	cloneDummyAppearanceOntoCharacter(character, humanoid, source)
	applyDarkZonicCatalogLook(character, entry)
	return true
end

local function applySkinById(player, skinId)
	local applied
	local message
	local entry = SuitCatalog.Get(skinId)
	if skinId ~= "DarkZonicSuit" and player.Character then
		setDarkZonicNeckSpacing(player.Character, false)
	end

	if not entry then
		return false, "Unknown skin"
	elseif entry.SpecialApplyMode == "WorkspaceDummy" then
		applied, message = applyWorkspaceDummySuit(player, entry)
	elseif skinId == "FlashSuit" then
		                                                                        
		                                                                       
		                                                              
		applied, message = applyCatalogSuit(player, entry)
	elseif skinId == "ReverseSpeedsterSuit" then
		applied, message = applyReverseSpeedsterSuit(player)
	else
		applied, message = applyCatalogSuit(player, entry)
	end

	if applied then
		lastAppliedCharacter[player] = player.Character
		lastAppliedSkin[player] = skinId
		refreshCosmeticsAfterSkin(player)
	end

	return applied, message
end

local function waitForDataLoaded(player)
	for _ = 1, 120 do
		if not player.Parent then
			return false
		end
		if player:GetAttribute("DataLoaded") == true then
			return true
		end
		task.wait(0.25)
	end

	return false
end

local function applySavedSkin(player)
	local skinId = tostring(player:GetAttribute("EquippedSkin") or "")
	local character = player.Character

	if applyingSavedSkin[player] then
		return
	end

	if lastAppliedCharacter[player] == character
		and lastAppliedSkin[player] == skinId
	then
		sendUpdate(player)
		sendIndexUpdate(player)
		return
	end

	applyingSavedSkin[player] = true

	if not SuitCatalog.IsValid(skinId) then
		skinId = SuitCatalog.DefaultSkinId or "FlashSuit"
		player:SetAttribute("EquippedSkin", skinId)
	end

	                                                                     
	                                                                           
	                                                                            
	unlockSkin(player, SuitCatalog.DefaultSkinId or "FlashSuit")
	unlockSkin(player, skinId)
	applySkinById(player, skinId)

	applyingSavedSkin[player] = nil
	sendUpdate(player)
	sendIndexUpdate(player)
end

EquipSkin.OnServerEvent:Connect(function(player, skinId)
	if type(skinId) ~= "string"
		or player:GetAttribute("DataLoaded") ~= true
		or evolveInProgress[player]
	then
		sendUpdate(player)
		return
	end

	if skinId == "UnequipFlashSuit" then
		unequipFlashSuit(player)
		forceBaseStamina(player, true)
		refreshCosmeticsAfterSkin(player)
		saveSkinState(player, "skin_unequip")
		sendIndexUpdate(player)
		return
	end

	local expectedEntry = getNextEvolutionEntry(player)
	if not expectedEntry or skinId ~= expectedEntry.Id then
		sendUpdate(player)
		sendIndexUpdate(player, "Use Evolve in order, or equip an owned skin from Index")
		return
	end

	local requiredLevel = math.max(0, math.floor(tonumber(expectedEntry.RequiredLevel) or 0))
	local requiredRebirths = math.max(0, math.floor(tonumber(expectedEntry.RequiredRebirths) or 0))
	local currentLevel = getLevel(player)
	local currentRebirths = getRebirths(player)

	if currentLevel < requiredLevel or currentRebirths < requiredRebirths then
		sendUpdate(player)

		local message
		if currentLevel < requiredLevel and currentRebirths < requiredRebirths then
			message = "Reach Level "
				.. tostring(requiredLevel)
				.. " and "
				.. tostring(requiredRebirths)
				.. (requiredRebirths == 1 and " Rebirth" or " Rebirths")
				.. " to evolve"
		elseif currentLevel < requiredLevel then
			message = "Reach Level " .. tostring(requiredLevel) .. " to evolve"
		else
			message = "Need "
				.. tostring(requiredRebirths)
				.. (requiredRebirths == 1 and " Rebirth" or " Rebirths")
				.. " to evolve"
		end

		sendIndexUpdate(player, message)
		return
	end

	evolveInProgress[player] = true
	local applyOk, applied = pcall(applySkinById, player, skinId)
	if not applyOk then
		warn("[SkinSystem] Evolve apply failed safely: " .. tostring(applied))
		applied = false
	end
	if applied then
		unlockSkin(player, skinId)
		saveSkinState(player, "evolve_skin")
		evolveInProgress[player] = nil
		sendIndexUpdate(player, "Unlocked and equipped")
	else
		evolveInProgress[player] = nil
		sendIndexUpdate(player, "Character is not ready")
	end
end)

SkinIndexRequest.OnServerEvent:Connect(function(player, action, skinId)
	if action == "RequestState" then
		if player:GetAttribute("DataLoaded") == true then
			sendIndexUpdate(player)
		end
		return
	end

	if action ~= "Equip"
		or player:GetAttribute("DataLoaded") ~= true
		or type(skinId) ~= "string"
		or not VALID_INDEX_SKINS[skinId]
	then
		return
	end

	if not ownsSkin(player, skinId) then
		sendIndexUpdate(player, "That skin is still locked")
		return
	end
	if evolveInProgress[player] then
		sendIndexUpdate(player, "A skin is already being equipped")
		return
	end

	evolveInProgress[player] = true

	                                                                          
	                                                                     
	sendIndexUpdate(player, "Equipping...", false, skinId)

	task.spawn(function()
		if not player.Parent then
			evolveInProgress[player] = nil
			return
		end

		local applyOk, applied = pcall(applySkinById, player, skinId)
		if not applyOk then
			warn("[SkinSystem] Index apply failed safely: " .. tostring(applied))
			applied = false
		end
		if applied then
			saveSkinState(player, "index_skin_equip")
			evolveInProgress[player] = nil
			sendIndexUpdate(player, "Equipped")
		else
			evolveInProgress[player] = nil
			sendIndexUpdate(player, "Character is not ready")
		end
	end)
end)

local function connectOwnedSkinUpdates(player)
	local folder = getOwnedSkinsFolder(player)
	if not folder then
		return
	end

	folder.ChildAdded:Connect(function()
		if player.Parent then
			sendUpdate(player)
			sendIndexUpdate(player)
		end
	end)

	folder.ChildRemoved:Connect(function()
		if player.Parent then
			sendUpdate(player)
			sendIndexUpdate(player)
		end
	end)
end

local DARK_ZONIC_SKIN_ID = "DarkZonicSuit"
local DARK_ZONIC_PASS_ID = tonumber(Config.DarkZonicGamePassId) or 1963032723
local DARK_ZONIC_LIMIT = math.max(1, math.floor(tonumber(Config.DarkZonicLimitedTotal) or 370))
local DARK_ZONIC_STORE_KEY = "DarkZonicStock"
local DARK_ZONIC_RESERVATION_SECONDS = 120
local darkZonicStore = DataStoreService:GetDataStore("SpeedsterEscape_DarkZonicLimited_v1")
local darkZonicMemoryState = { Sold = 0, Owners = {}, Reservations = {} }
local darkZonicBillboard = nil
local darkZonicPrompt = nil
local darkZonicLastState = nil
local darkZonicPendingReservations = {}

local function normalizeDarkZonicState(data)
	if type(data) ~= "table" then
		data = {}
	end
	if type(data.Owners) ~= "table" then
		data.Owners = {}
	end
	if type(data.Reservations) ~= "table" then
		data.Reservations = {}
	end
	local now = os.time()
	for userId, expiresAt in pairs(data.Reservations) do
		if tonumber(expiresAt) == nil or tonumber(expiresAt) <= now or data.Owners[tostring(userId)] == true then
			data.Reservations[userId] = nil
		end
	end
	local sold = 0
	for _, owned in pairs(data.Owners) do
		if owned == true then
			sold += 1
		end
	end
	data.Sold = math.clamp(sold, 0, DARK_ZONIC_LIMIT)
	return data
end

local function countDarkZonicReservations(data)
	local count = 0
	for _ in pairs(data.Reservations or {}) do
		count += 1
	end
	return count
end

local function getDarkZonicAvailable(data)
	data = normalizeDarkZonicState(data)
	return math.max(0, DARK_ZONIC_LIMIT - data.Sold - countDarkZonicReservations(data))
end

local function publishDarkZonicState(data)
	data = normalizeDarkZonicState(data)
	darkZonicLastState = data
	local available = getDarkZonicAvailable(data)
	if darkZonicBillboard and darkZonicBillboard.Parent then
		for _, descendant in ipairs(darkZonicBillboard:GetDescendants()) do
			if descendant:IsA("TextLabel") and descendant.Name == "Stock" then
				descendant.Text = tostring(available) .. "/" .. tostring(DARK_ZONIC_LIMIT)
			end
		end
	end
	if darkZonicPrompt and darkZonicPrompt.Parent then
		darkZonicPrompt.ActionText = available > 0 and "Buy / Equip" or "Equip / Sold Out"
	end
	if not RunService:IsStudio() then
		pcall(function()
			MessagingService:PublishAsync("DarkZonicLimitedStock_v1", { Available = available })
		end)
	end
end

local function updateDarkZonicState(mutator)
	if RunService:IsStudio() then
		darkZonicMemoryState = normalizeDarkZonicState(darkZonicMemoryState)
		mutator(darkZonicMemoryState)
		darkZonicMemoryState = normalizeDarkZonicState(darkZonicMemoryState)
		publishDarkZonicState(darkZonicMemoryState)
		return darkZonicMemoryState, true
	end

	local ok, result = pcall(function()
		return darkZonicStore:UpdateAsync(DARK_ZONIC_STORE_KEY, function(data)
			data = normalizeDarkZonicState(data)
			mutator(data)
			return normalizeDarkZonicState(data)
		end)
	end)
	if ok and type(result) == "table" then
		publishDarkZonicState(result)
		return result, true
	end
	warn("[DarkZonicLimited] Stock update failed: " .. tostring(result))
	return darkZonicLastState, false
end

local function readDarkZonicState()
	if RunService:IsStudio() then
		darkZonicMemoryState = normalizeDarkZonicState(darkZonicMemoryState)
		publishDarkZonicState(darkZonicMemoryState)
		return darkZonicMemoryState
	end
	local ok, result = pcall(function()
		return darkZonicStore:GetAsync(DARK_ZONIC_STORE_KEY)
	end)
	if ok then
		result = normalizeDarkZonicState(result)
		publishDarkZonicState(result)
		return result
	end
	warn("[DarkZonicLimited] Stock read failed: " .. tostring(result))
	return darkZonicLastState
end

local function reserveDarkZonic(userId)
	local uid = tostring(userId)
	local status = "error"
	local state, ok = updateDarkZonicState(function(data)
		if data.Owners[uid] == true then
			status = "owned"
			return
		end
		if data.Reservations[uid] ~= nil then
			data.Reservations[uid] = os.time() + DARK_ZONIC_RESERVATION_SECONDS
			status = "reserved"
			return
		end
		if getDarkZonicAvailable(data) <= 0 then
			status = "soldout"
			return
		end
		data.Reservations[uid] = os.time() + DARK_ZONIC_RESERVATION_SECONDS
		status = "reserved"
	end)
	if not ok then
		return "error", state
	end
	if status == "reserved" then
		darkZonicPendingReservations[userId] = true
	end
	return status, state
end

local function releaseDarkZonicReservation(userId)
	if darkZonicPendingReservations[userId] ~= true then
		return
	end
	darkZonicPendingReservations[userId] = nil
	local uid = tostring(userId)
	updateDarkZonicState(function(data)
		data.Reservations[uid] = nil
	end)
end

local function finalizeDarkZonicReservation(userId)
	darkZonicPendingReservations[userId] = nil
	local uid = tostring(userId)
	local granted = false
	local state, ok = updateDarkZonicState(function(data)
		if data.Owners[uid] == true then
			data.Reservations[uid] = nil
			granted = true
			return
		end
		if data.Reservations[uid] == nil then
			return
		end
		if data.Sold >= DARK_ZONIC_LIMIT then
			data.Reservations[uid] = nil
			return
		end
		data.Reservations[uid] = nil
		data.Owners[uid] = true
		granted = true
	end)
	return granted and ok, state
end

local function claimExistingDarkZonicOwner(userId)
	local uid = tostring(userId)
	local granted = false
	local state, ok = updateDarkZonicState(function(data)
		if data.Owners[uid] == true then
			granted = true
			return
		end
		if getDarkZonicAvailable(data) <= 0 then
			return
		end
		data.Owners[uid] = true
		granted = true
	end)
	return granted and ok, state
end

local function equipDarkZonic(player)
	if not player.Parent or player:GetAttribute("DataLoaded") ~= true then
		return false
	end
	if not ownsSkin(player, DARK_ZONIC_SKIN_ID) then
		return false
	end
	local ok, applied = pcall(applySkinById, player, DARK_ZONIC_SKIN_ID)
	if ok and applied then
		saveSkinState(player, "dark_zonic_equip")
		sendUpdate(player)
		sendIndexUpdate(player, "Dark Zonic equipped")
		return true
	end
	return false
end

local function grantDarkZonic(player)
	if not player.Parent or player:GetAttribute("DataLoaded") ~= true then
		return false
	end
	if not unlockSkin(player, DARK_ZONIC_SKIN_ID) then
		return false
	end
	saveSkinState(player, "dark_zonic_unlock")
	return equipDarkZonic(player)
end

local function playerOwnsDarkZonicPass(player)
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, DARK_ZONIC_PASS_ID)
	end)
	return ok and owns == true
end

local function tryClaimOwnedDarkZonicPass(player)
	if ownsSkin(player, DARK_ZONIC_SKIN_ID) then
		return true
	end
	if not playerOwnsDarkZonicPass(player) then
		return false
	end
	local granted = claimExistingDarkZonicOwner(player.UserId)
	if granted then
		grantDarkZonic(player)
	end
	return granted
end

local function createDarkZonicPresentation()
	local entry = SuitCatalog.Get(DARK_ZONIC_SKIN_ID)
	if not entry then
		return
	end
	local dummy = getDarkZonicDummy(entry)
	if not dummy then
		warn("[DarkZonicLimited] Workspace.DarkZonic R6 dummy was not found")
		return
	end
	applyDarkZonicCatalogLook(dummy, entry)
	local head = dummy:FindFirstChild("Head")
	local adornee = head or dummy:FindFirstChild("Torso") or dummy:FindFirstChild("HumanoidRootPart")
	if not adornee or not adornee:IsA("BasePart") then
		warn("[DarkZonicLimited] DarkZonic has no usable Head/Torso/RootPart")
		return
	end

	local oldGui = dummy:FindFirstChild("DarkZonicLimitedBillboard")
	if oldGui then
		oldGui:Destroy()
	end
	local oldPrompt = adornee:FindFirstChild("DarkZonicLimitedPrompt")
	if oldPrompt then
		oldPrompt:Destroy()
	end

	local facingPart = dummy:FindFirstChild("HumanoidRootPart") or dummy:FindFirstChild("Torso") or adornee
	local look = Vector3.new(facingPart.CFrame.LookVector.X, 0, facingPart.CFrame.LookVector.Z)
	if look.Magnitude < 0.001 then
		look = Vector3.new(0, 0, -1)
	else
		look = look.Unit
	end
	local headTopY = adornee.Position.Y + adornee.Size.Y * 0.5
	local signWidth = 10.5
	local signHeight = 4.2
	local signPosition = Vector3.new(adornee.Position.X, headTopY + 0.28 + signHeight * 0.5, adornee.Position.Z)

	local sign = Instance.new("Part")
	sign.Name = "DarkZonicLimitedBillboard"
	sign.Anchored = true
	sign.CanCollide = false
	sign.CanTouch = false
	sign.CanQuery = false
	sign.CastShadow = false
	sign.Massless = true
	sign.Transparency = 1
	sign.Size = Vector3.new(signWidth, signHeight, 0.05)
	sign.CFrame = CFrame.lookAt(signPosition, signPosition + look, Vector3.yAxis)
	sign.Parent = dummy

	local function addStroke(label, thickness, color)
		local stroke = Instance.new("UIStroke")
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		stroke.Color = color
		stroke.Thickness = thickness
		stroke.LineJoinMode = Enum.LineJoinMode.Round
		stroke.Parent = label
	end

	local function createTextSurface(face)
		local surface = Instance.new("SurfaceGui")
		surface.Name = "DarkZonicLimitedSurface"
		surface.Adornee = sign
		surface.Face = face
		surface.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		surface.CanvasSize = Vector2.new(360, 144)
		surface.AlwaysOnTop = false
		surface.LightInfluence = 0
		surface.MaxDistance = 0
		surface.ZOffset = 0.01
		surface.Parent = sign

		local stock = Instance.new("TextLabel")
		stock.Name = "Stock"
		stock.BackgroundTransparency = 1
		stock.Position = UDim2.fromOffset(0, 0)
		stock.Size = UDim2.fromOffset(360, 32)
		stock.Font = Enum.Font.GothamBlack
		stock.Text = tostring(DARK_ZONIC_LIMIT) .. "/" .. tostring(DARK_ZONIC_LIMIT)
		stock.TextColor3 = Color3.fromRGB(0, 0, 0)
		stock.TextSize = 27
		stock.TextScaled = false
		stock.TextXAlignment = Enum.TextXAlignment.Center
		stock.TextYAlignment = Enum.TextYAlignment.Center
		stock.Parent = surface
		addStroke(stock, 2, Color3.fromRGB(255, 255, 255))

		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.BackgroundTransparency = 1
		title.Position = UDim2.fromOffset(0, 30)
		title.Size = UDim2.fromOffset(360, 68)
		title.Font = Enum.Font.GothamBlack
		title.Text = "DARK ZONIC"
		title.TextColor3 = Color3.fromRGB(255, 255, 255)
		title.TextSize = 52
		title.TextScaled = false
		title.TextXAlignment = Enum.TextXAlignment.Center
		title.TextYAlignment = Enum.TextYAlignment.Center
		title.Parent = surface
		addStroke(title, 4, Color3.fromRGB(0, 0, 0))
		local titleGradient = Instance.new("UIGradient")
		titleGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 45, 45)),
			ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 220, 40)),
			ColorSequenceKeypoint.new(0.34, Color3.fromRGB(65, 255, 70)),
			ColorSequenceKeypoint.new(0.51, Color3.fromRGB(35, 235, 255)),
			ColorSequenceKeypoint.new(0.68, Color3.fromRGB(70, 95, 255)),
			ColorSequenceKeypoint.new(0.84, Color3.fromRGB(210, 55, 255)),
			ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 45, 115)),
		})
		titleGradient.Parent = title

		local stat = Instance.new("TextLabel")
		stat.Name = "Stat"
		stat.BackgroundTransparency = 1
		stat.Position = UDim2.fromOffset(0, 96)
		stat.Size = UDim2.fromOffset(360, 44)
		stat.Font = Enum.Font.GothamBlack
		stat.Text = "300x"
		stat.TextColor3 = Color3.fromRGB(255, 35, 35)
		stat.TextSize = 34
		stat.TextScaled = false
		stat.TextXAlignment = Enum.TextXAlignment.Center
		stat.TextYAlignment = Enum.TextYAlignment.Center
		stat.Parent = surface
		addStroke(stat, 3, Color3.fromRGB(0, 0, 0))
	end

	createTextSurface(Enum.NormalId.Front)
	createTextSurface(Enum.NormalId.Back)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "DarkZonicLimitedPrompt"
	prompt.ActionText = "Buy / Equip"
	prompt.ObjectText = "Dark Zonic Limited"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = adornee

	darkZonicBillboard = sign
	darkZonicPrompt = prompt

	prompt.Triggered:Connect(function(player)
		if player:GetAttribute("DataLoaded") ~= true then
			return
		end
		if ownsSkin(player, DARK_ZONIC_SKIN_ID) then
			equipDarkZonic(player)
			return
		end
		if playerOwnsDarkZonicPass(player) then
			local granted = claimExistingDarkZonicOwner(player.UserId)
			if granted then
				grantDarkZonic(player)
			end
			return
		end

		local status = reserveDarkZonic(player.UserId)
		if status ~= "reserved" then
			return
		end
		local ok = pcall(function()
			MarketplaceService:PromptGamePassPurchase(player, DARK_ZONIC_PASS_ID)
		end)
		if not ok then
			releaseDarkZonicReservation(player.UserId)
		end
	end)

	readDarkZonicState()
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, wasPurchased)
	if tonumber(gamePassId) ~= DARK_ZONIC_PASS_ID then
		return
	end
	if wasPurchased == true then
		task.spawn(function()
			for attempt = 1, 5 do
				local granted = finalizeDarkZonicReservation(player.UserId)
				if granted then
					grantDarkZonic(player)
					return
				end
				if attempt < 5 then
					task.wait(attempt * 1.5)
				end
			end
		end)
	else
		releaseDarkZonicReservation(player.UserId)
	end
end)

if not RunService:IsStudio() then
	pcall(function()
		MessagingService:SubscribeAsync("DarkZonicLimitedStock_v1", function(message)
			local data = message.Data
			if type(data) == "table" and tonumber(data.Available) ~= nil then
				local available = math.clamp(math.floor(tonumber(data.Available)), 0, DARK_ZONIC_LIMIT)
				if darkZonicBillboard and darkZonicBillboard.Parent then
					for _, descendant in ipairs(darkZonicBillboard:GetDescendants()) do
						if descendant:IsA("TextLabel") and descendant.Name == "Stock" then
							descendant.Text = tostring(available) .. "/" .. tostring(DARK_ZONIC_LIMIT)
						end
					end
				end
				if darkZonicPrompt and darkZonicPrompt.Parent then
					darkZonicPrompt.ActionText = available > 0 and "Buy / Equip" or "Equip / Sold Out"
				end
			end
		end)
	end)
end

task.defer(createDarkZonicPresentation)

local function setupPlayer(player)
	player:GetAttributeChangedSignal("Level"):Connect(function()
		if player:GetAttribute("DataLoaded") == true then
			sendUpdate(player)
		end
	end)

	player:GetAttributeChangedSignal("EquippedSkin"):Connect(function()
		if player:GetAttribute("DataLoaded") == true then
			sendUpdate(player)
			sendIndexUpdate(player)
		end
	end)

	player.CharacterAdded:Connect(function(character)
		task.spawn(function()
			if not waitForDataLoaded(player) then
				return
			end

			task.wait(1)
			if player.Parent and player.Character == character then
				applySavedSkin(player)
			end
		end)
	end)

	task.spawn(function()
		if not waitForDataLoaded(player) then
			return
		end

		connectOwnedSkinUpdates(player)
		tryClaimOwnedDarkZonicPass(player)

		if player.Character then
			task.wait(1)
			if player.Parent then
				applySavedSkin(player)
			end
		else
			sendUpdate(player)
			sendIndexUpdate(player)
		end
	end)
end

Players.PlayerAdded:Connect(setupPlayer)

for _, player in ipairs(Players:GetPlayers()) do
	task.defer(setupPlayer, player)
end

Players.PlayerRemoving:Connect(function(player)
	releaseDarkZonicReservation(player.UserId)
	originalDescriptions[player] = nil
	lastAppliedCharacter[player] = nil
	lastAppliedSkin[player] = nil
	applyingSavedSkin[player] = nil
	evolveInProgress[player] = nil
end)

print("[SkinSystem] V306KCD loaded. Dark Zonic world-space sign, clean outfit, neck spacing, auto-equip, and Index ownership active.")
