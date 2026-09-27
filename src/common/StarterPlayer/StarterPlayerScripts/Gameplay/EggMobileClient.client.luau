-- StarterPlayer/StarterPlayerScripts/Gameplay/EggMobileClient.client.luau — Update 4 (2026-09-26,
-- owner): Dr. Eggman's Egg Mobile comes alive on each client ("the ship's plasma must be
-- animated... NO sparkles"). The ship is built by audit/u4_egg_mobile (Shared/EggMobile, from the
-- owner's Blender kit; 2026-09-26: no part-built ship any more, no ship at all without the kit) inside
-- the Eggman model, its hull welded to his HumanoidRootPart; Gameplay/LobbyNpcs adopts him (his
-- root anchored, the rest of the rig and the ship unanchored and held by it, the model tagged
-- LobbyNpcEggman and streamed Atomic) and Gameplay/LobbyNpcsClient plays his "EggmanDriving" pose.
-- Here, found by that tag as the model streams in and out:
--   * Hover: the whole ship and Eggman bob, pitch, yaw and roll (Shared/EggMobile.HoverValues, a
--     pure function of the server clock: frame-rate independent, the same moment for everyone),
--     by moving his anchored root: one CFrame write a frame moves the ~30 MeshParts. The rear fan
--     spins in its nozzle, each red lever tilts toward its fist (read from his joints) and lets go
--     when the fist leaves its grip (a gesture), all on their Motor6Ds (a siren, if a kit has one,
--     turns). Only within the tier's MotionRadius of the camera and while the ship is on screen;
--     the ship goes back to its rest frame when that stops.
--   * Plasma: Beams with LightEmission 1 and no texture (never particles, never sparkles): the
--     cone of plasma under the hull (and its hot core on High), the nozzle's jet; the Neon emitter,
--     exhaust, lamps, dash lights and screen pulse. 2026-09-26 (owner): no cyan PointLight (it
--     washed the ship and Eggman blue), no spotlight from the sky, no gear on the sign: only the
--     exhaust flame and the plasma pulse glow. Tiered by Shared/RaceFeelTier
--     (EggMobile.Client.Tiers): Low (phones under 30 FPS) gets the hover at 20 Hz within 70 studs,
--     one plasma beam, no lights, no pulse.
--   * The QUESTS sign (a BillboardGui over the ship: the word in the player's language and the
--     blue "!" bouncing while a quest reward or choice waits), within EggMobile.Client.Sign.MaxDistance.
-- Workspace.U4Off_Npcs (the NPC kill switch) stops all of it and hides the sign, live.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local EggMobile = require(Shared:WaitForChild("EggMobile"))
local LobbyNpcConfig = require(Shared:WaitForChild("LobbyNpcConfig"))
local LobbyNpcPose = require(Shared:WaitForChild("LobbyNpcPose"))
local LobbyNpcRig = require(Shared:WaitForChild("LobbyNpcRig"))
local LobbyNpcText = require(Shared:WaitForChild("LobbyNpcText"))
local RaceFeelTier = require(Shared:WaitForChild("RaceFeelTier"))

local CLIENT = EggMobile.Client
local COLORS = EggMobile.Colors
local TAU = math.pi * 2
local FIST = Vector3.new(0, -0.75, 0) -- an R6 arm's fist, in the arm's frame
-- A fist further than the lever's length (plus a little) from its pivot has let go of it (2026-09-26:
-- tighter than before, so the "come here" hand, which passes over its lever, does not drag it along).
local GRIP_SLACK, GRIP_FADE = 0.05, 0.15
local SIGN_NAME = "EggMobileQuestSign"
local SIGN_BOB = TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local MARK_BOUNCE = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)

local lang = LobbyNpcText.ForPlayer(player)

local function rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end
local function serverNow(): number
	return Workspace:GetServerTimeNow()
end
local function killed(): boolean
	return Workspace:GetAttribute(LobbyNpcConfig.KillAttribute) == true
