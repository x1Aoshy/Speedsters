                           
  
                                                                
                                 
            
                            
          
                                                                            
  
                                           
                             
                                                                                   
                                                                 
                                                               
                                                                              
  
                                                                         
                                     

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local IS_WORLD2 = Config.IsWorld2Place == true
local ServerScriptService = game:GetService("ServerScriptService")
local MovementGuard = require(ServerScriptService:WaitForChild("Services"):WaitForChild("MovementGuard"))

local function safeZoneName(zoneIndex)
	if Config.IsNewWorld1Map == true then
		return tostring(Config.NewWorld1SafeZonePrefix or "stage") .. tostring(zoneIndex)
	end
	return "SafeZone"
		.. tostring(zoneIndex)
		.. (IS_WORLD2 and tostring(Config.World2SafeZoneSuffix or ".2") or "")
end

local SAFE_ZONE_ATTRIBUTE = "SafeZoneProtected"
local SAFE_ZONE_FORCE_FIELD = "VortexSafeZoneForceField"
local SAFE_ZONE_COUNT = Config.IsNewWorld1Map == true and 11 or 10
local BALL_ROUTE_LAST_SAFE_ZONE = 6
local SAFE_ZONE_SCAN_SECONDS = IS_WORLD2 and 0 or 20
local SAFE_ZONE_CHECK_INTERVAL = 0.08
local SAFE_ZONE_SIDE_PADDING = 0.75
local SAFE_ZONE_BELOW_PADDING = 2
local SAFE_ZONE_HEIGHT_ABOVE = 12

                                                                        
                                                                      
                                            
local SAFE_ZONE_REWARDS = {
	[2] = 5,
	[3] = 15,
	[4] = 50,
	[5] = 200,
	[6] = 1000,
	[7] = 3500,
	[8] = 7000,
	[9] = 10000,
	[10] = 20000,
}

local PAD_FOLDER_NAME = "WinPads_TO_PLACE"
local PAD_MANUAL_FOLDER_ATTRIBUTE = "VortexManualPadPositions"
local PAD_INSTRUCTION_VALUE_NAME = "COPY_THIS_FOLDER_THEN_MOVE_COLORED_PADS"
local FIRST_PAD_SAFE_ZONE = 2
local WIN_PAD_FEEDBACK_REMOTE_NAME = "WinPadFeedback"
local RED_BALL_CONTACT_REMOTE_NAME = "RedBallContact"
local PAD_TOUCH_SOUND_ID = "rbxassetid://136993031050456"
local PAD_COLOR = Color3.fromRGB(255, 190, 0)
local PAD_LIGHT_COLOR = Color3.fromRGB(255, 135, 25)
local PAD_DOUBLE_WINS_COLOR = Color3.fromRGB(175, 45, 255)
local PAD_DOUBLE_WINS_LIGHT_COLOR = Color3.fromRGB(220, 100, 255)
local PAD_BASE_COLOR = Color3.fromRGB(18, 18, 18)
local PAD_TEXT_COLOR = Color3.fromRGB(255, 200, 0)
local PAD_TEXT_STROKE = Color3.fromRGB(0, 0, 0)
local PAD_MAX_SIZE = IS_WORLD2 and 8 or 5.5
local PAD_HEIGHT = IS_WORLD2 and 0.6 or 0.5
local PAD_BASE_HEIGHT = IS_WORLD2 and 0.34 or 0.28
local PAD_EDGE_MARGIN = IS_WORLD2 and 3 or 0.5
local PAD_RIGHT_OFFSET = 3
local PAD_ADDITIONAL_RIGHT_SHIFTS = IS_WORLD2 and {
	[2] = 0,
	[3] = 0,
	[4] = 0,
	[5] = 0,
	[6] = 0,
	[7] = 0,
	[8] = 0,
	[9] = 0,
	[10] = 0,
} or {
	[2] = 7,
	[3] = 7,
	[4] = 7,
	[5] = 7,
	[6] = 17,
	[7] = 24,
	[8] = 24,
	[9] = 0,
	[10] = 0,
}
local PAD_PAIR_GAP = IS_WORLD2 and 3.5 or 1.5
local PAD_CLAIM_COOLDOWN = 1.5
local DOUBLE_WINS_PAD_GAMEPASS_ID = tonumber(Config.DoubleWinsPadGamePassId) or 1941409601
local DOUBLE_WINS_PAD_PRODUCT_ID = tonumber(Config.DoubleWinsPadProductId) or 3712435111
local DOUBLE_WINS_PAD_MULTIPLIER = 2
local DOUBLE_WINS_PROMPT_COOLDOWN = 2
local PAD_REPAIR_INTERVAL = IS_WORLD2 and 2 or 1
local WIN_STAGE_BASE_REWARD = 50000
local WIN_STAGE_NORMAL_PAD_NAME = "WinStage_50000Wins"
local WIN_STAGE_DOUBLE_PAD_NAME = "WinStage_2xWins"
local WIN_STAGE_NORMAL_MARKER_NAME = "WINHERE"
local WIN_STAGE_DOUBLE_MARKER_NAME = "X2HERE"
local WIN_STAGE_MARKER_PAD_FOLDER_NAME = "WinStageMarkerPads"
local EXPECTED_PAD_COUNT = 0
for zoneIndex = FIRST_PAD_SAFE_ZONE, SAFE_ZONE_COUNT do
	if SAFE_ZONE_REWARDS[zoneIndex] then
		EXPECTED_PAD_COUNT += 1
	end
end

local BALL_NAME = "RedBall"
local BALL_DESPAWN_FOLDER_NAME = "VortexDespawnedHazards"
local BALL_RESET_PAUSE = 1.15
local BALL_MIN_ROLL_TIME = 3
local BALL_MAX_ROLL_TIME = 12
local BALL_STILL_SPEED = 1.2
local BALL_STILL_TIME = 1.1
local BALL_MAX_TRAVEL = 400
local BALL_INITIAL_SPEED = 30
local BALL_LAUNCH_ASSIST_TIME = 0.7
local BALL_PROBE_DIRECTIONS = 16
local BALL_SAFE_ZONE_GAP = 1
local BALL_EXTRA_TRAVEL_STUDS = 15
local BALL_DESPAWN_TIME = 1.37
local BALL_DAMAGE_HITBOX_NAME = "VortexRedBallDamageHitbox"
local BALL_DAMAGE_HITBOX_SCALE = 1

local HAMMER_COUNT = 5
local HAMMER_WHOOSH_SOUND_ID = "rbxassetid://138158731526545"
local HAMMER_WHOOSH_VOLUME = 2.6
local HAMMER_DEFAULT_ANGLE = 55
local HAMMER_DEFAULT_HALF_SWING_TIME = 1.2
local HAMMER_SWING_SPEED_MULTIPLIER = 0.819                                                    
local HAMMER_PHASE_OFFSETS = {
	-math.pi * 0.5,
	math.pi * 0.5,
	0,
	math.pi,
	-math.pi * 0.25,
}

local STATIC_LETHAL_HAZARD_NAMES = {
	"Water",
	"Water1",
	"Water2",
	"Water3",
	"Water4",
	"Water5",
}
local STATIC_LETHAL_HAZARD_NAME_SET = {
	water = true,
	water1 = true,
	water2 = true,
	water3 = true,
	water4 = true,
	water5 = true,
}

local safeZones = {}
local allSafeZonesFound = false
local lastPadClaimAt = {}
local lastDoubleWinsPromptAt = {}
local doubleWinsPassOwned = {}
local connectedWinPads = setmetatable({}, { __mode = "k" })
local connectedDoubleWinsPads = setmetatable({}, { __mode = "k" })
local trackedCharacters = {}
local spawnCFrames = {}
local horizontalUnit
local projectedHalfExtent
local getCourseDirection

local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "Remotes"
	remotesFolder.Parent = ReplicatedStorage
end

local winPadFeedbackRemote = remotesFolder:FindFirstChild(WIN_PAD_FEEDBACK_REMOTE_NAME)
if winPadFeedbackRemote and not winPadFeedbackRemote:IsA("RemoteEvent") then
	winPadFeedbackRemote:Destroy()
	winPadFeedbackRemote = nil
end

if not winPadFeedbackRemote then
	winPadFeedbackRemote = Instance.new("RemoteEvent")
	winPadFeedbackRemote.Name = WIN_PAD_FEEDBACK_REMOTE_NAME
	winPadFeedbackRemote.Parent = remotesFolder
end

local redBallContactRemote = remotesFolder:FindFirstChild(RED_BALL_CONTACT_REMOTE_NAME)
if redBallContactRemote and not redBallContactRemote:IsA("RemoteEvent") then
	redBallContactRemote:Destroy()
	redBallContactRemote = nil
end

if not redBallContactRemote then
	redBallContactRemote = Instance.new("RemoteEvent")
	redBallContactRemote.Name = RED_BALL_CONTACT_REMOTE_NAME
	redBallContactRemote.Parent = remotesFolder
end

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

local function isSupportedMapObject(object)
	return object:IsA("BasePart") or object:IsA("Model")
end

local function findAllNamedMapObjects(targetName)
	local normalizedTarget = normalizeName(targetName)
	local matches = {}
	local searchRoot = Workspace
	if Config.IsNewWorld1Map == true then
		searchRoot = Workspace:FindFirstChild(tostring(Config.NewWorld1MapMarkerName or "neworld1"))
		if not searchRoot then
			return matches
		end
	end

	for _, object in ipairs(searchRoot:GetDescendants()) do
		if normalizeName(object.Name) == normalizedTarget and isSupportedMapObject(object) then
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

	return matches
end

                                                                        
                                                                             
                                                                              
local function isSupportedStaticHazardObject(object)
	return object:IsA("BasePart") or object:IsA("Model") or object:IsA("Folder")
end

local function findAllNamedStaticHazardObjects(targetName)
	local normalizedTarget = normalizeName(targetName)
	local matches = {}

	for _, object in ipairs(Workspace:GetDescendants()) do
		if normalizeName(object.Name) == normalizedTarget
			and isSupportedStaticHazardObject(object)
		then
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

	return matches
end

local function findNamedMapObject(targetName)
	local matches = findAllNamedMapObjects(targetName)

	if #matches > 1 then
		warn(
			"[VortexMapGameplay] More than one object matches "
				.. targetName
				.. "; using "
				.. matches[1]:GetFullName()
		)
	end

	return matches[1]
end

local function refreshSafeZoneReferences()
	local missing = {}
	local foundCount = 0

	for zoneIndex = 1, SAFE_ZONE_COUNT do
		local zone = safeZones[zoneIndex]
		if not zone or not zone.Parent then
			zone = findNamedMapObject(safeZoneName(zoneIndex))
			safeZones[zoneIndex] = zone
		end

		if zone then
			foundCount += 1
		else
			table.insert(missing, safeZoneName(zoneIndex))
		end
	end

	allSafeZonesFound = foundCount == SAFE_ZONE_COUNT
	return foundCount, missing
end

local function waitForNamedObjects(names, timeoutSeconds)
	local results = {}
	local deadline = os.clock() + timeoutSeconds

	repeat
		local complete = true

		for _, name in ipairs(names) do
			if not results[name] or not results[name].Parent then
				results[name] = findNamedMapObject(name)
			end

			if not results[name] then
				complete = false
			end
		end

		if complete then
			break
		end

		task.wait(0.25)
	until os.clock() >= deadline

	return results
end

local function getBounds(object)
	if not object then
		return nil, nil
	end

	if object:IsA("BasePart") then
		return object.CFrame, object.Size
	end

	if object:IsA("Model") then
		local success, boundsCFrame, boundsSize = pcall(function()
			return object:GetBoundingBox()
		end)

		if success then
			return boundsCFrame, boundsSize
		end
	end

	return nil, nil
end

local function getObjectPivot(object)
	if not object then
		return nil
	end

	if object:IsA("BasePart") or object:IsA("Model") then
		local success, pivot = pcall(function()
			return object:GetPivot()
		end)

		if success then
			return pivot
		end
	end

	return nil
