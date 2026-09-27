                          
  
                              
                                                                   
                                 
                                 
  
                                                                              
                                                                            
                                                                           
                                                                            

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local IS_NEW_WORLD1 = Config.IsNewWorld1Map == true
local SEARCH_ROOT = Workspace
if IS_NEW_WORLD1 then
	local markerName = tostring(Config.NewWorld1MapMarkerName or "neworld1")
	SEARCH_ROOT = Workspace:FindFirstChild(markerName) or Workspace:WaitForChild(markerName, 25)
end

if not SEARCH_ROOT then
	warn("[ReverseFlashBoss] New World 1 map root is missing")
	return
end

local BOSS_NAME = "ReverseFlashBoss"
local BOSS_AREA_NAME = "BossArea"
local SAFE_ZONE_ATTRIBUTE = "SafeZoneProtected"
local SAFE_ZONE_COUNT = IS_NEW_WORLD1 and 11 or 10
local FIND_TIMEOUT_SECONDS = 25
local BOSS_TRAIL_TEMPLATE_ID = "Trail02"
local BOSS_TRAIL_INSTANCE_NAME = "ReverseFlashBossRedTrail"
local BOSS_TRAIL_COLOR = Color3.fromRGB(255, 0, 0)
local BOSS_RED_EYES_NAME = "ReverseFlashBossRedEyes"

                         
                                                                           
                                                                       
                                                                              
local DEFAULT_WALK_SPEED = 26.5
local TARGET_REFRESH_INTERVAL = 0.075
local TARGET_LEAD_SECONDS = 0.04
local MAX_TARGET_LEAD_STUDS = 4
local STEERING_RESPONSE = 12
local ARRIVAL_DISTANCE = 2.5
local TOUCH_DEBOUNCE = 0.35
local HOME_ARRIVAL_DISTANCE = 0.9
local HOME_VERTICAL_SNAP_DISTANCE = 8
local HOME_RETURN_TIMEOUT_MIN = 6
local HOME_RETURN_TIMEOUT_MULTIPLIER = 2.5

local SAFE_ZONE_SIDE_PADDING = 0.75
local SAFE_ZONE_BELOW_PADDING = 2
local SAFE_ZONE_HEIGHT_ABOVE = 12
local BOSS_AREA_BELOW_PADDING = 3
local BOSS_AREA_HEIGHT_ABOVE = 180

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

local function findNamedObject(name, classCheck)
	local normalizedTarget = normalizeName(name)
	local matches = {}

	for _, object in ipairs(SEARCH_ROOT:GetDescendants()) do
		if normalizeName(object.Name) == normalizedTarget and classCheck(object) then
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

	if #matches > 1 then
		warn(
			"[ReverseFlashBoss] Multiple objects match "
				.. name
				.. "; using "
				.. matches[1]:GetFullName()
		)
	end

	return matches[1]
end

local function waitForNamedObject(name, classCheck)
	local deadline = os.clock() + FIND_TIMEOUT_SECONDS

	repeat
		local result = findNamedObject(name, classCheck)
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

	return math.abs(localPoint.X) <= halfSize.X
		and math.abs(localPoint.Z) <= halfSize.Z
		and localPoint.Y >= -halfSize.Y - BOSS_AREA_BELOW_PADDING
		and localPoint.Y <= halfSize.Y + BOSS_AREA_HEIGHT_ABOVE
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

local function safeZoneObjectName(zoneIndex)
	if IS_NEW_WORLD1 then
		return tostring(Config.NewWorld1SafeZonePrefix or "stage") .. tostring(zoneIndex)
	end
	return "SafeZone" .. tostring(zoneIndex)
end

                                                                     
                                                                                
                                                                               
                                                                               
                                                                                  
                                                                                   
                                                                                
                                                                                
                                                                                  
local bossArea = waitForNamedObject(BOSS_AREA_NAME, isAreaObject)
if not bossArea then
	warn("[ReverseFlashBoss] Missing new World 1 area: " .. BOSS_AREA_NAME)
	return
