                                       
  
                                                                               
                   
                                  
  
                                                                              
                                                                           
                                                                             
                                                                                
                                                                                 
                                                                               
  
                                                                                 
                                                                          

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
if Config.IsWorld2Place ~= true then
	return
end

local RUNTIME_FOLDER_NAME = "World2WallFlightBarriers_Runtime"
local BARRIER_HEIGHT = 777
local HORIZONTAL_PADDING = 0.75
local BOTTOM_OVERLAP = 0.20
local VERSION = "V306JBWorld2WallFlightBarriers"

local runtimeFolder = Workspace:FindFirstChild(RUNTIME_FOLDER_NAME)
if runtimeFolder and not runtimeFolder:IsA("Folder") then
	runtimeFolder:Destroy()
	runtimeFolder = nil
end
if not runtimeFolder then
	runtimeFolder = Instance.new("Folder")
	runtimeFolder.Name = RUNTIME_FOLDER_NAME
	runtimeFolder.Parent = Workspace
end
runtimeFolder:SetAttribute("WorldNumber", 2)
runtimeFolder:SetAttribute("Version", VERSION)
for _, child in ipairs(runtimeFolder:GetChildren()) do
	child:Destroy()
end

local wallToBarrier = setmetatable({}, { __mode = "k" })

local function normalizeName(value)
	return tostring(value or ""):lower():gsub("[^%w]", "")
end

local function isPhysicalContainer(instance)
	return instance and (instance:IsA("Model") or instance:IsA("BasePart"))
end

local function collectPhysicalParts(object)
	local parts = {}
	if object:IsA("BasePart") then
		parts[1] = object
		return parts
	end
	for _, descendant in ipairs(object:GetDescendants()) do
		if descendant:IsA("BasePart") then
			parts[#parts + 1] = descendant
		end
	end
	return parts
end

local function partWorldAABB(part)
	local half = part.Size * 0.5
	local cf = part.CFrame
	local ex = math.abs(cf.RightVector.X) * half.X
		+ math.abs(cf.UpVector.X) * half.Y
		+ math.abs(cf.LookVector.X) * half.Z
	local ey = math.abs(cf.RightVector.Y) * half.X
		+ math.abs(cf.UpVector.Y) * half.Y
		+ math.abs(cf.LookVector.Y) * half.Z
	local ez = math.abs(cf.RightVector.Z) * half.X
		+ math.abs(cf.UpVector.Z) * half.Y
		+ math.abs(cf.LookVector.Z) * half.Z
	local extent = Vector3.new(ex, ey, ez)
	return cf.Position - extent, cf.Position + extent
end

local function getWorldAABB(object)
	local parts = collectPhysicalParts(object)
	if #parts == 0 then
		return nil, nil
	end

	local minimum = Vector3.new(math.huge, math.huge, math.huge)
	local maximum = Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, part in ipairs(parts) do
		local pmin, pmax = partWorldAABB(part)
		minimum = Vector3.new(
			math.min(minimum.X, pmin.X),
			math.min(minimum.Y, pmin.Y),
			math.min(minimum.Z, pmin.Z)
		)
		maximum = Vector3.new(
			math.max(maximum.X, pmax.X),
			math.max(maximum.Y, pmax.Y),
			math.max(maximum.Z, pmax.Z)
		)
	end
	return minimum, maximum
end

local function horizontalArea(object)
	local minimum, maximum = getWorldAABB(object)
	if not minimum then
		return 0
	end
	local size = maximum - minimum
	return math.max(0, size.X) * math.max(0, size.Z)
end

local function getWallBody(candidate)
	if not candidate or not candidate:IsA("Model") or not candidate.Parent then
		return nil
	end

	local rockCount = 0
	local treeCount = 0
	local bodies = {}

	for _, child in ipairs(candidate:GetChildren()) do
		local normalized = normalizeName(child.Name)
		if normalized == "model" and isPhysicalContainer(child) then
			bodies[#bodies + 1] = child
		elseif normalized == "rock" then
			rockCount += 1
		elseif normalized == "tree" then
			treeCount += 1
		end
	end

	                                                                               
	                                                                       
	if #bodies < 1 or rockCount < 2 or treeCount < 2 then
		return nil
	end

	                                                                          
	                                                                             
	                                                                
	table.sort(bodies, function(left, right)
		local leftArea = horizontalArea(left)
		local rightArea = horizontalArea(right)
		if leftArea == rightArea then
			return left:GetFullName() < right:GetFullName()
		end
		return leftArea > rightArea
	end)
	return bodies[1]
end

local function destroyBarrier(wall)
	local barrier = wallToBarrier[wall]
	wallToBarrier[wall] = nil
	if barrier and barrier.Parent then
		barrier:Destroy()
	end
end

local function createOrRefreshBarrier(wall)
	local body = getWallBody(wall)
	if not body then
		destroyBarrier(wall)
		return false
	end

	local minimum, maximum = getWorldAABB(body)
	if not minimum or not maximum then
		destroyBarrier(wall)
		return false
	end

	local width = math.max(0.5, maximum.X - minimum.X + HORIZONTAL_PADDING)
	local depth = math.max(0.5, maximum.Z - minimum.Z + HORIZONTAL_PADDING)
	local topY = maximum.Y
	local center = Vector3.new(
		(minimum.X + maximum.X) * 0.5,
		topY + BARRIER_HEIGHT * 0.5 - BOTTOM_OVERLAP,
		(minimum.Z + maximum.Z) * 0.5
	)

	local barrier = wallToBarrier[wall]
	if not barrier or not barrier.Parent then
		barrier = Instance.new("Part")
		barrier.Name = "WallFlightBarrier"
		barrier.Anchored = true
		barrier.CanCollide = true
		barrier.CanTouch = false
		barrier.CanQuery = true
		barrier.CastShadow = false
		barrier.Transparency = 1
		barrier.Material = Enum.Material.SmoothPlastic
		barrier:SetAttribute("WorldNumber", 2)
		barrier:SetAttribute("World2WallFlightBarrier", true)
		barrier:SetAttribute("SourceWallName", wall.Name)
		barrier.Parent = runtimeFolder
		wallToBarrier[wall] = barrier
	end

	barrier.Size = Vector3.new(width, BARRIER_HEIGHT, depth)
	barrier.CFrame = CFrame.new(center)
	return true
end

local function refreshAncestorWalls(instance)
	local current = instance
	while current and current ~= Workspace do
		-- A character (or any rig) is never a wall: its children scan ran once per added limb,
		-- accessory and effect, on every respawn of every player.
		if current:IsA("Model") and not current:FindFirstChildOfClass("Humanoid") then
			createOrRefreshBarrier(current)
		end
		current = current.Parent
	end
end

local startupCount = 0
for _, instance in ipairs(Workspace:GetDescendants()) do
	if instance:IsA("Model") and getWallBody(instance) then
		if createOrRefreshBarrier(instance) then
			startupCount += 1
		end
	end
end

Workspace.DescendantAdded:Connect(function(instance)
	                                                                           
	                                                                         
	task.defer(refreshAncestorWalls, instance)
end)

Workspace.DescendantRemoving:Connect(function(instance)
	if wallToBarrier[instance] then
		destroyBarrier(instance)
		return
	end

	local parent = instance.Parent
	if parent then
		task.defer(function()
			if parent.Parent then
				refreshAncestorWalls(parent)
			end
		end)
	end
end)

print(
	"[World2WallFlightBarriers] " .. VERSION
		.. " active | matched walls=" .. tostring(startupCount)
		.. " | height=" .. tostring(BARRIER_HEIGHT)
		.. " | world-AABB coverage"
)
