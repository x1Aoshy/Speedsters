                                                                        
                                                                             
                                                

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
if Config.IsWorld2Place ~= true then
	return
end
local BossContact = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BossContact"))

local player = Players.LocalPlayer
local BOSS_NAME = "Sonic.EXE"
local AREA_NAME = "SixSevenArea"
local CONTACT_REMOTE_NAME = "World2SonicEXEContact"
local RENDER_BIND_NAME = "World2SonicEXEZoomProceduralRunV306IF"

                                        
local BLEND_RESPONSE = 14
local ARM_SWING_DEGREES = 42
local LEG_SWING_DEGREES = 34
local BODY_LEAN_DEGREES = 5
local CONTACT_FIRE_COOLDOWN = 0.25
-- Exact boxes on the runner's own screen (2026-09-21): no padding, no shrink. The old
-- bounding-box query grew every body part by 0.4 studs.
local CONTACT_SHRINK = 0
local AREA_BELOW_PADDING = 10
local AREA_HEIGHT_ABOVE = 180

local R15_DAMAGE_PART_NAMES = {
	head = true,
	uppertorso = true,
	lowertorso = true,
	leftupperarm = true,
	leftlowerarm = true,
	lefthand = true,
	rightupperarm = true,
	rightlowerarm = true,
	righthand = true,
	leftupperleg = true,
	leftlowerleg = true,
	leftfoot = true,
	rightupperleg = true,
	rightlowerleg = true,
	rightfoot = true,
}

local function normalizeName(value)
	return tostring(value or ""):lower():gsub("[^%w]", "")
end

local function findBoss()
	local target = normalizeName(BOSS_NAME)
	for _, object in ipairs(Workspace:GetDescendants()) do
		if object:IsA("Model") and normalizeName(object.Name) == target then
			return object
		end
	end
	return nil
end

local function waitForBoss()
	local boss = findBoss()
	if boss then
		return boss
	end
	local target = normalizeName(BOSS_NAME)
	while true do
		local object = Workspace.DescendantAdded:Wait()
		if object:IsA("Model") and normalizeName(object.Name) == target then
			return object
		end
	end
end

local function getWorldAABBForParts(parts)
	local minPoint = Vector3.new(math.huge, math.huge, math.huge)
	local maxPoint = Vector3.new(-math.huge, -math.huge, -math.huge)
	local found = false
	for _, part in ipairs(parts) do
		if part and part.Parent and part:IsA("BasePart") then
			local half = part.Size * 0.5
			local cframe = part.CFrame
			local extent = Vector3.new(
				math.abs(cframe.RightVector.X) * half.X + math.abs(cframe.UpVector.X) * half.Y + math.abs(cframe.LookVector.X) * half.Z,
				math.abs(cframe.RightVector.Y) * half.X + math.abs(cframe.UpVector.Y) * half.Y + math.abs(cframe.LookVector.Y) * half.Z,
				math.abs(cframe.RightVector.Z) * half.X + math.abs(cframe.UpVector.Z) * half.Y + math.abs(cframe.LookVector.Z) * half.Z
			)
			local low = part.Position - extent
			local high = part.Position + extent
			minPoint = Vector3.new(math.min(minPoint.X, low.X), math.min(minPoint.Y, low.Y), math.min(minPoint.Z, low.Z))
			maxPoint = Vector3.new(math.max(maxPoint.X, high.X), math.max(maxPoint.Y, high.Y), math.max(maxPoint.Z, high.Z))
			found = true
		end
	end
	if not found then return nil, nil end
	local center = (minPoint + maxPoint) * 0.5
	return CFrame.new(center), maxPoint - minPoint
end

local function collectAreaBounds()
	local target = normalizeName(AREA_NAME)
	local bounds = {}
	for _, object in ipairs(Workspace:GetDescendants()) do
		if normalizeName(object.Name) == target then
			if object:IsA("BasePart") then
				table.insert(bounds, { CFrame = object.CFrame, Size = object.Size })
			elseif object:IsA("Model") then
				local ok, cframe, size = pcall(function() return object:GetBoundingBox() end)
				if ok and cframe and size then
					table.insert(bounds, { CFrame = cframe, Size = size })
				end
			elseif object:IsA("Folder") or object:IsA("Configuration") then
				local parts = {}
				for _, descendant in ipairs(object:GetDescendants()) do
					if descendant:IsA("BasePart") then table.insert(parts, descendant) end
				end
				local cframe, size = getWorldAABBForParts(parts)
				if cframe and size then table.insert(bounds, { CFrame = cframe, Size = size }) end
			end
		end
	end
	return bounds
