          
                                                                               
                                                                             
                                                                                
                                                                           
                                                                               
                                                                          
                                                     

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
-- 2026-09-26 (owner): V306KBB = accessories welded, root-only anchor, dancing (Shared/LeaderboardChampionRig).
local CHAMPION_VISUAL_VERSION = "V306KBB"
local CHAMPION_RETRY_SECONDS = 15
local CHAMPION_RETRY_MAX_SECONDS = 120
local CHAMPION_DANCE_CHECK_SECONDS = 0.5

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
	-- Update 4 (2026-09-25): best race times, lowest first (the server formats "36.52s").
	-- Optional: a place without the Race_* parts shows the other three as before.
	{
		Id = "Race",
		Title = "FASTEST RACERS",
		ColumnTitle = "TIME",
		Primary = Color3.fromRGB(0, 190, 235),
		Accent = Color3.fromRGB(190, 95, 255),
		Background = Color3.fromRGB(6, 22, 48),
		RowA = Color3.fromRGB(8, 40, 78),
		RowB = Color3.fromRGB(6, 32, 64),
		Optional = true,
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

local function categoryHasTargets(model, category)
	return findImportedPart(model, category.Id .. "_LeaderboardScreen") ~= nil
		and findImportedPart(model, category.Id .. "_LeaderboardFrame") ~= nil
		and findImportedPart(model, category.Id .. "_ChampionStandTop") ~= nil
end

-- An Optional board (Race) whose parts are missing, or not streamed in yet, does not hold up
-- the others; it is bound when its parts arrive.
local function hasImportedTargets(model)
	if not model or not model:IsA("Model") then
		return false
	end
	for _, category in ipairs(categories) do
		if not category.Optional and not categoryHasTargets(model, category) then
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

local importedModel = nil
local championFolder = nil
local championStates = {}

-- 2026-09-26 (owner): "make the characters' accessories show properly and make them dance".
-- This script is the ONE champion layer in all three worlds (World2/World3LeaderboardChampions
-- are retired stubs; the server only labels the stands). The rig, the placement and the dance
-- are Shared/LeaderboardChampionRig: the #1's avatar is prepared and stood on the stand out of
-- the world (accessories welded from their attachments, the rest pose laid out, scaled, feet on
-- the stand), then only its HumanoidRootPart is anchored, so it dances on its Animator while the
-- camera is near and the accessories follow the body. Loaded when the boards bind; without it the
-- boards still show, with no champions.
local ChampionRig = nil
local RIG_ENV = { Instance = Instance, Vector3 = Vector3, CFrame = CFrame, Color3 = Color3, Enum = Enum }

local function loadChampionRig()
	local shared = ReplicatedStorage:WaitForChild("Shared", 10)
	local module = shared and shared:WaitForChild("LeaderboardChampionRig", 10)
	if not module then
		warn("[GlobalLeaderboardChampion] Shared.LeaderboardChampionRig is missing; the boards show without champions.")
		return nil
	end
	local ok, result = pcall(require, module)
	if not ok or type(result) ~= "table" then
		warn("[GlobalLeaderboardChampion] Shared.LeaderboardChampionRig failed to load: " .. tostring(result))
		return nil
	end
	return result
end

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

local function getChampionState(category)
	local state = championStates[category.Id]
	if state then
		return state
	end
	state = {
		Category = category,
		-- Where it stands (LeaderboardChampionRig.StandTarget), read once while the stand is streamed in.
		Target = nil,
		Generation = 0,
		DesiredUserId = nil,
		RequestedUserId = nil,
		CurrentUserId = nil,
		CurrentVisual = nil,
		LastRows = nil,
		LastFailureUserId = nil,
		LastFailureAt = 0,
		FailureCount = 0,
		RetryAfter = CHAMPION_RETRY_SECONDS,
		DanceModel = nil,
		DanceTrack = nil,
		Dancing = false,
	}
	championStates[category.Id] = state
	return state
end

-- Puts a champion placed out of the world on its stand, in place of the one there; a frame later
-- (the engine has laid the joints out in the world) its feet are checked once more.
local function showChampion(state, model)
	local old = state.CurrentVisual
	model.Parent = championFolder
	state.CurrentVisual = model
	state.DanceModel = nil
	state.DanceTrack = nil
	state.Dancing = false
	if old and old ~= model then
		old:Destroy()
	end
	task.spawn(function()
		task.wait()
		if model.Parent == championFolder and state.CurrentVisual == model then
			if not ChampionRig.Settle(RIG_ENV, model, state.Target) then
				warn(string.format(
					"[GlobalLeaderboardChampion] %s champion's feet are %.3f studs off its stand after settling.",
					state.Category.Id,
					tonumber(model:GetAttribute("ChampionFeetLockError")) or 0
				))
			end
		end
	end)
end

-- The default champion (no #1 yet, or the avatar is still loading or failed): a jointed R6 in the
-- board's colour that dances like the real ones.
local function ensureNeutralChampion(category)
	if not ChampionRig or not championFolder or not championFolder.Parent then
		return nil
	end
	local state = getChampionState(category)
	if not state.Target then
		return nil
	end
	local current = state.CurrentVisual
	if current
		and current.Parent == championFolder
		and current:GetAttribute("ChampionVisualKind") == "NeutralR6Fallback"
	then
		return current
	end

	local neutral = ChampionRig.BuildNeutralR6(RIG_ENV, category.Id .. "_ChampionFallback_R6", category.Accent)
	neutral:SetAttribute("ClientOwnedLeaderboardChampion", true)
	neutral:SetAttribute("ChampionVisualKind", "NeutralR6Fallback")
	neutral:SetAttribute("ChampionPublicAppearanceUserId", 0)
	ChampionRig.Prepare(RIG_ENV, neutral)
	local placed, reason = ChampionRig.Place(RIG_ENV, neutral, state.Target)
	if not placed then
		neutral:Destroy()
		warn("[GlobalLeaderboardChampion] " .. category.Id .. " default champion could not stand: " .. tostring(reason))
		return nil
	end
	showChampion(state, neutral)
	state.CurrentUserId = nil
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

local requestChampionAppearance

-- A #1 that could not be shown: the default champion stays and the avatar is asked for again
-- after 15, 30, 60, 120 s (the boards only refresh every minute).
local function noteChampionFailure(category, state, userId, reason)
	state.RequestedUserId = nil
	state.LastFailureUserId = userId
	state.LastFailureAt = os.clock()
	state.FailureCount += 1
	state.RetryAfter = math.min(CHAMPION_RETRY_SECONDS * 2 ^ (state.FailureCount - 1), CHAMPION_RETRY_MAX_SECONDS)
	warn(string.format(
		"[GlobalLeaderboardChampion] %s could not show #1 user %d (%s); the default champion stands, retrying in %d s.",
		category.Id,
		userId,
		tostring(reason),
		state.RetryAfter
	))
	local generation = state.Generation
	task.delay(state.RetryAfter + 0.1, function()
		if state.Generation == generation and state.DesiredUserId == userId and state.CurrentUserId ~= userId then
			requestChampionAppearance(category, state.LastRows)
		end
	end)
end

function requestChampionAppearance(category, rows)
	if not ChampionRig or not championFolder or not championFolder.Parent or not importedModel then
		return
	end
	local state = getChampionState(category)
	if not state.Target then
		return
	end
	state.LastRows = rows
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
		state.LastFailureUserId = nil
		state.FailureCount = 0
		state.RetryAfter = CHAMPION_RETRY_SECONDS
		ensureNeutralChampion(category)
	end

	if state.RequestedUserId == userId then
		return
	end
	if state.LastFailureUserId == userId
		and os.clock() - state.LastFailureAt < state.RetryAfter
	then
		return
	end

	state.RequestedUserId = userId
	local generation = state.Generation
	task.spawn(function()
		local success, avatarOrError = pcall(createFullAppearanceR6, userId)
		local isModel = success and typeof(avatarOrError) == "Instance" and avatarOrError:IsA("Model")
		if generation ~= state.Generation
			or state.DesiredUserId ~= userId
			or not championFolder
			or not championFolder.Parent
		then
			if isModel then
				avatarOrError:Destroy()
			end
			return
		end
		if not isModel then
			noteChampionFailure(category, state, userId, avatarOrError)
			return
		end

		local avatar = avatarOrError
		avatar.Name = category.Id .. "_NumberOneR6FullAppearance_" .. tostring(userId)
		avatar:SetAttribute("ClientOwnedLeaderboardChampion", true)
		avatar:SetAttribute("ChampionVisualKind", "NumberOneFullPublicAppearanceR6")
		avatar:SetAttribute("ChampionPublicAppearanceUserId", userId)
		ChampionRig.Prepare(RIG_ENV, avatar)
		local placed, reason = ChampionRig.Place(RIG_ENV, avatar, state.Target)
		if not placed then
			avatar:Destroy()
			noteChampionFailure(category, state, userId, reason)
			return
		end
		if generation ~= state.Generation or state.DesiredUserId ~= userId or not championFolder.Parent then
			avatar:Destroy()
			return
		end
		showChampion(state, avatar)
		state.CurrentUserId = userId
		state.RequestedUserId = nil
		state.LastFailureUserId = nil
		state.FailureCount = 0
		state.RetryAfter = CHAMPION_RETRY_SECONDS
		print(string.format(
			"[GlobalLeaderboardChampion] %s displayed %s #1 user %d: full R6 avatar, %d accessories on, root anchored, dancing.",
			CHAMPION_VISUAL_VERSION,
			category.Id,
			userId,
			tonumber(avatar:GetAttribute("ChampionAccessoriesAttached")) or 0
		))
	end)
end

-- The dances: a champion within DanceNear of the camera dances (its board's own dance, looped),
-- one past DanceFar stops and stands. Twice a second over at most four champions.
local function updateChampionDances()
	local camera = Workspace.CurrentCamera
	if not ChampionRig or not camera then
		return
	end
	local eye = camera.CFrame.Position
	for _, state in pairs(championStates) do
		local model = state.CurrentVisual
		local root = model
			and model.Parent == championFolder
			and model:GetAttribute("ChampionSettled") == true
			and model.PrimaryPart
		if not root then
			continue
		end
		local distance = (root.CFrame.Position - eye).Magnitude
		if not state.Dancing and distance <= ChampionRig.DanceNear then
			if state.DanceModel ~= model then
				state.DanceModel = model
				local danceId = ChampionRig.DanceFor(state.Category.Id)
				state.DanceTrack = ChampionRig.LoadDance(RIG_ENV, model, danceId)
				model:SetAttribute("ChampionDanceId", danceId)
			end
			state.Dancing = ChampionRig.PlayDance(state.DanceTrack)
			model:SetAttribute("ChampionDancing", state.Dancing)
		elseif state.Dancing and distance > ChampionRig.DanceFar then
			ChampionRig.StopDance(state.DanceTrack)
			state.Dancing = false
			model:SetAttribute("ChampionDancing", false)
		end
	end
end

local function createChampionFolder(model)
	-- This script's folder from before, the old Studio preview and the retired World 2 / World 3
	-- champion scripts' folders: one layer of champions only.
	for _, oldName in ipairs({
		CHAMPION_FOLDER_NAME,
		"StudioLeaderboardR6Preview_LOCAL",
		"World2LeaderboardChampionVisuals_LOCAL",
		"World3LeaderboardChampionVisuals_LOCAL",
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
	ChampionRig = loadChampionRig()
	championFolder = createChampionFolder(model)

	local function bindCategory(category)
		-- 2026-09-26 (owner): the stand is read once here (streamed in now), so a new #1 still
		-- stands right when the stand's parts have streamed out meanwhile.
		if ChampionRig then
			local standTop, frame, screen = getCategoryTargets(model, category)
			getChampionState(category).Target = ChampionRig.StandTarget(RIG_ENV, standTop, frame, screen)
		end
		ensureNeutralChampion(category)
		local view = createBoardGui(model, category)
		if view then
			views[category.Id] = view
			local pending = pendingData[category.Id]
			if pending then
				renderRows(view, pending.Rows, pending.HasError)
			end
		end
	end

	local waitingOptional = {}
	for _, category in ipairs(categories) do
		if category.Optional and not categoryHasTargets(model, category) then
			table.insert(waitingOptional, category)
		else
			bindCategory(category)
			task.wait()
		end
	end

	displayRemote:FireServer("Request")

	-- 2026-09-26 (owner): the champions dance while the camera is near (LeaderboardChampionRig).
	if ChampionRig then
		task.spawn(function()
			while championFolder and championFolder.Parent do
				task.wait(CHAMPION_DANCE_CHECK_SECONDS)
				updateChampionDances()
			end
		end)
	end

	-- Optional boards whose parts stream in later (a small model: a cheap look every 3 s, and
	-- only until they are bound or the model is gone).
	while #waitingOptional > 0 and model.Parent do
		task.wait(3)
		for index = #waitingOptional, 1, -1 do
			local category = waitingOptional[index]
			if categoryHasTargets(model, category) then
				table.remove(waitingOptional, index)
				bindCategory(category)
				displayRemote:FireServer("Request")
			end
		end
	end
end)
