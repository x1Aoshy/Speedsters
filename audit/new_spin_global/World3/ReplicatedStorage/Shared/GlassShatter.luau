-- White camera-following glass, based on the supplied shatter effect.
local Debris=game:GetService("Debris")
local Lighting=game:GetService("Lighting")
local RunService=game:GetService("RunService")
local TweenService=game:GetService("TweenService")
local GlassShatter={}
-- The smash: Config.GlassBreakSoundId (ProSoundEffects' "Glass Smashes 7", checked to be
-- audio). The id it first shipped with (9114223175) was not audio, so Roblox refused it
-- on every shatter with "Asset type does not match requested type".
do
 local ok,Config=pcall(function()
  return require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
 end)
 GlassShatter.SoundId=ok and type(Config)=="table" and Config.GlassBreakSoundId or nil
end
local activeCleanup
local serial=0
local function rng(a,b) return a+math.random()*(b-a) end
local function slice(x,y,w,h,depth,out)
 if depth<=0 then table.insert(out,{x=x,y=y,w=w,h=h});return end
 if w>h then local cut=w*rng(0.3,0.7);slice(x,y,cut,h,depth-1,out);slice(x+cut,y,w-cut,h,depth-1,out)
 else local cut=h*rng(0.3,0.7);slice(x,y,w,cut,depth-1,out);slice(x,y+cut,w,h-cut,depth-1,out) end
