local originalApplyCommand=ProfileReducers.ApplyCommand
function ProfileReducers.ApplyCommand(profile,command,nowUnix)
	local function invalid(message) return {ok=false,error={code="InvalidInput",message=message,retryable=false}} end
	local function finite(n) return type(n)=="number" and n==n and math.abs(n)~=math.huge end
	if command.kind=="SetPersistent" then
		local key,value=command.key,command.value
		local booleans={World2Unlocked=true,FirstTimeTutorialSeen=true,StarterPackGranted=true}
		local numbers={PermanentBaseSpeedMultiplier=true,PermanentWinsMultiplier=true,GlobalSpeedGainMultiplier=true,TrailSpeedGainMultiplier=true,UpgradeSpeedGainMultiplier=true,GamepassSpeedGainMultiplier=true,LastSeenUpdateLog=true,StarterPackRewardVersion=true}
		if booleans[key] then
			if type(value)~="boolean" then return invalid("Expected boolean") end
			profile[key]=profile[key]==true or value
		elseif numbers[key] then
			if not finite(value) or value<0 then return invalid("Expected finite nonnegative number") end
			profile[key]=if command.monotonic then math.max(profile[key] or 0,value) else value
		else return invalid("Persistent field is not writable") end
		return {ok=true,value=true}
	elseif command.kind=="PurchaseSpeed" then
		local tier=command.tier
		local multiplier=tonumber(tier.GainMultiplier) or 0
		local minGain=tonumber(tier.MinGain) or ({500,2500,10000,50000})[tier.Tier or 1] or 100
		if not finite(multiplier) or multiplier<0 or not finite(minGain) or minGain<0 then return invalid("Invalid speed purchase") end
		local value=profile.Speed*multiplier
		local rounded=0
		if value>0 then
			if value<1000 then rounded=if value>=10 then math.max(10,math.round(value/10)*10) else math.max(1,math.floor(value+0.5))
			else
				local base=1000^math.floor(math.log10(value)/3)
				local scaled=value/base
				rounded=(if scaled>=10 then math.max(10,math.round(scaled/10)*10) else math.max(1,math.round(scaled)))*base
			end
		end
		profile.Speed=math.min(1e50,profile.Speed+math.max(minGain,rounded))
		return {ok=true,value=true}
	elseif command.kind=="PurchaseMultiplier" then
		if command.key~="PermanentBaseSpeedMultiplier" and command.key~="PermanentWinsMultiplier" then return invalid("Invalid multiplier") end
		local current=profile[command.key] or 1
		local target=command.target
		if not finite(target) or target<1 then return invalid("Invalid target") end
		local nextValue=math.max(current,target)
		if command.repeatAdd and current>=target then
			if not finite(command.repeatAdd) or command.repeatAdd<0 then return invalid("Invalid increment") end
			nextValue=math.max(current,math.min(command.cap or 1e50,current+command.repeatAdd))
		end
		profile[command.key]=nextValue
		return {ok=true,value=true}
	elseif command.kind=="RecordReceipt" then
		if type(command.receiptId)~="string" or command.receiptId=="" then return invalid("Receipt identity required") end
		profile.ProcessedReceipts[command.receiptId]=nowUnix
		return {ok=true,value=true}
	elseif command.kind=="GrantStarterPack" then
		if (profile.StarterPackRewardVersion or 0)>=command.version then return {ok=true,value=true} end
		profile.Speed=math.min(1e50,profile.Speed+command.speed)
		profile.Wins=math.min(9007199254740991,profile.Wins+command.wins)
		if not table.find(profile.OwnedTrails,command.trailId) then table.insert(profile.OwnedTrails,command.trailId) end
		profile.StarterPackGranted=true;profile.StarterPackRewardVersion=command.version
		return {ok=true,value=true}
	end
	return originalApplyCommand(profile,command,nowUnix)
end