end

local areaBounds = collectAreaBounds()
if #areaBounds == 0 then
	local deadline = os.clock() + 25
	repeat
		task.wait(0.25)
		areaBounds = collectAreaBounds()
	until #areaBounds > 0 or os.clock() >= deadline
end

local function pointInsideArea(point)
	for _, bound in ipairs(areaBounds) do
		local localPoint = bound.CFrame:PointToObjectSpace(point)
		local half = bound.Size * 0.5
		if math.abs(localPoint.X) <= half.X
			and math.abs(localPoint.Z) <= half.Z
			and localPoint.Y >= -half.Y - AREA_BELOW_PADDING
			and localPoint.Y <= half.Y + AREA_HEIGHT_ABOVE
		then
			return true
		end
	end
	return false
end

local function findMotorByJointOrPart1(model, acceptedJointNames, acceptedPart1Names)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("Motor6D") then
			local jointName = normalizeName(descendant.Name)
			local part1Name = descendant.Part1 and normalizeName(descendant.Part1.Name) or ""
			if acceptedJointNames[jointName] or acceptedPart1Names[part1Name] then
				return descendant
			end
		end
	end
	return nil
end

local function findRunMotors(boss)
	local deadline = os.clock() + 10
	repeat
		local rightShoulder = findMotorByJointOrPart1(
			boss,
			{ rightshoulder = true, rightarmjoint = true },
			{ rightupperarm = true }
		)
		local leftShoulder = findMotorByJointOrPart1(
			boss,
			{ leftshoulder = true, leftarmjoint = true },
			{ leftupperarm = true }
		)
		local rightHip = findMotorByJointOrPart1(
			boss,
			{ righthip = true, rightlegjoint = true },
			{ rightupperleg = true }
		)
		local leftHip = findMotorByJointOrPart1(
			boss,
			{ lefthip = true, leftlegjoint = true },
			{ leftupperleg = true }
		)
		if rightShoulder and leftShoulder and rightHip and leftHip then
			return rightShoulder, leftShoulder, rightHip, leftHip
		end
		task.wait(0.1)
	until not boss.Parent or os.clock() >= deadline
	return nil, nil, nil, nil
end

local function findRootJoint(boss)
	return findMotorByJointOrPart1(
		boss,
		{ rootjoint = true, root = true },
		{ lowertorso = true, torso = true }
	)
end

local function resetMotor(motor)
	if motor and motor.Parent then
		motor.Transform = CFrame.identity
	end
end

local contactRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild(CONTACT_REMOTE_NAME, 30)
if not contactRemote or not contactRemote:IsA("RemoteEvent") then
	warn("[World2SonicEXEBoss] Missing contact RemoteEvent: " .. CONTACT_REMOTE_NAME)
	return
end
local lastContactFireAt = -math.huge

local function isInsideAccessory(part, boss)
	local current = part.Parent
	while current and current ~= boss do
		if current:IsA("Accessory") then
			return true
		end
		current = current.Parent
	end
	return false
end

local damageBoss = nil
local damageRoot = nil
local damageParts = {}
local damagePartSet = setmetatable({}, { __mode = "k" })
local damageSizes = setmetatable({}, { __mode = "k" })
local character = nil
local localHumanoid = nil
local localRoot = nil
local characterParts = {}
local locallyKilledCharacter = nil

-- Only the runner's body counts (2026-09-21): hats, wings, tools and effect parts parented to
-- the character used to make the runner's own hitbox bigger.
local function isDirectCharacterBodyPart(part, model)
	if not part:IsA("BasePart") or part.Parent ~= model then
		return false
	end
	return BossContact.IsBodyPartName(part.Name)
end

