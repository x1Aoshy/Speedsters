-- Update 2: serialized snapshots and retryable, idempotent writes.
local scheduler = if typeof(script) == "Instance" then task else require("@lune/task")
local sequence = 0
local function uniqueId()
	if typeof(script) == "Instance" then return game:GetService("HttpService"):GenerateGUID(false) end
	sequence += 1
	return tostring(os.clock()) .. ":" .. tostring(sequence)
end
local originalNew = SessionActor.new
function SessionActor.new(deps)
	deps = table.clone(deps)
	deps.sessionId = deps.sessionId or uniqueId()
	local actor = originalNew(deps)
	actor.closing = false
	return actor
end

function SessionActor:_resolvePending()
	local pending = self.pendingWrite
	if not pending then return true end
	if self.isEphemeral then
		self.profile = pending.profile
	else
		local lost = false
		local result = self.storeAdapter:UpdateAsync(self.key, function(current)
			lost = false
			-- Confirmation of an earlier applied timeout, including final release.
			if type(current) == "table" and current.Update2WriteId == pending.id then return current end
			if type(current) ~= "table" or current.ActiveSessionId ~= self.sessionId
				or current.Update2WriteId ~= pending.previousId then
				lost = true
				return nil
			end
			local encoded = ProfileCodec.Encode(pending.profile)
			encoded.Update2WriteId = pending.id
			encoded.LastSaveUnix = self.clock.UnixNow()
			encoded.ActiveSessionId = if pending.release then nil else self.sessionId
			encoded.ActiveSessionStartedUnixMs = if pending.release then nil else current.ActiveSessionStartedUnixMs
			encoded.ActiveSessionExpiresUnix = if pending.release then nil else self.clock.UnixNow() + self.leaseDurationSeconds
			return encoded
		end)
		if lost then
			self.state = "Lost"
			self:_notifySubscribers()
			return false, "SessionLost"
		end
		if not result.ok or type(result.value) ~= "table" or result.value.Update2WriteId ~= pending.id then
			self.state = "Recovering"
			self:_notifySubscribers()
			return false, "PersistenceUncertain"
		end
		if not pending.release and result.value.ActiveSessionId ~= self.sessionId then
			self.state = "Lost"
			self:_notifySubscribers()
			return false, "SessionLost"
		end
		self.profile = pending.profile
		self.profile.ActiveSessionId = result.value.ActiveSessionId
		self.profile.ActiveSessionExpiresUnix = result.value.ActiveSessionExpiresUnix
	end
	self.profile.Update2WriteId = pending.id
	self.saveCoordinator:ConfirmDurable(pending.revision)
	if pending.resetCarry then self.speedCarry = 0 end
	self.pendingWrite = nil
	self.leaseExpiresUnix = if pending.release then nil else self.clock.UnixNow() + self.leaseDurationSeconds
	self.state = if pending.release then "Released" elseif self.closing then "Quiescing" else "Ready"
	self:_notifySubscribers()
	return true
end

function SessionActor:_writeSnapshot(profile, release, resetCarry)
	assert(not self.pendingWrite, "Pending write must be resolved first")
	local revision = self.saveCoordinator:AdvanceCurrent()
	self.pendingWrite = {
		id = uniqueId(), previousId = self.profile.Update2WriteId,
		profile = deepCopy(profile), release = release == true,
		resetCarry = resetCarry == true, revision = revision,
	}
	return self:_resolvePending()
end

function SessionActor:Commit(handle, request)
	local err = self:_validateHandle(handle)
	if err then return {kind="Rejected", error=err} end
	if self.state == "Lost" then return {kind="Rejected",error={code="SessionLost",message="Session lost",retryable=false}} end
	if self.pendingWrite then
		local ok = self:_resolvePending()
		if not ok then return {kind="Pending",operationId=request.operationId,retryAfterSeconds=1} end
	end
	if self.closing or self.state ~= "Ready" then return {kind="Rejected",error={code="Closing",message="Session not accepting transactions",retryable=false}} end
	if type(request.operationId) ~= "string" or request.operationId == "" or type(request.fingerprint) ~= "string" then
		return {kind="Rejected",error={code="InvalidInput",message="Operation identity required",retryable=false}}
	end
	local operations = self.profile.Update2Operations or {}
	local existing = operations[request.operationId]
	if request.receiptId and self.profile.ProcessedReceipts[request.receiptId] ~= nil then
		return {kind="AlreadyCommitted",operationId=request.operationId,revision=self.saveCoordinator:GetDurableRevision()}
	end
	if existing then
		if existing.fingerprint ~= request.fingerprint then return {kind="Rejected",error={code="OperationConflict",message="Operation identity conflict",retryable=false}} end
		return {kind="AlreadyCommitted",operationId=request.operationId,revision=self.saveCoordinator:GetDurableRevision()}
	end
	local draft = deepCopy(self.profile)
	local resetCarry = false
	for _,command in ipairs(request.commands) do
		local result = ProfileReducers.ApplyCommand(draft,command,self.clock.UnixNow())
		if not result.ok then return {kind="Rejected",error=result.error} end
		if command.kind == "PerformRebirth" then resetCarry=true end
	end
	draft.Update2Operations = draft.Update2Operations or {}
	draft.Update2Operations[request.operationId] = {fingerprint=request.fingerprint,time=self.clock.UnixNow()}
	-- Normal session operations are bounded. Purchase identities also live in receipts.
	local entries = {}
	for id,entry in pairs(draft.Update2Operations) do table.insert(entries,{id=id,time=entry.time}) end
	table.sort(entries,function(a,b) return a.time > b.time end)
	for i=513,#entries do
		if entries[i].id ~= request.operationId then draft.Update2Operations[entries[i].id]=nil end
	end
	if request.receiptId then draft.ProcessedReceipts[request.receiptId]=self.clock.UnixNow() end
	local ok = self:_writeSnapshot(draft,false,resetCarry)
	if not ok then return {kind="Pending",operationId=request.operationId,retryAfterSeconds=1} end
	return {kind="Committed",operationId=request.operationId,revision=self.saveCoordinator:GetDurableRevision()}
