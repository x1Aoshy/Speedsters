local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Catalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CosmeticCatalog"))
local TemplateBuilder = require(script.Parent:WaitForChild("CosmeticTemplateBuilder"))

local TEXTURE_LOAD_TAG = "LoadVFXTextures"

local CosmeticService = {}

local initialized = false
local playerConnections = {}
local repairBusy = {}
local repairWarnAt = {}

local REPAIR_RETRY_DELAYS = {0, 0.10, 0.30, 0.75, 1.50}
local WATCHDOG_INTERVAL = 1.25

local CHARACTER_FOLDER_NAME = "SpeedsterCosmetics"

local ATTRIBUTE_BY_TYPE = {
	Aura = "EquippedAuraId",
	Trail = "EquippedTrailId",
}

local FOLDER_BY_TYPE = {
	Aura = "Auras",
	Trail = "Trails",
}

local SLOT_NAME_BY_TYPE = {
	Aura = "EquippedAura",
	Trail = "EquippedTrail",
}

local DATA_EQUIPPED_BY_TYPE = {
	Aura = "EquippedAura",
	Trail = "EquippedTrail",
}

local DATA_OWNED_BY_TYPE = {
	Aura = "OwnedAuras",
	Trail = "OwnedTrails",
}

local function syncAuraSpeedMultiplier(player, auraId)
	player:SetAttribute("AuraSpeedGainMultiplier", Catalog.GetSpeedMultiplier("Aura", auraId or ""))
end

local function syncTrailSpeedMultiplier(player, trailId)
	player:SetAttribute("TrailSpeedGainMultiplier", Catalog.GetSpeedMultiplier("Trail", trailId or ""))
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

local function persistSelection(player, cosmeticType, cosmeticId)
	local dataFolder = player:FindFirstChild("SpeedsterData")
	if not dataFolder then
		return
	end

	local equippedName = DATA_EQUIPPED_BY_TYPE[cosmeticType]
	local ownedName = DATA_OWNED_BY_TYPE[cosmeticType]
	if not equippedName or not ownedName then
		return
	end

	local equipped = dataFolder:FindFirstChild(equippedName)
	if equipped and not equipped:IsA("StringValue") then
		equipped:Destroy()
		equipped = nil
	end
	if not equipped then
		equipped = Instance.new("StringValue")
		equipped.Name = equippedName
		equipped.Parent = dataFolder
	end
	equipped.Value = cosmeticId

	if cosmeticId ~= "" then
		local owned = dataFolder:FindFirstChild(ownedName)
		if owned and not owned:IsA("Folder") then
			owned:Destroy()
			owned = nil
		end
		if not owned then
			owned = Instance.new("Folder")
			owned.Name = ownedName
			owned.Parent = dataFolder
		end

		local value = owned:FindFirstChild(cosmeticId)
		if not value then
			value = Instance.new("BoolValue")
			value.Name = cosmeticId
			value.Parent = owned
		end
		value.Value = true
	end

	if cosmeticType == "Trail" and type(_G.SpeedsterEquipTrail) == "function" then
		_G.SpeedsterEquipTrail(player, cosmeticId)
	elseif cosmeticType == "Aura" and type(_G.SpeedsterEquipAura) == "function" then
		_G.SpeedsterEquipAura(player, cosmeticId)
	end

	task.defer(function()
		local savePlayer = _G.SpeedsterSavePlayer
		if type(savePlayer) == "function" and player.Parent then
			savePlayer(player, string.lower(cosmeticType) .. "_equip")
		end
	end)
end

local function getTemplates()
	return TemplateBuilder.Build()
end

local function getTemplate(cosmeticType, cosmeticId)
	if not Catalog.IsValid(cosmeticType, cosmeticId) then
		return nil
	end

	local templates = getTemplates()
	local typeFolderName = FOLDER_BY_TYPE[cosmeticType]
	local typeFolder = templates:FindFirstChild(typeFolderName)

	if not typeFolder then
		return nil
	end

	return typeFolder:FindFirstChild(cosmeticId)
