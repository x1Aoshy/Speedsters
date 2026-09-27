local fs=require('@lune/fs')
local r=require('@lune/roblox')
local luau=require('@lune/luau')
local serde=require('@lune/serde')
fs.writeDir('output/Update2_revision')
local results={}
local editedNames={SpeedsterClient=true,MainHUDController=true,DataStoreAdapter=true,SessionActor=true,Bootstrap=true,PlayerStatsBridge=true}
for label,file in {V2='V2Speedsters.rbxl',World2='World2.rbxl'} do
 local g=r.deserializePlace(fs.readFile(file))
 local normalizedOriginal=r.serializePlace(g)
 local originalSources={}
 local changes={}
 local compiled=0
 for _,inst in g:GetDescendants() do
  if not inst:IsA('LuaSourceContainer') then continue end
  local path=inst:GetFullName()
  local filePath='audit/patched/'..label..'/'..path:gsub('%.','/'):gsub('[<>:"|?*]','_')..'.luau'
  local source=editedNames[inst.Name] and fs.readFile(filePath) or inst.Source
  luau.compile(source); compiled+=1
  if source~=inst.Source then
   assert(originalSources[path]==nil,'Duplicate edited path')
   originalSources[path]=inst.Source
   inst.Source=source
   table.insert(changes,path)
  end
 end
 local output='output/Update2_revision/'..file
 fs.writeFile(output,r.serializePlace(g))
 local reopened=r.deserializePlace(fs.readFile(output))
 assert(#reopened:GetDescendants()==#g:GetDescendants(),'Instance count changed')
 local restored=0
 for _,inst in reopened:GetDescendants() do
  if inst:IsA('LuaSourceContainer') then
   luau.compile(inst.Source)
   local old=originalSources[inst:GetFullName()]
   if old then inst.Source=old;restored+=1 end
  end
 end
 assert(restored==#changes,'Missing patched script after round trip: '..restored..' vs '..#changes..' '..table.concat(changes,', '))
 assert(r.serializePlace(reopened)==normalizedOriginal,'Non-source change detected in normalized binary round trip')
 table.sort(changes)
 results[label]={file=output,compiled=compiled,instances=#g:GetDescendants(),changes=changes,onlySourceChangesVerified=true}
 print('VERIFIED',label,'compiled',compiled,'edited scripts',#changes,'instances',#g:GetDescendants(),'binary equality after reverting only Source')
end
fs.writeFile('audit/build_results.json',serde.encode('json',results,true))
