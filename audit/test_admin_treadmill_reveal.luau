-- test_admin_treadmill_reveal.luau
-- The admin treadmill's reveal, played frame by frame in a small Roblox: the rumble and its
-- words, the boom, the card laid out on real screen sizes, GO sending the player through
-- the server, closing, replacing, and the camera left exactly where the camera scripts
-- put it. Then the server half: the reveal goes to everyone and GO lands the player on
-- the belt.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local rb = require("@lune/roblox")

local CLIENT = "src/common/StarterPlayer/StarterPlayerScripts/Admin/AdminTreadmillReveal.client.luau"
local SERVICE = "src/common/ServerScriptService/Admin/AdminAbusePanelService.server.luau"
local client = fs.readFile(CLIENT)
local service = fs.readFile(SERVICE)

local function has(source, needle, message)
	assert(string.find(source, needle, 1, true), message)
end

----------------------------------------------------------------------
-- A small Roblox
----------------------------------------------------------------------
local function signal()
	local s = { listeners = {} }
	function s:Connect(callback)
		table.insert(self.listeners, callback)
		return { Disconnect = function() end }
	end
	function s:Fire(...)
		for _, callback in table.clone(self.listeners) do
			callback(...)
		end
	end
	return s
end

local EVENTS = { Activated = true, MouseEnter = true, MouseLeave = true, OnClientEvent = true, ChildAdded = true, Destroying = true }
local methods = {}
local function instance(class)
	local object = {
		props = {
			ClassName = class,
			Name = class,
			Visible = true,
			ZIndex = 1,
			Rotation = 0,
			Text = "",
			Position = rb.UDim2.new(0, 0, 0, 0),
			Size = rb.UDim2.new(0, 0, 0, 0),
			AnchorPoint = rb.Vector2.new(0, 0),
		},
		children = {},
		events = {},
		attributes = {},
	}
	return setmetatable(object, {
		__index = function(self, key)
			if methods[key] then
				return methods[key]
			end
			if self.props[key] ~= nil then
				return self.props[key]
			end
			if EVENTS[key] then
				self.events[key] = self.events[key] or signal()
				return self.events[key]
			end
			for _, child in self.children do
				if child.Name == key then
					return child
				end
			end
			return nil
		end,
		__newindex = function(self, key, value)
			if key == "Parent" then
				local old = self.props.Parent
				if old then
					local index = table.find(old.children, self)
					if index then
						table.remove(old.children, index)
					end
				end
				if value then
					table.insert(value.children, self)
				end
			end
			self.props[key] = value
		end,
	})
end
function methods:IsA(class)
	return self.ClassName == class or (class == "BasePart" and self.ClassName == "Part")
end
function methods:FindFirstChild(name)
	for _, child in self.children do
		if child.Name == name then
			return child
		end
	end
	return nil
end
function methods:WaitForChild(name)
	return assert(self:FindFirstChild(name), "Missing " .. self.Name .. "." .. name)
end
function methods:FindFirstChildOfClass(class)
	for _, child in self.children do
		if child.ClassName == class then
			return child
		end
	end
	return nil
end
function methods:FindFirstChildWhichIsA(class)
	for _, child in self.children do
		if child:IsA(class) then
			return child
		end
	end
	return nil
end
function methods:GetPropertyChangedSignal(name)
    self.events[name] = self.events[name] or signal()
    return self.events[name]
end
function methods:GetAttributeChangedSignal(name)
    return self:GetPropertyChangedSignal("Attribute_" .. name)
end
function methods:GetAttribute(name)
	return self.attributes[name]
end
function methods:SetAttribute(name, value)
	self.attributes[name] = value
	if self.events["Attribute_" .. name] then self.events["Attribute_" .. name]:Fire() end
end
-- A character moved as a whole: what it was moved to, and how many times.
function methods:PivotTo(cframe)
	self.props.PivotedTo = cframe
	self.props.Pivots = (self.props.Pivots or 0) + 1
end
function methods:GetChildren()
	return table.clone(self.children)
end
function methods:GetDescendants()
	local all = {}
	for _, child in self.children do
		table.insert(all, child)
		for _, descendant in child:GetDescendants() do
			table.insert(all, descendant)
		end
	end
	return all
end
function methods:Destroy()
	self.Parent = nil
	self.props.Destroyed = true
end
function methods:Play()
	self.props.Playing = true
end
function methods:FireServer(...)
	table.insert(self.props.Calls, { ... })
end

local function lookAt(at, target)
	local look = (target - at).Unit
	local right = look:Cross(rb.Vector3.new(0, 1, 0)).Unit
	return rb.CFrame.fromMatrix(at, right, right:Cross(look), -look)
end
local CFrameRoblox = setmetatable({ lookAt = lookAt }, { __index = rb.CFrame })

local function child(parent, class, name)
	local object = instance(class)
	object.Name = name
	object.Parent = parent
	return object
end

