                                                                     
  
                                                                           
                                                                             
  
                                                              
                                                             
                                                
                                                                                   
                                                 
                                                     
                                                                 
  
                                                                               
                                                                                
                                                                             

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
if Config.IsWorld2Place ~= true then
	return
end

local ServerScriptService = game:GetService("ServerScriptService")
local World2StageTeleportService = require(script.Parent:WaitForChild("World2StageTeleportService"))
local RewardPadClaims = require(ServerScriptService:WaitForChild("Services"):WaitForChild("RewardPadClaims"))
local WinsMath = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WinsMath"))
local DoubleWinsPad = require(ServerScriptService:WaitForChild("Services"):WaitForChild("DoubleWinsPad"))

local FIRST_STAGE = 2
local PadTouchService = require(ServerScriptService:WaitForChild("Services"):WaitForChild("PadTouchService"))

local STAGE_COUNT = math.max(FIRST_STAGE, math.floor(tonumber(Config.StageCount) or 10))
local SKIP_STAGE_PRODUCT_ID = math.max(0, math.floor(tonumber(Config.SkipStageProductId) or 0))
local DOUBLE_WINS_PAD_GAMEPASS_ID = DoubleWinsPad.GamePassId
local DOUBLE_WINS_MULTIPLIER = WinsMath.PadDoubleMultiplier
local FINAL_WIN_REWARD = math.max(0, math.floor(tonumber(Config.World2FinalWinReward) or 1000000))

local PAD_TOUCH_SOUND_ID = "rbxassetid://136993031050456"
local PAD_CLAIM_COOLDOWN = 1.5
local SKIP_PROMPT_COOLDOWN = 1.5
local RUNTIME_FOLDER_NAME = "World2ManualStagePads_Runtime"
local VERSION = "V306IRWorld2ManualPads"

local STAGE_REWARDS = {}
for stage = FIRST_STAGE, STAGE_COUNT do
	local configured = Config.World2StageWinRewards and Config.World2StageWinRewards[stage]
	STAGE_REWARDS[stage] = math.max(0, math.floor(tonumber(configured) or 0))
end

                                      
local PAD_SIZE = Vector3.new(7.0, 0.5, 7.0)
local PAD_BASE_HEIGHT = 0.28
local PAD_BASE_COLOR = Color3.fromRGB(18, 18, 18)
local PAD_BASE_PADDING_NORMAL = 0.75
local PAD_BASE_PADDING_FINAL = 1.25
local PAD_LIGHT_BRIGHTNESS = 0.8
local PAD_LIGHT_RANGE = 3
local PAD_LABEL_SIZE = UDim2.fromOffset(118, 27)
local PAD_LABEL_OFFSET = Vector3.new(0, 1.75, 0)
local PAD_LABEL_MAX_DISTANCE = 117
local PAD_LABEL_TEXT_SIZE = 19
local PAD_TEXT_STROKE_TRANSPARENCY = 0.35

local COLORS = {
	win = Color3.fromRGB(255, 190, 0),
	x2 = Color3.fromRGB(175, 45, 255),
	skip = Color3.fromRGB(0, 255, 85),
}
local LIGHT_COLORS = {
	win = Color3.fromRGB(255, 135, 25),
	x2 = Color3.fromRGB(220, 100, 255),
	skip = Color3.fromRGB(80, 255, 135),
}
local TEXT_COLORS = {
	win = Color3.fromRGB(255, 200, 0),
	x2 = Color3.fromRGB(255, 70, 255),
	skip = Color3.fromRGB(45, 255, 95),
}

                                             
local STAGE_TEXT_BOARD_SIZE = Vector3.new(46.0, 12.6, 0.2)
local STAGE_TEXT_HEIGHT = 26.5
                                                                         
                                                                  
local STAGE_TEXT_EXTRA_HEIGHT_BY_STAGE = {
	[5] = 3,
	[6] = 7,
}
local STAGE_TEXT_RIGHT_SHIFT_BY_STAGE = {
	[7] = 7,
}
                                                                        
                                                                           
                                    
local STAGE_TEXT_YAW_DEGREES_BY_STAGE = {
	[8] = 270,
	[9] = 270,
	[10] = 270,
}
local STAGE_TEXT_PIXELS_PER_STUD = 8
local STAGE_TEXT_MAX_SIZE = 100
local STAGE_TEXT_OUTLINE_THICKNESS = 8

