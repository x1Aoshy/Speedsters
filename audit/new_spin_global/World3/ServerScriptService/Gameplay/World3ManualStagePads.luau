-- World3ManualStagePads.server.luau
-- The Win, x2 and Skip pads of World 3 (Desert), and its finish.
--
-- The designer left one checkpoint template per stage ("stage1" block with "Win1", "X1"
-- and "Skip1" parts) and the same template once more at the end of the course.
-- Shared.World3StageTeleportService reads them (the stage number comes from each "Stage N"
-- folder); this script hides those flat parts and builds the playable pads on top, in
-- World 2's look:
--
--   Win   Stage N (2-10) pays Config.World3StageWinRewards[N]; the finish pays
--         Config.World3FinalWinReward.
--   x2    The same reward doubled, for owners of the x2 pads game pass
--         (Services.DoubleWinsPad); anyone else is offered the pass.
--   Skip  Prompts the Skip Stage product. Stage N skips to Stage N + 1, the last stage to the
--         finish (SpeedProductPurchases pays out through the stage service).
--
-- Every claim goes through Services.RewardPadClaims (MovementGuard, one grant per touch,
-- the player's Wins multipliers) and returns the player to the lobby spawn, as in World 2.
-- Claiming the finish also bursts confetti over it and plays the victory sound.

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
if Config.IsWorld3Place ~= true then
	return
end

local StageTeleport = require(script.Parent:WaitForChild("World3StageTeleportService"))
local Services = ServerScriptService:WaitForChild("Services")
local RewardPadClaims = require(Services:WaitForChild("RewardPadClaims"))
local PadTouchService = require(Services:WaitForChild("PadTouchService"))
local DoubleWinsPad = require(Services:WaitForChild("DoubleWinsPad"))
local WinsMath = require(Shared:WaitForChild("WinsMath"))

local FIRST_STAGE = 2
local STAGE_COUNT = StageTeleport.StageCount
local SKIP_STAGE_PRODUCT_ID = math.max(0, math.floor(tonumber(Config.SkipStageProductId) or 0))
local DOUBLE_WINS_MULTIPLIER = WinsMath.PadDoubleMultiplier
local FINAL_WIN_REWARD = math.max(0, math.floor(tonumber(Config.World3FinalWinReward) or 0))
local STAGE_REWARDS = {}
for stage = FIRST_STAGE, STAGE_COUNT do
	STAGE_REWARDS[stage] = math.max(0, math.floor(tonumber(Config.World3StageWinRewards and Config.World3StageWinRewards[stage]) or 0))
end

local PAD_TOUCH_SOUND_ID = "rbxassetid://136993031050456"
local VICTORY_SOUND_NAME = "winner!" -- the victory sound every world keeps in Workspace
local PAD_CLAIM_COOLDOWN = 1.5
local SKIP_PROMPT_COOLDOWN = 1.5
local RUNTIME_FOLDER_NAME = "World3ManualStagePads_Runtime"
local VERSION = "W3Pads1"

-- World 2's pad look.
local PAD_SIZE = Vector3.new(7, 0.5, 7)
local FINAL_PAD_SIZE = Vector3.new(9, 0.5, 9)
local PAD_BASE_HEIGHT = 0.28
local PAD_BASE_COLOR = Color3.fromRGB(18, 18, 18)
local PAD_BASE_PADDING_NORMAL = 0.75
local PAD_BASE_PADDING_FINAL = 1.25
local PAD_LIGHT_BRIGHTNESS = 0.8
local PAD_LIGHT_RANGE = 3
local PAD_LABEL_SIZE = UDim2.fromOffset(118, 27)
local PAD_LABEL_MULTILINE_SIZE = UDim2.fromOffset(150, 46)
local PAD_LABEL_OFFSET = Vector3.new(0, 1.75, 0)
local PAD_LABEL_MULTILINE_OFFSET = Vector3.new(0, 2.1, 0)
local PAD_LABEL_MAX_DISTANCE = 117
local PAD_LABEL_TEXT_SIZE = 19
local PAD_LABEL_MULTILINE_TEXT_SIZE = 16
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

-- The finish sign, in World 2's stage text style, over the front of the finish block.
local FINISH_SIGN_SIZE = Vector3.new(46, 12.6, 0.2)
local FINISH_SIGN_HEIGHT = 26.5
local FINISH_SIGN_PIXELS_PER_STUD = 8
local FINISH_CONFETTI_BURST = 140

local Service = {}

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------
local function formatNumber(value)
	local text = tostring(math.floor(tonumber(value) or 0))
	while true do
		local changed
		text, changed = string.gsub(text, "^(-?%d+)(%d%d%d)", "%1,%2")
		if changed == 0 then
			return text
		end
	end
end
Service.FormatNumber = formatNumber

-- The texts on the pads.
function Service.LabelText(kind, reward)
	if kind == "win" then
		return "+" .. formatNumber(reward) .. " Wins"
	elseif kind == "x2" then
		return "x2 Wins\n+" .. formatNumber(reward * DOUBLE_WINS_MULTIPLIER) .. " Wins"
	end
	return "Skip Stage"
end

local function horizontalUnit(vector)
	local flat = Vector3.new(vector.X, 0, vector.Z)
	if flat.Magnitude < 0.001 then
		return nil
	end
	return flat.Unit
end

-- A level CFrame at `position` looking along `direction`, built from its axes.
local function facing(position, direction)
	local look = Vector3.new(direction.X, 0, direction.Z).Unit
	return CFrame.fromMatrix(position, look:Cross(Vector3.yAxis).Unit, Vector3.yAxis, -look)
end

local function topY(part)
	local half = part.Size * 0.5
	local cframe = part.CFrame
	return cframe.Position.Y
		+ math.abs(cframe.RightVector.Y) * half.X
		+ math.abs(cframe.UpVector.Y) * half.Y
		+ math.abs(cframe.LookVector.Y) * half.Z
end

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end
local winPadFeedback = remotes:FindFirstChild("WinPadFeedback")
if not winPadFeedback then
	winPadFeedback = Instance.new("RemoteEvent")
	winPadFeedback.Name = "WinPadFeedback"
	winPadFeedback.Parent = remotes
end

local runtimeFolder = Workspace:FindFirstChild(RUNTIME_FOLDER_NAME)
if not runtimeFolder then
	runtimeFolder = Instance.new("Folder")
	runtimeFolder.Name = RUNTIME_FOLDER_NAME
	runtimeFolder.Parent = Workspace
end
for _, child in runtimeFolder:GetChildren() do
	child:Destroy()
end
runtimeFolder:SetAttribute("WorldNumber", 3)
runtimeFolder:SetAttribute("Version", VERSION)

local function victorySoundId()
	local sound = Workspace:FindFirstChild(VICTORY_SOUND_NAME)
	local id = sound and sound:IsA("Sound") and sound.SoundId or ""
	return if id ~= "" then id else PAD_TOUCH_SOUND_ID
end

local function playerFromHit(hit)
	if not hit or not hit:IsA("BasePart") then
		return nil, nil
	end
	local current = hit.Parent
	while current and current ~= Workspace do
		if current:IsA("Model") then
			local humanoid = current:FindFirstChildOfClass("Humanoid")
			if humanoid then
				return Players:GetPlayerFromCharacter(current), humanoid
			end
		end
		current = current.Parent
	end
	return nil, nil
end

local function canUsePad(player, humanoid)
	return player ~= nil
		and humanoid ~= nil
		and humanoid.Health > 0
		and player:GetAttribute("DataLoaded") == true
		and os.clock() >= (tonumber(player:GetAttribute("StageTeleportArrivalGraceUntil")) or 0)
end

local lastClaimAt = {}
local lastSkipPromptAt = {}

local function touchReady(player, pad)
	local perPlayer = lastClaimAt[player]
	if not perPlayer then
		perPlayer = setmetatable({}, { __mode = "k" })
		lastClaimAt[player] = perPlayer
	end
	local now = os.clock()
	if now - (perPlayer[pad] or -math.huge) < PAD_CLAIM_COOLDOWN then
		return false
	end
	perPlayer[pad] = now
	return true
end

local function queueSave(player, reason)
	if type(_G.SpeedsterSavePlayer) == "function" then
		task.defer(_G.SpeedsterSavePlayer, player, reason)
	end
end

----------------------------------------------------------------------
-- Building pads
----------------------------------------------------------------------
-- The authored parts stay where the designer put them, invisible and untouchable.
local function hideMarker(marker)
	marker.Transparency = 1
	marker.CanCollide = false
	marker.CanTouch = false
	marker.CanQuery = false
	marker.CastShadow = false
	marker:SetAttribute("World3ManualMarker", true)
end

-- `surfaceY`: the floor the pad stands on when its marker sits lower (the End's markers are
-- sunk into its floor).
local function createPad(marker, kind, stage, isFinal, surfaceY)
	hideMarker(marker)
	local size = if isFinal then FINAL_PAD_SIZE else PAD_SIZE
	local right = horizontalUnit(marker.CFrame.RightVector) or Vector3.xAxis
	local look = horizontalUnit(marker.CFrame.LookVector) or -Vector3.zAxis
	local position = Vector3.new(marker.CFrame.Position.X, math.max(topY(marker), surfaceY or -math.huge) + size.Y * 0.5, marker.CFrame.Position.Z)

	local pad = Instance.new("Part")
	pad.Name = string.format("%s%s_%s", if isFinal then "Finish" else "Stage", if isFinal then "" else tostring(stage), kind)
	pad.Anchored = true
	pad.CanCollide = false
	pad.CanTouch = true
	pad.CanQuery = true
	pad.CastShadow = false
	pad.Material = Enum.Material.Neon
	pad.Color = COLORS[kind]
	pad.Size = size
	pad.CFrame = CFrame.fromMatrix(position, right, Vector3.yAxis, -look)
	pad:SetAttribute("WorldNumber", 3)
	pad:SetAttribute("World3ManualPad", true)
	pad:SetAttribute("World3ManualPadType", kind)
	pad:SetAttribute("World3ManualStage", stage)
	pad:SetAttribute("World3FinalWinStagePad", isFinal == true)
	pad:SetAttribute("SourceMarkerName", marker:GetFullName())
	pad.Parent = runtimeFolder

	local base = Instance.new("Part")
	base.Name = pad.Name .. "_Base"
	base.Anchored = true
	base.CanCollide = false
	base.CanTouch = false
	base.CanQuery = false
	base.CastShadow = false
	base.Material = Enum.Material.SmoothPlastic
	base.Color = PAD_BASE_COLOR
	base.TopSurface = Enum.SurfaceType.Studs
	local padding = if isFinal then PAD_BASE_PADDING_FINAL else PAD_BASE_PADDING_NORMAL
	base.Size = Vector3.new(size.X + padding, PAD_BASE_HEIGHT, size.Z + padding)
	base.CFrame = pad.CFrame * CFrame.new(0, -(size.Y + PAD_BASE_HEIGHT) * 0.5 + 0.02, 0)
	base:SetAttribute("World3ManualPadBase", true)
	base.Parent = runtimeFolder

	local light = Instance.new("PointLight")
	light.Name = "PadLight"
	light.Color = LIGHT_COLORS[kind]
	light.Brightness = PAD_LIGHT_BRIGHTNESS
	light.Range = PAD_LIGHT_RANGE
	light.Shadows = false
	light.Parent = pad
	return pad
end

local function addLabel(pad, kind, text)
	local multiline = string.find(text, "\n", 1, true) ~= nil
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "WinRewardBillboard"
	billboard.Adornee = pad
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.Size = if multiline then PAD_LABEL_MULTILINE_SIZE else PAD_LABEL_SIZE
	billboard.StudsOffsetWorldSpace = if multiline then PAD_LABEL_MULTILINE_OFFSET else PAD_LABEL_OFFSET
	billboard.MaxDistance = PAD_LABEL_MAX_DISTANCE
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
	label.TextSize = if multiline then PAD_LABEL_MULTILINE_TEXT_SIZE else PAD_LABEL_TEXT_SIZE
	label.Parent = billboard
end

local function addConfetti(pad)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "FinishConfetti"
	emitter.Enabled = false
	emitter.Rate = 0
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 70, 70)),
		ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 200, 0)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(60, 220, 90)),
		ColorSequenceKeypoint.new(0.75, Color3.fromRGB(60, 160, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 80, 255)),
	})
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.45),
		NumberSequenceKeypoint.new(1, 0.3),
	})
	emitter.Lifetime = NumberRange.new(2.2, 3.6)
	emitter.Speed = NumberRange.new(30, 48)
	emitter.SpreadAngle = Vector2.new(40, 40)
	emitter.Acceleration = Vector3.new(0, -38, 0)
	emitter.Drag = 1.2
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-320, 320)
	emitter.LightEmission = 0.25
	emitter.Parent = pad
	return emitter