local function rebuildCharacterParts()
	characterParts = {}
	if not character then return end
	for _, descendant in ipairs(character:GetDescendants()) do
		if isDirectCharacterBodyPart(descendant, character) then
			table.insert(characterParts, descendant)
		end
	end
end

local function refreshCharacter(newCharacter)
	character = newCharacter
	localHumanoid = character and character:FindFirstChildOfClass("Humanoid")
	localRoot = character and character:FindFirstChild("HumanoidRootPart")
	locallyKilledCharacter = nil
	rebuildCharacterParts()
	if character then
		character.DescendantAdded:Connect(function(descendant)
			if descendant:IsA("Humanoid") then
				localHumanoid = descendant
			elseif descendant:IsA("BasePart") and descendant.Name == "HumanoidRootPart" then
				localRoot = descendant
			elseif isDirectCharacterBodyPart(descendant, character) then
				table.insert(characterParts, descendant)
			end
		end)
		character.DescendantRemoving:Connect(function(descendant)
			if descendant == localRoot then localRoot = nil end
			if descendant == localHumanoid then localHumanoid = nil end
			if descendant:IsA("BasePart") then
				for index = #characterParts, 1, -1 do
					if characterParts[index] == descendant then
						table.remove(characterParts, index)
						break
					end
				end
			end
		end)
	end
end

player.CharacterAdded:Connect(refreshCharacter)
refreshCharacter(player.Character)

local function rebuildDamageParts()
	damageParts = {}
	damagePartSet = setmetatable({}, { __mode = "k" })
	damageSizes = setmetatable({}, { __mode = "k" })
	if not damageBoss or not damageBoss.Parent then return end

	local standardParts = {}
	local directVisibleParts = {}
	for _, descendant in ipairs(damageBoss:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant ~= damageRoot and not isInsideAccessory(descendant, damageBoss) then
			local normalized = normalizeName(descendant.Name)
			if R15_DAMAGE_PART_NAMES[normalized] then
				table.insert(standardParts, descendant)
			elseif descendant.Parent == damageBoss and descendant.Transparency < 0.95 then
				table.insert(directVisibleParts, descendant)
			end
		end
	end

	                                                                              
	                                                                             
	                                                                              
	local chosen = #standardParts > 0 and standardParts or directVisibleParts
	for _, part in ipairs(chosen) do
		if part.Parent then
			damagePartSet[part] = true
			-- The box Sonic draws, never bigger than the part (5.08 leg cubes draw 1.5-wide legs).
			damageSizes[part] = BossContact.VisibleSize(part)
			table.insert(damageParts, part)
		end
	end
end

local function setDamageBoss(boss, root)
	if damageBoss == boss and damageRoot == root then return end
	damageBoss = boss
	damageRoot = root
	rebuildDamageParts()
	boss.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("BasePart") then task.defer(rebuildDamageParts) end
	end)
	boss.DescendantRemoving:Connect(function(descendant)
		if damagePartSet[descendant] then task.defer(rebuildDamageParts) end
	end)
end

local function isLocallySafe()
	if not character then
		return false
	end
	-- StageTeleportArrivalGraceUntil is the SERVER's os.clock(), which has nothing to do with
	-- ours (2026-09-21): after one Speed Force use a long-running server made this client
	-- "safe" for hours. The ServerTime copy is on the clock both sides share; absent = no grace.
	local graceUntil = tonumber(player:GetAttribute("StageTeleportArrivalGraceUntilServerTime"))
	return player:GetAttribute("StageTeleportInvulnerable") == true
		or (graceUntil ~= nil and Workspace:GetServerTimeNow() < graceUntil)
		or player:GetAttribute("VortexSafeZone") == true
		or character:GetAttribute("VortexSafeZone") == true
		or character:FindFirstChild("VortexSafeZoneForceField") ~= nil
end