local manualParts = {
	win = {},
	x2 = {},
	skip = {},
	stage = {},
}
local finalParts = { win = nil, x2 = nil }
local runtimePads = setmetatable({}, { __mode = "k" })
local runtimeBases = setmetatable({}, { __mode = "k" })
local stageLabelBoards = {}
local stageLabelAnchors = {}
local stageSafeZones = {}
local connectedPads = setmetatable({}, { __mode = "k" })
local configuredMarkers = setmetatable({}, { __mode = "k" })
local lastClaimAt = {}
local lastSkipPromptAt = {}

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end
local winPadFeedbackRemote = remotes:FindFirstChild("WinPadFeedback")
if winPadFeedbackRemote and not winPadFeedbackRemote:IsA("RemoteEvent") then
	winPadFeedbackRemote:Destroy()
	winPadFeedbackRemote = nil
end
if not winPadFeedbackRemote then
	winPadFeedbackRemote = Instance.new("RemoteEvent")
	winPadFeedbackRemote.Name = "WinPadFeedback"
	winPadFeedbackRemote.Parent = remotes
end

local function normalizeName(value)
	return tostring(value or ""):lower():gsub("[^%w]", "")
end

local function formatNumber(value)
	local text = tostring(math.floor(tonumber(value) or 0))
	while true do
		local changed
		text, changed = text:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		if changed == 0 then
			return text
		end
	end
end

local function horizontalUnit(vector)
	local flat = Vector3.new(vector.X, 0, vector.Z)
	if flat.Magnitude < 0.001 then
		return nil
	end
	return flat.Unit
end

local function getMarkerYawBasis(marker)
	local right = horizontalUnit(marker.CFrame.RightVector)
	local look = horizontalUnit(marker.CFrame.LookVector)
	if right and look then
		return right, look
	end
	if right then
		local derivedLook = horizontalUnit(Vector3.new(-right.Z, 0, right.X))
		return right, derivedLook or Vector3.zAxis
	end
	if look then
		local derivedRight = horizontalUnit(Vector3.new(look.Z, 0, -look.X))
		return derivedRight or Vector3.xAxis, look
	end
	return Vector3.xAxis, -Vector3.zAxis
end

local function getTopY(part)
	local size = part.Size * 0.5
	local cframe = part.CFrame
	local verticalExtent = math.abs(cframe.RightVector.Y) * size.X
		+ math.abs(cframe.UpVector.Y) * size.Y
		+ math.abs(cframe.LookVector.Y) * size.Z
	return part.Position.Y + verticalExtent
end

local function parseMarkerName(name)
	local n = normalizeName(name)
	if n == "winstagewin" then return "finalwin", STAGE_COUNT end
	if n == "winstagex2" then return "finalx2", STAGE_COUNT end
	local stage = tonumber(n:match("^win(%d+)$"))
	if stage then return "win", stage end
	stage = tonumber(n:match("^x2(%d+)$"))
	if stage then return "x2", stage end
	stage = tonumber(n:match("^skip(%d+)$"))
	if stage then return "skip", stage end
	stage = tonumber(n:match("^stage(%d+)$"))
	if stage then return "stage", stage end
	return nil, nil
end

local function markerIsValid(kind, stage)
	if kind == "finalwin" or kind == "finalx2" then
		return true
	end
	if not stage or stage < FIRST_STAGE or stage > STAGE_COUNT then
		return false
	end
	if kind == "win" or kind == "x2" then
		return STAGE_REWARDS[stage] ~= nil
	end
	if kind == "skip" or kind == "stage" then
		return true
	end
	return false
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
	folder:SetAttribute("WorldNumber", 2)
	folder:SetAttribute("ManualMarkersAuthoritative", true)
	folder:SetAttribute("Version", VERSION)
	return folder
end

local runtimeFolder = getRuntimeFolder()
for _, child in ipairs(runtimeFolder:GetChildren()) do
	child:Destroy()
end

local function clearOldGeneratedWorld2Furniture()
	local oldDecor = Workspace:FindFirstChild("StageDecor_Runtime")
	if oldDecor and oldDecor:GetAttribute("WorldNumber") == 2 then
		oldDecor:Destroy()
	end
	local oldPads = Workspace:FindFirstChild("WinPads_TO_PLACE")
	if oldPads and oldPads:IsA("Folder") and oldPads:GetAttribute("WorldNumber") == 2 then
		oldPads:Destroy()
	end
