                                                                 
  
                                                                           
                                                                             
                                                                               
                                                                                  

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
if Config.IsNewWorld1Map == true then
	return
end

local OBJECT_NAMES = { "UpDown1", "UpDown2", "UpDown3" }
local FIND_TIMEOUT = 25
local MIN_DOWN_DISTANCE = 14
local MAX_DOWN_DISTANCE = 28
local EXTRA_CLEARANCE = 4
local MIN_TRAVEL_TIME = 1.85
local MAX_TRAVEL_TIME = 2.55
local MIN_TOP_HOLD = 0.35
local MAX_TOP_HOLD = 1.35
local MIN_BOTTOM_HOLD = 0.30
local MAX_BOTTOM_HOLD = 1.15
local MAX_INITIAL_STAGGER = 2.75

local function normalizeName(value)
	return tostring(value or ""):lower():gsub("[^%w]", "")
end

local function findMapObject(name)
	local target = normalizeName(name)
	local best = nil
	for _, object in ipairs(Workspace:GetDescendants()) do
		if normalizeName(object.Name) == target
			and (object:IsA("BasePart") or object:IsA("Model"))
		then
			if not best or object:GetFullName() < best:GetFullName() then
				best = object
			end
		end
	end
	return best
end

local function waitForMapObject(name)
	local deadline = os.clock() + FIND_TIMEOUT
	repeat
		local object = findMapObject(name)
		if object then
			return object
		end
		task.wait(0.25)
	until os.clock() >= deadline
	return nil
end

local function getPivotAndSize(object)
	if object:IsA("BasePart") then
		return object.CFrame, object.Size
	end
	local ok, cf, size = pcall(function()
		return object:GetBoundingBox()
	end)
	if ok then
		return cf, size
	end
	return object:GetPivot(), Vector3.new(1, MIN_DOWN_DISTANCE, 1)
end

local function anchorObject(object)
	if object:IsA("BasePart") then
		object.Anchored = true
		object.AssemblyLinearVelocity = Vector3.zero
		object.AssemblyAngularVelocity = Vector3.zero
		return
	end
	for _, descendant in ipairs(object:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.AssemblyLinearVelocity = Vector3.zero
			descendant.AssemblyAngularVelocity = Vector3.zero
		end
	end
end

local function setPivot(object, cf)
	if object:IsA("BasePart") then
		object.CFrame = cf
	else
		object:PivotTo(cf)
	end
end

local function tweenPivot(object, fromCFrame, toCFrame, duration)
	if not object.Parent then
		return false
	end

	if object:IsA("BasePart") then
		local tween = TweenService:Create(
			object,
			TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
			{ CFrame = toCFrame }
		)
		tween:Play()
		tween.Completed:Wait()
		return object.Parent ~= nil
	end

	local driver = Instance.new("CFrameValue")
	driver.Value = fromCFrame
	local connection = driver:GetPropertyChangedSignal("Value"):Connect(function()
		if object.Parent then
			object:PivotTo(driver.Value)
		end
	end)
	local tween = TweenService:Create(
		driver,
		TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		{ Value = toCFrame }
	)
	tween:Play()
	tween.Completed:Wait()
	connection:Disconnect()
	driver:Destroy()
	if object.Parent then
		object:PivotTo(toCFrame)
		return true
	end
	return false
end

local function runObstacle(name, index)
	local object = waitForMapObject(name)
	if not object then
		warn("[UpDownController] Missing Workspace object: " .. name)
		return
	end

	anchorObject(object)
	local topCFrame, size = getPivotAndSize(object)
	local authoredDownDistance = tonumber(object:GetAttribute("UpDownDistance"))
	local downDistance = authoredDownDistance
		or math.clamp(size.Y + EXTRA_CLEARANCE, MIN_DOWN_DISTANCE, MAX_DOWN_DISTANCE)
	local bottomCFrame = topCFrame - Vector3.new(0, downDistance, 0)

	object:SetAttribute("UpDownOriginalCFrame", topCFrame)
	object:SetAttribute("UpDownDistance", downDistance)
	object:SetAttribute("UpDownControllerVersion", "V306EQ")

	local random = Random.new(306000 + index * 7919 + math.floor(os.clock() * 1000) % 100000)
	task.wait(random:NextNumber(0, MAX_INITIAL_STAGGER))

	while object.Parent do
		                                                     
		setPivot(object, topCFrame)
		task.wait(random:NextNumber(MIN_TOP_HOLD, MAX_TOP_HOLD))

		local downTime = random:NextNumber(MIN_TRAVEL_TIME, MAX_TRAVEL_TIME)
		if not tweenPivot(object, topCFrame, bottomCFrame, downTime) then
			break
		end
		task.wait(random:NextNumber(MIN_BOTTOM_HOLD, MAX_BOTTOM_HOLD))

		local upTime = random:NextNumber(MIN_TRAVEL_TIME, MAX_TRAVEL_TIME)
		if not tweenPivot(object, bottomCFrame, topCFrame, upTime) then
			break
		end
	end
end

for index, name in ipairs(OBJECT_NAMES) do
	task.spawn(runObstacle, name, index)
end

print("[UpDownController] V306EQ active | UpDown1/2/3 independent smooth randomized vertical cycles")