local function localKillFromSonic()
	if not character or not localHumanoid or localHumanoid.Health <= 0 or locallyKilledCharacter == character then
		return
	end
	if isLocallySafe() then
		return
	end
	locallyKilledCharacter = character

	                                                                       
	                                                                            
	character:SetAttribute("Dead", true)
	character:SetAttribute("Ragdolled", true)
	localHumanoid.Health = 0
	pcall(function()
		localHumanoid:ChangeState(Enum.HumanoidStateType.Dead)
	end)

	local now = os.clock()
	if now - lastContactFireAt >= CONTACT_FIRE_COOLDOWN then
		lastContactFireAt = now
		contactRemote:FireServer()
	end
end

local function detectSonicContact()
	if Workspace:GetAttribute("AdminWorldFrozen") == true then
		return -- frozen by the admin Snow event: a frozen boss catches nobody (2026-09-21)
	end
	if not damageBoss or not damageBoss.Parent or not damageRoot or not damageRoot.Parent then return end
	if not character or not localHumanoid or localHumanoid.Health <= 0 or not localRoot or not localRoot.Parent then return end
	if isLocallySafe() then return end
	if not pointInsideArea(localRoot.Position) then return end
	if (localRoot.Position - damageRoot.Position).Magnitude > 25 then return end

	local dist = Vector3.new(localRoot.Position.X - damageRoot.Position.X, 0, localRoot.Position.Z - damageRoot.Position.Z).Magnitude
	local deltaY = math.abs(localRoot.Position.Y - damageRoot.Position.Y)
	if dist <= 3.2 and deltaY <= 5.5 then
		localKillFromSonic()
		return
	end

	-- Exact boxes (2026-09-21): each drawn Sonic part (its VisibleSize, never bigger than the
	-- part) against each body part of the runner. GetPartBoundsInBox tested whole part bounds,
	-- 5.08-stud cubes around 1.5-stud-wide legs, and killed 1.5-3.5 studs from what is drawn.
	local validDamageParts = {}
	for _, part in ipairs(damageParts) do
		if part and part.Parent and part.CanQuery then
			table.insert(validDamageParts, part)
		end
	end
	if #validDamageParts == 0 then return end
	if BossContact.CharacterTouches(validDamageParts, characterParts, CONTACT_SHRINK, nil, nil, damageSizes) then
		localKillFromSonic()
	end
end

RunService.RenderStepped:Connect(detectSonicContact)

contactRemote.OnClientEvent:Connect(function(msg)
	if msg == "Kill" then
		localKillFromSonic()
	end
end)

local function renderBoss(boss)
	local humanoid = boss:FindFirstChildOfClass("Humanoid") or boss:WaitForChild("Humanoid", 10)
	local root = boss:FindFirstChild("HumanoidRootPart") or boss:WaitForChild("HumanoidRootPart", 10)
	if not humanoid or not humanoid:IsA("Humanoid") or not root or not root:IsA("BasePart") then
		return
	end

	                                                                            
	                                                                            
	setDamageBoss(boss, root)

	local rightShoulder, leftShoulder, rightHip, leftHip = findRunMotors(boss)
	if not rightShoulder or not leftShoulder or not rightHip or not leftHip then
		warn("[World2SonicEXEBoss] Could not resolve Sonic.EXE R15 shoulder/hip Motor6Ds by joint OR connected body-part names")
		while boss.Parent do task.wait(0.5) end
		return
	end
	local rootJoint = findRootJoint(boss)

	local phase = 0
	local blend = 0

	RunService:UnbindFromRenderStep(RENDER_BIND_NAME)
	RunService:BindToRenderStep(
		RENDER_BIND_NAME,
		Enum.RenderPriority.Character.Value + 20,
		function(deltaTime)
			if not boss.Parent or not humanoid.Parent or not root.Parent then return end

			local velocity = root.AssemblyLinearVelocity
			local horizontalSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
			local active = (boss:GetAttribute("TrackingActive") == true or horizontalSpeed > 0.75)
				and humanoid.Health > 0
			local targetBlend = active and 1 or 0
			local blendAlpha = 1 - math.exp(-BLEND_RESPONSE * math.min(deltaTime, 0.1))
			blend += (targetBlend - blend) * blendAlpha
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

print("[World2SonicEXEBoss] V306IF client ready | independent RenderStepped local contact kill | Zoom-style procedural R15 run")

while true do
	renderBoss(waitForBoss())
	task.wait(0.25)
end