end
local function questWaiting(): boolean
	return player:GetAttribute("QuestRewardReady") == true or player:GetAttribute("QuestAvailable") == true
end

local PLASMA, PLASMA_HOT = rgb(COLORS.Plasma), rgb(COLORS.PlasmaHot)
local LAMP_HOT, DASH_HOT = rgb(COLORS.LampHot), Color3.fromRGB(255, 190, 190)

----------------------------------------------------------------------
-- Tier (Shared/RaceFeelTier: phones under 30 FPS are Low)
----------------------------------------------------------------------
local meter = RaceFeelTier.NewMeter()
local tier = RaceFeelTier.Detect(nil)
local tierClock = 0

----------------------------------------------------------------------
-- The ships
----------------------------------------------------------------------
type Glow = { part: BasePart, kind: string, color: Color3 }
type Stick = { motor: Motor6D, side: number, length: number, shoulder: Motor6D?, rootJoint: Motor6D? }
type Ship = {
	eggman: Model,
	model: Model,
	root: BasePart,
	hull: BasePart,
	anchor: BasePart?,
	restRoot: CFrame,
	pivot: CFrame, -- the hull's rest frame (the hull centre, ship axes)
	pivotToRoot: CFrame,
	floor: CFrame, -- the ship's floor frame at rest
	canMove: boolean,
	moved: boolean,
	fans: { { motor: Motor6D, side: number } },
	sticks: { Stick },
	siren: Motor6D?,
	glows: { Glow },
	made: { Instance }, -- attachments, beams and lights this script added (destroyed with the VFX)
	vfxTier: string?,
	plasmaBeams: { Beam },
	exhaust: { { beam: Beam, tip: Attachment, rest: Vector3 } },
	sirenLight: PointLight?,
	sign: BillboardGui?,
	signAnchor: Attachment?,
	signStroke: UIStroke?,
	mark: TextLabel?,
	tweens: { Tween },
	markTween: Tween?,
	nextStep: number,
	nextSignCheck: number,
	connections: { RBXScriptConnection },
}
local ships: { [Model]: Ship } = {}

-- A point of ship space as an Attachment on `part` (whose rest frame is `rest`), destroyed with
-- the VFX unless `keep`.
local function attach(ship: Ship, part: BasePart, rest: CFrame, name: string, point: { number }, keep: boolean?): Attachment
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.Position = rest:PointToObjectSpace(ship.floor * Vector3.new(point[1], point[2], point[3]))
	attachment.Parent = part
	if not keep then
		table.insert(ship.made, attachment)
	end
	return attachment
end

local function newBeam(ship: Ship, name: string, a0: Attachment, a1: Attachment, color: Color3, width0: number, width1: number, transparency: NumberSequence): Beam
	local beam = Instance.new("Beam")
	beam.Name = name
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Color = ColorSequence.new(color)
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Transparency = transparency
	beam.Width0 = width0
	beam.Width1 = width1
	beam.FaceCamera = true
	beam.Segments = 1
	beam.Texture = "" -- a soft solid ribbon: no texture, no particles
	beam.Parent = a0.Parent
	table.insert(ship.made, beam)
	return beam
end

local function fade(points: { { number } }): NumberSequence
	local keys = {}
	for _, p in points do
		table.insert(keys, NumberSequenceKeypoint.new(p[1], p[2]))
	end
	return NumberSequence.new(keys)
end

local function clearVfx(ship: Ship)
	for _, instance in ship.made do
		instance:Destroy()
	end
	table.clear(ship.made)
	table.clear(ship.plasmaBeams)
	table.clear(ship.exhaust)
	ship.sirenLight, ship.vfxTier = nil, nil
	for _, glow in ship.glows do
		if glow.part.Parent then
			glow.part.Color = glow.color
		end
	end
end

