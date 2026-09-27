         
                                                                             
                                                              

local ContentProvider = game:GetService("ContentProvider")
local SoundService = game:GetService("SoundService")

local PurchaseButtonSound = {}

local SOUND_NAME = "PermanentWinsMultiplierClickSound"
local SOUND_ID = "rbxassetid://72264591133889"

                                                                              
                                                                        
for _, staleName in ipairs({"PermanentSpeedMultiplierClickSound", "SpeedProductUiClickSound"}) do
	local staleSound = SoundService:FindFirstChild(staleName)
	if staleSound and staleSound:IsA("Sound") then
		staleSound:Destroy()
	end
end

local clickSound = SoundService:FindFirstChild(SOUND_NAME)
if not clickSound or not clickSound:IsA("Sound") then
	clickSound = Instance.new("Sound")
	clickSound.Name = SOUND_NAME
	clickSound.Parent = SoundService
end

clickSound.SoundId = SOUND_ID
clickSound.Volume = 0.65
clickSound.PlaybackSpeed = 1

task.spawn(function()
	pcall(function()
		ContentProvider:PreloadAsync({clickSound})
	end)
end)

function PurchaseButtonSound.Play()
	clickSound.TimePosition = 0
	SoundService:PlayLocalSound(clickSound)
end

return PurchaseButtonSound
