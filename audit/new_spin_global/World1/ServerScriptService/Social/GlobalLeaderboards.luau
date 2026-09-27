          
                                                                            
                                                                             
                                                                         
                                                                           
                                                                             
                                                                            

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserService = game:GetService("UserService")
local Workspace = game:GetService("Workspace")

local displayRemote = ReplicatedStorage
	:WaitForChild("Remotes")
	:WaitForChild("GlobalLeaderboardDisplay")

local LEGACY_GENERATED_FOLDER_NAMES = {
	"GlobalLeaderboardsV306DA",
	"GlobalLeaderboardsV306DB",
	"GlobalLeaderboardsV306DC",
	"GlobalLeaderboardsV306DD",
	"GlobalLeaderboardsV306DE",
	"GlobalLeaderboardsV306DF",
	"GlobalLeaderboardsV306DG",
	"GlobalLeaderboardsV306DH",
	"GlobalLeaderboardsV306DI",
	"GlobalLeaderboardsV306DJ",
	"GlobalLeaderboardsV306DK",
	"GlobalLeaderboardsV306DL",
	"GlobalLeaderboardsV306DM",
}

local IMPORTED_MODEL_NAME = "leaderboard1"
local DISPLAY_COUNT = 100
local PUBLISH_INTERVAL_SECONDS = 60
local BOARD_REFRESH_SECONDS = 60
local CHAMPION_LABEL_MAX_DISTANCE = 60
                                                                           
                                                                           
local CHAMPION_FEET_CLEARANCE = 0
local CHAMPION_MANUAL_LIFT = 0
local FOOT_LOCK_EPSILON = 0.001
local MAX_SAFE_INTEGER = 9007199254740991
local DATASTORE_RETRIES = 3
local USERNAME_LOOKUP_LIMIT_PER_MINUTE = 240
local R6_DUMMY_BODY_COLOR = Color3.fromRGB(163, 162, 165)

                                                                               
                                                                              
local SPEED_MANTISSA_SCALE = 1e12
local SPEED_EXPONENT_SCALE = 1e13

local NUMBER_SUFFIXES = {
	"", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc",
	"Ud", "Dd", "Td", "Qad", "Qid", "Sxd", "Spd", "Ocd", "Nod", "Vg",
}

local function isFiniteNumber(value)
	return type(value) == "number"
		and value == value
		and value ~= math.huge
		and value ~= -math.huge
end

local function cleanOrderedInteger(value)
	value = tonumber(value) or 0
	if not isFiniteNumber(value) or value <= 0 then
		return 0
	end
	return math.clamp(math.floor(value), 0, MAX_SAFE_INTEGER)
end

local function formatCompact(value)
	value = tonumber(value) or 0
	if not isFiniteNumber(value) or value <= 0 then
		return "0"
	end
	if value < 1000 then
		return tostring(math.floor(value + 0.5))
	end

	local suffixIndex = math.floor(math.log10(value) / 3)
	if suffixIndex >= #NUMBER_SUFFIXES then
		return string.format("%.2e", value)
	end
	local scaled = value / (1000 ^ suffixIndex)
	local decimals = scaled >= 100 and 0 or (scaled >= 10 and 1 or 2)
	local text = string.format("%." .. tostring(decimals) .. "f", scaled)
	text = string.gsub(text, "(%..-)0+$", "%1")
	text = string.gsub(text, "%.$", "")
	return text .. NUMBER_SUFFIXES[suffixIndex + 1]
end

local function encodeSpeed(value)
	value = tonumber(value) or 0
	if not isFiniteNumber(value) or value <= 0 then
		return 0
	end

	local exponent = math.max(0, math.floor(math.log10(value)))
	local power = 10 ^ exponent
	local normalized = value / power
	local mantissa = math.floor(normalized * SPEED_MANTISSA_SCALE + 0.5)
	mantissa = math.clamp(mantissa, SPEED_MANTISSA_SCALE, SPEED_EXPONENT_SCALE - 1)
	return cleanOrderedInteger(exponent * SPEED_EXPONENT_SCALE + mantissa)
end

