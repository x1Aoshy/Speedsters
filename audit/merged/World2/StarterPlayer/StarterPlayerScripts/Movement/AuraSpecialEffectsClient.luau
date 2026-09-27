--!strict
-- src/common/StarterPlayer/StarterPlayerScripts/Movement/AuraSpecialEffectsClient.client.luau
-- Places the aura pieces that do not ride a limb, for every character this client sees:
-- 1. FloorVFX (Demon Aura): lies on the ground under its wearer, shrinks as they rise
--    and hides in flight or high in the air.
-- 2. ShidouBall (Shidou Demon): floats beside its wearer with a gentle bob.
--
-- The server keeps both anchored (CosmeticService), so moving them here is local to
-- this client and replicates nothing. Written for phones: property writes happen only
-- when something changes, other players' ground checks run at 10 Hz, and pieces far
-- from the camera are left alone.
-- 3. Orbs (Galaxy's Orbit1 and Orbit2): circle their wearer's root.
-- 4. Level of detail for OTHER players' auras and trails: full within LOD.Near studs of
--    the camera, LOD.MidRate of their particles out to LOD.Far, none beyond (their trails
--    and Forge VFX stop too). This client's copies only: nothing replicates, the wearer
--    sees it all.
--
-- Forge VFX runs here too: the auras built from the original models (the Cursed energies'
-- Bezier streams, emitters driven by Forge attributes) only move on a client that has
-- started it. The server's own ForgeVFX.init() stops early, by design.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer

task.spawn(function()
	local ok, err = pcall(function()
		local forge = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ForgeVFX", 30)
		if forge then
			require(forge).init()
		end
	end)
	if not ok then
		warn("[AuraSpecialEffectsClient] Forge VFX could not start: " .. tostring(err))
	end
end)

local SPECIAL = {
	-- Farther than this from the camera, a piece is not moved at all.
	CullDistance = 160,
	-- Other players' floors look for the ground this often (the local player's every frame).
	OthersRaycastInterval = 0.1,
	RayLength = 60,
	-- The floor is full size on the ground and shrinks to FloorMinScale at FloorFadeHeight.
	FloorFadeHeight = 18,
	FloorHideHeight = 16,
	FloorMinScale = 0.02,
	-- Sizes change only in steps this big (a resize is not free).
	ScaleStep = 0.04,
}

type FloorState = {
	Sizes: { [BasePart]: Vector3 },
	Emitters: { ParticleEmitter },
	Parts: { BasePart },
	Visible: boolean?,
	Scale: number?,
	NextRay: number,
	Ground: Vector3?,
}

-- Weak keys: a piece that is destroyed (unequip, respawn, leaving) drops its state.
local floorStates: { [Instance]: FloorState } = setmetatable({}, { __mode = "k" }) :: any
local ballFrames: { [BasePart]: CFrame } = setmetatable({}, { __mode = "k" }) :: any

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = false

local function isFlying(character: Model, player: Player?): boolean
	if player and (player:GetAttribute("AdminFlying") == true or player:GetAttribute("FlightAbilityActive") == true) then
		return true
	end
	return character:GetAttribute("FlightAbilityLocalActive") == true
end

local function floorState(floor: Instance): FloorState
	local state = floorStates[floor]
	if state then
		return state
	end
	state = { Sizes = {}, Emitters = {}, Parts = {}, NextRay = 0 }
	local pieces = floor:GetDescendants()
	table.insert(pieces, floor)
	for _, piece in pieces do
		if piece:IsA("ParticleEmitter") then
			table.insert(state.Emitters, piece)
		elseif piece:IsA("BasePart") then
			table.insert(state.Parts, piece)
			state.Sizes[piece] = piece.Size
			piece.Transparency = 1
			piece.CastShadow = false
		end
	end
	floorStates[floor] = state
	return state
end

