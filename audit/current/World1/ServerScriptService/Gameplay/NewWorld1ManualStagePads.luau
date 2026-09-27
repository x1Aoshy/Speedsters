                                                                
  
                                                                             
                                                                              
                   
                                     
                                         
                                                                    
                                                        
                                                                        
  
                                                                            
                                                                           
                                                                                
                                                                            
                                            

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
if Config.IsNewWorld1Map ~= true or Config.IsWorld2Place == true then
	return
end

local ServerScriptService = game:GetService("ServerScriptService")
local Services = ServerScriptService:WaitForChild("Services")
local StageTeleportService = require(Services:WaitForChild("StageTeleportService"))
local MovementGuard = require(Services:WaitForChild("MovementGuard"))

local STAGE_COUNT = math.max(1, math.floor(tonumber(Config.StageCount) or 11))
local SKIP_STAGE_PRODUCT_ID = math.max(0, math.floor(tonumber(Config.SkipStageProductId) or 0))
local DOUBLE_WINS_PAD_GAMEPASS_ID = tonumber(Config.DoubleWinsPadGamePassId) or 1941409601
local DOUBLE_WINS_PRODUCT_ID = tonumber(Config.DoubleWinsPadProductId) or 3712435111
local DOUBLE_WINS_MULTIPLIER = 2

                                                             
                                                                            
                                                                            
                                                                            
                                    
local STAGE_REWARDS = {
	[1] = 10,
	[2] = 35,
	[3] = 50,
	[4] = 75,
	[5] = 350,
	[6] = 750,
	[7] = 3750,
	[8] = 7000,
	[9] = 20000,
	[10] = 75000,
	[11] = 350000,
}
local FINAL_WIN_REWARD = 700000

local PAD_TOUCH_SOUND_ID = "rbxassetid://136993031050456"
local PAD_CLAIM_COOLDOWN = 1.5
local DOUBLE_WINS_PROMPT_COOLDOWN = 2
local SKIP_PROMPT_COOLDOWN = 1.5
local RUNTIME_FOLDER_NAME = "NewWorld1ManualStagePads_Runtime"
local VERSION = "V306KBUNewWorld1ManualPads"

                                                                             
                                                                          
                                                                            
                                                                           
local PAD_SIZE = Vector3.new(12.5, 0.5, 12.5)
local FINAL_PAD_SIZE = Vector3.new(14.5, 0.5, 14.5)
local PAD_BASE_HEIGHT = 0.28
local PAD_BASE_COLOR = Color3.fromRGB(18, 18, 18)
local PAD_BASE_PADDING = 0.75
local FINAL_PAD_BASE_PADDING = 1.25
local PAD_LIGHT_BRIGHTNESS = 0.8
local PAD_LIGHT_RANGE = 3
local PAD_LABEL_SIZE = UDim2.fromOffset(260, 56)
local PAD_LABEL_OFFSET = Vector3.new(0, 4.5, 0)
local PAD_LABEL_MAX_DISTANCE = 160
local PAD_LABEL_TEXT_SIZE = 22
local PAD_TEXT_STROKE_TRANSPARENCY = 0

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

local mapRootName = tostring(Config.NewWorld1MapMarkerName or "neworld1")
local mapRoot = Workspace:FindFirstChild(mapRootName) or Workspace:WaitForChild(mapRootName, 20)
if not mapRoot then
	warn("[NewWorld1ManualStagePads] Workspace." .. mapRootName .. " is missing")
	return
end

local runtimeFolder = Workspace:FindFirstChild(RUNTIME_FOLDER_NAME)
if runtimeFolder and not runtimeFolder:IsA("Folder") then
	runtimeFolder:Destroy()
	runtimeFolder = nil
end
if not runtimeFolder then
	runtimeFolder = Instance.new("Folder")
	runtimeFolder.Name = RUNTIME_FOLDER_NAME
	runtimeFolder.Parent = Workspace
