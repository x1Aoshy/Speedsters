         
                                             
  
                                                                       
                                                                           
                                                                              
                                                                               
                                                                              
  
                                                                             
                                                                              

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local SERVER_REFERENCE_NAME = "SpeedsterServerAnimatorReference"
local boundPlayers = setmetatable({}, { __mode = "k" })
local boundCharacters = setmetatable({}, { __mode = "k" })
local boundAnimators = setmetatable({}, { __mode = "k" })
local boundReferences = setmetatable({}, { __mode = "k" })

local function disableWorkspaceAnimationThrottling()
	if Workspace.ClientAnimatorThrottling ~= Enum.ClientAnimatorThrottlingMode.Disabled then
		Workspace.ClientAnimatorThrottling = Enum.ClientAnimatorThrottlingMode.Disabled
	end
end

                                                                              
                                                                          
                                                                              
disableWorkspaceAnimationThrottling()
Workspace:GetPropertyChangedSignal("ClientAnimatorThrottling"):Connect(function()
	disableWorkspaceAnimationThrottling()
end)

local function bindAnimator(animator, humanoid)
	if not animator
		or not animator:IsA("Animator")
		or animator.Parent ~= humanoid
	then
		return
	end

	local existingHumanoid = boundAnimators[animator]
	if existingHumanoid == humanoid then
		if animator.PreferLodEnabled then
			animator.PreferLodEnabled = false
		end
		return
	end

	boundAnimators[animator] = humanoid
	animator.PreferLodEnabled = false

	                                                                            
	                                                                       
	animator:GetPropertyChangedSignal("PreferLodEnabled"):Connect(function()
		if animator.Parent == humanoid and animator.PreferLodEnabled then
			animator.PreferLodEnabled = false
		end
	end)
end

local function bindReference(reference, humanoid)
	if not reference or not reference:IsA("ObjectValue") then
		return
	end
	if boundReferences[reference] == humanoid then
		bindAnimator(reference.Value, humanoid)
		return
	end
	boundReferences[reference] = humanoid

	local function bindReferencedAnimator()
		bindAnimator(reference.Value, humanoid)
	end

	bindReferencedAnimator()
	reference:GetPropertyChangedSignal("Value"):Connect(bindReferencedAnimator)
end

local function bindCharacter(character)
	if boundCharacters[character] then
		return
	end
	boundCharacters[character] = true

	task.spawn(function()
		local humanoid = character:WaitForChild("Humanoid", 15)
		if not humanoid or not humanoid:IsA("Humanoid") or not character.Parent then
			return
		end

		                                                                  
		                                                               
		bindAnimator(humanoid:FindFirstChildOfClass("Animator"), humanoid)

		humanoid.ChildAdded:Connect(function(child)
			if child:IsA("Animator") then
				bindAnimator(child, humanoid)
			elseif child.Name == SERVER_REFERENCE_NAME and child:IsA("ObjectValue") then
				bindReference(child, humanoid)
			end
		end)

		local reference = humanoid:FindFirstChild(SERVER_REFERENCE_NAME)
			or humanoid:WaitForChild(SERVER_REFERENCE_NAME, 15)
		if reference and reference:IsA("ObjectValue") then
			bindReference(reference, humanoid)

			                                                                     
			                                                           
			local deadline = os.clock() + 15
			while character.Parent and not reference.Value and os.clock() < deadline do
				task.wait()
			end
			bindAnimator(reference.Value, humanoid)
		end
	end)
end

local function bindPlayer(player)
	if boundPlayers[player] then
		return
	end
	boundPlayers[player] = true
	if player.Character then
		bindCharacter(player.Character)
	end
	player.CharacterAdded:Connect(bindCharacter)
end

for _, player in ipairs(Players:GetPlayers()) do
	bindPlayer(player)
end
Players.PlayerAdded:Connect(bindPlayer)

print("[RemoteAnimatorFidelity] V306GZ loaded. Workspace client animation throttling is disabled; every current/replaced server Animator is locked to full fidelity with event-driven guards only.")
