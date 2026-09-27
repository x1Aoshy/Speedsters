local Part = script.Parent
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

-- remember what the part looked like before anyone touches it
local OriginalSize = Part.Size
local OriginalCFrame = Part.CFrame
local Pressed = false
local Touches = 0 -- how many humanoids are currently standing on it

local TiltAngle = 6
local LerpSpeed = 10 -- responsive tilt

local TouchingCharacters = {} -- lista de characters actualmente parados en la Part
local UpdateConnection = nil

local PressSound = Part:FindFirstChild("PressSound")
if not PressSound or not PressSound:IsA("Sound") then
	PressSound = Instance.new("Sound")
	PressSound.Name = "PressSound"
	PressSound.SoundId = "rbxassetid://116062165012558"
	PressSound.Volume = 0.5
	PressSound.Parent = Part
end

local ReleaseSound = Part:FindFirstChild("ReleaseSound")
if not ReleaseSound or not ReleaseSound:IsA("Sound") then
	ReleaseSound = Instance.new("Sound")
	ReleaseSound.Name = "ReleaseSound"
	ReleaseSound.SoundId = "rbxassetid://133222321566847"
	ReleaseSound.Volume = 0.5
	ReleaseSound.Parent = Part
end

local BaseCFrame = OriginalCFrame * CFrame.new(0, -OriginalSize.Y * 0.2, 0)
local SmoothedDirection = Vector3.new(0, 0, 1)
local BasePosition = BaseCFrame.Position
local BaseRotation = OriginalCFrame - OriginalCFrame.Position

local Release = nil -- forward declaration

local function GetTargetCFrame()
	local ClosestHRP = nil
	local ClosestDistance = math.huge

	for i = #TouchingCharacters, 1, -1 do
		local Character = TouchingCharacters[i]
		local HRP = Character and Character:FindFirstChild("HumanoidRootPart")
		local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
		if not Character or not Character.Parent or not HRP or not Humanoid or Humanoid.Health <= 0 then
			table.remove(TouchingCharacters, i)
		else
			local Distance = (HRP.Position - Part.Position).Magnitude
			if Distance > 10 then
				table.remove(TouchingCharacters, i)
			elseif Distance < ClosestDistance then
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
		SmoothedDirection = RawDirection.Unit
	end

	local Axis = Vector3.new(SmoothedDirection.Z, 0, -SmoothedDirection.X)
	local TiltCFrame = CFrame.fromAxisAngle(Axis, math.rad(TiltAngle))

	return CFrame.new(BasePosition) * TiltCFrame * BaseRotation
end

local function Press(Character)
	if not Character then return end
	if not table.find(TouchingCharacters, Character) then
		table.insert(TouchingCharacters, Character)
	end

	if Pressed then return end
	Pressed = true

	ReleaseSound:Stop()
	PressSound:Stop()
	PressSound:Play()

	local InitialTarget = GetTargetCFrame()

	local PressTween = TweenService:Create(Part, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		Size = Vector3.new(OriginalSize.X * 1.12, OriginalSize.Y * 0.25, OriginalSize.Z * 1.12),
		CFrame = InitialTarget
	})
	PressTween:Play()

	if UpdateConnection then
		UpdateConnection:Disconnect()
	end

	UpdateConnection = RunService.Heartbeat:Connect(function(dt)
		if #TouchingCharacters == 0 then
			if Release then Release() end
			return
		end
		if PressTween.PlaybackState == Enum.PlaybackState.Playing then
			return
		end
		local Target = GetTargetCFrame()
		Part.CFrame = Part.CFrame:Lerp(Target, 1 - math.exp(-LerpSpeed * dt))
	end)
end

Release = function(Character)
	if Character then
		local idx = table.find(TouchingCharacters, Character)
		if idx then
			table.remove(TouchingCharacters, idx)
		end
	end

	for i = #TouchingCharacters, 1, -1 do
		local c = TouchingCharacters[i]
		if not c or not c.Parent or not c:FindFirstChild("HumanoidRootPart") then
			table.remove(TouchingCharacters, i)
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

	TweenService:Create(Part, TweenInfo.new(1.2, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
		Size = OriginalSize,
		CFrame = OriginalCFrame
	}):Play()
end

Part.Touched:Connect(function(Hit)
	local Character = Hit and Hit.Parent
	if not Character then return end
	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid then
		Character = Character.Parent
		Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
	end
	if not Humanoid or Humanoid.Health <= 0 then return end

	Touches += 1
	Press(Character)
end)

Part.TouchEnded:Connect(function(Hit)
	local Character = Hit and Hit.Parent
	if not Character then return end
	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid then
		Character = Character.Parent
		Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
	end
	if not Humanoid then return end

	Touches -= 1
	if Touches < 0 then
		Touches = 0
	end
	Release(Character)
end)