end
clearOldGeneratedWorld2Furniture()

local function playerFromHit(hit)
	if not hit or not hit:IsA("BasePart") then
		return nil, nil, nil
	end
	local current = hit.Parent
	while current and current ~= Workspace do
		if current:IsA("Model") then
			local humanoid = current:FindFirstChildOfClass("Humanoid")
			if humanoid then
				return Players:GetPlayerFromCharacter(current), current, humanoid
			end
		end
		current = current.Parent
	end
	return nil, nil, nil
end

local function inArrivalGrace(player)
	return os.clock() < (tonumber(player:GetAttribute("StageTeleportArrivalGraceUntil")) or 0)
end

local function awardWins(player, reward)
	local addWins = _G.SpeedsterAddWins
	if type(addWins) == "function" then
		return addWins(player, reward) == true
	end
	local leaderstats = player:FindFirstChild("leaderstats")
	local wins = leaderstats and leaderstats:FindFirstChild("Wins")
	if wins and wins:IsA("IntValue") then
		wins.Value += reward
		return true
	end
	return false
end

local function queueSave(player, reason)
	if type(_G.SpeedsterSavePlayer) == "function" then
		task.defer(_G.SpeedsterSavePlayer, player, reason)
	end
end

local function playWinFeedback(player)
	winPadFeedbackRemote:FireClient(player, PAD_TOUCH_SOUND_ID)
end

local function touchReady(player, part)
	if player:GetAttribute("DataLoaded") ~= true or inArrivalGrace(player) then
		return false
	end
	local now = os.clock()
	local perPlayer = lastClaimAt[player]
	if not perPlayer then
		perPlayer = setmetatable({}, { __mode = "k" })
		lastClaimAt[player] = perPlayer
	end
	if now - (perPlayer[part] or -math.huge) < PAD_CLAIM_COOLDOWN then
		return false
	end
	perPlayer[part] = now
	return true
end

local function teleportToStart(player)
	local ok, reason = World2StageTeleportService.TeleportToStart(player)
	if not ok then
		warn("[World2ManualStagePads] Could not return " .. player.Name .. " to World 2 start: " .. tostring(reason))
	end
	return ok
end

local function hideMarker(marker)
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanTouch = false
	marker.CanQuery = false
	marker.CastShadow = false
	marker.Transparency = 1
	marker:SetAttribute("World2ManualMarker", true)
	marker:SetAttribute("ManualCFrameAuthoritative", true)
	marker:SetAttribute("ManualSizeAuthoritative", true)
end

local function createRuntimePad(marker, kind, stage, isFinal)
	local oldPad = runtimePads[marker]
	if oldPad and oldPad.Parent then
		oldPad:Destroy()
	end
	local oldBase = runtimeBases[marker]
	if oldBase and oldBase.Parent then
		oldBase:Destroy()
	end

	local right, look = getMarkerYawBasis(marker)
	local topY = getTopY(marker)
	local cframe = CFrame.fromMatrix(
		Vector3.new(marker.Position.X, topY + PAD_SIZE.Y * 0.5, marker.Position.Z),
		right,
		Vector3.yAxis,
		-look
	)

	local pad = Instance.new("Part")
	pad.Name = marker.Name .. "_RuntimePad"
	pad.Anchored = true
	pad.CanCollide = false
	pad.CanTouch = true
	pad.CanQuery = true
	pad.CastShadow = false
	pad.Material = Enum.Material.Neon
	pad.Color = COLORS[kind]
	pad.TopSurface = Enum.SurfaceType.Smooth
	pad.BottomSurface = Enum.SurfaceType.Smooth
	pad.Size = PAD_SIZE
	pad.CFrame = cframe
	pad:SetAttribute("WorldNumber", 2)
	pad:SetAttribute("World2ManualPad", true)
	pad:SetAttribute("World2ManualPadType", kind)
	pad:SetAttribute("World2ManualStage", stage)
	pad:SetAttribute("World2FinalWinStagePad", isFinal == true)
	pad:SetAttribute("SourceMarkerName", marker.Name)
	pad.Parent = runtimeFolder
	runtimePads[marker] = pad

	local base = Instance.new("Part")
	base.Name = marker.Name .. "_RuntimeBase"
	base.Anchored = true
	base.CanCollide = false
	base.CanTouch = false
	base.CanQuery = false
	base.CastShadow = false
	base.Material = Enum.Material.SmoothPlastic
	base.Color = PAD_BASE_COLOR
	base.TopSurface = Enum.SurfaceType.Studs
	base.BottomSurface = Enum.SurfaceType.Smooth
	local padding = isFinal and PAD_BASE_PADDING_FINAL or PAD_BASE_PADDING_NORMAL
	base.Size = Vector3.new(pad.Size.X + padding, PAD_BASE_HEIGHT, pad.Size.Z + padding)
	base.CFrame = pad.CFrame * CFrame.new(0, -((pad.Size.Y + PAD_BASE_HEIGHT) * 0.5) + 0.02, 0)
	base:SetAttribute("World2ManualPadBase", true)
	base:SetAttribute("SourceMarkerName", marker.Name)
	base.Parent = runtimeFolder
	runtimeBases[marker] = base

	return pad
