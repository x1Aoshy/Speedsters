-- audit/test_perf_live_errors.luau
-- The live error list of 2026-09-22 (Creator Hub error report) and the phone costs found next to
-- it, each checked on the real source text (functions cut out between their own lines and run
-- with stand-ins for the engine):
--   1. Raining Tacos: the crash (101686101827917, not authorized) and crunch (9114223170, not
--      audio) ids are off, and an empty id makes no Sound at all; with an id set, a small pool of
--      Sounds made once plays every taco instead of a new Sound per taco (~7 a second).
--   2. Snow draws 150 flakes a second on phones, 380 on computers.
--   3. Admin treadmill rainbow: the parts are listed once per model (not GetDescendants every
--      frame) and phones recolour at most 15 times a second; computers every frame as before.
--   4. R6DeathRagdoll never loads the get-up animation while its id is empty.
--   5. AsmrEffectsClient: a dead player (root false) no longer errors, and pressed keys release.
--   6. InstantMovementController no longer calls CameraPunch.Punch (the module has none).
--   7. SpinWheelController: a state push before the HUD button code has run does not error, the
--      lobby wheel waits in its own thread, and the HUD wheel turns at 30 Hz.
--   8. ZoomArenaAmbience: tweenVolume is declared above the SoundEffects handler that calls it.
--
--   lune run audit/test_perf_live_errors.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local Vector3 = roblox.Vector3
local Vector2 = roblox.Vector2
local CFrame = roblox.CFrame
local Color3 = roblox.Color3
local NumberRange = roblox.NumberRange
local NumberSequence = roblox.NumberSequence
local NumberSequenceKeypoint = roblox.NumberSequenceKeypoint
local ColorSequence = roblox.ColorSequence
local ColorSequenceKeypoint = roblox.ColorSequenceKeypoint
local UDim2 = roblox.UDim2

local EFFECTS = "src/common/StarterPlayer/StarterPlayerScripts/Admin/AdminAbuseEffects.client.luau"
local RAGDOLL = "src/common/StarterPlayer/StarterCharacterScripts/R6DeathRagdoll.server.luau"
local ASMR = "src/worlds/World2/StarterPlayer/StarterPlayerScripts/AsmrEffectsClient.client.luau"
local IMC = "src/common/StarterPlayer/StarterPlayerScripts/Movement/InstantMovementController.client.luau"
local SPIN = "src/common/StarterPlayer/StarterPlayerScripts/UI/SpinWheelController.client.luau"
local ZOOM = "src/common/StarterPlayer/StarterPlayerScripts/Gameplay/ZoomArenaAmbience.client.luau"

local function read(path)
	return (string.gsub(fs.readFile(path), "\r\n", "\n"))
end
local function pass(text)
	print("PASS " .. text)
