-- Offline rewards are frozen at join and granted in one persistent transaction.
-- The client panel creates no remotes of its own, so this service runs everywhere
-- and serves only the players Shared.FeatureGate lets see the preview features.
--
-- Earnings while away (Config.AfkZone, +1 Monkey style): back after OfflineMinMinutes or
-- more, each minute away up to OfflineMaxMinutes (8 hours) pays OfflineSpeedShare of the
-- player's Speed, never less than 50 + 10 per level. The Earnings panel opens with it.
-- Claim! collects it; Get x5 collects it five times over, free for VIP, or through the
-- ClaimX5 developer product (29 R$), whose receipt (Economy/SpeedProductPurchases) asks
-- this service for what to pay (_G.SpeedsterAfkClaimX5Plan).
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local MarketplaceService=game:GetService("MarketplaceService")
local FeatureGate=require(RS:WaitForChild("Shared"):WaitForChild("FeatureGate"))
local Config=require(RS:WaitForChild("Shared"):WaitForChild("Config"))
local SSS=game:GetService("ServerScriptService")
local DataService=require(SSS.Services.Data.DataService)
local RateLimiter=require(SSS.Services.ServerRateLimiter)
-- Creator Hub funnels (Services.FunnelAnalytics: never throws, never waits).
local FunnelAnalytics = (function()
	local ok, api = pcall(function()
		return require(game:GetService("ServerScriptService"):WaitForChild("Services"):WaitForChild("FunnelAnalytics", 10))
	end)
	if ok and type(api) == "table" then
		return api
	end
	return { Step = function() return false end, NewSession = function() return nil end }
end)()
local Remotes=RS:WaitForChild("Remotes")
local function remote(name)
 local r=Remotes:FindFirstChild(name)
 if not r then r=Instance.new("RemoteEvent");r.Name=name;r.Parent=Remotes end
 return r
end
local Request,Update=remote("AfkRewardsRequest"),remote("AfkRewardsUpdate")
local settings=type(Config.AfkZone)=="table" and Config.AfkZone or {}
local MIN_MINUTES=math.max(1,math.floor(tonumber(settings.OfflineMinMinutes) or 10))
local MAX_MINUTES=math.max(MIN_MINUTES,math.floor(tonumber(settings.OfflineMaxMinutes) or 480))
local SPEED_SHARE=math.max(0,tonumber(settings.OfflineSpeedShare) or 0.0003)
local ZONE_SHARE=math.max(0,tonumber(settings.SpeedShare) or 0.005)
local ZONE_FLOOR=math.max(0,tonumber(settings.SpeedFloor) or 500)
local X5=type(settings.ClaimX5)=="table" and settings.ClaimX5 or {}
local sessions={}
-- Big numbers the way the HUD shows them (1.5K, 2.3Qa...).
local SUFFIXES={"","K","M","B","T","Qa","Qi","Sx","Sp","Oc","No","Dc"}
local function short(value)
 value=math.max(0,math.floor(tonumber(value) or 0))
 local index=1
 while value>=1000 and index<#SUFFIXES do value/=1000;index+=1 end
 local text=if index==1 then tostring(math.floor(value)) else string.format("%.2f",value):gsub("0+$",""):gsub("%.$","")
 return text..SUFFIXES[index]
end
local function inspect(player)
 if player:GetAttribute("DataLoaded")~=true then return nil end
 local h=DataService.GetHandle(player.UserId)
 if not h then return nil end
 local result=DataService.Inspect(h)
 return result.ok and result.value.profile or nil,h
end
-- What `minutes` away pay a player at `level` with `speed`.
local function offlineSpeed(minutes,level,speed)
 local perMinute=math.max(50+level*10,(tonumber(speed) or 0)*SPEED_SHARE)
 return math.floor(minutes*perMinute)
end
local function evaluate(player)
 local state=sessions[player]
 local p=inspect(player)
 if not state or not p then return nil end
 if not state.evaluated then
  state.evaluated=true
  local reference=math.max(p.LastLogoutTimestamp or 0,p.LastAfkClaimTimestamp or 0)
  state.minutes=reference>0 and math.clamp(math.floor((state.joined-reference)/60),0,MAX_MINUTES) or 0
  local level=math.max(1,tonumber(player:GetAttribute("Level")) or 1)
  state.speed=offlineSpeed(state.minutes,level,p.Speed);state.wins=state.minutes*2
  state.claimed=(p.LastAfkClaimTimestamp or 0)>=state.joined
  state.roll=math.random(1,100)
 end
 return state
