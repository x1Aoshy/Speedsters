-- Audit only: executes current production math and MovementGuard with mock services.
local fs = require('@lune/fs')
local luau = require('@lune/luau')
local rb = require('@lune/roblox')
local serde = require('@lune/serde')
local results = { speed = {}, checks = {} }
local stats = luau.load(fs.readFile('src/common/ServerScriptService/Services/Stats/StatsService.luau'))()
for _, raw in {1, 1e6, 1e9, 1e12, 3.37e15, 1e18} do
 local function calculate(scale)
  local result = stats.CalculateWalkSpeed(raw,nil,{worldMultiplier=scale,selectorMultiplier=1,boostMultiplier=1,permanentMultiplier=1})
  assert(result.ok);return result.value
 end
 local current, proposed = calculate(1), calculate(1/3)
 local legacy = stats.CalculateMaxWalkSpeed(raw,true)
 assert(math.abs(legacy-proposed)<1e-8)
 table.insert(results.speed,{raw=raw,currentWorld1=current,currentWorld2=current,oneThirdCandidate=proposed,legacyHelperWorld2=legacy,
  currentPoweredHorizontal=math.max(35,current*.3151),candidatePoweredHorizontal=math.max(35,proposed*.3151),
  currentGlideHorizontal=math.max(45,current*1.2519),candidateGlideHorizontal=math.max(45,proposed*1.2519)})
end
local function signal()
 local s={callbacks={}}
 function s:Connect(fn) table.insert(self.callbacks,fn);return {Disconnect=function()end} end
 function s:Fire(...) for _,fn in self.callbacks do fn(...) end end
 return s
end
local now=0;local studio=false;local nearest=1
local heartbeat=signal()
local root={Position=rb.Vector3.zero,Parent=true,IsA=function()return true end}
local humanoid={Health=100}
local character={Parent=true,FindFirstChild=function()return root end,FindFirstChildOfClass=function()return humanoid end}
local player={Character=character,CharacterAdded=signal()}
local players={PlayerAdded=signal(),PlayerRemoving=signal(),GetPlayers=function()return {player} end}
local config={};local stageService={GetNearestStage=function()return nearest,0 end}
local shared={WaitForChild=function()return config end}
local env={
 game={GetService=function(_,n)return ({Players=players,RunService={Heartbeat=heartbeat,IsStudio=function()return studio end},ReplicatedStorage={WaitForChild=function()return shared end},Workspace={}})[n]end},
 script={Parent={WaitForChild=function()return stageService end}},require=function(v)return v end,
 typeof=function(v)if v==root.Position then return 'Vector3' end;return typeof(v) end,
 os={clock=function()return now end},task={defer=function(fn)fn()end},_G={},warn=print,
}
local guard=luau.load(fs.readFile('src/common/ServerScriptService/Services/MovementGuard.luau'),{environment=env})()
local function check(name,condition)assert(condition,name);table.insert(results.checks,name);print('PASS '..name)end
guard.Rebase(player,10)
check('Live: eligible first final claim accepted',guard.CanClaim(player,10,true))
guard.RecordFinalClaim(player,0)
now=179.9
check('Live: second final claim rejected before 180 seconds',not guard.CanClaim(player,10,true))
-- Keep nearest stage consistent with a complete run; the first sample above only initialized lastPos.
nearest=10
now=180
check('Live: final cooldown expires at 180 seconds',guard.CanClaim(player,10,true))
nearest=1;now=200;guard.Rebase(player,1);guard.CanClaim(player,1,false)
now=204;nearest=3
check('Live: skipped sampled stage blocks stage-3 reward',not guard.CanClaim(player,3,false))
check('Live: rejected stage jump leaves progress at 1',guard.GetProgress(player)==1)
now=250
check('Live: remaining at skipped stage re-arms block after 45 seconds',not guard.CanClaim(player,3,false) and guard.IsBlocked(player))
studio=true
check('Studio: same blocked player passes CanClaim',guard.CanClaim(player,3,false))
studio=false;nearest=10;now=300;guard.Rebase(player,10);guard.RecordFinalClaim(player,now)
guard.ResetForCharacter(player,character)
check('Live: character reset does not remove final cooldown',not guard.CanClaim(player,10,true))
fs.writeFile('audit/world2_review_2026_09_14/behavior_probes.json',serde.encode('json',results,true))
print('PASS current speed path equals World1; legacy World2 helper equals one-third candidate')
