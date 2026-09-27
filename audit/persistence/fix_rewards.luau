local fs=require('@lune/fs')
local function replace(s,a,b)
 local x,y=s:find(a,1,true);assert(x,'Missing '..a:sub(1,95));return s:sub(1,x-1)..b..s:sub(y+1)
end
for _,world in {'World1','World2'} do
 local root='audit/merged/'..world..'/'
 local function edit(path,fn) fs.writeFile(root..path,fn((fs.readFile(root..path):gsub('\r\n','\n')))) end
 edit('ServerScriptService/Services/Data/ProfileReducers.luau',function(s)
  return replace(s,'\tif command.kind=="SetGiftContext" then',[[
	if command.kind=="SetDailyState" then
		local state=command.state
		if type(state)~="table" or type(state.ClaimedDays)~="table" or not finite(state.LastClaimAt) or not finite(state.Cycle) then return invalid("Invalid daily state") end
		profile.DailyLoginState={ClaimedDays=table.clone(state.ClaimedDays),LastClaimAt=state.LastClaimAt,LastClaimedDay=state.LastClaimedDay,Cycle=state.Cycle}
		return {ok=true,value=true}
	elseif command.kind=="SetGiftContext" then]])
 end)
 for _,cosmetic in {'Aura','Trail'} do
  edit('ServerScriptService/Economy/'..cosmetic..'ShopSystem.luau',function(s)
   local start=assert(s:find('\tif type(_G.SpeedsterSpendWins) == "function" then',1,true))
   local finish=assert(s:find('\n\tlocal equippedValue =',start,true))
   local variable=cosmetic:lower()..'Id'
   local block=[[
	local DataService=require(game:GetService("ServerScriptService").Services.Data.DataService)
	local handle=DataService.GetHandle(player.UserId)
	if not handle then sendState(player,"Your data is not ready");return end
	local commands={}
	if cost>0 then table.insert(commands,{kind="DebitWins",amount=cost}) end
	table.insert(commands,{kind="GrantCOSMETIC",KEY=VARIABLE})
	table.insert(commands,{kind="EquipCOSMETIC",KEY=VARIABLE})
	local result=DataService.Commit(handle,{operationId="buy:COSMETIC:"..VARIABLE,receiptId="owned:COSMETIC:"..VARIABLE,fingerprint="buy:COSMETIC:"..VARIABLE,commands=commands})
	if result.kind~="Committed" and result.kind~="AlreadyCommitted" then
		sendState(player,"Purchase is awaiting save confirmation. Try again shortly.");return
	end
]]
   block=block:gsub('COSMETIC',cosmetic):gsub('KEY',variable):gsub('VARIABLE',variable)
   return s:sub(1,start-1)..block..s:sub(finish)
  end)
 end
 edit('ServerScriptService/Social/CodesSystem.luau',function(s)
  local start=assert(s:find('\tlocal grantExactStat, unlockUpgrade, savePlayer = waitForGrantFunctions()',1,true))
  local finish=assert(s:find('\n\tlocal rewardStr =',start,true))
  return s:sub(1,start-1)..[[
	local DataService=require(ServerScriptService.Services.Data.DataService)
	local handle=DataService.GetHandle(player.UserId)
	if not handle then finish(false,"Your data is not ready.");return end
	local commands={{kind="GrantUpgrade",upgradeId=definition.Marker}}
	local rewards={}
	for _,stat in {"Speed","Wins"} do
		if definition[stat] and definition[stat]>0 then
			table.insert(commands,{kind="GrantExact",stat=stat,amount=definition[stat]})
			table.insert(rewards,"+"..tostring(definition[stat]).." "..stat)
		end
	end
	if definition.Potion then
		local potion=definition.Potion
		local kind=if potion.Type=="Wins" then "WinsPotion" else "SpeedPotion"
		table.insert(commands,{kind="GrantBuff",grant={kind=kind,addedSeconds=(potion.DurationMinutes or 10)*60,multiplier=potion.Multiplier or 2}})
		table.insert(rewards,"+"..tostring(potion.DurationMinutes or 10).."m "..kind)
	end
	local result=DataService.Commit(handle,{operationId="code:"..definition.Marker,receiptId="code:"..definition.Marker,fingerprint=definition.Marker,commands=commands})
	if result.kind~="Committed" and result.kind~="AlreadyCommitted" then
		finish(false,"Your reward is awaiting save confirmation. Try again shortly.");return
	end
]]..s:sub(finish)
 end)
 edit('ServerScriptService/Social/PlaytimeRewards.luau',function(s)
  local start=assert(s:find('\tlocal grantExactStat, savePlayer = waitForGrantFunctions()',1,true))
  local finish=assert(s:find('\n\tfinish("Claimed ',start,true))
  return s:sub(1,start-1)..[[
	local DataService=require(game:GetService("ServerScriptService").Services.Data.DataService)
	local handle=DataService.GetHandle(player.UserId)
	if not handle then finish("Your data is not ready.",false);return end
	local id="playtime:"..handle.sessionId..":"..index
	local result=DataService.Commit(handle,{operationId=id,receiptId=id,fingerprint=id,commands={{kind="GrantExact",stat=reward.Type,amount=reward.Amount}}})
	if result.kind~="Committed" and result.kind~="AlreadyCommitted" then
		finish("Your reward is awaiting save confirmation. Try again shortly.",false);return
	end
	session.Claimed[index]=true
]]..s:sub(finish)
 end)
 edit('ServerScriptService/Social/DailyLoginSystem.luau',function(s)
  local start=assert(s:find('\tclaimInProgress[player] = true\n\tlocal oldState',1,true))
  local finish=assert(s:find('\n\tfireUpdate(player, "Claimed Day ',start,true))
  return s:sub(1,start-1)..[[
	claimInProgress[player]=true
	local DataService=require(game:GetService("ServerScriptService").Services.Data.DataService)
	local handle=DataService.GetHandle(player.UserId)
	if not handle then claimInProgress[player]=nil;fireFailure(player,"Your data is not ready");return end
	local nextState=cloneState(state)
	if day>=DailyRewards.TotalDays then
		nextState.ClaimedDays={};nextState.LastClaimedDay=0;nextState.Cycle=math.max(1,nextState.Cycle+1)
	else
		table.insert(nextState.ClaimedDays,day);nextState.LastClaimedDay=day
	end
	nextState.LastClaimAt=safeNow()
	local amount=reward.Amount
	if reward.Type=="Wins" then
		amount*=(_G.SpeedsterGetPermanentWinsMultiplier(player) or 1)
	elseif reward.Type=="Speed" then
		local PotionServer=require(game:GetService("ServerScriptService").Services.PotionServer)
		local function attr(key) return tonumber(player:GetAttribute(key)) or 1 end
		amount*=(_G.SpeedsterGetTotalGainMultiplier(player) or 1)
			*(_G.SpeedsterGetSuitSpeedGainMultiplierForSkin(player:GetAttribute("EquippedSkin")) or 1)
			*(_G.SpeedsterGetRebirthSpeedGainMultiplier(player:GetAttribute("Rebirths") or 0) or 1)
			*attr("VIPSpeedGainMultiplier")*PotionServer.GetSpeedPotionMultiplier(player)*PotionServer.GetServerBoostMultiplier()
	end
	local id="daily:"..state.Cycle..":"..day..":"..state.LastClaimAt
	local result=DataService.Commit(handle,{operationId=id,receiptId=id,fingerprint=id,commands={{kind="GrantExact",stat=reward.Type,amount=amount},{kind="SetDailyState",state=nextState}}})
	if result.kind~="Committed" and result.kind~="AlreadyCommitted" then
		claimInProgress[player]=nil;fireUpdate(player,"Your reward is awaiting save confirmation. Try again shortly.");return
	end
	-- A retry may confirm yesterday's prepared state; use the authoritative result.
	local view=DataService.Inspect(handle)
	if view.ok then state=cleanLoadedState(view.value.profile.DailyLoginState);states[player]=state end
	recomputeClaimState(state)
	claimInProgress[player]=nil
]]..s:sub(finish)
 end)
end
print('Codes, daily/playtime rewards and Wins cosmetic purchases are atomic')
