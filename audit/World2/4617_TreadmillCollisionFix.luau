                                                                                 
                                                               
  
                                                                            
                                                                             
                                                                               
                                                                       

local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local IS_NEW_WORLD1 = Config.IsNewWorld1Map == true
local NEW_WORLD1_ROOT = IS_NEW_WORLD1
	and Workspace:FindFirstChild(tostring(Config.NewWorld1MapMarkerName or "neworld1"))
local NEW_WORLD1_TREADMILL_PROFILES = Config.NewWorld1TreadmillProfiles or {}

local CHARACTER_GROUP = "VortexSpeedsterCharacters"
local TREADMILL_VISUAL_GROUP = "VortexTreadmillVisuals"
local GENERATED_FOLDER_NAME = "VortexTreadmillCollisionFix_V255"
local SPECIAL_PLATFORM_NAME = "Platform1"
local FIX_VERSION = "V255"

local MIN_HORIZONTAL_AREA = 2
local MIN_UP_ALIGNMENT = 0.78
local HEIGHT_CLUSTER_TOLERANCE = 0.42
local SURFACE_THICKNESS = 0.36
local SURFACE_OVERLAP = 0.45
local RAMP_MIN_RUN = 5.5
local RAMP_MAX_RUN = 10
local RAMP_WIDTH_OVERLAP = 0.35
local PLATFORM_RAMP_MIN_RUN = 3.25
local PLATFORM_RAMP_MAX_RUN = 6.5
local GROUND_RAY_HEIGHT = 12
local GROUND_RAY_DEPTH = 42

local generatedFolder = nil
local preparedObjects = setmetatable({}, { __mode = "k" })
local preparingObjects = setmetatable({}, { __mode = "k" })
local generatedIndex = 0

local function normalizeName(value)
	return tostring(value or ""):lower():gsub("[^%w]", "")
end

local function isSupportedObject(object)
	return object:IsA("Model") or object:IsA("BasePart")
end

local function ensureCollisionGroup(groupName)
	pcall(function()
		PhysicsService:RegisterCollisionGroup(groupName)
	end)
end

ensureCollisionGroup(CHARACTER_GROUP)
ensureCollisionGroup(TREADMILL_VISUAL_GROUP)
PhysicsService:CollisionGroupSetCollidable(CHARACTER_GROUP, TREADMILL_VISUAL_GROUP, false)
                                                                               
                                                                                         
PhysicsService:CollisionGroupSetCollidable(CHARACTER_GROUP, CHARACTER_GROUP, false)

local function setCharacterCollisionGroup(character)
	local function apply(instance)
		if instance:IsA("BasePart") then
			instance.CollisionGroup = CHARACTER_GROUP
		end
	end

	for _, descendant in ipairs(character:GetDescendants()) do
		apply(descendant)
	end

	character.DescendantAdded:Connect(apply)
	character:SetAttribute("VortexTreadmillCollisionFix", true)
	character:SetAttribute("VortexTreadmillCollisionFixVersion", FIX_VERSION)
end

local function bindPlayer(player)
	if player.Character then
		task.defer(setCharacterCollisionGroup, player.Character)
	end
	player.CharacterAdded:Connect(setCharacterCollisionGroup)
end

for _, player in ipairs(Players:GetPlayers()) do
	bindPlayer(player)
end
Players.PlayerAdded:Connect(bindPlayer)

local function collectParts(object)
	local parts = {}

	if object:IsA("BasePart") then
		table.insert(parts, object)
	end

	for _, descendant in ipairs(object:GetDescendants()) do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end

	return parts
end

local function projectedTopY(part)
	local half = part.Size * 0.5
	local cframe = part.CFrame
	local verticalRadius = math.abs(cframe.RightVector.Y) * half.X
		+ math.abs(cframe.UpVector.Y) * half.Y
		+ math.abs(cframe.LookVector.Y) * half.Z

	return part.Position.Y + verticalRadius
end

