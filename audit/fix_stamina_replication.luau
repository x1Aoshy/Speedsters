local fs=require('@lune/fs')
local function replace(s,a,b)
 local i,j=s:find(a,1,true); assert(i,'missing '..a)
 return s:sub(1,i-1)..b..s:sub(j+1)
end
for _,world in {'World1','World2'} do
 local path='audit/merged/'..world..'/ServerScriptService/Bootstrap.luau'
 local s=fs.readFile(path):gsub('\r\n','\n')
 s=replace(s,'local lastBoostUseAt: { [Player]: number } = {}',[[local lastBoostUseAt: { [Player]: number } = {}
local staminaPublicationByPlayer: { [Player]: { at: number, maximum: number, stamina: number } } = {}
local STAMINA_PUBLICATION_INTERVAL = 0.25]])
 local a=assert(s:find('local function syncBoostStaminaAttributes',1,true))
 local b=assert(s:find('-- 4. Listeners de Remotes',a,true))
 s=s:sub(1,a-1)..[[local function getCurrentBoostStamina(player: Player): (number, number)
	local maxStamina = getBoostMaxStamina(player)
	local stamina = math.clamp(boostStaminaByPlayer[player] or maxStamina, 0, maxStamina)
	boostStaminaByPlayer[player] = stamina
	return stamina, maxStamina
end

-- Server consumers must use runtime state, not the periodically replicated UI sample.
_G.SpeedsterGetBoostStamina = function(player: Player): number
	if player:GetAttribute("DataLoaded") ~= true then return 0 end
	local stamina = getCurrentBoostStamina(player)
	return stamina
end

local function syncBoostStaminaAttributes(player: Player, sampledAt: number?)
	local stamina, maxStamina = getCurrentBoostStamina(player)
	local now = sampledAt or os.clock()
	local previous = staminaPublicationByPlayer[player]
	local reachedBoundary = (stamina == 0 or stamina == maxStamina)
		and (previous == nil or previous.stamina ~= stamina)
	if previous and previous.maximum == maxStamina and not reachedBoundary
		and now - previous.at < STAMINA_PUBLICATION_INTERVAL then
		return
	end
	staminaPublicationByPlayer[player] = { at = now, maximum = maxStamina, stamina = stamina }
	local function publish(name: string, value: number)
		if player:GetAttribute(name) ~= value then player:SetAttribute(name, value) end
	end
	-- Keep compatibility aliases used by the authored HUD and flight controllers.
	publish("TrueBoostStaminaMax", maxStamina)
	publish("TrueBoostStamina", stamina)
	publish("BoostStaminaMaxInternal", maxStamina)
	publish("BoostStaminaDisplayMax", maxStamina)
	publish("BoostStamina", stamina)
end

]]..s:sub(b)
 s=replace(s,'lastBoostUseAt[player] = nil','lastBoostUseAt[player] = nil\n\tstaminaPublicationByPlayer[player] = nil')
 s=replace(s,[[			syncBoostStaminaAttributes(player)
			local maxStamina = getBoostMaxStamina(player)
			local stamina = boostStaminaByPlayer[player] or maxStamina]],[[			local stamina, maxStamina = getCurrentBoostStamina(player)]])
 s=replace(s,[[			player:SetAttribute("BoostStamina", stamina)
			player:SetAttribute("TrueBoostStamina", stamina)]],[[			syncBoostStaminaAttributes(player, now)]])
 fs.writeFile(path,s)
 path='audit/merged/'..world..'/ServerScriptService/Gameplay/'..world..'FlightAbility.luau'
 s=fs.readFile(path):gsub('\r\n','\n')
 s=replace(s,[[		local stamina = tonumber(player:GetAttribute("TrueBoostStamina"))
		if stamina == nil then stamina = 100 end]],[[		local readStamina = _G.SpeedsterGetBoostStamina
		local stamina
		if type(readStamina) == "function" then
			stamina = tonumber(readStamina(player))
		else
			-- Compatibility for the legacy backend, which publishes every frame.
			stamina = tonumber(player:GetAttribute("TrueBoostStamina"))
		end
		if stamina == nil or stamina ~= stamina or math.abs(stamina) == math.huge then stamina = 0 end]])
 fs.writeFile(path,s)
end

