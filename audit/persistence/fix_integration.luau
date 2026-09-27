local fs=require('@lune/fs')
local function replace(s,a,b)
 local x,y=s:find(a,1,true);assert(x,'Missing '..a:sub(1,95));return s:sub(1,x-1)..b..s:sub(y+1)
end
for _,world in {'World1','World2'} do
 local root='audit/merged/'..world..'/'
 local function edit(path,fn) fs.writeFile(root..path,fn((fs.readFile(root..path):gsub("\r\n","\n")))) end
 edit('ServerScriptService/Progression/RankReward.luau',function(s)
  local start=assert(s:find('\tlocal grantExactStat, unlockUpgrade, savePlayer = getGrantFunctions()',1,true))
  local finish=assert(s:find('\n\tfinish(true, "+1,000,000',start,true))
  return s:sub(1,start-1)..[[
	local DataService=require(game:GetService("ServerScriptService").Services.Data.DataService)
	local handle=DataService.GetHandle(player.UserId)
	if not handle then finish(false,"Your data is not ready. Try again.",false);return end
	local result=DataService.Commit(handle,{
		operationId="rank:"..REWARD_MARKER,receiptId="reward:"..REWARD_MARKER,fingerprint=REWARD_MARKER,
		commands={{kind="GrantExact",stat="Speed",amount=SPEED_REWARD},{kind="GrantExact",stat="Wins",amount=WINS_REWARD},{kind="GrantUpgrade",upgradeId=REWARD_MARKER}},
	})
	if result.kind~="Committed" and result.kind~="AlreadyCommitted" then
		finish(false,"Your reward is awaiting save confirmation. Try again shortly.",false);return
	end
]]..s:sub(finish)
 end)
 edit('ServerScriptService/Worlds/WorldPortalService.luau',function(s)
  local start=assert(s:find('\t\tnewlyUnlocked = true',1,true))
  local finish=assert(s:find('\n\tlocal targetPlaceId',start,true))
  return s:sub(1,start-1)..[[
		local DataService=require(game:GetService("ServerScriptService").Services.Data.DataService)
		local handle=DataService.GetHandle(player.UserId)
		if not handle then sendState(player,"Data is not ready yet.",false,"Busy");return end
		local result=DataService.Commit(handle,{operationId="world2_unlock_"..player.UserId,fingerprint="unlock_w2",commands={{kind="SetPersistent",key="World2Unlocked",value=true}}})
		if result.kind~="Committed" and result.kind~="AlreadyCommitted" then
			sendState(player,"Waiting for your unlock to save. Try again shortly.",false,"Busy");return
		end
		newlyUnlocked=true
	end
]]..s:sub(finish)
 end)
 edit('ServerScriptService/Services/Stats/StatsProjection.luau',function(s)
  return replace(s,'player:SetAttribute(prefix.."BottleType",','player:SetAttribute(prefix.."Bottle",')
 end)
 edit('StarterPlayer/StarterPlayerScripts/UI/ConsoleUiScale.luau',function(s)
  s=replace(s,'if not targetBtn or not targetBtn.Visible then','if not isVisibleButton(targetBtn) then\n\t\ttargetBtn = nil')
  s=replace(s,'child:IsA("GuiButton") and child.Visible','isVisibleButton(child)')
  s=replace(s,'local function onFocusSidebarInput(actionName, inputState, inputObject)','local function onFocusSidebarInput(actionName, inputState, inputObject)\n\tif GuiService.MenuIsOpen then return Enum.ContextActionResult.Pass end')
  return s
 end)
 edit('StarterPlayer/StarterPlayerScripts/UI/RankRewardPanel.luau',function(s)
  return replace(s,'\tif UserInputService.TouchEnabled then\n\t\tsetStatus(', '\tif GuiService:IsTenFootInterface() or UserInputService:GetLastInputType().Name:find("Gamepad") then\n\t\tsetStatus("Select JOIN GROUP, then CLAIM REWARD.", Color3.fromRGB(255, 245, 175))\n\t\treturn\n\tend\n\tif UserInputService.TouchEnabled then\n\t\tsetStatus(')
 end)
 edit('ServerScriptService/Economy/SpeedProductPurchases.luau',function(s)
  -- Handle modular gamepass speed before touching projected values.
  local start=assert(s:find('\tif DataService then\n\t\tlocal handle=DataService.GetHandle(player.UserId)\n\t\tif not handle then return nil end',1,true))
  local finish=assert(s:find('\n\tend',start,true))+5
  local block=s:sub(start,finish)
  s=s:sub(1,start-1)..s:sub(finish+1)
  s=replace(s,'local function grantSpeedTransaction(player, tier)','local function grantSpeedTransaction(player, tier)\n'..block)
  -- Delete the obsolete rollback of an immutable inspection copy.
  start=assert(s:find('\t\t\tif DataService then\n\t\t\t\tpcall(function()',1,true))
  finish=assert(s:find('\n\t\t\tif _G.SpeedsterApplyWalkSpeed',start,true))
  s=s:sub(1,start-1)..s:sub(finish)
  -- Pin gift destination in the receipt record across servers and callback retries.
  s=replace(s,'local decision = "error"\n\tlocal ok','local decision = "error"\n\tlocal targetUserId = receiptInfo.TargetUserId or receiptInfo.PlayerId\n\tlocal ok')
  s=replace(s,'ReceiptStore:UpdateAsync(receiptKey(purchaseId), function(current)\n\t\t\tif isGrantedRecord(current)', 'ReceiptStore:UpdateAsync(receiptKey(purchaseId), function(current)\n\t\t\tdecision = "error"\n\t\t\ttargetUserId = type(current)=="table" and current.TargetUserId or receiptInfo.TargetUserId or receiptInfo.PlayerId\n\t\t\tif isGrantedRecord(current)')
  s=replace(s,'Status = "Processing",','Status = "Processing",\n\t\t\t\tTargetUserId = targetUserId,')
  s=replace(s,'return decision == "acquired" or decision == "granted", decision, claimOwnerId','return decision == "acquired" or decision == "granted", decision, claimOwnerId, targetUserId')
  s=replace(s,'Status = "Granted",','Status = "Granted",\n\t\t\t\tTargetUserId = type(current)=="table" and current.TargetUserId or receiptInfo.TargetUserId,')
  s=replace(s,'\tlocal receiptOk, receiptDecision, claimOwnerId = acquireReceipt(receiptInfo)',[[
	local player=Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player or not waitForPlayerData(player,10) then return Enum.ProductPurchaseDecision.NotProcessedYet end
	if DataService then
		local handle=DataService.GetHandle(player.UserId)
		local view=handle and DataService.Inspect(handle)
		if not view or not view.ok then return Enum.ProductPurchaseDecision.NotProcessedYet end
		local contexts=view.value.profile.Update2GiftContexts or {}
		receiptInfo=table.clone(receiptInfo)
		receiptInfo.TargetUserId=contexts[tostring(productId)] or player.UserId
	end
	local receiptOk, receiptDecision, claimOwnerId, targetUserId = acquireReceipt(receiptInfo)]])
  start=assert(s:find('\tlocal player = Players:GetPlayerByUserId(receiptInfo.PlayerId)',1,true))
  finish=assert(s:find('\n\tlocal hasProcessed =',start,true))
  s=s:sub(1,start-1)..[[
	local grantPlayer=Players:GetPlayerByUserId(targetUserId or receiptInfo.TargetUserId or player.UserId)
	if not grantPlayer or not waitForPlayerData(grantPlayer,10) then return retryLater() end
]]..s:sub(finish)
  s=replace(s,'if grantPlayer~=player then pendingGiftContexts[player]=nil end',[[if grantPlayer~=player then
			pendingGiftContexts[player]=nil
			local handle=DataService.GetHandle(player.UserId)
			if handle then DataService.Commit(handle,{operationId="gift-clear:"..purchaseId,fingerprint="gift-clear",commands={{kind="SetGiftContext",productId=tostring(productId),targetUserId=0}}}) end
		end]])
  start=assert(s:find('GiftContextRequest.OnServerEvent:Connect(',1,true))
  finish=assert(s:find('\ngrantPassPerkToTarget =',start,true))
  s=s:sub(1,start-1)..[[
local giftRequestBusy={}
GiftContextRequest.OnServerEvent:Connect(function(player,targetUserId,productId,requestId)
	if giftRequestBusy[player] or type(requestId)~="string" then return end
	local target=Players:GetPlayerByUserId(tonumber(targetUserId) or 0)
	local entry=productsById[tonumber(productId)]
	local handle=DataService and DataService.GetHandle(player.UserId)
	if not target or target==player or target:GetAttribute("AcceptGifts")==false or not entry or not persistentReceiptCommands(entry) or not handle then
		GiftContextRequest:FireClient(player,requestId,false);return
	end
	giftRequestBusy[player]=true
	local ok,result=pcall(function()
		local view=DataService.Inspect(handle)
		local old=view.ok and (view.value.profile.Update2GiftContexts or {})[tostring(productId)]
		if old and old~=target.UserId then return false end
		local committed=DataService.Commit(handle,{operationId="gift-context:"..requestId,fingerprint=tostring(productId)..":"..target.UserId,commands={{kind="SetGiftContext",productId=tostring(productId),targetUserId=target.UserId}}})
		return committed.kind=="Committed" or committed.kind=="AlreadyCommitted"
	end)
	giftRequestBusy[player]=nil
	if ok and result then pendingGiftContexts[player]={ProductId=tonumber(productId),TargetUserId=target.UserId,ExpiresAt=math.huge} end
	if player.Parent then GiftContextRequest:FireClient(player,requestId,ok and result==true) end
end)
]]..s:sub(finish)
  return s
 end)
 edit('StarterPlayer/StarterPlayerScripts/UI/ShopController.luau',function(s)
  s=replace(s,'local templatePriceFormat = nil',[[
local giftRequestSerial=0
local giftReplies={}
if GiftContextRequest then
	GiftContextRequest.OnClientEvent:Connect(function(id,ok) giftReplies[id]=ok==true end)
end
local templatePriceFormat = nil]])
  s=replace(s,'\t\t\t\tGiftContextRequest:FireServer(plr.UserId, selectedGift.id)\n\t\t\t\tpromptPurchase(selectedGift.passType, selectedGift.id)\n\t\t\t\tcloseGiftPanel()',[[
				if not GiftContextRequest or selectedGift.passType=="GamePass" or plr==player then
					if priceLabel then priceLabel.Text="Gift unavailable" end
					return
				end
				local gift=table.clone(selectedGift)
				giftRequestSerial+=1
				local id=tostring(os.clock())..":"..giftRequestSerial
				priceBtn.Active=false
				if priceLabel then priceLabel.Text="Preparing gift..." end
				GiftContextRequest:FireServer(plr.UserId,gift.id,id)
				local deadline=os.clock()+20
				repeat task.wait(0.1) until giftReplies[id]~=nil or os.clock()>=deadline
				local ready=giftReplies[id];giftReplies[id]=nil
				priceBtn.Active=true
				if not ready then
					if priceLabel then priceLabel.Text="Could not prepare gift. Retry." end
					return
				end
				promptPurchase(gift.passType,gift.id)
				closeGiftPanel()]])
  return s
 end)
end
print('Reward atomicity, portal confirmation, gift routing and console integration fixed')

