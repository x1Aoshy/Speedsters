--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TextService = game:GetService("TextService")
local MessagingService = game:GetService("MessagingService")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")

local AdminBannerConfig = require(ReplicatedStorage:WaitForChild("AdminBannerConfig"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local PotionServer = require(ServerScriptService:WaitForChild("Services"):WaitForChild("PotionServer"))
local DataService = require(ServerScriptService:WaitForChild("Services"):WaitForChild("Data"):WaitForChild("DataService"))
local CodesCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Catalogs"):WaitForChild("CodesCatalog"))

local Validation = require(ServerScriptService.Admin.AdminRequestValidation)
local RateLimiter = require(ServerScriptService.Services.ServerRateLimiter)
local acceptCodeEvent = Validation.NewEventCache()

local WORLD_2_PLACE_ID = 116359653478954
local MESSAGING_TOPIC = "SpeedsterGlobalAnnouncements_v1"
local CODES_MESSAGING_TOPIC = "SpeedsterGlobalCodes_v1"

local ALLOWED_USER_IDS: { [number]: boolean } = {
	[767108248] = true,
}

local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10) or ReplicatedStorage
local function ensureRemote(name: string): RemoteEvent
	local remote = Remotes:FindFirstChild(name)
	if not remote or not remote:IsA("RemoteEvent") then
		if remote then remote:Destroy() end
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = Remotes
	end
	return remote
end

local AdminPanelAction = ensureRemote("AdminPanelAction")
local AdminPanelStatus = ensureRemote("AdminPanelStatus")
local DisplayRemote = ensureRemote("DisplayGlobalAnnouncement")

local function isAllowed(player: Player): boolean
	if RunService:IsStudio() then return true end
	if ALLOWED_USER_IDS[player.UserId] == true then return true end
	if AdminBannerConfig.IsAdmin(player.UserId) then return true end
	if game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId then return true end
	if game.CreatorType == Enum.CreatorType.Group and game.CreatorId > 0 then
		local ok, rank = pcall(function() return player:GetRankInGroup(game.CreatorId) end)
		if ok and rank >= 254 then return true end
	end
	return false
end

local function sendToast(player: Player, success: boolean, message: string)
	if player and player.Parent == Players then
		AdminPanelStatus:FireClient(player, {
			kind = "Toast",
			success = success,
			message = message,
		})
	end
end

local function resolveTargets(admin: Player, rawTarget: any): { Player }
	if rawTarget == "All" or rawTarget == "all" then
		return Players:GetPlayers()
	elseif rawTarget == "Self" or rawTarget == "self" or rawTarget == nil then
		return { admin }
	else
		local numId = tonumber(rawTarget)
		if Validation.Finite(numId) and numId>0 and numId%1==0 then
			local p = Players:GetPlayerByUserId(numId)
			if p then return { p } end
		end
		if typeof(rawTarget) == "string" then
			local lower = string.lower(rawTarget)
			for _, p in ipairs(Players:GetPlayers()) do
				if string.lower(p.Name) == lower or string.lower(p.DisplayName) == lower then
					return { p }
				end
			end
		end
	end
	return {}
end

local function filterText(player: Player, text: string): string?
 return Validation.FilterBroadcast(TextService,player.UserId,text)
end

local function commitAdmin(target, commands, reason)
 if target.Parent~=Players or target:GetAttribute("DataLoaded")~=true then return false end
 local handle=DataService.GetHandle(target.UserId)
 if not handle then return false end
 local ok,result=pcall(function()
  return DataService.Commit(handle,{operationId=DataService.NewOperationId(),fingerprint=reason,commands=commands})
 end)
 return ok and (result.kind=="Committed" or result.kind=="AlreadyCommitted")
end

local function reportTargets(admin, count, total, description)
 sendToast(admin,count>0,description..": "..count.."/"..total.." confirmed")
end

-- State for Auto Rebirths per admin
type AutoRebirthConfig = {
	enabled: boolean,
	mode: "Threshold" | "Forced",
	lastRun: number,
}
local autoRebirthAdmins: { [number]: AutoRebirthConfig } = {}

-- Auto Rebirth loop
task.spawn(function()
	while true do
		task.wait(1.0)
		for userId, cfg in pairs(autoRebirthAdmins) do
			if cfg.enabled then
				local player = Players:GetPlayerByUserId(userId)
				if player and player.Parent == Players then
					local now = os.clock()
					if cfg.mode == "Forced" then
						if now - cfg.lastRun >= 3.0 then
							cfg.lastRun = now
							if type(_G.SpeedsterPerformRebirth) == "function" then
								_G.SpeedsterPerformRebirth(player, true)
							end
						end
					else
						-- Threshold mode: only rebirth if player meets level requirement
						local level = tonumber(player:GetAttribute("Level")) or 1
						local reqLevel = tonumber(player:GetAttribute("NextRebirthLevelRequired")) or 5
						if level >= reqLevel and now - cfg.lastRun >= 1.5 then
							cfg.lastRun = now
							if type(_G.SpeedsterPerformRebirth) == "function" then
								_G.SpeedsterPerformRebirth(player, false)
							end
						end
					end
				else
					autoRebirthAdmins[userId] = nil
				end
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	autoRebirthAdmins[player.UserId] = nil
end)

-- Apply pass state (enable or disable) for a target player
local function applyPassToggle(target: Player, passId: string, enabled: boolean): boolean
 local valid={VIP=true,Flight=true,TwoXSpeed=true,TwoXVictory=true,InfiniteRevives=true,DarkZonic=true,All=true}
 if not valid[passId] then return false end
 local commands={}
 for _,id in {"VIP","Flight","TwoXSpeed","TwoXVictory","InfiniteRevives","DarkZonic"} do
  if passId==id or passId=="All" then
   if id=="DarkZonic" then
    table.insert(commands,{kind=if enabled then "GrantSkin" else "RemoveSkin",skinId=id})
   else
    table.insert(commands,{kind=if enabled then "GrantUpgrade" else "RemoveUpgrade",upgradeId=id})
   end
   if id=="Flight" then table.insert(commands,{kind="SetAbilityEquipped",equipped=enabled}) end
   if id=="TwoXSpeed" then table.insert(commands,{kind="SetPersistent",key="PermanentBaseSpeedMultiplier",value=enabled and 2 or 1}) end
   if id=="TwoXVictory" then table.insert(commands,{kind="SetPersistent",key="PermanentWinsMultiplier",value=enabled and 2 or 1}) end
  end
 end
 if not commitAdmin(target,commands,"admin_pass:"..passId..":"..tostring(enabled)) then return false end
 -- Session flags are applied only after the durable profile mutation confirms.
 if passId=="VIP" or passId=="All" then
  target:SetAttribute("VIPGamepassOwned",enabled)
  target:SetAttribute("VIPSpeedGainMultiplier",enabled and (tonumber(Config.VipSpeedGainMultiplier) or 2) or 1)
  target:SetAttribute("VIPWinsMultiplier",enabled and (tonumber(Config.VipWinsMultiplier) or 2) or 1)
 end
 if passId=="TwoXSpeed" or passId=="All" then target:SetAttribute("GamepassSpeedGainMultiplier",enabled and 2 or 1) end
 if passId=="TwoXVictory" or passId=="All" then
  target:SetAttribute("DoubleWinsPadUnlocked",enabled);target:SetAttribute("TwoXVictoryOwned",enabled)
 end
 if passId=="InfiniteRevives" or passId=="All" then
  target:SetAttribute("InfiniteRevivesOwned",enabled);target:SetAttribute("InfiniteRevivesOwnershipChecked",true)
 end
 if passId=="DarkZonic" or passId=="All" then target:SetAttribute("DarkZonicOwned",enabled) end
 if type(_G.SpeedsterApplyWalkSpeed)=="function" then _G.SpeedsterApplyWalkSpeed(target) end
 if type(_G.SpeedsterRefreshAbilityShop)=="function" then _G.SpeedsterRefreshAbilityShop(target) end
 return true
end

local function redeemCodeForPlayers(codeName: string, force: boolean, senderName: string, eventId: string?): (number, number)
	local grantedCount = 0
	local alreadyCount = 0
	if type(_G.SpeedsterRedeemCode) ~= "function" then
		return 0, 0
	end
	for _, target in ipairs(Players:GetPlayers()) do
		local ok, msg = _G.SpeedsterRedeemCode(target, codeName, force, senderName, eventId)
		if ok then
			grantedCount += 1
		elseif msg == "AlreadyClaimed" then
			alreadyCount += 1
		end
	end
	return grantedCount, alreadyCount
end

pcall(function()
	MessagingService:SubscribeAsync(CODES_MESSAGING_TOPIC, function(message)
		local data = message.Data
		if Validation.Payload(data) and type(data.Code)=="string" and #data.Code<=64 then
   if data.OriginJobId==game.JobId then return end
   if not Validation.Finite(data.Timestamp) or math.abs(os.time()-data.Timestamp)>600 then return end
   if not acceptCodeEvent(data.EventId,os.time()) then return end
			redeemCodeForPlayers(data.Code, data.Force == true, data.SenderName or "Admin", data.EventId)
		end
	end)
end)

-- Server request listener
AdminPanelAction.OnServerEvent:Connect(function(player: Player, payload: any)
 if not RateLimiter.Allow(player,"AdminPanelRequest",0.25) then return end
 if not Validation.Payload(payload) or not isAllowed(player) then return end
 local action=payload.action
 if type(action)~="string" or #action>40 then return end
 if action~="CheckPermission" and not RateLimiter.Allow(player,"AdminPanelMutation",1) then return end
 if payload.target~=nil and #resolveTargets(player,payload.target)==0 then sendToast(player,false,"Target not found");return end

	if action == "CheckPermission" then
		local boostExp = tonumber(Workspace:GetAttribute("ServerBoostExpiresUnix")) or 0
		local remainingBoost = math.max(0, boostExp - os.time())
		local cfg = autoRebirthAdmins[player.UserId]
		AdminPanelStatus:FireClient(player, {
			kind = "Permission",
			allowed = true,
			displayName = player.DisplayName,
			serverBoostRemaining = remainingBoost,
			autoRebirthEnabled = cfg and cfg.enabled == true or false,
			autoRebirthMode = cfg and cfg.mode or "Threshold",
			world2Unlocked = player:GetAttribute("World2Unlocked") == true,
		})

	elseif action == "ServerBoost" then
		local minutes = math.clamp(math.floor(tonumber(payload.minutes) or 15), 1, 240)
		local mult = 2
		local grant = PotionServer.GrantServerBoost(minutes, mult, player.DisplayName)
		if grant and grant.Notify then
			grant.Notify()
		end

		-- Also give all players 2x Wins Potion for the same duration
		for _, p in ipairs(Players:GetPlayers()) do
			pcall(function()
				local winGrant = PotionServer.GrantWinsPotion(p, minutes, mult)
				if winGrant and winGrant.Notify then
					winGrant.Notify()
				end
			end)
		end

		sendToast(player, true, "⚡ ¡Boost 2x Speed & 2x Wins activado para el servidor por " .. minutes .. "m!")

 elseif action == "GekoFlyGiveaway" then
  local targets=resolveTargets(player,payload.target or "All")
  local minutes=math.clamp(math.floor(tonumber(payload.minutes) or 20),1,120)
  local confirmed=0
  for _,target in ipairs(targets) do
   if commitAdmin(target,{
    {kind="GrantExact",stat="Speed",amount=800000},
    {kind="GrantExact",stat="Wins",amount=20000},
    {kind="GrantBuff",grant={kind="TemporaryFlight",addedSeconds=minutes*60}},
   },"admin_gekkoh:"..minutes) then
    confirmed+=1
    if type(_G.SpeedsterApplyWalkSpeed)=="function" then _G.SpeedsterApplyWalkSpeed(target) end
    if type(_G.SpeedsterRefreshAbilityShop)=="function" then _G.SpeedsterRefreshAbilityShop(target) end
    sendToast(target,true,"Gekkoh gave you +800K Speed, +20K Wins and "..minutes.."m Flight!")
   end
  end
  reportTargets(player,confirmed,#targets,"Gekkoh giveaway")

 elseif action=="GiveRebirths" or action=="GiveStats" then
  if action=="GiveStats" and payload.stat~="Speed" and payload.stat~="Wins" then sendToast(player,false,"Invalid stat");return end
  local stat=if action=="GiveRebirths" then "Rebirths" else payload.stat
  local limit=if stat=="Rebirths" then 10000 else 1e14
  local amount=math.clamp(math.floor(tonumber(payload.amount) or 1),1,limit)
  local targets=resolveTargets(player,payload.target)
  local confirmed=0
  for _,target in ipairs(targets) do
   if commitAdmin(target,{{kind="GrantExact",stat=stat,amount=amount}},"admin_grant:"..stat..":"..amount) then
    confirmed+=1
    if type(_G.SpeedsterApplyWalkSpeed)=="function" then _G.SpeedsterApplyWalkSpeed(target) end
    if target~=player then sendToast(target,true,"Admin granted +"..amount.." "..stat) end
   end
  end
  reportTargets(player,confirmed,#targets,"+"..amount.." "..stat)

 elseif action=="TogglePass" then
  if type(payload.pass)~="string" or type(payload.enabled)~="boolean" then sendToast(player,false,"Invalid pass request");return end
  local targets=resolveTargets(player,payload.target)
  local confirmed=0
  for _,target in ipairs(targets) do
   if applyPassToggle(target,payload.pass,payload.enabled) then
    confirmed+=1
    if target~=player then sendToast(target,true,"Admin updated "..payload.pass) end
   end
  end
  reportTargets(player,confirmed,#targets,"Pass "..payload.pass)

	elseif action == "AutoRebirth" then
		local enabled = payload.enabled == true
		local mode = if payload.mode == "Forced" then "Forced" else "Threshold"

		autoRebirthAdmins[player.UserId] = {
			enabled = enabled,
			mode = mode,
			lastRun = 0,
		}

		local modeText = if mode == "Forced" then "Rápido (cada 3s, reinicia stats)" else "Al cumplir nivel requerido"
		sendToast(player, true, "🔄 Auto Rebirth: " .. (enabled and "ACTIVADO [" .. modeText .. "]" or "DESACTIVADO"))

	elseif action == "ManualRebirthReset" then
		if type(_G.SpeedsterPerformRebirth) == "function" then
			_G.SpeedsterPerformRebirth(player, true)
			sendToast(player, true, "✨ ¡Rebirth forzado completado! Stats reiniciados a 1 y +1 Rebirth.")
		else
			sendToast(player, false, "RebirthSystem no disponible.")
		end

 elseif action=="UnlockWorld2" then
  local enabled=payload.enabled~=false
  local targets=resolveTargets(player,payload.target)
  local confirmed=0
  for _,target in ipairs(targets) do
   if commitAdmin(target,{{kind="SetPersistent",key="World2Unlocked",value=enabled,allowFalse=true}},"admin_world2:"..tostring(enabled)) then confirmed+=1 end
  end
  reportTargets(player,confirmed,#targets,"World 2 "..(enabled and "unlocked" or "locked"))

	elseif action == "TeleportWorld2" or action == "TeleportWorld1" then
		if type(_G.SpeedsterAdminWorldTravel)=="function" then
			_G.SpeedsterAdminWorldTravel(player, action=="TeleportWorld2" and 2 or 1)
		else sendToast(player,false,"World travel is still loading") end

	elseif action == "BroadcastAnnouncement" then
		local rawMsg = type(payload.message)=="string" and payload.message or ""
		local trimmed = string.match(rawMsg, "^%s*(.-)%s*$") or ""
		if #trimmed == 0 then
			sendToast(player, false, "El mensaje no puede estar vacío.")
			return
		end
		if #trimmed > 250 then trimmed = string.sub(trimmed, 1, 250) end

		local filtered = filterText(player, trimmed)
		if not filtered then sendToast(player,false,"Text filtering unavailable; announcement was not sent");return end
		local annPayload = {
			Message = filtered,
			EventId=HttpService:GenerateGUID(false),
			OriginJobId=game.JobId,
			SenderName = player.DisplayName or player.Name,
			SenderId = player.UserId,
			Duration = 8,
			Timestamp = os.time(),
		}

		DisplayRemote:FireAllClients(annPayload)

		if not RunService:IsStudio() then
			task.spawn(function()
				pcall(function()
					MessagingService:PublishAsync(MESSAGING_TOPIC, annPayload)
				end)
			end)
		end

		sendToast(player, true, "📢 Global announcement broadcasted to all.")

	elseif action == "ActivateCode" then
		local rawCode = type(payload.code)=="string" and payload.code or ""
		local cleanCode = string.match(rawCode, "^%s*(.-)%s*$") or ""
		if #cleanCode == 0 then
			sendToast(player, false, "El código no puede estar vacío.")
			return
		end

		local definition = CodesCatalog.Get(cleanCode)
		if not definition then
			sendToast(player, false, "Código '" .. cleanCode .. "' no existe en el catálogo.")
			return
		end

		local scope = tostring(payload.scope or "Server")
		local force = payload.force == true
		local senderName = player.DisplayName or player.Name

		local codeEventId=HttpService:GenerateGUID(false)
		local granted, already = redeemCodeForPlayers(cleanCode, force, senderName, codeEventId)

		if scope == "Global" then
			local codePayload = {
				Code = cleanCode,
				EventId = codeEventId,
				OriginJobId = game.JobId,
				SenderName = senderName,
				SenderId = player.UserId,
				Force = force,
				Timestamp = os.time(),
			}

			if not RunService:IsStudio() then
				task.spawn(function()
					pcall(function()
						MessagingService:PublishAsync(CODES_MESSAGING_TOPIC, codePayload)
					end)
				end)
			end

			sendToast(player, true, "🌐 Código [" .. cleanCode .. "] ACTIVADO GLOBALMENTE (" .. granted .. " en este servidor)")
		else
			local resultMsg = "✅ Código [" .. cleanCode .. "] activado: " .. granted .. " otorgados"
			if already > 0 then
				resultMsg = resultMsg .. ", " .. already .. " ya lo tenían"
			end
			sendToast(player, true, resultMsg)
		end
	end
end)

print("[AdminPanelService] Loaded successfully. Authorized admins have full control.")
