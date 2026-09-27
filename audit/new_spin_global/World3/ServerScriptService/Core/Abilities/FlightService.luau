-- Shared private service. Require is side-effect free; Start is idempotent.
local FlightService = {}
local state = "idle"
local failure

local function initialize()
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")
local ServerScriptService = game:GetService("ServerScriptService")
local DataService = require(ServerScriptService.Services.Data.DataService)
local RateLimiter = require(ServerScriptService.Services.ServerRateLimiter)

local Workspace = nil
pcall(function()
	Workspace = game:GetService("Workspace")
end)
if not Workspace then
	pcall(function()
		Workspace = workspace
	end)
end

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local FlightStamina = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FlightStamina"))
local WinsMath = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WinsMath"))
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
-- Flight is a traversal unlock, so its price rises with the permanent wins
-- multiplier instead of being erased by it (Shared.WinsMath). The quote the
-- client is shown and the amount the transaction charges BOTH come from here;
-- they must never be computed separately or the purchase silently misprices.
--
-- The multiplier comes from _G.SpeedsterGetPermanentWinsMultiplier, the same getter
-- TeleportSystem prices against, NOT from the attribute directly. The canonical
-- getter takes math.max(attribute, persisted profile); reading the attribute alone
-- would under-price Flight in the window after a join where the profile has loaded
-- but the attribute has not replicated yet.
local function flightWinsCost(player)
	local multiplier
	if type(_G.SpeedsterGetPermanentWinsMultiplier) == "function" then
		local ok, value = pcall(_G.SpeedsterGetPermanentWinsMultiplier, player)
		if ok then multiplier = value end
	end
	if type(multiplier) ~= "number" then
		return WinsMath.GetProgressionPriceFor(WINS_COST, player, Config.ProgressionPriceMultiplierExponent)
	end
	return WinsMath.GetProgressionPrice(WINS_COST, multiplier, Config.ProgressionPriceMultiplierExponent)
end
local GAMEPASS_ID = math.max(0, math.floor(tonumber(Config.AbilityFlightGamePassId or Config.AbilityFlightProductId) or 1978623069))
local PRODUCT_ID = GAMEPASS_ID
local ROBUX_PRICE = math.max(0, math.floor(tonumber(Config.AbilityFlightPriceRobux) or 799))
local EQUIP_MARKER_NAME = "__AbilityEquipped_Flight"
local EQUIP_STATE_INITIALIZED_NAME = "__AbilityEquipStateInitialized"
local purchaseBusy = {}

local function isBarrierPart(part)
	if not part or not part:IsA("BasePart") then return false end
	if part:GetAttribute("IsBarrier") == true or part:GetAttribute("World2WallFlightBarrier") == true then
		return true
	end
	local name = part.Name:lower()
	if name == "barrier" or name == "barriers" or name == "wallflightbarrier" then
		return true
	end
	local parent = part.Parent
	if parent and (parent.Name:lower() == "barriers" or parent.Name == "World2WallFlightBarriers_Runtime") then
		return true
	end
	return false
end

local function forceStopFlightServer(player, character)
	player:SetAttribute("FlightAbilityActive", false)
	player:SetAttribute("FlightAbilityPowered", false)
	player:SetAttribute("LastBarrierTouchTime", os.clock())

	if character and character.Parent then
		local root = character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local vel = root:FindFirstChild("FlightAbilityVelocity")
			if vel then vel:Destroy() end
			local att = root:FindFirstChild("FlightAbilityAttachment")
			if att then att:Destroy() end
			local orient = root:FindFirstChild("FlightAbilityOrientation")
			if orient then orient:Destroy() end

			local currentVel = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(0, math.min(currentVel.Y, 0), 0)
			root.AssemblyAngularVelocity = Vector3.zero
		end
	end

	FlightAbilityState:FireClient(player, false, false)
end

local function isCharacterTouchingBarrier(character)
	if not character or not character.Parent then return false end
	for _, child in ipairs(character:GetDescendants()) do
		if child:IsA("BasePart") then
			local parts = nil
			local ok = pcall(function()
				parts = Workspace:GetPartsInPart(child)
			end)
			if not ok or not parts then
				pcall(function()
					parts = child:GetTouchingParts()
				end)
			end
			if parts then
				for _, part in ipairs(parts) do
					if isBarrierPart(part) then
						return true
					end
				end
			end
		end
	end
	return false
end

