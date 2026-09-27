local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
-- The one rule for "this part kills on touch", shared with the server's arbiter (H6).
local HazardNames = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("HazardNames"))

local character = script.Parent
local localPlayer = Players.LocalPlayer
local humanoid = character:WaitForChild("Humanoid", 10)
local rootPart = character:WaitForChild("HumanoidRootPart", 10)

if not humanoid or not rootPart then
	return
end

humanoid.BreakJointsOnDeath = false
humanoid.RequiresNeck = false
humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)

         
                                                                              
                                                                        
                                                                           
                                                                          
                                                                       
                                                                          
  
                                                                           
                                                                              
                                                                             
local stockAnimateGuards = setmetatable({}, { __mode = "k" })

local function forceStockAnimateDisabled(candidate)
	if not candidate
		or candidate.Name ~= "Animate"
		or not candidate:IsA("LocalScript")
	then
		return
	end

	                                                                            
	                                                                           
	pcall(function()
		candidate.Enabled = false
	end)
	pcall(function()
		candidate.Disabled = true
	end)

	if stockAnimateGuards[candidate] then
		return
	end

	local guardConnection = nil
	local connected = pcall(function()
		guardConnection = candidate:GetPropertyChangedSignal("Enabled"):Connect(function()
			if candidate.Parent == character then
				forceStockAnimateDisabled(candidate)
			end
		end)
	end)

	if not connected then
		pcall(function()
			guardConnection = candidate:GetPropertyChangedSignal("Disabled"):Connect(function()
				if candidate.Parent == character then
					forceStockAnimateDisabled(candidate)
				end
			end)
		end)
	end

	stockAnimateGuards[candidate] = guardConnection or true
end

for _, child in ipairs(character:GetChildren()) do
	forceStockAnimateDisabled(child)
end

local stockAnimateAddedConnection = character.ChildAdded:Connect(function(child)
	forceStockAnimateDisabled(child)
end)

         
                                         
  
                                           
                                    
                                     
                                     
                                    
                                     
  
                                                                           
                                                                                 
                                                               

local IDLE_ANIMATION_ID = "rbxassetid://72327681713648"
local MOVE_ANIMATION_ID = "rbxassetid://124536617516408"
local TREADMILL_ANIMATION_ID = "rbxassetid://108196819514550"
local JUMP_ANIMATION_ID = "rbxassetid://88686087786377"
local FALL_ANIMATION_ID = "rbxassetid://105655805870914"

                                                
  
                                                                            
                                                                                  
  
                                                       
                      
                      
                      
                      
                      
                      
                      
                      
  
                                                              
                                                               
                                                            
local HIGH_SPEED_START = 200
local HIGH_SPEED_STEP = 20
local HIGH_SPEED_STEP_PLAYBACK = 0.17
local HIGH_SPEED_START_PLAYBACK = 1.91
local ABSURD_REAL_SPEED_CAP = 100000

local AFTERIMAGE_START_SPEED = 48
local AFTERIMAGE_FULL_SPEED = 300
local AFTERIMAGE_SLOW_INTERVAL = 0.15
local AFTERIMAGE_FAST_INTERVAL = 0.075
local AFTERIMAGE_MIN_LIFETIME = 0.24
local AFTERIMAGE_MAX_LIFETIME = 0.32
local MAX_AFTERIMAGES = 5
local AFTERIMAGE_COLOR = Color3.fromRGB(28, 17, 38)
-- Phones and tablets (most players): fewer, sparser ghosts of the body alone, with no
-- Highlight (each one is a full-screen pass, and a device can only draw 31).
local UserInputService = game:GetService("UserInputService")
local LOW_POWER = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
if LOW_POWER then
	MAX_AFTERIMAGES = 3
	AFTERIMAGE_SLOW_INTERVAL = 0.24
	AFTERIMAGE_FAST_INTERVAL = 0.12
end

local function assetNumber(animationId)
	return tostring(animationId or ""):match("%d+")
end

local CUSTOM_NUMBERS = {
	[assetNumber(IDLE_ANIMATION_ID)] = true,
	[assetNumber(MOVE_ANIMATION_ID)] = true,
	[assetNumber(TREADMILL_ANIMATION_ID)] = true,
	[assetNumber(JUMP_ANIMATION_ID)] = true,
	[assetNumber(FALL_ANIMATION_ID)] = true,
}

local BLOCKED_OLD_ANIMATION_IDS = {
	["180436334"] = true,                                                       
	["83598519628860"] = true,
	["79315214233216"] = true,
	["106624508073696"] = true,
	["94274826249836"] = true,
	["91648305938374"] = true,
	["94497294180969"] = true,
	["126880825855394"] = true,                             
}

local SERVER_REFERENCE_NAME = "SpeedsterServerAnimatorReference"
local animationSync = ReplicatedStorage
	:WaitForChild("Remotes")
	:WaitForChild("SpeedsterAnimationSync", 15)
