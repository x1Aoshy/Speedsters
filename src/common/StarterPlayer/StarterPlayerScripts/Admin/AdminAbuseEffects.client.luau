-- AdminAbuseEffects.client.luau
-- What an Admin Abuse Panel action does on the receiving player's screen and character
-- (Admin/AdminAbusePanelService). Anything that moves the character runs here because
-- each client owns its own character's physics; the server only says what and how long.

local ContextActionService = game:GetService("ContextActionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- Sprite-sheet particle textures need their grid declared, or every particle draws the whole
-- sheet (the "broken" clusters of dots): Flipbooks.Apply follows each Texture below.
local Flipbooks = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ParticleFlipbooks"))
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local Panel = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("AdminAbusePanel")
-- Phones and tablets (most players): the effects that repaint many parts every frame
-- repaint less often there.
local UserInputService = game:GetService("UserInputService")
local LOW_POWER = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local PlayerGui = player:WaitForChild("PlayerGui")

local overlay = Instance.new("ScreenGui")
overlay.Name = "AdminAbuseEffects"
overlay.ResetOnSpawn = false
overlay.IgnoreGuiInset = true
overlay.DisplayOrder = 300
overlay.Parent = PlayerGui

local function character()
	local model = player.Character
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")
	local root = model and model:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root then
		return nil, nil
	end
	return humanoid, root
end

-- One running instance per effect; a new order replaces the old one.
local stops = {}
local function run(name, duration, start)
	if stops[name] then
		stops[name]()
		stops[name] = nil
	end
	if duration <= 0 then
		return
	end
	local stopped = false
	local cleanup = start()
	local function stop()
		if stopped then
			return
		end
		stopped = true
		if cleanup then
			cleanup()
		end
	end
	stops[name] = stop
	task.delay(duration, function()
		if stops[name] == stop then
			stops[name] = nil
		end
		stop()
	end)
end

local function banner(text, duration)
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.fromScale(0.5, 0.12)
	label.Size = UDim2.fromScale(0.6, 0.06)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 220, 80)
	label.TextStrokeTransparency = 0.2
	label.Text = text
	label.Parent = overlay
	Debris:AddItem(label, duration)
	return label
end

local EFFECTS = {}

function EFFECTS.Rocket(duration)
	local _, root = character()
	if not root then
		return
	end
	run("Rocket", math.min(duration, 2), function()
		local attachment = Instance.new("Attachment")
		attachment.Parent = root
		local velocity = Instance.new("LinearVelocity")
		velocity.Attachment0 = attachment
		velocity.MaxForce = math.huge
		velocity.VectorVelocity = Vector3.new(0, 170, 0)
		velocity.Parent = root
		local fire = Instance.new("Fire")
		fire.Heat = 25
		fire.Size = 9
		fire.Parent = root
		local smoke = Instance.new("Smoke")
		smoke.RiseVelocity = -12
		smoke.Size = 6
		smoke.Parent = root
		banner("ROCKET!", 2)
		return function()
			velocity:Destroy()
			attachment:Destroy()
			fire.Enabled = false
			smoke.Enabled = false
			Debris:AddItem(fire, 2)
			Debris:AddItem(smoke, 3)
		end
	end)
end

function EFFECTS.Balloon(duration)
	local humanoid, root = character()
	if not humanoid or not root then
		return
	end
	run("Balloon", duration, function()
		local parts = {}
		local rootAttachment = Instance.new("Attachment")
		rootAttachment.Position = Vector3.new(0, 1, 0)
		rootAttachment.Parent = root
		for index = 1, 3 do
			local balloon = Instance.new("Part")
			balloon.Shape = Enum.PartType.Ball
			balloon.Size = Vector3.new(3, 3.4, 3)
			balloon.Material = Enum.Material.SmoothPlastic
			balloon.Color = Color3.fromHSV((index * 0.27) % 1, 0.8, 1)
			balloon.CanCollide = false
			balloon.Massless = true
			balloon.CFrame = root.CFrame * CFrame.new((index - 2) * 2.5, 9 + index, 0)
			balloon.Parent = Workspace
			local attachment = Instance.new("Attachment")
			attachment.Parent = balloon
			local rope = Instance.new("RopeConstraint")
			rope.Attachment0 = rootAttachment
			rope.Attachment1 = attachment
			rope.Length = 9
			rope.Visible = true
			rope.Parent = balloon
			local lift = Instance.new("VectorForce")
			lift.Attachment0 = attachment
			lift.RelativeTo = Enum.ActuatorRelativeTo.World
			lift.Force = Vector3.new(0, balloon:GetMass() * Workspace.Gravity * 1.15, 0)
			lift.Parent = balloon
			table.insert(parts, balloon)
		end
		local attachment = Instance.new("Attachment")
		attachment.Parent = root
		local float = Instance.new("LinearVelocity")
		float.Attachment0 = attachment
		float.MaxForce = root.AssemblyMass * Workspace.Gravity * 3
		float.VectorVelocity = Vector3.new(0, 9, 0)
		float.Parent = root
		banner("Up, up and away!", 2)
		return function()
			float:Destroy()
			attachment:Destroy()
			rootAttachment:Destroy()
			for _, balloon in parts do
				balloon:Destroy()
			end
		end
	end)
end

function EFFECTS.NoGravity(duration)
	local _, root = character()
	if not root then
		return
	end
	run("NoGravity", duration, function()
		local attachment = Instance.new("Attachment")
		attachment.Parent = root
		local force = Instance.new("VectorForce")
		force.Attachment0 = attachment
		force.RelativeTo = Enum.ActuatorRelativeTo.World
		force.ApplyAtCenterOfMass = true
		force.Parent = root
		local connection = RunService.Heartbeat:Connect(function()
			if root.Parent then
				force.Force = Vector3.new(0, root.AssemblyMass * Workspace.Gravity * 0.86, 0)
			end
		end)
		banner("No gravity!", 2)
		return function()
			connection:Disconnect()
			force:Destroy()
			attachment:Destroy()
		end
	end)
end

local function controls()
	local ok, module = pcall(function()
		return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")):GetControls()
	end)
	return if ok then module else nil
end

function EFFECTS.Inverse(duration)
	local humanoid = character()
	local moduleControls = controls()
	if not humanoid or not moduleControls then
		return
	end
	run("Inverse", duration, function()
		local name = "AdminAbuseInverse"
		-- Runs right after the control script moves the character, and moves it backwards.
		RunService:BindToRenderStep(name, Enum.RenderPriority.Input.Value + 1, function()
			if humanoid.Parent then
				humanoid:Move(-moduleControls:GetMoveVector(), true)
			end
		end)
		banner("Controls inverted!", 2.5)
		return function()
			RunService:UnbindFromRenderStep(name)
		end
	end)
end

function EFFECTS.Control(duration, adminUserId)
	local humanoid, root = character()
	local admin = adminUserId and Players:GetPlayerByUserId(adminUserId)
	if not humanoid or not root or not admin then
		return
	end
	run("Control", duration, function()
		local name = "AdminAbuseControl"
		ContextActionService:BindActionAtPriority(name, function()
			return Enum.ContextActionResult.Sink
		end, false, Enum.ContextActionPriority.High.Value + 100, Enum.PlayerActions.CharacterJump)
		RunService:BindToRenderStep(name, Enum.RenderPriority.Input.Value + 1, function()
			local adminRoot = admin.Character and admin.Character:FindFirstChild("HumanoidRootPart")
			if not humanoid.Parent or not adminRoot then
				return
			end
			local offset = (adminRoot.Position - root.Position) * Vector3.new(1, 0, 1)
			humanoid:Move(if offset.Magnitude > 6 then offset.Unit else Vector3.zero, false)
		end)
		banner(admin.DisplayName .. " is controlling you!", 3)
		return function()
			RunService:UnbindFromRenderStep(name)
			ContextActionService:UnbindAction(name)
		end
	end)
end

function EFFECTS.Jumpscare()
	run("Jumpscare", 1.6, function()
		local screen = Instance.new("Frame")
		screen.Size = UDim2.fromScale(1, 1)
		screen.BackgroundColor3 = Color3.new(0, 0, 0)
		screen.ZIndex = 50
		screen.Parent = overlay
		local face = Instance.new("TextLabel")
		face.AnchorPoint = Vector2.new(0.5, 0.5)
		face.Position = UDim2.fromScale(0.5, 0.5)
		face.Size = UDim2.fromScale(0.9, 0.55)
		face.BackgroundTransparency = 1
		face.Font = Enum.Font.Creepster
		face.TextScaled = true
		face.TextColor3 = Color3.fromRGB(220, 0, 0)
		face.Text = "BOO!"
		face.ZIndex = 51
		face.Parent = screen
		local scale = Instance.new("UIScale")
		scale.Scale = 0.3
		scale.Parent = face
		TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.15 }):Play()
		local scream = Instance.new("Sound")
		scream.SoundId = "rbxasset://sounds/uuhhh.mp3"
		scream.Volume = 2
		scream.PlaybackSpeed = 0.55
		scream.Parent = screen
		scream:Play()
		local startedAt = os.clock()
		local shake = RunService.RenderStepped:Connect(function()
			local t = os.clock() - startedAt
			face.Rotation = math.sin(t * 60) * 6
			face.Position = UDim2.new(0.5, math.random(-12, 12), 0.5, math.random(-12, 12))
		end)
		return function()
			shake:Disconnect()
			local fade = TweenService:Create(screen, TweenInfo.new(0.25), { BackgroundTransparency = 1 })
			TweenService:Create(face, TweenInfo.new(0.25), { TextTransparency = 1 }):Play()
			fade:Play()
			Debris:AddItem(screen, 0.4)
		end
	end)
end

function EFFECTS.Confetti(duration)
	run("Confetti", math.min(duration, 60), function()
		local layer = Instance.new("Frame")
		layer.Size = UDim2.fromScale(1, 1)
		layer.BackgroundTransparency = 1
		layer.ClipsDescendants = true
		layer.Parent = overlay
		local active = true
		task.spawn(function()
			while active do
				for _ = 1, 14 do
					local piece = Instance.new("Frame")
					piece.BorderSizePixel = 0
					piece.BackgroundColor3 = Color3.fromHSV(math.random(), 0.85, 1)
					piece.Size = UDim2.fromOffset(math.random(8, 14), math.random(14, 22))
					piece.Position = UDim2.fromScale(math.random(), -0.05)
					piece.Rotation = math.random(0, 360)
					piece.Parent = layer
					local fall = math.random(26, 42) / 10
					TweenService:Create(piece, TweenInfo.new(fall, Enum.EasingStyle.Linear), {
						Position = UDim2.fromScale(piece.Position.X.Scale + (math.random() - 0.5) * 0.2, 1.05),
						Rotation = piece.Rotation + math.random(-540, 540),
					}):Play()
					Debris:AddItem(piece, fall)
				end
				task.wait(0.35)
			end
		end)
		return function()
			active = false
			Debris:AddItem(layer, 4.5)
		end
	end)
end

function EFFECTS.Sandstorm(duration)
	run("Sandstorm", duration, function()
		return function() end
	end)
end

function EFFECTS.RainingTacos(_duration)
	-- The replicated world state owns the rain; the server sends one neutral announcement.
end

function EFFECTS.Snail(duration)
	-- The crawl itself is the server's (AdminSnailUntil); this is the player's own notice:
	-- the snail and a slimy green edge on the screen while it lasts.
	run("Snail", duration, function()
		banner("🐌 SNAIL MODE! S-l-o-o-o-w...", duration)
		local slime = Instance.new("Frame")
		slime.Name = "SnailSlime"
		slime.BackgroundColor3 = Color3.fromRGB(120, 230, 70)
		slime.BackgroundTransparency = 0.55
		slime.BorderSizePixel = 0
		slime.Size = UDim2.fromScale(1, 1)
		slime.Parent = overlay
		local edges = Instance.new("UIGradient")
		edges.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(0.15, 1),
			NumberSequenceKeypoint.new(0.85, 1),
			NumberSequenceKeypoint.new(1, 0.2),
		})
		edges.Parent = slime
		return function()
			slime:Destroy()
		end
	end)
end

-- Fake Reset: a harmless troll, all on this one screen and nothing saved anywhere. The
-- Speed, Wins and Rebirths on the HUD read 0, with a distorted "oof", a glitch and a fake
-- data error; FAKE_RESET.Seconds later a fanfare and confetti, "TROLLED BY <admin>! Your
-- stats are 100% safe", and the HUD's real numbers are back (the latest ones: the HUD
-- keeps counting underneath while it shows 0).
local FAKE_RESET = {
	Seconds = 6,
	Total = 10.5, -- until the reveal has had its moment
	Sounds = {
		Oof = "rbxasset://sounds/uuhhh.mp3",
		Glitch = "rbxasset://sounds/electronicpingshort.wav",
		Tada = "rbxassetid://80736831159506",
	},
}

-- The HUD's Speed, Wins and Rebirths labels (MainHUDController), what they read, and what
-- they read at 0.
local function hudCounters()
	local counters = {}
	local mainhud = PlayerGui:FindFirstChild("Mainhud")
	local trophies = mainhud and mainhud:FindFirstChild("Rebith/trof")
	local level = mainhud and mainhud:FindFirstChild("LevelProgressBar")
	local levelFrame = level and level:FindFirstChild("Frame")
	for _, entry in {
		{ trophies and trophies:FindFirstChild("Rebirth"), "0" },
		{ trophies and trophies:FindFirstChild("Victory"), "0" },
		{ levelFrame and levelFrame:FindFirstChild("Speed"), "Speed: 0" },
	} do
		local label = entry[1]
		if label and label:IsA("TextLabel") then
			table.insert(counters, { Label = label, Zero = entry[2], Real = label.Text })
		end
	end
	return counters
end

-- A plate in the game's style: a gradient, a dark edge, an emoji on its own at the left, a
-- title and a line under it in white with a dark outline.
local function trollPlate(name, colours, icon, title, subtitle)
	local plate = Instance.new("Frame")
	plate.Name = name
	plate.AnchorPoint = Vector2.new(0.5, 0.5)
	plate.Position = UDim2.fromScale(0.5, 0.34)
	plate.Size = UDim2.fromOffset(560, 130)
	plate.BackgroundColor3 = Color3.new(1, 1, 1)
	plate.Visible = false
	plate.ZIndex = 70
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 18)
	corner.Parent = plate
	local fill = Instance.new("UIGradient")
	fill.Rotation = 90
	fill.Color = colours
	fill.Parent = plate
	local edge = Instance.new("UIStroke")
	edge.Color = Color3.fromRGB(11, 27, 61)
	edge.Thickness = 5
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Parent = plate
	local iconLabel = Instance.new("TextLabel")
	iconLabel.Name = "Icon"
	iconLabel.BackgroundTransparency = 1
	iconLabel.AnchorPoint = Vector2.new(0, 0.5)
	iconLabel.Position = UDim2.new(0, 16, 0.5, 0)
	iconLabel.Size = UDim2.fromOffset(92, 92)
	iconLabel.TextSize = 70
	iconLabel.Text = icon
	iconLabel.ZIndex = 71
	iconLabel.Parent = plate
	for index, line in { { "Title", title, 0.1, 0.5 }, { "Subtitle", subtitle, 0.6, 0.3 } } do
		local label = Instance.new("TextLabel")
		label.Name = line[1]
		label.BackgroundTransparency = 1
		label.Position = UDim2.new(0, 120, line[3], 0)
		label.Size = UDim2.new(1, -136, line[4], 0)
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextColor3 = if index == 1 then Color3.new(1, 1, 1) else Color3.fromRGB(255, 245, 190)
		label.Text = line[2]
		label.ZIndex = 71
		label.Parent = plate
		local outline = Instance.new("UIStroke")
		outline.Color = Color3.fromRGB(11, 27, 61)
		outline.Thickness = if index == 1 then 4 else 3
		outline.Parent = label
	end
	local scale = Instance.new("UIScale")
	scale.Parent = plate
	plate.Parent = overlay
	return plate, scale
end

local function trollSound(id, volume, speed, distorted)
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume
	sound.PlaybackSpeed = speed
	if distorted then
		local distortion = Instance.new("DistortionSoundEffect")
		distortion.Level = 0.85
		distortion.Parent = sound
	end
	sound.Parent = overlay
	pcall(function()
		sound:Play()
	end)
	task.delay(6, function()
		sound:Destroy()
	end)
	return sound
end

