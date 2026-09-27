local fs = require('@lune/fs')
local roblox = require('@lune/roblox')
local serde = require('@lune/serde')
local inputs = {OG='+1 Speedster Escape OGGG.rbxl', V2='V2Speedsters.rbxl', World2='World2.rbxl', V2Backup='V2Speedsters.rbxl.original_backup', World2Backup='World2.rbxl.original_backup'}
for label, file in inputs do
 local game = roblox.deserializePlace(fs.readFile(file))
 local rows = {}
 fs.writeDir('audit/'..label)
 for i, inst in game:GetDescendants() do
  local row = {id=i, path=inst:GetFullName(), class=inst.ClassName}
  if inst:IsA('LuaSourceContainer') then
   row.file = tostring(i)..'_'..inst.Name:gsub('[^%w_-]', '_')..'.luau'
   fs.writeFile('audit/'..label..'/'..row.file, inst.Source)
   if inst:IsA('BaseScript') then row.disabled=inst.Disabled end
  end
  table.insert(rows,row)
 end
 fs.writeFile('audit/'..label..'/inventory.json',serde.encode('json',rows,true))
 print(label,#rows)
end
