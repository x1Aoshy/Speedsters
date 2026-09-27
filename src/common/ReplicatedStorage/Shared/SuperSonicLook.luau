-- ReplicatedStorage/Shared/SuperSonicLook.luau — the Super Sonic form's look on any character, drawn by
-- every client for every Super player (player attribute SSE_Super, Shared/SuperSonicEvent), and the
-- body hidden behind the homing attack's spin ball. Used by Gameplay/SuperSonicEventClient.
-- 2026-09-26 (owner): "radiant gold (255, 215, 0) body, ruby-red (255, 30, 30) eyes, lightning flipbook
-- sparks from the limbs; DO NOT add or force any aura particle and NEVER hide or disable the player's
-- equipped auras or trails; restore everything exactly when it ends". How it reads over R6 clothing
-- and the game's skins (decided 2026-09-26):
--   * The skin turns gold: each body part's Color (what BodyColors paints and the clothing's
--     transparent areas show) is set to the gold, locally. The value it had is kept and put back at
--     the end; if the server changes it meanwhile (a skin change, the appearance loading late) the
--     new value is the one kept and put back, and the gold goes on again.
--   * The clothes (a Shirt / Pants texture cannot be recoloured: Clothing.Color3 only multiplies, and
--     blue x gold is black) get a gold glaze: a Neon shell 0.08 studs over each body part, half
--     transparent, so the suit's drawing still shows through a golden glow. Accessories (hair, the
--     skins' masks and capes) get the same glaze on the Full level: Sonic's quills go gold.
--   * Two small Neon ruby eyes on the face (in front of a face mask when the skin wears one).
--   * Lightning flipbook sparks (Shared/SuperSonicEventFx.Textures.Lightning) from the hands and feet.
-- Nothing of the player's is hidden, disabled, recoloured or re-parented except the body parts'
-- Color above: everything else is added (named SSE_*) and destroyed by Remove. The equipped aura and
-- trail (character.SpeedsterCosmetics, Economy/Cosmetics/CosmeticService) are never looked into.
-- 2026-09-26 (owner, v2): while the server dresses the player in the game's real Super Sonic skin, the
-- client draws none of the old look (options BodyGold = false, Shells / AccessoryShells / Eyes off): only the
-- small lightning sparks on the hands and feet (SparkScale shrinks them).
-- `env`: { Instance, Vector3, CFrame, Color3, Enum, NumberRange, NumberSequence, NumberSequenceKeypoint,
-- ColorSequence, ColorSequenceKeypoint, Vector2 } (the Roblox globals in game, @lune/roblox in
-- audit/test_u4_supersonic_client). Look._watch is replaced by the test (Lune has no events).
local Look = {}