local function fakeReset(adminName)
	local name = string.sub(tostring(adminName or "un admin"), 1, 32)
	local started = os.clock()
	local counters = hudCounters()
	local forcing = true
	local revealed = false
	local watchers = {}
	-- Zero, and zero again the moment the HUD writes a real number (which is kept for later).
	local function hold(counter)
		if forcing and counter.Label.Text ~= counter.Zero then
			counter.Real = counter.Label.Text
			counter.Label.Text = counter.Zero
		end
	end
	for _, counter in counters do
		hold(counter)
		table.insert(watchers, counter.Label:GetPropertyChangedSignal("Text"):Connect(function()
			hold(counter)
		end))
	end
	trollSound(FAKE_RESET.Sounds.Oof, 1.6, 0.8, true)

	local glitch = Instance.new("Frame")
	glitch.Name = "FakeResetGlitch"
	glitch.BackgroundColor3 = Color3.fromRGB(255, 30, 40)
	glitch.BackgroundTransparency = 0.55
	glitch.BorderSizePixel = 0
	glitch.Size = UDim2.fromScale(1, 1)
	glitch.ZIndex = 60
	glitch.Parent = overlay
	local bars = {}
	for index = 1, 9 do
		local bar = Instance.new("Frame")
		bar.Name = "GlitchBar"
		bar.BorderSizePixel = 0
		bar.BackgroundColor3 = if index % 3 == 0 then Color3.new(1, 1, 1) elseif index % 2 == 0 then Color3.fromRGB(0, 255, 255) else Color3.fromRGB(255, 0, 90)
		bar.BackgroundTransparency = 0.25
		bar.ZIndex = 61
		bar.Parent = glitch
		table.insert(bars, bar)
	end
	local warning = trollPlate(
		"FakeResetError",
		ColorSequence.new(Color3.fromRGB(255, 90, 90), Color3.fromRGB(150, 10, 25)),
		"⚠️",
		"DATA ERROR!",
		"Your Speed, Wins and Rebirths have reset to 0"
	)
	local reveal, revealScale = trollPlate(
		"FakeResetReveal",
		ColorSequence.new(Color3.fromRGB(255, 240, 120), Color3.fromRGB(255, 150, 20)),
		"🤣",
		"ROLLED BY " .. name .. "!",
		"Your stats are 100% safe"
	)
	local nextBlip = 0.2
	local connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		if forcing then
			for _, counter in counters do
				hold(counter)
			end
		end
		-- The first moments: the screen tears, flashes and crackles.
		local tearing = t < 1.5
		glitch.BackgroundTransparency = if t < 0.3 then 0.55 + t else (if tearing then 0.88 + 0.06 * math.sin(t * 40) else 1)
		for _, bar in bars do
			bar.Visible = tearing and math.random() < 0.7
			if bar.Visible then
				bar.Position = UDim2.fromScale(math.random() * 0.4 - 0.2, math.random())
				bar.Size = UDim2.new(0.6 + math.random() * 0.7, 0, 0, math.random(3, 16))
			end
		end
		if tearing and t >= nextBlip then
			nextBlip = t + 0.16 + math.random() * 0.14
			trollSound(FAKE_RESET.Sounds.Glitch, 0.9, 0.5 + math.random() * 1.3, true)
		end
		-- The fake error, shaking at first, until the reveal.
		warning.Visible = t >= 0.5 and t < FAKE_RESET.Seconds
		warning.Position = UDim2.new(0.5, if tearing then math.random(-10, 10) else 0, 0.34, 0)
		-- The reveal: the real numbers back, a fanfare, confetti, and who did it.
		if t >= FAKE_RESET.Seconds and not revealed then
			revealed = true
			forcing = false
			for _, counter in counters do
				counter.Label.Text = counter.Real
			end
			trollSound(FAKE_RESET.Sounds.Tada, 1, 1, false)
			EFFECTS.Confetti(4)
			reveal.Visible = true
		end
		if revealed then
			local x = math.clamp((t - FAKE_RESET.Seconds) / 0.45, 0, 1)
			revealScale.Scale = 1 + 2.70158 * (x - 1) ^ 3 + 1.70158 * (x - 1) ^ 2
		end
	end)
	return function()
		connection:Disconnect()
		for _, watcher in watchers do
			watcher:Disconnect()
		end
		if not revealed then
			forcing = false
			for _, counter in counters do
				counter.Label.Text = counter.Real
			end
		end
		glitch:Destroy()
		warning:Destroy()
		reveal:Destroy()
	end
end

function EFFECTS.FakeReset(_duration, _adminUserId, adminName)
	-- Always the same six seconds, whatever the panel's duration says.
	run("FakeReset", FAKE_RESET.Total, function()
		return fakeReset(adminName)
	end)
end

-- The trolls that act on the character end with it: a reset or a death takes the rocket,
-- the balloons, the forces and the bound controls away at once, instead of leaving them
-- tied to a character that is gone until their time runs out.
local CHARACTER_EFFECTS = { "Rocket", "Balloon", "NoGravity", "Inverse", "Control" }
player.CharacterRemoving:Connect(function()
	for _, name in CHARACTER_EFFECTS do
		local stop = stops[name]
		if stop then
			stops[name] = nil
			stop()
		end
	end
end)

Panel.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" or payload.kind ~= "Effect" then
		return
	end
	local effect = EFFECTS[payload.effect]
	local duration = math.clamp(tonumber(payload.duration) or 0, 0, 900)
	if not effect then
		return
	end
	if duration <= 0 then
		-- An event switched off early.
		if stops[payload.effect] then
			stops[payload.effect]()
			stops[payload.effect] = nil
		end
		return
	end
	task.spawn(effect, duration, tonumber(payload.adminUserId), payload.adminName, payload)
end)

----------------------------------------------------------------------
-- World events drawn on every client: snow, the disco ball, the admin treadmills
----------------------------------------------------------------------
-- These follow what the server has put in the world (attributes and models), so a player
-- who joins in the middle of one sees it too.
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")

local function lerp(a, b, t)
	return a + (b - a) * t
end

-- Snow (Workspace.AdminSnowUntil): a snowfall around the camera and a winter sky, blended
-- in and out. The flakes and the sky are the ones from the RobloxBall weather.
--
-- The flakes are born on a sheet above the camera and have to live long enough to reach
-- the ground: the ground under the camera is found with a ray, the sheet sits well above
-- it, and every flake lives for the whole fall (the floor hides it once it lands). A
-- sheet a fixed height over the camera with a fixed lifetime made them vanish mid-air.
local SNOW = {
	Texture = "rbxassetid://8163218169",
	CeilingSize = 180,
	AboveCamera = 25, -- the sheet is always at least this far over the camera
	AboveGround = 70, -- ...and normally this far over the ground under it
	FallbackFall = 90, -- the fall when there is no ground under the camera
	MaxLifetime = 20,
	Spread = 20, -- degrees off straight down: a light drift, still reaching the floor
	-- 2026-09-22: phones draw fewer flakes. 380 a second over the 20 s fall kept thousands of
	-- particles alive on 26 FPS phones; 150 still reads as a snowstorm on a small screen.
	Rate = if LOW_POWER then 150 else 380,
	Speed = 13,
	Size = 0.9,
	ProbeSeconds = 0.2,
	MaxLead = 90, -- how far ahead of a running player the flakes are born
	BlendSeconds = 4,
	Atmosphere = { Density = 0.52, Haze = 2.6, Glare = 0.35, Color = Color3.fromRGB(215, 228, 242), Decay = Color3.fromRGB(140, 155, 175) },
	Brightness = 1.4,
	OutdoorAmbient = Color3.fromRGB(150, 162, 180),
	Clouds = { Cover = 0.88, Density = 0.3, Color = Color3.fromRGB(225, 232, 242) },
}

local snowWeight = 0
local snow = nil -- the snowfall's objects and the sky it replaced, while any snow shows

local function snowActive()
	local untilTime = tonumber(Workspace:GetAttribute("AdminSnowUntil"))
	return untilTime ~= nil and untilTime > Workspace:GetServerTimeNow() - 1
end

local function buildSnow()
	local ceiling = Instance.new("Part")
	ceiling.Name = "AdminSnowCeiling"
	ceiling.Anchored = true
	ceiling.CanCollide = false
	ceiling.CanQuery = false
	ceiling.CanTouch = false
	ceiling.CastShadow = false
	ceiling.Transparency = 1
	ceiling.Size = Vector3.new(SNOW.CeilingSize, 1, SNOW.CeilingSize)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Snow"
	emitter.Texture = SNOW.Texture
	emitter.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
	emitter.Rate = 0
	emitter.Speed = NumberRange.new(SNOW.Speed * 0.8, SNOW.Speed)
	emitter.SpreadAngle = Vector2.new(SNOW.Spread, SNOW.Spread)
	emitter.Rotation = NumberRange.new(-360, 360)
	emitter.RotSpeed = NumberRange.new(-50, 50)
	emitter.Size = NumberSequence.new(SNOW.Size)
	-- Each flake fades in just under the sheet instead of popping into view.
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.06, 0.1),
		NumberSequenceKeypoint.new(1, 0.1),
	})
	emitter.EmissionDirection = Enum.NormalId.Bottom
	-- Loose flakes stay where they fall instead of travelling with the camera.
	emitter.LockedToPart = false
	emitter.LightInfluence = 0.6
	emitter.Parent = ceiling
	ceiling.Parent = Workspace.CurrentCamera

	local tint = Instance.new("ColorCorrectionEffect")
	tint.Name = "AdminSnowTint"
	tint.Parent = Lighting
	-- Frost creeping in from the top and bottom of the screen.
	local frost = Instance.new("Frame")
	frost.Name = "Frost"
	frost.BackgroundColor3 = Color3.fromRGB(225, 240, 255)
	frost.BorderSizePixel = 0
	frost.Size = UDim2.fromScale(1, 1)
	frost.BackgroundTransparency = 1
	local edges = Instance.new("UIGradient")
	edges.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(0.12, 1),
		NumberSequenceKeypoint.new(0.88, 1),
		NumberSequenceKeypoint.new(1, 0.55),
	})
	edges.Rotation = 90
	edges.Parent = frost
	frost.Parent = overlay

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	local ownsAtmosphere = atmosphere == nil
	if ownsAtmosphere then
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Name = "AdminSnowAtmosphere"
		atmosphere.Density = 0
		atmosphere.Haze = 0
		atmosphere.Parent = Lighting
	end
	local clouds = Workspace.Terrain:FindFirstChildOfClass("Clouds")
	local ownsClouds = clouds == nil
	if ownsClouds then
		clouds = Instance.new("Clouds")
		clouds.Name = "AdminSnowClouds"
		clouds.Cover = 0
		clouds.Parent = Workspace.Terrain
	end
	snow = {
		Ceiling = ceiling,
		Emitter = emitter,
		GroundY = nil,
		NextProbe = 0,
		LastCamera = nil,
		Velocity = Vector3.zero,
		Tint = tint,
		Frost = frost,
		Atmosphere = atmosphere,
		OwnsAtmosphere = ownsAtmosphere,
		Clouds = clouds,
		OwnsClouds = ownsClouds,
		Original = {
			Density = atmosphere.Density,
			Haze = atmosphere.Haze,
			Glare = atmosphere.Glare,
			Color = atmosphere.Color,
			Decay = atmosphere.Decay,
			CloudCover = clouds.Cover,
			CloudDensity = clouds.Density,
			CloudColor = clouds.Color,
		},
	}
end

-- The height of the ground under a point: the first solid, visible thing a ray straight
-- down meets. Players, the camera's own parts and see-through or walk-through parts
-- (zones, triggers, glass roofs) are skipped.
local function groundBelow(position)
	local ignore = { Workspace.CurrentCamera }
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(ignore, other.Character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true
	for _ = 1, 8 do
		params.FilterDescendantsInstances = ignore
		local hit = Workspace:Raycast(position, Vector3.new(0, -1500, 0), params)
		if not hit then
			return nil
		end
		local part = hit.Instance
		if part:IsA("BasePart") and (part.Transparency >= 0.9 or not part.CanCollide) then
			table.insert(ignore, part)
		else
			return hit.Position.Y
		end
	end
	return nil
end

-- Where the sheet goes and how long its flakes live, for a camera at `position` moving at
-- `velocity`, over ground at `groundY` (nil when there is none).
local function snowPlacement(position, velocity, groundY)
	local floorY = groundY or (position.Y - SNOW.FallbackFall + SNOW.AboveCamera)
	local height = math.max(position.Y + SNOW.AboveCamera, floorY + SNOW.AboveGround)
	local fall = height - floorY
	-- The slowest flake, falling at the widest angle, still gets all the way down.
	local slowest = SNOW.Speed * 0.8 * math.cos(math.rad(SNOW.Spread))
	local lifetime = math.min(fall / slowest + 0.5, SNOW.MaxLifetime)
	-- A running player meets the flakes halfway through their fall, so they are born ahead.
	local lead = Vector3.new(velocity.X, 0, velocity.Z) * (fall / SNOW.Speed) * 0.5
	if lead.Magnitude > SNOW.MaxLead then
		lead = lead.Unit * SNOW.MaxLead
	end
	return Vector3.new(position.X, height, position.Z) + lead, lifetime
end

local originalJointC0s = setmetatable({}, { __mode = "k" })
local coldBreathAttachments = setmetatable({}, { __mode = "k" })
local lastBreathEmit = 0

local function restoreSnowShivering()
	for joint, origC0 in pairs(originalJointC0s) do
		if joint and joint.Parent then
			pcall(function()
				joint.C0 = origC0
			end)
		end
	end
	table.clear(originalJointC0s)
	for char, att in pairs(coldBreathAttachments) do
		if att and att.Parent then
			pcall(function()
				att:Destroy()
			end)
		end
	end
	table.clear(coldBreathAttachments)
end

local function updateSnowShivering(weight)
	-- Restore joints before distance culling, so leaving range cannot freeze a pose.
	for joint, original in pairs(originalJointC0s) do
		if joint.Parent then joint.C0 = original end
	end
	local camera = Workspace.CurrentCamera
	local camPos = if camera then camera.CFrame.Position else Vector3.zero
	local now = os.clock()
	local emitBreath = false
	if now - lastBreathEmit >= 2.2 then
		lastBreathEmit = now
		emitBreath = true
	end

	for _, p in Players:GetPlayers() do
		local char = p.Character
		if char and char.Parent then
			local root = char:FindFirstChild("HumanoidRootPart")
			if root and (root.Position - camPos).Magnitude < 140 then
				local rootJoint = (char:FindFirstChild("LowerTorso") and char.LowerTorso:FindFirstChild("Root"))
					or (char:FindFirstChild("HumanoidRootPart") and char.HumanoidRootPart:FindFirstChild("RootJoint"))
				if rootJoint and rootJoint.Parent then
					if not originalJointC0s[rootJoint] then
						originalJointC0s[rootJoint] = rootJoint.C0
					end
					local origC0 = originalJointC0s[rootJoint]
					if weight > 0.03 then
						local shiverSpeed = 42
						local jitterAmp = 0.045 * weight
						local jx = math.sin(now * shiverSpeed) * jitterAmp
						local jz = math.cos(now * (shiverSpeed * 1.15)) * (jitterAmp * 0.6)
						local jRot = math.sin(now * (shiverSpeed * 0.88)) * math.rad(1.5 * weight)
						rootJoint.C0 = origC0 * CFrame.new(jx, 0, jz) * CFrame.Angles(0, 0, jRot)
					else
						rootJoint.C0 = origC0
					end
				end

				-- Cold breath vapor puff
				local head = char:FindFirstChild("Head")
				if head and weight > 0.15 then
					local breathAtt = coldBreathAttachments[char]
					if not breathAtt or not breathAtt.Parent then
						breathAtt = Instance.new("Attachment")
						breathAtt.Name = "ColdBreathAttachment"
						breathAtt.Position = Vector3.new(0, -0.15, -0.6)
						breathAtt.Parent = head
						local breathEmitter = Instance.new("ParticleEmitter")
						breathEmitter.Name = "BreathVapor"
						breathEmitter.Texture = "rbxassetid://8163218169"
						Flipbooks.Apply(breathEmitter)
						breathEmitter.Rate = 0
						breathEmitter.Speed = NumberRange.new(0.8, 1.4)
						breathEmitter.Lifetime = NumberRange.new(0.6, 1.0)
						breathEmitter.SpreadAngle = Vector2.new(12, 12)
						breathEmitter.Size = NumberSequence.new({
							NumberSequenceKeypoint.new(0, 0.2),
							NumberSequenceKeypoint.new(0.5, 0.6),
							NumberSequenceKeypoint.new(1, 0.9),
						})
						breathEmitter.Transparency = NumberSequence.new({
							NumberSequenceKeypoint.new(0, 0.7),
							NumberSequenceKeypoint.new(0.3, 0.4),
							NumberSequenceKeypoint.new(1, 1),
						})
						breathEmitter.Color = ColorSequence.new(Color3.fromRGB(230, 240, 255))
						breathEmitter.LightInfluence = 0.3
						breathEmitter.EmissionDirection = Enum.NormalId.Front
						breathEmitter.Parent = breathAtt
						coldBreathAttachments[char] = breathAtt
					end
					if emitBreath and breathAtt:FindFirstChild("BreathVapor") then
						breathAtt.BreathVapor:Emit(3)
					end
				end
			end
		end
	end
end

local function removeSnow()
	restoreSnowShivering()
	snow.Ceiling:Destroy()
	snow.Tint:Destroy()
	snow.Frost:Destroy()
	if snow.OwnsAtmosphere then
		snow.Atmosphere:Destroy()
	end
	if snow.OwnsClouds then
		snow.Clouds:Destroy()
	end
	snow = nil
end

local function updateSnow(dt)
	local target = if snowActive() then 1 else 0
	if target == 0 and snowWeight == 0 then
		return
	end
	if not snow then
		buildSnow()
	end
	snowWeight = math.clamp(snowWeight + (if target > snowWeight then dt else -dt) / SNOW.BlendSeconds, 0, 1)
	local t = snowWeight
	local camera = Workspace.CurrentCamera
	if camera then
		if snow.Ceiling.Parent ~= camera then
			snow.Ceiling.Parent = camera
		end
		local position = camera.CFrame.Position
		if snow.LastCamera and dt > 0 then
			local step = (position - snow.LastCamera) / dt
			-- A teleport is not running: only steady movement moves the snow ahead.
			if step.Magnitude < 400 then
				snow.Velocity = snow.Velocity:Lerp(step, math.clamp(dt * 4, 0, 1))
			else
				snow.Velocity = Vector3.zero
			end
		end
		snow.LastCamera = position
		local now = os.clock()
		if now >= snow.NextProbe then
			snow.NextProbe = now + SNOW.ProbeSeconds
			snow.GroundY = groundBelow(position)
		end
		local sheet, lifetime = snowPlacement(position, snow.Velocity, snow.GroundY)
		snow.Ceiling.CFrame = CFrame.new(sheet)
		snow.Emitter.Lifetime = NumberRange.new(lifetime, lifetime * 1.1)
	end
	snow.Emitter.Rate = SNOW.Rate * t
	local original = snow.Original
	snow.Atmosphere.Density = lerp(original.Density, SNOW.Atmosphere.Density, t)
	snow.Atmosphere.Haze = lerp(original.Haze, SNOW.Atmosphere.Haze, t)
	snow.Atmosphere.Glare = lerp(original.Glare, SNOW.Atmosphere.Glare, t)
	snow.Atmosphere.Color = original.Color:Lerp(SNOW.Atmosphere.Color, t)
	snow.Atmosphere.Decay = original.Decay:Lerp(SNOW.Atmosphere.Decay, t)
	snow.Clouds.Cover = lerp(original.CloudCover, SNOW.Clouds.Cover, t)
	snow.Clouds.Density = lerp(original.CloudDensity, SNOW.Clouds.Density, t)
	snow.Clouds.Color = original.CloudColor:Lerp(SNOW.Clouds.Color, t)
	snow.Tint.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(225, 238, 255), t)
	snow.Tint.Saturation = -0.18 * t
	snow.Tint.Brightness = 0.04 * t
	snow.Frost.BackgroundTransparency = lerp(1, 0.25, t)

	updateSnowShivering(t)

	if snowWeight == 0 then
		removeSnow()
	end
