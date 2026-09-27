                                   
  
                                                                              
                                                                              
                                                                             
                                                                  

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
if Config.IsNewWorld1Map ~= true then
	return
end

local MAP_ROOT_NAME = tostring(Config.NewWorld1MapMarkerName or "neworld1")
local mapRoot = Workspace:FindFirstChild(MAP_ROOT_NAME) or Workspace:WaitForChild(MAP_ROOT_NAME, 20)
if not mapRoot then
	warn("[NewWorld1PadCleanup] Workspace." .. MAP_ROOT_NAME .. " is missing")
	return
end

local ROOT_PAD_FOLDERS = {
	WinPads_TO_PLACE = true,
	WinStageMarkerPads = true,
}

local function normalizeName(value)
	return tostring(value or ""):lower():gsub("[^%w]", "")
end

local function isKnownPadObject(object)
	local name = normalizeName(object.Name)
	if name == "winhere" or name == "x2here" then
		return true
	end
	if name:find("winpad", 1, true) or name:find("skipstagepad", 1, true) then
		return true
	end
	if object:GetAttribute("WinStagePad") == true
		or object:GetAttribute("WinReward") ~= nil
		or object:GetAttribute("FutureRobuxProduct") == true
		or object:GetAttribute("SkipStageProductId") ~= nil
	then
		return true
	end
	return false
end

local function removeRootPadFolder(object)
	if object and object.Parent == Workspace and ROOT_PAD_FOLDERS[object.Name] then
		object:Destroy()
		return true
	end
	return false
end

for _, child in ipairs(Workspace:GetChildren()) do
	removeRootPadFolder(child)
end

                                                                        
                                                                                
local startup = mapRoot:GetDescendants()
for index = #startup, 1, -1 do
	local object = startup[index]
	if object.Parent and isKnownPadObject(object) then
		object:Destroy()
	end
end
table.clear(startup)

Workspace.ChildAdded:Connect(function(object)
	if ROOT_PAD_FOLDERS[object.Name] then
		task.defer(function()
			if object.Parent == Workspace then
				object:Destroy()
			end
		end)
	end
end)

mapRoot.DescendantAdded:Connect(function(object)
	if isKnownPadObject(object) then
		task.defer(function()
			if object.Parent and object:IsDescendantOf(mapRoot) and isKnownPadObject(object) then
				object:Destroy()
			end
		end)
	end
end)

mapRoot:SetAttribute("NewWorld1PadsDisabledVersion", "V306KBF")
print("[NewWorld1PadCleanup] V306KBF active | new World 1 Win/2x/Skip/WinStage pads removed and blocked")
