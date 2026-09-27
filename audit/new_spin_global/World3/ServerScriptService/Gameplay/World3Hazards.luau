-- World3Hazards.server.luau
-- The traps of World 3 (Desert), server side.
--
--   Cactus      Stage 1. Touching a cactus with the body kills.
--   Quicksand   Stage 5. Standing on quicksand for 2.5 seconds kills. The count pauses in
--               the air (no hopping in place) and resets on anything that is not
--               quicksand: the logs, bridges, buttons and hay are the way across.
--   Void        Every stage. Falling below 25 studs under the stage's lowest floor kills,
--               so a fall always ends in a death and the revive prompt, never on the
--               Baseplate or somewhere unreachable.
--   Moving      Tumbleweeds (2), roadrunners (3), carts (7), the serpent (8) and the
--               scorpions (9) move on every client from Shared.World3HazardMotion and a
--               shared start time; a client that sees its own character hit reports it,
--               and the server kills that player if they really are where that hazard
--               runs. The report can only ever kill its sender, as with World 2's tree
--               slammers. The serpent and the scorpions wear the modeller's Snake and
--               Scorpion (ServerStorage.World3HazardTemplates, handed to the clients here).
--   Collapsing  Stages 6 and 10. The flat platforms are tagged here with their timing (0.6 s
--               shake / 3 s back on Stage 6, 0.7 s / 3.5 s on Stage 10); each client shakes
--               and drops them under its own feet (World3HazardsClient).
--   Lasers      Stage 10. The red laser bars go round off, warning and on
--               (Shared.World3HazardMotion.Laser, the clients' clock); only while on does
--               touching one, or standing in it when it comes on, kill. They are beams, not
--               walls: nothing bumps into them.
--   Void        Stage 10's "Void" parts kill on touch, besides the height below (Stage 10's
--               is just under its route, World3HazardLayout.Stage10VoidBelowCheckpoint).
--
-- Every death is an ordinary Humanoid death, so the revive offer follows as usual.

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
if Config.IsWorld3Place ~= true then
	return
end

local StageTeleport = require(script.Parent:WaitForChild("World3StageTeleportService"))
local Layout = require(script.Parent:WaitForChild("World3HazardLayout"))
local Motion = require(Shared:WaitForChild("World3HazardMotion"))

local QUICKSAND_SECONDS = 2.5
local QUICKSAND_PROBE = 4.5
local STEP_SECONDS = 0.1
local SELF_HIT_COOLDOWN = 0.15
local LAYOUT_FOLDER_NAME = "World3HazardLayout"
local REMOTE_NAME = "World3HazardSelfHit"
local SINK_ATTRIBUTE = "World3QuicksandSink"
local COLLAPSE_ATTRIBUTE = "World3CollapsePlatform"
local COLLAPSE_SHAKE_ATTRIBUTE = "World3CollapseShake"
local COLLAPSE_BACK_ATTRIBUTE = "World3CollapseBack"
local LASER_TAG = "World3Laser"
local LASER_ATTRIBUTE = "World3LaserIndex"
local VERSION = "W3Hazards2"

local BODY_PARTS = {
	Head = true, Torso = true, UpperTorso = true, LowerTorso = true,
	["Left Arm"] = true, ["Right Arm"] = true, ["Left Leg"] = true, ["Right Leg"] = true,
	LeftUpperArm = true, LeftLowerArm = true, LeftHand = true, RightUpperArm = true, RightLowerArm = true, RightHand = true,
	LeftUpperLeg = true, LeftLowerLeg = true, LeftFoot = true, RightUpperLeg = true, RightLowerLeg = true, RightFoot = true,
}

local Service = {}

local templates = ServerStorage:FindFirstChild("World3HazardTemplates")
local layout = Layout.Read(Workspace, StageTeleport, templates)
Service.Layout = layout
for _, problem in layout.Problems do
	warn("[World3Hazards] " .. problem)
