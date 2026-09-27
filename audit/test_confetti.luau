local fs=require('@lune/fs');local luau=require('@lune/luau');local r=require('@lune/roblox')
local world=require('@lune/process').args[1] or 'World1'
local function signal() local s={handlers={}};function s:Connect(fn) table.insert(self.handlers,fn);return {Disconnect=function() end} end;function s:Fire(...) for _,fn in self.handlers do fn(...) end end;return s end
local parts,prompts,delayed={},{},{}
local heartbeat=signal();local Players={};local Workspace={FindFirstChild=function() return nil end}
local Instance={new=function(class)
 local object=setmetatable({ClassName=class,Enabled=true,AncestryChanged=signal(),Triggered=signal()}, {__index=function(self,key) if key=='Position' then return self.CFrame.Position end end})
 function object:SetNetworkOwner(owner) self.OwnerAssigned=true;assert(owner==nil) end
 function object:Destroy() self.Parent=nil;self.AncestryChanged:Fire() end
 if class=='Part' then table.insert(parts,object) else table.insert(prompts,object) end
 return object
end}
local now=1000;local attrs={DataLoaded=true};local feedback=0
local root={Position=r.Vector3.new(1e5,0,0)};local humanoid={Health=100}
local player={Parent=Players,GetAttribute=function(_,k) return attrs[k] end,SetAttribute=function(_,k,v) attrs[k]=v end,Character={FindFirstChildOfClass=function() return humanoid end,FindFirstChild=function() return root end}}
local s=fs.readFile('audit/merged/'..world..'/ServerScriptService/Admin/AdminAbuseServer.luau')
local a=assert(s:find('local CONFETTI_COUNT',1,true));local b=assert(s:find('local function applyMultipliers',a,true))
local fire=luau.load(s:sub(a,b-1)..'\nreturn fireConfetti',{environment={Players=Players,workspace=Workspace,RunService={Heartbeat=heartbeat},AdminGlobalEvents={DEFAULT_CONFETTI={}},
 Instance=Instance,Vector3=r.Vector3,CFrame=r.CFrame,Color3=r.Color3,Enum=r.Enum,os={clock=function() return now end,time=function() return now end},
 Validation=require('./merged/'..world..'/ServerScriptService/Admin/AdminRequestValidation'),AdminRemote={FireClient=function() feedback+=1 end},task={delay=function(_,fn) table.insert(delayed,fn) end}}})()
for _=1,10 do fire(nil,120,120,2,2,5) end
assert(#parts==240 and #prompts==240 and #heartbeat.handlers==1,'Unbounded parts or heartbeat connections')
for _,part in parts do assert(part.OwnerAssigned) end
prompts[1].Triggered:Fire(player);assert(feedback==0,'Distant collection')
root.Position=parts[1].Position;humanoid.Health=0;prompts[1].Triggered:Fire(player);assert(feedback==0)
humanoid.Health=100;attrs.DataLoaded=false;prompts[1].Triggered:Fire(player);assert(feedback==0)
attrs.DataLoaded=true;prompts[1].Triggered:Fire(player);prompts[1].Triggered:Fire(player)
assert(feedback==1 and attrs.ConfettiBoostExpire==1300,'Duplicate reward')
local original=parts[2].CFrame;heartbeat:Fire();local updated=parts[2].CFrame;assert(updated~=original)
heartbeat:Fire();assert(parts[2].CFrame==updated,'Unthrottled animation')
for _,fn in delayed do fn() end
fire(nil,5,120,2,2,5);assert(#parts==360,'Expired pieces retain capacity')
print('PASS '..world..' actual confetti: 240 total cap, one heartbeat, 10Hz update, server ownership, distance/life/load rejection, one reward and capacity cleanup')
