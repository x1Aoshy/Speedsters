                                 
                                                                      
  
                              
                                                              
                                                                           
                                        
  
                     
                                                                                   
                                                                           
                                                                                 
                                 
                                                                                
                                                                          

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
if Config.IsWorld2Place ~= true then
	return
end

local BOSS_NAME = "Sonic.EXE"
local AREA_NAME = "SixSevenArea"
local FIND_TIMEOUT_SECONDS = 25
local SONIC_WALK_SPEED = 57.7
-- 2026-09-22: World 2 opens at 6 Rebirths + Level 50 and walks at x0.5, so a new entrant runs
-- about 22.6 studs/s (it was 32 at 7 + Level 100 and x1/3). Sonic keeps today's edge over the
-- runner he chases (57.7 against 32 is x1.8, a little above the x1.7 sprint) rather than a fixed
-- 57.7 nobody new could escape, and never goes above 57.7. RealWalkSpeedMax is the runner's full
-- speed, so a slow walk mode does not slow him down.
local SONIC_CHASE_EDGE = 1.8
local SONIC_MIN_CHASE_SPEED = 30
local RETURN_TO_SPAWN_ARRIVAL_DISTANCE = 0.45

                                                                            
local TARGET_REFRESH_INTERVAL = 0.06
local TARGET_LEAD_SECONDS = 0.04
local MAX_TARGET_LEAD_STUDS = 4
local STEERING_RESPONSE = 12
local ARRIVAL_DISTANCE = 1.0
local AREA_SIDE_PADDING = 15
local AREA_BELOW_PADDING = 10
local AREA_HEIGHT_ABOVE = 180
local CLIENT_CONTACT_REMOTE_NAME = "World2SonicEXEContact"

local function normalizeName(value)
	return tostring(value or ""):lower():gsub("[^%w]", "")
end

local function objectDepth(object)
	local depth = 0
	local current = object
	while current and current.Parent and current.Parent ~= Workspace do
		depth += 1
		current = current.Parent
	end
	return depth
end

                                                                                  
                                                                                   
local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end
local contactRemote = remotes:FindFirstChild(CLIENT_CONTACT_REMOTE_NAME)
if contactRemote and not contactRemote:IsA("RemoteEvent") then
	contactRemote:Destroy()
	contactRemote = nil
end
if not contactRemote then
	contactRemote = Instance.new("RemoteEvent")
	contactRemote.Name = CLIENT_CONTACT_REMOTE_NAME
	contactRemote.Parent = remotes
end

local function findNamedModel(name)
	local target = normalizeName(name)
	local matches = {}
	for _, object in ipairs(Workspace:GetDescendants()) do
		if object:IsA("Model") and normalizeName(object.Name) == target then
			table.insert(matches, object)
		end
	end
	table.sort(matches, function(left, right)
		local leftDepth = objectDepth(left)
		local rightDepth = objectDepth(right)
		if leftDepth == rightDepth then
			return left:GetFullName() < right:GetFullName()
		end
		return leftDepth < rightDepth
	end)
	return matches[1]
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
			minPoint = Vector3.new(
				math.min(minPoint.X, low.X),
				math.min(minPoint.Y, low.Y),
				math.min(minPoint.Z, low.Z)
			)
			maxPoint = Vector3.new(
				math.max(maxPoint.X, high.X),
				math.max(maxPoint.Y, high.Y),
				math.max(maxPoint.Z, high.Z)
			)
			found = true
		end
	end

	if not found then
		return nil, nil
	end
	local center = (minPoint + maxPoint) * 0.5
	return CFrame.new(center), maxPoint - minPoint
end