end

local function celebrate(player, pad)
	winPadFeedback:FireClient(player, victorySoundId())
	local confetti = pad:FindFirstChild("FinishConfetti")
	if confetti then
		pcall(function()
			confetti:Emit(FINISH_CONFETTI_BURST)
		end)
	end
end

----------------------------------------------------------------------
-- Pad behaviour
----------------------------------------------------------------------
local function connectRewardPad(pad, baseReward, isDouble, stage, isFinal)
	pad:SetAttribute("BaseReward", baseReward)
	pad:SetAttribute("IsDoublePad", isDouble)
	pad:SetAttribute("StageNumber", stage)
	PadTouchService.Connect(pad, function(hit)
		local player, humanoid = playerFromHit(hit)
		if not canUsePad(player, humanoid) then
			return false
		end
		-- x2 pads need the permanent x2 pads game pass (Services.DoubleWinsPad).
		if isDouble and not DoubleWinsPad.IsEntitled(player) then
			DoubleWinsPad.RequestPurchase(player, pad, "[World3ManualStagePads]")
			return true
		end
		if not touchReady(player, pad) then
			return false
		end
		-- Pad doubling first; RewardPadClaims then applies the player's own multipliers.
		local reward = WinsMath.GetPadBaseReward(baseReward, isDouble, true)
		return RewardPadClaims.Claim(player, pad, reward, stage, isFinal, function(claimer)
			local ok, reason = StageTeleport.TeleportToStart(claimer)
			if not ok then
				warn("[World3ManualStagePads] Could not return " .. claimer.Name .. " to the lobby: " .. tostring(reason))
			end
			return ok
		end, function(grantedAmount)
			DoubleWinsPad.Clear(player)
			player:SetAttribute("LastClaimedWinPad", pad.Name)
			player:SetAttribute("LastWinPadReward", grantedAmount)
			player:SetAttribute("LastCompletedSafeZone", stage)
			if isFinal then
				player:SetAttribute("World3FinalWinStageClaimed", true)
				celebrate(player, pad)
				-- Finishing World 3 wins its mythic skin, the Silver Surfer (once; SkinSystem).
				local grantSkin = _G.SpeedsterGrantExclusiveSkin
				if type(grantSkin) == "function" then
					task.spawn(grantSkin, player, "SilverSurferSuit", "world3_finish_silver_surfer")
				end
			else
				winPadFeedback:FireClient(player, PAD_TOUCH_SOUND_ID)
			end
			local what = if isDouble then "x2" else "win"
			queueSave(player, if isFinal then "world3_final_" .. what else "world3_" .. what .. "_stage_" .. stage)
		end)
	end)
