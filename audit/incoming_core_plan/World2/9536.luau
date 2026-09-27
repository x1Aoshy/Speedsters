                                                                     
  
                                                                            
                                                                               
                                                                              
                                                                            
                                                                          
                                                                           

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
if Config.IsWorld2Place ~= true then
	return
end

local TREE_COUNT = 6
local SAFE_ZONE_ATTRIBUTE = "SafeZoneProtected"
local REMOTE_NAME = "World2TreeSlamSelfHit"
local ACTIVE_DISTANCE = 105
local VERSION = "V306IIWorld2TreeExactClientHit"

local hitRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild(REMOTE_NAME)

local function normalizeName(value)
	return tostring(value or ""):lower():gsub("[^%w]", "")
end

local function objectDepth(object)
	local depth = 0
	local current = object
	while current and current.Parent and current.Parent ~= Workspace do
		depth += 1
		current = current.Parent
	end
	return depth
end

local function treeIndexFromName(name)
	local index = tonumber(normalizeName(name):match("^tree(%d+)$"))
	if index and index >= 1 and index <= TREE_COUNT then
		return index
	end
	return nil
end

local function isTreeObject(object)
	return object and (object:IsA("BasePart") or object:IsA("Model"))
end

local function isVisibleTreePart(part)
	return part:IsA("BasePart") and part.Transparency < 0.95
end

local function getPhysicalParts(object)
	local parts = {}
	if object:IsA("BasePart") then
		if isVisibleTreePart(object) then
			table.insert(parts, object)
		end
	else
		for _, descendant in ipairs(object:GetDescendants()) do
			if isVisibleTreePart(descendant) then
				table.insert(parts, descendant)
			end
		end
	end
	return parts
end

local function getBoundsPosition(object)
	if object:IsA("BasePart") then
		return object.Position
	end
	local ok, cf = pcall(function()
		return object:GetBoundingBox()
	end)
	if ok and cf then
		return cf.Position
	end
	return nil
end

local treeObjects = {}
local treeParts = {}
local treePartToIndex = setmetatable({}, { __mode = "k" })
local allTreeParts = {}
local treeBasePositions = {}

local function chooseTreeObject(object)
	if not isTreeObject(object) then
		return nil
	end
	local index = treeIndexFromName(object.Name)
	if not index then
		return nil
	end
	local old = treeObjects[index]
	if not old or not old.Parent or objectDepth(object) < objectDepth(old) then
		treeObjects[index] = object
		return index
	end
	return nil
end

local function rebuildTreePartCache()
	treeParts = {}
	treePartToIndex = setmetatable({}, { __mode = "k" })
	allTreeParts = {}
	for index = 1, TREE_COUNT do
		local tree = treeObjects[index]
		if tree and tree.Parent then
			treeBasePositions[index] = getBoundsPosition(tree)
			local parts = getPhysicalParts(tree)
			treeParts[index] = parts
			for _, part in ipairs(parts) do
				if part.Parent then
					treePartToIndex[part] = index
					table.insert(allTreeParts, part)
				end
			end
		end
	end
end

for _, object in ipairs(Workspace:GetDescendants()) do
	chooseTreeObject(object)
end
rebuildTreePartCache()

local treeOverlap = OverlapParams.new()
treeOverlap.FilterType = Enum.RaycastFilterType.Include
treeOverlap.RespectCanCollide = false
treeOverlap.MaxParts = 20

local character = nil
local humanoid = nil
local rootPart = nil
local characterParts = {}

local BODY_PART_NAMES = {
	Head = true,
	Torso = true,
	UpperTorso = true,
	LowerTorso = true,
	["Left Arm"] = true,
	["Right Arm"] = true,
	["Left Leg"] = true,
	["Right Leg"] = true,
	LeftUpperArm = true,
	LeftLowerArm = true,
	LeftHand = true,
	RightUpperArm = true,
	RightLowerArm = true,
	RightHand = true,
	LeftUpperLeg = true,
	LeftLowerLeg = true,
	LeftFoot = true,
	RightUpperLeg = true,
	RightLowerLeg = true,
	RightFoot = true,
}
local locallyKilledCharacter = nil
local characterConnections = {}

local function rebuildCharacterParts()
	characterParts = {}
	if not character then
		return
	end
	for _, descendant in ipairs(character:GetChildren()) do
		if descendant:IsA("BasePart") and BODY_PART_NAMES[descendant.Name] == true then
			table.insert(characterParts, descendant)
		end
	end
end