end

local function getCharacterFolder(character)
	local folder = character:FindFirstChild(CHARACTER_FOLDER_NAME)

	if not folder then
		folder = Instance.new("Folder")
		folder.Name = CHARACTER_FOLDER_NAME
		folder.Parent = character
	end

	return folder
end

local function clearSlot(character, cosmeticType)
	local characterFolder = character:FindFirstChild(CHARACTER_FOLDER_NAME)

	if not characterFolder then
		return
	end

	local slotName = SLOT_NAME_BY_TYPE[cosmeticType]
	local old = characterFolder:FindFirstChild(slotName)

	if old then
		old:Destroy()
	end
end

local function configureEquippedPart(part)
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Massless = true
	part.Transparency = 1
end

-- True for a piece that each client places itself (an aura's FloorVFX or ShidouBall),
-- or for any part inside one.
local function isClientPlaced(instance)
	local current = instance
	while current and not current:IsA("Folder") do
		if current:GetAttribute("DynamicFloorVFX") or current:GetAttribute("DynamicShidouBall") or current:GetAttribute("DynamicOrbit") then
			return true
		end
		current = current.Parent
	end
	return false
end

local function enableEffects(instance)
	CollectionService:AddTag(instance, TEXTURE_LOAD_TAG)
	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("BasePart") then
			if descendant.Name == "EffectHolder" or descendant:GetAttribute("HolderPart") == true then
				configureEquippedPart(descendant)
			elseif isClientPlaced(descendant) then
				descendant.Anchored = true
				descendant.CanCollide = false
				descendant.CanTouch = false
				descendant.CanQuery = false
				descendant.Massless = true
			else
				descendant.Anchored = false
				descendant.CanCollide = false
				descendant.CanTouch = false
				descendant.CanQuery = false
				descendant.Massless = true
			end
		elseif descendant:IsA("ParticleEmitter")
			or descendant:IsA("Trail")
			or descendant:IsA("Beam")
			or descendant:IsA("Light")
			or descendant:IsA("Highlight")
		then
			descendant.Enabled = true
		end
	end

	pcall(function()
		local sharedFolder = ReplicatedStorage:FindFirstChild("Shared")
		local forge = sharedFolder and sharedFolder:FindFirstChild("ForgeVFX")
		if forge then
			local ForgeVFX = require(forge)
			ForgeVFX.enable(instance)
		end
	end)
end

local function warnRepairOnce(player, cosmeticType, message)
	local key = tostring(player and player.UserId or 0) .. ":" .. tostring(cosmeticType)
	local now = os.clock()
	if now - (repairWarnAt[key] or 0) >= 5 then
		repairWarnAt[key] = now
		warn("[CosmeticService] " .. tostring(message))
	end
end

local function getExpectedEffectClass(cosmeticType)
	if cosmeticType == "Aura" then
		return "ParticleEmitter"
	elseif cosmeticType == "Trail" then
		return "Trail"
	end
	return nil
end

local function slotLooksHealthy(character, cosmeticType, cosmeticId, overrideSlot)
	local characterFolder = character and character:FindFirstChild(CHARACTER_FOLDER_NAME)
	local slotName = SLOT_NAME_BY_TYPE[cosmeticType]
	local slot = overrideSlot or (characterFolder and slotName and characterFolder:FindFirstChild(slotName))

	if cosmeticId == nil or cosmeticId == "" then
		return slot == nil
	end

	if not slot or slot:GetAttribute("EquippedCosmeticId") ~= cosmeticId then
		return false
	end

	local holder = slot:FindFirstChild("EffectHolder")
	if not holder or not holder:IsA("BasePart") then
		return false
	end

	local weld = holder:FindFirstChild("CosmeticWeld")
	if not weld or not weld:IsA("WeldConstraint") or weld.Part1 ~= holder then
		return false
	end
	if not weld.Part0 or not weld.Part0:IsDescendantOf(character) then
		return false
	end

	local expectedClass = getExpectedEffectClass(cosmeticType)
	if expectedClass and not slot:FindFirstChildWhichIsA(expectedClass, true) then
		return false
	end

	-- Once per slot: nothing on the server switches an equipped cosmetic's effects off, and
	-- walking every emitter (and ForgeVFX) for every player every watchdog tick was pure cost.
	if slot:GetAttribute("EffectsReady") ~= true then
		enableEffects(slot)
		slot:SetAttribute("EffectsReady", true)
	end
	return true
end

local function attachTemplate(character, cosmeticType, cosmeticId)
	if not character then
		return false, "Character is missing."
	end

	cosmeticId = cosmeticId or ""
	if cosmeticId == "" then
		clearSlot(character, cosmeticType)
		return true
	end

	local template
	local templateOk, templateResult = pcall(getTemplate, cosmeticType, cosmeticId)
	if templateOk then
		template = templateResult
	else
		return false, "Template build failed: " .. tostring(templateResult)
	end

	if not template then
		return false, "Missing template for " .. tostring(cosmeticType) .. " " .. tostring(cosmeticId)
	end

	local targetPart
	if cosmeticType == "Trail" then
		targetPart = character:FindFirstChild("UpperTorso")
			or character:FindFirstChild("Torso")
			or character:FindFirstChild("HumanoidRootPart")
	else
		local targetName = template:GetAttribute("TargetPart") or "HumanoidRootPart"
		targetPart = character:FindFirstChild(targetName)
	end
	if not targetPart or not targetPart:IsA("BasePart") then
		return false, "Target part is not ready: " .. tostring(template:GetAttribute("TargetPart") or "HumanoidRootPart")
	end

	local characterFolder = getCharacterFolder(character)
	local slotName = SLOT_NAME_BY_TYPE[cosmeticType]
	local pendingName = slotName .. "_Pending"
	local stalePending = characterFolder:FindFirstChild(pendingName)
	if stalePending then
		stalePending:Destroy()
	end

	local equipped = template:Clone()
	equipped.Name = pendingName
	equipped:SetAttribute("EquippedCosmeticId", cosmeticId)
	equipped:SetAttribute("EquippedCosmeticType", cosmeticType)
	equipped.Parent = characterFolder

	local holder = equipped:FindFirstChild("EffectHolder")
	if not holder or not holder:IsA("BasePart") then
		equipped:Destroy()
		return false, "Template has no EffectHolder: " .. template:GetFullName()
	end

	local offsetValue = equipped:FindFirstChild("LocalOffset")
	local localOffset = CFrame.new()
	if offsetValue and offsetValue:IsA("CFrameValue") then
		localOffset = offsetValue.Value
	end

	-- Authored offsets are measured against the preview rig's HumanoidRootPart,
	-- which sits in the same place on R6 and R15. Placing from the character's own
	-- HumanoidRootPart and then welding to the target part keeps both rigs
	-- identical, instead of correcting R15 with a hand-tuned height constant.
	local placementOrigin = targetPart.CFrame
	if equipped:GetAttribute("OffsetSpace") == "HumanoidRootPart" then
		local characterRoot = character:FindFirstChild("HumanoidRootPart")
		if characterRoot and characterRoot:IsA("BasePart") then
			placementOrigin = characterRoot.CFrame
		end
	end

	configureEquippedPart(holder)
	holder.CFrame = placementOrigin * localOffset

	local oldWeld = holder:FindFirstChild("CosmeticWeld")
	if oldWeld then
		oldWeld:Destroy()
	end

	local weld = Instance.new("WeldConstraint")
	weld.Name = "CosmeticWeld"
	weld.Part0 = targetPart
	weld.Part1 = holder
	weld.Parent = holder

	-- Weld limb holders to their respective character body parts
	local R6_LIMB_TO_R15 = {
		Torso = "UpperTorso",
		Head = "Head",
		["Left Arm"] = "LeftUpperArm",
		["Right Arm"] = "RightUpperArm",
		["Left Leg"] = "LeftUpperLeg",
		["Right Leg"] = "RightUpperLeg",
		HumanoidRootPart = "HumanoidRootPart",
	}

	for _, child in ipairs(equipped:GetChildren()) do
		local targetLimb = child:GetAttribute("TargetLimb")
		if targetLimb and child:IsA("BasePart") then
			-- Find the character limb (try R15 name first, then R6)
			local r15Name = R6_LIMB_TO_R15[targetLimb] or targetLimb
			local limbPart = character:FindFirstChild(r15Name) or character:FindFirstChild(targetLimb)
			if limbPart and limbPart:IsA("BasePart") then
				configureEquippedPart(child)
				-- Where it sat on the showcase rig's limb (an aura part riding the root).
				local offset = child:GetAttribute("LimbOffset")
				child.CFrame = limbPart.CFrame * (if typeof(offset) == "CFrame" then offset else CFrame.new())
				local limbWeld = Instance.new("WeldConstraint")
				limbWeld.Name = "LimbWeld"
				limbWeld.Part0 = limbPart
				limbWeld.Part1 = child
				limbWeld.Parent = child
			end
		end
	end

	-- FloorVFX and ShidouBall are not welded: every client moves them next to the
	-- wearer (AuraSpecialEffectsClient). They stay anchored on the server, so they
	-- neither fall nor replicate a position.
	for _, child in ipairs(equipped:GetChildren()) do
		if isClientPlaced(child) then
			if child:IsA("Model") then
				child:PivotTo(targetPart.CFrame + Vector3.new(0, -3, 0))
			elseif child:IsA("BasePart") then
				child.CFrame = targetPart.CFrame + Vector3.new(0, -3, 0)
			end
		end
	end

	enableEffects(equipped)

	local expectedClass = getExpectedEffectClass(cosmeticType)
	if expectedClass and not equipped:FindFirstChildWhichIsA(expectedClass, true) then
		equipped:Destroy()
		return false, "Template contains no " .. expectedClass .. "."
	end
	if weld.Part0 ~= targetPart or weld.Part1 ~= holder then
		equipped:Destroy()
		return false, "Cosmetic weld did not bind."
	end

	if not slotLooksHealthy(character, cosmeticType, cosmeticId, equipped) then
		equipped:Destroy()
		return false, "Equipped cosmetic failed the final health check."
	end

	local old = characterFolder:FindFirstChild(slotName)
	if old and old ~= equipped then
		old:Destroy()
	end
	equipped.Name = slotName

	return true
end

local function getEquippedId(player, cosmeticType)
	local attributeName = ATTRIBUTE_BY_TYPE[cosmeticType]
	return attributeName and tostring(player:GetAttribute(attributeName) or "") or ""
end

local function queueRepair(player, cosmeticType, expectedCharacter)
	if not player or not player.Parent then
		return
	end

	repairBusy[player] = repairBusy[player] or {}
	if repairBusy[player][cosmeticType] then
		return
	end
	repairBusy[player][cosmeticType] = true

	task.spawn(function()
		local lastMessage = nil
		for _, delayTime in ipairs(REPAIR_RETRY_DELAYS) do
			if delayTime > 0 then
				task.wait(delayTime)
			end

			if not player.Parent then
				break
			end

			local character = player.Character
			if expectedCharacter and character ~= expectedCharacter then
				break
			end
			if not character then
				continue
			end

			local cosmeticId = getEquippedId(player, cosmeticType)
			if slotLooksHealthy(character, cosmeticType, cosmeticId) then
				repairBusy[player][cosmeticType] = nil
				return
			end

			local success, message = attachTemplate(character, cosmeticType, cosmeticId)
			lastMessage = message
			if success then
				repairBusy[player][cosmeticType] = nil
				return
			end
		end

		if player.Parent and lastMessage then
			warnRepairOnce(
				player,
				cosmeticType,
				"Could not restore "
					.. tostring(cosmeticType)
					.. " for "
					.. player.Name
					.. ": "
					.. tostring(lastMessage)
			)
		end
		if repairBusy[player] then
			repairBusy[player][cosmeticType] = nil
		end
	end)
end

function CosmeticService.GetCatalog()
	return Catalog
end

function CosmeticService.GetTemplates()
	return getTemplates()
end

function CosmeticService.IsValid(cosmeticType, cosmeticId)
	return Catalog.IsValid(cosmeticType, cosmeticId)
end

function CosmeticService.ApplyCharacter(player, character)
	if not player or not character then
		return
	end

	local auraId = getEquippedId(player, "Aura")
	local trailId = getEquippedId(player, "Trail")
	syncAuraSpeedMultiplier(player, auraId)
	syncTrailSpeedMultiplier(player, trailId)

	local auraOk = attachTemplate(character, "Aura", auraId)
	if not auraOk then
		queueRepair(player, "Aura", character)
	end
	local trailOk = attachTemplate(character, "Trail", trailId)
	if not trailOk then
		queueRepair(player, "Trail", character)
	end
end

function CosmeticService.RefreshPlayer(player)
	if not player or not player.Parent then
		return
	end
	local character = player.Character
	if not character then
		return
	end
	queueRepair(player, "Aura", character)
	queueRepair(player, "Trail", character)
end

function CosmeticService.Equip(player, cosmeticType, cosmeticId)
	local attributeName = ATTRIBUTE_BY_TYPE[cosmeticType]
	if not attributeName then
		return false, "Invalid cosmetic type."
	end

	cosmeticId = cosmeticId or ""
	if cosmeticId ~= "" and not Catalog.IsValid(cosmeticType, cosmeticId) then
		return false, "Unknown cosmetic ID."
	end

	                                                                           
	                                                                             
	if cosmeticId ~= "" then
		local ok, template = pcall(getTemplate, cosmeticType, cosmeticId)
		if not ok then
			return false, "Cosmetic template build failed: " .. tostring(template)
		end
		if not template then
			return false, "Cosmetic template is missing."
		end
	end

	player:SetAttribute(attributeName, cosmeticId)
	if cosmeticType == "Aura" then
		syncAuraSpeedMultiplier(player, cosmeticId)
	elseif cosmeticType == "Trail" then
		syncTrailSpeedMultiplier(player, cosmeticId)
	end
	persistSelection(player, cosmeticType, cosmeticId)

	local character = player.Character
	if character then
		local success, message = attachTemplate(character, cosmeticType, cosmeticId)
		if not success then
			queueRepair(player, cosmeticType, character)
			                                                                      
			return true, message or "Visual application queued."
		end
	end

	return true
end

function CosmeticService.EquipAura(player, auraId)
	return CosmeticService.Equip(player, "Aura", auraId)
end

function CosmeticService.EquipTrail(player, trailId)
	return CosmeticService.Equip(player, "Trail", trailId)
end

function CosmeticService.UnequipAura(player)
	return CosmeticService.Equip(player, "Aura", "")
end

function CosmeticService.UnequipTrail(player)
	return CosmeticService.Equip(player, "Trail", "")
end

function CosmeticService.ClearCharacter(character)
	local folder = character and character:FindFirstChild(CHARACTER_FOLDER_NAME)

	if folder then
		folder:Destroy()
	end
end

local function disconnectPlayer(player)
	local connections = playerConnections[player]
	if connections then
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end
	end

	playerConnections[player] = nil
	repairBusy[player] = nil
	for _, cosmeticType in ipairs({"Aura", "Trail"}) do
		repairWarnAt[tostring(player.UserId) .. ":" .. cosmeticType] = nil
	end
end

local function setupPlayer(player)
	disconnectPlayer(player)

	local connections = {}

	table.insert(connections, player.CharacterAdded:Connect(function(character)
		task.spawn(function()
			if not waitForDataLoaded(player) then
				return
			end
			character:WaitForChild("HumanoidRootPart", 15)
			if player.Character == character then
				CosmeticService.ApplyCharacter(player, character)
			end
		end)
	end))

	table.insert(connections, player:GetAttributeChangedSignal(ATTRIBUTE_BY_TYPE.Aura):Connect(function()
		local auraId = player:GetAttribute(ATTRIBUTE_BY_TYPE.Aura) or ""
		syncAuraSpeedMultiplier(player, auraId)
		if player:GetAttribute("DataLoaded") == true
			and (auraId == "" or Catalog.IsValid("Aura", auraId))
		then
			persistSelection(player, "Aura", auraId)
		end
		if player.Character then
			queueRepair(player, "Aura", player.Character)
		end
	end))

	table.insert(connections, player:GetAttributeChangedSignal(ATTRIBUTE_BY_TYPE.Trail):Connect(function()
		local trailId = player:GetAttribute(ATTRIBUTE_BY_TYPE.Trail) or ""
		syncTrailSpeedMultiplier(player, trailId)
		if player:GetAttribute("DataLoaded") == true
			and (trailId == "" or Catalog.IsValid("Trail", trailId))
		then
			persistSelection(player, "Trail", trailId)
		end
		if player.Character then
			queueRepair(player, "Trail", player.Character)
		end
	end))

	playerConnections[player] = connections

	task.spawn(function()
		if not waitForDataLoaded(player) then
			return
		end

		local dataFolder = player:FindFirstChild("SpeedsterData")
		local equippedAura = dataFolder and dataFolder:FindFirstChild("EquippedAura")
		local equippedTrail = dataFolder and dataFolder:FindFirstChild("EquippedTrail")

		player:SetAttribute(
			ATTRIBUTE_BY_TYPE.Aura,
			equippedAura and equippedAura:IsA("StringValue") and equippedAura.Value or ""
		)
		syncAuraSpeedMultiplier(
			player,
			equippedAura and equippedAura:IsA("StringValue") and equippedAura.Value or ""
		)
		player:SetAttribute(
			ATTRIBUTE_BY_TYPE.Trail,
			equippedTrail and equippedTrail:IsA("StringValue") and equippedTrail.Value or ""
		)
		syncTrailSpeedMultiplier(
			player,
			equippedTrail and equippedTrail:IsA("StringValue") and equippedTrail.Value or ""
		)

		if player.Character then
			CosmeticService.ApplyCharacter(player, player.Character)
		end
	end)
end

function CosmeticService.Initialize()
	if initialized then
		return true
	end

	                                                                           
	                                                                          
	                                                         
	local ok, templatesOrError = pcall(getTemplates)
	if not ok then
		return false, tostring(templatesOrError)
	end
	if not templatesOrError then
		return false, "Cosmetic templates were not built."
	end

	initialized = true

	for _, player in ipairs(Players:GetPlayers()) do
		setupPlayer(player)
	end

	Players.PlayerAdded:Connect(setupPlayer)
	Players.PlayerRemoving:Connect(disconnectPlayer)

	                                                       
	_G.SpeedsterCosmetics = CosmeticService

	task.spawn(function()
		while initialized do
			task.wait(WATCHDOG_INTERVAL)
			for _, player in ipairs(Players:GetPlayers()) do
				if player:GetAttribute("DataLoaded") == true and player.Character then
					local character = player.Character
					for _, cosmeticType in ipairs({"Aura", "Trail"}) do
						local cosmeticId = getEquippedId(player, cosmeticType)
						if not slotLooksHealthy(character, cosmeticType, cosmeticId) then
							queueRepair(player, cosmeticType, character)
						end
					end
				end
			end
		end
	end)

	print(
		"[CosmeticService] V306ED ready. Trail/Aura templates, saved state, visible VFX, suit refresh, and self-healing are synchronized."
	)
	return true
end

return CosmeticService
