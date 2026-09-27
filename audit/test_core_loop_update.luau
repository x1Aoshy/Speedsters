local fs=require('@lune/fs')
local luau=require('@lune/luau')
local rb=require('@lune/roblox')
local paths={
 'src/common/ReplicatedStorage/Shared/Config.luau',
 'src/common/ReplicatedStorage/Shared/DailyRewardsData.luau',
 'src/common/ReplicatedStorage/Shared/QuestCatalog.luau',
 'src/common/ServerScriptService/Services/FunnelAnalytics.luau',
 'src/common/ServerScriptService/Progression/RebirthSystem.server.luau',
 'src/common/ServerScriptService/Social/AfkZoneService.server.luau',
 'src/common/StarterPlayer/StarterPlayerScripts/UI/FirstTimeTutorial.client.luau',
 'src/common/StarterPlayer/StarterPlayerScripts/UI/StarterPackOffer.client.luau',
}
for _,path in paths do
 luau.compile(fs.readFile(path))
 print('COMPILES',path)
end
local config=fs.readFile(paths[1])
assert(config:find('BaseGain = 10,',config:find('Config.World2TreadmillProfiles',1,true),true))
assert(config:find('MobiusWallyWestSuit = 110',config:find('if Config.IsWorld2Place or Config.IsWorld3Place',1,true),true))
local daily=fs.readFile(paths[2])
assert(daily:find('Day = 1,  Type = "Speed", Amount = 250',1,true))
local quests=fs.readFile(paths[3])
assert(quests:find('period >= 20717',1,true))
assert(quests:find('Base = 180',1,true))
local funnel=fs.readFile(paths[4])
assert(not funnel:find('send(player, funnel, id, step, stepName)',1,true))
assert(funnel:find('Revive_Purchase_v2',1,true) and funnel:find('Revive_Dismissed_v2',1,true))
local rewardModule=luau.load(daily)()
assert(rewardModule.Rewards[1].Amount == 250)
assert(rewardModule.Rewards[1].Amount < 100000)
local questModule=luau.load(quests)()
for period=20717,20730 do
 local offered=questModule.PathsFor(period)
 local seen={}
 for _,path in offered do seen[path.Id]=true end
 local distinct=0;for _ in seen do distinct+=1 end
 assert(seen.sprinter and #offered==3 and distinct==3,'Short quest absent or duplicate on '..period)
end
assert(questModule.TargetFor(questModule.Paths[1].Tasks[3],1,1)==180,'New player short quest is three minutes')
local function worldConfig(number)
 local place={GetAttribute=function(_,key) if key=='PlaceWorldNumber' then return number end end,
  FindFirstChild=function() return nil end}
 local env={
  game={GetService=function() return place end,PlaceId=0},workspace=place,
  Color3=rb.Color3,Vector3=rb.Vector3,CFrame=rb.CFrame,Enum=rb.Enum,
 }
 return luau.load(config,{environment=setmetatable(env,{__index=_G})})()
end
local w1,w2,w3=worldConfig(1),worldConfig(2),worldConfig(3)
assert(w2.World2TreadmillProfiles.Golden.BaseGain==w1.NewWorld1TreadmillProfiles.Diamond.BaseGain)
assert(w3.World3TreadmillProfiles.Diamond.BaseGain>=w2.World2TreadmillProfiles.Diamond.BaseGain)
assert(w1.SuitSpeedGainMultipliers.MobiusWallyWestSuit==w2.SuitSpeedGainMultipliers.MobiusWallyWestSuit)
assert(w2.SuitSpeedGainMultipliers.MobiusWallyWestSuit==w3.SuitSpeedGainMultipliers.MobiusWallyWestSuit)
print('PASS core loop assertions')