-- The beams and lights of the current tier (rebuilt when the tier changes).
local function buildVfx(ship: Ship)
	if ship.vfxTier == tier then
		return
	end
	clearVfx(ship)
	local budget = CLIENT.Tiers[tier] or CLIENT.Tiers.Low
	local points = EggMobile.Points
	local hull, pivot = ship.hull, ship.pivot
	local anchor = ship.anchor or hull
	local anchorRest = if ship.anchor then ship.anchor.CFrame else pivot
	local top = attach(ship, hull, pivot, "EggPlasmaTop", points.PlasmaTop)
	local ground = attach(ship, anchor, anchorRest, "EggPlasmaFloor", points.PlasmaFloor)
	table.insert(ship.plasmaBeams, newBeam(ship, "EggPlasmaCone", top, ground, PLASMA, 2.8, 5.2,
		fade({ { 0, 0.25 }, { 0.55, 0.65 }, { 1, 1 } })))
	if budget.PlasmaBeams >= 2 then
		table.insert(ship.plasmaBeams, newBeam(ship, "EggPlasmaCore", top, ground, PLASMA_HOT, 1.3, 2.4,
			fade({ { 0, 0.1 }, { 0.7, 0.75 }, { 1, 1 } })))
	end
	if budget.Exhaust then
		for index, point in points.Exhaust do
			local base = attach(ship, hull, pivot, "EggExhaust" .. index, point)
			local tip = attach(ship, hull, pivot, "EggExhaustTip" .. index, { point[1], point[2], point[3] + points.ExhaustLength })
			local beam = newBeam(ship, "EggExhaustJet", base, tip, PLASMA, 1.25, 0.15, fade({ { 0, 0.1 }, { 0.6, 0.55 }, { 1, 1 } }))
			table.insert(ship.exhaust, { beam = beam, tip = tip, rest = tip.Position })
		end
	end
	-- 2026-09-26 (owner): no spotlight Beam from the sky and no cyan PointLight under the hull
	-- (it lit the whole ship and Eggman blue); the plasma beams and the exhaust stay.
	if budget.SirenLight and ship.siren and ship.siren.Part1 then
		local light = Instance.new("PointLight")
		light.Name = "EggSirenLight"
		light.Color = rgb(COLORS.Siren)
		light.Range = 9
		light.Brightness = 0
		light.Shadows = false
		light.Parent = ship.siren.Part1
		table.insert(ship.made, light)
		ship.sirenLight = light
	end
	ship.vfxTier = tier
end

----------------------------------------------------------------------
-- The QUESTS sign
----------------------------------------------------------------------
local function syncMark(ship: Ship)
	local mark = ship.mark
	if not mark then
		return
	end
	local show = questWaiting()
	if mark.Visible == show then
		return
	end
	mark.Visible = show
	if ship.markTween then
		ship.markTween:Cancel()
		ship.markTween = nil
	end
	local scale = mark:FindFirstChild("Bounce")
	if show and scale and scale:IsA("UIScale") then
		scale.Scale = 1
		ship.markTween = TweenService:Create(scale, MARK_BOUNCE, { Scale = 1.22 })
		ship.markTween:Play()
	end
end

local function corner(parent: Instance, scale: number)
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(scale, 0)
	round.Parent = parent
end

local function stroke(parent: Instance, color: Color3, thickness: number): UIStroke
	local line = Instance.new("UIStroke")
	line.Color = color
	line.Thickness = thickness
	line.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	line.Parent = parent
	return line
end

local function gradient(parent: Instance, top: Color3, middle: Color3, bottom: Color3)
	local fill = Instance.new("UIGradient")
	fill.Rotation = 90
	fill.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, top), ColorSequenceKeypoint.new(0.5, middle), ColorSequenceKeypoint.new(1, bottom),
	})
	fill.Parent = parent
end

local GOLD_TOP, GOLD_MID, GOLD_LOW = Color3.fromRGB(255, 246, 150), Color3.fromRGB(255, 202, 40), Color3.fromRGB(226, 128, 0)
local GOLD_EDGE = Color3.fromRGB(120, 60, 0)

