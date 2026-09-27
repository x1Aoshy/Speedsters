local fs=require('@lune/fs')
local function replace(s,a,b)
 local x,y=s:find(a,1,true);assert(x,'Missing '..a:sub(1,90));return s:sub(1,x-1)..b..s:sub(y+1)
end
for _,world in {'World1','World2'} do
 local root='audit/merged/'..world..'/'
 local function edit(path,fn) fs.writeFile(root..path,fn(fs.readFile(root..path))) end
 fs.writeFile(root..'ReplicatedStorage/Shared/ConsolePanelSupport.luau',fs.readFile('audit/persistence/ConsolePanelSupport.luau'))
 edit('ServerScriptService/Services/Data/ProfileCodec.luau',function(s)
  return replace(s,'\nreturn ProfileCodec',[[
-- Keep extension fields across old-schema round trips; normalized known fields still win.
local decodeExtended, encodeExtended = ProfileCodec.Decode, ProfileCodec.Encode
local function cloneExtension(value)
	if type(value) ~= "table" then return value end
	local result = {}
	for k,v in pairs(value) do result[k] = cloneExtension(v) end
	return result
end
function ProfileCodec.Decode(raw, validator)
	local result = decodeExtended(raw, validator)
	if result.ok and type(raw) == "table" then
		local known = encodeExtended(result.value)
		result.value.Update2PreservedFields = {}
		for k,v in pairs(raw) do
			if known[k] == nil and k ~= "Update2PreservedFields" then result.value.Update2PreservedFields[k] = cloneExtension(v) end
		end
		for _,key in {"PotionSpeedMultiplier","PotionWinsMultiplier","PotionSpeedBottleType","PotionWinsBottleType","Update2GiftContexts"} do
			result.value[key] = cloneExtension(raw[key])
		end
	end
	return result
end
function ProfileCodec.Encode(profile)
	local result = cloneExtension(profile.Update2PreservedFields or {})
	for k,v in pairs(encodeExtended(profile)) do result[k] = v end
	-- Session metadata must never be resurrected from extension fields after release.
	for _,key in {"ActiveSessionId","ActiveSessionStartedUnixMs","ActiveSessionExpiresUnix","Update2WriteId"} do result[key]=profile[key] end
	for _,key in {"PotionSpeedMultiplier","PotionWinsMultiplier","PotionSpeedBottleType","PotionWinsBottleType","Update2GiftContexts"} do result[key]=cloneExtension(profile[key]) end
	return result
end

return ProfileCodec]])
 end)
 edit('ServerScriptService/Services/Data/ProfileReducers.luau',function(s)
  s=s:gsub('math.max%(1,math.round%(scaled%)%)','math.max(1,math.floor(scaled))')
  s=replace(s,'\t\tprofile.Speed=math.min(1e50,profile.Speed+command.speed)',[[
		local speed,wins=command.speed,command.wins
		if profile.StarterPackGranted then
			speed=math.max(0,speed-(command.legacySpeed or 0));wins=math.max(0,wins-(command.legacyWins or 0))
		end
		profile.Speed=math.min(1e50,profile.Speed+speed)]])
  s=replace(s,'profile.Wins+command.wins','profile.Wins+wins')
  s=replace(s,'\treturn originalApplyCommand(profile,command,nowUnix)',[[
	if command.kind=="SetGiftContext" then
		if type(command.productId)~="string" or type(command.targetUserId)~="number" then return invalid("Invalid gift context") end
		profile.Update2GiftContexts=profile.Update2GiftContexts or {}
		profile.Update2GiftContexts[command.productId]=if command.targetUserId>0 then command.targetUserId else nil
		return {ok=true,value=true}
	elseif command.kind=="GrantBuff" then
		local grant=command.grant
		if type(grant)~="table" or not finite(grant.multiplier) or grant.multiplier<1 then return invalid("Invalid potion multiplier") end
		local result=originalApplyCommand(profile,command,nowUnix)
		if result.ok then
			local prefix=if grant.kind=="SpeedPotion" then "PotionSpeed" else "PotionWins"
			profile[prefix.."Multiplier"]=math.max(profile[prefix.."Multiplier"] or 1,grant.multiplier)
			profile[prefix.."BottleType"]=tostring(grant.bottleType or "Small")
		end
		return result
	end
	return originalApplyCommand(profile,command,nowUnix)]])
  return s
 end)
 edit('ServerScriptService/Services/Data/SessionActor.luau',function(s)
  s=replace(s,'self.leaseExpiresUnix = if pending.release then nil else self.clock.UnixNow() + self.leaseDurationSeconds','self.leaseExpiresUnix = if pending.release then nil else self.profile.ActiveSessionExpiresUnix or self.clock.UnixNow() + self.leaseDurationSeconds')
  s=replace(s,'\t\tself.mutationOwner=true\n\t\tlocal result=',[[
		self.mutationOwner=true
		local now=self.clock.UnixNow()
		if self.profile and not self.pendingWrite then
			local elapsed=math.max(0,now-(self.buffClock or now))
			local changed=false
			for _,key in {"PotionSpeedRemainingSeconds","PotionWinsRemainingSeconds"} do
				local current=self.profile[key] or 0
				if current>0 and elapsed>0 then self.profile[key]=math.max(0,current-elapsed);changed=true end
			end
			if changed then self.saveCoordinator:AdvanceCurrent() end
			self.buffClock=now
		end
		local result=]])
  s=replace(s,'\t\tself.mutationOwner=nil','\t\tself.buffClock=self.buffClock or self.clock.UnixNow()\n\t\tself.mutationOwner=nil')
  s=replace(s,'function SessionActor:_buildView(): SessionView\n\treturn {','function SessionActor:_buildView(): SessionView\n\treturn {\n\t\tbuffSampleUnix = self.buffClock or self.clock.UnixNow(),')
  return s
 end)
 edit('ServerScriptService/Services/Stats/StatsProjection.luau',function(s)
  return replace(s,'\t\t-- Progression flags',[[
		-- Timers pause while offline and use the actor's sample time during a yielding save.
		for _,prefix in {"PotionSpeed","PotionWins"} do
			local remaining=profile[prefix.."RemainingSeconds"] or 0
			player:SetAttribute(prefix.."ExpireUnix",if remaining>0 then (view.buffSampleUnix or os.time())+remaining else 0)
			player:SetAttribute(prefix.."Multiplier",profile[prefix.."Multiplier"] or 2)
			player:SetAttribute(prefix.."BottleType",profile[prefix.."BottleType"] or "Small")
		end
		if table.find(profile.OwnedUpgrades or {},"Flight") then player:SetAttribute("FlightAbilityOwned",true) end
		-- Progression flags]])
 end)
 edit('ServerScriptService/Services/Data/DataService.luau',function(s)
  return replace(s,'\nreturn DataService',[[
local operationSequence=0
function DataService.NewOperationId()
	if typeof(script)=="Instance" then return game:GetService("HttpService"):GenerateGUID(false) end
	operationSequence+=1
	return tostring(os.clock())..":"..operationSequence
end
return DataService]])
 end)
 edit('ServerScriptService/Progression/PlayerStatsBridge.luau',function(s)
  -- Every invocation is distinct, including two grants or two equips in the same second.
  s=s:gsub('operationId = [^\n]+','operationId = DataService.NewOperationId(),')
  local start=assert(s:find('\t\tif RunService and RunService:IsStudio() then',1,true))
  local finish=assert(s:find('\n\t\tend',start,true));s=s:sub(1,start-1)..s:sub(finish+7)
  s=replace(s,'\t\tlocal flushRes = DataService.Flush(handle)',[[
		local inspect=DataService.Inspect(handle)
		if not inspect.ok or not inspect.value.profile then return false end
		local commands={}
		for _,key in {"FirstTimeTutorialSeen","World2Unlocked"} do
			if player:GetAttribute(key)==true and inspect.value.profile[key]~=true then table.insert(commands,{kind="SetPersistent",key=key,value=true}) end
		end
		local seen=tonumber(player:GetAttribute("LastSeenUpdateLog")) or 0
		if seen>(inspect.value.profile.LastSeenUpdateLog or 0) then table.insert(commands,{kind="SetPersistent",key="LastSeenUpdateLog",value=seen,monotonic=true}) end
		if #commands>0 then
			local committed=DataService.Commit(handle,{operationId=DataService.NewOperationId(),fingerprint="legacy-flags",commands=commands})
			if committed.kind~="Committed" and committed.kind~="AlreadyCommitted" then return false end
		end
		local flushRes = DataService.Flush(handle)]])
  return s
 end)
 edit('ServerScriptService/Bootstrap.luau',function(s)
  return replace(s,'\tDataService.Release(player.UserId)',[[
	local result=DataService.Release(player.UserId)
	if result.kind~="Released" and result.kind~="AlreadyReleased" then
		task.spawn(function()
			for attempt=1,12 do
				if result.error and result.error.retryable==false then return end
				task.wait(5)
				result=DataService.Release(player.UserId)
				if result.kind=="Released" or result.kind=="AlreadyReleased" then return end
			end
			warn("[DataService] Final save still unconfirmed for "..player.UserId)
		end)
	end]])
 end)
 edit('ServerScriptService/Economy/SpeedProductPurchases.luau',function(s)
  s=replace(s,'local function processReceipt(receiptInfo)',fs.readFile('audit/persistence/ReceiptCommands.luau')..'\nlocal function processReceipt(receiptInfo)')
  s=replace(s,'\tlocal transaction = grantProductTransaction(grantPlayer, productEntry)',[[
	local commands=DataService and persistentReceiptCommands(productEntry)
	if commands then
		if not commitPersistentReceipt(player,grantPlayer,receiptInfo,productEntry,commands) then return retryLater() end
		if not markReceiptGranted(receiptInfo) then return retryLater() end
		if grantPlayer~=player then pendingGiftContexts[player]=nil end
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local transaction = grantProductTransaction(grantPlayer, productEntry)]])
  s=replace(s,'\tlocal currentRewardVersion =',[[
	if DataService then
		local handle=DataService.GetHandle(player.UserId)
		if not handle then return false end
		local result=DataService.Commit(handle,{
			operationId="starter-pack:"..STARTER_PACK_REWARD_VERSION,fingerprint="starter-pack:"..STARTER_PACK_REWARD_VERSION,
			commands={{kind="GrantStarterPack",version=STARTER_PACK_REWARD_VERSION,
				speed=math.max(0,tonumber(Config.StarterPackSpeedReward) or 100000),wins=math.max(0,tonumber(Config.StarterPackWinsReward) or 100),
				legacySpeed=LEGACY_STARTER_PACK_SPEED_REWARD,legacyWins=LEGACY_STARTER_PACK_WINS_REWARD,trailId=tostring(Config.StarterPackTrailReward or "Trail02")}},
		})
		return result.kind=="Committed" or result.kind=="AlreadyCommitted"
	end
	local currentRewardVersion =]])
  -- Legacy transaction speed hook is also used by gamepass completion. Never mutate an Inspect copy.
  local start=assert(s:find('\t-- Update DataService profile atomically via Commit',1,true))
  local finish=assert(s:find('\n\treturn {',start,true))
  local old=s:sub(start,finish-1)
  s=replace(s,old,[[
	if DataService then
		local handle=DataService.GetHandle(player.UserId)
		if not handle then return nil end
		local result=DataService.Commit(handle,{operationId="speed-pass:"..tostring(tier.ProductId),fingerprint="speed-pass",commands={{kind="PurchaseSpeed",tier=tier}}})
		if result.kind~="Committed" and result.kind~="AlreadyCommitted" then return nil end
		return {Rollback=function() end,Commit=function() end}
	end]])
  return s
 end)
end
print('Persistence, atomic economic receipts and starter pack integrated')
