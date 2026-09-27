                   
  
                              
                                                        
                                     
  
                                                                              
                                                                             
                                                                           

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
if Config.IsWorld2Place == true then
	return
end
local IS_NEW_WORLD1 = Config.IsNewWorld1Map == true
local SEARCH_ROOT = Workspace
if IS_NEW_WORLD1 then
	local markerName = tostring(Config.NewWorld1MapMarkerName or "neworld1")
	SEARCH_ROOT = Workspace:FindFirstChild(markerName) or Workspace:WaitForChild(markerName, 25)
end

if not SEARCH_ROOT then
	warn("[ZoomBoss] New World 1 map root is missing")
	return
end

local BOSS_NAME = "Zoom"
local ARENA_NAME = "ZoomsArena"
local EXPECTED_ARENA_PARTS = IS_NEW_WORLD1 and 1 or 3
local SAFE_ZONE_NAMES = { "SafeZone5", "SafeZone6" }
local FIND_TIMEOUT_SECONDS = 25

local BOSS_TRAIL_TEMPLATE_ID = "Trail02"
local BOSS_TRAIL_INSTANCE_NAME = "ZoomDarkBlueTrail"
local BOSS_TRAIL_COLOR = Color3.fromRGB(12, 48, 190)

                                                       
                                                                              
                                                                  
                                                                           
local DEFAULT_WALK_SPEED = 55.75

local TARGET_REFRESH_INTERVAL = 0.06
local TARGET_LEAD_SECONDS = 0.18
local MAX_TARGET_LEAD_STUDS = 10
local STEERING_RESPONSE = 18
local ARRIVAL_DISTANCE = 0.35
local TOUCH_DEBOUNCE = 0.35
local HOME_ARRIVAL_DISTANCE = 0.9
local HOME_VERTICAL_SNAP_DISTANCE = 10
local HOME_RETURN_TIMEOUT_MIN = 6
local HOME_RETURN_TIMEOUT_MULTIPLIER = 2.5

                                                                        
                                                                      
local TRAIL_VISUAL_BOOST = 0.95
local TRAIL_MIN_VISUAL_SCALE = 1.25
local TRAIL_MAX_VISUAL_SCALE = 4.5
local TRAIL_LIFETIME_BOOST = 1.10

local ARENA_SIDE_PADDING = 0
local ARENA_BELOW_PADDING = 3
local ARENA_HEIGHT_ABOVE = 12
local SAFE_ZONE_SIDE_PADDING = 0.75
local SAFE_ZONE_BELOW_PADDING = 2
local SAFE_ZONE_HEIGHT_ABOVE = 12

local function normalizeName(value)
	return tostring(value or ""):lower():gsub("[^%w]", "")
end

local function objectDepth(object)
	local depth = 0
	local current = object

	while current and current.Parent and current.Parent ~= SEARCH_ROOT do
		depth += 1
		current = current.Parent
	end

	return depth
end

local function findNamedModel(name)
	local normalizedTarget = normalizeName(name)
	local matches = {}

	for _, object in ipairs(SEARCH_ROOT:GetDescendants()) do
		if object:IsA("Model") and normalizeName(object.Name) == normalizedTarget then
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

local function waitForNamedModel(name)
	local deadline = os.clock() + FIND_TIMEOUT_SECONDS
	repeat
		local result = findNamedModel(name)
		if result then
			return result
		end
		task.wait(0.25)
	until os.clock() >= deadline
	return nil
end

local function isAreaObject(object)
	return object:IsA("BasePart") or object:IsA("Model")
end

local function findNamedArea(name)
	local normalizedTarget = normalizeName(name)
	local matches = {}

	for _, object in ipairs(SEARCH_ROOT:GetDescendants()) do
		if isAreaObject(object) and normalizeName(object.Name) == normalizedTarget then
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

local function collectArenaObjects()
	local normalizedTarget = normalizeName(ARENA_NAME)
	local matches = {}

	for _, object in ipairs(SEARCH_ROOT:GetDescendants()) do
		if isAreaObject(object) and normalizeName(object.Name) == normalizedTarget then
			table.insert(matches, object)
		end
	end

	table.sort(matches, function(left, right)
		return left:GetFullName() < right:GetFullName()
	end)

	return matches
end

