-- audit/test_fable_taco_meteor.luau  (2026-09-20)
-- The Taco Treadmill's arrival (Shared/TacoMeteor + Admin/AdminTreadmillReveal), from the real
-- module:
--   1. the fall: starts high and to the side, keeps speeding up, lands upright exactly in place;
--   2. the camera: never under the floor, never inside the taco, no jump cuts, looks up at the
--      meteor first and at the treadmill after the hit, sane field of view, given back at the end;
--   3. (was the crater of rocks: the user had it removed on 2026-09-20);
--   4. the instances build: V40 fire on the meteor while it falls; the landing is only its impact
--      effects (flash, shock rings, explosion, taco splashes, dust): no rocks, no chunks;
--   5. the reveal: a longer fall on a stretched clock, Roblox-owned sounds, interface hidden and restored;
--   6. sprite-sheet particles get their grid (the "broken" taco flakes); the Taco Treadmill is a
--      plain treadmill with one client-floated taco and few taco particles: nothing hung on
--      it and nothing left burning on it.
-- Pass "places" to check the three places carry these sources.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local rb = require("@lune/roblox")
local serde = require("@lune/serde")
local process = require("@lune/process")

local MODULE = "src/common/ReplicatedStorage/Shared/TacoMeteor.luau"
local REVEAL = "src/common/StarterPlayer/StarterPlayerScripts/Admin/AdminTreadmillReveal.client.luau"
local Vector3, CFrame = rb.Vector3, rb.CFrame
local passed = 0
local function pass(message)
	passed += 1
	print("PASS " .. message)
end

for _, path in { MODULE, REVEAL } do
	local ok, problem = pcall(luau.compile, fs.readFile(path))
	assert(ok, path .. ": " .. tostring(problem))
end

-- Lune's CFrame.lookAt is wrong for most directions; give the module a correct one.
local function lookAt(from, to)
	local look = (to - from).Unit
	local right = look:Cross(Vector3.new(0, 1, 0))
	right = if right.Magnitude < 1e-4 then Vector3.new(1, 0, 0) else right.Unit
	local up = right:Cross(look)
	return CFrame.fromMatrix(from, right, up, -look)
end
local tweens, debris = 0, 0
local tweenGoals, delays = {}, {}
local fakeWorkspace = rb.Instance.new("Folder")
local services = {
	TweenService = { Create = function(_, instance, info, goals)
		tweens += 1
		table.insert(tweenGoals, { instance = instance, info = info, goals = goals })
		return { Play = function() end }
	end },
	Debris = { AddItem = function() debris += 1 end },
	Workspace = fakeWorkspace,
	Players = { GetPlayers = function() return {} end },
}
local seedState = 12345
local env = {
	Vector3 = Vector3, Vector2 = rb.Vector2, Color3 = rb.Color3, ColorSequence = rb.ColorSequence,
	ColorSequenceKeypoint = rb.ColorSequenceKeypoint, NumberSequence = rb.NumberSequence,
	NumberSequenceKeypoint = rb.NumberSequenceKeypoint, NumberRange = rb.NumberRange, Enum = rb.Enum,
	Instance = rb.Instance, TweenInfo = { new = function(seconds) return { seconds = seconds } end },
	RaycastParams = { new = function() return {} end },
	Random = { new = function() return { NextNumber = function() seedState = (seedState * 1103515245 + 12345) % 2147483648; return seedState / 2147483648 end } end },
	CFrame = setmetatable({ lookAt = lookAt }, { __index = CFrame }),
	game = { GetService = function(_, name) return services[name] end },
	task = { delay = function(seconds, fn) table.insert(delays, { seconds = seconds, fn = fn }) end }, math = math, table = table, pcall = pcall, tonumber = tonumber, ipairs = ipairs, pairs = pairs,
}
local Meteor = luau.load(fs.readFile(MODULE), { debugName = "TacoMeteor", environment = env })()

local BOOM = 2.7
local heart = Vector3.new(278.5, 37480, -1623)
local floorY = heart.Y - 8

