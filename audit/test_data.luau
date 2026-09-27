local process=require('@lune/process')
local root=process.args[1] or 'source/V2'
local patched=root:find('patched',1,true)~=nil
local base='./'..root..'/ServerScriptService/Services/Data/'
local Codec=require(base..'ProfileCodec')
local Adapter=require(base..'DataStoreAdapter')
local Actor=require(base..'SessionActor')
local ds=require(base..'DataService')
local now=1000
local clock={UnixNow=function() return now end,MonotonicNow=function() return now end}
local function newActor(store,id,session)
 return Actor.new({userId=id,sessionId=session or 'test-A',storeAdapter=store,clock=clock})
end
local fixture={Version=306,Speed=1234567890123,Wins=78000,Rebirths=12,RobuxSpent=990,
 GlobalSpeedGainMultiplier=2,TrailSpeedGainMultiplier=3,UpgradeSpeedGainMultiplier=4,GamepassSpeedGainMultiplier=10,
 PermanentBaseSpeedMultiplier=2,PermanentWinsMultiplier=2,StarterPackGranted=true,StarterPackRewardVersion=2,
 World2Unlocked=true,FirstTimeTutorialSeen=true,FirstRunEasyLevelsEligible=false,EquippedSkin='FlashSuit',
 OwnedSkins={'FlashSuit','SonicSuit'},EquippedTrail='red',OwnedTrails={'red','blue'},EquippedAura='lightning',OwnedAuras={'lightning'},OwnedUpgrades={'Flight'},
 ProcessedReceipts={purchase_1=900,purchase_2=950},DailyLoginState={ClaimedDays={1,2},LastClaimAt=900,LastClaimedDay=2,Cycle=3}}
local function eq(a,b)
 if type(a)~=type(b) then return false end
 if type(a)~='table' then return a==b end
 for k,v in a do if not eq(v,b[k]) then return false end end
 for k in b do if a[k]==nil then return false end end
 return true
end
local store=Adapter.CreateMock({Player_1=fixture})
local a=newActor(store,1);local opened=a:Open();assert(opened.ok)
local h=opened.value;assert(a:Release(h).kind=='Released')
local migrated=store:GetData('Player_1')
for k,v in fixture do assert(eq(v,migrated[k]),'migration changed '..k) end
print('PASS OG-shaped profile: speed/wins/rebirths/inventory/multipliers/receipts/daily preserved')
local b=newActor(store,1,'test-B'); local bh=b:Open();assert(bh.ok)
local blocked=newActor(store,1,'test-C'):Open();assert(not blocked.ok and blocked.error.code=='LeaseBusy')
now+=121
assert(newActor(store,1,'test-D'):Open().ok)
assert(b:AccrueSpeed(bh.value,5).ok)
assert(b:Flush(bh.value).kind=='Failed','old owner can write')
print('PASS second owner blocked and stale owner cannot save')
for _,raw in {'CORRUPT_EXISTING_RECORD',17,false} do
 local s=Adapter.CreateMock({Player_2=raw}); local actor=newActor(s,2);local result=actor:Open()
 if patched then
  assert(not result.ok and eq(s:GetData('Player_2'),raw),'corrupt record was overwritten')
 else
  assert(result.ok and type(s:GetData('Player_2'))=='table','original corruption reproduction changed')
 end
end
print(patched and 'PASS corrupt records remain untouched' or 'CONFIRMED BLOCKER: corrupt records overwritten with defaults')
local future={Version=999,Speed=998877,ActiveSessionId='keep',ActiveSessionExpiresUnix=0}
local futureStore=Adapter.CreateMock({Player_3=future}); local futureActor=newActor(futureStore,3)
assert(not futureActor:Open().ok)
if patched then assert(eq(futureStore:GetData('Player_3'),future),'future record mutated') end
print(patched and 'PASS future schema remains untouched' or 'CHECK future schema rejects after acquiring/releasing lease')
local unavailable=Adapter.CreateProduction('offline-test-only')
local result=unavailable:UpdateAsync('x',function() return {Speed=1} end)
assert(result.ok==not patched,'production fallback behavior unexpected')
print(patched and 'PASS unavailable store fails closed' or 'CONFIRMED BLOCKER: production fallback claims mock save is durable')
local contended={UpdateAsync=function(_,_,transform)
 transform(nil)
 local owned={Version=306,Speed=100,ActiveSessionId='another-server',ActiveSessionExpiresUnix=now+120}
 local cancelled=transform(owned)
 assert(cancelled==nil)
 return {ok=true,value=owned}
end}
local contention=newActor(contended,9):Open()
assert(contention.ok==not patched,'callback contention result unexpected')
print(patched and 'PASS retried acquire callback cannot accept another owner' or 'CONFIRMED BLOCKER: stale callback flag accepts another session profile')

-- Deterministic reproduction: accrue while a durable economic commit yields.
local s=Adapter.CreateMock({Player_4={Version=306,Speed=100,Wins=1000}})
local realUpdate=s.UpdateAsync;local inject=nil
function s:UpdateAsync(key,transform)
 local result=realUpdate(self,key,transform)
 if inject then local fn=inject;inject=nil;fn() end
 return result
end
local actor=newActor(s,4);local oh=actor:Open().value
inject=function()
 assert(actor:AccrueSpeed(oh,25).ok);assert(actor:Inspect(oh).value.profile.Speed==125)
end
assert(actor:Commit(oh,{operationId='reward-1',fingerprint='wins-10',commands={{kind='GrantExact',stat='Wins',amount=10}}}).kind=='Committed')
assert(actor:Inspect(oh).value.profile.Speed==100)
print('CONFIRMED REMAINING BLOCKER: speed earned during Commit is discarded (125 -> 100)')

local timedStore=Adapter.CreateMock({Player_5={Version=306,Speed=100,Wins=1000}})
local timedActor=newActor(timedStore,5);local th=timedActor:Open().value
timedStore:SetFailureMode('Player_5','Timeout')
local commit=timedActor:Commit(th,{operationId='purchase',fingerprint='purchase',commands={{kind='GrantExact',stat='Speed',amount=500}}})
assert(commit.kind=='Pending' and timedStore:GetData('Player_5').Speed==600)
timedStore:SetFailureMode('Player_5','None');timedActor:Release(th)
assert(timedStore:GetData('Player_5').Speed==100)
print('CONFIRMED REMAINING BLOCKER: timeout-applied grant overwritten by Release (600 -> 100)')

local snap=Codec.Decode(fixture).value
local copyStore=Adapter.CreateMock({Player_6=snap});local ca=newActor(copyStore,6);local ch=ca:Open().value
ca:Inspect(ch).value.profile.PermanentBaseSpeedMultiplier=100
ca:Flush(ch)
assert(ca:Inspect(ch).value.profile.PermanentBaseSpeedMultiplier==2)
print('CONFIRMED REMAINING BLOCKER: mutating Inspect copies cannot persist purchases/multipliers')
print('DONE',root,'offline only; remaining blockers are expected reproductions, not a release approval')
