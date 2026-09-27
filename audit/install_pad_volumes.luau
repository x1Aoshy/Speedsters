local fs=require('@lune/fs')
for _,world in {'World1','World2'} do
 local root='audit/merged/'..world..'/ServerScriptService/'
 fs.writeFile(root..'Services/PadTouchService.luau',fs.readFile('audit/PadTouchService.luau'))
 for _,name in {'NewWorld1ManualStagePads','World2ManualStagePads'} do
  local path=root..'Gameplay/'..name..'.luau'
  if not fs.isFile(path) then continue end
  local s=fs.readFile(path)
  local anchor='local STAGE_COUNT =';local i=assert(s:find(anchor,1,true))
  s=s:sub(1,i-1)..'local PadTouchService = require(ServerScriptService:WaitForChild("Services"):WaitForChild("PadTouchService"))\n\n'..s:sub(i)
  local n;s,n=s:gsub('pad%.Touched:Connect%(function%(hit%)','PadTouchService.Connect(pad, function(hit)');assert(n==2,name..n)
  fs.writeFile(path,s)
 end
end
