local fs=require('@lune/fs');local luau=require('@lune/luau');local r=require('@lune/roblox')
local world=require('@lune/process').args[1] or 'World1'
local prefix='audit/merged/'..world..'/ServerScriptService/'
local Data=require('./merged/'..world..'/ServerScriptService/Services/Data/DataService')
local Adapter=require('./merged/'..world..'/ServerScriptService/Services/Data/DataStoreAdapter')
local now=1000
local store=Adapter.CreateMock({Player_1={Version=306,Wins=50000000,Speed=100,PermanentWinsMultiplier=16}})
Data.Init({storeAdapter=store,clock={UnixNow=function() return now end,MonotonicNow=function() return now end}});Data.Start();assert(Data.Open(1).ok)
local function signal()
 local s={handlers={}};function s:Connect(fn) table.insert(self.handlers,fn);return {Disconnect=function() end} end
 function s:Fire(...) for _,fn in self.handlers do fn(...) end end;return s
end
local Players={PlayerAdded=signal(),PlayerRemoving=signal(),GetPlayers=function() return {} end}
local Workspace={}
local RunService={Heartbeat=signal()}
local attrs={DataLoaded=true}
local root={Position=r.Vector3.new(0,3,0),Size=r.Vector3.new(2,2,1),IsA=function() return true end}
local humanoid={Health=100,HipHeight=2,WalkSpeed=16}
local player={UserId=1,Name='Test',Parent=Players,GetAttribute=function(_,n) return attrs[n] end,GetAttributeChangedSignal=function() return signal() end,
 Character={FindFirstChildOfClass=function() return humanoid end,FindFirstChild=function() return root end}}
local queued={};local taskMock={delay=function(_,fn,...) table.insert(queued,{fn=fn,args={...}}) end,spawn=function(fn,...) fn(...) end,defer=function() end,wait=function() now+=1 end}
local function drain() local n=0;while #queued>0 do n+=1;assert(n<20);local q=table.remove(queued,1);q.fn(table.unpack(q.args)) end end
local function folder(children)
 return setmetatable({WaitForChild=function(self,n) return assert(self[n],n) end,FindFirstChild=function(self,n) return self[n] end},{__index=children})
end
local action={OnServerEvent=signal()};local updates={};local update={FireClient=function(_,_,data) table.insert(updates,data) end}
local Config={IsWorld2Place=world=='World2',StageCount=10,TeleportStageOptions={{Stage=10,WinsCost=725000}},
 ProgressionPriceMultiplierExponent=0.5}
-- Real WinsMath, not a stub: the quote the handler sends and the figure asserted
-- below must come from the same pricing code the game ships.
local WinsMath=luau.load(fs.readFile('src/common/ReplicatedStorage/Shared/WinsMath.luau'),
 {environment={tonumber=tonumber,math=math,os=os,pcall=pcall,typeof=typeof,type=type,ipairs=ipairs,pairs=pairs}})()
-- 725,000 base at x16 damped by 0.5 -> 725,000 * 4. The old linear rule charged
-- 725,000 * 16 = 11,600,000, which is exactly the price that made the ladder pointless.
local QUOTE=WinsMath.GetProgressionPrice(725000,16,Config.ProgressionPriceMultiplierExponent)
assert(QUOTE==2900000,'expected a damped x16 quote of 2,900,000, got '..tostring(QUOTE))
local moved=false;local teleports=0
local Stage={TeleportPlayer=function() teleports+=1;return moved,'Test destination failure' end}
local services=folder({Data=folder({DataService=Data}),StageTeleportService=Stage})
local gameMock={GetService=function(_,name) return assert(({Players=Players,Workspace=Workspace,RunService=RunService,ReplicatedStorage=folder({Shared=folder({Config=Config,WinsMath=WinsMath}),Remotes=folder({TeleportAction=action,TeleportUpdate=update})}),ServerScriptService=folder({Services=services})})[name]) end}
local env={game=gameMock,require=function(x) return x end,task=taskMock,os={clock=function() return now end},_G={SpeedsterGetPermanentWinsMultiplier=function() return 16 end}}
luau.load(fs.readFile(prefix..'Worlds/TeleportSystem.luau'),{environment=env})()
local function wins() return Data.Inspect(Data.GetHandle(1)).value.profile.Wins end
local function fire(kind,cost) now+=1;action.OnServerEvent:Fire(player,kind,10,cost) end
fire('Quote');assert(updates[#updates].Costs[10]==QUOTE,'server quote must be the damped price')
fire('Wins',725000);assert(wins()==50000000 and teleports==0,'Stale quote charged')
fire('Wins',QUOTE);assert(wins()==50000000 and teleports==1,'Refund was multiplied')
for _=1,10 do fire('Wins',QUOTE) end;assert(wins()==50000000,'Failed travel mints Wins')
moved=true;fire('Wins',QUOTE);assert(wins()==50000000-QUOTE)
store:SetFailureMode('Player_1','Timeout');fire('Wins',QUOTE)
assert(#queued==1);fire('Wins',QUOTE);assert(#queued==1,'Concurrent trip accepted')
store:SetFailureMode('Player_1','None');drain();assert(wins()==50000000-QUOTE*2,'Uncertain debit duplicated')
assert(Data.Inspect(Data.GetHandle(1)).value.profile.PendingStageTeleport==nil)
print('PASS '..world..' actual teleport handler: damped x16 server quote ('..QUOTE..'), stale price rejection, 11 exact refunds, one debit on timeout retry')
local pad={Parent=Workspace,CFrame=r.CFrame.new(),Size=r.Vector3.new(8,1,8),GetAttribute=function() return nil end,IsDescendantOf=function() return true end}
env.Vector3=r.Vector3;env.CFrame=r.CFrame
local padService=luau.load(fs.readFile(prefix.."Services/PadTouchService.luau"),{environment=env})()
env.script={Parent={PadTouchService=padService,Data={DataService=Data},MovementGuard={CanClaim=function() return true end,RecordFinalClaim=function() end}}}
local claims=luau.load(fs.readFile(prefix..'Services/RewardPadClaims.luau'),{environment=env})()
local before=wins();assert(not claims.Claim(player,pad,500000,10,true,function() return false end));assert(wins()==before)
assert(not claims.Claim(player,pad,500000,10,true,function() return true end));assert(wins()==before,'Paid without leaving pad')
local function go() root.Position=r.Vector3.new(1000,0,0);return true end
assert(claims.Claim(player,pad,500000,10,true,go));assert(wins()==before+8000000,'Double multiplier')
root.Position=r.Vector3.new(0,3,0);before=wins();store:SetFailureMode('Player_1','Timeout')
assert(claims.Claim(player,pad,500000,10,true,go));root.Position=r.Vector3.new(0,3,0)
assert(not claims.Claim(player,pad,500000,10,true,go),'Concurrent reward accepted')
store:SetFailureMode('Player_1','None');drain();assert(wins()==before+8000000)
assert(8000000<11600000,'Bought-stage cycle profitable')
print('PASS '..world..' actual reward handler: failed return/no movement pays zero; x16 once; reentry during timeout pays once')
assert(Data.Release(1).kind=='Released');assert(Data.Open(1).ok);assert(wins()==before+8000000)
print('PASS final Wins survive release/rejoin')
