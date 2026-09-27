                                                                                                        
  
                                                                               
                                                                            
                                                                         
                                                                     

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

                                                                          
                                                                            
                                                                                  
                                                                            
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
if Config.IsNewWorld1Map == true then
	print("[TogetherController] V306KBI disabled on new World 1; zero Workspace scans")
	return
end

local TweenService = game:GetService("TweenService")

local FIND_TIMEOUT = 30
local BASE_OPEN_TIME = 2.20
local BASE_CLOSE_TIME = 2.20
local TARGET_TRAVEL_PER_OBJECT = 107
local SPEED_MULTIPLIER = 1.9539
local OPEN_HOLD = 0.70
local CLOSED_HOLD = 0.55
local EDGE_MARGIN = 2.0
local FALLBACK_TRAVEL = 16
local MAX_TRAVEL = 60
local MIN_USEFUL_TRAVEL = 1

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

local function findNamedObject(name)
	local target = normalizeName(name)
	local candidates = {}
	for _, object in ipairs(Workspace:GetDescendants()) do
		if normalizeName(object.Name) == target
			and (object:IsA("BasePart") or object:IsA("Model") or object:IsA("Folder"))
		then
			if #getPhysicalParts(object) > 0 then
				table.insert(candidates, object)
			end
		end
	end
	table.sort(candidates, function(a, b)
		local ad = objectDepth(a)
		local bd = objectDepth(b)
		if ad == bd then
			return a:GetFullName() < b:GetFullName()
		end
		return ad < bd
	end)
	return candidates[1]
end

local function waitForNamedObject(name)
	local deadline = os.clock() + FIND_TIMEOUT
	repeat
		local object = findNamedObject(name)
		if object then
			return object
		end
		task.wait(0.25)
	until os.clock() >= deadline
	return nil
end

local function getCornerScalars(parts, axis)
	local minimum = math.huge
	local maximum = -math.huge
	for _, part in ipairs(parts) do
		local half = part.Size * 0.5
		for sx = -1, 1, 2 do
			for sy = -1, 1, 2 do
				for sz = -1, 1, 2 do
					local corner = part.CFrame:PointToWorldSpace(Vector3.new(
						half.X * sx,
						half.Y * sy,
						half.Z * sz
					))
					local scalar = corner:Dot(axis)
					minimum = math.min(minimum, scalar)
					maximum = math.max(maximum, scalar)
				end
			end
		end
	end
	return minimum, maximum
end

local function getWorldBoundsCenter(parts)
	local minimum = Vector3.new(math.huge, math.huge, math.huge)
	local maximum = Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, part in ipairs(parts) do
		local half = part.Size * 0.5
		for sx = -1, 1, 2 do
			for sy = -1, 1, 2 do
				for sz = -1, 1, 2 do
					local corner = part.CFrame:PointToWorldSpace(Vector3.new(
						half.X * sx,
						half.Y * sy,
						half.Z * sz
					))
					minimum = Vector3.new(
						math.min(minimum.X, corner.X),
						math.min(minimum.Y, corner.Y),
						math.min(minimum.Z, corner.Z)
					)
					maximum = Vector3.new(
						math.max(maximum.X, corner.X),
						math.max(maximum.Y, corner.Y),
						math.max(maximum.Z, corner.Z)
					)
				end
			end
		end
	end
	return (minimum + maximum) * 0.5
end

local function captureGroup(object)
	local parts = getPhysicalParts(object)
	local originals = {}
	for _, part in ipairs(parts) do
		part.Anchored = true
		part.AssemblyLinearVelocity = Vector3.zero
		part.AssemblyAngularVelocity = Vector3.zero
		originals[part] = part.CFrame
	end
	return {
		Object = object,
		Parts = parts,
		Originals = originals,
		Center = getWorldBoundsCenter(parts),
	}
end

local function applyOffset(group, offset)
	for part, original in pairs(group.Originals) do
		if part.Parent then
			part.CFrame = original + offset
		end
	end
end

local function tweenGroups(group1, group2, offset1, offset2, startAlpha, endAlpha, duration)
	local driver = Instance.new("NumberValue")
	driver.Value = startAlpha
	local function apply(alpha)
		applyOffset(group1, offset1 * alpha)
		applyOffset(group2, offset2 * alpha)
	end
	local connection = driver:GetPropertyChangedSignal("Value"):Connect(function()
		apply(driver.Value)
	end)
	apply(startAlpha)
	local tween = TweenService:Create(
		driver,
		TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		{ Value = endAlpha }
	)
	tween:Play()
	tween.Completed:Wait()
	apply(endAlpha)
	connection:Disconnect()
	driver:Destroy()
