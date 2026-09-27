local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
if Config.IsNewWorld1Map == true then
	return
end

                           
local PRESSER_COUNT = 5
local LIFT_HEIGHT = 37
local UP_SPEED = 12.5
local DOWN_SPEED = 270
local TOP_PAUSE = 0.37
local BOTTOM_PAUSE = 0.17
local START_DELAY = 0.5
local PRESSER_SEQUENCE_STAGGER = 0.62

local activePresserControllers = {}
local UP_TRAVEL_DURATION = LIFT_HEIGHT / UP_SPEED
local DOWN_TRAVEL_DURATION = LIFT_HEIGHT / DOWN_SPEED
local PRESSER_CYCLE_PERIOD = UP_TRAVEL_DURATION + TOP_PAUSE + DOWN_TRAVEL_DURATION + BOTTOM_PAUSE

local PRESSER_SOUND_ID = "rbxassetid://109100548085585"
local PRESSER_SOUND_VOLUME = 0.82
local PRESSER_SOUND_MIN_DISTANCE = 8
local PRESSER_SOUND_MAX_DISTANCE = 65

                                                                          
                                                                                
                                                                    
local function findWorkspaceObject(name, timeoutSeconds)
	local lowerName = string.lower(name)
	local deadline = os.clock() + (timeoutSeconds or 10)
	repeat
		local exact = Workspace:FindFirstChild(name, true)
		if exact then
			return exact
		end

		for _, descendant in ipairs(Workspace:GetDescendants()) do
			if string.lower(descendant.Name) == lowerName then
				return descendant
			end
		end

		                                                                    
		                                                               
		task.wait(0.1)
	until os.clock() >= deadline

	return nil
end

local function getObjectPivot(object)
	if object:IsA("Model") then
		return object:GetPivot()
	elseif object:IsA("BasePart") then
		return object.CFrame
	end

	local firstPart = object:FindFirstChildWhichIsA("BasePart", true)
	if firstPart then
		return firstPart.CFrame
	end

	return nil
end

local function setObjectPivot(object, pivot)
	if object:IsA("Model") then
		object:PivotTo(pivot)
	elseif object:IsA("BasePart") then
		object.CFrame = pivot
	else
		local currentPivot = getObjectPivot(object)
		if not currentPivot then
			return false
		end

		local delta = pivot * currentPivot:Inverse()
		for _, descendant in ipairs(object:GetDescendants()) do
			if descendant:IsA("BasePart") then
				descendant.CFrame = delta * descendant.CFrame
			end
		end
	end

	return true
end

local function getBounds(object)
	if object:IsA("BasePart") then
		return object.CFrame, object.Size
	elseif object:IsA("Model") then
		return object:GetBoundingBox()
	end

	local minPoint = Vector3.new(math.huge, math.huge, math.huge)
	local maxPoint = Vector3.new(-math.huge, -math.huge, -math.huge)
	local foundPart = false

	for _, descendant in ipairs(object:GetDescendants()) do
		if descendant:IsA("BasePart") then
			foundPart = true
			local half = descendant.Size * 0.5
			for x = -1, 1, 2 do
				for y = -1, 1, 2 do
					for z = -1, 1, 2 do
						local corner = descendant.CFrame:PointToWorldSpace(Vector3.new(
							half.X * x,
							half.Y * y,
							half.Z * z
						))
						minPoint = Vector3.new(
							math.min(minPoint.X, corner.X),
							math.min(minPoint.Y, corner.Y),
							math.min(minPoint.Z, corner.Z)
						)
						maxPoint = Vector3.new(
							math.max(maxPoint.X, corner.X),
							math.max(maxPoint.Y, corner.Y),
							math.max(maxPoint.Z, corner.Z)
						)
					end
				end
			end
		end
	end

	if not foundPart then
		return nil, nil
	end

	local size = maxPoint - minPoint
	local center = (minPoint + maxPoint) * 0.5
	return CFrame.new(center), size
end

