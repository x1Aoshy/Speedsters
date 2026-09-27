local fs=require('@lune/fs')
local function replace(s,a,b) local x,y=s:find(a,1,true);assert(x,a);return s:sub(1,x-1)..b..s:sub(y+1) end
for _,world in {'World1','World2'} do
 local path='audit/merged/'..world..'/ServerScriptService/Social/GlobalAnnouncementService.luau'
 local s=fs.readFile(path)
 s=replace(s,'local MESSAGING_TOPIC =',[[local HttpService = game:GetService("HttpService")
local ServerScriptService = game:GetService("ServerScriptService")
local Validation = require(ServerScriptService.Admin.AdminRequestValidation)
local RateLimiter = require(ServerScriptService.Services.ServerRateLimiter)
local acceptEvent = Validation.NewEventCache()

local MESSAGING_TOPIC =]])
 local first=s:find('local function filterTextForBroadcast',1,true);local last=s:find('local function displayLocally',first,true)
 s=s:sub(1,first-1)..'local function filterTextForBroadcast(player: Player, rawMessage: string): string?\n\treturn Validation.FilterBroadcast(TextService, player.UserId, rawMessage)\nend\n\n'..s:sub(last)
 s=replace(s,'\tif not isAllowed(player) then return end\n\n\tlocal trimmed','\tif type(rawMessage)~="string" or #rawMessage>512 or not RateLimiter.Allow(player,"AnnouncementBroadcast",1) then return end\n\tif not isAllowed(player) then return end\n\n\tlocal trimmed')
 s=replace(s,'local filteredMessage = filterTextForBroadcast(player, trimmed)','local filteredMessage = filterTextForBroadcast(player, trimmed)\n\tif not filteredMessage then return end')
 s=replace(s,'\t\tMessage = filteredMessage,','\t\tMessage = filteredMessage,\n\t\tEventId = HttpService:GenerateGUID(false),\n\t\tOriginJobId = game.JobId,')
 s=replace(s,'\tdisplayLocally(payload)','\tacceptEvent(payload.EventId, os.time())\n\tdisplayLocally(payload)')
 first=s:find('\t\tlocal data = message.Data',1,true);last=s:find('\n\tend)\nend)',first,true)
 s=s:sub(1,first-1)..[[
		local data = message and message.Data
		if not Validation.Payload(data) or type(data.Message)~="string" or #data.Message==0
			or type(data.SenderName)~="string" or not Validation.Finite(data.Timestamp)
			or math.abs(os.time()-data.Timestamp)>600 or data.OriginJobId==game.JobId then return end
		if not acceptEvent(data.EventId,os.time()) then return end
		displayLocally({Message=data.Message,SenderName=data.SenderName,SenderId=data.SenderId,
			Duration=math.clamp(tonumber(data.Duration) or DEFAULT_DURATION,1,30)})
]]..s:sub(last)
 s=replace(s,'AdminBarRemote.OnServerEvent:Connect(function(player, action, messageText)\n','AdminBarRemote.OnServerEvent:Connect(function(player, action, messageText)\n\tif not RateLimiter.Allow(player,"AnnouncementRequest",0.25) then return end\n')
 fs.writeFile(path,s)
end
print('Announcement filtering and event identity checks integrated')
