                                              
                                                                                  
                                                                                
                                                                                        

local Players = game:GetService("Players")
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
if Config.IsWorld2Place ~= true then return end

local player = Players.LocalPlayer
local AREA_NAME = "SixSevenArea"
local TARGET_VOLUME = 1.8
local FADE_TIME = 0.35
local CHECK_INTERVAL = 0.06
local BELOW_PADDING = 3
local HEIGHT_ABOVE = 12
local BACKGROUND_MUSIC_NAME = "SpeedsterBackgroundMusic"
local BACKGROUND_MUSIC_NORMAL_VOLUME = 0.24
local BACKGROUND_MUSIC_DUCKED_VOLUME = 0.06
local OWN_DUCK_ATTRIBUTE = "World2SixSevenAreaAmbienceDuck"

local OLD_TRACK_NAMES = {
	"World2SixSevenArea140244308309117",
	"World2SixSevenArea132307272475720",
}
for _, oldName in ipairs(OLD_TRACK_NAMES) do
	local oldSound = SoundService:FindFirstChild(oldName)
	if oldSound and oldSound:IsA("Sound") then
		oldSound:Stop()
		oldSound:Destroy()
	end
end

local TRACKS = {
	{ Name = "World2SixSevenArea95039478522269", SoundId = "rbxassetid://95039478522269" },
}

local function normalizeName(value)
	return tostring(value or ""):lower():gsub("[^%w]", "")
end

local function getWorldAABBForParts(parts)
	local minPoint = Vector3.new(math.huge, math.huge, math.huge)
	local maxPoint = Vector3.new(-math.huge, -math.huge, -math.huge)
	local found = false
	for _, part in ipairs(parts) do
		if part and part.Parent and part:IsA("BasePart") then
			local half = part.Size * 0.5
			local cframe = part.CFrame
			local extent = Vector3.new(
				math.abs(cframe.RightVector.X) * half.X + math.abs(cframe.UpVector.X) * half.Y + math.abs(cframe.LookVector.X) * half.Z,
				math.abs(cframe.RightVector.Y) * half.X + math.abs(cframe.UpVector.Y) * half.Y + math.abs(cframe.LookVector.Y) * half.Z,
				math.abs(cframe.RightVector.Z) * half.X + math.abs(cframe.UpVector.Z) * half.Y + math.abs(cframe.LookVector.Z) * half.Z
			)
			local low = part.Position - extent
			local high = part.Position + extent
			minPoint = Vector3.new(math.min(minPoint.X, low.X), math.min(minPoint.Y, low.Y), math.min(minPoint.Z, low.Z))
			maxPoint = Vector3.new(math.max(maxPoint.X, high.X), math.max(maxPoint.Y, high.Y), math.max(maxPoint.Z, high.Z))
			found = true
		end
	end
	if not found then return nil, nil end
	local center = (minPoint + maxPoint) * 0.5
	return CFrame.new(center), maxPoint - minPoint
end

local function collectAreaBounds()
	local target = normalizeName(AREA_NAME)
	local bounds = {}
	for _, object in ipairs(Workspace:GetDescendants()) do
		if normalizeName(object.Name) == target then
			if object:IsA("BasePart") then
				table.insert(bounds, { CFrame = object.CFrame, Size = object.Size })
			elseif object:IsA("Model") then
				local ok, cframe, size = pcall(function() return object:GetBoundingBox() end)
				if ok and cframe and size then table.insert(bounds, { CFrame = cframe, Size = size }) end
			elseif object:IsA("Folder") or object:IsA("Configuration") then
				local parts = {}
				for _, descendant in ipairs(object:GetDescendants()) do
					if descendant:IsA("BasePart") then table.insert(parts, descendant) end
				end
				local cframe, size = getWorldAABBForParts(parts)
				if cframe and size then table.insert(bounds, { CFrame = cframe, Size = size }) end
			end
		end
	end
	return bounds
end

local areaBounds = collectAreaBounds()
if #areaBounds == 0 then
	local deadline = os.clock() + 25
	repeat
		task.wait(0.25)
		areaBounds = collectAreaBounds()
	until #areaBounds > 0 or os.clock() >= deadline
end

