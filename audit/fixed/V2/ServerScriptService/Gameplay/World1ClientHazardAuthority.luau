-- V306KR World 1 authoritative validation for client-rendered moving hazards.
-- Hammer/Presser visuals no longer replicate per-frame CFrames from the server.
-- The client reports a local contact; the server validates the synchronized
-- virtual hazard pose at the reported server timestamp before killing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local hitRemote = Remotes:FindFirstChild("World1ClientHazardHit")
if not hitRemote then
	hitRemote = Instance.new("RemoteEvent")
	hitRemote.Name = "World1ClientHazardHit"
	hitRemote.Parent = Remotes
end

local MAX_TIMESTAMP_AGE = 0.75
local REQUEST_COOLDOWN = 0.035
local lastRequestAt = {}
local hazardCache = {}
local safeZones = {}

local function findNamedObject(name)
	local cached = hazardCache[name]
	if cached and cached.Parent then return cached end
	local exact = Workspace:FindFirstChild(name, true)
	if exact then hazardCache[name] = exact end
	return exact
end

local function getBounds(object)
	if object:IsA("BasePart") then return object.CFrame, object.Size end
	if object:IsA("Model") then
		local ok, cf, size = pcall(function() return object:GetBoundingBox() end)
		if ok then return cf, size end
	end
	return nil, nil
end

for i = 1, 10 do
	local zone = Workspace:FindFirstChild("SafeZone" .. tostring(i), true)
	if zone then safeZones[i] = zone end
end

local function pointInsideSafeZone(point, safeZone)
	local cf, size = getBounds(safeZone)
	if not cf or not size then return false end
	local p = cf:PointToObjectSpace(point)
	local half = size * 0.5
	return math.abs(p.X) <= half.X + 0.75
		and math.abs(p.Z) <= half.Z + 0.75
		and p.Y >= -half.Y - 2
		and p.Y <= half.Y + 12
end

local function isSafe(player, character)
	if player:GetAttribute("SafeZoneProtected") == true or character:GetAttribute("SafeZoneProtected") == true then
		return true
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return false end
	for i = 1, 10 do
		local zone = safeZones[i]
		if not zone or not zone.Parent then
			zone = Workspace:FindFirstChild("SafeZone" .. tostring(i), true)
			safeZones[i] = zone
		end
		if zone and pointInsideSafeZone(root.Position, zone) then return true end
	end
	return false
end

local function characterOverlapsBox(character, cf, size)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { character }
	params.RespectCanCollide = false
	return #Workspace:GetPartBoundsInBox(cf, size, params) > 0
end

local function hammerHitAt(hammer, character, timestamp)
	if hammer:GetAttribute("ClientMotionType") ~= "Hammer" then return false end
	local epoch = tonumber(hammer:GetAttribute("ClientMotionEpoch"))
	local pivot = hammer:GetAttribute("ClientSwingPivot")
	local axis = hammer:GetAttribute("ClientSwingAxis")
	local angle = tonumber(hammer:GetAttribute("ClientSwingAngle"))
	local halfTime = tonumber(hammer:GetAttribute("ClientHalfSwingTime"))
	local phaseOffset = tonumber(hammer:GetAttribute("ClientPhaseOffset")) or 0
	if not epoch or typeof(pivot) ~= "Vector3" or typeof(axis) ~= "Vector3" or not angle or not halfTime or halfTime <= 0 then
		return false
	end
	local phase = phaseOffset + (timestamp - epoch) * (math.pi / halfTime)
	local radians = math.rad(math.sin(phase) * angle)
	local rotation = CFrame.new(pivot) * CFrame.fromAxisAngle(axis.Unit, radians) * CFrame.new(-pivot)
	local parts = hammer:IsA("BasePart") and {hammer} or hammer:GetDescendants()
	for _, part in ipairs(parts) do
		if part:IsA("BasePart") and part:GetAttribute("ClientMotionRole") == "Moving" then
			local base = part:GetAttribute("ClientMotionBaseCFrame")
			if typeof(base) == "CFrame" and characterOverlapsBox(character, rotation * base, part.Size) then
				return true
			end
		end
	end
	return false
end

local function easeSineInOut(alpha)
	return -(math.cos(math.pi * alpha) - 1) * 0.5
end

local function presserOffsetAt(presser, timestamp)
	local epoch = tonumber(presser:GetAttribute("ClientMotionEpoch"))
	local indexOffset = tonumber(presser:GetAttribute("ClientMotionSequenceOffset")) or 0
	local lift = tonumber(presser:GetAttribute("ClientMotionLiftHeight")) or 37
	local up = tonumber(presser:GetAttribute("ClientMotionUpDuration")) or (37 / 12.5)
	local topPause = tonumber(presser:GetAttribute("ClientMotionTopPause")) or 0.37
	local down = tonumber(presser:GetAttribute("ClientMotionDownDuration")) or (37 / 270)
	local bottomPause = tonumber(presser:GetAttribute("ClientMotionBottomPause")) or 0.17
	local period = tonumber(presser:GetAttribute("ClientMotionCyclePeriod")) or (up + topPause + down + bottomPause)
	if not epoch or period <= 0 then return 0 end
	local localTime = timestamp - (epoch + indexOffset)
	if localTime <= 0 then return 0 end
	local t = localTime % period
	if t < up then
		return lift * easeSineInOut(math.clamp(t / up, 0, 1))
	elseif t < up + topPause then
		return lift
	elseif t < up + topPause + down then
		local a = (t - up - topPause) / down
		return lift * (1 - math.clamp(a, 0, 1))
	end
	return 0
end

local function presserHitAt(presser, character, timestamp)
	if presser:GetAttribute("ClientMotionType") ~= "Presser" then return false end
	local offset = presserOffsetAt(presser, timestamp)
	local parts = presser:IsA("BasePart") and {presser} or presser:GetDescendants()
	for _, part in ipairs(parts) do
		if part:IsA("BasePart") then
			local base = part:GetAttribute("ClientMotionBaseCFrame")
			if typeof(base) == "CFrame" then
				local cf = base + Vector3.new(0, offset, 0)
				if characterOverlapsBox(character, cf, part.Size) then return true end
			end
		end
	end
	return false
end

hitRemote.OnServerEvent:Connect(function(player, hazardType, hazardName, reportedTimestamp)
	local now = Workspace:GetServerTimeNow()
	local last = lastRequestAt[player] or -math.huge
	if now - last < REQUEST_COOLDOWN then return end
	lastRequestAt[player] = now

	if type(hazardName) ~= "string" or #hazardName > 32 then return end
	reportedTimestamp = tonumber(reportedTimestamp) or now
	if math.abs(now - reportedTimestamp) > MAX_TIMESTAMP_AGE then return end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 or isSafe(player, character) then return end

	local hazard = findNamedObject(hazardName)
	if not hazard then return end
	local valid = false
	if hazardType == "Hammer" and hazardName:match("^Hammer[1-5]$") then
		valid = hammerHitAt(hazard, character, reportedTimestamp)
	elseif hazardType == "Presser" and hazardName:match("^Presser[1-5]$") then
		valid = presserHitAt(hazard, character, reportedTimestamp)
	end
	if valid then humanoid.Health = 0 end
end)

Players.PlayerRemoving:Connect(function(player)
	lastRequestAt[player] = nil
end)

print("[World1ClientHazardAuthority] V306KR ready | Hammer/Presser contact validated from synchronized virtual poses")
