local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local windowFocused = true
local camera = workspace.CurrentCamera

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local StaminaFeedback = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("StaminaFeedback"))
local StudUi = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("StudUi"))

local playerGui = player:WaitForChild("PlayerGui")

local function removeOldHudCopies()
	for _, child in ipairs(playerGui:GetChildren()) do
		if child.Name == "SpeedsterHUD" and child:GetAttribute("V125ProtectedHud") ~= true then
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

-- The old SpeedsterHUD screen was removed; the designer's SpeedsterFrame shows
-- speed now. Code must NOT require or enable the old SpeedsterHUD.
local gui = playerGui:FindFirstChild("SpeedsterHUD")
if gui then
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 42
	-- gui.Enabled is left as designed; code no longer forces the old HUD on.
end

-- Speed popup frames are displayed on SpeedPopupLayer across all platforms.
local function getPopupLayer()
	local layer = playerGui:FindFirstChild("SpeedPopupLayer")
	if not layer then
		layer = playerGui:WaitForChild("SpeedPopupLayer", 2)
	end
	if not layer then
		layer = Instance.new("ScreenGui")
		layer.Name = "SpeedPopupLayer"
		layer.Parent = playerGui
	end
	layer:SetAttribute("V125ProtectedHud", true)
	layer.ResetOnSpawn = false
	layer.IgnoreGuiInset = true
	layer.DisplayOrder = 50
	layer.Enabled = player:GetAttribute("HidePopups") ~= true
	return layer
end

local popupLayer = getPopupLayer()

local function updatePopupLayerVisibility()
	local hidden = player:GetAttribute("HidePopups") == true
	local layer = playerGui:FindFirstChild("SpeedPopupLayer")
	if layer and layer:IsA("ScreenGui") then
		layer.Enabled = not hidden
		if hidden then
			for _, child in ipairs(layer:GetChildren()) do
				if child:IsA("GuiObject") then
					child:Destroy()
				end
			end
		end
	end
end
player:GetAttributeChangedSignal("HidePopups"):Connect(updatePopupLayerVisibility)
task.defer(updatePopupLayerVisibility)

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


local mobileButton = gui and gui:FindFirstChild("MobileBoostButton")
local mobileButtonScale = mobileButton and mobileButton:FindFirstChild("MobileResponsiveScale")
if mobileButton then
	mobileButton.Visible = UserInputService.TouchEnabled
end

-- The design's right-side sprint button; it replaces the old MobileBoostButton
-- (that button lived in the deleted SpeedsterHUD screen, so mobile players had
-- no way to boost). Wired below as the mobile boost toggle.
local mobileSprintButton = nil

-- Hide old BoostFrame (replaced by Mainhud.SpeedsterBar)
local oldBoostFrame = gui and gui:FindFirstChild("BoostFrame")
if oldBoostFrame then
	oldBoostFrame.Visible = false
end
local function anyGamepadConnected()
	if UserInputService.GamepadEnabled then
		return true
	end
	return #UserInputService:GetConnectedGamepads() > 0
end

local function isCompactMobileViewport()
	local currentCamera = workspace.CurrentCamera
	local viewport = currentCamera and currentCamera.ViewportSize or Vector2.new(1920, 1080)
	return UserInputService.TouchEnabled and viewport.Y <= 700, viewport
end

local function updateMobileHudLayout()
	-- Layout is fully controlled from Studio (the imported SpeedsterHUD GUI).
	-- No runtime position/scale overrides here, so the positions/sizes set in
	-- Studio are preserved instead of being moved by code.
end

local boostHeld = false
local activeMobileBoostInput = nil
local legacyTrailConnection = nil
local legacyTrailCharacter = nil

local MOBILE_OFF_COLOR = Color3.fromRGB(68, 160, 255)
local MOBILE_ON_COLOR = Color3.fromRGB(255, 170, 60)

local SPRINT_OFF_GRADIENT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 235, 255)),
	ColorSequenceKeypoint.new(0.55, Color3.fromRGB(30, 160, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 92, 214)),
})
local SPRINT_ON_GRADIENT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 225, 80)),
	ColorSequenceKeypoint.new(0.55, Color3.fromRGB(255, 140, 20)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 50, 10)),
})

