local fs=require('@lune/fs')
local function replace(s,a,b)
 local x,y=s:find(a,1,true);assert(x,'Missing '..a:sub(1,95));return s:sub(1,x-1)..b..s:sub(y+1)
end
for _,world in {'World1','World2'} do
 local root='audit/merged/'..world..'/ServerScriptService/Services/'
 local function edit(path,fn) fs.writeFile(root..path,fn(fs.readFile(root..path))) end
 edit('Data/ProfileReducers.luau',function(s)
  return replace(s,'\tif command.kind=="SetDailyState" then',[[
	if command.kind=="PurchaseUpgrade" then
		if type(command.upgradeId)~="string" or command.upgradeId=="" or not finite(command.cost) or command.cost<0 or command.cost%1~=0 then return invalid("Invalid upgrade purchase") end
		if table.find(profile.OwnedUpgrades,command.upgradeId) then return {ok=true,value=true} end
		if profile.Wins<command.cost then return {ok=false,error={code="InsufficientFunds",message="Not enough Wins",retryable=false}} end
		profile.Wins-=command.cost
		table.insert(profile.OwnedUpgrades,command.upgradeId)
		return {ok=true,value=true}
	elseif command.kind=="SetAbilityEquipped" then
		if type(command.equipped)~="boolean" then return invalid("Invalid ability state") end
		if command.equipped and not table.find(profile.OwnedUpgrades,"Flight") then return invalid("Flight is not owned") end
		if not table.find(profile.OwnedUpgrades,"__AbilityEquipStateInitialized") then table.insert(profile.OwnedUpgrades,"__AbilityEquipStateInitialized") end
		local index=table.find(profile.OwnedUpgrades,"__AbilityEquipped_Flight")
		if command.equipped and not index then table.insert(profile.OwnedUpgrades,"__AbilityEquipped_Flight")
		elseif not command.equipped and index then table.remove(profile.OwnedUpgrades,index) end
		return {ok=true,value=true}
	elseif command.kind=="BeginStageTeleport" then
		if type(command.id)~="string" or command.id=="" or #command.id>128 or (command.world~=1 and command.world~=2)
			or not finite(command.stage) or command.stage%1~=0 or command.stage<1 or command.stage>100
			or not finite(command.cost) or command.cost%1~=0 or command.cost<0 or command.cost>9007199254740991 then return invalid("Invalid stage travel") end
		local pending=profile.PendingStageTeleport
		if pending then
			if pending.id==command.id and pending.world==command.world and pending.stage==command.stage and pending.cost==command.cost then return {ok=true,value=true} end
			return {ok=false,error={code="OperationConflict",message="Another stage travel is pending",retryable=true}}
		end
		if profile.Wins<command.cost then return {ok=false,error={code="InsufficientFunds",message="Not enough Wins",retryable=false}} end
		profile.Wins-=command.cost
		profile.PendingStageTeleport={id=command.id,world=command.world,stage=command.stage,cost=command.cost}
		return {ok=true,value=true}
	elseif command.kind=="FinishStageTeleport" then
		if type(command.id)~="string" or type(command.refund)~="boolean" then return invalid("Invalid travel completion") end
		local pending=profile.PendingStageTeleport
		if not pending then return {ok=true,value=true} end
		if pending.id~=command.id then return {ok=false,error={code="OperationConflict",message="Travel identity mismatch",retryable=false}} end
		if command.refund then profile.Wins=math.min(9007199254740991,profile.Wins+pending.cost) end
		profile.PendingStageTeleport=nil
		return {ok=true,value=true}
	elseif command.kind=="SetDailyState" then]])
 end)
 edit('Data/ProfileCodec.luau',function(s)
  s=s:gsub('"PotionWinsBottleType","Update2GiftContexts"','"PotionWinsBottleType","Update2GiftContexts","PendingStageTeleport"')
  return replace(s,'\t\tlocal known = encodeExtended(result.value)',[[
		local pending=raw.PendingStageTeleport
		if pending~=nil then
			local function finite(value) return type(value)=="number" and value==value and math.abs(value)~=math.huge end
			if type(pending)~="table" or type(pending.id)~="string" or pending.id=="" or #pending.id>128
				or (pending.world~=1 and pending.world~=2) or not finite(pending.stage) or pending.stage%1~=0 or pending.stage<1 or pending.stage>100
				or not finite(pending.cost) or pending.cost%1~=0 or pending.cost<0 or pending.cost>9007199254740991 then
				return {ok=false,error={code="CorruptData",message="Invalid pending travel; preserving stored record",retryable=false}}
			end
		end
		local known = encodeExtended(result.value)]])
 end)
 edit('Stats/StatsProjection.luau',function(s)
  return replace(s,'if table.find(profile.OwnedUpgrades or {},"Flight") then player:SetAttribute("FlightAbilityOwned",true) end',[[local upgrades=profile.OwnedUpgrades or {}
		local owned=table.find(upgrades,"Flight")~=nil
		local initialized=table.find(upgrades,"__AbilityEquipStateInitialized")~=nil
		local equipped=owned and (not initialized or table.find(upgrades,"__AbilityEquipped_Flight")~=nil)
		player:SetAttribute("FlightAbilityOwned",owned)
		player:SetAttribute("FlightAbilityEquipped",equipped)
		player:SetAttribute("EquippedAbility",if equipped then "Flight" else "")
		if not equipped then
			player:SetAttribute("FlightAbilityActive",false)
			player:SetAttribute("FlightAbilityPowered",false)
		end]])
 end)
end
print('Flight transactions and persistent stage travel commands ready')
