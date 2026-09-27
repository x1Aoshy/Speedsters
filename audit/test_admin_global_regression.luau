local fs=require('@lune/fs');local luau=require('@lune/luau')
local s=fs.readFile('src/common/ServerScriptService/Admin/AdminAbusePanelService.server.luau')
local a=assert(s:find('local function publish(action:',1,true));local b=assert(s:find('\n----------------------------------------------------------------------\n-- Requests',a,true))
local code=s:sub(a,b-1)..'\nreturn {publish=publish,runShared=runShared,receive=receiveGlobal}'
local jobs={};local clock=0;local bus={};local worlds={};local seq=0;local firstPublish=true;local ids={}
local function schedule(co,at)table.insert(jobs,{co=co,at=at})end
local taskApi={spawn=function(fn)schedule(coroutine.create(fn),clock)end,wait=function(dt)return coroutine.yield(dt)end}
local function drain()
 local count=0
 while #jobs>0 do
  table.sort(jobs,function(x,y)return x.at<y.at end)
  local j=table.remove(jobs,1);clock=j.at
  local ok,delay=coroutine.resume(j.co);assert(ok,delay)
  if coroutine.status(j.co)~='dead' then schedule(j.co,clock+(delay or 0))end
  count+=1;assert(count<100,'retry runaway')
 end
end
for n=1,3 do
 local calls={};local attrs={};local seen={};local attempts=0
 local function record(action,...)table.insert(calls,{action=action,args={...}})end
 local env=setmetatable({
  TOPIC='same-experience-admin-topic',game={JobId='job-'..n},os={time=function()return 1000+math.floor(clock)end},task=taskApi,
  HttpService={GenerateGUID=function()seq+=1;return 'event-'..seq end},
  acceptEvent=function(id)if type(id)~='string' or seen[id]then return false end;seen[id]=true;return true end,
  Validation={Finite=function(v)return type(v)=='number' and v==v end},
  number=function(v,default,low,high)return math.clamp(tonumber(v) or default,low,high)end,
  toast=function(_,ok,msg)record('Toast',ok,msg)end,warn=function()end,
  Workspace={SetAttribute=function(_,k,v)attrs[k]=v end,FindFirstChild=function()return {ClearAllChildren=function()record('ClearTreadmills')end}end},
  TREADMILL_FOLDER='AdminSpawnedTreadmills',
  applyAbuse=function(...)record('Abuse',...)end,runEvent=function(...)record('Event',...)end,
  boost=function(...)record('Boost',...)end,announce=function(...)record('Announce',...)end,
  spawnTreadmill=function(...)record('Treadmill',...);return true end,adminTreadmillSpeedGain=function()return 3000 end,
  Panel={FireAllClients=function(_,payload)record('Reveal',payload)end},
  musicTracks=function()return {{Id='song'}}end,playMusic=function(id)record(if id then 'PlayMusic' else 'StopMusic',id)end,
  MessagingService={
   SubscribeAsync=function(_,topic,callback)attempts+=1;if n==2 and attempts==1 then error('transient subscription failure')end;bus[n]=callback;return {}end,
   PublishAsync=function(_,topic,payload)
    assert(topic=='same-experience-admin-topic');table.insert(ids,payload.EventId)
    for _,callback in bus do callback({Data=payload})end
    if firstPublish then firstPublish=false;error('timeout after backend accepted')end
   end,
  },
 },{__index=_G})
 local api=luau.load(code,{environment=env})();worlds[n]={api=api,calls=calls,attrs=attrs}
end
drain();for _,w in worlds do assert(w.attrs.AdminGlobalSubscribed)end
local actions={
 {'Event',{name='Snow',duration=60,enabled=true,byId=42,byName='Admin'}},
 {'Event',{name='Disco',duration=60,enabled=true}},
 {'Event',{name='Sandstorm',duration=60,enabled=true}},
 {'Event',{name='Confetti',duration=60,enabled=true}},
 {'Event',{name='Fireworks',duration=60,enabled=true}},
 {'Event',{name='Snow',duration=60,enabled=false}},
 {'Abuse',{effect='Rocket',target='All',duration=10}},
 {'Abuse',{effect='Tiny',target=123,duration=10}},
 {'Boost',{stat='Speed',multiplier=2,minutes=5}},
 {'Announce',{message='Hello',byName='Admin',byId=42}},
 {'Treadmill',{multiplier=5,minutes=2,byId=42,byName='Admin',withDisco=true}},
 {'ClearTreadmills',{}},{'PlayMusic',{trackId='song'}},{'StopMusic',{}},
}
for _,entry in actions do
 worlds[1].api.runShared(entry[1],entry[2]);worlds[1].api.publish(entry[1],entry[2],{})
 drain()