end
-- opts.Intensity (0.5..3, default 1) scales everything that sells the hit at once:
-- camera shake strength and length, colour distortion, blur, how hard the shards fly
-- and how loud the shockwave reads.
-- Played by Movement/StageBarrierShatter (breaking through a stage barrier or the finish at
-- speed; the sprint no longer plays it) and by the Sonic Burst's burst (opts.Always).
function GlassShatter.Play(opts)
 -- A preview feature (Shared.FeatureGate): Studio, testing places and the preview
 -- accounts. Gated here rather than at the call sites. opts.Always skips the gate for a
 -- bought ability (the Sonic Burst), which every owner must see.
 local FeatureGate=require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("FeatureGate"))
 if opts.Always~=true and not FeatureGate.IsPreviewPlayer(game:GetService("Players").LocalPlayer) then
  return
 end
 local camera=workspace.CurrentCamera
 if not camera or camera.ViewportSize.Y<=0 then return end
 if activeCleanup then activeCleanup() end
 serial+=1
 local name="GlassShatter"..serial
 local intensity=math.clamp(tonumber(opts.Intensity) or 1,0.5,3)
 local depth=math.clamp(math.floor(opts.Depth or 3),1,5)
 local distance=math.clamp(opts.Distance or 3.2,1,8)
 local halfH=distance*math.tan(math.rad(camera.FieldOfView/2))*1.15
 local width=halfH*2*camera.ViewportSize.X/camera.ViewportSize.Y
 local height=halfH*2
 local impact=opts.ImpactPosition or Vector2.new(0.5,0.5)
 local transparency=math.clamp(opts.Transparency or 0.48,0.2,0.95)
 local shakeTime=0.2+0.12*intensity
 local lifetime=0.85+0.1*intensity
 local folder=Instance.new("Folder");folder.Name="SpeedsterGlassShards";folder.Parent=camera
 local correction=Instance.new("ColorCorrectionEffect")
 correction.Name="ShatterDistortion"
 correction.Brightness=0.06*intensity;correction.Contrast=0.12*intensity;correction.Saturation=-0.12*intensity
 correction.Parent=Lighting
 TweenService:Create(correction,TweenInfo.new(0.25+0.1*intensity,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Brightness=0,Contrast=0,Saturation=0}):Play()
 local blur=Instance.new("BlurEffect");blur.Name="ShatterBlur";blur.Size=6*intensity;blur.Parent=Lighting
 TweenService:Create(blur,TweenInfo.new(0.3,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Size=0}):Play()
 local soundId=opts.SoundId or GlassShatter.SoundId
 if opts.PlaySound~=false and soundId then
  local sound=Instance.new("Sound");sound.Name="SonicBarrierShatterSound";sound.SoundId=soundId
  sound.Volume=opts.Volume or 1.2;sound.Parent=camera;sound:Play();Debris:AddItem(sound,3.5)
 end
 local pieces={};slice(0,0,width,height,depth,pieces)
 local shards={}
 local burst=0.6+0.4*intensity
 for _,piece in pieces do
  local center=Vector2.new(piece.x+piece.w/2,piece.y+piece.h/2)
  local delta=center-Vector2.new(width*impact.X,height*impact.Y)
  local direction=delta.Magnitude>0.01 and delta.Unit or Vector2.new(1,0)
  for side=1,2 do
   local part=Instance.new("WedgePart")
   part.Size=Vector3.new(piece.w,piece.h,opts.Thickness or 0.045)
   part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false;part.CastShadow=false
   part.Material=Enum.Material.Glass;part.Color=opts.Color or Color3.fromRGB(250,252,255)
   part.Reflectance=0.45;part.Transparency=transparency;part.Parent=folder
   local origin=CFrame.new(center.X-width/2,height/2-center.Y,-distance)*CFrame.Angles(0,0,(side-1)*math.pi)
   part.CFrame=camera.CFrame*origin
   table.insert(shards,{part=part,origin=origin,
    velocity=Vector3.new(direction.X*rng(2,5)*burst,-direction.Y*rng(2,5)*burst,rng(-0.5,0.2)*burst),
    rotation=Vector3.new(rng(-3,3),rng(-3,3),rng(-4,4))*burst,
    delay=(opts.HoldTime or 0.01)+delta.Magnitude/math.max(width,height)*0.2})
  end
 end
 local wave
 if opts.Shockwave~=false then
  wave=Instance.new("Part");wave.Name="SonicShockwaveRing";wave.Shape=Enum.PartType.Cylinder
  wave.Anchored=true;wave.CanCollide=false;wave.CanTouch=false;wave.CanQuery=false;wave.CastShadow=false
  wave.Material=Enum.Material.Glass;wave.Color=Color3.fromRGB(245,248,255)
  wave.Transparency=math.max(0.35,0.72-0.15*intensity);wave.Parent=folder
 end
 local waveStart=wave and wave.Transparency or 1
 local elapsed=0
 local lastOffset=CFrame.identity
 local offsetCamera=nil
 local cleaned=false
 local function unshake()
  if offsetCamera then offsetCamera.CFrame=offsetCamera.CFrame*lastOffset:Inverse();offsetCamera=nil end
  lastOffset=CFrame.identity
 end
 local function cleanup()
  if cleaned then return end;cleaned=true
  RunService:UnbindFromRenderStep(name.."Before");RunService:UnbindFromRenderStep(name)
  unshake();folder:Destroy();correction:Destroy();blur:Destroy()
  if activeCleanup==cleanup then activeCleanup=nil end
 end
 activeCleanup=cleanup
 RunService:BindToRenderStep(name.."Before",Enum.RenderPriority.Camera.Value-1,unshake)
 RunService:BindToRenderStep(name,Enum.RenderPriority.Camera.Value+2,function(dt)
  elapsed+=dt
  local cam=workspace.CurrentCamera
  if cam~=camera or not folder.Parent or elapsed>=lifetime then cleanup();return end
  if opts.CameraPunch~=false and elapsed<shakeTime then
   local strength=(1-elapsed/shakeTime)^2
   -- A hard roll kick on the first frames, then a decaying rattle.
   local kick=elapsed<0.06 and (1-elapsed/0.06) or 0
   lastOffset=CFrame.new(math.sin(elapsed*95)*0.09*intensity*strength,math.cos(elapsed*113)*0.07*intensity*strength,0)
    *CFrame.Angles(math.sin(elapsed*83)*0.018*intensity*strength,math.cos(elapsed*71)*0.008*intensity*strength,
     math.cos(elapsed*101)*0.024*intensity*strength+0.03*intensity*kick)
   cam.CFrame=cam.CFrame*lastOffset;offsetCamera=cam
  end
  for _,item in shards do
   local t=math.max(0,elapsed-item.delay)
   local drift=item.velocity*t+Vector3.new(0,-(opts.FallAcceleration or 60)*0.05*t*t,0)
   item.part.CFrame=cam.CFrame*(item.origin+drift)*CFrame.Angles(item.rotation.X*t,item.rotation.Y*t,item.rotation.Z*t)
   item.part.Transparency=transparency+(1-transparency)*math.clamp(t/0.6,0,1)
  end
  if wave then
   local grow=width*elapsed*10*(0.8+0.2*intensity)
   wave.Size=Vector3.new(0.025,1+grow,1+grow)
   wave.CFrame=cam.CFrame*CFrame.new(0,0,-distance-0.2)*CFrame.Angles(0,math.pi/2,0)
   wave.Transparency=math.min(1,waveStart+elapsed*2)
  end
 end)
 task.delay(lifetime+0.15,cleanup)
