local SoundService = game:GetService("SoundService")

local MUSIC_SOUND_ID = "rbxassetid://1840684529"
local MUSIC_VOLUME = 0.24
local DUCKED_MUSIC_VOLUME = 0.06
local BOSS_AREA_DUCK_ATTRIBUTE = "BossAreaAmbienceDuck"
local ZOOM_ARENA_DUCK_ATTRIBUTE = "ZoomArenaAmbienceDuck"
local WALLY_ARENA_DUCK_ATTRIBUTE = "WallyArenaAmbienceDuck"

local function getMusic()
	local music = SoundService:FindFirstChild("SpeedsterBackgroundMusic")

	if not music then
		music = Instance.new("Sound")
		music.Name = "SpeedsterBackgroundMusic"
		music.Parent = SoundService
	end

	return music
end

local function forceOriginalMusic()
	local music = getMusic()
	local shouldDuck = music:GetAttribute(BOSS_AREA_DUCK_ATTRIBUTE) == true
		or music:GetAttribute(ZOOM_ARENA_DUCK_ATTRIBUTE) == true
		or music:GetAttribute(WALLY_ARENA_DUCK_ATTRIBUTE) == true

	                                                         
	music.SoundId = MUSIC_SOUND_ID
	music.Volume = shouldDuck and DUCKED_MUSIC_VOLUME or MUSIC_VOLUME
	music.Looped = true
	music.PlaybackSpeed = 1
	music.RollOffMode = Enum.RollOffMode.InverseTapered

	if not music.IsPlaying then
		music:Play()
	end
end

forceOriginalMusic()

task.spawn(function()
	                                                                                                     
	for _ = 1, 20 do
		task.wait(0.25)
		forceOriginalMusic()
	end
end)

print("[BackgroundMusic] V306EQ locked original music with shared boss-area duck ownership: " .. MUSIC_SOUND_ID)
