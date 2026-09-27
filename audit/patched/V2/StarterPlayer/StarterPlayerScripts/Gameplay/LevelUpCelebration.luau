                                      
                                                                                
                                                                                  
                                                                                         

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")
local TEMPLATE_NAME = "LevelUpConfettiTemplate"
local LEVEL_UP_SOUND_ID = "rbxassetid://3120909354"
local BURST_PARTICLE_COUNT = 48
local LEVEL_UP_SOUND_VOLUME = 0.75
local HEAD_LOWER_EDGE_INSET = 0.08
local BANNER_LIFETIME = 1.35

local lastLevel = nil
local celebrating = false

local bannerGui
local bannerRoot
local titleLabel
local leftEmoji
local rightEmoji
local levelLabel
local titleTextConstraint
local levelTextConstraint
local phonePopupLayout = false
local currentAnimationId = 0

local function playLevelUpSound()
	local sound = Instance.new("Sound")
	sound.Name = "LevelUpCelebrationSound"
	sound.SoundId = LEVEL_UP_SOUND_ID
	sound.Volume = LEVEL_UP_SOUND_VOLUME
	sound.PlaybackSpeed = 1
	sound.Parent = SoundService

	local played = pcall(function()
		SoundService:PlayLocalSound(sound)
	end)
	if not played then
		pcall(function()
			sound:Play()
		end)
	end

	Debris:AddItem(sound, 10)
end

local function preparePart(part)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Transparency = 1
end

local function getEmitterLifetimeMax(instance)
	local maximum = 0
	if instance:IsA("ParticleEmitter") then
		maximum = math.max(maximum, instance.Lifetime.Max)
	end
	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("ParticleEmitter") then
			maximum = math.max(maximum, descendant.Lifetime.Max)
		end
	end
	return maximum
end

local function emitAll(instance)
	local emitted = false
	if instance:IsA("ParticleEmitter") then
		instance.Enabled = false
		instance:Emit(BURST_PARTICLE_COUNT)
		emitted = true
	end
	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("ParticleEmitter") then
			descendant.Enabled = false
			descendant:Emit(BURST_PARTICLE_COUNT)
			emitted = true
		end
	end
	return emitted
end

local function spawnConfetti()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local head = character and character:FindFirstChild("Head")
	if not root or not root:IsA("BasePart") then
		return
	end

	local template = ReplicatedStorage:FindFirstChild(TEMPLATE_NAME)
	if not template then
		warn("[LevelUpCelebration] Missing ReplicatedStorage." .. TEMPLATE_NAME .. "; import confetti.rbxm into ServerStorage as 'Confetti'.")
		return
	end

	local clone = template:Clone()
	clone.Name = "LevelUpConfetti_Local"
	clone.Parent = Workspace

	local targetPosition
	if head and head:IsA("BasePart") then
		local lowerHeadOffset = math.max(0, head.Size.Y * 0.5 - HEAD_LOWER_EDGE_INSET)
		targetPosition = head.Position - head.CFrame.UpVector * lowerHeadOffset
	else
		targetPosition = root.Position + Vector3.new(0, 2.1, 0)
	end
	local targetCFrame = CFrame.new(targetPosition)
	if clone:IsA("BasePart") then
		local rotation = clone.CFrame.Rotation
		preparePart(clone)
		clone.CFrame = targetCFrame * rotation
	elseif clone:IsA("Model") then
		for _, descendant in ipairs(clone:GetDescendants()) do
			if descendant:IsA("BasePart") then
				preparePart(descendant)
			end
		end
		pcall(function()
			clone:PivotTo(targetCFrame)
		end)
	else
		for _, descendant in ipairs(clone:GetDescendants()) do
			if descendant:IsA("BasePart") then
				preparePart(descendant)
				descendant.CFrame = targetCFrame * descendant.CFrame.Rotation
			end
		end
	end

	local maxLifetime = getEmitterLifetimeMax(clone)
	if not emitAll(clone) then
		clone:Destroy()
		warn("[LevelUpCelebration] LevelUpConfettiTemplate contains no ParticleEmitter.")
		return
	end

	Debris:AddItem(clone, math.max(2.5, maxLifetime + 1.5))
end

local function addOutline(label, thickness, color)
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Thickness = thickness
	stroke.Color = color
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = label
	return stroke
end