local function applyMobileBoostVisual(boosting)
	if mobileButton then
		mobileButton.BackgroundColor3 = boosting and MOBILE_ON_COLOR or MOBILE_OFF_COLOR
	end
	if mobileSprintButton then
		local gradient = mobileSprintButton:FindFirstChildOfClass("UIGradient")
		if gradient then
			gradient.Color = if boosting then SPRINT_ON_GRADIENT else SPRINT_OFF_GRADIENT
			mobileSprintButton.BackgroundColor3 = Color3.new(1, 1, 1)
		else
			mobileSprintButton.BackgroundColor3 = boosting and MOBILE_ON_COLOR or MOBILE_OFF_COLOR
		end
	end
end

local function setBoosting(value)
	if value and (not windowFocused or player:GetAttribute("SpeedsterMenuOpen") or GuiService.MenuIsOpen or UserInputService:GetFocusedTextBox()) then value = false end
	value = value == true

	if boostHeld == value then
		return
	end

	if value and player:GetAttribute("FlightAbilityActive") ~= true then
		-- The server refuses a sprint below this; say so instead of silently ignoring the key.
		local stamina = tonumber(player:GetAttribute("TrueBoostStamina"))
		if stamina and stamina < (tonumber(Config.MinimumStaminaToStartBoost) or 1.4) then
			StaminaFeedback.Notify("run")
		end
	end

	boostHeld = value
	-- Local only (never replicated): whether this player is holding the sprint. The Sonic
	-- Burst charges while it is held and fires when it is let go (SonicBurstClient).
	player:SetAttribute("SprintHeld", value)
	applyMobileBoostVisual(value)

	BoostState:FireServer(value)
end

-- Other client scripts turn the sprint on and off through here (the Sonic Burst's touch
-- button sprints while it is held, draining the same stamina bar).
do
	local playerScripts = player:WaitForChild("PlayerScripts")
	local boostControl = playerScripts:FindFirstChild("SpeedsterBoostControl")
	if not boostControl then
		boostControl = Instance.new("BindableEvent")
		boostControl.Name = "SpeedsterBoostControl"
		boostControl.Parent = playerScripts
	end
	boostControl.Event:Connect(function(value)
		setBoosting(value == true)
	end)
end

