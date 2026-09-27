          
                                                                               
                                                                             
                                                                                
                                                                           
                                                                               
                                                                          
                                                     

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local displayRemote = ReplicatedStorage
	:WaitForChild("Remotes")
	:WaitForChild("GlobalLeaderboardDisplay")

local IMPORTED_MODEL_NAME = "leaderboard1"
local DISPLAY_COUNT = 100
local BOARD_PIXELS_PER_STUD = 46
local BOARD_VISIBLE_ROWS = 6.1
local CONTENT_X_SCALE = 0.015
local CONTENT_WIDTH_SCALE = 0.97
local ROW_RIGHT_INSET_PIXELS = 14
local CHAMPION_FOLDER_NAME = "LeaderboardChampionVisuals_LOCAL"
local CHAMPION_VISUAL_VERSION = "V306KBA"
local CHAMPION_RETRY_SECONDS = 15

local RANK_X_SCALE = 0.012
local RANK_WIDTH_SCALE = 0.105
local USERNAME_X_SCALE = 0.125
local USERNAME_WIDTH_SCALE = 0.50
local VALUE_X_SCALE = 0.63
local VALUE_WIDTH_SCALE = 0.35

local categories = {
	{
		Id = "Robux",
		Title = "MOST ROBUX SPENT",
		ColumnTitle = "ROBUX",
		Primary = Color3.fromRGB(5, 158, 27),
		Accent = Color3.fromRGB(0, 255, 92),
		Background = Color3.fromRGB(2, 32, 10),
		RowA = Color3.fromRGB(3, 55, 16),
		RowB = Color3.fromRGB(2, 43, 12),
	},
	{
		Id = "Speed",
		Title = "MOST SPEED",
		ColumnTitle = "SPEED",
		Primary = Color3.fromRGB(5, 92, 250),
		Accent = Color3.fromRGB(0, 210, 255),
		Background = Color3.fromRGB(2, 17, 52),
		RowA = Color3.fromRGB(3, 35, 80),
		RowB = Color3.fromRGB(2, 27, 66),
	},
	{
		Id = "Wins",
		Title = "MOST WINS",
		ColumnTitle = "WINS",
		Primary = Color3.fromRGB(255, 158, 4),
		Accent = Color3.fromRGB(255, 224, 38),
		Background = Color3.fromRGB(45, 34, 2),
		RowA = Color3.fromRGB(74, 55, 3),
		RowB = Color3.fromRGB(60, 44, 2),
	},
}

local categoryById = {}
for _, category in ipairs(categories) do
	categoryById[category.Id] = category
end

