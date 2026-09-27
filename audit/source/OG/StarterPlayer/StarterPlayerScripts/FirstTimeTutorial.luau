         
                                                                              
                                                                              
                                                                             
                                                                               
                                                                   

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local IS_NEW_WORLD1 = Config.IsNewWorld1Map == true
local newWorld1Root = IS_NEW_WORLD1
	and Workspace:FindFirstChild(tostring(Config.NewWorld1MapMarkerName or "neworld1"))

local function getNewWorld1Root()
	if not IS_NEW_WORLD1 then
		return nil
	end
	if not newWorld1Root or not newWorld1Root.Parent then
		newWorld1Root = Workspace:FindFirstChild(tostring(Config.NewWorld1MapMarkerName or "neworld1"))
	end
	return newWorld1Root
end

local WORLD_2_PLACE_ID = 116359653478954
if game.PlaceId == WORLD_2_PLACE_ID then
	print("[FirstTimeTutorial] V306HQ client inactive in World 2.")
	return
end

                                                                               
local FORCE_TUTORIAL_FOR_EVERYONE = false

local COMPLETE_SOUND_ID = "rbxassetid://135478009117226"
local ARROW_TEXTURE_ID = "rbxassetid://5886559421"
local ARROW_BEAM_WIDTH = 3.25
local ARROW_OUTLINE_EXTRA_WIDTH = 0.70
                                                                      
local ARROW_TEXTURE_LENGTH = 5.2
local ARROW_TEXTURE_SPEED = 1
local PLAYER_ARROW_HEIGHT_OFFSET = -2.55
local TARGET_ARROW_SURFACE_OFFSET = 0.32
local STEP_TIMEOUT_SECONDS = 1.7 * 60
local BETWEEN_STEPS_SECONDS = 0.65
local COLLISION_FOLDER_NAME = "VortexTreadmillCollisionFix_V255"

local displayedStep = 0
local target = nil
local targetSearchSerial = 0
local targetWatchConnection = nil
local targetAncestryConnection = nil
local targetDeck = nil
local targetDeckWatchConnection = nil
local beamFolder = nil
local goalPart = nil
local goalAttachment = nil
local playerAttachment = nil
local tutorialOutlineBeam = nil
local tutorialBeam = nil
local characterAddedConnection = nil
local reviewActive = FORCE_TUTORIAL_FOR_EVERYONE
local reviewStep = FORCE_TUTORIAL_FOR_EVERYONE and 1 or 0
local reviewToken = 0

local completeSound = SoundService:FindFirstChild("FirstTimeTutorialCompleteSound")
if not completeSound or not completeSound:IsA("Sound") then
	if completeSound then
		completeSound:Destroy()
	end
	completeSound = Instance.new("Sound")
	completeSound.Name = "FirstTimeTutorialCompleteSound"
	completeSound.Parent = SoundService
end
completeSound.SoundId = COMPLETE_SOUND_ID
completeSound.Volume = 1
completeSound.PlaybackSpeed = 1

task.spawn(function()
	pcall(function()
		ContentProvider:PreloadAsync({ completeSound, ARROW_TEXTURE_ID })
	end)
end)

local function playCompleteSound()
	completeSound:Stop()
	completeSound.TimePosition = 0
	SoundService:PlayLocalSound(completeSound)
end

local function isInsideStageDecor(instance)
	local current = instance
	while current and current ~= Workspace do
		if current.Name == "StageDecor_Runtime" or current:GetAttribute("StageDecorClone") == true then
			return true
		end
		current = current.Parent
	end
	return false
end

local function isBrownTreadmillCandidate(instance)
	local acceptedName = instance.Name == "Treadmill1_basic"
		or (IS_NEW_WORLD1
			and instance.Name == "Basic"
			and getNewWorld1Root() ~= nil
			and instance:IsDescendantOf(getNewWorld1Root()))
	return (instance:IsA("Model") or instance:IsA("BasePart"))
		and acceptedName
		and instance:GetAttribute("OwnerAdminSpawned") ~= true
		and not isInsideStageDecor(instance)
end

local function isFirstWinPadCandidate(instance)
	local targetStage = IS_NEW_WORLD1 and 1 or 2
	return instance:IsA("BasePart")
		and tonumber(instance:GetAttribute("SafeZoneIndex")) == targetStage
		and tonumber(instance:GetAttribute("WinReward")) ~= nil
		and instance:GetAttribute("FutureRobuxProduct") ~= true