local animatorReference = humanoid:FindFirstChild(SERVER_REFERENCE_NAME)
	or humanoid:WaitForChild(SERVER_REFERENCE_NAME, 15)

if not animatorReference or not animatorReference:IsA("ObjectValue") then
	warn("[R15SpeedsterRun] V306HB exact server Animator reference was not available; animation controller stopped safely.")
	return
end

local animator = nil
local animatorDeadline = os.clock() + 15
repeat
	local referencedAnimator = animatorReference.Value
	if referencedAnimator
		and referencedAnimator:IsA("Animator")
		and referencedAnimator.Parent == humanoid
	then
		animator = referencedAnimator
		break
	end
	task.wait()
until os.clock() >= animatorDeadline or not character.Parent

if not animator then
	warn("[R15SpeedsterRun] V306HB referenced server Animator did not replicate in time; animation controller stopped safely.")
	return
end

                                                                             
                                                                              
                                                                         
local function stopAndDestroyTrack(track)
	pcall(function()
		track:Stop(0)
	end)
	pcall(function()
		track:Destroy()
	end)
end

for _, child in ipairs(humanoid:GetChildren()) do
	if child:IsA("Animator") then
		for _, track in ipairs(child:GetPlayingAnimationTracks()) do
			stopAndDestroyTrack(track)
		end

		if child ~= animator then
			child:Destroy()
		end
	end
end

local function loadTrack(name, animationId, priority, looped)
	local animation = Instance.new("Animation")
	animation.Name = name .. "_Animation"
	animation.AnimationId = animationId

	local ok, result = pcall(function()
		return animator:LoadAnimation(animation)
	end)

	if not ok then
		warn(string.format(
			"[R15SpeedsterRun] V306HB %s LoadAnimation failed: %s",
			name,
			tostring(result)
		))
		return nil
	end

	local track = result
	track.Name = name .. "_Track"
	track.Priority = priority
	track.Looped = looped
	return track
end

local idleTrack = loadTrack(
	"V306GY_Idle",
	IDLE_ANIMATION_ID,
	Enum.AnimationPriority.Action,
	true
)

local moveTrack = loadTrack(
	"V306GY_WalkRun",
	MOVE_ANIMATION_ID,
	Enum.AnimationPriority.Action,
	true
)

local treadmillTrack = loadTrack(
	"V306GY_TreadmillWalk",
	TREADMILL_ANIMATION_ID,
	Enum.AnimationPriority.Action,
	true
)

local jumpTrack = loadTrack(
	"V306GY_Jump",
	JUMP_ANIMATION_ID,
	Enum.AnimationPriority.Action2,
	false
)

local fallTrack = loadTrack(
	"V306GY_Fall",
	FALL_ANIMATION_ID,
	Enum.AnimationPriority.Action2,
	true
)

local authoritativeTracks = {}
for _, track in ipairs({ idleTrack, moveTrack, treadmillTrack, jumpTrack, fallTrack }) do
	if track then
		authoritativeTracks[track] = true
	end
end

local function stopCompetingTrack(track)
	if authoritativeTracks[track] then
		return
	end

	local animation = track.Animation
	local number = animation and assetNumber(animation.AnimationId) or nil

	                                                                      
	                                                                         
	                                                            
	if CUSTOM_NUMBERS[number] == true
		or BLOCKED_OLD_ANIMATION_IDS[number] == true
	then
		stopAndDestroyTrack(track)
	end
end

for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
	stopCompetingTrack(track)
end

local animationPlayedConnection = animator.AnimationPlayed:Connect(stopCompetingTrack)

local function horizontalSpeed()
	local velocity = rootPart.AssemblyLinearVelocity
	return Vector3.new(velocity.X, 0, velocity.Z).Magnitude
end

local function minimumSelectorMultiplier()
	local multipliers = Config.WalkSpeedSelectorMultipliers
	if type(multipliers) ~= "table" then
		return 1
	end

	local minimum = math.huge
	for _, value in pairs(multipliers) do
		value = tonumber(value)
		if value and value > 0 then
			minimum = math.min(minimum, value)
		end
	end

	if minimum == math.huge then
		return 1
	end

	return minimum
end

local BASE_REAL_WALK_SPEED = math.max(0.01, tonumber(Config.RealWalkSpeedMin) or 8)
local MIN_SELECTED_REAL_SPEED = math.max(
	0.01,
	BASE_REAL_WALK_SPEED * minimumSelectorMultiplier()
)
local REFERENCE_REAL_WALK_SPEED = math.max(
	BASE_REAL_WALK_SPEED + 0.01,
	tonumber(Config.RealWalkSpeedAtReference) or 300
)