local function decodeSpeed(encoded)
	encoded = cleanOrderedInteger(encoded)
	if encoded <= 0 then
		return 0
	end
	local exponent = math.floor(encoded / SPEED_EXPONENT_SCALE)
	local mantissa = encoded - exponent * SPEED_EXPONENT_SCALE
	return (mantissa / SPEED_MANTISSA_SCALE) * (10 ^ exponent)
end

local function getRawSpeed(player)
	local dataFolder = player:FindFirstChild("SpeedsterData")
	local rawSpeed = dataFolder and dataFolder:FindFirstChild("RawSpeed")
	if rawSpeed and rawSpeed:IsA("NumberValue") then
		return rawSpeed
	end
	return nil
end

local function getLeaderstat(player, name)
	local leaderstats = player:FindFirstChild("leaderstats")
	local value = leaderstats and leaderstats:FindFirstChild(name)
	if value and (value:IsA("IntValue") or value:IsA("NumberValue")) then
		return value
	end
	return nil
end

local categories = {
	{
		Id = "Robux",
		Title = "MOST ROBUX SPENT",
		ColumnTitle = "ROBUX",
		Primary = Color3.fromRGB(5, 158, 27),
		Accent = Color3.fromRGB(0, 255, 92),
		Dark = Color3.fromRGB(2, 60, 10),
		Store = DataStoreService:GetOrderedDataStore("SpeedsterEscape_GlobalRobuxSpent_v1"),
		Monotonic = true,
		GetScore = function(player)
			return cleanOrderedInteger(player:GetAttribute("RobuxSpent"))
		end,
		Decode = function(score)
			return cleanOrderedInteger(score)
		end,
		Format = function(value)
			return "R$ " .. formatCompact(value)
		end,
	},
	{
		Id = "Speed",
		Title = "MOST SPEED",
		ColumnTitle = "SPEED",
		Primary = Color3.fromRGB(5, 92, 250),
		Accent = Color3.fromRGB(0, 210, 255),
		Dark = Color3.fromRGB(2, 29, 92),
		Store = DataStoreService:GetOrderedDataStore("SpeedsterEscape_GlobalSpeed_v1"),
		GetScore = function(player)
			local rawSpeed = getRawSpeed(player)
			return encodeSpeed(rawSpeed and rawSpeed.Value or 0)
		end,
		Decode = decodeSpeed,
		Format = formatCompact,
	},
	{
		Id = "Wins",
		Title = "MOST WINS",
		ColumnTitle = "WINS",
		Primary = Color3.fromRGB(255, 158, 4),
		Accent = Color3.fromRGB(255, 224, 38),
		Dark = Color3.fromRGB(117, 52, 1),
		Store = DataStoreService:GetOrderedDataStore("SpeedsterEscape_GlobalWins_v1"),
		GetScore = function(player)
			local wins = getLeaderstat(player, "Wins")
			return cleanOrderedInteger(wins and wins.Value or 0)
		end,
		Decode = function(score)
			return cleanOrderedInteger(score)
		end,
		Format = formatCompact,
	},
}

local function orderedKey(userId)
	return "U_" .. tostring(userId)
end

local function userIdFromOrderedKey(key)
	local matched = string.match(tostring(key or ""), "^U_(%d+)$")
	return matched and tonumber(matched) or nil
end

-- Studio without "Enable Studio Access to API Services" refuses every DataStore
-- call. The boards retried every minute and buried the output under the same
-- refusal, so once Studio has said no they stop asking for the rest of the session.
-- A live server never takes this path.
local IS_STUDIO = RunService:IsStudio()
local studioApiBlocked = false
local function noteStudioRefusal(err)
	if not IS_STUDIO or studioApiBlocked then
		return
	end
	local message = tostring(err)
	if string.find(message, "Studio access to APIs is not allowed", 1, true)
		or string.find(message, "API access is not enabled", 1, true)
		or string.find(message, "StudioAccessToApisNotAllowed", 1, true)
	then
		studioApiBlocked = true
		warn("[GlobalLeaderboards] Studio has no DataStore access, so leaderboards are off for this session. "
			.. "Enable it in Game Settings > Security > Enable Studio Access to API Services.")
	end
end