local function addCorner(instance, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance
end

local function addStroke(instance, color, thickness, transparency)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Transparency = transparency or 0
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = instance
end

local function makeText(parent, name, position, size, text, font, color, zIndex)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Text = text
	label.Font = font or Enum.Font.GothamBold
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.TextScaled = true
	label.TextWrapped = false
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 0
	label.ZIndex = zIndex or 3
	label.Parent = parent
	return label
end

local function constrainText(label, minimum, maximum)
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MinTextSize = minimum
	constraint.MaxTextSize = maximum
	constraint.Parent = label
end

local function findImportedPart(model, name)
	local instance = model:FindFirstChild(name, true)
	if instance and instance:IsA("BasePart") then
		return instance
	end
	return nil
end

local function hasImportedTargets(model)
	if not model or not model:IsA("Model") then
		return false
	end
	for _, category in ipairs(categories) do
		if not findImportedPart(model, category.Id .. "_LeaderboardScreen")
			or not findImportedPart(model, category.Id .. "_LeaderboardFrame")
			or not findImportedPart(model, category.Id .. "_ChampionStandTop")
		then
			return false
		end
	end
	return true
end

local function findImportedModel()
	local preferred = Workspace:FindFirstChild(IMPORTED_MODEL_NAME, true)
	if preferred and hasImportedTargets(preferred) then
		return preferred
	end
	return nil
end

local function partVerticalBounds(part)
	local half = part.Size * 0.5
	local cframe = part.CFrame
	local extentY = math.abs(cframe.RightVector.Y) * half.X
		+ math.abs(cframe.UpVector.Y) * half.Y
		+ math.abs(cframe.LookVector.Y) * half.Z
	return cframe.Position.Y - extentY, cframe.Position.Y + extentY
end

local importedModel = nil
local championFolder = nil
local championStates = {}

local function getCategoryTargets(model, category)
	local standTop = findImportedPart(model, category.Id .. "_ChampionStandTop")
	local frame = findImportedPart(model, category.Id .. "_LeaderboardFrame")
	local screen = findImportedPart(model, category.Id .. "_LeaderboardScreen")
	if not standTop or not frame or not screen then
		warn("[GlobalLeaderboardChampion] Missing exact targets for " .. category.Id)
		return nil, nil, nil
	end
	return standTop, frame, screen
end

local function getHorizontalFront(screen)
	local horizontalFront = Vector3.new(screen.CFrame.LookVector.X, 0, screen.CFrame.LookVector.Z)
	if horizontalFront.Magnitude <= 1e-4 then
		return Vector3.new(0, 0, -1)
	end
	return horizontalFront.Unit
end

local function getR6BodyHeight(model)
	local minimumY = math.huge
	local maximumY = -math.huge
	local found = false
	for _, partName in ipairs({
		"Head",
		"Torso",
		"Left Arm",
		"Right Arm",
		"Left Leg",
		"Right Leg",
	}) do
		local part = model:FindFirstChild(partName)
		if part and part:IsA("BasePart") then
			local partMinimumY, partMaximumY = partVerticalBounds(part)
			minimumY = math.min(minimumY, partMinimumY)
			maximumY = math.max(maximumY, partMaximumY)
			found = true
		end
	end
	if found and maximumY > minimumY then
		return maximumY - minimumY
	end
	return 0
end

local function getR6FeetBottomY(model)
	local minimumY = math.huge
	local found = false
	for _, partName in ipairs({ "Left Leg", "Right Leg" }) do
		local part = model:FindFirstChild(partName)
		if part and part:IsA("BasePart") then
			local partMinimumY = partVerticalBounds(part)
			minimumY = math.min(minimumY, partMinimumY)
			found = true
		end
	end
	return found and minimumY or nil
end

local function sanitizeAndAnchorChampion(model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("Script")
			or descendant:IsA("LocalScript")
			or descendant:IsA("Tool")
			or descendant:IsA("Highlight")
			or descendant:IsA("PointLight")
			or descendant:IsA("SpotLight")
			or descendant:IsA("SurfaceLight")
		then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
			descendant.AssemblyLinearVelocity = Vector3.zero
			descendant.AssemblyAngularVelocity = Vector3.zero
		end
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid.NameDisplayDistance = 0
		humanoid.AutoRotate = false
		humanoid.Sit = false
		humanoid.PlatformStand = false
		humanoid.EvaluateStateMachine = false
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
	end
end

local function placeFullAppearanceOnExactStand(model, boardModel, category)
	local standTop, frame, screen = getCategoryTargets(boardModel, category)
	if not standTop or not frame or not screen then
		return false
	end

	sanitizeAndAnchorChampion(model)
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end
	model.PrimaryPart = root

	local bodyHeight = getR6BodyHeight(model)
	if bodyHeight <= 0.01 then
		return false
	end
	local targetAvatarHeight = math.clamp(frame.Size.Y * 1.12, 10, 18)
	local currentScale = 1
	local scaleReadSuccess, returnedScale = pcall(function()
		return model:GetScale()
	end)
	if scaleReadSuccess and type(returnedScale) == "number" and returnedScale > 0 then
		currentScale = returnedScale
	end
	local scaleSuccess = pcall(function()
		model:ScaleTo(currentScale * targetAvatarHeight / bodyHeight)
	end)
	if not scaleSuccess then
		return false
	end

	local _, standTopSurfaceY = partVerticalBounds(standTop)
	local horizontalFront = getHorizontalFront(screen)
	local standPosition = Vector3.new(standTop.Position.X, standTopSurfaceY, standTop.Position.Z)
	model:PivotTo(CFrame.lookAt(standPosition, standPosition + horizontalFront, Vector3.yAxis))
	local feetBottomY = getR6FeetBottomY(model)
	if not feetBottomY then
		return false
	end
	model:PivotTo(model:GetPivot() + Vector3.new(0, standTopSurfaceY - feetBottomY, 0))

	local verifiedFeetY = getR6FeetBottomY(model)
	if not verifiedFeetY then
		return false
	end
	local feetError = verifiedFeetY - standTopSurfaceY
	model:SetAttribute("ChampionSupportPart", standTop.Name)
	model:SetAttribute("ChampionSupportY", standTopSurfaceY)
	model:SetAttribute("ChampionFeetLockError", feetError)
	model:SetAttribute("ChampionPlacementRoute", "V306KBA_ClientExactStandTop_AllPartsAnchored")
	return math.abs(feetError) <= 0.01
end

                                                                            
                                                                            
                                                                           
local function createNeutralR6Champion(parent, model, category)
	local standTop, frame, screen = getCategoryTargets(model, category)
	if not standTop or not frame or not screen then
		return nil
	end

	local targetAvatarHeight = math.clamp(frame.Size.Y * 1.12, 10, 18)
	local scale = targetAvatarHeight / 5
	local _, standTopSurfaceY = partVerticalBounds(standTop)
	local dummy = Instance.new("Model")
	dummy.Name = category.Id .. "_ChampionFallback_R6"
	dummy:SetAttribute("ClientOwnedLeaderboardChampion", true)
	dummy:SetAttribute("ChampionVisualKind", "NeutralR6Fallback")
	dummy:SetAttribute("ChampionPublicAppearanceUserId", 0)
	dummy:SetAttribute("ChampionSupportPart", standTop.Name)
	dummy:SetAttribute("ChampionSupportY", standTopSurfaceY)
	dummy:SetAttribute("ChampionFeetLockError", 0)
	dummy:SetAttribute("ChampionPlacementRoute", "V306KBA_ClientExactStandTop_NoLabel")

	local function makePart(name, size, position, color)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size * scale
		part.CFrame = CFrame.new(position * scale)
		part.Color = color
		part.Material = Enum.Material.SmoothPlastic
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Parent = dummy
		return part
	end

	local root = makePart("HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0), Color3.fromRGB(110, 110, 110))
	root.Transparency = 1
	makePart("Torso", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0), category.Accent)
	local head = makePart("Head", Vector3.new(2, 1, 1), Vector3.new(0, 4.5, 0), Color3.fromRGB(255, 220, 180))
	makePart("Left Arm", Vector3.new(1, 2, 1), Vector3.new(-1.5, 3, 0), Color3.fromRGB(255, 220, 180))
	makePart("Right Arm", Vector3.new(1, 2, 1), Vector3.new(1.5, 3, 0), Color3.fromRGB(255, 220, 180))
	makePart("Left Leg", Vector3.new(1, 2, 1), Vector3.new(-0.5, 1, 0), Color3.fromRGB(45, 45, 55))
	makePart("Right Leg", Vector3.new(1, 2, 1), Vector3.new(0.5, 1, 0), Color3.fromRGB(45, 45, 55))

	local face = Instance.new("Decal")
	face.Name = "face"
	face.Face = Enum.NormalId.Front
	face.Texture = "rbxasset://textures/face.png"
	face.Parent = head

	dummy.PrimaryPart = root
	dummy.Parent = parent
	local horizontalFront = getHorizontalFront(screen)
	                                                                         
	                                                                          
	local rootPosition = Vector3.new(
		standTop.Position.X,
		standTopSurfaceY + 3 * scale,
		standTop.Position.Z
	)
	dummy:PivotTo(CFrame.lookAt(rootPosition, rootPosition + horizontalFront, Vector3.yAxis))
	return dummy
end

local function getChampionState(category)
	local state = championStates[category.Id]
	if state then
		return state
	end
	state = {
		Category = category,
		Generation = 0,
		DesiredUserId = nil,
		RequestedUserId = nil,
		CurrentUserId = nil,
		CurrentVisual = nil,
		LastFailureUserId = nil,
		LastFailureAt = 0,
	}
	championStates[category.Id] = state
	return state
end

local function ensureNeutralChampion(category)
	if not championFolder or not championFolder.Parent or not importedModel then
		return nil
	end
	local state = getChampionState(category)
	local current = state.CurrentVisual
	if current
		and current.Parent == championFolder
		and current:GetAttribute("ChampionVisualKind") == "NeutralR6Fallback"
	then
		return current
	end

	local neutral = createNeutralR6Champion(championFolder, importedModel, category)
	if not neutral then
		return nil
	end
	state.CurrentVisual = neutral
	state.CurrentUserId = nil
	if current and current ~= neutral then
		current:Destroy()
	end
	return neutral
end

local function createFullAppearanceR6(userId)
	local description = Players:GetHumanoidDescriptionFromUserIdAsync(userId)
	local createSuccess, avatarOrError = pcall(function()
		return Players:CreateHumanoidModelFromDescriptionAsync(
			description,
			Enum.HumanoidRigType.R6
		)
	end)
	description:Destroy()
	if not createSuccess then
		error(avatarOrError)
	end
	return avatarOrError
end

local function requestChampionAppearance(category, rows)
	if not championFolder or not championFolder.Parent or not importedModel then
		return
	end
	local state = getChampionState(category)
	local firstRow = type(rows) == "table" and rows[1] or nil
	local userId = firstRow and math.floor(tonumber(firstRow.UserId) or 0) or 0
	if userId <= 0 then
		if state.DesiredUserId ~= nil then
			state.Generation += 1
		end
		state.DesiredUserId = nil
		state.RequestedUserId = nil
		ensureNeutralChampion(category)
		return
	end

	if state.CurrentUserId == userId
		and state.CurrentVisual
		and state.CurrentVisual.Parent == championFolder
	then
		return
	end

	if state.DesiredUserId ~= userId then
		state.Generation += 1
		state.DesiredUserId = userId
		state.RequestedUserId = nil
		ensureNeutralChampion(category)
	end

	if state.RequestedUserId == userId then
		return
	end
	if state.LastFailureUserId == userId
		and os.clock() - state.LastFailureAt < CHAMPION_RETRY_SECONDS
	then
		return
	end

	state.RequestedUserId = userId
	local generation = state.Generation
	task.spawn(function()
		local success, avatarOrError = pcall(function()
			return createFullAppearanceR6(userId)
		end)
		if generation ~= state.Generation
			or state.DesiredUserId ~= userId
			or not championFolder
			or not championFolder.Parent
		then
			if success and avatarOrError and avatarOrError:IsA("Model") then
				avatarOrError:Destroy()
			end
			return
		end
		if not success or not avatarOrError or not avatarOrError:IsA("Model") then
			state.RequestedUserId = nil
			state.LastFailureUserId = userId
			state.LastFailureAt = os.clock()
			warn(string.format(
				"[GlobalLeaderboardChampion] %s could not load #1 user %d; keeping the exact-StandTop neutral R6: %s",
				category.Id,
				userId,
				tostring(avatarOrError)
			))
			return
		end

		local avatar = avatarOrError
		avatar.Name = category.Id .. "_NumberOneR6FullAppearance_" .. tostring(userId)
		avatar:SetAttribute("ClientOwnedLeaderboardChampion", true)
		avatar:SetAttribute("ChampionVisualKind", "NumberOneFullPublicAppearanceR6")
		avatar:SetAttribute("ChampionPublicAppearanceUserId", userId)
		avatar.Parent = championFolder
		if not placeFullAppearanceOnExactStand(avatar, importedModel, category) then
			avatar:Destroy()
			state.RequestedUserId = nil
			state.LastFailureUserId = userId
			state.LastFailureAt = os.clock()
			warn(string.format(
				"[GlobalLeaderboardChampion] %s rejected #1 user %d because its forced-R6 model could not be locked to %s.",
				category.Id,
				userId,
				category.Id .. "_ChampionStandTop"
			))
			return
		end

		if generation ~= state.Generation or state.DesiredUserId ~= userId then
			avatar:Destroy()
			return
		end
		local oldVisual = state.CurrentVisual
		state.CurrentVisual = avatar
		state.CurrentUserId = userId
		state.RequestedUserId = nil
		state.LastFailureUserId = nil
		state.LastFailureAt = 0
		if oldVisual and oldVisual ~= avatar then
			oldVisual:Destroy()
		end
		print(string.format(
			"[GlobalLeaderboardChampion] V306KBA displayed %s #1 user %d as an anchored full-appearance R6.",
			category.Id,
			userId
		))
	end)
end

local function createChampionFolder(model)
	local oldCurrent = model:FindFirstChild(CHAMPION_FOLDER_NAME)
	if oldCurrent then
		oldCurrent:Destroy()
	end
	local oldStudioPreview = model:FindFirstChild("StudioLeaderboardR6Preview_LOCAL")
	if oldStudioPreview then
		oldStudioPreview:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = CHAMPION_FOLDER_NAME
	folder:SetAttribute("ClientOwned", true)
	folder:SetAttribute("ChampionVisualVersion", CHAMPION_VISUAL_VERSION)
	folder.Parent = model
	return folder
end

local function createBoardGui(model, category)
	local screen = findImportedPart(model, category.Id .. "_LeaderboardScreen")
	if not screen then
		return nil
	end

	local surfaceName = "GlobalLeaderboardSurface_" .. category.Id
	local oldSurface = playerGui:FindFirstChild(surfaceName)
	if oldSurface then
		oldSurface:Destroy()
	end

	local surface = Instance.new("SurfaceGui")
	surface.Name = surfaceName
	surface.Active = true
	surface.Adornee = screen
	surface.Face = Enum.NormalId.Front
	surface.AlwaysOnTop = false
	surface.LightInfluence = 1
	surface.MaxDistance = 400
	surface.ResetOnSpawn = false
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = BOARD_PIXELS_PER_STUD
	surface.ZOffset = 0.03
	surface.Parent = playerGui

	if not screen.CanQuery then
		warn("[GlobalLeaderboardDisplay] " .. screen:GetFullName() .. " must have CanQuery enabled for scrolling input.")
	end

	local root = Instance.new("Frame")
	root.Name = "LeaderboardCanvas"
	root.BackgroundColor3 = category.Background
	root.BackgroundTransparency = 0
	root.BorderSizePixel = 0
	root.ClipsDescendants = true
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = surface

	local title = makeText(
		root,
		"Title",
		UDim2.fromScale(0.025, 0.012),
		UDim2.fromScale(0.95, 0.13),
		category.Title,
		Enum.Font.GothamBlack,
		category.Accent,
		4
	)
	constrainText(title, 38, 100)

	local divider = Instance.new("Frame")
	divider.Name = "TitleDivider"
	divider.BackgroundColor3 = category.Primary
	divider.BorderSizePixel = 0
	divider.Position = UDim2.fromScale(0.035, 0.145)
	divider.Size = UDim2.fromScale(0.93, 0.009)
	divider.Parent = root
	addCorner(divider, 3)

	                                                                            
	                                                                           
	                                                                         
	local headerFrame = Instance.new("Frame")
	headerFrame.Name = "ColumnHeader"
	headerFrame.BackgroundTransparency = 1
	headerFrame.BorderSizePixel = 0
	headerFrame.Position = UDim2.fromScale(CONTENT_X_SCALE, 0.158)
	headerFrame.Size = UDim2.new(CONTENT_WIDTH_SCALE, -ROW_RIGHT_INSET_PIXELS, 0.062, 0)
	headerFrame.Parent = root

	local rankHeader = makeText(headerFrame, "RankHeader", UDim2.fromScale(RANK_X_SCALE, 0), UDim2.fromScale(RANK_WIDTH_SCALE, 1), "#", Enum.Font.GothamBlack, Color3.new(1, 1, 1), 3)
	local nameHeader = makeText(headerFrame, "NameHeader", UDim2.fromScale(USERNAME_X_SCALE, 0), UDim2.fromScale(USERNAME_WIDTH_SCALE, 1), "USERNAME", Enum.Font.GothamBlack, category.Accent, 3)
	local valueHeader = makeText(headerFrame, "ValueHeader", UDim2.fromScale(VALUE_X_SCALE, 0), UDim2.fromScale(VALUE_WIDTH_SCALE, 1), category.ColumnTitle, Enum.Font.GothamBlack, category.Accent, 3)
	nameHeader.TextXAlignment = Enum.TextXAlignment.Left
	valueHeader.TextXAlignment = Enum.TextXAlignment.Right
	for _, label in ipairs({ rankHeader, nameHeader, valueHeader }) do
		constrainText(label, 28, 80)
	end

	local canvasHeightPixels = math.max(1, math.floor(screen.Size.Y * BOARD_PIXELS_PER_STUD))
	local scrollingHeightPixels = canvasHeightPixels * 0.755
	local rowStepPixels = math.max(48, math.floor(scrollingHeightPixels / BOARD_VISIBLE_ROWS))
	local rowGapPixels = math.max(4, math.floor(rowStepPixels * 0.07))
	local rowHeightPixels = rowStepPixels - rowGapPixels

	local scrollingFrame = Instance.new("ScrollingFrame")
	scrollingFrame.Name = "Top100Scroll"
	scrollingFrame.Active = true
	scrollingFrame.BackgroundTransparency = 1
	scrollingFrame.BorderSizePixel = 0
	scrollingFrame.Position = UDim2.fromScale(CONTENT_X_SCALE, 0.225)
	scrollingFrame.Size = UDim2.fromScale(CONTENT_WIDTH_SCALE, 0.755)
	scrollingFrame.CanvasPosition = Vector2.zero
	scrollingFrame.CanvasSize = UDim2.fromOffset(0, DISPLAY_COUNT * rowStepPixels)
	scrollingFrame.AutomaticCanvasSize = Enum.AutomaticSize.None
	scrollingFrame.ScrollingDirection = Enum.ScrollingDirection.Y
	scrollingFrame.ScrollingEnabled = true
	scrollingFrame.ElasticBehavior = Enum.ElasticBehavior.Never
	scrollingFrame.ScrollBarThickness = 12
	scrollingFrame.ScrollBarImageColor3 = category.Accent
	scrollingFrame.ScrollBarImageTransparency = 0
	scrollingFrame.VerticalScrollBarInset = Enum.ScrollBarInset.Always
	scrollingFrame.ClipsDescendants = true
	scrollingFrame.ZIndex = 2
	scrollingFrame.Parent = root

	local rowObjects = {}
	for index = 1, DISPLAY_COUNT do
		local row = Instance.new("Frame")
		row.Name = "Row" .. tostring(index)
		row.BackgroundColor3 = index % 2 == 1 and category.RowA or category.RowB
		row.BackgroundTransparency = index == 1 and 0.04 or 0.12
		row.BorderSizePixel = 0
		row.Position = UDim2.fromOffset(0, (index - 1) * rowStepPixels)
		row.Size = UDim2.new(1, -ROW_RIGHT_INSET_PIXELS, 0, rowHeightPixels)
		row.Visible = false
		row.ZIndex = 2
		row.Parent = scrollingFrame
		addCorner(row, 4)
		if index == 1 then
			addStroke(row, category.Accent, 2, 0.05)
		end

		local rankColor = Color3.fromRGB(245, 245, 245)
		if index == 1 then
			rankColor = Color3.fromRGB(255, 220, 45)
		elseif index == 2 then
			rankColor = Color3.fromRGB(220, 232, 241)
		elseif index == 3 then
			rankColor = Color3.fromRGB(224, 145, 78)
		end

		local rank = makeText(row, "Rank", UDim2.fromScale(RANK_X_SCALE, 0.02), UDim2.fromScale(RANK_WIDTH_SCALE, 0.96), tostring(index), Enum.Font.GothamBlack, rankColor, 4)
		local username = makeText(row, "Username", UDim2.fromScale(USERNAME_X_SCALE, 0.02), UDim2.fromScale(USERNAME_WIDTH_SCALE, 0.96), "---", Enum.Font.GothamBold, Color3.fromRGB(248, 250, 252), 4)
		local value = makeText(row, "Value", UDim2.fromScale(VALUE_X_SCALE, 0.02), UDim2.fromScale(VALUE_WIDTH_SCALE, 0.96), "---", Enum.Font.GothamBlack, category.Accent, 4)
		username.TextXAlignment = Enum.TextXAlignment.Left
		value.TextXAlignment = Enum.TextXAlignment.Right
		username.TextTruncate = Enum.TextTruncate.AtEnd
		value.TextTruncate = Enum.TextTruncate.AtEnd
		for _, label in ipairs({ rank, username, value }) do
			constrainText(label, 34, 100)
		end

		table.insert(rowObjects, {
			Container = row,
			Rank = rank,
			Username = username,
			Value = value,
		})
	end

	local status = makeText(
		root,
		"Status",
		UDim2.fromScale(0.15, 0.43),
		UDim2.fromScale(0.70, 0.14),
		"LOADING GLOBAL DATA...",
		Enum.Font.GothamBlack,
		category.Accent,
		10
	)
	constrainText(status, 28, 80)

	return {
		Category = category,
		Rows = rowObjects,
		ScrollingFrame = scrollingFrame,
		Status = status,
		RowStepPixels = rowStepPixels,
		Screen = screen,
	}
end

local views = {}
local pendingData = {}

local function renderRows(view, rows, hasError)
	rows = type(rows) == "table" and rows or {}
	for index, rowView in ipairs(view.Rows) do
		local entry = rows[index]
		if entry then
			rowView.Container.Visible = true
			rowView.Rank.Text = tostring(tonumber(entry.Rank) or index)
			rowView.Username.Text = tostring(entry.Username or ("User " .. tostring(index)))
			rowView.Value.Text = tostring(entry.Value or "0")
		else
			rowView.Container.Visible = false
		end
	end

	view.ScrollingFrame.CanvasSize = UDim2.fromOffset(
		0,
		math.max(#rows, 1) * view.RowStepPixels
	)
	if hasError then
		view.Status.Text = "GLOBAL DATA TEMPORARILY UNAVAILABLE"
		view.Status.TextColor3 = Color3.fromRGB(235, 55, 62)
		view.Status.Visible = true
	elseif #rows == 0 then
		view.Status.Text = "WAITING FOR GLOBAL DATA..."
		view.Status.TextColor3 = view.Category.Accent
		view.Status.Visible = true
	else
		view.Status.Visible = false
	end
	requestChampionAppearance(view.Category, rows)
end

displayRemote.OnClientEvent:Connect(function(categoryId, rows, hasError)
	if not categoryById[categoryId] then
		return
	end
	pendingData[categoryId] = {
		Rows = rows,
		HasError = hasError == true,
	}
	local view = views[categoryId]
	if view then
		renderRows(view, rows, hasError == true)
	end
end)


task.spawn(function()
	local model = findImportedModel()
	while not model do
		task.wait(1)
		model = findImportedModel()
	end
	importedModel = model
	championFolder = createChampionFolder(model)
	for _, category in ipairs(categories) do
		ensureNeutralChampion(category)
	end

	for _, category in ipairs(categories) do
		local view = createBoardGui(model, category)
		if view then
			views[category.Id] = view
			local pending = pendingData[category.Id]
			if pending then
				renderRows(view, pending.Rows, pending.HasError)
			end
		end
		task.wait()
	end

	displayRemote:FireServer("Request")
end)
