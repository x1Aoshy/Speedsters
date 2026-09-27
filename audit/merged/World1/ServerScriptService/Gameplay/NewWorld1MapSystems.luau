                                                                      
  
                                                                                 
                                                                              
                                                                              

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
if Config.IsNewWorld1Map ~= true then
	return
end

local MAP_ROOT_NAME = tostring(Config.NewWorld1MapMarkerName or "neworld1")
local mapRoot = Workspace:FindFirstChild(MAP_ROOT_NAME)
if not mapRoot then
	warn("[NewWorld1MapSystems] Disabled: Workspace." .. MAP_ROOT_NAME .. " is missing")
	return
end
ReplicatedStorage:SetAttribute("NewWorld1MapActive", true)
ReplicatedStorage:SetAttribute("NewWorld1MapVersion", "V306KBV")
if tonumber(mapRoot:GetAttribute("NewWorld1MotionStartServerTime")) == nil then
	mapRoot:SetAttribute("NewWorld1MotionStartServerTime", Workspace:GetServerTimeNow() + 1)
end

local REMOTE_NAME = "NewWorld1HazardContact"
local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end

local contactRemote = remotes:FindFirstChild(REMOTE_NAME)
if contactRemote and not contactRemote:IsA("RemoteEvent") then
	contactRemote:Destroy()
	contactRemote = nil
end
if not contactRemote then
	contactRemote = Instance.new("RemoteEvent")
	contactRemote.Name = REMOTE_NAME
	contactRemote.Parent = remotes
end

local VALID_HAZARD_KEYS = {
	Cylinder = true,
	Hammer = true,
	Laser = true,
	PressDown = true,
	Fast = true,
	LavaUp = true,
	Lava = true,
}

local lastContactAt = setmetatable({}, { __mode = "k" })
contactRemote.OnServerEvent:Connect(function(player, hazardKey)
	if not VALID_HAZARD_KEYS[tostring(hazardKey or "")] then
		return
	end
	-- Frozen lava (the admin Snow event) does not burn.
	if (hazardKey == "Lava" or hazardKey == "LavaUp") and game:GetService("Workspace"):GetAttribute("AdminWorldFrozen") == true then
		return
	end

	local now = os.clock()
	if now - (lastContactAt[player] or -math.huge) < 0.08 then
		return
	end
	lastContactAt[player] = now

	if player:GetAttribute("StageTeleportInvulnerable") == true then
		return
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		                                                                           
		                                            
		humanoid.Health = 0
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastContactAt[player] = nil
end)

local function normalizeName(value)
	return tostring(value or ""):lower():gsub("[^%w]", "")
end

local function isMovableContainer(object)
	local name = normalizeName(object.Name)
	if name == "cylinder"
		or name == "cylinder1"
		or name == "rollingcylinder"
		or name == "cylinderstart"
		or name == "fast"
		or name == "lavaup"
		or name == "bridge"
		or name == "slide1"
		or name == "slide2"
		or name:match("^hammer[1-5]$")
		or name:match("^pressdown[1-3]$")
	then
		return true
	end
	return false
end

local function isFastEnd(object)
	return normalizeName(object.Name) == "fastend"
end

local function isCylinderStop(object)
	return normalizeName(object.Name) == "cylinderstop"
end

local function isPressDownStop(object)
	local name = normalizeName(object.Name)
	return name:match("^pressdown[1-3]stop$") ~= nil
		or name:match("^pressdownstop[1-3]$") ~= nil
end

local function isLaserBeam(object)
	if normalizeName(object.Name) ~= "laser" or not object:IsA("BasePart") then
		return false
	end
	local current = object.Parent
	while current and current ~= Workspace do
		if normalizeName(current.Name) == "laserplatform" then
			return true
		end
		current = current.Parent
	end
	return false
end

local function forEachBasePart(object, callback)
	if object:IsA("BasePart") then
		callback(object)
	end
	for _, descendant in ipairs(object:GetDescendants()) do
		if descendant:IsA("BasePart") then
			callback(descendant)
		end
	end
end

local function isDownPartPiece(part, pressObject)
	local current = part
	while current and current ~= pressObject do
		if normalizeName(current.Name) == "downpart" then
			return true
		end
		current = current.Parent
	end
	return normalizeName(part.Name) == "downpart"
end

