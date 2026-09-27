                                                          
                                                                           
                                                                               
                                                                            

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
if Config.IsWorld2Place ~= true then
	return
end

local displayRemote = ReplicatedStorage
	:WaitForChild("Remotes")
	:WaitForChild("GlobalLeaderboardDisplay")

local IMPORTED_MODEL_NAME = "leaderboard1"
local CHAMPION_FOLDER_NAME = "World2LeaderboardChampionVisuals_LOCAL"
local CHAMPION_VISUAL_VERSION = "V306KN"
local CHAMPION_RETRY_SECONDS = 15

local categories = {
	{ Id = "Robux", Accent = Color3.fromRGB(0, 255, 92) },
	{ Id = "Speed", Accent = Color3.fromRGB(0, 210, 255) },
	{ Id = "Wins", Accent = Color3.fromRGB(255, 224, 38) },
}

local categoryById = {}
for _, category in ipairs(categories) do
	categoryById[category.Id] = category
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

local function getCategoryTargets(model, category)
	local standTop = findImportedPart(model, category.Id .. "_ChampionStandTop")
	local frame = findImportedPart(model, category.Id .. "_LeaderboardFrame")
	local screen = findImportedPart(model, category.Id .. "_LeaderboardScreen")
	if not standTop or not frame or not screen then
		warn("[World2LeaderboardChampion] Missing exact targets for " .. category.Id)
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
	model:SetAttribute("ChampionPlacementRoute", "V306KN_World2ClientExactStandTop_AllPartsAnchored")
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
	dummy.Name = category.Id .. "_World2ChampionFallback_R6"
	dummy:SetAttribute("ClientOwnedLeaderboardChampion", true)
	dummy:SetAttribute("ChampionVisualKind", "NeutralR6Fallback")
	dummy:SetAttribute("ChampionPublicAppearanceUserId", 0)
	dummy:SetAttribute("ChampionSupportPart", standTop.Name)
	dummy:SetAttribute("ChampionSupportY", standTopSurfaceY)
	dummy:SetAttribute("ChampionFeetLockError", 0)
	dummy:SetAttribute("ChampionPlacementRoute", "V306KN_World2ClientExactStandTop_NoLabel")

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

	local root = makePart(
		"HumanoidRootPart",
		Vector3.new(2, 2, 1),
		Vector3.new(0, 3, 0),
		Color3.fromRGB(110, 110, 110)
	)
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

local importedModel = nil
local championFolder = nil
local championStates = {}
local pendingRows = {}

local function getChampionState(category)
	local state = championStates[category.Id]
	if state then
		return state
	end
	state = {
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
				"[World2LeaderboardChampion] %s could not load #1 user %d; keeping the exact-StandTop neutral R6: %s",
				category.Id,
				userId,
				tostring(avatarOrError)
			))
			return
		end

		local avatar = avatarOrError
		avatar.Name = category.Id .. "_World2NumberOneR6FullAppearance_" .. tostring(userId)
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
				"[World2LeaderboardChampion] %s rejected #1 user %d because its forced-R6 model could not be locked to %s.",
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
			"[World2LeaderboardChampion] V306KN displayed %s #1 user %d as an anchored full-appearance R6.",
			category.Id,
			userId
		))
	end)
end

local function createChampionFolder(model)
	for _, oldName in ipairs({
		CHAMPION_FOLDER_NAME,
		"LeaderboardChampionVisuals_LOCAL",
		"StudioLeaderboardR6Preview_LOCAL",
	}) do
		local oldFolder = model:FindFirstChild(oldName)
		if oldFolder then
			oldFolder:Destroy()
		end
	end

	local folder = Instance.new("Folder")
	folder.Name = CHAMPION_FOLDER_NAME
	folder:SetAttribute("ClientOwned", true)
	folder:SetAttribute("ChampionVisualVersion", CHAMPION_VISUAL_VERSION)
	folder.Parent = model
	return folder
end

                                                                              
displayRemote.OnClientEvent:Connect(function(categoryId, rows)
	local category = categoryById[categoryId]
	if not category then
		return
	end
	pendingRows[categoryId] = type(rows) == "table" and rows or {}
	if championFolder then
		requestChampionAppearance(category, pendingRows[categoryId])
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
		local rows = pendingRows[category.Id]
		if rows then
			requestChampionAppearance(category, rows)
		end
	end

	                                                                           
	                                                                               
	displayRemote:FireServer("Request")
end)

print("[World2LeaderboardChampion] V306KN active. Exact-StandTop neutral R6 fallbacks are replaced only by sanitized #1 full public R6 appearances.")