end
runtimeFolder:SetAttribute("WorldNumber", 1)
runtimeFolder:SetAttribute("NewWorld1ManualMarkersAuthoritative", true)
runtimeFolder:SetAttribute("Version", VERSION)
for _, child in ipairs(runtimeFolder:GetChildren()) do
	child:Destroy()
end

local runtimePads = setmetatable({}, { __mode = "k" })
local runtimeBases = setmetatable({}, { __mode = "k" })
local configuredMarkers = setmetatable({}, { __mode = "k" })
local connectedPads = setmetatable({}, { __mode = "k" })
local markerSlots = { win = {}, x2 = {}, skip = {}, finalwin = {}, finalx2 = {} }
local lastClaimAt = {}
local lastDoubleWinsPromptAt = {}
local lastSkipPromptAt = {}
local doubleWinsOwned = {}
local claimingPlayers = setmetatable({}, { __mode = "k" })

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

local function markerTransform(marker)
	if marker:IsA("BasePart") then
		return marker.CFrame, marker.Size
	end
	if marker:IsA("Model") then
		local ok, cf, size = pcall(marker.GetBoundingBox, marker)
		if ok and cf and size then
			return cf, size
		end
	end
	return nil, nil
end

local function markerTopY(marker)
	local cf, size = markerTransform(marker)
	if not cf or not size then
		return nil
	end
	local half = size * 0.5
	local verticalExtent = math.abs(cf.RightVector.Y) * half.X
		+ math.abs(cf.UpVector.Y) * half.Y
		+ math.abs(cf.LookVector.Y) * half.Z
	return cf.Position.Y + verticalExtent
end

local function markerYawBasis(marker)
	local cf = markerTransform(marker)
	if not cf then
		return Vector3.xAxis, -Vector3.zAxis
	end
	local right = horizontalUnit(cf.RightVector)
	local look = horizontalUnit(cf.LookVector)
	if right and look then
		return right, look
	end
	if right then
		local derivedLook = horizontalUnit(Vector3.new(-right.Z, 0, right.X))
		return right, derivedLook or -Vector3.zAxis
	end
	if look then
		local derivedRight = horizontalUnit(Vector3.new(look.Z, 0, -look.X))
		return derivedRight or Vector3.xAxis, look
	end
	return Vector3.xAxis, -Vector3.zAxis
end

local function parseMarkerName(name)
	local n = normalizeName(name)
	if n == "winstage1" then return "finalwin", STAGE_COUNT + 1 end
	if n == "winstage2" then return "finalx2", STAGE_COUNT + 1 end
	local stage = tonumber(n:match("^x(%d+)$"))
	if stage then return "x2", math.floor(stage) end
	stage = tonumber(n:match("^win(%d+)$"))
	if stage then return "win", math.floor(stage) end
	stage = tonumber(n:match("^skip(%d+)$"))
	if stage then return "skip", math.floor(stage) end
	return nil, nil
end

local function markerIsValid(kind, stage)
	if (kind == "finalwin" or kind == "finalx2") and stage == STAGE_COUNT + 1 then
		return true
	end
	return kind ~= nil and stage ~= nil and stage >= 1 and stage <= STAGE_COUNT
end

local function visualKind(kind)
	if kind == "finalwin" then return "win" end
	if kind == "finalx2" then return "x2" end
	return kind
end

local function isCandidateObject(object)
	return object and (object:IsA("BasePart") or object:IsA("Model"))
end

local function candidatePriority(object)
	if object:IsDescendantOf(mapRoot) then
		return 1
	end
	                                                                             
	                                                                              
	return 2
end

local function shouldReplaceSlot(existing, candidate)
	if not existing or not existing.Parent then
		return true
	end
	local a = candidatePriority(candidate)
	local b = candidatePriority(existing)
	if a ~= b then
		return a < b
	end
	return candidate:GetFullName() < existing:GetFullName()
end

