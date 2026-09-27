local SoundService = game:GetService("SoundService")

local BACKGROUND_MUSIC = "rbxassetid://1840684529"
local CLICK_SOUND = "rbxassetid://72264591133889"

local function forceSound(name, soundId, volume, looped)
	local sound = SoundService:FindFirstChild(name)
	if not sound then
		sound = Instance.new("Sound")
		sound.Name = name
		sound.Parent = SoundService
	end

	sound.SoundId = soundId
	sound.Volume = volume
	sound.Looped = looped
	sound.PlaybackSpeed = 1

	return sound
end

local Players = game:GetService("Players")
local isMuted = Players.LocalPlayer:GetAttribute("Muted") == true
local music = forceSound("SpeedsterBackgroundMusic", BACKGROUND_MUSIC, isMuted and 0 or 0.24, true)
forceSound("SpeedsterUiClickSound", CLICK_SOUND, 0.65, false)

if not music.IsPlaying then
	music:Play()
end

print("[AudioIdReset] V98 exact audio IDs restored. Music=" .. BACKGROUND_MUSIC .. " Click=" .. CLICK_SOUND)
