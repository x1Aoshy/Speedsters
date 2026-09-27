-- HeatVisionService.server.luau
-- Superman's Heat Vision Trail (Config.AbilityHeatVision, Shared.HeatVisionMath): a player
-- wearing the Superman skin asks (Remotes.HeatVision, { Target = the point they aim at });
-- the server checks the skin, the cooldown and that the character is alive and not in AFK
-- Mode, then melts a path of molten rock on the ground ahead toward the aim:
--   * level with the floor at the feet (or the feet's height over a gap), from the feet up
--     to MaxLength studs, never under MinLength, and short of the first wall (rays at the
--     waist and the head), so it never goes through walls or skips a stage;
--   * drawn out by two red beams from the eyes over DrawSeconds, glowing with embers;
--   * solid for BridgeSeconds, then it cools to dark rock and fades.
-- The next one is ready CooldownSeconds later (the player attribute HeatVisionReadyAt, in
-- server time, for the client's button). A wall right in front makes no path and costs
-- no cooldown. The pieces are named MoltenPath: nothing counts them as lava or a hazard.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local HeatVisionMath = require(Shared:WaitForChild("HeatVisionMath"))
local settings = HeatVisionMath.Settings(Config)
if not settings.Enabled then
	return
end
local RateLimiter = require(ServerScriptService:WaitForChild("Services"):WaitForChild("ServerRateLimiter"))

local FOLDER_NAME = "HeatVisionPaths"
local READY_ATTRIBUTE = "HeatVisionReadyAt"
-- Latency: a request may arrive a little before the owner's own cooldown ran out here.
local COOLDOWN_SLACK = 0.3
local MOLTEN = Color3.fromRGB(255, 104, 30)
local COOLED = Color3.fromRGB(58, 52, 50)
local BEAM = Color3.fromRGB(255, 40, 30)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local function remote(name)
	local existing = Remotes:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end
	if existing then
		existing:Destroy()
	end
	local created = Instance.new("RemoteEvent")
	created.Name = name
	created.Parent = Remotes
	return created
end
local Request = remote("HeatVision")

local readyAt: { [Player]: number } = {}

local function pathsFolder()
	local folder = Workspace:FindFirstChild(FOLDER_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = Workspace
	end
	return folder
end

local function finite(vector)
	return typeof(vector) == "Vector3"
		and vector.X == vector.X and vector.Y == vector.Y and vector.Z == vector.Z
		and math.abs(vector.X) < 1e7 and math.abs(vector.Y) < 1e7 and math.abs(vector.Z) < 1e7
end

-- Rays that see the map only: never characters or other paths.
local function mapParams(character)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = { pathsFolder() }
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(ignore, other.Character)
		end
	end
	if character then
		table.insert(ignore, character)
	end
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true
	return params
end

-- Where the path starts: the floor right under the feet, or the feet's height in the air.
local function startPoint(root, params)
	local at = root.CFrame.Position
	local hit = Workspace:Raycast(at, Vector3.new(0, -8, 0), params)
	if hit then
		return Vector3.new(at.X, hit.Position.Y, at.Z)
	end
	return at - Vector3.new(0, 3, 0)
end

-- How far ahead the first wall is, at the waist and at the head (nil: none in reach).
local function wallAhead(start, direction, params)
	local nearest = nil
	for _, height in { 1.5, 4.5 } do
		local hit = Workspace:Raycast(start + Vector3.new(0, height, 0), direction * (settings.MaxLength + HeatVisionMath.WallClearance), params)
		if hit then
			local distance = (Vector3.new(hit.Position.X, 0, hit.Position.Z) - Vector3.new(start.X, 0, start.Z)).Magnitude
			nearest = math.min(nearest or math.huge, distance)
		end
	end
	return nearest
end

local function embers(parent)
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "Embers"
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 200, 80), Color3.fromRGB(255, 70, 20))
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	sparks.Lifetime = NumberRange.new(0.5, 1.1)
	sparks.Speed = NumberRange.new(2, 6)
	sparks.SpreadAngle = Vector2.new(25, 25)
	sparks.Acceleration = Vector3.new(0, 4, 0)
	sparks.Rate = 14
	sparks.EmissionDirection = Enum.NormalId.Top
	sparks.Parent = parent
	return sparks
end

-- One slab of molten rock.
local function slab(spec, index, model)
	local part = Instance.new("Part")
	part.Name = "MoltenPath"
	part.Anchored = true
	part.CanCollide = true
	part.CanTouch = false
	part.CanQuery = true
	part.CastShadow = false
	part.Material = Enum.Material.CrackedLava
	part.Color = MOLTEN
	part.Size = spec.Size
	part.CFrame = spec.CFrame
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	embers(part)
	if index % 2 == 1 then
		local glow = Instance.new("PointLight")
		glow.Name = "Glow"
		glow.Color = Color3.fromRGB(255, 120, 40)
		glow.Range = 12
		glow.Brightness = 2
		glow.Parent = part
	end
	part.Parent = model
	return part
end

-- The two red beams from the eyes to the end of the path as it is drawn.
local function beams(character, model)
	local head = character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return nil
	end
	local target = Instance.new("Attachment")
	target.Name = "HeatVisionEnd"
	local list = {}
	for _, side in { -1, 1 } do
		local eye = Instance.new("Attachment")
		eye.Name = "HeatVisionEye"
		eye.Position = Vector3.new(0.18 * side, 0.2, -0.55)
		eye.Parent = head
		local beam = Instance.new("Beam")
		beam.Name = "HeatVision"
		beam.Attachment0 = eye
		beam.Attachment1 = target
		beam.Color = ColorSequence.new(BEAM, Color3.fromRGB(255, 150, 60))
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.FaceCamera = true
		beam.Width0 = 0.25
		beam.Width1 = 0.8
		beam.Transparency = NumberSequence.new(0.05)
		beam.Segments = 2
		beam.Parent = model
		table.insert(list, beam)
		Debris:AddItem(eye, settings.DrawSeconds + 0.5)
	end
	return target, list
end

local function melt(player, character, start, direction, length)
	local model = Instance.new("Model")
	model.Name = "HeatVisionPath_" .. player.UserId
	model:SetAttribute("HeatVisionBy", player.UserId)
	model.Parent = pathsFolder()
	local target, list = beams(character, model)
	local slabs = HeatVisionMath.Segments(settings, start, direction, length)
	local parts = {}
	for index, spec in slabs do
		task.delay(spec.Delay, function()
			if not model.Parent then
				return
			end
			local part = slab(spec, index, model)
			table.insert(parts, part)
			if target then
				-- The beams follow the end of the path as it grows.
				target.Position = Vector3.new(0, part.Size.Y / 2, -part.Size.Z / 2) -- its far end, on top
				target.Parent = part
			end
		end)
	end
	-- The beams stop once the path is drawn.
	task.delay(settings.DrawSeconds + 0.25, function()
		for _, beam in list or {} do
			beam:Destroy()
		end
	end)
	-- It cools to dark rock, then fades away.
	task.delay(settings.DrawSeconds + settings.BridgeSeconds, function()
		for _, part in parts do
			if part.Parent then
				for _, child in part:GetChildren() do
					if child:IsA("ParticleEmitter") then
						child.Enabled = false
					elseif child:IsA("PointLight") then
						TweenService:Create(child, TweenInfo.new(settings.FadeSeconds), { Brightness = 0 }):Play()
					end
				end
				part.Material = Enum.Material.Basalt
				TweenService:Create(part, TweenInfo.new(settings.FadeSeconds), { Color = COOLED, Transparency = 1 }):Play()
			end
		end
		task.delay(settings.FadeSeconds, function()
			for _, part in parts do
				part.CanCollide = false
			end
		end)
		Debris:AddItem(model, settings.FadeSeconds + 0.2)
	end)
end

local function onRequest(player, payload)
	if not RateLimiter.Allow(player, "HeatVision", 0.25) then
		return
	end
	if type(payload) ~= "table" or not finite(payload.Target) then
		return
	end
	if player:GetAttribute("EquippedSkin") ~= settings.SkinId or player:GetAttribute("AfkModeActive") == true then
		return
	end
	local now = Workspace:GetServerTimeNow()
	if now < (readyAt[player] or 0) - COOLDOWN_SLACK then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return
	end
	local params = mapParams(character)
	local direction = HeatVisionMath.FlatDirection(payload.Target - root.CFrame.Position, root.CFrame.LookVector)
	local start = startPoint(root, params)
	local aim = Vector3.new(payload.Target.X - start.X, 0, payload.Target.Z - start.Z).Magnitude
	local length = HeatVisionMath.Length(settings, aim, wallAhead(start, direction, params))
	if length < HeatVisionMath.ShortestPath then
		return
	end
	readyAt[player] = now + settings.CooldownSeconds
	player:SetAttribute(READY_ATTRIBUTE, readyAt[player])
	melt(player, character, start, direction, length)
end
Request.OnServerEvent:Connect(onRequest)

Players.PlayerRemoving:Connect(function(player)
	readyAt[player] = nil
end)

print("[HeatVision] ready | " .. settings.MaxLength .. " studs, " .. settings.BridgeSeconds .. " s, every " .. settings.CooldownSeconds .. " s")