local function intendedRealMovementSpeed()
	                                                                       
	                                                                          
	                                                                                
	local speed = tonumber(localPlayer:GetAttribute("RealWalkSpeedSelected"))
		or tonumber(humanoid.WalkSpeed)
		or horizontalSpeed()

	if localPlayer:GetAttribute("IsBoosting") == true then
		speed *= tonumber(Config.BoostWalkSpeedMultiplier or Config.BoostSpeedMultiplier) or 1.7
	end

	                                                                                
	                                                                              
	                                 
	return math.max(0, speed, horizontalSpeed())
end

local function calculateMovePlaybackSpeed(realSpeed)
	realSpeed = math.max(0, tonumber(realSpeed) or 0)

	if realSpeed < 20 then
		return 0.54
	elseif realSpeed < 40 then
		return 0.74
	elseif realSpeed < 60 then
		return 0.94
	elseif realSpeed < 80 then
		return 1.17
	elseif realSpeed < 100 then
		return 1.34
	elseif realSpeed < 150 then
		return 1.48
	elseif realSpeed < 170 then
		return 1.54
	elseif realSpeed < 200 then
		return 1.74
	end

	                                                                         
	                                                                              
	local cappedRealSpeed = math.min(realSpeed, ABSURD_REAL_SPEED_CAP)
	local completedSteps = math.floor((cappedRealSpeed - HIGH_SPEED_START) / HIGH_SPEED_STEP)
	return HIGH_SPEED_START_PLAYBACK + (completedSteps * HIGH_SPEED_STEP_PLAYBACK)
end

local currentMovePlaybackSpeed = calculateMovePlaybackSpeed(intendedRealMovementSpeed())