local function pointInsideArea(point)
	for _, bound in ipairs(areaBounds) do
		local localPoint = bound.CFrame:PointToObjectSpace(point)
		local half = bound.Size * 0.5
		if math.abs(localPoint.X) <= half.X
			and math.abs(localPoint.Z) <= half.Z
			and localPoint.Y >= -half.Y - BELOW_PADDING
			and localPoint.Y <= half.Y + HEIGHT_ABOVE
		then
			return true
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
	sound.Looped = true
	sound.PlaybackSpeed = 1
	sound:SetAttribute("World2SixSevenAreaOnly", true)
	sound:SetAttribute("TargetVolume", TARGET_VOLUME)
	sound:SetAttribute("ConfiguredVersion", "V306IF")
	table.insert(sounds, sound)
end

player:SetAttribute("World2SixSevenAreaAudioConfigured", true)
player:SetAttribute("World2SixSevenAreaResolvedBounds", #areaBounds)

task.spawn(function()
	local ok, preloadError = pcall(function()
		ContentProvider:PreloadAsync(sounds)
	end)
	if not ok then
		warn("[World2SixSevenAreaAmbience] Audio preload warning: " .. tostring(preloadError))
	end
end)

task.delay(8, function()
	for _, sound in ipairs(sounds) do
		if not sound.IsLoaded then
			warn("[World2SixSevenAreaAmbience] Audio not loaded/permission unavailable: " .. sound.SoundId)
		end
	end
end)

local activeTweens = {}
local insideArea = false
local transitionToken = 0

local function setBackgroundDucked(ducked)
	local music = SoundService:FindFirstChild(BACKGROUND_MUSIC_NAME)
	if music and music:IsA("Sound") then
		music:SetAttribute(OWN_DUCK_ATTRIBUTE, ducked)
		local anyOtherDuck = music:GetAttribute("BossAreaAmbienceDuck") == true
			or music:GetAttribute("ZoomArenaAmbienceDuck") == true
			or music:GetAttribute("WallyArenaAmbienceDuck") == true
		music.Volume = (ducked or anyOtherDuck) and BACKGROUND_MUSIC_DUCKED_VOLUME or BACKGROUND_MUSIC_NORMAL_VOLUME
	end
end

local function tweenVolume(sound, target)
	local oldTween = activeTweens[sound]
	if oldTween then oldTween:Cancel() end
	local tween = TweenService:Create(
		sound,
		TweenInfo.new(FADE_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{ Volume = target }
	)
	activeTweens[sound] = tween
	tween:Play()
end

local function startLocalSound(sound)
	sound:Stop()
	sound.TimePosition = 0
	sound.Volume = math.max(sound.Volume, 0.12)
	local played = pcall(function()
		SoundService:PlayLocalSound(sound)
	end)
	if not played or not sound.IsPlaying then
		sound:Play()
	end
end

local function setInsideArea(nextInside)
	if insideArea == nextInside then return end
	insideArea = nextInside
	transitionToken += 1
	local token = transitionToken
	player:SetAttribute("World2SixSevenAreaAudioActive", nextInside)

	if nextInside then
		setBackgroundDucked(true)
		for _, sound in ipairs(sounds) do
			startLocalSound(sound)
			tweenVolume(sound, TARGET_VOLUME)
		end
		return
	end

	for _, sound in ipairs(sounds) do tweenVolume(sound, 0) end
	setBackgroundDucked(false)
	task.delay(FADE_TIME + 0.05, function()
		if transitionToken ~= token or insideArea then return end
		for _, sound in ipairs(sounds) do
			sound:Stop()
			sound.Volume = 0
		end
	end)
end

setBackgroundDucked(false)
print("[World2SixSevenAreaAmbience] V306IF ready | one replacement track | resolved bounds=" .. tostring(#areaBounds))

while true do
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local inside = root and root:IsA("BasePart") and pointInsideArea(root.Position) or false
	setInsideArea(inside)
	if inside then
		setBackgroundDucked(true)
		for _, sound in ipairs(sounds) do
			if not sound.IsPlaying then startLocalSound(sound) end
			if sound.Volume < TARGET_VOLUME * 0.9 then sound.Volume = TARGET_VOLUME end
		end
	end
	task.wait(CHECK_INTERVAL)
end
