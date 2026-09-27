                                                                     
  
                                                                              
                                                                             
                                          

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

                                                                        
                                                                      
if Config.IsWorld2Place == true then
	print("[WinPadStagePlacement] V306HA World 1 correction disabled in World 2.")
	return
end
if Config.IsNewWorld1Map == true then
	print("[WinPadStagePlacement] V306KBD old-map correction disabled; WinPads uses authored stage1-stage10 directly.")
	return
end

local PAD_FOLDER_NAME = "WinPads_TO_PLACE"
local STAGE_DECOR_FOLDER_NAME = "StageDecor_Runtime"
local SIGN_ALIGNED_TARGET_STAGES = { 2, 3, 4 }
local STAGE4_TEMPLATE_TARGET_STAGES = { 9, 10 }
local TARGET_GAP_RIGHT_OF_SIGN_CENTER = 6.6
local FALLBACK_RIGHT_OFFSET_FROM_STAGE_CENTER = 25
local PAD_SIZE = Vector3.new(5.5, 0.5, 5.5)
local PAD_PAIR_GAP = 3.0
local PAD_PAIR_HALF_SPACING = (PAD_SIZE.Z + PAD_PAIR_GAP) * 0.5
local CHECK_INTERVAL = 0.5
local POSITION_TOLERANCE = 0.01
local ANGLE_TOLERANCE_DOT = 0.9999
local PLACEMENT_VERSION = "V306EPStage4ExactFor9And10"
local PAIR_RIGHT_SHIFTS_BY_STAGE = {
	                                                        
	[2] = -4.5,
}

                                                                              
                                                                           
                                                                           
local safeZoneCache = {}

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

local function findNamedMapObjectUncached(targetName)
	local normalizedTarget = normalizeName(targetName)
	local matches = {}

	for _, object in ipairs(Workspace:GetDescendants()) do
		if isSupportedMapObject(object) and normalizeName(object.Name) == normalizedTarget then
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

local function safeZoneIndexFromName(name)
	local normalized = normalizeName(name)
	local digits = normalized:match("^safezone(%d+)$")
	local index = tonumber(digits)
	if index and index >= 1 and index <= 10 then
		return index
	end
	return nil
end

local function getSafeZone(zoneIndex)
	local cached = safeZoneCache[zoneIndex]
	if cached and cached.Parent then
		return cached
	end

	local found = findNamedMapObjectUncached("SafeZone" .. tostring(zoneIndex))
	safeZoneCache[zoneIndex] = found
	return found
end

local function considerSafeZoneCandidate(object)
	if not object or not object.Parent or not isSupportedMapObject(object) then
		return
	end

	local zoneIndex = safeZoneIndexFromName(object.Name)
	if not zoneIndex then
		return
	end

	local current = safeZoneCache[zoneIndex]
	if not current or not current.Parent then
		safeZoneCache[zoneIndex] = object
		return
	end

	local currentDepth = objectDepth(current)
	local candidateDepth = objectDepth(object)
	if candidateDepth < currentDepth
		or (candidateDepth == currentDepth and object:GetFullName() < current:GetFullName())
	then
		safeZoneCache[zoneIndex] = object
	end
end

local function getObjectPivot(object)
	if not object then
		return nil
	end
	local ok, pivot = pcall(function()
		return object:GetPivot()
	end)
	return ok and pivot or nil
end

local function horizontalUnit(vector)
	local horizontal = Vector3.new(vector.X, 0, vector.Z)
	return horizontal.Magnitude >= 0.05 and horizontal.Unit or nil
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

local function getStageCourseDirection(safeZones, zoneIndex)
	local currentPivot = getObjectPivot(safeZones[zoneIndex])
	if not currentPivot then
		return Vector3.new(0, 0, -1)
	end

	local previousPivot = getObjectPivot(safeZones[zoneIndex - 1])
	local nextPivot = getObjectPivot(safeZones[zoneIndex + 1])
	local direction

	if zoneIndex >= 4 and previousPivot then
		direction = horizontalUnit(currentPivot.Position - previousPivot.Position)
	elseif nextPivot then
		direction = horizontalUnit(nextPivot.Position - currentPivot.Position)
	elseif previousPivot then
		direction = horizontalUnit(currentPivot.Position - previousPivot.Position)
	end

	if not direction then
		direction = Vector3.new(0, 0, -1)
	end
	return zoneIndex >= 4 and snapDirectionToCardinal(direction) or direction
end

local function getStageCenter(zoneIndex, fallbackPosition)
	local decorFolder = Workspace:FindFirstChild(STAGE_DECOR_FOLDER_NAME)
	local stageModel = decorFolder
		and decorFolder:FindFirstChild(string.format("Stage%02d_Decor", zoneIndex))
	local labelAnchor = stageModel
		and stageModel:FindFirstChild(string.format("Stage%02d_LabelAnchor", zoneIndex))
	if labelAnchor and labelAnchor:IsA("BasePart") then
		return Vector3.new(labelAnchor.Position.X, fallbackPosition.Y, labelAnchor.Position.Z)
	end
	local floor = stageModel
		and stageModel:FindFirstChild(string.format("Stage%02d_Floor", zoneIndex))
	if floor and floor:IsA("BasePart") then
		return Vector3.new(floor.Position.X, fallbackPosition.Y, floor.Position.Z)
	end
	return fallbackPosition
