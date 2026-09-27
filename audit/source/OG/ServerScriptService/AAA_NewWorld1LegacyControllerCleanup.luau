                                                                                     
                                                                             
                                                                    

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
if Config.IsNewWorld1Map ~= true then
	return
end

local OBSOLETE_SERVER_CONTROLLERS = {
	                                                            
	World1ClientHazardAuthority = true,

	                                                                           
	                                                      
	TogetherController = true,
	Press1Press2Controller = true,
	Presser1Controller = true,
	UpDownController = true,
	RotatingLaser = true,
	StageDecor = true,
	WinPadStagePlacement = true,
	SpeedsterDebugVerifier = true,
	SpawnOutlineCheckerCleanup = true,
	AAA_DuplicateMapAndWaterFix = true,
	RestoreMissingWaterModels = true,
	WaterLayerAlignmentAndWater1Kill = true,
	WaterRestoreOldMapTemplate = true,
	RemoveOldStartingBuild = true,
}

local function disableIfObsolete(object)
	if object:IsA("Script") and OBSOLETE_SERVER_CONTROLLERS[object.Name] then
		object.Disabled = true
		object:SetAttribute("DisabledForNewWorld1V306KBY", true)
		return true
	end
	return false
end

local disabled = 0
for _, object in ipairs(ServerScriptService:GetChildren()) do
	if object ~= script and disableIfObsolete(object) then
		disabled += 1
	end
end

ServerScriptService.ChildAdded:Connect(function(object)
	if object ~= script then
		task.defer(disableIfObsolete, object)
	end
end)

print("[NewWorld1LegacyControllerCleanup] V306KBY disabled obsolete server controllers=" .. tostring(disabled))
