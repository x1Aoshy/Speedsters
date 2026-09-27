local fs=require('@lune/fs');local r=require('@lune/roblox');local serde=require('@lune/serde')
local byWorld={};local totals={}
for world,file in {World1='World1 Speedtercorrect.rbxl',World2='World2Old has to be synced with world1updated the p[ad bug still.rbxl'} do
 local raw=fs.readFile(file);local dir='audit/incoming_core_plan/'..world;fs.writeDir(dir)
 if not fs.isFile(dir..'/input.rbxl') then fs.writeFile(dir..'/input.rbxl',raw) else assert(fs.readFile(dir..'/input.rbxl')==raw,'Input changed') end
 local game=r.deserializePlace(raw);local sources={};local count,parts,unanchored,enabledWorkspaceScripts=0,0,0,0
 local differences={};local nodes={}
 for id,i in game:GetDescendants() do
  if i:IsA('LuaSourceContainer') then
   count+=1;local key=i:GetFullName();sources[key]=sources[key] or {};table.insert(sources[key],i.Source)
   fs.writeFile(dir..'/'..id..'.luau',i.Source);table.insert(nodes,{path=key,id=id,class=i.ClassName})
   local merged='audit/merged/'..world..'/'..key:gsub('%.','/'):gsub('[<>:"|?*]','_')..'.luau'
   if not fs.isFile(merged) or fs.readFile(merged)~=i.Source then table.insert(differences,key) end
   if i:IsA('Script') and i:IsDescendantOf(game:GetService('Workspace')) and not i.Disabled then enabledWorkspaceScripts+=1 end
  elseif i:IsA('BasePart') and i:IsDescendantOf(game:GetService('Workspace')) then parts+=1;if not i.Anchored then unanchored+=1 end end
 end
 byWorld[world]=sources;totals[world]={scripts=count,workspaceParts=parts,unanchored=unanchored,enabledWorkspaceScripts=enabledWorkspaceScripts,differentFromMerged=differences}
 fs.writeFile(dir..'/scripts.json',serde.encode('json',nodes,true))
end
local identical,different,only1,only2={},{},{},{}
for path,arr in byWorld.World1 do
 local other=byWorld.World2[path]
 if not other then table.insert(only1,path)
 elseif #arr==1 and #other==1 then
  if arr[1]:gsub('\r\n','\n')==other[1]:gsub('\r\n','\n') then table.insert(identical,path) else table.insert(different,path) end
 end
end
for path in byWorld.World2 do if not byWorld.World1[path] then table.insert(only2,path) end end
table.sort(identical);table.sort(different);table.sort(only1);table.sort(only2)
local report={totals=totals,identicalCommonUniqueScripts=identical,differingCommonUniqueScripts=different,world1OnlyPaths=only1,world2OnlyPaths=only2}
fs.writeFile('audit/core_inventory.json',serde.encode('json',report,true))
print(serde.encode('json',{totals=totals,identical=#identical,different=different,world1Only=only1,world2Only=only2},true))
