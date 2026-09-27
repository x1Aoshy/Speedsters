-- test_admin_trolls.luau
-- The Snail and Fake Reset trolls. Snail: the server's crawl (a time limit every movement
-- script reads), the snail sign and slime trail everyone sees, and the player's own speed
-- back when it ends. Fake Reset: played frame by frame in a small Roblox, all on the
-- player's screen: the HUD's Speed, Wins and Rebirths held at 0 even while the HUD keeps
-- counting, the glitch and the fake error, then the reveal with the latest real numbers,
-- and nothing ever sent to the server or saved.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local rb = require("@lune/roblox")

local SERVICE = fs.readFile("audit/review_20260919/AdminAbusePanelService.before.luau")
local EFFECTS = fs.readFile("audit/review_20260919/AdminAbuseEffects.before.luau")
local MOVEMENT = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/Movement/InstantMovementController.client.luau")
local STATS = fs.readFile("src/common/ServerScriptService/Progression/PlayerStats.server.luau")

local function has(source, needle, message)
	assert(string.find(source, needle, 1, true), message)
end
local function between(source, first, last)
	local a = assert(string.find(source, first, 1, true), "chunk " .. first)
	local b = assert(string.find(source, last, a, true), "chunk end " .. last)
	return string.sub(source, a, b - 1)
end

----------------------------------------------------------------------
-- 1. Snail on the server
----------------------------------------------------------------------
do
	local now = 1000
	local attributes = {}
	local player = {
		Name = "Victim",
		SetAttribute = function(_, key, value)
			attributes[key] = value
		end,
		GetAttribute = function(_, key)
			return attributes[key]
		end,
	}
	local character = rb.Instance.new("Model")
	local root = rb.Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Parent = character
	local delays, fired, applied = {}, {}, 0
	local env = setmetatable({
		aliveRoot = function()
			return character, root
		end,
		Workspace = { GetServerTimeNow = function()
			return now
		end },
		Panel = { FireClient = function(_, target, payload)
			table.insert(fired, { target, payload })
		end },
		task = { delay = function(seconds, callback)
			table.insert(delays, { Seconds = seconds, Callback = callback })
		end },
		_G = { SpeedsterApplyWalkSpeed = function(target)
			assert(target == player)
			applied += 1
		end },
		Instance = rb.Instance,
		Enum = rb.Enum,
		UDim2 = rb.UDim2,
		Vector3 = rb.Vector3,
		Color3 = rb.Color3,
		ColorSequence = rb.ColorSequence,
		NumberSequence = rb.NumberSequence,
	}, { __index = _G })
	local snail, SNAIL_SPEED = luau.load(between(SERVICE, "-- Snail: a crawl", "local function jail") .. "\nreturn snail, SNAIL_SPEED", { environment = env })()
	assert(SNAIL_SPEED >= 2 and SNAIL_SPEED <= 3, "A crawl of 2 to 3 studs a second")
	assert(snail(player, 10) == true, "Snail takes a living player")
	assert(attributes.AdminSnailUntil == 1010, "Crawling for the chosen seconds, by the server's clock")
	local kit = assert(character:FindFirstChild("AdminSnail"), "Its look")
	local sign = kit:FindFirstChild("SnailSign")
	assert(sign and sign.Adornee == root and sign.Title.Text == "SNAIL MODE" and sign.Icon.Text == "🐌", "A snail sign over the player, for everyone")
	assert(not sign.Icon:FindFirstChildOfClass("UIStroke"), "...the snail on its own, not outlined")
	local slime = kit:FindFirstChild("Slime")
	assert(slime and slime.Attachment0.Parent == root and slime.Attachment1.Parent == root, "A slime trail from the feet")
	assert(applied == 1, "The player's walk speed is worked out again at once")
	assert(fired[1][1] == player and fired[1][2].effect == "Snail" and fired[1][2].duration == 10, "The player hears about it")
	-- A second snail before the first ends: the first one's end does not cut it short.
	now = 1005
	snail(player, 10)
	assert(attributes.AdminSnailUntil == 1015, "A new snail runs its own time")
	delays[1].Callback()
	assert(attributes.AdminSnailUntil == 1015 and character:FindFirstChild("AdminSnail"), "...the old one's end leaves it alone")
	delays[2].Callback()
	assert(attributes.AdminSnailUntil == nil, "When it ends the crawl is over")
	assert(not character:FindFirstChild("AdminSnail") and not root:FindFirstChild("AdminSnailSlimeLeft") and not root:FindFirstChild("AdminSnailSlimeRight"), "...its sign and slime gone")
	assert(applied == 3, "...and the player's own walk speed worked out again")

	-- Every mover respects it.
	local sonic = assert(string.find(MOVEMENT, "movementWalkSpeed *= sonicRatio", 1, true))
	local cap = assert(string.find(MOVEMENT, 'local snailUntil = tonumber(player:GetAttribute("AdminSnailUntil"))', sonic, true), "The client's movement caps the crawl")
	local walk = assert(string.find(MOVEMENT, "humanoid.WalkSpeed = movementWalkSpeed", cap, true), "...before it sets the walk speed")
	assert(cap < walk, "...in order")
	has(MOVEMENT, "movementWalkSpeed = math.min(movementWalkSpeed, SNAIL_WALK_SPEED)", "...to the crawl")
	has(MOVEMENT, "local SNAIL_WALK_SPEED = 2.5", "...of 2.5 studs a second")
	has(STATS, 'local snailUntil = tonumber(player:GetAttribute("AdminSnailUntil"))', "The server's walk speed caps it too")
	has(STATS, "actualWalkSpeed = math.min(actualWalkSpeed, SNAIL_WALK_SPEED)", "...to the crawl")
	has(SERVICE, 'elseif effect == "Snail" then\n\t\t\tok = snail(player, duration)', "The panel's Snail runs it")
	print("PASS Snail: a 2.5 stud/s crawl for the chosen seconds, a snail sign and slime for everyone, the real speed back when it ends")
