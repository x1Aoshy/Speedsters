local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
if Config.IsWorld2Place == true then
	                                                                          
	                                               
	local player = Players.LocalPlayer
	local legacyGainSoundId = "rbxassetid://96591611478915"

	local function looksLikeLegacySpeedGainSound(sound)
		local name = sound.Name:lower()
		local parentName = sound.Parent and sound.Parent.Name:lower() or ""
		return name:find("speed")
			or name:find("gain")
			or name:find("popup")
			or name:find("treadmill")
			or parentName:find("speed")
			or parentName:find("gain")
			or parentName:find("popup")
			or parentName:find("treadmill")
	end

	local function patchLegacySound(sound)
		if sound:IsA("Sound") and looksLikeLegacySpeedGainSound(sound) then
			sound.SoundId = legacyGainSoundId
			sound.Volume = math.max(sound.Volume, 0.65)
		end
	end

	local function scanLegacy(container)
		for _, object in ipairs(container:GetDescendants()) do
			if object:IsA("Sound") then
				patchLegacySound(object)
			end
		end
	end

	local function hookLegacy(container)
		container.DescendantAdded:Connect(function(object)
			if object:IsA("Sound") then
				task.defer(patchLegacySound, object)
			end
		end)
	end

	local function hookLegacyCharacter(character)
		scanLegacy(character)
		hookLegacy(character)
	end

	scanLegacy(player:WaitForChild("PlayerGui"))
	hookLegacy(player.PlayerGui)
	if player.Character then
		hookLegacyCharacter(player.Character)
	end
	player.CharacterAdded:Connect(hookLegacyCharacter)
	scanLegacy(SoundService)
	hookLegacy(SoundService)

	print("[SpeedGainPopupSoundPatch] V96 +1 speed/treadmill popup sound forced to " .. legacyGainSoundId)
	return
end

local SPAWN_SOUND_NAME = "SpeedPopupSpawnSound"
local SPAWN_SOUND_ID = "rbxassetid://96750121076266"
local SPAWN_VOLUME = Config.SpeedPopupSoundVolume or 0.37

local function enforceExactPopupSound(sound)
	if not sound:IsA("Sound") then
		return
	end

	if sound.Name == SPAWN_SOUND_NAME then
		sound.SoundId = SPAWN_SOUND_ID
		sound.Volume = SPAWN_VOLUME
	end
end

for _, child in ipairs(SoundService:GetChildren()) do
	enforceExactPopupSound(child)
end

                                                                            
                                                                          
SoundService.ChildAdded:Connect(enforceExactPopupSound)

print("[SpeedGainPopupSoundPatch] V306KAV overlapping popup-spawn audio guard ready | sound=" .. SPAWN_SOUND_ID .. " @ " .. tostring(SPAWN_VOLUME))