local originalPresser = findWorkspaceObject("Presser1", 10)
if not originalPresser then
	warn("Presser1 was not found anywhere in Workspace")
	return
end
if not (originalPresser:IsA("Model") or originalPresser:IsA("BasePart") or originalPresser:IsA("Folder")) then
	warn("Presser1 must be a Model, BasePart, or Folder containing BaseParts")
	return
end

local sourceObby = findWorkspaceObject("obby1", 10)
if not sourceObby then
	warn("obby1 was not found anywhere in Workspace")
	return
end

local sourceObbyBounds = getBounds(sourceObby)
local sourcePresserPivot = getObjectPivot(originalPresser)
if not sourceObbyBounds or not sourcePresserPivot then
	warn("Presser1 and obby1 must contain BaseParts")
	return
end

                                                                            
                                                                           
                                                                            
                                                    
local presserRelativeToObby = sourceObbyBounds:ToObjectSpace(sourcePresserPivot)

originalPresser.Archivable = true
local template = originalPresser:Clone()
template.Parent = nil

local pressers = { [1] = originalPresser }

for index = 2, PRESSER_COUNT do
	local obby = findWorkspaceObject("obby" .. index, 10)
	if not obby then
		warn("obby" .. index .. " was not found; skipping Presser" .. index)
		continue
	end

	local obbyBounds = getBounds(obby)
	if not obbyBounds then
		warn("obby" .. index .. " must contain BaseParts")
		continue
	end

	local oldPresser = Workspace:FindFirstChild("Presser" .. index, true)
	if oldPresser and oldPresser ~= originalPresser then
		oldPresser:Destroy()
	end

	local presser = template:Clone()
	presser.Name = "Presser" .. index
	presser.Parent = Workspace

	local targetPivot = obbyBounds * presserRelativeToObby
	if setObjectPivot(presser, targetPivot) then
		pressers[index] = presser
	else
		warn("Could not place Presser" .. index .. " over obby" .. index)
		presser:Destroy()
	end
end

template:Destroy()

local safeZoneCache = {}

local function findSafeZoneNow(zoneIndex)
	local wanted = string.lower("SafeZone" .. tostring(zoneIndex))
	local exact = Workspace:FindFirstChild("SafeZone" .. tostring(zoneIndex), true)
	if exact and (exact:IsA("BasePart") or exact:IsA("Model")) then
		return exact
	end
	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if string.lower(descendant.Name) == wanted
			and (descendant:IsA("BasePart") or descendant:IsA("Model"))
		then
			return descendant
		end
	end
	return nil
end

local function pointInsideSafeZone(point, safeZone)
	local boundsCFrame, boundsSize = getBounds(safeZone)
	if not boundsCFrame or not boundsSize then
		return false
	end

	local localPoint = boundsCFrame:PointToObjectSpace(point)
	local halfSize = boundsSize * 0.5
	return math.abs(localPoint.X) <= halfSize.X + 0.75
		and math.abs(localPoint.Z) <= halfSize.Z + 0.75
		and localPoint.Y >= -halfSize.Y - 2
		and localPoint.Y <= halfSize.Y + 12
end

local function isCharacterSafe(player, character)
	if player:GetAttribute("SafeZoneProtected") == true
		or character:GetAttribute("SafeZoneProtected") == true
	then
		return true
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end

	for zoneIndex = 1, 10 do
		local safeZone = safeZoneCache[zoneIndex]
		if not safeZone or not safeZone.Parent then
			safeZone = findSafeZoneNow(zoneIndex)
			safeZoneCache[zoneIndex] = safeZone
		end
		if safeZone and pointInsideSafeZone(root.Position, safeZone) then
			return true
		end
	end

	                                                                           
	                                                                          
	                                              
	return false
end

local function findPlayerHumanoid(hit)
	local current = hit
	while current and current ~= Workspace do
		if current:IsA("Model") then
			local humanoid = current:FindFirstChildOfClass("Humanoid")
			local player = Players:GetPlayerFromCharacter(current)
			if humanoid and player then
				return humanoid, current, player
			end
		end
		current = current.Parent
	end
	return nil, nil, nil
