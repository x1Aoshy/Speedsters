local fs=require('@lune/fs')
local serde=require('@lune/serde')
local function replace(source,old,new)
 local start,finish=source:find(old,1,true)
 assert(start,'Patch anchor missing: '..old:sub(1,90))
 assert(not source:find(old,finish+1,true),'Ambiguous patch anchor')
 return source:sub(1,start-1)..new..source:sub(finish+1)
end
for _,label in {'V2','World2'} do
 local inv=serde.decode('json',fs.readFile('audit/'..label..'/inventory.json'))
 for _,row in inv do
  if not row.file then continue end
  local source=fs.readFile('audit/'..label..'/'..row.file)
  local name=row.path:match('([^%.]+)$')
  if name=='SpeedsterClient' then
   source=replace(source,'local StudUi = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("StudUi"))','-- Popup rendering has no dependency on the legacy StudUi module.')
   source=replace(source,'\t\tlayer = playerGui:WaitForChild("SpeedPopupLayer", 2)','\t\t-- Recreate immediately after respawn/removal; do not stall the popup queue.')
   source=replace(source,'\t\tmakeOneWorld1BarPopup(\n\t\t\trequest.Amount,','\t\tlocal ok, err = pcall(makeOneWorld1BarPopup,\n\t\t\trequest.Amount,')
   source=replace(source,'\t\ttask.wait(request.SpawnGap)','\t\tif not ok then warn("[SpeedsterClient] Popup failed: " .. tostring(err)) end\n\t\ttask.wait(request.SpawnGap)')
   source=replace(source,'\ttable.insert(world1PopupSpawnQueue, request)',[=[
	if player:GetAttribute("HidePopups") == true then return end
	-- Never replay minutes of stale gains after a burst or a slow frame.
	if #world1PopupSpawnQueue - world1PopupSpawnHead >= 48 then return end
	table.insert(world1PopupSpawnQueue, request)]=])
   source=replace(source,'SpeedGainPopup.OnClientEvent:Connect(showSpeedGainBurst)',[=[
-- The modular backend and exact grants do not always send SpeedGainPopup.
-- Watch replicated progress as a fallback, preserving the original shoe/tweens.
local lastPopupRemoteAt = -math.huge
local previousRawSpeed = tonumber(player:GetAttribute("RawSpeed"))
local fallbackSerial = 0
local lastFallbackSpeed = nil
local lastFallbackAt = -math.huge
SpeedGainPopup.OnClientEvent:Connect(function(data)
	lastPopupRemoteAt = os.clock()
	local total = type(data) == "table" and tonumber(data.TotalSpeed) or nil
	if total and total == lastFallbackSpeed and os.clock() - lastFallbackAt < 2 then return end
	showSpeedGainBurst(data)
end)
player:GetAttributeChangedSignal("RawSpeed"):Connect(function()
	local current = tonumber(player:GetAttribute("RawSpeed"))
	local previous = previousRawSpeed
	previousRawSpeed = current
	fallbackSerial += 1
	local serial = fallbackSerial
	if player:GetAttribute("DataLoaded") ~= true or not current or not previous or current <= previous then return end
	local observedAt = os.clock()
	task.delay(0.30, function()
		if serial ~= fallbackSerial or lastPopupRemoteAt >= observedAt - 0.10 then return end
		lastFallbackSpeed = current
		lastFallbackAt = os.clock()
		showSpeedGainBurst({
			Amount = current - previous, TotalSpeed = current, BurstCount = 1,
			IsRunningPopup = player:GetAttribute("IsOnTreadmill") ~= true,
			IsBoostingPopup = player:GetAttribute("IsBoosting") == true,
		})
	end)
end)
]=])
  elseif name=='MainHUDController' then
   source=replace(source,'\tlocal displaySpeed = cleanSpeed(explicitSpeed) or cleanSpeed(readSpeedAmount()) or 1',[=[
	local actualSpeed = cleanSpeed(readSpeedAmount()) or 1
	local displaySpeed = cleanSpeed(explicitSpeed) or actualSpeed
	-- Late overlapping impacts cannot rewind the number or undo a rebirth reset.
	displaySpeed = math.min(actualSpeed, math.max(displaySpeed, lastCommittedSpeed or displaySpeed))]=])
  elseif name=='DataStoreAdapter' then
   source=replace(source,'\t\treturn DataStoreAdapter.CreateMock()',[=[
		-- Never make a live session appear durable using an in-memory test store.
		local message = "DataStore initialization failed: " .. tostring(ds)
		local unavailable = {}
		function unavailable:GetAsync(_key: string): StoreResult
			return { ok = false, error = message, isUncertain = false }
		end
		function unavailable:UpdateAsync(_key: string, _transform: any): StoreResult
			return { ok = false, error = message, isUncertain = false }
		end
		return unavailable]=])
  elseif name=='SessionActor' then
   source=replace(source,'\tlocal acquireError: string? = nil','\tlocal acquireError: string? = nil\n\tlocal validationError: any = nil')
   source=replace(source,'\tlocal updateResult = self.storeAdapter:UpdateAsync(self.key, function(current)\n\t\tlocal success, modified, errReason', [=[
	local updateResult = self.storeAdapter:UpdateAsync(self.key, function(current)
		-- Roblox can invoke this callback again after contention. Reset all results.
		leaseAcquired = false
		acquireError = nil
		validationError = nil
		local decoded = ProfileCodec.Decode(current)
		if not decoded.ok then
			validationError = decoded.error
			return nil -- Preserve corrupt/future data verbatim, never replace by defaults.
		end
		local success, modified, errReason]=])
   source=replace(source,'\tif not leaseAcquired then\n\t\tself.state = "Failed"',[=[
	if validationError then
		self.state = "Failed"
		return { ok = false, error = validationError }
	end
	if not leaseAcquired then
		self.state = "Failed"]=])
  elseif name=='Bootstrap' then
   source=replace(source,'\tplayer:SetAttribute(attrName, value)\n\tlocal handle = DataService.GetHandle(player.UserId)\n\tif handle then\n\t\tDataService.SetPreference(handle, attrName, value)\n\tend',[=[
	local allowed = {
		Muted = "boolean", SoundEffects = "boolean", GlobalMessages = "boolean",
		PromptRevivals = "boolean", HideHud = "boolean", HidePopups = "boolean",
		AcceptGifts = "boolean", EventEffects = "boolean",
		MusicVolume = "number", SfxVolume = "number",
	}
	if allowed[attrName] ~= type(value) then return end
	if type(value) == "number" and (value ~= value or math.abs(value) == math.huge) then return end
	local handle = DataService.GetHandle(player.UserId)
	if handle then
		-- SetPreference validates and projects only accepted settings.
		DataService.SetPreference(handle, attrName, value)
	end]=])
   source=replace(source,'\t\tplayer:SetAttribute("DataLoadFailed", true)\n\t\treturn','\t\tplayer:SetAttribute("DataLoadFailed", true)\n\t\tplayer:Kick("Your data could not be loaded safely. Please rejoin in a moment; your saved progress has not been reset.")\n\t\treturn')
  elseif name=='PlayerStatsBridge' then
   source=replace(source,'return flushRes.kind == "Saved" or flushRes.kind == "Skipped" or flushRes.kind == "Pending"','return flushRes.kind == "Saved" or (flushRes.kind == "Skipped" and flushRes.reason == "Clean")')
   source=replace(source,'return commitRes and (commitRes.kind == "Committed" or commitRes.kind == "AlreadyCommitted") or true','return commitRes ~= nil and (commitRes.kind == "Committed" or commitRes.kind == "AlreadyCommitted")')
   source=replace(source,[=[
		if not handle then
			local leaderstats = player and player:FindFirstChild("leaderstats")
			local wins = leaderstats and leaderstats:FindFirstChild("Wins")
			if wins and wins:IsA("IntValue") then
				wins.Value += baseGain
				return true
			end
			return false
		end]=],[=[
		if not handle then return false end
		-- Preserve OG reward semantics: permanent wins bonuses apply to rewards.
		-- Exact purchased grants continue to use SpeedsterGrantExactStat.
		local amount = tonumber(baseGain) or 0
		if amount > 0 then amount *= g.SpeedsterGetPermanentWinsMultiplier(player) end]=])
   source=replace(source,'{ kind = "GrantExact", stat = "Wins", amount = baseGain }','{ kind = "GrantExact", stat = "Wins", amount = amount }')
  end
  local path='audit/patched/'..label..'/'..row.path:gsub('%.','/'):gsub('[<>:"|?*]','_')..'.luau'
  fs.writeDir(path:match('^(.*)/')); fs.writeFile(path,source)
 end
 print('patched',label)
end