end

local function moveObjectTo(object, targetCFrame)
	if not object or not object.Parent then
		return false
	end

	local success = pcall(function()
		object:PivotTo(targetCFrame)
	end)

	return success
end

local function getPhysicalParts(object)
	local parts = {}

	if object:IsA("BasePart") then
		table.insert(parts, object)
		return parts
	end

	for _, descendant in ipairs(object:GetDescendants()) do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end

	return parts
end

local function getWorldTopY(part)
	local halfSize = part.Size * 0.5
	local cframe = part.CFrame

	local verticalExtent = math.abs(cframe.RightVector.Y) * halfSize.X
		+ math.abs(cframe.UpVector.Y) * halfSize.Y
		+ math.abs(cframe.LookVector.Y) * halfSize.Z

	return part.Position.Y + verticalExtent
end

local function getProjectedTopArea(part)
	local size = part.Size
	local cframe = part.CFrame

	                                                                         
	                                                                   
	return size.X * size.Z * math.abs(cframe.UpVector.Y)
		+ size.X * size.Y * math.abs(cframe.LookVector.Y)
		+ size.Y * size.Z * math.abs(cframe.RightVector.Y)
end

local function findSafeZoneSurface(zone)
	if not zone then
		return nil
	end

	if zone:IsA("BasePart") then
		return zone
	end

	local zonePivot = getObjectPivot(zone)
	local bestPart = nil
	local bestScore = -math.huge

	for _, part in ipairs(getPhysicalParts(zone)) do
		local score = getProjectedTopArea(part)

		if part.CanCollide then
			score *= 1.2
		end

		if part.Transparency >= 0.95 then
			score *= 0.55
		end

		if zonePivot then
			local offset = part.Position - zonePivot.Position
			local horizontalDistance = Vector3.new(offset.X, 0, offset.Z).Magnitude
			score /= 1 + horizontalDistance * 0.025
		end

		if score > bestScore then
			bestScore = score
			bestPart = part
		end
	end

	return bestPart
end

local function makeHorizontalSurfaceCFrame(surface)
	local topPosition = Vector3.new(
		surface.Position.X,
		getWorldTopY(surface),
		surface.Position.Z
	)
	local look = Vector3.new(surface.CFrame.LookVector.X, 0, surface.CFrame.LookVector.Z)

	if look.Magnitude < 0.05 then
		look = Vector3.new(surface.CFrame.RightVector.Z, 0, -surface.CFrame.RightVector.X)
	end

	if look.Magnitude < 0.05 then
		look = Vector3.new(0, 0, -1)
	end

	return CFrame.lookAt(topPosition, topPosition + look.Unit, Vector3.yAxis)
end

local function makeHorizontalPositionCFrame(position, referenceCFrame)
	local look = referenceCFrame
		and Vector3.new(referenceCFrame.LookVector.X, 0, referenceCFrame.LookVector.Z)
		or Vector3.new(0, 0, -1)

	if look.Magnitude < 0.05 then
		look = Vector3.new(0, 0, -1)
	end

	return CFrame.lookAt(position, position + look.Unit, Vector3.yAxis)
end

local function findSafeZonePlacement(zone)
	if not zone then
		return nil, nil
	end

	local surface = findSafeZoneSurface(zone)

	                                                                           
	                                                                          
	                                                                           
	if surface and (surface.Transparency < 0.95 or surface.Size.Y <= 4) then
		return makeHorizontalSurfaceCFrame(surface), surface
	end

	local zoneCFrame, zoneSize = getBounds(zone)
	if zoneCFrame and zoneSize then
		local excluded = {}
		if zone:IsA("BasePart") then
			table.insert(excluded, zone)
		else
			                                                                       
			                                                         
			for _, part in ipairs(getPhysicalParts(zone)) do
				if part.Transparency >= 0.95 or not part.CanCollide then
					table.insert(excluded, part)
				end
			end
		end
		if surface and not table.find(excluded, surface) then
			table.insert(excluded, surface)
		end
		local padFolder = Workspace:FindFirstChild(PAD_FOLDER_NAME)
		if padFolder then
			table.insert(excluded, padFolder)
		end

		for _, player in ipairs(Players:GetPlayers()) do
			if player.Character then
				table.insert(excluded, player.Character)
			end
		end

		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = excluded
		params.IgnoreWater = false

		local castAbove = math.max(12, zoneSize.Y * 0.5 + 6)
		local castDepth = math.max(150, zoneSize.Y + 100)
		local result = Workspace:Raycast(
			zoneCFrame.Position + Vector3.new(0, castAbove, 0),
			Vector3.new(0, -castDepth, 0),
			params
		)

		if result then
			return makeHorizontalPositionCFrame(result.Position, zoneCFrame), result.Instance
		end

		                                                                      
		                                                                   
		local halfSize = zoneSize * 0.5
		local verticalExtent = math.abs(zoneCFrame.RightVector.Y) * halfSize.X
			+ math.abs(zoneCFrame.UpVector.Y) * halfSize.Y
			+ math.abs(zoneCFrame.LookVector.Y) * halfSize.Z
		local fallbackPosition = Vector3.new(
			zoneCFrame.Position.X,
			zoneCFrame.Position.Y - verticalExtent,
			zoneCFrame.Position.Z
		)

		return makeHorizontalPositionCFrame(fallbackPosition, zoneCFrame), surface
	end

	if surface then
		return makeHorizontalSurfaceCFrame(surface), surface
	end

	return nil, nil
end

local function isPointInSafeZone(point, zone)
	local zoneCFrame, zoneSize = getBounds(zone)
	if not zoneCFrame or not zoneSize then
		return false
	end

	local localPoint = zoneCFrame:PointToObjectSpace(point)
	local halfSize = zoneSize * 0.5

	return math.abs(localPoint.X) <= halfSize.X + SAFE_ZONE_SIDE_PADDING
		and math.abs(localPoint.Z) <= halfSize.Z + SAFE_ZONE_SIDE_PADDING
		and localPoint.Y >= -halfSize.Y - SAFE_ZONE_BELOW_PADDING
		and localPoint.Y <= halfSize.Y + SAFE_ZONE_HEIGHT_ABOVE
end

local function isCharacterGeometricallySafe(character)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end

	for zoneIndex = 1, SAFE_ZONE_COUNT do
		local zone = safeZones[zoneIndex]
		if zone and zone.Parent and isPointInSafeZone(root.Position, zone) then
			return true
		end
	end

	return false
end

local function setCharacterProtection(player, character, protected)
	if not character or not character.Parent then
		return
	end

	character:SetAttribute(SAFE_ZONE_ATTRIBUTE, protected)
	if player then
		player:SetAttribute(SAFE_ZONE_ATTRIBUTE, protected)
	end

	local forceField = character:FindFirstChild(SAFE_ZONE_FORCE_FIELD)
	local humanoid = character:FindFirstChildOfClass("Humanoid")

	if protected then
		if forceField and not forceField:IsA("ForceField") then
			forceField:Destroy()
			forceField = nil
		end

		if not forceField then
			forceField = Instance.new("ForceField")
			forceField.Name = SAFE_ZONE_FORCE_FIELD
			forceField.Visible = false
			forceField.Parent = character
		end

		if humanoid and humanoid.Health > 0 and humanoid.Health < humanoid.MaxHealth then
			humanoid.Health = humanoid.MaxHealth
		end
	elseif forceField then
		forceField:Destroy()
	end
end

local function characterIsProtected(character)
	if not character then
		return false
	end

	if character:GetAttribute(SAFE_ZONE_ATTRIBUTE) == true then
		return true
	end

	return isCharacterGeometricallySafe(character)
end

local function getCharacterFromHit(hit)
	if not hit or not hit:IsA("BasePart") then
		return nil, nil, nil
	end

	local current = hit.Parent

	while current and current ~= Workspace do
		if current:IsA("Model") then
			local humanoid = current:FindFirstChildOfClass("Humanoid")
			if humanoid then
				return current, humanoid, Players:GetPlayerFromCharacter(current)
			end
		end

		current = current.Parent
	end

	return nil, nil, nil
end

local function killFromHazard(hit)
	local character, humanoid, player = getCharacterFromHit(hit)
	if not character or not humanoid or humanoid.Health <= 0 then
		return false
	end
	if player and player:GetAttribute("StageTeleportInvulnerable") == true then
		return false
	end

	                                                                      
	                                       
	if not allSafeZonesFound then
		return false
	end

	if characterIsProtected(character) then
		setCharacterProtection(player, character, true)
		if humanoid.Health > 0 and humanoid.Health < humanoid.MaxHealth then
			humanoid.Health = humanoid.MaxHealth
		end
		return false
	end

	humanoid.Health = 0
	return true
end

local function setupCharacterTracking(player, character)
	trackedCharacters[player] = character
	character:SetAttribute(SAFE_ZONE_ATTRIBUTE, false)
	player:SetAttribute(SAFE_ZONE_ATTRIBUTE, false)

	local root = character:WaitForChild("HumanoidRootPart", 10)
	if root and root:IsA("BasePart") then
		                                                                        
		                                                                     
		                                                   
		RunService.Heartbeat:Wait()
		if character.Parent and root.Parent then
			spawnCFrames[player] = root.CFrame
		end
	end

	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid or not humanoid:IsA("Humanoid") then
		return
	end

	humanoid.HealthChanged:Connect(function(health)
		if character.Parent
			and character:GetAttribute(SAFE_ZONE_ATTRIBUTE) == true
			and health < humanoid.MaxHealth
		then
			humanoid.Health = humanoid.MaxHealth
		end
	end)
end

local function setupPlayerTracking(player)
	if player.Character then
		task.spawn(setupCharacterTracking, player, player.Character)
	end

	player.CharacterAdded:Connect(function(character)
		setupCharacterTracking(player, character)
	end)

	player.CharacterRemoving:Connect(function(character)
		if trackedCharacters[player] == character then
			trackedCharacters[player] = nil
		end
	end)
end

local function startSafeZoneTracker()
	task.spawn(function()
		while true do
			for _, player in ipairs(Players:GetPlayers()) do
				local character = player.Character
				if character and character.Parent then
					local protected = isCharacterGeometricallySafe(character)
					setCharacterProtection(player, character, protected)
				end
			end

			task.wait(SAFE_ZONE_CHECK_INTERVAL)
		end
	end)
end

local function formatNumber(value)
	local text = tostring(math.floor(value))

	while true do
		local changed
		text, changed = text:gsub("^(-?%d+)(%d%d%d)", "%1,%2")

		if changed == 0 then
			return text
		end
	end
end

local function getOrPrepareEditablePadFolder()
	local folder = Workspace:FindFirstChild(PAD_FOLDER_NAME)
	local preserveExistingPositions = folder
		and folder:IsA("Folder")
		and folder:GetAttribute(PAD_MANUAL_FOLDER_ATTRIBUTE) == true
		and (Config.IsNewWorld1Map ~= true
			or folder:GetAttribute("NewWorld1LayoutVersion") == "V306KBE")

	if folder and not folder:IsA("Folder") then
		folder:Destroy()
		folder = nil
	end

	if not folder then
		folder = Instance.new("Folder")
		folder.Name = PAD_FOLDER_NAME
		folder.Parent = Workspace
	end
	folder.Archivable = true

	                                                                        
	                                                                            
	                                                                             
	                                                    
	if not preserveExistingPositions then
		for _, child in ipairs(folder:GetChildren()) do
			child:Destroy()
		end
	end

	folder:SetAttribute(PAD_MANUAL_FOLDER_ATTRIBUTE, true)
	folder:SetAttribute("ManualColoredPadCFramesAreAuthoritative", true)
	if Config.IsNewWorld1Map == true then
		                                                                        
		                                                                           
		folder:SetAttribute("NewWorld1LayoutVersion", "V306KBE")
	end
	folder:SetAttribute("FallbackLayoutVersion", "V235")
	folder:SetAttribute("V237CopyReady", true)
	folder:SetAttribute(
		"EditModeInstructions",
		"Copy this folder during Play, stop, paste into Workspace, then move the colored pads."
	)

	local instruction = folder:FindFirstChild(PAD_INSTRUCTION_VALUE_NAME)
	if instruction and not instruction:IsA("StringValue") then
		instruction:Destroy()
		instruction = nil
	end
	if not instruction then
		instruction = Instance.new("StringValue")
		instruction.Name = PAD_INSTRUCTION_VALUE_NAME
		instruction.Parent = folder
	end
	instruction.Value = "Copy folder in Play > Stop > Paste into Workspace > move colored pads"

	return folder, preserveExistingPositions
