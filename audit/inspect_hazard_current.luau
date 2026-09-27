local fs=require('@lune/fs')
local rb=require('@lune/roblox')
local serde=require('@lune/serde')
local inputs={'World1 Speedtercorrect.rbxl','World2Old has to be synced with world1updated the p[ad bug still.rbxl'}
local rows={}
for world,file in ipairs(inputs) do
 local root=rb.deserializePlace(fs.readFile(file))
 local out={world=world,hazards={},sources={}}
 for _,d in ipairs(root:GetDescendants()) do
  if d:IsA('BasePart') then
   local path=d:GetFullName()
   if path:match('Tree[1-6]') or path:match('Hammer[1-5]') or path:match('Presser[1-5]') then
    local row={path=path,class=d.ClassName,size=tostring(d.Size),cframe=tostring(d.CFrame),anchored=d.Anchored,transparency=d.Transparency,collide=d.CanCollide,touch=d.CanTouch,query=d.CanQuery}
    if d:IsA('MeshPart') then local ok,mesh=pcall(function() return d.MeshId end); row.mesh=ok and tostring(mesh) or nil; local okf,f=pcall(function() return d.CollisionFidelity end); row.fidelity=okf and tostring(f) or "unavailable Lune" end
    table.insert(out.hazards,row)
   end
  elseif d:IsA('LuaSourceContainer') and (d.Name:find('TreeSlammers') or d.Name:find('ClientMotionHazards') or d.Name:find('ClientHazardAuthority') or d.Name=='NewWorld1ServerMotion' or d.Name=='Presser1Controller') then
   local path='audit/hazard_current/World'..world..'/'..d:GetFullName():gsub('%.','/')..'.luau'
   fs.writeDir(path:match('^(.*)/'))
   fs.writeFile(path,d.Source)
   table.insert(out.sources,path)
  end
 end
 table.insert(rows,out)
end
fs.writeFile('audit/hazard_current_inventory.json',serde.encode('json',rows,true))
print(serde.encode('json',rows,true))


