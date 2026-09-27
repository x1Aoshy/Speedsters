local fs = require("@lune/fs")

local function normalize(s)
    return (s:gsub("\r\n", "\n"))
end

local function replace(s, a, b)
    local sn = normalize(s)
    local an = normalize(a)
    local bn = normalize(b)
    local x, y = sn:find(an, 1, true)
    assert(x, "Missing anchor:\n" .. an:sub(1, 100))
    return sn:sub(1, x - 1) .. bn .. sn:sub(y + 1)
end

print("=== FIXING SPEED COUNTER, TREADMILLS, TELEPORT & STAGES ===")

-- 1. MainHUDController: Speed counter fix in World1 & World2
for _, world in {"World1", "World2"} do
    local path = "audit/merged/" .. world .. "/StarterPlayer/StarterPlayerScripts/UI/MainHUDController.luau"
    local s = fs.readFile(path)

    local oldBlock = [[local speedUpdatePending = false

local function commitSpeedText(explicitSpeed)
	local actualSpeed = cleanSpeed(readSpeedAmount()) or 1
	local displaySpeed = cleanSpeed(explicitSpeed) or actualSpeed
	lastCommittedSpeed = displaySpeed
	speedLabel.Text = "Speed: " .. formatNumber(displaySpeed)
end

local function scheduleSpeedTextUpdate(forceInstant)
	if forceInstant or lastCommittedSpeed == nil then
		commitSpeedText()
		return
	end
	if speedUpdatePending then return end
	speedUpdatePending = true
	task.defer(function()
		speedUpdatePending = false
		commitSpeedText()
	end)
end]]

    if not normalize(s):find(normalize(oldBlock), 1, true) then
        local originalOldBlock = [[local function commitSpeedText(explicitSpeed)
	local actualSpeed = cleanSpeed(readSpeedAmount()) or 1
	local displaySpeed = cleanSpeed(explicitSpeed) or actualSpeed
	-- Late overlapping impacts cannot rewind the number or undo a rebirth reset.
	displaySpeed = math.min(actualSpeed, math.max(displaySpeed, lastCommittedSpeed or displaySpeed))
	lastCommittedSpeed = displaySpeed
	speedLabel.Text = "Speed: " .. formatNumber(displaySpeed)
end

local function scheduleSpeedTextUpdate(forceInstant)
	local actualSpeed = cleanSpeed(readSpeedAmount()) or 1
	if forceInstant or lastCommittedSpeed == nil or actualSpeed < lastCommittedSpeed then
		speedUpdateSerial += 1
		commitSpeedText(actualSpeed)
		return
	end
	speedUpdateSerial += 1
	local thisSerial = speedUpdateSerial
	task.delay(SPEED_TEXT_FALLBACK_SECONDS, function()
		if thisSerial == speedUpdateSerial then
			commitSpeedText()
		end
	end)
end]]
        s = replace(s, originalOldBlock, oldBlock)
        fs.writeFile(path, s)
        print("Fixed MainHUDController speed counter in " .. world)
    else
        print("MainHUDController speed counter already fixed in " .. world)
    end
end

-- 2. Config.luau: Candy treadmill in World1 should require Rebirths (3), not GamePass
do
    local path = "audit/merged/World1/ReplicatedStorage/Shared/Config.luau"
    local s = fs.readFile(path)
    local oldCandy = [[	Candy = {
		BaseGain = 5,
		GamePassId = 1941090466, -- Valentine treadmill: same pass as Needoh (owner-confirmed); pass-only unlock like Admin/Hacker
		PopupColor = Color3.fromRGB(255, 92, 202),
		PopupBurstCount = 5,
		DisplayText = "x5 Speed",
	},]]
    local newCandy = [[	Candy = {
		BaseGain = 5,
		RequiredRebirths = 3,
		PopupColor = Color3.fromRGB(255, 92, 202),
		PopupBurstCount = 5,
		DisplayText = "x5 Speed",
	},]]
    s = replace(s, oldCandy, newCandy)
    fs.writeFile(path, s)
    print("Fixed World1 Candy treadmill profile in Config.luau (now 3 Rebirths, no gamepass)")
end

