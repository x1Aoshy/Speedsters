local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local TELEPORT_INVULNERABLE_SECONDS = 1.5

local function armTeleportInvulnerability(player)
	local serial = math.max(0, math.floor(tonumber(player:GetAttribute("StageTeleportProtectionSerial")) or 0)) + 1
	player:SetAttribute("StageTeleportProtectionSerial", serial)
	player:SetAttribute("StageTeleportInvulnerable", true)
	player:SetAttribute("StageTeleportArrivalGraceUntil", os.clock() + TELEPORT_INVULNERABLE_SECONDS)
	-- The same window on the clock clients share (2026-09-21): the attribute above is this
	-- server's os.clock(), which a client cannot compare with its own.
	player:SetAttribute("StageTeleportArrivalGraceUntilServerTime", Workspace:GetServerTimeNow() + TELEPORT_INVULNERABLE_SECONDS)
	task.delay(TELEPORT_INVULNERABLE_SECONDS, function()
		if player.Parent == Players
			and tonumber(player:GetAttribute("StageTeleportProtectionSerial")) == serial
		then
			player:SetAttribute("StageTeleportInvulnerable", false)
		end
	end)
end

-- Update 4 (2026-09-25): World 2 and 3 return their own teleport service below; each gets the
-- same ArmArrivalGrace export (the race server calls it after arena teleports) unless it has one.
local function withArrivalGrace(service)
	if type(service) == "table" and service.ArmArrivalGrace == nil then
		service.ArmArrivalGrace = armTeleportInvulnerability
	end
	return service
end

-- World 2 has authored Stage2=SafeZone1.2 .. Stage10=SafeZone9.2.
-- Use the same resolver for purchases, movement validation and pad returns.
if Config.IsWorld2Place == true then
	return withArrivalGrace(require(game:GetService("ServerScriptService"):WaitForChild("Gameplay"):WaitForChild("World2StageTeleportService")))
end
-- World 3 reads its stages from the desert map's "Stage N" folders.
if Config.IsWorld3Place == true then
	return withArrivalGrace(require(game:GetService("ServerScriptService"):WaitForChild("Gameplay"):WaitForChild("World3StageTeleportService")))
end
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
-- Update 4 (2026-09-25): the race server arms the same arrival grace after its own teleports
-- (arena <-> lobby), so pads, hazards and bosses treat a race return like a stage trip.
StageTeleportService.ArmArrivalGrace = armTeleportInvulnerability

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
Players.PlayerAdded:Connect(setupPlayerSpawnCapture)
for _, player in ipairs(Players:GetPlayers()) do
	setupPlayerSpawnCapture(player)
end
Players.PlayerRemoving:Connect(function(player)
	playerNormalSpawnCFrames[player] = nil
end)

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
	if not targetCFrame then targetCFrame = canonicalCFrame end
	if not targetCFrame then targetCFrame = playerNormalSpawnCFrames[player] end
	if not targetCFrame then return false, "Spawn is not ready" end

	armTeleportInvulnerability(player)
	humanoid.Health = humanoid.MaxHealth
	zeroCharacterVelocity(character)
	character:PivotTo(targetCFrame)
	zeroCharacterVelocity(character)
	player:SetAttribute("CurrentSafeZoneStage", 0)

	local vmgRebase = _G.VortexMovementGuardRebase
	if type(vmgRebase) == "function" then
		pcall(vmgRebase, player, 0)
	end

	return true
end

local function safeZoneName(stageNumber)
	if IS_NEW_WORLD1 then
		return tostring(Config.NewWorld1SafeZonePrefix or "stage") .. tostring(stageNumber)
	end
	if IS_WORLD2 then
		if stageNumber >= 2 and stageNumber <= STAGE_COUNT then
			return "SafeZone" .. tostring(stageNumber - 1) .. WORLD2_SAFE_ZONE_SUFFIX
		end
		return nil
	end
	return "SafeZone" .. tostring(stageNumber)
end