local function newWorld(viewport, treadmillAt)
	local world = { clock = 0, serverNow = 50000, delays = {}, binds = {} }
	local services = {}
	for _, name in { "Lighting", "Players", "ReplicatedStorage", "RunService", "SoundService", "StarterGui", "UserInputService", "Workspace" } do
		services[name] = instance(name)
	end
	-- A computer: the reveal's low-power path is for touch-only devices.
	services.UserInputService.TouchEnabled = false
	services.UserInputService.KeyboardEnabled = true
	services.RunService.IsClient = function()
		return true
	end
	world.coreGui = {}
	services.StarterGui.GetCoreGuiEnabled = function(_, kind)
		return world.coreGui[kind] ~= false
	end
	services.StarterGui.SetCoreGuiEnabled = function(_, kind, enabled)
		world.coreGui[kind] = enabled
	end
	local player = child(services.Players, "Player", "Player")
	services.Players.LocalPlayer = player
	services.Players.GetUserThumbnailAsync = function(_, userId)
		return "rbxthumb://" .. userId
	end
	world.playerGui = child(player, "PlayerGui", "PlayerGui")
	local remotes = child(services.ReplicatedStorage, "Folder", "Remotes")
	world.panel = child(remotes, "RemoteEvent", "AdminAbusePanel")
	world.go = child(remotes, "RemoteEvent", "AdminTreadmillGo")
	world.go.Calls = {}
	-- The Shared modules the reveal requires: the real ones, loaded from src.
	local shared = child(services.ReplicatedStorage, "Folder", "Shared")
	for _, name in { "TacoMeteor", "TacoVisual", "TacoFire", "InterfaceHider", "CinematicFit" } do
		child(shared, "ModuleScript", name).SourcePath = "src/common/ReplicatedStorage/Shared/" .. name .. ".luau"
	end
	-- The player's character, mid-fall and sitting, somewhere else.
	world.character = child(services.Workspace, "Model", "Character")
	world.root = child(world.character, "Part", "HumanoidRootPart")
	world.root.CFrame = rb.CFrame.new(12, 8, -40)
	world.root.AssemblyLinearVelocity = rb.Vector3.new(0, -80, 0)
	world.root.AssemblyAngularVelocity = rb.Vector3.new(1, 1, 1)
	world.humanoid = child(world.character, "Humanoid", "Humanoid")
	world.humanoid.Health = 100
	world.humanoid.Sit = true
	player.Character = world.character
	local camera = instance("Camera")
	world.base = rb.CFrame.new(10, 20, 30) * rb.CFrame.Angles(0, math.rad(40), 0)
	camera.CFrame = world.base
	camera.Focus = world.base
	camera.CameraType = rb.Enum.CameraType.Custom
	camera.ViewportSize = viewport
	world.camera = camera
	services.Workspace.CurrentCamera = camera
	services.Workspace.GetServerTimeNow = function()
		return world.serverNow
	end
	local treadmills = child(services.Workspace, "Folder", "AdminSpawnedTreadmills")
	world.treadmill = child(treadmills, "Model", "AdminTreadmill")
	world.parts = {}
	local at = treadmillAt or rb.Vector3.new(30, 0, 60)
	for index, spec in {
		{ rb.Vector3.new(0, 1, 0), rb.Vector3.new(36, 2, 18) },
		{ rb.Vector3.new(-16, 8, 0), rb.Vector3.new(2, 14, 2) },
		{ rb.Vector3.new(0, 16, 0), rb.Vector3.new(4, 1, 4) },
	} do
		local part = child(world.treadmill, "Part", "Part" .. index)
		part.CFrame = rb.CFrame.new(at + spec[1]) * rb.CFrame.Angles(0, math.rad(20), 0)
		part.Size = spec[2]
		part.CanCollide = index ~= 3
		table.insert(world.parts, { Part = part, CFrame = part.CFrame, CanCollide = part.CanCollide })
	end
	world.treadmillAt = at
	-- Where to stand on the belt and which way to face, as spawnTreadmill publishes them.
	world.stand = at + rb.Vector3.new(0, 3.5, 0)
	world.face = rb.Vector3.new(0.6, 0, 0.8)
	world.treadmill:SetAttribute("AdminTreadmillStand", world.stand)
	world.treadmill:SetAttribute("AdminTreadmillFace", world.face)
	services.RunService.BindToRenderStep = function(_, name, priority, callback)
		world.binds[name] = { Priority = priority, Callback = callback }
	end
	services.RunService.UnbindFromRenderStep = function(_, name)
		world.binds[name] = nil
	end
	world.services = services
	world.lighting = services.Lighting
	world.sounds = services.SoundService

	local globals
	local loaded = {}
	globals = {
		-- Services nothing here looks into (TweenService, Debris, ContentProvider) are made when asked for.
		game = { GetService = function(_, name)
			services[name] = services[name] or instance(name)
			return services[name]
		end },
		require = function(module)
			local path = assert(module.SourcePath, "require of " .. tostring(module.Name))
			if loaded[module] == nil then
				local own = table.clone(globals)
				own.script = module
				loaded[module] = luau.load(fs.readFile(path), { environment = own })()
			end
			if module.Name == "TacoMeteor" then world.meteor = loaded[module] end
			return loaded[module]
		end,
		typeof = typeof,
		Instance = { new = instance },
		Enum = rb.Enum,
		UDim = rb.UDim,
		UDim2 = rb.UDim2,
		Vector2 = rb.Vector2,
		Vector3 = rb.Vector3,
		CFrame = CFrameRoblox,
		Color3 = rb.Color3,
		ColorSequence = rb.ColorSequence,
		ColorSequenceKeypoint = rb.ColorSequenceKeypoint,
		NumberSequence = rb.NumberSequence,
		NumberSequenceKeypoint = rb.NumberSequenceKeypoint,
		NumberRange = rb.NumberRange,
		os = { clock = function()
			return world.clock
		end },
		task = {
			spawn = function(callback, ...)
				callback(...)
			end,
			delay = function(seconds, callback)
				table.insert(world.delays, { At = world.clock + seconds, Callback = callback })
			end,
		},
	}
	local env = setmetatable(globals, { __index = _G })
	luau.load(client, { environment = env })()

	-- One rendered frame at time `t`, the way Roblox orders it: steps before the camera,
	-- the camera scripts (which build on the camera's current CFrame), steps after.
	function world.frame(t)
		world.clock = t
		local ordered = {}
		for _, bind in world.binds do
			table.insert(ordered, bind)
		end
		table.sort(ordered, function(a, b)
			return a.Priority < b.Priority
		end)
		local cameraPriority = rb.Enum.RenderPriority.Camera.Value
		for _, bind in ordered do
			if bind.Priority < cameraPriority then
				bind.Callback(1 / 60)
			end
		end
		world.cameraSeenByScripts = world.camera.CFrame
		-- The camera scripts: in charge unless the camera is Scriptable.
		if world.camera.CameraType ~= rb.Enum.CameraType.Scriptable then
			world.camera.CFrame = world.base
		end
		for _, bind in ordered do
			if bind.Priority > cameraPriority then
				bind.Callback(1 / 60)
			end
		end
		for index = #world.delays, 1, -1 do
			if world.delays[index].At <= t then
				table.remove(world.delays, index).Callback()
			end
		end
	end
	function world.run(from, to)
		local t = from
		while t < to do
			world.frame(t)
			t += 1 / 60
		end
		world.frame(to)
	end
	function world.reveal(extra)
		local payload = { kind = "TreadmillReveal", byName = "GekkoH", byUserId = 767108248, multiplier = 5, speedGain = 315, expiresAt = world.serverNow + 600 }
		for key, value in extra or {} do
			payload[key] = value
		end
		-- Every show in these checks is timed from its own start.
		world.clock = 0
		world.panel.OnClientEvent:Fire(payload)
		return world.playerGui:FindFirstChild("AdminTreadmillReveal")
	end
	return world
end

local function near(a, b, epsilon)
	return math.abs(a - b) <= (epsilon or 1e-3)
end
local function sameCFrame(a, b)
	return a == b
end

-- Pixel rectangle of a GUI object inside the screen (UIScale on the card applied).
local function rect(object, view)
	if object.ClassName == "ScreenGui" then
		return { X = 0, Y = 0, W = view.X, H = view.Y }
	end
	local parent = rect(object.Parent, view)
	local scale = object:FindFirstChildOfClass("UIScale")
	local s = if scale and object.Name == "Card" then scale.Scale else 1
	local w = (parent.W * object.Size.X.Scale + object.Size.X.Offset) * s
	local h = (parent.H * object.Size.Y.Scale + object.Size.Y.Offset) * s
	local parentScale = if object.Parent.Name == "Card" then object.Parent:FindFirstChildOfClass("UIScale").Scale else 1
	return {
		X = parent.X + parent.W * object.Position.X.Scale + object.Position.X.Offset * parentScale - w * object.AnchorPoint.X,
		Y = parent.Y + parent.H * object.Position.Y.Scale + object.Position.Y.Offset * parentScale - h * object.AnchorPoint.Y,
		W = if object.Parent.Name == "Card" then w * parentScale else w,
		H = if object.Parent.Name == "Card" then h * parentScale else h,
	}
end
local function inside(inner, outer, label)
	assert(inner.X >= outer.X - 0.5 and inner.Y >= outer.Y - 0.5 and inner.X + inner.W <= outer.X + outer.W + 0.5 and inner.Y + inner.H <= outer.Y + outer.H + 0.5, label)
end
local function apart(a, b, label)
	assert(a.X + a.W <= b.X + 0.5 or b.X + b.W <= a.X + 0.5 or a.Y + a.H <= b.Y + 0.5 or b.Y + b.H <= a.Y + 0.5, label)
end

----------------------------------------------------------------------
-- 1. The quake's shape
----------------------------------------------------------------------
do
	local a = assert(string.find(client, "local TIMELINE = {", 1, true))
	local b = assert(string.find(client, "local WHISPER", a, true))
	local c = assert(string.find(client, "-- How hard the ground shakes", 1, true))
	local d = assert(string.find(client, "local function escape", c, true))
	local quakeStrength, TIMELINE = luau.load(string.sub(client, a, b - 1) .. string.sub(client, c, d - 1) .. "\nreturn quakeStrength, TIMELINE")()
	local previous = -1
	for step = 0, 26 do
		local t = step * 0.1
		if t < TIMELINE.Boom then
			local strength = quakeStrength(t)
			assert(strength > previous, "The rumble keeps building up to the boom")
			previous = strength
		end
	end
	assert(quakeStrength(0.01) < 0.2, "It starts as a faint tremble")
	assert(quakeStrength(TIMELINE.Boom) > quakeStrength(TIMELINE.Boom - 0.01) * 1.5, "The boom hits harder than anything before it")
	assert(quakeStrength(TIMELINE.Boom + 2) < 0.003, "Two seconds after the boom the ground is still")
	print("PASS quake: a faint tremble building up, one big hit at the boom, still two seconds later")
end

----------------------------------------------------------------------
-- 2. The whole show, then GO
----------------------------------------------------------------------
do
	local view = rb.Vector2.new(1280, 720)
	local world = newWorld(view)
	local gui = assert(world.reveal(), "The reveal opens its own screen")
	assert(gui.DisplayOrder >= 150 and gui.IgnoreGuiInset == true and gui.ZIndexBehavior == rb.Enum.ZIndexBehavior.Sibling, "Above the HUD and the announcements, edge to edge")
	assert(world.binds.AdminTreadmillReveal and world.binds.AdminTreadmillRevealUndo, "The quake runs with the camera")
	assert(world.binds.AdminTreadmillRevealUndo.Priority < rb.Enum.RenderPriority.Camera.Value and world.binds.AdminTreadmillReveal.Priority > rb.Enum.RenderPriority.Camera.Value, "...its shake comes off before the camera scripts and goes on after them")
	local rumble
	for _, sound in world.sounds:GetChildren() do
		if sound.Looped then
			rumble = sound
		end
	end
	assert(rumble and rumble.Playing, "The rumble starts")

	-- The camera trembles, and the camera scripts never see the shake.
	local shaken = 0
	local t = 0
	while t < 2.6 do
		world.frame(t)
		assert(sameCFrame(world.cameraSeenByScripts, world.base), "The camera scripts always get the camera back without the shake (t=" .. t .. ")")
		if not sameCFrame(world.camera.CFrame, world.base) then
			shaken += 1
		end
		t += 1 / 60
	end
	assert(shaken > 140, "The screen shakes all through the rumble")

	local whisper, feeling = gui.Whisper, gui.Feeling
	world.frame(0.35)
	world.frame(0.9)
	assert(whisper.TextTransparency < 0.05 and whisper.MaxVisibleGraphemes > 0 and whisper.MaxVisibleGraphemes < #whisper.Text, "\"" .. whisper.Text .. "\" types itself out")
	assert(feeling.TextTransparency > 0.99 and not gui.Card.Visible, "One line at a time, and no card yet")
	assert(gui.BarTop.AnchorPoint.Y == 0 and gui.BarBottom.AnchorPoint.Y == 1, "The black bars have closed in")
	assert(gui.Tint.BackgroundTransparency < 0.9, "The screen darkens")
	local grade = assert(world.lighting:FindFirstChild("AdminTreadmillQuake"), "The world's colour drains")
	assert(grade.Saturation < -0.1, "...greyer as the rumble builds")
	world.frame(1.35)
	assert(whisper.MaxVisibleGraphemes == #"Something powerful is coming...", "The whole whisper")
	world.frame(2.1)
	assert(whisper.TextTransparency > 0.99 and feeling.TextTransparency < 0.05 and feeling.Text == "What is this feeling?", "Then: What is this feeling?")
	assert(feeling.UIScale.Scale > 0.9, "...popped up big")

	-- BOOM.
	world.frame(2.71)
	assert(gui.Card.Visible and gui.Rays.Visible and gui.Shockwave.Visible, "The boom brings the card, the rays and the shockwave")
	assert(gui.Flash.BackgroundTransparency < 0.1, "A white flash")
	local boom, reveal = false, false
	for _, sound in world.sounds:GetChildren() do
		boom = boom or (sound.SoundId == "rbxasset://sounds/collide.wav" and not sound.Looped and sound.Playing)
		reveal = reveal or (sound.SoundId == "rbxassetid://80736831159506" and sound.Playing)
	end
	assert(boom and reveal, "The boom and the reveal sound")
	world.run(2.72, 3.6)
	assert(gui.Flash.BackgroundTransparency > 0.99 and gui.Tint.BackgroundTransparency > 0.99, "The flash and the dark clear")
	assert(gui.BarTop.AnchorPoint.Y == 1 and gui.BarBottom.AnchorPoint.Y == 0, "The bars open again")
	assert(whisper.TextTransparency > 0.99 and feeling.TextTransparency > 0.99, "The words are gone")
	assert(rumble.Volume < 0.01, "The rumble has died down")

	-- The card says who spawned what.
	local card = gui.Card
	assert(string.find(card.Kicker.Text, "GekkoH", 1, true) and string.find(card.Kicker.Text, "spawned an", 1, true), "\"GekkoH spawned an\"")
	assert(card.Title.Text == "ADMIN TREADMILL!" and card.Title:FindFirstChildOfClass("UIGradient"), "ADMIN TREADMILL! in rainbow")
	assert(card.Multiplier.Label.Text == "x315 SPEED + x5 WINS", "Its Speed (Hacker + 5%) and the Wins multiplier")
	assert(card.Timer.Label.Text == "10:00", "The time left")
	assert(card.Go.Label.Text == "GO!", "The GO button")
	assert(card.Avatar.Headshot.Image == "rbxthumb://767108248", "The admin's avatar")
	assert(near(card.UIScale.Scale, 1, 0.01), "Popped in to full size")
	world.serverNow += 61
	world.frame(3.7)
	assert(card.Timer.Label.Text == "8:59", "The time left counts down")

	-- Laid out cleanly.
	local cardRect = rect(card, view)
	inside(cardRect, rect(gui, view), "The card is on screen")
	local parts = { card.Avatar, card.Kicker, card.Title, card.Multiplier, card.Timer, card.Go, card.Close }
	for _, part in parts do
		if part ~= card.Close then
			inside(rect(part, view), cardRect, part.Name .. " is inside the card")
		end
	end
	for i = 1, #parts do
		for j = i + 1, #parts do
			apart(rect(parts[i], view), rect(parts[j], view), parts[i].Name .. " and " .. parts[j].Name .. " do not overlap")
		end
	end

	-- It glides up out of the way.
	world.run(3.7, 6)
	assert(near(card.Position.Y.Scale, 0.25, 0.01), "The card rises to the top of the screen")
	assert(near(gui.Rays.Position.Y.Scale, card.Position.Y.Scale), "...with its rays")

	-- GO.
	card.Go.MouseEnter:Fire()
	world.frame(6.05)
	assert(card.Go.UIScale.Scale > 1.02, "GO grows under the pointer")
	local before = world.root.CFrame
	card.Go.Activated:Fire()
	-- The landing does not wait for the server: the client reads the stand the server published
	-- on the treadmill and sets the player down itself, in the same press.
	local landed = world.root.CFrame
	assert(landed ~= before and (landed.Position - world.stand).Magnitude < 0.01, "GO sets the player down on the belt at once, on this client")
	assert(landed.LookVector:Dot(world.face) > 0.999, "...facing the handles")
	assert(world.humanoid.Sit == false and world.root.AssemblyLinearVelocity.Magnitude == 0 and world.root.AssemblyAngularVelocity.Magnitude == 0, "...standing, and not still falling or spinning")
	assert(world.character.Pivots == 1 and world.character.PivotedTo == landed, "...the whole character with it")
	world.root.CFrame = before
	card.Go.Activated:Fire()
	assert(#world.go.Calls == 1, "GO asks the server once to send the player")
	assert(world.character.Pivots == 1 and world.root.CFrame == before, "...and a second press moves nobody again")
	world.frame(6.1)
	assert(gui.Warp.BackgroundTransparency < 0.5, "A white rush as the player goes")
	world.run(6.1, 7)
	assert(gui.Parent == nil, "Then the reveal is gone")
	assert(next(world.binds) == nil, "...its camera steps unbound")
	assert(grade.Parent == nil and rumble.Parent == nil, "...its colour grade and rumble removed")
	assert(sameCFrame(world.camera.CFrame, world.base), "...and the camera exactly where the camera scripts left it")

	-- The client only lands a living player, and only on a stand the server published.
	local dead = newWorld(view)
	local deadGui = dead.reveal()
	dead.run(0, 3.5)
	dead.humanoid.Health = 0
	local deadAt = dead.root.CFrame
	deadGui.Card.Go.Activated:Fire()
	assert(dead.root.CFrame == deadAt and dead.character.Pivots == nil, "A dead player is not moved on the client")
	assert(#dead.go.Calls == 1, "...the server is still asked, and decides")
	local bare = newWorld(view)
	bare.treadmill:SetAttribute("AdminTreadmillStand", nil)
	local bareGui = bare.reveal()
	bare.run(0, 3.5)
	local bareAt = bare.root.CFrame
	bareGui.Card.Go.Activated:Fire()
	assert(bare.root.CFrame == bareAt and bare.character.Pivots == nil and #bare.go.Calls == 1, "A treadmill with no published stand: the server alone sends the player")
	print("PASS reveal: rumble with its words, a boom, the card with who, x5, time and GO, laid out cleanly; GO lands a living player on the published stand at once and asks the server once")
end

----------------------------------------------------------------------
-- 3. Closing, closing on its own, replacing, a treadmill that is gone, small screens
----------------------------------------------------------------------
do
	local world = newWorld(rb.Vector2.new(1280, 720))
	local gui = world.reveal()
	world.run(0, 3.5)
	gui.Card.Close.Activated:Fire()
	world.run(3.5, 5.5)
	assert(gui.Parent == nil and #world.go.Calls == 0, "The close button closes it without sending anyone")

	gui = world.reveal()
	world.run(0, 3.5)
	world.treadmill.Parent = nil
	world.frame(3.6)
	assert(gui.Card.Go.Label.Text == "GONE", "A treadmill that has gone says so")
	gui.Card.Go.Activated:Fire()
	-- Until 2026-09-19 the GO handler began: if warpAt or closingAt or not boomed or not adminTreadmill() then return end.
	-- The edit that added the client-side landing left only `if warpAt`.
	assert(#world.go.Calls == 0, "...and GO does nothing (the GO handler lost its guard: it fires the server, plays its sound and closes the card for a treadmill that is gone)")
	world.run(3.6, 2.7 + 15 + 1)
	assert(gui.Parent == nil, "Left alone, the card closes by itself")

	gui = world.reveal()
	world.run(0, 1)
	local second = world.reveal({ byName = "Other" })
	assert(gui.Parent == nil and second ~= gui and #world.playerGui:GetChildren() == 1, "A new reveal replaces the one on screen")
	local binds = 0
	for _ in world.binds do
		binds += 1
	end
	assert(binds == 2, "...with one quake running, not two")
	world.run(0, 1)
	assert(sameCFrame(world.cameraSeenByScripts, world.base), "Replacing mid-quake leaves no shake behind")

	-- Markup in a name stays text.
	local third = world.reveal({ byName = '<font size="99">x</font>' })
	world.run(0, 3)
	assert(not string.find(third.Card.Kicker.Text, '<font size="99">', 1, true), "A name cannot inject markup")

	for _, size in { rb.Vector2.new(1920, 1080), rb.Vector2.new(1024, 600), rb.Vector2.new(700, 390) } do
		local small = newWorld(size)
		local screen = small.reveal()
		for _, t in { 3.0, 3.4, 4, 5.2, 6, 10 } do
			small.run(t - 0.2, t)
			local card = rect(screen.Card, size)
			inside(card, rect(screen, size), size.X .. "x" .. size.Y .. ": the card stays on screen (t=" .. t .. ")")
		end
	end
	print("PASS reveal controls: close, closing by itself, a gone treadmill, one reveal at a time, safe names, on screen from phones to 1080p")
end

----------------------------------------------------------------------
-- 4. The treadmill rising out of the ground, and the flight to watch it
----------------------------------------------------------------------
do
	local function sink(world)
		local lowest = math.huge
		for _, entry in world.parts do
			lowest = math.min(lowest, entry.Part.CFrame.Position.Y - entry.CFrame.Position.Y)
		end
		return lowest
	end
	local function inPlace(world)
		for _, entry in world.parts do
			if entry.Part.CFrame ~= entry.CFrame or entry.Part.CanCollide ~= entry.CanCollide then
				return false
			end
		end
		return true
	end
	local function dust(world)
		return world.services.Workspace:FindFirstChild("AdminTreadmillDust")
	end

	-- Far away: the treadmill rises while the camera circles it.
	local world = newWorld(rb.Vector2.new(1280, 720), rb.Vector3.new(5000, 100, 900))
	world.reveal()
	world.frame(0.05)
	for _, entry in world.parts do
		assert(entry.Part.CanCollide == false, "Rising, the treadmill bumps nobody")
	end
	world.run(0.05, 0.3)
	assert(sink(world) < -17, "It starts under the ground, out of sight (" .. sink(world) .. ")")
	local previous = sink(world)
	for _, t in { 0.8, 1.4, 2.0, 2.5 } do
		world.run(t - 0.2, t)
		local now = sink(world)
		assert(now > previous, "It climbs out of the ground (t=" .. t .. ")")
		previous = now
	end
	assert(dust(world) and dust(world).Dust.Rate > 0, "In a cloud of dust")
	world.run(2.5, 2.72)
	assert(inPlace(world), "On the boom it locks exactly into place, solid again")
	assert(dust(world).Dust.Rate == 0, "The dust settles")

	-- ...and the camera of a player far away flew there to watch.
	local fresh = newWorld(rb.Vector2.new(1280, 720), rb.Vector3.new(5000, 100, 900))
	local gui = fresh.reveal()
	fresh.run(0, 0.2)
	assert(fresh.camera.CameraType == rb.Enum.CameraType.Custom, "The player's own camera until the cut")
	assert(gui.Cut.BackgroundTransparency < 0.9, "The screen dips to white for the cut")
	fresh.run(0.2, 1.2)
	assert(not gui.Card.Visible, "The card stays hidden during the flight")
	assert(fresh.camera.CameraType == rb.Enum.CameraType.Scriptable, "Then the camera flies to the treadmill")
	local eye = fresh.camera.CFrame.Position
	local centre = fresh.treadmillAt + rb.Vector3.new(0, 0, 0)
	local base = rb.Vector3.new(centre.X, sink(fresh) + fresh.parts[1].CFrame.Position.Y - 1, centre.Z)
	local flat = (rb.Vector3.new(eye.X, 0, eye.Z) - rb.Vector3.new(centre.X, 0, centre.Z)).Magnitude
	assert(flat > 30 and flat < 50, "...circling it at a good distance (" .. flat .. ")")
	local target = rb.Vector3.new(centre.X, eye.Y, centre.Z)
	assert(fresh.camera.CFrame.LookVector:Dot((target - eye).Unit) > 0.9, "...looking at it")
	local seen = fresh.camera.CFrame.Position
	fresh.run(1.2, 1.4)
	assert((fresh.camera.CFrame.Position - seen).Magnitude > 0.5, "...moving round it")
	fresh.run(1.4, 2.72)
	assert(not gui.Card.Visible and not gui.Rays.Visible and gui.Shockwave.Visible, "The impact does not open the teleport prompt mid-flight")
	gui.Card.Go.Activated:Fire()
	assert(#fresh.go.Calls == 0, "GO is blocked until the card has opened")
	fresh.run(2.72, 2.7 + 1.9 + 0.1)
	assert(fresh.camera.CameraType == rb.Enum.CameraType.Custom, "Once it has landed, the camera comes back to the player")
	fresh.frame(2.7 + 2.05)
	assert(sameCFrame(fresh.cameraSeenByScripts, fresh.base), "...exactly where the player's camera was")
	assert(gui.Cut.BackgroundTransparency < 1, "...behind another white dip")
	fresh.run(2.7 + 2.05, 2.7 + 3)
	assert(gui.Cut.BackgroundTransparency == 1, "Then the view is clear")
	assert(gui.Card.Visible, "The GO card opens after the flight and its white dip")
	fresh.run(2.7 + 3, 9)
	assert(dust(fresh) == nil, "The dust cloud is cleared away")

	-- Near it: no flight, the player watches from where they are.
	local close = newWorld(rb.Vector2.new(1280, 720), rb.Vector3.new(30, 0, 60))
	local closeGui = close.reveal()
	for t = 0, 5, 0.1 do
		close.frame(t)
		assert(close.camera.CameraType == rb.Enum.CameraType.Custom and closeGui.Cut.BackgroundTransparency == 1, "A player near it keeps their own camera (t=" .. t .. ")")
	end
	assert(inPlace(close), "...and sees it rise into place")

	-- Cut short mid-rise (a new reveal): everything goes back where it belongs.
	local cutShort = newWorld(rb.Vector2.new(1280, 720), rb.Vector3.new(5000, 100, 900))
	cutShort.reveal()
	cutShort.run(0, 1.5)
	assert(not inPlace(cutShort) and cutShort.camera.CameraType == rb.Enum.CameraType.Scriptable, "Mid-rise and mid-flight")
	cutShort.reveal({ byName = "Other" })
	assert(cutShort.camera.CameraType == rb.Enum.CameraType.Custom, "Replaced: the camera is the player's again at once")
	cutShort.run(0, 3)
	assert(inPlace(cutShort), "...and the treadmill ends exactly in place")
	print("PASS rising: the treadmill climbs out of the ground in dust and locks in on the boom; far players fly there and back, near ones watch")
end

----------------------------------------------------------------------
-- 5. The server half
----------------------------------------------------------------------
do
	local requestStart = assert(string.find(service, "Panel.OnServerEvent:Connect", 1, true))
	local requests = string.sub(service, requestStart)
	local handler = assert(string.match(requests, 'elseif action == "Treadmill" then(.-)elseif action == "ClearTreadmills"'), "Treadmill request handler")
	local spawnAt = assert(string.find(handler, "spawnTreadmill(admin, multiplier, minutes, treadmillType)", 1, true))
	local fireAt = assert(string.find(handler, 'Panel:FireAllClients({\n\t\t\t\tkind = "TreadmillReveal"', 1, true), "The reveal goes to every player")
	assert(fireAt > spawnAt and string.find(handler, "if ok then", 1, true), "...once the treadmill is really there")
	for _, field in { "byName = admin.DisplayName", "byUserId = admin.UserId", "multiplier = multiplier", "expiresAt = os.time() + minutes * 60" } do
		has(handler, field, "The reveal carries " .. field)
	end
	has(service, 'local TreadmillGo = remote("AdminTreadmillGo")', "GO has its own remote, open to every player")
	has(handler, "player:RequestStreamAroundAsync(stand, 3)", "The treadmill's corner of the lobby is loaded for every player")
	has(handler, 'runEvent("Disco", math.min(minutes * 60, 900), true, { UserId = admin.UserId, Name = admin.DisplayName })', "A Disco Party can come with it, the admin as its DJ")
	local controller = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/Admin/AdminAbusePanelController.client.luau")
	-- 2026-09-20: the user had the "with a Disco Party" choice taken off the treadmill card. The
	-- server still honours withDisco; the panel no longer sends it. Disco Party is its own event.
	assert(not string.find(controller, "withDisco", 1, true), "The treadmill card sends no Disco Party choice")
	has(service, 'if RateLimiter.Allow(player, "AdminTreadmillGo", 1) then', "GO is rate limited")

	local a = assert(string.find(service, "local function goToTreadmill", 1, true))
	local b = assert(string.find(service, "TreadmillGo.OnServerEvent", a, true))
	local stand = rb.Vector3.new(280, 37471, -1811)
	local face = rb.Vector3.new(0.6, 0, 0.8)
	local treadmill = { GetAttribute = function(_, name)
		return if name == "AdminTreadmillStand" then stand elseif name == "AdminTreadmillFace" then face else nil
	end }
	local folder = { FindFirstChild = function(_, name)
		return if name == "AdminTreadmill" then treadmill else nil
	end, FindFirstChildWhichIsA = function()
		return treadmill
	end }
	local log = {}
	local character = { Parent = true, PivotTo = function(_, cframe)
		table.insert(log, { "Pivot", cframe })
	end }
	local root = { AssemblyLinearVelocity = rb.Vector3.new(0, -80, 0), AssemblyAngularVelocity = rb.Vector3.new(1, 1, 1) }
	local humanoid = { Health = 100, Sit = true }
	local alive = true
	local env = setmetatable({
		Workspace = { FindFirstChild = function(_, name)
			return if name == "AdminSpawnedTreadmills" then folder else nil
		end },
		TREADMILL_FOLDER = "AdminSpawnedTreadmills",
		aliveRoot = function()
			if alive then
				return character, root, humanoid
			end
			return nil, nil, nil
		end,
		Vector3 = rb.Vector3,
		-- The ground is asked for without holding up the landing (task.spawn); here it runs in line.
		task = { spawn = function(callback, ...)
			callback(...)
		end },
		-- Lune's CFrame.lookAt only gets some directions right; this one works like Roblox's.
		CFrame = setmetatable({ lookAt = function(at, target)
			local look = (target - at).Unit
			local right = look:Cross(rb.Vector3.new(0, 1, 0)).Unit
			return rb.CFrame.fromMatrix(at, right, right:Cross(look), -look)
		end }, { __index = rb.CFrame }),
		typeof = typeof,
	}, { __index = _G })
	local goToTreadmill = luau.load(string.sub(service, a, b - 1) .. "\nreturn goToTreadmill", { environment = env })()
	local player = { RequestStreamAroundAsync = function(_, position)
		table.insert(log, { "Stream", position })
	end }
	assert(goToTreadmill(player) == true, "GO works for a living player")
	assert(log[1][1] == "Stream" and log[1][2] == stand, "The ground there is asked for")
	local pivot = log[2][2]
	assert(log[2][1] == "Pivot" and (pivot.Position - stand).Magnitude < 1e-4 and pivot.LookVector:Dot(face) > 0.999, "The player lands on the belt, facing the handles")
	assert(root.CFrame == pivot, "...root and character together")
	assert(humanoid.Sit == false and root.AssemblyLinearVelocity.Magnitude == 0 and root.AssemblyAngularVelocity.Magnitude == 0, "Standing, and not still falling or spinning")
	alive = false
	assert(goToTreadmill(player) == false, "Nobody is sent while dead")
	alive = true
	treadmill = nil
	assert(goToTreadmill(player) == false, "Nobody is sent to a treadmill that is gone")
	print("PASS server: the reveal goes to everyone once the treadmill exists, and GO lands the player on the belt, facing its handles")
end


-- Taco timing uses the real clock, Pose and Shot; particle construction is tested separately.
do
    local world = newWorld(rb.Vector2.new(1280, 720))
    world.meteor.BuildAura = function() return { Update = function() end, Burst = function() end, Destroy = function() end } end
    world.meteor.Impact = function() end
    local hud = child(world.playerGui, "ScreenGui", "Mainhud")
    hud.Enabled = true
    local gui = world.reveal({ isTaco = true })
    world.run(0, 1)
    assert(not hud.Enabled, "Taco flight hides the HUD")
    assert(world.services.Players.LocalPlayer:GetAttribute("AdminTreadmillCinematicActive") == true)
    world.run(1, 5.2)
    assert(not gui.Card.Visible and gui.Shockwave.Visible, "The taco impact still does not open GO")
    world.run(5.2, 7.2)
    assert(hud.Enabled and not gui.Card.Visible, "Camera restored, but GO waits for the white dip")
    world.run(7.2, 7.6)
    assert(gui.Card.Visible, "GO opens after the complete taco flight")
    world.run(7.6, 24)
    assert(gui.Parent == nil and hud.Enabled, "Natural completion restores the HUD and destroys the reveal")
    local first = world.reveal({ isTaco = true })
    world.run(0, 1)
    local second = world.reveal({ isTaco = true })
    assert(first.Parent == nil and hud.Enabled, "Replacing a reveal releases the first hide")
    world.run(0, 1)
    second.Destroying:Fire()
    assert(hud.Enabled and next(world.binds) == nil, "External destruction restores HUD and camera")
    local player = world.services.Players.LocalPlayer
    player:SetAttribute("WorldPortalCinematicActive", true)
    assert(world.reveal() == nil, "A treadmill reveal waits while the portal owns the camera")
    player:SetAttribute("WorldPortalCinematicActive", false)
    assert(world.playerGui:FindFirstChild("AdminTreadmillReveal"), "The waiting reveal starts after the portal finishes")
    print("PASS taco and portal: GO after flight, HUD restoration on end/replacement/destruction, camera ownership")
end

print("ALL ADMIN TREADMILL REVEAL CHECKS PASSED")