local function writeScore(category, userId, score)
	if studioApiBlocked then
		return false
	end
	score = cleanOrderedInteger(score)
	local success = false
	local lastError = nil

	for attempt = 1, DATASTORE_RETRIES do
		success, lastError = pcall(function()
			if category.Monotonic then
				category.Store:UpdateAsync(orderedKey(userId), function(current)
					return math.max(cleanOrderedInteger(current), score)
				end)
			else
				category.Store:SetAsync(orderedKey(userId), score)
			end
		end)
		if success then
			return true
		end
		noteStudioRefusal(lastError)
		if studioApiBlocked then
			return false
		end
		if attempt < DATASTORE_RETRIES then
			task.wait(attempt)
		end
	end

	warn(string.format(
		"[GlobalLeaderboardData] Could not publish %s for user %d: %s",
		category.Id,
		userId,
		tostring(lastError)
	))
	return false
end

local playerStates = {}

local function markPlayerDirty(player)
	local state = playerStates[player]
	if not state then
		return
	end
	state.Revision += 1
	state.Dirty = true
end

local function publishPlayer(player, force)
	local state = playerStates[player]
	if not state or player:GetAttribute("SessionDataOnly") == true then
		return false
	end
	if not force and not state.Dirty then
		return true
	end

	if state.Publishing then
		if not force then
			return false
		end
		local deadline = os.clock() + 8
		while state.Publishing and os.clock() < deadline do
			task.wait(0.05)
		end
		if state.Publishing then
			return false
		end
	end

	state.Publishing = true
	local revision = state.Revision
	local allSucceeded = true

	for _, category in ipairs(categories) do
		local score = category.GetScore(player)
		if force or state.LastPublished[category.Id] ~= score then
			if writeScore(category, player.UserId, score) then
				state.LastPublished[category.Id] = score
			else
				allSucceeded = false
			end
		end
	end

	state.Dirty = not allSucceeded or state.Revision ~= revision
	state.Publishing = false
	return allSucceeded
end

local function disconnectPlayerState(player)
	local state = playerStates[player]
	if not state then
		return
	end
	for _, connection in ipairs(state.Connections) do
		connection:Disconnect()
	end
	state.Connections = {}
	playerStates[player] = nil
end

local function setupPlayer(player)
	task.spawn(function()
		local deadline = os.clock() + 120
		while player.Parent == Players
			and player:GetAttribute("DataLoaded") ~= true
			and os.clock() < deadline
		do
			task.wait(0.1)
		end

		if player.Parent ~= Players
			or player:GetAttribute("DataLoaded") ~= true
			or player:GetAttribute("SessionDataOnly") == true
		then
			return
		end

		local rawSpeed = getRawSpeed(player)
		local wins = getLeaderstat(player, "Wins")
		if not rawSpeed or not wins then
			warn("[GlobalLeaderboardData] Missing loaded stats for " .. player.Name)
			return
		end

		local state = {
			Connections = {},
			Dirty = true,
			LastPublished = {},
			Publishing = false,
			Revision = 1,
		}
		playerStates[player] = state

		table.insert(state.Connections, rawSpeed.Changed:Connect(function()
			markPlayerDirty(player)
		end))
		table.insert(state.Connections, wins.Changed:Connect(function()
			markPlayerDirty(player)
		end))
		table.insert(state.Connections, player:GetAttributeChangedSignal("RobuxSpent"):Connect(function()
			markPlayerDirty(player)
		end))

		task.wait((player.UserId % 11) * 0.12)
		if playerStates[player] == state then
			publishPlayer(player, true)
		end
	end)
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
	return constraint
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
		if not findImportedPart(model, category.Id .. "_LeaderboardFrame")
			or not findImportedPart(model, category.Id .. "_LeaderboardScreen")
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

local boardStates = {}
local usernameCache = {}
local usernameLookupWindowStartedAt = os.clock()
local usernameLookupsUsed = 0

