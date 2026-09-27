                                        
                                                                               
                                                                             
                                                                              
                                                            

local Workspace = game:GetService("Workspace")

local TARGET_NAME = "Spawn1Outline"
local HORIZONTAL_DOT_MINIMUM = 0.85
local VERTICAL_TOLERANCE = 7
local SEARCH_PADDING_XZ = 6
local FAST_SECONDS = 15

local connected = setmetatable({}, { __mode = "k" })

local function getWorldAabb(part)
	local half = part.Size * 0.5
	local cf = part.CFrame
	local right = cf.RightVector
	local up = cf.UpVector
	local look = cf.LookVector
	local extent = Vector3.new(
		math.abs(right.X) * half.X + math.abs(up.X) * half.Y + math.abs(look.X) * half.Z,
		math.abs(right.Y) * half.X + math.abs(up.Y) * half.Y + math.abs(look.Y) * half.Z,
		math.abs(right.Z) * half.X + math.abs(up.Z) * half.Y + math.abs(look.Z) * half.Z
	)
	return cf.Position - extent, cf.Position + extent
end

local function getObjectBounds(object)
	if object:IsA("BasePart") then
		local minPoint, maxPoint = getWorldAabb(object)
		return CFrame.new((minPoint + maxPoint) * 0.5), maxPoint - minPoint
	end
	if object:IsA("Model") then
		return object:GetBoundingBox()
	end

	local minPoint = Vector3.new(math.huge, math.huge, math.huge)
	local maxPoint = Vector3.new(-math.huge, -math.huge, -math.huge)
	local found = false
	for _, descendant in ipairs(object:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local partMin, partMax = getWorldAabb(descendant)
			minPoint = Vector3.new(math.min(minPoint.X, partMin.X), math.min(minPoint.Y, partMin.Y), math.min(minPoint.Z, partMin.Z))
			maxPoint = Vector3.new(math.max(maxPoint.X, partMax.X), math.max(maxPoint.Y, partMax.Y), math.max(maxPoint.Z, partMax.Z))
			found = true
		end
	end
	if not found then
		return nil, nil
	end
	return CFrame.new((minPoint + maxPoint) * 0.5), maxPoint - minPoint
end

local function overlapLength(minA, maxA, minB, maxB)
	return math.max(0, math.min(maxA, maxB) - math.max(minA, minB))
end

local function buildCandidate(part, boundsCFrame, boundsSize, target)
	if not part:IsA("BasePart") or part == target then
		return nil
	end
	if string.find(string.lower(part.Name), "outline", 1, true) then
		return nil
	end
	if math.abs(part.CFrame.UpVector.Y) < HORIZONTAL_DOT_MINIMUM then
		return nil
	end

	local partMin, partMax = getWorldAabb(part)
	local boundsHalf = boundsSize * 0.5
	local boundsMin = boundsCFrame.Position - boundsHalf
	local boundsMax = boundsCFrame.Position + boundsHalf
	if math.abs(partMax.Y - boundsMax.Y) > VERTICAL_TOLERANCE then
		return nil
	end

	local overlapX = overlapLength(partMin.X, partMax.X, boundsMin.X, boundsMax.X)
	local overlapZ = overlapLength(partMin.Z, partMax.Z, boundsMin.Z, boundsMax.Z)
	local overlapArea = overlapX * overlapZ
	local partArea = math.max(0.001, (partMax.X - partMin.X) * (partMax.Z - partMin.Z))
	local boundsArea = math.max(0.001, boundsSize.X * boundsSize.Z)
	if overlapArea / partArea < 0.35 or overlapArea / boundsArea < 0.06 then
		return nil
	end

	return {
		part = part,
		minPoint = partMin,
		maxPoint = partMax,
		overlapArea = overlapArea,
		topY = partMax.Y,
		thickness = partMax.Y - partMin.Y,
	}
end

local function pairScore(a, b, boundsSize)
	local colorDelta = math.abs(a.part.Color.R - b.part.Color.R)
		+ math.abs(a.part.Color.G - b.part.Color.G)
		+ math.abs(a.part.Color.B - b.part.Color.B)
	local gapX = math.max(0, math.max(a.minPoint.X, b.minPoint.X) - math.min(a.maxPoint.X, b.maxPoint.X))
	local gapZ = math.max(0, math.max(a.minPoint.Z, b.minPoint.Z) - math.min(a.maxPoint.Z, b.maxPoint.Z))
	local overlapX = overlapLength(a.minPoint.X, a.maxPoint.X, b.minPoint.X, b.maxPoint.X)
	local overlapZ = overlapLength(a.minPoint.Z, a.maxPoint.Z, b.minPoint.Z, b.maxPoint.Z)
	local bonus = (a.part.Material == b.part.Material) and 5000 or 0
	if gapX <= 2.5 and overlapZ > 1 then bonus = bonus + boundsSize.Z * 20 end
	if gapZ <= 2.5 and overlapX > 1 then bonus = bonus + boundsSize.X * 20 end
	return a.overlapArea + b.overlapArea + bonus
		- colorDelta * 6000
		- math.abs(a.thickness - b.thickness) * 400
		- math.abs(a.topY - b.topY) * 1000
end

local function findBothHalves()
	local target = Workspace:FindFirstChild(TARGET_NAME, true)
	if not target or not (target:IsA("BasePart") or target:IsA("Model") or target:IsA("Folder")) then
		return {}
	end
	local boundsCFrame, boundsSize = getObjectBounds(target)
	if not boundsCFrame or not boundsSize then
		return {}
	end

	local querySize = Vector3.new(boundsSize.X + SEARCH_PADDING_XZ * 2, math.max(12, boundsSize.Y + VERTICAL_TOLERANCE * 2), boundsSize.Z + SEARCH_PADDING_XZ * 2)
	local rawParts = Workspace:GetPartBoundsInBox(CFrame.new(boundsCFrame.Position), querySize)
	local candidates = {}
	local seen = {}
	local function consider(part)
		if seen[part] then return end
		seen[part] = true
		local candidate = buildCandidate(part, boundsCFrame, boundsSize, target)
		if candidate then table.insert(candidates, candidate) end
	end
	for _, part in ipairs(rawParts) do consider(part) end
	if #candidates < 2 then
		for _, descendant in ipairs(Workspace:GetDescendants()) do
			if descendant:IsA("BasePart") then consider(descendant) end
		end
	end
	if #candidates < 2 then return {} end

	local bestA, bestB, bestScore = nil, nil, -math.huge
	for i = 1, #candidates - 1 do
		for j = i + 1, #candidates do
			local score = pairScore(candidates[i], candidates[j], boundsSize)
			if score > bestScore then
				bestScore, bestA, bestB = score, candidates[i], candidates[j]
			end
		end
	end
	if not bestA or not bestB then return {} end
	return { bestA.part, bestB.part }
end

local function lockStuds(part)
	if not part or not part.Parent then return end
	part.TopSurface = Enum.SurfaceType.Studs
	part.BottomSurface = Enum.SurfaceType.Studs
	if connected[part] then return end
	connected[part] = {
		part:GetPropertyChangedSignal("TopSurface"):Connect(function()
			if part.Parent and part.TopSurface ~= Enum.SurfaceType.Studs then part.TopSurface = Enum.SurfaceType.Studs end
		end),
		part:GetPropertyChangedSignal("BottomSurface"):Connect(function()
			if part.Parent and part.BottomSurface ~= Enum.SurfaceType.Studs then part.BottomSurface = Enum.SurfaceType.Studs end
		end),
	}
end

local function repair()
	local parts = findBothHalves()
	if #parts == 2 then
		lockStuds(parts[1])
		lockStuds(parts[2])
		return true
	end
	return false
end

                                                                              
                                                                               
                                                                           
                                                                          
local repaired = false
local repairQueued = false
local descendantAddedConnection = nil

local function tryRepairOnce()
	if repaired then
		return true
	end
	repaired = repair() == true
	if repaired and descendantAddedConnection then
		descendantAddedConnection:Disconnect()
		descendantAddedConnection = nil
	end
	return repaired
end

local function queueRepair()
	if repaired or repairQueued then
		return
	end
	repairQueued = true
	task.defer(function()
		repairQueued = false
		tryRepairOnce()
	end)
end

                                                                           
                                                                           
descendantAddedConnection = Workspace.DescendantAdded:Connect(function(object)
	if repaired then
		return
	end
	if object.Name == TARGET_NAME or object:IsA("BasePart") then
		queueRepair()
	end
end)

task.spawn(function()
	local deadline = os.clock() + FAST_SECONDS
	repeat
		if tryRepairOnce() then
			return
		end
		task.wait(0.05)
	until os.clock() >= deadline
end)