local function horizontalArea(part)
	local size = part.Size
	return math.max(size.X * size.Z, size.X * size.Y, size.Y * size.Z)
end

local function makeHorizontalCandidates(parts)
	local candidates = {}

	for _, part in ipairs(parts) do
		local upAlignment = math.abs(part.CFrame.UpVector.Y)
		local area = part.Size.X * part.Size.Z
		if upAlignment >= MIN_UP_ALIGNMENT and area >= MIN_HORIZONTAL_AREA then
			table.insert(candidates, {
				Part = part,
				TopY = projectedTopY(part),
				Area = area,
			})
		end
	end

	if #candidates == 0 then
		for _, part in ipairs(parts) do
			table.insert(candidates, {
				Part = part,
				TopY = projectedTopY(part),
				Area = horizontalArea(part),
			})
		end
	end

	return candidates
end

local function chooseWalkingCluster(candidates)
	local bestCluster = nil
	local bestWeight = -math.huge

	for _, seed in ipairs(candidates) do
		local cluster = {}
		local totalArea = 0
		local weightedTop = 0

		for _, candidate in ipairs(candidates) do
			if math.abs(candidate.TopY - seed.TopY) <= HEIGHT_CLUSTER_TOLERANCE then
				table.insert(cluster, candidate)
				local collideWeight = candidate.Part.CanCollide and 1 or 0.35
				local weight = math.max(candidate.Area, 0.1) * collideWeight
				totalArea += weight
				weightedTop += candidate.TopY * weight
			end
		end

		if totalArea > 0 then
			local averageTop = weightedTop / totalArea
			local score = totalArea + averageTop * 0.0001
			if score > bestWeight then
				bestWeight = score
				bestCluster = cluster
			end
		end
	end

	return bestCluster
end

local function flattenedUnit(vector, fallback)
	local flat = Vector3.new(vector.X, 0, vector.Z)
	if flat.Magnitude <= 0.001 then
		return fallback
	end
	return flat.Unit
end

local function calculateDeck(sourceObject, parts)
	local candidates = makeHorizontalCandidates(parts)
	local cluster = chooseWalkingCluster(candidates)
	if not cluster or #cluster == 0 then
		return nil
	end

	local anchor = cluster[1]
	for _, candidate in ipairs(cluster) do
		if candidate.Area > anchor.Area then
			anchor = candidate
		end
	end

	local right = flattenedUnit(anchor.Part.CFrame.RightVector, Vector3.xAxis)
	local look = Vector3.new(-right.Z, 0, right.X)
	local origin = anchor.Part.Position

	local minimumRight = math.huge
	local maximumRight = -math.huge
	local minimumLook = math.huge
	local maximumLook = -math.huge
	local weightedTop = 0
	local totalWeight = 0

	for _, candidate in ipairs(cluster) do
		local part = candidate.Part
		local halfX = part.Size.X * 0.5
		local halfZ = part.Size.Z * 0.5

		for _, signX in ipairs({ -1, 1 }) do
			for _, signZ in ipairs({ -1, 1 }) do
				local corner = part.Position
					+ part.CFrame.RightVector * halfX * signX
					+ part.CFrame.LookVector * halfZ * signZ
				local offset = corner - origin
				local rightDistance = offset:Dot(right)
				local lookDistance = offset:Dot(look)
				minimumRight = math.min(minimumRight, rightDistance)
				maximumRight = math.max(maximumRight, rightDistance)
				minimumLook = math.min(minimumLook, lookDistance)
				maximumLook = math.max(maximumLook, lookDistance)
			end
		end

		local weight = math.max(candidate.Area, 0.1)
		weightedTop += candidate.TopY * weight
		totalWeight += weight
	end

	if totalWeight <= 0 then
		return nil
	end

	local spanRight = maximumRight - minimumRight
	local spanLook = maximumLook - minimumLook
	local centerRight = (minimumRight + maximumRight) * 0.5
	local centerLook = (minimumLook + maximumLook) * 0.5
	local center = origin + right * centerRight + look * centerLook
	local topY = weightedTop / totalWeight + 0.04

	local longAxis
	local widthAxis
	local length
	local width
	if spanRight >= spanLook then
		longAxis = right
		widthAxis = look
		length = spanRight
		width = spanLook
	else
		longAxis = look
		widthAxis = right
		length = spanLook
		width = spanRight
	end

	length = math.max(length + SURFACE_OVERLAP * 2, 5)
	width = math.max(width + RAMP_WIDTH_OVERLAP * 2, 3)

	return {
		Center = Vector3.new(center.X, topY, center.Z),
		TopY = topY,
		LongAxis = longAxis,
		WidthAxis = widthAxis,
		Length = length,
		Width = width,
		Source = sourceObject,
	}
