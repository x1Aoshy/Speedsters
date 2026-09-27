local fs=require('@lune/fs')
local function replace(s,a,b)
 local x,y=s:find(a,1,true);assert(x,'Missing '..a:sub(1,95));return s:sub(1,x-1)..b..s:sub(y+1)
end
for _,world in {'World1','World2'} do
 local root='audit/merged/'..world..'/'
 local function edit(path,fn) fs.writeFile(root..path,fn(fs.readFile(root..path))) end
 edit('ServerScriptService/Services/Data/ProfileCodec.luau',function(s)
  -- Receipt retention must not forget an unacknowledged purchase after a count threshold.
  return replace(s,'math.min(#entries, MAX_SAVED_RECEIPTS)','#entries')
 end)
 edit('ServerScriptService/Progression/PlayerStatsBridge.luau',function(s)
  s=replace(s,'return ReceiptLedger.HasProcessed(receiptId)',[[local handle=DataService.GetHandle(player.UserId)
		local view=handle and DataService.Inspect(handle)
		return view and view.ok and view.value.profile.ProcessedReceipts[receiptId]~=nil or false]])
  local start=assert(s:find('\t\tReceiptLedger.RecordProcessed({',1,true))
  local finish=assert(s:find('\n\tend',start,true))
  s=s:sub(1,start-1)..[[
		local handle=DataService.GetHandle(player.UserId)
		if not handle then return false end
		local result=DataService.Commit(handle,{operationId="receipt:"..receiptId,receiptId=receiptId,fingerprint="legacy-receipt",commands={}})
		return result.kind=="Committed" or result.kind=="AlreadyCommitted"
]]..s:sub(finish)
  s=replace(s,'ReceiptLedger.Clear(receiptId)','-- A confirmed receipt is immutable; uncertain saves are retried, never rolled back.')
  return s
 end)
 edit('ServerScriptService/Economy/SpeedProductPurchases.luau',function(s)
  -- These effects occur inside grantProductTransaction before confirmation. Do not undo
  -- them on an uncertain write: a durable receipt proves they already ran.
  s=replace(s,'\tlocal previousRobuxSpent = cleanRobuxSpent(player:GetAttribute("RobuxSpent"))',[[
	if DataService then
		if not commitPersistentReceipt(player,grantPlayer,receiptInfo,productEntry,{}) then return retryLater() end
		local ok,message=pcall(transaction.Commit)
		if not ok then warn("[Receipt] Feedback failed: "..tostring(message)) end
		if not markReceiptGranted(receiptInfo) then return retryLater() end
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local previousRobuxSpent = cleanRobuxSpent(player:GetAttribute("RobuxSpent"))]])
  -- A receipt acknowledged before gift cleanup may be replayed after a timeout.
  local function cleanupBlock() return [[
		if DataService and (targetUserId or player.UserId)~=player.UserId then
			local handle=DataService.GetHandle(player.UserId)
			if handle then
				DataService.Commit(handle,{operationId="gift-clear:"..purchaseId,fingerprint="gift-clear",commands={{kind="SetGiftContext",productId=tostring(productId),targetUserId=0}}})
			end
		end
]] end
  s=replace(s,'\tif receiptDecision == "granted" then\n\t\treturn','\tif receiptDecision == "granted" then\n'..cleanupBlock()..'\t\treturn')
  s=replace(s,'\t\tif markReceiptGranted(receiptInfo) then\n\t\t\treturn','\t\tif markReceiptGranted(receiptInfo) then\n'..cleanupBlock()..'\t\t\treturn')
  return s
 end)
end
print('Durable receipt retention and transient purchase confirmation fixed')
