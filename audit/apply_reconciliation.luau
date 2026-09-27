-- One-time import of the reviewed 12:11 Gemini snapshot. Never run after extraction.
local fs = require('@lune/fs')
local serde = require('@lune/serde')
assert(not fs.isFile('src/manifest.json'), 'Canonical sources exist; reconcile explicitly there')
local inventory = serde.decode('json', fs.readFile('audit/core_inventory.json'))
local applied = {}
for _, world in {'World1', 'World2'} do
 for _, path in inventory.totals[world].differentFromMerged do
  local incoming = 'audit/reconciliation/' .. world .. '/' .. path:gsub('[<>:"|?*]', '_') .. '.incoming.luau'
  local target = 'audit/merged/' .. world .. '/' .. path:gsub('%.', '/'):gsub('[<>:"|?*]', '_') .. '.luau'
  fs.writeDir(target:match('^(.*)/'))
  fs.writeFile(target, fs.readFile(incoming))
  table.insert(applied, {world=world, path=path})
 end
end
fs.writeFile('audit/reconciliation/applied.json', serde.encode('json', applied, true))
print('Imported reviewed Gemini sources: ' .. #applied)
