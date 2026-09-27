                                                                            
                                                                             
                                                                                
                                                                            

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
if Config.IsNewWorld1Map ~= true then
	return
end

local OBSOLETE_CLIENT_CONTROLLERS = {
	                                                                                
	                                                        
	World1ClientMotionHazards = true,
	RotatingLaserVisual = true,
	RedBallContact = true,

	                                                                          
	                                                                             
	                                     
	NewWorld1TrussClimb = true,
	AudioCheckV99 = true,
	AudioCheckV102 = true,
	BossAreaAmbience = true,
	LevelProgressBar = true,
}

local playerScripts = script.Parent
local function removeIfObsolete(object)
	if object ~= script
		and object:IsA("LocalScript")
		and OBSOLETE_CLIENT_CONTROLLERS[object.Name]
	then
		object.Disabled = true
		object:Destroy()
		return true
	end
	return false
end

local removed = 0
for _, object in ipairs(playerScripts:GetChildren()) do
	if removeIfObsolete(object) then
		removed += 1
	end
end

playerScripts.ChildAdded:Connect(function(object)
	task.defer(removeIfObsolete, object)
end)

print("[NewWorld1LegacyClientCleanup] V306KBY removed obsolete local obstacle controllers=" .. tostring(removed))
