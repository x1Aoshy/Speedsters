                                     
  
                                                                               
                                           
                                                         
                                      
                                                         
  
                                                                             
                                                                               
                                                                           

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

if Config.IsWorld2Place ~= true then
	return
end

local STAGE_COUNT = math.max(1, math.floor(tonumber(Config.StageCount) or 10))
local SAFE_ZONE_SUFFIX = tostring(Config.World2SafeZoneSuffix or ".2")
local RUNTIME_FOLDER_NAME = "StageDecor_Runtime"
local VERSION = "V306HAWorld2Stages"
local WAIT_SECONDS = 20

local SKIP_STAGE_PRODUCT_ID = math.max(0, math.floor(tonumber(Config.SkipStageProductId) or 0))
local SKIP_PAD_SIZE = Vector3.new(8, 0.6, 8)
local SKIP_PAD_BASE_HEIGHT = 0.34
local SKIP_PAD_EDGE_INSET = 3
local SKIP_PAD_COLOR = Color3.fromRGB(0, 255, 85)
local SKIP_PAD_LIGHT_COLOR = Color3.fromRGB(80, 255, 135)
local SKIP_PAD_TEXT_COLOR = Color3.fromRGB(45, 255, 95)
local SKIP_PROMPT_COOLDOWN = 1.5

local LABEL_BOARD_SIZE = Vector3.new(46, 12.6, 0.2)
local LABEL_HEIGHT = 17.5

local safeZones = {}
local normalizedZoneNames = {}
local lastSkipPromptAt = {}
local rebuildQueued = false
local hasBuilt = false

local function normalizeName(value)
	return tostring(value or ""):lower():gsub("[^%w]", "")
end

local function safeZoneName(stage)
	return "SafeZone" .. tostring(stage) .. SAFE_ZONE_SUFFIX
end

for stage = 1, STAGE_COUNT do
	normalizedZoneNames[normalizeName(safeZoneName(stage))] = stage
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

local function considerSafeZone(object)
	if not object or not object.Parent or not isSupportedMapObject(object) then
		return false
	end

	local stage = normalizedZoneNames[normalizeName(object.Name)]
	if not stage then
		return false
	end

	local current = safeZones[stage]
	if current and current.Parent then
		local currentDepth = objectDepth(current)
		local candidateDepth = objectDepth(object)
		if candidateDepth > currentDepth
			or (candidateDepth == currentDepth and object:GetFullName() >= current:GetFullName())
		then
			return false
		end
	end

	safeZones[stage] = object
	return current ~= object
end

local function getBounds(object)
	if object and object:IsA("BasePart") then
		return object.CFrame, object.Size
	end
	if object and object:IsA("Model") then
		local ok, cframe, size = pcall(function()
			return object:GetBoundingBox()
		end)
		if ok then
			return cframe, size
		end
	end
	return nil, nil
end

local function getPivot(object)
	if not object then
		return nil
	end
	local ok, pivot = pcall(function()
		return object:GetPivot()
	end)
	return ok and pivot or nil
end

local function physicalParts(object)
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

local function verticalExtent(cframe, size)
	local half = size * 0.5
	return math.abs(cframe.RightVector.Y) * half.X
		+ math.abs(cframe.UpVector.Y) * half.Y
		+ math.abs(cframe.LookVector.Y) * half.Z
end

local function worldTopY(part)
	return part.Position.Y + verticalExtent(part.CFrame, part.Size)
end

local function projectedTopArea(part)
	local size = part.Size
	local cframe = part.CFrame
	return size.X * size.Z * math.abs(cframe.UpVector.Y)
		+ size.X * size.Y * math.abs(cframe.LookVector.Y)
		+ size.Y * size.Z * math.abs(cframe.RightVector.Y)
end

local function horizontalUnit(vector)
	local flat = Vector3.new(vector.X, 0, vector.Z)
	return flat.Magnitude >= 0.05 and flat.Unit or nil
end

local function projectedHalfExtent(cframe, size, direction)
	local half = size * 0.5
	return math.abs(cframe.RightVector:Dot(direction)) * half.X
		+ math.abs(cframe.UpVector:Dot(direction)) * half.Y
		+ math.abs(cframe.LookVector:Dot(direction)) * half.Z
end

local function findSurface(zone)
	if zone:IsA("BasePart") then
		return zone
	end

	local pivot = getPivot(zone)
	local bestPart = nil
	local bestScore = -math.huge
	for _, part in ipairs(physicalParts(zone)) do
		local score = projectedTopArea(part)
		if part.CanCollide then
			score *= 1.2
		end
		if part.Transparency >= 0.95 then
			score *= 0.55
		end
		if pivot then
			local offset = part.Position - pivot.Position
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