end

----------------------------------------------------------------------
-- What the clients need
----------------------------------------------------------------------
local folder = ReplicatedStorage:FindFirstChild(LAYOUT_FOLDER_NAME)
if not folder then
	folder = Instance.new("Folder")
	folder.Name = LAYOUT_FOLDER_NAME
	folder.Parent = ReplicatedStorage
end
-- The map's tumbleweed and wagons become the look of the moving ones.
if layout.Templates.Tumbleweed then
	layout.Templates.Tumbleweed.Name = "Tumbleweed"
	layout.Templates.Tumbleweed.Parent = folder
end
for index, wagon in layout.Templates.Wagons or {} do
	wagon.Name = if index == 1 then "Cart" else "SpareWagon" .. index
	wagon.Parent = folder
end
-- The modeller's Snake and Scorpion become the serpent's and the scorpions' look.
for _, name in { "Snake", "Scorpion" } do
	local template = templates and templates:FindFirstChild(name)
	if template then
		template:Clone().Parent = folder
	else
		warn("[World3Hazards] No " .. name .. " template in ServerStorage.World3HazardTemplates")
	end
end
for index, part in layout.CollapseParts do
	local timing = Layout.Collapse[layout.CollapseStages[part] or 6] or Layout.Collapse[6]
	part:SetAttribute(COLLAPSE_ATTRIBUTE, index)
	part:SetAttribute(COLLAPSE_SHAKE_ATTRIBUTE, timing.Shake)
	part:SetAttribute(COLLAPSE_BACK_ATTRIBUTE, timing.Back)
end
for stage, height in layout.VoidPlanes do
	folder:SetAttribute("VoidPlane" .. stage, height)
end
-- The lasers: numbered and tagged for the clients (who draw their cycle), and passable.
for index, part in layout.LaserParts do
	part.CanCollide = false
	part:SetAttribute(LASER_ATTRIBUTE, index)
	CollectionService:AddTag(part, LASER_TAG)
end
local epoch = Workspace:GetServerTimeNow()
folder:SetAttribute("Layout", HttpService:JSONEncode(layout.Client))
folder:SetAttribute("Epoch", epoch)
folder:SetAttribute("Version", VERSION)

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end
local selfHit = remotes:FindFirstChild(REMOTE_NAME)
if not selfHit then
	selfHit = Instance.new("RemoteEvent")
	selfHit.Name = REMOTE_NAME
	selfHit.Parent = remotes
end

----------------------------------------------------------------------
-- Killing
----------------------------------------------------------------------
-- Just teleported, reviving or standing in a safe zone: hazards wait.
local function isProtected(player, character)
	return player:GetAttribute("StageTeleportInvulnerable") == true
		or player:GetAttribute("SafeZoneProtected") == true
		or character:GetAttribute("SafeZoneProtected") == true
		or os.clock() < (tonumber(player:GetAttribute("StageTeleportArrivalGraceUntil")) or 0)
end

