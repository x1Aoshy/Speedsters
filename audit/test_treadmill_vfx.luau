-- audit/test_treadmill_vfx.luau
-- The 2026-09-22 treadmill VFX pass, run on the REAL sources:
--   1. TreadmillVfxController.client.luau is loaded whole (luau.load) with stubbed Players (the
--      local player + 6 others with attributes and characters whose roots are Lune Parts),
--      UserInputService (phone / desktop), a Heartbeat we fire, Workspace (Raycast counter,
--      CurrentCamera), task.delay/cancel and the REAL ReplicatedStorage of World1Update3New.rbxl
--      (the V40 DragonGingeriniFloorpart template), and again with no template.
--      Proves: exactly ONE emitter per runner, one theme per treadmill name (legacy names, Taco,
--      unknown), theme colours only, a treadmill switch replaces the emitter, phone LOD (others
--      only within 20 studs, at most 3, 50% rate; the local player always full), desktop LOD
--      (160 studs, 60%), zero raycasts for other players, fade then destroy, no Instances made
--      for effects already running, and the lobby emitter count against the old source.
--   2. TreadmillTraining.server.luau: the real sampling-loop body publishes CurrentTreadmillName
--      only on change, beside IsOnTreadmill, first zone wins, "Taco" for the taco treadmill, ""
--      when off; the touch path only fills it when empty.
--
--   lune run audit/test_treadmill_vfx.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local rb = require("@lune/roblox")
local process = require("@lune/process")
local serde = require("@lune/serde")
local PlaceFiles = require("./place_files")

local CLIENT = "src/common/StarterPlayer/StarterPlayerScripts/Gameplay/TreadmillVfxController.client.luau"
local OLD_CLIENT = "output/FableTreadmillVfx_20260922/backup_src/common/StarterPlayer/StarterPlayerScripts/Gameplay/TreadmillVfxController.client.luau"
local SERVER = "src/common/ServerScriptService/Progression/TreadmillTraining.server.luau"

local function read(path)
	return (string.gsub(fs.readFile(path), "\r\n", "\n"))
end
local function pass(text)
	print("PASS " .. text)