local function buildSign(ship: Ship)
	if ship.sign or not ship.anchor then
		return
	end
	local config = CLIENT.Sign
	local adornee = attach(ship, ship.anchor, ship.anchor.CFrame, "EggSign", EggMobile.Points.Sign, true)
	local gui = Instance.new("BillboardGui")
	gui.Name = SIGN_NAME
	gui.Adornee = adornee
	gui.Size = UDim2.new(config.Studs[1], config.Pixels[1], config.Studs[2], config.Pixels[2])
	gui.MaxDistance = config.MaxDistance
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	gui.ResetOnSpawn = false
	gui.AutoLocalize = false
	gui.Active = false
	gui.ClipsDescendants = false
	gui.Enabled = not killed()

	local word = Instance.new("TextLabel")
	word.Name = "Word"
	word.BackgroundTransparency = 1
	word.AnchorPoint = Vector2.new(0.5, 0)
	word.Position = UDim2.fromScale(0.5, 0)
	word.Size = UDim2.fromScale(1, 0.56)
	word.Font = Enum.Font.FredokaOne
	word.Text = EggMobile.SignWord(lang)
	word.TextScaled = true
	word.TextColor3 = Color3.new(1, 1, 1)
	word.ZIndex = 4
	word.Parent = gui
	gradient(word, Color3.fromRGB(225, 248, 255), Color3.fromRGB(120, 210, 255), Color3.fromRGB(40, 140, 245))
	local outline = Instance.new("UIStroke")
	outline.Name = "Outline"
	outline.Color = Color3.fromRGB(14, 42, 110)
	outline.Thickness = 4
	outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	outline.LineJoinMode = Enum.LineJoinMode.Round
	outline.Parent = word
	LobbyNpcText.Style(word, lang)
	ship.signStroke = outline

	local mark = Instance.new("TextLabel")
	mark.Name = "Mark"
	mark.BackgroundTransparency = 1
	mark.AnchorPoint = Vector2.new(0.5, 0.5)
	mark.Position = UDim2.fromScale(0.65, 0.77)
	mark.Size = UDim2.fromScale(0.2, 0.46)
	mark.Rotation = 12
	mark.Font = Enum.Font.FredokaOne
	mark.Text = "!"
	mark.TextScaled = true
	mark.TextColor3 = Color3.new(1, 1, 1)
	mark.Visible = false
	mark.ZIndex = 4
	mark.Parent = gui
	gradient(mark, Color3.fromRGB(150, 220, 255), Color3.fromRGB(40, 150, 255), Color3.fromRGB(20, 80, 220))
	local markLine = Instance.new("UIStroke")
	markLine.Color = Color3.new(1, 1, 1)
	markLine.Thickness = 3
	markLine.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	markLine.Parent = mark
	local bounce = Instance.new("UIScale")
	bounce.Name = "Bounce"
	bounce.Parent = mark
	gui.Parent = playerGui
	ship.sign, ship.signAnchor, ship.mark = gui, adornee, mark

	local bob = TweenService:Create(gui, SIGN_BOB, { StudsOffsetWorldSpace = Vector3.new(0, 0.45, 0) })
	bob:Play()
	table.insert(ship.tweens, bob)
	syncMark(ship)
end

-- The outline follows the sign's size on screen (a fixed 4 px would swamp it far away).
local function fitSignStroke(ship: Ship, camera: Camera, distance: number)
	local line = ship.signStroke
	if not line then
		return
	end
	local fov = math.rad(camera.FieldOfView)
	local perStud = camera.ViewportSize.Y / (2 * math.max(distance, 1) * math.tan(fov / 2))
	local height = CLIENT.Sign.Studs[2] * perStud + CLIENT.Sign.Pixels[2]
	local thickness = math.floor(math.clamp(height * 0.035, 1.5, 5) * 2 + 0.5) / 2
	if line.Thickness ~= thickness then
		line.Thickness = thickness
	end
end

----------------------------------------------------------------------
-- Motion
----------------------------------------------------------------------
-- Back to the frame the server gave it (and the joysticks upright).
local function rest(ship: Ship)
	if not ship.moved then
		return
	end
	ship.moved = false
	if ship.root.Parent then
		ship.root.CFrame = ship.restRoot
	end
