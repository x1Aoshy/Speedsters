-- Build from immutable current places, preserving all authored non-source properties.
local fs=require('@lune/fs')
local rb=require('@lune/roblox')
local luau=require('@lune/luau')
local serde=require('@lune/serde')
local manifest=serde.decode('json',fs.readFile('src/manifest.json'))
assert(manifest.formatVersion==1,'Unsupported manifest version')
local output='output/Update2_core'
local artifacts={};local report={coreVersion=manifest.coreVersion,worlds={}}
-- Declared corrections to authored, non-source properties. Each one checks the value
-- it replaces, and the graph comparison below reverts exactly these first, so that
-- check still proves nothing else in the authored place moved.
-- The Main HUD's x2 badges in vivid colours (2026-09-18, mobile/console pass): x2 Victory
-- (Wins) in gold, x2 Speed in blue with a navy outline instead of the shared orange.
local function colours(stops)
 local points={}
 for _,stop in stops do table.insert(points,rb.ColorSequenceKeypoint.new(stop[1],stop[2])) end
 return rb.ColorSequence.new(points)
end
local AUTHORED_BADGE_FILL=colours({
 {0,rb.Color3.new(1,0.7921568751,0.0392156877)},
 {0.7799295783,rb.Color3.new(0.8235294223,0.4862745106,0.0980392173)},
 {1,rb.Color3.new(0.8470588326,0.4392156899,0.1686274558)},
})
local HUD_BADGE_PATCHES={
 {path={'StarterGui','Mainhud','Rightbuttons','2xVictory','UIGradient'},class='UIGradient',property='Color',from=AUTHORED_BADGE_FILL,
  to=colours({{0,rb.Color3.fromRGB(255,232,90)},{0.5,rb.Color3.fromRGB(255,190,0)},{1,rb.Color3.fromRGB(222,128,0)}})},
 {path={'StarterGui','Mainhud','Rightbuttons','2xSpeed','UIGradient'},class='UIGradient',property='Color',from=AUTHORED_BADGE_FILL,
  to=colours({{0,rb.Color3.fromRGB(120,235,255)},{0.55,rb.Color3.fromRGB(30,160,255)},{1,rb.Color3.fromRGB(20,92,214)}})},
 -- The first of 2xSpeed's two UIStrokes is its dark outline.
 {path={'StarterGui','Mainhud','Rightbuttons','2xSpeed','UIStroke'},nth=1,class='UIStroke',property='Color',from=rb.Color3.fromRGB(88,51,18),to=rb.Color3.fromRGB(11,27,61)},
 -- The second is its light inner rim, orange to yellow like x2 Victory's: cyan on x2 Speed
 -- (2026-09-18 playtest: "not all light blue, it has some yellow").
 {path={'StarterGui','Mainhud','Rightbuttons','2xSpeed','UIStroke','UIGradient'},nth={[5]=2},class='UIGradient',property='Color',
  from=colours({
   {0,rb.Color3.new(1,0.5372549295,0.2274509817)},
   {0.5088028312,rb.Color3.new(1,0.9176470637,0.2784313858)},
   {1,rb.Color3.new(1,0.8352941275,0)},
  }),
  to=colours({{0,rb.Color3.fromRGB(150,240,255)},{0.5088028312,rb.Color3.fromRGB(215,250,255)},{1,rb.Color3.fromRGB(90,200,255)}})},
}
local HUD_SPRINT_PATCHES={
 {path={'StarterGui','Mainhud','MobileSprint','UIStroke'},nth=1,class='UIStroke',property='Color',from=rb.Color3.new(0,0,0),to=rb.Color3.fromRGB(11,27,61)},
 {path={'StarterGui','Mainhud','MobileSprint','UIStroke'},nth=1,class='UIStroke',property='Thickness',from=3,to=2.5},
 {path={'StarterGui','Mainhud','MobileSprint','UIStroke'},nth=2,class='UIStroke',property='Color',from=rb.Color3.new(0,0,0),to=rb.Color3.fromRGB(255,255,255)},
 {path={'StarterGui','Mainhud','MobileSprint','UIStroke'},nth=2,class='UIStroke',property='Thickness',from=3,to=1.5},
 {path={'StarterGui','Mainhud','MobileSprint'},class='TextButton',property='TextStrokeColor3',from=rb.Color3.new(0,0,0),to=rb.Color3.fromRGB(11,27,61)},
 {path={'StarterGui','Mainhud','MobileSprint'},class='TextButton',property='TextStrokeTransparency',from=1,to=0},
}
local PROPERTY_PATCHES={
 World1={
  -- Imported with Sandboxed on, so Roblox refused its FireServer on the (unsandboxed)
  -- GlobalAnnouncementRequest remote and admin broadcasts never left the client.
  {path={'StarterGui','Messages','MessageHandler'},class='LocalScript',property='Sandboxed',from=true,to=false},
  -- The game is English only: placeholder texts the designer left in Spanish (each is
  -- redrawn once data arrives, but shows until then).
  {path={'StarterGui','Rebirth','Rebirth','BeforeMax','Speed'},class='TextLabel',property='Text',from='Nivel Max 100',to='Level Max 100'},
  {path={'StarterGui','Rebirth','Rebirth','AfterMax','Speed'},class='TextLabel',property='Text',from='Nivel Max 100',to='Level Max 100'},
  {path={'StarterGui','Evolve','Evolve','ProgressFrame','Levelnext'},class='TextLabel',property='Text',from='Nivel 34/40 I Rebirth 1/2',to='Level 34/40 I Rebirth 1/2'},
  {path={'StarterGui','TimeGift','TimeGift','Frame','12','Name'},class='TextLabel',property='Text',from='317 Victorias',to='317 Wins',nth=1},
 },
 World2={
  -- Same import, same fault.
  {path={'StarterGui','Messages','MessageHandler'},class='LocalScript',property='Sandboxed',from=true,to=false},
 },
 World3={
  -- World 3's input takes StarterGui from World 2's (audit/compose_world3.luau).
  {path={'StarterGui','Messages','MessageHandler'},class='LocalScript',property='Sandboxed',from=true,to=false},
 },
}
for _,world in {'World1','World2','World3'} do
 for _,patch in HUD_BADGE_PATCHES do table.insert(PROPERTY_PATCHES[world],patch) end
 for _,patch in HUD_SPRINT_PATCHES do table.insert(PROPERTY_PATCHES[world],patch) end