end

local function createPadLabel(pad, kind, text)
	local isMultiLine = string.find(text, "\n") ~= nil
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "WinRewardBillboard"
	billboard.Adornee = pad
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.Size = isMultiLine and UDim2.fromOffset(150, 46) or PAD_LABEL_SIZE
	billboard.StudsOffsetWorldSpace = isMultiLine and Vector3.new(0, 2.1, 0) or PAD_LABEL_OFFSET
	billboard.MaxDistance = kind == "skip" and 75 or PAD_LABEL_MAX_DISTANCE
	billboard.Parent = pad

	local label = Instance.new("TextLabel")
	label.Name = "RewardText"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.Text = text
	label.TextColor3 = TEXT_COLORS[kind]
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = PAD_TEXT_STROKE_TRANSPARENCY
	label.TextScaled = false
	label.TextSize = isMultiLine and 16 or PAD_LABEL_TEXT_SIZE
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = billboard
end

local function addPadLight(pad, kind)
	local light = Instance.new("PointLight")
	light.Name = "PadLight"
	light.Color = LIGHT_COLORS[kind]
	light.Brightness = PAD_LIGHT_BRIGHTNESS
	light.Range = PAD_LIGHT_RANGE
	light.Shadows = false
	light.Parent = pad
end

local function connectRewardPad(pad, baseReward, isDouble, stage, isFinal)
	if connectedPads[pad] then
		return
	end
	connectedPads[pad] = true
	pad:SetAttribute("BaseReward", baseReward)
	pad:SetAttribute("IsDoublePad", isDouble == true)
	pad:SetAttribute("StageNumber", stage)
	PadTouchService.Connect(pad, function(hit)
		local player, _, humanoid = playerFromHit(hit)
		if not player or not humanoid or humanoid.Health <= 0 then return false end
		if player:GetAttribute("DataLoaded") ~= true or inArrivalGrace(player) then return false end
		-- Services.DoubleWinsPad owns the entitlement: x2 pads need the permanent x2 pads
		-- gamepass. The Wins ladder is a separate purchase and does not unlock them.
		if isDouble and not DoubleWinsPad.IsEntitled(player) then
			DoubleWinsPad.RequestPurchase(player, pad, "[World2ManualStagePads]")
			return true
		end
		if not touchReady(player, pad) then return false end
		-- Pad doubling first, then RewardPadClaims applies the account multipliers.
		local reward = WinsMath.GetPadBaseReward(baseReward, isDouble, true)

		local claimed = RewardPadClaims.Claim(
			player,
			pad,
			reward,
			stage,
			isFinal == true,
			function(p)
				return teleportToStart(p)
			end,
			function(grantedAmount)
				DoubleWinsPad.Clear(player)
				player:SetAttribute("LastClaimedWinPad", pad.Name)
				player:SetAttribute("LastWinPadReward", grantedAmount)
				player:SetAttribute("LastCompletedSafeZone", stage)
				if isFinal then
					player:SetAttribute("World2FinalWinStageClaimed", true)
				end
				playWinFeedback(player)
				queueSave(player, isFinal and (isDouble and "world2_final_x2_win" or "world2_final_win") or ((isDouble and "world2_x2_stage_" or "world2_win_stage_") .. tostring(stage)))
			end
		)
		return claimed
	end)
end

