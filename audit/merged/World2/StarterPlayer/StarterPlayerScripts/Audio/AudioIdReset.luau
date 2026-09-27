local SoundService = game:GetService("SoundService")

-- Background music is owned by Audio/BackgroundMusic.client, which walks the
-- Config playlist. This script used to hard-force a single track id here, so the
-- two fought on every spawn - that is what the old "call it 20 times" loop in
-- BackgroundMusic was working around. Only the click sound is restored now.
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

forceSound("SpeedsterUiClickSound", CLICK_SOUND, 0.65, false)

print("[AudioIdReset] Click sound restored. Music is owned by BackgroundMusic.client.")
