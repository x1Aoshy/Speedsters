local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
	return flag ~= nil and flag.Value == true
end

local function setAuraOwned(player, auraId)
	if type(_G.SpeedsterUnlockAura) == "function" then
		_G.SpeedsterUnlockAura(player, auraId)
		return
	end

	local folder = getOwnedFolder(player)
	if not folder then
		return
	end

	local value = folder:FindFirstChild(auraId)
	if not value then
		value = Instance.new("BoolValue")
		value.Name = auraId
		value.Parent = folder
	end
	value.Value = true
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

	winsValue.Value = currentWins - cost
	setAuraOwned(player, auraId)
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

	local applied, applyMessage = applyAura(player, auraId)
	if not applied then
		sendState(player, "Equip failed - try again")
		warn("[AuraShopSystem] Equip failed: " .. tostring(applyMessage))
		return
	end
	sendState(player, "Equipped " .. tostring(entry.DisplayName))
end

AuraShopAction.OnServerEvent:Connect(function(player, action, auraId)
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
	end
end)

for _, player in ipairs(Players:GetPlayers()) do
	setupPlayer(player)
end
Players.PlayerAdded:Connect(setupPlayer)

print("[AuraShopSystem] V306FJ loaded. Aura shop equip state now stays synchronized with visible VFX.")
