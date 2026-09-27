local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

-- EXACT running + treadmill sound ID the user gave:
local RUN_SOUND_ID = "rbxassetid://96591611478915"

local currentSound = nil

-- 2026-09-22: this used to run every frame, allocate a RaycastParams per call and walk the
-- root's children every frame. One params object for the script (re-aimed when the
-- character changes), the default sound patched only when the root gets a child, and the
-- loop at 10 Hz: a start or stop up to 0.1 s late is not heard.
local UPDATE_INTERVAL = 0.1
local treadmillRayParams = RaycastParams.new()
treadmillRayParams.FilterType = Enum.RaycastFilterType.Exclude
local rayCharacter = nil
local hookedRoot = nil
local rootChildConnection = nil

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

-- The root this script patches: its current children now, and each child it gets later.
local function hookRoot(root)
	if hookedRoot == root then
		return
	end
	if rootChildConnection then
		rootChildConnection:Disconnect()
		rootChildConnection = nil
	end
	hookedRoot = root
	if not root then
		return
	end
	replaceDefaultRunningSound(root)
	rootChildConnection = root.ChildAdded:Connect(function(child)
		if child:IsA("Sound") then
			replaceDefaultRunningSound(root)
			-- The default sound script may set its properties just after parenting it.
			task.defer(replaceDefaultRunningSound, root)
		end
	end)
end

local function isOnTreadmill(character)
	if player:GetAttribute("IsOnTreadmill") == true then
		return true
	end

	local root = getRoot(character)
	if not root then
		return false
	end

	if rayCharacter ~= character then
		rayCharacter = character
		treadmillRayParams.FilterDescendantsInstances = { character }
	end

	local result = workspace:Raycast(root.Position, Vector3.new(0, -7, 0), treadmillRayParams)
	if not result or not result.Instance then
		return false
	end

	local hit = result.Instance
	if hit.Name == "SmoothDeck" or hit:GetAttribute("VortexTreadmillCollisionPart") == true then
		return true
	end
	local model = hit:FindFirstAncestorOfClass("Model")
	local name = (model and model.Name or hit.Name):lower()

	return name:find("treadmil") ~= nil
end

local function shouldPlay(character, humanoid)
	if not character or not humanoid or humanoid.Health <= 0 then
		return false
	end

	-- Locomotion audio is silenced during active flight
	if player:GetAttribute("FlightAbilityActive") == true
		or character:GetAttribute("FlightAbilityLocalActive") == true
		or player:GetAttribute("AdminFlying") == true
	then
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

	hookRoot(root)

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
	rayCharacter = character
	treadmillRayParams.FilterDescendantsInstances = { character }
	task.wait(0.3)

	local root = getRoot(character)
	if root then
		hookRoot(root)
		makeSound(root)
	end

	print("[RunningAndTreadmillSound] V93 exact sound loaded: " .. RUN_SOUND_ID)
end

if player.Character then
	task.spawn(setup, player.Character)
end

player.CharacterAdded:Connect(setup)
local updateElapsed = 0
RunService.Heartbeat:Connect(function(deltaTime)
	updateElapsed += deltaTime
	if updateElapsed < UPDATE_INTERVAL then
		return
	end
	updateElapsed = 0
	update()
end)
