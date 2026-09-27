-- V306KR World 1 client-side moving obstacle renderer.
-- Hammers, Presser1-5 and UpDown1-3 render locally from synchronized server
-- timestamps. This removes continuous server CFrame replication while keeping
-- the same authored geometry and motion timing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local hitRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("World1ClientHazardHit")

local runtime = Workspace:FindFirstChild("World1ClientMotion_Runtime")
if runtime then runtime:Destroy() end
runtime = Instance.new("Folder")
runtime.Name = "World1ClientMotion_Runtime"
runtime.Parent = Workspace

local hammerStates = {}
local presserStates = {}
local upDownStates = {}
local sourceConnections = {}
local localHitDebounceUntil = 0
local collisionAccumulator = 0

local function allParts(object)
	local result = {}
	if object:IsA("BasePart") then table.insert(result, object) end
	for _, d in ipairs(object:GetDescendants()) do
		if d:IsA("BasePart") then table.insert(result, d) end
	end
	return result
end

local function getObjectPivot(object)
	if object:IsA("Model") then return object:GetPivot() end
	if object:IsA("BasePart") then return object.CFrame end
	local first = object:FindFirstChildWhichIsA("BasePart", true)
	return first and first.CFrame or nil
end

local function setObjectPivot(object, cf)
	if object:IsA("Model") then
		object:PivotTo(cf)
	elseif object:IsA("BasePart") then
		object.CFrame = cf
	else
		local current = getObjectPivot(object)
		if not current then return end
		local delta = cf * current:Inverse()
		for _, p in ipairs(allParts(object)) do p.CFrame = delta * p.CFrame end
	end
end

local function hideSource(source)
	for _, part in ipairs(allParts(source)) do
		part.LocalTransparencyModifier = 1
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
	end
end

local function restoreClonePart(part)
	part.LocalTransparencyModifier = 0
	part.Anchored = true
	local originalCollide = part:GetAttribute("ClientMotionOriginalCanCollide")
	local originalTouch = part:GetAttribute("ClientMotionOriginalCanTouch")
	local originalQuery = part:GetAttribute("ClientMotionOriginalCanQuery")
	part.CanCollide = originalCollide == true
	part.CanTouch = originalTouch == true
	part.CanQuery = originalQuery ~= false
	part.AssemblyLinearVelocity = Vector3.zero
	part.AssemblyAngularVelocity = Vector3.zero
end

local function cloneVisual(source)
	source.Archivable = true
	local clone = source:Clone()
	clone.Name = source.Name .. "_ClientVisual"
	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("Script") or d:IsA("LocalScript") then d:Destroy() end
	end
	if clone:IsA("BasePart") then restoreClonePart(clone) end
	for _, p in ipairs(allParts(clone)) do restoreClonePart(p) end
	clone.Parent = runtime
	hideSource(source)
	return clone
end

local function findExact(name)
	local found = Workspace:FindFirstChild(name, true)
	if found and found:IsDescendantOf(runtime) then return nil end
	return found
end

local function easeSineInOut(alpha)
	return -(math.cos(math.pi * alpha) - 1) * 0.5
end

local safeZoneCache = {}
local function objectBounds(object)
	if object:IsA("BasePart") then return object.CFrame, object.Size end
	if object:IsA("Model") then
		local ok, cf, size = pcall(function() return object:GetBoundingBox() end)
		if ok then return cf, size end
	end
	return nil, nil
end
local function isSafeLocally(character)
	if player:GetAttribute("SafeZoneProtected") == true or character:GetAttribute("SafeZoneProtected") == true then
		return true
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return false end
	for i=1,10 do
		local zone=safeZoneCache[i]
		if not zone or not zone.Parent then zone=Workspace:FindFirstChild("SafeZone"..i,true); safeZoneCache[i]=zone end
		if zone then
			local cf,size=objectBounds(zone)
			if cf and size then
				local q=cf:PointToObjectSpace(root.Position); local half=size*0.5
				if math.abs(q.X)<=half.X+0.75 and math.abs(q.Z)<=half.Z+0.75 and q.Y>=-half.Y-2 and q.Y<=half.Y+12 then return true end
			end
		end
	end
	return false
end