end

local function makePadSize()
	return Vector3.new(PAD_MAX_SIZE, PAD_HEIGHT, PAD_MAX_SIZE)
end

local function getPlacementHalfExtent(zone, surface, axis)
	local available = nil
	local zoneCFrame, zoneSize = getBounds(zone)

	if zoneCFrame and zoneSize then
		available = projectedHalfExtent(zoneCFrame, zoneSize, axis)
	end

	if surface and surface:IsA("BasePart") then
		local surfaceExtent = projectedHalfExtent(surface.CFrame, surface.Size, axis)
		available = available and math.min(available, surfaceExtent) or surfaceExtent
	end

	return math.max(0, available or 0)
end

local function makePadPairCFrames(zoneIndex, zone, surface, surfaceCFrame, padSize)
	local courseDirection
	if IS_WORLD2 then
		local currentPivot = getObjectPivot(zone)
		local adjacentZone = zoneIndex < SAFE_ZONE_COUNT
			and safeZones[zoneIndex + 1]
			or safeZones[zoneIndex - 1]
		local adjacentPivot = getObjectPivot(adjacentZone)
		if currentPivot and adjacentPivot then
			courseDirection = zoneIndex < SAFE_ZONE_COUNT
				and horizontalUnit(adjacentPivot.Position - currentPivot.Position)
				or horizontalUnit(currentPivot.Position - adjacentPivot.Position)
		end
	end
	courseDirection = courseDirection
		or getCourseDirection()
		or horizontalUnit(surfaceCFrame.LookVector)
		or Vector3.xAxis
	                                                                         
	                                                                            
	                                    
	local rightDirection = IS_WORLD2
		and horizontalUnit(courseDirection:Cross(Vector3.yAxis))
		or horizontalUnit(surfaceCFrame.RightVector)

	if not rightDirection then
		rightDirection = courseDirection:Cross(Vector3.yAxis)
		if rightDirection.Magnitude < 0.05 then
			rightDirection = Vector3.xAxis
		else
			rightDirection = rightDirection.Unit
		end
	end

	local rightExtent = getPlacementHalfExtent(zone, surface, rightDirection)
	local maximumSafeRightOffset = math.max(
		0,
		rightExtent - padSize.X * 0.5 - PAD_EDGE_MARGIN
	)
	                                                                          
	                                                                        
	local baseRightOffset = IS_WORLD2
		and maximumSafeRightOffset
		or math.min(PAD_RIGHT_OFFSET, maximumSafeRightOffset)
	local additionalRightShift = PAD_ADDITIONAL_RIGHT_SHIFTS[zoneIndex] or 0
	local rightOffset = baseRightOffset + additionalRightShift
	local wantedPairOffset = (padSize.Z + PAD_PAIR_GAP) * 0.5
	                                                                         
	                                                                         
	                                                           
	local pairOffset = wantedPairOffset
	local verticalOffset = PAD_BASE_HEIGHT + padSize.Y * 0.5 + 0.03
	local pairCenter = surfaceCFrame.Position
		+ rightDirection * rightOffset
		+ Vector3.yAxis * verticalOffset
	local goldPosition = pairCenter - courseDirection * pairOffset
	local purplePosition = pairCenter + courseDirection * pairOffset

	return CFrame.lookAt(goldPosition, goldPosition + courseDirection, Vector3.yAxis),
		CFrame.lookAt(purplePosition, purplePosition + courseDirection, Vector3.yAxis),
		rightOffset,
		pairOffset,
		baseRightOffset,
		additionalRightShift,
		rightDirection
end

local REQUESTED_WIN_PAD_RIGHT_SHIFTS = IS_WORLD2 and {} or {
	[7] = 24,
	[8] = 24,
}

local function getLegacyAppliedWinPadShift(pad, zoneIndex)
	local applied = 0

	if zoneIndex == 7 then
		if pad:GetAttribute("V306EYStage7WinPadRightShiftApplied") == true then
			applied = tonumber(pad:GetAttribute("V306EYStage7WinPadRightShiftStuds")) or 17
		end
	elseif zoneIndex == 8 then
		if pad:GetAttribute("V306EXStage8WinPadRightShiftApplied") == true then
			applied = 17
		end
		if pad:GetAttribute("V306EYStage8WinPadRightShiftApplied") == true then
			applied = math.max(applied, tonumber(pad:GetAttribute("V306EYStage8WinPadRightShiftStuds")) or 17)
		end
	end

	return applied
end

local function applyRequestedWinPadShift(pad, zoneIndex, rightDirection, reusedManualCFrame)
	local requestedShift = REQUESTED_WIN_PAD_RIGHT_SHIFTS[zoneIndex]
	if not requestedShift then
		return
	end

	                                                                        
	                                                                           
	                                                                        
	                                                       
	local markerName = string.format("V306EZStage%dWinPadRightShiftApplied", zoneIndex)
	local legacyApplied = getLegacyAppliedWinPadShift(pad, zoneIndex)
	local delta = math.max(0, requestedShift - legacyApplied)
	if reusedManualCFrame and pad:GetAttribute(markerName) ~= true and delta > 0 then
		pad.CFrame = pad.CFrame + rightDirection * delta
	end

	pad:SetAttribute(markerName, true)
	pad:SetAttribute(
		string.format("V306EZStage%dWinPadRightShiftStuds", zoneIndex),
		requestedShift
	)
end

local function createPadBase(folder, pad)
	local oldBase = folder:FindFirstChild(pad.Name .. "_BlackBase")
	if oldBase then
		oldBase:Destroy()
	end

	local base = Instance.new("Part")
	base.Name = pad.Name .. "_BlackBase"
	base.Anchored = true
	base.CanCollide = false
	base.CanTouch = false
	base.CanQuery = false
	base.CastShadow = false
	base.Material = Enum.Material.SmoothPlastic
	base.Color = PAD_BASE_COLOR
	base.TopSurface = Enum.SurfaceType.Studs
	base.BottomSurface = Enum.SurfaceType.Smooth
	local baseHorizontalPadding = pad:GetAttribute("WinStagePad") == true and 1.25 or 0.75
	base.Size = Vector3.new(
		pad.Size.X + baseHorizontalPadding,
		PAD_BASE_HEIGHT,
		pad.Size.Z + baseHorizontalPadding
	)
	base.CFrame = pad.CFrame
		* CFrame.new(0, -((pad.Size.Y + PAD_BASE_HEIGHT) * 0.5) + 0.02, 0)
	base:SetAttribute("FollowsEditablePad", pad.Name)
	base.Parent = folder

	pad:GetPropertyChangedSignal("CFrame"):Connect(function()
		if pad.Parent and base.Parent then
			base.CFrame = pad.CFrame
				* CFrame.new(0, -((pad.Size.Y + PAD_BASE_HEIGHT) * 0.5) + 0.02, 0)
		end
	end)

	return base
end

local function createPadLight(pad, lightColor)
	local oldLight = pad:FindFirstChild("PadLight")
	if oldLight then
		oldLight:Destroy()
	end

	local light = Instance.new("PointLight")
	light.Name = "PadLight"
	light.Color = lightColor or PAD_LIGHT_COLOR
	light.Brightness = 0.8
	light.Range = 3
	light.Shadows = false
	light.Parent = pad
end

local function createPadLabel(pad, text)
	local oldBillboard = pad:FindFirstChild("WinRewardBillboard")
	if oldBillboard then
		oldBillboard:Destroy()
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "WinRewardBillboard"
	billboard.Adornee = pad
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.Size = IS_WORLD2 and UDim2.fromOffset(170, 39) or UDim2.fromOffset(118, 27)
	billboard.StudsOffsetWorldSpace = IS_WORLD2
		and Vector3.new(0, 2.25, 0)
		or Vector3.new(0, 1.75, 0)
	billboard.MaxDistance = 117
	billboard.Parent = pad

	local label = Instance.new("TextLabel")
	label.Name = "RewardText"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.Text = tostring(text)
	if tostring(text) == "2x Wins" then
		label.TextColor3 = Color3.fromRGB(255, 70, 255)
	else
		label.TextColor3 = PAD_TEXT_COLOR
	end
	label.TextStrokeColor3 = PAD_TEXT_STROKE
	label.TextStrokeTransparency = 0.35
	label.TextScaled = false
	label.TextSize = IS_WORLD2 and 26 or 19
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = billboard
end

local function awardWins(player, reward)
	local addWins = _G.SpeedsterAddWins

	if type(addWins) == "function" then
		addWins(player, reward)
		return true
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	local wins = leaderstats and leaderstats:FindFirstChild("Wins")

	if wins and wins:IsA("IntValue") then
		wins.Value += reward
		return true
	end

	return false
end

local function playPadTouchSound(player)
	winPadFeedbackRemote:FireClient(player, PAD_TOUCH_SOUND_ID)
end

local function zeroCharacterVelocity(character)
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.AssemblyLinearVelocity = Vector3.zero
			descendant.AssemblyAngularVelocity = Vector3.zero
		end
	end
end

local function getNormalSpawnCFrame(player)
	local stored = spawnCFrames[player]
	if stored then
		return stored
	end

	local respawnLocation = player.RespawnLocation
	if respawnLocation and respawnLocation:IsA("SpawnLocation") then
		return respawnLocation.CFrame * CFrame.new(0, 3.5, 0)
	end

	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if descendant:IsA("SpawnLocation") and descendant.Enabled then
			return descendant.CFrame * CFrame.new(0, 3.5, 0)
		end
	end

	return nil
end

local function teleportToStart(player, character, humanoid)
	local targetCFrame = getNormalSpawnCFrame(player)
	if not targetCFrame or not character or not character.Parent then
		warn("[VortexMapGameplay] No normal Roblox spawn position was available; teleport skipped")
		return false
	end

	setCharacterProtection(player, character, true)
	if humanoid and humanoid.Health > 0 then
		humanoid.Health = humanoid.MaxHealth
	end

	zeroCharacterVelocity(character)
	character:PivotTo(targetCFrame)
	zeroCharacterVelocity(character)
	MovementGuard.Rebase(player, 1)
	return true
end

local function connectWinPad(pad, reward, zoneIndex)
	if connectedWinPads[pad] then
		return
	end
	connectedWinPads[pad] = true

	pad.Touched:Connect(function(hit)
		local character, humanoid, player = getCharacterFromHit(hit)
		if not character or not humanoid or not player or humanoid.Health <= 0 then
			return
		end

		if player:GetAttribute("DataLoaded") ~= true then
			return
		end

		local now = os.clock()
		local teleportGraceUntil = tonumber(player:GetAttribute("StageTeleportArrivalGraceUntil")) or 0
		if now < teleportGraceUntil then
			return
		end
		if now - (lastPadClaimAt[player] or -math.huge) < PAD_CLAIM_COOLDOWN then
			return
		end

		lastPadClaimAt[player] = now

		if not MovementGuard.CanClaim(player, zoneIndex, zoneIndex == SAFE_ZONE_COUNT) then
			return
		end

		if not awardWins(player, reward) then
			lastPadClaimAt[player] = nil
			warn("[VortexMapGameplay] Could not award Wins to " .. player.Name)
			return
		end

		if zoneIndex == SAFE_ZONE_COUNT then
			MovementGuard.RecordFinalClaim(player)
		end

		player:SetAttribute("LastClaimedWinPad", pad.Name)
		player:SetAttribute("LastWinPadReward", reward)
		player:SetAttribute("LastCompletedSafeZone", zoneIndex)
		playPadTouchSound(player)
		teleportToStart(player, character, humanoid)

		                                                                      
		                                                                        
		                              
		local savePlayer = _G.SpeedsterSavePlayer
		if type(savePlayer) == "function" then
			task.defer(savePlayer, player, "win_pad_reward_safezone_" .. tostring(zoneIndex))
		end

		print(
			"[VortexMapGameplay] "
				.. player.Name
				.. " earned "
				.. tostring(reward)
				.. " Wins from SafeZone"
				.. tostring(zoneIndex)
		)
	end)
