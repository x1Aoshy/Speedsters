-- Persistent rewards and their receipt marker are committed in the same profile write.
local function persistentReceiptCommands(entry)
	local data = entry.Data or {}
	if entry.Kind == "SpeedAmount" then
		return {{kind="PurchaseSpeed",tier=data}}
	elseif entry.Kind == "PermanentMultiplier" or entry.Kind == "PermanentWinsMultiplier" then
		local speed = entry.Kind == "PermanentMultiplier"
		return {{kind="PurchaseMultiplier",key=if speed then "PermanentBaseSpeedMultiplier" else "PermanentWinsMultiplier",
			target=math.max(1,tonumber(data.TargetMultiplier) or 1),repeatAdd=if speed then tonumber(data.RepeatAddMultiplier) else nil,
			cap=tonumber(Config.MaxPermanentSpeedMultiplier) or 32}}
	elseif entry.Kind == "Rebirth" then
		return {{kind="GrantExact",stat="Rebirths",amount=math.max(1,tonumber(data.Amount) or 1)}}
	elseif entry.Kind == "AbilityFlight" then
		return {{kind="GrantUpgrade",upgradeId="Flight"}}
	elseif entry.Kind == "CosmeticUnlock" then
		if data.CosmeticType == "Trail" then return {{kind="GrantTrail",trailId=data.CosmeticId},{kind="EquipTrail",trailId=data.CosmeticId}} end
		if data.CosmeticType == "Aura" then return {{kind="GrantAura",auraId=data.CosmeticId},{kind="EquipAura",auraId=data.CosmeticId}} end
	elseif entry.Kind == "PotionSpeed" or entry.Kind == "PotionWins" then
		local speed = entry.Kind == "PotionSpeed"
		return {{kind="GrantBuff",grant={kind=if speed then "SpeedPotion" else "WinsPotion",
			addedSeconds=math.max(1,tonumber(data.DurationMinutes) or 15)*60,
			multiplier=tonumber(data.TargetMultiplier) or 2,bottleType=data.BottleType}}}
	end
	return nil
end

local function commitPersistentReceipt(player, recipient, receiptInfo, entry, commands)
	local handle = DataService.GetHandle(recipient.UserId)
	if not handle then return false end
	local purchaseId = tostring(receiptInfo.PurchaseId)
	local robux = getReceiptRobuxAmount(receiptInfo,entry)
	if recipient == player then table.insert(commands,{kind="RecordRobuxSpent",amount=robux}) end
	local result = DataService.Commit(handle,{
		operationId="receipt:"..purchaseId,receiptId=purchaseId,
		fingerprint=tostring(receiptInfo.ProductId),commands=commands,
	})
	if result.kind ~= "Committed" and result.kind ~= "AlreadyCommitted" then return false end
	if recipient ~= player then
		local buyerHandle = DataService.GetHandle(player.UserId)
		if not buyerHandle then return false end
		local buyerResult = DataService.Commit(buyerHandle,{
			operationId="gift-buyer:"..purchaseId,receiptId=purchaseId,
			fingerprint="gift:"..tostring(receiptInfo.ProductId)..":"..recipient.UserId,
			commands={{kind="RecordRobuxSpent",amount=robux}},
		})
		if buyerResult.kind ~= "Committed" and buyerResult.kind ~= "AlreadyCommitted" then return false end
	end
	return true
end