end

local together1 = waitForNamedObject("Together1")
local together2 = waitForNamedObject("Together2")
local safeZone10 = waitForNamedObject("SafeZone10")

if not together1 or not together2 then
	warn(
		"[TogetherController] Missing Stage 10 Together object(s). Together1="
			.. tostring(together1 ~= nil)
			.. " Together2="
			.. tostring(together2 ~= nil)
	)
	return
end

local group1 = captureGroup(together1)
local group2 = captureGroup(together2)

local horizontalDifference = Vector3.new(
	group2.Center.X - group1.Center.X,
	0,
	group2.Center.Z - group1.Center.Z
)
local axis
if horizontalDifference.Magnitude > 0.05 then
	axis = horizontalDifference.Unit
elseif safeZone10 then
	local zoneParts = getPhysicalParts(safeZone10)
	if #zoneParts > 0 then
		local first = zoneParts[1]
		local right = Vector3.new(first.CFrame.RightVector.X, 0, first.CFrame.RightVector.Z)
		axis = right.Magnitude > 0.05 and right.Unit or Vector3.xAxis
	else
		axis = Vector3.xAxis
	end
else
	axis = Vector3.xAxis
end

                                                                               
if group1.Center:Dot(axis) > group2.Center:Dot(axis) then
	axis = -axis
end

local travel1 = FALLBACK_TRAVEL
local travel2 = FALLBACK_TRAVEL
if safeZone10 then
	local zoneParts = getPhysicalParts(safeZone10)
	if #zoneParts > 0 then
		local zoneMin, zoneMax = getCornerScalars(zoneParts, axis)
		local oneMin = getCornerScalars(group1.Parts, axis)
		local _, twoMax = getCornerScalars(group2.Parts, axis)

		local available1 = oneMin - (zoneMin + EDGE_MARGIN)
		local available2 = (zoneMax - EDGE_MARGIN) - twoMax
		if available1 >= MIN_USEFUL_TRAVEL then
			travel1 = math.min(available1, MAX_TRAVEL)
		end
		if available2 >= MIN_USEFUL_TRAVEL then
			travel2 = math.min(available2, MAX_TRAVEL)
		end
	end
end

                                                                        
                                                                             
                                                                             
                                                              
local referenceTravel = math.max(MIN_USEFUL_TRAVEL, (travel1 + travel2) * 0.5)
local openTime = (BASE_OPEN_TIME * (TARGET_TRAVEL_PER_OBJECT / referenceTravel)) / SPEED_MULTIPLIER
local closeTime = (BASE_CLOSE_TIME * (TARGET_TRAVEL_PER_OBJECT / referenceTravel)) / SPEED_MULTIPLIER

travel1 = TARGET_TRAVEL_PER_OBJECT
travel2 = TARGET_TRAVEL_PER_OBJECT

local openOffset1 = -axis * travel1
local openOffset2 = axis * travel2

together1:SetAttribute("TogetherControllerVersion", "V306FD")
together2:SetAttribute("TogetherControllerVersion", "V306FD")
together1:SetAttribute("TogetherOpenDistance", travel1)
together2:SetAttribute("TogetherOpenDistance", travel2)
together1:SetAttribute("TogetherOpenTime", openTime)
together2:SetAttribute("TogetherOpenTime", openTime)
together1:SetAttribute("TogetherCloseTime", closeTime)
together2:SetAttribute("TogetherCloseTime", closeTime)
together1:SetAttribute("TogetherEasing", "SineInOut")
together2:SetAttribute("TogetherEasing", "SineInOut")

                                                                  
applyOffset(group1, Vector3.zero)
applyOffset(group2, Vector3.zero)

task.wait(CLOSED_HOLD)
while together1.Parent and together2.Parent do
	tweenGroups(group1, group2, openOffset1, openOffset2, 0, 1, openTime)
	task.wait(OPEN_HOLD)
	if not together1.Parent or not together2.Parent then
		break
	end
	tweenGroups(group1, group2, openOffset1, openOffset2, 1, 0, closeTime)
	task.wait(CLOSED_HOLD)
end

print(
	string.format(
		"[TogetherController] V306FD active | exact 107-stud travel each | another 17%% faster than V306FC + same Sine smoothness | open=%.2fs close=%.2fs",
		openTime,
		closeTime
	)
)