-- 2026-09-25 (owner: never walk in a race): while the player is in a race (RaceActive: staged,
-- countdown, running, the staging box) the move track is always the fast run: the race's own
-- speed (Race/RaceInputClient's RaceLocalSpeed, not the lobby dial or the sprint), never under
-- RACE_MIN_PLAYBACK (the 100-150 studs/s band) and never over RACE_MAX_PLAYBACK. On the grid
-- the racer stands (idle) under the Flash crouch of Race/RacePoseClient.
local RACE_MIN_PLAYBACK = 1.48
local RACE_MAX_PLAYBACK = 2.6
local RACE_AIR_GRACE = 0.25
local raceAirSince, raceJumped = nil, false
local function inRace()
	return localPlayer ~= nil and localPlayer:GetAttribute("RaceActive") == true
end

local function updateMovePlaybackSpeed()
	if not moveTrack then
		return
	end

	                                                             
	                                                                            
	                                                          
	if inRace() then
		local raceSpeed = math.max(tonumber(localPlayer:GetAttribute("RaceLocalSpeed")) or 0, horizontalSpeed())
		currentMovePlaybackSpeed = math.clamp(calculateMovePlaybackSpeed(raceSpeed), RACE_MIN_PLAYBACK, RACE_MAX_PLAYBACK)
	else
		currentMovePlaybackSpeed = calculateMovePlaybackSpeed(intendedRealMovementSpeed())
	end
	moveTrack:AdjustSpeed(currentMovePlaybackSpeed)
end

local currentMode = "none"
local jumpStartedAt = 0

local function stopTrack(track, fade)
	if track and track.IsPlaying then
		track:Stop(fade or 0.06)
	end
end

local function stopAllAuthoritative(exceptTrack)
	for _, track in ipairs({ idleTrack, moveTrack, treadmillTrack, jumpTrack, fallTrack }) do
		if track ~= exceptTrack then
			stopTrack(track, 0.05)
		end
	end
end

local function playLoop(track, fade)
	if not track then
		return
	end

	stopAllAuthoritative(track)

	if not track.IsPlaying then
		track.TimePosition = 0
		track:Play(fade or 0.06, 1, 1)
	end

	track.Looped = true
	if track == moveTrack then
		track:AdjustSpeed(currentMovePlaybackSpeed)
	else
		track:AdjustSpeed(1)
	end
end

local function playJump()
	if not jumpTrack then
		return
	end

	stopAllAuthoritative(jumpTrack)

	if not jumpTrack.IsPlaying then
		jumpTrack.TimePosition = 0
		jumpTrack.Looped = false
		jumpTrack:Play(0.04, 1, 1)
	end
end

local function setMode(wantedMode)
	if currentMode == wantedMode then
		                                                              
		if wantedMode == "idle" then
			playLoop(idleTrack, 0.06)
		elseif wantedMode == "move" then
			playLoop(moveTrack, 0.06)
		elseif wantedMode == "treadmill" then
			playLoop(treadmillTrack, 0.06)
		elseif wantedMode == "fall" then
			playLoop(fallTrack, 0.04)
		elseif wantedMode == "jump" and jumpTrack and not jumpTrack.IsPlaying then
			                                                                     
			                                                                  
		end
		return
	end

	currentMode = wantedMode

	if wantedMode == "idle" then
		playLoop(idleTrack, 0.08)
	elseif wantedMode == "move" then
		playLoop(moveTrack, 0.06)
	elseif wantedMode == "treadmill" then
		playLoop(treadmillTrack, 0.06)
	elseif wantedMode == "jump" then
		jumpStartedAt = os.clock()
		playJump()
	elseif wantedMode == "fall" then
		playLoop(fallTrack, 0.04)
	else
		stopAllAuthoritative(nil)
	end
end

local function updateAuthoritativeAnimation(deltaTime)
	if humanoid.Health <= 0
		or humanoid.Sit
		or rootPart.Anchored
		or character:GetAttribute("Ragdolled") == true
	then
		setMode("none")
		return
	end

	local state = humanoid:GetState()
	local onTreadmill = localPlayer:GetAttribute("IsOnTreadmill") == true
	local moving = horizontalSpeed() > 0.50
		or humanoid.MoveDirection.Magnitude > 0.05
	local verticalVelocity = rootPart.AssemblyLinearVelocity.Y
	local airborne = humanoid.FloorMaterial == Enum.Material.Air
		or state == Enum.HumanoidStateType.Jumping
		or state == Enum.HumanoidStateType.Freefall
	-- 2026-09-25 (owner: never walk in a race): at race speed the floor's seams lift the racer
	-- for a frame or two; that is not a jump or a fall, so in a race only a real jump, or more
	-- than RACE_AIR_GRACE seconds off the floor, leaves the run.
	if not airborne then
		raceAirSince, raceJumped = nil, false
	elseif inRace() then
		raceJumped = raceJumped or state == Enum.HumanoidStateType.Jumping
		local since = raceAirSince or os.clock()
		raceAirSince = since
		if not raceJumped and os.clock() - since < RACE_AIR_GRACE then
			airborne = false
		end
	end

	                                                
	                                                                             
	                                                                                
	                      
	  
	                  
	                             
	                             
	  
	                                                                              
	                                                                     
	if airborne then
		if state == Enum.HumanoidStateType.Jumping or verticalVelocity >= 0 then
			setMode("jump")
		else
			setMode("fall")
		end
	elseif onTreadmill then
		setMode("treadmill")
	elseif moving then
		setMode("move")
		updateMovePlaybackSpeed()
	else
		setMode("idle")
	end
end

local authoritativeConnection = RunService.PreAnimation:Connect(updateAuthoritativeAnimation)

                                                                             
                                                                               
                                                                                
                                                                               
                                                     
local lastRepublishSerial = 0
local function republishCurrentAnimation(serial)
	serial = tonumber(serial) or 0
	if serial <= lastRepublishSerial or not character.Parent or humanoid.Health <= 0 then
		return
	end
	lastRepublishSerial = serial

	updateAuthoritativeAnimation(0)
	local wantedMode = currentMode
	if wantedMode == "none" then
		return
	end

	currentMode = "none"
	                                                                           
	                                                                              
	                                                                        
	for track in pairs(authoritativeTracks) do
		if track.IsPlaying then
			track:Stop(0)
		end
	end
	setMode(wantedMode)
	if wantedMode == "move" then
		updateMovePlaybackSpeed()
	end
end

if animationSync and animationSync:IsA("RemoteEvent") then
	animationSync.OnClientEvent:Connect(function(action, serial)
		if action == "RepublishCurrent" then
			republishCurrentAnimation(serial)
		end
	end)

	                                                                        
	                                        
	task.defer(function()
		if character.Parent and localPlayer.Character == character then
			animationSync:FireServer("ObserverReady", character)
		end
	end)
end

task.delay(1.5, function()
	if not character.Parent then
		return
	end

	print(string.format(
		"[R15SpeedsterRun] V306HB diagnostic | rig=%s | idle=%.3f | move=%.3f | treadmill=%.3f | jump=%.3f | fall=%.3f | mode=%s | IsOnTreadmill=%s",
		tostring(humanoid.RigType),
		idleTrack and idleTrack.Length or -1,
		moveTrack and moveTrack.Length or -1,
		treadmillTrack and treadmillTrack.Length or -1,
		jumpTrack and jumpTrack.Length or -1,
		fallTrack and fallTrack.Length or -1,
		currentMode,
		tostring(localPlayer:GetAttribute("IsOnTreadmill") == true)
	))
	print(string.format(
		"[R15SpeedsterRun] V306HB run-speed | realSpeed=%.2f | playback=%.2fx | +0.17x per +20 real speed after 200 | safetyCapRealSpeed=%d",
		intendedRealMovementSpeed(),
		currentMovePlaybackSpeed,
		ABSURD_REAL_SPEED_CAP
	))
end)

print(string.format(
	"[R15SpeedsterRun] V306HB loaded | single controller=true | reusable tracks=5 | stock Animate disabled=true | full-fidelity server Animator=%s | observer-ready republish=true | rig=%s | idle=%s | walk/run=%s | treadmill=%s | jump=%s | fall=%s",
	animator:GetFullName(),
	tostring(humanoid.RigType),
	IDLE_ANIMATION_ID,
	MOVE_ANIMATION_ID,
	TREADMILL_ANIMATION_ID,
	JUMP_ANIMATION_ID,
	FALL_ANIMATION_ID
))

                                                                              
                                                                      
local function horizontalSpeed()
	local velocity = rootPart.AssemblyLinearVelocity
	return Vector3.new(velocity.X, 0, velocity.Z).Magnitude
end

local groundRayParams = RaycastParams.new()
groundRayParams.FilterType = Enum.RaycastFilterType.Exclude
groundRayParams.FilterDescendantsInstances = { character }
groundRayParams.IgnoreWater = false

local SUPPORT_EXTRA_DEPTH = 1.10
local SUPPORT_SIDE_OFFSET = 0.82
local SUPPORT_FORWARD_OFFSET = 0.68
local SUPPORT_MIN_NORMAL_Y = 0.08

local function horizontalUnit(vector, fallback)
	local flat = Vector3.new(vector.X, 0, vector.Z)
	if flat.Magnitude <= 0.001 then
		return fallback
	end
	return flat.Unit
end

local function closeSurfaceSupportProbe()
	local castDistance = math.max(
		3.75,
		humanoid.HipHeight + (rootPart.Size.Y * 0.5) + SUPPORT_EXTRA_DEPTH
	)
	local right = horizontalUnit(rootPart.CFrame.RightVector, Vector3.xAxis)
	local forward = horizontalUnit(rootPart.CFrame.LookVector, Vector3.zAxis)
	local offsets = {
		Vector3.zero,
		right * SUPPORT_SIDE_OFFSET,
		-right * SUPPORT_SIDE_OFFSET,
		forward * SUPPORT_FORWARD_OFFSET,
		-forward * SUPPORT_FORWARD_OFFSET,
	}
	local castVector = Vector3.new(0, -castDistance, 0)

	for _, offset in ipairs(offsets) do
		local result = Workspace:Raycast(rootPart.Position + offset, castVector, groundRayParams)
		if result and result.Instance and result.Normal.Y > SUPPORT_MIN_NORMAL_Y then
			return true
		end
	end

	return false
end

local BLOCK_AFTERIMAGE_STATES = {
	[Enum.HumanoidStateType.Climbing] = true,
	[Enum.HumanoidStateType.Dead] = true,
	[Enum.HumanoidStateType.FallingDown] = true,
	[Enum.HumanoidStateType.GettingUp] = true,
	[Enum.HumanoidStateType.Jumping] = true,
	[Enum.HumanoidStateType.Physics] = true,
	[Enum.HumanoidStateType.PlatformStanding] = true,
	[Enum.HumanoidStateType.Ragdoll] = true,
	[Enum.HumanoidStateType.Seated] = true,
	[Enum.HumanoidStateType.Swimming] = true,
}

local function movementForAfterimages()
	if humanoid.Health <= 0 or humanoid.Sit or rootPart.Anchored then
		return false, 0
	end

	local state = humanoid:GetState()
	if BLOCK_AFTERIMAGE_STATES[state] then
		return false, 0
	end

	if (state == Enum.HumanoidStateType.Freefall or humanoid.FloorMaterial == Enum.Material.Air)
		and not closeSurfaceSupportProbe()
	then
		return false, 0
	end

	local speed = horizontalSpeed()
	return speed > 0.5, speed
end

for _, oldFolderName in ipairs({
	"_V239LocalSpeedAfterimages",
	"_V240LocalShiftAfterimages",
}) do
	local oldFolder = Workspace:FindFirstChild(oldFolderName)
	if oldFolder and oldFolder:IsA("Folder") then
		oldFolder:Destroy()
	end
end

local afterimageFolder = Instance.new("Folder")
afterimageFolder.Name = "_V240LocalShiftAfterimages"
afterimageFolder.Parent = Workspace
-- The folder lives in the Workspace, so it must go with the character however the
-- character goes: a death cleans it up below, but a respawn or a trip to another world
-- replaces the character without one.
character.AncestryChanged:Connect(function()
	if not character:IsDescendantOf(Workspace) and afterimageFolder.Parent then
		afterimageFolder:Destroy()
	end
end)

local afterimageElapsed = AFTERIMAGE_SLOW_INTERVAL

local function trimAfterimages()
	local ghosts = afterimageFolder:GetChildren()
	while #ghosts >= MAX_AFTERIMAGES do
		ghosts[1]:Destroy()
		table.remove(ghosts, 1)
	end
end

-- 2026-09-22: declared before createAfterimage. It used to come after it, so the
-- `afterimagesAlive = true` below wrote a global, updateAfterimages read a local that
-- stayed false, and the ghosts were never cleared when the boost stopped.
local afterimagesAlive = false

local function createAfterimage(intensity)
	if not character.Parent or not afterimageFolder.Parent then
		return
	end

	trimAfterimages()

	local ghost = Instance.new("Model")
	ghost.Name = "SpeedShadow"
	local lifetime = AFTERIMAGE_MIN_LIFETIME
		+ (AFTERIMAGE_MAX_LIFETIME - AFTERIMAGE_MIN_LIFETIME) * intensity
	local startingTransparency = 0.56 - (0.10 * intensity)

	-- On phones only the body itself (limbs, and a worn skin rig) is copied.
	local sources = if LOW_POWER then character:GetChildren() else character:GetDescendants()
	if LOW_POWER then
		local morph = character:FindFirstChild("SkinMorph")
		for _, piece in ipairs(morph and morph:GetChildren() or {}) do
			table.insert(sources, piece)
		end
	end
	for _, descendant in ipairs(sources) do
		if descendant:IsA("BasePart")
			and descendant ~= rootPart
			and descendant.Transparency < 0.98
			and not descendant:FindFirstAncestorOfClass("Tool")
		then
			local clonedSuccessfully, clone = pcall(function()
				return descendant:Clone()
			end)

			if clonedSuccessfully and clone and clone:IsA("BasePart") then
				for _, child in ipairs(clone:GetChildren()) do
					if child:IsA("SpecialMesh") then
						child.TextureId = ""
					else
						child:Destroy()
					end
				end
				clone.Name = descendant.Name
				clone.Anchored = true
				clone.CanCollide = false
				clone.CanTouch = false
				clone.CanQuery = false
				clone.CastShadow = false
				clone.Massless = true
				clone.Material = Enum.Material.SmoothPlastic
				clone.Color = AFTERIMAGE_COLOR
				clone.Transparency = startingTransparency
				clone.LocalTransparencyModifier = 0
				clone.CFrame = descendant.CFrame

				if clone:IsA("MeshPart") then
					pcall(function()
						clone.TextureID = ""
					end)
				end

				clone.Parent = ghost
				TweenService:Create(
					clone,
					TweenInfo.new(lifetime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ Transparency = 1 }
				):Play()
			end
		end
	end

	if #ghost:GetChildren() == 0 then
		ghost:Destroy()
		return
	end

	if not LOW_POWER then
		local silhouette = Instance.new("Highlight")
		silhouette.Name = "DarkSilhouette"
		silhouette.DepthMode = Enum.HighlightDepthMode.Occluded
		silhouette.FillColor = AFTERIMAGE_COLOR
		silhouette.FillTransparency = 0.28 + (0.10 * (1 - intensity))
		silhouette.OutlineTransparency = 1
		silhouette.Parent = ghost
	end

	ghost.Parent = afterimageFolder
	afterimagesAlive = true
	Debris:AddItem(ghost, lifetime + 0.04)
end

local function clearAfterimages()
	for _, ghost in ipairs(afterimageFolder:GetChildren()) do
		ghost:Destroy()
	end
end

local function updateAfterimages(deltaTime)
	local shiftBoostActive = localPlayer
		and localPlayer:GetAttribute("IsBoosting") == true

	if not shiftBoostActive then
		afterimageElapsed = AFTERIMAGE_SLOW_INTERVAL
		-- Only when there is something to clear: this runs every frame of every walk.
		if afterimagesAlive then
			afterimagesAlive = false
			clearAfterimages()
		end
		return
	end

	local running, speed = movementForAfterimages()
	if not running or speed < AFTERIMAGE_START_SPEED then
		afterimageElapsed = AFTERIMAGE_SLOW_INTERVAL
		return
	end

	local intensity = math.clamp(
		(speed - AFTERIMAGE_START_SPEED)
			/ (AFTERIMAGE_FULL_SPEED - AFTERIMAGE_START_SPEED),
		0,
		1
	)
	local interval = AFTERIMAGE_SLOW_INTERVAL
		+ (AFTERIMAGE_FAST_INTERVAL - AFTERIMAGE_SLOW_INTERVAL) * intensity
	afterimageElapsed += math.min(deltaTime, 0.1)

	if afterimageElapsed >= interval then
		afterimageElapsed %= interval
		createAfterimage(intensity)
	end
end

local updateConnection = RunService.Heartbeat:Connect(updateAfterimages)

local clientRagdolled = false

local function applyClientRagdoll(enabled: boolean)
	if enabled then
		if clientRagdolled then return end
		clientRagdolled = true

		if authoritativeConnection then
			authoritativeConnection:Disconnect()
			authoritativeConnection = nil
		end
		stopAllAuthoritative(nil)

		local animator = humanoid:FindFirstChildOfClass("Animator")
		if animator then
			for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
				track:Stop(0)
			end
		end

		humanoid.AutoRotate = false
		humanoid.PlatformStand = true
		humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
		humanoid:ChangeState(Enum.HumanoidStateType.Physics)

		-- Disable limb Motor6Ds immediately on client (preserve RootJoint so RootPart stays with Torso)
		local torsoPart = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
		if humanoid.RigType == Enum.HumanoidRigType.R6 and torsoPart then
			for _, motor in ipairs(torsoPart:GetChildren()) do
				if motor:IsA("Motor6D") and not motor:HasTag("DontModifyOnRagdoll") then
					motor.Enabled = false
				end
			end
		else
			for _, desc in ipairs(character:GetDescendants()) do
				if desc:IsA("Motor6D") and desc.Name ~= "Root" and desc.Name ~= "RootJoint" and not desc:HasTag("DontModifyOnRagdoll") then
					desc.Enabled = false
				end
			end
		end

		-- Enable BallSocketConstraints & Colliders immediately on client
		local joints = character:FindFirstChild("RagdollComponents")
		if joints then
			for _, item in ipairs(joints:GetChildren()) do
				if item:IsA("BallSocketConstraint") then
					item.Enabled = true
				elseif item:IsA("BasePart") then
					item.CanCollide = true
				elseif (item:IsA("WeldConstraint") or item:IsA("Weld")) and item.Name == "RagdollWeld" then
					item.Enabled = true
					local rj = rootPart and rootPart:FindFirstChild("RootJoint")
					if rj and rj:IsA("Motor6D") then
						rj.Enabled = false
					end
				end
			end
		end

		-- Disable visual limb collision to prevent self-clipping
		for _, limb in ipairs(character:GetChildren()) do
			if limb:IsA("BasePart") and limb.Name ~= "HumanoidRootPart" then
				limb.CanCollide = false
			end
		end
	else
		if not clientRagdolled then return end
		if humanoid.Health <= 0 then return end
		clientRagdolled = false

		local joints = character:FindFirstChild("RagdollComponents")
		if joints then
			for _, item in ipairs(joints:GetChildren()) do
				if item:IsA("BallSocketConstraint") then
					item.Enabled = false
				elseif item:IsA("BasePart") then
					item.CanCollide = false
				elseif (item:IsA("WeldConstraint") or item:IsA("Weld")) and item.Name == "RagdollWeld" then
					item.Enabled = false
					local rj = rootPart and rootPart:FindFirstChild("RootJoint")
					if rj and rj:IsA("Motor6D") then
						rj.Enabled = true
					end
				end
			end
		end

		local torsoPart = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
		if humanoid.RigType == Enum.HumanoidRigType.R6 and torsoPart then
			for _, motor in ipairs(torsoPart:GetChildren()) do
				if motor:IsA("Motor6D") then
					motor.Enabled = true
					motor.Transform = CFrame.identity
				end
			end
		else
			for _, desc in ipairs(character:GetDescendants()) do
				if desc:IsA("Motor6D") then
					desc.Enabled = true
					desc.Transform = CFrame.identity
				end
			end
		end

		humanoid.PlatformStand = false
		humanoid.AutoRotate = true
		humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)

		if not authoritativeConnection then
			authoritativeConnection = RunService.PreAnimation:Connect(updateAuthoritativeAnimation)
		end
	end
