local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
if Config.AbilityFlightEnabled ~= true then
	return
end

-- El servidor CREA la carpeta y los eventos de inmediato (sin WaitForChild)
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

local AbilityShopAction = getOrCreateRemote("AbilityShopAction")
local AbilityShopUpdate = getOrCreateRemote("AbilityShopUpdate")
local FlightAbilityState = getOrCreateRemote("FlightAbilityState")

local UPGRADE_NAME = tostring(Config.AbilityFlightUpgradeName or "Flight")
local WINS_COST = math.max(0, math.floor(tonumber(Config.AbilityFlightWinsCost) or 25000000))
local GAMEPASS_ID = math.max(0, math.floor(tonumber(Config.AbilityFlightGamePassId or Config.AbilityFlightProductId) or 1978623069))
local PRODUCT_ID = GAMEPASS_ID
local ROBUX_PRICE = math.max(0, math.floor(tonumber(Config.AbilityFlightPriceRobux) or 79))
local EQUIP_MARKER_NAME = "__AbilityEquipped_Flight"
local EQUIP_STATE_INITIALIZED_NAME = "__AbilityEquipStateInitialized"
local purchaseBusy = {}
local equipSaveBusy = {}

local function getDataFolder(player, createIfMissing)
	local folder = player:FindFirstChild("SpeedsterData")
	if not folder and createIfMissing and player.Parent then
		folder = Instance.new("Folder")
		folder.Name = "SpeedsterData"
		folder.Parent = player
	end
	return folder
end

local function getOwnedFolder(player, createIfMissing)
	local data = getDataFolder(player, createIfMissing)
	local owned = data and data:FindFirstChild("OwnedUpgrades")
	if not owned and createIfMissing and data and data.Parent then
		owned = Instance.new("Folder")
		owned.Name = "OwnedUpgrades"
		owned.Parent = data
	end
	return owned
end