local SUFFIXES = {"", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc", "Ud", "Dd", "Td", "Qad", "Qid", "Sxd", "Spd", "Ocd", "Nod", "Vg"}

local function formatGain(value)
	value = tonumber(value) or 0
	if value < 1000 then
		return tostring(math.floor(value))
	end
	local tier = math.floor(math.log10(math.max(1, value)) / 3) + 1
	if tier <= #SUFFIXES then
		local scaled = value / (1000 ^ (tier - 1))
		if scaled >= 100 then
			return string.format("%.0f%s", scaled, SUFFIXES[tier])
		elseif scaled >= 10 then
			return string.format("%.1f%s", scaled, SUFFIXES[tier]):gsub("%.0", "")
		else
			return string.format("%.2f%s", scaled, SUFFIXES[tier]):gsub("0+$", ""):gsub("%.$", "")
		end
	end
	return string.format("%.2e", value)
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

local lastPopSoundAt = 0
local function playPopSound(playbackSpeed)
	local now = os.clock()
	if now - lastPopSoundAt < 0.06 then
		return
	end
	lastPopSoundAt = now
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
	local mainhud = playerGui:FindFirstChild("Mainhud")
	local lpb = mainhud and mainhud:FindFirstChild("LevelProgressBar")
	local frame = lpb and lpb:FindFirstChild("Frame")
	local speedLabel = frame and (frame:FindFirstChild("Speed") or frame:FindFirstChild("Exp") or frame:FindFirstChild("Level"))
	local target = speedLabel or frame or lpb

	if target and target:IsA("GuiObject") and target.AbsoluteSize.X > 0 and target.AbsoluteSize.Y > 0 then
		local targetCenter = target.AbsolutePosition + (target.AbsoluteSize * 0.5)
		local width = math.max(target.AbsoluteSize.X, frame and frame.AbsoluteSize.X or (lpb and lpb.AbsoluteSize.X or target.AbsoluteSize.X))
		return target, targetCenter, width
	end

	local progressGui = playerGui:FindFirstChild("BottomProgress") or playerGui:FindFirstChild("BottomProgressImage")
	local progressHolder = progressGui and progressGui:FindFirstChild("ProgressBarHolder")
	local targetLabel = progressHolder and (progressHolder:FindFirstChild("SpeedAmountText") or progressHolder:FindFirstChild("Speed"))

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
	return nil, Vector2.new(viewport.X * 0.5, viewport.Y * 0.77), viewport.X * 0.44
end

local function fireWorld1SpeedImpact(totalSpeed)
	local mainhud = playerGui:FindFirstChild("Mainhud")
	local lpb = mainhud and mainhud:FindFirstChild("LevelProgressBar")
	local frame = lpb and lpb:FindFirstChild("Frame")
	local impactEvent = (frame and frame:FindFirstChild("World1SpeedGainImpact"))
		or (lpb and lpb:FindFirstChild("World1SpeedGainImpact"))
		or (mainhud and mainhud:FindFirstChild("World1SpeedGainImpact"))
		or (playerGui:FindFirstChild("BottomProgress") and playerGui.BottomProgress:FindFirstChild("World1SpeedGainImpact"))
	if impactEvent and impactEvent:IsA("BindableEvent") then
		impactEvent:Fire(totalSpeed)
	end
end

local speedPulseSerial = 0

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

	task.spawn(function()
		local punch = TweenService:Create(
			pulseScale,
			TweenInfo.new(0.07, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = 1.18 }
		)
		punch:Play()
		punch.Completed:Wait()

		if thisPulse ~= speedPulseSerial or not pulseScale.Parent then
			return
		end

		local settle = TweenService:Create(
			pulseScale,
			TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Scale = 1.0 }
		)
		settle:Play()
		settle.Completed:Wait()

		if thisPulse == speedPulseSerial and pulseScale.Parent then
			pulseScale.Scale = 1.0
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
	if player:GetAttribute("HidePopups") == true then
		if onFinished then
			task.defer(onFinished)
		end
		return
	end
	local currentCamera = workspace.CurrentCamera
	local viewport = currentCamera and currentCamera.ViewportSize or Vector2.new(1920, 1080)
	local targetLabel, targetPoint, progressWidth = findWorld1SpeedTarget()
	local touchViewport = UserInputService.TouchEnabled

	local horizontalSpread = math.max(20, math.min(viewport.X * 0.34, progressWidth * 0.42))
	local minimumRise = math.max(52, math.min(88, viewport.Y * 0.085))
	local maximumRise = math.max(minimumRise + 36, math.min(245, viewport.Y * 0.235))
	if touchViewport then
		minimumRise *= 0.68
		maximumRise *= 0.72
	end

	local minSpread = -math.abs(math.floor(horizontalSpread))
	local maxSpread = math.abs(math.floor(horizontalSpread))
	local spreadOffset = (minSpread >= maxSpread) and 0 or math.random(minSpread, maxSpread)

	local minR = math.floor(math.min(minimumRise, maximumRise))
	local maxR = math.floor(math.max(minimumRise, maximumRise))
	local riseOffset = (minR >= maxR) and minR or math.random(minR, maxR)

	local spawnX = math.clamp(
		targetPoint.X + spreadOffset,
		48,
		viewport.X - 48
	)
	local spawnY = math.clamp(
		targetPoint.Y - riseOffset,
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
	holder.Active = false
	holder.Selectable = false
	local layer = getPopupLayer()
	if layer then
		layer.Enabled = true
		holder.Parent = layer
	end
	
	playPopSound(popupSoundPlaybackSpeed)

	local text = Instance.new("TextLabel")
	text.Name = "GainText"
	text.BackgroundTransparency = 1
	text.Position = UDim2.fromScale(0, 0)
	text.Size = UDim2.new(1, -34, 1, 0)
	text.Font = Enum.Font.GothamBlack
	text.Text = "+" .. formatGain(amount)
	if isRunningPopup then
		text.TextColor3 = Color3.fromRGB(255, 255, 255)
	else
		text.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	end
	text.TextScaled = true
	text.TextXAlignment = Enum.TextXAlignment.Right
	text.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	text.TextStrokeTransparency = 0
	text.Active = false
	text.Selectable = false
	text.ZIndex = 4
	text.Parent = holder
	local textStroke = addStroke(text, isRunningPopup and 2 or 2.5)

	local shoe = Instance.new("TextLabel")
	shoe.Name = "ShoeIcon"
	shoe.BackgroundTransparency = 1
	shoe.Position = UDim2.new(1, -30, 0, 2)
	shoe.Size = UDim2.new(0, 30, 1, -4)
	shoe.Font = Enum.Font.GothamBlack
	shoe.Text = "👟"
	shoe.TextColor3 = isRunningPopup and Color3.fromRGB(255, 65, 88) or (color or Color3.fromRGB(255, 255, 255))
	shoe.TextScaled = true
	shoe.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	shoe.TextStrokeTransparency = 0
	shoe.Active = false
	shoe.Selectable = false
	shoe.Visible = true
	shoe.ZIndex = 4
	shoe.Parent = holder
	local shoeStroke = addStroke(shoe, 1)

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
local world1PopupSpawnTail = 0
local world1PopupSpawnWorkerRunning = false

-- Running gains arrive ten times a second (twenty while boosting), but a popup
-- needs longer than that to fly to the bar. Queuing one popup per tick made the
-- queue itself the bottleneck: every extra tick pushed the number on screen
-- further behind the number the server had already credited, which is what
-- players saw as "the multis don't change". The queue is therefore kept shallow
-- and anything that cannot be drawn in time is folded into the pending popup,
-- so the figure that does appear is the real accumulated total.
local MAX_RUNNING_POPUP_QUEUE_SIZE = 2
local MAX_BURST_POPUP_QUEUE_SIZE = 36

local function mergeWorld1Popup(target, request)
	target.Amount = (tonumber(target.Amount) or 0) + (tonumber(request.Amount) or 0)
	target.TotalSpeed = request.TotalSpeed or target.TotalSpeed
	target.SoundPlaybackSpeed = request.SoundPlaybackSpeed or target.SoundPlaybackSpeed
	-- Drain faster while behind, without dropping below one frame.
	target.SpawnGap = math.max(0.03, math.min(target.SpawnGap or 0.12, request.SpawnGap or 0.12) * 0.5)
	target.TimingScale = math.min(target.TimingScale or 1, request.TimingScale or 1)
end

local function runWorld1PopupSpawnWorker()
	while true do
		local request = world1PopupSpawnQueue[world1PopupSpawnHead]
		if not request then
			world1PopupSpawnQueue = {}
			world1PopupSpawnHead = 1
			world1PopupSpawnTail = 0
			world1PopupSpawnWorkerRunning = false
			return
		end
		world1PopupSpawnQueue[world1PopupSpawnHead] = nil
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
	if player:GetAttribute("HidePopups") == true then return end
	local pending = world1PopupSpawnTail - world1PopupSpawnHead + 1
	local maxQueue = request.IsRunningPopup and MAX_RUNNING_POPUP_QUEUE_SIZE or MAX_BURST_POPUP_QUEUE_SIZE
	if pending >= maxQueue then
		local tail = world1PopupSpawnQueue[world1PopupSpawnTail]
		if tail then
			mergeWorld1Popup(tail, request)
			return
		end
	end
	world1PopupSpawnTail += 1
	world1PopupSpawnQueue[world1PopupSpawnTail] = request
	if world1PopupSpawnWorkerRunning then
		return
	end
	world1PopupSpawnWorkerRunning = true
	task.spawn(runWorld1PopupSpawnWorker)
end

local function makeOneScreenPopup(amount, color, isRunningPopup, totalSpeed, popupSoundPlaybackSpeed)
	color = color or Color3.fromRGB(255, 0, 0)
	isRunningPopup = isRunningPopup == true
	enqueueWorld1Popup({
		Amount = amount,
		Color = color,
		IsRunningPopup = isRunningPopup,
		TotalSpeed = totalSpeed,
		SoundPlaybackSpeed = popupSoundPlaybackSpeed,
		TimingScale = 1,
		SpawnGap = 0.12,
	})
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
		isRunningPopup = data.IsRunningPopup == true
		isBoostingPopup = data.IsBoostingPopup == true
		burstCount = tonumber(data.BurstCount) or (isRunningPopup and 1 or burstCount)
		soundPlaybackSpeed = tonumber(data.SoundPlaybackSpeed)
		totalSpeed = tonumber(data.TotalSpeed)
	else
		amount = tonumber(data) or 0
	end

	if isRunningPopup then
		burstCount = isBoostingPopup and 2 or 1
	else
		local compactMobile = isCompactMobileViewport()
		-- Keep the OG mobile budget; desktop preserves each treadmill's full
		-- configured burst, including the newer Hacker/Admin3000 profiles.
		burstCount = math.clamp(math.floor(burstCount), 1, compactMobile and 8 or 36)
	end

	if amount <= 0 then
		return
	end

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

local function isBoostPressInput(input)
	return input.UserInputType == Enum.UserInputType.Touch
		or input.UserInputType == Enum.UserInputType.MouseButton1
end

-- Mobile sprint button: Mainhud (and its MobileSprint child) is recreated
-- whenever the GUI resets on spawn/respawn, so keep watching rather than
-- resolving the button once. Placed after the helpers it depends on so the
-- closures capture them as upvalues (not nil globals).
task.spawn(function()
	while player.Parent do
		local mainhudGui = playerGui:FindFirstChild("Mainhud")
		local sprintButton = mainhudGui and mainhudGui:FindFirstChild("MobileSprint")

		if not sprintButton and mainhudGui then
			sprintButton = mainhudGui:WaitForChild("MobileSprint", 10)
		end

		if sprintButton and sprintButton ~= mobileSprintButton then
			mobileSprintButton = sprintButton
			mobileSprintButton.Visible = UserInputService.TouchEnabled
			-- Pressed state: the button sinks while the finger is on it and springs back
			-- when it lifts (its PressScale is saved in the place; made here if missing).
			local pressScale = sprintButton:FindFirstChild("PressScale")
			if not (pressScale and pressScale:IsA("UIScale")) then
				pressScale = Instance.new("UIScale")
				pressScale.Name = "PressScale"
				pressScale.Parent = sprintButton
			end
			local label = sprintButton:FindFirstChild("Label")
			if not label or not label:IsA("TextLabel") then
				label = Instance.new("TextLabel")
				label.Name = "Label"
				label.BackgroundTransparency = 1
				label.Size = UDim2.fromScale(1, 1)
				label.Position = UDim2.fromScale(0.5, 0.5)
				label.AnchorPoint = Vector2.new(0.5, 0.5)
				label.Text = (sprintButton:IsA("TextButton") and sprintButton.Text ~= "" and sprintButton.Text) or "SPRINT"
				label.TextColor3 = Color3.fromRGB(255, 255, 255)
				label.TextStrokeColor3 = Color3.fromRGB(11, 27, 61)
				label.TextStrokeTransparency = 0
				label.TextScaled = true
				label.ZIndex = 5
				pcall(function()
					label.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
				end)
				label.Parent = sprintButton
			end
			local pressDown = TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			local pressUp = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			mobileSprintButton.InputBegan:Connect(function(input)
				if not isBoostPressInput(input) then
					return
				end
				TweenService:Create(pressScale, pressDown, { Scale = 0.86 }):Play()

				-- Mobile BOOST is a toggle: tap to enable / tap again to disable.
				setBoosting(not boostHeld)
			end)
			mobileSprintButton.InputEnded:Connect(function(input)
				if isBoostPressInput(input) then
					TweenService:Create(pressScale, pressUp, { Scale = 1 }):Play()
				end
			end)

			-- Keep the highlight state on a freshly re-created button.
			if boostHeld then
				applyMobileBoostVisual(true)
			end
		end

		task.wait(0.5)
	end
end)

local function isGamepadInput(input)
	local t = input.UserInputType
	return t == Enum.UserInputType.Gamepad1
		or t == Enum.UserInputType.Gamepad2
		or t == Enum.UserInputType.Gamepad3
		or t == Enum.UserInputType.Gamepad4
		or t == Enum.UserInputType.Gamepad5
		or t == Enum.UserInputType.Gamepad6
		or t == Enum.UserInputType.Gamepad7
		or t == Enum.UserInputType.Gamepad8
end

local function handleBoostAction(actionName, inputState, inputObject)
	if not windowFocused or player:GetAttribute("SpeedsterMenuOpen") or GuiService.MenuIsOpen or UserInputService:GetFocusedTextBox() then
		setBoosting(false)
		return Enum.ContextActionResult.Pass
	end
	if inputState == Enum.UserInputState.Cancel then setBoosting(false); return Enum.ContextActionResult.Pass end
	if inputObject.KeyCode == Enum.KeyCode.ButtonL2 or inputObject.KeyCode == Enum.KeyCode.ButtonR2 then
		if inputObject.Position.Z > 0.15 or inputState == Enum.UserInputState.Begin then
			setBoosting(true)
		else
			setBoosting(false)
		end
		return Enum.ContextActionResult.Sink
	end

	if inputState == Enum.UserInputState.Begin then
		setBoosting(true)
		return Enum.ContextActionResult.Sink
	elseif inputState == Enum.UserInputState.End then
		setBoosting(false)
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end

ContextActionService:BindActionAtPriority(
	"SpeedsterBoostSprint",
	handleBoostAction,
	false,
	Enum.ContextActionPriority.High.Value + 100,
	Enum.KeyCode.LeftShift,
	Enum.KeyCode.RightShift,
	Enum.KeyCode.ButtonL2,
	Enum.KeyCode.ButtonR2,
	Enum.KeyCode.ButtonL1
)

-- Secondary listeners for keyboard and digital gamepad buttons
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if UserInputService:GetFocusedTextBox() then
		return
	end

	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		setBoosting(true)
	elseif input.KeyCode == Enum.KeyCode.ButtonL1 or input.KeyCode == Enum.KeyCode.ButtonL2 or input.KeyCode == Enum.KeyCode.ButtonR2 then
		setBoosting(true)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		setBoosting(false)
	elseif input.KeyCode == Enum.KeyCode.ButtonL1 or input.KeyCode == Enum.KeyCode.ButtonL2 or input.KeyCode == Enum.KeyCode.ButtonR2 then
		setBoosting(false)
	end
end)

-- Analog trigger listener (crucial for PS4 / PS5 / Xbox where L2/R2 send InputChanged with Position.Z)
UserInputService.InputChanged:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.ButtonL2 or input.KeyCode == Enum.KeyCode.ButtonR2 then
		if input.Position.Z > 0.15 then
			setBoosting(true)
		else
			setBoosting(false)
		end
	end
end)