end

local function isCandidate(instance, step)
	if step == 1 then
		return isBrownTreadmillCandidate(instance)
	elseif step == 2 then
		return isFirstWinPadCandidate(instance)
	end
	return false
end

local function candidateScore(instance, step)
	local score = 0
	local current = instance
	while current and current ~= Workspace do
		score += 1
		current = current.Parent
	end

	if instance.Parent == Workspace then
		score -= 100
	end
	if step == 2 and instance.Parent and instance.Parent.Name == "WinPads_TO_PLACE" then
		score -= 100
	end
	return score
end

local function findBestTarget(step)
	local best = nil
	local bestScore = math.huge
	                                                                           
	                                                     
	for _, instance in ipairs(Workspace:GetDescendants()) do
		if isCandidate(instance, step) then
			local score = candidateScore(instance, step)
			if score < bestScore then
				best = instance
				bestScore = score
			end
		end
	end
	return best
end

local function disconnectTargetWatch()
	if targetWatchConnection then
		targetWatchConnection:Disconnect()
		targetWatchConnection = nil
	end
end

local function disconnectTargetAncestryWatch()
	if targetAncestryConnection then
		targetAncestryConnection:Disconnect()
		targetAncestryConnection = nil
	end
end

local function disconnectTargetDeckWatch()
	if targetDeckWatchConnection then
		targetDeckWatchConnection:Disconnect()
		targetDeckWatchConnection = nil
	end
end

local refreshBeamVisual
local resolveTarget

local function findCollisionDeckForTreadmill(treadmill)
	if not treadmill or not treadmill.Parent then
		return nil
	end

	local collisionFolder = Workspace:FindFirstChild(COLLISION_FOLDER_NAME)
	if not collisionFolder then
		return nil
	end

	local physicalTreadmill = treadmill
	if IS_NEW_WORLD1 and treadmill.Name == "Basic" then
		local nestedBelt = treadmill:FindFirstChild("Treadmil", true)
		if nestedBelt and (nestedBelt:IsA("Model") or nestedBelt:IsA("BasePart")) then
			physicalTreadmill = nestedBelt
		end
	end

	local wantedSource = physicalTreadmill:GetFullName()
	for _, treadmillFolder in ipairs(collisionFolder:GetChildren()) do
		if treadmillFolder:GetAttribute("SourceTreadmill") == wantedSource then
			local deck = treadmillFolder:FindFirstChild("SmoothDeck")
			if deck and deck:IsA("BasePart") then
				return deck
			end
		end
	end

	return nil
end

local function resolveTargetDeck(treadmill)
	targetDeck = findCollisionDeckForTreadmill(treadmill)
	disconnectTargetDeckWatch()
	if targetDeck then
		if refreshBeamVisual then
			task.defer(refreshBeamVisual)
		end
		return
	end

	targetDeckWatchConnection = Workspace.DescendantAdded:Connect(function(instance)
		if instance.Name ~= "SmoothDeck" or not instance:IsA("BasePart") then
			return
		end

		task.defer(function()
			if target == treadmill and treadmill.Parent then
				targetDeck = findCollisionDeckForTreadmill(treadmill)
				if targetDeck then
					disconnectTargetDeckWatch()
					if refreshBeamVisual then
						task.defer(refreshBeamVisual)
					end
				end
			end
		end)
	end)
end

local function assignTarget(instance)
	if not instance or not instance.Parent then
		return false
	end
	target = instance
	disconnectTargetWatch()
	disconnectTargetAncestryWatch()
	targetAncestryConnection = instance.AncestryChanged:Connect(function()
		if target == instance and not instance:IsDescendantOf(Workspace) then
			disconnectTargetAncestryWatch()
			if displayedStep == 1 or displayedStep == 2 then
				task.defer(resolveTarget, displayedStep)
			end
		end
	end)
	if displayedStep == 1 then
		resolveTargetDeck(instance)
	else
		targetDeck = nil
		disconnectTargetDeckWatch()
	end
	print(
		"[FirstTimeTutorial] V306HQ target resolved | Step="
			.. tostring(displayedStep)
			.. " | "
			.. instance:GetFullName()
	)
	if refreshBeamVisual then
		task.defer(refreshBeamVisual)
	end
	return true
end

