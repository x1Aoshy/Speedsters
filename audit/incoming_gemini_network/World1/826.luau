local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")
local ServerScriptService = game:GetService("ServerScriptService")
local DataService = require(ServerScriptService.Services.Data.DataService)
local RateLimiter = require(ServerScriptService.Services.ServerRateLimiter)

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
local ROBUX_PRICE = math.max(0, math.floor(tonumber(Config.AbilityFlightPriceRobux) or 799))
local EQUIP_MARKER_NAME = "__AbilityEquipped_Flight"
local EQUIP_STATE_INITIALIZED_NAME = "__AbilityEquipStateInitialized"
local purchaseBusy = {}

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

local function hasTemporaryFlight(player)
	local expire = tonumber(player:GetAttribute("TemporaryFlightExpireUnix")) or 0
	return expire > os.time()
end

local function permanentlyOwnsFlight(player)
	local folder = getOwnedFolder(player)
	local flag = folder and folder:FindFirstChild(UPGRADE_NAME)
	return flag ~= nil and flag:IsA("BoolValue") and flag.Value == true
end

local function ownsFlight(player)
	return permanentlyOwnsFlight(player) or hasTemporaryFlight(player)
end

local function getTrueBool(folder, name)
	local flag = folder and folder:FindFirstChild(name)
	return flag ~= nil and flag:IsA("BoolValue") and flag.Value == true
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



local function commitFlight(player, commands, fingerprint)
	if player.Parent ~= Players or player:GetAttribute("DataLoaded") ~= true then
		return false, "Data is still loading"
	end
	local handle = DataService.GetHandle(player.UserId)
	if not handle then return false, "Data is still loading" end
	local result = DataService.Commit(handle, {
		operationId = DataService.NewOperationId(), fingerprint = fingerprint, commands = commands,
	})
	if result.kind ~= "Committed" and result.kind ~= "AlreadyCommitted" then
		if result.error and result.error.code == "InsufficientFunds" then return false, "Not Enough Wins" end
		return false, "Save is awaiting confirmation. Try again shortly."
	end
	syncOwnedAttribute(player)
	syncEquippedAttributes(player)
	return true
end

local function initializeLegacyEquipState(player)
	local folder = getOwnedFolder(player)
	if not folder or getTrueBool(folder, EQUIP_STATE_INITIALIZED_NAME) then return end
	local ok, message = commitFlight(player, {{kind="SetAbilityEquipped", equipped=ownsFlight(player)}}, "flight_equip_migration")
	if not ok then warn("[FlightAbility] " .. tostring(message)) end
end

local function setFlightEquipped(player, equipped)
	if not ownsFlight(player) then return false, "Flight is not owned" end
	local ok, message = commitFlight(player, {{kind="SetAbilityEquipped", equipped=equipped}}, "flight_equip:" .. tostring(equipped))
	return ok, if ok then (equipped and "Flight Equipped" or "Flight Unequipped") else message
end

local function grantAndEquipFlight(player, reason)
	if not waitForData(player) then return false, "Data is still loading" end
	local owned = permanentlyOwnsFlight(player)
	local initialized = getTrueBool(getOwnedFolder(player), EQUIP_STATE_INITIALIZED_NAME)
	-- Rechecking a previously purchased pass must preserve the saved Unequip choice.
	if owned and initialized and reason == "flight_gamepass_on_join" then
		syncOwnedAttribute(player); syncEquippedAttributes(player)
		return true
	end
	local ok, message = commitFlight(player, {
		{kind="GrantUpgrade", upgradeId=UPGRADE_NAME},
		{kind="SetAbilityEquipped", equipped=true},
	}, reason or "flight_grant")
	if ok then
		player:SetAttribute("FlightAbilityGrantPending", nil)
		sendState(player, "Flight Purchased & Equipped!")
	else
		sendState(player, message)
	end
	return ok, message
end

_G.SpeedsterGrantFlight = grantAndEquipFlight

local function buyWithWins(player)
	if purchaseBusy[player] then return end
	purchaseBusy[player] = true
	local ran, ok, message = pcall(function()
		if permanentlyOwnsFlight(player) then return true, "Flight Owned" end
		local purchased, failure = commitFlight(player, {
			{kind="PurchaseUpgrade", upgradeId=UPGRADE_NAME, cost=WINS_COST},
			{kind="SetAbilityEquipped", equipped=true},
		}, "flight_wins_purchase")
		return purchased, if purchased then "Flight Purchased & Equipped!" else failure
	end)
	purchaseBusy[player] = nil
	if not ran then warn("[FlightAbility] Purchase failed: " .. tostring(ok)) end
	sendState(player, if ran then message else "Purchase could not be confirmed. Try again shortly.")
end

AbilityShopAction.OnServerEvent:Connect(function(player, action, abilityId)
	if type(action) ~= "string" or #action > 32 then return end
	if abilityId ~= nil and abilityId ~= "Flight" then return end
	if not RateLimiter.Allow(player, "AbilityShopAction", 0.15) then return end
	if player:GetAttribute("DataLoaded") ~= true then return end
	abilityId = abilityId or "Flight"
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
		if grantAndEquipFlight(player, "flight_gamepass_purchase") then
			print("[FlightAbility] Flight GamePass granted to " .. player.Name)
		end
	end
end)

FlightAbilityState.OnServerEvent:Connect(function(player, active, powered)
	if type(active) ~= "boolean" or type(powered) ~= "boolean" then return end
	if not RateLimiter.Allow(player, active and "FlightStartState" or "FlightStopState", 0.08) then return end
	if player:GetAttribute("DataLoaded") ~= true then active = false; powered = false end
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

	if player:GetAttribute("FlightAbilityActive") ~= active then player:SetAttribute("FlightAbilityActive", active) end
	if player:GetAttribute("FlightAbilityPowered") ~= powered then player:SetAttribute("FlightAbilityPowered", powered) end
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
end)

-- Authoritative watchdog for temporary flight expiration
task.spawn(function()
	while true do
		task.wait(1)
		local nowTime = os.time()
		for _, player in ipairs(Players:GetPlayers()) do
			local tempExpire = tonumber(player:GetAttribute("TemporaryFlightExpireUnix")) or 0
			if tempExpire > 0 and nowTime >= tempExpire then
				player:SetAttribute("TemporaryFlightExpireUnix", 0)
				local folder = getOwnedFolder(player)
				local flag = folder and folder:FindFirstChild(UPGRADE_NAME)
				local permanentOwned = flag ~= nil and flag:IsA("BoolValue") and flag.Value == true
				if not permanentOwned then
					player:SetAttribute("FlightAbilityOwned", false)
					player:SetAttribute("FlightAbilityEquipped", false)
					player:SetAttribute("FlightAbilityActive", false)
					player:SetAttribute("FlightAbilityPowered", false)
					player:SetAttribute("EquippedAbility", "")
					sendState(player, "Temporary Flight has expired.")
				else
					syncEquippedAttributes(player)
					sendState(player, "Temporary Flight ended (Permanent Flight active).")
				end
			end
		end
	end
end)

print("[World1FlightAbility] Server active | Remotes ready")