end

local function ownsDoubleWinsPadPass(player, forceRefresh)
	if player:GetAttribute("DoubleWinsPadUnlocked") == true or (tonumber(player:GetAttribute("PermanentWinsMultiplier")) or 1) >= 2 then
		doubleWinsPassOwned[player] = true
		return true
	end
	if not forceRefresh and doubleWinsPassOwned[player] ~= nil then
		return doubleWinsPassOwned[player] == true
	end

	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, DOUBLE_WINS_PAD_GAMEPASS_ID)
	end)
	if not ok then
		warn("[VortexMapGameplay] Could not check x2 Wins pad Game Pass for " .. player.Name .. ": " .. tostring(owns))
		return nil
	end

	doubleWinsPassOwned[player] = owns == true
	if owns == true then
		player:SetAttribute("DoubleWinsPadUnlocked", true)
		local current = tonumber(player:GetAttribute("PermanentWinsMultiplier")) or 1
		player:SetAttribute("PermanentWinsMultiplier", math.max(2, current))
	end
	return owns == true
end

local function promptDoubleWinsPadPass(player)
	local now = os.clock()
	if now - (lastDoubleWinsPromptAt[player] or -math.huge) < DOUBLE_WINS_PROMPT_COOLDOWN then
		return
	end
	lastDoubleWinsPromptAt[player] = now

	local ok, err = pcall(function()
		MarketplaceService:PromptProductPurchase(player, DOUBLE_WINS_PAD_PRODUCT_ID)
	end)
	if not ok then
		warn("[VortexMapGameplay] Could not prompt x2 Wins DevProduct: " .. tostring(err))
	end
end

local function connectDoubleWinsPad(pad, reward, zoneIndex)
	if connectedDoubleWinsPads[pad] then
		return
	end
	connectedDoubleWinsPads[pad] = true

	pad.Touched:Connect(function(hit)
		local character, humanoid, player = getCharacterFromHit(hit)
		if not character or not humanoid or not player or humanoid.Health <= 0 then
			return
		end
		if player:GetAttribute("DataLoaded") ~= true then
			return
		end

		local now = os.clock()
		local teleportGraceUntil = tonumber(player:GetAttribute("StageTeleportArrivalGraceUntil")) or 0
		if now < teleportGraceUntil then
			return
		end

		local owns = ownsDoubleWinsPadPass(player, false)
		if owns ~= true then
			promptDoubleWinsPadPass(player)
			return
		end

		if now - (lastPadClaimAt[player] or -math.huge) < PAD_CLAIM_COOLDOWN then
			return
		end
		lastPadClaimAt[player] = now

		if not MovementGuard.CanClaim(player, zoneIndex, zoneIndex == SAFE_ZONE_COUNT) then
			return
		end

		local doubledReward = reward * DOUBLE_WINS_PAD_MULTIPLIER
		if not awardWins(player, doubledReward) then
			lastPadClaimAt[player] = nil
			warn("[VortexMapGameplay] Could not award x2 Wins to " .. player.Name)
			return
		end

		if zoneIndex == SAFE_ZONE_COUNT then
			MovementGuard.RecordFinalClaim(player)
		end

		player:SetAttribute("LastClaimedWinPad", pad.Name)
		player:SetAttribute("LastWinPadReward", doubledReward)
		player:SetAttribute("LastCompletedSafeZone", zoneIndex)
		playPadTouchSound(player)
		teleportToStart(player, character, humanoid)

		local savePlayer = _G.SpeedsterSavePlayer
		if type(savePlayer) == "function" then
			task.defer(savePlayer, player, "double_wins_pad_reward_safezone_" .. tostring(zoneIndex))
		end

		print(
			"[VortexMapGameplay] "
				.. player.Name
				.. " earned "
				.. tostring(doubledReward)
				.. " Wins from x2 pad at SafeZone"
				.. tostring(zoneIndex)
		)
	end)
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, purchaseSuccess)
	if tonumber(gamePassId) ~= DOUBLE_WINS_PAD_GAMEPASS_ID then
		return
	end
	if purchaseSuccess then
		doubleWinsPassOwned[player] = true
		player:SetAttribute("DoubleWinsPadUnlocked", true)
		task.defer(function()
			ownsDoubleWinsPadPass(player, true)
		end)
	end
end)

-- Developer-product ownership is granted only by ProcessReceipt.


