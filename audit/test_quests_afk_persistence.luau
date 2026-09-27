local Actor=require('../src/common/ServerScriptService/Services/Data/SessionActor')
local Adapter=require('../src/common/ServerScriptService/Services/Data/DataStoreAdapter')
local Codec=require('../src/common/ServerScriptService/Services/Data/ProfileCodec')
local now=2000000
local clock={UnixNow=function() return now end,MonotonicNow=function() return now end}
local store=Adapter.CreateMock({Player_77={Version=306,Speed=1,Wins=0}})
local a=Actor.new({userId=77,sessionId='quests-A',storeAdapter=store,clock=clock})
local opened=a:Open();assert(opened.ok);local h=opened.value
local function commit(id,commands)
 return a:Commit(h,{operationId=id,fingerprint=id,commands=commands})
end
assert(a:AccrueSpeed(h,50000).ok)
local p=a:Inspect(h).value.profile
assert(p.QuestState.Daily.Progress.speed==50000)
local period=math.floor(now/86400)
local commands={{kind='ClaimQuest',category='Daily',metric='speed',target=50000,period=period},{kind='GrantExact',stat='Wins',amount=10000}}
assert(commit('daily-speed',commands).kind=='Committed')
assert(commit('daily-speed',commands).kind=='AlreadyCommitted')
assert(commit('daily-speed-second-id',commands).kind~='Committed')
assert(a:Inspect(h).value.profile.Wins==10000,'Quest must pay exactly once')
assert(commit('rebirth',{{kind='PerformRebirth'}}).kind=='Committed')
assert(a:Inspect(h).value.profile.QuestState.Daily.Progress.rebirth==1)
assert(commit('win-run',{{kind='QuestProgress',metric='wins',amount=1}}).kind=='Committed')
assert(commit('stages-time',{{kind='QuestProgress',metric='stages',amount=20},{kind='QuestProgress',metric='playtime',amount=900}}).kind=='Committed')
local potion={{kind='ClaimQuest',category='Daily',metric='playtime',target=900,period=period},{kind='GrantBuff',grant={kind='SpeedPotion',addedSeconds=900,multiplier=2}}}
assert(commit('potion',potion).kind=='Committed')
assert(a:Inspect(h).value.profile.PotionSpeedRemainingSeconds==900)
assert(commit('tickets',{{kind='GrantSpinTickets',amount=1}}).kind=='Committed')
now+=30
assert(a:Release(h).kind=='Released')
assert(store:GetData('Player_77').LastLogoutTimestamp==now)
now+=1200
local b=Actor.new({userId=77,sessionId='quests-B',storeAdapter=store,clock=clock})
local bo=b:Open();assert(bo.ok);local bh=bo.value
local loaded=b:Inspect(bh).value.profile
assert(loaded.QuestState.Daily.Claimed.speed and loaded.SpinTickets==1,'Quest and tickets survive reconnect')
assert(loaded.PotionSpeedRemainingSeconds==870,'Potions pause offline')
local afk={operationId='afk-join',fingerprint='afk-join',commands={{kind='ClaimAfk',sessionStart=now},{kind='GrantExact',stat='Speed',amount=6000},{kind='GrantExact',stat='Wins',amount=40}}}
local before=loaded.Speed
assert(b:Commit(bh,afk).kind=='Committed');assert(b:Commit(bh,afk).kind=='AlreadyCommitted')
assert(b:Inspect(bh).value.profile.Speed==before+6000)
afk.operationId='afk-duplicate';afk.fingerprint='afk-duplicate'
assert(b:Commit(bh,afk).kind~='Committed')
assert(b:Inspect(bh).value.profile.Wins==10040)
now+=86400
assert(b:AccrueSpeed(bh,1).ok)
local reset=b:Inspect(bh).value.profile.QuestState.Daily
assert(not reset.Claimed.speed and reset.Progress.speed==1,'New daily period resets claims and counters')
print('PASS quest progress, rewards, no double claims, potions, tickets, reconnect, logout timestamp, AFK atomic grant and daily reset')

