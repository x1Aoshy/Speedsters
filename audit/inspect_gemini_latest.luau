local fs=require('@lune/fs');local r=require('@lune/roblox');local serde=require('@lune/serde')
local files={World1='World1 Speedtercorrect.rbxl',World2='World2Old has to be synced with world1updated the p[ad bug still.rbxl'}
for world,file in files do
 local raw=fs.readFile(file);local game=r.deserializePlace(raw);local dir='audit/incoming_gemini_network/'..world
 fs.writeDir(dir);if not fs.isFile(dir..'/input.rbxl') then fs.writeFile(dir..'/input.rbxl',raw) else assert(fs.readFile(dir..'/input.rbxl')==raw,'Input changed; take another snapshot') end
 local scripts={};local unanchored={};local differences={};local count=0
 for index,i in game:GetDescendants() do
  if i:IsA('LuaSourceContainer') then
   count+=1;local path=i:GetFullName():gsub('%.','/'):gsub('[<>:"|?*]','_')..'.luau'
   fs.writeFile(dir..'/'..index..'.luau',i.Source)
   table.insert(scripts,{id=index,path=i:GetFullName(),class=i.ClassName,file=index..'.luau'})
   local merged='audit/merged/'..world..'/'..path
   if not fs.isFile(merged) or fs.readFile(merged):gsub('\r\n','\n')~=i.Source:gsub('\r\n','\n') then
    table.insert(differences,{path=i:GetFullName(),file=index..'.luau'})
   end
  elseif i:IsA('BasePart') and i:IsDescendantOf(game:GetService('Workspace')) and not i.Anchored then table.insert(unanchored,{id=index,path=i:GetFullName(),size=tostring(i.Size)}) end
 end
 fs.writeFile(dir..'/scripts.json',serde.encode('json',scripts,true))
 fs.writeFile(dir..'/unanchored.json',serde.encode('json',unanchored,true))
 print(world,'scripts',count,'unanchored',#unanchored,'different',serde.encode('json',differences,true))
end