local function connectSkipPad(pad, stage)
	if stage >= STAGE_COUNT then
		return
	end
	if connectedPads[pad] then
		return
	end
	connectedPads[pad] = true
	PadTouchService.Connect(pad, function(hit)
		local player, _, humanoid = playerFromHit(hit)
		if not player or not humanoid or humanoid.Health <= 0 then return false end
		if player:GetAttribute("DataLoaded") ~= true or inArrivalGrace(player) then return false end
		local now = os.clock()
		if now - (lastSkipPromptAt[player] or -math.huge) < SKIP_PROMPT_COOLDOWN then return false end
		lastSkipPromptAt[player] = now
		player:SetAttribute("CurrentSafeZoneStage", stage)
		local last = math.floor(tonumber(player:GetAttribute("LastReachedStage")) or 1)
		if stage > last then
			player:SetAttribute("LastReachedStage", stage)
		end
		player:SetAttribute("PendingSkipStageFrom", stage)
		player:SetAttribute("PendingSkipStageTarget", stage + 1)
		player:SetAttribute("PendingSkipStageSetAt", Workspace:GetServerTimeNow())
		player:SetAttribute("PendingSkipStageWorld", 2)
		if SKIP_STAGE_PRODUCT_ID <= 0 then
			warn("[World2ManualStagePads] Skip Stage product is not configured")
			return
		end
		local ok, err = pcall(function()
			MarketplaceService:PromptProductPurchase(player, SKIP_STAGE_PRODUCT_ID)
		end)
		if not ok then
			warn("[World2ManualStagePads] Could not prompt Skip Stage purchase: " .. tostring(err))
		end
	end)
end

local function configurePadFromMarker(marker, kind, stage, isFinal)
	hideMarker(marker)
	local pad = createRuntimePad(marker, kind, stage, isFinal)
	addPadLight(pad, kind)

	if kind == "win" then
		local reward = isFinal and FINAL_WIN_REWARD or STAGE_REWARDS[stage]
		pad:SetAttribute("WinReward", reward)
		pad:SetAttribute("Repeatable", true)
		pad:SetAttribute("TeleportsToNormalSpawn", true)
		createPadLabel(pad, kind, formatNumber(reward) .. " Wins")
		connectRewardPad(pad, reward, false, stage, isFinal)
	elseif kind == "x2" then
		local reward = isFinal and FINAL_WIN_REWARD or STAGE_REWARDS[stage]
		pad:SetAttribute("BaseWinReward", reward)
		pad:SetAttribute("DoubledWinReward", reward * DOUBLE_WINS_MULTIPLIER)
		pad:SetAttribute("GamePassId", DOUBLE_WINS_PAD_GAMEPASS_ID)
		pad:SetAttribute("DoubleWinsMultiplier", DOUBLE_WINS_MULTIPLIER)
		createPadLabel(pad, kind, "2x Wins\n" .. formatNumber(reward * DOUBLE_WINS_MULTIPLIER) .. " Wins")
		connectRewardPad(pad, reward, true, stage, isFinal)
	elseif kind == "skip" then
		if stage >= STAGE_COUNT then
			                                               
			pad:Destroy()
			local base = runtimeBases[marker]
			if base and base.Parent then
				base:Destroy()
			end
			runtimePads[marker] = nil
			runtimeBases[marker] = nil
			marker:SetAttribute("World2FinalStageSkipDisabled", true)
			return
		end
		pad:SetAttribute("SkipStageProductId", SKIP_STAGE_PRODUCT_ID)
		pad:SetAttribute("SkipFromStage", stage)
		pad:SetAttribute("SkipTargetStage", stage + 1)
		pad:SetAttribute("SkipTargetIsFinalWinStage", false)
		createPadLabel(pad, kind, "Skip Stage")
		connectSkipPad(pad, stage)
	end
end

local function destroyStageLabel(stage)
	local board = stageLabelBoards[stage]
	if board and board.Parent then
		board:Destroy()
	end
	stageLabelBoards[stage] = nil
	stageLabelAnchors[stage] = nil
end

local function normalizeSafeZoneName(value)
	return tostring(value or ""):lower():gsub("[%s_%-]", "")
end

local function getSafeZoneBounds(object)
	if not object or not object.Parent then
		return nil, nil
	end
	if object:IsA("BasePart") then
		return object.CFrame, object.Size
	end
	if object:IsA("Model") then
		local ok, cframe, size = pcall(function()
			return object:GetBoundingBox()
		end)
		if ok then
			return cframe, size
		end
	end
	return nil, nil
end

