local fs=require('@lune/fs')
local function replace(s,a,b) local x,y=s:find(a,1,true);assert(x,a);return s:sub(1,x-1)..b..s:sub(y+1) end
for _,world in {'World1','World2'} do
 local root='audit/merged/'..world..'/'
 local path=root..'ServerScriptService/Economy/SpeedProductPurchases.luau';local s=fs.readFile(path)
 s=replace(s,'if giftRequestBusy[player] or type(requestId)', 'if giftRequestBusy[player] or pendingGiftContexts[player] or type(requestId)')
 s=replace(s,'if ok and result then pendingGiftContexts[player]={ProductId=tonumber(productId),TargetUserId=target.UserId,ExpiresAt=math.huge} end',[[if ok and result then
		-- The server owns this prompt and can associate its cancellation with this attempt.
		local context={ProductId=productId,TargetUserId=target.UserId,ContextId=requestId,Handle=handle,ExpiresAt=math.huge}
		pendingGiftContexts[player]=context
		local prompted,promptError=pcall(function() MarketplaceService:PromptProductPurchase(player,productId) end)
		if not prompted then
			-- An exception is not evidence of cancellation; retain the durable route.
			warn("[Gifts] Could not open gift prompt: "..tostring(promptError))
			result=false
		end
	end]])
 local marker='\ngrantPassPerkToTarget = function(target, passId)'
 s=replace(s,marker,[[
-- Only cancellation is handled here. Successful purchases still use ProcessReceipt.
MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId,productId,isPurchased)
	if isPurchased~=false then return end
	local player=Players:GetPlayerByUserId(userId)
	local context=player and pendingGiftContexts[player]
	if not context or context.ProductId~=productId or not context.ContextId then return end
	if context.Canceling then return end
	context.Canceling=true
	local transaction={operationId="gift-cancel:"..context.ContextId,fingerprint="gift-cancel:"..context.ProductId,
		commands={{kind="ClearGiftContext",productId=tostring(context.ProductId),targetUserId=context.TargetUserId,contextId=context.ContextId}}}
	local function settle()
		local handle=DataService.GetHandle(player.UserId)
		if not handle or handle.sessionId~=context.Handle.sessionId or handle.generation~=context.Handle.generation then return end
		local ok,result=pcall(DataService.Commit,handle,transaction)
		if ok and result and (result.kind=="Committed" or result.kind=="AlreadyCommitted") then
			if pendingGiftContexts[player]==context then pendingGiftContexts[player]=nil end
		elseif not ok or (result and result.kind=="Pending") then task.delay(2,settle)
		else warn("[Gifts] Gift cancellation could not be saved") end
	end
	settle()
end)
]]..marker)
 fs.writeFile(path,s)
 path=root..'StarterPlayer/StarterPlayerScripts/UI/ShopController.luau';s=fs.readFile(path)
 s=replace(s,'\t\t\t\tpromptPurchase(gift.passType,gift.id)','\t\t\t\t-- The server opened the gift prompt after persisting its destination.')
 fs.writeFile(path,s)
end
print('Server-owned gift prompt with identity-checked cancellation installed')
