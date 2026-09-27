-- ONE TIME ONLY. Reconciliation must finish before running this importer.
local fs = require('@lune/fs')
local rb = require('@lune/roblox')
local serde = require('@lune/serde')
assert(not fs.isFile('src/manifest.json'), 'src is authoritative already; do not reimport audit/merged')
local inputs = {
 World1 = 'World1 Speedtercorrect.rbxl',
 World2 = 'World2Old has to be synced with world1updated the p[ad bug still.rbxl',
}
local additions = {
 ['ServerScriptService/Services/DynamicCodeDefinitions']='ModuleScript',
 ['ServerScriptService/Core/Abilities/FlightService']='ModuleScript',
 ['ServerScriptService/Services/PadTouchService']='ModuleScript',
 ['ServerScriptService/Services/RewardPadClaims']='ModuleScript',
 ['ServerScriptService/Services/RemoteGuard']='ModuleScript',
 ['ServerScriptService/Admin/AdminRequestValidation']='ModuleScript',
 ['ServerScriptService/Admin/AdminPanelService']='Script',
 ['StarterPlayer/StarterPlayerScripts/UI/AdminPanelController']='LocalScript',
}
local function segments(instance)
 local result = {}
 while instance.Parent do table.insert(result, 1, instance.Name); instance=instance.Parent end
 return result
end
local function diskPath(path) return (path:gsub('[<>:"|?*]', '_')) end
local worlds = {}
local staleSources = {}
for _, world in {'World1','World2'} do
 local input='audit/incoming_core_plan/'..world..'/input.rbxl'
 local raw=fs.readFile(input)
 assert(raw==fs.readFile(inputs[world]), 'Latest input changed: reconcile new file before extracting '..world)
 local place=rb.deserializePlace(raw)
 local counts={};local paths={};local rows={}
 for _, i in place:GetDescendants() do
  if i:IsA('LuaSourceContainer') then
   local p=i:GetFullName();counts[p]=(counts[p] or 0)+1
  end
 end
 for id,i in place:GetDescendants() do
  if i:IsA('LuaSourceContainer') then
   local legacy=diskPath(i:GetFullName():gsub('%.','/'))
   local merged='audit/merged/'..world..'/'..legacy..'.luau'
   local source=i.Source
   -- Duplicate names are independent instances: retain their own source exactly.
   if counts[i:GetFullName()]==1 and fs.isFile(merged) then source=fs.readFile(merged) end
   local names=segments(i)
   table.insert(rows,{id=id,path=i:GetFullName(),segments=names,class=i.ClassName,
    sourceText=source, legacyPath=legacy, duplicate=counts[i:GetFullName()]>1})
   paths[legacy]=true
  end
 end
 local function walk(relative)
  for _,n in fs.readDir('audit/merged/'..world..'/'..relative) do
   local p=relative..n;local full='audit/merged/'..world..'/'..p
   if fs.isDir(full) then walk(p..'/')
   elseif p:sub(-5)=='.luau' and not paths[p:sub(1,-6)] then
    local key=p:sub(1,-6)
    if not additions[key] then
     -- Latest place is authoritative for removals; never resurrect stale exports.
     table.insert(staleSources,{world=world,legacyPath=key})
     continue
    end
    local names=string.split(key,'/')
    table.insert(rows,{path=table.concat(names,'.'),segments=names,class=additions[key],
     sourceText=fs.readFile(full),legacyPath=key,added=true})
   end
  end
 end
 walk('')
 worlds[world]={input=input,latestInput=inputs[world],inputSha256=serde.hash('sha256',raw),scripts=rows}
end
local other={}
for _,row in worlds.World2.scripts do if not row.duplicate then other[row.path]=row end end
local shared={}
for _,row in worlds.World1.scripts do
 local match=other[row.path]
 if not row.duplicate and match and row.class==match.class
  and row.sourceText:gsub('\r\n','\n')==match.sourceText:gsub('\r\n','\n') then shared[row.path]=true end
end
local written={};local commonCount=0
for world,data in worlds do
 for _,row in data.scripts do
  local scope=if shared[row.path] then 'common' else 'worlds/'..world
  local parts={};for _,n in row.segments do table.insert(parts,diskPath(n)) end
  local suffix=if row.class=='Script' then '.server.luau' elseif row.class=='LocalScript' then '.client.luau' else '.luau'
  local file='src/'..scope..'/'..table.concat(parts,'/')..(if row.duplicate then '__instance_'..row.id else '')..suffix
  local source=row.sourceText:gsub('\r\n','\n')
  if written[file] then assert(fs.readFile(file)==source,'Source path collision: '..file)
  else
   assert(not written[file:lower()], 'Case-insensitive source collision: '..file)
   fs.writeDir(file:match('^(.*)/'));fs.writeFile(file,source)
   written[file]=true;written[file:lower()]=true
   if shared[row.path] then commonCount+=1 end
  end
  row.source=file;row.sourceText=nil
 end
end
fs.writeFile('src/manifest.json',serde.encode('json',{
 formatVersion=1,coreVersion='update2-core-0.1.0',commonSources=commonCount,worlds=worlds,staleExportsNotImported=staleSources,
},true))
print('Canonical source created: '..commonCount..' shared sources; instance classes and duplicate identities preserved')
