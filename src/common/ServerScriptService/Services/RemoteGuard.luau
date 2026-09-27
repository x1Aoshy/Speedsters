-- One in-flight invocation per player and remote; keys are server-owned remotes.
-- onDropped (optional, 2026-09-22): a call refused because the player's previous one is still
-- running or inside `interval` is answered instead of lost. onDropped(player, ...) runs once
-- per burst of refused calls, with the last refused call's arguments, after the running call
-- has finished and its interval has ended, and not at all when a newer accepted call (which
-- answers for itself) came first. onDropped itself runs under the guard (busy, then its own
-- interval), so it may do the refused call's work. Without onDropped a refused call is
-- ignored exactly as before.
local RemoteGuard = {}

function RemoteGuard.Connect(remote, interval, handler, onDropped)
	local state=setmetatable({}, {__mode="k"})
	local function answerDropped(player, entry)
		if entry.answerQueued or entry.busy or not entry.dropped then return end
		entry.answerQueued=true
		task.delay(math.max(0, entry.nextAt-os.clock()), function()
			entry.answerQueued=false
			if entry.busy or not entry.dropped then return end
			entry.dropped=false
			local args=entry.droppedArgs
			entry.droppedArgs=nil
			if state[player]~=entry or player.Parent==nil then return end
			-- The answer runs under the guard like an accepted call, so calls refused while it
			-- runs (or inside its interval) are coalesced again and spam stays limited.
			local answer={busy=true,nextAt=os.clock()+interval}
			state[player]=answer
			local ok,message=pcall(onDropped,player,table.unpack(args,1,args.n))
			answer.busy=false
			if not ok then warn("[RemoteGuard] "..remote.Name.." (dropped answer): "..tostring(message)) end
			if answer.dropped then answerDropped(player, answer) end
		end)
	end
	return remote.OnServerEvent:Connect(function(player,...)
		local now=os.clock()
		local previous=state[player]
		if previous and (previous.busy or now<previous.nextAt) then
			if onDropped then
				previous.dropped=true
				previous.droppedArgs=table.pack(...)
				answerDropped(player, previous)
			end
			return
		end
		local entry={busy=true,nextAt=now+interval}
		state[player]=entry
		local ok,message=pcall(handler,player,...)
		entry.busy=false
		if not ok then warn("[RemoteGuard] "..remote.Name..": "..tostring(message)) end
		if entry.dropped then answerDropped(player, entry) end
	end)
end

return RemoteGuard