end

-- Each stick points at its fist (FK from Eggman's joints as posed now); a fist that has let go
-- (the fist pump) leaves it upright.
local function aimSticks(ship: Ship, rootNow: CFrame, hullNow: CFrame)
	for _, stick in ship.sticks do
		local rootJoint, shoulder = stick.rootJoint, stick.shoulder
		if rootJoint and shoulder and rootJoint.Parent and shoulder.Parent then
			local torso = rootNow * rootJoint.C0 * rootJoint.Transform * rootJoint.C1:Inverse()
			local arm = torso * shoulder.C0 * shoulder.Transform * shoulder.C1:Inverse()
			local fist = arm * FIST
			local rel = (hullNow * stick.motor.C0):PointToObjectSpace(fist)
			local hold = math.clamp((stick.length + GRIP_SLACK - rel.Magnitude) / GRIP_FADE, 0, 1)
			local rx, rz = EggMobile.StickAngles(rel.X, rel.Y, rel.Z)
			stick.motor.Transform = CFrame.Angles(rx * hold, 0, rz * hold)
		end
	end
end

local function pulse(ship: Ship, t: number, budget: any)
	if budget.Pulse then
		local beat = 0.5 + 0.5 * math.sin(TAU * 1.6 * t)
		local flicker = 0.5 + 0.5 * math.sin(TAU * 9.3 * t) * math.sin(TAU * 3.1 * t + 1)
		for _, glow in ship.glows do
			local kind = glow.kind
			local k
			local hot = PLASMA_HOT
			if kind == "Plasma" or kind == "PlasmaCore" or kind == "Hub" then
				k = 0.25 + 0.55 * beat
			elseif kind == "Exhaust" then
				k = 0.2 + 0.7 * flicker
			elseif kind == "Headlight" or kind == "HeadlightCore" or kind == "Screen" then
				k = 0.2 + 0.3 * (0.5 + 0.5 * math.sin(TAU * 0.6 * t))
			elseif kind == "Lamp" then
				-- 2026-09-26: the classic ship's yellow lamps breathe toward warm white.
				k, hot = 0.1 + 0.35 * (0.5 + 0.5 * math.sin(TAU * 0.45 * t)), LAMP_HOT
			elseif kind == "DashLight" then
				k, hot = 0.5 + 0.5 * math.sin(TAU * 1.3 * t + glow.part.Position.X), DASH_HOT
			end
			if k then
				glow.part.Color = glow.color:Lerp(hot, k)
			end
		end
		for index, beam in ship.plasmaBeams do
			local w = if index == 1 then 2.8 else 1.3
			beam.Width0 = w * (0.9 + 0.2 * beat)
			beam.Width1 = w * (1.75 + 0.3 * beat)
		end
		for index, jet in ship.exhaust do
			local f = 0.5 + 0.5 * math.sin(TAU * 11 * t + index * 2.1) * math.sin(TAU * 4.3 * t + index)
			jet.beam.Width0 = 1.05 + 0.35 * f
			-- The jet's tip flickers along the hull's Z (ship axes: straight back).
			jet.tip.Position = jet.rest + Vector3.new(0, 0, (f - 0.5) * 1.1)
		end
	end
	if ship.sirenLight and ship.siren then
		local angle = (t * CLIENT.SirenSpeed) % TAU
		ship.sirenLight.Brightness = 3.5 * math.abs(math.sin(angle))
	end
end

local function step(ship: Ship, t: number, budget: any)
	if ship.canMove then
		local hover = EggMobile.HoverCFrame(t, CFrame)
		local hullNow = ship.pivot * hover
		local rootNow = hullNow * ship.pivotToRoot
		ship.root.CFrame = rootNow
		ship.moved = true
		aimSticks(ship, rootNow, hullNow)
	end
	local fan = (t * budget.FanSpeed) % TAU
	for _, entry in ship.fans do
		entry.motor.Transform = CFrame.Angles(0, 0, entry.side * fan)
	end
	if ship.siren then
		ship.siren.Transform = CFrame.Angles(0, (t * CLIENT.SirenSpeed) % TAU, 0)
	end
	pulse(ship, t, budget)
end

----------------------------------------------------------------------
-- Registering the ships as Eggman streams in and out
----------------------------------------------------------------------
local function unregister(model: Instance)
	local ship = ships[model :: Model]
	if not ship then
		return
	end
	ships[model :: Model] = nil
	for _, connection in ship.connections do
		connection:Disconnect()
	end
	for _, tween in ship.tweens do
		tween:Cancel()
	end
	if ship.markTween then
		ship.markTween:Cancel()
	end
	rest(ship)
	clearVfx(ship)
	if ship.sign then
		ship.sign:Destroy()
	end
	if ship.signAnchor then
		ship.signAnchor:Destroy()
	end
end

-- The seated pose once, whatever the distance: Gameplay/LobbyNpcsClient poses him only near the
-- camera, and a rig never posed would sit with its arms down at its sides.
local function poseOnce(model: Model)
	if not LobbyNpcPose.Defs[EggMobile.PoseKind] then
		return
	end
	local out = LobbyNpcPose.Sample(EggMobile.PoseKind, serverNow(), LobbyNpcPose.NewOut())
	for _, joint in (LobbyNpcRig.FindJoints(model)) do
		local basis = joint.motor.C0.Rotation
		joint.motor.Transform = basis:Inverse() * LobbyNpcPose.ToCFrame(out[joint.name], CFrame) * basis
	end
end

local function register(model: Instance)
	if not model:IsA("Model") or ships[model] then
		return
	end
	-- Prepared by the server (attribute LobbyNpc): the rig and the ship are then held by the root.
	local deadline = os.clock() + 15
	while model:GetAttribute(LobbyNpcConfig.KindAttribute) ~= "Eggman" and model.Parent and os.clock() < deadline do
		task.wait(0.25)
	end
	local shipModel = model:FindFirstChild(EggMobile.ModelName)
	for _ = 1, 4 do
		if shipModel or not model.Parent then
			break
		end
		task.wait(1)
		shipModel = model:FindFirstChild(EggMobile.ModelName)
	end
	if not shipModel or not model:IsDescendantOf(Workspace) or ships[model] then
		return -- a standing Eggman (no ship): Gameplay/LobbyNpcsClient alone
	end
	local hull = shipModel:FindFirstChild(EggMobile.HullName)
	local root = LobbyNpcRig.FindRoot(model)
	if not (hull and hull:IsA("BasePart") and root) then
		return
	end
	local c = EggMobile.HullCenter
	local pivot = hull.CFrame
	local ship: Ship = {
		eggman = model,
		model = shipModel,
		root = root,
		hull = hull,
		anchor = nil,
		restRoot = root.CFrame,
		pivot = pivot,
		pivotToRoot = pivot:Inverse() * root.CFrame,
		floor = pivot * CFrame.new(-c[1], -c[2], -c[3]),
		-- Unanchored by the server's PrepareOwnerModel: the hull then rides on Eggman's root.
		canMove = not hull.Anchored and root.Anchored,
		moved = false,
		fans = {},
		sticks = {},
		siren = nil,
		glows = {},
		made = {},
		vfxTier = nil,
		plasmaBeams = {},
		exhaust = {},
		sirenLight = nil,
		sign = nil,
		signAnchor = nil,
		signStroke = nil,
		mark = nil,
		tweens = {},
		markTween = nil,
		nextStep = 0,
		nextSignCheck = 0,
		connections = {},
	}
	local joints = {}
	for _, joint in (LobbyNpcRig.FindJoints(model)) do
		joints[joint.name] = joint.motor
	end
	for _, d in shipModel:GetDescendants() do
		if d:IsA("Motor6D") and d.Part1 then
			if d.Name == "EggFanMotor" then
				table.insert(ship.fans, { motor = d, side = tonumber(d.Part1:GetAttribute("EggFan")) or 1 })
			elseif d.Name == "EggStickMotor" then
				local side = tonumber(d.Part1:GetAttribute("EggStick")) or 1
				local spec = if side > 0 then EggMobile.Sticks.Right else EggMobile.Sticks.Left
				table.insert(ship.sticks, { motor = d, side = side, length = spec.Length, shoulder = joints[spec.Shoulder], rootJoint = joints.RootJoint })
			elseif d.Name == "EggSirenMotor" then
				ship.siren = d
			end
		elseif d:IsA("BasePart") then
			local glow = d:GetAttribute("EggGlow")
			if type(glow) == "string" then
				table.insert(ship.glows, { part = d, kind = glow, color = d.Color })
			end
			if d:GetAttribute("EggAnchor") == true then
				ship.anchor = d
			end
		end
	end
	ships[model] = ship
	poseOnce(model)
	buildSign(ship)
	table.insert(ship.connections, model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(Workspace) then
			unregister(model)
		end
	end))
