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

local TrailShopAction = getOrCreateRemote("TrailShopAction")
local TrailShopUpdate = getOrCreateRemote("TrailShopUpdate")

local TRAIL_ENTRIES = Catalog.GetSortedShopEntries("Trail")
local BLUE_TRAIL_ENTRY = Catalog.GetEntry("Trail", "Trail07")
local BLUE_TRAIL_ROBUX_ID = BLUE_TRAIL_ENTRY and tonumber(BLUE_TRAIL_ENTRY.RobuxPurchaseId) or 0
local BLUE_TRAIL_PURCHASE_TYPE = BLUE_TRAIL_ENTRY and tostring(BLUE_TRAIL_ENTRY.RobuxPurchaseType or "") or ""

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

	local ownedFolder = dataFolder:FindFirstChild("OwnedTrails")
	if not ownedFolder then
		ownedFolder = Instance.new("Folder")
		ownedFolder.Name = "OwnedTrails"
		ownedFolder.Parent = dataFolder
	end

	return ownedFolder
end

local function getEquippedTrailValue(player)
	local dataFolder = getDataFolder(player)
	if not dataFolder then
		return nil
	end

	local value = dataFolder:FindFirstChild("EquippedTrail")
	if not value then
		value = Instance.new("StringValue")
		value.Name = "EquippedTrail"
		value.Value = ""
		value.Parent = dataFolder
	end

	return value
end

local function ownsTrail(player, trailId)
	local folder = getOwnedFolder(player)
	local flag = folder and folder:FindFirstChild(trailId)
	if flag ~= nil and flag.Value == true then
		return true
	end
	if type(_G.SpeedsterHasTrail) == "function" and _G.SpeedsterHasTrail(player, trailId) == true then
		if folder and not flag then
			local v = Instance.new("BoolValue")
			v.Name = trailId
			v.Value = true
			v.Parent = folder
		end
		return true
	end
	local entry = Catalog.GetEntry("Trail", trailId)
	local passId = entry and tonumber(entry.RobuxPurchaseId)
	if passId and passId > 0 and (passId < 3000000000 or entry.RobuxPurchaseType == "GamePass" or entry.RobuxPurchaseType == "Auto") then
		local ok, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
		end)
		if ok and owns == true then
			setTrailOwned(player, trailId)
			return true
		end
	end
	return false
end

local function setTrailOwned(player, trailId)
	local folder = getOwnedFolder(player)
	if folder then
		local value = folder:FindFirstChild(trailId)
		if not value then
			value = Instance.new("BoolValue")
			value.Name = trailId
			value.Parent = folder
		end
		value.Value = true
	end

	if type(_G.SpeedsterUnlockTrail) == "function" then
		_G.SpeedsterUnlockTrail(player, trailId)
	end
end

local function applyTrail(player, trailId)
	local entry = Catalog.GetEntry("Trail", trailId)
	local multiplier = 1
	if entry then
		multiplier = tonumber(entry.SpeedMultiplier) or 1
	end

	                                                                          
	                                             
	local success, message = CosmeticService.EquipTrail(player, trailId or "")
	if not success then
		return false, message
	end

	if type(_G.SpeedsterEquipTrail) == "function" then
		_G.SpeedsterEquipTrail(player, trailId or "", multiplier)
	else
		player:SetAttribute("TrailSpeedGainMultiplier", multiplier)
	end

	return true, message
end

local function collectOwnedMap(player)
	local map = {}
	for _, entry in ipairs(TRAIL_ENTRIES) do
		map[entry.Id] = ownsTrail(player, entry.Id)
	end
	return map
end

local function buildState(player, message)
	local winsValue = getWinsValue(player)
	local equippedValue = getEquippedTrailValue(player)

	return {
		Trails = TRAIL_ENTRIES,
		Owned = collectOwnedMap(player),
		EquippedTrail = equippedValue and equippedValue.Value or "",
		Wins = winsValue and (tonumber(winsValue.Value) or 0) or 0,
		Message = message,
	}
end

local function sendState(player, message)
	TrailShopUpdate:FireClient(player, buildState(player, message))
end

_G.SpeedsterRefreshTrailShop = function(player, message)
	if player and player.Parent then
		sendState(player, message)
	end
end

local function saveCosmeticOwnership(player, reason)
	local savePlayer = _G.SpeedsterSavePlayer
	if type(savePlayer) == "function" then
		task.defer(savePlayer, player, reason or "cosmetic_robux_ownership")
	end
end

local function grantTrailGamePassOwnership(player, trailId, message)
	if not player or not player.Parent or not trailId or trailId == "" then
		return
	end
	local entry = Catalog.GetEntry("Trail", trailId)
	if not ownsTrail(player, trailId) then
		setTrailOwned(player, trailId)
	end
	local equippedValue = getEquippedTrailValue(player)
	if equippedValue then
		equippedValue.Value = trailId
	end
	applyTrail(player, trailId)
	saveCosmeticOwnership(player, "trail_gamepass_unlock_" .. tostring(trailId))
	sendState(player, message or (entry and ("Bought " .. tostring(entry.DisplayName) .. " with Robux") or "Trail unlocked"))
