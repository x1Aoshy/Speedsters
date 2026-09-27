local fs=require('@lune/fs');local rb=require('@lune/roblox');local luau=require('@lune/luau');local serde=require('@lune/serde')
local m=serde.decode('json',fs.readFile('src/manifest.json'))
local changed={
 'src/common/ReplicatedStorage/Shared/QuestUi.luau',
 'src/common/ReplicatedStorage/Shared/Catalogs/CodesCatalog.luau',
 'src/common/StarterPlayer/StarterPlayerScripts/UI/UpdateLogsController.client.luau',
 'src/common/StarterPlayer/StarterPlayerScripts/Movement/SpeedsterClient.client.luau',
 'src/common/StarterPlayer/StarterPlayerScripts/Gameplay/TreadmillVfxController.client.luau',
 'src/common/StarterPlayer/StarterPlayerScripts/Admin/AdminAbuseEffects.client.luau',
 'src/common/ServerScriptService/Admin/AdminAbusePanelService.server.luau',
 'src/common/ReplicatedStorage/Shared/Config.luau',
 'src/common/ServerScriptService/Worlds/WorldPortalService.server.luau',
 'src/common/StarterPlayer/StarterPlayerScripts/UI/WorldsController.client.luau',
}
local logs=fs.readFile(changed[3]);local updateText=assert(logs:match('local UPDATE_TEXT = %[%[(.-)%]%]'))
local function find(dm,segments) local i=dm;for _,s in segments do i=assert(i:FindFirstChild(s),table.concat(segments,'.')) end;return i end
local out='output/Update3_Reviewed_20260919';fs.writeDir(out)
local report={worlds={},changedSources=changed};local artifacts={}
for _,world in {'World1','World2','World3'} do
 local raw=fs.readFile('audit/review_20260919/'..world..'.rbxl');local dm=rb.deserializePlace(raw)
 local rows={};for _,r in m.worlds[world].scripts do rows[r.source]=r end
 local originals={}
 for _,path in changed do
  local row=assert(rows[path],path);local inst=find(dm,row.segments)
  table.insert(originals,{segments=row.segments,source=inst.Source})
  inst.Source=fs.readFile(path);luau.compile(inst.Source)
 end
 local sg=dm:GetService('StarterGui');sg.QuestGui:Destroy()
 local quest=rb.deserializeModel(fs.readFile('src/ui/QuestGui.rbxm'))[1];quest.Parent=sg
 local logChanges={}
 for _,i in sg['Update Logs']:GetDescendants() do
  if i:IsA('TextLabel') then
   local value
   if i.Text:find('NEW FEATURES',1,true) or i.Text:find('NEW CONTENT',1,true) then value=updateText
   elseif i.Name=='Update' then value='UPDATE 3!'
   elseif i.Name=='Code' then value='Codes: UPDATE3  NEWWORLD  ADMINPARTY  BOOST' end
   if value then table.insert(logChanges,{instance=i,old=i.Text});i.Text=value end
  end
 end
 local bytes=rb.serializePlace(dm);local decoded=rb.deserializePlace(bytes);local count=0
 for _,i in decoded:GetDescendants() do if i:IsA('LuaSourceContainer') then luau.compile(i.Source);count+=1 end end
 for _,path in changed do assert(find(decoded,rows[path].segments).Source==fs.readFile(path),'Serialized source mismatch') end
 local fx=decoded:GetService('ReplicatedStorage'):FindFirstChild('VfxTemplates');assert(fx)
 for _,i in fx:GetDescendants() do assert(not i:IsA('LuaSourceContainer')) end
 -- Undo exactly the declared changes and compare the entire preserved graph.
 for _,o in originals do find(dm,o.segments).Source=o.source end
 for _,o in logChanges do o.instance.Text=o.old end
 dm:GetService('StarterGui').QuestGui:Destroy()
 local baseline=rb.deserializePlace(raw);baseline:GetService('StarterGui').QuestGui:Destroy()
 local function stable(i) return (rb.serializePlace(i,true):gsub('<UniqueId name="UniqueId">.-</UniqueId>','<UniqueId/>')) end
 if stable(dm)~=stable(baseline) then fs.writeFile('scratch/review_actual.rbxlx',rb.serializePlace(dm,true));fs.writeFile('scratch/review_base.rbxlx',rb.serializePlace(baseline,true));error('Unexpected graph change '..world) end
 artifacts[world]=bytes
 report.worlds[world]={compiledScripts=count,sha256=serde.hash('sha256',bytes),preservedMapAndOtherProperties=true,vfxInstances=#fx:GetDescendants()}
 print('PASS',world,count,'scripts compile; changed sources verified; all other map properties preserved')
end
for world,bytes in artifacts do fs.writeFile(out..'/'..world..'.rbxl',bytes);fs.writeFile(world..'Update3.rbxl',bytes) end
fs.writeFile(out..'/validation.json',serde.encode('json',report,true))



