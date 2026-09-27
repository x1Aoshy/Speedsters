-- audit/test_perf_phone.luau
-- The 2026-09-22 phone performance pass, run on the REAL sources (luau.load of the file or of
-- a marked slice, with the engine stubbed) and on in-memory copies of the three real places:
--   1. AuraSpecialEffectsClient: other players' auras on a phone are full within 40 studs,
--      20% to 100, none beyond; their Beams and Lights go off outside 40 and come back to
--      exactly what they were. A desktop is unchanged (75/150/30%, beams never touched), and
--      the player's own aura is never thinned.
--   2. LowPowerGraphics: on a phone Bloom, SunRays and Depth of Field go off (also when the
--      server recreates them, or turns one back on); ColorCorrection and Atmosphere stay. The
--      six lobby bolt Highlights go off in every world; no other Highlight changes. A desktop
--      changes nothing.
--   3. RunningAndTreadmillSound: one RaycastParams for the script's life, the loop at 10 Hz,
--      the root's children walked only when it gets one.
--   4. World2TreeSlammers: the contact filter is written once per cache rebuild, not per
--      frame, the kill still happens, and non-parts streaming in are ignored at once.
--   5. R15SpeedsterRun: the afterimages are cleared when the boost stops (the flag is a local
--      declared before it is set). The old source fails the same harness.
--   6. audit/perf_place_edits.luau on the three places: exact counts, only Bottom 0.9
--      overlays on static upright map parts removed, the Stage 10 emitters fixed, the three
--      unauthorized Sounds gone, and a second run changes nothing.
--
--   lune run audit/test_perf_phone.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local rb = require("@lune/roblox")
local PlaceFiles = require("./place_files")
local Edits = require("./perf_place_edits")

local SPS = "src/common/StarterPlayer/StarterPlayerScripts/"
local AURA = SPS .. "Movement/AuraSpecialEffectsClient.client.luau"
local LOW = SPS .. "Gameplay/LowPowerGraphics.client.luau"
local SOUND = SPS .. "Audio/RunningAndTreadmillSound.client.luau"
local TREES = "src/worlds/World2/StarterPlayer/StarterPlayerScripts/Gameplay/World2TreeSlammers.client.luau"
local RUN = "src/common/StarterPlayer/StarterCharacterScripts/R15SpeedsterRun.client.luau"

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
			return { Disconnect = function()
				local index = table.find(callbacks, callback)
				if index then
					table.remove(callbacks, index)
				end
			end }
		end,
		Fire = function(_, ...)
			for _, callback in table.clone(callbacks) do
				callback(...)
			end
		end,
		Count = function()
			return #callbacks
		end,
	}
end

