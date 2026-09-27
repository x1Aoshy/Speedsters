local RemoteGuard = require(game:GetService("ServerScriptService").Services.RemoteGuard)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("CosmeticCatalog"))
local CosmeticService = require(script.Parent:WaitForChild("Cosmetics"):WaitForChild("CosmeticService"))

local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not Remotes then
	Remotes = Instance.new("Folder")
	Remotes.Name = "Remotes"
	Remotes.Parent = ReplicatedStorage
end

local function getOrCreateRemote(name)
	local remote = Remotes:FindFirstChild(name)
	if remote and not remote:IsA("RemoteEvent") then
		remote:Destroy()
		remote = nil
	end

	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = Remotes
	end

	return remote
end

local AuraShopAction = getOrCreateRemote("AuraShopAction")
local AuraShopUpdate = getOrCreateRemote("AuraShopUpdate")

local AURA_ENTRIES = Catalog.GetSortedShopEntries("Aura")

local function getLeaderstats(player)
	return player:FindFirstChild("leaderstats")
end

local function getWinsValue(player)
	local leaderstats = getLeaderstats(player)
	return leaderstats and leaderstats:FindFirstChild("Wins")
end

local function getDataFolder(player)
	return player:FindFirstChild("SpeedsterData")
end

local function getOwnedFolder(player)
	local dataFolder = getDataFolder(player)
	if not dataFolder then
		return nil
	end

	local ownedFolder = dataFolder:FindFirstChild("OwnedAuras")
	if not ownedFolder then
		ownedFolder = Instance.new("Folder")
		ownedFolder.Name = "OwnedAuras"
		ownedFolder.Parent = dataFolder
	end

	return ownedFolder
end

local function getEquippedAuraValue(player)
	local dataFolder = getDataFolder(player)
	if not dataFolder then
		return nil
	end

	local value = dataFolder:FindFirstChild("EquippedAura")
	if not value then
		value = Instance.new("StringValue")
		value.Name = "EquippedAura"
		value.Value = ""
		value.Parent = dataFolder
	end

	return value
end

local function ownsAura(player, auraId)
	local folder = getOwnedFolder(player)
	local flag = folder and folder:FindFirstChild(auraId)
	if flag ~= nil and flag.Value == true then
		return true
	end
	if type(_G.SpeedsterHasAura) == "function" and _G.SpeedsterHasAura(player, auraId) == true then
		if folder and not flag then
			local v = Instance.new("BoolValue")
			v.Name = auraId
			v.Value = true
			v.Parent = folder
		end
		return true
	end
	local entry = Catalog.GetEntry("Aura", auraId)
	local passId = entry and tonumber(entry.RobuxPurchaseId)
	if passId and passId > 0 and (passId < 3000000000 or entry.RobuxPurchaseType == "GamePass" or entry.RobuxPurchaseType == "Auto") then
		local ok, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
		end)
		if ok and owns == true then
			setAuraOwned(player, auraId)
			return true
		end
	end
	return false
end

local function setAuraOwned(player, auraId)
	local folder = getOwnedFolder(player)
	if folder then
		local value = folder:FindFirstChild(auraId)
		if not value then
			value = Instance.new("BoolValue")
			value.Name = auraId
			value.Parent = folder
		end
		value.Value = true
	end

	if type(_G.SpeedsterUnlockAura) == "function" then
		_G.SpeedsterUnlockAura(player, auraId)
	end
end

local function applyAura(player, auraId)
	local entry = Catalog.GetEntry("Aura", auraId)
	local multiplier = 1
	if entry then
		multiplier = tonumber(entry.SpeedMultiplier) or 1
	end

	                                                                          
	                                             
	local success, message = CosmeticService.EquipAura(player, auraId or "")
	if not success then
		warn("[AuraShopSystem] Could not equip aura: " .. tostring(message))
		return false, message
	end

	if type(_G.SpeedsterEquipAura) == "function" then
		_G.SpeedsterEquipAura(player, auraId or "", multiplier)
	else
		player:SetAttribute("AuraSpeedGainMultiplier", multiplier)
	end

	return true, message
end

local function collectOwnedMap(player)
	local map = {}
	for _, entry in ipairs(AURA_ENTRIES) do
		map[entry.Id] = ownsAura(player, entry.Id)
	end
	return map
end

local function buildState(player, message)
	local winsValue = getWinsValue(player)
	local equippedValue = getEquippedAuraValue(player)

	return {
		Auras = AURA_ENTRIES,
		Owned = collectOwnedMap(player),
		EquippedAura = equippedValue and equippedValue.Value or "",
		Wins = winsValue and (tonumber(winsValue.Value) or 0) or 0,
		Message = message,
	}
end

local function sendState(player, message)
	AuraShopUpdate:FireClient(player, buildState(player, message))
end

_G.SpeedsterRefreshAuraShop = function(player, message)
	if player and player.Parent then
		sendState(player, message)
	end
end

local function saveCosmeticOwnership(player, reason)
	local savePlayer = _G.SpeedsterSavePlayer
	if type(savePlayer) == "function" then
		task.defer(savePlayer, player, reason or "aura_gamepass_ownership")
	end
end

local function grantAuraGamePassOwnership(player, auraId, message)
	if not player or not player.Parent or not auraId or auraId == "" then
		return
	end
	local entry = Catalog.GetEntry("Aura", auraId)
	if not ownsAura(player, auraId) then
		setAuraOwned(player, auraId)
	end
	local equippedValue = getEquippedAuraValue(player)
	if equippedValue then
		equippedValue.Value = auraId
	end
	applyAura(player, auraId)
	saveCosmeticOwnership(player, "aura_gamepass_unlock_" .. tostring(auraId))
	sendState(player, message or (entry and ("Bought " .. tostring(entry.DisplayName) .. " with Robux") or "Aura unlocked"))