local function safeZoneStageFromObject(object)
	if not object or not object.Parent or not (object:IsA("BasePart") or object:IsA("Model")) then
		return nil
	end
	local suffix = tostring(Config.World2SafeZoneSuffix or ".2")
	for stage = FIRST_STAGE, STAGE_COUNT do
		local zoneNumber = stage - 1
		local wanted = normalizeSafeZoneName("SafeZone" .. tostring(zoneNumber) .. suffix)
		if normalizeSafeZoneName(object.Name) == wanted then
			return stage
		end
	end
	return nil
end

local function registerStageSafeZone(object)
	local stage = safeZoneStageFromObject(object)
	if not stage then
		return false
	end
	local old = stageSafeZones[stage]
	if old and old ~= object and old.Parent then
		return false
	end
	stageSafeZones[stage] = object
	return true
end

local function unregisterStageSafeZone(object)
	for stage, safeZone in pairs(stageSafeZones) do
		if safeZone == object then
			stageSafeZones[stage] = nil
			return stage
		end
	end
	return nil
end

local function getStageAnchor(stage)
	                                                                       
	                                 
	                                                    
	local safeZone = stageSafeZones[stage]
	local safeZoneCFrame = getSafeZoneBounds(safeZone)
	if safeZoneCFrame then
		local horizontalLook = horizontalUnit(safeZoneCFrame.LookVector) or -Vector3.zAxis
		return {
			Position = safeZoneCFrame.Position,
			                                                                       
			LookVector = -horizontalLook,
		}, false
	end

	                                                                         
	                                                                              
	local fallback = manualParts.x2[stage] or manualParts.win[stage] or manualParts.skip[stage]
	if fallback and fallback.Parent then
		local _, look = getMarkerYawBasis(fallback)
		return {
			Position = fallback.Position,
			LookVector = -look,
		}, false
	end
	return nil, false
end

local function refreshStageLabel(stage)
	destroyStageLabel(stage)
	local anchor, explicit = getStageAnchor(stage)
	if not anchor then
		return
	end

	if explicit and anchor:IsA("BasePart") then
		hideMarker(anchor)
	end

	local position = anchor.Position
	local look = horizontalUnit(anchor.LookVector or Vector3.zAxis) or -Vector3.zAxis
	local yawDegrees = STAGE_TEXT_YAW_DEGREES_BY_STAGE[stage] or 0
	if math.abs(yawDegrees) > 0.001 then
		local yawRotation = CFrame.Angles(0, math.rad(yawDegrees), 0)
		local rotatedLook = yawRotation:VectorToWorldSpace(look)
		look = horizontalUnit(rotatedLook) or look
	end
	local textHeight = STAGE_TEXT_HEIGHT + (STAGE_TEXT_EXTRA_HEIGHT_BY_STAGE[stage] or 0)
	local baseTextPosition = Vector3.new(position.X, position.Y + textHeight, position.Z)
	local baseBoardCFrame = CFrame.lookAt(
		baseTextPosition,
		baseTextPosition + look,
		Vector3.yAxis
	)
	                                                                           
	                                                                        
	local rightShift = STAGE_TEXT_RIGHT_SHIFT_BY_STAGE[stage] or 0
	local textPosition = baseTextPosition + baseBoardCFrame.RightVector * rightShift
	local boardCFrame = CFrame.lookAt(
		textPosition,
		textPosition + look,
		Vector3.yAxis
	)

	local board = Instance.new("Part")
	board.Name = string.format("World2_Stage%02d_LabelBoard", stage)
	board.Anchored = true
	board.CanCollide = false
	board.CanTouch = false
	board.CanQuery = false
	board.CastShadow = false
	board.Transparency = 1
	board.Size = STAGE_TEXT_BOARD_SIZE
	board.CFrame = boardCFrame
	board:SetAttribute("WorldNumber", 2)
	board:SetAttribute("World2ManualStageText", true)
	board.Parent = runtimeFolder

	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Name = "FrontApproachStageText"
	surfaceGui.Adornee = board
	surfaceGui.Face = Enum.NormalId.Back
	surfaceGui.AlwaysOnTop = false
	surfaceGui.LightInfluence = 0
	surfaceGui.MaxDistance = 0
	surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surfaceGui.PixelsPerStud = STAGE_TEXT_PIXELS_PER_STUD
	surfaceGui.Parent = board

	local label = Instance.new("TextLabel")
	label.Name = "StageNumberText"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.Text = "STAGE " .. tostring(stage)
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = surfaceGui

	local constraint = Instance.new("UITextSizeConstraint")
	constraint.Name = "HugeWorldTextConstraint"
	constraint.MinTextSize = 1
	constraint.MaxTextSize = STAGE_TEXT_MAX_SIZE
	constraint.Parent = label

	local outline = Instance.new("UIStroke")
	outline.Name = "ThickBlackOutline"
	outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	outline.Color = Color3.fromRGB(0, 0, 0)
	outline.Thickness = STAGE_TEXT_OUTLINE_THICKNESS
	outline.Transparency = 0
	outline.Parent = label

	stageLabelBoards[stage] = board
	stageLabelAnchors[stage] = anchor
