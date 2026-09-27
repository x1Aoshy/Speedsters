                                                            
                                               
  
                                                                                   
                                                                                
                                                                                 
                                                                               
                                                            

local Players = game:GetService("Players")
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
if Config.IsNewWorld1Map ~= true then
	return
end

local MAP_ROOT_NAME = tostring(Config.NewWorld1MapMarkerName or "neworld1")
local mapRoot = Workspace:FindFirstChild(MAP_ROOT_NAME) or Workspace:WaitForChild(MAP_ROOT_NAME, 20)
if not mapRoot then
	warn("[NewWorld1PlayerHitbox] Workspace." .. MAP_ROOT_NAME .. " is missing")
	return
end

local remotes = ReplicatedStorage:WaitForChild("Remotes", 20)
local contactRemote = remotes and remotes:WaitForChild("NewWorld1HazardContact", 20)
if not contactRemote or not contactRemote:IsA("RemoteEvent") then
	warn("[NewWorld1PlayerHitbox] NewWorld1HazardContact remote is missing")
	return
end

                                                                            
                                                                                   
local PLAYER_HITBOX_SIZE = Vector3.new(4.4, 6.2, 4.4)
local CONTACT_COOLDOWN = 0.12
local VALID_HAZARD_KEYS = {
	Cylinder = true,
	Hammer = true,
	Laser = true,
	PressDown = true,
	Fast = true,
	LavaUp = true,
	Lava = true,
}

local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Include
overlapParams.FilterDescendantsInstances = { mapRoot }
overlapParams.MaxParts = 0
overlapParams.RespectCanCollide = false

local character
local humanoid
local rootPart
local lastContactAt = -math.huge

local function normalizeName(value)
	return tostring(value or ""):lower():gsub("[^%w]", "")
end

local hammerCharacterParams = OverlapParams.new()
hammerCharacterParams.FilterType = Enum.RaycastFilterType.Include
hammerCharacterParams.MaxParts = 1
hammerCharacterParams.RespectCanCollide = false

                                                                             
                                                                                
                                                                 
local HAMMER_VISIBLE_BODY_NAMES = {
	head = true,
	torso = true,
	uppertorso = true,
	lowertorso = true,
	leftarm = true,
	rightarm = true,
	leftleg = true,
	rightleg = true,
	leftupperarm = true,
	leftlowerarm = true,
	lefthand = true,
	rightupperarm = true,
	rightlowerarm = true,
	righthand = true,
	leftupperleg = true,
	leftlowerleg = true,
	leftfoot = true,
	rightupperleg = true,
	rightlowerleg = true,
	rightfoot = true,
}
local hammerBodyConnections = {}

local function refreshHammerBodyFilter()
	local bodyParts = {}
	if character then
		for _, child in ipairs(character:GetChildren()) do
			if child:IsA("BasePart") and HAMMER_VISIBLE_BODY_NAMES[normalizeName(child.Name)] then
				table.insert(bodyParts, child)
			end
		end
	end
	hammerCharacterParams.FilterDescendantsInstances = bodyParts
end

local function disconnectHammerBodyConnections()
	for _, connection in ipairs(hammerBodyConnections) do
		connection:Disconnect()
	end
	table.clear(hammerBodyConnections)
end

local function bindCharacter(newCharacter)
	disconnectHammerBodyConnections()
	character = newCharacter
	humanoid = newCharacter and newCharacter:FindFirstChildOfClass("Humanoid") or nil
	rootPart = newCharacter and newCharacter:FindFirstChild("HumanoidRootPart") or nil

	if newCharacter then
		if not humanoid then
			humanoid = newCharacter:WaitForChild("Humanoid", 10)
		end
		if not rootPart then
			rootPart = newCharacter:WaitForChild("HumanoidRootPart", 10)
		end
		refreshHammerBodyFilter()
		table.insert(hammerBodyConnections, newCharacter.ChildAdded:Connect(function(child)
			if child:IsA("BasePart") then
				refreshHammerBodyFilter()
			end
		end))
		table.insert(hammerBodyConnections, newCharacter.ChildRemoved:Connect(function(child)
			if child:IsA("BasePart") then
				refreshHammerBodyFilter()
			end
		end))
	else
		hammerCharacterParams.FilterDescendantsInstances = {}
	end