end

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
			if candidateRoot and isPointInsideArea(candidateRoot.Position, bossArea) then
				table.insert(inside, candidate)
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
		return inside[1], "workspace-exact-name-inside-neworld1-BossArea"
	end
	if #inside > 1 then
		warn("[ReverseFlashBoss] Multiple exact ReverseFlashBoss models are physically inside new World 1 BossArea; refusing to guess")
		return nil, "ambiguous-inside-area"
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

local safeZones = {}
local missingSafeZones = {}

for zoneIndex = 1, SAFE_ZONE_COUNT do
	local zoneName = safeZoneObjectName(zoneIndex)
	safeZones[zoneIndex] = waitForNamedObject(zoneName, isAreaObject)

	if not safeZones[zoneIndex] then
		table.insert(missingSafeZones, zoneName)
	end
end

if not boss then
	warn("[ReverseFlashBoss] Could not bind exact " .. BOSS_NAME .. " for new World 1 | source=" .. tostring(bossBindSource) .. " | exactCandidates=" .. tostring(#bossCandidates))
	return
end

                                                                          
                                                                              
if #missingSafeZones > 0 then
	warn(
		"[ReverseFlashBoss] Disabled because these protection areas are missing: "
			.. table.concat(missingSafeZones, ", ")
	)
	return
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
	warn("[ReverseFlashBoss] ReverseFlashBoss needs a Humanoid")
	return
end

if not root or not root:IsA("BasePart") then
	warn("[ReverseFlashBoss] ReverseFlashBoss needs a HumanoidRootPart")
	return
end

                                                                           
                                                                            
                                                                    
local homeRootCFrame = root.CFrame

if humanoid.RigType ~= Enum.HumanoidRigType.R6 then
	warn("[ReverseFlashBoss] ReverseFlashBoss is expected to be an R6 rig")
end

local coreR6PartNames = {
	head = true,
	torso = true,
	humanoidrootpart = true,
	leftarm = true,
	rightarm = true,
	leftleg = true,
	rightleg = true,
}

local ignoredEffectParts = {}
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

local function isProtectedHeadOrEyeEffect(instance)
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

local function rememberNonRigEffectHolder(effect)
	local current = effect.Parent

	while current and current ~= boss do
		if current:IsA("BasePart") then
			if not coreR6PartNames[normalizeName(current.Name)] then
				ignoredEffectParts[current] = true
			end
			return
		end

		current = current.Parent
	end
end

local function removeBuiltInBossEffects()
	local removedCount = 0

	for _, descendant in ipairs(boss:GetDescendants()) do
		if isSpeedVisualEffect(descendant)
			and not isInsideNewBossTrail(descendant)
			and not isProtectedHeadOrEyeEffect(descendant)
		then
			rememberNonRigEffectHolder(descendant)
			descendant:Destroy()
			removedCount += 1
		end
	end

	return removedCount
end

local function recolorAndEnableBossTrail(instance)
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
		warn("[ReverseFlashBoss] CosmeticTemplateBuilder was not found")
		return nil
	end

	local builder = require(builderModule)
	templates = builder.Build()
	trails = templates and templates:FindFirstChild("Trails")
	source = trails and trails:FindFirstChild(BOSS_TRAIL_TEMPLATE_ID)

	if not source then
		warn("[ReverseFlashBoss] Project trail template Trail02 was not built")
		return nil
	end

	return source
end

local function attachProjectRedTrail()
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

		recolorAndEnableBossTrail(clone)

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
		weld.Name = "BossTrailWeld"
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
		warn("[ReverseFlashBoss] Could not attach project Trail02: " .. tostring(result))
		return false
	end

	return result ~= nil
end

local function createGuaranteedRedEyes()
	local head = boss:FindFirstChild("Head", true)
	if not head or not head:IsA("BasePart") then
		warn("[ReverseFlashBoss] Could not restore red eyes because Head was not found")
		return false
	end

	local oldEyes = boss:FindFirstChild(BOSS_RED_EYES_NAME)
	if oldEyes then
		oldEyes:Destroy()
	end

	local eyeModel = Instance.new("Model")
	eyeModel.Name = BOSS_RED_EYES_NAME
	eyeModel:SetAttribute("BossCosmeticEffect", true)
	eyeModel:SetAttribute("EyeColor", BOSS_TRAIL_COLOR)
	eyeModel.Parent = boss

	for eyeIndex, side in ipairs({ -1, 1 }) do
		local eye = Instance.new("Part")
		eye.Name = eyeIndex == 1 and "LeftRedEye" or "RightRedEye"
		eye.Size = Vector3.new(
			math.max(0.18, head.Size.X * 0.11),
			math.max(0.12, head.Size.Y * 0.14),
			0.06
		)
		eye.Material = Enum.Material.Neon
		eye.Color = BOSS_TRAIL_COLOR
		eye.Transparency = 0
		eye.CastShadow = false
		eye.Anchored = false
		eye.CanCollide = false
		eye.CanTouch = false
		eye.CanQuery = false
		eye.Massless = true
		eye.CFrame = head.CFrame * CFrame.new(
			side * head.Size.X * 0.18,
			head.Size.Y * 0.08,
			-(head.Size.Z * 0.5 + 0.035)
		)
		eye.Parent = eyeModel

		local weld = Instance.new("WeldConstraint")
		weld.Name = "RedEyeWeld"
		weld.Part0 = head
		weld.Part1 = eye
		weld.Parent = eye

		local light = Instance.new("PointLight")
		light.Name = "RedEyeGlow"
		light.Color = BOSS_TRAIL_COLOR
		light.Brightness = 0.75
		light.Range = 5
		light.Shadows = false
		light.Parent = eye
	end

	return true
end

                                                                            
                                                                             
                                          
local removedBuiltInEffectCount = removeBuiltInBossEffects()
local redEyesAttached = createGuaranteedRedEyes()

boss.DescendantAdded:Connect(function(descendant)
	if isSpeedVisualEffect(descendant)
		and not bossTrailInstalling
		and not isInsideNewBossTrail(descendant)
		and not isProtectedHeadOrEyeEffect(descendant)
	then
		task.defer(function()
			if descendant.Parent
				and not bossTrailInstalling
				and not isInsideNewBossTrail(descendant)
				and not isProtectedHeadOrEyeEffect(descendant)
			then
				rememberNonRigEffectHolder(descendant)
				descendant:Destroy()
			end
		end)
	end
end)

local projectTrailAttached = attachProjectRedTrail()

if not projectTrailAttached then
	task.spawn(function()
		for _ = 1, 8 do
			task.wait(1.5)
			if attachProjectRedTrail() then
				projectTrailAttached = true
				boss:SetAttribute("BossTrailPureRed", true)
				return
			end
		end
	end)
end

boss:SetAttribute("RemovedBuiltInSpeedVFX", removedBuiltInEffectCount)
boss:SetAttribute("BossTrailSource", BOSS_TRAIL_TEMPLATE_ID)
boss:SetAttribute("BossTrailPureRed", projectTrailAttached)
boss:SetAttribute("GuaranteedRedEyes", redEyesAttached)

local function isInAnySafeZone(position)
	for zoneIndex = 1, SAFE_ZONE_COUNT do
		if isPointInsideSafeZone(position, safeZones[zoneIndex]) then
			return true
		end
	end

	return false
end

local configuredBossParts = {}

local function configureBossPart(part)
	if configuredBossParts[part] or not part:IsA("BasePart") then
		return
	end

	if ignoredEffectParts[part] or isInsideBossCosmetic(part) then
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

	configuredBossParts[part] = true
	part.Anchored = false
	part.CanTouch = true

	                                                                          
	                                                                            
	local normalized = normalizeName(part.Name)
	if part ~= root and normalized ~= "torso" then
		part.CanCollide = false
		part.Massless = true
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

                                                                         
                                                                               
local resolvedWalkSpeed = DEFAULT_WALK_SPEED
boss:SetAttribute("BossWalkSpeed", resolvedWalkSpeed)
humanoid.WalkSpeed = resolvedWalkSpeed

                                                                                 
                                                                               
                                                                  
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

	if not isPointInsideArea(targetRoot.Position, bossArea) then
		return nil, nil
	end

	                                                                         
	                                                                            
	                  
	if isInAnySafeZone(targetRoot.Position) then
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
	if Workspace:GetAttribute("AdminWorldFrozen") == true then
		return -- frozen by the admin Snow event
	end
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

	                                                                       
	                                                                         
	                             
	if character:GetAttribute(SAFE_ZONE_ATTRIBUTE) == true
		or player:GetAttribute(SAFE_ZONE_ATTRIBUTE) == true
		or isInAnySafeZone(targetRoot.Position)
	then
		return
	end

	local now = os.clock()
	if now - (lastTouchAt[targetHumanoid] or -math.huge) < TOUCH_DEBOUNCE then
		return
	end

	lastTouchAt[targetHumanoid] = now
	character:SetAttribute("Dead", true)
	character:SetAttribute("Ragdolled", true)
	targetHumanoid.Health = 0
	pcall(function()
		targetHumanoid:TakeDamage(targetHumanoid.MaxHealth + 1000)
	end)
end

local touchConnections = {}

local function connectBossTouch(part)
	if not configuredBossParts[part] or touchConnections[part] then
		return
	end

	touchConnections[part] = part.Touched:Connect(killPlayerOnTouch)
end

for part in pairs(configuredBossParts) do
	connectBossTouch(part)
end

boss.DescendantAdded:Connect(function(descendant)
	if descendant:IsA("BasePart") then
		connectBossTouch(descendant)
	end
end)

local trackingActive = false
local currentTargetPlayer = nil
local currentTargetRoot = nil
local nextTargetRefreshAt = 0
local smoothedDirection = Vector3.zero
local homeReturnStartedAt = nil
local homeReturnTimeout = HOME_RETURN_TIMEOUT_MIN

local function setTrackingState(player)
	local active = player ~= nil
	if trackingActive ~= active then
		trackingActive = active
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
	if distance <= HOME_ARRIVAL_DISTANCE and verticalDistance <= 2.5 then
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
			(distance / math.max(resolvedWalkSpeed, 1)) * HOME_RETURN_TIMEOUT_MULTIPLIER + 2
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

boss:SetAttribute("BossTrackingConfigured", true)
boss:SetAttribute("TrackingArea", BOSS_AREA_NAME)
boss:SetAttribute("SafeZoneExclusion", IS_NEW_WORLD1 and "stage1-stage11" or "SafeZone1-10")
boss:SetAttribute("TrackingMode", "HeartbeatDirectSteeringV231")
boss:SetAttribute("ResolvedBossWalkSpeed", resolvedWalkSpeed)
boss:SetAttribute("ProceduralR6Walk", true)
boss:SetAttribute("TouchKillsOutsideSafeZones", true)
boss:SetAttribute("RestoredFromV306IK", true)
boss:SetAttribute("RestoredR6RunPresentation", "V231Procedural")
boss:SetAttribute("RestoredBossAreaSoundIds", "110509599718307,89362634813966")
boss:SetAttribute("AuthoredHomeCFrame", homeRootCFrame)
boss:SetAttribute("ReturnsHomeWithoutTarget", true)
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

	if Workspace:GetAttribute("AdminWorldFrozen") == true then
		-- Frozen by the admin Snow event.
		humanoid:Move(Vector3.zero, false)
		root.AssemblyLinearVelocity = Vector3.zero
		return
	end

	local now = os.clock()
	local eligibleCurrentRoot = currentTargetPlayer
		and select(1, getEligibleTarget(currentTargetPlayer))

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
	"[ReverseFlashBoss] V306KBN restored V306IK behavior | speed="
		.. tostring(resolvedWalkSpeed)
		.. " | project Trail02 pure red="
		.. tostring(projectTrailAttached)
		.. " | red eyes="
		.. tostring(redEyesAttached)
		.. " | smooth pursuit | procedural R6 walk | SafeZone-aware touch kill | boss="
		.. boss:GetFullName()
		.. " | bindSource="
		.. tostring(bossBindSource)
		.. " | area="
		.. bossArea:GetFullName()
)