end

----------------------------------------------------------------------
-- 2. Fake Reset on the player's screen
----------------------------------------------------------------------
local function signal()
	local s = { listeners = {} }
	function s:Connect(callback)
		local entry = { callback = callback, live = true }
		table.insert(self.listeners, entry)
		return { Disconnect = function()
			entry.live = false
		end }
	end
	function s:Fire(...)
		for _, entry in table.clone(self.listeners) do
			if entry.live then
				entry.callback(...)
			end
		end
	end
	return s
end
local methods = {}
local function instance(class)
	local object = { props = { ClassName = class, Name = class, Visible = true, Text = "" }, children = {}, changed = {} }
	return setmetatable(object, {
		__index = function(self, key)
			if methods[key] then
				return methods[key]
			end
			if self.props[key] ~= nil then
				return self.props[key]
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
			local before = self.props[key]
			self.props[key] = value
			if before ~= value and self.changed[key] then
				self.changed[key]:Fire()
			end
		end,
	})
end
function methods:IsA(class)
	return self.ClassName == class
end
function methods:FindFirstChild(name)
	for _, child in self.children do
		if child.Name == name then
			return child
		end
	end
	return nil
end
function methods:FindFirstChildOfClass(class)
	for _, child in self.children do
		if child.ClassName == class then
			return child
		end
	end
	return nil
end
function methods:GetPropertyChangedSignal(key)
	self.changed[key] = self.changed[key] or signal()
	return self.changed[key]
end
function methods:Destroy()
	self.Parent = nil
	self.props.Destroyed = true
end
function methods:Play()
	self.props.Playing = true
end
local function child(parent, class, name, text)
	local object = instance(class)
	object.Name = name
	if text then
		object.Text = text
	end
	object.Parent = parent
	return object
end

