-- V306JQ World 2 Speed Force client.
-- Hold Space (or the existing mobile Jump button) for 0.37 seconds. The server
-- validates the hold and target. This client renders the entire cinematic in a
-- local ViewportFrame, so no cutscene geometry/effects replicate to other users.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
if Config.IsWorld2Place ~= true or Config.AbilitySpeedForceEnabled ~= true then
	return
end

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SpeedForceAction = Remotes:WaitForChild("SpeedForceAction")
local SpeedForceCutscene = Remotes:WaitForChild("SpeedForceCutscene")

local HOLD_SECONDS = math.max(0.25, tonumber(Config.AbilitySpeedForceHoldSeconds) or 0.37)
local RUN_SECONDS = math.max(0.6, tonumber(Config.AbilitySpeedForceCutsceneRunSeconds) or 2.10)
local POSE_SECONDS = math.max(0.45, tonumber(Config.AbilitySpeedForceCutscenePoseSeconds) or 1.35)
local RUN_ANIMATION_ID = tostring(Config.AbilitySpeedForceRunAnimationId or "rbxassetid://124536617516408")
local POSE_ANIMATION_ID = tostring(Config.AbilitySpeedForcePoseAnimationId or "rbxassetid://83598519628860")

local holdActive = false
local holdSerial = 0
local cutsceneActive = false
local activeToken = ""
local pendingClone = nil
local cutsceneGui = nil
local runningTweens = {}
local currentTracks = {}

local function canUse()
	return player:GetAttribute("SpeedForceAbilityOwned") == true
		and player:GetAttribute("SpeedForceAbilityEquipped") == true
		and player:GetAttribute("EquippedAbility") == "SpeedForce"
		and player:GetAttribute("SpeedForceTransitionActive") ~= true
end

local function stopTracks()
	for _, track in ipairs(currentTracks) do
		pcall(function() track:Stop(0.05) end)
	end
	table.clear(currentTracks)
end

local function cancelTweens()
	for _, tween in ipairs(runningTweens) do
		pcall(function() tween:Cancel() end)
	end
	table.clear(runningTweens)
end

local function destroyPendingClone()
	if pendingClone then
		pendingClone:Destroy()
		pendingClone = nil
	end
end

local function cleanupCutscene()
	cutsceneActive = false
	activeToken = ""
	stopTracks()
	cancelTweens()
	destroyPendingClone()
	if cutsceneGui then
		cutsceneGui:Destroy()
		cutsceneGui = nil
	end
end

local function cloneCharacterForCutscene()
	destroyPendingClone()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 then return nil end

	local oldArchivable = character.Archivable
	character.Archivable = true
	local ok, clone = pcall(function() return character:Clone() end)
	character.Archivable = oldArchivable
	if not ok or not clone then return nil end
	clone.Name = "SpeedForceCutsceneCharacter"

	for _, object in ipairs(clone:GetDescendants()) do
		if object:IsA("Script") or object:IsA("LocalScript") or object:IsA("ModuleScript") then
			object:Destroy()
		elseif object:IsA("Sound") then
			object:Destroy()
		elseif object:IsA("ParticleEmitter") or object:IsA("Beam") or object:IsA("Trail") then
			object.Enabled = false
		elseif object:IsA("BasePart") then
			object.CanCollide = false
			object.CanTouch = false
			object.CanQuery = false
			object.Massless = true
		end
	end
	local cloneRoot = clone:FindFirstChild("HumanoidRootPart")
	if cloneRoot then
		cloneRoot.Anchored = true
		cloneRoot.Transparency = 1
	end
	pendingClone = clone
	return clone
end

local function addTween(tween)
	table.insert(runningTweens, tween)
	tween:Play()
	return tween
end

local function createLine(parent, x, y, width, thickness, transparency, z)
	local line = Instance.new("Frame")
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	line.Position = UDim2.fromScale(x, y)
	line.Size = UDim2.new(width, 0, 0, thickness)
	line.BackgroundColor3 = Color3.fromRGB(205, 250, 255)
	line.BackgroundTransparency = transparency
	line.BorderSizePixel = 0
	line.ZIndex = z or 4
	line.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = line
	return line
end

local function loadTrack(clone, animationId, name, looped, speed)
	local humanoid = clone and clone:FindFirstChildOfClass("Humanoid")
	if not humanoid then return nil end
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = humanoid
	local animation = Instance.new("Animation")
	animation.Name = name
	animation.AnimationId = animationId
	local ok, track = pcall(function() return animator:LoadAnimation(animation) end)
	animation:Destroy()
	if not ok or not track then return nil end
	track.Name = name
	track.Priority = Enum.AnimationPriority.Action4
	track.Looped = looped == true
	track:Play(0.08, 1, speed or 1)
	table.insert(currentTracks, track)
	return track
end

