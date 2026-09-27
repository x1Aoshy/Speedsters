                       
                                                                  
                                                                                         

local Workspace = game:GetService("Workspace")

local EXACT_NAMES = {
	WallyWest = true,
	WallyWest_BlackFlashSpawnMarker = true,
}

local function shouldRemove(instance)
	if EXACT_NAMES[instance.Name] then
		return true
	end

	if instance:GetAttribute("WallyWestBoss") == true
		or instance:GetAttribute("BlackFlashBoss") == true
		or instance:GetAttribute("WallyWestRuntimeBoss") == true then
		return true
	end

	return false
end

for _, instance in ipairs(Workspace:GetChildren()) do
	if shouldRemove(instance) then
		instance:Destroy()
	end
end

Workspace.ChildAdded:Connect(function(instance)
	if shouldRemove(instance) then
		task.defer(function()
			if instance.Parent then
				instance:Destroy()
			end
		end)
	end
end)

print("[RemoveWallyWestBoss] V306ET removed old Wally/Black Flash boss remnants; no boss system is active.")
