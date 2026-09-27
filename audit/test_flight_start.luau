local fs=require('@lune/fs')
local luau=require('@lune/luau')
local source=fs.readFile('audit/merged/World1/ServerScriptService/Core/Abilities/FlightService.luau')
assert(source==fs.readFile('audit/merged/World2/ServerScriptService/Core/Abilities/FlightService.luau'))
local function run(enabled, fail)
 local connections,tasks,servicesRead=0,0,0
 local function signal() return {Connect=function() connections+=1 end} end
 local remotes={}
 for _,name in {'AbilityShopAction','AbilityShopUpdate','FlightAbilityState'} do
  remotes[name]={OnServerEvent=signal(),IsA=function(_,class) return class=='RemoteEvent' end}
 end
 function remotes:FindFirstChild(name) return self[name] end
 local config={AbilityFlightEnabled=enabled}
 local data,rate={},{}
 local flightStamina=luau.load(fs.readFile('src/common/ReplicatedStorage/Shared/FlightStamina.luau'),{environment={math=math,tonumber=tonumber}})()
 local winsMath=luau.load(fs.readFile('src/common/ReplicatedStorage/Shared/WinsMath.luau'),
  {environment={math=math,tonumber=tonumber,os=os,pcall=pcall,typeof=typeof,type=type,ipairs=ipairs,pairs=pairs}})()
 local shared={WaitForChild=function(_,name)
  if name=='FlightStamina' then return flightStamina end
  if name=='WinsMath' then return winsMath end
  assert(name=='Config');return config end}
 local rs={WaitForChild=function(_,name) assert(name=='Shared');return shared end,
  FindFirstChild=function(_,name) assert(name=='Remotes');return remotes end}
 local services={ReplicatedStorage=rs,RunService={},
  Players={GetPlayers=function() if fail then error('injected startup failure') end; return {} end,
   PlayerAdded=signal(),PlayerRemoving=signal()},
  MarketplaceService={PromptGamePassPurchaseFinished=signal()},
  ServerScriptService={Services={Data={DataService=data},ServerRateLimiter=rate}}}
 local api=luau.load(source,{environment={
  game={GetService=function(_,name) servicesRead+=1;return assert(services[name],name) end},
  require=function(module) return module end,_G={},
  task={spawn=function() tasks+=1 end,defer=function() tasks+=1 end}, print=function() end,
 }})()
 assert(servicesRead==0 and connections==0 and tasks==0,'require has side effects')
 local ok=pcall(api.Start)
 assert(ok~=fail,'startup result incorrect')
 local before=connections;local beforeTasks=tasks
 assert(pcall(api.Start)==ok,'repeated start masks failure')
 assert(connections==before and tasks==beforeTasks,'duplicate startup registered handlers/tasks')
 if enabled and not fail then assert(connections==5 and tasks==1,'missing handlers/watchdog') end
 if not enabled then assert(connections==0 and tasks==0,'disabled feature started') end
end
run(true,false);run(false,false);run(true,true)
print('PASS FlightService: side-effect-free require, one startup, disabled feature, failed startup cannot duplicate handlers')
