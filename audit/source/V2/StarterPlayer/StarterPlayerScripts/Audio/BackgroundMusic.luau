local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local MUSIC_SOUND_ID = "rbxassetid://1840684529"
local MUSIC_VOLUME = 0.24
local DUCKED_MUSIC_VOLUME = 0.06
local BOSS_AREA_DUCK_ATTRIBUTE = "BossAreaAmbienceDuck"
local ZOOM_ARENA_DUCK_ATTRIBUTE = "ZoomArenaAmbienceDuck"
local WALLY_ARENA_DUCK_ATTRIBUTE = "WallyArenaAmbienceDuck"

local function getMusicSoundId()
	local musicFolder = ReplicatedStorage:FindFirstChild("Music")
	if musicFolder then
		for _, child in ipairs(musicFolder:GetChildren()) do
			if child:IsA("Sound") and not child.Name:lower():find("^admin") then
				return child.SoundId
			end
		end
	end
	return MUSIC_SOUND_ID
end

local function getMusic()
	local music = SoundService:FindFirstChild("SpeedsterBackgroundMusic")

	if not music then
		music = Instance.new("Sound")
		music.Name = "SpeedsterBackgroundMusic"
		music.Parent = SoundService
	end

	return music
end

local function getMusicVolumeMultiplier()
	local val = tonumber(Players.LocalPlayer:GetAttribute("MusicVolume"))
	if val == nil then return 1 end
	return math.clamp(math.floor(val), 0, 100) / 100
end

local function forceOriginalMusic()
	local music = getMusic()
	local shouldDuck = music:GetAttribute(BOSS_AREA_DUCK_ATTRIBUTE) == true
		or music:GetAttribute(ZOOM_ARENA_DUCK_ATTRIBUTE) == true
		or music:GetAttribute(WALLY_ARENA_DUCK_ATTRIBUTE) == true

	music.SoundId = getMusicSoundId()
	-- The Settings panel's "Sound" toggle sets the Muted attribute on the
	-- local player; when muted, silence the background music entirely.
	local muted = Players.LocalPlayer:GetAttribute("Muted") == true
	local mult = getMusicVolumeMultiplier()
	local baseVol = shouldDuck and DUCKED_MUSIC_VOLUME or MUSIC_VOLUME
	music.Volume = muted and 0 or (baseVol * mult)
	music.Looped = true
	music.PlaybackSpeed = 1
	music.RollOffMode = Enum.RollOffMode.InverseTapered

	if not music.IsPlaying then
		music:Play()
	end
end

forceOriginalMusic()

Players.LocalPlayer:GetAttributeChangedSignal("Muted"):Connect(function()
	forceOriginalMusic()
end)

Players.LocalPlayer:GetAttributeChangedSignal("MusicVolume"):Connect(function()
	forceOriginalMusic()
end)

-- Master guard: If ANY script attempts to set background music volume > 0 while muted, immediately clamp it to 0
local music = getMusic()
music:GetPropertyChangedSignal("Volume"):Connect(function()
	if Players.LocalPlayer:GetAttribute("Muted") == true and music.Volume > 0 then
		music.Volume = 0
	end
end)

task.spawn(function()
	for _ = 1, 20 do
		task.wait(0.25)
		forceOriginalMusic()
	end
end)

print("[BackgroundMusic] V306EQ locked original music with strict mute protection: " .. MUSIC_SOUND_ID)