end

-- Disco (Workspace.AdminDiscoUntil, AdminDiscoCenter, AdminDiscoFloor, AdminDiscoFloorSize):
-- the night falls and a big mirror ball comes down over the lobby's dance floor. The ball is
-- rings of mirror and neon tiles swirling with colour, turned by the server's clock so it
-- spins smoothly and in step for everyone. It throws twelve spots of colour onto the floor
-- that turn with it (no beams: the user found them too much). Coloured lights wander over
-- the floor and the sky's colour drifts slowly round. Off the dance floor a small copy of
-- the ball follows each player, turning over their head and lighting their outline in
-- the party's colours. Everything eases in and out; nothing strobes.
local DISCO = {
	BallRadius = 11,
	TileSize = 2.7,
	TileThickness = 0.4,
	DropHeight = 45, -- the ball comes down from this far above its place, and goes back up
	SpinDegrees = 36, -- the ball turns this many degrees a second round its vertical axis
	NearRadius = 260, -- closer than this to the ball, the show is the ball's
	RigHeight = 30, -- away from the lobby, the coloured lights wander this far over the ground
	-- The spots it throws on the floor: two even rings of six, one steeper, set half a step
	-- apart, so they lie in a regular ring round the floor. They turn with the ball.
	Spots = 12,
	SpotPitches = { 44, 64 }, -- degrees below the horizon: the outer ring, the inner ring
	SpotAngle = 16,
	-- One wide light under the ball washes the dance floor, pulsing on the beat.
	WashAngle = 75,
	Wanderers = 8,
	BlendSeconds = 1.5,
	TileColourSeconds = 1 / 30,
	ClockTime = 0, -- midnight
	Brightness = 0.6,
}
local MIRROR = Color3.fromRGB(205, 212, 225)
local GOLD_TRIM = Color3.fromRGB(255, 196, 40)

local disco = nil
local discoWeight = 0
-- The disco's sky, drifting through the colours; the light mixer reads it (blendLighting).
local discoColors = { Ambient = Color3.fromRGB(70, 45, 95), OutdoorAmbient = Color3.fromRGB(60, 40, 90) }

local function eased(x)
	return 1 - (1 - math.clamp(x, 0, 1)) ^ 3
end

-- The disco's own clock. It moves on by exactly each frame's time, so nothing it drives can
-- jump or stutter, and leans gently toward the server's clock so every player stays in step.
-- A big gap (the first frame, a long hitch) is closed at once.
local function discoClock(clock, serverNow, dt)
	if clock == nil or math.abs(serverNow - clock) > 1 then
		return serverNow
	end
	local nextClock = clock + dt
	return nextClock + (serverNow - nextClock) * math.min(1, dt * 0.8)
end

-- The music's beat. The song this player hears (the admin's track, or the game's background
-- music) is followed through its loudness: a beat is a jump well above the song's recent
-- level. Between songs, or with the music muted, the beat carries on at the tempo it last
-- heard, so the party never stops pulsing. beat.Pulse is 1 on a beat and fades quickly.
local BEAT = { MinGap = 0.28, Rise = 1.3, Rearm = 1.1, Floor = 25, Decay = 7, Period = 0.5, KeepTime = 2 }

local function newBeat()
	return { Fast = 0, Slow = 0, Peak = 0, Armed = true, LastBeat = -math.huge, LastHeard = -math.huge, Period = BEAT.Period, Pulse = 0 }
end

-- Moves the beat on by `dt` to time `now`, with the song's loudness (nil when no song plays).
-- Returns true on a beat.
local function stepBeat(beat, dt, now, loudness)
	beat.Since = beat.Since or now
	beat.Pulse *= math.exp(-dt * BEAT.Decay)
	local hit = false
	if loudness then
		local previous = beat.Fast
		beat.Fast += (loudness - beat.Fast) * math.min(1, dt * 30)
		beat.Slow += (loudness - beat.Slow) * math.min(1, dt * 1.2)
		-- Ready for the next beat once this one has died down.
		if beat.Fast < beat.Slow * BEAT.Rearm or beat.Fast < beat.Peak * 0.6 then
			beat.Armed = true
		end
		-- A beat: the song getting suddenly louder, well above its recent level.
		local rising = beat.Fast > previous * 1.15 + 1
		if beat.Armed and rising and beat.Fast > BEAT.Floor and beat.Fast > beat.Slow * BEAT.Rise and now - beat.LastBeat >= BEAT.MinGap then
			hit = true
			beat.Armed = false
			beat.Peak = beat.Fast
			local gap = now - beat.LastHeard
			if gap >= BEAT.MinGap and gap <= 1.2 then
				beat.Period += (gap - beat.Period) * 0.25
			end
			beat.LastHeard = now
		end
	end
	-- Nothing heard for a while: keep time.
	if not hit and now - math.max(beat.LastHeard, beat.Since) > BEAT.KeepTime and now - beat.LastBeat >= beat.Period then
		hit = true
	end
	if hit then
		beat.LastBeat = now
		beat.Pulse = 1
	end
	return hit
end

local function musicLoudness()
	local admin = Workspace:FindFirstChild("AdminMusic")
	if admin and admin:IsA("Sound") and admin.IsPlaying then
		return admin.PlaybackLoudness
	end
	local background = SoundService:FindFirstChild("SpeedsterBackgroundMusic")
	if background and background:IsA("Sound") and background.IsPlaying then
		return background.PlaybackLoudness
	end
	return nil
end

local function discoActive()
	local untilTime = tonumber(Workspace:GetAttribute("AdminDiscoUntil"))
	return untilTime ~= nil
		and untilTime > Workspace:GetServerTimeNow() - 1
		and typeof(Workspace:GetAttribute("AdminDiscoCenter")) == "Vector3"
		and typeof(Workspace:GetAttribute("AdminDiscoFloor")) == "Vector3"
end

-- Where the spotlights hang: from the ball when the camera is near it, otherwise over the
-- ground under the player. Returns the rig's position, the floor's height under it and
-- whether it is the ball's show.
local function discoAnchor(cameraPosition, center, floorY, focus, groundY)
	local offset = cameraPosition - center
	if Vector3.new(offset.X, 0, offset.Z).Magnitude <= DISCO.NearRadius and math.abs(offset.Y) <= DISCO.NearRadius then
		return center, floorY, true
	end
	local ground = groundY or (focus.Y - 4)
	return Vector3.new(focus.X, ground + DISCO.RigHeight, focus.Z), ground, false
end

-- The mirror ball's tiles: rings from pole to pole, as many square tiles round each ring as
-- fit, each ring set half a tile round from the last. Directions point out from the middle.
local function ballTiles(radius, tileSize)
	local tiles = {}
	local rings = math.max(4, math.floor(math.pi * radius / tileSize))
	for ring = 0, rings - 1 do
		local latitude = -math.pi / 2 + (ring + 0.5) * math.pi / rings
		local around = math.max(3, math.floor(2 * math.pi * radius * math.cos(latitude) / tileSize))
		for index = 0, around - 1 do
			local longitude = (index + (ring % 2) * 0.5) / around * math.pi * 2
			table.insert(tiles, {
				Direction = Vector3.new(math.cos(latitude) * math.cos(longitude), math.sin(latitude), math.cos(latitude) * math.sin(longitude)),
				Latitude = latitude,
				Longitude = longitude,
				Mirror = (ring + index) % 3 == 0,
			})
		end
	end
	return tiles
end

-- Which way beam `index` points in the ball's own frame, and how far below the horizon:
-- odd beams on the outer ring, even ones on the inner, evenly round, each ring half a step
-- round from the other. (`now` is kept for callers; the cone does not wobble.)
local function spotDirection(index, now)
	local ring = (index - 1) % #DISCO.SpotPitches + 1
	local pitch = math.rad(DISCO.SpotPitches[ring])
	local yaw = (index - 1) / DISCO.Spots * math.pi * 2
	return Vector3.new(math.cos(pitch) * math.cos(yaw), -math.sin(pitch), math.cos(pitch) * math.sin(yaw)), pitch
end

local function invisiblePart(name, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(1, 1, 1)
	part.Parent = parent
	return part
end

local function solidPart(name, shape, size, color, material, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Size = size
	part.Color = color
	part.Material = material
	part.Parent = parent
	return part
end

-- A mirror ball as one solid piece (both the big one and the players' copies): a silver,
-- reflective core, and the tiles set flush into it (each half sunk in, so no light shows
-- between a tile and the core), each ring's tiles as wide as the ring allows so they close
-- up edge to edge. The tiles' axes come from the ring's own east and north (not lookAt,
-- which twists near the poles). It used to float its tiles a fraction of a stud off a
-- smaller dark core, which read as panels coming loose.
--   `radius` the ball's outer surface, `tileSize` about how big a tile is, `thickness` how
--   thick; `piece(part, offset)` places each part in the ball's frame. Returns the tiles.
local function tileFrame(tile, radius, thickness)
	local latitude, longitude = tile.Latitude, tile.Longitude
	local outward = tile.Direction
	local east = Vector3.new(-math.sin(longitude), 0, math.cos(longitude))
	local north = outward:Cross(east)
	-- (-east) x north is -outward, so the tile's front (LookVector) faces out.
	return CFrame.fromMatrix(outward * (radius - thickness / 2), -east, north), latitude
end

local function buildMirrorBall(radius, tileSize, thickness, piece, folder, neonColour)
	piece(
		solidPart("Core", Enum.PartType.Ball, Vector3.one * (radius - thickness * 0.6) * 2, MIRROR, Enum.Material.SmoothPlastic, folder),
		CFrame.new()
	).Reflectance = 0.45
	local rings = math.max(4, math.floor(math.pi * radius / tileSize))
	local ringHeight = math.pi * radius / rings
	local tiles = {}
	for _, tile in ballTiles(radius, tileSize) do
		local around = math.max(3, math.floor(2 * math.pi * radius * math.cos(tile.Latitude) / tileSize))
		local width = 2 * math.pi * radius * math.cos(tile.Latitude) / around
		local part = solidPart(
			if tile.Mirror then "Mirror" else "Neon",
			Enum.PartType.Block,
			Vector3.new(width * 0.94, ringHeight * 0.94, thickness),
			if tile.Mirror then MIRROR else neonColour,
			if tile.Mirror then Enum.Material.SmoothPlastic else Enum.Material.Neon,
			folder
		)
		if tile.Mirror then
			part.Reflectance = 0.55
		end
		piece(part, (tileFrame(tile, radius, thickness)))
		tile.Part = part
		tile.Seed = math.random() * 100
		tile.Width = width * 0.94
		tile.Height = ringHeight * 0.94
		table.insert(tiles, tile)
	end
	return tiles
end

-- The dance floor (Workspace.AdminDiscoFloor, AdminDiscoFloorSize): light-up tiles over the
-- lobby floor, a glowing rim round them, and a sign over the ball. The tiles play light
-- shows by the server's clock, the same for everyone, each flowing into the next: a rainbow
-- wave, ripples from the middle, a pulsing checkerboard and a turning spiral.
local DANCE_FLOOR = {
	TileSize = 10, -- about; tiles stretch a little to fill the floor exactly
	Gap = 0.5,
	Lift = 0.07, -- the tiles' middle over the floor
	ShowSeconds = 10, -- each light show
	BlendSeconds = 2, -- flowing from one show into the next
	ColourSeconds = 1 / 30,
	LowPowerColourSeconds = 1 / 12,
	-- A camera this far from the floor sees little of it: the tiles repaint twice a second.
	FarDistance = 300,
	FarColourSeconds = 0.5,
}

-- The colour of the tile in column `column`, row `row` of a `columns` x `rows` floor, at
-- server time `t`: hue and brightness of one light show.
local function floorShow(show, column, row, columns, rows, t)
	local x = (column + 0.5) / columns * 2 - 1
	local z = (row + 0.5) / rows * 2 - 1
	local ring = math.sqrt((x * columns) ^ 2 + (z * rows) ^ 2) / 2
	if show == 1 then
		-- A rainbow wave rolling across.
		return (column * 0.06 + row * 0.04 - t * 0.25) % 1, 1
	elseif show == 2 then
		-- Ripples from the middle.
		return (t * 0.05 + ring * 0.07) % 1, 0.35 + 0.65 * math.max(0, math.sin(ring * 0.9 - t * 3))
	elseif show == 3 then
		-- A checkerboard pulsing to a beat, the two colours trading places.
		local beat = 0.5 + 0.5 * math.sin(t * math.pi * 2)
		local odd = (column + row) % 2
		return (t * 0.08 + odd * 0.5) % 1, if odd == 0 then 0.4 + 0.6 * beat else 1 - 0.6 * beat
	end
	-- A spiral turning.
	local angle = math.atan2(z, x)
	return (angle / (math.pi * 2) + ring * 0.05 - t * 0.2) % 1, 0.6 + 0.4 * math.sin(angle * 3 + t * 2)
end

-- Which show is on at server time `t`, the next one, and how far it has flowed into it.
local function floorShowsAt(t)
	local phase = t / DANCE_FLOOR.ShowSeconds
	local index = math.floor(phase)
	local into = (phase - index) * DANCE_FLOOR.ShowSeconds - (DANCE_FLOOR.ShowSeconds - DANCE_FLOOR.BlendSeconds)
	local blend = math.clamp(into / DANCE_FLOOR.BlendSeconds, 0, 1)
	blend = blend * blend * (3 - 2 * blend)
	return index % 4 + 1, (index + 1) % 4 + 1, blend
end

local function floorColour(column, row, columns, rows, t)
	local current, following, blend = floorShowsAt(t)
	local hueA, valueA = floorShow(current, column, row, columns, rows, t)
	local colour = Color3.fromHSV(hueA, 0.9, valueA)
	if blend > 0 then
		local hueB, valueB = floorShow(following, column, row, columns, rows, t)
		colour = colour:Lerp(Color3.fromHSV(hueB, 0.9, valueB), blend)
	end
	return colour
end

local function buildDanceFloor(floor, size, folder)
	local columns = math.max(2, math.floor(size.X / DANCE_FLOOR.TileSize + 0.5))
	local rows = math.max(2, math.floor(size.Z / DANCE_FLOOR.TileSize + 0.5))
	local width, length = size.X / columns, size.Z / rows
	local tiles = {}
	for column = 0, columns - 1 do
		for row = 0, rows - 1 do
			local tile = solidPart(
				"DanceTile",
				Enum.PartType.Block,
				Vector3.new(width - DANCE_FLOOR.Gap, 0.12, length - DANCE_FLOOR.Gap),
				Color3.new(1, 1, 1),
				Enum.Material.Neon,
				folder
			)
			tile.Transparency = 1
			tile.CFrame = CFrame.new(
				floor.X - size.X / 2 + (column + 0.5) * width,
				floor.Y + DANCE_FLOOR.Lift,
				floor.Z - size.Z / 2 + (row + 0.5) * length
			)
			table.insert(tiles, { Part = tile, Column = column, Row = row })
		end
	end
	local rim = {}
	for _, side in {
		{ Vector3.new(0, 0, -size.Z / 2 - 0.75), Vector3.new(size.X + 3, 0.2, 1.5) },
		{ Vector3.new(0, 0, size.Z / 2 + 0.75), Vector3.new(size.X + 3, 0.2, 1.5) },
		{ Vector3.new(-size.X / 2 - 0.75, 0, 0), Vector3.new(1.5, 0.2, size.Z) },
		{ Vector3.new(size.X / 2 + 0.75, 0, 0), Vector3.new(1.5, 0.2, size.Z) },
	} do
		local strip = solidPart("DanceRim", Enum.PartType.Block, side[2], Color3.new(1, 1, 1), Enum.Material.Neon, folder)
		strip.Transparency = 1
		strip.CFrame = CFrame.new(floor + side[1] + Vector3.new(0, 0.1, 0))
		table.insert(rim, strip)
	end
	return { Tiles = tiles, Columns = columns, Rows = rows, Rim = rim, Floor = floor, Size = size, NextColour = 0 }
end

local function discoSign(root)
	local sign = Instance.new("BillboardGui")
	sign.Name = "DiscoSign"
	sign.Size = UDim2.fromScale(30, 7)
	sign.StudsOffsetWorldSpace = Vector3.new(0, DISCO.BallRadius + 9, 0)
	sign.MaxDistance = 350
	sign.LightInfluence = 0
	sign.Parent = root
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 0.62)
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Text = "DISCO PARTY"
	title.Parent = sign
	local titleStroke = Instance.new("UIStroke")
	titleStroke.Color = Color3.fromRGB(11, 27, 45)
	titleStroke.Thickness = 3
	titleStroke.Parent = title
	local rainbow = Instance.new("UIGradient")
	rainbow.Name = "Rainbow"
	rainbow.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 200)),
		ColorSequenceKeypoint.new(0.35, Color3.fromRGB(120, 90, 255)),
		ColorSequenceKeypoint.new(0.7, Color3.fromRGB(60, 220, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 80, 200)),
	})
	rainbow.Parent = title
	local hint = Instance.new("TextLabel")
	hint.Name = "Hint"
	hint.BackgroundTransparency = 1
	hint.Position = UDim2.fromScale(0, 0.62)
	hint.Size = UDim2.fromScale(1, 0.38)
	hint.Font = Enum.Font.FredokaOne
	hint.TextScaled = true
	hint.TextColor3 = Color3.fromRGB(255, 230, 90)
	hint.Text = "Dance for x100 Speed! Stand still here or type /e dance"
	hint.Parent = sign
	local hintStroke = Instance.new("UIStroke")
	hintStroke.Color = Color3.fromRGB(11, 27, 45)
	hintStroke.Thickness = 2
	hintStroke.Parent = hint
	return sign
