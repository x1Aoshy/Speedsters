                                                                                                        
  
                                                                              
                                                                               
                                                                           
                                                                          

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
if Config.IsWorld2Place ~= true then
	return
end

local TREE_COUNT = 6
local SAFE_ZONE_ATTRIBUTE = "SafeZoneProtected"
local REMOTE_NAME = "World2TreeSlamSelfHit"
local SLAM_ANGLE_DEGREES = 88
local DOWN_TIME = 0.16
local DOWN_HOLD = 0.70
local UP_TIME = 1.05
local UPRIGHT_HOLD = 0.70
local INITIAL_STAGGER = 0.29
local VERSION = "V306ICWorld2TreeMotion"

local DOWN_TWEEN = TweenInfo.new(DOWN_TIME, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
local UP_TWEEN = TweenInfo.new(UP_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

                                                                     
                                                                    
                                      
local TREE_YAW_CORRECTION_DEGREES = {
	[2] = 270,
	[4] = 270,
	[6] = 90,
}

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end
local hitRemote = remotes:FindFirstChild(REMOTE_NAME)
if hitRemote and not hitRemote:IsA("RemoteEvent") then
	hitRemote:Destroy()
	hitRemote = nil
end
if not hitRemote then
	hitRemote = Instance.new("RemoteEvent")
	hitRemote.Name = REMOTE_NAME
	hitRemote.Parent = remotes
end

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

local function isTreeObject(object)
	return object and (object:IsA("BasePart") or object:IsA("Model"))
end

local function treeIndexFromName(name)
	local index = tonumber(normalizeName(name):match("^tree(%d+)$"))
	if index and index >= 1 and index <= TREE_COUNT then
		return index
	end
	return nil
end

local function getPhysicalParts(object)
	local parts = {}
	if object:IsA("BasePart") then
		table.insert(parts, object)
	else
		for _, descendant in ipairs(object:GetDescendants()) do
			if descendant:IsA("BasePart") then
				table.insert(parts, descendant)
			end
		end
	end
	return parts
end

local function getBounds(object)
	if object:IsA("BasePart") then
		return object.CFrame, object.Size
	end
	local ok, cf, size = pcall(function()
		return object:GetBoundingBox()
	end)
	if ok then
		return cf, size
	end
	return nil, nil
end

local function worldVerticalExtent(part)
	local half = part.Size * 0.5
	local cf = part.CFrame
	return math.abs(cf.RightVector.Y) * half.X
		+ math.abs(cf.UpVector.Y) * half.Y
		+ math.abs(cf.LookVector.Y) * half.Z
end

local function horizontalDirection(fromPosition, toPosition)
	local delta = Vector3.new(toPosition.X - fromPosition.X, 0, toPosition.Z - fromPosition.Z)
	if delta.Magnitude < 0.05 then
		return nil
	end
	return delta.Unit
end

local function rotateHorizontal(vector, degrees)
	if math.abs(degrees or 0) < 0.001 then
		return vector
	end
	local rotation = CFrame.Angles(0, math.rad(degrees), 0)
	local rotated = rotation:VectorToWorldSpace(vector)
	local flat = Vector3.new(rotated.X, 0, rotated.Z)
	return flat.Magnitude > 0.001 and flat.Unit or vector
end

                                                                         
local lavaCandidates = {}
local lavaSet = setmetatable({}, { __mode = "k" })

local function isLavaPart(part)
	if not part:IsA("BasePart") then
		return false
	end
	local name = normalizeName(part.Name)
	return part.Material == Enum.Material.CrackedLava
		or name == "lava"
		or name:match("^lava%d+$") ~= nil
		or name:find("lava", 1, true) ~= nil
end

local function registerLavaPart(part)
	if isLavaPart(part) and not lavaSet[part] then
		lavaSet[part] = true
		table.insert(lavaCandidates, part)
	end
end

local function closestPointOnPartXZ(part, worldPosition)
	local localPoint = part.CFrame:PointToObjectSpace(worldPosition)
	local half = part.Size * 0.5
	local clamped = Vector3.new(
		math.clamp(localPoint.X, -half.X, half.X),
		0,
		math.clamp(localPoint.Z, -half.Z, half.Z)
	)
	return part.CFrame:PointToWorldSpace(clamped)
end

local treeObjects = {}
local startedTrees = setmetatable({}, { __mode = "k" })
local treeContactBounds = setmetatable({}, { __mode = "k" })

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

for _, object in ipairs(Workspace:GetDescendants()) do
	if object:IsA("BasePart") then
		registerLavaPart(object)
	end
	chooseTreeObject(object)
end

local function fallbackLaneDirection(index, basePosition)
	local positions = {}
	for treeIndex = 1, TREE_COUNT do
		local tree = treeObjects[treeIndex]
		if tree and tree.Parent then
			local cf = getBounds(tree)
			if cf then
				table.insert(positions, cf.Position)
			end
		end
	end
	if #positions >= 3 then
		local meanX, meanZ = 0, 0
		for _, position in ipairs(positions) do
			meanX += position.X
			meanZ += position.Z
		end
		meanX /= #positions
		meanZ /= #positions
		local xx, zz, xz = 0, 0, 0
		for _, position in ipairs(positions) do
			local dx = position.X - meanX
			local dz = position.Z - meanZ
			xx += dx * dx
			zz += dz * dz
			xz += dx * dz
		end
		local theta = 0.5 * math.atan2(2 * xz, xx - zz)
		local lateral = Vector3.new(-math.sin(theta), 0, math.cos(theta))
		local offset = Vector3.new(basePosition.X - meanX, 0, basePosition.Z - meanZ)
		local side = offset:Dot(lateral)
		if math.abs(side) > 0.05 then
			return side > 0 and -lateral or lateral
		end
	end
	local tree = treeObjects[index]
	if tree then
		local cf = getBounds(tree)
		if cf then
			local right = Vector3.new(cf.RightVector.X, 0, cf.RightVector.Z)
			if right.Magnitude > 0.05 then
				return -right.Unit
			end
		end
	end
	return Vector3.xAxis
end

local function findSlamDirection(index, basePosition)
	local bestDirection = nil
	local bestDistance = math.huge
	for _, lavaPart in ipairs(lavaCandidates) do
		if lavaPart and lavaPart.Parent and lavaSet[lavaPart] then
			local target = closestPointOnPartXZ(lavaPart, basePosition)
			local direction = horizontalDirection(basePosition, target)
			if direction then
				local distance = Vector3.new(target.X - basePosition.X, 0, target.Z - basePosition.Z).Magnitude
				if distance < bestDistance then
					bestDistance = distance
					bestDirection = direction
				end
			end
		end
	end
	local direction = bestDirection or fallbackLaneDirection(index, basePosition)
	return rotateHorizontal(direction, TREE_YAW_CORRECTION_DEGREES[index] or 0)
end

local function startTree(tree, index)
	if startedTrees[tree] or not tree.Parent then
		return
	end
	startedTrees[tree] = true

	local parts = getPhysicalParts(tree)
	if #parts == 0 then
		warn("[World2TreeSlammers] " .. tree:GetFullName() .. " has no BaseParts")
		return
	end
	local boundsCFrame = getBounds(tree)
	if not boundsCFrame then
		warn("[World2TreeSlammers] Could not resolve bounds for " .. tree:GetFullName())
		return
	end

	local minimumY = math.huge
	for _, part in ipairs(parts) do
		part.Anchored = true
		part.AssemblyLinearVelocity = Vector3.zero
		part.AssemblyAngularVelocity = Vector3.zero
		part:SetAttribute("World2TreeSlamHazard", true)
		part:SetAttribute("World2TreeIndex", index)
		minimumY = math.min(minimumY, part.Position.Y - worldVerticalExtent(part))
	end
	tree:SetAttribute("World2TreeSlamHazard", true)
	tree:SetAttribute("World2TreeIndex", index)

	local basePosition = Vector3.new(boundsCFrame.Position.X, minimumY, boundsCFrame.Position.Z)
	-- Rotation preserves distance from the pivot. This is an eligibility bound,
	-- never a lethal box: it accepts a delayed local hit anywhere in the real swing.
	local contactRadius = 0
	for _, part in ipairs(parts) do
		contactRadius = math.max(contactRadius, (part.Position - basePosition).Magnitude + part.Size.Magnitude * 0.5)
	end
	treeContactBounds[tree] = { center = basePosition, radius = contactRadius }
	local baseCFrame = CFrame.new(basePosition)
	local slamDirection = findSlamDirection(index, basePosition)
	local axis = Vector3.yAxis:Cross(slamDirection)
	if axis.Magnitude < 0.01 then
		axis = Vector3.zAxis
	else
		axis = axis.Unit
	end
	local slamAngle = math.rad(SLAM_ANGLE_DEGREES)

	local originalRelative = {}
	for _, part in ipairs(parts) do
		originalRelative[part] = baseCFrame:ToObjectSpace(part.CFrame)
	end

	local angleValue = Instance.new("NumberValue")
	angleValue.Name = "World2Tree" .. tostring(index) .. "SlamAngle"
	angleValue.Value = 0
	angleValue.Parent = script

	local function applyAngle(angle)
		if not tree.Parent then
			return
		end
		local rotation = CFrame.fromAxisAngle(axis, angle)
		for part, relative in pairs(originalRelative) do
			if part.Parent then
				part.CFrame = baseCFrame * rotation * relative
				part.AssemblyLinearVelocity = Vector3.zero
				part.AssemblyAngularVelocity = Vector3.zero
			end
		end
	end

	angleValue:GetPropertyChangedSignal("Value"):Connect(function()
		applyAngle(angleValue.Value)
	end)
	applyAngle(0)

	task.spawn(function()
		task.wait((index - 1) * INITIAL_STAGGER)
		while tree.Parent do
			task.wait(UPRIGHT_HOLD + ((index - 1) % 3) * 0.06)
			if not tree.Parent then break end

			local downTween = TweenService:Create(angleValue, DOWN_TWEEN, { Value = slamAngle })
			downTween:Play()
			downTween.Completed:Wait()
			applyAngle(slamAngle)

			task.wait(DOWN_HOLD + ((index - 1) % 2) * 0.08)
			if not tree.Parent then break end

			local upTween = TweenService:Create(angleValue, UP_TWEEN, { Value = 0 })
			upTween:Play()
			upTween.Completed:Wait()
			applyAngle(0)
		end
		angleValue:Destroy()
	end)

	print(
		"[World2TreeSlammers] Tree" .. tostring(index)
			.. " replicated motion active | down=" .. tostring(DOWN_TIME)
			.. "s | downHold=" .. tostring(DOWN_HOLD)
			.. "s | up=" .. tostring(UP_TIME)
			.. "s | uprightHold=" .. tostring(UPRIGHT_HOLD)
			.. "s | yawCorrection=" .. tostring(TREE_YAW_CORRECTION_DEGREES[index] or 0)
	)
end

for index = 1, TREE_COUNT do
	local tree = treeObjects[index]
	if tree and tree.Parent then
		startTree(tree, index)
	else
		warn("[World2TreeSlammers] Tree" .. tostring(index) .. " not found at startup; waiting for it to appear")
	end
end

Workspace.DescendantAdded:Connect(function(object)
	if object:IsA("BasePart") then
		registerLavaPart(object)
	end
	local index = chooseTreeObject(object)
	if index and treeObjects[index] == object then
		startTree(object, index)
	end
end)

                                                                            
                                                                         
local HAZARD_BODY_NAMES = {
 Head=true, Torso=true, UpperTorso=true, LowerTorso=true,
 ["Left Arm"]=true, ["Right Arm"]=true, ["Left Leg"]=true, ["Right Leg"]=true,
 LeftUpperArm=true, LeftLowerArm=true, LeftHand=true, RightUpperArm=true, RightLowerArm=true, RightHand=true,
 LeftUpperLeg=true, LeftLowerLeg=true, LeftFoot=true, RightUpperLeg=true, RightLowerLeg=true, RightFoot=true,
}
local function isHazardBodyPart(part, character)
 return part and part:IsA("BasePart") and part.Parent == character and HAZARD_BODY_NAMES[part.Name] == true
end

local lastServerConfirmAt = {}
local function isSafe(player, character)
	return player:GetAttribute("StageTeleportInvulnerable") == true
		or player:GetAttribute(SAFE_ZONE_ATTRIBUTE) == true
		or character:GetAttribute(SAFE_ZONE_ATTRIBUTE) == true
		or character:FindFirstChild("VortexSafeZoneForceField") ~= nil
end

hitRemote.OnServerEvent:Connect(function(player, treeIndex)
	if type(treeIndex) ~= "number" or treeIndex ~= treeIndex or treeIndex % 1 ~= 0 or treeIndex < 1 or treeIndex > TREE_COUNT then
		return
	end
	local now = os.clock()
	if now - (lastServerConfirmAt[player] or -math.huge) < 0.15 then
		return
	end
	lastServerConfirmAt[player] = now
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 or isSafe(player, character) then
		return
	end
	local tree = treeObjects[treeIndex]
	if not tree or not tree.Parent then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	local bounds = treeContactBounds[tree]
	if not root or not root:IsA("BasePart") or not bounds then return end
	local bodyRadius = 0
	for _, part in ipairs(character:GetChildren()) do
		if isHazardBodyPart(part, character) then
			bodyRadius = math.max(bodyRadius, (part.Position - root.Position).Magnitude + part.Size.Magnitude * 0.5)
		end
	end
	if bodyRadius <= 0 or (root.Position - bounds.center).Magnitude > bounds.radius + bodyRadius then return end
	-- The report only affects its sender. Rechecking the server's CURRENT pose
	-- would disagree with the already rendered local pose under replication delay.
	humanoid.Health = 0
end)

Players.PlayerRemoving:Connect(function(player)
	lastServerConfirmAt[player] = nil
end)

print(
	"[World2TreeSlammers] " .. VERSION
		.. " active | SERVER replicated motion preserved from V306IB | CLIENT all-part frame-hit detection | WORLD 2 ONLY"
)