do
	local playerGui = instance("PlayerGui")
	local mainhud = child(playerGui, "ScreenGui", "Mainhud")
	local trophies = child(mainhud, "Frame", "Rebith/trof")
	local rebirths = child(trophies, "TextLabel", "Rebirth", "12")
	local wins = child(trophies, "TextLabel", "Victory", "3.4k")
	local levelFrame = child(child(mainhud, "Frame", "LevelProgressBar"), "Frame", "Frame")
	local speed = child(levelFrame, "TextLabel", "Speed", "Speed: 1.2M")
	local overlay = instance("ScreenGui")
	local clock = 0
	local renders = {}
	local confetti = 0
	local env = setmetatable({
		PlayerGui = playerGui,
		overlay = overlay,
		RunService = { RenderStepped = { Connect = function(_, callback)
			local entry = { callback = callback, live = true }
			table.insert(renders, entry)
			return { Disconnect = function()
				entry.live = false
			end }
		end } },
		EFFECTS = { Confetti = function()
			confetti += 1
		end },
		os = { clock = function()
			return clock
		end },
		task = { delay = function() end },
		Instance = { new = instance },
		Enum = rb.Enum,
		UDim = rb.UDim,
		UDim2 = rb.UDim2,
		Vector2 = rb.Vector2,
		Color3 = rb.Color3,
		ColorSequence = rb.ColorSequence,
	}, { __index = _G })
	local chunk = between(EFFECTS, "local FAKE_RESET = {", "function EFFECTS.FakeReset")
	assert(not string.find(chunk, "FireServer", 1, true) and not string.find(chunk, "InvokeServer", 1, true), "Fake Reset never talks to the server: nothing is changed or saved")
	local fakeReset, FAKE_RESET = luau.load(chunk .. "\nreturn fakeReset, FAKE_RESET", { environment = env })()
	local function frame(t)
		clock = t
		for _, entry in renders do
			if entry.live then
				entry.callback(1 / 60)
			end
		end
	end
	local cleanup = fakeReset("GekkoH")
	assert(rebirths.Text == "0" and wins.Text == "0" and speed.Text == "Speed: 0", "Speed, Wins and Rebirths read 0 at once")
	local oof
	for _, object in overlay.children do
		if object.ClassName == "Sound" and object.SoundId == FAKE_RESET.Sounds.Oof then
			oof = object
		end
	end
	assert(oof and oof.Playing and oof:FindFirstChildOfClass("DistortionSoundEffect"), "A distorted oof")
	frame(0.6)
	local glitch = assert(overlay:FindFirstChild("FakeResetGlitch"), "The screen glitches")
	local visibleBars = 0
	for _, bar in glitch.children do
		if bar.Visible then
			visibleBars += 1
		end
	end
	assert(visibleBars > 0 and glitch.BackgroundTransparency < 1, "...tearing and flashing")
	local warning = assert(overlay:FindFirstChild("FakeResetError"), "A fake data error")
	assert(warning.Visible and warning.Title.Text == "DATA ERROR!", "...on screen")
	assert(not warning.Icon:FindFirstChildOfClass("UIStroke") and warning.Icon.Text == "⚠️", "...its warning sign on its own")
	local blips = 0
	for t = 0.6, 1.5, 1 / 60 do
		frame(t)
	end
	for _, object in overlay.children do
		if object.ClassName == "Sound" and object.SoundId == FAKE_RESET.Sounds.Glitch then
			blips += 1
		end
	end
	assert(blips >= 3, "...crackling (" .. blips .. " glitch sounds)")
	frame(2)
	-- The HUD keeps counting underneath: its new numbers are held at 0 and kept for later.
	wins.Text = "3.5k"
	assert(wins.Text == "0", "A real update to the HUD is held at 0 straight away")
	speed.Text = "Speed: 1.3M"
	assert(speed.Text == "Speed: 0", "...every counter")
	for t = 2, 5.95, 1 / 30 do
		frame(t)
		assert(rebirths.Text == "0" and wins.Text == "0" and speed.Text == "Speed: 0", "Held at 0 all six seconds (t=" .. t .. ")")
	end
	for _, bar in glitch.children do
		assert(not bar.Visible, "The glitch has settled")
	end
	local reveal = assert(overlay:FindFirstChild("FakeResetReveal"), "The reveal waits")
	assert(not reveal.Visible and confetti == 0, "...until the six seconds are up")

	-- The reveal.
	frame(6.02)
	assert(rebirths.Text == "12" and wins.Text == "3.5k" and speed.Text == "Speed: 1.3M", "The real numbers are back, the latest ones")
	assert(not warning.Visible and reveal.Visible, "The fake error goes, the reveal comes")
	assert(reveal.Title.Text == "ROLLED BY GekkoH!" and reveal.Subtitle.Text == "Your stats are 100% safe" and reveal.Icon.Text == "🤣", "🤣 ROLLED BY GekkoH! Your stats are 100% safe")
	assert(confetti == 1, "Confetti")
	local tada
	for _, object in overlay.children do
		if object.ClassName == "Sound" and object.SoundId == FAKE_RESET.Sounds.Tada then
			tada = object
		end
	end
	assert(tada and tada.Playing and not tada:FindFirstChildOfClass("DistortionSoundEffect"), "A clean fanfare")
	wins.Text = "3.6k"
	assert(wins.Text == "3.6k", "After the reveal the HUD counts as usual")
	frame(7)
	cleanup()
	assert(glitch.Parent == nil and warning.Parent == nil and reveal.Parent == nil, "Everything cleared away")
	wins.Text = "3.7k"
	assert(wins.Text == "3.7k", "...and the HUD left alone")

	-- Ended early (a second Fake Reset replaces it): the numbers come back at once.
	local second = fakeReset("Other")
	assert(rebirths.Text == "0", "A second one zeroes again")
	second()
	assert(rebirths.Text == "12" and wins.Text == "3.7k", "Ended early, the real numbers come straight back")

	has(SERVICE, "FakeReset = true }", "The server offers Fake Reset")
	has(SERVICE, "local CLIENT_EFFECTS = { Rocket = true, Balloon = true, Inverse = true, Control = true, Jumpscare = true, NoGravity = true, FakeReset = true }", "...played only on the target's screen")
	has(SERVICE, "adminName = credit,", "...named after the admin")
	has(EFFECTS, "task.spawn(effect, duration, tonumber(payload.adminUserId), payload.adminName, payload)", "The client gets the admin's name")
	print("PASS Fake Reset: the HUD reads 0 with a glitch and a fake error for six seconds, then confetti, who did it, and the latest real numbers; nothing sent or saved")
