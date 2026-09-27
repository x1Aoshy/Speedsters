local SoundService = game:GetService("SoundService")

local CLICK_SOUND_ID = "rbxassetid://72264591133889"

local function forceClickSoundObject(sound)
	if not sound or not sound:IsA("Sound") then
		return
	end

	if sound.Name == "SpeedsterUiClickSound" or sound.Name == "SpeedsterUiClickOneShot" then
		sound.SoundId = CLICK_SOUND_ID
		sound.Volume = 0.65
		sound.PlaybackSpeed = 1
		sound.Looped = false
	end
end

local function getOrCreateMainClickSound()
	local sound = SoundService:FindFirstChild("SpeedsterUiClickSound")
	if not sound then
		sound = Instance.new("Sound")
		sound.Name = "SpeedsterUiClickSound"
		sound.Parent = SoundService
	end

	forceClickSoundObject(sound)
	return sound
end

getOrCreateMainClickSound()

SoundService.ChildAdded:Connect(function(child)
	if child:IsA("Sound") then
		task.defer(function()
			forceClickSoundObject(child)
		end)
	end
end)

task.spawn(function()
	                                                                                               
	for _ = 1, 40 do
		getOrCreateMainClickSound()
		task.wait(0.25)
	end
end)

print("[LeftButtonClickSoundAuthority] V113 left button click sound locked to " .. CLICK_SOUND_ID)