end

function SessionActor:Flush(handle, targetRevision, deadlineMono)
	local err=self:_validateHandle(handle)
	if err then return {kind="Failed",error=err} end
	if self.state=="Lost" then return {kind="Failed",error={code="SessionLost",message="Session lost",retryable=false}} end
	if self.pendingWrite and not self:_resolvePending() then return {kind="Pending",targetRevision=self.saveCoordinator:GetCurrentRevision()} end
	if self.state=="Released" or self.state=="Closed" then return {kind="Skipped",reason="Released"} end
	if not self.profile then return {kind="Failed",error={code="NotReady",message="No loaded profile",retryable=true}} end
	if self.saveCoordinator:GetDurableRevision()>=self.saveCoordinator:GetCurrentRevision()
		and (self.leaseExpiresUnix or 0)-self.clock.UnixNow()>self.leaseDurationSeconds/2 then
		return {kind="Saved",durableRevision=self.saveCoordinator:GetDurableRevision()}
	end
	local ok=self:_writeSnapshot(self.profile,false,false)
	if not ok then return {kind="Pending",targetRevision=self.saveCoordinator:GetCurrentRevision()} end
	return {kind="Saved",durableRevision=self.saveCoordinator:GetDurableRevision()}
end

function SessionActor:Quiesce(handle, reason)
	local err=self:_validateHandle(handle)
	if err then return {ok=false,error=err} end
	self.closing=true
	if self.state=="Loading" then self.quiesceRequestedDuringLoading=true
	elseif self.state=="Ready" then self.state="Quiescing" end
	return {ok=true,value=self.saveCoordinator:GetCurrentRevision()}
end

function SessionActor:Release(handle, deadlineMono)
	local err=self:_validateHandle(handle)
	if err then return {kind="Failed",error=err} end
	self.closing=true
	if self.state=="Lost" then return {kind="Failed",error={code="SessionLost",message="Session lost",retryable=false}} end
	if self.pendingWrite and not self:_resolvePending() then return {kind="Failed",error={code="PersistenceUncertain",message="Final save awaiting confirmation",retryable=true}} end
	if self.state=="Released" or self.state=="Closed" then return {kind="AlreadyReleased",durableRevision=self.saveCoordinator:GetDurableRevision()} end
	if not self.profile then return {kind="Failed",error={code="NotReady",message="Load not complete",retryable=true}} end
	local ok=self:_writeSnapshot(self.profile,true,false)
	if not ok then return {kind="Failed",error={code="PersistenceUncertain",message="Final save awaiting confirmation",retryable=true}} end
	return {kind="Released",durableRevision=self.saveCoordinator:GetDurableRevision()}
end

-- Notifications run after the critical section; subscribers cannot reenter a draft.
local originalNotify=SessionActor._notifySubscribers
function SessionActor:_notifySubscribers()
	if self.mutationOwner then self.notificationPending=true else originalNotify(self) end
end
for _,methodName in ipairs({"Open","Commit","SetPreference","SetDailyLoginState","AccrueSpeed","Flush","Quiesce","Release"}) do
	local implementation=SessionActor[methodName]
	SessionActor[methodName]=function(self,...)
		while self.mutationOwner do scheduler.wait() end
		self.mutationOwner=true
		local result=table.pack(pcall(implementation,self,...))
		self.mutationOwner=nil
		if self.notificationPending then
			self.notificationPending=false
			originalNotify(self)
		end
		if not result[1] then error(result[2],0) end
		return table.unpack(result,2,result.n)
	end
end
