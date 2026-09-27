local fs=require('@lune/fs')
local luau=require('@lune/luau')
local rb=require('@lune/roblox')
local V=rb.Vector3
local CF=rb.CFrame
local function slice(s,a,b)
 local i=assert(s:find(a,1,true),a); local j=assert(s:find(b,i+1,true),b)
 return s:sub(i,j-1)
end
local function signal()
 local listeners={}
 return {Connect=function(_,fn)
  local item={fn=fn,live=true}; table.insert(listeners,item)
  return {Disconnect=function() item.live=false end}
 end,Fire=function(_,...)
  for _,item in ipairs(listeners) do if item.live then item.fn(...) end end
 end,Count=function() local n=0;for _,i in ipairs(listeners) do if i.live then n+=1 end end;return n end}
end
local function part(name,parent,position)
 return {Name=name,Parent=parent,Position=position or V.zero,Size=V.new(2,2,2),IsA=function(_,class) return class=='BasePart' end}
end
local function character()
 local c={children={},attrs={},ChildAdded=signal(),ChildRemoved=signal()}
 c.humanoid={Health=100,IsA=function(_,class) return class=='Humanoid' end}
 function c:GetChildren() return self.children end
 function c:FindFirstChildOfClass(class) return class=='Humanoid' and self.humanoid or nil end
 function c:GetAttribute(key) return self.attrs[key] end
 function c:FindFirstChild(name) for _,p in ipairs(self.children) do if p.Name==name then return p end end;return nil end
 function c:Add(p) p.Parent=self;table.insert(self.children,p);self.ChildAdded:Fire(p) end
 function c:Remove(p) table.remove(self.children,assert(table.find(self.children,p)));p.Parent=nil;self.ChildRemoved:Fire(p) end
 c:Add(part('HumanoidRootPart',c));c:Add(part('Head',c))
 return c