end

-- `pulse` is the music's beat: every tile flares a little brighter on it.
local function updateDanceFloor(danceFloor, w, clock, now, pulse)
	if now >= danceFloor.NextColour then
		local camera = Workspace.CurrentCamera
		local far = camera and typeof(danceFloor.Floor) == "Vector3" and (camera.CFrame.Position - danceFloor.Floor).Magnitude > DANCE_FLOOR.FarDistance
		danceFloor.NextColour = now + (if far then DANCE_FLOOR.FarColourSeconds elseif LOW_POWER then DANCE_FLOOR.LowPowerColourSeconds else DANCE_FLOOR.ColourSeconds)
		local flare = 0.22 * pulse
		local shown = 1 - (0.72 + 0.18 * pulse) * w
		for _, tile in danceFloor.Tiles do
			tile.Part.Color = floorColour(tile.Column, tile.Row, danceFloor.Columns, danceFloor.Rows, clock):Lerp(Color3.new(1, 1, 1), flare)
			tile.Part.Transparency = shown
		end
		for index, strip in danceFloor.Rim do
			strip.Color = Color3.fromHSV((clock * 0.1 + index * 0.25) % 1, 0.8, 0.7 + 0.3 * pulse)
			strip.Transparency = 1 - 0.9 * w
		end
	end
end

-- Dancing: standing still on the dance floor while the disco is on, the player dances, one
-- of Roblox's dances, a new one every little while. Moving, jumping, leaving the floor, a
-- treadmill, a ragdoll or the disco ending stops it.
local DANCES = {
	R15 = { "rbxassetid://507771019", "rbxassetid://507776043", "rbxassetid://507777268" },
	R6 = { "rbxassetid://182435998", "rbxassetid://182436842", "rbxassetid://182436935" },
}
local DANCE = { StillSeconds = 0.35, SwitchSeconds = 10, Height = 12 }
local dancing = { Track = nil, Animator = nil, Still = 0, Since = 0, Index = 0 }

-- Whether a player standing at `position` is on the dance floor.
local function onDanceFloor(position, floor, size)
	local offset = position - floor
	return math.abs(offset.X) <= size.X / 2 and math.abs(offset.Z) <= size.Z / 2 and offset.Y >= -1 and offset.Y <= DANCE.Height
end

local function stopDancing()
	if dancing.Track then
		pcall(function()
			dancing.Track:Stop(0.25)
		end)
		dancing.Track = nil
	end
	dancing.Animator = nil
end

local function startDance(humanoid, animator)
	local list = if humanoid.RigType == Enum.HumanoidRigType.R6 then DANCES.R6 else DANCES.R15
	dancing.Index = dancing.Index % #list + 1
	local animation = Instance.new("Animation")
	animation.Name = "AdminDiscoDance"
	animation.AnimationId = list[dancing.Index]
	local ok, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	if not ok or not track then
		return
	end
	-- Above the character's own idle and run animations (Action) and its jump (Action2).
	track.Priority = Enum.AnimationPriority.Action3
	track.Looped = true
	local previous = dancing.Track
	track:Play(0.3)
	if previous then
		pcall(function()
			previous:Stop(0.3)
		end)
	end
	dancing.Track = track
	dancing.Animator = animator
	dancing.Since = os.clock()
end

local function updateDance(dt)
	local humanoid, root = character()
	local floor = Workspace:GetAttribute("AdminDiscoFloor")
	local size = Workspace:GetAttribute("AdminDiscoFloorSize")
	local model = player.Character
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	local canDance = disco ~= nil
		and discoWeight >= 0.5
		and humanoid ~= nil
		and root ~= nil
		and animator ~= nil
		and typeof(floor) == "Vector3"
		and typeof(size) == "Vector3"
		and onDanceFloor(root.Position, floor, size)
		and humanoid.MoveDirection.Magnitude < 0.1
		and humanoid.FloorMaterial ~= Enum.Material.Air
		and not humanoid.Sit
		and player:GetAttribute("IsOnTreadmill") ~= true
		and not (model and (model:GetAttribute("Ragdolled") == true or model:GetAttribute("Dead") == true))
	if not canDance then
		dancing.Still = 0
		stopDancing()
		return
	end
	dancing.Still += dt
	if dancing.Animator ~= animator then
		-- A new character: its old dance went with the old one.
		dancing.Track = nil
		dancing.Animator = nil
	end
	if dancing.Still >= DANCE.StillSeconds and (dancing.Track == nil or os.clock() - dancing.Since >= DANCE.SwitchSeconds) then
		startDance(humanoid, animator)
	end
end

local function buildDisco(center)
	local folder = Instance.new("Folder")
	folder.Name = "AdminDiscoLocal"
	local radius = DISCO.BallRadius

	-- The ball floats on its own: no chain, no cap. Every piece is anchored and has its
	-- place in the ball's own frame (Offsets); each frame the whole ball is set down at its
	-- new turn in one BulkMoveTo, so it turns as one piece without any joint.
	local parts, offsets = {}, {}
	local function piece(part, offset)
		table.insert(parts, part)
		table.insert(offsets, offset)
		part.CFrame = CFrame.new(center) * offset
		return part
	end
	local root = piece(invisiblePart("BallRoot", folder), CFrame.new())
	local tiles = buildMirrorBall(radius, DISCO.TileSize, DISCO.TileThickness, piece, folder, Color3.fromRGB(120, 80, 255))
	local glow = Instance.new("PointLight")
	glow.Name = "Glow"
	glow.Range = 60
	glow.Brightness = 0
	glow.Shadows = false
	glow.Parent = root
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name = "Sparkles"
	sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkles.LightEmission = 1
	sparkles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.1), NumberSequenceKeypoint.new(1, 0) })
	sparkles.Lifetime = NumberRange.new(1.2, 2.2)
	sparkles.Speed = NumberRange.new(5, 11)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Rate = 0
	sparkles.Parent = root
	-- The wash: one wide light just under the ball, straight down onto the dance floor.
	local washHolder = piece(invisiblePart("Wash", folder), CFrame.new(0, -radius - 0.5, 0) * CFrame.Angles(-math.pi / 2, 0, 0))
	local wash = Instance.new("SpotLight")
	wash.Name = "Wash"
	wash.Face = Enum.NormalId.Front
	wash.Angle = DISCO.WashAngle
	wash.Range = 60
	wash.Brightness = 0
	wash.Shadows = false
	wash.Parent = washHolder

	-- The spots: where each ray from the ball's middle meets the floor, a dot of colour. No
	-- beam is drawn between them.
	local spots = {}
	for index = 1, DISCO.Spots do
		local direction = spotDirection(index, 0)
		local dot = solidPart("Dot", Enum.PartType.Cylinder, Vector3.new(0.08, 7, 7), Color3.new(1, 1, 1), Enum.Material.Neon, folder)
		dot.Transparency = 1
		table.insert(spots, { Index = index, Direction = direction, Dot = dot })
	end
	local wanderers = {}
	for index = 1, DISCO.Wanderers do
		local holder = invisiblePart("Wanderer", folder)
		local light = Instance.new("PointLight")
		light.Range = 24
		light.Brightness = 0
		light.Shadows = false
		light.Parent = holder
		table.insert(wanderers, {
			Part = holder,
			Light = light,
			Phase = index / DISCO.Wanderers,
			Radius = 14 + index * 4,
			Speed = 0.25 + (index % 4) * 0.08,
		})
	end
	-- The dance floor under it, and the sign over it.
	local floor = Workspace:GetAttribute("AdminDiscoFloor")
	local size = Workspace:GetAttribute("AdminDiscoFloorSize")
	local danceFloor = if typeof(floor) == "Vector3" and typeof(size) == "Vector3" then buildDanceFloor(floor, size, folder) else nil
	local sign = discoSign(root)
	folder.Parent = Workspace
	local tint = Instance.new("ColorCorrectionEffect")
	tint.Name = "AdminDiscoTint"
	tint.Parent = Lighting
	disco = {
		Folder = folder,
		Root = root,
		Parts = parts,
		Offsets = offsets,
		Frames = table.create(#parts),
		Angle = 0,
		DanceFloor = danceFloor,
		Sign = sign,
		Tiles = tiles,
		Glow = glow,
		Wash = wash,
		Sparkles = sparkles,
		Spots = spots,
		Wanderers = wanderers,
		Tint = tint,
		Center = center,
		Near = 1,
		GroundY = nil,
		NextProbe = 0,
		NextTileColour = 0,
		Clock = nil,
		Beat = newBeat(),
	}
end

-- Sets every piece of the ball down at `frame` (the ball's middle and turn) in one go.
local function moveBall(ball, frame)
	local frames = ball.Frames
	for index, offset in ball.Offsets do
		frames[index] = frame * offset
	end
	local moved = pcall(function()
		Workspace:BulkMoveTo(ball.Parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	end)
	if not moved then
		for index, part in ball.Parts do
			part.CFrame = frames[index]
		end
	end
end

-- Off the dance floor the party goes with you: a small copy of the mirror ball hangs a
-- little over each player's head (yours, and on stronger devices the nearest others),
-- turning like the big one, its light on them, and their outline (a Highlight) running
-- through the party's colours. Back on the floor the copy goes; the big ball is there.
local FOLLOWER = {
	Radius = 1.7,
	TileSize = 1,
	TileThickness = 0.12,
	Height = 6.5, -- over the character's root: about two studs clear of the head
	Bob = 0.35,
	SpinDegrees = 50, -- a slow, smooth turn
	FollowRate = 8, -- how quickly it catches up with the player
	Range = 120, -- other players' copies are drawn this close to the camera
	Max = 6,
	LightRange = 14,
	ColourSeconds = 1 / 15,
}
local followers = {} -- character model -> its copy of the ball

-- True when `position` is over the dance floor (a jump counts).
local function onDanceFloor(position)
	local floor = Workspace:GetAttribute("AdminDiscoFloor")
	local size = Workspace:GetAttribute("AdminDiscoFloorSize")
	if typeof(floor) ~= "Vector3" or typeof(size) ~= "Vector3" then
		return false
	end
	return math.abs(position.X - floor.X) <= size.X / 2
		and math.abs(position.Z - floor.Z) <= size.Z / 2
		and position.Y > floor.Y - 6
		and position.Y < floor.Y + 40
end

local function buildFollower(model, parent)
	local folder = Instance.new("Folder")
	folder.Name = "AdminDiscoFollower"
	local parts, offsets = {}, {}
	local function piece(part, offset)
		table.insert(parts, part)
		table.insert(offsets, offset)
		return part
	end
	local root = piece(invisiblePart("BallRoot", folder), CFrame.new())
	local tiles = buildMirrorBall(FOLLOWER.Radius, FOLLOWER.TileSize, FOLLOWER.TileThickness, piece, folder, Color3.fromRGB(120, 80, 255))
	local light = Instance.new("PointLight")
	light.Name = "Glow"
	light.Range = FOLLOWER.LightRange
	light.Brightness = 0
	light.Shadows = false
	light.Parent = root
	local outline = Instance.new("Highlight")
	outline.Name = "AdminDiscoOutline"
	outline.FillTransparency = 1
	outline.OutlineTransparency = 1
	outline.DepthMode = Enum.HighlightDepthMode.Occluded
	outline.Adornee = model
	outline.Parent = folder
	folder.Parent = parent
	return {
		Folder = folder,
		Root = root,
		Parts = parts,
		Offsets = offsets,
		Frames = table.create(#parts),
		Tiles = tiles,
		Light = light,
		Outline = outline,
		Angle = math.random() * math.pi * 2,
		Phase = math.random(),
		Position = nil,
		NextColour = 0,
	}
end

local function removeFollower(model)
	local follower = followers[model]
	if follower then
		follower.Folder:Destroy()
		followers[model] = nil
	end
end

-- Places, turns and colours every copy for this frame; makes the missing ones and removes
-- the ones no longer wanted (on the floor, gone, too far, or the party over).
local function updateFollowers(dt, w, serverNow, now, pulse, cameraPosition)
	local wanted = {}
	if w > 0 and disco then
		local candidates = {}
		for _, other in Players:GetPlayers() do
			if other == player or not LOW_POWER then
				local model = other.Character
				local root = model and model:FindFirstChild("HumanoidRootPart")
				local humanoid = model and model:FindFirstChildOfClass("Humanoid")
				if root and root:IsA("BasePart") and (humanoid == nil or humanoid.Health > 0) then
					local position = root.CFrame.Position
					local distance = if other == player then -1 else (position - cameraPosition).Magnitude
					if distance <= FOLLOWER.Range and not onDanceFloor(position) then
						table.insert(candidates, { Model = model, Position = position, Distance = distance })
					end
				end
			end
		end
		table.sort(candidates, function(a, b)
			return a.Distance < b.Distance
		end)
		for index = 1, math.min(#candidates, FOLLOWER.Max) do
			local candidate = candidates[index]
			local follower = followers[candidate.Model]
			if not follower then
				follower = buildFollower(candidate.Model, disco.Folder)
				followers[candidate.Model] = follower
			end
			wanted[candidate.Model] = true
			local target = candidate.Position + Vector3.new(0, FOLLOWER.Height + math.sin(serverNow * 2 + follower.Phase * 6) * FOLLOWER.Bob, 0)
			follower.Position = if follower.Position then follower.Position:Lerp(target, math.min(1, dt * FOLLOWER.FollowRate)) else target
			follower.Angle = (follower.Angle + math.rad(FOLLOWER.SpinDegrees) * dt) % (math.pi * 2)
			moveBall(follower, CFrame.new(follower.Position) * CFrame.Angles(0, follower.Angle, 0))
			-- The outline and the light run through the colours together.
			local colour = Color3.fromHSV((serverNow * 0.25 + follower.Phase) % 1, 0.85, 1)
			follower.Outline.OutlineColor = colour
			follower.Outline.OutlineTransparency = 1 - w
			follower.Light.Color = colour
			follower.Light.Brightness = (2.5 + 3 * pulse) * w
			if now >= follower.NextColour then
				follower.NextColour = now + FOLLOWER.ColourSeconds
				for _, tile in follower.Tiles do
					if tile.Mirror then
						-- Silver catching the light now and then.
						local glint = math.max(0, math.sin(serverNow * 2.6 + tile.Seed)) ^ 14
						tile.Part.Color = MIRROR:Lerp(Color3.new(1, 1, 1), glint)
					else
						local band = (tile.Longitude / (math.pi * 2) + serverNow * 0.3) % 1
						tile.Part.Color = Color3.fromHSV(band, 0.85, 0.8 + 0.2 * pulse)
					end
				end
			end
		end
	end
	for model in followers do
		if not wanted[model] then
			removeFollower(model)
		end
	end
end

local function removeDisco()
	for model in followers do
		removeFollower(model)
	end
	disco.Folder:Destroy()
	disco.Tint:Destroy()
	disco = nil
end

local function updateDisco(dt)
	local active = discoActive()
	if not active and discoWeight == 0 then
		return
	end
	local center = Workspace:GetAttribute("AdminDiscoCenter")
	local floor = Workspace:GetAttribute("AdminDiscoFloor")
	if not disco then
		if not active then
			discoWeight = 0
			return
		end
		buildDisco(center)
	end
	discoWeight = math.clamp(discoWeight + (if active then dt else -dt) / DISCO.BlendSeconds, 0, 1)
	local w = discoWeight
	if typeof(center) == "Vector3" and typeof(floor) == "Vector3" then
		disco.Center = center
		disco.FloorY = floor.Y
	end
	local camera = Workspace.CurrentCamera
	local now = os.clock()
	-- Everything moves by the disco's smooth clock; the lights flare on the music's beat.
	disco.Clock = discoClock(disco.Clock, Workspace:GetServerTimeNow(), dt)
	local serverNow = disco.Clock
	local hue = (serverNow * 0.015) % 1
	local onBeat = stepBeat(disco.Beat, dt, now, musicLoudness())
	local pulse = disco.Beat.Pulse * w

	-- The ball: down from above as the party starts, and turning steadily round its
	-- vertical axis, a little more every frame, for as long as the party is on.
	disco.Angle = (disco.Angle + math.rad(DISCO.SpinDegrees) * dt) % (math.pi * 2)
	local spin = CFrame.Angles(0, disco.Angle, 0)
	local ballCenter = disco.Center + Vector3.new(0, (1 - eased(w)) * DISCO.DropHeight, 0)
	moveBall(disco, CFrame.new(ballCenter) * spin)
	disco.Glow.Color = Color3.fromHSV(hue, 0.45, 1)
	disco.Glow.Brightness = 4 * w + 6 * pulse
	disco.Wash.Color = Color3.fromHSV((hue + 0.5) % 1, 0.55, 1)
	disco.Wash.Brightness = 3 * w + 7 * pulse
	if disco.DanceFloor then
		updateDanceFloor(disco.DanceFloor, w, serverNow, now, pulse)
	end
	disco.Sign.Enabled = w > 0.05
	disco.Sign.Title.Rainbow.Offset = Vector2.new(math.sin(now * 1.2) * 0.4, 0)
	if now >= disco.NextTileColour then
		disco.NextTileColour = now + (if LOW_POWER then 1 / 12 else DISCO.TileColourSeconds)
		for _, tile in disco.Tiles do
			if tile.Mirror then
				-- Silver catching the light now and then.
				local glint = math.max(0, math.sin(serverNow * 2.3 + tile.Seed)) ^ 14
				tile.Part.Color = MIRROR:Lerp(Color3.new(1, 1, 1), glint)
			else
				-- Bands of colour swirling round the ball.
				local band = (tile.Longitude / (math.pi * 2) + tile.Latitude / math.pi * 0.6 + serverNow * 0.12) % 1
				tile.Part.Color = Color3.fromHSV(band, 0.85 - 0.25 * pulse, (0.35 + 0.65 * w) * (0.78 + 0.22 * pulse))
			end
		end
	end

	if camera then
		local _, root = character()
		local focus = if root then root.Position else camera.Focus.Position
		if now >= disco.NextProbe then
			disco.NextProbe = now + 0.25
			disco.GroundY = groundBelow(focus + Vector3.new(0, 3, 0))
		end
		local rig, floorY, near = discoAnchor(camera.CFrame.Position, ballCenter, disco.FloorY, focus, disco.GroundY)
		-- Moving between the lobby and the map, the ball's spots fade rather than jump.
		disco.Near = math.clamp(disco.Near + (if near then dt else -dt) / 0.8, 0, 1)
		local shown = w * disco.Near
		-- Each spot lands where its ray from the ball's middle meets the floor, turning with
		-- the ball; away from the ball (out on the map) they fade.
		for _, spot in disco.Spots do
			local direction = spin:VectorToWorldSpace(spot.Direction)
			local pitch = math.asin(math.clamp(-spot.Direction.Y, 0.2, 1))
			local reach = math.max(DISCO.BallRadius + 1, (ballCenter.Y - (disco.FloorY or floorY)) / math.sin(pitch))
			local hit = ballCenter + direction * reach
			local colour = Color3.fromHSV((spot.Index / DISCO.Spots + serverNow * 0.05) % 1, 0.8, 1)
			local spread = math.clamp((reach - DISCO.BallRadius) * math.tan(math.rad(DISCO.SpotAngle / 2)) * 1.1, 4, 10)
			spot.Hit = hit
			spot.Dot.Size = Vector3.new(0.08, spread, spread)
			spot.Dot.CFrame = CFrame.new(hit + Vector3.new(0, 0.14, 0)) * CFrame.Angles(0, 0, math.rad(90))
			spot.Dot.Color = colour
			spot.Dot.Transparency = 1 - (0.6 + 0.3 * pulse) * shown
		end
		for _, wanderer in disco.Wanderers do
			local angle = wanderer.Phase * math.pi * 2 + now * wanderer.Speed
			local radius = wanderer.Radius + math.sin(now * 0.7 + wanderer.Phase * 12) * 6
			wanderer.Part.CFrame = CFrame.new(rig.X + math.cos(angle) * radius, floorY + 3, rig.Z + math.sin(angle) * radius)
			wanderer.Light.Color = Color3.fromHSV((wanderer.Phase + serverNow * 0.04) % 1, 0.8, 1)
			wanderer.Light.Brightness = 4 * w
		end
		disco.Sparkles.Rate = 20 * shown
		disco.Sparkles.Color = ColorSequence.new(Color3.fromHSV(hue, 0.5, 1))
		if onBeat and shown > 0.3 then
			pcall(function()
				disco.Sparkles:Emit(14)
			end)
		end
		updateFollowers(dt, w, serverNow, now, pulse, camera.CFrame.Position)
	end

	-- The sky's colour drifting slowly round (the light mixer blends it in).
	discoColors.Ambient = Color3.fromHSV(hue, 0.5, 0.4)
	discoColors.OutdoorAmbient = Color3.fromHSV((hue + 0.08) % 1, 0.55, 0.36)
	disco.Tint.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromHSV(hue, 0.14, 1), w)
	disco.Tint.Saturation = 0.2 * w
	disco.Tint.Contrast = 0.08 * w
	disco.Tint.Brightness = 0.04 * pulse
	if not active and discoWeight == 0 then
		removeDisco()
	end
end

-- The DJ booth (Workspace.AdminDJBooth, built by AdminAbusePanelService): its neon, its
-- equaliser bars, its woofer rings and its spotlights move with the music's beat. It
-- arrives in a burst of confetti and, when the party ends (its Leaving attribute), fades
-- away into more.
local DJ = { FadeSeconds = 1.6, ArriveBurst = 70, LeaveBurst = 160 }
local djBooth = nil -- the booth this client is lighting: its parts by role, and how it fades

-- `scale` is the booth's (its DJScale): a giant booth throws giant confetti, further.
local function confettiBurst(position, count, scale)
	scale = scale or 1
	local holder = Instance.new("Part")
	holder.Name = "AdminDJConfetti"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.new(10, 1, 10) * scale
	holder.CFrame = CFrame.new(position)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Confetti"
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 200)),
		ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 60)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(90, 230, 110)),
		ColorSequenceKeypoint.new(0.75, Color3.fromRGB(80, 190, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 110, 255)),
	})
	emitter.LightEmission = 0.4
	emitter.Size = NumberSequence.new(0.6 * scale)
	emitter.Lifetime = NumberRange.new(1.6, 2.6)
	emitter.Speed = NumberRange.new(16 * scale, 30 * scale)
	emitter.SpreadAngle = Vector2.new(60, 60)
	emitter.Acceleration = Vector3.new(0, -26 * scale, 0)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-300, 300)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Rate = 0
	emitter.Parent = holder
	holder.Parent = Workspace
	pcall(function()
		emitter:Emit(count)
	end)
	task.delay(3, function()
		holder:Destroy()
	end)
	return holder