end

local function syncAllTrailGamePasses(player)
	for _, entry in ipairs(TRAIL_ENTRIES) do
		local passId = tonumber(entry.RobuxPurchaseId)
		if passId and passId > 0 and (passId < 3000000000 or entry.RobuxPurchaseType == "GamePass" or entry.RobuxPurchaseType == "Auto") then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
			end)
			if ok and owns == true then
				setTrailOwned(player, entry.Id)
			end
		end
	end
end

local function syncPlayerTrail(player)
	local dataFolder = getDataFolder(player)
	if not dataFolder then
		return
	end

	local equippedValue = getEquippedTrailValue(player)
	local trailId = equippedValue and equippedValue.Value or ""
	if trailId == "" then
		applyTrail(player, "")
		return
	end

	if Catalog.IsValid("Trail", trailId) and ownsTrail(player, trailId) then
		applyTrail(player, trailId)
	else
		if equippedValue then
			equippedValue.Value = ""
		end
		applyTrail(player, "")
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

		syncAllTrailGamePasses(player)
		syncPlayerTrail(player)
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

local function handleBuy(player, trailId)
	local entry = Catalog.GetEntry("Trail", trailId)
	if not entry or entry.ShopEnabled ~= true then
		sendState(player, "Trail not found")
		return
	end

	if ownsTrail(player, trailId) then
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
	table.insert(commands,{kind="GrantTrail",trailId=trailId})
	table.insert(commands,{kind="EquipTrail",trailId=trailId})
	local result=DataService.Commit(handle,{operationId="buy:Trail:"..trailId,receiptId="owned:Trail:"..trailId,fingerprint="buy:Trail:"..trailId,commands=commands})
	if result.kind~="Committed" and result.kind~="AlreadyCommitted" then
		sendState(player,"Purchase is awaiting save confirmation. Try again shortly.");return
	end

	local equippedValue = getEquippedTrailValue(player)
	if equippedValue then
		equippedValue.Value = trailId
	end

	local applied, applyMessage = applyTrail(player, trailId)
	if not applied then
		sendState(player, "Bought, but visual equip failed")
		warn("[TrailShopSystem] Visual equip failed: " .. tostring(applyMessage))
		return
	end
	sendState(player, "Bought " .. tostring(entry.DisplayName))
end

local function handleEquip(player, trailId)
	local entry = Catalog.GetEntry("Trail", trailId)
	if not entry or entry.ShopEnabled ~= true then
		sendState(player, "Trail not found")
		return
	end

	if not ownsTrail(player, trailId) then
		sendState(player, "Buy it first")
		return
	end

	local equippedValue = getEquippedTrailValue(player)
	if equippedValue then
		equippedValue.Value = trailId
	end

	local applied, applyMessage = applyTrail(player, trailId)
	if not applied then
		sendState(player, "Equip failed - try again")
		warn("[TrailShopSystem] Equip failed: " .. tostring(applyMessage))
		return
	end
	sendState(player, "Equipped " .. tostring(entry.DisplayName))
end

local function handleUnequip(player, trailId)
	local equippedValue = getEquippedTrailValue(player)
	if equippedValue then
		equippedValue.Value = ""
	end
	local applied, applyMessage = applyTrail(player, "")
	if not applied then
		sendState(player, "Unequip failed - try again")
		return
	end
	sendState(player, "Trail unequipped")
end

TrailShopAction.OnServerEvent:Connect(function(player, action, trailId)
	if type(action) ~= "string" then
		return
	end
	if type(trailId) ~= "string" then
		trailId = ""
	end

	if action == "RequestState" then
		sendState(player)
	elseif action == "Buy" then
		handleBuy(player, trailId)
	elseif action == "Equip" then
		handleEquip(player, trailId)
	elseif action == "Unequip" then
		handleUnequip(player, trailId)
	end
end)


MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, wasPurchased)
	if not wasPurchased then return end
	local numericPassId = tonumber(gamePassId)
	for _, entry in ipairs(TRAIL_ENTRIES) do
		if tonumber(entry.RobuxPurchaseId) == numericPassId then
			grantTrailGamePassOwnership(player, entry.Id, "Bought " .. tostring(entry.DisplayName) .. " with Robux")
			return
		end
	end
end)

for _, player in ipairs(Players:GetPlayers()) do
	setupPlayer(player)
end
Players.PlayerAdded:Connect(setupPlayer)

print("[TrailShopSystem] V306FJ loaded. Trail shop equip state now stays synchronized with visible VFX.")
