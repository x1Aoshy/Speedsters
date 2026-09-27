local fs=require('@lune/fs')
local rb=require('@lune/roblox')
local luau=require('@lune/luau')
local serde=require('@lune/serde')
local manifest=serde.decode('json',fs.readFile('src/manifest.json'))
local files={World1='World1Update3New.rbxl',World2='World2Update3new.rbxl',World3='World3Update3New.rbxl'}
local sources={
 'src/common/ReplicatedStorage/Shared/Config.luau',
 'src/common/ReplicatedStorage/Shared/DailyRewardsData.luau',
 'src/common/ReplicatedStorage/Shared/QuestCatalog.luau',
 'src/common/ServerScriptService/Services/FunnelAnalytics.luau',
 'src/common/ServerScriptService/Progression/RebirthSystem.server.luau',
 'src/common/ServerScriptService/Social/AfkZoneService.server.luau',
 'src/common/StarterPlayer/StarterPlayerScripts/UI/FirstTimeTutorial.client.luau',
 'src/common/StarterPlayer/StarterPlayerScripts/UI/StarterPackOffer.client.luau',
}
local stamp=os.date('!%Y%m%d_%H%M%S')
local backup='output/Backup_CoreLoop_'..stamp
local output='output/CoreLoop_Update_'..stamp
fs.writeDir(backup);fs.writeDir(output)
local contents={}
for _,path in sources do
 contents[path]=fs.readFile(path)
 luau.compile(contents[path])
end
local function find(dm,segments)
 local node=dm
 for _,segment in segments do node=assert(node:FindFirstChild(segment),segment) end
 return node
end
local prepared={}
local report={backup=backup,output=output,worlds={}}
for world,file in files do
 local raw=fs.readFile(file)
 local dm=rb.deserializePlace(raw)
 local rows={};for _,row in manifest.worlds[world].scripts do rows[row.source]=row end
 local originals={}
 for _,node in dm:GetDescendants() do
  if node:IsA('LuaSourceContainer') then originals[node:GetFullName()]=node.Source end
 end
 for _,path in sources do
  local row=assert(rows[path],world..' missing '..path)
  local node=find(dm,row.segments)
  local baseline='scratch/core_loop_baseline/'..world..'_'..path:match('[^/]+$')
  assert(node.Source==fs.readFile(baseline),'Place changed since inspection: '..world..' '..path)
  node.Source=contents[path]
 end
 local bytes=rb.serializePlace(dm)
 local verified=rb.deserializePlace(bytes)
 local changed={}
 local count=0
 for _,node in verified:GetDescendants() do
  if node:IsA('LuaSourceContainer') then
   count+=1
   local name=node:GetFullName()
   assert(originals[name]~=nil,'Unexpected script added: '..name)
   if node.Source~=originals[name] then table.insert(changed,name) end
  end
 end
 assert(#changed==#sources,'Expected only '..#sources..' changed scripts in '..world..', got '..#changed)
 assert(#dm:GetDescendants()==#verified:GetDescendants(),'Instance count changed: '..world)
 for _,path in sources do assert(find(verified,rows[path].segments).Source==contents[path],world..' source mismatch '..path) end
 fs.writeFile(backup..'/'..file,raw)
 fs.writeFile(output..'/'..file,bytes)
 prepared[world]={raw=raw,bytes=bytes}
 report.worlds[world]={file=file,scriptCount=count,changed=changed,sha256=serde.hash('sha256',bytes)}
 print('PREPARED',world,count,'scripts;',#changed,'changed; instance count preserved')
end
for world,file in files do
 assert(fs.readFile(file)==prepared[world].raw,'Concurrent place change: '..file)
 fs.writeFile(file,prepared[world].bytes)
 local check=rb.deserializePlace(fs.readFile(file))
 assert(#check:GetDescendants()>0,'Failed root re-read: '..world)
 print('SAVED',file)
end
fs.writeFile(output..'/validation.json',serde.encode('json',report,true))
print('BACKUP',backup)
print('OUTPUT',output)