local function setMarkerHidden(marker, hidden)
	local function apply(part)
		if hidden then
			if part:GetAttribute("V306KBS_OrigTransparency") == nil then
				part:SetAttribute("V306KBS_OrigTransparency", part.Transparency)
				part:SetAttribute("V306KBS_OrigCanCollide", part.CanCollide)
				part:SetAttribute("V306KBS_OrigCanTouch", part.CanTouch)
				part:SetAttribute("V306KBS_OrigCanQuery", part.CanQuery)
				part:SetAttribute("V306KBS_OrigCastShadow", part.CastShadow)
			end
			part.Anchored = true
			part.Transparency = 1
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.CastShadow = false
		end
	end
	if marker:IsA("BasePart") then
		apply(marker)
	elseif marker:IsA("Model") then
		for _, descendant in ipairs(marker:GetDescendants()) do
			if descendant:IsA("BasePart") then
				apply(descendant)
			end
		end
	end
	marker:SetAttribute("NewWorld1ManualPadMarker", true)
	marker:SetAttribute("ManualCFrameAuthoritative", true)
	marker:SetAttribute("ManualSizeAuthoritative", true)
end

local function markerReward(marker, kind, stage)
	local value = STAGE_REWARDS[stage]
	if value ~= nil then
		return math.max(0, math.floor(value))
	end
	if marker then
		local attrReward = marker:GetAttribute(kind == "x2" and "BaseWinReward" or "WinReward")
			or marker:GetAttribute("WinReward")
			or marker:GetAttribute("BaseWinReward")
		if type(attrReward) == "number" then
			return math.max(0, math.floor(attrReward))
		end
	end
	return nil
end

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
		local ok, res = pcall(addWins, player, reward)
		if ok and res ~= false then
			return true
		end
	end
	local leaderstats = player and player:FindFirstChild("leaderstats")
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

local DOUBLE_WINS_PRODUCT_ID = tonumber(Config.DoubleWinsPadProductId) or 3712435111

local function ownsDoubleWins(player, forceRefresh)
	if (tonumber(player:GetAttribute("PermanentWinsMultiplier")) or 1) >= 2
		or player:GetAttribute("DoubleWinsPadUnlocked") == true
	then
		return true
	end
	if not forceRefresh and doubleWinsOwned[player] ~= nil then
		return doubleWinsOwned[player] == true
	end
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, DOUBLE_WINS_PAD_GAMEPASS_ID)
	end)
	if not ok then
		warn("[NewWorld1ManualStagePads] x2 Wins pass check failed for " .. player.Name .. ": " .. tostring(owns))
		return nil
	end
	doubleWinsOwned[player] = owns == true
	if owns == true then
		player:SetAttribute("DoubleWinsPadUnlocked", true)
		local current = tonumber(player:GetAttribute("PermanentWinsMultiplier")) or 1
		player:SetAttribute("PermanentWinsMultiplier", math.max(2, current))
	end
	return owns == true
end

local function promptDoubleWins(player)
	local now = os.clock()
	if now - (lastDoubleWinsPromptAt[player] or -math.huge) < DOUBLE_WINS_PROMPT_COOLDOWN then
		return
	end
	lastDoubleWinsPromptAt[player] = now
	local ok, err = pcall(function()
		MarketplaceService:PromptProductPurchase(player, DOUBLE_WINS_PRODUCT_ID)
	end)
	if not ok then
		warn("[NewWorld1ManualStagePads] Could not prompt x2 Wins DevProduct: " .. tostring(err))
	end
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