local function getNamedAreaBounds()
	local target = normalizeName(AREA_NAME)
	local bounds = {}

	for _, object in ipairs(Workspace:GetDescendants()) do
		if normalizeName(object.Name) == target then
			if object:IsA("BasePart") then
				table.insert(bounds, { CFrame = object.CFrame, Size = object.Size, Source = object })
			elseif object:IsA("Model") then
				local ok, cframe, size = pcall(function()
					return object:GetBoundingBox()
				end)
				if ok and cframe and size then
					table.insert(bounds, { CFrame = cframe, Size = size, Source = object })
				end
			elseif object:IsA("Folder") or object:IsA("Configuration") then
				local parts = {}
				for _, descendant in ipairs(object:GetDescendants()) do
					if descendant:IsA("BasePart") then
						table.insert(parts, descendant)
					end
				end
				local cframe, size = getWorldAABBForParts(parts)
				if cframe and size then
					table.insert(bounds, { CFrame = cframe, Size = size, Source = object })
				end
			end
		end
	end

	return bounds
end

local function waitForBossAndAreaBounds()
	local deadline = os.clock() + FIND_TIMEOUT_SECONDS
	local boss = nil
	local areaBounds = {}
	repeat
		boss = boss or findNamedModel(BOSS_NAME)
		if #areaBounds == 0 then
			areaBounds = getNamedAreaBounds()
		end
		if boss and #areaBounds > 0 then
			return boss, areaBounds
		end
		task.wait(0.25)
	until os.clock() >= deadline
	return boss, areaBounds
end

local function pointInsideBound(point, bound)
	local localPoint = bound.CFrame:PointToObjectSpace(point)
	local half = bound.Size * 0.5
	return math.abs(localPoint.X) <= half.X + AREA_SIDE_PADDING
		and math.abs(localPoint.Z) <= half.Z + AREA_SIDE_PADDING
		and localPoint.Y >= -half.Y - AREA_BELOW_PADDING
		and localPoint.Y <= half.Y + AREA_HEIGHT_ABOVE
end

local boss, areaBounds = waitForBossAndAreaBounds()
if not boss then
	warn("[World2SonicEXEBoss] Missing Workspace R15 model: " .. BOSS_NAME)
	return
end
if #areaBounds == 0 then
	warn("[World2SonicEXEBoss] No usable bounds found for Workspace object/container: " .. AREA_NAME)
	return
end

local humanoid = boss:FindFirstChildOfClass("Humanoid") or boss:WaitForChild("Humanoid", 10)
local root = boss:FindFirstChild("HumanoidRootPart") or boss:WaitForChild("HumanoidRootPart", 10)
if not humanoid or not humanoid:IsA("Humanoid") then
	warn("[World2SonicEXEBoss] Sonic.EXE needs a Humanoid")
	return
end
if not root or not root:IsA("BasePart") then
	warn("[World2SonicEXEBoss] Sonic.EXE needs a HumanoidRootPart")
	return
end
if humanoid.RigType ~= Enum.HumanoidRigType.R15 then
	warn("[World2SonicEXEBoss] Sonic.EXE is expected to be R15; detected " .. tostring(humanoid.RigType))
end

local function isInsideSixSevenArea(position)
	for _, bound in ipairs(areaBounds) do
		if pointInsideBound(position, bound) then
			return true
		end
	end
	return false
end

local function horizontal(vector)
	return Vector3.new(vector.X, 0, vector.Z)
end

local function horizontalUnit(vector)
	local flat = horizontal(vector)
	if flat.Magnitude < 0.001 then
		return nil
	end
	return flat.Unit
end

                                                                                       
root.Anchored = true
root.AssemblyLinearVelocity = Vector3.zero
root.AssemblyAngularVelocity = Vector3.zero

local configuredParts = setmetatable({}, { __mode = "k" })
local function isAccessoryPart(part)
	local current = part.Parent
	while current and current ~= boss do
		if current:IsA("Accessory") then
			return true
		end
		current = current.Parent
	end
	return false
end