end
local function between(source, first, last, label)
	local a = assert(string.find(source, first, 1, true), label .. ": start moved")
	local b = assert(string.find(source, last, a + #first, true), label .. ": end moved")
	return string.sub(source, a, b - 1)
end
local function signal()
	local callbacks = {}
	return {
		Connect = function(_, callback)
			table.insert(callbacks, callback)
			return { Disconnect = function() end }
		end,
		Fire = function(_, ...)
			for _, callback in table.clone(callbacks) do
				callback(...)
			end
		end,
	}
end
local function near(a, b)
	return math.abs(a - b) < 1e-3
end
local function sameColor(a, b)
	return near(a.R, b.R) and near(a.G, b.G) and near(a.B, b.B)
end

local RB_TYPES = {
	Color3 = rb.Color3,
	ColorSequence = rb.ColorSequence,
	ColorSequenceKeypoint = rb.ColorSequenceKeypoint,
	NumberSequence = rb.NumberSequence,
	NumberSequenceKeypoint = rb.NumberSequenceKeypoint,
	NumberRange = rb.NumberRange,
	Vector3 = rb.Vector3,
	Vector2 = rb.Vector2,
	CFrame = rb.CFrame,
	Enum = rb.Enum,
}

local clientSource = read(CLIENT)
assert(clientSource:sub(1, 9) == "--!strict", "client keeps --!strict")

----------------------------------------------------------------------------------------------
-- 1a. ThemeFor and THEMES from the marked block.
----------------------------------------------------------------------------------------------
local themeChunk = between(clientSource, "-- TreadmillVfxThemes begin", "-- TreadmillVfxThemes end", "themes")
local ThemeFor, THEMES = luau.load(themeChunk .. "\nreturn ThemeFor, THEMES", {
	environment = setmetatable(table.clone(RB_TYPES), { __index = _G }),
})()

local EXPECTED_THEME = {
	Basic = "Basic", Starter = "Basic", Treadmill1_basic = "Basic", basic = "Basic",
	Golden = "Golden", Gold = "Golden", Treadmill2_fast = "Golden", GOLDEN = "Golden",
	Candy = "Candy", Treadmill4_hyperspeed = "Candy",
	Diamond = "Diamond", Treadmill3_superfast = "Diamond",
	Needoh = "Ruby", Admin = "Ruby", TreadmillAdmin = "Ruby",
	Hacker = "Matrix", Admin3000 = "Matrix", Treadmill5_insanespeed = "Matrix", admin3000 = "Matrix",
	Taco = "Taco", ["Taco Treadmill"] = "Taco",
	[""] = "Basic", SomethingNew = "Basic",
}
for name, theme in EXPECTED_THEME do
	assert(ThemeFor(name) == theme, ("ThemeFor(%q) = %s, want %s"):format(name, tostring(ThemeFor(name)), theme))
end
assert(ThemeFor(nil) == "Basic")
local themeCount = 0
for name, def in THEMES do
	themeCount += 1
	assert(def.Source == "lines1" or def.Source == "floorfire1", name .. " builds from lines1 or floorfire1")
	assert(def.LightEmission > 0, name .. " glows (never the template's darkening -1)")
end
assert(themeCount == 7, "seven themes")
assert(THEMES.Diamond.Source == "floorfire1" and THEMES.Ruby.Source == "floorfire1", "Diamond/Ruby are rings")
assert(THEMES.Basic.Rate <= 8, "Basic is subtle")
pass(("ThemeFor maps all %d treadmill names (lobby, legacy, Taco, unknown) to 7 one-emitter themes"):format(#(function()
	local t = {}
	for k in EXPECTED_THEME do
		table.insert(t, k)
	end
	return t
end)()))

----------------------------------------------------------------------------------------------
-- 1b. The whole client script in a stubbed engine.
----------------------------------------------------------------------------------------------
local place = rb.deserializePlace(fs.readFile(PlaceFiles.World1))
local realRS = place:GetService("ReplicatedStorage")
local template = realRS.VfxTemplates.Treadmill.DragonGingeriniFloorpart
local templateEmitterCount = 0
local TEMPLATE_COLORS = {}
for _, child in template:GetChildren() do
	if child:IsA("ParticleEmitter") then
		templateEmitterCount += 1
		table.insert(TEMPLATE_COLORS, child.Color.Keypoints[1].Value)
	end
end
assert(templateEmitterCount == 10, "the real template still has 10 emitters")

local function makeWorld(opts)
	local world = { raycasts = 0, delays = {}, clock = 0, instancesMade = 0 }
	local heartbeat = signal()
	local playerAdded, playerRemoving = signal(), signal()
	local workspaceFolder = rb.Instance.new("Folder")

	local function makePlayer(name, position)
		local attrs = {}
		local player = { Name = name, CharacterRemoving = signal() }
		function player:GetAttribute(key)
			return attrs[key]
		end
		function player:SetAttribute(key, value)
			attrs[key] = value
		end
		local root = rb.Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.CFrame = rb.CFrame.new(position)
		local humanoid = { Health = 100, HipHeight = 2, MoveDirection = rb.Vector3.new(0, 0, 0) }
		local character = { Name = name, Parent = workspaceFolder }
		function character:FindFirstChild(child)
			return if child == "HumanoidRootPart" then root else nil
		end
		function character:FindFirstChildOfClass(class)
			return if class == "Humanoid" then humanoid else nil
		end
		player.Character = character
		player.Root = root
		player.Humanoid = humanoid
		return player
	end

	local localPlayer = makePlayer("Local", rb.Vector3.new(0, 3, 0))
	local others = {}
	for i, distance in opts.distances do
		others[i] = makePlayer("Other" .. i, rb.Vector3.new(distance, 3, 0))
	end
	local all = { localPlayer }
	for _, p in others do
		table.insert(all, p)
	end

	local services = {
		Players = {
			LocalPlayer = localPlayer,
			GetPlayers = function()
				return table.clone(all)
			end,
			PlayerAdded = playerAdded,
			PlayerRemoving = playerRemoving,
		},
		ReplicatedStorage = if opts.template then realRS else rb.Instance.new("Folder"),
		RunService = { Heartbeat = heartbeat },
		UserInputService = { TouchEnabled = opts.phone, KeyboardEnabled = not opts.phone },
		Workspace = {
			CurrentCamera = { CFrame = rb.CFrame.new(0, 10, 10) },
			Raycast = function(_, origin)
				world.raycasts += 1
				return if world.rayHit then { Instance = world.rayHit } else nil
			end,
		},
	}
	local env = setmetatable(table.clone(RB_TYPES), { __index = _G })
	env.game = { GetService = function(_, name)
		return assert(services[name], "unexpected service " .. name)
	end }
	env.Instance = { new = function(class)
		world.instancesMade += 1
		return rb.Instance.new(class)
	end }
	env.RaycastParams = { new = function()
		world.raycastParamsMade = (world.raycastParamsMade or 0) + 1
		return {}
	end }
	env.os = { clock = function()
		return world.clock
	end }
	env.task = {
		delay = function(t, fn)
			local handle = { Time = t, Fn = fn }
			table.insert(world.delays, handle)
			return handle
		end,
		cancel = function(handle)
			handle.Cancelled = true
		end,
	}
	luau.load(clientSource, { debugName = "TreadmillVfxController", environment = env })()

	world.localPlayer = localPlayer
	world.others = others
	world.all = all
	world.playerRemoving = playerRemoving
	function world.step(n)
		for _ = 1, n or 1 do
			world.clock += 0.2
			heartbeat:Fire(1 / 60)
		end
	end
	function world.flushDelays()
		local list = world.delays
		world.delays = {}
		for _, handle in list do
			if not handle.Cancelled then
				handle.Fn()
			end
		end
	end
	function world.emitters(player)
		local found = {}
		for _, d in player.Root:GetDescendants() do
			if d:IsA("ParticleEmitter") then
				table.insert(found, d)
			end
		end
		return found
	end
	function world.attachments(player)
		local found = {}
		for _, d in player.Root:GetChildren() do
			if d:IsA("Attachment") then
				table.insert(found, d)
			end
		end
		return found
	end
	function world.totalEmitters(enabledOnly)
		local n = 0
		for _, p in all do
			for _, e in world.emitters(p) do
				if not enabledOnly or e.Enabled then
					n += 1
				end
			end
		end
		return n
	end
	function world.train(player, name)
		player:SetAttribute("IsOnTreadmill", true)
		player:SetAttribute("CurrentTreadmillName", name)
	end
	return world
end

local RETIRED = "TreadmillVfx_Retired"
local function checkOne(world, player, theme, rate, label)
	local ems = {}
	for _, e in world.emitters(player) do
		if e.Name == RETIRED then
			assert(not e.Enabled, label .. ": a retired emitter still emits")
		else
			table.insert(ems, e)
		end
	end
	assert(#ems == 1, ("%s: %d emitters, want exactly 1"):format(label, #ems))
	local e = ems[1]
	assert(e.Enabled, label .. ": enabled")
	assert(e.Name == "TreadmillVfx_" .. theme, ("%s: %s, want theme %s"):format(label, e.Name, theme))
	local def = THEMES[theme]
	assert(sameColor(e.Color.Keypoints[1].Value, def.From), label .. ": theme From colour")
	assert(sameColor(e.Color.Keypoints[#e.Color.Keypoints].Value, def.To), label .. ": theme To colour")
	for _, c in TEMPLATE_COLORS do
		assert(not sameColor(e.Color.Keypoints[1].Value, c), label .. ": a template colour survived")
	end
	assert(e.LightEmission > 0, label .. ": positive LightEmission")
	assert(near(e.Rate, rate), ("%s: rate %s, want %s"):format(label, tostring(e.Rate), tostring(rate)))
	assert(#world.attachments(player) == 1, label .. ": one attachment")
	return e
end

-- Lobby scenario: local on Basic + 6 others, four of them within 20 studs.
local DISTANCES = { 5, 10, 15, 18, 50, 200 }
local OTHER_NAMES = { "Golden", "Candy", "Diamond", "Needoh", "Hacker", "Admin3000" }

-- Desktop, real template.
do
	local w = makeWorld({ phone = false, template = true, distances = DISTANCES })
	w.train(w.localPlayer, "Basic")
	for i, p in w.others do
		w.train(p, OTHER_NAMES[i])
	end
	w.step(3)
	checkOne(w, w.localPlayer, "Basic", THEMES.Basic.Rate, "desktop local")
	for i = 1, 5 do
		local theme = ThemeFor(OTHER_NAMES[i])
		checkOne(w, w.others[i], theme, THEMES[theme].Rate * 0.6, "desktop other " .. i)
	end
	assert(#w.emitters(w.others[6]) == 0, "desktop: runner at 200 studs has no effect")
	assert(w.raycasts == 0, "desktop: zero raycasts (attributes only)")
	-- Nothing is rebuilt for effects already running.
	local before = w.instancesMade
	local firstEmitter = w.emitters(w.localPlayer)[1]
	w.step(20)
	assert(w.instancesMade == before, "no Instance creation for running effects")
	assert(w.emitters(w.localPlayer)[1] == firstEmitter, "the running emitter is kept")
	assert(w.raycastParamsMade == 1, "one module-level RaycastParams")
	pass("desktop: 1 themed emitter per runner, others within 160 at 60%, none at 200, 0 raycasts, no per-scan Instances")
end

-- Phone, real template: the lobby count against the old source.
local phoneLobbyEmitters
do
	local w = makeWorld({ phone = true, template = true, distances = DISTANCES })
	w.train(w.localPlayer, "Basic")
	for i, p in w.others do
		w.train(p, OTHER_NAMES[i])
	end
	w.step(3)
	checkOne(w, w.localPlayer, "Basic", THEMES.Basic.Rate, "phone local")
	for i = 1, 3 do
		local theme = ThemeFor(OTHER_NAMES[i])
		checkOne(w, w.others[i], theme, THEMES[theme].Rate * 0.5, "phone other " .. i)
	end
	for i = 4, 6 do
		assert(#w.emitters(w.others[i]) == 0, "phone: other " .. i .. " has no effect (4th nearest or beyond 20)")
	end
	assert(w.raycasts == 0, "phone: zero raycasts")
	phoneLobbyEmitters = w.totalEmitters()

	-- The nearest one leaves: the 4th nearest (18 studs) takes the slot; the leaver fades.
	w.others[1]:SetAttribute("IsOnTreadmill", false)
	w.others[1]:SetAttribute("CurrentTreadmillName", "")
	w.step()
	local fading = w.emitters(w.others[1])
	assert(#fading == 1 and not fading[1].Enabled, "stop disables first (fade)")
	assert(#w.attachments(w.others[1]) == 1, "attachment kept while fading")
	assert(#w.delays == 1 and near(w.delays[1].Time, 0.85), "fade of 0.85 s scheduled")
	checkOne(w, w.others[4], "Ruby", THEMES.Ruby.Rate * 0.5, "phone other 4 promoted")
	w.flushDelays()
	assert(#w.attachments(w.others[1]) == 0 and #w.emitters(w.others[1]) == 0, "fade then destroy")

	-- A runner walking out past 20 studs loses the effect; the local player at 200 keeps it full.
	w.others[2].Root.CFrame = rb.CFrame.new(30, 3, 0)
	w.localPlayer.Root.CFrame = rb.CFrame.new(-200, 3, 0)
	w.step()
	w.flushDelays()
	checkOne(w, w.localPlayer, "Basic", THEMES.Basic.Rate, "phone local far away")
	for i = 1, 6 do
		assert(#w.emitters(w.others[i]) == 0, "phone: others are measured from the local character")
	end
	pass("phone: others only within 20 studs, 3 nearest, 50% rate; local always full; fade 0.85 s then destroy")
end

-- The old source against the same lobby: every runner cloned all 10 template emitters.
do
	local oldSource = read(OLD_CLIENT)
	local clones = 0
	local fakeTemplateChildren = {}
	for _, child in template:GetChildren() do
		local isEmitter = child:IsA("ParticleEmitter")
		table.insert(fakeTemplateChildren, {
			IsA = function(_, class)
				return isEmitter and class == "ParticleEmitter"
			end,
			Clone = function()
				clones += 1
				return {}
			end,
		})
	end
	local fakeTpl = { GetChildren = function()
		return fakeTemplateChildren
	end }
	local treadmillFolder = { DragonGingeriniFloorpart = fakeTpl }
	function treadmillFolder:FindFirstChild(n)
		return self[n]
	end
	local vfx = { Treadmill = treadmillFolder }
	function vfx:FindFirstChild(n)
		return self[n]
	end
	local heartbeat = signal()
	local players = {}
	local function fakePlayer(x)
		local root = { Position = rb.Vector3.new(x, 3, 0) }
		local hum = { Health = 100, HipHeight = 2, MoveDirection = rb.Vector3.new(0, 0, 0) }
		local char = { Parent = true }
		function char:FindFirstChild()
			return root
		end
		function char:FindFirstChildOfClass()
			return hum
		end
		return {
			Character = char,
			CharacterRemoving = signal(),
			GetAttribute = function(_, k)
				return if k == "IsOnTreadmill" then true else nil
			end,
		}
	end
	table.insert(players, fakePlayer(0))
	for _, d in DISTANCES do
		if d <= 160 then
			table.insert(players, fakePlayer(d))
		else
			table.insert(players, fakePlayer(20)) -- the old code: all 6 in a normal lobby are close
		end
	end
	local services = {
		Debris = {},
		Players = { LocalPlayer = players[1], GetPlayers = function()
			return players
		end, PlayerAdded = signal(), PlayerRemoving = signal() },
		ReplicatedStorage = { FindFirstChild = function(_, n)
			return if n == "VfxTemplates" then vfx else nil
		end },
		RunService = { Heartbeat = heartbeat },
		Workspace = { CurrentCamera = { CFrame = rb.CFrame.new(0, 10, 10) }, Raycast = function() end },
	}
	local env = setmetatable(table.clone(RB_TYPES), { __index = _G })
	env.game = { GetService = function(_, n)
		return services[n]
	end }
	env.Instance = { new = function()
		return {}
	end }
	env.RaycastParams = { new = function()
		return {}
	end }
	local clock = 0
	env.os = { clock = function()
		return clock
	end }
	env.task = { delay = function() end, cancel = function() end }
	luau.load(oldSource, { environment = env })()
	clock += 1
	heartbeat:Fire()
	assert(clones == 70, "old source clones 70 emitters for 7 runners, got " .. clones)
	local reduction = (1 - phoneLobbyEmitters / clones) * 100
	print(("LOBBY (local + 6 others training, 4 of them within 20 studs): old %d emitters -> phone %d emitters (%.0f%% fewer)"):format(clones, phoneLobbyEmitters, reduction))
	assert(phoneLobbyEmitters == 4 and reduction >= 90, "phone lobby load cut by at least 90%")
	pass("phone lobby emitters cut from 70 to 4")
end

-- Every treadmill name on the local player and on an other; switching replaces, never stacks.
do
	local w = makeWorld({ phone = false, template = true, distances = { 8 } })
	local other = w.others[1]
	w.train(w.localPlayer, "Basic")
	w.train(other, "Basic")
	w.step()
	local localAttachment = w.attachments(w.localPlayer)[1]
	local names = {}
	for name in EXPECTED_THEME do
		table.insert(names, name)
	end
	table.sort(names)
	for _, name in names do
		local theme = EXPECTED_THEME[name]
		w.train(w.localPlayer, name)
		w.train(other, name)
		w.step()
		checkOne(w, w.localPlayer, theme, THEMES[theme].Rate, "local on " .. name)
		checkOne(w, other, theme, THEMES[theme].Rate * 0.6, "other on " .. name)
		assert(w.attachments(w.localPlayer)[1] == localAttachment, "switch keeps the attachment")
		-- The old theme's emitter (if any) stops at once and is destroyed after its particles' life.
		for _, handle in w.delays do
			assert(handle.Time > 0 and handle.Time <= 0.85, "retire delay within the particle life")
		end
		w.flushDelays()
		assert(#w.emitters(w.localPlayer) == 1 and #w.emitters(other) == 1, name .. ": retired emitters destroyed")
	end
	-- A switch while fading brings the new theme back, still one emitter.
	w.localPlayer:SetAttribute("IsOnTreadmill", false)
	w.step()
	w.train(w.localPlayer, "Diamond")
	w.step()
	checkOne(w, w.localPlayer, "Diamond", THEMES.Diamond.Rate, "resume on another treadmill")
	w.flushDelays()
	checkOne(w, w.localPlayer, "Diamond", THEMES.Diamond.Rate, "cancelled fade leaves it running")
	assert(w.raycasts == 0, "no raycasts")
	pass(("every name (%d) maps to its theme on local and other runners; switching replaces the emitter"):format(#names))
end

-- Review fixes: a theme switch fades the old emitter out; a replaced root re-attaches; the phone
-- LOD has hysteresis (no 10 Hz blinking at the 20-stud edge or between the 3rd and 4th nearest).
do
	local w = makeWorld({ phone = true, template = true, distances = { 5, 10, 15, 15.5, 21 } })
	w.train(w.localPlayer, "Golden")
	w.step()
	local golden = w.emitters(w.localPlayer)[1]
	w.train(w.localPlayer, "Diamond")
	w.step()
	assert(golden.Parent ~= nil and not golden.Enabled and golden.Name == RETIRED, "old theme stops emitting but its particles live on")
	assert(#w.delays == 1 and w.delays[1].Time > 0 and w.delays[1].Time <= 0.85, "old emitter destroyed after its lifetime")
	checkOne(w, w.localPlayer, "Diamond", THEMES.Diamond.Rate, "new theme at once")
	w.flushDelays()
	assert(golden.Parent == nil and #w.emitters(w.localPlayer) == 1, "retired emitter gone")

	-- Streaming / a morph replaces the HumanoidRootPart of the same character model.
	local oldRoot = w.localPlayer.Root
	local newRoot = rb.Instance.new("Part")
	newRoot.Name = "HumanoidRootPart"
	newRoot.CFrame = oldRoot.CFrame
	w.localPlayer.Root = newRoot
	w.localPlayer.Character.FindFirstChild = function(_, child)
		return if child == "HumanoidRootPart" then newRoot else nil
	end
	w.step()
	checkOne(w, w.localPlayer, "Diamond", THEMES.Diamond.Rate, "re-attached on the new root")
	assert(#oldRoot:GetChildren() == 0, "the old root's attachment was destroyed")

	-- Others 1..4 at 5/10/15/15.5 train, 5 at 21 (outside 20).
	for i = 1, 5 do
		w.train(w.others[i], "Candy")
	end
	w.step()
	for i = 1, 3 do
		checkOne(w, w.others[i], "Candy", THEMES.Candy.Rate * 0.5, "phone near " .. i)
	end
	assert(#w.emitters(w.others[4]) == 0 and #w.emitters(w.others[5]) == 0, "4th nearest and 21 studs: nothing")
	-- The 3rd and 4th swap by less than the hysteresis on alternate scans: the shown one stays.
	for k = 1, 10 do
		w.others[3].Root.CFrame = rb.CFrame.new(if k % 2 == 1 then 16 else 15, 3, 0)
		w.others[4].Root.CFrame = rb.CFrame.new(if k % 2 == 1 then 15 else 16, 3, 0)
		w.step()
		checkOne(w, w.others[3], "Candy", THEMES.Candy.Rate * 0.5, "tie scan " .. k)
		assert(#w.emitters(w.others[4]) == 0, "tie scan " .. k .. ": the 4th never flickers on")
	end
	-- The shown one sits on the 20-stud line, drifting 19.5 <-> 21: it stays on.
	w.others[4]:SetAttribute("IsOnTreadmill", false)
	w.others[5]:SetAttribute("IsOnTreadmill", false)
	for k = 1, 10 do
		w.others[3].Root.CFrame = rb.CFrame.new(if k % 2 == 1 then 21 else 19.5, 3, 0)
		w.step()
		checkOne(w, w.others[3], "Candy", THEMES.Candy.Rate * 0.5, "edge scan " .. k)
	end
	assert(#w.delays == 0, "no fade started while blinking at the edge")
	-- Clearly past the cut (more than 2 studs): it fades as before.
	w.others[3].Root.CFrame = rb.CFrame.new(22.5, 3, 0)
	w.step()
	assert(#w.emitters(w.others[3]) == 1 and not w.emitters(w.others[3])[1].Enabled, "past the hysteresis: fade")
	w.flushDelays()
	assert(#w.emitters(w.others[3]) == 0, "then destroyed")
	-- A runner not yet showing does not get the bonus: 21 studs stays off.
	w.others[5]:SetAttribute("IsOnTreadmill", true)
	w.step()
	assert(#w.emitters(w.others[5]) == 0, "a new runner at 21 studs gets nothing")
	pass("review fixes: theme switch retires the old emitter after its lifetime; new root re-attaches; phone LOD hysteresis (tie and 20-stud edge)")
end

-- No template: code-built single emitters with the V40 textures.
do
	local w = makeWorld({ phone = false, template = false, distances = { 6, 12 } })
	w.train(w.localPlayer, "Golden")
	w.train(w.others[1], "Diamond")
	w.train(w.others[2], "Admin")
	w.step()
	assert(checkOne(w, w.localPlayer, "Golden", THEMES.Golden.Rate, "fallback lines").Texture == "rbxassetid://13828261486")
	assert(checkOne(w, w.others[1], "Diamond", THEMES.Diamond.Rate * 0.6, "fallback ring").Texture == "rbxassetid://16846725471")
	assert(checkOne(w, w.others[2], "Ruby", THEMES.Ruby.Rate * 0.6, "fallback ruby").Texture == "rbxassetid://16846725471")
	pass("without the template: one code-built emitter per runner (lines 13828261486 / ring 16846725471)")
end

-- Older server (no CurrentTreadmillName): the local player alone raycasts, once per scan.
do
	local w = makeWorld({ phone = true, template = true, distances = { 5, 6 } })
	local model = rb.Instance.new("Model")
	model.Name = "Treadmill2_fast"
	local belt = rb.Instance.new("Part")
	belt.Parent = model
	w.rayHit = belt
	w.localPlayer.Humanoid.MoveDirection = rb.Vector3.new(1, 0, 0)
	w.others[1]:SetAttribute("IsOnTreadmill", true)
	w.others[1].Humanoid.MoveDirection = rb.Vector3.new(1, 0, 0)
	w.step(4)
	assert(w.raycasts == 4, "one raycast per scan, local player only: " .. w.raycasts)
	checkOne(w, w.localPlayer, "Golden", THEMES.Golden.Rate, "raycast fallback theme")
	checkOne(w, w.others[1], "Basic", THEMES.Basic.Rate * 0.5, "other without a name")
	assert(#w.emitters(w.others[2]) == 0, "moving other without IsOnTreadmill gets nothing (no raycast)")
	pass("older server: the local player's raycast fallback only (1 per scan, shared params); others by attribute")
end

-- EventEffects off, character removal, player removal.
do
	local w = makeWorld({ phone = false, template = true, distances = { 5, 7 } })
	w.train(w.localPlayer, "Candy")
	w.train(w.others[1], "Hacker")
	w.train(w.others[2], "Taco")
	w.step()
	assert(w.totalEmitters(true) == 3)
	w.localPlayer:SetAttribute("EventEffects", false)
	w.step()
	assert(w.totalEmitters(true) == 0, "EventEffects off stops every effect")
	w.flushDelays()
	assert(w.totalEmitters() == 0, "and destroys them after the fade")
	w.localPlayer:SetAttribute("EventEffects", nil)
	w.step()
	assert(w.totalEmitters(true) == 3)
	w.others[1].CharacterRemoving:Fire(w.others[1].Character)
	assert(#w.attachments(w.others[1]) == 0, "CharacterRemoving destroys at once")
	w.playerRemoving:Fire(w.others[2])
	assert(#w.attachments(w.others[2]) == 0, "PlayerRemoving destroys at once")
	w.others[1].Character.Parent = nil
	w.others[2].Character.Parent = nil
	w.step()
	assert(#w.delays == 0, "nothing scheduled for removed characters")
	pass("EventEffects off, CharacterRemoving and PlayerRemoving leave nothing behind")
end

----------------------------------------------------------------------------------------------
-- 2. Server: the real loop body.
----------------------------------------------------------------------------------------------
do
	local serverSource = read(SERVER)
	local helper = between(serverSource, "local function getVfxTreadmillName(zone)", "\nlocal function ", "helper")
	local body = between(serverSource, "\t\tlocal playersOnAnyTreadmill = {}", "\n\tend\nend)\n\nMarketplaceService", "loop")
	assert(body:find('player:SetAttribute("IsOnTreadmill", onAny)\n\t\t\tend\n\t\t\tlocal currentName', 1, true), "written beside IsOnTreadmill")
	local writes = {}
	local function makePlayer(name)
		local attrs = {}
		return {
			Name = name,
			GetAttribute = function(_, k)
				return attrs[k]
			end,
			SetAttribute = function(_, k, v)
				if k == "CurrentTreadmillName" then
					table.insert(writes, name .. "=" .. tostring(v))
				end
				attrs[k] = v
			end,
		}
	end
	local a, b, c = makePlayer("A"), makePlayer("B"), makePlayer("C")
	local function treadmill(attrs)
		return { GetAttribute = function(_, k)
			return attrs[k]
		end }
	end
	local zones = {
		{ TreadmillName = "Golden", Treadmill = treadmill({}), Members = {} },
		{ TreadmillName = "Diamond", Treadmill = treadmill({}), Members = {} },
		{ TreadmillName = "Treadmill1_basic", Treadmill = treadmill({ IsTacoTreadmill = true }), Members = {} },
	}
	local env = setmetatable({
		zones = zones,
		findPlayersInZone = function(zone)
			return zone.Members
		end,
		playerMeetsRequirement = function()
			return true
		end,
		tryGrantTreadmillSpeed = function() end,
		notifyLockedPlayer = function() end,
		ejectLockedPlayer = function() end,
		ensureHeadTaco = function() end,
		removeHeadTaco = function() end,
		workspace = { GetAttribute = function()
			return nil
		end, GetServerTimeNow = function()
			return 0
		end },
		Players = { GetPlayers = function()
			return { a, b, c }
		end },
	}, { __index = _G })
	local tick = luau.load(helper .. "\nreturn function()\n" .. body .. "\nend", { environment = env })()
	tick()
	assert(a:GetAttribute("CurrentTreadmillName") == "" and #writes == 3, "first tick publishes \"\" for everyone")
	table.clear(writes)
	tick()
	assert(#writes == 0, "no write when nothing changed")
	zones[1].Members = { [a] = true }
	zones[2].Members = { [a] = true, [b] = true } -- A stands where Golden and Diamond overlap
	zones[3].Members = { [c] = true }
	tick()
	assert(a:GetAttribute("CurrentTreadmillName") == "Golden", "first zone found wins")
	assert(b:GetAttribute("CurrentTreadmillName") == "Diamond")
	assert(c:GetAttribute("CurrentTreadmillName") == "Taco", "taco treadmill publishes Taco")
	assert(a:GetAttribute("IsOnTreadmill") == true)
	assert(#writes == 3)
	table.clear(writes)
	for _ = 1, 5 do
		tick()
	end
	assert(#writes == 0, "only on change")
	zones[1].Members = {}
	tick()
	assert(a:GetAttribute("CurrentTreadmillName") == "Diamond" and #writes == 1, "switch publishes the new name")
	zones[2].Members = {}
	tick()
	assert(a:GetAttribute("IsOnTreadmill") == false and a:GetAttribute("CurrentTreadmillName") == "", "cleared with IsOnTreadmill")
	-- The touch path only fills an empty name.
	local touch = between(serverSource, 'player:SetAttribute("IsOnTreadmill", true)', "\telse\n", "touch")
	assert(touch:find('if currentName == nil or currentName == "" then', 1, true)
		and touch:find('player:SetAttribute("CurrentTreadmillName", getVfxTreadmillName(zone))', 1, true), "touch path")
	pass("server: CurrentTreadmillName beside IsOnTreadmill, on change only, first zone wins, Taco, cleared with it")
end

----------------------------------------------------------------------------------------------
-- 3. (places) The three places carry exactly the src of both scripts. Fails until the lead builds.
----------------------------------------------------------------------------------------------
if process.args[1] == "places" then
	local manifest = serde.decode("json", fs.readFile("src/manifest.json"))
	for _, entry in PlaceFiles.Places do
		local dm = rb.deserializePlace(fs.readFile(entry.file))
		for _, source in { CLIENT, SERVER } do
			local row
			for _, candidate in manifest.worlds[entry.key].scripts do
				if candidate.source == source then
					row = candidate
				end
			end
			assert(row, entry.key .. ": no manifest row for " .. source)
			local node = dm
			for _, name in row.segments do
				node = assert(node:FindFirstChild(name), entry.file .. " is missing " .. table.concat(row.segments, "."))
			end
			assert((string.gsub(node.Source, "\r\n", "\n")) == read(source), entry.file .. ": " .. node.Name .. " differs from src")
		end
	end
	pass("places: World1/World2/World3 carry the src TreadmillVfxController and TreadmillTraining")
end

print("ALL TREADMILL VFX TESTS PASSED")