end

local function getRecommendedSignBoard(zoneIndex)
	local decorFolder = Workspace:FindFirstChild(STAGE_DECOR_FOLDER_NAME)
	local stageModel = decorFolder
		and decorFolder:FindFirstChild(string.format("Stage%02d_Decor", zoneIndex))
	local signModel = stageModel
		and stageModel:FindFirstChild(string.format("Stage%02d_RecommendedSign", zoneIndex))
	local board = signModel and signModel:FindFirstChild("Board")
	return board and board:IsA("BasePart") and board or nil
end

local function getTargetRightOffset(zoneIndex, stageCenter, rightDirection)
	local board = getRecommendedSignBoard(zoneIndex)
	if board then
		return (board.Position - stageCenter):Dot(rightDirection)
			+ TARGET_GAP_RIGHT_OF_SIGN_CENTER
	end
	return FALLBACK_RIGHT_OFFSET_FROM_STAGE_CENTER
end

local function getStagePads(padFolder, zoneIndex)
	local goldPad
	local purplePad
	for _, child in ipairs(padFolder:GetChildren()) do
		if child:IsA("BasePart")
			and tonumber(child:GetAttribute("SafeZoneIndex")) == zoneIndex
		then
			if child:GetAttribute("WinReward") ~= nil then
				goldPad = child
			elseif child:GetAttribute("FutureRobuxProduct") == true then
				purplePad = child
			end
		end
	end
	return goldPad, purplePad
end

local function needsCFrameCorrection(part, targetCFrame)
	return (part.Position - targetCFrame.Position).Magnitude > POSITION_TOLERANCE
		or part.CFrame.LookVector:Dot(targetCFrame.LookVector) < ANGLE_TOLERANCE_DOT
		or part.CFrame.RightVector:Dot(targetCFrame.RightVector) < ANGLE_TOLERANCE_DOT
end

local function setPadGeometry(padFolder, pad, targetCFrame, targetRightOffset, pairCenterForwardOffset, pairSide, pairRightShift)
	local changed = false
	if (pad.Size - PAD_SIZE).Magnitude > POSITION_TOLERANCE then
		pad.Size = PAD_SIZE
		changed = true
	end
	if needsCFrameCorrection(pad, targetCFrame) then
		pad.CFrame = targetCFrame
		changed = true
	end

	local base = padFolder:FindFirstChild(pad.Name .. "_BlackBase")
	if base and base:IsA("BasePart") then
		base.CFrame = pad.CFrame
			* CFrame.new(0, -((pad.Size.Y + base.Size.Y) * 0.5) + 0.02, 0)
	end

	pad:SetAttribute("StageSidePlacementVersion", PLACEMENT_VERSION)
	pad:SetAttribute("StageTargetRightOffsetStuds", targetRightOffset)
	pad:SetAttribute("PairCenterForwardOffsetStuds", pairCenterForwardOffset)
	pad:SetAttribute("PerfectlySymmetricalPair", true)
	pad:SetAttribute("PairSide", pairSide)
	pad:SetAttribute("ExactPairGapStuds", PAD_PAIR_GAP)
	pad:SetAttribute("ExactPairCenterSpacingStuds", PAD_PAIR_HALF_SPACING)
	pad:SetAttribute("StageSpecificPairRightShiftStuds", pairRightShift or 0)
	return changed
end

local function alignStagePadPair(padFolder, zoneIndex, stageCenter, courseDirection, rightDirection)
	local goldPad, purplePad = getStagePads(padFolder, zoneIndex)
	if not goldPad or not purplePad then
		return 0
	end

	local targetRightOffset = getTargetRightOffset(zoneIndex, stageCenter, rightDirection)
	local goldForward = (goldPad.Position - stageCenter):Dot(courseDirection)
	local purpleForward = (purplePad.Position - stageCenter):Dot(courseDirection)
	local pairCenterForward = (goldForward + purpleForward) * 0.5
	local pairHeight = (goldPad.Position.Y + purplePad.Position.Y) * 0.5
	local pairRightShift = PAIR_RIGHT_SHIFTS_BY_STAGE[zoneIndex] or 0
	local pairCenter = Vector3.new(stageCenter.X, pairHeight, stageCenter.Z)
		+ rightDirection * (targetRightOffset + pairRightShift)
		+ courseDirection * pairCenterForward
	local goldPosition = pairCenter - courseDirection * PAD_PAIR_HALF_SPACING
	local purplePosition = pairCenter + courseDirection * PAD_PAIR_HALF_SPACING
	local goldCFrame = CFrame.lookAt(goldPosition, goldPosition + courseDirection, Vector3.yAxis)
	local purpleCFrame = CFrame.lookAt(purplePosition, purplePosition + courseDirection, Vector3.yAxis)

	local changed = 0
	if setPadGeometry(padFolder, goldPad, goldCFrame, targetRightOffset, pairCenterForward, "Gold", pairRightShift) then
		changed += 1
	end
	if setPadGeometry(padFolder, purplePad, purpleCFrame, targetRightOffset, pairCenterForward, "Purple", pairRightShift) then
		changed += 1
	end
	return changed