local function hydrateUsernames(entries)
	local missingUserIds = {}
	for _, entry in ipairs(entries) do
		local cached = usernameCache[entry.UserId]
		if cached then
			entry.Username = cached
		else
			table.insert(missingUserIds, entry.UserId)
		end
	end

	local now = os.clock()
	if now - usernameLookupWindowStartedAt >= 60 then
		usernameLookupWindowStartedAt = now
		usernameLookupsUsed = 0
	end
	local availableLookups = math.max(
		0,
		USERNAME_LOOKUP_LIMIT_PER_MINUTE - usernameLookupsUsed
	)
	local lookupUserIds = {}
	for index = 1, math.min(#missingUserIds, availableLookups) do
		table.insert(lookupUserIds, missingUserIds[index])
	end

	if #lookupUserIds > 0 then
		usernameLookupsUsed += #lookupUserIds
		local success, userInfos = pcall(function()
			return UserService:GetUserInfosByUserIdsAsync(lookupUserIds)
		end)
		if success and type(userInfos) == "table" then
			for _, userInfo in ipairs(userInfos) do
				local userId = tonumber(userInfo.Id)
				local username = userInfo.Username
				if userId and type(username) == "string" and username ~= "" then
					usernameCache[userId] = username
				end
			end
		end
	end

	for _, entry in ipairs(entries) do
		entry.Username = usernameCache[entry.UserId]
			or ("User " .. tostring(entry.UserId))
	end
end

local function makeR6DummyPart(model, root, name, size, offset)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = root.CFrame * CFrame.new(offset)
	part.Color = R6_DUMMY_BODY_COLOR
	part.Material = Enum.Material.Plastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Massless = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Parent = model

	local weld = Instance.new("WeldConstraint")
	weld.Name = name .. "RootWeld"
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = root
	return part
end

                                                                            
                                                                            
                                                                           
                               
local function createNeutralR6Dummy(categoryId, targetAvatarHeight)
	local model = Instance.new("Model")
	model.Name = "NumberOneR6_WaitingForData_" .. tostring(categoryId)
	model:SetAttribute("ChampionRigPolicy", "StandardR6NeutralFallback")
	model:SetAttribute("ChampionAppearanceScope", "NeutralFallback")
	model:SetAttribute("ChampionRequiresExternalApi", false)

	local scale = math.max(0.01, tonumber(targetAvatarHeight) or 5) / 5
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1) * scale
	root.CFrame = CFrame.identity
	root.Transparency = 1
	root.Material = Enum.Material.Plastic
	root.Massless = true
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.Parent = model
	model.PrimaryPart = root

	makeR6DummyPart(model, root, "Torso", Vector3.new(2, 2, 1) * scale, Vector3.new(0, 0, 0))
	local head = makeR6DummyPart(model, root, "Head", Vector3.new(2, 1, 1) * scale, Vector3.new(0, 1.5, 0) * scale)
	makeR6DummyPart(model, root, "Left Arm", Vector3.new(1, 2, 1) * scale, Vector3.new(-1.5, 0, 0) * scale)
	makeR6DummyPart(model, root, "Right Arm", Vector3.new(1, 2, 1) * scale, Vector3.new(1.5, 0, 0) * scale)
	makeR6DummyPart(model, root, "Left Leg", Vector3.new(1, 2, 1) * scale, Vector3.new(-0.5, -2, 0) * scale)
	makeR6DummyPart(model, root, "Right Leg", Vector3.new(1, 2, 1) * scale, Vector3.new(0.5, -2, 0) * scale)

	local face = Instance.new("Decal")
	face.Name = "face"
	face.Face = Enum.NormalId.Front
	face.Texture = "rbxasset://textures/face.png"
	face.Parent = head
	return model
end

local function createChampionFullAppearanceR6(userId)
	                                                                              
	                                                                     
	                                                                          
	                                                        
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
	local avatar = avatarOrError
	avatar:SetAttribute("ChampionRigPolicy", "StandardR6FullAppearance")
	avatar:SetAttribute("ChampionAppearanceScope", "CompletePublicHumanoidDescription")
	avatar:SetAttribute("ChampionPublicAppearanceUserId", userId)
	return avatar
end

local function sanitizeAvatar(model)
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
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.CastShadow = true
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
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
	end
end

local function partVerticalBounds(part)
	local half = part.Size * 0.5
	local cframe = part.CFrame
	local extentY = math.abs(cframe.RightVector.Y) * half.X
		+ math.abs(cframe.UpVector.Y) * half.Y
		+ math.abs(cframe.LookVector.Y) * half.Z
	return cframe.Position.Y - extentY, cframe.Position.Y + extentY
end