local function getWins(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local wins = leaderstats and leaderstats:FindFirstChild("Wins")
	return wins and wins:IsA("IntValue") and wins or nil
end

local function ownsFlight(player)
	local folder = getOwnedFolder(player)
	local flag = folder and folder:FindFirstChild(UPGRADE_NAME)
	return flag ~= nil and flag:IsA("BoolValue") and flag.Value == true
end

local function getTrueBool(folder, name)
	local flag = folder and folder:FindFirstChild(name)
	return flag ~= nil and flag:IsA("BoolValue") and flag.Value == true
end

local function ensureTrueBool(folder, name)
	if not folder then return nil end
	local flag = folder:FindFirstChild(name)
	if flag and not flag:IsA("BoolValue") then return nil end
	if not flag then
		flag = Instance.new("BoolValue")
		flag.Name = name
		flag.Parent = folder
	end
	flag.Value = true
	return flag
end

local function isFlightEquipped(player)
	return ownsFlight(player) and getTrueBool(getOwnedFolder(player), EQUIP_MARKER_NAME)
end

local function syncEquippedAttributes(player)
	local equipped = isFlightEquipped(player)
	player:SetAttribute("FlightAbilityEquipped", equipped)
	player:SetAttribute("EquippedAbility", equipped and "Flight" or "")
	if not equipped then
		player:SetAttribute("FlightAbilityActive", false)
		player:SetAttribute("FlightAbilityPowered", false)
	end
	return equipped
end

local function syncOwnedAttribute(player)
	if player:GetAttribute("FlightAbilityGrantPending") == true then
		return player:GetAttribute("FlightAbilityOwned") == true
	end
	local owned = ownsFlight(player)
	if player:GetAttribute("FlightAbilityOwned") ~= owned then
		player:SetAttribute("FlightAbilityOwned", owned)
	end
	return owned
end

local function buildState(player, message)
	local wins = getWins(player)
	return {
		Flight = {
			Id = UPGRADE_NAME,
			DisplayName = "Flight",
			Owned = syncOwnedAttribute(player),
			Equipped = syncEquippedAttributes(player),
			WinsCost = WINS_COST,
			ProductId = PRODUCT_ID,
			RobuxPrice = ROBUX_PRICE,
			PoweredAnimationId = tostring(Config.AbilityFlightPoweredAnimationId or ""),
			GlideAnimationId = tostring(Config.AbilityFlightGlideAnimationId or ""),
		},
		Wins = wins and wins.Value or 0,
		Message = tostring(message or ""),
	}
end

local function sendState(player, message)
	if player and player.Parent then
		AbilityShopUpdate:FireClient(player, buildState(player, message))
	end
end

_G.SpeedsterRefreshAbilityShop = sendState

local function waitForData(player)
	for _ = 1, 120 do
		if not player.Parent then return false end
		if player:GetAttribute("DataLoaded") == true and getOwnedFolder(player) and getWins(player) then
			return true
		end
		task.wait(0.1)
	end
	return false
end

local function ensureFlightFlag(player)
	local folder = getOwnedFolder(player, true)
	if not folder or not folder:IsA("Folder") then
		return nil, false
	end
	local flag = folder:FindFirstChild(UPGRADE_NAME)
	if flag and not flag:IsA("BoolValue") then
		return nil, false
	end
	local created = false
	if not flag then
		flag = Instance.new("BoolValue")
		flag.Name = UPGRADE_NAME
		flag.Parent = folder
		created = true
	end
	return flag, created
end

local function saveEquipState(player, reason)
	if equipSaveBusy[player] then return end
	equipSaveBusy[player] = true
	task.defer(function()
		equipSaveBusy[player] = nil
		if not player.Parent then return end
		local savePlayer = _G.SpeedsterSavePlayer
		if type(savePlayer) == "function" then
			local ok, saved = pcall(savePlayer, player, reason or "flight_equip_state", true)
			if not ok or saved ~= true then
				warn("[World1FlightAbility] Equip state save did not confirm for " .. player.Name)
			end
		end
	end)
end

local function initializeLegacyEquipState(player)
	local folder = getOwnedFolder(player)
	if not folder or getTrueBool(folder, EQUIP_STATE_INITIALIZED_NAME) then
		return
	end
	if ownsFlight(player) then
		ensureTrueBool(folder, EQUIP_MARKER_NAME)
	end
	ensureTrueBool(folder, EQUIP_STATE_INITIALIZED_NAME)
	syncEquippedAttributes(player)
	saveEquipState(player, "flight_equip_migration")
end

local function setFlightEquipped(player, equipped)
	if not waitForData(player) then
		return false, "Data is still loading"
	end
	if not ownsFlight(player) then
		return false, "Flight is not owned"
	end
	local folder = getOwnedFolder(player)
	if not folder then
		return false, "Ability data is not ready"
	end
	ensureTrueBool(folder, EQUIP_STATE_INITIALIZED_NAME)

	local marker = folder:FindFirstChild(EQUIP_MARKER_NAME)
	if equipped then
		if marker and not marker:IsA("BoolValue") then
			return false, "Could not equip Flight"
		end
		if not marker then
			marker = Instance.new("BoolValue")
			marker.Name = EQUIP_MARKER_NAME
			marker.Parent = folder
		end
		marker.Value = true
	else
		if marker and marker:IsA("BoolValue") then
			marker.Value = false
		end
	end

	syncEquippedAttributes(player)
	saveEquipState(player, equipped and "flight_equip" or "flight_unequip")
	return true, equipped and "Flight Equipped" or "Flight Unequipped"
end

local function grantAndEquipFlight(player, reason)
	local flag = ensureFlightFlag(player)
	if flag then
		flag.Value = true
	end
	local folder = getOwnedFolder(player, true)
	if folder then
		ensureTrueBool(folder, EQUIP_STATE_INITIALIZED_NAME)
		ensureTrueBool(folder, EQUIP_MARKER_NAME)
	end
	player:SetAttribute("FlightAbilityOwned", true)
	player:SetAttribute("FlightAbilityGrantPending", nil)
	syncEquippedAttributes(player)

	if type(_G.SpeedsterUnlockUpgrade) == "function" then
		pcall(_G.SpeedsterUnlockUpgrade, player, UPGRADE_NAME)
	end
	local savePlayer = _G.SpeedsterSavePlayer
	if type(savePlayer) == "function" then
		pcall(savePlayer, player, reason or "flight_purchase", true)
	end
	sendState(player, "Flight Purchased & Equipped!")
	return true
end

_G.SpeedsterGrantFlight = grantAndEquipFlight

local function buyWithWins(player)
	if purchaseBusy[player] then return end
	purchaseBusy[player] = true

	local function finish(message)
		purchaseBusy[player] = nil
		if player.Parent then
			sendState(player, message)
		end
	end

	if not waitForData(player) then
		finish("Data is still loading")
		return
	end
	if ownsFlight(player) then
		finish("Flight Owned")
		return
	end

	local wins = getWins(player)
	if not wins then
		finish("Wins are still loading")
		return
	end

	local isStudio = RunService:IsStudio()
	if not isStudio and wins.Value < WINS_COST then
		finish("Not Enough Wins")
		return
	end

	if wins.Value >= WINS_COST then
		wins.Value -= WINS_COST
	end

	grantAndEquipFlight(player, "flight_wins_purchase")
	purchaseBusy[player] = nil
end

AbilityShopAction.OnServerEvent:Connect(function(player, action, abilityId)
	action = tostring(action or "")
	abilityId = tostring(abilityId or "Flight")
	if action == "RequestState" then
		sendState(player)
	elseif action == "BuyWins" then
		buyWithWins(player)
	elseif action == "StudioBuyRobux" and RunService:IsStudio() then
		grantAndEquipFlight(player, "flight_studio_robux_purchase")
	elseif action == "Equip" and abilityId == "Flight" then
		local _, message = setFlightEquipped(player, true)
		sendState(player, message)
	elseif action == "Unequip" and abilityId == "Flight" then
		local _, message = setFlightEquipped(player, false)
		sendState(player, message)
	end
end)

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, purchasedPassId, purchaseSuccess)
	if purchaseSuccess and tonumber(purchasedPassId) == GAMEPASS_ID then
		grantAndEquipFlight(player, "flight_gamepass_purchase")
		print("[FlightAbility] Flight GamePass granted to " .. player.Name)
	end
