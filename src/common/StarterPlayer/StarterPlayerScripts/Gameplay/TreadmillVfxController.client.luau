--!strict
-- TreadmillVfxController.client.luau
-- One clean themed treadmill effect per runner, built from ONE emitter of the V40 SAB template
-- (ReplicatedStorage.VfxTemplates.Treadmill.DragonGingeriniFloorpart) recoloured to the treadmill's
-- theme. It never clones the template's other nine emitters (the old multi-coloured cloud).
-- Who is running on what comes from the server's replicated player attributes IsOnTreadmill and
-- CurrentTreadmillName (TreadmillTraining.server.luau). Other players are never raycast.
-- LOD: the local player always gets the full effect; on a phone other runners only show within
-- 20 studs, at most the 3 nearest, at half rate; on a desktop within 160 studs at 60% rate.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer
local MAX_VFX_DISTANCE = 160 -- Desktop: cull other runners further than this
local LOW_POWER = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local PHONE_OTHER_DISTANCE = 20 -- Phone: other runners only this close to the local character
local PHONE_MAX_OTHERS = 3 -- Phone: at most this many other runners at once
local PHONE_OTHER_RATE_SCALE = 0.5
local DESKTOP_OTHER_RATE_SCALE = 0.6
local FADE_TIME = 0.85
local LOD_HYSTERESIS = 2 -- Studs: a runner already showing keeps it this far past the cut / ahead in the ranking

local LINES_TEXTURE = "rbxassetid://13828261486" -- V40 lines1..lines4
local RING_TEXTURE = "rbxassetid://16846725471" -- V40 floorfire1..floorfire3

-- TreadmillVfxThemes begin
-- Treadmill name (server attribute CurrentTreadmillName, or a model name) -> theme.
local THEME_BY_NAME: { [string]: string } = {
	basic = "Basic",
	starter = "Basic",
	treadmill1_basic = "Basic",
	golden = "Golden",
	gold = "Golden",
	treadmill2_fast = "Golden",
	candy = "Candy",
	treadmill4_hyperspeed = "Candy",
	diamond = "Diamond",
	treadmill3_superfast = "Diamond",
	needoh = "Ruby",
	admin = "Ruby",
	treadmilladmin = "Ruby",
	hacker = "Matrix",
	admin3000 = "Matrix",
	treadmill5_insanespeed = "Matrix",
	taco = "Taco",
	["taco treadmill"] = "Taco",
}

-- Substring fallbacks for decorated names, most specific first.
local THEME_KEYWORDS: { { string } } = {
	{ "admin3000", "Matrix" },
	{ "hacker", "Matrix" },
	{ "insane", "Matrix" },
	{ "taco", "Taco" },
	{ "needoh", "Ruby" },
	{ "admin", "Ruby" },
	{ "diamond", "Diamond" },
	{ "superfast", "Diamond" },
	{ "candy", "Candy" },
	{ "hyperspeed", "Candy" },
	{ "gold", "Golden" },
	{ "fast", "Golden" },
	{ "basic", "Basic" },
	{ "starter", "Basic" },
}

local function ThemeFor(name: string?): string
	if typeof(name) ~= "string" or name == "" then
		return "Basic"
	end
	local key = string.lower(name)
	local exact = THEME_BY_NAME[key]
	if exact then
		return exact
	end
	for _, entry in THEME_KEYWORDS do
		if string.find(key, entry[1], 1, true) then
			return entry[2]
		end
	end
	return "Basic"
end

type ThemeDef = {
	Source: string, -- the ONE template emitter this theme is built from
	Kind: string, -- "Lines" (speed lines) or "Ring" (floor pulse ring)
	From: Color3,
	To: Color3,
	LightEmission: number,
	Brightness: number,
	Rate: number,
}

