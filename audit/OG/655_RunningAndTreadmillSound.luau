local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

-- EXACT running + treadmill sound ID the user gave:
local RUN_SOUND_ID = "rbxassetid://96591611478915"

local currentSound = nil

local function getRoot(character)
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function makeSound(root)
	if currentSound and currentSound.Parent == root then
		return currentSound
	end

	if currentSound then
		currentSound:Destroy()
	end

	local sound = Instance.new("Sound")
	sound.Name = "SpeedsterRunTreadmillSound_EXACT_96591611478915"
	sound.SoundId = RUN_SOUND_ID
	sound.Looped = true
	sound.Volume = 0.6
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMaxDistance = 70
	sound.Parent = root

	currentSound = sound
	return sound
end

local function replaceDefaultRunningSound(root)
	-- Roblox often creates a default "Running" sound under HumanoidRootPart.
	-- This forces that sound to use the same new ID too.
	for _, obj in ipairs(root:GetChildren()) do
		if obj:IsA("Sound") and (obj.Name == "Running" or obj.Name:lower():find("run")) then
			obj.SoundId = RUN_SOUND_ID
			obj.Volume = 0.6
		end
	end
end

local function isOnTreadmill(character)
	local root = getRoot(character)
	if not root then
		return false
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }

	local result = workspace:Raycast(root.Position, Vector3.new(0, -7, 0), params)
	if not result or not result.Instance then
		return false
	end

	local hit = result.Instance
	local model = hit:FindFirstAncestorOfClass("Model")
	local name = (model and model.Name or hit.Name):lower()

	return name:find("treadmill") ~= nil
end

local function shouldPlay(character, humanoid)
	if not character or not humanoid or humanoid.Health <= 0 then
		return false
	end

	if humanoid.MoveDirection.Magnitude > 0.05 then
		return true
	end

	if isOnTreadmill(character) then
		return true
	end

	return false
end

local function update()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = getRoot(character)

	if not character or not humanoid or not root then
		return
	end

	replaceDefaultRunningSound(root)

	local sound = makeSound(root)

	if shouldPlay(character, humanoid) then
		local speed = tonumber(humanoid.WalkSpeed) or 16
		sound.PlaybackSpeed = math.clamp(0.9 + (speed / 120), 0.9, 1.7)

		if not sound.IsPlaying then
			sound:Play()
		end
	else
		if sound.IsPlaying then
			sound:Stop()
		end
	end
end

local function setup(character)
	currentSound = nil
	task.wait(0.3)

	local root = getRoot(character)
	if root then
		replaceDefaultRunningSound(root)
		makeSound(root)
	end

	print("[RunningAndTreadmillSound] V93 exact sound loaded: " .. RUN_SOUND_ID)
end

if player.Character then
	task.spawn(setup, player.Character)
end

player.CharacterAdded:Connect(setup)
RunService.Heartbeat:Connect(update)