local function waitForArenaObjects()
	local deadline = os.clock() + FIND_TIMEOUT_SECONDS
	local best = {}

	repeat
		local matches = collectArenaObjects()
		if #matches > #best then
			best = matches
		end
		if #matches >= EXPECTED_ARENA_PARTS then
			return matches
		end
		task.wait(0.25)
	until os.clock() >= deadline

	return best
end

local function getBounds(object)
	if not object then
		return nil, nil
	end

	if object:IsA("BasePart") then
		return object.CFrame, object.Size
	end

	if object:IsA("Model") then
		local ok, boundsCFrame, boundsSize = pcall(function()
			return object:GetBoundingBox()
		end)
		if ok then
			return boundsCFrame, boundsSize
		end
	end

	return nil, nil
end

local staticBoundsCache = setmetatable({}, { __mode = "k" })

local function getStaticBounds(object)
	local cached = object and staticBoundsCache[object]
	if cached then
		return cached.CFrame, cached.Size
	end

	local boundsCFrame, boundsSize = getBounds(object)
	if boundsCFrame and boundsSize then
		staticBoundsCache[object] = {
			CFrame = boundsCFrame,
			Size = boundsSize,
		}
	end
	return boundsCFrame, boundsSize
end

local function isPointInsideArea(point, area)
	local areaCFrame, areaSize = getStaticBounds(area)
	if not areaCFrame or not areaSize then
		return false
	end

	local localPoint = areaCFrame:PointToObjectSpace(point)
	local halfSize = areaSize * 0.5

	return math.abs(localPoint.X) <= halfSize.X + ARENA_SIDE_PADDING
		and math.abs(localPoint.Z) <= halfSize.Z + ARENA_SIDE_PADDING
		and localPoint.Y >= -halfSize.Y - ARENA_BELOW_PADDING
		and localPoint.Y <= halfSize.Y + ARENA_HEIGHT_ABOVE
end

local function isPointInsideSafeZone(point, safeZone)
	local zoneCFrame, zoneSize = getStaticBounds(safeZone)
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

local function resolveSafeZoneName(name)
	if IS_NEW_WORLD1 then
		local index = tostring(name):match("(%d+)$")
		if index then
			return tostring(Config.NewWorld1SafeZonePrefix or "stage") .. index
		end
	end
	return name
end

local arenaObjects = waitForArenaObjects()

                                                                              
                                                                            
                                                                              
                                                             
local normalizedBossName = normalizeName(BOSS_NAME)
local bossCandidates = {}
local bossCandidateSet = setmetatable({}, { __mode = "k" })

local function getCandidateRoot(model)
	if not model or not model:IsA("Model") then
		return nil
	end
	local candidateRoot = model:FindFirstChild("HumanoidRootPart", true)
	if candidateRoot and candidateRoot:IsA("BasePart") then
		return candidateRoot
	end
	return nil
end

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

local bossCandidateConnection = Workspace.DescendantAdded:Connect(addBossCandidate)

local function resolveBossCandidate()
	local live = {}
	local inside = {}
	for _, candidate in ipairs(bossCandidates) do
		if candidate.Parent then
			table.insert(live, candidate)
			local candidateRoot = getCandidateRoot(candidate)
			if candidateRoot then
				for _, arena in ipairs(arenaObjects) do
					if arena.Parent and isPointInsideArea(candidateRoot.Position, arena) then
						table.insert(inside, candidate)
						break
					end
				end
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
		return inside[1], "workspace-exact-name-inside-newworld1-ZoomsArena"
	end
	if #inside > 1 then
		warn("[ZoomBoss] Multiple exact Zoom models are physically inside new World 1 ZoomsArena; refusing to guess")
		return nil, "ambiguous-inside-arena"
	end
	if #live == 1 then
		return live[1], "unique-workspace-exact-name"
	end
	return nil, #live == 0 and "missing" or "ambiguous-workspace"
end

local boss = nil
local bossBindSource = "missing"
local deadline = os.clock() + FIND_TIMEOUT_SECONDS
repeat
	boss, bossBindSource = resolveBossCandidate()
	if boss then
		break
	end
	task.wait(0.10)
until os.clock() >= deadline

if bossCandidateConnection then
	bossCandidateConnection:Disconnect()
end

