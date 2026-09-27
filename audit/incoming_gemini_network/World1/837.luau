                                          
  
                                                
                           
                                                                 
  
                                                                            
                                                                            
                                       

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
if Config.IsNewWorld1Map ~= true then
	return
end

local MAP_ROOT_NAME = tostring(Config.NewWorld1MapMarkerName or "neworld1")
local mapRoot = Workspace:FindFirstChild(MAP_ROOT_NAME) or Workspace:WaitForChild(MAP_ROOT_NAME, 20)
if not mapRoot then
	warn("[NewWorld1StagePresentation] Workspace." .. MAP_ROOT_NAME .. " is missing")
	return
end

local STAGE_COUNT = 11
local GENERATED_FOLDER_NAME = "V306KBY_NewWorld1StagePresentation"
local LABEL_HEIGHT = 27.5
local LABEL_SIZE = Vector3.new(72, 20, 0.2)

local previous = mapRoot:FindFirstChild(GENERATED_FOLDER_NAME)
if previous then
	previous:Destroy()
end

                                                                          
                                                                             
local previousKBX = mapRoot:FindFirstChild("V306KBX_NewWorld1StagePresentation")
if previousKBX then
	previousKBX:Destroy()
end

                                                                 
for _, oldFolderName in ipairs({
	"V306KBU_NewWorld1StageText",
	"V306KBF_NewWorld1StageText",
	"V306KBE_NewWorld1StageText",
}) do
	local oldFolder = mapRoot:FindFirstChild(oldFolderName)
	if oldFolder then
		oldFolder:Destroy()
	end
end

local generatedFolder = Instance.new("Folder")
generatedFolder.Name = GENERATED_FOLDER_NAME
generatedFolder:SetAttribute("StagePresentationVersion", "V306KBY")
generatedFolder.Parent = mapRoot

local presentationByStage = {}

local function normalizeName(value)
	return tostring(value or ""):lower():gsub("[^%w]", "")
end

local function stageIndexFromObject(object)
	local index = tonumber(normalizeName(object and object.Name):match("^stage(%d+)$"))
	if index and index >= 1 and index <= STAGE_COUNT then
		return math.floor(index)
	end
	return nil
end

local function isStageObject(object)
	return object and (object:IsA("BasePart") or object:IsA("Model"))
end

local function getStageBounds(object)
	if object:IsA("BasePart") then
		return object.CFrame, object.Size
	end
	local ok, boundsCFrame, boundsSize = pcall(object.GetBoundingBox, object)
	if ok then
		return boundsCFrame, boundsSize
	end
	return nil, nil
end

local function findStage(index)
	local exactName = "stage" .. tostring(index)
	local direct = mapRoot:FindFirstChild(exactName, true)
	if isStageObject(direct) then
		return direct
	end
	for _, object in ipairs(mapRoot:GetDescendants()) do
		if isStageObject(object) and normalizeName(object.Name) == exactName then
			return object
		end
	end
	return nil
end

local function recommendedLevel(index)
	return 5 + ((index - 1) * 15)
end

local function destroyPresentation(index)
	local holder = presentationByStage[index]
	if holder then
		presentationByStage[index] = nil
		if holder.Parent then
			holder:Destroy()
		end
	end
end

local function addTextConstraint(label, maxSize)
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MinTextSize = 1
	constraint.MaxTextSize = maxSize
	constraint.Parent = label
end

local function addOutline(label, thickness)
	local outline = Instance.new("UIStroke")
	outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	outline.Color = Color3.fromRGB(0, 0, 0)
	outline.Thickness = thickness
	outline.Transparency = 0
	outline.Parent = label
end

