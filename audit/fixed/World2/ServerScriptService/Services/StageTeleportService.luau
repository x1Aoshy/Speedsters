local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local STAGE_COUNT = math.max(1, math.floor(tonumber(Config.StageCount) or 10))
local IS_WORLD2 = Config.IsWorld2Place == true
local IS_NEW_WORLD1 = Config.IsNewWorld1Map == true
local WORLD2_SAFE_ZONE_SUFFIX = tostring(Config.World2SafeZoneSuffix or ".2")
local STAGE_SEARCH_ROOT = Workspace
if IS_NEW_WORLD1 then
	local markerName = tostring(Config.NewWorld1MapMarkerName or "neworld1")
	STAGE_SEARCH_ROOT = Workspace:FindFirstChild(markerName) or Workspace:WaitForChild(markerName, 20)
end

local StageTeleportService = {}
local TELEPORT_INVULNERABLE_SECONDS = 4

local function armTeleportInvulnerability(player)
	local serial = math.max(0, math.floor(tonumber(player:GetAttribute("StageTeleportProtectionSerial")) or 0)) + 1
	player:SetAttribute("StageTeleportProtectionSerial", serial)
	player:SetAttribute("StageTeleportInvulnerable", true)
	player:SetAttribute("StageTeleportArrivalGraceUntil", os.clock() + TELEPORT_INVULNERABLE_SECONDS)
	task.delay(TELEPORT_INVULNERABLE_SECONDS, function()
		if player.Parent == Players
			and tonumber(player:GetAttribute("StageTeleportProtectionSerial")) == serial
		then
			player:SetAttribute("StageTeleportInvulnerable", false)
		end
	end)
end

                                                                              
                                                                              
                                                                              
local cachedNormalSpawn = nil
local playerNormalSpawnCFrames = {}

local function considerNormalSpawn(object)
	if object and object:IsA("SpawnLocation") and object.Enabled then
		if not cachedNormalSpawn or not cachedNormalSpawn.Parent
			or object:GetFullName() < cachedNormalSpawn:GetFullName()
		then
			cachedNormalSpawn = object
		end
	end
end

if IS_NEW_WORLD1 then
	for _, object in ipairs(Workspace:GetDescendants()) do
		considerNormalSpawn(object)
	end
	Workspace.DescendantAdded:Connect(considerNormalSpawn)
	Workspace.DescendantRemoving:Connect(function(object)
		if object == cachedNormalSpawn then
			cachedNormalSpawn = nil
			                                                            
			for _, candidate in ipairs(Workspace:GetDescendants()) do
				considerNormalSpawn(candidate)
			end
		end
	end)
end

local function captureNormalSpawnCFrame(player, character)
	local root = character and character:WaitForChild("HumanoidRootPart", 10)
	if root and root:IsA("BasePart") then
		                                                                        
		                                                                       
		                                                      
		RunService.Heartbeat:Wait()
		if player.Parent and character.Parent and root.Parent then
			playerNormalSpawnCFrames[player] = root.CFrame
		end
	end
end

local function setupPlayerSpawnCapture(player)
	player.CharacterAdded:Connect(function(character)
		task.spawn(captureNormalSpawnCFrame, player, character)
	end)
	if player.Character then
		task.spawn(captureNormalSpawnCFrame, player, player.Character)
	end
end
if IS_NEW_WORLD1 then
	Players.PlayerAdded:Connect(setupPlayerSpawnCapture)
	for _, player in ipairs(Players:GetPlayers()) do
		setupPlayerSpawnCapture(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		playerNormalSpawnCFrames[player] = nil
	end)
end

local function zeroCharacterVelocity(character)
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.AssemblyLinearVelocity = Vector3.zero
			descendant.AssemblyAngularVelocity = Vector3.zero
		end
	end
end

