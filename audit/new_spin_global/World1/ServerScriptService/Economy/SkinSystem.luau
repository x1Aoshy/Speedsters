local RemoteGuard = require(game:GetService("ServerScriptService").Services.RemoteGuard)
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
local ModularData = Config.UseModularDataService and require(game:GetService("ServerScriptService").Services.Data.DataService) or nil
local HttpService = game:GetService("HttpService")

local ownsSkin

local function persistSkinSelection(player, skinId, grant)
	if not ModularData then return true end
	local handle = ModularData.GetHandle(player.UserId)
	if not handle then return false end
	local commands = {}
	local shouldGrant = grant == true or skinId == "FlashSuit" or (type(ownsSkin) == "function" and ownsSkin(player, skinId))
	if shouldGrant then
		table.insert(commands, { kind = "GrantSkin", skinId = skinId })
	end
	table.insert(commands, { kind = "EquipSkin", skinId = skinId })
	local result = ModularData.Commit(handle, {
		operationId = HttpService:GenerateGUID(false), fingerprint = "equip:" .. skinId, commands = commands,
	})
	return result.kind == "Committed" or result.kind == "AlreadyCommitted"
end

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
-- Defined with the rig outfits and the Silver Surfer's board, used before them.
local clearRigOutfit, clearSurfboard
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
		PreviewRig = entry.PreviewRig,
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