-- Direct hardware polling every frame: 100% guarantees PS4/PS5/Xbox L2/R2 trigger detection!
local lastHardwareBoostState = false
local function cancelBoostInput()
	lastHardwareBoostState = false
	setBoosting(false)
end
UserInputService.GamepadDisconnected:Connect(cancelBoostInput)
UserInputService.WindowFocusReleased:Connect(function() windowFocused = false; cancelBoostInput() end)
UserInputService.WindowFocused:Connect(function() windowFocused = true end)
UserInputService.TextBoxFocused:Connect(cancelBoostInput)
player:GetAttributeChangedSignal("SpeedsterMenuOpen"):Connect(function() if player:GetAttribute("SpeedsterMenuOpen") then cancelBoostInput() end end)
GuiService.MenuOpened:Connect(cancelBoostInput)
RunService.RenderStepped:Connect(function()
	if not windowFocused or player:GetAttribute("SpeedsterMenuOpen") or GuiService.MenuIsOpen or UserInputService:GetFocusedTextBox() then
		cancelBoostInput()
		return
	end
	local connectedGamepads = UserInputService:GetConnectedGamepads()
	if #connectedGamepads > 0 then
		local gp = connectedGamepads[1]
		local states = UserInputService:GetGamepadState(gp)
		local isTriggerDown = false
		for _, item in ipairs(states) do
			if item.KeyCode == Enum.KeyCode.ButtonL2 or item.KeyCode == Enum.KeyCode.ButtonR2 then
				if item.Position.Z > 0.15 then
					isTriggerDown = true
					break
				end
			elseif item.KeyCode == Enum.KeyCode.ButtonL1 then
				if UserInputService:IsGamepadButtonDown(gp, Enum.KeyCode.ButtonL1) then
					isTriggerDown = true
					break
				end
			end
		end

		if isTriggerDown and not lastHardwareBoostState then
			lastHardwareBoostState = true
			setBoosting(true)
		elseif not isTriggerDown and lastHardwareBoostState then
			lastHardwareBoostState = false
			setBoosting(false)
		end
	end
end)