resolveTarget = function(step)
	targetSearchSerial += 1
	local searchSerial = targetSearchSerial
	target = nil
	targetDeck = nil
	disconnectTargetWatch()
	disconnectTargetAncestryWatch()
	disconnectTargetDeckWatch()

	if step ~= 1 and step ~= 2 then
		return
	end

	if assignTarget(findBestTarget(step)) then
		return
	end

	targetWatchConnection = Workspace.DescendantAdded:Connect(function(instance)
		if displayedStep == step and isCandidate(instance, step) then
			assignTarget(instance)
		end
	end)

	                                                                             
	                                                                                
	for _, delaySeconds in ipairs({ 0.25, 1.25, 4 }) do
		task.delay(delaySeconds, function()
			if targetSearchSerial == searchSerial
				and displayedStep == step
				and not target
			then
				assignTarget(findBestTarget(step))
			end
		end)
	end

	task.delay(4.25, function()
		if targetSearchSerial == searchSerial
			and displayedStep == step
			and not target
		then
			warn("[FirstTimeTutorial] V306HQ could not resolve the target for Step " .. tostring(step))
		end
	end)
end

local function getTargetPosition(instance)
	if not instance or not instance.Parent then
		return nil
	end

	if displayedStep == 1 then
		                                                                         
		                                                                          
		if not targetDeck or not targetDeck.Parent then
			return nil
		end

		local half = targetDeck.Size * 0.5
		local cf = targetDeck.CFrame
		local verticalRadius = math.abs(cf.RightVector.Y) * half.X
			+ math.abs(cf.UpVector.Y) * half.Y
			+ math.abs(cf.LookVector.Y) * half.Z
		return targetDeck.Position + Vector3.new(0, verticalRadius + TARGET_ARROW_SURFACE_OFFSET, 0)
	elseif instance:IsA("BasePart") then
		return instance.Position + Vector3.new(
			0,
			instance.Size.Y * 0.5 + TARGET_ARROW_SURFACE_OFFSET,
			0
		)
	elseif instance:IsA("Model") then
		local ok, boxCFrame, boxSize = pcall(instance.GetBoundingBox, instance)
		if ok and boxCFrame and boxSize then
			return boxCFrame.Position + Vector3.new(
				0,
				boxSize.Y * 0.5 + TARGET_ARROW_SURFACE_OFFSET,
				0
			)
		end
	end
	return nil
end