end

local function connectSkipPad(pad, stage)
	local toFinish = stage >= STAGE_COUNT
	pad:SetAttribute("SkipStageProductId", SKIP_STAGE_PRODUCT_ID)
	pad:SetAttribute("SkipFromStage", stage)
	pad:SetAttribute("SkipTargetStage", stage + 1)
	pad:SetAttribute("SkipTargetIsFinish", toFinish)
	PadTouchService.Connect(pad, function(hit)
		local player, humanoid = playerFromHit(hit)
		if not canUsePad(player, humanoid) then
			return false
		end
		local now = os.clock()
		if now - (lastSkipPromptAt[player] or -math.huge) < SKIP_PROMPT_COOLDOWN then
			return false
		end
		lastSkipPromptAt[player] = now
		player:SetAttribute("CurrentSafeZoneStage", stage)
		if stage > math.floor(tonumber(player:GetAttribute("LastReachedStage")) or 1) then
			player:SetAttribute("LastReachedStage", stage)
		end
		-- SpeedProductPurchases reads these when the receipt arrives. From the last stage
		-- the target is past STAGE_COUNT: the finish.
		player:SetAttribute("PendingSkipStageFrom", stage)
		player:SetAttribute("PendingSkipStageTarget", stage + 1)
		player:SetAttribute("PendingSkipStageSetAt", Workspace:GetServerTimeNow())
		player:SetAttribute("PendingSkipStageWorld", 3)
		if SKIP_STAGE_PRODUCT_ID <= 0 then
			warn("[World3ManualStagePads] The Skip Stage product is not configured")
			return false
		end
		local ok, err = pcall(function()
			MarketplaceService:PromptProductPurchase(player, SKIP_STAGE_PRODUCT_ID)
		end)
		if not ok then
			warn("[World3ManualStagePads] Could not prompt Skip Stage: " .. tostring(err))
		end
		return true
	end)
