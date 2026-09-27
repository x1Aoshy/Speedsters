local fs=require('@lune/fs')
local luau=require('@lune/luau')
local process=require('@lune/process')
local root=process.args[1] or 'audit/patched/V2'
local s=fs.readFile(root..'/ServerScriptService/Bootstrap.luau')
local start=assert(s:find('SettingsUpdate.OnServerEvent:Connect(',1,true))
local stop=assert(s:find('UpdateLogClosed.OnServerEvent:Connect(',start,true))
local handler;local preferences={};local writes={}
local player={UserId=1,GetAttribute=function() return true end,SetAttribute=function(_,key,value) writes[key]=value end}
luau.load(s:sub(start,stop-1),{environment={SettingsUpdate={OnServerEvent={Connect=function(_,fn) handler=fn end}},DataService={GetHandle=function() return {} end,SetPreference=function(_,k,v) preferences[k]=v;return {ok=true} end}}})()
for _,k in {'DataLoaded','World2Unlocked','PermanentBaseSpeedMultiplier','Level','IsBoosting'} do handler(player,k,true) end
assert(next(writes)==nil and next(preferences)==nil,'unauthorized attributes accepted')
handler(player,'HidePopups',true);assert(preferences.HidePopups==true)
handler(player,'MusicVolume',65);assert(preferences.MusicVolume==65)
handler(player,'MusicVolume',math.huge);assert(preferences.MusicVolume==65)
handler(player,'HidePopups',1);assert(preferences.HidePopups==true)
print('PASS SettingsUpdate allowlist/types/finite numbers')
s=fs.readFile(root..'/ServerScriptService/Progression/PlayerStatsBridge.luau')
start=assert(s:find('g.SpeedsterSavePlayer = function',1,true))
stop=assert(s:find('-- 8b.',start,true))
local g={};local saveResult={kind='Pending'}
luau.load(s:sub(start,stop-1),{environment={g=g,DataService={GetHandle=function() return {} end,Flush=function() return saveResult end}}})()
assert(g.SpeedsterSavePlayer(player,'purchase',true)==false,'Pending was reported as durable')
saveResult={kind='Failed'};assert(g.SpeedsterSavePlayer(player,'purchase',true)==false)
saveResult={kind='Skipped',reason='Released'};assert(g.SpeedsterSavePlayer(player,'purchase',true)==false)
saveResult={kind='Saved'};assert(g.SpeedsterSavePlayer(player,'purchase',true)==true)
print('PASS confirmed save required; Pending/Failed/Released are not success')
start=assert(s:find('g.SpeedsterAddWins = function',1,true))
stop=assert(s:find('-- 9b.',start,true))
local amount;local commitKind='Committed';local hasHandle=true
g.SpeedsterGetPermanentWinsMultiplier=function() return 4 end
luau.load(s:sub(start,stop-1),{environment={g=g,DataService={GetHandle=function() return hasHandle and {} or nil end,Commit=function(_,request) amount=request.commands[1].amount;return {kind=commitKind} end}}})()
assert(g.SpeedsterAddWins(player,10)==true and amount==40,'OG x4 wins reward not preserved')
commitKind='Rejected';assert(g.SpeedsterAddWins(player,10)==false)
hasHandle=false;assert(g.SpeedsterAddWins(player,10)==false)
print('PASS OG permanent wins bonus and no false success without durable reward')
