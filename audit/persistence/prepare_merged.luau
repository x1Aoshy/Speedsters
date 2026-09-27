local fs=require('@lune/fs')
local serde=require('@lune/serde')
local roblox=require('@lune/roblox')
for label,file in {World1='World1 Speedtercorrect.rbxl',World2='world2 speedtster.rbxl'} do
 local g=roblox.deserializePlace(fs.readFile(file))
 for _,i in g:GetDescendants() do
  if i:IsA('LuaSourceContainer') then
   local path='audit/merged/'..label..'/'..i:GetFullName():gsub('%.','/'):gsub('[<>:"|?*]','_')..'.luau'
   fs.writeDir(path:match('^(.*)/'))
   fs.writeFile(path,i.Source)
  elseif (i:GetFullName():find('RankRewardGui',1,true) or i:GetFullName():find('RebirthBuy',1,true)) and i:IsA('GuiObject') then
   print(label,i:GetFullName(),i.ClassName,if i:IsA('TextLabel') or i:IsA('TextButton') then i.Text else '',i.Visible,i.Position,i.Size)
  end
 end
end