end

local function makePart(name, size, cframe, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.CanCollide = true
	part.CanTouch = false
	part.CanQuery = true
	part.CastShadow = false
	part.Transparency = 1
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part:SetAttribute("VortexTreadmillCollisionPart", true)
	part:SetAttribute("VortexTreadmillCollisionVersion", FIX_VERSION)
	part.Parent = parent
	return part
end

local function horizontalCFrame(position, widthAxis, longAxis)
	local right = flattenedUnit(widthAxis, Vector3.xAxis)
	local look = flattenedUnit(longAxis, Vector3.zAxis)
	return CFrame.fromMatrix(position, right, Vector3.yAxis, -look)
end

local function groundYAt(sourceObject, position, fallbackY)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { sourceObject, generatedFolder }
	params.IgnoreWater = false
	params.RespectCanCollide = true

	local origin = position + Vector3.new(0, GROUND_RAY_HEIGHT, 0)
	local result = Workspace:Raycast(origin, Vector3.new(0, -GROUND_RAY_DEPTH, 0), params)

	if result then
		return result.Position.Y
	end

	return fallbackY
end

local function createRamp(
	deck,
	endDirection,
	edgeHalfSpan,
	rampWidth,
	index,
	parent,
	minimumRun,
	maximumRun
)
	minimumRun = minimumRun or RAMP_MIN_RUN
	maximumRun = maximumRun or RAMP_MAX_RUN

	local surfaceEnd = deck.Center + endDirection * (edgeHalfSpan - 0.25)
	local heightGuess = deck.TopY - 1.25
	local groundProbe = deck.Center + endDirection * (edgeHalfSpan + minimumRun)
	local groundY = groundYAt(deck.Source, groundProbe, heightGuess)
	groundY = math.min(groundY, deck.TopY - 0.08)

	local rise = math.max(deck.TopY - groundY, 0.08)
	local run = math.clamp(minimumRun + rise * 1.65, minimumRun, maximumRun)
	local outerPoint = deck.Center + endDirection * (edgeHalfSpan + run)
	outerPoint = Vector3.new(outerPoint.X, groundY - 0.12, outerPoint.Z)
	local innerPoint = Vector3.new(surfaceEnd.X, deck.TopY - 0.03, surfaceEnd.Z)

	local difference = innerPoint - outerPoint
	if difference.Magnitude <= 0.001 then
		return nil
	end

	local look = difference.Unit
	local right = look:Cross(Vector3.yAxis)
	local wantedWidthAxis = math.abs(endDirection:Dot(deck.LongAxis)) >= 0.9
		and deck.WidthAxis
		or deck.LongAxis

	if right.Magnitude <= 0.001 then
		right = wantedWidthAxis
	else
		right = right.Unit
	end
	if right:Dot(wantedWidthAxis) < 0 then
		right = -right
	end

	local up = right:Cross(look).Unit
	local centerLine = (outerPoint + innerPoint) * 0.5
	local center = centerLine - up * (SURFACE_THICKNESS * 0.5)
	local slopeLength = difference.Magnitude + 0.45
	local cframe = CFrame.fromMatrix(center, right, up, -look)

	return makePart(
		"SmoothRamp" .. tostring(index),
		Vector3.new(rampWidth, SURFACE_THICKNESS, slopeLength),
		cframe,
		parent
	)
end

local function setVisualPart(part)
	part.CollisionGroup = TREADMILL_VISUAL_GROUP
	part:SetAttribute("VortexTreadmillVisualPart", true)
	part:SetAttribute("VortexTreadmillVisualVersion", FIX_VERSION)
end

local function safeFolderName(value)
	local clean = tostring(value or "Surface"):gsub("[^%w_%-]", "_")
	if #clean > 55 then
		clean = clean:sub(1, 55)
	end
	return clean
end

local function prepareSurface(sourceObject, displayName, addAllSideRamps)
	if not sourceObject
		or not sourceObject.Parent
		or not isSupportedObject(sourceObject)
		or preparedObjects[sourceObject]
		or preparingObjects[sourceObject]
	then
		return false
	end

	preparingObjects[sourceObject] = true
	local parts = collectParts(sourceObject)
	if #parts == 0 then
		preparingObjects[sourceObject] = nil
		return false
	end

	local deck = calculateDeck(sourceObject, parts)
	if not deck then
		preparingObjects[sourceObject] = nil
		warn("[TreadmillCollisionFix] Could not calculate smooth deck for " .. sourceObject:GetFullName())
		return false
	end

	for _, part in ipairs(parts) do
		setVisualPart(part)
	end

	generatedIndex += 1
	local modelFolder = Instance.new("Folder")
	modelFolder.Name = string.format("%02d_%s", generatedIndex, safeFolderName(displayName))
	modelFolder:SetAttribute("VortexTreadmillCollisionPart", true)
	modelFolder:SetAttribute("SourceTreadmill", sourceObject:GetFullName())
	modelFolder:SetAttribute("SourceIsStageClone", sourceObject:GetAttribute("StageDecorClone") == true)
	modelFolder:SetAttribute("AllSideRamps", addAllSideRamps == true)
	modelFolder.Parent = generatedFolder

	local deckPosition = deck.Center - Vector3.new(0, SURFACE_THICKNESS * 0.5, 0)
	makePart(
		"SmoothDeck",
		Vector3.new(deck.Width, SURFACE_THICKNESS, deck.Length),
		horizontalCFrame(deckPosition, deck.WidthAxis, deck.LongAxis),
		modelFolder
	)
	createRamp(deck, deck.LongAxis, deck.Length * 0.5, deck.Width, 1, modelFolder)
	createRamp(deck, -deck.LongAxis, deck.Length * 0.5, deck.Width, 2, modelFolder)

	if addAllSideRamps then
		createRamp(
			deck,
			deck.WidthAxis,
			deck.Width * 0.5,
			deck.Length,
			3,
			modelFolder,
			PLATFORM_RAMP_MIN_RUN,
			PLATFORM_RAMP_MAX_RUN
		)
		createRamp(
			deck,
			-deck.WidthAxis,
			deck.Width * 0.5,
			deck.Length,
			4,
			modelFolder,
			PLATFORM_RAMP_MIN_RUN,
			PLATFORM_RAMP_MAX_RUN
		)
	end

	preparedObjects[sourceObject] = modelFolder
	preparingObjects[sourceObject] = nil

	sourceObject:SetAttribute("VortexTreadmillCollisionFix", true)
	sourceObject:SetAttribute("VortexTreadmillCollisionFixVersion", FIX_VERSION)

	sourceObject.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("BasePart") then
			setVisualPart(descendant)
		end
	end)

	sourceObject.AncestryChanged:Connect(function()
		if not sourceObject:IsDescendantOf(Workspace) then
			local folder = preparedObjects[sourceObject]
			if folder and folder.Parent then
				folder:Destroy()
			end
			preparedObjects[sourceObject] = nil
			preparingObjects[sourceObject] = nil
		end
	end)

	return true
