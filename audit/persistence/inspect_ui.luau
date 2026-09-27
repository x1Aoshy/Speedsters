local fs=require('@lune/fs');local r=require('@lune/roblox')
for label,file in {World1='World1 Speedtercorrect.rbxl',World2='world2 speedtster.rbxl'} do
 local g=r.deserializePlace(fs.readFile(file))
 for _,gui in g:GetService('StarterGui'):GetChildren() do
  if gui:IsA('ScreenGui') then
   local children={};for _,c in gui:GetChildren() do if c:IsA('GuiObject') then table.insert(children,c.Name..':'..tostring(c.Visible)) end end
   print(label,gui.Name,gui.Enabled,table.concat(children,','))
  end
 end
end