end

bindCharacter(localPlayer.Character)
localPlayer.CharacterAdded:Connect(bindCharacter)
localPlayer.CharacterRemoving:Connect(function(removingCharacter)
	if character == removingCharacter then
		character = nil
		humanoid = nil
		rootPart = nil
	end
end)


                                                                              
                                                                                 
                                                                            
                                                                    
task.spawn(function()
	local BOSS_AREA_NORMALIZED = "bossarea"
	local TARGET_VOLUME = 1.8
	local FADE_TIME = 0.55
	local CHECK_INTERVAL = 0.08
	local BELOW_PADDING = 3
	local HEIGHT_ABOVE = 12
	local BACKGROUND_MUSIC_NAME = "SpeedsterBackgroundMusic"
	local BACKGROUND_MUSIC_NORMAL_VOLUME = 0.24
	local BACKGROUND_MUSIC_DUCKED_VOLUME = 0.06
	local OWN_DUCK_ATTRIBUTE = "BossAreaAmbienceDuck"
	local OTHER_DUCK_ATTRIBUTE = "ZoomArenaAmbienceDuck"
	local WALLY_DUCK_ATTRIBUTE = "WallyArenaAmbienceDuck"
	local TRACKS = {
		{ Name = "BossAreaAmbience110509599718307", SoundId = "rbxassetid://110509599718307" },
		{ Name = "BossAreaAmbience89362634813966", SoundId = "rbxassetid://89362634813966" },
	}

	local function normalized(value)
		return tostring(value or ""):lower():gsub("[^%w]", "")
	end

	local bossArea = nil
	for _, object in ipairs(mapRoot:GetDescendants()) do
		if normalized(object.Name) == BOSS_AREA_NORMALIZED
			and (object:IsA("BasePart") or object:IsA("Model"))
		then
			bossArea = object
			break
		end
	end

	if not bossArea then
		local addedConnection
		addedConnection = mapRoot.DescendantAdded:Connect(function(object)
			if not bossArea
				and normalized(object.Name) == BOSS_AREA_NORMALIZED
				and (object:IsA("BasePart") or object:IsA("Model"))
			then
				bossArea = object
			end
		end)
		local deadline = os.clock() + 20
		while mapRoot.Parent and not bossArea and os.clock() < deadline do
			task.wait(0.10)
		end
		if addedConnection then
			addedConnection:Disconnect()
		end
	end

	if not bossArea then
		warn("[NewWorld1PlayerHitbox] V306KBN BossArea audio could not find exact Workspace.neworld1 BossArea")
		return
	end

	local function getBounds(area)
		if area:IsA("BasePart") then
			return area.CFrame, area.Size
		end
		local ok, cframe, size = pcall(function()
			return area:GetBoundingBox()
		end)
		if ok then
			return cframe, size
		end
		return nil, nil
	end

	local areaCFrame, areaSize = getBounds(bossArea)
	if not areaCFrame or not areaSize then
		warn("[NewWorld1PlayerHitbox] V306KBN BossArea has no readable bounds: " .. bossArea:GetFullName())
		return
	end

	local function pointInside(point)
		local localPoint = areaCFrame:PointToObjectSpace(point)
		local half = areaSize * 0.5
		return math.abs(localPoint.X) <= half.X
			and math.abs(localPoint.Z) <= half.Z
			and localPoint.Y >= -half.Y - BELOW_PADDING
			and localPoint.Y <= half.Y + HEIGHT_ABOVE
	end

	local sounds = {}
	for _, definition in ipairs(TRACKS) do
		local sound = SoundService:FindFirstChild(definition.Name)
		if sound and not sound:IsA("Sound") then
			sound:Destroy()
			sound = nil
		end
		if not sound then
			sound = Instance.new("Sound")
			sound.Name = definition.Name
			sound.Parent = SoundService
		end
		sound.SoundId = definition.SoundId
		sound.Volume = 0
		sound.Looped = true
		sound.PlaybackSpeed = 1
		sound:SetAttribute("BossAreaOnly", true)
		sound:SetAttribute("TargetVolume", TARGET_VOLUME)
		sound:SetAttribute("ConfiguredVersion", "V306KBN")
		table.insert(sounds, sound)
	end

	localPlayer:SetAttribute("BossAreaAudioConfigured", true)
	localPlayer:SetAttribute("BossAreaAudioOwner", "NewWorld1MapMotionV306KBN")

	task.spawn(function()
		local ok, preloadError = pcall(function()
			ContentProvider:PreloadAsync(sounds)
		end)
		if not ok then
			warn("[NewWorld1PlayerHitbox] V306KBN BossArea audio preload warning: " .. tostring(preloadError))
		end
	end)

	local activeTweens = {}
	local insideArea = false
	local transitionToken = 0

	local function setBackgroundMusicVolume(volume)
		local music = SoundService:FindFirstChild(BACKGROUND_MUSIC_NAME)
		if music and music:IsA("Sound") then
			local ownDuck = volume <= BACKGROUND_MUSIC_DUCKED_VOLUME
			music:SetAttribute(OWN_DUCK_ATTRIBUTE, ownDuck)
			local shouldDuck = ownDuck
				or music:GetAttribute(OTHER_DUCK_ATTRIBUTE) == true
				or music:GetAttribute(WALLY_DUCK_ATTRIBUTE) == true
			music.Volume = shouldDuck and BACKGROUND_MUSIC_DUCKED_VOLUME or BACKGROUND_MUSIC_NORMAL_VOLUME
		end
	end

	local function tweenVolume(sound, volume)
		local oldTween = activeTweens[sound]
		if oldTween then
			oldTween:Cancel()
		end
		local tween = TweenService:Create(
			sound,
			TweenInfo.new(FADE_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
			{ Volume = volume }
		)
		activeTweens[sound] = tween
		tween:Play()
	end

	local function setInside(nextInside)
		if insideArea == nextInside then
			return
		end
		insideArea = nextInside
		transitionToken += 1
		local token = transitionToken
		localPlayer:SetAttribute("BossAreaAudioActive", nextInside)
		if nextInside then
			setBackgroundMusicVolume(BACKGROUND_MUSIC_DUCKED_VOLUME)
			for _, sound in ipairs(sounds) do
				sound.TimePosition = 0
				sound.Volume = math.max(sound.Volume, 0.12)
				if not sound.IsPlaying then
					sound:Play()
				end
				tweenVolume(sound, TARGET_VOLUME)
			end
		else
			for _, sound in ipairs(sounds) do
				tweenVolume(sound, 0)
			end
			setBackgroundMusicVolume(BACKGROUND_MUSIC_NORMAL_VOLUME)
			task.delay(FADE_TIME + 0.05, function()
				if transitionToken ~= token or insideArea then
					return
				end
				for _, sound in ipairs(sounds) do
					sound:Stop()
					sound.Volume = 0
				end
			end)
		end
	end

	setBackgroundMusicVolume(BACKGROUND_MUSIC_NORMAL_VOLUME)
	print("[NewWorld1PlayerHitbox] V306KBN BossArea audio bound | area=" .. bossArea:GetFullName() .. " | sounds=110509599718307,89362634813966 | volume=1.8")

	while mapRoot.Parent and bossArea.Parent do
		local currentCharacter = localPlayer.Character
		local currentRoot = currentCharacter and currentCharacter:FindFirstChild("HumanoidRootPart")
		setInside(currentRoot and currentRoot:IsA("BasePart") and pointInside(currentRoot.Position) or false)
		if insideArea then
			setBackgroundMusicVolume(BACKGROUND_MUSIC_DUCKED_VOLUME)
			for _, sound in ipairs(sounds) do
				if not sound.IsPlaying then
					sound:Play()
				end
				if sound.Volume < TARGET_VOLUME * 0.9 then
					sound.Volume = TARGET_VOLUME
				end
			end
		end
		task.wait(CHECK_INTERVAL)
	end
end)

local function getHazardKey(part)
	local key = part:GetAttribute("NewWorld1HazardKey")
	if VALID_HAZARD_KEYS[tostring(key or "")] then
		return tostring(key)
	end
	return nil
end

local function cylinderMetrics(part)
	local size = part.Size
	if part:IsA("Part") and part.Shape == Enum.PartType.Cylinder then
		                                                          
		return "X", math.max(0.05, size.X * 0.5 - 0.03), math.max(0.05, math.min(size.Y, size.Z) * 0.5 - 0.03)
	end
	local yz = math.abs(size.Y - size.Z) / math.max(size.Y, size.Z, 0.001)
	local xz = math.abs(size.X - size.Z) / math.max(size.X, size.Z, 0.001)
	local xy = math.abs(size.X - size.Y) / math.max(size.X, size.Y, 0.001)
	if yz <= xz and yz <= xy then
		return "X", math.max(0.05, size.X * 0.5 - 0.03), math.max(0.05, math.min(size.Y, size.Z) * 0.5 - 0.03)
	elseif xz <= xy then
		return "Y", math.max(0.05, size.Y * 0.5 - 0.03), math.max(0.05, math.min(size.X, size.Z) * 0.5 - 0.03)
	end
	return "Z", math.max(0.05, size.Z * 0.5 - 0.03), math.max(0.05, math.min(size.X, size.Y) * 0.5 - 0.03)
end

local function pointInsideExactCylinder(point, part)
	local localPoint = part.CFrame:PointToObjectSpace(point)
	local axis, halfLength, radius = cylinderMetrics(part)
	local axial, radialA, radialB
	if axis == "X" then
		axial, radialA, radialB = localPoint.X, localPoint.Y, localPoint.Z
	elseif axis == "Y" then
		axial, radialA, radialB = localPoint.Y, localPoint.X, localPoint.Z
	else
		axial, radialA, radialB = localPoint.Z, localPoint.X, localPoint.Y
	end
	return math.abs(axial) <= halfLength and radialA * radialA + radialB * radialB <= radius * radius
end

local function exactCylinderTouchesCharacter(part)
	if not character or not part or not part.Parent
		or part:GetAttribute("NewWorld1ExactCylinderHazardKBJ") ~= true
		or part:GetAttribute("NewWorld1CylinderLethalActiveKBJ") ~= true
	then
		return false
	end

	                                                                             
	                                                                               

	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("BasePart") and pointInsideExactCylinder(child.Position, part) then
			return true
		end
	end
	return false
end

local function exactHammerTouchesCharacter(part)
	if not character or not part or not part.Parent
		or part:GetAttribute("NewWorld1ExactHammerHazardKBM") ~= true
	then
		return false
	end

	                                                                            
	                                                                          
	local touching = Workspace:GetPartsInPart(part, hammerCharacterParams)
	return #touching > 0
end

local function killLocalForHazard(hazardKey)
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	if localPlayer:GetAttribute("StageTeleportInvulnerable") == true then
		return
	end
	local now = os.clock()
	if now - lastContactAt < CONTACT_COOLDOWN then
		return
	end
	lastContactAt = now

	                                                                      
	humanoid.Health = 0
	contactRemote:FireServer(hazardKey)
end

RunService.RenderStepped:Connect(function()
	if not character or not character.Parent or not humanoid or humanoid.Health <= 0 or not rootPart or not rootPart.Parent then
		return
	end

	local touchedParts = Workspace:GetPartBoundsInBox(rootPart.CFrame, PLAYER_HITBOX_SIZE, overlapParams)
	for _, part in ipairs(touchedParts) do
		if part:GetAttribute("NewWorld1ExactCylinderHazardKBJ") == true then
			                                                                       
			                                                                         
			if exactCylinderTouchesCharacter(part) then
				killLocalForHazard("Cylinder")
				return
			end
		else
			local hazardKey = getHazardKey(part)
			if hazardKey == "Hammer" then
				if exactHammerTouchesCharacter(part) then
					killLocalForHazard("Hammer")
					return
				end
			elseif hazardKey then
				killLocalForHazard(hazardKey)
				return
			end
		end
	end
end)

print("[NewWorld1PlayerHitbox] V306KBV active | teleport invulnerability respected | exact hammer/cylinder contact preserved | obstacle motion server-owned")
