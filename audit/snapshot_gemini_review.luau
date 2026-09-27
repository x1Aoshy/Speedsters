local fs=require('@lune/fs');local rb=require('@lune/roblox');local serde=require('@lune/serde')
local dir='audit/incoming_gemini_review_1731';fs.writeDir(dir)
local manifest=serde.decode('json',fs.readFile('src/manifest.json'))
if not fs.isFile(dir..'/manifest.before.json') then fs.writeFile(dir..'/manifest.before.json',fs.readFile('src/manifest.json')) end
local inputs={World1='World1 Speedtercorrect.rbxl',World2='World2Old has to be synced with world1updated the p[ad bug still.rbxl'}
local diffs={};local unknown={}
for world,input in inputs do
 local raw=fs.readFile(input);fs.writeDir(dir..'/'..world)
 local snap=dir..'/'..world..'/input.rbxl'
 if fs.isFile(snap) then assert(raw==fs.readFile(snap),'Input changed during review') else fs.writeFile(snap,raw) end
 local place=rb.deserializePlace(raw);local byPath={}
 for id,i in place:GetDescendants() do if i:IsA('LuaSourceContainer') then
  local path=i:GetFullName();byPath[path]=byPath[path] or {};table.insert(byPath[path],{id=id,i=i})
 end end
 local used={}
 for _,row in manifest.worlds[world].scripts do
  local list=byPath[row.path];used[row.path]=(used[row.path] or 0)+1
  local found=list and list[used[row.path]]
  if not found then assert(row.added,'Latest place removed source: '..row.path)
  else
   assert(row.class==found.i.ClassName,'Class changed: '..row.path)
   if fs.readFile(row.source):gsub('\r\n','\n')~=found.i.Source:gsub('\r\n','\n') then
    table.insert(diffs,{world=world,path=row.path,canonical=row.source})
   end
   row.id=found.id;row.added=nil
  end
 end
 for path,list in byPath do if (used[path] or 0)~=#list then table.insert(unknown,{world=world,path=path}) end end
 local data=manifest.worlds[world]
 data.input=snap;data.latestInput=input;data.inputSha256=serde.hash('sha256',raw)
end
assert(#unknown==0,'Unreviewed scripts: '..serde.encode('json',unknown))
fs.writeFile(dir..'/rebase_differences.json',serde.encode('json',diffs,true))
fs.writeFile(dir..'/manifest.proposed.json',serde.encode('json',manifest,true))
print(serde.encode('json',diffs,true))
