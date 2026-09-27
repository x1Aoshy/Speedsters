local fs=require('@lune/fs');local rb=require('@lune/roblox');local serde=require('@lune/serde')
fs.writeDir('audit/world2_review_2026_09_14')
local manifest=serde.decode('json',fs.readFile('src/manifest.json'))
local report={places={}}
for _,entry in {{'World1','World1Update3.rbxl'},{'World2','World2Update3.rbxl'},{'World2Old','World2Old has to be synced with world1updated the p[ad bug still.rbxl'},{'World2Base',manifest.worlds.World2.input}} do
 local name,path=entry[1],entry[2]
 local raw=fs.readFile(path);local place=rb.deserializePlace(raw);local ws=place:FindFirstChild('Workspace')
 local info={file=path,sha256=serde.hash('sha256',raw),bytes=#raw,classes={},scripts={},workspaceParts=0,workspaceScripts=0,markers={},trees={},worldAttributes={}}
 local function property(object,key) local ok,v=pcall(function()return object[key]end);if ok then return v end;return nil end
 for _,obj in place:GetDescendants() do
  info.classes[obj.ClassName]=(info.classes[obj.ClassName] or 0)+1
  if obj:IsA('BasePart') and obj:IsDescendantOf(ws) then info.workspaceParts+=1 end
  if obj:IsDescendantOf(ws) and (obj:IsA('Model') or obj:IsA('BasePart')) and obj.Name:lower():gsub('[^%w]',''):match('^tree[1-6]$') then
   local count=obj:IsA('BasePart') and 1 or 0
   for _,child in obj:GetDescendants() do if child:IsA('BasePart') then count+=1 end end
   table.insert(info.trees,{path=obj:GetFullName(),parts=count})
  end
  if obj:IsA('LuaSourceContainer') then
   local full=obj:GetFullName()
   local row={path=full,class=obj.ClassName,disabled=property(obj,'Disabled'),sha256=serde.hash('sha256',obj.Source),lines=#string.split(obj.Source,'\n')}
   table.insert(info.scripts,row)
   if name=='World2' and obj:IsDescendantOf(ws) then
    fs.writeDir('audit/world2_review_2026_09_14/workspace_scripts')
    fs.writeFile('audit/world2_review_2026_09_14/workspace_scripts/'..tostring(#info.scripts)..'_'..full:gsub('[^%w_]','_')..'.luau',obj.Source)
   end
   if obj:IsDescendantOf(ws) and obj:IsA('Script') and not row.disabled then info.workspaceScripts+=1 end
   if obj.Name=='Config' or obj.Name=='World2FlightAbility' or obj.Name=='CharacterStatsAdapter' then
    fs.writeFile('audit/world2_review_2026_09_14/'..name..'_'..full:gsub('[^%w_]','_')..'.luau',obj.Source)
   end
  end
  if obj:IsA('BasePart') and (obj.Name:match('^X2%d+$') or obj.Name:match('^Win%d+$') or obj.Name:match('^SafeZone') or obj.Name:match('^safezone') or obj.Name:find('WinStage',1,true)) then
   local pos=obj.CFrame.Position;local size=obj.Size
   table.insert(info.markers,{path=obj:GetFullName(),name=obj.Name,position={pos.X,pos.Y,pos.Z},size={size.X,size.Y,size.Z}})
  end
 end
 info.streamingEnabled=property(ws,'StreamingEnabled')
 info.streamingMinRadius=property(ws,'StreamingMinRadius');info.streamingTargetRadius=property(ws,'StreamingTargetRadius')
 info.worldAttributes={workspace=ws:GetAttribute('PlaceWorldNumber'),replicated=place:FindFirstChild('ReplicatedStorage'):GetAttribute('PlaceWorldNumber')}
 if manifest.worlds[name] then
  local byPath={};for _,row in manifest.worlds[name].scripts do byPath[table.concat(row.segments,'.')]=row end
  info.sourceMismatches={}
  info.manifestScripts=#manifest.worlds[name].scripts
  info.matchedScripts=0
  info.unmatchedScripts={}
  for _,obj in place:GetDescendants() do if obj:IsA('LuaSourceContainer') then
   local row=byPath[obj:GetFullName()]
   if row then info.matchedScripts+=1 else table.insert(info.unmatchedScripts,obj:GetFullName()) end
   if row and obj.Source:gsub('\r\n','\n')~=fs.readFile(row.source):gsub('\r\n','\n') then table.insert(info.sourceMismatches,obj:GetFullName()) end
  end end
 end
 report.places[name]=info
 print(name,info.workspaceParts,'parts',#info.scripts,'scripts',info.workspaceScripts,'enabled Workspace scripts','streaming',info.streamingEnabled,'source mismatches',info.sourceMismatches and #info.sourceMismatches)
end
fs.writeFile('audit/world2_review_2026_09_14/place_inventory.json',serde.encode('json',report,true))