local THEMES: { [string]: ThemeDef } = {
	-- Subtle bronze/white speed lines.
	Basic = { Source = "lines1", Kind = "Lines", From = Color3.fromRGB(205, 127, 50), To = Color3.fromRGB(255, 255, 255), LightEmission = 0.15, Brightness = 2, Rate = 8 },
	-- Rich gold energy lines.
	Golden = { Source = "lines1", Kind = "Lines", From = Color3.fromRGB(255, 200, 40), To = Color3.fromRGB(255, 240, 150), LightEmission = 0.5, Brightness = 4, Rate = 11 },
	-- Sweet pastel pink speed lines.
	Candy = { Source = "lines1", Kind = "Lines", From = Color3.fromRGB(255, 160, 210), To = Color3.fromRGB(255, 220, 240), LightEmission = 0.35, Brightness = 3, Rate = 10 },
	-- Pure cyan diamond rings.
	Diamond = { Source = "floorfire1", Kind = "Ring", From = Color3.fromRGB(90, 230, 255), To = Color3.fromRGB(210, 250, 255), LightEmission = 0.6, Brightness = 3, Rate = 5 },
	-- Electric ruby red pulse.
	Ruby = { Source = "floorfire1", Kind = "Ring", From = Color3.fromRGB(225, 20, 60), To = Color3.fromRGB(255, 110, 130), LightEmission = 0.6, Brightness = 4, Rate = 5 },
	-- Matrix green digital lines.
	Matrix = { Source = "lines1", Kind = "Lines", From = Color3.fromRGB(40, 255, 90), To = Color3.fromRGB(170, 255, 190), LightEmission = 0.5, Brightness = 4, Rate = 12 },
	-- Warm orange/golden taco lines.
	Taco = { Source = "lines1", Kind = "Lines", From = Color3.fromRGB(255, 150, 40), To = Color3.fromRGB(255, 215, 90), LightEmission = 0.35, Brightness = 3, Rate = 10 },
}
-- TreadmillVfxThemes end

type ActiveVfx = {
	Attachment: Attachment,
	Emitters: { ParticleEmitter },
	Theme: string,
	BaseRate: number,
	RateScale: number,
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

-- Local player only, and only when the server does not publish CurrentTreadmillName (an older
-- server). One RaycastParams for the script's life.
local localRayParams = RaycastParams.new()
localRayParams.FilterType = Enum.RaycastFilterType.Exclude
localRayParams.IgnoreWater = true
local localRayCharacter: Model? = nil

local function isOnTreadmillRaycast(character: Model, root: BasePart): string?
	if localRayCharacter ~= character then
		localRayCharacter = character
		localRayParams.FilterDescendantsInstances = { character }
	end

	local result = Workspace:Raycast(root.CFrame.Position, Vector3.new(0, -7.5, 0), localRayParams)
	if not result or not result.Instance then
		return nil
	end

	local hit = result.Instance
	local model = hit:FindFirstAncestorOfClass("Model")
	local name = if model then model.Name else hit.Name
	if string.find(string.lower(name), "treadmill", 1, true) == nil then
		return nil
	end
	return name
end

local function getTemplateEmitter(sourceName: string): ParticleEmitter?
	local vfxTemplates = ReplicatedStorage:FindFirstChild("VfxTemplates")
	local folder = vfxTemplates and vfxTemplates:FindFirstChild("Treadmill")
	local treadmillTpl = folder and folder:FindFirstChild("DragonGingeriniFloorpart")
	local source = treadmillTpl and treadmillTpl:FindFirstChild(sourceName)
	if source and source:IsA("ParticleEmitter") then
		return source
	end
	return nil
end

local function createFallbackEmitter(kind: string): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	if kind == "Ring" then
		-- Ground energy pulse ring (V40 floorfire)
		emitter.Texture = RING_TEXTURE
		emitter.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		emitter.EmissionDirection = Enum.NormalId.Top
		emitter.Speed = NumberRange.new(0.001, 0.001)
		emitter.Lifetime = NumberRange.new(0.45, 0.75)
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1.8),
			NumberSequenceKeypoint.new(0.5, 2.6),
			NumberSequenceKeypoint.new(1, 3.4),
		})
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(0.65, 0.25),
			NumberSequenceKeypoint.new(1, 1),
		})
	else
		-- Speed lines (V40 lines)
		emitter.Texture = LINES_TEXTURE
		emitter.Orientation = Enum.ParticleOrientation.VelocityParallel
		emitter.EmissionDirection = Enum.NormalId.Bottom
		emitter.Speed = NumberRange.new(7, 16)
		emitter.Lifetime = NumberRange.new(0.2, 0.55)
		emitter.SpreadAngle = Vector2.new(10, 10)
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.15, 0.45),
			NumberSequenceKeypoint.new(1, 0),
		})
		emitter.Drag = 3
	end
	return emitter
end

-- Exactly ONE emitter for the theme: a clone of one template emitter, or a code-built one.
local function buildThemeEmitter(themeName: string, rateScale: number): (ParticleEmitter, number)
	local def = THEMES[themeName] or THEMES.Basic
	local source = getTemplateEmitter(def.Source)
	local emitter = if source then source:Clone() else createFallbackEmitter(def.Kind)
	emitter.Name = "TreadmillVfx_" .. themeName
	emitter.Color = ColorSequence.new(def.From, def.To)
	emitter.LightEmission = def.LightEmission -- positive: the template rings darken (-1)
	emitter.Brightness = def.Brightness
	emitter.Rate = def.Rate * rateScale
	emitter.Enabled = true
	return emitter, def.Rate
