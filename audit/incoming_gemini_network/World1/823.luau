         
                                                                   
  
                                                                               
                                                                               
                                                                          
                                                                              

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local animationSync = ReplicatedStorage
	:WaitForChild("Remotes")
	:WaitForChild("SpeedsterAnimationSync")

local readyCharacterByPlayer = setmetatable({}, { __mode = "k" })
local syncSerial = 0

local function disableAnimatorLodForCharacter(character)
	task.spawn(function()
		local humanoid = character:WaitForChild("Humanoid", 15)
		local reference = humanoid and (
			humanoid:FindFirstChild("SpeedsterServerAnimatorReference")
				or humanoid:WaitForChild("SpeedsterServerAnimatorReference", 15)
		)
		local animator = reference and reference:IsA("ObjectValue") and reference.Value or nil
		if animator and animator:IsA("Animator") and animator.Parent == humanoid then
			animator.PreferLodEnabled = false
		end
	end)
end

local function bindPlayer(player)
	if player.Character then
		disableAnimatorLodForCharacter(player.Character)
	end
	player.CharacterAdded:Connect(disableAnimatorLodForCharacter)
end

for _, player in ipairs(Players:GetPlayers()) do
	bindPlayer(player)
end
Players.PlayerAdded:Connect(bindPlayer)

local function broadcastRepublish(observer, expectedCharacter)
	if observer.Parent ~= Players
		or observer.Character ~= expectedCharacter
		or readyCharacterByPlayer[observer] ~= expectedCharacter
	then
		return
	end

	syncSerial += 1
	for _, owner in ipairs(Players:GetPlayers()) do
		animationSync:FireClient(owner, "RepublishCurrent", syncSerial)
	end
end

animationSync.OnServerEvent:Connect(function(player, action, reportedCharacter)
	if action ~= "ObserverReady"
		or reportedCharacter ~= player.Character
		or not reportedCharacter
		or not reportedCharacter:IsDescendantOf(workspace)
	then
		return
	end

	                                                                           
	                                                                       
	if readyCharacterByPlayer[player] == reportedCharacter then
		return
	end

	local humanoid = reportedCharacter:FindFirstChildOfClass("Humanoid")
	local reference = humanoid and humanoid:FindFirstChild("SpeedsterServerAnimatorReference")
	local animator = reference and reference:IsA("ObjectValue") and reference.Value or nil
	if not humanoid
		or not animator
		or not animator:IsA("Animator")
		or animator.Parent ~= humanoid
		or animator:GetAttribute("SpeedsterServerAuthoritative") ~= true
	then
		return
	end

	readyCharacterByPlayer[player] = reportedCharacter

	                                                                           
	                                                                            
	                                                                           
	task.delay(0.15, broadcastRepublish, player, reportedCharacter)
	task.delay(1.00, broadcastRepublish, player, reportedCharacter)
end)

Players.PlayerRemoving:Connect(function(player)
	readyCharacterByPlayer[player] = nil
end)

print("[AnimationReplicationSync] V306GY loaded. Animator LOD is disabled and each observer receives two bounded owner-track republishes per character.")
