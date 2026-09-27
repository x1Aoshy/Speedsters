local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

if Config.IsNewWorld1Map == true then
	local staleDecor = Workspace:FindFirstChild("StageDecor_Runtime")
	if staleDecor and staleDecor:GetAttribute("DecorVersion") ~= nil then
		staleDecor:Destroy()
	end
	print("[StageDecor] V306KBD old-map decorator disabled; new World 1 uses its authored stage parts.")
	return
end

                                                                                
                                                                                  
                                                         
if Config.IsWorld2Place == true then
	print("[StageDecor] V306HA World 1 decorator disabled in World 2; World2StageSystem owns the authored .2 stages.")
	return
end

-- World 3's desert map has no SafeZoneN: this decorator found none, built nothing, and then
-- rescanned the whole Workspace (36,000 instances) ten times every 0.25 s, for 20 s out of
-- every 25 s, forever. That alone kept the World 3 server busy with nobody playing.
if Config.IsWorld3Place == true then
	print("[StageDecor] World 1 decorator disabled in World 3; World3ManualStagePads owns the desert stages.")
	return
end

local STAGE_COUNT = math.max(1, math.floor(tonumber(Config.StageCount) or 10))
local DECOR_FOLDER_NAME = "StageDecor_Runtime"
local DECOR_VERSION = "V306EY"
local SAFE_ZONE_SCAN_TIMEOUT = 20
local SAFE_ZONE_REPAIR_INTERVAL = 5
local STAGE_RECOMMENDED_LEVELS = {
	[1] = 1,
	[2] = 7,
	[3] = 20,
	[4] = 30,
	[5] = 50,
	[6] = 60,
	[7] = 70,
	[8] = 80,
	[9] = 90,
	[10] = 100,
}

local SOURCE_TREADMILL_NAME = "Treadmill1_basic"
local STAGE_TREADMILL_SCALE = 0.56
local FLOOR_THICKNESS = 0.22
local FLOOR_COLOR = Color3.fromRGB(136, 142, 152)
local FLOOR_MATERIAL = Enum.Material.DiamondPlate
local FLOOR_RAISE = FLOOR_THICKNESS * 0.5 - 0.03
                                                                            
                                                                             
                                                                
local FLOOR_FIXED_WIDTH = 66
local FLOOR_FIXED_DEPTH = 26
local FLOOR_DEPTHS_BY_STAGE = {}
local FLOOR_RIGHT_OFFSET = 6
                                                                          
                                                                 
local FLOOR_RIGHT_OFFSETS_BY_STAGE = {}

                                                                            
                                                                            
                                                                             
                                                                        
                                                                  
local FLOOR_SIDE_WALL_MAX_DISTANCE = 80
local FLOOR_SIDE_WALL_MARGIN = -0.10
local FLOOR_SIDE_WALL_MIN_WIDTH = 30
local FLOOR_SIDE_WALL_PROBE_HEIGHTS = { 2.5, 5, 8, 11 }
local FLOOR_SIDE_WALL_MIN_VALID_PROBES = 2

                                                                        
                                                                          
                                               
local STAGE_ELEMENT_RIGHT_SHIFTS = {
	                                                                         
	                                                                      
	[7] = -3,
	                                                                           
	                                          
	[8] = -11,
}

                                                                          
                                                                        
                                                                                
                                                                              
local WHOLE_STAGE_LEFT_SHIFTS = {
	[9] = 0.7,
	[10] = 0.5,
}

                                                                             
                                                                            
              
local LAYOUT_REFERENCE_WIDTH = 44
local LAYOUT_REFERENCE_DEPTH = 30
local TREADMILL_LEFT_RATIO = 0.32
local TREADMILL_FORWARD_RATIO = 0.18
local SIGN_BOARD_SIZE = Vector3.new(5.6, 2.8, 0.32)
local SIGN_POST_SIZE = Vector3.new(0.48, 2.2, 0.48)
local SIGN_BOARD_CENTER_HEIGHT = SIGN_POST_SIZE.Y + SIGN_BOARD_SIZE.Y * 0.5
local SIGN_EDGE_INSET = 0.85
local SIGN_RIGHT_RATIO = 0.5
local SIGN_MAX_RIGHT_OFFSET = 18.4
local SIGN_FORWARD_RATIO = 0.28
local SIGN_MAX_FORWARD_OFFSET = 8.5
local SIGN_BOARD_COLOR = Color3.fromRGB(194, 78, 31)
local SIGN_POST_COLOR = Color3.fromRGB(166, 63, 25)
local SIGN_TEXT_MAX_DISTANCE = 0

                                                                           
                                                                          
local SKIP_STAGE_PRODUCT_ID = math.floor(tonumber(Config.SkipStageProductId) or 0)
local SKIP_PAD_SIZE = Vector3.new(5.5, 0.5, 5.5)
local SKIP_PAD_BASE_HEIGHT = 0.28
local SKIP_PAD_COLOR = Color3.fromRGB(0, 255, 85)
local SKIP_PAD_LIGHT_COLOR = Color3.fromRGB(80, 255, 135)
local SKIP_PAD_TEXT_COLOR = Color3.fromRGB(45, 255, 95)
local SKIP_PAD_FORWARD_GAP = 11.0
local SKIP_PROMPT_COOLDOWN = 1.5
-- Weak keys: a player who left is not kept alive by their cooldown.
local lastSkipPromptAt = setmetatable({}, { __mode = "k" })

local function normalizeName(value)
	return tostring(value or ""):lower():gsub("[^%w]", "")
end

local function isSupportedMapObject(object)
	return object:IsA("BasePart") or object:IsA("Model")
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

local function findNamedMapObject(targetName)
	local normalizedTarget = normalizeName(targetName)
	local matches = {}

	for _, object in ipairs(Workspace:GetDescendants()) do
		if normalizeName(object.Name) == normalizedTarget and isSupportedMapObject(object) then
			table.insert(matches, object)
		end
	end

	table.sort(matches, function(left, right)
		local leftDepth = objectDepth(left)
		local rightDepth = objectDepth(right)

		if leftDepth == rightDepth then
			return left:GetFullName() < right:GetFullName()
		end

		return leftDepth < rightDepth
	end)

	return matches[1]