local function createRuntimePad(marker, kind, stage, isFinal)
	local oldPad = runtimePads[marker]
	if oldPad and oldPad.Parent then oldPad:Destroy() end
	local oldBase = runtimeBases[marker]
	if oldBase and oldBase.Parent then oldBase:Destroy() end

	local markerCf = markerTransform(marker)
	local topY = markerTopY(marker)
	if not markerCf or not topY then
		return nil
	end
	local padSize = isFinal and FINAL_PAD_SIZE or PAD_SIZE
	local renderKind = visualKind(kind)
	local right, look = markerYawBasis(marker)
	local cframe = CFrame.fromMatrix(
		Vector3.new(markerCf.Position.X, topY + padSize.Y * 0.5, markerCf.Position.Z),
		right,
		Vector3.yAxis,
		-look
	)

	local pad = Instance.new("Part")
	pad.Name = marker.Name .. "_RuntimePad"
	pad.Anchored = true
	pad.CanCollide = true
	pad.CanTouch = true
	pad.CanQuery = true
	pad.CastShadow = false
	pad.Material = Enum.Material.Neon
	pad.Color = COLORS[renderKind]
	pad.TopSurface = Enum.SurfaceType.Smooth
	pad.BottomSurface = Enum.SurfaceType.Smooth
	pad.Size = padSize
	pad.CFrame = cframe
	pad:SetAttribute("WorldNumber", 1)
	pad:SetAttribute("NewWorld1ManualPad", true)
	pad:SetAttribute("NewWorld1ManualPadType", kind)
	pad:SetAttribute("NewWorld1ManualStage", stage)
	pad:SetAttribute("NewWorld1FinalWinStagePad", isFinal == true)
	pad:SetAttribute("SafeZoneIndex", isFinal and 0 or stage)
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
	local basePadding = isFinal and FINAL_PAD_BASE_PADDING or PAD_BASE_PADDING
	base.Size = Vector3.new(pad.Size.X + basePadding, PAD_BASE_HEIGHT, pad.Size.Z + basePadding)
	base.CFrame = pad.CFrame * CFrame.new(0, -((pad.Size.Y + PAD_BASE_HEIGHT) * 0.5) + 0.02, 0)
	base:SetAttribute("NewWorld1ManualPadBase", true)
	base:SetAttribute("SourceMarkerName", marker.Name)
	base.Parent = runtimeFolder
	runtimeBases[marker] = base

	return pad
end

local function createPadLabel(pad, kind, text)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "WinRewardBillboard"
	billboard.Adornee = pad
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.Size = PAD_LABEL_SIZE
	billboard.StudsOffsetWorldSpace = PAD_LABEL_OFFSET
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
	label.TextScaled = true
	label.RichText = true
	label.TextSize = PAD_LABEL_TEXT_SIZE
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center

	local sizeConstraint = Instance.new("UITextSizeConstraint")
	sizeConstraint.MaxTextSize = 26
	sizeConstraint.MinTextSize = 13
	sizeConstraint.Parent = label

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

local function connectRewardPad(pad, reward, isDouble, stage, isFinal)
	if connectedPads[pad] then return end
	connectedPads[pad] = true
	pad.Touched:Connect(function(hit)
		local player, _, humanoid = playerFromHit(hit)
		if not player or not humanoid or humanoid.Health <= 0 then return end
		if player:GetAttribute("DataLoaded") ~= true or inArrivalGrace(player) then return end

		if claimingPlayers[player] then
			return
		end
		claimingPlayers[player] = true

		local function handleRewardTouch()
			if isDouble and ownsDoubleWins(player, false) ~= true then
				player:SetAttribute("PendingDoubleWinsStage", stage)
				player:SetAttribute("PendingDoubleWinsIsFinal", isFinal == true)
				promptDoubleWins(player)
				return
			end

			-- MovementGuard: reward pads require trusted, teleport-free stage
			-- progress (WinN/X2N need the player cleanly reaching stage N;
			-- final pads additionally gate on the last stage + a hard cooldown).
			local requiredProgress = isFinal and STAGE_COUNT or stage
			if not MovementGuard.CanClaim(player, requiredProgress, isFinal) then
				return
			end

			if not touchReady(player, pad) then return end
			-- Avoid double-multiplying (SpeedsterAddWins already applies the 2x PermanentWinsMultiplier)
			local finalReward = isDouble and reward or reward
			if not awardWins(player, finalReward) then
				warn("[NewWorld1ManualStagePads] Could not award Wins to " .. player.Name)
				return
			end
			player:SetAttribute("LastClaimedWinPad", pad.Name)
			player:SetAttribute("LastWinPadReward", finalReward)
			player:SetAttribute("LastCompletedSafeZone", math.min(stage, STAGE_COUNT))
			if isFinal or stage >= 11 then
				MovementGuard.RecordFinalClaim(player)
				player:SetAttribute("NewWorld1FinalWinStageClaimed", true)
			end
			playWinFeedback(player)
			local teleported, reason = StageTeleportService.TeleportToNormalSpawn(player)
			if not teleported then
				warn("[NewWorld1ManualStagePads] Could not return " .. player.Name .. " to normal spawn: " .. tostring(reason))
			end
			queueSave(player, isFinal
				and (isDouble and "new_world1_final_x2_win" or "new_world1_final_win")
				or ((isDouble and "new_world1_x2_stage_" or "new_world1_win_stage_") .. tostring(stage)))
		end

		local ok, err = pcall(handleRewardTouch)
		claimingPlayers[player] = nil
		if not ok then
			warn("[NewWorld1ManualStagePads] Error processing reward claim for " .. player.Name .. ": " .. tostring(err))
		end
	end)
