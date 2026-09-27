local fs=require('@lune/fs')
local function replace(s,a,b) local x,y=s:find(a,1,true);assert(x,a);return s:sub(1,x-1)..b..s:sub(y+1) end
local function range(s,a,b,r) local x=s:find(a,1,true);assert(x,a);local y=s:find(b,x+1,true);assert(y,b);return s:sub(1,x-1)..r..'\n\n'..s:sub(y) end
for _,world in {'World1','World2'} do
 local path='audit/merged/'..world..'/ServerScriptService/Admin/AdminPanelService.luau'
 local s=fs.readFile(path)
 s=replace(s,'local WORLD_2_PLACE_ID', 'local Validation = require(ServerScriptService.Admin.AdminRequestValidation)\nlocal RateLimiter = require(ServerScriptService.Services.ServerRateLimiter)\nlocal acceptCodeEvent = Validation.NewEventCache()\n\nlocal WORLD_2_PLACE_ID')
 s=replace(s,'\treturn { admin }\nend','\treturn {}\nend')
 s=replace(s,'if numId then','if Validation.Finite(numId) and numId>0 and numId%1==0 then')
 s=range(s,'local function filterText','-- State for Auto Rebirths', [=[local function filterText(player: Player, text: string): string?
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
end]=])
 s=range(s,'local function applyPassToggle','local function redeemCodeForPlayers', [=[local function applyPassToggle(target: Player, passId: string, enabled: boolean): boolean
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
end]=])
 s=replace(s,'if type(data) == "table" and type(data.Code) == "string" then\n\t\t\tif data.SenderId and data.Timestamp and (os.time() - data.Timestamp < 3) then\n\t\t\t\tlocal localSender = Players:GetPlayerByUserId(data.SenderId)\n\t\t\t\tif localSender then return end\n\t\t\tend', [=[if Validation.Payload(data) and type(data.Code)=="string" and #data.Code<=64 then
   if data.OriginJobId==game.JobId then return end
   if not Validation.Finite(data.Timestamp) or math.abs(os.time()-data.Timestamp)>600 then return end
   if not acceptCodeEvent(data.EventId,os.time()) then return end]=])
 s=replace(s,'\tif not isAllowed(player) then return end\n\tif typeof(payload) ~= "table" then return end\n\n\tlocal action = payload.action', [=[ if not RateLimiter.Allow(player,"AdminPanelRequest",0.25) then return end
 if not Validation.Payload(payload) or not isAllowed(player) then return end
 local action=payload.action
 if type(action)~="string" or #action>40 then return end
 if action~="CheckPermission" and not RateLimiter.Allow(player,"AdminPanelMutation",1) then return end
 if payload.target~=nil and #resolveTargets(player,payload.target)==0 then sendToast(player,false,"Target not found");return end]=])
 s=range(s,'\telseif action == "GekoFlyGiveaway" then','\telseif action == "GiveRebirths" then', [=[ elseif action == "GekoFlyGiveaway" then
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
  reportTargets(player,confirmed,#targets,"Gekkoh giveaway")]=])
 s=range(s,'\telseif action == "GiveRebirths" then','\telseif action == "AutoRebirth" then', [=[ elseif action=="GiveRebirths" or action=="GiveStats" then
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
  reportTargets(player,confirmed,#targets,"Pass "..payload.pass)]=])
 s=range(s,'\telseif action == "UnlockWorld2" then','\telseif action == "TeleportWorld2" then', [=[ elseif action=="UnlockWorld2" then
  local enabled=payload.enabled~=false
  local targets=resolveTargets(player,payload.target)
  local confirmed=0
  for _,target in ipairs(targets) do
   if commitAdmin(target,{{kind="SetPersistent",key="World2Unlocked",value=enabled,allowFalse=true}},"admin_world2:"..tostring(enabled)) then confirmed+=1 end
  end
  reportTargets(player,confirmed,#targets,"World 2 "..(enabled and "unlocked" or "locked"))]=])
 s=replace(s,'local rawMsg = tostring(payload.message or "")','local rawMsg = type(payload.message)=="string" and payload.message or ""')
 s=replace(s,'\t\tlocal filtered = filterText(player, trimmed)\n\t\tlocal annPayload', '\t\tlocal filtered = filterText(player, trimmed)\n\t\tif not filtered then sendToast(player,false,"Text filtering unavailable; announcement was not sent");return end\n\t\tlocal annPayload')
 s=replace(s,'\t\t\tMessage = filtered,','\t\t\tMessage = filtered,\n\t\t\tEventId=HttpService:GenerateGUID(false),\n\t\t\tOriginJobId=game.JobId,')
 s=replace(s,'local rawCode = tostring(payload.code or "")','local rawCode = type(payload.code)=="string" and payload.code or ""')
 s=replace(s,'\t\t\t\tCode = cleanCode,','\t\t\t\tCode = cleanCode,\n\t\t\t\tEventId = HttpService:GenerateGUID(false),\n\t\t\t\tOriginJobId = game.JobId,')
 fs.writeFile(path,s)
end
print('AdminPanel confirmations, atomic grants, validation and dedup applied')
