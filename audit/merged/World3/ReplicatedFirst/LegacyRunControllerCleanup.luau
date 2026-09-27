         
                                                                                           
                       
                                                             
                              
  
                                                                                    
                                                                                   
                                            

local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")

local player = Players.LocalPlayer

local LEGACY_SCRIPT_NAMES = {
	RunAnimationOverride = true,
	ClearOldRunAnimation = true,
}

local LEGACY_RUN_ID = "106624508073696"

local function normalizeAnimationId(value)
	if type(value) ~= "string" then
		return ""
	end
	return value:match("(%d+)") or ""
end

local function removeLegacyScript(instance)
	if not instance or not LEGACY_SCRIPT_NAMES[instance.Name] then
		return false
	end

	if instance:IsA("LocalScript") or instance:IsA("Script") then
		pcall(function()
			instance.Disabled = true
		end)
		instance:Destroy()
		return true
	end

	return false
end

local function cleanContainer(container)
	if not container then
		return 0
	end

	local removed = 0
	for _, descendant in ipairs(container:GetDescendants()) do
		if removeLegacyScript(descendant) then
			removed += 1
		end
	end
	return removed
end

local function guardContainer(container)
	if not container then
		return
	end

	container.DescendantAdded:Connect(function(descendant)
		removeLegacyScript(descendant)
	end)
end

local removed = 0
removed += cleanContainer(StarterPlayer:FindFirstChild("StarterPlayerScripts"))
removed += cleanContainer(StarterPlayer:FindFirstChild("StarterCharacterScripts"))

guardContainer(StarterPlayer:FindFirstChild("StarterPlayerScripts"))
guardContainer(StarterPlayer:FindFirstChild("StarterCharacterScripts"))

local playerScripts = player:WaitForChild("PlayerScripts")
removed += cleanContainer(playerScripts)
guardContainer(playerScripts)

local function protectCharacter(character)
	cleanContainer(character)
	guardContainer(character)

	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end

	local animator = humanoid:FindFirstChildOfClass("Animator") or humanoid:WaitForChild("Animator", 10)
	if not animator then
		return
	end

	                                                                               
	                                                     
	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		local anim = track.Animation
		if anim and normalizeAnimationId(anim.AnimationId) == LEGACY_RUN_ID then
			track:Stop(0)
		end
	end

	animator.AnimationPlayed:Connect(function(track)
		local anim = track.Animation
		if anim and normalizeAnimationId(anim.AnimationId) == LEGACY_RUN_ID then
			track:Stop(0)
		end
	end)
end

if player.Character then
	task.spawn(protectCharacter, player.Character)
end
player.CharacterAdded:Connect(protectCharacter)

print(string.format(
	"[LegacyRunControllerCleanup] V306GD active. Removed %d confirmed legacy run controller(s); blocked old run rbxassetid://%s.",
	removed,
	LEGACY_RUN_ID
))
