local fs=require('@lune/fs')
local rb=require('@lune/roblox')
local luau=require('@lune/luau')
local serde=require('@lune/serde')
local manifest=serde.decode('json',fs.readFile('src/manifest.json'))
local files={World1='World1Update3New.rbxl',World2='World2Update3new.rbxl',World3='World3Update3New.rbxl'}
local previous='output/CoreLoop_Update_20260920_025554'
local changes={
 'src/common/ServerScriptService/Services/FunnelAnalytics.luau',
 'src/common/StarterPlayer/StarterPlayerScripts/UI/StarterPackOffer.client.luau',
}
local stamp=os.date('!%Y%m%d_%H%M%S')
local output='output/CoreLoop_Final_'..stamp
fs.writeDir(output)
local prepared={}
local report={output=output,previous=previous,worlds={}}
local function find(dm,segments)
 local node=dm
 for _,segment in segments do node=assert(node:FindFirstChild(segment),segment) end
 return node
end
for world,file in files do
 local raw=fs.readFile(file)
 assert(raw==fs.readFile(previous..'/'..file),'World changed since previous build: '..world)
 local dm=rb.deserializePlace(raw)
 local rows={};for _,row in manifest.worlds[world].scripts do rows[row.source]=row end
 for _,path in changes do
  local source=fs.readFile(path)
  luau.compile(source)
  find(dm,assert(rows[path],path).segments).Source=source
 end
 local bytes=rb.serializePlace(dm)
 local check=rb.deserializePlace(bytes)
 for _,path in changes do assert(find(check,rows[path].segments).Source==fs.readFile(path),world..' '..path) end
 assert(#dm:GetDescendants()==#check:GetDescendants(),'Instance count changed: '..world)
 fs.writeFile(output..'/'..file,bytes)
 prepared[world]={raw=raw,bytes=bytes}
 report.worlds[world]={file=file,sha256=serde.hash('sha256',bytes),instances=#check:GetDescendants()}
 print('PREPARED',world)
end
for world,file in files do
 assert(fs.readFile(file)==prepared[world].raw,'Concurrent change: '..world)
 fs.writeFile(file,prepared[world].bytes)
 print('SAVED',file)
end
fs.writeFile(output..'/validation.json',serde.encode('json',report,true))
print('FINAL',output)
