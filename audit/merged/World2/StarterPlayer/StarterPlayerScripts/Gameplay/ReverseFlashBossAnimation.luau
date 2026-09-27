                                                                       
  
                                                                             
                                                                              
                                                                           
                                             

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
if Config.IsNewWorld1Map ~= true then
	return
end
local mapRoot = Workspace:FindFirstChild(tostring(Config.NewWorld1MapMarkerName or "neworld1"))
	or Workspace:WaitForChild(tostring(Config.NewWorld1MapMarkerName or "neworld1"), 25)
if not mapRoot then
	warn("[ReverseFlashBossAnimation] new World 1 map root is missing")
	return
end

local BOSS_NAME = "ReverseFlashBoss"
local BOSS_AREA_NAME = "BossArea"
local RENDER_BIND_NAME = "ReverseFlashBossProceduralWalkV231"
local BLEND_RESPONSE = 14
local ARM_SWING_DEGREES = 42
local LEG_SWING_DEGREES = 34
local BODY_LEAN_DEGREES = 5

local function normalizeName(value)
	return tostring(value or ""):lower():gsub("[^%w]", "")
end

local cachedBossArea = nil
local function findBossArea()
	if cachedBossArea and cachedBossArea.Parent then
		return cachedBossArea
	end
	local target = normalizeName(BOSS_AREA_NAME)
	for _, object in ipairs(mapRoot:GetDescendants()) do
		if normalizeName(object.Name) == target
			and (object:IsA("BasePart") or object:IsA("Model"))
		then
			cachedBossArea = object
			return object
		end
	end
	return nil
end

local function getAreaBounds(area)
	if area:IsA("BasePart") then
		return area.CFrame, area.Size
	end
	local ok, cframe, size = pcall(area.GetBoundingBox, area)
	if ok then
		return cframe, size
	end
	return nil, nil
end

local function rootIsInsideArea(root, area)
	local cframe, size = getAreaBounds(area)
	if not cframe or not size then
		return false
	end
	local point = cframe:PointToObjectSpace(root.Position)
	local half = size * 0.5
	return math.abs(point.X) <= half.X
		and math.abs(point.Z) <= half.Z
		and point.Y >= -half.Y - 3
		and point.Y <= half.Y + 12
end

                                                                             
                                                                              
                                                                                
                                         
local normalizedBossName = normalizeName(BOSS_NAME)
local bossCandidates = {}
local bossCandidateSet = setmetatable({}, { __mode = "k" })

local function addBossCandidate(object)
	if object:IsA("Model")
		and normalizeName(object.Name) == normalizedBossName
		and not bossCandidateSet[object]
	then
		bossCandidateSet[object] = true
		table.insert(bossCandidates, object)
	end
end

for _, object in ipairs(Workspace:GetDescendants()) do
	addBossCandidate(object)
end
Workspace.DescendantAdded:Connect(addBossCandidate)

local function candidateRoot(model)
	local root = model and model:FindFirstChild("HumanoidRootPart", true)
	return root and root:IsA("BasePart") and root or nil
end

local function findBoss()
	local bossArea = findBossArea()
	if not bossArea then
		return nil, "missing-area"
	end
	local live = {}
	local inside = {}
	for _, object in ipairs(bossCandidates) do
		if object.Parent then
			table.insert(live, object)
			local root = candidateRoot(object)
			if root and rootIsInsideArea(root, bossArea) then
				table.insert(inside, object)
			end
		end
	end
	table.sort(live, function(left, right)
		return left:GetFullName() < right:GetFullName()
	end)
	table.sort(inside, function(left, right)
		return left:GetFullName() < right:GetFullName()
	end)
	if #inside == 1 then
		return inside[1], "inside-neworld1-BossArea"
	end
	if #inside == 0 and #live == 1 then
		return live[1], "unique-workspace-exact-name"
	end
	return nil, #live == 0 and "missing" or "ambiguous"
end

local function waitForBoss()
	while mapRoot.Parent do
		local boss, source = findBoss()
		if boss then
			print("[ReverseFlashBossAnimation] V306KBN bound " .. boss:GetFullName() .. " | source=" .. tostring(source))
			return boss
		end
		task.wait(0.10)
	end
	return nil
end

local function findMotor(model, acceptedNames)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("Motor6D") and acceptedNames[normalizeName(descendant.Name)] then
			return descendant
		end
	end

	return nil
end