end

local function refreshStageRange()
	for stage = FIRST_STAGE, STAGE_COUNT do
		refreshStageLabel(stage)
	end
end

local function registerMarker(object)
	if not object or not object.Parent or not object:IsA("BasePart") or object:IsDescendantOf(runtimeFolder) then
		return false
	end
	local kind, stage = parseMarkerName(object.Name)
	if not kind or not markerIsValid(kind, stage) then
		return false
	end

	if kind == "finalwin" or kind == "finalx2" then
		local finalKind = kind == "finalwin" and "win" or "x2"
		finalParts[finalKind] = object
		if not configuredMarkers[object] then
			configuredMarkers[object] = true
			configurePadFromMarker(object, finalKind, STAGE_COUNT, true)
		end
		return true
	end

	manualParts[kind][stage] = object
	if kind ~= "stage" and not configuredMarkers[object] then
		configuredMarkers[object] = true
		configurePadFromMarker(object, kind, stage, false)
	end
	refreshStageLabel(stage)
	return true
end

local function unregisterMarker(object)
	if not object or not object:IsA("BasePart") then
		return
	end
	local kind, stage = parseMarkerName(object.Name)
	local runtimePad = runtimePads[object]
	if runtimePad and runtimePad.Parent then
		runtimePad:Destroy()
	end
	local runtimeBase = runtimeBases[object]
	if runtimeBase and runtimeBase.Parent then
		runtimeBase:Destroy()
	end
	runtimePads[object] = nil
	runtimeBases[object] = nil
	configuredMarkers[object] = nil
	if kind == "finalwin" and finalParts.win == object then
		finalParts.win = nil
		return
	end
	if kind == "finalx2" and finalParts.x2 == object then
		finalParts.x2 = nil
		return
	end
	if kind and stage and manualParts[kind] and manualParts[kind][stage] == object then
		manualParts[kind][stage] = nil
		refreshStageLabel(stage)
	end
end

local startupConfigured = 0
local startupSafeZones = 0
for _, object in ipairs(Workspace:GetDescendants()) do
	if registerStageSafeZone(object) then
		startupSafeZones += 1
	end
	if registerMarker(object) then
		startupConfigured += 1
	end
end
Workspace.DescendantAdded:Connect(function(object)
	local safeZoneAdded = registerStageSafeZone(object)
	registerMarker(object)
	if safeZoneAdded then
		local stage = safeZoneStageFromObject(object)
		if stage then
			refreshStageLabel(stage)
		end
	end
end)
Workspace.DescendantRemoving:Connect(function(object)
	local removedStage = unregisterStageSafeZone(object)
	unregisterMarker(object)
	if removedStage then
		task.defer(function()
			refreshStageLabel(removedStage)
		end)
	end
end)

-- Buying the x2 pads gamepass is handled by Services.DoubleWinsPad, which marks the
-- player as owner and re-checks the pad they were standing on.
--
-- This hook only serves the retired per-claim product: a receipt already in flight
-- pays its reward directly, so any pending pad is released rather than re-armed.
local function onDoubleWinsEntitlementGranted(player)
	DoubleWinsPad.Clear(player)
end
_G.SpeedsterDoubleWinsEntitledWorld2 = onDoubleWinsEntitlementGranted

local function setupPlayer(player)
end
Players.PlayerAdded:Connect(setupPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	setupPlayer(player)
end
Players.PlayerRemoving:Connect(function(player)
	lastClaimAt[player] = nil
	lastSkipPromptAt[player] = nil
end)

refreshStageRange()

print(
	"[World2ManualStagePads] " .. VERSION
		.. " active | World 2-only manual markers | runtime World 1-style pads + stage text"
		.. " | startup markers=" .. tostring(startupConfigured)
		.. " | stage SafeZones=" .. tostring(startupSafeZones)
)