function StageTeleportService.TeleportToNormalSpawn(player)
	local character = player and player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 then
		return false, "Character is not ready"
	end

	-- The canonical true course spawn is always preferred for a win-pad
	-- return. The recaptured per-character CFrame is only trusted when it
	-- actually sits at the true spawn, so a stray capture (e.g. while a
	-- player is on a farmed stage) can never land the player back on stage.
	local canonicalSpawn = player.RespawnLocation
	if not (canonicalSpawn and canonicalSpawn:IsA("SpawnLocation") and canonicalSpawn.Parent and canonicalSpawn.Enabled) then
		canonicalSpawn = cachedNormalSpawn
	end
	local canonicalCFrame = nil
	if canonicalSpawn and canonicalSpawn.Parent then
		canonicalCFrame = canonicalSpawn.CFrame * CFrame.new(0, 3.5, 0)
	end

	local targetCFrame = nil
	local recaptured = playerNormalSpawnCFrames[player]
	if recaptured and canonicalCFrame then
		local delta = (recaptured.Position - canonicalCFrame.Position)
		delta = Vector3.new(delta.X, 0, delta.Z)
		if delta.Magnitude <= 20 then
			targetCFrame = canonicalCFrame
		end
	end
	if not targetCFrame then
		targetCFrame = canonicalCFrame
	end
	if not targetCFrame then
		targetCFrame = playerNormalSpawnCFrames[player]
	end
	if not targetCFrame then
		return false, "Normal Roblox spawn is not ready"
	end

	armTeleportInvulnerability(player)
	humanoid.Health = humanoid.MaxHealth
	zeroCharacterVelocity(character)
	character:PivotTo(targetCFrame)
	zeroCharacterVelocity(character)
	player:SetAttribute("CurrentSafeZoneStage", 0)

	-- Notify MovementGuard: returning to spawn starts a fresh clean run.
	local vmgRebase = _G.VortexMovementGuardRebase
	if type(vmgRebase) == "function" then
		pcall(vmgRebase, player, 1)
	end

	return true
end

                                                                              
                                                                              
                                                                       
local newWorld1StageCandidates = {}

local function newWorld1StageIndex(object)
	if not IS_NEW_WORLD1
		or not object
		or not (object:IsA("BasePart") or object:IsA("Model"))
	then
		return nil
	end
	local normalized = string.lower(tostring(object.Name)):gsub("[^%w]", "")
	local stageNumber = tonumber(normalized:match("^stage(%d+)$"))
	if stageNumber and stageNumber >= 1 and stageNumber <= STAGE_COUNT then
		return math.floor(stageNumber)
	end
	return nil
end

local function registerNewWorld1Stage(object)
	local stageNumber = newWorld1StageIndex(object)
	if not stageNumber then
		return false
	end
	local candidates = newWorld1StageCandidates[stageNumber]
	if not candidates then
		candidates = {}
		newWorld1StageCandidates[stageNumber] = candidates
	end
	candidates[object] = true
	return true
end

local function newWorld1ObjectDepth(object)
	local depth = 0
	local current = object
	while current and current ~= STAGE_SEARCH_ROOT do
		depth += 1
		current = current.Parent
	end
	return depth
end

local function getCachedNewWorld1Stage(stageNumber)
	local candidates = newWorld1StageCandidates[stageNumber]
	local best = nil
	for object in pairs(candidates or {}) do
		if object.Parent and object:IsDescendantOf(STAGE_SEARCH_ROOT) then
			if not best
				or newWorld1ObjectDepth(object) < newWorld1ObjectDepth(best)
				or (newWorld1ObjectDepth(object) == newWorld1ObjectDepth(best)
					and object:GetFullName() < best:GetFullName())
			then
				best = object
			end
		else
			candidates[object] = nil
		end
	end
	return best
end

if IS_NEW_WORLD1 and STAGE_SEARCH_ROOT then
	for _, object in ipairs(STAGE_SEARCH_ROOT:GetDescendants()) do
		registerNewWorld1Stage(object)
	end
	STAGE_SEARCH_ROOT.DescendantAdded:Connect(registerNewWorld1Stage)
	STAGE_SEARCH_ROOT.DescendantRemoving:Connect(function(object)
		local stageNumber = newWorld1StageIndex(object)
		local candidates = stageNumber and newWorld1StageCandidates[stageNumber]
		if candidates then
			candidates[object] = nil
		end
	end)
end

local function safeZoneName(stageNumber)
	if IS_NEW_WORLD1 then
		return tostring(Config.NewWorld1SafeZonePrefix or "stage") .. tostring(stageNumber)
	end
	return "SafeZone"
		.. tostring(stageNumber)
		.. (IS_WORLD2 and WORLD2_SAFE_ZONE_SUFFIX or "")
end

local function findDescendantByName(parent, targetName)
    if not parent then
        return nil
    end

    local direct = parent:FindFirstChild(targetName, true)
    if direct then
        return direct
    end

    local wantedLower = string.lower(tostring(targetName))
    for _, object in ipairs(parent:GetDescendants()) do
        if string.lower(object.Name) == wantedLower then
            return object
        end
    end

    return nil
