local world=require('@lune/process').args[1] or 'World1'
local Actor=require('./merged/'..world..'/ServerScriptService/Services/Data/SessionActor')
local Adapter=require('./merged/'..world..'/ServerScriptService/Services/Data/DataStoreAdapter')
local fs=require('@lune/fs');local luau=require('@lune/luau')
local store=Adapter.CreateMock();local clock={UnixNow=function() return 1000 end,MonotonicNow=function() return 1000 end}
local function open(id) local a=Actor.new({userId=1,sessionId=id,clock=clock,storeAdapter=store});local h=a:Open();assert(h.ok);return a,h.value end
local a,h=open('one');local serial=0
local function commit(command) serial+=1;return a:Commit(h,{operationId='test'..serial,fingerprint='test'..serial,commands={command}}) end
local function set(id,target) return commit({kind='SetGiftContext',productId='12',targetUserId=target,contextId=id}) end
local function clear(id,target) return commit({kind='ClearGiftContext',productId='12',targetUserId=target,contextId=id}) end
assert(set('old',2).kind=='Committed');assert(set('other',2).kind~='Committed')
assert(set('old',2).kind=='Committed');assert(clear('old',2).kind=='Committed');assert(set('new',2).kind=='Committed')
assert(clear('old',2).kind=='Committed')
assert(a:Inspect(h).value.profile.Update2GiftContexts['12']==2)
assert(a:Release(h).kind=='Released');a,h=open('two')
assert(a:Inspect(h).value.profile.Update2GiftContextIds['12']=='new')
assert(clear('new',3).kind=='Committed');assert(a:Inspect(h).value.profile.Update2GiftContexts['12']==2)
assert(clear('new',2).kind=='Committed');assert(a:Inspect(h).value.profile.Update2GiftContexts['12']==nil)
local s=fs.readFile('audit/merged/'..world..'/ServerScriptService/Economy/SpeedProductPurchases.luau')
local first=s:find('local function acquireReceipt',1,true);local last=s:find('local function waitForPlayerData',first,true)
local record={Status='Granted',TargetUserId=2,GiftContextId='old'}
local env={ReceiptStore={UpdateAsync=function(_,_,fn) record=fn(record);return record end},receiptKey=function(x) return x end,
 receiptOwnerId='server',HttpService={GenerateGUID=function() return 'unique' end},RECEIPT_LEASE_SECONDS=30,
 RunService={IsStudio=function() return false end},isGrantedRecord=function(x) return x and x.Status=='Granted' end}
local api=luau.load(s:sub(first,last-1)..'\nreturn {acquire=acquireReceipt,mark=markReceiptGranted}',{environment=env})()
local info={PurchaseId='purchase',PlayerId=1,ProductId=12,TargetUserId=3,GiftContextId='new'}
local ok,decision,_,target,id=api.acquire(info)
assert(ok and decision=='granted' and target==2 and id=='old','Old receipt adopted new gift')
record=nil;ok,decision,_,target,id=api.acquire(info);assert(ok and target==3 and id=='new')
assert(api.mark(info));assert(record.GiftContextId=='new' and record.TargetUserId==3)
print('PASS '..world..' gift identity survives rejoin; stale cleanup cannot erase new gift; actual receipt ledger freezes attempt identity')
