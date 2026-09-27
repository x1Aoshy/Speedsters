local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local StudUi = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("StudUi"))

local playerGui = player:WaitForChild("PlayerGui")

local function removeOldHudCopies()
	for _, child in ipairs(playerGui:GetChildren()) do
		if (child.Name == "SpeedsterHUD" or child.Name == "SpeedPopupLayer") and child:GetAttribute("V125ProtectedHud") ~= true then
			child:Destroy()
		end
	end
end

removeOldHudCopies()

                                                                           
                                                                              
                                                                            
                                                                           
                                             
local POPUP_SPAWN_SOUND_ID = Config.SpeedPopupSoundId or "rbxassetid://96750121076266"
local POPUP_SPAWN_SOUND_VOLUME = Config.SpeedPopupSoundVolume or 0.37
local POPUP_SPAWN_SOUND_PLAYBACK_SPEED = Config.SpeedPopupSoundPlaybackSpeed or 1.0

if Config.IsWorld2Place ~= true then
	                                                                           
	                                                                          
	                                                                           
	local stalePopupSoundNames = {
		SpeedPopSound_ONLY = true,
		SpeedPopupSpawnSound = true,
		SpeedPopupImpactSound = true,
	}
	for _, child in ipairs(SoundService:GetChildren()) do
		if child:IsA("Sound") and stalePopupSoundNames[child.Name] then
			child:Stop()
			child:Destroy()
		end
	end
end

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local BoostState = Remotes:WaitForChild("BoostState")
local SpeedGainPopup = Remotes:WaitForChild("SpeedGainPopup")

local gui = Instance.new("ScreenGui")
gui.Name = "SpeedsterHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 42
gui:SetAttribute("V125ProtectedHud", true)
gui.Parent = playerGui

local popupLayer = Instance.new("ScreenGui")
popupLayer.Name = "SpeedPopupLayer"
popupLayer.ResetOnSpawn = false
popupLayer.IgnoreGuiInset = true
popupLayer.DisplayOrder = 50
popupLayer:SetAttribute("V125ProtectedHud", true)
popupLayer.Parent = playerGui

task.spawn(function()
	for _ = 1, 8 do
		task.wait(0.5)
		removeOldHudCopies()
	end
end)

local function addCorner(instance, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 12)
	corner.Parent = instance
	return corner
end

local boostFrame = Instance.new("Frame")
boostFrame.Name = "BoostFrame"
boostFrame.AnchorPoint = Vector2.new(0.5, 1)
boostFrame.Size = UDim2.fromOffset(1080, 53)
boostFrame.Position = UDim2.new(0.5, 0, 1, -84)
boostFrame.BackgroundColor3 = Color3.fromRGB(14, 15, 25)
boostFrame.BackgroundTransparency = 0
boostFrame.BorderSizePixel = 0
boostFrame.ClipsDescendants = true
boostFrame.Parent = gui
addCorner(boostFrame, 12)

local boostFrameScale = Instance.new("UIScale")
boostFrameScale.Name = "MobileResponsiveScale"
boostFrameScale.Scale = 1
boostFrameScale.Parent = boostFrame

local boostStroke = Instance.new("UIStroke")
boostStroke.Color = Color3.fromRGB(0, 0, 0)
boostStroke.Thickness = 4
boostStroke.LineJoinMode = Enum.LineJoinMode.Round
boostStroke.Parent = boostFrame

local boostFill = Instance.new("Frame")
boostFill.Name = "BoostFill"
boostFill.Size = UDim2.fromScale(1, 1)
boostFill.BackgroundColor3 = Color3.fromRGB(255, 210, 0)
boostFill.BorderSizePixel = 0
boostFill.ZIndex = 1
boostFill.Parent = boostFrame
addCorner(boostFill, 12)

local boostFillGradient = Instance.new("UIGradient")
boostFillGradient.Rotation = 90
boostFillGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 248, 70)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 208, 0)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 160, 0)),
})
boostFillGradient.Parent = boostFill
local boostStudSurface = StudUi.AddSurface(boostFill, 2, 12)
local boostStudGradient = boostStudSurface:FindFirstChild("StudSurfaceGradient")
if boostStudGradient then
	                                                              
	boostStudGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.52, Color3.fromRGB(255, 255, 245)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 245, 220)),
	})