end
local c=character()
local player={Character=c,attrs={}}
function player:GetAttribute(key) return self.attrs[key] end
local players={GetPlayerFromCharacter=function(_,char) return char==c and player or nil end}
local src=fs.readFile('audit/merged/World1/ServerScriptService/Gameplay/Presser1Controller.luau')
local shapeResult=nil;local casts=0
local workspace={Shapecast=function(_,hazard,direction,params)
 casts+=1;assert(direction==V.new(0,20,0));assert(#params.FilterDescendantsInstances==1)
 return shapeResult
end}
local helpers=luau.load(slice(src,'local HAZARD_BODY_NAMES','local function startPresser')..'\nreturn {find=findPlayerHumanoid,sweep=sweptBodyContact}',{environment={Players=players,Workspace=workspace,RaycastParams={new=function() return {} end},Enum=rb.Enum}})()
assert(helpers.find(c:FindFirstChild('Head'))==c.humanoid)
assert(helpers.find(c:FindFirstChild('HumanoidRootPart'))==nil,'invisible root was lethal')
local accessory={Parent=c};local handle=part('Head',accessory)
assert(helpers.find(handle)==nil,'accessory with body-like name was lethal')
assert(helpers.find(part('Handle',c))==nil,'tool handle was lethal')
local presser={Position=V.zero}
assert(helpers.sweep(presser,CF.new(0,20,0),c:FindFirstChild('Head'))==false,'broad box killed without shape contact')
shapeResult={};assert(helpers.sweep(presser,CF.new(0,20,0),c:FindFirstChild('Head')))
assert(helpers.sweep(presser,CF.new(),c:FindFirstChild('Head'))==false and casts==2,'zero movement cast')
print('PASS Presser: body only; accessory/root exclusion; broad phase requires real shape contact')

src=fs.readFile('audit/merged/World1/ServerScriptService/Gameplay/NewWorld1ServerMotion.luau')
local getParams=luau.load(slice(src,'local HAMMER_VISIBLE_BODY_NAMES','local function exactHammerTouchesCharacter')..'\nreturn getHammerCharacterOverlapParams',{environment={normalizeName=function(n) return n:lower():gsub('[^%w]','') end,OverlapParams={new=function() return {} end},Enum=rb.Enum}})()
assert(#getParams(c).FilterDescendantsInstances==1)
local torso=part('UpperTorso',c);c:Add(torso)
assert(#getParams(c).FilterDescendantsInstances==2,'late avatar parts ignored')
c:Remove(torso);assert(#getParams(c).FilterDescendantsInstances==1,'removed avatar parts retained')
print('PASS Hammer: late-added and removed body parts refresh contact filter')

src=fs.readFile('audit/merged/World2/ServerScriptService/Gameplay/World2TreeSlammers.luau')
local hit=signal();local tree={Parent={}}
local bounds={[tree]={center=V.zero,radius=100}}
luau.load(slice(src,'local HAZARD_BODY_NAMES','Players.PlayerRemoving:Connect'),{environment={
 hitRemote={OnServerEvent=hit},treeObjects={[1]=tree},treeContactBounds=bounds,
 SAFE_ZONE_ATTRIBUTE='SafeZoneProtected',TREE_COUNT=6,os={clock=function() return 100 end}
}})()
for _,bad in ipairs({'1',0,1.5,7,math.huge,0/0,{}}) do hit:Fire(player,bad) end
assert(c.humanoid.Health==100,'invalid remote tree index killed')
player.attrs.StageTeleportInvulnerable=true;hit:Fire(player,1)
assert(c.humanoid.Health==100,'arrival protection ignored')
-- Reset the per-player cooldown by using a fresh sender; no data or real remote involved.
local function sender(char,attrs) return {Character=char,GetAttribute=function(_,key) return (attrs or {})[key] end} end
local far=character();for _,p in ipairs(far.children) do p.Position=V.new(1000,0,0) end
hit:Fire(sender(far),1);assert(far.humanoid.Health==100,'remote outside tree swing accepted')
local safe=character();hit:Fire(sender(safe,{SafeZoneProtected=true}),1);assert(safe.humanoid.Health==100)
local near=character();hit:Fire(sender(near),1);assert(near.humanoid.Health==0,'local self contact in possible swing was not confirmed')
print('PASS Tree remote: integer indices, teleport/safe protection, swing eligibility, sender-only death')

src=fs.readFile('audit/merged/World2/StarterPlayer/StarterPlayerScripts/Gameplay/World2TreeSlammers.luau')
local clientPlayer={attrs={}}
function clientPlayer:GetAttribute(key) return self.attrs[key] end
local client=luau.load(slice(src,'local character = nil','player.CharacterAdded:Connect')..'\n'..slice(src,'local function isLocallySafe()','local function localKill')..'\nreturn {refresh=refreshCharacter,safe=isLocallySafe,state=function() return character,humanoid,rootPart,characterParts end}',{environment={player=clientPlayer,SAFE_ZONE_ATTRIBUTE='SafeZoneProtected'}})()
local old,new=character(),character();client.refresh(old);assert(old.ChildAdded:Count()==1)
client.refresh(new);assert(old.ChildAdded:Count()==0 and old.ChildRemoved:Count()==0,'old avatar connections retained')
old.ChildAdded:Fire({Name='HumanoidRootPart',IsA=function(_,class) return class=='BasePart' end})
local active,humanoid,root,bodyParts=client.state()
assert(active==new and humanoid==new.humanoid and root==new:FindFirstChild('HumanoidRootPart'))
assert(#bodyParts==1)
clientPlayer.attrs.StageTeleportInvulnerable=true;assert(client.safe())
clientPlayer.attrs.StageTeleportInvulnerable=nil;assert(not client.safe())
print('PASS Tree client: respawn disconnects old avatar; protection respected locally')
print('All hazard review tests passed (mocked spatial engine; geometry must be playtested in Roblox)')