-- 1. The fall.
do
	assert(Meteor.Progress(0, BOOM) == 0 and Meteor.Progress(Meteor.Fall.StartAt, BOOM) == 0 and Meteor.Progress(BOOM, BOOM) == 1)
	local previous, previousStep = -1, 0
	for step = 0, 270 do
		local t = step / 100
		local progress = Meteor.Progress(t, BOOM)
		assert(progress >= previous, "the meteor goes back up")
		if t > Meteor.Fall.StartAt + 0.02 and t < BOOM then
			assert(progress - previous >= previousStep - 1e-9, "the meteor must keep speeding up")
			previousStep = progress - previous
		end
		previous = progress
		local at = Meteor.Position(t, BOOM, heart)
		assert(at.Y >= heart.Y - 1e-3, "the meteor dips under its landing place")
	end
	local start = Meteor.Position(0, BOOM, heart)
	assert(math.abs(start.Y - heart.Y - Meteor.Fall.Height) < 0.5, "it must start Height above")
	assert(((start - heart) * Vector3.new(1, 0, 1)).Magnitude > 100, "it must come in on a slant")
	-- Rigid all the way, upright and exactly in place at the end.
	local a, b = heart + Vector3.new(19, -4, 13), heart + Vector3.new(-12, 6, -9)
	for _, t in { 0, 0.5, 1.2, 2.0, 2.69 } do
		local pose = Meteor.Pose(t, BOOM, heart)
		assert(math.abs(((pose * a) - (pose * b)).Magnitude - (a - b).Magnitude) < 0.01, "the treadmill stretches on the way down")
	end
	local landed = Meteor.Pose(BOOM, BOOM, heart)
	assert((landed * a - a).Magnitude < 1e-4 and landed.UpVector.Y > 0.9999, "it must land upright, exactly in place")
	assert((Meteor.Pose(BOOM + 3, BOOM, heart) * a - a).Magnitude < 1e-4, "after the hit it stays put")
	local nearEnd = Meteor.Pose(BOOM - 0.05, BOOM, heart)
	assert(nearEnd.UpVector.Y > 0.9, "it is still tumbling hard just before the hit")
	pass("fall: 760 studs up on a slant, always speeding up, rigid, lands upright exactly in place")
end

-- 2. The camera.
do
	local cutIn, cutOut = 0.3, BOOM + 1.9
	for _, yaw in { 0, 1.3, -2.4 } do
		local lastEye, lastFov
		local maxStep, maxFovStep = 0, 0
		for frame = 0, math.floor((cutOut - cutIn) * 60) do
			local t = cutIn + frame / 60
			local eye, focus, fov = Meteor.Shot(t, BOOM, heart, floorY, yaw)
			assert(eye.Y >= floorY + 3, "the camera goes into the floor")
			assert(fov >= 50 and fov <= 100, "field of view out of range: " .. fov)
			local meteor = Meteor.Position(t, BOOM, heart)
			if t < BOOM then
				assert((focus - meteor).Magnitude < 1e-3, "before the hit the camera must follow the meteor")
				assert((eye - meteor).Magnitude > 30, "the camera is inside the taco")
			else
				assert(((focus - heart) * Vector3.new(1, 0, 1)).Magnitude < 1e-3, "after the hit the camera must look at the treadmill")
				assert((eye - heart).Magnitude > 25, "the camera is inside the treadmill")
			end
			if lastEye then
				maxStep = math.max(maxStep, (eye - lastEye).Magnitude)
				maxFovStep = math.max(maxFovStep, math.abs(fov - lastFov))
			end
			lastEye, lastFov = eye, fov
		end
		assert(maxStep < 3.5, ("jump cut: the camera moves %.1f studs in one frame"):format(maxStep))
		assert(maxFovStep < 4, ("the lens snaps %.1f degrees in one frame"):format(maxFovStep))
		local firstEye, firstFocus = Meteor.Shot(cutIn, BOOM, heart, floorY, yaw)
		assert(firstFocus.Y - firstEye.Y > 300, "the first shot must look up at the sky")
		local awayDirection = Vector3.new(math.cos(yaw), 0, math.sin(yaw))
		assert(((firstEye - heart) * Vector3.new(1, 0, 1)).Unit:Dot(awayDirection) > 0.99, "the first shot must be from the player's side")
	end
	local _, _, impactFov = Meteor.Shot(BOOM + 0.2, BOOM, heart, floorY, 0)
	local _, _, orbitFov = Meteor.Shot(BOOM + 1.8, BOOM, heart, floorY, 0)
	assert(impactFov > orbitFov + 10, "the hit must punch the lens wide")
	pass("camera: above the floor, outside the taco, no jump cuts (3 sides x 258 frames), looks up first, wide lens on the hit")
end