local function refreshCharacter(newCharacter)
	for _, connection in ipairs(characterConnections) do connection:Disconnect() end
	table.clear(characterConnections)
	character = newCharacter
	humanoid = character and character:FindFirstChildOfClass("Humanoid")
	rootPart = character and character:FindFirstChild("HumanoidRootPart")
	locallyKilledCharacter = nil
	rebuildCharacterParts()
	if character then
		table.insert(characterConnections, character.ChildAdded:Connect(function(descendant)
			if descendant:IsA("BasePart") and BODY_PART_NAMES[descendant.Name] == true then
				table.insert(characterParts, descendant)
			elseif descendant:IsA("Humanoid") then
				humanoid = descendant
			end
			if descendant.Name == "HumanoidRootPart" and descendant:IsA("BasePart") then
				rootPart = descendant
			end
		end))
		table.insert(characterConnections, character.ChildRemoved:Connect(function(descendant)
			if descendant:IsA("BasePart") and BODY_PART_NAMES[descendant.Name] == true then
				for i = #characterParts, 1, -1 do
					if characterParts[i] == descendant then
						table.remove(characterParts, i)
						break
					end
				end
			end
		end))
	end
end

player.CharacterAdded:Connect(refreshCharacter)
refreshCharacter(player.Character)

local function isLocallySafe()
	if not character then
		return false
	end
	return player:GetAttribute("StageTeleportInvulnerable") == true
		or player:GetAttribute(SAFE_ZONE_ATTRIBUTE) == true
		or character:GetAttribute(SAFE_ZONE_ATTRIBUTE) == true
		or character:FindFirstChild("VortexSafeZoneForceField") ~= nil
end

local function localKill(treeIndex)
	if not character or not humanoid or humanoid.Health <= 0 or locallyKilledCharacter == character then
		return
	end
	if isLocallySafe() then
		return
	end
	locallyKilledCharacter = character

	                                                                            
	                                                                         
	humanoid.Health = 0
	pcall(function()
		humanoid:ChangeState(Enum.HumanoidStateType.Dead)
	end)

	                                                               
	hitRemote:FireServer(treeIndex)
end

local function nearestTreeDistance()
	if not rootPart then
		return math.huge
	end
	local rootPos = rootPart.Position
	local best = math.huge
	for index = 1, TREE_COUNT do
		local pos = treeBasePositions[index]
		if pos then
			local dist = (rootPos - pos).Magnitude
			if dist < best then
				best = dist
			end
		end
	end
	return best
end

local function detectTreeContact()
	if not character or not humanoid or humanoid.Health <= 0 or not rootPart or not rootPart.Parent then
		return
	end
	if isLocallySafe() or nearestTreeDistance() > ACTIVE_DISTANCE then
		return
	end

	                                                                               
	                                                                                 
	                                                                             
	                                                                            
	                                                                            
	                                                                 
	local validTreeParts = {}
	for _, part in ipairs(allTreeParts) do
		if part and part.Parent then
			table.insert(validTreeParts, part)
		end
	end
	if #validTreeParts == 0 then
		return
	end
	treeOverlap.FilterDescendantsInstances = validTreeParts

	for _, bodyPart in ipairs(characterParts) do
		if bodyPart and bodyPart.Parent == character then
			local contacts = Workspace:GetPartsInPart(bodyPart, treeOverlap)
			if #contacts > 0 then
				local treeIndex = treePartToIndex[contacts[1]] or 1
				localKill(treeIndex)
				return
			end
		end
	end
end

RunService.RenderStepped:Connect(detectTreeContact)

Workspace.DescendantAdded:Connect(function(object)
	local index = chooseTreeObject(object)
	if index then
		task.defer(function()
			if object.Parent then
				rebuildTreePartCache()
			end
		end)
	elseif object:IsA("BasePart") then
		for treeIndex = 1, TREE_COUNT do
			local tree = treeObjects[treeIndex]
			if tree and object:IsDescendantOf(tree) then
				task.defer(rebuildTreePartCache)
				break
			end
		end
	end
end)

Workspace.DescendantRemoving:Connect(function(object)
	if treePartToIndex[object] or treeIndexFromName(object.Name) then
		task.defer(rebuildTreePartCache)
	end
end)

print(
	"[World2TreeSlammers] " .. VERSION
		.. " active | exact Tree1..Tree6 part-volume contact checked locally every RenderStepped"
		.. " | avatar body parts only | no padding | immediate local death | WORLD 2 ONLY"
)