-- 0. Everything changed compiles ------------------------------------------------------------
for _, path in { AURA, LOW, SOUND, TREES, RUN, "audit/perf_place_edits.luau" } do
	assert(#luau.compile(fs.readFile(path)) > 0, path)
end
pass("the five client sources and the place edits compile")

-- 1. Aura LOD --------------------------------------------------------------------------------
do
	local source = read(AURA)
	assert(string.find(source, "local LOW_POWER = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled", 1, true),
		"the aura client tells phones apart the way the rest of the game does")
	-- Lune's parts have no .Position; the same point through CFrame.
	local chunk = string.gsub(between(source, "local LOD = {", "local lodClock = 0", "aura LOD"), "root%.Position", "root.CFrame.Position")

	local function dressed(x)
		local character = rb.Instance.new("Model")
		local root = rb.Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.CFrame = rb.CFrame.new(x, 0, 0)
		root.Parent = character
		local cosmetics = rb.Instance.new("Folder")
		cosmetics.Name = "SpeedsterCosmetics"
		cosmetics.Parent = character
		local holder = rb.Instance.new("Part")
		holder.Parent = cosmetics
		local kit = { character = character, root = root }
		kit.emitter = rb.Instance.new("ParticleEmitter")
		kit.emitter.Rate = 20
		kit.emitter.Parent = holder
		kit.trail = rb.Instance.new("Trail")
		kit.trail.Enabled = true
		kit.trail.Parent = holder
		kit.beam = rb.Instance.new("Beam")
		kit.beam.Enabled = true
		kit.beam.Parent = holder
		kit.offBeam = rb.Instance.new("Beam") -- authored off: must stay off
		kit.offBeam.Enabled = false
		kit.offBeam.Parent = holder
		kit.light = rb.Instance.new("PointLight")
		kit.light.Enabled = true
		kit.light.Parent = holder
		kit.spot = rb.Instance.new("SpotLight")
		kit.spot.Enabled = true
		kit.spot.Parent = holder
		return kit
	end

	local function harness(lowPower)
		local me, other = {}, {}
		local mine, theirs = dressed(0), dressed(0)
		me.Character, other.Character = mine.character, theirs.character
		local env = setmetatable({
			Players = { GetPlayers = function() return { me, other } end },
			localPlayer = me,
			LOW_POWER = lowPower,
		}, { __index = _G })
		local updateLod = luau.load(chunk .. "\nreturn updateLod, LOD", { environment = env })()
		local now = 0
		local function at(distance)
			theirs.root.CFrame = rb.CFrame.new(distance, 0, 0)
			mine.root.CFrame = rb.CFrame.new(0, 0, 0)
			now += 2.5 -- past LOD.Refresh, so each call walks the cosmetics again
			updateLod(rb.Vector3.new(0, 0, 0), now)
		end
		return mine, theirs, at
	end

	-- A phone.
	local mine, theirs, at = harness(true)
	at(30)
	assert(theirs.emitter.Rate == 20 and theirs.beam.Enabled and theirs.light.Enabled and theirs.spot.Enabled and theirs.trail.Enabled,
		"phone, 30 studs: everything at full")
	at(60)
	assert(math.abs(theirs.emitter.Rate - 4) < 1e-6, "phone, past 40 studs: 20% of the particles (" .. theirs.emitter.Rate .. ")")
	assert(not theirs.beam.Enabled and not theirs.light.Enabled and not theirs.spot.Enabled, "phone, past 40 studs: their beams and lights are off")
	assert(theirs.trail.Enabled, "phone, past 40 studs: the trail stays until the far ring")
	at(90)
	assert(not theirs.beam.Enabled and not theirs.offBeam.Enabled, "phone: still held off on the next walk")
	at(120)
	assert(theirs.emitter.Rate == 0 and not theirs.trail.Enabled and not theirs.beam.Enabled, "phone, past 100 studs: nothing")
	at(20)
	assert(theirs.emitter.Rate == 20 and theirs.trail.Enabled, "phone, back near: particles and trail back")
	assert(theirs.beam.Enabled and theirs.light.Enabled and theirs.spot.Enabled, "phone, back near: the beams and lights that were on are on")
	assert(not theirs.offBeam.Enabled, "phone: a beam the aura keeps off is never forced on")
	-- Something (an aura script) switches a held beam on: that becomes the state to restore.
	at(60)
	theirs.offBeam.Enabled = true
	at(60)
	assert(not theirs.offBeam.Enabled, "phone: re-held off on the next walk")
	at(20)
	assert(theirs.offBeam.Enabled, "phone: restored to what it was last set to, not to a stale value")
	at(80)
	for _, item in { mine.beam, mine.light, mine.spot, mine.trail } do
		assert(item.Enabled, "phone: the player's own aura is never touched")
	end
	assert(mine.emitter.Rate == 20 and not mine.offBeam.Enabled, "phone: the player's own aura is never touched")

	-- A desktop: as before, byte for byte.
	local _, theirsPc, atPc = harness(false)
	atPc(60)
	assert(theirsPc.emitter.Rate == 20 and theirsPc.beam.Enabled and theirsPc.light.Enabled, "desktop, 60 studs: full (Near 75)")
	atPc(100)
	assert(math.abs(theirsPc.emitter.Rate - 6) < 1e-6 and theirsPc.beam.Enabled and theirsPc.light.Enabled and theirsPc.trail.Enabled,
		"desktop, 100 studs: 30% of the particles, beams and lights untouched")
	atPc(200)
	assert(theirsPc.emitter.Rate == 0 and not theirsPc.trail.Enabled, "desktop, past 150: no particles, no trail")
	assert(theirsPc.beam.Enabled and theirsPc.light.Enabled and theirsPc.spot.Enabled and not theirsPc.offBeam.Enabled,
		"desktop: beams and lights are never touched")
	pass("aura LOD: phones 40/100/20% with other players' beams and lights off past 40 and restored exactly; desktop 75/150/30% unchanged; own aura untouched")
end

-- 2. LowPowerGraphics (loaded whole) ---------------------------------------------------------
local places = {}
for _, place in PlaceFiles.Places do
	places[place.key] = rb.deserializePlace(fs.readFile(place.file))
end

local function mockEffect(className)
	local data = { Enabled = true, Name = className, ClassName = className }
	local changed = signal()
	local proxy = setmetatable({}, {
		__index = function(_, key)
			if key == "IsA" then
				return function(_, name) return name == className end
			elseif key == "GetPropertyChangedSignal" then
				return function(_, property)
					assert(property == "Enabled")
					return changed
				end
			end
			return data[key]
		end,
		__newindex = function(_, key, value)
			local old = data[key]
			data[key] = value
			if key == "Enabled" and old ~= value then
				changed:Fire()
			end
		end,
	})
	return proxy
end

local function runLowPower(dm, touch, keyboard)
	local children = {}
	for _, name in { "BloomEffect", "SunRaysEffect", "ColorCorrectionEffect", "Atmosphere" } do
		table.insert(children, mockEffect(name))
	end
	local shadowsSignal, childAdded = signal(), signal()
	local lighting = setmetatable({ ChildAdded = childAdded, Children = children }, {
		__index = {
			GlobalShadows = true,
			GetChildren = function(self) return table.clone(self.Children) end,
			GetPropertyChangedSignal = function(_, name)
				assert(name == "GlobalShadows")
				return shadowsSignal
			end,
		},
	})
	local loop = nil
	local services = {
		Lighting = lighting,
		UserInputService = { TouchEnabled = touch, KeyboardEnabled = keyboard },
		Workspace = dm:GetService("Workspace"),
	}
	local env = setmetatable({
		game = { GetService = function(_, name) return assert(services[name], name) end },
		task = {
			spawn = function(fn) loop = coroutine.create(fn) end,
			wait = function() coroutine.yield() end,
		},
	}, { __index = _G })
	luau.load(read(LOW), { environment = env })()
	local function sweep()
		if loop then
			assert(coroutine.resume(loop))
		end
	end
	sweep()
	return lighting, children, childAdded, sweep
end

local function highlights(dm)
	local list = {}
	for _, item in dm:GetService("Workspace"):GetDescendants() do
		if item.ClassName == "Highlight" then
			table.insert(list, item)
		end
	end
	return list
end
local function isLobbyBolt(highlight)
	local bolt = highlight.Parent
	local holder = bolt and bolt.Parent
	local display = holder and holder.Parent
	local root = display and display.Parent
	if not (bolt.Name == "Lightning Bolt GFX" and holder.Name == "Model" and display) then
		return false
	end
	local ws = highlight:FindFirstAncestorOfClass("Workspace")
	return (display.Name == "Admin" or display.Name == "Hacker")
		and ((root and (root.Name == "neworld1" or root.Name == "Lobby") and root.Parent == ws)
			or (display.Name == "Admin" and root == ws)
			or (display.Name == "Hacker" and root and root.Name == "Admin" and root.Parent == ws))
end

do
	-- Desktop: nothing at all changes.
	local lighting, effects, childAdded, sweep = runLowPower(places.World1, true, true)
	local dof = mockEffect("DepthOfFieldEffect")
	lighting.Children[#lighting.Children + 1] = dof
	childAdded:Fire(dof)
	sweep()
	assert(lighting.GlobalShadows == true, "desktop keeps its shadows")
	for _, effect in effects do
		assert(effect.Enabled, "desktop keeps " .. effect.ClassName)
	end
	assert(dof.Enabled, "desktop keeps a new Depth of Field")
	for _, highlight in highlights(places.World1) do
		assert(highlight.Enabled, "desktop keeps every Highlight")
	end

	local totalBolts = 0
	for _, key in { "World1", "World2", "World3" } do
		local dm = places[key]
		local ws = dm:GetService("Workspace")
		-- Highlights that must never be touched: a character's, a tutorial's, one on the display
		-- model itself, and the admin treadmill clone's bolts (AdminPanelService parents an
		-- "Admin3000" copy of the Hacker treadmill into neworld1).
		local character = rb.Instance.new("Model")
		character.Name = "SomePlayer"
		character.Parent = ws
		local characterHighlight = rb.Instance.new("Highlight")
		characterHighlight.Parent = character
		local tutorial = rb.Instance.new("Highlight")
		tutorial.Name = "TutorialHighlight"
		tutorial.Parent = ws
		local extra = {}
		local displayRoot = ws:FindFirstChild("neworld1") or ws:FindFirstChild("Lobby") or ws
		local display = assert(displayRoot:FindFirstChild("Admin"), key .. ": no Admin display")
		local onDisplay = rb.Instance.new("Highlight")
		onDisplay.Parent = display
		table.insert(extra, onDisplay)
		local hacker = displayRoot:FindFirstChild("Hacker") or display:FindFirstChild("Hacker")
		local clone = assert(hacker, key .. ": no Hacker display"):Clone()
		clone.Name = "Admin3000"
		clone.Parent = displayRoot
		for _, item in clone:GetDescendants() do
			if item.ClassName == "Highlight" then
				table.insert(extra, item)
			end
		end

		local before = {}
		for _, highlight in highlights(dm) do
			before[highlight] = highlight.Enabled
		end
		local lightingPhone, phoneEffects, phoneChildAdded, phoneSweep = runLowPower(dm, true, false)
		local bolts = 0
		for _, highlight in highlights(dm) do
			if isLobbyBolt(highlight) then
				bolts += 1
				assert(not highlight.Enabled, key .. ": a lobby bolt Highlight is still on: " .. highlight:GetFullName())
			else
				assert(highlight.Enabled == before[highlight], key .. ": a Highlight that is not a lobby bolt changed: " .. highlight:GetFullName())
			end
		end
		assert(bolts == 6, key .. ": expected the 6 lobby bolt Highlights, found " .. bolts)
		totalBolts += bolts
		assert(characterHighlight.Enabled and tutorial.Enabled, key .. ": gameplay Highlights untouched")
		for _, item in extra do
			assert(item.Enabled, key .. ": " .. item:GetFullName() .. " is not a lobby bolt and must stay on")
		end
		if key == "World2" then
			assert(ws.SixSevenArea.Highlight.Enabled, "World 2's SixSevenArea Highlight is gameplay and stays")
		end
		-- Streaming: the lobby goes and comes back as new instances; the next sweep catches it.
		local adminDisplay = if key == "World2" then ws.Admin else displayRoot.Admin
		local fresh = adminDisplay:Clone()
		local parent = adminDisplay.Parent
		adminDisplay:Destroy()
		fresh.Parent = parent
		for _, item in fresh:GetDescendants() do
			if item.ClassName == "Highlight" and item.Parent.Name == "Lightning Bolt GFX" then
				item.Enabled = true
			end
		end
		phoneSweep()
		for _, highlight in highlights(dm) do
			if isLobbyBolt(highlight) then
				assert(not highlight.Enabled, key .. ": a re-streamed bolt Highlight stayed on")
			end
		end

		-- Lighting on the phone.
		assert(lightingPhone.GlobalShadows == false, "phone: shadows off")
		for _, effect in phoneEffects do
			local off = effect.ClassName == "BloomEffect" or effect.ClassName == "SunRaysEffect"
			assert(effect.Enabled == not off, "phone: " .. effect.ClassName .. (if off then " must be off" else " must stay on"))
		end
		-- The server destroys and recreates its effects: ChildAdded.
		for _, name in { "BloomEffect", "SunRaysEffect", "DepthOfFieldEffect", "ColorCorrectionEffect" } do
			local effect = mockEffect(name)
			phoneChildAdded:Fire(effect)
			assert(effect.Enabled == (name == "ColorCorrectionEffect"), "phone: a recreated " .. name)
			effect.Enabled = true
			assert(effect.Enabled == (name == "ColorCorrectionEffect"), "phone: " .. name .. " switched back on is switched off again")
		end
		character:Destroy()
		tutorial:Destroy()
	end
	assert(totalBolts == 18)
	pass("LowPowerGraphics: phones lose Bloom/SunRays/DoF (existing, recreated, re-enabled) and the 18 lobby bolt Highlights (6 per world, re-streamed too); ColorCorrection, Atmosphere and every other Highlight stay; desktop unchanged")
end

-- 3. Running and treadmill sound (loaded whole) ---------------------------------------------
local function runSoundHarness(path)
	local counts = { params = 0, raycasts = 0, getChildren = 0 }
	local heartbeat, characterAdded = signal(), signal()
	local attributes = {}
	local function makeCharacter()
		local rootChildren = {}
		local root = {
			Name = "HumanoidRootPart",
			Position = rb.Vector3.new(0, 5, 0),
			ChildAdded = signal(),
			Children = rootChildren,
			GetChildren = function()
				counts.getChildren += 1
				return table.clone(rootChildren)
			end,
		}
		local humanoid = { Health = 100, WalkSpeed = 16, MoveDirection = { Magnitude = 0 } }
		local character = {
			GetAttribute = function() return nil end,
			FindFirstChild = function(_, name) return if name == "HumanoidRootPart" then root else nil end,
			FindFirstChildOfClass = function(_, name) return if name == "Humanoid" then humanoid else nil end,
		}
		return character, root, humanoid
	end
	local function sound(name)
		local s = { Name = name, SoundId = "rbxasset://default", Volume = 1, IsPlaying = false }
		s.IsA = function(_, c) return c == "Sound" end
		s.Play = function(self) self.IsPlaying = true end
		s.Stop = function(self) self.IsPlaying = false end
		s.Destroy = function(self) self.Parent = nil end
		return s
	end
	local character, root, humanoid = makeCharacter()
	local defaultRunning = sound("Running")
	table.insert(root.Children, defaultRunning)
	local player = {
		Character = character,
		CharacterAdded = characterAdded,
		GetAttribute = function(_, name) return attributes[name] end,
	}
	local lastParams = nil
	local created = {}
	local env = setmetatable({
		game = { GetService = function(_, name)
			return if name == "Players" then { LocalPlayer = player } else { Heartbeat = heartbeat }
		end },
		RaycastParams = { new = function()
			counts.params += 1
			lastParams = {}
			return lastParams
		end },
		Enum = { RaycastFilterType = { Exclude = "Exclude" }, RollOffMode = { InverseTapered = "InverseTapered" } },
		Instance = { new = function(className)
			assert(className == "Sound")
			local made = sound("")
			table.insert(created, made)
			return made
		end },
		Vector3 = rb.Vector3,
		workspace = { Raycast = function(_, _, _, params)
			counts.raycasts += 1
			counts.lastRayParams = params
			return nil
		end },
		task = {
			spawn = function(fn, ...) fn(...) end,
			defer = function(fn, ...) fn(...) end,
			wait = function() end,
		},
		print = function() end,
	}, { __index = _G })
	luau.load(read(path), { environment = env })()
	return {
		counts = counts, heartbeat = heartbeat, characterAdded = characterAdded, attributes = attributes,
		character = character, root = root, humanoid = humanoid, defaultRunning = defaultRunning,
		sound = sound, makeCharacter = makeCharacter, player = player,
		params = function() return lastParams end,
		created = created,
	}
end

do
	local RUN_ID = "rbxassetid://96591611478915"
	local h = runSoundHarness(SOUND)
	assert(h.defaultRunning.SoundId == RUN_ID, "the default Running sound takes the exact id at setup")
	assert(h.counts.params == 1, "one RaycastParams at load")
	local params = h.params()
	assert(params.FilterType == "Exclude" and params.FilterDescendantsInstances[1] == h.character, "the params exclude the character from setup")
	local walks = h.counts.getChildren
	for _ = 1, 60 do
		h.heartbeat:Fire(1 / 60)
	end
	assert(h.counts.raycasts >= 8 and h.counts.raycasts <= 10, "standing still: the treadmill check runs at about 10 Hz (6-7 frames at 60 FPS), not every frame (" .. h.counts.raycasts .. " in 60 frames)")
	assert(h.counts.lastRayParams == params, "the raycast uses the hoisted params")
	assert(h.counts.params == 1, "no RaycastParams is made per frame")
	assert(h.counts.getChildren == walks, "the root's children are not walked every frame")
	-- The engine adds its default sound later: patched as it arrives.
	local late = h.sound("Running")
	table.insert(h.root.Children, late)
	h.root.ChildAdded:Fire(late)
	assert(late.SoundId == RUN_ID and late.Volume == 0.6, "a Running sound added later takes the exact id")
	-- Moving: the loop sound plays within 0.1 s, and stops as quickly.
	local loopSound = h.created[#h.created]
	assert(loopSound and loopSound.SoundId == RUN_ID and loopSound.Parent == h.root, "the script's own loop sound sits on the root")
	h.humanoid.MoveDirection = { Magnitude = 1 }
	for _ = 1, 7 do
		h.heartbeat:Fire(1 / 60)
	end
	assert(loopSound.IsPlaying, "running: the loop sound starts within 0.1 s")
	h.humanoid.MoveDirection = { Magnitude = 0 }
	for _ = 1, 7 do
		h.heartbeat:Fire(1 / 60)
	end
	assert(not loopSound.IsPlaying, "stopped: the loop sound stops within 0.1 s")
	-- Respawn: the params follow the new character, still without a new RaycastParams.
	local character2, root2 = h.makeCharacter()
	local running2 = h.sound("Running")
	table.insert(root2.Children, running2)
	h.player.Character = character2
	h.characterAdded:Fire(character2)
	assert(params.FilterDescendantsInstances[1] == character2, "after a respawn the params exclude the new character")
	assert(running2.SoundId == RUN_ID, "the new root's default sound is patched")
	assert(h.counts.params == 1, "still one RaycastParams after a respawn")
	h.root.ChildAdded:Fire(h.sound("Running")) -- the old root's hook is gone: must not error or matter
	assert(h.root.ChildAdded:Count() == 0, "the old root's ChildAdded hook is disconnected")
	pass("running sound: one RaycastParams (re-aimed on respawn), update at 10 Hz, default sound patched at setup and on ChildAdded only")
end

-- 4. World 2 tree slammers (loaded whole) ----------------------------------------------------
local function runTreeHarness(path)
	local counts = { filterWrites = 0, overlaps = 0, fired = {}, deferred = 0 }
	local frame, added, removing, characterAdded = signal(), signal(), signal(), signal()
	local workspace = {}
	local function part(name, parent, position)
		return {
			Name = name, Parent = parent, Transparency = 0, Position = position,
			IsA = function(_, c) return c == "BasePart" end,
			GetAttribute = function() return nil end,
			IsDescendantOf = function(self, ancestor) return self.Parent == ancestor end,
		}
	end
	local tree = {
		Name = "Tree1", Parent = workspace,
		IsA = function(_, c) return c == "Model" end,
		GetAttribute = function() return nil end,
		GetBoundingBox = function() return { Position = rb.Vector3.new(0, 0, 0) } end,
	}
	local treeParts = { part("Trunk", tree, rb.Vector3.new(0, 0, 0)), part("Leaves", tree, rb.Vector3.new(0, 10, 0)) }
	tree.GetDescendants = function() return table.clone(treeParts) end
	local contact = false
	workspace.GetDescendants = function()
		local list = { tree }
		for _, p in treeParts do
			table.insert(list, p)
		end
		return list
	end
	workspace.DescendantAdded = added
	workspace.DescendantRemoving = removing
	workspace.GetAttribute = function() return nil end
	workspace.GetServerTimeNow = function() return 0 end
	workspace.GetPartsInPart = function(_, _, params)
		counts.overlaps += 1
		assert(#params.FilterDescendantsInstances == #treeParts, "the filter lists the tree parts")
		return if contact then { treeParts[1] } else {}
	end
	local humanoid = { Health = 100, ChangeState = function() end }
	local rootPart = part("HumanoidRootPart", nil, rb.Vector3.new(0, 0, 30))
	local head = part("Head", nil, rb.Vector3.new(0, 2, 30))
	local character = {
		GetChildren = function() return { head, rootPart } end,
		FindFirstChildOfClass = function(_, c) return if c == "Humanoid" then humanoid else nil end,
		FindFirstChild = function(_, name) return if name == "HumanoidRootPart" then rootPart else nil end,
		GetAttribute = function() return nil end,
		ChildAdded = signal(),
		ChildRemoved = signal(),
	}
	head.Parent, rootPart.Parent = character, character
	local player = { Character = character, CharacterAdded = characterAdded, GetAttribute = function() return nil end }
	local remote = { FireServer = function(_, index) table.insert(counts.fired, index) end }
	local services = {
		Players = { LocalPlayer = player },
		ReplicatedStorage = { WaitForChild = function(_, name)
			return if name == "Shared" then { WaitForChild = function(_, n) return n end }
				else { WaitForChild = function() return remote end }
		end },
		RunService = { RenderStepped = frame },
		Workspace = workspace,
	}
	local Motion = require("../src/common/ReplicatedStorage/Shared/TreeSlamMotion")
	local env = setmetatable({
		game = { GetService = function(_, name) return services[name] end },
		require = function(name) return if name == "Config" then { IsWorld2Place = true } else Motion end,
		OverlapParams = { new = function()
			local store = {}
			return setmetatable({}, {
				__index = store,
				__newindex = function(_, k, v)
					if k == "FilterDescendantsInstances" then
						counts.filterWrites += 1
					end
					store[k] = v
				end,
			})
		end },
		Enum = { RaycastFilterType = { Include = "Include" }, HumanoidStateType = { Dead = "Dead" } },
		task = { spawn = function() end, defer = function(fn) counts.deferred += 1 fn() end },
		print = function() end,
	}, { __index = _G })
	luau.load(read(path), { environment = env })()
	return {
		counts = counts, frame = frame, added = added, tree = tree, treeParts = treeParts, part = part,
		humanoid = humanoid, setContact = function(value) contact = value end,
	}
end

do
	local h = runTreeHarness(TREES)
	local writesAtStart = h.counts.filterWrites
	assert(writesAtStart >= 1, "the filter is built when the cache is built")
	for _ = 1, 30 do
		h.frame:Fire()
	end
	assert(h.counts.filterWrites == writesAtStart, "no filter write per frame")
	assert(h.counts.overlaps == 30, "the contact test still runs every frame for the body part (Head) near the trees (" .. h.counts.overlaps .. ")")
	assert(h.humanoid.Health == 100 and #h.counts.fired == 0, "no contact, no kill")
	-- A non-part streaming in: ignored before anything reads it.
	local texture = setmetatable({}, { __index = function(_, key)
		if key == "IsA" then
			return function() return false end
		end
		error("the handler read ." .. tostring(key) .. " of a non-part")
	end })
	h.added:Fire(texture)
	assert(h.counts.deferred == 0, "a non-part does not trigger a rebuild")
	-- A new piece of the tree streams in: one rebuild, one filter write.
	local deferred = h.counts.deferred
	local piece = h.part("Branch", h.tree, rb.Vector3.new(0, 5, 0))
	table.insert(h.treeParts, piece)
	local writes = h.counts.filterWrites
	h.added:Fire(piece)
	assert(h.counts.deferred == deferred + 1 and h.counts.filterWrites == writes + 1, "a tree part streaming in rebuilds the cache and its filter once")
	h.setContact(true)
	h.frame:Fire()
	assert(h.humanoid.Health == 0 and h.counts.fired[1] == 1, "contact still kills at once and reports tree 1")
	pass("tree slammers: the overlap filter is built with the cache, not per frame; contact still kills; non-parts ignored on DescendantAdded")
end

-- The same count against the source before this pass: proves the harness sees per-frame writes.
do
	local function countWrites(path)
		local writes = 0
		local frame = signal()
		local src = read(path)
		-- The same harness, but with OverlapParams as a pure proxy so every write is seen.
		local h
		do
			local counts = { n = 0 }
			local store = {}
			local proxy = setmetatable({}, {
				__index = store,
				__newindex = function(_, k, v)
					if k == "FilterDescendantsInstances" then
						counts.n += 1
					end
					store[k] = v
				end,
			})
			local Motion = require("../src/common/ReplicatedStorage/Shared/TreeSlamMotion")
			local workspace = {}
			local tree = { Name = "Tree1", Parent = workspace, IsA = function(_, c) return c == "Model" end,
				GetAttribute = function() return nil end, GetBoundingBox = function() return { Position = rb.Vector3.new(0, 0, 0) } end }
			local trunk = { Name = "Trunk", Parent = tree, Transparency = 0, IsA = function(_, c) return c == "BasePart" end, GetAttribute = function() return nil end }
			tree.GetDescendants = function() return { trunk } end
			workspace.GetDescendants = function() return { tree, trunk } end
			workspace.DescendantAdded, workspace.DescendantRemoving = signal(), signal()
			workspace.GetAttribute = function() return nil end
			workspace.GetPartsInPart = function() return {} end
			local head = { Name = "Head", Transparency = 0, IsA = function(_, c) return c == "BasePart" end }
			local root = { Name = "HumanoidRootPart", Position = rb.Vector3.new(0, 0, 20), IsA = function(_, c) return c == "BasePart" end }
			local character = { GetChildren = function() return { head, root } end,
				FindFirstChildOfClass = function() return { Health = 100 } end,
				FindFirstChild = function(_, n) return if n == "HumanoidRootPart" then root else nil end,
				GetAttribute = function() return nil end, ChildAdded = signal(), ChildRemoved = signal() }
			head.Parent, root.Parent = character, character
			local services = {
				Players = { LocalPlayer = { Character = character, CharacterAdded = signal(), GetAttribute = function() return nil end } },
				ReplicatedStorage = { WaitForChild = function(_, name)
					return if name == "Shared" then { WaitForChild = function(_, n) return n end } else { WaitForChild = function() return {} end }
				end },
				RunService = { RenderStepped = frame },
				Workspace = workspace,
			}
			local env = setmetatable({
				game = { GetService = function(_, name) return services[name] end },
				require = function(name) return if name == "Config" then { IsWorld2Place = true } else Motion end,
				OverlapParams = { new = function() return proxy end },
				Enum = { RaycastFilterType = { Include = "Include" } },
				task = { spawn = function() end, defer = function(fn) fn() end },
				print = function() end,
			}, { __index = _G })
			luau.load(src, { environment = env })()
			local before = counts.n
			for _ = 1, 20 do
				frame:Fire()
			end
			writes = counts.n - before
		end
		return writes
	end
	local now = countWrites(TREES)
	local old = countWrites("output/FablePerf_20260922/backup_src/worlds/World2/StarterPlayer/StarterPlayerScripts/Gameplay/World2TreeSlammers.client.luau")
	assert(now == 0, "the filter is written " .. now .. " times in 20 frames near a tree (expected 0)")
	assert(old == 20, "sanity: the old source wrote it every frame (" .. old .. ")")
	pass("tree slammers: 0 filter writes in 20 frames near a tree (the old source: 20)")
end

-- 5. R15SpeedsterRun afterimages ------------------------------------------------------------
local function afterimagesCleared(path)
	local source = read(path)
	local chunk = between(source, "local afterimageElapsed = AFTERIMAGE_SLOW_INTERVAL", "local updateConnection", "afterimages")
	local destroyed = 0
	local folderChildren = {}
	local folder = { Parent = {}, GetChildren = function() return table.clone(folderChildren) end }
	local function ghostModel()
		local ghost = { Name = "", GetChildren = function() return { 1 } end }
		ghost.Destroy = function()
			destroyed += 1
			local index = table.find(folderChildren, ghost)
			if index then
				table.remove(folderChildren, index)
			end
		end
		return setmetatable(ghost, { __newindex = function(t, k, v)
			rawset(t, k, v)
			if k == "Parent" and v == folder then
				table.insert(folderChildren, t)
			end
		end })
	end
	local limb = {
		Transparency = 0,
		CFrame = rb.CFrame.new(),
		IsA = function(_, c) return c == "BasePart" end,
		FindFirstAncestorOfClass = function() return nil end,
		Clone = function()
			return { IsA = function(_, c) return c == "BasePart" end, GetChildren = function() return {} end }
		end,
	}
	local boosting = true
	local env = setmetatable({
		AFTERIMAGE_SLOW_INTERVAL = 0.15, AFTERIMAGE_FAST_INTERVAL = 0.075, AFTERIMAGE_MIN_LIFETIME = 0.24,
		AFTERIMAGE_MAX_LIFETIME = 0.32, MAX_AFTERIMAGES = 5, AFTERIMAGE_COLOR = rb.Color3.new(0, 0, 0),
		AFTERIMAGE_START_SPEED = 48, AFTERIMAGE_FULL_SPEED = 300, LOW_POWER = false,
		afterimageFolder = folder,
		character = { Parent = {}, GetDescendants = function() return { limb } end, GetChildren = function() return { limb } end },
		rootPart = {},
		localPlayer = { GetAttribute = function(_, name) return if name == "IsBoosting" then boosting else nil end },
		movementForAfterimages = function() return true, 300 end,
		Instance = { new = function(className)
			return if className == "Model" then ghostModel() else {}
		end },
		TweenService = { Create = function() return { Play = function() end } end },
		TweenInfo = { new = function() return {} end },
		Enum = { EasingStyle = { Quad = 1 }, EasingDirection = { Out = 1 }, Material = { SmoothPlastic = 1 }, HighlightDepthMode = { Occluded = 1 } },
		Debris = { AddItem = function() end },
	}, { __index = _G })
	local update = luau.load(chunk .. "\nreturn updateAfterimages", { environment = env })()
	update(0.2) -- boosting at full speed: one ghost
	assert(#folderChildren == 1, "a ghost is made while boosting")
	boosting = false
	update(0.016)
	return #folderChildren == 0 and destroyed == 1
end
do
	local source = read(RUN)
	local declared = assert(string.find(source, "local afterimagesAlive = false", 1, true))
	-- The code line (tab-indented), not the comment that mentions it.
	local firstSet = assert(string.find(source, "\n\tafterimagesAlive = true", 1, true))
	assert(declared < firstSet, "afterimagesAlive is declared before createAfterimage sets it")
	assert(string.find(source, "local function isInArrivalGrace(p)", 1, true), "the lead's isInArrivalGrace stays")
	assert(afterimagesCleared(RUN), "the afterimages are cleared when the boost stops")
	assert(not afterimagesCleared("output/FablePerf_20260922/backup_src/common/StarterPlayer/StarterCharacterScripts/R15SpeedsterRun.client.luau"),
		"sanity: the old source never cleared them (the flag was a global)")
	pass("afterimages: the flag is a local declared before use, so ghosts are cleared when the boost stops (the old source left them)")
end

-- 6. Place edits on the real places ---------------------------------------------------------
do
	-- Fresh copies (section 2 added and removed test instances in the ones above).
	local EXPECTED = {
		World1 = { emitters = 0, sounds = 3 },
		World2 = { emitters = 0, sounds = 1 },
		World3 = { emitters = 2, sounds = 1 },
	}
	local counted = {}
	-- The edits are measured on the places as they were before this pass: once
	-- audit/build_fable_perf.luau has run, the root places carry them already (checked below),
	-- and the build keeps the originals in output/FablePerf_20260922/backup.
	local PRE_PASS = "output/FablePerf_20260922/backup/"
	for _, place in PlaceFiles.Places do
		local key = place.key
		local original = if fs.isFile(PRE_PASS .. place.file) then PRE_PASS .. place.file else place.file
		local dm = rb.deserializePlace(fs.readFile(original))
		local ws = dm:GetService("Workspace")
		-- Snapshot every Texture before.
		local snapshot = {}
		local totalTextures = 0
		for _, texture in dm:GetDescendants() do
			if texture.ClassName == "Texture" then
				totalTextures += 1
				local part = texture.Parent
				local chain, node = {}, part
				while node and node ~= ws and node ~= dm do
					table.insert(chain, 1, node.Name)
					node = node.Parent
				end
				snapshot[texture] = {
					face = texture.Face, transparency = texture.Transparency, anchored = part:IsA("BasePart") and part.Anchored,
					up = part:IsA("BasePart") and part.CFrame.UpVector.Y or 0, class = part.ClassName,
					inWorkspace = node == ws, chain = chain,
				}
			end
		end
		local stage10 = ws:FindFirstChild("Stage 10")
		local action = {}
		if stage10 and stage10:FindFirstChild("Action Parts") then
			for _, e in stage10["Action Parts"]:GetDescendants() do
				if e.ClassName == "ParticleEmitter" then
					action[e] = e.Lifetime
				end
			end
		end

		local notes = {}
		local changed = Edits.edit(key, dm, notes)
		local removed, removedBy = 0, {}
		for texture, info in snapshot do
			if texture.Parent == nil then
				removed += 1
				assert(info.face == rb.Enum.NormalId.Bottom, key .. ": removed a non-Bottom texture")
				assert(math.abs(info.transparency - 0.9) < 0.01, key .. ": removed a texture at " .. info.transparency)
				assert(info.anchored and info.class == "Part" and info.up >= 0.99, key .. ": removed a texture on a moving, tilted or non-block part")
				assert(info.inWorkspace, key .. ": removed a texture outside Workspace")
				local root = info.chain[1]
				assert((key == "World1" and root == "neworld1") or (key == "World3" and (string.match(root, "^Stage %d+$") or root == "Lobby" or root == "End")),
					key .. ": removed a texture outside the map roots (" .. root .. ")")
				for _, name in info.chain do
					local n = string.lower((string.gsub(name, "[^%w]", "")))
					assert(not (n:match("^hammer%d") or n:match("^pressdown") or n == "laserplatform" or n == "lava" or n == "lavaup"
						or n == "bridge" or n:match("cylinder") or n == "tumbleweed" or n == "actionparts" or n == "parkour"),
						key .. ": removed a texture inside a hazard: " .. table.concat(info.chain, "."))
				end
				removedBy[root] = (removedBy[root] or 0) + 1
			end
		end
		-- The kept Bottom 0.9 overlays are exactly the unsafe ones.
		local keptBottom = 0
		for texture, info in snapshot do
			if texture.Parent ~= nil and info.face == rb.Enum.NormalId.Bottom and math.abs(info.transparency - 0.9) < 0.01 then
				keptBottom += 1
			end
		end
		counted[key] = { removed = removed, kept = keptBottom, total = totalTextures }

		-- Emitters.
		local fixed = 0
		if stage10 then
			for _, e in stage10.Decor:GetDescendants() do
				if e.ClassName == "ParticleEmitter" then
					assert(e.Lifetime.Max <= 3, key .. ": a Stage 10 decor emitter still lives " .. e.Lifetime.Max .. " s")
					if e.Lifetime.Min == 2 and e.Lifetime.Max == 3 then
						fixed += 1
					end
				end
			end
			for e, lifetime in action do
				assert(e.Lifetime == lifetime, "the Action Parts emitters are untouched")
			end
		end
		assert(fixed == EXPECTED[key].emitters, key .. ": fixed " .. fixed .. " emitters")

		-- Sounds.
		local function soundAt(...)
			local node = dm
			for _, name in { ... } do
				node = node and (if node == dm then dm:GetService(name) else node:FindFirstChild(name))
			end
			return node
		end
		local soundNotes = 0
		for _, text in notes do
			if string.find(text, "unauthorized sound", 1, true) then
				soundNotes += 1
				assert(not string.find(text, "id unreadable", 1, true), key .. ": the asset id was matched, not just the path: " .. text)
			end
		end
		assert(soundNotes == EXPECTED[key].sounds, key .. ": removed " .. soundNotes .. " sounds")
		assert(soundAt("ServerStorage", "AuthoredAuras", "AquaticOpenSource", "Rig", "HumanoidRootPart", "Sound") == nil, key .. ": the aura rig Sound is gone")
		assert(soundAt("ServerStorage", "AuthoredAuras", "GalacticOpenSource", "Rig", "HumanoidRootPart", "AuraSound") ~= nil, key .. ": Galactic's own sound stays")
		if key == "World1" then
			assert(soundAt("Workspace", "Folder", "Zoom", "HumanoidRootPart", "LightningStart") == nil, "Zoom LightningStart is gone")
			assert(soundAt("Workspace", "Trampoline", "Trampoline_Hitbox", "JumpSound") == nil, "Trampoline JumpSound is gone")
			assert(soundAt("Workspace", "Folder", "Zoom", "HumanoidRootPart", "LightningSound") ~= nil, "Zoom LightningSound stays")
			assert(soundAt("Workspace", "Folder", "Zoom", "Zoom CW Run") ~= nil, "the Zoom CW Run music stays")
		end

		assert(changed == true, key .. ": the first run changes the place")
		Edits.verify(key, dm)
		-- Idempotent.
		local again = {}
		assert(Edits.edit(key, dm, again) == false and #again == 0, key .. ": a second run changes nothing (" .. table.concat(again, "; ") .. ")")
		print(("  %s: %s | kept Bottom 0.9: %d"):format(key, table.concat(notes, "; "), keptBottom))
	end
	-- Exact texture counts (Lune scan 2026-09-22 of the places as they stand).
	assert(counted.World2.removed == 0, "World 2 has no map overlays to remove")
	assert(counted.World1.removed == 1037, "World 1 removed " .. counted.World1.removed)
	assert(counted.World1.kept == 399, "World 1 kept " .. counted.World1.kept)
	assert(counted.World3.removed == 1632, "World 3 removed " .. counted.World3.removed)
	assert(counted.World3.kept == 539, "World 3 kept " .. counted.World3.kept)
	-- The root places, once built, carry every edit: verify holds and nothing is left to do.
	local built = 0
	for _, place in PlaceFiles.Places do
		if fs.isFile(PRE_PASS .. place.file) then
			local dm = rb.deserializePlace(fs.readFile(place.file))
			Edits.verify(place.key, dm)
			local left = {}
			assert(Edits.edit(place.key, dm, left) == false and #left == 0, place.key .. ": the built place still needs " .. table.concat(left, "; "))
			built += 1
		end
	end
	pass(("place edits: Stage 10 emitters 2-3 s (2), hidden Bottom overlays removed (W1 1037 of 1436, W3 1632 of 2171; only upright static map parts), the unauthorized sounds gone (W1 3, W2 1, W3 1), second run a no-op; %d built place(s) already carry them"):format(built))
end

print("ALL PASS test_perf_phone")