local function createStagePresentation(index, stageObject)
	destroyPresentation(index)

	local stageCFrame, stageSize = getStageBounds(stageObject)
	if not stageCFrame or not stageSize then
		warn("[NewWorld1StagePresentation] Could not read stage" .. tostring(index) .. " bounds")
		return false
	end

	stageObject:SetAttribute("SafeZoneIndex", index)
	stageObject:SetAttribute("NewWorld1TeleportStage", index)

	local holder = Instance.new("Folder")
	holder.Name = string.format("Stage%02d_Presentation", index)
	holder:SetAttribute("StageIndex", index)
	holder.Parent = generatedFolder


	local board = Instance.new("Part")
	board.Name = string.format("Stage%02d_LabelBoard", index)
	board.Anchored = true
	board.CanCollide = false
	board.CanTouch = false
	board.CanQuery = false
	board.CastShadow = false
	board.Transparency = 1
	board.Size = LABEL_SIZE
	board.CFrame = stageCFrame
		* CFrame.new(0, stageSize.Y * 0.5 + LABEL_HEIGHT, 0)
		* CFrame.Angles(0, math.pi, 0)
	board:SetAttribute("NewWorld1GeneratedStageText", true)
	board:SetAttribute("StageIndex", index)
	board.Parent = holder

	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local surfaceGui = Instance.new("SurfaceGui")
		surfaceGui.Name = face == Enum.NormalId.Front and "FrontApproachStageText" or "BackApproachStageText"
		surfaceGui.Adornee = board
		surfaceGui.Face = face
		surfaceGui.AlwaysOnTop = false
		surfaceGui.LightInfluence = 0
		surfaceGui.MaxDistance = 0
		surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		surfaceGui.PixelsPerStud = 8
		surfaceGui.Parent = board

		local stageLabel = Instance.new("TextLabel")
		stageLabel.Name = "StageNumberText"
		stageLabel.BackgroundTransparency = 1
		stageLabel.Position = UDim2.fromScale(0, 0)
		stageLabel.Size = UDim2.fromScale(1, 0.64)
		stageLabel.Font = Enum.Font.GothamBlack
		stageLabel.Text = "Stage " .. tostring(index)
		stageLabel.TextScaled = true
		stageLabel.TextColor3 = Color3.fromRGB(180, 255, 18)
		stageLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		stageLabel.TextStrokeTransparency = 0
		stageLabel.TextXAlignment = Enum.TextXAlignment.Center
		stageLabel.TextYAlignment = Enum.TextYAlignment.Bottom
		stageLabel.Parent = surfaceGui
		addTextConstraint(stageLabel, 160)
		addOutline(stageLabel, 8)

		local recommendedLabel = Instance.new("TextLabel")
		recommendedLabel.Name = "RecommendedLevelText"
		recommendedLabel.BackgroundTransparency = 1
		recommendedLabel.Position = UDim2.fromScale(0.08, 0.64)
		recommendedLabel.Size = UDim2.fromScale(0.84, 0.30)
		recommendedLabel.Font = Enum.Font.GothamBlack
		recommendedLabel.Text = "Recommended Level: " .. tostring(recommendedLevel(index))
		recommendedLabel.TextScaled = true
		recommendedLabel.TextColor3 = Color3.fromRGB(255, 188, 24)
		recommendedLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		recommendedLabel.TextStrokeTransparency = 0
		recommendedLabel.TextXAlignment = Enum.TextXAlignment.Center
		recommendedLabel.TextYAlignment = Enum.TextYAlignment.Top
		recommendedLabel.Parent = surfaceGui
		addTextConstraint(recommendedLabel, 90)
		addOutline(recommendedLabel, 6)
	end

	presentationByStage[index] = holder
	return true
end

local function rebuildStage(index)
	local stageObject = findStage(index)
	if stageObject then
		createStagePresentation(index, stageObject)
	else
		destroyPresentation(index)
		warn("[NewWorld1StagePresentation] Missing stage" .. tostring(index) .. " below Workspace." .. MAP_ROOT_NAME)
	end
end

local configured = 0
for index = 1, STAGE_COUNT do
	local stageObject = findStage(index)
	if stageObject and createStagePresentation(index, stageObject) then
		configured += 1
	else
		warn("[NewWorld1StagePresentation] Missing stage" .. tostring(index) .. " below Workspace." .. MAP_ROOT_NAME)
	end
end

local rebuildQueued = {}
local function queueStageRebuild(index)
	if not index or rebuildQueued[index] then
		return
	end
	rebuildQueued[index] = true
	task.delay(0.2, function()
		rebuildQueued[index] = nil
		rebuildStage(index)
	end)
end

mapRoot.DescendantAdded:Connect(function(object)
	queueStageRebuild(stageIndexFromObject(object))
end)

mapRoot.DescendantRemoving:Connect(function(object)
	queueStageRebuild(stageIndexFromObject(object))
end)

print(
	"[NewWorld1StagePresentation] V306KBY created text-only Stage + Recommended Level presentation for "
		.. tostring(configured)
		.. "/11 authored stages"
)
