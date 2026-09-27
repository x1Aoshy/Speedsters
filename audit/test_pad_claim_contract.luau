local fs=require('@lune/fs'); local luau=require('@lune/luau'); local r=require('@lune/roblox')
local function signal() local s={f={}}; function s:Connect(fn) self.f[fn]=true; return {Disconnect=function() self.f[fn]=nil end} end; function s:Fire(...) for fn in self.f do fn(...) end end; return s end
for _,world in {'World1','World2'} do
 local hb=signal();local workspace={};local now=0;local attrs={DataLoaded=true}
 local players={PlayerRemoving=signal()};local root={Position=r.Vector3.new(-30,3,0),Size=r.Vector3.new(2,2,1),IsA=function() return true end}
 local hum={Health=100,WalkSpeed=1500,HipHeight=2};local char={FindFirstChildOfClass=function() return hum end,FindFirstChild=function() return root end}
 local player={UserId=7,Name='runner',Parent=players,Character=char,GetAttribute=function(_,n) return attrs[n] end}
 players.GetPlayers=function() return {player} end
 local function part(size,cf)
  local p=setmetatable({Size=size,CFrame=cf,Parent=workspace,signals={},Destroying=signal()}, {__index=function(t,k) if k=='Position' then return t.CFrame.Position end end})
  function p:GetAttribute() return nil end
  function p:GetPropertyChangedSignal(name) self.signals[name]=self.signals[name] or signal();return self.signals[name] end
  p.GetAttributeChangedSignal=p.GetPropertyChangedSignal
  function p:IsDescendantOf(other) return self.Parent ~= nil and other==workspace end
  function p:Destroy() self.Destroying:Fire();self.Parent=nil end
  return p
 end
 local clock={clock=function() return now end};local warnings={};local delayed={}
 local env={game={GetService=function(_,n) return ({Players=players,RunService={Heartbeat=hb},Workspace=workspace})[n] end},Vector3=r.Vector3,CFrame=r.CFrame,Instance={new=function() return part() end},task={spawn=function(fn) fn() end,delay=function(_,fn) table.insert(delayed,fn) end},os=clock,warn=function(s) table.insert(warnings,s) end}
 local base='audit/merged/'..world..'/ServerScriptService/Services/'
 local pads=luau.load(fs.readFile(base..'PadTouchService.luau'),{environment=env})()
 local handle={userId=7,sessionId='a',generation=1};local wins=0;local commits=0
 local data={GetHandle=function() return handle end,NewOperationId=function() return 'op'..commits end,Commit=function(_,req) wins+=req.commands[1].amount;commits+=1;return {kind='Committed'} end}
 local allowed=true;local guard={CanClaim=function() return allowed end,RecordFinalClaim=function() end}
 local claimenv=table.clone(env);claimenv.script={Parent={Data={DataService=data},MovementGuard=guard,PadTouchService=pads}};claimenv.require=function(m) return m end
 claimenv._G={SpeedsterGetPermanentWinsMultiplier=function() return 16 end}
 local claims=luau.load(fs.readFile(base..'RewardPadClaims.luau'),{environment=claimenv})()
 local pad=part(r.Vector3.new(7,.5,7),r.CFrame.new());local calls=0;local successful=0
 local mode='claim'
 local connection=pads.Connect(pad,function()
  calls+=1
  if mode=='retry' and not allowed then return false end
  if mode=='observe' then return true end
  local ok=claims.Claim(player,pad,100,1,false,function()
   if mode=='returnfail' then return false end
   root.Position=r.Vector3.new(100,3,0);attrs.StageTeleportProtectionSerial=(attrs.StageTeleportProtectionSerial or 0)+1
   return true
  end)
  if ok then successful+=1 end
  return ok
 end)
 local function step(pos,dt) now+=dt or 1/30;if pos then root.Position=pos end;hb:Fire(dt or 1/30) end
 step();step(r.Vector3.new(30,3,0));assert(successful==1 and wins==1600,'Fast pass must use shared server evidence')
 assert(not pads.ConsumeContact(player,pad),'Proof was consumed/invalidated by teleport')
 assert(pad.Size.Y==.5 and pad.CFrame==r.CFrame.new(),'Authored pad was moved')
 step(r.Vector3.new(30,3,0));step(r.Vector3.new(-30,3,0));assert(successful==2,'Fresh legitimate pass must work')
 -- A slow avatar cannot claim a short 60-stud teleport passing through the pad.
 hum.WalkSpeed=16;step(r.Vector3.new(-30,3,0));step(r.Vector3.new(30,3,0));assert(successful==2,'Discontinuous crossing awarded')
 -- Same position geometry rules for both services; outside expanded sphere no longer counts.
 root.Position=r.Vector3.new(15,3,0);assert(not claims.IsAtPad(player,pad))
 root.Position=r.Vector3.new(0,12,0);assert(claims.IsAtPad(player,pad),'Gemini 14-stud height lost')
 root.Position=r.Vector3.new(0,17,0);assert(not claims.IsAtPad(player,pad),'Vertical mismatch')
 -- Grace never latches inside; expiry retries without stepping away.
 mode='observe';attrs.StageTeleportArrivalGraceUntil=now+1;local before=calls
 step(r.Vector3.new(0,3,0));assert(calls==before)
 step(nil,1.1);assert(calls==before+1,'Grace expiry silently latched contact')
 -- Respawn cannot sweep the old character path.
 step(r.Vector3.new(-30,3,0));root={Position=r.Vector3.new(30,3,0),Size=r.Vector3.new(2,2,1),IsA=function() return true end};player.Character={FindFirstChildOfClass=function() return hum end,FindFirstChild=function() return root end}
 before=calls;step();assert(calls==before,'Respawn swept across pad')
 -- Callback rejection schedules bounded retries while standing, no busy loop.
 mode='retry';allowed=false;step(r.Vector3.new(0,3,0));before=calls
 step();assert(calls==before);allowed=true;mode='observe';step(nil,.6);assert(calls==before+1,'Rejected contact stayed latched')
 -- Two overlapping triggers select exactly one callback per sample, no second next frame.
 step(r.Vector3.new(100,3,0));local second=0;local overlap=part(r.Vector3.new(7,.5,7),r.CFrame.new(3,0,0));local conn2=pads.Connect(overlap,function() second+=1 end)
 before=calls;step(r.Vector3.new(0,3,0));step();assert(calls==before+1 and second==0,'Overlap dispatched more than one pad')
 connection.Disconnect();conn2.Disconnect();before=calls;step();assert(calls==before,'Removed pad still active')
 print('PASS '..world..' actual PadTouchService + RewardPadClaims: fast crossing x16, proof invalidation, speed bound, geometry, grace, respawn, bounded retry, overlap, cleanup')
end