end

local function treadmillSourceName(object)
	if NEW_WORLD1_ROOT
		and object:IsDescendantOf(NEW_WORLD1_ROOT)
		and NEW_WORLD1_TREADMILL_PROFILES[object.Name]
	then
		return object.Name
	end

	local attributeName = object:GetAttribute("TreadmillTrainingSourceName")
	if typeof(attributeName) == "string" and Config.TreadmillBaseGains[attributeName] then
		return attributeName
	end

	if Config.TreadmillBaseGains[object.Name] then
		return object.Name
	end

	return nil
end

local function classifyAndPrepare(object)
	if not object
		or not object.Parent
		or not isSupportedObject(object)
		or object:IsDescendantOf(generatedFolder)
		or preparedObjects[object]
		or preparingObjects[object]
	then
		return nil
	end

	local sourceName = treadmillSourceName(object)
	if sourceName then
		                                                                        
		                                                                         
		                                                                        
		                                                                    
		local physicalObject = object
		if NEW_WORLD1_ROOT
			and object:IsDescendantOf(NEW_WORLD1_ROOT)
			and NEW_WORLD1_TREADMILL_PROFILES[sourceName]
		then
			local nestedBelt = object:FindFirstChild("Treadmil", true)
			if nestedBelt and isSupportedObject(nestedBelt) then
				physicalObject = nestedBelt
			else
				warn(
					"[TreadmillCollisionFix] New World 1 treadmill "
						.. object:GetFullName()
						.. " has no nested Model/BasePart named Treadmil; using the outer model"
				)
			end
		end

		local label = object:GetAttribute("StageDecorClone") == true
			and (object.Name .. "_StageClone")
			or sourceName
		return prepareSurface(physicalObject, label, false) and "Treadmill" or nil
	end

	if normalizeName(object.Name) == normalizeName(SPECIAL_PLATFORM_NAME) then
		return prepareSurface(object, SPECIAL_PLATFORM_NAME, true) and "Platform" or nil
	end

	return nil