end

local EGGMAN_TAG = LobbyNpcConfig.Tags.Eggman
for _, model in CollectionService:GetTagged(EGGMAN_TAG) do
	task.spawn(register, model)
end
CollectionService:GetInstanceAddedSignal(EGGMAN_TAG):Connect(function(model)
	task.spawn(register, model)
end)
CollectionService:GetInstanceRemovedSignal(EGGMAN_TAG):Connect(unregister)

Workspace:GetAttributeChangedSignal(LobbyNpcConfig.KillAttribute):Connect(function()
	local off = killed()
	for _, ship in ships do
		if ship.sign then
			ship.sign.Enabled = not off
		end
		if off then
			rest(ship)
			clearVfx(ship)
		end
	end
end)
for _, name in { "QuestRewardReady", "QuestAvailable" } do
	player:GetAttributeChangedSignal(name):Connect(function()
		for _, ship in ships do
			syncMark(ship)
		end
	end)
end

----------------------------------------------------------------------
-- The loop
----------------------------------------------------------------------
local function visible(camera: Camera, point: Vector3, distance: number): boolean
	if distance <= CLIENT.NearRadius then
		return true
	end
	local screen, inView = camera:WorldToViewportPoint(point)
	if inView then
		return true
	end
	local size = camera.ViewportSize
	-- A 12-stud ship shows before its centre does.
	return screen.Z > 0 and screen.X > -size.X * 0.3 and screen.X < size.X * 1.3 and screen.Y > -size.Y * 0.4 and screen.Y < size.Y * 1.4
