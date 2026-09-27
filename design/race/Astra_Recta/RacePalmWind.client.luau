-- One client controller for all palms. Put in StarterPlayerScripts.
-- LOD: at most 6 nearby trees on touch devices, 14 on desktop; no server scripts.
local CollectionService = game:GetService('CollectionService')
local RunService = game:GetService('RunService')
local UserInputService = game:GetService('UserInputService')
local records = {}
local active = {}
local mobile = UserInputService.TouchEnabled
local radius = mobile and 190 or 380
local limit = mobile and 6 or 14
local function register(p)
 if not p:IsA('BasePart') or records[p] then return end
 local base = p:GetAttribute('WindBase')
 local crown = p:GetAttribute('WindCrown')
 if typeof(base)~='Vector3' or typeof(crown)~='Vector3' then return end
 records[p]={part=p,rest=p.CFrame,base=base,crown=crown,phase=p:GetAttribute('WindPhase') or 0,kind=p:GetAttribute('WindKind'),tree=p:GetAttribute('WindTree')}
end
for _,p in CollectionService:GetTagged('RacePalmWind') do register(p) end
CollectionService:GetInstanceAddedSignal('RacePalmWind'):Connect(register)
CollectionService:GetInstanceRemovedSignal('RacePalmWind'):Connect(function(p)records[p]=nil end)
local selectTime,stepTime,t=0,0,0
RunService.Heartbeat:Connect(function(dt)
 t+=dt;selectTime+=dt;stepTime+=dt
 if selectTime>=.5 then
  selectTime=0
  for _,r in active do if r.part.Parent then r.part.CFrame=r.rest end end
  table.clear(active)
  local camera=workspace.CurrentCamera
  if not camera then return end
  local candidates={}
  local distances={}
  for _,r in records do
   if r.part.Parent and r.part.Transparency<.95 and r.part.LocalTransparencyModifier<.95 then
    local distance=(r.base-camera.CFrame.Position).Magnitude
    if distance<radius then distances[r.tree]=math.min(distances[r.tree] or math.huge,distance) end
   end
  end
  for tree,distance in distances do table.insert(candidates,{tree=tree,distance=distance}) end
  table.sort(candidates,function(a,b)return a.distance<b.distance end)
  local chosen={}
  for i=1,math.min(limit,#candidates) do chosen[candidates[i].tree]=true end
  for _,r in records do if chosen[r.tree] then table.insert(active,r) end end
 end
 if stepTime<(mobile and 1/20 or 1/30) then return end
 stepTime=0
 for _,r in active do
  local p=r.part
  if p.Parent and p.Transparency<.95 and p.LocalTransparencyModifier<.95 then
   local a=math.sin(t*1.1+r.phase)*.018
   local b=math.sin(t*.83+r.phase+1.7)*.012
   local base=CFrame.new(r.base)
   local sway=base*CFrame.Angles(a,0,b)*base:Inverse()
   if r.kind=='canopy' then
    local crown=CFrame.new(r.crown)
    sway=sway*crown*CFrame.Angles(math.sin(t*1.5+r.phase)*.038,0,math.cos(t*1.2+r.phase)*.03)*crown:Inverse()
   end
   p.CFrame=sway*r.rest
  end
 end
end)