local function findR6Motors(boss)
	local deadline = os.clock() + 10

	repeat
		local rightShoulder = findMotor(boss, {
			rightshoulder = true,
			rightarmjoint = true,
		})
		local leftShoulder = findMotor(boss, {
			leftshoulder = true,
			leftarmjoint = true,
		})
		local rightHip = findMotor(boss, {
			righthip = true,
			rightlegjoint = true,
		})
		local leftHip = findMotor(boss, {
			lefthip = true,
			leftlegjoint = true,
		})

		if rightShoulder and leftShoulder and rightHip and leftHip then
			return rightShoulder, leftShoulder, rightHip, leftHip
		end

		task.wait(0.1)
	until not boss.Parent or os.clock() >= deadline

	return nil, nil, nil, nil
end

local function resetMotor(motor)
	if motor and motor.Parent then
		motor.Transform = CFrame.identity
	end
end

local function renderBossWalk(boss)
	local humanoid = boss:FindFirstChildWhichIsA("Humanoid", true)
	local root = boss:FindFirstChild("HumanoidRootPart", true)
	local deadline = os.clock() + 10
	while boss.Parent and (not humanoid or not root) and os.clock() < deadline do
		task.wait(0.10)
		humanoid = humanoid or boss:FindFirstChildWhichIsA("Humanoid", true)
		root = root or boss:FindFirstChild("HumanoidRootPart", true)
	end

	if not humanoid or not humanoid:IsA("Humanoid")
		or not root or not root:IsA("BasePart")
	then
		return
	end

	local rightShoulder, leftShoulder, rightHip, leftHip = findR6Motors(boss)
	if not rightShoulder or not leftShoulder or not rightHip or not leftHip then
		warn("[ReverseFlashBossAnimation] R6 shoulder/hip Motor6Ds were not found")
		while boss.Parent do
			task.wait(0.5)
		end
		return
	end

	local rootJoint = findMotor(boss, {
		rootjoint = true,
		root = true,
	})
	local phase = 0
	local blend = 0

	RunService:UnbindFromRenderStep(RENDER_BIND_NAME)
	RunService:BindToRenderStep(
		RENDER_BIND_NAME,
		Enum.RenderPriority.Character.Value + 20,
		function(deltaTime)
			if not boss.Parent or not humanoid.Parent or not root.Parent then
				return
			end

			local active = (boss:GetAttribute("TrackingActive") == true
				or boss:GetAttribute("ReturningHome") == true)
				and humanoid.Health > 0
			local targetBlend = active and 1 or 0
			local blendAlpha = 1 - math.exp(-BLEND_RESPONSE * math.min(deltaTime, 0.1))
			blend += (targetBlend - blend) * blendAlpha

			local velocity = root.AssemblyLinearVelocity
			local horizontalSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
			if active then
				local cadence = math.clamp(9 + horizontalSpeed * 0.16, 9, 17)
				phase += deltaTime * cadence
			end

			local wave = math.sin(phase)
			local armSwing = math.rad(ARM_SWING_DEGREES) * wave * blend
			local legSwing = math.rad(LEG_SWING_DEGREES) * wave * blend
			local armOut = math.rad(4) * blend

			                                                          
			rightShoulder.Transform = CFrame.Angles(armSwing, 0, armOut)
			leftShoulder.Transform = CFrame.Angles(-armSwing, 0, -armOut)
			rightHip.Transform = CFrame.Angles(-legSwing, 0, 0)
			leftHip.Transform = CFrame.Angles(legSwing, 0, 0)

			if rootJoint and rootJoint.Parent then
				local bob = math.abs(math.sin(phase * 2)) * 0.055 * blend
				rootJoint.Transform = CFrame.new(0, bob, 0)
					* CFrame.Angles(math.rad(-BODY_LEAN_DEGREES) * blend, 0, 0)
			end
		end
	)

	while boss.Parent and humanoid.Parent and root.Parent and humanoid.Health > 0 do
		task.wait(0.25)
	end

	RunService:UnbindFromRenderStep(RENDER_BIND_NAME)
	resetMotor(rightShoulder)
	resetMotor(leftShoulder)
	resetMotor(rightHip)
	resetMotor(leftHip)
	resetMotor(rootJoint)
end

while mapRoot.Parent do
	local boss = waitForBoss()
	if not boss then
		break
	end
	renderBossWalk(boss)
	task.wait(0.25)
end