if IS_NEW_WORLD1 and boss and #arenaObjects > 1 then
	                                                                               
	                                                                                
	local candidateRoot = getCandidateRoot(boss)
	local bossPosition = candidateRoot and candidateRoot.Position or boss:GetPivot().Position
	local containing = {}
	for _, arena in ipairs(arenaObjects) do
		if isPointInsideArea(bossPosition, arena) then
			table.insert(containing, arena)
		end
	end
	if #containing > 0 then
		arenaObjects = containing
	else
		table.sort(arenaObjects, function(left, right)
			local leftCFrame = select(1, getStaticBounds(left))
			local rightCFrame = select(1, getStaticBounds(right))
			local leftDistance = leftCFrame and (leftCFrame.Position - bossPosition).Magnitude or math.huge
			local rightDistance = rightCFrame and (rightCFrame.Position - bossPosition).Magnitude or math.huge
			return leftDistance < rightDistance
		end)
		arenaObjects = { arenaObjects[1] }
	end
end

local protectedSafeZones = {}
local missingSafeZones = {}
for _, zoneName in ipairs(SAFE_ZONE_NAMES) do
	local resolvedZoneName = resolveSafeZoneName(zoneName)
	local zone = findNamedArea(resolvedZoneName)
	if zone then
		table.insert(protectedSafeZones, zone)
	else
		table.insert(missingSafeZones, resolvedZoneName)
	end
end