end

local function readBooth(model)
	local booth = { Model = model, Neon = {}, Bars = {}, Woofers = {}, Spots = {}, LeftAt = nil, Looks = nil }
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			if part:GetAttribute("DJNeon") ~= nil then
				table.insert(booth.Neon, part)
			end
			if part:GetAttribute("DJBar") ~= nil then
				table.insert(booth.Bars, part)
			end
			if part:GetAttribute("DJWoofer") ~= nil then
				table.insert(booth.Woofers, part)
			end
			if part:GetAttribute("DJSpot") ~= nil then
				table.insert(booth.Spots, { Part = part, Light = part:FindFirstChildOfClass("SpotLight") })
			end
		end
	end
	local stage = model:FindFirstChild("Stage")
	booth.Centre = if stage then stage.CFrame.Position else nil
	booth.Scale = tonumber(model:GetAttribute("DJScale")) or 1
	return booth
end

-- How tall equaliser bar `index` stands at time `t` (0 to 1), jumping on the beat.
local function barLevel(index, t, pulse)
	local wave = math.noise(index * 0.63, t * 2.4) * 0.5 + 0.5
	return math.clamp(0.12 + 0.88 * wave * (0.55 + 0.45 * pulse), 0.08, 1)
end

local function updateDJBooth(dt)
	local model = Workspace:FindFirstChild("AdminDJBooth")
	if djBooth and djBooth.Model ~= model then
		djBooth = nil
	end
	if not model then
		return
	end
	if not djBooth then
		djBooth = readBooth(model)
		if djBooth.Centre and model:GetAttribute("Leaving") == nil then
			confettiBurst(djBooth.Centre + Vector3.new(0, 2 * djBooth.Scale, 0), DJ.ArriveBurst, djBooth.Scale)
		end
	end
	local clock = if disco and disco.Clock then disco.Clock else Workspace:GetServerTimeNow()
	local pulse = if disco then disco.Beat.Pulse else 0.5 + 0.5 * math.sin(clock * math.pi * 4)

	for _, part in djBooth.Neon do
		if part:GetAttribute("DJBar") == nil then
			part.Color = Color3.fromHSV((part:GetAttribute("DJNeon") + clock * 0.1) % 1, 0.85, 0.65 + 0.35 * pulse)
		end
	end
	for _, bar in djBooth.Bars do
		local foot = bar:GetAttribute("DJBarFoot")
		local tallest = tonumber(bar:GetAttribute("DJBarMax")) or 8
		if typeof(foot) == "CFrame" then
			local level = barLevel(bar:GetAttribute("DJBar"), clock, pulse)
			local height = tallest * level
			bar.Size = Vector3.new(bar.Size.X, height, bar.Size.Z)
			bar.CFrame = foot * CFrame.new(0, height / 2, 0)
			-- Green when low, through gold, to pink at the top, as an equaliser.
			bar.Color = Color3.fromHSV((0.33 - 0.42 * level) % 1, 0.85, 1)
		end
	end
	for _, ring in djBooth.Woofers do
		ring.Color = Color3.new(1, 1, 1):Lerp(Color3.fromHSV((clock * 0.1) % 1, 0.8, 1), 1 - 0.7 * pulse)
	end
	for index, spot in djBooth.Spots do
		if spot.Light then
			spot.Light.Color = Color3.fromHSV((index / 4 + clock * 0.08) % 1, 0.7, 1)
			spot.Light.Brightness = 4 + 8 * pulse
		end
	end
	local rig = model:FindFirstChild("DJ")
	local head = rig and rig:FindFirstChild("Head")
	local sign = head and head:FindFirstChild("DJSign")
	local title = sign and sign:FindFirstChild("Plate") and sign.Plate:FindFirstChild("Title")
	local rainbow = title and title:FindFirstChild("Rainbow")
	if rainbow then
		rainbow.Offset = Vector2.new(math.sin(clock * 1.5) * 0.4, 0)
	end

	-- The party is over: everything fades out of sight in a shower of confetti.
	if model:GetAttribute("Leaving") ~= nil then
		local now = os.clock()
		if not djBooth.LeftAt then
			djBooth.LeftAt = now
			djBooth.Looks = {}
			for _, part in model:GetDescendants() do
				if part:IsA("BasePart") or part:IsA("Decal") then
					table.insert(djBooth.Looks, { Object = part, Transparency = part.Transparency })
				end
			end
			if djBooth.Centre then
				confettiBurst(djBooth.Centre + Vector3.new(0, 4 * djBooth.Scale, 0), DJ.LeaveBurst, djBooth.Scale)
			end
		end
		local fade = math.clamp((now - djBooth.LeftAt) / DJ.FadeSeconds, 0, 1)
		for _, look in djBooth.Looks do
			if look.Object.Parent then
				look.Object.Transparency = look.Transparency + (1 - look.Transparency) * fade
			end
		end
		for _, spot in djBooth.Spots do
			if spot.Light then
				spot.Light.Brightness *= 1 - fade
			end
		end
		if sign then
			sign.Enabled = fade < 0.6
		end
	end
end