local function horizontalCFrame(position, referenceCFrame)
	local look = referenceCFrame and horizontalUnit(referenceCFrame.LookVector) or nil
	look = look or Vector3.new(0, 0, -1)
	return CFrame.lookAt(position, position + look, Vector3.yAxis)
end

local function findPlacement(zone)
	local surface = findSurface(zone)
	if surface and surface.CanCollide and surface.Transparency < 0.95 and surface.Size.Y <= 6 then
		local topPosition = Vector3.new(surface.Position.X, worldTopY(surface), surface.Position.Z)
		return horizontalCFrame(topPosition, surface.CFrame), surface
	end

	local zoneCFrame, zoneSize = getBounds(zone)
	if zoneCFrame and zoneSize then
		local excluded = {}
		local oldRuntime = Workspace:FindFirstChild(RUNTIME_FOLDER_NAME)
		if oldRuntime then
			table.insert(excluded, oldRuntime)
		end
		if zone:IsA("BasePart") then
			table.insert(excluded, zone)
		else
			for _, part in ipairs(physicalParts(zone)) do
				if part.Transparency >= 0.95 or not part.CanCollide then
					table.insert(excluded, part)
				end
			end
		end
		for _, player in ipairs(Players:GetPlayers()) do
			if player.Character then
				table.insert(excluded, player.Character)
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
			return horizontalCFrame(result.Position, zoneCFrame), result.Instance
		end

		local fallbackY = zoneCFrame.Position.Y - verticalExtent(zoneCFrame, zoneSize)
		return horizontalCFrame(
			Vector3.new(zoneCFrame.Position.X, fallbackY, zoneCFrame.Position.Z),
			zoneCFrame
		), surface
	end

	if surface then
		local topPosition = Vector3.new(surface.Position.X, worldTopY(surface), surface.Position.Z)
		return horizontalCFrame(topPosition, surface.CFrame), surface
	end
	return nil, nil
end

local function placementHalfExtent(zone, surface, direction)
	local available = nil
	local zoneCFrame, zoneSize = getBounds(zone)
	if zoneCFrame and zoneSize then
		available = projectedHalfExtent(zoneCFrame, zoneSize, direction)
	end
	if surface and surface:IsA("BasePart") then
		local surfaceExtent = projectedHalfExtent(surface.CFrame, surface.Size, direction)
		available = available and math.min(available, surfaceExtent) or surfaceExtent
	end
	return math.max(4, available or 4)
end

local function getCourseDirection(stage, placements)
	local current = placements[stage]
	if not current then
		return Vector3.new(0, 0, -1)
	end

	if stage < STAGE_COUNT and placements[stage + 1] then
		local direction = horizontalUnit(placements[stage + 1].CFrame.Position - current.CFrame.Position)
		if direction then
			return direction
		end
	end
	if stage > 1 and placements[stage - 1] then
		local direction = horizontalUnit(current.CFrame.Position - placements[stage - 1].CFrame.Position)
		if direction then
			return direction
		end
	end
	return horizontalUnit(current.CFrame.LookVector) or Vector3.new(0, 0, -1)
end

local function clearChildren(instance)
	for _, child in ipairs(instance:GetChildren()) do
		child:Destroy()
	end
end

local function getRuntimeFolder()
	local folder = Workspace:FindFirstChild(RUNTIME_FOLDER_NAME)
	if folder and not folder:IsA("Folder") then
		folder:Destroy()
		folder = nil
	end
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = RUNTIME_FOLDER_NAME
		folder.Parent = Workspace
	end
	folder:SetAttribute("DecorVersion", VERSION)
	folder:SetAttribute("WorldNumber", 2)
	return folder
end

local function createLandingReference(parent, stage, placement, zone, surface, course, right)
	local halfRight = placementHalfExtent(zone, surface, right)
	local halfCourse = placementHalfExtent(zone, surface, course)
	local part = Instance.new("Part")
	part.Name = string.format("Stage%02d_Floor", stage)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(math.max(8, halfRight * 2), 0.1, math.max(8, halfCourse * 2))
	local center = placement.Position - Vector3.new(0, part.Size.Y * 0.5, 0)
	part.CFrame = CFrame.lookAt(center, center + course, Vector3.yAxis)
	part:SetAttribute("World2TeleportReference", true)
	part:SetAttribute("SafeZoneIndex", stage)
	part.Parent = parent
	return part
end

