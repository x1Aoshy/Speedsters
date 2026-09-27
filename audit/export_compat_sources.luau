-- audit/merged is a generated test view. Production edits belong in src.
local fs=require('@lune/fs')
local serde=require('@lune/serde')
local manifest=serde.decode('json',fs.readFile('src/manifest.json'))
local indexPath='audit/generated_sources.json'
local previous=if fs.isFile(indexPath) then serde.decode('json',fs.readFile(indexPath)) else {}
local pending={};local hashes={}
for world,data in manifest.worlds do
 for _,row in data.scripts do
  if not row.duplicate then
   local path='audit/merged/'..world..'/'..row.legacyPath..'.luau'
   local source=fs.readFile(row.source)
   if previous[path] and fs.isFile(path) then
    local existing=fs.readFile(path)
    assert(serde.hash('sha256',existing)==previous[path] or existing==source,
     'Manual edit in generated file; merge it into '..row.source..' first: '..path)
   end
   pending[path]=source;hashes[path]=serde.hash('sha256',source)
  end
 end
end
for path,source in pending do fs.writeDir(path:match('^(.*)/'));fs.writeFile(path,source) end
fs.writeFile(indexPath,serde.encode('json',hashes,true))
print('PASS generated audit/merged from src; manual-edit conflict guard active')