-- Fireworks (the admin's Fireworks event): rockets whistle up from the lobby's dance floor
-- (or around the player, away from the lobby), trailing sparks, and burst into colour:
-- round peonies, rings and golden willows, each with a flash of light and a small, short
-- shake of the camera for anyone near it.
local FIREWORKS = {
	Interval = if LOW_POWER then { 2.5, 3.5 } else { 1.5, 2.5 }, -- six bursts per launch
	Rise = { 1.2, 1.9 }, -- seconds a rocket climbs
	Height = { 45, 80 }, -- how high it bursts
	Drift = 6, -- how far off straight up it may go
	NearLobby = 300, -- a camera this close to the lobby watches the lobby's show
	AroundPlayer = { 25, 70 }, -- elsewhere, rockets go up this far from the player
	ShakeRange = 220, -- bursts further than this do not shake the camera
	ShakeStuds = 0.35, -- the most a burst moves the camera, right under it
	ShakeSeconds = 0.35,
	FlashSeconds = 0.6,
	BurstLife = 3.5, -- seconds a burst's sparks linger before it is cleared
	Kinds = { "Peony", "Ring", "Willow" },
	Sounds = {
		Launch = "rbxassetid://75964117535029",
		Boom = "rbxassetid://126237860088652",
	},
}

local function spread(range)
	return range[1] + (range[2] - range[1]) * math.random()
end

local function fireworksShow(origin, size)
	local folder = Instance.new("Folder")
	folder.Name = "AdminFireworks"
	folder.Parent = Workspace
	local show = { Folder = folder, Rockets = {}, Bursts = {}, Elapsed = 0, NextLaunch = 0, ShakeUntil = 0, ShakeStrength = 0 }

	-- Where the next rocket goes up from.
	function show.LaunchPoint(cameraPosition, focus, groundY)
		if origin and (cameraPosition - origin).Magnitude < FIREWORKS.NearLobby then
			return origin + Vector3.new((math.random() - 0.5) * 0.8 * size.X, 0, (math.random() - 0.5) * 0.8 * size.Z)
		end
		local angle = math.random() * math.pi * 2
		local distance = spread(FIREWORKS.AroundPlayer)
		return Vector3.new(focus.X + math.cos(angle) * distance, groundY or (focus.Y - 3), focus.Z + math.sin(angle) * distance)
	end

	function show.Launch(from)
		local hue = math.random()
		local rocket = Instance.new("Part")
		rocket.Name = "Rocket"
		rocket.Anchored = true
		rocket.CanCollide = false
		rocket.CanQuery = false
		rocket.CanTouch = false
		rocket.CastShadow = false
		rocket.Size = Vector3.new(0.5, 1.8, 0.5)
		rocket.Material = Enum.Material.Neon
		rocket.Color = Color3.fromHSV(hue, 0.7, 1)
		rocket.CFrame = CFrame.new(from)
		local top = Instance.new("Attachment")
		top.Position = Vector3.new(0, 0.9, 0)
		top.Parent = rocket
		local bottom = Instance.new("Attachment")
		bottom.Position = Vector3.new(0, -0.9, 0)
		bottom.Parent = rocket
		local trail = Instance.new("Trail")
		trail.Attachment0 = top
		trail.Attachment1 = bottom
		trail.Lifetime = 0.6
		trail.LightEmission = 1
		trail.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromHSV(hue, 0.8, 1))
		trail.Transparency = NumberSequence.new(0.1, 1)
		trail.Parent = rocket
		local sparks = Instance.new("ParticleEmitter")
		sparks.Name = "Sparks"
		sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparks.Color = ColorSequence.new(Color3.fromRGB(255, 210, 120), Color3.fromRGB(255, 120, 40))
		sparks.LightEmission = 1
		sparks.Size = NumberSequence.new(0.5, 0)
		sparks.Lifetime = NumberRange.new(0.35, 0.7)
		sparks.Speed = NumberRange.new(2, 5)
		sparks.SpreadAngle = Vector2.new(25, 25)
		sparks.EmissionDirection = Enum.NormalId.Bottom
		sparks.Rate = 60
		sparks.Parent = rocket

		-- V40 Startup Launch VFX (shards, sharp, pixel blob)
		local vfxTemplates = ReplicatedStorage:FindFirstChild("VfxTemplates")
		local startupTpl = vfxTemplates and vfxTemplates:FindFirstChild("Fireworks") and vfxTemplates.Fireworks:FindFirstChild("FireworkStartup")
		if startupTpl then
			local startupClone = startupTpl:Clone()
			startupClone.Anchored = true
			startupClone.CanCollide = false
			startupClone.CanTouch = false
			startupClone.CanQuery = false
			startupClone.CFrame = CFrame.new(from)
			startupClone.Parent = folder
			for _, desc in startupClone:GetDescendants() do
				if desc:IsA("ParticleEmitter") then
					desc.Enabled = false
					pcall(function()
						desc:Emit(math.clamp(tonumber(desc:GetAttribute("EmitCount")) or desc.Rate, 1, if LOW_POWER then 12 else 30))
					end)
				end
			end
			Debris:AddItem(startupClone, 2)
		else
			local startupHolder = Instance.new("Part")
			startupHolder.Name = "StartupVfx"
			startupHolder.Anchored = true
			startupHolder.CanCollide = false
			startupHolder.CanQuery = false
			startupHolder.CanTouch = false
			startupHolder.Transparency = 1
			startupHolder.Size = Vector3.new(1, 1, 1)
			startupHolder.CFrame = CFrame.new(from)
			startupHolder.Parent = folder
			local att = Instance.new("Attachment")
			att.Parent = startupHolder

			local shards = Instance.new("ParticleEmitter")
			shards.Name = "Shards"
			shards.Texture = "rbxassetid://10439119562"
			Flipbooks.Apply(shards)
			shards.Speed = NumberRange.new(50, 70)
			shards.Lifetime = NumberRange.new(0.08, 0.16)
			shards.SpreadAngle = Vector2.new(25, 25)
			shards.Orientation = Enum.ParticleOrientation.VelocityParallel
			shards.Acceleration = Vector3.new(0, -30, 0)
			shards.Drag = 10
			shards.Color = ColorSequence.new(Color3.fromRGB(255, 240, 80))
			shards.LightEmission = 0.5
			shards.Rate = 0
			shards.Parent = att

			local sharp = Instance.new("ParticleEmitter")
			sharp.Name = "Sharp"
			sharp.Texture = "http://www.roblox.com/asset/?id=17629991673"
			sharp.Speed = NumberRange.new(5, 30)
			sharp.Lifetime = NumberRange.new(0.15, 0.35)
			sharp.SpreadAngle = Vector2.new(60, 60)
			sharp.Orientation = Enum.ParticleOrientation.VelocityParallel
			sharp.Drag = 8
			sharp.Color = ColorSequence.new(Color3.fromRGB(255, 220, 100))
			sharp.Rate = 0
			sharp.Parent = att

			local blob = Instance.new("ParticleEmitter")
			blob.Name = "Blob"
			blob.Texture = "rbxassetid://8733488500"
			Flipbooks.Apply(blob)
			blob.Speed = NumberRange.new(3, 40)
			blob.Lifetime = NumberRange.new(0.15, 0.25)
			blob.Drag = 4
			blob.Color = ColorSequence.new(Color3.fromRGB(255, 240, 80))
			blob.Rate = 0
			blob.Parent = att

			shards:Emit(20)
			sharp:Emit(20)
			blob:Emit(15)
			Debris:AddItem(startupHolder, 2)
		end

		local whistle = Instance.new("Sound")
		whistle.SoundId = FIREWORKS.Sounds.Launch
		whistle.Volume = if player:GetAttribute("SoundEffects") == false or player:GetAttribute("Muted") == true then 0 else 0.6
		whistle.PlaybackSpeed = 0.95 + math.random() * 0.1
		whistle.RollOffMaxDistance = 450
		whistle.Parent = rocket
		rocket.Parent = folder
		pcall(function()
			whistle:Play()
		end)
		rocket.Parent = folder
		local destination = from + Vector3.new((math.random() - 0.5) * 2 * FIREWORKS.Drift, spread(FIREWORKS.Height), (math.random() - 0.5) * 2 * FIREWORKS.Drift)
		local entry = {
			Part = rocket,
			From = from,
			Top = destination,
			Rise = spread(FIREWORKS.Rise),
			Age = 0,
			Hue = hue,
			Kind = FIREWORKS.Kinds[math.random(1, #FIREWORKS.Kinds)],
			Wobble = math.random() * 10,
		}
		table.insert(show.Rockets, entry)
		return entry
	end

	-- A burst of kind `kind` in colour `hue` at `at`, seen from `cameraPosition`.
	function show.Burst(at, hue, kind, cameraPosition, playSound)
		local holder = Instance.new("Part")
		holder.Name = "Burst"
		holder.Anchored = true
		holder.CanCollide = false
		holder.CanQuery = false
		holder.CanTouch = false
		holder.Transparency = 1
		holder.Size = Vector3.new(1, 1, 1)
		-- Rings face any way; the others do not care.
		holder.CFrame = CFrame.new(at) * CFrame.Angles(math.random() * math.pi, math.random() * math.pi, 0)
		holder.Parent = folder

		-- V40 Burst template integration
		local vfxTemplates = ReplicatedStorage:FindFirstChild("VfxTemplates")
		local burstTpl = vfxTemplates and vfxTemplates:FindFirstChild("Fireworks") and vfxTemplates.Fireworks:FindFirstChild("FireworkBurst")
		if burstTpl then
			for _, child in burstTpl:GetChildren() do
				if child:IsA("Attachment") then
					local attClone = child:Clone()
					attClone.Parent = holder
					for _, emitter in attClone:GetChildren() do
						if emitter:IsA("ParticleEmitter") then
							emitter.Enabled = false
							pcall(function()
								emitter:Emit(math.clamp(tonumber(emitter:GetAttribute("EmitCount")) or emitter.Rate, 1, if LOW_POWER then 10 else 25))
							end)
						end
					end
				end
			end
		end

		-- Direct V40 particle additions (shockwave flash, embers, fire specs)
		local shockwave = Instance.new("ParticleEmitter")
		shockwave.Name = "PixelBurst57"
		shockwave.Texture = "rbxassetid://116373783921886"
		Flipbooks.Apply(shockwave)
		shockwave.Color = ColorSequence.new(Color3.fromHSV(hue, 0.75, 1))
		shockwave.LightEmission = 1
		shockwave.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.3, 5),
			NumberSequenceKeypoint.new(1, 7),
		})
		shockwave.Lifetime = NumberRange.new(0.2, 0.3)
		shockwave.Speed = NumberRange.new(0.1, 1)
		shockwave.Rate = 0
		shockwave.Parent = holder

		local embers = Instance.new("ParticleEmitter")
		embers.Name = "Embers"
		embers.Texture = "rbxassetid://8733488500"
		Flipbooks.Apply(embers)
		embers.Color = ColorSequence.new(Color3.fromRGB(255, 220, 120), Color3.fromRGB(255, 140, 40))
		embers.LightEmission = 0.5
		embers.Size = NumberSequence.new(0.8, 0)
		embers.Speed = NumberRange.new(12, 35)
		embers.Lifetime = NumberRange.new(0.8, 1.8)
		embers.Drag = 6
		embers.Acceleration = Vector3.new(0, -10, 0)
		embers.SpreadAngle = Vector2.new(180, 180)
		embers.Rate = 0
		embers.Parent = holder

		local fireSpecs = Instance.new("ParticleEmitter")
		fireSpecs.Name = "FireSpecs"
		fireSpecs.Texture = "rbxassetid://18802780455"
		Flipbooks.Apply(fireSpecs)
		fireSpecs.Color = ColorSequence.new(Color3.fromHSV((hue + 0.08) % 1, 0.8, 1))
		fireSpecs.LightEmission = 1
		fireSpecs.Size = NumberSequence.new(0.9, 0)
		fireSpecs.Speed = NumberRange.new(10, 45)
		fireSpecs.Lifetime = NumberRange.new(0.7, 1.4)
		fireSpecs.Drag = 4
		fireSpecs.SpreadAngle = Vector2.new(180, 180)
		fireSpecs.Rate = 0
		fireSpecs.Parent = holder

		local main = Instance.new("ParticleEmitter")
		main.Name = kind
		main.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		main.LightEmission = 1
		main.Rate = 0
		main.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.7, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		})
		local count = 120
		if kind == "Willow" then
			main.Color = ColorSequence.new(Color3.fromRGB(255, 225, 120), Color3.fromRGB(255, 150, 40))
			main.Size = NumberSequence.new(1, 0)
			main.Speed = NumberRange.new(18, 24)
			main.Lifetime = NumberRange.new(2.4, 3.2)
			main.Drag = 1.2
			main.Acceleration = Vector3.new(0, -14, 0)
			main.SpreadAngle = Vector2.new(180, 180)
			count = 110
		elseif kind == "Ring" then
			main.Color = ColorSequence.new(Color3.fromHSV(hue, 0.8, 1), Color3.fromHSV((hue + 0.1) % 1, 0.6, 1))
			main.Size = NumberSequence.new(1.3, 0)
			main.Speed = NumberRange.new(32, 36)
			main.Lifetime = NumberRange.new(1.2, 1.6)
			main.Drag = 2.5
			main.SpreadAngle = Vector2.new(180, 0)
			count = 90
		else
			main.Color = ColorSequence.new(Color3.fromHSV(hue, 0.85, 1), Color3.fromHSV((hue + 0.12) % 1, 0.7, 1))
			main.Size = NumberSequence.new(1.4, 0)
			main.Speed = NumberRange.new(28, 40)
			main.Lifetime = NumberRange.new(1.3, 1.9)
			main.Drag = 2.2
			main.Acceleration = Vector3.new(0, -6, 0)
			main.SpreadAngle = Vector2.new(180, 180)
			count = 130
		end
		main.Parent = holder
		local glitter = Instance.new("ParticleEmitter")
		glitter.Name = "Glitter"
		glitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		glitter.LightEmission = 1
		glitter.Color = ColorSequence.new(Color3.new(1, 1, 1))
		glitter.Size = NumberSequence.new(0.5, 0)
		glitter.Speed = NumberRange.new(10, 24)
		glitter.Lifetime = NumberRange.new(1, 1.6)
		glitter.SpreadAngle = Vector2.new(180, 180)
		glitter.Rate = 0
		glitter.Parent = holder
		local flash = Instance.new("PointLight")
		flash.Name = "Flash"
		flash.Color = Color3.fromHSV(hue, 0.6, 1)
		flash.Range = 60
		flash.Brightness = 10
		flash.Shadows = false
		flash.Parent = holder

		if playSound ~= false then
			local boom = Instance.new("Sound")
			boom.SoundId = FIREWORKS.Sounds.Boom
			boom.Volume = if player:GetAttribute("SoundEffects") == false or player:GetAttribute("Muted") == true then 0 else 0.8
			boom.PlaybackSpeed = 1
			boom.RollOffMaxDistance = 650
			local audioHolder = Instance.new("Part")
			audioHolder.Name = "FireworkAudio"
			audioHolder.Anchored = true
			audioHolder.CanCollide = false
			audioHolder.CanTouch = false
			audioHolder.CanQuery = false
			audioHolder.Transparency = 1
			audioHolder.CFrame = CFrame.new(at)
			audioHolder.Parent = folder
			boom.Parent = audioHolder
			boom.Ended:Once(function() audioHolder:Destroy() end)
			Debris:AddItem(audioHolder, 20)
			pcall(function()
				boom:Play()
			end)
		end

		holder.Parent = folder
		pcall(function()
			main:Emit(count)
			glitter:Emit(40)
			shockwave:Emit(3)
			embers:Emit(30)
			fireSpecs:Emit(25)
		end)
		table.insert(show.Bursts, { Part = holder, Flash = flash, Born = show.Elapsed })
		-- A small shake for anyone near, less the further away.
		local distance = (cameraPosition - at).Magnitude
		if distance < FIREWORKS.ShakeRange then
			local strength = FIREWORKS.ShakeStuds * (1 - distance / FIREWORKS.ShakeRange)
			local remaining = if show.Elapsed < show.ShakeUntil then show.ShakeStrength * (show.ShakeUntil - show.Elapsed) / FIREWORKS.ShakeSeconds else 0
			show.ShakeStrength = math.max(strength, remaining)
			show.ShakeUntil = show.Elapsed + FIREWORKS.ShakeSeconds
		end
		return holder
	end

	-- One frame: launches while `launching`, rockets climbing and bursting, flashes fading,
	-- old bursts cleared. Returns how far to move the camera this frame.
	function show.Step(dt, cameraPosition, focus, groundY, launching)
		show.Elapsed += dt
		if launching and show.Elapsed >= show.NextLaunch then
			show.NextLaunch = show.Elapsed + spread(FIREWORKS.Interval)
			show.Launch(show.LaunchPoint(cameraPosition, focus, groundY))
			if not LOW_POWER and math.random() < 0.15 then
				show.Launch(show.LaunchPoint(cameraPosition, focus, groundY))
			end
		end
		for index = #show.Rockets, 1, -1 do
			local rocket = show.Rockets[index]
			rocket.Age += dt
			local x = math.clamp(rocket.Age / rocket.Rise, 0, 1)
			local up = 1 - (1 - x) ^ 2
			local sway = math.sin(rocket.Age * 8 + rocket.Wobble) * 0.4 * (1 - x)
			rocket.Part.CFrame = CFrame.new(rocket.From:Lerp(rocket.Top, up) + Vector3.new(sway, 0, 0))
			if x >= 1 then
				local peak = rocket.Top
				local baseHue = rocket.Hue
				local baseKind = rocket.Kind
				-- Trigger multi-burst sequence of ~6 explosions matching sound 126237860088652
				show.Burst(peak, baseHue, baseKind, cameraPosition, true)
				for i = 1, 5 do
					local burstDelay = i * 0.115 + (math.random() - 0.5) * 0.02
					task.delay(burstDelay, function()
						if not folder.Parent then
							return
						end
						local offset = Vector3.new(
							(math.random() - 0.5) * 16,
							(math.random() - 0.3) * 12,
							(math.random() - 0.5) * 16
						)
						local subHue = (baseHue + i * 0.17) % 1
						local subKind = FIREWORKS.Kinds[math.random(1, #FIREWORKS.Kinds)]
						show.Burst(peak + offset, subHue, subKind, cameraPosition, false)
					end)
				end
				rocket.Part:Destroy()
				table.remove(show.Rockets, index)
			end
		end
		for index = #show.Bursts, 1, -1 do
			local burst = show.Bursts[index]
			local age = show.Elapsed - burst.Born
			burst.Flash.Brightness = 10 * math.max(0, 1 - age / FIREWORKS.FlashSeconds)
			if age >= FIREWORKS.BurstLife then
				burst.Part:Destroy()
				table.remove(show.Bursts, index)
			end
		end
		if show.Elapsed >= show.ShakeUntil then
			return Vector3.zero
		end
		local strength = show.ShakeStrength * (show.ShakeUntil - show.Elapsed) / FIREWORKS.ShakeSeconds
		local n = show.Elapsed * 40
		return Vector3.new(math.noise(n, 1.3), math.noise(n, 7.7), math.noise(n, 13.1)) * 2 * strength
	end

	function show.Stop()
		folder:Destroy()
	end
	return show
end

function EFFECTS.Fireworks(duration, _adminUserId, _adminName, payload)
	local origin = if payload and typeof(payload.origin) == "Vector3" then payload.origin else nil
	local size = if payload and typeof(payload.size) == "Vector3" then payload.size else Vector3.new(60, 0, 60)
	-- A little longer than the launches, so the last rockets still burst.
	run("Fireworks", duration + FIREWORKS.Rise[2] + 20, function()
		local show = fireworksShow(origin, size)
		local startedAt = os.clock()
		local groundY, nextProbe = nil, 0
		local connection = RunService.RenderStepped:Connect(function(dt)
			local camera = Workspace.CurrentCamera
			if not camera then
				return
			end
			local humanoid, root = character()
			local focus = if root then root.Position else camera.Focus.Position
			if os.clock() >= nextProbe then
				nextProbe = os.clock() + 0.5
				groundY = groundBelow(focus + Vector3.new(0, 3, 0))
			end
			local shake = show.Step(dt, camera.CFrame.Position, focus, groundY, os.clock() - startedAt < duration)
			if humanoid then
				humanoid.CameraOffset = shake
			end
		end)
		return function()
			connection:Disconnect()
			local humanoid = character()
			if humanoid then
				humanoid.CameraOffset = Vector3.zero
			end
			show.Stop()
		end
	end)
end

----------------------------------------------------------------------
-- Raining Tacos World Event (Workspace.AdminRainingTacosUntil):
-- Festive golden fiesta sky & atmosphere, authentic soundtrack, 2D screen rain,
-- and real 3D tacos raining from the sky that CRASH into the ground with VFX & sounds,
-- and grant free Speed if they hit the player!
----------------------------------------------------------------------
local TacoVisual = require(ReplicatedStorage.Shared:WaitForChild("TacoVisual"))
local tacoShake = 0
local TACOS = {
	Texture = "rbxassetid://84855954319870",
	FlakesTexture = "rbxassetid://13802408466",
	MusicId = "rbxassetid://142376088",
	-- 2026-09-22: both sounds are off until the owner uploads (or grants this experience)
	-- sounds he owns. 101686101827917 is "not authorized" for this experience and 9114223170
	-- is not an audio asset: one new Sound per taco made ~7 failed loads a second per phone
	-- during the event (~2.1M live errors). An empty id plays nothing and creates no Sound.
	CrashSoundId = "",
	CrunchSoundId = "",
	CeilingSize = 220,
	CeilingHeight = 40,
	SpawnInterval = if LOW_POWER then 0.22 else 0.14,
	FallSpeedMin = 50,
	FallSpeedMax = 72,
	SpawnRadiusMin = 0,
	SpawnRadiusMax = 32,
	SpawnHeight = 48,
	Atmosphere = {
		Density = 0.38,
		Haze = 2.4,
		Glare = 0.5,
		Color = Color3.fromRGB(255, 185, 75),
		Decay = Color3.fromRGB(255, 100, 20),
	},
	TintColor = Color3.fromRGB(255, 225, 170),
	Saturation = 0.5,
	Contrast = 0.2,
	Brightness = 0.05,
	BlendSeconds = 1.6,
}

local tacosWeight = 0
local tacos = nil
local tacoList = {}
local nextTacoSpawn = 0
local lastTacoPickupAt = 0

local function tacosActive(): boolean
	local untilTime = tonumber(Workspace:GetAttribute("AdminRainingTacosUntil"))
	return untilTime ~= nil and untilTime > Workspace:GetServerTimeNow()
end

local function getTacoHitRemote(): RemoteEvent?
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	return remotes and remotes:FindFirstChild("AdminTacoHit") :: any
end

-- 2026-09-22: taco sounds come from a few Sounds made once and reused, not a new Sound per
-- taco (a taco lands every 0.14 s). With a bad id that costs one failed load per Sound per
-- session instead of ~7 a second; with a good one the asset loads once. An empty id makes
-- no Sound at all. Positional sounds sit in small invisible parts moved to each crash.
local TACO_SOUND_POOL_SIZE = 3
local tacoSoundPools = {}
local function tacoPooledSound(key: string, soundId: string, positional: boolean): Sound?
	if soundId == "" then
		return nil
	end
	local pool = tacoSoundPools[key]
	if not pool then
		pool = { Next = 0, Sounds = {} }
		tacoSoundPools[key] = pool
	end
	pool.Next = pool.Next % TACO_SOUND_POOL_SIZE + 1
	local sound = pool.Sounds[pool.Next]
	if not sound or not sound.Parent then
		sound = Instance.new("Sound")
		sound.Name = key
		sound.SoundId = soundId
		if positional then
			local holder = Instance.new("Part")
			holder.Name = key .. "Emitter"
			holder.Size = Vector3.new(0.2, 0.2, 0.2)
			holder.Anchored = true
			holder.CanCollide = false
			holder.CanQuery = false
			holder.CanTouch = false
			holder.Transparency = 1
			holder.Parent = Workspace
			sound.Parent = holder
		else
			sound.Parent = SoundService
		end
		pool.Sounds[pool.Next] = sound
	end
	return sound
end

local function tacoGroundCrash(hitPos: Vector3)
	local camera = Workspace.CurrentCamera
	if camera then
		local distance = (camera.CFrame.Position - hitPos).Magnitude
		tacoShake = math.min(0.65, tacoShake + 0.3 * math.clamp(1 - distance / 65, 0, 1))
	end

	local sound = tacoPooledSound("TacoCrashSound", TACOS.CrashSoundId, true)
	if sound then
		(sound.Parent :: BasePart).CFrame = CFrame.new(hitPos + Vector3.new(0, 0.2, 0))
		sound.Volume = 0.35
		sound.RollOffMaxDistance = 85
		sound.RollOffMinDistance = 8
		sound.PlaybackSpeed = math.random(90, 115) / 100
		sound:Play()
	end

	local fx = Instance.new("Part")
	fx.Name = "TacoCrashVFX"
	fx.Size = Vector3.new(0.5, 0.5, 0.5)
	fx.CFrame = CFrame.new(hitPos + Vector3.new(0, 0.2, 0))
	fx.Anchored = true
	fx.CanCollide = false
	fx.CanQuery = false
	fx.CanTouch = false
	fx.Transparency = 1
	fx.Parent = Workspace
	-- A visible shock ring, even if particle textures are unavailable.
	local shock = Instance.new("Part")
	shock.Name = "TacoImpactRing"
	shock.Shape = Enum.PartType.Cylinder
	shock.Size = Vector3.new(0.08, 1, 1)
	shock.CFrame = CFrame.new(hitPos + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	shock.Anchored = true
	shock.CanCollide, shock.CanTouch, shock.CanQuery = false, false, false
	shock.Material = Enum.Material.Neon
	shock.Color = Color3.fromRGB(255, 205, 70)
	shock.Transparency = 0.4
	shock.Parent = fx
	TweenService:Create(shock, TweenInfo.new(0.35), {Size = Vector3.new(0.08, 10, 10), Transparency = 1}):Play()
	local assets = ReplicatedStorage.Shared:FindFirstChild("TacoEventAssets")
	local struck = assets and assets:FindFirstChild("StruckVFX")
	if struck then
		local burst = struck:Clone()
		burst.Parent = fx
		if burst:IsA("BasePart") then
			burst.Anchored = true
			burst.CanCollide, burst.CanTouch, burst.CanQuery = false, false, false
			burst.CFrame = fx.CFrame
		elseif burst:IsA("Model") then burst:PivotTo(fx.CFrame) end
		for _, emitter in burst:GetDescendants() do
			if emitter:IsA("ParticleEmitter") then
				emitter.Enabled = false
				emitter:Emit(math.min(tonumber(emitter:GetAttribute("EmitCount")) or 12, LOW_POWER and 12 or 24))
			end
		end
	end

	local crumbs = Instance.new("ParticleEmitter")
	crumbs.Name = "Crumbs"
	crumbs.Texture = TACOS.Texture
	Flipbooks.Apply(crumbs)
	crumbs.Rate = 0
	crumbs.Speed = NumberRange.new(10, 24)
	crumbs.SpreadAngle = Vector2.new(65, 65)
	crumbs.Rotation = NumberRange.new(-180, 180)
	crumbs.RotSpeed = NumberRange.new(-120, 120)
	crumbs.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.9),
		NumberSequenceKeypoint.new(0.6, 1.3),
		NumberSequenceKeypoint.new(1, 0),
	})
	crumbs.Lifetime = NumberRange.new(0.8, 1.4)
	crumbs.EmissionDirection = Enum.NormalId.Top
	crumbs.Parent = fx

	local bits = Instance.new("ParticleEmitter")
	bits.Name = "Bits"
	bits.Texture = "rbxasset://textures/particles/smoke_main.dds"
	bits.Rate = 0
	bits.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 40)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 220, 60)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 205, 50)),
	})
	bits.Speed = NumberRange.new(8, 18)
	bits.SpreadAngle = Vector2.new(80, 80)
	bits.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(1, 0),
	})
	bits.Lifetime = NumberRange.new(0.5, 1.1)
	bits.EmissionDirection = Enum.NormalId.Top
	bits.Parent = fx

	crumbs:Emit(10)
	bits:Emit(16)
	Debris:AddItem(fx, 2)