local function createStageLabel(parent, stage, placement, course)
	local board = Instance.new("Part")
	board.Name = string.format("Stage%02d_LabelBoard", stage)
	board.Anchored = true
	board.CanCollide = false
	board.CanTouch = false
	board.CanQuery = false
	board.CastShadow = false
	board.Transparency = 1
	board.Size = LABEL_BOARD_SIZE
	local position = placement.Position + Vector3.new(0, LABEL_HEIGHT, 0)
	board.CFrame = CFrame.lookAt(position, position + course, Vector3.yAxis)
	board.Parent = parent

	local recLevels = {
		[1] = 1, [2] = 7, [3] = 20, [4] = 30, [5] = 50,
		[6] = 60, [7] = 70, [8] = 80, [9] = 90, [10] = 100
	}
	local recLevel = recLevels[stage] or (stage * 10)

	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local gui = Instance.new("SurfaceGui")
		gui.Name = face == Enum.NormalId.Front and "FrontStageText" or "BackStageText"
		gui.Adornee = board
		gui.Face = face
		gui.AlwaysOnTop = false
		gui.LightInfluence = 0
		gui.MaxDistance = 0
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 8
		gui.Parent = board

		local stageLabel = Instance.new("TextLabel")
		stageLabel.Name = "StageNumberText"
		stageLabel.BackgroundTransparency = 1
		stageLabel.Position = UDim2.fromScale(0, 0)
		stageLabel.Size = UDim2.fromScale(1, 0.60)
		stageLabel.Font = Enum.Font.GothamBlack
		stageLabel.Text = "STAGE " .. tostring(stage)
		stageLabel.TextScaled = true
		stageLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		stageLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		stageLabel.TextStrokeTransparency = 0
		stageLabel.TextXAlignment = Enum.TextXAlignment.Center
		stageLabel.TextYAlignment = Enum.TextYAlignment.Bottom
		stageLabel.Parent = gui

		local stageOutline = Instance.new("UIStroke")
		stageOutline.Name = "ThickBlackOutline"
		stageOutline.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		stageOutline.Color = Color3.fromRGB(0, 0, 0)
		stageOutline.Thickness = 8
		stageOutline.Parent = stageLabel

		local recLabel = Instance.new("TextLabel")
		recLabel.Name = "RecommendedLevelText"
		recLabel.BackgroundTransparency = 1
		recLabel.Position = UDim2.fromScale(0.05, 0.60)
		recLabel.Size = UDim2.fromScale(0.90, 0.38)
		recLabel.Font = Enum.Font.GothamBlack
		recLabel.Text = "Recommended Level: " .. tostring(recLevel)
		recLabel.TextScaled = true
		recLabel.TextColor3 = Color3.fromRGB(255, 188, 24)
		recLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		recLabel.TextStrokeTransparency = 0
		recLabel.TextXAlignment = Enum.TextXAlignment.Center
		recLabel.TextYAlignment = Enum.TextYAlignment.Top
		recLabel.Parent = gui

		local recOutline = Instance.new("UIStroke")
		recOutline.Name = "RecOutline"
		recOutline.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		recOutline.Color = Color3.fromRGB(0, 0, 0)
		recOutline.Thickness = 6
		recOutline.Parent = recLabel
	end
end

local function playerFromHit(hit)
	if not hit or not hit:IsA("BasePart") then
		return nil
	end
	local character = hit:FindFirstAncestorOfClass("Model")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return Players:GetPlayerFromCharacter(character)
end

local function connectSkipPad(pad, stage)
	if stage >= STAGE_COUNT or SKIP_STAGE_PRODUCT_ID <= 0 then
		return
	end
	pad.Touched:Connect(function(hit)
		local player = playerFromHit(hit)
		if not player then
			return
		end
		local now = os.clock()
		if now - (lastSkipPromptAt[player] or -math.huge) < SKIP_PROMPT_COOLDOWN then
			return
		end
		lastSkipPromptAt[player] = now

		player:SetAttribute("PendingSkipStageFrom", stage)
		player:SetAttribute("PendingSkipStageTarget", stage + 1)
		player:SetAttribute("PendingSkipStageSetAt", Workspace:GetServerTimeNow())
		player:SetAttribute("PendingSkipStageWorld", 2)
		MarketplaceService:PromptProductPurchase(player, SKIP_STAGE_PRODUCT_ID)
	end)
end

