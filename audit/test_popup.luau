local fs=require('@lune/fs')
local luau=require('@lune/luau')
local r=require('@lune/roblox')
local process=require('@lune/process')
local sourceRoot=process.args[1] or 'audit/source/V2'
local source=fs.readFile(fs.isFile(sourceRoot) and sourceRoot or sourceRoot..'/StarterPlayer/StarterPlayerScripts/Movement/SpeedsterClient.luau')
source=source:sub(1,assert(source:find('local LEGACY_BOOST_INSTANCES',1,true))-1)
local jobs,now,created,tweens={ },0,{},{}
local function schedule(delay,fn,...)
 table.insert(jobs,{at=now+delay,fn=fn,args=table.pack(...)})
end
local function drain(untilTime)
 local n=0
 while #jobs>0 do
  table.sort(jobs,function(a,b) return a.at<b.at end)
  if jobs[1].at>untilTime then break end
  local job=table.remove(jobs,1); now=job.at; job.fn(table.unpack(job.args)); n+=1
  assert(n<10000,'scheduler runaway')
 end
 now=untilTime
end
local function signal()
 local listeners={}
 return {Connect=function(_,fn) table.insert(listeners,fn); return {Disconnect=function() end} end,
 Once=function(_,fn) table.insert(listeners,fn) end,
 Wait=function() end,
 Fire=function(_,...) for _,fn in table.clone(listeners) do fn(...) end end}
end
local methods={}
local function obj(class,name)
 local o=setmetatable({ClassName=class,Name=name or class,attrs={},signals={},Rotation=0,AbsoluteSize=r.Vector2.new(200,40),AbsolutePosition=r.Vector2.new(400,750)}, {__index=methods})
 if class=='BindableEvent' then o.Event=signal() end
 table.insert(created,o); return o
end
function methods:IsA(class) return self.ClassName==class or (class=='GuiObject' and (self.ClassName=='Frame' or self.ClassName=='TextLabel')) end
function methods:GetChildren() local c={} for _,o in created do if o.Parent==self then table.insert(c,o) end end return c end
function methods:FindFirstChild(name) for _,o in self:GetChildren() do if o.Name==name then return o end end end
function methods:WaitForChild(name) return self:FindFirstChild(name) end
function methods:GetAttribute(k) return self.attrs[k] end
function methods:SetAttribute(k,v) self.attrs[k]=v; if self.signals[k] then self.signals[k]:Fire() end end
function methods:GetAttributeChangedSignal(k) self.signals[k]=self.signals[k] or signal(); return self.signals[k] end
function methods:Destroy() self.Parent=nil end
function methods:Stop() end
function methods:Play() end
local pg=obj('PlayerGui'); local player=obj('Player'); pg.Parent=player; player.Parent={}
local ps=obj('PlayerScripts'); ps.Parent=player
player.UserId=1; player.attrs.DataLoaded=true; player.attrs.RawSpeed=100
local main=obj('ScreenGui','Mainhud'); main.Parent=pg
local bar=obj('Frame','LevelProgressBar'); bar.Parent=main
local frame=obj('Frame','Frame'); frame.Parent=bar
local speed=obj('TextLabel','Speed'); speed.Parent=frame
local impact=obj('BindableEvent','World1SpeedGainImpact'); impact.Parent=frame; local impacts=0
function impact:Fire() impacts+=1 end
local layer=obj('ScreenGui','SpeedPopupLayer'); layer.Parent=pg
local rs=obj('ReplicatedStorage'); local shared=obj('Folder','Shared'); shared.Parent=rs
for _,name in {'Config','StudUi','StaminaFeedback'} do local o=obj('ModuleScript',name); o.Parent=shared end
local remotes=obj('Folder','Remotes'); remotes.Parent=rs
local popup
for _,name in {'BoostState','SpeedGainPopup'} do local o=obj('RemoteEvent',name); o.Parent=remotes; o.OnClientEvent=signal(); if name=='SpeedGainPopup' then popup=o end end
local services={GuiService={},Players={LocalPlayer=player},ReplicatedStorage=rs,UserInputService={TouchEnabled=false},ContextActionService={},RunService={},SoundService=obj('SoundService'),Debris={AddItem=function() end}}
services.TweenService={Create=function(_,target,info,props)
 local tw={Completed=signal()}; table.insert(tweens,{target=target,props=props})
 function tw:Play() schedule(info.Time,function() if target.Parent then for k,v in props do target[k]=v end end self.Completed:Fire() end) end
 function tw:Cancel() end
 return tw
end}
local config={IsWorld2Place=false}
local fakeTask={delay=schedule,defer=function(fn,...) schedule(0,fn,...) end,spawn=function(fn,...) schedule(0,fn,...) end,wait=function() end}
luau.load(source,{environment={game={GetService=function(_,n) return assert(services[n],n) end},workspace={CurrentCamera={ViewportSize=r.Vector2.new(1920,1080)}},task=fakeTask,Instance={new=obj},UDim2=r.UDim2,UDim=r.UDim,Vector2=r.Vector2,Color3=r.Color3,ColorSequence=r.ColorSequence,ColorSequenceKeypoint=r.ColorSequenceKeypoint,Enum=r.Enum,TweenInfo={new=function(t,...) return {Time=t} end},os={clock=function() return now end},require=function(m) return m.Name=='Config' and config or {} end}})()
popup.OnClientEvent:Fire({Amount=10,BurstCount=1,IsRunningPopup=true,TotalSpeed=110})
drain(2)
local shoes=0;local homes=0
for _,o in created do if o.Name=='ShoeIcon' then shoes+=1 end end
for _,tw in tweens do if tw.props.Position==r.UDim2.fromOffset(500,770) then homes+=1 end end
assert(shoes==1,'expected one shoe, got '..shoes)
assert(homes>=1,'no tween to progress bar')
assert(impacts==1,'no impact')
print('PASS popup shoe, tween to bar, impact:',sourceRoot)
local function shoeCount() local n=0 for _,o in created do if o.Name=='ShoeIcon' then n+=1 end end return n end
player:SetAttribute('HidePopups',true)
popup.OnClientEvent:Fire({Amount=10,BurstCount=1,TotalSpeed=120})
drain(3); assert(shoeCount()==1,'HidePopups ignored')
player:SetAttribute('HidePopups',false)
if source:find('lastPopupRemoteAt',1,true) then
 player:SetAttribute('IsOnTreadmill',true)
 player:SetAttribute('RawSpeed',130)
 drain(4.5); assert(shoeCount()==2,'missing remote must still render gain')
 assert(impacts==2,'fallback did not reach bar')
 popup.OnClientEvent:Fire({Amount=30,TotalSpeed=130,BurstCount=1})
 drain(4.6); assert(shoeCount()==2,'late remote duplicates fallback')
 player:SetAttribute('RawSpeed',140)
 popup.OnClientEvent:Fire({Amount=10,TotalSpeed=140,BurstCount=1})
 drain(6); assert(shoeCount()==3,'remote and attributes duplicate popup')
 player:SetAttribute('RawSpeed',1)
 drain(7); assert(shoeCount()==3,'rebirth produced positive gain')
 player:SetAttribute('DataLoaded',false)
 player:SetAttribute('RawSpeed',10000)
 drain(8); assert(shoeCount()==3,'loading save produced false gain')
 print('PASS fallback treadmill, remote deduplication, HidePopups, rebirth and initial load')
end