Look.Prefix = "SSE_"
Look.CosmeticsFolder = "SpeedsterCosmetics" -- the equipped aura and trail: never touched
Look.R6Body = { "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }
Look.R15Body = {
	"Head", "UpperTorso", "LowerTorso",
	"LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand",
	"LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot",
}
-- Where the sparks come from, in order (hands first): { R6 limb, R15 part }.
Look.SparkLimbs = {
	{ "Right Arm", "RightHand" },
	{ "Left Arm", "LeftHand" },
	{ "Right Leg", "RightFoot" },
	{ "Left Leg", "LeftFoot" },
}
Look.Shell = { Grow = 0.08, Transparency = 0.5, AccessoryTransparency = 0.42, MeshGrow = 1.05 }
-- R6 eyes (head space; forward -Z): half the gap between them, the height, the size.
Look.Eyes = { Gap = 0.19, Height = 0.14, Size = { 0.2, 0.3, 0.1 }, Front = 0.61, MaskReach = 2.2 }
Look.Spark = { Lifetime = { 0.16, 0.3 }, Size = { 1.5, 0.7 }, Speed = { 0.5, 2.5 }, Brightness = 2, ZOffset = 0.4 }

-- A property watcher (Roblox: GetPropertyChangedSignal). Returns something with :Disconnect().
function Look._watch(instance: any, property: string, callback: () -> ()): any
	return instance:GetPropertyChangedSignal(property):Connect(callback)
end

local function rgb(env: any, values: { number }): any
	return env.Color3.fromRGB(values[1], values[2], values[3])
end

local function sameColor(a: any, b: any): boolean
	return math.abs(a.R - b.R) + math.abs(a.G - b.G) + math.abs(a.B - b.B) < 0.01
end

-- Is `instance` part of the equipped aura / trail (character.SpeedsterCosmetics)?
function Look.IsCosmetic(instance: any, character: any): boolean
	local folder = character and character:FindFirstChild(Look.CosmeticsFolder)
	if folder and (instance == folder or instance:IsDescendantOf(folder)) then
		return true
	end
	local node = instance
	while node and node ~= character do
		if node.Name == Look.CosmeticsFolder then
			return true
		end
		node = node.Parent
	end
	return false
end

-- The character's body parts (R6 or R15 names), in order.
function Look.BodyParts(character: any): { any }
	local out = {}
	for _, list in { Look.R6Body, Look.R15Body } do
		for _, name in list do
			local part = character:FindFirstChild(name)
			if part and part:IsA("BasePart") and not table.find(out, part) then
				table.insert(out, part)
			end
		end
	end
	return out
end

-- The Accessory handles (the equipped aura / trail are not Accessories, and never under one).
function Look.AccessoryHandles(character: any): { any }
	local out = {}
	for _, child in character:GetChildren() do
		if child:IsA("Accessory") then
			local handle = child:FindFirstChild("Handle")
			if handle and handle:IsA("BasePart") and not Look.IsCosmetic(handle, character) then
				table.insert(out, handle)
			end
		end
	end
	return out
end

local function quiet(part: any)
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.CastShadow = false
end

-- A glaze over `part`: a clone of its shape (MeshPart, a Part's SpecialMesh, or its block / ball), a
-- little bigger, Neon gold, half transparent, welded to it. Nil when the part has nothing to copy.
local function makeShell(env: any, handle: any, part: any, gold: any, transparency: number): any?
	local grow = Look.Shell.Grow
	local shell
	if part:IsA("MeshPart") then
		shell = part:Clone()
		for _, child in shell:GetChildren() do
			child:Destroy()
		end
		pcall(function()
			shell.TextureID = ""
		end)
	elseif part:IsA("Part") then
		shell = env.Instance.new("Part")
		pcall(function()
			shell.Shape = part.Shape
		end)
		local mesh = part:FindFirstChildWhichIsA("SpecialMesh")
		if mesh then
			local copy = env.Instance.new("SpecialMesh")
			copy.MeshType = mesh.MeshType
			pcall(function()
				copy.MeshId = mesh.MeshId
			end)
			copy.TextureId = ""
			copy.Scale = mesh.Scale * Look.Shell.MeshGrow
			copy.Offset = mesh.Offset
			copy.Parent = shell
		end
	else
		return nil
	end
	shell.Name = Look.Prefix .. "Shell"
	shell.Size = part.Size + env.Vector3.new(grow, grow, grow)
	shell.CFrame = part.CFrame
	quiet(shell)
	shell.Material = env.Enum.Material.Neon
	shell.Color = gold
	shell.Transparency = transparency
	shell.Reflectance = 0
	pcall(function()
		shell.LocalTransparencyModifier = 0
	end)
	local weld = env.Instance.new("WeldConstraint")
	weld.Name = Look.Prefix .. "ShellWeld"
	weld.Part0 = part
	weld.Part1 = shell
	weld.Parent = shell
	shell.Parent = part
	table.insert(handle.added, shell)
	return shell
end

-- How far in front of the head centre the face is (a face mask pushes it forward): head-space z < 0.
local function faceFront(character: any, head: any): number
	local front = -Look.Eyes.Front
	for _, handlePart in Look.AccessoryHandles(character) do
		local offset = head.CFrame:PointToObjectSpace(handlePart.CFrame.Position)
		if offset.Magnitude < Look.Eyes.MaskReach and offset.Z < -0.15 and math.abs(offset.Y) < 0.9 then
			front = math.min(front, offset.Z - handlePart.Size.Z * 0.5 * 0.85)
		end
	end
	return front
end

local function makeEyes(env: any, handle: any, character: any, ruby: any)
	local head = character:FindFirstChild("Head")
	if not (head and head:IsA("BasePart")) then
		return
	end
	local e = Look.Eyes
	local front = faceFront(character, head) - 0.02
	for _, side in { -1, 1 } do
		local eye = env.Instance.new("Part")
		eye.Name = Look.Prefix .. "Eye"
		eye.Size = env.Vector3.new(e.Size[1], e.Size[2], e.Size[3])
		eye.CFrame = head.CFrame * env.CFrame.new(side * e.Gap, e.Height, front)
		quiet(eye)
		eye.Material = env.Enum.Material.Neon
		eye.Color = ruby
		pcall(function()
			eye.LocalTransparencyModifier = 0
		end)
		local mesh = env.Instance.new("SpecialMesh")
		mesh.MeshType = env.Enum.MeshType.Sphere
		mesh.Parent = eye
		local weld = env.Instance.new("WeldConstraint")
		weld.Name = Look.Prefix .. "EyeWeld"
		weld.Part0 = head
		weld.Part1 = eye
		weld.Parent = eye
		eye.Parent = head
		table.insert(handle.added, eye)
	end
end

-- A lightning flipbook emitter (the one texture this module puts on a particle).
local function makeSparks(env: any, handle: any, part: any, isR6: boolean, options: any)
	local s = Look.Spark
	local attachment = env.Instance.new("Attachment")
	attachment.Name = Look.Prefix .. "Spark"
	-- An R6 limb's hand / foot end; an R15 hand or foot's centre.
	local y = if isR6 then -part.Size.Y / 2 + 0.25 else 0
	attachment.CFrame = env.CFrame.new(0, y, 0)
	local emitter = env.Instance.new("ParticleEmitter")
	emitter.Name = Look.Prefix .. "Lightning"
	emitter.Texture = options.Texture
	local flip = options.Flipbook or {}
	pcall(function()
		emitter.FlipbookLayout = env.Enum.ParticleFlipbookLayout[flip.Layout or "None"]
		emitter.FlipbookMode = env.Enum.ParticleFlipbookMode[flip.Mode or "OneShot"]
		emitter.FlipbookFramerate = env.NumberRange.new(flip.Fps or 30)
	end)
	emitter.Rate = options.SparkRate or 3
	emitter.Lifetime = env.NumberRange.new(s.Lifetime[1], s.Lifetime[2])
	emitter.Speed = env.NumberRange.new(s.Speed[1], s.Speed[2])
	emitter.SpreadAngle = env.Vector2.new(180, 180)
	emitter.Rotation = env.NumberRange.new(0, 360)
	local k = math.clamp(tonumber(options.SparkScale) or 1, 0.1, 2)
	emitter.Size = env.NumberSequence.new({
		env.NumberSequenceKeypoint.new(0, s.Size[1] * k),
		env.NumberSequenceKeypoint.new(1, s.Size[2] * k),
	})
	emitter.Transparency = env.NumberSequence.new({
		env.NumberSequenceKeypoint.new(0, 0),
		env.NumberSequenceKeypoint.new(0.7, 0.25),
		env.NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Color = env.ColorSequence.new({
		env.ColorSequenceKeypoint.new(0, env.Color3.fromRGB(255, 250, 200)),
		env.ColorSequenceKeypoint.new(1, options.Gold),
	})
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	pcall(function()
		emitter.Brightness = s.Brightness
	end)
	emitter.LockedToPart = true
	emitter.ZOffset = s.ZOffset
	emitter.Enabled = true
	emitter.Parent = attachment
	attachment.Parent = part
	table.insert(handle.added, attachment)
	table.insert(handle.sparks, emitter)
end

-- Turns `character` Super. options:
--   Gold, Ruby (Color3), BodyGold (default on: the body parts turn gold), Shells (the glaze on the body),
--   AccessoryShells, Eyes (default on), SparkLimbs (0..4), SparkRate, SparkScale, Texture (the lightning
--   flipbook id), Flipbook { Layout, Mode, Fps }
-- Returns the handle Remove takes.
function Look.Apply(env: any, character: any, options: any): any
	local gold = options.Gold or rgb(env, { 255, 215, 0 })
	local ruby = options.Ruby or rgb(env, { 255, 30, 30 })
	local handle = { character = character, colors = {}, watchers = {}, added = {}, sparks = {}, gold = gold, removed = false }
	local body = Look.BodyParts(character)
	-- The skin: gold, the old colour kept (and kept up to date if the server changes it meanwhile).
	for _, part in (if options.BodyGold == false then {} else body) do
		local entry = { part = part, original = part.Color }
		table.insert(handle.colors, entry)
		part.Color = gold
		local ok, connection = pcall(Look._watch, part, "Color", function()
			if handle.removed or not part.Parent then
				return
			end
			if not sameColor(part.Color, gold) then
				entry.original = part.Color
				part.Color = gold
			end
		end)
		if ok and connection then
			table.insert(handle.watchers, connection)
		end
	end
	-- The glaze.
	if options.Shells then
		for _, part in body do
			makeShell(env, handle, part, gold, Look.Shell.Transparency)
		end
	end
	if options.AccessoryShells then
		for _, handlePart in Look.AccessoryHandles(character) do
			makeShell(env, handle, handlePart, gold, Look.Shell.AccessoryTransparency)
		end
	end
	if options.Eyes ~= false then
		makeEyes(env, handle, character, ruby)
	end
	-- The sparks.
	local limbs = math.clamp(math.floor(tonumber(options.SparkLimbs) or 0), 0, #Look.SparkLimbs)
	if limbs > 0 and type(options.Texture) == "string" and options.Texture ~= "" then
		local made = 0
		for _, pair in Look.SparkLimbs do
			if made >= limbs then
				break
			end
			local r6 = character:FindFirstChild(pair[1])
			local r15 = character:FindFirstChild(pair[2])
			local part = if r6 and r6:IsA("BasePart") then r6 elseif r15 and r15:IsA("BasePart") then r15 else nil
			if part then
				makeSparks(env, handle, part, part == r6, { Texture = options.Texture, Flipbook = options.Flipbook, SparkRate = options.SparkRate, SparkScale = options.SparkScale, Gold = gold })
				made += 1
			end
		end
	end
	return handle
end

-- The sparks on or off (the spin ball hides the body; the aura is not ours and stays as it is).
function Look.SetSparks(handle: any, on: boolean)
	if not handle then
		return
	end
	for _, emitter in handle.sparks do
		if emitter.Parent then
			emitter.Enabled = on
		end
	end
end

-- Everything back exactly as it was: the colours kept (the server's latest), what was added destroyed.
function Look.Remove(handle: any)
	if not handle or handle.removed then
		return
	end
	handle.removed = true
	for _, connection in handle.watchers do
		pcall(function()
			connection:Disconnect()
		end)
	end
	table.clear(handle.watchers)
	for _, entry in handle.colors do
		if entry.part.Parent then
			entry.part.Color = entry.original
		end
	end
	table.clear(handle.colors)
	for _, instance in handle.added do
		instance:Destroy()
	end
	table.clear(handle.added)
	table.clear(handle.sparks)
end

----------------------------------------------------------------------
-- The body behind the spin ball (the homing attack)
----------------------------------------------------------------------
-- What the ball hides: every BasePart and Decal of the character (body, accessories, the Super
-- glaze and eyes), never the equipped aura / trail. Computed once per flight.
function Look.HidePieces(character: any): { any }
	local out = {}
	for _, d in character:GetDescendants() do
		if (d:IsA("BasePart") or d:IsA("Decal")) and not Look.IsCosmetic(d, character) then
			table.insert(out, d)
		end
	end
	return out
end

-- hidden: LocalTransparencyModifier 1 on every piece (the first value kept in `saved`); else the
-- kept values back. Called every frame of a flight (the camera may write it too): no allocation.
function Look.Hide(pieces: { any }, saved: { [any]: number }, hidden: boolean)
	if hidden then
		for _, piece in pieces do
			if saved[piece] == nil then
				saved[piece] = piece.LocalTransparencyModifier
			end
			if piece.LocalTransparencyModifier ~= 1 then
				piece.LocalTransparencyModifier = 1
			end
		end
	else
		for piece, value in saved do
			if piece.Parent then
				piece.LocalTransparencyModifier = value
			end
		end
		table.clear(saved)
	end
end

return Look