end

local LOCAL_DEATH_CONFIRM_SECONDS = 2.5
local localDeathWatch = false

-- A death only this client saw is judged by the server (Gameplay/LocalDeathArbiter, 2026-09-25,
-- H6): it confirms it (a real death, the usual revive offer) or overrules it (a respawn at
-- the stage start, nothing lost). Found in the background so the character never waits on it.
local localDeathClaim = nil
task.spawn(function()
	local remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
	local remote = remotes and remotes:WaitForChild("LocalDeathClaim", 10)
	if remote and remote:IsA("RemoteEvent") then
		localDeathClaim = remote
	end
end)

local function claimLocalDeath(hitPart, seenAt)
	if localDeathClaim then
		localDeathClaim:FireServer(hitPart, seenAt)
	end
end

local function onLocalDeath()
	if authoritativeConnection then
		authoritativeConnection:Disconnect()
		authoritativeConnection = nil
	end
	if animationPlayedConnection then
		animationPlayedConnection:Disconnect()
		animationPlayedConnection = nil
	end
	if stockAnimateAddedConnection then
		stockAnimateAddedConnection:Disconnect()
		stockAnimateAddedConnection = nil
	end
	for animateScript, guardConnection in pairs(stockAnimateGuards) do
		if typeof(guardConnection) == "RBXScriptConnection" then
			guardConnection:Disconnect()
		end
		stockAnimateGuards[animateScript] = nil
	end

	applyClientRagdoll(true)

	if updateConnection then
		updateConnection:Disconnect()
		updateConnection = nil
	end
	if afterimageFolder.Parent then
		afterimageFolder:Destroy()
	end

	-- A death only this client saw (a local hazard prediction the server turned down) would
	-- leave the player lying there forever: the server respawns only deaths it sees. If the
	-- server has not marked this character dead after a moment, it is sent to the arbiter
	-- with no part: confirmed only if a claim for this character was already accepted.
	if not localDeathWatch then
		localDeathWatch = true
		task.delay(LOCAL_DEATH_CONFIRM_SECONDS, function()
			if character.Parent and localPlayer.Character == character and character:GetAttribute("Dead") ~= true then
				claimLocalDeath(nil, nil)
			end
		end)
	end