end
assert(ids[1]==ids[2],'Retries must reuse the same event ID')
local function effects(w)local out={};for _,call in w.calls do if call.action~='Toast'then table.insert(out,call)end end;return out end
local baseline=effects(worlds[1])
for n=2,3 do
 local calls=effects(worlds[n]);assert(#calls==#baseline,'Missing or duplicated remote actions')
 for i,call in calls do assert(call.action==baseline[i].action)end
 local abuse={};for _,call in calls do if call.action=='Abuse'then table.insert(abuse,call)end end
 assert(abuse[1].args[3]=='All' and abuse[2].args[3]==123,'Target scope lost')
end
print('PASS 3 simulated servers: subscription recovers, 5 events + stop, abuse targets, boosts, announcements, treadmills/reveal/clear and music')
print('PASS publish accepted then timed out: retry uses same ID, no doubled effects, origin does not replay itself')
local before=#worlds[2].calls
worlds[2].api.receive({Data={OriginJobId='remote',Timestamp=-1000,EventId='stale',Action='Event',Data={name='Snow'}}})
assert(#worlds[2].calls==before)
print('PASS stale global message rejected')
-- Drive the actual remote request handler, including the scope selected in the UI.
local start=assert(s:find('local ABUSE = {',1,true));local finish=assert(s:find('-- Admins are told on arrival:',start,true))
local requestHandler;local published={}
local admin={UserId=42,DisplayName='Admin',Name='Admin'}
local folder={GetChildren=function()return {}end,ClearAllChildren=function()end,FindFirstChild=function()return nil end}
local env=setmetatable({
 Panel={OnServerEvent={Connect=function(_,fn)requestHandler=fn end},FireAllClients=function()end},
 RateLimiter={Allow=function()return true end},isAllowed=function()return true end,
 number=function(v,d,l,h)return math.clamp(tonumber(v) or d,l,h)end,
 applyAbuse=function()return 1,1 end,runEvent=function()end,boost=function()end,
 spawnTreadmill=function()return true,'spawned'end,toast=function()end,
 Workspace={FindFirstChild=function()return folder end},TREADMILL_FOLDER='AdminSpawnedTreadmills',
 adminTreadmillSpeedGain=function()return 3000 end,musicTracks=function()return {{Id='song'}}end,playMusic=function()end,
 publish=function(action,data)table.insert(published,{action=action,data=data})end,
 announce=function()end,Validation={FilterBroadcast=function(_,_,text)return text end},TextService={},ANNOUNCE_THEMES={Gold=true},
},{__index=_G})
luau.load(s:sub(start,finish-1),{environment=env})()
for _,scope in {'Server','All'} do
 local before=#published
 for _,payload in {
  {action='Event',name='Snow',enabled=true},{action='Event',name='Snow',enabled=false},
  {action='Abuse',effect='Rocket',target='All'},{action='Abuse',effect='Tiny',target=123},
  {action='Boost',stat='Speed'},{action='Treadmill',withDisco=true},{action='ClearTreadmills'},
  {action='PlayMusic',trackId='song'},{action='StopMusic'},{action='Announce',message='Hello',theme='Gold'},
 }do payload.scope=scope;requestHandler(admin,payload)end
 assert(#published-before==(if scope=='All'then 10 else 0),'Scope routed incorrectly')
end
local ui=fs.readFile('src/common/StarterPlayer/StarterPlayerScripts/Admin/AdminAbusePanelController.client.luau')
assert(ui:find('{ "All", "All Servers" }',1,true) and ui:find('payload.scope = scope',1,true))
print('PASS actual request handler: This Server publishes nothing; All Servers publishes all 10 tested actions; UI scope matches')