-- Choose Your Destiny: the catalog, and the pick and the pay on the profile.
do
 local Catalog=require('../src/common/ReplicatedStorage/Shared/QuestCatalog')
 local combos={}
 for day=0,60 do
  local paths=Catalog.PathsFor(day)
  assert(#paths==3 and paths[1].Id~=paths[2].Id and paths[2].Id~=paths[3].Id and paths[1].Id~=paths[3].Id,'Three different quests a day')
  assert(Catalog.PathsFor(day)[2].Id==paths[2].Id,'Every server offers the same quests')
  combos[paths[1].Id..paths[2].Id..paths[3].Id]=true
  for _,path in paths do
   assert(#path.Tasks==3 and #path.Rewards>=2,path.Id..' has three tasks and rewards')
   for _,task in path.Tasks do assert(Catalog.Metrics[task.Metric],path.Id..' counts a known metric') end
  end
 end
 local count=0;for _ in combos do count+=1 end
 assert(count>=8,'The quests change from day to day ('..count..' combinations in 61 days)')
 local speedTask={Metric='speed',Base=250,SpeedShare=0.5}
 assert(Catalog.TargetFor(speedTask,296)==250 and Catalog.TargetFor(speedTask,1e6)==500000,'Speed targets grow with the player')
 assert(Catalog.TargetFor({Metric='stages',Base=10},1e9)==10,'Counts stay counts')
 assert(Catalog.TaskText('wins',1)=='Claim 1 Win Pad' and Catalog.TaskText('wins',18)=='Claim 18 Win Pads' and Catalog.TaskText('playtime',600)=='Play 10 Minutes' and Catalog.TaskText('speed',5000)=='Earn 5K Speed','Task texts')
 assert(Catalog.ProgressText('playtime',250,600)=='4/10 min' and Catalog.ProgressText('speed',1200,5000)=='1.2K/5K','Progress texts')
 assert(Catalog.FormatNumber(100000)=='100K' and Catalog.FormatNumber(26600000)=='26.6M','Numbers read like the HUD')
 assert(Catalog.RewardAmount({Kind='Wins',Multiple=3},1)==5000 and Catalog.RewardAmount({Kind='Wins',Multiple=3},100)==100000,'Wins rewards grow with the level')
 assert(Catalog.RewardText({Kind='SpinTicket',Amount=2},1)=='x2' and Catalog.RewardText({Kind='PotionWins',Minutes=15},1)=='15m','Reward texts')
 -- Proportional to the player: counts follow the level (a new player is not asked for
 -- 30 stages; level 150+ gets bigger days), rewards follow the level and Speed.
 local stages={Metric='stages',Base=30}
 assert(Catalog.TargetFor(stages,0,1)==18 and Catalog.TargetFor(stages,0,20)==30 and Catalog.TargetFor(stages,0,100)==60 and Catalog.TargetFor(stages,0,500)==90,'Stage targets grow with the level')
 assert(Catalog.TargetFor({Metric='wins',Base=1},0,1)==1 and Catalog.TargetFor({Metric='wins',Base=3},0,180)==9,'Win pad targets grow with the level, never below one')
 assert(Catalog.TargetFor({Metric='playtime',Base=600},0,1)==480 and Catalog.TargetFor({Metric='playtime',Base=1800},0,180)==3600,'Time played grows at half the rate, in whole minutes')
 assert(Catalog.TargetFor({Metric='rebirth',Base=1},0,300)==1,'One rebirth a day at any level')
 assert(Catalog.TargetFor(speedTask,1e6,1)==500000 and Catalog.TargetFor(speedTask,1e6,300)==500000,'Speed targets follow Speed, not the level')
 local lastWins,lastTickets=0,0
 for _,level in {1,20,75,150,400} do
  local wins=Catalog.RewardAmount({Kind='Wins',Multiple=3},level)
  assert(wins>=lastWins,'Wins rewards never shrink as the level grows');lastWins=wins
  local tickets=Catalog.RewardAmount({Kind='SpinTicket',Amount=2},level)
  assert(tickets>=lastTickets and tickets>=1 and tickets<=3,'1 to 3 Spin Tickets');lastTickets=tickets
  local minutes=Catalog.RewardAmount({Kind='PotionSpeed',Minutes=15},level)
  assert(minutes>=15 and minutes<=30,'Potions last 15 to 30 minutes')
 end
 assert(Catalog.RewardAmount({Kind='PotionWins',Minutes=15},150)==30 and Catalog.RewardAmount({Kind='SpinTicket',Amount=3},100)==3,'Endgame potions and tickets top out')
 assert(Catalog.RewardAmount({Kind='Speed',Share=0.1},1,0)==500 and Catalog.RewardAmount({Kind='Speed',Share=0.1},10,4e6)==500000,'Speed rewards are a share of the player Speed, with a floor by level')
 assert(Catalog.RewardText({Kind='Speed',Share=0.1},10,4e6)=='500K' and Catalog.RewardIcons.Speed~=nil,'Speed rewards read like the HUD, with their icon')
 for _,path in Catalog.Paths do
  assert(#path.Rewards<=4,path.Id..' fits the four reward slots of the panel')
  for _,reward in path.Rewards do assert(Catalog.RewardIcons[reward.Kind],path.Id..' pays a reward the panel can draw') end
 end
 for metric,info in Catalog.Metrics do assert(string.match(info.Image or '','^rbxassetid://%d+$'),metric..' has an icon for its task row') end
 -- "Runs" was never a mechanic of the game (2026-09-20): the task is "Claim N Win Pads" and every
 -- paid pad counts, so no task text may speak of runs, and the goals are three times the old ones.
 for metric,info in Catalog.Metrics do
  for _,word in {info.Singular,info.Plural,info.Verb} do assert(not string.match(word,'[Rr]un'),metric..' still speaks of runs: '..word) end
 end
 for _,list in {Catalog.DailyQuests or {},Catalog.WeeklyQuests or {}} do
  for _,quest in list do assert(not string.match(string.lower(quest.Description or ''),'%f[%a]runs?%f[%A]'),quest.Id..' still speaks of runs') end
 end
 local padGoals={champion={4,6,12,18},grinder={2,3,6,9},explorer={5,9,18,27}}
 local seenPadPaths=0
 for _,path in Catalog.Paths do
  local metrics={}
  for _,task in path.Tasks do
   assert(not metrics[task.Metric],path.Id..' counts '..task.Metric..' twice: targets are keyed by metric');metrics[task.Metric]=true
   if task.Metric=='wins' then
    local goals=assert(padGoals[path.Id],path.Id..' asks for Win pads without an agreed goal');seenPadPaths+=1
    for index,level in {1,20,100,180} do
     assert(Catalog.TargetFor(task,0,level)==goals[index],path.Id..' asks for '..Catalog.TargetFor(task,0,level)..' Win pads at level '..level)
    end
   end
  end
 end
 assert(seenPadPaths==3,'Champion, Grinder and Explorer ask for Win pads')
 do
  -- The producer, from the real module: a pad on ANY stage counts once, in the grant's own commit.
  local luau,fs=require('@lune/luau'),require('@lune/fs')
  local commits,returned={},true
  local services={Data={DataService={GetHandle=function() return {userId=1,sessionId='s',generation=1} end,NewOperationId=function() return 'op'..#commits end,
   Commit=function(_,request) table.insert(commits,request);return {kind='Committed'} end}},
   MovementGuard={CanClaim=function() return true end,RecordFinalClaim=function() end},
   PadTouchService={IsAtPad=function() return not returned end,RequestRetry=function() end,ConsumeContact=function() return true end}}
  local padPlayer={UserId=1,Name='Runner',Parent=true,GetAttribute=function(_,name) return name=='DataLoaded' and true or nil end,FindFirstChild=function() return nil end}
  local claims=luau.load(fs.readFile('src/common/ServerScriptService/Services/RewardPadClaims.luau'),{environment={
   game={GetService=function(_,name) return name=='Players' and {PlayerRemoving={Connect=function() end}} or {} end},
   script={Parent=services},require=function(module) return module end,_G={},os=os,math=math,table=table,type=type,typeof=function(value) return type(value) end,
   tonumber=tonumber,tostring=tostring,pcall=pcall,warn=function() end,task=nil}})()
  padPlayer.Parent=nil -- (no Players service here: the feedback branch is skipped)
  for _,final in {false,true} do
   table.clear(commits);returned=false
   local ok=claims.Claim(padPlayer,{},100,3,final,function() returned=true;return true end)
   assert(ok==true and #commits==1,'a pad claim is one commit')
   local counted=0
   for _,command in commits[1].commands do if command.kind=='QuestProgress' then assert(command.metric=='wins' and command.amount==1);counted+=1 end end
   assert(commits[1].commands[1].kind=='GrantExact' and commits[1].commands[1].amount==100 and counted==1,'every paid pad counts once for the quest, final or not')
  end
  table.clear(commits);returned=false
  assert(claims.Claim(padPlayer,{},100,3,false,function() return false end)==false and #commits==0,'a claim whose return fails pays nothing and counts nothing')
 end

 local store78=Adapter.CreateMock({Player_78={Version=306,Speed=1,Wins=0}})
 local c=Actor.new({userId=78,sessionId='destiny-A',storeAdapter=store78,clock=clock})
 local co=c:Open();assert(co.ok);local ch=co.value
 local function run(id,commands) return c:Commit(ch,{operationId=id,fingerprint=id,commands=commands}) end
 local day=math.floor(now/86400)
 assert(run('early',{{kind='QuestProgress',metric='stages',amount=7}}).kind=='Committed')
 assert(run('bad-choice',{{kind='ChooseQuestPath',period=day,choice=4,targets={stages=10}}}).kind~='Committed','Only quests 1-3')
 assert(run('bad-metric',{{kind='ChooseQuestPath',period=day,choice=1,targets={jumps=10}}}).kind~='Committed','Only known metrics')
 assert(run('old-day',{{kind='ChooseQuestPath',period=day-1,choice=1,targets={stages=10}}}).kind~='Committed','Only today')
 assert(run('choose',{{kind='ChooseQuestPath',period=day,choice=2,targets={stages=10,playtime=600}}}).kind=='Committed')
 local destiny=c:Inspect(ch).value.profile.QuestState.Destiny
 assert(destiny.Choice==2 and destiny.Baseline.stages==7 and destiny.Targets.playtime==600,'The pick keeps its targets, and counts from its moment')
 assert(run('choose-again',{{kind='ChooseQuestPath',period=day,choice=1,targets={stages=10}}}).kind~='Committed','One pick a day')
 local pay={{kind='ClaimQuestPath',period=day},{kind='GrantExact',stat='Wins',amount=5000},{kind='GrantSpinTickets',amount=2}}
 assert(run('pay-early',pay).kind~='Committed','Nothing pays before the tasks are done')
 assert(run('work',{{kind='QuestProgress',metric='stages',amount=10},{kind='QuestProgress',metric='playtime',amount=599}}).kind=='Committed')
 assert(run('pay-almost',pay).kind~='Committed','Every task must be done')
 assert(run('work-more',{{kind='QuestProgress',metric='playtime',amount=1}}).kind=='Committed')
 assert(run('pay',pay).kind=='Committed' and run('pay',pay).kind=='AlreadyCommitted','Pays')
 assert(run('pay-twice',pay).kind~='Committed','...once')
 local paid=c:Inspect(ch).value.profile
 assert(paid.Wins==5000 and paid.SpinTickets==2 and paid.QuestState.Destiny.Claimed==true,'Rewards landed')
 now+=10
 assert(c:Release(ch).kind=='Released')
 local d=Actor.new({userId=78,sessionId='destiny-B',storeAdapter=store78,clock=clock})
 local dopen=d:Open();assert(dopen.ok)
 local kept=d:Inspect(dopen.value).value.profile.QuestState.Destiny
 assert(kept and kept.Choice==2 and kept.Claimed==true and kept.Baseline.stages==7,'The pick and the pay survive reconnecting')
 now+=86400
 local function runD(id,commands) return d:Commit(dopen.value,{operationId=id,fingerprint=id,commands=commands}) end
 assert(runD('next-day',{{kind='ChooseQuestPath',period=math.floor(now/86400),choice=1,targets={wins=2}}}).kind=='Committed','A new day, a new pick')
 now-=86400
 local decoded=Codec.Decode({Version=306,QuestState={Destiny={Period=0/0,Choice=9,Targets={stages=-5,jumps=3},Baseline={speed='x'},Claimed='yes'}}})
 assert(decoded.ok,'A damaged pick still loads')
 local cleaned=decoded.value.QuestState.Destiny
 assert(cleaned.Period==0 and cleaned.Choice==3 and cleaned.Targets.stages==0 and cleaned.Targets.jumps==nil and cleaned.Baseline.speed==nil and cleaned.Claimed==false,'Saved picks are cleaned on load')
 print('PASS Choose Your Destiny: three different quests a day, scaled targets, one pick counted from its moment, pays once when done, survives reconnect, new day new pick')
end
