--[[
	SfxAudioController.client.luau
	Controls general sound effects (SFX) volume via a dedicated SoundGroup in SoundService.
	Reflects the "Sound effects" toggle (SoundEffects attribute) and the "SFX Volume" slider (SfxVolume attribute).
]]

local SoundService = game:GetService("SoundService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local SFX_GROUP_NAME = "SpeedsterSFXGroup"

local function getSfxGroup(): SoundGroup
	local group = SoundService:FindFirstChild(SFX_GROUP_NAME)
	if not group then
		group = Instance.new("SoundGroup")
		group.Name = SFX_GROUP_NAME
		group.Parent = SoundService
	end
	return group
end

local sfxGroup = getSfxGroup()

local function updateSfxVolume()
	local sfxEnabled = player:GetAttribute("SoundEffects") ~= false
	local volumeVal = tonumber(player:GetAttribute("SfxVolume"))
	local volumeFrac = volumeVal and math.clamp(math.floor(volumeVal), 0, 100) / 100 or 1.0
	sfxGroup.Volume = sfxEnabled and volumeFrac or 0
end

updateSfxVolume()

player:GetAttributeChangedSignal("SoundEffects"):Connect(updateSfxVolume)
player:GetAttributeChangedSignal("SfxVolume"):Connect(updateSfxVolume)

local function routeSound(sound: Instance)
	if not sound:IsA("Sound") then return end
	if sound.Name == "SpeedsterBackgroundMusic" then return end
	if sound.SoundGroup == nil or sound.SoundGroup == sfxGroup then
		sound.SoundGroup = sfxGroup
	end
end

-- Route existing sounds
for _, sound in ipairs(SoundService:GetDescendants()) do
	routeSound(sound)
end
for _, sound in ipairs(workspace:GetDescendants()) do
	routeSound(sound)
end
for _, sound in ipairs(playerGui:GetDescendants()) do
	routeSound(sound)
end

-- Route dynamically created sounds
SoundService.DescendantAdded:Connect(routeSound)
workspace.DescendantAdded:Connect(routeSound)
playerGui.DescendantAdded:Connect(routeSound)

print("[SfxAudioController] Loaded with SpeedsterSFXGroup routing.")