local function createCutsceneGui(clone)
	local playerGui = player:WaitForChild("PlayerGui")
	local old = playerGui:FindFirstChild("SpeedForceCutsceneGui")
	if old then old:Destroy() end

	local gui = Instance.new("ScreenGui")
	gui.Name = "SpeedForceCutsceneGui"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10000
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui
	cutsceneGui = gui

	local background = Instance.new("Frame")
	background.Name = "LightningBlueBackground"
	background.Size = UDim2.fromScale(1, 1)
	background.BackgroundColor3 = Color3.fromRGB(1, 26, 47)
	background.BorderSizePixel = 0
	background.ZIndex = 1
	background.Parent = gui
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 10, 28)),
		ColorSequenceKeypoint.new(0.42, Color3.fromRGB(0, 92, 132)),
		ColorSequenceKeypoint.new(0.68, Color3.fromRGB(0, 45, 84)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 6, 18)),
	})
	gradient.Rotation = 8
	gradient.Parent = background

	-- Fast horizontal cyan/white streaks, matching the supplied clip's tunnel feel.
	local seeded = Random.new(306)
	for i = 1, 18 do
		local y = seeded:NextNumber(0.05, 0.95)
		local width = seeded:NextNumber(0.12, 0.55)
		local line = createLine(background, seeded:NextNumber(-0.25, 0.9), y, width, seeded:NextInteger(2, 8), seeded:NextNumber(0.12, 0.68), 3)
		local duration = seeded:NextNumber(0.22, 0.52)
		addTween(TweenService:Create(line, TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), {
			Position = UDim2.fromScale(1.35, y),
		}))
	end

	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "RunnerViewport"
	viewport.AnchorPoint = Vector2.new(0.5, 0.5)
	viewport.Position = UDim2.fromScale(0.52, 0.53)
	viewport.Size = UDim2.fromScale(0.72, 0.88)
	viewport.BackgroundTransparency = 1
	viewport.Ambient = Color3.fromRGB(65, 205, 255)
	viewport.LightColor = Color3.fromRGB(220, 252, 255)
	viewport.LightDirection = Vector3.new(-1, -0.25, -1)
	viewport.ZIndex = 8
	viewport.Parent = gui

	local world = Instance.new("WorldModel")
	world.Name = "LocalCutsceneWorld"
	world.Parent = viewport
	clone.Parent = world
	pendingClone = nil

	local camera = Instance.new("Camera")
	camera.Name = "CutsceneCamera"
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	clone:PivotTo(CFrame.new(0, -2.5, 0) * CFrame.Angles(0, math.rad(-90), 0))
	local _, bounds = clone:GetBoundingBox()
	-- V306JQ: keep the lower framing the user preferred, but pull the camera
	-- farther back so the runner has more breathing room in the frame.
	local distance = math.clamp(math.max(bounds.Y * 1.45, bounds.X * 1.20, 9.8), 9.8, 18)
	local cameraTarget = Vector3.new(0.15, -1.25, 0)
	camera.CFrame = CFrame.lookAt(Vector3.new(0.15, -0.55, distance), cameraTarget)

	local highlight = Instance.new("Highlight")
	highlight.Name = "SpeedForceBlueGlow"
	highlight.Adornee = clone
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.FillColor = Color3.fromRGB(74, 221, 255)
	highlight.FillTransparency = 0.58
	highlight.OutlineColor = Color3.fromRGB(225, 253, 255)
	highlight.OutlineTransparency = 0.08
	highlight.Parent = clone

	local flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.ZIndex = 50
	flash.Parent = gui

	return gui, viewport, clone, flash, camera, distance
end

local function flashScreen(flash, peakTransparency, inTime, outTime)
	if not flash or not flash.Parent then return end
	local t1 = addTween(TweenService:Create(flash, TweenInfo.new(inTime or 0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = peakTransparency or 0.08,
	}))
	t1.Completed:Wait()
	if flash.Parent then
		local t2 = addTween(TweenService:Create(flash, TweenInfo.new(outTime or 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			BackgroundTransparency = 1,
		}))
		t2.Completed:Wait()
	end
end