local function configureBossPart(part)
	if configuredParts[part] or not part:IsA("BasePart") then
		return
	end
	configuredParts[part] = true

	if part ~= root then
		part.Anchored = false
	end
	part.CanTouch = false                                                                              
	part.CanQuery = true

	if isAccessoryPart(part) then
		part.CanCollide = false
		part.Massless = true
	else
		local normalized = normalizeName(part.Name)
		if normalized == "lowertorso" then
			part.CanCollide = true
			part.Massless = false
		else
			part.CanCollide = false
			if part ~= root then
				part.Massless = true
			end
		end
	end

	if not root.Anchored then
		pcall(function()
			part:SetNetworkOwner(nil)
		end)
	end
end

for _, descendant in ipairs(boss:GetDescendants()) do
	if descendant:IsA("BasePart") then
		configureBossPart(descendant)
	elseif (descendant:IsA("Script") or descendant:IsA("LocalScript"))
		and normalizeName(descendant.Name) == "animate"
	then
		descendant.Enabled = false
	end
end
boss.DescendantAdded:Connect(function(descendant)
	if descendant:IsA("BasePart") then
		configureBossPart(descendant)
	elseif (descendant:IsA("Script") or descendant:IsA("LocalScript"))
		and normalizeName(descendant.Name) == "animate"
	then
		descendant.Enabled = false
	end
end)

humanoid.AutoRotate = true
humanoid.PlatformStand = false
humanoid.Sit = false
humanoid.WalkSpeed = SONIC_WALK_SPEED

                                                                             
                                                                              
for _, descendant in ipairs(boss:GetDescendants()) do
	if descendant:IsA("Animator") then
		for _, track in ipairs(descendant:GetPlayingAnimationTracks()) do
			track:Stop(0.05)
		end
	end
end

local function worldVerticalExtent(part)
	local half = part.Size * 0.5
	local cframe = part.CFrame
	return math.abs(cframe.RightVector.Y) * half.X
		+ math.abs(cframe.UpVector.Y) * half.Y
		+ math.abs(cframe.LookVector.Y) * half.Z
end

local function partBottomY(part)
	return part.Position.Y - worldVerticalExtent(part)
end

local function getRigFootBottomY()
	local preferred = { leftfoot = true, rightfoot = true }
	local fallback = { leftlowerleg = true, rightlowerleg = true }
	local lowest = math.huge
	local foundPreferred = false

	for _, descendant in ipairs(boss:GetDescendants()) do
		if descendant:IsA("BasePart") and not isAccessoryPart(descendant) then
			local name = normalizeName(descendant.Name)
			if preferred[name] then
				lowest = math.min(lowest, partBottomY(descendant))
				foundPreferred = true
			end
		end
	end
	if foundPreferred then
		return lowest
	end

	lowest = math.huge
	local foundFallback = false
	for _, descendant in ipairs(boss:GetDescendants()) do
		if descendant:IsA("BasePart") and not isAccessoryPart(descendant) then
			local name = normalizeName(descendant.Name)
			if fallback[name] then
				lowest = math.min(lowest, partBottomY(descendant))
				foundFallback = true
			end
		end
	end
	if foundFallback then
		return lowest
	end

	local ok, boundsCFrame, boundsSize = pcall(function()
		return boss:GetBoundingBox()
	end)
	if ok and boundsCFrame and boundsSize then
		return boundsCFrame.Position.Y - boundsSize.Y * 0.5
	end
	return nil
end

                                                                            
                                                                               
local footBottomBefore = getRigFootBottomY()
if footBottomBefore then
	local rootToFeet = root.Position.Y - footBottomBefore
	local derivedHipHeight = math.max(0, rootToFeet - root.Size.Y * 0.5)
	if derivedHipHeight > 0 then
		humanoid.HipHeight = derivedHipHeight
	end
end

                                                                           
                                         
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.FilterDescendantsInstances = { boss }
pcall(function()
	rayParams.RespectCanCollide = true
end)
local rayOrigin = root.Position + Vector3.new(0, 30, 0)
local floorHit = Workspace:Raycast(rayOrigin, Vector3.new(0, -200, 0), rayParams)
local currentFootBottom = getRigFootBottomY()
if floorHit and currentFootBottom then
	local verticalCorrection = floorHit.Position.Y - currentFootBottom + 0.04
	if math.abs(verticalCorrection) <= 40 then
		boss:PivotTo(boss:GetPivot() + Vector3.new(0, verticalCorrection, 0))
	end
