-- One in-flight invocation per player and remote; keys are server-owned remotes.
local RemoteGuard = {}

function RemoteGuard.Connect(remote, interval, handler)
	local state=setmetatable({}, {__mode="k"})
	return remote.OnServerEvent:Connect(function(player,...)
		local now=os.clock()
		local previous=state[player]
		if previous and (previous.busy or now<previous.nextAt) then return end
		local entry={busy=true,nextAt=now+interval}
		state[player]=entry
		local ok,message=pcall(handler,player,...)
		entry.busy=false
		if not ok then warn("[RemoteGuard] "..remote.Name..": "..tostring(message)) end
	end)
end

return RemoteGuard
