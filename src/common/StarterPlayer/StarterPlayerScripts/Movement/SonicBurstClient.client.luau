-- SonicBurstClient.client.luau
-- The Sonic Burst ability, as every client sees it (Core/Abilities/SonicBurstService is
-- the server side, Shared.SonicBurstMath its numbers):
--
--   1. Charge: hold the sprint (Shift on a keyboard, the sprint trigger on a gamepad, the
--      Burst button on a phone, which sprints while held). The stamina bar drains as it
--      always does, and the more of it this hold spends the fuller the charge. The bar's
--      hint says so ("Hold Shift to charge the run"). Around the player a bubble of glass
--      and shimmering energy swells and shakes, faster and harder as it fills, with glass
--      shards whirling round it, a cage of flickering lightning and sparks; on the player's
--      own screen the glass trembles and the view warps behind it (Shared.GlassShatter's
--      Charge).
--   2. Burst: let go. The bubble explodes into shards with a sonic boom; the player's
--      screen shatters exactly like the Glass Shatter, with a camera kick and an FOV punch
--      70 -> 88 and back (Shared.CameraPunch).
--   3. Throw: the owner's client drives its own character for AbilitySonicBurstDashSeconds at
--      the dash speed (logarithmic in the speedometer speed, scaled by the charge) where the
--      player aims: at the mouse pointer (a free cursor), or where the camera looks (shift-
--      lock, gamepads, touch screens), turning with it while the throw lasts. It stops short
--      of the first wall ahead (a sphere cast every frame), so no speed goes through the
--      map. InstantMovementController stands aside while the character has
--      SonicBurstDashLocal.
--
-- Everything it makes (bubble, shards, bolts, sparks, sounds, loops) goes when the burst
-- ends, and at once if its character dies, respawns or leaves.
local Debris = game:GetService("Debris")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
if Config.AbilitySonicBurstEnabled ~= true then
	return
end
local SonicBurstMath = require(Shared:WaitForChild("SonicBurstMath"))
local GlassBurst = require(Shared:WaitForChild("GlassBurst"))
local GlassShatter = require(Shared:WaitForChild("GlassShatter"))
local CameraPunch = require(Shared:WaitForChild("CameraPunch"))
local HudErgonomics = require(Shared:WaitForChild("HudErgonomics"))
local SonicBurstUi = require(Shared:WaitForChild("SonicBurstUi"))
local MenuEvents = require(Shared:WaitForChild("MenuEvents"))

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Action = Remotes:WaitForChild("SonicBurstAction")
local Update = Remotes:WaitForChild("SonicBurstUpdate")

local COOLDOWN = SonicBurstMath.Cooldown(Config)
local DASH = SonicBurstMath.Dash(Config)
local FULL_CHARGE = SonicBurstMath.FullChargeSeconds
local SHOW_AFTER = SonicBurstMath.ShowAfterSeconds
local DRAIN = tonumber(Config.BoostDrainPerSecond) or 5.78
local FOV_PUNCH = tonumber(Config.AbilitySonicBurstFovPunch) or 18
local CHARGE_SOUND = tostring(Config.AbilitySonicBurstChargeSoundId or "")
local BOOM_SOUND = tostring(Config.AbilitySonicBurstBoomSoundId or "")
local RUNTIME_NAME = "SonicBurstRuntime"
local DASH_ATTRIBUTE = "SonicBurstDashLocal"
local HINT_ATTRIBUTE = "SonicBurstHint"
local BUBBLE_SIZE = 7.5
local GLASS_COLOR = Color3.fromRGB(220, 242, 255)
local ENERGY_COLOR = Color3.fromRGB(80, 200, 255)
local BOLT_COLOR = Color3.fromRGB(170, 240, 255)
local BOLTS = 7
local BOLT_SEGMENTS = 5
local SHARDS = 10
local WALL_PROBE_RADIUS = 1.4
-- A remote player's bubble that never hears its end (a lost message) goes by itself.
local REMOTE_CHARGE_TIMEOUT = 8
-- Exactly the Glass Shatter the sprint used to play (StageBarrierShatter uses it too),
-- a little harder the fuller the charge.
local SHATTER = {
	Distance = 3.2,
	HoldTime = 0.02,
	Depth = 4,
	Thickness = 0.07,
	Transparency = 0.4,
	Color = Color3.fromRGB(250, 252, 255),
	CameraPunch = true,
	Shockwave = true,
	Always = true,
}