end

local function waitForSafeZones(timeoutSeconds)
	local results = {}
	local deadline = os.clock() + timeoutSeconds

	repeat
		local complete = true
		for zoneIndex = 1, STAGE_COUNT do
			if not results[zoneIndex] or not results[zoneIndex].Parent then
				results[zoneIndex] = findNamedMapObject("SafeZone" .. tostring(zoneIndex))
			end
			if not results[zoneIndex] then
				complete = false
			end
		end

		if complete then
			return results
		end

		task.wait(0.25)
	until os.clock() >= deadline

	return results
end

local function getBounds(object)
	if not object then
		return nil, nil
	end

	if object:IsA("BasePart") then
		return object.CFrame, object.Size
	elseif object:IsA("Model") then
		local ok, boundsCFrame, boundsSize = pcall(function()
			return object:GetBoundingBox()
		end)
		if ok then
			return boundsCFrame, boundsSize
		end
	end

	return nil, nil
end

local function getObjectPivot(object)
	if not object then
		return nil
	end

	local ok, pivot = pcall(function()
		return object:GetPivot()
	end)
	if ok then
		return pivot
	end

	return nil
end

local function getPhysicalParts(object)
	local parts = {}
	if object:IsA("BasePart") then
		table.insert(parts, object)
		return parts
	end

	for _, descendant in ipairs(object:GetDescendants()) do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end

	return parts
end

local function getWorldVerticalExtent(cframe, size)
	local halfSize = size * 0.5
	return math.abs(cframe.RightVector.Y) * halfSize.X
		+ math.abs(cframe.UpVector.Y) * halfSize.Y
		+ math.abs(cframe.LookVector.Y) * halfSize.Z
end

local function getWorldTopY(part)
	return part.Position.Y + getWorldVerticalExtent(part.CFrame, part.Size)
end

local function getProjectedTopArea(part)
	local size = part.Size
	local cframe = part.CFrame
	return size.X * size.Z * math.abs(cframe.UpVector.Y)
		+ size.X * size.Y * math.abs(cframe.LookVector.Y)
		+ size.Y * size.Z * math.abs(cframe.RightVector.Y)
end

local function horizontalUnit(vector)
	local horizontal = Vector3.new(vector.X, 0, vector.Z)
	if horizontal.Magnitude < 0.05 then
		return nil
	end
	return horizontal.Unit
end

local function snapDirectionToCardinal(direction)
	if not direction then
		return nil
	end

	if math.abs(direction.X) >= math.abs(direction.Z) then
		return Vector3.new(direction.X >= 0 and 1 or -1, 0, 0)
	end

	return Vector3.new(0, 0, direction.Z >= 0 and 1 or -1)
end

local function projectedHalfExtent(cframe, size, direction)
	local halfSize = size * 0.5
	return math.abs(cframe.RightVector:Dot(direction)) * halfSize.X
		+ math.abs(cframe.UpVector:Dot(direction)) * halfSize.Y
		+ math.abs(cframe.LookVector:Dot(direction)) * halfSize.Z
end

local function findSafeZoneSurface(zone)
	if not zone then
		return nil
	end

	if zone:IsA("BasePart") then
		return zone
	end

	local zonePivot = getObjectPivot(zone)
	local bestPart = nil
	local bestScore = -math.huge

	for _, part in ipairs(getPhysicalParts(zone)) do
		local score = getProjectedTopArea(part)
		if part.CanCollide then
			score *= 1.2
		end
		if part.Transparency >= 0.95 then
			score *= 0.55
		end
		if zonePivot then
			local offset = part.Position - zonePivot.Position
			local horizontalDistance = Vector3.new(offset.X, 0, offset.Z).Magnitude
			score /= 1 + horizontalDistance * 0.025
		end
		if score > bestScore then
			bestScore = score
			bestPart = part
		end
	end

	return bestPart
end

local function makeHorizontalSurfaceCFrame(surface)
	local topPosition = Vector3.new(surface.Position.X, getWorldTopY(surface), surface.Position.Z)
	local look = horizontalUnit(surface.CFrame.LookVector)
	if not look then
		look = horizontalUnit(Vector3.new(surface.CFrame.RightVector.Z, 0, -surface.CFrame.RightVector.X))
	end
	if not look then
		look = Vector3.new(0, 0, -1)
	end
	return CFrame.lookAt(topPosition, topPosition + look.Unit, Vector3.yAxis)
end

local function makeHorizontalPositionCFrame(position, referenceCFrame)
	local look = referenceCFrame and horizontalUnit(referenceCFrame.LookVector) or nil
	if not look then
		look = Vector3.new(0, 0, -1)
	end
	return CFrame.lookAt(position, position + look.Unit, Vector3.yAxis)
end

local function findSafeZonePlacement(zone)
	if not zone then
		return nil, nil
	end

	local surface = findSafeZoneSurface(zone)
	local surfaceLooksWalkable = surface
		and surface.CanCollide
		and surface.Transparency < 0.95
		and surface.Size.Y <= 6

	                                                                             
	                                                                         
	                                              
	if surfaceLooksWalkable then
		return makeHorizontalSurfaceCFrame(surface), surface
	end

	local zoneCFrame, zoneSize = getBounds(zone)
	if zoneCFrame and zoneSize then
		local excluded = {}
		local runtimeFolder = Workspace:FindFirstChild(DECOR_FOLDER_NAME)
		if runtimeFolder then
			table.insert(excluded, runtimeFolder)
		end

		if zone:IsA("BasePart") then
			table.insert(excluded, zone)
		else
			for _, part in ipairs(getPhysicalParts(zone)) do
				if part.Transparency >= 0.95 or not part.CanCollide then
					table.insert(excluded, part)
				end
			end
		end

		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = excluded
		params.IgnoreWater = false
		local castAbove = math.max(12, zoneSize.Y * 0.5 + 6)
		local castDepth = math.max(150, zoneSize.Y + 100)
		local result = Workspace:Raycast(
			zoneCFrame.Position + Vector3.new(0, castAbove, 0),
			Vector3.new(0, -castDepth, 0),
			params
		)
		if result then
			return makeHorizontalPositionCFrame(result.Position, zoneCFrame), result.Instance
		end
	end

	if surface then
		return makeHorizontalSurfaceCFrame(surface), surface
	end

	return nil, nil
