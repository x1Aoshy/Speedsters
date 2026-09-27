local fs=require('@lune/fs');local luau=require('@lune/luau')
local world=require('@lune/process').args[1] or 'World1'
local Validation=require('./merged/'..world..'/ServerScriptService/Admin/AdminRequestValidation')
local function signal() local s={};function s:Connect(fn) self.fn=fn end;return s end
local now=1000;local shown={};local published={};local callback;local failing=true;local authQueries=0
local admin={UserId=767108248,DisplayName='Admin',Parent=true}
local display={IsA=function() return true end,FireAllClients=function(_,p) table.insert(shown,p) end}
local action={IsA=function() return true end,OnServerEvent=signal(),FireClient=function() end}
local remotes={FindFirstChild=function(_,name) return name=='DisplayGlobalAnnouncement' and display or action end}
local rate={};local limiter={Allow=function(_,key,interval) local old=rate[key];if old and now-old<interval then return false end;rate[key]=now;return true end}
local services={Players={GetPlayers=function() return {} end,PlayerAdded=signal(),GetPlayerByUserId=function() return admin end},
 ReplicatedStorage={WaitForChild=function() return remotes end},RunService={IsStudio=function() return false end},
 ServerScriptService={Admin={AdminRequestValidation=Validation},Services={ServerRateLimiter=limiter}},
 HttpService={GenerateGUID=function() return 'event-'..now end},TextChatService={},
 TextService={FilterStringAsync=function() if failing then error('filter offline') end;return {GetNonChatStringForBroadcastAsync=function() return 'FILTERED' end} end},
 MessagingService={SubscribeAsync=function(_,_,fn) callback=fn end,PublishAsync=function(_,_,p) table.insert(published,p) end}}
local game={JobId='local',CreatorId=0,GetService=function(_,name) return assert(services[name],name) end}
luau.load(fs.readFile('audit/merged/'..world..'/ServerScriptService/Social/GlobalAnnouncementService.luau'),{environment={game=game,require=function(x) return x end,os={clock=function() return now end,time=function() return now end},task={spawn=function(fn) fn() end},Enum={CreatorType={User=1,Group=2},ChatVersion={TextChatService=1}}}})()
action.OnServerEvent.fn(admin,'Broadcast','raw message');assert(#shown==0 and #published==0,'Unfiltered fallback')
failing=false;now+=2;action.OnServerEvent.fn(admin,'Broadcast','raw message');assert(#shown==1 and #published==1 and shown[1].Message=='FILTERED')
callback({Data=published[1]});assert(#shown==1,'Own echo repeated')
local data={Message='Other',SenderName='Admin',SenderId=2,Duration=999,Timestamp=now,OriginJobId='remote',EventId='remote-event'}
callback({Data=data});callback({Data=data});assert(#shown==2 and shown[2].Duration==30)
for _,bad in {{Message={}}, {Message='old',SenderName='A',Timestamp=now-601,EventId='old'}, {Message='bad',SenderName='A',Timestamp=0/0,EventId='nan'}} do callback({Data=bad}) end
assert(#shown==2)
print('PASS '..world..' actual announcement script: filter failure emits nothing; filtered publish; own echo/repeated/stale/malformed events rejected')
local client=fs.readFile('audit/merged/'..world..'/StarterGui/Messages/MessageHandler.luau')
local a=assert(client:find('local function escapeAnnouncementText',1,true));local b=assert(client:find('local function displayAnnouncement',a,true))
local escape=luau.load(client:sub(a,b-1)..'\nreturn escapeAnnouncementText')()
assert(escape('<font size="999">A&B</font>')=='&lt;font size=&quot;999&quot;&gt;A&amp;B&lt;/font&gt;')
print('PASS markup remains literal announcement text')
