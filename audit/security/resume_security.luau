local fs = require('@lune/fs')
local function replace(s, before, after)
 local a,b=s:find(before,1,true); assert(a,'Missing replacement: '..before:sub(1,120))
 return s:sub(1,a-1)..after..s:sub(b+1)
end
local function range(s, first, last, replacement)
 local a=s:find(first,1,true); assert(a,first); local b=s:find(last,a+1,true);assert(b,last)
 return s:sub(1,a-1)..replacement..'\n\n'..s:sub(b)
end
local validation=[=[
-- Server-only validation shared by admin and announcement entry points.
local Validation = {}
function Validation.Finite(value)
 return type(value)=="number" and value==value and math.abs(value)<math.huge
end
function Validation.Payload(value)
 local seen, budget = {}, 96
 local function check(item, depth)
  budget-=1
  if budget<0 then return false end
  local kind=type(item)
  if kind=="boolean" or kind=="nil" then return true end
  if kind=="number" then return Validation.Finite(item) end
  if kind=="string" then
   if #item>512 then return false end
   local numeric=tonumber(item)
   return numeric==nil or Validation.Finite(numeric)
  end
  if kind~="table" or depth>=3 or seen[item] then return false end
  seen[item]=true
  for key,child in pairs(item) do
   if type(key)~="string" or #key>64 or not check(child,depth+1) then return false end
  end
  return true
 end
 return type(value)=="table" and check(value,0)
end
function Validation.EscapeRichText(value)
 return (tostring(value):gsub("&","&amp;"):gsub("<","&lt;"):gsub(">","&gt;"):gsub('"',"&quot;"):gsub("'","&apos;"))
end
function Validation.FilterBroadcast(textService, userId, raw)
 if type(raw)~="string" or #raw==0 or #raw>512 then return nil end
 local ok, filtered=pcall(function()
  local result=textService:FilterStringAsync(raw,userId)
  return result:GetNonChatStringForBroadcastAsync()
 end)
 if not ok or type(filtered)~="string" or #filtered==0 then return nil end
 return filtered
end
function Validation.NewEventCache()
 local seen={}
 return function(id, now)
  if type(id)~="string" or #id==0 or #id>128 then return false end
  if seen[id] then return false end
  local count=0
  for key,untilTime in pairs(seen) do
   if untilTime<=now then seen[key]=nil else count+=1 end
  end
  if count>=1024 then return false end
  seen[id]=now+600
  return true
 end
end
return Validation
]=]
for _,world in {'World1','World2'} do
 local base='audit/merged/'..world..'/ServerScriptService/'
 fs.writeFile(base..'Admin/AdminRequestValidation.luau',validation)
 local path=base..'Gameplay/'..world..'FlightAbility.luau'
 local s=fs.readFile(path)
 s=replace(s,'local function ownsFlight(player)\n\tif hasTemporaryFlight(player) then\n\t\treturn true\n\tend','local function permanentlyOwnsFlight(player)')
 s=replace(s,'local function getTrueBool(folder, name)', 'local function ownsFlight(player)\n\treturn permanentlyOwnsFlight(player) or hasTemporaryFlight(player)\nend\n\nlocal function getTrueBool(folder, name)')
 s=replace(s,'local function isFlightEquipped(player)\n\tif hasTemporaryFlight(player) then\n\t\treturn true\n\tend', 'local function isFlightEquipped(player)')
 s=replace(s,'local owned = ownsFlight(player)\n\tlocal initialized =', 'local owned = permanentlyOwnsFlight(player)\n\tlocal initialized =')
 s=replace(s,'if ownsFlight(player) then return true, "Flight Owned" end','if permanentlyOwnsFlight(player) then return true, "Flight Owned" end')
 s=replace(s,'if active and not RateLimiter.Allow(player, "FlightAbilityState", 0.08) then return end','if not RateLimiter.Allow(player, active and "FlightStartState" or "FlightStopState", 0.08) then return end')
 s=replace(s,'\t\tgrantAndEquipFlight(player, "flight_gamepass_purchase")\n\t\tprint("[FlightAbility] Flight GamePass granted to " .. player.Name)', '\t\tif grantAndEquipFlight(player, "flight_gamepass_purchase") then\n\t\t\tprint("[FlightAbility] Flight GamePass granted to " .. player.Name)\n\t\tend')
 -- Remove obsolete writers/helpers: all persistent mutation now goes through Actor.
 s=s:gsub('local equipSaveBusy = {}\n',''):gsub('\n\tequipSaveBusy%[player%] = nil','')
 s=range(s,'local function ensureTrueBool','local function isFlightEquipped','')
 s=range(s,'local function ensureFlightFlag','local function commitFlight','')
 fs.writeFile(path,s)
 path=base..'Admin/AdminAbuseServer.luau';s=fs.readFile(path)
 s=replace(s,'local TextChatService = game:GetService("TextChatService")','local TextChatService = game:GetService("TextChatService")\nlocal TextService = game:GetService("TextService")\nlocal HttpService = game:GetService("HttpService")\nlocal ServerScriptService = game:GetService("ServerScriptService")\nlocal Validation = require(ServerScriptService.Admin.AdminRequestValidation)\nlocal RateLimiter = require(ServerScriptService.Services.ServerRateLimiter)\nlocal acceptEvent = Validation.NewEventCache()')
 s=replace(s,'local AdminRemote = Instance.new("RemoteEvent")\nAdminRemote.Name = "AdminAbuseRemote"\nAdminRemote.Parent = RemotesFolder',[=[local AdminRemote = RemotesFolder:FindFirstChild("AdminAbuseRemote")
if AdminRemote and not AdminRemote:IsA("RemoteEvent") then AdminRemote:Destroy();AdminRemote=nil end
if not AdminRemote then
 AdminRemote=Instance.new("RemoteEvent");AdminRemote.Name="AdminAbuseRemote";AdminRemote.Parent=RemotesFolder
end]=])
 s=replace(s,".. adminName .. '</font>' .. badge .. ': ' .. message", ".. Validation.EscapeRichText(adminName) .. '</font>' .. badge .. ': ' .. Validation.EscapeRichText(message)")
 s=replace(s,'spec = spec or {}','spec = type(spec)=="table" and Validation.Payload(spec) and spec or {}')
 s=replace(s,'part.Parent = workspace\n\n\t\tlocal prompt', 'part.Parent = workspace\n\t\tpart:SetNetworkOwner(nil)\n\n\t\tlocal prompt')
 s=replace(s,'prompt.Triggered:Connect(function(triggerPlayer)\n\t\t\tif activeConfetti', [=[prompt.Triggered:Connect(function(triggerPlayer)
   if triggerPlayer.Parent~=Players or triggerPlayer:GetAttribute("DataLoaded")~=true then return end
   if not prompt.Enabled or not part.Parent then return end
   local character=triggerPlayer.Character
   local humanoid=character and character:FindFirstChildOfClass("Humanoid")
   local root=character and character:FindFirstChild("HumanoidRootPart")
   if not humanoid or humanoid.Health<=0 or not root then return end
   local distance=(root.Position-part.Position).Magnitude
   if not Validation.Finite(distance) or distance>prompt.MaxActivationDistance+2 then return end
   if activeConfetti]=])
 s=range(s,'local function createCode','local SESSION_LOGS', [=[local function createCode(codeName, statName, statAmount)
 if type(codeName)~="string" or #codeName<1 or #codeName>40 or not codeName:match("^[%w_]+$") then return false,"Use 1-40 letters, digits or underscores" end
 local stats={speed="Speed",wins="Wins",rebirths="Rebirths"}
 statName=type(statName)=="string" and stats[statName:lower()] or nil
 if not statName then return false,"Stat must be Speed, Wins or Rebirths" end
 local amount=tonumber(statAmount)
 if not Validation.Finite(amount) or amount<=0 or amount%1~=0 or amount>1e14 then return false,"Invalid stat amount" end
 if not CodesStore then return false,"DataStore unavailable" end
 local normalized=codeName:lower()
 local definition={CodeName=codeName,StatName=statName,StatAmount=amount,CreatedBy="Admin",CreatedAt=os.time(),Marker="AdminDynamicCode_"..normalized.."_v1"}
 local duplicate=false
 local ok=pcall(function()
  CodesStore:UpdateAsync("code_"..normalized,function(existing)
   duplicate=existing~=nil
   if duplicate then return nil end
   return definition
  end)
 end)
 if not ok then return false,"Code creation could not be confirmed" end
 if duplicate then return false,"Code already exists; existing rewards were preserved" end
 return true,"Code '"..codeName.."' created"
end

local function wipePlayerData(_targetName)
 -- This legacy path used the codes store, not the profile store. No account wipe
 -- is performed here until a separately validated maintenance workflow exists.
 return false,"Data wipe is unavailable. No player data was changed."
end

]=])
 s=replace(s,'local function publishGlobal(action, data)\n\tpcall(function()\n\t\tMessagingService:PublishAsync(AdminGlobalEvents.TopicName, { Action = action, Data = data or {}, Sender = os.time() })\n\tend)\nend',[=[local function publishGlobal(action, data)
 local id=HttpService:GenerateGUID(false)
 acceptEvent(id,os.time())
 local ok=pcall(function()
  MessagingService:PublishAsync(AdminGlobalEvents.TopicName,{Action=action,Data=data or {},EventId=id,OriginJobId=game.JobId,Timestamp=os.time()})
 end)
 if not ok then warn("[AdminAbuse] Global publish failed; effect remains local") end
 return ok
end]=])
 s=replace(s,'if type(payload) ~= "table" then return end\n\t\t\trunLocalEvent', 'if not Validation.Payload(payload) then return end\n\t\t\tif payload.OriginJobId==game.JobId then return end\n\t\t\tif not Validation.Finite(payload.Timestamp) or math.abs(os.time()-payload.Timestamp)>600 then return end\n\t\t\tif not acceptEvent(payload.EventId,os.time()) then return end\n\t\t\tif payload.Data~=nil and type(payload.Data)~="table" then return end\n\t\t\trunLocalEvent')
 s=replace(s,'local function handleAdminAction(player, request)\n\tif not isPlayerAdmin(player) then return end\n\tif type(request) ~= "table" then return end\n\tlocal action = tostring(request.Action or "")',[=[local function handleAdminAction(player, request)
 if not RateLimiter.Allow(player,"AdminAbuseRequest",0.25) then return end
 if not isPlayerAdmin(player) or not Validation.Payload(request) then return end
 local action=request.Action
 if type(action)~="string" or #action>40 then return end
 if action=="ConfettiEffect" or action=="CreateCode" or action=="Broadcast" or action=="SpawnTreadmill" then
  if not RateLimiter.Allow(player,"AdminAbuseExpensive",2) then return end
 end]=])
 s=replace(s,'local message = tostring(request.Message or "")','local message = type(request.Message)=="string" and request.Message or ""')
 s=replace(s,'\t\tlocal duration = tonumber(request.Duration) or 8','\t\tmessage=Validation.FilterBroadcast(TextService,player.UserId,message)\n\t\tif not message then sendToAdmin(player,{Type="ActionResult",Ok=false,Message="Text filtering unavailable; announcement was not sent"});return end\n\t\tlocal duration = math.clamp(tonumber(request.Duration) or 8,1,30)')
 s=replace(s,'BPM = tonumber(request.BPM) or 128','BPM = math.clamp(tonumber(request.BPM) or 128,30,300)')
 -- SendingMessage is client-only; do not subscribe to a nonfunctional server log.
 s=range(s,'local function onSendingMessage','-- ============================= GLOBAL EVENTS', '-- Chat logging from this disabled legacy panel is unavailable; no unfiltered chat is rebroadcast.')
 fs.writeFile(path,s)
end
print('Flight/AdminAbuse validation edits applied')