end

local function tacoPlayerHit(hitPos: Vector3)
	local now = os.clock()
	if now - lastTacoPickupAt < 0.15 then
		return
	end
	lastTacoPickupAt = now

	local sound = tacoPooledSound("TacoCrunchSound", TACOS.CrunchSoundId, false)
	if sound then
		sound.Volume = 0.9
		sound.PlaybackSpeed = math.random(95, 110) / 100
		sound:Play()
	end

	local _, root = character()
	if root then
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "TacoSpeedGainPopup"
		billboard.Size = UDim2.fromScale(6, 2.5)
		billboard.StudsOffset = Vector3.new(0, 3.5, 0)
		billboard.AlwaysOnTop = true
		billboard.Parent = root

		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.Text = "+75 SPEED! 🌮"
		label.TextColor3 = Color3.fromRGB(255, 225, 60)
		label.TextScaled = true
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(11, 27, 45)
		stroke.Thickness = 3
		stroke.Parent = label
		label.Parent = billboard

		local tween = TweenService:Create(billboard, TweenInfo.new(0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			StudsOffset = Vector3.new(0, 7.5, 0)
		})
		local tweenFade = TweenService:Create(label, TweenInfo.new(0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			TextTransparency = 1
		})
		local tweenStroke = TweenService:Create(stroke, TweenInfo.new(0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Transparency = 1
		})
		tween:Play()
		tweenFade:Play()
		tweenStroke:Play()
		Debris:AddItem(billboard, 0.9)
	end

	local sparkPart = Instance.new("Part")
	sparkPart.Size = Vector3.new(1, 1, 1)
	sparkPart.CFrame = CFrame.new(hitPos)
	sparkPart.Anchored = true
	sparkPart.CanCollide = false
	sparkPart.CanQuery = false
	sparkPart.CanTouch = false
	sparkPart.Transparency = 1
	sparkPart.Parent = Workspace

	local spark = Instance.new("ParticleEmitter")
	spark.Texture = TACOS.Texture
	Flipbooks.Apply(spark)
	spark.Rate = 0
	spark.Speed = NumberRange.new(8, 18)
	spark.SpreadAngle = Vector2.new(180, 180)
	spark.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.4), NumberSequenceKeypoint.new(1, 0) })
	spark.Lifetime = NumberRange.new(0.5, 0.9)
	spark.Parent = sparkPart
	spark:Emit(8)
	Debris:AddItem(sparkPart, 1.5)

	local remote = getTacoHitRemote()
	if remote then
		remote:FireServer()
	end
end

local function spawnFallingTaco(cameraPos: Vector3, playerPos: Vector3?)
	if #tacoList >= (if LOW_POWER then 12 else 22) then return end
	local angle = math.random() * math.pi * 2
	local radius = math.random(TACOS.SpawnRadiusMin, TACOS.SpawnRadiusMax)
	local center = playerPos or cameraPos
	local spawnPos = center + Vector3.new(math.cos(angle) * radius, TACOS.SpawnHeight, math.sin(angle) * radius)

	local part = Instance.new("Part")
	part.Name = "FallingTaco"
	part.Size = Vector3.new(1.2, 1.4, 2.3)
	part.Color = Color3.fromRGB(255, 205, 70)
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.CFrame = CFrame.new(spawnPos) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)

	TacoVisual.Decorate(part, math.random(12, 20) / 10)

	part.Parent = Workspace

	local fallSpeed = math.random(TACOS.FallSpeedMin, TACOS.FallSpeedMax)
	local drift = Vector3.new((math.random() - 0.5) * 6, 0, (math.random() - 0.5) * 6)
	local rotSpeed = Vector3.new(math.random(-3, 3), math.random(-4, 4), math.random(-3, 3))

	table.insert(tacoList, {
		Part = part,
		Pos = spawnPos,
		Speed = fallSpeed,
		Drift = drift,
		Rot = rotSpeed,
		Angles = Vector3.new(math.random() * 6, math.random() * 6, math.random() * 6),
		Born = os.clock(),
	})
end

local function buildTacos()
	local music = Instance.new("Sound")
	music.Name = "AdminRainingTacosMusic"
	music.SoundId = TACOS.MusicId
	music.Volume = 0
	music.Looped = true
	music.Parent = SoundService
	-- Playback comes from the replicated AdminMusic sound.

	local tint = Instance.new("ColorCorrectionEffect")
	tint.Name = "AdminTacosTint"
	tint.Parent = Lighting

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	local ownsAtmosphere = atmosphere == nil
	if ownsAtmosphere then
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Name = "AdminTacosAtmosphere"
		atmosphere.Density = 0
		atmosphere.Haze = 0
		atmosphere.Parent = Lighting
	end

	-- 2D Screen falling tacos
	local layer = Instance.new("Frame")
	layer.Name = "TacoRainGuiLayer"
	layer.Size = UDim2.fromScale(1, 1)
	layer.BackgroundTransparency = 1
	layer.ClipsDescendants = true
	layer.Parent = overlay

	-- Overhead 3D Ceiling Part (Fayple-style authentic yellow taco shower)
	local ceiling = Instance.new("Part")
	ceiling.Name = "AdminTacoCeiling"
	ceiling.Anchored = true
	ceiling.CanCollide = false
	ceiling.CanQuery = false
	ceiling.CanTouch = false
	ceiling.CastShadow = false
	ceiling.Transparency = 1
	ceiling.Size = Vector3.new(TACOS.CeilingSize, 1, TACOS.CeilingSize)

	-- 1. Yellow flakes (the signature Fayple yellow taco shower)
	local yello = Instance.new("ParticleEmitter")
	yello.Name = "YellowFlakes"
	yello.Texture = TACOS.FlakesTexture
	Flipbooks.Apply(yello)
	yello.Color = ColorSequence.new(Color3.fromRGB(255, 205, 40))
	yello.Rate = 0
	yello.Speed = NumberRange.new(55, 85)
	yello.SpreadAngle = Vector2.new(15, 15)
	yello.Rotation = NumberRange.new(-180, 180)
	yello.RotSpeed = NumberRange.new(-60, 60)
	yello.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.2, 0.45),
		NumberSequenceKeypoint.new(0.8, 0.45),
		NumberSequenceKeypoint.new(1, 0),
	})
	yello.Lifetime = NumberRange.new(1.0, 1.8)
	yello.EmissionDirection = Enum.NormalId.Bottom
	yello.LockedToPart = false
	yello.LightInfluence = 0.3
	yello.Parent = ceiling

	-- 2. Falling 2D Taco particles
	local tacoEmitter = Instance.new("ParticleEmitter")
	tacoEmitter.Name = "TacoParticles"
	tacoEmitter.Texture = TACOS.Texture
	Flipbooks.Apply(tacoEmitter)
	tacoEmitter.Color = ColorSequence.new(Color3.new(1, 1, 1))
	tacoEmitter.Rate = 0
	tacoEmitter.Speed = NumberRange.new(50, 85)
	tacoEmitter.SpreadAngle = Vector2.new(15, 15)
	tacoEmitter.Rotation = NumberRange.new(-180, 180)
	tacoEmitter.RotSpeed = NumberRange.new(-40, 40)
	tacoEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.15, 1.3),
		NumberSequenceKeypoint.new(0.85, 1.4),
		NumberSequenceKeypoint.new(1, 0),
	})
	tacoEmitter.Lifetime = NumberRange.new(1.0, 1.8)
	tacoEmitter.EmissionDirection = Enum.NormalId.Bottom
	tacoEmitter.LockedToPart = false
	tacoEmitter.LightInfluence = 0.2
	tacoEmitter.Parent = ceiling

	-- 3. Red sprinkles
	local redEmitter = Instance.new("ParticleEmitter")
	redEmitter.Name = "RedSprinkles"
	redEmitter.Texture = TACOS.FlakesTexture
	Flipbooks.Apply(redEmitter)
	redEmitter.Color = ColorSequence.new(Color3.fromRGB(255, 66, 49))
	redEmitter.Rate = 0
	redEmitter.Speed = NumberRange.new(50, 85)
	redEmitter.SpreadAngle = Vector2.new(15, 15)
	redEmitter.Rotation = NumberRange.new(-180, 180)
	redEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.2, 0.4),
		NumberSequenceKeypoint.new(0.8, 0.4),
		NumberSequenceKeypoint.new(1, 0),
	})
	redEmitter.Lifetime = NumberRange.new(1.0, 1.8)
	redEmitter.EmissionDirection = Enum.NormalId.Bottom
	redEmitter.LockedToPart = false
	redEmitter.LightInfluence = 0.3
	redEmitter.Parent = ceiling

	-- 4. Green sprinkles
	local greenEmitter = Instance.new("ParticleEmitter")
	greenEmitter.Name = "GreenSprinkles"
	greenEmitter.Texture = TACOS.FlakesTexture
	Flipbooks.Apply(greenEmitter)
	greenEmitter.Color = ColorSequence.new(Color3.fromRGB(137, 255, 58))
	greenEmitter.Rate = 0
	greenEmitter.Speed = NumberRange.new(50, 85)
	greenEmitter.SpreadAngle = Vector2.new(15, 15)
	greenEmitter.Rotation = NumberRange.new(-180, 180)
	greenEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.2, 0.4),
		NumberSequenceKeypoint.new(0.8, 0.4),
		NumberSequenceKeypoint.new(1, 0),
	})
	greenEmitter.Lifetime = NumberRange.new(1.0, 1.8)
	greenEmitter.EmissionDirection = Enum.NormalId.Bottom
	greenEmitter.LockedToPart = false
	greenEmitter.LightInfluence = 0.3
	greenEmitter.Parent = ceiling

	ceiling.Parent = Workspace.CurrentCamera

	tacos = {
		Music = music,
		Tint = tint,
		Atmosphere = atmosphere,
		OwnsAtmosphere = ownsAtmosphere,
		GuiLayer = layer,
		Ceiling = ceiling,
		YellowFlakes = yello,
		TacoEmitter = tacoEmitter,
		RedEmitter = redEmitter,
		GreenEmitter = greenEmitter,
		Original = {
			Density = atmosphere.Density,
			Haze = atmosphere.Haze,
			Glare = atmosphere.Glare,
			Color = atmosphere.Color,
			Decay = atmosphere.Decay,
		},
	}
end

local function removeTacos()
	if tacos then
		if tacos.Music then
			tacos.Music:Destroy()
		end
		if tacos.Tint then
			tacos.Tint:Destroy()
		end
		if tacos.OwnsAtmosphere and tacos.Atmosphere then
			tacos.Atmosphere:Destroy()
		elseif tacos.Atmosphere and tacos.Original then
			local orig = tacos.Original
			tacos.Atmosphere.Density = orig.Density
			tacos.Atmosphere.Haze = orig.Haze
			tacos.Atmosphere.Glare = orig.Glare
			tacos.Atmosphere.Color = orig.Color
			tacos.Atmosphere.Decay = orig.Decay
		end
		if tacos.GuiLayer then
			tacos.GuiLayer:Destroy()
		end
		if tacos.Ceiling then
			tacos.Ceiling:Destroy()
		end
		tacos = nil
	end
	for _, item in tacoList do
		if item.Part then
			item.Part:Destroy()
		end
	end
	table.clear(tacoList)

end

local tacoRayParams = RaycastParams.new()
tacoRayParams.FilterType = Enum.RaycastFilterType.Exclude
tacoRayParams.RespectCanCollide = true

