local fs=require('@lune/fs');local r=require('@lune/roblox');local luau=require('@lune/luau');local migration=require('./network_map_migration');local serde=require('@lune/serde')
for _,world in {'World1','World2'}do
 local original=r.deserializePlace(fs.readFile('audit/incoming_gemini_network/'..world..'/input.rbxl'))
 local normalized=r.serializePlace(r.deserializePlace(r.serializePlace(original)))
 local result=migration.Apply(original)
 local migrated=r.deserializePlace(r.serializePlace(original))
 local count=0
 for _,i in migrated:GetDescendants()do
  if i:IsA('Script') and i:FindFirstChild('AsmrEffectKind') then assert(i.Disabled);count+=1;for _,t in i:GetChildren()do if t:IsA('BasePart')then assert(t.Anchored and not t.CanCollide and not t.CanTouch and not t.CanQuery and t.Transparency==1)end end end
  if i:IsA('LuaSourceContainer')then luau.compile(i.Source)end
 end
 assert(count==(world=='World2' and 25 or 0))
 result.Undo(migrated)
 assert(r.serializePlace(migrated)==normalized, 'Non-target graph changed or failed undo '..world)
 fs.writeFile('audit/asmr_migration_'..world..'.json',serde.encode('json',{changes=result.changes,inserted=result.inserted,counts=result.counts},true))
 print('PASS '..world..': per-instance ASMR migration, compile, complete roundtrip reversal; count '..count)
end