end

humanoid.Died:Connect(onLocalDeath)
humanoid.HealthChanged:Connect(function(health)
	if health <= 0 then
		onLocalDeath()
	end
end)
humanoid.StateChanged:Connect(function(oldState, newState)
	if newState == Enum.HumanoidStateType.Dead then
		onLocalDeath()
	end
end)

character:GetAttributeChangedSignal("Ragdolled"):Connect(function()
	local isRag = character:GetAttribute("Ragdolled") == true
	applyClientRagdoll(isRag)
end)

character:GetAttributeChangedSignal("Dead"):Connect(function()
	if character:GetAttribute("Dead") == true then
		onLocalDeath()
	end
end)

-- Arrival grace for the touch prediction (2026-09-21). Writers stamp
-- StageTeleportArrivalGraceUntilServerTime on the clock clients share. World 3's stage trips
-- (World3StageTeleportService) only stamp the server's os.clock() copy, which a client cannot
-- compare with anything, so any change of that attribute also opens a 1.75 s window here.
-- Without it a World 3 runner landing on a hazard inside the server's grace killed themself.
local ARRIVAL_GRACE_FALLBACK_SECONDS = 1.75
local observedArrivalGraceUntil = -math.huge
if localPlayer then
	localPlayer:GetAttributeChangedSignal("StageTeleportArrivalGraceUntil"):Connect(function()
		observedArrivalGraceUntil = Workspace:GetServerTimeNow() + ARRIVAL_GRACE_FALLBACK_SECONDS
	end)