end

----------------------------------------------------------------------
-- 3. Fireworks
----------------------------------------------------------------------
do
	math.randomseed(7)
	local V3 = rb.Vector3
	local world = rb.Instance.new("Folder")
	local env = setmetatable({
		Workspace = world,
		Instance = rb.Instance,
		Enum = rb.Enum,
		Vector3 = V3,
		Vector2 = rb.Vector2,
		CFrame = rb.CFrame,
		Color3 = rb.Color3,
		ColorSequence = rb.ColorSequence,
		NumberSequence = rb.NumberSequence,
		NumberSequenceKeypoint = rb.NumberSequenceKeypoint,
		NumberRange = rb.NumberRange,
	}, { __index = _G })
	local fireworksShow, FIREWORKS = luau.load(between(EFFECTS, "local FIREWORKS = {", "function EFFECTS.Fireworks") .. "\nreturn fireworksShow, FIREWORKS", { environment = env })()
	local origin = V3.new(290, 0, -1755)
	local size = V3.new(112, 0, 140)
	local show = fireworksShow(origin, size)
	assert(show.Folder.Parent == world, "The show has its own folder")
	local launched, bursts = {}, {}
	local launch, burst = show.Launch, show.Burst
	show.Launch = function(from)
		local entry = launch(from)
		table.insert(launched, entry)
		return entry
	end
	show.Burst = function(at, hue, kind, cameraPosition)
		local holder = burst(at, hue, kind, cameraPosition)
		-- What it is made of, read while it exists (old bursts are cleared away later).
		table.insert(bursts, {
			At = at,
			Kind = kind,
			Holder = holder,
			Born = show.Elapsed,
			Complete = holder:FindFirstChild(kind) ~= nil and holder:FindFirstChild("Glitter") ~= nil and holder:FindFirstChild("Flash") ~= nil,
			Spread = holder:FindFirstChild(kind) and holder:FindFirstChild(kind).SpreadAngle,
		})
		return holder
	end

	-- Ten seconds of the show, watched from the lobby.
	local camera = origin + V3.new(0, 12, 60)
	local biggestShake, climbing = 0, {}
	for _ = 1, 300 do
		local shake = show.Step(1 / 30, camera, camera, origin.Y, true)
		biggestShake = math.max(biggestShake, shake.Magnitude)
		for _, rocket in show.Rockets do
			local y = rocket.Part.CFrame.Position.Y
			if climbing[rocket] then
				assert(y >= climbing[rocket] - 1e-3, "Rockets only go up")
			end
			climbing[rocket] = y
		end
	end
	assert(#launched >= 10 and #launched <= 45, "Rockets keep going up (" .. #launched .. " in ten seconds)")
	for _, rocket in launched do
		assert(math.abs(rocket.From.X - origin.X) <= 0.4 * size.X + 1e-3 and math.abs(rocket.From.Z - origin.Z) <= 0.4 * size.Z + 1e-3 and rocket.From.Y == origin.Y, "From the lobby's dance floor")
		local height = rocket.Top.Y - rocket.From.Y
		assert(height >= FIREWORKS.Height[1] and height <= FIREWORKS.Height[2], "Up to a good height")
	end
	assert(#bursts >= 8, "They burst (" .. #bursts .. ")")
	local kinds = {}
	for _, entry in bursts do
		kinds[entry.Kind] = true
		assert(entry.Complete, "Each burst has its sparks, glitter and a flash")
		local matched = false
		for _, rocket in launched do
			if (rocket.Top - entry.At).Magnitude < 1e-3 then
				matched = true
			end
		end
		assert(matched, "Each burst is where its rocket topped out")
	end
	assert(kinds.Peony and kinds.Ring and kinds.Willow, "Peonies, rings and willows")
	for _, entry in bursts do
		if entry.Kind == "Ring" then
			assert(entry.Spread == rb.Vector2.new(180, 0), "A ring bursts flat")
		end
	end
	assert(biggestShake > 0.01, "A burst nearby shakes the camera")
	assert(biggestShake <= FIREWORKS.ShakeStuds * math.sqrt(3) + 1e-6, "...only a little (" .. biggestShake .. " studs at most)")

	-- The flash fades.
	local last = bursts[#bursts]
	for _ = 1, 30 do
		show.Step(1 / 30, camera, camera, origin.Y, false)
	end
	assert(last.Holder:FindFirstChild("Flash").Brightness == 0, "Each flash fades out")

	-- The launches stop; the last rockets burst and everything clears.
	for _ = 1, 30 * 7 do
		show.Step(1 / 30, camera, camera, origin.Y, false)
	end
	assert(#show.Rockets == 0 and #show.Bursts == 0, "When the show ends, the sky clears")
	assert(show.Step(1 / 30, camera, camera, origin.Y, false) == V3.zero, "...and the camera is still")

	-- A burst far away does not shake the camera.
	show.Burst(origin + V3.new(0, 60, 0), 0.5, "Peony", origin + V3.new(1000, 0, 0))
	assert(show.Step(1 / 30, origin + V3.new(1000, 0, 0), origin, origin.Y, false) == V3.zero, "A far burst does not shake anyone")

	-- Away from the lobby, the rockets go up around the player instead.
	local far = V3.new(5000, 300, 900)
	for _ = 1, 20 do
		local point = show.LaunchPoint(far, far, 296)
		local flat = (V3.new(point.X, 0, point.Z) - V3.new(far.X, 0, far.Z)).Magnitude
		assert(flat >= FIREWORKS.AroundPlayer[1] - 1e-3 and flat <= FIREWORKS.AroundPlayer[2] + 1e-3 and point.Y == 296, "Around the player, on their ground")
	end

	show.Stop()
	assert(show.Folder.Parent == nil, "Stopping the show takes it all away")
	local handler = between(EFFECTS, "function EFFECTS.Fireworks", "-- The sky under the events")
	assert(string.find(handler, "humanoid.CameraOffset = shake", 1, true) and string.find(handler, "humanoid.CameraOffset = Vector3.zero", 1, true), "The shake moves the camera through its offset, and puts it back")
	has(SERVICE, "Confetti = true, Fireworks = true }", "The panel's Fireworks event")
	has(SERVICE, 'Panel:FireAllClients({ kind = "Effect", effect = "Fireworks", duration = duration, origin = floor, size = size })', "...from the lobby's dance floor, for everyone")
	print("PASS Fireworks: rockets up from the lobby (or round the player), peonies, rings and willows, flashes that fade, a small shake only nearby")
end

print("ALL ADMIN TROLL CHECKS PASSED")
