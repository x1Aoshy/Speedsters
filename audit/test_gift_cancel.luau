local fs=require('@lune/fs');local luau=require('@lune/luau')
local world=require('@lune/process').args[1] or 'World1'
local Data=require('./merged/'..world..'/ServerScriptService/Services/Data/DataService')
local Adapter=require('./merged/'..world..'/ServerScriptService/Services/Data/DataStoreAdapter')
local store=Adapter.CreateMock();Data.Init({storeAdapter=store});Data.Start();assert(Data.Open(1).ok)
local function signal() local s={};function s:Connect(fn) self.fn=fn end;return s end
local request=signal();local finished=signal();local replies={};local prompts=0;local queued={}
local buyer={UserId=1,Parent=true};local target={UserId=2,GetAttribute=function() return true end}
local Players={GetPlayerByUserId=function(_,id) return id==1 and buyer or id==2 and target or nil end}
local remote={OnServerEvent=request,FireClient=function(_,_,id,ok) replies[id]=ok end}
local s=fs.readFile('audit/merged/'..world..'/ServerScriptService/Economy/SpeedProductPurchases.luau')
local first=s:find('local giftRequestBusy={}',1,true);local last=s:find('grantPassPerkToTarget = function',first,true)
local env={DataService=Data,Players=Players,pendingGiftContexts={},productsById={[12]={}},persistentReceiptCommands=function() return {} end,
 GiftContextRequest=remote,MarketplaceService={PromptProductPurchaseFinished=finished,PromptProductPurchase=function(_,p,id) assert(p==buyer and id==12);prompts+=1 end},task={delay=function(_,fn) table.insert(queued,fn) end}}
luau.load(s:sub(first,last-1),{environment=env})()
request.fn(buyer,2,12,'one');assert(prompts==1 and replies.one)
request.fn(buyer,2,12,'extra');assert(prompts==1)
local function destination() return Data.Inspect(Data.GetHandle(1)).value.profile.Update2GiftContexts['12'] end
finished.fn(1,99,false);assert(destination()==2)
finished.fn(1,12,true);assert(destination()==2,'Purchase signal cleared gift before receipt')
store:SetFailureMode('Player_1','Timeout');finished.fn(1,12,false);assert(#queued==1)
finished.fn(1,12,false);assert(#queued==1,'Duplicate cancellation queued')
store:SetFailureMode('Player_1','None');table.remove(queued,1)();assert(destination()==nil)
request.fn(buyer,2,12,'two');assert(prompts==2 and replies.two and destination()==2)
print('PASS '..world..' actual gift handlers: one server prompt, unrelated/true closure ignored, cancellation timeout retries once and permits next gift')