local function getRigBodyHeight(model)
	local minimumY = math.huge
	local maximumY = -math.huge
	local found = false
	for _, child in ipairs(model:GetChildren()) do
		if child:IsA("BasePart") and child.Name ~= "HumanoidRootPart" then
			local childMinimum, childMaximum = partVerticalBounds(child)
			minimumY = math.min(minimumY, childMinimum)
			maximumY = math.max(maximumY, childMaximum)
			found = true
		end
	end
	if found and maximumY > minimumY then
		return maximumY - minimumY
	end
	local _, fallbackSize = model:GetBoundingBox()
	return fallbackSize.Y
end

local function resetAvatarToStandingPose(model, humanoid)
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if animator then
		for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
			track:Stop(0)
		end
	end
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("Motor6D") then
			descendant.Transform = CFrame.identity
		end
	end
	if humanoid then
		humanoid.Sit = false
		humanoid.PlatformStand = false
		humanoid.AutoRotate = false
		humanoid.EvaluateStateMachine = false
	end
end

local function getFeetBottomY(model, humanoid)
	local footNames = humanoid and humanoid.RigType == Enum.HumanoidRigType.R15
		and { "LeftFoot", "RightFoot" }
		or { "Left Leg", "Right Leg" }
	local minimumY = math.huge
	local found = false
	for _, footName in ipairs(footNames) do
		local foot = model:FindFirstChild(footName)
		if foot and foot:IsA("BasePart") then
			local footBottom = partVerticalBounds(foot)
			minimumY = math.min(minimumY, footBottom)
			found = true
		end
	end
	if found then
		return minimumY
	end
	for _, child in ipairs(model:GetChildren()) do
		if child:IsA("BasePart") and child.Name ~= "HumanoidRootPart" then
			local childBottom = partVerticalBounds(child)
			minimumY = math.min(minimumY, childBottom)
			found = true
		end
	end
	return found and minimumY or nil
end

local function hasCompleteR15MotorRig(model)
	local motorCount = 0
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("Motor6D") then
			motorCount += 1
		end
	end
	return motorCount >= 14
end

local function alignAvatarFeetToStandTop(model, state)
	local facing = CFrame.lookAt(
		state.StatuePosition,
		state.StatuePosition + state.StatueFront,
		Vector3.yAxis
	)
	model:PivotTo(facing)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local feetBottomY = getFeetBottomY(model, humanoid)
	if not feetBottomY then
		return nil
	end

	local targetBottomY = state.StandTopSurfaceY
		+ CHAMPION_FEET_CLEARANCE
		+ CHAMPION_MANUAL_LIFT
	model:PivotTo(model:GetPivot() + Vector3.new(0, targetBottomY - feetBottomY, 0))
	model:SetAttribute("ChampionSupportPart", state.StandTop.Name)
	model:SetAttribute("ChampionSupportY", state.StandTopSurfaceY)
	model:SetAttribute("ChampionFeetTargetY", targetBottomY)
	return targetBottomY
end

local function positionAvatar(model, state)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid
		and humanoid.RigType == Enum.HumanoidRigType.R15
		and not hasCompleteR15MotorRig(model)
	then
		pcall(function()
			humanoid:BuildRigFromAttachments()
		end)
	end
	if humanoid and humanoid.RigType == Enum.HumanoidRigType.R15 then
		humanoid.AutomaticScalingEnabled = false
	end
	resetAvatarToStandingPose(model, humanoid)

	local initialBodyHeight = getRigBodyHeight(model)
	if initialBodyHeight <= 0.01 then
		return nil
	end
	local currentScale = 1
	local scaleSuccess, returnedScale = pcall(function()
		return model:GetScale()
	end)
	if scaleSuccess and isFiniteNumber(returnedScale) and returnedScale > 0 then
		currentScale = returnedScale
	end
	if not pcall(function()
		model:ScaleTo(currentScale * state.TargetAvatarHeight / initialBodyHeight)
	end) then
		return nil
	end
	resetAvatarToStandingPose(model, humanoid)

	                                                                      
	                                                                            
	                                                                             
	return alignAvatarFeetToStandTop(model, state)
