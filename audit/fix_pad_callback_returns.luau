local fs=require('@lune/fs')
for _,item in {{'World1','NewWorld1ManualStagePads'},{'World2','World2ManualStagePads'}} do
 local path='audit/merged/'..item[1]..'/ServerScriptService/Gameplay/'..item[2]..'.luau'
 local s=fs.readFile(path)
 local a=assert(s:find('local function connectRewardPad(',1,true))
 local b=assert(s:find('local function connectSkipPad(',a,true))
 local body=s:sub(a,b-1)
 body=body:gsub('then return end','then return false end')
 body=body:gsub('if claimingPlayers%[player%] then%s+return%s+end','if claimingPlayers[player] then return false end')
 body=body:gsub('(if not MovementGuard.CanClaim%b() then)%s+return%s+end','%1 return false end')
 body=body:gsub('(promptDoubleWins%(player%))%s+return','%1\n\t\t\treturn true')
 if item[1]=='World1' then
  body=body:gsub('if not claimed then%s+return%s+end','return claimed')
  body=body:gsub('local ok, err = pcall%(handleRewardTouch%)','local ok, err = pcall(handleRewardTouch)')
  body=body:gsub('(warn%(%"%[NewWorld1ManualStagePads%] Error processing reward claim.-\n\t\tend)\n\tend%)','%1\n\t\treturn ok and err == true\n\tend)')
 else
  body=body:gsub('if not claimed then%s+return%s+end','return claimed')
 end
 s=s:sub(1,a-1)..body..s:sub(b)
 -- Only temporary preconditions retry; completed purchase prompts keep their entry latch.
 a=assert(s:find('local function connectSkipPad(',1,true))
 b=assert(s:find('\nlocal function ',a+10,true))
 body=s:sub(a,b-1)
 body=body:gsub('(local player, _, humanoid = playerFromHit%(hit%).*)',function(t)
  t=t:gsub('then return end','then return false end')
  return t
 end)
 s=s:sub(1,a-1)..body..s:sub(b)
 fs.writeFile(path,s)
end
