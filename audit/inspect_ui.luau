local fs=require('@lune/fs')
local r=require('@lune/roblox')
for _,file in {'V2Speedsters.rbxl','World2.rbxl'} do
 local g=r.deserializePlace(fs.readFile(file))
 print(file)
 for _,i in g:GetDescendants() do
  if i:IsA('ScreenGui') and i:IsDescendantOf(g:GetService('StarterGui')) then
   print(i:GetFullName(),'enabled',i.Enabled,'order',i.DisplayOrder)
  end
  if i.Name=='LevelProgressBar' or i.Name=='SpeedPopupLayer' then
   print('TARGET',i:GetFullName(),i.ClassName)
   if i:IsA('GuiObject') then print(i.Position,i.Size,i.Visible) end
  end
 end
end