end
-- The glass before it breaks: the same camera glass, whole, trembling and fogging over while
-- the view warps and flickers behind it (the Sonic Burst's charge). `level` (0..1, set with
-- SetLevel while charging) drives how hard. Returns { SetLevel, Stop }; Play then shatters
-- the view as usual. opts.Always: shown to every player (a bought ability), not only the
-- preview accounts.
function GlassShatter.Charge(opts)
 opts=opts or {}
 local controller={SetLevel=function() end,Stop=function() end}
 local FeatureGate=require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("FeatureGate"))
 if opts.Always~=true and not FeatureGate.IsPreviewPlayer(game:GetService("Players").LocalPlayer) then
  return controller
 end
 local camera=workspace.CurrentCamera
 if not camera or camera.ViewportSize.Y<=0 then return controller end
 serial+=1
 local name="GlassCharge"..serial
 local distance=math.clamp(opts.Distance or 3.2,1,8)
 local halfH=distance*math.tan(math.rad(camera.FieldOfView/2))*1.15
 local width=halfH*2*camera.ViewportSize.X/camera.ViewportSize.Y
 local height=halfH*2
 local folder=Instance.new("Folder");folder.Name="SpeedsterGlassCharge";folder.Parent=camera
 local correction=Instance.new("ColorCorrectionEffect");correction.Name="ChargeDistortion";correction.Parent=Lighting
 local blur=Instance.new("BlurEffect");blur.Name="ChargeBlur";blur.Size=0;blur.Parent=Lighting
 local pieces={};slice(0,0,width,height,math.clamp(math.floor(opts.Depth or 3),1,4),pieces)
 local panes={}
 for _,piece in pieces do
  local centre=Vector2.new(piece.x+piece.w/2,piece.y+piece.h/2)
  for side=1,2 do
   local part=Instance.new("WedgePart")
   part.Size=Vector3.new(piece.w*0.985,piece.h*0.985,0.045)
   part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false;part.CastShadow=false
   part.Material=Enum.Material.Glass;part.Color=opts.Color or Color3.fromRGB(235,248,255)
   part.Reflectance=0.4;part.Transparency=0.95;part.Parent=folder
   local origin=CFrame.new(centre.X-width/2,height/2-centre.Y,-distance)*CFrame.Angles(0,0,(side-1)*math.pi)
   part.CFrame=camera.CFrame*origin
   table.insert(panes,{part=part,origin=origin})
  end
 end
 local level=0
 local stopped=false
 local started=os.clock()
 local function stop()
  if stopped then return end;stopped=true
  RunService:UnbindFromRenderStep(name)
  folder:Destroy();correction:Destroy();blur:Destroy()
 end
 RunService:BindToRenderStep(name,Enum.RenderPriority.Camera.Value+3,function()
  local cam=workspace.CurrentCamera
  if cam~=camera or not folder.Parent then stop();return end
  local t=os.clock()-started
  local shake=0.004+0.03*level
  -- Faster and harder the fuller the charge: the glass trembles in its frame.
  for index,pane in panes do
   local jitter=math.sin(t*(55+index*7))*shake
   pane.part.CFrame=cam.CFrame*pane.origin*CFrame.new(jitter,math.cos(t*(61+index*5))*shake,0)
    *CFrame.Angles(0,0,math.sin(t*(47+index))*shake*0.6)
   pane.part.Transparency=math.clamp(0.93-0.4*level+0.06*math.sin(t*38+index),0.35,0.97)
  end
  local flicker=0.5+0.5*math.sin(t*43)
  correction.Contrast=(0.05+0.25*level)*(0.6+0.4*flicker)
  correction.Saturation=-0.25*level
  correction.Brightness=0.04*level*flicker
  blur.Size=(1+6*level)*(0.5+0.5*flicker)
 end)
 controller.SetLevel=function(value) level=math.clamp(tonumber(value) or 0,0,1) end
 controller.Stop=stop
 return controller
end
return GlassShatter