if not boss then
	warn(
		"[ZoomBoss] Could not bind exact "
			.. BOSS_NAME
			.. " for new World 1 | source="
			.. tostring(bossBindSource)
			.. " | exactCandidates="
			.. tostring(#bossCandidates)
	)
	return
end

if #missingSafeZones > 0 then
	warn(
		"[ZoomBoss] V306KBO disabled safely because these protection areas are missing: "
			.. table.concat(missingSafeZones, ", ")
	)
	return
end

if #arenaObjects == 0 then
	warn("[ZoomBoss] No new World 1 objects named " .. ARENA_NAME .. " were found")
	return
end

if #arenaObjects < EXPECTED_ARENA_PARTS then
	warn(
		"[ZoomBoss] Expected "
			.. tostring(EXPECTED_ARENA_PARTS)
			.. " ZoomsArena parts, but found "
			.. tostring(#arenaObjects)
			.. ". Using the ones that exist."
	)
end

local humanoid = boss:FindFirstChildWhichIsA("Humanoid", true)
local root = boss:FindFirstChild("HumanoidRootPart", true)
if not humanoid or not root then
	local rigDeadline = os.clock() + 10
	repeat
		task.wait(0.10)
		humanoid = humanoid or boss:FindFirstChildWhichIsA("Humanoid", true)
		root = root or boss:FindFirstChild("HumanoidRootPart", true)
	until (humanoid and root) or os.clock() >= rigDeadline
end

if not humanoid or not humanoid:IsA("Humanoid") then
	warn("[ZoomBoss] Zoom needs a Humanoid")
	return
end

if not root or not root:IsA("BasePart") then
	warn("[ZoomBoss] Zoom needs a HumanoidRootPart")
	return
end

boss:SetAttribute("NewWorld1ZoomBossKBO", true)
boss:SetAttribute("ZoomBossBindSourceKBO", bossBindSource)

                                                             
local homeRootCFrame = root.CFrame

if humanoid.RigType ~= Enum.HumanoidRigType.R15 then
	warn("[ZoomBoss] Zoom is expected to be an R15 rig")
end

local function isInAnyArena(position)
	for _, arena in ipairs(arenaObjects) do
		if arena.Parent and isPointInsideArea(position, arena) then
			return true
		end
	end
	return false
end

local function isInProtectedSafeZone(position)
	for _, safeZone in ipairs(protectedSafeZones) do
		if safeZone.Parent and isPointInsideSafeZone(position, safeZone) then
			return true
		end
	end
	return false
end

local function isInZoomChaseArea(position)
	return isInAnyArena(position) and not isInProtectedSafeZone(position)
end

                                                                               
                                                      
local bossTrailModel = nil
local bossTrailInstalling = false

local function isSpeedVisualEffect(instance)
	return instance:IsA("Trail")
		or instance:IsA("Beam")
		or instance:IsA("ParticleEmitter")
		or instance:IsA("Fire")
		or instance:IsA("Smoke")
		or instance:IsA("Sparkles")
end

local function isInsideNewBossTrail(instance)
	return bossTrailModel ~= nil
		and instance ~= bossTrailModel
		and instance:IsDescendantOf(bossTrailModel)
end

local function isInsideBossCosmetic(instance)
	local current = instance
	while current and current ~= boss do
		if current:GetAttribute("BossCosmeticEffect") == true then
			return true
		end
		current = current.Parent
	end
	return false
end

local function isProtectedHeadEffect(instance)
	local current = instance.Parent
	while current and current ~= boss do
		local normalized = normalizeName(current.Name)
		if normalized == "head" or normalized:find("eye", 1, true) then
			return true
		end
		current = current.Parent
	end
	return false
end

local function removeBuiltInSpeedEffects()
	local removed = 0
	for _, descendant in ipairs(boss:GetDescendants()) do
		if isSpeedVisualEffect(descendant)
			and not isInsideNewBossTrail(descendant)
			and not isProtectedHeadEffect(descendant)
		then
			descendant:Destroy()
			removed += 1
		end
	end
	return removed
end

local function getProjectTrailTemplate()
	local templates = ServerStorage:FindFirstChild("CosmeticTemplates")
	local trails = templates and templates:FindFirstChild("Trails")
	local source = trails and trails:FindFirstChild(BOSS_TRAIL_TEMPLATE_ID)
	if source then
		return source
	end

	local ServerScriptService = game:GetService("ServerScriptService")
	local builderModule = (ServerScriptService:FindFirstChild("Economy") and ServerScriptService.Economy:FindFirstChild("Cosmetics") and ServerScriptService.Economy.Cosmetics:FindFirstChild("CosmeticTemplateBuilder"))
		or (ServerScriptService:FindFirstChild("Cosmetics") and ServerScriptService.Cosmetics:FindFirstChild("CosmeticTemplateBuilder"))
		or ServerScriptService:FindFirstChild("CosmeticTemplateBuilder", true)

	if not builderModule or not builderModule:IsA("ModuleScript") then
		warn("[ZoomBoss] CosmeticTemplateBuilder was not found")
		return nil
	end

	local builder = require(builderModule)
	templates = builder.Build()
	trails = templates and templates:FindFirstChild("Trails")
	source = trails and trails:FindFirstChild(BOSS_TRAIL_TEMPLATE_ID)
	if not source then
		warn("[ZoomBoss] Project trail template Trail02 was not built")
		return nil
	end
	return source
end

local function getZoomModelScale()
	local modelScale = 1
	pcall(function()
		modelScale = boss:GetScale()
	end)

	local rootScale = math.max(
		root.Size.X / 2,
		root.Size.Y / 2,
		root.Size.Z / 1
	)

	return math.max(1, modelScale, rootScale)
end

local ZOOM_MODEL_SCALE = getZoomModelScale()
local ZOOM_TRAIL_VISUAL_SCALE = math.clamp(
	ZOOM_MODEL_SCALE * TRAIL_VISUAL_BOOST,
	TRAIL_MIN_VISUAL_SCALE,
	TRAIL_MAX_VISUAL_SCALE
)

local function scaleNumberSequence(sequence, factor)
	local keypoints = {}
	for _, keypoint in ipairs(sequence.Keypoints) do
		table.insert(
			keypoints,
			NumberSequenceKeypoint.new(
				keypoint.Time,
				keypoint.Value * factor,
				keypoint.Envelope * factor
			)
		)
	end
	return NumberSequence.new(keypoints)
end

local function scaleBossTrailGeometry(instance)
	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("Attachment") then
			descendant.Position *= ZOOM_TRAIL_VISUAL_SCALE
		elseif descendant:IsA("Trail") then
			descendant.WidthScale = scaleNumberSequence(descendant.WidthScale, ZOOM_TRAIL_VISUAL_SCALE)
			descendant.Lifetime *= TRAIL_LIFETIME_BOOST
		elseif descendant:IsA("Beam") then
			descendant.Width0 *= ZOOM_TRAIL_VISUAL_SCALE
			descendant.Width1 *= ZOOM_TRAIL_VISUAL_SCALE
		elseif descendant:IsA("ParticleEmitter") then
			descendant.Size = scaleNumberSequence(descendant.Size, ZOOM_TRAIL_VISUAL_SCALE)
			local speedFactor = math.sqrt(ZOOM_TRAIL_VISUAL_SCALE)
			descendant.Speed = NumberRange.new(
				descendant.Speed.Min * speedFactor,
				descendant.Speed.Max * speedFactor
			)
		end
	end
end

local function recolorAndEnableTrail(instance)
	local colorSequence = ColorSequence.new(BOSS_TRAIL_COLOR)
	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.CastShadow = false
			descendant.Massless = true
			descendant.Transparency = 1
		elseif descendant:IsA("Trail") or descendant:IsA("Beam") then
			descendant.Color = colorSequence
			descendant.LightEmission = 1
			descendant.LightInfluence = 0
			descendant.Enabled = true
		elseif descendant:IsA("ParticleEmitter") then
			descendant.Color = colorSequence
			descendant.LightEmission = 1
			descendant.LightInfluence = 0
			descendant.Enabled = true
		elseif descendant:IsA("PointLight")
			or descendant:IsA("SpotLight")
			or descendant:IsA("SurfaceLight")
		then
			descendant.Color = BOSS_TRAIL_COLOR
			descendant.Enabled = true
		end
	end
end

local function attachDarkBlueTrail()
	local oldTrail = boss:FindFirstChild(BOSS_TRAIL_INSTANCE_NAME)
	if oldTrail then
		oldTrail:Destroy()
	end

	bossTrailModel = nil
	bossTrailInstalling = true
	local pendingClone = nil

	local ok, result = pcall(function()
		local source = getProjectTrailTemplate()
		local clone = source:Clone()
		pendingClone = clone
		clone.Name = BOSS_TRAIL_INSTANCE_NAME
		clone:SetAttribute("BossCosmeticEffect", true)
		clone:SetAttribute("SourceTrailTemplate", BOSS_TRAIL_TEMPLATE_ID)
		clone:SetAttribute("ForcedColor", BOSS_TRAIL_COLOR)

		local holder = clone:FindFirstChild("EffectHolder", true)
		if not holder or not holder:IsA("BasePart") then
			clone:Destroy()
			error("Trail02 clone has no EffectHolder")
		end

		local localOffset = CFrame.new()
		local offsetValue = clone:FindFirstChild("LocalOffset")
		if offsetValue and offsetValue:IsA("CFrameValue") then
			localOffset = offsetValue.Value
		end

		scaleBossTrailGeometry(clone)
		recolorAndEnableTrail(clone)

		local trailCount = 0
		for _, descendant in ipairs(clone:GetDescendants()) do
			if descendant:IsA("Trail") then
				trailCount += 1
			end
		end
		if trailCount == 0 then
			error("Trail02 clone contains no Trail instances")
		end

		bossTrailModel = clone
		clone.Parent = boss
		holder.CFrame = root.CFrame * localOffset

		local weld = Instance.new("WeldConstraint")
		weld.Name = "ZoomTrailWeld"
		weld.Part0 = root
		weld.Part1 = holder
		weld.Parent = holder
		clone:SetAttribute("VerifiedTrailCount", trailCount)

		return clone
	end)

	bossTrailInstalling = false
	if not ok then
		if pendingClone then
			pendingClone:Destroy()
		end
		bossTrailModel = nil
		warn("[ZoomBoss] Could not attach dark-blue Trail02: " .. tostring(result))
		return false
	end

	return result ~= nil
end

local removedBuiltInEffectCount = removeBuiltInSpeedEffects()

boss.DescendantAdded:Connect(function(descendant)
	if isSpeedVisualEffect(descendant)
		and not bossTrailInstalling
		and not isInsideNewBossTrail(descendant)
		and not isProtectedHeadEffect(descendant)
	then
		task.defer(function()
			if descendant.Parent
				and not bossTrailInstalling
				and not isInsideNewBossTrail(descendant)
				and not isProtectedHeadEffect(descendant)
			then
				descendant:Destroy()
			end
		end)
	end
end)

local projectTrailAttached = attachDarkBlueTrail()
if not projectTrailAttached then
	task.spawn(function()
		for _ = 1, 8 do
			task.wait(1.5)
			if attachDarkBlueTrail() then
				projectTrailAttached = true
				boss:SetAttribute("ZoomTrailDarkBlue", true)
				return
			end
		end
	end)
end

boss:SetAttribute("RemovedBuiltInSpeedVFX", removedBuiltInEffectCount)
boss:SetAttribute("BossTrailSource", BOSS_TRAIL_TEMPLATE_ID)
boss:SetAttribute("ZoomTrailDarkBlue", projectTrailAttached)
boss:SetAttribute("ZoomTrailColorRGB", "12,48,190")
boss:SetAttribute("ZoomModelScale", ZOOM_MODEL_SCALE)
boss:SetAttribute("ZoomTrailVisualScale", ZOOM_TRAIL_VISUAL_SCALE)

                                                                               
local configuredBossParts = {}
local function configureBossPart(part)
	if configuredBossParts[part] or not part:IsA("BasePart") then
		return
	end
	configuredBossParts[part] = true

	if isInsideBossCosmetic(part) then
		part.Anchored = false
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = false
		part.Massless = true
		pcall(function()
			part:SetNetworkOwner(nil)
		end)
		return
	end

	part.Anchored = false
	part.CanTouch = true

	                                                                            
	                                                                         
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

	pcall(function()
		part:SetNetworkOwner(nil)
	end)
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
	end
end)

humanoid.AutoRotate = true
humanoid.PlatformStand = false
humanoid.Sit = false
humanoid.WalkSpeed = DEFAULT_WALK_SPEED

boss:SetAttribute("BossWalkSpeed", DEFAULT_WALK_SPEED)
boss:SetAttribute("ResolvedBossWalkSpeed", DEFAULT_WALK_SPEED)
boss:SetAttribute("BossTrackingConfigured", true)
boss:SetAttribute("TrackingArea", ARENA_NAME)
boss:SetAttribute("TrackingAreaPartCount", #arenaObjects)
boss:SetAttribute("TrackingMode", "HeartbeatDirectSteeringV306BV")
boss:SetAttribute("ProceduralR15Run", true)
boss:SetAttribute("ReverseFlashAnimationMatch", true)
boss:SetAttribute("ExcludedSafeZones", IS_NEW_WORLD1 and "stage5,stage6" or "SafeZone5,SafeZone6")
boss:SetAttribute("TouchKillsInsideZoomArena", true)
boss:SetAttribute("Level60BalanceWalkSpeed", 56.0929269628)
boss:SetAttribute("AuthoredHomeCFrame", homeRootCFrame)
boss:SetAttribute("ReturnsHomeWithoutTarget", true)

                                                                           
                                                                            
local animator = humanoid:FindFirstChildOfClass("Animator")
if animator then
	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		track:Stop(0.1)
	end
end

local function getEligibleTarget(player)
	local character = player.Character
	local targetHumanoid = character and character:FindFirstChildOfClass("Humanoid")
	local targetRoot = character and character:FindFirstChild("HumanoidRootPart")

	if not character
		or not targetHumanoid
		or targetHumanoid.Health <= 0
		or not targetRoot
		or not targetRoot:IsA("BasePart")
	then
		return nil, nil
	end

	                                                                   
	                                                                          
	if not isInZoomChaseArea(targetRoot.Position) then
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

local lastTouchAt = setmetatable({}, { __mode = "k" })

local function getPlayerCharacterFromHit(hit)
	if not hit or not hit:IsA("BasePart") or hit:IsDescendantOf(boss) then
		return nil, nil, nil
	end

	local current = hit.Parent
	while current and current ~= Workspace do
		if current:IsA("Model") then
			local targetHumanoid = current:FindFirstChildOfClass("Humanoid")
			local player = Players:GetPlayerFromCharacter(current)
			if targetHumanoid and player then
				return current, targetHumanoid, player
			end
		end
		current = current.Parent
	end

	return nil, nil, nil
end

local function killPlayerOnTouch(hit)
	local character, targetHumanoid, player = getPlayerCharacterFromHit(hit)
	if not character or not targetHumanoid or not player or targetHumanoid.Health <= 0 then
		return
	end
	if player:GetAttribute("StageTeleportInvulnerable") == true then
		return
	end

	local targetRoot = character:FindFirstChild("HumanoidRootPart")
	if not targetRoot or not targetRoot:IsA("BasePart") then
		return
	end

	                                                                
	                                            
	if not isInZoomChaseArea(targetRoot.Position) then
		return
	end

	local now = os.clock()
	if now - (lastTouchAt[targetHumanoid] or -math.huge) < TOUCH_DEBOUNCE then
		return
	end

	lastTouchAt[targetHumanoid] = now
	targetHumanoid.Health = 0
end

local touchConnections = {}
local function connectTouch(part)
	if touchConnections[part]
		or not part:IsA("BasePart")
		or isInsideBossCosmetic(part)
	then
		return
	end
	touchConnections[part] = part.Touched:Connect(killPlayerOnTouch)
end

for _, descendant in ipairs(boss:GetDescendants()) do
	if descendant:IsA("BasePart") then
		connectTouch(descendant)
	end
end

boss.DescendantAdded:Connect(function(descendant)
	if descendant:IsA("BasePart") then
		connectTouch(descendant)
	end
end)

local currentTargetPlayer = nil
local currentTargetRoot = nil
local nextTargetRefreshAt = 0
local smoothedDirection = Vector3.zero
local homeReturnStartedAt = nil
local homeReturnTimeout = HOME_RETURN_TIMEOUT_MIN

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

local function stopBoss()
	humanoid:Move(Vector3.zero, false)
	if root.Parent then
		local velocity = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(0, velocity.Y, 0)
		root.AssemblyAngularVelocity = Vector3.zero
	end
	smoothedDirection = Vector3.zero
	currentTargetPlayer = nil
	currentTargetRoot = nil
	homeReturnStartedAt = nil
	boss:SetAttribute("ReturningHome", false)
	setTrackingState(nil)
end

local function snapBossHome()
	humanoid:Move(Vector3.zero, false)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	root.CFrame = homeRootCFrame
	smoothedDirection = Vector3.zero
	homeReturnStartedAt = nil
	boss:SetAttribute("ReturningHome", false)
	boss:SetAttribute("AtAuthoredHome", true)
end

local function returnBossHome(deltaTime, now)
	currentTargetPlayer = nil
	currentTargetRoot = nil
	setTrackingState(nil)

	local displacement = horizontal(homeRootCFrame.Position - root.Position)
	local distance = displacement.Magnitude
	local verticalDistance = math.abs(root.Position.Y - homeRootCFrame.Position.Y)
	if distance <= HOME_ARRIVAL_DISTANCE and verticalDistance <= 3 then
		if boss:GetAttribute("AtAuthoredHome") ~= true then
			snapBossHome()
		else
			humanoid:Move(Vector3.zero, false)
		end
		return
	end

	if not homeReturnStartedAt then
		homeReturnStartedAt = now
		homeReturnTimeout = math.max(
			HOME_RETURN_TIMEOUT_MIN,
			(distance / math.max(DEFAULT_WALK_SPEED, 1)) * HOME_RETURN_TIMEOUT_MULTIPLIER + 2
		)
	end

	boss:SetAttribute("ReturningHome", true)
	boss:SetAttribute("AtAuthoredHome", false)
	if verticalDistance >= HOME_VERTICAL_SNAP_DISTANCE
		or now - homeReturnStartedAt >= homeReturnTimeout
	then
		snapBossHome()
		return
	end

	local desiredDirection = horizontalUnit(displacement)
	if not desiredDirection then
		snapBossHome()
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

stopBoss()

local heartbeatConnection
heartbeatConnection = RunService.Heartbeat:Connect(function(deltaTime)
	if not boss.Parent or not humanoid.Parent or not root.Parent or humanoid.Health <= 0 then
		if heartbeatConnection then
			heartbeatConnection:Disconnect()
		end
		stopBoss()
		return
	end

	local now = os.clock()
	local eligibleCurrentRoot = currentTargetPlayer and select(1, getEligibleTarget(currentTargetPlayer))
	if not eligibleCurrentRoot or eligibleCurrentRoot ~= currentTargetRoot then
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
		returnBossHome(deltaTime, now)
		return
	end

	homeReturnStartedAt = nil
	boss:SetAttribute("ReturningHome", false)
	boss:SetAttribute("AtAuthoredHome", false)

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
	"[ZoomBoss] V306KBO restored old Zoom behavior | speed="
		.. tostring(DEFAULT_WALK_SPEED)
		.. " | boss="
		.. boss:GetFullName()
		.. " | bindSource="
		.. tostring(bossBindSource)
		.. " | arena parts="
		.. tostring(#arenaObjects)
		.. " | dark-blue Trail02="
		.. tostring(projectTrailAttached)
		.. " | ZoomsArena minus SafeZone5/6 | ReverseFlash animation match | Level 60 barely outruns"
)