local function ensureBannerGui()
	if bannerGui and bannerGui.Parent then
		return
	end

	bannerGui = Instance.new("ScreenGui")
	bannerGui.Name = "LevelUpBanner"
	bannerGui.ResetOnSpawn = false
	bannerGui.DisplayOrder = 90
	bannerGui.IgnoreGuiInset = true
	bannerGui.Parent = PlayerGui

	bannerRoot = Instance.new("Frame")
	bannerRoot.Name = "Root"
	bannerRoot.BackgroundTransparency = 1
	bannerRoot.AnchorPoint = Vector2.new(0.5, 0.5)
	bannerRoot.Position = UDim2.fromScale(0.5, 0.28)
	bannerRoot.Size = UDim2.fromOffset(860, 250)
	bannerRoot.Visible = false
	bannerRoot.Parent = bannerGui

	titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.BackgroundTransparency = 1
	titleLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	titleLabel.Position = UDim2.fromScale(0.5, 0.36)
	titleLabel.Size = UDim2.fromOffset(620, 92)
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.Text = "LEVEL UP!"
	titleLabel.TextColor3 = Color3.fromRGB(255, 211, 33)
	titleLabel.TextScaled = true
	titleLabel.ZIndex = 2
	titleLabel.Parent = bannerRoot
	addOutline(titleLabel, 4, Color3.fromRGB(0, 0, 0))

	titleTextConstraint = Instance.new("UITextSizeConstraint")
	titleTextConstraint.Name = "LevelUpTitleDeviceSize"
	titleTextConstraint.MinTextSize = 1
	titleTextConstraint.MaxTextSize = 1000
	titleTextConstraint.Parent = titleLabel

	leftEmoji = Instance.new("TextLabel")
	leftEmoji.Name = "LeftEmoji"
	leftEmoji.BackgroundTransparency = 1
	leftEmoji.AnchorPoint = Vector2.new(0.5, 0.5)
	leftEmoji.Position = UDim2.fromScale(0.17, 0.36)
	leftEmoji.Size = UDim2.fromOffset(90, 90)
	leftEmoji.Font = Enum.Font.GothamBlack
	leftEmoji.Text = "🎉"
	leftEmoji.TextScaled = true
	leftEmoji.Rotation = -10
	leftEmoji.ZIndex = 2
	leftEmoji.Parent = bannerRoot
	addOutline(leftEmoji, 2, Color3.fromRGB(255, 255, 255))

	rightEmoji = Instance.new("TextLabel")
	rightEmoji.Name = "RightEmoji"
	rightEmoji.BackgroundTransparency = 1
	rightEmoji.AnchorPoint = Vector2.new(0.5, 0.5)
	rightEmoji.Position = UDim2.fromScale(0.83, 0.36)
	rightEmoji.Size = UDim2.fromOffset(90, 90)
	rightEmoji.Font = Enum.Font.GothamBlack
	rightEmoji.Text = "🎉"
	rightEmoji.TextScaled = true
	rightEmoji.Rotation = 10
	rightEmoji.ZIndex = 2
	rightEmoji.Parent = bannerRoot
	addOutline(rightEmoji, 2, Color3.fromRGB(255, 255, 255))

	levelLabel = Instance.new("TextLabel")
	levelLabel.Name = "Level"
	levelLabel.BackgroundTransparency = 1
	levelLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	levelLabel.Position = UDim2.fromScale(0.5, 0.68)
	levelLabel.Size = UDim2.fromOffset(420, 74)
	levelLabel.Font = Enum.Font.GothamBlack
	levelLabel.Text = "Level 1"
	levelLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	levelLabel.TextScaled = true
	levelLabel.ZIndex = 2
	levelLabel.Parent = bannerRoot
	addOutline(levelLabel, 4, Color3.fromRGB(0, 0, 0))

	levelTextConstraint = Instance.new("UITextSizeConstraint")
	levelTextConstraint.Name = "LevelUpNumberDeviceSize"
	levelTextConstraint.MinTextSize = 1
	levelTextConstraint.MaxTextSize = 1000
	levelTextConstraint.Parent = levelLabel
end

local function applyLevelUpTextDeviceSize()
	                                                              
	                                                                      
	                                                                           
	                                                                          
	                                                                     
	if not titleTextConstraint or not levelTextConstraint then
		return
	end

	local camera = Workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
	phonePopupLayout = false
	if UserInputService.TouchEnabled then
		local isTablet = math.min(viewport.X, viewport.Y) >= 600
		if isTablet then
			titleTextConstraint.MaxTextSize = 80
			levelTextConstraint.MaxTextSize = 64
			                                                    
			levelLabel.Position = UDim2.fromScale(0.5, 0.68)
			leftEmoji.Size = UDim2.fromOffset(90, 90)
			rightEmoji.Size = UDim2.fromOffset(90, 90)
		else
			phonePopupLayout = true
			titleTextConstraint.MaxTextSize = 37
			levelTextConstraint.MaxTextSize = 29
			                                                           
			levelLabel.Position = UDim2.fromScale(0.5, 0.53)
			                                                                  
			                                                                      
			leftEmoji.Size = UDim2.fromOffset(44, 44)
			rightEmoji.Size = UDim2.fromOffset(44, 44)
		end
	else
		titleTextConstraint.MaxTextSize = 1000
		levelTextConstraint.MaxTextSize = 1000
		                                                
		levelLabel.Position = UDim2.fromScale(0.5, 0.68)
		leftEmoji.Size = UDim2.fromOffset(90, 90)
		rightEmoji.Size = UDim2.fromOffset(90, 90)
	end