end
local function sendStatus(player,message)
 local state=evaluate(player)
 if not state then Update:FireClient(player,{eligible=false,message="Your data is loading. Please try again."});return end
 local vip=player:GetAttribute("VIPGamepassOwned")==true
 local eligible=state.minutes>=MIN_MINUTES and not state.claimed
 player:SetAttribute("OfflineEarningsReady", eligible)
 Update:FireClient(player,{eligible=eligible,minutes=state.minutes,minMinutes=MIN_MINUTES,
  speed=eligible and state.speed or 0,wins=eligible and state.wins or 0,isVip=vip,
  vipSpeed=state.speed*5,vipWins=state.wins*5,claimed=false,hasBonus=eligible and state.roll<=10,
  message=message or (state.claimed and "Your offline rewards have been collected." or (not eligible and "Return after at least "..MIN_MINUTES.." minutes offline. Rewards stop accumulating when you join."
   or "While you were away you earned +"..short(state.speed).." Speed!"))})
end
-- The offline claim's commands, paid `multiplier` times.
local function claimCommands(player,state,multiplier)
 local commands={
  {kind="ClaimAfk",sessionStart=state.joined},
  {kind="GrantExact",stat="Speed",amount=state.speed*multiplier},
  {kind="GrantExact",stat="Wins",amount=state.wins*multiplier},
 }
 local bonus=nil
 if state.roll<=10 then
  local kind=state.roll<=5 and "SpeedPotion" or "WinsPotion"
  table.insert(commands,{kind="GrantBuff",grant={kind=kind,addedSeconds=900,multiplier=2,bottleType="Small"}})
  bonus=state.roll<=5 and "Bonus: 15m 2x Speed Potion!" or "Bonus: 15m 2x Wins Potion!"
 end
 return commands,bonus
end
local function claim(player,mode)
 local state=evaluate(player)
 if not state or state.busy then return end
 if state.claimed or state.minutes<MIN_MINUTES then sendStatus(player);return end
 if mode=="VIP" and player:GetAttribute("VIPGamepassOwned")~=true then sendStatus(player,"VIP is required for the 5x reward.");return end
 local p,h=inspect(player)
 if not p then return end
 state.busy=true
 if not state.request then
  state.multiplier=mode=="VIP" and 5 or 1
  local commands,bonus=claimCommands(player,state,state.multiplier)
  state.bonus=bonus
  local op="afk:"..player.UserId..":"..state.joined
  state.request={operationId=op,fingerprint=op,commands=commands}
 end
 local ok,result=pcall(DataService.Commit,h,state.request)
 state.busy=false
 if not ok or (result.kind~="Committed" and result.kind~="AlreadyCommitted") then
  sendStatus(player,"Rewards are still saving. Please try again.");return
 end
 state.claimed=true
 player:SetAttribute("OfflineEarningsReady", false)
 Update:FireClient(player,{claimed=true,eligible=false,minutes=state.minutes,
  speed=state.speed*state.multiplier,wins=state.wins*state.multiplier,bonus=state.bonus,
  message="Offline rewards collected!"})
end
-- Get x5 without VIP: the server opens the ClaimX5 product's prompt.
local function promptX5(player)
 local productId=tonumber(X5.ProductId)
 if not productId or productId<=0 or player:GetAttribute("VIPGamepassOwned")==true then return end
 local ok,err=pcall(function() MarketplaceService:PromptProductPurchase(player,productId) end)
 if not ok then warn("[AfkRewardsService] Could not open the Get x5 prompt: "..tostring(err)) end
end
local function setup(player)
 if sessions[player] or not FeatureGate.IsPreviewPlayer(player) then return end
 sessions[player]={joined=os.time()}
 -- Wait on the actual loaded signal; slow loads do not permanently disable AFK.
 sessions[player].connection=player:GetAttributeChangedSignal("DataLoaded"):Connect(function()
  if player:GetAttribute("DataLoaded")==true then task.defer(sendStatus,player) end
 end)
 if player:GetAttribute("DataLoaded")==true then task.defer(sendStatus,player) end