local objectsByName, lavaParts = {}, {}
local function indexObject(object)
	local lower = string.lower(object.Name)
	objectsByName[lower] = objectsByName[lower] or {}
	table.insert(objectsByName[lower], object)
	if object:IsA("BasePart") and string.find(lower, "lava", 1, true) then lavaParts[object] = true end
end
for _, object in ipairs(Workspace:GetDescendants()) do indexObject(object) end
Workspace.DescendantAdded:Connect(indexObject)
Workspace.DescendantRemoving:Connect(function(object)
	local bucket = objectsByName[string.lower(object.Name)]
	local index = bucket and table.find(bucket, object)
	if index then table.remove(bucket, index) end
	lavaParts[object] = nil
end)
local function findDescendantByName(parent, targetName)
	if not parent or not targetName then return nil end
	for _, object in ipairs(objectsByName[string.lower(targetName)] or {}) do
		if object.Parent and object:IsDescendantOf(parent) then return object end
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
		local ok, cf, size = pcall(function() return object:GetBoundingBox() end)
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

local function chooseLandingPosition(topCenter, forward, right, targetSize, stageNumber)
	return topCenter
end

local function resolveStageTarget(stageNumber)
	stageNumber = math.floor(tonumber(stageNumber) or 0)
	if stageNumber < 1 or stageNumber > STAGE_COUNT then return nil end

	if IS_WORLD2 then
		if stageNumber == 1 then
			return cachedNormalSpawn
		end
		local name = safeZoneName(stageNumber)
		local safeZone = name and findDescendantByName(STAGE_SEARCH_ROOT, name)
		if safeZone and (safeZone:IsA("BasePart") or safeZone:IsA("Model")) then
			return safeZone
		end
		if stageNumber == STAGE_COUNT then
			local finalWin = findDescendantByName(STAGE_SEARCH_ROOT, "WinStage.2")
				or findDescendantByName(STAGE_SEARCH_ROOT, "WinStageX2")
				or findDescendantByName(STAGE_SEARCH_ROOT, "SafeZone10.2")
				or findDescendantByName(STAGE_SEARCH_ROOT, "WinStageWin")
			if finalWin then return finalWin end
		end
		return nil
	end

	local decor = Workspace:FindFirstChild("StageDecor_Runtime")
	if decor then
		local floorName = string.format("Stage%02d_Floor", stageNumber)
		local floor = findDescendantByName(decor, floorName)
		if floor and floor:IsA("BasePart") then return floor end
	end

	local safeZone = STAGE_SEARCH_ROOT and findDescendantByName(STAGE_SEARCH_ROOT, safeZoneName(stageNumber))
	if safeZone and (safeZone:IsA("BasePart") or safeZone:IsA("Model")) then
		return safeZone
	end

	return nil
end

function StageTeleportService.GetStageReferencePosition(stageNumber)
	stageNumber = math.floor(tonumber(stageNumber) or 0)
	if stageNumber < 1 or stageNumber > STAGE_COUNT then return nil end

	if IS_WORLD2 and stageNumber == 1 then
		if cachedNormalSpawn and cachedNormalSpawn.Parent then
			return cachedNormalSpawn.Position
		end
		return Vector3.new(-783.8316, 36628.5, -993.7578)
	end

	local target = resolveStageTarget(stageNumber)
	if not target then return nil end

	local topCenter = getTopCenterAndAxes(target)
	return topCenter
end

function StageTeleportService.GetNearestStage(position)
	if typeof(position) ~= "Vector3" then return nil, nil end

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

	if IS_WORLD2 and stageNumber == 1 then
		return StageTeleportService.TeleportToNormalSpawn(player)
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

	-- Detección de Lava: si hay lava cerca o debajo del safe zone, colocar al jugador arriba
	local extraHeight = 0
	local highestLavaTop = -math.huge
	local lavaNear = false

	for obj in pairs(lavaParts) do
		if obj.Parent then
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

	local vmgRebase = _G.VortexMovementGuardRebase
	if type(vmgRebase) == "function" then
		pcall(vmgRebase, player, stageNumber)
	end

	return true
end

return StageTeleportService
