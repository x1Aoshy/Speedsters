                                                                       
                                                                            
                                                                         
                                                                        

local Players = game:GetService("Players")
local ContentProvider = game:GetService("ContentProvider")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local ARENA_NAME = "ZoomsArena"
local STAGE6_EXCLUSION_NAMES = {
	["safezone6"] = true,
	["stage06floor"] = true,
	["stage6floor"] = true,
	["stage6"] = true,
}
local TARGET_VOLUME = 1.8
local FADE_TIME = 0.55
local CHECK_INTERVAL = 0.08
local BELOW_PADDING = 3
local HEIGHT_ABOVE = 12
local BACKGROUND_MUSIC_NAME = "SpeedsterBackgroundMusic"
local BACKGROUND_MUSIC_NORMAL_VOLUME = 0.24
local BACKGROUND_MUSIC_DUCKED_VOLUME = 0.06
local OWN_DUCK_ATTRIBUTE = "ZoomArenaAmbienceDuck"
local OTHER_DUCK_ATTRIBUTE = "BossAreaAmbienceDuck"
local WALLY_DUCK_ATTRIBUTE = "WallyArenaAmbienceDuck"

local TRACKS = {
	{
		Name = "ZoomArenaAmbience113977368098146",
		SoundId = "rbxassetid://113977368098146",
	},
	{
		Name = "ZoomArenaAmbience134989380630915",
		SoundId = "rbxassetid://134989380630915",
	},
}

local function normalizeName(value)
	return tostring(value or ""):lower():gsub("[^%w]", "")
end

local function isArenaObject(object)
	return (object:IsA("BasePart") or object:IsA("Model"))
		and normalizeName(object.Name) == normalizeName(ARENA_NAME)
end

local arenaObjects = {}
local stage6ExclusionObjects = {}

local function isStage6ExclusionObject(object)
	if not (object:IsA("BasePart") or object:IsA("Model")) then
		return false
	end
	return STAGE6_EXCLUSION_NAMES[normalizeName(object.Name)] == true
end

local function addArenaObject(object)
	if isArenaObject(object) then
		arenaObjects[object] = true
	end
	if isStage6ExclusionObject(object) then
		stage6ExclusionObjects[object] = true
	end
end

local function removeArenaObject(object)
	arenaObjects[object] = nil
	stage6ExclusionObjects[object] = nil
end

for _, object in ipairs(Workspace:GetDescendants()) do
	addArenaObject(object)
end

Workspace.DescendantAdded:Connect(addArenaObject)
Workspace.DescendantRemoving:Connect(removeArenaObject)

local function getBounds(area)
	if area:IsA("BasePart") then
		return area.CFrame, area.Size
	end

	local ok, boundsCFrame, boundsSize = pcall(function()
		return area:GetBoundingBox()
	end)
	if ok then
		return boundsCFrame, boundsSize
	end
	return nil, nil
end

local function pointIsInsideArea(point, area)
	local areaCFrame, areaSize = getBounds(area)
	if not areaCFrame or not areaSize then
		return false
	end

	local localPoint = areaCFrame:PointToObjectSpace(point)
	local halfSize = areaSize * 0.5
	return math.abs(localPoint.X) <= halfSize.X
		and math.abs(localPoint.Z) <= halfSize.Z
		and localPoint.Y >= -halfSize.Y - BELOW_PADDING
		and localPoint.Y <= halfSize.Y + HEIGHT_ABOVE
end

local function pointIsInsideAnyArena(point)
	for arena in pairs(arenaObjects) do
		if arena.Parent and pointIsInsideArea(point, arena) then
			return true
		end
	end
	return false
end

local function pointIsInsideStage6(point)
	for area in pairs(stage6ExclusionObjects) do
		if area.Parent then
			local areaCFrame, areaSize = getBounds(area)
			if areaCFrame and areaSize then
				local localPoint = areaCFrame:PointToObjectSpace(point)
				local halfSize = areaSize * 0.5
				                                                                 
				                                                                  
				                                                         
				if math.abs(localPoint.X) <= halfSize.X
					and math.abs(localPoint.Z) <= halfSize.Z
					and localPoint.Y >= -halfSize.Y - 12
					and localPoint.Y <= halfSize.Y + 250
				then
					return true
				end
			end
		end
	end
	return false
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
	sound.Looped = false
	sound.PlaybackSpeed = 1
	sound:SetAttribute("ZoomArenaOnly", true)
	sound:SetAttribute("TargetVolume", TARGET_VOLUME)
	sound:SetAttribute("ConfiguredVersion", "V306BZ")
	table.insert(sounds, sound)
end

local longSound = sounds[2]

player:SetAttribute("ZoomArenaAudioConfigured", true)