end

local function getSurfaceExtents(_zone, _surface, _surfaceCFrame)
	return FLOOR_FIXED_WIDTH, FLOOR_FIXED_DEPTH
end

local function getOrCreateRuntimeFolder()
	local folder = Workspace:FindFirstChild(DECOR_FOLDER_NAME)
	if folder and not folder:IsA("Folder") then
		folder:Destroy()
		folder = nil
	end
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = DECOR_FOLDER_NAME
		folder.Parent = Workspace
	end
	folder:SetAttribute("DecorVersion", DECOR_VERSION)
	return folder
end

local function clearChildren(instance)
	for _, child in ipairs(instance:GetChildren()) do
		child:Destroy()
	end
end

local function makeFloorSideRaycastParams(zone)
	local excluded = {}
	local runtimeFolder = Workspace:FindFirstChild(DECOR_FOLDER_NAME)
	if runtimeFolder then
		table.insert(excluded, runtimeFolder)
	end

	local winPadFolder = Workspace:FindFirstChild("WinPads_TO_PLACE")
	if winPadFolder then
		table.insert(excluded, winPadFolder)
	end

	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			table.insert(excluded, player.Character)
		end
	end

	                                                                           
	                                                                          
	if zone:IsA("BasePart") then
		if zone.Transparency >= 0.95 or not zone.CanCollide then
			table.insert(excluded, zone)
		end
	else
		for _, part in ipairs(getPhysicalParts(zone)) do
			if part.Transparency >= 0.95 or not part.CanCollide then
				table.insert(excluded, part)
			end
		end
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = excluded
	params.IgnoreWater = true
	return params
end

