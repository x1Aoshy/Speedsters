error('Retired builder: stale 07:27 base. Use lune run audit/export_compat_sources.luau then tests and lune run audit/build_core.luau. Authoritative sources: src/manifest.json.')
local fs=require('@lune/fs');local r=require('@lune/roblox');local luau=require('@lune/luau');local serde=require('@lune/serde')
local output='output/Update2_fixed';fs.writeDir(output)
local manifest={}
for _,world in {'World1','World2'} do
 local input='audit/incoming_gemini_network/'..world..'/input.rbxl'
 local game=r.deserializePlace(fs.readFile(input));local base='audit/merged/'..world..'/'
 local byPath={};local originalSources={};local changed={};local added={};local preserved={};local mapChanges={}
 for id,i in game:GetDescendants() do
  if world=='World2' and i:IsA('BasePart') and i:IsDescendantOf(game:GetService('Workspace')) and not i.Anchored then
   table.insert(mapChanges,{id=id,path=i:GetFullName(),property='Anchored',before=false,after=true})
   i.Anchored=true
  end
 end
 for _,i in game:GetDescendants() do
  local p=i:GetFullName():gsub('%.','/'):gsub('[<>:"|?*]','_')
  byPath[p]=byPath[p] or {};table.insert(byPath[p],i)
 end
 local missing={}
 local function walk(relative)
  for _,n in fs.readDir(base..relative) do
   local path=relative..n
   if fs.isDir(base..path) then walk(path..'/')
   elseif path:sub(-5)=='.luau' then
    local key=path:sub(1,-6);local matches=byPath[key]
    if not matches then table.insert(missing,key)
    elseif #matches>1 then table.insert(preserved,{path=key,count=#matches})
    else
     local i=matches[1];assert(i:IsA('LuaSourceContainer'),key)
     local source=fs.readFile(base..path);luau.compile(source)
     originalSources[key]=i.Source
     if source~=i.Source then i.Source=source;table.insert(changed,key) end
    end
   end
  end
 end
 walk('')
 local allowedModules={['ServerScriptService/Services/RewardPadClaims']='ModuleScript',['ServerScriptService/Services/RemoteGuard']='ModuleScript',['ServerScriptService/Services/DynamicCodeDefinitions']='ModuleScript',['ServerScriptService/Admin/AdminRequestValidation']='ModuleScript',['ServerScriptService/Admin/AdminPanelService']='Script',['StarterPlayer/StarterPlayerScripts/UI/AdminPanelController']='LocalScript'}
 allowedModules['ServerScriptService/Services/PadTouchService']='ModuleScript'
 print(world..' missing sources: '..table.concat(missing,', '))
 for _,key in missing do
  assert(allowedModules[key],'Unreviewed missing instance: '..key)
  local parent,name=key:match('^(.*)/([^/]+)$');local parents=byPath[parent];assert(parents and #parents==1,key)
  local i=r.Instance.new(allowedModules[key]);i.Name=name;i.Source=fs.readFile(base..key..'.luau');luau.compile(i.Source);i.Parent=parents[1];table.insert(added,key)
 end
 local raw=r.serializePlace(game);local decoded=r.deserializePlace(raw);local count=0
 for _,i in decoded:GetDescendants() do if i:IsA('LuaSourceContainer') then luau.compile(i.Source);count+=1 end end
 -- Restore only our edits to prove the full instance/property graph serializes
 -- identically to an untouched round trip of the input. Duplicate paths stay intact.
 for _,i in decoded:GetDescendants() do
  local key=i:GetFullName():gsub('%.','/'):gsub('[<>:"|?*]','_')
  if table.find(added,key) then i:Destroy()
  elseif originalSources[key] then i.Source=originalSources[key] end
 end
 local restored=decoded:GetDescendants()
 for _,change in mapChanges do local i=restored[change.id];assert(i:GetFullName()==change.path);i[change.property]=change.before end
 local normalizedInput=r.serializePlace(r.deserializePlace(r.serializePlace(r.deserializePlace(fs.readFile(input)))))
 assert(r.serializePlace(decoded)==normalizedInput,'Non-source graph changed in '..world)
 fs.writeFile(output..'/'..world..'.rbxl',raw)
 manifest[world]={input=input,output=output..'/'..world..'.rbxl',changedScripts=changed,insertedModules=added,duplicatePathsPreserved=preserved,compiledScripts=count,mapPropertyChanges=mapChanges,nonSourceGraphPreservedExceptListed=true}
 print('PASS '..world..': '..#changed..' changed scripts, '..#added..' inserted modules, '..count..' compiled; map and other properties preserved')
end
fs.writeFile(output..'/manifest.json',serde.encode('json',manifest,true))
