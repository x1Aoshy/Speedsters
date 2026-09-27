       
                                                                           
                                                                    

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local WIN_PAD_SOUND_VOLUME = 1.6

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local feedbackRemote = remotes:WaitForChild("WinPadFeedback")

feedbackRemote.OnClientEvent:Connect(function(soundId)
	local sound = Instance.new("Sound")
	sound.Name = "WinPadRewardFeedback"
	sound.SoundId = tostring(soundId or "rbxassetid://136993031050456")
	sound.Volume = WIN_PAD_SOUND_VOLUME
	sound.PlaybackSpeed = 1
	sound.Parent = SoundService
	sound:Play()
	Debris:AddItem(sound, 15)
end)
