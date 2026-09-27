local fs=require('@lune/fs');local serde=require('@lune/serde')
local inventory=serde.decode('json',fs.readFile('audit/core_inventory.json'))
for _,world in {'World1','World2'} do
 local rows=serde.decode('json',fs.readFile('audit/incoming_core_plan/'..world..'/scripts.json'))
 local changed={};for _,path in inventory.totals[world].differentFromMerged do changed[path]=true end
 local dir='audit/reconciliation/'..world;fs.writeDir(dir)
 for _,row in rows do if changed[row.path] then
  local path=row.path:gsub('%.','/'):gsub('[<>:"|?*]','_')..'.luau'
  local merged='audit/merged/'..world..'/'..path
  local safe=row.path:gsub('[<>:"|?*]','_')
  if fs.isFile(merged) and not fs.isFile(dir..'/'..safe..'.before.luau') then fs.writeFile(dir..'/'..safe..'.before.luau',fs.readFile(merged)) end
  fs.writeFile(dir..'/'..safe..'.incoming.luau',fs.readFile('audit/incoming_core_plan/'..world..'/'..row.id..'.luau'))
 end end
end