end

local function tweenTransparency(label, textT, strokeT, duration)
	TweenService:Create(label, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		TextTransparency = textT,
	}):Play()
	local stroke = label:FindFirstChildOfClass("UIStroke")
	if stroke then
		TweenService:Create(stroke, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Transparency = strokeT,
		}):Play()
	end
end

local function showBanner(level)
	ensureBannerGui()
	applyLevelUpTextDeviceSize()
	currentAnimationId += 1
	local animationId = currentAnimationId

	bannerRoot.Visible = true
	bannerRoot.AnchorPoint = Vector2.new(0.5, 0.5)
	bannerRoot.Position = UDim2.fromScale(0.5, 0.29)
	bannerRoot.Size = UDim2.fromOffset(700, 205)
	bannerRoot.Rotation = 0

	titleLabel.Text = "LEVEL UP!"
	levelLabel.Text = string.format("Level %d", level)

	for _, label in ipairs({ titleLabel, levelLabel, leftEmoji, rightEmoji }) do
		label.TextTransparency = 1
		local stroke = label:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Transparency = 1
		end
	end
	leftEmoji.Rotation = -18
	rightEmoji.Rotation = 18
	if phonePopupLayout then
		leftEmoji.Position = UDim2.fromScale(0.35, 0.36)
		rightEmoji.Position = UDim2.fromScale(0.65, 0.36)
	else
		leftEmoji.Position = UDim2.fromScale(0.17, 0.36)
		rightEmoji.Position = UDim2.fromScale(0.83, 0.36)
	end

	TweenService:Create(bannerRoot, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(860, 250),
		Position = UDim2.fromScale(0.5, 0.28),
	}):Play()

	for _, label in ipairs({ titleLabel, levelLabel, leftEmoji, rightEmoji }) do
		tweenTransparency(label, 0, 0, 0.12)
	end

	local leftEmojiTarget = phonePopupLayout and UDim2.fromScale(0.33, 0.36) or UDim2.fromScale(0.15, 0.36)
	local rightEmojiTarget = phonePopupLayout and UDim2.fromScale(0.67, 0.36) or UDim2.fromScale(0.85, 0.36)
	TweenService:Create(leftEmoji, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Rotation = -8,
		Position = leftEmojiTarget,
	}):Play()
	TweenService:Create(rightEmoji, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Rotation = 8,
		Position = rightEmojiTarget,
	}):Play()

	task.delay(0.92, function()
		if currentAnimationId ~= animationId or not bannerRoot then
			return
		end
		TweenService:Create(bannerRoot, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.fromScale(0.5, 0.25),
		}):Play()
		for _, label in ipairs({ titleLabel, levelLabel, leftEmoji, rightEmoji }) do
			tweenTransparency(label, 1, 1, 0.24)
		end
	end)

	task.delay(BANNER_LIFETIME, function()
		if currentAnimationId ~= animationId or not bannerRoot then
			return
		end
		bannerRoot.Visible = false
	end)
end

local function celebrateLevelUp(level)
	if celebrating then
		return
	end
	celebrating = true
	playLevelUpSound()
	spawnConfetti()
	showBanner(level)
	task.delay(BANNER_LIFETIME + 0.1, function()
		celebrating = false
	end)
end

local function readLevel()
	local value = tonumber(player:GetAttribute("Level"))
	if not value then
		return nil
	end
	return math.max(1, math.floor(value))
end

local function onLevelChanged()
	local newLevel = readLevel()
	if not newLevel then
		return
	end

	if lastLevel == nil then
		lastLevel = newLevel
		return
	end

	if newLevel > lastLevel then
		celebrateLevelUp(newLevel)
	end
	lastLevel = newLevel
end

player:GetAttributeChangedSignal("Level"):Connect(onLevelChanged)
onLevelChanged()

print("[LevelUpCelebration] V306KAB ready | phone side confetti closer | sound volume=" .. tostring(LEVEL_UP_SOUND_VOLUME) .. " | " .. LEVEL_UP_SOUND_ID)