local function setupHammer(source)
	if source:GetAttribute("ClientMotionType") ~= "Hammer" then return end
	local clone = cloneVisual(source)
	for _, p in ipairs(allParts(clone)) do p.CanQuery = true end
	local moving = {}
	local firstMoving
	for _, p in ipairs(allParts(clone)) do
		if p:GetAttribute("ClientMotionRole") == "Moving" then
			local base = p:GetAttribute("ClientMotionBaseCFrame")
			if typeof(base) == "CFrame" then
				table.insert(moving, { part = p, base = base, previous = p.CFrame })
				firstMoving = firstMoving or p
			end
		end
	end
	local sound
	if firstMoving then
		sound = Instance.new("Sound")
		sound.Name = "VortexHammerWhoosh"
		sound.SoundId = tostring(source:GetAttribute("ClientWhooshSoundId") or "rbxassetid://138158731526545")
		sound.Volume = tonumber(source:GetAttribute("ClientWhooshVolume")) or 2.6
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
		sound.RollOffMinDistance = 8
		sound.RollOffMaxDistance = 85
		sound.Parent = firstMoving
	end
	local phaseOffset = tonumber(source:GetAttribute("ClientPhaseOffset")) or 0
	table.insert(hammerStates, {
		source = source, clone = clone, moving = moving,
		epoch = tonumber(source:GetAttribute("ClientMotionEpoch")) or Workspace:GetServerTimeNow(),
		pivot = source:GetAttribute("ClientSwingPivot"), axis = source:GetAttribute("ClientSwingAxis"),
		angle = tonumber(source:GetAttribute("ClientSwingAngle")) or 55,
		halfTime = tonumber(source:GetAttribute("ClientHalfSwingTime")) or 1.2,
		phaseOffset = phaseOffset, lastCrossing = math.floor(phaseOffset / math.pi), sound = sound,
	})
end

local function setupPresser(source)
	if source:GetAttribute("ClientMotionType") ~= "Presser" then return end
	local clone = cloneVisual(source)
	for _, p in ipairs(allParts(clone)) do p.CanQuery = true end
	local bottom = source:GetAttribute("ClientMotionBottomPivot")
	if typeof(bottom) ~= "CFrame" then bottom = getObjectPivot(source) end
	local soundParent = allParts(clone)[1]
	if soundParent then
		local sound = Instance.new("Sound")
		sound.Name = "PresserNearSound"
		sound.SoundId = "rbxassetid://109100548085585"
		sound.Volume = 0.82
		sound.Looped = true
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
		sound.RollOffMinDistance = 8
		sound.RollOffMaxDistance = 65
		sound.EmitterSize = 5
		sound.Parent = soundParent
		sound:Play()
	end
	local trackedParts = {}
	for _, p in ipairs(allParts(clone)) do table.insert(trackedParts, {part=p, previous=p.CFrame}) end
	table.insert(presserStates, {
		source=source, clone=clone, bottom=bottom, parts=trackedParts,
		epoch=tonumber(source:GetAttribute("ClientMotionEpoch")) or Workspace:GetServerTimeNow(),
		offset=tonumber(source:GetAttribute("ClientMotionSequenceOffset")) or 0,
		lift=tonumber(source:GetAttribute("ClientMotionLiftHeight")) or 37,
		up=tonumber(source:GetAttribute("ClientMotionUpDuration")) or (37/12.5),
		topPause=tonumber(source:GetAttribute("ClientMotionTopPause")) or 0.37,
		down=tonumber(source:GetAttribute("ClientMotionDownDuration")) or (37/270),
		bottomPause=tonumber(source:GetAttribute("ClientMotionBottomPause")) or 0.17,
		period=tonumber(source:GetAttribute("ClientMotionCyclePeriod")) or ((37/12.5)+0.37+(37/270)+0.17),
	})
end

local function setupUpDown(source)
	if source:GetAttribute("ClientMotionType") ~= "UpDown" then return end
	local clone = cloneVisual(source)
	local top = source:GetAttribute("ClientMotionTopPivot")
	local bottom = source:GetAttribute("ClientMotionBottomPivot")
	if typeof(top) ~= "CFrame" or typeof(bottom) ~= "CFrame" then return end
	table.insert(upDownStates, {
		source=source, clone=clone, top=top, bottom=bottom,
		epoch=tonumber(source:GetAttribute("ClientMotionEpoch")) or Workspace:GetServerTimeNow(),
		initial=tonumber(source:GetAttribute("ClientMotionInitialDelay")) or 0,
		topHold=tonumber(source:GetAttribute("ClientMotionTopHold")) or 0.5,
		down=tonumber(source:GetAttribute("ClientMotionDownDuration")) or 2.2,
		bottomHold=tonumber(source:GetAttribute("ClientMotionBottomHold")) or 0.5,
		up=tonumber(source:GetAttribute("ClientMotionUpDuration")) or 2.2,
		period=tonumber(source:GetAttribute("ClientMotionCyclePeriod")) or 5.4,
	})
end

local function waitConfigured(name, motionType, timeout)
	local deadline = os.clock() + (timeout or 15)
	repeat
		local source = findExact(name)
		if source and source:GetAttribute("ClientMotionType") == motionType then return source end
		task.wait(0.1)
	until os.clock() >= deadline
	return nil
end

for i=1,5 do
	task.spawn(function()
		local source = waitConfigured("Hammer"..i, "Hammer", 20)
		if source then setupHammer(source) end
	end)
	task.spawn(function()
		local source = waitConfigured("Presser"..i, "Presser", 20)
		if source then setupPresser(source) end
	end)
