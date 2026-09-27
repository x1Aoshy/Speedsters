local fs=require('@lune/fs')
local function replace(s,a,b)
 local x,y=s:find(a,1,true);assert(x,'Missing '..a);return s:sub(1,x-1)..b..s:sub(y+1)
end
for _,world in {'World1','World2'} do
 local root='audit/merged/'..world..'/ServerScriptService/'
 local path=root..'Services/Data/ProfileCodec.luau';local s=fs.readFile(path)
 s=s:gsub('"Update2GiftContexts","PendingStageTeleport"','"Update2GiftContexts","Update2GiftContextIds","PendingStageTeleport"');fs.writeFile(path,s)
 path=root..'Services/Data/ProfileReducers.luau';s=fs.readFile(path)
 local first=s:find('\telseif command.kind=="SetGiftContext" then',1,true)
 local last=s:find('\telseif command.kind=="GrantBuff" then',first,true)
 s=s:sub(1,first-1)..[[
	elseif command.kind=="ClearGiftContext" then
		if type(command.productId)~="string" or type(command.contextId)~="string" or #command.contextId>128 then return invalid("Invalid gift completion") end
		local ids=profile.Update2GiftContextIds or {}
		local contexts=profile.Update2GiftContexts or {}
		if (ids[command.productId] or "")==command.contextId and contexts[command.productId]==command.targetUserId then
			contexts[command.productId]=nil;ids[command.productId]=nil
		end
		return {ok=true,value=true}
	elseif command.kind=="SetGiftContext" then
		if type(command.productId)~="string" or #command.productId>32 or not command.productId:match("^%d+$")
			or not finite(command.targetUserId) or command.targetUserId%1~=0 or command.targetUserId<0 or command.targetUserId>9007199254740991
			or (command.contextId~=nil and (type(command.contextId)~="string" or #command.contextId<1 or #command.contextId>128)) then return invalid("Invalid gift context") end
		profile.Update2GiftContexts=profile.Update2GiftContexts or {}
		profile.Update2GiftContextIds=profile.Update2GiftContextIds or {}
		local old=profile.Update2GiftContexts[command.productId]
		local oldId=profile.Update2GiftContextIds[command.productId]
		if old and command.targetUserId>0 and (old~=command.targetUserId or oldId~=command.contextId) then return invalid("Another gift is pending") end
		profile.Update2GiftContexts[command.productId]=if command.targetUserId>0 then command.targetUserId else nil
		profile.Update2GiftContextIds[command.productId]=if command.targetUserId>0 then command.contextId else nil
		return {ok=true,value=true}
]]..s:sub(last);fs.writeFile(path,s)
 path=root..'Economy/SpeedProductPurchases.luau';s=fs.readFile(path)
 s=replace(s,'local targetUserId = receiptInfo.TargetUserId or receiptInfo.PlayerId','local targetUserId = receiptInfo.TargetUserId or receiptInfo.PlayerId\n\tlocal giftContextId = receiptInfo.GiftContextId or ""')
 s=replace(s,'\t\t\ttargetUserId = type(current)=="table" and current.TargetUserId or receiptInfo.TargetUserId or receiptInfo.PlayerId','\t\t\ttargetUserId = type(current)=="table" and current.TargetUserId or receiptInfo.TargetUserId or receiptInfo.PlayerId\n\t\t\tgiftContextId = if type(current)=="table" then (current.GiftContextId or "") else (receiptInfo.GiftContextId or "")')
 s=replace(s,'TargetUserId = targetUserId,','TargetUserId = targetUserId,\n\t\t\t\tGiftContextId = giftContextId,')
 s=replace(s,'return true, "acquired", claimOwnerId','return true, "acquired", claimOwnerId, targetUserId, giftContextId')
 s=replace(s,'decision, claimOwnerId, targetUserId\nend','decision, claimOwnerId, targetUserId, giftContextId\nend')
 s=replace(s,'Status = "Granted",','Status = "Granted",\n\t\t\t\tGiftContextId = if type(current)=="table" then (current.GiftContextId or "") else (receiptInfo.GiftContextId or ""),')
 s=replace(s,'receiptInfo.TargetUserId=contexts[tostring(productId)] or player.UserId','receiptInfo.TargetUserId=contexts[tostring(productId)] or player.UserId\n\t\treceiptInfo.GiftContextId=(view.value.profile.Update2GiftContextIds or {})[tostring(productId)] or ""')
 s=replace(s,'local receiptOk, receiptDecision, claimOwnerId, targetUserId = acquireReceipt(receiptInfo)','local receiptOk, receiptDecision, claimOwnerId, targetUserId, giftContextId = acquireReceipt(receiptInfo)')
 s=s:gsub('{kind="SetGiftContext",productId=tostring%(productId%),targetUserId=0}','{kind="ClearGiftContext",productId=tostring(productId),targetUserId=targetUserId,contextId=giftContextId or ""}')
 s=replace(s,'if giftRequestBusy[player] or type(requestId)~="string" then return end','if giftRequestBusy[player] or type(requestId)~="string" or #requestId<1 or #requestId>128 or type(productId)~="number" or productId~=productId or productId%1~=0 or type(targetUserId)~="number" or targetUserId~=targetUserId or targetUserId%1~=0 then return end')
 s=replace(s,'if old and old~=target.UserId then return false end','local oldId=view.ok and (view.value.profile.Update2GiftContextIds or {})[tostring(productId)]\n\t\tif old and (old~=target.UserId or oldId~=requestId) then return false end')
 s=replace(s,'kind="SetGiftContext",productId=tostring(productId),targetUserId=target.UserId','kind="SetGiftContext",productId=tostring(productId),targetUserId=target.UserId,contextId=requestId')
 fs.writeFile(path,s)
end
print('Gift attempt identity and conditional receipt cleanup integrated')