end
Request.OnServerEvent:Connect(function(player,payload)
 if type(payload)~="table" or not sessions[player] or not RateLimiter.Allow(player,"AfkRewardsRequest",0.3) then return end
 if payload.action=="Open" or payload.action=="RequestStatus" then
  FunnelAnalytics.Step(player, "Engagement_AFK", 1, FunnelAnalytics.NewSession(player, "Engagement_AFK"))
  sendStatus(player)
 elseif payload.action=="Claim" and (payload.mode=="Normal" or payload.mode=="VIP") then claim(player,payload.mode)
 elseif payload.action=="BuyX5" then promptX5(player) end
end)
Players.PlayerAdded:Connect(setup)
for _,p in Players:GetPlayers() do setup(p) end
Players.PlayerRemoving:Connect(function(player)
 local state=sessions[player]
 if state and state.connection then state.connection:Disconnect() end
 sessions[player]=nil
end)

-- What a Get x5 receipt pays (Economy/SpeedProductPurchases commits these commands with the
-- receipt, so it pays once): the offline rewards on screen x5, else the zone's unclaimed
-- rewards x5, else, so a purchase is never empty, five times ten minutes of the zone.
-- Committed() tells the panel; Failed() puts the zone's rewards back.
_G.SpeedsterAfkClaimX5Plan=function(player)
 local state=evaluate(player)
 if state and not state.claimed and not state.busy and state.minutes>=MIN_MINUTES then
  local commands,bonus=claimCommands(player,state,5)
  return {Source="Offline",Commands=commands,
   Committed=function()
    state.claimed=true;state.multiplier=5;state.bonus=bonus
    player:SetAttribute("OfflineEarningsReady", false)
    if player.Parent then
     Update:FireClient(player,{claimed=true,eligible=false,minutes=state.minutes,speed=state.speed*5,wins=state.wins*5,bonus=bonus,message="Offline rewards collected x5!"})
    end
   end,
   Failed=function() end}
 end
 local taken=type(_G.SpeedsterAfkZoneTake)=="function" and _G.SpeedsterAfkZoneTake(player) or nil
 if taken then
  local commands={{kind="GrantExact",stat="Speed",amount=math.floor(taken.Speed*5)}}
  if taken.Tickets>0 then table.insert(commands,{kind="GrantSpinTickets",amount=taken.Tickets}) end
  return {Source="Zone",Commands=commands,
   Committed=function()
    if player.Parent then Update:FireClient(player,{claimed=true,eligible=false,speed=math.floor(taken.Speed*5),wins=0,message="AFK rewards collected x5!"}) end
   end,
   Failed=taken.Restore}
 end
 local p=inspect(player)
 local speed=p and tonumber(p.Speed) or 0
 local amount=math.floor(5*10*math.max(ZONE_FLOOR,speed*ZONE_SHARE))
 return {Source="Fallback",Commands={{kind="GrantExact",stat="Speed",amount=amount}},
  Committed=function()
   if player.Parent then Update:FireClient(player,{claimed=true,eligible=false,speed=amount,wins=0,message="AFK rewards collected x5!"}) end
  end,
  Failed=function() end}
end

-- Called only by the existing authorized server admin command dispatcher.
_G.SpeedsterTestAfkRewards=function(player,minutes)
 local state=evaluate(player)
 local p=inspect(player)
 if not state or not p or state.busy or state.request and not state.claimed then return false end
 local amount=tonumber(minutes)
 if not amount or amount~=amount or math.abs(amount)==math.huge then return false end
 state.minutes=math.clamp(math.floor(amount),0,MAX_MINUTES)
 state.joined=math.max(os.time(),(p.LastAfkClaimTimestamp or 0)+1)
 state.speed=offlineSpeed(state.minutes,math.max(1,tonumber(player:GetAttribute("Level")) or 1),p.Speed)
 state.wins=state.minutes*2;state.claimed=false;state.request=nil;state.bonus=nil;state.roll=math.random(1,100)
 sendStatus(player,"Admin test: rewards are ready to claim.")
 return true
end