local function runCutscene(token)
	if cutsceneActive then return end
	cutsceneActive = true
	activeToken = token
	local clone = pendingClone or cloneCharacterForCutscene()
	if not clone then
		-- Background-only fallback still completes safely if Roblox refuses to clone
		-- the avatar during a respawn edge case.
		clone = Instance.new("Model")
		clone.Name = "SpeedForceCutsceneCharacterFallback"
		pendingClone = clone
	end
	local gui, viewport, runner, flash, cutsceneCamera, cameraDistance = createCutsceneGui(clone)

	-- V306JQ: restore the original fast runner playback. The user's correction was
	-- to keep this fast and then visibly play the separate Wally West animation.
	local runTrack = loadTrack(runner, RUN_ANIMATION_ID, "SpeedForceFullSpeedRun", true, 2.35)
	local runnerWorld = viewport:FindFirstChild("LocalCutsceneWorld")
	-- Slight side drift makes the avatar feel like it is accelerating through the
	-- tunnel without moving any real Workspace object.
	addTween(TweenService:Create(viewport, TweenInfo.new(RUN_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = UDim2.fromScale(0.58, 0.51),
	}))

	task.wait(math.max(0.05, RUN_SECONDS - 0.14))
	if not cutsceneActive or activeToken ~= token then return end
	flashScreen(flash, 0.04, 0.07, 0.13)
	if runTrack then pcall(function() runTrack:Stop(0.08) end) end

	local poseTrack = loadTrack(runner, POSE_ANIMATION_ID, "SpeedForceWallyPose", true, 1)
	-- V306JQ: keep the actual Wally West animation clearly visible without the
	-- aggressive close-up from V306JP. The camera remains low but only eases in
	-- slightly for this section.
	if cutsceneCamera and cutsceneCamera.Parent then
		local poseDistance = math.max(9.0, (cameraDistance or 11) * 0.92)
		addTween(TweenService:Create(cutsceneCamera, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = CFrame.lookAt(Vector3.new(0.1, -0.75, poseDistance), Vector3.new(0.1, -1.30, 0)),
		}))
	end
	-- Match the reference's bright, almost white-blue second half.
	local background = gui:FindFirstChild("LightningBlueBackground")
	if background then
		addTween(TweenService:Create(background, TweenInfo.new(0.25), {
			BackgroundColor3 = Color3.fromRGB(0, 75, 110),
		}))
	end
	task.wait(POSE_SECONDS)
	if not cutsceneActive or activeToken ~= token then return end

	-- Hold the final white flash until the server confirms the authoritative
	-- teleport; this prevents a single-frame glimpse of the hidden real character.
	local finalTween = addTween(TweenService:Create(flash, TweenInfo.new(0.10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0,
	}))
	finalTween.Completed:Wait()
	if cutsceneActive and activeToken == token then
		SpeedForceAction:FireServer("Finish", token)
	end
end

local function beginHold()
	if holdActive or cutsceneActive or not canUse() then return end
	holdActive = true
	holdSerial += 1
	local mySerial = holdSerial
	SpeedForceAction:FireServer("HoldBegin")
	task.delay(HOLD_SECONDS, function()
		if not holdActive or mySerial ~= holdSerial or cutsceneActive or not canUse() then return end
		-- Capture the visible avatar before the server hides/moves the real one.
		cloneCharacterForCutscene()
		SpeedForceAction:FireServer("Activate")
	end)
end

local function endHold()
	if not holdActive then return end
	holdActive = false
	holdSerial += 1
	SpeedForceAction:FireServer("HoldCancel")
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then beginHold() end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then endHold() end
end)

-- Use Roblox's existing mobile Jump button; no extra HUD button is created.
local boundJumpButtons = setmetatable({}, { __mode = "k" })
local function bindMobileJumpButton(instance)
	if not UserInputService.TouchEnabled or boundJumpButtons[instance] then return end
	if not instance:IsA("GuiButton") or instance.Name ~= "JumpButton" then return end
	if not instance:FindFirstAncestor("TouchGui") then return end
	boundJumpButtons[instance] = true
	instance.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then beginHold() end
	end)
	instance.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then endHold() end
	end)
end
if UserInputService.TouchEnabled then
	local playerGui = player:WaitForChild("PlayerGui")
	for _, descendant in ipairs(playerGui:GetDescendants()) do bindMobileJumpButton(descendant) end
	playerGui.DescendantAdded:Connect(bindMobileJumpButton)
end

SpeedForceCutscene.OnClientEvent:Connect(function(action, token, okOrTarget, detail)
	action = tostring(action or "")
	if action == "Start" then
		holdActive = false
		holdSerial += 1
		task.spawn(runCutscene, tostring(token or ""))
	elseif action == "Denied" then
		holdActive = false
		holdSerial += 1
		destroyPendingClone()
	elseif action == "End" then
		if tostring(token or "") ~= activeToken then return end
		local gui = cutsceneGui
		local flash = gui and gui:FindFirstChild("Flash")
		if flash then
			local tween = TweenService:Create(flash, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				BackgroundTransparency = 1,
			})
			tween:Play()
			tween.Completed:Wait()
		end
		cleanupCutscene()
	end
end)

local function syncAbilityState()
	if not canUse() and holdActive then endHold() end
	if player:GetAttribute("EquippedAbility") ~= "SpeedForce" then destroyPendingClone() end
end
player:GetAttributeChangedSignal("SpeedForceAbilityOwned"):Connect(syncAbilityState)
player:GetAttributeChangedSignal("SpeedForceAbilityEquipped"):Connect(syncAbilityState)
player:GetAttributeChangedSignal("EquippedAbility"):Connect(syncAbilityState)
player.CharacterAdded:Connect(function()
	holdActive = false
	holdSerial += 1
	cleanupCutscene()
end)

print("[World2SpeedForce] V306JQ client active | hold 0.37s | fast runner + Wally animation | +3.7s cinematic | pulled-back low camera | PC + mobile Jump")