local function living(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root then
		return nil
	end
	return character, humanoid, root
end

local function kill(player, humanoid, cause)
	player:SetAttribute("World3LastHazard", cause)
	humanoid.Health = 0
end

local function inside(box, position)
	return box ~= nil
		and position.X >= box.MinX and position.X <= box.MaxX
		and position.Y >= box.MinY and position.Y <= box.MaxY
		and position.Z >= box.MinZ and position.Z <= box.MaxZ
end

----------------------------------------------------------------------
-- Cactus (Stage 1), lasers and void (Stage 10): deadly to touch
----------------------------------------------------------------------
-- Only a player's own body parts count, and the connections belong to the map's parts, so
-- nothing is left behind when a player leaves.
local function deadlyTouch(cause)
	return function(hit)
		local character = hit and hit.Parent
		if not character or not hit:IsA("BasePart") or not BODY_PARTS[hit.Name] then
			return
		end
		local player = Players:GetPlayerFromCharacter(character)
		if not player then
			return
		end
		local _, humanoid = living(player)
		if humanoid and not isProtected(player, character) then
			kill(player, humanoid, cause)
		end
	end
end
Service.OnCactusTouched = deadlyTouch("Cactus")
Service.OnVoidTouched = deadlyTouch("Void")
local laserTouched = deadlyTouch("Laser")
-- A laser kills only while it is on.
function Service.OnLaserTouched(index, hit)
	if Motion.LaserDeadly(index, Workspace:GetServerTimeNow() - epoch) then
		laserTouched(hit)
	end
end
for _, part in layout.CactusParts do
	part.Touched:Connect(Service.OnCactusTouched)
end
for index, part in layout.LaserParts do
	part.Touched:Connect(function(hit)
		Service.OnLaserTouched(index, hit)
	end)
end
for _, part in layout.VoidParts do
	part.Touched:Connect(Service.OnVoidTouched)
end

-- Collapsing platforms: tag them so clients watch, shake, and drop them underfoot
for index, part in layout.CollapseParts do
	local stage = layout.CollapseStages[part] or 10
	local collapse = Layout.Collapse[stage] or { Shake = 0.7, Back = 3.5 }
	part:SetAttribute(COLLAPSE_ATTRIBUTE, index)
	part:SetAttribute(COLLAPSE_SHAKE_ATTRIBUTE, collapse.Shake)
	part:SetAttribute(COLLAPSE_BACK_ATTRIBUTE, collapse.Back)
end

-- Lasers: tag them so clients draw rotation, warning flicker, and on-state
for index, part in layout.LaserParts do
	part.CanCollide = false
	CollectionService:AddTag(part, LASER_TAG)
	part:SetAttribute(LASER_ATTRIBUTE, index)
end

-- Stage 10 fixes:
-- 1. Smooth out the broken decorative wooden bridge (53 jagged, tilted planks that block/fling players)
local stage10 = Workspace:FindFirstChild("Stage 10")
if stage10 then
	local decor = stage10:FindFirstChild("Decor")
	if decor then
		for _, part in decor:GetDescendants() do
			if part:IsA("BasePart") then
				local pos = part.CFrame.Position
				if pos.Z > -7025 and pos.Z < -6960 and pos.X > 170 and pos.X < 240 and pos.Y > 115 and pos.Y < 132 and part.Size.Z < 40 then
					part.CanCollide = false
				end
			end
		end
	end
	local walkway = stage10:FindFirstChild("Stage10BridgeWalkway")
	if not walkway then
		walkway = Instance.new("Part")
		walkway.Name = "Stage10BridgeWalkway"
		walkway.Anchored = true
		walkway.CanCollide = true
		walkway.CanTouch = false
		walkway.CanQuery = false
		walkway.CastShadow = false
		walkway.Transparency = 1
		walkway.Size = Vector3.new(16, 1.5, 92)
		local pStart = Vector3.new(170.4, 120.2, -6960)
		local pEnd = Vector3.new(237.0, 121.1, -7020)
		local pCenter = (pStart + pEnd) / 2
		walkway.CFrame = CFrame.lookAt(pCenter, pEnd)
		walkway.Parent = stage10
	end

	-- 2. Ensure backward conveyor pushes stably
	local actionParts = stage10:FindFirstChild("Action Parts")
	local conveyorModel = actionParts and actionParts:FindFirstChild("Model")
	local conveyorPart = conveyorModel and conveyorModel:FindFirstChild("Conveyor")
	if conveyorPart and conveyorPart:IsA("BasePart") then
		conveyorPart.AssemblyLinearVelocity = conveyorPart.CFrame.LookVector * 65
	end
end

----------------------------------------------------------------------
-- Moving hazards: a client reports its own character hit
----------------------------------------------------------------------
local lastSelfHitAt = {}

local function hazardExists(kind, index)
	if type(index) ~= "number" or index ~= index or index % 1 ~= 0 or index < 1 then
		return false
	end
	local client = layout.Client
	if kind == "Tumbleweed" then
		return client.Tumbleweeds[index] ~= nil
	elseif kind == "Roadrunner" then
		return client.Roadrunners[index] ~= nil
	elseif kind == "Cart" then
		return client.Carts[index] ~= nil
	elseif kind == "Serpent" then
		return client.Serpent ~= nil and index == 1
	elseif kind == "Scorpion" then
		return client.Scorpions[index] ~= nil
	end
	return false
end

function Service.OnSelfHit(player, kind, index)
	if type(kind) ~= "string" or not hazardExists(kind, index) then
		return
	end
	local now = os.clock()
	if now - (lastSelfHitAt[player] or -math.huge) < SELF_HIT_COOLDOWN then
		return
	end
	lastSelfHitAt[player] = now
	local character, humanoid, root = living(player)
	if not character or isProtected(player, character) then
		return
	end
	if kind == "Serpent" and Motion.InDugout(layout.Client.Serpent, root.Position) then
		return
	end
	if inside(layout.Regions[kind], root.Position) then
		kill(player, humanoid, kind)
	end
end
selfHit.OnServerEvent:Connect(Service.OnSelfHit)

----------------------------------------------------------------------
-- Void and quicksand, ten times a second
----------------------------------------------------------------------
local quicksand = {}
local quicksandBox = nil
for _, part in layout.QuicksandParts do
	quicksand[part] = true
end
if #layout.QuicksandParts > 0 then
	local merged = nil
	for _, part in layout.QuicksandParts do
		local box = Layout.BoundsOf(part)
		merged = if merged
			then { MinX = math.min(merged.MinX, box.MinX), MinY = math.min(merged.MinY, box.MinY), MinZ = math.min(merged.MinZ, box.MinZ), MaxX = math.max(merged.MaxX, box.MaxX), MaxY = math.max(merged.MaxY, box.MaxY), MaxZ = math.max(merged.MaxZ, box.MaxZ) }
			else box
	end
	quicksandBox = { MinX = merged.MinX - 5, MinY = merged.MinY - 5, MinZ = merged.MinZ - 5, MaxX = merged.MaxX + 5, MaxY = merged.MaxY + 12, MaxZ = merged.MaxZ + 5 }
end

local sunk = {}
local shownSink = {}
local probe = RaycastParams.new()
probe.FilterType = Enum.RaycastFilterType.Exclude

local function showSink(player, share)
	share = math.clamp(share, 0, 1)
	local shown = shownSink[player] or 0
	if (share == 0) ~= (shown == 0) or math.abs(share - shown) >= 0.05 then
		shownSink[player] = share
		player:SetAttribute(SINK_ATTRIBUTE, share)
	end
end

-- The lasers that are on right now (a body standing in a beam when it comes on dies too).
local function liveLasers()
	local live = nil
	local elapsed = Workspace:GetServerTimeNow() - epoch
	for index, box in layout.LaserBoxes do
		if Motion.LaserDeadly(index, elapsed) then
			live = live or {}
			table.insert(live, box)
		end
	end
	return live
end

local initialLaserFrames = {}
local function getLaserInitial(part)
	local cf = initialLaserFrames[part]
	if not cf then
		pcall(function() cf = part.CFrame end)
		cf = cf or CFrame.new()
		initialLaserFrames[part] = cf
	end
	return cf
end

local function updateServerLasers(elapsed)
	for index, part in layout.LaserParts do
		if part and part.Parent then
			pcall(function()
				local home = getLaserInitial(part)
				local center = home.Position
				local dir = if index == 1 then 1 else -1
				local angle = (elapsed * 1.2 * dir) % (math.pi * 2)
				part.CFrame = CFrame.new(center) * CFrame.Angles(0, angle, 0) * (CFrame.new(center):Inverse() * home)
			end)
		end
	end
end

local function inLaser(live, position)
	for _, box in live or {} do
		if Motion.LaserTouches(box, position) then
			return true
		end
	end
	return false
end

function Service.Step(dt)
	local elapsed = Workspace:GetServerTimeNow() - epoch
	updateServerLasers(elapsed)
	local live = liveLasers()
	-- Check rotating laser overlap
	for index, part in layout.LaserParts do
		if part and part.Parent and Motion.LaserDeadly(index, elapsed) then
			pcall(function()
				for _, hit in Workspace:GetPartsInPart(part) do
					if hit:IsA("BasePart") and BODY_PARTS[hit.Name] then
						local character = hit.Parent
						local player = character and Players:GetPlayerFromCharacter(character)
						local humanoid = character and character:FindFirstChildOfClass("Humanoid")
						if player and humanoid and not isProtected(player, character) then
							kill(player, humanoid, "Laser")
						end
					end
				end
			end)
		end
	end
	for _, player in Players:GetPlayers() do
		local character, humanoid, root = living(player)
		if character and not isProtected(player, character) then
			local position = root.Position
			local stage = StageTeleport.GetNearestStage(position)
			local plane = stage and layout.VoidPlanes[stage]
			if plane and position.Y < plane then
				sunk[player] = nil
				showSink(player, 0)
				kill(player, humanoid, "Void")
			elseif inLaser(live, position) then
				kill(player, humanoid, "Laser")
			elseif inside(quicksandBox, position) then
				probe.FilterDescendantsInstances = { character }
				local result = Workspace:Raycast(position, Vector3.new(0, -QUICKSAND_PROBE, 0), probe)
				local seconds = sunk[player] or 0
				if result and quicksand[result.Instance] then
					seconds += dt
				elseif result then
					seconds = 0
				end
				sunk[player] = seconds
				showSink(player, seconds / QUICKSAND_SECONDS)
				if seconds >= QUICKSAND_SECONDS then
					sunk[player] = nil
					showSink(player, 0)
					kill(player, humanoid, "Quicksand")
				end
			elseif sunk[player] then
				sunk[player] = nil
				showSink(player, 0)
			end
		elseif sunk[player] then
			sunk[player] = nil
			showSink(player, 0)
		end
	end
end

local waited = 0
RunService.Heartbeat:Connect(function(dt)
	waited += dt
	if waited >= STEP_SECONDS then
		Service.Step(waited)
		waited = 0
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastSelfHitAt[player] = nil
	sunk[player] = nil
	shownSink[player] = nil
end)

-- Performance: ensure all static map parts in Workspace are anchored to prevent physics solver load
for _, part in ipairs(Workspace:GetDescendants()) do
	if part:IsA("BasePart") and not part.Anchored then
		local isPlayerDescendant = false
		for _, pl in ipairs(Players:GetPlayers()) do
			if pl.Character and part:IsDescendantOf(pl.Character) then
				isPlayerDescendant = true
				break
			end
		end
		if not isPlayerDescendant then
			part.Anchored = true
		end
	end
end

local planes = {}
for stage = 1, StageTeleport.StageCount do
	table.insert(planes, string.format("%d:%.0f", stage, layout.VoidPlanes[stage] or -1))
end
print(string.format("[World3Hazards] %s | cactus parts=%d tumbleweeds=%d roadrunners=%d quicksand=%d collapsing=%d carts=%d serpent dugouts=%d scorpions=%d lasers=%d void parts=%d | void %s",
	VERSION, #layout.CactusParts, #layout.Client.Tumbleweeds, #layout.Client.Roadrunners, #layout.QuicksandParts,
	#layout.CollapseParts, #layout.Client.Carts, layout.Client.Serpent and #layout.Client.Serpent.Dugouts or 0,
	#layout.Client.Scorpions, #layout.LaserParts, #layout.VoidParts, table.concat(planes, " ")))

return Service