end

local function syncAllAuraGamePasses(player)
	for _, entry in ipairs(AURA_ENTRIES) do
		local passId = tonumber(entry.RobuxPurchaseId)
		if passId and passId > 0 and (passId < 3000000000 or entry.RobuxPurchaseType == "GamePass" or entry.RobuxPurchaseType == "Auto") then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
			end)
			if ok and owns == true then
				setAuraOwned(player, entry.Id)
			end
		end
	end
end

local function syncPlayerAura(player)
	local dataFolder = getDataFolder(player)
	if not dataFolder then
		return
	end

	local equippedValue = getEquippedAuraValue(player)
	local auraId = equippedValue and equippedValue.Value or ""
	if auraId == "" then
		applyAura(player, "")
		return
	end

	if Catalog.IsValid("Aura", auraId) and ownsAura(player, auraId) then
		applyAura(player, auraId)
	else
		if equippedValue then
			equippedValue.Value = ""
		end
		applyAura(player, "")
	end
end

local function setupPlayer(player)
	task.spawn(function()
		for _ = 1, 120 do
			if player.Parent and getLeaderstats(player) and getDataFolder(player) then
				break
			end
			task.wait(0.25)
		end

		if not player.Parent then
			return
		end

		syncAllAuraGamePasses(player)
		syncPlayerAura(player)
		sendState(player)

		local winsValue = getWinsValue(player)
		if winsValue then
			winsValue.Changed:Connect(function()
				if player.Parent then
					sendState(player)
				end
			end)
		end
	end)
end

local function handleBuy(player, auraId)
	local entry = Catalog.GetEntry("Aura", auraId)
	if not entry or entry.ShopEnabled ~= true then
		sendState(player, "Aura not found")
		return
	end

	if ownsAura(player, auraId) then
		sendState(player, "Already owned")
		return
	end

	local winsValue = getWinsValue(player)
	if not winsValue then
		sendState(player, "Wins not ready")
		return
	end

	local cost = tonumber(entry.WinsCost) or 0
	local currentWins = tonumber(winsValue.Value) or 0
	if currentWins < cost then
		sendState(player, "Not Enough Wins (Need " .. tostring(cost) .. " Wins)")
		return
	end

	local DataService=require(game:GetService("ServerScriptService").Services.Data.DataService)
	local handle=DataService.GetHandle(player.UserId)
	if not handle then sendState(player,"Your data is not ready");return end
	local commands={}
	if cost>0 then table.insert(commands,{kind="DebitWins",amount=cost}) end
	table.insert(commands,{kind="GrantAura",auraId=auraId})
	table.insert(commands,{kind="EquipAura",auraId=auraId})
	local result=DataService.Commit(handle,{operationId="buy:Aura:"..auraId,receiptId="owned:Aura:"..auraId,fingerprint="buy:Aura:"..auraId,commands=commands})
	if result.kind~="Committed" and result.kind~="AlreadyCommitted" then
		sendState(player,"Purchase is awaiting save confirmation. Try again shortly.");return
	end

	local equippedValue = getEquippedAuraValue(player)
	if equippedValue then
		equippedValue.Value = auraId
	end

	local applied, applyMessage = applyAura(player, auraId)
	if not applied then
		sendState(player, "Bought, but visual equip failed")
		warn("[AuraShopSystem] Visual equip failed: " .. tostring(applyMessage))
		return
	end
	sendState(player, "Bought " .. tostring(entry.DisplayName))
end

local function handleEquip(player, auraId)
	local entry = Catalog.GetEntry("Aura", auraId)
	if not entry or entry.ShopEnabled ~= true then
		sendState(player, "Aura not found")
		return
	end

	if not ownsAura(player, auraId) then
		sendState(player, "Buy it first")
		return
	end

	local equippedValue = getEquippedAuraValue(player)
	if equippedValue then
		equippedValue.Value = auraId
	end

	local applied, applyMessage = applyAura(player, auraId)
	if not applied then
		sendState(player, "Equip failed - try again")
		warn("[AuraShopSystem] Equip failed: " .. tostring(applyMessage))
		return
	end
	sendState(player, "Equipped " .. tostring(entry.DisplayName))
end

local function handleUnequip(player, auraId)
	local equippedValue = getEquippedAuraValue(player)
	if equippedValue then
		equippedValue.Value = ""
	end
	local applied, applyMessage = applyAura(player, "")
	if not applied then
		sendState(player, "Unequip failed - try again")
		return
	end
	sendState(player, "Aura unequipped")
end

RemoteGuard.Connect(AuraShopAction, 0.25, function(player, action, auraId)
	if type(action) ~= "string" then
		return
	end
	if type(auraId) ~= "string" then
		auraId = ""
	end

	if action == "RequestState" then
		sendState(player)
	elseif action == "Buy" then
		handleBuy(player, auraId)
	elseif action == "Equip" then
		handleEquip(player, auraId)
	elseif action == "Unequip" then
		handleUnequip(player, auraId)
	end
end)

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, wasPurchased)
	if not wasPurchased then return end
	local numericPassId = tonumber(gamePassId)
	for _, entry in ipairs(AURA_ENTRIES) do
		if tonumber(entry.RobuxPurchaseId) == numericPassId then
			grantAuraGamePassOwnership(player, entry.Id, "Bought " .. tostring(entry.DisplayName) .. " with Robux")
			return
		end
	end
end)

for _, player in ipairs(Players:GetPlayers()) do
	setupPlayer(player)
end
Players.PlayerAdded:Connect(setupPlayer)

print("[AuraShopSystem] V306FJ loaded. Aura shop equip state now stays synchronized with visible VFX.")