end

                                                                           
                                                                                
                                                                               
local function freezeAvatarAssembly(model)
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end

	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	root.Anchored = true
	model.PrimaryPart = root

	local bodyPartCount = 0
	local anchoredPartCount = 0
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			bodyPartCount += 1
			if descendant ~= root then
				descendant.Anchored = false
			end
			if descendant.Anchored then
				anchoredPartCount += 1
			end
		end
	end

	model:SetAttribute("ChampionFreezeMode", "RootOnlyMotor6D")
	model:SetAttribute("ChampionBodyPartCount", bodyPartCount)
	model:SetAttribute("ChampionAnchoredPartCount", anchoredPartCount)
	return bodyPartCount > 1 and anchoredPartCount == 1
end

                                                                           
                                                                           
                
local function lockAvatarFeetToTarget(model, targetBottomY)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local feetBottomY = getFeetBottomY(model, humanoid)
	if not feetBottomY then
		return false
	end
	local correction = targetBottomY - feetBottomY
	if math.abs(correction) > 1e-7 then
		model:PivotTo(model:GetPivot() + Vector3.new(0, correction, 0))
	end

	local verifiedBottomY = getFeetBottomY(model, humanoid)
	if not verifiedBottomY then
		return false
	end
	local errorY = verifiedBottomY - targetBottomY
	model:SetAttribute("ChampionFeetLockError", errorY)
	return math.abs(errorY) <= FOOT_LOCK_EPSILON
end

                                                                              
                                                                      
local function validateStandingAvatar(model, state, targetBottomY)
	local measuredHeight = getRigBodyHeight(model)
	local minimumHeight = state.TargetAvatarHeight * 0.82
	local maximumHeight = state.TargetAvatarHeight * 1.18
	model:SetAttribute("ChampionMeasuredBodyHeight", measuredHeight)
	model:SetAttribute("ChampionTargetBodyHeight", state.TargetAvatarHeight)

	if not isFiniteNumber(measuredHeight)
		or measuredHeight < minimumHeight
		or measuredHeight > maximumHeight
	then
		model:SetAttribute("ChampionValidation", "RejectedBodyHeight")
		return false
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local feetBottomY = getFeetBottomY(model, humanoid)
	if not feetBottomY or math.abs(feetBottomY - targetBottomY) > FOOT_LOCK_EPSILON then
		model:SetAttribute("ChampionValidation", "RejectedFootLock")
		return false
	end

	model:SetAttribute("ChampionValidation", "PassedStandardR6Rig")
	return true
end

local function placeAndFreezeAvatar(model, state)
	sanitizeAvatar(model)
	model.Parent = state.AvatarContainer
	local targetBottomY = positionAvatar(model, state)
	if not targetBottomY
		or not freezeAvatarAssembly(model)
		or not lockAvatarFeetToTarget(model, targetBottomY)
		or not validateStandingAvatar(model, state, targetBottomY)
	then
		return false
	end
	return true
end

local function installNeutralR6Dummy(state)
	local dummy = createNeutralR6Dummy(state.Category.Id, state.TargetAvatarHeight)
	sanitizeAvatar(dummy)
	dummy.Parent = state.AvatarContainer
	local targetBottomY = alignAvatarFeetToStandTop(dummy, state)
	if not targetBottomY
		or not freezeAvatarAssembly(dummy)
		or not lockAvatarFeetToTarget(dummy, targetBottomY)
		or not validateStandingAvatar(dummy, state, targetBottomY)
	then
		warn(string.format(
			"[GlobalLeaderboards] Built-in %s R6 fallback failed placement validation=%s.",
			state.Category.Id,
			tostring(dummy:GetAttribute("ChampionValidation"))
		))
		dummy:Destroy()
		return false
	end
	local oldAvatar = state.CurrentAvatar
	state.CurrentAvatar = dummy
	state.CurrentUserId = nil
	if oldAvatar and oldAvatar ~= dummy then
		oldAvatar:Destroy()
	end
	return true
end

local function updateChampionLabel(state, leader)
	if not leader then
		state.ChampionText.Text = "#1\nWAITING FOR DATA"
		return
	end

	local category = state.Category
	state.ChampionText.Text = "#1 " .. leader.Username .. "\n" .. category.Format(leader.Value)
	                                                                        
	                                                                           
	                                                                          