local function median(values)
	if #values == 0 then
		return nil
	end
	table.sort(values)
	local middle = math.floor((#values + 1) * 0.5)
	if #values % 2 == 1 then
		return values[middle]
	end
	return (values[middle] + values[middle + 1]) * 0.5
end

local function probeSideWallDistance(origin, direction, params)
	local distances = {}

	for _, height in ipairs(FLOOR_SIDE_WALL_PROBE_HEIGHTS) do
		local result = Workspace:Raycast(
			origin + Vector3.new(0, height, 0),
			direction * FLOOR_SIDE_WALL_MAX_DISTANCE,
			params
		)

		if result then
			local horizontalNormal = horizontalUnit(result.Normal)
			local facesProbe = horizontalNormal
				and horizontalNormal:Dot(direction) <= -0.35
			if facesProbe then
				table.insert(distances, result.Distance)
			end
		end
	end

	if #distances < FLOOR_SIDE_WALL_MIN_VALID_PROBES then
		return nil
	end

	return median(distances)
end

local function fitFloorBetweenSideWalls(zone, nominalCenter, rightDirection, fallbackWidth)
	local params = makeFloorSideRaycastParams(zone)
	local rightDistance = probeSideWallDistance(nominalCenter, rightDirection, params)
	local leftDistance = probeSideWallDistance(nominalCenter, -rightDirection, params)

	if not rightDistance or not leftDistance then
		return nominalCenter, fallbackWidth, false
	end

	local fittedWidth = rightDistance + leftDistance - FLOOR_SIDE_WALL_MARGIN * 2
	if fittedWidth < FLOOR_SIDE_WALL_MIN_WIDTH then
		return nominalCenter, fallbackWidth, false
	end

	                                                                          
	                                                                      
	fittedWidth = math.min(fallbackWidth, fittedWidth)
	local fittedCenter = nominalCenter

	if fittedWidth < fallbackWidth - 0.05 then
		local wallMidpointShift = (rightDistance - leftDistance) * 0.5
		fittedCenter += rightDirection * wallMidpointShift
	end

	return fittedCenter, fittedWidth, true
end

local function createFloorDeck(parent, zoneIndex, floorCFrame, width, depth)
	local deck = Instance.new("Part")
	deck.Name = string.format("Stage%02d_Floor", zoneIndex)
	deck.Anchored = true
	deck.Material = FLOOR_MATERIAL
	deck.Color = FLOOR_COLOR
	deck.TopSurface = Enum.SurfaceType.Smooth
	deck.BottomSurface = Enum.SurfaceType.Smooth
	deck.CastShadow = false
	deck.Size = Vector3.new(width, FLOOR_THICKNESS, depth)
	deck.CFrame = floorCFrame * CFrame.new(0, FLOOR_RAISE, 0)
	deck.Parent = parent
	return deck
end

local function createStageLabel(parent, zoneIndex, floor)
	                                                                         
	                                                                             
	                                                                      
	local board = Instance.new("Part")
	board.Name = string.format("Stage%02d_LabelBoard", zoneIndex)
	board.Anchored = true
	board.CanCollide = false
	board.CanTouch = false
	board.CanQuery = false
	board.CastShadow = false
	board.Transparency = 1
	                                                                            
	                                                                         
	                                                                           
	                                                                     
	                                                
	board.Size = Vector3.new(46.0, 12.6, 0.2)
	board.CFrame = floor.CFrame * CFrame.new(0, 17.5, 0)
	board.Parent = parent

	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Name = "FrontApproachStageText"
	surfaceGui.Adornee = board
	surfaceGui.Face = Enum.NormalId.Back
	                                                                     
	                                                                           
	                                            
	surfaceGui.AlwaysOnTop = false
	surfaceGui.LightInfluence = 0
	surfaceGui.MaxDistance = 0
	surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surfaceGui.PixelsPerStud = 8
	surfaceGui.Parent = board

	local label = Instance.new("TextLabel")
	label.Name = "StageNumberText"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.Text = "STAGE " .. tostring(zoneIndex)
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = surfaceGui

	local textConstraint = Instance.new("UITextSizeConstraint")
	textConstraint.Name = "HugeWorldTextConstraint"
	textConstraint.MinTextSize = 1
	textConstraint.MaxTextSize = 100
	textConstraint.Parent = label

	local outline = Instance.new("UIStroke")
	outline.Name = "ThickBlackOutline"
	outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	outline.Color = Color3.fromRGB(0, 0, 0)
	outline.Thickness = 8
	outline.Transparency = 0
	outline.Parent = label
end

local function createRecommendedSign(parent, zoneIndex, center, rightDirection, courseDirection, width, depth)
	                                                                         
	                                                                               
	local maximumRightOffset = math.max(
		0,
		width * 0.5 - SIGN_BOARD_SIZE.X * 0.5 - SIGN_EDGE_INSET
	)
	local wantedRightOffset = math.min(width * SIGN_RIGHT_RATIO, SIGN_MAX_RIGHT_OFFSET)
	local rightOffset = math.min(wantedRightOffset, maximumRightOffset)
	local maximumForwardOffset = math.max(
		0,
		depth * 0.5 - SIGN_BOARD_SIZE.X * 0.5 - SIGN_EDGE_INSET
	)
	local wantedForwardOffset = math.min(
		depth * SIGN_FORWARD_RATIO,
		SIGN_MAX_FORWARD_OFFSET
	)
	local forwardOffset = math.min(wantedForwardOffset, maximumForwardOffset)
	local basePosition = center
		+ rightDirection * rightOffset
		+ courseDirection * forwardOffset
	local faceDirection = horizontalUnit(-rightDirection - courseDirection)
		or horizontalUnit(center - basePosition)
		or -courseDirection
	local signCFrame = CFrame.lookAt(
		basePosition,
		basePosition + faceDirection,
		Vector3.yAxis
	)

	local model = Instance.new("Model")
	model.Name = string.format("Stage%02d_RecommendedSign", zoneIndex)
	model:SetAttribute("SignStyleVersion", "V255RightShifted45Degrees")
	model:SetAttribute("RightOffsetStuds", rightOffset)
	model:SetAttribute("ForwardOffsetStuds", forwardOffset)
	model:SetAttribute("InwardYawDegrees", 45)
	model.Parent = parent

	local post = Instance.new("Part")
	post.Name = "Post"
	post.Anchored = true
	post.CanTouch = false
	post.Material = Enum.Material.SmoothPlastic
	post.Color = SIGN_POST_COLOR
	post.Size = SIGN_POST_SIZE
	post.TopSurface = Enum.SurfaceType.Smooth
	post.BottomSurface = Enum.SurfaceType.Smooth
	post.CFrame = signCFrame * CFrame.new(0, SIGN_POST_SIZE.Y * 0.5, 0)
	post.Parent = model

	local board = Instance.new("Part")
	board.Name = "Board"
	board.Anchored = true
	board.CanTouch = false
	board.Material = Enum.Material.SmoothPlastic
	board.Color = SIGN_BOARD_COLOR
	board.Size = SIGN_BOARD_SIZE
	board.TopSurface = Enum.SurfaceType.Smooth
	board.BottomSurface = Enum.SurfaceType.Smooth
	board.CFrame = signCFrame * CFrame.new(0, SIGN_BOARD_CENTER_HEIGHT, 0)
	board.Parent = model

	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local gui = Instance.new("SurfaceGui")
		gui.Name = face.Name .. "Gui"
		gui.Face = face
		                                                                     
		                                                           
		gui.AlwaysOnTop = false
		gui.LightInfluence = 0
		gui.MaxDistance = SIGN_TEXT_MAX_DISTANCE
		gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		gui.CanvasSize = Vector2.new(560, 280)
		gui.Parent = board

		local textLabel = Instance.new("TextLabel")
		textLabel.Name = "RecommendedLevelText"
		textLabel.BackgroundTransparency = 1
		textLabel.AnchorPoint = Vector2.new(0.5, 0.5)
		textLabel.Position = UDim2.fromScale(0.5, 0.5)
		textLabel.Size = UDim2.fromScale(0.93, 0.86)
		textLabel.Font = Enum.Font.GothamBlack
		textLabel.Text = "Recommended\nLevel: " .. tostring(STAGE_RECOMMENDED_LEVELS[zoneIndex] or 1)
		textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		textLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		textLabel.TextStrokeTransparency = 0
		textLabel.TextScaled = true
		textLabel.TextWrapped = true
		textLabel.TextXAlignment = Enum.TextXAlignment.Center
		textLabel.TextYAlignment = Enum.TextYAlignment.Center
		textLabel.Parent = gui

		local outline = Instance.new("UIStroke")
		outline.Name = "StrongerBlackOutline"
		outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		outline.Color = Color3.fromRGB(0, 0, 0)
		outline.Thickness = 3
		outline.Transparency = 0
		outline.Parent = textLabel

		local sizeConstraint = Instance.new("UITextSizeConstraint")
		sizeConstraint.MinTextSize = 20
		sizeConstraint.MaxTextSize = 82
		sizeConstraint.Parent = textLabel
	end
end

local function scaleObject(object, scale)
	if math.abs(scale - 1) < 0.001 then
		return
	end

	if object:IsA("BasePart") then
		object.Size = object.Size * scale
		return
	end

	if not object:IsA("Model") then
		return
	end

	local pivot = object:GetPivot()
	for _, descendant in ipairs(object:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local relative = pivot:ToObjectSpace(descendant.CFrame)
			local rx, ry, rz = relative:ToOrientation()
			local scaledPosition = relative.Position * scale
			descendant.Size = descendant.Size * scale
			descendant.CFrame = pivot * CFrame.new(scaledPosition) * CFrame.fromOrientation(rx, ry, rz)
		elseif descendant:IsA("Attachment") then
			descendant.Position = descendant.Position * scale
		elseif descendant:IsA("SpecialMesh") then
			descendant.Scale = descendant.Scale * scale
		end
	end
end

local function positionObjectOnFloor(object, targetCFrame, floorY)
	object:PivotTo(targetCFrame)
	local boundsCFrame, boundsSize = getBounds(object)
	if not boundsCFrame or not boundsSize then
		return
	end
	local bottomY = boundsCFrame.Position.Y - getWorldVerticalExtent(boundsCFrame, boundsSize)
	local deltaY = floorY - bottomY + 0.02
	if math.abs(deltaY) > 0.001 then
		object:PivotTo(object:GetPivot() + Vector3.new(0, deltaY, 0))
	end
end

local function findSourceTreadmill()
	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if isSupportedMapObject(descendant)
			and descendant.Name == SOURCE_TREADMILL_NAME
			and not descendant:GetAttribute("StageDecorClone")
		then
			local runtimeFolder = Workspace:FindFirstChild(DECOR_FOLDER_NAME)
			if not runtimeFolder or not descendant:IsDescendantOf(runtimeFolder) then
				return descendant
			end
		end
	end
	return nil
end

local function getPlayerFromTouchedPart(hit)
	if not hit or not hit.Parent then
		return nil
	end

	local character = hit:FindFirstAncestorOfClass("Model")
	if not character then
		return nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end

	return Players:GetPlayerFromCharacter(character)
end

local function connectSkipStagePad(pad, zoneIndex)
	if zoneIndex >= STAGE_COUNT or SKIP_STAGE_PRODUCT_ID <= 0 then
		return
	end

	pad.Touched:Connect(function(hit)
		local player = getPlayerFromTouchedPart(hit)
		if not player then
			return
		end

		local now = os.clock()
		if now - (lastSkipPromptAt[player] or 0) < SKIP_PROMPT_COOLDOWN then
			return
		end
		lastSkipPromptAt[player] = now

		local targetStage = math.min(STAGE_COUNT, zoneIndex + 1)
		player:SetAttribute("PendingSkipStageFrom", zoneIndex)
		player:SetAttribute("PendingSkipStageTarget", targetStage)
		player:SetAttribute("PendingSkipStageSetAt", Workspace:GetServerTimeNow())

		MarketplaceService:PromptProductPurchase(player, SKIP_STAGE_PRODUCT_ID)
	end)
end

local function createSkipStagePad(parent, zoneIndex, treadmillCenter, courseDirection, floorY)
	if zoneIndex >= STAGE_COUNT then
		return nil
	end

	local padPosition = treadmillCenter + courseDirection * SKIP_PAD_FORWARD_GAP
	local padCFrame = CFrame.lookAt(
		Vector3.new(padPosition.X, floorY + SKIP_PAD_SIZE.Y * 0.5 + 0.03, padPosition.Z),
		Vector3.new(padPosition.X, floorY + SKIP_PAD_SIZE.Y * 0.5 + 0.03, padPosition.Z) + courseDirection,
		Vector3.yAxis
	)

	local base = Instance.new("Part")
	base.Name = string.format("Stage%02d_SkipStagePad_BlackBase", zoneIndex)
	base.Anchored = true
	base.CanCollide = false
	base.CanTouch = false
	base.CanQuery = false
	base.CastShadow = false
	base.Material = Enum.Material.SmoothPlastic
	base.Color = Color3.fromRGB(18, 18, 18)
	base.TopSurface = Enum.SurfaceType.Studs
	base.BottomSurface = Enum.SurfaceType.Smooth
	base.Size = Vector3.new(
		SKIP_PAD_SIZE.X + 0.75,
		SKIP_PAD_BASE_HEIGHT,
		SKIP_PAD_SIZE.Z + 0.75
	)
	base.CFrame = padCFrame
		* CFrame.new(0, -((SKIP_PAD_SIZE.Y + SKIP_PAD_BASE_HEIGHT) * 0.5) + 0.02, 0)
	base.Parent = parent

	local pad = Instance.new("Part")
	pad.Name = string.format("Stage%02d_SkipStagePad", zoneIndex)
	pad.Anchored = true
	pad.CanCollide = true
	pad.CanTouch = true
	pad.CanQuery = true
	pad.CastShadow = false
	pad.Material = Enum.Material.Neon
	pad.Color = SKIP_PAD_COLOR
	pad.Size = SKIP_PAD_SIZE
	pad.CFrame = padCFrame
	pad.TopSurface = Enum.SurfaceType.Smooth
	pad.BottomSurface = Enum.SurfaceType.Smooth
	pad:SetAttribute("SkipStageRobuxPlaceholder", false)
	pad:SetAttribute("ProductConfigured", SKIP_STAGE_PRODUCT_ID > 0)
	pad:SetAttribute("SkipStageProductId", SKIP_STAGE_PRODUCT_ID)
	pad:SetAttribute("SkipFromStage", zoneIndex)
	pad:SetAttribute("SkipTargetStage", zoneIndex + 1)
	pad:SetAttribute("SafeZoneIndex", zoneIndex)
	pad.Parent = parent

	local light = Instance.new("PointLight")
	light.Name = "PadLight"
	light.Color = SKIP_PAD_LIGHT_COLOR
	light.Brightness = 0.8
	light.Range = 3
	light.Shadows = false
	light.Parent = pad

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "SkipStageBillboard"
	billboard.Adornee = pad
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.Size = UDim2.fromOffset(118, 27)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 1.75, 0)
	billboard.MaxDistance = 75
	billboard.Parent = pad

	local label = Instance.new("TextLabel")
	label.Name = "SkipStageText"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.Text = "Skip Stage"
	label.TextColor3 = SKIP_PAD_TEXT_COLOR
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0.35
	label.TextScaled = false
	label.TextSize = 19
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = billboard

	connectSkipStagePad(pad, zoneIndex)
	return pad
end

local function createStageTreadmill(parent, zoneIndex, stageCenter, rightDirection, courseDirection, width, depth, floorY)
	local source = findSourceTreadmill()
	if not source then
		warn("[StageDecor] Missing source treadmill: " .. SOURCE_TREADMILL_NAME)
		return false
	end

	local treadmill = source:Clone()
	treadmill.Name = string.format("Stage%02d_%s", zoneIndex, SOURCE_TREADMILL_NAME)
	treadmill:SetAttribute("StageDecorClone", true)
	treadmill:SetAttribute("TreadmillTrainingSourceName", SOURCE_TREADMILL_NAME)
	                                                                         
	                                                                              
	treadmill:SetAttribute("TreadmillTrainingHorizontalScale", 0.72)
	treadmill:SetAttribute("TreadmillTrainingVerticalPadding", 2.25)
	treadmill.Parent = parent

	scaleObject(treadmill, STAGE_TREADMILL_SCALE)

	local leftOffset = width * TREADMILL_LEFT_RATIO
	local forwardOffset = depth * TREADMILL_FORWARD_RATIO
	local targetPosition = stageCenter - rightDirection * leftOffset - courseDirection * forwardOffset
	                                                                     
	local targetCFrame = CFrame.lookAt(targetPosition, targetPosition - courseDirection, Vector3.yAxis)
	positionObjectOnFloor(treadmill, targetCFrame, floorY)
	createSkipStagePad(parent, zoneIndex, targetPosition, courseDirection, floorY)
	return true
end

local function getStageCourseDirection(zones, zoneIndex, fallbackDirection)
	local currentPivot = getObjectPivot(zones[zoneIndex])
	if currentPivot then
		                                                                   
		                                                                        
		                                                                        
		                                                                        
		                                                                  
		if zoneIndex >= 4 then
			local previousPivot = getObjectPivot(zones[zoneIndex - 1])
			if previousPivot then
				local incomingDirection = horizontalUnit(currentPivot.Position - previousPivot.Position)
				if incomingDirection then
					return snapDirectionToCardinal(incomingDirection)
				end
			end
		end

		local nextPivot = getObjectPivot(zones[zoneIndex + 1])
		if nextPivot then
			local direction = horizontalUnit(nextPivot.Position - currentPivot.Position)
			if direction then
				return zoneIndex >= 4 and snapDirectionToCardinal(direction) or direction
			end
		end

		local previousPivot = getObjectPivot(zones[zoneIndex - 1])
		if previousPivot then
			local direction = horizontalUnit(currentPivot.Position - previousPivot.Position)
			if direction then
				return zoneIndex >= 4 and snapDirectionToCardinal(direction) or direction
			end
		end
	end

	local fallback = horizontalUnit(fallbackDirection) or Vector3.new(0, 0, -1)
	return zoneIndex >= 4 and snapDirectionToCardinal(fallback) or fallback
end

local function buildStageDecor(folder, zoneIndex, zone, zones)
	local surfaceCFrame, surface = findSafeZonePlacement(zone)
	if not surfaceCFrame then
		warn("[StageDecor] Could not resolve stage surface for SafeZone" .. tostring(zoneIndex))
		return false
	end

	local width, depth = getSurfaceExtents(zone, surface, surfaceCFrame)
	local stageModel = Instance.new("Model")
	stageModel.Name = string.format("Stage%02d_Decor", zoneIndex)
	stageModel.Parent = folder

	local surfaceRightDirection = horizontalUnit(surfaceCFrame.RightVector) or Vector3.xAxis
	local surfaceCourseDirection = horizontalUnit(surfaceCFrame.LookVector) or Vector3.zAxis
	local layoutCourseDirection = getStageCourseDirection(zones, zoneIndex, surfaceCourseDirection)
	local layoutRightDirection = layoutCourseDirection:Cross(Vector3.yAxis)
	if layoutRightDirection.Magnitude < 0.05 then
		layoutRightDirection = surfaceRightDirection
	else
		layoutRightDirection = layoutRightDirection.Unit
	end

	                                                                          
	                                                                             
	                                
	local layoutCenterPosition = surfaceCFrame.Position
	local floorRightOffset = FLOOR_RIGHT_OFFSETS_BY_STAGE[zoneIndex]
	if floorRightOffset == nil then
		floorRightOffset = FLOOR_RIGHT_OFFSET
	end
	local nominalFloorCenter = layoutCenterPosition + layoutRightDirection * floorRightOffset
	local floorCenterPosition, requestedFloorWidth, fittedToWalls = fitFloorBetweenSideWalls(
		zone,
		nominalFloorCenter,
		layoutRightDirection,
		FLOOR_FIXED_WIDTH
	)

	local wholeStageLeftShift = WHOLE_STAGE_LEFT_SHIFTS[zoneIndex] or 0
	if wholeStageLeftShift ~= 0 then
		floorCenterPosition -= layoutRightDirection * wholeStageLeftShift
	end

	local floorCFrame = CFrame.lookAt(
		floorCenterPosition,
		floorCenterPosition + layoutCourseDirection,
		Vector3.yAxis
	)
	local requestedFloorDepth = FLOOR_DEPTHS_BY_STAGE[zoneIndex] or FLOOR_FIXED_DEPTH
	local floor = createFloorDeck(
		stageModel,
		zoneIndex,
		floorCFrame,
		requestedFloorWidth,
		requestedFloorDepth
	)
	floor:SetAttribute("FittedBetweenSideWalls", fittedToWalls)
	floor:SetAttribute("ResolvedStageWidth", requestedFloorWidth)

	                                                                         
	                                             
	local stageCenter = layoutCenterPosition
		+ Vector3.new(0, FLOOR_RAISE + FLOOR_THICKNESS * 0.5, 0)
	if wholeStageLeftShift ~= 0 then
		stageCenter -= layoutRightDirection * wholeStageLeftShift
	end
	createStageLabel(stageModel, zoneIndex, floor)
	createRecommendedSign(
		stageModel,
		zoneIndex,
		stageCenter,
		layoutRightDirection,
		layoutCourseDirection,
		LAYOUT_REFERENCE_WIDTH,
		LAYOUT_REFERENCE_DEPTH
	)
	                                                                        
	                                                        
	local treadmillStageCenter = stageCenter
	local treadmillRightShift = STAGE_ELEMENT_RIGHT_SHIFTS[zoneIndex] or 0
	if treadmillRightShift ~= 0 then
		treadmillStageCenter += layoutRightDirection * treadmillRightShift
	end
	createStageTreadmill(
		stageModel,
		zoneIndex,
		treadmillStageCenter,
		layoutRightDirection,
		layoutCourseDirection,
		LAYOUT_REFERENCE_WIDTH,
		LAYOUT_REFERENCE_DEPTH,
		stageCenter.Y
	)
	return true
end

local function findMatchingStageDescendant(sourceStage, targetStage, sourceDescendant, sourceStageNumber, targetStageNumber)
	local path = {}
	local current = sourceDescendant
	while current and current ~= sourceStage do
		table.insert(path, 1, current.Name)
		current = current.Parent
	end
	if current ~= sourceStage then
		return nil
	end

	local sourceToken = string.format("Stage%02d", sourceStageNumber)
	local targetToken = string.format("Stage%02d", targetStageNumber)
	local target = targetStage
	for _, name in ipairs(path) do
		local targetName = string.gsub(name, sourceToken, targetToken)
		target = target:FindFirstChild(targetName)
		if not target then
			return nil
		end
	end
	return target
end

local function copyStagePartLayoutFromTemplate(folder, sourceStageNumber, targetStageNumber)
	local sourceStage = folder:FindFirstChild(string.format("Stage%02d_Decor", sourceStageNumber))
	local targetStage = folder:FindFirstChild(string.format("Stage%02d_Decor", targetStageNumber))
	if not sourceStage or not targetStage then
		return false
	end

	local sourceFloor = sourceStage:FindFirstChild(string.format("Stage%02d_Floor", sourceStageNumber))
	local targetFloor = targetStage:FindFirstChild(string.format("Stage%02d_Floor", targetStageNumber))
	if not sourceFloor or not targetFloor or not sourceFloor:IsA("BasePart") or not targetFloor:IsA("BasePart") then
		return false
	end

	                                                                                   
	                                                                           
	                                                                            
	local sourceFloorFrame = sourceFloor.CFrame
	local targetFloorFrame = targetFloor.CFrame
	local copiedParts = 0

	for _, sourceDescendant in ipairs(sourceStage:GetDescendants()) do
		if sourceDescendant:IsA("BasePart") then
			local targetDescendant = findMatchingStageDescendant(
				sourceStage,
				targetStage,
				sourceDescendant,
				sourceStageNumber,
				targetStageNumber
			)
			if targetDescendant and targetDescendant:IsA("BasePart") then
				local localCFrame = sourceFloorFrame:ToObjectSpace(sourceDescendant.CFrame)
				targetDescendant.Size = sourceDescendant.Size
				targetDescendant.CFrame = targetFloorFrame * localCFrame
				copiedParts += 1
			end
		end
	end

	targetStage:SetAttribute("ExactLayoutTemplateStage", sourceStageNumber)
	targetStage:SetAttribute("ExactLayoutCopiedParts", copiedParts)
	return copiedParts > 0
end

local function replaceStageModelFromTemplate(folder, sourceStageNumber, targetStageNumber, sourceModelName)
	local sourceStage = folder:FindFirstChild(string.format("Stage%02d_Decor", sourceStageNumber))
	local targetStage = folder:FindFirstChild(string.format("Stage%02d_Decor", targetStageNumber))
	if not sourceStage or not targetStage then
		return false
	end

	local sourceFloor = sourceStage:FindFirstChild(string.format("Stage%02d_Floor", sourceStageNumber))
	local targetFloor = targetStage:FindFirstChild(string.format("Stage%02d_Floor", targetStageNumber))
	if not sourceFloor or not targetFloor or not sourceFloor:IsA("BasePart") or not targetFloor:IsA("BasePart") then
		return false
	end

	local sourceModel = sourceStage:FindFirstChild(string.format("Stage%02d_%s", sourceStageNumber, sourceModelName))
	local targetModel = targetStage:FindFirstChild(string.format("Stage%02d_%s", targetStageNumber, sourceModelName))
	if not sourceModel or not targetModel or not sourceModel:IsA("Model") or not targetModel:IsA("Model") then
		return false
	end

	local localPivot = sourceFloor.CFrame:ToObjectSpace(sourceModel:GetPivot())
	local replacement = sourceModel:Clone()
	replacement.Name = string.format("Stage%02d_%s", targetStageNumber, sourceModelName)
	replacement.Parent = targetStage
	replacement:PivotTo(targetFloor.CFrame * localPivot)
	targetModel:Destroy()
	return true
end


local function copyStagePartFromTemplate(folder, sourceStageNumber, targetStageNumber, partSuffix)
	local sourceStage = folder:FindFirstChild(string.format("Stage%02d_Decor", sourceStageNumber))
	local targetStage = folder:FindFirstChild(string.format("Stage%02d_Decor", targetStageNumber))
	if not sourceStage or not targetStage then
		return false
	end

	local sourceFloor = sourceStage:FindFirstChild(string.format("Stage%02d_Floor", sourceStageNumber))
	local targetFloor = targetStage:FindFirstChild(string.format("Stage%02d_Floor", targetStageNumber))
	local sourcePart = sourceStage:FindFirstChild(string.format("Stage%02d_%s", sourceStageNumber, partSuffix))
	local targetPart = targetStage:FindFirstChild(string.format("Stage%02d_%s", targetStageNumber, partSuffix))
	if not sourceFloor or not targetFloor or not sourcePart or not targetPart then
		return false
	end
	if not sourceFloor:IsA("BasePart") or not targetFloor:IsA("BasePart") or not sourcePart:IsA("BasePart") or not targetPart:IsA("BasePart") then
		return false
	end

	local localCFrame = sourceFloor.CFrame:ToObjectSpace(sourcePart.CFrame)
	targetPart.Size = sourcePart.Size
	targetPart.CFrame = targetFloor.CFrame * localCFrame
	return true
end


                                                                           
                                                                         
                                                                        
local function applyOneSidedFloorAdjustment(folder, zoneIndex)
	local stageModel = folder:FindFirstChild(string.format("Stage%02d_Decor", zoneIndex))
	if not stageModel then
		return
	end

	local floor = stageModel:FindFirstChild(string.format("Stage%02d_Floor", zoneIndex))
	if not floor or not floor:IsA("BasePart") then
		return
	end

	if zoneIndex == 8 then
		                                                                    
		                                                                  
		                                                             
		                                                                        
		floor.Size = Vector3.new(floor.Size.X + 9.5, floor.Size.Y, floor.Size.Z)
		floor.CFrame = floor.CFrame - floor.CFrame.RightVector * 5.75
		floor:SetAttribute("V306EW_Stage8LeftEdgeGrow", 10.5)
		floor:SetAttribute("V306EW_Stage8RightEdgeShrink", 1)
	elseif zoneIndex == 9 then
		                                                                       
		floor.Size = Vector3.new(math.max(1, floor.Size.X - 1), floor.Size.Y, floor.Size.Z)
		floor.CFrame = floor.CFrame + floor.CFrame.RightVector * 0.5
		floor:SetAttribute("V306EV_Stage9LeftEdgeShrink", 1)
	elseif zoneIndex == 10 then
		                                                                         
		floor.Size = Vector3.new(floor.Size.X + 1, floor.Size.Y, floor.Size.Z)
		floor.CFrame = floor.CFrame + floor.CFrame.RightVector * 0.5
		floor:SetAttribute("V306EV_Stage10RightEdgeGrow", 1)
	end
end

local function rebuildDecor()
	local zones = waitForSafeZones(SAFE_ZONE_SCAN_TIMEOUT)
	local folder = getOrCreateRuntimeFolder()
	clearChildren(folder)

	local built = 0
	for zoneIndex = 1, STAGE_COUNT do
		local zone = zones[zoneIndex]
		if zone then
			if buildStageDecor(folder, zoneIndex, zone, zones) then
				built += 1
				if zoneIndex == 5 then
					if not copyStagePartLayoutFromTemplate(folder, 4, 5) then
						warn("[StageDecor] Could not copy exact Stage 4 layout onto Stage 5")
					end
					if not replaceStageModelFromTemplate(folder, 4, 5, SOURCE_TREADMILL_NAME) then
						warn("[StageDecor] Could not replace Stage 5 treadmill from Stage 4 template")
					end
				elseif zoneIndex == 6 then
					if not replaceStageModelFromTemplate(folder, 4, 6, SOURCE_TREADMILL_NAME) then
						warn("[StageDecor] Could not replace Stage 6 treadmill from Stage 4 template")
					end
					if not copyStagePartFromTemplate(folder, 4, 6, "SkipStagePad") then
						warn("[StageDecor] Could not align Stage 6 Skip Stage pad from Stage 4 template")
					end
					if not copyStagePartFromTemplate(folder, 4, 6, "SkipStagePad_BlackBase") then
						warn("[StageDecor] Could not align Stage 6 Skip Stage pad base from Stage 4 template")
					end
				elseif zoneIndex == 9 or zoneIndex == 10 then
					                                                                    
					                                                                      
					                                                                   
					if not copyStagePartLayoutFromTemplate(folder, 4, zoneIndex) then
						warn("[StageDecor] Could not copy exact Stage 4 layout onto Stage " .. tostring(zoneIndex))
					end
					if not replaceStageModelFromTemplate(folder, 4, zoneIndex, SOURCE_TREADMILL_NAME) then
						warn("[StageDecor] Could not replace Stage " .. tostring(zoneIndex) .. " treadmill from Stage 4 template")
					end
					if zoneIndex < STAGE_COUNT then
						if not copyStagePartFromTemplate(folder, 4, zoneIndex, "SkipStagePad") then
							warn("[StageDecor] Could not align Stage " .. tostring(zoneIndex) .. " Skip Stage pad from Stage 4 template")
						end
						if not copyStagePartFromTemplate(folder, 4, zoneIndex, "SkipStagePad_BlackBase") then
							warn("[StageDecor] Could not align Stage " .. tostring(zoneIndex) .. " Skip Stage pad base from Stage 4 template")
						end
					end
				end

				                                                                   
				                                                                          
				if zoneIndex == 8 or zoneIndex == 9 or zoneIndex == 10 then
					applyOneSidedFloorAdjustment(folder, zoneIndex)
				end
			end
		else
			warn("[StageDecor] Missing SafeZone" .. tostring(zoneIndex))
		end
	end

	folder:SetAttribute("ConfiguredStages", built)
	return built
end

local function isDecorHealthy(folder)
	if not folder or not folder.Parent then
		return false
	end
	if folder:GetAttribute("DecorVersion") ~= DECOR_VERSION then
		return false
	end
	return (folder:GetAttribute("ConfiguredStages") or 0) >= STAGE_COUNT
end

local builtStages = rebuildDecor()
print("[StageDecor] " .. DECOR_VERSION .. " built stage decor for " .. tostring(builtStages) .. "/" .. tostring(STAGE_COUNT) .. " stages")

task.spawn(function()
	while true do
		task.wait(SAFE_ZONE_REPAIR_INTERVAL)
		local folder = Workspace:FindFirstChild(DECOR_FOLDER_NAME)
		if not isDecorHealthy(folder) then
			local ok, rebuilt = pcall(rebuildDecor)
			if ok then
				print("[StageDecor] Rebuilt runtime stage decor: " .. tostring(rebuilt) .. "/" .. tostring(STAGE_COUNT))
			else
				warn("[StageDecor] Rebuild failed: " .. tostring(rebuilt))
			end
		end
	end
end)