end
-- Art added in Studio, captured into src/assets by audit/capture_world1_assets.luau and
-- placed in EVERY world. An asset may not carry a single script (the Tung Tung rig came
-- from a free model with two hidden PositionsFix scripts), and the graph comparison
-- below removes these first, so it still proves nothing authored moved.
local ASSETS={
 {source='src/assets/TungTung.rbxm',parent={'ServerStorage'},name='TungTung'},
 {source='src/assets/Aura67.rbxm',parent={'ServerStorage','AuthoredAuras'},name='67'},
 -- The original Water, Galaxy and Cursed auras (audit/capture_aura_sources.luau).
 {source='src/assets/AquaticOpenSource.rbxm',parent={'ServerStorage','AuthoredAuras'},name='AquaticOpenSource'},
 {source='src/assets/GalacticOpenSource.rbxm',parent={'ServerStorage','AuthoredAuras'},name='GalacticOpenSource'},
 {source='src/assets/CursedEnergy.rbxm',parent={'ServerStorage','AuthoredAuras'},name='CursedEnergy'},
 -- The finished UIs, saved into StarterGui so they are real instances in the places
 -- (audit/build_ui_prefabs.luau).
 {source='src/ui/SpinWheelGui.rbxm',parent={'StarterGui'},name='SpinWheelGui'},
 {source='src/ui/AfkRewardsGui.rbxm',parent={'StarterGui'},name='AfkRewardsGui'},
 {source='src/ui/QuestGui.rbxm',parent={'StarterGui'},name='QuestGui'},
 -- Pieces added to authored HUDs (audit/build_ui_prefabs.luau): the Revive offer's close X
 -- and the touch Sprint button's pressed state.
 {source='src/ui/ReviveCloseButton.rbxm',parent={'StarterGui','RevivePromptHUD','ReviveOfferHolder'},name='CloseButton'},
 {source='src/ui/MobileSprintPressScale.rbxm',parent={'StarterGui','Mainhud','MobileSprint'},name='PressScale'},
 {source='src/ui/MobileSprintLabel.rbxm',parent={'StarterGui','Mainhud','MobileSprint'},name='Label'},
 -- The Sonic Burst ability's HUD button and its card in the Abilities panel.
 {source='src/ui/SonicBurstButton.rbxm',parent={'StarterGui','Mainhud'},name='SonicBurstButton'},
 {source='src/ui/SonicBurstCard.rbxm',parent={'StarterGui','Abilities','Panel','ScrollingFrame'},name='SonicBurstCard'},
 -- Superman's Heat Vision button.
 {source='src/ui/HeatVisionButton.rbxm',parent={'StarterGui','Mainhud'},name='HeatVisionButton'},
 -- The Superman and A-Train rigs their skins are worn from (audit/capture_skin_rigs.luau).
 {source='src/assets/SkinRigs.rbxm',parent={'ReplicatedStorage'},name='SkinRigs'},
 {source='src/assets/Titles.rbxm',parent={'ReplicatedStorage'},name='Titles'},
 -- 3D Spin Wheel Lobby models in Workspace (audit/build_ui_prefabs.luau).
 {source='src/assets/SpinWheelLobby_World1.rbxm',parent={'Workspace'},name='SpinWheelLobby',world='World1'},
 {source='src/assets/SpinWheelLobby_World2.rbxm',parent={'Workspace'},name='SpinWheelLobby',world='World2'},
 {source='src/assets/SpinWheelLobby_World3.rbxm',parent={'Workspace'},name='SpinWheelLobby',world='World3'},
}
-- Root places the user saved from Studio that were reviewed and reconciled, by sha256:
-- the build replaces them with its output, so each entry is needed once.
local RECONCILED_LATEST={
 -- 2026-09-17: World 1 plus ServerStorage.TungTung and ServerStorage.67 (now ASSETS);
 -- the rest is Studio's save noise (ScriptGuid, FilteredSelection, new defaults).
 -- 2026-09-18 11:39: World 1 plus Workspace.Superman and Workspace.V0_7H (A-Train), the
 -- skin rigs, now ReplicatedStorage.SkinRigs in every place (audit/capture_skin_rigs.luau;
 -- the save is kept in audit/studio_saves). Nothing else changed: no script, no other part.
 World1={['0495478f5ff6bc0aa0e29979908d1713c6995aee02092c8c68e2ada897a5a19b']=true,
  ['657552dd15cc85d78cf97e5d4101862d0bd47c364b1baacafc1cf6ba159fa784']=true,
  ['e75e3bfef6cb755f217ab12d963560d3d018e3f8a7b8e88a82d2d6c40e9ab030']=true},
 World2={['9ca3c4d6b45aac3ffdd217d1a79d88ff010f0804e9b19c9187bcafcdcfbb422e']=true},
 World3={['1c5141e506ae2d64d1772c0716eb6dc009650e76a8f4392f99b013fe4a6dafc3']=true},
}
local function findUnique(root,names,nth)
 local current=root
 for index,name in names do
  if not current then return nil end
  local match=nil;local seen=0
  -- `nth` picks one of several same-named children: a number for the last step of the
  -- path, or a table {[step]=n} for any step.
  local want=if type(nth)=='table' then nth[index] elseif index==#names then nth else nil
  for _,c in current:GetChildren() do
   if c.Name==name then
    seen+=1
    if want then
     if seen==want then match=c end
    else
     assert(match==nil,'Ambiguous property patch path: '..table.concat(names,'.'));match=c
    end
   end
  end
  current=match
 end
 return current