-- 3. TreadmillTraining.luau: Do not register container model "Admin" as a treadmill when it has child treadmills (World2 & World1)
for _, world in {"World1", "World2"} do
    local path = "audit/merged/" .. world .. "/ServerScriptService/Progression/TreadmillTraining.luau"
    local s = fs.readFile(path)

    local oldReg = [[		local namedGain = Config.TreadmillBaseGains[descendant.Name]
		if namedGain then
			if registerIfTreadmill(tracked, descendant, descendant.Name, namedGain) then
				foundByName[descendant.Name] = true
			end
		end]]

    local newReg = [[		local namedGain = Config.TreadmillBaseGains[descendant.Name]
		if namedGain then
			-- If descendant is a container named "Admin" that contains other treadmill models, do NOT register the container
			local isContainer = false
			if descendant:IsA("Model") and descendant.Name == "Admin" then
				for _, child in ipairs(descendant:GetChildren()) do
					if child:IsA("Model") and (Config.TreadmillBaseGains[child.Name] or child:FindFirstChild("Treadmil", true)) then
						isContainer = true
						break
					end
				end
			end
			if not isContainer then
				if registerIfTreadmill(tracked, descendant, descendant.Name, namedGain) then
					foundByName[descendant.Name] = true
				end
			end
		end

		-- Special check for inner Admin treadmill inside container
		if descendant:IsA("Model") and descendant.Name == "Model" and descendant.Parent and descendant.Parent.Name == "Admin" and descendant:FindFirstChild("Treadmil", true) then
			local adminGain = Config.TreadmillBaseGains["Admin"] or 100
			if registerIfTreadmill(tracked, descendant, "Admin", adminGain) then
				foundByName["Admin"] = true
			end
		end]]

    s = replace(s, oldReg, newReg)
    fs.writeFile(path, s)
    print("Fixed TreadmillTraining.luau container registration in " .. world)
end

-- 4. TeleportSystem.luau: Use _G.SpeedsterSpendWins to properly deduct wins in DataService
for _, world in {"World1", "World2"} do
    local path = "audit/merged/" .. world .. "/ServerScriptService/Worlds/TeleportSystem.luau"
    local s = fs.readFile(path)

    local oldTeleport = [[    local canTeleport, reason = StageTeleportService.TeleportPlayer(player, stage)
    if not canTeleport then
        sendUpdate(player, reason or "Stage is not ready", false, stage)
        return
    end

    if cost > 0 then
        winsValue.Value = wins - cost
        if _G.SpeedsterSavePlayer then
            task.defer(_G.SpeedsterSavePlayer, player, "stage_teleport_wins")
        end
    end

    sendUpdate(player, "Teleported to Stage " .. tostring(stage), true, stage)]]

    local newTeleport = [[    if cost > 0 then
        if type(_G.SpeedsterSpendWins) == "function" then
            local spent = _G.SpeedsterSpendWins(player, cost)
            if not spent then
                sendUpdate(player, "Not Enough Wins (Need " .. tostring(cost) .. " Wins)", false, stage)
                return
            end
        else
            winsValue.Value = math.max(0, wins - cost)
            if _G.SpeedsterSavePlayer then
                task.defer(_G.SpeedsterSavePlayer, player, "stage_teleport_wins")
            end
        end
    end

    local canTeleport, reason = StageTeleportService.TeleportPlayer(player, stage)
    if not canTeleport then
        -- Refund if teleport fails
        if cost > 0 and type(_G.SpeedsterAddWins) == "function" then
            _G.SpeedsterAddWins(player, cost)
        end
        sendUpdate(player, reason or "Stage is not ready", false, stage)
        return
    end

    sendUpdate(player, "Teleported to Stage " .. tostring(stage), true, stage)]]

    s = replace(s, oldTeleport, newTeleport)
    fs.writeFile(path, s)
    print("Fixed TeleportSystem.luau wins reduction in " .. world)
end