end

local function connectSkipPad(pad, stage)
	if stage >= STAGE_COUNT or connectedPads[pad] then return end
	connectedPads[pad] = true
	pad.Touched:Connect(function(hit)
		local player, _, humanoid = playerFromHit(hit)
		if not player or not humanoid or humanoid.Health <= 0 then return end
		if player:GetAttribute("DataLoaded") ~= true or inArrivalGrace(player) then return end
		local now = os.clock()
		if now - (lastSkipPromptAt[player] or -math.huge) < SKIP_PROMPT_COOLDOWN then return end
		lastSkipPromptAt[player] = now
		local targetStage = stage + 1
		player:SetAttribute("CurrentSafeZoneStage", stage)
		local last = math.floor(tonumber(player:GetAttribute("LastReachedStage")) or 1)
		if stage > last then player:SetAttribute("LastReachedStage", stage) end
		player:SetAttribute("PendingSkipStageFrom", stage)
		player:SetAttribute("PendingSkipStageTarget", targetStage)
		player:SetAttribute("PendingSkipStageSetAt", Workspace:GetServerTimeNow())
		player:SetAttribute("PendingSkipStageWorld", 1)

		local productId = SKIP_STAGE_PRODUCT_ID
		for _, option in ipairs(Config.TeleportStageOptions or {}) do
			if option.Stage == targetStage and tonumber(option.ProductId) and tonumber(option.ProductId) > 0 then
				productId = tonumber(option.ProductId)
				break
			end
		end

		if productId <= 0 then
			warn("[NewWorld1ManualStagePads] Skip Stage product is not configured")
			return
		end
		local ok, err = pcall(function()
			MarketplaceService:PromptProductPurchase(player, productId)
		end)
		if not ok then
			warn("[NewWorld1ManualStagePads] Could not prompt Skip Stage purchase: " .. tostring(err))
		end
	end)
end

local function destroyRuntimeForMarker(marker)
	local pad = runtimePads[marker]
	if pad and pad.Parent then pad:Destroy() end
	local base = runtimeBases[marker]
	if base and base.Parent then base:Destroy() end
	runtimePads[marker] = nil
	runtimeBases[marker] = nil
	configuredMarkers[marker] = nil
end