end

local function isInArrivalGrace(p)
	local now = Workspace:GetServerTimeNow()
	return (tonumber(p:GetAttribute("StageTeleportArrivalGraceUntilServerTime")) or -math.huge) > now
		or observedArrivalGraceUntil > now
end

-- Instant touch prediction on lethal hazards (Lava / Kill bricks / Lasers)
local function setupLethalTouchPrediction()
	local function checkPart(hitPart)
		if not hitPart or not hitPart:IsA("BasePart") then return end
		if hitPart:IsDescendantOf(character) then return end

		-- Never treat other player characters or humanoid models as map hazards
		local hitModel = hitPart:FindFirstAncestorOfClass("Model")
		if hitModel then
			if Players:GetPlayerFromCharacter(hitModel) or hitModel:FindFirstChildOfClass("Humanoid") then
				return
			end
		end

		local nameLower = string.lower(hitPart.Name)
		local parentLower = hitPart.Parent and string.lower(hitPart.Parent.Name) or ""
		-- Shared/HazardNames (the rule the arbiter checks too): lethal names, the
		-- "laserplatform" exception, and a "Kill script" child.
		local isLethal = HazardNames.IsNamedLethalPart(hitPart)
		-- Lava frozen by the admin Snow event is ice: it does not kill (the server's kill
		-- scripts skip it too, so a death here would never be real and never respawn).
		if isLethal and (hitPart:GetAttribute("AdminFrozenLava") == true
			or (Workspace:GetAttribute("AdminWorldFrozen") == true
				and (string.find(nameLower, "lava", 1, true) ~= nil or string.find(parentLower, "lava", 1, true) ~= nil)))
		then
			return
		end
		if isLethal and humanoid and humanoid.Health > 0 then
			local p = Players.LocalPlayer
			if p and (p:GetAttribute("StageTeleportInvulnerable") == true
				-- The shared clock (2026-09-21): the plain attribute is the server's os.clock().
				or isInArrivalGrace(p)) then
				return
			end
			-- Where the server never kills, neither does the prediction (2026-09-25, H6): a
			-- safe zone, and a race (its spike tiles only trip, RaceSpikeTile).
			if hitPart:GetAttribute("SafeZoneProtected") == true
				or character:GetAttribute("SafeZoneProtected") == true
				or (p and (p:GetAttribute("SafeZoneProtected") == true or p:GetAttribute("RaceActive") == true))
				or hitPart:GetAttribute("RaceArenaPart") ~= nil or hitPart:GetAttribute("RaceSpikeTile") ~= nil
			then
				return
			end
			claimLocalDeath(hitPart, Workspace:GetServerTimeNow())
			humanoid.Health = 0
			onLocalDeath()
		end
	end

	for _, limb in ipairs(character:GetChildren()) do
		if limb:IsA("BasePart") then
			limb.Touched:Connect(checkPart)
		end
	end
end

setupLethalTouchPrediction()

character:SetAttribute("VortexR15AnimationVersion", "V306HB")
character:SetAttribute("VortexAnimationPlaybackMode", "R6FasterRunScale20Step_JumpAscentFallDescent")
character:SetAttribute("VortexAfterimageStartStudsPerSecond", AFTERIMAGE_START_SPEED)
character:SetAttribute("VortexAfterimagesRequireShift", true)