local function createInvisibleAnchor(name, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = Vector3.new(0.05, 0.05, 0.05)
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Parent = parent
	return part
end

local function ensureBeamVisual()
	if beamFolder
		and beamFolder.Parent
		and tutorialOutlineBeam
		and tutorialOutlineBeam.Parent
		and tutorialBeam
		and tutorialBeam.Parent
	then
		return
	end

	beamFolder = Instance.new("Folder")
	beamFolder.Name = "FirstTimeTutorialBeam_Local"
	beamFolder.Parent = Workspace

	goalPart = createInvisibleAnchor("GoalAnchor", beamFolder)
	goalAttachment = Instance.new("Attachment")
	goalAttachment.Name = "GoalAttachment"
	goalAttachment.Parent = goalPart

	tutorialOutlineBeam = Instance.new("Beam")
	tutorialOutlineBeam.Name = "StreamingArrowOutline"
	tutorialOutlineBeam.Attachment1 = goalAttachment
	tutorialOutlineBeam.Color = ColorSequence.new(Color3.fromRGB(0, 0, 0))
	tutorialOutlineBeam.Transparency = NumberSequence.new(0)
	tutorialOutlineBeam.Width0 = ARROW_BEAM_WIDTH + ARROW_OUTLINE_EXTRA_WIDTH
	tutorialOutlineBeam.Width1 = ARROW_BEAM_WIDTH + ARROW_OUTLINE_EXTRA_WIDTH
	tutorialOutlineBeam.CurveSize0 = 0
	tutorialOutlineBeam.CurveSize1 = 0
	tutorialOutlineBeam.FaceCamera = true
	tutorialOutlineBeam.Segments = 1
	tutorialOutlineBeam.Texture = ARROW_TEXTURE_ID
	tutorialOutlineBeam.TextureLength = ARROW_TEXTURE_LENGTH
	tutorialOutlineBeam.TextureMode = Enum.TextureMode.Static
	tutorialOutlineBeam.TextureSpeed = ARROW_TEXTURE_SPEED
	tutorialOutlineBeam.LightEmission = 0
	tutorialOutlineBeam.LightInfluence = 0
	tutorialOutlineBeam.ZOffset = 0
	tutorialOutlineBeam.Enabled = false
	tutorialOutlineBeam.Parent = beamFolder

	tutorialBeam = Instance.new("Beam")
	tutorialBeam.Name = "StreamingArrowBeam"
	tutorialBeam.Attachment1 = goalAttachment
	tutorialBeam.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
	tutorialBeam.Transparency = NumberSequence.new(0)
	tutorialBeam.Width0 = ARROW_BEAM_WIDTH
	tutorialBeam.Width1 = ARROW_BEAM_WIDTH
	tutorialBeam.CurveSize0 = 0
	tutorialBeam.CurveSize1 = 0
	tutorialBeam.FaceCamera = true
	tutorialBeam.Segments = 1
	tutorialBeam.Texture = ARROW_TEXTURE_ID
	tutorialBeam.TextureLength = ARROW_TEXTURE_LENGTH
	tutorialBeam.TextureMode = Enum.TextureMode.Static
	tutorialBeam.TextureSpeed = ARROW_TEXTURE_SPEED
	tutorialBeam.LightEmission = 0
	tutorialBeam.LightInfluence = 0
	tutorialBeam.ZOffset = 0.05
	tutorialBeam.Enabled = false
	tutorialBeam.Parent = beamFolder
end

local function ensurePlayerAttachment()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return nil
	end

	if playerAttachment and playerAttachment.Parent == root then
		return playerAttachment
	end
	if playerAttachment then
		playerAttachment:Destroy()
	end

	local oldAttachment = root:FindFirstChild("FirstTimeTutorialStart_Local")
	if oldAttachment then
		oldAttachment:Destroy()
	end

	playerAttachment = Instance.new("Attachment")
	playerAttachment.Name = "FirstTimeTutorialStart_Local"
	playerAttachment.Position = Vector3.new(0, PLAYER_ARROW_HEIGHT_OFFSET, 0)
	playerAttachment.Parent = root
	return playerAttachment
end

local function setBeamVisible(visible)
	if tutorialOutlineBeam then
		tutorialOutlineBeam.Enabled = visible == true
	end
	if tutorialBeam then
		tutorialBeam.Enabled = visible == true
	end
end

refreshBeamVisual = function()
	ensureBeamVisual()
	setBeamVisible(false)

	if displayedStep ~= 1 and displayedStep ~= 2 then
		return
	end
	if not target or not target.Parent then
		return
	end

	local startAttachment = ensurePlayerAttachment()
	local destination = getTargetPosition(target)
	if not startAttachment or not destination or not goalPart or not goalPart.Parent then
		return
	end

	goalPart.Position = destination
	tutorialOutlineBeam.Attachment0 = startAttachment
	tutorialOutlineBeam.Attachment1 = goalAttachment
	tutorialBeam.Attachment0 = startAttachment
	tutorialBeam.Attachment1 = goalAttachment
	setBeamVisible((startAttachment.WorldPosition - destination).Magnitude >= 2)
end

local function destroyBeamVisual()
	disconnectTargetWatch()
	disconnectTargetAncestryWatch()
	disconnectTargetDeckWatch()
	targetSearchSerial += 1
	target = nil
	targetDeck = nil
	if playerAttachment then
		playerAttachment:Destroy()
		playerAttachment = nil
	end
	if beamFolder then
		beamFolder:Destroy()
		beamFolder = nil
	end
	goalPart = nil
	goalAttachment = nil
	tutorialOutlineBeam = nil
	tutorialBeam = nil
end

local function syncTutorialState()
	local active
	local step
	if FORCE_TUTORIAL_FOR_EVERYONE then
		active = reviewActive
		step = active and reviewStep or 0
	else
		active = player:GetAttribute("FirstTimeTutorialActive") == true
		step = active and math.floor(tonumber(player:GetAttribute("FirstTimeTutorialStep")) or 0) or 0
	end
	if step ~= 1 and step ~= 2 then
		step = 0
	end

	if step ~= displayedStep then
		displayedStep = step
		setBeamVisible(false)
		resolveTarget(step)
	elseif active then
		refreshBeamVisual()
	end

	if not active then
		displayedStep = 0
		destroyBeamVisual()
	end
end

local beginReviewStep

local function finishReviewStep(expectedStep)
	if not FORCE_TUTORIAL_FOR_EVERYONE
		or reviewActive ~= true
		or reviewStep ~= expectedStep
	then
		return
	end

	reviewToken += 1
	reviewStep = 0
	playCompleteSound()
	syncTutorialState()

	if expectedStep == 1 then
		local transitionToken = reviewToken
		task.delay(BETWEEN_STEPS_SECONDS, function()
			if reviewActive == true and reviewToken == transitionToken then
				beginReviewStep(2)
			end
		end)
		return
	end

	reviewActive = false
	syncTutorialState()
	print("[FirstTimeTutorial] V306HQ forced review completed locally.")
end

beginReviewStep = function(step)
	if not FORCE_TUTORIAL_FOR_EVERYONE then
		return
	end

	reviewToken += 1
	reviewActive = true
	reviewStep = step
	syncTutorialState()

	local timeoutToken = reviewToken
	task.delay(STEP_TIMEOUT_SECONDS, function()
		if reviewActive == true
			and reviewStep == step
			and reviewToken == timeoutToken
		then
			finishReviewStep(step)
		end
	end)

	if step == 1 and player:GetAttribute("OnTutorialBrownTreadmill") == true then
		task.defer(finishReviewStep, 1)
	elseif step == 2
		and tonumber(player:GetAttribute("LastCompletedSafeZone")) == (IS_NEW_WORLD1 and 1 or 2)
	then
		task.defer(finishReviewStep, 2)
	end
end

local lastTransitionSerial = math.max(
	0,
	math.floor(tonumber(player:GetAttribute("FirstTimeTutorialTransitionSerial")) or 0)
)

player:GetAttributeChangedSignal("FirstTimeTutorialActive"):Connect(function()
	if not FORCE_TUTORIAL_FOR_EVERYONE then
		syncTutorialState()
	end
end)
player:GetAttributeChangedSignal("FirstTimeTutorialStep"):Connect(function()
	if not FORCE_TUTORIAL_FOR_EVERYONE then
		syncTutorialState()
	end
end)
player:GetAttributeChangedSignal("FirstTimeTutorialTransitionSerial"):Connect(function()
	if FORCE_TUTORIAL_FOR_EVERYONE then
		return
	end
	local serial = math.max(
		0,
		math.floor(tonumber(player:GetAttribute("FirstTimeTutorialTransitionSerial")) or 0)
	)
	if serial > lastTransitionSerial then
		playCompleteSound()
	end
	lastTransitionSerial = serial
end)

player:GetAttributeChangedSignal("OnTutorialBrownTreadmill"):Connect(function()
	if FORCE_TUTORIAL_FOR_EVERYONE
		and player:GetAttribute("OnTutorialBrownTreadmill") == true
	then
		finishReviewStep(1)
	end
end)

player:GetAttributeChangedSignal("LastCompletedSafeZone"):Connect(function()
	if FORCE_TUTORIAL_FOR_EVERYONE
		and tonumber(player:GetAttribute("LastCompletedSafeZone")) == (IS_NEW_WORLD1 and 1 or 2)
	then
		finishReviewStep(2)
	end
end)

script.Destroying:Connect(function()
	reviewToken += 1
	reviewActive = false
	if characterAddedConnection then
		characterAddedConnection:Disconnect()
		characterAddedConnection = nil
	end
	destroyBeamVisual()
end)

local function refreshWhenCharacterReady(character)
	task.spawn(function()
		local root = character:WaitForChild("HumanoidRootPart", 10)
		if root
			and player.Character == character
			and (displayedStep == 1 or displayedStep == 2)
		then
			refreshBeamVisual()
		end
	end)
end

characterAddedConnection = player.CharacterAdded:Connect(function(character)
	refreshWhenCharacterReady(character)
end)

if player.Character then
	refreshWhenCharacterReady(player.Character)
end

if FORCE_TUTORIAL_FOR_EVERYONE then
	beginReviewStep(1)
	print("[FirstTimeTutorial] V306HQ outlined official streaming-Beam review started immediately at Step 1.")
else
	syncTutorialState()
	print("[FirstTimeTutorial] V306KBV one-time-only outlined streaming-Beam renderer ready; Stage 1 is the new World 1 Win target.")
end
