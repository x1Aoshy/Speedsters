                                                                     
  
                                                                            
                                                                               
                                                                              
                                                                            
                                                                          
                                                                           

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
local TreeSlamMotion = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TreeSlamMotion"))

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

local rebuildMotionCache

local function rebuildTreePartCache()
	table.clear(treeBasePositions) -- Discard positions of streamed-out/destroyed trees.
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
	if rebuildMotionCache then
		rebuildMotionCache()
	end
end

for _, object in ipairs(Workspace:GetDescendants()) do
	chooseTreeObject(object)
end

-- The slam is rendered here, not replicated. The server publishes the constants
-- once; this recomputes the pose every frame from the shared server clock, so the
-- motion is smooth at whatever frame rate the player has and identical on every
-- machine. The contact test below then runs against the pose the player can see.
local motionTrees = {}

function rebuildMotionCache()
	table.clear(motionTrees)
	for index = 1, TREE_COUNT do
		local tree = treeObjects[index]
		if tree and tree.Parent then
			local base = tree:GetAttribute(TreeSlamMotion.BaseAttribute)
			local axis = tree:GetAttribute(TreeSlamMotion.AxisAttribute)
			local slamIndex = tonumber(tree:GetAttribute(TreeSlamMotion.IndexAttribute)) or index
			if typeof(base) == "CFrame" and typeof(axis) == "Vector3" then
				local parts = {}
				for _, part in ipairs(treeParts[index] or {}) do
					local relative = part:GetAttribute(TreeSlamMotion.RelativeAttribute)
					if typeof(relative) == "CFrame" then
						table.insert(parts, { part = part, relative = relative })
					end
				end
				if #parts > 0 then
					table.insert(motionTrees, { index = slamIndex, base = base, axis = axis, parts = parts })
				end
			end
		end
	end
end

local function renderTreeMotion()
	local start = tonumber(Workspace:GetAttribute(TreeSlamMotion.StartAttribute))
	if not start then
		return
	end
	local elapsed = Workspace:GetServerTimeNow() - start
	for _, tree in ipairs(motionTrees) do
		local angle = TreeSlamMotion.AngleAt(tree.index, elapsed)
		for _, entry in ipairs(tree.parts) do
			if entry.part.Parent then
				entry.part.CFrame = TreeSlamMotion.PoseFor(tree.base, tree.axis, angle, entry.relative)
			end
		end
	end
end

rebuildTreePartCache()

-- The server publishes the constants as it sets each tree up, so on a fast join
-- they can still be in flight. Retry briefly rather than rendering nothing.
task.spawn(function()
	for _ = 1, 40 do
		if #motionTrees >= TREE_COUNT then
			break
		end
		task.wait(0.25)
		rebuildMotionCache()
	end
end)

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

RunService.RenderStepped:Connect(function()
	-- Pose first, then test contact against that pose in the same frame.
	renderTreeMotion()
	detectTreeContact()
end)

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
		.. " active | slam rendered locally from the shared server clock, exact part-volume contact each frame"
		.. " | avatar body parts only | no padding | immediate local death | WORLD 2 ONLY"
)