Players.PlayerAdded:Connect(function(player)
	task.defer(function()
		ownsDoubleWinsPadPass(player, true)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	doubleWinsPassOwned[player] = nil
	lastDoubleWinsPromptAt[player] = nil
end)

local function getOrCreateEditablePadPart(folder, name, color, fallbackCFrame, canTouch)
	local pad = folder:FindFirstChild(name)
	local reusedManualCFrame = pad and pad:IsA("BasePart")

	if pad and not pad:IsA("BasePart") then
		pad:Destroy()
		pad = nil
	end

	if not pad then
		pad = Instance.new("Part")
		pad.Name = name
		pad.CFrame = fallbackCFrame
		pad.Parent = folder
	end

	pad.Anchored = true
	pad.Archivable = true
	pad.CanCollide = true
	pad.CanTouch = canTouch
	pad.CanQuery = true
	pad.CastShadow = false
	pad.Material = Enum.Material.Neon
	pad.Color = color
	pad.Transparency = 0
	pad.Size = makePadSize()
	pad.TopSurface = Enum.SurfaceType.Smooth
	pad.BottomSurface = Enum.SurfaceType.Smooth
	pad:SetAttribute("ManualCFramePreserved", reusedManualCFrame == true)
	return pad, reusedManualCFrame == true
end

local function createWinPads()
	local folder, preservedExistingFolder = getOrPrepareEditablePadFolder()
	local createdGoldCount = 0
	local createdFutureCount = 0

	for zoneIndex = FIRST_PAD_SAFE_ZONE, SAFE_ZONE_COUNT do
		local zone = safeZones[zoneIndex]
		local reward = SAFE_ZONE_REWARDS[zoneIndex]
		local surfaceCFrame, surface = findSafeZonePlacement(zone)

		if reward and surfaceCFrame then
			local padSize = makePadSize()
			local goldCFrame, purpleCFrame, rightOffset, pairOffset,
				baseRightOffset, additionalRightShift, rightDirection = makePadPairCFrames(
					zoneIndex,
					zone,
					surface,
					surfaceCFrame,
					padSize
				)

			local goldPad, reusedGoldCFrame = getOrCreateEditablePadPart(
				folder,
				string.format("WinPad%02d_%dWins", zoneIndex, reward),
				PAD_COLOR,
				goldCFrame,
				true
			)
			applyRequestedWinPadShift(
				goldPad,
				zoneIndex,
				rightDirection,
				reusedGoldCFrame
			)
			goldPad:SetAttribute("WinReward", reward)
			goldPad:SetAttribute("SafeZoneIndex", zoneIndex)
			goldPad:SetAttribute("Repeatable", true)
			goldPad:SetAttribute("TeleportsToNormalSpawn", true)
			goldPad:SetAttribute("RightSideOffsetStuds", rightOffset)
			goldPad:SetAttribute("V232BaseRightOffsetStuds", baseRightOffset)
			goldPad:SetAttribute("AdditionalRightShiftStuds", additionalRightShift)
			goldPad:SetAttribute("RightDirectionWorld", rightDirection)
			goldPad:SetAttribute("RightAxisMode", "SafeZoneSurfaceRightVectorV234")
			goldPad:SetAttribute("SpawnPerspectiveRightShiftStuds", nil)
			goldPad:SetAttribute("SpawnPerspectiveRightDirectionWorld", nil)
			goldPad:SetAttribute("SpawnPerspectiveRightAxisMode", nil)
			goldPad:SetAttribute("SpawnPerspectiveRightSource", nil)
			goldPad:SetAttribute("PairOffsetStuds", -pairOffset)
			goldPad:SetAttribute("V235FallbackCFrame", goldCFrame)
			goldPad:SetAttribute("FallbackPlacementVersion", "V235")
			goldPad:SetAttribute("ManualPositionAuthoritative", true)
			goldPad:SetAttribute("ReusedManualCFrame", reusedGoldCFrame)
			goldPad:SetAttribute("PlacementMode", "ManualWorkspaceCFrameOrV235Fallback")
			goldPad:SetAttribute("PlacementVersion", "V237Editable")
			goldPad:SetAttribute("PlacementGuaranteed", true)

			createPadBase(folder, goldPad)
			createPadLight(goldPad, PAD_LIGHT_COLOR)
			createPadLabel(goldPad, string.format("%s Wins", formatNumber(reward)))
			connectWinPad(goldPad, reward, zoneIndex)
			createdGoldCount += 1

			local purplePad, reusedPurpleCFrame = getOrCreateEditablePadPart(
				folder,
				string.format("Future2xWinsPad%02d", zoneIndex),
				PAD_DOUBLE_WINS_COLOR,
				purpleCFrame,
				true
			)
			applyRequestedWinPadShift(
				purplePad,
				zoneIndex,
				rightDirection,
				reusedPurpleCFrame
			)
			purplePad:SetAttribute("SafeZoneIndex", zoneIndex)
			purplePad:SetAttribute("FutureRobuxProduct", true)
			purplePad:SetAttribute("PurchasableNow", true)
			purplePad:SetAttribute("ProductId", DOUBLE_WINS_PAD_PRODUCT_ID)
			purplePad:SetAttribute("GamePassId", DOUBLE_WINS_PAD_GAMEPASS_ID)
			purplePad:SetAttribute("DoubleWinsMultiplier", DOUBLE_WINS_PAD_MULTIPLIER)
			purplePad:SetAttribute("RightSideOffsetStuds", rightOffset)
			purplePad:SetAttribute("V232BaseRightOffsetStuds", baseRightOffset)
			purplePad:SetAttribute("AdditionalRightShiftStuds", additionalRightShift)
			purplePad:SetAttribute("RightDirectionWorld", rightDirection)
			purplePad:SetAttribute("RightAxisMode", "SafeZoneSurfaceRightVectorV234")
			purplePad:SetAttribute("SpawnPerspectiveRightShiftStuds", nil)
			purplePad:SetAttribute("SpawnPerspectiveRightDirectionWorld", nil)
			purplePad:SetAttribute("SpawnPerspectiveRightAxisMode", nil)
			purplePad:SetAttribute("SpawnPerspectiveRightSource", nil)
			purplePad:SetAttribute("PairOffsetStuds", pairOffset)
			purplePad:SetAttribute("V235FallbackCFrame", purpleCFrame)
			purplePad:SetAttribute("FallbackPlacementVersion", "V235")
			purplePad:SetAttribute("ManualPositionAuthoritative", true)
			purplePad:SetAttribute("ReusedManualCFrame", reusedPurpleCFrame)
			purplePad:SetAttribute("PlacementMode", "ManualWorkspaceCFrameOrV235Fallback")
			purplePad:SetAttribute("PlacementVersion", "V237Editable")
			purplePad:SetAttribute("PlacementGuaranteed", true)

			createPadBase(folder, purplePad)
			createPadLight(purplePad, PAD_DOUBLE_WINS_LIGHT_COLOR)
			createPadLabel(purplePad, "2x Wins")
			connectDoubleWinsPad(purplePad, reward, zoneIndex)
			createdFutureCount += 1
		elseif reward and not surfaceCFrame then
			warn(
				"[VortexMapGameplay] Could not find a BasePart surface inside SafeZone"
					.. tostring(zoneIndex)
			)
		end
	end

	folder:SetAttribute("LastBuildPreservedExistingCFrames", preservedExistingFolder == true)
	folder:SetAttribute("ConfiguredGoldPads", createdGoldCount)
	folder:SetAttribute("ConfiguredFuturePads", createdFutureCount)

	return createdGoldCount, createdFutureCount
end

local function findExactMarkerPart(markerName)
	                                                                           
	                                                                        
	local direct = Workspace:FindFirstChild(markerName)
	if direct and direct:IsA("BasePart") then
		return direct
	end

	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if descendant.Name == markerName and descendant:IsA("BasePart") then
			return descendant
		end
	end

	return nil
end

local function getOrCreateWinStageMarkerPadFolder()
	local folder = Workspace:FindFirstChild(WIN_STAGE_MARKER_PAD_FOLDER_NAME)
	if folder and not folder:IsA("Folder") then
		folder:Destroy()
		folder = nil
	end
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = WIN_STAGE_MARKER_PAD_FOLDER_NAME
		folder.Parent = Workspace
	end
	return folder
end

local function cleanupOldWinStagePads(keepFolder)
	local names = {
		[WIN_STAGE_NORMAL_PAD_NAME] = true,
		[WIN_STAGE_DOUBLE_PAD_NAME] = true,
		[WIN_STAGE_NORMAL_PAD_NAME .. "_BlackBase"] = true,
		[WIN_STAGE_DOUBLE_PAD_NAME .. "_BlackBase"] = true,
	}

	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if names[descendant.Name]
			and descendant.Parent ~= keepFolder
			and not descendant:IsDescendantOf(keepFolder)
		then
			descendant:Destroy()
		end
	end
end

local function styleWinStageMarkerPad(pad, color)
	pad.Anchored = true
	pad.Archivable = true
	pad.CanCollide = true
	pad.CanTouch = true
	pad.CanQuery = true
	pad.CastShadow = false
	pad.Material = Enum.Material.Neon
	pad.Color = color
	pad.Transparency = 0
	pad.TopSurface = Enum.SurfaceType.Smooth
	pad.BottomSurface = Enum.SurfaceType.Smooth
end

local function cleanupOldGeneratedWinStagePads()
	local folder = Workspace:FindFirstChild(WIN_STAGE_MARKER_PAD_FOLDER_NAME)
	if folder then
		folder:Destroy()
	end

	local oldNames = {
		[WIN_STAGE_NORMAL_PAD_NAME] = true,
		[WIN_STAGE_DOUBLE_PAD_NAME] = true,
		[WIN_STAGE_NORMAL_PAD_NAME .. "_BlackBase"] = true,
		[WIN_STAGE_DOUBLE_PAD_NAME .. "_BlackBase"] = true,
	}

	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if oldNames[descendant.Name]
			and descendant.Name ~= WIN_STAGE_NORMAL_MARKER_NAME
			and descendant.Name ~= WIN_STAGE_DOUBLE_MARKER_NAME
		then
			descendant:Destroy()
		end
	end
end

local function createWinStagePads()
	                                                                                          
	                                                                                
	local normalPad = findExactMarkerPart(WIN_STAGE_NORMAL_MARKER_NAME)
	local doublePad = findExactMarkerPart(WIN_STAGE_DOUBLE_MARKER_NAME)
	if not normalPad or not doublePad then
		return false,
			"missing marker part(s): WINHERE=" .. tostring(normalPad ~= nil)
				.. " X2HERE=" .. tostring(doublePad ~= nil)
	end

	cleanupOldGeneratedWinStagePads()

	styleWinStageMarkerPad(normalPad, PAD_COLOR)
	normalPad:SetAttribute("WinStagePad", true)
	normalPad:SetAttribute("WinReward", WIN_STAGE_BASE_REWARD)
	normalPad:SetAttribute("SafeZoneIndex", SAFE_ZONE_COUNT)
	normalPad:SetAttribute("Repeatable", true)
	normalPad:SetAttribute("TeleportsToNormalSpawn", true)
	normalPad:SetAttribute("PlacementMarker", WIN_STAGE_NORMAL_MARKER_NAME)
	normalPad:SetAttribute("ManualPositionAuthoritative", true)
	normalPad:SetAttribute("PlacementVersion", "V306FHMarkerIsPad")
	createPadBase(normalPad.Parent, normalPad)
	createPadLight(normalPad, PAD_LIGHT_COLOR)
	createPadLabel(normalPad, string.format("%s Wins", formatNumber(WIN_STAGE_BASE_REWARD)))
	connectWinPad(normalPad, WIN_STAGE_BASE_REWARD, SAFE_ZONE_COUNT)

	styleWinStageMarkerPad(doublePad, PAD_DOUBLE_WINS_COLOR)
	doublePad:SetAttribute("WinStagePad", true)
	doublePad:SetAttribute("SafeZoneIndex", SAFE_ZONE_COUNT)
	doublePad:SetAttribute("FutureRobuxProduct", true)
	doublePad:SetAttribute("PurchasableNow", true)
	doublePad:SetAttribute("ProductId", DOUBLE_WINS_PAD_PRODUCT_ID)
	doublePad:SetAttribute("GamePassId", DOUBLE_WINS_PAD_GAMEPASS_ID)
	doublePad:SetAttribute("DoubleWinsMultiplier", DOUBLE_WINS_PAD_MULTIPLIER)
	doublePad:SetAttribute("BaseWinReward", WIN_STAGE_BASE_REWARD)
	doublePad:SetAttribute("DoubledWinReward", WIN_STAGE_BASE_REWARD * DOUBLE_WINS_PAD_MULTIPLIER)
	doublePad:SetAttribute("PlacementMarker", WIN_STAGE_DOUBLE_MARKER_NAME)
	doublePad:SetAttribute("ManualPositionAuthoritative", true)
	doublePad:SetAttribute("PlacementVersion", "V306FHMarkerIsPad")
	createPadBase(doublePad.Parent, doublePad)
	createPadLight(doublePad, PAD_DOUBLE_WINS_LIGHT_COLOR)
	createPadLabel(doublePad, "2x Wins")
	connectDoubleWinsPad(doublePad, WIN_STAGE_BASE_REWARD, SAFE_ZONE_COUNT)

	return true, "WINHERE/X2HERE are the pads"
end

local function winStagePadsHealthy()
	local normalPad = findExactMarkerPart(WIN_STAGE_NORMAL_MARKER_NAME)
	local doublePad = findExactMarkerPart(WIN_STAGE_DOUBLE_MARKER_NAME)
	if not normalPad or not doublePad then
		return false
	end

	return normalPad:GetAttribute("WinStagePad") == true
		and doublePad:GetAttribute("WinStagePad") == true
		and tonumber(normalPad:GetAttribute("WinReward")) == WIN_STAGE_BASE_REWARD
		and tonumber(doublePad:GetAttribute("DoubledWinReward"))
			== WIN_STAGE_BASE_REWARD * DOUBLE_WINS_PAD_MULTIPLIER
		and normalPad:GetAttribute("PlacementVersion") == "V306FHMarkerIsPad"
		and doublePad:GetAttribute("PlacementVersion") == "V306FHMarkerIsPad"
		and normalPad.Transparency < 0.95
		and doublePad.Transparency < 0.95
		and normalPad.CanTouch
		and doublePad.CanTouch
		and normalPad:FindFirstChild("WinRewardBillboard") ~= nil
		and doublePad:FindFirstChild("WinRewardBillboard") ~= nil
end

local function countRuntimePads()
	local folder = Workspace:FindFirstChild(PAD_FOLDER_NAME)
	if not folder or not folder:IsA("Folder") then
		return 0, 0, false
	end

	local goldCount = 0
	local futureCount = 0
	local healthy = folder:GetAttribute(PAD_MANUAL_FOLDER_ATTRIBUTE) == true
		and folder:GetAttribute("ManualColoredPadCFramesAreAuthoritative") == true

	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("BasePart") then
			if child:GetAttribute("WinStagePad") == true then
				continue
			end
			if child:GetAttribute("WinReward") ~= nil then
				goldCount += 1
			elseif child:GetAttribute("FutureRobuxProduct") == true then
				futureCount += 1
			else
				continue
			end

			local zoneIndex = tonumber(child:GetAttribute("SafeZoneIndex"))
			local expectedAdditionalShift = zoneIndex
				and PAD_ADDITIONAL_RIGHT_SHIFTS[zoneIndex]
			local additionalRightShift = tonumber(
				child:GetAttribute("AdditionalRightShiftStuds")
			)
			if child:GetAttribute("PlacementVersion") ~= "V237Editable"
				or child:GetAttribute("PlacementGuaranteed") ~= true
				or child:GetAttribute("RightAxisMode") ~= "SafeZoneSurfaceRightVectorV234"
				or child:GetAttribute("PlacementMode")
					~= "ManualWorkspaceCFrameOrV235Fallback"
				or child:GetAttribute("FallbackPlacementVersion") ~= "V235"
				or child:GetAttribute("ManualPositionAuthoritative") ~= true
				or child.Transparency >= 0.95
				or not child.Anchored
				or not child:FindFirstChild("WinRewardBillboard")
				or not folder:FindFirstChild(child.Name .. "_BlackBase")
				or expectedAdditionalShift == nil
				or additionalRightShift == nil
				or math.abs(additionalRightShift - expectedAdditionalShift) > 0.05
			then
				healthy = false
			end
		end
	end

	return goldCount, futureCount, healthy
end

local function startWinPadRepairWatchdog()
	task.spawn(function()
		while true do
			task.wait(PAD_REPAIR_INTERVAL)

			refreshSafeZoneReferences()
			local expectedNow = 0
			for zoneIndex = FIRST_PAD_SAFE_ZONE, SAFE_ZONE_COUNT do
				if safeZones[zoneIndex] and safeZones[zoneIndex].Parent then
					expectedNow += 1
				end
			end

			local goldCount, futureCount, healthy = countRuntimePads()
			if goldCount ~= expectedNow or futureCount ~= expectedNow or not healthy then
				local ok, repairedGold, repairedFuture = pcall(createWinPads)
				if ok then
					warn(
						"[VortexMapGameplay] V237 repaired editable pads without moving CFrames | Wins="
							.. tostring(repairedGold)
							.. "/"
							.. tostring(expectedNow)
							.. " | Future2x="
							.. tostring(repairedFuture)
							.. "/"
							.. tostring(expectedNow)
					)
				else
					warn("[VortexMapGameplay] Pad repair failed: " .. tostring(repairedGold))
				end
			end

			if not IS_WORLD2 and not winStagePadsHealthy() then
				local ok, created, detail = pcall(createWinStagePads)
				if not ok then
					warn("[VortexMapGameplay] WinStage pad repair failed: " .. tostring(created))
				elseif created ~= true and not string.find(tostring(detail), "missing marker part", 1, true) then
					warn("[VortexMapGameplay] WinStage pads unavailable: " .. tostring(detail))
				end
			end
		end
	end)
end

local connectedLethalParts = setmetatable({}, { __mode = "k" })

local function connectLethalParts(parts, canDamage)
	local newlyConnected = 0

	for _, part in ipairs(parts) do
		part.CanTouch = true

		if not connectedLethalParts[part] then
			connectedLethalParts[part] = true
			newlyConnected += 1

			                                                              
			                                                                      
			                                                                     
			part:GetPropertyChangedSignal("CanTouch"):Connect(function()
				if part.Parent and not part.CanTouch then
					part.CanTouch = true
				end
			end)

			part.Touched:Connect(function(hit)
				if canDamage and not canDamage() then
					return
				end

				killFromHazard(hit)
			end)
		end
	end

	return newlyConnected
end

local function configureStaticLethalHazard(hazardObject, hazardName)
	if not hazardObject then
		return 0
	end

	local parts = getPhysicalParts(hazardObject)
	if #parts == 0 then
		warn(
			"[VortexMapGameplay] "
				.. tostring(hazardName)
				.. " has no BaseParts to make lethal"
		)
		return 0
	end

	for _, part in ipairs(parts) do
		part:SetAttribute("VortexStaticLethalHazard", true)
		part:SetAttribute("VortexHazardName", hazardName)
	end

	local newlyConnected = connectLethalParts(parts)
	hazardObject:SetAttribute("VortexLethalConfigured", true)
	hazardObject:SetAttribute("VortexLethalPartCount", #parts)
	return #parts, newlyConnected
end

local function getStaticHazardAncestor(object)
	local current = object

	while current and current ~= Workspace do
		if isSupportedStaticHazardObject(current)
			and STATIC_LETHAL_HAZARD_NAME_SET[normalizeName(current.Name)]
		then
			return current
		end

		current = current.Parent
	end

	return nil
end

local function getBallDespawnFolder()
	local folder = ServerStorage:FindFirstChild(BALL_DESPAWN_FOLDER_NAME)

	if folder and folder:IsA("Folder") then
		return folder
	end

	local newFolder = Instance.new("Folder")
	newFolder.Name = folder
		and (BALL_DESPAWN_FOLDER_NAME .. "_Runtime")
		or BALL_DESPAWN_FOLDER_NAME
	newFolder.Parent = ServerStorage
	return newFolder
end

local function stopPartMotion(parts)
	for _, part in ipairs(parts) do
		part.AssemblyLinearVelocity = Vector3.zero
		part.AssemblyAngularVelocity = Vector3.zero
	end
end

local function setPartsAnchored(parts, anchored)
	for _, part in ipairs(parts) do
		part.Anchored = anchored
		if not anchored then
			pcall(function()
				part:SetNetworkOwner(nil)
			end)
		end
	end
end

local function captureBallPresentation(ballObject, parts)
	local states = {}

	for _, part in ipairs(parts) do
		states[part] = {
			Kind = "BasePart",
			Transparency = part.Transparency,
			CanCollide = part.CanCollide,
			CanTouch = part.CanTouch,
			CanQuery = part.CanQuery,
		}
	end

	for _, descendant in ipairs(ballObject:GetDescendants()) do
		if descendant:IsA("Decal") or descendant:IsA("Texture") then
			states[descendant] = {
				Kind = "Transparency",
				Transparency = descendant.Transparency,
			}
		elseif descendant:IsA("ParticleEmitter")
			or descendant:IsA("Trail")
			or descendant:IsA("Beam")
			or descendant:IsA("Fire")
			or descendant:IsA("Smoke")
			or descendant:IsA("Sparkles")
			or descendant:IsA("PointLight")
			or descendant:IsA("SpotLight")
			or descendant:IsA("SurfaceLight")
			or descendant:IsA("BillboardGui")
			or descendant:IsA("SurfaceGui")
			or descendant:IsA("Highlight")
		then
			states[descendant] = {
				Kind = "Enabled",
				Enabled = descendant.Enabled,
			}
		end
	end

	return states
end

local function setBallDespawned(presentationStates, despawned)
	for instance, state in pairs(presentationStates) do
		if instance.Parent then
			if state.Kind == "BasePart" then
				instance.Transparency = despawned and 1 or state.Transparency
				instance.CanCollide = despawned and false or state.CanCollide
				instance.CanTouch = despawned and false or state.CanTouch
				instance.CanQuery = despawned and false or state.CanQuery
			elseif state.Kind == "Transparency" then
				instance.Transparency = despawned and 1 or state.Transparency
			elseif state.Kind == "Enabled" then
				instance.Enabled = despawned and false or state.Enabled
			end
		end
	end
end

local function chooseAssemblyRoot(object, parts)
	if object:IsA("BasePart") then
		return object
	end

	if object:IsA("Model") and object.PrimaryPart then
		return object.PrimaryPart
	end

	return parts[1]
end

local function removeGeneratedBallDamageHitboxes(ballObject)
	for _, descendant in ipairs(ballObject:GetDescendants()) do
		if descendant:IsA("BasePart")
			and (descendant.Name == BALL_DAMAGE_HITBOX_NAME
				or descendant:GetAttribute("VortexGeneratedBallDamageHitbox") == true)
		then
			descendant:Destroy()
		end
	end
end

local function chooseBallDamageSourcePart(parts, preferredRoot)
	local bestPart = nil
	local bestScore = -math.huge

	for _, part in ipairs(parts) do
		local size = part.Size
		local smallestDimension = math.min(size.X, size.Y, size.Z)
		local largestDimension = math.max(size.X, size.Y, size.Z)

		if smallestDimension > 0 and largestDimension > 0 then
			local roundness = smallestDimension / largestDimension
			local volume = size.X * size.Y * size.Z
			local score = volume * roundness ^ 4

			if part == preferredRoot then
				score *= 1.05
			end

			if score > bestScore then
				bestScore = score
				bestPart = part
			end
		end
	end

	return bestPart or preferredRoot or parts[1]
end

local function createBallDamageHitbox(ballObject, root, parts)
	local sourcePart = chooseBallDamageSourcePart(parts, root)
	if not sourcePart then
		return nil
	end

	local sourceSize = sourcePart.Size
	local sourceDiameter = math.min(sourceSize.X, sourceSize.Y, sourceSize.Z)
	local hitboxDiameter = math.max(0.5, sourceDiameter * BALL_DAMAGE_HITBOX_SCALE)

	local hitbox = Instance.new("Part")
	hitbox.Name = BALL_DAMAGE_HITBOX_NAME
	hitbox.Shape = Enum.PartType.Ball
	hitbox.Size = Vector3.new(hitboxDiameter, hitboxDiameter, hitboxDiameter)
	hitbox.CFrame = sourcePart.CFrame
	hitbox.Transparency = 1
	hitbox.CastShadow = false
	hitbox.Anchored = false
	hitbox.Massless = true
	hitbox.CanCollide = false
	hitbox.CanTouch = false
	hitbox.CanQuery = true
	hitbox.CollisionGroup = sourcePart.CollisionGroup
	hitbox:SetAttribute("VortexGeneratedBallDamageHitbox", true)
	hitbox:SetAttribute("HitboxScale", BALL_DAMAGE_HITBOX_SCALE)
	hitbox:SetAttribute("ValidationMode", "ClientCurrentFullBodySweptV236")
	hitbox:SetAttribute("SourcePartName", sourcePart.Name)
	hitbox.Parent = root

	local weld = Instance.new("WeldConstraint")
	weld.Name = "DamageHitboxWeld"
	weld.Part0 = root
	weld.Part1 = hitbox
	weld.Parent = hitbox

	ballObject:SetAttribute("DamageHitboxName", BALL_DAMAGE_HITBOX_NAME)
	ballObject:SetAttribute("DamageHitboxScale", BALL_DAMAGE_HITBOX_SCALE)
	ballObject:SetAttribute("DamageValidationMode", "ClientCurrentFullBodySweptV236")
	ballObject:SetAttribute("DamageValidationMinDelaySeconds", 0)
	ballObject:SetAttribute("DamageValidationMaxDelaySeconds", 0)

	return hitbox
end

horizontalUnit = function(vector)
	local horizontal = Vector3.new(vector.X, 0, vector.Z)

	if horizontal.Magnitude < 0.05 then
		return nil
	end

	return horizontal.Unit
end

projectedHalfExtent = function(cframe, size, direction)
	local halfSize = size * 0.5

	return math.abs(cframe.RightVector:Dot(direction)) * halfSize.X
		+ math.abs(cframe.UpVector:Dot(direction)) * halfSize.Y
		+ math.abs(cframe.LookVector:Dot(direction)) * halfSize.Z
end

local function getBallStopProjection(ballObject, direction)
	local targetZone = safeZones[FIRST_PAD_SAFE_ZONE]
	local zoneCFrame, zoneSize = getBounds(targetZone)
	local ballCFrame, ballSize = getBounds(ballObject)

	if not zoneCFrame or not zoneSize or not ballCFrame or not ballSize then
		return nil
	end

	local ballStartProjection = ballCFrame.Position:Dot(direction)
	local zoneCenterProjection = zoneCFrame.Position:Dot(direction)

	                                                                         
	                                                                   
	if zoneCenterProjection <= ballStartProjection then
		return nil
	end

	local zoneApproachEdge = zoneCenterProjection
		- projectedHalfExtent(zoneCFrame, zoneSize, direction)
	local ballRadiusAlongCourse = projectedHalfExtent(ballCFrame, ballSize, direction)

	return zoneApproachEdge
		- ballRadiusAlongCourse
		- BALL_SAFE_ZONE_GAP
		+ BALL_EXTRA_TRAVEL_STUDS
end

getCourseDirection = function()
	local firstPivot = getObjectPivot(safeZones[1])
	local lastPivot = getObjectPivot(safeZones[BALL_ROUTE_LAST_SAFE_ZONE])

	if firstPivot and lastPivot then
		return horizontalUnit(lastPivot.Position - firstPivot.Position)
	end

	return nil
end

local function getConfiguredBallDirection(ballObject)
	local configured = ballObject:GetAttribute("RollDirection")

	if typeof(configured) == "Vector3" then
		return horizontalUnit(configured)
	end

	if type(configured) == "string" then
		local directions = {
			x = Vector3.xAxis,
			positivex = Vector3.xAxis,
			minusx = -Vector3.xAxis,
			negativex = -Vector3.xAxis,
			z = Vector3.zAxis,
			positivez = Vector3.zAxis,
			minusz = -Vector3.zAxis,
			negativez = -Vector3.zAxis,
		}

		return directions[normalizeName(configured)]
	end

	return nil
end

local function makeBallRaycastParams(ballParts)
	local excluded = table.clone(ballParts)
	local padFolder = Workspace:FindFirstChild(PAD_FOLDER_NAME)

	if padFolder then
		table.insert(excluded, padFolder)
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = excluded
	params.IgnoreWater = false

	return params
end

local function raycastFloorAt(position, castHeight, castDepth, params)
	local origin = position + Vector3.new(0, castHeight, 0)
	return Workspace:Raycast(origin, Vector3.new(0, -castDepth, 0), params)
end

local function findBallLaunchDirection(ballObject, root, ballParts)
	local configuredDirection = getConfiguredBallDirection(ballObject)
	if configuredDirection then
		return configuredDirection
	end

	local courseDirection = getCourseDirection()
	local params = makeBallRaycastParams(ballParts)
	local castHeight = math.max(40, root.Size.Y * 2)
	local castDepth = math.max(180, root.Size.Y * 10)
	local startResult = raycastFloorAt(root.Position, castHeight, castDepth, params)
	local startHeight = startResult and startResult.Position.Y
		or root.Position.Y - root.Size.Y * 0.5
	local radius = math.max(root.Size.X, root.Size.Z) * 0.5
	local nearDistance = radius + 6
	local farDistance = nearDistance + math.max(22, radius * 1.8)
	local bestDirection = nil
	local bestScore = -math.huge

	for directionIndex = 0, BALL_PROBE_DIRECTIONS - 1 do
		local angle = directionIndex * math.pi * 2 / BALL_PROBE_DIRECTIONS
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local nearResult = raycastFloorAt(
			root.Position + direction * nearDistance,
			castHeight,
			castDepth,
			params
		)
		local farResult = raycastFloorAt(
			root.Position + direction * farDistance,
			castHeight,
			castDepth,
			params
		)

		if nearResult and farResult then
			local nearDrop = startHeight - nearResult.Position.Y
			local farDrop = startHeight - farResult.Position.Y

			                                                                     
			                                      
			if nearDrop >= -root.Size.Y * 0.4
				and nearDrop <= root.Size.Y * 1.5
				and farDrop >= -root.Size.Y * 0.6
				and farDrop <= root.Size.Y * 2
			then
				local score = nearDrop * 2 + farDrop

				local gravity = Vector3.new(0, -1, 0)
				local downhill = gravity
					- nearResult.Normal * gravity:Dot(nearResult.Normal)

				if downhill.Magnitude > 0.05 then
					score += math.max(0, downhill.Unit:Dot(direction)) * 12
				end

				if courseDirection then
					score += courseDirection:Dot(direction) * 5
				end

				if score > bestScore then
					bestScore = score
					bestDirection = direction
				end
			end
		end
	end

	return bestDirection
		or courseDirection
		or horizontalUnit(root.CFrame.LookVector)
		or Vector3.xAxis
end

local function launchRedBall(ballObject, root, ballParts)
	local direction = findBallLaunchDirection(ballObject, root, ballParts)
	local radius = math.max(1, math.max(root.Size.X, root.Size.Z) * 0.5)
	local rollAxis = Vector3.yAxis:Cross(direction)
	local angularSpeed = BALL_INITIAL_SPEED / radius

	ballObject:SetAttribute("ResolvedRollDirection", direction)
	root.AssemblyLinearVelocity = direction * BALL_INITIAL_SPEED + Vector3.new(0, -1, 0)
	root.AssemblyAngularVelocity = rollAxis * angularSpeed

	                                                                          
	                                                                         
	task.spawn(function()
		local assistEnds = os.clock() + BALL_LAUNCH_ASSIST_TIME

		while root.Parent and ballObject.Parent and os.clock() < assistEnds do
			local velocity = root.AssemblyLinearVelocity
			local forwardSpeed = Vector3.new(velocity.X, 0, velocity.Z):Dot(direction)

			if forwardSpeed < BALL_INITIAL_SPEED * 0.85 then
				root.AssemblyLinearVelocity = direction * BALL_INITIAL_SPEED
					+ Vector3.new(0, math.min(velocity.Y, -1), 0)
			end

			root.AssemblyAngularVelocity = rollAxis * angularSpeed
			RunService.Heartbeat:Wait()
		end
	end)

	return direction
end

local function configureRedBall(ballObject)
	removeGeneratedBallDamageHitboxes(ballObject)

	local parts = getPhysicalParts(ballObject)
	local root = chooseAssemblyRoot(ballObject, parts)
	local startCFrame = getObjectPivot(ballObject)
	local originalParent = ballObject.Parent

	if #parts == 0 or not root or not startCFrame then
		warn("[VortexMapGameplay] RedBall must be a BasePart or a Model containing BaseParts")
		return false
	end

	local ballDamageEnabled = false
	local ballDamageCycle = 0
	local lastClientContactAt = setmetatable({}, { __mode = "k" })
	local despawnFolder = getBallDespawnFolder()
	local damageHitbox = createBallDamageHitbox(ballObject, root, parts)

	if not damageHitbox then
		warn("[VortexMapGameplay] RedBall damage hitbox could not be created")
		return false
	end

	local function setBallDamageEnabled(enabled)
		ballDamageCycle += 1
		ballDamageEnabled = enabled == true
		                                                                      
		                                                                          
		                                                                     
		damageHitbox.CanTouch = false
		damageHitbox.CanQuery = true
		damageHitbox:SetAttribute("DamageEnabled", ballDamageEnabled)
		damageHitbox:SetAttribute("DamageCycle", ballDamageCycle)
		ballObject:SetAttribute("DamageEnabled", ballDamageEnabled)
		ballObject:SetAttribute("DamageCycle", ballDamageCycle)
	end

	redBallContactRemote.OnServerEvent:Connect(function(
		player,
		reportedHitbox,
		reportedCycle
	)
		if reportedHitbox ~= damageHitbox
			or type(reportedCycle) ~= "number"
			or reportedCycle ~= ballDamageCycle
			or not ballDamageEnabled
			or not ballObject:IsDescendantOf(Workspace)
			or damageHitbox:GetAttribute("DamageEnabled") ~= true
		then
			return
		end

		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local characterRoot = character and character:FindFirstChild("HumanoidRootPart")

		if not character or not humanoid or humanoid.Health <= 0
			or not characterRoot or not characterRoot:IsA("BasePart")
		then
			return
		end

		                                                                           
		                                                                        
		if characterIsProtected(character) then
			setCharacterProtection(player, character, true)
			return
		end

		local now = os.clock()
		if now - (lastClientContactAt[player] or -math.huge) < 0.05 then
			return
		end

		lastClientContactAt[player] = now
		killFromHazard(characterRoot)
	end)
	local presentationStates = captureBallPresentation(ballObject, parts)
	local skipNextSpawnPause = false
	ballObject:SetAttribute("VortexBallConfigured", true)
	ballObject:SetAttribute("VortexBallConfiguredVersion", "V236")

	task.spawn(function()
		while ballObject.Parent and root.Parent do
			setBallDamageEnabled(false)
			setPartsAnchored(parts, true)
			stopPartMotion(parts)
			moveObjectTo(ballObject, startCFrame)

			local respawnParent = originalParent
			if not respawnParent or not respawnParent.Parent then
				respawnParent = Workspace
			end
			if ballObject.Parent ~= respawnParent then
				ballObject.Parent = respawnParent
			end

			setBallDespawned(presentationStates, false)
			ballObject:SetAttribute("StoppedAfterExtendedSafeZone2Travel", false)
			ballObject:SetAttribute("ExtraTravelStuds", BALL_EXTRA_TRAVEL_STUDS)
			ballObject:SetAttribute("EndpointHoldSeconds", 0)
			ballObject:SetAttribute("EndpointDespawnSeconds", BALL_DESPAWN_TIME)
			ballObject:SetAttribute("IsDespawned", false)
			stopPartMotion(parts)

			if skipNextSpawnPause then
				skipNextSpawnPause = false
			else
				task.wait(BALL_RESET_PAUSE)
			end

			setPartsAnchored(parts, false)
			stopPartMotion(parts)
			RunService.Heartbeat:Wait()
			setBallDamageEnabled(true)
			local rollDirection = launchRedBall(ballObject, root, parts)
			local stopProjection = getBallStopProjection(ballObject, rollDirection)

			local cycleStarted = os.clock()
			local stillStarted = nil
			local movedFarEnough = false

			while ballObject.Parent and root.Parent do
				RunService.Heartbeat:Wait()

				local pivot = getObjectPivot(ballObject)
				if not pivot then
					break
				end

				local boundsCFrame = select(1, getBounds(ballObject))
				local currentProjection = boundsCFrame
					and boundsCFrame.Position:Dot(rollDirection)

				if stopProjection
					and currentProjection
					and currentProjection >= stopProjection
				then
					setBallDamageEnabled(false)
					setPartsAnchored(parts, true)
					stopPartMotion(parts)

					                                                                     
					                                                           
					                                                            
					                                                    
					local correction = stopProjection - currentProjection
					setBallDespawned(presentationStates, true)
					moveObjectTo(ballObject, pivot + rollDirection * correction)
					stopPartMotion(parts)
					ballObject:SetAttribute("StoppedAfterExtendedSafeZone2Travel", true)
					ballObject:SetAttribute("IsDespawned", true)
					skipNextSpawnPause = true
					ballObject.Parent = despawnFolder
					task.wait(BALL_DESPAWN_TIME)
					break
				end

				local elapsed = os.clock() - cycleStarted
				local distance = (pivot.Position - startCFrame.Position).Magnitude
				local speed = root.AssemblyLinearVelocity.Magnitude
				movedFarEnough = movedFarEnough or distance >= 5

				if movedFarEnough and speed <= BALL_STILL_SPEED then
					stillStarted = stillStarted or os.clock()
				else
					stillStarted = nil
				end

				local fellNearDestroyHeight = pivot.Position.Y <= Workspace.FallenPartsDestroyHeight + 50
				local stoppedAfterRolling = elapsed >= BALL_MIN_ROLL_TIME
					and stillStarted
					and os.clock() - stillStarted >= BALL_STILL_TIME

				if elapsed >= BALL_MAX_ROLL_TIME
					or distance >= BALL_MAX_TRAVEL
					or fellNearDestroyHeight
					or stoppedAfterRolling
				then
					break
				end
			end
		end
	end)

	return true
end

local function partIsUnderNamedHandle(part, hammerObject)
	local current = part

	while current and current ~= hammerObject do
		if normalizeName(current.Name):find("handle", 1, true) then
			return true
		end

		current = current.Parent
	end

	return false
end

local function findInferredHandlePart(parts)
	if #parts < 2 then
		return nil
	end

	local bestPart = nil
	local bestScore = 0

	for _, part in ipairs(parts) do
		local size = part.Size
		local cframe = part.CFrame
		local verticalSpan = math.abs(cframe.RightVector.Y) * size.X
			+ math.abs(cframe.UpVector.Y) * size.Y
			+ math.abs(cframe.LookVector.Y) * size.Z
		local horizontalXSpan = math.abs(cframe.RightVector.X) * size.X
			+ math.abs(cframe.UpVector.X) * size.Y
			+ math.abs(cframe.LookVector.X) * size.Z
		local horizontalZSpan = math.abs(cframe.RightVector.Z) * size.X
			+ math.abs(cframe.UpVector.Z) * size.Y
			+ math.abs(cframe.LookVector.Z) * size.Z
		local horizontalSpan = math.max(0.1, horizontalXSpan, horizontalZSpan)
		local slenderness = verticalSpan / horizontalSpan
		local score = verticalSpan * slenderness

		if verticalSpan >= 8 and slenderness >= 1.8 and score > bestScore then
			bestScore = score
			bestPart = part
		end
	end

	return bestPart
end

local function splitHammerParts(hammerObject)
	local movingParts = {}
	local stationaryParts = {}

	if hammerObject:IsA("BasePart") then
		table.insert(movingParts, hammerObject)
		return movingParts, stationaryParts
	end

	local allParts = getPhysicalParts(hammerObject)

	for _, part in ipairs(allParts) do
		if partIsUnderNamedHandle(part, hammerObject) then
			table.insert(stationaryParts, part)
		else
			table.insert(movingParts, part)
		end
	end

	                                                                          
	                                                                         
	                                              
	if #stationaryParts == 0 then
		local inferredHandle = findInferredHandlePart(allParts)

		if inferredHandle then
			movingParts = {}

			for _, part in ipairs(allParts) do
				if part == inferredHandle then
					table.insert(stationaryParts, part)
				else
					table.insert(movingParts, part)
				end
			end
		end
	end

	return movingParts, stationaryParts
end

local function averagePartPosition(parts)
	local total = Vector3.zero

	for _, part in ipairs(parts) do
		total += part.Position
	end

	return total / math.max(1, #parts)
end

local function findSwingPivotAttachment(hammerObject)
	for _, descendant in ipairs(hammerObject:GetDescendants()) do
		if descendant:IsA("Attachment") and normalizeName(descendant.Name) == "swingpivot" then
			return descendant.WorldCFrame
		end
	end

	return nil
end

local function closestPointPivot(handle, movingCenter)
	local localPoint = handle.CFrame:PointToObjectSpace(movingCenter)
	local half = handle.Size * 0.5
	local clamped = Vector3.new(
		math.clamp(localPoint.X, -half.X, half.X),
		math.clamp(localPoint.Y, -half.Y, half.Y),
		math.clamp(localPoint.Z, -half.Z, half.Z)
	)
	local worldPoint = handle.CFrame:PointToWorldSpace(clamped)

	return CFrame.fromMatrix(
		worldPoint,
		handle.CFrame.XVector,
		handle.CFrame.YVector,
		handle.CFrame.ZVector
	)
end

local function getHammerPivot(hammerObject, movingParts, stationaryParts)
	local attachmentPivot = findSwingPivotAttachment(hammerObject)
	if attachmentPivot then
		return attachmentPivot
	end

	local largestHandlePart = stationaryParts[1]

	for _, part in ipairs(stationaryParts) do
		if not largestHandlePart
			or part.Size.X * part.Size.Y * part.Size.Z
				> largestHandlePart.Size.X * largestHandlePart.Size.Y * largestHandlePart.Size.Z
		then
			largestHandlePart = part
		end
	end

	if largestHandlePart then
		return closestPointPivot(largestHandlePart, averagePartPosition(movingParts))
	end

	                                                                           
	                                                                           
	                              
	local boundsCFrame, boundsSize = getBounds(hammerObject)
	if boundsCFrame and boundsSize then
		local topY = boundsCFrame.Position.Y
			+ projectedHalfExtent(boundsCFrame, boundsSize, Vector3.yAxis)
		return CFrame.new(boundsCFrame.Position.X, topY, boundsCFrame.Position.Z)
	end

	return getObjectPivot(hammerObject) or movingParts[1].CFrame
end

local function disableCrossHandleJoints(hammerObject, movingSet)
	for _, descendant in ipairs(hammerObject:GetDescendants()) do
		if descendant:IsA("JointInstance") or descendant:IsA("WeldConstraint") then
			local part0
			local part1

			pcall(function()
				part0 = descendant.Part0
				part1 = descendant.Part1
			end)

			if part0 and part1 and movingSet[part0] ~= movingSet[part1] then
				pcall(function()
					descendant.Enabled = false
				end)
			end
		end
	end
end

local function getHammerWorldAxis(axisName, pivot)
	if axisName == "X" then
		return pivot.RightVector.Unit
	elseif axisName == "Y" then
		return Vector3.yAxis
	elseif axisName == "Z" then
		return pivot.LookVector.Unit
	end

	                                                                          
	                                                          
	return getCourseDirection() or pivot.RightVector.Unit
end

local function createHammerSound(soundParent)
	local oldSound = soundParent:FindFirstChild("VortexHammerWhoosh")
	if oldSound then
		oldSound:Destroy()
	end

	local sound = Instance.new("Sound")
	sound.Name = "VortexHammerWhoosh"
	sound.SoundId = HAMMER_WHOOSH_SOUND_ID
	sound.Volume = HAMMER_WHOOSH_VOLUME
	sound.PlaybackSpeed = 1
	sound.Looped = false
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 8
	sound.RollOffMaxDistance = 85
	sound.Parent = soundParent

	return sound
end

local function configureHammer(hammerObject, hammerIndex)
	local movingParts, stationaryParts = splitHammerParts(hammerObject)
	if #movingParts == 0 then
		warn(
			"[VortexMapGameplay] Hammer"
				.. tostring(hammerIndex)
				.. " has no movable BaseParts outside a child named Handle"
		)
		return false
	end

	local movingSet = {}
	for _, part in ipairs(movingParts) do
		movingSet[part] = true
		part.Anchored = true
		part.CanTouch = true
	end

	for _, part in ipairs(stationaryParts) do
		part.Anchored = true
	end

	disableCrossHandleJoints(hammerObject, movingSet)
	connectLethalParts(movingParts)

	local pivot = getHammerPivot(hammerObject, movingParts, stationaryParts)
	local originalCFrames = {}

	for _, part in ipairs(movingParts) do
		originalCFrames[part] = part.CFrame
	end

	local driver = Instance.new("NumberValue")
	driver.Name = "Hammer" .. tostring(hammerIndex) .. "SwingDriver"
	driver.Value = 0
	driver.Parent = script

	local axisName = tostring(hammerObject:GetAttribute("SwingAxis") or "COURSE"):upper()
	if axisName ~= "X" and axisName ~= "Y" and axisName ~= "Z"
		and axisName ~= "COURSE"
	then
		axisName = "COURSE"
	end

	local worldAxis = getHammerWorldAxis(axisName, pivot)
	local pivotPosition = pivot.Position

	driver:GetPropertyChangedSignal("Value"):Connect(function()
		local radians = math.rad(driver.Value)
		local rotation = CFrame.new(pivotPosition)
			* CFrame.fromAxisAngle(worldAxis, radians)
			* CFrame.new(-pivotPosition)

		for part, originalCFrame in pairs(originalCFrames) do
			if part.Parent then
				part.CFrame = rotation * originalCFrame
			end
		end
	end)

	local swingAngle = tonumber(hammerObject:GetAttribute("SwingAngleDegrees"))
		or HAMMER_DEFAULT_ANGLE
	local halfSwingTime = tonumber(hammerObject:GetAttribute("HalfSwingTime"))
		or HAMMER_DEFAULT_HALF_SWING_TIME

	swingAngle = math.clamp(math.abs(swingAngle), 5, 120)
	halfSwingTime = math.clamp(
		halfSwingTime / HAMMER_SWING_SPEED_MULTIPLIER,
		0.25,
		6
	)

	local sound = createHammerSound(movingParts[1])
	local phaseOffset = HAMMER_PHASE_OFFSETS[hammerIndex]
		or ((hammerIndex - 1) * math.pi)
	driver.Value = math.sin(phaseOffset) * swingAngle

	hammerObject:SetAttribute("VortexHammerConfigured", true)
	hammerObject:SetAttribute("StationaryHandleParts", #stationaryParts)
	hammerObject:SetAttribute("ResolvedSwingAxis", axisName)
	hammerObject:SetAttribute("ResolvedSwingPivot", pivotPosition)
	hammerObject:SetAttribute("SmoothSineSwing", true)
	hammerObject:SetAttribute("PhaseOffsetDegrees", math.deg(phaseOffset))
	hammerObject:SetAttribute("ResolvedHalfSwingTime", halfSwingTime)
	hammerObject:SetAttribute("SwingSpeedMultiplier", HAMMER_SWING_SPEED_MULTIPLIER)
	hammerObject:SetAttribute("WhooshVolume", HAMMER_WHOOSH_VOLUME)

	task.spawn(function()
		local startedAt = os.clock()
		local phaseSpeed = math.pi / halfSwingTime
		local lastCenterCrossing = math.floor(phaseOffset / math.pi)

		while hammerObject.Parent do
			local phase = phaseOffset + (os.clock() - startedAt) * phaseSpeed
			driver.Value = math.sin(phase) * swingAngle

			local centerCrossing = math.floor(phase / math.pi)
			if centerCrossing ~= lastCenterCrossing then
				lastCenterCrossing = centerCrossing
				sound:Stop()
				sound.TimePosition = 0
				sound:Play()
			end

			RunService.Heartbeat:Wait()
		end

		driver:Destroy()
	end)

	return true
end

                                                                           
                                                                           
                                                              
local _, initialMissingSafeZones = refreshSafeZoneReferences()

for _, name in ipairs(initialMissingSafeZones) do
	warn("[VortexMapGameplay] Missing required Workspace object: " .. name)
end

if not allSafeZonesFound then
	warn(
		"[VortexMapGameplay] Lethal damage is disabled until all configured SafeZone objects exist"
	)
end

local createdWinPads = 0
local createdFuturePads = 0
                                                                           
                                                                            
                                                                               
if Config.IsNewWorld1Map ~= true then
	local initialPadsOk, initialGoldOrError, initialFuture = pcall(createWinPads)
	if initialPadsOk then
		createdWinPads = initialGoldOrError
		createdFuturePads = initialFuture
	else
		warn("[VortexMapGameplay] Initial pad creation failed: " .. tostring(initialGoldOrError))
	end

	if not IS_WORLD2 then
		local initialWinStageOk, initialWinStageCreated, initialWinStageDetail = pcall(createWinStagePads)
		if not initialWinStageOk then
			warn("[VortexMapGameplay] Initial WinStage pad creation failed: " .. tostring(initialWinStageCreated))
		elseif initialWinStageCreated ~= true and not string.find(tostring(initialWinStageDetail), "missing marker part", 1, true) then
			warn("[VortexMapGameplay] Initial WinStage pads unavailable: " .. tostring(initialWinStageDetail))
		end
	end
	startWinPadRepairWatchdog()
end

for _, player in ipairs(Players:GetPlayers()) do
	setupPlayerTracking(player)
end

Players.PlayerAdded:Connect(setupPlayerTracking)
Players.PlayerRemoving:Connect(function(player)
	lastPadClaimAt[player] = nil
	trackedCharacters[player] = nil
	spawnCFrames[player] = nil
end)

startSafeZoneTracker()

                                                                              
                                                                              
                                                         
if IS_WORLD2 then
	print(
		"[VortexMapGameplay] V306HA World 2 active | SafeZones="
			.. tostring(select(1, refreshSafeZoneReferences()))
			.. "/"
			.. tostring(SAFE_ZONE_COUNT)
			.. " | WinPads="
			.. tostring(createdWinPads)
			.. "/"
			.. tostring(EXPECTED_PAD_COUNT)
			.. " | x2Pads="
			.. tostring(createdFuturePads)
			.. "/"
			.. tostring(EXPECTED_PAD_COUNT)
			.. " | World 1 hazards skipped"
	)
	return
end

                                                                           
                                                                           
                                                                              
                                            
if Config.IsNewWorld1Map == true then
	print(
		"[VortexMapGameplay] V306KBS new World 1 active | Stage 1-11 SafeZones preserved | authored X/Win/Skip marker pads owned separately | legacy generated pads + RedBall/Hammer/Water controller skipped"
	)
	return
end

                                                                                                            
                                                                                
                                                                                               
                                                                                
local configuredStaticHazards = 0
local configuredStaticHazardParts = 0

Workspace.DescendantAdded:Connect(function(object)
	task.defer(function()
		if not object.Parent then
			return
		end

		local hazardObject = getStaticHazardAncestor(object)
		if hazardObject then
			configureStaticLethalHazard(hazardObject, hazardObject.Name)
		end
	end)
end)

for _, name in ipairs(STATIC_LETHAL_HAZARD_NAMES) do
	local hazardObjects = findAllNamedStaticHazardObjects(name)
	if #hazardObjects == 0 then
		warn("[VortexMapGameplay] Missing required Workspace object: " .. name)
	end

	for _, hazardObject in ipairs(hazardObjects) do
		local partCount, newlyConnected = configureStaticLethalHazard(hazardObject, name)
		if partCount > 0 then
			configuredStaticHazards += 1
			configuredStaticHazardParts += newlyConnected
		end
	end
end

                                                                              
                                                                             
                                                              

local requiredNames = { BALL_NAME }

for hammerIndex = 1, HAMMER_COUNT do
	table.insert(requiredNames, "Hammer" .. tostring(hammerIndex))
end

local namedObjects = waitForNamedObjects(requiredNames, SAFE_ZONE_SCAN_SECONDS)

local configuredBall = false
local ballObject = namedObjects[BALL_NAME]

if ballObject then
	configuredBall = configureRedBall(ballObject)
else
	warn("[VortexMapGameplay] Missing required Workspace object: " .. BALL_NAME)
end

local configuredHammers = 0

for hammerIndex = 1, HAMMER_COUNT do
	local name = "Hammer" .. tostring(hammerIndex)
	local hammerObject = namedObjects[name]

	if hammerObject then
		if configureHammer(hammerObject, hammerIndex) then
			configuredHammers += 1
		end
	else
		warn("[VortexMapGameplay] Missing required Workspace object: " .. name)
	end
end

local finalSafeZoneCount = select(1, refreshSafeZoneReferences())

print(
	"[VortexMapGameplay] V237 loaded | SafeZones="
		.. tostring(finalSafeZoneCount)
		.. "/"
		.. tostring(SAFE_ZONE_COUNT)
		.. " | WinPads="
		.. tostring(createdWinPads)
		.. "/"
		.. tostring(EXPECTED_PAD_COUNT)
		.. " | Future2xPads="
		.. tostring(createdFuturePads)
		.. "/"
		.. tostring(EXPECTED_PAD_COUNT)
		.. " | PadWatchdog=manual-CFrame-safe"
		.. " | PadFallback=V235"
		.. " | RedBall="
		.. tostring(configuredBall)
		.. " (client-current full-body swept 100% hitbox)"
		.. " | Hammers="
		.. tostring(configuredHammers)
		.. "/"
		.. tostring(HAMMER_COUNT)
		.. " | WaterHazards="
		.. tostring(configuredStaticHazards)
		.. " object(s) (parts="
		.. tostring(configuredStaticHazardParts)
		.. ")"
)