local function setupBarrier(barrier)
	if not isBarrierPart(barrier) then return end
	pcall(function()
		barrier:SetAttribute("IsBarrier", true)
	end)
	barrier.Touched:Connect(function(hit)
		local character = hit.Parent
		local hitPlayer = character and Players:GetPlayerFromCharacter(character)
		if not hitPlayer and character and character.Parent then
			hitPlayer = Players:GetPlayerFromCharacter(character.Parent)
			if hitPlayer then
				character = character.Parent
			end
		end
		if not hitPlayer then return end

		hitPlayer:SetAttribute("LastBarrierTouchTime", os.clock())
		if hitPlayer:GetAttribute("FlightAbilityActive") == true then
			forceStopFlightServer(hitPlayer, character)
		end
	end)
end

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
			WinsCost = flightWinsCost(player),
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
			{kind="PurchaseUpgrade", upgradeId=UPGRADE_NAME, cost=flightWinsCost(player)},
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
		if player:GetAttribute("FlightAbilityActive") == true or player:GetAttribute("FlightAbilityPowered") == true then
			player:SetAttribute("FlightAbilityActive", false)
			player:SetAttribute("FlightAbilityPowered", false)
		end
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
	local charRagdolled = character and type(character.GetAttribute) == "function" and (character:GetAttribute("Ragdolled") == true or character:GetAttribute("Dead") == true)
	local playerRagdolled = player and type(player.GetAttribute) == "function" and (player:GetAttribute("Ragdolled") == true or player:GetAttribute("Dead") == true)
	local isRagdolledOrDead = not humanoid or humanoid.Health <= 0
		or humanoid.PlatformStand == true
		or charRagdolled == true
		or playerRagdolled == true
	if isRagdolledOrDead then
		active = false
		powered = false
	end
	local lastBarrierTouch = tonumber(player:GetAttribute("LastBarrierTouchTime")) or 0
	if active and (os.clock() - lastBarrierTouch < 0.5 or isCharacterTouchingBarrier(character)) then
		active = false
		powered = false
	end
	local readStamina = _G.SpeedsterGetBoostStamina
	local stamina
	if type(readStamina) == "function" then
		stamina = tonumber(readStamina(player))
	else
		-- Compatibility for the legacy backend, which publishes every frame.
		stamina = tonumber(player:GetAttribute("TrueBoostStamina"))
	end
	if stamina == nil or stamina ~= stamina or math.abs(stamina) == math.huge then stamina = 0 end
	-- A share of this player's own bar, not a flat number: suits range from 5 to
	-- 60 stamina and a flat threshold locked the small ones out of flight entirely.
	local maxStamina = tonumber(player:GetAttribute("TrueBoostStaminaMax"))
		or tonumber(Config.BoostStaminaDisplayBase) or 17
	local minimum = FlightStamina.MinimumToPower(Config, maxStamina)

	if active then
		local wasActive = player:GetAttribute("FlightAbilityActive") == true
		if not wasActive and stamina <= minimum then
			active = false
			powered = false
		end
	end

	if powered then
		if stamina <= minimum then
			powered = false
		end
	end
	-- Gliding costs stamina too, so an exhausted player drops out of flight here
	-- rather than coasting indefinitely. Server authority, not just the client.
	if active and stamina <= 0 and FlightStamina.GlideDrainPerSecond(Config, maxStamina) > 0 then
		active = false
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

if Workspace and type(Workspace.GetDescendants) == "function" then
	local barrierCount = 0
	for _, desc in ipairs(Workspace:GetDescendants()) do
		if desc:IsA("BasePart") and isBarrierPart(desc) then
			setupBarrier(desc)
			barrierCount += 1
		end
	end

	if Workspace.DescendantAdded then
		Workspace.DescendantAdded:Connect(function(desc)
			if desc:IsA("BasePart") and isBarrierPart(desc) then
				setupBarrier(desc)
			end
		end)
	end

	print("[FlightService] Server active | Remotes ready | Monitored barriers: " .. tostring(barrierCount))
else
	print("[FlightService] Server active | Remotes ready")
end
end

function FlightService.Start()
 if state == "started" or state == "starting" then return end
 if state == "failed" then error(failure, 2) end
 state = "starting"
 local ok, reason = pcall(initialize)
 if not ok then
  -- Do not retry partially connected startup and duplicate purchase handlers.
  state = "failed"
  failure = "[FlightService] startup failed: " .. tostring(reason)
  error(failure, 2)
 end
 state = "started"
end

return FlightService