end

local function attachTreadmillVfx(character: Model, root: BasePart, humanoid: Humanoid?, themeName: string, rateScale: number): ActiveVfx
	local hipHeight = if humanoid and humanoid.HipHeight > 0 then humanoid.HipHeight else 2.2
	local att = Instance.new("Attachment")
	att.Name = "TreadmillVfxAttachment"
	att.Position = Vector3.new(0, -hipHeight + 0.15, 0)

	local emitter, baseRate = buildThemeEmitter(themeName, rateScale)
	emitter.Parent = att
	att.Parent = root

	local vfxData: ActiveVfx = {
		Attachment = att,
		Emitters = { emitter },
		Theme = themeName,
		BaseRate = baseRate,
		RateScale = rateScale,
		CleanupTask = nil,
	}
	activeVfxByChar[character] = vfxData
	return vfxData
end

-- A runner who changes treadmill gets the new theme: the old emitter is replaced, never stacked.
-- The old one stops emitting and is destroyed once its particles have lived out (no pop).
local function retireEmitter(em: ParticleEmitter)
	em.Enabled = false
	em.Name = "TreadmillVfx_Retired"
	task.delay(math.min(em.Lifetime.Max + 0.05, FADE_TIME), function()
		em:Destroy()
	end)
end

local function switchTreadmillTheme(vfxData: ActiveVfx, themeName: string, rateScale: number)
	for _, em in vfxData.Emitters do
		retireEmitter(em)
	end
	table.clear(vfxData.Emitters)
	local emitter, baseRate = buildThemeEmitter(themeName, rateScale)
	emitter.Parent = vfxData.Attachment
	table.insert(vfxData.Emitters, emitter)
	vfxData.Theme = themeName
	vfxData.BaseRate = baseRate
	vfxData.RateScale = rateScale
end

local function setTreadmillRateScale(vfxData: ActiveVfx, rateScale: number)
	if vfxData.RateScale == rateScale then
		return
	end
	vfxData.RateScale = rateScale
	for _, em in vfxData.Emitters do
		em.Rate = vfxData.BaseRate * rateScale
	end
end