local function prepareMapObject(object)
	if not object or not object.Parent then
		return
	end

	if isFastEnd(object) then
		                                                                         
		                                                                             
		                                                                              
		                                                                             
		                                                                         
		forEachBasePart(object, function(part)
			part.Anchored = true
			part.AssemblyLinearVelocity = Vector3.zero
			part.AssemblyAngularVelocity = Vector3.zero
		end)
		object:SetAttribute("NewWorld1VisibleFastEndKBQ", true)
		return
	end

	if isCylinderStop(object) then
		                                                                        
		                                                                          
		                                                                
		forEachBasePart(object, function(part)
			part.Anchored = true
			part.AssemblyLinearVelocity = Vector3.zero
			part.AssemblyAngularVelocity = Vector3.zero
			part.Transparency = 0
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.CastShadow = true
		end)
		object:SetAttribute("NewWorld1VisibleCylinderStop", true)
		object:SetAttribute("NewWorld1CylinderStopNonBlockingKBJ", true)
		return
	end

	if isPressDownStop(object) then
		                                                                        
		                                           
		                                                               
		forEachBasePart(object, function(part)
			part.Anchored = true
			part.AssemblyLinearVelocity = Vector3.zero
			part.AssemblyAngularVelocity = Vector3.zero
			part.Transparency = 0
			part.CanCollide = true
			part.CanTouch = true
			part.CanQuery = true
			part.CastShadow = true
		end)
		object:SetAttribute("NewWorld1VisiblePressDownStop", true)
		return
	end

	if isLaserBeam(object) then
		object.Anchored = true
		object.CanCollide = false
		object.CanTouch = false
		object.CanQuery = true
		object:SetAttribute("NewWorld1ClientHazard", "Laser")
		return
	end

	if not isMovableContainer(object) then
		return
	end

	local normalized = normalizeName(object.Name)
	if normalized == "cylinder"
		or normalized == "cylinder1"
		or normalized == "rollingcylinder"
		or normalized == "cylinderstart"
	then
		                                                                           
		                                                     
		object:SetAttribute("NewWorld1ServerMotionObject", true)
		return
	end
	forEachBasePart(object, function(part)
		part.Anchored = true
		part.AssemblyLinearVelocity = Vector3.zero
		part.AssemblyAngularVelocity = Vector3.zero

		local lethalMovingPart = normalized == "cylinder"
			or normalized == "cylinder1"
			or normalized == "rollingcylinder"
			or normalized == "cylinderstart"
			or normalized == "fast"
			or normalized == "lavaup"
			or normalized:match("^hammer[1-5]$") ~= nil
			or normalized:match("^pressdown[1-3]$") ~= nil
		if lethalMovingPart then
			part.CanTouch = false
			part.CanQuery = true
			                                                                      
			                                                           
			if normalized:match("^pressdown[1-3]$") ~= nil
				and isDownPartPiece(part, object)
			then
				part.Transparency = 0
				part.CanCollide = true
				part.CastShadow = true
			elseif normalized:match("^hammer[1-5]$") ~= nil then
				                                                                      
				                                                                   
				part.CanCollide = true
				part.CanQuery = true
			                                                                      
			                                                                             
			elseif normalized ~= "fast" or normalizeName(part.Name) == "hitbox" then
				part.CanCollide = false
			end
		end
	end)
	object:SetAttribute("NewWorld1ServerMotionObject", true)
end

local trackedNameCounts = {}
local function trackForAudit(object, delta)
	local normalized = normalizeName(object.Name)
	trackedNameCounts[normalized] = math.max(0, (trackedNameCounts[normalized] or 0) + delta)
end

                                                                           
                                                                               
                                                           
local startupObjects = mapRoot:GetDescendants()
for _, object in ipairs(startupObjects) do
	trackForAudit(object, 1)
	prepareMapObject(object)
end
table.clear(startupObjects)

mapRoot.DescendantAdded:Connect(function(object)
	trackForAudit(object, 1)
	task.defer(prepareMapObject, object)
	local current = object.Parent
	while current and current ~= mapRoot do
		if isMovableContainer(current) then
			task.defer(prepareMapObject, current)
			break
		end
		current = current.Parent
	end
end)

mapRoot.DescendantRemoving:Connect(function(object)
	trackForAudit(object, -1)
end)

local function hasEitherName(first, second)
	return (trackedNameCounts[first] or 0) > 0 or (trackedNameCounts[second] or 0) > 0
end

task.delay(4, function()
	local missing = {}
	local function requireName(displayName, normalizedName, minimumCount)
		if (trackedNameCounts[normalizedName] or 0) < (minimumCount or 1) then
			table.insert(missing, displayName)
		end
	end

	if not hasEitherName("cylinder", "cylinder1")
		and (trackedNameCounts.rollingcylinder or 0) <= 0
		and (trackedNameCounts.cylinderstart or 0) <= 0
		and mapRoot:GetAttribute("NewWorld1CylinderBoundPath") == nil
		and mapRoot:GetAttribute("NewWorld1CylinderFallbackBoundKBH") ~= true
	then
		table.insert(missing, "cylinder (named alias, classic Cylinder/CylinderMesh, cylinder-like FileMesh, or cylinder-like MeshPart/Union near cylinderstop)")
	end
	requireName("cylinderstop", "cylinderstop")
	for index = 1, 5 do
		if index ~= 2 then
			requireName("Hammer" .. index, "hammer" .. index)
		end
	end
	mapRoot:SetAttribute("NewWorld1Hammer2IntentionallyOptionalKBJ", true)
	requireName("laserplatform (3 copies)", "laserplatform", 3)
	for index = 1, 3 do
		requireName("pressdown" .. index, "pressdown" .. index)
		if not hasEitherName("pressdown" .. index .. "stop", "pressdownstop" .. index) then
			table.insert(missing, "pressdown" .. index .. "stop")
		end
	end
	requireName("slide1", "slide1")
	requireName("slide2", "slide2")
	requireName("Fast", "fast")
	requireName("Fast.Hitbox", "hitbox")
	requireName("Fastend", "fastend")
	requireName("LavaUp", "lavaup")
	requireName("Bridge", "bridge")
	requireName("BossArea", "bossarea")
	requireName("ZoomsArena", "zoomsarena")

	mapRoot:SetAttribute("NewWorld1SystemsVersion", "V306KBQ")
	mapRoot:SetAttribute("NewWorld1MissingContractCount", #missing)
	if #missing > 0 then
		warn(
			"[NewWorld1MapSystems] Runtime map is missing: "
				.. table.concat(missing, ", ")
				.. ". The controller remains armed and will bind them if they are inserted later."
		)
	else
		print("[NewWorld1MapSystems] V306KBQ runtime contract complete; every requested map object is bound")
	end
end)

print("[NewWorld1MapSystems] V306KBQ server active | Fast/Fastend server-owned + Fastend authored visibility preserved | physical cylinder/hammer geometry + local-player exact hitbox contact + server fallback")
