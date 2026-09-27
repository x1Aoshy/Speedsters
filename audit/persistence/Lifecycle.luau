local lifecycleTask=if typeof(script)=="Instance" then task else require("@lune/task")
local function handleFor(actor)
	return {userId=actor.userId,sessionId=actor.sessionId,generation=actor.generation}
end
function DataService.GetHandle(target)
	local actor=actorsByUserId[extractUserId(target)]
	if actor and actor.profile and actor.state~="Lost" and actor.state~="Released" and actor.state~="Closed" then return handleFor(actor) end
	return nil
end
function DataService.Release(target,deadlineMono)
	local uid=extractUserId(target)
	local actor=uid and actorsByUserId[uid]
	if not actor then return {kind="AlreadyReleased",durableRevision=0} end
	local handle=if type(target)=="table" and target.sessionId then target else handleFor(actor)
	local deadline=deadlineMono or os.clock()+25
	local result
	for attempt=1,4 do
		result=actor:Release(handle,deadline)
		if result.kind=="Released" or result.kind=="AlreadyReleased" then
			if actorsByUserId[uid]==actor then actorsByUserId[uid]=nil end
			actor:Destroy()
			return result
		end
		if result.error and result.error.retryable==false then break end
		if os.clock()+attempt>=deadline then break end
		lifecycleTask.wait(attempt)
	end
	-- Keep the snapshot available for a later retry; do not erase unconfirmed data.
	return result
end
function DataService.Shutdown(deadlineMono)
	local deadline=deadlineMono or os.clock()+25
	local results={};local remaining=0
	for uid,actor in pairs(actorsByUserId) do
		remaining+=1
		actor.closing=true
		lifecycleTask.spawn(function()
			local ok,result=pcall(DataService.Release,handleFor(actor),deadline)
			results[uid]=if ok then result else {kind="Failed",error={message=tostring(result)}}
			remaining-=1
		end)
	end
	while remaining>0 and os.clock()<deadline do lifecycleTask.wait(0.05) end
	return results
end
function DataService.ResumeAfterFailedTeleport(handle,deadlineMono)
	local actor=actorsByUserId[handle.userId]
	if actor then
		if actor.state=="Ready" and not actor.closing then return {ok=true,value=handleFor(actor)} end
		local released=DataService.Release(handle,deadlineMono)
		if released.kind~="Released" and released.kind~="AlreadyReleased" then return {ok=false,error=released.error} end
	end
	return DataService.Open(handle.userId,deadlineMono)
end