end

root.AssemblyLinearVelocity = Vector3.zero
root.AssemblyAngularVelocity = Vector3.zero

                                                                           
                                                                             
                                                                                
local spawnPivot = boss:GetPivot()
local spawnRootPosition = root.Position

boss:SetAttribute("WorldNumber", 2)
boss:SetAttribute("BossWalkSpeed", SONIC_WALK_SPEED)
boss:SetAttribute("ResolvedBossWalkSpeed", SONIC_WALK_SPEED)
boss:SetAttribute("TrackingArea", AREA_NAME)
boss:SetAttribute("TrackingAreaBoundCount", #areaBounds)
boss:SetAttribute("TrackingMode", "World2SixSevenZoomStyleSteeringV306IE")
boss:SetAttribute("ProceduralR15Run", true)
boss:SetAttribute("ZoomAnimationMatch", true)
boss:SetAttribute("ClientOnlyContactDetection", true)
boss:SetAttribute("ServerTouchedDamageDisabled", true)
boss:SetAttribute("GroundingFixedFromRigFeet", true)
boss:SetAttribute("IdleRootAnchored", true)
boss:SetAttribute("ReturnsToAuthoredSpawn", true)

                                                                                 
local function isProtected(player, character)
	local now = os.clock()
	return player:GetAttribute("StageTeleportInvulnerable") == true
		or now < (tonumber(player:GetAttribute("StageTeleportArrivalGraceUntil")) or 0)
		or player:GetAttribute("VortexSafeZone") == true
		or (character and character:GetAttribute("VortexSafeZone") == true)
		or (character and character:FindFirstChild("VortexSafeZoneForceField") ~= nil)
end

contactRemote.OnServerEvent:Connect(function(player)
	if Workspace:GetAttribute("AdminWorldFrozen") == true then
		return -- frozen by the admin Snow event: a frozen boss catches nobody (2026-09-21)
	end
	local character = player.Character
	local targetHumanoid = character and character:FindFirstChildOfClass("Humanoid")
	local targetRoot = character and character:FindFirstChild("HumanoidRootPart")
	if not targetHumanoid or targetHumanoid.Health <= 0
		or not targetRoot or not targetRoot:IsA("BasePart")
	then
		return
	end
	if isProtected(player, character) then
		return
	end
	local distanceToBoss = (targetRoot.Position - root.Position).Magnitude
	if distanceToBoss >= 25 and not isInsideSixSevenArea(targetRoot.Position) then
		return
	end
	                                                                            
	                                                              
	character:SetAttribute("Dead", true)
	character:SetAttribute("Ragdolled", true)
	targetHumanoid.Health = 0
	pcall(function()
		targetHumanoid:TakeDamage(targetHumanoid.MaxHealth + 1000)
	end)
end)

local function getEligibleTarget(player)
	local character = player.Character
	local targetHumanoid = character and character:FindFirstChildOfClass("Humanoid")
	local targetRoot = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not targetHumanoid or targetHumanoid.Health <= 0
		or not targetRoot or not targetRoot:IsA("BasePart")
	then
		return nil, nil
	end
	if isProtected(player, character) then
		return nil, nil
	end
	if not isInsideSixSevenArea(targetRoot.Position) then
		return nil, nil
	end
	return targetRoot, targetHumanoid
end

local function findClosestTarget()
	local closestPlayer = nil
	local closestRoot = nil
	local closestDistance = math.huge
	for _, player in ipairs(Players:GetPlayers()) do
		local targetRoot = getEligibleTarget(player)
		if targetRoot then
			local distance = horizontal(targetRoot.Position - root.Position).Magnitude
			if distance < closestDistance then
				closestDistance = distance
				closestPlayer = player
				closestRoot = targetRoot
			end
		end
	end
	return closestPlayer, closestRoot
end

local currentTargetPlayer = nil
local currentTargetRoot = nil
local nextTargetRefreshAt = 0
local smoothedDirection = Vector3.zero
local motionActive = false

local function setTrackingState(player)
	local active = player ~= nil
	if boss:GetAttribute("TrackingActive") ~= active then
		boss:SetAttribute("TrackingActive", active)
	end
	local userId = player and player.UserId or 0
	if boss:GetAttribute("CurrentTargetUserId") ~= userId then
		boss:SetAttribute("CurrentTargetUserId", userId)
	end
end

local function setMotionActive(active)
	if motionActive == active then
		return
	end
	motionActive = active

	if active then
		root.Anchored = false
		pcall(function()
			root:SetNetworkOwner(nil)
		end)
		for part in pairs(configuredParts) do
			if part.Parent and part ~= root then
				pcall(function()
					part:SetNetworkOwner(nil)
				end)
			end
		end
		pcall(function()
			humanoid:ChangeState(Enum.HumanoidStateType.Running)
		end)
	else
		humanoid:Move(Vector3.zero, false)
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		root.Anchored = true
	end
end

local function clearTargetState()
	currentTargetPlayer = nil
	currentTargetRoot = nil
	setTrackingState(nil)
end

-- How fast Sonic runs while he chases this player (SONIC_CHASE_EDGE above).
local function chaseSpeedFor(player)
	local runnerSpeed = tonumber(player and player:GetAttribute("RealWalkSpeedMax"))
	if not runnerSpeed or runnerSpeed ~= runnerSpeed or runnerSpeed <= 0 then
		return SONIC_WALK_SPEED
	end
	return math.clamp(runnerSpeed * SONIC_CHASE_EDGE, SONIC_MIN_CHASE_SPEED, SONIC_WALK_SPEED)
end

local function setSonicSpeed(speed)
	if math.abs(humanoid.WalkSpeed - speed) > 0.05 then
		humanoid.WalkSpeed = speed
		boss:SetAttribute("ResolvedBossWalkSpeed", speed)
	end
end

local function anchorExactlyAtSpawn()
	humanoid:Move(Vector3.zero, false)
	if root.Parent then
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end
	smoothedDirection = Vector3.zero
	clearTargetState()
	setMotionActive(false)
	if boss.Parent and root.Parent then
		boss:PivotTo(spawnPivot)
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end
	boss:SetAttribute("ReturningToSpawn", false)
end

local function returnToSpawn(deltaTime)
	clearTargetState()

	local displacement = horizontal(spawnRootPosition - root.Position)
	local distance = displacement.Magnitude
	if distance <= RETURN_TO_SPAWN_ARRIVAL_DISTANCE then
		-- Parked already: anchorExactlyAtSpawn() ran on arrival. Running it again on every
		-- Heartbeat re-pivoted the whole rig and flipped ReturningToSpawn true -> false 60 times
		-- a second while nobody was in the area (ZoomBoss parks the same way).
		if motionActive or boss:GetAttribute("ReturningToSpawn") == true then
			anchorExactlyAtSpawn()
		end
		return
	end

	boss:SetAttribute("ReturningToSpawn", true)
	setMotionActive(true)
	setSonicSpeed(SONIC_WALK_SPEED)
	local desiredDirection = horizontalUnit(displacement)
	if not desiredDirection then
		anchorExactlyAtSpawn()
		return
	end

	                                                                            
	                                                                           
	local responseAlpha = 1 - math.exp(-STEERING_RESPONSE * math.min(deltaTime, 0.1))
	if smoothedDirection.Magnitude < 0.001 then
		smoothedDirection = desiredDirection
	else
		local blended = smoothedDirection:Lerp(desiredDirection, responseAlpha)
		smoothedDirection = horizontalUnit(blended) or desiredDirection
	end
	humanoid:Move(smoothedDirection, false)
end

anchorExactlyAtSpawn()

local heartbeatConnection
heartbeatConnection = RunService.Heartbeat:Connect(function(deltaTime)
	if not boss.Parent or not humanoid.Parent or not root.Parent or humanoid.Health <= 0 then
		if heartbeatConnection then
			heartbeatConnection:Disconnect()
		end
		anchorExactlyAtSpawn()
		return
	end

	if Workspace:GetAttribute("AdminWorldFrozen") == true then
		-- Frozen by the admin Snow event.
		humanoid:Move(Vector3.zero, false)
		root.AssemblyLinearVelocity = Vector3.zero
		return
	end

	local now = os.clock()
	local eligibleCurrentRoot = currentTargetPlayer and select(1, getEligibleTarget(currentTargetPlayer))

	if eligibleCurrentRoot then
		local dist = horizontal(eligibleCurrentRoot.Position - root.Position).Magnitude
		local deltaY = math.abs(eligibleCurrentRoot.Position.Y - root.Position.Y)
		if dist <= 3.2 and deltaY <= 5.5 then
			contactRemote:FireClient(currentTargetPlayer, "Kill")
			local character = currentTargetPlayer.Character
			if character then
				local targetHumanoid = character:FindFirstChildOfClass("Humanoid")
				if targetHumanoid and targetHumanoid.Health > 0 then
					character:SetAttribute("Dead", true)
					character:SetAttribute("Ragdolled", true)
					targetHumanoid.Health = 0
					pcall(function() targetHumanoid:TakeDamage(targetHumanoid.MaxHealth + 1000) end)
				end
			end
		end
	end

	-- Only a LOST target forces an immediate search; with no target the search keeps its
	-- TARGET_REFRESH_INTERVAL instead of walking every player on every Heartbeat.
	if currentTargetPlayer and (not eligibleCurrentRoot or eligibleCurrentRoot ~= currentTargetRoot) then
		currentTargetPlayer = nil
		currentTargetRoot = nil
		nextTargetRefreshAt = 0
	end

	if now >= nextTargetRefreshAt then
		currentTargetPlayer, currentTargetRoot = findClosestTarget()
		nextTargetRefreshAt = now + TARGET_REFRESH_INTERVAL
		setTrackingState(currentTargetPlayer)
	end

	if not currentTargetPlayer or not currentTargetRoot then
		returnToSpawn(deltaTime)
		return
	end

	boss:SetAttribute("ReturningToSpawn", false)
	setMotionActive(true)
	setSonicSpeed(chaseSpeedFor(currentTargetPlayer))

	local targetVelocity = horizontal(currentTargetRoot.AssemblyLinearVelocity)
	local lead = targetVelocity * TARGET_LEAD_SECONDS
	if lead.Magnitude > MAX_TARGET_LEAD_STUDS then
		lead = lead.Unit * MAX_TARGET_LEAD_STUDS
	end
	local goal = currentTargetRoot.Position + lead
	local displacement = horizontal(goal - root.Position)
	local distance = displacement.Magnitude
	if distance <= ARRIVAL_DISTANCE then
		humanoid:Move(Vector3.zero, false)
		root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
		smoothedDirection = Vector3.zero
		return
	end
	local desiredDirection = horizontalUnit(displacement)
	if not desiredDirection then
		return
	end
	local responseAlpha = 1 - math.exp(-STEERING_RESPONSE * math.min(deltaTime, 0.1))
	if smoothedDirection.Magnitude < 0.001 then
		smoothedDirection = desiredDirection
	else
		local blended = smoothedDirection:Lerp(desiredDirection, responseAlpha)
		smoothedDirection = horizontalUnit(blended) or desiredDirection
	end
	humanoid:Move(smoothedDirection, false)
end)

print(
	"[World2SonicEXEBoss] V306IG active | speed="
		.. tostring(SONIC_WALK_SPEED)
		.. " | area bounds=" .. tostring(#areaBounds)
		.. " | grounded R15 | returns home when idle | client-only contact detection"
)
