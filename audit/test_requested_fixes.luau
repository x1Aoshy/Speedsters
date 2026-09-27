local fs=require('@lune/fs');local luau=require('@lune/luau');local rb=require('@lune/roblox')
local function source(p) return fs.readFile('src/common/'..p) end
local function slice(s,a,b) return s:sub(assert(s:find(a,1,true)),assert(s:find(b,1,true))-1) end
-- Real queue worker, suspended between gains, including Hide Popups toggles.
local s=source('StarterPlayer/StarterPlayerScripts/Movement/SpeedsterClient.client.luau')
local hidden=false;local worker;local seen={}
local enqueue=luau.load(slice(s,'local world1PopupSpawnQueue = {}','local function makeOneScreenPopup')..'\nreturn enqueueWorld1Popup', {environment=setmetatable({
 player={GetAttribute=function() return hidden end},
 makeOneWorld1BarPopup=function(amount) table.insert(seen,amount) end,
 task={spawn=function(fn) worker=coroutine.create(fn);assert(coroutine.resume(worker)) end,wait=function() coroutine.yield() end},
},{__index=_G})})()
for cycle=1,8 do
 enqueue({Amount=1,SpawnGap=0.1});enqueue({Amount=2,SpawnGap=0.1})
 hidden=true;enqueue({Amount=1000,SpawnGap=0.1});hidden=false
 enqueue({Amount=3,SpawnGap=0.1})
 while coroutine.status(worker)~='dead' do assert(coroutine.resume(worker)) end
end
local sum=0;for _,n in seen do sum+=n end
assert(sum==48,'Popup queue lost or replayed gains: '..sum)
print('PASS actual popup worker survives 8 hide/show cycles without losing or replaying gains')
-- Existing VFX stop/resume must preserve emitter rates.
s=source('StarterPlayer/StarterPlayerScripts/Gameplay/TreadmillVfxController.client.luau')
local char={};local emitter={Parent=true,Enabled=true,Rate=12};local data={Emitters={emitter},Attachment={Parent=true,Destroy=function() end}}
local stop,resume=luau.load(slice(s,'local function stopTreadmillVfx','local function updateCharacterVfx')..'\nreturn stopTreadmillVfx,resumeTreadmillVfx',{environment=setmetatable({activeVfxByChar={[char]=data},task={delay=function() return {} end,cancel=function() end}},{__index=_G})})()
stop(char);assert(not emitter.Enabled);resume(data);assert(emitter.Enabled and emitter.Rate==12 and not data.CleanupTask)
print('PASS actual treadmill stop/resume preserves particle emission')
local catalog=luau.load(source('ReplicatedStorage/Shared/Catalogs/CodesCatalog.luau'))()
local markers={}
for _,name in catalog.Active do
 local d=assert(catalog.Get(name));assert(not markers[d.Marker]);markers[d.Marker]=true
 assert(not d.ProportionalRewards and not d.Rebirths and not d.Speed and not d.Wins,'Unbounded progression reward')
 for _,p in d.Potions or {d.Potion} do assert(p.Multiplier==2 and p.DurationMinutes<=20) end
end
-- 2026-09-26 (owner): the banner advertises the three Update 4 codes (UPDATE4ISHERE, RACES, EGGMAN).
assert(#catalog.Active==3)
print('PASS the three Update 4 codes: unique markers, temporary 2x rewards, no progression skips')
-- Snow must not clear a pre-existing boost on its first start or a newer admin boost on stop.
s=source('ServerScriptService/Admin/AdminAbusePanelService.server.luau')
local attrs={ServerWinsBoostExpiresUnix=2000,ServerWinsBoostMultiplier=5}
local workspace={GetAttribute=function(_,k)return attrs[k] end,SetAttribute=function(_,k,v)attrs[k]=v end}
local stopSnow,startSnow=luau.load(slice(s,'local previousSnowWinsExpire','local function stopEvent')..'\nreturn stopSnow,startSnow',{environment=setmetatable({Workspace=workspace,eventTokens={},HttpService={GenerateGUID=function()return 'token' end},os={time=function() return 1000 end},task={delay=function()end},freezeWorld=function()end,thawWorld=function()end},{__index=_G})})()
startSnow(60);assert(attrs.ServerWinsBoostMultiplier==5 and attrs.ServerWinsBoostExpiresUnix==2000)
stopSnow();assert(attrs.ServerWinsBoostMultiplier==5)
attrs.ServerWinsBoostExpiresUnix=nil;attrs.ServerWinsBoostMultiplier=nil
startSnow(60);assert(attrs.ServerWinsBoostMultiplier==2 and attrs.ServerWinsBoostExpiresUnix==1060)
attrs.ServerWinsBoostExpiresUnix=3000;attrs.ServerWinsBoostMultiplier=10
stopSnow();assert(attrs.ServerWinsBoostMultiplier==10 and attrs.ServerWinsBoostExpiresUnix==3000)
print('PASS actual snow lifecycle preserves stronger and newer boosts')
local quest=rb.deserializeModel(fs.readFile('src/ui/QuestGui.rbxm'))[1]
local titles=0
for _,i in quest:GetDescendants() do
 if i:IsA('TextLabel') and i:FindFirstChild('RowTextSize') then
  titles+=1;assert(i.TextScaled and not i.TextWrapped)
  assert(not i:FindFirstChildOfClass('UIAspectRatioConstraint'))
  local stroke=i:FindFirstChildOfClass('UIStroke');assert(stroke.StrokeSizingMode==rb.Enum.StrokeSizingMode.FixedSize and math.abs(stroke.Thickness-1.2)<0.001)
 end
end
assert(titles>=9)
print('PASS saved quest rows use fixed thin outlines and separate icon/text space:',titles)
