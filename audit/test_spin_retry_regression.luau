local fs=require('@lune/fs');local luau=require('@lune/luau')
local function chunk(s,a,b) local p=assert(s:find(a,1,true));return s:sub(p,assert(s:find(b,p, true))-1) end
local service=fs.readFile('src/common/ServerScriptService/Economy/SpinWheelService.server.luau')
local rolls,commits,awards=0,0,0;local original;local replies={};local profile={SpinTickets=2,SpinWheelFreePeriod=10}
local p={UserId=42};local records={}
local spin=luau.load(chunk(service,'local function spin(player:','local function formatClock')..'\nreturn spin',{environment=setmetatable({
 spinRequests=records,inspect=function()return profile,{} end,currentPeriod=function()return 10 end,
 send=function(_,payload)table.insert(replies,payload)end,
 SpinWheelCatalog={Pick=function()rolls+=1;return 1 end,Segments={{Id='Wins',Kind='Wins'}}},
 random={NextNumber=function()return 0.5 end},rewardFor=function()return {{kind='GrantExact',amount=5}},'+5 Wins' end,
 DataService={NewOperationId=function()return 'server-operation-'..rolls end},
 commit=function(_,tx) commits+=1;if commits==1 then original=tx;return false,'Pending' end;assert(tx==original);awards+=1;profile.SpinTickets-=1;return true end,
 FunnelAnalytics={Step=function()end},
},{__index=_G})})()
spin(p,'client-request-1');assert(replies[#replies].Retry and awards==0)
spin(p,'other-request');assert(rolls==1 and commits==1,'Must not roll while unresolved')
spin(p,'client-request-1');assert(awards==1 and rolls==1 and profile.SpinTickets==1)
spin(p,'client-request-1');assert(awards==1 and commits==2 and replies[#replies].Result)
print('PASS actual spin: pending save, same transaction/roll on retry, one ticket, duplicate result replay')
-- Execute the real client request and receive handler with a delayed result.
local source=fs.readFile('src/common/StarterPlayer/StarterPlayerScripts/UI/SpinWheelController.client.luau')
local scheduled={};local now=0;local sent={};local handler;local landed=0
local env=setmetatable({phase='idle',labelsShowOdds=false,isOpen=true,
 os={clock=function()return now end},spinsAvailable=function()return 2 end,showMessage=function()end,
 PurchaseButtonSound={Play=function()end},HttpService={GenerateGUID=function()return 'client-request-1' end},
 setButtonEnabled=function()end,spinButton={},renderState=function()end,
 Request={FireServer=function(_,payload)table.insert(sent,payload)end},
 task={delay=function(_,fn)table.insert(scheduled,fn)end},
 Update={OnClientEvent={Connect=function(_,fn)handler=fn end}},
 beginLanding=function()landed+=1 end,
},{__index=_G})
local request=luau.load(chunk(source,'local spinRequestedAt = 0','spinButton.Activated:Connect')..'\n'..chunk(source,'Update.OnClientEvent:Connect(function(payload)','----------------------------------------------------------------------\n-- Open / close')..'\nreturn requestSpin',{environment=env})()
request();now=16;table.remove(scheduled,1)();assert(#sent==2 and sent[1].requestId==sent[2].requestId)
handler({Message='Unrelated purchase complete'})
handler({RequestId='client-request-1',Loading=true,Result={Index=1,Title='+5 Wins'}})
assert(landed==1);handler({RequestId='client-request-1',Result={Index=1}});assert(landed==1)
table.remove(scheduled,1)();assert(#sent==2)
print('PASS actual client: result after 16s still lands, unrelated message cannot cancel it, duplicate ignored, retries stop')