end

local function startPresser(presser, index)
	local movingParts = {}
	local touchConnections = {}
	local lastPartCFrames = {}

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = { presser }
	overlapParams.RespectCanCollide = false

	local function killFromHit(hit)
		local humanoid, character, player = findPlayerHumanoid(hit)
		if humanoid
			and humanoid.Health > 0
			and player:GetAttribute("StageTeleportInvulnerable") ~= true
			and not isCharacterSafe(player, character)
		then
			humanoid.Health = 0
		end
	end

	local function registerPart(part)
		if not part:IsA("BasePart") or touchConnections[part] then
			return
		end

		part.Anchored = true
		part.CanTouch = true
		part.CanQuery = true
		part.AssemblyLinearVelocity = Vector3.zero
		part.AssemblyAngularVelocity = Vector3.zero

		table.insert(movingParts, part)
		lastPartCFrames[part] = part.CFrame
		touchConnections[part] = part.Touched:Connect(killFromHit)
	end

	if presser:IsA("BasePart") then
		registerPart(presser)
	end
	for _, descendant in ipairs(presser:GetDescendants()) do
		registerPart(descendant)
	end
	presser.DescendantAdded:Connect(registerPart)

	if #movingParts == 0 then
		warn(presser.Name .. " does not contain any BaseParts")
		return nil
	end

	local boundsCFrame = getBounds(presser)
	local soundPart = movingParts[1]
	if boundsCFrame then
		local closestDistance = math.huge
		for _, part in ipairs(movingParts) do
			local distance = (part.Position - boundsCFrame.Position).Magnitude
			if distance < closestDistance then
				closestDistance = distance
				soundPart = part
			end
		end
	end

	local oldEmitter = soundPart:FindFirstChild("PresserSoundEmitter")
	if oldEmitter then
		oldEmitter:Destroy()
	end

	local soundEmitter = Instance.new("Attachment")
	soundEmitter.Name = "PresserSoundEmitter"
	if boundsCFrame then
		soundEmitter.Position = soundPart.CFrame:PointToObjectSpace(boundsCFrame.Position)
	end
	soundEmitter.Parent = soundPart

	local presserSound = Instance.new("Sound")
	presserSound.Name = "PresserNearSound"
	presserSound.SoundId = PRESSER_SOUND_ID
	presserSound.Volume = PRESSER_SOUND_VOLUME
	presserSound.Looped = true
	presserSound.RollOffMode = Enum.RollOffMode.InverseTapered
	presserSound.RollOffMinDistance = PRESSER_SOUND_MIN_DISTANCE
	presserSound.RollOffMaxDistance = PRESSER_SOUND_MAX_DISTANCE
	presserSound.EmitterSize = 5
	presserSound.Parent = soundEmitter
	presserSound:Play()

	local function scanForPlayersTouchingPresser()
		for _, part in ipairs(movingParts) do
			if part.Parent then
				for _, touchingPart in ipairs(Workspace:GetPartsInPart(part, overlapParams)) do
					killFromHit(touchingPart)
				end

				                                                                
				                                                                 
				                                                                  
				                       
				local currentCFrame = part.CFrame
				local previousCFrame = lastPartCFrames[part] or currentCFrame
				local worldDelta = currentCFrame.Position - previousCFrame.Position
				local localDelta = currentCFrame:VectorToObjectSpace(worldDelta)
				local sweptSize = part.Size + Vector3.new(
					math.abs(localDelta.X),
					math.abs(localDelta.Y),
					math.abs(localDelta.Z)
				)
				local midpoint = (currentCFrame.Position + previousCFrame.Position) * 0.5
				local rotationOnly = currentCFrame - currentCFrame.Position
				local sweptCFrame = CFrame.new(midpoint) * rotationOnly

				for _, crossedPart in ipairs(Workspace:GetPartBoundsInBox(
					sweptCFrame,
					sweptSize,
					overlapParams
				)) do
					killFromHit(crossedPart)
				end

				lastPartCFrames[part] = currentCFrame
			end
		end
	end

	local function setPivot(pivot)
		if not presser.Parent then
			return
		end

		setObjectPivot(presser, pivot)
		for _, part in ipairs(movingParts) do
			if part.Parent then
				part.AssemblyLinearVelocity = Vector3.zero
				part.AssemblyAngularVelocity = Vector3.zero
			end
		end
		scanForPlayersTouchingPresser()
	end

	local bottomPivot = getObjectPivot(presser)
	if not bottomPivot then
		return nil
	end
	local topPivot = bottomPivot + Vector3.new(0, LIFT_HEIGHT, 0)

	local motion = Instance.new("CFrameValue")
	motion.Name = "Presser" .. index .. "Motion"
	motion.Value = bottomPivot
	motion.Parent = script

	motion:GetPropertyChangedSignal("Value"):Connect(function()
		setPivot(motion.Value)
	end)

	local function moveTo(targetPivot, studsPerSecond, easingStyle, easingDirection)
		local distance = (motion.Value.Position - targetPivot.Position).Magnitude
		local duration = math.max(distance / studsPerSecond, 0.04)
		local tween = TweenService:Create(
			motion,
			TweenInfo.new(duration, easingStyle, easingDirection),
			{ Value = targetPivot }
		)

		tween:Play()
		tween.Completed:Wait()
		motion.Value = targetPivot
	end

	local controller = {}
	controller.index = index
	controller.presser = presser
	controller.moveUp = function()
		if not presser.Parent then
			return
		end
		task.spawn(function()
			moveTo(topPivot, UP_SPEED, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		end)
	end
	controller.moveDown = function()
		if not presser.Parent then
			return
		end
		task.spawn(function()
			moveTo(bottomPivot, DOWN_SPEED, Enum.EasingStyle.Linear, Enum.EasingDirection.In)
		end)
	end
	return controller
end

for index = 1, PRESSER_COUNT do
	local presser = pressers[index]
	if presser then
		local controller = startPresser(presser, index)
		if controller then
			activePresserControllers[index] = controller
		end
	end
end

                                                                           
                                                                               
                                                                           
                                                                             
                                                                        
local function waitUntil(targetTime)
	local remaining = targetTime - os.clock()
	if remaining > 0 then
		task.wait(remaining)
	end
end

local function runOrderedWave(actionName, firstWaveTime)
	task.spawn(function()
		local waveStart = firstWaveTime
		while true do
			waitUntil(waveStart)
			local foundAny = false
			for index = 1, PRESSER_COUNT do
				local controller = activePresserControllers[index]
				if controller and controller.presser and controller.presser.Parent then
					foundAny = true
					controller[actionName]()
				end
				if index < PRESSER_COUNT then
					task.wait(PRESSER_SEQUENCE_STAGGER)
				end
			end
			if not foundAny then
				break
			end
			waveStart += PRESSER_CYCLE_PERIOD
		end
	end)
end

local firstUpWaveTime = os.clock() + START_DELAY
local firstDownWaveTime = firstUpWaveTime + UP_TRAVEL_DURATION + TOP_PAUSE
runOrderedWave("moveUp", firstUpWaveTime)
runOrderedWave("moveDown", firstDownWaveTime)

print(
	"[Presser1Controller] V306CV active | swept lethal contact | order=1-5 up/down | Up="
		.. tostring(UP_SPEED)
		.. " | Down="
		.. tostring(DOWN_SPEED)
		.. " | TopPause="
		.. tostring(TOP_PAUSE)
		.. " | BottomPause="
		.. tostring(BOTTOM_PAUSE)
		.. " | Stagger="
		.. tostring(PRESSER_SEQUENCE_STAGGER)
		.. " | SafeZones=protected"
)