-- 5. Stage Recommended Levels in World 2 (World2StageSystem.luau)
do
    local path = "audit/merged/World2/ServerScriptService/Worlds/World2StageSystem.luau"
    local s = fs.readFile(path)

    local oldLabel = [[	local gui = Instance.new("SurfaceGui")
	gui.Name = "FrontApproachStageText"
	gui.Adornee = board
	gui.Face = Enum.NormalId.Back
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.MaxDistance = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 8
	gui.Parent = board

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
	label.Parent = gui

	local constraint = Instance.new("UITextSizeConstraint")
	constraint.Name = "HugeWorldTextConstraint"
	constraint.MinTextSize = 1
	constraint.MaxTextSize = 100
	constraint.Parent = label

	local outline = Instance.new("UIStroke")
	outline.Name = "ThickBlackOutline"
	outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	outline.Color = Color3.fromRGB(0, 0, 0)
	outline.Thickness = 8
	outline.Transparency = 0
	outline.Parent = label]]

    local newLabel = [[	local recLevels = {
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
	end]]

    s = replace(s, oldLabel, newLabel)
    fs.writeFile(path, s)
    print("Fixed World2StageSystem stage recommended levels (double-sided)")
end

-- 6. Stage Recommended Levels in World 1 (NewWorld1StagePresentation.luau)
do
    local path = "audit/merged/World1/ServerScriptService/Gameplay/NewWorld1StagePresentation.luau"
    local s = fs.readFile(path)

    local oldSurface = [[	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Name = "FrontApproachStageText"
	surfaceGui.Adornee = board
	surfaceGui.Face = Enum.NormalId.Back
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
	addOutline(recommendedLabel, 6)]]

    local newSurface = [[	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
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
	end]]

    s = replace(s, oldSurface, newSurface)
    fs.writeFile(path, s)
    print("Fixed NewWorld1StagePresentation stage recommended levels (double-sided)")
end

-- 7. Win pads double-dipping fix in NewWorld1ManualStagePads.luau
do
    local path = "audit/merged/World1/ServerScriptService/Gameplay/NewWorld1ManualStagePads.luau"
    local s = fs.readFile(path)

    local oldFinal = [[			local finalReward = isDouble and reward * DOUBLE_WINS_MULTIPLIER or reward
			if not awardWins(player, finalReward) then]]
    local newFinal = [[			-- Avoid double-multiplying (SpeedsterAddWins already applies the 2x PermanentWinsMultiplier)
			local finalReward = isDouble and reward or reward
			if not awardWins(player, finalReward) then]]

    s = replace(s, oldFinal, newFinal)

    local oldStage11 = [[			if isFinal then
				MovementGuard.RecordFinalClaim(player)
				player:SetAttribute("NewWorld1FinalWinStageClaimed", true)
			end]]
    local newStage11 = [[			if isFinal or stage >= 11 then
				MovementGuard.RecordFinalClaim(player)
				player:SetAttribute("NewWorld1FinalWinStageClaimed", true)
			end]]
    s = replace(s, oldStage11, newStage11)

    fs.writeFile(path, s)
    print("Fixed World1 Win Pads double-dipping and stage 11 repeat spam")
end

-- 8. Win pads double-dipping fix in World2ManualStagePads.luau
do
    local path = "audit/merged/World2/ServerScriptService/Gameplay/World2ManualStagePads.luau"
    local s = fs.readFile(path)

    local oldReward = [[		local reward = isDouble and (baseReward * DOUBLE_WINS_MULTIPLIER) or baseReward
		if not awardWins(player, reward) then]]
    local newReward = [[		-- Avoid double-multiplying (SpeedsterAddWins already applies the 2x PermanentWinsMultiplier)
		local reward = isDouble and baseReward or baseReward
		if not awardWins(player, reward) then]]

    s = replace(s, oldReward, newReward)
    fs.writeFile(path, s)
    print("Fixed World2 Win Pads double-dipping")
end

-- 9. TreadmillOverheadLabels fallback deck when collision fix hasn't finished
for _, world in {"World1", "World2"} do
    local path = (world == "World1")
        and "audit/merged/World1/ServerScriptService/Progression/TreadmillOverheadLabels.luau"
        or "audit/merged/World2/ServerScriptService/Progression/World2TreadmillOverheadLabels.luau"
    local s = fs.readFile(path)

    local oldFindDeck = [[	local wantedSource = getPhysicalTreadmill(treadmill):GetFullName()
	for _, treadmillFolder in ipairs(collisionFolder:GetChildren()) do
		if treadmillFolder:GetAttribute("SourceTreadmill") == wantedSource then
			local deck = treadmillFolder:FindFirstChild("SmoothDeck")
			if deck and deck:IsA("BasePart") then
				return deck
			end
		end
	end
	return nil]]

    local newFindDeck = [[	local wantedSource = getPhysicalTreadmill(treadmill):GetFullName()
	for _, treadmillFolder in ipairs(collisionFolder:GetChildren()) do
		if treadmillFolder:GetAttribute("SourceTreadmill") == wantedSource then
			local deck = treadmillFolder:FindFirstChild("SmoothDeck")
			if deck and deck:IsA("BasePart") then
				return deck
			end
		end
	end
	-- Fallback: return physical treadmill primary part or child part so overhead labels always render
	local physical = getPhysicalTreadmill(treadmill)
	if physical:IsA("BasePart") then return physical end
	if physical:IsA("Model") then
		local primary = physical.PrimaryPart or physical:FindFirstChildWhichIsA("BasePart", true)
		if primary then return primary end
	end
	return nil]]

    s = replace(s, oldFindDeck, newFindDeck)

    fs.writeFile(path, s)
    print("Fixed TreadmillOverheadLabels fallback deck in " .. world)
end

print("ALL GAMEPLAY FIXES SUCCESSFULLY APPLIED!")
