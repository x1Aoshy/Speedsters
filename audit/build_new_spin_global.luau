local fs=require('@lune/fs');local rb=require('@lune/roblox');local luau=require('@lune/luau');local serde=require('@lune/serde')
local files={World1='World1Update3New.rbxl',World2='World2Update3new.rbxl',World3='World3Update3New.rbxl'}
local paths={
 {source='src/common/StarterPlayer/StarterPlayerScripts/UI/SpinWheelController.client.luau',segments={'StarterPlayer','StarterPlayerScripts','UI','SpinWheelController'}},
 {source='src/common/ServerScriptService/Economy/SpinWheelService.server.luau',segments={'ServerScriptService','Economy','SpinWheelService'}},
 {source='src/common/ServerScriptService/Admin/AdminAbusePanelService.server.luau',segments={'ServerScriptService','Admin','AdminAbusePanelService'}},
}
local function find(dm,path)local i=dm;for _,name in path do i=assert(i:FindFirstChild(name),name)end;return i end
local function graph(dm)return (rb.serializePlace(dm,true):gsub('<UniqueId name="UniqueId">.-</UniqueId>','<UniqueId/>'))end
local output='output/New_Spin_AdminGlobal_Fix';fs.writeDir(output)
local artifacts={};local report={worlds={},sources=paths}
for world,file in files do
 local raw=fs.readFile('audit/new_spin_global/'..world..'.rbxl')
 assert(fs.readFile(file)==raw,'New file changed during work: '..file)
 local dm=rb.deserializePlace(raw);local originals={}
 for _,entry in paths do
  local inst=find(dm,entry.segments);originals[entry.source]=inst.Source
  inst.Source=fs.readFile(entry.source);luau.compile(inst.Source)
 end
 local encoded=rb.serializePlace(dm);local decoded=rb.deserializePlace(encoded);local count=0
 for _,i in decoded:GetDescendants()do if i:IsA('LuaSourceContainer')then luau.compile(i.Source);count+=1 end end
 for _,entry in paths do
  local inst=find(decoded,entry.segments);assert(inst.Source==fs.readFile(entry.source));inst.Source=originals[entry.source]
 end
 assert(graph(decoded)==graph(rb.deserializePlace(raw)),'Unexpected property/map/source change: '..world)
 artifacts[file]=encoded;report.worlds[world]={file=file,compiledScripts=count,inputSha256=serde.hash('sha256',raw),outputSha256=serde.hash('sha256',encoded),allOtherPropertiesPreserved=true}
 print('PASS',file,count,'scripts compiled; exact original map/UI/properties preserved; 3 source replacements verified')
end
-- Validate all three before writing any incoming file.
for world,file in files do assert(fs.readFile(file)==fs.readFile('audit/new_spin_global/'..world..'.rbxl'),'Studio saved during build: '..file)end
for file,encoded in artifacts do fs.writeFile(output..'/'..file,encoded);fs.writeFile(file,encoded)end
fs.writeFile(output..'/validation.json',serde.encode('json',report,true))