end

local boostIcon = Instance.new("TextLabel")
boostIcon.Name = "BoostIcon"
boostIcon.BackgroundTransparency = 1
boostIcon.AnchorPoint = Vector2.new(0, 0.5)
boostIcon.Position = UDim2.new(0, 17, 0.5, 0)
boostIcon.Size = UDim2.fromOffset(48, 36)
boostIcon.Font = Enum.Font.GothamBlack
boostIcon.Text = "⚡"
boostIcon.TextColor3 = Color3.fromRGB(255, 255, 255)
boostIcon.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
boostIcon.TextStrokeTransparency = 0
boostIcon.TextScaled = true
boostIcon.ZIndex = 4
boostIcon.Parent = boostFrame

local boostText = Instance.new("TextLabel")
boostText.Name = "BoostText"
boostText.Size = UDim2.fromScale(1, 1)
boostText.BackgroundTransparency = 1
boostText.Font = Enum.Font.GothamBlack
boostText.Text = "100/100"
boostText.TextColor3 = Color3.fromRGB(255, 255, 255)
boostText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
boostText.TextStrokeTransparency = 0
boostText.TextScaled = true
boostText.ZIndex = 4
boostText.Parent = boostFrame

local sprintHintText = Instance.new("TextLabel")
sprintHintText.Name = "SprintHintText"
sprintHintText.AnchorPoint = Vector2.new(1, 0.5)
sprintHintText.Position = UDim2.new(1, -18, 0.5, 0)
sprintHintText.Size = UDim2.fromOffset(240, 28)
sprintHintText.BackgroundTransparency = 1
sprintHintText.Font = Enum.Font.GothamBlack
sprintHintText.Text = "Shift To Sprint"
sprintHintText.TextColor3 = Color3.fromRGB(255, 255, 255)
sprintHintText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
sprintHintText.TextStrokeTransparency = 0
sprintHintText.TextScaled = true
sprintHintText.TextXAlignment = Enum.TextXAlignment.Right
sprintHintText.ZIndex = 4
sprintHintText.Parent = boostFrame

local mobileButton = Instance.new("TextButton")
mobileButton.Name = "MobileBoostButton"
mobileButton.Size = UDim2.fromOffset(132, 58)
mobileButton.Position = UDim2.new(1, -152, 1, -148)
mobileButton.BackgroundColor3 = Color3.fromRGB(68, 160, 255)
mobileButton.BackgroundTransparency = 0.05
mobileButton.BorderSizePixel = 0
mobileButton.Font = Enum.Font.GothamBlack
mobileButton.Text = "BOOST"
mobileButton.TextColor3 = Color3.fromRGB(255, 255, 255)
mobileButton.TextSize = 15
mobileButton.Visible = UserInputService.TouchEnabled
mobileButton.Parent = gui
addCorner(mobileButton, 18)
StudUi.StyleButton(mobileButton, 18)

local mobileButtonScale = Instance.new("UIScale")
mobileButtonScale.Name = "MobileResponsiveScale"
mobileButtonScale.Scale = 1
mobileButtonScale.Parent = mobileButton

local function isCompactMobileViewport()
	local currentCamera = workspace.CurrentCamera
	local viewport = currentCamera and currentCamera.ViewportSize or Vector2.new(1920, 1080)
	return UserInputService.TouchEnabled and viewport.Y <= 700, viewport
end

local function updateMobileHudLayout()
	local _, viewport = isCompactMobileViewport()
	local fit = math.min(viewport.X / 1920, viewport.Y / 1080)

	if UserInputService.TouchEnabled then
		                                                                         
		                                                                            
		local hudScale = math.clamp(fit * 0.72, 0.25, 0.62)
		boostFrameScale.Scale = hudScale
		local centeredBottomOffset = 3 + (89 * hudScale) + 3
		boostFrame.Position = UDim2.new(0.5, 0, 1, -centeredBottomOffset)

		mobileButtonScale.Scale = math.clamp(fit * 1.12, 0.48, 0.86)
		                                                                    
		                                                                         
		mobileButton.AnchorPoint = Vector2.new(1, 0)
		mobileButton.Position = UDim2.new(1, -134, 1, -74)
	else
		                                                                        
		                                                                      
		                                                                      
		                                                    
		local hudScale = math.clamp(viewport.X / 1920, 0.62, 0.82)
		boostFrameScale.Scale = hudScale
		local centeredBottomOffset = (200 * hudScale + 4) / 2
		boostFrame.Position = UDim2.new(0.5, 0, 1, -centeredBottomOffset)

		mobileButtonScale.Scale = 1
		mobileButton.AnchorPoint = Vector2.new(0, 0)
		mobileButton.Position = UDim2.new(1, -152, 1, -148)
	end