end

----------------------------------------------------------------------
-- The course
----------------------------------------------------------------------
local built = { Stages = {}, Finish = nil }
Service.Built = built

for stage = FIRST_STAGE, STAGE_COUNT do
	local markers = StageTeleport.GetStageMarkers(stage)
	if markers and markers.Win and markers.X2 and markers.Skip then
		local reward = STAGE_REWARDS[stage]
		local win = createPad(markers.Win, "win", stage, false)
		win:SetAttribute("WinReward", reward)
		addLabel(win, "win", Service.LabelText("win", reward))
		connectRewardPad(win, reward, false, stage, false)

		local x2 = createPad(markers.X2, "x2", stage, false)
		x2:SetAttribute("BaseWinReward", reward)
		x2:SetAttribute("DoubledWinReward", reward * DOUBLE_WINS_MULTIPLIER)
		x2:SetAttribute("GamePassId", DoubleWinsPad.GamePassId)
		addLabel(x2, "x2", Service.LabelText("x2", reward))
		connectRewardPad(x2, reward, true, stage, false)

		local skip = createPad(markers.Skip, "skip", stage, false)
		addLabel(skip, "skip", Service.LabelText("skip"))
		connectSkipPad(skip, stage)

		built.Stages[stage] = { Win = win, X2 = x2, Skip = skip }
	else
		warn("[World3ManualStagePads] Stage " .. stage .. " has no complete pad set")
	end
