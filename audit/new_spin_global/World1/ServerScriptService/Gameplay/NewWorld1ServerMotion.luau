                                                                      
  
                                                                             
                                                                               
                                                                              
                                                                            
                                                

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
if Config.IsNewWorld1Map ~= true then
	return
end

local MAP_ROOT_NAME = tostring(Config.NewWorld1MapMarkerName or "neworld1")
local mapRoot = Workspace:FindFirstChild(MAP_ROOT_NAME) or Workspace:WaitForChild(MAP_ROOT_NAME, 20)
if not mapRoot then
	warn("[NewWorld1ServerMotion] Workspace." .. MAP_ROOT_NAME .. " is missing")
	return
end

local motionStartServerTime = tonumber(mapRoot:GetAttribute("NewWorld1MotionStartServerTime"))
if not motionStartServerTime then
	motionStartServerTime = Workspace:GetServerTimeNow() + 1
	mapRoot:SetAttribute("NewWorld1MotionStartServerTime", motionStartServerTime)
end

local ORIGIN_CFRAME_ATTRIBUTE = "V306KBH_AuthoredCFrame"
local ORIGIN_PIVOT_ATTRIBUTE = "V306KBH_AuthoredPivot"
local BOUNDS_CFRAME_ATTRIBUTE = "V306KBH_AuthoredBoundsCFrame"
local BOUNDS_SIZE_ATTRIBUTE = "V306KBH_AuthoredBoundsSize"
local TRANSPARENCY_ATTRIBUTE = "V306KBH_AuthoredTransparency"
local CAN_COLLIDE_ATTRIBUTE = "V306KBH_AuthoredCanCollide"
local CAN_TOUCH_ATTRIBUTE = "V306KBH_AuthoredCanTouch"
local CAN_QUERY_ATTRIBUTE = "V306KBH_AuthoredCanQuery"