local function configureMarker(marker, kind, stage)
	if configuredMarkers[marker] then return true end
	configuredMarkers[marker] = true
	setMarkerHidden(marker, true)

	local isFinal = kind == "finalwin" or kind == "finalx2"
	local renderKind = visualKind(kind)
	if kind == "skip" and stage >= STAGE_COUNT then
		marker:SetAttribute("NewWorld1FinalStageSkipDisabled", true)
		return true
	end

	local reward = nil
	if isFinal then
		reward = FINAL_WIN_REWARD
	elseif kind == "win" or kind == "x2" then
		reward = markerReward(marker, kind, stage)
	end
	if (kind == "win" or kind == "x2") and reward == nil then
		marker:SetAttribute("NewWorld1WinRewardNeedsConfiguration", true)
		warn(
			"[NewWorld1ManualStagePads] " .. marker:GetFullName()
				.. " has no established World 1 reward for Stage " .. tostring(stage)
				.. "; set WinReward/BaseWinReward on this marker to activate it"
		)
		return true
	end

	local pad = createRuntimePad(marker, kind, stage, isFinal)
	if not pad then
		warn("[NewWorld1ManualStagePads] Could not resolve authored marker bounds: " .. marker:GetFullName())
		return false
	end
	addPadLight(pad, renderKind)

	if renderKind == "win" then
		pad:SetAttribute("WinReward", reward)
		pad:SetAttribute("Repeatable", true)
		pad:SetAttribute("TeleportsToNormalSpawn", true)
		createPadLabel(pad, renderKind, "+" .. formatNumber(reward) .. " Wins")
		connectRewardPad(pad, reward, false, stage, isFinal)
	elseif renderKind == "x2" then
		pad:SetAttribute("BaseWinReward", reward)
		pad:SetAttribute("DoubledWinReward", reward * DOUBLE_WINS_MULTIPLIER)
		pad:SetAttribute("ProductId", DOUBLE_WINS_PRODUCT_ID)
		pad:SetAttribute("GamePassId", DOUBLE_WINS_PAD_GAMEPASS_ID)
		pad:SetAttribute("DoubleWinsMultiplier", DOUBLE_WINS_MULTIPLIER)
		createPadLabel(pad, renderKind, "2x Wins (+" .. formatNumber(reward * DOUBLE_WINS_MULTIPLIER) .. ")")
		connectRewardPad(pad, reward, true, stage, isFinal)
	elseif kind == "skip" then
		local targetStage = stage + 1
		local productId = SKIP_STAGE_PRODUCT_ID
		local priceRobux = nil
		for _, option in ipairs(Config.TeleportStageOptions or {}) do
			if option.Stage == targetStage and tonumber(option.ProductId) and tonumber(option.ProductId) > 0 then
				productId = tonumber(option.ProductId)
				priceRobux = option.PriceRobux
				break
			end
		end
		pad:SetAttribute("SkipStageProductId", productId)
		pad:SetAttribute("SkipFromStage", stage)
		pad:SetAttribute("SkipTargetStage", targetStage)
		local skipText = "Skip to Stage " .. tostring(targetStage)
		if priceRobux and priceRobux > 0 then
			skipText = skipText .. " (" .. tostring(priceRobux) .. " R$)"
		end
		createPadLabel(pad, kind, skipText)
		connectSkipPad(pad, stage)
	end
	return true
end

local function registerMarker(object)
	if not isCandidateObject(object) or object:IsDescendantOf(runtimeFolder) then
		return false
	end
	local kind, stage = parseMarkerName(object.Name)
	if not markerIsValid(kind, stage) then
		return false
	end

	local existing = markerSlots[kind][stage]
	if existing == object then
		return true
	end
	if existing and not shouldReplaceSlot(existing, object) then
		return false
	end
	if existing and existing ~= object then
		destroyRuntimeForMarker(existing)
	end
	markerSlots[kind][stage] = object
	configureMarker(object, kind, stage)
	return true
end

local function unregisterMarker(object)
	local kind, stage = parseMarkerName(object and object.Name)
	if not kind or not stage then return end
	if markerSlots[kind][stage] == object then
		markerSlots[kind][stage] = nil
		destroyRuntimeForMarker(object)
	end
end

local startupConfigured = 0
for _, object in ipairs(Workspace:GetDescendants()) do
	if registerMarker(object) then
		startupConfigured += 1
	end
end

Workspace.DescendantAdded:Connect(function(object)
	registerMarker(object)
end)
Workspace.DescendantRemoving:Connect(function(object)
	unregisterMarker(object)
end)