end

local function getStageFloor(zoneIndex)
	local decorFolder = Workspace:FindFirstChild(STAGE_DECOR_FOLDER_NAME)
	local stageModel = decorFolder
		and decorFolder:FindFirstChild(string.format("Stage%02d_Decor", zoneIndex))
	local floor = stageModel
		and stageModel:FindFirstChild(string.format("Stage%02d_Floor", zoneIndex))
	return floor and floor:IsA("BasePart") and floor or nil
end

local function copyStage4PadPairExactly(padFolder, targetStageIndex)
	local sourceFloor = getStageFloor(4)
	local targetFloor = getStageFloor(targetStageIndex)
	local sourceGold, sourcePurple = getStagePads(padFolder, 4)
	local targetGold, targetPurple = getStagePads(padFolder, targetStageIndex)

	if not sourceFloor or not targetFloor
		or not sourceGold or not sourcePurple
		or not targetGold or not targetPurple
	then
		return 0
	end

	local function copyOne(sourcePad, targetPad, pairSide)
		local localCFrame = sourceFloor.CFrame:ToObjectSpace(sourcePad.CFrame)
		local targetCFrame = targetFloor.CFrame * localCFrame
		local changed = false

		if (targetPad.Size - sourcePad.Size).Magnitude > POSITION_TOLERANCE then
			targetPad.Size = sourcePad.Size
			changed = true
		end
		if needsCFrameCorrection(targetPad, targetCFrame) then
			targetPad.CFrame = targetCFrame
			changed = true
		end

		local base = padFolder:FindFirstChild(targetPad.Name .. "_BlackBase")
		if base and base:IsA("BasePart") then
			base.CFrame = targetPad.CFrame
				* CFrame.new(0, -((targetPad.Size.Y + base.Size.Y) * 0.5) + 0.02, 0)
		end

		targetPad:SetAttribute("StageSidePlacementVersion", PLACEMENT_VERSION)
		targetPad:SetAttribute("ExactLayoutTemplateStage", 4)
		targetPad:SetAttribute("ExactFloorRelativePlacement", true)
		targetPad:SetAttribute("PairSide", pairSide)
		return changed and 1 or 0
	end

	return copyOne(sourceGold, targetGold, "Gold")
		+ copyOne(sourcePurple, targetPurple, "Purple")
end

local function placePads()
	local padFolder = Workspace:FindFirstChild(PAD_FOLDER_NAME)
	if not padFolder or not padFolder:IsA("Folder") then
		return 0
	end

	local safeZones = {}
	for zoneIndex = 1, 10 do
		safeZones[zoneIndex] = getSafeZone(zoneIndex)
	end

	local changedCount = 0
	for _, zoneIndex in ipairs(SIGN_ALIGNED_TARGET_STAGES) do
		local zonePivot = getObjectPivot(safeZones[zoneIndex])
		if zonePivot then
			local courseDirection = getStageCourseDirection(safeZones, zoneIndex)
			local rightDirection = courseDirection:Cross(Vector3.yAxis)
			if rightDirection.Magnitude < 0.05 then
				rightDirection = Vector3.xAxis
			else
				rightDirection = rightDirection.Unit
			end

			changedCount += alignStagePadPair(
				padFolder,
				zoneIndex,
				getStageCenter(zoneIndex, zonePivot.Position),
				courseDirection,
				rightDirection
			)
		end
	end

	for _, zoneIndex in ipairs(STAGE4_TEMPLATE_TARGET_STAGES) do
		changedCount += copyStage4PadPairExactly(padFolder, zoneIndex)
	end

	padFolder:SetAttribute("Stage234PlacementVersion", PLACEMENT_VERSION)
	padFolder:SetAttribute("V306CVCorrectedStages", "2,3,4")
	padFolder:SetAttribute("V306EPStage4ExactCopiedStages", "9,10")
	return changedCount
end

                                                                       
Workspace.DescendantAdded:Connect(function(object)
	considerSafeZoneCandidate(object)
end)
Workspace.DescendantRemoving:Connect(function(object)
	local zoneIndex = safeZoneIndexFromName(object.Name)
	if zoneIndex and safeZoneCache[zoneIndex] == object then
		safeZoneCache[zoneIndex] = nil
	end
end)

                                                                           
                                                                              
for zoneIndex = 1, 10 do
	getSafeZone(zoneIndex)
end

task.spawn(function()
	while true do
		local changed = placePads()
		if changed > 0 then
			print("[WinPadStagePlacement] V306EP corrected/aligned " .. tostring(changed) .. " Stage 2-4 pads")
		end
		task.wait(CHECK_INTERVAL)
	end
end)
