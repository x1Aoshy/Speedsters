local ContentProvider = game:GetService("ContentProvider")
local RunService = game:GetService("RunService")

local character = script.Parent
local humanoid = character:WaitForChild("Humanoid", 10)
local root = character:WaitForChild("HumanoidRootPart", 10)

                                      
local RUN_SOUND_ID = "rbxassetid://96591611478915"

if not humanoid or not root then
	warn("[ExactRunTreadmillAudio] Missing Humanoid or HumanoidRootPart.")
	return
end

local sound = Instance.new("Sound")
sound.Name = "SpeedsterRunTreadmillSound_EXACT_96591611478915"
sound.SoundId = RUN_SOUND_ID
sound.Looped = true
sound.Volume = 0.75
sound.RollOffMode = Enum.RollOffMode.InverseTapered
sound.RollOffMaxDistance = 85
sound.Parent = root

local currentRunningSpeed = 0
local wasPlaying = false
local lastPatch = 0

local function patchDefaultRunningSounds()
	                                                               
	                                                               
	                                                                        
	                                                                       
	for _, obj in ipairs(root:GetChildren()) do
		if obj:IsA("Sound") and obj.Name == "Running" then
			obj.Volume = 0
		end
	end
end

root.ChildAdded:Connect(function(child)
	if child:IsA("Sound") and child.Name == "Running" then
		task.defer(function()
			if child.Parent == root then
				child.Volume = 0
			end
		end)
	end
end)

local function nameLooksLikeTreadmill(instance)
	local current = instance
	while current do
		local name = current.Name:lower()
		if name:find("treadmill")
			or name:find("tredmill")
			or name:find("conveyor")
			or name:find("training") then
			return true
		end
		current = current.Parent
	end
	return false
end

local function isOnTreadmill()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }

	                                                                                               
	local offsets = {
		Vector3.new(0, 0, 0),
		Vector3.new(1.4, 0, 0),
		Vector3.new(-1.4, 0, 0),
		Vector3.new(0, 0, 1.4),
		Vector3.new(0, 0, -1.4),
	}

	for _, offset in ipairs(offsets) do
		local result = workspace:Raycast(root.Position + offset, Vector3.new(0, -10, 0), params)
		if result and result.Instance and nameLooksLikeTreadmill(result.Instance) then
			return true
		end
	end

	for _, part in ipairs(root:GetTouchingParts()) do
		if part and nameLooksLikeTreadmill(part) then
			return true
		end
	end

	return false
end

local function horizontalVelocity()
	local velocity = root.AssemblyLinearVelocity
	return Vector3.new(velocity.X, 0, velocity.Z).Magnitude
end

local function shouldPlay()
	if humanoid.Health <= 0 or humanoid.Sit then
		return false
	end

	local state = humanoid:GetState()
	if state == Enum.HumanoidStateType.Dead then
		return false
	end

	                            
	if currentRunningSpeed > 0.75 then
		return true
	end

	if humanoid.MoveDirection.Magnitude > 0.04 then
		return true
	end

	if horizontalVelocity() > 1.25 then
		return true
	end

	                       
	if isOnTreadmill() then
		return true
	end

	return false
end

local function updateSound()
	if os.clock() - lastPatch > 0.35 then
		lastPatch = os.clock()
		patchDefaultRunningSounds()
	end

	if sound.SoundId ~= RUN_SOUND_ID then
		sound.SoundId = RUN_SOUND_ID
	end
	if sound.Volume ~= 0.75 then
		sound.Volume = 0.75
	end

	local play = shouldPlay()

	if play then
		local speedForPitch = math.max(currentRunningSpeed, horizontalVelocity(), humanoid.WalkSpeed)
		sound.PlaybackSpeed = math.clamp(0.85 + (speedForPitch / 120), 0.85, 1.75)

		if not sound.IsPlaying then
			sound:Play()
		end

		wasPlaying = true
	else
		if sound.IsPlaying then
			sound:Stop()
		end

		wasPlaying = false
	end
end

humanoid.Running:Connect(function(speed)
	currentRunningSpeed = speed or 0
end)

humanoid.Died:Connect(function()
	if sound.IsPlaying then
		sound:Stop()
	end
end)

patchDefaultRunningSounds()

task.spawn(function()
	local ok, err = pcall(function()
		ContentProvider:PreloadAsync({ sound })
	end)

	if ok then
		print("[ExactRunTreadmillAudio] V95 sound preloaded: " .. RUN_SOUND_ID)
	else
		warn("[ExactRunTreadmillAudio] Sound preload failed. If you still hear no audio, the sound asset may not be approved/public or may not be a valid sound. ID: " .. RUN_SOUND_ID .. " Error: " .. tostring(err))
	end
end)

RunService.Heartbeat:Connect(updateSound)

print("[ExactRunTreadmillAudio] V306KV single exact run/treadmill sound active: " .. RUN_SOUND_ID)