end

updateMobileHudLayout()

if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateMobileHudLayout)
end

local boostHeld = false
local legacyTrailConnection = nil
local legacyTrailCharacter = nil

local function setBoosting(value)
	value = value == true

	if boostHeld == value then
		return
	end

	boostHeld = value

	                                                                     
	BoostState:FireServer(value)
end

local function formatGain(amount)
	amount = tonumber(amount) or 0

	if amount >= 1000000000000 then
		return string.format("%.2fT", amount / 1000000000000)
	elseif amount >= 1000000000 then
		return string.format("%.2fB", amount / 1000000000)
	elseif amount >= 1000000 then
		return string.format("%.2fM", amount / 1000000)
	elseif amount >= 1000 then
		return string.format("%.2fK", amount / 1000)
	else
		return tostring(math.floor(amount))
	end
end

local function addStroke(label, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.Thickness = thickness or 4
	stroke.Transparency = 0
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = label
	return stroke
end


local function getPopupSoundPlaybackSpeed(burstCount)
	burstCount = tonumber(burstCount) or 1

	if burstCount >= 18 then
		return 1.85
	elseif burstCount >= 10 then
		return 1.55
	elseif burstCount >= 6 then
		return 1.35
	elseif burstCount >= 3 then
		return 1.15
	else
		return 1.0
	end
end

local function playImmediateOneShotSound(name, soundId, volume, playbackSpeed)
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = soundId
	sound.Volume = volume
	sound.PlaybackSpeed = playbackSpeed
	sound.Looped = false
	sound.Parent = SoundService

	sound:Play()
	Debris:AddItem(sound, 4)
end

local function playPopSound(playbackSpeed)
	local resolvedPlaybackSpeed = tonumber(playbackSpeed) or POPUP_SPAWN_SOUND_PLAYBACK_SPEED
	playImmediateOneShotSound(
		"SpeedPopupSpawnSound",
		POPUP_SPAWN_SOUND_ID,
		POPUP_SPAWN_SOUND_VOLUME,
		resolvedPlaybackSpeed
	)
end

                                                                              
                                                 
local speedPulseSerial = 0
local activeSpeedPulseTween = nil

local function findWorld1SpeedTarget()
	local progressGui = playerGui:FindFirstChild("BottomProgressImage")
	local progressHolder = progressGui and progressGui:FindFirstChild("ProgressBarHolder")
	local targetLabel = progressHolder and progressHolder:FindFirstChild("SpeedAmountText")

	if targetLabel
		and targetLabel:IsA("GuiObject")
		and targetLabel.AbsoluteSize.X > 0
		and targetLabel.AbsoluteSize.Y > 0
	then
		return targetLabel,
			targetLabel.AbsolutePosition + (targetLabel.AbsoluteSize * 0.5),
			math.max(targetLabel.AbsoluteSize.X, progressHolder.AbsoluteSize.X)
	end

	local currentCamera = workspace.CurrentCamera
	local viewport = currentCamera and currentCamera.ViewportSize or Vector2.new(1920, 1080)
	return nil, Vector2.new(viewport.X * 0.5, viewport.Y * 0.73), viewport.X * 0.58
end

local function fireWorld1SpeedImpact(totalSpeed)
	local progressGui = playerGui:FindFirstChild("BottomProgressImage")
	local impactEvent = progressGui and progressGui:FindFirstChild("World1SpeedGainImpact")
	if impactEvent and impactEvent:IsA("BindableEvent") then
		impactEvent:Fire(totalSpeed)
	end
end

local function pulseWorld1SpeedText(targetLabel)
	if not targetLabel or not targetLabel.Parent then
		return
	end

	local pulseScale = targetLabel:FindFirstChild("V306KASSpeedGainPulseScale")
	if not pulseScale or not pulseScale:IsA("UIScale") then
		if pulseScale then
			pulseScale:Destroy()
		end
		pulseScale = Instance.new("UIScale")
		pulseScale.Name = "V306KASSpeedGainPulseScale"
		pulseScale.Scale = 1
		pulseScale.Parent = targetLabel
	end

	speedPulseSerial += 1
	local thisPulse = speedPulseSerial
	if activeSpeedPulseTween then
		activeSpeedPulseTween:Cancel()
		activeSpeedPulseTween = nil
	end

	pulseScale.Scale = math.clamp(pulseScale.Scale, 0.90, 1.10)
	task.spawn(function()
		local function playStage(info, targetScale)
			if thisPulse ~= speedPulseSerial or not pulseScale.Parent then
				return false
			end

			local tween = TweenService:Create(pulseScale, info, { Scale = targetScale })
			activeSpeedPulseTween = tween
			tween:Play()
			tween.Completed:Wait()
			return thisPulse == speedPulseSerial and pulseScale.Parent ~= nil
		end

		if not playStage(TweenInfo.new(0.055, Enum.EasingStyle.Quad, Enum.EasingDirection.In), 0.90) then
			return
		end
		if not playStage(TweenInfo.new(0.10, Enum.EasingStyle.Back, Enum.EasingDirection.Out), 1.12) then
			return
		end
		if playStage(TweenInfo.new(0.10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), 1) then
			activeSpeedPulseTween = nil
		end
	end)
end

local function getWorld1PopupTimingScale(burstCount)
	burstCount = tonumber(burstCount) or 1
	if burstCount >= 18 then
		return 0.38
	elseif burstCount >= 10 then
		return 0.48
	elseif burstCount >= 6 then
		return 0.60
	elseif burstCount >= 3 then
		return 0.76
	end
	return 1
end

local function getWorld1PopupSpawnGap(burstCount)
	burstCount = tonumber(burstCount) or 1
	if burstCount >= 18 then
		return 0.018
	elseif burstCount >= 10 then
		return 0.032
	elseif burstCount >= 6 then
		return 0.045
	elseif burstCount >= 3 then
		return 0.065
	elseif burstCount >= 2 then
		return 0.085
	end
	return 0.12
end

local function makeOneWorld1BarPopup(
	amount,
	color,
	isRunningPopup,
	totalSpeed,
	popupSoundPlaybackSpeed,
	timingScale,
	onFinished
)
	timingScale = math.clamp(tonumber(timingScale) or 1, 0.35, 1)
	local currentCamera = workspace.CurrentCamera
	local viewport = currentCamera and currentCamera.ViewportSize or Vector2.new(1920, 1080)
	local targetLabel, targetPoint, progressWidth = findWorld1SpeedTarget()
	local touchViewport = UserInputService.TouchEnabled

	local horizontalSpread = math.min(viewport.X * 0.34, progressWidth * 0.42)
	local minimumRise = math.max(52, math.min(88, viewport.Y * 0.085))
	local maximumRise = math.max(minimumRise + 36, math.min(245, viewport.Y * 0.235))
	if touchViewport then
		minimumRise *= 0.68
		maximumRise *= 0.72
	end

	local spawnX = math.clamp(
		targetPoint.X + math.random(math.floor(-horizontalSpread), math.floor(horizontalSpread)),
		48,
		viewport.X - 48
	)
	local spawnY = math.clamp(
		targetPoint.Y - math.random(math.floor(minimumRise), math.floor(maximumRise)),
		36,
		viewport.Y - 44
	)

	local holder = Instance.new("Frame")
	local finished = false
	local function finishPopup()
		if finished then
			return
		end
		finished = true
		if holder.Parent then
			holder:Destroy()
		end
		if onFinished then
			task.defer(onFinished)
		end
	end

	holder.Name = isRunningPopup and "RunningSpeedPopupToBar" or "TreadmillSpeedPopupToBar"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromOffset(spawnX, spawnY)
	holder.Size = isRunningPopup and UDim2.fromOffset(132, 38) or UDim2.fromOffset(154, 43)
	holder.Rotation = math.random(-6, 6)
	holder.ZIndex = 2
	holder.Parent = popupLayer
	                                              
	playPopSound(popupSoundPlaybackSpeed)

	local text = Instance.new("TextLabel")
	text.Name = "GainText"
	text.BackgroundTransparency = 1
	text.Position = UDim2.fromScale(0, 0)
	text.Size = UDim2.fromScale(0.78, 1)
	text.Font = Enum.Font.GothamBlack
	text.Text = "+" .. formatGain(amount)
	text.TextColor3 = Color3.fromRGB(255, 255, 255)
	text.TextScaled = true
	text.TextXAlignment = Enum.TextXAlignment.Right
	text.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	text.TextStrokeTransparency = 0
	text.ZIndex = 3
	text.Parent = holder
	local textStroke = addStroke(text, isRunningPopup and 2 or 2.5)

	local shoe = Instance.new("TextLabel")
	shoe.Name = "ShoeIcon"
	shoe.BackgroundTransparency = 1
	shoe.Position = UDim2.fromScale(0.79, 0.04)
	shoe.Size = UDim2.fromScale(0.21, 0.92)
	shoe.Font = Enum.Font.GothamBlack
	shoe.Text = "👟"
	shoe.TextColor3 = isRunningPopup and Color3.fromRGB(255, 65, 88) or (color or Color3.fromRGB(255, 65, 88))
	shoe.TextScaled = true
	shoe.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	shoe.TextStrokeTransparency = 0
	shoe.ZIndex = 3
	shoe.Parent = holder
	local shoeStroke = addStroke(shoe, 2)

	local popupScale = Instance.new("UIScale")
	local viewportFit = math.min(viewport.X / 1920, viewport.Y / 1080)
	local mobileMultiplier = touchViewport and math.clamp(viewportFit * 1.5, 0.62, 0.86) or 1
	popupScale.Scale = 0.46 * mobileMultiplier
	popupScale.Parent = holder

	local visibleScale = (math.random(90, 106) / 100) * mobileMultiplier
	TweenService:Create(popupScale, TweenInfo.new(0.13 * timingScale, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = visibleScale,
	}):Play()

	local popPosition = UDim2.fromOffset(
		spawnX + math.random(-20, 20),
		spawnY - math.random(18, 34)
	)
	TweenService:Create(holder, TweenInfo.new(0.20 * timingScale, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = popPosition,
		Rotation = holder.Rotation + math.random(-4, 4),
	}):Play()

	local flyDelay = (math.random(20, 28) / 100) * timingScale
	local flyDuration = (math.random(48, 60) / 100) * timingScale
	task.delay(flyDelay, function()
		if not holder.Parent then
			return
		end

		                                                                        
		                                                                     
		                                     
		local liveTargetLabel, liveTargetPoint = findWorld1SpeedTarget()
		targetLabel = liveTargetLabel or targetLabel
		targetPoint = liveTargetPoint

		local homeTween = TweenService:Create(holder, TweenInfo.new(flyDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.fromOffset(targetPoint.X, targetPoint.Y),
			Rotation = 0,
		})
		local shrinkTween = TweenService:Create(popupScale, TweenInfo.new(flyDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Scale = 0.44 * mobileMultiplier,
		})

		homeTween:Play()
		shrinkTween:Play()
		homeTween.Completed:Once(function()
			if not holder.Parent then
				return
			end

			                                                                     
			                                                                   
			                                                        
			local impactTargetLabel, impactTargetPoint = findWorld1SpeedTarget()
			targetLabel = impactTargetLabel or targetLabel
			holder.Position = UDim2.fromOffset(impactTargetPoint.X, impactTargetPoint.Y)
			holder.Rotation = 0
			fireWorld1SpeedImpact(totalSpeed)
			pulseWorld1SpeedText(targetLabel)

			local impactFade = TweenInfo.new(math.max(0.045, 0.09 * timingScale), Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			TweenService:Create(text, impactFade, {
				TextTransparency = 1,
				TextStrokeTransparency = 1,
			}):Play()
			TweenService:Create(shoe, impactFade, {
				TextTransparency = 1,
				TextStrokeTransparency = 1,
			}):Play()
			TweenService:Create(textStroke, impactFade, { Transparency = 1 }):Play()
			TweenService:Create(shoeStroke, impactFade, { Transparency = 1 }):Play()
			local impactShrink = TweenService:Create(popupScale, impactFade, {
				Scale = 0.12 * mobileMultiplier,
			})
			impactShrink:Play()
			impactShrink.Completed:Once(finishPopup)
		end)
	end)

	                                                                          
	                                                         
	task.delay(math.max(0.55, 1.6 * timingScale), finishPopup)
end

                                                                        
                                                                           
                                                                               
                                                                               
                                                                        
local world1PopupSpawnQueue = {}
local world1PopupSpawnHead = 1
local world1PopupSpawnWorkerRunning = false

local function runWorld1PopupSpawnWorker()
	while true do
		local request = world1PopupSpawnQueue[world1PopupSpawnHead]
		if not request then
			world1PopupSpawnQueue = {}
			world1PopupSpawnHead = 1
			world1PopupSpawnWorkerRunning = false
			return
		end
		world1PopupSpawnHead += 1
		makeOneWorld1BarPopup(
			request.Amount,
			request.Color,
			request.IsRunningPopup,
			request.TotalSpeed,
			request.SoundPlaybackSpeed,
			request.TimingScale
		)
		task.wait(request.SpawnGap)
	end
end

local function enqueueWorld1Popup(request)
	table.insert(world1PopupSpawnQueue, request)
	if world1PopupSpawnWorkerRunning then
		return
	end
	world1PopupSpawnWorkerRunning = true
	task.spawn(runWorld1PopupSpawnWorker)
end

local function makeOneScreenPopup(amount, color, isRunningPopup, totalSpeed, popupSoundPlaybackSpeed)
	color = color or Color3.fromRGB(255, 0, 0)
	isRunningPopup = isRunningPopup == true
	if Config.IsWorld2Place ~= true then
		enqueueWorld1Popup({
			Amount = amount,
			Color = color,
			IsRunningPopup = isRunningPopup,
			TotalSpeed = totalSpeed,
			SoundPlaybackSpeed = popupSoundPlaybackSpeed,
			TimingScale = 1,
			SpawnGap = 0.12,
		})
		return
	end

	local holder = Instance.new("Frame")
	holder.Name = isRunningPopup and "RunningSpeedPopupSmall" or "SpeedPopup"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)

	if isRunningPopup then
		holder.Size = UDim2.fromOffset(math.random(112, 166), math.random(54, 78))
	else
		holder.Size = UDim2.fromOffset(math.random(170, 260), math.random(82, 120))
	end

	local compactMobile = isCompactMobileViewport()

	holder.Position = UDim2.fromScale(
		math.random(12, 88) / 100,
		compactMobile and (math.random(12, 64) / 100) or (math.random(12, 82) / 100)
	)
	holder.Rotation = math.random(-10, 10)
	holder.Parent = popupLayer

	local shoe = Instance.new("TextLabel")
	shoe.Name = "ShoeIcon"
	shoe.BackgroundTransparency = 1
	shoe.AnchorPoint = Vector2.new(0.5, 0)
	shoe.Position = UDim2.fromScale(0.5, 0)
	shoe.Size = isRunningPopup and UDim2.fromScale(0.36, 0.34) or UDim2.fromScale(0.45, 0.42)
	shoe.Font = Enum.Font.GothamBlack
	shoe.Text = "👟"
	shoe.TextColor3 = color
	shoe.TextScaled = true
	shoe.TextStrokeTransparency = 0
	shoe.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	shoe.Parent = holder
	local shoeStroke = addStroke(shoe, isRunningPopup and 2 or 3)

	local text = Instance.new("TextLabel")
	text.Name = "GainText"
	text.BackgroundTransparency = 1
	text.AnchorPoint = Vector2.new(0.5, 0)
	text.Position = isRunningPopup and UDim2.fromScale(0.5, 0.31) or UDim2.fromScale(0.5, 0.36)
	text.Size = isRunningPopup and UDim2.fromScale(1, 0.66) or UDim2.fromScale(1, 0.62)
	text.Font = Enum.Font.GothamBlack
	text.Text = "+" .. formatGain(amount) .. " SPEED"
	text.TextColor3 = color
	text.TextScaled = true
	text.TextStrokeTransparency = 0
	text.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	text.Parent = holder
	local textStroke = addStroke(text, isRunningPopup and 3 or 5)

	local scale = Instance.new("UIScale")
	local mobilePopupMultiplier = compactMobile and 0.68 or 1
	scale.Scale = (isRunningPopup and 0.52 or 0.7) * mobilePopupMultiplier
	scale.Parent = holder

	local targetScale
	if isRunningPopup then
		targetScale = (math.random(70, 86) / 100) * mobilePopupMultiplier
	else
		targetScale = (math.random(92, 118) / 100) * mobilePopupMultiplier
	end

	TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = targetScale,
	}):Play()

	TweenService:Create(holder, TweenInfo.new(0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = holder.Position - UDim2.fromScale(math.random(-5, 5) / 100, math.random(8, 18) / 100),
		Rotation = holder.Rotation + math.random(-12, 12),
	}):Play()

	local fadeDelay = math.random(22, 40) / 100
	local fadeInfo = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, fadeDelay)

	                                                                                                 
	TweenService:Create(shoe, fadeInfo, {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()

	TweenService:Create(text, fadeInfo, {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()

	TweenService:Create(shoeStroke, fadeInfo, {
		Transparency = 1,
	}):Play()

	TweenService:Create(textStroke, fadeInfo, {
		Transparency = 1,
	}):Play()

	task.delay(1, function()
		if holder then
			holder:Destroy()
		end
	end)
end

local function showSpeedGainBurst(data)
	local amount = 0
	local color = Color3.fromRGB(255, 0, 0)
	local burstCount = Config.DefaultPopupBurstCount or 7
	local soundPlaybackSpeed = nil
	local isRunningPopup = false
	local isBoostingPopup = false
	local totalSpeed = nil

	if type(data) == "table" then
		amount = tonumber(data.Amount) or 0
		color = data.Color or color
		burstCount = tonumber(data.BurstCount) or burstCount
		soundPlaybackSpeed = tonumber(data.SoundPlaybackSpeed)
		isRunningPopup = data.IsRunningPopup == true
		isBoostingPopup = data.IsBoostingPopup == true
		totalSpeed = tonumber(data.TotalSpeed)
	else
		amount = tonumber(data) or 0
	end

	if amount <= 0 then
		return
	end

	burstCount = math.clamp(math.floor(burstCount), 1, 24)

	local compactMobile = isCompactMobileViewport()
	if compactMobile then
		                                                                    
		burstCount = math.min(burstCount, 8)
	end

	if Config.IsWorld2Place ~= true then
		                                                                        
		                                                                         
		                                                                    
		if isBoostingPopup then
			soundPlaybackSpeed = soundPlaybackSpeed or POPUP_SPAWN_SOUND_PLAYBACK_SPEED
		else
			soundPlaybackSpeed = POPUP_SPAWN_SOUND_PLAYBACK_SPEED
		end
		local timingScale = getWorld1PopupTimingScale(burstCount)
		local spawnGap = getWorld1PopupSpawnGap(burstCount)
		for _ = 1, burstCount do
			enqueueWorld1Popup({
				Amount = amount,
				Color = color,
				IsRunningPopup = isRunningPopup,
				TotalSpeed = totalSpeed,
				SoundPlaybackSpeed = soundPlaybackSpeed,
				TimingScale = timingScale,
				SpawnGap = spawnGap,
			})
		end
		return
	end

	soundPlaybackSpeed = soundPlaybackSpeed or getPopupSoundPlaybackSpeed(burstCount)

	if Config.IsWorld2Place == true then
		                                                            
		playPopSound(soundPlaybackSpeed)
	end

	for i = 1, burstCount do
		task.delay((i - 1) * 0.025, function()
			makeOneScreenPopup(amount, color, isRunningPopup, totalSpeed, soundPlaybackSpeed)
		end)
	end
end

SpeedGainPopup.OnClientEvent:Connect(showSpeedGainBurst)

local LEGACY_BOOST_INSTANCES = {
	SpeedsterBoostTrail = true,
	SpeedTrailTop = true,
	SpeedTrailBottom = true,
}

local function isLegacyBoostInstance(instance)
	return (instance:IsA("Trail") or instance:IsA("Attachment"))
		and LEGACY_BOOST_INSTANCES[instance.Name] == true
end

local function removeLegacyBoostTrail(character)
	if legacyTrailConnection then
		legacyTrailConnection:Disconnect()
		legacyTrailConnection = nil
	end
	legacyTrailCharacter = character

	for _, descendant in ipairs(character:GetDescendants()) do
		if isLegacyBoostInstance(descendant) then
			descendant:Destroy()
		end
	end

	                                                                          
	                                                                             
	legacyTrailConnection = character.DescendantAdded:Connect(function(descendant)
		if isLegacyBoostInstance(descendant) then
			task.defer(function()
				if descendant.Parent then
					descendant:Destroy()
				end
			end)
		end
	end)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		setBoosting(true)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		setBoosting(false)
	end
end)

local activeMobileBoostInput = nil

local function isBoostPressInput(input)
	return input.UserInputType == Enum.UserInputType.Touch
		or input.UserInputType == Enum.UserInputType.MouseButton1
end

mobileButton.InputBegan:Connect(function(input)
	if not isBoostPressInput(input) then
		return
	end

	activeMobileBoostInput = input
	setBoosting(true)
end)

local function finishMobileBoostInput(input)
	if activeMobileBoostInput and input == activeMobileBoostInput then
		activeMobileBoostInput = nil
		setBoosting(false)
	end
end

mobileButton.InputEnded:Connect(finishMobileBoostInput)
UserInputService.InputEnded:Connect(finishMobileBoostInput)

player.CharacterAdded:Connect(function(character)
	boostHeld = false
	activeMobileBoostInput = nil
	removeLegacyBoostTrail(character)
end)

if player.Character then
	removeLegacyBoostTrail(player.Character)
end

player.CharacterRemoving:Connect(function(character)
	if legacyTrailCharacter == character and legacyTrailConnection then
		legacyTrailConnection:Disconnect()
		legacyTrailConnection = nil
		legacyTrailCharacter = nil
	end
end)

task.spawn(function()
	while true do
		local maxStamina = player:GetAttribute("TrueBoostStaminaMax") or player:GetAttribute("BoostStaminaMaxInternal") or player:GetAttribute("BoostStaminaDisplayMax") or Config.BoostStaminaDisplayBase or 17
		local displayMax = player:GetAttribute("TrueBoostStaminaMax") or player:GetAttribute("BoostStaminaDisplayMax") or maxStamina
		local stamina = player:GetAttribute("TrueBoostStamina") or player:GetAttribute("BoostStamina") or maxStamina
		local ratio = math.clamp(stamina / maxStamina, 0, 1)
		local displayStamina = math.clamp(stamina, 0, displayMax)

		boostFill.Size = UDim2.fromScale(ratio, 1)
		boostText.Text = tostring(math.floor(displayStamina + 0.5)) .. "/" .. tostring(math.floor(displayMax + 0.5))

		task.wait(Config.ClientUiUpdateSeconds)
	end
end)

RunService.RenderStepped:Connect(function(dt)
	local boosting = player:GetAttribute("IsBoosting") == true
	local targetFov = boosting and (Config.BoostFov or 95) or (Config.NormalFov or 70)
	local currentCamera = workspace.CurrentCamera

	if currentCamera then
		currentCamera.FieldOfView += (targetFov - currentCamera.FieldOfView) * math.min(dt * 10, 1)
	end
end)

if Config.IsWorld2Place then
	print("[SpeedsterClient] V306CT loaded. Stamina bar now includes a right-side Shift To Sprint hint while preserving dynamic centering on desktop and mobile.")
else
	print("[SpeedsterClient] V306KBA loaded. World 1 popup flights overlap with nonzero spawn gaps; normal running/treadmills use fixed pitch 1.0 while Shift keeps its accepted boosted pitch.")
end
