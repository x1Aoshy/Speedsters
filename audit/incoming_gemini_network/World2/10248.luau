local Part = script.Parent
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

-- remember what the part looked like before anyone touches it
local OriginalSize = Part.Size
local OriginalCFrame = Part.CFrame
local Pressed = false
local Touches = 0 -- how many humanoids are currently standing on it

local TiltAngle = 6
local LerpSpeed = 10 -- antes 5, muy lento; ahora responde más rápido

local TouchingCharacters = {} -- lista de characters actualmente parados en la Part
local UpdateConnection = nil

local PressSound = Instance.new("Sound")
PressSound.SoundId = "rbxassetid://116062165012558"
PressSound.Volume = 0.5
PressSound.Parent = Part

local ReleaseSound = Instance.new("Sound")
ReleaseSound.SoundId = "rbxassetid://133222321566847"
ReleaseSound.Volume = 0.5
ReleaseSound.Parent = Part

local BaseCFrame = OriginalCFrame * CFrame.new(0, -OriginalSize.Y * 0.2, 0)
local SmoothedDirection = Vector3.new(0, 0, 1) -- dirección suavizada, arranca con un valor default
local BasePosition = BaseCFrame.Position
local BaseRotation = OriginalCFrame - OriginalCFrame.Position -- solo la rotación, sin posición

local function GetTargetCFrame()
	local ClosestHRP = nil
	local ClosestDistance = math.huge

	for _, Character in ipairs(TouchingCharacters) do
		local HRP = Character:FindFirstChild("HumanoidRootPart")
		if HRP then
			local Distance = (HRP.Position - Part.Position).Magnitude
			if Distance < ClosestDistance then
				ClosestDistance = Distance
				ClosestHRP = HRP
			end
		end
	end

	if not ClosestHRP then
		return BaseCFrame
	end

	local RawDirection = ClosestHRP.Position - Part.Position
	RawDirection = Vector3.new(RawDirection.X, 0, RawDirection.Z)

	if RawDirection.Magnitude > 0.5 then
		SmoothedDirection = RawDirection.Unit -- sin doble lerp, el Heartbeat ya suaviza el movimiento
	end

	local Axis = Vector3.new(SmoothedDirection.Z, 0, -SmoothedDirection.X)
	local TiltCFrame = CFrame.fromAxisAngle(Axis, math.rad(TiltAngle))

	-- tilt en espacio mundial, rotación original de la Part se aplica después
	return CFrame.new(BasePosition) * TiltCFrame * BaseRotation
end

local function Press(Character)
	table.insert(TouchingCharacters, Character)

	if Pressed then return end
	Pressed = true

	ReleaseSound:Stop()
	PressSound:Stop()
	PressSound:Play()

	local InitialTarget = GetTargetCFrame()

	-- size y tilt inicial van juntos en el mismo tween
	local PressTween = TweenService:Create(Part, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		Size = Vector3.new(OriginalSize.X * 1.12, OriginalSize.Y * 0.25, OriginalSize.Z * 1.12),
		CFrame = InitialTarget
	})
	PressTween:Play()

	if UpdateConnection then
		UpdateConnection:Disconnect()
	end

	UpdateConnection = RunService.Heartbeat:Connect(function(dt)
		if PressTween.PlaybackState == Enum.PlaybackState.Playing then
			return
		end
		local Target = GetTargetCFrame()
		Part.CFrame = Part.CFrame:Lerp(Target, 1 - math.exp(-LerpSpeed * dt)) -- exponencial, independiente del framerate
	end)
end

local function Release(Character)
	for i, Char in ipairs(TouchingCharacters) do
		if Char == Character then
			table.remove(TouchingCharacters, i)
			break
		end
	end

	if #TouchingCharacters > 0 or not Pressed then return end
	Pressed = false

	PressSound:Stop()
	ReleaseSound:Stop()
	ReleaseSound:Play()

	if UpdateConnection then
		UpdateConnection:Disconnect()
		UpdateConnection = nil
	end

	TweenService:Create(Part, TweenInfo.new(2, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
		Size = OriginalSize,
		CFrame = OriginalCFrame
	}):Play()
end

Part.Touched:Connect(function(Hit)
	local Character = Hit.Parent
	if not Character then return end
	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid then return end

	Touches += 1
	Press(Character)
end)

Part.TouchEnded:Connect(function(Hit)
	local Character = Hit.Parent
	if not Character then return end
	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid then return end

	Touches -= 1
	if Touches < 0 then
		Touches = 0
	end
	Release(Character)
end)