-- 4. The instances: fire from the V40 assets on the way down; a landing of impact effects only.
do
	local tacoVisual = {
		Decorate = function(root, scale)
			local mesh = rb.Instance.new("MeshPart"); mesh.Name = "OriginalTaco"; mesh.Parent = root
			root:SetAttribute("TestScale", scale)
			return root
		end,
		EnsureVisible = function() end,
	}
	local fireAssets = rb.deserializeModel(fs.readFile("src/ui/TacoMeteorAssets.rbxm"))[1]
	assert(fireAssets.Name == "TacoMeteorAssets" and fireAssets:FindFirstChild("Wrap") and fireAssets:FindFirstChild("Boom")
		and fireAssets:FindFirstChild("Jet") and fireAssets:FindFirstChild("Trail"), "the captured fire assets are incomplete")
	for _, item in fireAssets:GetDescendants() do
		assert(not item:IsA("LuaSourceContainer") and not item:IsA("Sound"), "the fire assets must carry no script and no sound")
	end
	local size = Vector3.new(38, 16, 27)
	local centre = Vector3.new(heart.X, floorY, heart.Z)
	-- A floor of two materials with a gap: green grass on one side, grey slate on the other, nothing beyond x + 25.
	local grass, slate = rb.Color3.fromRGB(60, 200, 70), rb.Color3.fromRGB(120, 120, 130)
	Meteor._raycast = function(origin)
		if origin.X > centre.X + 25 then
			return nil
		end
		local onGrass = origin.X < centre.X
		return { Position = Vector3.new(origin.X, floorY + (if onGrass then 0 else 2), origin.Z), Material = if onGrass then rb.Enum.Material.Grass else rb.Enum.Material.Slate,
			Instance = { IsA = function() return false end, Color = if onGrass then grass else slate, MaterialVariant = "" } }
	end
	for _, lowPower in { false, true } do
		for _, child in fakeWorkspace:GetChildren() do child:Destroy() end
		local crashSplash = rb.deserializeModel(fs.readFile("src/ui/TacoEventAssets.rbxm"))[1].StruckVFX
		local tacoFireModule = luau.load(fs.readFile("src/common/ReplicatedStorage/Shared/TacoFire.luau"), { environment = {
			Enum = rb.Enum, NumberRange = rb.NumberRange, NumberSequence = rb.NumberSequence, NumberSequenceKeypoint = rb.NumberSequenceKeypoint,
			Vector2 = rb.Vector2, Vector3 = Vector3, math = math, table = table } })()
		local aura = Meteor.BuildAura(heart, size, lowPower, tacoVisual, fireAssets, { Fire = tacoFireModule, Struck = crashSplash })
		local folder = assert(fakeWorkspace:FindFirstChild("TacoMeteor_Local"))
		local tacos = 0
		for _, item in folder:GetChildren() do
			if item.Name == "AuraTaco" then tacos += 1 end
		end
		assert(tacos == (if lowPower then 6 else 12) and folder:FindFirstChild("GiantTaco") and folder.Core:FindFirstChild("Fire"))
		assert(folder.Core:FindFirstChild("FireSpecs") and folder.Core:FindFirstChild("Embers [20]"), "the meteor must also burn in the tacos' own crash fire")
		local wrap, jet = assert(folder:FindFirstChild("Wrap"), "no fireball round the meteor"), assert(folder:FindFirstChild("Jet"), "no flame jet")
		assert(folder.Core:FindFirstChild("Trail") and folder.Core.Trail.Enabled, "no trail")
		local burning, riding, source = 0, 0, {}
		for _, emitter in fireAssets.Wrap:GetDescendants() do
			if emitter:IsA("ParticleEmitter") then source[emitter.Name] = tostring(emitter.FlipbookLayout) end
		end
		for _, emitter in wrap:GetDescendants() do
			if emitter:IsA("ParticleEmitter") then
				assert(tostring(emitter.FlipbookLayout) == source[emitter.Name], emitter.Name .. " lost its sprite grid")
				if emitter.Enabled then burning += 1 end
				if emitter.Enabled and emitter.LockedToPart then riding += 1 end
			end
		end
		assert(burning >= 10 and riding >= 3 and riding < burning, ("fireball: %d burning, %d riding with the meteor"):format(burning, riding))
		for _, t in { 0.4, 1.5, 2.6 } do
			aura.Update(t, Meteor.Pose(t, BOOM, heart))
		end
		-- 20% smaller than the first one (1.5 treadmills wide), as the user asked.
		assert(Meteor.TacoWidth == 1.2, "the giant taco must be 1.2 treadmills wide")
		assert(math.abs(folder.GiantTaco:GetAttribute("TestScale") - math.max(size.X, size.Z) * 1.2 / 2.5) < 1e-6, "the giant taco is not drawn at TacoWidth")
		local shellAt = folder.GiantTaco.CFrame.Position
		assert((shellAt - Meteor.Position(2.6, BOOM, heart)).Magnitude < 0.5, "the giant taco is not around the treadmill")
		assert((wrap.CFrame.Position - shellAt).Magnitude < 0.5, "the fire is not on the meteor")
		-- The jet points back up the way it came: further up the sky than the meteor.
		assert(jet.CFrame.Position.Y > shellAt.Y and jet.CFrame.UpVector.Y > 0.5, "the flame jet does not trail behind the meteor")
		for _, item in folder:GetChildren() do
			if item.Name == "AuraTaco" then
				local away = (item.CFrame.Position - shellAt).Magnitude
				assert(away > 20 and away < 60, "the ring of tacos is not around the meteor: " .. away)
			end
		end
		aura.Burst()
		for _, emitter in folder:GetDescendants() do
			if emitter:IsA("ParticleEmitter") then assert(not emitter.Enabled or emitter.Rate == 0, emitter.Name .. " keeps burning after the hit") end
		end

		local stone = rb.Instance.new("Part")
		stone.Name = "StruckVFX"
		rb.Instance.new("ParticleEmitter").Parent = stone
		local tacoAssets = rb.Instance.new("Folder")
		stone.Parent = tacoAssets
		table.clear(delays)
		table.clear(tweenGoals)
		local impact = Meteor.Impact(centre, size, lowPower, tacoAssets, fireAssets)
		assert(impact.Name == "TacoMeteorImpact_Local")
		local rings = 0
		for _, item in impact:GetDescendants() do
			if item:IsA("BasePart") then
				assert(item.CanCollide == false and item.CanTouch == false and item.CanQuery == false, item.Name .. " could block the way to the treadmill")
				-- No crater any more: the user had the rocks and the chunks in the air removed.
				assert(item.Name ~= "CraterRock" and item.Name ~= "CraterChunk", "the landing still raises " .. item.Name)
				if item.Name == "ShockRing" then rings += 1 end
			end
		end
		assert(impact:FindFirstChild("Boom") and impact:FindFirstChild("Flash") and rings == 2, "the explosion, the flash and the two shock rings are the impact")
		assert(impact.TacoMeteorSplash:FindFirstChild("Dust"), "the dust is missing")
		-- The taco splash: once in the middle, then round the landing one after another. Nothing later than that.
		local rims = 0
		local splashesBefore = #impact.TacoMeteorSplash:GetChildren()
		for _, item in table.clone(delays) do
			assert(item.seconds < 1, "nothing of the landing may be scheduled for later (that was the rocks sinking)")
			rims += 1
			item.fn()
		end
		assert(rims == (if lowPower then 4 else 8) and #impact.TacoMeteorSplash:GetChildren() == splashesBefore + rims, "the taco splash must go off all round the landing")
		assert(Meteor.ImpactSeconds >= 3 and Meteor.ImpactSeconds <= 10, "the impact's effects clean themselves up soon after")
	end
	Meteor._raycast = nil
	assert(Meteor.Crater == nil and Meteor.CraterRocks == nil, "the crater code is gone with the rocks")
	pass("instances: V40 fireball + jet + trail on the meteor while it falls; the landing is flash, two shock rings, explosion, taco splash in the middle and round it, dust: no rocks, no chunks, nothing left standing or burning; nothing collides")
end

-- 5. The reveal: a longer fall, its own sounds, the interface away and back.
do
	local reveal = fs.readFile(REVEAL)
	for _, needed in { "TacoMeteor.BuildAura", "TacoMeteor.Pose(t, TIMELINE.Boom, stage.Heart)", "TacoMeteor.Shot(", "TacoMeteor.Impact, stage.Centre, stage.Size, LOW_POWER, Shared:FindFirstChild(\"TacoEventAssets\"),", "stage.Aura.Burst",
		'Shared:FindFirstChild("TacoMeteorAssets")', "play(SOUNDS.TacoImpact)", "rbxassetid://3149249837" } do
		assert(reveal:find(needed, 1, true), "the reveal lost " .. needed)
	end
	-- The rocket whoosh of the fall is gone (the user: "pusiste sonido de un rocket").
	for _, gone in { "TacoFall", "FallSound", "12222095" } do
		assert(not reveal:find(gone, 1, true), "the rocket sound is still in the reveal: " .. gone)
	end
	assert(reveal:find("if isTaco then\n\t\t\tstage.Heart", 1, true), "the meteor must be the taco treadmill's alone")
	local _, restores = reveal:gsub("camera%.FieldOfView = cinema%.FieldOfView", "")
	assert(restores == 2, "the lens must be given back at the cut out and when the reveal stops")
	assert(select(2, reveal:gsub("os%.clock%(%) %- started", "")) == 1, "every moment of the reveal must read the stretched clock")
	-- The stretched clock, run for real.
	local clock = 0
	local nowSource = assert(reveal:match("(\tlocal function now%(%).-\n\tend\n)"), "now() not found")
	local function makeNow(isTaco)
		return luau.load("local started = 0\n" .. nowSource .. "\nreturn now", { environment = {
			os = { clock = function() return clock end }, isTaco = isTaco, TIMELINE = { Boom = BOOM }, TacoMeteor = Meteor } })()
	end
	local tacoNow, plainNow = makeNow(true), makeNow(false)
	local boomReal = BOOM * Meteor.FallStretch
	clock = boomReal
	assert(math.abs(tacoNow() - BOOM) < 1e-9, "the boom must land at TIMELINE.Boom on the stretched clock")
	clock = boomReal + 3
	assert(math.abs(tacoNow() - (BOOM + 3)) < 1e-9 and plainNow() == clock, "after the hit the clock runs at the normal rate; the admin treadmill is untouched")
	local fallSeconds = (BOOM - Meteor.Fall.StartAt) * Meteor.FallStretch
	assert(fallSeconds >= 4 and fallSeconds <= 6, ("the fall lasts %.1f s"):format(fallSeconds))
	-- The interface: hidden when the camera leaves, back when it returns and whenever the reveal stops.
	assert(reveal:find("hideInterface()", 1, true) and select(2, reveal:gsub("showInterface%(%)", "")) >= 3, "the interface must come back at the cut out AND on stop")
	-- The hiding lives in Shared/InterfaceHider now (shared with the world-portal flight): the reveal
	-- hands it its own ScreenGui to keep, the helper also never hides it by name, and it only
	-- covers what was showing.
	local hider = fs.readFile("src/common/ReplicatedStorage/Shared/InterfaceHider.luau")
	assert(reveal:find("InterfaceHider.Hide(INTERFACE_OWNER, { gui })", 1, true) and hider:find("AdminTreadmillReveal = true", 1, true)
		and hider:find("gui.Enabled and not kept(gui)", 1, true), "only what was showing may be hidden, and never the reveal itself")
	assert(hider:find("GetCoreGuiEnabled", 1, true), "core GUI must go back to what it was, not simply on")
	assert(reveal:find("\tlocal function showInterface()", 1, true) < reveal:find("\tlocal function stop()", 1, true),
		"showInterface must be declared above stop(), or stop() calls a nil global")
	assert(reveal:find("pcall(stage.Aura.Destroy)", 1, true), "a replaced reveal must take its meteor with it")
	assert(not fs.readFile(MODULE):find("FireServer", 1, true))
	pass(("reveal: fall %.1f s (was 2.3), no rocket whoosh on the fall, a Roblox-owned impact sound, interface hidden for the flight and restored, lens and camera always given back"):format(fallSeconds))
end

-- 6. Sprite sheets, and the plain Taco Treadmill: one floating taco, a little taco VFX, no fire left on it.
do
	local Flipbooks = luau.load(fs.readFile("src/common/ReplicatedStorage/Shared/ParticleFlipbooks.luau"), { environment = {
		Enum = rb.Enum, NumberRange = rb.NumberRange, pcall = pcall, type = type, string = string } })()
	local flakes = rb.Instance.new("ParticleEmitter")
	flakes.Texture = "rbxassetid://13802408466"
	assert(tostring(flakes.FlipbookLayout):find("None"), "a new emitter starts with no grid: that is the bug")
	assert(Flipbooks.Apply(flakes) and tostring(flakes.FlipbookLayout):find("Grid4x4") and tostring(flakes.FlipbookMode):find("OneShot"))
	local taco = rb.Instance.new("ParticleEmitter")
	taco.Texture = "rbxassetid://84855954319870"
	assert(not Flipbooks.Apply(taco) and tostring(taco.FlipbookLayout):find("None"), "a single image must be left alone")
	assert(Flipbooks.Apply(rb.Instance.new("Part")) == false and Flipbooks.Apply(nil) == false)
	local effects = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/Admin/AdminAbuseEffects.client.luau")
	for _, name in { "yello", "redEmitter", "greenEmitter", "blob", "embers", "fireSpecs", "shockwave" } do
		assert(effects:find("Flipbooks.Apply(" .. name .. ")", 1, true), name .. " still draws its whole sprite sheet")
	end

	-- The fire: steady flames out of the splash the raining tacos crash in.
	local struck = rb.deserializeModel(fs.readFile("src/ui/TacoEventAssets.rbxm"))[1].StruckVFX
	local TacoFire = luau.load(fs.readFile("src/common/ReplicatedStorage/Shared/TacoFire.luau"), { environment = {
		Enum = rb.Enum, NumberRange = rb.NumberRange, NumberSequence = rb.NumberSequence, NumberSequenceKeypoint = rb.NumberSequenceKeypoint,
		Vector2 = rb.Vector2, Vector3 = Vector3, math = math, table = table } })()
	local holder = rb.Instance.new("Attachment")
	local flames = TacoFire.Flames(struck, holder, { Scale = 0.9, Rate = 0.7 })
	assert(#flames >= 4 and #flames <= TacoFire.MaxPerFlame, "a flame is " .. #flames .. " emitters")
	local names = {}
	for _, flame in flames do
		local first = flame.Color.Keypoints[1].Value
		assert(first.R >= first.G, flame.Name .. " is green: that is lettuce, not fire")
		assert(flame.Enabled and flame.Rate > 0 and flame.Rate <= 8 and flame.Parent == holder and flame.Acceleration.Y > 0, flame.Name .. " is not a steady rising flame")
		assert(TacoFire.Recipe[flame.Name], flame.Name .. " is one of the splash's flashes, not its fire")
		local original
		for _, source in struck:GetDescendants() do
			if source.Name == flame.Name then original = source break end
		end
		assert(tostring(flame.FlipbookLayout) == tostring(original.FlipbookLayout), flame.Name .. " lost its sprite grid")
		names[flame.Name] = true
	end
	assert(names.Fire and names.FireSpecs and names["Embers [20]"], "the flame must use the splash's Fire, FireSpecs and Embers")
	assert(#TacoFire.Flames(nil, holder) == 0, "no splash asset, no flames, no error")

	local server = fs.readFile("src/common/ServerScriptService/Admin/AdminAbusePanelService.server.luau")
	for _, gone in { "decorateTacoTreadmill", "TacoGarland", "TacoHeadboard", "TacoCorner", "TacoColourFlakes", "tacoConn = RunService.Heartbeat" } do
		assert(not server:find(gone, 1, true), "the Taco Treadmill must be a plain treadmill: " .. gone .. " is still there")
	end
	assert(server:find('AddTag(tacoPart, "TacoTreadmillFloat")', 1, true) and server:find('SetAttribute("FloatBase", tacoPart.CFrame)', 1, true),
		"the one floating taco must be handed to the clients")
	local dress = server:sub(assert(server:find("local function dressAdminTreadmill", 1, true)), assert(server:find('sign.Name = "AdminTreadmillSign"', 1, true)))
	assert(not dress:find("tacoPart.CFrame =", 1, true) or select(2, dress:gsub("tacoPart%.CFrame =", "")) == 1, "the server must place the floating taco once and never move it")
	assert(tonumber(server:match("tacoRain%.Rate = (%d+)")) <= 6 and tonumber(server:match("yellowFlakes%.Rate = (%d+)")) <= 8, "taco particles must stay few")
	assert(server:find("Flipbooks).Apply(yellowFlakes)", 1, true) or server:find("ParticleFlipbooks).Apply(yellowFlakes)", 1, true))

	-- Nothing is left burning on the treadmill (the user: only the impact effects, no fire kept).
	for _, gone in { "burnTacoTreadmill", "TacoFire" } do
		assert(not server:find(gone, 1, true), "the Taco Treadmill still keeps fire: " .. gone)
	end

	local float = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/Admin/TacoTreadmillFloat.client.luau")
	for _, needed in { '"TacoTreadmillFloat"', "GetServerTimeNow", "BindToRenderStep", "FloatBase", ":Lerp(target", "TacoMeteor_Local" } do
		assert(float:find(needed, 1, true), "the floating taco script lost " .. needed)
	end
	assert(not float:find("FireServer", 1, true) and not float:find("task.wait", 1, true))
	pass("taco flakes and firework sheets get their 4x4 grid; Taco Treadmill is plain: no hung tacos, one taco floated by the clients every frame, "
		.. "few taco particles, no fire left on it (TacoFire still burns round the meteor while it falls)")
end

-- 7. The admin panel's treadmill card has no disco choice any more.
do
	local PANEL = "src/common/StarterPlayer/StarterPlayerScripts/Admin/AdminAbusePanelController.client.luau"
	local panel = fs.readFile(PANEL)
	assert(select(1, pcall(luau.compile, panel)), "the admin panel does not compile")
	local a = assert(panel:find("function TABS.Treadmills(page)", 1, true))
	local b = assert(panel:find("function TABS.Music(page)", a, true))
	local card = panel:sub(a, b - 1)
	for _, gone in { "No disco", "With a Disco Party", "withDisco", "disco()" } do
		assert(not card:find(gone, 1, true), "the treadmill card still has: " .. gone)
	end
	for _, needed in { '"Rainbow Treadmill"', "Taco Treadmill", '"Remove All"', 'treadmillType = "Rainbow"', 'treadmillType = "Taco"', 'action = "ClearTreadmills"' } do
		assert(card:find(needed, 1, true), "the treadmill card lost " .. needed)
	end
	assert(panel:find('"Disco Party"', 1, true), "the Disco Party stays as its own event")
	local service = fs.readFile("src/common/ServerScriptService/Admin/AdminAbusePanelService.server.luau")
	assert(service:find("payload.withDisco == true", 1, true), "the server must read a missing disco flag as no disco")
	pass("admin panel: the treadmill card spawns Rainbow / Taco / Remove All with no disco choice; Disco Party is still its own event")
end

if process.args[1] == "places" then
	local manifest = serde.decode("json", fs.readFile("src/manifest.json"))
	for _, place in { { "World1", "World1Update3New.rbxl" }, { "World2", "World2Update3new.rbxl" }, { "World3", "World3Update3New.rbxl" } } do
		local dm = rb.deserializePlace(fs.readFile(place[2]))
		for _, source in { MODULE, REVEAL, "src/common/ReplicatedStorage/Shared/ParticleFlipbooks.luau",
			"src/common/StarterPlayer/StarterPlayerScripts/Admin/AdminAbuseEffects.client.luau",
			"src/common/ServerScriptService/Admin/AdminAbusePanelService.server.luau",
			"src/common/ReplicatedStorage/Shared/TacoFire.luau",
			"src/common/StarterPlayer/StarterPlayerScripts/Admin/TacoTreadmillFloat.client.luau",
			"src/common/StarterPlayer/StarterPlayerScripts/Admin/AdminAbusePanelController.client.luau" } do
			local row
			for _, candidate in manifest.worlds[place[1]].scripts do
				if candidate.source == source then row = candidate end
			end
			assert(row, place[1] .. ": no manifest row for " .. source)
			local node = dm
			for _, name in row.segments do
				node = assert(node:FindFirstChild(name), place[1] .. " is missing " .. table.concat(row.segments, "."))
			end
			assert(node.Source == fs.readFile(source), place[1] .. ": " .. node.Name .. " differs from src")
		end
		assert(dm:GetService("ReplicatedStorage").Shared:FindFirstChild("TacoEventAssets"), place[1] .. ": TacoEventAssets missing")
		local fire = assert(dm:GetService("ReplicatedStorage").Shared:FindFirstChild("TacoMeteorAssets"), place[1] .. ": TacoMeteorAssets missing")
		assert(fire:FindFirstChild("Wrap") and fire:FindFirstChild("Boom") and fire:FindFirstChild("Jet") and fire:FindFirstChild("Trail"), place[1] .. ": fire assets incomplete")
	end
	pass("the three places carry TacoMeteor, the reveal, the sprite-sheet fix, the decorated treadmill and the V40 fire assets")
end
print(("ALL PASSED (%d groups)"):format(passed))