end
for i=1,3 do
	task.spawn(function()
		local source = waitConfigured("UpDown"..i, "UpDown", 30)
		if source then setupUpDown(source) end
	end)
end

local function presserHeight(state, now)
	local localTime = now - (state.epoch + state.offset)
	if localTime <= 0 then return 0 end
	local t = localTime % state.period
	if t < state.up then return state.lift * easeSineInOut(math.clamp(t/state.up,0,1)) end
	if t < state.up + state.topPause then return state.lift end
	if t < state.up + state.topPause + state.down then
		local a=(t-state.up-state.topPause)/state.down
		return state.lift*(1-math.clamp(a,0,1))
	end
	return 0
end

local function upDownPivot(state, now)
	local localTime = now - (state.epoch + state.initial)
	if localTime <= 0 then return state.top end
	local t = localTime % state.period
	if t < state.topHold then return state.top end
	t -= state.topHold
	if t < state.down then return state.top:Lerp(state.bottom, easeSineInOut(math.clamp(t/state.down,0,1))) end
	t -= state.down
	if t < state.bottomHold then return state.bottom end
	t -= state.bottomHold
	return state.bottom:Lerp(state.top, easeSineInOut(math.clamp(t/state.up,0,1)))
end

local function reportContact(kind, name, now)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 or isSafeLocally(character) then return end
	if os.clock() < localHitDebounceUntil then return end
	localHitDebounceUntil = os.clock() + 0.35
	hitRemote:FireServer(kind, name, now)
	-- Immediate local feedback; server independently validates the contact.
	humanoid.Health = 0
end

local function partTouchesCharacter(part, character, params)
	if not part.Parent then return false end
	return #Workspace:GetPartsInPart(part, params) > 0
end

RunService.RenderStepped:Connect(function(dt)
	local now = Workspace:GetServerTimeNow()
	for _, state in ipairs(hammerStates) do
		if state.clone.Parent and typeof(state.pivot)=="Vector3" and typeof(state.axis)=="Vector3" then
			local phase = state.phaseOffset + (now-state.epoch)*(math.pi/state.halfTime)
			local rotation = CFrame.new(state.pivot) * CFrame.fromAxisAngle(state.axis.Unit, math.rad(math.sin(phase)*state.angle)) * CFrame.new(-state.pivot)
			for _, item in ipairs(state.moving) do
				item.part.CFrame = rotation * item.base
			end
			local crossing=math.floor(phase/math.pi)
			if crossing~=state.lastCrossing then
				state.lastCrossing=crossing
				if state.sound then state.sound:Stop(); state.sound.TimePosition=0; state.sound:Play() end
			end
		end
	end
	for _, state in ipairs(presserStates) do
		if state.clone.Parent and state.bottom then
			setObjectPivot(state.clone, state.bottom + Vector3.new(0,presserHeight(state,now),0))
		end
	end
	for _, state in ipairs(upDownStates) do
		if state.clone.Parent then setObjectPivot(state.clone, upDownPivot(state,now)) end
	end

	collisionAccumulator += dt
	if collisionAccumulator < 1/30 then return end
	collisionAccumulator = 0
	local character=player.Character
	local humanoid=character and character:FindFirstChildOfClass("Humanoid")
	local root=character and character:FindFirstChild("HumanoidRootPart")
	if not character or not humanoid or humanoid.Health<=0 or not root then return end
	local params=OverlapParams.new()
	params.FilterType=Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances={character}
	params.RespectCanCollide=false
	for i,state in ipairs(hammerStates) do
		if state.clone.Parent then
			for _,item in ipairs(state.moving) do
				if (item.part.Position-root.Position).Magnitude < 110 and partTouchesCharacter(item.part,character,params) then
					reportContact("Hammer",state.source.Name,now); return
				end
			end
		end
	end
	for _,state in ipairs(presserStates) do
		if state.clone.Parent then
			for _,item in ipairs(state.parts) do
				local part=item.part
				if (part.Position-root.Position).Magnitude < 90 then
					if partTouchesCharacter(part,character,params) then reportContact("Presser",state.source.Name,now); return end
					-- Swept translation catches the accepted 270 studs/s down stroke.
					local prev=item.previous or part.CFrame
					local current=part.CFrame
					local delta=current.Position-prev.Position
					if delta.Magnitude>0.05 then
						local localDelta=current:VectorToObjectSpace(delta)
						local sweptSize=part.Size+Vector3.new(math.abs(localDelta.X),math.abs(localDelta.Y),math.abs(localDelta.Z))
						local mid=(current.Position+prev.Position)*0.5
						local swept=CFrame.new(mid)*(current-current.Position)
						if #Workspace:GetPartBoundsInBox(swept,sweptSize,params)>0 then reportContact("Presser",state.source.Name,now); return end
					end
				end
				item.previous=part.CFrame
			end
		end
	end
end)

print("[World1ClientMotion] V306KR ready | Hammer1-5 + Presser1-5 + UpDown1-3 rendered locally from server time")
