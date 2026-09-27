--!strict
-- TreadmillVfxController.client.luau
-- Dynamic treadmill speed lines, floor pulse energy, and foot sparks extracted from V40 SAB.
-- Activates when players run on treadmills (IsOnTreadmill attribute or ground raycast).

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer
local MAX_VFX_DISTANCE = 160 -- Cull characters further than this to preserve framerate

type ActiveVfx = {
	Attachment: Attachment,
	Emitters: { ParticleEmitter },
	CleanupTask: thread?,
}

local activeVfxByChar: { [Model]: ActiveVfx } = {}

local function getRoot(character: Model?): BasePart?
	if not character then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function getHumanoid(character: Model?): Humanoid?
	if not character then
		return nil
	end
	return character:FindFirstChildOfClass("Humanoid")
end

local function isOnTreadmillRaycast(character: Model, root: BasePart): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.IgnoreWater = true

	local result = Workspace:Raycast(root.Position, Vector3.new(0, -7.5, 0), params)
	if not result or not result.Instance then
		return false
	end

	local hit = result.Instance
	local model = hit:FindFirstAncestorOfClass("Model")
	local name = (if model then model.Name else hit.Name):lower()
	return name:find("treadmill") ~= nil
end

local function isPlayerOnTreadmill(player: Player, character: Model, root: BasePart): boolean
	if player:GetAttribute("IsOnTreadmill") == true then
		return true
	end
	return isOnTreadmillRaycast(character, root)
end

local function createFallbackEmitters(att: Attachment): { ParticleEmitter }
	local emitters: { ParticleEmitter } = {}

	-- Speed lines (V40 lines1..lines4)
	local lineColors = {
		Color3.fromRGB(96, 255, 71),   -- Lime green
		Color3.fromRGB(255, 55, 55),   -- Red / Orange
		Color3.fromRGB(116, 160, 255), -- Cyan / Blue
		Color3.fromRGB(248, 255, 107), -- Bright Yellow
	}

	for i, color in ipairs(lineColors) do
		local line = Instance.new("ParticleEmitter")
		line.Name = "SpeedLine_" .. i
		line.Texture = "rbxassetid://13828261486"
		line.Orientation = Enum.ParticleOrientation.VelocityParallel
		line.EmissionDirection = Enum.NormalId.Bottom
		line.Speed = NumberRange.new(7, 16)
		line.Lifetime = NumberRange.new(0.2, 0.55)
		line.SpreadAngle = Vector2.new(10, 10)
		line.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.15, 0.45),
			NumberSequenceKeypoint.new(1, 0),
		})
		line.Color = ColorSequence.new(color)
		line.Drag = 3
		line.Rate = 12
		line.LightEmission = 0.4
		line.ZOffset = 0.05 * i
		line.Parent = att
		table.insert(emitters, line)
	end

	-- Ground energy pulse rings (V40 floorfire1..floorfire3)
	local fireColors = {
		Color3.fromRGB(115, 255, 127),
		Color3.fromRGB(255, 75, 75),
		Color3.fromRGB(119, 139, 255),
	}

	for i, color in ipairs(fireColors) do
		local ring = Instance.new("ParticleEmitter")
		ring.Name = "FloorPulse_" .. i
		ring.Texture = "rbxassetid://16846725471"
		ring.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		ring.EmissionDirection = Enum.NormalId.Top
		ring.Speed = NumberRange.new(0.001, 0.001)
		ring.Lifetime = NumberRange.new(0.45, 0.75)
		ring.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1.8),
			NumberSequenceKeypoint.new(0.5, 2.6),
			NumberSequenceKeypoint.new(1, 3.4),
		})
		ring.Color = ColorSequence.new(color)
		ring.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(0.65, 0.25),
			NumberSequenceKeypoint.new(1, 1),
		})
		ring.Rate = 5
		ring.LightEmission = 0.3
		ring.ZOffset = 0.01 * i
		ring.Parent = att
		table.insert(emitters, ring)
	end

	-- Foot sparks / ground energy (V40 fire1..fire3)
	local fireTextures = {
		"http://www.roblox.com/asset/?id=109425262745323",
		"rbxassetid://109839180247874",
		"rbxassetid://16849232483",
	}

	for i, tex in ipairs(fireTextures) do
		local spark = Instance.new("ParticleEmitter")
		spark.Name = "FootSpark_" .. i
		spark.Texture = tex
		spark.Orientation = Enum.ParticleOrientation.FacingCamera
		spark.Speed = NumberRange.new(2, 6)
		spark.Lifetime = NumberRange.new(0.25, 0.45)
		spark.SpreadAngle = Vector2.new(45, 45)
		spark.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.6),
			NumberSequenceKeypoint.new(1, 0),
		})
		spark.Color = ColorSequence.new(Color3.fromRGB(255, 200, 80))
		spark.Rate = 8
		spark.LightEmission = 0.6
		spark.Parent = att
		table.insert(emitters, spark)
	end

	return emitters