end
local function key(names) return serde.encode('json',names) end
local function newInstance(class, identity)
 -- Explicit IDs avoid Lune resolving new zero-ID nodes against Gemini's existing
 -- zero-ID AdminPanelAction remote and silently changing that remote's UniqueId.
 assert(class=='Folder' or class=='ModuleScript' or class=='Script' or class=='LocalScript')
 local id='1'..serde.hash('sha256','update2-core:'..identity):sub(2,32)
 return rb.deserializeModel('<roblox version="4"><Item class="'..class..'" referent="0"><Properties><UniqueId name="UniqueId">'..id..'</UniqueId></Properties></Item></roblox>')[1]
end
local function segments(instance)
 local result={}
 while instance.Parent do table.insert(result,1,instance.Name);instance=instance.Parent end
 return result
end
local common={}
for _,data in manifest.worlds do for _,row in data.scripts do
 if row.source:sub(1,11)=='src/common/' then common[row.source]=serde.hash('sha256',fs.readFile(row.source)) end
end end
local ordered={};for path,hash in common do table.insert(ordered,path..'\0'..hash) end;table.sort(ordered)
report.commonSourceSha256=serde.hash('sha256',table.concat(ordered,'\n'))
report.commonSources=common
for _,world in {'World1','World2','World3'} do
 local data=manifest.worlds[world]
 local raw=fs.readFile(data.input)
 assert(serde.hash('sha256',raw)==data.inputSha256,'Immutable base changed: '..world)
 -- A world's first build has no root place yet; it starts from its input.
 local latestRaw = if fs.isFile(data.latestInput) then fs.readFile(data.latestInput) else raw
 local isOutput = fs.isFile(output..'/'..world..'.rbxl') and latestRaw == fs.readFile(output..'/'..world..'.rbxl')
 local reconciled = (RECONCILED_LATEST[world] or {})[serde.hash('sha256',latestRaw)] == true
 assert(latestRaw == raw or isOutput or reconciled, 'New Gemini input detected; reconcile before building '..world)
 local place=rb.deserializePlace(raw);local original=place:GetDescendants()
 local originals={};local changed={};local added={};local folders={};local sourceHashes={};local covered={}
 for _,i in original do if i:IsA('LuaSourceContainer') then
  local k=key(segments(i));originals[k]=originals[k] or {};table.insert(originals[k],i.Source)
 end end
 for _,row in data.scripts do
  assert(row.source:sub(1,4)=='src/' and not row.source:find('..',1,true),'Source outside src')
  local source=fs.readFile(row.source);luau.compile(source)
  sourceHashes[row.source]=serde.hash('sha256',source)
  if not row.duplicate then
   local exported='audit/merged/'..world..'/'..row.legacyPath..'.luau'
   assert(fs.isFile(exported) and fs.readFile(exported)==source,'Run export_compat_sources before tests/build: '..row.source)
  end
  if row.added then
   local parent=place
   for n=1,#row.segments-1 do
    local name=row.segments[n];local found=parent:FindFirstChild(name)
    if not found then
     found=newInstance('Folder',world..':'..table.concat(row.segments,'/',1,n));found.Name=name;found.Parent=parent
     table.insert(folders,segments(found))
    end
    parent=found
   end
   assert(not parent:FindFirstChild(row.segments[#row.segments]),'Added instance already exists: '..row.path)
   local i=newInstance(row.class,world..':'..key(row.segments));i.Name=row.segments[#row.segments];i.Source=source;i.Parent=parent
   table.insert(added,row.segments)
  else
   local i=original[row.id];assert(i and i.ClassName==row.class and key(segments(i))==key(row.segments),'Instance identity mismatch: '..row.path)
   assert(not covered[row.id],'Duplicate instance in manifest');covered[row.id]=true
   if i.Source~=source then i.Source=source;table.insert(changed,{path=row.path,id=row.id}) end
  end
 end
 for id,i in original do if i:IsA('LuaSourceContainer') then assert(covered[id],'Untracked source: '..i:GetFullName()) end end
 local assetsAdded={}
 for _,asset in ASSETS do
  if asset.world and asset.world ~= world then continue end
  local model=rb.deserializeModel(fs.readFile(asset.source))
  assert(#model==1 and model[1].Name==asset.name,'Asset must hold exactly '..asset.name..': '..asset.source)
  local root=model[1]
  for _,d in root:GetDescendants() do assert(not d:IsA('LuaSourceContainer'),'Assets may not carry scripts: '..d:GetFullName()) end
  local parent=findUnique(place,asset.parent)
  assert(parent,'Asset parent missing in '..world..': '..table.concat(asset.parent,'.'))
  assert(not parent:FindFirstChild(asset.name),'Asset already exists in '..world..': '..asset.name)
  root.Parent=parent
  local path=table.clone(asset.parent);table.insert(path,asset.name)
  table.insert(assetsAdded,path)
 end
 local patches=PROPERTY_PATCHES[world] or {}
 for _,patch in patches do
  local label=table.concat(patch.path,'.')..'.'..patch.property
  local target=findUnique(place,patch.path,patch.nth)
  assert(target and target.ClassName==patch.class,'Property patch target missing: '..label)
  assert(target[patch.property]==patch.from,'Property patch is stale, authored value changed: '..label)
  target[patch.property]=patch.to
 end
 local encoded=rb.serializePlace(place)
 local decoded=rb.deserializePlace(encoded)
 local count=0
 for _,i in decoded:GetDescendants() do if i:IsA('LuaSourceContainer') then luau.compile(i.Source);count+=1 end end
 local function find(names)
  local current=decoded
  for _,name in names do
   if not current then return nil end
   current=current:FindFirstChild(name)
  end
  return current
 end
 for _,path in assetsAdded do
  local inst=find(path)
  assert(inst,'Asset did not survive serialization: '..table.concat(path,'.'))
  inst:Destroy()
 end
 for index=#added,1,-1 do
  local inst=find(added[index])
  if inst then inst:Destroy() end
 end
 for index=#folders,1,-1 do
  local folder=find(folders[index])
  if folder then
   assert(#folder:GetChildren()==0,'Unexpected content in added folder')
   folder:Destroy()
  end
 end
 local restoredCounts={}
 for _,i in decoded:GetDescendants() do if i:IsA('LuaSourceContainer') then
  local k=key(segments(i));restoredCounts[k]=(restoredCounts[k] or 0)+1
  i.Source=assert(originals[k] and originals[k][restoredCounts[k]],'Unexpected restored source')
 end end
 for _,patch in patches do
  local label=table.concat(patch.path,'.')..'.'..patch.property
  local target=findUnique(decoded,patch.path,patch.nth)
  assert(target and target[patch.property]==patch.to,'Property patch did not survive serialization: '..label)
  target[patch.property]=patch.from
 end
 local normalized=rb.serializePlace(rb.deserializePlace(rb.serializePlace(rb.deserializePlace(raw))))
 if rb.serializePlace(decoded)~=normalized then
  fs.writeFile('audit/core_restored_debug.rbxlx',rb.serializePlace(decoded,true))
  fs.writeFile('audit/core_baseline_debug.rbxlx',rb.serializePlace(rb.deserializePlace(normalized),true))
  error('Authored graph/properties changed unexpectedly: '..world)
 end
 artifacts[world]=encoded
 report.worlds[world]={input=data.input,inputSha256=data.inputSha256,output=output..'/'..world..'.rbxl',
  outputSha256=serde.hash('sha256',encoded),compiledScripts=count,changedScripts=changed,addedInstances=added,
  addedFolders=folders,addedAssets=assetsAdded,sourceHashes=sourceHashes,authoredNonSourceGraphPreserved=true,propertyPatches=#patches}
 print('PASS '..world..': '..count..' scripts compile; exact authored graph preserved; '..#changed..' source updates, '..#added..' added modules, '..#assetsAdded..' assets, '..#patches..' declared property patches')
end
-- No artifact is replaced until EVERY world passes structural validation.
fs.writeDir(output)
local rootFiles = {
 World1 = { 'World1Update3.rbxl' },
 World2 = { 'World2Update3.rbxl' },
 World3 = { 'World3Update3.rbxl' },
}
for world,raw in artifacts do
 fs.writeFile(output..'/'..world..'.rbxl',raw)
 if rootFiles[world] then
  for _, dest in ipairs(rootFiles[world]) do
   fs.writeFile(dest, raw)
  end
 end
end
fs.writeFile(output..'/manifest.json',serde.encode('json',report,true))
print('PASS all worlds use common core '..report.commonSourceSha256)
