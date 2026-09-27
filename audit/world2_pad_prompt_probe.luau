local fs=require('@lune/fs'); local luau=require('@lune/luau'); local r=require('@lune/roblox')
local function signal() local s={f={}}; function s:Connect(fn) self.f[fn]=true; return {Disconnect=function() self.f[fn]=nil end} end; function s:Fire(...) for fn in self.f do fn(...) end end; return s end
local PASS_ID=1941409601
for _,world in {'World2'} do
 local hb=signal();local workspace={};local now=0;local attrs={DataLoaded=true}
 local players={PlayerRemoving=signal()};local root={Position=r.Vector3.new(-30,3,0),Size=r.Vector3.new(2,2,1),IsA=function() return true end}
 local hum={Health=100,WalkSpeed=1500,HipHeight=2};local char={FindFirstChildOfClass=function() return hum end,FindFirstChild=function() return root end}
 local player={UserId=7,Name='runner',Parent=players,Character=char,GetAttribute=function(_,n) return attrs[n] end}
 player.SetAttribute=function(_,k,v) attrs[k]=v end
 players.GetPlayers=function() return {player} end
 local function part(size,cf)
  local p=setmetatable({Size=size,CFrame=cf,Parent=workspace,signals={},Destroying=signal()}, {__index=function(t,k) if k=='Position' then return t.CFrame.Position end end})
  function p:GetAttribute(n) return self.attrs and self.attrs[n] end
  function p:SetAttribute(n,v) self.attrs=self.attrs or {};self.attrs[n]=v end
  function p:GetPropertyChangedSignal(name) self.signals[name]=self.signals[name] or signal();return self.signals[name] end
  p.GetAttributeChangedSignal=p.GetPropertyChangedSignal
  function p:IsDescendantOf(other) return self.Parent ~= nil and other==workspace end
  function p:Destroy() self.Destroying:Fire();self.Parent=nil end
  return p
 end
 local clock={clock=function() return now end};local warnings={};local delayed={}
 local env={game={GetService=function(_,n) return ({Players=players,RunService={Heartbeat=hb},Workspace=workspace})[n] end},Vector3=r.Vector3,CFrame=r.CFrame,Instance={new=function() return part() end},task={spawn=function(fn) fn() end,delay=function(_,fn) table.insert(delayed,fn) end},os=clock,warn=function(s) table.insert(warnings,s) end}
 local base='src/common/ServerScriptService/Services/'
 local pads=luau.load(fs.readFile(base..'PadTouchService.luau'),{environment=env})()
 local handle={userId=7,sessionId='a',generation=1};local wins=0;local commits=0
 local commitKind='Committed';local data={GetHandle=function() return handle end,NewOperationId=function() return 'op'..commits end,Commit=function(_,req) commits+=1;if commitKind=='Committed' then wins+=req.commands[1].amount end;return {kind=commitKind} end}
 local allowed=true;local guard={CanClaim=function() return allowed end,RecordFinalClaim=function() end}
 local claimenv=table.clone(env);claimenv.script={Parent={Data={DataService=data},MovementGuard=guard,PadTouchService=pads}};claimenv.require=function(m) return m end
 claimenv._G={SpeedsterGetPermanentWinsMultiplier=function() return 16 end}
 local claims=luau.load(fs.readFile(base..'RewardPadClaims.luau'),{environment=claimenv})()
 local mathenv=table.clone(env);mathenv.typeof=function(v) return type(v)=='table' and 'table' or type(v) end;mathenv.os={time=function() return 0 end,clock=clock.clock}
 local winsMath=luau.load(fs.readFile('src/common/ReplicatedStorage/Shared/WinsMath.luau'),{environment=mathenv})()

 -- Exercise the real shared x2-pad module against a Marketplace stand-in.
 local owned=false;local prompts=0;local productPrompts=0;local lookups=0
 local marketplace={PromptGamePassPurchaseFinished=signal()}
 function marketplace:PromptGamePassPurchase(_,id) assert(id==PASS_ID,'Prompted the wrong gamepass: '..tostring(id));prompts+=1 end
 function marketplace:PromptProductPurchase() productPrompts+=1 end
 function marketplace:UserOwnsGamePassAsync(_,id) assert(id==PASS_ID);lookups+=1;return owned end
 local padModuleEnv=table.clone(env)
 padModuleEnv.typeof=mathenv.typeof
 local sharedStub={WaitForChild=function(_,name) return name=='WinsMath' and winsMath or {DoubleWinsPadGamePassId=PASS_ID} end}
 local servicesStub={WaitForChild=function(_,name) assert(name=='PadTouchService');return pads end}
 padModuleEnv.game={GetService=function(_,n)
  if n=='MarketplaceService' then return marketplace end
  if n=='Players' then return players end
  if n=='ReplicatedStorage' then return {WaitForChild=function() return sharedStub end} end
  if n=='ServerScriptService' then return {WaitForChild=function() return servicesStub end} end
  return nil
 end}
 padModuleEnv.require=function(m) return m end
 local doubleWinsPad=luau.load(fs.readFile('src/common/ServerScriptService/Services/DoubleWinsPad.luau'),{environment=padModuleEnv})()

 local pad=part(r.Vector3.new(7,.5,7),r.CFrame.new())
 local prod=fs.readFile('src/worlds/World2/ServerScriptService/Gameplay/World2ManualStagePads.server.luau')
 local a=assert(prod:find('local function connectRewardPad(',1,true))
 local b=assert(prod:find('local function connectSkipPad(',a,true))
 local moved=0
 local padenv=table.clone(env)
 for k,v in {
  connectedPads={},PadTouchService=pads,playerFromHit=function() return player,char,hum end,
  WinsMath=winsMath,DoubleWinsPad=doubleWinsPad,
  inArrivalGrace=function() return false end,touchReady=function() return true end,
  RewardPadClaims=claims,teleportToStart=function() moved+=1;root.Position=r.Vector3.new(100,3,0);return true end,
  playWinFeedback=function() end,queueSave=function() end,
 } do padenv[k]=v end
 local connect=luau.load(prod:sub(a,b-1)..'\nreturn connectRewardPad',{environment=padenv})()
 connect(pad,100,true,2,false)
 local function step(pos,dt) now+=dt or 1/30;if pos then root.Position=pos end;hb:Fire(dt or 1/30)end
 -- A long step off can still sweep through the pad, so settle once outside before
 -- coming back; otherwise PadTouchService rightly treats it as one continuous visit.
 local function leave() step(r.Vector3.new(100,3,0),2.5);step(r.Vector3.new(100,3,0)) end
 local function enter() step(r.Vector3.new(0,3,0)) end

 -- 1. No pass: the pad prompts the GAMEPASS and pays nothing.
 enter()
 assert(prompts==1 and productPrompts==0 and moved==0 and commits==0,'Unowned x2 pad must prompt the gamepass, not pay')
 assert(lookups==1,'The first touch asks Roblox once whether the pass is owned')
 assert(doubleWinsPad.PendingPad(player)==pad,'Must remember the pad the prompt was opened from')
 print('PASS unowned x2 pad prompts the permanent gamepass and pays nothing')

 -- 2. Cancelled prompt: still nothing, and the pending pad is dropped.
 marketplace.PromptGamePassPurchaseFinished:Fire(player,PASS_ID,false)
 step()
 assert(commits==0 and attrs.DoubleWinsPadUnlocked==nil,'A cancelled prompt must not unlock or pay')
 assert(doubleWinsPad.PendingPad(player)==nil,'A cancelled prompt must drop the pending pad')

 -- 3. Walking back on re-prompts, without asking Roblox again on every touch.
 leave();enter()
 assert(prompts==2 and commits==0,'Returning to the pad without the pass prompts again')
 assert(lookups==2,'Ownership is looked up once per session, plus once when a prompt closes unbought')
 print('PASS cancelled purchase pays nothing and re-prompts on the next visit')

 -- 4. Buying while standing on the pad claims it through the normal path.
 owned=true
 marketplace.PromptGamePassPurchaseFinished:Fire(player,PASS_ID,true)
 assert(attrs.DoubleWinsPadUnlocked==true and attrs.TwoXVictoryOwned==true,'Purchase must mark the pass as owned')
 step()
 -- 100 base x2 (pads pass) x16 (Wins ladder multiplier) = 3200.
 assert(moved==1 and commits==1 and wins==3200,'x2 pad must stack its doubling on top of the Wins ladder multiplier')
 print('PASS buying the pass while on the pad claims it: 100 x2 pad x16 ladder = 3200')

 -- 5. The pass is permanent: later visits pay without any prompt.
 leave();enter()
 assert(moved==2 and commits==2 and wins==6400 and prompts==2,'An owned pass must keep paying double with no prompt')
 print('PASS the x2 pads pass is permanent, not charged per claim')

 -- 6. A rejected durable commit still returns the player without awarding wins.
 leave();commitKind='Rejected';local previousWins=wins
 enter()
 assert(moved==3 and root.Position.X==100 and wins==previousWins,'Rejected durable reward did not preserve teleport-before-commit behavior')
 print('PASS actual RewardPadClaims: rejected commit leaves character returned to start without awarding wins')

 assert(productPrompts==0,'No step of the x2 pad flow may prompt a developer product')
end