task.spawn(function()
	local ok, preloadError = pcall(function()
		ContentProvider:PreloadAsync(sounds)
	end)
	if not ok then
		warn("[ZoomArenaAmbience] Audio preload warning: " .. tostring(preloadError))
	end
end)

task.delay(10, function()
	for _, sound in ipairs(sounds) do
		if not sound.IsLoaded then
			warn(
				"[ZoomArenaAmbience] Roblox did not load "
					.. sound.SoundId
					.. "; verify that this experience has permission to use the audio"
			)
		end
	end
end)

local activeTweens = {}
local insideArea = false
local transitionToken = 0
local enteredAt = -math.huge

local function isMuted()
	return player:GetAttribute("Muted") == true
end

local function isSoundEffectsEnabled()
	return player:GetAttribute("SoundEffects") ~= false
end

local function setBackgroundMusicVolume(volume)
	local music = SoundService:FindFirstChild(BACKGROUND_MUSIC_NAME)
	if music and music:IsA("Sound") then
		local ownDuck = volume <= BACKGROUND_MUSIC_DUCKED_VOLUME
		music:SetAttribute(OWN_DUCK_ATTRIBUTE, ownDuck)
		local shouldDuck = ownDuck
			or music:GetAttribute(OTHER_DUCK_ATTRIBUTE) == true
			or music:GetAttribute(WALLY_DUCK_ATTRIBUTE) == true
		if isMuted() then
			music.Volume = 0
		else
			music.Volume = shouldDuck
				and BACKGROUND_MUSIC_DUCKED_VOLUME
				or BACKGROUND_MUSIC_NORMAL_VOLUME
		end
	end
end

player:GetAttributeChangedSignal("Muted"):Connect(function()
	local music = SoundService:FindFirstChild(BACKGROUND_MUSIC_NAME)
	if music and music:IsA("Sound") then
		if isMuted() then
			music.Volume = 0
		else
			local shouldDuck = music:GetAttribute(OWN_DUCK_ATTRIBUTE) == true
				or music:GetAttribute(OTHER_DUCK_ATTRIBUTE) == true
				or music:GetAttribute(WALLY_DUCK_ATTRIBUTE) == true
			music.Volume = shouldDuck and BACKGROUND_MUSIC_DUCKED_VOLUME or BACKGROUND_MUSIC_NORMAL_VOLUME
		end
	end
end)

player:GetAttributeChangedSignal("SoundEffects"):Connect(function()
	if insideArea then
		local targetVol = isSoundEffectsEnabled() and TARGET_VOLUME or 0
		for _, sound in ipairs(sounds) do
			if targetVol > 0 and not sound.IsPlaying then
				sound:Play()
			end
			tweenVolume(sound, targetVol)
		end
	end
end)

setBackgroundMusicVolume(BACKGROUND_MUSIC_NORMAL_VOLUME)

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

local function startSynchronizedCycle()
	if not insideArea then
		return
	end

	for _, sound in ipairs(sounds) do
		sound:Stop()
		sound.TimePosition = 0
		if sound.Volume <= 0 then
			sound.Volume = 0.12
		end
		sound:Play()
	end
end

longSound.Ended:Connect(function()
	if insideArea then
		startSynchronizedCycle()
	end
end)

local function setInsideArea(nextInside)
	if insideArea == nextInside then
		return
	end

	insideArea = nextInside
	transitionToken += 1
	local token = transitionToken
	player:SetAttribute("ZoomArenaAudioActive", nextInside)

	if nextInside then
		enteredAt = os.clock()
		setBackgroundMusicVolume(BACKGROUND_MUSIC_DUCKED_VOLUME)
		for _, sound in ipairs(sounds) do
			sound.Volume = math.max(sound.Volume, 0.12)
			tweenVolume(sound, TARGET_VOLUME)
		end
		startSynchronizedCycle()
		return
	end

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

print(
	"[ZoomArenaAmbience] V306CU ready | synchronized pair | Stage 6 muted | target volume="
		.. tostring(TARGET_VOLUME)
		.. " | arena name="
		.. ARENA_NAME
)

while true do
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local inside = root
		and root:IsA("BasePart")
		and pointIsInsideAnyArena(root.Position)
		and not pointIsInsideStage6(root.Position)
		or false

	setInsideArea(inside)

	if inside then
		setBackgroundMusicVolume(BACKGROUND_MUSIC_DUCKED_VOLUME)
		                                                                      
		                                                                    
		for _, sound in ipairs(sounds) do
			if os.clock() - enteredAt >= FADE_TIME + 0.2
				and sound.Volume < TARGET_VOLUME * 0.9
			then
				sound.Volume = TARGET_VOLUME
			end
		end
	end

	task.wait(CHECK_INTERVAL)
end