end
-- From `first` up to (not including) `last`.
local function between(source, first, last, label)
	local a = assert(string.find(source, first, 1, true), label .. ": start moved")
	local b = assert(string.find(source, last, a + #first, true), label .. ": end moved")
	return string.sub(source, a, b - 1)
end
-- From `first` through the first column-0 "end" after `anchor`.
local function throughEnd(source, first, anchor, label)
	local a = assert(string.find(source, first, 1, true), label .. ": start moved")
	local b = assert(string.find(source, anchor, a, true), label .. ": anchor moved")
	local _, c = string.find(source, "\nend\n", b, true)
	assert(c, label .. ": end moved")
	return string.sub(source, a, c)
end
local function env(values)
	return setmetatable(values, { __index = _G })
end
-- A clock the test moves by hand.
local function fakeOs()
	local clock = { now = 0 }
	return clock, setmetatable({
		clock = function()
			return clock.now
		end,
	}, { __index = os })
end

----------------------------------------------------------------------
-- Every changed source compiles
----------------------------------------------------------------------
for _, path in { EFFECTS, RAGDOLL, ASMR, IMC, SPIN, ZOOM } do
	luau.compile(fs.readFile(path))
end
pass("all six changed sources compile")

----------------------------------------------------------------------
-- 1. Taco sounds
----------------------------------------------------------------------
do
	local source = read(EFFECTS)
	local tacosText = between(source, "local TACOS = {", "\nlocal tacosWeight", "TACOS table")
	local TACOS = luau.load(tacosText .. "\nreturn TACOS", { environment = env({ LOW_POWER = true, Color3 = Color3 }) })()
	assert(TACOS.CrashSoundId == "", "the unauthorized crash id is off")
	assert(TACOS.CrunchSoundId == "", "the non-audio crunch id is off")
	assert(not string.find(source, '"rbxassetid://101686101827917"', 1, true), "101686101827917 is not used as an id")
	assert(not string.find(source, '"rbxassetid://9114223170"', 1, true), "9114223170 is not used as an id")

	local chunk = throughEnd(source, "local TACO_SOUND_POOL_SIZE", "local function tacoPlayerHit", "taco sounds")
	assert(not string.find(chunk, "Debris:AddItem(sound", 1, true), "no Sound goes to Debris any more")

	-- Instance stand-ins: every Instance.new is counted by class; Sound:Play is counted.
	local function run(ids, crashes, hits)
		local created, plays = {}, { n = 0 }
		local function newInstance(className)
			created[className] = (created[className] or 0) + 1
			local object = { ClassName = className, Name = className }
			function object:Play()
				if className == "Sound" then
					plays.n += 1
				end
			end
			function object:Emit() end
			function object:IsA(name)
				return name == className
			end
			function object:GetDescendants()
				return {}
			end
			return object
		end
		local clock, osStub = fakeOs()
		local tacos = table.clone(TACOS)
		tacos.CrashSoundId, tacos.CrunchSoundId = ids, ids
		local fn = luau.load(chunk .. "\nreturn tacoGroundCrash, tacoPlayerHit", { environment = env({
			os = osStub,
			TACOS = tacos,
			LOW_POWER = true,
			tacoShake = 0,
			lastTacoPickupAt = -1,
			Instance = { new = newInstance },
			Workspace = { CurrentCamera = nil },
			SoundService = { Name = "SoundService" },
			ReplicatedStorage = { Shared = { FindFirstChild = function() return nil end } },
			TweenService = { Create = function() return { Play = function() end } end },
			TweenInfo = { new = function() return {} end },
			Debris = { AddItem = function() end },
			Flipbooks = { Apply = function() end },
			character = function() return nil, nil end,
			getTacoHitRemote = function() return nil end,
			Enum = roblox.Enum,
			Vector3 = Vector3, Vector2 = Vector2, CFrame = CFrame, Color3 = Color3, UDim2 = UDim2,
			NumberRange = NumberRange, NumberSequence = NumberSequence, NumberSequenceKeypoint = NumberSequenceKeypoint,
			ColorSequence = ColorSequence, ColorSequenceKeypoint = ColorSequenceKeypoint,
		}) })
		local crash, hit = fn()
		for i = 1, crashes do
			clock.now = i * 0.14
			crash(Vector3.new(i, 0, 0))
		end
		for i = 1, hits do
			clock.now = 100 + i * 0.2 -- past the 0.15 s crunch throttle every time
			hit(Vector3.new(i, 0, 0))
		end
		return created, plays.n
	end

	local created, plays = run("", 100, 100)
	assert((created.Sound or 0) == 0 and plays == 0, "empty ids: no Sound made or played in 100 crashes and 100 hits")
	assert((created.ParticleEmitter or 0) > 0, "the crash visuals still run (the stand-ins work)")
	pass("Raining Tacos: both bad ids are off and an empty id creates no Sound (100 crashes + 100 hits)")

	created, plays = run("rbxassetid://1", 100, 100)
	local POOL = tonumber(string.match(chunk, "TACO_SOUND_POOL_SIZE = (%d+)"))
	assert(POOL and POOL <= 4, "a small pool")
	assert(created.Sound <= POOL * 2, ("a set id: %d Sounds for 200 taco sounds (pool %d per kind)"):format(created.Sound, POOL))
	assert(plays == 200, "every crash and hit still plays its sound (" .. plays .. ")")
	pass(("Raining Tacos: a set id makes %d Sounds for 100 crashes + 100 hits and plays all 200"):format(created.Sound))
end

----------------------------------------------------------------------
-- 2. Snow rate
----------------------------------------------------------------------
do
	local source = read(EFFECTS)
	local snowText = between(source, "local SNOW = {", "\nlocal snowWeight", "SNOW table")
	local function rate(lowPower)
		return luau.load(snowText .. "\nreturn SNOW.Rate", { environment = env({ LOW_POWER = lowPower, Color3 = Color3 }) })()
	end
	assert(rate(true) == 150, "phones: 150 flakes a second")
	assert(rate(false) == 380, "computers: 380 flakes a second")
	assert(string.find(source, "snow.Emitter.Rate = SNOW.Rate * t", 1, true), "the emitter still uses SNOW.Rate")
	pass("snow: 150 flakes a second on phones, 380 on computers")
end

----------------------------------------------------------------------
-- 3. Admin treadmill rainbow
----------------------------------------------------------------------
do
	local source = read(EFFECTS)
	local chunk = between(source, "local RAINBOW_LOW_POWER_STEP", "\n-- Telling the server when this player dances", "rainbow")
	local function run(lowPower, frames, fps)
		local descendantsCalls = 0
		local added = {}
		local parts = {}
		for i = 1, 6 do
			local part = { Name = "Belt" .. i, Position = Vector3.new(i * 3, 0, i), Writes = 0 }
			function part:IsA(name)
				return name == "BasePart"
			end
			setmetatable(part, {
				__newindex = function(t, key, value)
					if key == "Color" then
						rawset(t, "Writes", t.Writes + 1)
					end
				end,
			})
			table.insert(parts, part)
		end
		local disconnected = 0
		local signal = function()
			return {
				Connect = function(_, fn)
					table.insert(added, fn)
					return { Disconnect = function()
						disconnected += 1
					end }
				end,
			}
		end
		local model = {
			DescendantAdded = signal(),
			DescendantRemoving = signal(),
			GetAttribute = function(_, key)
				return key == "AdminRainbow"
			end,
			GetDescendants = function()
				descendantsCalls += 1
				return parts
			end,
			FindFirstChild = function()
				return nil
			end,
		}
		local inFolder = { model }
		local folder = { GetChildren = function() return inFolder end }
		model.Parent = folder
		local clock, osStub = fakeOs()
		local update = luau.load(chunk .. "\nreturn updateTreadmills", { environment = env({
			os = osStub,
			LOW_POWER = lowPower,
			Workspace = {
				FindFirstChild = function(_, name)
					return if name == "AdminSpawnedTreadmills" then folder else nil
				end,
				GetServerTimeNow = function() return 0 end,
			},
			Color3 = Color3,
			Vector2 = Vector2,
		}) })()
		for frame = 0, frames - 1 do
			clock.now = frame / fps
			update()
		end
		-- The treadmill times out: its list and both signal connections are dropped, and it is
		-- never listed again (a weak-keyed cache could lose the entry and reconnect instead).
		model.Parent = nil
		table.clear(inFolder)
		update()
		assert(disconnected == 2, "a treadmill that left the folder has its 2 connections dropped (" .. disconnected .. ")")
		update()
		assert(disconnected == 2 and #added == 2, "...once, and nothing connects again")
		return parts[1].Writes, descendantsCalls
	end

	local writes, calls = run(true, 120, 60) -- two seconds at 60 FPS
	assert(writes <= 30 and writes >= 25, ("phones: %d recolours in 2 s (at most 15 Hz)"):format(writes))
	assert(calls == 1, ("phones: GetDescendants %d times in 120 frames (once)"):format(calls))
	assert(select(1, run(true, 1, 60)) == 1, "the first frame recolours")
	pass(("rainbow on phones: %d recolours in 2 s at 60 FPS, GetDescendants once per model"):format(writes))

	writes, calls = run(true, 288, 144) -- two seconds at 144 FPS
	assert(writes <= 30, ("phones at 144 FPS: %d recolours in 2 s"):format(writes))

	writes, calls = run(false, 120, 60)
	assert(writes == 120, ("computers: every frame as before (%d of 120)"):format(writes))
	assert(calls == 1, "computers: listed once too")
	pass("rainbow on computers: every frame recolours, as before")
end
-- The model listing is rebuilt when its parts change.
do
	local source = read(EFFECTS)
	local chunk = between(source, "local RAINBOW_LOW_POWER_STEP", "\nlocal function updateTreadmills", "rainbow parts")
	local calls, fns = 0, {}
	local signal = { Connect = function(_, fn)
		table.insert(fns, fn)
		return { Disconnect = function() end }
	end }
	local model = {
		DescendantAdded = signal,
		DescendantRemoving = signal,
		GetDescendants = function()
			calls += 1
			return {}
		end,
	}
	local partsOf = luau.load(chunk .. "\nreturn rainbowPartsOf", { environment = env({ LOW_POWER = true }) })()
	partsOf(model)
	partsOf(model)
	assert(calls == 1, "listed once")
	fns[1]()
	partsOf(model)
	partsOf(model)
	assert(calls == 2, "listed again after DescendantAdded, once")
	fns[2]()
	partsOf(model)
	assert(calls == 3, "listed again after DescendantRemoving")
	pass("rainbow part lists are rebuilt only when the model's descendants change")
end

----------------------------------------------------------------------
-- 4. R6DeathRagdoll get-up animation
----------------------------------------------------------------------
do
	local source = read(RAGDOLL)
	local chunk = between(source, "local GET_UP_ANIMATION_ID", "\n-- Builds the RagdollComponents folder", "ragdoll get-up")
	assert(string.find(chunk, 'local GET_UP_ANIMATION_ID = ""', 1, true), "the id is empty")
	local function run(text)
		local loads, created = 0, 0
		local animator = {
			LoadAnimation = function()
				loads += 1
				return {}
			end,
		}
		local humanoid = { FindFirstChildOfClass = function() return animator end }
		local track = luau.load(text .. "\nreturn getUpTrack", { environment = env({
			humanoid = humanoid,
			Instance = { new = function() created += 1; return {} end },
			Enum = roblox.Enum,
		}) })()
		return loads, created, track
	end
	local loads, created, track = run(chunk)
	assert(loads == 0 and created == 0 and track == nil, "empty id: no Animation and no LoadAnimation")
	-- The same code with an id does load it (the stand-ins reach LoadAnimation).
	loads = run((string.gsub(chunk, 'local GET_UP_ANIMATION_ID = ""', 'local GET_UP_ANIMATION_ID = "rbxassetid://1"')))
	assert(loads == 1, "with an id the animation loads once")
	assert(string.find(source, "if getUpTrack then", 1, true), "the play site stays guarded")
	pass("R6DeathRagdoll: with the id empty, setupGetUpAnimation returns before LoadAnimation")
end

----------------------------------------------------------------------
-- 5. AsmrEffectsClient while dead
----------------------------------------------------------------------
do
	local source = read(ASMR)
	local chunk = between(source, "local function update(record, root)", "\nWorkspace.DescendantAdded:Connect(discover)", "asmr update")
	local tweens = 0
	local update = luau.load(chunk .. "\nreturn update", { environment = env({
		TweenService = { Create = function() tweens += 1; return { Play = function() end, Cancel = function() end } end },
		PRESS = "press",
		RELEASE = "release",
		Vector3 = Vector3,
	}) })()
	local function record()
		local piece = { Parent = {}, FindFirstChildWhichIsA = function() return nil end }
		return {
			soundIds = {},
			cells = { { piece = piece, cf = CFrame.new(0, 0, 0), size = Vector3.new(4, 1, 4), pressed = false } },
		}
	end
	local r = record()
	update(r, { Position = Vector3.new(0, 1, 0) })
	assert(r.cells[1].pressed == true, "standing on a key presses it (the stand-ins work)")
	local ok, err = pcall(update, r, false)
	assert(ok, "a dead player's root (false) does not error: " .. tostring(err))
	assert(r.cells[1].pressed == false, "the pressed key releases while dead")
	r = record()
	r.cells[1].pressed = true
	assert(pcall(update, r, nil) and r.cells[1].pressed == false, "no root: released")

	local rootLine = string.match(source, "\n\t(local root = [^\n]+)")
	local root = luau.load("local character, humanoid = ...\n" .. rootLine .. "\nreturn root")(
		{ FindFirstChild = function() return { Position = Vector3.zero } end },
		{ Health = 0 }
	)
	assert(root == nil, "the Heartbeat root is nil (not false) for a dead player")
	pass("AsmrEffectsClient: a dead player's update does not error and releases pressed keys")
end

----------------------------------------------------------------------
-- 6. InstantMovementController
----------------------------------------------------------------------
do
	local source = read(IMC)
	assert(not string.find(source, "CameraPunch.Punch", 1, true), "no CameraPunch.Punch call")
	assert(not string.find(source, 'WaitForChild("CameraPunch")', 1, true), "the unused CameraPunch require is gone")
	assert(string.find(source, "CameraPunch = true,", 1, true), "GlassShatter still shakes the camera (unchanged)")
	local module = read("src/common/ReplicatedStorage/Shared/CameraPunch.luau")
	assert(not string.find(module, "%.Punch%s*=") and not string.find(module, "function%s+%w+[.:]Punch%f[^%w_]"), "CameraPunch really has no Punch")
	pass("InstantMovementController: no call to the missing CameraPunch.Punch")
end

----------------------------------------------------------------------
-- 7. SpinWheelController
----------------------------------------------------------------------
do
	local source = read(SPIN)
	local chunk = between(source, "local function setButtonEnabled", "\n----------------------------------------------------------------------\n-- Spinning", "renderState")
	local function run(refresh)
		local renderState = luau.load(chunk .. "\nreturn renderState", { environment = env({
			state = { Loading = false, PaidSpinsAllowed = false, FreeAvailable = true, Products = {} },
			phase = "idle",
			spinsAvailable = function() return 1 end,
			spinCount = {},
			spinButton = {},
			sidePacks = {},
			packs = {},
			winsButton = nil,
			timerLabel = {},
			messageText = nil,
			messageUntil = 0,
			livePrices = {},
			formatClock = function() return "" end,
			serverNow = function() return 0 end,
			renderSegments = function() end,
			refreshHudButton = refresh,
			DIM_COLOR = Color3.new(0.5, 0.5, 0.5),
			Color3 = Color3,
		}) })()
		return pcall(renderState)
	end
	local ok, err = run(nil)
	assert(ok, "renderState before refreshHudButton exists: " .. tostring(err))
	local calls = 0
	assert(run(function() calls += 1 end) and calls == 1, "renderState refreshes the HUD button once it exists")
	pass("SpinWheelController: a state push before the HUD button code has run does not error")

	-- The lobby wheel waits in its own thread; nothing after it uses its locals.
	assert(string.find(source, 'task.spawn(function()\n\tlocal model = Workspace:WaitForChild("SpinWheelLobby")', 1, true),
		"the lobby wheel wait runs in its own thread")
	local lobbyEnd = select(2, string.find(source, "\t\t\t\tlobbyWheel.Rotation = idleAngle\n\t\t\tend\n\t\tend)\n\tend\nend)\n", 1, true))
	assert(lobbyEnd, "the lobby thread closes where expected")
	local after = string.gsub(string.sub(source, lobbyEnd + 1), "%-%-[^\n]*", "") -- code only, no comments
	for _, name in { "model", "face", "surface", "holder", "overhead", "billboard", "promptAnchor", "prompt", "idleAngle" } do
		assert(not string.find(after, "%f[%w_]" .. name .. "%f[^%w_]"), name .. " is not used after the lobby thread")
	end
	for _, use in { "if lobbyStatus then", "if lobbyWheel then" } do
		assert(string.find(after, use, 1, true), use .. " guards the countdown loop")
	end
	assert(string.find(after, "local function buildHudButton", 1, true) or string.find(source, "local function buildHudButton", 1, true), "HUD button builder present")
	pass("SpinWheelController: the lobby wheel no longer holds up the HUD button, countdown and first state request")

	-- The HUD wheel turns at 30 Hz; the button follows x2 Speed every frame.
	local spinnerChunk = between(source, "local HUD_SPINNER_STEP", "\n\n-- Countdown,", "HUD spinner")
	local function frames(fps, seconds)
		local callback
		local rotations, places = 0, 0
		local spinner = setmetatable({}, {
			__newindex = function(_, key)
				if key == "Rotation" then
					rotations += 1
				end
			end,
		})
		luau.load(spinnerChunk, { environment = env({
			RunService = { RenderStepped = { Connect = function(_, fn) callback = fn end } },
			hudSpinner = spinner,
			HUD_WHEEL_DEGREES_PER_SECOND = 45,
			placeHudButton = function() places += 1 end,
		}) })()
		for _ = 1, fps * seconds do
			callback(1 / fps)
		end
		return rotations, places
	end
	local rotations, places = frames(60, 2)
	assert(rotations >= 58 and rotations <= 61, ("60 FPS: %d HUD wheel turns in 2 s (30 Hz)"):format(rotations))
	assert(places == 120, "the button is placed every frame")
	rotations, places = frames(144, 2)
	assert(rotations >= 58 and rotations <= 61 and places == 288, ("144 FPS: %d turns in 2 s"):format(rotations))
	rotations = frames(20, 2)
	assert(rotations == 40, "below 30 FPS every frame turns")
	pass("SpinWheelController: the HUD wheel turns 30 times a second, the button is placed every frame")
end

----------------------------------------------------------------------
-- 8. ZoomArenaAmbience
----------------------------------------------------------------------
do
	local source = read(ZOOM)
	local declared = string.find(source, "\nlocal tweenVolume\n", 1, true)
	local firstCall = string.find(source, "tweenVolume(sound", 1, true)
	local handler = string.find(source, 'GetAttributeChangedSignal("SoundEffects")', 1, true)
	assert(declared and firstCall and handler, "declaration, handler and call found")
	assert(declared < handler and declared < firstCall, "the local is declared above the SoundEffects handler and its first use")
	assert(not string.find(source, "local function tweenVolume", 1, true), "the definition assigns the forward-declared local")
	assert(string.find(source, "\nfunction tweenVolume(sound, volume)", 1, true), "the definition is an assignment")
	pass("ZoomArenaAmbience: the SoundEffects handler resolves tweenVolume to the local")
end

print("ALL LIVE ERROR CHECKS PASSED")