end

local function getTopCenterAndAxes(object)
	if object:IsA("BasePart") then
		local cf = object.CFrame
        local halfY = math.abs(cf.RightVector.Y) * object.Size.X * 0.5
            + math.abs(cf.UpVector.Y) * object.Size.Y * 0.5
            + math.abs(cf.LookVector.Y) * object.Size.Z * 0.5
        local forward = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
        if forward.Magnitude < 0.01 then
            forward = Vector3.new(0, 0, -1)
        else
            forward = forward.Unit
        end
		local right = Vector3.new(cf.RightVector.X, 0, cf.RightVector.Z)
		right = right.Magnitude >= 0.01 and right.Unit or Vector3.xAxis
		return Vector3.new(cf.Position.X, cf.Position.Y + halfY, cf.Position.Z), forward, right, object.Size
    end

    if object:IsA("Model") then
        local ok, cf, size = pcall(function()
            return object:GetBoundingBox()
        end)
        if ok and cf and size then
            local halfY = math.abs(cf.RightVector.Y) * size.X * 0.5
                + math.abs(cf.UpVector.Y) * size.Y * 0.5
                + math.abs(cf.LookVector.Y) * size.Z * 0.5
            local forward = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
            if forward.Magnitude < 0.01 then
                forward = Vector3.new(0, 0, -1)
            else
                forward = forward.Unit
            end
			local right = Vector3.new(cf.RightVector.X, 0, cf.RightVector.Z)
			right = right.Magnitude >= 0.01 and right.Unit or Vector3.xAxis
			return Vector3.new(cf.Position.X, cf.Position.Y + halfY, cf.Position.Z), forward, right, size
        end
    end

	return nil, nil, nil, nil
end

local function isClearOfStagePads(position, stageNumber)
	local function overlapsPad(object)
		if not object:IsA("BasePart")
			or tonumber(object:GetAttribute("SafeZoneIndex")) ~= stageNumber
		then
			return false
		end
		local delta = object.Position - position
		local horizontalDistance = Vector3.new(delta.X, 0, delta.Z).Magnitude
		local clearance = math.max(object.Size.X, object.Size.Z) * 0.75 + 3
		return horizontalDistance < clearance
	end

    local folder = Workspace:FindFirstChild("WinPads_TO_PLACE")
	if folder then
		for _, object in ipairs(folder:GetChildren()) do
			if overlapsPad(object) then
				return false
			end
		end
	end

	                                                                        
	                                                                           
	local decor = Workspace:FindFirstChild("StageDecor_Runtime")
	if decor then
		for _, object in ipairs(decor:GetDescendants()) do
			if object:GetAttribute("SkipStageProductId") ~= nil and overlapsPad(object) then
				return false
			end
		end
	end

	                                                                             
	                                                                             
	local manualPads = Workspace:FindFirstChild("NewWorld1ManualStagePads_Runtime")
	if manualPads then
		for _, object in ipairs(manualPads:GetChildren()) do
			if object:GetAttribute("NewWorld1ManualPad") == true and overlapsPad(object) then
				return false
			end
		end
	end

	return true
end

local function chooseLandingPosition(topCenter, forward, right, targetSize, stageNumber)
	local halfWidth = targetSize and targetSize.X * 0.5 or 0
	local halfDepth = targetSize and targetSize.Z * 0.5 or 0
	local sideOffset = math.min(12, math.max(0, halfWidth - 3.5))
	local forwardOffset = math.min(9, math.max(0, halfDepth - 3.5))

	                                                                          
	                                                                          
	                                                                        
	local candidates = {
		topCenter - right * sideOffset,
		topCenter - right * (sideOffset * 0.55) - forward * (forwardOffset * 0.45),
		topCenter - forward * forwardOffset,
		topCenter + forward * forwardOffset,
		topCenter,
	}

	for _, candidate in ipairs(candidates) do
		if isClearOfStagePads(candidate, stageNumber) then
			return candidate
		end
	end

	return topCenter
end

local function resolveStageTarget(stageNumber)
    stageNumber = math.floor(tonumber(stageNumber) or 0)
    if stageNumber < 1 or stageNumber > STAGE_COUNT then
        return nil
    end

    if IS_NEW_WORLD1 then
		return getCachedNewWorld1Stage(stageNumber)
	end

    local decor = Workspace:FindFirstChild("StageDecor_Runtime")
    if decor then
        local floorName = string.format("Stage%02d_Floor", stageNumber)
        local floor = findDescendantByName(decor, floorName)
        if floor and floor:IsA("BasePart") then
            return floor
        end
    end

    local safeZone = STAGE_SEARCH_ROOT and findDescendantByName(STAGE_SEARCH_ROOT, safeZoneName(stageNumber))
    if safeZone and (safeZone:IsA("BasePart") or safeZone:IsA("Model")) then
        return safeZone
    end

    return nil