end

local function attachTreadmillVfx(character: Model, root: BasePart, humanoid: Humanoid?): ActiveVfx
	local hipHeight = if humanoid and humanoid.HipHeight > 0 then humanoid.HipHeight else 2.2
	local att = Instance.new("Attachment")
	att.Name = "TreadmillVfxAttachment"
	att.Position = Vector3.new(0, -hipHeight + 0.15, 0)
	att.Parent = root

	local emitters: { ParticleEmitter } = {}

	-- Check if preloaded V40 template is available in ReplicatedStorage
	local vfxTemplates = ReplicatedStorage:FindFirstChild("VfxTemplates")
	local treadmillTpl = vfxTemplates
		and vfxTemplates:FindFirstChild("Treadmill")
		and vfxTemplates.Treadmill:FindFirstChild("DragonGingeriniFloorpart")

	if treadmillTpl then
		for _, child in treadmillTpl:GetChildren() do
			if child:IsA("ParticleEmitter") then
				local clone = child:Clone()
				clone.Enabled = true
				clone.Parent = att
				table.insert(emitters, clone)
			end
		end
	end

	if #emitters == 0 then
		emitters = createFallbackEmitters(att)
	end

	local vfxData: ActiveVfx = {
		Attachment = att,
		Emitters = emitters,
		CleanupTask = nil,
	}
	activeVfxByChar[character] = vfxData
	return vfxData
end

local function stopTreadmillVfx(character: Model)
	local vfxData = activeVfxByChar[character]
	if not vfxData then
		return
	end

	if vfxData.CleanupTask then
		return -- Already cleaning up
	end

	-- Disable particle emission immediately
	for _, em in vfxData.Emitters do
		if em and em.Parent then
			em.Enabled = false
			em.Rate = 0
		end
	end

	-- Fade and destroy attachment after particles finish their lifetime
	vfxData.CleanupTask = task.delay(0.85, function()
		if vfxData.Attachment and vfxData.Attachment.Parent then
			vfxData.Attachment:Destroy()
		end
		if activeVfxByChar[character] == vfxData then
			activeVfxByChar[character] = nil
		end
	end)
end

local function resumeTreadmillVfx(vfxData: ActiveVfx)
	if vfxData.CleanupTask then
		task.cancel(vfxData.CleanupTask)
		vfxData.CleanupTask = nil
	end
	for _, em in vfxData.Emitters do
		if em and em.Parent then
			em.Enabled = true
		end
	end
end

local function updateCharacterVfx(player: Player, character: Model, cameraPos: Vector3)
	local root = getRoot(character)
	local hum = getHumanoid(character)
	if not root or not hum or hum.Health <= 0 then
		stopTreadmillVfx(character)
		return
	end

	local dist = (root.Position - cameraPos).Magnitude
	if dist > MAX_VFX_DISTANCE then
		stopTreadmillVfx(character)
		return
	end

	local isMoving = hum.MoveDirection.Magnitude > 0.05
	local onTreadmill = isPlayerOnTreadmill(player, character, root)

	if onTreadmill and (isMoving or player:GetAttribute("IsOnTreadmill") == true) then
		local current = activeVfxByChar[character]
		if current then
			resumeTreadmillVfx(current)
		else
			attachTreadmillVfx(character, root, hum)
		end
	else
		stopTreadmillVfx(character)
	end
end

-- Main Heartbeat scan loop (runs at 10Hz to remain completely lightweight)
local lastScan = 0
local SCAN_INTERVAL = 0.1

RunService.Heartbeat:Connect(function()
	local now = os.clock()
	if now - lastScan < SCAN_INTERVAL then
		return
	end
	lastScan = now

	local camera = Workspace.CurrentCamera
	local camPos = if camera then camera.CFrame.Position else Vector3.zero

	-- Scan all active players
	for _, p in Players:GetPlayers() do
		local char = p.Character
		if char and char.Parent then
			updateCharacterVfx(p, char, camPos)
		end
	end

	-- Prune stale characters
	for char, _ in pairs(activeVfxByChar) do
		if not char.Parent then
			activeVfxByChar[char] = nil
		end
	end
end)

-- Character cleanup listeners
local function setupPlayer(p: Player)
	p.CharacterRemoving:Connect(function(char)
		stopTreadmillVfx(char)
		activeVfxByChar[char] = nil
	end)
end

Players.PlayerAdded:Connect(setupPlayer)
for _, p in Players:GetPlayers() do
	setupPlayer(p)
end

Players.PlayerRemoving:Connect(function(p)
	local char = p.Character
	if char then
		stopTreadmillVfx(char)
		activeVfxByChar[char] = nil
	end
end)