for _, entry in ipairs(SuitCatalog.Exclusive or {}) do
	table.insert(INDEX_DISPLAY_SKINS, {
		Id = entry.Id,
		DisplayName = entry.DisplayName,
		PreviewAssetId = entry.PreviewAssetId,
		PreviewRig = entry.PreviewRig,
		RequiredLevel = 0,
		RequiredRebirths = 0,
		Stamina = entry.Stamina,
		-- Where it is won; the Index shows it locked with this until then.
		Exclusive = entry.Exclusive,
		Rarity = entry.Rarity,
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
		local numericId = tonumber(assetId)
		if numericId and numericId > 0 then
			info = MarketplaceService:GetProductInfo(numericId, Enum.InfoType.Asset)
		else
			error("Invalid assetId: " .. tostring(assetId))
		end
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

-- Whether an asset is already in the cache (no web call, no yield).
local function isAssetCached(assetId)
	local cached = cachedLoadedAssets[assetId]
	if cached and cached.Parent then
		return true
	end
	local existing = skinAssetCacheFolder:FindFirstChild("Asset_" .. tostring(assetId))
	if existing then
		cachedLoadedAssets[assetId] = existing
		return true
	end
	return false
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

			local addOk, addErr = pcall(function()
				humanoid:AddAccessory(child)
			end)

			if not addOk then
				-- Fallback if AddAccessory fails
				child.Parent = character
			end
			added = true
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

----------------------------------------------------------------------
-- The skin tone a suit is worn in
----------------------------------------------------------------------
-- A suit's own tone (SkinColorRGB: the Silver Surfer's silver), or else the player's own
-- avatar colours, back after a skin that changed them (a rig outfit, the silver).
local DESCRIPTION_COLOR_FIELDS = { "HeadColor", "TorsoColor", "LeftArmColor", "RightArmColor", "LeftLegColor", "RightLegColor" }

local function setDescriptionColors(desc, color)
	for _, field in ipairs(DESCRIPTION_COLOR_FIELDS) do
		safeSetDescriptionField(desc, field, color)
	end
end

local function applySuitColors(desc, entry, humanoid)
	local rgb = entry and entry.SkinColorRGB
	if type(rgb) == "table" then
		setDescriptionColors(desc, Color3.fromRGB(tonumber(rgb[1]) or 200, tonumber(rgb[2]) or 200, tonumber(rgb[3]) or 200))
		return
	end
	local player = humanoid and Players:GetPlayerFromCharacter(humanoid.Parent)
	local original = player and originalDescriptions[player]
	if original then
		for _, field in ipairs(DESCRIPTION_COLOR_FIELDS) do
			local value = safeGetDescriptionField(original, field)
			if typeof(value) == "Color3" then
				safeSetDescriptionField(desc, field, value)
			end
		end
	end
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

			local addOk, addErr = pcall(function()
				humanoid:AddAccessory(clone)
			end)

			if not addOk then
				clone.Parent = character
			end
			applied = true
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
				-- Only a mask or suit can be any accessory type. Hair, shirts and pants are
				-- always applied with their field named, so asking Marketplace what they
				-- are was a wasted web call per server - and a startup warning whenever
				-- Marketplace refuses to describe a classic clothing asset.
				if fieldName == "MaskId" or fieldName == "SuitId" then
					getAssetField(assetId)
				end
				                                                                  
				                                                                 
				                                                      
				if entry.Order <= 2 then
					getCachedLoadedAsset(assetId)
				end
				task.wait()
			end
		end
	end
	-- Every suit's accessories (masks, hair, the Silver Surfer's pieces) into the cache, so
	-- they go on the moment a suit is put on instead of waiting on a web call each time
	-- (they came late, or not at all, when the avatar description's own download was slow).
	for _, collection in ipairs({ SuitCatalog.Ordered, SuitCatalog.Limited or {}, SuitCatalog.Exclusive or {} }) do
		for _, entry in ipairs(collection) do
			local ids = { tonumber(entry.MaskId), tonumber(entry.HairId) }
			for _, accessory in ipairs(entry.Accessories or {}) do
				table.insert(ids, tonumber(accessory.Id))
			end
			for index = 1, 2 + #(entry.Accessories or {}) do
				local assetId = ids[index]
				if assetId and not isAssetCached(assetId) then
					getCachedLoadedAsset(assetId)
					task.wait(0.1)
				end
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
	local shirtOk = applyAssetToDescription(desc, REVERSE_SHIRT_ID, "Shirt")
	local pantsOk = applyAssetToDescription(desc, REVERSE_PANTS_ID, "Pants")

	                                                     
	                                          
	if not shirtOk then
		safeSetDescriptionField(desc, "Shirt", REVERSE_SHIRT_ID)
	end

	if not pantsOk then
		safeSetDescriptionField(desc, "Pants", REVERSE_PANTS_ID)
	end
	applySuitColors(desc, nil, humanoid)

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
	if entry.ShirtId then
		local expectedTemplate = "http://www.roblox.com/asset/?id=" .. tostring(entry.ShirtId)
		local shirt = character:FindFirstChildOfClass("Shirt")
		if not shirt then
			shirt = Instance.new("Shirt")
			shirt.Name = entry.Id .. "ShirtFallback"
			shirt:SetAttribute("FlashSuitClothing", true)
			shirt.ShirtTemplate = expectedTemplate
			shirt.Parent = character
		elseif shirt.ShirtTemplate ~= expectedTemplate and (shirt:GetAttribute("FlashSuitClothing") or not character:FindFirstChild("HumanoidRootPart")) then
			shirt.ShirtTemplate = expectedTemplate
		end
	end

	if entry.PantsId then
		local expectedTemplate = "http://www.roblox.com/asset/?id=" .. tostring(entry.PantsId)
		local pants = character:FindFirstChildOfClass("Pants")
		if not pants then
			pants = Instance.new("Pants")
			pants.Name = entry.Id .. "PantsFallback"
			pants:SetAttribute("FlashSuitClothing", true)
			pants.PantsTemplate = expectedTemplate
			pants.Parent = character
		elseif pants.PantsTemplate ~= expectedTemplate and (pants:GetAttribute("FlashSuitClothing") or not character:FindFirstChild("HumanoidRootPart")) then
			pants.PantsTemplate = expectedTemplate
		end
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

-- A catalog suit's accessories: its mask, its hair, and any pieces it lists.
local function suitAccessories(entry)
	local list = {}
	if tonumber(entry.MaskId) then
		table.insert(list, { Id = tonumber(entry.MaskId) })
	end
	if tonumber(entry.HairId) then
		table.insert(list, { Id = tonumber(entry.HairId), Field = "HairAccessory" })
	end
	for _, accessory in ipairs(entry.Accessories or {}) do
		if tonumber(accessory.Id) then
			table.insert(list, { Id = tonumber(accessory.Id), Field = accessory.Field })
		end
	end
	return list
end

-- Puts on, from the cache, every accessory of the suit it does not wear yet. Never waits:
-- an accessory not cached yet is left to the description and to finishFallback.
local function wearCachedSuitAccessories(character, humanoid, entry)
	for _, accessory in ipairs(suitAccessories(entry)) do
		if isAssetCached(accessory.Id) and not hasCatalogAccessory(character, accessory.Id) then
			loadReverseAssetOntoCharacter(character, humanoid, accessory.Id)
		end
	end
end

local function applyCatalogSuitDescription(humanoid, entry)
	local desc = humanoid:GetAppliedDescription()
	clearReverseDescription(desc)

	-- Accessories already in the cache are worn from it (wearCachedSuitAccessories); only
	-- the others go through the description, whose own download can be slow.
	local maskOk = if entry.MaskId and not isAssetCached(tonumber(entry.MaskId)) then applyAssetToDescription(desc, entry.MaskId) else true
	local hairOk = if entry.HairId and not isAssetCached(tonumber(entry.HairId)) then applyAssetToDescription(desc, entry.HairId, "HairAccessory") else true
	local shirtOk = if entry.ShirtId then applyAssetToDescription(desc, entry.ShirtId, "Shirt") else true
	local pantsOk = if entry.PantsId then applyAssetToDescription(desc, entry.PantsId, "Pants") else true

	if entry.ShirtId and not shirtOk then
		safeSetDescriptionField(desc, "Shirt", entry.ShirtId)
	end
	if entry.PantsId and not pantsOk then
		safeSetDescriptionField(desc, "Pants", entry.PantsId)
	end
	-- Suits made of several pieces (the Silver Surfer's head, torso, waist and shoulders).
	for _, accessory in ipairs(entry.Accessories or {}) do
		if not isAssetCached(tonumber(accessory.Id)) then
			applyAssetToDescription(desc, accessory.Id, accessory.Field)
		end
	end
	applySuitColors(desc, entry, humanoid)

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

	-- The accessories go on at once from the cache, and again once the description (which
	-- may take them off, being a reset) is in.
	wearCachedSuitAccessories(character, humanoid, entry)
	local applied = applyCatalogSuitDescription(humanoid, entry)
	if player.Character == character and player:GetAttribute("EquippedSkin") == entry.Id then
		wearCachedSuitAccessories(character, humanoid, entry)
	end

	local function finishFallback()
		if player.Character ~= character
			or humanoid.Parent ~= character
			or player:GetAttribute("EquippedSkin") ~= entry.Id
		then
			return false
		end
		forceCatalogClassicClothingObjects(character, entry)
		for _, accessory in ipairs(suitAccessories(entry)) do
			if not hasCatalogAccessory(character, accessory.Id) then
				loadReverseAssetOntoCharacter(character, humanoid, accessory.Id)
			end
		end
		return true
	end

	-- Anything still missing (not cached yet): loaded and put on straight away.
	task.defer(finishFallback)

	-- The description once more only if the clothes did not make it (a reset each time took
	-- the accessories off again, which is why they sometimes came late).
	task.defer(function()
		for _, delayTime in ipairs({ 0.35, 1.0 }) do
			task.wait(delayTime)
			if not finishFallback() then
				return
			end
			local wearing = character:FindFirstChildOfClass("Shirt") ~= nil or not entry.ShirtId
			if not applied or not wearing then
				applied = applyCatalogSuitDescription(humanoid, entry)
				wearCachedSuitAccessories(character, humanoid, entry)
			end
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
	clearRigOutfit(character)
	clearSurfboard(character)

	local desc = originalDescriptions[player]

	if not desc then
		local ok, userDesc = pcall(function()
			return Players:GetHumanoidDescriptionFromUserIdAsync(player.UserId)
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


----------------------------------------------------------------------
-- RigOutfit: Superman and A-Train
----------------------------------------------------------------------
-- The skin is an R6 rig in ReplicatedStorage.SkinRigs (audit/capture_skin_rigs.luau). The
-- player wears its hair, suit (shirt and pants), cape and other accessories, and keeps their
-- own face, eyes, head and skin tone, as with Flash and the first suits (2026-09-18: the
-- rig's face, Kent's, was put over theirs). The avatar's own accessories and clothes come
-- off first (a description reset in the player's own colours); then the rig's pieces are
-- copied on, each tagged, so the next skin takes them off again (clearRigOutfit).
local RIG_OUTFIT_TAG = "SkinRigOutfit"

local function getSkinRig(entry)
	local folder = ReplicatedStorage:FindFirstChild("SkinRigs")
	local rig = folder and folder:FindFirstChild(tostring(entry.SourceModelName or ""))
	if rig and rig:IsA("Model") and rig:FindFirstChildOfClass("Humanoid") then
		return rig
	end
	return nil
end

function clearRigOutfit(character)
	if not character then
		return
	end
	local worn = {}
	for _, item in ipairs(character:GetDescendants()) do
		if item:GetAttribute(RIG_OUTFIT_TAG) == true then
			table.insert(worn, item)
		end
	end
	for _, item in ipairs(worn) do
		item:Destroy()
	end
end

-- The rig's hair, suit, cape and accessories on the character; its face, head and skin
-- tone stay the player's own.
local function dressFromRig(character, humanoid, rig)
	clearReverseAvatarItems(character)

	-- Clothes and accessories.
	for _, item in ipairs(rig:GetChildren()) do
		if item:IsA("Shirt") or item:IsA("Pants") or item:IsA("ShirtGraphic") then
			local copy = item:Clone()
			copy:SetAttribute(RIG_OUTFIT_TAG, true)
			copy:SetAttribute("FlashSuitClothing", true)
			copy.Parent = character
		elseif item:IsA("Accessory") then
			local copy = item:Clone()
			copy:SetAttribute(RIG_OUTFIT_TAG, true)
			copy:SetAttribute("FlashSuitAccessory", true)
			local handle = copy:FindFirstChild("Handle")
			if handle and handle:IsA("BasePart") then
				handle.Anchored = false
				handle.CanCollide = false
				handle.CanTouch = false
				handle.CanQuery = false
				handle.Massless = true
				local weld = handle:FindFirstChild("AccessoryWeld")
				if weld then
					weld:Destroy()
				end
			end
			local added = pcall(function()
				humanoid:AddAccessory(copy)
			end)
			if not added then
				copy:Destroy()
			end
		end
	end
end

local function isRigOutfitWorn(character)
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Shirt") and child:GetAttribute(RIG_OUTFIT_TAG) == true then
			return true
		end
	end
	return false
end

local function applyRigOutfitSuit(player, entry)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid then
		return false, "No character"
	end
	local rig = getSkinRig(entry)
	if not rig then
		return false, tostring(entry.SourceModelName) .. " rig missing"
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
	clearRigOutfit(character)
	clearReverseAvatarItems(character)
	removeFlashFallbackObjects(character)
	removeFlashDirectClothing(character)

	-- The avatar's own accessories and clothes off; its face and its own skin tone stay
	-- (back after a skin that changed them, such as the Silver Surfer's silver).
	local ok, desc = pcall(function()
		return humanoid:GetAppliedDescription()
	end)
	if ok and desc then
		clearReverseDescription(desc)
		applySuitColors(desc, entry, humanoid)
		tryApplyReverseDescription(humanoid, desc)
	end
	-- The reset yields: another skin may have been put on meanwhile.
	if player.Character ~= character or humanoid.Parent ~= character or player:GetAttribute("EquippedSkin") ~= entry.Id then
		return true
	end
	dressFromRig(character, humanoid, rig)

	-- A late avatar load can undo it (as it can a catalog suit): dress again once.
	task.delay(1, function()
		if player.Character == character
			and humanoid.Parent == character
			and player:GetAttribute("EquippedSkin") == entry.Id
			and not isRigOutfitWorn(character)
		then
			clearRigOutfit(character)
			dressFromRig(character, humanoid, rig)
		end
	end)

	sendUpdate(player)
	return true
end

----------------------------------------------------------------------
-- The Silver Surfer's board
----------------------------------------------------------------------
-- The catalog's Surfer's '07 board (a waist accessory), ridden under the feet: welded to
-- the root, its longest side along the rider's forward axis and its thinnest side up, a
-- board length long. The body is lifted by Config.SurfboardHover (Humanoid.HipHeight, an
-- offset on R6) so the board floats a little over the floor; the character's physics and
-- speed are the same. Movement/SurfboardPose (every client) gives the rider the stance.
local SURFBOARD_FOLDER = "SkinSurfboard"
local SURFBOARD_ATTRIBUTE = "SurfboardRiding"
local SURFBOARD_BASE_HIP = "SurfboardBaseHipHeight"
local SURFBOARD_LENGTH = 5.6
local SURFBOARD_HOVER = math.clamp(tonumber(Config.SurfboardHover) or 0.85, 0.3, 2)
local R6_SOLES_BELOW_ROOT = 3
local surfboardTemplates = {}
local surfboardWatchers: { [Model]: RBXScriptConnection } = setmetatable({}, { __mode = "k" }) :: any

-- The rotation that stands a board of `size` on the rider: longest side forward (Z),
-- thinnest side up (Y), the other across (X).
local function surfboardRotation(size)
	local axes = {
		{ Length = size.X, Index = 1 },
		{ Length = size.Y, Index = 2 },
		{ Length = size.Z, Index = 3 },
	}
	table.sort(axes, function(a, b)
		return a.Length < b.Length
	end)
	local columns = {}
	columns[axes[1].Index] = Vector3.yAxis
	columns[axes[2].Index] = Vector3.xAxis
	columns[axes[3].Index] = Vector3.zAxis
	if columns[1]:Cross(columns[2]):Dot(columns[3]) < 0 then
		columns[axes[2].Index] = -Vector3.xAxis
	end
	return CFrame.fromMatrix(Vector3.zero, columns[1], columns[2], columns[3]), axes[3].Length, axes[1].Length
end

local function buildFallbackSurfboard()
	local board = Instance.new("Part")
	board.Size = Vector3.new(1.9, 0.3, SURFBOARD_LENGTH)
	board.Color = Color3.fromRGB(214, 222, 232)
	board.Material = Enum.Material.Metal
	board.Reflectance = 0.35
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = board
	return board
end

local function getSurfboardTemplate(entry)
	local cached = surfboardTemplates[entry.Id]
	if cached then
		return cached
	end
	local board = nil
	local surfboard = entry.Surfboard or {}
	for _, assetId in ipairs({ tonumber(surfboard.AssetId), tonumber(surfboard.FallbackAssetId) }) do
		local loaded = getCachedLoadedAsset(assetId)
		local handle = loaded and loaded:FindFirstChild("Handle", true)
		if handle and handle:IsA("BasePart") then
			board = handle:Clone()
			-- Only its look: no accessory welds, attachments or scripts.
			for _, child in ipairs(board:GetChildren()) do
				if not (child:IsA("DataModelMesh") or child:IsA("SurfaceAppearance") or child:IsA("Decal") or child:IsA("Texture")) then
					child:Destroy()
				end
			end
			break
		end
	end
	board = board or buildFallbackSurfboard()
	local rotation, length, thickness = surfboardRotation(board.Size)
	local scale = SURFBOARD_LENGTH / math.max(0.1, length)
	board.Size *= scale
	local mesh = board:FindFirstChildWhichIsA("SpecialMesh")
	if mesh and mesh.MeshType == Enum.MeshType.FileMesh then
		mesh.Scale *= scale
	end
	board.Name = "Board"
	board.Anchored = false
	board.CanCollide = false
	board.CanTouch = false
	board.CanQuery = false
	board.Massless = true
	board.CastShadow = true
	cached = { Board = board, Rotation = rotation, Thickness = thickness * scale }
	surfboardTemplates[entry.Id] = cached
	return cached
end

function clearSurfboard(character)
	if not character then
		return
	end
	local watcher = surfboardWatchers[character]
	if watcher then
		watcher:Disconnect()
		surfboardWatchers[character] = nil
	end
	local folder = character:FindFirstChild(SURFBOARD_FOLDER)
	if folder then
		folder:Destroy()
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local base = character:GetAttribute(SURFBOARD_BASE_HIP)
	if humanoid and type(base) == "number" then
		humanoid.HipHeight = base
	end
	character:SetAttribute(SURFBOARD_BASE_HIP, nil)
	character:SetAttribute(SURFBOARD_ATTRIBUTE, nil)
end

local function attachSurfboard(player, entry)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then
		return false
	end
	-- The first board of a server comes from the catalog (InsertService): it yields.
	local template = getSurfboardTemplate(entry)
	if player.Character ~= character or not root.Parent or player:GetAttribute("EquippedSkin") ~= entry.Id then
		return false
	end
	clearSurfboard(character)

	local folder = Instance.new("Folder")
	folder.Name = SURFBOARD_FOLDER
	local board = template.Board:Clone()
	-- Its top just under the soles (the stance spreads the feet a touch lower than 3 studs).
	local lift = CFrame.new(0, -(R6_SOLES_BELOW_ROOT + template.Thickness / 2) - 0.05, 0)
	board.CFrame = root.CFrame * lift * template.Rotation
	local weld = Instance.new("Weld")
	weld.Name = "BoardWeld"
	weld.Part0 = root
	weld.Part1 = board
	weld.C0 = lift * template.Rotation
	weld.Parent = board
	-- A short wake off the tail.
	local front = Instance.new("Attachment")
	front.Name = "WakeTop"
	front.CFrame = template.Rotation:Inverse() * CFrame.new(0, 0.12, SURFBOARD_LENGTH * 0.42)
	front.Parent = board
	local back = Instance.new("Attachment")
	back.Name = "WakeBottom"
	back.CFrame = template.Rotation:Inverse() * CFrame.new(0, -0.12, SURFBOARD_LENGTH * 0.42)
	back.Parent = board
	local wake = Instance.new("Trail")
	wake.Name = "Wake"
	wake.Attachment0 = front
	wake.Attachment1 = back
	wake.Lifetime = 0.3
	wake.MinLength = 0.2
	wake.LightEmission = 0.6
	wake.Color = ColorSequence.new(Color3.fromRGB(235, 245, 255), Color3.fromRGB(140, 200, 255))
	wake.Transparency = NumberSequence.new(0.35, 1)
	wake.Parent = board
	board.Parent = folder
	folder.Parent = character

	-- Lift the body over the board, and keep it lifted.
	local base = humanoid.HipHeight
	character:SetAttribute(SURFBOARD_BASE_HIP, base)
	humanoid.HipHeight = base + SURFBOARD_HOVER
	surfboardWatchers[character] = humanoid:GetPropertyChangedSignal("HipHeight"):Connect(function()
		if folder.Parent == character and humanoid.HipHeight ~= base + SURFBOARD_HOVER then
			humanoid.HipHeight = base + SURFBOARD_HOVER
		end
	end)
	character:SetAttribute(SURFBOARD_ATTRIBUTE, true)
	return true
end

-- ModelMorph: a whole rig worn over the player's R6 body. Each of the rig's meshes is
-- welded to the R6 limb it belongs to, where it sits on the rig scaled to an R6 height,
-- and the R6 body underneath is hidden (and shown again when the skin comes off).
local MORPH_FOLDER_NAME = "SkinMorph"
local MORPH_HIDDEN_ATTRIBUTE = "SkinMorphHiddenTransparency"
local MORPH_LIMB_OF = {
	Head = "Head",
	UpperTorso = "Torso",
	LowerTorso = "Torso",
	LeftUpperArm = "Left Arm",
	LeftLowerArm = "Left Arm",
	LeftHand = "Left Arm",
	RightUpperArm = "Right Arm",
	RightLowerArm = "Right Arm",
	RightHand = "Right Arm",
	LeftUpperLeg = "Left Leg",
	LeftLowerLeg = "Left Leg",
	LeftFoot = "Left Leg",
	RightUpperLeg = "Right Leg",
	RightLowerLeg = "Right Leg",
	RightFoot = "Right Leg",
}
-- Where each R6 limb rests from the root, and the root's height over the soles.
local R6_LIMB_REST = {
	Torso = CFrame.new(0, 0, 0),
	Head = CFrame.new(0, 1.5, 0),
	["Left Arm"] = CFrame.new(-1.5, 0, 0),
	["Right Arm"] = CFrame.new(1.5, 0, 0),
	["Left Leg"] = CFrame.new(-0.5, -2, 0),
	["Right Leg"] = CFrame.new(0.5, -2, 0),
}
local R6_ROOT_HEIGHT = 3
local morphPieceCache = {}
-- Per character: the connections that keep its body hidden under the rig.
local morphWatchers: { [Model]: { RBXScriptConnection } } = setmetatable({}, { __mode = "k" }) :: any

-- The rig's meshes, sized for an R6 body, each tagged with its limb and its place on it.
local function buildMorphPieces(entry)
	local cached = morphPieceCache[entry.Id]
	if cached then
		return cached
	end
	local source = ServerStorage:FindFirstChild(tostring(entry.SourceModelName or ""))
	local root = source and source:FindFirstChild("HumanoidRootPart")
	if not source or not root or not root:IsA("BasePart") then
		return nil
	end
	local rootFrame = root.CFrame
	local soles = 0
	for _, part in ipairs(source:GetChildren()) do
		if part:IsA("BasePart") and MORPH_LIMB_OF[part.Name] then
			local relative = rootFrame:ToObjectSpace(part.CFrame)
			local up = relative:VectorToObjectSpace(Vector3.new(0, 1, 0))
			local halfHeight = 0.5 * (math.abs(up.X) * part.Size.X + math.abs(up.Y) * part.Size.Y + math.abs(up.Z) * part.Size.Z)
			soles = math.min(soles, relative.Position.Y - halfHeight)
		end
	end
	if soles >= 0 then
		return nil
	end
	local scale = R6_ROOT_HEIGHT / -soles

	local pieces = {}
	for _, part in ipairs(source:GetChildren()) do
		local limb = part:IsA("BasePart") and MORPH_LIMB_OF[part.Name]
		if limb then
			local piece = part:Clone()
			-- Only the mesh and its look travel: no joints, rig attachments, cages,
			-- face rig or scripts.
			for _, child in ipairs(piece:GetChildren()) do
				if not child:IsA("SurfaceAppearance") and not child:IsA("Decal") then
					child:Destroy()
				end
			end
			local relative = rootFrame:ToObjectSpace(part.CFrame)
			local placed = CFrame.new(relative.Position * scale) * relative.Rotation
			piece.Size = part.Size * scale
			piece.Anchored = false
			piece.CanCollide = false
			piece.CanTouch = false
			piece.CanQuery = false
			piece.Massless = true
			piece:SetAttribute("MorphLimb", limb)
			piece:SetAttribute("MorphOffset", R6_LIMB_REST[limb]:ToObjectSpace(placed))
			table.insert(pieces, piece)
		end
	end
	morphPieceCache[entry.Id] = pieces
	return pieces
end

local function hideUnderMorph(item)
	if item:GetAttribute(MORPH_HIDDEN_ATTRIBUTE) ~= nil then
		return
	end
	if item:IsA("BasePart") or item:IsA("Decal") then
		item:SetAttribute(MORPH_HIDDEN_ATTRIBUTE, item.Transparency)
		item.Transparency = 1
	end
end

-- The R6 body, its face and whatever it wears; never the morph, the cosmetics (auras,
-- trails) or the invisible root.
local function hideBodyForMorph(character, item)
	local accessory = item:FindFirstAncestorWhichIsA("Accessory")
	if accessory and accessory.Parent == character then
		hideUnderMorph(item)
	elseif item.Parent == character and item:IsA("BasePart") and R6_LIMB_REST[item.Name] then
		hideUnderMorph(item)
	elseif item:IsA("Decal") and item.Parent and item.Parent.Parent == character and R6_LIMB_REST[item.Parent.Name] then
		hideUnderMorph(item)
	end
end

local function clearModelMorph(character)
	if not character then
		return
	end
	for _, connection in morphWatchers[character] or {} do
		connection:Disconnect()
	end
	morphWatchers[character] = nil
	local folder = character:FindFirstChild(MORPH_FOLDER_NAME)
	if folder then
		folder:Destroy()
	end
	for _, item in ipairs(character:GetDescendants()) do
		local saved = item:GetAttribute(MORPH_HIDDEN_ATTRIBUTE)
		if saved ~= nil then
			item.Transparency = saved
			item:SetAttribute(MORPH_HIDDEN_ATTRIBUTE, nil)
		end
	end
end

local function applyModelMorphSuit(player, entry)
	local character = player.Character
	if not character or not character:FindFirstChildOfClass("Humanoid") then
		return false, "No character"
	end
	local pieces = buildMorphPieces(entry)
	if not pieces or #pieces == 0 then
		return false, tostring(entry.SourceModelName) .. " rig missing"
	end
	clearModelMorph(character)

	local folder = Instance.new("Folder")
	folder.Name = MORPH_FOLDER_NAME
	folder:SetAttribute("SkinId", entry.Id)
	for _, template in ipairs(pieces) do
		local limb = character:FindFirstChild(template:GetAttribute("MorphLimb"))
		if limb and limb:IsA("BasePart") then
			local offset = template:GetAttribute("MorphOffset")
			local piece = template:Clone()
			piece.CFrame = limb.CFrame * offset
			local weld = Instance.new("Weld")
			weld.Name = "MorphWeld"
			weld.Part0 = limb
			weld.Part1 = piece
			weld.C0 = offset
			weld.Parent = piece
			piece.Parent = folder
		end
	end
	folder.Parent = character

	forceSuitState(player, entry.Id)
	for _, item in ipairs(character:GetDescendants()) do
		hideBodyForMorph(character, item)
	end
	-- A hat or a face put on later (another system's description) stays hidden too, until
	-- the character leaves the world (a respawn, or leaving the game).
	local connections = {}
	morphWatchers[character] = connections
	table.insert(connections, character.DescendantAdded:Connect(function(item)
		if folder.Parent == character then
			hideBodyForMorph(character, item)
		end
	end))
	table.insert(connections, character.AncestryChanged:Connect(function()
		if not character:IsDescendantOf(game) then
			for _, connection in connections do
				connection:Disconnect()
			end
			morphWatchers[character] = nil
		end
	end))
	return true
end

local function applySkinById(player, skinId)
	local applied
	local message
	local entry = SuitCatalog.Get(skinId)
	if skinId ~= "DarkZonicSuit" and player.Character then
		setDarkZonicNeckSpacing(player.Character, false)
	end

	if entry and entry.SpecialApplyMode ~= "ModelMorph" and player.Character then
		clearModelMorph(player.Character)
	end
	if entry and entry.SpecialApplyMode ~= "RigOutfit" and player.Character then
		clearRigOutfit(player.Character)
	end
	if entry and not entry.Surfboard and player.Character then
		clearSurfboard(player.Character)
	end

	if not entry then
		return false, "Unknown skin"
	elseif entry.SpecialApplyMode == "ModelMorph" then
		applied, message = applyModelMorphSuit(player, entry)
	elseif entry.SpecialApplyMode == "RigOutfit" then
		applied, message = applyRigOutfitSuit(player, entry)
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
		if entry.Surfboard then
			task.spawn(attachSurfboard, player, entry)
		end
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

RemoteGuard.Connect(EquipSkin, 0.25, function(player, skinId)
	if skinId == "Sync" then
		if player:GetAttribute("DataLoaded") == true then sendUpdate(player) end
		return
	end
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
	if not persistSkinSelection(player, skinId, true) then
		evolveInProgress[player] = nil
		sendIndexUpdate(player, "Could not save evolution. Please retry.")
		sendUpdate(player)
		return
	end
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

		if not persistSkinSelection(player, skinId, false) then
			evolveInProgress[player] = nil
			sendIndexUpdate(player, "Could not save skin selection. Please retry.")
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

-- For the admin panel's Unlock All Cosmetics (server only): grant a skin and put it on,
-- saved and applied exactly as the Index equips one.
_G.SpeedsterAdminGiveSkin = function(player, skinId)
	if typeof(player) ~= "Instance" or not player:IsA("Player") or type(skinId) ~= "string" or not VALID_INDEX_SKINS[skinId] then
		return false
	end
	if player:GetAttribute("DataLoaded") ~= true or evolveInProgress[player] then
		return false
	end
	evolveInProgress[player] = true
	local saved = persistSkinSelection(player, skinId, true)
	local ok, applied = false, false
	if saved then
		unlockSkin(player, skinId)
		ok, applied = pcall(applySkinById, player, skinId)
	end
	evolveInProgress[player] = nil
	if saved and ok and applied then
		saveSkinState(player, "admin_skin_equip")
		sendIndexUpdate(player, "Equipped")
		return true
	end
	sendIndexUpdate(player)
	return false
end

-- Exclusive skins won in play (the Silver Surfer, for finishing World 3): owned for good,
-- saved at once, and announced in the Index, where the player puts it on. Server only.
_G.SpeedsterGrantExclusiveSkin = function(player, skinId, reason)
	local entry = SuitCatalog.Get(skinId)
	if typeof(player) ~= "Instance" or not player:IsA("Player") or not entry or not entry.Exclusive then
		return false
	end
	if player:GetAttribute("DataLoaded") ~= true then
		return false
	end
	if ownsSkin(player, skinId) then
		return true
	end
	if ModularData then
		local handle = ModularData.GetHandle(player.UserId)
		if not handle then
			return false
		end
		local result = ModularData.Commit(handle, {
			operationId = HttpService:GenerateGUID(false),
			fingerprint = "exclusive:" .. skinId,
			commands = { { kind = "GrantSkin", skinId = skinId } },
		})
		if result.kind ~= "Committed" and result.kind ~= "AlreadyCommitted" then
			return false
		end
	else
		unlockSkin(player, skinId)
	end
	saveSkinState(player, reason or "exclusive_skin")
	sendIndexUpdate(player, tostring(entry.DisplayName) .. " unlocked! Equip it from the Index")
	return true
end

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

-- Applying the suit needs two things: a Humanoid, and Roblox having inserted the
-- player's own avatar into THIS character. The suit is built on top of
-- humanoid:GetAppliedDescription(); read that from a character whose avatar is not
-- in yet and it comes back empty - black body colours, no face, no accessories -
-- and applying it locks that look in. That was the black skin after dying.
--
-- Player:HasAppearanceLoaded() cannot tell: it is per player, not per character, so
-- after the first spawn it already reads true while a respawned character is still
-- bare. CharacterAppearanceLoaded fires for every character, so it is tracked here.
-- On a respawn the avatar is cached and the event lands within a moment, so this is
-- still far quicker than the old blind one-second wait.
local appearanceReady = setmetatable({}, { __mode = "k" })
local APPEARANCE_WAIT_SECONDS = 8

local function waitForCharacterReady(player, character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		humanoid = character:WaitForChild("Humanoid", 5)
	end
	if not humanoid then
		return false
	end

	-- A very slow avatar load still gets its suit, just after the timeout.
	local deadline = os.clock() + APPEARANCE_WAIT_SECONDS
	while not appearanceReady[character] and os.clock() < deadline do
		if player.Parent == nil or player.Character ~= character then
			return false
		end
		task.wait()
	end

	return player.Parent ~= nil and player.Character == character
end

local function setupPlayer(player)
	player.CharacterAppearanceLoaded:Connect(function(character)
		appearanceReady[character] = true
	end)
	-- When this script starts after the player joined (Studio Play Solo), the first
	-- character's event has already fired. For that first character the per-player
	-- flag is still accurate.
	local existing = player.Character
	if existing then
		local ok, loaded = pcall(function()
			return player:HasAppearanceLoaded()
		end)
		if ok and loaded then
			appearanceReady[existing] = true
		end
	end

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

			if waitForCharacterReady(player, character) then
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

		local character = player.Character
		if character then
			if waitForCharacterReady(player, character) then
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