local TAU = math.pi * 2
local CYLINDER_SPEED = 30
local CYLINDER_STOP_WAIT = 0.77
local CYLINDER_START_WAIT = 0.37
local CYLINDER_PATH_SAMPLE_SPACING = 1.5
local CYLINDER_PATH_PROBE_UP = 45
local CYLINDER_PATH_PROBE_DOWN = 120
local CYLINDER_MIN_SURFACE_NORMAL_Y = 0.12
                                                                             
                                                                
local HAMMER_ANGULAR_SPEED = math.pi / (1.2 / 0.819)
local HAMMER_SWING_ANGLE = math.rad(55)
local HAMMER_WHOOSH_SOUND_ID = "rbxassetid://138158731526545"
local HAMMER_WHOOSH_VOLUME = 2.6
local HAMMER_PHASE_OFFSETS = {
	-math.pi * 0.5,
	math.pi * 0.5,
	0,
	math.pi,
	-math.pi * 0.25,
}
local LASER_ANGULAR_SPEED = math.rad(52)
local PRESS_DOWN_SPEED = 170
local PRESS_UP_SPEED = 7.7
local PRESS_EXTRA_LOWER_STUDS = 7
local PRESS_TOP_WAIT = 0.55
local PRESS_BOTTOM_WAIT = 0.17
local PRESS_SEQUENCE_STAGGER = 0.31
local SLIDE_OUTWARD_DISTANCE = 100                                                        
local SLIDE_TRAVEL_TIME = 1.25
local SLIDE_EDGE_WAIT = 0.35
-- The floor that splits open (slide1, slide2) only moves 100 studs apart, which left ledges
-- of it to stand on at the sides (2026-09-18, Sung's video). Past SLIDE_SOLID_UNTIL of the
-- way open each half stops being solid and fades out fully; closing, it is solid again
-- once it is back under that.
local SLIDE_SOLID_UNTIL = 0.55
local FAST_SPEED = 177.77777                                                      
local FAST_START_WAIT = 0.9
local FAST_END_WAIT = 0.77
local LAVA_RISE_STUDS = 437
-- 2.5 times the 12.65 it rose at (2026-09-18, Sung's video: the rising lava was too slow to
-- be a threat).
local LAVA_UP_SPEED = 12.65 * 2.5                                                        
local LAVA_DOWN_SPEED = 320                                                                
local LAVA_TOP_WAIT = 0.55
local LAVA_BOTTOM_WAIT = 1.25
local BRIDGE_VISIBLE_TIME = 3.7
local BRIDGE_FADE_TIME = 0.55
local BRIDGE_HIDDEN_TIME = 1.65
local SERVER_MOTION_INTERVAL = 1 / 30
local BODY_PADDING = Vector3.new(2.6, 3.5, 2.6)
local SWEEP_SAMPLE_DISTANCE = 2.25
local MAX_SWEEP_SAMPLES = 20

local function normalizeName(value)
	return tostring(value or ""):lower():gsub("[^%w]", "")
end

local function isObjectContainer(object)
	return object and (object:IsA("Model") or object:IsA("BasePart") or object:IsA("Folder"))
end

local function collectBaseParts(object)
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

local function getObjectPivot(object)
	if object:IsA("Model") then
		return object:GetPivot()
	elseif object:IsA("BasePart") then
		return object.CFrame
	end
	local firstPart = object:FindFirstChildWhichIsA("BasePart", true)
	return firstPart and firstPart.CFrame or nil
end

local function getObjectBounds(object)
	if object:IsA("Model") then
		local ok, boundsCFrame, boundsSize = pcall(object.GetBoundingBox, object)
		if ok then
			return boundsCFrame, boundsSize
		end
	elseif object:IsA("BasePart") then
		return object.CFrame, object.Size
	end

	local parts = collectBaseParts(object)
	if #parts == 0 then
		return nil, nil
	end
	local minimum = Vector3.new(math.huge, math.huge, math.huge)
	local maximum = Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, part in ipairs(parts) do
		local half = part.Size * 0.5
		for xSign = -1, 1, 2 do
			for ySign = -1, 1, 2 do
				for zSign = -1, 1, 2 do
					local corner = part.CFrame:PointToWorldSpace(Vector3.new(
						half.X * xSign,
						half.Y * ySign,
						half.Z * zSign
					))
					minimum = Vector3.new(
						math.min(minimum.X, corner.X),
						math.min(minimum.Y, corner.Y),
						math.min(minimum.Z, corner.Z)
					)
					maximum = Vector3.new(
						math.max(maximum.X, corner.X),
						math.max(maximum.Y, corner.Y),
						math.max(maximum.Z, corner.Z)
					)
				end
			end
		end
	end
	return CFrame.new((minimum + maximum) * 0.5), maximum - minimum
end

local function getPartsBounds(parts)
	if #parts == 0 then
		return nil, nil
	end
	local minimum = Vector3.new(math.huge, math.huge, math.huge)
	local maximum = Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, part in ipairs(parts) do
		local half = part.Size * 0.5
		for xSign = -1, 1, 2 do
			for ySign = -1, 1, 2 do
				for zSign = -1, 1, 2 do
					local corner = part.CFrame:PointToWorldSpace(Vector3.new(
						half.X * xSign,
						half.Y * ySign,
						half.Z * zSign
					))
					minimum = Vector3.new(
						math.min(minimum.X, corner.X),
						math.min(minimum.Y, corner.Y),
						math.min(minimum.Z, corner.Z)
					)
					maximum = Vector3.new(
						math.max(maximum.X, corner.X),
						math.max(maximum.Y, corner.Y),
						math.max(maximum.Z, corner.Z)
					)
				end
			end
		end
	end
	return CFrame.new((minimum + maximum) * 0.5), maximum - minimum
end

local function getCFrameAttribute(object, name)
	local value = object:GetAttribute(name)
	return typeof(value) == "CFrame" and value or nil
end

local function getVectorAttribute(object, name)
	local value = object:GetAttribute(name)
	return typeof(value) == "Vector3" and value or nil
end

local function preservePartState(part)
	if getCFrameAttribute(part, ORIGIN_CFRAME_ATTRIBUTE) == nil then
		part:SetAttribute(ORIGIN_CFRAME_ATTRIBUTE, part.CFrame)
	end
	if part:GetAttribute(TRANSPARENCY_ATTRIBUTE) == nil then
		part:SetAttribute(TRANSPARENCY_ATTRIBUTE, part.Transparency)
		part:SetAttribute(CAN_COLLIDE_ATTRIBUTE, part.CanCollide)
		part:SetAttribute(CAN_TOUCH_ATTRIBUTE, part.CanTouch)
		part:SetAttribute(CAN_QUERY_ATTRIBUTE, part.CanQuery)
	end
	part.Anchored = true
	part.AssemblyLinearVelocity = Vector3.zero
	part.AssemblyAngularVelocity = Vector3.zero
end

local function preserveVisualState(object)
	if (object:IsA("Decal") or object:IsA("Texture"))
		and object:GetAttribute(TRANSPARENCY_ATTRIBUTE) == nil
	then
		object:SetAttribute(TRANSPARENCY_ATTRIBUTE, object.Transparency)
	end
end

local function makeMotionRecord(object)
	if not object or not object.Parent or not isObjectContainer(object) then
		return nil
	end

	local originPivot = getCFrameAttribute(object, ORIGIN_PIVOT_ATTRIBUTE)
	local boundsCFrame = getCFrameAttribute(object, BOUNDS_CFRAME_ATTRIBUTE)
	local boundsSize = getVectorAttribute(object, BOUNDS_SIZE_ATTRIBUTE)
	if not originPivot then
		originPivot = getObjectPivot(object)
		if originPivot then
			object:SetAttribute(ORIGIN_PIVOT_ATTRIBUTE, originPivot)
		end
	end
	if not boundsCFrame or not boundsSize then
		boundsCFrame, boundsSize = getObjectBounds(object)
		if boundsCFrame and boundsSize then
			object:SetAttribute(BOUNDS_CFRAME_ATTRIBUTE, boundsCFrame)
			object:SetAttribute(BOUNDS_SIZE_ATTRIBUTE, boundsSize)
		end
	end

	local parts = collectBaseParts(object)
	if not originPivot or not boundsCFrame or not boundsSize or #parts == 0 then
		return nil
	end

	local originCFrames = {}
	local previousCFrames = {}
	for _, part in ipairs(parts) do
		preservePartState(part)
		originCFrames[part] = getCFrameAttribute(part, ORIGIN_CFRAME_ATTRIBUTE) or part.CFrame
		previousCFrames[part] = part.CFrame
	end
	for _, descendant in ipairs(object:GetDescendants()) do
		preserveVisualState(descendant)
	end

	return {
		Object = object,
		Parts = parts,
		OriginPivot = originPivot,
		OriginCFrames = originCFrames,
		PreviousCFrames = previousCFrames,
		BoundsCFrame = boundsCFrame,
		BoundsSize = boundsSize,
		Radius = boundsSize.Magnitude * 0.5,
		CurrentCenter = boundsCFrame.Position,
		PreviousCenter = boundsCFrame.Position,
	}
end

local function makeSelectedMotionRecord(object, parts, originPivot, boundsCFrame, boundsSize)
	if not object or not object.Parent or #parts == 0 or not originPivot or not boundsCFrame or not boundsSize then
		return nil
	end

	                                                                           
	                                                                    
	object:SetAttribute(ORIGIN_PIVOT_ATTRIBUTE, originPivot)
	object:SetAttribute(BOUNDS_CFRAME_ATTRIBUTE, boundsCFrame)
	object:SetAttribute(BOUNDS_SIZE_ATTRIBUTE, boundsSize)

	local originCFrames = {}
	local previousCFrames = {}
	for _, part in ipairs(parts) do
		preservePartState(part)
		originCFrames[part] = getCFrameAttribute(part, ORIGIN_CFRAME_ATTRIBUTE) or part.CFrame
		previousCFrames[part] = part.CFrame
	end
	for _, descendant in ipairs(object:GetDescendants()) do
		preserveVisualState(descendant)
	end

	return {
		Object = object,
		Parts = parts,
		OriginPivot = originPivot,
		OriginCFrames = originCFrames,
		PreviousCFrames = previousCFrames,
		BoundsCFrame = boundsCFrame,
		BoundsSize = boundsSize,
		Radius = boundsSize.Magnitude * 0.5,
		CurrentCenter = boundsCFrame.Position,
		PreviousCenter = boundsCFrame.Position,
	}
end

local function getWorldVerticalSpan(part)
	local size = part.Size
	local cframe = part.CFrame
	return math.abs(cframe.RightVector.Y) * size.X
		+ math.abs(cframe.UpVector.Y) * size.Y
		+ math.abs(cframe.LookVector.Y) * size.Z
end

local function getPartTopPoint(part)
	local half = part.Size * 0.5
	local candidates = {
		part.CFrame.RightVector * half.X,
		part.CFrame.UpVector * half.Y,
		part.CFrame.LookVector * half.Z,
	}
	local best = candidates[1]
	for _, vector in ipairs(candidates) do
		if math.abs(vector.Y) > math.abs(best.Y) then
			best = vector
		end
	end
	if best.Y < 0 then
		best = -best
	end
	return part.Position + best
end

local function getPartWorldBottomY(part)
	return part.Position.Y - getWorldVerticalSpan(part) * 0.5
end

local function splitHammerParts(hammerObject)
	local allParts = collectBaseParts(hammerObject)
	if #allParts <= 1 then
		return allParts, {}, allParts[1] and getPartTopPoint(allParts[1]) or nil, allParts[1]
	end

	                                                                       
	                                                                       
	                                                                             
	                                                                           
	                                                                      
	                                                                            
	                                                                      
	local shaftPart = allParts[1]
	local shaftSpan = getWorldVerticalSpan(shaftPart)
	for _, part in ipairs(allParts) do
		local span = getWorldVerticalSpan(part)
		if span > shaftSpan then
			shaftPart = part
			shaftSpan = span
		end
	end

	local pivotPosition = getPartTopPoint(shaftPart)
	local stationaryParts = {}
	local movingParts = {}
	for _, part in ipairs(allParts) do
		if part ~= shaftPart and getPartWorldBottomY(part) >= pivotPosition.Y - 0.8 then
			table.insert(stationaryParts, part)
		else
			table.insert(movingParts, part)
		end
	end

	                                                                            
	                                                                          
	                                                  
	if #stationaryParts == 0 then
		return {}, {}, nil, shaftPart
	end

	return movingParts, stationaryParts, pivotPosition, shaftPart
end

local function disableCrossSupportJoints(hammerObject, movingSet)
	for _, descendant in ipairs(hammerObject:GetDescendants()) do
		if descendant:IsA("JointInstance") or descendant:IsA("WeldConstraint") then
			local part0
			local part1
			pcall(function()
				part0 = descendant.Part0
				part1 = descendant.Part1
			end)
			if part0 and part1 and movingSet[part0] ~= movingSet[part1] then
				pcall(function()
					descendant.Enabled = false
				end)
			end
		end
	end
end

local function horizontalUnit(vector)
	local horizontal = Vector3.new(vector.X, 0, vector.Z)
	return horizontal.Magnitude > 0.001 and horizontal.Unit or nil
end

local function getCourseDirection()
	local firstStage = mapRoot:FindFirstChild("stage1", true)
	local lastStage = mapRoot:FindFirstChild("stage6", true)
	local firstPivot = firstStage and getObjectPivot(firstStage)
	local lastPivot = lastStage and getObjectPivot(lastStage)
	if firstPivot and lastPivot then
		return horizontalUnit(lastPivot.Position - firstPivot.Position)
	end
	return nil
end

local function getHammerWorldAxis(axisName, pivot)
	if axisName == "X" then
		return pivot.RightVector.Unit
	elseif axisName == "Y" then
		return Vector3.yAxis
	elseif axisName == "Z" then
		return pivot.LookVector.Unit
	end
	return getCourseDirection() or pivot.RightVector.Unit
end

local function createHammerSound(soundParent)
	local sound = soundParent:FindFirstChild("VortexHammerWhoosh")
	if sound and not sound:IsA("Sound") then
		sound:Destroy()
		sound = nil
	end
	if not sound then
		sound = Instance.new("Sound")
		sound.Name = "VortexHammerWhoosh"
		sound.Parent = soundParent
	end
	                                                                          
	                                                                    
	sound.SoundId = HAMMER_WHOOSH_SOUND_ID
	sound.Volume = HAMMER_WHOOSH_VOLUME
	sound.PlaybackSpeed = 1
	sound.Looped = false
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 8
	sound.RollOffMaxDistance = 85
	return sound
end

local function snapshotRecord(record)
	record.PreviousCenter = record.CurrentCenter
	for part in pairs(record.OriginCFrames) do
		if part.Parent then
			record.PreviousCFrames[part] = part.CFrame
		end
	end
end

local function setRecordPivot(record, targetPivot)
	local transform = targetPivot * record.OriginPivot:Inverse()
	for part, originCFrame in pairs(record.OriginCFrames) do
		if part.Parent then
			part.CFrame = transform * originCFrame
		end
	end
	record.CurrentCenter = (transform * record.BoundsCFrame).Position
end

local function setPartsFromWorldTransform(record, transform)
	for part, originCFrame in pairs(record.OriginCFrames) do
		if part.Parent then
			part.CFrame = transform * originCFrame
		end
	end
	record.CurrentCenter = (transform * record.BoundsCFrame).Position
end

local function objectDepth(object)
	local depth = 0
	local current = object
	while current and current ~= mapRoot do
		depth += 1
		current = current.Parent
	end
	return depth
end

local function sizeLooksCylinderLike(size)
	local values = { size.X, size.Y, size.Z }
	table.sort(values)
	if values[1] < 8 or values[3] < 12 then
		return false
	end
	                                                                          
	                                                                             
	local pair12 = values[2] / math.max(values[1], 0.001)
	local pair23 = values[3] / math.max(values[2], 0.001)
	return pair12 <= 1.18 or pair23 <= 1.18
end

local function isCylinderGeometryPart(object)
	if not object:IsA("BasePart") or normalizeName(object.Name) == "cylinderstop" then
		return false
	end
	if object:IsA("Part") and object.Shape == Enum.PartType.Cylinder then
		return true
	end
	if object:FindFirstChildOfClass("CylinderMesh") then
		return true
	end
	local mesh = object:FindFirstChildOfClass("SpecialMesh")
	if mesh then
		if mesh.MeshType == Enum.MeshType.Cylinder then
			return true
		end
		                                                                       
		                                                                          
		                                                                
		if sizeLooksCylinderLike(object.Size) then
			return true
		end
	end
	                                                                          
	                                                                             
	                                                                   
	                                                                          
	                       
	if object:IsA("MeshPart") or object:IsA("UnionOperation") then
		return sizeLooksCylinderLike(object.Size)
	end
	return false
end

local function isInsideOtherNamedHazard(object)
	local current = object.Parent
	while current and current ~= mapRoot do
		local name = normalizeName(current.Name)
		if name:match("^hammer[1-5]$")
			or name:match("^pressdown[1-3]$")
			or name == "fast"
			or name == "laserplatform"
			or name == "slide1"
			or name == "slide2"
			or name == "lavaup"
			or name == "bridge"
		then
			return true
		end
		current = current.Parent
	end
	return false
end

local cylinderFallbackCandidates = {}

local interestingNames = {
	cylinder = true,
	cylinder1 = true,
	rollingcylinder = true,
	cylinderstart = true,
	cylinderstop = true,
	laserplatform = true,
	laser = true,
	slide1 = true,
	slide2 = true,
	fast = true,
	hitbox = true,
	fastend = true,
	lavaup = true,
	lava = true,
	bridge = true,
}
for index = 1, 5 do
	interestingNames["hammer" .. index] = true
end
for index = 1, 3 do
	interestingNames["pressdown" .. index] = true
	interestingNames["pressdown" .. index .. "stop"] = true
	interestingNames["pressdownstop" .. index] = true
end

local candidatesByName = {}
local function registerCandidate(object)
	local registeredFallback = false
	if isCylinderGeometryPart(object) and not isInsideOtherNamedHazard(object) then
		cylinderFallbackCandidates[object] = true
		registeredFallback = true
	end

	local normalized = normalizeName(object.Name)
	if not interestingNames[normalized] then
		return registeredFallback
	end
	local bucket = candidatesByName[normalized]
	if not bucket then
		bucket = {}
		candidatesByName[normalized] = bucket
	end
	bucket[object] = true
	return true
end

local function getNamedObjects(normalizedName)
	local result = {}
	for object in pairs(candidatesByName[normalizedName] or {}) do
		if object.Parent and object:IsDescendantOf(mapRoot) then
			table.insert(result, object)
		end
	end
	table.sort(result, function(left, right)
		local leftDepth = objectDepth(left)
		local rightDepth = objectDepth(right)
		if leftDepth ~= rightDepth then
			return leftDepth < rightDepth
		end
		return left:GetFullName() < right:GetFullName()
	end)
	return result
end

local function getNamedObject(normalizedName)
	return getNamedObjects(normalizedName)[1]
end

local function getNamedObjectAny(names)
	for _, name in ipairs(names) do
		local object = getNamedObject(name)
		if object then
			return object
		end
	end
	return nil
end

local CYLINDER_SEARCH_RADIUS = 500
local CYLINDER_MAX_VERTICAL_OFFSET = 100
local CYLINDER_MIN_TRAVEL_DISTANCE = 8

local function resolveCylinderGeometryPart(part)
	                                                                       
	                                                                           
	                                      
	if part and part:IsA("BasePart") and isCylinderGeometryPart(part) then
		return part
	end
	return nil
end

local function isInsideCylinderStop(object)
	local current = object
	while current and current ~= Workspace do
		if normalizeName(current.Name) == "cylinderstop" then
			return true
		end
		current = current.Parent
	end
	return false
end

local function scoreCylinderPart(part, stopPosition)
	if not part
		or not part.Parent
		or isInsideOtherNamedHazard(part)
		or isInsideCylinderStop(part)
		or not sizeLooksCylinderLike(part.Size)
	then
		return nil
	end
	local authoredCFrame = getCFrameAttribute(part, ORIGIN_CFRAME_ATTRIBUTE) or part.CFrame
	local offset = authoredCFrame.Position - stopPosition
	local horizontalDistance = Vector3.new(offset.X, 0, offset.Z).Magnitude
	local verticalDistance = math.abs(offset.Y)
	local travelDistance = offset.Magnitude
	if travelDistance < CYLINDER_MIN_TRAVEL_DISTANCE
		or horizontalDistance > CYLINDER_SEARCH_RADIUS
		or verticalDistance > CYLINDER_MAX_VERTICAL_OFFSET
	then
		return nil
	end
	return horizontalDistance + verticalDistance * 4
end

local function pickBestCylinderPart(parts, stopPosition, requireInsideMap)
	local bestPart = nil
	local bestScore = math.huge
	for _, part in ipairs(parts) do
		if part:IsA("BasePart")
			and normalizeName(part.Name) ~= "cylinderstop"
			and (not requireInsideMap or part:IsDescendantOf(mapRoot))
			and isCylinderGeometryPart(part)
		then
			local score = scoreCylinderPart(part, stopPosition)
			if score and (score < bestScore
				or (math.abs(score - bestScore) < 0.001
					and bestPart
					and part:GetFullName() < bestPart:GetFullName()))
			then
				bestPart = part
				bestScore = score
			end
		end
	end
	return bestPart
end

local function resolveNamedCylinderPart(named, stopPosition)
	if not named or not stopPosition then
		return nil
	end
	if named:IsA("BasePart") then
		return resolveCylinderGeometryPart(named)
	end
	                                                                        
	return pickBestCylinderPart(collectBaseParts(named), stopPosition, false)
end

local function getCylinderObject(stopPosition)
	local named = getNamedObjectAny({ "cylinder", "cylinder1", "rollingcylinder", "cylinderstart" })
	if named and stopPosition then
		local namedPart = resolveNamedCylinderPart(named, stopPosition)
		if namedPart then
			return namedPart, false, "named-exact-cylinder-part-under-neworld1"
		end
	end
	if not stopPosition then
		return nil, false, "missing-cylinderstop"
	end

	                                                                       
	local cachedParts = {}
	for part in pairs(cylinderFallbackCandidates) do
		if part.Parent and part:IsDescendantOf(mapRoot) then
			table.insert(cachedParts, part)
		end
	end
	local bestPart = pickBestCylinderPart(cachedParts, stopPosition, true)
	if bestPart then
		return resolveCylinderGeometryPart(bestPart), true, "geometry-under-neworld1"
	end

	                                                                            
	                                                                  
	                                                                            
	                                                  
	local spatialParts = Workspace:GetPartBoundsInRadius(stopPosition, CYLINDER_SEARCH_RADIUS)
	bestPart = pickBestCylinderPart(spatialParts, stopPosition, false)
	if bestPart then
		return resolveCylinderGeometryPart(bestPart), true, "spatial-cylinder-near-neworld1-stop"
	end

	return nil, false, "no-real-cylinder-geometry-found"
end

local function findExactDescendant(object, normalizedName, className)
	for _, descendant in ipairs(object:GetDescendants()) do
		if normalizeName(descendant.Name) == normalizedName
			and (not className or descendant:IsA(className))
		then
			return descendant
		end
	end
	return nil
end

local function getMarkerPosition(object)
	local pivot = object and getObjectPivot(object)
	return pivot and pivot.Position or nil
end

                                                                               
                                                                              
                                                                               
                                                   
local function getPartsProjectionRange(parts, axis, cframeOverrides)
	local minimum = math.huge
	local maximum = -math.huge
	for _, part in ipairs(parts) do
		if part.Parent then
			local cframe = cframeOverrides and cframeOverrides[part]
				or getCFrameAttribute(part, ORIGIN_CFRAME_ATTRIBUTE)
				or part.CFrame
			local half = part.Size * 0.5
			for xSign = -1, 1, 2 do
				for ySign = -1, 1, 2 do
					for zSign = -1, 1, 2 do
						local corner = cframe:PointToWorldSpace(Vector3.new(
							half.X * xSign,
							half.Y * ySign,
							half.Z * zSign
						))
						local projection = corner:Dot(axis)
						minimum = math.min(minimum, projection)
						maximum = math.max(maximum, projection)
					end
				end
			end
		end
	end
	if minimum == math.huge or maximum == -math.huge then
		return nil, nil
	end
	return minimum, maximum
end

local function getCylinderSurfaceHit(x, z, expectedY)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { mapRoot }
	params.RespectCanCollide = true

	local origin = Vector3.new(x, expectedY + CYLINDER_PATH_PROBE_UP, z)
	local direction = Vector3.new(0, -(CYLINDER_PATH_PROBE_UP + CYLINDER_PATH_PROBE_DOWN), 0)
	local hit = Workspace:Raycast(origin, direction, params)
	if not hit or not hit.Instance or hit.Normal.Y < CYLINDER_MIN_SURFACE_NORMAL_Y then
		return nil
	end
	return hit
end

local function inferCylinderRadius(boundsSize)
	local values = { boundsSize.X, boundsSize.Y, boundsSize.Z }
	table.sort(values)
	local lowerPairDifference = math.abs(values[2] - values[1])
	local upperPairDifference = math.abs(values[3] - values[2])
	if lowerPairDifference <= upperPairDifference then
		return math.max(0.5, (values[1] + values[2]) * 0.25)
	end
	return math.max(0.5, (values[2] + values[3]) * 0.25)
end

local function cylinderMetrics(part)
	local size = part.Size
	if part:IsA("Part") and part.Shape == Enum.PartType.Cylinder then
		                                                          
		return "X", math.max(0.05, size.X * 0.5 - 0.03), math.max(0.05, math.min(size.Y, size.Z) * 0.5 - 0.03)
	end
	                                                                            
	                                                                         
	local yz = math.abs(size.Y - size.Z) / math.max(size.Y, size.Z, 0.001)
	local xz = math.abs(size.X - size.Z) / math.max(size.X, size.Z, 0.001)
	local xy = math.abs(size.X - size.Y) / math.max(size.X, size.Y, 0.001)
	if yz <= xz and yz <= xy then
		return "X", math.max(0.05, size.X * 0.5 - 0.03), math.max(0.05, math.min(size.Y, size.Z) * 0.5 - 0.03)
	elseif xz <= xy then
		return "Y", math.max(0.05, size.Y * 0.5 - 0.03), math.max(0.05, math.min(size.X, size.Z) * 0.5 - 0.03)
	end
	return "Z", math.max(0.05, size.Z * 0.5 - 0.03), math.max(0.05, math.min(size.X, size.Y) * 0.5 - 0.03)
end

local function pointInsideExactCylinder(point, part)
	local localPoint = part.CFrame:PointToObjectSpace(point)
	local axis, halfLength, radius = cylinderMetrics(part)
	local axial, radialA, radialB
	if axis == "X" then
		axial, radialA, radialB = localPoint.X, localPoint.Y, localPoint.Z
	elseif axis == "Y" then
		axial, radialA, radialB = localPoint.Y, localPoint.X, localPoint.Z
	else
		axial, radialA, radialB = localPoint.Z, localPoint.X, localPoint.Y
	end
	return math.abs(axial) <= halfLength and radialA * radialA + radialB * radialB <= radius * radius
end

local function characterTouchesExactCylinder(character, root, cylinderPart)
	if not character or not root or not cylinderPart or not cylinderPart.Parent then
		return false
	end
	                                                        
	if (root.Position - cylinderPart.Position).Magnitude > cylinderPart.Size.Magnitude + 10 then
		return false
	end
	                                                                            
	                                                                                
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("BasePart") and pointInsideExactCylinder(child.Position, cylinderPart) then
			return true
		end
	end
	return false
end

local function buildCylinderSurfacePath(record, stopPosition, radius)
	                                                                           
	                                                                           
	                                                                             
	local startCenter = record.BoundsCFrame.Position
	local horizontalDelta = Vector3.new(
		stopPosition.X - startCenter.X,
		0,
		stopPosition.Z - startCenter.Z
	)
	local horizontalDistance = horizontalDelta.Magnitude
	if horizontalDistance < 0.001 then
		return { startCenter }, { Vector3.yAxis }, 0, 0, { 0 }
	end

	local points = { startCenter }
	local normals = { Vector3.yAxis }
	local surfaceHits = 0
	local sampleCount = math.max(1, math.ceil(horizontalDistance / CYLINDER_PATH_SAMPLE_SPACING))
	local expectedY = startCenter.Y

	for sampleIndex = 1, sampleCount do
		local alpha = sampleIndex / sampleCount
		local x = startCenter.X + horizontalDelta.X * alpha
		local z = startCenter.Z + horizontalDelta.Z * alpha
		local hit = getCylinderSurfaceHit(x, z, expectedY)
		local point
		local normal
		if hit then
			normal = hit.Normal.Unit
			                                                                      
			                                                                      
			local verticalClearance = radius / math.max(normal.Y, CYLINDER_MIN_SURFACE_NORMAL_Y)
			point = Vector3.new(x, hit.Position.Y + verticalClearance, z)
			expectedY = point.Y
			surfaceHits += 1
		else
			                                                                         
			                                                                     
			point = Vector3.new(x, expectedY, z)
			normal = normals[#normals]
		end
		table.insert(points, point)
		table.insert(normals, normal)
	end

	local cumulative = { 0 }
	local totalDistance = 0
	for index = 2, #points do
		totalDistance += (points[index] - points[index - 1]).Magnitude
		cumulative[index] = totalDistance
	end

	return points, normals, totalDistance, surfaceHits, cumulative
end

local function sampleCylinderPath(system, distanceAlongPath)
	local points = system.PathPoints
	local cumulative = system.PathCumulative
	if #points <= 1 or system.PathDistance <= 0 then
		return points[1] or system.StartCenter, Vector3.yAxis
	end

	local targetDistance = math.clamp(distanceAlongPath, 0, system.PathDistance)
	local low = 2
	local high = #points
	while low < high do
		local middle = math.floor((low + high) * 0.5)
		if cumulative[middle] < targetDistance then
			low = middle + 1
		else
			high = middle
		end
	end
	local segmentIndex = low

	local previousDistance = cumulative[segmentIndex - 1] or 0
	local segmentDistance = math.max(0.0001, cumulative[segmentIndex] - previousDistance)
	local alpha = math.clamp((targetDistance - previousDistance) / segmentDistance, 0, 1)
	local position = points[segmentIndex - 1]:Lerp(points[segmentIndex], alpha)
	local normal = system.PathNormals[segmentIndex - 1]:Lerp(system.PathNormals[segmentIndex], alpha)
	if normal.Magnitude < 0.001 then
		normal = Vector3.yAxis
	else
		normal = normal.Unit
	end
	return position, normal
end

local systems = {
	Cylinder = nil,
	Hammers = {},
	Lasers = {},
	Presses = {},
	Slides = nil,
	Fast = nil,
	LavaUp = nil,
	Bridge = nil,
	StaticLava = {},
}
local movingRecords = {}
local lethalGroups = {}

local function addMovingRecord(record)
	if record then
		table.insert(movingRecords, record)
	end
	return record
end

local function addLethalGroup(hazardKey, record, parts, radius, centerPart)
	for _, part in ipairs(parts) do
		if part and part.Parent then
			part:SetAttribute("NewWorld1HazardKey", hazardKey)
		end
	end
	table.insert(lethalGroups, {
		HazardKey = hazardKey,
		Record = record,
		Parts = parts,
		Radius = radius,
		CenterPart = centerPart,
	})
end

local function sineEase(alpha)
	return 0.5 - math.cos(math.clamp(alpha, 0, 1) * math.pi) * 0.5
end

local function rebuildSystems()
	for _, group in ipairs(lethalGroups) do
		for _, part in ipairs(group.Parts) do
			if part and part.Parent and part:GetAttribute("NewWorld1HazardKey") == group.HazardKey then
				part:SetAttribute("NewWorld1HazardKey", nil)
			end
			if part and part.Parent and part:GetAttribute("NewWorld1ExactHammerHazardKBM") == true then
				part:SetAttribute("NewWorld1ExactHammerHazardKBM", nil)
			end
		end
	end
	local previousCylinder = systems.Cylinder
	if previousCylinder and previousCylinder.HazardPart and previousCylinder.HazardPart.Parent then
		previousCylinder.HazardPart:SetAttribute("NewWorld1ExactCylinderHazardKBJ", nil)
		previousCylinder.HazardPart:SetAttribute("NewWorld1CylinderLethalActiveKBJ", nil)
	end
	table.clear(movingRecords)
	table.clear(lethalGroups)
	systems.Cylinder = nil
	table.clear(systems.Hammers)
	table.clear(systems.Lasers)
	table.clear(systems.Presses)
	systems.Slides = nil
	systems.Fast = nil
	systems.LavaUp = nil
	systems.Bridge = nil
	table.clear(systems.StaticLava)

	mapRoot:SetAttribute("NewWorld1CylinderBoundPath", nil)
	mapRoot:SetAttribute("NewWorld1CylinderBoundClass", nil)
	mapRoot:SetAttribute("NewWorld1CylinderPartCount", nil)
	local cylinderStopObject = getNamedObject("cylinderstop")
	local cylinderStopPosition = getMarkerPosition(cylinderStopObject)
	local cylinderObject, cylinderUsedFallback, cylinderBindSource = getCylinderObject(cylinderStopPosition)
	for candidate in pairs(cylinderFallbackCandidates) do
		if candidate.Parent and candidate:GetAttribute("NewWorld1CylinderGeometryFallbackKBH") == true then
			candidate:SetAttribute("NewWorld1CylinderGeometryFallbackKBH", false)
		end
	end
	mapRoot:SetAttribute("NewWorld1CylinderFallbackBoundKBH", cylinderUsedFallback == true)
	mapRoot:SetAttribute("NewWorld1CylinderBindSource", cylinderBindSource)
	if not cylinderObject then
		warn(
			"[NewWorld1ServerMotion] V306KBJ cylinder bind FAILED | source="
				.. tostring(cylinderBindSource)
				.. " | cylinderstop="
				.. tostring(cylinderStopObject and cylinderStopObject:GetFullName() or "MISSING")
		)
	end

	if cylinderObject and cylinderStopPosition then
		if cylinderUsedFallback then
			cylinderObject:SetAttribute("NewWorld1CylinderGeometryFallbackKBH", true)
		end
		local record = addMovingRecord(makeMotionRecord(cylinderObject))
		if record then
			mapRoot:SetAttribute("NewWorld1CylinderBoundPath", cylinderObject:GetFullName())
			mapRoot:SetAttribute("NewWorld1CylinderBoundClass", cylinderObject.ClassName)
			mapRoot:SetAttribute("NewWorld1CylinderPartCount", #record.Parts)
			for _, part in ipairs(record.Parts) do
				part.CanCollide = false
				part.CanTouch = false
				part.CanQuery = true
			end
			local startCenter = record.BoundsCFrame.Position
			local displacement = cylinderStopPosition - startCenter
			local horizontalDirection = Vector3.new(displacement.X, 0, displacement.Z)
			horizontalDirection = horizontalDirection.Magnitude > 0.001
				and horizontalDirection.Unit
				or horizontalUnit(record.OriginPivot.LookVector)
				or Vector3.zAxis
			local rollAxis = Vector3.yAxis:Cross(horizontalDirection)
			rollAxis = rollAxis.Magnitude < 0.001 and record.OriginPivot.RightVector or rollAxis.Unit
			local radius = inferCylinderRadius(record.BoundsSize)

			                                                                          
			                                                                     
			for _, part in ipairs(record.Parts) do
				part.CanCollide = false
				part.CanTouch = false
				part.CanQuery = false
			end
			local pathPoints, pathNormals, pathDistance, surfaceHits, pathCumulative =
				buildCylinderSurfacePath(record, cylinderStopPosition, radius)
			for _, part in ipairs(record.Parts) do
				                                                                       
				                                                                       
				part.CanCollide = true
				part.CanTouch = false
				part.CanQuery = true
				part:SetAttribute("NewWorld1PhysicalCylinderKBO", true)
			end

			local hazardPart = record.Parts[1]
			if hazardPart then
				hazardPart:SetAttribute("NewWorld1ExactCylinderHazardKBJ", true)
				hazardPart:SetAttribute("NewWorld1CylinderLethalActiveKBJ", false)
			end
			systems.Cylinder = {
				Record = record,
				HazardPart = hazardPart,
				LethalActive = false,
				StartPivot = record.OriginPivot,
				StartCenter = startCenter,
				PivotOffset = record.OriginPivot.Position - startCenter,
				EndPosition = cylinderStopPosition,
				Distance = displacement.Magnitude,
				PathPoints = pathPoints,
				PathNormals = pathNormals,
				PathCumulative = pathCumulative,
				PathDistance = pathDistance,
				SurfaceHits = surfaceHits,
				TravelTime = math.max(0.35, pathDistance / CYLINDER_SPEED),
				RollAxis = rollAxis,
				Radius = radius,
			}
			mapRoot:SetAttribute("NewWorld1CylinderTravelDistance", pathDistance)
			mapRoot:SetAttribute("NewWorld1CylinderStartPosition", startCenter)
			mapRoot:SetAttribute("NewWorld1CylinderStopPosition", cylinderStopPosition)
			mapRoot:SetAttribute("NewWorld1CylinderSurfacePathPoints", #pathPoints)
			mapRoot:SetAttribute("NewWorld1CylinderSurfaceHits", surfaceHits)
			print(
				"[NewWorld1ServerMotion] V306KBJ CYLINDER BOUND | source="
					.. tostring(cylinderBindSource)
					.. " | object="
					.. cylinderObject:GetFullName()
					.. " | class="
					.. cylinderObject.ClassName
					.. " | parts="
					.. tostring(#record.Parts)
					.. " | surfacePath="
					.. string.format("%.2f", pathDistance)
					.. " | pathPoints="
					.. tostring(#pathPoints)
					.. " | surfaceHits="
					.. tostring(surfaceHits)
			)
			                                                                       
			                                                              
		end
	end

	for index = 1, 5 do
		local hammerObject = getNamedObject("hammer" .. index)
		if hammerObject then
			local movingParts, stationaryParts, pivotPosition, shaftPart = splitHammerParts(hammerObject)
			if #movingParts > 0 and pivotPosition then
				local movingSet = {}
				for _, part in ipairs(movingParts) do
					movingSet[part] = true
				end
				for _, part in ipairs(stationaryParts) do
					part.Anchored = true
					part.AssemblyLinearVelocity = Vector3.zero
					part.AssemblyAngularVelocity = Vector3.zero
				end
				disableCrossSupportJoints(hammerObject, movingSet)

				local pivot = pivotPosition and CFrame.new(pivotPosition) or nil
				local boundsCFrame = getCFrameAttribute(hammerObject, BOUNDS_CFRAME_ATTRIBUTE)
				local boundsSize = getVectorAttribute(hammerObject, BOUNDS_SIZE_ATTRIBUTE)
				if not boundsCFrame or not boundsSize then
					boundsCFrame, boundsSize = getPartsBounds(movingParts)
				end
				local record = addMovingRecord(
					makeSelectedMotionRecord(hammerObject, movingParts, pivot, boundsCFrame, boundsSize)
				)
				if record then
					local axisName = tostring(hammerObject:GetAttribute("SwingAxis") or "COURSE"):upper()
					if axisName ~= "X" and axisName ~= "Y" and axisName ~= "Z" and axisName ~= "COURSE" then
						axisName = "COURSE"
					end
					local worldAxis = getHammerWorldAxis(axisName, pivot)
					local phaseOffset = HAMMER_PHASE_OFFSETS[index] or ((index - 1) * math.pi)
					local currentPhase = phaseOffset
						+ math.max(0, Workspace:GetServerTimeNow() - motionStartServerTime) * HAMMER_ANGULAR_SPEED
					local sound = createHammerSound(shaftPart or movingParts[1])
					table.insert(systems.Hammers, {
						Record = record,
						Index = index,
						PivotPosition = pivot.Position,
						Axis = worldAxis,
						PhaseOffset = phaseOffset,
						Sound = sound,
						LastCenterCrossing = math.floor(currentPhase / math.pi),
					})
					hammerObject:SetAttribute("V306KBGHammerSwing", true)
					hammerObject:SetAttribute("V306KBHHammerSwing", true)
					hammerObject:SetAttribute("MovingSwingParts", #movingParts)
					hammerObject:SetAttribute("StationaryTopParts", #stationaryParts)
					if shaftPart then
						hammerObject:SetAttribute("ResolvedShaftPart", shaftPart:GetFullName())
					end
					hammerObject:SetAttribute("ResolvedSwingPivot", pivot.Position)
					hammerObject:SetAttribute("ResolvedSwingAxis", axisName)
					hammerObject:SetAttribute("WhooshSoundId", HAMMER_WHOOSH_SOUND_ID)
					for _, hammerPart in ipairs(record.Parts) do
						                                                                 
						                                                                   
						hammerPart.CanCollide = true
						hammerPart.CanTouch = false
						hammerPart.CanQuery = true
						hammerPart:SetAttribute("NewWorld1ExactHammerHazardKBM", true)
						hammerPart:SetAttribute("NewWorld1PhysicalHammerKBO", true)
					end
					addLethalGroup("Hammer", record, record.Parts, record.Radius)
					print(
						"[NewWorld1ServerMotion] V306KBH Hammer"
							.. tostring(index)
							.. " exact authored split | moving="
							.. tostring(#movingParts)
							.. " fixedTop="
							.. tostring(#stationaryParts)
					)
				end
			else
				warn(
					"[NewWorld1ServerMotion] V306KBH Hammer"
						.. tostring(index)
						.. " did not match the supplied authored shaft/top-support geometry; not guessing a split."
				)
			end
		end
	end

	local seenLasers = {}
	for platformIndex, platform in ipairs(getNamedObjects("laserplatform")) do
		local laser = findExactDescendant(platform, "laser", "BasePart")
		if laser and not seenLasers[laser] then
			seenLasers[laser] = true
			local record = addMovingRecord(makeMotionRecord(laser))
			if record then
				table.insert(systems.Lasers, {
					Record = record,
					Center = record.OriginPivot.Position,
					Direction = platformIndex % 2 == 0 and -1 or 1,
					PhaseOffset = (platformIndex - 1) * math.rad(37),
				})
				addLethalGroup("Laser", record, record.Parts, record.Radius)
			end
		end
	end

	for index = 1, 3 do
		local object = getNamedObject("pressdown" .. index)
		local stopObject = getNamedObject("pressdown" .. index .. "stop")
			or getNamedObject("pressdownstop" .. index)
		local stopPosition = getMarkerPosition(stopObject)
		local record = object and stopPosition and addMovingRecord(makeMotionRecord(object)) or nil
		if record and stopObject then
			local towardStop = stopPosition - record.OriginPivot.Position
			local stopParts = collectBaseParts(stopObject)
			if towardStop.Magnitude > 0.001 and #stopParts > 0 then
				local travelAxis = towardStop.Unit
				local _, movingLeadingProjection = getPartsProjectionRange(
					record.Parts,
					travelAxis,
					record.OriginCFrames
				)
				local stopNearProjection = getPartsProjectionRange(stopParts, travelAxis)
				if movingLeadingProjection and stopNearProjection then
					                                                                    
					                                                                  
					                                                                  
					                                                                       
					local surfaceTravel = stopNearProjection - movingLeadingProjection
					if surfaceTravel >= 0 then
						                                                                        
						                                                                      
						                                                          
						local totalTravel = surfaceTravel + PRESS_EXTRA_LOWER_STUDS
						local endPivot = record.OriginPivot + travelAxis * totalTravel
						local distance = totalTravel
						table.insert(systems.Presses, {
							Record = record,
							Index = index,
							TopPivot = record.OriginPivot,
							BottomPivot = endPivot,
							DownTime = math.max(0.16, distance / PRESS_DOWN_SPEED),
							UpTime = math.max(0.45, distance / PRESS_UP_SPEED),
						})
						addLethalGroup("PressDown", record, record.Parts, record.Radius)
						print(
							"[NewWorld1ServerMotion] V306KBM pressdown"
								.. tostring(index)
								.. " surface-stop+7 bound | surfaceTravel="
								.. string.format("%.3f", surfaceTravel)
								.. " | totalTravel="
								.. string.format("%.3f", totalTravel)
								.. " | stop="
								.. stopObject:GetFullName()
						)
					else
						warn(
							"[NewWorld1ServerMotion] V306KBM pressdown"
								.. tostring(index)
								.. " authored geometry already overlaps its stop; refusing to guess a target."
						)
					end
				end
			end
		end
	end

	local slideRecord1 = makeMotionRecord(getNamedObject("slide1"))
	local slideRecord2 = makeMotionRecord(getNamedObject("slide2"))
	if slideRecord1 and slideRecord2 then
		addMovingRecord(slideRecord1)
		addMovingRecord(slideRecord2)
		local direction = slideRecord2.OriginPivot.Position - slideRecord1.OriginPivot.Position
		direction = direction.Magnitude < 0.001 and Vector3.xAxis or direction.Unit
		local partStates = {}
		for _, record in { slideRecord1, slideRecord2 } do
			for _, part in ipairs(record.Parts) do
				partStates[part] = {
					Transparency = tonumber(part:GetAttribute(TRANSPARENCY_ATTRIBUTE)) or part.Transparency,
					CanCollide = part.CanCollide,
					CanTouch = part.CanTouch,
				}
			end
		end
		systems.Slides = {
			First = slideRecord1,
			Second = slideRecord2,
			FirstOut = slideRecord1.OriginPivot - direction * SLIDE_OUTWARD_DISTANCE,
			SecondOut = slideRecord2.OriginPivot + direction * SLIDE_OUTWARD_DISTANCE,
			PartStates = partStates,
		}
	end

	local fastObject = getNamedObject("fast")
	local fastEndPosition = getMarkerPosition(getNamedObject("fastend"))
	local fastRecord = fastObject and fastEndPosition and addMovingRecord(makeMotionRecord(fastObject)) or nil
	if fastRecord then
		local hitbox = findExactDescendant(fastObject, "hitbox", "BasePart")
		if hitbox then
			local translation = fastEndPosition - (getCFrameAttribute(hitbox, ORIGIN_CFRAME_ATTRIBUTE) or hitbox.CFrame).Position
			systems.Fast = {
				Record = fastRecord,
				Hitbox = hitbox,
				StartPivot = fastRecord.OriginPivot,
				EndPivot = fastRecord.OriginPivot + translation,
				TravelTime = math.clamp(translation.Magnitude / FAST_SPEED, 0.5, 30),
			}
			addLethalGroup("Fast", fastRecord, { hitbox }, hitbox.Size.Magnitude * 0.5, hitbox)
		end
	end

	local lavaRecord = addMovingRecord(makeMotionRecord(getNamedObject("lavaup")))
	if lavaRecord then
		systems.LavaUp = {
			Record = lavaRecord,
			BottomPivot = lavaRecord.OriginPivot,
			TopPivot = lavaRecord.OriginPivot + Vector3.new(0, LAVA_RISE_STUDS, 0),
			UpTime = LAVA_RISE_STUDS / LAVA_UP_SPEED,
			DownTime = LAVA_RISE_STUDS / LAVA_DOWN_SPEED,
		}
		addLethalGroup("LavaUp", lavaRecord, lavaRecord.Parts, lavaRecord.Radius)
	end

	local bridgeRecord = makeMotionRecord(getNamedObject("bridge"))
	if bridgeRecord then
		local partStates = {}
		for _, part in ipairs(bridgeRecord.Parts) do
			partStates[part] = {
				Transparency = tonumber(part:GetAttribute(TRANSPARENCY_ATTRIBUTE)) or part.Transparency,
				CanCollide = part:GetAttribute(CAN_COLLIDE_ATTRIBUTE) == true,
				CanTouch = part:GetAttribute(CAN_TOUCH_ATTRIBUTE) == true,
				CanQuery = part:GetAttribute(CAN_QUERY_ATTRIBUTE) == true,
			}
		end
		local visuals = {}
		for _, descendant in ipairs(bridgeRecord.Object:GetDescendants()) do
			if descendant:IsA("Decal") or descendant:IsA("Texture") then
				table.insert(visuals, {
					Object = descendant,
					Transparency = tonumber(descendant:GetAttribute(TRANSPARENCY_ATTRIBUTE)) or descendant.Transparency,
				})
			end
		end
		systems.Bridge = {
			Record = bridgeRecord,
			PartStates = partStates,
			Visuals = visuals,
		}
	end

	for _, lavaObject in ipairs(getNamedObjects("lava")) do
		if lavaObject:IsA("BasePart") then
			preservePartState(lavaObject)
			table.insert(systems.StaticLava, lavaObject)
			addLethalGroup("Lava", nil, { lavaObject }, lavaObject.Size.Magnitude * 0.5, lavaObject)
		end
	end

	mapRoot:SetAttribute("NewWorld1ServerMotionRecords", #movingRecords)
	mapRoot:SetAttribute("NewWorld1ServerLethalGroups", #lethalGroups)
	mapRoot:SetAttribute("NewWorld1ServerMotionReadyVersion", "V306KBR")
end

local function setCylinderLethalActive(system, active)
	if not system or system.LethalActive == active then
		return
	end
	system.LethalActive = active
	if system.HazardPart and system.HazardPart.Parent then
		system.HazardPart:SetAttribute("NewWorld1CylinderLethalActiveKBJ", active)
	end
end

local function updateCylinder(serverTime)
	local system = systems.Cylinder
	if not system or not system.Record.Object.Parent then
		return
	end

	local cycle = CYLINDER_START_WAIT + system.TravelTime + CYLINDER_STOP_WAIT
	local phase = serverTime % cycle
	if phase <= CYLINDER_START_WAIT then
		                                                                        
		setCylinderLethalActive(system, false)
		setRecordPivot(system.Record, system.StartPivot)
		return
	end

	setCylinderLethalActive(system, true)
	local travelElapsed = math.min(system.TravelTime, phase - CYLINDER_START_WAIT)
	local distanceAlongPath = math.min(system.PathDistance, travelElapsed * CYLINDER_SPEED)
	local centerPosition = sampleCylinderPath(system, distanceAlongPath)

	local angle = distanceAlongPath / system.Radius
	local rotationOnly = system.StartPivot - system.StartPivot.Position
	local pivotPosition = centerPosition + system.PivotOffset
	local pivot = CFrame.new(pivotPosition)
		* CFrame.fromAxisAngle(system.RollAxis, angle)
		* rotationOnly
	setRecordPivot(system.Record, pivot)
end

local function updateHammers(serverTime)
	for _, system in ipairs(systems.Hammers) do
		if system.Record.Object.Parent then
			local phase = system.PhaseOffset + serverTime * HAMMER_ANGULAR_SPEED
			local angle = math.sin(phase) * HAMMER_SWING_ANGLE
			local transform = CFrame.new(system.PivotPosition)
				* CFrame.fromAxisAngle(system.Axis, angle)
				* CFrame.new(-system.PivotPosition)
			setPartsFromWorldTransform(system.Record, transform)

			local centerCrossing = math.floor(phase / math.pi)
			if centerCrossing ~= system.LastCenterCrossing then
				system.LastCenterCrossing = centerCrossing
				if system.Sound and system.Sound.Parent then
					system.Sound:Stop()
					system.Sound.TimePosition = 0
					system.Sound:Play()
				end
			end
		end
	end
end

local function updateLasers(serverTime)
	for _, system in ipairs(systems.Lasers) do
		if system.Record.Object.Parent then
			local spinPeriod = TAU / LASER_ANGULAR_SPEED
			local angle = (serverTime % spinPeriod) * LASER_ANGULAR_SPEED
			angle = angle * system.Direction + system.PhaseOffset
			local transform = CFrame.new(system.Center)
				* CFrame.Angles(0, angle, 0)
				* CFrame.new(-system.Center)
			setPartsFromWorldTransform(system.Record, transform)
		end
	end
end

local function updatePresses(serverTime)
	                                                                            
	                                                                              
	                                                                               
	                                                                                       
	if #systems.Presses == 0 then
		return
	end

	local latestDownFinish = PRESS_TOP_WAIT
	for _, system in ipairs(systems.Presses) do
		local downStart = PRESS_TOP_WAIT + (system.Index - 1) * PRESS_SEQUENCE_STAGGER
		latestDownFinish = math.max(latestDownFinish, downStart + system.DownTime)
	end
	local upBase = latestDownFinish + PRESS_BOTTOM_WAIT
	local latestUpFinish = upBase
	for _, system in ipairs(systems.Presses) do
		local upStart = upBase + (system.Index - 1) * PRESS_SEQUENCE_STAGGER
		latestUpFinish = math.max(latestUpFinish, upStart + system.UpTime)
	end
	local cycle = latestUpFinish
	local phase = serverTime % cycle

	for _, system in ipairs(systems.Presses) do
		local downStart = PRESS_TOP_WAIT + (system.Index - 1) * PRESS_SEQUENCE_STAGGER
		local downEnd = downStart + system.DownTime
		local upStart = upBase + (system.Index - 1) * PRESS_SEQUENCE_STAGGER
		local upEnd = upStart + system.UpTime
		local pivot
		if phase < downStart then
			pivot = system.TopPivot
		elseif phase < downEnd then
			local alpha = (phase - downStart) / system.DownTime
			pivot = system.TopPivot:Lerp(system.BottomPivot, alpha ^ 3)
		elseif phase < upStart then
			pivot = system.BottomPivot
		elseif phase < upEnd then
			local alpha = (phase - upStart) / system.UpTime
			pivot = system.BottomPivot:Lerp(system.TopPivot, sineEase(alpha))
		else
			pivot = system.TopPivot
		end
		setRecordPivot(system.Record, pivot)
	end
end

local function updateSlides(serverTime)
	local system = systems.Slides
	if not system then
		return
	end
	local cycle = SLIDE_TRAVEL_TIME * 2 + SLIDE_EDGE_WAIT * 2
	local phase = serverTime % cycle
	local alpha
	if phase < SLIDE_TRAVEL_TIME then
		alpha = sineEase(phase / SLIDE_TRAVEL_TIME)
	elseif phase < SLIDE_TRAVEL_TIME + SLIDE_EDGE_WAIT then
		alpha = 1
	elseif phase < SLIDE_TRAVEL_TIME * 2 + SLIDE_EDGE_WAIT then
		alpha = 1 - sineEase((phase - SLIDE_TRAVEL_TIME - SLIDE_EDGE_WAIT) / SLIDE_TRAVEL_TIME)
	else
		alpha = 0
	end
	setRecordPivot(system.First, system.First.OriginPivot:Lerp(system.FirstOut, alpha))
	setRecordPivot(system.Second, system.Second.OriginPivot:Lerp(system.SecondOut, alpha))
	-- Open, nothing of it is left to stand on: not solid, and out of sight.
	local solid = alpha <= SLIDE_SOLID_UNTIL
	local hidden = math.clamp((alpha - SLIDE_SOLID_UNTIL) / (1 - SLIDE_SOLID_UNTIL), 0, 1)
	for part, state in pairs(system.PartStates or {}) do
		if part.Parent then
			part.CanCollide = state.CanCollide and solid
			part.CanTouch = state.CanTouch and solid
			part.Transparency = state.Transparency + (1 - state.Transparency) * hidden
		end
	end
end

local function updateFast(serverTime)
	local system = systems.Fast
	if not system then
		return
	end
	local cycle = FAST_START_WAIT + system.TravelTime + FAST_END_WAIT
	local phase = serverTime % cycle
	local alpha = phase > FAST_START_WAIT
		and math.clamp((phase - FAST_START_WAIT) / system.TravelTime, 0, 1)
		or 0
	setRecordPivot(system.Record, system.StartPivot:Lerp(system.EndPivot, alpha))
end

local function updateLavaUp(serverTime)
	local system = systems.LavaUp
	if not system then
		return
	end
	local cycle = LAVA_BOTTOM_WAIT + system.UpTime + LAVA_TOP_WAIT + system.DownTime
	local phase = serverTime % cycle
	local pivot
	if phase < LAVA_BOTTOM_WAIT then
		pivot = system.BottomPivot
	elseif phase < LAVA_BOTTOM_WAIT + system.UpTime then
		pivot = system.BottomPivot:Lerp(system.TopPivot, sineEase((phase - LAVA_BOTTOM_WAIT) / system.UpTime))
	elseif phase < LAVA_BOTTOM_WAIT + system.UpTime + LAVA_TOP_WAIT then
		pivot = system.TopPivot
	else
		local alpha = (phase - LAVA_BOTTOM_WAIT - system.UpTime - LAVA_TOP_WAIT) / system.DownTime
		pivot = system.TopPivot:Lerp(system.BottomPivot, alpha * alpha)
	end
	setRecordPivot(system.Record, pivot)
end

local function updateBridge(serverTime)
	local system = systems.Bridge
	if not system then
		return
	end
	local cycle = BRIDGE_VISIBLE_TIME + BRIDGE_FADE_TIME + BRIDGE_HIDDEN_TIME + BRIDGE_FADE_TIME
	local phase = serverTime % cycle
	local hiddenAlpha
	if phase < BRIDGE_VISIBLE_TIME then
		hiddenAlpha = 0
	elseif phase < BRIDGE_VISIBLE_TIME + BRIDGE_FADE_TIME then
		hiddenAlpha = sineEase((phase - BRIDGE_VISIBLE_TIME) / BRIDGE_FADE_TIME)
	elseif phase < BRIDGE_VISIBLE_TIME + BRIDGE_FADE_TIME + BRIDGE_HIDDEN_TIME then
		hiddenAlpha = 1
	else
		hiddenAlpha = 1 - sineEase(
			(phase - BRIDGE_VISIBLE_TIME - BRIDGE_FADE_TIME - BRIDGE_HIDDEN_TIME) / BRIDGE_FADE_TIME
		)
	end

	local physicallyPresent = hiddenAlpha < 0.62
	for part, state in pairs(system.PartStates) do
		if part.Parent then
			part.Transparency = state.Transparency + (1 - state.Transparency) * hiddenAlpha
			part.CanCollide = state.CanCollide and physicallyPresent
			part.CanTouch = state.CanTouch and physicallyPresent
			part.CanQuery = state.CanQuery and physicallyPresent
		end
	end
	for _, state in ipairs(system.Visuals) do
		if state.Object.Parent then
			state.Object.Transparency = state.Transparency + (1 - state.Transparency) * hiddenAlpha
		end
	end
end

local function segmentDistanceToPoint(segmentStart, segmentEnd, point)
	local segment = segmentEnd - segmentStart
	local denominator = segment:Dot(segment)
	if denominator <= 0.0001 then
		return (point - segmentStart).Magnitude
	end
	local alpha = math.clamp((point - segmentStart):Dot(segment) / denominator, 0, 1)
	return (point - (segmentStart + segment * alpha)).Magnitude
end

local function pointInsideExpandedPart(point, partCFrame, partSize)
	local localPoint = partCFrame:PointToObjectSpace(point)
	local half = partSize * 0.5 + BODY_PADDING
	return math.abs(localPoint.X) <= half.X
		and math.abs(localPoint.Y) <= half.Y
		and math.abs(localPoint.Z) <= half.Z
end

local previousRootByPlayer = setmetatable({}, { __mode = "k" })
local function samplePreviousRoot(player, character, root)
	local serial = player:GetAttribute("StageTeleportProtectionSerial")
	local previous = previousRootByPlayer[player]
	local current = root.Position
	previousRootByPlayer[player] = { Character = character, Root = root, Position = current, Serial = serial }
	if previous and previous.Character == character and previous.Root == root and previous.Serial == serial then
		return previous.Position
	end
	return current
end
local function getGroupCenters(group)
	if group.CenterPart and group.CenterPart.Parent then
		local current = group.CenterPart.Position
		local previousCFrame = group.Record and group.Record.PreviousCFrames[group.CenterPart]
		return current, previousCFrame and previousCFrame.Position or current
	end
	if group.Record then
		return group.Record.CurrentCenter, group.Record.PreviousCenter
	end
	local part = group.Parts[1]
	return part.Position, part.Position
end

local function checkExactCylinderContact(character, humanoid, root)
	local system = systems.Cylinder
	if not system or not system.LethalActive or not system.HazardPart or not system.HazardPart.Parent then
		return false
	end
	if characterTouchesExactCylinder(character, root, system.HazardPart) then
		humanoid.Health = 0
		return true
	end
	return false
end

                                                                            
                                                                             
                                                                          
                                                                               
local HAMMER_VISIBLE_BODY_NAMES = {
	head = true,
	torso = true,
	uppertorso = true,
	lowertorso = true,
	leftarm = true,
	rightarm = true,
	leftleg = true,
	rightleg = true,
	leftupperarm = true,
	leftlowerarm = true,
	lefthand = true,
	rightupperarm = true,
	rightlowerarm = true,
	righthand = true,
	leftupperleg = true,
	leftlowerleg = true,
	leftfoot = true,
	rightupperleg = true,
	rightlowerleg = true,
	rightfoot = true,
}

-- A character can receive body parts after the first collision query (avatar loading).
-- Build this small list from direct children so respawns/accessories cannot leave stale filters.
local function getHammerCharacterOverlapParams(character)
 local bodyParts = {}
 for _, child in ipairs(character:GetChildren()) do
  if child:IsA("BasePart") and HAMMER_VISIBLE_BODY_NAMES[normalizeName(child.Name)] then table.insert(bodyParts, child) end
 end
 local params = OverlapParams.new()
 params.FilterType = Enum.RaycastFilterType.Include
 params.FilterDescendantsInstances = bodyParts
 params.MaxParts = 1
 params.RespectCanCollide = false
 return params
end

local function exactHammerTouchesCharacter(group, character)
	local params = getHammerCharacterOverlapParams(character)
	for _, hammerPart in ipairs(group.Parts) do
		if hammerPart.Parent and hammerPart:GetAttribute("NewWorld1ExactHammerHazardKBM") == true then
			local touching = Workspace:GetPartsInPart(hammerPart, params)
			if #touching > 0 then
				return true
			end
		end
	end
	return false
end

local function checkPlayerContact(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		previousRootByPlayer[player] = nil
		return
	end

	local currentRoot = root.Position
	if player:GetAttribute("StageTeleportInvulnerable") == true
		or (tonumber(player:GetAttribute("StageTeleportArrivalGraceUntil")) or 0) > os.clock()
		or player:GetAttribute("SafeZoneProtected") == true
		or character:GetAttribute("SafeZoneProtected") == true
	then
		previousRootByPlayer[player] = nil
		return
	end
	local previousRoot = samplePreviousRoot(player, character, root)

	                                                                      
	if checkExactCylinderContact(character, humanoid, root) then
		return
	end

	local lavaFrozen = Workspace:GetAttribute("AdminWorldFrozen") == true
	for _, group in ipairs(lethalGroups) do
		if lavaFrozen and (group.HazardKey == "LavaUp" or group.HazardKey == "Lava") then
			continue -- frozen by the admin Snow event
		end
		local currentCenter, previousCenter = getGroupCenters(group)
		local centerMovement = (currentCenter - previousCenter).Magnitude
		local broadDistance = math.min(
			segmentDistanceToPoint(previousRoot, currentRoot, currentCenter),
			segmentDistanceToPoint(previousRoot, currentRoot, previousCenter)
		)
		if broadDistance <= group.Radius + 8 then
			if group.HazardKey == "Hammer" then
				                                                                  
				                                                                    
				if exactHammerTouchesCharacter(group, character) then
					humanoid.Health = 0
					return
				end
			else
				local rootMovement = (currentRoot - previousRoot).Magnitude
				local sampleCount = math.clamp(
					math.ceil(math.max(rootMovement, centerMovement) / SWEEP_SAMPLE_DISTANCE),
					1,
					MAX_SWEEP_SAMPLES
				)
				for _, part in ipairs(group.Parts) do
					if part.Parent then
						local previousCFrame = group.Record and group.Record.PreviousCFrames[part] or part.CFrame
						for sampleIndex = 1, sampleCount do
							local alpha = sampleIndex / sampleCount
							local rootPosition = previousRoot:Lerp(currentRoot, alpha)
							local partCFrame = previousCFrame:Lerp(part.CFrame, alpha)
							if pointInsideExpandedPart(rootPosition, partCFrame, part.Size) then
								humanoid.Health = 0
								return
							end
						end
					end
				end
			end
		end
	end
end

for _, object in ipairs(mapRoot:GetDescendants()) do
	registerCandidate(object)
end

task.wait(0.5)
rebuildSystems()

local rebuildQueued = false
local function queueRebuild()
	if rebuildQueued then
		return
	end
	rebuildQueued = true
	task.delay(0.2, function()
		rebuildQueued = false
		rebuildSystems()
	end)
end

local function hasRelevantAncestor(object)
	local current = object.Parent
	while current and current ~= mapRoot do
		if interestingNames[normalizeName(current.Name)] then
			return true
		end
		current = current.Parent
	end
	return false
end

mapRoot.DescendantAdded:Connect(function(object)
	if object:IsA("Sound") and object.Name == "VortexHammerWhoosh" then
		return
	end
	if registerCandidate(object) or hasRelevantAncestor(object) then
		queueRebuild()
	end
end)

mapRoot.DescendantRemoving:Connect(function(object)
	if object:IsA("Sound") and object.Name == "VortexHammerWhoosh" then
		return
	end
	local removedFallback = cylinderFallbackCandidates[object] == true
	cylinderFallbackCandidates[object] = nil
	local bucket = candidatesByName[normalizeName(object.Name)]
	if bucket and bucket[object] then
		bucket[object] = nil
		queueRebuild()
	elseif removedFallback or hasRelevantAncestor(object) then
		queueRebuild()
	end
end)

Players.PlayerRemoving:Connect(function(player)
	previousRootByPlayer[player] = nil
end)

local accumulator = 0
RunService.Heartbeat:Connect(function(deltaTime)
	accumulator += math.min(deltaTime, 0.1)
	if accumulator >= SERVER_MOTION_INTERVAL then
		accumulator = accumulator % SERVER_MOTION_INTERVAL
		for _, record in ipairs(movingRecords) do
			snapshotRecord(record)
		end

		local serverTime = math.max(0, Workspace:GetServerTimeNow() - motionStartServerTime)
		updateCylinder(serverTime)
		updateHammers(serverTime)
		updateLasers(serverTime)
		updatePresses(serverTime)
		updateSlides(serverTime)
		updateFast(serverTime)
		if Workspace:GetAttribute("AdminWorldFrozen") ~= true then
			updateLavaUp(serverTime)
		end
		updateBridge(serverTime)

		for _, player in ipairs(Players:GetPlayers()) do
			checkPlayerContact(player)
		end
	end
end)

mapRoot:SetAttribute("NewWorld1ServerMotionVersion", "V306KBW")
print(
	"[NewWorld1ServerMotion] V306KBW active | SERVER-ONLY obstacle geometry 30 Hz | hammer=visible-body exact contact | pressUp=7.7 | press=1D>2D>3D>1U>2U>3U | slides=100 studs | Fast/Wave=177.77777 | LavaUp=12.65 up/320 down studs/s | records="
		.. tostring(#movingRecords)
		.. " lethalGroups="
		.. tostring(#lethalGroups)
)