-- Immediate teardown (character gone): no fade, nothing left behind.
local function destroyTreadmillVfx(character: Model)
	local vfxData = activeVfxByChar[character]
	if not vfxData then
		return
	end
	activeVfxByChar[character] = nil
	if vfxData.CleanupTask then
		task.cancel(vfxData.CleanupTask)
		vfxData.CleanupTask = nil
	end
	vfxData.Attachment:Destroy()
	table.clear(vfxData.Emitters)
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
		end
	end

	-- Fade and destroy attachment after particles finish their lifetime
	vfxData.CleanupTask = task.delay(FADE_TIME, function()
		vfxData.CleanupTask = nil
		if vfxData.Attachment and vfxData.Attachment.Parent then
			vfxData.Attachment:Destroy()
		end
		table.clear(vfxData.Emitters)
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

local function updateCharacterVfx(character: Model, root: BasePart, humanoid: Humanoid, themeName: string, rateScale: number)
	local current = activeVfxByChar[character]
	if not current or current.Attachment.Parent ~= root then
		if current then
			destroyTreadmillVfx(character)
		end
		attachTreadmillVfx(character, root, humanoid, themeName, rateScale)
		return
	end
	resumeTreadmillVfx(current)
	if current.Theme ~= themeName then
		switchTreadmillTheme(current, themeName, rateScale)
	else
		setTreadmillRateScale(current, rateScale)
	end
end

-- The theme the local player is running on, or nil. Attributes first; the raycast only when the
-- server does not publish CurrentTreadmillName.
local function getLocalTheme(character: Model, root: BasePart, humanoid: Humanoid): string?
	local onTreadmill = localPlayer:GetAttribute("IsOnTreadmill") == true
	local current = localPlayer:GetAttribute("CurrentTreadmillName")
	if typeof(current) == "string" then
		return if onTreadmill then ThemeFor(current) else nil
	end
	local isMoving = humanoid.MoveDirection.Magnitude > 0.05
	if not onTreadmill and not isMoving then
		return nil
	end
	local hitName = isOnTreadmillRaycast(character, root)
	if hitName then
		return ThemeFor(hitName)
	end
	return if onTreadmill then "Basic" else nil
end

-- Main Heartbeat scan loop (runs at 10Hz to remain completely lightweight)
local lastScan = 0
local SCAN_INTERVAL = 0.1

type Wanted = { Root: BasePart, Humanoid: Humanoid, Theme: string, Scale: number }
local wantedByChar: { [Model]: Wanted } = {}
local candidates: { Model } = {}
local candidateDistance: { [Model]: number } = {}
local candidateInfo: { [Model]: Wanted } = {}

local function byDistance(a: Model, b: Model): boolean
	return candidateDistance[a] < candidateDistance[b]
end

local function aliveParts(character: Model?): (BasePart?, Humanoid?)
	if not character or not character.Parent then
		return nil, nil
	end
	local root = getRoot(character)
	local hum = getHumanoid(character)
	if not root or not hum or hum.Health <= 0 then
		return nil, nil
	end
	return root, hum
end

local function scanTreadmillVfx()
	table.clear(wantedByChar)
	table.clear(candidates)
	table.clear(candidateDistance)
	table.clear(candidateInfo)

	if localPlayer:GetAttribute("EventEffects") ~= false then
		local localChar = localPlayer.Character
		local localRoot, localHum = aliveParts(localChar)
		local referencePos: Vector3
		if localChar and localRoot and localHum then
			referencePos = localRoot.CFrame.Position
			local theme = getLocalTheme(localChar, localRoot, localHum)
			if theme then
				wantedByChar[localChar] = { Root = localRoot, Humanoid = localHum, Theme = theme, Scale = 1 }
			end
		else
			local camera = Workspace.CurrentCamera
			referencePos = if camera then camera.CFrame.Position else Vector3.zero
		end

		local maxDistance = if LOW_POWER then PHONE_OTHER_DISTANCE else MAX_VFX_DISTANCE
		local scale = if LOW_POWER then PHONE_OTHER_RATE_SCALE else DESKTOP_OTHER_RATE_SCALE
		for _, p in Players:GetPlayers() do
			if p ~= localPlayer and p:GetAttribute("IsOnTreadmill") == true then
				local char = p.Character
				local root, hum = aliveParts(char)
				if char and root and hum and char ~= localChar then
					local dist = (root.CFrame.Position - referencePos).Magnitude
					-- Hysteresis: a runner already showing (not fading) keeps it a little past the cut and
					-- ranks slightly ahead, so runners at the edge or tied for 3rd do not blink at 10 Hz.
					local active = activeVfxByChar[char]
					local showing = active ~= nil and active.CleanupTask == nil and active.Attachment.Parent == root
					local bonus = if showing then LOD_HYSTERESIS else 0
					if dist <= maxDistance + bonus then
						table.insert(candidates, char)
						candidateDistance[char] = dist - bonus
						local name = p:GetAttribute("CurrentTreadmillName")
						candidateInfo[char] = {
							Root = root,
							Humanoid = hum,
							Theme = ThemeFor(if typeof(name) == "string" then name else nil),
							Scale = scale,
						}
					end
				end
			end
		end

		if LOW_POWER and #candidates > PHONE_MAX_OTHERS then
			table.sort(candidates, byDistance)
		end
		local limit = if LOW_POWER then math.min(#candidates, PHONE_MAX_OTHERS) else #candidates
		for i = 1, limit do
			local char = candidates[i]
			wantedByChar[char] = candidateInfo[char]
		end
	end

	-- Turn off everyone not wanted this scan (fade path), then run/refresh the wanted ones.
	for char, _ in activeVfxByChar do
		if not wantedByChar[char] then
			if char.Parent then
				stopTreadmillVfx(char)
			else
				destroyTreadmillVfx(char)
			end
		end
	end
	for char, want in wantedByChar do
		updateCharacterVfx(char, want.Root, want.Humanoid, want.Theme, want.Scale)
	end

	table.clear(candidateInfo)
end

RunService.Heartbeat:Connect(function()
	local now = os.clock()
	if now - lastScan < SCAN_INTERVAL then
		return
	end
	lastScan = now
	scanTreadmillVfx()
end)

-- Character cleanup listeners
local function setupPlayer(p: Player)
	p.CharacterRemoving:Connect(function(char)
		destroyTreadmillVfx(char)
	end)
end

Players.PlayerAdded:Connect(setupPlayer)
for _, p in Players:GetPlayers() do
	setupPlayer(p)
end

Players.PlayerRemoving:Connect(function(p)
	local char = p.Character
	if char then
		destroyTreadmillVfx(char)
	end
end)
