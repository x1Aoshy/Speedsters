                                                                   
                                                                              
                                                                              
                                                                  
                                                                                  

local Workspace = game:GetService("Workspace")

local OLD_OVERLAY_NAME = "V262GreenCheckerOverlay"
local OLD_VERSION_ATTRIBUTE = "GreenCheckerVersion"
local OLD_TILE_ATTRIBUTE = "GreenCheckerTileStuds"

local function removeOldChecker(instance)
	if instance.Name == OLD_OVERLAY_NAME then
		instance:Destroy()
		return
	end

	if instance:IsA("BasePart") then
		instance:SetAttribute(OLD_VERSION_ATTRIBUTE, nil)
		instance:SetAttribute(OLD_TILE_ATTRIBUTE, nil)
	end
end

                                                                          
for _, descendant in ipairs(Workspace:GetDescendants()) do
	removeOldChecker(descendant)
end

                                                                                 
                                                                                         
Workspace.DescendantAdded:Connect(function(descendant)
	if descendant.Name == OLD_OVERLAY_NAME then
		task.defer(function()
			if descendant.Parent then
				descendant:Destroy()
			end
		end)
	end
end)

print("[SpawnOutlineChecker] V265 old checker generator replaced; original Spawn1Outline appearance preserved")