local function rng(a, b)
	return a + math.random() * (b - a)
end

local function soundsOn()
	return player:GetAttribute("SoundEffects") ~= false
end

local function runtimeFolder()
	local folder = Workspace:FindFirstChild(RUNTIME_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = RUNTIME_NAME
		folder.Parent = Workspace
	end
	return folder
end

local function playSoundAt(soundId, parent, volume, looped)
	if soundId == "" or not soundsOn() then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume
	sound.Looped = looped == true
	sound.RollOffMaxDistance = 250
	sound.Parent = parent
	sound:Play()
	return sound
end

local function onSphere(angle, latitude)
	return Vector3.new(math.cos(angle) * math.cos(latitude), math.sin(latitude), math.sin(angle) * math.cos(latitude))
end

local function effectPart(className, name, parent)
	local part = Instance.new(className)
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Parent = parent
	return part
end

----------------------------------------------------------------------
-- The bubble (any character's)
----------------------------------------------------------------------
local active = {} -- [character] = effect

-- A charging bubble on `character`. effect.SetLevel(0..1) makes it fuller and wilder;
-- effect.Cancel() takes it all away. `levelByTime` (another player's bubble, whose charge
-- this client cannot see) fills it with the time held instead.
local function startBubble(character, levelByTime)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return nil
	end
	local previous = active[character]
	if previous then
		previous.Cancel()
	end

	local effect = { Alive = true, Level = 0, Connections = {} }
	local holder = Instance.new("Folder")
	holder.Name = "SonicBurst_" .. character.Name
	holder.Parent = runtimeFolder()

	-- Glass outside, shimmering energy inside: the view through it warps and ripples.
	local glass = effectPart("Part", "Bubble", holder)
	glass.Shape = Enum.PartType.Ball
	glass.Material = Enum.Material.Glass
	glass.Color = GLASS_COLOR
	glass.Reflectance = 0.5
	glass.Transparency = 0.35
	glass.Size = Vector3.one * BUBBLE_SIZE
	glass.CFrame = CFrame.new(root.Position)
	local energy = effectPart("Part", "Energy", holder)
	energy.Shape = Enum.PartType.Ball
	energy.Material = Enum.Material.ForceField
	energy.Color = ENERGY_COLOR
	energy.Size = Vector3.one * BUBBLE_SIZE * 0.94
	local glow = Instance.new("PointLight")
	glow.Color = BOLT_COLOR
	glow.Range = 18
	glow.Brightness = 3
	glow.Parent = glass
	effect.Bubble = glass

	-- The pulse: bigger and smaller, over and over, two beats every 0.4 s.
	local pulse = Instance.new("NumberValue")
	pulse.Name = "Pulse"
	pulse.Parent = holder
	local pulseTween = TweenService:Create(pulse, TweenInfo.new(0.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Value = 1 })
	pulseTween:Play()

	-- Glass shards whirling round the bubble, each on its own tilted orbit.
	local shards = {}
	for index = 1, SHARDS do
		local shard = effectPart("WedgePart", "Shard", holder)
		shard.Material = Enum.Material.Glass
		shard.Color = GLASS_COLOR
		shard.Reflectance = 0.45
		shard.Transparency = 0.25
		shard.Size = Vector3.new(0.08, rng(0.5, 1.1), rng(0.6, 1.2))
		shards[index] = {
			Part = shard,
			Tilt = CFrame.Angles(rng(-1.2, 1.2), rng(0, math.pi * 2), rng(-1.2, 1.2)),
			Speed = rng(6, 12) * (if index % 2 == 0 then 1 else -1),
			Phase = rng(0, math.pi * 2),
			Spin = Vector3.new(rng(-9, 9), rng(-9, 9), rng(-9, 9)),
		}
	end

	-- The cage of lightning, re-drawn every frame.
	local bolts = {}
	for index = 1, BOLTS do
		local segments = {}
		for step = 1, BOLT_SEGMENTS do
			local segment = effectPart("Part", "Bolt", holder)
			segment.Material = Enum.Material.Neon
			segment.Color = BOLT_COLOR
			segment.Size = Vector3.new(0.12, 0.12, 1)
			segments[step] = segment
		end
		bolts[index] = segments
	end

	-- Sparks from inside.
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(BOLT_COLOR)
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	sparks.Lifetime = NumberRange.new(0.15, 0.35)
	sparks.Speed = NumberRange.new(10, 26)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Rate = 25
	sparks.Parent = glass

	local crackle = playSoundAt(CHARGE_SOUND, glass, 0.6, true)

	local started = os.clock()
	table.insert(effect.Connections, RunService.RenderStepped:Connect(function()
		if not root.Parent then
			effect.Cancel()
			return
		end
		local t = os.clock() - started
		if levelByTime then
			effect.Level = math.clamp(t / FULL_CHARGE, 0, 1)
			if t > REMOTE_CHARGE_TIMEOUT then
				effect.Cancel()
				return
			end
		end
		local level = effect.Level
		local wild = 0.4 + level
		local centre = root.Position

		-- Swelling, shrinking and shaking, harder as it fills.
		local size = BUBBLE_SIZE * (1 + 0.22 * level) * (1 + 0.12 * pulse.Value + rng(-0.04, 0.04) * wild)
		glass.Size = Vector3.one * size
		glass.CFrame = CFrame.new(centre + Vector3.new(rng(-1, 1), rng(-1, 1), rng(-1, 1)) * 0.12 * wild)
			* CFrame.Angles(rng(0, 6.28), rng(0, 6.28), 0)
		glass.Transparency = rng(0.25, 0.45)
		energy.Size = Vector3.one * size * rng(0.9, 0.97)
		energy.CFrame = CFrame.new(centre) * CFrame.Angles(t * 5, t * 7, 0)
		glow.Brightness = rng(2, 4 + 4 * level)
		sparks.Rate = 25 + 110 * level
		if crackle then
			crackle.PlaybackSpeed = 1 + 0.5 * level
		end

		local radius = size / 2
		for _, shard in shards do
			local angle = shard.Phase + t * shard.Speed * (1 + level)
			local offset = shard.Tilt * Vector3.new(math.cos(angle), 0, math.sin(angle)) * (radius + 0.7)
			local spin = shard.Spin * t
			shard.Part.CFrame = CFrame.new(centre + offset) * CFrame.Angles(spin.X, spin.Y, spin.Z)
		end

		for index, segments in bolts do
			-- Flickering on and off, more of them the fuller it is.
			local on = math.random() < 0.55 + 0.4 * level
			local angle = t * (9 + 6 * level) + index * (2 * math.pi / BOLTS)
			local latitude = math.sin(t * 5 + index) * 1.1
			local from = centre + onSphere(angle, latitude) * (radius + 0.2)
			local to = centre + onSphere(angle + rng(1, 2.2), -latitude * rng(0.4, 1)) * (radius + 0.2)
			local previousPoint = from
			local width = rng(0.06, 0.16) * (1 + level)
			for step, segment in segments do
				local point = to
				if step < BOLT_SEGMENTS then
					local along = from:Lerp(to, step / BOLT_SEGMENTS) + Vector3.new(rng(-1, 1), rng(-1, 1), rng(-1, 1)) * (0.7 + 0.6 * level)
					local out = along - centre
					point = centre + (if out.Magnitude > 0.01 then out.Unit else Vector3.yAxis) * (radius + rng(0, 0.6))
				end
				local length = (point - previousPoint).Magnitude
				segment.Transparency = if on then 0 else 1
				segment.Size = Vector3.new(width, width, math.max(0.1, length))
				segment.CFrame = CFrame.lookAt((previousPoint + point) / 2, point)
				previousPoint = point
			end
		end
	end))

	function effect.SetLevel(value)
		effect.Level = math.clamp(tonumber(value) or 0, 0, 1)
	end

	function effect.Cancel()
		if not effect.Alive then
			return
		end
		effect.Alive = false
		for _, connection in effect.Connections do
			connection:Disconnect()
		end
		pulseTween:Cancel()
		holder:Destroy()
		if active[character] == effect then
			active[character] = nil
		end
	end

	active[character] = effect
	return effect
end

----------------------------------------------------------------------
-- The throw (the local player's own character only)
----------------------------------------------------------------------
local dashing = nil

local function endDash()
	local state = dashing
	if not state then
		return
	end
	dashing = nil
	state.Connection:Disconnect()
	if state.Character.Parent then
		state.Character:SetAttribute(DASH_ATTRIBUTE, nil)
	end
end

-- A mouse whose cursor is free to point (not shift-lock), being used right now.
local POINTER_INPUTS = {
	[Enum.UserInputType.MouseMovement] = true,
	[Enum.UserInputType.MouseButton1] = true,
	[Enum.UserInputType.MouseButton2] = true,
	[Enum.UserInputType.MouseWheel] = true,
	[Enum.UserInputType.Keyboard] = true,
}

-- Where the player aims: at the ground under the mouse pointer, else where the camera looks
-- (shift-lock centres the mouse; gamepads and touch screens steer with the camera).
local function aimDirection(character)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local fallback = root and root.CFrame.LookVector
	local camera = Workspace.CurrentCamera
	if not camera then
		return SonicBurstMath.FlatDirection(fallback)
	end
	local pointer = POINTER_INPUTS[UserInputService:GetLastInputType()] == true
		and UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter
		and not UserInputService.TouchEnabled
	if pointer and root then
		local mouse = UserInputService:GetMouseLocation()
		local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
		return SonicBurstMath.AimAt(root.Position, ray.Origin, ray.Direction, camera.CFrame.LookVector)
	end
	return SonicBurstMath.FlatDirection(camera.CFrame.LookVector, fallback)
end

local function dash(character, charge)
	endDash()
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return
	end
	local velocity = root.AssemblyLinearVelocity
	local speed = SonicBurstMath.ReferenceSpeed(player:GetAttribute("RealWalkSpeedSelected"), Vector3.new(velocity.X, 0, velocity.Z).Magnitude)
	local dashSpeed = SonicBurstMath.DashSpeed(speed, Config, charge)
	local direction = aimDirection(character)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, runtimeFolder() }
	params.RespectCanCollide = true

	local started = os.clock()
	character:SetAttribute(DASH_ATTRIBUTE, true)
	local state = { Character = character }
	state.Connection = RunService.Heartbeat:Connect(function(dt)
		if os.clock() - started >= DASH
			or not root.Parent
			or humanoid.Health <= 0
			or character:GetAttribute("Ragdolled") == true
		then
			endDash()
			return
		end
		-- Steered while it lasts: toward the pointer, or where the camera turns.
		direction = SonicBurstMath.Steer(direction, aimDirection(character), dt)
		humanoid:Move(direction, false)
		-- Stop short of a wall rather than go through it at this speed.
		local ahead = Workspace:Spherecast(root.Position, WALL_PROBE_RADIUS, direction * (dashSpeed * dt + 1.5), params)
		if ahead then
			root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
			endDash()
			return
		end
		root.AssemblyLinearVelocity = Vector3.new(direction.X * dashSpeed, root.AssemblyLinearVelocity.Y, direction.Z * dashSpeed)
	end)
	dashing = state
end

----------------------------------------------------------------------
-- The burst (any character's; the throw and the screen only for the local player)
----------------------------------------------------------------------
local function burst(character, effect, charge, isLocal)
	local centre, radius
	if effect and effect.Alive then
		centre, radius = effect.Bubble.Position, effect.Bubble.Size.X / 2
		effect.Cancel()
	else
		local root = character:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end
		centre, radius = root.Position, BUBBLE_SIZE / 2
	end
	local level = math.clamp(tonumber(charge) or 1, 0, 1)
	-- The glass flies apart in the world for everyone; the owner hears its own screen's.
	GlassBurst.Sphere(centre, radius, { Speed = 120 + 220 * level, Color = GLASS_COLOR, Sound = not isLocal and soundsOn(), Volume = 0.9 })
	if soundsOn() and BOOM_SOUND ~= "" then
		local holder = Instance.new("Attachment")
		holder.WorldCFrame = CFrame.new(centre)
		holder.Parent = Workspace.Terrain
		playSoundAt(BOOM_SOUND, holder, 0.8)
		Debris:AddItem(holder, 4)
	end
	if isLocal and character == player.Character then
		local shatter = table.clone(SHATTER)
		shatter.Intensity = 1.6 + 1.0 * level
		shatter.PlaySound = soundsOn()
		task.defer(GlassShatter.Play, shatter)
		CameraPunch.Fov(FOV_PUNCH)
		dash(character, level)
	end
end

----------------------------------------------------------------------
-- Charging (the local player)
----------------------------------------------------------------------
local cooldownEndsAt = 0
local lastBurstAt = -math.huge
local charging = nil -- { StartedAt, StartStamina, SprintSeconds, Level, Shown, Effect, Screen }

local function equipped()
	return player:GetAttribute("SonicBurstEquipped") == true
end

local function characterReady(character)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return humanoid ~= nil and humanoid.Health > 0 and root ~= nil
		and character:GetAttribute("Ragdolled") ~= true
		and character:GetAttribute("Dead") ~= true
		and player:GetAttribute("FlightAbilityActive") ~= true
		and player:GetAttribute("AdminFlying") ~= true
		and character:GetAttribute("FlightAbilityLocalActive") ~= true
		and not humanoid.Sit
end

local function currentStamina()
	for _, name in { "CurrentStamina", "BoostStamina", "TrueBoostStamina" } do
		local value = tonumber(player:GetAttribute(name))
		if value then
			return value
		end
	end
	return 0
end

local function stopChargeVisuals(state)
	if state.Effect then
		state.Effect.Cancel()
	end
	if state.Screen then
		state.Screen.Stop()
	end
end

-- The bubble and the trembling glass come up, and every client is told (once a charge).
local function showCharge(state, character)
	state.Shown = true
	state.Effect = startBubble(character, false)
	state.Screen = GlassShatter.Charge({ Always = true })
	Action:FireServer("Charge")
end

local function startCharge()
	if charging or not equipped() or os.clock() < cooldownEndsAt then
		return
	end
	if player:GetAttribute("SpeedsterMenuOpen") == true or UserInputService:GetFocusedTextBox() then
		return
	end
	if not characterReady(player.Character) then
		return
	end
	charging = {
		StartedAt = os.clock(),
		StartStamina = currentStamina(),
		SprintSeconds = 0,
		Level = 0,
		Shown = false,
	}
end

local function cancelCharge()
	local state = charging
	if not state then
		return
	end
	charging = nil
	stopChargeVisuals(state)
	if state.Shown then
		Action:FireServer("Cancel")
	end
end

local function releaseCharge()
	local state = charging
	if not state then
		return
	end
	charging = nil
	local character = player.Character
	-- A tap of the sprint is only a sprint; too little charge is only the end of one.
	if not state.Shown or state.Level < SonicBurstMath.MinCharge or not characterReady(character) then
		stopChargeVisuals(state)
		if state.Shown then
			Action:FireServer("Cancel")
		end
		return
	end
	if state.Screen then
		state.Screen.Stop()
	end
	cooldownEndsAt = os.clock() + COOLDOWN
	lastBurstAt = os.clock()
	Action:FireServer("Fire", { Direction = aimDirection(character), Charge = state.Level })
	burst(character, state.Effect, state.Level, true)
end

-- Every frame while charging: the charge from the stamina spent, the bubble and the glass.
RunService.Heartbeat:Connect(function(dt)
	local state = charging
	if not state then
		return
	end
	local character = player.Character
	if not equipped() or not characterReady(character) then
		cancelCharge()
		return
	end
	-- Holding the sprint charges it, running or standing still (2026-09-18: standing, it
	-- charged nothing and letting go only moved the camera). Running, the charge is the
	-- stamina the hold spends; standing still it costs no stamina and fills with time. The
	-- bubble comes up once the charge has begun.
	state.SprintSeconds += dt
	state.Level = SonicBurstMath.ChargeLevel(state.StartStamina, currentStamina(), state.SprintSeconds, DRAIN, state.Level)
	if not state.Shown and state.SprintSeconds >= SHOW_AFTER then
		showCharge(state, character)
	end
	if state.Effect then
		state.Effect.SetLevel(state.Level)
	end
	if state.Screen then
		state.Screen.SetLevel(state.Level)
	end
end)

Update.OnClientEvent:Connect(function(message)
	if type(message) ~= "table" then
		return
	end
	local who = message.Player
	if message.Kind == "Denied" then
		-- Refused (not ready, or still recharging on the server): call off a charge, and
		-- wait as long as the server says.
		cancelCharge()
		local readyIn = tonumber(message.ReadyIn)
		if readyIn and readyIn > 0 then
			cooldownEndsAt = math.max(cooldownEndsAt, os.clock() + math.min(readyIn, COOLDOWN))
		end
		return
	end
	if typeof(who) ~= "Instance" or not who:IsA("Player") or who == player then
		-- This client drew its own charge and burst already.
		return
	end
	local character = who.Character
	if not character then
		return
	end
	if message.Kind == "Charge" then
		startBubble(character, true)
	elseif message.Kind == "ChargeEnd" then
		local effect = active[character]
		if effect then
			effect.Cancel()
		end
	elseif message.Kind == "Burst" then
		burst(character, active[character], message.Charge, false)
	end
end)

----------------------------------------------------------------------
-- Holding the sprint
----------------------------------------------------------------------
-- A phone or tablet (no keyboard, no gamepad) uses its Burst button; everything else the
-- sprint itself (Shift, or the gamepad's sprint trigger).
local function touchOnly()
	local last = UserInputService:GetLastInputType()
	return UserInputService.TouchEnabled
		and not UserInputService.KeyboardEnabled
		and not last.Name:find("Gamepad")
		and not GuiService:IsTenFootInterface()
end

player:GetAttributeChangedSignal("SprintHeld"):Connect(function()
	if touchOnly() then
		return
	end
	-- Update 4 (2026-09-25): in a race Shift and the triggers charge the start and sprint
	-- (Race/RaceInputClient); a burst never charges there, and one already charging is called off.
	if player:GetAttribute("RaceActive") == true then
		cancelCharge()
		return
	end
	if player:GetAttribute("SprintHeld") == true then
		startCharge()
	else
		releaseCharge()
	end
end)
player:GetAttributeChangedSignal("RaceActive"):Connect(function()
	if player:GetAttribute("RaceActive") == true then
		cancelCharge()
	end
end)

----------------------------------------------------------------------
-- The touch button (phones and tablets only; PC and consoles charge with the sprint key)
----------------------------------------------------------------------
local playerGui = player:WaitForChild("PlayerGui")
local mainhud = playerGui:WaitForChild("Mainhud", 30)
local button = nil
local boostControl = player:WaitForChild("PlayerScripts"):WaitForChild("SpeedsterBoostControl", 10)
local hudVisible = true

-- Declared ahead: the HUD-visibility handler below calls it (a later `local function`
-- would leave that call on a nil global).
local layoutButton

MenuEvents.HUDVisibilityChanged.Event:Connect(function(visible)
	hudVisible = (visible == true)
	if hudVisible and button then
		layoutButton()
	end
end)

function layoutButton()
	if not button or not mainhud or not mainhud:IsA("ScreenGui") then
		return
	end
	local hud = mainhud.AbsoluteSize
	if hud.X <= 0 or hud.Y <= 0 then
		return
	end
	local camera = Workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or hud
	local topBar = (GuiService:GetGuiInset()).Y
	-- Clear of the phone column's boost cards and speedometer (Main HUD pixels), or where the
	-- player moved it ("Move controls" in Settings) when that place is legal on this screen.
	local neighbours = HudErgonomics.TouchNeighbours(viewport.X, viewport.Y, UserInputService.KeyboardEnabled, topBar)
	local layout = if UserInputService.TouchEnabled then player:GetAttribute("TouchLayout") else nil
	local plan = HudErgonomics.TouchControls(hud.X, hud.Y, layout, neighbours, button.Visible).B
	button.Size = UDim2.fromOffset(plan.Size, plan.Size)
	local basePos = UDim2.fromOffset(math.floor(plan.X + 0.5), math.floor(plan.Y + 0.5))
	-- MainHUDController slides the button back to this place when the HUD shows again
	-- (2026-09-25): a layout change while a menu is open must not leave it a stale target.
	button:SetAttribute("HudBasePosition", basePos)
	if hudVisible then
		button.Position = basePos
	end
end

local function refreshButton()
	if button then
		button.Visible = equipped() and touchOnly()
		SonicBurstUi.Round(button)
		layoutButton()
	end
end

if mainhud then
	button = mainhud:FindFirstChild(SonicBurstUi.ButtonName) or mainhud:WaitForChild(SonicBurstUi.ButtonName, 5)
	if not button then
		-- A place without the saved button: the designer's Sprint button, made the same way.
		local sprint = mainhud:FindFirstChild("MobileSprint")
		if sprint then
			button = SonicBurstUi.DecorateButton(sprint:Clone())
			button.Parent = mainhud
		end
	end
end

if button then
	local BURST_GRADIENT = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(160, 245, 255)),
		ColorSequenceKeypoint.new(0.55, Color3.fromRGB(0, 190, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 105, 225)),
	})
	local burstGradient = button:FindFirstChildOfClass("UIGradient")
	if not burstGradient then
		burstGradient = Instance.new("UIGradient")
		burstGradient.Rotation = 90
		burstGradient.Color = BURST_GRADIENT
		burstGradient.Parent = button
	else
		burstGradient.Rotation = 90
		burstGradient.Color = BURST_GRADIENT
	end
	button.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextStrokeColor3 = Color3.fromRGB(11, 27, 61)
	button.TextStrokeTransparency = 0
	pcall(function()
		button.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	end)

	local authoredText = button.Text
	local authoredTransparency = button.BackgroundTransparency
	local press = button:FindFirstChild("PressScale")
	local label = button:FindFirstChild("Label")
	if not label or not label:IsA("TextLabel") then
		label = Instance.new("TextLabel")
		label.Name = "Label"
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Position = UDim2.fromScale(0.5, 0.5)
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Text = authoredText
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.TextStrokeColor3 = Color3.fromRGB(11, 27, 61)
		label.TextStrokeTransparency = 0
		label.TextScaled = true
		label.ZIndex = 5
		pcall(function()
			label.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
		end)
		label.Parent = button
	end
	local sprintBefore = false
	local holding = nil

	button.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end
		-- No burst in the race arena (Update 4): the race's own button sprints there.
		if holding or os.clock() < cooldownEndsAt or player:GetAttribute("RaceActive") == true then
			return
		end
		holding = input
		if press and press:IsA("UIScale") then
			TweenService:Create(press, TweenInfo.new(0.06), { Scale = 0.86 }):Play()
		end
		-- Held, it sprints (the same stamina bar drains) and charges.
		sprintBefore = player:GetAttribute("SprintHeld") == true
		if boostControl then
			boostControl:Fire(true)
		end
		startCharge()
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input ~= holding then
			return
		end
		holding = nil
		if press and press:IsA("UIScale") then
			TweenService:Create(press, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
		releaseCharge()
		if boostControl and not sprintBefore then
			boostControl:Fire(false)
		end
	end)

	-- Its text: the charge while held, the seconds while it recharges.
	task.spawn(function()
		while button.Parent do
			task.wait(0.1)
			local left = cooldownEndsAt - os.clock()
			local currentText
			if charging and charging.Shown then
				currentText = tostring(math.floor(charging.Level * 100)) .. "%"
				button.BackgroundTransparency = authoredTransparency
			elseif left > 0 then
				currentText = tostring(math.ceil(left)) .. "s"
				button.BackgroundTransparency = math.min(1, authoredTransparency + 0.45)
			else
				currentText = authoredText
				button.BackgroundTransparency = authoredTransparency
			end
			button.Text = currentText
			if label then
				label.Text = currentText
			end
		end
	end)

	mainhud:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutButton)
	player:GetAttributeChangedSignal("TouchLayout"):Connect(layoutButton)
	UserInputService.LastInputTypeChanged:Connect(refreshButton)