end

local finish = StageTeleport.GetFinish()
if finish then
	finish.Checkpoint:SetAttribute(StageTeleport.FinalAttribute, true)
	-- The End's markers are sunk into its floor: the pads stand on the floor.
	local surfaceY = if finish.End then topY(finish.Checkpoint) else nil

	local win = createPad(finish.Win, "win", STAGE_COUNT, true, surfaceY)
	win:SetAttribute("WinReward", FINAL_WIN_REWARD)
	addLabel(win, "win", Service.LabelText("win", FINAL_WIN_REWARD))
	addConfetti(win)
	connectRewardPad(win, FINAL_WIN_REWARD, false, STAGE_COUNT, true)

	local x2 = nil
	if finish.X2 then
		x2 = createPad(finish.X2, "x2", STAGE_COUNT, true, surfaceY)
		x2:SetAttribute("BaseWinReward", FINAL_WIN_REWARD)
		x2:SetAttribute("DoubledWinReward", FINAL_WIN_REWARD * DOUBLE_WINS_MULTIPLIER)
		x2:SetAttribute("GamePassId", DoubleWinsPad.GamePassId)
		addLabel(x2, "x2", Service.LabelText("x2", FINAL_WIN_REWARD))
		addConfetti(x2)
		connectRewardPad(x2, FINAL_WIN_REWARD, true, STAGE_COUNT, true)
	else
		warn("[World3ManualStagePads] The finish has no x2 pad marker")
	end

	-- Nothing to skip at the finish.
	if finish.Skip then
		hideMarker(finish.Skip)
		finish.Skip:SetAttribute("World3FinishSkipDisabled", true)
	end

	-- "FINISH" over the front of the block, facing the runners.
	local checkpoint = finish.Checkpoint
	local lastStage = StageTeleport.GetStageReferencePosition(STAGE_COUNT)
	local centre = checkpoint.CFrame.Position
	local forward = lastStage and horizontalUnit(centre - lastStage) or -Vector3.zAxis
	local halfDepth = math.abs(checkpoint.CFrame.RightVector:Dot(forward)) * checkpoint.Size.X / 2
		+ math.abs(checkpoint.CFrame.LookVector:Dot(forward)) * checkpoint.Size.Z / 2
	local signPosition = Vector3.new(centre.X, topY(checkpoint) + FINISH_SIGN_HEIGHT, centre.Z) - forward * halfDepth
	local sign = Instance.new("Part")
	sign.Name = "FinishSign"
	sign.Anchored = true
	sign.CanCollide = false
	sign.CanTouch = false
	sign.CanQuery = false
	sign.CastShadow = false
	sign.Transparency = 1
	sign.Size = FINISH_SIGN_SIZE
	sign.CFrame = facing(signPosition, forward)
	sign.Parent = runtimeFolder
	local surface = Instance.new("SurfaceGui")
	surface.Name = "FinishText"
	surface.Face = Enum.NormalId.Back
	surface.LightInfluence = 0
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = FINISH_SIGN_PIXELS_PER_STUD
	surface.Parent = sign
	local text = Instance.new("TextLabel")
	text.Name = "Finish"
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.GothamBlack
	text.Text = "FINISH"
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(255, 205, 40)
	text.Parent = surface
	local outline = Instance.new("UIStroke")
	outline.Color = Color3.fromRGB(0, 0, 0)
	outline.Thickness = 8
	outline.Parent = text

	built.Finish = { Win = win, X2 = x2, Sign = sign }
else
	warn("[World3ManualStagePads] The finish block is missing; World 3 cannot be finished")
end

Players.PlayerRemoving:Connect(function(player)
	lastClaimAt[player] = nil
	lastSkipPromptAt[player] = nil
end)

local stagesBuilt = 0
for _ in built.Stages do
	stagesBuilt += 1
end
print(string.format("[World3ManualStagePads] %s | %d/%d stage pad sets | finish=%s | skip product=%d",
	VERSION, stagesBuilt, STAGE_COUNT - FIRST_STAGE + 1, tostring(built.Finish ~= nil), SKIP_STAGE_PRODUCT_ID))

return Service