end

local function bindImportedBoards(model)
	for _, runtimeName in ipairs({
		"ImportedLeaderboardRuntimeV306DH",
		"ImportedLeaderboardRuntimeV306DI",
		"ImportedLeaderboardRuntimeV306DJ",
		"ImportedLeaderboardRuntimeV306DK",
		"ImportedLeaderboardRuntimeV306DL",
		"ImportedLeaderboardRuntimeV306DM",
		"ImportedLeaderboardRuntimeV306KAK",
		"ImportedLeaderboardRuntimeV306KAL",
		"ImportedLeaderboardRuntimeV306KAM",
		"ImportedLeaderboardRuntimeV306KAN",
		"ImportedLeaderboardRuntimeV306KAW",
		"ImportedLeaderboardRuntimeV306KAX",
		"ImportedLeaderboardRuntimeV306KAY",
		"ImportedLeaderboardRuntimeV306KAZ",
		"ImportedLeaderboardRuntimeV306KBA",
	}) do
		local oldRuntime = model:FindFirstChild(runtimeName)
		if oldRuntime then
			oldRuntime:Destroy()
		end
	end
	local runtime = Instance.new("Folder")
	runtime.Name = "ImportedLeaderboardRuntimeV306KBA"
	runtime.Parent = model

	boardStates = {}
	for _, category in ipairs(categories) do
		local frame = findImportedPart(model, category.Id .. "_LeaderboardFrame")
		local screen = findImportedPart(model, category.Id .. "_LeaderboardScreen")
		local standTop = findImportedPart(model, category.Id .. "_ChampionStandTop")
		if not frame or not screen or not standTop then
			warn("[GlobalLeaderboards] Missing imported targets for " .. category.Id)
			return false
		end

		local oldWorkspaceSurface = screen:FindFirstChild("GlobalLeaderboardSurface")
		if oldWorkspaceSurface then
			oldWorkspaceSurface:Destroy()
		end
		local categoryRuntime = Instance.new("Folder")
		categoryRuntime.Name = category.Id .. "Runtime"
		categoryRuntime.Parent = runtime
		local avatarContainer = Instance.new("Folder")
		avatarContainer.Name = "CurrentAvatar"
		avatarContainer.Parent = categoryRuntime

		local targetAvatarHeight = math.clamp(frame.Size.Y * 1.12, 10, 18)
		local _, standTopSurfaceY = partVerticalBounds(standTop)
		local standPosition = Vector3.new(standTop.Position.X, standTopSurfaceY, standTop.Position.Z)
		standTop:SetAttribute("ResolvedChampionSupportY", standTopSurfaceY)
		standTop:SetAttribute("ChampionSupportSolver", "V306KAL_ExactNamedStandTop")
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "ChampionLabel"
		billboard.Adornee = standTop
		billboard.AlwaysOnTop = true
		billboard.MaxDistance = CHAMPION_LABEL_MAX_DISTANCE
		billboard.Size = UDim2.fromOffset(390, 110)
		billboard.StudsOffsetWorldSpace = Vector3.new(
			0,
			standTopSurfaceY - standTop.Position.Y
				+ CHAMPION_MANUAL_LIFT
				+ targetAvatarHeight
				+ 0.75,
			0
		)
		billboard.Parent = categoryRuntime
		local championText = makeText(billboard, "Text", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), "#1\nWAITING FOR DATA", Enum.Font.GothamBlack, category.Accent, 2)
		championText.TextWrapped = true
		constrainText(championText, 20, 58)

		local state = {
			Category = category,
			ClientRows = {},
			HasError = false,
			AvatarContainer = avatarContainer,
			ChampionText = championText,
			StatuePosition = standPosition,
			StatueFront = screen.CFrame.LookVector,
			StandTop = standTop,
			StandTopSurfaceY = standTopSurfaceY,
			TargetAvatarHeight = targetAvatarHeight,
			CurrentAvatar = nil,
			CurrentUserId = nil,
			RequestedUserId = nil,
			StatueGeneration = 0,
			LastStatueLoadAt = 0,
		}
		table.insert(boardStates, state)
	end

	print(string.format("[GlobalLeaderboards] Bound %d imported boards on %s without generating or moving geometry.", #boardStates, model:GetFullName()))
	return #boardStates == #categories
end

local function makeClientRows(state, entries)
	local rows = table.create(#entries)
	for index, entry in ipairs(entries) do
		rows[index] = {
			Rank = index,
			UserId = entry.UserId,
			Username = entry.Username,
			Value = state.Category.Format(entry.Value),
		}
	end
	return rows
end

local function sendBoardStateToPlayer(player, state)
	displayRemote:FireClient(
		player,
		state.Category.Id,
		state.ClientRows,
		state.HasError
	)
end

local function setBoardRows(state, entries, errorText)
	state.ClientRows = makeClientRows(state, entries)
	state.HasError = errorText ~= nil
	displayRemote:FireAllClients(
		state.Category.Id,
		state.ClientRows,
		state.HasError
	)
	updateChampionLabel(state, entries[1])
end

local function refreshBoard(state)
	local category = state.Category
	if studioApiBlocked then
		setBoardRows(state, {}, "Leaderboards need Studio API access")
		return
	end
	local success, pagesOrError = pcall(function()
		return category.Store:GetSortedAsync(false, DISPLAY_COUNT)
	end)
	if not success then
		setBoardRows(state, {}, tostring(pagesOrError))
		noteStudioRefusal(pagesOrError)
		if not studioApiBlocked then
			warn("[GlobalLeaderboards] " .. category.Id .. " read failed: " .. tostring(pagesOrError))
		end
		return
	end

	local entries = {}
	for _, record in ipairs(pagesOrError:GetCurrentPage()) do
		local userId = userIdFromOrderedKey(record.key)
		local score = cleanOrderedInteger(record.value)
		if userId and score > 0 then
			table.insert(entries, {
				UserId = userId,
				Score = score,
				Value = category.Decode(score),
			})
		end
	end
	hydrateUsernames(entries)
	setBoardRows(state, entries, nil)
end

local function refreshAllBoards()
	for _, state in ipairs(boardStates) do
		refreshBoard(state)
	end
end

local boardRequestTimes = {}
displayRemote.OnServerEvent:Connect(function(player, requestName)
	if requestName ~= "Request" then
		return
	end
	local now = os.clock()
	local previousRequestAt = boardRequestTimes[player]
	if previousRequestAt and now - previousRequestAt < 2 then
		return
	end
	boardRequestTimes[player] = now
	for _, state in ipairs(boardStates) do
		sendBoardStateToPlayer(player, state)
	end
end)

local function removeOldRuntimeGeometry()
	for _, folderName in ipairs(LEGACY_GENERATED_FOLDER_NAMES) do
		local stale = Workspace:FindFirstChild(folderName)
		if stale then
			stale:Destroy()
		end
	end
end

removeOldRuntimeGeometry()

Players.PlayerAdded:Connect(setupPlayer)
Players.PlayerRemoving:Connect(function(player)
	publishPlayer(player, true)
	disconnectPlayerState(player)
	boardRequestTimes[player] = nil
end)
for _, player in ipairs(Players:GetPlayers()) do
	setupPlayer(player)
end

task.spawn(function()
	while true do
		task.wait(PUBLISH_INTERVAL_SECONDS)
		for player in pairs(playerStates) do
			task.spawn(publishPlayer, player, false)
		end
	end
end)

task.spawn(function()
	while true do
		local importedModel = findImportedModel()
		if not importedModel then
			task.wait(2)
		else
			if bindImportedBoards(importedModel) then
				                                                               
				task.wait(8)
				while importedModel.Parent and #boardStates == #categories do
					refreshAllBoards()
					task.wait(BOARD_REFRESH_SECONDS)
				end
			end
			boardStates = {}
			task.wait(2)
		end
	end
end)

game:BindToClose(function()
	local pending = 0
	for player in pairs(playerStates) do
		pending += 1
		task.spawn(function()
			publishPlayer(player, true)
			pending -= 1
		end)
	end
	local deadline = os.clock() + 12
	while pending > 0 and os.clock() < deadline do
		task.wait(0.05)
	end
end)

print("[GlobalLeaderboards] V306KBA loaded. Sanitized top-100 rows now include UserId so the proven client exact-StandTop route owns every podium champion.")
