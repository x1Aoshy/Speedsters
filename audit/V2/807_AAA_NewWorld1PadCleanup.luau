                                   
  
                                                                              
                                                                              
                                                                             
                                                                  

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
	-- Legitimate markers that carry reward configuration or manual pad marker attributes must be preserved
	if object:GetAttribute("WinReward") ~= nil
		or object:GetAttribute("BaseWinReward") ~= nil
		or object:GetAttribute("NewWorld1ManualPadMarker") == true
		or object:GetAttribute("ManualCFrameAuthoritative") == true
	then
		return false
	end

	local name = normalizeName(object.Name)
	if name == "winhere" or name == "x2here" then
		return true
	end
	if name:find("winpad", 1, true) or name:find("skipstagepad", 1, true) then
		return true
	end
	if object:GetAttribute("WinStagePad") == true
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

-- Fix rogue humanoids directly under Workspace (like Workspace.ColdBloodedKiller) to prevent engine warnings
for _, child in ipairs(Workspace:GetChildren()) do
	if child:IsA("Humanoid") then
		local container = Instance.new("Model")
		container.Name = child.Name .. "_Model"
		container.Parent = Workspace
		child.Parent = container
	end
end

-- Clean up broken free-model asset loader scripts under world 2 portal
local portal = Workspace:FindFirstChild("Folder") and Workspace.Folder:FindFirstChild("world 2 portal")
if portal then
	for _, desc in ipairs(portal:GetDescendants()) do
		if desc.Name == "PoseTexture" or desc.Name == "TextureConfiguration" then
			if desc:IsA("BaseScript") then
				desc.Disabled = true
			end
			pcall(function() desc:Destroy() end)
		end
	end
end

-- Fix Admin.Rainbow script so it cannot error even in currently open Studio sessions
local function fixAdminRainbow()
	local admin = Workspace:FindFirstChild("neworld1") and Workspace.neworld1:FindFirstChild("Admin")
	if admin then
		local rainbow = admin:FindFirstChild("Rainbow")
		if rainbow and rainbow:IsA("BaseScript") then
			rainbow.Disabled = true
			pcall(function() rainbow:Destroy() end)
		end
		local TweenService = game:GetService("TweenService")
		local parts = {}
		for _, desc in ipairs(admin:GetDescendants()) do
			if desc:IsA("BasePart") then
				table.insert(parts, desc)
			end
		end
		if #parts > 0 then
			local colors = {
				Color3.fromRGB(255, 0, 0),
				Color3.fromRGB(255, 155, 0),
				Color3.fromRGB(255, 255, 0),
				Color3.fromRGB(0, 255, 0),
				Color3.fromRGB(0, 255, 255),
				Color3.fromRGB(0, 155, 255),
				Color3.fromRGB(255, 0, 255),
				Color3.fromRGB(255, 0, 155),
			}
			local tweenInfo = TweenInfo.new(1, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut)
			task.spawn(function()
				while admin.Parent do
					for _, color in ipairs(colors) do
						for _, part in ipairs(parts) do
							TweenService:Create(part, tweenInfo, { Color = color }):Play()
						end
						task.wait(0.5)
					end
				end
			end)
		end
	end
end
task.spawn(fixAdminRainbow)

print("[NewWorld1PadCleanup] V306KBF active | new World 1 Win/2x/Skip/WinStage pads removed and blocked")
