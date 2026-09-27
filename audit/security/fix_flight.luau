local fs=require('@lune/fs')
local function replaceRange(s,first,last,replacement)
	local a=assert(s:find(first,1,true),first);local b=assert(s:find(last,a+1,true),last)
	return s:sub(1,a-1)..replacement..'\n\n'..s:sub(b)
end
for _,world in {'World1','World2'} do
	local path='audit/merged/'..world..'/ServerScriptService/Gameplay/'..world..'FlightAbility.luau'
	local s=fs.readFile(path)
	s=s:gsub('local MarketplaceService = game:GetService%("MarketplaceService"%)','local MarketplaceService = game:GetService("MarketplaceService")\nlocal ServerScriptService = game:GetService("ServerScriptService")\nlocal DataService = require(ServerScriptService.Services.Data.DataService)\nlocal RateLimiter = require(ServerScriptService.Services.ServerRateLimiter)',1)
	s=replaceRange(s,'local function saveEquipState','AbilityShopAction.OnServerEvent',[[local function commitFlight(player, commands, fingerprint)
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
	local owned = ownsFlight(player)
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
		if ownsFlight(player) then return true, "Flight Owned" end
		local purchased, failure = commitFlight(player, {
			{kind="PurchaseUpgrade", upgradeId=UPGRADE_NAME, cost=WINS_COST},
			{kind="SetAbilityEquipped", equipped=true},
		}, "flight_wins_purchase")
		return purchased, if purchased then "Flight Purchased & Equipped!" else failure
	end)
	purchaseBusy[player] = nil
	if not ran then warn("[FlightAbility] Purchase failed: " .. tostring(ok)) end
	sendState(player, if ran then message else "Purchase could not be confirmed. Try again shortly.")
end]])
	s=s:gsub('action = tostring%(action or ""%)\n\tabilityId = tostring%(abilityId or "Flight"%)','if type(action) ~= "string" or #action > 32 then return end\n\tif abilityId ~= nil and abilityId ~= "Flight" then return end\n\tif not RateLimiter.Allow(player, "AbilityShopAction", 0.15) then return end\n\tif player:GetAttribute("DataLoaded") ~= true then return end\n\tabilityId = abilityId or "Flight"',1)
	s=s:gsub('FlightAbilityState.OnServerEvent:Connect%(function%(player, active, powered%)\n','FlightAbilityState.OnServerEvent:Connect(function(player, active, powered)\n\tif type(active) ~= "boolean" or type(powered) ~= "boolean" then return end\n\tif active and not RateLimiter.Allow(player, "FlightAbilityState", 0.08) then return end\n\tif player:GetAttribute("DataLoaded") ~= true then active = false; powered = false end\n',1)
	s=s:gsub('player:SetAttribute%("FlightAbilityActive", active%)\n\tplayer:SetAttribute%("FlightAbilityPowered", powered%)','if player:GetAttribute("FlightAbilityActive") ~= active then player:SetAttribute("FlightAbilityActive", active) end\n\tif player:GetAttribute("FlightAbilityPowered") ~= powered then player:SetAttribute("FlightAbilityPowered", powered) end',1)
	fs.writeFile(path,s)
end