local function updateTacos(dt: number)
	local target = if tacosActive() then 1 else 0
	if target == 0 and tacosWeight == 0 then
		return
	end
	if not tacos then
		buildTacos()
	end
	tacosWeight = math.clamp(tacosWeight + (if target > tacosWeight then dt else -dt) / TACOS.BlendSeconds, 0, 1)
	local t = tacosWeight

	local camera = Workspace.CurrentCamera
	local humanoid, root = character()
	local camPos = if camera then camera.CFrame.Position else Vector3.zero
	local playerPos = root and root.Position

	if tacos then
		tacos.Music.Volume = lerp(0, 0.5, t)
		local original = tacos.Original
		tacos.Atmosphere.Density = lerp(original.Density, TACOS.Atmosphere.Density, t)
		tacos.Atmosphere.Haze = lerp(original.Haze, TACOS.Atmosphere.Haze, t)
		tacos.Atmosphere.Glare = lerp(original.Glare, TACOS.Atmosphere.Glare, t)
		tacos.Atmosphere.Color = original.Color:Lerp(TACOS.Atmosphere.Color, t)
		tacos.Atmosphere.Decay = original.Decay:Lerp(TACOS.Atmosphere.Decay, t)
		tacos.Tint.TintColor = Color3.new(1, 1, 1):Lerp(TACOS.TintColor, t)
		tacos.Tint.Saturation = TACOS.Saturation * t
		tacos.Tint.Contrast = TACOS.Contrast * t
		tacos.Tint.Brightness = TACOS.Brightness * t

		-- Position overhead ceiling and set particle rates for yellow taco shower
		if tacos.Ceiling then
			local ceilingY = (if playerPos then playerPos.Y else camPos.Y) + TACOS.CeilingHeight
			tacos.Ceiling.CFrame = CFrame.new(camPos.X, ceilingY, camPos.Z)
			tacos.YellowFlakes.Rate = 50 * t
			tacos.TacoEmitter.Rate = 35 * t
			tacos.RedEmitter.Rate = 30 * t
			tacos.GreenEmitter.Rate = 30 * t
		end


	end

	-- 3D falling tacos spawning
	if target == 1 and t > 0.2 and os.clock() >= nextTacoSpawn then
		nextTacoSpawn = os.clock() + TACOS.SpawnInterval
		spawnFallingTaco(camPos, playerPos)
	end

	local excludeList = {}
	for _, other in Players:GetPlayers() do
		if other.Character then table.insert(excludeList, other.Character) end
	end
	if tacos and tacos.Ceiling then
		table.insert(excludeList, tacos.Ceiling)
	end
	tacoRayParams.FilterDescendantsInstances = excludeList

	local i = 1
	while i <= #tacoList do
		local taco = tacoList[i]
		if not taco.Part or not taco.Part.Parent then
			table.remove(tacoList, i)
		else
			local oldPos = taco.Pos
			local nextPos = oldPos + Vector3.new(taco.Drift.X * dt, -taco.Speed * dt, taco.Drift.Z * dt)

			local hitPlayer = false
			if root then
				local dist = (nextPos - root.Position).Magnitude
				local distHead = (nextPos - (root.Position + Vector3.new(0, 1.5, 0))).Magnitude
				if dist < 4.2 or distHead < 3.8 then
					hitPlayer = true
				end
			end

			if hitPlayer then
				tacoPlayerHit(nextPos)
				taco.Part:Destroy()
				table.remove(tacoList, i)
			else
				local ray = Workspace:Raycast(oldPos, nextPos - oldPos, tacoRayParams)
				local solidHit = false
				if ray and ray.Instance and ray.Instance.CanCollide then
					solidHit = true
				end

				if solidHit and ray then
					tacoGroundCrash(ray.Position)
					taco.Part:Destroy()
					table.remove(tacoList, i)
				elseif os.clock() - taco.Born > 5.5 then
					taco.Part:Destroy()
					table.remove(tacoList, i)
				else
					TacoVisual.EnsureVisible(taco.Part)
			taco.Pos = nextPos
					taco.Angles += taco.Rot * dt
					taco.Part.CFrame = CFrame.new(nextPos) * CFrame.Angles(taco.Angles.X, taco.Angles.Y, taco.Angles.Z)
					i += 1
				end
			end
		end
	end

	if tacosWeight == 0 then
		removeTacos()
	end
end

-- The sky under the events. Snow and the disco both change the light, so both are mixed
-- here from one saved copy of the map's own lighting, which comes back when both are over.
local lightingBase = nil

local function clockToward(from, to, t)
	local shortest = ((to - from + 12) % 24) - 12
	return (from + shortest * t) % 24
end

-- 2026-09-26 (owner): the "Super Sonic vs Dr. Eggman" event's chaos: a fiery orange-red sky while it lasts,
-- a layer mixed in here last (Shared/SuperSonicEventFx.ChaosLighting), from the same saved base, at the weight
-- the event's own phase gives (Fx.ChaosTarget / ChaosStep on the Workspace attributes: it rises while Eggman
-- lifts off, falls after his defeat, and the event's kill switch takes it away). The base comes back exactly
-- when every layer is at 0.
-- The event's modules are looked up without waiting (a place built without the event has none: the layer stays
-- at 0), again every couple of seconds until they are there.
-- 2026-09-26 (owner, v3): toned down (a subtle warm haze: the layer goes only Fx.Chaos.Strength of the way) and
-- ZONE-BASED: it rises only while the local player is in the event's area (the event client's LOCAL player
-- attribute Fx.ChaosZoneAttribute), and blends back out when the player leaves (or is teleported away).
local chaosFx, chaosContract = nil, nil
local chaosLookupAt = 0
local chaosWeight = 0

local function chaosModules(): boolean
	if chaosFx and chaosContract then
		return true
	end
	local now = os.clock()
	if now < chaosLookupAt then
		return false
	end
	chaosLookupAt = now + 2
	pcall(function()
		local shared = ReplicatedStorage:FindFirstChild("Shared")
		local contract = shared and shared:FindFirstChild("SuperSonicEvent")
		local fx = shared and shared:FindFirstChild("SuperSonicEventFx")
		if contract and fx then
			chaosContract = require(contract)
			chaosFx = require(fx)
		end
	end)
	return chaosFx ~= nil and chaosContract ~= nil
end

local function updateChaos(dt: number)
	if not chaosModules() then
		return
	end
	if not chaosContract.IsOn() then
		chaosWeight = 0 -- the event's kill switch: the lobby's own sky at once
		return
	end
	local attributes = chaosContract.Attributes
	local phase = Workspace:GetAttribute(attributes.Phase)
	local start = tonumber(Workspace:GetAttribute(attributes.PhaseStart)) or Workspace:GetServerTimeNow()
	local zoneName = chaosFx.ChaosZoneAttribute
	local inZone = if zoneName then Players.LocalPlayer:GetAttribute(zoneName) == true else nil
	local target = chaosFx.ChaosTarget(phase, Workspace:GetServerTimeNow() - start, true, inZone)
	chaosWeight = chaosFx.ChaosStep(chaosWeight, target, dt)
end

local function blendLighting()
	if snowWeight == 0 and discoWeight == 0 and tacosWeight == 0 and chaosWeight == 0 then
		if lightingBase then
			for property, value in lightingBase do
				(Lighting :: any)[property] = value
			end
			lightingBase = nil
		end
		return
	end
	if not lightingBase then
		lightingBase = {
			Brightness = Lighting.Brightness,
			OutdoorAmbient = Lighting.OutdoorAmbient,
			Ambient = Lighting.Ambient,
			ClockTime = Lighting.ClockTime,
		}
	end
	local base = lightingBase
	local snowDiscoBright = lerp(lerp(base.Brightness, SNOW.Brightness, snowWeight), DISCO.Brightness, discoWeight)
	local mixed = {
		Brightness = lerp(snowDiscoBright, 2.2, tacosWeight),
		OutdoorAmbient = base.OutdoorAmbient:Lerp(SNOW.OutdoorAmbient, snowWeight):Lerp(discoColors.OutdoorAmbient, discoWeight):Lerp(Color3.fromRGB(255, 200, 130), tacosWeight * 0.5),
		Ambient = base.Ambient:Lerp(discoColors.Ambient, discoWeight):Lerp(Color3.fromRGB(255, 220, 160), tacosWeight * 0.45),
		ClockTime = clockToward(base.ClockTime, DISCO.ClockTime, discoWeight),
	}
	if chaosWeight > 0 and chaosFx then
		mixed = chaosFx.ChaosLighting(mixed, chaosWeight, Color3)
	end
	Lighting.Brightness = mixed.Brightness
	Lighting.OutdoorAmbient = mixed.OutdoorAmbient
	Lighting.Ambient = mixed.Ambient
	Lighting.ClockTime = mixed.ClockTime
end

-- Admin treadmills (Workspace.AdminSpawnedTreadmills): rainbow parts in a travelling wave,
-- a rainbow light, and a sign with a moving gradient and the time left.
-- 2026-09-22: each model's rainbow parts are listed once (and again only when its parts
-- change) instead of GetDescendants every frame, and phones recolour 15 times a second:
-- repainting every part each frame cost phones frames while a treadmill was out.
local RAINBOW_LOW_POWER_STEP = 1 / 15
-- Keyed by model and pruned by hand (pruneRainbowParts), not a weak table: Roblox may drop an
-- Instance's Lua wrapper while the instance lives on, which would lose the entry and connect
-- the model's signals again.
local rainbowParts = {}
local nextRainbowRecolour = 0

local function rainbowPartsOf(model)
	local entry = rainbowParts[model]
	if not entry then
		entry = { Dirty = true, Parts = {}, Connections = {} }
		rainbowParts[model] = entry
		local function markDirty()
			entry.Dirty = true
		end
		table.insert(entry.Connections, model.DescendantAdded:Connect(markDirty))
		table.insert(entry.Connections, model.DescendantRemoving:Connect(markDirty))
	end
	if entry.Dirty then
		entry.Dirty = false
		table.clear(entry.Parts)
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") and part.Name ~= "AdminTreadmillVFX" then
				table.insert(entry.Parts, part)
			end
		end
	end
	return entry.Parts
end

-- A treadmill that timed out (or streamed out) leaves the folder: drop its list and signals.
local function pruneRainbowParts(folder)
	for model, entry in rainbowParts do
		if folder == nil or model.Parent ~= folder then
			for _, connection in entry.Connections do
				connection:Disconnect()
			end
			rainbowParts[model] = nil
		end
	end
end

local function updateTreadmills()
	local folder = Workspace:FindFirstChild("AdminSpawnedTreadmills")
	if next(rainbowParts) ~= nil then
		pruneRainbowParts(folder)
	end
	if not folder then
		return
	end
	local now = os.clock()
	local recolour = true
	if LOW_POWER then
		recolour = now >= nextRainbowRecolour
		if recolour then
			nextRainbowRecolour = now + RAINBOW_LOW_POWER_STEP
		end
	end
	for _, model in folder:GetChildren() do
		local isTaco = model:GetAttribute("IsTacoTreadmill") == true
		if model:GetAttribute("AdminRainbow") == true then
			if recolour then
				for _, part in rainbowPartsOf(model) do
					local wave = (part.Position.X + part.Position.Z) * 0.02
					part.Color = Color3.fromHSV((now * 0.25 + wave) % 1, 0.85, 1)
				end
			end
			local vfx = model:FindFirstChild("AdminTreadmillVFX")
			local light = vfx and vfx:FindFirstChild("RainbowLight")
			if light then
				light.Color = Color3.fromHSV(now * 0.25 % 1, 0.7, 1)
			end
		end

		local vfx = model:FindFirstChild("AdminTreadmillVFX")
		local sign = vfx and vfx:FindFirstChild("AdminTreadmillSign")
		if sign then
			local title = sign:FindFirstChild("Title")
			local rainbow = title and title:FindFirstChild("Rainbow")
			if rainbow then
				rainbow.Offset = Vector2.new((now * 0.35) % 2 - 1, 0)
			end
			local subtitle = sign:FindFirstChild("Subtitle")
			local expiresAt = tonumber(model:GetAttribute("AdminExpiresAt"))
			if subtitle and expiresAt then
				local left = math.max(0, math.floor(expiresAt - Workspace:GetServerTimeNow()))
				local speedGain = tonumber(model:GetAttribute("AdminSpeedGain"))
				if isTaco then
					subtitle.Text = string.format(
						"%sx%d Wins | TACO RAIN! %d:%02d",
						if speedGain then "x" .. math.floor(speedGain) .. " Speed + " else "",
						tonumber(model:GetAttribute("AdminMultiplier")) or 1,
						left // 60,
						left % 60
					)
				else
					subtitle.Text = string.format(
						"%sx%d Wins - hop on! %d:%02d",
						if speedGain then "x" .. math.floor(speedGain) .. " Speed + " else "",
						tonumber(model:GetAttribute("AdminMultiplier")) or 1,
						left // 60,
						left % 60
					)
				end
			end
		end
	end
end

-- Telling the server when this player dances (the Disco perk: x100 Speed while dancing):
-- any dance playing on the character, the dance floor's own (AdminDiscoDance) or the
-- Animate script's /e dance, dance2 and dance3 (the same Roblox dances). Sent when it
-- changes and again every couple of seconds while the party is on; the server checks the
-- player really stands still.
local DANCE_IDS = {}
for _, list in DANCES do
	for _, id in list do
		DANCE_IDS[string.match(id, "%d+")] = true
	end
end
local function danceTrackPlaying()
	local humanoid = character()
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return false
	end
	for _, track in animator:GetPlayingAnimationTracks() do
		local animation = track.Animation
		local id = animation and string.match(animation.AnimationId, "%d+")
		local name = string.lower((animation and animation.Name or "") .. " " .. track.Name)
		if (id and DANCE_IDS[id]) or string.find(name, "dance", 1, true) then
			return true
		end
	end
	return false
end
task.spawn(function()
	local DanceReport = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("AdminDiscoDance", 60)
	if not DanceReport then
		return
	end
	do
		local sent, sentAt = false, 0
		while true do
			task.wait(0.25)
			local untilTime = tonumber(Workspace:GetAttribute("AdminDiscoUntil"))
			local on = untilTime ~= nil and Workspace:GetServerTimeNow() < untilTime
			local dancingNow = on and danceTrackPlaying()
			if dancingNow ~= sent or (on and os.clock() - sentAt >= 2) then
				sent, sentAt = dancingNow, os.clock()
				DanceReport:FireServer(dancingNow)
			end
		end
	end
end)

-- World 1's lobby Admin treadmill (Workspace.neworld1.Admin, marked ClientRainbow by
-- AAA_NewWorld1PadCleanup): its rainbow is painted here, on each client (2026-09-24). The
-- server used to tween its ~30 parts forever, 60 new tweens a second whose colour changes
-- every client in the lobby had to receive.
local LOBBY_RAINBOW_STEP = 1 / 30
local lobbyRainbow = { Model = nil, Parts = {}, Dirty = true, NextLookup = 0, NextRecolour = 0, Connections = {} }

local function updateLobbyRainbow()
	local now = os.clock()
	local model = lobbyRainbow.Model
	if not (model and model.Parent) then
		if now < lobbyRainbow.NextLookup then
			return
		end
		lobbyRainbow.NextLookup = now + 2
		local map = Workspace:FindFirstChild("neworld1")
		local found = map and map:FindFirstChild("Admin")
		for _, connection in lobbyRainbow.Connections do
			connection:Disconnect()
		end
		table.clear(lobbyRainbow.Connections)
		lobbyRainbow.Model = nil
		if not (found and found:GetAttribute("ClientRainbow") == true) then
			return
		end
		model = found
		lobbyRainbow.Model = found
		lobbyRainbow.Dirty = true
		local function markDirty()
			lobbyRainbow.Dirty = true
		end
		table.insert(lobbyRainbow.Connections, found.DescendantAdded:Connect(markDirty))
		table.insert(lobbyRainbow.Connections, found.DescendantRemoving:Connect(markDirty))
	end
	if now < lobbyRainbow.NextRecolour then
		return
	end
	lobbyRainbow.NextRecolour = now + (if LOW_POWER then RAINBOW_LOW_POWER_STEP else LOBBY_RAINBOW_STEP)
	if lobbyRainbow.Dirty then
		lobbyRainbow.Dirty = false
		table.clear(lobbyRainbow.Parts)
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				table.insert(lobbyRainbow.Parts, part)
			end
		end
	end
	-- One colour for the whole model, cycling red -> magenta every 4 s like the old tweens.
	local color = Color3.fromHSV(now * 0.25 % 1, 1, 1)
	for _, part in lobbyRainbow.Parts do
		part.Color = color
	end
end

RunService.RenderStepped:Connect(function(dt)
	updateSnow(dt)
	updateDisco(dt)
	updateDance(dt)
	updateDJBooth(dt)
	updateChaos(dt)
	blendLighting()
	updateTreadmills()
	updateLobbyRainbow()
end)

-- Independent connection: another admin effect cannot prevent taco rain from updating.
RunService.Heartbeat:Connect(updateTacos)
local lastTacoCamera, lastTacoOffset = nil, CFrame.identity
RunService:BindToRenderStep("TacoImpactReset", Enum.RenderPriority.Camera.Value - 1, function()
	if lastTacoCamera and lastTacoCamera.Parent then
		lastTacoCamera.CFrame = lastTacoCamera.CFrame * lastTacoOffset:Inverse()
	end
	lastTacoCamera, lastTacoOffset = nil, CFrame.identity
end)
RunService:BindToRenderStep("TacoImpactShake", Enum.RenderPriority.Camera.Value + 1, function(dt)
	local camera, now = Workspace.CurrentCamera, os.clock()
	if camera and tacoShake > 0.001 then
		local offset = CFrame.new(math.noise(now * 30, 1) * tacoShake, math.noise(2, now * 34) * tacoShake, 0)
			* CFrame.Angles(0, 0, math.noise(now * 25, 3) * tacoShake * 0.02)
		camera.CFrame *= offset
		lastTacoCamera, lastTacoOffset = camera, offset
	end
	tacoShake *= math.exp(-9 * dt)
	for _, other in Players:GetPlayers() do
		local model = other.Character
		local taco = model and model:FindFirstChild("TacoHeadAccessory")
		local weld = taco and taco:FindFirstChild("TacoWeld")
		if weld and weld:IsA("Weld") then
			weld.C0 = CFrame.new(0, 2.1 + math.sin(now * 2.4) * 0.18, 0) * CFrame.Angles(0, now * 0.8, 0)
			TacoVisual.EnsureVisible(taco)
		end
	end
end)