end
player:GetAttributeChangedSignal("SonicBurstEquipped"):Connect(refreshButton)
refreshButton()

----------------------------------------------------------------------
-- The stamina bar's hint (MainHUDController shows SonicBurstHint in the bar)
----------------------------------------------------------------------
local function hintText()
	if not equipped() then
		return nil
	end
	if charging and charging.Shown then
		return "Release to Burst! " .. tostring(math.floor(charging.Level * 100)) .. "%"
	end
	local left = cooldownEndsAt - os.clock()
	if left > 0 then
		return "Sonic Burst in " .. tostring(math.ceil(left)) .. "s"
	end
	local flight = player:GetAttribute("FlightAbilityEquipped") == true
	local last = UserInputService:GetLastInputType()
	if last.Name:find("Gamepad") or GuiService:IsTenFootInterface() then
		return if flight then "L2: Charge the run | A / RB: Fly" else "Hold L2 to charge the run"
	elseif touchOnly() then
		return "Hold Burst to charge the run"
	end
	return if flight then "Shift: Charge the run | Space: Fly" else "Hold Shift to charge the run"
end

task.spawn(function()
	while true do
		local text = hintText()
		if player:GetAttribute(HINT_ATTRIBUTE) ~= text then
			player:SetAttribute(HINT_ATTRIBUTE, text)
		end
		task.wait(0.1)
	end
end)

----------------------------------------------------------------------
-- Clean-up: a character that dies, respawns or leaves takes its burst with it
----------------------------------------------------------------------
local function dropCharacter(character)
	local effect = character and active[character]
	if effect then
		effect.Cancel()
	end
	if dashing and dashing.Character == character then
		endDash()
	end
	if character and character == player.Character then
		cancelCharge()
	end
end

local function watchPlayer(other)
	other.CharacterRemoving:Connect(dropCharacter)
	local function onCharacter(character)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid then
			humanoid.Died:Connect(function()
				dropCharacter(character)
			end)
		end
	end
	if other.Character then
		task.spawn(onCharacter, other.Character)
	end
	other.CharacterAdded:Connect(onCharacter)
end
Players.PlayerAdded:Connect(watchPlayer)
for _, other in Players:GetPlayers() do
	watchPlayer(other)
end
Players.PlayerRemoving:Connect(function(other)
	dropCharacter(other.Character)
end)