local function showFloor(state: FloorState, visible: boolean)
	if state.Visible == visible then
		return
	end
	state.Visible = visible
	for _, emitter in state.Emitters do
		emitter.Enabled = visible
	end
end

local function updateFloor(character: Model, floor: Instance, player: Player?, root: BasePart, humanoid: Humanoid, now: number)
	local state = floorState(floor)
	if isFlying(character, player) then
		showFloor(state, false)
		return
	end

	if now >= state.NextRay then
		state.NextRay = now + (if player == localPlayer then 0 else SPECIAL.OthersRaycastInterval)
		rayParams.FilterDescendantsInstances = { character }
		local hit = Workspace:Raycast(root.Position, Vector3.new(0, -SPECIAL.RayLength, 0), rayParams)
		state.Ground = hit and hit.Position or nil
	end
	local ground = state.Ground
	if not ground then
		showFloor(state, false)
		return
	end

	local hipHeight = if humanoid.HipHeight > 0 then humanoid.HipHeight else 2
	local feetY = root.Position.Y - (hipHeight + root.Size.Y * 0.5)
	local height = math.max(0, feetY - ground.Y)
	if height >= SPECIAL.FloorHideHeight then
		showFloor(state, false)
		return
	end
	showFloor(state, true)

	local scale = math.clamp(1 - height / SPECIAL.FloorFadeHeight, SPECIAL.FloorMinScale, 1)
	scale = math.floor(scale / SPECIAL.ScaleStep + 0.5) * SPECIAL.ScaleStep
	local resize = state.Scale ~= scale
	state.Scale = scale

	local _, yaw, _ = root.CFrame:ToOrientation()
	local turn = CFrame.Angles(0, yaw, 0)
	for _, part in state.Parts do
		local size = state.Sizes[part]
		if part.Name == "Mid" then
			if resize then
				part.Size = size * scale
			end
			part.CFrame = CFrame.new(root.Position.X, ground.Y + 0.08 + 1.2 * scale, root.Position.Z) * turn
		else
			if resize then
				part.Size = Vector3.new(size.X * scale, size.Y, size.Z * scale)
			end
			part.CFrame = CFrame.new(root.Position.X, ground.Y + 0.08, root.Position.Z) * turn
		end
	end
end

local function updateBall(ball: BasePart, root: BasePart, now: number, dt: number)
	local bob = Vector3.new(math.cos(now * 1.6) * 0.18, math.sin(now * 3.2) * 0.4, math.sin(now * 2.1) * 0.12)
	local target = root.CFrame
		* CFrame.new(Vector3.new(2.4, 2.2, 1.6) + bob)
		* CFrame.Angles(math.sin(now * 1.2) * 0.15, now * 2.2, math.cos(now * 1.4) * 0.15)
	local current = ballFrames[ball]
	current = if current then current:Lerp(target, math.clamp(dt * 9.5, 0.01, 1)) else target
	ballFrames[ball] = current
	ball.CFrame = current
end

-- An orb's place: round the root at its radius and height, turning at its speed.
local function orbitFrame(root: BasePart, orb: Instance, now: number): CFrame
	local radius = tonumber(orb:GetAttribute("OrbitRadius")) or 4
	local height = tonumber(orb:GetAttribute("OrbitHeight")) or 0
	local phase = tonumber(orb:GetAttribute("OrbitPhase")) or 0
	local speed = tonumber(orb:GetAttribute("OrbitSpeed")) or 1.4
	local angle = phase + now * speed
	return CFrame.new(root.Position) * CFrame.new(math.cos(angle) * radius, height, math.sin(angle) * radius)
end