local function createSkipPad(parent, stage, placement, zone, surface, course, right)
	if stage >= STAGE_COUNT then
		return
	end

	local halfRight = placementHalfExtent(zone, surface, right)
	local maximumOffset = math.max(0, halfRight - SKIP_PAD_SIZE.X * 0.5 - SKIP_PAD_EDGE_INSET)
	local position = placement.Position - right * maximumOffset
	position = Vector3.new(position.X, placement.Position.Y + SKIP_PAD_SIZE.Y * 0.5 + 0.03, position.Z)
	local padCFrame = CFrame.lookAt(position, position + course, Vector3.yAxis)

	local base = Instance.new("Part")
	base.Name = string.format("Stage%02d_SkipStagePad_BlackBase", stage)
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
		SKIP_PAD_SIZE.X + 1,
		SKIP_PAD_BASE_HEIGHT,
		SKIP_PAD_SIZE.Z + 1
	)
	base.CFrame = padCFrame
		* CFrame.new(0, -((SKIP_PAD_SIZE.Y + SKIP_PAD_BASE_HEIGHT) * 0.5) + 0.02, 0)
	base.Parent = parent

	local pad = Instance.new("Part")
	pad.Name = string.format("Stage%02d_SkipStagePad", stage)
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
	pad:SetAttribute("SkipFromStage", stage)
	pad:SetAttribute("SkipTargetStage", stage + 1)
	pad:SetAttribute("SafeZoneIndex", stage)
	pad:SetAttribute("WorldNumber", 2)
	pad.Parent = parent

	local light = Instance.new("PointLight")
	light.Name = "PadLight"
	light.Color = SKIP_PAD_LIGHT_COLOR
	light.Brightness = 0.8
	light.Range = 4.5
	light.Shadows = false
	light.Parent = pad

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "SkipStageBillboard"
	billboard.Adornee = pad
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.Size = UDim2.fromOffset(170, 39)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 2.25, 0)
	billboard.MaxDistance = 117
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
	label.TextSize = 26
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = billboard

	connectSkipPad(pad, stage)
end

local function countReadyZones()
	local count = 0
	for stage = 1, STAGE_COUNT do
		if safeZones[stage] and safeZones[stage].Parent then
			count += 1
		end
	end
	return count
end

local function buildAllStages()
	local placements = {}
	for stage = 1, STAGE_COUNT do
		local zone = safeZones[stage]
		if zone and zone.Parent then
			local cframe, surface = findPlacement(zone)
			if cframe then
				placements[stage] = {
					CFrame = cframe,
					Surface = surface,
					Zone = zone,
				}
			end
		end
	end

	local folder = getRuntimeFolder()
	clearChildren(folder)
	local built = 0
	for stage = 1, STAGE_COUNT do
		local placement = placements[stage]
		if placement then
			local stageModel = Instance.new("Model")
			stageModel.Name = string.format("Stage%02d_Decor", stage)
			stageModel:SetAttribute("WorldNumber", 2)
			stageModel:SetAttribute("SafeZoneName", safeZoneName(stage))
			stageModel.Parent = folder

			local course = getCourseDirection(stage, placements)
			local right = course:Cross(Vector3.yAxis)
			right = right.Magnitude >= 0.05 and right.Unit or Vector3.xAxis
			createLandingReference(
				stageModel,
				stage,
				placement.CFrame,
				placement.Zone,
				placement.Surface,
				course,
				right
			)
			createStageLabel(stageModel, stage, placement.CFrame, course)
			createSkipPad(
				stageModel,
				stage,
				placement.CFrame,
				placement.Zone,
				placement.Surface,
				course,
				right
			)
			built += 1
		else
			warn("[World2StageSystem] Could not resolve " .. safeZoneName(stage))
		end
	end

	folder:SetAttribute("ConfiguredStages", built)
	folder:SetAttribute("NoGeneratedTreadmills", true)
	folder:SetAttribute("EventDrivenDiscovery", true)
	hasBuilt = built > 0
	print(
		"[World2StageSystem] "
			.. VERSION
			.. " built "
			.. tostring(built)
			.. "/"
			.. tostring(STAGE_COUNT)
			.. " authored stages | large left Skip pads | no stage treadmills | no polling scans"
	)
end

local function queueRebuild()
	if rebuildQueued then
		return
	end
	rebuildQueued = true
	task.delay(0.25, function()
		rebuildQueued = false
		if countReadyZones() == STAGE_COUNT then
			buildAllStages()
		end
	end)
end

Workspace.DescendantAdded:Connect(function(object)
	if considerSafeZone(object) then
		queueRebuild()
	end
end)

Workspace.DescendantRemoving:Connect(function(object)
	local stage = normalizedZoneNames[normalizeName(object.Name)]
	if stage and safeZones[stage] == object then
		safeZones[stage] = nil
		hasBuilt = false
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastSkipPromptAt[player] = nil
end)

                                                                                 
task.wait(1)
for _, object in ipairs(Workspace:GetDescendants()) do
	considerSafeZone(object)
end

local deadline = os.clock() + WAIT_SECONDS
while countReadyZones() < STAGE_COUNT and os.clock() < deadline do
	task.wait(0.1)
end

if countReadyZones() > 0 then
	buildAllStages()
else
	warn("[World2StageSystem] No SafeZoneN.2 objects were found; nothing was generated.")
end

if not hasBuilt then
	queueRebuild()
end
