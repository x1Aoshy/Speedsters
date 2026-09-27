        
                                                        
                                                                                                     

local ServerScriptService = game:GetService("ServerScriptService")

local OLD_CONFLICT_SCRIPTS = {
	GameServer = true,
	SpeedsterServer = true,
}

local function disableOldConflicts()
	for name in pairs(OLD_CONFLICT_SCRIPTS) do
		local old = ServerScriptService:FindFirstChild(name)

		if old and old ~= script and old:IsA("LuaSourceContainer") then
			warn("[V165 Cleanup] Disabling old conflicting script: " .. old:GetFullName())

			pcall(function()
				old.Enabled = false
			end)

			pcall(function()
				old.Disabled = true
			end)

			pcall(function()
				old:Destroy()
			end)
		end
	end
end

disableOldConflicts()

ServerScriptService.ChildAdded:Connect(function(child)
	if OLD_CONFLICT_SCRIPTS[child.Name] == true and child:IsA("LuaSourceContainer") then
		task.defer(disableOldConflicts)
	end
end)

task.delay(0.25, disableOldConflicts)
task.delay(1, disableOldConflicts)
task.delay(3, disableOldConflicts)

print("[V165 Cleanup] Loaded. Old GameServer/SpeedsterServer conflicts will be disabled/removed in Play mode.")
