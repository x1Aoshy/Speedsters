local fs=require('@lune/fs')
local r=require('@lune/roblox')
for world,file in {World1='World1 Speedtercorrect.rbxl',World2='world2 speedtster.rbxl'} do
 local g=r.deserializePlace(fs.readFile(file))
 print(world)
 for _,o in g:GetDescendants() do
  if o:IsA('SpawnLocation') or (o:IsA('BasePart') and (o.Name:lower():match('^winstage') or o.Name:lower():match('^win%d+$') or o.Name:lower():match('^safezone%d+%.2$'))) then
   print(o:GetFullName(),'pos',o.CFrame.Position,'size',o.Size,'attrs',o:GetAttributes(),o:IsA('SpawnLocation') and ('Enabled='..tostring(o.Enabled)) or '')
  elseif o:IsA('BaseScript') and (o.Name=='WinPads' or o.Name=='World2StageSystem') then print(o:GetFullName(),'Disabled',o.Disabled) end
 end
end