-- Auto-reset toggle state if server halts boosting (e.g. stamina depleted)
player:GetAttributeChangedSignal("IsBoosting"):Connect(function()
	local isBoosting = player:GetAttribute("IsBoosting") == true
	if not isBoosting then
		local holdingKey = false
		pcall(function()
			holdingKey = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
				or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
				or UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonL2)
				or UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonR2)
		end)
		local stamina = tonumber(player:GetAttribute("TrueBoostStamina"))
		if (holdingKey or boostHeld) and stamina and stamina < (tonumber(Config.MinimumStaminaToStartBoost) or 1.4)
			and player:GetAttribute("FlightAbilityActive") ~= true
		then
			-- The bar ran dry while the player is still asking to run.
			StaminaFeedback.Notify("run")
		end
		if not holdingKey then
			boostHeld = false
			player:SetAttribute("SprintHeld", false)
			applyMobileBoostVisual(false)
		end
	end
end)


if mobileButton then
	mobileButton.InputBegan:Connect(function(input)
		if not isBoostPressInput(input) then
			return
		end

		-- Mobile BOOST is a toggle: tap to enable / tap again to disable.
		setBoosting(not boostHeld)
	end)
end

-- Note: mobileSprintButton (Mainhud.MobileSprint) is resolved and wired inside
-- the task.spawn above, since it may not exist when this script first runs.