local function processCharacter(character: Model, player: Player?, cameraPosition: Vector3, now: number, dt: number)
	local cosmetics = character:FindFirstChild("SpeedsterCosmetics")
	local aura = cosmetics and cosmetics:FindFirstChild("EquippedAura")
	if not aura or not (aura:GetAttribute("HasFloorVFX") or aura:GetAttribute("HasShidouBall") or aura:GetAttribute("HasOrbit")) then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
		return
	end
	if (root.Position - cameraPosition).Magnitude > SPECIAL.CullDistance then
		return
	end
	for _, child in aura:GetChildren() do
		if child:GetAttribute("DynamicFloorVFX") then
			updateFloor(character, child, player, root, humanoid, now)
		elseif child:GetAttribute("DynamicShidouBall") then
			local ball = if child:IsA("BasePart") then child else (child :: Model).PrimaryPart or child:FindFirstChildWhichIsA("BasePart")
			if ball then
				updateBall(ball, root, now, dt)
			end
		elseif child:GetAttribute("DynamicOrbit") and child:IsA("BasePart") then
			child.CFrame = orbitFrame(root, child, now)
		end
	end
end

local LOD = {
	Near = 75,
	Far = 150,
	MidRate = 0.3,
	-- How often the distances are checked, and how often a cosmetic is walked again anyway
	-- (a re-equip brings new emitters).
	Interval = 0.25,
	Refresh = 2,
}
type LodState = { Factor: number, NextWalk: number }
local baseRates: { [ParticleEmitter]: number } = setmetatable({}, { __mode = "k" }) :: any
local lodDisabledTrails: { [Trail]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local lodStates: { [Instance]: LodState } = setmetatable({}, { __mode = "k" }) :: any

local function lodFactor(distance: number): number
	if distance <= LOD.Near then
		return 1
	elseif distance <= LOD.Far then
		return LOD.MidRate
	end
	return 0
end

local function applyLod(cosmetics: Instance, factor: number)
	for _, item in cosmetics:GetDescendants() do
		if item:IsA("ParticleEmitter") then
			local base = baseRates[item]
			if base == nil then
				base = item.Rate
				baseRates[item] = base
			end
			local rate = base * factor
			if item.Rate ~= rate then
				item.Rate = rate
			end
		elseif item:HasTag("ConstantVFX") then
			-- A Forge VFX stream: off beyond LOD.Far, as the author set it otherwise.
			if factor == 0 then
				if item:GetAttribute("Enabled") ~= false then
					item:SetAttribute("LodAuthoredEnabled", item:GetAttribute("Enabled") == nil and "unset" or item:GetAttribute("Enabled"))
					item:SetAttribute("Enabled", false)
				end
			else
				local authored = item:GetAttribute("LodAuthoredEnabled")
				if authored ~= nil then
					item:SetAttribute("Enabled", if authored == "unset" then nil else authored)
					item:SetAttribute("LodAuthoredEnabled", nil)
				end
			end
		elseif item:IsA("Trail") then
			if factor == 0 then
				if item.Enabled then
					item.Enabled = false
					lodDisabledTrails[item] = true
				end
			elseif lodDisabledTrails[item] then
				lodDisabledTrails[item] = nil
				item.Enabled = true
			end
		end
	end
end

local function updateLod(cameraPosition: Vector3, now: number)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local cosmetics = character and character:FindFirstChild("SpeedsterCosmetics")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if player ~= localPlayer and cosmetics and root and root:IsA("BasePart") then
			local factor = lodFactor((root.Position - cameraPosition).Magnitude)
			local state = lodStates[cosmetics]
			if not state or state.Factor ~= factor or now >= state.NextWalk then
				applyLod(cosmetics, factor)
				lodStates[cosmetics] = { Factor = factor, NextWalk = now + LOD.Refresh }
			end
		end
	end
end

local lodClock = 0
RunService.RenderStepped:Connect(function(dt: number)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local cameraPosition = camera.CFrame.Position
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character and character.Parent then
			processCharacter(character, player, cameraPosition, now, dt)
		end
	end
	lodClock += dt
	if lodClock >= LOD.Interval then
		lodClock = 0
		updateLod(cameraPosition, now)
	end
end)