end

RunService.Stepped:Connect(function(_, dt)
	RaceFeelTier.Sample(meter, dt)
	tierClock += dt
	if tierClock >= CLIENT.TierSeconds then
		tierClock = 0
		tier = RaceFeelTier.Detect(meter)
	end
	if next(ships) == nil or killed() then
		return
	end
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local eye = camera.CFrame.Position
	local budget = CLIENT.Tiers[tier] or CLIENT.Tiers.Low
	local t = serverNow()
	for _, ship in ships do
		if not (ship.root.Parent and ship.hull.Parent) then
			continue
		end
		local distance = (ship.pivot.Position - eye).Magnitude
		-- Beams and lights near enough to matter.
		if distance <= CLIENT.VfxRadius then
			buildVfx(ship)
		elseif ship.vfxTier and distance > CLIENT.VfxRadius + 20 then
			clearVfx(ship)
		end
		if ship.sign and t >= ship.nextSignCheck then
			ship.nextSignCheck = t + 0.25
			fitSignStroke(ship, camera, distance)
		end
		if distance <= budget.MotionRadius and visible(camera, ship.pivot.Position, distance) then
			if budget.Hz == nil or t >= ship.nextStep then
				ship.nextStep = t + 1 / (budget.Hz or 60)
				step(ship, t, budget)
			end
		else
			rest(ship)
		end
	end
end)