end)

FlightAbilityState.OnServerEvent:Connect(function(player, active, powered)
	active = active == true
	powered = powered == true

	if not syncOwnedAttribute(player) or not syncEquippedAttributes(player) then
		active = false
		powered = false
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		active = false
		powered = false
	end
	if powered then
		local stamina = tonumber(player:GetAttribute("TrueBoostStamina"))
		if stamina == nil then stamina = 100 end
		local minimum = tonumber(Config.AbilityFlightMinimumStaminaToPower) or 0.25
		if stamina <= minimum then
			powered = false
		end
	end
	if not active then
		powered = false
	end

	player:SetAttribute("FlightAbilityActive", active)
	player:SetAttribute("FlightAbilityPowered", powered)
	if active and player:GetAttribute("IsBoosting") == true then
		player:SetAttribute("IsBoosting", false)
		if type(_G.SpeedsterApplyWalkSpeed) == "function" then
			_G.SpeedsterApplyWalkSpeed(player)
		end
	end
end)

local function setupPlayer(player)
	player:SetAttribute("FlightAbilityActive", false)
	player:SetAttribute("FlightAbilityPowered", false)
	player:SetAttribute("FlightAbilityEquipped", false)
	player:SetAttribute("EquippedAbility", "")
	task.spawn(function()
		if not waitForData(player) then return end

		-- Check GamePass ownership
		if GAMEPASS_ID > 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, GAMEPASS_ID)
			end)
			if ok and owns == true then
				grantAndEquipFlight(player, "flight_gamepass_on_join")
			end
		end

		syncOwnedAttribute(player)
		initializeLegacyEquipState(player)
		syncEquippedAttributes(player)
		sendState(player)

		local wins = getWins(player)
		if wins then
			wins.Changed:Connect(function()
				if player.Parent then sendState(player) end
			end)
		end
	end)

	player.CharacterAdded:Connect(function()
		player:SetAttribute("FlightAbilityActive", false)
		player:SetAttribute("FlightAbilityPowered", false)
		syncEquippedAttributes(player)
	end)
end

Players.PlayerAdded:Connect(setupPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	task.defer(setupPlayer, player)
end
Players.PlayerRemoving:Connect(function(player)
	purchaseBusy[player] = nil
	equipSaveBusy[player] = nil
end)

print("[World1FlightAbility] Server active | Remotes ready")