local function checkPendingDoubleWins(player)
	local pendingStage = player:GetAttribute("PendingDoubleWinsStage")
	local pendingIsFinal = player:GetAttribute("PendingDoubleWinsIsFinal") == true
	player:SetAttribute("PendingDoubleWinsStage", nil)
	player:SetAttribute("PendingDoubleWinsIsFinal", nil)

	if pendingStage then
		local stageReward = pendingIsFinal and FINAL_WIN_REWARD or STAGE_REWARDS[pendingStage]
		if stageReward then
			local doubled = stageReward * DOUBLE_WINS_MULTIPLIER
			awardWins(player, doubled)
			player:SetAttribute("LastClaimedWinPad", "X" .. tostring(pendingStage))
			player:SetAttribute("LastWinPadReward", doubled)
			player:SetAttribute("LastCompletedSafeZone", math.min(pendingStage, STAGE_COUNT))
			if pendingIsFinal then
				MovementGuard.RecordFinalClaim(player)
				player:SetAttribute("NewWorld1FinalWinStageClaimed", true)
			end
			playWinFeedback(player)
			StageTeleportService.TeleportToNormalSpawn(player)
			queueSave(player, "new_world1_x2_purchased_award")
		end
	end
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, purchaseSuccess)
	if tonumber(gamePassId) == DOUBLE_WINS_PAD_GAMEPASS_ID and purchaseSuccess then
		doubleWinsOwned[player] = true
		player:SetAttribute("DoubleWinsPadUnlocked", true)
		local current = tonumber(player:GetAttribute("PermanentWinsMultiplier")) or 1
		local newMult = math.max(2, current)
		player:SetAttribute("PermanentWinsMultiplier", newMult)
		if type(_G.SpeedsterSetPermanentWinsMultiplier) == "function" then
			_G.SpeedsterSetPermanentWinsMultiplier(player, newMult)
		end
		checkPendingDoubleWins(player)
	end
end)

MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, isPurchased)
	if isPurchased and tonumber(productId) == DOUBLE_WINS_PRODUCT_ID then
		local player = Players:GetPlayerByUserId(userId)
		if player then
			doubleWinsOwned[player] = true
			player:SetAttribute("DoubleWinsPadUnlocked", true)
			local current = tonumber(player:GetAttribute("PermanentWinsMultiplier")) or 1
			local newMult = math.max(2, current)
			player:SetAttribute("PermanentWinsMultiplier", newMult)
			if type(_G.SpeedsterSetPermanentWinsMultiplier) == "function" then
				_G.SpeedsterSetPermanentWinsMultiplier(player, newMult)
			end
			checkPendingDoubleWins(player)
		end
	end
end)

local function setupPlayer(player)
	player:GetAttributeChangedSignal("PermanentWinsMultiplier"):Connect(function()
		local mult = tonumber(player:GetAttribute("PermanentWinsMultiplier")) or 1
		if mult >= 2 then
			doubleWinsOwned[player] = true
			player:SetAttribute("DoubleWinsPadUnlocked", true)
			checkPendingDoubleWins(player)
		end
	end)
	task.defer(function()
		ownsDoubleWins(player, true)
	end)
end
Players.PlayerAdded:Connect(setupPlayer)
for _, player in ipairs(Players:GetPlayers()) do setupPlayer(player) end
Players.PlayerRemoving:Connect(function(player)
	lastClaimAt[player] = nil
	lastDoubleWinsPromptAt[player] = nil
	lastSkipPromptAt[player] = nil
	doubleWinsOwned[player] = nil
end)

print(
	"[NewWorld1ManualStagePads] " .. VERSION
		.. " active | X1-X11=x2, Win1-Win11=normal, Skip1-Skip11=skip"
		.. " | Winstage1=700k final, Winstage2=x2 final"
		.. " | 12.5-stud regular pads | exact authored marker transforms | runtime pads=" .. tostring(startupConfigured)
		.. " | normal-spawn return | no World 2 runtime dependency"
)
