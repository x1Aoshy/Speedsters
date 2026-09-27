local process=require('@lune/process')
local world=process.args[1] or 'World1'
local Actor=require('../merged/'..world..'/ServerScriptService/Services/Data/SessionActor')
local Adapter=require('../merged/'..world..'/ServerScriptService/Services/Data/DataStoreAdapter')
local Codec=require('../merged/'..world..'/ServerScriptService/Services/Data/ProfileCodec')
local DataService=require('../merged/'..world..'/ServerScriptService/Services/Data/DataService')
local now=1000
local clock={UnixNow=function() return now end,MonotonicNow=function() return now end}
local function equal(a,b)
	if type(a)~=type(b) then return false end
	if type(a)~='table' then return a==b end
	for k,v in a do if not equal(v,b[k]) then return false end end
	for k in b do if a[k]==nil then return false end end
	return true
end
local function open(store,id,session)
	local actor=Actor.new({userId=id,sessionId=session,storeAdapter=store,clock=clock})
	local result=actor:Open();assert(result.ok,tostring(result.error and result.error.message));return actor,result.value
end
local fixture={Version=306,Speed=1234567890123,Wins=78000,Rebirths=12,RobuxSpent=990,
	GlobalSpeedGainMultiplier=2,TrailSpeedGainMultiplier=3,UpgradeSpeedGainMultiplier=4,GamepassSpeedGainMultiplier=10,
	PermanentBaseSpeedMultiplier=2,PermanentWinsMultiplier=2,StarterPackGranted=true,StarterPackRewardVersion=2,
	World2Unlocked=true,FirstTimeTutorialSeen=true,FirstRunEasyLevelsEligible=false,EquippedSkin='FlashSuit',
	OwnedSkins={'FlashSuit','SonicSuit'},EquippedTrail='red',OwnedTrails={'red','blue'},EquippedAura='lightning',OwnedAuras={'lightning'},OwnedUpgrades={'Flight'},
	ProcessedReceipts={purchase_1=900,purchase_2=950},DailyLoginState={ClaimedDays={1,2},LastClaimAt=900,LastClaimedDay=2,Cycle=3},
	FutureCompatibleFlag={nested={7,8,9}}}
for i=1,250 do fixture.ProcessedReceipts['p'..i]=i end
local store=Adapter.CreateMock({Player_1=fixture})
local a,h=open(store,1,'A');assert(a:Release(h).kind=='Released')
local persisted=store:GetData('Player_1')
for k,v in fixture do assert(equal(v,persisted[k]),'Lost migration field '..k) end
assert(persisted.ActiveSessionId==nil)
print('PASS '..world..' OG-shaped migration: all fields, unknown extensions and 252 receipts retained')
for id,raw in { [2]='corrupt-record',[3]={Version=999,Speed=12345}} do
	local damaged=Adapter.CreateMock({['Player_'..id]=raw})
	local actor=Actor.new({userId=id,storeAdapter=damaged,clock=clock})
	assert(not actor:Open().ok);assert(equal(raw,damaged:GetData('Player_'..id)))
end
assert(not Adapter.CreateProduction('offline-only'):UpdateAsync('x',function() return {} end).ok)
local competing={UpdateAsync=function(_,_,callback)
	callback(nil)
	local other={Version=306,Speed=15,ActiveSessionId='foreign',ActiveSessionExpiresUnix=now+120}
	assert(callback(other)==nil);return {ok=true,value=other}
end}
assert(not Actor.new({userId=4,storeAdapter=competing,clock=clock}):Open().ok)
print('PASS corrupt/future records unchanged; production failures and contended callback fail closed')
local b,bh=open(store,1,'B')
assert(not Actor.new({userId=1,sessionId='C',storeAdapter=store,clock=clock}):Open().ok)
now+=121
local c,ch=open(store,1,'C')
assert(b:Commit(bh,{operationId='late',fingerprint='late',commands={{kind='GrantExact',stat='Wins',amount=1}}}).kind~='Committed')
assert(store:GetData('Player_1').ActiveSessionId=='C')
assert(c:Release(ch).kind=='Released')
print('PASS old server cannot overwrite replacement lease')
local ps=Adapter.CreateMock({Player_5={Version=306,Speed=100,Wins=0}})
local p,ph=open(ps,5,'P')
local requests={
	{operationId='starter1',fingerprint='starter1',commands={{kind='GrantStarterPack',version=2,speed=1000,wins=100,trailId='Trail02'}}},
	{operationId='rank1',receiptId='rank1',fingerprint='rank1',commands={{kind='GrantExact',stat='Speed',amount=1000000},{kind='GrantExact',stat='Wins',amount=1000},{kind='GrantUpgrade',upgradeId='rank'}}},
	{operationId='gift',fingerprint='gift',commands={{kind='SetGiftContext',productId='12',targetUserId=22}}},
	{operationId='unlock',fingerprint='unlock',commands={{kind='SetPersistent',key='World2Unlocked',value=true}}},
	{operationId='potion',receiptId='potion',fingerprint='potion',commands={{kind='GrantBuff',grant={kind='SpeedPotion',addedSeconds=600,multiplier=2}}}},
}
for _,request in requests do assert(p:Commit(ph,request).kind=='Committed');assert(p:Commit(ph,request).kind=='AlreadyCommitted') end
now+=60;assert(p:Flush(ph).kind=='Saved');assert(p:Release(ph).kind=='Released')
now+=3600
local q,qh=open(ps,5,'Q');local profile=q:Inspect(qh).value.profile
assert(profile.Speed==1001100 and profile.Wins==1100)
assert(profile.World2Unlocked and profile.Update2GiftContexts['12']==22)
assert(profile.PotionSpeedRemainingSeconds==540 and profile.PotionSpeedMultiplier==2)
assert(q:Commit(qh,{operationId='starter2',fingerprint='starter2',commands=requests[1].commands}).kind=='Committed')
assert(q:Inspect(qh).value.profile.Speed==1001100)
assert(q:Commit(qh,requests[2]).kind=='AlreadyCommitted')
assert(q:Release(qh).kind=='Released')
print('PASS starter bundle, rank reward, gift route, World2 unlock and potion survive rejoin without duplicate grants')
local fs=require('@lune/fs');local luau=require('@lune/luau')
local entry={Kind='SpeedAmount',Data={Tier=1,GainMultiplier=0.2,MinGain=500}}
local code=fs.readFile('audit/persistence/ReceiptCommands.luau')..'\nreturn {commands=persistentReceiptCommands,commit=commitPersistentReceipt}'
DataService.Init({storeAdapter=Adapter.CreateMock({Player_11={Version=306,Speed=100}}),clock=clock})
DataService.Start();assert(DataService.Open(11).ok)
local handler=luau.load(code,{environment={Config={},DataService=DataService,getReceiptRobuxAmount=function() return 25 end}})()
local buyer={UserId=11}
local receipt={PurchaseId='economic',ProductId=12}
assert(handler.commit(buyer,buyer,receipt,entry,handler.commands(entry)))
assert(handler.commit(buyer,buyer,receipt,entry,handler.commands(entry)))
local view=DataService.Inspect(DataService.GetHandle(11)).value.profile
assert(view.Speed==600 and view.RobuxSpent==25)
assert(DataService.Release(11).kind=='Released')
print('PASS actual receipt command builder + DataService: reward and RobuxSpent exactly once')