end

local oldFolder = Workspace:FindFirstChild(GENERATED_FOLDER_NAME)
if oldFolder then
	oldFolder:Destroy()
end

                                                                               
                                                            
for _, child in ipairs(Workspace:GetChildren()) do
	if child:IsA("Folder")
		and child.Name:match("^VortexTreadmillCollisionFix_V%d+$")
		and child.Name ~= GENERATED_FOLDER_NAME
	then
		child:Destroy()
	end
end

generatedFolder = Instance.new("Folder")
generatedFolder.Name = GENERATED_FOLDER_NAME
generatedFolder:SetAttribute("VortexTreadmillCollisionPart", true)
generatedFolder:SetAttribute("Version", FIX_VERSION)
generatedFolder.Parent = Workspace

                                                                                 
task.wait(1)

local discoveredTreadmills = 0
local discoveredPlatforms = 0

local function scanWorkspace()
	for _, object in ipairs(Workspace:GetDescendants()) do
		local classification = classifyAndPrepare(object)
		if classification == "Treadmill" then
			discoveredTreadmills += 1
		elseif classification == "Platform" then
			discoveredPlatforms += 1
		end
	end
end

scanWorkspace()

Workspace.DescendantAdded:Connect(function(object)
	task.defer(function()
		classifyAndPrepare(object)
		local parent = object.Parent
		while parent and parent ~= Workspace do
			if classifyAndPrepare(parent) then
				break
			end
			parent = parent.Parent
		end
	end)
end)

                                                                             
                                                                               
                                                                               
                                                                          
                                                                             
task.delay(3, function()
	scanWorkspace()
end)

print(
	"[TreadmillCollisionFix] V255 loaded. Smooth collision created for "
		.. tostring(discoveredTreadmills)
		.. " treadmill(s) at startup; Platform1 repairs="
		.. tostring(discoveredPlatforms)
		.. ". Runtime stage-clone discovery is active."
)