end

function StageTeleportService.GetStageReferencePosition(stageNumber)
	stageNumber = math.floor(tonumber(stageNumber) or 0)
	if stageNumber < 1 or stageNumber > STAGE_COUNT then
		return nil
	end

	local target = resolveStageTarget(stageNumber)
	if not target then
		return nil
	end

	local topCenter = getTopCenterAndAxes(target)
	return topCenter
end

function StageTeleportService.GetNearestStage(position)
	if typeof(position) ~= "Vector3" then
		return nil, nil
	end

	local nearestStage = nil
	local nearestDistance = math.huge
	for stageNumber = 1, STAGE_COUNT do
		local stagePosition = StageTeleportService.GetStageReferencePosition(stageNumber)
		if stagePosition then
			                                                                    
			                                                                    
			                                                       
			local delta = position - stagePosition
			local horizontalDistance = Vector3.new(delta.X, 0, delta.Z).Magnitude
			local distance = horizontalDistance + math.abs(delta.Y) * 0.001
			if distance < nearestDistance then
				nearestStage = stageNumber
				nearestDistance = distance
			end
		end
	end

	return nearestStage, nearestDistance
end

function StageTeleportService.TeleportPlayer(player, stageNumber)
    stageNumber = math.floor(tonumber(stageNumber) or 0)
    if stageNumber < 1 or stageNumber > STAGE_COUNT then
        return false, "Invalid stage"
    end

    local target = resolveStageTarget(stageNumber)
    if not target then
        return false, "Stage " .. tostring(stageNumber) .. " is not ready"
    end

    local character = player and player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not character or not humanoid or not root or humanoid.Health <= 0 then
        return false, "Character is not ready"
    end

	local topCenter, forward, right, targetSize = getTopCenterAndAxes(target)
	if not topCenter then
        return false, "Stage " .. tostring(stageNumber) .. " is not ready"
    end

    local standHeight = math.max(3.5, (tonumber(humanoid.HipHeight) or 2) + root.Size.Y * 0.5 + 0.55)
	local landingSurfacePosition = chooseLandingPosition(topCenter, forward, right, targetSize, stageNumber)

	-- Si hay lava cerca del safe zone o abajo, poner al jugador arriba (+5.5 studs de elevacion segura)
	local extraHeight = 0
	local highestLavaTop = -math.huge
	local lavaNear = false

	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj:IsA("BasePart") and string.find(string.lower(obj.Name), "lava") then
			local delta = obj.Position - landingSurfacePosition
			local hDist = math.sqrt(delta.X * delta.X + delta.Z * delta.Z)
			if hDist < 120 and math.abs(delta.Y) < 150 then
				lavaNear = true
				local lTop = obj.Position.Y + obj.Size.Y * 0.5
				if lTop > highestLavaTop then
					highestLavaTop = lTop
				end
			end
		end
	end

	if lavaNear then
		extraHeight = 5.5
		if highestLavaTop > -math.huge and (highestLavaTop + standHeight + 2.0) > (landingSurfacePosition.Y + standHeight + extraHeight) then
			landingSurfacePosition = Vector3.new(landingSurfacePosition.X, highestLavaTop + 2.0, landingSurfacePosition.Z)
		end
	end

	local targetPosition = landingSurfacePosition + Vector3.new(0, standHeight + extraHeight, 0)
	local targetCFrame = CFrame.lookAt(targetPosition, targetPosition + forward, Vector3.yAxis)

	armTeleportInvulnerability(player)
	root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    character:PivotTo(targetCFrame)
    root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	player:SetAttribute("LastReachedStage", stageNumber)
	player:SetAttribute("CurrentSafeZoneStage", stageNumber)

	-- Notify MovementGuard so this sanctioned teleport does not count as a
	-- teleport anomaly (progress is rebased to the destination stage).
	local vmgRebase = _G.VortexMovementGuardRebase
	if type(vmgRebase) == "function" then
		pcall(vmgRebase, player, stageNumber)
	end

	return true
end

return StageTeleportService
