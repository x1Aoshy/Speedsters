local fs=require('@lune/fs')
local serde=require('@lune/serde')
local luau=require('@lune/luau')
for _,label in {'OG','V2','World2'} do
 local inv=serde.decode('json',fs.readFile('audit/'..label..'/inventory.json'))
 local count=0
 for _,r in inv do
  if r.file then
   local src=fs.readFile('audit/'..label..'/'..r.file)
   local ok,err=pcall(luau.compile,src)
   if not ok then print('SYNTAX',label,r.path,err) end
   count+=1
   local path='audit/source/'..label..'/'..r.path:gsub('%.','/'):gsub('[<>:"|?*]','_')..'.luau'
   fs.writeDir(path:match('^(.*)/'))
   fs.writeFile(path,src)
  end
 end
 print('compiled',label,count)
end