player.CharacterAdded:Connect(function(character)
	boostHeld = false
	player:SetAttribute("SprintHeld", false)
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
		-- Stamina bar display is handled by MainHUDController via Mainhud.SpeedsterBar
		task.wait(Config.ClientUiUpdateSeconds)
	end
end)

-- One-off kicks (the Sonic Burst's FOV punch, Shared.CameraPunch) ride on top of the
-- smoothed FOV instead of being eased away by it.
local CameraPunch = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CameraPunch"))
local smoothedFov = nil

RunService.RenderStepped:Connect(function(dt)
	local boosting = player:GetAttribute("IsBoosting") == true
	local sonicActive = player:GetAttribute("SonicBurstActive") == true
	local baseFov = Config.NormalFov or 70
	local targetFov = baseFov

	if boosting and sonicActive then
		targetFov = math.min((Config.BoostFov or 95) + 8, 110)
	elseif boosting then
		targetFov = Config.BoostFov or 95
	elseif sonicActive then
		targetFov = math.min(baseFov + 14, 105)
	end

	local currentCamera = workspace.CurrentCamera
	if currentCamera then
		smoothedFov = smoothedFov or currentCamera.FieldOfView
		smoothedFov += (targetFov - smoothedFov) * math.min(dt * 10, 1)
		currentCamera.FieldOfView = math.clamp(smoothedFov + CameraPunch.FovOffset(), 1, 120)
	end
end)

RunService.Heartbeat:Connect(function()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local moving = (hum ~= nil) and hum.Health > 0 and (hum.MoveDirection.Magnitude > 0.05)
	if player:GetAttribute("IsMoving") ~= moving then
		player:SetAttribute("IsMoving", moving)
	end
end)

if Config.IsWorld2Place then
	print("[SpeedsterClient] V306CT loaded. Stamina bar now includes a right-side Shift To Sprint hint while preserving dynamic centering on desktop and mobile.")
else
	print("[SpeedsterClient] V306KBA loaded. World 1 popup flights overlap with nonzero spawn gaps; normal running/treadmills use fixed pitch 1.0 while Shift keeps its accepted boosted pitch.")
end
