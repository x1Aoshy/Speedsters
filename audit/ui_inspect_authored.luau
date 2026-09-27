local fs=require('@lune/fs');local r=require('@lune/roblox')
for world,file in {World1='World1 Speedtercorrect.rbxl',World2='world2 speedtster.rbxl'} do
 local place=r.deserializePlace(fs.readFile(file))
 for _,root in place:GetDescendants() do
  if root:IsA('ScreenGui') and root.Name=='RankRewardGui' then
   print(world,root:GetFullName(),'ResetOnSpawn',root.ResetOnSpawn)
   for _,n in root:GetDescendants() do
    if n:IsA('GuiObject') then print(n:GetFullName(),n.ClassName,'size',n.Size,'pos',n.Position,'anchor',n.AnchorPoint,'visible',n.Visible) end
   end
  end
 end
end
